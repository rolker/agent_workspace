#!/bin/bash
# .agent/scripts/_issue_helpers.sh
# Shared helper functions for git-bug-first issue lookups with sync-on-miss.
#
# Source this file from other scripts:
#   source "$SCRIPT_DIR/_issue_helpers.sh"
#
# Requires: jq (for JSON parsing)
# Optional: git-bug v0.10+ with GitHub bridge configured
#
# Pattern: try git-bug first (offline-capable), pull on cache miss,
# fall back to gh CLI. See ADR-0010 and AGENTS.md "git-bug-first Pattern".

# --- Single-issue lookup ---
# Fetch title, state, and body for a GitHub issue number.
#
# Usage:
#   issue_lookup <N> --repo <owner/repo> [--root <dir>]
#
# Sets these variables in the caller's scope:
#   ISSUE_TITLE  — issue title (empty string if not found)
#   ISSUE_STATE  — OPEN or CLOSED (empty string if not found)
#   ISSUE_BODY   — issue body text (empty string if not found)
#
# Returns 0 on success, 1 if issue not found via any source.
issue_lookup() {
    local issue_num="" repo_slug="" root_dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo) repo_slug="$2"; shift 2 ;;
            --root) root_dir="$2"; shift 2 ;;
            *)
                if [[ -z "$issue_num" ]]; then
                    issue_num="$1"; shift
                else
                    echo "ERROR: issue_lookup: unexpected argument: $1" >&2
                    return 1
                fi
                ;;
        esac
    done

    if [[ -z "$issue_num" ]]; then
        echo "ERROR: issue_lookup: issue number required" >&2
        return 1
    fi
    if [[ -z "$repo_slug" ]]; then
        echo "ERROR: issue_lookup: --repo <owner/repo> required" >&2
        return 1
    fi

    # Default root to script's workspace root
    if [[ -z "$root_dir" ]]; then
        root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi

    ISSUE_TITLE=""
    ISSUE_STATE=""
    ISSUE_BODY=""

    # --- Try git-bug ---
    if command -v git-bug &>/dev/null && command -v jq &>/dev/null; then
        local github_url="https://github.com/${repo_slug}/issues/${issue_num}"

        _issue_lookup_gitbug "$root_dir" "$github_url"

        # Sync-on-miss: if not found locally, pull and retry
        if [[ -z "$ISSUE_TITLE" ]]; then
            local has_bridge
            has_bridge=$(git -C "$root_dir" bug bridge 2>/dev/null | grep -c "github" || true)
            if [[ "$has_bridge" -gt 0 ]]; then
                echo "  git-bug: cache miss for #${issue_num}, pulling from GitHub..." >&2
                git -C "$root_dir" bug bridge pull github &>/dev/null || true
                _issue_lookup_gitbug "$root_dir" "$github_url"
            fi
        fi
    fi

    # --- Fall back to gh ---
    if [[ -z "$ISSUE_TITLE" ]] && command -v gh &>/dev/null; then
        local gh_json
        gh_json=$(gh issue view "$issue_num" --repo "$repo_slug" \
            --json title,state,body 2>/dev/null || echo "")
        if [[ -n "$gh_json" ]]; then
            ISSUE_TITLE=$(echo "$gh_json" | jq -r '.title // empty')
            ISSUE_STATE=$(echo "$gh_json" | jq -r '.state // empty')
            ISSUE_BODY=$(echo "$gh_json" | jq -r '.body // empty')
        fi
    fi

    [[ -n "$ISSUE_TITLE" ]]
}

# Internal: query git-bug by GitHub URL metadata.
# Sets ISSUE_TITLE, ISSUE_STATE, ISSUE_BODY in caller's scope.
# shellcheck disable=SC2034 # Variables are set for the caller's use
_issue_lookup_gitbug() {
    local root_dir="$1" github_url="$2"

    local list_json bug_id
    list_json=$(git -C "$root_dir" bug bug \
        -m "github-url=${github_url}" --format json 2>/dev/null || echo "")

    if [[ -z "$list_json" ]] || [[ "$list_json" == "[]" ]] || [[ "$list_json" == "null" ]]; then
        return
    fi

    bug_id=$(echo "$list_json" | jq -r '.[0].human_id // empty' 2>/dev/null)
    if [[ -z "$bug_id" ]]; then
        return
    fi

    local show_json
    show_json=$(git -C "$root_dir" bug bug show "$bug_id" --format json 2>/dev/null || echo "")
    if [[ -z "$show_json" ]]; then
        return
    fi

    ISSUE_TITLE=$(echo "$show_json" | jq -r '.title // empty')
    local raw_state
    raw_state=$(echo "$show_json" | jq -r '.status // empty')
    case "${raw_state,,}" in
        open) ISSUE_STATE="OPEN" ;;
        closed) ISSUE_STATE="CLOSED" ;;
        *) ISSUE_STATE="$raw_state" ;;
    esac
    # Body is the first comment's message
    ISSUE_BODY=$(echo "$show_json" | jq -r '.comments[0].message // empty')
}

# --- List open issues ---
# List open issues from git-bug or gh.
#
# Usage:
#   issue_list_open [--repo <owner/repo>] [--root <dir>]
#
# Outputs one line per issue: <human_id_or_number>\t<title>
# Returns 0 on success, 1 if no source available.
issue_list_open() {
    local repo_slug="" root_dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo) repo_slug="$2"; shift 2 ;;
            --root) root_dir="$2"; shift 2 ;;
            *) echo "ERROR: issue_list_open: unexpected argument: $1" >&2; return 1 ;;
        esac
    done

    if [[ -z "$root_dir" ]]; then
        root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi

    # --- Try git-bug ---
    if command -v git-bug &>/dev/null; then
        local has_bridge
        has_bridge=$(git -C "$root_dir" bug bridge 2>/dev/null | grep -c "github" || true)
        if [[ "$has_bridge" -gt 0 ]]; then
            local list_output
            list_output=$(git -C "$root_dir" bug bug status:open 2>/dev/null)
            if [[ $? -eq 0 && -n "$list_output" ]]; then
                # Output format: <short_id>\t<status>\t<title>
                # Reformat to: <short_id>\t<title>
                echo "$list_output" | awk -F'\t' '{print $1 "\t" $3}'
                return 0
            fi
        fi
    fi

    # --- Fall back to gh ---
    if command -v gh &>/dev/null && [[ -n "$repo_slug" ]]; then
        gh issue list --repo "$repo_slug" --state open \
            --json number,title --jq '.[] | "\(.number)\t\(.title)"' 2>/dev/null
        return $?
    fi

    return 1
}

# --- Count open issues ---
# Count open issues from git-bug or gh.
#
# Usage:
#   issue_count_open [--repo <owner/repo>] [--root <dir>]
#
# Outputs a single integer. Returns 0 on success, 1 if no source available.
issue_count_open() {
    local repo_slug="" root_dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo) repo_slug="$2"; shift 2 ;;
            --root) root_dir="$2"; shift 2 ;;
            *) echo "ERROR: issue_count_open: unexpected argument: $1" >&2; return 1 ;;
        esac
    done

    if [[ -z "$root_dir" ]]; then
        root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi

    # --- Try git-bug ---
    if command -v git-bug &>/dev/null; then
        local has_bridge
        has_bridge=$(git -C "$root_dir" bug bridge 2>/dev/null | grep -c "github" || true)
        if [[ "$has_bridge" -gt 0 ]]; then
            local list_output
            if list_output=$(git -C "$root_dir" bug bug status:open 2>/dev/null); then
                if [[ -z "$list_output" ]]; then
                    echo "0"
                else
                    echo "$list_output" | grep -c .
                fi
                return 0
            fi
        fi
    fi

    # --- Fall back to gh ---
    if command -v gh &>/dev/null && [[ -n "$repo_slug" ]]; then
        gh api -X GET search/issues \
            -f q="repo:${repo_slug} is:issue is:open" \
            --jq '.total_count' 2>/dev/null || echo "0"
        return 0
    fi

    return 1
}
