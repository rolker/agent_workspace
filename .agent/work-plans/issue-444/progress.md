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

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-13 10:32 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-444 at `c323b709`
**Base**: origin/main
**Depth**: Deep (reason: 1,360 changed lines; `.pre-commit-config.yaml` is an override trigger)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

Checked after the merge of origin/main (c323b709): the 48 suites, the three new ones from main among them (test_commit_identity.sh, test_fresh_clone_no_project.sh, test_records_write_gate.sh), all passed in one run at `-j 4 --shuffle=444` (561 s, exit 0, load average 14 to 20 with other agents' runs going); afterwards `git status --porcelain` was empty. No new suite from main uses pgrep/pkill or writes outside its sandbox (grep). Branch pre-commit with SKIP=validate-script-tests: exit 0. Cross-model: gemini and codex both complete (EXIT=0).

Dismissed, with evidence: "the EXIT trap does not run on an untrapped INT/TERM/HUP" (gemini, Claude adversarial) — bash 5.2 here runs it on all three, tested; "wait -n misses children that finished before the wait" (codex) — 400 rounds of the runner's own start/wait pattern, jobs finished before the wait, no miss; "a late leak listed first should give exit 2 over a later failure" (codex) — a one-job run stops at the failure and never sees the late leak, so exit 1 is what one job gives; "unused total, wrong k under --shuffle" (gemini) — total is used at :803, and k is list position as :757 says; "--timings, # serial:, sleep_arg missing, bash 5.1" (gemini, codex) — dropped or chosen by the plan review and its checkpoint; stopped jobs on /dev/tty — no suite or script opens /dev/tty; duplicate scoped suites — the mapper prints dict keys.

### Findings
- [x] (must-fix) Header says the runner sends KILL "to whatever is left 5 seconds later", but :614 KILLs every suite's group as soon as all suite leaders have exited, so a child still doing its own cleanup is killed at once; reword the header (or drop :614 and leave KILL to the watchdog), and add a (u8) variant with a suite that ignores the signal, so the 5 s backstop is tested at all — `.agent/scripts/tests/run_script_tests.sh:39`
- [x] (suggestion) Exits from the parallel section other than on_interrupt (a `set -u` abort, the "lost track" exit 1 at :651, a signal landing between `&` and `job_of[$!]=` at :636-638) remove RUN_ROOT under suites that keep running; have the EXIT cleanup kill the groups of `jobs -p` too — `.agent/scripts/tests/run_script_tests.sh:512`
- [x] (suggestion) An empty count or seed (`-j ""`, `--jobs=`, `--shuffle=`) falls back to the default or a random seed instead of being refused like `-j 0` — `.agent/scripts/tests/run_script_tests.sh:217`
- [x] (suggestion) (u4)'s first run cannot tell "first failing in list order" from "first to finish": both give exit 1; make the first-listed failure a leak there (the second run and (v) cover it today) — `.agent/scripts/tests/test_run_script_tests.sh:1234`

## Implementation
**Status**: complete
**When**: 2026-11-13 10:57 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-444 at `f499f06f`
**Addressed**: Local Review (Pre-Push) at `c323b709` (2026-11-13 10:32 -05:00)
**Commits**: b88b2db2, 4f0f789c, 475c53d2, f499f06f

### Actions
- [x] (must-fix) The 5-second KILL now holds as the header says. The interrupt path (now `stop_suites`) no longer KILLs every suite's group as soon as the suites have exited. It waits until their groups are empty or 5 seconds have passed since the signal, then KILLs what is left. The header now says what this costs: a process that ignores the signal waits out the 5 seconds, and a suite's `cmd &` ignores SIGINT, so the SIGINT (u8) run now takes 5 s where it took 0. Two new (u8) tests: a suite that ignores SIGTERM is KILLed by the backstop at 5 s; a child that takes a second over its own cleanup after its suite exits finishes it (1 s, before the backstop). Checked against the runner before the fix: the child's cleanup was cut short (rc 143, 0 s, no marker) — `.agent/scripts/tests/run_script_tests.sh:39`, `:619`
- [x] (suggestion) The EXIT trap (`cleanup_run`) now calls `stop_suites TERM` in a parallel run before removing the run's directory, and `stop_suites` also takes the pids `jobs -p` lists, so a suite started but not yet in `job_of` is stopped too. New (u8) test: SIGUSR1, which the runner does not trap, ends it while two suites run; both suites and their sleeps are gone and the directory is removed. Against the runner before the fix the sleeps were left running. The `&`-to-`job_of` window has no test of its own, because it cannot be hit on demand — `.agent/scripts/tests/run_script_tests.sh:530`
- [x] (suggestion) `-j ""`, `--jobs=` and `--shuffle=` are now refused (exit 1, before any suite runs) like `-j 0` or `--shuffle=x`. An empty RUN_SCRIPT_TESTS_JOBS still counts as unset. Four new `jobs_case` lines — `.agent/scripts/tests/run_script_tests.sh:228`, `:258`
- [x] (suggestion) In (u4)'s first run a failure is listed first and a leak finishes first, and the case asserts the finish order, so exit 1 can only come from list order. The second run keeps the other direction (leak listed first, failure finishing first, exit 2). This differs a little from the literal suggestion, which would have repeated the second run's direction. — `.agent/scripts/tests/test_run_script_tests.sh:1226`

### Verification
- `bash .agent/scripts/tests/test_run_script_tests.sh` alone, after each change: 154, 156, then 157 passed, 0 failed.
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only origin/main...HEAD)`, with no SKIP, on `f499f06f`: exit 0 in 834 s. Every hook passed, `validate-script-tests` among them (every suite, because the branch touches the runner, at the hook's default of one job).
- Each fix commit used `SKIP=validate-script-tests` (owner direction for this pass); every other hook ran.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-13 11:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent ae06b08c73314a845, resume 1 of 3)

**Branch**: feature/issue-444 at `b0e658f0`
**Base**: origin/main
**Depth**: Deep (reason: whole-branch diff over 200 lines; `.pre-commit-config.yaml` is an override trigger; fix round classified on the whole diff)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round 1's four findings are fixed (b88b2db2, 4f0f789c, 475c53d2, f499f06f): the 5 s KILL now holds as the header says, and (u8b) fails if the backstop is removed or moved earlier; the EXIT trap stops running suites, `$(jobs -p)` checked to list the parent's `set -m` jobs inside a command substitution; empty `-j ""`, `--jobs=`, `--shuffle=` are refused; (u4)'s first run now separates list order from finish order. Accepted: the 5 s a SIGINT stop now takes when a suite's `cmd &` ignores SIGINT (stated in the header); `test_run_script_tests.sh` alone took 52 s, 157 passed, against 58 s for the round-1 version inside a full run, so the added cases cost little. Accepted with no test: the gap between a suite's `&` and its `job_of` entry, since it cannot be hit on demand and `jobs -p` now covers it.

Ran: `bash .agent/scripts/tests/test_run_script_tests.sh` alone (157 passed, 0 failed, 52 s, load average 12); cross-model on the whole diff (`cross_model_review.sh --branch origin/main --agents gemini,codex`, both EXIT=0, as the fix-round rule requires at Deep); a fresh Claude adversarial sub-review of the fix diff. Not run, per the host: the full suite (the fix pass ran full pre-commit on f499f06f, exit 0, 834 s).

Dismissed, with evidence: the "wait -n misses children" and "late leak should give exit 2" findings again (codex; see round 1: 400 rounds without a miss, and exit 1 is what one job gives); "the second stop_suites after on_interrupt re-enters a 5 s wait" (gemini) — the SIGTERM (u8) run ends in 0 s, so it does not; "total is unused" (gemini) — read at :860 and :862; plan items `--timings`, `# serial:`, `sleep_arg` (gemini, codex) — dropped by the plan review's checkpoint.

### Findings
- [x] (suggestion) A second signal during the stop does not hurry it: `on_interrupt` resets the traps, so a second TERM or Ctrl-C makes the EXIT trap call `stop_suites TERM` again with a new 5 s deadline (the adversarial reviewer measured 6.0 s for a second TERM at 1 s); when a stop is already under way, KILL at once — `.agent/scripts/tests/run_script_tests.sh:530`
- [x] (suggestion) A suite reaped by `wait -n` leaves `job_of`, so a process it left running in its own group is not stopped by a later interrupt or the EXIT cleanup (not a regression; the second sweep catches it only if it writes to TMPDIR); keep every launched group for `stop_suites` — `.agent/scripts/tests/run_script_tests.sh:712`
- [x] (suggestion) (u4)'s finish-order check relies on 0.5 s gaps between three suites that start one after another; under load or on a 4-vCPU runner b and c can swap and fail a correct runner; widen the gaps (about 1 s and 2.5 s) — `.agent/scripts/tests/test_run_script_tests.sh:1252`
- [x] (suggestion) (u8c) bounds a 1 s cleanup by `u8_secs -le 4` measured with whole-second `date +%s` against a 5 s backstop; a 1 to 2 s stall under load fails it; measure with EPOCHREALTIME or bound against the backstop (under 5 s) — `.agent/scripts/tests/test_run_script_tests.sh:1523`

## Checkpoint
**Status**: complete
**When**: 2026-11-13 11:03 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 2 is approved with no must-fix and four suggestions; two of them, S3 and S4, are tests that can fail a correct runner under load, which is the failure the owner is paying for today, and S1 and S2 are small robustness fixes in the same file; fixing them before publishing costs one fix pass and a narrow round 3, less than a fix round after CI has started)
**After**: publish
**Decision**: address

Read: the round 2 Local Review (Pre-Push) at f1bf7501 and its reviewer's report. S1 run_script_tests.sh:530 a second signal during a stop should KILL at once; S2 :712 keep every launched process group for stop_suites; S3 test_run_script_tests.sh:1252 widen (u4)'s gaps; S4 :1523 time (u8c) with EPOCHREALTIME or bound it below 5 s. First host address at this checkpoint.

### Decisions made (owner may veto)
- Address the four suggestions before publishing rather than publish as approved — undoing it: none needed before the push; the branch can be published at f1bf7501 instead.

## Implementation
**Status**: complete
**When**: 2026-11-13 11:16 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent abfc89607fe23254d, resume 1 of 3)

**Branch**: feature/issue-444 at `f48e2101`
**Addressed**: Local Review (Pre-Push) at `b0e658f0` (2026-11-13 11:02 -05:00)
**Commits**: ddb035fd, cb3371e9, f48e2101

### Actions
- [x] (suggestion) S1: a second signal during the stop now KILLs at once. `on_interrupt` marks a stop under way, and the EXIT trap then calls `kill_now`, which KILLs every live group and the stop's watchdog, instead of starting a second 5 s stop. Its message ("stop cut short; KILLing N process group(s) at once") goes to a copy of the runner's stderr (`runner_err`, closed in the suites and the watchdog). Without the copy the line was lost: a second TERM lands in `wait ... 2>/dev/null`, and the EXIT trap runs with that redirection in place (found by tracing; the KILL itself did happen). New (u8) tests: a second SIGTERM, and a second Ctrl-C to the runner's group, sent 0.5 s into a stop that would last 5 s, end the run in 4 to 8 ms. The runner from before this pass took 5009 ms — `.agent/scripts/tests/run_script_tests.sh:545`, `:713`
- [x] (suggestion) S2: a group a reaped suite leaves with a process still in it is kept in `lingering`. It is dropped once empty, on every reap and in `live_groups`, because an empty group's number can be reused. `stop_suites` and `kill_now` reach these groups through `live_groups`. At the end of a normal run, the EXIT trap stops them after the second sweep and prints a line. Both new (u8) tests are deterministic. In the first, SIGTERM stops a sleep left by a suite the runner has already reaped; the test waits for the suite's "---" line, so the reap is certain. In the second, a run that ends normally stops such a sleep and says so. The runner from before this pass left that sleep alive — `.agent/scripts/tests/run_script_tests.sh:656`, `:783`
- [x] (suggestion) S3: (u4)'s finish order no longer depends on sleeps racing each other. Each suite records its pid. The next waits until that suite is gone (reaped by the runner, since a zombie still answers kill -0), then one more second. Each wait is capped at 30 s, so a broken chain fails the case rather than hanging it — `.agent/scripts/tests/test_run_script_tests.sh:1231`
- [x] (suggestion) S4: (u8c) and (u8b) are now timed in milliseconds with EPOCHREALTIME (`ms_now`), from before the signal. (u8c) must end under 4800 ms, against 5000 ms or more for a runner that waits out the deadline; that leaves 3.8 s of slack for its 1 s cleanup. (u8b) must end between 4900 and 10000 ms. The SIGINT/SIGTERM and SIGUSR1 (u8) cases keep their loose whole-second upper bound of 10 s — `.agent/scripts/tests/test_run_script_tests.sh:1476`

### Verification
- `bash .agent/scripts/tests/test_run_script_tests.sh` alone, three times in a row on `f48e2101`, load average 13 to 14:
  - run 1: 161 passed, 0 failed, 52 s;
  - run 2: 161 passed, 0 failed, 54 s;
  - run 3: 161 passed, 0 failed, 55 s.
  (u8c) measured 1032 to 1039 ms.
- On the owner's direction, the full `pre-commit run --files ...` pass and the full suite were skipped. `test_run_script_tests.sh` is the only suite run; the host runs the full pass before publishing.
- Every commit used `SKIP=validate-script-tests`; every other hook ran, shellcheck included, and passed.
- The behaviour of the runner from before this pass was checked with a small scratchpad script, deleted afterwards.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-13 11:21 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-444 at `3880add0`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: round 2's S1 to S4 and the fix diff f1bf7501..f48e2101 (ddb035fd, cb3371e9, f48e2101). The merge of origin/main at 3880add0 does not touch either file (empty diff stat). Cross-model: skipped (round-3 convergence check, per handoff).

All four are fixed. S1: after on_interrupt the EXIT trap calls kill_now, and the second SIGTERM and second Ctrl-C (u8) cases end in milliseconds and check the "stop cut short" line. S2: groups a reaped suite leaves non-empty go into `lingering`. They are pruned on every reap and in live_groups, and only a non-empty group is signalled. Linux does not reuse a pid while it is a live group's id, so a reused group id is only possible in the microseconds between the check and the kill, the same window as before for job_of. S3: (u4) chains finish order on pids, with a 30 s cap per wait. S4: (u8b) and (u8c) are timed in ms from before the signal.

New descriptor: `runner_err` is closed in the suites (:757) and the watchdog (:690). Every other process that gets it is short-lived and runs in the foreground (`$(jobs -p)`, `sleep 0.1`). A left-behind process therefore cannot hold a caller's pipe open. Normal runs: a suite's `setsid` children leave its group, so nothing the suites start on purpose is stopped (grep of the suites: only setsid'd holders).

Ran: `bash .agent/scripts/tests/test_run_script_tests.sh` alone once: 161 passed, 0 failed, 58 s, load average 14. Scratchpad experiments (deleted), killing only the pids they started: (a) a single SIGTERM with a suite that ignores it, 3 times: rc 143, and no spurious "stop cut short" line; (b) the finding below. One fd-listing experiment was refused by the permission checker and not run.

### Findings
- [ ] (suggestion) A signal during the end-of-run stop of a left-behind process (the new "still running at exit" path, up to 5 s if it ignores SIGTERM) ends the runner inside its EXIT trap: traps were reset at :801, and bash does not run the EXIT trap a second time, so /tmp/run-script-tests.* is left behind (reproduced: rc 143, directory still there; the watchdog KILLs the process later). Trap INT/TERM/HUP to kill_now and rm before stop_suites in that branch — `.agent/scripts/tests/run_script_tests.sh:553`
- [ ] (suggestion) kill_now KILLs `-$stop_watchdog` even after stop_suites has KILLed that watchdog (:706) and it may have been reaped, so the id is stale by then. Clear stop_watchdog after :706 — `.agent/scripts/tests/run_script_tests.sh:720`

## Checkpoint
**Status**: complete
**When**: 2026-11-13 11:36 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3, the narrow convergence check, is approved with no must-fix; its two suggestions, a signal during the end-of-run stop leaving the run's temp directory behind and a stale watchdog id in kill_now, go to triage; the host's one full pre-commit pass on 3880add0, every hook and every suite with no SKIP, exited 0 in 1069 s on a loaded machine; the entry commit e852068b after it changes progress.md only)
**After**: publish
**Decision**: publish

Read: the round 3 Local Review (Pre-Push) at e852068b and its report; the full pass output. The owner's rule of 2026-11-13 ("yes, one local run before a pr") is met by that pass.

## Integrated Review
**Status**: complete
**When**: 2026-11-13 11:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #468 at `bb125a16`
**Sources**: 2 (Local Review (Pre-Push) round 3 @ `3880add0` (covers bb125a16 via bookkeeping), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

GitHub: 0 reviews, 0 inline comments, 0 conversation comments; Copilot's automatic review is off for this repository (owner, 2026-11-12), so no check-run is awaited. CI at bb125a16: Validate Documentation, Validate Adapter Contract and ros-manifest tests pass; Lint (pre-commit) still running in both workflow runs. Rounds 1 and 2 were fixed and ticked on the timeline; only round 3's two suggestions are open, and both are valid on reading the code. Both paths are reached only with -j above 1, which is opt-in in this pull request (JOBS_DEFAULT=1, :166) and becomes the default in part 2.

### Findings
- [x] (suggestion, Local Review (Pre-Push) @ 3880add0) Valid. After the loop the INT/TERM/HUP traps are reset (:801); when cleanup_run (the EXIT trap) finds a group a suite left running, it prints "still running at exit" and calls `stop_suites TERM`, which can wait up to 5 s. A Ctrl-C or TERM in that window ends the runner with the default action; bash does not run the EXIT trap again, so `rm -rf "$RUN_ROOT"` at :556 never runs and one /tmp/run-script-tests.* directory (suite logs and scratch) is left behind; the left process is still KILLed by the watchdog. Needs a suite that leaves a process in its own group that is slow on TERM (a suite defect the runner already reports), then a signal in that window; the printed line followed by a pause invites exactly that Ctrl-C. Fix: in the elif branch of cleanup_run, before `stop_suites TERM`, trap INT/TERM/HUP to `kill_now; rm -rf "$RUN_ROOT"; exit <128+n>` (stop_suites sets stop_underway, so kill_now covers the watchdog); add a (u8) case beside the "still running at exit" test (test_run_script_tests.sh:1671) with a left process that ignores TERM, signal the runner after that line, and assert a fast exit and no RUN_ROOT — `.agent/scripts/tests/run_script_tests.sh:553`
- [x] (suggestion, Local Review (Pre-Push) @ 3880add0) Valid. stop_suites KILLs its watchdog's group at :706 but leaves `stop_watchdog` set; after every interrupted parallel run, on_interrupt exits and kill_now (:720) KILLs `-$stop_watchdog` again, by then usually reaped. It reaches a live process only if that pid has been reused as a group leader within milliseconds, which needs the pid space to wrap (very unlikely), but the result would be a KILL to an unrelated process group of the same user. Fix: `stop_watchdog=""` right after :706 (the live_groups exclusion at :661 only matters while the watchdog runs) — `.agent/scripts/tests/run_script_tests.sh:720`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-13 11:39 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (triage classified both open suggestions valid and recommends fixing them in this pull request: a few lines in cleanup_run with one test, and one line clearing stop_watchdog; part 2 of the issue turns the parallel default on and must not inherit them; under the owner's rule of 2026-11-13 a fix pass after publish runs only the touched suite and CI is the check, so the fix costs no second local full run; first host address at this checkpoint)
**After**: findings
**Decision**: address

Read: the Integrated Review at f1ecdb34 and its report. S1 run_script_tests.sh:553 a signal during the end-of-run stop leaves the run's temp directory behind; S2 run_script_tests.sh:720 kill_now signals a stale watchdog id.

## Implementation
**Status**: complete
**When**: 2026-11-13 11:45 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #468 at `0f6b78d8`
**Addressed**: Integrated Review at `bb125a16` (2026-11-13 11:38 -05:00)
**Commits**: 6b4da8f2, 0f6b78d8

### Actions
- [x] S1: a signal during the end-of-run stop left the run's directory behind. cleanup_run now traps INT/TERM/HUP to `kill_now; rm -rf "$RUN_ROOT"; exit 130/143/129` before `stop_suites TERM`. New (u8) case beside the "still running at exit" test: a suite leaves a sleep that ignores SIGTERM; after that line, SIGTERM to the runner and Ctrl-C (SIGINT to its group) each end the run in 2–52 ms with rc 143/130, "stop cut short; KILLing 1", the sleep gone and no RUN_ROOT. Checked against the pre-fix runner in a scratch harness: both cases fail there (rc 143/130 by default action, sleep alive, directory left; the harness removed it) — `.agent/scripts/tests/run_script_tests.sh:553`
- [x] S2: kill_now KILLed a stale watchdog id. stop_suites now reaps the watchdog (`wait`) and clears `stop_watchdog` right after KILLing its group. The `wait` is part of the fix, not extra: live_groups skips the watchdog only while `stop_watchdog` names it, so an unreaped watchdog still listed by `jobs -p` could otherwise be counted as a live group by kill_now after on_interrupt — `.agent/scripts/tests/run_script_tests.sh:720`

### Checks
- Full pre-commit pass and the full script suite skipped on the owner's direction (2026-11-13: one local run before a pull request, already made at 3880add0); CI on the push is the check. Both commits used `SKIP=validate-script-tests`; every other hook ran and passed (shellcheck included).
- `test_run_script_tests.sh` three times in a row on the final tree (loaded machine): 163 passed, 0 failed in 47 s; 163/0 in 47 s; 163/0 in 46 s. No new /tmp/run-script-tests.* directory after the three runs.

## Local Review
**Status**: complete
**When**: 2026-11-13 11:49 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #468 at `c327c009`
**Depth**: Deep (reason: narrow re-review of the post-publish fix pass per handoff, the owner's rule of 2026-11-13; whole-diff tier is Deep)
**Must-fix**: 0 | **Suggestions**: 1

Scope: the fix diff `git diff e852068b..0f6b78d8 -- .agent/scripts/tests/` (6b4da8f2 S1, 0f6b78d8 S2); c327c009 changes progress.md only. Cross-model: skipped (narrow fix-pass check, per handoff; the skill's round-3 trigger does not apply here, PR-mode round 1, but the owner's rule of 2026-11-13 named in the handoff does). Governance and plan drift: no change in scope since round 3 (two-hunk fix inside the runner and one test case).

Both triage findings are fixed. S1: cleanup_run traps INT/TERM/HUP before `stop_suites TERM`; the handler cannot loop: bash marks the EXIT trap in progress and does not run it again on the handler's `exit`, a second signal of the same kind is not re-entered, and one of another kind only repeats kill_now and the rm. `rm -rf "$RUN_ROOT"` cannot see an empty value: RUN_ROOT is assigned once (:520) from mktemp, the script exits before `trap cleanup_run EXIT` (:566) if that fails, and nothing reassigns it. S2: `wait "$stop_watchdog"` cannot block: the watchdog is this shell's own background child (same shell in both the on_interrupt and EXIT-trap paths) and its group was just KILLed; if it already exited, wait returns its status at once, and if bash no longer knows it, wait returns 127 at once (stderr discarded). The runner uses `set -uo pipefail`, no `-e`, so the non-zero status is harmless, and `stop_watchdog` is set from `$!` at :699 so `-u` cannot trip. After the wait the job is gone from `jobs -p`, so clearing the id does not let live_groups count it. Test timing: the success path measured 2 and 46 ms; the 3 s bound sits between that and the ~4.9 s a runner waiting out the deadline would take, so load alone will not flip it.

Ran: `bash .agent/scripts/tests/test_run_script_tests.sh` alone once: 163 passed, 0 failed, 46 s (both new u8 cases pass: SIGTERM 46 ms, SIGINT 2 ms). shellcheck --severity=warning (pre-commit's binary) on both changed files: clean.

### Findings
- [ ] (suggestion) The "still running at exit" line is printed before the new traps are installed, so a signal in the few microseconds between them takes the default action and leaves /tmp/run-script-tests.* behind; the new test signals as soon as it sees that line, so a runner descheduled right after the write would fail the test (a rare flake). Move the echo after the three `trap` lines — `.agent/scripts/tests/run_script_tests.sh:552`

## Integrated Review
**Status**: complete
**When**: 2026-11-13 11:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a6a6f8f253de032f0, resume 1 of 3)

**PR**: #468 at `5d9de7ef`
**Sources**: 2 (Local Review @ `c327c009` (covers 5d9de7ef via bookkeeping), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

GitHub: 0 reviews, 0 inline comments, 0 conversation comments (Copilot's automatic review is off). CI at 5d9de7ef: Validate Documentation and ros-manifest tests pass; Lint (pre-commit) and Validate Adapter Contract still running. The Integrated Review at bb125a16 is closed: S1 and S2 fixed in 6b4da8f2 and 0f6b78d8 (read at :552-561 and in the Implementation entry); the round-3 pre-push entry is stale. One open suggestion remains, from the pull-request-mode Local Review.

Mechanism: the ordinary tail of a signal-handling change, not a wrong design; the windows found have shrunk each round (a 5 s stop, then a stale id, now microseconds). All of them sit where the traps are reset and re-installed (:728, :801, :558), so if another one turns up, the cure is one handler installed once for the whole parallel section and the cleanup, deciding by `stop_underway`.

### Findings
- [x] (suggestion, Local Review @ c327c009) Valid. cleanup_run prints "still running at exit" (:552) before installing its INT/TERM/HUP traps (:558-560); a signal between them takes the default action inside the EXIT trap, so stop_suites never starts: no watchdog, the left process runs on until it ends by itself, and /tmp/run-script-tests.* is left behind. For a person the window is three builtins, microseconds; it matters only to something that reacts to the line. The new (u8) test does: it polls the log every 0.1 s and signals right after seeing the line. To fail, the runner must be descheduled in those microseconds for longer than the test takes to wake, run two greps and send the signal (a few ms at best, up to about 100 ms). On an idle machine that does not happen; on a heavily loaded one (load 14 to 20 seen today) it is roughly one run in thousands or rarer, and a failure costs a rerun of the suite. Fix: move the echo after the three `trap` lines; no new test needed — `.agent/scripts/tests/run_script_tests.sh:552`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-13 11:50 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the one open finding is valid and its fix is moving one echo below three trap lines, no new test; triage recommends fixing it here; it removes a possible flake in the test this pull request adds, and flaky tests under load are what cost the owner time today; second host address in a row at this checkpoint, so the next answer here is the owner's)
**After**: findings
**Decision**: address

Read: the Integrated Review at 0713d270 and its report. Finding: run_script_tests.sh:552, the "still running at exit" line is printed before the three new trap lines are installed. Triage's note on the mechanism: the ordinary tail of a signal-handling change, the window shrinking each round; if another point turns up, the cure is one handler installed once for the whole parallel section and its cleanup, which belongs to part 2 of the issue.

## Implementation
**Status**: complete
**When**: 2026-11-13 11:54 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a1af62f56eaa99a72, resume 1 of 3)

**PR**: #468 at `33b83ab7`
**Addressed**: Integrated Review at `5d9de7ef` (2026-11-13 11:50 -05:00)
**Commits**: 33b83ab7

### Actions
- [x] The "still running at exit" line was printed before cleanup_run's INT/TERM/HUP traps were installed; the echo now follows the three `trap` lines, so a signal sent on seeing the line always finds them set. No other edit, no new test — `.agent/scripts/tests/run_script_tests.sh:552`

### Checks
- Full pre-commit pass and the full script suite skipped on the owner's direction (2026-11-13: one local run before a pull request, already made at 3880add0); CI on the push is the check. The commit used `SKIP=validate-script-tests`; every other hook ran and passed (shellcheck included).
- `test_run_script_tests.sh` three times in a row on the final tree (loaded machine): 163 passed, 0 failed in 50 s; 163/0 in 45 s; 163/0 in 46 s. The end-of-run-stop case ended the run 48–49 ms after SIGTERM and 2 ms after SIGINT. No run directory of these runs left; the one new /tmp/run-script-tests.* seen afterwards belongs to another session's live `run_script_tests.sh --files` run (test_cross_model_review.sh content), not to these.

## Local Review
**Status**: complete
**When**: 2026-11-13 11:55 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent aa8210757935c59b7, resume 1 of 3)
**Verdict**: approved

**PR**: #468 at `d2916a3c`
**Depth**: Deep (reason: narrow re-review of the post-publish fix pass per handoff, the owner's rule of 2026-11-13; whole-diff tier is Deep)
**Must-fix**: 0 | **Suggestions**: 0

Scope: `git diff 0f6b78d8..33b83ab7 -- .agent/scripts/tests/`, the one fix commit 33b83ab7; d2916a3c and the entries before it change progress.md only. Cross-model: skipped (narrow fix-pass check, per handoff).

The diff is exactly the move: the "still running at exit" echo, text and redirection unchanged, now sits after the three `trap` lines in cleanup_run and before `stop_suites TERM` (:560). It still prints in every case it did before: it stays inside the same `if (( ${#live[@]} ))` branch, `trap` with a fixed handler string does not exit or fail, and nothing between the traps and the echo touches `live`. The open suggestion from the Local Review at c327c009 (echo before the traps) is fixed.

Ran: `bash .agent/scripts/tests/test_run_script_tests.sh` alone once: 163 passed, 0 failed, 47 s (end-of-run-stop cases: SIGTERM 48 ms, SIGINT 2 ms).

### Findings
None.

## Integrated Review
**Status**: complete
**When**: 2026-11-13 11:56 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a6a6f8f253de032f0, resume 2 of 3)

**PR**: #468 at `fd09c223`
**Sources**: 2 (Local Review @ `d2916a3c` (covers fd09c223 via bookkeeping), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

GitHub: 0 reviews, 0 inline comments, 0 conversation comments (Copilot's automatic review is off). CI at fd09c223: all four checks (Lint (pre-commit), Validate Documentation, Validate Adapter Contract, ros-manifest tests) still running in both workflow runs. The one finding of the Integrated Review at 5d9de7ef is fixed in 33b83ab7: the "still running at exit" echo now follows the three `trap` lines in cleanup_run (read at :551-560). The Local Review at d2916a3c is approved with no findings; the earlier entries are stale. Nothing is open.

Carry into part 2 of the issue: if another signal-handling point turns up in the runner, replace the trap resets and re-installs (:728, :801, cleanup_run) with one handler installed once for the whole parallel section and its cleanup, deciding by `stop_underway`.

### Findings

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-13 11:57 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

The owner's answer, verbatim: "merge 468 if ci is gree". He had been told: reviews and triage are finished with nothing open; the pull request adds the parallel runner, the default stays one job, and it is part 1 of 2 that does not close issue 444; CI's full run on the final commit was still running. The host merges only when every check on 8e21c771 has passed, and stops and reports if any fails.

## Checkpoint
**Status**: complete
**When**: 2026-11-13 12:29 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: address

CI failed, so the earlier conditional answer ("merge 468 if ci is gree") did not merge. Shown to the owner: the push runs (the branch alone) pass; the pull_request runs (the branch combined with main) have failed six times in a row since pull request 461 merged at 2026-11-13 16:43Z, every time at the same case of test_merge_pr_gate.sh: "FAIL: (hang-1) origin silent (reap=reached elapsed=4s ..." / "elapsed=5s", in "TEST: an origin that does not answer: the gate's fetch and the record push are ended by WT_FETCH_TIMEOUT", then "run_script_tests: FAILED at test_merge_pr_gate.sh (suite 16 of 48)". Main's own CI passes that test at 8161b57d. Asked: "Send pull request 468 (parallel test suites) back to find and fix its CI failure against main?" The owner's answer, verbatim: "yes to both".

## Implementation
**Status**: complete
**When**: 2026-11-13 13:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #468 at `7938e59f`
**Addressed**: Checkpoint (After: merge, Decision: address) at 2026-11-13 12:29 -05:00 — the CI failure of the pull_request runs (branch merged with main): test_merge_pr_gate.sh case hang-1
**Commits**: e5c228b3 (merge of origin/main, no conflicts), 7938e59f (the fix and its test), then the docs commit that adds this note (made after this entry)

### Cause
Not a signal, process group or stdin difference: the hang-1 run ended on time (reap=reached, 4-5 s). Its reason sentence was cut short. merge_pr.sh passed the owning checkout's whole reason sentence (_GATE_OWN_NOREAD / _GATE_OWN_PROBLEM, with the checkout's path inside) through _bk_display, whose 256-byte cap then cut the sentence to "so it is not...(+20 bytes)". The test looks for "so it is not known to be current". This branch's per-suite TMPDIR (/tmp/run-script-tests.X/tmp/test_merge_pr_gate.sh/...) is 26 bytes longer than main's per-run one, enough to push the sentence over the cap; on main the sentence was about 6 bytes under it. Reproduced without the runner: test_merge_pr_gate.sh on its own with a long TMPDIR (the session scratchpad) fails 9 cases this way (pkg-13 x2, pkg-16 x3, pkg-19 x3, hang-1). Reproduced through the runner at one job: the same hang-1 failure as CI. The defect is in merge_pr.sh from pull request 461. The test is right to expect the whole sentence, and the runner needs no change.

### Actions
- [x] Each value in the owning checkout's reason goes through _bk_display as the sentence is built, and the gate reasons quote the sentence unchanged, so the cap applies to a path, never to the sentence — `.agent/scripts/merge_pr.sh:751-806, :906-908`
- [x] New case (pkg-13 long-path): the checkout's path is padded to about 240 bytes, under the cap, while its reason sentence goes over it (310 bytes). It fails without the fix at the normal short TMPDIR, so it does not depend on where the suite runs — `.agent/scripts/tests/test_merge_pr_gate.sh` (after the pkg-13 block)
- [x] The fix's six-line comment moved every `merge_pr.sh` line after 750 by six: design.md's citations of it (Table 1's `merge_pr.sh` row, the Records bullet, the Target's mechanism 1) are refreshed and checked line by line against the new file, with a change-log row. Found after this entry was committed; a reset to put the docs commit before it was refused by the permission checker, so it follows the entry — `docs/design.md:400, :496-513, :584, :985`

### Runs
- Unfixed, test_merge_pr_gate.sh alone, long TMPDIR: 9 failed (191 passed), 137 s
- Unfixed plus the new case, alone, short TMPDIR: only pkg-13 long-path failed (200 passed), 167 s
- Unfixed, through the runner at 1 job (`--files` the test file, which scoped to 35 suites; stopped at suite 9): hang-1 failed as in CI, and pkg-13 long-path also failed, 400 s
- Fixed, through the runner at 1 job (a scratch tests dir holding test_merge_pr_gate.sh and the required test_checkpoint_269.sh), 3 in a row: 201 passed, 0 failed each, 170 s / 225 s / 329 s
- Fixed, test_merge_pr_gate.sh alone with the long TMPDIR: 201 passed, 0 failed, 220 s
- Fixed, test_run_script_tests.sh alone, 3 in a row: 163 passed, 0 failed each, 51 s / 50 s / 51 s

Commits used SKIP=validate-script-tests under the owner's test rule of 2026-11-13; the full suite and the full pre-commit pass were not run. CI on the push is the full check. Nothing was pushed.

Left as it is: _gate_refusal (merge_pr.sh, the "records gate refused" reason) still caps a whole message from another script. In most cases it is that script's single error line, a value. Its two built-in sentences hold only a short relative path.

## Local Review
**Status**: complete
**When**: 2026-11-13 13:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #468 at `f068ca67`
**Depth**: Deep (reason: whole-PR diff is 2201 lines and touches `merge_pr.sh`, the merge gate; scope per handoff: the fix 7938e59f, the merges e5c228b3 and f068ca67, the docs commit bfb76b0e; the runner itself not re-reviewed)
**Must-fix**: 0 | **Suggestions**: 2

Fix (7938e59f). Diagnosis confirmed: `suite_tmp` adds exactly `/tmp/test_merge_pr_gate.sh` (26 bytes) to the sandbox path, and `_bk_display` capped the whole `_GATE_OWN_NOREAD` sentence at 256 bytes. What the gate decides is unchanged: every test of `_GATE_OWN_PROBLEM` / `_GATE_OWN_NOREAD` is on emptiness (`merge_pr.sh:854, 871, 905, 907, 1172, 1307, 1309`), and `_bk_display` never empties a value. Each untrusted value in the two sentences (`_gate_wt`, `PR_BRANCH`, `_gate_own_branch`, the `wt_fetch_why` text) passes through `_bk_display` exactly once; the SHA slices, `rev-parse --short` and the count are hex or digits. The reasons at :906/:908 and `why_comment` at :1308/:1310 use the sentences as built, and the joined `_gate_why` (:1468) is never displayed again, so nothing is escaped twice. The only text change beyond "not truncated": `why_comment` on these two paths now prints an escaped path where it printed it raw. `_gate_already_recorded` compares Conditions built the same way, so one fresh record after an older truncated one is the only effect. `_gate_refusal` (:910) is fine, not the same defect: the gate's own sentence ("the records gate refused the timeline in <wt>:") stays whole and only the other script's one-line message, an opaque value, is capped as values are meant to be; no test matches on its tail. The new case fails without the fix by construction (239-byte path, 310-byte reason: the old cap appends "...(+54 bytes)").

Merges. e5c228b3: no conflict (remerge diff empty). f068ca67: the one conflict in `docs/design.md`'s change log keeps main's #466 row as on main, then this branch's row, its count 1061 (`wc -l` agrees). `test_script_tests_hook_scope.sh` holds both sides (the job-count checks and the `test_register_session_root.sh` ROOT_READERS entry). Main's test changes (pull requests 461, 467, 469) were scanned for parallel hazards: `test_register_session_root.sh` redirects HOME into its sandbox and only reads copies of the real tree; the hang cases keep their pids in sandbox files and allow up to 120 s; nothing names `run-script-tests`, `RUN_TMPDIR` or the old layout. The one path-length dependence was the defect fixed here. Serial runs still stop at the first failure, so CI's failing runs never reached suites 17-48 on the combined tree; the CI run at f068ca67 (Lint still pending at review time, the other checks passed) is the first to.

Docs (bfb76b0e). Spot-checked against the file: 741, 875, 1182, 1472, 1485, 896-903, 1305-1306, 744-811, 812-864, 1145-1320 all land on the statements cited.

Cross-model: ran on the fix commit alone (a scratch clone detached at 7938e59f, `--branch e5c228b3 --no-progress`), since Deep calls for it and the handoff gave no convergence words. Gemini: completed, no issues. Codex: completed, two test-portability points, not taken: the case fails, naming the cause, when the sandbox path is 157 bytes or more, and at about 172 the existing cases fail anyway because the path alone passes the cap by design; and the raw path in `want` breaks only with a non-ASCII TMPDIR, the same assumption every existing pkg case makes. Claude adversarial (fresh subagent): no must-fix; its points are in the suggestions.

Ran: `test_merge_pr_gate.sh` 201 passed, 0 failed, 152 s (pkg-13 long-path and hang-1 pass); `test_script_tests_hook_scope.sh` 328 passed, 0 failed, 49 s; `check_design_anchors.sh` exit 0; shellcheck --severity=warning on both changed scripts, clean. No full suite, no full pre-commit pass (owner's rule of 2026-11-13).

### Findings
- [ ] (suggestion) No case pins exactly-once escaping in the owning checkout's sentences: every fixture path is printable ASCII, on which `_bk_display` is the identity, so re-wrapping the sentence at :906/:908 would not be caught; a raw-byte owning path, as g17 does for the workspace root, would — `.agent/scripts/tests/test_merge_pr_gate.sh:890`
- [ ] (suggestion) Follow-up, outside this pull request (main's code from pull request 461): the other `why_comment` / `after_why` texts interpolate `_gate_wt`, `PR_BRANCH`, `cur_branch` and `wt_fetch_why` raw; they reach only the terminal (:1316/:1318), not the PR comment — `.agent/scripts/merge_pr.sh:1197-1297`

## Integrated Review
**Status**: complete
**When**: 2026-11-13 13:20 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #468 at `4911f4a`
**Sources**: 3 (Local Review @ `f068ca6` (covers 4911f4a via bookkeeping), GitHub: 0 reviews and 0 comments, CI rollup)
**Cross-source confirmations**: 0
**CI**: pending (on 4911f4a and on f068ca6: Validate Documentation, Validate Adapter Contract and ros-manifest tests pass; Lint (pre-commit), the job that runs the script suites, still in progress at 13:20, so the combined tree's suites 17 to 48 have no result yet)

Read for this entry: the fix commit 7938e59f, `merge_pr.sh` 748-908 and 1165-1320, `_bk_display` (`_bookkeeping.sh:40`), `wt_fetch_why` (`_worktree_helpers.sh:593`), case pkg-13 and cases g17-g17c. The fix is right as it stands: every value in `_GATE_OWN_PROBLEM` / `_GATE_OWN_NOREAD` goes through `_bk_display` once (760-805); the gate reasons (906, 908) and the terminal line (1308, 1310) use the sentences without a second wrap. Neither suggestion is must-fix; neither needs a new issue.

### Findings
- [x] (suggestion, Local Review @ `f068ca6`) Valid. No case puts raw bytes in the owning checkout's path, so nothing proves those sentences are escaped exactly once. How it would go wrong: a later edit drops the per-value `_bk_display` (raw control bytes reach the terminal and the gate's record) or wraps the sentence again (`\377` shown as `\\377`; a long sentence is cut again, which pkg-13 does catch). Likelihood low: today's code is right, and only a future edit to these lines brings it back; the gap predates this pull request (pull request 461's code had no such case either). Recommendation: carry into part 2 of this issue, which rebuilds `test_merge_pr_gate.sh`'s fixtures anyway (plan line 81), so the case costs no extra round here — a raw-byte owning path, as `raw_root_sandbox` does for the workspace root — `.agent/scripts/tests/test_merge_pr_gate.sh:890` (deferred: owner 2026-11-13: 'yes on q1'; carried into part 2 of issue 444, which reworks this test file's fixtures)
- [x] (suggestion, Local Review @ `f068ca6`) Valid, outside this pull request (main's code from pull request 461). The record step's other reasons (`merge_pr.sh` 1197, 1200, 1255, 1258, 1261, 1286, 1290, 1297, and the lines at 1229/1251) put `_gate_wt`, `PR_BRANCH`, `cur_branch` and the fetch's first stderr line in raw. How it would go wrong: odd bytes printed raw to the operator's own terminal only, never to the pull request comment (the comment body is the entry alone, 1313). Likelihood low: git refuses control characters in branch names, so it takes a checkout path with control bytes in it, or a fetch error line carrying them. Recommendation: no fix here and not part 2 (which does not touch `merge_pr.sh`); no new issue: it belongs with issue 462 (the record step publishing unpushed commits and uncommitted edits), which edits the same function and is owned by the other machine's session, already told — `.agent/scripts/merge_pr.sh:1197-1297` (deferred: owner 2026-11-13: 'yes on q1'; left for issue 462, which edits the same function of merge_pr.sh)

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-13 13:23 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: findings
**Decision**: merge

Asked: "Merge pull request 468 once CI is green on the combined code, with F1 carried into part 2 and F2 left for issue 462?", with F1 (test_merge_pr_gate.sh:890: no case checks that escaping happens exactly once; triage: carry into part 2 of this issue) and F2 (merge_pr.sh:1197-1297, main's code from pull request 461: other record-step messages print the checkout path, branch names and the fetch error line raw, to the terminal only; triage: belongs with issue 462), and with what changed since his earlier conditional answer: the 26-line fix in merge_pr.sh (the 256-byte cap applies to each value, never to the whole sentence), its new test, and two merges of main. The owner's answer, verbatim: "yes on q1 and open the issue about limits and safeguards". The host merges only when every check on the reviewed head f068ca67 has passed, the pull_request run included, with no relaxing flag, and stops and reports otherwise. F1 and F2 are deferred on that answer.

## Checkpoint
**Status**: complete
**When**: 2026-11-13 13:29 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (pull request 468, part 1, merged; the plan's part 2 is an outline and the owner has cut it down, so the plan is refreshed before anything is implemented; first host revise at this checkpoint since the merge)
**After**: plan
**Decision**: revise

The owner's direction for the next part, verbatim (2026-11-13): "Add a small PR to switch it on. I'm not sure we need to record before and after times now. Don't we have enough before times?" So the next pull request only turns the parallel job count on by default; no new before/after measurement runs; the slow-suite work (the issue's P2), the run-time wording in AGENTS.md and the other texts, and the carried test point (a raw-byte owning path in test_merge_pr_gate.sh, deferred from pull request 468) are left for later. Before times in hand: one job 680 to 694 s (2026-11-12), 824 to 1069 s on a loaded machine (2026-11-13), CI's lint job 11 to 13.5 min; parallel 163 to 320 s (2026-11-12).

## Plan Authored
**Status**: complete
**When**: 2026-11-13 13:32 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-444/plan.md` at `b50c8813`

Part 2a refresh: one small pull request that turns the parallel default on (the suited count, 1 when the CPU count is unreadable or bash is older than 5.1; `-j 1` and RUN_SCRIPT_TESTS_JOBS=1 keep one job), updates every text and test that states the default, and checks suite independence with two shuffled parallel full runs; no before/after timing runs (owner, 2026-11-13). Does not close issue 444.

## Plan Review
**Status**: complete
**When**: 2026-11-13 13:36 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #444 — Run the script test suites in parallel, and speed up the slowest
**Plan**: `.agent/work-plans/issue-444/plan.md` at `b50c8813`
**Branch**: `feature/issue-444`

Scope of this review: the "PR 2a" section and what `b50c8813` changed around it; part 1's text is the record of merged work and was not re-reviewed. Owner's direction checked against: "Add a small PR to switch it on. I'm not sure we need to record before and after times now. Don't we have enough before times?"

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One small pull request: the default flip with its two fallbacks, the texts that state the default (runner header, usage, hook comment, reference row), the default-pinning test cases. No before/after timing runs. Nothing beyond the owner's direction. |
| Issue alignment | Good | Part of issue 444, not closing it. Left for later and listed: the slow-suite fixture work (P2, and whether to split `test_cross_model_review.sh`), the run-time wording in `AGENTS.md` and the other "about 12 minutes" texts, the carried test point from pull request 468 (`test_merge_pr_gate.sh` near 890), issue 465 (when the suites run), issue 472 (the cap of 8). Serves line, as checked: "Easy to use (`README.md#workspace-goals` ...) under `docs/design.md#registry-and-adapters`". |
| File targeting | Good | Checked against the code as merged: `JOBS_DEFAULT=1` is line 166, `jobs_suited` is computed at 171-179 unconditionally, before argument parsing, so it exists in every path that reaches 238; `jobs_asked="$JOBS_DEFAULT"` is 238; `jobs_note` 246-249; the bash 5.1 refusal 256. Every nested runner call in `test_run_script_tests.sh` names a job count except 1103/1105 (`jobs_case`, given `-j` or the variable), 1123 (the default case being changed) and 1152 (`RUN_SCRIPT_TESTS_JOBS=2`); `check_full` and both generated hook scripts pass `-j 1`. `test_script_tests_hook_scope.sh` pins only the absence of `-j` in the entry and the word `RUN_SCRIPT_TESTS_JOBS` in the comment. One citation is off: the one-job loop is near 905-915 (its "remaining suites not run" line is 912), not 895, which is blank. |
| Consequences | Good | Callers checked in the code: the hook passes no `-j`; CI reaches it through `make lint`; no text in `AGENTS.md`, the skills or `dispatch_phase.sh` relies on stop-at-first-failure. The run-time texts are deferred (notes 1 and 2). |
| Principle alignment | Good | Only what's needed (one line flipped, two fallbacks); test what breaks (default cases plus `-j 1`, environment 1 and unreadable-CPU cases); reversible alone (D9). |
| ADR compliance | Good | ADR-0013 (this entry). No `.github/workflows` or branch protection change; `AGENTS.md` untouched (Ask First, deferred). |
| ROS conventions | N/A | Workspace plan. |

### Checks made for this review

- The flip cannot turn a working run into an error: `jobs_suited` is always computed first; empty CPU count gives 1; capped at the CPU count (1 CPU gives 1 job, the one-job path); a bash older than 5.1 gives 1 by the planned clear; an explicit count still meets the refusal. A machine whose bash lacks job control or whose `nproc` reports host CPUs inside a CPU-limited container would run slower, not fail.
- Parallel at a terminal and as a background job at a terminal (not covered by part 1's runs, which ran each in its own session with no terminal): run here under `script` with a 4-stub tests directory at `-j 2`, in the foreground and as `cmd &` from an interactive shell. Both exit 0, no stop on SIGTTOU/SIGTTIN; `set -m` is only on around each `&` (runner 768-771), so no foreground command takes the terminal.
- Shared resources between suites, searched in all 49 suites: the suites that write under a home set `HOME` to their sandbox (`test_package_issue_loop.sh:43`, `test_records_write_gate.sh:46`, `test_register_*`, `test_user_tier_install.sh` per call); `test_package_issue_loop.sh:40` sets `GIT_CONFIG_GLOBAL`; the locks (`test_capture.sh:244`, `test_register_project.sh:959`, `test_project_file.sh:858,925`) are on sandbox files; no port, no `pkill`/`killall`, no host-wide `pgrep` (only `pgrep -P` on a known parent, `test_register_project.sh:997`). `test_gh_create_issue.sh:88` and `test_plugin_manifest.sh:133` run in the real checkout but only read it (a stubbed `gh`; `claude plugin validate`). No clash found.
- Memory and load: 31 GB and 16 CPUs here; CI 4 vCPUs at 2 jobs. Nothing in the suites is memory-heavy. Load across concurrent drives grows (each full run now 4 jobs, not 1); the per-run bound is the only limit (D8, already on the owner's veto list).
- The 600 s tool-call timeout: a one-job full run today (680 to 1069 s) already exceeds it; at 4 jobs (163 to 355 s measured) it fits. The flip improves this.

### Findings

No must-fix. Notes for the implementer, each applicable without a re-plan:

1. **[Consequences]** The later part's run-time list omits two texts that quote a full run's length and tell agents the tool timeout: `.agent/scripts/dispatch_phase.sh:618` ("about 2 minutes for a typical fix, about 7 when every suite runs ... up to 600000 ms") and `.claude/skills/address-findings/SKILL.md:199` ("about 7 when every suite runs"). Leave them unchanged in this pull request (owner: no new times) but name them in the pull request's "left for later" list beside `AGENTS.md` and the issue 419/399/410 texts.
2. **[Scope]** Step 6 calls the final branch pre-commit run "scoped", but this branch changes `run_script_tests.sh` and `.pre-commit-config.yaml`, both full-run triggers, so that run is a full run at the new default, under pre-commit. Plan for three local full runs (two shuffled plus the pre-commit one), not "the one place this pull request runs the full suite". That third run is useful: it is the only check of the parallel default through pre-commit itself. Say so in the progress entry and the pull request body, since the owner's rule of 2026-11-13 is one local run before a pull request.
3. **[Consequences]** Step 4's caller text for the pull request body: a parallel run at a terminal also prints a `--- <suite> passed in Ns (k of n done)` line as each suite finishes, not only `running X` lines. Under pre-commit nothing shows until the hook ends at any job count, because pre-commit holds a hook's output until it exits, so the parallel default makes that silent stretch shorter, not longer.
4. **[Issue alignment]** Two shuffled runs only catch frequent clashes (part 1 needed 10 runs to see its one flake). That fits a small pull request, because every pre-commit and CI run afterwards is parallel. The pull request body should say what to do about a failure that shows only in parallel after merge: `RUN_SCRIPT_TESTS_JOBS=1` locally while it is fixed; for CI, either the workflow variable (a CI change, owner's yes) or reverting this pull request alone (D9).
5. **[File targeting]** Step 5's list of suites changed since part 1's independence runs (`90ad6aa3`) is incomplete: `test_user_tier_install.sh` (about 2,360 lines changed), `test_ros2_colcon.sh` (+808), `test_adapter.sh`, `test_cross_model_review.sh`, `test_project_registry.sh`, `test_merge_pr.sh` and others also changed (`git diff --stat 90ad6aa3 HEAD -- .agent/scripts/tests/`). The check runs every suite, so nothing is missed. When comparing PASS counts with the last one-job baseline, use that diff and not the plan's list.
6. **[File targeting]** Fix the citation "the one-job loop at 895" to the loop near 905-915 when writing the pull request text.
7. **[Principle alignment]** Step 5 runs on a quiet machine. Record the load average at each run's start, as part 1 did, so that a later flake under load can be compared with these runs.
8. **[File targeting]** The new unreadable-CPU case has to shadow both `nproc` and `getconf` with failing stubs first on `PATH` (runner 172 falls back from one to the other). A stub `nproc` alone leaves the real `getconf` answering.

### Summary

The plan does exactly what the owner asked, as one small pull request. The flip is safe in every path checked: the CPU count is read first, the two fallbacks to one job are complete, and parallel mode works at a terminal and in the background. No suite was found sharing a path, home, git configuration, port, lock or process match with another. Ready for implementation. The notes are wording and bookkeeping for the pull request text.

### Recommended Actions

- [ ] Implement as planned, applying notes 1 to 8 in the pull request text and the tests.
