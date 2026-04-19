---
issue: 147
---

# Issue #147 — cross_model_review.sh and plan-task skill write work-plans into main when invoked outside issue worktree

## Plan
**Status**: complete
**When**: 2026-04-19 (current session)
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-147/plan.md`.

Approach: add a shared sourceable helper `_resolve_work_plans_dir.sh` that
enforces option 1+4 from the issue (refuse outside matching worktree, explicit
override via `--work-plans-dir`/`$WORK_PLANS_DIR_OVERRIDE`). Wire it into
`cross_model_review.sh` and into `plan-task` SKILL.md Step 4 so both fail
loudly instead of silently writing into the main tree.
