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
pull on cache miss, fall back to gh). Refactor existing compliant scripts to
validate the helper, then update non-compliant scripts and skill instructions.
Document the canonical pattern in AGENTS.md and append sync strategy to ADR-0010.
