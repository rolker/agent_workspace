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

## Implementation
**Status**: complete
**When**: 2026-04-06 00:45
**By**: Claude Code Agent (claude-opus-4-6)

Implemented per plan:
1. `update_roadmap.sh` — searches both roadmap formats (table + checklist)
   for explicit `#N` matches, updates status to done/checked. Supports --dry-run.
2. `merge_pr.sh` — added --no-roadmap-update flag, replaced step 5 roadmap
   reminder with pre-merge auto-update (new step 1). Commits and pushes
   roadmap changes to feature branch before merging. Failures non-blocking.
3. AGENTS.md script reference updated.
