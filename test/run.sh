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
trap 'rm -f "$tmp"' EXIT

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

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
