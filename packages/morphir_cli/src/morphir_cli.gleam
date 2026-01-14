//// Morphir CLI for Gleam
////
//// This is the main entry point for the morphir-cli command line tool.
//// It provides commands for working with Morphir IR files and generating
//// code from Morphir models.

import argv
import gleam/io
import glint
import morphir_cli/commands/about
import morphir_cli/commands/version

/// Main entry point for the morphir-cli.
pub fn main() {
  glint.new()
  |> glint.with_name("morphir-cli")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.group_flag(at: [], of: version.flag(), with: handle_version)
  |> glint.add(at: [], do: root_command())
  |> glint.add(at: ["about"], do: about.command())
  |> glint.run(argv.load().arguments)
}

fn handle_version(version_flag: Bool) -> glint.CommandResult(Nil) {
  case version_flag {
    True -> {
      io.println(version.version_string())
      glint.Halt
    }
    False -> glint.Continue
  }
}

fn root_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Morphir tooling for Gleam - work with Morphir IR and generate code",
  )
  use _named, _args, _flags <- glint.command()
  io.println("morphir-cli - Morphir tooling for Gleam")
  io.println("")
  io.println("Use --help to see available commands")
  Nil
}
