//! Generated Gleam keeps the value signatures of the IR, so a round trip
//! (generate, then compile again) gives the same model (finos/morphir-gleam#34).
//!
//! The fixtures in `fixtures/mep_generic` are the expected IR of the shared MEP
//! kit profile `generic-json-library-v1` (finos/morphir, tag v0.4.0-beta.12,
//! `spec/mep/mck/guest-generic-json.json`).

use morphir_core::ir::v4::IRFile;
use morphir_extension_sdk::prelude::*;
use morphir_gleam_binding::GleamExtension;
use serde_json::{Value, json};

const PACKAGE: &str = "mck/generic";

fn fixture(name: &str) -> Value {
    let path = format!(
        "{}/tests/fixtures/mep_generic/{name}",
        env!("CARGO_MANIFEST_DIR")
    );
    serde_json::from_str(&std::fs::read_to_string(&path).unwrap()).unwrap()
}

fn compile(documents: Vec<SourceDocument>, ir_version: &str) -> Value {
    let compiled = GleamExtension
        .compile(CompileRequest {
            language_id: "gleam".into(),
            sources: SourceSet {
                root: None,
                documents,
            },
            package: CompilePackage {
                name: PACKAGE.into(),
                exposed_modules: Some(vec!["main".into()]),
            },
            dependencies: vec![],
            options: CompileOptions {
                ir_version: ir_version.into(),
                types_only: false,
                extra: [("emitParseStage".into(), json!(false))].into(),
            },
            baseline: None,
        })
        .unwrap();
    assert!(compiled.success, "{ir_version}: {:?}", compiled.diagnostics);
    compiled.ir.unwrap()
}

fn source(text: &str) -> Vec<SourceDocument> {
    vec![SourceDocument {
        uri: "main.gleam".into(),
        language_id: "gleam".into(),
        version: 1,
        text: text.into(),
    }]
}

fn generate(ir: &Value) -> Vec<SourceDocument> {
    let generated = GleamExtension
        .generate(GenerateRequest {
            ir: ir.clone(),
            target: "gleam".into(),
            options: Default::default(),
        })
        .unwrap();
    assert!(generated.success, "{:?}", generated.diagnostics);
    generated
        .artifacts
        .into_iter()
        .map(|artifact| SourceDocument {
            uri: artifact.path,
            language_id: "gleam".into(),
            version: 1,
            text: artifact.content,
        })
        .collect()
}

/// Compare V4 models through the IR types: the kit fixture uses the compact
/// type form, and the compiler writes the expanded form.
fn canonical(ir: &Value) -> Value {
    if ir["formatVersion"] == json!(4) {
        serde_json::to_value(serde_json::from_value::<IRFile>(ir.clone()).unwrap()).unwrap()
    } else {
        ir.clone()
    }
}

/// Generate Gleam from `ir`, compile it again, and require the same model.
fn assert_round_trip(ir: &Value, ir_version: &str) -> String {
    let generated = generate(ir);
    let text = generated
        .iter()
        .map(|document| document.text.clone())
        .collect::<String>();
    let recompiled = compile(generated, ir_version);
    assert_eq!(
        canonical(&recompiled),
        canonical(ir),
        "IR {ir_version} changed in the round trip; generated Gleam:\n{text}"
    );
    text
}

#[test]
fn v4_round_trip_keeps_bool_output_types_of_the_mep_kit_model() {
    let ir = fixture("ir-v4.json");
    let text = assert_round_trip(&ir, "4.0.0");
    assert!(text.contains("pub fn ready() -> Bool {"), "{text}");
    assert!(text.contains("pub fn blocked() -> Bool {"), "{text}");
}

#[test]
fn v3_round_trip_of_the_mep_kit_model_is_unchanged() {
    assert_round_trip(&fixture("ir-v3.json"), "3.0.0");
}

#[test]
fn mep_kit_source_compiles_to_the_kit_v4_model() {
    let text = "pub fn ready() -> Bool {\n  True\n}\n\npub fn blocked() -> Bool {\n  False\n}\n";
    assert_eq!(
        canonical(&compile(source(text), "4.0.0")),
        canonical(&fixture("ir-v4.json"))
    );
}

#[test]
fn v4_round_trip_keeps_argument_and_output_types() {
    let ir = compile(
        source(
            "pub fn pick(flag: Bool, count: Int, label: String) -> Int {\n  count\n}\n\n\
             pub fn negate(flag: Bool) -> Bool {\n  case flag {\n    True -> False\n    False -> True\n  }\n}\n",
        ),
        "4.0.0",
    );
    let text = assert_round_trip(&ir, "4.0.0");
    assert!(
        text.contains("pub fn pick(flag: Bool, count: Int, label: String) -> Int {"),
        "{text}"
    );
    assert!(
        text.contains("pub fn negate(flag: Bool) -> Bool {"),
        "{text}"
    );
}

#[test]
fn v3_round_trip_keeps_argument_and_output_types() {
    let ir = compile(
        source("pub fn pick(flag: Bool, count: Int) -> Int {\n  count\n}\n"),
        "3.0.0",
    );
    assert_round_trip(&ir, "3.0.0");
}

#[test]
#[ignore = "requires an installed Gleam compiler"]
fn generated_signatures_pass_the_gleam_compiler() {
    let project = tempfile::tempdir().unwrap();
    std::fs::create_dir(project.path().join("src")).unwrap();
    std::fs::write(
        project.path().join("gleam.toml"),
        "name = \"generated_signatures\"\nversion = \"1.0.0\"\n",
    )
    .unwrap();
    let arguments = compile(
        source("pub fn pick(flag: Bool, count: Int, label: String) -> Int {\n  count\n}\n"),
        "4.0.0",
    );
    for (name, ir) in [
        ("kit", fixture("ir-v4.json")),
        ("kit_v3", fixture("ir-v3.json")),
        ("arguments", arguments),
    ] {
        let generated = generate(&ir);
        assert_eq!(generated.len(), 1);
        std::fs::write(
            project.path().join(format!("src/{name}.gleam")),
            &generated[0].text,
        )
        .unwrap();
    }
    let output = std::process::Command::new(
        std::env::var_os("MORPHIR_TEST_GLEAM").unwrap_or_else(|| "gleam".into()),
    )
    .args(["check", "--target", "javascript"])
    .current_dir(project.path())
    .output()
    .unwrap();
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
}
