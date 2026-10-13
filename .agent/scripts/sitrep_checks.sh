#!/usr/bin/env bash
# .agent/scripts/sitrep_checks.sh
# Run the checks named in a roadmap's `## Direction` section and print one
# row per line (issue #386). Read-only. The sit-rep skill formats this
# output; it decides nothing itself.
#
# Usage: sitrep_checks.sh [--root <dir>] [--roadmap <file>] [--summary]
#        sitrep_checks.sh --summary-from <rows-file>
#   --root     the roadmap's repository root (default: this script's own
#              checkout, resolved through symlinks, so a run through the
#              repo-root `scripts/` link finds it). Relative paths in checks
#              resolve against it, and gh-issue takes its repo from its
#              `origin` remote.
#   --roadmap  default <root>/docs/roadmap.md
#   --summary  print one line instead of rows:
#                lines <true>/<total> deferrals <true>/<total>
#              (a deferral whose check is true is due). The sit-rep stores
#              this line in its run record.
#   --summary-from <rows-file>
#              the same line, counted from rows saved by an earlier run; no
#              roadmap is read and no check runs. The sit-rep runs the checks
#              once, saves the rows, and takes both the summary it shows and
#              the one it records from them. Exit 2, with a message and no
#              summary, for an empty argument, an unreadable or empty file,
#              or a line that is not a whole row (five TAB-separated fields,
#              a known kind and result word, a date): a cut-off or failed
#              run is never counted. Blank lines are skipped. Exit 3, with
#              a message and no summary, when the rows say the roadmap was
#              not read (`(roadmap not found: ...)` or `(roadmap not
#              readable: ...)`): no Direction line was looked at, so there
#              is no 0/0 to record. A roadmap that was read and has no
#              section or no rows still counts, as 0/0. `--summary` exits
#              3 the same way.
#
# What is read: only the `## Direction` section (up to the next level-1 or
# level-2 heading: `#` or `##` with up to 3 spaces of indent, or a setext
# `===`/`---` underline under paragraph text; `###` stays inside), outside
# fenced code. Fences are tracked from
# the top of the file, so a fenced `## Direction` example is not the
# section. A fence opens with 3+ backticks or tildes (up to 3 spaces of
# indent; after backticks, no further backtick on the line, as in
# CommonMark) and closes with a run of the same character at least as long
# and nothing after it. Tables are picked by header:
#   | Line | Check |               -> rows of kind `line`
#   | Deferral | Revisit check |   -> rows of kind `deferral`
# Any other table in the section is ignored. Cells split on `|` as GFM
# does: `\|` is a literal pipe in the cell (and in the check), and no other
# backslash is special. A row with more than two cells is `unchecked`, with
# every cell after the first shown in <check>. A checklist item (`- [ ]`,
# `- [x]`) in the section prints a `format` row, `unchecked`, so the misuse
# is visible (update_roadmap.sh would tick it on merge). So does a row
# below the delimiter row with only empty cells, dashes or colons
# (`|  |  |`, `| - | |`): item `(empty row in the Line table: <row>)`.
#
# Output: one TAB-separated row per item:
#   <kind>  <item>  <result>  <check>  <date>
# <check> is the cell text, or `none` when the cell is empty. `section` rows,
# result `unchecked`, say why there is nothing to check: the item is
# `(roadmap not found: <path>)`, `(no Direction section)`, `(no Line or
# Deferral table)` for a section that has neither table (an empty section
# included), or `(no rows in the Line or Deferral tables)` for tables with
# a header and nothing under it. A roadmap that exists but cannot be read
# (no permission, not a regular file, under a directory that cannot be
# entered) gives `(roadmap not readable: <path>)`, result `unknown`, never
# a "no Direction section". Every run prints at least one row. Rows
# are printed only at the end, so a run that is interrupted prints none and
# exits non-zero (128 + the signal). Exit 0 when the rows were printed; 1
# when they could not be written; 2 on usage; 3 under `--summary` (and
# `--summary-from`) when the roadmap was not read.
#
# Check grammar (a cell may join several checks with ` ; `; a check may be
# wrapped in backticks, and so may a whole cell, which is unwrapped before
# it is split). Each check is split into words with `read -ra`
# under `set -f`: nothing is globbed, nothing is eval'd.
#   file-exists <relpath>
#   file-contains <relpath> <fixed string>   (the rest of the check;
#                                              grep -qF; a missing file is
#                                              false)
#   adr-status <relpath> <word>              (the first non-blank line after
#                                              the file's first `## Status`
#                                              heading outside fenced code
#                                              starts with <word>, bold or
#                                              not, any case; <word> is
#                                              letters only; a missing file
#                                              is false, no Status heading
#                                              is unknown)
#   gh-issue <N> <open|closed>               (repo from <root>'s origin)
#   gh-issue <owner/repo>#<N> <open|closed>
#   script <form>, where <form> is exactly one of
#       adapter --project <name> validate     (<name>: [A-Za-z0-9._-]+, and
#                                              registered on this machine)
#       user_tier_install.sh --check
#       user_tier_install.sh --check --require
#       check_design_anchors.sh
#     run from this script's own .agent/scripts directory (tests point
#     SITREP_SCRIPTS_DIR at a sandbox copy), with the cwd at that checkout's
#     root. A project root's .agent/scripts is never consulted.
# A path is tested as written: a trailing `/` names a directory, so
# `file-exists f.txt/` is false for a regular file f.txt.
# Anything else is `unchecked`: an absolute path or one containing `..`, a
# path that resolves (through a symlink) outside the root, an unknown kind,
# any other script form, malformed gh-issue arguments (an owner/repo slug
# must start with a letter or digit, a repo name may start with `.` or `_`),
# a bare `#N`, an empty cell.
#
# Results: true (exit 0) / false (exit 1) / unknown (could not run: gh or
# the script missing or failing, an exit above 1, grep error, timeout, no
# timeout command, an unregistered adapter name, a malformed registry, a
# directory on the path that cannot be entered) /
# unchecked (no check) / partial (a mixed cell). Several checks combine:
# any unknown -> unknown; else all unchecked -> unchecked; else any
# unchecked -> partial; else all true -> true, all false -> false, mixed ->
# partial. The five words are a trial.
#
# `script user_tier_install.sh --check` exits 1 both on drift and when it
# cannot check (a settings.json that is not valid JSON), so that case reads
# `false`, not `unknown`; its message is on stderr, which is not read here.
#
# External calls and file reads run under `timeout` ($SITREP_TIMEOUT
# seconds, default 60), with SIGKILL $SITREP_KILL_AFTER seconds later
# (default 5) for a check that ignores TERM. They never read this script's
# stdin, which is the roadmap while it is being read.
#
# ADR-0010 departure: gh-issue reads the state with `gh -R <repo> issue
# view` directly, not issue_lookup. A git-bug cache hit is not refreshed, so
# it is not "checked this run"; a gh failure gives `unknown`, never a stale
# answer.

set -uo pipefail
set -f

# -P: through the repo-root `scripts/` symlink, a logical path's `../..`
# would be the checkout's parent.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPTS_DIR="${SITREP_SCRIPTS_DIR:-$SCRIPT_DIR}"
TIMEOUT_SECS="${SITREP_TIMEOUT:-60}"
KILL_AFTER="${SITREP_KILL_AFTER:-5}"

# shellcheck source=_issue_helpers.sh
source "$SCRIPT_DIR/_issue_helpers.sh"
REGISTRY_OK=true
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh" 2>/dev/null || REGISTRY_OK=false

usage() {
    echo "usage: sitrep_checks.sh [--root <dir>] [--roadmap <file>] [--summary]" >&2
    echo "       sitrep_checks.sh --summary-from <rows-file>" >&2
    exit 2
}

ROOT=""
ROADMAP=""
SUMMARY=false
SUMMARY_FROM=""
while [ $# -gt 0 ]; do
    case "$1" in
        --root) [ $# -ge 2 ] || usage; ROOT="$2"; shift 2 ;;
        --roadmap) [ $# -ge 2 ] || usage; ROADMAP="$2"; shift 2 ;;
        --summary) SUMMARY=true; shift ;;
        --summary-from)
            [ $# -ge 2 ] || usage
            [ -n "$2" ] || { echo "--summary-from needs a rows file; got an empty argument" >&2; exit 2; }
            SUMMARY_FROM="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "unknown argument: $1" >&2; usage ;;
    esac
done

# summarize: the summary line of the rows in ROWS.
summarize() {
    local r k res lt=0 ln=0 dt=0 dn=0
    for r in "${ROWS[@]}"; do
        k="${r%%$'\t'*}"
        res="${r#*$'\t'}"
        res="${res#*$'\t'}"
        res="${res%%$'\t'*}"
        case "$k" in
            line) ln=$((ln + 1)); [ "$res" = true ] && lt=$((lt + 1)) ;;
            deferral) dn=$((dn + 1)); [ "$res" = true ] && dt=$((dt + 1)) ;;
        esac
    done
    echo "lines $lt/$ln deferrals $dt/$dn"
}

ROWS=()
if [ -n "$SUMMARY_FROM" ]; then
    [ -f "$SUMMARY_FROM" ] && [ -r "$SUMMARY_FROM" ] || { echo "rows file not readable: $SUMMARY_FROM" >&2; exit 2; }
    ROW_RE=$'^(line|deferral|format|section)\t[^\t]*\t(true|false|unknown|unchecked|partial)\t[^\t]+\t[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    n=0
    not_read=""
    while IFS= read -r r || [ -n "$r" ]; do
        n=$((n + 1))
        [ -n "$r" ] || continue
        [[ "$r" =~ $ROW_RE ]] || { echo "rows file line $n is not a whole row: $SUMMARY_FROM" >&2; exit 2; }
        case "$r" in
            section$'\t(roadmap not found: '* | section$'\t(roadmap not readable: '*)
                not_read="${r#section$'\t'}"; not_read="${not_read%%$'\t'*}" ;;
        esac
        ROWS+=("$r")
    done < "$SUMMARY_FROM"
    [ "${#ROWS[@]}" -gt 0 ] || { echo "rows file has no rows: $SUMMARY_FROM" >&2; exit 2; }
    [ -z "$not_read" ] || { echo "the roadmap was not read $not_read; nothing to count" >&2; exit 3; }
    summarize
    exit 0
fi

[ -n "$ROOT" ] || ROOT="$SCRIPT_DIR/../.."
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "root not found" >&2; exit 2; }
[ -n "$ROADMAP" ] || ROADMAP="$ROOT/docs/roadmap.md"
TODAY="$(date +%Y-%m-%d)"

TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN=gtimeout
fi

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# A relative path inside the root: no leading /, no `..` anywhere.
safe_rel() {
    [ -n "$1" ] && [[ "$1" != /* ]] && [[ "$1" != *..* ]]
}

# in_root <relpath>: sets RESOLVED to <root>/<relpath> with every symlink on
# the way resolved. Returns 0 when that is inside the root (a dangling final
# link included; it then does not exist), 1 when it leaves the root, 2 when
# the parent directory does not exist (nothing to look at), 3 when it cannot
# be told: a directory on the way that cannot be entered, or a link that
# could not be resolved.
in_root() {
    local p="$ROOT/$1" dir
    RESOLVED=""
    dir="$(cd -P -- "$(dirname -- "$p")" 2>/dev/null && pwd -P)" || { why_no_parent "$1"; return; }
    case "$dir" in "$ROOT"|"$ROOT"/*) ;; *) return 1 ;; esac
    RESOLVED="$dir/$(basename -- "$p")"
    if [ -L "$RESOLVED" ] && [ -e "$RESOLVED" ]; then
        command -v realpath >/dev/null 2>&1 || return 3
        RESOLVED="$(realpath -- "$RESOLVED" 2>/dev/null)" || return 3
        case "$RESOLVED" in "$ROOT"|"$ROOT"/*) ;; *) return 1 ;; esac
    fi
    # dirname and basename drop a trailing slash; put it back so the path
    # is tested as written: `f.txt/` names a directory, and a regular file
    # there does not exist.
    [[ "$1" != */ ]] || RESOLVED="$RESOLVED/"
    return 0
}

# why_no_parent <relpath>: the parent of <relpath> could not be entered.
# Walks down from the root: a component that is missing or not a directory
# means the path does not exist (2); a directory that cannot be entered
# means it cannot be told (3), since what is under it cannot be seen.
why_no_parent() {
    local cur="$ROOT" comp comps
    IFS=/ read -ra comps <<< "$(dirname -- "$1")"
    for comp in "${comps[@]}"; do
        [ -n "$comp" ] && [ "$comp" != . ] || continue
        cur="$cur/$comp"
        if [ -d "$cur" ]; then
            [ -x "$cur" ] || return 3
        else
            return 2
        fi
    done
    return 3
}

# check_path <relpath>: echoes nothing and returns 0 when the path is usable
# (RESOLVED set); otherwise echoes the result word for the check and
# returns 1.
check_path() {
    local rc=0
    safe_rel "$1" || { echo unchecked; return 1; }
    in_root "$1" || rc=$?
    case "$rc" in
        0) return 0 ;;
        1) echo unchecked ;;
        2) echo false ;;
        *) echo unknown ;;
    esac
    return 1
}

# Interruption. Each cell's checks run in a process substitution that the
# main loop reads with `read`, which a trapped signal interrupts at once
# (a foreground wait would hold the trap until the check ended, and
# `timeout` runs the check in its own process group, out of reach of a
# Ctrl-C). On INT or TERM the trap stops that reader, kills everything
# under it (the subshells, `timeout`, the check and its children, found
# with `pgrep -P`), then dies of the same signal: no rows, exit 128 + the
# signal. Without pgrep only the reader is killed and the check runs on
# until its timeout. A run started with INT ignored cannot trap it.
CHILD=""
kill_tree() {  # <pid>: stop it so it forks no more, kill what is under it, then it
    local c
    kill -STOP "$1" 2>/dev/null || return 0
    if command -v pgrep >/dev/null 2>&1; then
        for c in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$c"; done
    fi
    kill -KILL "$1" 2>/dev/null
}
on_signal() {  # <INT|TERM>
    trap '' INT TERM
    [ -z "$CHILD" ] || kill_tree "$CHILD"
    trap - INT TERM
    kill -s "$1" "$$"
}
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM

# run_bounded <cmd...>: runs under the timeout, stdin from /dev/null;
# returns its exit code, or 125 when there is no timeout command.
run_bounded() {
    [ -n "$TIMEOUT_BIN" ] || return 125
    "$TIMEOUT_BIN" -k "$KILL_AFTER" "$TIMEOUT_SECS" "$@" </dev/null
}

exit_to_result() {
    case "$1" in
        0) echo true ;;
        1) echo false ;;
        *) echo unknown ;;
    esac
}

check_gh_issue() {  # <ref> <state>
    local ref="$1" want="${2,,}" slug n url out rc=0
    [[ "$want" == open || "$want" == closed ]] || { echo unchecked; return; }
    if [[ "$ref" =~ ^[0-9]+$ ]]; then
        n="$ref"
        url="$(git -C "$ROOT" remote get-url origin 2>/dev/null)" || { echo unknown; return; }
        slug="$(extract_gh_slug "$url")"
        [ -n "$slug" ] || { echo unknown; return; }
    elif [[ "$ref" =~ ^([A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.][A-Za-z0-9_.-]*)#([0-9]+)$ ]]; then
        slug="${BASH_REMATCH[1]}"
        n="${BASH_REMATCH[2]}"
    else
        echo unchecked; return
    fi
    command -v gh >/dev/null 2>&1 || { echo unknown; return; }
    out="$(run_bounded gh -R "$slug" issue view "$n" --json state --jq .state 2>/dev/null)" || rc=$?
    [ "$rc" -eq 0 ] || { echo unknown; return; }
    out="$(trim "${out,,}")"
    if [ "$out" = "$want" ]; then
        echo true
    elif [[ "$out" == open || "$out" == closed ]]; then
        echo false
    else
        echo unknown
    fi
}

check_script() {  # <words...> (after the `script` kind word)
    local runner_root rc=0 name="${1:-}"
    case "$#:$*" in
        "4:adapter --project "*" validate")
            [[ "$2" == --project && "$4" == validate && "$3" =~ ^[A-Za-z0-9._-]+$ ]] || { echo unchecked; return; }
            ;;
        "2:user_tier_install.sh --check" | "3:user_tier_install.sh --check --require" | "1:check_design_anchors.sh") ;;
        *) echo unchecked; return ;;
    esac
    runner_root="$(cd "$SCRIPTS_DIR/../.." 2>/dev/null && pwd)" || { echo unknown; return; }
    [ -x "$SCRIPTS_DIR/$name" ] || { echo unknown; return; }
    if [ "$name" = adapter ]; then
        # Look the name up first: the adapter exits 1 for an unregistered
        # name or a malformed registry too, which must not read as false.
        [ "$REGISTRY_OK" = true ] || { echo unknown; return; }
        registry_lookup "$runner_root" "$3" >/dev/null 2>&1 || { echo unknown; return; }
    fi
    (cd "$runner_root" && run_bounded "$SCRIPTS_DIR/$name" "${@:2}") >/dev/null 2>&1 </dev/null || rc=$?
    exit_to_result "$rc"
}

check_adr_status() {  # <relpath> <word>
    local path="$1" want="${2,,}" line word rc=0 out
    [[ "$want" =~ ^[a-z]+$ ]] || { echo unchecked; return; }
    check_path "$path" || return
    [ -e "$RESOLVED" ] || { echo false; return; }
    # Fences as in the roadmap reader; CRs dropped first.
    out="$(run_bounded awk '
        { sub(/\r$/, "") }
        {
            l = $0; sub(/^ ? ? ?/, "", l)
            if (match(l, /^(```+|~~~+)/)) {
                run = substr(l, 1, RLENGTH); rest = substr(l, RLENGTH + 1)
                if (!fence) {
                    if (substr(run, 1, 1) != "`" || index(rest, "`") == 0) {
                        fence = substr(run, 1, 1); flen = length(run); next
                    }
                } else {
                    if (substr(run, 1, 1) == fence && length(run) >= flen && rest ~ /^[ \t]*$/) fence = ""
                    next
                }
            }
            if (fence) next
        }
        f && NF { print; found = 1; exit }
        /^##[[:space:]]+Status[[:space:]]*$/ { f = 1 }
        END { if (!found) exit 3 }' "$RESOLVED" 2>/dev/null)" || rc=$?
    [ "$rc" -eq 0 ] || { echo unknown; return; }
    line="$(trim "$out")"
    line="${line#"${line%%[!*_]*}"}"
    [[ "$line" =~ ^([A-Za-z]+) ]] || { echo unknown; return; }
    word="${BASH_REMATCH[1],,}"
    if [ "$word" = "$want" ]; then echo true; else echo false; fi
}

check_one() {  # <single check text>
    local c="$1" words kind path rest rc=0
    c="$(trim "$c")"
    if [[ "$c" == \`*\` ]] && [ "${#c}" -ge 2 ]; then
        c="${c:1:${#c}-2}"
        c="$(trim "$c")"
    fi
    [ -n "$c" ] || { echo unchecked; return; }
    read -ra words <<< "$c"
    kind="${words[0]}"
    case "$kind" in
        file-exists)
            [ "${#words[@]}" -eq 2 ] || { echo unchecked; return; }
            check_path "${words[1]}" || return
            if [ -e "$RESOLVED" ]; then echo true; else echo false; fi
            ;;
        file-contains)
            [[ "$c" =~ ^file-contains[[:space:]]+([^[:space:]]+)[[:space:]]+(.*[^[:space:]])$ ]] || { echo unchecked; return; }
            path="${BASH_REMATCH[1]}"
            rest="${BASH_REMATCH[2]}"
            check_path "$path" || return
            [ -e "$RESOLVED" ] || { echo false; return; }
            run_bounded grep -qF -- "$rest" "$RESOLVED" 2>/dev/null || rc=$?
            exit_to_result "$rc"
            ;;
        adr-status)
            [ "${#words[@]}" -eq 3 ] || { echo unchecked; return; }
            check_adr_status "${words[1]}" "${words[2]}"
            ;;
        gh-issue)
            [ "${#words[@]}" -eq 3 ] || { echo unchecked; return; }
            check_gh_issue "${words[1]}" "${words[2]}"
            ;;
        script)
            [ "${#words[@]}" -ge 2 ] || { echo unchecked; return; }
            check_script "${words[@]:1}"
            ;;
        *) echo unchecked ;;
    esac
}

combine() {  # <results...>
    local r n=0 t=0 f=0 u=0 c=0
    for r in "$@"; do
        n=$((n + 1))
        case "$r" in
            true) t=$((t + 1)) ;;
            false) f=$((f + 1)) ;;
            unknown) u=$((u + 1)) ;;
            *) c=$((c + 1)) ;;
        esac
    done
    if [ "$u" -gt 0 ]; then echo unknown
    elif [ "$c" -eq "$n" ]; then echo unchecked
    elif [ "$c" -gt 0 ]; then echo partial
    elif [ "$t" -eq "$n" ]; then echo true
    elif [ "$f" -eq "$n" ]; then echo false
    else echo partial
    fi
}

check_cell() {  # <cell text>
    local cell part results=() rest
    # A whole cell in one pair of backticks is unwrapped before the split.
    cell="$(trim "$1")"
    if [[ "$cell" =~ ^\`([^\`]*)\`$ ]]; then
        cell="${BASH_REMATCH[1]}"
    fi
    rest="$cell"
    while :; do
        if [[ "$rest" == *" ; "* ]]; then
            part="${rest%%" ; "*}"
            rest="${rest#*" ; "}"
        else
            part="$rest"
            rest=""
        fi
        results+=("$(check_one "$part")")
        [ -n "$rest" ] || break
    done
    combine "${results[@]}"
}

emit() {  # <kind> <item> <result> <check>
    local item="${2//$'\t'/ }" check="${4//$'\t'/ }"
    [ -n "$check" ] || check="none"
    ROWS+=("$1"$'\t'"$item"$'\t'"$3"$'\t'"$check"$'\t'"$TODAY")
}

# split_row <line>: sets CELLS to the trimmed cells of a table row, split
# on unescaped pipes as GFM does; `\|` becomes a literal `|` in its cell.
split_row() {
    local s i ch cur="" ended=false parts=()
    s="$(trim "$1")"
    for ((i = 0; i < ${#s}; i++)); do
        ch="${s:i:1}"
        if [ "$ch" = '\' ] && [ "${s:i+1:1}" = '|' ]; then
            cur+='|'; i=$((i + 1)); ended=false
        elif [ "$ch" = '|' ]; then
            parts+=("$cur"); cur=""; ended=true
        else
            cur+="$ch"; ended=false
        fi
    done
    [ "$ended" = true ] || parts+=("$cur")
    # A leading pipe leaves an empty first piece.
    [[ "$s" == '|'* ]] && parts=("${parts[@]:1}")
    CELLS=()
    for cur in "${parts[@]}"; do
        CELLS+=("$(trim "$cur")")
    done
}

in_section=false
seen_section=false
seen_table=false
in_fence=false
fence_char=""
fence_len=0
table=none      # none | line | deferral | other
prev_table_line=false
after_header=false   # the last table line was a header (the delimiter row is next)
prev_para=false # the line before was paragraph text (a setext underline may follow)
START_RE='^ {0,3}##[[:space:]]+Direction([[:space:]]+#+)?[[:space:]]*$'
END_RE='^ {0,3}##?([[:space:]]|$)'
SETEXT_RE='^ {0,3}(=+|-+)[[:space:]]*$'
NOT_PARA_RE='^[[:space:]]*$|^ {0,3}(#|>|[-*+]([[:space:]]|$)|[0-9]+[.)]([[:space:]]|$))'
THEMATIC_RE='^ {0,3}([*_][[:space:]]*){3,}$'
FENCE_RE='^ {0,3}(`{3,}|~{3,})(.*)$'
# found | missing | unreadable. A file that exists but cannot be opened (no
# read permission, a directory) is not read as a roadmap without the
# section: that would be a false "no Direction section".
ROADMAP_STATE=found
if [ ! -e "$ROADMAP" ]; then
    # Missing, unless the nearest directory above it that can be seen
    # cannot be entered: then what is under it cannot be told.
    ROADMAP_STATE=missing
    d="$(dirname -- "$ROADMAP")"
    while [ ! -e "$d" ] && [ "$d" != / ] && [ "$d" != . ]; do d="$(dirname -- "$d")"; done
    if [ -d "$d" ] && [ ! -x "$d" ]; then ROADMAP_STATE=unreadable; fi
elif [ ! -f "$ROADMAP" ] || ! { : < "$ROADMAP"; } 2>/dev/null; then
    ROADMAP_STATE=unreadable
fi
if [ "$ROADMAP_STATE" = found ]; then
    while IFS= read -r raw || [ -n "$raw" ]; do
        raw="${raw%$'\r'}"
        # Fences are tracked from the top of the file, so a fenced example
        # of the section is never taken for it.
        # A backtick opener with a backtick after it is inline code, not a
        # fence (CommonMark); inside a fence such a line closes nothing.
        if [[ "$raw" =~ $FENCE_RE ]] && { [ "$in_fence" = true ] \
            || [ "${BASH_REMATCH[1]:0:1}" = '~' ] || [[ "${BASH_REMATCH[2]}" != *'`'* ]]; }; then
            run="${BASH_REMATCH[1]}"
            if [ "$in_fence" = false ]; then
                in_fence=true; fence_char="${run:0:1}"; fence_len="${#run}"
            elif [ "${run:0:1}" = "$fence_char" ] && [ "${#run}" -ge "$fence_len" ] \
                && [ -z "$(trim "${BASH_REMATCH[2]}")" ]; then
                in_fence=false
            fi
            prev_table_line=false; table=none; prev_para=false
            continue
        fi
        [ "$in_fence" = true ] && continue
        if [ "$in_section" = false ]; then
            if [[ "$raw" =~ $START_RE ]]; then
                in_section=true
                seen_section=true
            fi
            continue
        fi
        # A level-1 or level-2 heading ends the section: ATX (`#`, `##`,
        # up to 3 spaces of indent) or setext (a `===` or `---` line under
        # paragraph text).
        if [[ "$raw" =~ $END_RE ]] || { [ "$prev_para" = true ] && [[ "$raw" =~ $SETEXT_RE ]]; }; then
            break
        fi
        if [[ "$raw" =~ ^[[:space:]]*\| ]]; then
            prev_para=false
            if [ "$prev_table_line" = false ]; then
                split_row "$raw"
                table=other
                if [ "${#CELLS[@]}" -eq 2 ]; then
                    case "${CELLS[0],,}|${CELLS[1],,}" in
                        "line|check") table=line; seen_table=true ;;
                        "deferral|revisit check") table=deferral; seen_table=true ;;
                    esac
                fi
                prev_table_line=true
                after_header=true
                continue
            fi
            prev_table_line=true
            [ "$table" = line ] || [ "$table" = deferral ] || { after_header=false; continue; }
            # The delimiter row is the one right under the header. Further
            # down, a row of only empty cells, dashes and colons is a data
            # row with nothing in it: shown as a format problem, not dropped.
            if [[ "$raw" =~ ^[[:space:]|:-]+$ ]]; then
                if [ "$after_header" = true ]; then
                    after_header=false
                else
                    emit format "(empty row in the ${table^} table: $(trim "$raw"))" unchecked ""
                fi
                continue
            fi
            after_header=false
            split_row "$raw"
            item="${CELLS[0]:-}"
            cell="${CELLS[1]:-}"
            if [ "${#CELLS[@]}" -gt 2 ]; then
                # Extra cells are shown, never dropped.
                extra="${CELLS[1]}"
                for x in "${CELLS[@]:2}"; do extra+=" | $x"; done
                emit "$table" "$item" unchecked "(${#CELLS[@]} cells) $extra"
                continue
            fi
            if [ -z "$(trim "$cell")" ]; then
                emit "$table" "$item" unchecked ""
            else
                # Read through a pipe, not $(...), so a signal is handled
                # while the check runs (see Interruption above).
                exec 4< <(check_cell "$cell")
                CHILD=$!
                result=""
                IFS= read -r result <&4 || true
                exec 4<&-
                CHILD=""
                emit "$table" "$item" "${result:-unknown}" "$cell"
            fi
            continue
        fi
        prev_table_line=false
        table=none
        # A thematic break (`---`, `***`) is not paragraph text either.
        if [[ "$raw" =~ $NOT_PARA_RE ]] || [[ "$raw" =~ $SETEXT_RE ]] || [[ "$raw" =~ $THEMATIC_RE ]]; then
            prev_para=false
        else
            prev_para=true
        fi
        if [[ "$raw" =~ ^[[:space:]]*[-*+][[:space:]]+\[[[:space:]xX]\][[:space:]]*(.*)$ ]]; then
            emit format "${BASH_REMATCH[1]}" unchecked ""
        fi
    done < "$ROADMAP"
fi

if [ "$ROADMAP_STATE" = missing ]; then
    emit section "(roadmap not found: $ROADMAP)" unchecked ""
elif [ "$ROADMAP_STATE" = unreadable ]; then
    emit section "(roadmap not readable: $ROADMAP)" unknown ""
elif [ "$seen_section" = false ]; then
    emit section "(no Direction section)" unchecked ""
elif [ "$seen_table" = false ]; then
    emit section "(no Line or Deferral table)" unchecked ""
elif [ "${#ROWS[@]}" -eq 0 ]; then
    emit section "(no rows in the Line or Deferral tables)" unchecked ""
fi

if [ "$SUMMARY" = true ]; then
    if [ "$ROADMAP_STATE" != found ]; then
        item="${ROWS[0]#*$'\t'}"
        echo "the roadmap was not read ${item%%$'\t'*}; nothing to count" >&2
        exit 3
    fi
    summarize || exit 1
else
    printf '%s\n' "${ROWS[@]}" || exit 1
fi
exit 0
