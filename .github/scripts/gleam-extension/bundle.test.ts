import { describe as group, expect, test } from "bun:test";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import {
  type BundleInput,
  type Claims,
  EXECUTION_PROFILE,
  buildDescriptor,
  checkBundle,
  descriptorName,
  describe,
  sha256,
  wasmName,
  writeBundle,
} from "./bundle.ts";

const root = resolve(import.meta.dir, "../../..");
const expectedClaims: Claims = JSON.parse(
  readFileSync(join(root, "rust/crates/morphir-gleam-binding/claims/expected.json"), "utf8"),
);
const version = expectedClaims.extension.version;
const commit = "0123456789abcdef0123456789abcdef01234567";

function input(overrides: Partial<BundleInput> = {}): BundleInput {
  return {
    wasm: new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0]),
    version,
    gitCommit: commit,
    claims: structuredClone(expectedClaims),
    expectedClaims,
    ...overrides,
  };
}

group("descriptor", () => {
  test("describes one portable core-Wasm artifact", () => {
    const descriptor = buildDescriptor(input());
    expect(descriptor.schemaVersion).toBe("2.0.0-draft.2");
    expect(descriptor.extensionId).toBe("morphir-gleam");
    expect(descriptor.shortId).toBe("gleam");
    expect(descriptor.version).toBe(version);
    expect(descriptor.gitCommit).toBe(commit);
    expect(descriptor.platformDifferences).toBe("none");
    expect(descriptor.artifacts).toHaveLength(1);
    const [artifact] = descriptor.artifacts;
    expect(artifact).not.toHaveProperty("platform");
    expect(artifact.runtime).toBe("core-wasm");
    expect(artifact.executionProfile).toEqual({ ...EXECUTION_PROFILE });
    expect(artifact.filename).toBe(`morphir-gleam-${version}.wasm`);
    expect(artifact.sha256).toBe(sha256(input().wasm));
    expect(artifact.claimCheck).toBe("probed");
    expect(artifact.claims.claimsVersion).toBe("0.1.0-draft.2");
    expect(artifact.critical).toEqual(["runtime", "executionProfile"]);
  });

  test("refuses a module whose version differs from the release", () => {
    expect(() => buildDescriptor(input({ version: "9.9.9" }))).toThrow(/reports version/);
  });

  test("refuses claims that drift from claims/expected.json", () => {
    const claims = structuredClone(expectedClaims) as Claims & { capabilities: { streaming: boolean } };
    claims.capabilities.streaming = !claims.capabilities.streaming;
    expect(() => buildDescriptor(input({ claims }))).toThrow(/differ/);
  });

  test("refuses a short git commit", () => {
    expect(() => buildDescriptor(input({ gitCommit: "abc123" }))).toThrow(/40 hex/);
  });
});

group("bundle directory", () => {
  test("holds exactly the module, the descriptor and their checksums", () => {
    const dir = join(mkdtempSync(join(tmpdir(), "gleam-bundle-")), "out");
    const files = writeBundle(dir, input());
    expect(files).toEqual(
      [wasmName(version), `${wasmName(version)}.sha256`, descriptorName(version), `${descriptorName(version)}.sha256`].sort(),
    );
    const line = readFileSync(join(dir, `${wasmName(version)}.sha256`), "utf8");
    expect(line).toBe(`${sha256(input().wasm)}  ${wasmName(version)}\n`);
  });

  test("detects a tampered checksum and an extra file", () => {
    const dir = join(mkdtempSync(join(tmpdir(), "gleam-bundle-")), "out");
    writeBundle(dir, input());
    writeFileSync(join(dir, "extra.txt"), "x");
    expect(() => checkBundle(dir, version)).toThrow(/expected/);
    const clean = join(mkdtempSync(join(tmpdir(), "gleam-bundle-")), "out");
    writeBundle(clean, input());
    writeFileSync(join(clean, `${wasmName(version)}.sha256`), `${"0".repeat(64)}  ${wasmName(version)}\n`);
    expect(() => checkBundle(clean, version)).toThrow(/does not match/);
  });

  test("refuses a directory that is not empty", () => {
    const dir = mkdtempSync(join(tmpdir(), "gleam-bundle-"));
    writeFileSync(join(dir, "old"), "x");
    expect(() => writeBundle(dir, input())).toThrow(/not empty/);
  });
});

const built = join(root, "rust/target/wasm32-unknown-unknown/release/morphir_gleam_binding.wasm");
test.skipIf(!existsSync(built))("the built module's live claims equal the committed claims", async () => {
  const claims = await describe(new Uint8Array(readFileSync(built)));
  expect(claims).toEqual(expectedClaims);
});
