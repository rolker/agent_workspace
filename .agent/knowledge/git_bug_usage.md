# git-bug-first Pattern (ADR-0010)

How scripts read and write issues through git-bug, moved here from `AGENTS.md`
(issue #259). [ADR-0010](../../docs/decisions/0010-git-bug-is-optional.md) stays
the decision record.

For issue reads, try git-bug first (offline-capable), then fall back to `gh`.
PR operations (`gh pr view/merge/create/diff`) stay `gh`-only — git-bug
doesn't track PRs.

**Scripts**: source `.agent/scripts/_issue_helpers.sh` and use:
- `issue_lookup <N> --repo <owner/repo> [--root <dir>]` — single issue
- `issue_list_open --repo <owner/repo> [--root <dir>]` — list open issues
- `issue_count_open --repo <owner/repo> [--root <dir>]` — count open issues

**Sync behavior**:
- **Reads**: local cache first; on miss, `git bug bridge pull github` + retry,
  then fall back to `gh`
- **Writes**: local git-bug op, then immediate `git bug bridge push github`
- **Periodic**: `make sync` for full bidirectional reconciliation

**git-bug CLI notes** (v0.10.1):
- Use `git bug bug ...` (not `git bug ...`) for issue commands
- Use `git bug bridge` (no subcommand) to list bridges — `bridge list` doesn't exist
- Lookup by GitHub issue number uses metadata filter:
  `git bug bug -m "github-url=https://github.com/OWNER/REPO/issues/N" --format json`
- `--format json` works on both list (`bug bug`) and show (`bug bug show`)
