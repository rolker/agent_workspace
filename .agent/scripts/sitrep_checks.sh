#!/usr/bin/env bash
# .agent/scripts/sitrep_checks.sh
# Run the checks named in a roadmap's `## Direction` section and print one
# row per line (issue #386). Read-only. The sit-rep skill formats this
# output; it decides nothing itself.
#
# Usage: sitrep_checks.sh [--root <dir>] [--roadmap <file>] [--summary] [--no-follow]
#        sitrep_checks.sh --summary-from <rows-file>
#        sitrep_checks.sh --next-steps-from <rows-file>
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
#              3 the same way. Only `line` and `deferral` rows count: a
#              part's rows (below) never enter the root's totals.
#   --no-follow
#              read the root's roadmap only: no `Sub-roadmap | Root` table
#              is followed and no `part` row is printed. The pointer table
#              is then ignored like any other table, so a section that
#              holds only pointers gives the `(no Line or Deferral table)`
#              section row. `--summary` never follows (it counts the
#              root's rows only).
#   --next-steps-from <rows-file>
#              the next step of the root and of each part, from rows saved
#              by an earlier run (no roadmap is read, no check runs, so it
#              agrees with the rows shown). One TAB-separated line each:
#                (root)<TAB><item><TAB><result>   the first `line` row
#                                                 whose result is not true
#                (root)<TAB>none open             when every one is true
#              then, for each `part` row whose result is `true` (a followed
#              sub-roadmap), in order, the same with the sub-roadmap path
#              in place of `(root)`, from that part's `subline` rows (item
#              without the path prefix). Parts that were not followed have
#              no line here; their `part` row says why. Same exits as
#              `--summary-from` (2 for a rows file it cannot use, 3 when the
#              root's roadmap was not read).
#
# Sub-roadmaps (issue #488, ADR-0022). A part of the root may carry its own
# roadmap. The root's Direction section points at it with a third table:
#   | Sub-roadmap | Root |
#   | `tools/ros-manifest/docs/roadmap.md` | `tools/ros-manifest` |
#   | `docs/manifest/roadmap.md` | . |
# Cell 1 is the sub-roadmap file, cell 2 the directory its checks' paths
# are relative to (what --root gets for it); both are relative to this
# root, backticks optional, and an empty Root cell is `.`. Each valid
# pointer is followed one level: the sub-roadmap's Direction section is
# read with the same rules, under --root <root>/<Root>, and its rows are
# printed after the root's. One level is what this checker follows, not a
# limit of the rule (ADR-0022 puts none on levels of planning and design).
# A sub-roadmap's own Paths paragraphs are not read here (they are prose).
# Row kinds for parts:
#   part         one per pointer row; item = the Sub-roadmap cell as
#                written (unwrapped), check = what happened. Results:
#                  true          followed (check `read`)
#                  unknown       the target exists but cannot be read,
#                                or a directory on the way cannot be
#                                entered
#                  unchecked     a broken pointer, never fatal to the
#                                root's rows: an empty cell, extra cells,
#                                an absolute or `..` path, a path or
#                                Root outside the root, a missing target
#                                or Root, a file outside its Root, a
#                                target or Root in another git repository
#                                (a nested repository or a submodule,
#                                ADR-0022: not supported), the
#                                root's own roadmap, a sub-roadmap
#                                already followed (a cycle or a repeat),
#                                or a sub-roadmap with nothing to check
#                                (no Direction section, no Line or
#                                Deferral table, no rows; a nested
#                                pointer table is not a Line or Deferral
#                                table, so a sub-roadmap holding only
#                                one is unchecked too)
#                  not-followed  a pointer table inside a sub-roadmap
#                                (check `nested pointer`); item is
#                                `<sub-roadmap>: <cell 1>`. Not a
#                                problem: the checker follows one level.
#   subline, subdeferral, subformat
#                the sub-roadmap's `line`, `deferral` and `format` rows;
#                item = `<sub-roadmap>: <item>`, so a report names a
#                part's lines by the part's path.
# A bare `gh-issue N` in a sub-roadmap takes its repository from the
# Root's `origin`, as --root does for the root.
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
#   | Sub-roadmap | Root |         -> pointers (see Sub-roadmaps above)
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
# Deferral table)` for a section that has none of the three tables (an
# empty section included), or `(no rows in the Line or Deferral tables)`
# for tables with a header and nothing under it (a followed pointer row
# counts as a row: a root whose section only points at parts has no section
# row, except under --no-follow). A roadmap that exists but cannot be read
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
    echo "usage: sitrep_checks.sh [--root <dir>] [--roadmap <file>] [--summary] [--no-follow]" >&2
    echo "       sitrep_checks.sh --summary-from <rows-file>" >&2
    echo "       sitrep_checks.sh --next-steps-from <rows-file>" >&2
    exit 2
}

ROOT=""
ROADMAP=""
SUMMARY=false
SUMMARY_FROM=""
NEXT_FROM=false
FOLLOW=true
while [ $# -gt 0 ]; do
    case "$1" in
        --root) [ $# -ge 2 ] || usage; ROOT="$2"; shift 2 ;;
        --roadmap) [ $# -ge 2 ] || usage; ROADMAP="$2"; shift 2 ;;
        --summary) SUMMARY=true; shift ;;
        --no-follow) FOLLOW=false; shift ;;
        --summary-from|--next-steps-from)
            [ $# -ge 2 ] || usage
            [ -z "$SUMMARY_FROM" ] || usage
            [ -n "$2" ] || { echo "$1 needs a rows file; got an empty argument" >&2; exit 2; }
            [ "$1" = --summary-from ] || NEXT_FROM=true
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

# fields <row>: sets F_K, F_I, F_R to its kind, item and result (an item
# may be empty, so the row is not split with read, which joins TABs).
fields() {
    local r="$1"
    F_K="${r%%$'\t'*}"; r="${r#*$'\t'}"
    F_I="${r%%$'\t'*}"; r="${r#*$'\t'}"
    F_R="${r%%$'\t'*}"
}

# next_steps: the --next-steps-from lines for the rows in ROWS.
next_steps() {
    local r p first="" fres="" found
    local -a parts=()
    for r in "${ROWS[@]}"; do
        fields "$r"
        # fres, not the item, marks "chosen": an item (the Line cell) may be
        # empty, and a result never is.
        if [ "$F_K" = line ] && [ "$F_R" != true ] && [ -z "$fres" ]; then
            first="$F_I"; fres="$F_R"
        fi
        [ "$F_K" = part ] && [ "$F_R" = true ] && parts+=("$F_I")
    done
    if [ -n "$fres" ]; then
        printf '(root)\t%s\t%s\n' "$first" "$fres"
    else
        printf '(root)\tnone open\n'
    fi
    for p in ${parts[@]+"${parts[@]}"}; do
        found=false
        for r in "${ROWS[@]}"; do
            fields "$r"
            [ "$F_K" = subline ] && [[ "$F_I" == "$p: "* ]] && [ "$F_R" != true ] || continue
            printf '%s\t%s\t%s\n' "$p" "${F_I#"$p: "}" "$F_R"
            found=true
            break
        done
        [ "$found" = true ] || printf '%s\tnone open\n' "$p"
    done
}

ROWS=()
if [ -n "$SUMMARY_FROM" ]; then
    [ -f "$SUMMARY_FROM" ] && [ -r "$SUMMARY_FROM" ] || { echo "rows file not readable: $SUMMARY_FROM" >&2; exit 2; }
    ROW_RE=$'^(line|deferral|format|section|part|subline|subdeferral|subformat)\t[^\t]*\t(true|false|unknown|unchecked|partial|not-followed)\t[^\t]+\t[0-9]{4}-[0-9]{2}-[0-9]{2}$'
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
    if [ "$NEXT_FROM" = true ]; then next_steps; else summarize; fi
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

START_RE='^ {0,3}##[[:space:]]+Direction([[:space:]]+#+)?[[:space:]]*$'
END_RE='^ {0,3}##?([[:space:]]|$)'
SETEXT_RE='^ {0,3}(=+|-+)[[:space:]]*$'
NOT_PARA_RE='^[[:space:]]*$|^ {0,3}(#|>|[-*+]([[:space:]]|$)|[0-9]+[.)]([[:space:]]|$))'
THEMATIC_RE='^ {0,3}([*_][[:space:]]*){3,}$'
FENCE_RE='^ {0,3}(`{3,}|~{3,})(.*)$'

# roadmap_state <file>: found | missing | unreadable. A file that exists but
# cannot be opened (no read permission, a directory) is not read as a
# roadmap without the section: that would be a false "no Direction section".
roadmap_state() {
    local f="$1" d
    if [ ! -e "$f" ]; then
        # Missing, unless the nearest directory above it that can be seen
        # cannot be entered: then what is under it cannot be told.
        d="$(dirname -- "$f")"
        while [ ! -e "$d" ] && [ "$d" != / ] && [ "$d" != . ]; do d="$(dirname -- "$d")"; done
        if [ -d "$d" ] && [ ! -x "$d" ]; then echo unreadable; else echo missing; fi
    elif [ ! -f "$f" ] || ! { : < "$f"; } 2>/dev/null; then
        echo unreadable
    else
        echo found
    fi
}

# unwrap <cell>: the cell trimmed, one pair of enclosing backticks dropped.
unwrap() {
    local c
    c="$(trim "$1")"
    if [[ "$c" =~ ^\`([^\`]*)\`$ ]]; then c="$(trim "${BASH_REMATCH[1]}")"; fi
    printf '%s' "$c"
}

# scan_roadmap <file> <part>: read the Direction section of <file> and emit
# its rows. <part> is empty for the root's roadmap; for a sub-roadmap it is
# the pointer's path, which prefixes every item and turns the kinds into
# subline/subdeferral/subformat. Pointer rows of the root are collected in
# POINTERS (one "<cell 1>\t<cell 2>\t<cell count>" each, unless --no-follow);
# in a sub-roadmap they print `part` rows, `not-followed` (one level). Sets
# SCAN_SECTION and SCAN_TABLE (true|false) and SCAN_ROWS: the line,
# deferral and format rows emitted, plus the root's pointer rows when they
# are followed. A nested pointer, or a pointer under --no-follow, is not
# content: a sub-roadmap whose only table points further is "no Line or
# Deferral table", never a part read with nothing open.
scan_roadmap() {
    local file="$1" part="$2" kpre="" ipre="" raw run item cell extra x result
    local in_section=false in_fence=false fence_char="" fence_len=0
    local table=none      # none | line | deferral | pointer | other
    local prev_table_line=false
    local after_header=false   # the last table line was a header (the delimiter row is next)
    local prev_para=false # the line before was paragraph text (a setext underline may follow)
    local start_rows="${#ROWS[@]}" pointers=0 nested=0
    if [ -n "$part" ]; then kpre=sub; ipre="$part: "; fi
    SCAN_SECTION=false
    SCAN_TABLE=false
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
                SCAN_SECTION=true
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
                        "line|check") table=line; SCAN_TABLE=true ;;
                        "deferral|revisit check") table=deferral; SCAN_TABLE=true ;;
                        # A pointer table makes the section something to
                        # read only where it is followed: in the root's
                        # roadmap without --no-follow. Under --no-follow it
                        # is ignored, and in a sub-roadmap it is a nested
                        # pointer, listed but not content (issue #488).
                        "sub-roadmap|root")
                            table=pointer
                            [ -n "$part" ] || [ "$FOLLOW" = false ] || SCAN_TABLE=true ;;
                    esac
                fi
                prev_table_line=true
                after_header=true
                continue
            fi
            prev_table_line=true
            [ "$table" = line ] || [ "$table" = deferral ] || [ "$table" = pointer ] \
                || { after_header=false; continue; }
            # The delimiter row is the one right under the header. Further
            # down, a row of only empty cells, dashes and colons is a data
            # row with nothing in it: shown as a format problem, not dropped.
            if [[ "$raw" =~ ^[[:space:]|:-]+$ ]]; then
                if [ "$after_header" = true ]; then
                    after_header=false
                elif [ "$table" = pointer ]; then
                    if [ -n "$part" ]; then
                        nested=$((nested + 1))
                        emit part "$ipre(empty row in the Sub-roadmap table: $(trim "$raw"))" not-followed "nested pointer"
                    elif [ "$FOLLOW" = true ]; then
                        pointers=$((pointers + 1))
                        POINTERS+=($'\t\t2')
                    fi
                else
                    emit "${kpre}format" "$ipre(empty row in the ${table^} table: $(trim "$raw"))" unchecked ""
                fi
                continue
            fi
            after_header=false
            split_row "$raw"
            item="${CELLS[0]:-}"
            cell="${CELLS[1]:-}"
            if [ "$table" = pointer ]; then
                if [ -n "$part" ]; then
                    nested=$((nested + 1))
                    emit part "$ipre$(unwrap "$item")" not-followed "nested pointer"
                elif [ "$FOLLOW" = true ]; then
                    pointers=$((pointers + 1))
                    POINTERS+=("${item//$'\t'/ }"$'\t'"${cell//$'\t'/ }"$'\t'"${#CELLS[@]}")
                fi
                continue
            fi
            if [ "${#CELLS[@]}" -gt 2 ]; then
                # Extra cells are shown, never dropped.
                extra="${CELLS[1]}"
                for x in "${CELLS[@]:2}"; do extra+=" | $x"; done
                emit "$kpre$table" "$ipre$item" unchecked "(${#CELLS[@]} cells) $extra"
                continue
            fi
            if [ -z "$(trim "$cell")" ]; then
                emit "$kpre$table" "$ipre$item" unchecked ""
            else
                # Read through a pipe, not $(...), so a signal is handled
                # while the check runs (see Interruption above).
                exec 4< <(check_cell "$cell")
                CHILD=$!
                result=""
                IFS= read -r result <&4 || true
                exec 4<&-
                CHILD=""
                emit "$kpre$table" "$ipre$item" "${result:-unknown}" "$cell"
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
            emit "${kpre}format" "$ipre${BASH_REMATCH[1]}" unchecked ""
        fi
    done < "$file"
    SCAN_ROWS=$(( ${#ROWS[@]} - start_rows - nested + pointers ))
}

# real_path <absolute path>: the path with its directory resolved, and the
# file itself when it is a link (realpath), as in_root resolves a target.
real_path() {
    local d
    d="$(cd -P -- "$(dirname -- "$1")" 2>/dev/null && pwd -P)" || { printf '%s' "$1"; return; }
    d="$d/$(basename -- "$1")"
    if [ -L "$d" ] && command -v realpath >/dev/null 2>&1; then
        realpath -- "$d" 2>/dev/null || printf '%s' "$d"
    else
        printf '%s' "$d"
    fi
}

# repo_top <dir>: the top of the git repository <dir> is in (symlinks
# resolved), or nothing outside one.
repo_top() {
    local t
    t="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 0
    (cd -P -- "$t" 2>/dev/null && pwd -P)
}

# follow_pointer <cell 1> <cell 2> <cell count>: check one pointer row of the
# root and, when it is valid, read the sub-roadmap with its Root as --root.
# Always emits the `part` row first, then the part's rows.
follow_pointer() {
    local item rdir n="$3" rc=0 target rootdir f idx save_root why=""
    item="$(unwrap "$1")"
    rdir="$(unwrap "$2")"
    [ -n "$rdir" ] || rdir=.
    if [ -z "$item" ]; then
        emit part "(empty Sub-roadmap cell)" unchecked "no sub-roadmap named"; return
    fi
    if [ "$n" -gt 2 ]; then
        emit part "$item" unchecked "($n cells) a pointer row has two cells: Sub-roadmap and Root"; return
    fi
    safe_rel "$item" || { emit part "$item" unchecked "not a path inside the root (absolute, or with ..)"; return; }
    [ "$rdir" = . ] || safe_rel "$rdir" || { emit part "$item" unchecked "Root $rdir is not a path inside the root (absolute, or with ..)"; return; }
    in_root "$item" || rc=$?
    case "$rc" in
        0) ;;
        1) emit part "$item" unchecked "outside the root (through a link)"; return ;;
        2) emit part "$item" unchecked "not found"; return ;;
        *) emit part "$item" unknown "cannot be told: a directory on the way cannot be entered"; return ;;
    esac
    target="${RESOLVED%/}"
    case "$(roadmap_state "$target")" in
        found) ;;
        missing) emit part "$item" unchecked "not found"; return ;;
        *) emit part "$item" unknown "not readable"; return ;;
    esac
    rootdir="$(cd -P -- "$ROOT/$rdir" 2>/dev/null && pwd -P)" || { emit part "$item" unchecked "Root $rdir not found"; return; }
    case "$rootdir" in "$ROOT"|"$ROOT"/*) ;; *) emit part "$item" unchecked "Root $rdir is outside the root"; return ;; esac
    case "$target" in "$rootdir"/*) ;; *) emit part "$item" unchecked "the file is outside its Root $rdir"; return ;; esac
    # A pointer into another repository is not supported (ADR-0022): a
    # target or Root in a nested repository or a submodule would take a
    # bare gh-issue's repository from that repository's origin.
    if [ "$(repo_top "$(dirname -- "$target")")" != "$ROOT_TOP" ] \
        || [ "$(repo_top "$rootdir")" != "$ROOT_TOP" ]; then
        emit part "$item" unchecked "in another repository (a nested repository or a submodule)"; return
    fi
    if [ "$target" = "$ROADMAP_REAL" ]; then
        emit part "$item" unchecked "points at the root's own roadmap"; return
    fi
    for f in ${FOLLOWED[@]+"${FOLLOWED[@]}"}; do
        if [ "$f" = "$target" ]; then
            emit part "$item" unchecked "already followed (a repeated or circular pointer)"; return
        fi
    done
    FOLLOWED+=("$target")
    idx="${#ROWS[@]}"
    emit part "$item" true "read"
    save_root="$ROOT"
    ROOT="$rootdir"
    scan_roadmap "$target" "$item"
    ROOT="$save_root"
    if [ "$SCAN_SECTION" = false ]; then why="no Direction section"
    elif [ "$SCAN_TABLE" = false ]; then why="no Line or Deferral table"
    elif [ "$SCAN_ROWS" -eq 0 ]; then why="no rows in the Line or Deferral tables"
    fi
    if [ -n "$why" ]; then
        ROWS[idx]="part"$'\t'"$item"$'\t'"unchecked"$'\t'"$why"$'\t'"$TODAY"
    fi
}

POINTERS=()
FOLLOWED=()
[ "$SUMMARY" = false ] || FOLLOW=false
ROADMAP_STATE="$(roadmap_state "$ROADMAP")"
if [ "$ROADMAP_STATE" = found ]; then
    scan_roadmap "$ROADMAP" ""
fi

if [ "$ROADMAP_STATE" = missing ]; then
    emit section "(roadmap not found: $ROADMAP)" unchecked ""
elif [ "$ROADMAP_STATE" = unreadable ]; then
    emit section "(roadmap not readable: $ROADMAP)" unknown ""
elif [ "$SCAN_SECTION" = false ]; then
    emit section "(no Direction section)" unchecked ""
elif [ "$SCAN_TABLE" = false ]; then
    emit section "(no Line or Deferral table)" unchecked ""
elif [ "$SCAN_ROWS" -eq 0 ]; then
    emit section "(no rows in the Line or Deferral tables)" unchecked ""
fi

if [ "${#POINTERS[@]}" -gt 0 ]; then
    ROADMAP_REAL="$(real_path "$ROADMAP")"
    ROOT_TOP="$(repo_top "$ROOT")"
    for p in "${POINTERS[@]}"; do
        c1="${p%%$'\t'*}"; p="${p#*$'\t'}"
        follow_pointer "$c1" "${p%%$'\t'*}" "${p#*$'\t'}"
    done
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
