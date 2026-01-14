////
//// The `morphir_tooling` package provides workspace and project management
//// utilities for Morphir projects.
////
//// This package helps detect and work with morphir.toml files, manage
//// workspace hierarchies, and provide context for CLI commands.
////

import gleam/option.{type Option}
import morphir_config.{type MorphirConfig}

/// Represents a Morphir workspace containing one or more projects
pub type Workspace {
  Workspace(
    /// Path to the workspace root directory
    root: String,
    /// Parsed workspace configuration
    config: MorphirConfig,
    /// List of discovered member projects
    members: List(Project),
  )
}

/// Represents a single Morphir project within a workspace
pub type Project {
  Project(
    /// Path to the project directory
    path: String,
    /// Project name from configuration
    name: String,
    /// Parsed project configuration
    config: Option(MorphirConfig),
  )
}

/// Context for running Morphir commands
pub type ToolContext {
  ToolContext(
    /// Current working directory
    cwd: String,
    /// Detected workspace (if any)
    workspace: Option(Workspace),
    /// Currently active project (if any)
    current_project: Option(Project),
  )
}
