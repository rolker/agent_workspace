# Plan: cross_model_review.sh: reconsider tmux-default; sync should be parallel

## Issue

https://github.com/rolker/agent_workspace/issues/206

## Context

`cross_model_review.sh` currently dispatches **one agent per invocation**,
defaulting to a background tmux session (auto-falls back to sync only when
tmux is unavailable). `review-code` step 5e calls the script three times in
sequence to cover gemini/codex/copilot, so sandboxed callers (Claude Code,
CI — where tmux is unavailable) lose parallelism, not just the tmux session.
Owner checkpoint (2026-09-22) approved proceeding with four hard
requirements: a new ADR recording the reversal, rewriting the skill's
dispatch step in the same PR, explicit parallel-failure-mode tests, and
keeping the Copilot `-p`/`--allow-all-tools` fix out of scope (tracked as
#212).

PR #311 (merged today) added `.agent/scripts/_agy_review.sh`, which owns the
gemini findings file end-to-end (truncates it, writes result-or-failure-reason,
the caller only appends the `--- Review complete/failed ---` marker) — this
contract is unaffected by the change below and must stay intact.

## Approach

1. **New ADR** `docs/decisions/0015-parallel-sync-is-the-default-review-dispatch-mode.md`
   recording: tmux was chosen for interactivity (#2, #65, #66) but reviews
   run headless now; tmux sessions leak past the review; the tmux path
   requires building one quoted shell-command string (`build_invoke_cmd`),
   adding quoting-correctness risk that a plain array-based sync dispatch
   avoids; and sandboxed callers (no tmux) were silently downgraded to
   *sequential* sync, losing parallelism entirely. Decision: parallel `&`+
   `wait` sync dispatch becomes the default; tmux moves behind an explicit
   `--tmux` opt-in (see recommendation below) instead of being
   auto-detected. Considered-alternatives section covers gstack's
   `benchmark-models` `Promise.allSettled`/typed-adapter pattern — rejected
   because it requires a bun/node runtime the workspace doesn't otherwise
   depend on, and stays a reference, not scope.

2. **`cross_model_review.sh`: add multi-agent dispatch.**
   - Add `--agents a,b,c` (comma-separated, validated against
     `AGENT_BINS` keys same as `--agent`). Mutually exclusive with
     `--agent` (both given → exit 2, matching the existing `--pr`/`--branch`
     mutual-exclusion pattern).
   - Internally normalize both flags to one `AGENTS_TO_RUN` array — `--agent`
     produces a 1-element array, `--agents` splits on comma. The rest of the
     script (prompt building, dispatch, output) is one loop over this array
     instead of a single `$TARGET_AGENT`.
   - **Shared diff fetch.** Fetch the PR/branch diff once (existing
     `gh pr diff`/`git diff` + `filter_work_plans_diff` code), not once per
     agent — avoids N redundant `gh`/`git` calls and N copies of a
     potentially large diff. Each agent's prompt file gets the shared
     header + shared diff + its own agent-specific footer (only gemini gets
     the "do not run shell commands" paragraph, per existing logic).
   - `--sync` stays accepted for backward compatibility (many existing
     tests and the branch-mode skill examples pass it) but becomes a
     documented no-op: sync is now the unconditional default. Emit no
     warning — treating it as a no-op is simpler than deprecation
     machinery for a flag that still describes real (now default)
     behavior accurately.
   - Remove the `command -v tmux` auto-detect fallback. tmux only runs when
     `--tmux` is passed explicitly; `--tmux` is compatible with both
     `--agent` and `--agents` (loops the existing per-agent tmux
     new-session code once per agent, one session per agent named
     `review-<agent>-<issue>` as today).

3. **Parallel sync dispatch (the default path).** For each agent in
   `AGENTS_TO_RUN`: launch `run_agent_sync` in a background subshell,
   collecting `$!` into a `pids` array keyed by agent name. After launching
   all agents, loop over `pids` and call `wait "$pid"` per agent (not
   `wait -n`) — `wait PID` returns that job's own exit status directly, so
   no separate `.exit`-file bookkeeping is needed; the PID→agent array
   already gives the caller everything a poll of on-disk exit files would.
   **Pitfall to flag for the implementer:** the script runs under
   `set -euo pipefail`; `wait "$pid"` on a failed job will trigger `set -e`
   and abort the loop before later agents are waited on unless captured as
   `wait "$pid" || rc=$?`. This is exactly the failure mode requirement 3
   below tests for.
   - Per agent, after `wait` returns: append `--- Review complete ---` or
     `--- Review failed ---` to that agent's own findings file based on its
     own exit code — independent per agent, not derived from any other
     agent's outcome or from an aggregate status.
   - Single-agent invocations (`--agent`, no `--agents`) are the N=1 case of
     the same loop and keep today's exact stdout shape (`MODE=sync`,
     `AGENT=`, `FINDINGS_FILE=`) — no output-format change for existing
     single-agent callers.

4. **New output shape for `--agents` runs.** Print `MODE=parallel-sync` once,
   then repeat one `AGENT=`/`FINDINGS_FILE=`/`EXIT=` triplet per agent (exit
   code as the literal agent exit status, `0` success). Example:
   ```
   MODE=parallel-sync
   AGENT=gemini
   FINDINGS_FILE=.../review-gemini-findings.md
   EXIT=0
   AGENT=codex
   FINDINGS_FILE=.../review-codex-findings.md
   EXIT=1
   AGENT=copilot
   FINDINGS_FILE=.../review-copilot-findings.md
   EXIT=0
   ```
   Script's own exit code: `0` if every agent succeeded, `3` if at least one
   agent's sync run failed (mirrors the existing single-agent "sync failure
   → exit 3" contract) — the per-agent `EXIT=` lines are what let a caller
   tell *which* agent(s) failed instead of just "something failed."

5. **Rewrite `.claude/skills/review-code/SKILL.md` step 5e** in the same PR:
   replace the three sequential `--agent gemini`/`--agent codex`/
   `--agent copilot` invocations with one `--agents gemini,codex,copilot`
   call (PR mode and branch mode variants). Update the "collecting findings"
   guidance: today's text says "if the script exits non-zero for one agent,
   note it and continue" — that assumed one script call per agent. Rewrite
   it to say the skill parses every `AGENT=`/`FINDINGS_FILE=`/`EXIT=`
   triplet from stdout regardless of the script's own overall exit code,
   since one call now covers several agents and the top-level exit code
   alone can't distinguish "all failed" from "one failed." Update the
   auto-detect paragraph ("script auto-detects tmux vs sync") to describe
   the new default (always parallel sync) and `--tmux` as explicit opt-in
   for live-observe via `tmux attach` (mention `tail -f` on the findings
   file as the non-tmux equivalent).

6. **Update the script's own header comment** (usage block, lines ~21-46) to
   document `--agents`, the parallel-sync default, `--tmux` opt-in, and the
   new multi-agent stdout shape.

## Files to Change

| File | Change |
|------|--------|
| `docs/decisions/0015-parallel-sync-is-the-default-review-dispatch-mode.md` | New ADR recording the tmux-default reversal |
| `.agent/scripts/cross_model_review.sh` | Add `--agents`, loop dispatch over an agent array, parallel `&`+`wait` sync as default, remove tmux auto-detect, add `--tmux` opt-in, shared diff fetch, new multi-agent stdout shape, rewritten header comment |
| `.claude/skills/review-code/SKILL.md` | Step 5e: single `--agents` invocation, updated findings-parsing guidance, updated mode description |
| `.agent/scripts/tests/test_cross_model_review.sh` | New tests (below) + adjust `test_agy_tmux_invocation` to pass `--tmux` explicitly (auto-detect fallback is gone) |

### New/changed tests in `test_cross_model_review.sh`

- `test_agents_flag_all_succeed` — baseline: `--agents gemini,codex` with
  both mocks exiting 0; asserts `MODE=parallel-sync`, both `AGENT=`/
  `FINDINGS_FILE=`/`EXIT=0` triplets present, both findings files carry
  `--- Review complete ---`, script exits 0.
- `test_agents_flag_partial_failure` — one mock agent CLI exits 1, the
  other exits 0; asserts the failing agent's findings file gets
  `--- Review failed ---` and the succeeding agent's gets
  `--- Review complete ---` (markers stay independent), both `EXIT=` lines
  are correct, and the script's own exit code is 3 (per requirement 4)
  while both findings files are still fully written (not short-circuited
  by the first failure — this is what catches the `set -e`/`wait` pitfall
  from step 3 if the implementation gets it wrong).
- `test_agents_flag_one_times_out` — one mock agent sleeps past a short
  injected timeout (or simulates the agy-timeout contract non-zero exit)
  while the other completes normally; asserts the timed-out agent's
  findings/marker reflect failure, the other agent's findings/marker are
  unaffected and not delayed by the slow one, and the script doesn't hang
  (test has its own timeout guard).
- `test_agents_and_agent_mutually_exclusive` — `--agent gemini --agents
  gemini,codex` exits 2 with a clear error.
- `test_agents_flag_rejects_unknown_agent` — `--agents gemini,bogus` exits
  2 (reuses the existing unknown-agent validation, applied per list entry).
- `test_tmux_requires_explicit_flag` — adjust/rename
  `test_agy_tmux_invocation`: with a working mock `tmux` on `PATH` and
  **no** `--tmux` passed, the script still runs sync (auto-detect fallback
  removed); a second assertion (or a sibling test) confirms `--tmux`
  explicitly still launches the tmux session with the existing quoted
  command-string behavior intact.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Skill step 5e rewritten in the same PR (requirement 2); script's own usage header updated so it doesn't go stale. |
| Capture decisions, not just implementations | New ADR-0015 records the reversal and rationale before implementation lands, per ADR-0001. |
| Only what's needed | gstack's bun/node adapter pattern stays out of scope, referenced only in the ADR's considered-alternatives; `--sync` kept as a no-op instead of adding deprecation machinery. |
| Test what breaks | Explicit partial-failure and timeout tests for the new background-job path (requirement 3), plus mutual-exclusion/validation tests for the new flags. |
| Improve incrementally | Single-agent `--agent` callers keep today's exact output contract — no forced migration for existing scripts/tests beyond the tmux auto-detect removal. |
| Workspace improvements cascade to projects | Downstream `rolker/ros2_agent_workspace#461` (Copilot-only port) can adopt the same `--agents` shape once this lands; not blocking this PR. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0001 — Adopt ADRs | Yes | New ADR-0015 for this reversal. |
| 0008 — Cross-reference addendums | No (new decision, not an edit to an existing accepted ADR) | N/A |
| 0013 — progress.md entry-type vocabulary | Yes (process) | Standard `review_progress.sh persist` calls through the review loop; no content changes needed. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `cross_model_review.sh` dispatch shape | `.claude/skills/review-code/SKILL.md` step 5e | Yes |
| Script's stdout contract | Any other consumer parsing `MODE=`/`AGENT=`/`FINDINGS_FILE=` | Checked — `review-code` is the only in-repo consumer found; downstream `ros2_agent_workspace#461` is out of scope/not blocking |
| tmux auto-detect removed | Existing `test_agy_tmux_invocation` | Yes — adjusted to pass `--tmux` explicitly |
| `.agent/knowledge/` digests mentioning tmux dispatch | — | No — historical notes, not living docs (per issue review) |

## Open Questions

- **tmux: keep behind `--tmux` or remove entirely?** Recommendation: **keep
  behind an explicit `--tmux` flag**, not remove. The issue's own proposal
  frames it this way, live-observe via `tmux attach` has a real (if now
  secondary) use case for a stuck long-running agent, and gating behind an
  explicit flag already satisfies the actual complaint (silent
  auto-detect downgrading sandboxed/parallel callers to sequential sync).
  Full removal would also force reworking `test_agy_tmux_invocation`'s
  quoted-command-string coverage rather than just adjusting its
  invocation, for no behavior-correctness gain. If the owner would rather
  delete tmux support outright, that's a small follow-up scope change to
  flag at `review-plan`.
- Exact multi-agent aggregate exit-code contract (script exits 3 if any
  agent fails) is a judgment call, not dictated by the issue — confirm at
  `review-plan` that "any failure → exit 3, but all findings files/markers
  still fully written" is the right contract versus, say, always exiting 0
  and pushing all failure signaling into the per-agent `EXIT=` lines.

## Estimated Scope

Single PR.
