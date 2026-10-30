//! One MEP exchange for the core-Wasm execution profile
//! `morphir/mep-bytes-v1/v1-draft`.
//!
//! The host gives one JSON-RPC body and calls `handle`. The guest writes at most
//! one response body. This module holds the target-independent part, so native
//! tests cover it; `core_wasm` only moves bytes across the import boundary.

use crate::GleamExtension;
use morphir_extension_sdk::protocol::{ExtensionRequest, ExtensionResponse, methods};
use morphir_extension_sdk::{
    __ProtocolSession, __dispatch_backend, __dispatch_frontend, __dispatch_request,
    __dispatch_workspace, DispatchFn, ExtensionType,
};
use serde_json::{Value, json};

/// JSON-RPC error code for bytes that are not valid JSON.
const PARSE_ERROR: i32 = -32700;
/// JSON-RPC error code for JSON that is not a valid request.
const INVALID_REQUEST: i32 = -32600;

/// The result of one exchange, in the terms of the execution profile.
#[derive(Debug, PartialEq, Eq)]
pub enum Exchange {
    /// Response bytes; `handle` returns their exact length.
    Response(Vec<u8>),
    /// A notification other than exit; `handle` returns `-2`.
    Notification,
    /// The exit notification; `handle` returns `0` and the session ends.
    Exit,
}

impl Exchange {
    /// The `handle` return value for this exchange, or `-1` when a response
    /// does not fit the result type.
    pub fn code(&self) -> i32 {
        match self {
            Exchange::Response(bytes) => i32::try_from(bytes.len()).unwrap_or(-1),
            Exchange::Notification => -2,
            Exchange::Exit => 0,
        }
    }
}

/// A guest session. The core-Wasm module keeps one for its whole life.
pub struct Guest {
    session: __ProtocolSession,
}

impl Default for Guest {
    fn default() -> Self {
        Self::new()
    }
}

const TYPES: [ExtensionType; 3] = [
    ExtensionType::Frontend,
    ExtensionType::Backend,
    ExtensionType::Workspace,
];

impl Guest {
    /// Create a session that has not yet initialized.
    pub const fn new() -> Self {
        Self {
            session: __ProtocolSession::new(),
        }
    }

    /// Serve one JSON-RPC body.
    pub fn exchange(&self, input: &[u8]) -> Exchange {
        let value: Value = match std::str::from_utf8(input)
            .ok()
            .and_then(|text| serde_json::from_str(text).ok())
        {
            Some(value) => value,
            None => return error(Value::Null, PARSE_ERROR, "Request is not UTF-8 JSON"),
        };
        if value.get("id").is_none() {
            return self.notification(&value);
        }
        let request: ExtensionRequest = match serde_json::from_value(value.clone()) {
            Ok(request) => request,
            Err(_) => {
                let id = value.get("id").cloned().unwrap_or(Value::Null);
                return error(id, INVALID_REQUEST, "Invalid JSON-RPC request");
            }
        };
        respond(&self.dispatch(&request))
    }

    fn notification(&self, value: &Value) -> Exchange {
        if value.get("method").and_then(Value::as_str) != Some(methods::EXIT) {
            return Exchange::Notification;
        }
        // The session needs a request to close; its response is not sent.
        let exit = ExtensionRequest::new(methods::EXIT, json!({}), 0)
            .expect("an empty exit request is valid");
        self.dispatch(&exit);
        Exchange::Exit
    }

    fn dispatch(&self, request: &ExtensionRequest) -> ExtensionResponse {
        let dispatchers: [DispatchFn<GleamExtension>; 3] = [
            __dispatch_frontend::<GleamExtension>,
            __dispatch_backend::<GleamExtension>,
            __dispatch_workspace::<GleamExtension>,
        ];
        self.session.dispatch(request, || {
            __dispatch_request::<GleamExtension>(request, &dispatchers, &TYPES)
        })
    }
}

fn respond(response: &ExtensionResponse) -> Exchange {
    match serde_json::to_vec(response) {
        Ok(bytes) => Exchange::Response(bytes),
        Err(_) => error(Value::Null, -32603, "Response is not serializable"),
    }
}

fn error(id: Value, code: i32, message: &str) -> Exchange {
    let body = json!({
        "jsonrpc": "2.0",
        "id": id,
        "error": { "code": code, "message": message },
    });
    Exchange::Response(serde_json::to_vec(&body).expect("an error body serializes"))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn body(exchange: Exchange) -> Value {
        match exchange {
            Exchange::Response(bytes) => serde_json::from_slice(&bytes).unwrap(),
            other => panic!("expected a response, got {other:?}"),
        }
    }

    fn request(guest: &Guest, id: u64, method: &str, params: Value) -> Value {
        let input = json!({"jsonrpc": "2.0", "id": id, "method": method, "params": params});
        body(guest.exchange(input.to_string().as_bytes()))
    }

    #[test]
    fn describe_reports_the_extension_identity() {
        let guest = Guest::new();
        let params = json!({"protocolVersions": ["0.1"]});
        let answer = request(&guest, 1, methods::DESCRIBE, params);
        assert_eq!(answer["id"], 1);
        let extension = &answer["result"]["extension"];
        assert_eq!(extension["id"], "morphir-gleam");
        assert_eq!(extension["version"], env!("CARGO_PKG_VERSION"));
        assert_eq!(
            extension["types"],
            json!(["frontend", "backend", "workspace"])
        );
    }

    #[test]
    fn malformed_bytes_get_a_parse_error_response() {
        let guest = Guest::new();
        for input in [&b"\xff\xfe"[..], b"{not json", b""] {
            let exchange = guest.exchange(input);
            assert!(exchange.code() > 0);
            let answer = body(exchange);
            assert_eq!(answer["id"], Value::Null);
            assert_eq!(answer["error"]["code"], PARSE_ERROR);
        }
    }

    #[test]
    fn invalid_request_keeps_its_id() {
        let guest = Guest::new();
        let answer = body(guest.exchange(br#"{"jsonrpc":"2.0","id":7}"#));
        assert_eq!(answer["id"], 7);
        assert_eq!(answer["error"]["code"], INVALID_REQUEST);
    }

    #[test]
    fn notifications_have_no_output_and_exit_ends_the_session() {
        let guest = Guest::new();
        let initialized = br#"{"jsonrpc":"2.0","method":"morphir.initialized","params":{}}"#;
        assert_eq!(guest.exchange(initialized), Exchange::Notification);
        assert_eq!(guest.exchange(initialized).code(), -2);
        let exit = br#"{"jsonrpc":"2.0","method":"morphir.exit"}"#;
        assert_eq!(guest.exchange(exit), Exchange::Exit);
        assert_eq!(Exchange::Exit.code(), 0);
        let after = request(&guest, 2, methods::DESCRIBE, json!({}));
        assert!(after.get("error").is_some(), "{after}");
    }

    #[test]
    fn response_code_is_the_exact_byte_length() {
        let guest = Guest::new();
        let input = json!({"jsonrpc": "2.0", "id": 3, "method": methods::DESCRIBE});
        let exchange = guest.exchange(input.to_string().as_bytes());
        let Exchange::Response(bytes) = &exchange else {
            panic!("expected a response");
        };
        assert_eq!(exchange.code() as usize, bytes.len());
    }
}
