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
skip=0

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

# skipped DESCRIPTION REASON: for a check this host cannot make
skipped() {
    skip=$((skip + 1))
    echo "skip $1"
    printf '     %s\n' "$2"
}

# the target reclang builds for here, spelled as reclang spells it
case $(uname -m) in
    x86_64|amd64)  hostArch=x86_64 ;;
    arm64|aarch64) hostArch=aarch64 ;;
    *)             hostArch=unknown ;;
esac
case $(uname -s) in
    Linux)  hostOS=linux ;;
    Darwin) hostOS=macos ;;
    *)      hostOS=unknown ;;
esac
host=$hostArch-$hostOS

# hex FILE OFFSET COUNT: COUNT bytes of FILE at OFFSET as one hex string
# (-v stops od collapsing repeated lines; bytewise output is endian-proof)
hex() {
    od -A n -t x1 -v -j "$2" -N "$3" "$1" | tr -d ' \t\n'
}

# check_hex DESCRIPTION FILE OFFSET EXPECTED
check_hex() {
    got=$(hex "$2" "$3" $((${#4} / 2)))
    if [ "$got" = "$4" ]; then
        ok "$1"
    else
        bad "$1" "got $got"
    fi
}

tmp=$(mktemp) || exit 2
bin=$(mktemp) || exit 2
cross=$(mktemp) || exit 2
elf=$(mktemp) || exit 2
elfarm=$(mktemp) || exit 2
# two directories, for the same output name built for two targets
dir1=$(mktemp -d) || exit 2
dir2=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp" "$bin" "$cross" "$elf" "$elfarm" "$dir1" "$dir2"' EXIT

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

# reclang -t rejects an unsupported target without writing output,
# and lists the supported ones on stderr
msg=$("$reclang" -o "$bin" -t no-such-target "$root/test/min-1.rec" 2>&1 > /dev/null)
status=$?
if [ "$status" -ne 0 ] && [ ! -s "$bin" ]; then
    ok "reclang -t no-such-target fails"
else
    bad "reclang -t no-such-target fails" "exit status $status"
fi

case $msg in
    *x86_64-linux*) ok "reclang -t no-such-target lists x86_64-linux on stderr" ;;
    *)              bad "reclang -t no-such-target lists x86_64-linux on stderr" "got '$msg'" ;;
esac

# test/min-1.rec compiles for the host and runs
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

# test/min-0.rec compiles for the host and runs
"$reclang" -o "$bin" "$root/test/min-0.rec" > /dev/null 2>&1
"$bin" > /dev/null 2>&1
status=$?
if [ "$status" -eq 42 ]; then
    ok "min-0 exits 42"
else
    bad "min-0 exits 42" "exit status $status"
fi

# macOS caches code-signature state per vnode, so a signed binary rewritten
# in place is SIGKILLed (status 137) the next time it runs. The output above
# was min-0; compiling min-1 over it must still give a binary that runs.
"$reclang" -o "$bin" "$root/test/min-1.rec" > /dev/null 2>&1
"$bin" > /dev/null 2>&1
status=$?
if [ "$status" -eq 42 ]; then
    ok "a second program compiled to the same path runs"
else
    bad "a second program compiled to the same path runs" "exit status $status"
fi

# the ELF checks below describe x86_64-linux output only
if [ "$host" = x86_64-linux ] && command -v readelf > /dev/null 2>&1; then
    readelf -h -l "$bin" > "$tmp" 2>&1
    if grep -q 'OS/ABI: *UNIX - System V' "$tmp" \
       && grep -q 'Entry point address: *0x400078' "$tmp" \
       && grep -q '^  LOAD ' "$tmp"; then
        ok "readelf -h -l accepts min-1"
    else
        bad "readelf -h -l accepts min-1" "$(head -n 1 "$tmp")"
    fi
fi

# -t x86_64-linux writes an ELF64 executable on any host, so unlike the
# readelf check above these bytes are checked everywhere, the Mac included
"$reclang" -t x86_64-linux -o "$elf" "$root/test/min-1.rec" > /dev/null 2>&1
status=$?
if [ "$status" -eq 0 ]; then
    ok "reclang -t x86_64-linux compiles test/min-1.rec"
else
    bad "reclang -t x86_64-linux compiles test/min-1.rec" "exit status $status"
fi

check_hex "x86_64-linux min-1 is EM_X86_64" "$elf" 18 3e00
check_hex "x86_64-linux min-1 entry is 0x400078" "$elf" 24 7800400000000000
# code at 120: mov rax, 1; mov rdi, 1; mov rsi, str0; mov rdx, 14; syscall;
# mov rax, 60; mov rdi, 42; syscall; str0: "Hello, world!", 10
# str0 sits 64 bytes into the code, so it loads 0x400078 + 0x40 = 0x4000b8
check_hex "x86_64-linux min-1 code" "$elf" 120 \
48b8010000000000000048bf010000000000000048beb80040000000000048ba0e000000000000000f0548b83c0000000000000048bf2a000000000000000f0548656c6c6f2c20776f726c64210a

# -t aarch64-linux writes an ELF64 executable on any host, so like the
# x86-64 checks above its bytes are checked everywhere, and it runs where it can
"$reclang" -t aarch64-linux -o "$elfarm" "$root/test/min-1.rec" > /dev/null 2>&1
status=$?
if [ "$status" -eq 0 ]; then
    ok "reclang -t aarch64-linux compiles test/min-1.rec"
else
    bad "reclang -t aarch64-linux compiles test/min-1.rec" "exit status $status"
fi

check_hex "aarch64-linux min-1 is EM_AARCH64" "$elfarm" 18 b700
check_hex "aarch64-linux min-1 entry is 0x400078" "$elfarm" 24 7800400000000000
# aarch64 loads on 64 KiB boundaries; p_align is the last Phdr field, at 64 + 48
check_hex "aarch64-linux min-1 segment align is 0x10000" "$elfarm" 112 0000010000000000
# code at 120: mov x8, 64; mov x0, 1; adr x1, str0; mov x2, 14; svc 0;
# mov x8, 93; mov x0, 42; svc 0; str0: "Hello, world!", 10
check_hex "aarch64-linux min-1 code" "$elfarm" 120 \
080880d2200080d2c1000010c20180d2010000d4a80b80d2400580d2010000d448656c6c6f2c20776f726c64210a

if [ "$host" = aarch64-linux ]; then
    "$elfarm" > "$tmp" 2>&1
    status=$?
    if [ "$status" -eq 42 ] && printf 'Hello, world!\n' | cmp -s - "$tmp"; then
        ok "aarch64-linux min-1 runs"
    else
        bad "aarch64-linux min-1 runs" "exit status $status, output '$(cat "$tmp")'"
    fi
else
    skipped "aarch64-linux min-1 runs" "$host cannot run aarch64-linux output"
fi

# -t aarch64-macos writes a signed Mach-O executable on any host; its bytes
# are checked everywhere, and it runs where it can
"$reclang" -t aarch64-macos -o "$cross" "$root/test/min-1.rec" > /dev/null 2>&1
status=$?
if [ "$status" -eq 0 ]; then
    ok "reclang -t aarch64-macos compiles test/min-1.rec"
else
    bad "reclang -t aarch64-macos compiles test/min-1.rec" "exit status $status"
fi

check_hex "aarch64-macos min-1 has the Mach-O 64 magic" "$cross" 0 cffaedfe
check_hex "aarch64-macos min-1 is arm64" "$cross" 4 0c000001
# code at 0x260: mov x16, 4; mov x0, 1; adr x1, str0; mov x2, 14; svc 128;
# mov x16, 1; mov x0, 42; svc 128; str0: "Hello, world!", 10
check_hex "aarch64-macos min-1 code" "$cross" 0x260 \
900080d2200080d2c1000010c20180d2011000d4300080d2400580d2011000d448656c6c6f2c20776f726c64210a

if [ "$host" = aarch64-macos ]; then
    "$cross" > "$tmp" 2>&1
    status=$?
    if [ "$status" -eq 42 ] && printf 'Hello, world!\n' | cmp -s - "$tmp"; then
        ok "aarch64-macos min-1 runs"
    else
        bad "aarch64-macos min-1 runs" "exit status $status, output '$(cat "$tmp")'"
    fi

    # reclang signs its output itself, so the system must accept the signature
    if codesign --verify --strict "$cross" > "$tmp" 2>&1; then
        ok "codesign --verify --strict accepts min-1"
    else
        bad "codesign --verify --strict accepts min-1" "$(cat "$tmp")"
    fi

    # the default target is this host's, so both ways give the same file
    # (same basename: the signature carries it as the identifier)
    "$reclang" -o "$dir1/min-1" "$root/test/min-1.rec" > /dev/null 2>&1
    "$reclang" -t aarch64-macos -o "$dir2/min-1" "$root/test/min-1.rec" > /dev/null 2>&1
    if cmp -s "$dir1/min-1" "$dir2/min-1"; then
        ok "the default target and -t aarch64-macos give the same file"
    else
        bad "the default target and -t aarch64-macos give the same file"
    fi
else
    skipped "aarch64-macos min-1 runs" "$host cannot run aarch64-macos output"
fi

echo "$pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ]
