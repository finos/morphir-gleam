# Shared setup for the Rust tasks. Source this file; do not run it.
# ring (through gleam-core) compiles C for wasm32. Apple clang has no wasm32
# target, so use Homebrew LLVM on macOS when it is installed.
set -eu
cd "$(git rev-parse --show-toplevel)/rust"
if [ "$(uname -s)" = "Darwin" ] && [ -z "${CC_wasm32_unknown_unknown:-}" ]; then
    for llvm in /opt/homebrew/opt/llvm/bin /usr/local/opt/llvm/bin; do
        if [ -x "$llvm/clang" ]; then
            export CC_wasm32_unknown_unknown="$llvm/clang"
            export AR_wasm32_unknown_unknown="$llvm/llvm-ar"
            break
        fi
    done
fi
