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
3. Line 3767 (PATH-without-jq fixture): swap the hardcoded `/usr/bin` and `/bin` probes for `command -v "$tool"` as `test_ros2_colcon.sh:898` does (two-line change; each tool keeps its own name, so uutils dispatch still works). Taken because it is small; the other sweep items stay out of scope.
4. Repo-wide check: `grep -rnE 'cp .*command -v|ln .*command -v' .agent/scripts/tests` lists only `test_ros2_colcon.sh:898` (a symlink under the tool's own name, not a rename) after the change.

Part 2 (commit 2). Replace delays with ordering. The child is `bash` that writes `pre.mark`, blocks on a FIFO it opened read-write (so TERM-ignoring is separate from holding), then `exec setsid sleep 30`. The test waits for `pre.mark` (not a sleep), then runs the extracted `terminate_child`. A `kill` function wrapper in the probe (same pattern as `test_helper_term_with_the_sweep_pending`) releases the FIFO at the chosen signal. No helper change is planned: the hooks are in the test.

| Position | Hold / release | Who holds, who releases | Asserts |
|---|---|---|---|
| A. TERM before the group exists | child held at FIFO for the whole handler run (coop: dies on TERM; deaf: only the deadline KILL ends it) | test holds; nothing releases | handler returns 143, child gone (pid_state), within the hang ceiling |
| B. group appears just after the deadline | deaf child held; wrapper releases the FIFO and polls `kill -0 -- -PID` until the group exists, then lets the watchdog's `kill -KILL` through | probe wrapper on the first `kill -KILL` | child (now group leader) gone; handler not stuck waiting |
| C. group already exists | child released and group confirmed (`kill -0 -- -PID`) before `terminate_child` runs | test, via `pre.mark`/group poll | group TERM path kills coop child; deaf child by deadline KILL |
| dead (existing) | child writes marker and exits; test waits for it, not 0.3 s | n/a | handler returns 143 |

The exact wrapper trigger for B is finalised in implementation and decided by the revert check below. If B cannot be reached without a helper hook, stop and say so before changing `_cli_review.sh`/`_agy_review.sh` (then `script_reference.md` rows 43-44 and the helper header comments at lines 80-91 follow).
5. Escalation stays 0.4 s where a deadline is needed. All wall-clock limits become hang ceilings of 10 s (outer `timeout -k 1 8` raised accordingly), and the "handler returned inside Ns" assertion is replaced by the state assertions; rewrite the test's header comment (kind/delay/escalation/limit) to describe ordering points and say the ceilings only catch hangs.
6. Keep every case the matrix found: coop/deaf/dead x positions A, B, C, for both helpers (22 cases become 2 x (coop A, coop C, deaf A, deaf B, deaf C, dead) = 12 plus the hang-ceiling checks).

Revert check (run once, recorded in the PR description):
- #313 r4: in a scratch copy of `cross_model_review.sh`, change `stat=${stat##*) }` in `proc_state` (line 919) to `stat=$(awk '{print $3}' <<<"$stat")`; expect "a running job named 'a Z b' is reported as running" (the awk $3 reads `Z`) and, for `x y`, the zombie assertion, to fail.
- #363: in scratch copies of both helpers, change the watchdog `signal_live_cli KILL "$CLI_PID"` to `signal_cli KILL "$CLI_PID"` (group only; the pre-fix behaviour); expect position A deaf and position B to fail ("the CLI is killed" / handler stuck at the hang ceiling).
Reverts are made in a copy pointed at by the test's script variable, never committed.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/tests/test_cross_model_review.sh` | Part 1 fixtures and state assertions; line 3767 `command -v`; part 2 ordering-based rewrite and comment |
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
- GNU coreutils: no GNU host is reachable from this session. CI's `Lint (pre-commit)` job runs `make lint` -> `pre-commit run --all-files` on `ubuntu-latest` (GNU coreutils, `.github/workflows/validate.yml`); `--all-files` exceeds the `--files` limit so `run_script_tests.sh` runs every suite, including this one. A green Lint job on the PR is the GNU evidence; the owner's GNU machine is the backup. To confirm, read that job's log for the cross-model suite's "passed" line.
- Revert check outputs recorded in the PR.
- Grep: no `cp`/rename of a host binary in `.agent/scripts/tests/`.

## Open Questions

- None for the owner. Implementation-time risk: position B's trigger (above).

## Estimated Scope

One pull request, two commits (part 1, part 2); both touch one file.
