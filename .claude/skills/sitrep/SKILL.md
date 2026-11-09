---
name: sitrep
description: "Use when asked 'what's next?', 'what should I work on?' or 'where are we?'. Situation report for the session's own root (the workspace, or the project the session was started in) from checked facts, easy to take in: what the acceptance case is for, the next step towards it (the first Direction line not yet true, checked this run, and the work in flight for it), where work in flight stands, and problems to know about (an audit or research due, documentation that may have fallen behind, judged by dates and commits since, and deferrals that are due), then the counts and the inbox; each piece of work in flight is marked with the path it serves, and the closing question asks which path to focus on. Reads only, except one line to a machine-local run record; in a workspace session it may start a due read-only check in the background and says so."
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

`$WS_ROOT` is where the scripts are, not what the report is about. The
report is about the session's own root, `$ROOT`: the workspace in a
workspace session, the registered project root in a project session.
`$WS_ROOT/.agent/scripts/sitrep_root.sh` decides it, once per block, and
prints it with the facts the steps below need (`root=`, `type=`,
`record_name=`, `roadmap=`, `own_repo=`, `default_branch=`, `pr_source=`
and which Problems checks the root's files allow; the script's header
has the rules). When it decides no root (the directory is outside every
root, or the project registry cannot be parsed) it prints nothing, gives
the reason, and exits non-zero; there is then no sit-rep, and the report
says so, with that reason, rather than fall back to the workspace.

## Usage

```
/sitrep          # the report
/sitrep inbox    # the report, with a proposed sort of the inbox
```

The sit-rep covers the session's own root only: a sit-rep in a project
is just for that project, and one in the workspace is just for the
workspace (owner, 2026-11-09). A view that combines the workspace and
every project is not part of it.

## What it is

A read-out that answers "what's next?" from facts checked this run, in
the order the owner needs them: what to work on next towards the goals,
where the work in flight stands, and problems he should know about. It
replaces the old what-next skill, which ranked roadmap rows; this one
answers from checked facts instead. The skill formats and proposes; it
decides nothing. The "Next:" line (Suggested next) and the inbox sort are
proposals for the owner to accept or change. The one thing it starts on
its own is a read-only check that is due (step 7), and the report says
so. Every statement in the report comes from a command run in this
invocation: the check runner's rows, the roadmap's acceptance-case
paragraph, the inbox file, the worktree list, the open pull requests,
the issue timelines, and the files and history of the root's local
default branch. The
words those facts are put in come from fixed tables (step 3's states,
step 8's results); the one free rewording is Suggested next, which
restates the next line, printed as written just above it, as an action.
Memory notes, earlier conversation and earlier reports are not sources. If something could not be checked, say so; never fill
the gap.

The authored part lives in the `## Direction` section of the root's
roadmap (`docs/roadmap.md`, else `ROADMAP.md`): lines that must be true
for the acceptance case, each
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
the rows file before it exits. The block first prints the root's facts
(`sitrep_root.sh`), then `---`; when no root is decided (outside every
root, or a registry that cannot be parsed) it prints "no sit-rep" and
stops, and so does the sit-rep.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
if ! r="$("$WS_ROOT/.agent/scripts/sitrep_root.sh")"; then
    echo "no sit-rep: no root could be decided for this directory (reason above)"
    exit 1
fi
printf '%s\n---\n' "$r"
ROOT="$(sed -n 's/^root=//p' <<< "$r")"
roadmap="$(sed -n 's/^roadmap=//p' <<< "$r")"
ra=(); [ -z "$roadmap" ] || ra=(--roadmap "$roadmap")
rows="$(mktemp -t sitrep-rows.XXXXXX)" || rows=""
pid=""
stop() { [ -z "$pid" ] || kill -TERM "$pid" 2>/dev/null; [ -z "$rows" ] || rm -f -- "$rows"; trap - INT TERM; exit "$1"; }
trap 'stop 130' INT
trap 'stop 143' TERM
if [ -z "$rows" ]; then
    echo "could not create a temporary file; checks not run"
else
    "$WS_ROOT/.agent/scripts/sitrep_checks.sh" --root "$ROOT" "${ra[@]}" > "$rows" &
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

In a project session, a `section` row (no roadmap, or a roadmap with no
Direction section) is reported as "no Direction section in this project;
onboarding (`onboard-project`) offers one", and nothing is invented in
its place: no next step, no Paths, no acceptance case.

### 2. Read the inbox and the last run record

The last run record is the last line for this root: its second column is
the root's `record_name` (`workspace`, or the project's registered name).
In a project session the inbox lines captured in that project (their
`project` field is its registered name, as `capture.sh` writes it) are
listed first, then the other lines after a `--- other lines` marker,
each group oldest first, in the one listing pass; a workspace session
lists them in file order.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
r="$("$WS_ROOT/.agent/scripts/sitrep_root.sh")" || { echo "no sit-rep: no root could be decided for this directory (reason above)"; exit 1; }
name="$(sed -n 's/^record_name=//p' <<< "$r")"
mine=""; [ "$(sed -n 's/^type=//p' <<< "$r")" != project ] || mine="$(sed -n 's/^project=//p' <<< "$r")"
source "$WS_ROOT/.agent/scripts/_settings.sh"
inbox="$(settings_path "$WS_ROOT" inbox)" || inbox=""
record="$(settings_path "$WS_ROOT" run_record)" || record=""
last=""
if [ -n "$record" ] && [ -f "$record" ]; then
    last="$(N="$name" awk -F'\t' '$2 == ENVIRON["N"]' "$record" | tail -n1)"
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
    # The first 20 inbox lines in listing order; the marker is not one of
    # them, and is printed only when an other line follows it.
    M="$mine" awk -F'\t' '
        !/^[[:space:]]*$/ { if (ENVIRON["M"] == "" || $2 == ENVIRON["M"]) mine[++m] = $0; else rest[++n] = $0 }
        END { k = 0
              for (i = 1; i <= m && k < 20; i++) { print mine[i]; k++ }
              if (n && k < 20) print "--- other lines"
              for (i = 1; i <= n && k < 20; i++) { print rest[i]; k++ } }' "$inbox"
fi
```

Inbox lines are `date`, `project`, `issue`, `text`. The first 20 (oldest)
are shown, in listing order (the `--- other lines` marker is not counted
among them); say how many more there are. New lines are appended at the end,
so the new ones are those after the last line the previous run saw, which
its record keeps (step 4). `inbox_new` counts the lines after that line,
found at the position recorded or, when lines above it were removed, as
the one line equal to it. It is `unknown`, with the reason, when that line
is gone or appears more than once, or the last record has no count. In a
project session the listing puts this project's lines first, so a new
line is told by its place in the file, not in the listing.

### 3. Read what is in flight

The worktrees are this root's (`sitrep_root.sh --worktrees`): its own,
plus those its own Direction lines name (an `adapter --project <name>`
check names that project's worktrees, a `gh-issue <owner/repo>#N` check
the worktree of that issue). Project worktrees no Direction line of this
root names are not listed, in a workspace session either. Each entry
carries `own`: `yes` for a checkout of the root's own repository, whose
issues are this root's. It also carries the GitHub repository its issue
belongs to (`repository`, with the checkouts of it, and why there is none),
the branch its pull request would have (`pr_branch`), and, with step 1's
rows, whether a Direction line names it (`named`); the helper's header
has the rules, and a check is read as the check runner reads it. The rows of step 1 tell the named ones apart, so
put step 1's `rows_file` value in place of the placeholder (leave it as
it is when step 1 printed none: then only the root's own worktrees are
listed, and the report says the work its Direction lines name could not
be listed).

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
r="$("$WS_ROOT/.agent/scripts/sitrep_root.sh")" || { echo "no sit-rep: no root could be decided for this directory (reason above)"; exit 1; }
src="$(sed -n 's/^pr_source=//p' <<< "$r")"
"$WS_ROOT/.agent/scripts/sitrep_root.sh" --worktrees --rows "<rows_file printed in step 1>" \
    || echo "worktrees: could not be listed (reason above)"
echo "---"
if [ -n "$src" ] && [ "$src" != none ]; then
    gh pr list -R "$src" --state open \
        --json number,title,headRefName,isCrossRepository,isDraft,reviewDecision,updatedAt,closingIssuesReferences
else
    echo "pull requests: no pull-request source for this root"
fi
```

`-R` names the session root's own repository (`pr_source`), so the pull
requests listed are this root's. A root that is not a git repository of
its own, or whose `origin` is not on GitHub, has no pull-request source:
the report says "pull requests: no pull-request source for this root",
never a guess. When the worktrees could not be listed, the report says
so under Problems; it never reads that as "nothing in flight". In a
workspace session the list includes the main checkout (`type: "main"`);
it is not work in flight and is left out of the report. For each other worktree with an
issue, where the work stands is the issue's title and the latest entry on
its timeline (`progress.md`, read by `progress_read.py`), and which path
it serves (the root's roadmap's Paths paragraphs, under `## Direction`).
Put step 1's `rows_file` value in place of the placeholder (leave it as
it is when step 1 printed none):

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
source "$WS_ROOT/.agent/scripts/_issue_helpers.sh"
r="$("$WS_ROOT/.agent/scripts/sitrep_root.sh")" || { echo "no sit-rep: no root could be decided for this directory (reason above)"; exit 1; }
stype="$(sed -n 's/^type=//p' <<< "$r")"
roadmap="$(sed -n 's/^roadmap=//p' <<< "$r")"
rows="<rows_file printed in step 1>"
# With no **Path <n>** paragraph in the root's Direction section (the
# last block of this step prints paths=none), no path word is printed.
haspaths=no
if [ -n "$roadmap" ] && awk '/^## Direction/ { d = 1; next } d && /^## / { exit }
        d && /^\*\*Path [0-9]+/ { f = 1; exit } END { exit !f }' "$roadmap" 2>/dev/null; then
    haspaths=yes
fi
wl="$("$WS_ROOT/.agent/scripts/sitrep_root.sh" --worktrees --rows "$rows")" \
    || { echo "worktrees: could not be listed (reason above); work in flight not known this run"; exit 1; }
jq -c '.worktrees[]? | select(.type != "main" and .issue)' <<< "$wl" |
while IFS= read -r w; do
    # Each field by its name, never by position: a worktree with no branch
    # (detached) or no repo keeps its other fields where they belong. A
    # list field comes back one item per line.
    field() { jq -r --arg k "$1" '.[$k] // "" | if type == "array" then join("\n") else tostring end' <<< "$w"; }
    type="$(field type)"; repo="$(field repo)"; branch="$(field branch)"
    issue="$(field issue)"; path="$(field path)"
    # The issue lives in the repository the worktree belongs to, which
    # sitrep_root.sh names ("repository", with "repository_dirs", the
    # checkouts of it, and "repository_why" when there is none). The
    # title cache and the timeline come from that repository's checkouts
    # only: work plans are written at the issue's checkout, and another
    # repository can have its own issue <N>. "named" is "yes" when one of
    # the root's own Direction lines names this work (Path 1), and is
    # absent when step 1 saved no rows.
    slug="$(field repository)"; dirs="$(field repository_dirs)"; why="$(field repository_why)"
    named="$(field named)"
    cache="$(head -n1 <<< "$dirs")"; latest="no progress record yet"
    [ -n "$slug" ] || [ ! -f "$path/.worktree-repos" ] || latest="unknown (no repository to read it from)"
    title="unknown ($why)"
    if [ -n "$slug" ]; then
        # gh first: the git-bug cache can hold a title the issue no longer has.
        title="$(gh issue view "$issue" -R "$slug" --json title --jq .title 2>/dev/null)" || title=""
        if [ -z "$title" ]; then
            # The cache only: issue_lookup pulls from GitHub on a miss, a write.
            ISSUE_TITLE=""
            [ -z "$cache" ] || _issue_lookup_gitbug "$cache" "https://github.com/$slug/issues/$issue" >/dev/null 2>&1
            title="${ISSUE_TITLE:+$ISSUE_TITLE (offline: git-bug cache)}"
            title="${title:-unknown (lookup failed)}"
        fi
    fi
    f=""
    while IFS= read -r d; do
        [ -n "$d" ] && [ -f "$d/.agent/work-plans/issue-$issue/progress.md" ] && { f="$d/.agent/work-plans/issue-$issue/progress.md"; break; }
    done <<< "$dirs"
    if [ -n "$f" ]; then
        latest="$(python3 "$WS_ROOT/.agent/scripts/progress_read.py" "$f" 2>/dev/null | python3 -c '
import json, sys
# The latest timeline entry, in state words (the table below the block),
# looked up by its base type, so "External Review (round 2)" is an
# External Review. The words for a review come from its open boxes.
DONE = {"Issue Review": "issue reviewed, not yet planned",
        "Plan Authored": "plan written, not yet reviewed",
        "Plan Review": "plan reviewed, not yet implemented",
        "Implementation": "implemented",
        "Merge (report-only)": "merged although the merge check found problems",
        "Merge (unreviewed)": "merged without review"}
REVIEWED = {"Local Review": "code reviewed", "Local Review (Pre-Push)": "code reviewed",
            "Integrated Review": "reviews triaged", "External Review": "reviews triaged"}
STEP = {"Issue Review": "issue review", "Plan Authored": "plan writing",
        "Plan Review": "plan review", "Implementation": "implementation",
        "Local Review": "code review", "Local Review (Pre-Push)": "code review",
        "Integrated Review": "review triage", "External Review": "review triage"}
CHECKPOINT = {("plan", "proceed"): "plan approved, implementing",
              ("plan", "approve"): "plan approved, implementing",
              ("plan", "revise"): "plan being revised",
              ("issue-actions", "proceed"): "issue review accepted, planning",
              ("issue-actions", "revise"): "issue being revised",
              ("phase-failed", "retry"): "a step failed; retrying it",
              ("phase-failed", "takeover"): "a step failed; the session is doing it by hand",
              ("merge-refused", "retriage"): "merge refused; reviews being triaged again"}
BY_DECISION = {"address": "review findings being addressed",
               "publish": "approved to publish", "merge": "approved to merge",
               "stop": "stopped at a checkpoint",
               "restart": "goal restated by the owner; issue review starts again"}
def words(e):
    t, st = e.get("base_type") or e.get("type") or "", e.get("status") or ""
    f = e.get("fields") or {}
    if t == "Checkpoint":
        after, dec = (f.get("After") or "").strip(), (f.get("Decision") or "").strip()
        return CHECKPOINT.get((after, dec)) or BY_DECISION.get(dec) \
            or "checkpoint after %s: %s" % (after or "?", dec or "?")
    if t in STEP and st and st != "complete":
        return "%s %s" % (STEP[t], st)
    if t in REVIEWED:
        # review-code leaves "- [ ] No issues found. LGTM." open on an approval.
        k = sum(1 for x in e.get("findings") or [] if not x.get("checked")
                and not (x.get("text") or "").startswith("No issues found"))
        return "%s, %s" % (REVIEWED[t], "nothing open" if k == 0
                           else "1 finding to address" if k == 1 else "%d findings to address" % k)
    return DONE.get(t) or "latest timeline entry: %s %s" % (t, st or "(no status)")
try:
    e = json.load(sys.stdin).get("entries", [])
    print(words(e[-1]) if e else "no progress record yet")
except ValueError:
    print("progress record unreadable")')"
    fi
    # Path 2 is any other work whose newest complete Issue Review has a
    # Serves line naming a goal (every Issue Review writes one, naming the
    # README goals it serves). A project worktree's Serves line names the
    # project's own goals (review-issue), not the workspace README's that
    # Path 2 is defined by, so it is never Path 2, and in a project
    # session nothing is. Only the newest complete Issue Review counts,
    # so a later "none" outranks an older goal, and a partial or failed one
    # (which may have stopped before its Serves line) changes nothing;
    # "none" means no path. With no complete Issue Review, or one with no
    # Serves line, nothing was said either way: the path is unknown, never
    # "no path". Fenced lines are not headings or fields.
    serves="unreviewed"
    [ -z "$f" ] || serves="$(awk 'function done_ir() { if (ir && tolower(st) ~ /^complete[[:space:]]*$/) { s = cs; seen = 1 }; ir = 0 }
        /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
        fence { next }
        /^## / { done_ir(); ir = ($0 ~ /^## Issue Review([[:space:]]|$)/); cs = ""; st = ""; sub_ = 0; next }
        /^### / { sub_ = 1 }
        ir && !sub_ && /^\*\*Status\*\*:/ { sub(/^\*\*Status\*\*:[[:space:]]*/, ""); st = $0 }
        ir && /^\*\*Serves\*\*:/ { sub(/^\*\*Serves\*\*:[[:space:]]*/, ""); cs = $0 }
        END { done_ir()
              if (!seen) print "unreviewed"
              else if (s !~ /[^[:space:]]/) print "unstated"
              else if (tolower(s) ~ /^["\047`*_]*none([^[:alnum:]_]|$)/) print "none"
              else print "goal" }' "$f")"
    if [ "$haspaths" != yes ]; then wpath=""
    elif [ -z "$named" ]; then wpath="path unknown (steps not checked)"
    elif [ "$named" = yes ]; then wpath="Path 1"
    elif [ "$serves" = goal ] && { [ "$type" = project ] || [ "$stype" = project ]; }; then wpath="no path (serves a project goal)"
    elif [ "$serves" = goal ]; then wpath="Path 2"
    elif [ "$serves" = none ]; then wpath="no path"
    elif [ "$serves" = unstated ]; then wpath="path unknown (its issue review has no Serves line)"
    else wpath="path unknown (no complete issue review)"; fi
    printf '%s\t%s\t%s\tissue %s\t%s\t%s\t%s\n' "$type" "${repo:-workspace}" "${branch:-(no branch)}" "$issue" "$title" "$latest" "$wpath"
done
```

Rows are `type`, `repo`, `branch`, `issue <N>`, title, state, path,
TAB-separated; a worktree with no branch (a detached HEAD, e.g. mid-rebase)
reads `(no branch)`. The path is empty when the root's Direction section
has no Paths paragraph (the last block of this step prints `paths=none`):
no path word is printed then. Otherwise it is `Path 1` (`named` is
`yes`: a Direction line names the issue, in its own cells, or a check
names the project the worktree belongs to; a bare `(#N)` or `gh-issue N` names an issue of the
root's own repository, so it matches only a worktree whose `own` is
`yes`, and another repository's worktree is named only by its
`<owner/repo>#N` or `adapter --project` check), else `Path 2` (the newest complete Issue Review on its
timeline has a `**Serves**:` line naming a goal), else `no path` when
that Serves line is `none` (the review template's word for no goal),
which is itself worth seeing: work that serves neither. Only the newest
complete Issue Review's Serves line counts, so a re-review that found the
issue serves nothing outranks an older one that named a goal, and a
partial or failed Issue Review leaves the older one's Serves in place.
`no path` is said only on that evidence. With no complete Issue Review
(no timeline yet, or only partial or failed ones) the path is
"path unknown (no complete issue review)", and with a complete one that
has no Serves line it is "path unknown (its issue review has no Serves
line)". It is `path unknown (steps not checked)` when step 1 printed no
rows. A project worktree is never `Path 2`, and in a project session
nothing is: review-issue writes a project issue's Serves line from the
project's own goals, and Path 2 is work that serves a goal in the
workspace README. With such a goal it reads "no path (serves a project
goal)", which says what it serves and that no Direction line names it.

The state is the latest timeline entry in words, so the report needs no
entry names. The entry is looked up by its base type
(`progress_read.py`'s `base_type`), so an older heading with a suffix,
such as `External Review (round 2)`, reads as its type. A review entry's
state counts its open boxes (`- [ ]` under its `###` sections), so it
never says findings are being addressed when none are open. The
placeholder `- [ ] No issues found. LGTM.`, which `review-code` leaves
unchecked on an approval, is not a finding and is not counted:

| Latest entry | State |
|---|---|
| Issue Review | issue reviewed, not yet planned |
| Plan Authored | plan written, not yet reviewed |
| Plan Review | plan reviewed, not yet implemented |
| Checkpoint after plan, proceed (or approve) | plan approved, implementing |
| Checkpoint after plan, revise | plan being revised |
| Checkpoint after issue-actions, proceed / revise | issue review accepted, planning / issue being revised |
| Checkpoint after phase-failed, retry / takeover | a step failed; retrying it / a step failed; the session is doing it by hand |
| Checkpoint after merge-refused, retriage | merge refused; reviews being triaged again |
| Checkpoint, any other step: address / publish / merge / stop | review findings being addressed / approved to publish / approved to merge / stopped at a checkpoint |
| Checkpoint, any step: restart (the owner restated the goal, `/orchestrator` recipe (a)) | goal restated by the owner; issue review starts again |
| Implementation | implemented (for one of the root's own worktrees with no pull request, when the root has a pull-request source, the report adds "no pull request yet") |
| Local Review, Local Review (Pre-Push), with <k> open boxes | code reviewed, <k> findings to address (1: "1 finding to address") |
| Local Review, Local Review (Pre-Push), no open box | code reviewed, nothing open |
| Integrated Review (or the older External Review), with <k> open boxes | reviews triaged, <k> findings to address |
| Integrated Review (or the older External Review), no open box | reviews triaged, nothing open |
| Merge (report-only): the merge check found problems and the merge went ahead | merged although the merge check found problems |
| Merge (unreviewed) | merged without review |

A status other than `complete` reads as the step and its status instead,
e.g. "implementation partial", "code review failed". Anything else is
printed as "latest timeline entry: <type> <status>", or "checkpoint after
<step>: <decision>", so a new entry type shows up rather than being
guessed at. No `progress.md`, or one with no entries, reads "no
progress record yet". A worktree with no issue (a skill worktree) gets
no row; its line names the branch only. A package worktree's `branch` is
its checkouts' branches, comma-separated, as the worktree list gives it.
Its title and state come from the issue's repository only (its
`repository`), the one its header names, or with a bare `issue=<N>` the
one every listed checkout shares; a checkout of another repository is never read, since that
repository can have an issue with the same number. When no single
repository can be told, the title is "unknown (its checkouts are not
all in one GitHub repository)" and the state "unknown (no repository to
read it from)".
Reading across roots is allowed (`session_root.sh`); nothing here
writes.

The report gives one line per branch. The pull requests listed are the
session root's, so only one of the root's own worktrees (`own` is `yes`)
is matched to one: when its `pr_branch` equals the pull request's
`headRefName` and the pull request's `isCrossRepository` is false, they
are the same work and share that line. `pr_branch` is the worktree's
branch, except for a package worktree, whose `branch` is every
checkout's branch joined by commas and so never a `headRefName`: its
`pr_branch` is the branch of its checkouts of the root's repository. A pull request from a fork
(`isCrossRepository` true) can reuse a local branch name, so it is never
joined: it gets its own line, with "from a fork" after its title and no
worktree part. A worktree that is not the root's own (`own` is `no`: a
worktree a Direction line names, of another repository) gets its own
line, named with its `repo` (`workspace` for a workspace worktree), and
no pull request: other repositories use the same `feature/issue-<N>`
names with their own numbers, so a name match would join unrelated work.
Branches with a ready pull request (open and not a draft; every one needs
the owner's merge) come first; then the rest (a draft pull request, or a
worktree with no pull request). `reviewDecision` does not change the
order; it is printed as the review state when set, and nothing is printed
for it when it is empty. Within each group, branches with a worktree come
first, in the worktree list's order, then branches with only a pull
request, in the order `gh pr list` printed them.

The paths themselves, for the report's closing question: each paragraph of
the root's Direction section that opens with `**Path <n>`, printed as its
number, its bold name and its first sentence, as written.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
r="$("$WS_ROOT/.agent/scripts/sitrep_root.sh")" || { echo "no sit-rep: no root could be decided for this directory (reason above)"; exit 1; }
roadmap="$(sed -n 's/^roadmap=//p' <<< "$r")"
awk '/^## Direction/ { d = 1; next } d && /^## / { exit }
     d && /^\*\*Path [0-9]+/ { p = 1; s = "" }
     p && /^[[:space:]]*$/ { print s; p = 0; next }
     p { s = s (s == "" ? "" : " ") $0 }
     END { if (p) print s }' "${roadmap:-/dev/null}" 2>/dev/null | python3 -c '
import re, sys
n = 0
for l in sys.stdin:
    m = re.match(r"\*\*(Path \d+)[,.:]?\s*(.*?)\.?\*\*\s*(.*)", l.strip())
    if m:
        n += 1
        first = re.match(r"(.+?\.)(?:\s|$)", m.group(3))
        print("path\t%s\t%s\t%s" % (m.group(1), m.group(2), first.group(1) if first else m.group(3)))
if not n:
    print("paths=none (no **Path <n>** paragraph in the Direction section)")'
```

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

The record line is `<when>`, the root's `record_name` (`workspace` for the
workspace, the project's registered name for a project, so the next run
compares with the last line for the same root), `<summary>`, `inbox <n>`,
then that inbox line's own four fields, TAB-separated.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
rows="<rows_file printed in step 1>"
n="<inbox_lines printed in step 2>"
name="$("$WS_ROOT/.agent/scripts/sitrep_root.sh" | sed -n 's/^record_name=//p')"
source "$WS_ROOT/.agent/scripts/_settings.sh"
record="$(settings_path "$WS_ROOT" run_record)" || record=""
inbox="$(settings_path "$WS_ROOT" inbox)" || inbox=""
if [ -z "$name" ]; then
    echo "run record: not written (no root could be decided for this directory)"
elif [ -z "$record" ]; then
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
        && printf '%s\t%s\t%s\tinbox %s\t%s\n' "$(date '+%Y-%m-%d %H:%M %z')" \
            "$name" "$summary" "$n" "$seen_line" >> "$record"; then
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

### 5. Find the next step

The next step is the first Direction line that is not `true`, in roadmap
order: the first `line` row of step 1 whose result is anything else.
`unchecked` and `unknown` count as not true and are not skipped, because
the lines are an ordered chain and a line that cannot be checked is
still in the way. When step 1 printed no rows (`checks failed`, `no
summary`), there is no next line; skip this step and say so in the
report.

Look up what that line's own cells name: the title of each issue it names,
and the branch of the root's own worktree and the open pull request for
that issue (an ADR it names gets its title from the next block). Paste the row's `item` and `check` fields
between the `ROW` markers, as step 1 printed them (the check is `none`
when the cell was empty; leave it empty here). The quoted here-document
keeps any quote or `$` in the text as written.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
item="$(cat <<'ROW'
<item of the first line row whose result is not true>
ROW
)"
check="$(cat <<'ROW'
<check of that row, or nothing>
ROW
)"
source "$WS_ROOT/.agent/scripts/_issue_helpers.sh"
r="$("$WS_ROOT/.agent/scripts/sitrep_root.sh")" || { echo "no sit-rep: no root could be decided for this directory (reason above)"; exit 1; }
ROOT="$(sed -n 's/^root=//p' <<< "$r")"
src="$(sed -n 's/^pr_source=//p' <<< "$r")"
# The root's own worktrees only (own = yes): the numbers below are issues
# of the root's own repository, and a worktree of another repository can
# carry the same number.
wl="$("$WS_ROOT/.agent/scripts/sitrep_root.sh" --worktrees)" || wl=""
[ -n "$wl" ] || echo "branches: could not be listed (reason above)"
# Issue numbers from the line's own cells only: "(#N)", "(#N," or each of
# a list "(#N, #M)" in the item, and a whole "gh-issue N <open|closed>"
# check (this repository) in the check cell, split as the check runner
# splits it (at " ; ", backticks unwrapped), so a gh-issue inside another
# check's argument is not one. Never from the
# section's prose, which holds the Format paragraph's literal (#N).
nums="$( { grep -oE '\(#[0-9]+(,[[:space:]]*#[0-9]+)*[,)]' <<< "$item" | grep -oE '[0-9]+'
           awk '{ c = $0; gsub(/^[ \t]+|[ \t]+$/, "", c)
                  if (c ~ /^`[^`]*`$/) c = substr(c, 2, length(c) - 2)
                  n = split(c, part, / ; /)
                  for (i = 1; i <= n; i++) {
                      p = part[i]; gsub(/^[ \t]+|[ \t]+$/, "", p)
                      if (length(p) >= 2 && p ~ /^`.*`$/) { p = substr(p, 2, length(p) - 2); gsub(/^[ \t]+|[ \t]+$/, "", p) }
                      if (split(p, w, /[ \t]+/) == 3 && w[1] == "gh-issue" && w[2] ~ /^[0-9]+$/ && tolower(w[3]) ~ /^(open|closed)$/) print w[2] + 0
                  } }' <<< "$check"; } | sort -un)"
echo "issues_named=$(echo ${nums:-none})"
for n in $nums; do
    t=""
    if [ -z "$src" ] || [ "$src" = none ]; then
        t="unknown (no repository to read it from)"
    else
        t="$(gh issue view "$n" -R "$src" --json title --jq .title 2>/dev/null)"
        if [ -z "$t" ]; then
            # The cache only: issue_lookup pulls from GitHub on a miss, a write.
            ISSUE_TITLE=""
            _issue_lookup_gitbug "$ROOT" "https://github.com/$src/issues/$n" >/dev/null 2>&1
            t="${ISSUE_TITLE:+$ISSUE_TITLE (offline: git-bug cache)}"
        fi
    fi
    printf 'issue\t%s\t%s\n' "$n" "${t:-unknown (lookup failed)}"
    [ -z "$wl" ] || N="$n" python3 -c '
import json, os, sys
for w in json.load(sys.stdin).get("worktrees", []):
    if w.get("own") == "yes" and str(w.get("issue")) == os.environ["N"]:
        print("branch\t%s\t%s" % (w.get("branch"), w.get("path")))' <<< "$wl"
    [ -z "$src" ] || [ "$src" = none ] || gh pr list -R "$src" --state open \
        --json number,title,headRefName,isCrossRepository,isDraft,closingIssuesReferences \
        --jq ".[] | select(.isCrossRepository | not)
            | select(.headRefName == \"feature/issue-$n\"
                or ([(.closingIssuesReferences // [])[] | select(.repository != null)
                    | select((.repository.owner.login + \"/\" + .repository.name | ascii_downcase) == (\"$src\" | ascii_downcase)) | .number] | index($n)))
            | \"pull_request\t\(.number)\t\(.title)\t\(if .isDraft then \"draft\" else \"ready\" end)\""
done
```

A `branch` row is in-flight work for that line, in one of the root's own
worktrees; a `pull_request` row is its open pull request (ready or
draft), from the root's pull-request source. With no pull-request source
the title is "unknown (no repository to read it from)" and no pull
request is looked up. A pull request with no closing
references (`null` or empty), or a reference without its repository, is
matched by its branch name only. Matching is by the issue number
only, through `feature/issue-<N>` worktrees and pull requests that close
`#<N>` or come from that branch. When the line names no issue, or no
branch or pull request matches, nothing in flight advances it, and the
report says that rather than pick other work.

What the next step is for comes from the Direction section's
`**Acceptance case.**` paragraph, read by this block, which runs even
when step 1 printed no rows. The paragraph is joined into one line and
split after its first sentence (the first period followed by a space or
the end of the paragraph); nothing is reworded.

The same block renders every piece of roadmap text the report prints:
the acceptance case, and the Direction lines and deferrals pasted
between the `TEXT` markers, one per line, as step 1 printed them. The
words stay as written; two things are made readable. A markdown link
prints as its text, and an ADR number gets its title in parentheses (the
ADR file's first line, after `ADR-<NNNN>: `), unless a parenthesis
already follows it. The ADR files are the root's own (`docs/decisions/`
under the root), so a project's ADR number never gets the workspace's
title; an ADR number with no file there, or a root with no such
directory, stays as written. Each pasted line comes back as a `text=`
line, in order.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
r="$("$WS_ROOT/.agent/scripts/sitrep_root.sh")" || { echo "no sit-rep: no root could be decided for this directory (reason above)"; exit 1; }
ROOT="$(sed -n 's/^root=//p' <<< "$r")"
roadmap="$(sed -n 's/^roadmap=//p' <<< "$r")"
text="$(cat <<'TEXT'
<the Direction lines and deferrals the report prints, one per line>
TEXT
)"
awk '/^## Direction/ { d = 1; next } d && /^## / { exit }
     d && /^\*\*Acceptance case\.\*\*/ { s = 1 } s && /^[[:space:]]*$/ { exit } s { print }' \
    "${roadmap:-/dev/null}" 2>/dev/null | ROOT="$ROOT" TEXT="$text" python3 -c '
import glob, os, re, sys
def title(n):
    # The first line of the ADR file: "# ADR-<NNNN>: <title>".
    for f in sorted(glob.glob(os.path.join(os.environ["ROOT"], "docs", "decisions", n + "-*.md"))):
        try:
            with open(f, encoding="utf-8") as fh:
                return re.sub(r"^#\s*(ADR-\d{4}:\s*)?", "", fh.readline().strip())
        except (OSError, UnicodeDecodeError):
            return ""
    return ""
def render(t):
    t = re.sub(r"\[([^\]]+)\]\([^)\s]*\)", r"\1", t)
    def adr(m):
        n = title(m.group(1))
        return "%s (%s)" % (m.group(0), n) if n else m.group(0)
    return re.sub(r"\bADR-(\d{4})\b(?!\s*\((?!#))", adr, t)
p = " ".join(l.strip() for l in sys.stdin.read().splitlines()).strip()
p = re.sub(r"^\*\*Acceptance case\.\*\*\s*", "", p)
m = re.match(r"(.+?\.)(?:\s+(.*))?$", p)
print("acceptance_first=" + render(m.group(1) if m else p))
print("acceptance_rest=" + render((m.group(2) or "") if m else ""))
for l in os.environ["TEXT"].splitlines():
    if l.strip() and not l.startswith("<the Direction lines and deferrals"):
        print("text=" + render(l))'
```

`acceptance_first` is the report's second line; when it is empty (no
such paragraph), that line is left out. `acceptance_rest` is the rest of
the paragraph, for the counts section.

### 6. Read problems

Read-only facts, once per sit-rep, from the root's local default branch
(`default_branch`, usually `main`; a worktree session's own branch is not
what has landed). Commit counts leave out merge commits and commits that
touch only work plans, and are counted from the commit that set the
date: the last commit on the default branch on or before that date, or
the commit that last changed the file. A root that is not a git
repository of its own (a hosting directory, or a root inside another
repository) has no such facts: they are skipped with one line, never
read from the enclosing repository. With no default branch (no
`origin/HEAD`, and not exactly one of `main` and `master`) they are
"cannot tell". A check whose file the root does not have
(`sitrep_root.sh`'s `check_<name>=skipped (...)`) prints one skip line
naming the file.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
r="$("$WS_ROOT/.agent/scripts/sitrep_root.sh")" || { echo "no sit-rep: no root could be decided for this directory (reason above)"; exit 1; }
rv() { sed -n "s/^$1=//p" <<< "$r"; }
ROOT="$(rv root)"
DB="$(rv default_branch)"
echo "session_type=$(rv type)"
days_since() { python3 -c 'import datetime, sys; print((datetime.date.today() - datetime.date.fromisoformat(sys.argv[1])).days)' "$1"; }
# Commits on the default branch after <sha>, under the given paths: no merges, no work-plan-only commits.
since() { local sha="$1"; shift; git -C "$ROOT" rev-list --count --no-merges "$sha..$DB" -- "$@" ':!.agent/work-plans'; }
sha_at() { [ -z "$DB" ] || git -C "$ROOT" log -1 --format=%H --until="$1 23:59:59" "$DB"; }
# show <$ROOT/path>: that file as committed on the default branch.
show() { [ -z "$DB" ] || git -C "$ROOT" show "$DB:${1#"$ROOT"/}" 2>/dev/null; }

if [ "$(rv own_repo)" != yes ]; then
    echo "git_facts=skipped (this root is not a git repository of its own)"
elif [ -z "$DB" ]; then
    echo "default_branch=cannot tell (no origin/HEAD, and not exactly one of main and master)"
    echo "main_behind_origin=cannot tell (no default branch)"
# Local main can lag GitHub. Nothing is fetched (a fetch writes refs): this
# compares with origin's branch as last fetched.
elif git -C "$ROOT" rev-parse -q --verify "refs/remotes/origin/$DB" >/dev/null 2>&1; then
    echo "default_branch=$DB"
    echo "main_behind_origin=$(git -C "$ROOT" rev-list --count "$DB..refs/remotes/origin/$DB" 2>/dev/null || echo unknown)"
else
    echo "default_branch=$DB"
    echo "main_behind_origin=unknown (no origin/$DB)"
fi

# Audit: the Re-examined column of docs/design.md's Decision register.
# An escaped pipe (\|) inside a cell is not a column break: drop it before
# the line is split. Separator rows (| --- | :-: |) are skipped.
if [ "$(rv check_decision_register)" != run ]; then
    echo "audit=$(rv check_decision_register)"
else
    reg="$(show "$ROOT/docs/design.md" | awk -F'|' '
        { gsub(/\\\|/, "") }
        /^## Decision register/ { s = 1; next }
        s && /^## / { exit }
        s && /^\|/ && col == "" { for (i = 2; i < NF; i++) if ($i ~ /Re-examined/) col = i; next }
        s && /^\|/ && col != "" && $2 !~ /^[ :-]+$/ { gsub(/^ +| +$/, "", $col); print $col }')"
    if [ -z "$reg" ]; then
        echo "audit=cannot tell (no Decision register with a Re-examined column on the default branch)"
    else
        echo "audit_adrs=$(grep -c . <<< "$reg") not_yet_reexamined=$(grep -c '^not yet' <<< "$reg")"
        newest="$(grep -oE '^yes [0-9]{4}-[0-9]{2}-[0-9]{2}' <<< "$reg" | cut -d' ' -f2 | sort | tail -n1)"
        sha=""; [ -z "$newest" ] || sha="$(sha_at "$newest")"
        if [ -n "$sha" ]; then
            echo "newest_adr_reexamination=$newest days=$(days_since "$newest") commits_since=$(since "$sha" .)"
        else
            echo "newest_adr_reexamination=cannot tell (no 'yes <date>' cell, or no commit on the default branch by then)"
        fi
    fi
fi

# Research: the research skill's own staleness rule (Last verified, else
# Added; stale past 30 days, flagged for review past 90).
if [ "$(rv check_research_digest)" != run ]; then
    echo "research=$(rv check_research_digest)"
else
    show "$ROOT/.agent/knowledge/research_digest.md" | python3 -c '
import datetime, re, sys
text = sys.stdin.read()
if not text:
    print("research=cannot tell (no research digest on the default branch)"); sys.exit()
today = datetime.date.today()
m = re.search(r"Last full refresh: (\d{4}-\d{2}-\d{2})", text)
print("last_full_refresh=" + (m.group(1) if m else "none"))
ages, undated = [], 0
for line in text.splitlines():
    if not line.startswith("**Added**:"):
        continue
    d = re.search(r"Last verified\*\*: (\d{4}-\d{2}-\d{2})", line) or re.search(r"Added\*\*: (\d{4}-\d{2}-\d{2})", line)
    if d:
        ages.append((today - datetime.date.fromisoformat(d.group(1))).days)
    else:
        undated += 1
print("digest_entries=%d past_30_days=%d past_90_days=%d oldest_days=%s undated=%d" % (
    len(ages) + undated, sum(a > 30 for a in ages), sum(a > 90 for a in ages),
    max(ages) if ages else "none", undated))'
fi

# Documentation: work since docs/design.md last changed on the default branch.
if [ "$(rv check_documentation)" != run ]; then
    echo "design_doc=$(rv check_documentation)"
else
    d=""; [ -z "$DB" ] || d="$(git -C "$ROOT" log -1 --format='%H %cs' "$DB" -- docs/design.md)"
    if [ -z "$d" ]; then
        echo "design_doc=cannot tell (docs/design.md has no commit on the default branch)"
    else
        echo "design_doc_changed=${d#* } days=$(days_since "${d#* }") commits_since_touching_agent_claude_docs=$(since "${d%% *}" .agent .claude docs)"
    fi
fi
# The anchor check passes in pre-commit and CI; only a failure is news.
if [ "$(rv check_design_anchors)" != run ]; then
    echo "design_anchors=$(rv check_design_anchors)"
elif ! out="$("$WS_ROOT/.agent/scripts/check_design_anchors.sh" "$ROOT" 2>&1)"; then
    echo "design_anchors=failed"
    printf '%s\n' "$out" | head -n 10
fi
```

Each problem is printed as its facts, then one judgment word: "probably
due", "recent" or "cannot tell" (a date or count is missing).

- **Audit**: the fact is the newest `yes <date>` in the Decision
  register's Re-examined column, labelled "last design-decision review",
  never "last audit" (that column also carries the dates of the design
  rewrite). Print it with days and commits since and
  how many ADRs are still `not yet`. There is no stored cadence: judge
  from days, commits and the `not yet` count, and say which way the facts
  lean.
- **Research**: due by the research skill's written rule
  (the research skill's Staleness rules): any entry past 30
  days means "probably due"; none means "recent". Print the counts past 30
  and past 90 days and the `Last full refresh` date.
- **Documentation**: days since `docs/design.md` last changed and the
  commits since that touched `.agent/`, `.claude/` or `docs/`: work that
  may have outrun the design. Judge from the numbers. The report names
  them in words, "the design document" and, by the root's `type`, "the
  workspace's scripts, skills or docs" or "this project's scripts,
  skills or docs", not as paths. A failed anchor check is printed with
  its first lines; a passing one is not mentioned.
- **Direction**: `format` rows from step 1 and `unknown` lines (a check
  that could not run) are problems too.
- **Local main**: these facts are from the root's local default branch
  (named in the report, e.g. "local main"). When `main_behind_origin` is
  a number above 0, a Problems line says "local main is <n> commits
  behind GitHub, as last fetched; the facts above are from local main".
  When it is `unknown` or "cannot tell", the Problems heading reads
  "Problems (as of local main)". At 0 nothing is said.
- **Skipped**: every Problems fact is the session root's. A check the
  root's files do not allow (`audit=skipped (...)`, `research=skipped
  (...)`, `design_doc=skipped (...)`, `design_anchors=skipped (...)`) is
  one line naming what is missing, e.g. "Audit: skipped, this project has
  no docs/design.md". `git_facts=skipped` is one line too: "No history
  read: this root is not a git repository of its own".

### 7. Start a due check, or offer it

When the audit or research fact is "probably due":

- **Start it** when the session is a workspace session
  (`session_type=workspace`) and the Agent tool is available: launch one
  agent in the background (`run_in_background: true` where the tool takes
  it) with the prompt below, and say in its Problems line "started in the
  background". Do not start the same check twice in one session; say
  "already started this session" instead.
- **Offer it** in a workspace session with no Agent tool, as in Codex or
  agy: name the command and where to run it, e.g. "run /audit-workspace
  from the workspace".
- **In a project session, nothing is started or offered** for a due
  design-decision review or a due research digest: the Problems line
  states the facts and its judgment only. No skill checks them for a
  project: `/audit-project` does not read a Decision register's
  Re-examined column, `/audit-workspace` audits the workspace, not the
  project, and the `research` skill's digest is the workspace's. A
  check skipped for a missing file is not offered either.

Only read-only checks start on their own. Anything that writes to a
repository or GitHub (a digest edit, a Decision-register pull request, an
issue) is offered as a one-line yes/no, never done. When a background
check returns, give its findings in a few lines and offer the write as a
yes/no.

The prompts, as written, with `<workspace root>` replaced by the main
checkout's absolute path, which git names first (with no user tier,
`$WS_ROOT` is the cwd, which may be a feature worktree):

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
git -C "$WS_ROOT" worktree list --porcelain | sed -n '1s/^worktree //p'
```

- **Audit**: "From <workspace root> (the main checkout, not a feature
  worktree, so what is audited is what has landed), run the
  /audit-workspace skill's checks and report findings only. Do not edit any file, create a worktree, commit, push, or open a
  pull request or issue. Return the findings and, separately, the
  Decision-register cell changes you would propose."
- **Research**: `/research` writes in every mode (worktree, commit, push,
  pull request), so the background run is not that skill: "Do not run the
  /research skill. Read-only, no worktree, no commit, no push, no pull
  request, no issue, no file edit. Read
  <workspace root>/.agent/knowledge/research_digest.md and find the three
  entries with the oldest Last verified date (or Added date, if never
  verified), among those more than 30 days old. For each of those three,
  oldest first, do the web survey
  that steps 2 to 4 of "Refreshing" in
  <workspace root>/.claude/skills/research/SKILL.md describe, and return, as text only, the proposed
  new or changed entry content and the new Last verified date. Do not
  write anything to disk." Applying the proposals (worktree, commit, pull
  request) is offered as a one-line yes/no. Research stays due while
  any entry is past 30 days, so each new session's sit-rep starts a
  survey again; three entries keep it small. The Problems line says "the
  3 oldest started in the background".

### 8. Print the report

The top part (what the next step is for, the next step, Suggested next,
In flight, Problems) comes first and fits in about 20 lines with its blank
lines; the counts, the inbox and the deferrals follow. Plain words: the
top part names no mechanism (no "Direction lines", "result", "timeline
entry" or "Decision register"); the facts the steps above print are
translated by the rules below. No count without what it counts (never a
bare "3/6").

The layout is for reading at a glance (owner, 2026-10-15: a sample left him
unsure "if it was describing the current state, or what we still need to
do", and asked for "more whitespace to make it easier to read and see the
structure"):

- **A lead word fixes the tense** of every line that names a step or a
  piece of work: `Done:` (true now), `Not yet:` (still to become true),
  `Next:` (the action proposed), `Running:` (work in flight). A Problems
  line is a fact measured this run and keeps its topic label (`Audit:`,
  `Research:`, ...).
- **One item per line.** Steps, branches, inbox items and deferrals are
  bullets, never joined with commas or semicolons on one line.
- **A blank line** between sections, and between a section's heading and
  its bullets.

```markdown
## Sit-rep, <date>

<acceptance_first from step 5>

Done: <t> of <n> steps.
Not yet: <first unmet line, as written> — <its result in words>.
Next: <the line's text as an action>.
Running: <branch>: <its state>.

**In flight**:

- Running: <name>: <issue title> (issue <N>)<, the next step>: <state>. <path>.
- And <k> more:
  - <name>

**Problems**:

- Audit: last design-decision review <date>, <d> days and <c> commits
  ago. <k> of <n> design decisions not yet reviewed. <Judgment>
  [, started in the background | , offered: <command, where>].
- Research: <k> of <n> research topics last checked more than 30 days
  ago (<m> more than 90). Last full refresh <date>. <Judgment>
  [, the 3 oldest started in the background | , offered: ...].
- Documentation: the design document last changed <date>, <d> days
  ago. <c> commits since changed <the workspace's | this project's>
  scripts, skills or docs. <Judgment>.
- Deferral due: <the deferral, as written>.
- <only when present: local main behind GitHub, a failed anchor check,
  a malformed Direction section, a step whose check could not run, a
  check skipped for a file this root does not have, worktrees that
  could not be listed>

**Steps**: <t> of <n> done.

- Done: <line, as written>.
- Not yet: <line, as written> — <result in words>.

<What moved: compare the summary with the last run record's, in words,
e.g. "steps done: 3 of 6 on 2026-10-10, 4 of 6 now"; "first run" when
there is no earlier line.>

<acceptance_rest, when not empty>

**Inbox**: <n> lines, <k> new since the last run (or "new since the last
run: unknown", with the reason). `/sitrep inbox` for a proposed sort.

- New: <a new line in a few words>

**Deferrals**: <k> of <n> due (under Problems).

- No automatic check yet: <deferral, as written>
```

Rules for the report:

- **Roadmap text is printed as step 5 rendered it.** The acceptance
  case, the Direction lines and the deferrals keep their words ("as
  written" in the template), but never show markdown link syntax or a
  bare ADR number whose ADR file has a title: use step 5's
  `acceptance_first`, `acceptance_rest` and `text=` lines, not step 1's
  rows.
- **The line after the heading** is step 5's `acceptance_first`, so the
  reader sees what the next step is for. When it is empty, the line is
  left out.
- **Result words** are translated, and always printed, so a step that
  could not be checked never reads as one that failed:

  | Result | Words |
  |---|---|
  | `true` | done |
  | `false` | not yet done |
  | `unchecked` | not yet done (no automatic check) |
  | `partial` | partly done (its checks disagree) |
  | `unknown` | could not be checked |

- **The `Done:` and `Not yet:` lines** give the count of steps done, then
  the first unmet line as written, and its result in words. An issue number in the line,
  written `(#<N>`, reads `(issue <N>`.
- **Suggested next** is the `Next:` line: it restates that line as
  something to do, keeping its own words and names ("X is onboarded
  through Y" becomes "Onboard X through Y"). The `Running:` line under it
  gives the branch step 5 matched and step 3's state for it, then, when
  step 5 matched one, "; pull request <M>: <draft or ready>". It does not
  print the issue's title. When step 5 matched nothing, it reads
  "Running: nothing advances it."
- Only when every line is `true` does Suggested next come from
  elsewhere, from the first of these with an item: a due deferral; work
  in flight (a branch with a ready pull request first, step 3's order);
  the proposed inbox "now" bin, which says "this rests on the proposed
  inbox sort", since that bin is this run's proposal, not a checked
  fact. When none has one: "Next: nothing from this run's
  facts." When step 1 checked nothing, it says the steps were not
  checked this run, and why.
  - The main checkout is not work in flight: the worktree list of a
    workspace session includes it (`type: "main"`), so it is never a
    candidate. The
    worktree this session runs in counts like any other.
- **Titles once.** An issue's title is printed once, in its In flight
  line; everywhere else the issue is "issue <N>". An issue the report
  names that has no In flight line gets its title at its first mention.
  A pull request joined to a branch is "pull request <M>" on that line,
  labelled by the issue's title; a pull request with no worktree
  carries its own title.
- **In flight** has one line per branch, in step 3's order, at most
  five. More than five: the first five, then "And <k> more:" with one
  bullet per name under it. The next step's branch is always among the five shown (it
  takes the fifth place when it would fall below). A line is filled in
  part by part, and a part the branch does not have is left out:
  - `<name>` is the branch, or for a worktree that is not the root's
    own (`own` is `no`: another repository's work a Direction line of
    this root names) its `repo` (`workspace` for a workspace worktree),
    a slash and the branch, e.g. `myproject/feature/issue-12` in the
    workspace's report.
  - Then the issue's title and "(issue <N>)", then ", the next step"
    when step 5 matched this branch, then the state from step 3's
    table (e.g. "plan approved, implementing").
  - A branch with a pull request adds "; pull request <M>: <draft or
    ready>", then "from a fork" if `isCrossRepository` is true, then the
    review state in words if `reviewDecision` is set ("approved",
    "changes requested", "review required"). One of the root's own
    worktrees with no pull request whose state is "implemented" reads
    "implemented, no pull request yet", when the root has a
    pull-request source. A worktree that is not the root's own has its
    pull requests in another repository, which are not looked up, so
    its line says nothing about one; with no pull-request source for
    the root, no line says anything about pull requests.
  - A pull request with no worktree: its title, "(pull request <M>)",
    then the same draft, fork and review words.
  - Last, after a period, the path step 3 printed: `Path 1`, `Path 2`,
    `no path` or one of its "path unknown (...)" labels; nothing when
    step 3 printed an empty path (the root's Direction section has no
    Paths paragraph). A branch with only a
    pull request has no timeline here, so no Serves line was read:
    `Path 1` when a Direction line names its issue, else "path unknown
    (no worktree, timeline not read)". Its issue is the `<N>` of a
    `feature/issue-<N>` head branch, or an issue in step 3's
    `closingIssuesReferences` whose repository is this one (the match
    step 5 makes); with neither, it is path unknown. Never `no path`,
    which says the work serves neither path.
- **Problems** in words: the Decision register's newest `yes <date>` is
  the "last design-decision review", its `not yet` rows "design
  decisions not yet reviewed"; digest entries are "research topics".
  A deferral whose revisit check is `true` is listed here, as written,
  on every run, whether or not a step is unmet. Step 6's local-main rule
  says when local main lagging GitHub is a line, or "(as of local main)"
  goes on the heading. `format` rows and `unknown` lines go here too.
- In the Steps section a `true` line is a `Done:` bullet; a `false`,
  `unknown`, `partial` or `unchecked` line is a `Not yet:` bullet with
  its result in words.
- A deferral is due only when its result is `true`. An `unchecked`
  deferral is listed as having no automatic check, never as due.
- The inbox is its line and one `New:` bullet per new line (at most
  five; "And <k> more new" after them). The five-bin sort is printed only for
  `/sitrep inbox`, after the Inbox line:
  ```markdown
  Proposed sort, to answer in batches:
  - now: <items>
  - next: <items>
  - someday: <items>
  - decided against, revisit when <condition>: <items>
  - delete: <items>
  ```
  The sort is a proposal. Use only these five bins; never "never" —
  "decided against" always carries the condition that would reopen it.
  Do not edit the inbox; filing issues or editing the roadmap from the
  answers is a separate step the owner asks for.
- After the report, end with at most one question, the one whose answer
  changes the most. The suggestion proposes an action; the question asks
  the owner to decide something. By default it is the focus: Path 1, Path
  2 or both, each named as step 3's last block printed it (its number,
  name and first sentence). The owner decides the focus when he asks for
  a sit-rep, and it is never stored. Ask something else only when the
  owner already named the focus in this session, or when step 3 printed
  `paths=none`.
