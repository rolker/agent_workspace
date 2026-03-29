#!/bin/bash
# .agent/scripts/worktree_list.sh
# List all git worktrees for this workspace
#
# Usage:
#   ./worktree_list.sh [--verbose] [--json]
#
# Shows all active worktrees including:
#   - Issue number / skill name
#   - Type (project/workspace)
#   - Branch name
#   - Path
#   - Status (clean/dirty)
#
# Options:
#   --json    Output structured JSON to stdout (diagnostics to stderr)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "$SCRIPT_DIR/_worktree_helpers.sh"

VERBOSE=false
JSON_OUTPUT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--verbose] [--json]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show detailed status for each worktree"
            echo "      --json       Output structured JSON to stdout"
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            exit 1
            ;;
    esac
done

# JSON array accumulator
JSON_ENTRIES=()
DIRTY_COUNT=0

# Helper: escape a string for JSON (handles quotes, backslashes, newlines)
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# Helper: build a JSON object for one worktree
# Arguments: type issue skill path branch status repo files_changed
build_json_entry() {
    local type="$1" issue="$2" skill="$3" path="$4" branch="$5"
    local status="$6" repo="$7" files_changed="$8"

    local issue_val="null"
    [ -n "$issue" ] && issue_val="$issue"

    local skill_val="null"
    [ -n "$skill" ] && skill_val="\"$(json_escape "$skill")\""

    local repo_val="null"
    [ -n "$repo" ] && repo_val="\"$(json_escape "$repo")\""

    local branch_val="null"
    [ -n "$branch" ] && branch_val="\"$(json_escape "$branch")\""

    printf '{"type":"%s","issue":%s,"skill":%s,"path":"%s","branch":%s,"status":"%s","repo":%s,"files_changed":%s}' \
        "$type" "$issue_val" "$skill_val" \
        "$(json_escape "$path")" "$branch_val" "$status" \
        "$repo_val" "${files_changed:-0}"
}

cd "$ROOT_DIR"

if [ "$JSON_OUTPUT" = false ]; then
    echo "========================================"
    echo "Git Worktrees"
    echo "========================================"
    echo ""
fi

# Get worktree list from git (workspace repo: main + workspace worktrees)
WORKTREES=$(git worktree list --porcelain)

WORKSPACE_COUNT=0
PROJECT_COUNT=0

# Helper: extract issue/repo/skill from worktree directory basename
extract_issue_repo() {
    local basename="$1"
    WT_ISSUE=""
    WT_REPO=""
    WT_SKILL=""

    # Skill format: skill-{REPO_SLUG}-{SKILL_NAME}-{TIMESTAMP}
    if [[ "$basename" =~ ^skill-([a-zA-Z0-9_]+)-([a-zA-Z0-9_-]+)-([0-9]{8}-[0-9]{6}(-[0-9]+)?)$ ]]; then
        WT_REPO="${BASH_REMATCH[1]}"
        WT_SKILL="${BASH_REMATCH[2]}"
    # New format: issue-{REPO_SLUG}-{NUMBER}
    elif [[ "$basename" =~ ^issue-([a-zA-Z0-9_]+)-([0-9]+)$ ]]; then
        WT_REPO="${BASH_REMATCH[1]}"
        WT_ISSUE="${BASH_REMATCH[2]}"
    # Legacy format: issue-{NUMBER}
    elif [[ "$basename" =~ ^issue-([0-9]+)$ ]]; then
        WT_ISSUE="${BASH_REMATCH[1]}"
        WT_REPO="(legacy)"
    fi
}

# Print a worktree entry
print_worktree() {
    local path="$1"
    local branch="$2"
    local head="$3"

    local type="main"
    local issue=""
    local repo=""
    local skill=""

    if [[ "$path" == *"/worktrees/workspace/"* ]] || [[ "$path" == *"/.workspace-worktrees/"* ]]; then
        type="workspace"
        extract_issue_repo "$(basename "$path")"
        issue="$WT_ISSUE"
        repo="$WT_REPO"
        skill="$WT_SKILL"
        ((WORKSPACE_COUNT++)) || true
    fi

    # Check if clean or dirty and count changed files
    local status="clean"
    local files_changed=0
    if [ -d "$path" ]; then
        local porcelain
        porcelain="$(git -C "$path" status --porcelain 2>/dev/null || true)"
        if [ -n "$porcelain" ]; then
            status="dirty"
            files_changed=$(echo "$porcelain" | wc -l)
            files_changed=$((files_changed + 0))  # strip whitespace
        fi
    fi

    # Track dirty count (exclude main — summary.total excludes main too)
    if [ "$status" = "dirty" ] && [ "$type" != "main" ]; then
        ((DIRTY_COUNT++)) || true
    fi

    # Collect JSON entry
    local display_branch="${branch:-detached at $head}"
    JSON_ENTRIES+=("$(build_json_entry "$type" "$issue" "$skill" "$path" "$display_branch" "$status" "$repo" "$files_changed")")

    # Format text output
    if [ "$JSON_OUTPUT" = false ]; then
        if [ "$type" == "main" ]; then
            echo "[main] Main Workspace"
            echo "   Path:   $path"
            echo "   Branch: $display_branch"
            echo "   Status: $status"
        elif [ -n "$skill" ]; then
            echo "[workspace] Skill: $skill - Repository: $repo"
            echo "   Path:   $path"
            echo "   Branch: $display_branch"
            echo "   Status: $status"
            if [ "$VERBOSE" = true ] && [ -d "$path" ]; then
                echo "   Files changed: $files_changed"
            fi
        else
            echo "[workspace] Issue #$issue - Repository: $repo"
            echo "   Path:   $path"
            echo "   Branch: $display_branch"
            echo "   Status: $status"
            if [ "$VERBOSE" = true ] && [ -d "$path" ]; then
                echo "   Files changed: $files_changed"
            fi
        fi
        echo ""
    fi
}

# Parse and display workspace worktrees from git worktree list
CURRENT_PATH=""
CURRENT_BRANCH=""
CURRENT_HEAD=""

while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line == worktree* ]]; then
        if [ -n "$CURRENT_PATH" ]; then
            print_worktree "$CURRENT_PATH" "$CURRENT_BRANCH" "$CURRENT_HEAD"
        fi
        CURRENT_PATH="${line#worktree }"
        CURRENT_BRANCH=""
        CURRENT_HEAD=""
    elif [[ $line == HEAD* ]]; then
        CURRENT_HEAD="${line#HEAD }"
    elif [[ $line == branch* ]]; then
        CURRENT_BRANCH="${line#branch refs/heads/}"
    fi
done <<< "$WORKTREES"

if [ -n "$CURRENT_PATH" ]; then
    print_worktree "$CURRENT_PATH" "$CURRENT_BRANCH" "$CURRENT_HEAD"
fi

# Discover project worktrees by scanning worktrees/project/*/ (new) and project/worktrees/ (legacy)
_scan_project_worktrees() {
    local search_dir="$1"
    local is_legacy="$2"

    [ -d "$search_dir" ] || return 0

    for proj_wt in "$search_dir"/issue-* "$search_dir"/skill-*; do
        [ -d "$proj_wt" ] || continue

        extract_issue_repo "$(basename "$proj_wt")"
        local_issue="$WT_ISSUE"
        local_repo="$WT_REPO"
        local_skill="$WT_SKILL"

        local_branch=$(git -C "$proj_wt" branch --show-current 2>/dev/null || echo "")

        # Check dirty status and count changed files
        local_status="clean"
        local_changed=0
        local_porcelain
        local_porcelain="$(git -C "$proj_wt" status --porcelain 2>/dev/null || true)"
        if [ -n "$local_porcelain" ]; then
            local_status="dirty"
            local_changed=$(echo "$local_porcelain" | wc -l)
            local_changed=$((local_changed + 0))
            ((DIRTY_COUNT++)) || true
        fi

        # Collect JSON entry
        JSON_ENTRIES+=("$(build_json_entry "project" "$local_issue" "$local_skill" "$proj_wt" "${local_branch:-}" "$local_status" "$local_repo" "$local_changed")")

        # Format text output
        if [ "$JSON_OUTPUT" = false ]; then
            if [ "$is_legacy" = true ]; then
                echo "[project] ⚠️  LEGACY LOCATION"
            fi
            if [ -n "$local_skill" ]; then
                echo "[project] Skill: $local_skill - Repository: $local_repo"
            else
                echo "[project] Issue #$local_issue - Repository: $local_repo"
            fi
            echo "   Path:   $proj_wt"
            echo "   Branch: ${local_branch:-unknown}"
            echo "   Status: $local_status"

            if [ "$VERBOSE" = true ]; then
                echo "   Files changed: $local_changed"
            fi

            echo ""
        fi
        ((PROJECT_COUNT++)) || true
    done
}

# New location: worktrees/project/<repo>/
NEW_PROJECT_BASE="$(wt_project_base_glob "$ROOT_DIR")"
if [ -d "$NEW_PROJECT_BASE" ]; then
    for repo_dir in "$NEW_PROJECT_BASE"/*/; do
        [ -d "$repo_dir" ] || continue
        _scan_project_worktrees "${repo_dir%/}" false
    done
fi

# Legacy location: project/worktrees/
LEGACY_PROJECT_BASE="$(wt_legacy_project_base "$ROOT_DIR")"
_scan_project_worktrees "$LEGACY_PROJECT_BASE" true

# --- Output ---

if [ "$JSON_OUTPUT" = true ]; then
    TOTAL=$(( PROJECT_COUNT + WORKSPACE_COUNT ))

    # Build JSON array
    printf '{"worktrees":['
    first=true
    for entry in "${JSON_ENTRIES[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            printf ','
        fi
        printf '%s' "$entry"
    done
    printf '],"summary":{"total":%d,"project":%d,"workspace":%d,"dirty":%d}}\n' \
        "$TOTAL" "$PROJECT_COUNT" "$WORKSPACE_COUNT" "$DIRTY_COUNT"
    exit 0
fi

# Text output continues below

if [ -z "$WORKTREES" ] && [ "$WORKSPACE_COUNT" -eq 0 ] && [ "$PROJECT_COUNT" -eq 0 ]; then
    echo "No worktrees found."
    echo ""
    echo "Create one with:"
    echo "  ./.agent/scripts/worktree_create.sh --issue <number> --type workspace"
    exit 0
fi

echo "========================================"
echo "Summary"
echo "========================================"
echo "  Workspace worktrees: $WORKSPACE_COUNT"
echo "  Project worktrees:   $PROJECT_COUNT"
echo ""
echo "Locations:"
echo "  Workspace: worktrees/workspace/"
echo "  Project:   worktrees/project/<repo>/"
