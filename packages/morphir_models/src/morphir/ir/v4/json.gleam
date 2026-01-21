//// JSON Codecs for Morphir IR v4.
////
//// This module provides functions to encode and decode Morphir IR v4 types
//// to and from JSON.

import gleam/dict

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import morphir/ir/access_controlled as ac
import morphir/ir/documented as doc
import morphir/ir/fqname
import morphir/ir/literal
import morphir/ir/name
import morphir/ir/path
import morphir/ir/qname
import morphir/ir/v4/distribution as dist
import morphir/ir/v4/type_ as t
import morphir/ir/v4/value as v

@external(erlang, "morphir_models_ffi", "coerce")
@external(javascript, "./../../../morphir_models_ffi.mjs", "coerce")
fn unsafe_coerce(x: a) -> b

fn unsafe_zero() -> a {
  unsafe_coerce(Nil)
}

// --- Encoders ---

pub fn encode_option(
  opt: option.Option(a),
  encoder: fn(a) -> json.Json,
) -> json.Json {
  case opt {
    Some(val) -> encoder(val)
    None -> json.null()
  }
}

pub fn encode_list(l: List(a), encoder: fn(a) -> json.Json) -> json.Json {
  json.preprocessed_array(list.map(l, encoder))
}

pub fn encode_dict(
  d: dict.Dict(k, v),
  key_encoder: fn(k) -> json.Json,
  val_encoder: fn(v) -> json.Json,
) -> json.Json {
  json.preprocessed_array(
    dict.to_list(d)
    |> list.map(fn(pair) {
      json.preprocessed_array([key_encoder(pair.0), val_encoder(pair.1)])
    }),
  )
}

pub fn encode_access_controlled(
  ac_val: ac.AccessControlled(a),
  encoder: fn(a) -> json.Json,
) -> json.Json {
  case ac_val.access {
    ac.Public ->
      json.preprocessed_array([json.string("Public"), encoder(ac_val.value)])
    ac.Private ->
      json.preprocessed_array([json.string("Private"), encoder(ac_val.value)])
  }
}

pub fn encode_documented(
  doc_val: doc.Documented(a),
  encoder: fn(a) -> json.Json,
) -> json.Json {
  case doc_val {
    doc.Documented(doc_str, val) ->
      json.preprocessed_array([
        json.string("Documented"),
        json.string(doc_str),
        encoder(val),
      ])
  }
}

pub fn encode_name(name: name.Name) -> json.Json {
  json.preprocessed_array(name.to_list(name) |> list.map(json.string))
}

pub fn encode_path(path: path.Path) -> json.Json {
  json.preprocessed_array(path.to_list(path) |> list.map(encode_name))
}

pub fn encode_qname(qname: qname.QName) -> json.Json {
  json.preprocessed_array([
    encode_path(qname.get_module_path(qname)),
    encode_name(qname.get_local_name(qname)),
  ])
}

pub fn encode_fqname(fqname: fqname.FQName) -> json.Json {
  json.preprocessed_array([
    encode_path(fqname.get_package_path(fqname)),
    encode_path(fqname.get_module_path(fqname)),
    encode_name(fqname.get_local_name(fqname)),
  ])
}

pub fn encode_literal(literal: literal.Literal) -> json.Json {
  case literal {
    literal.BoolLiteral(value) ->
      json.preprocessed_array([json.string("BoolLiteral"), json.bool(value)])
    literal.CharLiteral(value) ->
      json.preprocessed_array([json.string("CharLiteral"), json.string(value)])
    literal.StringLiteral(value) ->
      json.preprocessed_array([json.string("StringLiteral"), json.string(value)])
    literal.WholeNumberLiteral(value) ->
      json.preprocessed_array([
        json.string("WholeNumberLiteral"),
        json.int(value),
      ])
    literal.FloatLiteral(value) ->
      json.preprocessed_array([json.string("FloatLiteral"), json.float(value)])
    literal.DecimalLiteral(value) ->
      json.preprocessed_array([
        json.string("DecimalLiteral"),
        json.string(value),
      ])
  }
}

pub fn encode_type(
  tpe: t.Type(a),
  encode_attributes: fn(a) -> json.Json,
) -> json.Json {
  case tpe {
    t.Variable(a, name) ->
      json.preprocessed_array([
        json.string("Variable"),
        encode_attributes(a),
        encode_name(name),
      ])
    t.Reference(a, fqn, args) ->
      json.preprocessed_array([
        json.string("Reference"),
        encode_attributes(a),
        encode_fqname(fqn),
        json.preprocessed_array(
          list.map(args, fn(x) { encode_type(x, encode_attributes) }),
        ),
      ])
    t.Tuple(a, elements) ->
      json.preprocessed_array([
        json.string("Tuple"),
        encode_attributes(a),
        json.preprocessed_array(
          list.map(elements, fn(x) { encode_type(x, encode_attributes) }),
        ),
      ])
    t.Record(a, fields) ->
      json.preprocessed_array([
        json.string("Record"),
        encode_attributes(a),
        json.preprocessed_array(
          list.map(fields, fn(f) {
            json.preprocessed_array([
              encode_name(f.name),
              encode_type(f.tpe, encode_attributes),
            ])
          }),
        ),
      ])
    t.ExtensibleRecord(a, name, fields) ->
      json.preprocessed_array([
        json.string("ExtensibleRecord"),
        encode_attributes(a),
        encode_name(name),
        json.preprocessed_array(
          list.map(fields, fn(f) {
            json.preprocessed_array([
              encode_name(f.name),
              encode_type(f.tpe, encode_attributes),
            ])
          }),
        ),
      ])
    t.Function(a, arg_type, return_type) ->
      json.preprocessed_array([
        json.string("Function"),
        encode_attributes(a),
        encode_type(arg_type, encode_attributes),
        encode_type(return_type, encode_attributes),
      ])
    t.Unit(a) ->
      json.preprocessed_array([json.string("Unit"), encode_attributes(a)])
  }
}

pub fn encode_type_constructor(
  ctor: t.Constructor(a),
  encode_attributes: fn(a) -> json.Json,
) -> json.Json {
  case ctor {
    t.Constructor(name, args) ->
      json.preprocessed_array([
        json.string("Constructor"),
        encode_name(name),
        json.preprocessed_array(
          list.map(args, fn(arg) {
            json.preprocessed_array([
              encode_name(arg.0),
              encode_type(arg.1, encode_attributes),
            ])
          }),
        ),
      ])
  }
}

pub fn encode_type_definition(
  def: t.Definition(a),
  encode_attributes: fn(a) -> json.Json,
) -> json.Json {
  case def {
    t.CustomTypeDefinition(params, ctors) ->
      json.preprocessed_array([
        json.string("CustomTypeDefinition"),
        encode_list(params, encode_name),
        encode_access_controlled(ctors, fn(c_list) {
          encode_list(c_list, fn(c) {
            encode_type_constructor(c, encode_attributes)
          })
        }),
      ])
    t.TypeAliasDefinition(params, tpe) ->
      json.preprocessed_array([
        json.string("TypeAliasDefinition"),
        encode_list(params, encode_name),
        encode_type(tpe, encode_attributes),
      ])
    t.IncompleteTypeDefinition(params, _, partial) ->
      json.preprocessed_array([
        json.string("IncompleteTypeDefinition"),
        encode_list(params, encode_name),
        // TODO: encode_incompleteness
        json.null(),
        encode_option(partial, fn(p) { encode_type(p, encode_attributes) }),
      ])
  }
}

pub fn encode_type_specification(
  spec: t.Specification(a),
  encode_attributes: fn(a) -> json.Json,
) -> json.Json {
  case spec {
    t.TypeAliasSpecification(params, tpe) ->
      json.preprocessed_array([
        json.string("TypeAliasSpecification"),
        encode_list(params, encode_name),
        encode_type(tpe, encode_attributes),
      ])
    t.OpaqueTypeSpecification(params) ->
      json.preprocessed_array([
        json.string("OpaqueTypeSpecification"),
        encode_list(params, encode_name),
      ])
    t.CustomTypeSpecification(params, ctors) ->
      json.preprocessed_array([
        json.string("CustomTypeSpecification"),
        encode_list(params, encode_name),
        encode_list(ctors, fn(c) {
          encode_type_constructor(c, encode_attributes)
        }),
      ])
    t.DerivedTypeSpecification(params, details) ->
      json.preprocessed_array([
        json.string("DerivedTypeSpecification"),
        encode_list(params, encode_name),
        json.preprocessed_array([
          json.string("DerivedTypeSpecificationDetails"),
          encode_type(details.base_type, encode_attributes),
          encode_fqname(details.from_base_type),
          encode_fqname(details.to_base_type),
        ]),
      ])
  }
}

pub fn encode_pattern(
  pattern: v.Pattern(va),
  encode_attributes: fn(va) -> json.Json,
) -> json.Json {
  case pattern {
    v.WildcardPattern(a) ->
      json.preprocessed_array([
        json.string("WildcardPattern"),
        encode_attributes(a),
      ])
    v.AsPattern(a, pat, name) ->
      json.preprocessed_array([
        json.string("AsPattern"),
        encode_attributes(a),
        encode_pattern(pat, encode_attributes),
        encode_name(name),
      ])
    v.TuplePattern(a, patterns) ->
      json.preprocessed_array([
        json.string("TuplePattern"),
        encode_attributes(a),
        json.preprocessed_array(
          list.map(patterns, fn(p) { encode_pattern(p, encode_attributes) }),
        ),
      ])
    v.ConstructorPattern(a, fqn, args) ->
      json.preprocessed_array([
        json.string("ConstructorPattern"),
        encode_attributes(a),
        encode_fqname(fqn),
        json.preprocessed_array(
          list.map(args, fn(p) { encode_pattern(p, encode_attributes) }),
        ),
      ])
    v.EmptyListPattern(a) ->
      json.preprocessed_array([
        json.string("EmptyListPattern"),
        encode_attributes(a),
      ])
    v.HeadTailPattern(a, head, tail) ->
      json.preprocessed_array([
        json.string("HeadTailPattern"),
        encode_attributes(a),
        encode_pattern(head, encode_attributes),
        encode_pattern(tail, encode_attributes),
      ])
    v.LiteralPattern(a, lit) ->
      json.preprocessed_array([
        json.string("LiteralPattern"),
        encode_attributes(a),
        encode_literal(lit),
      ])
    v.UnitPattern(a) ->
      json.preprocessed_array([json.string("UnitPattern"), encode_attributes(a)])
  }
}

pub fn encode_value(
  val: v.Value(ta, va),
  encode_type_attributes: fn(ta) -> json.Json,
  encode_value_attributes: fn(va) -> json.Json,
) -> json.Json {
  let encode_val = fn(v) {
    encode_value(v, encode_type_attributes, encode_value_attributes)
  }
  let encode_pat = fn(p) { encode_pattern(p, encode_value_attributes) }

  case val {
    v.Literal(a, lit) ->
      json.preprocessed_array([
        json.string("Literal"),
        encode_value_attributes(a),
        encode_literal(lit),
      ])
    v.Constructor(a, fqn) ->
      json.preprocessed_array([
        json.string("Constructor"),
        encode_value_attributes(a),
        encode_fqname(fqn),
      ])
    v.Tuple(a, elements) ->
      json.preprocessed_array([
        json.string("Tuple"),
        encode_value_attributes(a),
        json.preprocessed_array(list.map(elements, encode_val)),
      ])
    v.List(a, items) ->
      json.preprocessed_array([
        json.string("List"),
        encode_value_attributes(a),
        json.preprocessed_array(list.map(items, encode_val)),
      ])
    v.Record(a, fields) ->
      json.preprocessed_array([
        json.string("Record"),
        encode_value_attributes(a),
        json.preprocessed_array(
          list.map(fields, fn(f) {
            json.preprocessed_array([encode_name(f.0), encode_val(f.1)])
          }),
        ),
      ])
    v.Unit(a) ->
      json.preprocessed_array([json.string("Unit"), encode_value_attributes(a)])
    v.Variable(a, name) ->
      json.preprocessed_array([
        json.string("Variable"),
        encode_value_attributes(a),
        encode_name(name),
      ])
    v.Reference(a, fqn) ->
      json.preprocessed_array([
        json.string("Reference"),
        encode_value_attributes(a),
        encode_fqname(fqn),
      ])
    v.Field(a, record, name) ->
      json.preprocessed_array([
        json.string("Field"),
        encode_value_attributes(a),
        encode_val(record),
        encode_name(name),
      ])
    v.FieldFunction(a, name) ->
      json.preprocessed_array([
        json.string("FieldFunction"),
        encode_value_attributes(a),
        encode_name(name),
      ])
    v.Apply(a, func, arg) ->
      json.preprocessed_array([
        json.string("Apply"),
        encode_value_attributes(a),
        encode_val(func),
        encode_val(arg),
      ])
    v.Lambda(a, pat, body) ->
      json.preprocessed_array([
        json.string("Lambda"),
        encode_value_attributes(a),
        encode_pat(pat),
        encode_val(body),
      ])
    v.LetDefinition(a, name, def, in_val) ->
      json.preprocessed_array([
        json.string("LetDefinition"),
        encode_value_attributes(a),
        encode_name(name),
        encode_definition_body(
          def,
          encode_type_attributes,
          encode_value_attributes,
        ),
        encode_val(in_val),
      ])
    v.LetRecursion(a, defs, in_val) ->
      json.preprocessed_array([
        json.string("LetRecursion"),
        encode_value_attributes(a),
        json.preprocessed_array(
          list.map(defs, fn(d) {
            json.preprocessed_array([
              encode_name(d.0),
              encode_definition_body(
                d.1,
                encode_type_attributes,
                encode_value_attributes,
              ),
            ])
          }),
        ),
        encode_val(in_val),
      ])
    v.Destructure(a, pat, value, in_val) ->
      json.preprocessed_array([
        json.string("Destructure"),
        encode_value_attributes(a),
        encode_pat(pat),
        encode_val(value),
        encode_val(in_val),
      ])
    v.IfThenElse(a, cond_val, then_val, else_val) ->
      json.preprocessed_array([
        json.string("IfThenElse"),
        encode_value_attributes(a),
        encode_val(cond_val),
        encode_val(then_val),
        encode_val(else_val),
      ])
    v.PatternMatch(a, subject, cases) ->
      json.preprocessed_array([
        json.string("PatternMatch"),
        encode_value_attributes(a),
        encode_val(subject),
        json.preprocessed_array(
          list.map(cases, fn(case_) {
            json.preprocessed_array([encode_pat(case_.0), encode_val(case_.1)])
          }),
        ),
      ])
    v.UpdateRecord(a, record, updates) ->
      json.preprocessed_array([
        json.string("UpdateRecord"),
        encode_value_attributes(a),
        encode_val(record),
        json.preprocessed_array(
          list.map(updates, fn(u) {
            json.preprocessed_array([encode_name(u.0), encode_val(u.1)])
          }),
        ),
      ])
    v.HoleValue(a, _reason, _expected_type) ->
      // For now, simplify Hole to just its tag and attrs
      json.preprocessed_array([
        json.string("HoleValue"),
        encode_value_attributes(a),
      ])
    v.Native(a, fqn, _info) ->
      json.preprocessed_array([
        json.string("Native"),
        encode_value_attributes(a),
        encode_fqname(fqn),
      ])
    v.External(a, name, platform) ->
      json.preprocessed_array([
        json.string("External"),
        encode_value_attributes(a),
        json.string(name),
        json.string(platform),
      ])
  }
}

pub fn encode_definition_body(
  body: v.DefinitionBody(ta, va),
  encode_type_attributes: fn(ta) -> json.Json,
  encode_value_attributes: fn(va) -> json.Json,
) -> json.Json {
  case body {
    v.ExpressionBody(input_types, output_type, val) ->
      json.preprocessed_array([
        json.string("ExpressionBody"),
        json.preprocessed_array(
          list.map(input_types, fn(it) {
            json.preprocessed_array([
              encode_name(it.0),
              encode_type(it.1, encode_type_attributes),
            ])
          }),
        ),
        encode_type(output_type, encode_type_attributes),
        encode_value(val, encode_type_attributes, encode_value_attributes),
      ])
    v.NativeBody(input_types, output_type, _info) ->
      json.preprocessed_array([
        json.string("NativeBody"),
        json.preprocessed_array(
          list.map(input_types, fn(it) {
            json.preprocessed_array([
              encode_name(it.0),
              encode_type(it.1, encode_type_attributes),
            ])
          }),
        ),
        encode_type(output_type, encode_type_attributes),
      ])
    v.ExternalBody(input_types, output_type, name, platform) ->
      json.preprocessed_array([
        json.string("ExternalBody"),
        json.preprocessed_array(
          list.map(input_types, fn(it) {
            json.preprocessed_array([
              encode_name(it.0),
              encode_type(it.1, encode_type_attributes),
            ])
          }),
        ),
        encode_type(output_type, encode_type_attributes),
        json.string(name),
        json.string(platform),
      ])
    v.IncompleteBody(input_types, output_type, _incompleteness, _partial) ->
      json.preprocessed_array([
        json.string("IncompleteBody"),
        json.preprocessed_array(
          list.map(input_types, fn(it) {
            json.preprocessed_array([
              encode_name(it.0),
              encode_type(it.1, encode_type_attributes),
            ])
          }),
        ),
        // Handling Option
        case output_type {
          Some(t) -> encode_type(t, encode_type_attributes)
          None -> json.null()
        },
      ])
  }
}

pub fn encode_value_definition(
  def: v.Definition(ta, va),
  encode_type_attributes: fn(ta) -> json.Json,
  encode_value_attributes: fn(va) -> json.Json,
) -> json.Json {
  case def {
    v.Definition(body) ->
      json.preprocessed_array([
        json.string("Definition"),
        encode_access_controlled(body, fn(b) {
          encode_definition_body(
            b,
            encode_type_attributes,
            encode_value_attributes,
          )
        }),
      ])
  }
}

pub fn encode_value_specification(
  spec: v.Specification(ta),
  encode_attributes: fn(ta) -> json.Json,
) -> json.Json {
  case spec {
    v.Specification(inputs, output) ->
      json.preprocessed_array([
        json.string("Specification"),
        json.preprocessed_array(
          list.map(inputs, fn(it) {
            json.preprocessed_array([
              encode_name(it.0),
              encode_type(it.1, encode_attributes),
            ])
          }),
        ),
        encode_type(output, encode_attributes),
      ])
  }
}

pub fn encode_module_definition(
  def: dist.ModuleDefinition(ta, va),
  encode_type_attributes: fn(ta) -> json.Json,
  encode_value_attributes: fn(va) -> json.Json,
) -> json.Json {
  json.preprocessed_array([
    json.string("ModuleDefinition"),
    encode_dict(def.types, encode_name, fn(ac) {
      encode_access_controlled(ac, fn(doc) {
        encode_documented(doc, fn(d) {
          encode_type_definition(d, encode_type_attributes)
        })
      })
    }),
    encode_dict(def.values, encode_name, fn(ac) {
      encode_access_controlled(ac, fn(doc) {
        encode_documented(doc, fn(d) {
          encode_value_definition(
            d,
            encode_type_attributes,
            encode_value_attributes,
          )
        })
      })
    }),
  ])
}

pub fn encode_package_definition(
  def: dist.PackageDefinition(ta, va),
  encode_type_attributes: fn(ta) -> json.Json,
  encode_value_attributes: fn(va) -> json.Json,
) -> json.Json {
  json.preprocessed_array([
    json.string("PackageDefinition"),
    encode_dict(def.modules, encode_name, fn(ac) {
      encode_access_controlled(ac, fn(mod_def) {
        encode_module_definition(
          mod_def,
          encode_type_attributes,
          encode_value_attributes,
        )
      })
    }),
  ])
}

pub fn encode_package_specification(
  spec: dist.PackageSpecification(ta),
  encode_attributes: fn(ta) -> json.Json,
) -> json.Json {
  json.preprocessed_array([
    json.string("PackageSpecification"),
    encode_dict(spec.modules, encode_name, fn(mod_spec) {
      encode_module_specification(mod_spec, encode_attributes)
    }),
  ])
}

pub fn encode_module_specification(
  spec: dist.ModuleSpecification(ta),
  encode_attributes: fn(ta) -> json.Json,
) -> json.Json {
  json.preprocessed_array([
    json.string("ModuleSpecification"),
    encode_dict(spec.types, encode_name, fn(doc) {
      encode_documented(doc, fn(s) {
        encode_type_specification(s, encode_attributes)
      })
    }),
    encode_dict(spec.values, encode_name, fn(doc) {
      encode_documented(doc, fn(s) {
        encode_value_specification(s, encode_attributes)
      })
    }),
  ])
}

pub fn encode_package_info(info: dist.PackageInfo) -> json.Json {
  json.preprocessed_array([
    json.string("PackageInfo"),
    encode_path(info.name),
    json.string(info.version),
  ])
}

pub fn encode_entry_point_kind(kind: dist.EntryPointKind) -> json.Json {
  case kind {
    dist.Main -> json.string("Main")
    dist.Command -> json.string("Command")
    dist.Handler -> json.string("Handler")
    dist.Job -> json.string("Job")
    dist.Policy -> json.string("Policy")
  }
}

pub fn encode_entry_point(ep: dist.EntryPoint) -> json.Json {
  json.preprocessed_array([
    json.string("EntryPoint"),
    encode_fqname(ep.target),
    encode_entry_point_kind(ep.kind),
    encode_option(ep.doc, json.string),
  ])
}

pub fn encode_distribution(
  distro: dist.Distribution(ta, va),
  encode_type_attributes: fn(ta) -> json.Json,
  encode_value_attributes: fn(va) -> json.Json,
) -> json.Json {
  case distro {
    dist.Library(lib) ->
      json.preprocessed_array([
        json.string("Library"),
        json.preprocessed_array([
          json.string("LibraryDistribution"),
          encode_package_info(lib.package_info),
          encode_package_definition(
            lib.definition,
            encode_type_attributes,
            encode_value_attributes,
          ),
          encode_dict(lib.dependencies, encode_path, fn(spec) {
            encode_package_specification(spec, encode_type_attributes)
          }),
        ]),
      ])
    dist.Specs(specs) ->
      json.preprocessed_array([
        json.string("Specs"),
        json.preprocessed_array([
          json.string("SpecsDistribution"),
          encode_package_info(specs.package_info),
          encode_package_specification(
            specs.specification,
            encode_type_attributes,
          ),
          encode_dict(specs.dependencies, encode_path, fn(spec) {
            encode_package_specification(spec, encode_type_attributes)
          }),
        ]),
      ])
    dist.Application(app) ->
      json.preprocessed_array([
        json.string("Application"),
        json.preprocessed_array([
          json.string("ApplicationDistribution"),
          encode_package_info(app.package_info),
          encode_package_definition(
            app.definition,
            encode_type_attributes,
            encode_value_attributes,
          ),
          encode_dict(app.dependencies, encode_path, fn(def) {
            encode_package_definition(
              def,
              encode_type_attributes,
              encode_value_attributes,
            )
          }),
          encode_dict(app.entry_points, encode_name, encode_entry_point),
        ]),
      ])
  }
}

// --- Decoders ---

pub fn decode_access_controlled(
  decoder: decode.Decoder(a),
) -> decode.Decoder(ac.AccessControlled(a)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "Public" -> decode.at([1], decoder) |> decode.map(ac.public)
      "Private" -> decode.at([1], decoder) |> decode.map(ac.private)
      _ -> decode.failure(unsafe_zero(), "AccessControlled")
    }
  })
}

pub fn decode_documented(
  decoder: decode.Decoder(a),
) -> decode.Decoder(doc.Documented(a)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "Documented" ->
        decode.at([1], decode.string)
        |> decode.then(fn(doc_str) {
          decode.at([2], decoder)
          |> decode.map(fn(val) { doc.Documented(doc_str, val) })
        })
      _ -> decode.failure(unsafe_zero(), "Documented")
    }
  })
}

pub fn decode_name() -> decode.Decoder(name.Name) {
  decode.list(decode.string) |> decode.map(name.from_list)
}

pub fn decode_path() -> decode.Decoder(path.Path) {
  decode.list(decode_name()) |> decode.map(path.from_list)
}

pub fn decode_qname() -> decode.Decoder(qname.QName) {
  decode.at([0], decode_path())
  |> decode.then(fn(p) {
    decode.at([1], decode_name())
    |> decode.then(fn(n) { decode.success(qname.from_tuple(#(p, n))) })
  })
}

pub fn decode_fqname() -> decode.Decoder(fqname.FQName) {
  decode.at([0], decode_path())
  |> decode.then(fn(p) {
    decode.at([1], decode_path())
    |> decode.then(fn(m) {
      decode.at([2], decode_name())
      |> decode.then(fn(n) { decode.success(fqname.from_tuple(#(p, m, n))) })
    })
  })
}

/// Decode a JSON value into a Morphir `Literal`.
pub fn decode_literal() -> decode.Decoder(literal.Literal) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "BoolLiteral" ->
        decode.at([1], decode.bool) |> decode.map(literal.BoolLiteral)
      "CharLiteral" ->
        decode.at([1], decode.string) |> decode.map(literal.CharLiteral)
      "StringLiteral" ->
        decode.at([1], decode.string) |> decode.map(literal.StringLiteral)
      "WholeNumberLiteral" ->
        decode.at([1], decode.int) |> decode.map(literal.WholeNumberLiteral)
      "FloatLiteral" ->
        decode.at([1], decode.float) |> decode.map(literal.FloatLiteral)
      "DecimalLiteral" ->
        decode.at([1], decode.string) |> decode.map(literal.DecimalLiteral)
      _ -> decode.failure(literal.BoolLiteral(False), "Literal")
    }
  })
}

/// Decode a JSON value into a Morphir `Type`.
pub fn decode_type(
  decode_attributes: decode.Decoder(a),
) -> decode.Decoder(t.Type(a)) {
  decode.recursive(fn() {
    decode.at([0], decode.string)
    |> decode.then(fn(tag) {
      case tag {
        "Variable" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_name())
            |> decode.map(fn(name) { t.Variable(attr, name) })
          })
        "Reference" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_fqname())
            |> decode.then(fn(fqn) {
              decode.at([3], decode.list(decode_type(decode_attributes)))
              |> decode.map(fn(args) { t.Reference(attr, fqn, args) })
            })
          })
        "Tuple" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode.list(decode_type(decode_attributes)))
            |> decode.map(fn(elems) { t.Tuple(attr, elems) })
          })
        "Record" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at(
              [2],
              decode.list(
                decode.at([0], decode_name())
                |> decode.then(fn(name) {
                  decode.at([1], decode_type(decode_attributes))
                  |> decode.map(fn(tpe) { t.Field(name, tpe) })
                }),
              ),
            )
            |> decode.map(fn(fields) { t.Record(attr, fields) })
          })
        "ExtensibleRecord" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_name())
            |> decode.then(fn(name) {
              decode.at(
                [3],
                decode.list(
                  decode.at([0], decode_name())
                  |> decode.then(fn(fname) {
                    decode.at([1], decode_type(decode_attributes))
                    |> decode.map(fn(tpe) { t.Field(fname, tpe) })
                  }),
                ),
              )
              |> decode.map(fn(fields) {
                t.ExtensibleRecord(attr, name, fields)
              })
            })
          })
        "Function" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_type(decode_attributes))
            |> decode.then(fn(arg) {
              decode.at([3], decode_type(decode_attributes))
              |> decode.map(fn(ret) { t.Function(attr, arg, ret) })
            })
          })
        "Unit" -> decode.at([1], decode_attributes) |> decode.map(t.Unit)
        _ -> decode.failure(unsafe_zero(), "Type")
      }
    })
  })
}

pub fn decode_type_constructor(
  decode_attributes: decode.Decoder(a),
) -> decode.Decoder(t.Constructor(a)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "Constructor" ->
        decode.at([1], decode_name())
        |> decode.then(fn(name) {
          decode.at(
            [2],
            decode.list(
              decode.at([0], decode_name())
              |> decode.then(fn(arg_name) {
                decode.at([1], decode_type(decode_attributes))
                |> decode.map(fn(arg_type) { #(arg_name, arg_type) })
              }),
            ),
          )
          |> decode.map(fn(args) { t.Constructor(name, args) })
        })
      _ ->
        decode.failure(t.Constructor(name.from_string(""), []), "Constructor")
    }
  })
}

pub fn decode_type_definition(
  decode_attributes: decode.Decoder(a),
) -> decode.Decoder(t.Definition(a)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "CustomTypeDefinition" ->
        decode.at([1], decode.list(decode_name()))
        |> decode.then(fn(params) {
          decode.at(
            [2],
            decode_access_controlled(
              decode.list(decode_type_constructor(decode_attributes)),
            ),
          )
          |> decode.map(fn(ctors) { t.CustomTypeDefinition(params, ctors) })
        })
      "TypeAliasDefinition" ->
        decode.at([1], decode.list(decode_name()))
        |> decode.then(fn(params) {
          decode.at([2], decode_type(decode_attributes))
          |> decode.map(fn(tpe) { t.TypeAliasDefinition(params, tpe) })
        })
      // "IncompleteTypeDefinition"
      _ -> decode.failure(unsafe_zero(), "TypeDefinition")
    }
  })
}

pub fn decode_type_specification(
  decode_attributes: decode.Decoder(a),
) -> decode.Decoder(t.Specification(a)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "TypeAliasSpecification" ->
        decode.at([1], decode.list(decode_name()))
        |> decode.then(fn(params) {
          decode.at([2], decode_type(decode_attributes))
          |> decode.map(fn(tpe) { t.TypeAliasSpecification(params, tpe) })
        })
      "OpaqueTypeSpecification" ->
        decode.at([1], decode.list(decode_name()))
        |> decode.map(t.OpaqueTypeSpecification)
      "CustomTypeSpecification" ->
        decode.at([1], decode.list(decode_name()))
        |> decode.then(fn(params) {
          decode.at(
            [2],
            decode.list(decode_type_constructor(decode_attributes)),
          )
          |> decode.map(fn(ctors) { t.CustomTypeSpecification(params, ctors) })
        })
      "DerivedTypeSpecification" ->
        decode.at([1], decode.list(decode_name()))
        |> decode.then(fn(params) {
          decode.at(
            [2],
            decode.at([0], decode.string)
              // Check tag
              |> decode.then(fn(_) {
                decode.at([1], decode_type(decode_attributes))
                |> decode.then(fn(base) {
                  decode.at([2], decode_fqname())
                  |> decode.then(fn(from) {
                    decode.at([3], decode_fqname())
                    |> decode.map(fn(to) {
                      t.DerivedTypeSpecificationDetails(base, from, to)
                    })
                  })
                })
              }),
          )
          |> decode.map(fn(details) {
            t.DerivedTypeSpecification(params, details)
          })
        })
      _ -> decode.failure(t.OpaqueTypeSpecification([]), "TypeSpecification")
    }
  })
}

/// Decode a JSON value into a Morphir `Pattern`.
pub fn decode_pattern(
  decode_attributes: decode.Decoder(a),
) -> decode.Decoder(v.Pattern(a)) {
  decode.recursive(fn() {
    decode.at([0], decode.string)
    |> decode.then(fn(tag) {
      case tag {
        "WildcardPattern" ->
          decode.at([1], decode_attributes) |> decode.map(v.WildcardPattern)
        "AsPattern" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_pattern(decode_attributes))
            |> decode.then(fn(pat) {
              decode.at([3], decode_name())
              |> decode.map(fn(name) { v.AsPattern(attr, pat, name) })
            })
          })
        "TuplePattern" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode.list(decode_pattern(decode_attributes)))
            |> decode.map(fn(patterns) { v.TuplePattern(attr, patterns) })
          })
        "ConstructorPattern" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_fqname())
            |> decode.then(fn(fqn) {
              decode.at([3], decode.list(decode_pattern(decode_attributes)))
              |> decode.map(fn(args) { v.ConstructorPattern(attr, fqn, args) })
            })
          })
        "EmptyListPattern" ->
          decode.at([1], decode_attributes) |> decode.map(v.EmptyListPattern)
        "HeadTailPattern" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_pattern(decode_attributes))
            |> decode.then(fn(head) {
              decode.at([3], decode_pattern(decode_attributes))
              |> decode.map(fn(tail) { v.HeadTailPattern(attr, head, tail) })
            })
          })
        "LiteralPattern" ->
          decode.at([1], decode_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_literal())
            |> decode.map(fn(lit) { v.LiteralPattern(attr, lit) })
          })
        "UnitPattern" ->
          decode.at([1], decode_attributes) |> decode.map(v.UnitPattern)
        _ -> decode.failure(unsafe_zero(), "Pattern")
      }
    })
  })
}

/// Decode a JSON value into a Morphir `Value`.
pub fn decode_value(
  decode_type_attributes: decode.Decoder(ta),
  decode_value_attributes: decode.Decoder(va),
) -> decode.Decoder(v.Value(ta, va)) {
  decode.recursive(fn() {
    let decode_val =
      decode_value(decode_type_attributes, decode_value_attributes)
    let decode_pat = decode_pattern(decode_value_attributes)
    let decode_def =
      decode_definition_body(decode_type_attributes, decode_value_attributes)

    decode.at([0], decode.string)
    |> decode.then(fn(tag) {
      case tag {
        "Literal" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_literal())
            |> decode.map(fn(lit) { v.Literal(attr, lit) })
          })
        "Constructor" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_fqname())
            |> decode.map(fn(fqn) { v.Constructor(attr, fqn) })
          })
        "Tuple" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode.list(decode_val))
            |> decode.map(fn(elems) { v.Tuple(attr, elems) })
          })
        "List" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode.list(decode_val))
            |> decode.map(fn(elems) { v.List(attr, elems) })
          })
        "Record" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at(
              [2],
              decode.list(
                decode.at([0], decode_name())
                |> decode.then(fn(field_name) {
                  decode.at([1], decode_val)
                  |> decode.map(fn(val) { #(field_name, val) })
                }),
              ),
            )
            |> decode.map(fn(fields) { v.Record(attr, fields) })
          })
        "Unit" -> decode.at([1], decode_value_attributes) |> decode.map(v.Unit)
        "Variable" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_name())
            |> decode.map(fn(name) { v.Variable(attr, name) })
          })
        "Reference" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_fqname())
            |> decode.map(fn(fqn) { v.Reference(attr, fqn) })
          })
        "Field" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_val)
            |> decode.then(fn(record) {
              decode.at([3], decode_name())
              |> decode.map(fn(name) { v.Field(attr, record, name) })
            })
          })
        "FieldFunction" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_name())
            |> decode.map(fn(name) { v.FieldFunction(attr, name) })
          })
        "Apply" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_val)
            |> decode.then(fn(func) {
              decode.at([3], decode_val)
              |> decode.map(fn(arg) { v.Apply(attr, func, arg) })
            })
          })
        "Lambda" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_pat)
            |> decode.then(fn(pat) {
              decode.at([3], decode_val)
              |> decode.map(fn(body) { v.Lambda(attr, pat, body) })
            })
          })
        "LetDefinition" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_name())
            |> decode.then(fn(name) {
              decode.at([3], decode_def)
              |> decode.then(fn(def) {
                decode.at([4], decode_val)
                |> decode.map(fn(in_val) {
                  v.LetDefinition(attr, name, def, in_val)
                })
              })
            })
          })
        "LetRecursion" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at(
              [2],
              decode.list(
                decode.at([0], decode_name())
                |> decode.then(fn(name) {
                  decode.at([1], decode_def)
                  |> decode.map(fn(def) { #(name, def) })
                }),
              ),
            )
            |> decode.then(fn(defs) {
              decode.at([3], decode_val)
              |> decode.map(fn(in_val) { v.LetRecursion(attr, defs, in_val) })
            })
          })
        "Destructure" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_pat)
            |> decode.then(fn(pat) {
              decode.at([3], decode_val)
              |> decode.then(fn(val) {
                decode.at([4], decode_val)
                |> decode.map(fn(in_val) {
                  v.Destructure(attr, pat, val, in_val)
                })
              })
            })
          })
        "IfThenElse" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_val)
            |> decode.then(fn(cond) {
              decode.at([3], decode_val)
              |> decode.then(fn(then_br) {
                decode.at([4], decode_val)
                |> decode.map(fn(else_br) {
                  v.IfThenElse(attr, cond, then_br, else_br)
                })
              })
            })
          })
        "PatternMatch" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_val)
            |> decode.then(fn(subject) {
              decode.at(
                [3],
                decode.list(
                  decode.at([0], decode_pat)
                  |> decode.then(fn(case_pat) {
                    decode.at([1], decode_val)
                    |> decode.map(fn(case_val) { #(case_pat, case_val) })
                  }),
                ),
              )
              |> decode.map(fn(cases) { v.PatternMatch(attr, subject, cases) })
            })
          })
        "UpdateRecord" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_val)
            |> decode.then(fn(rec_val) {
              decode.at(
                [3],
                decode.list(
                  decode.at([0], decode_name())
                  |> decode.then(fn(fname) {
                    decode.at([1], decode_val)
                    |> decode.map(fn(uval) { #(fname, uval) })
                  }),
                ),
              )
              |> decode.map(fn(updates) {
                v.UpdateRecord(attr, rec_val, updates)
              })
            })
          })
        "HoleValue" ->
          decode.at([1], decode_value_attributes)
          |> decode.map(fn(attr) {
            v.HoleValue(attr, v.TypeMismatch("Unknown", "Unknown"), None)
          })
        "Native" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode_fqname())
            |> decode.map(fn(fqn) {
              v.Native(attr, fqn, v.NativeInfo(v.Arithmetic, None))
            })
          })
        "External" ->
          decode.at([1], decode_value_attributes)
          |> decode.then(fn(attr) {
            decode.at([2], decode.string)
            |> decode.then(fn(name) {
              decode.at([3], decode.string)
              |> decode.map(fn(platform) { v.External(attr, name, platform) })
            })
          })

        _ -> decode.failure(unsafe_zero(), "Value")
      }
    })
  })
}

pub fn decode_definition_body(
  decode_type_attributes: decode.Decoder(ta),
  decode_value_attributes: decode.Decoder(va),
) -> decode.Decoder(v.DefinitionBody(ta, va)) {
  decode.recursive(fn() {
    decode.at([0], decode.string)
    |> decode.then(fn(tag) {
      case tag {
        "ExpressionBody" ->
          decode.at(
            [1],
            decode.list(
              decode.at([0], decode_name())
              |> decode.then(fn(arg_name) {
                decode.at([1], decode_type(decode_type_attributes))
                |> decode.map(fn(arg_type) { #(arg_name, arg_type) })
              }),
            ),
          )
          |> decode.then(fn(args) {
            decode.at([2], decode_type(decode_type_attributes))
            |> decode.then(fn(ret_type) {
              decode.at(
                [3],
                decode_value(decode_type_attributes, decode_value_attributes),
              )
              |> decode.map(fn(body) { v.ExpressionBody(args, ret_type, body) })
            })
          })
        "NativeBody" ->
          decode.at(
            [1],
            decode.list(
              decode.at([0], decode_name())
              |> decode.then(fn(arg_name) {
                decode.at([1], decode_type(decode_type_attributes))
                |> decode.map(fn(arg_type) { #(arg_name, arg_type) })
              }),
            ),
          )
          |> decode.then(fn(args) {
            decode.at([2], decode_type(decode_type_attributes))
            |> decode.map(fn(ret_type) {
              v.NativeBody(args, ret_type, v.NativeInfo(v.Arithmetic, None))
            })
          })
        "ExternalBody" ->
          decode.at(
            [1],
            decode.list(
              decode.at([0], decode_name())
              |> decode.then(fn(arg_name) {
                decode.at([1], decode_type(decode_type_attributes))
                |> decode.map(fn(arg_type) { #(arg_name, arg_type) })
              }),
            ),
          )
          |> decode.then(fn(args) {
            decode.at([2], decode_type(decode_type_attributes))
            |> decode.then(fn(ret_type) {
              decode.at([3], decode.string)
              |> decode.then(fn(name) {
                decode.at([4], decode.string)
                |> decode.map(fn(platform) {
                  v.ExternalBody(args, ret_type, name, platform)
                })
              })
            })
          })
        "IncompleteBody" ->
          decode.at(
            [1],
            decode.list(
              decode.at([0], decode_name())
              |> decode.then(fn(arg_name) {
                decode.at([1], decode_type(decode_type_attributes))
                |> decode.map(fn(arg_type) { #(arg_name, arg_type) })
              }),
            ),
          )
          |> decode.then(fn(args) {
            decode.at([2], decode.optional(decode_type(decode_type_attributes)))
            |> decode.map(fn(ret_type) {
              v.IncompleteBody(
                args,
                ret_type,
                v.Hole(v.TypeMismatch("Unknown", "Unknown")),
                None,
              )
            })
          })
        _ -> decode.failure(unsafe_zero(), "DefinitionBody")
      }
    })
  })
}

pub fn decode_value_definition(
  decode_type_attributes: decode.Decoder(ta),
  decode_value_attributes: decode.Decoder(va),
) -> decode.Decoder(v.Definition(ta, va)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "Definition" ->
        decode.at(
          [1],
          decode_access_controlled(decode_definition_body(
            decode_type_attributes,
            decode_value_attributes,
          )),
        )
        |> decode.map(v.Definition)
      _ -> decode.failure(unsafe_zero(), "Definition")
    }
  })
}

pub fn decode_value_specification(
  decode_attributes: decode.Decoder(ta),
) -> decode.Decoder(v.Specification(ta)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "Specification" ->
        decode.at(
          [1],
          decode.list(
            decode.at([0], decode_name())
            |> decode.then(fn(arg_name) {
              decode.at([1], decode_type(decode_attributes))
              |> decode.map(fn(arg_type) { #(arg_name, arg_type) })
            }),
          ),
        )
        |> decode.then(fn(inputs) {
          decode.at([2], decode_type(decode_attributes))
          |> decode.map(fn(output) { v.Specification(inputs, output) })
        })
      _ -> decode.failure(unsafe_zero(), "Specification")
    }
  })
}

pub fn decode_module_definition(
  decode_type_attributes: decode.Decoder(ta),
  decode_value_attributes: decode.Decoder(va),
) -> decode.Decoder(dist.ModuleDefinition(ta, va)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "ModuleDefinition" ->
        decode.at(
          [1],
          decode.list(
            decode.at([0], decode_name())
            |> decode.then(fn(key) {
              decode.at(
                [1],
                decode_access_controlled(
                  decode_documented(decode_type_definition(
                    decode_type_attributes,
                  )),
                ),
              )
              |> decode.map(fn(val) { #(key, val) })
            }),
          ),
        )
        |> decode.then(fn(types_list) {
          decode.at(
            [2],
            decode.list(
              decode.at([0], decode_name())
              |> decode.then(fn(key) {
                decode.at(
                  [1],
                  decode_access_controlled(
                    decode_documented(decode_value_definition(
                      decode_type_attributes,
                      decode_value_attributes,
                    )),
                  ),
                )
                |> decode.map(fn(val) { #(key, val) })
              }),
            ),
          )
          |> decode.map(fn(values_list) {
            dist.ModuleDefinition(
              dict.from_list(types_list),
              dict.from_list(values_list),
            )
          })
        })
      _ ->
        decode.failure(
          dist.ModuleDefinition(dict.new(), dict.new()),
          "ModuleDefinition",
        )
    }
  })
}

pub fn decode_module_specification(
  decode_attributes: decode.Decoder(ta),
) -> decode.Decoder(dist.ModuleSpecification(ta)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "ModuleSpecification" ->
        decode.at(
          [1],
          decode.list(
            decode.at([0], decode_name())
            |> decode.then(fn(key) {
              decode.at(
                [1],
                decode_documented(decode_type_specification(decode_attributes)),
              )
              |> decode.map(fn(val) { #(key, val) })
            }),
          ),
        )
        |> decode.then(fn(types_list) {
          decode.at(
            [2],
            decode.list(
              decode.at([0], decode_name())
              |> decode.then(fn(key) {
                decode.at(
                  [1],
                  decode_documented(decode_value_specification(
                    decode_attributes,
                  )),
                )
                |> decode.map(fn(val) { #(key, val) })
              }),
            ),
          )
          |> decode.map(fn(values_list) {
            dist.ModuleSpecification(
              dict.from_list(types_list),
              dict.from_list(values_list),
            )
          })
        })
      _ ->
        decode.failure(
          dist.ModuleSpecification(dict.new(), dict.new()),
          "ModuleSpecification",
        )
    }
  })
}

pub fn decode_package_definition(
  decode_type_attributes: decode.Decoder(ta),
  decode_value_attributes: decode.Decoder(va),
) -> decode.Decoder(dist.PackageDefinition(ta, va)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "PackageDefinition" ->
        decode.at(
          [1],
          decode.list(
            decode.at([0], decode_name())
            |> decode.then(fn(key) {
              decode.at(
                [1],
                decode_access_controlled(decode_module_definition(
                  decode_type_attributes,
                  decode_value_attributes,
                )),
              )
              |> decode.map(fn(val) { #(key, val) })
            }),
          ),
        )
        |> decode.map(fn(modules_list) {
          dist.PackageDefinition(dict.from_list(modules_list))
        })
      _ ->
        decode.failure(dist.PackageDefinition(dict.new()), "PackageDefinition")
    }
  })
}

pub fn decode_package_specification(
  decode_attributes: decode.Decoder(ta),
) -> decode.Decoder(dist.PackageSpecification(ta)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "PackageSpecification" ->
        decode.at(
          [1],
          decode.list(
            decode.at([0], decode_name())
            |> decode.then(fn(key) {
              decode.at([1], decode_module_specification(decode_attributes))
              |> decode.map(fn(val) { #(key, val) })
            }),
          ),
        )
        |> decode.map(fn(modules_list) {
          dist.PackageSpecification(dict.from_list(modules_list))
        })
      _ ->
        decode.failure(
          dist.PackageSpecification(dict.new()),
          "PackageSpecification",
        )
    }
  })
}

pub fn decode_package_info() -> decode.Decoder(dist.PackageInfo) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "PackageInfo" ->
        decode.at([1], decode_path())
        |> decode.then(fn(name) {
          decode.at([2], decode.string)
          |> decode.map(fn(version) { dist.PackageInfo(name, version) })
        })
      _ ->
        decode.failure(dist.PackageInfo(path.from_list([]), ""), "PackageInfo")
    }
  })
}

pub fn decode_entry_point_kind() -> decode.Decoder(dist.EntryPointKind) {
  decode.string
  |> decode.then(fn(str) {
    case str {
      "Main" -> decode.success(dist.Main)
      "Command" -> decode.success(dist.Command)
      "Handler" -> decode.success(dist.Handler)
      "Job" -> decode.success(dist.Job)
      "Policy" -> decode.success(dist.Policy)
      _ -> decode.failure(dist.Main, "EntryPointKind")
    }
  })
}

pub fn decode_entry_point() -> decode.Decoder(dist.EntryPoint) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "EntryPoint" ->
        decode.at([1], decode_fqname())
        |> decode.then(fn(target) {
          decode.at([2], decode_entry_point_kind())
          |> decode.then(fn(kind) {
            decode.at([3], decode.optional(decode.string))
            |> decode.map(fn(doc) { dist.EntryPoint(target, kind, doc) })
          })
        })
      _ ->
        decode.failure(
          dist.EntryPoint(
            fqname.from_tuple(#(
              path.from_list([]),
              path.from_list([]),
              name.from_string(""),
            )),
            dist.Main,
            None,
          ),
          "EntryPoint",
        )
    }
  })
}

pub fn decode_distribution(
  decode_type_attributes: decode.Decoder(ta),
  decode_value_attributes: decode.Decoder(va),
) -> decode.Decoder(dist.Distribution(ta, va)) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "Library" ->
        decode.at(
          [1],
          decode.at([0], decode.string)
            |> decode.then(fn(_) {
              decode.at([1], decode_package_info())
              |> decode.then(fn(info) {
                decode.at(
                  [2],
                  decode_package_definition(
                    decode_type_attributes,
                    decode_value_attributes,
                  ),
                )
                |> decode.then(fn(def) {
                  decode.at(
                    [3],
                    decode_dict_list(
                      decode_path(),
                      decode_package_specification(decode_type_attributes),
                    ),
                  )
                  |> decode.map(fn(deps) {
                    dist.LibraryDistribution(info, def, deps)
                  })
                })
              })
            }),
        )
        |> decode.map(dist.Library)
      "Specs" ->
        decode.at(
          [1],
          decode.at([0], decode.string)
            |> decode.then(fn(_) {
              decode.at([1], decode_package_info())
              |> decode.then(fn(info) {
                decode.at(
                  [2],
                  decode_package_specification(decode_type_attributes),
                )
                |> decode.then(fn(spec) {
                  decode.at(
                    [3],
                    decode_dict_list(
                      decode_path(),
                      decode_package_specification(decode_type_attributes),
                    ),
                  )
                  |> decode.map(fn(deps) {
                    dist.SpecsDistribution(info, spec, deps)
                  })
                })
              })
            }),
        )
        |> decode.map(dist.Specs)
      "Application" ->
        decode.at(
          [1],
          decode.at([0], decode.string)
            |> decode.then(fn(_) {
              decode.at([1], decode_package_info())
              |> decode.then(fn(info) {
                decode.at(
                  [2],
                  decode_package_definition(
                    decode_type_attributes,
                    decode_value_attributes,
                  ),
                )
                |> decode.then(fn(def) {
                  decode.at(
                    [3],
                    decode_dict_list(
                      decode_path(),
                      decode_package_definition(
                        decode_type_attributes,
                        decode_value_attributes,
                      ),
                    ),
                  )
                  |> decode.then(fn(deps) {
                    decode.at(
                      [4],
                      decode_dict_list(decode_name(), decode_entry_point()),
                    )
                    |> decode.map(fn(eps) {
                      dist.ApplicationDistribution(info, def, deps, eps)
                    })
                  })
                })
              })
            }),
        )
        |> decode.map(dist.Application)
      _ ->
        decode.failure(
          dist.Library(dist.LibraryDistribution(
            dist.PackageInfo(path.from_list([]), ""),
            dist.PackageDefinition(dict.new()),
            dict.new(),
          )),
          "Distribution",
        )
    }
  })
}

// Helper to decode list of pairs to dict
pub fn decode_dict_list(
  key_decoder: decode.Decoder(k),
  val_decoder: decode.Decoder(v),
) -> decode.Decoder(dict.Dict(k, v)) {
  decode.list(
    decode.at([0], key_decoder)
    |> decode.then(fn(key) {
      decode.at([1], val_decoder) |> decode.map(fn(val) { #(key, val) })
    }),
  )
  |> decode.map(dict.from_list)
}

pub fn encode_distribution_mode(mode: dist.DistributionMode) -> json.Json {
  case mode {
    dist.ClassicMode -> json.string("ClassicMode")
    dist.VfsMode -> json.string("VfsMode")
  }
}

pub fn decode_distribution_mode() -> decode.Decoder(dist.DistributionMode) {
  decode.string
  |> decode.then(fn(str) {
    case str {
      "ClassicMode" -> decode.success(dist.ClassicMode)
      "VfsMode" -> decode.success(dist.VfsMode)
      _ -> decode.failure(dist.VfsMode, "DistributionMode")
    }
  })
}

pub fn encode_vfs_manifest(manifest: dist.VfsManifest) -> json.Json {
  json.preprocessed_array([
    json.string("VfsManifest"),
    json.string(manifest.format_version),
    encode_distribution_mode(manifest.layout),
    encode_path(manifest.package_name),
    json.string(manifest.created),
  ])
}

pub fn decode_vfs_manifest() -> decode.Decoder(dist.VfsManifest) {
  decode.at([0], decode.string)
  |> decode.then(fn(tag) {
    case tag {
      "VfsManifest" ->
        decode.at([1], decode.string)
        |> decode.then(fn(ver) {
          decode.at([2], decode_distribution_mode())
          |> decode.then(fn(layout) {
            decode.at([3], decode_path())
            |> decode.then(fn(pkg) {
              decode.at([4], decode.string)
              |> decode.map(fn(created) {
                dist.VfsManifest(ver, layout, pkg, created)
              })
            })
          })
        })
      _ ->
        decode.failure(
          dist.VfsManifest("", dist.VfsMode, path.from_list([]), ""),
          "VfsManifest",
        )
    }
  })
}
