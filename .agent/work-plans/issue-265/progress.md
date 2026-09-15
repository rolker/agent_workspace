---
issue: 265
---

# Issue #265 — Step 5: hosted projects under projects/ with project-rooted sessions and per-project CLAUDE.md

## Plan
**Status**: complete
**When**: 2026-09-15 14:29
**By**: Claude Code Agent (claude-sonnet-5)

Plan file: `.agent/work-plans/issue-265/plan.md`.

Formalizes `projects/<name>/` as the primary hosting shape: `adapter setup`
renders a per-project `CLAUDE.md` from a per-type template; the legacy
`project/` symlink gets a deprecate-and-warn path (not hard removal) with
a migration helper; out-of-tree projects use a physical bind-mount under
`projects/<name>/` (per the logical-vs-physical-path test in the issue
comment) rather than a symlink, since Claude Code resolves `process.cwd()`
past symlinks and never walks the logical ancestor chain; the `.claude/`
launch-dir limitation (skills/hooks/commands not ancestor-walked) is
documented, not worked around.
