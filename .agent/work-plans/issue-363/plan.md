# Plan: Cross-model reviewer scripts still lack seven hardening fixes the fork found

## Issue

https://github.com/rolker/agent_workspace/issues/363

Scope after the owner's split (checkpoint in `progress.md`, 2026-09-29): this issue
is **P1a-P1d only**. P1e-P1g (`--work-dir` vs `--no-progress`, closing-keyword
regex, `assert_*` helpers) moved to #369 and are not planned here. #363 lands
first; #344 (drop the Copilot CLI) rebases across `_cli_review.sh` afterwards.

## Context

`cross_model_review.sh` (parent) runs one background job per agent, each running
`_cli_review.sh` (codex/claude/copilot) or `_agy_review.sh` (gemini) under
`timeout -k "$AGENT_KILL_AFTER"`. Four lifecycle gaps, all ported from
rolker/ros2_agent_workspace PR #662 (commits 5af570f, 69a6907, 5818535, b5f080a,
read as diffs in the local fork clone):

- `AGENT_KILL_AFTER=0` is accepted, but `timeout -k 0` *disables* the SIGKILL.
- The helpers signal only the CLI's PID (`kill "$CLI_PID"` / `kill -9 "$AGY_PID"`),
  so a TERM-ignoring grandchild survives the helper.
- A TERM between `cmd &` and `PID=$!` finds no PID to signal (CLI in both helpers,
  the helper in `run_agent_job`, the job in the parent loop).
- Nothing serializes two runs into one `.agent/work-plans/issue-<N>/`; prompt and
  findings names are fixed per agent, so they clobber each other.

The fork's `kill_tree` (its a2b04c8: cleanup's hard kill takes the whole job
tree, not just the job shell) does not exist here, and no open issue tracks it
(#369 is P1e-P1g; a search of open issues finds only umbrella #172). Our
`cleanup_jobs` still SIGKILLs only the job shell when the reap budget runs out,
orphaning `timeout`, the helper and the CLI. Out of scope here; the PR
description should flag it as an untracked gap for the owner to file or decline.
The plan review (finding 10) asked that this be stated, not that anything be filed.

## Approach

Commit order follows the fork (P1a first: it deletes the carve-outs P1b touches).

1. **P1a: refuse `AGENT_KILL_AFTER=0`.** In `cross_model_review.sh` call
   `validate_duration_knob AGENT_KILL_AFTER ... false false "<reason: timeout -k 0
   disables the SIGKILL>"` and reword the `$3 allow_zero` comment (no caller uses
   it now; keep the parameter). In `_cli_review.sh` (~L174-181) and
   `_agy_review.sh` (~L130-137) drop the both-zero carve-out: condition becomes
   `KILL_AFTER_SECONDS -le ESCALATION_SECONDS` and the "(set both to 0 ...)" hint
   goes. Update the `# AGENT_KILL_AFTER` comment at `cross_model_review.sh:137-141`.
2. **P1b: process-group kill.** In both helpers add `CLI_SETSID`/`AGY_SETSID`
   (`setsid` if present, else empty) and `signal_cli KILL|TERM|0 <pid>` which uses
   `kill -SIG -- -PID` in group mode and `kill -SIG PID` otherwise. Launch with
   `"${CLI_SETSID[@]}" "$@" ... &` (agy likewise); in a non-interactive shell a
   background job is not a group leader, so setsid execs in place and `$!` is the
   group id. Empty-array expansion is written `${CLI_SETSID[@]+"${CLI_SETSID[@]}"}`
   (the helpers run `set -u`; bash < 4.4 treats a bare `"${arr[@]}"` of an empty
   array as unbound, and that is exactly the no-setsid path). `terminate_child`:
   TERM the group, watchdog kills the group, then after `wait` poll the group for
   `ESCALATION_SECONDS*10` ticks and SIGKILL it (fork 69a6907). After a normal
   `wait`, sweep the group with KILL. Both sweeps run in group mode only (fork
   5818535): a bare reaped PID may be reused, so the no-setsid fallback keeps
   today's PID-only TERM/watchdog behaviour and nothing more.
   **Watchdog cancel (prerequisite fix, fork 06871f4 then a2b04c8; review finding
   M1).** `terminate_child` runs `trap '' INT TERM HUP` and then forks the
   watchdog, which inherits the ignored TERM, so today's `kill "$watchdog"`
   (`_cli_review.sh:250`, `_agy_review.sh:178`) is a no-op: the watchdog outlives
   every clean shutdown by the whole escalation window and then SIGKILLs the dead
   CLI's PID, which under P1b would be `kill -KILL -- -PGID` on a group id that
   may have been reused. Port a2b04c8's form in both helpers: cancel with
   `pkill -KILL -P "$watchdog"` (its `sleep`, while still findable) then
   `kill -KILL "$watchdog"`; rewrite the comment that claims the watchdog "cannot
   hit a recycled PID" (`kill -0` checks a PID, not identity).
   **setsid vs `timeout` (finding S4).** GNU `timeout` (no `--foreground`) sends
   its TERM and the `-k` KILL to its own process group; today the CLI and its
   children are in it. After setsid the CLI's group is outside it, so the helper's
   forwarding is the only path to the CLI, and if the helper itself is SIGKILLed
   nothing reaches the CLI group. That is safe only while
   `REVIEW_KILL_ESCALATION < AGENT_KILL_AFTER`, which P1a now enforces strictly
   (no zero carve-out). The post-`wait` poll (`ESCALATION_SECONDS*10` ticks of
   `sleep 0.1`, each a fork) can overrun the escalation by a few hundred ms: fine
   at the 5 s/10 s defaults, tight at `KILL_AFTER = ESCALATION + 1`. The plan
   keeps the fork's loop and the ADR bullet states the dependency; implementation
   should measure the overrun once and, if it exceeds ~0.5 s, budget the loop by
   elapsed time rather than tick count.
3. **P1c: close the launch window** (fork 5818535). Helpers: `CLI_LAUNCHING`,
   `CLI_LAUNCH_PREV="${!:-}"` set before the `&`, `CLI_LAUNCHING=false` after
   `CLI_PID=$!`; the top of `terminate_child` adopts `$!` when `CLI_PID` is empty,
   launching is true and `$!` differs from the recorded previous value. Same for
   `AGY_PID`. `run_agent_job`: `launch_prev` local and the TERM trap adopts `$!`
   into `child`. Parent: `LAUNCHING_AGENT`/`LAUNCH_PREV` globals, adopted in
   `cleanup_jobs` when `AGENT_PID[$LAUNCHING_AGENT]` is unset.
4. **P1d: one run per issue dir, locking the directory itself (finding S6).**
   After `mkdir -p "$WORK_PLANS_DIR"` (~L673) and before any prompt/findings
   write: `exec 9< "$WORK_PLANS_DIR"` (open failure -> exit 4), then
   `flock -n 9 || exit 5` with a message naming the dir. Departure from the fork
   (which locks `.cross-model-review.lock`): the script also runs in project
   worktrees where the workspace `.gitignore` does not apply, so a lock file
   would show up untracked there (against zero-footprint, #335). Verified on this
   host (Linux, util-linux flock): `exec 9< <dir>; flock -n 9` acquires, and a
   second open of the same directory is refused. If the host's `flock` cannot lock
   a directory (some BSD/macOS ports; probe once with `flock -n 9` right after the
   open), the fallback is the fork's lock file `${WORK_PLANS_DIR}/.cross-model-review.lock`
   opened `9>>` plus the `.gitignore` entry, and a stderr note about the footprint;
   no `flock` at all: warn and proceed unserialized, as the fork does.
   `--no-progress` uses a fresh mktemp dir, so it never contends. Launch the jobs
   `run_agent_job "$agent" 9>&- &` so nothing a job leaves behind holds the lock.
   No `.gitignore` change in the primary path.
5. **Docs (same PR).** Script header exit-code list: add `5`. ADR-0015 (~L105-108):
   drop the "`AGENT_KILL_AFTER=0` is excepted" clause; add a short bullet on
   process-group kill (including the setsid/`timeout` dependency on
   `ESCALATION < AGENT_KILL_AFTER`), the launch-window adoption and the per-dir
   lock. Record it on the ADR's Status line ("Amended by #363: ...") as #320 did
   for its amendment (finding S8). This is a substantive edit to an accepted ADR,
   which ADR-0001 makes immutable and ADR-0008 allows only navigational addenda
   for; ADR-0015 was amended in place before (#313, #320) and the decision itself
   is unchanged, so amend rather than supersede, and put the ADR-0001/0008
   tension in the PR description for the owner. AGENTS.md
   rows for `cross_model_review.sh`, `_cli_review.sh`, `_agy_review.sh`: exit 5,
   positive-only `AGENT_KILL_AFTER`, group kill. Script-table rows do not need
   Ask-First. `.claude/skills/review-code/SKILL.md` (~L414-436, the only consumer that
   reads this script's exit codes; `run-issue` and `dispatch_phase.sh` never call
   it, checked by grep): document exit 4 (wrong worktree / invalid environment,
   not mentioned today) and exit 5 (another run holds the dir, nothing written;
   wait, do not start a second) next to exits 1 and 3 (finding S7).
6. **Live verification after P1b (finding S9).** Before the PR, run once
   `cross_model_review.sh --branch --agents gemini,codex --no-progress` against the
   real CLIs. Mocks cannot show two effects: setsid detaches each CLI from any
   controlling tty, and the post-exit group KILL removes anything a CLI
   deliberately left running (an agy or MCP helper daemon). Record what was
   observed (both reviews complete, no stray processes) in the PR description.

## Tests (`.agent/scripts/tests/test_cross_model_review.sh`)

Every "fails on old code" claim below is one the implementer verifies by running
the test against the pre-change script before committing the fix.

- **P1a:** flip the assertion at ~L3044-3051: `AGENT_KILL_AFTER=0` (with or without
  `REVIEW_KILL_ESCALATION=0`) now exits 2 with "must be greater than zero"; add a
  `0s` variant; keep the `KILL_AFTER=1 / ESCALATION=5` helper-refusal case. Direct
  helper calls to `_cli_review.sh` and `_agy_review.sh` must set
  `AGENT_KILL_AFTER=0 REVIEW_KILL_ESCALATION=0` (M2): with the default escalation
  of 5, 0 is refused today anyway, so only the both-zero case reaches the carve-out
  and exits 0 on today's code; after the change it must fail with the
  "must be greater than" message. Only L3050 uses a lone `AGENT_KILL_AFTER=0`.
- **Watchdog cancel (M1):** port the fork's `assert_watchdog_cancelled <label>
  <findings>` (`pgrep -f` on the per-test findings path, which the forked
  subshell keeps in its argv; 1 s settle, then kill and FAIL if still present) and
  a second check that no orphan watchdog `sleep` remains. Call it after a clean
  helper run for both `_cli_review.sh` and `_agy_review.sh` with
  `REVIEW_KILL_ESCALATION` well above the check delay. Fails on today's code.
- **P1b:** orphan-child mocks for codex and agy: a plain `( trap '' TERM HUP; ... ) &`
  inside the mock, no setsid or nohup-into-a-new-group, so the child stays in the
  CLI's process group (otherwise the test proves nothing); its pidfile is polled
  before the TERM. `CROSS_MODEL_ENV_PASSTHROUGH` is fork-only (it came with the
  codex env allowlist); our mocks inherit the environment, so there is no such
  step (S5). `test_local_helpers_kill_the_cli_process_group` asserts the child is
  gone after a helper TERM (codex, agy) and after a normal exit (codex).
  `assert_orphan_gone` kills a survivor so a failure does not leak, and treats a
  missing pidfile as FAIL only in these deterministic tests. Skips with a message
  when `setsid` is missing. **No-setsid fallback:** two parts. (1) Extract
  `signal_cli` with the suite's `sed -n` idiom and test both modes (group mode
  with a `setsid sleep`, PID mode with a plain `sleep`). (2) One full helper pass
  with `PATH` limited to a temp dir of symlinks to the tools the helper uses
  (listed in the test: bash, jq, mktemp, awk, sleep, pkill, tail, grep, cat, rm,
  head, sed, date, env) minus `setsid`, asserting the review completes and a TERM
  still exits 143. That also exercises the `set -u`-safe empty-array expansion.
- **P1c, deterministic adoption tests (M3).** The window is microseconds wide and
  cannot be hit by timing, so the staggered-TERM stress test is dropped; no timing
  test enters the per-commit suite (`validate-script-tests` runs it on every
  commit). Instead one test per adoption branch, using the suite's existing
  extraction idiom (`sed -n '/^name() {$/,/^}$/p'` as `test_job_finished_without_proc`
  does at ~L3807; a function whose handler is an inline `trap '...'` string is
  extracted by its line) so the REAL code runs, in a subshell with `set -u`:
  1. `_cli_review.sh` `terminate_child`: define `CLI_PID=""`, start
     `setsid sleep 30 &`, set `CLI_LAUNCH_PREV` to the `$!` value from before that
     launch and `CLI_LAUNCHING=true`, stub `exit`, call the handler, assert the
     sleep (and its group) is gone. Second case: `CLI_LAUNCHING=false` or `$!`
     equal to `CLI_LAUNCH_PREV` must NOT adopt (an unrelated background job is left
     running), which guards the stale-PID/double-signal failure.
  2. `_agy_review.sh` `terminate_child`: same two cases.
  3. `run_agent_job`'s TERM trap: the trap string is extracted and evaluated with
     `child=""`, `launch_prev` set and a fresh `sleep 30 &` as `$!`; assert it is
     killed and the trap exits 143; and no-adopt when `$!` did not move.
  4. `cleanup_jobs`: with `LAUNCHING_AGENT=codex`, `LAUNCH_PREV` stale, a live
     `sleep 30 &`, and `AGENT_PID` empty, assert the sleep is gone after
     `cleanup_jobs` (with `CLEANUP_REAP_SECONDS` small); and that an agent already
     in `AGENT_PID` is not overwritten.
  Each adoption test fails when the adoption `if` is removed (verified by
  deleting it locally). *Asserted:* the adoption logic and its guard conditions,
  plus that the existing TERM/interrupt/escalation tests pass, showing the flags
  reset after every launch. *Not asserted:* that bash actually delivers a TERM
  inside the real `&`-to-`$!` gap; that rests on the fork's field use and review,
  and the PR description says so.
- **P1d:** `test_local_concurrent_runs_refused`: hold the directory lock from a
  helper subshell (`exec 8< dir; flock -n 8; sleep`; killed and reaped in the test
  so the lock is released), run 2 exits 5, the message names the directory, run 1's
  findings are untouched. fd probe: a `MOCK_CODEX_FD9_PROBE` mock records whether
  fd 9 is open, tested with `[[ -e /dev/fd/9 ]]` rather than a write to it (the
  directory fd is read-only); asserted `closed`; fails without `9>&-`. A pair of `--no-progress` runs does not contend. Skip when
  `flock` is absent. If the lock-file fallback is implemented, one test forces it.
- New tests go in the existing file, so no new exec bit is needed. Run the full
  script suite (~2-3 min) and shellcheck via pre-commit.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/cross_model_review.sh` | P1a validation + comments; P1c launch-window vars; P1d lock + `9>&-`; header exit 5 |
| `.agent/scripts/_cli_review.sh` | P1a drop carve-out; P1b setsid/group signalling; P1c adoption |
| `.agent/scripts/_agy_review.sh` | same three as `_cli_review.sh` |
| `.agent/scripts/tests/test_cross_model_review.sh` | tests above; mocks; env passthrough |
| `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md` | amend knob text; lifecycle bullet; Status-line amendment note |
| `AGENTS.md` | three script-table rows (exit 5, group kill, positive grace) |
| `.claude/skills/review-code/SKILL.md` | document exits 4 and 5 |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Each fix is code plus a test; docs follow the code |
| Test what you change | Every test must fail on the old code; P1c is tested deterministically via the real functions, with the one untestable gap stated |
| Improve incrementally | Scope cut to P1a-P1d; P1e-P1g in #369; one commit per item, atomic |
| Only what's needed | Lock and `9>&-` land together; no kill_tree port |
| Workspace project-agnostic | No project references |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0015 | Yes | Knob text edited, lifecycle bullet added, Status-line amendment note (#320 precedent) |
| 0001 / 0008 | Yes | Accepted ADRs are immutable / navigational-only addenda; substantive in-place amendment has precedent (#313, #320); decision unchanged; tension raised in the PR description |
| 0013 | No | `progress.md` writers untouched; the lock file is a gitignored sibling |
| 0011 / others | No | - |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Exit codes of `cross_model_review.sh` | header list, AGENTS.md row, review-code SKILL result reading | Yes |
| `AGENT_KILL_AFTER` legal range | ADR-0015, script comments, L3044 test | Yes |
| Helpers' launch shape | #344 (Copilot drop) touches `_cli_review.sh` | Follow-up rebase, owner ordered #363 first |
| Callers reading exit codes | review-code SKILL is the only one (grep: `run-issue`, `dispatch_phase.sh` never call the script) | Yes: exits 4 and 5 documented |
| Lock on the work-plans directory itself | no file, so no `.gitignore` or project-repo footprint | Yes |
| Untracked `kill_tree` gap | PR description note | Yes (flagged, nothing filed) |

## Open Questions

- None blocking. Assumption: amending ADR-0015 in place (not superseding) is acceptable; the PR description will raise the ADR-0001/0008 tension.
- FYI: the fork's `kill_tree` fix is not tracked in any open issue here.

## Estimated Scope

Single PR, about six atomic commits (P1a, watchdog cancel + P1b, P1c, P1d, docs; the live run is a verification step, not a commit). Roughly 150 lines of script and 300 of tests.
