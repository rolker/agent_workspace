---
issue: 410
---

# Issue #410 — Pre-commit script-test hook: run only the suites whose declared files changed

## Issue Review
**Status**: complete
**When**: 2026-10-29 08:13 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #410

### Scope Assessment

**Well-scoped?** Mostly. One PR can carry it, but the issue's premise is off (see Recommendations): the existing declaration covers only 5 of 39 suites and says which out-of-tree prefixes a suite reads, not which script it tests. The scoping map has to be built, not just reused.
**Right repo?** Yes. Hook, runner and tests are workspace infrastructure.
**Serves**: Quality of the work (and wall-clock of the review loop) — `docs/design.md#rules` (hook rows) and `docs/design.md#review-loop-and-timeline`
**Design picture?** No change, provided the backstop stays: the Rules table says the Lint job runs every hook on all files. Narrowing CI would change that row and is a separate decision (the issue already says so).
**Dependencies**: none blocking. Related #399 (SKIP rule, whose wording may need a touch), #384.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforce what matters, as simply as possible | Action needed | A suite-to-file map risks drifting (a suite starts reading a new file and the hook silently skips it). The map needs an enforced check, like the existing scope test, and the safe default for an undeclared or unmapped suite must be "run it". |
| Verify before claiming | Watch | The "under a minute for a typical fix commit" acceptance needs a measured typical case (which suites a commit to one script triggers), not an estimate. |
| Only what's needed | Watch | Keep to the hook; CI narrowing stays out of scope as the issue says. |
| Keep one current design | OK | No design change; the Rules row on CI running all hooks stays true. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (progress timeline) | No | The progress.md vocabulary suites keep their own triggers. |
| ADR-0011 (adapter) | No | Not touched. |

### Consequences

- Update the header comments in `run_script_tests.sh` and the `.pre-commit-config.yaml` comment block, plus the #399 wording ("final no-SKIP run over `git diff --name-only main...HEAD`"), so they describe scoped behaviour.
- `test_run_script_tests.sh` and `test_script_tests_hook_scope.sh` need new cases for the scoped mode and the full-run triggers.
- The hook uses `pass_filenames: false`; the runner must now receive the changed files (or the hook must pass them) and keep the full run when invoked with none (`make lint`, CI `--all-files`).

### Recommendations

- Correct the premise in the plan: `test_script_tests_hook_scope.sh` declares only 5 `ROOT_READERS` entries (suites that derive a real repo root) and lists out-of-tree prefixes read, not the script under test. Say how the suite-to-file map is made (a new declaration per suite, or derived from the suite name and its `SCRIPT_DIR` references) and how a missing entry is caught.
- Make the fail-safe explicit: a changed file that maps to no suite, a suite with no entry, or a runner/shared-helper/hook-config change runs everything.
- List the shared helpers every suite sources, and test that a change to each triggers the full run.
- State the measured timing for one or two typical fix commits in the plan, and confirm `make lint` / CI `--all-files` still runs all 39.

### Actions
- [ ] A suite-to-file map risks drifting (a suite starts reading a new file and the hook silently skips it). The map needs an enforced check, like the existing scope test, and the safe default for an undeclared or unmapped suite must be "run it".
- [ ] Correct the premise in the plan: `test_script_tests_hook_scope.sh` declares only 5 `ROOT_READERS` entries (suites that derive a real repo root) and lists out-of-tree prefixes read, not the script under test. Say how the suite-to-file map is made (a new declaration per suite, or derived from the suite name and its `SCRIPT_DIR` references) and how a missing entry is caught.
- [ ] Make the fail-safe explicit: a changed file that maps to no suite, a suite with no entry, or a runner/shared-helper/hook-config change runs everything.
- [ ] List the shared helpers every suite sources, and test that a change to each triggers the full run.
- [ ] State the measured timing for one or two typical fix commits in the plan, and confirm `make lint` / CI `--all-files` still runs all 39.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 08:13 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (all five open Actions are plan-level requirements: how the suite-to-file map is built, its enforced drift check, the run-everything fail-safe, the shared-helper list and measured timing; none changes what the issue is for or its scope, so /orchestrator's table lets the host answer proceed)
**After**: issue-actions
**Decision**: proceed

The Issue Review found the issue well-scoped and in the right repository, with one premise to correct: `test_script_tests_hook_scope.sh` declares only 5 ROOT_READERS entries (out-of-tree prefixes read), not a suite-to-file map, so the map has to be built. All five Actions are carried into the plan-task handoff as plan requirements.

## Plan Authored
**Status**: complete
**When**: 2026-10-29 08:17 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-410/plan.md` at `6c764c56`

Derive the suite-to-file map from suite text (closure over referenced scripts) with optional covers lines, pass changed files to the runner, and run everything on no files, helper or runner change, or an unmapped file. Drift and helper-rule tests are enforced; CI stays full.

## Plan Review
**Status**: complete
**When**: 2026-10-29 08:22 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #410 — Pre-commit script-test hook: run only the suites whose declared files changed
**Plan**: `.agent/work-plans/issue-410/plan.md` at `6c764c56`
**Branch**: `feature/issue-410`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR: one new script, the runner, the hook block, two test suites, a few `# covers:` lines |
| Issue alignment | Concern | Serves, as checked: "Quality of the work and review-loop wall-clock (README Workspace goals); `docs/design.md#rules` and `docs/design.md#review-loop-and-timeline`" (goal heading and both anchors exist). The five Issue Review Actions are each addressed on paper, but the mechanism as written does not narrow anything in this tree (finding 1), so the issue's purpose, under a minute for a typical fix commit, is not met |
| File targeting | Needs work | Missing `AGENTS.md` (Script Reference row for the runner says "Run every ... suite"); the #399 wording sites are not named |
| Consequences | Needs work | Deletions and renames never reach the hook (finding 3); `AGENTS.md` row; hook `entry:` must carry `--files` |
| Principle alignment | Needs work | "Verify before claiming": the derivation's selectivity was not measured before planning, and a prototype shows it collapses. "Test what breaks": no test pins that narrowing actually happens on the real tree |
| ADR compliance | Good | ADR-0013 and ADR-0011 not triggered, agreed. ADR-0005 (CI is the enforcement layer): kept, CI stays full |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Issue alignment / Verify before claiming]** The transitive closure in step 1 maps every change to all 39 suites. Prototype of step 1 as written (tracked paths, match by relpath or basename, closure over `.sh`/`.py`/executables): every suite's closure reaches 286 files; `merge_pr.sh`, `register_project.sh`, `review_progress.sh`, a `SKILL.md` and `AGENTS.md` each select 39 of 39. Restricting the vocabulary to the hook's `files:` scope still gives 39 of 39 (closures of 96 to 121 files). The cause is hubs that name many files in comments and help text (`dispatch_phase.sh` names 165 tracked files, `cross_model_review.sh` 144) and generic basenames (`progress.md`, `plan.md`, `SKILL.md`, `README.md`, `adapter.sh`). Stripping comment lines before matching makes it selective: `merge_pr.sh` selects 15 suites, `register_project.sh` 2. One hop with no closure selects 8 and 3, but misses transitive callers. "Over-inclusion is fine" holds only while it is partial. The plan should specify the derivation rule (comments stripped, expansion only through code, vocabulary = hook scope minus work-plans), record measured selectivity for two or three typical files, and add a real-tree test asserting that a named script maps to a strict subset of the suites. Without that test, a future hub silently turns the hook back into the full 7 minutes.
2. **[Issue alignment] The premise correction is itself wrong, and folding in the prefixes defeats the timing goal.** `ROOT_READERS` has 23 entries, not 5. Their prefixes are coarse: `.agent/scripts` (10 suites), `.agent/` (`test_session_root`, `test_skill_prefix`, `test_skill_paths`, `test_user_tier_guard`, `test_user_tier_install`), `.claude/`. If "folded in automatically" means each prefix acts as a covers line, any `.agent/scripts/*` change runs about 16 suites, `test_register_project.sh` (94.8 s) among them. Every script fix then misses the under-a-minute acceptance, not only a `register_project.sh` fix as the Open Questions say. The plan must say whether the prefixes select suites or only feed drift check 5(b), and state the resulting suite set and time for the two measured commits. This is a mechanism choice: decide it from the principles and list it for veto.
3. **[Consequences] Deleted and renamed-away files never reach the runner.** pre-commit gathers staged files with `--diff-filter=ACMRTUXB` (no `D`; `pre_commit/git.py:get_staged_files`), and `run.py:75` drops any `--files` path that does not exist (`os.path.lexists`). A rename passes only the new name. A commit, or the #399 branch run, that deletes or renames a script and also edits another in-scope file narrows to the edited file's suites. The suites that still name the old path are skipped and only CI catches it. Add a full-run trigger the runner computes itself, for example any staged deletion or rename source in scope (`git diff --cached --name-only --diff-filter=DR`), or any suite naming a tracked-looking path that is no longer in `git ls-files`. Test it.
4. **[File targeting / Consequences] `AGENTS.md` Script Reference row** for `run_script_tests.sh` ("Run every `.agent/scripts/tests/test_*.sh` suite ...") becomes wrong and must change. `AGENTS.md` is an instruction file (Ask First), so the plan should say so for the owner. Also name the #399 wording sites in step 8 and check each: `.claude/skills/address-findings/SKILL.md:178`, `.claude/skills/run-issue/SKILL.md:325`, `.agent/scripts/dispatch_phase.sh:22` and `:411` (text asserted by `test_dispatch_phase.sh:497`), and the `.pre-commit-config.yaml` comment.
5. **[Consequences] The hook `entry:` must end in `--files`.** The runner reads `$1` as `[tests-dir]` (`run_script_tests.sh:76`). With `pass_filenames: true` and the current entry, the first staged path becomes the tests dir. That fails loudly rather than silently, but the plan should state the new entry and pin it in the scope test that already parses the hook block.
6. **[Principle alignment] The full-run pin (step 7).** Assert the count against the glob, not the literal 39. Do not run the real tree from `test_run_script_tests.sh` (it is one of the suites, so it would recurse). Instead feed `suites_for_files.sh` the real `git ls-files` list filtered by the hook's own `files:`/`exclude:` regexes (197 paths today), expect `ALL`, and run the runner's full mode on a synthetic dir. Step 3 also says no files are passed under `make lint` / CI `--all-files`. That is wrong once `pass_filenames: true`: all 197 in-scope paths are passed, and `ALL` comes from the runner being among them (step 7 has it right). Fix the wording.
7. **[Suggestion] Python imports are invisible to filename matching.** `from workspace import` in `validate_workspace.py`/`sync.py` maps `workspace.py` to no suite (the result is `ALL`, which is safe). `from progress_read import` in `test_progress_read.py` maps only because `progress_read.py` is a substring of `test_progress_read.py`. Map `import X` / `from X import` to `X.py` explicitly, or note it as a known gap.
8. **[Suggestion] Clarify two fail-safe rules.** "A suite derives no references → `ALL`": does that mean the whole run, or only that this suite always runs? The comment-stripped prototype has one suite with an empty set; with whole-run semantics, every commit would be full. Second, `test_checkpoint_269.sh`: the runner only checks that it is present, but its header says "present and was executed". State whether the checkpoint suite joins every scoped run, and fix the header either way.
9. **[Suggestion] State the expected full-run cases.** About 50 in-scope files map to no suite (`.agent/knowledge/*.md`, `.agent/hooks/*.py`, the top-level `.agent/*.md` guides), so a docs-only commit there still pays the full run. That is fine, but the PR should say so, so nobody reports it as a bug.

Host checks, answered:
- `pass_filenames: true` with `require_serial: true` is correct. `lang_base.run_xargs` sets `jobs = 1`, and `xargs.partition` then allows `max_args = len(files)`. It splits only past 2^17 bytes of arguments (`_get_platform_max_length`); the in-scope list is 197 paths and 7.6 KB, so it runs as one process.
- Testing the helper rule over the glob `.agent/scripts/_*.sh` (11 files today, matching the plan's list) is the right shape. The implementation should match the same pattern rather than a list, so the glob test also catches a list that has drifted.

### Summary

The fail-safes and the CI backstop are sound, and the pre-commit wiring is right. The core mechanism needs rework before implementation: the closure as written selects all 39 suites for every change in this tree. The `ROOT_READERS` count and its timing effect are wrong. Deleted and renamed files bypass the narrowing.

### Recommended Actions

- [ ] Must-fix: specify a bounded derivation (comments stripped, closure only through code, vocabulary = hook scope minus work-plans). Record its measured selectivity for `merge_pr.sh` and `register_project.sh`, and add a real-tree test that one named script selects a strict subset of suites.
- [ ] Must-fix: correct the premise to 23 `ROOT_READERS` entries. Say whether their coarse prefixes select suites or only feed drift check 5(b), and give the resulting suite set and time for the two typical commits against the under-a-minute acceptance.
- [ ] Must-fix: add a full-run (or affected-suite) trigger for staged deletions and rename sources, which pre-commit never passes to a hook, with a test covering the commit and #399 branch-run cases.
- [ ] Must-fix: add the `AGENTS.md` Script Reference row to Files to Change, flagged as an Ask-First instruction-file edit, and name each #399 wording site (`address-findings` and `run-issue` SKILL.md, `dispatch_phase.sh` with its `test_dispatch_phase.sh` assertion, the hook comment).
- [ ] Suggestion: state the new hook `entry:` with `--files` and pin it in the scope test.
- [ ] Suggestion: pin the full run by glob count and with the real filtered `git ls-files` list fed to `suites_for_files.sh`. Fix step 3's claim that `--all-files` passes no files.
- [ ] Suggestion: map Python `import X` to `X.py` or record it as a known gap.
- [ ] Suggestion: say whether a suite with no references makes that suite always run or the whole run, and whether `test_checkpoint_269.sh` joins every scoped run; fix the runner header's "and was executed".
- [ ] Suggestion: list the in-scope files that will still trigger a full run (knowledge docs, `.agent/hooks/*.py`) in the PR.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 08:23 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (first revise at plan; the review's four must-fixes are mechanism: the derivation as written selects all 39 suites for every change, the ROOT_READERS count is 23 not 5, deletions and renames never reach the hook, and the Files-to-Change list misses the AGENTS.md row and the #399 wording sites; none changes what the issue is for)
**After**: plan
**Decision**: revise

Plan Review verdict needs-work (42c529c8). Host decisions carried into the plan-task handoff, listed for the owner's veto: ROOT_READERS prefixes feed the drift check only and never select suites (selectivity is the point; helpers and the runner already force a full run); staged deletions and renames of in-scope files force a full run (the simplest safe rule); the AGENTS.md Script Reference row is flagged Ask-First and the owner is asked in this turn, before implementation.

## Plan Authored
**Status**: complete
**When**: 2026-10-29 08:29 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-410/plan.md` at `5af3efe3`

Revision after a needs-work plan review. Suite derivation is now bounded (comment lines stripped, closure only through code, vocabulary = hook scope minus work-plans) and measured on the real tree: a merge_pr.sh change selects 16 of 39 suites (about 137 s serial), a register_project.sh change 2 (about 95 to 118 s), so the under-a-minute acceptance is not met serially and is raised as an open question. ROOT_READERS prefixes (23, not 5) feed the drift check only; staged deletions and rename sources force a full run; the AGENTS.md row is a last, Ask-First step; the wording sites are named.

## Plan Review
**Status**: complete
**When**: 2026-10-29 09:25 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #410 — Pre-commit script-test hook: run only the suites whose declared files changed
**Plan**: `.agent/work-plans/issue-410/plan.md` at `5af3efe3`
**Branch**: `feature/issue-410`

Round 2. Round-1 must-fixes: (1) bounded derivation, measured, real-tree selectivity test: addressed; my own prototype of the rule as written reproduces the plan's figures (`merge_pr.sh` 16 of 39, `register_project.sh` 2, `review_progress.sh` 10, `AGENTS.md` and a `SKILL.md` 13, 55 unmapped in-scope files). (2) 23 `ROOT_READERS`, prefixes drift-only, suite sets and times stated: addressed, but see finding 2 for what drift-only drops. (3) Deletions and renames: addressed in intent, but the mechanism as written misses both cases it targets (finding 1). (4) `AGENTS.md` row and #399 wording sites: addressed (all five line references checked). Round-1 suggestions 5 to 9 are all addressed (entry pin, glob-count and real `git ls-files` pins, step 8 wording, Python imports, empty-suite and checkpoint semantics, the 55 full-run files).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR; unchanged from round 1 |
| Issue alignment | Good | Serves, as checked: "Quality of the work and review-loop wall-clock (README Workspace goals); `docs/design.md#rules` and `docs/design.md#review-loop-and-timeline`" (goal heading and both anchors exist). Under-a-minute miss is stated honestly and is with the owner |
| File targeting | Good | Wording sites verified at the cited lines; `AGENTS.md` row is step 10 |
| Consequences | Needs work | Deletion check reads the wrong index and the wrong side of a rename (finding 1); whole-prefix scanning suites lose their coverage (finding 2) |
| Principle alignment | Needs work | "Test what breaks": the planned deletion/rename tests would pass against the broken mechanism unless they go through a real `git commit -a` and an out-of-scope rename. "Enforce what matters": the drift check in `test_script_tests_hook_scope.sh` itself stops running when a suite it guards is edited |
| ADR compliance | Good | ADR-0005 kept (CI runs every hook on all files); ADR-0013 and ADR-0011 not triggered. Design picture: `docs/design.md` line 359 (adapter `test` verb wraps the runner) stays true, since no `--files` still runs everything |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Consequences] The deletion/rename trigger in step 4 misses the cases it is for (verified in a scratch repo).**
   (a) The runner unsets `GIT_INDEX_FILE` at its top (the hook-environment sanitization). `git commit -a` runs hooks with `GIT_INDEX_FILE=.git/index.lock`, and `git commit <paths>` with `.git/next-index-*.lock`. After the unset, `git diff --cached --name-only --diff-filter=D` reads `.git/index` and printed nothing for a deleted file; before the unset it printed the deletion. The check must run before the unset, or with the saved `GIT_INDEX_FILE`.
   (b) `git diff --name-only --diff-filter=DR` prints a rename's destination, not its source (`git mv .agent/scripts/x.sh old/x.sh` printed `old/x.sh`). A rename from inside the hook scope to outside it is therefore not forced full. Use `--no-renames --diff-filter=D`, which lists the rename source as a deletion. The same applies to the branch-run `<default>...HEAD` check.
   Tests: drive one case through a real `git commit -a` (or a pathspec commit) with the runner as the hook, and rename an in-scope file to an out-of-scope path. A `git rm` plus a direct runner call passes against the broken version.
2. **[Consequences] Suites that scan a whole prefix are no longer selected by it, and drift check 6(b) passes for them anyway.** Prototype of step 1:
   - `test_skill_paths.sh` guard (c) runs `git grep` for pointers to the old what-next skill over `.agent/ .claude/ AGENTS.md Makefile`. A pointer added to, say, `dashboard.sh` selects 3 suites, not this one.
   - `test_script_tests_hook_scope.sh` scans every `test_*.sh` (root-derivation scan, ROOT_READERS check, and the new step 6 checks). Editing a suite outside ROOT_READERS (`test_capture.sh` selects only itself) skips it. A suite that starts deriving a real root without a declaration, or loses its references, passes locally; only CI catches it.
   Step 6(b) passes for both, because their prefixes trivially contain derived files. Name the scanning suites in the plan and give each a `# covers:` line with the prefix it scans (`test_skill_paths.sh`: its four grep prefixes; `test_script_tests_hook_scope.sh`: `.agent/scripts/tests/`). Both are among the fast suites. Distinguish a scanning prefix (selects) from a copy-into-sandbox prefix (drift-only) in the `ROOT_READERS` comment. The manifest-driven `test_user_tier_guard.sh` is fine: every manifest entry already maps to it.
3. **[Suggestion] `test_progress_read.sh` derives no references.** It runs `python3 -m unittest test_progress_read`, which neither filename matching nor `import X` matching sees. The plan says the prototype found no such suite; mine found this one. Step 6(a) will then demand a `covers:` line, which is fine. Also, step 3's "anything under `tests/` that is not a `test_*.sh`" makes an edit to `test_progress_read.py` (and `tests/live/plugin_acceptance.sh`) a full 7-minute run. A `# covers: .agent/scripts/tests/test_progress_read.py` on the wrapper, with the `.py` dropped from the trigger rule, would select one suite instead.
4. **[Suggestion] The hub guard in step 7 is weak.** "Fewer than the glob count" still passes at 38 of 39. Pin a bound that a hub regression would break, for example `register_project.sh` selects at most 5 suites (2 today).
5. **[Suggestion] `dispatch_phase.sh:411` has two more claims that step 4 makes stale.** It says "pre-commit drops deleted paths; CI's all-files run covers the rest" and "it takes several minutes". Add both to step 9's check, with `test_dispatch_phase.sh:497-498`.
6. **[Suggestion, for the owner's parallel-runner decision] A parallel runner is workable but not a drop-in.**
   - The leak sweep uses one shared `RUN_TMPDIR`, swept after each suite. Run concurrently, a suite's sweep would see the other suites' sandboxes as leaks (false exit 2) and charge them to the wrong suite. Each suite needs its own guard directory, swept when that suite exits.
   - Fail-fast must kill the sibling suites' process groups. It must also still clean up or report their temp directories.
   - Output must be buffered per suite.
   - 30 of 39 suites do not set `HOME`. Any suite that writes under the real `HOME` or the real repo could race; that needs an audit first.
   - Gain is capped by the slowest chosen suite: about 57 s for a `merge_pr.sh` fix, but still 95 to 118 s for a `register_project.sh` fix. For that commit only speeding up `test_register_project.sh` meets the minute.

### Summary

The revision fixes the round-1 core problem: the bounded derivation is selective, and I reproduced its numbers. Two mechanism gaps remain, both cheap. The deletion/rename trigger reads the wrong index under `git commit -a` and the wrong side of a rename. Prefix-scanning suites, including the drift check itself, stop running when the files they scan change. Fix those, with tests that would fail against the current text, and the plan is ready.

### Recommended Actions

- [ ] Must-fix: compute the deletion check before the runner unsets `GIT_INDEX_FILE` (or with the saved value), and use `--no-renames --diff-filter=D` for both the staged and the branch-run checks. Test it through a real `git commit -a` or pathspec commit and an in-scope to out-of-scope rename.
- [ ] Must-fix: give the prefix-scanning suites `# covers:` lines with what they scan, at least `test_skill_paths.sh` (guard (c) prefixes) and `test_script_tests_hook_scope.sh` (`.agent/scripts/tests/`). Record the scan vs copy distinction next to `ROOT_READERS`, so drift check 6(b) is not read as covering them.
- [ ] Suggestion: handle `test_progress_read.sh` with a `covers:` line for `test_progress_read.py`, and drop that `.py` from the full-run trigger rule.
- [ ] Suggestion: tighten the real-tree hub guard to a small upper bound (for example at most 5 suites for `register_project.sh`).
- [ ] Suggestion: add `dispatch_phase.sh:411`'s "pre-commit drops deleted paths" and "several minutes" claims to the step 9 wording check.
- [ ] Suggestion: if the owner picks parallel running, plan per-suite TMPDIR guards, sibling kill on first failure, per-suite output buffering and a HOME/real-repo write audit. Note that `register_project.sh` fixes stay above a minute regardless.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 09:26 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (second revise in a row at plan, the last the host may answer; the two must-fixes are mechanism and cheap: the deletion check must run before the runner unsets GIT_INDEX_FILE and must use --no-renames --diff-filter=D, and the prefix-scanning suites need covers: lines)
**After**: plan
**Decision**: revise

Plan Review round 2 verdict needs-work (12f625db). Owner answers given this turn and carried into the handoff: the AGENTS.md Script Reference row edit is approved ("Yes, edit the row"); the under-a-minute acceptance is settled as "Accept ~2 min now; parallel later": scoping ships as planned, the parallel runner and the two slow suites are a follow-up (captured in the inbox), so the plan's Open Question on that closes and the parallel-runner suggestion is not taken into this plan.

## Plan Authored
**Status**: complete
**When**: 2026-10-29 09:27 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-410/plan.md` at `0270dd6a`

Revision 2: deletion check runs before GIT_INDEX_FILE is unset using --no-renames --diff-filter=D (tested through commit -a, pathspec commit and an in-scope to out-of-scope rename); prefix-scanning suites get covers lines; hub guard bounded at 5; AGENTS.md row edit approved; parallel runner moved to a follow-up.

## Plan Review
**Status**: complete
**When**: 2026-10-29 09:31 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #410 — Pre-commit script-test hook: run only the suites whose declared files changed
**Plan**: `.agent/work-plans/issue-410/plan.md` at `0270dd6a`
**Branch**: `feature/issue-410`

Round 3, narrow convergence check against the round-2 entry (12f625db) and the plan diff 5af3efe3..0270dd6a. Sections passed in rounds 1 and 2 were not re-reviewed; owner decisions (AGENTS.md row approved, about 2 minutes serial accepted, parallel runner a follow-up) are settled.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged; one PR |
| Issue alignment | Good | Serves, as checked: "Quality of the work and review-loop wall-clock (README Workspace goals); `docs/design.md#rules` and `docs/design.md#review-loop-and-timeline`". The under-a-minute gap is now recorded as the owner's decision, not an open question |
| File targeting | Good | `# covers:` row names `test_skill_paths.sh`, `test_script_tests_hook_scope.sh`, `test_progress_read.sh`; `AGENTS.md` row unconditional after the owner's yes |
| Consequences | Good | Must-fix 1 holds: step 4 computes the staged check before `GIT_INDEX_FILE` is unset (or from the saved value), uses `--no-renames --diff-filter=D` for both the staged and the `<default>...HEAD` branch-run checks, "with the same ordering". Must-fix 2 holds: both prefix-scanning suites get `# covers:` lines, and the scan-vs-copy note goes next to `ROOT_READERS`, with 6(b) scoped to real-root readers. One new interaction, finding 1 |
| Principle alignment | Good | "Test what breaks": the deletion/rename tests now go through a real hook with `git commit -a`, a pathspec commit and an in-scope to out-of-scope rename, which fail against the round-2 mechanism |
| ADR compliance | Good | No change from round 2 (ADR-0005 kept; CI still runs every hook on all files) |
| ROS conventions | N/A | Workspace plan |

Taken suggestions, all in: `test_progress_read.py` handled by a `covers:` line and exempted from the `tests/` trigger (step 3); hub guard bounded at 5 suites (step 7); `dispatch_phase.sh:411` "pre-commit drops deleted paths" and "several minutes" added to the step 9 check.

### Findings

1. **[Consequences] The new `test_skill_paths.sh` `covers:` line makes the "unmapped file runs everything" fail-safe dead.** Its guard (c) prefixes are `.agent/ .claude/ AGENTS.md Makefile`, which is nearly the whole hook scope. Read as an ordinary `covers:` mapping, every one of the 55 unmapped in-scope files (`.agent/knowledge/*.md`, `.agent/hooks/*.py`, the `.agent/*.md` guides) now maps to `test_skill_paths.sh`, so it selects one fast suite instead of `ALL`. Step 3 still says "those commits still pay the full run", which would no longer be true. The copy-into-sandbox readers (the ROOT_READERS suites, which deliberately do not select) are the suites that fail-safe protects, and they would be skipped. The same thing happens on a smaller scale with `test_script_tests_hook_scope.sh` covering `.agent/scripts/tests/`: if "a file some suite declares with `# covers:`" in step 3 matches prefixes, the "anything under `tests/` that is not a `test_*.sh`" trigger can never fire (`tests/live/plugin_acceptance.sh` would stop forcing a full run). This does not block the plan: the fix is one rule plus one test, and the implementer can apply it. Rule: a scan-prefix declaration (a distinct keyword such as `# scans:`, or `covers:` marked as a scan) **adds** its suite to the selection but does not count as a mapping for the unmapped-file rule or for the `tests/` exemption. The `tests/` exemption matches exact declared files only. Test: on the real tree, `suites_for_files.sh` given one of today's unmapped files (for example a `.agent/knowledge/*.md`) still prints `ALL`, and a synthetic `tests/` helper still prints `ALL`.
2. **[Suggestion] Name the hub guard's fourth suite.** Step 7 says "4 today: the two timed ones plus the always-run `test_checkpoint_269.sh` and any other reference", which adds up to 3 plus an unnamed one. The fourth is most likely `test_skill_paths.sh` through its new `.agent/` prefix. Name it, so the bound of 5 has a stated margin of 1.
3. **[Suggestion] Spell out two things in the rename test and the PR.** The out-of-scope rename case needs an in-scope edit staged alongside, or pre-commit never invokes the hook ("Same for" implies this, so say it). A commit whose only in-scope change is a deletion or an outbound rename still does not run the hook at all, as today, and CI is the backstop. Say that in the PR, so the "deletions force a full run" claim is not read as covering it.

### Summary

Both round-2 must-fixes are now correctly specified, with tests that would fail against the round-2 mechanism. The three taken suggestions are in. The revision adds one interaction that needs a rule at implementation: a whole-prefix scan declaration must not count as a mapping, or the unmapped-file fail-safe never fires. That is a one-rule fix with a real-tree test, carried as an implementation item rather than another plan round. Ready for implementation.

### Recommended Actions

- [ ] Implement: scan-prefix declarations (`test_skill_paths.sh`, `test_script_tests_hook_scope.sh`) add their suite but do not count as a mapping for the unmapped-file `ALL` rule or the `tests/` exemption (exact declared files only); add a real-tree test that a currently unmapped in-scope file still yields `ALL`.
- [ ] Suggestion: name the fourth suite in the `register_project.sh` hub-guard count (likely `test_skill_paths.sh`).
- [ ] Suggestion: state that the out-of-scope rename test stages an in-scope edit alongside, and note in the PR that a deletion-only commit still skips the hook (CI backstop).

## Checkpoint
**Status**: complete
**When**: 2026-10-29 09:33 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Owner, verbatim: "revise, but also launch bg agents to look into why the tests are slow, and to prepare for parallelization". Plan Review round 3 (7d267c0f) was ready with one implementation item (scan-prefix declarations must not count as a mapping for the unmapped-file ALL rule or the tests/ exemption) and two suggestions; the owner chose to fold them into the plan text first. The two background investigations (slow suites, parallel-runner readiness) are read-only and outside this plan; their reports feed the follow-up issue.

## Plan Authored
**Status**: complete
**When**: 2026-10-29 09:34 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-410/plan.md` at `481378f5`

Third revision: scan-prefix declarations add only their own suite and do not satisfy the unmapped-file or tests/ rules (real-tree test added); fourth hub-guard suite named; rename test stages an in-scope edit, deletion-only note for the PR.

## Plan Review
**Status**: complete
**When**: 2026-10-29 09:35 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #410 — Pre-commit script-test hook: run only the suites whose declared files changed
**Plan**: `.agent/work-plans/issue-410/plan.md` at `481378f5`
**Branch**: `feature/issue-410`

Round 4, narrow convergence check: only the diff `0270dd6a..481378f5` of `plan.md`, checked against the three boxes left open by round 3 (entry `7d267c0f`). Rounds 1 to 3 are not re-reviewed.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | The diff touches step 3 and step 7 only; it adds no files or steps. |
| Issue alignment | Good | Serves (checked, unchanged): "Quality of the work and review-loop wall-clock (README Workspace goals); `docs/design.md#rules` and `docs/design.md#review-loop-and-timeline`." |
| File targeting | Good | Unchanged by the diff. |
| Consequences | Good | The PR note on deletion-only commits is now in step 7, so the "deletions force a full run" claim is bounded. |
| Principle alignment | Good | "Test what breaks": the scan-prefix rule now has a real-tree test that fails if the prefixes swallow the unmapped set. |
| ADR compliance | Good | No new ADR triggers. |
| ROS conventions | N/A | Workspace plan. |

### Findings

Round 3 items, each checked against the diff:

1. **Box 1 (implement) holds.** Step 3 now defines scan-prefix declarations as a separate kind. They add their own suite for a changed file under the prefix and do not count as a mapping for the unmapped-file `ALL` rule or the `tests/` exemption. Only exact-file `# covers:` lines count, and both rule sites say "exact-file". It gives the reason: the `test_skill_paths.sh` prefixes would map all 55 files, and `.agent/scripts/tests/` would defeat the `tests/` trigger. I confirmed the prefixes in `test_skill_paths.sh` lines 31-32: `.agent/`, `.claude/`, `AGENTS.md`, `Makefile`. Step 7 adds the real-tree test, which takes a currently unmapped in-scope file and expects `ALL`.
2. **Box 2 (suggestion) holds.** The hub-guard count now names `test_skill_paths.sh`, selected through its scan prefix, as the fourth suite. The bound of 5 is left with a margin of 1.
3. **Box 3 (suggestion) holds.** The out-of-scope rename test now stages an in-scope edit alongside the rename, and says why. Step 7 also says the PR will note that a deletion-only commit still skips the hook, with CI as the backstop.

The diff introduced no new defect. One residual nit for the implementer, not a reason to withhold:

4. **[Suggestion] Keep the real-tree unmapped-file test non-circular and non-vacuous.** "Chosen at test time from the real unmapped set" means calling the mapper under test to find the input. Pick the candidate independently: for example, a tracked `.agent/knowledge/*.md` that no suite names literally, found with `grep -L` over the suites. Then assert `ALL`, and fail the test (not skip it) if no candidate is found, so it cannot pass vacuously.

### Summary

All three round-3 items are folded into the plan correctly, and the edit introduces no new defect. The plan is ready for implementation.

### Recommended Actions

- [ ] Suggestion: choose the real-tree unmapped candidate independently of `suites_for_files.sh` (for example, a `.agent/knowledge/*.md` that no suite names), and fail rather than skip when none is found.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 09:36 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (Plan Review round 4 is ready with one suggestion-only box for the implementer; the host repeat limit was reset by the owner's own revise answer at the previous plan checkpoint, so proceed is a host answer again)
**After**: plan
**Decision**: proceed

Plan at 481378f5, reviewed ready in round 4 (2d0e6231). The one open suggestion (pick the real-tree unmapped test candidate independently of suites_for_files.sh and fail rather than skip when none is found) is carried into the implement handoff. Owner answers already in the plan: the AGENTS.md row edit is approved; about 2 minutes serial per typical fix commit is accepted; the parallel runner and the slow suites are a follow-up.

## Implementation
**Status**: complete
**When**: 2026-10-29 10:03 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**PR**: #411 at `f958ce35`

Every plan step (1 to 11) is implemented, in 7 commits (a42d5dca..f958ce35):

- **New `.agent/scripts/tests/suites_for_files.sh`** (bash wrapper around embedded Python). Takes the vocabulary from the hook's `files:`/`exclude:` regexes, matched with Python `re.search` as pre-commit matches them. Strips comment lines. Matches path and basename tokens; an extensionless basename counts only inside a token with a `/`. Maps Python `import X` to `X.py`. Expands the closure through code files only. Declarations: `# covers: <file>` maps exactly and counts as a mapping. `# covers: ALL` puts the suite in every scoped run. `# scans: <prefix>` adds the suite and never counts as a mapping. It prints `ALL` for every trigger the plan lists and for any error. `--dump` prints the derived map. Mapper runtime is about 0.3 s on the real tree.
- **Declarations added**: `test_progress_read.sh` covers `test_progress_read.py`. `test_skill_paths.sh` scans `.agent/ .claude/ AGENTS.md Makefile`. `test_script_tests_hook_scope.sh` scans `.agent/scripts/tests/`. `test_plugin_manifest.sh` scans `.claude/skills/`; this is a third prefix scanner, found by grepping the suites for directory walks.
- **`run_script_tests.sh`**: new `[tests-dir] [--files <f>...]` mode. The deletion check runs before the `GIT_*` unset and uses `--no-renames --diff-filter=D`. It reads the staged index, or `<default>...HEAD` when nothing is staged. Every suite runs when the check fails, with more than 200 files, or when the mapper fails or answers ALL. `test_checkpoint_269.sh` is always added to a scoped run. The runner prints its choice and the reason.
- **`.pre-commit-config.yaml`**: entry ends in `--files`, with `pass_filenames: true` and `require_serial: true`. The comment block is reworded.
- **`test_script_tests_hook_scope.sh`** adds:
  - the entry, pass_filenames and require_serial pins;
  - drift checks (a), (b) (real-root readers; a non-suite key is checked through the suites that map it, excluding this suite) and (c);
  - the hub guard: `register_project.sh` selects at most 5 suites;
  - the all-files list (198 paths) gives ALL;
  - each of the 11 `.agent/scripts/_*.sh` helpers gives ALL as a shared helper;
  - an unmapped candidate gives ALL. Per the round-4 suggestion, the candidate is chosen without the mapper: a `.agent/knowledge/*.md` named by no tracked non-markdown file. The check fails, not skips, when none is found (today it is `agent_wait_patterns.md`).
  - Mutation-checked: a wrong covers path fails (b) and (c); a missing covers line fails (a).
- **`test_run_script_tests.sh`**: cases (l) to (p), on synthetic git repos only. They cover:
  - the mapper rules and every trigger;
  - a scoped run;
  - full runs, with the count taken from the glob;
  - real-hook deletions: `git commit -a`, a pathspec commit, a rename out of scope, plus an edit-only control;
  - the branch run, plus its staged-edit negative.
  - Mutation-checked: moving the check after the unset fails the commit -a and pathspec cases. Dropping `--no-renames` fails the rename case. Not stripping comments fails the comment case. Dropping the exact-covers exemption fails the covers case.
- **Wording** (step 9): updated `address-findings` and `run-issue` SKILL.md, `dispatch_phase.sh` lines 22 and 411 (deleted-path and "several minutes" claims reworded), and the `test_dispatch_phase.sh` assertion.
- **`AGENTS.md`** Script Reference row (owner-approved).

Measured (2026-10-29, serial, this machine):

- **Synthetic `merge_pr.sh` change**: 17 of 39 suites, 85 s. The 16 the plan's prototype counted, plus `test_progress_read.sh`, which its new covers line pulls in through `progress_read.py`.
- **Synthetic `register_project.sh` change**: 4 of 39 suites (`test_register_project`, `test_script_tests_hook_scope`, `test_checkpoint_269`, `test_skill_paths`), 72 s.
- **Final no-SKIP `pre-commit run --files $(git diff --name-only main...HEAD)`**: exit 0, every hook passed. It ran all 39 suites, as it should, because the branch changes the runner, a full-run trigger. Wall-clock 551 s (suites 547 s).
- Unmapped in-scope files today: 56. A commit that touches one still runs every suite.

For the PR description: a commit whose only in-scope change is a deletion or an outbound rename still does not invoke the hook at all (pre-commit drops the path). CI's all-files run is the backstop there.

## Local Review
**Status**: complete
**When**: 2026-10-29 10:08 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #411 at `db6547dd`
**Depth**: Deep (reason: 1541 lines over 16 files; touches the enforcement config `.pre-commit-config.yaml` and `AGENTS.md`)
**Must-fix**: 2 | **Suggestions**: 2

Specialists: static analysis (shellcheck clean on the 9 changed scripts; flake8 on the embedded Python: style only), governance, plan drift (no drift: `# scans:` is the plan's scan-prefix declaration; `test_plugin_manifest.sh` is a third scanner found by the implementer), Claude adversarial, cross-model (Gemini ran, 4 findings; Codex failed: "Selected model is at capacity"; Copilot hosted review: quota exhausted, no review). Targeted suites run under a private TMPDIR: `test_script_tests_hook_scope.sh` 239/0, `test_run_script_tests.sh` 48/0, `test_dispatch_phase.sh` 139/0, no leftovers. Plan correctness points verified in code: comment stripping before derivation; deletion check before the `GIT_*` unset with `--no-renames --diff-filter=D` in the staged and `main...HEAD` cases; `# scans:` never counts as a mapping for the unmapped-file rule or the tests/ exemption; the all-files list gives ALL; helper rule over the `_*.sh` glob; `test_run_script_tests.sh` builds synthetic repos only.

### Findings
- [x] (must-fix) Fail-open on scope mismatch: a passed file the mapper's own `files:`/`exclude:` parse calls out of scope is only noted and skipped. Reproduced: quoting the hook's `files:` value (valid YAML, same regex to pre-commit) makes every file "ignored" and every closure empty, so `--all-files` (CI) runs 35 of 39 suites and skips `test_script_tests_hook_scope.sh`, the suite that guards the hook; an absolute path or an all-out-of-scope list (Gemini 4) also gives a near-empty run. pre-commit has already filtered the list, so any passed file the mapper deems out of scope should give ALL (and/or strip YAML quotes when parsing); add a synthetic case — `.agent/scripts/tests/suites_for_files.sh:338` (parse at `:127`)
- [x] (must-fix) Roadmap row says "a fix pass and a CI run stop paying for all 39 suites"; CI runs every suite (plan step 8, runner header, hook comment). Reword (also "declared files": the map is derived) — `docs/roadmap.md:76`
- [x] (suggestion) `./adapter` / `./agent` (extensionless script run as `./name`) is not mapped: `./` is stripped before the `"/" in t` test, so the token is bare and rejected; no suite uses that spelling today — `.agent/scripts/tests/suites_for_files.sh:194`
- [x] (suggestion) The branch-deletion check runs only when nothing is staged, so `pre-commit run --files $(git diff --name-only main...HEAD)` with anything staged misses earlier branch deletions, while the SKILL.md / hook-comment wording says the branch run goes to every suite on a deletion. Key on the commit context (GIT_INDEX_FILE set by git) instead, or add "with nothing staged" to the wording — `.agent/scripts/tests/run_script_tests.sh:131`

## Implementation
**Status**: complete
**When**: 2026-10-29 10:22 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #411 at `03017e7c`
**Addressed**: Local Review at `db6547dd` (2026-10-29 10:08 -04:00)
**Commits**: `3f4ffdee`, `22a6ae07`, `6a3a5158`, `03017e7c`

### Actions
- [x] (must-fix) Fail-open on scope mismatch: a passed file the mapper's parse calls out of scope (an absolute path included) now gives ALL; the parse reads single- and double-quoted scalars and a plain value's trailing comment, refuses block scalars, and a files: regex matching no tracked file is an error (ALL); synthetic cases in test_run_script_tests.sh (l) — `.agent/scripts/tests/suites_for_files.sh`
- [x] (must-fix) Roadmap row no longer claims a CI run stops paying for all suites, and says "the changed files reach" instead of "declared files" — `docs/roadmap.md:76`
- [x] (suggestion) `./name` maps an extensionless script (the slash test reads the raw token); synthetic suite running `./tool` — `.agent/scripts/tests/suites_for_files.sh`
- [x] (suggestion) The deletion check is keyed on GIT_INDEX_FILE (git sets it for every commit hook): a commit checks its staged deletions; any other run checks the staged deletions plus the branch's, so a branch run with something staged no longer misses an earlier deletion; case (p) covers both runs and a commit — `.agent/scripts/tests/run_script_tests.sh`

Hooks: `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, every hook, in 455 s (the branch changes the runner, so every suite ran). The source entry's heading is `## Local Review`, which `review_progress.sh findings`/`check` do not select, so its four boxes were checked by direct edit in each fix commit.

## Local Review
**Status**: complete
**When**: 2026-10-29 10:26 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #411 at `4384d03d`
**Depth**: Deep (reason: whole-PR diff 1724 lines over 16 files; touches the enforcement config `.pre-commit-config.yaml` and `AGENTS.md`); round 2, scoped to the fix diff `db6547dd..03017e7c` against round 1's four findings plus a regression read of the changed files
**Must-fix**: 1 | **Suggestions**: 2

Round 1's four findings are fixed as claimed: a passed file the mapper's parse rejects (an absolute path included) gives ALL; the YAML parse reads plain, single- and double-quoted one-line scalars and a plain value's trailing comment, refuses block scalars and unclosed quotes, and a files: regex matching no tracked file is an error (ALL); `./tool` maps an extensionless script; the deletion check is keyed on GIT_INDEX_FILE (a commit: staged deletions only; any other run: staged plus `main...HEAD`), and the runner header, hook comment and SKILL.md wording match it. pre-commit passes the environment unchanged to a `language: system` hook (`no_git_env` is used only for its own clones), and case (p)'s real `core.hooksPath` commit proves git sets GIT_INDEX_FILE for a plain commit. Roadmap row: smallest edit, accurate. Specialists: static analysis (shellcheck clean on the 3 changed scripts), governance, plan drift (none), Claude adversarial (3 suggestions, 1 kept), cross-model (Gemini ran, 4 suggestions, 1 kept: basename over-matching only widens a run, the `pwd` vs tests-dir point has no real caller, the #332 roadmap row was an intended commit `4d1cdee3`; Codex ran, 1 must-fix, reproduced here; Copilot hosted review: quota exhausted, no review). Targeted suites under a private TMPDIR: `test_run_script_tests.sh` 56/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers. Convergence: round 2, 1 mechanical must-fix (prev 2), not rising — `review_progress.sh verdict` says ship recommended after the fix.

### Findings
- [x] (must-fix) The deletion check reads `git diff --name-only` without `-z`, so git C-quotes a non-ASCII path (`".agent/scripts/caf\303\251.sh"`, confirmed); the quoted path fails the mapper's anchored scope regex and an in-scope deletion no longer forces ALL. Read both deletion queries NUL-delimited (`-z`, `mapfile -d ''`) and add a synthetic non-ASCII deletion case — `.agent/scripts/tests/run_script_tests.sh:135,143`
- [x] (suggestion) The quoted-scalar `yaml_case` cases never prove `exclude:` was parsed: a mis-stripped exclude regex matches nothing and gives the same selection. Add a probe that depends on the exclude (pass a tracked `.agent/work-plans/` file, expect ALL) — `.agent/scripts/tests/test_run_script_tests.sh:530`
- [x] (suggestion) `from pkg import mod` maps only `pkg`, not `mod.py`; a suite importing a module that way is not selected when another suite already maps it (no such import in the tree today; `.agent/scripts/lib/` is a package) — `.agent/scripts/tests/suites_for_files.sh:189`

## Implementation
**Status**: complete
**When**: 2026-10-29 10:38 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a59fddc42ed513466, resume 1 of 3)

**PR**: #411 at `79b9f12c`
**Addressed**: Local Review at `4384d03d` (2026-10-29 10:26 -04:00)
**Commits**: `1dfaa50d`, `2aafe78c`, `79b9f12c`

### Actions
- [x] (must-fix) Both deletion queries read NUL-delimited (`git diff -z`, `mapfile -d ''`, git's exit status kept through `wait $!`), so a non-ASCII deleted path is no longer C-quoted; synthetic cases: a commit deleting `café.sh` (case o) and a branch run after one (case q), both failing on the old runner — `.agent/scripts/tests/run_script_tests.sh:131`
- [x] (suggestion) Exclude probe: the synthetic repo tracks a work-plans file test_alpha.sh names; every yaml_case also passes it (parsed exclude: ALL; lost: test_alpha.sh), and a case with an exclude that excludes nothing shows the probe tells them apart — `.agent/scripts/tests/test_run_script_tests.sh`
- [x] (suggestion) `from pkg import mod` maps `mod.py` as well as `pkg.py` (one line, parentheses allowed); synthetic suite running `from pkg import mod_y` — `.agent/scripts/tests/suites_for_files.sh`

Hooks: `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, every hook, in 442 s (the branch changes the runner, so every suite ran). The source entry is a PR-mode `## Local Review`, which `review_progress.sh findings`/`check` do not select, so its three boxes were checked by direct edit in each fix commit.

## Local Review
**Status**: complete
**When**: 2026-10-29 10:41 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a179d7297ea6933f7, resume 1 of 3)

**PR**: #411 at `71281825`
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 1

Scope: round 2's findings (1 must-fix, 2 suggestions) and the fix diff `4384d03d..79b9f12c` (`1dfaa50d`, `2aafe78c`, `79b9f12c`). All three hold: both deletion queries read `git diff -z` through `git_paths_z` (`mapfile -d ''`, `wait "$!"`), and git's failure still sets the error (checked here with a bad ref: rc=1; a slow failing command also caught, per the adversarial pass); the commit deleting `café.sh` (hook_case non_ascii) and the branch run after one (case q) assert the deleted name and a full run; the exclude probe (a tracked work-plans file named by test_alpha.sh, passed in every yaml_case) plus the excludes-nothing control proves `exclude:` is parsed; `from pkg import mod` and `from pkg import (mod, ...)` on one line map `mod.py`. Specialists: static analysis (shellcheck clean on the 3 changed scripts), governance and plan drift (no change since round 2), Claude adversarial (fresh: no must-fix, 1 suggestion kept). Cross-model: skipped (round-3 convergence check, per handoff). Targeted suites under a private TMPDIR: `test_run_script_tests.sh` 60/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers. Convergence: round 3, 0 must-fix (prev 1) — ship recommended.

### Findings
- [ ] (suggestion) `FROM_RE` reads only the `from ... import` line, so a name on a continuation line of a parenthesised import (`from pkg import (` / `mod_b,`) is not mapped; a suite importing a module only that way is skipped when another suite maps that module (an unmapped module still gives ALL). Join continuation lines, or run ALL on an unterminated `(`, or at least say so in the header comment, which now claims `from X import Y` maps `Y.py` — `.agent/scripts/tests/suites_for_files.sh:190,250`

## Integrated Review
**Status**: complete
**When**: 2026-10-29 10:43 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #411 at `11a0612e`
**Sources**: 3 (Local Review @ `71281825` (covers 11a0612e via bookkeeping), Copilot x4 (quota exhausted, no review content), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

Copilot's four reviews (at `4d1cdee3`, `db6547dd`, `4384d03d`, `71281825`) each say only that its quota is exhausted: no comments, nothing to triage. No conversation comments. Earlier Local Review rounds (`db6547dd`, `4384d03d`) have no open boxes; `sources` reports no dropped entries. Codex and Gemini ran inside the round-1/round-2 local reviews (Codex at capacity in round 1); their findings were folded into those entries and are closed. CI at the head: Validate Documentation and ros-manifest tests pass in both runs, Validate Adapter Contract pass in one run and pending in the other, Lint (pre-commit) pending in both.

The one open finding is kept open (suggestion, not must-fix). Verified at the head: `FROM_RE` captures only the text after `import (` on the same line, and a bare continuation-line name (`mod_b,`) is not a vocabulary token, so it maps nothing. Failure mode is real but latent: a suite whose only link to `mod_b.py` is such a continuation line is silently skipped when another suite maps `mod_b.py`. Nothing in the tree hits it today: of the two parenthesised imports tracked, `.agent/scripts/validate_workspace.py:42` (`from workspace import (`) lists functions and its module `workspace.py` is mapped from the first line, and `tools/ros-manifest/tests/test_selectors.py:5` is outside the hook's `files:` scope. CI's all-files run is the backstop. The fix is a few lines plus one synthetic case, so it is recommended before merge rather than deferred.

### Findings
- [x] (suggestion, Local Review @ `71281825`) `FROM_RE` reads only the `from ... import` line, so a name on a continuation line of a parenthesised import (`from pkg import (` / `mod_b,`) is not mapped; a suite importing a module only that way is skipped when another suite maps that module. Fix: in `Index.refs`, before the per-line import loop, join each `from X import ( ... )` span onto one line (e.g. `re.sub(r"(^\s*from\s+[\w.]+\s+import\s*\()([^)]*)\)", lambda m: m.group(1) + " ".join(m.group(2).split()) + ")", body, flags=re.M)`), and add a case to `test_script_tests_hook_scope.sh` where a suite reaches `mod_b.py` only through a continuation line — `.agent/scripts/tests/suites_for_files.sh`

### False positives
- (Copilot x4) "unable to review this pull request ... insufficient remaining quota" — not a finding; no review content to triage.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 10:44 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (one open suggestion, a few lines plus a test; the workspace quality rule says fix it rather than defer it, and merging with a finding open is the owner's answer only)
**After**: findings
**Decision**: address

Integrated Review c56bdf12 at head 11a0612e: one open suggestion, the continuation lines of a parenthesised `from pkg import (...)` are not mapped. Sent to address-findings; the owner is told and may instead say merge.

## Implementation
**Status**: complete
**When**: 2026-10-29 10:52 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a59fddc42ed513466, resume 2 of 3)

**PR**: #411 at `0e4a8717`
**Addressed**: Integrated Review at `11a0612e` (2026-10-29 10:43 -04:00)
**Commits**: `0e4a8717`

### Actions
- [x] (suggestion) Each parenthesised `from X import ( ... )` span is joined onto one line (inline ` # ...` comments dropped) before the per-line import match, so a module named only on a continuation line maps; the header comment now says so. Synthetic case in test_run_script_tests.sh (l), next to the existing from-import case: a suite reaching `pkg/mod_b.py` only through a continuation line with an inline comment; it fails on the previous mapper — `.agent/scripts/tests/suites_for_files.sh`

Hooks: `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, every hook, in 392 s. Direct suite runs under a private TMPDIR: `test_run_script_tests.sh` 61/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers.

## Local Review
**Status**: complete
**When**: 2026-10-29 10:53 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a179d7297ea6933f7, resume 2 of 3)

**PR**: #411 at `244f4db8`
**Depth**: Deep (reason: round 4 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 1

Scope: round 3's one suggestion (continuation lines of a parenthesised `from pkg import (...)`) and the fix diff `11a0612e..244f4db8` (`0e4a8717`). The fix holds: `FROM_PAREN_RE` joins a parenthesised list onto its first line, inline comments dropped, before the per-line match, and the new synthetic case (test_fromimp.sh reaches `pkg/mod_b.py` only through a continuation line with an inline comment) proves its label (`mod_b` alone is no token match). Token and single-line import matching unchanged. The tree's one multi-line import (`validate_workspace.py:42`) is plain. Specialists: static analysis (shellcheck clean on the 2 changed scripts), governance and plan drift (no change), Claude adversarial (fresh: its comment-`)` case kept below as a suggestion, a strict sub-case of round 3's suggestion; the `\s*`-under-`re.M` quadratic cost dropped, 0.5 s at 20,000 blank lines). Cross-model: skipped (round-4 convergence check, per handoff). Targeted suite under a private TMPDIR: `test_run_script_tests.sh` 61/0, no leftovers. Convergence: round 4, 0 must-fix (prev 0) — ship recommended.

### Findings
- [ ] (suggestion) A `)` inside an inline comment in a parenthesised import (`a,  # see f()`) ends `FROM_PAREN_RE`'s `[^)]*` early, so later names (`b`) are lost (confirmed); a backslash-continued `from p import a, \` loses `b` too. Fail-open only when that module is also mapped by another suite; none in the tree. Strip comments before finding the `)`, or run ALL on any `from` import the parser cannot fully read — `.agent/scripts/tests/suites_for_files.sh:193`

## Integrated Review
**Status**: complete
**When**: 2026-10-29 10:55 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a690d590879db8601, resume 1 of 3)

**PR**: #411 at `797ac2d2`
**Sources**: 3 (Local Review @ `244f4db8` (covers 797ac2d2 via bookkeeping), Copilot x7 (quota or error notices, no review content), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

The previous Integrated Review's one open finding (continuation lines of a parenthesised `from pkg import (...)`) is closed by `0e4a8717`: `sources` lists the round-3 entry as stale, and a reproduction at this head shows a continuation-line name now maps. Copilot's three new reviews (at `11a0612e`, `90249967`, `244f4db8`) are again quota or error notices with no comments. The one conversation comment is the previous decision summary. CI at `797ac2d2`: Validate Documentation and ros-manifest tests pass in both runs, Validate Adapter Contract pass in one run and pending in the other, Lint (pre-commit) pending in both.

The round-4 suggestion is kept open, verified at this head: with `FROM_PAREN_RE`'s substitution and `FROM_RE` run on `from pkg import (\n    a,  # see f()\n    b,\n)` the names read are `pkg, a` (`b` lost), and on `from p import a, \` + `    b` they are `p, a` (`b` lost). Failure mode is real and silent (a suite skipped) only when the lost module is also mapped by another suite; nothing in the tree hits it (no backslash-continued import in tracked `.sh`/`.py`; the one multi-line import, `validate_workspace.py:42`, has no comments). This is the third edge case of the same import parser in a row, so the fix recommended is the one that closes the class rather than a third patch.

### Findings
- [x] (suggestion, Local Review @ `244f4db8`) A `)` inside an inline comment in a parenthesised import (`a,  # see f()`) ends `FROM_PAREN_RE`'s `[^)]*` early, so later names (`b`) are lost; a backslash-continued `from p import a, \` loses `b` too. Fix the class: when a `from` import line is one the parser cannot fully read (an unclosed `(` after joining, a trailing `\`, or a `#` inside the parenthesised span), make the suite's selection fall back to ALL (or treat the file as referencing every `.py` in the vocabulary) instead of mapping a partial name list; add synthetic cases for both shapes — `.agent/scripts/tests/suites_for_files.sh:193`

### False positives
- (Copilot x7) "unable to review this pull request" (quota exhausted, or an error at `90249967`) — not a finding; no review content to triage.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 11:00 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: findings
**Decision**: address

Owner's answer: "Fix the class, then merge". Integrated Review 91cc10ba at head 797ac2d2 left one suggestion open, the third edge case in the same import parser (a `)` inside an inline comment, or a backslash-continued `from` import, drops the names after it). The fix closes the class: when a `from` import cannot be fully read, the suite's selection falls back to ALL instead of a partial name list, with synthetic cases for both shapes. Then a round-5 convergence check, re-triage and the merge call.

## Implementation
**Status**: complete
**When**: 2026-10-29 11:10 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a59fddc42ed513466, resume 3 of 3)

**PR**: #411 at `47787ccc`
**Addressed**: Integrated Review at `797ac2d2` (2026-10-29 10:55 -04:00)
**Commits**: `47787ccc`

### Actions
- [x] (suggestion) Fixed the class (owner: "Fix the class, then merge"). Inline comments are dropped before a `from X import ( ... )` span is joined, so a `)` in a comment no longer ends the list and that common case maps precisely. Any `import`/`from` line whose name list is still not a plain list (a `\` continuation, an unclosed `(`, `;`, `*`, anything else) makes the file count every `.py` in the vocabulary as referenced; the header comment says so. Chosen over ALL because a lost name can only be a module, so every `.py` is exactly the set it could denote, and it needs no new plumbing: it is a per-file reference, so it carries through the closure to every suite that reaches the file, a helper reached transitively included. Synthetic cases in test_run_script_tests.sh (l): a name after `)` in an inline comment (precise: test_fromimp.sh does not join mod_x.py's selection), a name after a `\` (fallback), and mod_x.py, which the fallback suite never names, selecting it (the fallback runs the suite); the unreadable import is assembled at generation time so this suite's own text does not trip the fallback. The real repository's derived map is unchanged (`--dump` before and after compared) — `.agent/scripts/tests/suites_for_files.sh`

Hooks: `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, every hook, in 404 s. Direct suite runs under a private TMPDIR: `test_run_script_tests.sh` 63/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers.

## Local Review
**Status**: complete
**When**: 2026-10-29 11:14 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a179d7297ea6933f7, resume 3 of 3)

**PR**: #411 at `0de3699a`
**Depth**: Deep (reason: round 5 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 0

Scope: round 4's suggestion and the fix diff `797ac2d2..0de3699a` (`47787ccc`), against the owner's "Fix the class, then merge". What holds: comments are dropped per line before a parenthesised list is joined, so a `)` in a comment no longer cuts it, and stripping cannot drop a real name (probed: `import helper#x`, a comment inside a list, `${#arr[@]}` on a non-import line); a line-start import that is not a plain name list (`\` continuation, unclosed `(`, `;`, `*`) counts every `.py`; the real repository's `--dump` map is unchanged (diffed old vs new, 1601 lines); the 5 changed/new expectations fail on the round-4 mapper (run in a scratch copy: 58/5) and pass now. Specialists: static analysis (shellcheck clean), governance and plan drift (no change), Claude adversarial (fresh: found the same gap independently; no spurious fallback anywhere in the tree today, prose starting `import ` would over-select safely). Cross-model: skipped (round-5 convergence check, per handoff). Targeted suites under a private TMPDIR: `test_run_script_tests.sh` 63/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers. Convergence: round 5, 1 mechanical must-fix (prev 0) — `review_progress.sh verdict` says continue (rising).

### Findings
- [x] (must-fix) The class is not closed: `FROM_RE`/`IMPORT_RE` are anchored at line start, so an import that does not start its line is never seen and the every-`.py` fallback does not fire: `python3 -c "from pkg import mod"` (the usual way a bash suite runs Python), `x = 1; import mod`, `try: import mod`, `if x: import mod` each map nothing (confirmed with `Index(vocab).refs`). The header comment's "anything but a plain name list" claim is false for them. No instance in the tree today. Treat an `import`/`from ... import` found mid-line (after `;`, `:` or a quote) as unreadable, or parse that segment, and add a synthetic `python3 -c` case; or narrow the comment to line-start imports if the owner accepts that bound — `.agent/scripts/tests/suites_for_files.sh:195,196,42`

## Implementation
**Status**: complete
**When**: 2026-10-29 11:30 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #411 at `fac2fe43`
**Addressed**: Local Review at `0de3699a` (2026-10-29 11:14 -04:00)
**Commits**: `fac2fe43`

### Actions
- [x] (must-fix) Imports that do not start their line are now found (host decision: extend, not narrow the comment). Each line is cut at every `;`, `:`, `'` and `"` (a `\` before a quote goes with it) and each piece is parsed as an import: a plain name list maps its modules, anything else makes the file count every `.py` as referenced. A `#` ends only its own piece, so an earlier `${#a[@]}` or `"#"` no longer hides an import later on the line; a parenthesised `from X import (` opened mid-line is joined across lines as before. Text after `import` that is only words, dots and commas yet not a name list is prose (Python refuses it) and is ignored: without that rule `ros2_colcon/adapter.sh`'s `"... import failed for optional layer"` message widened test_adapter.sh to every `.py`. Probed with `Index.refs`: `python3 -c "from pkg import mod"`, `x = 1; import mod`, `try: import mod`, `if x: import mod`, `else:import mod` map precisely; `$'import a\nimport b'` and a mid-line `from pkg import *` fall back. Header comment rewritten to match, residual risk now names `__import__`/`importlib`. Synthetic cases in test_run_script_tests.sh (l): test_pyc.sh (`-c "from pkg import mod_f"`, `; import mod_g`, `try: import mod_h`, plus a prose echo) selects each module precisely and does not join mod_x.py's selection; test_midstar.sh (a `from pkg import *` inside `python3 -c`, assembled at generation time) joins every `.py` selection; both read anchor.txt so the "no derived references" rule cannot mask a miss. Two labels reworded so this suite's own text does not open a parenthesised from-import. The 8 affected (l) expectations fail on the round-4 mapper (scratch copy) and pass now. Real repository `--dump` map: unchanged (1601 lines, diffed before and after). Box ticked by direct edit in `fac2fe43` (PR-mode entry, not selected by `findings`) — `.agent/scripts/tests/suites_for_files.sh`

Hooks: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, every hook (script suites and shellcheck included), in 524 s. Direct run under a private TMPDIR: `test_run_script_tests.sh` 66/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers.

## Local Review
**Status**: complete
**When**: 2026-10-29 11:35 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #411 at `92a807a7`
**Depth**: Deep (reason: round 6 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 1

Scope: round 5's must-fix and the fix diff `0de3699a..92a807a7` (`fac2fe43`). What holds: imports after `;`, `:` and a quote are now found (`python3 -c "from pkg import mod"`, `x = 1; import mod`, `try:`/`if x:` forms map precisely); a `:` in surrounding code (`d = {1: 2}; from pkg import (a,` + newline + `b)`) and a `:`/`)` inside a comment of a parenthesised list do not cut the list; every parenthesised form that does not close cleanly (a quote or text after the `)`, `((a, b))`, an unclosed `(`) takes the fallback; `\` after `import` takes the fallback; no valid Python import was found that PROSE_RE dismisses except the shell-concatenation case below (fresh adversarial specialist, about 100 inputs through `Index.refs`, plus the lead's own probes). Specialists: static analysis (shellcheck clean on both files), governance and plan drift (no change since round 5), Claude adversarial (fresh; found the must-fix below). Cross-model: skipped (round-6 convergence check, per handoff). Targeted suites under a private TMPDIR: `test_run_script_tests.sh` 66/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers. Convergence: round 6, 1 mechanical must-fix (prev 1) — `review_progress.sh verdict` says recommended (fix and ship).

### Findings
- [x] (must-fix) A `\` continuation inside the `from X ... import` header still maps a partial list silently, though the header comment promises the fallback for any `\` continuation: `from pkg \` + newline + `    import a, b` maps a.py and b.py but not pkg.py; `from pkg.z \` + newline + `    import a` misses pkg.py and z.py; `from \` + newline + ` pkg import a` maps nothing (confirmed with `Index.refs`). The second line's piece is not an import and the first's does not match FROM_RE. Fix: a piece matching `^\s*(from|import)\b` that ends in `\` (after the `#` cut) counts every `.py`; add a synthetic `from pkg \` case — `.agent/scripts/tests/suites_for_files.sh:282-309`
- [x] (suggestion) A name list cut by a quote with a dangling comma is dismissed as prose: `python3 -c "import a, "'b'` maps nothing (Python runs `import a, b`). Only a shell concatenation of quote styles mid-import produces it; narrowing PROSE_RE to refuse a trailing comma (only two names side by side are prose) would send it to the fallback; check `--dump` stays 1601 lines — `.agent/scripts/tests/suites_for_files.sh:224,300`

## Implementation
**Status**: complete
**When**: 2026-10-29 11:54 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af6fdb4891bd180cc, resume 1 of 3)

**PR**: #411 at `63a57508`
**Addressed**: Local Review at `92a807a7` (2026-10-29 11:35 -04:00)
**Commits**: `63a57508`

### Actions
- [x] (must-fix) A `\` in the `from X` header no longer maps a partial list. Instead of patching the shape, the host-directed structural backstop: every `import` word that could be Python is either the keyword of a clean statement (exactly one import word, plain name list, no string glued onto its closing quote), whose names are mapped, or it sends the file to the every-.py fallback; mid-piece words included (`echo import x | python3`). A bare `from X` header (at most a module name) ending in `\` or with a string glued on falls back, as does an import whose `from X` header is the piece before. Lines are also cut at escaped `\n`/`\r`/`\t`; a comment is now a `#` at a piece start or after a blank (so `${#a[@]}` hides nothing). Header comment rewritten around the promise "every import word is either mapped exactly or widens to every .py" — `.agent/scripts/tests/suites_for_files.sh`
- [x] (suggestion) The dangling comma (`"import a, "'b'`) now falls back; PROSE_RE is gone. Reconciling the host's prose direction: an import word is ignored only when no Python statement can hold what follows it — a `-` (`vcs import --skip-existing`) or a plain name, a blank and a second name that is not `as` (`import failed for optional layer`), which Python rejects whatever the shell appends. Without it the ros2_colcon adapter's `vcs import` lines sent about 29 suites into the fallback (measured), not just test_adapter.sh. The mapper's own patterns spell the keyword `\x69mport` and the test file passes keywords through variables, so neither file trips the fallback — `.agent/scripts/tests/suites_for_files.sh`

Synthetic `shape_case` cases in test_run_script_tests.sh (l), each a lone suite reading anchor.txt: the three `\` header shapes, the dangling comma, a clean list with a glued string, a `from pkg` header glued to its import and an unreadable import line each select the suite for a .py it never names (6 of these fail on the round-5 mapper); an escaped-newline import, the prose message and `vcs import --skip-existing` do not. Real repository `--dump`: unchanged, 1601 lines, diffed before and after; no real file takes the fallback. Both boxes ticked by direct edit in `63a57508` (PR-mode entry).

Hooks: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, every hook (script suites and shellcheck included), in 531 s. Direct run under a private TMPDIR: `test_run_script_tests.sh` 76/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers.

## Local Review
**Status**: complete
**When**: 2026-10-29 11:57 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent aa4121f4bda159108, resume 1 of 3)

**PR**: #411 at `dae905cf`
**Depth**: Deep (reason: round 7 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 0

Scope: round 6's two findings and the fix diff `92a807a7..dae905cf` (`63a57508`). What holds: the three `\` header shapes and the dangling comma (`"import a, "'b'`) now fall back; glued strings, a mid-piece `import`, `\n`-escaped imports and `${#a[@]}` behave as claimed. The prose rule (NOT_PYTHON_RE) has no valid Python counter-example: `import a as b`, `import a  as  b, c` and `import a ,b` map exactly; `import a. b` and `import a .b` (valid, a.b) fall back; every input it dismisses (`import a b`, `import failed for layer`, `vcs import --x`, `import a<TAB>b`) is a syntax error. The real repository's `--dump` is unchanged at 1601 lines. Static analysis: shellcheck is clean on both files. Governance and plan drift: no change since round 5. Claude adversarial: a lead probe through `Index.refs`; no fresh subagent this round, because this is a resumed narrow check. Cross-model: skipped (round-7 convergence check, per handoff). Targeted suites under a private TMPDIR: `test_run_script_tests.sh` 76/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers. Convergence: round 7, 1 mechanical must-fix (prev 1). `review_progress.sh verdict` says recommended (fix and ship).

### Findings
- [x] (must-fix) A relative import written without a blank before `import` is valid Python but silently maps nothing. `from .import a` maps nothing (`ast.parse` gives ImportFrom level=1, names a), and so do `from ..import a, b` and `from .import(a)`. IMPORT_WORD_RE's lookbehind excludes a word preceded by `.`, so the word is not counted; FROM_RE needs `\s+` before `import`; FROM_HEAD_RE does not match either. As a result neither the mapping nor the fallback fires. No instance exists in the tree today. Fix: let FROM_RE take a dots-only module with `\s*` before the keyword (`from\s*(\.+)\s*import` beside the current form), or at least count a `.import` word whose dot is not preceded by a word character, so it falls back. Add a synthetic `from .import` case and check that `--dump` stays at 1601 lines — `.agent/scripts/tests/suites_for_files.sh:226,242`

## Implementation
**Status**: complete
**When**: 2026-10-29 12:13 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af6fdb4891bd180cc, resume 2 of 3)

**PR**: #411 at `95588362`
**Addressed**: Local Review at `dae905cf` (2026-10-29 11:57 -04:00)
**Commits**: `95588362`

### Actions
- [x] (must-fix) `from .import a` and its kin now map (host direction, two changes). (1) A `.py` file's imports are read with Python's `ast`, exactly: a relative import resolves against the file's own directory (each further dot one level up) to the module file or its package init file and to each name as a possible submodule; an absolute one maps each dotted component by basename as before; a file `ast` cannot parse, or a star import, takes the every-.py fallback. The piece parser now runs only on Python embedded in other files. (2) In the piece parser a `from` module may be dots alone touching the keyword (`from .import a`, `from ..import(a)`), and an `import` word after a dot counts unless that dot follows a word character (`x.import`). The header states both paths; residual risk now names Python held in a `.py` file's string literals, which `ast` does not read. The new init-file literal is split so the mapper's own text does not reference every package init file by basename. Synthetic cases in test_run_script_tests.sh (l): rel/helper.py, reached by a suite, maps `from .import`, `from ..import a, b`, `from .import(b)`, a try-wrapped import and a parenthesised multi-line list exactly, while a same-named decoy elsewhere and an unimported sibling stay unselected; a `.py` file with a syntax error falls back; a shell `python3 -c "from .import rel_y"` maps rel_y.py. 6 of these fail on the round-6 mapper. Real repository `--dump`: unchanged, 1601 lines, diffed against the HEAD tree in a temporary worktree (no pair added or removed). Box ticked by direct edit in `95588362` (PR-mode entry) — `.agent/scripts/tests/suites_for_files.sh`

Hooks: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, every hook (script suites and shellcheck included), in 606 s. Direct run under a private TMPDIR: `test_run_script_tests.sh` 87/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers.

## Local Review
**Status**: complete
**When**: 2026-10-29 12:16 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent aa4121f4bda159108, resume 2 of 3)

**PR**: #411 at `8ae7b355`
**Depth**: Deep (reason: round 8 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 1

Scope: round 7's must-fix and the fix diff `dae905cf..8ae7b355` (`95588362`). What holds:
- Relative imports in a `.py` resolve correctly, probed through `Index.refs`. `from .. import x` in `pkg/sub/mod.py` maps `pkg/__init__.py`, `pkg/x.py` and `pkg/x/__init__.py`. `from . import y`, `from .import y`, `from .y import z` and `from ...pkg.x import q` resolve as documented.
- `ast` failures fall back to every `.py`: a syntax error, Python 2 `print 'x'`, a NUL byte (ValueError) and a star import all do.
- `import a.b.c` maps a, b and c by basename.
- On the shell path, `from .import a`, `from ..import(a, b)` and `from ...import a` map, and `from . . import a` falls back. `from.import a` maps nothing, but it is moot there: Python run from `-c` or stdin has no package, so a relative import can only raise ImportError.
- The real repository's `--dump` is unchanged at 1601 lines.

Specialists:
- Static analysis: shellcheck is clean on both files.
- Governance and plan drift: no change.
- Claude adversarial: a lead probe; no fresh subagent on a resumed narrow check.
- Cross-model: skipped (round-8 convergence check, per handoff).

Targeted suites under a private TMPDIR: `test_run_script_tests.sh` 87/0 and `test_script_tests_hook_scope.sh` 239/0, no leftovers. Convergence: round 8, 1 mechanical must-fix (prev 1). `review_progress.sh verdict` says recommended (fix and ship).

### Findings
- [x] (must-fix) A regression from this diff: Python held in a `.py` file's string literals is no longer read, and nothing falls back. In `s/t/test_q.py`, `subprocess.run([sys.executable, "-c", "import a"])` maps nothing, and so does `subprocess.run(["python3", "-c", "from lib import w"])`. Round 7's piece parser mapped both, and the same text in a `.sh` file still maps a.py. The header documents this as residual risk, but it is a silent miss that a `.py` test running a subprocess can produce. No instance exists in the tree today; I grepped in-scope `.py` string literals. Fix: in `_py_imports`, also hand each `ast.Constant` str holding an import word to `_embedded_imports` (OR its result into the fallback). Then drop that sentence from the header and residual risk, add a synthetic `.py` case, and check that `--dump` stays at 1601 lines — `.agent/scripts/tests/suites_for_files.sh:351-392`
- [x] (suggestion) An absolute import of a package maps nothing on either path. `import lib` maps nothing for `lib/__init__.py`, and `from lib import w` maps `lib/w.py` but not the package init, which runs too. This gap predates this diff, and no in-scope file imports a package today. Mapping `<name>/__init__.py` by directory basename for each component would make absolute imports consistent with the new relative ones — `.agent/scripts/tests/suites_for_files.sh:348`

## Implementation
**Status**: complete
**When**: 2026-10-29 12:27 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent af6fdb4891bd180cc, resume 3 of 3)

**PR**: #411 at `a414d207`
**Addressed**: Local Review at `8ae7b355`
**Commits**: `a414d207`

### Actions
- [x] (must-fix) Python held in a `.py` file's strings is read again: in `_py_imports` every `ast.Constant` str (docstrings and f-string literal parts are str constants too, so all three are covered) goes through the piece parser, and its fallback becomes the file's. Removed the header sentence and the residual-risk clause about string literals. Also, a string that ends at a closing `)`, `]` or `}` glued to its quote no longer counts as continued (a glued closer is a Python syntax error). Without that, `run([sys.executable, "-c", "import a"])` would have fallen back instead of mapping — `.agent/scripts/tests/suites_for_files.sh`
- [x] (suggestion) An absolute import of a package now maps the package's init file on both paths: each dotted component maps its `.py` by basename and the init file of any package directory with that name (`Index.by_pkg`) — `.agent/scripts/tests/suites_for_files.sh`

New synthetic cases in test_run_script_tests.sh (l): a `.py` runner reached by a suite maps str_a.py from `subprocess.run([sys.executable, "-c", "import str_a"])`, str_d.py from its docstring and str_f.py from an f-string's literal part. `from libpkg import w_mod` maps libpkg/w_mod.py and libpkg's init file, `import libpkg2` maps libpkg2's init file, and libpkg/other.py is not mapped. Five of these fail on the round-7 mapper. Real repository `--dump`: unchanged at 1601 lines, compared with the HEAD tree in a temporary worktree; no pair added or removed. Both boxes ticked by direct edit in `a414d207` (PR-mode entry).

Hooks: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed every hook, script suites and shellcheck included, in 447 s. Direct runs under a private TMPDIR: `test_run_script_tests.sh` 94/0, `test_script_tests_hook_scope.sh` 239/0, no leftovers.

## Local Review
**Status**: complete
**When**: 2026-10-29 12:30 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent aa4121f4bda159108, resume 3 of 3)

**PR**: #411 at `73d86b66`
**Depth**: Deep (reason: round 9 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 0

Scope: round 8's must-fix and suggestion and the fix diff `8ae7b355..73d86b66` (`a414d207`). What holds, probed through `Index.refs`:
- The round-8 regression is gone for str literals. `run([sys.executable, "-c", "import a"])` maps a.py, with or without a following `check=True`, and so do two such calls on one line. An f-string's literal part (`f"import a; x = {1}"`), a `textwrap.dedent("""...""")` block and Python's implicit concatenation (`"import a, " "b"`) all map exactly. `"import a, " + "b"`, `f"import {m}"` and a prose docstring fall back.
- The glued-closer rule cannot hide a Python continuation: once a quote is closed by `)`, `]` or `}`, Python cannot concatenate another string onto it, and a glued `]`/`}` hands Python a syntax error. The only bash construct it misreads is `${x:-"import a"}"b"`, where Python receives `import ab` and the mapper maps a.py. That is contrived and not a finding.
- Package init files map correctly. `import lib` maps `lib/__init__.py`; `from lib import w` maps it and `lib/w.py`; `import pkg.sub.mod` maps both inits and the module; the shell path does the same.
- The real repository's `--dump` is unchanged at 1601 lines.

Specialists:
- Static analysis: shellcheck is clean on both files.
- Governance and plan drift: no change.
- Claude adversarial: a lead probe on this resumed narrow check.
- Cross-model: skipped (round-9 convergence check, per handoff).

Targeted suites under a private TMPDIR: `test_run_script_tests.sh` 94/0 and `test_script_tests_hook_scope.sh` 239/0, no leftovers. Convergence: round 9, 1 mechanical must-fix (prev 1). `review_progress.sh verdict` says recommended (fix and ship).

### Findings
- [x] (must-fix) Bytes literals in a `.py` file are not read. `_py_imports` hands only `str` constants to the piece parser, so `subprocess.run([sys.executable, "-"], input=b"import a\n")` maps nothing and does not fall back, and neither does `subprocess.run([sys.executable, "-c", b"import a"])`. Both are valid Python, and bytes stdin is a common way for a test to feed Python to a child interpreter. No instance exists in the tree today; I grepped in-scope `.py` files. Fix: also take `bytes` constants, decoded with `errors="replace"`, and add a synthetic `input=b"..."` case — `.agent/scripts/tests/suites_for_files.sh:386`

## Implementation
**Status**: complete
**When**: 2026-10-29 12:45 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #411 at `602b9e64`
**Addressed**: Local Review at `73d86b66` (2026-10-29 12:30 -04:00)
**Commits**: 602b9e64

### Actions
- [x] (must-fix) Bytes literals in a `.py` file are now read: `_py_imports` hands `bytes` constants, decoded with `errors="replace"`, to the same piece parser as `str` constants; header comment and docstring updated; synthetic `input=b"import str_b\n"` case added beside the string-literal cases in `test_run_script_tests.sh` (failed on the previous mapper, 94/95; passes after, 95/95) — `.agent/scripts/tests/suites_for_files.sh:388`

### Notes
- The source is a PR-mode `## Local Review` entry, which `review_progress.sh findings` does not select, so its box was ticked by direct edit inside the fix commit 602b9e64, as in earlier passes.
- `suites_for_files.sh --dump` on the real tree: 1601 lines, byte-identical to the previous mapper's output.
- Fix commit made with `SKIP=validate-script-tests` (dispatched-pass rule); then `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, every hook including the script-test suite (586 s, exit 0).

## Local Review
**Status**: complete
**When**: 2026-10-29 12:48 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #411 at `fcd11d50`
**Depth**: Deep (reason: round 10 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0

Scope: round 9's one must-fix (bytes literals in a `.py` file not read) and the fix diff `73d86b66..fcd11d50` (`602b9e64` plus its progress entry). Only `suites_for_files.sh`, `test_run_script_tests.sh` and progress.md changed. Probed in a throwaway synthetic repository with `--dump`:
- `run([sys.executable, "-c", b"import a"])`, `input=b"import a\n"`, `rb"import a"` and `b"import a\x0a"` each map exactly their module, and an unnamed sibling stays unmapped.
- The decode cannot raise: `bytes.decode("utf-8", errors="replace")` substitutes U+FFFD for invalid bytes. Invalid bytes before an `import` word (`b"\xff\xfe import a"`) make the piece parser fall back to every `.py` for the file, the safe direction, not a miss.
- The round-9 mapper (`73d86b66`) maps none of those five shapes on the same fixture, so the new `input=b"import str_b\n"` case is a real regression test. It ran and passed in the suite.
- The real repository's `--dump` is unchanged at 1601 lines.

Specialists:
- Static analysis: shellcheck (`--severity=warning`) is clean on both files.
- Governance and plan drift: no change.
- Claude adversarial: a lead probe on this narrow check.
- Cross-model: skipped (round-10 convergence check, per handoff).

Targeted suites under a private TMPDIR: `test_run_script_tests.sh` 95/0 and `test_script_tests_hook_scope.sh` 239/0, no leftovers. Convergence: round 10, 0 must-fix (prev 1). `review_progress.sh verdict` says recommended.

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-10-29 12:49 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a690d590879db8601, resume 2 of 3)

**PR**: #411 at `791567b4`
**Sources**: 3 (Local Review @ `fcd11d50` (covers 791567b4 via bookkeeping), Copilot x13 since the last triage (quota notices, no review content), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

Since Integrated Review `91cc10ba`: the owner's checkpoint ("Fix the class, then merge"), six fix passes and six local reviews (rounds 5 to 10). `sources` lists the round-3 and round-4 entries as stale, with their one open box each closed by the fix passes (`0e4a8717`; then `47787ccc`, ticked at line 564). Rounds 5 to 9 each raised one must-fix, and each was ticked by the next Implementation entry. Round 10 at `fcd11d50` approved with 0 must-fix and 0 suggestions. Its only box, "No issues found. LGTM.", is the review's placeholder, not a finding, and is not carried forward. GitHub: 13 more Copilot quota notices with no comments. The two conversation comments are the earlier decision summaries. CI at `791567b4`: Validate Documentation and ros-manifest tests pass in both runs. Validate Adapter Contract passed in one run and is pending in the other. Lint (pre-commit) is pending in both. The merge follows the owner's recorded yes once CI passes.

### Findings
None open.

### False positives
- (Copilot x13) "unable to review this pull request" (quota exhausted) — not a finding; no review content to triage.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 12:50 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: merge
**Decision**: merge

Owner's answer at the round-9 merge call, verbatim: "One-line fix, then merge" (option text: fix pass, round-10 check and re-triage, then the merge script with the gate enforced). The condition is met: round 10 (791567b4) approved with 0 must-fix and 0 suggestions; Integrated Review ae12409e at head 791567b4 with nothing open. CI lint still running at this point, so the host waits for it before merge_pr.sh.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 13:17 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: merge
**Decision**: address

merge_pr.sh at 8e5099de: review gate approved, then "CI failed: Lint (pre-commit)". The hook-scope suite's hub guard asserted register_project.sh selects at most 5 suites; GitHub's checkout (PR merged with main, which now holds PR 413's project_integration_audit.sh) selects 6, local tree 4. Owner's answer: "Fix and merge": merge main into the branch, replace the fixed count with drift-proof include/exclude checks, round-11 check, re-triage, then the merge on the owner's existing yes. Also noted in CI: the runner's deletion check cannot resolve main in the shallow checkout and takes the run-everything path (correct), but the message reads like an error.

## Implementation
**Status**: complete
**When**: 2026-10-29 13:31 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a13c4c4205fa198f2, resume 1 of 3)

**PR**: #411 at `1baeccc9`
**Addressed**: CI failure at merge (hub guard count; merge from main), per Checkpoint at 13:17 (owner: "Fix and merge"); no open review box
**Commits**: 28f033fe, 96e91ac2, 1baeccc9

### Actions
- [x] Merged `origin/main` (47 commits, including PR 413) into the branch: `28f033fe`, no conflicts (AGENTS.md and docs/roadmap.md auto-merged, both sides kept). After the merge, `register_project.sh` selects 6 suites locally too, matching CI.
- [x] Hub guard made drift-proof: it now checks that the selection includes `test_register_project.sh`, excludes the unrelated `test_merge_pr.sh` and `test_cross_model_review.sh` (neither is mapped to it in `--dump`), and, apart from `test_checkpoint_269.sh`, selects at most a third of the suites, counted from the glob (5 of at most 13 of 40 today). The header comment says why, and the plan's hub-guard wording is amended with the reason. `96e91ac2` — `.agent/scripts/tests/test_script_tests_hook_scope.sh`, `.agent/work-plans/issue-410/plan.md:38`
- [x] Default-branch reason line: when `resolve_default_branch` fails, a branch run still runs every suite but now prints one plain line, `full run, all N suites: no default branch available here (shallow checkout?), so the branch's deletions cannot be listed`, with no ERROR text. Added case (r): no `main` branch in a synthetic repo. It failed on the previous runner, which printed the two-line ERROR text, and passes now. `1baeccc9` — `.agent/scripts/tests/run_script_tests.sh`, `.agent/scripts/tests/test_run_script_tests.sh`

### Notes
- `--dump` on the merged tree is 1713 lines, up from 1601 at `8e5099de`. 112 pairs were added and none removed: 66 for the new `test_project_integration_audit.sh`, plus 33 for `test_user_tier_guard.sh`, 11 for `test_skill_paths.sh` and 2 for `test_script_tests_hook_scope.sh`, which now reach PR 413's `project_integration_audit.sh` and the files it names.
- Targeted suites after the changes: `test_run_script_tests.sh` 96/0 and `test_script_tests_hook_scope.sh` 261/0.
- Fix commits were made with `SKIP=validate-script-tests`. Then `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed every hook, including the script-test suite (631 s, exit 0).

## Local Review
**Status**: complete
**When**: 2026-10-29 13:34 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #411 at `ba6614e8`
**Depth**: Standard (reason: round 11 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 11 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: the merge from main (28f033fe), the hub-guard fix (96e91ac2), the
no-default-branch reason line and case (r) (1baeccc9). Cross-model
reviewers skipped (round-11 convergence check, per handoff).

Checked:
- Merge: only AGENTS.md, docs/roadmap.md, test_script_tests_hook_scope.sh
  and test_skill_paths.sh changed on both sides. Merge vs main differs only
  by this PR's runner row (AGENTS.md) and its #410 + gz4d roadmap rows;
  merge vs the branch carries PR 413's allowlist rule, project_setting and
  audit rows, the two Deferred roadmap rows, the
  test_project_integration_audit.sh ROOT_READERS entry and the
  onboard-project section of test_skill_paths.sh. Nothing lost on either side.
- Map: --dump 1601 -> 1713 lines, 112 added, 0 removed; 66 under
  test_project_integration_audit.sh, the rest (test_user_tier_guard.sh 33,
  test_skill_paths.sh 11, this suite 2) trace to PR 413 commits 8a070061,
  fdf9cc9c and the new audit script.
- Hub guard now: 6 suites (5 besides test_checkpoint_269.sh, cap 13 = a
  third of 40); the cap scales with the glob; the two exclusions hold.
- Suites, private TMPDIR, no leftovers: test_script_tests_hook_scope.sh
  261 passed 0 failed; test_run_script_tests.sh 96 passed 0 failed (incl. r).

### Findings
- [ ] (suggestion) roadmap Direction row for #410 says "all 39 suites"; the merged tree has 40 — `docs/roadmap.md:76`
