//// Type representation for the Morphir IR.
////
//// This module defines the types for representing type expressions in the IR,
//// including variables, references, tuples, records, functions, and more.

import gleam/dict.{type Dict}
import morphir/ir/access_controlled.{type AccessControlled}
import morphir/ir/fqname.{type FQName}
import morphir/ir/name.{type Name}

/// A field in a record type.
pub type Field(a) {
  Field(name: Name, tpe: Type(a))
}

/// A type expression in the Morphir IR.
/// The type parameter `a` represents attributes (like source location info).
pub type Type(a) {
  /// A type variable (e.g., `a` in `List a`)
  Variable(attributes: a, name: Name)

  /// A reference to a named type with type arguments
  /// (e.g., `List Int` or `Dict String Value`)
  Reference(attributes: a, type_name: FQName, type_arguments: List(Type(a)))

  /// A tuple type (e.g., `#(Int, String)`)
  Tuple(attributes: a, element_types: List(Type(a)))

  /// A record type with named fields (e.g., `{ name: String, age: Int }`)
  Record(attributes: a, fields: List(Field(a)))

  /// An extensible record type (e.g., `{ a | name: String }`)
  ExtensibleRecord(attributes: a, variable_name: Name, fields: List(Field(a)))

  /// A function type (e.g., `Int -> String`)
  Function(attributes: a, argument_type: Type(a), return_type: Type(a))

  /// The unit type
  Unit(attributes: a)
}

/// Constructor arguments: a list of (name, type) pairs.
pub type ConstructorArgs(a) =
  List(#(Name, Type(a)))

/// Constructors for a custom type: a dictionary from constructor name to its arguments.
pub type Constructors(a) =
  Dict(Name, ConstructorArgs(a))

/// Details for a derived type specification.
pub type DerivedTypeSpecificationDetails(a) {
  DerivedTypeSpecificationDetails(
    base_type: Type(a),
    from_base_type: FQName,
    to_base_type: FQName,
  )
}

/// Type specification - the public interface of a type.
pub type Specification(a) {
  /// A type alias specification (e.g., `type alias UserId = String`)
  TypeAliasSpecification(type_params: List(Name), tpe: Type(a))

  /// An opaque type specification (only the type parameters are visible)
  OpaqueTypeSpecification(type_params: List(Name))

  /// A custom type specification (all constructors are visible)
  CustomTypeSpecification(type_params: List(Name), constructors: Constructors(a))

  /// A derived type specification (a type derived from a base type)
  DerivedTypeSpecification(
    type_params: List(Name),
    details: DerivedTypeSpecificationDetails(a),
  )
}

/// Type definition - the full implementation of a type.
pub type Definition(a) {
  /// A type alias definition
  TypeAliasDefinition(type_params: List(Name), tpe: Type(a))

  /// A custom type definition with access-controlled constructors
  CustomTypeDefinition(
    type_params: List(Name),
    constructors: AccessControlled(Constructors(a)),
  )
}

/// Get the attributes from a Type.
pub fn get_attributes(tpe: Type(a)) -> a {
  case tpe {
    Variable(a, _) -> a
    Reference(a, _, _) -> a
    Tuple(a, _) -> a
    Record(a, _) -> a
    ExtensibleRecord(a, _, _) -> a
    Function(a, _, _) -> a
    Unit(a) -> a
  }
}

/// Map a function over the attributes of a Type.
pub fn map_attributes(tpe: Type(a), f: fn(a) -> b) -> Type(b) {
  case tpe {
    Variable(a, name) -> Variable(f(a), name)
    Reference(a, fqn, args) ->
      Reference(f(a), fqn, map_list(args, fn(t) { map_attributes(t, f) }))
    Tuple(a, elems) ->
      Tuple(f(a), map_list(elems, fn(t) { map_attributes(t, f) }))
    Record(a, fields) ->
      Record(f(a), map_list(fields, fn(field) { map_field_attributes(field, f) }))
    ExtensibleRecord(a, var_name, fields) ->
      ExtensibleRecord(
        f(a),
        var_name,
        map_list(fields, fn(field) { map_field_attributes(field, f) }),
      )
    Function(a, arg, ret) ->
      Function(f(a), map_attributes(arg, f), map_attributes(ret, f))
    Unit(a) -> Unit(f(a))
  }
}

fn map_field_attributes(field: Field(a), f: fn(a) -> b) -> Field(b) {
  Field(field.name, map_attributes(field.tpe, f))
}

fn map_list(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [x, ..xs] -> [f(x), ..map_list(xs, f)]
  }
}
