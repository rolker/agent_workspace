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

## Plan Authored
**Status**: complete
**When**: 2026-09-21 08:36 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-194/plan.md` at `dddd51e`

Route every un-routed `Error: ...` echo in `worktree_enter.sh` (lines 74, 106, 125, 130, 135, 140, 144, 148, 365, 383) to stderr with `>&2`, no behavioral change beyond stream routing; add a new regression test (`test_worktree_enter_stderr.sh`) covering unknown option, missing `--skill` name, mutually-exclusive `--issue`/`--skill`, and missing `--type` (plus the remaining un-routed paths) under `2>/dev/null` asserting empty stdout; and remove the now-stale stdout-leak caveat at `start-task/SKILL.md` line 70.

## Plan Review
**Status**: complete
**When**: 2026-09-21 08:38 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #194 — worktree_enter.sh: route Unknown-option (and other arg-validation) errors to stderr
**Plan**: `.agent/work-plans/issue-194/plan.md` at `dddd51e`
**Branch**: `feature/issue-194`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One script edit, one new test file, one doc line. Single PR, well bounded; `worktree_create.sh` correctly left out. |
| Issue alignment | Concern | The plan's explicit decision to leave `show_usage` on stdout defeats acceptance criterion 1 — five of the ten error paths call `show_usage` immediately after the error echo, so the issue's own repro command still produces stdout. See finding 1. |
| File targeting | Good | The ten un-routed `Error:` lines (74, 106, 125, 130, 135, 140, 144, 148, 365, 383) match the file at this revision exactly; lines 171/203/234/285 are already routed, as claimed. Verified by reading `worktree_enter.sh`. |
| Consequences | Good | SKILL.md caveat removal is in scope (step 4), regression test is in scope (step 2), test-runner registration is asked about (step 2) — see finding 2 for the answer. |
| Principle alignment | Needs work | "Test what breaks" is well served by step 2, but the planned assertion ("stdout is empty") would fail against the plan's own step 1 as written — the fix and the test contradict each other. |
| ADR compliance | Good | ADR-0012 correctly marked not triggered — no composition/manifest/adapter surface is touched. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Approach / Issue alignment — must-fix]** Step 1 says `show_usage()` stays on stdout, but lines 75, 107, 126, 131 and 136 call `show_usage` immediately after the error echo on the unknown-option, missing-`--skill`-name, mutually-exclusive, either/or-missing and missing-`--type` paths. With only the `echo "Error: ..."` lines redirected, the issue's repro (`worktree_enter.sh --foo bar --print-path 2>/dev/null`) still prints the entire 18-line usage block to stdout, acceptance criterion 1 still fails, `/start-task`'s `WT=$(... 2>/dev/null)` still captures usage text into `$WT`, and step 2's planned assertion "stdout is empty" fails against the plan's own step 1. Resolution: route `show_usage` at the *error* call sites (`show_usage >&2`, or a `show_usage_err()` wrapper), while keeping the `-h|--help` path (line 102) on stdout with exit 0 — that is the conventional split and preserves help behaviour. The plan should state that split explicitly rather than leaving `show_usage` untouched.

2. **[File targeting — suggestion]** Step 2's open question ("register the new file in `run_script_tests.sh`'s discovery if that script requires explicit registration — verify") is already answerable: `run_script_tests.sh` globs `"$TESTS_DIR"/test_*.sh` (lines 66–68) and invokes each with `bash "$s"` (line 103), so a new `test_worktree_enter_stderr.sh` is auto-discovered and needs neither registration nor an exec bit. Replace the conditional with that statement so implementation doesn't re-derive it.

3. **[Consequences — suggestion]** Step 2 enumerates test coverage for the eight argument-validation paths but not for lines 365/366 (the "must be sourced" error) or 383 (failed `cd`). Line 365 is cheap to cover — run the script non-sourced with a valid `--issue`/`--type` and no `--print-path`/`--shell-snippet`, assert empty stdout and exit 1. Line 383 is impractical to trigger and can be left to the code change alone; say so explicitly so the gap is deliberate.

4. **[Consequences — suggestion]** Step 4 removes only the second sentence of `start-task/SKILL.md` line 70. The first sentence ("error text from the *not found* path goes to stderr") is also narrower than the post-fix reality; generalise it to "error text from `worktree_enter.sh`'s failure paths goes to stderr" so the doc states the invariant the new test now enforces, rather than one instance of it.

5. **[Principle alignment — suggestion]** Nothing in the plan pins the invariant against future additions: a new `echo "Error: ..."` added to `worktree_enter.sh` later would not be caught by per-path tests. Consider one extra assertion in the new test file — grep the script for `echo "Error:` lines lacking `>&2` and fail if any are found — which converts the per-path checks into an enforced rule (workspace principle: enforcement over documentation). Cheap, and it is precisely the regression class that produced this issue after PR #180.

### Summary

The plan's diagnosis, line inventory and file targeting are accurate and verified against the source. One structural problem blocks it: the decision to leave `show_usage` on stdout means the fix as planned does not satisfy the issue's headline acceptance criterion and contradicts the plan's own test assertion. Fix that call-site routing (keeping `--help` on stdout) and the rest is ready.

### Recommended Actions

- [ ] Route `show_usage` to stderr at the five error call sites (lines 75, 107, 126, 131, 136), keeping `-h|--help` usage on stdout with exit 0; update step 1 of the plan to say so.
- [ ] Replace step 2's "if that script requires explicit registration" conditional with the verified fact: `run_script_tests.sh` auto-globs `test_*.sh` and runs each via `bash`, so no registration or exec bit is needed.
- [ ] Add a test case for the non-sourced "must be sourced" path (lines 365–366); state explicitly that line 383's failed-`cd` path is covered by code change only.
- [ ] Generalise `start-task/SKILL.md` line 70's first sentence to cover all failure paths, not just "not found".
- [ ] Consider an invariant assertion in the new test file: no `echo "Error:` in `worktree_enter.sh` without `>&2`.

## Checkpoint
**Status**: complete
**When**: 2026-09-21 08:42 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise the plan — fold in the must-fix (show_usage >&2 at the error call sites; -h/--help stays on stdout, exit 0) and the four suggestions (test auto-discovery stated; cover line 365, declare 383 deliberately untested; generalise start-task SKILL.md line 70; grep-assert no un-routed `echo "Error:`). Owner note on the dialog itself: make checkpoint questions easier to read, not an unformatted block of text.
