# Agent Workspace

A general-purpose multi-agent development platform. Manages one or more external
project repositories with full AI agent infrastructure: worktree isolation, governance, skills,
hooks, and multi-agent coordination.

## Goals

The workspace exists to help one person manage many AI agents across one or
more projects, so the results can be trusted and the owner stays informed and
in control. <!-- P -->

### Quality of the work

- Agents take the time and resources a quality result needs, within practical
  limits: economical, but never at the cost of quality. <!-- Q1 -->
- Documentation, code and designs are concise and distilled, so a newcomer can
  grasp them without much effort. <!-- Q2 -->
- Agents learn from what's already there: why existing code was written the
  way it was, how the project already solves similar problems, and what the
  field considers good practice. They bring the same care to new code, say so
  when a better-known solution exists, and adopt new techniques only when
  they'll be a long-term gain. <!-- Q3 draft -->
- Code meets the safety expectations of the project's field. A path planning
  algorithm for a marine robot should be scrutinized for safety differently
  than a path planning algorithm for a game. <!-- Q4 -->

### Trust, control and information

- The owner stays in control: agents make decisions on their own only as far
  as the trust they've earned allows. When in doubt, they ask. <!-- T2 draft -->
- Agents can't do lasting damage: they get only the access a task needs, and
  anything that can't be undone needs the owner's OK. <!-- T3 draft -->
- Agents strive to be trustworthy and take care not to break the trust they've
  earned. <!-- T1 -->
- The owner has limited time and attention, so agents give the right amount of
  information: enough to make the important decisions and keep understanding
  the whole project, and no more. <!-- T4 draft -->

### Flexibility

- When practical, preference should go to open source and open standards to
  minimize vendor lock-in. Have an exit strategy for anything that depends on
  a vendor's closed product or infrastructure. <!-- F1 -->
- Agents follow the rules. When asked to bend one, they go along when it's
  harmless, push back if it seems harmful, and make sure a misunderstanding
  doesn't turn into a mistake. <!-- F2 -->

### Modular

- The workspace is project-agnostic and modular: knowledge about a kind of
  project, like ROS best practices, and workflows for different kinds of work,
  not only coding, are added as modules without changing the rest of the
  workspace. <!-- W1+W4 draft merge -->
- The workspace is improved with the same process and standards used on
  projects. <!-- W5 -->

### Light touch on projects

- Each project chooses how much footprint the workspace leaves in it, from none
  at all to agent instructions and other process-related documents. This lets
  the workspace be used on external projects that may not welcome its
  supporting files. <!-- W2; second sentence draft -->
- A project the workspace has worked on can still be developed and maintained
  without it. <!-- W3 -->

## History

<!-- PLACEHOLDER: the owner will write this section. Also to cover: moving from
coder to manager of agents; why one workspace (the trust built into its
instructions and what agents have learned). -->

Before 2026 I had been dismissing "vibe coding" without having tried it. I
finally tried it to get a better grasp of what it could do, using a one-year
Gemini subscription that came with my phone and that I was barely using. The
results opened my eyes to how much agents could do in very little time, but
also showed the weaknesses: code that wasn't designed to grow well with the
idea, and that didn't follow the principles I would. So I pivoted to agentic
coding. In January 2026 I started ros2_agent_workspace simply as the place to
version-control my agent instructions, without adding them to the project11
repos. agent_workspace began later for simple non-ROS projects, to avoid
scope-creeping ros2_agent_workspace; it is now its successor, and
ros2_agent_workspace is being retired.

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
PROJECT_TYPE="single_project"  # project-type adapter (ADR-0011); defaults to single_project
BUILD_CMD="make"       # or: cmake --build build, cargo build, npm run build
TEST_CMD="make test"   # or: cargo test, pytest, npm test
INSTALL_CMD=""         # optional deploy/install; empty = make install no-ops
EOF
```

## Common Commands

```bash
make build        # Run BUILD_CMD in project/
make test         # Run TEST_CMD in project/
make install      # Run INSTALL_CMD (no-op when unset)
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
- [`docs/design.md`](docs/design.md) — System design
- [`docs/decisions/`](docs/decisions/) — Architecture Decision Records
- [`docs/principles.md`](docs/principles.md) — Guiding principles
- [`.agent/WORKTREE_GUIDE.md`](.agent/WORKTREE_GUIDE.md) — Worktree patterns
