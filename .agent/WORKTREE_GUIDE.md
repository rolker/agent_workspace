# Git Worktree Guide

**Purpose**: Enable parallel development through isolated working directories. Each
worktree has its own branch, uncommitted changes, and build artifacts — completely
separate from the main workspace.

## Quick Start

```bash
# Infrastructure work (docs, scripts, skills)
.agent/scripts/worktree_create.sh --issue 42 --type workspace
source .agent/scripts/worktree_enter.sh 42
# work, commit, push
.agent/scripts/worktree_remove.sh 42

# Project repo work
.agent/scripts/worktree_create.sh --issue 42 --type project
source .agent/scripts/worktree_enter.sh 42
# work in the project/ worktree, commit, push to project repo
.agent/scripts/worktree_remove.sh 42

# Skill worktrees (no GitHub issue needed)
.agent/scripts/worktree_create.sh --skill research --type workspace
source .agent/scripts/worktree_enter.sh --skill research
.agent/scripts/worktree_remove.sh --skill research
```

## Why Worktrees?

Git worktrees create separate checkouts of the same repository:
- Each worktree is a separate directory
- Each has its own branch, builds, and uncommitted files
- All worktrees share the same git history
- No conflicts between concurrent agents

## Directory Structure

```
agent_workspace/
├── .workspace-worktrees/          # Workspace repo worktrees
│   └── issue-<slug>-<N>/          # e.g. issue-workspace-42/
│       └── ... (workspace files)
│
project/
├── worktrees/                     # Project repo worktrees
│   └── issue-<slug>-<N>/          # e.g. issue-myproject-42/
│       └── ... (project files)
```

## Worktree Types

### Workspace Worktrees

For infrastructure changes: `.agent/`, `docs/`, `.claude/skills/`, `Makefile`, etc.

```bash
.agent/scripts/worktree_create.sh --issue <N> --type workspace
```

- Created in: `.workspace-worktrees/issue-<slug>-<N>/`
- Git worktree of the **workspace repo**
- Branch: `feature/issue-<N>` in the workspace repo
- PRs target the workspace repo

### Project Worktrees

For changes to the managed project repo (`project/`).

```bash
.agent/scripts/worktree_create.sh --issue <N> --type project
```

- Created in: `project/worktrees/issue-<slug>-<N>/`
- Git worktree of the **project repo**
- Branch: `feature/issue-<N>` in the project repo
- PRs target the project repo with `-R <project-remote>`

## Naming Convention

| Mode | Directory name |
|------|----------------|
| Issue | `issue-<repo_slug>-<N>` |
| Skill | `skill-<repo_slug>-<YYYYMMDD-HHMMSS>` |

`<repo_slug>` is auto-detected from the remote URL (e.g., `workspace`, `myproject`).
Use `--repo-slug` to override.

## Disambiguation

If multiple worktrees match the same issue number, use `--repo-slug`:

```bash
source .agent/scripts/worktree_enter.sh --issue 42 --repo-slug myproject
.agent/scripts/worktree_remove.sh --issue 42 --repo-slug workspace
```

## Draft PRs with Plan File

Pass `--plan-file` to create a draft PR immediately and post the plan as a PR comment:

```bash
.agent/scripts/worktree_create.sh --issue 42 --type workspace --plan-file /tmp/plan.md
.agent/scripts/worktree_create.sh --issue 42 --type project --plan-file /tmp/plan.md
```

## Sub-Issue Worktrees (Stacked PRs)

Use `--parent-issue` to branch from a parent issue's feature branch and target the
draft PR at that branch:

```bash
.agent/scripts/worktree_create.sh --issue 43 --type workspace --parent-issue 42
```

## Troubleshooting

**"Worktree already exists"**: The directory already exists. Use `worktree_enter.sh`
to enter it, or `worktree_remove.sh` to clean it up.

**"Your shell is currently inside this worktree"**: `cd` to the workspace root first:
```bash
cd ~/agent_workspace
.agent/scripts/worktree_remove.sh --issue 42
```

**"No worktree found"**: Check `worktree_list.sh` to see what exists. The slug
may differ from what you expect — use `--repo-slug` to disambiguate.

**Branch already exists**: The script reuses an existing local branch, or tracks
the remote branch if one exists.
