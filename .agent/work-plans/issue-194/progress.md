---
issue: 194
---

# Issue #194 — worktree_enter.sh: route Unknown-option (and other arg-validation) errors to stderr

## Issue Review
**Status**: complete
**When**: 2026-09-21 08:29 -0400
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #194

### Scope Assessment

**Well-scoped?** Yes — a single script (`worktree_enter.sh`), one behavioral axis (stderr routing), no interface or semantic changes. Diff should be small and easily reviewable in one PR.

**Right repo?** Yes — `worktree_enter.sh` is workspace infrastructure (`.agent/scripts/`), not project content.

**Dependencies**: None blocking. Builds on the precedent set by PR #180 (commit d7d8fa8) for the not-found-issue/skill paths. PR #192's SKILL.md caveat is the reason this surfaced and is the intended follow-up once this lands.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | Action needed | No test file exists for `worktree_enter.sh` in `.agent/scripts/tests/` (confirmed: none of the 24 current `test_*.sh` files touch it). The acceptance criteria are manual repro commands (`2>/dev/null` + eyeball), not automated regression coverage. A stream-routing regression is exactly the kind of thing that silently regresses again without a test. |
| A change includes its consequences | Watch | The issue already scopes in the `start-task/SKILL.md` caveat removal (acceptance criterion 3) — good. Confirm the PR diff actually includes that edit rather than deferring it as a separate follow-up issue. |
| Enforcement over documentation | OK | Pure code-level fix (stream routing); no new rule being documented without enforcement. |
| Only what's needed | OK | Scope is explicitly bounded — `worktree_create.sh` and any behavioral/exit-code changes are called out as out of scope. |
| Improve incrementally | OK | Small, reviewable, non-breaking change. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0012 — Worktree composition is an adapter concern | No | This touches `worktree_enter.sh`'s argument-parsing error output only, not multi-repo composition logic or the `.worktree-repos` manifest. No adapter-verb concerns here. |
| Others | No | No ADR in the applicability table governs output-stream routing specifically. |

### Consequences

- Confirm the `start-task/SKILL.md` caveat edit (acceptance criterion 3) lands in the same PR, not deferred.
- No `AGENTS.md`/`WORKTREE_GUIDE.md` updates expected — this doesn't change worktree usage or interface, only which fd carries error text.

### Recommendations

- Add a regression test in `.agent/scripts/tests/` (e.g. `test_worktree_enter_stderr.sh`) that sources or execs `worktree_enter.sh` with each corrected error path (at minimum: unknown option, missing `--skill` name, mutually-exclusive `--issue`/`--skill`, missing `--type`) under `2>/dev/null` and asserts empty stdout, matching the acceptance criteria's manual repro but automated so it can't silently regress.
- While auditing, verify the `--skill` missing-name error at (current) line 74 and the mutual-exclusivity/required-option errors around (current) lines 125–148 — these are additional un-routed `echo "Error: ..."` calls found during this review beyond the two lines the issue text calls out by number, though the issue's own acceptance criteria ("All `Error: ...` messages ... route to stderr") already cover them by intent.

### Actions
- [ ] No test file exists for `worktree_enter.sh` in `.agent/scripts/tests/` (confirmed: none of the 24 current `test_*.sh` files touch it). The acceptance criteria are manual repro commands (`2>/dev/null` + eyeball), not automated regression coverage. A stream-routing regression is exactly the kind of thing that silently regresses again without a test.
- [ ] Add a regression test in `.agent/scripts/tests/` (e.g. `test_worktree_enter_stderr.sh`) that sources or execs `worktree_enter.sh` with each corrected error path (at minimum: unknown option, missing `--skill` name, mutually-exclusive `--issue`/`--skill`, missing `--type`) under `2>/dev/null` and asserts empty stdout, matching the acceptance criteria's manual repro but automated so it can't silently regress.
- [ ] While auditing, verify the `--skill` missing-name error at (current) line 74 and the mutual-exclusivity/required-option errors around (current) lines 125–148 — these are additional un-routed `echo "Error: ..."` calls found during this review beyond the two lines the issue text calls out by number, though the issue's own acceptance criteria ("All `Error: ...` messages ... route to stderr") already cover them by intent.

## Checkpoint
**Status**: complete
**When**: 2026-09-21 08:33 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed to planning (Recommended) — the three Issue Review action items (regression test for every error path under 2>/dev/null; cover unknown option, missing --skill name, exclusive --issue/--skill, missing --type; route the line-74 and 125–148 errors too) carry into the plan.
