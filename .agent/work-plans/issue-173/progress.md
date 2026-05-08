---
issue: 173
---

# Issue #173 — merge_pr.sh: project PRs fail silently when --type is omitted

## Plan
**Status**: complete
**When**: 2026-05-07 21:30
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-173/plan.md`.

Replace path-based auto-detect with `git worktree list --porcelain`
enumeration; try both workspace and project remotes for the PR lookup so
type can be determined from the first repo that returns a hit; add
`MERGE_PR_ARGS` passthrough on the Makefile rule.
