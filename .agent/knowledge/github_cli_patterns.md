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

The same holds in a checkout: `gh` picks a remote named `upstream` over
`origin` when no default is set, and a skill run from the wrong directory
reaches another repository's issue with the same number. Skills that read
or comment on an issue (`/review-issue`, `/plan-task`, `/review-plan`)
therefore never let `gh` choose: at the head of every code block that calls
`gh issue` or `gh pr` they ask `$WS_ROOT/.agent/scripts/issue_repo.sh <ref>`
(every block is a new shell), print the answer as a `Repository:` line, and
pass `-R "github.com/$_REPO"` (the host written out, so a `GH_HOST` in the
environment cannot send the call elsewhere). A bare number means the
repository of the checkout the skill runs in; an issue of another
repository is written `owner/repo#N`. A non-zero exit means no `gh` call in
that block; each skill's "Repository by exit code" table says what it does
then (exit 4, a checkout with no GitHub repository, is an ordinary case).

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
