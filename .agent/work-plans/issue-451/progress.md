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
