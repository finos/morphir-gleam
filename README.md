[![FINOS - Incubating](https://cdn.jsdelivr.net/gh/finos/contrib-toolbox@master/images/badge-incubating.svg)](https://community.finos.org/docs/governance/Software-Projects/stages/incubating)

# Morphir Gleam

Gleam tooling for [Morphir](https://morphir.finos.org) and the Morphir ecosystem. This repository is a multi-module monorepo providing Gleam implementations of Morphir components.

## Overview

Morphir is a library of tools that work to capture business logic as data. This repository provides Gleam ports of Morphir components, taking advantage of Gleam's similarities to Elm (the language used in the reference implementation at [finos/morphir-elm](https://github.com/finos/morphir-elm)).

## Packages

| Package | Description |
|---------|-------------|
| [morphir_models](./packages/morphir_models) | Gleam port of the Morphir IR (Intermediate Representation) |
| [morphir_cli](./packages/morphir_cli) | CLI tooling for working with Morphir IR |

## Installation

### Quick Install (Recommended)

#### Using mise (Recommended for developers)

If you have [mise](https://mise.jdx.dev/) installed, you can install `morphir-gleam` as a global tool:

```sh
# Install latest version
mise use -g github:finos/morphir-gleam

# Install specific version
mise use -g github:finos/morphir-gleam@v0.1.0

# Verify installation
morphir-gleam version
```

This automatically downloads the correct binary for your platform and manages it through mise.

#### Using install scripts

Install the `morphir-gleam` CLI directly from GitHub releases:

**Linux and macOS:**
```sh
# Install latest version
curl -fsSL https://raw.githubusercontent.com/finos/morphir-gleam/main/install.sh | bash

# Install specific version
curl -fsSL https://raw.githubusercontent.com/finos/morphir-gleam/main/install.sh | bash -s v0.1.0
```

**Windows (PowerShell):**
```powershell
# Install latest version
irm https://raw.githubusercontent.com/finos/morphir-gleam/main/install.ps1 | iex

# Install specific version
$env:VERSION="v0.1.0"; irm https://raw.githubusercontent.com/finos/morphir-gleam/main/install.ps1 | iex
```

### Manual Download

Download pre-built binaries from the [releases page](https://github.com/finos/morphir-gleam/releases/latest):

- **Linux x64**: `morphir-gleam-linux-x64`
- **Linux ARM64**: `morphir-gleam-linux-arm64`
- **macOS x64** (Intel): `morphir-gleam-macos-x64`
- **macOS ARM64** (Apple Silicon): `morphir-gleam-macos-arm64`
- **Windows x64**: `morphir-gleam-windows-x64.exe`

After downloading:

```sh
# Linux/macOS: Make executable and move to PATH
chmod +x morphir-gleam-*
sudo mv morphir-gleam-* /usr/local/bin/morphir-gleam

# Windows: Move to a directory in your PATH
move morphir-gleam-windows-x64.exe C:\Windows\System32\morphir-gleam.exe
```

### Using the CLI

```sh
# Show help
morphir-gleam --help

# Show version
morphir-gleam version

# Show about information
morphir-gleam about
```

### Building from Source

If you want to contribute or build from source, you'll need [mise](https://mise.jdx.dev/) for tool version management.

```sh
# Install mise (if not already installed)
curl https://mise.run | sh

# Install project dependencies (Gleam, Erlang, Bun)
mise install

# Build all packages
mise run build

# Run tests
mise run test

# Build executable
mise run build-exe
```

## OpenSpec change proposals

New changes use the shared `html-design` OpenSpec extension from
[Mission Control](https://github.com/moonrockz/mission-control/tree/main/apps/openspec-ext).
It produces proposal/spec/tasks documents and a standalone `design.html` with inline
CSS and SVG. The committed schema and ownership lock work without a sibling checkout
or an unpublished package dependency. Keep project policy in `openspec/config.yaml`.

`mise install` installs the pinned OpenSpec 1.14.3, Node.js and MoonBit tooling.
The shared checker uses MoonBit as a development tool; it does not affect Gleam packages.
The MoonBit binary archive needs its matching core library on a fresh machine.
Complete the pinned SDK once on Linux/macOS:

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | \
  MOON_HOME="$(mise where http:moonbit)" bash -s -- "$(mise current http:moonbit)"
mise exec -- moon update
```

On Windows, run the matching official installer in PowerShell:

```powershell
$env:MOON_HOME = mise where http:moonbit
$env:MOONBIT_INSTALL_VERSION = mise current http:moonbit
Invoke-RestMethod https://cli.moonbitlang.com/install/powershell.ps1 | Invoke-Expression
mise exec -- moon update
```

```sh
mise run openspec:check      # Detect missing or edited managed files
mise run openspec:validate   # Validate the schema and all proposal/spec artifacts
mise run openspec:test       # Run shared workflow and setup-isolation tests
mise run openspec:setup      # Regenerate core agent skills using isolated preferences
```

Use the `openspec-propose` skill to start a change. The six core skills are committed
for Codex/universal agents, Claude, Copilot, Cursor, Grok, Gemini and OpenCode.
Existing `pr-monitor` skills remain available. Track proposals in GitHub issues and
follow CONTRIBUTING.md for FINOS review and CLA requirements.

To update the managed bundle, use the selected version of Mission Control's installer
from its checkout, then commit the generated files and lock. The `openspec-ext` module
is awaiting publication; do not add an unpublished registry dependency.

## Project Structure

```
morphir-gleam/
├── .mise.toml              # Tool versions (Gleam 1.14.0, Erlang 27)
├── packages/
│   ├── morphir_models/     # Morphir IR types package
│   │   ├── gleam.toml
│   │   ├── src/
│   │   │   ├── morphir_models.gleam
│   │   │   └── morphir/ir/
│   │   │       ├── name.gleam
│   │   │       ├── path.gleam
│   │   │       ├── qname.gleam
│   │   │       ├── fqname.gleam
│   │   │       ├── access_controlled.gleam
│   │   │       ├── documented.gleam
│   │   │       ├── literal.gleam
│   │   │       ├── type_.gleam
│   │   │       ├── value.gleam
│   │   │       ├── module.gleam
│   │   │       └── package.gleam
│   │   └── test/
│   └── morphir_cli/        # CLI tooling package
│       ├── gleam.toml
│       ├── src/
│       │   ├── morphir_cli.gleam
│       │   └── morphir_cli/commands/
│       │       ├── about.gleam
│       │       └── version.gleam
│       └── test/
└── README.md
```

## Usage Example

```gleam
import morphir/ir/name
import morphir/ir/fqname
import morphir/ir/type_

// Create a name from various conventions
let my_name = name.from_string("myVariableName")
// Result: ["my", "variable", "name"]

// Convert to different naming conventions
name.to_snake_case(my_name)   // "my_variable_name"
name.to_camel_case(my_name)   // "myVariableName"
name.to_title_case(my_name)   // "MyVariableName"

// Create fully qualified type references
let int_type = fqname.fqn("Morphir.SDK", "Basics", "Int")

// Build type expressions
let string_type = type_.Reference(
  Nil,
  fqname.fqn("Morphir.SDK", "String", "String"),
  [],
)
```

## Roadmap

1. ✅ Core IR types (Name, Path, QName, FQName)
2. ✅ Type system (Type, Specification, Definition)
3. ✅ Value system (Value, Pattern, Definition)
4. ✅ Module and Package representations
5. ✅ CLI tooling foundation (morphir_cli)
6. 🔲 JSON serialization/deserialization
7. 🔲 IR validation utilities
8. 🔲 SDK type mappings
9. 🔲 Code generation commands

## Related Projects

- [morphir-elm](https://github.com/finos/morphir-elm) - Reference Morphir implementation in Elm
- [morphir](https://github.com/finos/morphir) - Next-gen Morphir tooling
- [morphir.finos.org](https://morphir.finos.org) - Morphir documentation

## Contributing

For any questions, bugs or feature requests please open an [issue](https://github.com/finos/morphir-gleam/issues).
For anything else please send an email to morphir@finos.org.

To submit a contribution:
1. Fork it (<https://github.com/finos/morphir-gleam/fork>)
2. Create your feature branch (`git checkout -b feature/fooBar`)
3. Read our [contribution guidelines](.github/CONTRIBUTING.md) and [Community Code of Conduct](https://www.finos.org/code-of-conduct)
4. Commit your changes (`git commit -am 'Add some fooBar'`)
5. Push to the branch (`git push origin feature/fooBar`)
6. Create a new Pull Request

_NOTE:_ Commits and pull requests to FINOS repositories will only be accepted from those contributors with an active, executed Individual Contributor License Agreement (ICLA) with FINOS OR who are covered under an existing and active Corporate Contribution License Agreement (CCLA) executed with FINOS. Commits from individuals not covered under an ICLA or CCLA will be flagged and blocked by the FINOS Clabot tool (or [EasyCLA](https://community.finos.org/docs/governance/Software-Projects/easycla)). Please note that some CCLAs require individuals/employees to be explicitly named on the CCLA.

*Need an ICLA? Unsure if you are covered under an existing CCLA? Email [help@finos.org](mailto:help@finos.org)*

## License

Copyright 2026 FINOS

Distributed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

SPDX-License-Identifier: [Apache-2.0](https://spdx.org/licenses/Apache-2.0)
