# Documentation Verification Workflow

## Why This Exists

In PR [rolker/unh_marine_autonomy#37](https://github.com/rolker/unh_marine_autonomy/pull/37),
AI-generated package documentation contained 13 factual errors: fabricated parameters,
wrong types, non-existent API signatures, and incorrect names. The root cause was that
the agent documented from assumptions instead of reading source code.

This workflow prevents that class of error.

## Cardinal Rule

> **No fact without reading the source.**
>
> Every parameter name, function signature, configuration key, default value,
> and API endpoint in documentation must be verified against the actual source
> code. If you cannot find it in the source, do not write the claim.

## Step-by-Step Process

### 1. Inventory the Component

```bash
# List all source files
find <component_path> -name '*.py' -o -name '*.cpp' -o -name '*.hpp' \
  -o -name '*.h' -o -name '*.js' -o -name '*.ts' | sort

# List configuration files
find <component_path> -name '*.yaml' -o -name '*.yml' -o -name '*.json' \
  -o -name '*.toml' | sort

# Read package metadata (package.json, setup.py, Cargo.toml, etc.)
```

### 2. Extract Facts via Grep

Search for the specific patterns relevant to your project's language and
framework. Record each finding with its file and line number. Examples:

```bash
# Python: find class definitions, function signatures, config keys
grep -rn 'def \|class \|config\[' <component_path>/

# JavaScript/TypeScript: find exports, route definitions
grep -rn 'export \|router\.\|app\.' <component_path>/

# C++: find public API, class declarations
grep -rn 'public:\|class \|namespace ' <component_path>/
```

### 3. Cross-Reference Configuration

Configuration files may override defaults or rename parameters. Read every
config file in the component and verify that your documentation matches
the configured behavior, not just the source defaults.

### 4. Self-Review Checklist

Before submitting documentation, verify each claim:

- [ ] Names match source code exactly (function names, config keys, etc.)
- [ ] Default values match the source (or "none" if no default is provided)
- [ ] Types match the actual declarations, including module/package prefixes
- [ ] No section is present for a category the component does not use
- [ ] API signatures match the actual function/method definitions

## Common Hallucination Anti-Patterns

These are the mistakes agents make most often. Check your documentation against each one.

| Anti-Pattern | Example | How to Avoid |
|---|---|---|
| **Fabricated parameters** | Documenting `max_speed` when the code only declares `speed_limit` | Grep for config declarations; use exact names |
| **Assumed names** | Writing `/api/users` when the code defines `/api/v1/users` | Grep for route/endpoint definitions; use exact strings |
| **Wrong types** | Claiming `string` when the code uses `number` | Check the actual type annotation or declaration |
| **Omitted interfaces** | Skipping a public method that the class actually provides | Grep for all public methods; document all matches |
| **Invented default values** | Writing "default: 1.0" when the parameter has no default | Copy the default from the source declaration |

## Workspace-Specific Notes

- **`project/` may be a symlink** — Git-aware tools (`git grep`, `rg`) may
  behave differently when searching through symlinks. Use `rg --no-ignore`
  or search within the project directory directly.
