---
name: inspiration-tracker
description: Track external projects for portable enhancements and interesting patterns. Supports fork-style file diffs and inspiration-style surveys with per-project digests.
---

# Inspiration Tracker

## Usage

```
/inspiration-tracker                  # List tracked projects, pick one to check
/inspiration-tracker <name>           # Check a specific tracked project
/inspiration-tracker add              # Add a new project interactively
/inspiration-tracker add <repo-url>   # Add a specific repo to the registry
```

## Overview

**Lifecycle position**: Utility — run periodically to discover portable
enhancements and interesting patterns from tracked external projects.

Maintains a registry of external projects (`.agent/knowledge/inspiration_registry.yml`)
and per-project digests that track what's been reviewed, ported, skipped, or deferred.
Supports two project types with different comparison strategies:

- **fork**: File-level diff for repos with shared structure (e.g., the original
  workspace this repo was forked from)
- **inspiration**: Structured survey + changelog for unrelated projects with
  interesting patterns

## Registry

The project registry lives at `.agent/knowledge/inspiration_registry.yml` (git-tracked).

```yaml
projects:
  ros2_agent_workspace:
    type: fork
    repo: rolker/ros2_agent_workspace
    description: Original ROS2 agent workspace this repo was forked from
    domain_patterns: [ros2, colcon, layer, overlay, gazebo, launch]
    categories: [scripts, skills, adrs, templates, knowledge, makefile, config]

  superpowers:
    type: inspiration
    repo: obra/superpowers
    description: Composable skills framework for Claude Code
    interest_areas:
      - skills architecture
      - TDD methodology
      - subagent patterns
```

### Registry fields

**Common fields (both types)**:
- `type`: `fork` or `inspiration`
- `repo`: GitHub `owner/repo` slug
- `description`: One-line description of the project

**Fork-only fields**:
- `domain_patterns`: list of strings — filenames matching these are auto-tagged
  as "domain-specific — probably skip"
- `categories`: which directories to compare (see fork comparison table below)

**Inspiration-only fields**:
- `interest_areas`: list of topics/patterns to focus on during surveys and
  changelog reviews

## Steps

### 1. Entry point

**No arguments**:
- Read the registry. If empty, offer to seed it:
  - Add `ros2_agent_workspace` (fork type)
  - Search the web for interesting projects
  - Enter a repo URL manually
- If registry has entries, list them and ask which to check.

**`<name>`**: Look up in registry and proceed to step 2.

**`add`**: Jump to the interactive add flow (step 9).

**`add <repo-url>`**: Pre-fill the repo URL and jump to the add flow (step 9).

### 2. Ensure local copy

All clones live in `.agent/scratchpad/inspiration/<name>/` (gitignored,
ephemeral — recreated on any machine where this workspace is checked out).

```bash
CLONE_DIR=".agent/scratchpad/inspiration/<name>"
if [ -d "$CLONE_DIR/.git" ]; then
    cd "$CLONE_DIR" && git fetch origin
else
    git clone --depth=1 "https://github.com/<repo>.git" "$CLONE_DIR"
fi
UPSTREAM_SHA=$(cd "$CLONE_DIR" && git rev-parse HEAD)
```

### 3. Load digest state

Read `.agent/knowledge/inspiration_<name>_digest.md` (if it exists) to check
which items have already been reviewed and what decisions were made (ported,
skipped, deferred). The digest also records the last-checked commit SHA,
needed for changelog mode in step 5.

### 4. Gather GitHub context

For both project types, query the upstream repo for activity:

```bash
# Open issues (most recent 20)
gh issue list -R <repo> --limit 20 --json number,title,labels,updatedAt

# Recently closed issues (last 30 days)
gh issue list -R <repo> --state closed --json number,title,labels,updatedAt \
  | jq '[.[] | select(.updatedAt > "YYYY-MM-DDT00:00:00Z")]'

# Open PRs
gh pr list -R <repo> --json number,title,labels,updatedAt,headRefName

# Recently merged PRs (last 30 days)
gh pr list -R <repo> --state merged --json number,title,labels,updatedAt \
  | jq '[.[] | select(.updatedAt > "YYYY-MM-DDT00:00:00Z")]'
```

Present a summary: "What's happening in `<name>`" — grouped by theme
(infrastructure, skills, docs, etc.).

### 5. Run type-specific comparison

#### Fork type — file-level diff

Compare these categories between the local clone and this workspace:

| Category | Path pattern | Method |
|----------|-------------|--------|
| Scripts | `.agent/scripts/` | File listing diff + content diff for shared files |
| Skills | `.claude/skills/` | Directory listing diff |
| ADRs | `docs/decisions/` | File listing diff + title comparison |
| Templates | `.agent/templates/` | File listing diff |
| Knowledge | `.agent/knowledge/` | File listing diff |
| Makefile | `Makefile` | `.PHONY` target listing diff |
| Config | `AGENTS.md`, `ARCHITECTURE.md` | Size/hash as change indicator |

For each category, identify:
- **Upstream-only files**: candidates to port
- **Shared files with differences**: potential enhancements (show brief diff summary)
- **Local-only files**: informational, no action needed

Auto-classify items matching `domain_patterns` as "domain-specific — probably skip".

#### Inspiration type — survey or changelog

**First run** (no digest exists yet): Perform an initial survey.
- Read the repo's README, directory structure, and key config files
- Produce a structured summary mapped to workspace categories:
  governance model, skills/commands, isolation strategy, identity management,
  testing approach, CI/CD patterns, documentation patterns
- Focus on `interest_areas` from the registry entry
- Record the summary in the digest

**Subsequent runs** (digest exists): Changelog mode.
- Use the GitHub compare API to see what changed since the last-checked SHA:
  ```bash
  gh api repos/<owner>/<repo>/compare/<last-sha>...<current-sha> \
    --jq '{commits: [.commits[].commit.message], files: [.files[].filename]}'
  ```
- Cross-reference with GitHub activity from step 4
- Highlight changes relevant to `interest_areas`
- Read changed files in the local clone for detailed understanding
- Summarize what's new since last check

### 6. Present findings interactively

**Section 1: Upstream Activity**
- Summary of open/recent issues and PRs from step 4

**Section 2: Findings**
- Fork type: new/changed files with domain-specific auto-tags
- Inspiration type: survey results or changelog highlights

For each **new or changed** item not already decided in the digest, present
the finding with a brief description and ask the user to choose:

- **Port/Adapt now** — add to batch for a PR
- **Open issue** — create a workspace issue to track it
- **Skip** (with reason) — record in digest, won't be re-prompted
- **Defer** — record in digest, will be re-prompted on next run

Items with existing decisions are shown as a summary at the end.

### 7. Act on decisions

**Port/Adapt now**: Batch all "port now" items into a single workspace
worktree. Copy/adapt files, commit with atomic commits per item, and open
a single PR.

```bash
# If there are items to port, create a worktree
# (The skill is already running in an issue worktree or can create one)
# Copy files from the scratchpad clone, adapt as needed
# Commit each logical change separately
```

**Open issue**: Create an issue on the workspace repo for each deferred item.

```bash
BODY_FILE=$(mktemp /tmp/gh_body.XXXXXX.md)
cat << EOF > "$BODY_FILE"
## Enhancement from <name>

<description of what to port/adapt>

Source: <repo> — <file or pattern>

Identified by the \`inspiration-tracker\` skill.

---
**Authored-By**: \`$AGENT_NAME\`
**Model**: \`$AGENT_MODEL\`
EOF
gh issue create --title "<title>" --body-file "$BODY_FILE" --label "enhancement"
rm "$BODY_FILE"
```

**Skip/Defer**: Record in digest only.

### 8. Update digest

Write/update `.agent/knowledge/inspiration_<name>_digest.md`:

```markdown
# Inspiration Digest: <name>

Type: fork | inspiration
Last checked: YYYY-MM-DD
Repo: <owner>/<repo> @ <commit-sha>

## Survey Summary (inspiration type only)

<structured summary from initial survey>

## Activity Snapshot

- N open issues, M open PRs
- Notable: <brief summary of relevant items>

## Ported/Adapted

- `feature` — adapted in PR #N (YYYY-MM-DD)

## Skipped

- `feature` — reason (YYYY-MM-DD)

## Deferred

- `feature` — revisit later (YYYY-MM-DD)

## Pending Issues

- `feature` — Issue #N (YYYY-MM-DD)
```

Commit the digest update in the workspace repo (in the current worktree or
via a skill worktree if running without an issue context).

### 9. Interactive add flow

When invoked with `add` or `add <url>`:

1. **Get the repo**: If URL provided, extract `owner/repo`. Otherwise, ask:
   - Enter a GitHub repo URL or `owner/repo` slug
   - Search the web for projects (optionally with user-supplied search terms)
   - Browse search results and select

2. **Validate**: Check the repo exists via `gh repo view -R <repo>`.

3. **Choose type**: Ask fork or inspiration.

4. **Configure type-specific fields**:
   - Fork: ask which categories to compare, any domain patterns to filter
   - Inspiration: ask which interest areas to focus on

5. **Add to registry**: Append the new entry to `inspiration_registry.yml`.

6. **Optionally run first check**: Offer to immediately check the newly added project.

## Guidelines

- **Interactive, not autonomous** — always present findings and let the user
  decide. Never auto-port without confirmation.
- **One project per run** — check one project at a time for focused review.
- **Idempotent** — safe to re-run. Items with decisions aren't re-prompted
  (except deferred items, which resurface).
- **Scratchpad clones are ephemeral** — all clones in
  `.agent/scratchpad/inspiration/<name>/` (gitignored). Registry and digests
  are git-tracked and portable across machines.
- **Shallow clones for reading, GitHub API for history** — local clones use
  `--depth=1` for speed; changelog tracking uses the GitHub compare API
  instead of local git history. This keeps clones lightweight.
- **GitHub API rate limits** — the skill uses ~6-7 API calls per project per
  run (issues, PRs, compare). Authenticated GitHub API allows 5000 calls/hour,
  so periodic manual use is well within limits.
- **Domain pattern filtering** — fork type only. Reduces noise for repos that
  share structure but have domain-specific content.
- **Skill worktree for digest commits** — use `--skill inspiration-tracker`
  worktrees for digest-only updates (no issue needed). For porting items,
  create an issue and use an issue worktree.
- **Commit digest updates** — so decisions are shared across agents and sessions.
