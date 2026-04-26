# Inspiration Digest: engram

Type: inspiration
Last checked: 2026-04-26 (first run)
Repo: shiblon/engram @ a4c577c25872c74567343faa55b93c7c7b43c8df

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

Note: this is a *durability* axis. Daddy_camp's existing memory uses a
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
  scoped (similar to daddy_camp's per-project memory dir under
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

| Interest area | What engram does | Daddy_camp delta |
|---|---|---|
| Stack-based short-term memory | `short` tier holds "in-flight context, conversation stack, backlog." Workflow says push current context before digression, pop on resume. The *tool* doesn't enforce stack semantics — it's prose-encoded in the global `engram-workflow` invariant. | We'd add this as a workflow convention in CLAUDE.md/AGENTS.md without needing tooling. |
| Personality as context-decay canary | `codename` invariant + status-line render. When status line drops the codename, context is breaking down. | Adoptable as a memory entry + lightweight status-line addition. |
| Multi-layer memory architecture | Two DBs (global + project), four tiers per DB. | We have global memory (CLAUDE.md ish) + per-project memory dir, but no tier-by-durability axis. |
| Tool-driven memory management | Cobra CLI subcommands; agent shells out instead of editing files. | Doesn't fit our model; we already have file-based markdown that the agent can edit directly via Write/Edit. |
| Memory dump/load for portability | `engram mem dump` / `mem load` to/from markdown. | We get this implicitly via git-checked memory directory. |
| Bootstrap UX | Single command sets up CLAUDE.md, hooks, gitignore, global invariants. | Compelling pattern but irrelevant unless we adopt the binary. |

## Activity Snapshot

- **No issues, no PRs.** Author works on `main` directly.
- **27 commits total** since project inception (recent: bootstrap polish,
  CLI ergonomics, README tightening, GoReleaser fixes).
- Activity reads as personal-project iteration, not a maintained library.
- Single contributor (`shiblon` aka Chris Monson).

## Pending Review

- `personality-canary` — Adopt a "codename" or designated identity memory
  that's expected to be present in context; pair with a small visual signal
  so its absence is obvious. Workflow change + 1 memory entry; possibly a
  status-line tweak. Aligned with stated user interest.
- `short-term-stack-workflow` — Adopt push/pop conventions for nested
  brainstorm/digression contexts. Document in CLAUDE.md/AGENTS.md; uses
  existing memory mechanism. No new tooling.
- `tier-by-durability-axis` — Add a `durability:` field to memory frontmatter
  (e.g., `invariant`, `preference`, `long`, `short`), orthogonal to existing
  `type:`. Lets us mark experimental notes as `short` so they don't pollute
  long-term context. Schema change; mild migration cost.
- `memory-dump-load-pattern` — Formalize export/import scripts even though
  git already gives us this. Marginal value; arguably skip.
- `tool-use-event-log` — Skip; we don't have the pain.
- `engram-binary-adoption` — Skip; conflicts with existing markdown setup.
- `hooks-integration` — Skip; would conflict with existing hooks in
  `.claude/settings.json`.

## Roadmapped

(none yet)

## Skipped

(none yet)

## Deferred

(none yet)
