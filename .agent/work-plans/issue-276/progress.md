---
issue: 276
---

# Issue #276 — Port run-issue from ros2_agent_workspace: in-process orchestrator over the #269 review loop, no container baggage

## Plan Authored
**Status**: complete
**When**: 2026-09-17 14:14 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `0d10096`

Three-PR port of run-issue as an in-process host: a tested dispatcher with a mechanical decision table, the skill plus docs, then a live exercise. Everything that existed only for containers is declined.

## Plan Review
**Status**: complete
**When**: 2026-09-17 14:18 -04:00
**By**: Claude Code Agent (claude-sonnet-5), fresh-context evaluator
**Verdict**: needs-work
**Plan**: `.agent/work-plans/issue-276/plan.md` at `0d10096`

### Findings
- [x] (must-fix) review-issue writes no `## Issue Review` entry; the table's first rows could never fire → revision 2 adds a persistence step to review-issue (PR 1)
- [x] (must-fix) model table asserted Opus as matching the owner's Sonnet-for-subagents rule → revision 2: Sonnet default, tier is Open Question 1
- [x] (suggestion) fork's implement phase: digest says dispatched, plan says inline → verified inline against the scratchpad clone; digest stale
- [x] (suggestion) split the gate change out of PR 1 → PR 0
- [x] (suggestion) state partial/failed handling, concurrency, resume, Claude-Code-only scoping → revision 2
