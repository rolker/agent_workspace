# Agent Wait Patterns

How agent flows should wait for external events (CI completion, tmux
session exit, background subagent finish, file appearance, network
service ready). Different mechanisms suit different contexts; pick the
one that matches the caller's framework.

## When to use `Monitor`

`Monitor` is a Claude Code SDK tool that streams events from a
background process — each line on stdout becomes a notification, and
the wait completes when the process exits. It's event-driven from the
agent's perspective, not a busy-poll.

**Use `Monitor` when:**

- The caller is a **Claude Code agent** (not a shell script, not a
  Codex/Gemini/Copilot session) — `Monitor` is a tool, not a CLI, so
  only Claude Code can invoke it.
- The wait is for a **bounded external event** that produces output as
  it progresses (CI checks, build runs, test runs, agent dispatch).
- You want the wait to not consume in-context tokens while idle —
  `Monitor` notifies on activity, so the agent doesn't have to
  re-prompt itself periodically.

**Concrete example** — waiting for CI on a just-pushed commit during a
triage-fix-merge cycle:

```
# Bash, run in background
gh pr checks <N> --watch --fail-fast

# Then in the agent flow, instead of busy-poll:
Monitor(processId=<bg-id>)
# returns when gh exits; non-zero exit = check failed; abort the merge
```

## When to fall back to busy-poll

`gh pr checks --watch` (or any other foreground blocking call) is the
right choice in:

- **Shell scripts.** `merge_pr.sh`, `cross_model_review.sh`, anything
  bash. `Monitor` is a Claude Code tool; bash can't call it. The
  blocking `--watch` form works for every framework.
- **Sandboxed / non-interactive environments.** CI runs, automated
  pipelines, anything where there's no Claude Code session to use
  `Monitor` from.
- **Other agent frameworks.** Codex, Gemini, Copilot sessions calling
  the same workspace scripts use the busy-poll path. The script-level
  wait works for them transparently.

## Decision quick-reference

| Caller | Recommended wait |
|--------|------------------|
| Claude Code agent (interactive) | `Monitor` over a background `gh pr checks --watch` (or similar) |
| `merge_pr.sh` (bash) | `gh pr checks --watch --fail-fast` directly |
| `cross_model_review.sh` polling tmux session output | tmux session-status check (existing busy-poll, OK as-is) |
| Codex / Gemini agents calling workspace scripts | The script's bash busy-poll fires for them automatically |
| CI / sandboxed pipeline | The script's bash busy-poll fires for them automatically |

## See also

- `.agent/scripts/merge_pr.sh` — uses `gh pr checks --watch --fail-fast`
  internally; works for every caller (issue #186)
- `.agent/scripts/cross_model_review.sh` — the tmux session approach
  for cross-model adversarial dispatch; busy-poll on session status is
  fine since it's tmux-internal
- Workspace ROADMAP "Reduce Agent Coordination Overhead" — broader
  context for the wait/event-driven theme
- Issue #187 — Routines + GitHub triggers spike; if Routines lands, some
  of these wait patterns get replaced by event-driven Routines fired by
  GitHub events instead of polled by the caller
