#!/bin/bash
# .agent/scripts/update_roadmap.sh
# Update roadmap files when an issue is completed.
#
# Usage:
#   update_roadmap.sh --issue <N> [--root <dir>] [--dry-run]
#
# Searches for #<N> in ROADMAP.md files under --root and updates status:
#   - Table format: changes the Status column to "done"
#   - Checklist format: changes "- [ ]" to "- [x]"
#
# Discovers roadmap files at: ROADMAP.md, docs/ROADMAP.md
# Both formats are tried against each file found.
#
# Only matches explicit #<N> references (no fuzzy matching).
# Prints status to stderr, changed file paths to stdout.
# Always exits 0 (never blocks merge).

set -o pipefail
trap 'exit 0' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# --- Discover and process roadmap files ---
# Check both possible locations; try both formats against each file.
for rel_path in "ROADMAP.md" "docs/ROADMAP.md"; do
    roadmap="$ROOT_DIR/$rel_path"
    [[ -f "$roadmap" ]] || continue

    _try_table_format "$roadmap" "$rel_path"
    _try_checklist_format "$roadmap" "$rel_path"
done

# --- Report ---
if [[ "$FOUND_MATCH" == false ]]; then
    echo "  No roadmap entries found for #${ISSUE_NUM}" >&2
fi
