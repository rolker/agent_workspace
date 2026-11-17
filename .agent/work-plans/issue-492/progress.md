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
