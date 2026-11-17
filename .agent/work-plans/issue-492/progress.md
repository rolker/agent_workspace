---
issue: 492
---

# Issue #492 — Follow-up to the folder retirement: say project, not product, in AGENTS.md, and note the retired shapes on four decision records

## Issue Review
**Status**: complete
**When**: 2026-11-17 12:00 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #492

### Scope Assessment

**Well-scoped?** Yes — six lines of approved text, one PR.
**Right repo?** Yes — workspace (AGENTS.md, docs/decisions).
**Serves**: Keep one current design — `docs/design.md#the-design` (documents match the code after pull request 491).
**Design picture?** No change — text notes only; the owner approved the wording in the issue.
**Dependencies**: none identified (pull request 491 is merged on main).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Verify before claiming | OK | Both "now" phrases match AGENTS.md on main: the Project bullet (lines 10-11, wrapped across a line break) and the ownership table row (line 29). Each proposed note is true of main: `worktree_create.sh` creates worktrees under the registered root; `_project_registry.sh` says projects.d/<name>.sh and `.agent/project_config.sh` "are no longer read, issue #265 part 4"; ADR-0018 has the "legacy unregistered `project/`" wording at lines 261 and 304. |
| Keep one current design | OK | Notes are added under `## Status`; decision text is untouched. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0002, 0003, 0011, 0018 | Yes | Status-note edits only; owner approved ("yes to both"). |

### Consequences

- AGENTS.md is exactly 200 lines (the pre-commit line budget); the T1 edit must not add a line. The first bullet wraps over two lines, so keep it at two.
- `grep -n -i product AGENTS.md` finds exactly the two lines named in the issue (10 and 29), nothing else.

### Recommendations

- No changes needed; the ADR-0018 "decision 6" reference is correct.

### Actions
- [x] No actions needed.

## Plan Authored
**Status**: complete
**When**: 2026-11-17 13:54 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-492/plan.md` at `4ea8d481`

Two phrase edits in AGENTS.md (200 lines kept, no reflow needed) in one commit, and one Status note per ADR 0002, 0003, 0011, 0018 in a second; no hook or test pins the changed phrases.

## Plan Review
**Status**: complete
**When**: 2026-11-17 13:55 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #492 — Follow-up to the folder retirement: say project, not product, in AGENTS.md, and note the retired shapes on four decision records
**Plan**: `.agent/work-plans/issue-492/plan.md` at `4ea8d481`
**Branch**: `feature/issue-492`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Five files, two commits, six owner-approved texts. |
| Issue alignment | Good | All six texts match the issue body character for character (two AGENTS.md phrases, four ADR notes). Acceptance checks (`grep -i product` empty, 200 lines, no other files) are in step 3. Serves, as checked: "Trust and information goals ("Trust, control and information"): rules and records that match the current system. Design section: `docs/design.md#documentation-layers`." Both exist (README.md `### Trust, control and information` under Workspace goals; `## Documentation layers` in docs/design.md). The issue review named `docs/design.md#the-design` instead; either fits a text-only change. |
| File targeting | Good | AGENTS.md lines 10 and 29 are the only `product` hits on this branch (based on main after PR 491). Each ADR has `## Status` at line 3, above the retired text, so "named below" holds. |
| Consequences | Good | AGENTS.md is 200 lines now; the new line 10 is shorter and lines 11-12 are unchanged, so the budget holds. `check_agents_md_budget.sh`, `check_design_anchors.sh` and `.agent/scripts/tests/test_skill_paths.sh` exist and are named in the verify step. |
| Principle alignment | Good | Truth of each note against main: ADR-0002 line 26 names `worktrees/project/<repo>/`, and `_worktree_helpers.sh` (lines 47-50) says #265 part 4 retired that fallback; ADR-0003 line 33 names `project/`, and neither `project/` nor `projects/` exists; ADR-0011 lines 16 and 53 name `project/` and `.agent/project_config.sh`, and `_project_registry.sh` (lines 54-56) says that file is no longer read (it is detected only to tell the user to retire it, `registry_stale_config_for`); ADR-0018 lines 261 and 304 carry the "legacy unregistered `project/`" wording, and `session_root.sh` (lines 51, 206) says the `project/` step was retired. Docs-only change, so no test is planned; the plan says no design-picture change. |
| ADR compliance | Good | ADR-0008 permits a dated note in an Accepted ADR's Status; decision text untouched. AGENTS.md and ADR edits are Ask First / owner decisions, covered by "yes to both" for this exact text. |
| ROS conventions | N/A | Workspace plan. |

### Findings

None.

### Summary

The plan quotes the approved wording exactly, each note is true of the code on main after PR 491, and the line budget holds. Ready for implementation.

### Recommended Actions

- [ ] None before implementation.

## Checkpoint
**Status**: complete
**When**: 2026-11-17 13:55 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review is ready with no findings and says the plan matches the six owner-approved texts character for character; the owner approved that text, the AGENTS.md edit and the four ADR notes before the issue was opened, so nothing in the plan is new to him)
**After**: plan
**Decision**: proceed

Read: the `## Plan Review` at `724a2a54` (verdict ready, no findings) and the plan at `4ea8d481`. The owner's approval, 2026-11-17, to "Q1 — are T1 and T2 right as worded? Q2 — should I open a small issue to track this follow-up?" with both texts shown in full: "yes to both". The merge decision stays his.

## Implementation
**Status**: complete
**When**: 2026-11-17 13:56 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-492 at `35f60ac6`

- `53a8c6e9` AGENTS.md: line 10 "the managed product, any folder" → "what is being built: any folder"; line 29 table row "The product being built (its registered folder)" → "The project's own files (its registered folder)". Still 200 lines.
- `35f60ac6` One dated note, its own paragraph, at the end of the `## Status` section of ADR-0002, ADR-0003, ADR-0011 and ADR-0018, text exactly as in the issue body and plan. No decision text edited.
- No other file changed.
- `grep -n -i product AGENTS.md`: no matches (exit 1).
- `bash .agent/scripts/tests/test_agents_md_budget.sh`: "Results: 7 passed, 0 failed".
- `bash .agent/scripts/tests/test_design_anchors.sh`: "test_design_anchors: 47 passed, 0 failed".
- Not run: `test_skill_paths.sh` (named in the plan's verify step; no skill or knowledge text changed, and the handoff named only the two suites above) and the full pre-commit pass (host runs it before the push). Every commit used `SKIP=validate-script-tests`; the other hooks ran and passed.
