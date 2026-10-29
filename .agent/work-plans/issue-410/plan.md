# Plan: Pre-commit script-test hook: run only the suites whose declared files changed

## Issue

https://github.com/rolker/agent_workspace/issues/410

## Context

The `validate-script-tests` hook runs all 39 suites (about 7 minutes). Owner: "optimise for wall-clock, not tokens"; he measured the full run as roughly a third of each 25 to 30 minute fix pass. The issue assumes `test_script_tests_hook_scope.sh` already declares, per suite, the files it reads. It does not: it declares 23 `ROOT_READERS` entries (suites that derive a real repo root) with coarse out-of-tree path prefixes (`.agent/scripts`, `.agent/`, `.claude/`), never the script under test. The suite-to-file map has to be built.

Measured here (2026-10-29, one serial run each): `test_register_project.sh` 94.8 s and 117.9 s (two runs), `test_merge_pr_gate.sh` 56.6 s, `test_project_registry.sh` 18.1 to 23.8 s, `test_sitrep_checks.sh` 16.6 s, `test_merge_pr.sh` 14.2 to 14.7 s, `test_dispatch_phase.sh` 10.9 s; the other 32 suites are each under 6 s. No helper is sourced by every suite; the 11 `.agent/scripts/_*.sh` helpers are each referenced by 1 to 14 suites.

Prototype of the bounded derivation below on the real tree (scratch script, not committed): 39 suites, no suite with an empty set, 55 in-scope files that map to no suite.

| Changed file | Suites selected | Serial time |
|---|---|---|
| `merge_pr.sh` | 16 of 39 | about 137 s (`merge_pr_gate` 56.6, `project_registry` 23.8, `sitrep_checks` 16.6, `merge_pr` 14.7, `dispatch_phase` 10.9, rest under 6 s each) |
| `register_project.sh` | 2 (`register_project`, `script_tests_hook_scope`) | about 95 to 118 s |
| `review_progress.sh` | 10 | not timed |
| `_settings.sh` (a helper; forced full run by rule) | 4 if it were mapped | n/a |
| `AGENTS.md`, `run-issue/SKILL.md` | 13 each | not timed |

Against the issue's "under a minute for a typical fix commit": neither measured commit meets it serially. `merge_pr.sh` is dominated by one 57 s suite; `register_project.sh` by one 95 to 118 s suite. Narrowing cuts 7 minutes to about 2. The owner read the acceptance as "the suites a change affects", about 2 minutes serial for a typical fix commit, and accepted that; the parallel runner and speeding up the two slow suites are a follow-up issue, not in this plan.

## Approach

1. **Derive the map, do not hand-write it, with a bounded rule.** New `.agent/scripts/tests/suites_for_files.sh` (not a `test_*.sh`, so the runner's glob ignores it; `chmod +x`).
   - **Vocabulary**: tracked paths (`git ls-files`) inside the hook's `files:` scope minus its `exclude:` (so `.agent/work-plans/` is out). The script parses the regexes from `.pre-commit-config.yaml`, the same block the scope test already parses.
   - **Matching**: a file is referenced by a text when its repo-relative path or its basename appears in it, after **comment lines (first non-blank character `#`) are stripped**. Comments and help text are what made the unbounded closure select all 39 suites for every change (the review's prototype).
   - **Python imports**: `import X` / `from X import` count as a reference to `X.py` (found while prototyping, accepted from review finding 7).
   - **Closure**: start from each suite's own references and expand only through referenced files that are code (`.sh`, `.py`); documents (`*.md`, `*.json`, `*.yaml`) are leaves. A changed file selects a suite when it is in the suite's closure or is the suite itself.
2. **Declarations only for what text cannot show.** A suite that builds paths from variables adds a `# covers: <path-or-prefix>` header line; `# covers: ALL` marks a suite that must always run. The 23 `ROOT_READERS` prefixes do **not** select suites (host decision, listed for veto): they are far too coarse (`.agent/scripts` alone would pull in 10 suites, `.agent/` 5 more, and make every script fix run `test_register_project.sh`). They feed the drift check in step 5(b) only.
3. **Fail-safe: when in doubt, run everything.** `suites_for_files.sh` prints `ALL` if any of these holds: no files were passed; any changed file is a full-run trigger (the runner, `suites_for_files.sh`, anything under `tests/` that is not a `test_*.sh` and not a file some suite declares with `# covers:` (`test_progress_read.py` is covered by `test_progress_read.sh`), `.pre-commit-config.yaml`, `Makefile`, `set_git_identity_env.sh`, and every `.agent/scripts/_*.sh` helper, matched by glob); a changed file inside the hook scope maps to no suite (55 today, mostly `.agent/knowledge/*.md`, `.agent/hooks/*.py`, the top-level `.agent/*.md` guides: those commits still pay the full run and the PR says so, so nobody reports it as a bug); the script errors. Two suites scan path prefixes rather than copy a file, so text derivation cannot see what they read and they carry `# covers:` lines naming what they scan: `test_skill_paths.sh` (the guard (c) prefixes) and `test_script_tests_hook_scope.sh` (`.agent/scripts/tests/`); the same applies to any other prefix-scanning suite the implementer finds. The scan-vs-copy distinction is recorded in a comment next to `ROOT_READERS`, so drift check 6(b) (which only checks real-root readers' declared prefixes against the derived map) is not read as covering them. A suite that derives no references **always runs** in a scoped run (it does not force a full run); the prototype found none, and the drift check (step 5a) fails if one appears without a `covers:` line. `test_checkpoint_269.sh` joins every scoped run (1.6 s): the runner's header said "present and was executed", and this makes that true again for scoped runs.
4. **Deletions and renames force a full run, computed by the runner itself** (host decision, listed for veto). pre-commit gathers staged files with `--diff-filter=ACMRTUXB` and drops `--files` paths that do not exist, so a deleted file or a rename source never reaches the hook, and the suites that still name the old path would be skipped. The runner therefore runs `ALL` when `git diff --cached --name-only --no-renames --diff-filter=D` lists a path in the hook scope (`--no-renames` makes a rename show as a deletion of its source; `--name-only --diff-filter=DR` would print the rename's destination, which is not the path the suites name). The check is computed at the very top of the runner, **before it unsets `GIT_INDEX_FILE`** (or with the value saved first): under `git commit -a` or `git commit <paths>` the hook sees a temporary index, and after the unset the diff shows nothing (reviewer-verified in a scratch repo with a real hook). When nothing is staged (the #399 branch-run case, `pre-commit run --files $(git diff --name-only main...HEAD)`), it checks `git diff --name-only --no-renames --diff-filter=D <default-branch>...HEAD` instead (default branch via `_resolve_default_branch.sh`), with the same ordering. The branch check applies only when nothing is staged, so ordinary commits on a branch with an earlier deletion are not forced full.
5. **Pass the files in.** The hook becomes `entry: bash .agent/scripts/tests/run_script_tests.sh --files`, `pass_filenames: true`, `require_serial: true` (pre-commit otherwise splits the list across parallel processes; with `require_serial` it runs one process, and 197 paths is 7.6 KB, far under the argument-length split). Runner usage: `run_script_tests.sh [tests-dir] [--files <f>...]`; with no `--files` it runs everything as today; more than 200 files also runs everything. It prints which suites it chose and why. The scope test that already parses the hook block pins the entry (ends in `--files`) and `pass_filenames: true`.
6. **Enforced drift check** in `test_script_tests_hook_scope.sh`: (a) every suite has a non-empty derived set or a `covers:` line; (b) (real-root readers only; it does not cover the prefix-scanning suites, which rely on their `covers:` lines) every `ROOT_READERS` suite's declared prefix is consistent with the derived map (the suite's derived set includes at least one tracked file under that prefix); (c) the `# covers:` prefixes exist in `git ls-files`; (d) the existing check that a root-reading suite without a declaration fails, unchanged; (e) the hook entry and `pass_filenames` pin from step 5. Residual risk, stated: a path assembled entirely at runtime from variables with no literal name anywhere is invisible to text derivation; it is caught only through (b), for real-root readers.
7. **Tests** in `test_run_script_tests.sh` and the scope test, all on synthetic directories except the two real-tree checks:
   - **Real-tree selectivity (the hub guard)**: `suites_for_files.sh .agent/scripts/register_project.sh` selects at most 5 suites (4 today: the two timed ones plus the always-run `test_checkpoint_269.sh` and any other reference; the bound is a small constant, not the glob count) and includes `test_register_project.sh`. A future hub that names everything turns this red instead of silently restoring the 7 minute run.
   - **Real-tree full-run pin**: feed `suites_for_files.sh` the real `git ls-files` list filtered by the hook's own `files:`/`exclude:` regexes (197 paths today); expect `ALL`. Do not run the real tree from inside `test_run_script_tests.sh` (it is one of the suites and would recurse).
   - Runner full mode on a synthetic dir runs all suites; the expected count is taken from the glob, not the literal 39.
   - Helper rule: iterate the glob `.agent/scripts/_*.sh` and assert each yields `ALL` (a new helper needs no edit; the implementation matches the same glob, not a list).
   - Synthetic: single script maps to a strict subset; unmapped in-scope file yields `ALL`; no files yields `ALL`; each trigger in step 3 yields `ALL`; comment-only mention does not select a suite; `import X` selects the suite naming `X.py`; a suite with no references runs in a scoped run without forcing `ALL`.
   - Deletion/rename, through a real hook in a synthetic git repo: `git commit -a` and a pathspec commit (`git commit <paths>`) that delete an in-scope script plus edit another; the runner (given only the edited file, as pre-commit would) runs `ALL`. Same for an in-scope to out-of-scope rename (source in scope, destination outside it), where the destination is not in the hook scope so only `--no-renames` exposes the source. Branch-run case: nothing staged, an earlier commit on the branch deleted an in-scope file, `--files` names another file; the runner runs `ALL`. And the negative: a deletion earlier on the branch with a staged unrelated edit does not force `ALL`.
8. **CI unchanged.** `pre-commit run --all-files` passes every in-scope tracked path; the list contains the runner, so it yields `ALL` (the earlier claim that `--all-files` passes no files was wrong once `pass_filenames` is true). CI narrowing is out of scope and not planned, per the owner's wall-clock constraint applying to the local loop. If wanted later it is a separate owner decision (it changes the Rules row `docs/design.md#rules`).
9. **Update wording** at each site: the runner header (usage, "and was executed", scoped description); the `.pre-commit-config.yaml` comment block above the hook (the `main...HEAD` command and "once, with no SKIP" now run the branch's suites); `.claude/skills/address-findings/SKILL.md:178`; `.claude/skills/run-issue/SKILL.md:325`; `.agent/scripts/dispatch_phase.sh:22` and `:411` with the assertion on that text in `test_dispatch_phase.sh:497` (update both together). Check each site still reads true; edit only the "every suite" claims. At `dispatch_phase.sh:411` also check the claims "pre-commit drops deleted paths" and "several minutes" against the new behaviour (deleted paths now force a full run, so the first no longer describes a gap; the run is about 2 minutes for a typical fix commit) and reword both.
10. **Last step: `AGENTS.md` Script Reference row** for `run_script_tests.sh` ("Run every `.agent/scripts/tests/test_*.sh` suite ...") is edited to describe the scoped mode. The owner approved this edit ("Yes, edit the row", 2026-10-29), so it is a normal implementation step, not conditional. `AGENTS.md` is itself in the hook scope; the edit is a mapped file (13 suites).
11. **Measure after building** on two real fix commits (a `merge_pr.sh` change, a `register_project.sh` change): record suites chosen and wall-clock in the PR, against the table above.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/tests/suites_for_files.sh` (new, `chmod +x`) | Derive suite set for a file list; prints suite names or `ALL` |
| `.agent/scripts/tests/run_script_tests.sh` | `--files` mode, deletion/rename check, choice logging, header comment |
| `.pre-commit-config.yaml` | `entry` ends in `--files`, `pass_filenames: true`, `require_serial: true`, comment block |
| `.agent/scripts/tests/test_script_tests_hook_scope.sh` | Drift checks and hook-entry pin (step 6) |
| `.agent/scripts/tests/test_run_script_tests.sh` | Scoped-mode, helper-rule, real-tree, deletion/rename cases (step 7) |
| `# covers:` lines in a few suites | `test_skill_paths.sh`, `test_script_tests_hook_scope.sh`, `test_progress_read.sh` (for the `.py`), and others only where text derivation cannot see the reads |
| `.claude/skills/address-findings/SKILL.md`, `.claude/skills/run-issue/SKILL.md` | #399 wording (step 9) |
| `.agent/scripts/dispatch_phase.sh`, `.agent/scripts/tests/test_dispatch_phase.sh` | #399 wording at lines 22 and 411, and its assertion (step 9) |
| `AGENTS.md` (owner approved) | Script Reference row for the runner (step 10) |

## Prior Art

The existing `ROOT_READERS` declaration and the regex check in `test_script_tests_hook_scope.sh` are kept and extended (as a drift input only). A fully hand-written suite-to-file table was rejected: it is the drift risk the issue review flagged. An unbounded closure over every file a suite names was tried in a prototype and rejected: comments and help text make it select all 39 suites for every change. `strace`-based read tracing was rejected for the hook (slow, needs privileges); it could be an occasional audit. pre-commit's own `files:` filtering is what this narrows further.

## Serves

Quality of the work and review-loop wall-clock (README Workspace goals); `docs/design.md#rules` and `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to the design picture, as CI keeps running every hook on all files.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforce what matters, as simply as possible | Map derived from comment-stripped text, one enforced drift check, default is "run it" |
| Verify before claiming | Selectivity and timings above measured on the real tree; post-build timings recorded in the PR; a real-tree test pins that narrowing happens |
| Test what breaks | Hub regression, deletion/rename (real hook, `commit -a`, pathspec, rename), helper glob and full-run pin each have a test |
| Only what's needed | No CI narrowing; no new tooling |
| Keep one current design | Rules row on CI unchanged; wording sites named |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | No | progress.md vocabulary suites keep their own triggers |
| ADR-0011 | No | Adapter not touched |
| ADR-0005 | Yes, kept | CI stays the enforcement layer and runs everything |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Runner usage | Runner header, hook comment block, #399 wording sites, `AGENTS.md` row | Yes (steps 9, 10) |
| Hook `entry` / `files:` / `pass_filenames` | Scope test parses and pins the block | Yes (steps 5, 6) |
| New helper `_*.sh` | Glob test covers it | Yes |
| Deleted or renamed in-scope file | Runner full-run trigger | Yes (step 4) |

## Open Questions

None open. Decided by the owner (2026-10-29): (1) the `AGENTS.md` Script Reference row edit is approved (step 10); (2) "Accept ~2 min now; parallel later": scoping ships as planned; a parallel runner and speeding up `test_register_project.sh` and `test_merge_pr_gate.sh` are a follow-up issue, not here.

Decided by the host, listed for the owner's veto: `ROOT_READERS` prefixes feed the drift check only; staged deletions and rename sources of in-scope files force a full run.

Any edit to a `_*.sh` helper runs the full 7 minutes (the requirement as given). If helper edits are common in fix passes, a later refinement could map helpers to their referencing suites; not planned.

## Estimated Scope

Single PR.
