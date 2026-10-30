//! Core-Wasm exports for the execution profile `morphir/mep-bytes-v1/v1-draft`.
//!
//! The module imports only `morphir_bytes_v1.input_len`, `input_byte` and
//! `output_byte`, and exports `handle`. Each call reads one request body, serves
//! it with [`Guest`], and writes the response one byte at a time.

use crate::guest::{Exchange, Guest};

#[link(wasm_import_module = "morphir_bytes_v1")]
unsafe extern "C" {
    fn input_len() -> i32;
    fn input_byte(index: i32) -> i32;
    fn output_byte(byte: i32);
}

static GUEST: Guest = Guest::new();

/// Serve the current request. Returns the response length, `0` after exit,
/// `-2` after another notification, or `-1` on an infrastructure failure.
#[unsafe(no_mangle)]
pub extern "C" fn handle() -> i32 {
    // SAFETY: the host provides these functions for the whole call, as the
    // execution profile requires; they only exchange integers.
    let length = unsafe { input_len() };
    let Ok(count) = usize::try_from(length) else {
        return -1;
    };
    let mut input = Vec::with_capacity(count);
    for index in 0..length {
        // SAFETY: as above; `index` is below the length the host reported.
        let byte = unsafe { input_byte(index) };
        let Ok(byte) = u8::try_from(byte) else {
            return -1;
        };
        input.push(byte);
    }
    let exchange = GUEST.exchange(&input);
    if let Exchange::Response(bytes) = &exchange {
        for byte in bytes {
            // SAFETY: as above.
            unsafe { output_byte(i32::from(*byte)) };
        }
    }
    exchange.code()
}
