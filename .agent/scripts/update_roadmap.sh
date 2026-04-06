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

if [[ -z "$ROOT_DIR" ]]; then
    ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

FOUND_MATCH=false

# Helper: rebuild a table row with column 4 (status) replaced by "done".
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

# --- Table format: docs/ROADMAP.md ---
# Format: | Item | #N | Status | Source | Notes |
# Match lines where the Issue column (col 3) is exactly #<N>.
# Update the Status column (col 4) to "done".
WS_ROADMAP="$ROOT_DIR/docs/ROADMAP.md"
if [[ -f "$WS_ROADMAP" ]]; then
    while IFS= read -r line_num; do
        line=$(sed -n "${line_num}p" "$WS_ROADMAP")

        # Check Issue column (awk field $3) is exactly #<N>
        issue_col=$(echo "$line" | awk -F'|' '{print $3}' | xargs)
        if [[ "$issue_col" != "#${ISSUE_NUM}" ]]; then
            continue
        fi

        status_col=$(echo "$line" | awk -F'|' '{print $4}' | xargs)
        FOUND_MATCH=true
        if [[ "${status_col,,}" == "done" ]]; then
            echo "  docs/ROADMAP.md: #${ISSUE_NUM} already marked done" >&2
            continue
        fi

        echo "  docs/ROADMAP.md: #${ISSUE_NUM} — updating status from '${status_col}' to 'done'" >&2
        if [[ "$DRY_RUN" == false ]]; then
            _replace_status_col "$WS_ROADMAP" "$line_num"
            # Verify the change actually took effect
            new_status=$(sed -n "${line_num}p" "$WS_ROADMAP" | awk -F'|' '{print $4}' | xargs)
            if [[ "${new_status,,}" == "done" ]]; then
                echo "$WS_ROADMAP"
            else
                echo "  ⚠️  docs/ROADMAP.md: replacement did not take effect" >&2
            fi
        fi
    done < <(grep -n "| *#${ISSUE_NUM} *|" "$WS_ROADMAP" 2>/dev/null | cut -d: -f1)
fi

# --- Checklist format: project/ROADMAP.md ---
# Format: - [ ] Item description (#N)  or  - [ ] Item #N description
# Match unchecked items containing #<N> and check them.
PJ_ROADMAP="$ROOT_DIR/project/ROADMAP.md"
if [[ -f "$PJ_ROADMAP" ]]; then
    # Portable word boundary: #N followed by non-alphanumeric or end of line
    while IFS= read -r line_num; do
        line=$(sed -n "${line_num}p" "$PJ_ROADMAP")

        FOUND_MATCH=true
        if [[ "$line" != *"- [ ]"* ]]; then
            if [[ "$line" == *"- [x]"* ]]; then
                echo "  project/ROADMAP.md: #${ISSUE_NUM} already checked" >&2
            fi
            continue
        fi

        echo "  project/ROADMAP.md: #${ISSUE_NUM} — checking item" >&2
        if [[ "$DRY_RUN" == false ]]; then
            sed -i "${line_num}s/- \[ \]/- [x]/" "$PJ_ROADMAP"
            # Verify the change
            if sed -n "${line_num}p" "$PJ_ROADMAP" | grep -q "\- \[x\]"; then
                echo "$PJ_ROADMAP"
            else
                echo "  ⚠️  project/ROADMAP.md: replacement did not take effect" >&2
            fi
        fi
    done < <(grep -nE "#${ISSUE_NUM}([^[:alnum:]_]|$)" "$PJ_ROADMAP" 2>/dev/null | cut -d: -f1)
fi

# --- Report ---
if [[ "$FOUND_MATCH" == false ]]; then
    echo "  No roadmap entries found for #${ISSUE_NUM}" >&2
fi
