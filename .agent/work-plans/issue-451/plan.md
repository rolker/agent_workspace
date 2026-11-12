# Plan: test_cross_model_review.sh: fixtures depend on the host's process behaviour

## Issue

https://github.com/rolker/agent_workspace/issues/451

## Context

`.agent/scripts/tests/test_cross_model_review.sh` has two host-dependent fixtures. (1) `test_job_finished_proc_comm_with_space` (lines 3943-3985) copies `sleep` to `a Z b` / `x y`; uutils' multi-call `sleep` dispatches on its file name and exits at once, so 2 assertions fail and the zombie case passes for the wrong reason. (2) `test_helper_terminate_reaches_a_cli_before_setsid` (lines 5376-5440) uses 11 delay/escalation/limit cases per helper, placed 0.01-0.05 s either side of a 0.4 s escalation; the side of the boundary is decided by machine speed. Part 1 blocks `make lint` on this machine; part 2 passes today.

Checked here (Ubuntu 26.04, uutils 0.10.0):
- A script run directly under a spaced name does NOT carry the name in `/proc/<pid>/stat`: `"./a Z b"` (bash script) shows `(bash)`, the kernel takes `comm` from the interpreter. So "a small script given that name" does not work.
- Writing the name into the process's own `comm` does: `bash -c 'printf "a Z b" > /proc/self/comm; s=$(< /proc/$$/stat); ...'` gives `636626 (a Z b) R ...`. (Use `printf` without newline: `echo` puts a newline inside the parentheses. Do it in a bash that does not exec its last command; an exec resets comm.) This is Linux-only, as is the `/proc` test, which already skips without `/proc`. It needs no copied binary, so it is identical on GNU and uutils.

## Approach

Part 1 (commit 1):
1. Replace the two `cp` lines with fixture processes that set their own comm: a running one (`bash -c 'printf "a Z b" > /proc/self/comm; echo up > marker; read -r _ <&3'`, FIFO held open read-write, so it blocks without `sleep`) and a zombie (a subshell of a non-reaping parent, as today, that sets comm `x y`, writes a marker file, then exits). Keep the existing non-reaping-parent structure and its comment, updated.
2. Add fixture-state assertions before `job_finished` is asked: wait for each marker (bounded loop, not a fixed sleep); running one: `kill -0` plus `/proc` state `S`/`R`, and its comm really reads `a Z b`; zombie: state `Z` and comm `x y`, and the marker proves it ran. A fixture in the wrong state prints a FAIL naming the fixture (not a silent pass).
3. Lines 3767-3768 (PATH-without-jq fixture): swap the hardcoded `/usr/bin` and `/bin` probes for one `command -v "$tool"` link, as `test_ros2_colcon.sh:898` does (each tool keeps its own name, so uutils dispatch still works). Taken because it is small; the other sweep items stay out of scope.
4. Repo-wide check, a heuristic: `grep -rnE '(cp|ln)\b.*(command -v|/usr/s?bin/|/bin/)' .agent/scripts/tests`. Expected after the change: exactly `test_ros2_colcon.sh:898` and the rewritten `test_cross_model_review.sh` line near 3767, both symlinks whose link name is the tool's own (`$tool`). Before the change it also lists 3767, 3768, 3956, 3957 (the `sleep` copies). Any hit whose target name differs from the source name fails the check; the grep is a heuristic and the hits are read, not counted.

Part 2 (commit 2). Replace delays with ordering. The child is `bash -c 'exec 3<>fifo; [trap "" TERM HUP;] echo up > pre.mark; read -r _ <&3; exec setsid sleep 30'`: it opens the FIFO read-write, writes `pre.mark`, and blocks until something writes the FIFO. The test waits for `pre.mark` (bounded loop, not a sleep), then runs the extracted `terminate_child`. A `kill` function wrapper in the probe (same idea as `test_helper_term_with_the_sweep_pending`) releases the child by writing the FIFO. No helper change: the hooks are in the test. Prototyped in the session scratchpad against `_cli_review.sh` (results below).

| Position | Hold / release | Escalation | Asserts |
|---|---|---|---|
| A. TERM before the group exists | child held for the whole handler run (coop: dies on TERM; deaf: TERM and HUP ignored, only the deadline KILL ends it); nothing releases | coop 30 s, deaf 0.4 s; one more coop case at 0 | handler returns 143 before the hang ceiling; child gone |
| B. group appears just after the deadline (deaf only) | deaf child held; the `kill` wrapper runs the real kill, then, if the signal is `-KILL` and the last argument is the CLI PID or `-PID` (keyed on the argument, not on "the first KILL", since the watchdog is a subshell and the handler's own `kill -KILL "$watchdog"` must not match), writes the FIFO | 0.4 s | handler returns 143 before the ceiling; child gone. With the #363 fix the PID KILL lands on the held child and kills it. Without it the group KILL finds no group, the release then lets `setsid sleep 30` make its group, and `wait` hangs to the ceiling |
| C. group already exists | test writes the FIFO, then polls `kill -0 -- -PID` (bounded) before `terminate_child` | coop 30 s, deaf 0.4 s | group TERM / deadline KILL end it; handler returns 143 before the ceiling; child gone |
| dead | probe starts `bash -c 'exit 0'` and runs `wait "$<P>_PID"` itself, so the child has exited and is reaped before `terminate_child` (no marker) | 30 s | returns 143 before the ceiling |

Time is no longer asserted finely. The properties the old matrix read from the clock are kept by making the margin seconds wide: coop, dead and the escalation-0 case use an escalation of 30 s, beyond the 10 s hang ceiling, so returning before the ceiling proves the handler did not wait for the deadline KILL: coop A (old `coop:0.3:5:2`) proves the TERM reaches the pre-setsid PID; dead (old `dead:0:5:1`) proves the handler does not wait on an empty group (the old group-wait loop took 5.5 s). Escalation 0 (old `coop:0.5:0:1`) covered a watchdog that fires at once, racing the TERM: kept as coop A with escalation 0 (handler still returns 143 with the child gone, the KILL and TERM both aimed at a held child). Deaf cases keep escalation 0.4 s, which is a deadline the test needs, not a boundary it probes.
5. Test shape: per helper (`_cli_review.sh` and `_agy_review.sh`) 7 cases: coop A, coop A (esc 0), coop C, deaf A, deaf B, deaf C, dead (14 in all, down from 22); the old delay cases collapse because positions replace delays. Each asserts exit 143, no shell errors in stderr, and the recorded child gone (`pid_state`). All wall-clock limits become 10 s hang ceilings (outer `timeout -k 1 10`) and the "handler returned inside Ns" assertion goes; a timeout shows as exit 124 and fails "handler exits 143". Rewrite the test's header comment (kind/delay/escalation/limit) to describe the positions and say the ceilings only catch hangs.

Revert check (run once, recorded in the PR description; each is made in a scratch copy of the helper that the test's script variable points at, never committed). Tried here on the plan's prototype against `_cli_review.sh` with a 3-4 s ceiling:
- #313 r4: in `proc_state` (line 919) change `stat=${stat##*) }` to `stat=$(awk '{print $3}' <<<"$stat")`; expect "a running job named 'a Z b' is reported as running" and the `x y` zombie assertion to fail. Reasoned, not yet run (needs the part 1 fixtures).
- #363 TERM-to-PID: change `signal_live_cli TERM "$CLI_PID"` to `signal_cli TERM "$CLI_PID"` in the handler. Run: coop A (esc 30) fails (exit 124 at the ceiling); every other case still passes. This is the case the old `coop:0.3:5:2` covered.
- #363 KILL-to-PID: change the watchdog `signal_live_cli KILL "$CLI_PID"` to `signal_cli KILL "$CLI_PID"`. Run: deaf A and deaf B fail (exit 137, child still alive, handler stuck in `wait`); deaf C passes, as it should since the group exists.
- Not run: the pre-372d002a group-wait loop for the dead case (the old file lacks `signal_live_cli`, so the extraction does not apply); reasoned: with escalation 30 the loop would run to the ceiling and fail "handler exits 143".
Repeat the same three helper reverts on `_agy_review.sh` when implementing.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/tests/test_cross_model_review.sh` | Part 1 fixtures and state assertions; lines 3767-3768 `command -v`; part 2 ordering-based rewrite and comment |
| `.agent/work-plans/issue-451/` | plan and progress |

## Prior Art

`test_helper_term_with_the_sweep_pending` (BASH_ENV DEBUG trap and `kill` wrapper) and the existing non-reaping-parent zombie are reused. `test_ros2_colcon.sh:898` is the model for the `command -v` change. Rejected: a script named `a Z b` (comm is the interpreter, tested above); `exec -a` (sets argv[0], not comm); copying `sleep` (the bug); a helper test hook (not needed yet).

## Serves

Quality of the work (results that can be trusted, tests that mean what they say), `docs/design.md#rules`.

## Design Picture

No change to the design picture (test fixtures only).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Both tests assert the promised behaviour; the revert check proves each fails without its fix |
| A change includes its consequences | Header and fixture comments rewritten with the code; repo-wide grep done |
| Only what's needed | Test-only hooks; helper unchanged unless B proves impossible |
| Small steps | Two commits, part 1 first (it unblocks `make lint`) |
| Verify before claiming | comm behaviour checked here; GNU verified in CI (below) |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0015 | Only if helpers change | Not planned |
| 0017 | No | No design change |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| test header comment (~5370) | rewrite to ordering points | Yes |
| helper (only if forced) | `script_reference.md` rows 43-44, helper header comments | Only then |

## Acceptance checks

- Suite passes here (uutils): `bash .agent/scripts/tests/test_cross_model_review.sh` (about 2.5 min) and `make lint` using `/home/roland/agent_workspace/.venv`.
- GNU coreutils: no GNU host is reachable from this session. The owner decided (checkpoint after the plan review) that a green `Lint (pre-commit)` job on GitHub's `ubuntu-latest` runner (GNU coreutils), confirmed in that job's log, meets the issue's "first machine with GNU coreutils" line. `make lint` -> `pre-commit run --all-files` in `.github/workflows/validate.yml` runs every suite including this one; confirm by reading the log for the cross-model suite's "passed" line. Undo: run the suite once on the first machine before merge.
- Revert check outputs recorded in the PR.
- Grep (step 4): hits are only same-name symlinks.

## Open Questions

- None for the owner. The position B trigger is prototyped and reverts as expected; implementation re-checks it on `_agy_review.sh`.

## Estimated Scope

One pull request, two commits (part 1, part 2); both touch one file.
