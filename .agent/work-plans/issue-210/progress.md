---
issue: 210
---

# Issue #210 — Workspace redesign foundation: 10-verb adapter contract + single_project adapter

## Plan
**Status**: complete
**When**: 2026-05-17 (UTC)
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-210/plan.md`.

Approach: build bottom-up — dispatcher → `single_project` adapter (10 verb facades) → config fields → validator → rewire `build`/`test`/`setup`/`sync` as dispatch shims → new `make install` → tests asserting delegation (not just exit code) → ADR-0011 superseding ADR-0003 in the same PR → AGENTS.md and review-guide cascade → validator wired to both pre-commit and CI → no-behavior-change verification on daddy_camp. Parent branch `feature/issue-172` was created off main as an empty integration branch so this PR can target it as the issue intends.
