# Inspiration Digest: engram

Type: inspiration
Last checked: 2026-09-14
Repo: shiblon/engram @ 2050c00b1ef66cc3e432d7a7a6b21907a2eb0f21
Previously checked: 2026-07-14 @ 243fb2c; 2026-05-07 @ 125f1d4; 2026-04-26 @ a4c577c

## Changelog (2026-07-14 → 2026-09-14)

48 commits (243fb2c..2050c00), v0.11.2 → v0.16.0, ~90 files touched.
Still no issues; the first three PRs ever (#1–#3, all self-authored
feature branches) show the author moving off direct-to-main. A Go CI
workflow (`.github/workflows/test.yml`) now runs on push and PR, so the
"no CI on PRs" survey line is stale too. Two new design documents
(`docs/design-notes.md` additions, `docs/dispatch-notes.md`) carry most
of the portable thinking this round.

### Experiments with exit conditions (most portable governance idea)

New `engram experiments` registry (`pkg/engram/experiments.go`): every
non-stable feature must declare a hypothesis, the surfaces that may
change, **the event that promotes it**, and **the event that removes
it** — "conditions name observable events rather than dates." Tests fail
if a registered experiment has no labeled CLI command or vice versa, and
minor-release prep must review every entry (promote / continue /
deprecate / remove). `skill-discovery` was promoted this round;
`curation-log`, `dispatch`, `guidance-reads` stay experimental with the
v0.16.0 review recording *why*.

- **Workspace relevance**: High, and directly relevant to the #172
  redesign. Project-type adapters, the multi-tenant registry, per-project
  manifests and role/distro variants are each a trial. An "experimental"
  ADR/status with named promote/remove events (e.g. "a second project
  type lands without touching the dispatcher") is a lighter-weight
  commitment than shipping them as settled architecture, and gives
  `/audit-workspace` something mechanical to check.

### Policy kernel + on-demand topic bodies (guidance restructure)

v0.16.0 unified all agent guidance behind one topic registry. Init files
(CLAUDE.md / AGENTS.md / GEMINI.md …) now carry a ~5.5 KB **policy
kernel** whose entries have explicit `WHEN` / `DO` / `READ` / optional
`BOUNDARY` fields; `engram agentinfo <topic>` loads a full body on
demand. Recognition is by condition, "without relying on magic
keywords." An experimental `agentinfo stats` histogram counts which
topic bodies actually get loaded per release, to find dead or
under-routed guidance ("evidence for deciding which policy belongs
eagerly in the kernel").

- **Workspace relevance**: Medium-High. AGENTS.md is already the kernel
  and `.agent/knowledge/` the bodies, but the rule entries are prose, not
  WHEN/DO/READ/BOUNDARY, and nothing measures which knowledge files are
  ever read. For #172's role/distro variants this suggests: one shared
  kernel + per-variant topic bodies, rather than per-variant instruction
  files that drift.

### Memory consolidation rule

v0.15.x bootstrap guidance adds a "Memory consolidation" section: before
writing a memory, notice when it contradicts or duplicates one already
in context, *surface* that instead of appending, and harmonize with the
user into a replacement that retires the old entry. User feedback about
the consolidation process itself goes to a memory entry the bootstrap
never regenerates, so refinements survive re-bootstrap. v0.15.1 fixed
the rule reaching only Claude — "a shared constant referenced by both
documents."

- **Workspace relevance**: Medium-High. Our auto-memory MEMORY.md index
  has no anti-drift rule; entries accumulate. A one-paragraph rule in the
  memory instructions is cheap. The "shared constant so two rendered
  documents can't drift" lesson also applies to CLAUDE.md vs the other
  framework adapter files.

### Dispatch: multi-provider fan-out (experimental) — lessons for review tooling

`engram dispatch` fans a decomposed task out to provider CLIs (claude,
codex) as child processes, joined by one supervisor: no daemon, no
schema, JSON-Lines status stream, per-child deadline and process group.
`docs/dispatch-notes.md` (659 lines) is the interesting artifact. Findings
measured against real CLIs:
- **Read-only is the default authority** and must be a closed set; a
  typo passed straight through as `--sandbox danger-full-access`.
- **Plan mode is not read-only**: claude's `--permission-mode plan`
  *redirects* writes to plan files, costing an 8-child review batch its
  output. Read-only became `--permission-mode dontAsk --disallowedTools
  "Edit Write NotebookEdit"`, canaried per probe.
- **A flag the provider accepts is not a flag it enforces** — codex
  echoed `sandbox: read-only` then wrote a file anyway.
- **Context load dominates cost**: 36,888 cache-creation tokens with no
  suppression vs 3,693 with `--setting-sources local` for a 9-word prompt.
  And the `user` rung is not isolation: a child asked its codename
  answered with the *parent operator's* codename.
- **Slicing destroys the seams / fan-out amplifies false positives** —
  always keep one child on the whole change at higher altitude; the
  per-slice prompt must explicitly license silence.
- Provider invocation recipes are **learned and probed, not compiled in**
  (argv arrays with placeholders, stored with provenance + help digest;
  "learning must probe, not believe"; model verified from CLI output
  metadata, never by asking the child).
- The test-quality reviewer found "tests that could not fail"; the
  security reviewer found four child-output hazards. Both were found by
  *reviewing dispatch with dispatch*.

- **Workspace relevance**: High for `cross_model_review.sh` and the
  `review-code` / `triage-reviews` skills, which already fan out to
  specialist reviewers and to Codex/Gemini. The authority, plan-mode,
  context-suppression, whole-change-reviewer and license-silence findings
  are directly checkable against our scripts. Not a port of dispatch.

### Multi-tenant scoping details (convergent with #172)

Items that don't need porting but validate design choices in the
redesign: bootstrap is **global by default so a forgotten flag cannot
dirty the current repository** (`--project` is explicit); linked
worktrees read the main checkout's database and "do not create a second
`.engram` inside the linked worktree"; the project manifest (`register
--list/--forget/--purge`) is keyed path-first so evicting one working
copy leaves sibling clones alone; identity is global-only, behavior
(preferences) may be global or project-scoped, "inject merges both,
global first." A new design note, **"Durable state is not automatically
memory"** (would it travel to another machine? does it shape agent
behavior? would a human curate it? — three noes means it is state, put
it in a table not a tier), is a useful test for what belongs in a
registry vs a knowledge doc.

- **Workspace relevance**: Medium for #172 — no new direction, but the
  explicit-scope default and the state-vs-knowledge test are worth
  citing in the design.

### Bootstrap `--dry-run` / `--diff`

Every bootstrap provider can preview writes as unified patches, with
unchanged targets shown as empty patch headers, then one accept/reject
prompt; reviewed files are revalidated before application.

- **Workspace relevance**: Medium. `/onboard-project` and the future
  per-project manifest generator (#172) write files into a project repo;
  a diff preview before writing is the same UX.

### Personality canary (open issue #168)

No change to the mechanism. Two relevant notes: `design-notes.md` now
states the principle as *"Identity is full and redundant; everything
else is a summary … never make identity depend on a single channel being
present"*; and the dispatch probe showed identity leaking into
subagents through user-level CLAUDE.md, so a subagent that "knows the
codename" says nothing about its own context health. Worth a comment on
#168 when the 30-day light-layer evaluation happens.

### Misc

`mem edit` in `$EDITOR`; copyable `engram:/tier/key` addresses; compact
`list`/`search` by default with `--limit`/`--full`; canonical tier
enforcement with alias normalization at migration; append-only
`curation_events` log (capture only, no consumer yet); Debian packaging;
"a local build no longer claims to BE the release" (Go stamps
pseudo-versions, and stamps no `vcs.*` at all when building from a
linked git worktree — a worktree gotcha worth knowing).

## Pending Review (2026-09-14 round)

- `experiment-registry-exit-conditions` — experimental features must
  declare hypothesis + promote/remove *events*; registry checked by
  tests; minor-release review of every entry. Candidate for #172's
  adapters/registry/manifests/variants and for `/audit-workspace`.
  (2026-09-14)
- `policy-kernel-topic-bodies` — WHEN/DO/READ/BOUNDARY kernel in the
  init file + on-demand topic bodies + body-load histogram. Candidate
  shape for AGENTS.md vs `.agent/knowledge/` and for #172 role/distro
  variants (shared kernel, per-variant bodies). (2026-09-14)
- `memory-consolidation-rule` — surface contradictions/duplicates before
  writing a memory instead of appending; refinements live outside the
  regenerated file. Candidate rule for auto-memory MEMORY.md
  instructions. (2026-09-14)
- `dispatch-review-fanout-lessons` — read-only default authority as a
  closed set; plan mode redirects writes; accepted ≠ enforced; context
  suppression numbers; keep one whole-change reviewer; license silence.
  Candidate audit of `cross_model_review.sh` / `review-code`.
  (2026-09-14)
- `bootstrap-dry-run-diff` — unified-patch preview + accept/reject before
  writing files into a project repo. Candidate for `/onboard-project`
  and #172 manifest generation. (2026-09-14)
- `explicit-scope-default` — global-by-default so a forgotten flag can't
  dirty the current repo; worktrees share the main checkout's store;
  "durable state is not memory" test. Convergent validation for #172;
  likely cite-and-skip. (2026-09-14)
- `identity-redundant-surfaces` — "never make identity depend on a single
  channel"; subagents inherit the parent's codename via user-level
  instructions, so the canary is per-session, not per-agent. Note for
  #168. (2026-09-14)
- `automation-catalog-digest-verdicts` — skill/automation discovery
  stores one judgment per candidate with its content digest; changed
  candidates keep prior verdict pending confirmation, removed ones need
  explicit retirement. Parallels `/skill-importer`, `/analyze-permissions`
  and `/audit-project`. (2026-09-14)

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
