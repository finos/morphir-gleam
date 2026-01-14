import gleeunit
import gleeunit/should
import morphir/ir/name
import morphir/ir/path
import morphir/ir/qname
import morphir/ir/fqname

pub fn main() {
  gleeunit.main()
}

// Name tests

pub fn name_from_string_camel_case_test() {
  name.from_string("myVariableName")
  |> should.equal(["my", "variable", "name"])
}

pub fn name_from_string_snake_case_test() {
  name.from_string("my_variable_name")
  |> should.equal(["my", "variable", "name"])
}

pub fn name_from_string_pascal_case_test() {
  name.from_string("MyVariableName")
  |> should.equal(["my", "variable", "name"])
}

pub fn name_to_camel_case_test() {
  ["my", "variable", "name"]
  |> name.to_camel_case
  |> should.equal("myVariableName")
}

pub fn name_to_title_case_test() {
  ["my", "variable", "name"]
  |> name.to_title_case
  |> should.equal("MyVariableName")
}

pub fn name_to_snake_case_test() {
  ["my", "variable", "name"]
  |> name.to_snake_case
  |> should.equal("my_variable_name")
}

// Path tests

pub fn path_from_string_test() {
  path.from_string("Morphir.IR.Type")
  |> should.equal([["morphir"], ["i", "r"], ["type"]])
}

pub fn path_to_string_test() {
  [["morphir"], ["i", "r"], ["type"]]
  |> path.to_string(name.to_title_case, ".")
  |> should.equal("Morphir.IR.Type")
}

pub fn path_is_prefix_of_true_test() {
  path.is_prefix_of([["morphir"]], [["morphir"], ["i", "r"]])
  |> should.be_true
}

pub fn path_is_prefix_of_false_test() {
  path.is_prefix_of([["morphir"], ["i", "r"]], [["morphir"]])
  |> should.be_false
}

// QName tests

pub fn qname_from_string_test() {
  let qn = qname.from_string("Morphir.IR:type")
  qn.module_path |> should.equal([["morphir"], ["i", "r"]])
  qn.local_name |> should.equal(["type"])
}

pub fn qname_to_string_test() {
  qname.QName([["morphir"], ["i", "r"]], ["type"])
  |> qname.to_string
  |> should.equal("Morphir.IR:type")
}

// FQName tests

pub fn fqname_fqn_test() {
  let fqn = fqname.fqn("Morphir.SDK", "Basics", "Int")
  fqn.package_path |> should.equal([["morphir"], ["s", "d", "k"]])
  fqn.module_path |> should.equal([["basics"]])
  fqn.local_name |> should.equal(["int"])
}

pub fn fqname_to_string_test() {
  fqname.fqn("Morphir.SDK", "Basics", "Int")
  |> fqname.to_string
  |> should.equal("Morphir.SDK:Basics:int")
}
