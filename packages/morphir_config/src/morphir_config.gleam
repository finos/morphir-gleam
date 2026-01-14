////
//// The `morphir_config` package provides types and utilities for parsing and
//// validating morphir.toml configuration files.
////
//// This package implements the Morphir TOML specification:
//// https://morphir.finos.org/docs/spec/morphir-toml/morphir-toml-specification/
////

import gleam/option.{type Option}

/// The root configuration structure for a morphir.toml file.
/// All top-level keys are optional per the specification.
pub type MorphirConfig {
  MorphirConfig(
    morphir: Option(MorphirSection),
    workspace: Option(WorkspaceSection),
    project: Option(ProjectSection),
    ir: Option(IrSection),
    codegen: Option(CodegenSection),
    cache: Option(CacheSection),
    logging: Option(LoggingSection),
    ui: Option(UiSection),
  )
}

/// Core settings and IR version constraints
pub type MorphirSection {
  MorphirSection(
    /// SemVer constraint for compatible IR versions
    version: Option(String),
  )
}

/// Workspace discovery and output layout
pub type WorkspaceSection {
  WorkspaceSection(
    /// Workspace root directory
    root: Option(String),
    /// Generated artifacts location (default: .morphir)
    output_dir: Option(String),
    /// Glob patterns for discovering projects
    members: Option(List(String)),
    /// Patterns to exclude from discovery
    exclude: Option(List(String)),
    /// Default project when unspecified
    default_member: Option(String),
  )
}

/// Project metadata
pub type ProjectSection {
  ProjectSection(
    /// Project identifier
    name: String,
    /// Project version string
    version: Option(String),
    /// Location of source files
    source_directory: Option(String),
    /// Public API modules
    exposed_modules: Option(List(String)),
    /// Optional qualified name prefix
    module_prefix: Option(String),
  )
}

/// IR processing settings
pub type IrSection {
  IrSection(
    /// IR format version (1-10, default: 3)
    format_version: Option(Int),
    /// Treat warnings as errors (default: false)
    strict_mode: Option(Bool),
  )
}

/// Code generation configuration
pub type CodegenSection {
  CodegenSection(
    /// Generation targets (go, typescript, scala, json-schema)
    targets: Option(List(String)),
    /// Custom templates location
    template_dir: Option(String),
    /// Output format: pretty/compact/minified (default: pretty)
    output_format: Option(String),
  )
}

/// Caching behavior configuration
pub type CacheSection {
  CacheSection(enabled: Option(Bool), directory: Option(String))
}

/// Log output settings
pub type LoggingSection {
  LoggingSection(level: Option(String), format: Option(String))
}

/// UI/TUI preferences
pub type UiSection {
  UiSection(theme: Option(String), color: Option(Bool))
}
