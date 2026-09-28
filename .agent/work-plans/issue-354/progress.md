---
issue: 354
---

# Issue #354 — Pre-commit: run the script test suites only when a commit touches what they test (~133 s on every commit today)

## Issue Review
**Status**: complete
**When**: 2026-09-28 11:31 -0400
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #354

### Scope Assessment

**Well-scoped?** Yes — single, bounded change: add a `files:` regex to the
`validate-script-tests` pre-commit hook, following the existing
`validate-adapter-contract` pattern in the same file. The acceptance criteria
are concrete and checkable (regex coverage, docs-only skip, CI unaffected,
stale-cost text updated).

**Right repo?** Yes — `.pre-commit-config.yaml` and `.agent/scripts/tests/`
are workspace infrastructure, not project content.

**Dependencies**: None identified. Builds on #269 (which introduced the
always_run hook) but doesn't require any other open issue.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | OK | Narrows *when* the hook runs, doesn't remove it; CI (`make lint`) stays unconditional per ADR-0005's layering, so nothing is enforced only in docs. |
| Only what's needed | OK | Directly targets a measured, growing cost (10 suites/~18 s at #269 to 29 suites/~133 s today) rather than speculative tuning. |
| A change includes its consequences | Action needed | Issue names updating stale "~18 s" guidance but should also confirm no other doc/skill references the always-run cost or count (see below). |
| Test what breaks | Action needed | The acceptance criteria call for deriving the regex from what suites actually read, but the real risk — a future suite silently drifting outside the regex — needs its own regression test, not just careful derivation. Plan should name it explicitly. |
| Improve incrementally | OK | Small, reviewable, single-file-plus-tests change. |
| Workspace vs. project separation | OK | Pure workspace-infra change. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0004/0005 — Enforcement hierarchy / layered enforcement | Yes | Directly on point: local pre-commit is fast local feedback, CI is authoritative. Scoping the local hook while CI keeps running all suites is exactly the intended layering — issue already states this correctly. |
| ADR-0013 — progress.md entry-type vocabulary | Yes (process, not content) | Any progress.md entries this work produces must use canonical entry types via `review_progress.sh persist` / `progress_append.sh`. No effect on the fix itself. |
| Others (0001–0003, 0006–0012, 0014–0016) | No | Not a design-decision record, not adapter/project-type, not worktree/dispatch/session-root machinery. |

### Consequences

- Confirmed: no currently-live guidance doc (AGENTS.md, docs/roadmap.md,
  docs/design.md) states an "~18 s" or fixed suite-count figure for this
  hook — only the immutable issue-269 work-plan/progress history does,
  which is a historical record and shouldn't be rewritten. The issue's
  "update stale ~18 s guidance" acceptance item may therefore have no live
  target; the plan should confirm this rather than edit history.
- `.agent/scripts/tests/tests/test_pre_commit_config` or equivalent (none
  currently exists) — worth checking whether any script test already
  asserts on `.pre-commit-config.yaml` hook shape, since this change edits
  that shape.

### Recommendations

- In the plan, enumerate the path-family evidence per suite (script,
  skill/SKILL.md, template, adapter/project_type, Makefile, doc) rather
  than a single merged regex derivation, so a reviewer can check coverage
  claim-by-claim.
- Add a regression test asserting the `files:` regex matches every path
  referenced by the suites (e.g., derived from the same source list used
  to build the regex), so a new suite added later that reads outside the
  regex fails loudly instead of silently skipping.
- Verify the regex also covers `.pre-commit-config.yaml` itself and
  `Makefile`, since suites test hook/target wiring, not just script bodies.

### Actions
- [ ] Issue names updating stale "~18 s" guidance but should also confirm no other doc/skill references the always-run cost or count (see below).
- [ ] The acceptance criteria call for deriving the regex from what suites actually read, but the real risk — a future suite silently drifting outside the regex — needs its own regression test, not just careful derivation. Plan should name it explicitly.
- [ ] In the plan, enumerate the path-family evidence per suite (script, skill/SKILL.md, template, adapter/project_type, Makefile, doc) rather than a single merged regex derivation, so a reviewer can check coverage claim-by-claim.
- [ ] Add a regression test asserting the `files:` regex matches every path referenced by the suites (e.g., derived from the same source list used to build the regex), so a new suite added later that reads outside the regex fails loudly instead of silently skipping.
- [ ] Verify the regex also covers `.pre-commit-config.yaml` itself and `Makefile`, since suites test hook/target wiring, not just script bodies.

## Plan Authored
**Status**: complete
**When**: 2026-09-28 11:39 -0400
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-354/plan.md` at `ef453fd`

Scope the `validate-script-tests` pre-commit hook with a `files:` regex
(`^(\.agent/|\.claude/|AGENTS\.md$|Makefile$|\.pre-commit-config\.yaml$)`)
derived from every suite's real (non-sandbox) path reads, remove
`always_run: true`, and add a regression suite that parses the regex out
of `.pre-commit-config.yaml` and asserts it covers every real path any
other suite references — so a future suite reading outside the regex
fails loudly instead of silently skipping.
