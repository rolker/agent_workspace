---
name: review-issue
description: Evaluate a GitHub issue against workspace principles and ADRs before work begins. Posts findings as a comment on the issue and records them as an ADR-0013 Issue Review entry on the issue's progress timeline.
session_scope: both
---

# Review Issue

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
/review-issue <N>
/review-issue <owner/repo#N>
```

A bare number `<N>` is issue N of the repository of the checkout the skill
is run in (the session's root). `owner/repo#N` names that repository
explicitly. An issue of another repository is reviewed from a checkout of
that repository (the session-root rule): `issue_repo.sh` refuses it here
(exit 6) before anything is read, recorded or posted. Below, `<ref>` is the
reference as given and `<N>` its number.

## Overview

Evaluate an issue before work begins. Checks scope, principle alignment, ADR
relevance, repo placement, and dependencies. Posts findings as a comment on
the issue — does not modify the issue body.

**Which repository.** Every `gh` call names the repository with
`-R "github.com/$_REPO"`, never the one `gh` would pick from the current
directory (a wrong directory, or an `upstream` remote `gh` prefers over
origin, would post on another project's issue). `$_REPO` comes from
`$WS_ROOT/.agent/scripts/issue_repo.sh <ref>`, asked again at the head of
every code block that needs it, because each block is a new shell. Step 1
says what to do for each of its exit codes.

**Lifecycle position**: **review-issue** → plan-task → review-plan → implement → review-code

**This skill evaluates the issue itself** (is it well-scoped? in the right
repo? conflicting with ADRs?). For evaluating an implementation plan, use
`plan-task`. For evaluating a completed PR, use `review-code`.

## Steps

### 1. Read the issue

Find the repository first, then try git-bug for offline-capable issue
reading, then fall back to `gh`. The block's first lines ask
`issue_repo.sh` for the repository and print it as a `Repository:` line;
show that line in the report, so a wrong repository is seen before anything
is posted. On a non-zero exit the block prints the exit code and makes no
`gh` call; do what this table says for that code.

#### Repository by exit code

| Exit | What this skill does |
|---|---|
| 0 | Proceeds. Every `gh issue` call carries `-R "github.com/$_REPO"`, and the git-bug lookup uses `$_REPO`. |
| 1 | Stops: the reference is neither `<N>` nor `owner/repo#N`. Show the usage. |
| 2, 3 | Stops and shows the helper's message. Exit 2 names the repository `gh` resolves here and this checkout's own, and gives this checkout's `owner/repo#N` to pass, the `gh repo set-default` to run or `GH_REPO` to unset. Exit 3 says this folder is no checkout to work an issue from (no git repository, a package worktree's top folder, or a package worktree whose issue checkout cannot be found) and where to run from. Nothing is read or posted. |
| 4 | An ordinary case: this checkout has no GitHub repository, so no `gh` call is made and the git-bug lookup (by GitHub URL) is skipped. Ask the owner for the issue's text, or where the project keeps its issues. Run steps 2-6 on that text; step 7 posts nothing; step 8 records the review with no posted comment. An origin through an SSH host alias (`git@<alias>:owner/repo.git`) or `ssh.github.com:443` lands here too although `gh` resolves it: `owner/repo#N` names the repository explicitly (the helper confirms it with `gh`). |
| 5 | `gh` had to be asked which repository it resolves here and could not answer (its message is shown). Say which read failed, then as for exit 4: ask the owner for the issue's text, post nothing, record the review with no posted comment. |
| 6 | Stops before anything is read, recorded or posted: `owner/repo#N` names another repository than this checkout's (or one the helper could not confirm as it). Show the helper's message; the review is run from a checkout of the named repository. |
| any other (127: the script is missing — a project session with no user tier, or an older workspace checkout) | Stops and shows the message on stderr. |

**A dispatched phase cannot ask the owner.** When this skill runs from a
`/run-issue` handoff and step 1 gives exit 4 or 5, it cannot review
without the issue's text: it appends the step-8 entry with
`**Status**: partial` in place of `complete`, a line naming the text it
needs (the title and body of issue `<ref>`) with the helper's message, and
no review sections, and ends. The host asks the owner.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
_REPO=$("$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>") || { _rc=$?; echo "issue_repo.sh exit $_rc: this block makes no gh call; see the Repository by exit code table"; exit "$_rc"; }
echo "Repository: $_REPO"
# git-bug first (offline-capable) — provides title, body, and comments
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
        echo "  git-bug: cache miss, pulling from GitHub..." >&2
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
    _GH_JSON=$(gh issue view <N> -R "github.com/$_REPO" --json title,body,labels,assignees,milestone,comments,url 2>/dev/null || echo "")
    if [ -n "$_GH_JSON" ]; then
        [ -z "$ISSUE_TITLE" ] && ISSUE_TITLE=$(echo "$_GH_JSON" | jq -r '.title')
        [ -z "$ISSUE_BODY" ] && ISSUE_BODY=$(echo "$_GH_JSON" | jq -r '.body')
    fi
fi
```

Check for review-issue comments — they contain scope assessment, principle
flags, and ADR notes. Comments are available from `gh` output (`.comments[]`)
or from git-bug JSON (`.comments[1:]` — index 0 is the issue body).

Identify:
- What is being proposed?
- Which repo does this affect? (workspace infra, or a project repo?)
- Is there a linked PR or existing work?

### 2. Load governance context

Read the evaluation criteria:

- `$WS_ROOT/.agent/knowledge/principles_review_guide.md` — principle quick reference,
  ADR applicability, and consequences map

Read the governance docs:

- `docs/principles.md` — workspace principles
- `docs/decisions/*.md` — ADR titles (read full text only for triggered ADRs)

If the issue targets a project repo, also check:
- The project repo's `PRINCIPLES.md` / `docs/principles.md`
- `.agent/project_knowledge/` if available (symlink to manifest repo's `.agents/workspace-context/`)

### 3. Assess scope

- **Well-scoped?** Can this be completed in a single PR? If not, should it
  be broken into sub-issues?
- **Right repo?** Does this change belong in the workspace repo or a project
  repo? Check the "Put each thing at the level it applies to" principle.
- **Serves?** For every issue, in one line: the goal it serves and the
  design section it falls under. For a workspace issue, name the goal by
  its section name under `$WS_ROOT/README.md#workspace-goals` (as the
  Serves lines in `docs/principles.md` do), and cite the design section by
  its anchor, as `docs/design.md#<section>` (the section list is in
  `$WS_ROOT/docs/design.md#the-design`). The README line
  "A safeguard has to earn its cost" has no section name of its own: work
  that serves it writes that phrase, word for word, in its Serves line,
  beside any other goal's section name. For a project issue, use the
  project's own goals and design document, found where
  `project_setting.sh doc <name> goals|design` says it keeps them (never a
  guessed path), or write "none"; a project is not asked to keep either.
  Work inside a part that has its own design (ADR-0022) names the root
  goal it serves and may also name the part's own goal, citing the part's
  design section as `<path>/design.md#<section>`, `<path>` being the
  design file's directory (`tools/repos-manifest/docs/design.md#<section>`).
  Flag an issue that serves no goal, or that
  breaks a stated rule (for a workspace issue, a principle or a row of
  `$WS_ROOT/docs/design.md#rules`; for a project issue, the project's own
  stated rules, if it has any), as a Principle Alignment row with
  Status `Action needed` (step 4): "Only what's needed" for no goal, the
  principle or ADR the rule cites for a broken rule. A project with no
  goals written down is not flagged for that.
- **Design picture?** Does the proposal change how the parts fit, or is it
  not covered by the current design? If so, name the design section it
  touches and bring the question to the user on its own ("Ask about what
  matters, and show how much"). Cite the section as in **Serves?** (for
  work inside a part with its own design, the section may be the part's,
  and the root's design changes only where what crosses the part's
  boundary changes, ADR-0022); for a
  project issue, name the section of the project's own design document,
  or say there is none. Record it as a "Keep one current design" row
  with Status `Action needed` in the Principle Alignment table (step 4),
  so it reaches the posted comment and the `### Actions` list. If the issue already records the
  user's decision and names the design update, record the row as `OK` with
  a pointer and do not re-ask.
- **Dependencies?** Does this depend on other open issues? Will other issues
  need to wait for this one?

### 4. Evaluate principle alignment

For each relevant principle, assess whether the proposed change aligns:

| Principle | Status | Notes |
|---|---|---|
| ... | OK / Watch / Action needed | Specific observation |

**Statuses**:
- **OK** — No concerns
- **Watch** — Worth noting but not blocking
- **Action needed** — Should be addressed before or during implementation

Skip principles that clearly don't apply.

### 5. Check ADR applicability

Using the ADR applicability table from the review guide, identify which ADRs
are triggered by this type of change. For each triggered ADR:

- Does the issue description account for the ADR's requirements?
- If not, note what may be missing.

### 6. Check consequences

Using the consequences map: if this issue changes something in the "If you
change..." column, note the corresponding "Also update..." items. These
should be part of the issue scope or flagged as follow-up work.

### 7. Post findings as a comment

Post the review as a comment on the issue. **Do not modify the issue body.**

```markdown
## Review

### Scope Assessment

**Well-scoped?** Yes/No — [explanation]
**Right repo?** Yes/No — [explanation]
**Serves**: [goal] — `docs/design.md#<section>` (or the project's own; "none")
**Design picture?** No change / Changes [section] — [explanation]
**Dependencies**: [list or "none identified"]

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| ... | ... | ... |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ... | ... | ... |

### Consequences

- [items that should be updated as part of this work]

### Recommendations

- [specific suggestions, if any]

---
**Authored-By**: `$AGENT_NAME`
**Model**: `$AGENT_MODEL`
```

Use `--body-file` for the comment (not `--body`). The repository is asked
for again (a new shell); when step 1 gave exit 4 or 5, skip this step:
nothing is posted.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
_REPO=$("$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>") || { _rc=$?; echo "issue_repo.sh exit $_rc: this block makes no gh call; see the Repository by exit code table"; exit "$_rc"; }
echo "Repository: $_REPO"
BODY_FILE=$(mktemp /tmp/gh_body.XXXXXX.md)
cat << 'COMMENT_EOF' > "$BODY_FILE"
[review content]
COMMENT_EOF
gh issue comment <N> -R "github.com/$_REPO" --body-file "$BODY_FILE"
rm "$BODY_FILE"
```

### 8. Persist the review to progress.md

The posted comment **is** the entry (ADR-0013 `## Issue Review`; the same
shape `review-plan`'s step 6 gives `## Plan Review`). Append it through
the shared persistence call with `--soft`, so a review run by hand outside
the issue's worktree still succeeds and just prints the notice.

The block asks `issue_repo.sh` again first: the entry is written only for
this checkout's issue (exit 0, or 4 and 5 for a bare number), and on any
other exit the block writes nothing.

When step 7 posted nothing (exit 4 or 5 in step 1), there is no comment:
the entry then holds the full review text the comment would have carried,
in the same place, and the line after `**Issue**` says
`No comment was posted: <the reason, from step 1>.` A dispatched phase
that could not get the issue's text writes `**Status**: partial` and the
text it needs instead of the review (step 1).

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/issue_repo.sh" "<ref>" >/dev/null; _rc=$?; case "$_rc" in 0|4|5) ;; *) echo "issue_repo.sh exit $_rc: this block reads and writes no records; see the Repository by exit code table"; exit "$_rc" ;; esac
$WS_ROOT/.agent/scripts/review_progress.sh persist --issue "<N>" \
    --branch "$(git branch --show-current)" --title "<issue title>" \
    --strict --soft <<'ENTRY'
## Issue Review
**Status**: complete
**When**: <YYYY-MM-DD HH:MM ±HH:MM>
**By**: <agent name> (<model>)

**Issue**: #<N>

### Scope Assessment
...the comment body from step 7, verbatim, from "### Scope Assessment"
   through the last "### Recommendations" bullet — WITHOUT the leading
   "## Review" line (a second "## " heading is a second entry to every
   reader) and WITHOUT the signature footer...

### Actions
- [ ] <Notes text of the first Principle Alignment row whose Status is "Action needed">
- [ ] <... one box per Action-needed row, in table order ...>
- [ ] <first Recommendations bullet, verbatim>
- [ ] <... one box per Recommendations bullet, in order ...>
ENTRY
```

Rules for `### Actions` (they are what `run-issue` routes on):

- Exactly these become checkboxes, in this order: every **Principle
  Alignment** row with Status `Action needed` (box text = that row's
  Notes), then every **Recommendations** bullet (box text = the bullet).
  Nothing else — not Watch rows, not ADR notes, not Consequences items.
- If there are no Action-needed rows and no Recommendations, write the
  single checked box `- [x] No actions needed.` so the section stays
  parseable and carries no open box.
- `**Issue**: #<N>` is the entry's correlation key (ADR-0013: issue
  number, no SHA).

Echo the one line the script prints ("Progress persisted ..." or
"Progress persistence failed: <reason> — the report above is unaffected")
after the comment URL. On a failure the comment on GitHub is still the
review; the entry can be appended by hand from the issue's worktree.

## Guidelines

- **Comment, don't edit** — the issue body is the authoritative spec. Review
  findings are advisory input posted as a comment with their own timestamp.
- **Be actionable** — "Watch: might be too large for a single PR" is useful.
  "Looks fine" without specifics is not.
- **Don't block unnecessarily** — most issues are fine. Flag genuine concerns,
  not hypothetical risks.
- **Note gaps, don't fill them** — if the issue is missing detail, note what's
  missing. Don't rewrite the issue.
