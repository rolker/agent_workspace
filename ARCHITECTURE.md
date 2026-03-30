# Architecture: General-Purpose Agent Workspace

## Overview

This workspace is a general-purpose multi-agent development platform. It manages
one external project repository (`project/`) and provides the full agent infrastructure
needed to develop it safely: worktree isolation, governance, skills, hooks, and
multi-agent coordination.

## Directory Structure

```
agent_workspace/
├── .agent/
│   ├── scripts/           # All automation scripts
│   │   ├── lib/           # Python library modules
│   │   └── ...
│   ├── knowledge/         # Agent knowledge documents
│   ├── project_config.sh  # BUILD_CMD / TEST_CMD (gitignored, per-developer)
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
├── project/               # Gitignored — cloned or symlinked project repo
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

The `project/` directory holds a single external git repository. It is configured
during setup and gitignored. The project can be:

- **Cloned**: `git clone <url> project/`
- **Symlinked**: `ln -s /path/to/existing/clone project`

The project's `remote.origin.url` (from `.git/config`) is the source of truth for the
project URL — no `configs/` directory is needed.

`validate_workspace.py` checks that `project/` exists, is a valid git repo, and has a
remote configured.

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
BUILD_CMD="make"       # whatever builds the project
TEST_CMD="make test"   # whatever tests the project
```

These are executed in the `project/` directory by `.agent/scripts/build.sh` and
`.agent/scripts/test.sh`.

## Governance

- **Issue-first policy**: No code without a GitHub issue
- **Worktree isolation**: All work in isolated worktrees, never the main tree
- **Pre-commit hooks**: Enforce identity, branch hygiene, and code quality
- **ADR system**: Architecture decisions recorded in `docs/decisions/`
- **PRINCIPLES.md**: Seven guiding principles in `docs/PRINCIPLES.md`
