////
//// Project management commands for the Morphir CLI.
////

import gleam/io
import gleam/list
import gleam/option
import gleam/string
import glint
import morphir/tooling/workspace

/// Register the project command and its subcommands
pub fn command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Morphir project management. Use 'morphir project --help' for available commands.",
  )
  use _named, _args, _flags <- glint.command()

  io.println("Use 'morphir project --help' to see available commands")
  Nil
}

/// Creates the project list command
pub fn list_command() -> glint.Command(Nil) {
  use <- glint.command_help("List all projects in the current workspace")
  use _named, _args, _flags <- glint.command()

  io.println("Listing projects in workspace...")
  io.println("")

  // Try to detect workspace from current directory
  case workspace.find_workspace_root(".") {
    Ok(workspace_root) -> {
      io.println("Workspace root: " <> workspace_root)
      io.println("")

      // Load workspace configuration
      case workspace.detect_workspace(workspace_root) {
        Ok(ws) -> {
          // Display workspace info
          case ws.config.workspace {
            option.Some(ws_config) -> {
              case ws_config.output_dir {
                option.Some(output) ->
                  io.println("Output directory: " <> output)
                option.None -> Nil
              }

              case ws_config.members {
                option.Some(members) -> {
                  io.println(
                    "Member patterns: "
                    <> string.join(members, ", "),
                  )
                }
                option.None -> Nil
              }
            }
            option.None -> Nil
          }

          io.println("")

          // List discovered projects
          case list.length(ws.members) {
            0 -> {
              io.println("No projects found in workspace.")
              io.println("")
              io.println("Tips:")
              io.println(
                "  - Check the 'members' patterns in morphir.toml",
              )
              io.println(
                "  - Ensure project directories contain morphir.toml files",
              )
            }
            count -> {
              io.println("Found " <> string.inspect(count) <> " project(s):")
              io.println("")

              list.each(ws.members, fn(project) {
                io.println("  • " <> project.name)
                io.println("    Path: " <> project.path)
              })
            }
          }
        }
        Error(err) -> {
          io.println("✗ Failed to load workspace: " <> err)
        }
      }
    }
    Error(err) -> {
      io.println("✗ " <> err)
      io.println("")
      io.println("No workspace found in current directory or ancestors.")
      io.println("Run 'morphir workspace init' to create a new workspace.")
    }
  }

  Nil
}
