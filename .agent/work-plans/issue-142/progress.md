---
issue: 142
---

# Issue #142 — Scripts and skills bypass git-bug for issue reads (ADR-0010 compliance)

## Plan
**Status**: complete
**When**: 2026-04-05 23:30
**By**: Claude Code Agent (claude-opus-4-6)

Plan file: `.agent/work-plans/issue-142/plan.md`.

Create a shared `_issue_helpers.sh` with sync-on-miss reads (git-bug first,
pull on cache miss, fall back to gh). Refactor existing callers (including
fixing broken `git bug select` invocations in worktree_create.sh) and update
non-compliant scripts and skill instructions. Document the canonical pattern
in AGENTS.md and append sync strategy to ADR-0010.

## Plan update
**Status**: complete
**When**: 2026-04-05 23:50
**By**: Claude Code Agent (claude-opus-4-6)

Major plan revision after discovering:
1. `git bug select` doesn't exist in v0.10.1 — existing "compliant" code is
   broken (silently falls back to gh every time)
2. Correct invocation is `git bug bug select/show/etc.`
3. GitHub issue number lookup requires metadata filter:
   `git bug bug -m "github-url=https://github.com/OWNER/REPO/issues/N"`
4. Switched from text parsing to JSON output (`--format json`) since the
   metadata lookup inherently needs structured parsing
