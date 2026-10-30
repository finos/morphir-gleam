//! The claims the guest reports must equal the committed `claims/expected.json`.
//!
//! A release copies these claims into `release.json`, so a capability change
//! must update the file in the same change. Run with `MORPHIR_UPDATE_CLAIMS=1`
//! to rewrite the file from the current guest, then review the difference.

use morphir_gleam_binding::guest::{Exchange, Guest};
use serde_json::Value;
use std::path::PathBuf;

const DESCRIBE: &[u8] = br#"{"jsonrpc":"2.0","id":1,"method":"morphir.extension.describe","params":{"protocolVersions":["0.2.0-draft.1"]}}"#;

fn expected_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("claims/expected.json")
}

#[test]
fn reported_claims_equal_the_committed_claims() {
    let Exchange::Response(bytes) = Guest::new().exchange(DESCRIBE) else {
        panic!("describe gets a response");
    };
    let answer: Value = serde_json::from_slice(&bytes).unwrap();
    let claims = answer["result"].clone();
    assert_eq!(claims["claimsVersion"], "0.1.0-draft.2");
    if std::env::var_os("MORPHIR_UPDATE_CLAIMS").is_some() {
        let text = serde_json::to_string_pretty(&claims).unwrap() + "\n";
        std::fs::write(expected_path(), text).unwrap();
    }
    let expected: Value =
        serde_json::from_str(&std::fs::read_to_string(expected_path()).unwrap()).unwrap();
    assert_eq!(
        claims, expected,
        "claims changed; run with MORPHIR_UPDATE_CLAIMS=1 and review claims/expected.json"
    );
}
