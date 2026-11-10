# GitHub CLI Patterns

How to call `gh` in this workspace, moved here from `AGENTS.md` (issue #259).
The hard rules (use the PR wrapper, use `--body-file`, never guess URLs, never
`gh pr merge --delete-branch` from a worktree) stay in `AGENTS.md` Boundaries.

## Creating pull requests

Use `.agent/scripts/gh_create_pr.sh` for PRs — it injects the AI signature,
validates labels, and prevents wrong-repo targeting. Heredoc body via stdin
keeps the whole flow in one allowlisted call:

```bash
.agent/scripts/gh_create_pr.sh --title "Title" --body-stdin <<'EOF'
Your markdown content here.
EOF
```

For a body already in a file:

```bash
.agent/scripts/gh_create_pr.sh --title "Title" --body-file path/to/body.md
```

The signature footer is appended automatically when `AGENT_NAME` and
`AGENT_MODEL` are set (via `set_git_identity_env.sh`). Pass
`--no-signature` to suppress — rare; revert PRs or human-authored only.

If a body is provided and identity env vars are unset, the wrapper hard-fails
with exit code 2 and points to `set_git_identity_env.sh`. This is intentional
workspace policy: PRs must be signed unless explicitly opted out.

## Use `--body-file`, Not `--body` (for direct `gh` calls)

When invoking `gh issue create` / `gh issue comment` directly (the wrapper
above covers PRs), prefer `--body-file` so multiline content isn't mangled
by shell quoting:

```bash
BODY_FILE=$(mktemp /tmp/gh_body.XXXXXX.md)
cat << 'EOF' > "$BODY_FILE"
Your markdown content here.
EOF
gh issue create --title "Title" --body-file "$BODY_FILE"
rm "$BODY_FILE"
```

## Never Guess GitHub URLs

```bash
gh issue view <N> --json url --jq '.url'
gh pr view <N> --json url --jq '.url'
gh repo view --json url --jq '.url'
```

## Repo Targeting in Scratchpad Clones

The `gh` CLI resolves the target repo from the current directory's git remote.
Inside scratchpad clones (`.agent/scratchpad/inspiration/<name>/` etc.), this
targets the cloned external repo — not the workspace or project repo.

When running `gh` commands that target a repo (`issue create`, `pr create`,
`issue comment`, etc.) from any non-worktree directory, always pass
`-R <owner/repo>` explicitly. `gh_create_issue.sh` enforces this with a
safeguard that aborts if the detected repo doesn't match workspace or project.

## Merging PRs from Worktrees

Never use `gh pr merge --delete-branch` from a worktree — `gh` tries to
checkout `main` locally, which fails because the main tree already has it
checked out. Use `--merge` without `--delete-branch` and let worktree
cleanup handle branch deletion:

```bash
# Preferred: use the merge script (handles worktree removal + sync)
make merge-pr PR=<N>

# Manual alternative:
gh pr merge <N> --merge          # no --delete-branch
```
