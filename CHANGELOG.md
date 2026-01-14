# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial Morphir IR type definitions in `morphir_models` package
  - Core types: `Name`, `Path`, `QName`, `FQName`
  - Type system: `Type`, `Specification`, `Definition`
  - Value system: `Value`, `Pattern`, `Definition`
  - Module and Package structures
  - Access control types: `Public`, `Private`
  - Documentation wrapper type
- CLI tooling in `morphir_cli` package
  - Basic CLI structure with glint
  - `version` command to display version information
  - `about` command to display project information
- Mise configuration for tool management
  - Tool versions: Gleam 1.14.0, Erlang 27, Bun latest
  - File-based tasks: `build`, `test`, `format`, `check`, `build-exe`
  - XDG-compliant configuration in `.config/mise/`
- Build tooling
  - TypeScript-based `build-exe` task using bun
  - Standalone executable compilation (~93MB)
  - JavaScript target support for CLI
- CI/CD workflows
  - GitHub Actions CI workflow (format, check, test, build)
  - GitHub Actions release workflow with multi-platform builds
  - Cross-compilation support using bun's --target flag (since bun v1.1.5)
  - Platform support: Linux x64/ARM64, macOS x64/ARM64, Windows x64
  - Release staging job validates CHANGELOG and builds for all platforms on release PRs
- Installation options
  - Mise integration via github backend (`mise use -g github:finos/morphir-gleam`)
  - Bash install script for Linux and macOS (`install.sh`)
  - PowerShell install script for Windows (`install.ps1`)
  - Support for installing latest version or specific version
  - Automatic platform detection and PATH configuration
- Repository governance
  - CODEOWNERS file designating @finos/morphir-maintainers as code owners

### Changed

- None

### Deprecated

- None

### Removed

- None

### Fixed

- None

### Security

- None

## [0.1.0] - UNRELEASED

Initial development release. See Unreleased section above for all changes.

[Unreleased]: https://github.com/finos/morphir-gleam/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/finos/morphir-gleam/releases/tag/v0.1.0
