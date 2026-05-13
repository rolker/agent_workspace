---
issue: 204
---

# Issue #204 — /start-task --type project: use Bash cd instead of EnterWorktree (cross-repo limitation)

## Plan
**Status**: complete
**When**: 2026-05-13 16:30
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-204/plan.md`.

Replace `EnterWorktree(path="$WT")` in `/start-task` step 4 with `cd "$WT"`,
uniformly across all modes. Update `.claude/skills/start-task/SKILL.md`
(step 4 + exit semantics + verification cases), `CLAUDE.md` lines 50–56
(adapter description), and add a `### Worktree Entry` subsection to
`AGENTS.md`. No script changes, no hook changes — `/start-task` is the
single entry point that enforces the new convention.
