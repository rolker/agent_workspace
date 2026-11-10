# Plan: Run the script test suites in parallel, and speed up the slowest

## Issue

https://github.com/rolker/agent_workspace/issues/444

## Context

`.agent/scripts/tests/run_script_tests.sh` (428 lines, read this phase) runs the 45 `test_*.sh` / `test_*.py` suites one after another (`for s in "${run_suites[@]}"` at line 382, `bash "$s"` at 386), stops at the first failure (exit 1, lines 386-392), and sweeps one shared `RUN_TMPDIR` (created at 371, exported as TMPDIR/TMP/TEMP at 378) after every passing suite (leak sweep 405-417, exit 2). A full run is about 12 minutes; CI reaches it through `make lint` -> the `validate-script-tests` hook (`.pre-commit-config.yaml:93-101`, `require_serial: true`), where every full run is triggered because the file list holds the runner. Owner, 2026-10-29: "Accept ~2 min now; parallel later"; 2026-11-10: "Yes on P1 and P2". Standing rule: wall-clock time before token use. After the 2026-11-09 crash from an unbounded parallel build, every parallel run here names its job count and the default is modest.

Two pull requests. PR 1 is implementable detail below; PR 2 is an outline, refined after PR 1's timing table exists.

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

### PR 2 - parallel on by default, measured (outline)

- Turn the default on: `jobs = clamp(nproc/4, 2, 6)`, cap 8, `-j 1` still available. (In PR 1 the "default" is already computed and printed in `--help`/the header but the effective default is 1; PR 2 flips the single line that uses it. Doing it in a second PR keeps the flip revertable on its own.)
- Measure before and after on this machine and in CI and record in the PR body: serial and parallel back to back on a quiet machine (same method as step 10, 3 runs each, median and range); CI before = last green `Lint (pre-commit)` job time on main, after = the PR's own job (`gh run view`, times read from the run, not estimated). State the CI job count: **2** on the 4-core hosted runner.
- Text that quotes the run time: the `#399` hook rule text (the SKIP rule in `AGENTS.md`/skills; grep for "12 minutes", "full run" before editing; `AGENTS.md` is an instruction file -> Ask-First, so this edit is listed for the owner), and the scoping text from #410/#419 (`plan.md` of issue 419 line 9 says "about 12 minutes"; the hook comment and the script_reference row). Each gets the measured figure and its date, no more precision than measured.
- P2 slow-fixture work where cheap, driven by the timing table, not guesses: in `test_register_project.sh` (October 95-118 s; 56.6 s measured under load by the review) copy the `.agent/scripts`, `project_types`, `.claude`, `.claude-plugin` tree once per suite and `cp -a` or hard-link it per sandbox (`:94-99`, seven builds) and shorten the four waited-out `sleep 2` builds via the code's own timeout knob; `test_merge_pr_gate.sh` (42.7 s): build the bare remote and base repo once, clone per case; `test_worktree_create.sh` (17.1 s): the `exec sleep 30` stubs (`:108, 523`) measured first. What lowers the run's floor: the floor under parallel is the slowest single suite, probably `test_cross_model_review.sh` (5,676 lines, never timed yet; time it with the new table). Lowering it means splitting that file into two suites of similar size (each independent, the `# covers:` declarations carried over) or cheaper fixtures; if the table shows it above the next-slowest by more than 30%, splitting is a third PR, otherwise not.
- `.github/workflows` is not touched; `require_serial: true` stays.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/tests/run_script_tests.sh` | PR 1: per-suite TMPDIR, job pool, output capture, shuffle, timings, serial marker, run-all exit rule, header |
| `.agent/scripts/tests/test_run_script_tests.sh` | PR 1: contract pin, new cases (steps 1 and 9); nested runs `-j 1` and clear the env var |
| `.agent/scripts/tests/test_script_tests_hook_scope.sh` | PR 1: only if it pins changed text |
| `.agent/scripts/tests/test_cross_model_review.sh` | PR 1: `sleep_arg` unique per run (or `# serial:`) |
| `.agent/scripts/tests/test_capture.sh`, `test_register_project.sh`, `test_project_file.sh`, `test_sitrep_checks.sh` | PR 1: only if the repeat flags them (wider bound or `# serial:`) |
| `.pre-commit-config.yaml` | PR 1: comment above `validate-script-tests`; no key changes |
| `.agent/knowledge/script_reference.md` | PR 1: runner row (line 52); PR 2: measured time |
| `.agent/scripts/tests/run_script_tests.sh` (default line) | PR 2: effective default on |
| `AGENTS.md` (issue 399 text), hook comment, `.agent/work-plans/issue-419/plan.md` mention | PR 2: measured run time (AGENTS.md is Ask-First) |
| `test_register_project.sh`, `test_merge_pr_gate.sh`, `test_worktree_create.sh` | PR 2: cheaper fixtures where measured |

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
| A change includes its consequences | Header, hook comment, reference row, nested-run fixtures, and in PR 2 the quoted run time are in the plan; other branches' line citations named (step 11) |
| Verify before claiming | Before/after figures come from recorded runs; CI job count read from the run; every runner claim above was read from the file this phase |
| Humans are the bottleneck | Failures-first output, one failing suite's log whole, and a timing table cut the reading and waiting; no early stop hides a second failure |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 (progress timeline) | Yes | This entry; review-plan entry follows |
| CI / branch protection (Ask-First) | No | No `.github/workflows` change; CI uses the runner default via `make lint` (2 jobs on a 4-core runner) |
| Instruction files (Ask-First) | PR 2 only | `AGENTS.md` mentions the run time (issue 399 rule); listed for owner approval then |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Fail-fast and exit-code text | runner header, `test_run_script_tests.sh` pins (`FAILED at`, "remaining suites not run") | Yes (steps 1, 5, 7, 9) |
| TMPDIR guard layout | leak message, header, nested-run fixtures | Yes (steps 2, 7, 8) |
| Runner line numbers | citations on issue 429's and 436's branches | Yes (step 11, refreshed by the second to merge) |
| Quoted run time | issue 399 rule text, 410/419 text, script_reference | PR 2 |
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
| D9 | The flip to default-on is a separate pull request (PR 2) so it can be reverted alone | Merge into PR 1; revert becomes harder |
| D10 | Interrupt kills each job's process group (`setsid` per job) | Without it, an interrupted run can leave suites' helper processes; plain `wait` only |

## Open Questions

- None that block PR 1. The hold-back on load (D8) and an `--fail-fast` option (D1) are the two places a different taste would add code.

## Estimated Scope

Two pull requests: PR 1 about 11 commits, mostly the runner and its tests (large because of the test cases and the repeated independence runs); PR 2 small plus the measured runs and the fixture work, with a possible third PR for splitting `test_cross_model_review.sh` if the timing table calls for it.
