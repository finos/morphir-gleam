//// Path representation for the Morphir IR.
////
//// A Path is a list of Names that identifies modules, packages, or other
//// hierarchical elements in the IR.

import gleam/list
import gleam/string
import morphir/ir/name.{type Name}

/// A Path is a list of Names forming a hierarchical identifier.
pub type Path =
  List(Name)

/// Create a Path from a list of Names.
pub fn from_list(names: List(Name)) -> Path {
  names
}

/// Convert a Path to a list of Names.
pub fn to_list(path: Path) -> List(Name) {
  path
}

/// Parse a string into a Path.
/// The string is split on dots (.) and each segment is parsed as a Name.
/// Example: "Morphir.IR.Type" -> [["morphir"], ["i", "r"], ["type"]]
pub fn from_string(str: String) -> Path {
  str
  |> string.split(".")
  |> list.map(name.from_string)
}

/// Convert a Path to a string using the given naming convention and separator.
pub fn to_string(
  path: Path,
  name_to_string: fn(Name) -> String,
  separator: String,
) -> String {
  path
  |> list.map(name_to_string)
  |> string.join(separator)
}

/// Check if one Path is a prefix of another.
pub fn is_prefix_of(prefix: Path, path: Path) -> Bool {
  case prefix, path {
    [], _ -> True
    _, [] -> False
    [p1, ..rest1], [p2, ..rest2] -> {
      case p1 == p2 {
        True -> is_prefix_of(rest1, rest2)
        False -> False
      }
    }
  }
}

/// Create an empty Path.
pub fn empty() -> Path {
  []
}

/// Append a Name to a Path.
pub fn append(path: Path, n: Name) -> Path {
  list.append(path, [n])
}

/// Concatenate two Paths.
pub fn concat(path1: Path, path2: Path) -> Path {
  list.append(path1, path2)
}
