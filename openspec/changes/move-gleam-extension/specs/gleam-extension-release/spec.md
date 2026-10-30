# Spec Delta

## Purpose

Defines the Gleam extension bundle that finos/morphir-gleam publishes to GitHub
releases, so that an extension repository index can admit it and a Morphir CLI
can verify and install it.

## ADDED Requirements

### Requirement: Release tag identifies the extension version
An extension release SHALL use the tag `extension/gleam/v<version>`, where
`<version>` is a SemVer version equal to the crate version and to the version
that the guest reports. The tagged commit SHALL be on `main`.

#### Scenario: Version mismatch
- **WHEN** the tag is `extension/gleam/v0.4.0` and the crate version is `0.4.1`
- **THEN** the release workflow fails before it builds and publishes nothing

#### Scenario: Tag not on main
- **WHEN** the tagged commit is not reachable from `main`
- **THEN** the release workflow fails and publishes nothing

### Requirement: Release has a fixed set of files
A release SHALL contain exactly these assets: `morphir-gleam-<version>.wasm`,
`morphir-gleam-<version>.release.json`, and a `<filename>.sha256` file for each of
them in `sha256sum` format (`<digest>  <filename>` and a newline).

#### Scenario: Checksums agree
- **WHEN** a user downloads all assets and runs `sha256sum --check` on each `.sha256` file
- **THEN** every check passes

### Requirement: Descriptor describes one portable artifact
`release.json` SHALL use `schemaVersion` `2.0.0-draft.2`, `extensionId`
`morphir-gleam`, `shortId` `gleam`, the release `version`, the 40-character
`gitCommit`, `platformDifferences` `none`, and exactly one artifact with no
`platform`, `runtime` `core-wasm` and the execution profile id.

#### Scenario: Descriptor fields
- **WHEN** a reader parses `release.json` of release `0.4.0`
- **THEN** it finds one artifact named `morphir-gleam-0.4.0.wasm` with its SHA-256, no `platform`, `runtime` `core-wasm` and `executionProfile.id` `morphir/mep-bytes-v1/v1-draft`

### Requirement: Old readers refuse the core-Wasm artifact
The descriptor SHALL list `runtime` and `executionProfile` in `critical`, so that
a reader that does not know the `core-wasm` runtime refuses the artifact and does
not load it as an Extism plugin.

#### Scenario: Reader without core-Wasm support
- **WHEN** a reader that knows only the runtimes `process` and `wasm` reads the descriptor
- **THEN** it refuses the artifact with an unknown critical member error

### Requirement: Claims match the live guest
The artifact SHALL carry a claim set with `claimsVersion` `0.1.0-draft.2` and
`claimCheck` `probed`. The release workflow SHALL get the claims from a
describe call to the built guest and SHALL fail if they differ from the
committed expected claims.

#### Scenario: Claims drift
- **WHEN** a code change adds a capability but the committed expected claims are not updated
- **THEN** the release workflow and the pull request CI fail with the difference

### Requirement: Every asset has a build provenance attestation
The release workflow SHALL create a GitHub artifact attestation for the `.wasm`
file and for `release.json`, signed by the workflow
`finos/morphir-gleam/.github/workflows/gleam-extension-release.yml`, before it
creates the GitHub release.

#### Scenario: Verify an asset
- **WHEN** a user runs `gh attestation verify morphir-gleam-0.4.0.wasm --repo finos/morphir-gleam --signer-workflow finos/morphir-gleam/.github/workflows/gleam-extension-release.yml`
- **THEN** the verification passes

#### Scenario: Attestation step fails
- **WHEN** the attestation step fails
- **THEN** no GitHub release is created

### Requirement: Release is published only after tests pass
The release workflow SHALL build the module once, run the crate tests and run the
built module through a core-Wasm host test, and SHALL publish only the bytes that
it tested.

#### Scenario: Host test fails
- **WHEN** the built module fails the host test
- **THEN** the workflow stops and creates no release and no attestation

### Requirement: Extension releases stay separate from CLI releases
An extension release SHALL NOT be marked as the latest release of the
repository, and the Gleam CLI release workflow SHALL NOT build or upload assets
for a release whose tag starts with `extension/`.

#### Scenario: Extension release created
- **WHEN** the extension workflow creates release `extension/gleam/v0.4.0`
- **THEN** the latest release of the repository does not change
- **AND** the Gleam CLI release workflow adds no assets to it
