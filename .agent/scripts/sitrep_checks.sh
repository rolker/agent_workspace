#!/usr/bin/env bash
# .agent/scripts/sitrep_checks.sh
# Run the checks named in a roadmap's `## Direction` section and print one
# row per line (issue #386). Read-only. The sit-rep skill formats this
# output; it decides nothing itself.
#
# Usage: sitrep_checks.sh [--root <dir>] [--roadmap <file>] [--summary]
#   --root     the roadmap's repository root (default: this script's own
#              checkout). Relative paths in checks resolve against it, and
#              gh-issue takes its repo from its `origin` remote.
#   --roadmap  default <root>/docs/roadmap.md
#   --summary  print one line instead of rows:
#                lines <true>/<total> deferrals <true>/<total>
#              (a deferral whose check is true is due). The sit-rep stores
#              this line in its run record.
#
# What is read: only the `## Direction` section (up to the next `## `
# heading), outside fenced code. Tables are picked by header:
#   | Line | Check |               -> rows of kind `line`
#   | Deferral | Revisit check |   -> rows of kind `deferral`
# Any other table in the section is ignored. A checklist item (`- [ ]`,
# `- [x]`) in the section prints a `format` row, `unchecked`, so the misuse
# is visible (update_roadmap.sh would tick it on merge).
#
# Output: one TAB-separated row per item:
#   <kind>  <item>  <result>  <check>  <date>
# <check> is the cell text, or `none` when the cell is empty. With no
# Direction section there is one row: section, (no Direction section),
# unchecked, none, date. Exit 0 whenever rows were printed; 2 on usage.
#
# Check grammar (a cell may join several checks with ` ; `; a check may be
# wrapped in backticks). Each check is split into words with `read -ra`
# under `set -f`: nothing is globbed, nothing is eval'd.
#   file-exists <relpath>
#   file-contains <relpath> <fixed string>   (the rest of the check;
#                                              grep -qF; a missing file is
#                                              false)
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
# Anything else is `unchecked`: an absolute path or one containing `..`, an
# unknown kind, any other script form, malformed gh-issue arguments, a bare
# `#N`, an empty cell.
#
# Results: true (exit 0) / false (exit 1) / unknown (could not run: gh or
# the script missing or failing, an exit above 1, grep error, timeout, no
# timeout command, an unregistered adapter name, a malformed registry) /
# unchecked (no check) / partial (a mixed cell). Several checks combine:
# any unknown -> unknown; else all unchecked -> unchecked; else any
# unchecked -> partial; else all true -> true, all false -> false, mixed ->
# partial. The five words are a trial.
#
# External calls run under `timeout` ($SITREP_TIMEOUT seconds, default 60).
#
# ADR-0010 departure: gh-issue reads the state with `gh -R <repo> issue
# view` directly, not issue_lookup. A git-bug cache hit is not refreshed, so
# it is not "checked this run"; a gh failure gives `unknown`, never a stale
# answer.

set -uo pipefail
set -f

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SITREP_SCRIPTS_DIR:-$SCRIPT_DIR}"
TIMEOUT_SECS="${SITREP_TIMEOUT:-60}"

# shellcheck source=_issue_helpers.sh
source "$SCRIPT_DIR/_issue_helpers.sh"
REGISTRY_OK=true
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh" 2>/dev/null || REGISTRY_OK=false

usage() {
    echo "usage: sitrep_checks.sh [--root <dir>] [--roadmap <file>] [--summary]" >&2
    exit 2
}

ROOT=""
ROADMAP=""
SUMMARY=false
while [ $# -gt 0 ]; do
    case "$1" in
        --root) [ $# -ge 2 ] || usage; ROOT="$2"; shift 2 ;;
        --roadmap) [ $# -ge 2 ] || usage; ROADMAP="$2"; shift 2 ;;
        --summary) SUMMARY=true; shift ;;
        -h|--help) usage ;;
        *) echo "unknown argument: $1" >&2; usage ;;
    esac
done
[ -n "$ROOT" ] || ROOT="$SCRIPT_DIR/../.."
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || { echo "root not found" >&2; exit 2; }
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

# run_bounded <cmd...>: runs under the timeout; returns its exit code, or
# 125 when there is no timeout command.
run_bounded() {
    [ -n "$TIMEOUT_BIN" ] || return 125
    "$TIMEOUT_BIN" "$TIMEOUT_SECS" "$@"
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
    elif [[ "$ref" =~ ^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#([0-9]+)$ ]]; then
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
            [ "${#words[@]}" -eq 2 ] && safe_rel "${words[1]}" || { echo unchecked; return; }
            if [ -e "$ROOT/${words[1]}" ]; then echo true; else echo false; fi
            ;;
        file-contains)
            [[ "$c" =~ ^file-contains[[:space:]]+([^[:space:]]+)[[:space:]]+(.*[^[:space:]])$ ]] || { echo unchecked; return; }
            path="${BASH_REMATCH[1]}"
            rest="${BASH_REMATCH[2]}"
            safe_rel "$path" || { echo unchecked; return; }
            [ -e "$ROOT/$path" ] || { echo false; return; }
            run_bounded grep -qF -- "$rest" "$ROOT/$path" 2>/dev/null || rc=$?
            exit_to_result "$rc"
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
    local cell="$1" part results=() rest
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

ROWS=()
emit() {  # <kind> <item> <result> <check>
    local item="${2//$'\t'/ }" check="${4//$'\t'/ }"
    [ -n "$check" ] || check="none"
    ROWS+=("$1"$'\t'"$item"$'\t'"$3"$'\t'"$check"$'\t'"$TODAY")
}

# split_row <line>: sets CELLS to the trimmed cells of a table row.
split_row() {
    local inner="$1" cell
    inner="$(trim "$inner")"
    inner="${inner#|}"
    inner="${inner%|}"
    CELLS=()
    IFS='|' read -ra _parts <<< "$inner"
    for cell in "${_parts[@]}"; do
        CELLS+=("$(trim "$cell")")
    done
}

in_section=false
seen_section=false
in_fence=false
fence_char=""
table=none      # none | line | deferral | other
prev_table_line=false
FENCE_RE='^ {0,3}(```|~~~)'
if [ -f "$ROADMAP" ]; then
    while IFS= read -r raw || [ -n "$raw" ]; do
        raw="${raw%$'\r'}"
        if [ "$in_section" = false ]; then
            if [[ "$raw" =~ ^##[[:space:]]+Direction[[:space:]]*$ ]]; then
                in_section=true
                seen_section=true
            fi
            continue
        fi
        # Fences (``` or ~~~, up to 3 spaces of indent).
        if [[ "$raw" =~ $FENCE_RE ]]; then
            ch="${BASH_REMATCH[1]:0:1}"
            if [ "$in_fence" = false ]; then
                in_fence=true; fence_char="$ch"
            elif [ "$ch" = "$fence_char" ]; then
                in_fence=false
            fi
            prev_table_line=false; table=none
            continue
        fi
        [ "$in_fence" = true ] && continue
        if [[ "$raw" =~ ^##?[[:space:]] ]]; then
            break
        fi
        if [[ "$raw" =~ ^[[:space:]]*\| ]]; then
            if [ "$prev_table_line" = false ]; then
                split_row "$raw"
                table=other
                if [ "${#CELLS[@]}" -eq 2 ]; then
                    case "${CELLS[0],,}|${CELLS[1],,}" in
                        "line|check") table=line ;;
                        "deferral|revisit check") table=deferral ;;
                    esac
                fi
                prev_table_line=true
                continue
            fi
            prev_table_line=true
            [ "$table" = line ] || [ "$table" = deferral ] || continue
            # Separator row.
            [[ "$raw" =~ ^[[:space:]|:-]+$ ]] && continue
            split_row "$raw"
            item="${CELLS[0]:-}"
            cell="${CELLS[1]:-}"
            if [ -z "$(trim "$cell")" ]; then
                emit "$table" "$item" unchecked ""
            else
                emit "$table" "$item" "$(check_cell "$cell")" "$cell"
            fi
            continue
        fi
        prev_table_line=false
        table=none
        if [[ "$raw" =~ ^[[:space:]]*[-*+][[:space:]]+\[[[:space:]xX]\][[:space:]]*(.*)$ ]]; then
            emit format "${BASH_REMATCH[1]}" unchecked ""
        fi
    done < "$ROADMAP"
fi

if [ "$seen_section" = false ]; then
    emit section "(no Direction section)" unchecked ""
fi

if [ "$SUMMARY" = true ]; then
    lt=0 ln=0 dt=0 dn=0
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
else
    printf '%s\n' "${ROWS[@]}"
fi
exit 0
