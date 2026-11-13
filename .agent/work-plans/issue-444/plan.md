# Plan: Run the script test suites in parallel, and speed up the slowest

## Issue

https://github.com/rolker/agent_workspace/issues/444

## Context

`.agent/scripts/tests/run_script_tests.sh` (428 lines, read this phase) runs the 45 `test_*.sh` / `test_*.py` suites one after another (`for s in "${run_suites[@]}"` at line 382, `bash "$s"` at 386), stops at the first failure (exit 1, lines 386-392), and sweeps one shared `RUN_TMPDIR` (created at 371, exported as TMPDIR/TMP/TEMP at 378) after every passing suite (leak sweep 405-417, exit 2). A full run is about 12 minutes; CI reaches it through `make lint` -> the `validate-script-tests` hook (`.pre-commit-config.yaml:93-101`, `require_serial: true`), where every full run is triggered because the file list holds the runner. Owner, 2026-10-29: "Accept ~2 min now; parallel later"; 2026-11-10: "Yes on P1 and P2". Standing rule: wall-clock time before token use. After the 2026-11-09 crash from an unbounded parallel build, every parallel run here names its job count and the default is modest.

Part 1 (PR 1, pull request 468) is merged. The next pull request is part 2a, which only turns the parallel default on (detailed below); the slow-suite work and the run-time wording are a later part. The text of PR 1 below is kept as the record of what was done.

Facts checked against the code this phase:
- The runner path is `.agent/scripts/tests/run_script_tests.sh` (not `.agent/scripts/`).
- Public repo, so GitHub's `ubuntu-latest` has 4 vCPU (`validate.yml` `runs-on: ubuntu-latest`, four jobs, lines 12/29/48/66); `nproc / 4 = 1`, clamped to 2, so a CI full run gets **2 jobs**. This machine: `nproc` = 16 -> 4 jobs.
- Existing runner tests: `test_run_script_tests.sh` (945 lines; pins `FAILED at test_b_fail.sh` at line 113 and the "remaining suites not run" wording) and `test_script_tests_hook_scope.sh` (755 lines, regex/scope guard).
- `test_cross_model_review.sh` host-wide matches: `pgrep -f -- "$findings"` / `pkill -KILL -f` (3686-3691), `pgrep -fx -- "sleep ${sleep_arg}"` / `pkill -KILL -fx` (3695-3697), and `pgrep -f -- "$pattern"` / `pkill -KILL -f` (4828, 4841, 4848; `$pattern` embeds `${dir}`). `$findings` and `${dir}` live under the suite's own sandbox, so they are unique per run once TMPDIR is per suite. The residue is `sleep ${sleep_arg}`: its comment says the value is "unique per suite", but two copies of the same suite (two worktrees, or P1's own pool alongside a hand-run) share it, and `pkill -KILL -fx "sleep N"` would kill the other copy's sleep. Issue 305 ("Guard against pgrep -f / pkill -f matching the agent's own command line") is about self-match, a different bug; the fix here does not redo it.
- `test_capture.sh:161-171` runs two `bash "$CAP"` in the background inside its own sandbox and waits; `flock` there is local to the sandbox.

## Approach

### PR 1 - the runner made safe for parallel runs (default stays one job)

Steps, in order; each is one commit.

1. **Pin today's contract before changing anything.** In `test_run_script_tests.sh` add a case (new letter after the last existing case) recording what must survive: exit 0 / 1 / 2 meanings, the header lines (`run_script_tests: full run, all N suites: ...`, `=== run_script_tests: running X ===`, `all N suites passed in Ns`), and that a leak is charged to the suite that left it. Runs green against the unchanged runner, so the later steps are checked against a fixed point.

2. **Per-suite temp directory and a leak sweep that charges only that suite.** Replace the single `RUN_TMPDIR` with `RUN_ROOT` (`mktemp -d --tmpdir=/tmp run-script-tests.XXXXXX`, still hardcoding `/tmp` for the reason in the header, still removed by the EXIT trap) holding `tmp/<suite-name>/` (the suite's TMPDIR/TMP/TEMP, created before it starts) and `out/` (step 3's logs; outside the swept directories). After a suite passes, `find "$RUN_ROOT/tmp/<name>" -mindepth 1` is the sweep; the suite's directory is then removed. Leak message keeps its shape and names the per-suite directory. Serial (`-j 1`) goes through the same code, so serial and parallel cannot drift. A failed suite is not swept (as today: sweep only on the pass path); its directory is removed with the rest at exit.

3. **A job pool with whole, unmixed output.** `-j N` / `--jobs N`, then `RUN_SCRIPT_TESTS_JOBS`, then the default (below). Resolution order: option, environment, default. Invalid (non-integer, < 1) -> exit 1 with a plain message; above 8 -> clamped to 8 with a one-line note naming what was asked. The line `run_script_tests: running with N job(s)` is always printed, so every run names its count.
   - `N = 1` streams each suite's output live, in list order, exactly as today (no capture), so it behaves as today in output and exit codes, except for the host decision in step 5 (does not stop at the first failure).
   - `N > 1` starts suites in the background with `wait -n` (bash 4.3+, the `bash` already required; checked at start, plain message if older), each writing stdout+stderr to `out/<n>-<name>.log` and its exit code to `out/<n>-<name>.rc`, stdin from `/dev/null`. Nothing from a suite reaches the terminal while it runs except the `=== running X ===` lines, printed by the parent at start. When all have finished the parent prints, failures first (in list order, each log whole, under a `===== FAILED: <name> =====` banner, stderr and stdout in the order the suite wrote them since both go to one file), then a `passed:` list of one line per suite with seconds, then today's summary line. Passing suites' logs are not printed (live output of a passing suite is not diagnostic), but are kept in `out/` until exit; `--show-passed` prints them too (cheap, makes comparing a parallel run to a serial one possible).
   - Start order for `N > 1`: largest file first (`wc -c`), a free proxy that lowers wall-clock (the 5,676-line `test_cross_model_review.sh` starts first) with no stored state. `--shuffle` overrides it.
   - Interrupt: an INT/TERM/EXIT trap kills the pool's process groups (`setsid` per job, `kill -- -$pgid`), waits, then removes `RUN_ROOT`. The abort path is covered by the test in step 9.

4. **`--shuffle[=SEED]` and the timing table.** `--shuffle` randomises the start order from a seed (`cksum` of `seed:name`; no `shuf` dependence); the seed is printed (`run_script_tests: shuffle seed 17`) so a failing order reproduces with `--shuffle=17`. The list used for "first failing suite" (step 5) is always the sorted glob order, so the exit code does not depend on the shuffle or on finish order. `--timings` prints a table (suite, seconds, status), slowest first; it is also printed automatically when `N > 1` and whenever any suite fails. Seconds come from `$EPOCHSECONDS`/`date +%s` per suite.

5. **Run everything, print every failure, exit as serial would.** (Host decision, listed for the owner's veto below.) No stop at the first failure. The exit code is that of the first failing suite in sorted list order: 1 for a failure, 2 for a leak (a leak is only charged to a suite that passed, as today). Preflight failures (missing required suite, missing tool, mktemp lint, bad arguments) still exit 1 before any suite runs. The "FAILED at <name> (suite k of n) after Ns" line is kept per failed suite, printed after the failure banner, without "stopping, remaining suites not run". A final line `run_script_tests: F of N suites failed: a, b` appears when F > 0. `test_checkpoint_269.sh` still joins every run and still must be run and reported (unchanged logic at lines 189-199 and 290-295).

6. **`# serial:` marker, read by the runner.** A suite that cannot be made independent carries, in its first 30 lines, `# serial: <reason>`. The runner starts those only after the pool has drained, one at a time, and lists them in the header (`serial suites: name (reason)`). A suite with the marker but no reason is a preflight error (exit 1). Used only as the last resort in step 8.

7. **Header, hook comment and reference text.** Rewrite the runner header's fail-fast paragraph, exit-code list and TMPDIR-guard prose (lines 19-22, 61-67, 309-378) for the new behaviour; the `.pre-commit-config.yaml` comment above the hook (it says CI "runs every suite" and `require_serial` - add that the runner's own job count applies, `require_serial` unchanged); the `script_reference.md` runner row (line 52) with `-j`, the environment variable, `--shuffle`, `--timings`, `--show-passed`, `# serial:`; the `suites_for_files.sh` header only if it mentions fail-fast (grep first; its mapping meaning does not change). Stale text deleted, not appended.

8. **Make each suspect independent or mark it, one commit per suite touched.** Evidence decides; the reading below says where to start:
   - **Runner leak sweep** (suspect 1): done in step 2.
   - **`test_cross_model_review.sh` pgrep/pkill** (suspect 2; the review's 3686-3697, 4828): `$findings` and `$pattern` are already per-run unique under the per-suite TMPDIR; make `sleep_arg` unique per run by deriving the unused digits from `$$` (the value selects a never-reached escalation window, so only trailing digits vary; verify that by reading where each `sleep_arg` is passed before changing), and add a test inside the suite that two copies of the helper's watchdog check do not match each other's sleep if cheap. If a collision cannot be removed, mark `# serial: host-wide pkill by command line`.
   - **`test_capture.sh`** (suspect 3), **`test_register_project.sh`** (flock/sleep holders, 100 x 0.1 s polls, 720-828 and 985), **`test_project_file.sh`** (879-977), **`test_sitrep_checks.sh`** (suspect 4): self-contained; the risk is load, not collision. No edit unless the repeat in step 10 shows a failure; then widen the poll bound (the polls are bounded waits, so a longer bound costs nothing when the event arrives) or mark `# serial:` with the observed failure as the reason.
   - **Real-tree readers** (suite 5: `test_plugin_manifest.sh:133` runs `claude plugin validate .` with the real HOME, `test_gh_create_issue.sh:41,88`, `test_resolve_work_plans_dir.sh:140`): read-only; confirm by one `strace`-free check (`find` of files under `$HOME/.claude` newer than the run start after a run) that none writes; no edit expected.
   - **Whole-tree copies** (suspect 6, `cp -r "$WS_ROOT/.agent"` in seven suites): safe unless a concurrent suite writes into the source tree. Check: after a parallel run, `git status --porcelain` in the worktree is empty and `.agent/scratchpad` has no new entries; any writer found is fixed to write in its sandbox.
   - **`test_run_script_tests.sh`** (suspect 7): nested runs become `-j 1` explicitly and clear `RUN_SCRIPT_TESTS_JOBS` in their environment so the outer run's setting is not inherited.
   - Anything else the repeat flags is added to this list with its disposition in the PR description.

9. **Runner tests (new cases in `test_run_script_tests.sh`, which already builds scratch tests directories with stub suites).**
   - Jobs: `-j 3` option; env var; option beats env; `-j 0`, `-j abc` exit 1; `-j 99` runs with 8 and says so; default is `clamp(nproc/4, 2, 6)` (assert on the printed count, with a fixture that sets nothing); `-j 1` output order equals list order.
   - **A failing suite's output is not interleaved with another's:** two stub suites that each print 200 numbered lines with `sleep 0.01` between lines, one marking its lines `A-n` and failing, the other `B-n`; run at `-j 2`; assert the `A` block in the output is contiguous (lines `A-1..A-200` consecutive with no `B-` line between) and that no `B-` line appears inside it. Run the case 5 times in a loop in the test itself.
   - Failures first: a failing suite listed last prints before the pass list.
   - Every selected suite runs after a failure (marker file from a later suite exists); all failures printed; exit code = first failing in sorted order, shuffled or not (suites finish in reverse order via sleeps); a leak plus a failure gives the earlier suite's code.
   - Leak attribution under concurrency: suite X holds a live file in its own TMPDIR for 1 s while suite Y finishes; Y passes, X passes (no cross-charge); suite Z leaks -> exit 2 naming Z only.
   - `--shuffle=7` prints the seed and gives the same start order twice; different seeds differ for 8 stubs.
   - `# serial:` suites never overlap another (stubs write start/end timestamps to a file; assert disjoint intervals), a reasonless marker exits 1.
   - Timing table lists every suite; `--show-passed` prints a passing log.
   - Interrupt: start a run with a stub that sleeps 30, send TERM to the runner, assert no stub process and no `run-script-tests.*` directory remain.
   - `test_script_tests_hook_scope.sh` is extended only if it pins text this PR changes (grep first); the real-tree map check is untouched.

10. **Verify independence (the acceptance for PR 1), on a quiet machine, recorded in the PR.** "Quiet" means no other full-suite run in progress (`pgrep -f run_script_tests` empty, load average under 2), checked before each batch.
    - Baseline: **2** serial runs (`-j 1`) of the full set. Per suite, record exit status and the counts of `PASS:`/`FAIL:` lines in its output (`--show-passed` makes them available).
    - **10** parallel runs with shuffled order at `-j 4`, seeds 1-10, each exercising a different overlap.
    - **3** runs at `-j 2` (the CI default) and **1** at `-j 8` (the cap).
    - **2** runs at `-j 4` while 8 busy loops hold 8 of the 16 cores (a named count, started and stopped by the test script, killed in a trap), to raise the timing-sensitive suites' odds.
    - Pass = in every run: overall exit 0; every suite exit 0; no leak; each suite's `PASS:` count equal to the serial baseline's and `FAIL:` count 0; after the run no `run-script-tests.*` under `/tmp`, no stray `sleep`/`flock`/`codex` mock processes from this run, and `git status --porcelain` empty. A suite that fails even once in the 16 parallel runs and not in serial is a finding to fix or mark `# serial:` (no retry-until-green; the failing seed is recorded). A suite that also fails serially is a pre-existing flake, filed separately (issue 361 is the known one) and not charged to this change, but the run is repeated after it is excluded or fixed so the claim "parallel equals serial" is made on a green baseline.
    - The comparison is a recipe in the PR description, not a checked-in tool: a loop over seeds calling the runner with `--shuffle=N -j 4 --show-passed`, then `grep -c` for the PASS and FAIL counts. A tool for a one-time acceptance is more than needed; PR 2 promotes it only if it repeats the check.
    - Total cost is about 18 runs; serial runs take about 12 minutes each, the parallel ones roughly a quarter to a third of that on this machine. The owner is not waiting on this (the pull request is reviewed after), so the budget is wall-clock on the machine, not his time; do the runs sequentially, never two batches at once, and never with a job count above the named one.

11. **Citations that will shift.** This PR moves most of the runner's lines (every number cited above refers to the current file). Other issues' branches (issue 429's, issue 436's) cite line numbers in `run_script_tests.sh`; those citations will be wrong after this PR merges. Who refreshes them: whoever merges second. The PR description lists the moved sections by name (arguments, preflight, selection, per-run guard, loop, summary) with old -> new line ranges; the implement phase of 429 and 436, on its next rebase, replaces its numbers using that table, and the orchestrator flags both issues when this PR merges. This plan does not edit those branches (outside this worktree).

### PR 2a - parallel on by default (detailed 2026-11-13; part 1 above is merged as pull request 468 and stays as the record)

Owner, 2026-11-13: "Add a small PR to switch it on. I'm not sure we need to record before and after times now. Don't we have enough before times?" So this pull request only flips the default. The before/after timing runs of the old PR 2 outline are dropped; the pull request quotes the before times in hand (one job: 680 to 694 s on 2026-11-12, 824 to 1069 s on a loaded machine on 2026-11-13; CI's Lint job 11 to 13.5 min; parallel: 163 to 320 s on 2026-11-12) and reports the times of its own runs (step 6). The flip stays its own pull request so it reverts alone (D9).

**The code as merged** (`run_script_tests.sh`, read this phase): `JOBS_DEFAULT=1` (line 166); `jobs_suited` is computed at 170-180 (`cpus/4`, at least 2, at most 6, at most `cpus`; empty when the CPU count cannot be read) and used only to word `jobs_note` (247-249); the effective default is `jobs_asked="$JOBS_DEFAULT"` (line 238). The bash 5.1 check at 256 refuses `jobs > 1` on an older bash with "run with -j 1".

**Steps** (each one commit; the runner first, as it is the change):

1. **Flip the default.** In `run_script_tests.sh`: delete `JOBS_DEFAULT=1` (166) and set `jobs_asked` at 238 to the suited count, `"${jobs_suited:-1}"`. Two fallbacks keep today's behaviour where a parallel default cannot work, so the default never turns a working run into an error: when the CPU count cannot be read (`jobs_suited` empty) and when bash is older than 5.1 (`jobs_suited` is cleared before 238 by the same version test that line 256 uses; an explicit `-j 2` on that bash still gets the refusal). `jobs_note` (247-249) becomes `default; suits this machine's $cpus CPUs` (or `default; the CPU count could not be read` / `default; bash older than 5.1` for the two fallbacks), and the comment at 168-170 ("Only printed while the default is 1") is rewritten. `-j 1` and `RUN_SCRIPT_TESTS_JOBS=1` still give the one-job path (443-449 and the one-job loop at 895 unchanged). The cap (8), the order option > environment > default, and the refusal of bad counts do not change.
2. **Texts that state the default** (same commit set, grep run this phase for `default`, `JOBS`, `one job`, `running with 1 job`, `run_script_tests`): the runner header, lines 19-25 ("One job (the default)": the one-job paragraph becomes "With -j 1 ...") and the opening of 27 ("with -j N above 1" stays true), the usage text at 56-63 ("else the default, 1" and "at the default it also names the count this machine suits"), the hook paragraph at 121-126, and the `USAGE` string if it states the default (it does not; unchanged); the comment above the hook in `.pre-commit-config.yaml` (lines 90-95: add that the default is the machine's suited count, 2 on CI's 4-CPU runner, and that `RUN_SCRIPT_TESTS_JOBS=1` gives the old one-job run; it must keep the words `RUN_SCRIPT_TESTS_JOBS`, which `test_script_tests_hook_scope.sh:549` pins); the runner row of `.agent/knowledge/script_reference.md` (line 56: "default 1, capped at 8; at the default the run also names ..." becomes "default: a quarter of the CPUs, at least 2, at most 6, never more than the machine has; capped at 8; `-j 1` or `RUN_SCRIPT_TESTS_JOBS=1` for one job"). `docs/design.md`: only line 441 mentions the runner and says nothing about job count or fail-fast (grep for `serial`, `fail-fast`, `first failure`, `12 minutes`: no hits), so no design section changes and no change-log row is needed.
3. **Tests that pin the default** in `test_run_script_tests.sh`: the (u1) loop at 1114-1128 expects `running with 1 job (default; -j $u1_want suits ...)` for 16/40/4/1 CPUs; it becomes `running with $u1_want jobs (default; suits this machine's $u1_cpus CPUs)` (4, 6, 2 jobs; the 1-CPU case gives `1 job`, the singular line, since `jobs_suited` is capped at the CPU count) with the label changed from "the default is one job". New cases beside it: `-j 1` and `RUN_SCRIPT_TESTS_JOBS=1` each print `running with 1 job (-j)` / `(RUN_SCRIPT_TESTS_JOBS)`, run suites in list order and stop at the first failure (the one-job path, pinned against the new default); an unreadable CPU count (a stub `nproc` that fails, `getconf` shadowed the same way) gives 1 job and says why. The bash < 5.1 fallback is checked by reading, not a test (the runner would need an older bash to run; the version test is one expression shared with line 256). The other cases already pass `-j 1` or an explicit count (verified by grep: the unpinned calls are only 1103/1105 `jobs_case` with `-j`/env, 1123, 1146 and 1152, and 1152 sets `RUN_SCRIPT_TESTS_JOBS=2`); the comment at 37-39 stays true. `test_script_tests_hook_scope.sh` pins no default and no "running with 1 job" line (grep, this phase): its 541-552 cases check that the hook entry passes no `-j` and that the hook comment names `RUN_SCRIPT_TESTS_JOBS`, both still true; it is run to confirm, and changed only if step 2's comment edit trips it.
4. **Callers, each checked in the code this phase.**
   - Pre-commit hook: `entry: ... run_script_tests.sh --files` passes no `-j`, so it now runs at the suited count; `require_serial: true` is about pre-commit's own file batching and stays. Locally (16 CPUs) 4 jobs; a scoped run of a few suites gains little and loses nothing.
   - CI: `validate.yml` line 25 runs `make lint` -> `pre-commit run --all-files` -> this hook, so every push runs the full set; `ubuntu-latest` has 4 vCPUs, so 2 jobs. `.github/workflows` and branch protection are not touched. If CI proves unstable at 2 jobs, `RUN_SCRIPT_TESTS_JOBS=1` in the workflow is a CI change for the owner; not made here.
   - Output and exit: at more than one job every selected suite runs, failures print at the end (each log whole under a FAILED banner), and the exit code is the first failing suite's in list order; at one job the run streams live and stops at the first failure. For a person at a terminal: nothing scrolls while a parallel run works except the `running X` lines, then the failures and a timing table come together; a failing run takes as long as a passing one instead of ending early, but a first failure no longer hides a second. For dispatched agents: they read the end of the output, which now holds every failure with its whole log; none of `AGENTS.md`, `.claude/skills/*`, `dispatch_phase.sh:618` (the SKIP rule text) or `run-issue` refers to stop-at-first-failure or to the output order (grep for `first failure`, `remaining suites`, `FAILED at` found only the runner and its test). No caller relies on stop-at-first-failure.
   - Nested runs in `test_run_script_tests.sh`: line 40 clears `RUN_SCRIPT_TESTS_JOBS`; every nested runner call carries `-j 1` or an explicit count except the default cases of step 3 (which are the point); the two generated hook scripts (853, 912) embed `-j 1`; `run_syn` callers all pass `-j`. The runner also unsets `RUN_SCRIPT_TESTS_JOBS` for its suites (line 255), so an outer parallel run cannot reach a nested one. No other suite starts the runner (`test_checkpoint_269.sh` only reads its text).
   - Makefile `test` target: runs `.agent/scripts/test.sh` (the project's tests), not the runner; unaffected. `lint` is the path to the runner, covered under CI above.
5. **Check the suites are independent of each other (implement step, the one place this pull request runs the full suite inside a pass; turning parallel on is the change itself).** Main has gained `test_register_session_root.sh`, `test_commit_identity.sh`, `test_fresh_clone_no_project.sh`, `test_records_write_gate.sh` and large additions to `test_merge_pr_gate.sh`, `test_dispatch_phase.sh` and `test_package_issue_loop.sh` since part 1's independence runs. Run, one after the other, never two at once and never above the named count, on a machine with no other full run (`pgrep -f run_script_tests` empty): `run_script_tests.sh --shuffle=A --show-passed` and `--shuffle=B --show-passed` at the new default (4 jobs on this machine; the printed `running with N jobs` line is recorded), seeds A and B chosen once and written in the progress entry. Expected: exit 0, no leak, every suite passing, `FAIL:` counts 0, `git status --porcelain` empty and no `run-script-tests.*` left in `/tmp` after each run. Compare the per-suite `PASS:` counts of the two runs with each other (they must match), and with the last one-job counts recorded in progress.md if a suite's count differs by anything but its additions.
6. **Run the two suites that pin this change, and record times.** `test_run_script_tests.sh` and `test_script_tests_hook_scope.sh`, alone (the rest of the implement pass runs no full suite; commits use `SKIP=validate-script-tests`, and the final pre-commit run with no SKIP is the scoped run the owner's rule of 2026-11-13 allows). The pull request body quotes the before times above and reports the wall times of the two step 5 runs and of CI's own Lint job from `gh run view` (read from the run, not estimated), naming 4 jobs locally and 2 in CI. No before/after comparison is claimed.

**Stop condition.** Stop and report, without trying a fix, if step 5 shows a suite that fails in a parallel run and passes alone, unless the fix is one line in that suite (a wider poll bound, a unique name); likewise any change needed in a suite outside the runner, its two tests, the hook comment and the reference row beyond one line, a hang or a leaked process after a parallel run, or a CI result at 2 jobs that fails where the one-job run passed. A failure that also occurs with `-j 1` is a pre-existing flake (issue 361 is known): record it, do not charge it to this change.

**Not in this pull request, left for a later part:** the slow-suite fixture work (the issue's P2: `test_register_project.sh`, `test_merge_pr_gate.sh`, `test_worktree_create.sh`, and whether `test_cross_model_review.sh` should be split); the run-time wording in `AGENTS.md` (an Ask First file) and the other texts that quote about 12 minutes (the issue 419 plan, the issue 399 and 410 texts); the carried test point from pull request 468 (a raw-byte owning-path case in `test_merge_pr_gate.sh`, near line 890, which belongs with the fixture rework); when the suites run (issue 465); the cap of 8 jobs (issue 472's checklist). **This pull request does not close issue 444** (it says "Part of #444"): P2 and the run-time wording remain.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/tests/run_script_tests.sh` | PR 1: per-suite TMPDIR, job pool, output capture, shuffle, timings, serial marker, run-all exit rule, header |
| `.agent/scripts/tests/test_run_script_tests.sh` | PR 1: contract pin, new cases (steps 1 and 9); nested runs `-j 1` and clear the env var |
| `.agent/scripts/tests/test_script_tests_hook_scope.sh` | PR 1: only if it pins changed text |
| `.agent/scripts/tests/test_cross_model_review.sh` | PR 1: `sleep_arg` unique per run (or `# serial:`) |
| `.agent/scripts/tests/test_capture.sh`, `test_register_project.sh`, `test_project_file.sh`, `test_sitrep_checks.sh` | PR 1: only if the repeat flags them (wider bound or `# serial:`) |
| `.pre-commit-config.yaml` | PR 1: comment above `validate-script-tests`; no key changes |
| `.agent/knowledge/script_reference.md` | PR 1: runner row (line 52, now 56) |
| `.agent/scripts/tests/run_script_tests.sh` (166, 168-170, 238, 247-249; header 19-25, 56-63, 121-126) | PR 2a: effective default on, with fallbacks to 1 when the CPU count is unreadable or bash is older than 5.1 |
| `.agent/scripts/tests/test_run_script_tests.sh` (1114-1128, new cases) | PR 2a: default cases expect the suited count; `-j 1` / env 1 / unreadable CPUs cases |
| `.pre-commit-config.yaml` (comment, 90-95), `.agent/knowledge/script_reference.md` (line 56) | PR 2a: state the new default |
| `AGENTS.md` (issue 399 text), `.agent/work-plans/issue-419/plan.md` mention | Later part: measured run time (AGENTS.md is Ask-First) |
| `test_register_project.sh`, `test_merge_pr_gate.sh`, `test_worktree_create.sh` | Later part: cheaper fixtures where measured |

## Prior Art

Looked at: pytest-xdist and `make -j` (a bounded job count, output kept per job, `-j1` the serial path); `xargs -P` and GNU parallel (rejected: a new dependency or one more tool for what `wait -n` in bash does; the output grouping and per-suite temp directory are what the repo needs and neither tool provides the leak attribution); bats `--jobs` (grouped output needs GNU parallel; rejected for the same reason). Taken from them: bounded default, grouped output, a way to reproduce a failing order (pytest-randomly's printed seed). Existing code reused: the runner's glob, the required-suite check, the `suites_for_files.sh` selection (unchanged), and the stub-suite fixtures in `test_run_script_tests.sh`.

## Serves

Easy to use (`README.md#workspace-goals`: a full run costs over 10 minutes per fix pass and again in CI) under `docs/design.md#registry-and-adapters` (the `test` verb row names the runner as the hook and test-gate entry).

No change to the design picture: the runner stays the single entry and only schedules suites differently; `docs/design.md` makes no statement about serial execution (checked by the review, to be re-grepped for "serial" and "fail-fast" at implementation).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | `wait -n` and a per-suite directory; no new tool; no stored timing state (size-ordered start); the acceptance script stays a recipe, not a checked-in tool |
| Enforce what matters, as simply as possible | The two guarantees the runner carries (leak attribution, exit-code contract) are kept and pinned by tests before the change (step 1) and after (step 9) |
| Test what breaks | Independence is checked by repeated shuffled/parallel/loaded runs compared with serial (step 10), and the interleaving, exit-code, attribution and interrupt cases are tests |
| A change includes its consequences | Header, hook comment, reference row, nested-run fixtures, and (later part) the quoted run time are in the plan; other branches' line citations named (step 11) |
| Verify before claiming | Before/after figures come from recorded runs; CI job count read from the run; every runner claim above was read from the file this phase |
| Humans are the bottleneck | Failures-first output, one failing suite's log whole, and a timing table cut the reading and waiting; no early stop hides a second failure |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 (progress timeline) | Yes | This entry; review-plan entry follows |
| CI / branch protection (Ask-First) | No | No `.github/workflows` change; CI uses the runner default via `make lint` (2 jobs on a 4-core runner) |
| Instruction files (Ask-First) | Later part only | `AGENTS.md` mentions the run time (issue 399 rule); listed for owner approval then |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Fail-fast and exit-code text | runner header, `test_run_script_tests.sh` pins (`FAILED at`, "remaining suites not run") | Yes (steps 1, 5, 7, 9) |
| TMPDIR guard layout | leak message, header, nested-run fixtures | Yes (steps 2, 7, 8) |
| Runner line numbers | citations on issue 429's and 436's branches | Yes (step 11, refreshed by the second to merge) |
| Quoted run time | issue 399 rule text, 410/419 text, script_reference | Later part |
| `.pre-commit-config.yaml` comment | `test_script_tests_hook_scope.sh` if it pins the comment | Yes (step 9, grep first) |

## Decisions for the owner's veto (made from `docs/principles.md`)

| # | Decision | Undoing costs |
|---|---|---|
| D1 (host) | A run executes every selected suite and prints every failure; exit code = what a serial run gives for the first failing suite; no stop at the first failure | An `--fail-fast` option, about 15 lines (stop launching, drain the pool) plus one test; not built unless asked |
| D2 | `-j 1` streams live and in list order like today (no capture); capture only at `-j > 1` | Always capturing is a one-line change; it changes serial output timing |
| D3 | Start order for `-j > 1` is largest file first (no stored state); `--shuffle` overrides | Delete one sort; no data lost |
| D4 | The exit code is by sorted list order, never by shuffle or finish order | Using the run's order makes shuffled and unshuffled exit codes differ; two lines |
| D5 | Passing suites' output is not printed in a parallel run unless `--show-passed` | A flag default flip |
| D6 | `# serial:` marker (reason required) as the escape for a suite that cannot be made independent; read only from the first 30 lines | Remove the marker support (~20 lines) once no suite uses it |
| D7 | The independence check is a PR-description recipe (2 serial, 10 shuffled at `-j 4`, 3 at `-j 2`, 1 at `-j 8`, 2 loaded) and not a checked-in script | Promote to a script later, about 40 lines |
| D8 | No load-average hold-back; the bounded count is the only limit | Add a check before each start; about 8 lines |
| D9 | The flip to default-on is a separate pull request (part 2a) so it can be reverted alone | Merge into PR 1; revert becomes harder |
| D10 | Interrupt kills each job's process group (`setsid` per job) | Without it, an interrupted run can leave suites' helper processes; plain `wait` only |

## Open Questions

- None that block PR 1. The hold-back on load (D8) and an `--fail-fast` option (D1) are the two places a different taste would add code.

## Estimated Scope

Part 1 (merged): about 11 commits, mostly the runner and its tests (large because of the test cases and the repeated independence runs); Part 2a: about 4 commits (runner, texts, tests, then the two verification runs recorded in progress.md); a later part for the fixture work and the run-time wording, with a possible further PR for splitting `test_cross_model_review.sh` if the timing table calls for it.
