# ADR-0010: git-bug Is Optional (Not Configured by Default)

## Status

Accepted

## Context

The source workspace (ros2_agent_workspace) adopted git-bug v0.10.1 as a local-first
issue cache with GitHub bridge sync (ADR-0010 in that workspace). This workspace is a
general-purpose fork that may not always have GitHub connectivity or the same dependency
appetite.

git-bug adds a ~15 MB binary dependency and requires bridge setup. For a general-purpose
workspace used with arbitrary projects, the value is unclear — the project repo may or
may not be on GitHub, and the workspace may be used in environments where the git-bug
binary is unavailable.

## Decision

git-bug is **not installed or configured by default** in this workspace.

All scripts that previously had git-bug → gh fallback logic use only `gh` (GitHub CLI).
If git-bug is installed and discoverable in PATH, scripts may use it opportunistically,
but no stamp or setup step depends on it.

## Consequences

**Positive:**
- Simpler setup — no `git-bug` binary download or bridge configuration
- Works in any environment with just `git` and `gh`

**Negative:**
- No offline issue lookup — all issue title/state queries require network access to GitHub
- Slightly higher GitHub API usage
