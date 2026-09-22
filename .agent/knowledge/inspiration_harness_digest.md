# Inspiration Digest: harness

Type: inspiration
Last checked: 2026-09-22
Repo: majiayu000/harness (no local clone checked out; survey done from README
+ GitHub API — see "Clone note" below)

First-run survey. Registry interest areas: Starlark-sandboxed policy engine
for execution rules; independent cross-agent code review (architectural
self-review prevention); Postgres-backed durable workflow/task state;
per-run git worktree isolation model; GitHub webhook automation (@harness
mentions triggering tasks); OpenTelemetry observability for agent runs.

## Survey Summary

Harness (MIT, Rust, created 2026-03-02) is a control plane for running
fleets of Claude Code / Codex / Anthropic-API agents "as serious
infrastructure" rather than one agent in one terminal. It is one layer
("Orchestrate") of the author's larger open-source agent-infra stack
(alongside `spellbook`, `vibeguard`, `remem`, `litellm-rs`, `keepline`).

### Architecture

A layered crate workspace: `harness-protocol` (JSON-RPC 2.0 envelopes,
32 methods over stdio/HTTP/WebSocket) → `harness-core` (domain types,
config, prompts, agent/interceptor traits) → `harness-agents` (Claude
Code CLI / Codex CLI / Anthropic API adapters), `harness-rules`
(Starlark policy engine), `harness-skills` (discovery/dedup),
`harness-gc` (signal-driven remediation), `harness-observe` (OTLP
events/metrics), `harness-exec` (ExecPlan lifecycle) → `harness-server`
(HTTP/stdio/WebSocket runtime, webhook intake, workflow-runtime
integration) → `harness-cli` (`exec`/`serve`/`gc`/`rule`/`skill`/`plan`
subcommands).

### Interest-area findings

**1. Starlark policy engine.** `harness-rules` executes execution
policies in a "hardened Starlark dialect" that strips `load`/`def`/
`lambda` — a sandboxed-but-real-language rule evaluator, not YAML
predicates. This is a materially different design point from this
workspace's rules, which live entirely as prose in `AGENTS.md` +
pre-commit/CI scripts (no rule DSL, no runtime rule-loading command).
`harness rule load .` / `harness rule check .` load and evaluate rules
against a project at runtime.

**2. Independent cross-agent review.** `[agents.review]` config
(`reviewer_agent = "codex"`, `max_rounds = 3`) runs a *different* agent
than the implementer to review before/alongside GitHub review —
"preventing self-review by architecture" per the README's Key Features
list. This is close in spirit to `cross_model_review.sh` (Gemini/agy
reviewing a Claude-authored diff) but built into the orchestration layer
as a first-class per-task stage rather than a standalone script invoked
around the review-code / triage-reviews loop. The JSON-RPC method list
includes a dedicated `cross_review` method under a "VibeGuard" category,
suggesting the review call is itself pluggable/interceptable.

**3. Postgres-backed durable state.** The server requires Postgres 14+
(the README notes "SQLite was removed in v0.x") for thread/task/turn
state, submissions, and workflow-runtime evidence; migrations run
automatically on first connect. This is materially heavier than this
workspace's state model (`progress.md` timelines + git history +
GitHub issues/PRs as the source of truth, no database). The tradeoff
buys resumable/queryable fleet state (`/api/workflows/runtime/
submissions/{id}` status and SSE streaming, `/api/dashboard` aggregate
view) at the cost of a running database dependency — not something to
port wholesale, but the "submission" object (durable record of a
prompt/issue/PR request plus its lifecycle) is a clean shape for
anything here that wants to track a dispatched piece of work across a
restart.

**4. Per-run git worktree isolation.** The stated execution flow is
`POST submission → dispatcher creates job → worker acquires project
queue permit → create git worktree → agent executes in isolation →
validate and review → persist evidence`. Each project entry in the
multi-project config (`[[projects]]`: name, root, max_concurrent,
optional per-project agent override) gets its own worktree isolation
and concurrency limit — structurally similar to this workspace's
per-issue/per-skill worktree model, but centrally scheduled by the
server rather than agent-invoked via `worktree_create.sh`. Sandbox
tiers are explicit and layered: `read-only`, `read-only-with-network`,
`workspace-write`, `danger-full-access`, backed by Landlock or
Bubblewrap on Linux, with a documented case (macOS Claude Code cannot
run under the Seatbelt `workspace-write` sandbox at all, forcing
`danger-full-access`) that is a useful cross-check against any sandbox
assumptions this workspace makes for macOS contributors.

**5. GitHub webhook automation.** HMAC-SHA256-verified webhooks parse
`@harness` mentions in issue comments / PR reviews to trigger
submissions — a chat-ops style entry point this workspace does not have
(work here starts from an agent session, never a GitHub comment).

**6. OpenTelemetry observability.** Native OTLP/HTTP/gRPC export
described as "async-safe transport for signal-handler contexts" — a
specific low-level detail (avoiding signal-handler-unsafe work during
OTel export on shutdown) that would matter if this workspace ever added
telemetry export from a long-running process; today nothing here runs
long enough for that class of bug to surface.

### Activity Snapshot (2026-09-22)

- 74 stars, MIT, Rust, created 2026-03-02 (~6.5 months old at time of
  check). Very active: `pushedAt` 2026-09-21T17:42Z, i.e. commits within
  the last 24 hours of this survey.
- Issue/PR numbering is well past 2000 (open issues sampled up to
  #1955; open PR #2110), and the 5 most recent commits are dated
  2026-09-21 — this is a high-velocity, single/small-team-maintained
  project judging by commit message density (`feat(eval)`,
  `fix(agents)`, `test(agents)` in tight succession), not a
  low-activity survey candidate like several other tracked
  "inspiration" entries.
- Open work skews toward hardening the eval/observability/cost-tracking
  surface (budget enforcement, semantic retrieval, golden-suite drift
  gates) rather than core orchestration — the fleet/policy/review
  architecture described above looks past its initial-design phase.

### Clone note

Per skill step 2, a local shallow clone would normally live at
`<MAIN_ROOT>/.agent/scratchpad/inspiration/harness/`. This first-run
survey was done from the GitHub README + `gh api` activity endpoints
only (no local clone), which was sufficient for the interest-area
findings above; a future changelog-mode check should clone for source-
level detail on the Starlark rule dialect and the `cross_review`
JSON-RPC handler if those become adoption candidates.

## Activity Snapshot

See "Activity Snapshot (2026-09-22)" above.

## Pending Review

- `starlark-policy-engine-vs-prose-rules` — Compare `harness-rules`'
  hardened-Starlark execution-policy model against this workspace's
  prose-plus-script rule enforcement (ADR-0004/0005 territory). Worth a
  closer read of `harness-rules` source before a roadmap decision — the
  restricted dialect (no `load`/`def`/`lambda`) is the interesting part,
  not "add Starlark". (2026-09-22)
- `cross-review-as-orchestration-primitive` — `[agents.review]` config
  + the `cross_review` JSON-RPC method make cross-model review a
  first-class per-task stage rather than an external script. Compare
  against `cross_model_review.sh` + the review-code/triage-reviews loop
  to see whether any part of the *configuration* shape (reviewer agent
  selection, max_rounds, auto-trigger toggle) is worth adopting even
  without the server. (2026-09-22)
- `submission-object-for-durable-dispatch` — The workflow-runtime
  "submission" object (prompt/issue/PR request + queryable status +
  SSE stream) is a clean model for tracking dispatched work across a
  restart; evaluate against `dispatch_phase.sh` / `/run-issue`'s
  in-process handoff model, which currently has no durable record if
  the driving session ends mid-run. (2026-09-22)
- `sandbox-tier-macos-claude-exception` — Confirm whether this
  workspace's own sandbox/tool-mapping assumptions account for the
  documented macOS constraint (Claude Code cannot run under Seatbelt
  `workspace-write`, forcing `danger-full-access`); informational unless
  a macOS contributor hits it. (2026-09-22)

## Roadmapped

(none — first-run survey; items above are pending review, not yet
triaged into roadmap/skip/defer)

## Skipped

(none)

## Deferred

(none)
