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
#     processed -- case-insensitive filesystems -- is skipped). A candidate
#     that is a symbolic link to a file inside --root is edited through the
#     link (the link stays); one that leads outside --root is handled as
#     before the setting existed (the edited copy replaces the link; the
#     file outside is not touched), with a warning;
#   - another key's bad line in the settings file: a warning, then the
#     roadmap key from its own line if valid, else the candidates;
#   - whether the key is set cannot be told (the registry cannot be parsed,
#     the settings file cannot be read): nothing is updated, with "cannot
#     be told: <reason>" -- a writer never ticks a file the project may not
#     have chosen (PROJECT_DOC_STRICT=1);
#   - the roadmap key itself is unusable (set twice, an invalid value, a
#     file outside --root, a symbolic link): nothing is updated, with the
#     reason.
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
# The candidate the lookup chose (it has warned about that one already).
LOOKUP_FALLBACK=""
REGISTRY_HELPER="$SCRIPT_DIR/_project_registry.sh"
# shellcheck source=_project_registry.sh
if [[ -f "$REGISTRY_HELPER" ]] && source "$REGISTRY_HELPER" 2>/dev/null \
        && declare -F project_document_query >/dev/null; then
    mapfile -t _shared < <(project_document_candidates roadmap)
    ROADMAP_CANDIDATES=()
    for ((_i = ${#_shared[@]} - 1; _i >= 0; _i--)); do ROADMAP_CANDIDATES+=("${_shared[_i]}"); done
    _ws="$(registry_main_checkout "$SCRIPT_DIR/../..")"
    # A writer: when whether the key is set cannot be told, it does nothing
    # (return 3); another key's bad line leaves a warning and the key's own
    # line, else the candidates; an unusable roadmap key stops here.
    PROJECT_DOC_STRICT=1 project_document_query project_document_for_dir "$_ws" "$ROOT_DIR" roadmap
    if [[ $PROJECT_DOC_RC -eq 0 && "$PROJECT_DOC_LINE" == none ]]; then
        echo "  This project keeps no roadmap (roadmap=none in its settings); nothing to update for #${ISSUE_NUM}" >&2
        exit 0
    elif [[ $PROJECT_DOC_RC -eq 0 && "$PROJECT_DOC_LINE" == "set "* ]]; then
        ROADMAP_CANDIDATES=("${PROJECT_DOC_LINE#set }")
    elif [[ $PROJECT_DOC_RC -eq 1 && "$PROJECT_DOC_LINE" == "set "* ]]; then
        # The setting names a file that does not exist: say so rather than
        # tick a candidate the project did not choose.
        echo "  ⚠️  roadmap=${PROJECT_DOC_LINE#set } names a file not in $ROOT_DIR; nothing updated for #${ISSUE_NUM}" >&2
        exit 0
    elif [[ $PROJECT_DOC_RC -eq 3 ]]; then
        echo "  ⚠️  which file is the roadmap cannot be told: ${PROJECT_DOC_WHY:-unknown error}; nothing updated for #${ISSUE_NUM}" >&2
        exit 0
    elif [[ $PROJECT_DOC_RC -ne 0 && $PROJECT_DOC_RC -ne 1 ]]; then
        echo "  ⚠️  the roadmap setting cannot be used (${PROJECT_DOC_WHY:-unknown error}); nothing updated for #${ISSUE_NUM}" >&2
        exit 0
    elif [[ "$PROJECT_DOC_LINE" == "fallback "* ]]; then
        LOOKUP_FALLBACK="${PROJECT_DOC_LINE#fallback }"
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
    # A candidate that is a symbolic link: edit the file it leads to when
    # that is inside --root, so the link stays a link; one that leads
    # outside is edited as before (the copy replaces the link, the outside
    # file is untouched), with a warning unless the lookup gave one.
    # (Its messages wait for the same-file guard below, so a link to a file
    # already processed says nothing.)
    _link_note=""
    if [[ -L "$roadmap" ]]; then
        _root_abs="$(cd "$ROOT_DIR" && pwd -P)"
        _real="$(readlink -f -- "$roadmap" 2>/dev/null)" || _real=""
        if [[ -n "$_real" && "$_real" == "$_root_abs/"* ]]; then
            roadmap="$_real"
            _link_note="  ${rel_path} is a link: editing ${_real#"$_root_abs"/} through it"
            rel_path="${_real#"$_root_abs"/}"
        elif [[ "$rel_path" != "$LOOKUP_FALLBACK" ]]; then
            _link_note="  ⚠️  ${rel_path} leads outside $ROOT_DIR (${_real:-unresolved}); edited as before: the edited copy replaces the link"
        fi
    fi
    # On a case-insensitive filesystem docs/ROADMAP.md and docs/roadmap.md
    # are one file — process it once.
    already=false
    for seen in "${PROCESSED_ROADMAPS[@]+"${PROCESSED_ROADMAPS[@]}"}"; do
        [[ "$roadmap" -ef "$seen" ]] && { already=true; break; }
    done
    $already && continue
    PROCESSED_ROADMAPS+=("$roadmap")
    [[ -z "$_link_note" ]] || echo "$_link_note" >&2

    _try_table_format "$roadmap" "$rel_path"
    _try_checklist_format "$roadmap" "$rel_path"
done

# --- Report ---
if [[ "$FOUND_MATCH" == false ]]; then
    echo "  No roadmap entries found for #${ISSUE_NUM}" >&2
fi
