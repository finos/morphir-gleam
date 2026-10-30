// Assemble the morphir-gleam extension bundle for a GitHub release.
//
// A bundle directory holds exactly: morphir-gleam-<version>.wasm,
// morphir-gleam-<version>.release.json, and a <filename>.sha256 file for each,
// in sha256sum format. The claims in release.json come from a live
// morphir.extension.describe call to the exact module, and must equal the
// committed claims/expected.json.
//
// When `morphir extension publish` exists, the release workflow can call it
// instead of this script.

import { createHash } from "node:crypto";
import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

export const EXTENSION_ID = "morphir-gleam";
export const SHORT_ID = "gleam";
export const DESCRIPTOR_VERSION = "2.0.0-draft.2";
export const CLAIMS_VERSION = "0.1.0-draft.2";
export const RUNTIME = "core-wasm";

// The core-Wasm execution profile and the SHA-256 of its contract text, as
// finos/morphir-moonbit defines them in pkgs/morphir-host/embedding/mep-adapter.mts
// (main at db63950). Update both together when the profile changes.
export const EXECUTION_PROFILE = {
  id: "morphir/mep-bytes-v1/v1-draft",
  sha256: "6ed5e96fa9c7f7dcaa179efc88e517307463cfeddc5e2eeae854f0395e7a4ec6",
} as const;

const SEMVER =
  /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;

export type Claims = Record<string, unknown> & {
  claimsVersion: string;
  extension: { id: string; version: string; types: string[] };
};

export type Descriptor = {
  schemaVersion: string;
  extensionId: string;
  shortId: string;
  version: string;
  gitCommit: string;
  platformDifferences: "none";
  artifacts: Array<{
    runtime: string;
    executionProfile: { id: string; sha256: string };
    filename: string;
    sha256: string;
    claimCheck: "probed";
    claims: Claims;
    critical: string[];
  }>;
};

export function sha256(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex");
}

export function wasmName(version: string): string {
  return `${EXTENSION_ID}-${version}.wasm`;
}

export function descriptorName(version: string): string {
  return `${EXTENSION_ID}-${version}.release.json`;
}

/** Run one describe call on the module, as a host of the execution profile. */
export async function describe(wasm: Uint8Array): Promise<Claims> {
  let input = new Uint8Array();
  let output: number[] = [];
  const imports = {
    morphir_bytes_v1: {
      input_len: () => input.length,
      input_byte: (index: number) => input[index],
      output_byte: (byte: number) => {
        output.push(byte);
      },
    },
  };
  const module = await WebAssembly.compile(wasm);
  const declared = WebAssembly.Module.imports(module).map((i) => `${i.module}.${i.name}`);
  const expected = [
    "morphir_bytes_v1.input_len",
    "morphir_bytes_v1.input_byte",
    "morphir_bytes_v1.output_byte",
  ];
  if (JSON.stringify(declared) !== JSON.stringify(expected)) {
    throw new Error(`module imports ${declared.join(", ")}; expected only the byte channel`);
  }
  const instance = await WebAssembly.instantiate(module, imports);
  const handle = instance.exports.handle as () => number;
  input = new TextEncoder().encode(
    JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "morphir.extension.describe",
      params: { protocolVersions: ["0.2.0-draft.1"] },
    }),
  );
  output = [];
  const length = handle();
  if (length <= 0 || length !== output.length) {
    throw new Error(`describe returned ${length} with ${output.length} bytes`);
  }
  const answer = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(new Uint8Array(output)));
  if (answer.error || !answer.result) {
    throw new Error(`describe failed: ${JSON.stringify(answer.error)}`);
  }
  return answer.result as Claims;
}

/** Compare two JSON values with key order ignored and array order kept. */
export function sameJson(left: unknown, right: unknown): boolean {
  const canonical = (value: unknown): unknown =>
    Array.isArray(value)
      ? value.map(canonical)
      : value && typeof value === "object"
        ? Object.fromEntries(
            Object.keys(value as object)
              .sort()
              .map((key) => [key, canonical((value as Record<string, unknown>)[key])]),
          )
        : value;
  return JSON.stringify(canonical(left)) === JSON.stringify(canonical(right));
}

export type BundleInput = {
  wasm: Uint8Array;
  version: string;
  gitCommit: string;
  claims: Claims;
  expectedClaims: Claims;
};

/** Check the inputs and build the descriptor. Throws on any mismatch. */
export function buildDescriptor(input: BundleInput): Descriptor {
  const { version, gitCommit, claims, expectedClaims } = input;
  if (!SEMVER.test(version)) throw new Error(`version ${version} is not SemVer`);
  if (!/^[0-9a-f]{40}$/.test(gitCommit)) throw new Error(`git commit ${gitCommit} is not 40 hex characters`);
  if (claims.claimsVersion !== CLAIMS_VERSION) {
    throw new Error(`claims version ${claims.claimsVersion}; expected ${CLAIMS_VERSION}`);
  }
  if (claims.extension?.id !== EXTENSION_ID) {
    throw new Error(`extension id ${claims.extension?.id}; expected ${EXTENSION_ID}`);
  }
  if (claims.extension.version !== version) {
    throw new Error(`module reports version ${claims.extension.version}; release is ${version}`);
  }
  if (!sameJson(claims, expectedClaims)) {
    throw new Error("module claims differ from claims/expected.json; run `mise run rust:claims --update` and review");
  }
  return {
    schemaVersion: DESCRIPTOR_VERSION,
    extensionId: EXTENSION_ID,
    shortId: SHORT_ID,
    version,
    gitCommit,
    platformDifferences: "none",
    artifacts: [
      {
        runtime: RUNTIME,
        executionProfile: { ...EXECUTION_PROFILE },
        filename: wasmName(version),
        sha256: sha256(input.wasm),
        claimCheck: "probed",
        claims,
        critical: ["runtime", "executionProfile"],
      },
    ],
  };
}

function checksumLine(filename: string, bytes: Uint8Array): string {
  return `${sha256(bytes)}  ${filename}\n`;
}

/** Write the bundle into an empty or new directory and return its file names. */
export function writeBundle(dir: string, input: BundleInput): string[] {
  const descriptor = buildDescriptor(input);
  mkdirSync(dir, { recursive: true });
  if (readdirSync(dir).length > 0) throw new Error(`${dir} is not empty`);
  const json = new TextEncoder().encode(`${JSON.stringify(descriptor, null, 2)}\n`);
  const files: Array<[string, Uint8Array]> = [
    [wasmName(input.version), input.wasm],
    [descriptorName(input.version), json],
  ];
  for (const [name, bytes] of files) {
    writeFileSync(join(dir, name), bytes);
    writeFileSync(join(dir, `${name}.sha256`), checksumLine(name, bytes));
  }
  checkBundle(dir, input.version);
  return readdirSync(dir).sort();
}

/** Check that a directory is exactly a valid bundle for the version. */
export function checkBundle(dir: string, version: string): void {
  const expected = [wasmName(version), descriptorName(version)].flatMap((name) => [name, `${name}.sha256`]).sort();
  const present = readdirSync(dir).sort();
  if (JSON.stringify(present) !== JSON.stringify(expected)) {
    throw new Error(`bundle has ${present.join(", ")}; expected ${expected.join(", ")}`);
  }
  for (const name of [wasmName(version), descriptorName(version)]) {
    const bytes = readFileSync(join(dir, name));
    const line = readFileSync(join(dir, `${name}.sha256`), "utf8");
    if (line !== checksumLine(name, bytes)) throw new Error(`${name}.sha256 does not match ${name}`);
  }
  const descriptor = JSON.parse(readFileSync(join(dir, descriptorName(version)), "utf8")) as Descriptor;
  const [artifact] = descriptor.artifacts;
  if (descriptor.artifacts.length !== 1 || artifact.filename !== wasmName(version)) {
    throw new Error("descriptor must list exactly the module");
  }
  if (artifact.sha256 !== sha256(readFileSync(join(dir, wasmName(version))))) {
    throw new Error("descriptor digest does not match the module");
  }
}
