---
issue: 451
---

# Issue #451 — test_cross_model_review.sh: fixtures depend on the host's process behaviour

## Issue Review
**Status**: complete
**When**: 2026-11-12 14:24 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #451

### Scope Assessment

**Well-scoped?** Yes — two fixes in one test file, with the acceptance stated and the out-of-scope sweep findings listed. Part 2 is the larger one. If it needs helper changes (`_cli_review.sh`, `_agy_review.sh`), the issue already requires the plan to say so first. Two commits or two PRs (part 1, then part 2) would keep the steps small, since part 1 is the one that blocks `make lint`.
**Right repo?** Yes — the test and the helpers it exercises are workspace infrastructure under `.agent/scripts/`.
**Serves**: Quality of the work (results that can be trusted, tests that mean what they say) — `docs/design.md#rules` (the test-discipline rows); no section describes test fixtures themselves.
**Design picture?** No change — test fixtures only. A helper change for part 2 (a hook where the child reports before/after `setsid`) would be testability plumbing, not a change to how the parts fit, unless it adds a production-visible interface; if it does, name the `docs/design.md` section then.
**Dependencies**: none blocking. Related and out of scope: #305 (`pgrep -f` self-match), #361 (loose-object fixture), #430 (parent, finding F6).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | OK | Both parts make the tests check what the code promises (the `proc_state` field after the last `)`; the TERM-before-group-exists boundary) instead of host behaviour. Acceptance requires the rewritten tests to fail with the #313 round 4 / #363 fix reverted. |
| A change includes its consequences | Watch | Part 1's comment and the "named 'x y' is reported as finished" case must again show what they say (a process that really ran and exited). The `-x /usr/bin` fixture at line 3767 is only in scope if it is a two-line change; decide that in the plan, not mid-implementation. |
| Only what's needed | OK | The `sleep` copy is replaced by the simplest fixture that works. For part 2, prefer a FIFO or marker file in the test over new helper hooks; a helper change needs a named problem the test cannot solve otherwise. |
| Small steps; step back when they stop converging | Watch | Part 2 replaces a 22-case timing matrix with ordering-based cases. The replacement must keep every case the matrix found (#313 r4, #363: coop/deaf/dead and the three boundary positions). Hold to the issue's own revert check. |
| Verify before claiming | OK | The failure was reproduced on the second machine (918 passed, 2 failed) and the unverified `comm` behaviour of a named script is flagged as something to check first. I confirmed: the only `cp "$(command -v ...)"` in the test suites are lines 3956 and 3957. |
| Know whether it works | OK | Acceptance includes the revert check and a run on both GNU and uutils hosts. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Only if part 2 touches helpers | A helper change must keep per-agent failure markers and `EXIT=` lines and must not add a mode. |
| 0004 / 0005 — Enforcement hierarchy / layered | No | Test fixtures only; `make lint` is the existing local gate. |
| 0017 — Design document is the current picture | No | No change to how the parts fit. |

### Consequences

- If any helper in `.agent/scripts/` changes for part 2: `.agent/knowledge/script_reference.md` and the header comments of `_cli_review.sh` and `_agy_review.sh` (lines 80-91 describe the pre-setsid TERM behaviour).
- If the test's header comment (line ~5370, kind/delay/escalation/limit) describes delays, rewrite it to describe ordering points.

### Recommendations

- Check first, in the plan, whether a script given the name `a Z b` and run directly has `comm` equal to that name or to the interpreter (the issue flags this; the kernel truncates `comm` to 15 characters). If it does not, name the alternative fixture and record the result.
- Make part 1's fixtures assert their own state before `job_finished` is asked: running one is alive (`kill -0` plus state `S`/`R` read from `/proc`), zombie one is state `Z` and its process really started (e.g. a marker file written before it exits).
- For part 2, give the plan a table of the three boundary positions (TERM before group exists, group appears just after the deadline, group exists), each with the ordering mechanism (FIFO/marker, who holds, who releases) and the helper change if any, before implementation.
- Keep the remaining wall-clock limits as hang ceilings only (generous, such as 10 s) and say so in the test comment.
- In the plan, show the revert check concretely: the command to revert the #313 round 4 fix and the #363 fix locally, and the expected failing assertion for each, run once and recorded in the PR description.
- Add to acceptance a repo-wide grep (`cp "$(command -v` and `ln`/`cp` of multi-call tools in `.agent/scripts/tests/`) so "no test copies or renames a host binary" is checked over all 45 suites, not just this file.
- Run the suite (about 2.5 minutes) on a GNU coreutils host as well; this machine is uutils, so the GNU run is not covered by what was reproduced here.

### Actions
- [ ] Check first, in the plan, whether a script given the name `a Z b` and run directly has `comm` equal to that name or to the interpreter (the issue flags this; the kernel truncates `comm` to 15 characters). If it does not, name the alternative fixture and record the result.
- [ ] Make part 1's fixtures assert their own state before `job_finished` is asked: running one is alive (`kill -0` plus state `S`/`R` read from `/proc`), zombie one is state `Z` and its process really started (e.g. a marker file written before it exits).
- [ ] For part 2, give the plan a table of the three boundary positions (TERM before group exists, group appears just after the deadline, group exists), each with the ordering mechanism (FIFO/marker, who holds, who releases) and the helper change if any, before implementation.
- [ ] Keep the remaining wall-clock limits as hang ceilings only (generous, such as 10 s) and say so in the test comment.
- [ ] In the plan, show the revert check concretely: the command to revert the #313 round 4 fix and the #363 fix locally, and the expected failing assertion for each, run once and recorded in the PR description.
- [ ] Add to acceptance a repo-wide grep (`cp "$(command -v` and `ln`/`cp` of multi-call tools in `.agent/scripts/tests/`) so "no test copies or renames a host binary" is checked over all 45 suites, not just this file.
- [ ] Run the suite (about 2.5 minutes) on a GNU coreutils host as well; this machine is uutils, so the GNU run is not covered by what was reproduced here.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 14:24 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (none of the review's actions changes scope)
**After**: issue-actions
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. Read: the Issue Review entry (35f3ba0c). No Principle Alignment row is "Action needed", and it lists no question for the owner. Its seven recommendations are inputs to the plan (check a script's `comm` first, name the three pre-setsid positions and their ordering mechanism, fixtures check their own state, remaining limits are hang ceilings, a revert check for each fix, a repo-wide grep in acceptance, a run on a GNU coreutils host); they go into the plan-task handoff. None adds or drops a behaviour the issue asks for.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 14:27 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-451/plan.md` at `53ce1928`

Part 1 sets the fixtures' own comm via /proc/self/comm (a script named "a Z b" shows the interpreter as comm, tested) with state assertions; part 2 replaces the delay matrix with FIFO/marker ordering at three positions and ceilings of 10 s. One PR, two commits; GNU check is CI's ubuntu-latest Lint job.

## Plan Review
**Status**: complete
**When**: 2026-11-12 14:29 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #451 — test_cross_model_review.sh: fixtures depend on the host's process behaviour
**Plan**: `.agent/work-plans/issue-451/plan.md` at `53ce1928`
**Branch**: `feature/issue-451`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One file, two commits, part 1 first (it unblocks `make lint`); line 3767 taken as the two-line change the issue allows. |
| Issue alignment | Needs work | Serves: "Quality of the work (results that can be trusted, tests that mean what they say), `docs/design.md#rules`" (checked: `README.md` "Quality of the work", `docs/design.md` "## Rules"). Part 1 meets the issue and every review-issue action. Part 2's table answers the review-issue action, but position B as written does not reach "group appears just after the deadline" (finding 1), and two properties the old matrix checked are lost (finding 2). |
| File targeting | Good | Test file only; helper files and `script_reference.md` named as conditional consequences. |
| Consequences | Good | Header comment rewrite, fixture comments, conditional helper docs all listed. |
| Principle alignment | Needs work | "Test what breaks": the revert check would not fail for position B, and the TERM-to-PID and no-wait paths of #363 go untested once the time assertions are removed (findings 1, 2). Part 1 checked here: a bash that writes `/proc/self/comm` gives `(a Z b) S` running and `(x y) Z` zombie with its marker written (bash 5.3.9, this machine). |
| ADR compliance | Good | ADR-0015 only if helpers change (not planned); ADR-0017 no design change. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment — Test what breaks]** (high) Position B's ordering is inverted. The wrapper "releases the FIFO and polls until the group exists, then lets the watchdog's `kill -KILL` through", so the KILL always lands on an existing group: that is position C after the deadline. Under the plan's own #363 revert (watchdog `signal_cli KILL`, group only) the group KILL finds the group and kills it, so B passes, and the claim "expect position A deaf and position B to fail" is false for B. The #363 defect (372d002a: "the watchdog found no group and did nothing, ... and the group appeared just after") needs the KILL delivered while the child is still held pre-setsid, then the FIFO released: fixed code kills the PID, the revert misses and the deaf `setsid sleep 30` then hangs `wait` to the ceiling. Also key the trigger on the CLI PID argument, not "the first `kill -KILL`": the watchdog is a subshell, so a "first" flag set there is not seen by the handler, whose own later `kill -KILL "$watchdog"` would match again.
2. **[Issue alignment — keep every case the matrix found]** (high) Replacing every "handler returned inside Ns" assertion with state assertions and a 10 s ceiling drops what the escalation axis checked. `coop:0.3:5:2` (escalation 5, limit 2) proved the TERM reaches the pre-setsid PID (#363 step 1); with escalation 0.4 and state-only asserts, coop A still passes if the TERM never reaches it, because the deadline KILL ends it. `dead:0:5:1` caught the old group-wait loop ("the dead case takes 5.5 s on the previous code", 372d002a); a 5.5 s return passes a 10 s ceiling. The 12-case list also drops `coop:0.5:0:1` (escalation 0) without saying what it covered. Resolution: for coop and dead, use an escalation beyond the hang ceiling (e.g. 30 s), so returning before the ceiling proves the TERM/no-wait path by a margin of seconds, not hundredths; or log signals with the `kill` wrapper and assert no KILL was sent. Add a revert step for `signal_live_cli TERM` -> `signal_cli TERM` with its expected failing case, and keep or explicitly retire the escalation-0 case.
3. **[Principle alignment]** (low) Dead case: a marker the child writes before exiting does not show it has exited and been reaped when `terminate_child` runs; the handler may then TERM a live child and the case stops testing "dead". `wait "$<P>_PID"` in the probe reaps it deterministically.
4. **[Consequences — acceptance grep]** (low) After step 3, line 3767 becomes `ln -sf "$(command -v "$tool")" ...`, which matches `ln .*command -v`, so "lists only `test_ros2_colcon.sh:898`" is wrong. The pattern also misses copies by fixed path (`cp /usr/bin/sleep "x y"`). State the expected output and widen the pattern (e.g. any `cp`/`ln` whose target name differs from the tool's) or say the grep is a heuristic.
5. **[Issue alignment — acceptance]** (info, owner) The issue's acceptance names "the first machine with GNU coreutils"; the plan offers CI's `ubuntu-latest` Lint job (checked: `validate.yml` runs `make lint`; the hook comment says the all-files run reaches every suite) with the owner's machine as backup. Owner to confirm the CI run satisfies that line.

### Summary

Part 1 is sound and verified on this machine. Part 2's structure (FIFO hold, marker, test-side `kill` wrapper, no helper change) is right, but position B as written tests position C, and dropping every time assertion loses the coop-TERM and dead no-wait checks; fix both before implementation so the revert check proves what it claims.

### Recommended Actions

- [ ] Reorder position B: deliver the watchdog's KILL while the deaf child is still held, then release; trigger on the CLI PID argument; correct the revert-check expectation.
- [ ] Give coop and dead cases an escalation beyond the hang ceiling (or a no-KILL assertion from a kill log), add a `signal_live_cli TERM` revert step, and account for the escalation-0 case.
- [ ] Dead case: reap the child with `wait` in the probe instead of a marker.
- [ ] Fix the step 4 grep's expected output (line 3767 will match) and widen or qualify the pattern.
- [ ] Ask the owner whether CI's `ubuntu-latest` Lint job satisfies the "first machine with GNU coreutils" acceptance line.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 14:30 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work with two high findings on part 2)
**After**: plan
**Decision**: revise

Host answer under /orchestrator's checkpoint table (first `revise` at this checkpoint). Read: the Plan Review entry (3fe6e428), verdict needs-work. Two high findings: position B as planned tests position C and would still pass with the #363 fix reverted; and removing every time assertion drops what `coop:0.3:5:2` and `dead:0:5:1` checked (TERM reaches the child before setsid; the old group-wait loop), with the escalation-0 case dropped unexplained. Two low findings: the dead case should reap its child; the step 4 grep's expected output is wrong and misses fixed-path copies. The plan goes back to plan-task with these.

### Decisions made (owner may veto)
- The acceptance line "passes on the first machine with GNU coreutils" is met by a green Lint job on GitHub's `ubuntu-latest` runner (GNU coreutils), confirmed in that job's log, since no GNU host is reachable from this session; the issue's intent is a pass on both coreutils. Undoing it: run the suite once on the first machine before merge.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 14:33 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-451/plan.md` at `d7d8a1b9`

Revision answering the plan review: position B now delivers the KILL while the deaf child is held, then releases it (keyed on the CLI PID); time checks kept by an escalation of 30 s beyond the 10 s ceiling, with a TERM revert step and the escalation-0 case kept; dead case reaps with wait; acceptance grep corrected. Reverts for TERM and KILL tried on a prototype here.

## Plan Review
**Status**: complete
**When**: 2026-11-12 14:36 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #451 — test_cross_model_review.sh: fixtures depend on the host's process behaviour
**Plan**: `.agent/work-plans/issue-451/plan.md` at `d7d8a1b9`
**Branch**: `feature/issue-451`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One file, two commits, part 1 first; line 3767 taken as the two-line change the issue allows. |
| Issue alignment | Good | Serves: "Quality of the work (results that can be trusted, tests that mean what they say), `docs/design.md#rules`" (unchanged from the checked first review). Every earlier finding is answered: B now KILLs the held child then releases (keyed on the PID argument); coop, coop-esc-0 and dead use escalation 30 s beyond the 10 s ceiling; a `signal_live_cli TERM` revert step is added; dead reaps with `wait`; grep expected output corrected; the GNU line is the host's recorded decision (CI `ubuntu-latest` Lint). |
| File targeting | Good | Test file only; helper docs conditional. |
| Consequences | Good | Header comment rewrite, fixture comments, conditional helper docs. |
| Principle alignment | Good, with notes | "Test what breaks": verified here that B as revised discriminates (findings below are about stating the mechanics so the implementation reproduces the prototype). |
| ADR compliance | Good | ADR-0015 only if helpers change (not planned); ADR-0017 no design change. |
| ROS conventions | N/A | Workspace plan. |

Verified by running (this machine, uutils, scratch copies only): deaf A and deaf B against `_cli_review.sh` both exit 143 with the child gone in 0.4 s; with the watchdog reverted to `signal_cli KILL` both exit 137 at the ceiling with the child alive. The step 4 grep today lists exactly `test_ros2_colcon.sh:898` and `test_cross_model_review.sh` 3767, 3768, 3956, 3957, as the plan says. `proc_state` is at `cross_model_review.sh:919` and the awk revert would misread both fixtures as the plan expects (reasoned from `job_finished`).

### Findings

1. **[Principle alignment — Test what breaks]** (medium) The `kill` wrapper must return the real `kill`'s exit status. The handler's group-wait loop reads it (`while signal_cli 0 "$CLI_PID" && kill -0 "$watchdog"`), and a wrapper written as the plan words it ("runs the real kill, then, if ..., writes the FIFO") ends in an `if` that returns 0, so `kill -0` always succeeds and the fixed handler spins to the ceiling. Run here: such a wrapper makes deaf B fail on the unreverted `_cli_review.sh` (exit 137 after 6 s); saving `rc` from `builtin kill` and returning it passes in 0.4 s. State this in the plan or the test comment.
2. **[Approach — revert check]** (low) "a scratch copy of the helper that the test's script variable points at": the test has no such variable. Both probes read `${SCRIPT_DIR}/../<file>`, and `SCRIPT_DIR` comes from `BASH_SOURCE` (line 11). Name the real mechanism (edit the helper in the worktree and restore it with `git checkout --`, or copy test and helpers into a scratch tree).
3. **[Approach — part 1]** (low) The new fixture-state check ("state `S`/`R`", "state `Z`") should read `/proc/<pid>/stat` with test-side code, not the extracted `proc_state`. Otherwise, with the #313 r4 revert, the fixture check itself reports the fixture in the wrong state and the revert record cannot tell a broken fixture from the caught regression.
4. **[Issue alignment]** (info) Under every listed revert deaf B gives the same verdict as deaf A (both hang, run here). B is still the only case that reaches "group appears just after the deadline" as the issue names it; a sentence in the test comment saying so would stop a later reader from deleting it as a duplicate.
5. **[Approach — wording]** (info) "a timeout shows as exit 124": the handler ignores TERM, so a deaf hang ended as 137 here (`timeout -k 1`). Either fails "handler exits 143"; only the wording is off.

### Summary

The revision answers both earlier high findings and both low ones, and the B mechanism works as described when run. The remaining points are implementation details to carry into the code (finding 1 is the one that would make a correct handler fail); ready for implementation.

### Recommended Actions

- [ ] The `kill` wrapper keeps and returns `builtin kill`'s status; say so in the test comment.
- [ ] Name the actual revert mechanism (no script variable exists).
- [ ] Part 1 fixture-state checks parse `/proc` in test code, independent of `proc_state`.
- [ ] Note in the test comment why deaf B is kept beside deaf A; fix the 124/137 wording.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 14:37 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second plan review's verdict is ready; its findings are implementation details)
**After**: plan
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. Read: the second Plan Review entry (1e5acabe), verdict ready, on the plan at d7d8a1b9. It confirms the revision answers all four earlier findings. Its own findings do not change the approach and go to the implement pass, which reads them on this timeline: (medium) the test's `kill` wrapper must return the real `kill`'s exit status, or the handler's group-wait loop spins and the correct handler fails deaf B; (low) the revert checks need a real way to swap in a reverted helper, since no script variable exists for it; (low) part 1's fixture-state check reads /proc with the test's own code, not the extracted `proc_state`; (info) the test comment says deaf B is the only case reaching "group appears just after the deadline"; (info) a deaf hang ends as exit 137, not 124.

## Implementation
**Status**: complete
**When**: 2026-11-12 14:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-451 at `d09d7431`

- Part 1 (53c86856): `test_job_finished_proc_comm_with_space` no longer copies `sleep`. Each fixture is a bash that writes its own comm through `/proc/self/comm` and blocks on a FIFO; the zombie is released only after its parent has exec'd the non-reaping `sleep`, and writes a marker before exiting. Before `job_finished` is asked, the test reads state and comm from `/proc/<pid>/status` and `/proc/<pid>/comm` (its own code, not `proc_state`) and fails by name (`FIXTURE-BAD`) if a fixture is not where its assertion assumes. PATH-without-jq fixture: tools linked from `type -P`, not hardcoded `/usr/bin`/`/bin` (deviation from the plan's `command -v`: `kill` and `printf` are builtins, for which `command -v` prints the bare name).
- Part 2 (d09d7431): pre-setsid matrix rewritten to positions A / B / C / dead reached by FIFO hold and marker, 7 cases per helper (14, was 22). B's `kill` wrapper returns the real kill's status and is keyed on the CLI PID / `-PID` argument. coop and dead use escalation 30 s beyond the 10 s hang ceiling (`timeout -k 1 10`), the only wall-clock limit; the "returned inside Ns" assertions are gone. Test comment rewritten: ordering points, why B is kept beside deaf A, 124 vs 137.
- Suite here (Ubuntu 26.04, uutils 0.10.0): `bash .agent/scripts/tests/test_cross_model_review.sh` 891 passed, 0 failed (was 918/2; 88 old matrix assertions replaced by 56, 3 fixture assertions added).
- Final `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP: all hooks passed, including the script test suite hook and shellcheck.
- Revert checks, run in a scratch copy of `.agent/scripts` (test and helpers copied together so `${SCRIPT_DIR}/../<file>` reads the reverted file; committed helpers unchanged):
  - #313 r4, `proc_state` with `stat=$(awk '{print $3}' <<<"$stat")`: fixture checks pass; FAIL "a running job named 'a Z b' is reported as running", "a zombie named 'x y' is reported as finished", "no misreport of a running job", "no misreport of a dead job" (4 failed).
  - #363 TERM-to-PID (`signal_live_<fn> TERM` -> `signal_<fn> TERM`), `_cli_review.sh` and `_agy_review.sh` each: FAIL "<file> coop position A, escalation 30s: handler exits 143" (exit 124); all else passes.
  - #363 watchdog KILL-to-PID (`signal_live_<fn> KILL` -> `signal_<fn> KILL`), each helper: FAIL deaf position A and deaf position B, "handler exits 143" (exit 137) and "the CLI is killed"; deaf C passes.
  - Not run: the pre-372d002a group-wait loop for the dead case (the extraction does not apply to that file), as the plan says.
- Acceptance grep `(cp|ln)\b.*(command -v|type -P|/usr/s?bin/|/bin/|\$path)` over `.agent/scripts/tests`: only same-name symlinks (`test_ros2_colcon.sh:898`, this file's jq fixture and its existing no-setsid shim); no copy or rename of a host binary.
- Not done here: the GNU coreutils run is left to CI's `ubuntu-latest` Lint job (host decision on this timeline).
