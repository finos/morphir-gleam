//// Literal values for the Morphir IR.
////
//// This module defines the types for representing fixed/constant values
//// in the IR, such as booleans, numbers, strings, and characters.

/// A literal value representing a fixed/constant value in the IR.
pub type Literal {
  /// Boolean literal (True or False)
  BoolLiteral(value: Bool)
  /// Character literal (a single character)
  CharLiteral(value: String)
  /// String literal
  StringLiteral(value: String)
  /// Whole number (integer) literal
  WholeNumberLiteral(value: Int)
  /// Floating-point number literal
  FloatLiteral(value: Float)
  /// Decimal literal (stored as string for precision)
  /// Note: Gleam doesn't have a built-in Decimal type, so we use String
  DecimalLiteral(value: String)
}

/// Create a boolean literal.
pub fn bool_literal(value: Bool) -> Literal {
  BoolLiteral(value)
}

/// Create a character literal.
pub fn char_literal(value: String) -> Literal {
  CharLiteral(value)
}

/// Create a string literal.
pub fn string_literal(value: String) -> Literal {
  StringLiteral(value)
}

/// Create a whole number literal.
pub fn whole_number_literal(value: Int) -> Literal {
  WholeNumberLiteral(value)
}

/// Create a floating-point literal.
pub fn float_literal(value: Float) -> Literal {
  FloatLiteral(value)
}

/// Create a decimal literal.
pub fn decimal_literal(value: String) -> Literal {
  DecimalLiteral(value)
}
