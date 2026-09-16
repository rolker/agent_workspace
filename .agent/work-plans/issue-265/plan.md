# Plan: Step 5 — hosted projects anywhere, project-rooted sessions via the user tier (design B)

## Issue

https://github.com/rolker/agent_workspace/issues/265

Revision 2 (2026-09-16; review findings 1–9 applied the same day). Replaces the `projects/`-centred draft (revision 1,
2026-09-15). Direction and decisions: issue comments of 2026-09-15 (owner
direction) and 2026-09-16 (superseding brief). Evidence: `spike-results.md`
beside this file (Claude Code 2.1.273).

## Context

Today a project is hosted under the workspace tree (`projects/<name>/` via
the registry, or the legacy `project/` symlink) and every session — workspace
work and project work alike — starts in the workspace checkout. Worktrees for
both kinds of work live under `<ws>/worktrees/`. This couples three things
that want to be separate: where a project's checkout lives, which repo a
session is "for", and how the workspace's skills, hooks and rules reach a
session.

Design B decouples them. Projects live anywhere on disk and are known to the
workspace only through the registry. Workspace sessions start in the
workspace checkout; project sessions start in the project root. The workspace
layer reaches project sessions through Claude Code's user tier (`~/.claude/`),
gated on the registry so unrelated repositories see nothing. Worktrees live
under whichever root owns them.

### Why revision 1 (design A) was set aside

Revision 1 kept `projects/<name>/` under the workspace so that a project
session would inherit the workspace `CLAUDE.md`/`AGENTS.md` by ancestor
walking, and proposed bind mounts for out-of-tree checkouts. Two findings
removed its advantage:

- **Ancestor walking does not cross a git worktree boundary.** A session
  launched inside `<project>/worktrees/x` sees only that worktree's
  `CLAUDE.md`, and nothing when it has none (spike, experiment 6). Any
  session resumed inside a worktree — the normal case after a restart —
  loses the project layer under *both* designs. Both designs therefore need
  the SessionStart hook, and once the hook injects the layers, ancestry buys
  nothing.
- **Skills, hooks, commands and settings are launch-dir only** (revision 1
  already documented this). Design A left project sessions "instructions
  only". Design B gives them the workspace skills and hooks through the user
  tier, which the spike verified works.

What design A retains is a working implementation of hosting. Design B's
hosting half is the same registry with absolute paths (`gz4d` at
`~/src/gz4d` already uses it); the new parts are the user tier and
worktrees-in-root.

### Decisions (owner, 2026-09-16)

1. **Worktrees live under each root**, default `<root>/worktrees/`, with an
   optional per-project override in the registry. The workspace's own
   worktrees stay at `<ws>/worktrees/workspace/`. The workspace writes the
   exclusions (`.git/info/exclude` for repos it does not own; a
   `COLCON_IGNORE` marker in `worktrees/` for ros2_colcon roots).
2. **Separate session roots.** Workspace work runs from the workspace
   checkout, project work from the project root. `--type` becomes derivable
   from cwd (kept as an override). Issue/PR targeting follows the session
   root. A project change that needs a workspace fix is two sessions and two
   PRs, as the owning-repo rule already requires.
3. **The workspace tree hosts no project.** `project/` symlink, `projects/`
   hosting dir and the bind-mount idea are retired. The registry is the only
   link.
4. **The workspace layer reaches project sessions through the user tier.**
   A registry-gated SessionStart hook injects the workspace layer *and* the
   project layer for any cwd under a registered root, and stays silent
   elsewhere. Skills are symlinked into `~/.claude/skills/` as a generated,
   curated subset. Hooks and permission rules use absolute paths. Workspace
   sessions need nothing new.
5. **Memory attaches to the project root.** Sessions launch at the root, so
   auto-memory groups per project; a ros2_colcon *project* (e.g.
   `~/project11`) is the memory unit, not its distro instances.
6. **Registration is a workspace script** with one always-available
   bootstrap command in the user tier as the only exception to stand-down.
   Registration never creates a diff in a repo the workspace does not own.
7. **Cross-framework parity (Codex, Gemini) is low priority**; recorded, not
   planned.

### Spike evidence (Claude Code 2.1.273, see `spike-results.md`)

| # | Question | Result |
|---|---|---|
| 1 | Skills via symlinked dirs in `<config>/skills/` | PASS — listed by name |
| 2 | Registry-gated SessionStart hook | PASS — stdout lands in context verbatim under a registered root; silent elsewhere; ~5 ms |
| 3a | Absolute-path user-tier PreToolUse hook | PASS — fires from a project cwd |
| 3b | Tool-mapping hook stand-down | By inspection — needs a registry guard before its pattern checks |
| 3c | Workspace `settings.json` rules do not leak | By documentation — project settings load only for that directory |
| 4 | Adapter cwd discovery | PASS — `<root>/worktrees/x` resolves to `<root>` by ancestry |
| 5 | Nested worktree exclusion | PASS — `git status` clean with `.git/info/exclude`; `colcon list` ignores with `COLCON_IGNORE` |
| 6 | Project `CLAUDE.md` vs nested worktree | PASS with caveat — in-session `cd` keeps the launch-dir file; a session launched inside the worktree gets nothing from the parent |
| 7 | One root variable | PASS — 11/20 skills and both hook commands are cwd-relative; a hook-exported root variable is the missing piece |
| 8 | Context cost | ~5,500 tokens/session for an unconditional import in every repo; ~0 for the gated hook |

## Approach

### 1. Registry schema (`.agent/projects.local`)

Extend the whitespace-separated line format additively (unknown columns are
an error today; the parser in `_project_registry.sh` gains named `key=value`
trailing fields so existing three-column lines keep working):

```
# <name>  <type>  <path>  [key=value ...]
gz4d         single_project  /home/roland/src/gz4d
p11          project         /home/roland/project11-ng        default_instance=p11-rolling   # parent root: session/memory unit, no adapter
p11-jazzy    ros2_colcon     /home/roland/project11-ng/jazzy  parent=p11 distro=jazzy   role=dev
p11-rolling  ros2_colcon     /home/roland/project11-ng/rolling parent=p11 distro=rolling role=dev
```

- `parent=<name>` declares an instance of a parent root. The parent line
  has pseudo-type `project` (no adapter; `validate_adapter.sh` is not
  affected because it is not a project type directory). Parent roots exist
  so the hook, memory and per-project instructions have a single root for a
  multi-instance project; instances stay the build/worktree unit.
- `worktrees=<path>` overrides the default `<path>/worktrees/`.
- `default_instance=<name>` (parent lines only) names the instance used
  when a parent root is selected without `--project`.
- `role=` and `distro=` are passed through to the adapter as
  `ACTIVE_PROJECT_ROLE` / `ACTIVE_PROJECT_DISTRO`; ros2_colcon uses `distro`
  now (replacing `ROS_DISTRO` in `projects.d/<name>.sh` as the primary
  source), `role` once #267's resolver lands. `single_project` ignores both.
- Resolution rule for a cwd: the **longest registered path that is a
  prefix** of the physical cwd. `~/project11-ng/jazzy/worktrees/x` → `p11-jazzy`;
  `~/project11-ng` → `p11`. The adapter's `--from` discovery and the hook share
  one implementation (`_project_registry.sh: registry_resolve_from_dir`, which already does
  longest-prefix ancestor matching). New parser work is limited to accepting
  `key=value` trailing fields (any extra field is a hard parse error today)
  and dropping the `projects/<name>` default path.
- `registry_worktree_dir <name>` is the single source for where a root's
  worktrees live; every script that today walks `<ws>/worktrees/` calls it.
  **Transition rule (PR 2 → PR 4):** for a project that has no registry
  entry (legacy `project/` symlink only), it returns today's
  `<ws>/worktrees/project/<repo>/` so nothing breaks mid-rollout; a test
  covers the no-entry case. PR 4 removes the fallback together with the
  symlink support.

### 2. User-tier layer (install, hook, skills, permissions)

**Install/verify script** `.agent/scripts/user_tier_install.sh` (idempotent;
`--check` mode wired into `make validate`):

- `~/.claude/hooks/agent-workspace-session-start.sh` → symlink to
  `<ws>/.claude/hooks/session_start_project_layer.sh` (new).
- `~/.claude/settings.json`: adds (merges, never overwrites foreign entries)
  a `SessionStart` hook entry and a `PreToolUse` entry for the tool-mapping
  hook, both by absolute path; adds the workspace's script allow-rules
  rewritten with absolute paths (see permissions below). Entries carry an
  `"_agent_workspace": "<ws path>"` marker so `--check` and uninstall find
  exactly their own entries.
- `~/.claude/skills/<name>` → symlinks for the curated subset (below).
- `~/.claude/commands/register-project.md` → the bootstrap command
  (decision 6). It calls `<ws>/.agent/scripts/register_project.sh --path
  "$PWD"` and tells the user to relaunch.
- `--check` reports every missing/stale/foreign-owned entry; exit non-zero
  on drift. Two machines (dev, ROS) run the same script; drift is not
  silent.

**SessionStart hook** `.claude/hooks/session_start_project_layer.sh`:

1. Resolve `$PWD` against the registry (longest-prefix). Not under a root →
   exit 0 with no output (measured ~5 ms).
2. Under a root → print, in order: a header naming the project/instance,
   `export AGENT_WORKSPACE_ROOT=<ws>` guidance (as text: "workspace scripts
   live at <ws>/.agent/scripts; call them by that absolute path"), the
   workspace layer, then the project layer.
   - **Workspace layer content**: `AGENTS.md` sections that apply to project
     work (Boundaries, Communication, Quality, Tool Usage, Worktree
     Workflow, Issue-First, AI Signature, GitHub CLI patterns, Post-Task
     Verification) — rendered from `AGENTS.md` by section heading list, not
     a second copy. Skipped: Terminology's `project/` wording (rewritten in
     #259), Script Reference table (replaced by the root pointer), Build &
     Test (replaced by the project layer). This is the #259 split done at
     render time; #259 later makes the file itself match.
   - **Project layer content** (rendered by the hook from adapter/registry
     data, not a file the project must carry): project name, type, root,
     parent/instances, `adapter --project <name> build|test|env|validate`
     commands, where issues live (`scope_for_pr` output), the worktree dir,
     and — if present — the project's own `<root>/.agent/CLAUDE.md`
     verbatim (a project may carry conventions; the workspace never writes
     that file).
3. Also print `WORKTREE_TYPE=project` / `PROJECT=<name>` lines so
   `/start-task` can default `--type` and `--project` from the session.
   **Parent-root rule (owner, 2026-09-16):** the two-instance layout is a
   transition state (the shared-source model of #267 makes the distro a
   build parameter and removes the question), and day-to-day sessions
   launch in the instance being worked on (`~/project11-ng/rolling`), so
   the rule stays minimal. When the resolved root is a parent, the hook
   prints `PROJECT=<parent>` plus `INSTANCES=<a,b,...>`. Scripts never
   prompt: `worktree_create.sh` with a parent selected and no
   `--project <instance>` uses the parent's `default_instance=` registry
   field if set, else the only instance if there is one, else errors
   listing the instances. `/start-task` passes the error through as an
   `AskUserQuestion` over the listed instances. The dispatcher's existing
   "no adapter for project type 'project'" error stays as the backstop for
   direct calls.

The heading list the renderer keys on is pinned by a test
(`tests/test_session_start_layer.sh`) that asserts every keyed heading
exists verbatim in `AGENTS.md` and fails loudly on drift, so a section
rename cannot silently drop content (ADR-0006: render, never fork; and
"enforcement over documentation").

Rendering happens on every session start; budget: keep the injected
workspace layer under ~3,000 tokens (measured in the PR; the unconditional
import baseline is ~5,500).

**Tool-mapping hook** gains the same registry guard before its pattern
checks: outside a registered root *and* outside the workspace checkout it
exits 0 immediately. Same for `log-tool-use.sh` (log only inside roots).

**Curated skill subset** — `make generate-user-tier-skills` writes the
symlink list from a frontmatter field `session_scope: project | workspace |
both` in each `SKILL.md` (default `workspace`). Initial assignment:

| Scope | Skills |
|---|---|
| both | start-task, plan-task, review-plan, review-code, triage-reviews, test-engineering, what-next |
| project | document-project, audit-project, onboard-project |
| workspace | audit-workspace, analyze-permissions, brainstorm, inspiration-tracker, research, gather-project-knowledge, issue-triage, review-issue, skill-importer, brand-guidelines |

`/make_*` generated commands are workspace-only (they assume the workspace
Makefile). `merge-pr` (#191) is `both` when it lands.

**Permissions** — of the 101 allow rules in `.claude/settings.json`, only
those naming workspace scripts move to the user tier, rewritten to absolute
paths (`Bash(<ws>/.agent/scripts/*)`, `Bash(source <ws>/.agent/scripts/*)`).
Generic read-only rules (`git status`, `gh pr view`, …) are *not* installed
globally; they stay project-scoped and a project may copy them into its own
`.claude/settings.json`. Rule of the user tier: **only entries that are
inert outside registered roots** (absolute-path scripts that themselves
check the registry, hooks that stand down). Global hooks run in every repo,
including untrusted clones, so nothing installed there may act on repo
content without the registry check.

**Scripts promoted to the user tier must enforce that rule themselves.**
Today `gh_create_pr.sh`, `gh_create_issue.sh`, `merge_pr.sh`,
`fetch_pr_reviews.sh`, `update_roadmap.sh`, `cross_model_review.sh` and
the worktree scripts resolve their target repo from the caller's cwd with
no registry awareness; a global no-prompt allow-rule for their absolute
path would let a session in an untrusted, unregistered repo run them
against that repo's remote. Therefore:

- `_project_registry.sh` gains `require_registered_root [dir]`: exits
  non-zero with a one-line reason unless `dir` (default `$PWD`) is under a
  registered root or under the workspace checkout itself.
- The user-tier allow-list is **generated from a manifest**
  (`.agent/user_tier_scripts.txt`) listing exactly the scripts promoted.
  Initial list: `worktree_create.sh`, `worktree_enter.sh`,
  `worktree_remove.sh`, `worktree_list.sh`, `merge_pr.sh`,
  `gh_create_pr.sh`, `gh_create_issue.sh`, `fetch_pr_reviews.sh`,
  `cross_model_review.sh`, `build.sh`, `test.sh`, `adapter`,
  `dashboard.sh`, `register_project.sh`, and the sourced helpers
  (`set_git_identity_env.sh`, `_issue_helpers.sh`,
  `_resolve_work_plans_dir.sh`) — the sourced helpers are inert (they set
  variables/functions) and are exempt from the guard by an explicit
  `# user-tier: inert` marker that the test recognises.
- Every non-inert script on the list calls `registry_require_root` before
  any repo-affecting action. A test (`tests/test_user_tier_guard.sh`) runs
  each listed script from a sandbox unregistered git repo and asserts it
  refuses with the guard's message and touches nothing; it also fails if a
  script is on the list without either the guard call or the inert marker.
- `user_tier_install.sh --check` verifies install state; the guard test
  verifies behaviour. Both run under `make validate`.

### 3. Scripts: cwd-relative → root-resolved

- `_worktree_helpers.sh` gains `workspace_root()` (from `BASH_SOURCE`, as
  scripts already do) and every generic script uses it; no script assumes
  `$PWD` is the workspace.
- The 11 skills that reference `.agent/scripts` relatively are rewritten to
  `${AGENT_WORKSPACE_ROOT:-.}/.agent/scripts/...` (hook supplies the value
  in project sessions; workspace sessions resolve `.`). A test
  (`tests/test_skill_paths.sh`) fails on any new relative `.agent/scripts`
  or `.claude/hooks` reference in `SKILL.md` or `settings.json`.
- `/start-task` defaults `--type` and `--project` from the hook's
  `WORKTREE_TYPE`/`PROJECT` lines when flags are absent; explicit flags win.

### 4. Worktrees under the root

- `worktree_create.sh`/`enter`/`remove`/`list`, `merge_pr.sh`,
  `dashboard.sh`: replace the `<ws>/worktrees/project/<repo>/` walk with
  `registry_worktree_dir` per registered root; enumeration iterates the
  registry (plus the workspace's own root). All must work from a project
  cwd (no `$PWD`-is-workspace assumption; covered by the hermetic tests
  with a sandbox registry).
- On first worktree creation in a root: append `worktrees/` to
  `<root>/.git/info/exclude` if the root is a git repo and the line is
  absent; for ros2_colcon roots write `<root>/worktrees/COLCON_IGNORE`.
  Idempotent; never touches tracked files.
- Package worktrees (ADR-0012) keep their `.worktree-repos` manifest; only
  their location changes. `p11-jazzy` layout: `~/project11-ng/jazzy/worktrees/
  issue-<N>/` beside `layers/` and `configs/`.
- Unregister (`register_project.sh --remove <name>`) refuses while the root
  has live worktrees, listing them.

### 5. Registration and migration

- `register_project.sh --name --type --path [--parent --distro --role
  --worktrees]`: validates, appends the registry line, runs `adapter setup`
  for the type, writes the exclusions, prints the relaunch hint. Type
  auto-detection when `--type` is omitted: `configs/manifest/` or a
  bootstrap URL → `ros2_colcon`, else `single_project`.
- Migration on this machine: `gz4d` unchanged (already out-of-tree);
  `p11-jazzy`/`p11-rolling` re-registered at `~/project11-ng/<distro>` with a
  parent `p11` (`-ng` while the fork's `~/project11` stays in production on
  the ROS machine; renamed to `~/project11` at cutover — a registry path
  edit only. Auto-memory is keyed by path and is deliberately **left
  behind**: the workspace and each project must stand on their own, so
  anything load-bearing learned during testing is promoted into
  repo-tracked docs (`.agent/knowledge/`, the project's own `.agent/`
  files) before the rename, and the memory directory starts empty), hosting dirs moved (or re-bootstrapped with `adapter setup`
  from the existing `projects.d/*.sh` URLs). `projects/` and `project/`
  removed from the workspace tree; the dispatcher's legacy fallback, the
  `projects/<name>` default path and `migrate_legacy_project.sh` from
  revision 1 are dropped rather than deprecated — with the registry as the
  only link there is nothing left to warn about. `validate_workspace.py`
  fails if `project/` or `projects/` exists.
- `AGENTS.md` Terminology/Build & Test wording that says "in `project/`" is
  updated (Ask-First item; separate commit, owner approval on the PR).

### 6. Acceptance test (definition of done for step 5)

Run on this machine against **`gz4d` with real issues from its tracker**,
launched at `~/src/gz4d`:

1. Session start shows the workspace + project layers (hook), skills listed
   include `start-task`, `review-code`; unrelated repo shows nothing.
2. `/start-task --issue <N>` with no `--type`: worktree created at
   `~/src/gz4d/worktrees/issue-<N>`, `git status` in `~/src/gz4d` clean,
   session cd'd in, project layer still visible.
3. `adapter build`/`test` from inside the worktree resolve `gz4d` by
   ancestry.
4. `/plan-task`, `/review-code --branch`, `gh_create_pr.sh` target
   `rolker/geozui4d` (or whatever `scope_for_pr` reports) from the worktree.
5. `make merge-pr PR=<N>` (invoked via `<ws>` absolute path from the project
   session, or `/merge-pr` if #191 has landed) merges, removes the worktree
   from under `~/src/gz4d`, syncs.
6. `user_tier_install.sh --check` and `make validate` pass before and after.

For **project11** the same cycle runs **on this machine, before cutover, in
parallel with ongoing project11 work in `ros2_agent_workspace`** — the fork
stays the production workspace until design B is fully tested here. The
project11 acceptance task is a real **"port to rolling" issue** on a package
repo: `p11-rolling` instance under `~/project11-ng/rolling`, package worktree
under the instance, first real Rolling build via the adapter, PR, merge. It
gates #262 (cutover); it is not a post-cutover check. Both cycles (`gz4d`,
project11) must pass before step 5 is called done.

The project11 cycle **does not depend on #267**: `adapter setup` bootstraps
`p11-rolling` from today's `rolling` manifest branch exactly as it did for
`projects/p11-rolling` (#248), and ROS Rolling is installed on this machine
(`/opt/ros/rolling`). What this plan must deliver for it is the
`~/project11-ng/<distro>` registration (PR 4) and worktrees under the
instance (PR 2); the port-to-rolling issue itself is opened on the package
repo when the cycle starts, and the first Rolling build is expected to
surface real porting work — that is the point of the test, not a
precondition of it.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_project_registry.sh` | `key=value` trailing fields; `parent`, `worktrees`, `role`, `distro`; `registry_worktree_dir` (with legacy fallback until PR 4); `registry_require_root` guard helper; drop `projects/<name>` default path (PR 4) |
| `.agent/projects.local.example` | New format, parent/instance example, no hosting-dir wording |
| `.claude/hooks/session_start_project_layer.sh` (new) | Registry-gated layer injection; `WORKTREE_TYPE`/`PROJECT` lines |
| `.claude/hooks/block-bash-tool-mapping.sh`, `log-tool-use.sh` | Registry guard, stand down elsewhere |
| `.agent/scripts/user_tier_install.sh` (new) | Install/`--check`/`--uninstall` for hooks, settings entries, skill symlinks, bootstrap command |
| `Makefile` | `user-tier-install`, `generate-user-tier-skills`; `validate` runs `--check` |
| `.claude/skills/*/SKILL.md` (11) | `${AGENT_WORKSPACE_ROOT:-.}` script paths; `session_scope` frontmatter on all 20 |
| `.claude/settings.json` | Hook commands by absolute path resolved at install (file keeps relative for workspace sessions; install rewrites into user tier) |
| `.agent/scripts/register_project.sh` (new) | Register/unregister, setup, exclusions, relaunch hint |
| `.claude/commands/register-project.md` (new, installed to user tier) | Bootstrap command |
| `.agent/scripts/_worktree_helpers.sh`, `worktree_create.sh`, `worktree_enter.sh`, `worktree_remove.sh`, `worktree_list.sh`, `merge_pr.sh` | `registry_worktree_dir`; registry iteration; exclusion writing; work from any cwd |
| `.agent/scripts/dashboard.sh` | Replace the hardcoded path-substring root classification and worktree counting (`*/worktrees/project/*`, `*/project/worktrees/*`, `*/.workspace-worktrees/*`, `*/worktrees/workspace/*`) with registry-driven enumeration of each root's worktree dir |
| `.agent/scripts/adapter` | Drop `project/` fallback; pass `ACTIVE_PROJECT_ROLE/DISTRO` |
| `.agent/project_types/ros2_colcon/adapter.sh` | `distro` from registry first, `ROS_DISTRO` config as fallback |
| `.agent/scripts/validate_workspace.py` | Fail on `project/`/`projects/`; call `user_tier_install.sh --check` |
| `.claude/skills/start-task/SKILL.md` | Default `--type`/`--project` from session lines |
| `.agent/scripts/tests/` | Registry parser cases (incl. `key=value`, parent/instance); worktree dir incl. legacy no-entry fallback; exclusion idempotency; hook silent/inject; heading-drift test; user-tier guard behaviour test; skill-path regression test; install `--check` drift |
| `.agent/WORKTREE_GUIDE.md`, `README.md`, `ARCHITECTURE.md` | Session roots, worktrees-in-root, user tier, registration |
| `AGENTS.md` | Terminology, Build & Test, Worktree Workflow wording (Ask First) |
| `docs/ROADMAP.md` | Step 5 row → #265 in progress; cutover row 1 → done; note step 4 re-scope (#267) |

## PR sequence

Additive, each independently mergeable and tested:

1. **Registry + resolution** (schema, `resolve_path`, `worktree_dir`, tests). No behaviour change for existing three-column lines.
2. **Worktrees under the root** (generic scripts, exclusions, dashboard/list iteration, tests). `gz4d` worktrees move on first use.
3. **User tier** (hook, install/check, skill scopes + generator, tool-mapping guard, permissions subset, register command, docs). Acceptance test steps 1–3.
4. **Retire hosting** (drop `project/`/`projects/` fallbacks, `register_project.sh`, migrate p11 instances, `AGENTS.md` wording, roadmap). Acceptance test steps 4–6.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Every cwd-relative reference is listed (11 skills, 2 hooks) and guarded by a regression test; every script that walks `worktrees/` is listed; unregister refuses with live worktrees |
| Workspace vs. project separation | The workspace never writes into a project checkout except `.git/info/exclude` and an untracked `COLCON_IGNORE`; project conventions live in the project's own file, read not written |
| Only what's needed | No bind mounts, no deprecation path, no per-type `CLAUDE.md` templates; the project layer is rendered from data the adapter already has |
| Improve incrementally | Four additive PRs; three-column registry lines keep working until PR 4 |
| The workspace serves the product | Project sessions get the same skills as workspace sessions; the test is a real `gz4d` issue end to end |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0011 (adapter contract) | Yes | No new verb. `ACTIVE_PROJECT_ROLE/DISTRO` are dispatcher-provided variables like `ACTIVE_PROJECT_*` today; `single_project` ignores them. The `project/` fallback removal changes the dispatcher's documented discovery order (registry only) — a substantive change by ADR-0008's test, so it is recorded in the new ADR below (which supersedes that part of ADR-0011's Decision), not as an addendum |
| ADR-0012 (worktree composition) | Yes | Package worktrees keep `.worktree-repos`; only `registry_worktree_dir` changes where they are created. No new verb |
| ADR-0006 (adapter files as thin routers) | Yes | The hook renders sections of `AGENTS.md`; it does not fork them. `CLAUDE.md` unchanged |
| New ADR: **session roots and the user tier** | Yes | Records decisions 2–6, the user-tier rule ("only entries inert outside registered roots") with its enforcement (guard helper + generated allow-list + behaviour test), the registry-only discovery order (superseding ADR-0011's legacy `project/` step), and the worktree-boundary finding that made ancestry insufficient. Status Provisional (roadmap's "ADR Provisional" item) until the acceptance test passes on the ROS machine |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Registry format | `dashboard.sh`, `validate_workspace.py`, `worktree_*` parsers, `projects.local.example`, hermetic tests' sandbox registries | Yes (PR 1) |
| Worktree location | `merge_pr.sh` cleanup, `worktree_list.sh --json` consumers, `.agent/WORKTREE_GUIDE.md`, `cross_model_review.sh --work-dir` default | Yes (PR 2); `cross_model_review.sh` verified in PR 2 |
| Skills reference `AGENT_WORKSPACE_ROOT` | Codex/Gemini adapter files (they have no hook) — document that non-Claude project sessions must export it manually | Yes, doc only (decision 7) |
| Hook renders `AGENTS.md` sections | #259 (trim `AGENTS.md`) must keep the section headings the renderer keys on, or update the list | Cross-reference on #259 |
| `distro` moves to the registry | `projects.d/p11-*.sh` `ROS_DISTRO` becomes fallback; ros2_colcon tests' config fixtures | Yes (PR 4) |
| `project/` removed | `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `onboard-project` and `gather-project-knowledge` skills that mention `project/` | Yes (PR 4); skills grep'd in PR 4 |
| Global hooks in every repo | User-tier rule in the new ADR; `--check` reports foreign entries | Yes (PR 3) |

## Open Questions

- **Project layer size.** Rendering the applicable `AGENTS.md` sections may
  still be ~3k tokens per project session. Acceptable now; #259 is the real
  fix. Measure in PR 3 and record.
- **Cross-session duplicate-spawn awareness** (roadmap item): with
  worktrees per root, "is someone already on this issue" is a per-root
  check; `worktree_create.sh` already refuses an existing worktree. Not
  extended here.
- **`CLAUDE_CONFIG_DIR` caveat** from the spike (a fake tier still saw the
  real user `CLAUDE.md`) is irrelevant to the design (the real tier is the
  target) but should be re-checked if the install script ever uses
  `CLAUDE_CONFIG_DIR` for tests.

## Estimated Scope

Four PRs (above). PR 1 and 2 are mechanical with hermetic tests; PR 3 is
the new surface (hook, install/check, skill scopes); PR 4 is removal plus
migration and the Ask-First `AGENTS.md` edit. Acceptance tests on `gz4d`
and on project11 (port-to-rolling, on this machine, before cutover) close
the issue.
