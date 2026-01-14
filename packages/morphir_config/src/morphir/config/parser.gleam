////
//// Parser for morphir.toml configuration files.
////

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import morphir_config.{
  type CodegenSection, type IrSection, type MorphirConfig, type MorphirSection,
  type ProjectSection, type WorkspaceSection, CodegenSection, IrSection,
  MorphirConfig, MorphirSection, ProjectSection, WorkspaceSection,
}
import simplifile
import tom

/// Parse a morphir.toml file from the given path
pub fn parse_file(path: String) -> Result(MorphirConfig, String) {
  use content <- result.try(
    simplifile.read(path)
    |> result.map_error(fn(err) {
      "Failed to read file: " <> simplifile.describe_error(err)
    }),
  )
  parse_string(content)
}

/// Parse morphir.toml content from a string
pub fn parse_string(content: String) -> Result(MorphirConfig, String) {
  use toml_dict <- result.try(
    tom.parse(content)
    |> result.map_error(fn(_err) { "TOML parse error" }),
  )

  // Parse each section - all are optional per spec
  let morphir = parse_morphir_section(toml_dict)
  let workspace = parse_workspace_section(toml_dict)
  let project = parse_project_section(toml_dict)
  let ir = parse_ir_section(toml_dict)
  let codegen = parse_codegen_section(toml_dict)

  Ok(MorphirConfig(
    morphir: morphir,
    workspace: workspace,
    project: project,
    ir: ir,
    codegen: codegen,
    cache: None,
    logging: None,
    ui: None,
  ))
}

fn parse_morphir_section(
  toml: Dict(String, tom.Toml),
) -> Option(MorphirSection) {
  case dict.get(toml, "morphir") {
    Ok(tom.InlineTable(section)) -> {
      let version = get_string(section, "version")
      Some(MorphirSection(version: version))
    }
    _ -> None
  }
}

fn parse_workspace_section(
  toml: Dict(String, tom.Toml),
) -> Option(WorkspaceSection) {
  case dict.get(toml, "workspace") {
    Ok(tom.InlineTable(section)) -> {
      let root = get_string(section, "root")
      let output_dir = get_string(section, "output_dir")
      let members = get_string_array(section, "members")
      let exclude = get_string_array(section, "exclude")
      let default_member = get_string(section, "default_member")

      Some(WorkspaceSection(
        root: root,
        output_dir: output_dir,
        members: members,
        exclude: exclude,
        default_member: default_member,
      ))
    }
    _ -> None
  }
}

fn parse_project_section(
  toml: Dict(String, tom.Toml),
) -> Option(ProjectSection) {
  case dict.get(toml, "project") {
    Ok(tom.InlineTable(section)) -> {
      // Name is required for project section
      case get_string(section, "name") {
        Some(name) -> {
          let version = get_string(section, "version")
          let source_directory = get_string(section, "source_directory")
          let exposed_modules = get_string_array(section, "exposed_modules")
          let module_prefix = get_string(section, "module_prefix")

          Some(ProjectSection(
            name: name,
            version: version,
            source_directory: source_directory,
            exposed_modules: exposed_modules,
            module_prefix: module_prefix,
          ))
        }
        None -> None
      }
    }
    _ -> None
  }
}

fn parse_ir_section(toml: Dict(String, tom.Toml)) -> Option(IrSection) {
  case dict.get(toml, "ir") {
    Ok(tom.InlineTable(section)) -> {
      let format_version = get_int(section, "format_version")
      let strict_mode = get_bool(section, "strict_mode")

      Some(IrSection(format_version: format_version, strict_mode: strict_mode))
    }
    _ -> None
  }
}

fn parse_codegen_section(
  toml: Dict(String, tom.Toml),
) -> Option(CodegenSection) {
  case dict.get(toml, "codegen") {
    Ok(tom.InlineTable(section)) -> {
      let targets = get_string_array(section, "targets")
      let template_dir = get_string(section, "template_dir")
      let output_format = get_string(section, "output_format")

      Some(CodegenSection(
        targets: targets,
        template_dir: template_dir,
        output_format: output_format,
      ))
    }
    _ -> None
  }
}

// Helper functions to extract typed values from TOML

fn get_string(dict: Dict(String, tom.Toml), key: String) -> Option(String) {
  case dict.get(dict, key) {
    Ok(tom.String(s)) -> Some(s)
    _ -> None
  }
}

fn get_int(dict: Dict(String, tom.Toml), key: String) -> Option(Int) {
  case dict.get(dict, key) {
    Ok(tom.Int(i)) -> Some(i)
    _ -> None
  }
}

fn get_bool(dict: Dict(String, tom.Toml), key: String) -> Option(Bool) {
  case dict.get(dict, key) {
    Ok(tom.Bool(b)) -> Some(b)
    _ -> None
  }
}

fn get_string_array(
  dict: Dict(String, tom.Toml),
  key: String,
) -> Option(List(String)) {
  case dict.get(dict, key) {
    Ok(tom.Array(arr)) -> {
      let strings =
        list.filter_map(arr, fn(item) {
          case item {
            tom.String(s) -> Ok(s)
            _ -> Error(Nil)
          }
        })
      case strings {
        [] -> None
        _ -> Some(strings)
      }
    }
    _ -> None
  }
}
