---
name: sitrep
description: Situation report from checked facts — where the workspace's acceptance case stands (Direction lines checked this run), the inbox with a proposed sort, work in flight, and deferrals that are due. Reads only; writes one line to a machine-local run record.
session_scope: both
---

# Sit-rep

## Workspace root

This skill can run in a **project** session as well as in the workspace.
In a project session, `.agent/scripts/...` does not resolve: those paths
belong to the workspace, and the cwd is somewhere else.

Every workspace path below is therefore written `$WS_ROOT/.agent/...`.
Resolve `$WS_ROOT` at the head of each command chain, because shell state does
not persist between tool calls:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/<script>" ...
```

`~/.claude/agent-workspace-root` is written by
`.agent/scripts/user_tier_install.sh` and names the main checkout. It is a
plain file, not an environment variable and not `SessionStart` hook output —
hook stdout is context text and never reaches a tool call's shell (ADR-0016).
With no user tier the fallback makes `$WS_ROOT` the cwd, which is right in a
workspace session.

## Usage

```
/sitrep
```

No arguments. This first mode reads the workspace root only.

## What it is

A read-out that answers "what's next" from facts checked this run. The
skill formats; it decides nothing. Every statement in the report comes from
a command run in this invocation: the check runner's rows, the inbox file,
the worktree list, the open pull requests. Memory notes, earlier
conversation and earlier reports are not sources. If something could not
be checked, say so; never fill the gap.

The authored part lives in the `## Direction` section at the top of
`docs/roadmap.md`: lines that must be true for the acceptance case, each
with a check, and deferrals, each with a revisit check. The check runner
reads that section and prints one row per item. The result words are a
trial: `true`, `false`, `partial` (a cell of several checks that disagree),
`unknown` (the check could not run) and `unchecked` (no check).

Machine-local files, both named in `.agent/settings.local` (git-ignored):
`inbox` (one-line thoughts written by `capture.sh`) and `run_record` (one
line per sit-rep run, so the next run can say what moved).

## Steps

### 1. Check the Direction lines

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/sitrep_checks.sh" --root "$WS_ROOT"
echo "---"
"$WS_ROOT/.agent/scripts/sitrep_checks.sh" --root "$WS_ROOT" --summary
```

Rows are `kind`, `item`, `result`, `check`, `date`, TAB-separated. Kinds:
`line`, `deferral`, `format` (a checklist item in the section, which breaks
the section's rules; report it), `section` (no Direction section). The last
line is the summary, `lines <true>/<total> deferrals <true>/<total>`.

### 2. Read the inbox and the last run record

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
source "$WS_ROOT/.agent/scripts/_settings.sh"
inbox="$(settings_path "$WS_ROOT" inbox)" || inbox=""
record="$(settings_path "$WS_ROOT" run_record)" || record=""
last=""
if [ -n "$record" ] && [ -f "$record" ]; then
    last="$(awk -F'\t' '$2 == "workspace"' "$record" | tail -n1)"
fi
echo "record_file=${record:-unset}"
echo "last_record=${last:-none}"
echo "inbox_file=${inbox:-unset}"
if [ -n "$inbox" ] && [ -f "$inbox" ]; then
    echo "inbox_lines=$(grep -c . "$inbox")"
    echo "inbox_oldest=$(head -n1 "$inbox" | cut -f1)"
    if [ -n "$last" ]; then
        echo "inbox_new=$(awk -F'\t' -v d="${last%%$'\t'*}" '$1 > d' "$inbox" | grep -c .)"
    fi
    echo "---"
    head -n 20 "$inbox"
fi
```

Inbox lines are `date`, `project`, `issue`, `text`. The first 20 (oldest)
are shown; say how many more there are.

### 3. Read what is in flight

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
"$WS_ROOT/.agent/scripts/worktree_list.sh" --json
WS_REPO="$(source "$WS_ROOT/.agent/scripts/_issue_helpers.sh" \
    && extract_gh_slug "$(git -C "$WS_ROOT" remote get-url origin 2>/dev/null)")"
echo "---"
gh pr list -R "$WS_REPO" --state open \
    --json number,title,headRefName,isDraft,reviewDecision,updatedAt
```

`-R` names the workspace repository from its own remote, so a project
session does not list the project's pull requests by mistake. For each
worktree, its last commit stands in for a resume note:

```bash
git -C "<worktree path>" log -1 --format='%cr: %s'
```

### 4. Write the run record

Only when `run_record` is set and its directory exists; the repository is
never written to. One line, appended:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
source "$WS_ROOT/.agent/scripts/_settings.sh"
record="$(settings_path "$WS_ROOT" run_record)" \
    && summary="$("$WS_ROOT/.agent/scripts/sitrep_checks.sh" --root "$WS_ROOT" --summary)" \
    && printf '%s\tworkspace\t%s\tinbox %s\n' "$(date '+%Y-%m-%d %H:%M %z')" \
        "$summary" "<inbox line count, or 0>" >> "$record"
```

With `run_record` unset, say so in the report and skip the write.

### 5. Print the report

Four sections, one screen. Plain words, no issue or pull request number
without its title beside it.

```markdown
## Sit-rep, <date>

**Acceptance case**: <t> of <n> lines true. <What moved: compare the
summary with the last run record's, e.g. "lines 3/6 -> 4/6 since
2026-10-10"; "first run" when there is no earlier line.>
Not yet true:
- <line> — <result> (<check>)
Workspace root only; registered project roots are not read in this mode.

**Inbox**: <n> lines, oldest <date>, <k> new since the last run.
Proposed sort, to answer in batches:
- now: <items>
- next: <items>
- someday: <items>
- decided against, revisit when <condition>: <items>
- delete: <items>

**In flight**: <each worktree: branch, last commit age and subject>;
<each open pull request: title, draft or review state>.

**Deferrals due**: <deferrals whose check is true>.
Unchecked (no revisit check): <deferrals whose result is unchecked>.
```

Rules for the report:

- A `false`, `unknown`, `partial` or `unchecked` line goes under "Not yet
  true" with its result word, so a line that could not be checked never
  reads as a line that failed.
- A deferral is due only when its result is `true`. An `unchecked`
  deferral is listed as unchecked, never as due.
- The inbox sort is a proposal. Use only the five bins above; never
  "never" — "decided against" always carries the condition that would
  reopen it. Do not edit the inbox; filing issues or editing the roadmap
  from the answers is a separate step the owner asks for.
- `format` rows are reported as a problem in the Direction section, not as
  lines.
- End with at most one question, the one whose answer changes the most.
