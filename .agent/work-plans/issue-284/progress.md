---
issue: 284
---

# Issue #284 — merge_pr.sh: gate record push moves the PR head after the CI wait; retries duplicate the Merge entry

## Plan Authored
**Status**: complete
**When**: 2026-09-18 09:00 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-284/plan.md` at `ac7d040`

Keep server-side protection; wait for CI on the reviewed head via a SHA-targeted check-runs poll (fixes #271), exempt a progress.md-only record commit from a second CI round, and make the Merge record idempotent per PR.
