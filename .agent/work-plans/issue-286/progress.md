---
issue: 286
---

# Issue #286 — merge_pr.sh gate: a review entry's own progress commit makes every review look stale

## Plan Authored
**Status**: complete
**When**: 2026-09-18 10:35 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-286/plan.md` at `313c126`

Extract the #284 ancestry + paths-only exemption into one helper and use it for gate condition (a), so a review followed only by its own progress.md commit (plus the run's roadmap commit) counts as at head.
