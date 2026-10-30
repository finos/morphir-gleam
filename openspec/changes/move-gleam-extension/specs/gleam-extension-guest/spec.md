# Spec Delta

## Purpose

Defines the core-Wasm module that Morphir hosts load to compile Gleam source to
Morphir IR and to generate Gleam source from Morphir IR, through the Morphir
Extension Protocol.

## ADDED Requirements

### Requirement: Guest uses only the byte-channel ABI
The guest SHALL be one core WebAssembly module that imports only the
`morphir_bytes_v1` functions `input_len`, `input_byte` and `output_byte`, and
exports `handle` and one unshared 32-bit memory, as the execution profile
`morphir/mep-bytes-v1/v1-draft` defines.

#### Scenario: Module imports are checked
- **WHEN** a tool lists the imports and exports of the released `.wasm` file
- **THEN** the imports are exactly the three `morphir_bytes_v1` functions
- **AND** the exports include `handle` and one memory

#### Scenario: Module has no WASI or Extism imports
- **WHEN** the module is loaded by a host that provides only `morphir_bytes_v1`
- **THEN** instantiation succeeds without any other import

### Requirement: Handle results follow the execution profile
For each request, `handle` SHALL return the exact length of the response bytes
when it writes a response, `0` after an `exit` notification, `-2` for another
notification, and `-1` only for an infrastructure failure.

#### Scenario: Request with a response
- **WHEN** the host gives a valid JSON-RPC request and calls `handle`
- **THEN** `handle` returns a positive number equal to the count of bytes written with `output_byte`

#### Scenario: Exit notification
- **WHEN** the host gives the `exit` notification
- **THEN** `handle` returns `0` and writes no bytes

#### Scenario: Malformed request
- **WHEN** the host gives bytes that are not a valid JSON-RPC message
- **THEN** the guest writes a JSON-RPC error response and does not return `-1`

### Requirement: Extension identity is stable
The guest SHALL report the extension id `morphir-gleam` and the types
`frontend`, `backend` and `workspace` in its describe answer, and the version
SHALL equal the release version.

#### Scenario: Describe answer
- **WHEN** the host sends `morphir.extension.describe`
- **THEN** the answer has id `morphir-gleam`, types `frontend`, `backend` and `workspace`, and the release version

### Requirement: Guest claims the Gleam language
The guest SHALL claim the frontend language `gleam` with the file extension
`.gleam` and the backend target `gleam`.

#### Scenario: Frontend language claim
- **WHEN** the host reads the frontend capabilities
- **THEN** they list language `gleam` with file extension `.gleam`

### Requirement: Guest supports the JSON model tuple
The guest SHALL accept MEP `0.2.0-draft.1` in `initialize` and SHALL offer the
tuple profile `morphir-ir`, codec `morphir-json`, envelope `0.1.0-draft.1` and
IR `4.0.0` for both `morphir.frontend.compileModel` and
`morphir.backend.generateModel`.

#### Scenario: Agreed tuple
- **WHEN** the host offers MEP `0.2.0-draft.1` and the JSON tuple in `initialize`
- **THEN** the guest returns that tuple as the agreed tuple

#### Scenario: Tuple not supported
- **WHEN** the host offers only profile `morphir-model` with codec `ion-binary`
- **THEN** the guest returns an empty agreement and the host reports `extension.tuple_unavailable`

### Requirement: Compile returns a Morphir IR envelope
For `morphir.frontend.compileModel`, the guest SHALL parse the Gleam source
documents in the request and SHALL return a model envelope that holds Morphir IR
`4.0.0` in Morphir JSON.

#### Scenario: Valid Gleam module
- **WHEN** the host sends a compile request with a valid Gleam module that declares a custom type and a function
- **THEN** the response envelope holds IR that contains that type and that value

#### Scenario: Gleam syntax error
- **WHEN** the host sends a compile request with a Gleam module that does not parse
- **THEN** the response has a diagnostic with the document and the source range of the error
- **AND** the response has no model

### Requirement: Generate returns Gleam source
For `morphir.backend.generateModel`, the guest SHALL accept a model envelope in
the agreed tuple and SHALL return Gleam source artifacts, one per module.

#### Scenario: Generate from compiled IR
- **WHEN** the host sends a generate request with the envelope from a successful compile
- **THEN** the response has one `.gleam` artifact for each module in the IR

#### Scenario: Unsupported IR construct
- **WHEN** the IR has a construct that the backend cannot generate
- **THEN** the response has an error diagnostic that names the construct

### Requirement: Legacy protocol stays available
The guest SHALL continue to answer the MEP `0.1` methods
`morphir.frontend.compile` and `morphir.backend.generate` with the same results
as the `0.3.0` release.

#### Scenario: Legacy compile
- **WHEN** a host negotiates MEP `0.1` and sends `morphir.frontend.compile`
- **THEN** the result equals the result of `0.3.0` for the same input

### Requirement: Guest has no ambient access
The guest SHALL NOT read files, the environment, the clock or random numbers
from the host. All source text SHALL come in the request.

#### Scenario: Request that names a file path only
- **WHEN** a compile request names a document path but does not include its text
- **THEN** the guest returns a diagnostic that the document text is missing
