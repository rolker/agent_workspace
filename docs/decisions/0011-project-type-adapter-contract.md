# ADR-0011: Project-Type Adapter Contract

## Status

Accepted. Supersedes
[ADR-0003](0003-workspace-infrastructure-is-project-agnostic.md).

## Context

[ADR-0003](0003-workspace-infrastructure-is-project-agnostic.md) made the
workspace project-agnostic, but scoped that agnosticism to "any
**single-repo** project": one repo, cloned or symlinked at `project/`, with
its shape hardcoded across `build.sh`, `test.sh`, `setup_project.sh`,
`sync_project.py`, `validate_workspace.py`, and `worktree_create.sh`.

Issue #172 commits the workspace to hosting other project shapes — sibling
multi-repo projects and ROS 2 colcon workspaces — from one workspace clone.
That reverses ADR-0003's single-repo assumption, so per
[ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md) it requires
supersession, not an addendum.

The part of ADR-0003 worth keeping is the separation doctrine: workspace
infrastructure must stay generic; project-specific content belongs with the
project; the project must remain usable standalone. What must change is
where project-*shape* knowledge lives.

## Decision

Project-shape-specific behavior is isolated behind a fixed **adapter
contract**. Each project type implements the same 10 verbs in a single
`adapter.sh` at `.agent/project_types/<type>/`:

| Verb | Purpose |
|---|---|
| `setup` | First-time bring-up: clone, layer import, post-install hooks |
| `sync` | Pull updates across constituent repos / refresh layers |
| `validate` | Check checkout shape matches what the type expects |
| `build` | Invoke the project's build |
| `test` | Invoke the project's tests |
| `install` | Deploy / install the built artifact (no-op default) |
| `env` | Emit shell statements callers `eval` (e.g., ROS overlay) |
| `project_root` | Path to the project tree |
| `repos` | Newline-separated `name:path` per constituent repo |
| `scope_for_pr` | Given a path, the `owner/repo` a PR targets |

Rules:

- **One dispatcher.** `.agent/scripts/adapter [--from <dir>] <verb>`
  resolves `PROJECT_TYPE` from `.agent/project_config.sh` (default:
  `single_project`) and dispatches to the type's `adapter_<verb>` function.
  `REQUIRED_VERBS` in the dispatcher is the single source of truth for the
  contract.
- **The contract is the narrow waist.** Workflow scripts and skills call
  adapter verbs when they touch anything that differs per project shape;
  they never branch on project type themselves.
- **Verbs are added by the test** *"the workflow needs this, and the how
  differs per project type"* — candidates failing it (docs, lint, format)
  stay workflow concerns.
- **Mechanical enforcement.** `.agent/scripts/validate_adapter.sh` asserts
  every type implements every verb; wired to pre-commit and CI
  (ADR-0004/0005).
- **Separation doctrine carried forward from ADR-0003.** The workspace repo
  still contains only generic infrastructure (adapters included — they
  encode *shape* knowledge, not knowledge of any specific project); the
  project repo still works standalone; the project's own
  `remote.origin.url` remains its source of truth.

`single_project` is the first adapter and is a pure facade over the
pre-adapter scripts, so existing workspaces behave identically. Later #172
steps add `multi_repo` and `ros2_colcon` types.

## Consequences

**Positive:**
- Multi-repo and ROS-shaped projects become hostable without forking the
  workspace (the drift between `agent_workspace` and `ros2_agent_workspace`
  was the motivating cost).
- One mental model across shapes: `make build/test/install/setup/sync` mean
  the same thing everywhere.
- The contract is mechanically enforced, not aspirational — an incomplete
  adapter fails pre-commit and CI.

**Negative:**
- Indirection: `make build` now traverses shim → dispatcher → adapter
  before reaching the build command.
- A bad dispatcher or adapter change affects every project on a machine
  (wider blast radius than per-project clones); the adapter test suite is
  the mitigation.
- The 10-verb contract will feel the pressure to grow; each addition must
  pass the differs-per-type test and update every existing adapter (the
  validator makes skipping that impossible).

## References

- [ADR-0003](0003-workspace-infrastructure-is-project-agnostic.md) —
  superseded by this ADR
- [ADR-0004](0004-enforcement-hierarchy-for-agent-compliance.md),
  [ADR-0005](0005-layered-enforcement-strategy.md) — validator wiring
- [ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md) — why this
  is a supersession, not an addendum
- Issue #172 (workspace redesign umbrella), #210 (this step)
