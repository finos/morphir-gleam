//// Morphir Models - Gleam port of the Morphir IR
////
//// This package provides the core data types for representing Morphir's
//// Intermediate Representation (IR) in Gleam. The IR is a language-agnostic
//// representation of business logic and domain models that can be used to
//// generate code in multiple target languages.
////
//// ## Module Organization
////
//// - `morphir/ir/name` - Name representation (convention-agnostic identifiers)
//// - `morphir/ir/path` - Path representation (hierarchical identifiers)
//// - `morphir/ir/qname` - Qualified names (module path + local name)
//// - `morphir/ir/fqname` - Fully qualified names (package + module + local)
//// - `morphir/ir/access_controlled` - Access control (public/private)
//// - `morphir/ir/documented` - Documentation wrapper
//// - `morphir/ir/literal` - Literal values (numbers, strings, etc.)
//// - `morphir/ir/type_` - Type expressions
//// - `morphir/ir/value` - Value expressions (business logic)
//// - `morphir/ir/module` - Module definitions
//// - `morphir/ir/package` - Package definitions
////
//// ## Example
////
//// ```gleam
//// import morphir/ir/name
//// import morphir/ir/fqname
////
//// // Create a name from a string
//// let my_name = name.from_string("myVariableName")
//// // ["my", "variable", "name"]
////
//// // Create a fully qualified name
//// let int_type = fqname.fqn("Morphir.SDK", "Basics", "Int")
//// ```

import morphir/ir/access_controlled
import morphir/ir/documented
import morphir/ir/fqname
import morphir/ir/literal
import morphir/ir/name
import morphir/ir/path
import morphir/ir/qname
import morphir/ir/type_
import morphir/ir/value

// Re-export commonly used types
pub type Name =
  name.Name

pub type Path =
  path.Path

pub type QName =
  qname.QName

pub type FQName =
  fqname.FQName

pub type Access =
  access_controlled.Access

pub type AccessControlled(a) =
  access_controlled.AccessControlled(a)

pub type Documented(a) =
  documented.Documented(a)

pub type Literal =
  literal.Literal

pub type Type(a) =
  type_.Type(a)

pub type Value(ta, va) =
  value.Value(ta, va)

pub type Pattern(a) =
  value.Pattern(a)
