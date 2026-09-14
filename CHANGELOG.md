# Changelog

## [Unreleased]

## [0.0.1] - 2026-09-14

Compiles `test/min-1.rec` to a runnable static x86-64 Linux ELF64:
prints "Hello, world!" and exits with the given status.

### Added

- Simple 2-pass assembler, code generator, parser, tokenizer, preprocessor.
- `reclang --version` reads from the `VERSION` file at build time.
- Makefile with `all`, `check` and `install`.
