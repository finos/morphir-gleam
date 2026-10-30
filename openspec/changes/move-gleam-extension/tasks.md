# Tasks

Tracking: one GitHub issue in finos/morphir-gleam, opened after approval. It also
lists the follow-ups from design.html FUP-1, with document-tree support in the
MoonBit host marked as a fast follower. Each group below lands as one pull request
against `main`, in order.

## 1. Import the crate with its history (PR 1)

- [ ] 1.1 Ask the finos/morphir-rust owners to freeze `crates/morphir-gleam-binding` at the import revision, and record that revision in the PR description. Verify: no commits touch the crate after that revision when PR 1 is ready.
- [x] 1.2 Run `git filter-repo` on a fresh clone with the path rename to `rust/crates/morphir-gleam-binding/` and the message callback from design.html HIS-1. Verify: `git log --format=%B` on the result has no AI co-author trailers and every commit has an `Imported-from:` trailer; the commit count is 47.
- [x] 1.3 Merge the filtered history into the feature branch with `--allow-unrelated-histories --no-ff`. Verify: `git log --follow rust/crates/morphir-gleam-binding/src/lib.rs` shows the imported commits.
- [x] 1.4 Add `rust/Cargo.toml` (workspace), `rust/rust-toolchain.toml` with the `wasm32-unknown-unknown` target, and `rust/target` in `.gitignore`. Verify: `cargo metadata --manifest-path rust/Cargo.toml` succeeds.
- [x] 1.5 Change the path dependencies to the crates.io versions (`morphir-extension-sdk` 0.4.0, `morphir-core` 0.2.0, `morphir-workspace` 0.2.0), copy the VFS types from `morphir-common` into `src/vfs.rs`, and drop `morphir-common`. If a build needs an unpublished change, ask finos/morphir-rust to publish it instead of adding a git dependency. Verify: `cargo build` and `cargo build --target wasm32-unknown-unknown` succeed in `rust/`.
- [x] 1.6 Add `.config/mise/config.rust.toml` (Rust, `wasm-tools`) and the tasks `rust:fmt`, `rust:lint`, `rust:test` and `rust:wasm`. Verify: `MISE_ENV=rust mise run rust:test` passes all imported tests locally, and plain `mise install` still installs no Rust.
- [ ] 1.7 Add `.github/workflows/gleam-extension.yml` with the path filters and the `fmt`, `test` and `wasm` jobs from design.html CI-1. Verify: the PR shows these jobs green and the four required checks unchanged.
- [x] 1.8 Move the Renovate rule for the `gleam-core` revision into `renovate.json`. Verify: `npx --yes --package renovate -- renovate-config-validator` passes.
- [x] 1.9 Add a "Rust half" section to `AGENTS.md` and `README.md` (layout, mise environment, commands) and an `Added` entry in `CHANGELOG.md`. Verify: the documented commands run as written.
- [ ] 1.10 Open PR 1. When EasyCLA, CI and review pass, merge it with a merge commit, not a squash (Damian approved this merge). Verify: `git log --first-parent main` shows one merge commit and `git log main -- rust/crates/morphir-gleam-binding` shows the imported commits.

## 2. Core-Wasm guest and MEP 0.2 model operations (PR 2)

- [x] 2.1 Check whether the SDK JSON-RPC dispatcher can run without `extism-pdk`; record the result in the PR. Verify: a build with `--no-default-features --features core-wasm` compiles or the blocker is named.
- [x] 2.2 Write the Wasmtime host test harness first: it loads a module, provides only `morphir_bytes_v1`, applies the profile limits, and runs a describe/initialize/operation/shutdown/exit session. Verify: it fails against the current build because `handle` has the Extism ABI.
- [x] 2.3 Add the `guest` and `core_wasm` modules and remove the Extism export (design.html RUN-2). Verify: the host test passes describe and exit; `wasm-tools print` shows only the three `morphir_bytes_v1` imports; the guest-ABI scenarios in `specs/gleam-extension-guest/spec.md` pass.
- [x] 2.4 Implement `Frontend::compile_model` and `Backend::generate_model` and advertise the JSON tuple (design.html MEP-1). Verify: host tests for valid module, syntax error, generate from compiled IR, unsupported construct, and the `ion-binary` refusal pass.
- [x] 2.5 Check that MEP `0.1` results are unchanged. Verify: the imported integration tests pass without edits to expected output.
- [x] 2.6 Replace the Extism parity test `tests/wasm.rs` with a native-versus-core-Wasm parity test on the fixtures. Verify: it passes in CI.
- [x] 2.7 Add `claims/expected.json` and the claims check task `rust:claims`. Verify: changing a capability without updating the file makes CI fail.
- [x] 2.8 Add the host test for the largest real-world fixture with time and memory output. Verify: it finishes under 10 s and 256 MiB in CI, and the numbers are in the PR.
- [x] 2.9 Set the crate version to `0.4.0`; document the guest contract in the crate README and add a `Changed` entry in `CHANGELOG.md`. Verify: describe reports `0.4.0`.
- [x] 2.10 Add a host test that compiles a document tree: several Gleam modules with relative paths that import one another, in one compileModel request. Verify: the IR has every module and cross-module references resolve; this is the guest half of the document-tree fast follower.

## 3. Release workflow and attestations (PR 3)

- [ ] 3.1 Add the bun mise task `rust:bundle` that writes `release.json`, the `.sha256` files and runs `sha256sum --check` (design.html MGR-1, REL-1). Verify: a test of the task checks the file set and descriptor fields from `specs/gleam-extension-release/spec.md`.
- [ ] 3.2 Add `bundle-dry-run` to `gleam-extension.yml`. Verify: the PR job uploads a bundle with the expected four files.
- [ ] 3.3 Add `.github/workflows/gleam-extension-release.yml` with the check, build, test and publish jobs and the minimum permissions from design.html REL-1. Verify: `actionlint` passes; a `workflow_dispatch` run with `publish: false` on the branch passes check, build and test and creates nothing.
- [ ] 3.4 Make the check job fail on a version mismatch and on a tag that is not on `main`. Verify: a dispatch run with a mismatched version fails in check.
- [ ] 3.5 Guard `.github/workflows/release.yml` against `extension/*` releases. Verify: `actionlint` passes and the condition is visible in the job.
- [ ] 3.6 Document the release steps, the bundle files and the `gh attestation verify` command in the crate README, and add an entry in `CHANGELOG.md`. Verify: the verify command is correct for the workflow path.

## 4. Integration check

- [ ] 4.1 After PRs 1 to 3 merge, run the release workflow from `main` with `publish: false`. Verify: all jobs pass and the bundle artifact matches the release spec.
- [ ] 4.2 Run `mise run openspec:validate` and `openspec validate move-gleam-extension --strict`. Verify: both pass.

## Workflow follow-up

- Tag `extension/gleam/v0.4.0` only after Damian approves it; then verify the
  release assets with `sha256sum --check` and `gh attestation verify`.
- Propose the follow-up changes in design.html FUP-1 to finos/morphir-moonbit,
  finos/morphir and finos/morphir-rust, each after Damian's approval. Start the
  MoonBit document-tree and non-MoonBit guest work as soon as PR 2 merges.
- Archive this change after review, following AGENTS.md.
