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
| Project | project repo (e.g. `my_project`) | The product being built (`project/`) |

## Boundaries

### Always (proceed autonomously)

- Use worktrees for all feature work — never edit files in the main tree
- Run pre-commit hooks before committing
- Include AI signature on all GitHub Issues/PRs/Comments (`$AGENT_NAME` / `$AGENT_MODEL`)
- Reference issue numbers in branches and PRs (`Closes #<N>`)
- Set `GIT_EDITOR=true` for rebase/amend/merge
- Use `--body-file` for multiline `gh` CLI content (not `--body`)
- Use `.agent/scripts/gh_create_pr.sh` for PRs (it adds the AI signature and checks the target repo)
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
- Run `gh pr merge --delete-branch` from a worktree — use `make merge-pr PR=<N>`
- Run bare `pip install` or use `--break-system-packages` — use `.venv` for dev tools (see ADR-0009)

## Communication Standards

- Don't use filler phrases that signal agreement without substance
  ("great question", "that's an interesting approach", "absolutely")
- Challenge vague terms and hidden assumptions — ask for clarification
- Push back when something seems wrong rather than agreeing too readily
- Lead with the answer or action, not the reasoning

## Quality Standard

What we ship is used by people who will see every bug, half-fix and silent
failure, and each one costs their trust. The marginal cost of completeness is
near zero with AI — do the whole thing, do it right, do it with tests.

- When fixing a bug, fix it completely: add the test, handle the edge case, check
  the state transition. Never leave a "good enough" fix when the proper one is
  within reach.
- When triaging reviews, do not dismiss concerns about error handling, silent
  failures, stale data, or missing validation as "nits" unless the failure mode
  genuinely cannot occur. Speculative or vague "won't happen in practice" is not
  a dismissal.
- Code that arrives from outside the normal review path is a draft — field
  imports, cherry-picks, copy-pastes, hurried agent commits merged without
  review. Add tests, verify external identifiers and contracts, check for
  idempotency before treating it as landed.
- Never offer to "table this for later" when the permanent solve is five minutes
  away. Never present a workaround when the real fix exists.

How work is judged beyond this list is in [`docs/principles.md`](docs/principles.md);
reviews apply it through
[`.agent/knowledge/principles_review_guide.md`](.agent/knowledge/principles_review_guide.md).

## Tool Usage

- **Prefer dedicated tools where they fit** — shell commands (`cat`,
  `grep`, `sed`, `find`, etc.) are fine for reads and simple edits; reach
  for a framework's dedicated search/read/edit tool instead when a shell
  command would be fragile or ambiguous — exact or multi-line
  replacements, or `sed`/`awk` flags that differ between GNU and
  BSD/macOS. This is a preference the agent applies by judgment, not an
  enforced rule.
- **Chain shell commands only when state depends on it** — Use `&&` when the
  second command needs shell state from the first (sourced environments, directory
  changes). For independent commands, use separate tool calls so each can be
  evaluated independently.

## Worktree Workflow

Every task must use an isolated worktree. `--type` is **required** on all
worktree scripts (create, enter, remove). Two types: **workspace** (`.agent/`, `docs/`,
skills) and **project** (the managed project repo; its PRs use `-R <project-remote>`).
Sub-issue work branches from the parent's feature branch (`--parent-issue`); skill
worktrees need no issue (Skill Worktree Exception, below). Commands, entry and removal:
[`.agent/WORKTREE_GUIDE.md`](.agent/WORKTREE_GUIDE.md).

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

Skills maintaining living documents (and `onboard-project`, below) may use `--skill <name>` instead of `--issue <N>`.
**Allowed skills**: `research`, `inspiration-tracker`, `onboard-project` (enforced by allowlist in `worktree_create.sh`). `onboard-project` uses it with `--type project --project <name>` for a project that uses no issues: a worktree of the project root's own repository. Each allowlisted skill has one worktree type: `research` and `inspiration-tracker` make workspace worktrees only, `onboard-project` project worktrees only.

Branch naming: `skill/{name}-{YYYYMMDD-HHMMSS}`.

All other rules (atomic commits, AI signature, pre-commit hooks) still apply.

## AI Signature (Required on all GitHub Issues/PRs/Comments)

```markdown
---
**Authored-By**: `$AGENT_NAME`
**Model**: `$AGENT_MODEL`
```

Use your actual runtime identity — never copy example model names from docs.

## Build & Test

Configure the project's build and test commands in `.agent/project_config.sh` (gitignored);
then `make build`, `make test`, `make lint` (pre-commit on all files) and `make validate`
(workspace config). See [`.agent/knowledge/build_and_test.md`](.agent/knowledge/build_and_test.md).

## Verify Before Claiming

Each claim in a PR description, a hand-back or a document traces to a command run
or a file read (principle "Verify before claiming").

- **Never document from assumptions** — verify every claim against actual source code.
- Before writing or updating project documentation, read the relevant source files.
- Check for `.agents/README.md` in the project repo before making changes.
- "Tests pass" names which tests. A step that was skipped, denied or failed is
  reported as skipped, denied or failed, never as done.

## Workspace Cleanliness

- Keep repo root clean — no temp files, build artifacts, or logs.
- Use `.agent/scratchpad/` for persistent temp files (unique names via `mktemp`).
- Use `/tmp` for ephemeral files cleaned up in the same command.

## Post-Task Verification

Before marking a task complete or opening a PR:

1. Re-read issue description and work plan
2. Compare changes against requirements
3. Check consequences: do tests, docs, or dependent references need updating?
4. Does the change alter the design picture (how the parts fit)? If so, the
   matching section of the owning repo's design document is updated in the same
   change (ADR-0017)
5. List any gaps; complete them or explain in PR description

## References (Read When Needed, Not Upfront)

- [`README.md`](README.md) — Workspace purpose and goals
- [`docs/design.md`](docs/design.md) — System design
- [`docs/decisions/`](docs/decisions/) — Architecture Decision Records
- [`.agent/WORKTREE_GUIDE.md`](.agent/WORKTREE_GUIDE.md) — Detailed worktree patterns
- [`.agent/AI_IDENTITY_STRATEGY.md`](.agent/AI_IDENTITY_STRATEGY.md) — Multi-framework identity
- [`.agent/WORKFORCE_PROTOCOL.md`](.agent/WORKFORCE_PROTOCOL.md) — Multi-agent coordination
- [`.agent/knowledge/`](.agent/knowledge/) — Development patterns and CLI best practices
- [`.agent/knowledge/github_cli_patterns.md`](.agent/knowledge/github_cli_patterns.md) — GitHub CLI Patterns (PR wrapper, `--body-file`, URLs, `-R` in scratchpad clones, merging from worktrees)
- [`.agent/knowledge/git_bug_usage.md`](.agent/knowledge/git_bug_usage.md) — git-bug-first Pattern for issue reads and writes (ADR-0010)
- [`.agent/knowledge/script_reference.md`](.agent/knowledge/script_reference.md) — Script Reference (every script in `.agent/scripts/`)
- [`.agent/templates/`](.agent/templates/) — Issue and PR templates
