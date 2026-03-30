---
name: gather-project-knowledge
description: Scan workspace repos and generate project knowledge summaries for `.agents/workspace-context/`. Requires a GitHub issue and project worktree on the target repo.
---

# Gather Project Knowledge

## Overview

**Lifecycle position**: Utility — run after repo changes to refresh project
knowledge summaries. Not tied to the per-issue lifecycle.

This skill operates in two modes depending on the target repo:

- **Manifest repo mode**: Scans all workspace repos and generates full summaries
  (`workspace_overview.md`, `governance_summary.md`, `project_profiles/`).
  Detected when the repo contains `config/bootstrap.yaml` (or equivalent
  workspace manifest).
- **Non-manifest repo mode**: Generates a self-profile only, written to the
  repo's own `.agents/workspace-context/`.

Output is written to `.agents/workspace-context/` in the current repo.

**Prerequisites**: This skill requires a GitHub issue and a project worktree on the
target repo. It does not create issues, worktrees, or PRs — it only generates and
commits content. Use the
[knowledge update issue template](../../../.agent/templates/knowledge_update_issue.md)
to create the issue, then:

```bash
.agent/scripts/worktree_create.sh --issue <N> --type project
source .agent/scripts/worktree_enter.sh --issue <N> --type project
```

## Workflow

### 1. Run the discovery script

```bash
.agent/scripts/discover_governance.sh --json
```

This produces a JSON-lines inventory of all governance documents across the
workspace and project repos.

### 2. Scan project repos and build the component inventory

For every project repo under `project/`:

- Glob for all source manifest files (e.g., `package.json`, `pyproject.toml`,
  `Cargo.toml`, `go.mod`, `pom.xml`, `*.cabal`) in the repo
- Extract the project/package name from each manifest — this is the only
  authoritative source for component names (not directory names)
- Read description and dependency fields for dependencies
- Detect language: `CMakeLists.txt`/`*.cpp`/`*.hpp` → C++,
  `setup.py`/`setup.cfg`/`pyproject.toml` → Python, `package.json` → JS/TS,
  `Cargo.toml` → Rust, `go.mod` → Go
- Read `.agents/README.md` if it exists (curated agent guide)
- Read `.agents/workspace-context/` contents if they exist (existing knowledge provider)

After scanning, produce a **structured inventory table** in your context. This
table is the single source of truth for all subsequent profile and overview
writing. Do not paraphrase or summarize it — copy component names verbatim.

```markdown
| Repo | Components (from manifest) | Language | Key Dependencies |
|------|---------------------------|----------|-----------------|
| repo_name | `pkg_a`, `pkg_b` | Python | dep1, dep2 |
```

> **Why this matters**: Using directory names instead of manifest-declared
> names, or relying on multi-hop summarization, produces errors in profiles.
> Always read manifests directly.

**Important constraints**:
- Never use directory names as component names — a directory may contain
  multiple components, or the directory name may differ from the declared name.
- Write profiles one at a time, referencing the inventory table directly.
  Do not delegate profile writing to a subagent that works from a natural
  language summary of the scan results.

### 3. Generate summaries

Write files to `.agents/workspace-context/` in the current repo. The set of
files depends on the mode.

#### Manifest repo mode

Detected when the repo contains a workspace-level manifest (`config/bootstrap.yaml`
or equivalent). Generates all three summary types:

##### `workspace_overview.md`

High-level workspace inventory:

- Project structure (which projects exist, what they contain)
- Component inventory table: repo, components, language, brief description
- Cross-repo relationships (shared dependencies, shared libraries)
- Repos with governance docs vs repos without

> **Count derivation rule**: All numeric counts in `workspace_overview.md` —
> repos, components, and totals — must be derived from the structured inventory
> table from step 2. Never copy counts from intermediate outputs, prior runs,
> or pre-computed summaries.

##### `governance_summary.md`

Unified governance view organized by theme, not by repo:

- Workspace principles (from `docs/PRINCIPLES.md`) — short summary of each
- ADR index with one-line summaries and applicability
- Project-level principles (from any repo's `PRINCIPLES.md`) — note where
  they differ from or extend workspace principles
- Governance coverage: which repos have principles, ADRs, agent guides

##### `project_profiles/<repo>.md`

One file per project repo. For repos with an `.agents/README.md`, summarize it.
For repos without, generate a lightweight profile from the scan:

- Components found (from manifests)
- Language (C++ / Python / JS / Rust / Go / mixed — from build files)
- Key dependencies
- Whether governance docs exist
- Flag: "No `.agents/README.md` — consider creating one"

#### Non-manifest repo mode

For any project repo that is not the manifest repo. Generates a self-profile
only:

##### `.agents/workspace-context/<repo-name>.md`

A single profile of the current repo, using the same format as the manifest
repo's `project_profiles/<repo>.md` above. This allows the repo to provide
its own knowledge to the workspace without depending on a central scan.

### 4. Validate profiles against source

Before adding frontmatter or committing, validate every generated profile:

For each profile, glob for manifest files in the corresponding repo and
extract declared component names. Compare this list against the components
listed in the profile. If there is any mismatch — missing components, extra
components, or wrong names — fix the profile before proceeding.

Quick validation approach:
```bash
# List declared names from manifests (adapt pattern to project type):
# For Python: grep -r "^name" pyproject.toml setup.cfg
# For Node: jq '.name' package.json
# For Rust: grep '^name' Cargo.toml
# For Go: grep '^module' go.mod
```

Compare the output against what the profile claims. Every name must match
exactly. Do not proceed to step 5 until all profiles pass validation.

#### Validate summary counts (manifest repo mode only)

If `workspace_overview.md` was generated, verify its structure table:

1. For each project row:
   - **Repo count**: Count the number of rows in the Component Inventory table.
   - **Component count**: For those rows, sum the number of component names listed
     in the Components column (do not just count rows — multi-component repos
     contribute one count per component name).
2. Compare these counts against the values claimed in the overview.
3. Verify that totals equal the sum of per-project counts.

If any count mismatches, fix `workspace_overview.md` before proceeding.

### 5. Add frontmatter to generated files

Every generated file should start with:

```markdown
<!-- Generated by gather-project-knowledge skill. Do not edit manually. -->
<!-- Regenerate by running this skill in a project worktree for a knowledge-update issue. -->
<!-- Source: workspace at {workspace_repo_url} -->
<!-- Generated: {date} -->
```

### 6. Commit the changes

Stage all files in `.agents/workspace-context/` and commit with a message like:

```
Update project knowledge summaries

Scanned N repos. Found X components.
Changes: [brief summary of what changed]
```

Report what was generated and what changed compared to the previous version.

## Output Structure

```
.agents/workspace-context/
├── workspace_overview.md
├── governance_summary.md
└── project_profiles/
    ├── repo_a.md
    ├── repo_b.md
    └── ...
```

## Guidelines

- **Component names come from manifests only** — repo directory names and
  declared component names are different things. The only authoritative source
  for a component name is the manifest file (`package.json`, `pyproject.toml`,
  `Cargo.toml`, etc.). A repo named `tools` may contain components named
  `cli-helper`, `data-pipeline`, etc.
- **Verify against source** — every claim must come from actual files read
  during the scan. Do not guess component descriptions or dependencies.
- **Keep summaries concise** — the point is to save context window. A profile
  should be 20-50 lines, not a full reproduction of the source.
- **Flag gaps** — if a repo has no agent guide or no governance docs, note it.
  This helps prioritize documentation work.
- **Preserve existing content** — if `.agents/workspace-context/` already has
  hand-written files (not generated), do not overwrite them. Only update files
  with the generated-file frontmatter.
- **Respect other knowledge providers** — if a project repo has its own
  `.agents/workspace-context/`, read it as input but don't overwrite it.
  Summarize its content in the workspace-level view.
