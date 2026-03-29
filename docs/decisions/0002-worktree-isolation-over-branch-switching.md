# ADR-0002: Worktree Isolation Over Branch Switching

## Status

Accepted

## Context

AI coding agents working in a shared repository cause problems when they switch branches:
uncommitted changes are discarded, builds interfere with each other, test results
overwrite each other, and lock contention slows everyone down.

The workspace tried documentation-only solutions first ("never switch branches"), but
agents don't reliably follow written rules. A mechanical enforcement was needed.

## Decision

All feature work uses git worktrees — separate working directory checkouts that each have
their own branch, build artifacts, and uncommitted changes, while sharing the same git
history.

Two worktree types (both require explicit `--type`):
- `workspace` — for workspace infrastructure (`.agent/`, `docs/`, skills). Created in
  `worktrees/workspace/issue-<slug>-<N>/` as a git worktree of the workspace repo.
- `project` — for changes to the managed project repo. Created in
  `worktrees/project/<repo>/issue-<slug>-<N>/` as a git worktree of the project repo.
  Draft PRs target the project repo with `-R <project-remote>`.
  The repo-name tier supports future multi-project workspaces.

Worktree lifecycle is managed through dedicated scripts: `worktree_create.sh`,
`worktree_enter.sh`, `worktree_list.sh`, `worktree_remove.sh`.

## Consequences

**Positive:**
- True parallel development — multiple tasks in progress without interference
- No risk of discarding uncommitted work when switching context
- Enables multi-agent workflows where different agents work on different issues simultaneously

**Negative:**
- More disk usage (each worktree is a separate checkout)
- Slightly more complex workflow than simple branch switching
