//// Name representation for the Morphir IR.
////
//// A Name is made up of words that are used to identify types, values, and other
//// named elements in the IR. The name is convention-agnostic and can be converted
//// to various naming conventions (camelCase, snake_case, TitleCase, etc.).

import gleam/list
import gleam/string

/// A Name is a list of words represented as lowercase strings.
/// Names can be converted to various naming conventions.
pub type Name =
  List(String)

/// Create a Name from a list of strings.
/// Each string is converted to lowercase.
pub fn from_list(words: List(String)) -> Name {
  list.map(words, string.lowercase)
}

/// Convert a Name back to a list of strings.
pub fn to_list(name: Name) -> List(String) {
  name
}

/// Parse a string into a Name by splitting on word boundaries.
/// Supports camelCase, PascalCase, snake_case, and kebab-case.
pub fn from_string(str: String) -> Name {
  // Split on underscores, hyphens, and camelCase boundaries
  str
  |> string.to_graphemes
  |> split_on_boundaries([])
  |> list.filter(fn(s) { s != "" })
  |> list.map(string.lowercase)
}

fn split_on_boundaries(
  graphemes: List(String),
  current_word: List(String),
) -> List(String) {
  case graphemes {
    [] -> {
      case current_word {
        [] -> []
        _ -> [string.concat(list.reverse(current_word))]
      }
    }
    [char, ..rest] -> {
      case is_separator(char) {
        True -> {
          case current_word {
            [] -> split_on_boundaries(rest, [])
            _ -> [
              string.concat(list.reverse(current_word)),
              ..split_on_boundaries(rest, [])
            ]
          }
        }
        False -> {
          case is_uppercase(char), current_word {
            True, [] -> split_on_boundaries(rest, [string.lowercase(char)])
            True, _ -> [
              string.concat(list.reverse(current_word)),
              ..split_on_boundaries(rest, [string.lowercase(char)])
            ]
            False, _ -> split_on_boundaries(rest, [char, ..current_word])
          }
        }
      }
    }
  }
}

fn is_separator(char: String) -> Bool {
  char == "_" || char == "-" || char == " " || char == "."
}

fn is_uppercase(char: String) -> Bool {
  let lower = string.lowercase(char)
  lower != char && is_letter(char)
}

fn is_letter(char: String) -> Bool {
  let codepoint = case string.to_utf_codepoints(char) {
    [cp] -> string.utf_codepoint_to_int(cp)
    _ -> 0
  }
  // A-Z: 65-90, a-z: 97-122
  { codepoint >= 65 && codepoint <= 90 }
  || { codepoint >= 97 && codepoint <= 122 }
}

/// Convert a Name to TitleCase (PascalCase).
/// Example: ["foo", "bar"] -> "FooBar"
pub fn to_title_case(name: Name) -> String {
  name
  |> list.map(capitalize)
  |> string.concat
}

/// Convert a Name to camelCase.
/// Example: ["foo", "bar"] -> "fooBar"
pub fn to_camel_case(name: Name) -> String {
  case name {
    [] -> ""
    [first, ..rest] -> {
      let tail = list.map(rest, capitalize)
      string.concat([first, ..tail])
    }
  }
}

/// Convert a Name to snake_case.
/// Example: ["foo", "bar"] -> "foo_bar"
pub fn to_snake_case(name: Name) -> String {
  string.join(name, "_")
}

/// Convert a Name to kebab-case.
/// Example: ["foo", "bar"] -> "foo-bar"
pub fn to_kebab_case(name: Name) -> String {
  string.join(name, "-")
}

/// Capitalize the first letter of a string.
fn capitalize(str: String) -> String {
  case string.pop_grapheme(str) {
    Ok(#(first, rest)) -> string.concat([string.uppercase(first), rest])
    Error(_) -> str
  }
}

/// Convert a Name to human-readable words.
/// Example: ["foo", "bar"] -> ["foo", "bar"]
pub fn to_human_words(name: Name) -> List(String) {
  name
}
