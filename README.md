# Agent Workspace

A general-purpose multi-agent development platform. Manages one external project
repository with full AI agent infrastructure: worktree isolation, governance, skills,
hooks, and multi-agent coordination.

## Quick Start

```bash
# 1. Clone this workspace
git clone <workspace-url> agent_workspace
cd agent_workspace

# 2. Set up dev tools and configure project
make setup
# → Installs pre-commit in .venv
# → Prompts for project URL (or detects existing project/)

# 3. Check status
make dashboard
```

## Project Configuration

The managed project lives in `project/` (gitignored). It is configured once via
`make setup`, which will prompt for a git URL or local path:

```bash
make setup
# Enter git URL or path: https://github.com/owner/repo.git
# → Clones to project/

# Or point to an existing local clone (creates a symlink):
# Enter git URL or path: /path/to/my/clone
# → Creates: project -> /path/to/my/clone
```

After setup, configure your build and test commands in `.agent/project_config.sh`
(gitignored, not committed):

```bash
cat > .agent/project_config.sh << 'EOF'
# Per-developer project configuration
BUILD_CMD="make"       # or: cmake --build build, cargo build, npm run build
TEST_CMD="make test"   # or: cargo test, pytest, npm test
EOF
```

## Common Commands

```bash
make build        # Run BUILD_CMD in project/
make test         # Run TEST_CMD in project/
make lint         # Pre-commit on all files
make validate     # Check workspace config
make dashboard    # Workspace + project status
make sync         # Fetch/pull workspace + project
make clean        # Remove stamp files (force re-setup)
```

## Worktree Workflow

All work happens in isolated git worktrees:

```bash
# Infrastructure work (docs, scripts, skills)
.agent/scripts/worktree_create.sh --issue 42 --type workspace
source .agent/scripts/worktree_enter.sh --issue 42 --type workspace

# Project repo work
.agent/scripts/worktree_create.sh --issue 42 --type project
source .agent/scripts/worktree_enter.sh --issue 42 --type project

# List / remove
.agent/scripts/worktree_list.sh
.agent/scripts/worktree_remove.sh --issue 42 --type workspace
.agent/scripts/worktree_remove.sh --issue 42 --type project
```

For Codex or any tool that runs each shell command in isolation, use the
execution-safe worktree entry modes instead of relying on `source` to persist:

```bash
WT_PATH=$(.agent/scripts/worktree_enter.sh --issue 42 --type workspace --print-path)
# WT_PATH does not change directories by itself:
git -C "$WT_PATH" status

eval "$(.agent/scripts/worktree_enter.sh --issue 42 --type workspace --shell-snippet)"
```

## For AI Agents

Read [`AGENTS.md`](AGENTS.md) before starting any task. The key rules:

- All work in worktrees — never edit the main tree
- Issue-first policy — open an issue before coding
- AI signature on all GitHub Issues/PRs/Comments

## Documentation

- [`AGENTS.md`](AGENTS.md) — Rules for all agents
- [`CLAUDE.md`](CLAUDE.md) — Claude Code specific setup
- [`CODEX.md`](CODEX.md) — Codex CLI specific setup
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — System design
- [`docs/decisions/`](docs/decisions/) — Architecture Decision Records
- [`docs/PRINCIPLES.md`](docs/PRINCIPLES.md) — Guiding principles
- [`.agent/WORKTREE_GUIDE.md`](.agent/WORKTREE_GUIDE.md) — Worktree patterns
