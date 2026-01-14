//// Fully Qualified Name representation for the Morphir IR.
////
//// An FQName (Fully Qualified Name) combines a package path, module path,
//// and local name to uniquely identify any type or value across packages.

import gleam/string
import morphir/ir/name.{type Name}
import morphir/ir/path.{type Path}
import morphir/ir/qname.{type QName, QName}

/// An FQName is a fully qualified name consisting of:
/// - package_path: The path identifying the package
/// - module_path: The path identifying the module within the package
/// - local_name: The local name within the module
pub type FQName {
  FQName(package_path: Path, module_path: Path, local_name: Name)
}

/// Create an FQName from its components.
pub fn fqname(package_path: Path, module_path: Path, local_name: Name) -> FQName {
  FQName(package_path, module_path, local_name)
}

/// Create an FQName from a package path and a QName.
pub fn from_qname(package_path: Path, qn: QName) -> FQName {
  FQName(package_path, qn.module_path, qn.local_name)
}

/// Get the package path from an FQName.
pub fn get_package_path(fqn: FQName) -> Path {
  fqn.package_path
}

/// Get the module path from an FQName.
pub fn get_module_path(fqn: FQName) -> Path {
  fqn.module_path
}

/// Get the local name from an FQName.
pub fn get_local_name(fqn: FQName) -> Name {
  fqn.local_name
}

/// Get the QName (module path + local name) from an FQName.
pub fn get_qname(fqn: FQName) -> QName {
  QName(fqn.module_path, fqn.local_name)
}

/// Convert an FQName to a tuple.
pub fn to_tuple(fqn: FQName) -> #(Path, Path, Name) {
  #(fqn.package_path, fqn.module_path, fqn.local_name)
}

/// Create an FQName from a tuple.
pub fn from_tuple(tuple: #(Path, Path, Name)) -> FQName {
  FQName(tuple.0, tuple.1, tuple.2)
}

/// Convenience constructor accepting three strings.
/// Example: fqn("Morphir.SDK", "Basics", "Int") creates an FQName for Int.
pub fn fqn(package_str: String, module_str: String, local_str: String) -> FQName {
  FQName(
    path.from_string(package_str),
    path.from_string(module_str),
    name.from_string(local_str),
  )
}

/// Convert an FQName to a string using colon separators.
/// Example: "Morphir.SDK:Basics:int"
pub fn to_string(fqn: FQName) -> String {
  let package_str = path.to_string(fqn.package_path, name.to_title_case, ".")
  let module_str = path.to_string(fqn.module_path, name.to_title_case, ".")
  let local_str = name.to_camel_case(fqn.local_name)
  string.concat([package_str, ":", module_str, ":", local_str])
}

/// Parse an FQName from a string with a given separator.
pub fn from_string(str: String, separator: String) -> Result(FQName, Nil) {
  case string.split(str, separator) {
    [package_str, module_str, local_str] ->
      Ok(FQName(
        path.from_string(package_str),
        path.from_string(module_str),
        name.from_string(local_str),
      ))
    _ -> Error(Nil)
  }
}
