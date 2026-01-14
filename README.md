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

### Prerequisites

This project uses [mise](https://mise.jdx.dev/) for tool version management.

```sh
# Install mise (if not already installed)
curl https://mise.run | sh

# Install project dependencies (Gleam + Erlang)
mise install
```

### Building

```sh
# Build all packages
cd packages/morphir_models && gleam build && cd ../..
cd packages/morphir_cli && gleam build && cd ../..

# Run tests
cd packages/morphir_models && gleam test && cd ../..
cd packages/morphir_cli && gleam test && cd ../..
```

### Running the CLI

```sh
cd packages/morphir_cli

# Run the CLI
gleam run

# Show help
gleam run -- --help

# Show version
gleam run -- --version

# Show about information
gleam run -- about
```

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
