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
