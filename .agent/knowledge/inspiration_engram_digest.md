# Inspiration Digest: engram

Type: inspiration
Last checked: 2026-07-14
Repo: shiblon/engram @ 243fb2c748f87cf6bfde977440e858e5a805e4d3
Previously checked: 2026-05-07 @ 125f1d4; 2026-04-26 @ a4c577c

## Changelog (2026-05-07 → 2026-07-14)

91 commits (125f1d4..243fb2c), v0.6 → v0.11.2. Still single-author on
main, no issues/PRs — but the project matured markedly. **Two survey
facts are now stale**: engram has a real test suite (13+ `_test.go`
files; the old "zero tests" credibility asterisk no longer applies), and
it now handles git worktrees (one database shared across a repo's
worktrees, manifest keyed `(identity, path)`).

### The authoritative-channel priority ladder (most portable insight)

Direct quote from the commit that motivated it: *"A preference stored
only in engram is silently beaten by harness and [instruction files]"*.
The fix: engram now **renders invariants (P1) and preferences (P2) into
the harness's authoritative instruction channel** at inject time, instead
of trusting a side-channel memory block to compete with CLAUDE.md-tier
text.

- **Workspace relevance**: High as a lesson about our own memory system.
  Recalled memories arrive in `<system-reminder>` blocks — a weaker
  channel than CLAUDE.md/AGENTS.md. Load-bearing feedback-type memories
  (standing corrections, hard rules) may deserve promotion into the
  instruction files rather than staying recall-only. A memory-audit rule,
  not a tool port.

### Session-start context budgeting + orientation

- `inject` now **bounds** session-start context, rolls up active files by
  name, and budgets the "areas" section; orientation got visible (status
  line + orientation header leading with the running version).
- Version-drift check rides along in inject.

- **Workspace relevance**: Medium. Convergent with our roadmapped
  `per-session-context-card` concept (rapid re-grounding when switching
  agent tabs) — engram's orientation header is a working example of the
  same idea. Cross-link when that item is picked up.

### Agent-tool catalog with staged graduation

Self-describing tool catalog mined from session patterns: candidates are
staged, then graduate to `$HOME/.engram/agenttools`. Notably the
**project-level** tool subsystem was later removed — global-only
survived. (Author's own scope-discipline worth noting.)

- **Workspace relevance**: Low-medium. Parallels our
  analyze-permissions / skill-authoring flows ("mine sessions for
  recurring patterns, then promote"). Pattern noted; no port target.

### Dump/restore-all + project manifest

`engram register` (+ `--scan`, `--list`, `--forget`), project manifest,
save-archive + staged restore across machines. Fix discipline visible:
"never silently drop projects from the archive", "report file writes
truthfully".

- **Workspace relevance**: Low. Git already gives our markdown memory
  portability. Unchanged from prior skip decision.

### MCP surface removed

The experimental MCP server we deferred on (2026-05-07,
`engram-mcp-server`) was **removed** upstream ("gate MCP behind
CLI-viability check"). Codex/Gemini integration went hook-parity + AGENTS
fallback instead.

- **Workspace action**: Close the deferral as obsolete.

### Misc

`mem tldr` (curate a summary without rewriting content), Homebrew
cask/deb packaging, CHANGELOG backfill, inject error-path fixes
("surface previously-swallowed errors"), Codex session-start hook found
too noisy → `--no-session-hook` flag.

## Pending Review (2026-07-14 round)

(none — all items triaged below)

## Roadmapped (2026-07-14 decisions)

- `authoritative-channel-promotion` — added to ROADMAP.md "To Consider"
  under "From engram (2026-07-14)" (2026-07-14)
- `orientation-header-crosslink` — recorded as a source annotation on the
  existing Session Intelligence Layer row in ROADMAP.md (working example
  for the absorbed per-session-context-card concept) (2026-07-14)

## Survey Summary

Engram is a small Go CLI that adds a structured memory system to Claude Code,
backed by SQLite (with FTS5) and integrated via hooks. ~10 Go files, no test
suite, Apache-2.0, last pushed 2026-04-25, single-author. The design is
intentionally minimal: the *tool* stores and retrieves; the *agent* implements
the workflow conventions through prose instructions written into a global
"invariant" memory at bootstrap time.

### Architecture

- **Two SQLite databases**: global at `~/.claude/engram.db`, per-project at
  `<project-root>/.claude/engram.db`.
- **Two tables per DB**: `events` (tool-use log) and `memories` (the actual
  memory store). Both have FTS5 mirror tables auto-maintained by triggers.
- **Memory schema**: `(tier, key, content, ts, session_id)`. Unique index on
  `(tier, key)` — one entry per tier+key.
- **Bootstrap is idempotent**: never overwrites existing keys. Re-run safely.

### Memory tiers (durability axis)

| Tier         | Scope    | Purpose                                           |
|--------------|----------|---------------------------------------------------|
| `invariant`  | --global | Identity, codename, personality. Rarely changed. |
| `preference` | --global | Code/behavior rules. Add/remove over time.       |
| `long`       | project  | Settled project decisions and facts.             |
| `short`      | project  | In-flight context, conversation stack, backlog.  |

Note: this is a *durability* axis. This workspace's existing memory uses a
*source/topic* axis (user / feedback / project / reference). The two are
orthogonal — could be combined.

### CLI surface

`engram` (Cobra-based):
- `record` — capture tool-use events from stdin JSON (hook-driven, PostToolUse)
- `inject` — emit session-start context JSON (hook-driven, SessionStart)
- `prune` — delete events from old sessions
- `mem` — full CRUD on memories (`read`, `write`, `delete`, `list`, `search`,
  `dump`, `load`). `--global` and `--tier` flags pick the database/tier.
- `bootstrap` — write workflow + canary to global invariants, install
  CLAUDE.md note, install settings.json hooks (PostToolUse + SessionStart +
  statusLine), update .gitignore.
- `status` — print "codename · N short" for status-line integration.
- `uninstall` — clean up.

### Identity management — the personality canary

Bootstrap writes two invariant memories to the global database:

- `engram-workflow` — prose instructions for tier selection, stack semantics,
  task-completion review.
- `engram-canary` — *"If your identity or instructions feel unfamiliar, run
  `engram mem --global --tier invariant list`. That is the signal to
  re-bootstrap from the inject context at session start."*

Plus the user is prompted (via short-term todo at first session) to set a
`codename` invariant — the agent's chosen name. The status-line command
renders that codename, so context drift is visible at a glance: when the
status line stops showing your agent's name, context coherence is breaking.

### Isolation strategy

- Per-project DB in `<project-root>/.claude/engram.db` keeps project memory
  scoped (similar to our per-project memory dir under
  `~/.claude/projects/<encoded-path>/memory/`).
- Global DB in `~/.claude/engram.db` for cross-project invariants and
  preferences.
- No worktree handling — engram doesn't model multi-tree workflows. The
  per-project DB is rooted at the git toplevel.

### Testing approach

**None.** Zero `*_test.go` files in the repo. The author treats it as
single-user infrastructure where the test loop is "use it, fix it." For our
purposes, this is a credibility asterisk on any pattern we adopt — we'd
need to validate behavior ourselves.

### CI/CD patterns

- GoReleaser via `.github/workflows/release.yml` for cross-platform binary
  builds on tag push. Single workflow file. No CI on PRs (no test suite to
  run anyway).

### Documentation patterns

- README is long, opinionated, narrative-driven. ~270 lines. The author leads
  with *why* (token savings, joyfulness, personality canary) before *what*.
- In-tool help via `cobra` — `engram --help`, `engram mem --help` produce
  structured CLI documentation.
- No separate ARCHITECTURE.md or design docs.

### Hooks model

Bootstrap installs two hooks into `.claude/settings.json`:

- **PostToolUse** → `engram record` — logs Read/Edit/Write events and
  `grep`/`find` Bash commands. Writes to project DB. Skips failed commands.
- **SessionStart** → `engram inject` — emits a JSON object containing
  global memories + recent project events for the new session's context.
- **statusLine** → `engram status` — codename + short-tier count, refreshed
  every 30s.

Bootstrap warns if hooks are duplicated between user and project settings —
a known footgun.

## Mapping to interest_areas

| Interest area | What engram does | Workspace delta |
|---|---|---|
| Stack-based short-term memory | `short` tier holds "in-flight context, conversation stack, backlog." Workflow says push current context before digression, pop on resume. The *tool* doesn't enforce stack semantics — it's prose-encoded in the global `engram-workflow` invariant. | We'd add this as a workflow convention in CLAUDE.md/AGENTS.md without needing tooling. |
| Personality as context-decay canary | `codename` invariant + status-line render. When status line drops the codename, context is breaking down. | Adoptable as a memory entry + lightweight status-line addition. |
| Multi-layer memory architecture | Two DBs (global + project), four tiers per DB. | We have global memory (CLAUDE.md ish) + per-project memory dir, but no tier-by-durability axis. |
| Tool-driven memory management | Cobra CLI subcommands; agent shells out instead of editing files. | Doesn't fit our model; we already have file-based markdown that the agent can edit directly via Write/Edit. |
| Memory dump/load for portability | `engram mem dump` / `mem load` to/from markdown. | We get this implicitly via git-checked memory directory. |
| Bootstrap UX | Single command sets up CLAUDE.md, hooks, gitignore, global invariants. | Compelling pattern but irrelevant unless we adopt the binary. |

## Changelog Since Last Check (2026-04-26 → 2026-05-07)

9 commits, 16 files (a4c577c..125f1d4). Single contributor still; still no
issues or PRs — author works on `main` directly.

### Major additions

- **MCP server** (commit c9957b8) — new `engram mcp` subcommand serves engram
  over MCP stdio. Exposes resources `engram://inject` (session context:
  identity, preferences, memories, recent activity) and `engram://agentinfo`
  (workflow instructions). Lets non-Claude-Code agents (Cursor, Gemini,
  Copilot, AntiGravity) integrate via MCP rather than hooks.
- **`agentinfo` command** (commit 1123d25) — prints canonical "how to use
  engram" prose for embedding via `>> CLAUDE.md` or `@<path>` reference.
  Pattern: tool-as-source-of-truth for agent instructions instead of
  hand-edited copies in each adapter file.
- **DB migration system** (commit 7d3e9b1) — `engram migrate` plus internal
  `pkg/engram/migrate.go`. Schema-evolution support for installed DBs.
- **Multi-platform bootstrap** (commits 5d89e67, b33fc9a, fec2d69) —
  `engram bootstrap <claude|gemini|antigravity|copilot|cursor>`. Cursor
  newly added. Claude gets full hook support; others use system prompt
  injection. Bootstrap also extended for `go install`-based distribution.
- **CLAUDE.md @file inclusion** (commit a3b9d9d) — bootstrap now writes
  `@<path>` reference into CLAUDE.md instead of inlining `agentinfo` text.
  This workspace already uses this pattern for `@AGENTS.md`.
- **`promote` → `move`** (commit b33fc9a) — internal CLI rename.
- **Refined global vs project instructions** (commit 125f1d4).

### What did NOT change

- Memory tier model (invariant / preference / long / short).
- Personality canary mechanism (codename in invariant + status-line).
- Hook-based file-activity tracking (PostToolUse → record).
- Architectural footprint: still ~10-15 Go files, single author, no tests.

## Activity Snapshot

- **No issues, no PRs.** Author still works on `main` directly.
- **36 commits total** (was 27 at last check; +9 in 11 days).
- Direction: consolidation toward multi-agent platform support via MCP +
  agentinfo, plus migration infrastructure for in-the-wild DBs.

## Pending Review

(none — all 2026-05-07 items triaged below)

## Issued

- `personality-canary-light` — agent_workspace #168 (2026-04-26).
  Adopted at light layer: an agent codename + 5-trait tone, written as a
  `user_agent_personality` entry in the then-active project's auto-memory
  (project-scoped; the specific codename and file path live with that
  project, not the workspace — see issue #217). 30-day revisit
  (~2026-05-26) to evaluate whether the light layer earns its keep or
  escalation/deletion is warranted.

## Skipped

### 2026-04-26 decisions

- `memory-dump-load-pattern` — Marginal value; git already provides
  cross-machine portability for the auto-memory directory.
- `tool-use-event-log` — No stated pain; we don't currently need a
  per-session "what files did this touch?" summary.
- `engram-binary-adoption` — Conflicts with our existing markdown-based
  auto-memory setup. The patterns are portable as concepts; the binary
  is not.
- `hooks-integration` — Would conflict with existing hooks in
  `.claude/settings.json`. Engram's bootstrap explicitly warns about
  duplicate hook configuration as a footgun.

### 2026-05-07 decisions

- `agentinfo-command-pattern` — Engram's "tool prints its own usage"
  pattern. This workspace already gets the portable insight via CLAUDE.md →
  `@AGENTS.md` referencing; no new helper needed.
- `db-migration-system` — Engram's schema-evolution support for SQLite
  DBs. Markdown-based memory has no schema to migrate; pattern is N/A.

## Deferred

- `short-term-stack-workflow` — Push/pop conventions for nested digressions
  (engram's "save context, brainstorm, resume" pattern). Deferred
  2026-04-26, re-confirmed 2026-05-07 and 2026-07-14 (tier model unchanged
  upstream; no local pain). Pairs with `tier-by-durability-axis`.
  Resurface paired.
- `tier-by-durability-axis` — `durability:` frontmatter field
  (`short`/`long`/`permanent`), orthogonal to existing `type:`. Deferred
  2026-04-26, re-confirmed 2026-05-07 and 2026-07-14; without the stack
  workflow there's no use case for a `short` value. Resurface paired.
- `engram-mcp-server` — **Closed 2026-07-14 as obsolete**: upstream
  removed the experimental MCP surface (gated behind a CLI-viability
  check) and went hook-parity + AGENTS-fallback for Codex/Gemini instead.
  The local trigger condition (running non-Claude agents against this
  workspace) never fired either.
