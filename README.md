# Recreational Programming Language

> Hey, this is a project in a very early stage of development.
> Right now, reclang 0.0.3 compiles a small subset of the language
> (exactly three functions: `main`, `writeln`, `exit`)
> to an x86-64 Linux ELF64 executable. It prints its tokens, AST and
> generated assembly to stdout as it goes. The language itself is not
> documented yet, but I'm working on that.

## Install

### With the install script

```sh
curl -fsSL https://raw.githubusercontent.com/reclang/reclang/main/packaging/install.sh | sh
```

Downloads the latest release and installs it and its man page under `~/.local`.
Pipe into `sudo sh` instead to install under `/usr/local` for everyone.

`PREFIX=dir` picks another prefix, `VERSION=X.Y.Z` pins a release.
The script never calls `sudo` itself and never writes outside the prefix,
and prints a `PATH` or `MANPATH` line if one is needed.

To uninstall, remove `PREFIX/bin/reclang` and `PREFIX/share/man/man1/reclang.1`.

### By hand from GitHub Releases

Prebuilt binaries live at
<https://github.com/reclang/reclang/releases>.
Download `reclang-X.Y.Z-linux-x86_64.tar.gz` and `SHA256SUMS`, then:

```sh
sha256sum -c --ignore-missing SHA256SUMS
tar -xzf reclang-X.Y.Z-linux-x86_64.tar.gz
```

The tarball contains `reclang`, `reclang.1` and `LICENSE`.
Put the binary somewhere on your `PATH` and the page on your manpath,
for example `~/.local/bin` and `~/.local/share/man/man1`.

Prebuilt binaries are Linux x86-64 only today and need glibc 2.34 or newer:
Ubuntu 22.04, Debian 12 and anything newer. Elsewhere, build from source.

### From source

Needs ldc 1.36 or newer (D 2.106); dmd 2.106 also works, gdc is not tested.
Run `make`, `make check` and `make install` as below.

### How to build

- `make`             - builds `reclang`
- `make check`       - runs `test/run.sh`
- `make install`     - installs binary and man page under `PREFIX`

## License

Apache License 2.0 with LLVM Exception (`Apache-2.0 WITH LLVM-exception`).
See [LICENSE](LICENSE).
