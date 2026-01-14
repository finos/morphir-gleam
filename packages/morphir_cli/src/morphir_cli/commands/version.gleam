//// Version information for morphir-cli.

import glint

/// The current version of morphir-cli.
pub const version = "0.1.0"

/// Returns a formatted version string.
pub fn version_string() -> String {
  "morphir-cli " <> version
}

/// Creates a --version flag for the CLI.
pub fn flag() -> glint.Flag(Bool) {
  glint.bool_flag("version")
  |> glint.flag_default(False)
  |> glint.flag_help("Print version information")
}
