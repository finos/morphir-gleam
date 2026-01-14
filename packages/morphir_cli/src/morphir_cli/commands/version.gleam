//// Version information for morphir-cli.

import gleam/io
import glint

/// The current version of morphir-cli.
pub const version = "0.1.0"

/// Returns a formatted version string.
pub fn version_string() -> String {
  "morphir-cli " <> version
}

/// Creates the version command.
pub fn command() -> glint.Command(Nil) {
  use <- glint.command_help("Display version information")
  use _named, _args, _flags <- glint.command()

  io.println(version_string())
  Nil
}
