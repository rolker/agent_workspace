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

## Plan Review
**Status**: complete
**When**: 2026-05-09 15:25
**By**: Claude Code Agent (claude-opus-4-7) + Roland

Walked the three architectural decisions one at a time with concrete
previews. Outcomes (see plan.md `## Decisions` for detail):

1. Surface scope: **both** — script-side bash wait in `merge_pr.sh`
   plus new `agent_wait_patterns.md` knowledge doc.
2. Wait behaviour: **`--fail-fast`** — exit on first failed check, abort
   merge with clear context.
3. Smoke test: **documented manual verification** — ~5 LOC procedure
   in script header; automation declined as out-of-scope for #186.

Plan refined: Open Questions section replaced with Decisions; flag
surface table added showing the new `--no-wait` flag.
