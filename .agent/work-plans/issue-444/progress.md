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
