---
name: plan-task
description: Generate a principles-aware work plan for an issue. Saves to `.agent/work-plans/` in the repo that owns the issue and commits as the first step on the feature branch.
session_scope: both
---

# Plan Task

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
/plan-task <N> [--no-pr]
/plan-task <owner/repo#N> [--no-pr]
```

- `--no-pr` — skip draft PR creation (step 8). The plan is still committed
  locally. Useful when working offline or when a PR isn't needed yet.

A bare number `<N>` is issue N of the repository of the checkout the skill
is run in (the session's root). `owner/repo#N` names that repository
explicitly. An issue of another repository is planned from a checkout of
that repository (the session-root rule): `issue_repo.sh` refuses it here
(exit 6) before any record is read or written. Below, `<ref>` is the
reference as given and `<N>` its number. Every `gh` call names the
repository with `-R "github.com/$_REPO"`, never the one `gh` would pick
from the current directory; `$_REPO` comes from
`$WS_ROOT/.agent/scripts/issue_repo.sh <ref>`, asked again at the head of
every code block that needs it, because each block is a new shell.

## Overview

Generate a work plan for an issue with principles and ADR awareness. This
complements EnterPlanMode — it adds the governance lens, not a competing
planning system. Use EnterPlanMode for general codebase exploration and
approach design; use this skill to ensure the plan accounts for workspace
principles, ADR compliance, and downstream consequences.

**Lifecycle position**: review-issue → **plan-task** → review-plan → implement → review-code

## Steps

### 1. Read the issue and any review comments

Find the repository first, then try git-bug for offline-capable issue
reading, then fall back to `gh`. The block's first lines ask
`issue_repo.sh` for the repository and print it as a `Repository:` line;
show that line in the report. On a non-zero exit the block prints the exit
code and makes no `gh` call; do what this table says for that code.

#### Repository by exit code

| Exit | What this skill does |
|---|---|
| 0 | Proceeds. Every `gh issue` and `gh pr` call carries `-R "github.com/$_REPO"`, the git-bug lookup uses `$_REPO`, and step 4's type comes from comparing `$_REPO` with the workspace's repository. |
| 1 | Stops: the reference is neither `<N>` nor `owner/repo#N`. Show the usage. |
| 2, 3 | Stops and shows the helper's message. Exit 2 names the repository `gh` resolves here and this checkout's own, and gives this checkout's `owner/repo#N` to pass, the `gh repo set-default` to run or `GH_REPO` to unset. Exit 3 says this folder is no checkout to work an issue from (no git repository, a package worktree's top folder, or a package worktree whose issue checkout cannot be found) and where to run from. |
| 4 | An ordinary case: this checkout has no GitHub repository, so no `gh` call is made and the git-bug lookup (by GitHub URL) is skipped. Ask the owner for the issue's text. Step 4's worktree type is the session's root (`workspace` in a workspace session, `project` in a project session); the plan's `## Issue` line is the reference as given, with no URL; step 8 (draft PR) is skipped, as with `--no-pr`, and the report says why. An origin through an SSH host alias (`git@<alias>:owner/repo.git`) or `ssh.github.com:443` lands here too although `gh` resolves it: only an origin URL on github.com is read as a GitHub repository, so use the bare number there (`owner/repo#N` is refused, exit 6). |
| 5 | `gh` had to be asked which repository it resolves here and could not answer (its message is shown). Say which read failed, then as for exit 4: the issue's text from the owner, the type from the session's root, no URL, no draft PR. |
| 6 | Stops before any record is read or written and before anything is pushed or posted: `owner/repo#N` names another repository than this checkout's (or any `owner/repo#N` in a checkout from which no GitHub repository is read, exit 4's case, where it cannot be shown to be this checkout's). Show the helper's message; the plan is made from a checkout of the named repository. |
| any other (127: the script is missing — a project session with no user tier, or an older workspace checkout) | Stops and shows the message on stderr. |

**A dispatched phase cannot ask the owner.** When this skill runs from a
`/run-issue` handoff and step 1 gives exit 4 or 5, it cannot plan without
the issue's text: it writes no plan, appends a `## Plan Authored` entry
(step 7's call, with no `**Plan**` line) with `**Status**: partial` and a
line naming the text it needs (the title and body of issue `<ref>`) with
the helper's message, and ends. The host asks the owner.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
_REPO=$("$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>") || { _rc=$?; echo "issue_repo.sh exit $_rc: this block makes no gh call; see the Repository by exit code table"; exit "$_rc"; }
echo "Repository: $_REPO"
# git-bug first (offline-capable) — provides title, body, and status
# Look up by GitHub URL metadata (git-bug human_id != GitHub issue number)
ISSUE_TITLE=""
ISSUE_BODY=""
if command -v git-bug &>/dev/null && command -v jq &>/dev/null; then
    _REPO_SLUG="$_REPO"  # from issue_repo.sh, above
    _GITHUB_URL="https://github.com/${_REPO_SLUG}/issues/<N>"
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
    _GH_JSON=$(gh issue view <N> -R "github.com/$_REPO" --json title,body,labels,comments,url 2>/dev/null || echo "")
    if [ -n "$_GH_JSON" ]; then
        [ -z "$ISSUE_TITLE" ] && ISSUE_TITLE=$(echo "$_GH_JSON" | jq -r '.title')
        [ -z "$ISSUE_BODY" ] && ISSUE_BODY=$(echo "$_GH_JSON" | jq -r '.body')
    fi
fi
```

If neither source is available, stop and inform the user: "Cannot read issue
#<N> — git-bug has no cached data and `gh` is unavailable."

Check for review-issue comments — they contain scope assessment, principle
flags, and ADR notes that should inform the plan. Comments are available from
`gh` output (`.comments[]`) or from git-bug JSON (`.comments[1:]` — index 0
is the issue body).

### 2. Load governance context

- `$WS_ROOT/.agent/knowledge/principles_review_guide.md` — evaluation criteria
- `docs/principles.md` — workspace principles
- `docs/decisions/*.md` — ADR titles (read triggered ADRs in full)
- Project-level governance if the issue targets a project repo

### 3. Explore the codebase

Read relevant files to understand the current state:
- Files that will be modified
- Tests that exist for those files
- Documentation that references them
- Use the consequences map to identify what else may be affected
- Look for prior art before designing something new: existing code in the
  project, features of the tools already in use, and outside practice. Note
  what was found and what was taken or rejected; the plan records it
- Name the goal the work serves and the design section it falls under,
  for every plan (the plan's `## Serves` line, step 5). For the workspace,
  the goal is a section name under `$WS_ROOT/README.md#workspace-goals`
  and the section is cited by its anchor, as `docs/design.md#<section>`.
  Work inside a part that has its own design (ADR-0022) names the root
  goal it serves and may also name the part's own goal, citing the part's
  design section as `<path>/design.md#<section>`, `<path>` being the
  design file's directory (`tools/repos-manifest/docs/design.md#<section>`).
  For a project, use its own goals and design document, found where
  `project_setting.sh doc <name> goals|design` says it keeps them (never a
  guessed path), or write "none"
- Ask whether the change alters the design picture (how the parts fit
  today) and, if so, which section of the owning repo's design document
  changes in the same change. For the workspace, the section list and the
  Status key are in `$WS_ROOT/docs/design.md#the-design`; cite the section
  by its anchor, as `docs/design.md#<section>`. The section that changes
  may be a part's own design (`<path>/design.md#<section>`, ADR-0022):
  the part owns its inside, and the root's design changes only where what
  crosses the part's boundary changes. For a project, name the
  section of the project's own design document, or say there is none

### 4. Ensure correct worktree (hard check)

Before writing or committing the plan, resolve the work-plans directory
using the shared helper. The block asks `issue_repo.sh` first: records are
resolved only for this checkout's issue (exit 0, or 4 and 5 for a bare
number), and on any other exit the block stops. The resolver refuses to
return a path when you're outside the matching worktree — this is
deliberate (issue #147): silent writes into the main tree were stranding
per-issue artifacts on no branch.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>" >/dev/null; _rc=$?; case "$_rc" in 0|4|5) ;; *) echo "issue_repo.sh exit $_rc: this block reads and writes no records; see the Repository by exit code table"; exit "$_rc" ;; esac
# shellcheck source=../../../.agent/scripts/_resolve_work_plans_dir.sh
source $WS_ROOT/.agent/scripts/_resolve_work_plans_dir.sh
WORK_PLANS_DIR=$(resolve_work_plans_dir <N>) || {
    # Resolver printed remediation guidance to stderr — surface it to the
    # user and stop. Do not write plan.md / progress.md anywhere else.
    exit 1
}
```

If the resolver aborts, the message tells the user to create or enter the
matching worktree. Typical remediation:

**Workspace issues** (changes to `.agent/`, `docs/`, configs, skills):

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/worktree_create.sh --issue <N> --type workspace
source $WS_ROOT/.agent/scripts/worktree_enter.sh --issue <N> --type workspace
```

**Project repo issues** (changes to the managed project repo):

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
$WS_ROOT/.agent/scripts/worktree_create.sh --issue <N> --type project
source $WS_ROOT/.agent/scripts/worktree_enter.sh --issue <N> --type project
```

To determine the type, compare the repository step 1 printed with the
workspace's own, with no `gh` call: `--type workspace` when they are the
same repository, `--type project` otherwise. On exit 4 or 5 in step 1 the
type is the session's root instead (`workspace` in a workspace session,
`project` in a project session). If a worktree for the issue already
exists, just enter it.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
_REPO=$("$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>") || { _rc=$?; echo "issue_repo.sh exit $_rc: this block makes no gh call; see the Repository by exit code table"; exit "$_rc"; }
echo "Repository: $_REPO"
# shellcheck source=../../../.agent/scripts/_issue_helpers.sh
source "$WS_ROOT/.agent/scripts/_issue_helpers.sh"
_WS_SLUG=$(extract_gh_slug "$(git -C "$WS_ROOT" remote get-url origin 2>/dev/null)")
if [ -n "$_WS_SLUG" ] && [ "${_REPO,,}" = "${_WS_SLUG,,}" ]; then
    echo "type: workspace"
else
    echo "type: project"
fi
```

Use `$WORK_PLANS_DIR` (from the resolver) as the base path in step 5;
steps 6, 7 and 8 resolve it again in their own blocks — do not construct
`$WS_ROOT/.agent/work-plans/issue-<N>/` by hand.

### 5. Generate the plan

Write a plan to `${WORK_PLANS_DIR}/plan.md` (resolved in step 4). Create
the directory if it doesn't exist — it also holds review artifacts (Gemini
prompts/findings) alongside the plan:

```markdown
# Plan: <issue-title>

## Issue

https://github.com/<owner/repo>/issues/<N>  (the repository step 1 printed; on exit 4 or 5 in step 1, write the issue reference as given instead, with no URL)

## Context

<Brief summary of current state and what needs to change>

## Approach

<Step-by-step implementation plan>

1. **<step>** — <what and why>
2. ...

## Files to Change

| File | Change |
|------|--------|
| `path/to/file` | Description of change |

## Prior Art

<What was looked at (existing code, tools already in use, outside practice)
and what was taken or rejected. "Nothing new is being built" is a valid
answer when true.>

## Serves

<One line: the goal this work serves and the design section it falls
under. For the workspace, the goal by its section name under `## Workspace
goals` in `README.md`, and the section by its anchor, as
`docs/design.md#<section>`. Work inside a part with its own design
(ADR-0022) may also cite the part's section, as
`<path>/design.md#<section>`. For a project, its own goals and design
document, or "none".>

## Design Picture

<Does this change alter how the parts fit? If yes, which section of the
owning repo's design document changes, in this PR (for the workspace, cite it
by its anchor, as `docs/design.md#<section>`, or a part's own design as
`<path>/design.md#<section>`; a project's own design
document, if it keeps one; if the project has none, say so). If no, say "No
change to the design picture".>

## Principles Self-Check

| Principle | Consideration |
|---|---|
| <relevant principle> | How this plan accounts for it |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| <relevant ADR> | Yes/No | <explanation> |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| <item from consequences map> | <dependent item> | Yes / No — follow-up |

## Open Questions

- <anything that needs human input before implementation>

## Estimated Scope

<single PR / multiple PRs / needs breakdown>
```

### 6. Commit the plan

Commit `plan.md` on its own first. The progress entry in step 7 cites the
commit that contains the plan text (ADR-0013's plan-commit SHA), so the
plan has to be committed before the entry can name it. The block is a new
shell: it resolves the work-plans directory itself (with step 4's guard),
and the summary goes in through a quoted heredoc, so a backtick or `$` in
it is never run or expanded:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>" >/dev/null; _rc=$?; case "$_rc" in 0|4|5) ;; *) echo "issue_repo.sh exit $_rc: this block reads and writes no records; see the Repository by exit code table"; exit "$_rc" ;; esac
# shellcheck source=../../../.agent/scripts/_resolve_work_plans_dir.sh
source "$WS_ROOT/.agent/scripts/_resolve_work_plans_dir.sh"
WORK_PLANS_DIR=$(resolve_work_plans_dir <N>) || exit 1
SUMMARY=$(cat <<'SUMMARY_EOF'
<one-line summary of the approach>
SUMMARY_EOF
)
git add "$WORK_PLANS_DIR/plan.md"
git commit -m "Add work plan for #<N>

$SUMMARY"
"$WS_ROOT/.agent/scripts/review_progress.sh" plan-sha --plan "$WORK_PLANS_DIR/plan.md"
```

`plan-sha` prints the last commit that touched `plan.md` (never the branch
head, never a blob SHA) and refuses an uncommitted plan. Re-run it after
every later plan revision; the new `## Plan Authored` entry for that
revision cites the new SHA.

### 7. Record the plan in progress.md

Append a `## Plan Authored` entry (ADR-0013's name for what this step used
to write as `## Plan`) through the same persistence call `review-code`,
`triage-reviews`, and `address-findings` use. It creates the file with
frontmatter and the `--title` heading when absent, and applies the
`PROGRESS_PERSISTENCE_STRICT` switch: compatibility (default) keeps this
skill's previous inline commit in the current worktree, but refuses (exit 4)
exactly as strict does when that checkout is not issue `<N>`'s (a main
checkout on its default branch, another issue's worktree; issue 437); it
prints the "would have aborted" notice and commits only when
`WORKTREE_ISSUE` names another issue or `WORK_PLANS_DIR_OVERRIDE` is set;
strict (`--strict`, or the env var set to `1`) goes through
`resolve_work_plans_dir()` and `progress_append.sh`. Echo the printed line
in step 9's report. As in step 4, the block asks `issue_repo.sh` first and
writes nothing for an issue that is not this checkout's. It is a new
shell, so it resolves the work-plans directory and the plan SHA itself.
The issue title and the entry's text go in through quoted heredocs, so a
backtick or `$` in them is never run or expanded; only the `**Plan**` line
is filled from the shell, by `printf`. (A dispatched phase's partial entry,
step 1, has no plan: it leaves out the `PLAN_SHA`, `PLAN_REL` and `printf`
lines.)

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>" >/dev/null; _rc=$?; case "$_rc" in 0|4|5) ;; *) echo "issue_repo.sh exit $_rc: this block reads and writes no records; see the Repository by exit code table"; exit "$_rc" ;; esac
# shellcheck source=../../../.agent/scripts/_resolve_work_plans_dir.sh
source "$WS_ROOT/.agent/scripts/_resolve_work_plans_dir.sh"
WORK_PLANS_DIR=$(resolve_work_plans_dir <N>) || exit 1
PLAN_SHA=$("$WS_ROOT/.agent/scripts/review_progress.sh" plan-sha --plan "$WORK_PLANS_DIR/plan.md") || exit 1
PLAN_REL="${WORK_PLANS_DIR#"$(git rev-parse --show-toplevel)/"}/plan.md"
ISSUE_TITLE=$(cat <<'TITLE_EOF'
<issue title>
TITLE_EOF
)
{
cat <<'ENTRY_HEAD'
## Plan Authored
**Status**: complete
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <agent name> (<model>)
ENTRY_HEAD
printf '**Plan**: `%s` at `%s`\n\n' "$PLAN_REL" "$PLAN_SHA"
cat <<'ENTRY_BODY'
<1-2 sentence summary of the approach>
ENTRY_BODY
} | $WS_ROOT/.agent/scripts/review_progress.sh persist --issue "<N>" --branch "$(git branch --show-current)" \
    --title "$ISSUE_TITLE" [--strict]
```

`**Plan**` is the entry's correlation key: `review-plan` and the round
counter match on that SHA, so it must be the value `plan-sha` printed.

### 8. Create or update a draft PR

**Skip this step** if:
- The user passed `--no-pr`, or
- `gh` is unavailable (`command -v gh &>/dev/null && gh auth status &>/dev/null` fails), or
- step 1 gave exit 4 or 5 (no GitHub repository, or `gh` could not answer)

If skipped, note in the report: "Draft PR skipped (offline, no GitHub
repository, or `--no-pr`). The plan is committed locally on branch
`<branch-name>`."

Otherwise, push the branch and create (or update) a draft PR with a `[PLAN]`
title prefix and the plan as the body. The prefix prevents agents from
confusing the PR number with the issue number. The repository is asked for
again (a new shell). The issue title goes in through a quoted heredoc, so a
backtick or `$` in it is never run or expanded. The branch is pushed to
origin; when origin is another repository than `$_REPO` (a package
worktree's issue checkout whose origin is a fork of the manifest header's
repository), the pull request's head names origin's owner
(`--head <owner>:<branch>`), which `gh pr create -R` needs to find the
branch in the fork. An existing pull request is the one from that head:
the branch name and the head repository's owner both match (another
fork's pull request can carry the same branch name); when more than one
matches, the block stops and lists them:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
_REPO=$("$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>") || { _rc=$?; echo "issue_repo.sh exit $_rc: this block makes no gh call; see the Repository by exit code table"; exit "$_rc"; }
echo "Repository: $_REPO"
# Push current branch (name may vary: feature/issue-<N> or feature/ISSUE-<N>-<desc>)
git push -u origin HEAD

# The issue title step 1 read, written in literally (a new shell); the
# quoted heredoc keeps a backtick or $ in it from running or expanding
ISSUE_TITLE=$(cat <<'TITLE_EOF'
<issue title>
TITLE_EOF
)
# shellcheck source=../../../.agent/scripts/_resolve_work_plans_dir.sh
source "$WS_ROOT/.agent/scripts/_resolve_work_plans_dir.sh"
# shellcheck source=../../../.agent/scripts/_issue_helpers.sh
source "$WS_ROOT/.agent/scripts/_issue_helpers.sh"
WORK_PLANS_DIR=$(resolve_work_plans_dir <N>) || exit 1
CURRENT_BRANCH=$(git branch --show-current)
# The pull request's head: the branch just pushed to origin, with origin's
# owner when origin is another repository than $_REPO (a fork)
_ORIGIN_SLUG=$(extract_gh_slug "$(git remote get-url origin 2>/dev/null)")
_HEAD="$CURRENT_BRANCH"
_HEAD_OWNER="${_REPO%%/*}"
if [ -n "$_ORIGIN_SLUG" ] && [ "${_ORIGIN_SLUG,,}" != "${_REPO,,}" ]; then
    _HEAD="${_ORIGIN_SLUG%%/*}:$CURRENT_BRANCH"
    _HEAD_OWNER="${_ORIGIN_SLUG%%/*}"
fi

# An existing PR from this head: the branch name and the head repository's
# owner (--head takes no owner:branch, and another fork's PR can carry the
# same branch name). More than one: stop and list them.
EXISTING_PR=$(gh pr list -R "github.com/$_REPO" --head "$CURRENT_BRANCH" --json url,headRepositoryOwner \
    --jq ".[] | select((.headRepositoryOwner.login | ascii_downcase) == \"${_HEAD_OWNER,,}\") | .url" 2>/dev/null || echo "")
if [ "$(printf '%s\n' "$EXISTING_PR" | grep -c .)" -gt 1 ]; then
    echo "More than one open pull request into $_REPO from $_HEAD_OWNER's $CURRENT_BRANCH; not editing any:"
    printf '%s\n' "$EXISTING_PR"
    exit 1
fi

# Build PR body: prepend Closes reference, then plan content
BODY_FILE=$(mktemp /tmp/gh_body.XXXXXX.md)
printf 'Closes #<N>\n\n' > "$BODY_FILE"
cat "$WORK_PLANS_DIR/plan.md" >> "$BODY_FILE"

if [ -n "$EXISTING_PR" ]; then
    # Update existing PR title and body
    gh pr edit "$EXISTING_PR" -R "github.com/$_REPO" --title "[PLAN] $ISSUE_TITLE" --body-file "$BODY_FILE"
else
    # Create new draft PR
    gh pr create -R "github.com/$_REPO" --draft --head "$_HEAD" --title "[PLAN] $ISSUE_TITLE" --body-file "$BODY_FILE"
fi
rm -f "$BODY_FILE"
```

### 9. Report to user

Summarize:
- What the plan proposes
- Which principles and ADRs were considered
- Any open questions that need input
- Link to the draft PR (or note that PR creation was skipped)
- Pointer to the "During implementation" section below, so the
  implementer knows to keep the plan in sync with landed code

## During implementation

The `plan-task` skill's primary artifact is the committed plan file
created in steps 5–6; step 8 publishes that plan into a draft PR.
Implementation then proceeds on the same branch — and typically deviates
from the plan: types get refined, functions change signatures, a "pure
logic" module picks up a dependency. Keep the plan in sync as this
happens so the file stays usable reference material — for Copilot's
plan-file review, for `review-code`, and for the next agent who picks
up the work.

1. **Inline edits are the default.** When implementation diverges from the
   plan in any way — wording, method names, file paths, dependency
   choices, a test contract that tightened during coding — edit the plan
   inline to match the landed code. Git history preserves the original
   planning state; nobody benefits from stale text at the top of an
   otherwise-current plan.

2. **Appended "Implementation Notes" only for rationale-bearing design
   pivots.** If the deviation is a real design decision whose *why* is
   not obvious from the code diff alone (e.g. "switched from `QGridLayout`
   to a custom layout because `QGridLayout` can't express slack-to-outside
   with shared inner edges"), make the inline edit *and* add a one-liner
   to an `## Implementation Notes` section at the bottom of the plan
   capturing the rationale. The section is for rationale only, not a
   changelog.

3. **Never append-only.** Leaving stale text at the top of the plan while
   listing "changes" in a section below misleads Copilot, human reviewers,
   and future onboarding agents — all of whom read the top first.

4. **Commit discipline.** Plan edits flow in commits alongside the code
   changes that triggered them (same commit when caught while coding;
   follow-up commit if caught later during review triage). Never amend a
   pushed commit just to update the plan.

This guidance is enforced at the instructions layer only. There is no
local hook for "did you update the plan"; the enforcement signal is
review feedback — Copilot's plan-drift flags and `review-code` catching
misalignment between the plan and the PR. If drift becomes a recurring
finding across multiple PRs, that's a signal the rule needs more teeth,
not that the rule is wrong.

The plan path under this rule is `$WS_ROOT/.agent/work-plans/issue-<N>/plan.md`
(the local convention; upstream uses `PLAN_ISSUE-<N>.md`). `review-plan`
already supports `--issue` / file-path forms, so it reads the live plan
file rather than the snapshotted PR body — inline plan edits stay
visible to plan review without further wiring.

## Guidelines

- **Generate, don't just evaluate** — this skill produces a plan, not a
  review of an existing plan. For reviewing plans, use `review-plan` on the
  draft PR.
- **Concrete, not generic** — "Update tests" is not a plan step. "Add test
  for edge case X in `test_foo.py`" is.
- **A new `test_*.sh` needs its exec bit** — when a plan step creates a new
  shell script, say `chmod +x` in the step. The
  `check-shebang-scripts-are-executable` pre-commit hook fails the commit
  otherwise, so the exec bit belongs in the plan as an explicit step rather
  than as an implicit assumption.
- **Flag conflicts early** — if the plan would violate a principle or ADR,
  say so and propose an alternative.
- **Include open questions** — if the approach depends on a choice the user
  should make, list it. Don't guess.
- **Keep it short** — a plan should be 30-80 lines. If it's longer, the
  task may need to be broken down.
