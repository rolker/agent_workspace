# Workspace Rules for AI Agents

Shared rules for all AI agents working in this workspace. For framework-specific
setup (environment, identity, features), see your framework's adapter file:

| Framework | Adapter File |
|-----------|-------------|
| Claude Code | [`CLAUDE.md`](CLAUDE.md) |
| Codex CLI | [`CODEX.md`](CODEX.md) |
| GitHub Copilot | [`.github/copilot-instructions.md`](.github/copilot-instructions.md) |
| Gemini CLI | [`.agent/instructions/gemini-cli.instructions.md`](.agent/instructions/gemini-cli.instructions.md) |
| Other | [`.agent/AGENT_ONBOARDING.md`](.agent/AGENT_ONBOARDING.md) |

## Terminology

- **Project**: the managed product in `project/` — what's actually being built.
  Product features, deployment, and user-facing behavior are project scope.
- **Workspace**: the agent infrastructure in this repo — skills, governance,
  scripts, worktrees, docs, and configuration.

When scope is ambiguous in conversation, default to **project** (the thing
being built) unless the topic is clearly about agent tooling or workspace
internals.

**Repo ownership**: The working directory contains files from both repos
(workspace infrastructure is layered onto the project checkout). Don't assume
which GitHub repo you're in based on directory contents — use `gh repo view` or
`git remote -v` to confirm. Issues and PRs must target the repo that owns the
code being changed:

| Scope | Repo | What lives there |
|-------|------|-----------------|
| Workspace | `agent_workspace` | `AGENTS.md`, `.agent/`, skills, scripts, docs |
| Project | project repo (e.g. `daddy_camp`) | The product being built (`project/`) |

## Boundaries

### Always (proceed autonomously)

- Use worktrees for all feature work — never edit files in the main tree
- Run pre-commit hooks before committing
- Include AI signature on all GitHub Issues/PRs/Comments (`$AGENT_NAME` / `$AGENT_MODEL`)
- Reference issue numbers in branches and PRs (`Closes #<N>`)
- Set `GIT_EDITOR=true` for rebase/amend/merge
- Use `--body-file` for multiline `gh` CLI content (not `--body`)
- Include clickable GitHub links in summaries (use `gh` to look up URLs — never guess)
- Read `.agents/README.md` before modifying any project repo
- Verify issue matches task before first commit
- Verify documentation claims against source code
- Atomic commits: one logical change per commit
- Branch naming: `feature/issue-<N>` or `feature/ISSUE-<N>-<description>`
- All changes via Pull Requests

### Ask First (get human approval)

- Modifying instruction files (`AGENTS.md`, `CLAUDE.md`, etc.)
- Changing CI or branch protection configuration
- Changing the project remote URL

### Never (hard stops)

- Commit to `main` — branch is protected; direct pushes are rejected
- Skip hooks with `--no-verify`
- Commit secrets or credentials
- Document from assumptions — verify against source code
- Construct GitHub URLs from directory names — use `gh` CLI to look them up
- Run bare `pip install` or use `--break-system-packages` — use `.venv` for dev tools (see ADR-0009)

## Communication Standards

- Don't use filler phrases that signal agreement without substance
  ("great question", "that's an interesting approach", "absolutely")
- Challenge vague terms and hidden assumptions — ask for clarification
- Push back when something seems wrong rather than agreeing too readily
- Lead with the answer or action, not the reasoning

## Tool Usage

- **Prefer dedicated tools over shell equivalents** — When your framework
  provides built-in tools for file search, content search, file reading, or
  file editing, use those instead of shell commands (`ls`, `find`, `grep`,
  `cat`, `sed`, etc.). Dedicated tools provide better audit trails and
  typically require fewer permission prompts.
- **Chain shell commands only when state depends on it** — Use `&&` when the
  second command needs shell state from the first (sourced environments, directory
  changes). For independent commands, use separate tool calls so each can be
  evaluated independently.

## Worktree Workflow

Every task must use an isolated worktree. `--type` is **required** on all
worktree scripts (create, enter, remove). Two types are available:

**Workspace worktrees** — for changes to workspace infrastructure (`.agent/`, `docs/`, skills):

```bash
.agent/scripts/worktree_create.sh --issue <N> --type workspace [--plan-file <path>]
source .agent/scripts/worktree_enter.sh --issue <N> --type workspace
# work here; this is a git worktree of the workspace repo

# Codex / per-command shells:
WT_PATH=$(.agent/scripts/worktree_enter.sh --issue <N> --type workspace --print-path)
# or:
eval "$(.agent/scripts/worktree_enter.sh --issue <N> --type workspace --shell-snippet)"
```

**Project worktrees** — for changes to the managed project repo:

```bash
.agent/scripts/worktree_create.sh --issue <N> --type project [--plan-file <path>]
source .agent/scripts/worktree_enter.sh --issue <N> --type project
# work here; this is a git worktree of project/
# PRs target the project repo (created with -R <project-remote>)

# Codex / per-command shells:
WT_PATH=$(.agent/scripts/worktree_enter.sh --issue <N> --type project --print-path)
# or:
eval "$(.agent/scripts/worktree_enter.sh --issue <N> --type project --shell-snippet)"
```

**Sub-issue work** (branches from parent's feature branch):

```bash
.agent/scripts/worktree_create.sh --issue <N> --type workspace --parent-issue <parent_N>
.agent/scripts/worktree_create.sh --issue <N> --type project --parent-issue <parent_N>
```

**Skill worktrees** (no issue needed, allowlist-enforced):

```bash
.agent/scripts/worktree_create.sh --skill research --type workspace
source .agent/scripts/worktree_enter.sh --skill research --type workspace
.agent/scripts/worktree_remove.sh --skill research --type workspace
```

**List / remove**:

```bash
.agent/scripts/worktree_list.sh
.agent/scripts/worktree_remove.sh --issue <N> --type workspace
.agent/scripts/worktree_remove.sh --issue <N> --type project
```

**Multi-project** — use `--repo` when multiple project repos are configured:

```bash
.agent/scripts/worktree_enter.sh --issue <N> --type project --repo <repo_name>
```

See [`.agent/WORKTREE_GUIDE.md`](.agent/WORKTREE_GUIDE.md) for disambiguation and troubleshooting.

## Issue-First Policy

No code without a ticket. Check for an existing GitHub issue first; if none exists,
ask the user: "Should I open an issue to track this?" Use the issue number in branches
and reference it in PRs with `Closes #<N>`.

Issues and PRs live in whichever repo owns the code being changed — workspace or project.

**Trivial fixes** (typos, minor doc corrections) don't need a dedicated issue.

**Sub-tasks**: Reference the parent issue in the issue body (e.g., "Part of #NNN"). Use
full `owner/repo#NNN` syntax for cross-repo references.

**Verify before committing**: Before your first commit, confirm the issue matches your task:
`gh issue view $WORKTREE_ISSUE --json title --jq '.title'`

### Skill Worktree Exception

Skills maintaining living documents may use `--skill <name>` instead of `--issue <N>`.
**Allowed skills**: `research`, `inspiration-tracker` (enforced by allowlist in `worktree_create.sh`).

Branch naming: `skill/{name}-{YYYYMMDD-HHMMSS}`.

All other rules (atomic commits, AI signature, pre-commit hooks) still apply.

## AI Signature (Required on all GitHub Issues/PRs/Comments)

```markdown
---
**Authored-By**: `$AGENT_NAME`
**Model**: `$AGENT_MODEL`
```

Use your actual runtime identity — never copy example model names from docs.

## GitHub CLI Patterns

### Use `--body-file`, Not `--body`

```bash
BODY_FILE=$(mktemp /tmp/gh_body.XXXXXX.md)
cat << 'EOF' > "$BODY_FILE"
Your markdown content here.
EOF
gh pr create --title "Title" --body-file "$BODY_FILE"
rm "$BODY_FILE"
```

### Never Guess GitHub URLs

```bash
gh issue view <N> --json url --jq '.url'
gh pr view <N> --json url --jq '.url'
gh repo view --json url --jq '.url'
```

### Repo Targeting in Scratchpad Clones

The `gh` CLI resolves the target repo from the current directory's git remote.
Inside scratchpad clones (`.agent/scratchpad/inspiration/<name>/` etc.), this
targets the cloned external repo — not the workspace or project repo.

When running `gh` commands that target a repo (`issue create`, `pr create`,
`issue comment`, etc.) from any non-worktree directory, always pass
`-R <owner/repo>` explicitly. `gh_create_issue.sh` enforces this with a
safeguard that aborts if the detected repo doesn't match workspace or project.

### Merging PRs from Worktrees

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

## Build & Test

Build and test commands are project-specific. Configure them in `.agent/project_config.sh`
(gitignored, per-developer):

```bash
# .agent/project_config.sh
BUILD_CMD="make"       # or: cmake --build build, cargo build, npm run build, etc.
TEST_CMD="make test"   # or: cargo test, pytest, npm test, etc.
```

Then run:

```bash
make build    # runs BUILD_CMD in project/
make test     # runs TEST_CMD in project/
make lint     # pre-commit on all files
make validate # check workspace config
make dashboard
```

## Documentation Accuracy

- **Never document from assumptions** — verify every claim against actual source code.
- Before writing or updating project documentation, read the relevant source files.
- Check for `.agents/README.md` in the project repo before making changes.

## Workspace Cleanliness

- Keep repo root clean — no temp files, build artifacts, or logs.
- Use `.agent/scratchpad/` for persistent temp files (unique names via `mktemp`).
- Use `/tmp` for ephemeral files cleaned up in the same command.

## Post-Task Verification

Before marking a task complete or opening a PR:

1. Re-read issue description and work plan
2. Compare changes against requirements
3. Check consequences: do tests, docs, or dependent references need updating?
4. List any gaps; complete them or explain in PR description

## Script Reference

`scripts/` at the repo root is a symlink to `.agent/scripts/` for convenience.

Scripts marked **(source)** must be sourced; all others should be executed.

| Script | Purpose |
|--------|---------|
| `.agent/scripts/set_git_identity_env.sh` | Ephemeral git identity (session-only) **(source)** |
| `.agent/scripts/worktree_create.sh` | Create isolated worktree |
| `.agent/scripts/worktree_enter.sh` | Enter worktree **(source)** |
| `.agent/scripts/worktree_remove.sh` | Remove worktree |
| `.agent/scripts/worktree_list.sh` | List active worktrees (`--json` for structured output) |
| `.agent/scripts/agent start-task <N>` | High-level wrapper: create worktree |
| `.agent/scripts/dashboard.sh` | Unified workspace status (supports `--quick`) |
| `.agent/scripts/build.sh` | Run BUILD_CMD from project_config.sh |
| `.agent/scripts/test.sh` | Run TEST_CMD from project_config.sh |
| `.agent/scripts/setup_project.sh` | Configure project/ directory |
| `.agent/scripts/check_branch_updates.sh` | Check if branch is behind default |
| `.agent/scripts/gh_create_issue.sh` | Create issue with label validation (`GITBUG_CREATE=1` for offline) |
| `.agent/scripts/revert_feature.sh` | Revert all commits for an issue |
| `.agent/scripts/merge_pr.sh` | Merge PR, remove worktree, delete branch, sync main |
| `.agent/scripts/sync_project.py` | Sync workspace + project repos |
| `.agent/scripts/validate_workspace.py` | Validate project/ configuration |
| `.agent/scripts/detect_agent_identity.sh` | Auto-detect agent framework + model |
| `.agent/scripts/fetch_pr_reviews.sh` | Fetch all PR reviews and CI status |
| `.agent/scripts/cross_model_review.sh` | Cross-model adversarial review (gemini/codex/claude/copilot, tmux or sync) |

## References (Read When Needed, Not Upfront)

- [`README.md`](README.md) — Workspace purpose and goals
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — System design
- [`docs/decisions/`](docs/decisions/) — Architecture Decision Records
- [`.agent/WORKTREE_GUIDE.md`](.agent/WORKTREE_GUIDE.md) — Detailed worktree patterns
- [`.agent/AI_IDENTITY_STRATEGY.md`](.agent/AI_IDENTITY_STRATEGY.md) — Multi-framework identity
- [`.agent/WORKFORCE_PROTOCOL.md`](.agent/WORKFORCE_PROTOCOL.md) — Multi-agent coordination
- [`.agent/knowledge/`](.agent/knowledge/) — Development patterns and CLI best practices
- [`.agent/templates/`](.agent/templates/) — Issue and PR templates
