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
- [x] (must-fix) `worktree_enter.sh` "not found" error goes to stdout, not stderr; SKILL `2>/dev/null` claim is false — `.agent/scripts/worktree_enter.sh:226-231`
- [x] (must-fix) Pre-redirect parse errors leak to stdout in `--print-path-only` mode (4+ paths) — `.agent/scripts/worktree_create.sh:69-145`
- [x] (must-fix) "Already in worktree" check uses loose substring match; misses legacy locations and false-positives on similarly-named dirs — `.claude/skills/start-task/SKILL.md:31-37`
- [x] (must-fix) Relative `.agent/scripts/...` paths require repo-root CWD; fails from subdirectories — `.claude/skills/start-task/SKILL.md:44-48`
- [x] (suggestion) `$ARGUMENTS` interpolation is unquoted — values with spaces or shell metacharacters break — `.claude/skills/start-task/SKILL.md:25,44`
- [x] (suggestion) No recovery instruction if `EnterWorktree` fails after creation succeeds — `.claude/skills/start-task/SKILL.md:71-79`
- [x] (suggestion) `set -e` mid-script failure leaves dangling worktree with no recovery hint — `.agent/scripts/worktree_create.sh:19,145`

### Notes
- All 4 must-fix items independently corroborated by Copilot bot review on the PR.
- CI: 8/8 green. Static analysis (pre-commit shellcheck) passed during commit.
- Per AGENTS.md "fix completely" standard, all 4 must-fix items are in scope for this PR (no follow-up).

## Review Fixes
**Status**: complete
**When**: 2026-05-08 05:15
**By**: Claude Code Agent (claude-opus-4-7)

All 4 must-fix and 3 suggestion-tier findings addressed across 3 atomic commits:

- `fix(worktree_enter): route not-found errors to stderr` (`d7d8fa8`)
  → resolves must-fix #1
- `fix(worktree_create): pre-scan for --print-path-only to suppress parse-time stdout` (`93ca991`)
  → resolves must-fix #2 (verified: all 4 parse-time error paths now stderr-only)
- `fix(skills/start-task): harden detection, paths, and recovery` (`cc23db5`)
  → resolves must-fix #3 (git-native worktree detection), must-fix #4 (cd to repo root),
    suggestion #1 (`"$ARGUMENTS"` quoting + metachar refusal), suggestion #2
    (EnterWorktree-fail recovery), suggestion #3 (set-e dangling worktree hint),
    plus nits (stray echo, --repo-vs-repo-slug mismatch, line-59 comment)

## External Review
**Status**: complete
**When**: 2026-05-09 14:30
**By**: Claude Code Agent (claude-opus-4-7)

**PR**: #182 — 1 review (Copilot bot, against `3908be3`), 4 inline comments, 0 valid, 0 false positives, 4 addressed
**CI**: all 4 checks pass on current head `5bf0fe0`

The Copilot review was submitted against the original feature commit
(`3908be3`) before the local-review fix commits landed. Verified each
of the 4 inline findings against the current head:

- `SKILL.md:35` (legacy paths in worktree-detection check) → addressed
  by `cc23db5` (now uses `git rev-parse --git-dir` vs `--git-common-dir`)
- `SKILL.md:48` (relative path needs cd to repo root) → addressed by
  `cc23db5` (Step 2 explicitly cds via `git rev-parse --show-toplevel`)
- `SKILL.md:62` (`2>/dev/null` doesn't suppress stdout message) →
  addressed by `d7d8fa8` (`worktree_enter.sh` routes not-found errors
  to stderr)
- `worktree_create.sh:148` (parse-time stdout leak) → addressed by
  `93ca991` (pre-scan for `--print-path-only` redirects fd 1→2 immediately)

### Actions
- [ ] (Optional) Dismiss the stale Copilot review on PR #182 — its findings are resolved.
- [ ] (Optional) Re-request Copilot review against `5bf0fe0` for a clean re-pass before merge.
- [ ] Merge when ready — CI green, Copilot findings resolved, local-review verdict approved.
