#!/bin/bash
# .agent/scripts/update_roadmap.sh
# Update roadmap files when an issue is completed.
#
# Usage:
#   update_roadmap.sh --issue <N> [--root <dir>] [--dry-run]
#
# Searches for #<N> in roadmap files under --root and updates status:
#   - Table format: changes the Status column to "done"
#   - Checklist format: changes "- [ ]" to "- [x]"
#
# Which file is the roadmap (issue #551) comes from project_document_path
# (_project_registry.sh), for the project --root belongs to: --root is its
# registered root, or a worktree of the root's own repository (merge_pr.sh
# passes the feature branch's worktree), found with
# project_document_name_for_root against the main checkout's registry.
#   - the project's `roadmap` setting names a file: that file only (a file
#     it names that does not exist: nothing is updated, with a message);
#   - the setting is `none`: nothing is updated, with a message;
#   - unset, or --root belongs to no registered project (the workspace):
#     every one of the candidates docs/roadmap.md, docs/ROADMAP.md,
#     ROADMAP.md that exists (a path that is the same file as one already
#     processed -- case-insensitive filesystems -- is skipped);
#   - the settings file or the registry cannot be read: nothing is updated,
#     with the reason.
# A file is read, written and reported under its stored name, whichever
# candidate spelling found it.
# Both formats are tried against each file found.
#
# Only matches explicit #<N> references (no fuzzy matching).
# Prints status to stderr, changed file paths to stdout.
# Always exits 0 (never blocks merge).

set -o pipefail
trap 'exit 0' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This script never blocks a merge: without a working helper, fall back to
# the candidate spelling (exact on case-sensitive filesystems) and say why.
# A helper that is present but fails to load keeps its own error on stderr.
REAL_CASE_HELPER="$SCRIPT_DIR/_real_case_path.sh"
real_case_problem=""
# shellcheck source=_real_case_path.sh
if [[ ! -f "$REAL_CASE_HELPER" ]]; then
    real_case_problem="not found"
elif ! source "$REAL_CASE_HELPER" || ! declare -F real_case_relpath >/dev/null; then
    real_case_problem="could not be loaded"
fi
if [[ -n "$real_case_problem" ]]; then
    echo "  ⚠️  _real_case_path.sh $real_case_problem next to update_roadmap.sh; using candidate spellings as-is" >&2
    real_case_relpath() { printf '%s\n' "$2"; }
fi

ISSUE_NUM=""
ROOT_DIR=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --issue)
            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --issue" >&2; exit 0; }
            ISSUE_NUM="$2"; shift 2 ;;
        --root)
            [[ $# -lt 2 ]] && { echo "ERROR: Missing value for --root" >&2; exit 0; }
            ROOT_DIR="$2"; shift 2 ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            exit 0 ;;
    esac
done

if [[ -z "$ISSUE_NUM" ]]; then
    echo "ERROR: --issue <N> is required" >&2
    exit 0
fi

if ! [[ "$ISSUE_NUM" =~ ^[0-9]+$ ]]; then
    echo "ERROR: --issue value must be numeric, got '${ISSUE_NUM}'" >&2
    exit 0
fi

if [[ -z "$ROOT_DIR" ]]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

FOUND_MATCH=false

# --- Helpers ---

# Rebuild a table row with column 4 (status) replaced by "done".
# Uses awk for precise column replacement — avoids sed regex injection.
_replace_status_col() {
    local file="$1" line_num="$2"
    awk -F'|' -v OFS='|' -v ln="$line_num" '
        NR == ln {
            # $4 is the status column — preserve spacing by replacing inner text
            gsub(/[^ ].*[^ ]/, "done", $4)
            # If status was single word with only one non-space char
            if ($4 !~ /done/) gsub(/[^ ]+/, "done", $4)
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# Try table format: | Item | #N | Status | Source | Notes |
# Match lines where the Issue column (col 3) is exactly #<N>.
_try_table_format() {
    local roadmap="$1" label="$2"

    while IFS= read -r line_num; do
        local line
        line=$(sed -n "${line_num}p" "$roadmap")

        local issue_col
        issue_col=$(echo "$line" | awk -F'|' '{print $3}' | xargs)
        if [[ "$issue_col" != "#${ISSUE_NUM}" ]]; then
            continue
        fi

        local status_col
        status_col=$(echo "$line" | awk -F'|' '{print $4}' | xargs)
        FOUND_MATCH=true
        if [[ "${status_col,,}" == "done" ]]; then
            echo "  ${label}: #${ISSUE_NUM} already marked done" >&2
            continue
        fi

        echo "  ${label}: #${ISSUE_NUM} — updating status from '${status_col}' to 'done'" >&2
        if [[ "$DRY_RUN" == false ]]; then
            _replace_status_col "$roadmap" "$line_num"
            local new_status
            new_status=$(sed -n "${line_num}p" "$roadmap" | awk -F'|' '{print $4}' | xargs)
            if [[ "${new_status,,}" == "done" ]]; then
                echo "$roadmap"
            else
                echo "  ⚠️  ${label}: replacement did not take effect" >&2
            fi
        fi
    done < <(grep -n "| *#${ISSUE_NUM} *|" "$roadmap" 2>/dev/null | cut -d: -f1)
}

# Try checklist format: - [ ] Item description (#N)
# Match unchecked items containing #<N> and check them.
_try_checklist_format() {
    local roadmap="$1" label="$2"

    # Portable word boundary: #N followed by non-alphanumeric or end of line
    while IFS= read -r line_num; do
        local line
        line=$(sed -n "${line_num}p" "$roadmap")

        if [[ "$line" != *"- [ ]"* ]]; then
            if [[ "$line" == *"- [x]"* ]]; then
                FOUND_MATCH=true
                echo "  ${label}: #${ISSUE_NUM} already checked" >&2
            fi
            continue
        fi

        FOUND_MATCH=true
        echo "  ${label}: #${ISSUE_NUM} — checking item" >&2
        if [[ "$DRY_RUN" == false ]]; then
            sed "${line_num}s/- \[ \]/- [x]/" "$roadmap" > "${roadmap}.tmp" && mv "${roadmap}.tmp" "$roadmap"
            if sed -n "${line_num}p" "$roadmap" | grep -q "\- \[x\]"; then
                echo "$roadmap"
            else
                echo "  ⚠️  ${label}: replacement did not take effect" >&2
            fi
        fi
    done < <(grep -nE "#${ISSUE_NUM}([^[:alnum:]_]|$)" "$roadmap" 2>/dev/null | cut -d: -f1)
}

# --- Which files: the project's roadmap setting, else the candidates ---
# The shared list (project_document_candidates), walked last to first:
# every candidate that exists is processed, so the order only sets the
# order of the printed paths and which spelling the same-file guard keeps
# (the first), and both stay as they were before the list was shared.
# This script never blocks a merge, so without the registry helper it uses
# the same list as written here and says why.
ROADMAP_CANDIDATES=("ROADMAP.md" "docs/ROADMAP.md" "docs/roadmap.md")
REGISTRY_HELPER="$SCRIPT_DIR/_project_registry.sh"
# shellcheck source=_project_registry.sh
if [[ -f "$REGISTRY_HELPER" ]] && source "$REGISTRY_HELPER" 2>/dev/null \
        && declare -F project_document_for_dir >/dev/null; then
    mapfile -t _shared < <(project_document_candidates roadmap)
    ROADMAP_CANDIDATES=()
    for ((_i = ${#_shared[@]} - 1; _i >= 0; _i--)); do ROADMAP_CANDIDATES+=("${_shared[_i]}"); done
    _ws="$(registry_main_checkout "$SCRIPT_DIR/../..")"
    _rc=0
    _line="$(project_document_for_dir "$_ws" "$ROOT_DIR" roadmap 2>/dev/null)" || _rc=$?
    if [[ $_rc -eq 0 && "$_line" == none ]]; then
        echo "  This project keeps no roadmap (roadmap=none in its settings); nothing to update for #${ISSUE_NUM}" >&2
        exit 0
    elif [[ $_rc -eq 0 && "$_line" == "set "* ]]; then
        ROADMAP_CANDIDATES=("${_line#set }")
    elif [[ $_rc -eq 1 ]]; then
        # Nothing exists: when a setting names the file, say so rather than
        # tick a candidate the project did not choose.
        _name="$(project_document_name_for_root "$_ws" "$ROOT_DIR" 2>/dev/null)" || _name=""
        _val=""
        [[ -z "$_name" ]] || _val="$(project_file_get "$_ws" "$_name" roadmap 2>/dev/null)" || _val=""
        if [[ -n "$_val" ]]; then
            echo "  ⚠️  roadmap=$_val (project '$_name') names a file not in $ROOT_DIR; nothing updated for #${ISSUE_NUM}" >&2
            exit 0
        fi
    elif [[ $_rc -ne 0 ]]; then
        _why="$(project_document_for_dir "$_ws" "$ROOT_DIR" roadmap 2>&1 >/dev/null | head -n1)"
        echo "  ⚠️  could not tell which file is the roadmap (${_why:-unknown error}); nothing updated for #${ISSUE_NUM}" >&2
        exit 0
    fi
else
    echo "  ⚠️  _project_registry.sh could not be loaded next to update_roadmap.sh; using the candidate roadmap files" >&2
fi

# --- Discover and process roadmap files ---
# Check every chosen location; try both formats against each file.
PROCESSED_ROADMAPS=()
for rel_path in "${ROADMAP_CANDIDATES[@]}"; do
    roadmap="$ROOT_DIR/$rel_path"
    [[ -f "$roadmap" ]] || continue
    # Use the stored name: on a case-insensitive filesystem the
    # docs/ROADMAP.md probe also opens a stored docs/roadmap.md; reporting
    # (stdout feeds merge_pr.sh's git add) and the write-back (mv of a temp
    # file onto the path) must use the name the file really has.
    rel_path="$(real_case_relpath "$ROOT_DIR" "$rel_path")"
    roadmap="$ROOT_DIR/$rel_path"
    # On a case-insensitive filesystem docs/ROADMAP.md and docs/roadmap.md
    # are one file — process it once.
    already=false
    for seen in "${PROCESSED_ROADMAPS[@]+"${PROCESSED_ROADMAPS[@]}"}"; do
        [[ "$roadmap" -ef "$seen" ]] && { already=true; break; }
    done
    $already && continue
    PROCESSED_ROADMAPS+=("$roadmap")

    _try_table_format "$roadmap" "$rel_path"
    _try_checklist_format "$roadmap" "$rel_path"
done

# --- Report ---
if [[ "$FOUND_MATCH" == false ]]; then
    echo "  No roadmap entries found for #${ISSUE_NUM}" >&2
fi
