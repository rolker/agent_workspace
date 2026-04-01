# Inspiration Digest: gastown

Type: inspiration
Last checked: 2026-03-31
Repo: steveyegge/gastown @ 4894b0d

## Survey Summary

### Overview

Gas Town is a Go-based multi-agent workspace manager that orchestrates AI coding
agents (Claude Code, Copilot, Codex, Gemini) working on tasks across multiple
projects. It provides persistent work tracking via git-backed "beads" (issues),
inter-agent communication via mail/nudge protocols, and a tiered supervisor
hierarchy. The system is designed to scale from a few agents to 20-30 working
concurrently.

### Multi-Agent Coordination and Workspace Management

- **Town/Rig/Agent hierarchy**: Town is the workspace root, Rigs are per-project
  containers, agents are scoped to town-level (Mayor, Deacon) or rig-level
  (Witness, Refinery, Polecats, Crew)
- **Mayor as coordinator**: A persistent Claude Code instance with full workspace
  context — the primary interface for directing multi-agent work
- **Beads system**: Git-backed issue tracking that stores work state as structured
  data in `.beads/` directories, surviving agent crashes and restarts
- **Two-level beads architecture**: Town-level beads (`hq-*`) for cross-rig
  coordination, rig-level beads for project implementation work
- **Convoys**: Batch work tracking units that group related beads across rigs,
  enabling progress monitoring and completion notification
- **Rigs use git worktrees** for isolation — each rig wraps a git repo with
  its own agent pool
- **Dolt database backend** for structured queries on beads data (graph-aware
  triage via `bv` CLI)

### Task Orchestration and Dispatching

- **`gt sling`**: Assigns a bead to an agent/polecat, creating the work context
- **Convoy-based dispatch**: Mayor creates convoy with bead IDs, assigns polecats,
  monitors progress via `gt convoy list`
- **Scheduler**: Config-driven capacity governor that batches polecat dispatch under
  concurrency limits to prevent API rate limit exhaustion
- **Molecules/Formulas**: Workflow templates (TOML) that coordinate multi-step work —
  formulas are instantiated as molecules with tracked steps; supports checkpoint
  recovery for poured wisps
- **`gt done`**: Work completion protocol — pushes branch, submits to merge queue,
  clears hook, signals witness
- **Refinery**: Per-rig merge queue processor using Bors-style bisecting queue with
  verification gates
- **Mountain convoys**: Autonomous stall detection and smart skip logic for large-
  scale (epic) execution

### Agent Isolation and Context Management

- **Persistent identity model**: Agents have persistent identity (via agent beads)
  but ephemeral sessions — work history, CV chain, and reputation survive restarts
- **BD_ACTOR format**: Slash-separated path format (`rig/role/name`) for universal
  attribution in git commits, beads, and mail
- **Hooks**: Git worktree-based persistent storage for agent work state, survives
  crashes and restarts
- **Three-tier monitoring**: Witness (per-rig lifecycle), Deacon (background
  supervisor), Dogs (infrastructure workers) — detects stuck/zombie agents
- **Polecat lifecycle**: Four states (Working, Idle, Stalled, Zombie) with
  structured transitions; idle polecats reused for efficiency
- **Seance**: Session discovery and continuation — agents can query predecessors
  for context and decisions from earlier work
- **`gt prime`**: Context recovery command after compaction/new session — reloads
  role context, identity, and pending work
- **Escalation protocol**: Severity-routed (P0-P2) with tiered chain
  (Agent -> Deacon -> Mayor -> Overseer), each tier can resolve or forward
- **Mail protocol**: Structured message types (POLECAT_DONE, MERGE_READY, MERGED,
  etc.) with routing through beads system; nudge for immediate delivery, mail
  for persistent messages
- **Sandboxed polecat execution**: Design for isolated execution environments
- **tmux-based agent sessions**: Per-agent tmux panes with socket isolation per town

### Notable Patterns Worth Studying

1. **Git-backed persistent work state** (beads) — agents never lose context on crash
2. **Tiered supervisor hierarchy** — Witness/Deacon/Mayor escalation chain
3. **Polecat reuse** — persistent identity with ephemeral sessions, worktree preserved
4. **Mail protocol** — structured inter-agent messaging with typed message formats
5. **Seance** — querying predecessor agent sessions for context continuity
6. **Convoy tracking** — batch work units with progress monitoring across agents
7. **Capacity scheduling** — concurrency governor to prevent API rate exhaustion
8. **Agent attribution** — BD_ACTOR slash-path format for universal provenance

## Changelog Since Last Check

207 commits, 300 files changed. Very high velocity.

- Refinery judgment controls: judgment_enabled + review_depth wired from rig config
- Disabled patrols setting: disable without editing daemon.json
- Merge queue panel in convoy view
- Plugin dispatch mail cleanup via hourly reaper
- Dolt 1.83+ compatibility fix
- Numerous bug fixes: patrol molecules, agent state sync, workspace nesting

## Activity Snapshot

- 3,436+ open issues (all needs-triage), extremely high velocity
- 10+ PRs merged in last 24 hours
- Self-hosting: project develops itself using its own multi-agent system

## Pending Review

(none)

## Issued

- `git-backed-work-state` — Issue #33: Explore git-backed persistent work state for agents (2026-03-22)
- `tiered-supervisor-hierarchy` — Issue #34: Explore agent health monitoring and supervision (2026-03-22)
- `inter-agent-mail-protocol` — Issue #35: Explore structured inter-agent messaging protocol (2026-03-22)
- `session-continuity-seance` — Issue #36: Explore session continuity and cross-session context recovery (2026-03-22)

## Skipped

(none)

## Deferred

- `convoy-batch-tracking` — Batch work tracking with progress monitoring — revisit when managing more concurrent work (2026-03-22)
- `polecat-reuse-pattern` — Persistent agent identity with worktree reuse — revisit as optimization when scale warrants (2026-03-22)
- `capacity-scheduling` — Concurrency governor for agent dispatch — revisit when running more agents concurrently (2026-03-22)
- `agent-attribution-model` — BD_ACTOR slash-path provenance format — revisit as agent team grows (2026-03-22)
- `configurable-review-depth-per-project` — Per-project review depth defaults instead of auto-classification only; revisit when multi-project is real (2026-03-31)
