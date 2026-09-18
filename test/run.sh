#!/bin/sh
#
# reclang test suite
#
# Usage: sh test/run.sh [path/to/reclang]
# Returns non-zero if any check fails

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
reclang=${1:-$root/reclang}
case $reclang in
    /*) ;;
    *)  reclang=$PWD/$reclang ;;
esac

if [ ! -x "$reclang" ]; then
    echo "run.sh: no executable at $reclang (build it first, or pass its path)" >&2
    exit 2
fi

pass=0
fail=0

ok() {
    pass=$((pass + 1))
    echo "ok   $1"
}

bad() {
    fail=$((fail + 1))
    echo "FAIL $1"
    if [ $# -gt 1 ]; then
        printf '     %s\n' "$2"
    fi
}

tmp=$(mktemp) || exit 2
bin=$(mktemp) || exit 2
trap 'rm -f "$tmp" "$bin"' EXIT

# ---------------------------------------------------------
# Add a check by calling ok/bad with a one-line description
# ---------------------------------------------------------

# reclang version
expected=$(cat "$root/VERSION")

# Check the VERSION file - expected one line version only
if printf '%s\n' "$expected" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    ok "VERSION is X.Y.Z"
else
    bad "VERSION is X.Y.Z" "got '$expected'"
fi

# reclang --version prints exactly the VERSION file
"$reclang" --version > "$tmp" 2>&1
status=$?
if [ "$status" -eq 0 ]; then
    ok "reclang --version exits 0"
else
    bad "reclang --version exits 0" "exit status $status"
fi

if printf '%s\n' "$expected" | cmp -s - "$tmp"; then
    ok "reclang --version prints exactly '$expected'"
else
    bad "reclang --version prints exactly '$expected'" "got '$(cat "$tmp")'"
fi

# reclang -a rejects an unsupported architecture without writing output,
# and lists the supported ones on stderr
msg=$("$reclang" -o "$bin" -a no-such-arch "$root/test/min-1.rec" 2>&1 > /dev/null)
status=$?
if [ "$status" -ne 0 ] && [ ! -s "$bin" ]; then
    ok "reclang -a no-such-arch fails"
else
    bad "reclang -a no-such-arch fails" "exit status $status"
fi

case $msg in
    *x86_64*) ok "reclang -a no-such-arch lists x86_64 on stderr" ;;
    *)        bad "reclang -a no-such-arch lists x86_64 on stderr" "got '$msg'" ;;
esac

# test/min-1.rec compiles to an ELF64 executable that runs
# (a noexec TMPDIR makes the run step fail with 126: use TMPDIR=$root)
"$reclang" -o "$bin" "$root/test/min-1.rec" > /dev/null 2>&1
status=$?
if [ "$status" -eq 0 ] && [ -x "$bin" ]; then
    ok "reclang -o compiles test/min-1.rec"
else
    bad "reclang -o compiles test/min-1.rec" "exit status $status"
fi

"$bin" > "$tmp" 2>&1
status=$?
if [ "$status" -eq 42 ]; then
    ok "min-1 exits 42"
else
    bad "min-1 exits 42" "exit status $status"
fi

if printf 'Hello, world!\n' | cmp -s - "$tmp"; then
    ok "min-1 prints 'Hello, world!'"
else
    bad "min-1 prints 'Hello, world!'" "got '$(cat "$tmp")'"
fi

if command -v readelf > /dev/null 2>&1; then
    readelf -h -l "$bin" > "$tmp" 2>&1
    if grep -q 'OS/ABI: *UNIX - System V' "$tmp" \
       && grep -q 'Entry point address: *0x400078' "$tmp" \
       && grep -q '^  LOAD ' "$tmp"; then
        ok "readelf -h -l accepts min-1"
    else
        bad "readelf -h -l accepts min-1" "$(head -n 1 "$tmp")"
    fi
fi

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
