---
issue: 133
---

# Issue #133 — cross_model_review.sh fails when invoked outside target repo worktree

## Plan
**Status**: complete
**When**: 2026-04-05 20:45
**By**: Claude Code Agent (claude-opus-4-6)

Plan file: `.agent/work-plans/issue-133/plan.md`.

Four targeted fixes: add `--repo` and `--work-dir` flags for explicit repo/artifact targeting, fix issue number extraction regex, and add empty diff guard with error surfacing.
