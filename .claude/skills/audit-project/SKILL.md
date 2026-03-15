---
name: audit-project
description: Check a project repo against workspace and project-level conventions. Reports governance coverage, documentation gaps, and test status.
---

# Audit Project

## Usage

```
/audit-project [<repo-name>]
```

If no repo name is given, audit the project repo in the current directory
(when working in a project worktree).

## Overview

**Lifecycle position**: Utility/periodic — run before or after repo work to
check project-level governance. Not tied to the per-issue lifecycle.

Check a project repo against workspace standards and its own governance docs.
Reports what's present, what's missing, and what may have drifted. Useful
for onboarding to a repo, identifying documentation gaps, or verifying
governance adoption.

**Not the same as `audit-workspace`** — that checks workspace-level governance.
This checks a single project repo.

## Steps

### 1. Identify the repo

If a repo name is given, find it under `project/<repo-name>`.
If not, use the current directory. Verify it's a valid project repo
(has at least a recognizable project structure such as a build file,
source directory, or manifest).

```bash
# Find repo location
find project/<repo-name> -maxdepth 0 -type d 2>/dev/null
```

### 2. Check governance coverage

Using the governance template (`.agent/templates/project_governance.md`)
as reference, check what exists:

| Item | Status | Path |
|---|---|---|
| `.agents/README.md` | Present / Missing | ... |
| `PRINCIPLES.md` | Present / Missing | ... |
| `ARCHITECTURE.md` | Present / Missing | ... |
| `docs/decisions/` | Present / Missing (N ADRs) | ... |
| `.agents/workspace-context/` | Present / Missing | ... |

This is a **coverage report**, not a mandate — not every repo needs full
governance. But missing items should be noted.

### 3. Check agent guide quality

If `.agents/README.md` exists, check it against the template
(`.agent/templates/project_agents_guide.md`):

- Does it have the expected sections? (Component inventory, layout,
  architecture, build & test, pitfalls)
- Are empty sections present? (Should be removed per template instructions)
- Do listed file paths actually exist in the repo?
- Does the component inventory match actual source modules?

### 4. Check project metadata

For each component/module in the repo:

- Is the description filled in (not empty or placeholder)?
- Are dependencies listed?
- Does it have a license?
- Is the maintainer field populated?

### 5. Check test status

For each component:

- Do test files exist? (`test/`, `tests/`, `*_test.py`, `*_test.cpp`, `*_test.go`, `*.test.*`)
- If available, run or report last known test results:

```bash
make test
# or: npm test, pytest, cargo test, etc.
```

Report test existence and pass/fail, not test quality.

### 6. Check documentation

- Does a top-level `README.md` exist?
- Do components have individual READMEs?
- Are entry points and interfaces documented?
- Are public APIs documented?

### 7. Cross-reference with workspace

- Is this repo listed in a workspace config or manifest file?
- Does the workspace's `.agent/project_knowledge/` symlink (pointing to
  `.agents/workspace-context/`) include content from this repo?

## Report Format

```markdown
## Project Audit: <repo-name>

**Location**: `project/<repo-name>`
**Components**: N components (list)

### Governance Coverage

| Item | Status |
|---|---|
| `.agents/README.md` | Present / Missing |
| `PRINCIPLES.md` | Present / Missing |
| ... | ... |

### Agent Guide

<findings if .agents/README.md exists, or "No agent guide — consider
creating one with the project_agents_guide.md template">

### Component Metadata

| Component | Description | License | Maintainer | Tests |
|---|---|---|---|---|
| `component_name` | OK / Missing | OK / Missing | OK / Missing | Exist / Missing |

### Documentation

| Item | Status |
|---|---|
| Top-level README | Present / Missing |
| ... | ... |

### Workspace Integration

| Check | Status |
|---|---|
| Listed in workspace manifest | Yes / No |
| ... | ... |

### Recommended Actions

- [ ] <specific action items>
```

## Guidelines

- **Report, don't fix** — identify gaps, don't fill them. Fixes should be
  separate issues.
- **Coverage, not quality** — check what exists, not whether it's good.
  "README exists" is objective; "README is well-written" is subjective.
- **Flag adoption level** — reference the governance template's adoption
  levels (minimal/standard/full) and note where this repo falls.
- **Don't run tests by default** — only run tests if the user asks. Just
  check whether test files exist.
