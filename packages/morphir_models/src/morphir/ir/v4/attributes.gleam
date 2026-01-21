//// Attributes and Properties for Morphir IR v4.
////
//// This module defines the concrete Attribute types that tie together the
//// Generic Type and Value definitions.

import gleam/dict.{type Dict}
import gleam/option.{type Option}
import morphir/ir/fqname.{type FQName}

// import morphir/ir/name.{type Name} // Not strictly needed unless referenced
import morphir/ir/v4/type_.{type Type}
import morphir/ir/v4/value.{type Value}

pub type SourceLocation {
  SourceLocation(file: Option(String), line: Int, column: Int)
}

pub type IntWidth {
  I8
  I16
  I32
  I64
}

pub type FloatWidth {
  F32
  F64
}

pub type NumericConstraint {
  Arbitrary
  Signed(bits: IntWidth)
  Unsigned(bits: IntWidth)
  FloatingPoint(bits: FloatWidth)
  // Bounded(min: Option(BigInt), max: Option(BigInt)) // Gleam no BigInt builtin usually?
  // We'll use Int for now or String if needed. Scala uses BigInt.
  // Given Literal uses Int for WholeNumberLiteral, we'll use Int here.
  Bounded(min: Option(Int), max: Option(Int))
  Decimal(precision: Int, scale: Int)
}

pub type StringEncoding {
  UTF8
  UTF16
  ASCII
  Latin1
}

pub type StringConstraint {
  StringConstraint(
    encoding: Option(StringEncoding),
    min_length: Option(Int),
    max_length: Option(Int),
    pattern: Option(String),
  )
}

pub type CollectionConstraint {
  CollectionConstraint(
    min_length: Option(Int),
    max_length: Option(Int),
    unique_items: Bool,
  )
}

pub type CustomConstraint {
  CustomConstraint(
    predicate: FQName,
    arguments: List(Value(TypeAttributes, ValueAttributes)),
  )
}

pub type TypeConstraints {
  TypeConstraints(
    numeric: Option(NumericConstraint),
    string: Option(StringConstraint),
    collection: Option(CollectionConstraint),
    custom: List(CustomConstraint),
  )
}

pub type TypeAttributes {
  TypeAttributes(
    source: Option(SourceLocation),
    constraints: Option(TypeConstraints),
    extensions: Dict(FQName, Value(TypeAttributes, ValueAttributes)),
  )
}

pub type Purity {
  Pure
  Effectful
  Unknown
}

pub type ValueProperties {
  ValueProperties(is_constant: Bool, purity: Purity)
}

pub type ValueAttributes {
  ValueAttributes(
    source: Option(SourceLocation),
    inferred_type: Option(Type(TypeAttributes)),
    properties: Option(ValueProperties),
    extensions: Dict(FQName, Value(TypeAttributes, ValueAttributes)),
  )
}
