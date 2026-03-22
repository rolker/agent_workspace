# ADR-0010: git-bug Installed by Default (with Opt-Out)

## Status

Accepted (supersedes previous "optional" decision)

## Context

The previous decision marked git-bug as optional because this workspace is a general-purpose
fork that "may not always have GitHub connectivity or the same dependency appetite." In
practice this assumption has not held: the workspace is GitHub-backed, and `worktree_create.sh`
queries the GitHub API for issue title/state on every `agent start-task`. The original
source workspace (ros2_agent_workspace) adopted git-bug precisely to eliminate this
per-worktree API latency and enable offline operation.

The implementation risks that originally justified keeping git-bug optional are already
mitigated:
- `git_bug_setup.sh` is idempotent and skips with a brief status message if git-bug is not installed
- `worktree_create.sh` tries git-bug first, falls back to `gh` — nothing breaks without it
- A `skip-git-bug` Makefile escape hatch exists for opt-out
- CI is detected and the setup step skips automatically

The real tradeoffs are modest: a ~15 MB binary download and a small additional sync step.

## Decision

git-bug **is installed by default** in this workspace.

- `bootstrap.sh` downloads the pinned git-bug binary to `/usr/local/bin/`
- `$(STAMP)/git-bug.done` is a Makefile stamp that runs `git_bug_setup.sh` (identity + GitHub bridge)
- `setup` depends on `git-bug.done`
- A `skip-git-bug` target marks the stamp without running setup (opt-out for constrained environments)
- All integrations degrade gracefully: scripts check `command -v git-bug` before use

## Consequences

**Positive:**
- Offline issue lookup — `worktree_create.sh` and `dashboard.sh` can resolve issue titles without network
- Reduced GitHub API usage during frequent worktree creation
- Issue metadata survives network outages

**Negative:**
- ~15 MB binary added to bootstrap
- Additional `git bug pull/push` step in `make sync`
- Bridge setup requires a valid GitHub token at first run

**Opt-out:**
Run `make skip-git-bug` to mark the stamp without running git-bug setup/configuration.
The workspace degrades to gh-only (identical to previous behavior).
