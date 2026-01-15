////
//// Workspace detection and management utilities.
////

import filepath
import gleam/option.{None, Some}
import gleam/result
import morphir/config/parser
import morphir_config
import morphir_tooling.{type Project, type Workspace, Workspace}
import simplifile

/// Find the workspace root by searching for morphir.toml in current dir and ancestors
pub fn find_workspace_root(start_dir: String) -> Result(String, String) {
  find_morphir_toml(start_dir)
}

/// Detect the full workspace context from a starting directory
pub fn detect_workspace(start_dir: String) -> Result(Workspace, String) {
  use root <- result.try(find_workspace_root(start_dir))
  use config <- result.try(load_workspace_config(root))

  // Discover member projects based on workspace configuration
  let members = discover_members(root, config)

  Ok(Workspace(root: root, config: config, members: members))
}

/// Load the morphir.toml configuration from a workspace root
pub fn load_workspace_config(
  workspace_root: String,
) -> Result(morphir_config.MorphirConfig, String) {
  let config_path = filepath.join(workspace_root, "morphir.toml")
  let alt_config_path =
    filepath.join(workspace_root, ".morphir/morphir.toml")

  // Try primary location first, then .morphir subdirectory
  case parser.parse_file(config_path) {
    Ok(config) -> Ok(config)
    Error(_) ->
      case parser.parse_file(alt_config_path) {
        Ok(config) -> Ok(config)
        Error(err) ->
          Error("No morphir.toml found at " <> config_path <> " or " <> alt_config_path <> ": " <> err)
      }
  }
}

/// Discover member projects based on workspace configuration
fn discover_members(
  _workspace_root: String,
  config: morphir_config.MorphirConfig,
) -> List(Project) {
  // Extract member patterns from workspace config
  let _member_patterns = case config.workspace {
    Some(ws) ->
      case ws.members {
        Some(patterns) -> patterns
        None -> []
      }
    None -> []
  }

  // For now, return empty list - full glob matching implementation needed
  // TODO: Implement glob pattern matching to discover projects
  []
}

/// Find morphir.toml by traversing up the directory tree
fn find_morphir_toml(start_dir: String) -> Result(String, String) {
  find_morphir_toml_recursive(start_dir, 0)
}

fn find_morphir_toml_recursive(
  dir: String,
  depth: Int,
) -> Result(String, String) {
  // Prevent infinite loops
  case depth > 20 {
    True -> Error("Max search depth exceeded looking for morphir.toml")
    False -> {
      // Check for morphir.toml in current directory
      let config_path = filepath.join(dir, "morphir.toml")
      let alt_config_path = filepath.join(dir, ".morphir/morphir.toml")

      let has_config = case simplifile.is_file(config_path) {
        Ok(True) -> True
        _ -> False
      }

      let has_alt_config = case simplifile.is_file(alt_config_path) {
        Ok(True) -> True
        _ -> False
      }

      case has_config || has_alt_config {
        True -> Ok(dir)
        False -> {
          // Try parent directory
          let parent = filepath.directory_name(dir)
          case parent == dir || parent == "" {
            True -> Error("No morphir.toml found in current directory or ancestors")
            False -> find_morphir_toml_recursive(parent, depth + 1)
          }
        }
      }
    }
  }
}
