---
issue: 3
---

# Issue #3 — Add branch mode to /review-code (local pre-push self-review)

## Plan
**Status**: complete
**When**: 2026-05-09 11:44
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-3/plan.md`.

Add `--branch [<base>]` to `/review-code` and `cross_model_review.sh` so the
existing review pipeline can run on a local branch diff before the PR exists.
Five architectural decisions surfaced as Open Questions for approval before
implement.
