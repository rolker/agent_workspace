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

## Plan review

**Status**: complete (findings applied)
**When**: 2026-09-16
**By**: independent Sonnet reviewer via /review-plan; findings applied by Claude Code Agent (claude-fable-5-1)

Nine findings, one Concern (user-tier allow-rules for scripts with no
registry awareness). Applied: `require_registered_root` guard + generated
allow-list manifest + behaviour test; legacy no-entry worktree fallback for
the PR 2→4 window; heading-drift test for the SessionStart renderer;
`dashboard.sh` substring logic called out; parent-root instance selection
decided (pending owner confirmation); project11 cycle stated as not
depending on #267; `registry_resolve_from_dir` claim corrected; discovery-
order change moved into the new ADR; PR title fixed. Review posted on PR
#266.

## Implement — PR 1 of 4 (registry)

**Status**: complete
**When**: 2026-09-16
**By**: Claude Code Agent (claude-fable-5-1)

Commit `35ea1ed`: trailing `key=value` registry fields (`parent`,
`worktrees`, `role`, `distro`, `default_instance`), parent roots
(pseudo-type `project`), `registry_entries_full` / `registry_field` /
`registry_instances` / `registry_default_instance` /
`registry_worktree_dir` (legacy fallback until PR 4) /
`registry_require_root`; adapter parent→instance resolution and
`ACTIVE_PROJECT_ROLE/DISTRO`; ros2_colcon distro from the registry with
manifest-mismatch hard error; worktree_create parent handling; validate and
dashboard parent awareness; Python parser parity. 15 new tests; all suites
green; pre-commit clean. Docs: ARCHITECTURE.md, WORKTREE_GUIDE.md,
projects.local.example, ROADMAP rows for steps 4/5 and cutover rows 1–3.
