# Static Analysis Specialist Reference

Tool configurations for the static analysis specialist in `/review-code`.

## Config Detection

Before applying defaults, check for project-specific configuration:

1. If `.pre-commit-config.yaml` exists, extract tool settings from it
   (line lengths, ignore lists, tool versions) and use those as the
   authoritative config for workspace files.
2. If a project-specific lint config exists (`pyproject.toml`, `setup.cfg`,
   `.flake8`, `.clang-tidy`, `.pylintrc`), use it for project files.
3. Fall back to the defaults below only when no config is found.

## File Classification

Classify by file extension. Use directory location to distinguish workspace
infrastructure from project code:

| File pattern | Location | Language |
|---|---|---|
| `*.py` | `.agent/scripts/`, `.agent/hooks/` | Python (workspace) |
| `*.py` | `project/` or other | Python (project) |
| `*.cpp`, `*.hpp`, `*.h`, `*.cc`, `*.cxx` | any | C++ |
| `*.sh` | any | Shell |
| `*.yaml`, `*.yml` | any | YAML |
| `*.xml` | any | XML |
| `*.js`, `*.ts`, `*.jsx`, `*.tsx` | any | JavaScript/TypeScript |
| `*.md`, `*.rst`, `*.txt` | any | skip (no linting) |

## Python — Workspace

Defaults match the workspace `.pre-commit-config.yaml`:

```bash
flake8 --max-line-length=100 \
  --extend-ignore="E203,W503,E402" \
  <changed-py-files>
```

The E203/W503 ignores compensate for Black formatting. E402 allows late
imports in scripts that modify `sys.path`.

Optional deeper check (if mypy is available):

```bash
mypy --ignore-missing-imports --no-error-summary <changed-py-files>
```

## Python — Project

Use the project's own config if available (`pyproject.toml`, `setup.cfg`,
`.flake8`). If none exists, fall back to sensible defaults:

```bash
flake8 --max-line-length=100 <changed-py-files>
```

## C++

### cppcheck

```bash
cppcheck -f --inline-suppr -q \
  --suppress=internalAstError \
  --suppress=unknownMacro \
  <changed-cpp-files>
```

### clang-tidy (optional)

```bash
clang-tidy <changed-cpp-files> -- -std=c++17
```

Requires a compilation database (`compile_commands.json`). Only run if one
exists in the build directory. Skip otherwise.

If a `.clang-tidy` config exists in the project, clang-tidy will use it
automatically.

## Shell

```bash
shellcheck --severity=warning <changed-sh-files>
```

## JavaScript / TypeScript

Use the project's ESLint config if available:

```bash
npx eslint <changed-js-files>
```

If no ESLint config exists, skip (no sensible universal default).

## YAML

```bash
yamllint -d '{extends: default, rules: {line-length: {max: 120}, document-start: disable}}' \
  <changed-yaml-files>
```

## XML

```bash
xmllint --noout <changed-xml-files>
```

## Running the Specialist

1. Check for project-specific lint configs (see Config Detection above)
2. Classify each changed file using the table above
3. Group files by location + language
4. Run the appropriate tool with the matching config
5. Collect output — each finding should include:
   - **file**: relative path
   - **line**: line number
   - **tool**: which tool found it
   - **message**: the finding text
6. Filter: only report findings on lines **touched by this PR** (added or
   modified lines in the diff). Findings on unchanged context lines are noise.
7. Pass findings to the lead reviewer for deduplication and severity classification
