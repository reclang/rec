# Changelog

## [0.0.4] - 2026-09-18

Moved to a new repo, https://github.com/reclang/rec,
updated Github workflows and the install.sh file.

## [0.0.3] - 2026-09-16

First release with prebuilt binaries: reclang installs with one command,
no D compiler needed.

## [0.0.2] - 2026-09-16

Github release script and `install.sh` for manual installation. 

### Added

- Prebuilt Linux x86-64 binary on GitHub Releases.
- `packaging/install.sh` downloads a release
  `curl -fsSL https://raw.githubusercontent.com/reclang/reclang/main/packaging/install.sh | sh`

### Changed

- The output file is executable now, without the need for `chmod +x`.

### Fixed

- Programs of 256 bytes or more got a wrong segment size in the ELF
  program header.
- The ELF header uses the System V OS/ABI and 4 KiB segment alignment now.

## [0.0.1] - 2026-09-14

Compiles `test/min-1.rec` to a runnable static x86-64 Linux ELF64:
prints "Hello, world!" and exits with the given status.

### Added

- Simple 2-pass assembler, code generator, parser, tokenizer, preprocessor.
- `reclang --version` reads from the `VERSION` file at build time.
- Makefile with `all`, `check` and `install`.
