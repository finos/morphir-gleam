//// Morphir CLI for Gleam
////
//// This is the main entry point for the morphir-cli command line tool.
//// It provides commands for working with Morphir IR files and generating
//// code from Morphir models.

import argv
import gleam/io
import glint
import morphir_cli/commands/about
import morphir_cli/commands/project
import morphir_cli/commands/version
import morphir_cli/commands/workspace

/// Main entry point for the morphir-cli.
pub fn main() {
  glint.new()
  |> glint.with_name("morphir-cli")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: [], do: root_command())
  |> glint.add(at: ["about"], do: about.command())
  |> glint.add(at: ["version"], do: version.command())
  |> glint.add(at: ["workspace"], do: workspace.command())
  |> glint.add(at: ["workspace", "init"], do: workspace.init_command())
  |> glint.add(at: ["project"], do: project.command())
  |> glint.add(at: ["project", "list"], do: project.list_command())
  |> glint.run(argv.load().arguments)
}

fn root_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Morphir tooling for Gleam - work with Morphir IR and generate code",
  )
  use _named, _args, _flags <- glint.command()
  io.println("morphir-cli - Morphir tooling for Gleam")
  io.println("")
  io.println("Use --help to see available commands")
  io.println("Use 'version' command to see version information")
  Nil
}
