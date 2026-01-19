//// Type representation for Morphir IR v4.
////
//// This module defines the types for representing type expressions in the IR v4.

import morphir/ir/access_controlled.{type AccessControlled}
import morphir/ir/fqname.{type FQName}
import morphir/ir/name.{type Name}
import gleam/option.{type Option}

/// A field in a record type.
pub type Field(a) {
  Field(name: Name, tpe: Type(a))
}

/// A type expression in the Morphir IR v4.
/// The type parameter `a` represents attributes.
pub type Type(a) {
  Variable(attributes: a, name: Name)
  Reference(attributes: a, fq_name: FQName, args: List(Type(a)))
  Tuple(attributes: a, elements: List(Type(a)))
  Record(attributes: a, fields: List(Field(a)))
  ExtensibleRecord(attributes: a, variable: Name, fields: List(Field(a)))
  Function(attributes: a, argument_type: Type(a), return_type: Type(a))
  Unit(attributes: a)
}

/// A constructor definition for Custom Types.
pub type Constructor(a) {
  Constructor(name: Name, args: List(#(Name, Type(a))))
}

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
  TypeAliasSpecification(params: List(Name), tpe: Type(a))
  OpaqueTypeSpecification(params: List(Name))
  CustomTypeSpecification(
    params: List(Name),
    constructors: List(Constructor(a)),
  )
  DerivedTypeSpecification(
    params: List(Name),
    details: DerivedTypeSpecificationDetails(a),
  )
}

/// Information about why a type definition is incomplete.
pub type HoleReason {
  UnresolvedReference(target: FQName)
  DeletedDuringRefactor(tx_id: String)
  TypeMismatch(expected: String, found: String)
}

/// Incompleteness status.
pub type Incompleteness {
  Hole(reason: HoleReason)
  Draft(notes: Option(String))
}

/// Type definition - the full implementation of a type.
pub type Definition(a) {
  CustomTypeDefinition(
    params: List(Name),
    constructors: AccessControlled(List(Constructor(a))),
  )
  TypeAliasDefinition(params: List(Name), tpe: Type(a))
  IncompleteTypeDefinition(
    params: List(Name),
    incompleteness: Incompleteness,
    partial_body: Option(Type(a)),
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
