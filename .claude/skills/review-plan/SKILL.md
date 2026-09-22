---
name: review-plan
description: Independent evaluation of a committed work plan before implementation begins. Checks scope, approach, principle alignment, consequences, and ROS conventions.
session_scope: both
---

# Review Plan

## Workspace root

This skill can run in a **project** session — a session started in a project
checkout, not in the workspace. There, `.agent/scripts/...` does not resolve:
those paths belong to the workspace, and the cwd is somewhere else entirely.

Every workspace path below is therefore written `$WS_ROOT/.agent/scripts/...`.
Resolve `$WS_ROOT` at the head of each command chain, because shell state does
not persist between tool calls:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root)"
"$WS_ROOT/.agent/scripts/<script>" ...
```

`~/.claude/agent-workspace-root` is written by
`.agent/scripts/user_tier_install.sh`. It is a plain file, not an environment
variable and not `SessionStart` hook output — hook stdout is context text and
never reaches a tool call's shell (ADR-0016). In a workspace session the file
still holds the right path, so the same chain works in both.

## Usage

```
/review-plan <pr-number>
/review-plan <path-to-plan.md>
/review-plan --issue <N>
```

- `<pr-number>` — read the plan from a draft PR (existing behavior)
- `<path-to-plan.md>` — read the plan directly from a local file
- `--issue <N>` — resolve to `.agent/work-plans/issue-<N>/plan.md`

The file path and `--issue` forms enable offline plan review without a PR.

## Overview

**Lifecycle position**: review-issue → plan-task → **review-plan** → implement → review-code

Independent evaluation of a committed work plan. The planner should not grade
their own work — this skill provides a second opinion before implementation
begins. Accepts draft PRs created by `plan-task` (typically prefixed `[PLAN]`),
local file paths, or issue numbers.

## Steps

### 1. Read the plan

Determine the input form and locate the plan file. Detection heuristic:
- Starts with `--issue` → issue number form
- Contains `/` or ends with `.md` → file path form
- Otherwise → PR number form

**PR number** (e.g., `/review-plan 127`):

```bash
# PR metadata and body (plan is in the PR body)
gh pr view <N> --json title,body,baseRefName,headRefName,files,url

# Get the linked issue
gh pr view <N> --json body --jq '.body' | grep -o '#[0-9]*' | head -1
```

Find the plan file in the PR's changed files — it will be at
`.agent/work-plans/issue-*/plan.md`. Read it in full.

**File path** (e.g., `/review-plan .agent/work-plans/issue-45/plan.md`):

Read the plan file directly. Extract the issue number from the path
(the `issue-<N>` directory name).

**Issue number** (e.g., `/review-plan --issue 45`):

Resolve to `.agent/work-plans/issue-<N>/plan.md`. If the file doesn't exist,
check the workspace worktree (`worktrees/workspace/issue-workspace-<N>/`)
first, then every project worktree location — not just the legacy
`worktrees/project/*/issue-*-<N>/` glob, since a registered project's
worktrees live under its own root as of issue #265. Enumerate every root's
worktree dir with the shared helper, the same way the worktree scripts do,
rather than re-deriving the glob:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root)"
# shellcheck source=../../../.agent/scripts/_worktree_helpers.sh
source $WS_ROOT/.agent/scripts/_worktree_helpers.sh
WS_ROOT="$(git rev-parse --show-toplevel)"
# Workspace worktree first (a workspace-repo issue's plan lives here) …
plan="$(wt_workspace_base "$WS_ROOT")/issue-workspace-<N>/.agent/work-plans/issue-<N>/plan.md"
if [ -f "$plan" ]; then echo "$plan"; else
    # … then every project worktree location: registered roots and the
    # legacy / transition worktrees/project/<name>/ dirs.
    while IFS=$'\t' read -r _name wtdir; do
        plan="$wtdir/issue-"*"-<N>/.agent/work-plans/issue-<N>/plan.md"
        [ -f $plan ] && { echo "$plan"; break; }
    done < <(wt_registry_worktree_dirs "$WS_ROOT"; wt_legacy_worktree_dirs "$WS_ROOT")
fi
```

`wt_registry_worktree_dirs` covers every registered non-parent root's
worktree dir (in-tree or out-of-tree); `wt_legacy_worktree_dirs` covers the
pre-#265 `worktrees/project/<name>/` fallback for unregistered projects. If
no match is found in any of these locations, stop and inform the user.

### 2. Read the issue and any review-issue comments

Try git-bug first for offline-capable issue reading, then fall back to `gh`:

```bash
# git-bug first (offline-capable) — provides title, body, and comments
# Look up by GitHub URL metadata (git-bug human_id != GitHub issue number)
ISSUE_TITLE=""
ISSUE_BODY=""
if command -v git-bug &>/dev/null && command -v jq &>/dev/null; then
    _REPO_SLUG="<owner/repo>"  # resolve from git remote
    _GITHUB_URL="https://github.com/${_REPO_SLUG}/issues/${ISSUE_NUM}"
    _LIST_JSON=$(git bug bug -m "github-url=${_GITHUB_URL}" --format json 2>/dev/null || echo "")
    _BUG_ID=$(echo "$_LIST_JSON" | jq -r '.[0].human_id // empty' 2>/dev/null)
    if [ -n "$_BUG_ID" ]; then
        _SHOW_JSON=$(git bug bug show "$_BUG_ID" --format json 2>/dev/null || echo "")
        ISSUE_TITLE=$(echo "$_SHOW_JSON" | jq -r '.title // empty')
        ISSUE_BODY=$(echo "$_SHOW_JSON" | jq -r '.comments[0].message // empty')
    fi
    # Sync-on-miss: if not found, pull from GitHub and retry
    if [ -z "$ISSUE_TITLE" ]; then
        git bug bridge pull github &>/dev/null || true
        _LIST_JSON=$(git bug bug -m "github-url=${_GITHUB_URL}" --format json 2>/dev/null || echo "")
        _BUG_ID=$(echo "$_LIST_JSON" | jq -r '.[0].human_id // empty' 2>/dev/null)
        if [ -n "$_BUG_ID" ]; then
            _SHOW_JSON=$(git bug bug show "$_BUG_ID" --format json 2>/dev/null || echo "")
            ISSUE_TITLE=$(echo "$_SHOW_JSON" | jq -r '.title // empty')
            ISSUE_BODY=$(echo "$_SHOW_JSON" | jq -r '.comments[0].message // empty')
        fi
    fi
fi

# Fall back to gh if git-bug didn't provide the data
if [ -z "$ISSUE_TITLE" ] || [ -z "$ISSUE_BODY" ]; then
    _GH_JSON=$(gh issue view "$ISSUE_NUM" --json title,body,labels,comments,url 2>/dev/null || echo "")
    if [ -n "$_GH_JSON" ]; then
        [ -z "$ISSUE_TITLE" ] && ISSUE_TITLE=$(echo "$_GH_JSON" | jq -r '.title')
        [ -z "$ISSUE_BODY" ] && ISSUE_BODY=$(echo "$_GH_JSON" | jq -r '.body')
    fi
fi
```

If neither source is available, the review can still proceed using only the
plan file content — note in the report: "Issue context unavailable (offline,
no git-bug cache). Review based on plan content only."

Check for review-issue comments — they contain scope assessment, principle
flags, and ADR notes that the plan should address. Comments are available from
`gh` output (`.comments[]`) or from git-bug JSON (`.comments[1:]` — index 0
is the issue body).

### 3. Load governance context

- `.agent/knowledge/principles_review_guide.md` — evaluation criteria
- `docs/PRINCIPLES.md` — workspace principles
- `docs/decisions/*.md` — ADR titles (read triggered ADRs in full)

For project repo plans, also read:
- Project `PRINCIPLES.md` if it exists
- `.agents/README.md` for architecture context
- `.agents/review-context.yaml` for the compact relevance map (if available)

### 4. Evaluate the plan

Assess each dimension and assign a verdict (**Good** / **Needs work** / **Concern**):

#### Scope

- Is the plan appropriately sized for a single PR?
- If too large (>10 files, >3 major components), should it be split?
- If too vague ("update tests"), does it need specifics ("add test for X in
  `test_foo.py` covering edge case Y")?

#### Issue alignment

- Does the plan address the issue's requirements?
- If `review-issue` was run, does the plan address its findings?
- Are there issue requirements not covered by the plan?

#### File targeting

- Are the right files identified for modification?
- For project repos: cross-reference with `.agents/README.md` or
  `review-context.yaml` — are there related files (dependencies, tests,
  downstream consumers) that should also be listed?
- Are any unnecessary files included? (scope creep)

#### Consequences

- Does the plan's consequences table cover all items from the consequences map?
- For each "If we change X, also update Y" — is Y included in the plan?
- Are there cross-repo consequences not captured?

#### Principle alignment

- Does the plan align with relevant workspace principles?
- Focus on principles most likely to be violated:
  - "A change includes its consequences" — is the plan complete?
  - "Only what's needed" — is the plan minimal?
  - "Enforcement over documentation" — does a new rule have enforcement?
  - "Test what breaks" — are tests planned for risky logic?

#### ADR compliance

- Which ADRs are triggered by this plan's approach?
- Does the plan comply with their key requirements?

#### ROS conventions (for project repo plans)

- Does the approach follow ROS 2 patterns for the type of change?
- Topic naming, QoS choices, parameter handling, lifecycle management?
- Does it reference the right REPs (103, 105, 2004)?

### 5. Produce the report

```markdown
## Plan Review
**Status**: complete
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <agent name> (<model>)
**Verdict**: <ready | needs-work>

**PR**: <url> — <title>
**Issue**: #<issue> — <issue-title>
**Plan**: `.agent/work-plans/issue-<issue>/plan.md` at `<plan-commit-sha>`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good / Needs work / Concern | Assessment |
| Issue alignment | ... | ... |
| File targeting | ... | ... |
| Consequences | ... | ... |
| Principle alignment | ... | ... |
| ADR compliance | ... | ... |
| ROS conventions | ... | N/A for workspace plans |

### Findings

<Numbered list of specific findings, if any. Each with:>
1. **[Dimension]** — Description of finding and suggested resolution

### Summary

<1-3 sentence overall assessment. Is the plan ready for implementation?>

### Recommended Actions

- [ ] <specific action items before implementation begins>
```

The report IS the progress entry (step 6 appends it verbatim), so it opens
with ADR-0013's header fields. The heading is the plain type,
`## Plan Review`; the PR number and title live in the body, and `**Plan**`
carries the plan-commit SHA, which is how this entry is correlated with
the `## Plan Authored` entry it reviews. Get the SHA from the helper, not
by hand:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root)"
# Plan checked out locally (worktree / --issue / file path):
$WS_ROOT/.agent/scripts/review_progress.sh plan-sha --plan <path>
# PR-number form, reviewing from any tree: fetch the head, then ask by ref —
# no local checkout of the file is needed.
git fetch -q origin "<headRefName>"
$WS_ROOT/.agent/scripts/review_progress.sh plan-sha --plan .agent/work-plans/issue-<issue>/plan.md --ref "<headRefOid>"
```

(In the PR-number form, read the plan text the same way: `git show
<headRefOid>:.agent/work-plans/issue-<issue>/plan.md`.)

**PR-less format** — when reviewing via `--issue` or file path (no PR exists),
replace the PR line:

```markdown
## Plan Review
**Status**: complete
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <agent name> (<model>)
**Verdict**: <ready | needs-work>

**Issue**: #<issue> — <issue-title>
**Plan**: `.agent/work-plans/issue-<issue>/plan.md` at `<plan-commit-sha>`
**Branch**: `<branch-name>` (if in a worktree, otherwise omit)
```

If no findings, output:

```markdown
## Plan Review
**Status**: complete
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <agent name> (<model>)
**Verdict**: ready

**PR**: <url> — <title>
**Plan**: `.agent/work-plans/issue-<issue>/plan.md` at `<plan-commit-sha>`
Plan looks solid. Ready for implementation.
```

### 6. Persist the review to progress.md

The report above is this skill's product; this step records it and must
never turn a finished review into a failed invocation. Append the report
as the entry, through the shared persistence call with `--soft`:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root)"
$WS_ROOT/.agent/scripts/review_progress.sh persist --issue "<issue>" \
    --branch "<plan's branch>" --title "<issue title>" --strict --soft <<'ENTRY'
## Plan Review
...the report exactly as produced in step 5 (it already carries
   **Status** / **When** / **By** / **Verdict** and the **Plan** field)...
ENTRY
```

`--soft` turns any failure — the worktree resolver refusing because this
is not the issue's worktree, an invalid entry, a commit error — into one
printed line, "Progress persistence failed: <reason> — the report above
is unaffected", with exit 0. Echo that line (its stdout; notes stay on
stderr) to the user when it appears; they can append the entry by hand
from the issue's worktree. On success the printed line names where the
entry landed. Run this from the plan's worktree when possible (the
resolver then hits); from elsewhere, the notice is the expected outcome,
not an error.

## Guidelines

- **Evaluate, don't rewrite** — flag gaps and concerns. Don't generate an
  alternative plan.
- **Plans are guides, not contracts** — minor deviations during implementation
  are expected. Focus on structural issues: missing files, missing consequences,
  scope problems, principle violations.
- **Be specific** — "Consequence missing: changing `marine_msgs` requires
  updating `mission_manager` subscriber" is useful. "Consider consequences" is
  not.
- **Skip N/A dimensions** — if the plan doesn't touch project repos, skip ROS
  conventions. If no ADRs are triggered, say so briefly.
- **review-issue feedback** — if `review-issue` was run, verify its findings are
  addressed. If they're not, flag it. If `review-issue` was not run, note this
  but don't penalize — it's an optional step.
