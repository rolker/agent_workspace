#!/bin/bash
# .agent/scripts/update_roadmap.sh
# Update roadmap files when an issue is completed.
#
# Usage:
#   update_roadmap.sh --issue <N> [--root <dir>] [--dry-run]
#
# Searches for #<N> in roadmap files and updates status:
#   - Table format (docs/ROADMAP.md): changes Status column to "done"
#   - Checklist format (project/ROADMAP.md): changes "- [ ]" to "- [x]"
#
# Only matches explicit #<N> references (no fuzzy matching).
# Prints what was changed for transparency. Always exits 0 (never blocks merge).

set -eo pipefail

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

if [[ -z "$ROOT_DIR" ]]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

CHANGED_FILES=()
FOUND_MATCH=false

# --- Table format: docs/ROADMAP.md ---
# Format: | Item | #N | Status | Source | Notes |
# Match lines where a column contains exactly #<N> and another column has a
# status that isn't "done". Update the status column to "done".
WS_ROADMAP="$ROOT_DIR/docs/ROADMAP.md"
if [[ -f "$WS_ROADMAP" ]]; then
    # Find table lines containing #<N> in a column (word boundary match)
    # Table rows look like: | Item | #47 | done | gstack | notes |
    while IFS= read -r line_num; do
        line=$(sed -n "${line_num}p" "$WS_ROADMAP")

        # Split into columns and check if any column is exactly #<N>
        # We need the Issue column (typically column 2) to contain #<N>
        issue_col=$(echo "$line" | awk -F'|' '{print $3}' | xargs)
        if [[ "$issue_col" != "#${ISSUE_NUM}" ]]; then
            # Also check if it's part of a compound reference like "#49" in "subsumed by #88"
            # Only match if the issue column is exactly our number
            continue
        fi

        # Get current status (column 4 typically)
        status_col=$(echo "$line" | awk -F'|' '{print $4}' | xargs)
        FOUND_MATCH=true
        if [[ "${status_col,,}" == "done" ]]; then
            echo "  docs/ROADMAP.md: #${ISSUE_NUM} already marked done"
            continue
        fi

        echo "  docs/ROADMAP.md: #${ISSUE_NUM} — updating status from '${status_col}' to 'done'"
        if [[ "$DRY_RUN" == false ]]; then
            # Replace the status column value with "done" on this specific line
            # Use sed to replace the status field in the pipe-delimited table row
            sed -i "${line_num}s/| ${status_col} |/| done |/" "$WS_ROADMAP"
            CHANGED_FILES+=("$WS_ROADMAP")
        fi
    done < <(grep -n "| *#${ISSUE_NUM} *|" "$WS_ROADMAP" 2>/dev/null | cut -d: -f1)
fi

# --- Checklist format: project/ROADMAP.md ---
# Format: - [ ] Item description (#N)  or  - [ ] Item #N description
# Match unchecked items containing #<N> and check them.
PJ_ROADMAP="$ROOT_DIR/project/ROADMAP.md"
if [[ -f "$PJ_ROADMAP" ]]; then
    while IFS= read -r line_num; do
        line=$(sed -n "${line_num}p" "$PJ_ROADMAP")

        FOUND_MATCH=true
        # Only update unchecked items
        if [[ "$line" != *"- [ ]"* ]]; then
            if [[ "$line" == *"- [x]"* ]]; then
                echo "  project/ROADMAP.md: #${ISSUE_NUM} already checked"
            fi
            continue
        fi

        echo "  project/ROADMAP.md: #${ISSUE_NUM} — checking item"
        if [[ "$DRY_RUN" == false ]]; then
            sed -i "${line_num}s/- \[ \]/- [x]/" "$PJ_ROADMAP"
            CHANGED_FILES+=("$PJ_ROADMAP")
        fi
    done < <(grep -n "#${ISSUE_NUM}\b" "$PJ_ROADMAP" 2>/dev/null | cut -d: -f1)
fi

# --- Report ---
if [[ "$FOUND_MATCH" == false ]]; then
    echo "  No roadmap entries found for #${ISSUE_NUM}"
fi

# Return unique list of changed files (for caller to commit)
# Output on stdout: one file path per line (only changed files)
if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
    printf '%s\n' "${CHANGED_FILES[@]}" | sort -u
fi

exit 0
