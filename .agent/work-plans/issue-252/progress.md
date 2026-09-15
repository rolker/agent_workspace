---
issue: 252
---

# Issue #252 — ros2_colcon adapter phase 3: layer/package worktrees (no symlink fallback)

## Plan
**Status**: complete
**When**: 2026-09-15 09:05
**By**: Claude Code Agent (claude-sonnet-5, drafting for claude-fable-5-1)

Plan file: `.agent/work-plans/issue-252/plan.md`.

Recommends Design B (pure overlay: colcon-native overlay on the hosted instance's
existing layer installs, no symlinked siblings/layers) over Design A (upstream's
hybrid mirror), because it satisfies the no-symlink hard-stop rule structurally and
avoids reintroducing the #427/#598 bug classes, at medium rather than large
implementation cost.

## Plan revision
**Status**: complete
**When**: 2026-09-15 09:40
**By**: Claude Code Agent (claude-fable-5-1)

Resolved the three open questions with the owner: AGENTS.md untouched, p11-jazzy-only
smoke, explicit CLI (`--type project --project <name> --issue owner/repo#N --layer
--package-repos`, nothing inferred) with qualified branch names in non-owning repos.
Depends on #255 (`--repo` → `--project` rename).
