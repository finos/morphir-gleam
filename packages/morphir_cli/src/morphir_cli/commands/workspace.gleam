////
//// Workspace management commands for the Morphir CLI.
////

import gleam/io
import glint
import simplifile

/// Register the workspace command
pub fn command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Morphir workspace management. Use 'morphir workspace --help' for available commands.",
  )
  use _named, _args, _flags <- glint.command()

  io.println("Use 'morphir workspace --help' to see available commands")
  Nil
}

/// Creates the workspace init command
pub fn init_command() -> glint.Command(Nil) {
  use <- glint.command_help("Initialize a new Morphir workspace")
  use _named, _args, _flags <- glint.command()

  io.println("Initializing Morphir workspace...")

  // Create default morphir.toml
  let default_config = generate_default_config()

  case simplifile.write("morphir.toml", default_config) {
    Ok(_) -> {
      io.println("✓ Created morphir.toml")
      io.println("")
      io.println("Workspace initialized successfully!")
      io.println("")
      io.println("Next steps:")
      io.println("  1. Edit morphir.toml to configure your workspace")
      io.println("  2. Add projects to the workspace/members array")
      io.println("  3. Run 'morphir project list' to verify configuration")
    }
    Error(err) -> {
      io.println(
        "✗ Failed to create morphir.toml: "
        <> simplifile.describe_error(err),
      )
    }
  }

  Nil
}

/// Generate default morphir.toml content
fn generate_default_config() -> String {
  "# Morphir Workspace Configuration
# See: https://morphir.finos.org/docs/spec/morphir-toml/morphir-toml-specification/

[morphir]
# SemVer constraint for compatible IR versions
version = \">=1.0.0\"

[workspace]
# Workspace root directory (defaults to directory containing this file)
# root = \".\"

# Generated artifacts location (default: .morphir)
output_dir = \".morphir\"

# Glob patterns for discovering projects
members = [
    \"packages/*\",
    \"projects/*\",
]

# Patterns to exclude from discovery
exclude = [
    \"**/build/**\",
    \"**/node_modules/**\",
]

# Default project when unspecified
# default_member = \"main\"

[ir]
# IR format version (1-10, default: 3)
format_version = 3

# Treat warnings as errors
strict_mode = false

[codegen]
# Output format: pretty, compact, or minified
output_format = \"pretty\"
"
}
