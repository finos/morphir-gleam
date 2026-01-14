//// Access control for the Morphir IR.
////
//// This module provides types for declaring access levels on types and values,
//// allowing modules to expose public interfaces while keeping implementations private.

/// Access level for types and values.
pub type Access {
  /// Publicly accessible to all modules.
  Public
  /// Only accessible within the same module.
  Private
}

/// A value with an associated access level.
pub type AccessControlled(a) {
  AccessControlled(access: Access, value: a)
}

/// Create a public AccessControlled value.
pub fn public(value: a) -> AccessControlled(a) {
  AccessControlled(Public, value)
}

/// Create a private AccessControlled value.
pub fn private(value: a) -> AccessControlled(a) {
  AccessControlled(Private, value)
}

/// Get the access level.
pub fn get_access(ac: AccessControlled(a)) -> Access {
  ac.access
}

/// Get the value regardless of access level.
/// Use this when you have permission to access the value.
pub fn get_value(ac: AccessControlled(a)) -> a {
  ac.value
}

/// Try to get the value with public access.
/// Returns Ok(value) if public, Error(Nil) if private.
pub fn with_public_access(ac: AccessControlled(a)) -> Result(a, Nil) {
  case ac.access {
    Public -> Ok(ac.value)
    Private -> Error(Nil)
  }
}

/// Get the value with private access (always succeeds).
/// This represents having full access to the module's internals.
pub fn with_private_access(ac: AccessControlled(a)) -> a {
  ac.value
}

/// Map a function over the contained value.
pub fn map(ac: AccessControlled(a), f: fn(a) -> b) -> AccessControlled(b) {
  AccessControlled(ac.access, f(ac.value))
}
