---
name: review-plan
description: Independent evaluation of a committed work plan before implementation begins. Checks scope, approach, principle alignment, consequences, and ROS conventions.
---

# Review Plan

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

Resolve to `.agent/work-plans/issue-<N>/plan.md`. If the file doesn't
exist, check worktrees (`worktrees/workspace/issue-workspace-<N>/` and
`worktrees/project/*/issue-*-<N>/`) for the plan file. If not
found, stop and inform the user.

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
## Plan Review: PR #<N> — <title>

**PR**: <url>
**Issue**: #<issue> — <issue-title>
**Plan file**: `.agent/work-plans/issue-<issue>/plan.md`

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

**PR-less format** — when reviewing via `--issue` or file path (no PR exists),
replace the PR header:

```markdown
## Plan Review: #<issue> — <title>

**Issue**: #<issue> — <issue-title>
**Plan file**: `.agent/work-plans/issue-<issue>/plan.md`
**Branch**: `<branch-name>` (if in a worktree, otherwise omit)
```

If no findings, output:

```markdown
## Plan Review: PR #<N> — <title>

**PR**: <url>
Plan looks solid. Ready for implementation.
```

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
