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

## Sync Strategy

git-bug's local cache syncs with GitHub at three levels:

| Operation | Sync behavior |
|-----------|---------------|
| Issue read (cache hit) | Local only — no network |
| Issue read (cache miss) | Pull from GitHub (`git bug bridge pull github`), retry locally, then fall back to `gh` |
| Issue write | Local git-bug op, then immediate push (`git bug bridge push github`) |
| Periodic | `make sync` runs full bidirectional pull + push |

**Rationale:** Always-sync on every read adds unnecessary latency and API usage.
Pull-on-miss covers the common stale-cache case (issue just created on GitHub)
while keeping cache-hit reads instant and offline-capable. Writes push immediately
so issues and comments are visible to collaborators and GitHub notifications
without waiting for periodic sync.

The shared helper `.agent/scripts/_issue_helpers.sh` implements the read
pattern. See `AGENTS.md` "git-bug-first Pattern" for usage.

## CLI Notes (v0.10.1)

- Issue commands use the `bug` subcommand: `git bug bug show`, `git bug bug select`, etc.
- Bridge listing: `git bug bridge` (bare command lists bridges; `bridge list` does not exist)
- GitHub issue number lookup: metadata filter
  `git bug bug -m "github-url=https://github.com/OWNER/REPO/issues/N" --format json`
- `bug show --format json` includes title, status, and comments but not bridge metadata
