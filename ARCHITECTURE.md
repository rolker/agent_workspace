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
│   │   └── single_project/  # adapter.sh + setup.sh + sync.py
│   ├── project_config.sh  # PROJECT_TYPE / BUILD_CMD / TEST_CMD / INSTALL_CMD (gitignored, per-developer)
│   ├── projects.local     # Per-machine project registry (gitignored; see projects.local.example)
│   ├── projects.d/        # Per-project command configs, <name>.sh (gitignored)
│   ├── work-plans/        # issue-<N>/plan.md and review artifacts
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
│   ├── PRINCIPLES.md
│   └── decisions/         # Architecture Decision Records (ADRs)
├── scripts -> .agent/scripts  # Convenience symlink
├── CLAUDE.md              # Claude Code adapter
├── AGENTS.md              # Shared agent rules
├── ARCHITECTURE.md        # This file
├── README.md
├── Makefile
├── requirements.txt
└── .pre-commit-config.yaml
```

## Project Repository Model

Project-shape-specific behavior (setup, sync, build, test, install, environment,
repo enumeration, PR targeting) lives behind a 10-verb adapter contract
(ADR-0011). `.agent/scripts/adapter [--from <dir>] [--project <name>] <verb>`
resolves the active project and dispatches to
`.agent/project_types/<type>/adapter.sh`. `validate_adapter.sh` (pre-commit + CI)
asserts every type implements every verb.

Two hosting shapes coexist during the #172 migration (issue #227):

- **Legacy**: the `project/` directory holds one external git repository —
  cloned (`git clone <url> project/`) or symlinked
  (`ln -s /path/to/existing/clone project`). `PROJECT_TYPE` comes from
  `.agent/project_config.sh` (default `single_project`).
- **Registry**: `.agent/projects.local` (per-machine, gitignored) maps
  project names to hosting dirs (default `projects/<name>/`) and project
  types. Per-project build/test commands live in
  `.agent/projects.d/<name>.sh`, falling back to `.agent/project_config.sh`.
  See `.agent/projects.local.example` for the format.

The dispatcher resolves the active project in order: explicit
`--project <name>` (`make build PROJECT=<name>`), the caller's cwd inside a
registered hosting dir, then the legacy `project/` shape. A machine with only
the legacy symlink behaves exactly as before.

The project's `remote.origin.url` (from `.git/config`) is the source of truth for the
project URL — no `configs/` directory is needed.

`validate_workspace.py` understands both shapes: legacy `project/` (valid git
repo with a remote) and registry entries (well-formed, known project type,
checkout present).

Further types (`multi_repo`, `ros2_colcon`) arrive with later #172 steps.

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

Location: `worktrees/project/<repo>/issue-<slug>-<N>/`

Git worktrees of the **project repo**. Used for all changes to the managed project.
Draft PRs target the project repo using `gh pr create -R <project-remote>`.

`worktrees/` is gitignored at the workspace root.

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

## Governance

- **Issue-first policy**: No code without a GitHub issue
- **Worktree isolation**: All work in isolated worktrees, never the main tree
- **Pre-commit hooks**: Enforce identity, branch hygiene, and code quality
- **ADR system**: Architecture decisions recorded in `docs/decisions/`
- **PRINCIPLES.md**: Seven guiding principles in `docs/PRINCIPLES.md`
