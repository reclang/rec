# Changelog

## [0.0.6] - 2026-09-21

Added Aarch64 output for ELF64 files, so the compiler supports three
targets now: x86-64 and arm64 Linux ELF64 and arm64 macOS Mach-O.

### Added

- `aarch64-linux` target: arm64 ELF64 executables for Linux on ARM.
- `-t ARCH-OS` supports three targets:
  - `x86_64-linux`
  - `aarch64-linux`
  - `aarch64-macos`

## [0.0.5] - 2026-09-21

Supports two targets now: x86-64 Linux ELF64 and arm64 macOS Mach-O.
The target defaults to the host, and either host can build for the other.

### Added

- `aarch64-macos` target: arm64 Mach-O executables for Apple Silicon.
- `-t ARCH-OS` supports two targets, `x86_64-linux` and `aarch64-macos`.

### Changed

- The default output file is `a.out`, was `out.o`.
- Errors go to stderr, not stdout.

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
