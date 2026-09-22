# Recreational Programming Language

> Hey, this is a project in a very early stage of development.
> Right now, reclang 0.0.7 compiles a small subset of the language
> (exactly three functions: `main`, `writeln`, `exit`)
> to an x86-64 or arm64 Linux ELF64, or an arm64 macOS Mach-O executable.
> It prints its tokens, AST and generated assembly to stdout as it goes.
> The language itself is not documented yet, but I'm working on that.

## Usage

The compiler supports three targets now: 

- `x86_64-linux`
- `aarch64-linux`
- `aarch64-macos`.

Any host builds for any of them:

```sh
reclang -o hello hello.rec                    # for current system
reclang -t aarch64-linux -o hello hello.rec   # for an arm64 Linux box
reclang -t aarch64-macos -o hello hello.rec   # for an Apple Silicon Mac
```

## Install

### With the install script

```sh
curl -fsSL https://raw.githubusercontent.com/reclang/rec/main/packaging/install.sh | sh
```

Downloads the latest release and installs it and its man page under `~/.local`.
Pipe into `sudo sh` instead to install under `/usr/local` for everyone.

`PREFIX=dir` picks another prefix, `VERSION=X.Y.Z` pins a release.
The script never calls `sudo` itself and never writes outside the prefix,
and prints a `PATH` or `MANPATH` line if one is needed.

To uninstall, remove `PREFIX/bin/reclang` and `PREFIX/share/man/man1/reclang.1`.

### With Homebrew

```sh
brew install reclang/rec/reclang
```

That taps `reclang/rec` and trusts this one formula. To trust the whole tap
and use the short name:

```sh
brew tap reclang/rec
brew trust reclang/rec
brew install reclang
```

That allows Homebrew to load every current and future formula, cask and external command from that tap.

In either case, run `brew upgrade reclang` to upgrade.

The formula builds from source with ldc, which Homebrew installs for the
build together with LLVM.

### By hand from GitHub Releases

Prebuilt binaries live at
<https://github.com/reclang/rec/releases>. Download the tarball for your
system and `SHA256SUMS`, then:

```sh
sha256sum -c --ignore-missing SHA256SUMS     # macOS: shasum -a 256 -c ...
tar -xzf reclang-X.Y.Z-linux-x86_64.tar.gz
```

The tarball contains `reclang`, `reclang.1` and `LICENSE`.
Put the binary somewhere on your `PATH` and the page on your manpath,
for example `~/.local/bin` and `~/.local/share/man/man1`.

- The Linux binaries need glibc 2.34 or newer: Ubuntu 22.04, Debian 12 and
anything newer.
- The macOS binary is for Apple Silicon, macOS 12 or newer. The build is
ad-hoc signed rather than notarised; use the `curl` command above to download
and install, since browsers marks its tarball as quarantined and macOS
refuses to run the binary.
To clear it by hand, run `xattr -dr com.apple.quarantine reclang`.
- MacOS on Intel Macs: build from source.

### From source

Needs ldc 1.36 or newer (D 2.106); dmd 2.106 also works, gdc is not tested.
On macOS, `brew install ldc`. Run `make`, `make check` and `make install`
as below. The compiler itself builds and runs on both Linux and macOS.

### How to build

- `make`             - builds `reclang`
- `make check`       - runs `test/run.sh`
- `make install`     - installs binary and man page under `PREFIX`

## License

Apache License 2.0 with LLVM Exception (`Apache-2.0 WITH LLVM-exception`).
See [LICENSE](LICENSE).
