# Inspiration Digest: agent-orchestrator

Type: inspiration
Last checked: 2026-04-19
Repo: ComposioHQ/agent-orchestrator @ 7b13d2beadc505117691e74e7757acdfa7d17b9d

## Survey Summary

Agent Orchestrator (AO) is a mature, actively-developed (multiple PRs/day)
platform for running fleets of parallel AI coding agents. Each agent gets
its own git worktree, branch, and PR. The dashboard is the operator's
"single pane of glass."

**Org:** ComposioHQ | **Stack:** TypeScript + pnpm monorepo, Next.js 15
web dashboard, tmux/Docker runtimes | **License:** MIT | **Target:** Web
app at `localhost:3000`.

### Scope (from README + ARCHITECTURE.md + CLAUDE.md)

- Quick-start: `ao start <repo-url>` clones, configures, launches a web
  dashboard and orchestrator agent in one command
- Orchestrator agent spawns worker agents per issue; workers live in
  isolated git worktrees and open their own PRs
- **Reaction system** auto-routes CI failures + review comments back to
  the responsible agent (key differentiator — this is the "unattended"
  loop)
- Human only gets pulled in "when human judgment is needed"

### Plugin/Adapter Architecture (docs/PLUGIN_SPEC.md)

Pluggable across **seven slots**:

| Slot | Examples |
|------|----------|
| `runtime` | tmux, Docker |
| `agent` | Claude Code, Codex, Aider, OpenCode |
| `workspace` | worktree, clone |
| `tracker` | GitHub, Linear, GitLab |
| `scm` | GitHub, GitLab |
| `notifier` | desktop, Slack, Discord, webhook, Composio, OpenClaw |
| `terminal` | iTerm2, web |

Plugins are Node.js modules exporting a `PluginModule` with `manifest`
(slot + version + description), `create()` factory, and optional
`detect()`. Registered in a per-slot registry at startup.

### Runtime Data Layout (hash-isolated)

- Config at `~/any/path/agent-orchestrator/agent-orchestrator.yaml`
- Runtime data at `~/.agent-orchestrator/{hash}-{projectId}/`
  - `sessions/`, `worktrees/`, `archive/`, `.origin`
- `hash = sha256(configDir).slice(0, 12)` — same config → same hash
  prefix, so multiple projects per config share the prefix but don't
  collide
- All paths auto-derived — **"zero path configuration"**

### Dashboard

- Next.js 15, React 19, Tailwind v4
- Kanban board with **6 attention-priority columns** (collapsible to 4
  via feature flag)
- Design ethos: "warm terminal" — "high-end audio gear meets flight
  deck"; dense, monospace-forward for 10+ hour dev-day use
- Competitors cited: Conductor.build, T3 Code, OpenAI Codex app — all
  native Mac apps; AO is the web-based alternative

### Feedback Routing (docs/design/feedback-routing-and-followup-design.md)

Formalized pipeline for turning bug reports / improvement suggestions
into issue-or-PR or agent-session actions. Key decisions:

- Routing mode is exclusive: `local` OR `scm` (not both)
- Side effects stay deterministic in orchestrator control code
- Optional subagent can *recommend* decisions but cannot execute SCM
  mutations
- Pipeline stages: **report capture → issue resolution → follow-up
  planning → execution (SCM path or agent-session path) → linking**

### Claude-specific integration (CLAUDE.md)

- Explicit AGENTS.md + CLAUDE.md + ARCHITECTURE.md at root (our pattern!)
- Monorepo discipline documented explicitly
- Includes "working principles" contributor docs (recent PR #1299)

## Activity Snapshot (2026-04-19)

- **Very active**: multiple PRs merged per day; open issues #1325–#1350
  from this week alone
- Current open themes: pipeline v2 with conversational follow-up
  (#1350), multi-project storage (#1343), code-review plugin slot
  (#1339), terminal UX (#1348/#1278)
- Version bumps cadence: ~daily patch versions (v0.2.5 series)
- Recent notable: duplicate-spawn prevention (#1337), CI-failure
  auto-spawn webhooks (#1347), templated orchestrator prompts (#1206)

### Interest-area map (our registry's focus)

| Our interest area | Where it lives in AO |
|---|---|
| Reaction system | Lifecycle manager + webhooks (#1325, #1347) + feedback-routing design doc |
| Task decomposition | Orchestrator agent uses tracker plugin (GitHub issues / Linear) as queue; one worker per issue |
| Adapter architecture | `docs/PLUGIN_SPEC.md` — 7 slots, manifest-based registry, published via npm |
| Worktree-per-agent | Core primitive; hash-namespaced runtime dir; convergent with our `worktree_*.sh` |
| Dashboard model | Next.js Kanban, 6→4 attention-priority columns, terminal embedded in web |

## Pending Review — candidate patterns worth triaging

### Portable concepts (implementable in our simpler toolkit)

1. **Webhook-driven reaction system** — CI failure webhook → auto-spawn
   or auto-wake an agent on the relevant PR. #1347 "restore killed
   sessions and auto-spawn on CI failure" is the mature form. For us,
   a minimal version would be a `.agent/scripts/watch_ci.sh` that polls
   `gh run list --json` and emits terminal bell on failure
2. **Code-review plugin slot (#1339)** — AO treats AI-powered peer
   review as a first-class slot alongside agents/trackers/etc. We
   already have `/review-code`; a "slot" concept could formalize it
   as something that multiple implementations (different reviewer
   personas) plug into
3. **Duplicate-spawn prevention (#1337)** — feature-flagged check that
   an agent isn't already working on an issue before spawning a new
   one. Would save us from accidentally double-tasking in parallel
   agent sessions (not a common failure mode yet but real)
4. **Warm-terminal design language** — if we ever build a visual UI,
   their typography (JetBrains Mono display, Geist Sans body at 13px)
   + warm palette is a more-engineered starting point than most. Not
   a near-term need

### Architectural references (understand, don't necessarily port)

5. **Hash-based project namespacing** — `sha256(configDir).slice(0,12)`
   prevents collisions when the same config manages multiple projects.
   We only have one active project (daddy_camp); overkill now, worth
   remembering if we scale
6. **Exclusive routing mode (local OR scm)** — their explicit decision
   that routing can't split both ways. Clarity-over-flexibility
   principle worth noting
7. **Plugin manifest + registry pattern** — formalized cross-framework
   extension points. More structure than our skill system needs today
8. **Templated orchestrator prompt (#1206)** — prompt-as-config for the
   orchestrator agent. Our plan-task and review-code skills are
   markdown files; they serve the same role at lower formality

### Out of scope (skip)

- Dashboard UI architecture — we're CLI-first (session D5 constraint)
- Web-based terminal embedding — we use real terminals directly
- Multi-tracker support (Linear/GitLab) — we're GitHub-only
- npm package distribution — we're a single-workspace repo
- Next.js monorepo discipline — we're bash + markdown

## Cross-reference with 2026-04-19 session decisions

- **Tier 3 orchestration** (Deferred, Row 6 of #157) — AO IS Tier 3.
  This survey confirms the category is well-formed, pattern-convergent,
  and mature. Still deferred for daddy_camp per our "most of our
  backlog isn't mechanical" reasoning. Revisit trigger unchanged
- **Agent Teams declined** (Row 7) — AO's reaction system is the
  non-Agent-Teams equivalent of the coordination they offer; our
  file-polling watchdog helper is the minimal-extraction version
- **Framework resilience** — AO's agent-agnostic design (Claude/Codex/
  Aider/OpenCode) validates the principle; reinforces we should keep
  CODEX.md, Gemini, Copilot adapters current

## Pending Review

(Items in the "Portable concepts" section above are pending — won't be
added to roadmap in this PR because PR #157 is actively reshaping the
roadmap. Triage next session.)

## Roadmapped

(none this run)

## Skipped (this run)

- Dashboard UI architecture — CLI-first constraint
- Web terminal embedding — not our model
- Linear/GitLab tracker plugins — GitHub-only
- npm publishing + pnpm monorepo — different ops shape

## Deferred

(none — all items either roadmapped-pending or skipped)
