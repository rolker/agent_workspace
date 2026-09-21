---
issue: 304
---

# Issue #304 — run_script_tests.sh: per-run TMPDIR guard that fails the run on a leaked sandbox (#297 PR 2)

## Issue Review
**Status**: complete
**When**: 2026-09-21 12:09 -0400
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #304

### Scope Assessment

**Well-scoped?** Yes, with one discrepancy (see Recommendations). The issue is a single, mechanical PR: extend `run_script_tests.sh` with a per-run `TMPDIR` guard, add its test coverage, document the guard in `AGENTS.md`, and write up the one-time cleanup note. All items are independently verifiable and fit one PR.

**Right repo?** Yes — `agent_workspace`. This is workspace test-infrastructure (`.agent/scripts/tests/`), matching the plan's own repo and the parent issue #297.

**Dependencies**: PR 1 (#303, "converted every suite onto one top-level sandbox + EXIT trap") is merged to `main` (commit `805d7a3`), and this branch (`feature/issue-304`) already has that merge as an ancestor. No absolute-`/tmp` `mktemp` templates remain under `.agent/scripts/tests/` (verified: `grep -rn "mktemp.*-d */tmp/\|mktemp */tmp/" .agent/scripts/tests/*.sh` returns nothing) — PR 1's normalisation of all ten sites landed as planned. Dependency is satisfied; no other open issue blocks this one.

### Scope-vs-Plan Comparison (plan PR 2, `.agent/work-plans/issue-297/plan.md`, three-round-reviewed)

| Plan PR 2 item | In issue #304? |
|---|---|
| Per-run `TMPDIR` via `mktemp -d /tmp/run-script-tests.XXXXXX`, never derived from `[tests-dir]`, exported for every suite | Yes |
| Sweep inside the per-suite loop, attribute leak to the suite, distinct exit code, unconditional `rm -rf` on exit | Yes |
| `test_run_script_tests.sh`: leak fixture fails with suite named, clean fixture still passes, existing fail-fast cases hold | Yes |
| Update the runner's "Exit codes:" header (current lines 26–27) | Yes |
| `AGENTS.md` Script Reference row for `run_script_tests.sh` mentions the guard | Yes (confirmed missing today) |
| Document (not automate) the one-time `/tmp/tmp.*` cleanup, `.git`-presence filter caveat, age-based alternative | Yes |
| Two suggestions carried from PR 1's review (`test_merge_pr_root_resolution.sh` rev-parse self-check; `test_block_bash_tool_mapping.sh` `TMP_HOME` naming) | Yes — both confirmed in `progress.md` as explicitly deferred to PR 2 by owner checkpoint (lines 554–555), not new scope |
| **"Lint for absolute `/tmp/` mktemp templates under `.agent/scripts/tests/`"** | **Present in issue, not in the approved plan** — see Recommendations |

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | OK | The guard is the enforcement layer the parent issue asked for; failing the run (not just warning) matches the principle |
| A change includes its consequences | OK | `AGENTS.md` row and `test_run_script_tests.sh` coverage are both explicitly in scope |
| Only what's needed | Watch | The lint item adds a check with no live target — every current suite is already normalised — worth confirming its purpose before implementing |
| Improve incrementally | OK | Single, reviewable PR; no design decisions left open (plan review already converged) |
| Test what breaks | OK | Both the leak-failure path and the clean-pass path get fixture coverage per the plan |
| Human control and transparency | OK | Cleanup is documented, not automated, per plan and per the parent issue's principle note |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0011 (adapter contract) | No | `run_script_tests.sh` is the script-test runner, not `TEST_CMD`/`adapter test` — same correction the Issue Review made on #297, still holds here |
| ADR-0013 (`progress.md` entry-type vocabulary) | Yes, for this review's own persistence and later `## Plan Authored`/`## Implementation` entries | No action needed now; applies to subsequent phases |

### Consequences

- None beyond what's already listed in the issue (`AGENTS.md` row, `test_run_script_tests.sh` coverage, exit-codes header). No other script or doc references `run_script_tests.sh`'s exit codes that would need updating.

### Recommendations

- Resolve the "lint for absolute `/tmp/` mktemp templates" bullet before implementing. It traces to Plan Review round-1 finding 4, which offered two alternatives — normalise the five suites' `mktemp` calls, or have the guard lint for the literal-`/tmp/`-template pattern — and the plan's final, approved text (Approach step 7, Files to Change) resolved that finding by choosing **normalisation only**, executed in PR 1 (confirmed merged, confirmed no absolute templates remain). The plan's PR 2 section does not describe a lint check anywhere. The issue's "per plan" attribution for this bullet is not accurate as the plan currently reads. Either: (a) drop the bullet, since normalisation already closes the gap the lint would catch, or (b) keep it as a deliberate regression guard against a *future* suite reintroducing an absolute template, and say so explicitly in the PR description rather than citing it as already-approved plan scope.

### Actions
- [ ] Resolve the "lint for absolute `/tmp/` mktemp templates" bullet before implementing. It traces to Plan Review round-1 finding 4, which offered two alternatives — normalise the five suites' `mktemp` calls, or have the guard lint for the literal-`/tmp/`-template pattern — and the plan's final, approved text (Approach step 7, Files to Change) resolved that finding by choosing normalisation only, executed in PR 1 (confirmed merged, confirmed no absolute templates remain). The plan's PR 2 section does not describe a lint check anywhere. The issue's "per plan" attribution for this bullet is not accurate as the plan currently reads. Either: (a) drop the bullet, since normalisation already closes the gap the lint would catch, or (b) keep it as a deliberate regression guard against a future suite reintroducing an absolute template, and say so explicitly in the PR description rather than citing it as already-approved plan scope.

## Checkpoint
**Status**: complete
**When**: 2026-09-21 12:12 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed, keep the lint (Recommended) — plan PR 2 as scoped in the parent plan (.agent/work-plans/issue-297/plan.md, PR 2 section) plus the absolute-/tmp-template lint, declared as an addition beyond the parent plan (a deliberate regression guard, not plan scope).

## Plan Authored
**Status**: complete
**When**: 2026-09-21 12:17 -0400
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-304/plan.md` at `be1dd1e`

Lifts PR 2 of the approved parent plan (`.agent/work-plans/issue-297/plan.md`) unchanged: a per-run TMPDIR guard in `run_script_tests.sh` that sweeps inside the per-suite loop, fails with a distinct exit code naming the leaking suite, and removes the directory unconditionally on exit, plus its test coverage, the two PR 1 review carry-overs, the AGENTS.md row, and the documented (not automated) one-time cleanup note. Adds, and explicitly declares as beyond the parent plan, the absolute-`/tmp` mktemp lint the owner kept at this issue's Checkpoint as a regression guard.

## Plan Review
**Status**: complete
**When**: 2026-09-21 12:22 -0400
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #304 — run_script_tests.sh: per-run TMPDIR guard that fails the run on a leaked sandbox (#297 PR 2)
**Plan**: `.agent/work-plans/issue-304/plan.md` at `be1dd1e`
**Branch**: `feature/issue-304`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One script, one test file, two small carry-over edits, one AGENTS.md row — proportionate to the parent estimate; the one addition beyond the approved PR 2 text (the lint) is declared as such |
| Issue alignment | Good | Enforcement layer as the issue asks: the guard fails the run (exit 2) rather than warning, and attributes the leak to the suite that caused it |
| File targeting | Good | Every file named exists and every cited line number is accurate (runner 26–27, 58, 99–110; `test_run_script_tests.sh` 68 / 99 / 133; `test_merge_pr_root_resolution.sh` 128–137 with the `mktemp -d -p "$SANDBOX"` at 133; `test_block_bash_tool_mapping.sh` 29; `AGENTS.md` 411) |
| Consequences | Good | AGENTS.md row, exit-code header, and test coverage all in-PR; the one-time cleanup is documented, not automated |
| Principle alignment | Needs work | "Enforcement over documentation" is met, but the lint as specified would fire on the guard the same PR introduces (finding 1), and the guard's coverage boundary is not stated (finding 7) |
| ADR compliance | Good | ADR-0011 correctly identified as not triggered; ADR-0013 entry vocabulary followed |
| ROS conventions | N/A | Workspace plan |

### Findings

**Must-fix**

1. **[Principle alignment / internal consistency]** — Step 1 and step 5 contradict each other. Step 1 creates the guard dir with `RUN_TMPDIR=$(mktemp -d /tmp/run-script-tests.XXXXXX)` inside `run_script_tests.sh`; step 5's lint greps `mktemp[^|]*/tmp/` over `.agent/scripts/tests/*.sh`, a glob that includes `run_script_tests.sh` itself. Verified: that exact line matches the pattern (`printf` of the proposed line through the plan's own grep returns a hit), and the lint currently returns nothing on the tree, so the PR would take the lint from green to red on its own first run. Pick one resolution before implementing: scope the lint glob to `test_*.sh`; keep `*.sh` and add an explicit, commented exemption for the guard line; or create the dir as `TMPDIR=/tmp mktemp -d` / `mktemp -d --tmpdir=/tmp` (neither form matches the pattern, since the regex needs `/tmp/` *after* `mktemp`) — the third is cleanest, as it keeps the "no absolute template anywhere under tests/" invariant literally true.

2. **[Scope / consequences]** — The lint's failure path has no exit code and is not in the exit-code header. Step 3 documents exactly three codes (0, 1, 2) but step 5 adds a fourth failure mode. Step 5 also leaves two implementation choices open that change what the test case in step 4 can even assert: (a) runner vs. test file, and (b) if in the runner, whether it lints `$TESTS_DIR` or a hardcoded `.agent/scripts/tests/`. Only the `$TESTS_DIR` form makes step 5's own "fixture file with an absolute `/tmp` template makes the lint fail" case reachable via `[tests-dir]`; the hardcoded form always lints the real directory and cannot be exercised by a fixture. Decide both, assign the lint a code (reusing `1` is defensible — it is a preflight failure like the missing-tool case — but say so), and document it in the header.

**Suggestions**

3. **[Test coverage]** — Step 4's leak-case bullet "Assert the check does **not** depend on the scratch tests-dir path itself" is not something an assertion can express directly; as written it will likely become prose in a comment. Concretize it or drop it: e.g. run the same leak fixture from a scratch tests-dir that is *not* under `$TMPDIR` and assert exit 2 either way, which is the observable form of the independence claim.

4. **[Documentation accuracy]** — Step 7's caveat is wrong in its specifics. It says `test_adapter.sh`, `test_project_registry.sh` and `test_dispatch_phase.sh` roots are plain directories and "only *nested* fixture repos inside them are git repos" — verified: none of those three suites calls `git init` at all, so nothing inside them is a git repo. The caveat's conclusion (the `.git` filter clears only part of the leftovers) is still right, and measurable: of 16,679 `/tmp/tmp.*` directories on this machine right now, 5,934 have a depth-1 `.git`, so the command as written catches roughly a third. Restate the caveat with that mechanism (the `.git` must sit at depth 1 of the sandbox root; most suites nest their repos deeper, and these three create none) rather than the current claim.

5. **[Documentation accuracy]** — The "~2,800-directory figure" is stale (current count: 16,679). Either attribute it explicitly to the #297 measurement date or re-measure when the note is posted.

6. **[Human control and transparency]** — The recommended cleanup command deletes in the same invocation. `-name 'tmp.*'` plus a depth-1 `.git` also matches any unrelated `mktemp -d` that happens to hold a clone. Give the note a dry-run form first (same `find`, `-print` instead of the `rm -rf` exec) and the deleting form second, so the owner sees the match set before anything is removed.

7. **[Consequences]** — State the guard's coverage boundary in the PR. The sweep only sees what lands in `TMPDIR`; the lint deliberately covers only `.agent/scripts/tests/*.sh`. Eight absolute-`/tmp` `mktemp` sites remain in production scripts the suites invoke — `worktree_create.sh:933,974`, `pr_status.sh:321,336`, `gh_create_pr.sh:237,306`, `fetch_pr_reviews.sh:148`, `gh_create_issue.sh:205` — and their temp files bypass both `TMPDIR` and the sweep. Not this PR's job to fix; saying so keeps the guard from reading as total.

8. **[ADR compliance / governance]** — Step 6 self-exempts the `AGENTS.md` Script Reference row edit from the "Ask First: modifying instruction files" boundary by citing a workspace convention. `AGENTS.md` records no such carve-out. Either cite where that standing rule was agreed, or take the one-line confirmation — it costs less than the claim.

### Summary

The core design is sound and verified against the files: the guard dir is genuinely independent of the caller-supplied `[tests-dir]` (hardcoded under `/tmp`, so a nested run against a scratch tests-dir cannot redirect it), the in-loop sweep does fail the run immediately with per-suite attribution, the distinct exit code 2 does not disturb the existing cases — (b) and (c) assert `rc -ne 0`, and (d) asserts `rc -eq 1` before any suite runs — and both PR-1 carry-overs are handled soundly (the `git rev-parse` self-check asserts the real precondition; the fixed-name `TMP_HOME` rationale is correct, since it is one purpose-named fixture per run inside a trapped `$SANDBOX`, not a per-iteration sandbox). What blocks it is the lint colliding with the very `mktemp` line the guard introduces, and the lint's undecided placement/exit code. Both are mechanical fixes to the plan text, not design changes.

### Recommended Actions

- [ ] Resolve the lint-vs-guard collision (finding 1) — preferably by creating `RUN_TMPDIR` in a form that does not embed an absolute template
- [ ] Decide the lint's placement and scanned directory, assign it an exit code, and add it to the `# Exit codes:` header (finding 2)
- [ ] Concretize or drop the "independent of the scratch tests-dir" assertion (finding 3)
- [ ] Correct the cleanup note's `.git`-filter caveat and the stale directory count; add a dry-run form (findings 4–6)
- [ ] State the guard's coverage boundary, naming the production-script `/tmp` sites left out of scope (finding 7)
- [ ] Confirm or cite the Ask-First carve-out for the `AGENTS.md` Script Reference row (finding 8)

## Checkpoint
**Status**: complete
**When**: 2026-09-21 12:37 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise (Sonnet) — fold in both must-fixes (guard dir via `mktemp -d --tmpdir=/tmp run-script-tests.XXXXXX` so the lint's own pattern never matches it; lint lives in the runner, lints `$TESTS_DIR`, exits 1 as a preflight failure, documented in the header) and the six suggestions (concrete independence test; cleanup caveat restated on the depth-1 .git mechanism, count re-measured — 16,679 today, 5,934 with a depth-1 .git; dry-run form first; guard boundary stated incl. the eight production-script absolute-/tmp sites; AGENTS.md row). Owner approved the one-row AGENTS.md edit for this PR at this checkpoint — cite that, not a standing rule.

## Plan Authored
**Status**: complete
**When**: 2026-09-21 12:41 -0400
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-304/plan.md` at `a39284e`

Revision of `be1dd1e` addressing the Plan Review at `8714a44` (needs-work).
Resolves both must-fix findings (guard dir now created with
`mktemp -d --tmpdir=/tmp ...` so it never matches the lint it introduces;
lint relocated into `run_script_tests.sh` as a `$TESTS_DIR` preflight
exiting 1, documented in the exit-codes header) and all six suggestions
(concretized independence test case; cleanup caveat restated on the
depth-1-`.git` mechanism with re-measured counts; dry-run-first cleanup
form; guard coverage boundary stated with the eight out-of-scope
production-script sites; AGENTS.md row edit now cites the owner's
Checkpoint approval). Design unchanged from `be1dd1e` — text-level fixes
only, per the owner's `revise` decision at this issue's Checkpoint.

## Plan Review
**Status**: complete
**When**: 2026-09-21 12:43 -0400
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #304 — run_script_tests.sh: per-run TMPDIR guard that fails the run on a leaked sandbox (#297 PR 2)
**Plan**: `.agent/work-plans/issue-304/plan.md` at `a39284e`
**Branch**: `feature/issue-304`

Round 2 — light-depth delta review of the revision of `be1dd1e`, against the
round-1 `## Plan Review` at `8714a44` (2 must-fix, 6 suggestions).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged from round 1 — text-level revision only, no design change |
| Issue alignment | Good | Enforcement layer intact: exit 2 leak failure with per-suite attribution, exit 1 preflight lint |
| File targeting | Good | Re-verified on this branch: runner lines 26–27, 58, 99–110 still accurate; `AGENTS.md:411` is the `run_script_tests.sh` row; all eight production-script sites in step 7 verified exact (`worktree_create.sh:933,974`, `pr_status.sh:321,336`, `gh_create_pr.sh:237,306`, `fetch_pr_reviews.sh:148`, `gh_create_issue.sh:205`) |
| Consequences | Good | Coverage boundary now stated (round-1 finding 7); AGENTS.md row cites the owner's Checkpoint approval rather than a claimed standing rule (round-1 finding 8) |
| Principle alignment | Needs work | The lint/guard collision is fixed for the guard line, but the same collision is reintroduced by the new lint *test* case (finding 1 below) |
| ADR compliance | Good | ADR-0011 not triggered; ADR-0013 vocabulary followed |
| ROS conventions | N/A | Workspace plan |

### Round-1 items — verified resolved

- **Must-fix 1 (lint vs. guard)** — resolved. Verified empirically: the new
  line `RUN_TMPDIR=$(mktemp -d --tmpdir=/tmp run-script-tests.XXXXXX)` piped
  through `grep -nE 'mktemp[^|]*/tmp/'` returns no match (rc 1), because the
  regex needs a literal `/tmp/` after `mktemp` and `--tmpdir=/tmp ` has a
  space, not a slash, before the template. The form also works: it creates
  the directory directly under `/tmp` with the same random-suffix semantics.
  `grep -rnE 'mktemp[^|]*/tmp/' .agent/scripts/tests/*.sh` returns nothing on
  the current tree, so the lint starts green.
- **Must-fix 2 (lint placement / exit code)** — resolved. Step 5 now fixes
  both open choices (in `run_script_tests.sh`, lints `$TESTS_DIR`) and
  assigns exit `1` as a preflight-class failure; step 3 folds that into the
  `# Exit codes:` header text alongside the missing-tool case.
- **Suggestion 3** — resolved: the independence check is now an observable
  assertion (leak fixture run from a scratch tests-dir outside `$TMPDIR`,
  exit 2 either way).
- **Suggestions 4–6** — resolved: the caveat is restated on the depth-1
  `.git` mechanism with the verified "no `git init` in any of the three
  suites" fact; the count is re-measured and dated (16,679 / 5,934 on
  2026-09-21); the dry-run form is given first, deleting form second.
- **Suggestion 7** — resolved: boundary stated, with the eight sites named.
- **Suggestion 8** — resolved: the `AGENTS.md` edit now cites the owner's
  `## Checkpoint` approval for this specific one-row edit.

### Findings

**Must-fix**

1. **[Principle alignment / internal consistency]** — The new lint test case
   in step 5 recreates the exact collision must-fix 1 just removed, one level
   up. The case is "a fixture file containing an absolute-`/tmp/` `mktemp`
   call, placed in a scratch tests-dir" — but that fixture has to be written
   by `test_run_script_tests.sh`, and the generator line lives in
   `.agent/scripts/tests/test_run_script_tests.sh`, which the real run's lint
   scans via `"$TESTS_DIR"/*.sh`. Verified: a natural generator line such as
   `printf 'd=$(mktemp -d /tmp/leak.XXXXXX)\n' > "$scratch/test_lintfix.sh"`
   matches `mktemp[^|]*/tmp/`, so the full-suite run in step 9 would fail the
   preflight lint on the test file that tests the lint. Fix in the plan text:
   require the fixture's absolute template to be assembled so no single line
   of the generator contains `mktemp`…`/tmp/` — e.g.
   `T=/tmp; printf 'd=$(mktemp -d %s/leak.XXXXXX)\n' "$T"` (verified: 0
   matches) — and state that step 9's full run is the check that this held.

**Suggestions**

2. **[Consequences / implementation caution]** — Step 7 puts the coverage-
   boundary note *inside* `run_script_tests.sh` as a comment near the guard
   (see the Files-to-Change row). If that comment reproduces any of the eight
   production-script lines verbatim (they all read `mktemp /tmp/...`), the
   file lints itself red. Say in the plan that the in-script comment names
   those sites as `file:line` only and never reproduces an absolute template.

3. **[Test coverage]** — The sweep fires on *anything* left in `TMPDIR`,
   including residue from tools a suite shells out to (git, gh, pre-commit),
   not just the suite's own sandbox. Step 9's full real-suite run is the
   empirical check that no such false positive exists today; worth saying
   that explicitly, so a failure there is read as "investigate the
   attribution", not "the guard is broken".

4. **[Documentation]** — Minor: the guard hardcodes `/tmp` and so ignores a
   caller's own `TMPDIR` for its own directory. Deliberate and trapped, but
   one clause in the in-script comment saying so would prevent a future
   reader from "fixing" it back into a lint collision.

### Summary

The revision resolves both round-1 must-fixes and all six suggestions, and
every re-verified line number and count in the new text is accurate. One new
must-fix arrived with the revision itself: the lint's own test fixture, as
described, would make the real run's preflight lint fail on
`test_run_script_tests.sh`. Like round 1's, it is a text-level fix, not a
design change.

### Recommended Actions

- [ ] Specify how the lint-fixture generator avoids matching the lint pattern on its own line, and note that step 9's full run verifies it (finding 1)
- [ ] State that the in-script boundary comment cites sites as `file:line`, without reproducing absolute templates (finding 2)
- [ ] Note that step 9's full-suite run is the false-positive check for the sweep (finding 3)
- [ ] Add a clause explaining why the guard dir hardcodes `/tmp` (finding 4)

## Checkpoint
**Status**: complete
**When**: 2026-09-21 12:49 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed to implementation (Recommended) — implement the plan at `a39284e` with the round-2 review's four items applied as construction details: the lint test's fixture generator assembles the absolute template so no single line contains `mktemp`…`/tmp/` (e.g. `T=/tmp; printf '… mktemp -d %s/…' "$T"`); the in-script boundary comment names production sites as file:line only, never reproducing an absolute template; step 9's full run is the empirical check against sweep false positives from tools a suite shells to; the comment states the guard deliberately ignores the caller's TMPDIR. Implementer: Opus sub-agent under the host.

## Implementation
**Status**: complete
**When**: 2026-09-21 13:00 -04:00
**By**: Claude Code Agent (implementer: claude-opus-5; lead: claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-304/plan.md` at `a39284e`

**Branch**: `feature/issue-304` at `5887915`
**Mode**: inline

Four atomic commits. `4b06617` — `run_script_tests.sh` gains a preflight lint
(`grep -rnE 'mktemp[^|]*/tmp/' "$TESTS_DIR"/*.sh`, exit 1, names the offending
file, runs after the existing tool preflight and before any suite) and the
per-run guard: `RUN_TMPDIR=$(mktemp -d --tmpdir=/tmp run-script-tests.XXXXXX)`
created immediately before the suite loop with an unconditional `EXIT` trap,
exported as `TMPDIR`/`TMP`/`TEMP`, plus a sweep inside the loop on the
continue path that exits 2 naming the suite and the leftover paths; the
`# Exit codes:` header now documents 0/1/2. The same commit adds cases (e)–(h)
to `test_run_script_tests.sh`: leak fixture → exit 2 naming the suite; a suite
that creates and removes its own `TMPDIR` files → still exit 0; the same leak
fixture run from a tests-dir outside a caller-supplied `TMPDIR` → still exit 2
and the caller's `TMPDIR` is asserted untouched (the observable form of guard
independence from both `[tests-dir]` and caller `TMPDIR`); an absolute-`/tmp`
template fixture → exit 1, naming the file, with a marker proving no suite
ran. Cases (a)–(d) unmodified and still passing. `11751a8` —
`test_merge_pr_root_resolution.sh` `test_resolution_outside_repo()` asserts the
precondition with `git rev-parse --is-inside-work-tree` before asserting
`resolve_root` returns empty. `92e50f4` — `test_block_bash_tool_mapping.sh`
records why `TMP_HOME` keeps a fixed name under `$SANDBOX`. `5887915` —
the one-row `AGENTS.md` Script Reference edit, per the owner's Checkpoint
approval.

Round-2 review items, all four applied: (1) the lint fixture's template is
assembled via `ABS_TMP_ROOT=/tmp` on its own line and a `printf '%s'`
substitution, so no line of `test_run_script_tests.sh` contains
`mktemp`…`/tmp/` — the green full-suite run (which lints that file) is the
empirical proof; (2) the in-script coverage-boundary comment cites the eight
production sites as `file:line` only and says explicitly that reproducing a
template there would trip the lint; (3) the comment states the sweep catches
anything left in `TMPDIR`, including residue from tools a suite shells out to,
and that the full real-suite run is the empirical check that no false positive
exists today — read a future firing as an attribution question, not a broken
guard; (4) the comment states the guard hardcodes `/tmp` and deliberately
ignores the caller's `TMPDIR`, with both reasons (nested-run isolation and
lint-collision avoidance) so nobody "fixes" it back.

Verification: `bash .agent/scripts/tests/run_script_tests.sh` → exit 0, all 23
suites in 48s with the guard active (no tool-residue false positives);
`bash .agent/scripts/tests/test_run_script_tests.sh` → 9 passed, 0 failed;
PR 1's per-suite measurement re-run across all 23 suites → 0 leftovers for
every suite. Pre-commit hooks (including the full script-test suite) passed on
each of the four commits.

Deviations from the plan, both minor: the one-time-cleanup note landed inside
`4b06617` with the guard comment it belongs to rather than as a fifth commit
(it is a comment block in the same file; the PR-description paragraph is still
owed at publish time). And the guard directory is created after the existing
preflight checks, not before them, so the plan's parenthetical "removed on an
early exit 1 from the preflight checks above the loop" is vacuous — no guard
directory exists on those paths, so there is nothing to remove; creating it
earlier would have required adding `mktemp`/`find` to case (d)'s minimal
`PATH`, editing an existing case the plan said to leave intact.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-21 13:32 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-304 at `5f6e5a1`
**Base**: main
**Depth**: Standard (reason: enforcement script wired into pre-commit + an AGENTS.md governance row)
**Must-fix**: 1 | **Suggestions**: 4
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

Verified by running, not by reading: full real suite 23/23 in 53s exit 0 (no
tool-residue false positive, lint green on the real tree); a leak fixture →
exit 2 naming `test_aaa_leaker.sh` and the leftover path, later suites not run,
guard dir removed by the trap; a nested-subdirectory leak → also exit 2; a
literal `/tmp/` template fixture → exit 1 naming the file with a marker proving
no suite ran; `test_run_script_tests.sh` 9 passed / 0 failed; shellcheck via
pre-commit passed on all four changed scripts. Both declared deviations are
sound — the cleanup note belongs with the guard comment it annotates, and
creating the guard dir after the preflights is strictly better than the plan's
text (a lint failure now leaves no stray dir, and case (d)'s minimal `PATH` has
no `mktemp`). An independent adversarial subagent found no must-fix; its three
suggestions are folded in below.

### Findings
- [x] (must-fix) lint catches only the `mktemp … /tmp/<template>` spelling — fixtures using `mktemp -d --tmpdir=/tmp …` and `mktemp -d -p /tmp …` both passed the lint, escaped the guard root and left a real dir in /tmp with the run exiting 0; fix by linting `"$TESTS_DIR"/test_*.sh` (drops the self-exemption) and broadening the pattern to `-p /tmp` / `--tmpdir=/tmp`, with a fixture case per spelling — `.agent/scripts/tests/run_script_tests.sh:116`
- [x] (suggestion) leak message lists only `-maxdepth 1` entries and the EXIT trap then deletes them, so a leaked directory is unreadable by the time it is reported — print the recursive listing in the message — `.agent/scripts/tests/run_script_tests.sh:199`
- [x] (suggestion) lint pattern is not anchored to a root `/tmp/`, so `"$HOME/local/tmp/x.XXXXXX"` would false-positive; anchor it or say in the comment that it is a heuristic over file text — `.agent/scripts/tests/run_script_tests.sh:116`
- [x] (suggestion) hardcoded "16,679 / 5,934" measurement bakes a decaying point-in-time number into permanent script documentation; it already lives in the Checkpoint entry and belongs in the PR description — `.agent/scripts/tests/run_script_tests.sh:170`
- [x] (suggestion) undeclared third deviation: the plan's Files-to-Change row said "No code change; PR description states why", but the TMP_HOME rationale landed as a code comment; the PR description still owes that rationale plus plan step 7's one-time-cleanup paragraph and the #297 closing comment — `.agent/scripts/tests/test_block_bash_tool_mapping.sh:28` (deferred: comment is the better home than the PR description; host carries the rationale, the one-time-cleanup paragraph and the #297 closing text into the PR body)

## Implementation
**Status**: complete
**When**: 2026-09-21 13:29 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-304 at `c0a555b`
**Addressed**: Local Review (Pre-Push) at `5f6e5a1` (2026-09-21 13:32 -04:00)
**Commits**: e028c54, 67a7816, 4a4a208, c0a555b

### Actions
- [x] (must-fix) lint caught only `mktemp … /tmp/<template>`; `-p /tmp`, `--tmpdir=/tmp` and `--tmpdir /tmp` escaped the guard root with the run exiting 0 — lint scope is now `"$TESTS_DIR"/test_*.sh` (the runner is exempt by glob, not by dodging its own pattern) and the pattern covers all four spellings; `test_run_script_tests.sh` case (i) adds one fixture per bypass spelling, templates assembled via `printf` so no line of the suite matches the pattern it lints itself with — `.agent/scripts/tests/run_script_tests.sh:116`, `.agent/scripts/tests/test_run_script_tests.sh:240`
- [x] (suggestion) leak message printed only `-maxdepth 1` entries that the EXIT trap then deleted — the sweep now lists the leaked tree recursively, capped at `LEAK_LIST_MAX=200` lines with the remainder summarised as a count, and the headline states the entry count; case (k) asserts a nested leak path appears in the message — `.agent/scripts/tests/run_script_tests.sh:199`
- [x] (suggestion) lint pattern was unanchored — `/tmp` must now follow a whitespace/quote/`=`/`(` boundary and be followed by `/`, whitespace, a quote, `)` or end of line, so `"$HOME/local/tmp/x.XXXXXX"` is not a hit; the comment also states outright that this is a heuristic over file text, not a shell parse. Case (j) pins the anchoring with a literal (not assembled) nested `.../tmp/` fixture, so the real run lints that very line — `.agent/scripts/tests/run_script_tests.sh:116`, `.agent/scripts/tests/test_run_script_tests.sh:300`
- [x] (suggestion) frozen "16,679 / 5,934" counts removed from the in-script cleanup note — it now cites the 2026-09-21 measurement date and the #297 timeline; the figures belong in the PR description — `.agent/scripts/tests/run_script_tests.sh:170`
- [x] (suggestion) TMP_HOME rationale landed as a code comment rather than PR-description text (deferred: the comment is the better home — it sits where a future editor reads it, not in a PR body nobody re-opens; left in place. The host still owes the PR description that rationale, plan step 7's one-time-cleanup paragraph and the #297 closing text) — `.agent/scripts/tests/test_block_bash_tool_mapping.sh:28`

### Verification
- `bash .agent/scripts/tests/run_script_tests.sh` — exit 0, all 23 suites passed in 46s (lint green on the real tree under the broadened, anchored pattern).
- `bash .agent/scripts/tests/test_run_script_tests.sh` — 14 passed, 0 failed, including the three new per-spelling lint cases, the anchoring case and the recursive-listing case.
- Hand-run in a scratch tests-dir, one run per spelling (`/tmp/<template>`, `-p /tmp`, `--tmpdir=/tmp`, `--tmpdir /tmp`): every run exited 1 and named the offending fixture; zero directories left in `/tmp` before and after.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-21 13:52 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-304 at `e26e4d4`
**Base**: main
**Depth**: Standard (reason: enforcement script wired into pre-commit)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 1), not rising — fix and ship rather than another full round

Round-2 delta review of `5f6e5a1..e26e4d4` against the round-1 entry at
`c80228f` (1 must-fix, 4 suggestions). All five round-1 items verified
resolved by execution, not by reading: every bypass spelling
(`/tmp/<template>`, a quoted template, `-p /tmp`, `--tmpdir=/tmp`,
`--tmpdir /tmp`) now exits 1 naming the offending fixture, with no suite
run and nothing left in `/tmp`; the anchoring holds in both directions —
`"$HOME/local/tmp/x.XXXXXX"` and `"${TMPDIR}/tmpfile.XXXXXX"` both stay
green; full real suite 23/23 exit 0 in 46s; `test_run_script_tests.sh`
14 passed / 0 failed; shellcheck (via pre-commit) clean on both changed
scripts; the delta touches only the two test scripts plus `progress.md`;
worktree clean. Both undeclared-but-noted additions are sound: the removed
"do not fix this back" comment is obsolete because the `test_*.sh` glob now
exempts the runner's own guard `mktemp` by scope rather than by pattern
contortion (verified), and case (k) + `LEAK_LIST_MAX` implement the
round-1 recursive-listing suggestion, with the cap arithmetic verified
exact on a 251-entry leak. An independent adversarial subagent found two
further lint escapes, both of which I reproduced myself before accepting.

### Findings
- [x] (must-fix) comment claims the pattern "covers every mktemp spelling that escapes TMPDIR", but two still escape — verified each leaves a real dir in /tmp with the run exiting 0: the attached-argument form (`mktemp -d -p/tmp t.XXXXXX`, `mktemp -dp/tmp t.XXXXXX`, a one-line regex fix) and a backslash line-continuation splitting `mktemp` from `-p /tmp` across two lines (out of reach of any line grep — belongs in the coverage boundary); either way the exhaustiveness claim must go — `.agent/scripts/tests/run_script_tests.sh:120`
- [x] (suggestion) a bare relative template (`mktemp -d leak.XXXXXX`) ignores TMPDIR and lands in the runner's cwd — the repo root under pre-commit — invisible to both the lint and the sweep; verified run-green with the directory left behind; name it in the coverage boundary or open a follow-up — `.agent/scripts/tests/run_script_tests.sh:161`
- [x] (suggestion) AGENTS.md Script Reference row still says the lint rejects absolute-`/tmp` mktemp *templates*; it now also rejects `-p /tmp` / `--tmpdir=/tmp` roots, and the runner's own error string was updated to "destination(s)" — `AGENTS.md:411`
- [x] (suggestion) case (j) pins only the leading boundary anchor; the trailing half of the claim (`/tmpfile.XXXXXX` is not a hit) has no fixture — verified green by hand, but uncovered — `.agent/scripts/tests/test_run_script_tests.sh:281`

## Implementation
**Status**: complete
**When**: 2026-09-21 13:51 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-304 at `b67b4e9`
**Addressed**: Local Review (Pre-Push) at `e26e4d4` (2026-09-21 13:52 -04:00)
**Commits**: 7941db0, 1a9bec2, b67b4e9

### Actions
- [x] (must-fix) attached-argument `-p/tmp` / `-dp/tmp` escaped the lint, and the "covers every mktemp spelling" claim was false — `.agent/scripts/tests/run_script_tests.sh:120`. The pattern now allows an optional attached short-flag cluster ending in `p` between the boundary character and `/tmp` (`(-[[:alpha:]]*p)?`); the comment lists the covered spellings without claiming exhaustiveness, and the coverage boundary names the backslash line-continuation form as out of reach of any line-oriented grep. Fixtures `(i) p_flag_attached` and `(i) dp_cluster_attached` added.
- [x] (suggestion) bare relative template (`mktemp -d leak.XXXXXX`) lands in the runner's cwd, invisible to lint and sweep — named in the coverage boundary alongside the line-continuation and variable-root cases; verified no such site exists in `.agent/scripts/tests/` today, so no follow-up issue — `.agent/scripts/tests/run_script_tests.sh:161`
- [x] (suggestion) Script Reference row now says the lint rejects absolute-`/tmp` mktemp *destinations* — a `/tmp` template, or a `-p /tmp` / `--tmpdir=/tmp` root — matching the runner's "destination(s)" error string — `AGENTS.md:411`
- [x] (suggestion) case (j) pinned only the leading anchor; new case (j2) asserts a `/tmp`-prefixed sibling (`/tmpfile.XXXXXX`, both in prose after a whitespace boundary and under `${TMPDIR}`) stays green — `.agent/scripts/tests/test_run_script_tests.sh:306`

### Verification
- `bash .agent/scripts/tests/run_script_tests.sh` → exit 0, all suites passed; `/tmp` entry count unchanged before/after.
- `bash .agent/scripts/tests/test_run_script_tests.sh` → 17 passed, 0 failed (was 14; +2 attached-form lint cases, +1 trailing-boundary case).
- Hand-run: a scratch tests dir containing `mktemp -d -p/tmp ...` and `mktemp -dp/tmp ...` fixtures → runner exits 1 naming both files; the pre-fix pattern matched neither.
- Self-check: the new pattern finds no hit in `.agent/scripts/tests/test_*.sh`, so no fixture line trips the lint on this repo's own run. Pre-commit (which runs the suite) passed on all three commits.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-21 13:55 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-304 at `1df412c`
**Base**: main
**Depth**: Light (reason: caller-specified; delta is three commits of test fixtures, comment prose, and one doc row)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

All four round-2 items verified by execution: attached-argument `-p/tmp` and
`-dp/tmp` fixtures reject with exit 1 (`p_flag_attached`, `dp_cluster_attached`);
exhaustiveness claim replaced by a named three-spelling coverage boundary; bare
relative template confirmed to ignore TMPDIR and land in cwd, with no such site
in the suites; AGENTS.md row matches lint behaviour; trailing-boundary fixture
`(j2)` added. 17/17 in test_run_script_tests.sh; full runner green (23 suites,
45s, exit 0) with zero new /tmp residue. Direct regex probe: 8 escaping
spellings hit, 6 safe ones miss — including `$HOME/opt-p/tmp/x`, the false
positive the attached-flag branch risked. pre-commit (shellcheck included)
clean on all three changed files. Nothing changed outside the three commits.

### Findings
- [ ] (suggestion) list insertion stranded "Eight absolute-/tmp" as a mid-sentence fragment; reflow the coverage-boundary paragraph — `.agent/scripts/tests/run_script_tests.sh:180`

## Checkpoint
**Status**: complete
**When**: 2026-09-21 14:01 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: publish
**Decision**: publish

Publish (Recommended) — round-3 pre-push review approved; the one cosmetic suggestion (comment reflow at run_script_tests.sh:180) is tracked, not applied.
