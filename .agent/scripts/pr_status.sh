#!/bin/bash
# PR Status Dashboard
# Shows PR pipeline status across workspace and project repos
#
# NOTE: For principles-aware PR review, use the review-code skill instead.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LABEL_REVIEW="[REVIEW]"
LABEL_CRITICAL="[CRITICAL]"
LABEL_MINOR="[MINOR]"
LABEL_READY="[READY]"

# Discover workspace and project repos (returns owner/repo slugs, one per line)
discover_repos() {
    local repos=()

    # Workspace repo
    local root_url
    root_url=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "")
    if [ -n "$root_url" ] && [[ "$root_url" == *"github.com"* ]]; then
        local root_slug
        root_slug=$(echo "$root_url" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')
        [ -n "$root_slug" ] && repos+=("$root_slug")
    fi

    # Project repo
    local project_dir="$REPO_ROOT/project"
    if [ -d "$project_dir" ] && git -C "$project_dir" rev-parse --git-dir &>/dev/null; then
        local project_url
        project_url=$(git -C "$project_dir" remote get-url origin 2>/dev/null || echo "")
        if [ -n "$project_url" ] && [[ "$project_url" == *"github.com"* ]]; then
            local proj_slug
            proj_slug=$(echo "$project_url" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')
            if [ -n "$proj_slug" ]; then
                repos+=("$proj_slug")
            fi
        fi
    fi

    if [ ${#repos[@]} -gt 0 ]; then
        printf '%s\n' "${repos[@]}" | sort -u
    fi
    return 0
}

fetch_prs() {
    local args=(--state open --json "number,title,updatedAt,reviewDecision" --limit 100)
    if [ -n "${1:-}" ]; then
        args+=(--repo "$1")
    fi
    gh pr list "${args[@]}"
}

get_review_comments() {
    local pr_number=$1
    local repo=${2:-"{owner}/{repo}"}
    (gh api --paginate "/repos/${repo}/pulls/${pr_number}/comments" 2>/dev/null || echo '[]') | jq -c '.[]'
}

classify_comment() {
    local comment_body=$1
    if echo "$comment_body" | grep -iE "(security|vulnerability|bug|error|critical|dangerous|unsafe|leak)" > /dev/null; then
        echo "critical"; return
    fi
    echo "minor"
}

analyze_pr() {
    local pr_json=$1
    local repo=${2:-"{owner}/{repo}"}
    local repo_name=""
    if [ "$repo" != "{owner}/{repo}" ]; then
        repo_name="$repo"
    fi
    local number title updated review_decision
    number=$(echo "$pr_json" | jq -r '.number')
    title=$(echo "$pr_json" | jq -r '.title')
    updated=$(echo "$pr_json" | jq -r '.updatedAt')
    review_decision=$(echo "$pr_json" | jq -r '.reviewDecision // "PENDING"')

    local reviews_count
    reviews_count=$(gh api --paginate "/repos/${repo}/pulls/${number}/reviews" 2>/dev/null \
        | jq -s 'add | length' 2>/dev/null || echo "0")

    local comments
    comments=$(get_review_comments "$number" "$repo")
    local critical_count=0 minor_count=0

    if [ -n "$comments" ]; then
        while IFS= read -r comment; do
            [ -z "$comment" ] && continue
            local body severity
            body=$(echo "$comment" | jq -r '.body // ""')
            severity=$(classify_comment "$body")
            if [ "$severity" = "critical" ]; then
                critical_count=$((critical_count + 1))
            else
                minor_count=$((minor_count + 1))
            fi
        done <<< "$comments"
    fi

    local category
    if [ "$reviews_count" -eq 0 ]; then
        category="needs_review"
    elif [ "$critical_count" -gt 0 ]; then
        category="critical"
    elif [ "$minor_count" -gt 0 ]; then
        category="minor"
    elif [ "$review_decision" = "APPROVED" ]; then
        category="ready"
    else
        category="needs_review"
    fi

    local time_ago now diff hours days time_str
    if command -v gdate >/dev/null 2>&1; then
        time_ago=$(gdate -d "$updated" +%s 2>/dev/null || echo "0")
    elif date -d "$updated" +%s >/dev/null 2>&1; then
        time_ago=$(date -d "$updated" +%s 2>/dev/null || echo "0")
    else
        time_ago=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$updated" "+%s" 2>/dev/null || echo "0")
    fi
    now=$(date +%s)
    diff=$((now - time_ago))
    hours=$((diff / 3600))
    days=$((diff / 86400))
    if [ "$days" -gt 0 ]; then time_str="${days}d ago"
    elif [ "$hours" -gt 0 ]; then time_str="${hours}h ago"
    else time_str="recently"; fi

    local base_json
    base_json=$(jq -n \
        --arg category "$category" --arg number "$number" --arg title "$title" \
        --arg time "$time_str" --arg critical "$critical_count" --arg minor "$minor_count" \
        '{category: $category, number: $number, title: $title, time: $time, critical: ($critical | tonumber), minor: ($minor | tonumber)}')
    if [ -n "$repo_name" ]; then
        echo "$base_json" | jq --arg repo "$repo_name" '. + {repo: $repo}'
    else
        echo "$base_json"
    fi
}

_pre_analyze_prs() {
    local prs_json=$1 repo=${2:-""} all_analyzed="[]"
    while IFS= read -r pr; do
        local analyzed
        if [ -n "$repo" ]; then analyzed=$(analyze_pr "$pr" "$repo")
        else analyzed=$(analyze_pr "$pr"); fi
        all_analyzed=$(echo "$all_analyzed" | jq --argjson item "$analyzed" '. + [$item]')
    done < <(echo "$prs_json" | jq -c '.[]')
    echo "$all_analyzed"
}

display_category() {
    local label=$1 prefix=$2 color=$3
    shift 3
    local items=("$@")
    [ ${#items[@]} -eq 0 ] && return
    echo -e "${color}${prefix} ${label} (${#items[@]})${NC}"
    for item in "${items[@]}"; do
        local number title time critical_count minor_count item_repo
        number=$(echo "$item" | jq -r '.number')
        title=$(echo "$item" | jq -r '.title' | cut -c1-50)
        time=$(echo "$item" | jq -r '.time')
        critical_count=$(echo "$item" | jq -r '.critical')
        minor_count=$(echo "$item" | jq -r '.minor')
        item_repo=$(echo "$item" | jq -r '.repo // ""')
        if [ -n "$item_repo" ]; then
            printf "  [%s] #%-4s %-40s (last: %s)\n" "$item_repo" "$number" "$title" "$time"
        else
            printf "  #%-4s %-50s (last: %s)\n" "$number" "$title" "$time"
        fi
        [ "$critical_count" -gt 0 ] && echo "        → $critical_count critical comment(s)"
        [ "$minor_count" -gt 0 ] && echo "        → $minor_count minor comment(s)"
    done
    echo ""
}

_wrap_json_summary() {
    local analyzed_json=${1:-$(cat)}
    echo "$analyzed_json" | jq '{
        summary: {
            total: (. | length),
            needs_review: ([.[] | select(.category == "needs_review")] | length),
            critical: ([.[] | select(.category == "critical")] | length),
            minor: ([.[] | select(.category == "minor")] | length),
            ready: ([.[] | select(.category == "ready")] | length)
        },
        prs: .
    }'
}

display_analyzed_dashboard() {
    local analyzed_json=$1 title_suffix=${2:-""}
    echo -e "${BLUE}PR Status Dashboard${title_suffix}${NC}"
    echo "===================="
    echo ""
    local needs_review=() critical=() minor=() ready=()
    while IFS= read -r item; do
        local cat
        cat=$(echo "$item" | jq -r '.category')
        case "$cat" in
            needs_review) needs_review+=("$item") ;;
            critical) critical+=("$item") ;;
            minor) minor+=("$item") ;;
            ready) ready+=("$item") ;;
        esac
    done < <(echo "$analyzed_json" | jq -c '.[]')
    display_category "NEEDS REVIEW" "$LABEL_REVIEW" "$YELLOW" "${needs_review[@]}"
    display_category "CRITICAL ISSUES" "$LABEL_CRITICAL" "$RED" "${critical[@]}"
    display_category "MINOR ISSUES" "$LABEL_MINOR" "$ORANGE" "${minor[@]}"
    display_category "READY TO MERGE" "$LABEL_READY" "$GREEN" "${ready[@]}"
    local total=$((${#needs_review[@]} + ${#critical[@]} + ${#minor[@]} + ${#ready[@]}))
    echo -e "${BLUE}Summary:${NC} $total open PRs | ${#needs_review[@]} need review | $((${#critical[@]} + ${#minor[@]})) need fixes | ${#ready[@]} ready"
    echo ""
}

output_analyzed_simple() {
    local analyzed_json=$1
    local needs_review=() critical=() minor=() ready=()
    while IFS= read -r item; do
        local cat
        cat=$(echo "$item" | jq -r '.category')
        case "$cat" in
            needs_review) needs_review+=("$item") ;;
            critical) critical+=("$item") ;;
            minor) minor+=("$item") ;;
            ready) ready+=("$item") ;;
        esac
    done < <(echo "$analyzed_json" | jq -c '.[]')
    echo "SUMMARY: ${#needs_review[@]} need review, ${#critical[@]} critical, ${#minor[@]} minor, ${#ready[@]} ready"
    if [ ${#critical[@]} -gt 0 ]; then
        echo ""; echo "CRITICAL ISSUES:"
        for item in "${critical[@]}"; do
            local number title crit min item_repo
            number=$(echo "$item" | jq -r '.number'); title=$(echo "$item" | jq -r '.title')
            crit=$(echo "$item" | jq -r '.critical'); min=$(echo "$item" | jq -r '.minor')
            item_repo=$(echo "$item" | jq -r '.repo // ""')
            [ -n "$item_repo" ] && echo "  [$item_repo] #$number: $title ($crit critical, $min minor)" || \
                echo "  #$number: $title ($crit critical, $min minor)"
        done
    fi
    if [ ${#needs_review[@]} -gt 0 ]; then
        echo ""; echo "NEEDS REVIEW:"
        for item in "${needs_review[@]}"; do
            local number title item_repo
            number=$(echo "$item" | jq -r '.number'); title=$(echo "$item" | jq -r '.title')
            item_repo=$(echo "$item" | jq -r '.repo // ""')
            [ -n "$item_repo" ] && echo "  [$item_repo] #$number: $title" || echo "  #$number: $title"
        done
    fi
    if [ ${#ready[@]} -gt 0 ]; then
        echo ""; echo "READY TO MERGE:"
        for item in "${ready[@]}"; do
            local number title item_repo
            number=$(echo "$item" | jq -r '.number'); title=$(echo "$item" | jq -r '.title')
            item_repo=$(echo "$item" | jq -r '.repo // ""')
            [ -n "$item_repo" ] && echo "  [$item_repo] #$number: $title" || echo "  #$number: $title"
        done
    fi
}

get_next_analyzed_pr() {
    local analyzed_json=$1 category=${2:-"critical"}
    while IFS= read -r item; do
        local pr_category
        pr_category=$(echo "$item" | jq -r '.category')
        if [ "$pr_category" = "$category" ]; then
            echo "$item"; return 0
        fi
    done < <(echo "$analyzed_json" | jq -c '.[]')
    return 1
}

main() {
    local mode="dashboard"  # dashboard, json, simple, next-critical, next-minor, next-review
    local all_repos=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --all-repos) all_repos=true; shift ;;
            --json) mode="json"; shift ;;
            --simple) mode="simple"; shift ;;
            --next-critical) mode="next-critical"; shift ;;
            --next-minor) mode="next-minor"; shift ;;
            --next-review) mode="next-review"; shift ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --all-repos         Query workspace + project repos"
                echo "  --json              Output full status as JSON (for agents)"
                echo "  --simple            Output simple text summary (for agents)"
                echo "  --next-critical     Output next PR with critical issues"
                echo "  --next-minor        Output next PR with minor issues"
                echo "  --next-review       Output next PR needing review"
                echo "  -h, --help          Show this help"
                exit 0 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ "$all_repos" = true ]; then
        local repos
        repos=$(discover_repos)
        local pr_ndjson
        pr_ndjson=$(mktemp /tmp/pr_status_prs.XXXXXX)

        while IFS= read -r repo; do
            [ -z "$repo" ] && continue
            [ "$mode" = "dashboard" ] && echo -e "${BLUE}Fetching PRs from ${repo}...${NC}" >&2
            local repo_prs
            repo_prs=$(fetch_prs "$repo" 2>/dev/null || echo "[]")
            echo "$repo_prs" | jq -c --arg repo "$repo" '.[] | . + {_repo: $repo}' >> "$pr_ndjson"
        done <<< "$repos"

        local merged_prs
        merged_prs=$(jq -s '. // []' "$pr_ndjson")
        rm -f "$pr_ndjson"

        local analyzed_ndjson
        analyzed_ndjson=$(mktemp /tmp/pr_status_analyzed.XXXXXX)
        while IFS= read -r pr; do
            local pr_repo
            pr_repo=$(echo "$pr" | jq -r '._repo // ""')
            analyze_pr "$pr" "$pr_repo" >> "$analyzed_ndjson"
        done < <(echo "$merged_prs" | jq -c '.[]')

        local all_analyzed
        all_analyzed=$(jq -s '. // []' "$analyzed_ndjson")
        rm -f "$analyzed_ndjson"

        case "$mode" in
            json) _wrap_json_summary "$all_analyzed" ;;
            simple) output_analyzed_simple "$all_analyzed" ;;
            next-critical) get_next_analyzed_pr "$all_analyzed" "critical" || echo "No PRs with critical issues found" ;;
            next-minor) get_next_analyzed_pr "$all_analyzed" "minor" || echo "No PRs with minor issues found" ;;
            next-review) get_next_analyzed_pr "$all_analyzed" "needs_review" || echo "No PRs needing review found" ;;
            dashboard) display_analyzed_dashboard "$all_analyzed" " (All Repos)" ;;
        esac
    else
        local prs
        prs=$(fetch_prs)
        local analyzed
        analyzed=$(_pre_analyze_prs "$prs")
        case "$mode" in
            json) _wrap_json_summary "$analyzed" ;;
            simple) output_analyzed_simple "$analyzed" ;;
            next-critical) get_next_analyzed_pr "$analyzed" "critical" || echo "No PRs with critical issues found" ;;
            next-minor) get_next_analyzed_pr "$analyzed" "minor" || echo "No PRs with minor issues found" ;;
            next-review) get_next_analyzed_pr "$analyzed" "needs_review" || echo "No PRs needing review found" ;;
            dashboard) display_analyzed_dashboard "$analyzed" ;;
        esac
    fi
}

main "$@"
