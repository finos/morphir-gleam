# AGENTS.md

AI coding assistants (Claude, Copilot, Cursor, etc.) should follow this guidance when working on the morphir-gleam repository.

## Project Overview

**morphir-gleam** is a Gleam implementation of the [Morphir](https://morphir.finos.org) tooling ecosystem. Morphir captures business logic as data using a technology-agnostic intermediate representation (IR), enabling code generation, documentation, and analysis across platforms.

### Related Implementations

When implementing features, reference these existing Morphir implementations for consistency:

- **[finos/morphir-elm](https://github.com/finos/morphir-elm)** - Reference implementation in Elm (primary source for IR types)
- **[finos/morphir](https://github.com/finos/morphir)** - Next-generation tooling in Go
- **[finos/morphir-jvm](https://github.com/finos/morphir-jvm)** - JVM/Scala implementation
- **[finos/morphir-dotnet](https://github.com/finos/morphir-dotnet)** - .NET implementation

### Why Gleam?

Gleam shares significant similarities with Elm:
- Strong static typing with type inference
- Algebraic data types (custom types/variants)
- Pattern matching
- Immutable data structures
- No null/undefined (uses Result and Option)
- Compiles to Erlang/JavaScript

This makes porting the Morphir IR from Elm to Gleam relatively straightforward while gaining access to the BEAM ecosystem.

## Repository Structure

```
morphir-gleam/
├── packages/                    # Monorepo packages directory
│   └── morphir_models/          # Core IR types package
│       ├── gleam.toml           # Package manifest
│       ├── src/morphir/ir/      # IR type definitions
│       └── test/                # Package tests
├── .mise.toml                   # Tool versions (Gleam, Erlang)
└── AGENTS.md                    # This file
```

### Adding New Packages

Create packages under `packages/` and use path dependencies:

```toml
# In a new package's gleam.toml
[dependencies]
morphir_models = { path = "../morphir_models" }
```

## Architectural Principles

### Functional Programming

Gleam is a functional language by design. Follow these principles:

1. **Immutable Data** - All data in Gleam is immutable; embrace this
2. **Pure Functions** - Prefer pure functions; isolate side effects
3. **Pattern Matching** - Use exhaustive pattern matching for control flow
4. **Result Types** - Use `Result(value, error)` for fallible operations
5. **Option Types** - Use `Option(value)` instead of nullable values

### Make Invalid States Unrepresentable

Use Gleam's type system to prevent invalid states at compile time:

```gleam
// GOOD: Invalid states are impossible
pub type Access {
  Public
  Private
}

pub type AccessControlled(a) {
  AccessControlled(access: Access, value: a)
}

// BAD: Could have inconsistent state
pub type BadAccessControlled(a) {
  BadAccessControlled(
    is_public: Bool,
    is_private: Bool,  // What if both are true?
    value: a,
  )
}
```

### Morphir IR Type Mapping

When porting types from morphir-elm, follow these conventions:

| Elm Construct | Gleam Equivalent |
|---------------|------------------|
| `type alias Foo = ...` | `pub type Foo = ...` |
| `type Foo = A \| B \| C` | `pub type Foo { A B C }` |
| `type Foo a = ...` | `pub type Foo(a) { ... }` |
| `Dict k v` | `Dict(k, v)` from `gleam/dict` |
| `List a` | `List(a)` |
| `Maybe a` | `Option(a)` from `gleam/option` |
| `Result e a` | `Result(a, e)` (note: order swapped) |
| `( a, b )` | `#(a, b)` |

### Module Naming

- Use snake_case for module names: `morphir/ir/fqname.gleam`
- Use snake_case for function names: `to_camel_case`
- Use PascalCase for type names: `FQName`, `AccessControlled`
- Suffix modules that conflict with keywords: `type_.gleam` (not `type.gleam`)

## Development Workflow

### Prerequisites

```sh
# Install mise for tool management
curl https://mise.run | sh

# Install Gleam and Erlang
mise install
```

### Building and Testing

```sh
cd packages/morphir_models

# Build the package
gleam build

# Run tests
gleam test

# Format code
gleam format

# Check without building
gleam check
```

### Test-Driven Development

Write tests before implementation using gleeunit:

```gleam
import gleeunit/should

pub fn name_to_snake_case_test() {
  ["my", "variable", "name"]
  |> name.to_snake_case
  |> should.equal("my_variable_name")
}
```

Test file naming: `test/<module_name>_test.gleam`

### Code Style

1. **Format code** - Always run `gleam format` before committing
2. **Document public APIs** - Use `////` for module docs and `///` for function docs
3. **Keep functions small** - Each function should do one thing
4. **Avoid deep nesting** - Use early returns with `use` or extract functions

## CLI Standards (Future Packages)

When building CLI tools:

1. **stdout** - Command output only (data, results)
2. **stderr** - Logs, diagnostics, progress indicators
3. **Exit codes** - 0 for success, non-zero for errors
4. **JSON output** - Support `--json` flag for machine-readable output

This separation enables proper shell piping: `morphir-gleam generate | jq .`

## Git Workflow

### Commit Messages

Use conventional commits:

```
feat(ir): add JSON serialization for Type
fix(name): handle empty string input
docs: update README with usage examples
test(fqname): add edge case tests
```

### Branch Naming

- Feature branches: `feature/json-serialization`
- Bug fixes: `fix/name-parsing`
- Documentation: `docs/api-reference`

## Critical Compliance Requirement

> **ABSOLUTELY DO NOT include AI assistants (like Claude, Copilot, etc.) as co-authors in commits.**

This violates FINOS EasyCLA compliance and will block pull request merges. Only human developers should appear as commit authors.

Incorrect:
```
Co-authored-by: Claude <claude@anthropic.com>
```

## Session Completion Checklist

Before ending a coding session, ensure:

- [ ] All tests pass: `gleam test`
- [ ] Code is formatted: `gleam format`
- [ ] Changes are committed with descriptive message
- [ ] Branch is pushed to remote: `git push`
- [ ] Related issues are updated (if applicable)

Work is not complete until `git push` succeeds.

## Key Morphir Concepts

### The IR (Intermediate Representation)

The Morphir IR is a data structure that captures:

1. **Types** - Domain model definitions
2. **Values** - Business logic as executable expressions
3. **Modules** - Groupings of types and values
4. **Packages** - Versioned collections of modules

### Naming Hierarchy

```
FQName (Fully Qualified Name)
├── Package Path (e.g., ["morphir", "sdk"])
├── Module Path  (e.g., ["basics"])
└── Local Name   (e.g., ["int"])

Example: Morphir.SDK:Basics:Int
```

### Type System

The IR type system supports:
- **Variables** - Type parameters (`a`, `b`)
- **References** - Named types (`Int`, `String`, `List a`)
- **Tuples** - Product types (`#(Int, String)`)
- **Records** - Named fields (`{ name: String, age: Int }`)
- **Functions** - `a -> b`
- **Unit** - The unit type

### Value System

Values represent expressions:
- **Literals** - `42`, `"hello"`, `True`
- **Variables** - References to bindings
- **Apply** - Function application
- **Lambda** - Anonymous functions
- **LetDefinition** - Local bindings
- **PatternMatch** - Case expressions
- **IfThenElse** - Conditionals

## Resources

- [Morphir Documentation](https://morphir.finos.org)
- [Gleam Language Tour](https://tour.gleam.run)
- [Gleam Standard Library](https://hexdocs.pm/gleam_stdlib/)
- [morphir-elm Source](https://github.com/finos/morphir-elm/tree/main/src/Morphir/IR)
