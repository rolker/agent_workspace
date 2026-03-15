---
name: document-project
description: Generate or update project component documentation (README and API docs) by reading source code. Enforces the documentation verification workflow.
---

# Document Project

## Usage

```
/document-project [<component-path>]
```

If no path is given, use the current directory.

## Overview

**Lifecycle position**: Utility — use after `audit-project` flags documentation
gaps, or when asked to "document a component", "update the README", or "write
API docs".

Generates both user-facing component documentation (README with interfaces,
configuration, usage) and developer-facing API documentation (class/function
reference) by reading the actual source code.

**Cardinal rule**: No fact without reading the source. Every parameter name,
interface name, type, and default value must come from the code, not
assumptions. See `.agent/knowledge/documentation_verification.md`.

## Steps

### 1. Inventory the component

```bash
# Detect project type and list source files
find <component_path> -name '*.py' -o -name '*.cpp' -o -name '*.hpp' \
  -o -name '*.h' -o -name '*.ts' -o -name '*.js' -o -name '*.go' \
  -o -name '*.rs' | sort

# Interface/schema definitions
find <component_path> -name '*.proto' -o -name '*.thrift' \
  -o -name '*.graphql' -o -name '*.json' -name 'schema*' | sort

# Configuration files
find <component_path> -name '*.yaml' -o -name '*.toml' -o -name '*.json' \
  -name 'config*' | sort
```

Record the component name, description, maintainer, license, and dependencies
from the project manifest (`package.json`, `pyproject.toml`, `Cargo.toml`,
`go.mod`, etc.).

### 2. Extract facts from source

Follow the command cookbook in `.agent/knowledge/documentation_verification.md`
to grep for every:

- **Configuration parameter**: environment variables, config file keys,
  CLI flags
- **Public API endpoint**: HTTP routes, gRPC methods, exported functions
- **Interface definition**: exported types, classes, interfaces, structs
- **Event/message schema**: event names, payload types

Record each finding with its file path and line number.

### 3. Analyze entry points and interfaces

Read every entry point file (main file, index file, handler file). Note:
- CLI arguments and flags (with defaults and descriptions)
- Environment variable configuration
- HTTP/gRPC/other interface definitions
- Exported public API surface

### 4. Analyze API (libraries and modules)

For C++ libraries (headers in `include/<component_name>/`):
- Public class definitions
- Public methods and their signatures
- Type definitions (`struct`, `enum`, `typedef`)

For Python modules:
- Class definitions and `__init__` signatures
- Public methods
- Module-level functions

For TypeScript/JavaScript:
- Exported classes and functions
- Type/interface definitions
- Default export

For Go packages:
- Exported functions and types
- Package-level documentation

For Rust crates:
- `pub` functions, structs, enums, and traits

### 5. Generate component README

Use the template at `.agent/templates/component_documentation.md` (or
`.agent/templates/package_documentation.md` if available):

- Fill in each section from the facts gathered in steps 1–3.
- **Omit** sections that don't apply (no empty tables).
- If a README already exists, preserve custom sections (e.g., "Theory of
  Operation", "Background") while standardizing the interface/API/usage sections.

Typical README sections for a component:
- Overview / description
- Installation / setup
- Configuration (parameters, environment variables)
- Usage examples
- Public API (for library components)
- Development / contributing

### 6. Generate API documentation (if applicable)

If the component contains libraries or modules with public APIs (not just
a standalone executable):

1. Create `docs/API.md` in the component root.
2. Document each public class/function with its signature, parameters, return
   type, and a usage example.
3. Include type definitions and enums.

Skip this step if the component only contains application executables with
no reusable library code.

### 7. Self-review

Run through the verification checklist:

- [ ] Every configuration parameter name matches an actual declaration in source
- [ ] Every API endpoint/route matches actual route definitions
- [ ] Every type/interface name matches actual type definitions
- [ ] Every default value is copied from the source
- [ ] Sections with no applicable content have been removed
- [ ] CLI arguments match actual argument declarations
- [ ] Examples are syntactically valid and accurately reflect the API

## References

- `.agent/knowledge/documentation_verification.md` — Verification workflow
  and command cookbook
- `.agent/templates/component_documentation.md` — README template with
  verification checklist

## Guidelines

- **Read before writing** — complete steps 1–4 before generating any text.
- **Omit, don't leave empty** — if a component has no CLI flags, remove the
  CLI flags section entirely.
- **Preserve existing work** — if a README exists, update rather than replace.
  Keep custom sections that add value.
- **One component at a time** — don't batch across components. Each component
  gets its own focused documentation pass.
- **Cite line numbers** — when documenting a parameter or interface, note the
  source file and line so reviewers can verify.
