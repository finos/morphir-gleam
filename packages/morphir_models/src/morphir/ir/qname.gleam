//// Qualified Name representation for the Morphir IR.
////
//// A QName (Qualified Name) combines a module path with a local name,
//// uniquely identifying a type or value within a module.

import gleam/string
import morphir/ir/name.{type Name}
import morphir/ir/path.{type Path}

/// A QName is a module path combined with a local name.
pub type QName {
  QName(module_path: Path, local_name: Name)
}

/// Create a QName from a module path and local name.
pub fn qname(module_path: Path, local_name: Name) -> QName {
  QName(module_path, local_name)
}

/// Create a QName from a tuple.
pub fn from_tuple(tuple: #(Path, Name)) -> QName {
  QName(tuple.0, tuple.1)
}

/// Convert a QName to a tuple.
pub fn to_tuple(qn: QName) -> #(Path, Name) {
  #(qn.module_path, qn.local_name)
}

/// Get the module path from a QName.
pub fn get_module_path(qn: QName) -> Path {
  qn.module_path
}

/// Get the local name from a QName.
pub fn get_local_name(qn: QName) -> Name {
  qn.local_name
}

/// Create a QName from just a name (with an empty module path).
pub fn from_name(n: Name) -> QName {
  QName([], n)
}

/// Convert a QName to a string representation.
/// Example: QName([["morphir"], ["i", "r"]], ["type"]) -> "Morphir.IR:type"
pub fn to_string(qn: QName) -> String {
  let module_str = path.to_string(qn.module_path, name.to_title_case, ".")
  let local_str = name.to_camel_case(qn.local_name)
  string.concat([module_str, ":", local_str])
}

/// Parse a QName from a string.
/// Example: "Morphir.IR:type" -> QName([["morphir"], ["i", "r"]], ["type"])
pub fn from_string(str: String) -> QName {
  case string.split(str, ":") {
    [module_str, local_str] ->
      QName(path.from_string(module_str), name.from_string(local_str))
    _ -> QName([], name.from_string(str))
  }
}
