---
issue: 181
---

# Issue #181 — cross_model_review.sh: gemini agent fails — `gemini -p` is invoked without a value

## Plan
**Status**: complete
**When**: 2026-05-07 23:30
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-181/plan.md`.

Pass an explicit empty string value to `gemini -p` in both sync and tmux
call sites, keeping stdin as the prompt source so the script's argv-
limit avoidance constraint (line 55 comment) stays honored. Add a code
comment at each site explaining why the `""` is load-bearing. Fix
verified empirically before planning.
