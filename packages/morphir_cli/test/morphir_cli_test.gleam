import gleeunit
import gleeunit/should
import morphir_cli/commands/version

pub fn main() {
  gleeunit.main()
}

pub fn version_string_test() {
  version.version_string()
  |> should.equal("morphir-cli 0.1.0")
}

pub fn version_constant_test() {
  version.version
  |> should.equal("0.1.0")
}
