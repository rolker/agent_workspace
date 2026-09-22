# ADR-0016: Session Roots and the User Tier

## Status

**Provisional.** The promotion condition is the acceptance test named in
issue #317 — the full `/run-issue` loop driven from `~/src/gz4d` through
the merge checkpoint, on this machine. Until that run passes, the
mechanisms here are built and hermetically tested but not proven against a
live Claude Code session. Promote to Accepted when it does; revise here if
it does not.

## Context

Until now, every session started in the workspace checkout. `projects/<name>`
(or the legacy `project/` symlink) hosted the project *inside* the
workspace tree, and Claude Code loads skills, hooks and instructions from
the launch directory, so a session started at `~/src/gz4d` saw none of the
workspace layer: no skills, no `AGENTS.md`, no tool-mapping hook, no
`/run-issue`.

Issue #265 changes the arrangement: a project lives at its own root,
registered in `.agent/projects.local`, and a session may legitimately start
there. PRs 1 and 2 landed the registry (`registry_resolve_from_dir`,
`registry_require_root`, `registry_worktree_dir`) and moved worktrees under
each project's own root. This PR (3 of 4) builds the layer that makes such
a session equivalent to a workspace one.

The parent plan's spike (`.agent/work-plans/issue-265/spike-results.md`)
established the mechanism and its limits:

- A registry-gated user-tier `SessionStart` hook can inject both layers
  when the cwd is under a registered root, and stay silent elsewhere, at
  about 5 ms.
- User-tier skill symlinks are discovered by name.
- Absolute-path user-tier hooks fire from a project cwd.
- Ancestor walking does **not** cross a git worktree boundary, so
  `@`-imports from a parent directory cannot carry the project layer into
  a worktree. The hook can, because it is told the cwd.

## Decision

### 1. Separate session roots

The workspace and each project are separate session roots. A session is in
exactly one of them, determined by its cwd, resolved through the registry
by longest-prefix ancestor match. Registered project roots are checked
before the workspace checkout, so a project registered inside the workspace
tree is still a project.

### 2. The workspace tree hosts no project

A project's checkout lives at its own root. The workspace never writes into
a project checkout (beyond `.git/info/exclude` and an untracked
`COLCON_IGNORE`), and reads the project's own conventions from
`<root>/.agent/CLAUDE.md` rather than maintaining a copy.

### 3. The user tier injects the layers

`~/.claude` carries a `SessionStart` hook, `PreToolUse` hooks, permission
allow-rules and skill symlinks, installed from a workspace checkout by
`.agent/scripts/user_tier_install.sh`. The hook renders the workspace layer
from `AGENTS.md` sections and the project layer from registry data plus the
project's own agent guide.

### 4. Memory attaches to the project root

Per-project memory belongs at the project root, not in the workspace — the
workspace is project-agnostic (ADR-0003 as amended by ADR-0011), and a
project's notes have no business in it.

### 5. Registration is a workspace script

Adding a project to the registry is a workspace operation, not something a
project session does to itself. (`register_project.sh` and its bootstrap
command are PR 4 scope; `gz4d` is already registered, so PR 3 needs
neither.)

### 6. The user-tier rule

**An entry may be promoted to the user tier only if it is inert outside the
workspace checkout and outside every registered project root.**

A user-tier entry runs in every session on the machine, including sessions
in repositories that have nothing to do with the workspace. The rule is
what keeps that from being an imposition. It is enforced, not documented:

- `.agent/user_tier_scripts.txt` is the promoted set.
- Each entry calls `registry_require_root` before any repo-affecting
  action, or carries `# user-tier: inert` (it only defines functions and
  variables), or `# user-tier: guarded-by:<script>` (it is a shim that
  execs a guarded entry).
- `.agent/scripts/tests/test_user_tier_guard.sh` fails on an ungoverned
  entry, on a guard that does not precede the first repo-affecting `gh`/
  `git` call, and on any entry that does not actually refuse — or, for the
  two hooks, stay silent — when run from a sandbox repo registered nowhere.

The tool-mapping and tool-use-logging hooks are promoted under this rule
(owner decision, 2026-09-22), so project sessions keep the
Bash-to-dedicated-tools steering and the tool-use log, and an unregistered
repo gets neither.

### 7. The workspace root is a file, not an environment variable

`user_tier_install.sh` writes the workspace checkout's absolute path to
`~/.claude/agent-workspace-root` (one line, no trailing newline). Skills
that need a workspace script read it at the head of each command chain:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root)"
"$WS_ROOT/.agent/scripts/<script>" ...
```

This is deliberate, and it is the correction of a tempting mistake.
`SessionStart` hook stdout is **context text for the model** — it is not
environment. Nothing it prints reaches the fresh shell that a Bash tool
call runs in, so a hook that emitted `AGENT_WORKSPACE_ROOT=...` would
produce a variable that appears to exist and is never set. A file has none
of that ambiguity: it is readable whether or not the hook ran, needs no
sourcing, and survives between tool calls, which shell state does not.

The name is a file path rather than an env-var name on purpose, so nothing
implies the value is ambient.

Workspace **scripts** do not read this file at all. They already resolve
their own root `BASH_SOURCE`-relative, and they resolve the *project* by
calling `registry_resolve_from_dir` on their own `$PWD` — never by
trusting anything the hook printed. `dispatch_phase.sh --project` and the
worktree scripts' optional `--type` both work this way.

### 8. Hook output carries no machine-readable lines

Following from 7: the session layer prints no `KEY=value` line for a script
to parse. It is prose for the model. A test asserts the absence, so the
convenience of "just emit a variable" cannot creep back in.

## Consequences

### The #295 fold is revised

The 2026-09-18 decision on #265 folded #295 into this series. Its *first*
half — a pinned registry entry for the workspace itself, so "which root am
I under" is one registry lookup for workspace and project sessions alike —
**moves to PR 4** (owner decision, 2026-09-22), to land with #295's second
half, the `--type` special-case collapse. The entry's shape (a `worktrees=`
override, and which consumers must skip it) has exactly the
unspecified blast radius — `adapter --from` discovery, `dashboard.sh`
classification, `registry_worktree_dir`'s default — that the collapse work
needs to settle in one pass. Shipping the entry alone would commit to a
shape before that.

For PR 3 the workspace-vs-project decision therefore uses only what already
exists: `registry_require_root` and `registry_derive_type_from_dir` branch
on "cwd is under the workspace checkout", with no registry entry required.

### ADR-0011's discovery order will be superseded

ADR-0011 documents a discovery order that ends in a legacy `project/`
fallback. The end state of #265 is **registry-only** discovery, and this
ADR is where that supersession belongs (the parent plan says so, and
ADR-0008's test agrees: it is a substantive change to a recorded decision,
not a cross-reference).

It is recorded here **but not yet in effect**. PR 3 does not remove the
fallback — PR 4 does. ADR-0011 gets a navigational pointer to this ADR and
nothing more; an addendum now would describe a change that has not
happened.

### The layer is rendered from `AGENTS.md`, so headings are an interface

The workspace layer is rendered from a pinned list of `AGENTS.md` section
headings. A rename upstream would empty the layer silently — the session
would look normal and carry no rules.
`.agent/scripts/tests/test_session_start_layer.sh` reads the pinned list
out of the hook and asserts, per heading, that it exists verbatim, that the
extracted section is non-empty, and that extraction stops at the next
same-level heading. Issue #259 (trimming `AGENTS.md`) must keep those
headings or update the list.

### Multi-project machines need disambiguation

With several projects registered, "the one registered project" is not a
resolution strategy. `dispatch_phase.sh` gained `--project` and a
`$PWD`-derived fallback; the worktree scripts derive `--type`/`--project`
the same way. Without this, `/run-issue <N> --type project` fails at the
first dispatch on this machine, which has three registered projects.

### A second checkout is detectable, not silently merged

Every settings entry the installer writes is tagged
`"_agent_workspace": "<checkout>"`. That tag makes install idempotent,
makes `--check` able to distinguish our entries from the user's own and
from another checkout's, and makes `--uninstall` surgical.

### `--check` is quiet about absence

`user_tier_install.sh --check` runs in `make validate`. On a machine that
never installed the user tier it prints a one-line note and exits 0 — the
user tier is optional, and a fresh checkout or the ROS machine must not go
red for not having it. `--check --require` exits non-zero instead, for a
machine that expects it.

## Alternatives Considered

- **`@`-imports from a parent directory.** Rejected: spike 6 found ancestor
  walking does not cross a git worktree boundary, so a worktree under a
  project root would not see the layer. The hook is told the cwd and has no
  such blind spot.
- **A `AGENT_WORKSPACE_ROOT` environment variable spliced by the hook.**
  Rejected: hook stdout is context, not environment. See decision 7.
- **Copying workspace skills into each project checkout.** Rejected: the
  workspace would be writing into project checkouts, against decision 2,
  and every checkout would drift independently.
- **Promoting every workspace script to the user tier.** Rejected: each
  promoted entry costs a guard call and a test row, and carries a small
  risk of firing somewhere it should not. The manifest is trimmed to what
  the acceptance loop actually invokes.

## References

- [ADR-0011](0011-project-type-adapter-contract.md) — its `project/`
  discovery step is superseded by this ADR once PR 4 removes the fallback
- [ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md) — why the
  supersession content lives here rather than as an addendum on ADR-0011
- [ADR-0006](0006-adopt-agents-md-as-shared-instruction-file.md) — the hook
  renders `AGENTS.md` sections; it does not fork them
- [ADR-0012](0012-worktree-composition-is-an-adapter-concern.md) — package
  worktrees, unaffected except for where `registry_worktree_dir` puts them
- [ADR-0014](0014-in-process-phase-handoff.md) — `dispatch_phase.sh`, whose
  `--project` flag and `$PWD` derivation this ADR motivates
- Issue #265 (umbrella, design B), #317 (PR 3), #295 (folded, first half
  deferred to PR 4), #259 (`AGENTS.md` trim — keep the rendered headings)
- `.agent/work-plans/issue-265/spike-results.md` — the mechanism spike
