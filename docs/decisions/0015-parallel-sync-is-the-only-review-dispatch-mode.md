# ADR-0015: Parallel Synchronous Dispatch Is the Only Cross-Model Review Mode

## Status

Accepted.

## Context

`cross_model_review.sh` dispatches external CLI reviewers (Gemini via
`agy`, Codex, Claude, Copilot) for the `review-code` skill's Deep tier. From
its first version (issues #2, #65, #66) it ran each agent in a detached
tmux session by default, with a sequential `--sync` mode added for
sandboxed environments (#106). The tmux default was chosen for
interactivity: a reviewing agent could ask the user questions mid-review
and the user could attach to answer.

That reason no longer holds, and the default carried costs that were not
paying for themselves (issue #206):

- Reviews run headless. No dispatched reviewer asks questions any more;
  Gemini's headless mode auto-denies interactive tools outright (#288).
- Sessions outlived the review and accumulated unless killed by hand.
- The agent invocation had to be flattened into one quoted shell string
  for `tmux new-session`. That path had no test coverage at all until
  #311, and its quoting was the one place a reviewer command could break
  silently.
- The fallback inverted the goal: where tmux was unavailable (Claude Code
  sessions, CI), the script silently downgraded to *sequential* sync runs.
  The callers that most needed overlap were the ones that lost it.
- `review-code` invoked the script once per agent, so even with tmux the
  parallelism lived in the skill's call pattern, not in the script.

The issue also pointed at `garrytan/gstack`'s `benchmark-models`, which
fans the same prompt out to several CLIs with `Promise.allSettled` and
returns typed per-provider results.

## Decision

1. **The tmux path is removed entirely.** No `--tmux` flag, no
   auto-detection, no session names in the output. `--sync` is rejected
   as a removed argument (exit 2) rather than kept as a no-op: with no
   other mode to opt out of it documents a choice that no longer exists.
2. **Every agent runs synchronously in its own background job, all
   selected agents in parallel**, and the script blocks until the last
   finishes. `--agents a,b,c` selects several agents in one invocation;
   `--agent X` (single-agent) keeps its previous stdout contract exactly.
3. **Each agent is bounded.** Codex, Claude and Copilot run under
   `timeout "$AGENT_TIMEOUT"` (seconds, env-overridable, default 1800);
   Gemini keeps `_agy_review.sh`'s own `--print-timeout`, because an outer
   SIGTERM would race that helper's timeout-then-partial-response
   handling (#288). A hung reviewer can no longer hang the call.
4. **Failure is per agent.** Each job appends its own
   `--- Review complete ---` / `--- Review failed ---` marker the moment it
   finishes, so a slow agent never delays a fast agent's marker. A missing
   CLI fails only that agent. The `--agents` output prints one
   `AGENT=` / `FINDINGS_FILE=` / `EXIT=` triplet per agent; the script exits
   3 when any agent failed, and exit 3 with no triplets means the shared
   prompt could not be built (every selected findings file then carries a
   `--- Review error: ... ---` marker).
5. **Live observation is `tail -f <findings-file>`**, which the parallel
   model supports without a session.

## Considered alternatives

- **Keep tmux behind an explicit `--tmux` flag.** Rejected by the owner.
  Its one remaining property, non-blocking dispatch, is not something the
  review loop uses: `review-code` waits for the findings anyway. Keeping
  the path would have kept the quoted-command-string risk and its test
  for no consumer.
- **gstack's `Promise.allSettled` adapter pattern** (typed per-provider
  results, `{output, tokens, durationMs, error: {code}}`). The shape is
  the model for the per-agent triplets here, but it needs a bun or node
  runtime. The workspace scripts are bash-only; a background job per
  agent plus `wait` gives the same fan-out without a new runtime. Kept as
  a reference, not adopted.
- **Sequential sync as the default.** Simplest, but it is exactly the
  degraded mode sandboxed callers were stuck in; Deep-tier reviews would
  take three times as long everywhere.

## Consequences

- `review-code` dispatches all cross-model reviewers in one
  `--agents gemini,codex,copilot` call and reads each agent's `EXIT=` line
  rather than the script's overall exit status.
- `.agent/knowledge/agent_wait_patterns.md` no longer names a tmux
  session poll as a wait pattern; the bounded parallel `wait` plus
  per-agent timeout replaces it.
- The mock-tmux test from #311 is retired; the suite gains parallel
  dispatch tests (partial failure, timeout, missing CLI, concurrency
  overlap, argument hygiene).
- Sessions or scripts that still pass `--sync` fail loudly with a message
  naming the removal; the fix is to drop the flag.
- The per-agent result validation that Gemini has (#288) is still
  missing for Codex, Claude and Copilot; that is #313, unchanged by this
  decision.

## References

- Issue #206 (this decision), #106 (`--sync` origin), #2/#65/#66 (tmux
  origin), #311/#288 (Gemini helper and its timeout contract), #313.
- `.agent/scripts/cross_model_review.sh`, `.agent/scripts/_agy_review.sh`,
  `.claude/skills/review-code/SKILL.md`.
