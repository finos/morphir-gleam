import gleam/dynamic/decode
import gleam/json
import morphir/ir/v4/distribution as dist
import morphir/ir/v4/json as v4_json

pub type LoadError {
  JsonError(json.DecodeError)
}

pub fn load_distribution_from_json(
  json_str: String,
) -> Result(dist.Distribution(Nil, Nil), LoadError) {
  let decoder =
    v4_json.decode_distribution(decode.success(Nil), decode.success(Nil))
  json.parse(json_str, decoder)
  |> map_error
}

pub fn load_vfs_manifest_from_json(
  json_str: String,
) -> Result(dist.VfsManifest, LoadError) {
  let decoder = v4_json.decode_vfs_manifest()
  json.parse(json_str, decoder)
  |> map_error
}

fn map_error(res: Result(a, json.DecodeError)) -> Result(a, LoadError) {
  case res {
    Ok(v) -> Ok(v)
    Error(e) -> Error(JsonError(e))
  }
}
