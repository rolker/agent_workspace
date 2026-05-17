# Plan: Workspace redesign foundation: 10-verb adapter contract + single_project adapter

## Issue

https://github.com/rolker/agent_workspace/issues/210

## Context

Step 1 of #172's 7-step migration. Today, project-shape concerns are hardcoded across `build.sh`, `test.sh`, `setup_project.sh`, `sync_project.py`, `validate_workspace.py`, and `worktree_create.sh` (700 lines, 4 coupling points). This step introduces a uniform 10-verb adapter contract and ships `single_project` as a pure facade so behavior is unchanged for daddy_camp. Every later step builds on this foundation.

## Approach

Build bottom-up so each commit is independently testable. The atomic-commit rule applies — one commit per step.

1. **Dispatcher** — write `.agent/scripts/adapter` with `_resolve_project_type` that reads `PROJECT_TYPE` from `.agent/project_config.sh`. Accept `--from <dir>` (unused in step 1, but locks the signature for step 2's cwd walk-up). Sources `.agent/project_types/${type}/adapter.sh` then execs `adapter_${verb}`. Define `REQUIRED_VERBS` as a single constant near the top — the validator imports it.
2. **`single_project/adapter.sh`** — single ~150-line file with all 10 verb functions. Verbs 1-4 delegate to existing scripts; `build`/`test`/`install` are `cd $(adapter project_root) && eval "$VAR"`; `env` is `:`; `project_root` echoes `$WORKSPACE_ROOT/project`; `repos` returns one `name:path` line; `scope_for_pr` walks up from path arg and extracts `owner/repo` from origin URL.
3. **Config fields** — add `PROJECT_TYPE=single_project` and `INSTALL_CMD=""` to `.agent/project_config.sh`. Document in the existing comment block.
4. **Validator** — `.agent/scripts/validate_adapter.sh` iterates `.agent/project_types/*/adapter.sh`, sources each, asserts every name in `REQUIRED_VERBS` is defined as a function. Nonzero exit with the missing-verb list.
5. **Wire existing scripts** — `build.sh`, `test.sh`, `setup_project.sh`, `sync_project.py` become two-line dispatch shims that exec `.agent/scripts/adapter <verb>`. The underlying logic moves into `single_project/adapter.sh` verb bodies (or remains where it is and the verb body calls it — pick per-script based on which is shorter).
6. **`make install` target** — add to `Makefile`; calls `.agent/scripts/adapter install`. No-ops when `INSTALL_CMD=""`.
7. **Tests** — `.agent/scripts/tests/test_adapter.sh` (or per-verb files under that dir). Cover: PROJECT_TYPE resolution, missing adapter dir, missing verb, each verb's behavior (especially: env emits nothing, install no-ops, build/test exit code propagation, repos format, scope_for_pr URL parsing for SSH + HTTPS forms). Verb tests assert **delegation observable** (right script invoked, right cwd) not just exit-zero.
8. **ADR-0003 supersession** — write `docs/decisions/0011-project-type-adapter-contract.md` (next free number). Mark ADR-0003 status as "Superseded by ADR-0011". New ADR explicitly preserves ADR-0003's workspace-vs-project separation; revises only the single-repo assumption.
9. **Doc consequences** — `AGENTS.md` Script Reference (add `adapter`, `validate_adapter.sh`); `.agent/knowledge/principles_review_guide.md` ADR table (add 0011, mark 0003 superseded); audit `README.md` and `ARCHITECTURE.md` for "single-repo" wording and update.
10. **Validator wiring** — pre-commit hook entry for `validate_adapter.sh`; CI job in `.github/workflows/validate.yml`. Per ADR-0004/0005: both, this PR.
11. **No-behavior-change verification** — `make build && make test` on daddy_camp; record exit codes and built-artifact list pre- and post-merge; both must match (exit codes equal; artifact lists set-equal).

## Files to Change

| File | Change |
|---|---|
| `.agent/scripts/adapter` | NEW — dispatcher + `_resolve_project_type` + `REQUIRED_VERBS` |
| `.agent/scripts/validate_adapter.sh` | NEW — verb-presence validator |
| `.agent/project_types/single_project/adapter.sh` | NEW — 10 verb implementations |
| `.agent/project_config.sh` (template/example) | NEW fields `PROJECT_TYPE`, `INSTALL_CMD` |
| `.agent/scripts/build.sh` | Shim → `exec .agent/scripts/adapter build` |
| `.agent/scripts/test.sh` | Shim → `exec .agent/scripts/adapter test` |
| `.agent/scripts/setup_project.sh` | Shim → `exec .agent/scripts/adapter setup` (or move body into verb) |
| `.agent/scripts/sync_project.py` | Shim → `exec .agent/scripts/adapter sync` (or wrap from verb) |
| `Makefile` | New `install` target |
| `.agent/scripts/tests/test_adapter.sh` | NEW — dispatcher + per-verb tests |
| `docs/decisions/0011-project-type-adapter-contract.md` | NEW ADR |
| `docs/decisions/0003-workspace-infrastructure-is-project-agnostic.md` | Status line → "Superseded by 0011" |
| `.agent/knowledge/principles_review_guide.md` | ADR table: add 0011; mark 0003 superseded |
| `AGENTS.md` | Script Reference: add `adapter`, `validate_adapter.sh` |
| `.pre-commit-config.yaml` | Add hook for `validate_adapter.sh` |
| `.github/workflows/validate.yml` | Add adapter-validate job |
| `README.md`, `ARCHITECTURE.md` | Audit for "single-repo" wording; revise as needed |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Validator wired to both pre-commit and CI in same PR |
| Capture decisions, not just implementations | ADR-0011 captures the adapter pattern; ADR-0003 superseded explicitly |
| A change includes its consequences | All cascaded files (AGENTS.md, review guide, README/ARCHITECTURE) updated in this PR |
| Only what's needed | 10 verbs justified per issue body; facade not inversion; one file per type |
| Improve incrementally | Hard "no behavior change for daddy_camp" gate; later steps explicitly out of scope |
| Test what breaks | Per-verb tests assert delegation (not just exit code); dispatcher tests cover failure modes |
| Workspace vs. project separation | Adapter pattern *reinforces* separation by isolating shape concerns behind one contract |
| The workspace serves the product | Step 1 alone delivers no product value; tracked in #172 — keep the program moving past step 1 |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0001 — Adopt ADRs | Yes | ADR-0011 added |
| 0003 — Project-agnostic workspace | Yes (superseded) | ADR-0011 supersedes; same PR; preserves separation intent |
| 0004 — Enforcement hierarchy | Yes | Validator at pre-commit + CI |
| 0005 — Layered enforcement | Yes | Same — local feedback + authoritative CI |
| 0007 — Retain Make with deps | Yes | Make targets keep working; new `install` target added |
| 0008 — Cross-reference addendums | Yes | Full supersession (position reverses), not addendum |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `AGENTS.md` Script Reference | Framework adapters if they duplicate it | Audit step (10); likely no edits, adapters point at AGENTS.md |
| ADR-0003 status | `principles_review_guide.md` ADR table | Yes, step 10 |
| `.agent/scripts/*` (build/test/setup/sync) | Script Reference table | Yes, step 10 |
| Makefile | ADR-0007 applicability check | Reviewed — `install` target consistent with stamp-file/dep-tracking model |

## Open Questions

The issue lists four; my recommended answers based on the review:

1. **ADR-0003 supersession: same PR.** Position reverses fundamentally; ADR-0008 requires supersession, not addendum.
2. **PROJECT_TYPE resolution.** Workspace config only for step 1; the `--from <dir>` arg locks the API for step 2's per-project extension.
3. **Validator wiring: both pre-commit and CI, this PR.** Small lift; ADR-0004/0005 favor both.
4. **`adapter env` line protocol.** Spec in dispatcher header comment now even though `single_project` returns nothing: "each line is a complete shell statement; callers `eval` the whole stdout." Locks the contract for step 6 (`ros2_colcon`).

Confirm before implementation.

## Estimated Scope

**Single PR, large.** ~17 files, ~600-800 LOC across dispatcher + adapter + tests + ADR + docs. The "no behavior change" gate argues against splitting; per-step atomic commits provide reviewable granularity within the one PR. PR base: `feature/issue-172` (created off main; merges into main via the eventual #172 integration PR).

## Implementation Notes

(Appended only for rationale-bearing design pivots discovered during coding.)
