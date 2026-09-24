# Codex workflow observations from issue 309

## Scope and evidence

Observed in the Codex session implementing #309 on 2026-09-23. These are
observations and proposed improvements, not changes to workspace policy.
The session exposes command-specific working directories, fresh-context
subagents, messaging, and asynchronous user questions. Other Codex deployments
may expose different capabilities.

## What worked

- `worktree_create.sh --issue 309 --type workspace` created the expected branch
  and worktree after sandbox approval. `worktree_enter.sh --print-path` and
  explicit command `workdir` replace persistent-shell assumptions.
- The work-plan resolver and `review_progress.sh plan-sha` worked unchanged.
- A fresh in-process Codex reviewer independently evaluated committed plan
  `bed79ef` and returned ready. The parent persisted its report accurately.
  This demonstrates delegation, not a complete run-issue adapter.
- `progress_append.sh` recorded Issue Review, Plan Authored, and Plan Review
  using existing ADR-0013 types. No alternate timeline format was needed.
- The first plan commit passed the full pre-commit suite. Later WIP timeline
  commits used the documented `SKIP=validate-script-tests` exemption, retaining
  other hooks; the completed implementation still requires the full suite.

## Friction and improvements

| Observation | Improvement to evaluate |
| --- | --- |
| Git metadata is read-only under this session's sandbox; worktree creation and commits need escalation. | Document sandbox requirements separately from framework capabilities; use narrowly scoped approvals. |
| Even git-bug reads attempt to open `.git/git-bug/lock`; the fallback also needs GitHub network access. | Expose cache-lock failure separately from a cache miss, and reuse an already fetched issue across phase handoffs where appropriate. |
| Multi-file skill reads produced very large and sometimes truncated output. | Load one phase's necessary instructions at a time; avoid repeated root-resolution boilerplate in every skill. This run's broad reads were avoidable overhead. |
| Explicit identity arguments set `AGENT_FRAMEWORK=custom` despite the Codex name. | Separate truthful model identity from framework detection; explicitly set `AGENT_FRAMEWORK=codex` when dispatching reviews. |
| The handoff script defaults to `sonnet`/`opus`, though it supports `--model`. | Add a framework-aware model mapping rather than copying provider-specific aliases into another runtime. |
| Root discovery uses `~/.claude/agent-workspace-root`. | Provide a shared root-resolution contract with framework-specific adapters. |
| A user reported a rapid five-hour allowance drop during the run. No per-task quota accounting was available to the agent. | Make review depth and context loading cost-aware; avoid automatic multi-agent expansion for small fixes. Do not treat the allowance as elapsed wall-clock time. |

OpenAI's [pricing documentation](https://learn.chatgpt.com/docs/pricing#what-are-the-usage-limits-for-my-plan)
states that usage depends on model, task complexity, context, reasoning, tools,
retrieval, and caching. The five-hour window is not five hours of continuous
execution. The exact cause or size of this session's quota consumption is not
established by those docs or by the user's warning alone.

## Is the Claude Code restriction warranted?

The literal `run-issue` recipe uses Claude-specific tool names, model aliases,
and checkpoint semantics. Treating that recipe as untested on Codex is justified.
Claiming that Codex fundamentally cannot orchestrate the workflow because it
lacks an Agent tool is too broad: this session completed a fresh-context plan
review, and official [Codex subagent documentation](https://learn.chatgpt.com/docs/agent-configuration/subagents)
describes supported delegation. The `start-task` persistent-cwd requirement is
also an adapter concern; explicit workdir is sufficient for the scripts here.

A future compatibility change should use capability checks (delegate, resume,
ask-and-wait, explicit cwd, identity, model mapping), and test dispatch exit
contracts and stop/resume checkpoints on Codex. This run has not validated a
complete automatic orchestrator, checkpoint approval adapter, or cross-framework
model equivalence. No Claude-only restriction is removed in the #309 fix.
