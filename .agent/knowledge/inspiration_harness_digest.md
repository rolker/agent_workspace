# Inspiration Digest: harness

Type: inspiration
Last checked: 2026-11-13
Repo: majiayu000/harness @ 030fbbc302f0f1be76ae97f4991d22f4a2d0a6ed
Previously checked: 2026-09-22 (no commit SHA recorded: the first survey was
done from the README and GitHub API without a clone)

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

## Changelog (2026-09-22 → 2026-11-13)

Method note: the 2026-09-22 survey recorded no commit SHA, so the GitHub
compare API could not be used (no base to compare from). Substituted: the
commit list since 2026-09-22 (`gh api repos/majiayu000/harness/commits?since=2026-09-22T00:00:00Z`,
30 commits), `gh release list`, and `CHANGELOG.md` in the new shallow clone
(`.agent/scratchpad/inspiration/harness/` in the main checkout, HEAD 030fbbc, 2026-11-13). The
clone is depth 1, so no per-commit diffs were read. The first clone is now
in place for future runs.

**Releases**: v0.7.0 (2026-10-19, first release since v0.6.34 on 2026-05-30),
v0.7.1 (2026-10-29), v0.7.2 (2026-11-13, a few hours before this check).

- **Architecture moved to a workflow runtime (v0.7.0, breaking).** The
  Harness-owned JSON-RPC `thread/*` and `turn/*` methods and the legacy
  `/tasks` routes were removed; durable work is submitted through
  `POST/GET /api/workflows/runtime/submissions` (detail, `/stream`,
  `/artifacts`, `/prompts`, `/proof`). New: declarative workflow definitions,
  intake bindings, candidate selection/promotion, durable replay
  transcripts. The "submission" object from the survey is therefore now the
  primary API, not a side feature. A 22,910-line net deletion (Phase 1
  removal) accompanied it.
- **Fail-closed API auth (v0.7.0).** HTTP API now refuses to run without
  `api_token` / `HARNESS_API_TOKEN` unless `allow_unauthenticated = true`.
- **Evaluation and cost control.** Manifest-driven eval runs, report/diff
  commands, attestations, a supervised Docker task host with native quality
  gates; CPU-time and USD budget enforcement (v0.7.1: USD-capped eval runs
  stop when spend is unknown instead of counting it as zero). Open issues
  #1768 and #1770 (live baselines, production spend verification) remain.
- **Operator tooling.** Console v3 dashboard connected to live data, an
  operator monitor cockpit, alerting, runtime trajectory spans.
- **Agents.** OpenCode execution and per-turn ACP backends, pinned
  agent-contract activities, agent stack inventory.
- **Distribution (v0.7.2).** Prebuilt binaries (macOS arm64/x64, Linux
  x64/arm64) with SHA-256 files attached to releases; v0.7.0 notes had said
  source-only.
- **Security hygiene.** Dependency advisories (rustls, rustls-webpki, openssl,
  tokio, rustix) patched in v0.7.0 / v0.7.1 / v0.7.2.
- **Not found changed in this range** (README and `CHANGELOG.md` read; no
  commit-level diff of the crates): the Starlark policy engine
  (`harness-rules`, README still describes the hardened dialect), the
  `[agents.review]` cross-agent review config (README still shows
  `reviewer_agent = "codex"`, `max_rounds = 3`), and per-run worktree
  isolation. Their implementation was not read at source level.

**Corrections to the 2026-09-22 survey**

- The survey said the JSON-RPC surface has 32 methods; the current README
  diagram says 30, and v0.7.0 removed the `thread/*` / `turn/*` methods the
  survey implied were the main interface. The `cross_review` method still
  exists in `crates/harness-protocol/src/methods.rs`.
- The survey said Postgres was required for the server. Still true for the
  fleet server; the README now states explicitly that one-shot
  `harness exec` needs neither Postgres nor the server (README lines 98, 114).
- The survey's "Clone note" (no local clone) is superseded by the clone made
  on this run.

## Activity Snapshot

Snapshot 2026-11-13 (supersedes the 2026-09-22 snapshot above for counts):

- 92 stars (was 74), MIT, Rust, not archived, default branch `main`,
  `pushedAt` 2026-11-13T14:08Z.
- 7 open issues, 1 open PR (the v0.7.2 release PR, #2175). The open issues
  are roadmap-style feature requests filed 2026-10/11: #2168 policy-gated
  event evaluation and decision router, #2169 correlating events / issues /
  PRs / CI / workflow attempts across sessions, #2170 operator attention
  queue with human-intervention reasons, #2171 supervised recurring agent
  loops with explicit mandates and stop conditions, plus eval/cost items
  #1744, #1768, #1770. The survey-era numbering (issues to #1955) implies
  most of the earlier backlog was closed.
- 30 commits since 2026-09-22, but the cadence slowed: 3 commits on
  2026-11-13, then 2026-10-29, 10-19..10-21, 10-13, 10-11, 10-07, and a
  burst 09-25..09-30. Mostly eval, runtime and release fixes, not new
  review/policy design.
- Still active and releasing (3 releases between 2026-10-19 and 2026-11-13); not a candidate for
  archiving.

## Pending Review

New in the 2026-11-13 check (ids are stable for triage):

(none pending from this round)

Carried from 2026-09-22, still undecided (the Starlark, cross-review and
sandbox-tier items were not changed by the commits read; the submission
item is sharpened by `harness-1`):

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

(none)

## Skipped

- `harness-3` `fail-closed-defaults-and-unknown-spend` — informational: two
  instances of failing on missing evidence, no change to workspace tooling
  (2026-11-13)
- `harness-4` `prebuilt-binary-release-with-checksums` — applies only to
  shipping a tool binary, which this workspace does not do (2026-11-13)

## Deferred

- `harness-1` `durable-submission-api-now-primary` — the concrete part is
  covered by the roadmapped `gstack-2` (progress entries record their
  commit); the rest is a comparison with a database-backed design the
  workspace does not follow (2026-11-13)
- `harness-2` `operator-attention-queue-and-stop-conditions` — design
  discussion upstream only (issues #2170, #2171); nothing shipped
  (2026-11-13)
