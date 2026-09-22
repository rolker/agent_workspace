# Plan: cross_model_review.sh: reconsider tmux-default; sync should be parallel

## Issue

https://github.com/rolker/agent_workspace/issues/206

## Context

`cross_model_review.sh` dispatches one agent per invocation, defaulting to a
tmux session (auto-falls back to *sequential* sync when tmux is unavailable).
`review-code` step 5e calls it three times in sequence, so sandboxed callers
(Claude Code, CI) lose parallelism.

Round-1 plan review (needs-work) found the first draft's parallel-sync path
unsafe: no timeout for non-gemini agents, single-agent binary resolution that
would abort a multi-agent run over one missing CLI, and a marker-placement
bug contradicting its own timeout test. The owner's checkpoint decided the
open tmux question: **remove tmux entirely**, no `--tmux` flag — reviews run
headless, parallel sync gives the observability tmux provided, dropping
`build_invoke_cmd` removes the quoted-command-string risk. This revision
folds in all ten round-1 findings and removes tmux per that decision.

`_agy_review.sh` (PR #311) still owns the gemini findings file and its own
`--print-timeout` (`AGY_PRINT_TIMEOUT="30m"`), unaffected here; gemini stays
exempt from the new outer per-agent timeout (item 3).

## Approach

1. **ADR** `docs/decisions/0015-parallel-sync-is-the-default-review-dispatch-mode.md`:
   tmux was for interactivity (#2/#65/#66) but reviews run headless now,
   sessions leaked, `build_invoke_cmd` risked quoting bugs. Decision: remove
   tmux outright — no flag, no fallback. Considered alternatives: keep tmux
   behind a flag (rejected — timeout + `tail -f` cover the remaining need);
   gstack's `Promise.allSettled` adapter pattern (rejected — needs a
   bun/node runtime, reference only).

2. **Remove tmux, add `--agents`.** Delete `build_invoke_cmd`, the
   `tmux new-session`/`has-session` block, `command -v tmux` auto-detect,
   `TMUX_SESSION=` output, and the `USE_SYNC`/`FORCE_SYNC` branch — sync is
   the only path. **Remove `--sync`** (not a no-op — with no tmux mode to
   disambiguate from, it documents a choice that no longer exists);
   `--sync` now exits 2 as an unknown argument. Add `--agents a,b,c`,
   mutually exclusive with `--agent` (both → exit 2). Normalize both flags
   to one `AGENTS_TO_RUN` array; the rest of the script loops over it.
   **Shared diff fetch** once, not per agent; each prompt gets the shared
   header/diff + its own agent-specific footer. **Hygiene** (before any
   dependency check or dispatch): trim, lowercase, reject empty
   entries/stray commas (exit 2), collapse exact duplicates (dedupe
   silently — avoids two jobs colliding on one filename), reject unknown
   agents (exit 2, reusing existing validation).

3. **Per-agent timeout.** Wrap codex/claude/copilot's `run_agent_sync` in
   `timeout -k "$AGENT_KILL_AFTER" "$AGENT_TIMEOUT"` (default `1800` = 30m,
   matching `AGY_PRINT_TIMEOUT`; kill-after 10s so a CLI ignoring SIGTERM
   cannot outlive the bound; both env-overridable so tests inject small
   values).
   Timeout exit (124) counts as that agent's failure. Gemini is exempt —
   `_agy_review.sh`'s own `--print-timeout` already bounds it and an
   external SIGTERM would race its timeout-then-partial-response contract
   (#288).

4. **Per-agent binary resolution.** Move binary lookup into a per-agent
   function called before dispatch. A missing CLI (or missing
   `_agy_review.sh` for gemini) does not abort the run: write `---
   Review failed ---` plus the reason into that agent's findings file,
   skip launching it, continue with the others. Exit 1 only when *no*
   selected agent has a resolvable binary — a dependency error like a
   missing `gh`: nothing written, no triplets, each agent named on
   stderr (distinct from exit 3 by the exit code itself).

5. **Parallel dispatch.** Each agent runs in a background subshell that
   itself appends `--- Review complete/failed ---` to its own findings
   file based on its own exit status immediately after the run — markers
   live inside the job, not written by the parent after `wait`, so a slow
   agent never delays a fast agent's marker. Parent collects `$!` per
   agent into a `pids` array, then loops `wait "$pid" || rc=$?` per agent
   (script runs under `set -euo pipefail`; an uncaptured `wait` on a
   failed job would abort the loop before later agents are collected),
   unsetting each PID once reaped. Background jobs write nothing to
   stdout. **Interrupt safety**: the parent traps INT/TERM/HUP and its
   EXIT cleanup kills every job still running; each job arms its own
   TERM trap *before* spawning its CLI as a waited-on child (`exec` in
   `run_agent_sync` makes the child PID the CLI's), and `_agy_review.sh`
   does the same for agy — so an abandoned run leaves no CLI burning
   quota. **Live observation**: multi-agent mode prints each findings
   path before launching (for `tail -f`); the triplets follow after
   collection, and callers parse by prefix, not position.

6. **Shared-diff failure path.** If the diff fetch fails or is empty,
   write the existing `--- Review error: ... ---` marker into *every*
   selected agent's findings file (truncating), print no `AGENT=`
   triplets, exit 3.

7. **Output/exit contract.** `--agent X` keeps today's exact `MODE=sync`
   block (no `EXIT=`). `--agents X[,...]` (including one entry) →
   `MODE=parallel-sync` once, then one `AGENT=`/`FINDINGS_FILE=`/`EXIT=`
   triplet per agent. Script exit: `0` all succeeded, `3` if any agent
   failed (missing binary, timeout, or nonzero exit). Disambiguator: exit
   3 with no `AGENT=` triplets = setup/shared-diff failure (item 6); exit
   3 with triplets = per-agent failures, read `EXIT=`. State this in the
   header and the skill.

8. **Rewrite `.claude/skills/review-code/SKILL.md` step 5d/5e**: one
   `--agents gemini,codex,copilot` call instead of three sequential
   `--agent` calls (PR and branch mode). Findings-parsing keyed on
   `EXIT=` per triplet, not the script's top-level exit code; state the
   exit-3 disambiguator; remove tmux-attach guidance, note `tail -f
   <findings-file>` for live observation.

## Files to Change

| File | Change |
|------|--------|
| `docs/decisions/0015-...md` | New ADR: tmux removal + rationale; gstack under considered alternatives |
| `.agent/scripts/cross_model_review.sh` | `--agents`, per-agent timeout + binary resolution, parallel dispatch with in-job markers, remove `build_invoke_cmd`/tmux/`--sync`, N-agent shared-diff error path, new stdout shape, rewritten header |
| `.agent/scripts/tests/test_cross_model_review.sh` | Retire `test_agy_tmux_invocation`; add tests below |
| `.claude/skills/review-code/SKILL.md` | Step 5d/5e per item 8 |
| `.agent/knowledge/agent_wait_patterns.md` | Line 63 row + "See also" (72-74) name tmux polling as the wait pattern — replace with bounded parallel `wait` + per-agent timeout; `tail -f` for live observation |
| `AGENTS.md` | `cross_model_review.sh` script-table row: add `--agents`; verify no stale tmux phrasing |

`.agent/knowledge/review_depth_classification.md` checked — no tmux mention, no change needed.

### Tests (`test_cross_model_review.sh`)

Add mock `codex`/`copilot`/`claude` binaries (suite currently only mocks
`agy`/`gh`/`git`; drop the `tmux` mock). New/changed cases: all-succeed
baseline; partial failure (both findings files fully written, exit 3); one
agent times out (`AGENT_TIMEOUT=1`, mock sleeps 5s) while the fast agent's
marker isn't delayed; wall-clock concurrency (three mocks sleeping `N`s
finish in well under `3N`); missing binary for one agent doesn't abort the
others; `--agent`/`--agents` mutual exclusion; unknown/empty/stray-comma
entries rejected; duplicate agent dedupes to one run; shared-diff failure
writes the error marker into every selected findings file with no triplets
(exit 3); `--sync` now rejected as unknown argument; retire
`test_agy_tmux_invocation`.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Consequences / cascades | Skill 5d/5e, `agent_wait_patterns.md`, `AGENTS.md` row updated here; `ros2_agent_workspace#461` can adopt `--agents` once landed, not blocking. |
| Capture decisions | ADR-0015 records the removal before implementation, per ADR-0001. |
| Only what's needed | gstack pattern stays reference-only in the ADR. |
| Test what breaks | Timeout, binary-failure, marker-independence, N-agent shared-diff failure, hygiene, true concurrency all tested. |
| Improve incrementally | `--agent` callers keep today's exact output; `--sync` removal is the only breaking change and has no meaning post-tmux. |

## ADR Compliance

0001 (Adopt ADRs) — Yes, new ADR-0015. 0008 (cross-reference addendums) —
No, this is a new decision, not an edit to an accepted ADR. 0013
(progress.md vocabulary) — Yes/process, standard `review_progress.sh
persist` calls.

## Consequences

Dispatch-shape change → `review-code` SKILL.md 5d/5e (included). Stdout
contract → checked for other consumers; only `review-code` parses it,
`ros2_agent_workspace#461` out of scope/not blocking. tmux removal →
`test_agy_tmux_invocation` retired, `agent_wait_patterns.md` and the script
header updated (included). `--sync` removal → tests/skill examples updated
here (included).

## Open Questions

None — the owner's checkpoint resolved the round-1 open question (remove
tmux entirely); this revision folds in all ten round-1 findings.

## Estimated Scope

Single PR.

## Implementation Notes

- Three live parallel runs (Gemini + Codex) of this branch through the
  new path drove the last two commits: Gemini found the orphaned-jobs
  interrupt gap, the withheld findings paths and the missing kill-after;
  Codex found the trap-after-spawn launch-window race (in the job and in
  `_agy_review.sh`) and the stale-PID cleanup. Both flagged the exit-1
  contract mismatch independently; resolved by documenting exit 1 as a
  no-artifact dependency error (Approach item 4) rather than writing
  markers before the artifact dir exists.
- On the third run Gemini itself failed (agy: output token limit
  exceeded) and the helper reported it as a failed review with the
  reason — the #288 validation working as intended, not a defect here.
- Codex's findings file echoes the whole prompt and its tool transcript
  before the answer (93 KB for a 79 KB prompt). `codex exec` has
  `--output-last-message <file>`; noted on #313, out of scope here.
- Concurrency test asserts interval overlap first and wall clock only as
  a loose secondary (round-2 plan review); the interrupt test sends
  SIGTERM because bash ignores SIGINT in background children of a
  non-interactive shell, so a test-sent INT never arrives.
