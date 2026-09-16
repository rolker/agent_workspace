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

## Plan (revision 2)

**Status**: complete
**When**: 2026-09-16
**By**: Claude Code Agent (claude-fable-5-1)

Plan rewritten as the design-B definition after the owner's 2026-09-16
direction (issue comments) and the eight-experiment spike
(`spike-results.md`, Claude Code 2.1.273; four experiments re-run by the
owner with real credentials). Projects live anywhere; separate session
roots; worktrees under each root; workspace + project layers injected by a
registry-gated user-tier SessionStart hook (ancestor loading does not cross
a worktree boundary, so ancestry is not relied on); registry gains
`parent`/`worktrees`/`role`/`distro`; `project/` and `projects/` retired
outright; four additive PRs; acceptance test on real `gz4d` issues. Design A
recorded as set aside with the finding that removed its advantage. Manifest
support (step 4) re-scoped to #267 (general ROS manifest resolver).
