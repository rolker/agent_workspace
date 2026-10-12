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
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
"$WS_ROOT/.agent/scripts/<script>" ...
```

`~/.claude/agent-workspace-root` is written by
`.agent/scripts/user_tier_install.sh` and names the main checkout. It is a
plain file, not an environment variable and not `SessionStart` hook output —
hook stdout is context text and never reaches a tool call's shell (ADR-0016).
With no user tier, or an empty file, the fallback makes `$WS_ROOT` the cwd,
which is right in a workspace session.

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

The checks run once per sit-rep. Their rows are saved to a temporary file,
and both the summary shown here and the one recorded in step 4 are counted
from that file, so the report and the record cannot disagree.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
rows="$(mktemp -t sitrep-rows.XXXXXX)" || rows=""
if [ -n "$rows" ]; then
    "$WS_ROOT/.agent/scripts/sitrep_checks.sh" --root "$WS_ROOT" > "$rows"
    cat "$rows"
    echo "---"
    "$WS_ROOT/.agent/scripts/sitrep_checks.sh" --summary-from "$rows"
    echo "rows_file=$rows"
else
    echo "could not create a temporary file; checks not run"
fi
```

Rows are `kind`, `item`, `result`, `check`, `date`, TAB-separated. Kinds:
`line`, `deferral`, `format` (a checklist item in the section, which breaks
the section's rules; report it), `section` (nothing to check, and why: no
roadmap file, no Direction section, or a section with neither table). After
`---` comes the summary, `lines <true>/<total> deferrals <true>/<total>`,
then `rows_file=`, which step 4 needs.

### 2. Read the inbox and the last run record

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
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
    lines="$(grep -c . "$inbox")"
    echo "inbox_lines=$lines"
    echo "inbox_oldest=$(head -n1 "$inbox" | cut -f1)"
    if [ -n "$last" ]; then
        seen="$(printf '%s\n' "$last" | cut -f4)"
        seen="${seen#inbox }"
        if [[ "$seen" =~ ^[0-9]+$ ]] && [ "$lines" -ge "$seen" ]; then
            echo "inbox_new=$((lines - seen))"
        else
            echo "inbox_new=unknown"
        fi
    fi
    echo "---"
    head -n 20 "$inbox"
fi
```

Inbox lines are `date`, `project`, `issue`, `text`. The first 20 (oldest)
are shown; say how many more there are. `inbox_new` is the line count now
minus the count the last run recorded: new lines are appended at the end,
so they are the last `inbox_new` lines. It is `unknown` when the inbox has
fewer lines than then (lines were removed, so a count cannot say which are
new) or the last record has no count.

### 3. Read what is in flight

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
"$WS_ROOT/.agent/scripts/worktree_list.sh" --json
WS_REPO="$(source "$WS_ROOT/.agent/scripts/_issue_helpers.sh" \
    && extract_gh_slug "$(git -C "$WS_ROOT" remote get-url origin 2>/dev/null)")"
echo "---"
if [ -n "$WS_REPO" ]; then
    gh pr list -R "$WS_REPO" --state open \
        --json number,title,headRefName,isDraft,reviewDecision,updatedAt
else
    echo "pull requests: not checked (no GitHub remote for $WS_ROOT)"
fi
```

`-R` names the workspace repository from its own remote, so a project
session does not list the project's pull requests by mistake. With no
GitHub remote the pull requests are reported as not checked. For each
worktree, its last commit stands in for a resume note:

```bash
git -C "<worktree path>" log -1 --format='%cr: %s'
```

### 4. Write the run record

Only when `run_record` is set and its directory exists; the repository is
never written to. One line, appended, with the summary counted from the rows
step 1 saved (the checks are not run again) and the inbox line count, which
the next run's `inbox_new` is measured from. Put step 1's `rows_file` value
in place of the placeholder. The rows file is removed either way.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
source "$WS_ROOT/.agent/scripts/_settings.sh"
rows="<rows_file printed in step 1>"
record="$(settings_path "$WS_ROOT" run_record)" || record=""
inbox="$(settings_path "$WS_ROOT" inbox)" || inbox=""
n=0
if [ -n "$inbox" ] && [ -f "$inbox" ]; then n="$(grep -c . "$inbox")"; fi
if [ -z "$record" ]; then
    echo "run record: not written (run_record not set)"
elif [ ! -d "$(dirname "$record")" ]; then
    echo "run record: not written (directory missing: $(dirname "$record"))"
elif summary="$("$WS_ROOT/.agent/scripts/sitrep_checks.sh" --summary-from "$rows")"; then
    printf '%s\tworkspace\t%s\tinbox %s\n' "$(date '+%Y-%m-%d %H:%M %z')" \
        "$summary" "$n" >> "$record" && echo "run record: written to $record"
else
    echo "run record: not written (rows file unreadable: $rows)"
fi
rm -f -- "$rows"
```

When the record is not written, say so in the report, with the reason
printed.

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

**Inbox**: <n> lines, oldest <date>, <k> new since the last run (or
"new since the last run: unknown", with the reason).
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
