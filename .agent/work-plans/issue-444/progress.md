---
issue: 444
---

# Issue #444 — Run the script test suites in parallel, and speed up the slowest

## Issue Review
**Status**: complete
**When**: 2026-11-10 14:05 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #444

### Scope Assessment

**Well-scoped?** Yes, with a split. P1 (parallel runner) and P2 (slow suites) are separable, and P1 has a prerequisite (make suites independent). Verdict: proceed, as two pull requests (see Recommendations).
**Right repo?** Yes. Workspace: `.agent/scripts/tests/`, `.pre-commit-config.yaml`, `script_reference.md`.
**Serves**: Easy to use (`README.md#workspace-goals`; a full run now costs more than 10 minutes per fix pass and again in CI) under `docs/design.md#registry-and-adapters` (the `test` verb row names the runner as the hook and test-gate entry).
**Design picture?** No change. The runner stays the single entry; only how it schedules suites changes.
**Dependencies**: none blocking. Points at, not redone: #410 (scoping, "parallel later"), #419 (docs-only selection; plan in `.agent/work-plans/issue-419/`), #399 (dispatched passes SKIP the hook; its text quotes the run time), #361 (flaky fixture), #305 (pgrep self-match), #136.

**How the suites run today** (read from `.agent/scripts/tests/run_script_tests.sh`):
- Serial `for s in "${run_suites[@]}"; do bash "$s"`, fail-fast: the first failing suite stops the run (exit 1). One shared guard dir `RUN_TMPDIR` (`mktemp -d --tmpdir=/tmp run-script-tests.XXXXXX`, exported as TMPDIR/TMP/TEMP), swept after every passing suite; anything left is charged to that suite (exit 2). That per-suite attribution is what breaks if two suites share `RUN_TMPDIR`.
- Callers: (1) pre-commit hook `validate-script-tests` (`.pre-commit-config.yaml:93-101`): `entry: bash .agent/scripts/tests/run_script_tests.sh --files`, `pass_filenames: true`, `require_serial: true` (that flag only stops pre-commit splitting the file list across processes; it is not about suite parallelism and stays). (2) `make lint` (`Makefile:115`) runs `pre-commit run --all-files`, which runs this hook with a file list containing the runner, a full-run trigger. (3) CI `.github/workflows/validate.yml` job "Lint (pre-commit)" runs `make lint`, so it reaches the runner through the hook; the other job runs three suites directly (`test_adapter.sh`, `test_project_registry.sh`, `test_ros2_colcon.sh`, lines 38-44), unaffected.
- Where a job count is set: inside the runner only (a `-j N` option and an env var such as `RUN_SCRIPT_TESTS_JOBS`, default computed from `nproc`). The hook entry needs no change; pre-commit does not need `-j`. **CI needs no workflow change for P1**: `make lint` -> hook -> runner, and the runner's own default applies. A workflow edit (Ask-First) would only be needed to pin the job count in CI, which the default makes unnecessary. Say so in the PR so the owner need not approve a CI change.

**Independence audit** (44 `test_*.sh` plus `test_progress_read.py`; read-and-grep, nothing run in parallel). Most of the tree is already independent: every suite is held to `TMPDIR` by the runner's lint (no absolute-/tmp mktemp) and sandboxes its own git repos; no suite binds a port, none runs `git config --global`, none touches the shared `.venv` (`test_precommit_hook_path.sh` only runs `make -pn` against a sandbox Makefile), and the sandboxes set `HOME` to a fake directory. Suspects, worst first:
1. **Runner: the shared `RUN_TMPDIR` leak sweep** (`run_script_tests.sh`, the `find "$RUN_TMPDIR" -mindepth 1` loop). With concurrent suites, suite A's live sandbox looks like suite B's leak. Fix: one subdirectory per job (`$RUN_TMPDIR/<suite>`), TMPDIR pointed at it, swept when that suite ends. This is the core change, not a suite fix.
2. **`test_cross_model_review.sh:3686-3697, 4828`**: `pgrep -f -- "$findings"`, `pkill -KILL -f`, and `pgrep -fx -- "sleep ${sleep_arg}"` match host-wide by command line. The `$findings` path is per-test and the sleep value is documented as unique, so a collision with another suite needs the same sleep argument; but they also match another worktree's concurrent run of the same suite (already true today with agents in several worktrees). Also `:4807` needs `flock`/`pgrep`. Smallest (5,676 lines) and slowest suite by size; likely the run's floor.
3. **`test_capture.sh:164-165, 234-235, 243-252`**: runs two captures in parallel and holds a `flock` for 2 s in its own sandbox. Self-contained, but timing-sensitive under CPU load (the #361 class).
4. **`test_register_project.sh:720-828, 985`** (also `test_project_file.sh:879-977`, `test_sitrep_checks.sh`): backgrounded `sleep 2` / `sleep 20` holders and polls of 100 x 0.1 s (a 10 s window) waiting for a marker; they pass or fail on load, so parallel load raises flake odds. Own sandbox, no collision.
5. **`test_plugin_manifest.sh:133`** runs `claude plugin validate .` in the real tree with the real HOME (read of the real user config; no write seen). `test_gh_create_issue.sh:41,88` and `test_resolve_work_plans_dir.sh:140` read the real repo (remote URL, toplevel). Read-only, safe in parallel; listed because they depend on the real tree, not a sandbox.
6. **Whole-tree copies from the live tree**: `cp -r "$WS_ROOT/.agent"` (and `.claude`, `.claude-plugin`) in `test_register_project.sh:94-99`, `test_session_root.sh:30`, `test_skill_prefix.sh:30`, `test_user_tier_guard.sh:137-138`, `test_user_tier_install.sh:41-43,402-403`, `test_session_start_layer.sh:117-118`, `test_script_tests_hook_scope.sh`. Read-only on the source and safe unless something writes into `.agent/` (for example `.agent/scratchpad`) during a copy; they are also the main cost in P2.
7. **`test_run_script_tests.sh`**: runs the runner against scratch directories; its guard hardcodes `/tmp` with a unique name, so nested runs are safe; its fixtures must be rechecked once the runner gains `-j` (nested runs must take `-j 1`).
8. Nothing found for ports, global git config, venv, or fixed `/tmp` names (the only `/tmp` literals are test strings: `test_resolve_work_plans_dir.sh:117`, `test_project_registry.sh:1043,1167`). Fixed names inside fake homes (`aw-accept-4242` in `test_plugin_acceptance_helpers.sh`) are under per-suite sandboxes.
The audit is by reading, so the issue's own method (shuffled order and parallel runs, ten in a row, compared with serial) stays the proof; the list above says where to look first when one differs.

**Job count.** nproc is 16 here; GitHub's ubuntu-latest runner has 4. Propose default `jobs = clamp(nproc / 4, 2, 6)` (4 on this machine, 2 in CI, never 1 on a multi-core host), hard cap 8 even when the option asks for more, `-j N` / `RUN_SCRIPT_TESTS_JOBS` to override, and `-j 1` is today's serial behaviour. Suites are CPU- and fork-heavy (git, jq, `cp -r`), other agents share the machine, and the 2026-11-09 crash came from an unbounded parallel build; a default of a quarter of the cores keeps the run below the load of a single normal agent build. Optionally hold back starting a new suite while the 1-minute load average exceeds nproc.

**Output and exit codes.** Each suite's stdout/stderr goes to its own file and is printed whole when the suite ends or at the end (failures first, then a one-line-per-suite pass list with times), never interleaved. Keep the existing lines (`=== run_script_tests: running X ===`, the full/scoped header, `all N suites passed in Ns`). The issue wants one failure not to hide another, so fail-fast goes: run all selected suites, print every failure, then exit with the code the serial fail-fast run would have given for the first failing suite in list order (1 for a failure, 2 for a leak), so callers and tests that read exit codes see no change. `test_run_script_tests.sh` pins the "stops, remaining suites not run" wording (grep `FAILED at`, `remaining suites not run`) and must be updated with it. `test_checkpoint_269.sh` still must run and be reported.

**P2: slowest suites** (timed one at a time this phase, with two other agents running the full suite on the machine, so absolute numbers are inflated): `test_register_project.sh` 56.6 s (October: 95-118 s); `test_merge_pr_gate.sh` 42.7 s (October: 57 s); `test_worktree_create.sh` 17.1 s. Not timed here: `test_cross_model_review.sh` (5,676 lines), `test_project_file.sh`, `test_user_tier_install.sh`, `test_ros2_colcon.sh`, `test_sitrep_checks.sh`, `test_project_registry.sh` (each 1,600-1,700 lines); `test_package_issue_loop.sh` is not on this branch. What reading shows: `test_register_project.sh` copies `.agent/scripts`, `project_types`, `.claude`, `.claude-plugin` into every sandbox (`:94-99`, seven sandbox builds) and waits out four `sleep 2` builds with 10 s polls; `test_merge_pr_gate.sh` builds 12+ git sandboxes with bare remotes (`:154, 488, 533, 564`); `test_worktree_create.sh` has `exec sleep 30` stubs for timeout tests (`:108, 523`; time cost depends on the script's own timeout setting, to be measured). The cheap wins are one shared pristine copy of the tree per suite (copy once, `cp -a` or `git worktree`-free clone per case) and shortening the waited-out intervals through the code's own timeout knobs. The run's floor under P1 is the slowest single suite (about 1 minute here, 2 minutes in the October figures); lowering it needs splitting `test_cross_model_review.sh` or cheaper fixtures in `test_register_project.sh`. The first step of P2 is a per-suite timing table from the new runner (it can print one), not guesses.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | The runner already globs suites; a job pool plus per-suite TMPDIR is the whole mechanism. No new tool (no GNU parallel dependency; `xargs -P`/`wait -n` in bash suffice). |
| Enforce what matters, as simply as possible | Action needed | The leak sweep and the exit-code contract carry the guarantees today; the plan must keep both (per-suite TMPDIR, exit code of the first failing suite in list order) and pin them in `test_run_script_tests.sh` before turning parallel on. |
| Test what breaks | Action needed | Acceptance needs a repeatable independence check (shuffled + parallel x 10 against serial); script it (a `--shuffle`/seed option on the runner) so it is not a one-off. |
| Verify before claiming | Watch | Measured figures in the PR (before/after, this machine and CI) must come from runs recorded in the PR; the numbers in this review were taken under load and are not the baseline. |
| Humans are the bottleneck | OK | The motive: a full run is 10+ minutes of owner-visible waiting per merge decision. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (progress timeline) | Yes | This entry; the plan and review entries follow it. |
| CI/branch-protection (AGENTS.md Ask-First) | No | No `.github/workflows` change is needed: CI reaches the runner via `make lint`. If the owner wants a pinned CI job count, that edit is Ask-First. |
| Instruction files (AGENTS.md / CLAUDE.md) | No | `script_reference.md` and the runner/hook comments change, not AGENTS.md. |

### Consequences

- `run_script_tests.sh` header (fail-fast paragraph, exit codes, TMPDIR guard text), `.pre-commit-config.yaml` comment at the hook, and the `script_reference.md` runner row all describe serial fail-fast and must change with it.
- `test_run_script_tests.sh` pins fail-fast output and the leak sweep; it needs the new semantics, and `-j 1` for its nested runs.
- #399's rule text and #410/#419's text quote "about 12 minutes"; update to the measured figure (the issue's acceptance bullet).
- `docs/design.md` has no statement of serial execution; no design-picture edit.

### Recommendations

- Two pull requests. PR 1: make the runner parallel-safe and add the machinery with the default left at `-j 1`: per-suite TMPDIR and sweep, per-suite output files with failures-first printing, exit-code rule, shuffle/seed option, per-suite timing table, the updated runner tests; fix any suite the shuffled+parallel repeat flags (expected: few, the suspects 2-4 first). PR 2: turn the default on (`clamp(nproc/4, 2, 6)`, cap 8), record before/after on this machine and in CI, update the #399/#410/#419 text; P2 fixture work (shared tree copy in `test_register_project.sh`, bare-remote setup in `test_merge_pr_gate.sh`, waited-out timeouts) can be PR 3 or ride with PR 2 once the timing table says which suites set the floor.
- State in the plan that P1 needs no `.github/workflows` change, so no Ask-First approval is needed; pin the CI job count there only if the owner asks.
- Decide the fail-fast question in the plan: the issue says one failure must not hide another, so run all, report every failure, exit as serial would. Do not keep a parallel fail-fast.
- Mark any suite that cannot be made independent with a `# serial:` header line the runner reads (recorded reason), per the issue; expect `test_cross_model_review.sh` to be the candidate if its host-wide `pgrep`/`pkill` cannot be scoped.
- Do not time or run the full suite for acceptance while other agents are running it; the before/after run is taken on a quiet machine, serial and parallel back to back.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 14:00 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review keeps the issue's scope and proposes how to build it; its one question, whether a parallel run stops at the first failure, is how a behaviour the owner asked for works, so the host decides it and lists it for his veto)
**After**: issue-actions
**Decision**: proceed

Host read the Issue Review. Accepted as plan inputs: two pull requests (1: the runner made safe for parallel runs, each suite with its own temporary directory, per-suite output with failures first, a shuffle option and a timing table, default still one job; 2: parallel turned on by default, with before and after recorded), the slow-fixture work riding with the second or as a third; the default job count `clamp(nproc/4, 2, 6)`, a hard cap of 8, an option and an environment variable to set it, one job keeping today's behaviour; no CI workflow change. Host decision listed for the owner's veto: a run executes every selected suite, prints every failure, and exits with the code a serial run would give for the first failing suite; it does not stop at the first failure. Undoing it: an option to stop early.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 14:02 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-444/plan.md` at `0938e6d6`

Two pull requests. PR 1 (11 steps, detailed): runner with per-suite temp directory and leak sweep, job pool with whole per-suite output (failures first), -j / RUN_SCRIPT_TESTS_JOBS (default stays 1, cap 8), shuffle with printed seed, timing table, run-all with the serial exit code, a "# serial:" marker, suspects made independent, new runner tests, independence verified by 2 serial vs 10 shuffled -j 4 + 3 at -j 2 + 1 at -j 8 + 2 loaded runs. PR 2 (outline): default clamp(nproc/4,2,6), measured before/after here and in CI (2 jobs on a 4-core runner), quoted run times updated, cheap fixture work. Ten decisions listed for the owner's veto.

## Plan Review
**Status**: complete
**When**: 2026-11-10 14:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #444 — Run the script test suites in parallel, and speed up the slowest
**Plan**: `.agent/work-plans/issue-444/plan.md` at `0938e6d6`
**Branch**: `feature/issue-444`

### What was run

Two hand-run concurrency probes from this worktree (a scratchpad driver: each suite as `bash suite </dev/null &` from a non-interactive script, its own TMPDIR, whole output to a log; then rc, seconds, PASS counts, leftovers in each TMPDIR, `git status --porcelain`, worktree list, branch list, new files under `~/.claude` and `.agent/scratchpad`). Taken under load: other agents were running suites (one full `run_script_tests.sh` in another worktree), load average 2.6 to 3.4 on 16 cores.

- Round 1, 9 at once: `test_cross_model_review.sh` 143 s (920 PASS), `test_register_project.sh` 74 s, `test_project_file.sh` 63 s, `test_merge_pr_gate.sh` 57 s, `test_user_tier_install.sh` 51 s, `test_session_root.sh` 21 s, `test_worktree_create.sh` 19 s, `test_capture.sh` 4 s, `test_plugin_manifest.sh` 1 s.
- Round 2, 10 at once, with two copies each of `test_cross_model_review.sh` and `test_capture.sh` (the cross-worktree case the `sleep_arg` concern is about), plus `test_register_project.sh`, `test_project_file.sh`, `test_sitrep_checks.sh`, `test_run_script_tests.sh`, `test_dispatch_phase.sh`, `test_skill_prefix.sh`.
- Result: every suite exit 0 in both rounds; both cross-model copies 920 PASS; no file left in any per-suite TMPDIR; `git status` unchanged; nothing new in `.agent/scratchpad`; the worktree-list and branch-list changes and the `~/.claude` writes were other sessions' (timestamps and a project11 session file), not the suites'. Nothing collided. The grep-based suspect list holds; the per-suite TMPDIR (step 2) is the one change concurrency needs.
- A signal probe (below) found what the grep could not: how the runner starts a job changes the suite's signal environment.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | PR 1 is one coherent change, but carries parts the evidence does not need yet: the `# serial:` marker (step 6; no suite needed it in two probes), the `--timings` flag (the table already prints at `N > 1` and on failure), and the `sleep_arg` change (step 8; a cross-worktree issue that exists today, not one `-j` introduces; two concurrent copies passed). Build the marker only if step 10 finds a suite that needs it |
| Issue alignment | Good | Parallel runner, independence check, per-suite output, exit-code rule, before/after measurement, P2 driven by the timing table. Serves: "Easy to use (`README.md#workspace-goals`: a full run costs over 10 minutes per fix pass and again in CI) under `docs/design.md#registry-and-adapters`" — checked: `README.md` "### Easy to use" and `docs/design.md` "## Registry and adapters" exist; `docs/design.md` says nothing about serial or fail-fast |
| File targeting | Needs work | The run-time figures are not in `AGENTS.md` (grep: none there). They are in `dispatch_phase.sh:412` ("about 2 minutes for a typical fix, about 7 when every suite runs"), pinned by `test_dispatch_phase.sh:502` ("about 2 minutes"), and `.claude/skills/address-findings/SKILL.md:192-193`. The issue-419 `plan.md` is a closed record and should not be edited |
| Consequences | Needs work | Missing: `test_dispatch_phase.sh:502` pin; the argument grammar (`[tests-dir] [--files <file>...]` — `--files` swallows the rest and a leading `-j` would today be taken as the tests dir; `test_script_tests_hook_scope.sh:519` requires the hook entry to end in `--files`) |
| Principle alignment | Needs work | "Test what breaks": two must-fixes below are behaviours a parallel run changes that no planned test catches. "Only what's needed": see Scope |
| ADR compliance | Good | ADR-0013 entries in order; no `.github/workflows` change; no instruction-file change is needed at all once the figures are edited where they live |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Principle alignment] Must-fix: background jobs start with SIGINT and SIGQUIT ignored, and bash cannot trap a signal ignored on entry.** Probe in this worktree: `bash -c 'trap "echo trapped" INT; kill -INT $$'` traps when run in the foreground, but run as `... &` or `setsid -w ... &` from a non-interactive script it does not (SigIgn 0x6), and the disposition passes to every child the suite starts. With `set -m` before starting jobs it traps again (SigIgn 0x4, as in the foreground). So `-j 1` (foreground) and `-j N` (step 3, `setsid` per job) give suites different signal environments; `cross_model_review.sh`, `_cli_review.sh`, `_agy_review.sh`, `register_project.sh`, `_project_registry.sh`, `sitrep_checks.sh` and `user_tier_install.sh` all install INT traps. No current suite sends INT (grep), so nothing fails today, but the first one that does passes serially and fails in parallel. Fix: start jobs under `set -m` (each job gets its own process group, which also serves the interrupt kill, so `setsid` is not needed) with explicit `</dev/null`, and add a step-9 case: a stub suite that traps INT and signals itself passes at `-j 2` as at `-j 1`.
2. **[Principle alignment] Must-fix: removing a suite's TMPDIR right after its sweep (step 2) hides a late leak that today is caught.** A background process a passing suite leaves running that writes into TMPDIR afterwards is caught today by the next suite's sweep (wrongly charged, but caught). With the directory removed at once, the late write fails silently or lands nowhere. Keep every per-suite directory until the pool drains, then sweep all of them once more before the EXIT trap, charging any late entry to the suite that owns the directory (better attribution than today), exit 2. One extra loop and one step-9 case (a stub that backgrounds `sleep 1; touch "$TMPDIR/late"` and exits 0).
3. **[File targeting] The figures PR 2 must update are in `dispatch_phase.sh:412` and `address-findings/SKILL.md:192-193`, with `test_dispatch_phase.sh:502` pinning "about 2 minutes"; `AGENTS.md` has none, so the Ask-First listing is unnecessary.** Both texts say "about 7" for a full run while the plan measures about 12, above the 600000 ms (10 minute) Bash cap they tell dispatched passes to use: today a failing or slow full run in a dispatched pass is cut off. PR 2 fixes the figure; worth saying so.
4. **[Scope] Run-all at `-j 1` lands in PR 1 while the default is still serial**, so between the two merges a failing full run always takes the whole ~12 minutes instead of stopping early, past that 10 minute cap. Either keep fail-fast at `-j 1` until PR 2, or merge PR 2 straight after PR 1.
5. **[Consequences] Argument grammar.** State it: options (`-j`, `--shuffle`, `--show-passed`) before the optional tests dir, `--files` last; the hook keeps `RUN_SCRIPT_TESTS_JOBS` as its only channel. Add a case that `-j 2 <dir> --files ...` parses.
6. **[Principle alignment] Step 10's pass criteria need two corrections.** `FAIL:` count 0 is wrong for `test_worktree_create.sh`, which prints `  FAIL: 0` as its summary (seen in the probe); compare FAIL counts with the serial baseline as for PASS, and rely on the exit code. "No `run-script-tests.*` under `/tmp`" and "no stray `sleep`/`flock` processes" must be scoped to this run's own root and process groups, since other worktrees' runs create the same names. The same applies to the step-9 interrupt test, which will run inside every full run alongside other agents' runs: it must check the root it started, not a `/tmp` glob.
7. **[Principle alignment] Load-sensitive list is incomplete.** `test_cross_model_review.sh` has wall-clock bounds ("waits at least 5s and at most 6s", line 5284; "returns well inside the escalation window") that load can break; add it to the timing-sensitive list for the loaded runs.
8. **[Principle alignment] CI evidence for default-on is one run.** CI is the only place with a 4-vCPU host at `-j 2` and a shallow checkout, where `test_checkpoint_269.sh` fetches `origin/main` into the real repo while other suites read it (`git ls-files`, `git grep` in `test_script_tests_hook_scope.sh`). In PR 2, re-run the Lint job twice more (`gh run rerun`) and record all three.
9. **[Scope] The shuffle check as a recipe is fine** for the one-time acceptance: once `--shuffle` exists, repeating it later is one command (`run_script_tests.sh -j 4 --shuffle`), and every parallel CI run checks a new suite against its neighbours. Put that one-liner in the `script_reference.md` row so it is findable when suites are added; no checked-in script.
10. **[File targeting] Mechanism: stay in bash.** Bash 5.2 here and on `ubuntu-latest` (24.04); the runner already needs 4.4 (`mapfile -d ''`, `local -n`). Require 5.1 and use `wait -n -p pid` so the parent knows which job finished without scanning `.rc` files. A Python driver would split selection/preflight (bash) from scheduling and is not simpler.
11. **[Issue alignment] Confirmed, no change needed:** pre-commit makes one runner call for the hook (211 in-scope files, 8 KB of names, below pre-commit's 128 KiB partition limit, `require_serial: true`), so there is no nested parallelism; pre-commit has no hook timeout and shows hook output only on failure, so a quiet run changes nothing for it. Nothing outside `test_run_script_tests.sh` parses the runner's output; callers read only the exit code.
12. **[Issue alignment] Small facts:** the runner globs `test_*.sh` only (44 suites); `test_progress_read.py` runs through `test_progress_read.sh`, so "45 `test_*.sh` / `test_*.py`" is 44. Floor data for PR 2, under load: `test_cross_model_review.sh` 137-143 s against 68-74 s for the next slowest, so the plan's split-at-30% rule will very likely call for the third PR.

### Summary

The plan fits the runner as it is and the hand-run probes found no collision among the suspects, two copies of the same suite included. Two runner-mechanism points would make parallel runs differ from serial (signals ignored in background jobs) or hide a late leak (per-suite directory removed at once); both are small fixes with one test each. The run-time figures are in the dispatch rule and the address-findings skill, not `AGENTS.md`.

### Recommended Actions

- [ ] Start jobs under `set -m` with `</dev/null` instead of `setsid`; add the INT-trap stub case (finding 1)
- [ ] Keep per-suite TMPDIRs until the pool drains and sweep them all once more; add the late-write stub case (finding 2)
- [ ] Retarget PR 2's figure edits to `dispatch_phase.sh:412`, `address-findings/SKILL.md:192-193` and the `test_dispatch_phase.sh:502` pin; drop the `AGENTS.md` and issue-419 plan edits (finding 3)
- [ ] Decide run-all at `-j 1` in PR 1 vs PR 2 (finding 4); state the argument grammar (finding 5)
- [ ] Fix step 10's FAIL criterion and scope the `/tmp`/process checks to this run (finding 6)
- [ ] Optional: drop `# serial:` and `--timings` from PR 1 unless step 10 needs them; leave the `sleep_arg` change out (Scope)

## Checkpoint
**Status**: complete
**When**: 2026-11-10 14:13 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review ran 9 and then 10 suites at once by hand, twice, and nothing collided; its two must-fixes are specific instructions the implementer can follow, and this issue exists to save wall-clock time, so they are carried to implementation rather than given another plan round)
**After**: plan
**Decision**: proceed

Host read the Plan Review (needs-work, 2 must-fix, suggestions) and carries all of it to the implementer of pull request 1:
- Jobs started in the background begin with SIGINT and SIGQUIT ignored, which bash cannot trap: start jobs under `set -m` with stdin from /dev/null, and add a test in which a suite traps INT.
- A suite's temporary directory is not deleted right after its own check: keep every directory until all suites have finished, then check them all once more, so a late write is still caught as it is today.
- Stay with bash and `wait -n -p`. State and test the argument order (options, then the tests directory, with `--files` last). At one job, keep today's stop at the first failure until pull request 2 turns parallel on, so a failing full run does not get slower in between. The independence check does not require a FAIL count of 0 in a suite's own output (one suite prints "FAIL: 0" when it passes) and looks only at this run's own directory and processes. Left out of pull request 1, as the review suggests: the `# serial:` marker, the `--timings` flag and the `sleep_arg` change, since nothing collided in the reviewer's runs; they come back only if the 16-run check finds a collision.
- For pull request 2: the run-time figures to update are in `dispatch_phase.sh` and the address-findings skill, checked by `test_dispatch_phase.sh`, not in AGENTS.md; add the reviewer's timing-limited cases in the cross-model suite to the load-sensitive list; re-run the CI job twice more.

## Implementation
**Status**: partial
**When**: 2026-11-12 14:18 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-444 at `90ad6aa3`

Pull request 1's code is complete and the branch pre-commit run passed. The independence check (plan step 10) is two-thirds done: 12 of its 18 runs were made, and 6 were not. That is why the status is partial.

Done by the earlier pass (03a131a7 to 052e6543), compared with the plan as the checkpoint amended it: the one-job contract cases (step 1); one TMPDIR per suite, kept until the run ends and swept a second time (step 2); the job pool with `-j`/`--jobs`, then `RUN_SCRIPT_TESTS_JOBS`, then the default of 1, with a cap of 8; jobs started under `set -m` with stdin from /dev/null; `wait -n -p`; output printed whole, failures first; `--show-passed`; and the interrupt (step 3). Also `--shuffle[=SEED]` and the times table at more than one job (step 4); run-all with the exit code of the first failing suite in list order, while one job still stops at the first failure (step 5); the header, the hook comment and the script_reference row (step 7). Left out, as the checkpoint said: the `# serial:` marker, `--timings` and the `sleep_arg` change.

Added in this pass:
- a922e4f4: at the default, the job-count line names the count this machine suits, clamp(nproc/4, 2, 6), as the plan's pull request 2 outline says pull request 1 already prints it. The count is also kept at or below nproc, by the owner's rule that a parallel run never exceeds the CPU count. Case (u1) checks it for 16, 40, 4 and 1 CPUs through a stub nproc. The header and the reference row say so too.
- e852d31a: the one-job cases of the runner's suite name `-j 1` (step 8, suspect 7), so they keep testing one job when pull request 2 changes the default.
- da0f71af: case (u3), unmixed failure output, now runs 5 rounds as step 9 says, not 2. Case (u2) checks that every suite appears in the times table.
- 90ad6aa3: test_sitrep_checks.sh. Its interrupt cases poll for up to 5 s for the killed check to go, in place of one fixed 0.2 s wait (step 8, suspect 4). This is the one finding from step 10, described below.

Step 10, independence (a driver kept in this session's scratchpad, not checked in). Each run went in a session of its own, so its root and processes could be checked exactly:
- Runs made: 2 serial runs at `-j 1` (680 s and 694 s, both exit 0). Then 10 shuffled runs at `-j 4` with seeds 1 to 10, taking 177 to 355 s. In every run the root was removed, no process of the run was left, `git status --porcelain` was empty and `.agent/scratchpad` had no new entries. Each suite's PASS/FAIL line counts matched the serial baseline in 9 of the 10 parallel runs.
- The finding: seed 9 failed in test_sitrep_checks.sh, case "(skill 1) TERM". The killed check was still alive 0.2 s after the step exited. It passed serially and in the other 9 parallel runs. Fixed in 90ad6aa3 by a wider bound. After the fix, the suite was rerun alone (210 PASS, the baseline), but the shuffled runs were not repeated.
- Not run: the 3 runs at `-j 2`, the 1 at `-j 8` and the 2 loaded runs at `-j 4`. The batch was stopped at 14:01 while it waited for a quiet machine before its first `-j 2` run.
- Quiet: not always. Other drives' runner runs overlapped both serial runs and seeds 2, 8 and 9. The load average at the start ranged from 1.4 to 15.3, and each run's summary line records its own.
- Files under `~/.claude` newer than the start of the seed 1 run were checked: none were written by a suite (only session backups, the tool-use log, skills sync and agent-status).

Branch pre-commit run (`.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP): exit 0, every hook passed or had no files. validate-script-tests made a full run at one job, which took 865 s with another drive's pre-commit run on the machine at the same time.

For pull request 2 and the reviewers:
- Pull request 2 data, gathered under load: test_cross_model_review.sh took 156 s and test_project_integration_audit.sh 153 s at `-j 4`, so the two slowest suites are close.
- Runner sections, old line ranges on main and new ones on this branch (step 11): arguments 114-131 -> 172-215; job count (new) 216-254; deletions 132-166 -> 255-290; preflight 171-249 -> 294-372; selection 250-308 -> 373-436; guard 309-381 -> 437-555; start order (new) 556-583; parallel run (new) 584-754; one-job loop 382-419 -> 755-798; summary 420-428 -> 799-807.
- The earlier pass also added one line per finished suite (`--- <suite> passed in Ns (k of n done)`) to a parallel run's live output. The plan does not name these lines; they are printed by the runner, not by a suite.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 14:20 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: phase-failed
**Decision**: retry
**Phase**: implement

"q12 do it now"

Q12 as put to him: the implement entry is partial because 12 of the plan's 18 independence runs were made (the host interrupted the batch at 14:01, wrongly taking it for stalled); finish the remaining six now (three at two jobs, one at eight, two at four jobs under load; about 40 minutes on a quiet machine) or hold until another drive's pull request is published. The host recommended hold; he chose now. The retry makes those six runs and, since the sitrep interrupt test was changed after the shuffled runs (90ad6aa3), repeats enough shuffled runs to show the fix holds. The code is otherwise complete.

## Implementation
**Status**: complete
**When**: 2026-11-12 15:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-444 at `d3e20de9`
**Dispatch**: resumed (agent a7304691c591ccf00, resume 2 of 3)

This retry covered the plan's step 10 only. The 6 runs it still lacked are now made, and 3 shuffled four-job runs were repeated on the head that has the sitrep fix (90ad6aa3). Every run in this retry exited 0 and matched the serial baseline. No tracked file changed, apart from this entry.

All runs, with the serial baseline being serial1 (which serial2 matches). "Matches" means each of the 45 suites has the same PASS/FAIL line counts, this run's own root is removed, none of this run's processes are left, `git status --porcelain` is empty and `.agent/scratchpad` has no new entries:

| Run | Jobs | Seconds | Exit | Matches baseline |
|---|---|---|---|---|
| serial1 | 1 | 680 | 0 | baseline |
| serial2 | 1 | 694 | 0 | yes |
| j4 seeds 1-8, 10 | 4 | 177-320 | 0 | yes (each) |
| j4 seed 9 (before 90ad6aa3) | 4 | 355 | 1 | no: test_sitrep_checks.sh "(skill 1) TERM", fixed in 90ad6aa3 |
| j2_run1 | 2 | 384 | 0 | yes |
| j2_run2 | 2 | 372 | 0 | yes |
| j2_run3 | 2 | 400 | 0 | yes |
| j8_run1 | 8 | 163 | 0 | yes |
| j4_loaded1 (seed 101, 8 busy loops) | 4 | 423 | 0 | yes |
| j4_loaded2 (seed 102, 8 busy loops) | 4 | 422 | 0 | yes |
| j4 seed 9 repeat | 4 | 279 | 0 | yes |
| j4 seed 1 repeat | 4 | 199 | 0 | yes |
| j4 seed 5 repeat | 4 | 250 | 0 | yes |

Seed 9 was the run that failed before the fix. Repeated in the same order on the fixed head, it passes and matches the baseline.

Overlap with other load, as the owner accepted ("q12 do it now"): the driver no longer waits for a quiet machine. It sampled other runner processes, outside the run's own session, every 10 s.
- In this retry, every run overlapped other drives' runs. The most seen at once per run: j2_run1 4, j2_run2 3, j2_run3 2, j8_run1 2, j4_loaded1 3, j4_loaded2 1, seed 9 repeat 4, seed 1 repeat 4, seed 5 repeat 1.
- The highest 1-minute load average per run was between 6.05 (seed 1 repeat) and 18.64 (j4_loaded2).
- In the earlier batch the driver checked only at the start of each run. Other runs were going then for serial1, serial2 and seeds 2, 8 and 9.

The driver and the logs are in this session's scratchpad (`indep/`); they are not checked in, as decision D7 of the plan says. Every run named its job count. The only counts above 4 are the plan's own eight-job run and its 8 busy loops, all within the 16 CPUs.
