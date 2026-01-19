//// Value representation for Morphir IR v4.
////
//// This module defines the types for representing value expressions in the IR v4.

import gleam/option.{type Option}
import morphir/ir/access_controlled.{type AccessControlled}
import morphir/ir/fqname.{type FQName}
import morphir/ir/literal.{type Literal}
import morphir/ir/name.{type Name}
import morphir/ir/v4/type_.{type Type}

/// A pattern for pattern matching.
pub type Pattern(va) {
  WildcardPattern(attributes: va)
  AsPattern(attributes: va, pattern: Pattern(va), name: Name)
  TuplePattern(attributes: va, element_patterns: List(Pattern(va)))
  ConstructorPattern(
    attributes: va,
    constructor: FQName,
    args: List(Pattern(va)),
  )
  EmptyListPattern(attributes: va)
  HeadTailPattern(
    attributes: va,
    head_pattern: Pattern(va),
    tail_pattern: Pattern(va),
  )
  LiteralPattern(attributes: va, value: Literal)
  UnitPattern(attributes: va)
}

/// Hints for native functions.
pub type NativeHint {
  Arithmetic
  Comparison
  StringOp
  CollectionOp
  PlatformSpecific(platform: String)
}

/// Details about a native function.
pub type NativeInfo {
  NativeInfo(hint: NativeHint, description: Option(String))
}

/// Reason for a hole in the value.
///
/// Holes represent incomplete or missing parts of the code. This type details why a hole exists.
pub type HoleReason {
  /// The value refers to a name that could not be resolved in the current scope.
  UnresolvedReference(target: FQName)
  /// The code was removed during a refactoring operation. `tx_id` identifies the transaction.
  DeletedDuringRefactor(tx_id: String)
  /// A type mismatch was detected. `expected` describes the required type, `found` describes the actual type.
  TypeMismatch(expected: String, found: String)
}

/// Incompleteness status for values.
///
/// This type tracks whether a value definition is fully complete or has gaps (holes) or is in a draft state.
pub type Incompleteness {
  /// The value contains a specific hole with a given reason.
  Hole(reason: HoleReason)
  /// The value is a draft and may not be fully implemented or checked. `notes` provides optional context.
  Draft(notes: Option(String))
}

/// The body of a value definition.
pub type DefinitionBody(ta, va) {
  ExpressionBody(
    input_types: List(#(Name, Type(ta))),
    output_type: Type(ta),
    body: Value(ta, va),
  )
  NativeBody(
    input_types: List(#(Name, Type(ta))),
    output_type: Type(ta),
    native_info: NativeInfo,
  )
  ExternalBody(
    input_types: List(#(Name, Type(ta))),
    output_type: Type(ta),
    external_name: String,
    target_platform: String,
  )
  IncompleteBody(
    input_types: List(#(Name, Type(ta))),
    output_type: Option(Type(ta)),
    incompleteness: Incompleteness,
    partial_body: Option(Value(ta, va)),
  )
}

/// A value definition.
pub type Definition(ta, va) {
  Definition(body: AccessControlled(DefinitionBody(ta, va)))
}

/// A value specification.
pub type Specification(ta) {
  Specification(inputs: List(#(Name, Type(ta))), output: Type(ta))
}

/// A value expression in Morphir IR v4.
/// `ta` is Type Attributes, `va` is Value Attributes.
pub type Value(ta, va) {
  Literal(attributes: va, value: Literal)
  Constructor(attributes: va, fq_name: FQName)
  Tuple(attributes: va, elements: List(Value(ta, va)))
  List(attributes: va, items: List(Value(ta, va)))
  Record(attributes: va, fields: List(#(Name, Value(ta, va))))
  Unit(attributes: va)
  Variable(attributes: va, name: Name)
  Reference(attributes: va, fq_name: FQName)
  Field(attributes: va, record: Value(ta, va), field_name: Name)
  FieldFunction(attributes: va, field_name: Name)
  Apply(attributes: va, function: Value(ta, va), argument: Value(ta, va))
  Lambda(attributes: va, argument_pattern: Pattern(va), body: Value(ta, va))
  LetDefinition(
    attributes: va,
    name: Name,
    definition: DefinitionBody(ta, va),
    in_value: Value(ta, va),
  )
  LetRecursion(
    attributes: va,
    definitions: List(#(Name, DefinitionBody(ta, va))),
    in_value: Value(ta, va),
  )
  Destructure(
    attributes: va,
    pattern: Pattern(va),
    value_to_destructure: Value(ta, va),
    in_value: Value(ta, va),
  )
  IfThenElse(
    attributes: va,
    condition: Value(ta, va),
    then_branch: Value(ta, va),
    else_branch: Value(ta, va),
  )
  PatternMatch(
    attributes: va,
    subject: Value(ta, va),
    cases: List(#(Pattern(va), Value(ta, va))),
  )
  UpdateRecord(
    attributes: va,
    record: Value(ta, va),
    updates: List(#(Name, Value(ta, va))),
  )
  HoleValue(attributes: va, reason: HoleReason, expected_type: Option(Type(ta)))
  Native(attributes: va, fq_name: FQName, native_info: NativeInfo)
  External(attributes: va, external_name: String, target_platform: String)
}

/// Get the attributes from a Value.
pub fn get_attributes(value: Value(ta, va)) -> va {
  case value {
    Literal(a, _) -> a
    Constructor(a, _) -> a
    Tuple(a, _) -> a
    List(a, _) -> a
    Record(a, _) -> a
    Unit(a) -> a
    Variable(a, _) -> a
    Reference(a, _) -> a
    Field(a, _, _) -> a
    FieldFunction(a, _) -> a
    Apply(a, _, _) -> a
    Lambda(a, _, _) -> a
    LetDefinition(a, _, _, _) -> a
    LetRecursion(a, _, _) -> a
    Destructure(a, _, _, _) -> a
    IfThenElse(a, _, _, _) -> a
    PatternMatch(a, _, _) -> a
    UpdateRecord(a, _, _) -> a
    HoleValue(a, _, _) -> a
    Native(a, _, _) -> a
    External(a, _, _) -> a
  }
}
