---
name: sitrep
description: "Use when asked 'what's next?', 'what should I work on?' or 'where are we?'. Situation report from checked facts — where the workspace's acceptance case stands (Direction lines checked this run), the inbox with a proposed sort, work in flight and deferrals that are due — ending with one suggested next step and the fact it rests on. Reads only; writes one line to a machine-local run record."
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

A read-out that answers "what's next?" from facts checked this run. It
replaces the old what-next skill, which ranked roadmap rows; this one
answers from checked facts instead. The skill formats and proposes; it
decides nothing. The inbox sort and the closing "Suggested next" line are
proposals for the owner to accept or change. Every statement in the report
comes from a command run in this invocation: the check runner's rows, the inbox file,
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
from that file, so the report and the record cannot disagree. A run that
fails or is interrupted keeps no rows file and prints no `rows_file=`, so
nothing from it can be recorded. Neither does a run that could not read
the roadmap (not found, or not readable): its rows are shown, but there is
no count to record, since no Direction line was looked at. If this block
itself is interrupted (INT or TERM), it stops the check runner and removes
the rows file before it exits.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
rows="$(mktemp -t sitrep-rows.XXXXXX)" || rows=""
pid=""
stop() { [ -z "$pid" ] || kill -TERM "$pid" 2>/dev/null; [ -z "$rows" ] || rm -f -- "$rows"; trap - INT TERM; exit "$1"; }
trap 'stop 130' INT
trap 'stop 143' TERM
if [ -z "$rows" ]; then
    echo "could not create a temporary file; checks not run"
else
    "$WS_ROOT/.agent/scripts/sitrep_checks.sh" --root "$WS_ROOT" > "$rows" &
    pid=$!
    rc=0; wait "$pid" || rc=$?
    pid=""
    if [ "$rc" -eq 0 ]; then
        cat "$rows"
        echo "---"
        if "$WS_ROOT/.agent/scripts/sitrep_checks.sh" --summary-from "$rows"; then
            echo "rows_file=$rows"
        else
            rm -f -- "$rows"
            echo "checks: no summary (reason above); nothing will be recorded"
        fi
    else
        rm -f -- "$rows"
        echo "checks failed or were interrupted (exit $rc); no rows, nothing will be recorded"
    fi
fi
trap - INT TERM
```

Rows are `kind`, `item`, `result`, `check`, `date`, TAB-separated. Kinds:
`line`, `deferral`, `format` (a checklist item in the section, which breaks
the section's rules; report it), `section` (nothing to check, and why: no
roadmap file, a roadmap that could not be read, no Direction section, or a
section with neither table). After `---` comes the summary, `lines
<true>/<total> deferrals <true>/<total>`, then `rows_file=`, which step 4
needs. When the block prints `checks failed` or `no summary` instead,
report that the Direction lines were not checked this run, with the reason
printed, and that the run record was not written, and skip step 4.

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
    # Blank lines (a hand edit) are skipped everywhere: count, oldest, list.
    lines="$(awk '!/^[[:space:]]*$/ { n++ } END { print n + 0 }' "$inbox")"
    echo "inbox_lines=$lines"
    echo "inbox_oldest=$(awk '!/^[[:space:]]*$/ { print; exit }' "$inbox" | cut -f1)"
    if [ -n "$last" ]; then
        seen="$(printf '%s\n' "$last" | cut -f4)"
        seen="${seen#inbox }"
        if [[ "$seen" =~ ^[0-9]+$ ]]; then
            SEEN="$seen" SEEN_LINE="$(printf '%s\n' "$last" | cut -f5-)" awk '
                /^[[:space:]]*$/ { next }
                { i++ }
                $0 == ENVIRON["SEEN_LINE"] { c++; at = i; if (i == ENVIRON["SEEN"] + 0) exact = i }
                END {
                    if (ENVIRON["SEEN"] + 0 == 0) print "inbox_new=" (i + 0)
                    else if (exact) print "inbox_new=" (i - exact)
                    else if (c == 1) print "inbox_new=" (i - at)
                    else if (c == 0) print "inbox_new=unknown (the line the last run saw last is gone)"
                    else print "inbox_new=unknown (the line the last run saw last appears more than once)"
                }' "$inbox"
        else
            echo "inbox_new=unknown (the last record has no inbox count)"
        fi
    fi
    echo "---"
    awk '!/^[[:space:]]*$/' "$inbox" | head -n 20
fi
```

Inbox lines are `date`, `project`, `issue`, `text`. The first 20 (oldest)
are shown; say how many more there are. New lines are appended at the end,
so the new ones are those after the last line the previous run saw, which
its record keeps (step 4). `inbox_new` counts the lines after that line,
found at the position recorded or, when lines above it were removed, as
the one line equal to it. It is `unknown`, with the reason, when that line
is gone or appears more than once, or the last record has no count.

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
GitHub remote the pull requests are reported as not checked. The list
always includes the main checkout (`type: "main"`); it is not work in
flight and is left out of the report. For each other worktree, its last
commit stands in for a resume note:

```bash
git -C "<worktree path>" log -1 --format='%cr: %s'
```

The report gives one line per branch. The pull requests listed are the
workspace's, so only a workspace worktree (`type: "workspace"`) is matched
to one: when its `branch` equals the pull request's `headRefName`, they
are the same work and share that line. A project worktree
(`type: "project"`) gets its own line, named with its project (`repo`),
and no pull request: project branches use the same `feature/issue-<N>`
names with their own numbers, so a name match would join unrelated work.
Branches with a ready pull request (open and not a draft; every one needs
the owner's merge) come first; then the rest (a draft pull request, or a
worktree with no pull request). `reviewDecision` does not change the
order; it is printed as the review state when set, and nothing is printed
for it when it is empty. Within each group, branches with a worktree come
first, in the worktree list's order, then branches with only a pull
request, in the order `gh pr list` printed them.

### 4. Write the run record

Only when step 1 printed `rows_file=`, `run_record` is set and its
directory exists; the repository is never written to. One line, appended,
with the summary counted from the rows step 1 saved (the checks are not run
again), the inbox line count step 2 printed (not counted again, so a
thought captured since is reported as new next time), and the last inbox
line step 2 counted, which the next run's `inbox_new` is measured from.
Put step 1's `rows_file` value and step 2's `inbox_lines` value (`0` when
step 2 printed none) in place of the placeholders. The rows file is removed
either way.

The record line is `<when>`, `workspace`, `<summary>`, `inbox <n>`, then
that inbox line's own four fields, TAB-separated.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
rows="<rows_file printed in step 1>"
n="<inbox_lines printed in step 2>"
source "$WS_ROOT/.agent/scripts/_settings.sh"
record="$(settings_path "$WS_ROOT" run_record)" || record=""
inbox="$(settings_path "$WS_ROOT" inbox)" || inbox=""
if [ -z "$record" ]; then
    echo "run record: not written (run_record not set)"
elif [ ! -d "$(dirname "$record")" ]; then
    echo "run record: not written (directory missing: $(dirname "$record"))"
elif ! [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "run record: not written (inbox count is not a number: $n)"
elif summary="$("$WS_ROOT/.agent/scripts/sitrep_checks.sh" --summary-from "$rows")"; then
    # The n-th non-blank inbox line: the last one step 2 counted.
    seen_line=""
    if [ "$n" -gt 0 ] && [ -n "$inbox" ] && [ -f "$inbox" ]; then
        seen_line="$(N="$n" awk '!/^[[:space:]]*$/ && ++i == ENVIRON["N"] + 0 { print; exit }' "$inbox")"
    fi
    # A record whose last line has no newline (a hand edit) gets one
    # first, so the new line is not glued to it.
    if { [ ! -s "$record" ] || [ -z "$(tail -c1 "$record")" ] || printf '\n' >> "$record"; } \
        && printf '%s\tworkspace\t%s\tinbox %s\t%s\n' "$(date '+%Y-%m-%d %H:%M %z')" \
            "$summary" "$n" "$seen_line" >> "$record"; then
        echo "run record: written to $record"
    else
        echo "run record: not written (could not append to $record)"
    fi
else
    echo "run record: not written (no usable rows file: ${rows:-none})"
fi
[ -z "$rows" ] || rm -f -- "$rows"
```

When the record is not written, say so in the report, with the reason
printed.

### 5. Print the report

Four sections and a closing "Suggested next" line, one screen. Plain
words, no issue or pull request number without its title beside it.

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

**In flight**: one line per branch, in the order step 3 gives:
- <branch> (for a project worktree, <project>/<branch>): <pull request
  title, and "draft" or its review state if set, when it has one>; <last
  commit age and subject, when it has a worktree>.

**Deferrals due**: <deferrals whose check is true>.
Unchecked (no revisit check): <deferrals whose result is unchecked>.

**Suggested next**: <one item> — <the fact it rests on>.
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
- "Suggested next" names one item, taken from the first of these sources
  that has one, in this order: a due deferral; a `false` Direction line;
  work in flight (a branch line from "In flight"); the proposed inbox
  "now" bin. It names the fact it rests on (the deferral and its check,
  the line and its check, the branch or pull request title, the inbox
  line). When it comes from the inbox "now" bin, it says "this rests on
  the proposed inbox sort", since that bin is this run's proposal, not a
  checked fact. When no source has an item, it reads "Suggested next:
  nothing from this run's facts."
  - The main checkout is not work in flight: the worktree list always
    includes it (`type: "main"`), so it is never a candidate. The
    worktree this session runs in counts like any other.
  - When a source has several items, take the first as listed in the
    report. For work in flight that is a branch with a ready pull
    request, if there is one (step 3's order).
  - From the Direction section only a due deferral and a `false` line are
    sources. A `format` problem and an `unknown`, `partial` or `unchecked`
    line are deliberately not: they say a check could not decide, not
    that work is due. The closing question may ask about them.
- After "Suggested next", end with at most one question, the one whose
  answer changes the most. The suggestion proposes an action; the question
  asks the owner to decide something.
