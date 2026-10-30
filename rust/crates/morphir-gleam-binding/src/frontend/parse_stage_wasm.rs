//! Parse-stage emission behavior for WebAssembly extensions.

use super::ast::ModuleIR;
use std::path::{Path, PathBuf};

/// One parsed module and the source document responsible for it.
pub(crate) struct ParseStageModule<'a> {
    pub(crate) module_name: &'a str,
    pub(crate) uri: &'a str,
    pub(crate) module: &'a ModuleIR,
}

/// An emission failure and, when applicable, its responsible source document.
#[derive(Debug)]
pub(crate) struct EmitFailure {
    pub(crate) message: String,
    pub(crate) uri: Option<String>,
}

/// The state of parse-stage output after an emission attempt.
#[derive(Debug)]
pub(crate) enum EmitParseStageOutcome {
    /// All requested outputs were atomically installed.
    Committed { cleanup_warning: Option<String> },
    /// No requested output remains partially updated.
    RolledBack { failure: EmitFailure },
    /// Rollback failed; transaction backups were retained at `recovery_path`.
    // Kept for the shared diagnostic handler; the guest never stages filesystem recovery.
    #[allow(dead_code)]
    RecoveryRequired {
        failure: EmitFailure,
        recovery_path: PathBuf,
    },
}

/// Report that host filesystem parse-stage emission is unavailable on wasm32.
pub(crate) fn emit_parse_stage(
    _output_dir: &Path,
    modules: &[ParseStageModule<'_>],
) -> EmitParseStageOutcome {
    if modules.is_empty() {
        return EmitParseStageOutcome::Committed {
            cleanup_warning: None,
        };
    }
    let module_count = modules.len();
    // Read the fields that native emission uses, so wasm32 builds have no
    // dead-code warnings for them.
    for module in modules {
        let _ = (module.module_name, module.uri, module.module);
    }
    EmitParseStageOutcome::RolledBack {
        failure: EmitFailure {
            message: format!(
                "Parse-stage filesystem emission is unsupported on wasm32 ({module_count} module(s) requested)"
            ),
            uri: None,
        },
    }
}
