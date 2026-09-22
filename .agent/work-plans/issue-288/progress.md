---
issue: 288
---

# Issue #288 — cross_model_review.sh: headless gemini permission denial reported as a completed review

## Plan Authored
**Status**: complete
**When**: 2026-09-22 09:30 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-288/plan.md` at `8b2733e`

Feed agy the prompt over stdin via stream-json (fixes #274) and validate the result event so a headless permission denial with empty output is reported as a failed review (fixes #288); a shared helper serves both tmux and sync modes.
