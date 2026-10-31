//! Tests of the built core-Wasm guest and its native equivalent.
//!
//! The harness is a host for the execution profile `morphir/mep-bytes-v1/v1-draft`:
//! it provides only the three `morphir_bytes_v1` functions and calls `handle`.
//! Build with `cargo build -p morphir-gleam-binding --target wasm32-unknown-unknown`,
//! then run `cargo test -p morphir-gleam-binding --features guest-host-tests --test core_wasm -- --ignored`.
//! Set MORPHIR_GLEAM_GUEST to select a packaged or release guest.
#![cfg(all(feature = "guest-host-tests", not(target_arch = "wasm32")))]

use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use morphir_extension_sdk::model::{
    CompileModelRequest, GenerateModelRequest, ModelOperation, ModelTransportLimits,
    ModelTransportSupport, MorphirModel,
};
use morphir_extension_sdk::{
    prelude::*,
    protocol::{
        ExtensionRequest, ExtensionResponse, InitializeParams, InitializeResult, JSONRPC_VERSION,
        MEP_VERSION, PeerInfo, error_codes, methods,
    },
};
use morphir_gleam_binding::GleamExtension;
use morphir_gleam_binding::model_transport::tuple;
use serde_json::{Value, json};
use std::path::PathBuf;
use std::time::{Duration, Instant};
use wasmtime::{Caller, Engine as WasmEngine, Linker, Module, Store, TypedFunc};

/// The execution profile's limit for one call.
const CALL_LIMIT: Duration = Duration::from_secs(10);
/// The MEP draft that carries model operations.
const MODEL_MEP: &str = "0.2.0-draft.1";

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_metadata_and_initialization_match_native_capabilities() {
    let mut guest = guest();
    let described = result(
        &mut guest,
        ExtensionRequest::new(
            methods::DESCRIBE,
            json!({"protocolVersions": [MODEL_MEP]}),
            1,
        )
        .unwrap(),
    );
    assert_eq!(described["extension"]["id"], "morphir-gleam");
    assert_eq!(described["extension"]["version"], env!("CARGO_PKG_VERSION"));
    assert_eq!(
        described["extension"]["types"],
        json!(["frontend", "backend", "workspace"])
    );
    let expected: Value = serde_json::from_str(include_str!("../claims/expected.json")).unwrap();
    assert_eq!(
        described, expected,
        "the built guest's claims equal claims/expected.json"
    );
    initialize(&mut guest);
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_notifications_and_exit_follow_the_execution_profile() {
    let mut guest = guest();
    initialize(&mut guest);
    let (code, output) = guest.exchange(br#"{"jsonrpc":"2.0","method":"morphir.initialized"}"#);
    assert_eq!((code, output.len()), (-2, 0));
    let (code, output) = guest.exchange(br#"{"jsonrpc":"2.0","method":"morphir.exit"}"#);
    assert_eq!((code, output.len()), (0, 0));
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_compile_generate_and_incremental_match_native_for_both_versions() {
    let mut guest = guest();
    initialize(&mut guest);
    for version in ["3", "4"] {
        let mut request = request(version);
        let first = same_compilation(&mut guest, &request);
        let generate = GenerateRequest {
            ir: first.ir.clone().unwrap(),
            target: "gleam".into(),
            options: Default::default(),
        };
        let native = GleamExtension.generate(generate.clone()).unwrap();
        assert!(native.success, "{:?}", native.diagnostics);
        let generated: GenerateResult = serde_json::from_value(result(
            &mut guest,
            ExtensionRequest::new(methods::GENERATE, generate, 3).unwrap(),
        ))
        .unwrap();
        assert_eq!(
            serde_json::to_value(generated).unwrap(),
            serde_json::to_value(native).unwrap()
        );

        request.baseline = Some(baseline(&first));
        let reused = same_compilation(&mut guest, &request);
        assert!(
            reused
                .module_results
                .iter()
                .all(|module| module.status == ModuleStatus::Unchanged)
        );
        assert_eq!(first.ir, reused.ir);
        request.sources.documents[1].text = "pub type Number = Float\n".into();
        let changed = same_compilation(&mut guest, &request);
        assert!(
            changed
                .module_results
                .iter()
                .all(|module| module.status == ModuleStatus::Compiled)
        );
    }
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_protocol_errors_do_not_poison_subsequent_requests() {
    let mut guest = guest();
    initialize(&mut guest);
    for (method, expected) in [
        (methods::COMPILE, error_codes::INVALID_PARAMS),
        (methods::GENERATE, error_codes::INVALID_PARAMS),
        ("unknown.method", error_codes::METHOD_NOT_FOUND),
    ] {
        let response = call(
            &mut guest,
            ExtensionRequest::new(method, json!({}), 41).unwrap(),
        );
        assert_eq!(response.error.unwrap().code, expected);
    }
    let (code, output) = guest.exchange(b"{");
    assert!(code > 0);
    let parse_error: Value = serde_json::from_slice(&output).unwrap();
    assert_eq!(parse_error["error"]["code"], -32700);
    assert_eq!(
        result(
            &mut guest,
            ExtensionRequest::new(methods::PING, json!({}), 42).unwrap()
        ),
        json!({"ok": true})
    );
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_official_parser_and_diagnostics_match_native() {
    let mut guest = guest();
    initialize(&mut guest);
    for (source, succeeds) in [
        ("pub const answer: Int = 0x2A\n", true),
        ("pub fn text() { \"\\u{1F600}\" }\n", true),
        ("pub type Wrapped = (Int)\n", false),
        ("pub fn missing(x: Int) -> Int\n", false),
        ("pub const inferred = 42\n", false),
        (
            "pub fn labelled(named value: Int) -> Int { value }\n",
            false,
        ),
    ] {
        let mut request = request("4");
        request.options.types_only = false;
        request.sources.documents.truncate(1);
        request.sources.documents[0].text = source.into();
        let native = GleamExtension.compile(request.clone()).unwrap();
        assert_eq!(
            native.success, succeeds,
            "{source}: {:?}",
            native.diagnostics
        );
        let compiled: CompileResult = serde_json::from_value(result(
            &mut guest,
            ExtensionRequest::new(methods::COMPILE, request, 2).unwrap(),
        ))
        .unwrap();
        assert_eq!(
            serde_json::to_value(compiled).unwrap(),
            serde_json::to_value(native).unwrap(),
            "{source}"
        );
    }
}

fn same_compilation(guest: &mut Guest, request: &CompileRequest) -> CompileResult {
    let native = GleamExtension.compile(request.clone()).unwrap();
    assert!(native.success, "{:?}", native.diagnostics);
    let compiled: CompileResult = serde_json::from_value(result(
        guest,
        ExtensionRequest::new(methods::COMPILE, request, 2).unwrap(),
    ))
    .unwrap();
    assert_eq!(
        serde_json::to_value(&compiled).unwrap(),
        serde_json::to_value(native).unwrap()
    );
    compiled
}

fn baseline(result: &CompileResult) -> CompileBaseline {
    CompileBaseline {
        context_digest: result.context_digest.clone(),
        modules: result
            .module_results
            .iter()
            .map(|module| BaselineModule {
                frontend_state: module.frontend_state.clone(),
                name: module.name.clone(),
                uri: module.uri.clone(),
                source_digest: module.source_digest.clone().unwrap(),
                interface_digest: module.interface_digest.clone().unwrap(),
                depends_on: module.depends_on.clone(),
                ir: module.ir.clone().unwrap(),
            })
            .collect(),
    }
}

fn request(version: &str) -> CompileRequest {
    CompileRequest {
        language_id: "gleam".into(),
        sources: SourceSet {
            root: None,
            documents: [
                (
                    "model",
                    "import numbers\npub type Amount = numbers.Number\npub type Outcome(a) { Pending Success(value: a, amount: Amount) Failed(String) Retry(Outcome(a)) }\n",
                ),
                ("numbers", "pub type Number = Int\n"),
            ]
            .into_iter()
            .map(|(name, source)| SourceDocument {
                uri: format!("file:///src/{name}.gleam"),
                language_id: "gleam".into(),
                version: 1,
                text: source.into(),
            })
            .collect(),
        },
        package: CompilePackage {
            name: "sample".into(),
            exposed_modules: None,
        },
        options: CompileOptions {
            ir_version: version.into(),
            types_only: true,
            extra: [("emitParseStage".into(), false.into())].into(),
        },
        ..Default::default()
    }
}

/// The byte channel of one call: the request the host gives and the response
/// bytes the guest writes.
#[derive(Default)]
struct Channel {
    input: Vec<u8>,
    output: Vec<u8>,
}

/// A loaded guest with one persistent session.
struct Guest {
    store: Store<Channel>,
    handle: TypedFunc<(), i32>,
}

impl Guest {
    /// Give one body to `handle` and return its result and the written bytes.
    fn exchange(&mut self, body: &[u8]) -> (i32, Vec<u8>) {
        let channel = self.store.data_mut();
        channel.input = body.to_vec();
        channel.output.clear();
        let started = Instant::now();
        let code = self
            .handle
            .call(&mut self.store, ())
            .expect("the guest does not trap");
        let elapsed = started.elapsed();
        assert!(elapsed < CALL_LIMIT, "call took {elapsed:?}");
        let output = std::mem::take(&mut self.store.data_mut().output);
        if code > 0 {
            assert_eq!(code as usize, output.len(), "result is the exact length");
        } else {
            assert!(matches!(code, 0 | -2), "unexpected result {code}");
            assert!(output.is_empty(), "no output without a response");
        }
        (code, output)
    }
}

fn guest_path() -> PathBuf {
    std::env::var_os("MORPHIR_GLEAM_GUEST")
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .join("../../target/wasm32-unknown-unknown/debug/morphir_gleam_binding.wasm")
        })
}

fn guest() -> Guest {
    let path = guest_path();
    let wasm = std::fs::read(&path).unwrap_or_else(|error| panic!(
        "cannot read guest {}: {error}; build the wasm32-unknown-unknown target or set MORPHIR_GLEAM_GUEST", path.display()
    ));
    let engine = WasmEngine::default();
    let module = Module::new(&engine, &wasm).expect("the guest is a valid core-Wasm module");
    let imports: Vec<(String, String)> = module
        .imports()
        .map(|import| (import.module().to_owned(), import.name().to_owned()))
        .collect();
    assert_eq!(
        imports,
        [
            ("morphir_bytes_v1".to_owned(), "input_len".to_owned()),
            ("morphir_bytes_v1".to_owned(), "input_byte".to_owned()),
            ("morphir_bytes_v1".to_owned(), "output_byte".to_owned()),
        ],
        "the guest imports only the byte channel"
    );
    let memories: Vec<_> = module
        .exports()
        .filter_map(|export| export.ty().memory().cloned())
        .collect();
    assert_eq!(memories.len(), 1, "one memory");
    assert!(!memories[0].is_shared() && !memories[0].is_64());
    assert!(
        memories[0].maximum().is_some_and(|pages| pages <= 4096),
        "a finite maximum of at most 4096 pages"
    );
    let mut linker = Linker::new(&engine);
    linker
        .func_wrap(
            "morphir_bytes_v1",
            "input_len",
            |caller: Caller<'_, Channel>| caller.data().input.len() as i32,
        )
        .unwrap();
    linker
        .func_wrap(
            "morphir_bytes_v1",
            "input_byte",
            |caller: Caller<'_, Channel>, index: i32| {
                i32::from(caller.data().input[usize::try_from(index).unwrap()])
            },
        )
        .unwrap();
    linker
        .func_wrap(
            "morphir_bytes_v1",
            "output_byte",
            |mut caller: Caller<'_, Channel>, byte: i32| {
                caller.data_mut().output.push(u8::try_from(byte).unwrap());
            },
        )
        .unwrap();
    let mut store = Store::new(&engine, Channel::default());
    let instance = linker
        .instantiate(&mut store, &module)
        .expect("the guest instantiates with only the byte channel");
    let handle = instance
        .get_typed_func::<(), i32>(&mut store, "handle")
        .expect("the guest exports handle");
    Guest { store, handle }
}

fn call(guest: &mut Guest, request: ExtensionRequest) -> ExtensionResponse {
    let input = serde_json::to_vec(&request).unwrap();
    let (code, output) = guest.exchange(&input);
    assert!(code > 0, "a request gets a response");
    let response: ExtensionResponse = serde_json::from_slice(&output).unwrap();
    assert_eq!(response.jsonrpc, JSONRPC_VERSION);
    assert_eq!(response.id, request.id);
    assert_ne!(response.result.is_some(), response.error.is_some());
    response
}

fn result(guest: &mut Guest, request: ExtensionRequest) -> Value {
    let response = call(guest, request);
    assert!(response.error.is_none(), "{:?}", response.error);
    response.result.unwrap()
}

fn initialize(guest: &mut Guest) {
    let initialized: InitializeResult = serde_json::from_value(result(
        guest,
        ExtensionRequest::new(
            methods::INITIALIZE,
            InitializeParams {
                model_transport: None,
                protocol_versions: vec![MEP_VERSION.into()],
                host: PeerInfo {
                    kind: Default::default(),
                    name: "gleam-wasm-test".into(),
                    version: "0.1.0".into(),
                },
            },
            1,
        )
        .unwrap(),
    ))
    .unwrap();
    assert_eq!(initialized.protocol_version, MEP_VERSION);
    assert_eq!(initialized.extension.id, "morphir-gleam");
    let capabilities = initialized.capabilities;
    // A MEP 0.1 session never grants the model transport.
    let mut expected = GleamExtension::capabilities();
    expected.model_transport = None;
    assert_eq!(
        serde_json::to_value(&capabilities).unwrap(),
        serde_json::to_value(expected).unwrap()
    );
    assert!(capabilities.frontend.unwrap().incremental);
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_structural_values_match_native_and_the_golden() {
    let mut guest = guest();
    initialize(&mut guest);
    let mut request = request("4");
    request.options.types_only = false;
    request.sources.documents.truncate(1);
    request.sources.documents[0].text = include_str!("fixtures/structural_values.gleam").into();
    let compiled = same_compilation(&mut guest, &request);
    let generate = GenerateRequest {
        ir: compiled.ir.unwrap(),
        target: "gleam".into(),
        options: Default::default(),
    };
    let native = GleamExtension.generate(generate.clone()).unwrap();
    assert!(native.success, "{:?}", native.diagnostics);
    assert_eq!(native.artifacts.len(), 1);
    assert_eq!(
        native.artifacts[0].content,
        include_str!("goldens/source_structural_values.gleam")
    );
    let generated: GenerateResult = serde_json::from_value(result(
        &mut guest,
        ExtensionRequest::new(methods::GENERATE, generate, 3).unwrap(),
    ))
    .unwrap();
    assert_eq!(
        serde_json::to_value(generated).unwrap(),
        serde_json::to_value(native).unwrap()
    );
}

/// The offer the MoonBit CLI makes on its core-Wasm route for one operation.
fn moonbit_offer(operation: ModelOperation) -> ModelTransportSupport {
    ModelTransportSupport {
        tuples: vec![tuple(operation)],
        limits: ModelTransportLimits {
            max_encoded_bytes: 2_796_204,
            max_decoded_bytes: 2 * 1024 * 1024,
            max_depth: 128,
            max_nodes: 100_000,
        },
        guarantees: vec![],
    }
}

/// Open a model session as the MoonBit CLI does: describe, initialize with
/// exactly one tuple, then the `morphir.initialized` notification.
fn model_session(operation: ModelOperation) -> Guest {
    let mut guest = guest();
    result(
        &mut guest,
        ExtensionRequest::new(
            methods::DESCRIBE,
            json!({"protocolVersions": [MODEL_MEP]}),
            1,
        )
        .unwrap(),
    );
    let offer = moonbit_offer(operation);
    let initialized: InitializeResult = serde_json::from_value(result(
        &mut guest,
        ExtensionRequest::new(
            methods::INITIALIZE,
            InitializeParams {
                model_transport: Some(offer.clone()),
                protocol_versions: vec![MODEL_MEP.into()],
                host: PeerInfo {
                    kind: Default::default(),
                    name: "gleam-core-wasm-test".into(),
                    version: "0.1.0".into(),
                },
            },
            2,
        )
        .unwrap(),
    ))
    .unwrap();
    assert_eq!(initialized.protocol_version, MODEL_MEP);
    let agreed = initialized.capabilities.model_transport.unwrap();
    assert_eq!(agreed.tuples, offer.tuples);
    assert_eq!(agreed.limits, offer.limits);
    let (code, _) = guest.exchange(br#"{"jsonrpc":"2.0","method":"morphir.initialized"}"#);
    assert_eq!(code, -2);
    guest
}

fn close(mut guest: Guest) {
    result(
        &mut guest,
        ExtensionRequest::new(methods::SHUTDOWN, json!({}), 99).unwrap(),
    );
    let (code, _) = guest.exchange(br#"{"jsonrpc":"2.0","method":"morphir.exit"}"#);
    assert_eq!(code, 0);
}

const CONTEXT_DIGEST: &str = "4f5b812789fc606be1b3b16908db13fc7a3c5bf6e0b8c1f2e4a5d6c7b8a9f0e1";

fn compile_model_request(request: &CompileRequest) -> CompileModelRequest {
    // The model options name the tuple's IR version, as the MoonBit CLI does.
    let mut options = request.options.clone();
    options.ir_version = "4.0.0".into();
    // A document tree with absolute URIs names its root; the SDK refuses
    // several absolute documents without one.
    let mut sources = request.sources.clone();
    if sources.documents.len() > 1 {
        sources.root = Some("file:///src/".into());
    }
    CompileModelRequest {
        language_id: request.language_id.clone(),
        sources,
        package: request.package.clone(),
        dependencies: vec![],
        options,
        context_digest: CONTEXT_DIGEST.into(),
        output: tuple(ModelOperation::CompileModel),
    }
}

fn payload(model: &MorphirModel) -> Value {
    serde_json::from_slice(&STANDARD.decode(&model.payload.content).unwrap()).unwrap()
}

/// Compile through a model session and return the model and the result body.
fn compile_through_model_session(request: &CompileRequest) -> Value {
    let mut guest = model_session(ModelOperation::CompileModel);
    let body = result(
        &mut guest,
        ExtensionRequest::new(methods::COMPILE_MODEL, compile_model_request(request), 3).unwrap(),
    );
    close(guest);
    body
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_model_session_compiles_and_generates_like_native() {
    let mut request = request("4");
    request.options.types_only = false;
    let native = GleamExtension.compile(request.clone()).unwrap();
    assert!(native.success, "{:?}", native.diagnostics);

    let compiled = compile_through_model_session(&request);
    assert_eq!(compiled["success"], true, "{compiled:#}");
    let model: MorphirModel = serde_json::from_value(compiled["model"].clone()).unwrap();
    assert_eq!(model.profile, "morphir-ir");
    assert_eq!(model.ir_version, "4.0.0");
    assert_eq!(model.model_id, "sample");
    assert_eq!(payload(&model), native.ir.clone().unwrap());

    let mut guest = model_session(ModelOperation::GenerateModel);
    let generated: GenerateResult = serde_json::from_value(result(
        &mut guest,
        ExtensionRequest::new(
            methods::GENERATE_MODEL,
            GenerateModelRequest {
                model,
                input: tuple(ModelOperation::GenerateModel),
                target: "gleam".into(),
                context_digest: CONTEXT_DIGEST.into(),
                required_guarantees: vec![],
                options: Default::default(),
            },
            3,
        )
        .unwrap(),
    ))
    .unwrap();
    close(guest);
    let expected = GleamExtension
        .generate(GenerateRequest {
            ir: native.ir.unwrap(),
            target: "gleam".into(),
            options: Default::default(),
        })
        .unwrap();
    assert!(generated.success, "{:?}", generated.diagnostics);
    assert_eq!(
        serde_json::to_value(generated).unwrap(),
        serde_json::to_value(expected).unwrap()
    );
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_model_session_reports_syntax_errors_without_a_model() {
    let mut request = request("4");
    request.sources.documents.truncate(1);
    request.sources.documents[0].text = "pub type Broken = {\n".into();
    let compiled = compile_through_model_session(&request);
    assert_eq!(compiled["success"], false, "{compiled:#}");
    assert!(compiled.get("model").is_none());
    let diagnostic = &compiled["diagnostics"][0];
    assert_eq!(diagnostic["severity"], "error");
    assert_eq!(diagnostic["location"]["uri"], "file:///src/model.gleam");
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_compiles_a_document_tree_of_importing_modules() {
    let documents = [
        ("shared/numbers", "pub type Number = Int\n"),
        (
            "app/money",
            "import shared/numbers\npub type Money { Money(amount: numbers.Number, currency: String) }\n",
        ),
        (
            "app/orders",
            "import app/money\nimport shared/numbers\npub type Order { Order(quantity: numbers.Number, price: money.Money) }\n",
        ),
    ];
    let mut request = request("4");
    request.sources.documents = documents
        .into_iter()
        .map(|(path, text)| SourceDocument {
            uri: format!("file:///src/{path}.gleam"),
            language_id: "gleam".into(),
            version: 1,
            text: text.into(),
        })
        .collect();
    let native = GleamExtension.compile(request.clone()).unwrap();
    assert!(native.success, "{:?}", native.diagnostics);
    assert_eq!(native.modules.len(), 3, "{:?}", native.modules);

    let compiled = compile_through_model_session(&request);
    assert_eq!(compiled["success"], true, "{compiled:#}");
    let model: MorphirModel = serde_json::from_value(compiled["model"].clone()).unwrap();
    assert_eq!(payload(&model), native.ir.unwrap());
    assert_eq!(compiled["modules"], json!(native.modules));
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_agrees_no_tuple_for_an_ion_only_model_offer() {
    let mut guest = guest();
    let mut offer = moonbit_offer(ModelOperation::CompileModel);
    offer.tuples[0].profile = "morphir-model".into();
    offer.tuples[0].codec = morphir_extension_sdk::model::ModelCodec::IonBinary;
    let initialized = result(
        &mut guest,
        ExtensionRequest::new(
            methods::INITIALIZE,
            InitializeParams {
                model_transport: Some(offer),
                protocol_versions: vec![MODEL_MEP.into()],
                host: PeerInfo {
                    kind: Default::default(),
                    name: "gleam-core-wasm-test".into(),
                    version: "0.1.0".into(),
                },
            },
            2,
        )
        .unwrap(),
    );
    // The host sees an empty agreement and reports extension.tuple_unavailable.
    assert_eq!(
        initialized["capabilities"]["modelTransport"]["tuples"],
        json!([])
    );
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_compiles_every_real_world_fixture_within_the_call_limit() {
    let fixtures = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/real_world");
    let mut documents: Vec<SourceDocument> = std::fs::read_dir(&fixtures)
        .unwrap()
        .map(|entry| entry.unwrap().path())
        .filter(|path| {
            path.extension()
                .is_some_and(|extension| extension == "gleam")
        })
        .map(|path| SourceDocument {
            uri: format!(
                "file:///src/{}",
                path.file_name().unwrap().to_string_lossy()
            ),
            language_id: "gleam".into(),
            version: 1,
            text: std::fs::read_to_string(&path).unwrap(),
        })
        .collect();
    documents.sort_by(|left, right| left.uri.cmp(&right.uri));
    let mut request = request("4");
    request.options.types_only = false;
    request.sources.documents = documents;
    let started = Instant::now();
    let compiled = compile_through_model_session(&request);
    eprintln!(
        "real-world fixtures: {} documents, session {:?}, guest {} bytes",
        request.sources.documents.len(),
        started.elapsed(),
        std::fs::metadata(guest_path()).unwrap().len()
    );
    let native = GleamExtension.compile(request).unwrap();
    assert_eq!(compiled["success"], native.success, "{compiled:#}");
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_refuses_a_document_without_text() {
    let mut request = request("4");
    request.sources.documents.truncate(1);
    let mut params = serde_json::to_value(compile_model_request(&request)).unwrap();
    params["sources"]["documents"][0]
        .as_object_mut()
        .unwrap()
        .remove("text");
    let mut guest = model_session(ModelOperation::CompileModel);
    let body =
        json!({"jsonrpc": "2.0", "id": 3, "method": methods::COMPILE_MODEL, "params": params});
    let (code, output) = guest.exchange(body.to_string().as_bytes());
    assert!(code > 0);
    let answer: Value = serde_json::from_slice(&output).unwrap();
    assert_eq!(
        answer["error"]["code"],
        error_codes::INVALID_PARAMS,
        "{answer}"
    );
    close(guest);
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_refuses_several_absolute_documents_without_a_root() {
    let mut params = compile_model_request(&request("4"));
    params.sources.root = None;
    let mut guest = model_session(ModelOperation::CompileModel);
    let response = call(
        &mut guest,
        ExtensionRequest::new(methods::COMPILE_MODEL, params, 3).unwrap(),
    );
    assert_eq!(
        response.error.map(|error| error.code),
        Some(error_codes::INVALID_PARAMS)
    );
    close(guest);
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_compiles_a_relative_document_tree_without_a_root() {
    // The shape the MoonBit CLI sends: paths relative to the source base and
    // no sources.root. Nested modules keep their full path.
    let mut request = request("4");
    request.sources.documents = [
        ("shared/numbers.gleam", "pub type Number = Int\n"),
        ("app/numbers.gleam", "pub type Count = Int\n"),
        (
            "app/orders.gleam",
            "import shared/numbers\npub type Order { Order(quantity: numbers.Number) }\n",
        ),
    ]
    .into_iter()
    .map(|(path, text)| SourceDocument {
        uri: path.into(),
        language_id: "gleam".into(),
        version: 1,
        text: text.into(),
    })
    .collect();
    let mut params = compile_model_request(&request);
    params.sources.root = None;
    let mut guest = model_session(ModelOperation::CompileModel);
    let compiled = result(
        &mut guest,
        ExtensionRequest::new(methods::COMPILE_MODEL, params, 3).unwrap(),
    );
    close(guest);
    assert_eq!(compiled["success"], true, "{compiled:#}");
    let mut modules: Vec<String> = serde_json::from_value(compiled["modules"].clone()).unwrap();
    modules.sort();
    assert_eq!(modules, ["app/numbers", "app/orders", "shared/numbers"]);
}

#[test]
#[ignore = "requires a built Gleam WASM guest"]
fn guest_negotiates_json_when_the_host_prefers_ion_but_offers_both() {
    // The host lists every format it supports, its default first. A guest
    // without the default agrees on another offered format; this is not an error.
    let ion_default = morphir_extension_sdk::model::ModelTransportTuple {
        profile: "morphir-model".into(),
        codec: morphir_extension_sdk::model::ModelCodec::IonBinary,
        ..tuple(ModelOperation::CompileModel)
    };
    let mut offer = moonbit_offer(ModelOperation::CompileModel);
    offer.tuples.insert(0, ion_default);
    let mut guest = guest();
    let initialized = result(
        &mut guest,
        ExtensionRequest::new(
            methods::INITIALIZE,
            InitializeParams {
                model_transport: Some(offer),
                protocol_versions: vec![MODEL_MEP.into()],
                host: PeerInfo {
                    kind: Default::default(),
                    name: "gleam-core-wasm-test".into(),
                    version: "0.1.0".into(),
                },
            },
            2,
        )
        .unwrap(),
    );
    assert_eq!(initialized["protocolVersion"], MODEL_MEP);
    assert_eq!(
        initialized["capabilities"]["modelTransport"]["tuples"],
        json!([tuple(ModelOperation::CompileModel)])
    );
    let (code, _) = guest.exchange(br#"{"jsonrpc":"2.0","method":"morphir.initialized"}"#);
    assert_eq!(code, -2);
    let compiled = result(
        &mut guest,
        ExtensionRequest::new(
            methods::COMPILE_MODEL,
            compile_model_request(&request("4")),
            3,
        )
        .unwrap(),
    );
    assert_eq!(compiled["success"], true, "{compiled:#}");
    close(guest);
}
