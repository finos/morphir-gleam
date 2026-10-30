//! MEP `0.2.0-draft.1` model operations for the tuple `morphir-ir` /
//! `morphir-json` / envelope `0.1.0-draft.1` / IR `4.0.0`.
//!
//! Both operations reuse the MEP `0.1` compile and generate paths. The model
//! payload is the same IR v4 document that `morphir.frontend.compile` returns.
//! The SDK session checks tuples, limits and payload integrity before and
//! after each call; this module checks them again where it decodes bytes.

use crate::GleamExtension;
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use morphir_extension_sdk::model::{
    CompileModelRequest, CompileModelResult, GenerateModelRequest, MODEL_ENVELOPE_VERSION,
    ModelCodec, ModelLayout, ModelOperation, ModelPayload, ModelTransportLimits,
    ModelTransportSupport, ModelTransportTuple, MorphirModel,
};
use morphir_extension_sdk::prelude::*;
use sha2::{Digest, Sha256};

/// The model-content profile this guest reads and writes.
pub const PROFILE: &str = "morphir-ir";
/// The semantic IR version of the model payload.
pub const IR_VERSION: &str = "4.0.0";

/// The complete tuple for one operation.
pub fn tuple(operation: ModelOperation) -> ModelTransportTuple {
    ModelTransportTuple {
        operation,
        profile: PROFILE.into(),
        codec: ModelCodec::MorphirJson,
        envelope_version: MODEL_ENVELOPE_VERSION.into(),
        ir_version: IR_VERSION.into(),
    }
}

/// The model transport this guest offers. A host takes the lower of each
/// limit, so these are the guest's own upper bounds.
pub fn support() -> ModelTransportSupport {
    ModelTransportSupport {
        tuples: vec![
            tuple(ModelOperation::CompileModel),
            tuple(ModelOperation::GenerateModel),
        ],
        limits: ModelTransportLimits {
            max_encoded_bytes: 64 * 1024 * 1024,
            max_decoded_bytes: 48 * 1024 * 1024,
            max_depth: 1024,
            max_nodes: 16 * 1024 * 1024,
        },
        guarantees: vec![],
    }
}

/// Compile Gleam sources into a Morphir IR v4 model envelope.
pub fn compile_model(request: CompileModelRequest) -> Result<CompileModelResult> {
    if request.output != tuple(ModelOperation::CompileModel) {
        return Err(ExtensionError::InvalidParams(
            "Unsupported model output tuple".into(),
        ));
    }
    let mut dependencies = Vec::with_capacity(request.dependencies.len());
    for dependency in request.dependencies {
        let document = decode(&dependency.model)?;
        let distribution = document.get("distribution").cloned().ok_or_else(|| {
            ExtensionError::InvalidParams("Dependency model has no distribution".into())
        })?;
        dependencies.push(CompileDependency {
            package_name: dependency.package_name,
            ir_version: "4".into(),
            distribution,
        });
    }
    let package_name = request.package.name.clone();
    let mut options = request.options;
    options.ir_version = "4".into();
    let result = GleamExtension.compile(CompileRequest {
        language_id: request.language_id,
        sources: request.sources,
        package: request.package,
        dependencies,
        options,
        baseline: None,
    })?;
    let Some(ir) = result.ir.filter(|_| result.success) else {
        return Ok(CompileModelResult::Failed {
            diagnostics: result.diagnostics,
        });
    };
    let model = encode(&package_name, &ir)?;
    Ok(CompileModelResult::Compiled {
        model: Box::new(model),
        diagnostics: result.diagnostics,
        modules: result.modules,
    })
}

/// Generate Gleam source from a Morphir IR v4 model envelope.
pub fn generate_model(request: GenerateModelRequest) -> Result<GenerateResult> {
    if request.input != tuple(ModelOperation::GenerateModel)
        || request.model.profile != PROFILE
        || request.model.ir_version != IR_VERSION
    {
        return Err(ExtensionError::InvalidParams(
            "Unsupported model input tuple".into(),
        ));
    }
    if let Some(required) = request.required_guarantees.first() {
        return Ok(GenerateResult {
            success: false,
            artifacts: vec![],
            diagnostics: vec![Diagnostic {
                severity: DiagnosticSeverity::Error,
                code: Some("UNSUPPORTED_GUARANTEE".into()),
                message: format!(
                    "The Gleam backend cannot check guarantee '{}'",
                    required.guarantee
                ),
                location: None,
                related: vec![],
            }],
        });
    }
    let ir = decode(&request.model)?;
    GleamExtension.generate(GenerateRequest {
        ir,
        target: request.target,
        options: request.options,
    })
}

fn encode(package_name: &str, ir: &serde_json::Value) -> Result<MorphirModel> {
    let bytes = serde_json::to_vec(ir)?;
    let length = u32::try_from(bytes.len())
        .map_err(|_| ExtensionError::ExecutionFailed("Model payload is too large".into()))?;
    let sha256 = hex(&Sha256::digest(&bytes));
    Ok(MorphirModel {
        envelope_version: MODEL_ENVELOPE_VERSION.into(),
        model_id: package_name.into(),
        revision: format!("sha256:{sha256}"),
        ir_version: IR_VERSION.into(),
        profile: PROFILE.into(),
        payload: ModelPayload {
            codec: ModelCodec::MorphirJson,
            layout: ModelLayout::SingleDocument,
            decoded_byte_length: length,
            sha256,
            content: STANDARD.encode(&bytes),
        },
        evidence: vec![],
        critical: vec![],
    })
}

fn decode(model: &MorphirModel) -> Result<serde_json::Value> {
    let payload = &model.payload;
    if payload.codec != ModelCodec::MorphirJson {
        return Err(ExtensionError::InvalidParams(
            "Model payload codec is not morphir-json".into(),
        ));
    }
    let bytes = STANDARD
        .decode(&payload.content)
        .map_err(|_| ExtensionError::InvalidParams("Model payload is not base64".into()))?;
    if u32::try_from(bytes.len()).ok() != Some(payload.decoded_byte_length)
        || hex(&Sha256::digest(&bytes)) != payload.sha256
    {
        return Err(ExtensionError::InvalidParams(
            "Model payload length or SHA-256 does not match".into(),
        ));
    }
    Ok(serde_json::from_slice(&bytes)?)
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use morphir_extension_sdk::model::retain_model;

    fn request() -> CompileModelRequest {
        CompileModelRequest {
            language_id: "gleam".into(),
            sources: SourceSet {
                root: None,
                documents: vec![SourceDocument {
                    uri: "file:///src/numbers.gleam".into(),
                    language_id: "gleam".into(),
                    version: 1,
                    text: "pub type Number = Int\n".into(),
                }],
            },
            package: CompilePackage {
                name: "sample".into(),
                exposed_modules: None,
            },
            dependencies: vec![],
            options: CompileOptions {
                ir_version: IR_VERSION.into(),
                types_only: true,
                extra: [("emitParseStage".into(), false.into())].into(),
            },
            context_digest: "0".repeat(64),
            output: tuple(ModelOperation::CompileModel),
        }
    }

    #[test]
    fn compiled_envelope_is_admitted_by_the_sdk() {
        let CompileModelResult::Compiled { model, .. } = compile_model(request()).unwrap() else {
            panic!("compilation failed");
        };
        retain_model(
            &model,
            &tuple(ModelOperation::CompileModel),
            &support().limits,
        )
        .unwrap();
    }
}
