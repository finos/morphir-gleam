import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleeunit
import gleeunit/should
import morphir/ir/literal
import morphir/ir/name
import morphir/ir/v4/json as v4_json
import morphir/ir/v4/type_ as t
import morphir/ir/v4/value as v

pub fn main() {
  gleeunit.main()
}

pub fn encode_name_test() {
  let name = name.from_list(["foo", "bar"])
  v4_json.encode_name(name)
  |> json.to_string
  |> should.equal("[\"foo\",\"bar\"]")
}

pub fn encode_type_test() {
  let unit_type = t.Unit(Nil)
  v4_json.encode_type(unit_type, fn(_) { json.null() })
  |> json.to_string
  |> should.equal("[\"Unit\",null]")

  let var_type = t.Variable(Nil, name.from_list(["a"]))
  v4_json.encode_type(var_type, fn(_) { json.null() })
  |> json.to_string
  |> should.equal("[\"Variable\",null,[\"a\"]]")
}

pub fn encode_value_test() {
  let lit = literal.BoolLiteral(True)
  let val = v.Literal(Nil, lit)
  v4_json.encode_value(val, fn(_) { json.null() }, fn(_) { json.null() })
  |> json.to_string
  |> should.equal("[\"Literal\",null,[\"BoolLiteral\",true]]")
}

pub fn decode_name_test() {
  let json_str = "[\"foo\",\"bar\"]"
  let assert Ok(name) = json.parse(json_str, v4_json.decode_name())
  name |> name.to_list |> should.equal(["foo", "bar"])
}

pub fn decode_literal_test() {
  let json_bool = "[\"BoolLiteral\", true]"
  let assert Ok(lit) = json.parse(json_bool, v4_json.decode_literal())
  lit |> should.equal(literal.BoolLiteral(True))

  let json_int = "[\"WholeNumberLiteral\", 123]"
  let assert Ok(lit) = json.parse(json_int, v4_json.decode_literal())
  lit |> should.equal(literal.WholeNumberLiteral(123))
}

pub fn decode_type_test() {
  let json_unit = "[\"Unit\", null]"
  let assert Ok(tpe) =
    json.parse(json_unit, v4_json.decode_type(decode.optional(decode.int)))
  tpe |> should.equal(t.Unit(option.None))

  let json_var = "[\"Variable\", null, [\"a\"]]"
  let assert Ok(tpe) =
    json.parse(json_var, v4_json.decode_type(decode.optional(decode.int)))
  tpe |> should.equal(t.Variable(option.None, name.from_list(["a"])))
}

pub fn decode_value_test() {
  let json_lit = "[\"Literal\", null, [\"BoolLiteral\", true]]"
  let assert Ok(val) =
    json.parse(
      json_lit,
      v4_json.decode_value(
        decode.optional(decode.int),
        decode.optional(decode.int),
      ),
    )
  val |> should.equal(v.Literal(option.None, literal.BoolLiteral(True)))

  let json_list =
    "[\"List\", null, [[\"Literal\", null, [\"WholeNumberLiteral\", 123]]]]"
  let assert Ok(val) =
    json.parse(
      json_list,
      v4_json.decode_value(
        decode.optional(decode.int),
        decode.optional(decode.int),
      ),
    )
  val
  |> should.equal(
    v.List(option.None, [
      v.Literal(option.None, literal.WholeNumberLiteral(123)),
    ]),
  )
}

pub fn decode_definition_body_test() {
  let json_body = "[\"ExpressionBody\", [], [\"Unit\", null], [\"Unit\", null]]"
  let assert Ok(body) =
    json.parse(
      json_body,
      v4_json.decode_definition_body(
        decode.optional(decode.int),
        decode.optional(decode.int),
      ),
    )
  body
  |> should.equal(v.ExpressionBody([], t.Unit(option.None), v.Unit(option.None)))
}
