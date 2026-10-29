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
