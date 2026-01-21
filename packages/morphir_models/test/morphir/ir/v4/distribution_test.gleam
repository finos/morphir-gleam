import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleeunit
import gleeunit/should
import morphir/ir/access_controlled as ac
import morphir/ir/documented as doc
import morphir/ir/name
import morphir/ir/path
import morphir/ir/v4/distribution as dist
import morphir/ir/v4/json as v4_json
import morphir/ir/v4/type_ as t
import morphir/ir/v4/value as v

pub fn main() {
  gleeunit.main()
}

// Helper for encoder/decoder arguments (using Unit for attributes)
fn encode_unit_attrs(_: Nil) -> json.Json {
  json.null()
}

fn decode_unit_attrs() -> decode.Decoder(Nil) {
  decode.success(Nil)
}

pub fn library_distribution_roundtrip_test() {
  let package_name = path.from_string("My.Package")

  let type_def = t.TypeAliasDefinition([], t.Unit(Nil))

  let value_def =
    v.Definition(ac.public(v.ExpressionBody([], t.Unit(Nil), v.Unit(Nil))))

  let module_def =
    dist.ModuleDefinition(
      dict.from_list([
        #(
          name.from_string("MyType"),
          ac.public(doc.documented("Doc", type_def)),
        ),
      ]),
      dict.from_list([
        #(
          name.from_string("myValue"),
          ac.public(doc.documented("Doc", value_def)),
        ),
      ]),
    )

  let package_def =
    dist.PackageDefinition(
      dict.from_list([#(name.from_string("My.Module"), ac.public(module_def))]),
    )

  let distro =
    dist.Library(dist.LibraryDistribution(
      dist.PackageInfo(package_name, "1.0.0"),
      package_def,
      dict.new(),
    ))

  let encoded =
    v4_json.encode_distribution(distro, encode_unit_attrs, encode_unit_attrs)
  let decoded =
    v4_json.decode_distribution(decode_unit_attrs(), decode_unit_attrs())

  let json_str = json.to_string(encoded)
  let result = json.parse(json_str, decoded)

  should.be_ok(result)
  let assert Ok(decoded_distro) = result

  case decoded_distro {
    dist.Library(lib) -> {
      lib.package_info.name |> should.equal(package_name)
      lib.package_info.version |> should.equal("1.0.0")

      let assert Ok(ac_mod) =
        dict.get(lib.definition.modules, name.from_string("My.Module"))
      let mod = ac_mod.value
      let assert Ok(_) = dict.get(mod.types, name.from_string("MyType"))
      let assert Ok(_) = dict.get(mod.values, name.from_string("myValue"))
      Nil
    }
    _ -> should.fail()
  }
}

pub fn vfs_manifest_roundtrip_test() {
  let manifest =
    dist.VfsManifest(
      format_version: "1.0",
      layout: dist.VfsMode,
      package_name: path.from_string("My.Package"),
      created: "2023-10-27",
    )

  let encoded = v4_json.encode_vfs_manifest(manifest)
  let decoded = v4_json.decode_vfs_manifest()

  let json_str = json.to_string(encoded)
  let result = json.parse(json_str, decoded)

  should.be_ok(result)
  let assert Ok(decoded_manifest) = result
  decoded_manifest |> should.equal(manifest)
}
