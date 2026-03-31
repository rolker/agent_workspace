# Agent Guide: {REPO_NAME}

> One-line description from README.

## Package Inventory

| Package | Language | Description |
|---------|----------|-------------|
| `pkg_name` | C++ / Python | What it does |

## Repository Layout

```
repo_root/
├── pkg_one/
│   ├── src/           # C++ source
│   ├── include/       # Headers
│   └── CMakeLists.txt
├── pkg_two/
│   ├── pkg_two/       # Python module
│   └── setup.py
└── ...
```

## Architecture Overview

Brief summary of data flows and component relationships. Describe how the
packages in this repo interact with each other and with external packages.
Link to `docs/` for details if available.

## Key Files to Read First

Prioritized list for agents new to this repo:

1. `path/to/entry_point` — Main node or launch file
2. `path/to/config.yaml` — Default parameters
3. `path/to/interfaces/` — Custom message/service/action definitions

## Build & Test

```bash
# Use the project's build/test commands (configured in .agent/project_config.sh)
make build
make test
```

Known build issues or special requirements:
- (List any non-obvious dependencies, build flags, or environment setup)

## Dependencies

| Component | Depends On | What It Imports |
|-----------|-----------|-----------------|
| `component_name` | `other_component` | Key imports or interfaces |

## Common Pitfalls

- (Repo-specific gotchas agents should know about)
- (Non-obvious conventions, naming quirks, or historical decisions)

---

## Instructions for Use

1. Copy this template to `.agents/README.md` at the project repo root.
2. Fill every section by reading actual source code — never assume.
3. Follow the verification workflow in
   [`.agent/knowledge/documentation_verification.md`](../../.agent/knowledge/documentation_verification.md).
4. **Omit** any section that does not apply (e.g., if there are no cross-layer
   dependencies, remove that section entirely). Do not leave empty tables.

## .agents/ Directory Structure

The `.agents/` directory at a project repo root can contain:

```
.agents/
├── README.md               # This file — agent onboarding guide
├── work-plans/             # Plans for work in this repo (optional)
└── workspace-context/      # Content symlinked into the workspace (optional)
```

- `README.md` and `work-plans/` are standalone — useful with or without the workspace.
- `workspace-context/` is only relevant if this repo participates in an
  [Agent Workspace](https://github.com/rolker/agent_workspace).
  The workspace symlinks this directory to `.agent/project_knowledge/`.

## Verification Checklist

- [ ] Every component listed actually exists in the repo
- [ ] Language column matches actual build configuration
- [ ] Architecture summary verified against source, not just existing docs
- [ ] Dependencies verified with grep for imports
- [ ] Key files actually exist at the listed paths
- [ ] Sections with no applicable content have been removed (not left empty)
