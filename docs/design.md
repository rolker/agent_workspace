# Architecture: General-Purpose Agent Workspace

## Overview

This workspace is a general-purpose multi-agent development platform. It hosts
external project repositories (the legacy `project/` symlink and/or named
projects under `projects/`) and provides the full agent infrastructure
needed to develop them safely: worktree isolation, governance, skills, hooks, and
multi-agent coordination.

## Directory Structure

```
agent_workspace/
├── .agent/
│   ├── scripts/           # All automation scripts
│   │   ├── lib/           # Python library modules
│   │   └── ...
│   ├── knowledge/         # Agent knowledge documents
│   ├── project_types/     # Project-type adapters (ADR-0011)
│   │   ├── single_project/  # adapter.sh + setup.sh + sync.py
│   │   └── ros2_colcon/     # adapter.sh — layered colcon workspaces (#235)
│   ├── project_config.sh  # PROJECT_TYPE / BUILD_CMD / TEST_CMD / INSTALL_CMD (gitignored, per-developer)
│   ├── projects.local     # Per-machine project registry (gitignored; see projects.local.example)
│   ├── projects.d/        # Per-project command configs, <name>.sh (gitignored)
│   ├── work-plans/        # issue-<N>/plan.md and progress.md (per-issue lifecycle timeline;
│   │                       # entry-type vocabulary is ADR-0013, docs/decisions/0013-progress-md-entry-type-vocabulary.md;
│   │                       # written via .agent/scripts/progress_append.sh, read via .agent/scripts/progress_read.py)
│   ├── work-artifacts/    # Generated outputs
│   ├── scratchpad/        # Temp workspace (gitignored)
│   ├── templates/         # Issue/PR/ADR templates
│   ├── hooks/             # Pre-commit hook scripts
│   ├── WORKTREE_GUIDE.md
│   ├── WORKFORCE_PROTOCOL.md
│   ├── AI_IDENTITY_STRATEGY.md
│   ├── AGENT_ONBOARDING.md
│   └── AI_RULES.md
├── .claude/
│   └── skills/            # Claude Code slash commands
├── .github/
│   ├── workflows/         # CI
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/
├── project/               # Gitignored — cloned or symlinked project repo (legacy shape)
├── projects/              # Gitignored — named project checkouts, projects/<name>/ (issue #227)
├── docs/
│   ├── design.md          # This file
│   ├── principles.md
│   └── decisions/         # Architecture Decision Records (ADRs)
├── scripts -> .agent/scripts  # Convenience symlink
├── CLAUDE.md              # Claude Code adapter
├── AGENTS.md              # Shared agent rules
├── README.md
├── Makefile
├── requirements.txt
└── .pre-commit-config.yaml
```

## Project Repository Model

Project-shape-specific behavior (setup, sync, build, test, install, environment,
repo enumeration, PR targeting, worktree composition) lives behind a 12-verb
adapter contract (ADR-0011, amended by ADR-0012).
`.agent/scripts/adapter [--from <dir>] [--project <name>] <verb>`
resolves the active project and dispatches to
`.agent/project_types/<type>/adapter.sh`. `validate_adapter.sh` (pre-commit + CI)
asserts every type implements every verb.

Two hosting shapes coexist during the #172 migration (issue #227):

- **Legacy**: the `project/` directory holds one external git repository —
  cloned (`git clone <url> project/`) or symlinked
  (`ln -s /path/to/existing/clone project`). `PROJECT_TYPE` comes from
  `.agent/project_config.sh` (default `single_project`).
- **Registry**: `.agent/projects.local` (per-machine, gitignored) maps
  project names to hosting dirs (anywhere on disk; default `projects/<name>/`)
  and project types, plus optional trailing `key=value` fields (issue #265):
  `parent=` groups instances under a **parent root** (pseudo-type `project`,
  no adapter — the session and memory unit for a multi-instance project such
  as one per ROS distro), `worktrees=` overrides where a root's worktrees
  live, `role=`/`distro=` reach the adapter as `ACTIVE_PROJECT_ROLE` /
  `ACTIVE_PROJECT_DISTRO`, and `default_instance=` names the instance a
  parent resolves to. Per-project build/test commands live in
  `.agent/projects.d/<name>.sh`, falling back to `.agent/project_config.sh`.
  See `.agent/projects.local.example` for the format.

The dispatcher resolves the active project in order: explicit
`--project <name>` (`make build PROJECT=<name>`), the caller's cwd inside a
registered hosting dir (longest match, so a cwd inside an instance resolves
to the instance rather than its parent), then the legacy `project/` shape. A
parent root resolves to its `default_instance`, else its only instance;
several instances without a default is an error that lists them. A machine
with only the legacy symlink behaves exactly as before.

The project's `remote.origin.url` (from `.git/config`) is the source of truth for the
project URL — no `configs/` directory is needed.

`validate_workspace.py` understands both shapes: legacy `project/` (valid git
repo with a remote) and registry entries (well-formed, known project type,
checkout present). Each registry entry's checkout shape is checked by its own
type — the validator delegates to `adapter --project <name> validate` and
reports every failure line prefixed `project '<name>':` — rather than by one
hard-coded `.git` test for every type (a `ros2_colcon` hosting dir has no
`.git` at its root). When `projects.local` has parse errors, delegation is
skipped (the dispatcher refuses every lookup then) and entries are only checked
for a present hosting dir. `make validate` runs this whole-workspace check;
`adapter --project <name> validate` checks that one project only.

Two project types exist: `single_project` (one repo at the hosting dir) and
`ros2_colcon` (ordered colcon layers under `layers/main/<layer>_ws/`, driven
by an in-tree manifest at `configs/manifest/` — `layers.txt`, per-layer
`.repos` files, `bootstrap.yaml`; the ROS distro comes from the manifest's
`distro:` field or `ROS_DISTRO` in the per-project config, never a silent
default). A `ros2_colcon` hosting dir starts empty: `adapter setup` fetches
the project's `bootstrap.yaml` (`BOOTSTRAP_URL`, then
`MANIFEST_BOOTSTRAP_URL` in the per-project config, then
`configs/project_bootstrap.url`), clones the manifest repo at its branch,
symlinks `configs/manifest/` into it, and imports every layer's repos with
`vcs` (#237). `multi_repo` is deferred until a sibling-repos project
materializes (#172 re-sequencing, 2026-07-24).

## Worktree Strategy

Two worktree types replace the ROS `layer` type. `--type` is required on all
worktree scripts (create, enter, remove):

### Workspace Worktrees

Location: `worktrees/workspace/issue-<slug>-<N>/`

Git worktrees of the **workspace repo**. Used for:
- Changes to `.agent/` (scripts, hooks, knowledge)
- Documentation updates (`docs/`, `AGENTS.md`, etc.)
- Skill development (`.claude/skills/`)

### Project Worktrees

Location: a registered project's own `worktrees/` (or its `worktrees=`
override in `.agent/projects.local`), resolved by `registry_worktree_dir`
(issue #265) — e.g. `~/src/gz4d/worktrees/issue-gz4d-<N>/`. An unregistered
project (legacy `project/` checkout only) falls back to the pre-#265
transition location `worktrees/project/<repo>/issue-<slug>-<N>/`, dropped
together with `project/` in a later PR.

Git worktrees of the **project repo**. Used for all changes to the managed project.
Draft PRs target the project repo using `gh pr create -R <project-remote>`.

`worktrees/` is gitignored at the workspace root. A registered project's own
`worktrees/` dir is excluded via that root's `.git/info/exclude` on first use
(never a tracked file); the `ros2_colcon` adapter's `worktree_env` verb
additionally writes an untracked `worktrees/COLCON_IGNORE` marker (ADR-0012:
type-specific behaviour stays in the adapter). Worktrees created before
registration remain discoverable at `worktrees/project/<name>/`.

## Stamp-Based Setup (ADR-0007)

The Makefile uses stamp files in `.make/` to track setup state:

```
setup-dev.done  ←  venv + pre-commit installed
project.done    ←  project/ configured (depends on setup-dev)
```

Running `make setup` runs the full chain. `make clean` removes stamps and forces
a full re-setup on the next `make setup`.

## Identity Management

AI agents use framework-specific git identities configured in
`.agent/scripts/framework_config.sh`. Identities are ephemeral (session-only) for
most agents and persistent for long-running ones. See
`.agent/AI_IDENTITY_STRATEGY.md` for details.

## Multi-Agent Coordination

Multiple agents can work concurrently by using separate worktrees. The workspace lock
(`make lock`/`make unlock`) prevents concurrent agents from stepping on each other during
critical operations. See `.agent/WORKFORCE_PROTOCOL.md`.

## Build and Test

Build and test commands are project-specific and configured in `.agent/project_config.sh`
(gitignored). This file is not committed — each developer/agent configures it for their
project:

```bash
PROJECT_TYPE="single_project"  # project-type adapter; defaults to single_project
BUILD_CMD="make"       # whatever builds the project
TEST_CMD="make test"   # whatever tests the project
INSTALL_CMD=""         # optional deploy/install; empty = make install no-ops
```

`make build`, `make test`, and `make install` dispatch through the project-type
adapter, which runs the configured command in the project tree
(`adapter project_root` — `project/` for `single_project`).

## Review Loop Lifecycle

An issue moves through a fixed phase order — `review-issue` → `plan-task`
→ `review-plan` → implement → `review-code` (pre-push, then post-push) →
`triage-reviews` → merge — each phase appending one canonical entry
(ADR-0013) to `.agent/work-plans/issue-<N>/progress.md`, the timeline that
is the only record of where an issue stands. `.claude/skills/run-issue/
SKILL.md` (Claude Code only) is the one script-driven path through this
table: `.agent/scripts/dispatch_phase.sh next` reads the timeline and
returns the next action, `dispatch_phase.sh --issue <N> --skill <phase>`
hands that phase to a fresh sub-agent via the Agent tool (ADR-0014), and
`--check-exit` verifies the phase kept its exit contract before the loop
advances. Nine `AskUserQuestion` checkpoints pause the loop for a human
decision, each recorded as its own `## Checkpoint` entry before the next
step is asked for — no loop state lives outside `progress.md`. Codex/
Gemini sessions, which cannot drive the Agent tool or `AskUserQuestion`
the same way, walk the same phase order by hand, one `SKILL.md` at a time.
See `.agent/knowledge/review_loop_lifecycle.md` for the one-page summary.

## Governance

- **Issue-first policy**: No code without a GitHub issue
- **Worktree isolation**: All work in isolated worktrees, never the main tree
- **Pre-commit hooks**: Enforce identity, branch hygiene, and code quality
- **ADR system**: Architecture decisions recorded in `docs/decisions/`
- **principles.md**: Seven guiding principles in `docs/principles.md`
