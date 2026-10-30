# Proposal

## Why

The Gleam extension `morphir-gleam` lives in finos/morphir-rust as the Rust crate
`morphir-gleam-binding`. Only the Rust CLI hosts it, as a built-in native
provider, and that CLI is being sunset. The MoonBit CLI is now the main Morphir
CLI. It does not have a Gleam provider, and language frontends must leave its
binary and come from an extension repository at run time. The Gleam extension
must therefore move to the Gleam project, finos/morphir-gleam, and be released
from there as a bundle that a repository index can admit and the MoonBit CLI can
install.

This change replaces the plan in bead `morphir-ukvn.1.4` (A3) in finos/morphir.
That plan kept Gleam built into the Rust CLI by a pin. That part is superseded.

## What Changes

- Add a Rust half to this repository under `rust/`: a Cargo workspace that holds
  the crate `morphir-gleam-binding`, imported from finos/morphir-rust with its git
  history (47 commits). The Gleam packages under `packages/` do not change.
- Build the extension as a **core-Wasm guest** for the MoonBit CLI's
  `core-wasm-process` binding (`morphir/mep-bytes-v1/v1-draft`). Do not build a
  native executable and do not ship the Extism artifact from this repository.
- Add the MEP `0.2.0-draft.1` model operations `morphir.frontend.compileModel`
  and `morphir.backend.generateModel` to the guest, for the tuple
  `morphir-ir` / `morphir-json` / envelope `0.1.0-draft.1` / IR `4.0.0`. The
  current MEP `0.1` operations stay.
- Keep the extension id `morphir-gleam`, the short id `gleam` and the tag scheme
  `extension/gleam/v<version>`. The first release from this repository is
  `0.4.0`, after `extension/gleam/v0.3.0` in finos/morphir-rust.
- Add Rust CI jobs that run only when Rust files change, and a release workflow
  that produces the bundle (`release.json` descriptor `2.0.0-draft.2`, claim set
  `0.1.0-draft.2`, a `.sha256` file for each artifact), attests each artifact with
  `actions/attest@v4`, verifies the attestations and attaches all files to a
  GitHub release.
- Stop the current `release.yml` (the Gleam CLI binaries) from acting on
  extension releases.
- Describe, but do not make, the follow-up changes in finos/morphir-moonbit,
  finos/morphir-rust and finos/morphir.

## Capabilities

### New Capabilities

- `gleam-extension-guest`: the core-Wasm module that hosts load. It covers the
  guest ABI, the extension identity, the MEP operations and the model tuple it
  claims.
- `gleam-extension-release`: the published bundle. It covers the files in a
  release, the descriptor and claims, checksums, attestations, the tag scheme
  and the separation from the Gleam CLI release.

### Modified Capabilities

None. This repository has no specs yet.

## Tracking

- No GitHub issue exists for this work. After approval, open one issue in
  finos/morphir-gleam for this change and link it here.
- Source plan: bead `morphir-ukvn.1.4` (A3) in finos/morphir. It depends on
  `morphir-ukvn.1.3` (A2, common layout) and its open child `morphir-ukvn.1.3.3`
  (template and release workflow). This change does not wait for A2. It follows
  the bundle rules that A2 builds on and records where it may differ.
- Related open work that moves with the crate: `morphir-ukvn.5.64.28` (Gleam
  compile, generate and roundtrip in the MoonBit CLI) and `morphir-4q8g.*`
  (Gleam value lowering).

## Impact

- New: `rust/` (Cargo workspace, crate, tests, fixtures),
  `.config/mise/config.rust.toml` (tool pins, used with `MISE_ENV=rust`),
  `.config/mise/tasks/rust/*`,
  `.github/workflows/gleam-extension.yml`,
  `.github/workflows/gleam-extension-release.yml`, `.github/scripts/` bundle
  assembly.
- Changed: `.github/workflows/release.yml` (ignore `extension/*` releases),
  `.gitignore` (`rust/target`), `renovate.json` (gleam-core rev and Rust crates),
  `README.md`, `AGENTS.md` (Rust half), `CHANGELOG.md`.
- New dependencies: Rust toolchain with the `wasm32-unknown-unknown` target,
  `wasm-tools`, the Morphir Rust SDK crates from crates.io
  (`morphir-extension-sdk` 0.4.0, `morphir-core` 0.2.0, `morphir-workspace` 0.2.0)
  and `gleam-core` from gleam-lang/gleam at a pinned revision.
- The released bundle is not usable by the MoonBit CLI until that CLI accepts a
  core-Wasm guest that is not built from MoonBit (see design.html, MGR-1). That
  work is in finos/morphir-moonbit and needs separate approval. Its first part,
  document-tree support (a Gleam project sent as several documents), is a fast
  follower of this change.
