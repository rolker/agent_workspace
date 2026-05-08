---
issue: 180
---

# Issue #180 — Slash command shim that wraps worktree_create.sh + native EnterWorktree

## Local Review
**Status**: complete
**When**: 2026-05-08 04:55
**By**: Claude Code Agent (claude-opus-4-7)
**Verdict**: changes-requested

**PR**: #182 at `3908be3`
**Depth**: Standard (reason: governance files — `CLAUDE.md` and new `SKILL.md`)
**Must-fix**: 4 | **Suggestions**: 3

### Findings
- [ ] (must-fix) `worktree_enter.sh` "not found" error goes to stdout, not stderr; SKILL `2>/dev/null` claim is false — `.agent/scripts/worktree_enter.sh:226-231`
- [ ] (must-fix) Pre-redirect parse errors leak to stdout in `--print-path-only` mode (4+ paths) — `.agent/scripts/worktree_create.sh:69-145`
- [ ] (must-fix) "Already in worktree" check uses loose substring match; misses legacy locations and false-positives on similarly-named dirs — `.claude/skills/start-task/SKILL.md:31-37`
- [ ] (must-fix) Relative `.agent/scripts/...` paths require repo-root CWD; fails from subdirectories — `.claude/skills/start-task/SKILL.md:44-48`
- [ ] (suggestion) `$ARGUMENTS` interpolation is unquoted — values with spaces or shell metacharacters break — `.claude/skills/start-task/SKILL.md:25,44`
- [ ] (suggestion) No recovery instruction if `EnterWorktree` fails after creation succeeds — `.claude/skills/start-task/SKILL.md:71-79`
- [ ] (suggestion) `set -e` mid-script failure leaves dangling worktree with no recovery hint — `.agent/scripts/worktree_create.sh:19,145`

### Notes
- All 4 must-fix items independently corroborated by Copilot bot review on the PR.
- CI: 8/8 green. Static analysis (pre-commit shellcheck) passed during commit.
- Per AGENTS.md "fix completely" standard, all 4 must-fix items are in scope for this PR (no follow-up).
