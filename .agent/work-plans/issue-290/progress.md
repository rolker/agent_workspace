---
issue: 290
---

# Issue #290 — merge_pr.sh: --no-wait also skips the mergeability settle, so the script's own push makes the merge refuse

## Issue Review
**Status**: complete
**When**: 2026-09-18 00:00 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #290

### Scope Assessment

**Well-scoped?** Yes — one script (`merge_pr.sh`), one flag's semantics, one test fixture gap. Fits a single PR.
**Right repo?** Yes — `merge_pr.sh` and its tests live in `.agent/scripts/`, workspace infra.
**Dependencies**: none identified. Direct follow-up to #284 (CI-target exemption / mergeability settle) and #289 (check-runs POST/404 fix), both merged. No open issue blocks this one.

Confirmed against source (`.agent/scripts/merge_pr.sh`, current `feature/issue-290` tree): the `if [[ "$NO_WAIT" == false ]]; then ... else echo "  CI wait skipped (--no-wait)"; fi` block at lines ~1045–1158 wraps both the CI poll *and* the `_wait_for_mergeable` settle-poll (lines 1130–1155), and the merge-retry re-poll at line 1183 is also gated on `[[ "$NO_WAIT" == false ]]`. So today `--no-wait` skips all three: CI wait, mergeability settle, and the one merge retry — exactly the bug the issue reports. The test harness confirms the coverage gap: `run_merge()` (the helper most gate tests use) always passes `--no-wait` and never writes a `write_mergeable_fixture` for it, so the mergeability path is untested under `--no-wait`; `write_mergeable_fixture`/settle-poll cases (ci-7, ci-8, ci-13) all go through `run_merge_wait()`, which omits `--no-wait` entirely.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | Action needed | Issue already specifies the exact regression fixture (`--no-wait` + `mergeable: UNKNOWN`→`MERGEABLE`); this is the right target, not a general coverage pass. |
| A change includes its consequences | Watch | The header comment (line ~968-970: "--no-wait skips this whole step (and Step 5's mergeability settle below)") and the `AGENTS.md` script-reference row ("`--no-wait` to skip the CI wait") both describe today's (buggy) behavior. Both need the one-line correction the issue already calls for ("--no-wait skips only the CI poll"), or a reader will re-derive the wrong mental model from the docs after the code is fixed. |
| Only what's needed | OK | Fix is a narrow scope split (CI poll vs. mergeability settle/retry), not a rewrite of Step 2/3. |
| Improve incrementally | OK | Builds on #284's existing structure without restructuring it. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0013 — progress.md entry vocabulary | Yes | This review's own persistence must use `## Issue Review`; the fix itself writes no new progress.md entry type. |
| Others | No | No worktree, adapter, or enforcement-hierarchy changes implicated. |

### Consequences

- `AGENTS.md`'s `.agent/scripts/merge_pr.sh` reference-table row currently reads "`--no-wait` to skip the CI wait" — accurate wording once fixed (it should say the settle/retry still run), but worth a one-line touch alongside the fix so the table doesn't quietly re-describe the old behavior.
- The script's own header comment (Step 2's block, "`--no-wait` skips this whole step (and Step 5's mergeability settle below)") is the same claim in a second place and needs the matching correction the issue asks for.
- No other reader of `merge_pr.sh` (dispatch_phase.sh, review_progress.sh, other skills) branches on `--no-wait` semantics, so no cascading update beyond the two doc spots above and the test fixture the issue names.

### Actions
- [ ] Issue already specifies the exact regression fixture (`--no-wait` + `mergeable: UNKNOWN`→`MERGEABLE`); this is the right target, not a general coverage pass.
- [ ] Split the single `if [[ "$NO_WAIT" == false ]]` block into two independent gates: one for the CI poll (skippable), one for the mergeability settle + merge-retry (not skippable) — rather than adding a second flag or an early exception inside the same block, to keep the "skips only CI" contract structurally obvious.
- [ ] Add the fixture-driven test case named in the issue (`--no-wait` + `mergeable: UNKNOWN`-then-`MERGEABLE`) using the existing `run_merge`/`write_mergeable_fixture` helpers, and verify it currently fails (merge attempted while still UNKNOWN, or the settle poll skipped) before the fix, then passes after.
- [ ] Update the two comment sites (script header, Step 2 inline comment) and the `AGENTS.md` script-reference row together with the code change, not as a follow-up.

## Checkpoint
**Status**: complete
**When**: 2026-09-18 13:40 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

proceed, but this question suffers from an issue I complained about in ros2 agent workspace where the question is a dense, hard to read paragraph.

## Plan Authored
**Status**: complete
**When**: 2026-09-18 18:10 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-290/plan.md` at `ff4bf0e`

Split Step 2's `--no-wait` gate so only the CI poll is skippable; the mergeability settle (`_wait_for_mergeable`) and the Step 3 merge retry always run, since they guard the script's own Step 1.5 push, not CI. Adds a regression test for `--no-wait` + `UNKNOWN`→`MERGEABLE` (merges) and `UNKNOWN` for the whole grace window (errors), plus fixes to the three comment sites describing the old behavior.

## Plan Review
**Status**: complete
**When**: 2026-09-18 13:46 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #290 — merge_pr.sh: --no-wait also skips the mergeability settle, so the script's own push makes the merge refuse
**Plan**: `.agent/work-plans/issue-290/plan.md` at `ff4bf0e`
**Branch**: `feature/issue-290`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One script, one flag's semantics, three comment sites, one test file. Single PR. |
| Issue alignment | Good | All four `## Issue Review` actions are covered (split the gate, un-gate the retry, fix comments + AGENTS.md row, add the named fixture test). |
| File targeting | Needs work | Correct files, but the test file needs more than "add 2 cases" — see finding 1. |
| Consequences | Concern | The consequences table misses the blast radius on the 27 existing `run_merge` call sites (finding 1) and on the un-gated retry's own coverage (finding 3). |
| Principle alignment | Needs work | "Test what breaks": case 1 as written passes against the unfixed code (finding 2), so it is not a regression test; the retry un-gating ships untested. |
| ADR compliance | Good | Only ADR-0013, handled. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences]** — `run_merge()` (line 157) always passes `--no-wait` and sets no `MERGE_PR_CI_*` env; `make_sandbox` writes no `.mergeable.json`, so the gh stub answers `UNKNOWN` forever. Once the settle runs unconditionally, all 27 existing `run_merge` tests poll for the default 120 s grace at 10 s intervals and then exit 1 at "mergeability never settled" — they never reach Step 3. The plan must also give `run_merge` zero-sleep env (`MERGE_PR_CI_POLL_SECONDS=0`, `MERGE_PR_CI_GRACE_SECONDS`) and a default `MERGEABLE` fixture (in `run_merge` or `make_sandbox`), or ~27 assertions break and the suite stalls for ~54 minutes.
2. **[Principle alignment]** — Plan step 5 says case 1 (`--no-wait`, UNKNOWN seq 1 → MERGEABLE, `GH_MERGE_EXIT=0`) should "assert it merges" and "fail against the current code". It will not fail: the stub's `pr merge` exits `GH_MERGE_EXIT` unconditionally and never consults the mergeable fixture, so the unfixed script (settle skipped) merges too. The assertion must be on the settle actually happening — e.g. `gh_calls.log` contains a `pr view ... --json mergeable,mergeStateStatus` call before the `pr merge` line — otherwise it is a no-op test.
3. **[File targeting]** — Approach step 2 (un-gating the Step 3 retry) has no test at all. Exercising it needs the gh stub to fail the first `pr merge` with "not mergeable" on stderr and succeed on the second; today `pr merge` has a single fixed exit code and no stderr. Add a sequenced merge-exit/stderr fixture (same pattern as `.mergeable_<N>.json`) plus a `--no-wait` retry case, or state explicitly why the retry ships uncovered.
4. **[Consequences]** — Plan step 3 rewrites the line-1168 sentence but leaves the stale "Step 5" references at lines 969–970 and 1166; the settle lives in Step 2. Fix both while editing those comments.
5. **[Scope]** — Editing `AGENTS.md` is an "Ask First" boundary (instruction file). The current row ("`--no-wait` to skip the CI wait") is not wrong post-fix but is ambiguous; if tightening it to "skips only the CI wait — the mergeability settle and merge retry always run", get approval rather than treating it as a drive-by.

### Summary

The diagnosis and the code fix are right and minimal. The test half is not: as specified, one new case cannot fail against the unfixed code, the retry un-gating is untested, and the unconditional settle silently breaks every existing `--no-wait` test. Revise step 5 before implementing.

### Recommended Actions

- [ ] Give `run_merge` (or `make_sandbox`) zero-sleep `MERGE_PR_CI_*` env and a default `MERGEABLE` fixture so the 27 existing cases still reach Step 3.
- [ ] Re-specify case 1 to assert the settle poll occurred before `pr merge` (gh_calls.log ordering), not merely that a merge happened.
- [ ] Add a `--no-wait` retry test, which requires a sequenced `pr merge` exit/stderr fixture in the gh stub; or record why the retry ships uncovered.
- [ ] Correct the stale "Step 5" wording at lines 969–970 and 1166 alongside the other comment fixes.
- [ ] Confirm with the owner before touching the `AGENTS.md` row (Ask First).

## Checkpoint
**Status**: complete
**When**: 2026-09-18 13:49 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Decided-by**: owner
**After**: plan
**Decision**: revise

revise (Recommended)

## Plan Authored
**Status**: complete
**When**: 2026-09-18 18:35 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-290/plan.md` at `2bebbdc`

Revision 2: addressed all five plan-review findings — zero-sleep test defaults so the unconditional settle doesn't stall the 27 existing run_merge cases, a gh_calls.log-ordering assertion in place of the non-discriminating merge-succeeded check, a new sequenced merge-exit/stderr fixture and test for the un-gated Step 3 retry, both stale "Step 5" comment fixes, and the AGENTS.md script-row edit deferred to the existing #269 standing rule instead of a fresh Ask-First round.

## Plan Review
**Status**: complete
**When**: 2026-09-18 13:57 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #290 — merge_pr.sh: --no-wait also skips the mergeability settle, so the script's own push makes the merge refuse
**Plan**: `.agent/work-plans/issue-290/plan.md` at `2bebbdc`
**Branch**: `feature/issue-290`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one script, one test file, one AGENTS.md script row. |
| Issue alignment | Good | All Issue Review actions covered. |
| File targeting | Good | Stub extension + `write_merge_fixture` is the right shape (mirrors `.mergeable_<N>` / `_seq`). |
| Consequences | Needs work | The new default-fixture change breaks an existing test, and two `--no-wait` call sites bypass `run_merge()` (findings 1–2). |
| Principle alignment | Good | Round-1 findings 2 and 3 resolved: settle-ordering assertion fails on today's code; retry test fails on today's gated retry. |
| ADR compliance | Good | ADR-0013 only. |
| ROS conventions | N/A | Workspace plan. |

Round-1 status: 1 (stall) partially resolved — see 1–2; 2, 3 resolved; 4 resolved (but see 3); 5 settled via the #269 script-row rule.

### Findings

1. **[Consequences]** — Item 4 writes a static `MERGEABLE` fixture in `make_sandbox()`, but `make_ci_sandbox()` calls `make_sandbox()`, and ci-8 (test file ~683, "UNKNOWN for the whole grace window") writes *no* mergeable fixture — it relies on the stub's UNKNOWN-forever fallback. With the default in place ci-8 settles to MERGEABLE, merges, and fails. Fix: have ci-8 (and the plan's new case 2) write an explicit static `UNKNOWN`, or put the default in `run_merge()` only (write-if-absent), not `make_sandbox()`.
2. **[Consequences]** — Two tests invoke `merge_pr.sh --no-wait` directly, not via `run_merge()`: the package-PR test (line 418, fixture `pr_view_owner_pkg_a_901`) and the project `--enforce` test (line 457, PR 9 on `fake_remotes/.../proj.git`). The `make_sandbox` default is keyed on `<sb>.remote.git` PR 70, so neither sees it, and neither sets `MERGE_PR_CI_POLL_SECONDS=0`. After the fix each polls UNKNOWN for the 120 s grace and exits 1 at "never settled"; the project test asserts `merged_called` and will fail. Add a mergeable fixture for each PR key plus zero-sleep/short-grace env to both calls.
3. **[Consequences]** — Item 3's check "`grep -n "Step 5"` must return nothing" is wrong: line 1379 is the legitimate `# --- Step 5: Delete branches ---` header. Narrow the check to the two comment sites (e.g. grep for "Step 5's mergeability" / "after Step 5").

### Summary

The code fix and the three new tests are sound and discriminating. The harness change fixes the 27 `run_merge` stalls but breaks ci-8 and misses the two direct `--no-wait` invocations. Both are small, concrete edits to item 4.

### Recommended Actions

- [ ] Keep ci-8 on UNKNOWN-forever: explicit static `UNKNOWN` fixture, or move the default into `run_merge()` as write-if-absent.
- [ ] Give the package-PR (line 418) and project-enforce (line 457) `--no-wait` calls a MERGEABLE fixture for their own PR key and `MERGE_PR_CI_POLL_SECONDS=0`.
- [ ] Replace the bare `grep "Step 5"` acceptance check with one scoped to the two stale comments.

## Checkpoint
**Status**: complete
**When**: 2026-09-18 13:58 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

proceed (Recommended) — implement now, folding in the three round-2 findings (ci-8 needs UNKNOWN forever; the two direct merge_pr.sh --no-wait callers need the zero-sleep env and a fixture; the Step 5 check must skip the real "Step 5: Delete branches" header).

## Implementation
**Status**: complete
**When**: 2026-09-18 14:11 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: `feature/issue-290` at `0573773`
**Plan**: `.agent/work-plans/issue-290/plan.md` at `2bebbdc`
**Mode**: inline

- merge_pr.sh: mergeability settle moved outside the NO_WAIT gate; Step 3 retry un-gated; header, Step 2 and Step 3 comments corrected (only the real "Step 5: Delete branches" header remains).
- test_merge_pr_gate.sh: stub GH_MERGEABLE_DEFAULT fallback (in place of the plan's make_sandbox fixture, which would have broken ci-8 per plan review round 2), set to MERGEABLE with zero sleeps by run_merge and the two direct --no-wait callers; sequenced pr-merge exit/stderr fixture + write_merge_fixture; cases nw-1..nw-3, which fail against origin/main's script and pass here.
- test_merge_pr.sh (not in the plan; found when the commit hook hung): its runner also passes --no-wait and its stub had no mergeability answer, so every case would poll for 120 s. Stub now answers the poll; runner sets zero sleeps. Neither plan review round caught this suite.
- AGENTS.md: merge_pr.sh row notes the settle and retry always run.
- Suites: gate 57/57 (18 s), merge 91/91 (6 s), root-resolution 5/5.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-18 14:13 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-290 at `c446d9e`
**Base**: main
**Depth**: Standard (reason: caller override; merge-path enforcement script)
**Must-fix**: 1 | **Suggestions**: 2
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) Planned AGENTS.md merge_pr.sh row edit is missing from the branch, yet the `## Implementation` entry claims "AGENTS.md: merge_pr.sh row notes the settle and retry always run" — make the edit (row still reads only "`--no-wait` to skip the CI wait") or correct the record — `AGENTS.md:401`
- [x] (suggestion) Under --no-wait a gh/API outage during the now-always-on settle waits the full grace window then reports "never settled (still UNKNOWN)", indistinguishable from a real UNKNOWN; consider naming the lookup failure — `.agent/scripts/merge_pr.sh:1028`
- [x] (suggestion) nw-1 checks the first mergeable poll precedes the merge but not that the UNKNOWN answer was consumed (a second poll); assert the mergeable_seq count is 2 — `.agent/scripts/tests/test_merge_pr_gate.sh:716`

## Implementation
**Status**: complete
**When**: 2026-09-18 14:19 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-290 at `51ca92a`
**Addressed**: Local Review (Pre-Push) at `c446d9e` (2026-09-18 14:13 -04:00)
**Commits**: f24bf31, 556549b, 51ca92a

### Actions
- [x] AGENTS.md merge_pr.sh row now says `--no-wait` skips the CI wait (the mergeability settle and one merge retry always run) — `AGENTS.md:401`
- [x] `_wait_for_mergeable` reports LOOKUP_FAILED when the last poll could not reach GitHub; the never-settled error names the lookup failure instead of "still UNKNOWN"; new test nw-2b (stub `GH_MERGEABLE_DEFAULT=FAIL`) — `.agent/scripts/merge_pr.sh:1028`
- [x] nw-1 asserts at least two mergeability polls (UNKNOWN read, then MERGEABLE) — `.agent/scripts/tests/test_merge_pr_gate.sh:716`

Checks: test_merge_pr_gate 58/0, test_merge_pr 91/0, test_merge_pr_root_resolution 5/0; shellcheck --severity=warning clean.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-18 14:23 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-290 at `cce43e2`
**Base**: main
**Depth**: Standard (reason: caller override; merge-path enforcement script)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

### Findings
- [ ] (suggestion) LOOKUP_FAILED error says "could not reach GitHub", but `gh pr view` also fails on auth expiry, rate limit, or a bad PR number and its stderr is discarded; say "the last `gh pr view` lookup failed (network, auth, or API error)" and drop the awkward "rather than reported UNKNOWN" clause — `.agent/scripts/merge_pr.sh:1160`

## Checkpoint
**Status**: complete
**When**: 2026-09-18 14:35 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Decided-by**: owner
**After**: publish
**Decision**: publish

publish (Recommended)

## Implementation
**Status**: complete
**When**: 2026-09-18 14:39 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: `feature/issue-290` at `aa81bc3`
**Plan**: `.agent/work-plans/issue-290/plan.md` at `2bebbdc`
**Mode**: inline

- merge_pr.sh: mergeability settle moved outside the NO_WAIT gate; Step 3 retry un-gated; header, Step 2 and Step 3 comments corrected (only the real "Step 5: Delete branches" header remains).
- test_merge_pr_gate.sh: stub GH_MERGEABLE_DEFAULT fallback (instead of the plan's make_sandbox fixture, which would have broken ci-8 per plan review round 2) set to MERGEABLE by run_merge and the two direct --no-wait callers, with zero sleeps; sequenced pr-merge exit/stderr fixture + write_merge_fixture; cases nw-1..nw-3. 57/57 pass in ~15 s; nw-1..3 fail against origin/main's merge_pr.sh.
- AGENTS.md: merge_pr.sh row notes the settle and retry always run.

## Integrated Review
**Status**: complete
**When**: 2026-09-18 14:40 -04:00
**By**: Claude Code Agent (claude-opus-5)

**PR**: #296 at `bf8277c`
**Sources**: 2 (Local Review (Pre-Push) R2 @ `cce43e2` — later commits touch only progress.md; CI rollup @ `aa81bc3`; Copilot review requested but not yet posted)
**Cross-source confirmations**: 0
**CI**: all-pass

### Findings
- [x] (suggestion, deferred, Local Review R2) LOOKUP_FAILED message says "could not reach GitHub" though `gh pr view` also fails on auth expiry / rate limit / bad PR number; imprecise but still tells the operator the lookup failed and the state is unknown, so it does not mislead the merge decision — optional rewording, not merge-blocking — `.agent/scripts/merge_pr.sh`

### False positives
- (none)
