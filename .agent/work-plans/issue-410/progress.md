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
