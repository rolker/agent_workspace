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

## Plan Authored
**Status**: complete
**When**: 2026-09-21 08:45 -0400
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-194/plan.md` at `6f0df98`

Revised plan per Plan Review verdict needs-work: routes `show_usage` to stderr at the five error call sites (lines 75, 107, 126, 131, 136) while keeping `-h|--help` on stdout with exit 0; states `run_script_tests.sh`'s auto-glob discovery as verified fact; adds test coverage for the line-365 non-sourced error while explicitly declaring line-383's failed-cd path deliberately untested; generalises the `start-task/SKILL.md` line-70 invariant to cover all failure paths, not just "not found"; and adds a grep-based invariant assertion in the new test file so any future un-routed `echo "Error:` line fails the suite.

## Plan Review
**Status**: complete
**When**: 2026-09-21 08:47 -0400
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: ready

**Issue**: #194 — worktree_enter.sh: route Unknown-option (and other arg-validation) errors to stderr
**Plan**: `.agent/work-plans/issue-194/plan.md` at `6f0df98`
**Branch**: `feature/issue-194`
**Round**: 2 (revision of `dddd51e`, reviewed needs-work)

### Round-1 finding verification

| # | Round-1 finding | Status in `6f0df98` |
|---|---|---|
| 1 | must-fix — `show_usage` leaks to stdout on five error paths | **Resolved.** Step 1 now requires `show_usage >&2` (or a `show_usage_err()` wrapper) at lines 75, 107, 126, 131, 136 and states the `-h\|--help` split (line 102 stays stdout, exit 0). Verified against source: those are exactly the five error-path `show_usage` calls, and 102 is the only help one. |
| 2 | suggestion — state `run_script_tests.sh` discovery as fact | **Resolved.** Step 2 states the auto-glob and cites lines 66–68/103. Verified: `shopt -s nullglob; suites=("$TESTS_DIR"/test_*.sh)` and `bash "$s"` — no registration or exec bit needed. |
| 3 | suggestion — cover line 365, declare 383 untested | **Resolved in text** (step 2 adds the non-sourced case and explicitly declares 383 code-change-only). See finding 1 below for a gap in how the 365 case is asserted. |
| 4 | suggestion — generalise SKILL.md line 70's first sentence | **Resolved.** Step 4 now replaces both sentences and drops the `#194` reference. Verified the quoted current text matches `.claude/skills/start-task/SKILL.md` line 70 verbatim. |
| 5 | suggestion — grep invariant against future un-routed errors | **Resolved in text** (step 2, plus a Principles Self-Check row). See finding 2 for a coverage gap in the proposed pattern. |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged from round 1: one script edit, one new test file, one doc line. Well bounded. |
| Issue alignment | Good | With `show_usage >&2` folded in, the issue's repro (`--foo bar --print-path 2>/dev/null`) now yields empty stdout under the plan as written. Acceptance criteria 1–3 all covered. |
| File targeting | Good | Re-verified the full inventory against the file at this revision: un-routed `echo "Error:` at 74, 106, 125, 130, 135, 140, 144, 148, 365, 383 (10, as claimed); 171, 203, 234, 285 already `>&2`. Follow-up line 366 is in the inventory table. |
| Consequences | Good | SKILL.md, regression test, and runner discovery all accounted for. |
| Principle alignment | Good | "Test what breaks" and "enforcement over documentation" both now have concrete mechanisms; the fix and the test no longer contradict each other. |
| ADR compliance | Good | ADR-0012 correctly not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences — suggestion]** The planned line-365 test asserts only "empty stdout, non-zero exit" from `bash worktree_enter.sh --issue <valid> --type <valid>`. That assertion does not discriminate: when no worktree exists for the chosen issue (a fresh clone, CI, or any tree where that worktree was removed), the script exits at line 285's not-found path — also empty stdout, also exit 1 — and the test passes without ever reaching line 365. Run from inside this worktree it happens to reach 365 only because `git rev-parse --show-toplevel` basename matches `issue-*-194` (lines 253–259). Resolution: assert stderr matches `must be sourced`, and stage the precondition deterministically — e.g. `git init` a temp dir at `<tmp>/worktrees/workspace/issue-workspace-<N>` and run the script with that as cwd so the lines 253–259 branch resolves — rather than relying on the ambient worktree layout.

2. **[Principle alignment — suggestion]** The grep invariant as specified (`echo "Error:` lines lacking `>&2`) would not catch the exact regression class round 1 found: a `show_usage` call left on stdout at an error site, or a non-`Error:`-prefixed follow-up `echo` on an error path (line 366 is one such line today). Resolution: extend the invariant to also assert that every `show_usage` call other than the `-h|--help` one carries `>&2`, so the rule the fix establishes is the rule the suite enforces.

3. **[Approach — suggestion]** Step 1's instruction reads "add `>&2` to each `echo \"Error: ...\"` line listed above"; line 366 (`Use --print-path or --shell-snippet when running it as a command.`) is not `Error:`-prefixed and appears only parenthetically in the Context table. It must be routed too or the "must be sourced" path still leaks one line to stdout. Name it explicitly in step 1 and in the Files-to-Change row so implementation does not have to infer it from the test failure.

### Summary

The round-1 must-fix is genuinely resolved in the plan text, not merely claimed, and all four suggestions were folded in; the line inventory and call-site line numbers re-verify exactly against the source at this revision. The three remaining items are refinements to the new test and invariant, none blocking. Ready for implementation.

### Recommended Actions

- [ ] Make the line-365 test discriminate the path it claims to test (assert stderr contains "must be sourced" and stage the worktree precondition deterministically).
- [ ] Extend the grep invariant to cover `show_usage` at error call sites, not just `echo "Error:` lines.
- [ ] Name line 366 explicitly in step 1 / Files-to-Change as one of the lines to route.

## Checkpoint
**Status**: complete
**When**: 2026-09-21 08:50 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed, apply the 3 suggestions — implement inline, folding in the round-2 suggestions: (1) line-365 test asserts stderr matches "must be sourced" from a staged worktree-named temp dir; (2) grep invariant also covers show_usage calls other than -h/--help; (3) line 366 routed explicitly.

## Implementation
**Status**: complete
**When**: 2026-09-21 08:59 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-194/plan.md` at `6f0df98`
**Branch**: `feature/issue-194` at `34c8d1b`
**Mode**: inline

Plan implemented as written plus the three round-2 review-plan suggestions (34c8d1b): ten `echo "Error:"` lines and the five error-path `show_usage` calls in `worktree_enter.sh` routed to stderr (`-h/--help` stays on stdout, exit 0); new `test_worktree_enter_stderr.sh` — 13 tests / 35 assertions covering every argument-validation path, the usage-on-error and help-on-stdout split, the "must be sourced" path from a staged worktree-shaped sandbox asserting on stderr text, and two grep invariants (no un-routed `Error:` echo; only the `-h|--help` `show_usage` lacks `>&2`); start-task SKILL.md line 70 states the invariant. Full suite 23/23; issue repro `--foo bar --print-path 2>/dev/null` prints nothing. Line 383 (failed cd) routed but deliberately untested, per plan.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-21 09:05 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-194 at `202999e`
**Base**: main
**Depth**: Standard (reason: enforcement-adjacent `.agent/scripts/` + skill doc change, 4 files)
**Must-fix**: 1 | **Suggestions**: 2
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) `test_must_be_sourced` reaches the sourced-check through the issue-title lookup, so every suite run does a live `git bug bridge pull github` + `gh issue view 999999` against the real repo and mutates shared local git-bug state — `.agent/scripts/tests/test_worktree_enter_stderr.sh:145`
- [x] (suggestion) The `echo "Error:` invariant is a literal-substring grep; a future `printf "Error: ..."` or differently-worded error message evades it — `.agent/scripts/tests/test_worktree_enter_stderr.sh:171`
- [x] (suggestion) Pre-existing: a dangling option value (`--issue`, `--type`, `--project`, `--repo-slug` as the last argument) makes `shift 2` fail and the parse loop spin forever; confirmed by timeout. Out of this plan's scope — warrants its own issue — `.agent/scripts/worktree_enter.sh:66` (deferred: pre-existing arg-parsing bug, out of this PR's scope; needs its own issue)

## Implementation
**Status**: complete
**When**: 2026-09-21 09:12 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-194 at `eef8fb6`
**Addressed**: Local Review (Pre-Push) at `202999e` (2026-09-21 09:05 -04:00)
**Commits**: eef8fb6

### Actions
- [x] (must-fix) `test_must_be_sourced` made a live `gh issue view` call and could fire `git bug bridge pull github` on every suite run — `.agent/scripts/tests/test_worktree_enter_stderr.sh:145`. Fixed: the two invocations that reach the sourced-check now run with `gh` and `git-bug` shadowed by inert logging stubs on PATH. Both lookup entry points in `_issue_helpers.sh: issue_lookup` are gated on `command -v`, and `git bug …` dispatches through `git-bug` on PATH, so the lookup finds nothing, writes nothing, and still falls through to the path under test. The suite asserts the stubs were the ones consulted. Verified: the stub log for a run records `git-bug bug -m …`, `git-bug bridge`, `gh issue view 999999 …` and nothing else — `git-bug bridge` returns empty, so `has_bridge` is 0 and no `bridge pull github` is attempted; the workspace's `refs/bugs/**` hashes are byte-identical before and after a suite run.
- [x] (suggestion) The `echo "Error:` invariant was a literal-substring grep — `.agent/scripts/tests/test_worktree_enter_stderr.sh:171`. Broadened to `grep -nE '(echo|printf)[[:space:]].*Error:'`, so a future `printf "Error: …"` (either quoting style) is covered. Still reports zero un-routed emitters against the current script.
- [x] (suggestion) Dangling option value makes `shift 2` fail and the parse loop spin forever — `.agent/scripts/worktree_enter.sh:66` (deferred: pre-existing arg-parsing bug, out of this PR's scope; needs its own issue — the host will open it)

### Verification
- `bash .agent/scripts/tests/test_worktree_enter_stderr.sh` — 36 passed, 0 failed
- Pre-commit on the fix commit: all hooks passed, including the full `.agent/scripts/tests/` suite and shellcheck

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-21 09:25 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-194 at `704d7e9`
**Base**: main
**Depth**: Standard (reason: enforcement-adjacent `.agent/scripts/tests/` change; round-2 re-verification of a state-mutation finding)
**Must-fix**: 0 | **Suggestions**: 3
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: delta `34c8d1b..eef8fb6` plus verification that each round-1 item is genuinely resolved. Verified by execution, not by reading: the suite run under `strace` shows 36 passed / 0 failed and zero `execve` of the real `/usr/bin/gh` or `/usr/local/bin/git-bug` — only the sandbox stubs (4x `git-bug`, 2x `gh`); `refs/bugs` + `refs/identities` hashes are byte-identical before and after; `git bug bridge` returns empty so `has_bridge` is 0 and no `bridge pull github` is attempted. Working tree clean afterwards and no `/tmp` sandbox leak. `pre-commit` on the changed file passes (shellcheck included). The broadened invariant grep was probed against a deliberately un-routed `printf 'Error: %s\n'` line and catches it. The deferred round-1 item is tracked as open issue #298 with a matching title.

### Findings
- [x] (suggestion) The stub-log assertion's `command -v` guard and its comment are inaccurate — the stubs are on PATH during the run, so the script's own `command -v` always succeeds and the log is always non-empty; the guard needlessly skips a valid assertion where the real tools are absent — `.agent/scripts/tests/test_worktree_enter_stderr.sh:196`
- [x] (suggestion) The invariant grep is line-scoped and unanchored: a correctly-routed `{ echo "Error: ..."; ... } >&2` block, a line-continued `printf`, or a comment containing both tokens would report as un-routed; worth a one-line note of the assumption — `.agent/scripts/tests/test_worktree_enter_stderr.sh:217`
- [ ] (suggestion) Stub isolation is scoped to `test_must_be_sourced` only; hoisting `make_offline_stubs` + the PATH override to suite level would make the offline guarantee structural, since this leak class already bit once — `.agent/scripts/tests/test_worktree_enter_stderr.sh:180`

## Checkpoint
**Status**: complete
**When**: 2026-09-21 09:27 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: publish
**Decision**: address

Address the 3 suggestions first — drop the dead `command -v` guard on the stub-log assertion; note the line-scoped grep assumption; hoist the gh/git-bug stubs + PATH override to suite level so the offline guarantee is structural. Then re-review before publishing.
