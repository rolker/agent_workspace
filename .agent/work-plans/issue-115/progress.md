---
issue: 115
---

# Issue #115 — Enable offline plan-review cycle via git-bug and local file paths

## Plan
**Status**: complete
**When**: 2026-04-04 13:15
**By**: Claude Code Agent (claude-opus-4-6)

Plan file: `.agent/work-plans/issue-115/plan.md`.

Add git-bug-first issue reading to plan-task and review-plan skills, make PR creation optional in plan-task, and let review-plan accept file paths or issue numbers as input.

## Implementation
**Status**: complete
**When**: 2026-04-04 13:30
**By**: Claude Code Agent (claude-opus-4-6)

Changes:
- `plan-task/SKILL.md`: git-bug JSON issue read in step 1 (title + body via `.comments[0].message`), `--no-pr` flag in usage, conditional PR creation in step 8
- `review-plan/SKILL.md`: three input forms (PR number, file path, `--issue N`), git-bug-first issue read in step 2, graceful degradation when offline
