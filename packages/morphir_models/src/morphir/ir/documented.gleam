//// Documentation wrapper for the Morphir IR.
////
//// This module provides a type for attaching documentation strings to values,
//// enabling self-documenting IR representations.

/// A documented value containing both a documentation string and the value itself.
pub type Documented(a) {
  Documented(doc: String, value: a)
}

/// Create a Documented value.
pub fn documented(doc: String, value: a) -> Documented(a) {
  Documented(doc, value)
}

/// Get the documentation string.
pub fn get_doc(d: Documented(a)) -> String {
  d.doc
}

/// Get the underlying value.
pub fn get_value(d: Documented(a)) -> a {
  d.value
}

/// Map a function over the documented value while preserving documentation.
pub fn map(d: Documented(a), f: fn(a) -> b) -> Documented(b) {
  Documented(d.doc, f(d.value))
}

/// Create a Documented value with empty documentation.
pub fn undocumented(value: a) -> Documented(a) {
  Documented("", value)
}
