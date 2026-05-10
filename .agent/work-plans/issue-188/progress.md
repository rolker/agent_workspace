---
issue: 188
---

# Issue #188 — /start-task: $ARGUMENTS quoting breaks every multi-flag invocation

## Plan
**Status**: complete
**When**: 2026-05-09 17:30
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-188/plan.md`.

Drop the quotes around `$ARGUMENTS` in `start-task/SKILL.md` (Option C
from `/review-issue` discussion); rewrite "Argument handling" honestly;
add embedded-whitespace bullet to "When not to use"; add manual-
verification procedure (same pattern as merge_pr.sh in #186). Single
file, ~30 LOC. No Open Questions — design resolved during issue review.
