---
name: sitrep
description: "Use when asked 'what's next?', 'what should I work on?' or 'where are we?'. Situation report from checked facts, easy to take in: the next step towards the goals (the first Direction line not yet true, checked this run, and the work in flight for it), where work in flight stands, and problems to know about (an audit or research due, documentation that may have fallen behind, judged by dates and commits since), then the counts, the inbox and deferrals. Reads only, except one line to a machine-local run record; in a workspace session it may start a due read-only check in the background and says so."
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
/sitrep          # the report
/sitrep inbox    # the report, with a proposed sort of the inbox
```

This first mode reads the workspace root only.

## What it is

A read-out that answers "what's next?" from facts checked this run, in
the order the owner needs them: what to work on next towards the goals,
where the work in flight stands, and problems he should know about. It
replaces the old what-next skill, which ranked roadmap rows; this one
answers from checked facts instead. The skill formats and proposes; it
decides nothing. The "Suggested next" line and the inbox sort are
proposals for the owner to accept or change. The one thing it starts on
its own is a read-only check that is due (step 7), and the report says
so. Every statement in the report comes from a command run in this
invocation: the check runner's rows, the inbox file, the worktree list,
the open pull requests, the issue timelines, and the files and history
of local `main`. Memory notes, earlier conversation and earlier reports
are not sources. If something could not be checked, say so; never fill
the gap.

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
        --json number,title,headRefName,isCrossRepository,isDraft,reviewDecision,updatedAt
else
    echo "pull requests: not checked (no GitHub remote for $WS_ROOT)"
fi
```

`-R` names the workspace repository from its own remote, so a project
session does not list the project's pull requests by mistake. With no
GitHub remote the pull requests are reported as not checked. The list
always includes the main checkout (`type: "main"`); it is not work in
flight and is left out of the report. For each other worktree with an
issue, where the work stands is the issue's title and the latest entry on
its timeline (`progress.md`, read by `progress_read.py`):

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
source "$WS_ROOT/.agent/scripts/_issue_helpers.sh"
"$WS_ROOT/.agent/scripts/worktree_list.sh" --json | python3 -c '
import json, sys
for w in json.load(sys.stdin).get("worktrees", []):
    if w.get("type") != "main" and w.get("issue"):
        print("\t".join(str(w.get(k) or "") for k in ("type", "repo", "branch", "issue", "path")))' |
while IFS=$'\t' read -r type repo branch issue path; do
    # The issue lives in the repository the worktree belongs to. A package
    # worktree (ADR-0012, a .worktree-repos manifest) is an aggregate
    # directory, not a checkout: its header names the issue's repository
    # (issue=<owner/repo>#<N>), and the timeline is at its root or in one
    # of the checkouts its entries list. A bare issue=<N> header gives the
    # repository only when every listed checkout has the same one.
    slug=""; cache="$path"; dirs="$path"; why="no GitHub remote"
    if [ -f "$path/.worktree-repos" ]; then
        hdr="$(head -n1 "$path/.worktree-repos" | sed -n 's/.* issue=\([^ ]*\).*/\1/p')"
        [[ "$hdr" == */*#* ]] && slug="${hdr%#*}"
        cache=""; agree=""
        while IFS=$'\t' read -r _origin rel _branch; do
            [ -n "$rel" ] || continue
            d="$path"; [ "$rel" = "." ] || d="$path/$rel"
            dirs="$dirs"$'\n'"$d"
            s="$(extract_gh_slug "$(git -C "$d" remote get-url origin 2>/dev/null)")"
            if [[ "$hdr" != */*#* ]]; then
                if [ -z "$agree" ]; then agree="$s"; elif [ "$agree" != "$s" ]; then agree="-"; fi
            fi
            [ -z "$cache" ] && [ -n "$s" ] && { [ "$s" = "$slug" ] || [[ "$hdr" != */*#* ]]; } && cache="$d"
        done < <(tail -n +2 "$path/.worktree-repos")
        if [[ "$hdr" != */*#* ]]; then
            if [ "$agree" = "-" ]; then why="its checkouts are in different repositories"; else slug="$agree"; fi
        fi
    else
        slug="$(extract_gh_slug "$(git -C "$path" remote get-url origin 2>/dev/null)")"
    fi
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
    latest="no progress.md"
    f=""
    while IFS= read -r d; do
        [ -f "$d/.agent/work-plans/issue-$issue/progress.md" ] && { f="$d/.agent/work-plans/issue-$issue/progress.md"; break; }
    done <<< "$dirs"
    if [ -n "$f" ]; then
        latest="$(python3 "$WS_ROOT/.agent/scripts/progress_read.py" "$f" 2>/dev/null | python3 -c '
import json, sys
try:
    e = json.load(sys.stdin).get("entries", [])
    print("%s %s" % (e[-1].get("type"), e[-1].get("status") or "(no status)") if e else "no entries")
except ValueError:
    print("unreadable")')"
    fi
    printf '%s\t%s\t%s\tissue %s\t%s\t%s\n' "$type" "${repo:-workspace}" "$branch" "$issue" "$title" "$latest"
done
```

Rows are `type`, `repo`, `branch`, `issue <N>`, title, latest entry
(`<type> <status>`, e.g. `Implementation complete`), TAB-separated. A
worktree with no issue (a skill worktree) gets no row; its line names the
branch only. A package worktree's `branch` is its checkouts' branches,
comma-separated, as the worktree list gives it. Reading across roots is allowed (`session_root.sh`); nothing
here writes.

The report gives one line per branch. The pull requests listed are the
workspace's, so only a workspace worktree (`type: "workspace"`) is matched
to one: when its `branch` equals the pull request's `headRefName` and the
pull request's `isCrossRepository` is false, they are the same work and
share that line. A pull request from a fork (`isCrossRepository` true)
can reuse a local branch name, so it is never joined: it gets its own
line, with "from a fork" after its title and no worktree part. A project
worktree (`type: "project"`) gets its own line, named with its project
(`repo`), and no pull request: project branches use the same `feature/issue-<N>`
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

### 5. Find the next step

The next step is the first Direction line that is not `true`, in roadmap
order: the first `line` row of step 1 whose result is anything else.
`unchecked` and `unknown` count as not true and are not skipped, because
the lines are an ordered chain and a line that cannot be checked is
still in the way. When step 1 printed no rows (`checks failed`, `no
summary`), there is no next line; skip this step and say so in the
report.

Look up what that line's own cells name: the title of each issue it names,
the workspace worktree branch and open pull request for that issue, and
the title of each ADR it names. Paste the row's `item` and `check` fields
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
WS_REPO="$(extract_gh_slug "$(git -C "$WS_ROOT" remote get-url origin 2>/dev/null)")"
# Issue numbers from the line's own cells only: "(#N)" or "(#N," in the
# item, "gh-issue N" (this repository) in the check. Never from the
# section's prose, which holds the Format paragraph's literal (#N).
nums="$( { grep -oE '\(#[0-9]+[,)]' <<< "$item"; grep -oE '(^|[;`[:space:]])gh-issue [0-9]+ ' <<< "$check"; } \
    | grep -oE '[0-9]+' | sort -un)"
echo "issues_named=$(echo ${nums:-none})"
for n in $nums; do
    t=""
    [ -n "$WS_REPO" ] && t="$(gh issue view "$n" -R "$WS_REPO" --json title --jq .title 2>/dev/null)"
    if [ -z "$t" ] && [ -n "$WS_REPO" ]; then
        # The cache only: issue_lookup pulls from GitHub on a miss, a write.
        ISSUE_TITLE=""
        _issue_lookup_gitbug "$WS_ROOT" "https://github.com/$WS_REPO/issues/$n" >/dev/null 2>&1
        t="${ISSUE_TITLE:+$ISSUE_TITLE (offline: git-bug cache)}"
    fi
    printf 'issue\t%s\t%s\n' "$n" "${t:-unknown (lookup failed)}"
    "$WS_ROOT/.agent/scripts/worktree_list.sh" --json | N="$n" python3 -c '
import json, os, sys
for w in json.load(sys.stdin).get("worktrees", []):
    if w.get("type") == "workspace" and str(w.get("issue")) == os.environ["N"]:
        print("branch\t%s\t%s" % (w.get("branch"), w.get("path")))'
    [ -z "$WS_REPO" ] || gh pr list -R "$WS_REPO" --state open \
        --json number,title,headRefName,isCrossRepository,isDraft,closingIssuesReferences \
        --jq ".[] | select(.isCrossRepository | not)
            | select(.headRefName == \"feature/issue-$n\"
                or ([(.closingIssuesReferences // [])[] | select(.repository != null)
                    | select((.repository.owner.login + \"/\" + .repository.name) == \"$WS_REPO\") | .number] | index($n)))
            | \"pull_request\t\(.number)\t\(.title)\t\(if .isDraft then \"draft\" else \"ready\" end)\""
done
# ADR numbers in the item, with the ADR file's own title (its first line).
for a in $(grep -oE 'ADR-[0-9]{4}' <<< "$item" | sort -u); do
    f="$(ls "$WS_ROOT/docs/decisions/${a#ADR-}"-*.md 2>/dev/null | head -n1)"
    t=""; [ -n "$f" ] && t="$(sed -n '1s/^# *//p' "$f")"
    printf 'adr\t%s\t%s\n' "$a" "${t:-unknown (no ADR file)}"
done
echo "---"
# The acceptance case paragraph, printed as written for the counts section.
awk '/^\*\*Acceptance case\.\*\*/ { s = 1 } s && /^[[:space:]]*$/ { exit } s { print }' \
    "$WS_ROOT/docs/roadmap.md" 2>/dev/null
```

A `branch` row is in-flight work for that line; a `pull_request` row is
its open pull request (ready or draft). A pull request with no closing
references (`null` or empty), or a reference without its repository, is
matched by its branch name only. Matching is by the issue number
only, through `feature/issue-<N>` worktrees and pull requests that close
`#<N>` or come from that branch. When the line names no issue, or no
branch or pull request matches, nothing in flight advances it, and the
report says that rather than pick other work.

### 6. Read problems

Read-only facts, once per sit-rep, from local `main` in `$WS_ROOT` (a
worktree session's own branch is not what has landed). Commit counts
leave out merge commits and commits that touch only work plans, and are
counted from the commit that set the date: the last commit on `main` on or
before that date, or the commit that last changed the file.

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
days_since() { python3 -c 'import datetime, sys; print((datetime.date.today() - datetime.date.fromisoformat(sys.argv[1])).days)' "$1"; }
# Commits on main after <sha>, under the given paths: no merges, no work-plan-only commits.
since() { local sha="$1"; shift; git -C "$WS_ROOT" rev-list --count --no-merges "$sha..main" -- "$@" ':!.agent/work-plans'; }
sha_at() { git -C "$WS_ROOT" log -1 --format=%H --until="$1 23:59:59" main; }
# show <$WS_ROOT/path>: that file as committed on main.
show() { git -C "$WS_ROOT" show "main:${1#"$WS_ROOT"/}" 2>/dev/null; }

st="$("$WS_ROOT/.agent/scripts/session_root.sh" 2>/dev/null | sed -n 's/^type=//p')"
echo "session_type=${st:-unknown}"

# Audit: the Re-examined column of docs/design.md's Decision register.
# An escaped pipe (\|) inside a cell is not a column break: drop it before
# the line is split. Separator rows (| --- | :-: |) are skipped.
reg="$(show "$WS_ROOT/docs/design.md" | awk -F'|' '
    { gsub(/\\\|/, "") }
    /^## Decision register/ { s = 1; next }
    s && /^## / { exit }
    s && /^\|/ && col == "" { for (i = 2; i < NF; i++) if ($i ~ /Re-examined/) col = i; next }
    s && /^\|/ && col != "" && $2 !~ /^[ :-]+$/ { gsub(/^ +| +$/, "", $col); print $col }')"
if [ -z "$reg" ]; then
    echo "audit=cannot tell (no Decision register with a Re-examined column on main)"
else
    echo "audit_adrs=$(grep -c . <<< "$reg") not_yet_reexamined=$(grep -c '^not yet' <<< "$reg")"
    newest="$(grep -oE '^yes [0-9]{4}-[0-9]{2}-[0-9]{2}' <<< "$reg" | cut -d' ' -f2 | sort | tail -n1)"
    sha=""; [ -z "$newest" ] || sha="$(sha_at "$newest")"
    if [ -n "$sha" ]; then
        echo "newest_adr_reexamination=$newest days=$(days_since "$newest") commits_since=$(since "$sha" .)"
    else
        echo "newest_adr_reexamination=cannot tell (no 'yes <date>' cell, or no commit on main by then)"
    fi
fi

# Research: the research skill's own staleness rule (Last verified, else
# Added; stale past 30 days, flagged for review past 90).
show "$WS_ROOT/.agent/knowledge/research_digest.md" | python3 -c '
import datetime, re, sys
text = sys.stdin.read()
if not text:
    print("research=cannot tell (no research digest on main)"); sys.exit()
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

# Documentation: work since docs/design.md last changed on main.
d="$(git -C "$WS_ROOT" log -1 --format='%H %cs' main -- docs/design.md)"
if [ -z "$d" ]; then
    echo "design_doc=cannot tell (docs/design.md has no commit on main)"
else
    echo "design_doc_changed=${d#* } days=$(days_since "${d#* }") commits_since_touching_agent_claude_docs=$(since "${d%% *}" .agent .claude docs)"
fi
# The anchor check passes in pre-commit and CI; only a failure is news.
if ! out="$("$WS_ROOT/.agent/scripts/check_design_anchors.sh" "$WS_ROOT" 2>&1)"; then
    echo "design_anchors=failed"
    printf '%s\n' "$out" | head -n 10
fi
```

Each problem is printed as its facts, then one judgment word: "probably
due", "recent" or "cannot tell" (a date or count is missing).

- **Audit**: the fact is the newest `yes <date>` in the Decision
  register's Re-examined column, labelled "newest ADR re-examination
  (Decision register)", never "last audit" (that column also carries the
  dates of the design rewrite). Print it with days and commits since and
  how many ADRs are still `not yet`. There is no stored cadence: judge
  from days, commits and the `not yet` count, and say which way the facts
  lean.
- **Research**: due by the research skill's written rule
  (the research skill's Staleness rules): any entry past 30
  days means "probably due"; none means "recent". Print the counts past 30
  and past 90 days and the `Last full refresh` date.
- **Documentation**: days since `docs/design.md` last changed and the
  commits since that touched `.agent/`, `.claude/` or `docs/`: work that
  may have outrun the design. Judge from the numbers. A failed anchor
  check is printed with its first lines; a passing one is not mentioned.
- **Direction**: `format` rows from step 1 and `unknown` lines (a check
  that could not run) are problems too.
- In a project session (`session_type=project`), the Problems section is
  the workspace's only, and the report says so; nothing is read from the
  project.

### 7. Start a due check, or offer it

When the audit or research fact is "probably due":

- **Start it** when the session is a workspace session
  (`session_type=workspace`) and the Agent tool is available: launch one
  agent in the background (`run_in_background: true` where the tool takes
  it) with the prompt below, and say in its Problems line "started in the
  background". Do not start the same check twice in one session; say
  "already started this session" instead.
- **Offer it** otherwise (a project session, `session_type` unknown, or
  no Agent tool, as in Codex or agy): name the command and where to run
  it, e.g. "run /audit-workspace from the workspace". These skills have no
  `session_scope`, so a project session does not have them.

Only read-only checks start on their own. Anything that writes to a
repository or GitHub (a digest edit, a Decision-register pull request, an
issue) is offered as a one-line yes/no, never done. When a background
check returns, give its findings in a few lines and offer the write as a
yes/no.

The prompts, as written, with `<workspace root>` replaced by the
`$WS_ROOT` path:

- **Audit**: "Run the /audit-workspace skill's checks and report findings
  only. Do not edit any file, create a worktree, commit, push, or open a
  pull request or issue. Return the findings and, separately, the
  Decision-register cell changes you would propose."
- **Research**: `/research` writes in every mode (worktree, commit, push,
  pull request), so the background run is not that skill: "Do not run the
  /research skill. Read-only, no worktree, no commit, no push, no pull
  request, no issue, no file edit. Read
  <workspace root>/.agent/knowledge/research_digest.md and find entries whose Last verified date is more than 30 days old. For
  each, in oldest-first order, do the web survey the research skill's
  --refresh steps 2 to 4 describe, and return, as text only, the proposed
  new or changed entry content and the new Last verified date. Do not
  write anything to disk." Applying the proposals (worktree, commit, pull
  request) is offered as a one-line yes/no.

### 8. Print the report

The top four parts (direction, Suggested next, In flight, Problems) come
first and fit in about 15 lines; counts, inbox and deferrals follow. Plain
words. Every number has its label: no issue, pull request or ADR number
without its title beside it, and no count without what it counts (never
a bare "3/6").

```markdown
## Sit-rep, <date>

<t> of <n> Direction lines true; next: <first unmet line, as written,
each number with its title> — <its result word>.

**Suggested next**: <one item> — <the fact it rests on>.

**In flight**: one line per branch, in the order step 3 gives:
- <name>: <worktree part>; <pull request part>

**Problems**:
- Audit: newest ADR re-examination (Decision register) <date>, <d> days
  and <c> commits ago; <k> of <n> ADRs not yet re-examined — <judgment>
  [; started in the background | ; offered: <command, where>].
- Research: <k> of <n> digest entries last verified more than 30 days ago
  (<m> more than 90); last full refresh <date> — <judgment> [...].
- Documentation: docs/design.md last changed <date>, <d> days ago; <c>
  commits since touched .agent/, .claude/ or docs/ — <judgment>.
- <a failed anchor check, format rows, unknown lines: only when present>

**Acceptance case**: <the paragraph step 5 printed, as written>
Not yet true: <line — result>; ... <What moved: compare the summary with
the last run record's, in words, e.g. "Direction lines true: 3 of 6 on
2026-10-10, 4 of 6 now"; "first run" when there is no earlier line.>
Workspace root only; registered project roots are not read in this mode.

**Inbox**: <n> lines, <k> new since the last run (or "new since the last
run: unknown", with the reason)<: the new ones in a few words each, when
they fit on this line>. `/sitrep inbox` for a proposed sort.

**Deferrals due**: <deferrals whose check is true, or "none">.
Unchecked (no revisit check): <deferrals whose result is unchecked>.
```

Rules for the report:

- The direction sentence and "Suggested next" both come from step 5's
  line. The result word is always printed, so a line that could not be
  checked never reads as a line that failed: `unknown` reads "check could
  not run", `unchecked` reads "unchecked (no check yet)".
- "Suggested next" is that line, and with it the branch and pull request
  step 5 matched, each with its title and step 3's timeline state, e.g.
  "The acceptance project is onboarded … — in flight on
  feature/issue-332, onboard-project registers projects (issue 332):
  Implementation complete, no pull request yet". When step 5 matched
  nothing, it reads "<line> — nothing in flight advances it".
- Only when every Direction line is `true` does "Suggested next" come
  from elsewhere, from the first of these with an item: a due deferral
  (with its check); work in flight (a branch with a ready pull request
  first, step 3's order); the proposed inbox "now" bin, which says "this
  rests on the proposed inbox sort", since that bin is this run's
  proposal, not a checked fact. When none has one: "Suggested next:
  nothing from this run's facts." When step 1 checked nothing, it says
  the Direction lines were not checked this run, and why.
  - The main checkout is not work in flight: the worktree list always
    includes it (`type: "main"`), so it is never a candidate. The
    worktree this session runs in counts like any other.
- A `false`, `unknown`, `partial` or `unchecked` line goes under "Not yet
  true" with its result word.
- A deferral is due only when its result is `true`. An `unchecked`
  deferral is listed as unchecked, never as due.
- An In flight line is filled in part by part, and a part the branch does
  not have is left out:
  - `<name>` is the branch, or for a project worktree its project
    (`repo`), a slash and the branch, e.g. `myproject/feature/issue-12`.
  - The worktree part is the issue's title, then "(issue <N>)", then the
    latest timeline entry's type and status from step 3, e.g.
    "onboard-project registers projects (issue 332): Implementation
    complete". A branch with a worktree but no pull request ends with "no
    pull request yet".
  - The pull request part is the title, then "from a fork" if
    `isCrossRepository` is true, then "draft" if it is one, then the
    review state if `reviewDecision` is set.
  - "; " goes only between the two parts, so a line with only a pull
    request or only a worktree has none.
- The inbox is one line. The five-bin sort is printed only for
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
- `format` rows are reported under Problems, not as lines.
- After the report, end with at most one question, the one whose answer
  changes the most. The suggestion proposes an action; the question asks
  the owner to decide something.
