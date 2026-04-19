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

## Local Review
**Status**: complete
**When**: 2026-04-19
**By**: Claude Code Agent (claude-opus-4-7)
**Verdict**: approved

**PR**: #148 at `1e4846a`
**Depth**: Standard (reason: touches skill governance + shared infra script)
**Must-fix**: 0 | **Suggestions**: 6

### Findings
- [ ] (suggestion) Add source-only guard — `.agent/scripts/_resolve_work_plans_dir.sh:end-of-file`
- [ ] (suggestion) Validate/normalize `$WORK_PLANS_DIR_OVERRIDE` (reject `..`) — `.agent/scripts/_resolve_work_plans_dir.sh:33`
- [ ] (suggestion) Header comment re: `local VAR=$(...)` masking exit status — `.agent/scripts/_resolve_work_plans_dir.sh:header`
- [ ] (suggestion) Replace `return 1 2>/dev/null || exit 1` with plain `exit 1` — `.claude/skills/plan-task/SKILL.md:104`
- [ ] (suggestion) Move resolver call earlier in script — `.agent/scripts/cross_model_review.sh:~226`
- [ ] (suggestion) Document integer-only contract for issue arg — `.agent/scripts/_resolve_work_plans_dir.sh:39`

### Out-of-scope follow-ups
- Loose `#N` fallback routes artifacts to wrong issue when no `Closes/Fixes/Resolves` — `.agent/scripts/cross_model_review.sh:199-202`
- `GH_REPO_SLUG` extraction brittle for SSH aliases / Enterprise GitHub — `.agent/scripts/cross_model_review.sh:149`

## External Review
**Status**: complete
**When**: 2026-04-19
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #148 — 1 review (Copilot), 3 valid, 0 false positives
**CI**: all 6 checks pass

### Actions
- [ ] Reject leading-`-` values in `--work-plans-dir` (+ apply to `--pr`, `--agent`) — `.agent/scripts/cross_model_review.sh:~99-132`
- [ ] Use distinct exit code (4) for wrong-worktree; update script header doc — `.agent/scripts/cross_model_review.sh:36,235`
- [ ] Update helper header to reflect override returned verbatim (may be relative) — `.agent/scripts/_resolve_work_plans_dir.sh:9-14`
