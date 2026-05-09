---
issue: 3
---

# Issue #3 — Add branch mode to /review-code (local pre-push self-review)

## Plan
**Status**: complete
**When**: 2026-05-09 11:44
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-3/plan.md`.

Add `--branch [<base>]` to `/review-code` and `cross_model_review.sh` so the
existing review pipeline can run on a local branch diff before the PR exists.
Five architectural decisions surfaced as Open Questions for approval before
implement.

## Plan Review
**Status**: complete
**When**: 2026-05-09 11:50
**By**: Claude Code Agent (claude-opus-4-7) + Roland

Walked five architectural decisions one at a time with concrete previews.
Outcomes (see plan.md `## Decisions` for detail):

1. Default base ref: dynamic resolution via new `_resolve_default_branch.sh`
   helper; manifest hook reserved for #172 landing.
2. Static analysis: on by default in both modes, `--skip-static` toggle.
3. Branch parse failure: hard error + `--no-progress` opt-in.
4. `--pr` + `--branch`: mutually exclusive.
5. Self-test: same PR.

Plan refined: helper file added (5 files instead of 4); flag surface
table added; estimated scope bumped to ~300 LOC.
