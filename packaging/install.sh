#!/bin/sh
#
# reclang installer
#
# Downloads a prebuilt reclang from GitHub Releases, checks it against the
# release's SHA256SUMS and installs it with the layout of `make install`:
#
#     $PREFIX/bin/reclang
#     $PREFIX/share/man/man1/reclang.1
#
# Usage: curl -fsSL https://raw.githubusercontent.com/reclang/reclang/main/packaging/install.sh | sh
#
#     PREFIX     install prefix: ~/.local, or /usr/local when run as root
#     VERSION    release to install as X.Y.Z; the latest release by default
#
#     curl -fsSL ... | sh                    current user, ~/.local
#     curl -fsSL ... | sudo sh               system-wide, /usr/local
#     PREFIX=/opt/reclang sh install.sh
#     VERSION=0.1.0 sh install.sh
#
# Never calls sudo, never writes outside PREFIX. To uninstall, remove the
# two files above. Needs curl or wget, tar, and sha256sum, shasum or openssl.
#
# Release assets are named reclang-VERSION-OS-ARCH[-musl].tar.gz with OS
# linux or macos and ARCH as printed by `uname -m`. Each tarball holds
# reclang, reclang.1 and LICENSE, flat or inside one directory. The
# version comes from the file names in SHA256SUMS, so the latest release
# needs no API call. RECLANG_RELEASES overrides the release base URL for
# mirrors and tests.

set -u

releases=${RECLANG_RELEASES:-https://github.com/reclang/reclang/releases}
releases=${releases%/}

err() {
    echo "install.sh: $1" >&2
    shift
    for line in "$@"; do
        echo "  $line" >&2
    done
    exit 1
}

usage() {
    echo "usage: [PREFIX=dir] [VERSION=X.Y.Z] sh install.sh" >&2
    echo "install.sh takes no arguments; see the comment at its top" >&2
    exit 2
}

# ---------------------------------------------------------
# Host: os, arch and libc pick the release asset
# ---------------------------------------------------------

detect_platform() {
    os=$(uname -s)
    arch=$(uname -m)
    libc=
    case $os in
        Linux)
            os=linux
            for f in /lib/ld-musl-*.so.1; do
                [ -e "$f" ] && libc=-musl
            done
            if [ -z "$libc" ] && ldd --version 2>&1 | grep -qi musl; then
                libc=-musl
            fi
            ;;
        Darwin)
            os=macos
            ;;
        *)
            err "no prebuilt reclang for $os $arch" \
                "build from source: https://github.com/reclang/reclang"
            ;;
    esac
    platform=$os-$arch$libc
}

# ---------------------------------------------------------
# Tools: pick a downloader and a SHA-256 command
# ---------------------------------------------------------

pick_tools() {
    if command -v curl > /dev/null 2>&1; then
        fetch() { curl -fsSL -o "$2" "$1"; }
    elif command -v wget > /dev/null 2>&1; then
        fetch() { wget -q -O "$2" "$1"; }
    else
        err "need curl or wget"
    fi

    if command -v sha256sum > /dev/null 2>&1; then
        sha256() { sha256sum "$1" | awk '{ print $1 }'; }
    elif command -v shasum > /dev/null 2>&1; then
        sha256() { shasum -a 256 "$1" | awk '{ print $1 }'; }
    elif command -v openssl > /dev/null 2>&1; then
        sha256() { openssl dgst -sha256 "$1" | awk '{ print $NF }'; }
    else
        err "need sha256sum, shasum or openssl"
    fi

    command -v tar > /dev/null 2>&1 || err "need tar"
}

# ---------------------------------------------------------
# Prefix: ~/.local for a user, /usr/local for root
# ---------------------------------------------------------

pick_prefix() {
    if [ -n "${PREFIX:-}" ]; then
        prefix=${PREFIX%/}
    elif [ "$(id -u)" -eq 0 ]; then
        prefix=/usr/local
    elif [ -n "${HOME:-}" ]; then
        prefix=$HOME/.local
    else
        err "HOME is not set; pass PREFIX"
    fi
    bindir=$prefix/bin
    mandir=$prefix/share/man/man1

    mkdir -p "$bindir" "$mandir" 2> /dev/null \
        && [ -w "$bindir" ] && [ -w "$mandir" ] \
        || err "cannot write to $prefix" \
               "run as root for /usr/local, or pass a writable PREFIX"
}

# ---------------------------------------------------------
# Release: SHA256SUMS names the assets and, for the latest
# release, tells the version
# ---------------------------------------------------------

find_release() {
    version=${VERSION:-}
    version=${version#v}
    if [ -n "$version" ]; then
        release=$releases/download/v$version
    else
        release=$releases/latest/download
    fi

    fetch "$release/SHA256SUMS" "$tmp/SHA256SUMS" \
        || err "cannot download $release/SHA256SUMS" \
               "is there such a release?"

    if [ -z "$version" ]; then
        version=$(awk '
            {
                n = $2
                sub(/^\*/, "", n)
                if (n ~ /^reclang-.*\.tar\.gz$/) {
                    sub(/^reclang-/, "", n)
                    sub(/-(linux|macos)-.*$/, "", n)
                    sub(/\.tar\.gz$/, "", n)
                    print n
                    exit
                }
            }' "$tmp/SHA256SUMS")
        [ -n "$version" ] \
            || err "cannot tell the version from $release/SHA256SUMS"
        release=$releases/download/v$version
    fi

    asset=reclang-$version-$platform.tar.gz
    expected=$(awk -v f="$asset" '
        {
            n = $2
            sub(/^\*/, "", n)
            if (n == f) {
                print $1
                exit
            }
        }' "$tmp/SHA256SUMS")
    if [ -z "$expected" ]; then
        echo "install.sh: no prebuilt reclang $version for $platform; the release has:" >&2
        awk '{ print "  " $2 }' "$tmp/SHA256SUMS" >&2
        echo "  build from source: https://github.com/reclang/reclang" >&2
        exit 1
    fi
}

# ---------------------------------------------------------
# Download, verify, extract
# ---------------------------------------------------------

download() {
    echo "downloading $release/$asset"
    fetch "$release/$asset" "$tmp/$asset" \
        || err "cannot download $release/$asset"

    actual=$(sha256 "$tmp/$asset")
    [ "$actual" = "$expected" ] \
        || err "checksum mismatch for $asset" \
               "expected $expected" \
               "got      $actual"

    mkdir "$tmp/x" \
        && tar -xzf "$tmp/$asset" -C "$tmp/x" \
        || err "cannot extract $asset"

    bin=$(find "$tmp/x" -maxdepth 2 -type f -name reclang | head -n 1)
    man=$(find "$tmp/x" -maxdepth 2 -type f -name reclang.1 | head -n 1)
    [ -n "$bin" ] || err "$asset does not contain reclang"
    [ -n "$man" ] || err "$asset does not contain reclang.1"
}

# ---------------------------------------------------------
# Install and check the result
# ---------------------------------------------------------

install_files() {
    install -m 755 "$bin" "$bindir/reclang" \
        || err "cannot install $bindir/reclang"
    install -m 644 "$man" "$mandir/reclang.1" \
        || err "cannot install $mandir/reclang.1"

    # mandoc warns on every `man reclang` until its index knows the page
    if command -v makewhatis > /dev/null 2>&1; then
        makewhatis "$prefix/share/man" > /dev/null 2>&1
    fi

    reported=$("$bindir/reclang" --version 2>&1)
    case $reported in
        *"$version"*) ;;
        *) err "$bindir/reclang --version failed: $reported" \
               "expected $version; the file is left in place" ;;
    esac

    echo "installed reclang $version"
    echo "  $bindir/reclang"
    echo "  $mandir/reclang.1"

    # Show $HOME in hints so they can be pasted into a shell rc file
    shown=$prefix
    if [ -n "${HOME:-}" ]; then
        case $prefix in
            "$HOME"/*) shown='$HOME'${prefix#"$HOME"} ;;
        esac
    fi

    case ":${PATH:-}:" in
        *":$bindir:"*) ;;
        *) echo "add to PATH:     export PATH=\"$shown/bin:\$PATH\"" ;;
    esac

    # man-db and macOS derive the manpath from PATH; mandoc needs MANPATH
    if command -v man > /dev/null 2>&1 \
       && ! PATH="$bindir:${PATH:-}" man -w reclang > /dev/null 2>&1; then
        echo "let man find it: export MANPATH=\":$shown/share/man\""
    fi
}

main() {
    [ $# -eq 0 ] || usage

    detect_platform
    pick_tools
    pick_prefix

    tmp=$(mktemp -d "${TMPDIR:-/tmp}/reclang-install.XXXXXX") \
        || err "cannot create a temporary directory"
    trap 'rm -rf "$tmp"' EXIT
    trap 'exit 1' INT TERM HUP

    find_release
    download
    install_files
}

main "$@"
