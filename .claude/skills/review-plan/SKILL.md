---
name: review-plan
description: Independent evaluation of a committed work plan before implementation begins. Checks scope, approach, principle alignment, consequences, and ROS conventions.
session_scope: both
---

# Review Plan

## Workspace root

This skill can run in a **project** session — a session started in a project
checkout, not in the workspace. There, `$WS_ROOT/.agent/scripts/...` does not resolve:
those paths belong to the workspace, and the cwd is somewhere else entirely.

Every workspace path below is therefore written `$WS_ROOT/.agent/scripts/...`.
Resolve `$WS_ROOT` at the head of each command chain, because shell state does
not persist between tool calls:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/<script>" ...
```

`~/.claude/agent-workspace-root` is written by
`.agent/scripts/user_tier_install.sh`. It is a plain file, not an environment
variable and not `SessionStart` hook output — hook stdout is context text and
never reaches a tool call's shell (ADR-0016).

**The `|| echo .` fallback is required, not decoration.** The user tier is
optional — `--check` and ADR-0016 both say so — and on a machine without it
the file does not exist. A bare `cat` would leave `$WS_ROOT` empty and turn
every command below into `/.agent/scripts/...`, which is worse than the
relative path it replaced. With the fallback, `$WS_ROOT` is `.` and a
workspace session behaves exactly as it did before this idiom existed.

## Usage

```
/review-plan <pr-number>
/review-plan <path-to-plan.md>
/review-plan --issue <N>
```

- `<pr-number>` — read the plan file at a PR's head commit
- `<path-to-plan.md>` — read the plan directly from a local file
- `--issue <N>` — resolve to `$WS_ROOT/.agent/work-plans/issue-<N>/plan.md`;
  `--issue <owner/repo#N>` names this checkout's repository explicitly

The file path and `--issue` forms enable offline plan review without a PR.

A bare number is a pull request or issue of the repository of the checkout
the skill is run in (the session's root). An issue of another repository
is reviewed from a checkout of that repository (the session-root rule):
`issue_repo.sh` refuses it here (exit 6) before any plan or record is read
or written. Every `gh` call names the
repository with `-R "github.com/$_REPO"`, never the one `gh` would pick from
the current directory; `$_REPO` comes from
`$WS_ROOT/.agent/scripts/issue_repo.sh <ref>` (step 0), asked again at the
head of every code block that needs it, because each block is a new shell.

## Overview

**Lifecycle position**: review-issue → plan-task → **review-plan** → implement → review-code

Independent evaluation of a committed work plan. The planner should not grade
their own work — this skill provides a second opinion before implementation
begins. Accepts draft PRs created by `plan-task` (typically prefixed `[PLAN]`),
local file paths, or issue numbers.

## Steps

### 0. Find the repository

`<ref>` is what `issue_repo.sh` is given, the same in every block below.
`<N>` is the issue number everywhere except in step 1's **PR number** form
and the Step 5 note's PR lines, where `<N>` is the pull request number and
`<issue>` the issue number:
- `--issue <N>` or `--issue <owner/repo#N>` form: that reference, as given
  (`<N>` is its number);
- file path form: the `<N>` of the path's `issue-<N>` directory;
- PR number form: the issue number in the current branch's name when it is
  `feature/issue-<issue>`, `feature/issue-<issue>-<description>` or
  `feature/ISSUE-<issue>-<description>` (case ignored), else the pull
  request number `<N>`. A bare number means this checkout's repository either
  way; the issue number matters only in a package worktree, whose manifest
  names the issue's repository for that number.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
_REPO=$("$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>") || { _rc=$?; echo "issue_repo.sh exit $_rc: this block makes no gh call; see the Repository by exit code table"; exit "$_rc"; }
echo "Repository: $_REPO"
```

Show the `Repository:` line in the report. On a non-zero exit the block
prints the exit code; do what this table says for that code.

#### Repository by exit code

| Exit | What this skill does |
|---|---|
| 0 | Proceeds. Every `gh pr` and `gh issue` call carries `-R "github.com/$_REPO"`, and the git-bug lookup uses `$_REPO`. |
| 1 | Stops: the reference is neither `<N>` nor `owner/repo#N`. Show the usage. |
| 2, 3 | Stops and shows the helper's message. Exit 2 names the repository `gh` resolves here and this checkout's own, and gives this checkout's `owner/repo#N` to pass, the `gh repo set-default` to run or `GH_REPO` to unset. Exit 3 says this folder is no checkout to work an issue from (no git repository, a package worktree's top folder, or a package worktree whose issue checkout cannot be found) and where to run from. |
| 4 | An ordinary case: this checkout has no GitHub repository, so no `gh` call is made. The PR number form is unavailable (say so; use `--issue <N>` or the file path). With `--issue <N>` the plan is read from the branch (step 1), and step 2 skips the issue read: "Issue context unavailable", the review rests on the plan alone. An origin through an SSH host alias (`git@<alias>:owner/repo.git`) or `ssh.github.com:443` lands here too although `gh` resolves it: `owner/repo#N` names the repository explicitly (the helper confirms it with `gh`). |
| 5 | `gh` had to be asked which repository it resolves here and could not answer (its message is shown). As for exit 4: no `gh` call, the plan from the branch, the review on the plan alone, saying which read failed. |
| 6 | Stops before any plan or record is read or written: `owner/repo#N` names another repository than this checkout's (or one the helper could not confirm as it). Show the helper's message; the plan is reviewed from a checkout of the named repository. |
| any other (127: the script is missing — a project session with no user tier, or an older workspace checkout) | Stops and shows the message on stderr. |

### 1. Read the plan

Determine the input form and locate the plan file. Detection heuristic:
- Starts with `--issue` → issue number form
- Contains `/` or ends with `.md` → file path form
- Otherwise → PR number form

**PR number** (e.g., `/review-plan 127`):

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
_REPO=$("$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>") || { _rc=$?; echo "issue_repo.sh exit $_rc: this block makes no gh call; see the Repository by exit code table"; exit "$_rc"; }
echo "Repository: $_REPO"
# The PR head is fetched from origin (below), so origin must be $_REPO: not
# so in a package checkout whose origin is a fork, where this form stops
# shellcheck source=../../../.agent/scripts/_issue_helpers.sh
source "$WS_ROOT/.agent/scripts/_issue_helpers.sh"
_ORIGIN_SLUG=$(extract_gh_slug "$(git remote get-url origin 2>/dev/null)")
if [ "${_ORIGIN_SLUG,,}" != "${_REPO,,}" ]; then
    echo "origin here is ${_ORIGIN_SLUG:-no GitHub repository}, not $_REPO: the PR number form is not supported in this checkout; use --issue <issue> or the plan's file path"
    exit 1
fi
# PR metadata (no body: it is a snapshot, not the plan; see below)
gh pr view <N> -R "github.com/$_REPO" --json title,baseRefName,headRefName,headRefOid,files,url

# Plan files the PR changes; each path names its issue as issue-<issue>
gh pr view <N> -R "github.com/$_REPO" --json files --jq '.files[].path | select(test("^[.]agent/work-plans/issue-[0-9]+/plan[.]md$"))'

# The issues the PR closes, as GitHub parses them (one number per line)
gh pr view <N> -R "github.com/$_REPO" --json closingIssuesReferences --jq '.closingIssuesReferences[].number'
```

The PR body is a snapshot of the plan, copied once when the PR was opened;
later edits to the plan file never reach it. Never review the body, or a PR
comment, as the plan: read the plan file at the PR's head commit. From the
top folder of the repository the PR belongs to, fetch the head first
(`<headRefOid>` from the first command; the Step 5 note reads the plan SHA
the same way). `origin` must be that repository (the first block stops
when it is not). The `cat-file` line is
there because `git show` prints the same "does not exist" message for a
commit that was never fetched as for a file missing at that commit; once
it passes, a failing `git show` can only mean the file is not at the head
(the no-plan-file case below). If the fetch or the `cat-file` check fails,
stop and show git's message; never read another copy:

```bash
git fetch -q origin "pull/<N>/head"
git cat-file -e "<headRefOid>^{commit}"
git show <headRefOid>:./.agent/work-plans/issue-<issue>/plan.md
```

- **One plan file**: `<issue>` is the number in its `issue-<issue>`
  directory; read the file in full with the `git show` above.
- **More than one plan file**: if exactly one of them has an `issue-<issue>`
  among the issues the PR closes, take it and read it as above. Otherwise
  (none matches, several match, or the PR closes no issue) stop and say
  which plan files the PR changes and which issues it closes.
- **No plan file** (for example a `[PLAN]` draft opened by
  `worktree_create.sh --plan-file`, which posts the plan as a PR comment,
  or a PR whose plan an earlier PR committed): `<issue>` is the issue the
  PR closes; if it closes none, or more than one, stop and say so (GitHub
  lists no closed issue for a PR into a branch other than the default one,
  such as a sub-issue's PR into its parent's branch). Read the
  plan at the PR's head with the `git show` above first. Only when that
  file does not exist at the head, read the one local fallback: the plan
  file in the checkout this skill runs from, which is the repository the
  PR belongs to, `$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<issue>/plan.md`.
  If it is not there, stop and say so, naming the path looked at. Never
  search other worktrees or registered projects (the **Issue number**
  form's workspace-worktree fallback): another repository's issue can have
  the same number. The
  head comes first so that a checkout behind the PR never supplies an
  older copy. Step 5 takes the SHA of a plan read at the head with `--ref`,
  and of the local fallback file with `--plan <path>`.

**File path** (e.g., `/review-plan $WS_ROOT/.agent/work-plans/issue-45/plan.md`):

Read the plan file directly. Extract the issue number from the path
(the `issue-<N>` directory name).

**Issue number** (e.g., `/review-plan --issue 45`):

Resolve to `$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<N>/plan.md`:
the repository this phase runs in, which for a dispatched phase is the
handoff's `worktree=` (for an issue of a package repository, the owning
checkout inside the package worktree; issue 429). If the file doesn't exist,
check the workspace worktree (`worktrees/workspace/issue-workspace-<N>/`)
first, then every registered project's worktree dir (a project's worktrees
live under its own root, issue #265). Enumerate every root's worktree dir
with the shared helper, the same way the worktree scripts do, rather than
deriving a glob. The block asks `issue_repo.sh` first and looks for no
plan when the issue is not this checkout's:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>" >/dev/null; _rc=$?; case "$_rc" in 0|4|5) ;; *) echo "issue_repo.sh exit $_rc: this block reads and writes no records; see the Repository by exit code table"; exit "$_rc" ;; esac
# The repository this phase runs in first …
plan="$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<N>/plan.md"
if [ -f "$plan" ]; then echo "$plan"; else
# shellcheck source=../../../.agent/scripts/_worktree_helpers.sh
source $WS_ROOT/.agent/scripts/_worktree_helpers.sh
WS_ROOT="$(git rev-parse --show-toplevel)"
# … then the workspace worktree (a workspace-repo issue's plan lives here) …
plan="$(wt_workspace_base "$WS_ROOT")/issue-workspace-<N>/.agent/work-plans/issue-<N>/plan.md"
if [ -f "$plan" ]; then echo "$plan"; else
    # … then every registered project's worktree dir.
    while IFS=$'\t' read -r _name wtdir; do
        plan="$wtdir/issue-"*"-<N>/.agent/work-plans/issue-<N>/plan.md"
        [ -f $plan ] && { echo "$plan"; break; }
    done < <(wt_registry_worktree_dirs "$WS_ROOT")
fi
fi
```

`wt_registry_worktree_dirs` covers every registered non-parent root's
worktree dir (in-tree or out-of-tree). If no match is found in any of these
locations, stop and inform the user.

### 2. Read the issue and any review-issue comments

Try git-bug first for offline-capable issue reading, then fall back to `gh`.
The repository is asked for again (a new shell); on exit 4 or 5 in step 0,
skip the block and go on with the plan alone (below). `<N>` is the issue
number from step 1.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
_REPO=$("$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>") || { _rc=$?; echo "issue_repo.sh exit $_rc: this block makes no gh call; see the Repository by exit code table"; exit "$_rc"; }
echo "Repository: $_REPO"
ISSUE_NUM="<N>"
# git-bug first (offline-capable) — provides title, body, and comments
# Look up by GitHub URL metadata (git-bug human_id != GitHub issue number)
ISSUE_TITLE=""
ISSUE_BODY=""
if command -v git-bug &>/dev/null && command -v jq &>/dev/null; then
    _REPO_SLUG="$_REPO"  # from issue_repo.sh, above
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
    _GH_JSON=$(gh issue view "$ISSUE_NUM" -R "github.com/$_REPO" --json title,body,labels,comments,url 2>/dev/null || echo "")
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

- `$WS_ROOT/.agent/knowledge/principles_review_guide.md` — evaluation criteria
- `docs/principles.md` — workspace principles
- `docs/decisions/*.md` — ADR titles (read triggered ADRs in full)

For project repo plans, also read:
- Project `PRINCIPLES.md` / `docs/principles.md` if it exists
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
- **Serves** (every plan): does the plan's `## Serves` line name the goal
  the work serves and the design section it falls under? For the
  workspace, the goal is a section name under
  `$WS_ROOT/README.md#workspace-goals` and the design section is cited by
  its anchor, as `docs/design.md#<section>`; for a project, the project's
  own goals and design document, found where `project_setting.sh doc
  <name> goals|design` says it keeps them (never a guessed path), or
  "none" (a project is not asked to keep either).
  Work inside a part that has its own design (ADR-0022) names the root
  goal it serves and may also name the part's own goal, citing the part's
  design section as `<path>/design.md#<section>`, `<path>` being the
  design file's directory (`tools/repos-manifest/docs/design.md#<section>`);
  the anchor is checked against that file.
  Copy the line, as checked, into this row's Notes. A
  missing line, work that serves no goal, or work that breaks a stated
  rule (for a workspace plan, a principle or a row of
  `$WS_ROOT/docs/design.md#rules`; for a project plan, the project's own
  stated rules, if it has any) is a finding. A project with no goals written down is not flagged for that.
  This is separate from the "Keep one current design" question below,
  which asks only whether the design picture changes

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
  - "Enforce what matters, as simply as possible" — does a rule that matters
    have the simplest check that fails when it is broken?
  - "Test what breaks" — does each fix come with a test that fails without
    it? (A docs- or skill-only change says so instead of planning one)
  - "Keep one current design" — does the plan say whether the change alters
    the design picture, and which design section changes? For the
    workspace, the section list and the Status key are in
    `$WS_ROOT/docs/design.md#the-design`, and the plan cites the section by
    its anchor, as `docs/design.md#<section>`. For work inside a part with
    its own design (ADR-0022), the section may be the part's
    (`<path>/design.md#<section>`), and the root's design text about the
    part keeps only what crosses its boundary. For a project, it names the
    section of the project's own design document, or says there is none
  - "Look for prior art before building" — does the plan say what was looked
    at and what was taken or rejected?

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
**Plan**: `$WS_ROOT/.agent/work-plans/issue-<issue>/plan.md` at `<plan-commit-sha>`

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
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
# Plan checked out locally (worktree / --issue / file path, and the
# PR-number form's local fallback when the head has no plan file):
$WS_ROOT/.agent/scripts/review_progress.sh plan-sha --plan <path>
# PR-number form, plan read at the PR head (every other PR case): fetch the
# head (<N> is the PR number), check the commit is here (stop if not),
# then ask by ref — no local checkout needed.
git fetch -q origin "pull/<N>/head"
git cat-file -e "<headRefOid>^{commit}"
$WS_ROOT/.agent/scripts/review_progress.sh plan-sha --plan ./.agent/work-plans/issue-<issue>/plan.md --ref "<headRefOid>"
```

(With `--ref`, `--plan` is relative to the current repository's top folder,
so run it in the repository the PR belongs to. In the PR-number form, read
the plan text the same way: `git show
<headRefOid>:./.agent/work-plans/issue-<issue>/plan.md`, from that top folder.)

**PR-less format** — when reviewing via `--issue` or file path (no PR exists),
replace the PR line:

```markdown
## Plan Review
**Status**: complete
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <agent name> (<model>)
**Verdict**: <ready | needs-work>

**Issue**: #<issue> — <issue-title>
**Plan**: `$WS_ROOT/.agent/work-plans/issue-<issue>/plan.md` at `<plan-commit-sha>`
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
**Plan**: `$WS_ROOT/.agent/work-plans/issue-<issue>/plan.md` at `<plan-commit-sha>`
**Serves**: <the plan's Serves line, as checked>
Plan looks solid. Ready for implementation.
```

### 6. Persist the review to progress.md

The report above is this skill's product; this step records it and must
never turn a finished review into a failed invocation. Append the report
as the entry, through the shared persistence call with `--soft`. The block
asks `issue_repo.sh` first and writes nothing for an issue that is not
this checkout's (step 0 has already stopped such a review). The issue
title goes in through a quoted heredoc, so a backtick or `$` in it is
never run or expanded:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>" >/dev/null; _rc=$?; case "$_rc" in 0|4|5) ;; *) echo "issue_repo.sh exit $_rc: this block reads and writes no records; see the Repository by exit code table"; exit "$_rc" ;; esac
ISSUE_TITLE=$(cat <<'TITLE_EOF'
<issue title>
TITLE_EOF
)
$WS_ROOT/.agent/scripts/review_progress.sh persist --issue "<issue>" \
    --branch "<plan's branch>" --title "$ISSUE_TITLE" --strict --soft <<'ENTRY'
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
- **Be specific** — "Consequence missing: changing `sonar_msgs` requires
  updating `mission_manager` subscriber" is useful. "Consider consequences" is
  not.
- **Skip N/A dimensions** — if the plan doesn't touch project repos, skip ROS
  conventions. If no ADRs are triggered, say so briefly.
- **review-issue feedback** — if `review-issue` was run, verify its findings are
  addressed. If they're not, flag it. If `review-issue` was not run, note this
  but don't penalize — it's an optional step.
