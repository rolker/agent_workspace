---
issue: 141
---

# Issue #141 — Auto-update roadmap status at merge time in merge_pr.sh

## Plan
**Status**: complete
**When**: 2026-04-05 22:30
**By**: Claude Code Agent (claude-opus-4-6)

Plan file: `.agent/work-plans/issue-141/plan.md`.

Replace the passive roadmap reminder in merge_pr.sh with a new `update_roadmap.sh` helper that auto-updates roadmap entries using explicit `#N` matching before merging. Opt-out via `--no-roadmap-update` flag.
