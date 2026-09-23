---
issue: 309
---

# Issue #309

## Issue Review
**Status**: complete
**When**: 2026-09-23 14:08-04:00
**By**: Codex CLI Agent (gpt-6)
**Issue**: #309

### Scope Assessment

**Well-scoped?** Yes — a shared coverage predicate and regression tests fit one PR.
**Right repo?** Yes — review-loop infrastructure belongs to agent_workspace.
**Dependencies**: None identified.

### Principle Alignment

| Principle | Status | Notes |
| --- | --- | --- |
| Only what's needed | OK | Reuse merge-gate equivalence without changing CI policy. |
| Test what breaks | OK | Real Git histories cover silent loss and stale-review rejection. |
| A change includes its consequences | OK | Update triage's sources contract and preserve merge callers. |

### ADR Applicability

| ADR | Triggered | Notes |
| --- | --- | --- |
| 0002 | Yes | Isolated feature/issue-309 worktree. |
| 0011 | Yes | Generic Git logic, no project-shape assumptions. |
| 0013 | Yes | Preserve entry vocabulary and original SHA provenance. |

### Consequences

- The gate now allows the issue's whole work-plan directory; use that current policy consistently.
- Regression tests belong in test_triage_reviews_integration.sh, which owns sources coverage.
- Codex observations remain work-plan evidence, not instruction or orchestrator changes.

### Recommendations

None beyond the implementation plan.

### Actions
- [x] No actions needed.

## Plan Authored
**Status**: complete
**When**: 2026-09-23 14:10-04:00
**By**: Codex CLI Agent (gpt-6)
**Plan**: `.agent/work-plans/issue-309/plan.md` at `bed79ef`

Share the existing merge-gate coverage rule with sources; preserve original review
SHAs and test real-history boundaries. Draft PR deferred until the fix is reviewable.
User authorized implementation and the workspace workflow in this session.
