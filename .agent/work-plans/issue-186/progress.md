---
issue: 186
---

# Issue #186 — Replace gh pr checks --watch busy-poll with native Monitor in merge flows

## Plan
**Status**: complete
**When**: 2026-05-09 14:55
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-186/plan.md`.

The issue's title implies "swap busy-poll for `Monitor`", but `Monitor` is
a Claude Code SDK tool that bash can't invoke — so the script-side
(`merge_pr.sh`) and agent-side (knowledge doc / future slash command)
surfaces need different mechanisms. Plan recommends doing both:
script-side `gh pr checks --watch` insertion to fix the manual-second-
invocation pain for everyone, plus a knowledge doc for the agent-side
`Monitor` pattern. Three Open Questions surfaced for approval before
implement.
