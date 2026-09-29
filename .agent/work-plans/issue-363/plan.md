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

The fork's kill_tree/pgrep pieces do not exist here (our `cleanup_jobs` only
signals job PIDs); this plan does not add them.

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
   group id. `terminate_child`: TERM the group, watchdog kills the group, then
   after `wait` poll the group for `ESCALATION_SECONDS*10` ticks and SIGKILL it,
   then `pkill -KILL -P "$watchdog"` before killing the watchdog (fork 69a6907).
   After a normal `wait`, sweep the group with KILL. Both sweeps run in group mode
   only (fork 5818535): a bare reaped PID may be reused, so the no-setsid fallback
   keeps today's PID-only TERM/watchdog behaviour and nothing more.
3. **P1c: close the launch window** (fork 5818535). Helpers: `CLI_LAUNCHING`,
   `CLI_LAUNCH_PREV="${!:-}"` set before the `&`, `CLI_LAUNCHING=false` after
   `CLI_PID=$!`; the top of `terminate_child` adopts `$!` when `CLI_PID` is empty,
   launching is true and `$!` differs from the recorded previous value. Same for
   `AGY_PID`. `run_agent_job`: `launch_prev` local and the TERM trap adopts `$!`
   into `child`. Parent: `LAUNCHING_AGENT`/`LAUNCH_PREV` globals, adopted in
   `cleanup_jobs` when `AGENT_PID[$LAUNCHING_AGENT]` is unset.
4. **P1d: one run per issue dir.** After `mkdir -p "$WORK_PLANS_DIR"` (~L673) and
   before any prompt/findings write: `exec 9>> "$WORK_PLANS_DIR/.cross-model-review.lock"`
   (open failure -> exit 4), `flock -n 9 || exit 5` with a message naming the dir.
   No `flock` on the host (macOS): warn on stderr and proceed unserialized, as the
   fork does. `--no-progress` uses a fresh mktemp dir, so it never contends. Launch
   the jobs `run_agent_job "$agent" 9>&- &` so nothing a job leaves behind holds the
   lock. Add `.agent/work-plans/*/.cross-model-review.lock` to `.gitignore`.
5. **Docs (same PR).** Script header exit-code list: add `5`. ADR-0015 (~L105-108):
   drop the "`AGENT_KILL_AFTER=0` is excepted" clause; add a short bullet on
   process-group kill, the launch-window adoption and the per-dir lock (ADR edit is
   an amendment of the same decision, not a new ADR; note it in the PR). AGENTS.md
   rows for `cross_model_review.sh`, `_cli_review.sh`, `_agy_review.sh`: exit 5,
   positive-only `AGENT_KILL_AFTER`, group kill. Script-table rows do not need
   Ask-First. `.claude/skills/review-code/SKILL.md` (~L428-436): one sentence that
   exit 5 means another run holds the dir and nothing was written.

## Tests (`.agent/scripts/tests/test_cross_model_review.sh`)

- **P1a:** flip the assertion at ~L3044-3051: `AGENT_KILL_AFTER=0` (with or without
  `REVIEW_KILL_ESCALATION=0`) now exits 2 with "must be greater than zero"; add
  `0s` variant; keep the `KILL_AFTER=1 / ESCALATION=5` helper-refusal case; add a
  direct helper call with `AGENT_KILL_AFTER=0` for `_cli_review.sh` and `_agy_review.sh`
  (usage/config failure). Sweep other tests for a lone `AGENT_KILL_AFTER=0` (only
  L3050 today).
- **P1b:** add `MOCK_CODEX_ORPHAN_PIDFILE` / `MOCK_AGY_ORPHAN_PIDFILE` to the mocks
  and to `CROSS_MODEL_ENV_PASSTHROUGH` (a TERM-ignoring child detached from the
  caller's fds); `test_local_helpers_kill_the_cli_process_group` asserts the child
  is gone after a helper TERM (codex, agy) and after a normal exit (codex).
  `assert_orphan_gone` kills a survivor so a failure does not leak. Skips with a
  message when `setsid` is missing; add a **fallback test** that runs the helper
  with `setsid` hidden (PATH shim dir without it) and asserts the review still
  completes and the TERM path still exits 143 (no group assertions).
- **P1c: what is and is not covered.** The window is a few instructions wide and
  cannot be hit deterministically, and the fork says the same. *Asserted:* (a) all
  existing TERM/interrupt/escalation tests still pass, proving the launch flags are
  reset after every launch so the adoption branch never fires on an already-recorded
  PID (a mis-reset would double-signal or signal a stale PID); (b) a bounded
  stress test sends TERM to a helper at staggered 0-150 ms delays (8 runs) with
  the orphan-child mock and asserts no child survives and the exit is 143. It can
  only fail if the adoption is broken, never on a correct implementation, but it
  will not catch every regression. *Not asserted:* that a TERM inside the exact
  window is adopted; that is covered by code review and the fork's field use.
  The PR description says so.
- **P1d:** `test_local_concurrent_runs_refused` (a `flock ... sleep` holder stands in
  for run 1; run 2 exits 5, message names the dir, run 1's findings untouched;
  `pkill -P` the holder's sleep so the lock is released); fd probe: a
  `MOCK_CODEX_FD9_PROBE` mock records whether fd 9 is open, asserted `closed`
  (fails without `9>&-`); a `--no-progress` pair of runs does not contend. Skip
  when `flock` is absent. New tests go in the existing file, so no new exec bit.
- Run `make test` / the script suite (~2-3 min) plus shellcheck via pre-commit.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/cross_model_review.sh` | P1a validation + comments; P1c launch-window vars; P1d lock + `9>&-`; header exit 5 |
| `.agent/scripts/_cli_review.sh` | P1a drop carve-out; P1b setsid/group signalling; P1c adoption |
| `.agent/scripts/_agy_review.sh` | same three as `_cli_review.sh` |
| `.agent/scripts/tests/test_cross_model_review.sh` | tests above; mocks; env passthrough |
| `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md` | amend knob text; lifecycle bullet |
| `AGENTS.md` | three script-table rows (exit 5, group kill, positive grace) |
| `.claude/skills/review-code/SKILL.md` | exit 5 reading |
| `.gitignore` | lock file |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Each fix is code plus a test; docs follow the code |
| Test what you change | P1a/b/d deterministic; P1c limits stated explicitly above |
| Improve incrementally | Scope cut to P1a-P1d; P1e-P1g in #369; one commit per item, atomic |
| Only what's needed | Lock and `9>&-` land together; no kill_tree port |
| Workspace project-agnostic | No project references |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0015 | Yes | Section on knobs edited (zero exception removed); lifecycle bullet added; same decision, amended in place |
| 0013 | No | `progress.md` writers untouched; the lock file is a gitignored sibling |
| 0011 / others | No | - |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Exit codes of `cross_model_review.sh` | header list, AGENTS.md row, review-code SKILL result reading | Yes |
| `AGENT_KILL_AFTER` legal range | ADR-0015, script comments, L3044 test | Yes |
| Helpers' launch shape | #344 (Copilot drop) touches `_cli_review.sh` | Follow-up rebase, owner ordered #363 first |
| Callers treating any non-0/1/3 exit as generic | `run-issue` / review-code exit handling | Check during implementation: grep callers for exit-code switches; add 5 if any enumerate codes |
| Lock file in work-plans dir | `.gitignore` | Yes |

## Open Questions

- None blocking. Assumption: amending ADR-0015 text in place (not superseding) is
  acceptable, since the decision itself is unchanged.

## Estimated Scope

Single PR, about five atomic commits (P1a, P1b, P1c, P1d, docs). Roughly 150 lines of script and 200 of tests.
