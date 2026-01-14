//// About command - displays information about morphir-cli.

import gleam/io
import glint
import morphir_cli/commands/version

/// Creates the about command.
pub fn command() -> glint.Command(Nil) {
  use <- glint.command_help("Display information about morphir-cli")
  use _named, _args, _flags <- glint.command()

  io.println("morphir-cli " <> version.version)
  io.println("")
  io.println("Gleam tooling for Morphir - capturing business logic as data.")
  io.println("")
  io.println(
    "Morphir is a library of tools that work to capture business logic",
  )
  io.println("as data, enabling code generation, documentation, and analysis")
  io.println("across multiple platforms and languages.")
  io.println("")
  io.println("This Gleam implementation provides:")
  io.println("  - morphir_models: Core Morphir IR types")
  io.println("  - morphir_cli:    CLI tooling (this package)")
  io.println("")
  io.println("Related projects:")
  io.println("  - https://morphir.finos.org")
  io.println("  - https://github.com/finos/morphir-elm")
  io.println("  - https://github.com/finos/morphir")
  io.println("")
  io.println("License: Apache-2.0")
  io.println("Copyright 2026 FINOS")

  Nil
}
