---
issue: 330
---

# Issue #330 — validate: the global validator requires .git at every project root (fails ros2_colcon), and single_project validate checks the whole workspace

## Issue Review
**Status**: complete
**When**: 2026-09-23 09:51 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #330

### Scope Assessment

**Well-scoped?** Yes — both defects are in the same file (`validate_workspace.py`) and the same dispatch seam (`adapter_validate` in `single_project/adapter.sh`), and fixing defect 2 (scoping `single_project`'s validate to the named project) is easiest to land alongside defect 1 (moving shape checks into per-type adapters), since both touch how `validate_workspace.py` walks the registry. Splitting them would leave an awkward half-state where the registry loop still hard-codes `.git`. One PR is right-sized; keep it that way rather than growing into a broader adapter refactor.

**Right repo?** Yes — `validate_workspace.py`, `single_project/adapter.sh`, and `ros2_colcon/adapter.sh` are all workspace infrastructure (`.agent/`). No project-repo content is involved.

**Dependencies**: None blocking. Related context: #317 (session-roots/user-tier work, status Provisional per ADR-0016) and the gz4d/geozui4d#7 acceptance run that surfaced this — worth linking, not worth waiting on.

I verified both claimed defects against current source:
- `validate_workspace.py`'s registry loop (~line 126) does `if not (path / ".git").exists() and not (path.resolve() / ".git").exists(): issues.append(f"project '{name}': {path} is not a git repository")` for every non-parent registry entry, regardless of `ptype`. This is exactly the single_project-shaped assumption the issue describes, and it contradicts the adapter contract's own framing.
- `single_project/adapter.sh`'s `adapter_validate()` (line 85-87) is a one-line `exec python3 .../validate_workspace.py "$@"` — it ignores `ACTIVE_PROJECT_NAME`/`ACTIVE_PROJECT_ROOT` entirely and always validates the whole registry. `ros2_colcon/adapter.sh`'s `adapter_validate` (line 567) does check only its own checkout, confirming the asymmetry the issue reports.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | OK | Fix is code (adapter delegation), not a doc note; issue explicitly asks for tests exercising both defects |
| A change includes its consequences | Action needed | If `single_project`'s `validate` verb changes meaning (named-project-only) and a whole-workspace check moves elsewhere, `AGENTS.md`'s script-reference row for `validate_workspace.py` (currently "Validate project/ configuration") and its `make validate` description should be checked against the new split so they still describe what the commands actually do |
| Test what breaks | OK | Issue's own proposed test plan (registry entry with a `ros2_colcon` type and no `.git`; `--project <name> validate` not reporting other projects) targets the actual regression, not framework glue |
| Workspace vs. project separation | OK | Purely workspace-infra; no project coupling introduced |
| Only what's needed | Watch | The fix could be read as "make every adapter's validate fully self-contained," which is more than this issue needs — the minimal fix is: stop hard-coding the `.git` shape check in the generic registry walker, and scope `single_project`'s verb to its own project. Don't let it grow into re-auditing every adapter's `validate` implementation |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0011 — Project-type adapter contract | Yes | This is squarely an ADR-0011 violation: "Shape-specific behavior lives in `.agent/project_types/<type>/adapter.sh` behind the 12-verb contract; workspace content stays project-agnostic." The generic registry loop in `validate_workspace.py` embeds a single_project-shape assumption (`.git` at the entry root) for every type, and the `validate` verb's contract ("Check checkout shape matches what the type expects") is only honored by `ros2_colcon`, not by `single_project`, which instead re-runs the whole-workspace check. The issue's proposed fix (delegate per-entry shape checks to each type's adapter; scope `single_project`'s `validate` to the named project) is the correct application of the existing contract, not new policy. `validate_adapter.sh` should still pass unchanged since the verb signature doesn't change. |
| 0013 — progress.md entry-type vocabulary | No | No workflow-skill changes involved |
| 0016 — Session roots and the user tier | No (tangential) | Only relevant as "found while" context (gz4d session root check); this issue's fix doesn't touch `user_tier_install.sh` or root resolution |

### Consequences

- `AGENTS.md`'s script-reference table entry for `validate_workspace.py` ("Validate project/ configuration") and the `make validate` line in the Build & Test section should be reviewed once the split lands, so they describe the actual per-project vs. whole-workspace split rather than the current (already slightly stale) single description.
- If a new whole-workspace check surfaces as its own command/verb (the issue suggests keeping "the whole-workspace check as its own command, for example `make validate`"), confirm it doesn't collide with the existing `make validate` semantics documented in `AGENTS.md`/`ARCHITECTURE.md` — either `make validate` keeps meaning "whole workspace" (already true today) and only the per-project adapter verb narrows, or the split needs to be spelled out explicitly wherever `make validate` is documented.

### Recommendations

- Confirm whether `make validate` (no `--project`) is meant to remain "check everything" after this fix, or whether it should also route to "current project" when one is registered as active — the issue's wording ("keep the whole-workspace check as its own command") reads as the former; state that explicitly in the plan so it isn't left ambiguous during implementation.
- When delegating the per-entry shape check to `adapter --project <name> validate`, make sure `validate_workspace.py` still surfaces the *name* of the failing project in its output (today's `project '{name}': {path} is not a git repository` format) — don't lose that context by just shelling out and passing through the adapter's raw stderr.

### Actions
- [ ] If `single_project`'s `validate` verb changes meaning (named-project-only) and a whole-workspace check moves elsewhere, `AGENTS.md`'s script-reference row for `validate_workspace.py` (currently "Validate project/ configuration") and its `make validate` description should be checked against the new split so they still describe what the commands actually do
- [ ] Confirm whether `make validate` (no `--project`) is meant to remain "check everything" after this fix, or whether it should also route to "current project" when one is registered as active — the issue's wording ("keep the whole-workspace check as its own command") reads as the former; state that explicitly in the plan so it isn't left ambiguous during implementation.
- [ ] When delegating the per-entry shape check to `adapter --project <name> validate`, make sure `validate_workspace.py` still surfaces the *name* of the failing project in its output (today's `project '{name}': {path} is not a git repository` format) — don't lose that context by just shelling out and passing through the adapter's raw stderr.
