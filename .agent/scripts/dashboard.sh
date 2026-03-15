#!/bin/bash

# Agent Workspace Dashboard
# Unified workspace status: health checks, repository sync, git status,
# worktree status, and GitHub PRs/issues.
#
# Usage:
#   dashboard.sh [OPTIONS]
#
# OPTIONS:
#   --quick          Quick local-only mode (skip sync and GitHub API calls)
#   --skip-sync      Skip repository fetch step (faster, may show stale data)
#   --skip-github    Skip GitHub PR/issue queries (offline mode)
#   --help           Show this help message
#
# EXAMPLES:
#   dashboard.sh                    # Full dashboard with sync and GitHub
#   dashboard.sh --quick            # Fast local-only check
#   dashboard.sh --skip-sync        # Skip fetch, keep GitHub queries
#
# DEPENDENCIES:
#   Required: git, python3
#   Optional: gh + jq (for GitHub data)

# Note: do not use 'set -e' here; many checks are best-effort and may fail.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# --- Parse arguments ---
SKIP_SYNC=false
SKIP_GITHUB=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick) SKIP_SYNC=true; SKIP_GITHUB=true; shift ;;
        --skip-sync) SKIP_SYNC=true; shift ;;
        --skip-github) SKIP_GITHUB=true; shift ;;
        --help)
            awk 'NR>1 && /^# Note: do not use/ {exit} NR>1 {sub(/^# ?/, ""); print}' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# --- Worktree detection ---
WORKTREE_INFO=""
if [[ "$ROOT_DIR" == *"/project/worktrees/"* ]]; then
    WORKTREE_INFO="project worktree"
    MAIN_ROOT="$(dirname "$(dirname "$(dirname "$ROOT_DIR")")")"
elif [[ "$ROOT_DIR" == *"/.workspace-worktrees/"* ]]; then
    WORKTREE_INFO="workspace worktree"
    MAIN_ROOT="$(dirname "$(dirname "$ROOT_DIR")")"
else
    MAIN_ROOT="$ROOT_DIR"
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_pass() { echo -e "  ${GREEN}✅ $1${NC}"; }
check_fail() { echo -e "  ${RED}❌ $1${NC}"; }
check_warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }

# --- Header ---
echo ""
echo "# Workspace Dashboard"
echo "**Date**: $(date)"
if [ -n "$WORKTREE_INFO" ]; then
    echo "**Context**: Running in $WORKTREE_INFO"
fi
echo ""

SECTION=0

#######################################
# SECTION: HEALTH CHECKS
#######################################

SECTION=$((SECTION + 1))
echo "## $SECTION. Health Checks"
echo ""

FAILED_CHECKS=0

# Required tools
for tool in git python3; do
    if command -v "$tool" &> /dev/null; then
        check_pass "$tool found"
    else
        check_fail "$tool not found"
        ((FAILED_CHECKS++))
    fi
done

# Dev tools
VENV_ROOT="${MAIN_ROOT:-$ROOT_DIR}"
if [ -x "$VENV_ROOT/.venv/bin/pre-commit" ]; then
    check_pass "pre-commit installed in .venv"

    HOOK_FILE=$(git -C "$ROOT_DIR" rev-parse --path-format=absolute --git-path hooks/pre-commit 2>/dev/null || true)
    if [ -n "$HOOK_FILE" ] && [ -f "$HOOK_FILE" ]; then
        INSTALL_PYTHON=$(sed -n 's/^INSTALL_PYTHON=//p' "$HOOK_FILE" | tr -d "'" | tr -d '"')
        if [ -n "$INSTALL_PYTHON" ] && [ -x "$INSTALL_PYTHON" ]; then
            check_pass "pre-commit hook installed"
        else
            check_warn "pre-commit hook has invalid INSTALL_PYTHON. Run: make lint"
        fi
    elif [ -n "$HOOK_FILE" ]; then
        check_warn "pre-commit hook not installed. Run: make lint (auto-installs)"
    fi
else
    check_warn "pre-commit not found. Run: make lint (auto-installs)"
fi

# Project directory
PROJECT_DIR="${MAIN_ROOT:-$ROOT_DIR}/project"
if [ -d "$PROJECT_DIR" ] && git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
    PROJECT_REMOTE=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo "")
    if [ -n "$PROJECT_REMOTE" ]; then
        check_pass "project/ configured ($(basename "$PROJECT_REMOTE" .git))"
    else
        check_warn "project/ is a git repo but has no remote"
    fi
else
    check_warn "project/ not configured. Run: make setup"
fi

# Configuration validation
if [ -f "$SCRIPT_DIR/validate_workspace.py" ]; then
    if python3 "$SCRIPT_DIR/validate_workspace.py" &>/dev/null; then
        check_pass "Workspace configuration valid"
    else
        check_warn "Workspace configuration issue. Run: make validate"
    fi
fi

# Lock status
LOCK_FILE="$ROOT_DIR/.agent/scratchpad/workspace.lock"
if [ -f "$LOCK_FILE" ]; then
    check_warn "Workspace is LOCKED (run: make unlock)"
else
    check_pass "Workspace is unlocked"
fi

# Git status (workspace repo)
cd "$ROOT_DIR" || exit
if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current)
    if [ -n "$(git status --porcelain)" ]; then
        check_warn "Workspace repo has uncommitted changes (branch: $BRANCH)"
    else
        check_pass "Workspace repo is clean (branch: $BRANCH)"
    fi
fi

echo ""
if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "  ${GREEN}All critical checks passed.${NC}"
else
    echo -e "  ${RED}$FAILED_CHECKS critical check(s) failed.${NC}"
fi
echo ""

#######################################
# SECTION: SYNC REPOSITORIES
#######################################

if [ "$SKIP_SYNC" = false ]; then
    SECTION=$((SECTION + 1))
    echo "## $SECTION. Syncing Repositories"
    echo ""

    echo -n "Syncing workspace repository... "
    if git -C "$ROOT_DIR" fetch --quiet 2>/dev/null; then
        echo "✅"
    else
        echo "⚠️ (fetch failed)"
    fi

    if [ -d "$PROJECT_DIR" ] && git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
        PROJECT_NAME=$(basename "$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo project)" .git)
        echo -n "Syncing project ($PROJECT_NAME)... "
        if git -C "$PROJECT_DIR" fetch --quiet 2>/dev/null; then
            echo "✅"
        else
            echo "⚠️ (fetch failed)"
        fi
    fi

    echo ""
fi

#######################################
# SECTION: REPOSITORY STATUS
#######################################

SECTION=$((SECTION + 1))
echo "## $SECTION. Repository Status"
echo ""

# Workspace repository
echo "### Workspace Repository"
cd "$ROOT_DIR" || exit
if [ -n "$(git status --porcelain)" ]; then
    echo "- **Status**: ⚠️ Modified"
    echo "- **Branch**: $(git branch --show-current)"
    echo ""
    echo "**Modified Files:**"
    echo '```'
    git status --short
    echo '```'
else
    echo "- **Status**: ✅ Clean"
    echo "- **Branch**: $(git branch --show-current)"
fi
echo ""

# Project repository
echo "### Project Repository"
if [ -d "$PROJECT_DIR" ] && git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
    PROJ_BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "detached HEAD")
    PROJ_REMOTE=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo "(no remote)")
    if [ -n "$(git -C "$PROJECT_DIR" status --porcelain)" ]; then
        echo "- **Status**: ⚠️ Modified"
        echo "- **Branch**: $PROJ_BRANCH"
        echo "- **Remote**: $PROJ_REMOTE"
        echo ""
        echo "**Modified Files:**"
        echo '```'
        git -C "$PROJECT_DIR" status --short
        echo '```'
    else
        echo "- **Status**: ✅ Clean"
        echo "- **Branch**: $PROJ_BRANCH"
        echo "- **Remote**: $PROJ_REMOTE"
    fi
else
    echo "- **Status**: ⚠️ Not configured (run: make setup)"
fi
echo ""

echo "---"
echo ""

#######################################
# SECTION: ACTIVE WORKTREES
#######################################

SECTION=$((SECTION + 1))
echo "## $SECTION. Active Worktrees"
echo ""

WORKTREE_SCRIPT="$SCRIPT_DIR/worktree_list.sh"
if [ -x "$WORKTREE_SCRIPT" ]; then
    WT_COUNT=$(git -C "$ROOT_DIR" worktree list 2>/dev/null | grep -v "(bare)" | grep -vF "$ROOT_DIR " | wc -l)
    # Also count project worktrees
    PROJ_WT_COUNT=0
    if [ -d "$PROJECT_DIR/worktrees" ]; then
        PROJ_WT_COUNT=$(find "$PROJECT_DIR/worktrees" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
    fi
    if [ "$WT_COUNT" -gt 0 ] || [ "$PROJ_WT_COUNT" -gt 0 ]; then
        "$WORKTREE_SCRIPT" 2>/dev/null | grep -E "^(\[main\]|\[workspace\]|\[project\]|  )" || true
        echo ""
    else
        echo "No active worktrees."
        echo ""
    fi
else
    echo "⚠️ worktree_list.sh not found"
    echo ""
fi

echo "---"
echo ""

#######################################
# SECTION: GITHUB PULL REQUESTS & ISSUES
#######################################

if [ "$SKIP_GITHUB" = false ]; then
    if ! command -v gh &> /dev/null; then
        SECTION=$((SECTION + 1))
        echo "## $SECTION. GitHub Status"
        echo ""
        echo "⚠️ **GitHub CLI (\`gh\`) not found**"
        echo "Install: \`sudo apt install gh\`, then: \`gh auth login\`"
        echo ""
    elif ! gh auth status &> /dev/null; then
        SECTION=$((SECTION + 1))
        echo "## $SECTION. GitHub Status"
        echo ""
        echo "⚠️ **GitHub CLI not authenticated**"
        echo "Run: \`gh auth login\`"
        echo ""
    elif ! command -v jq &> /dev/null; then
        SECTION=$((SECTION + 1))
        echo "## $SECTION. GitHub Status"
        echo ""
        echo "⚠️ **jq not found** (required for GitHub queries)"
        echo "Install: \`sudo apt install jq\`"
        echo ""
    else
        # Build repo list: workspace + project
        REPOS=""
        WS_REMOTE=$(cd "$ROOT_DIR" && git remote get-url origin 2>/dev/null | sed 's|git@github.com:||' | sed 's|https://github.com/||' | sed 's|.git$||' || true)
        [ -n "$WS_REMOTE" ] && REPOS="$WS_REMOTE"

        if [ -d "$PROJECT_DIR" ] && git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
            PROJ_REMOTE=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null | sed 's|git@github.com:||' | sed 's|https://github.com/||' | sed 's|.git$||' || true)
            [ -n "$PROJ_REMOTE" ] && REPOS=$(printf '%s\n%s' "$REPOS" "$PROJ_REMOTE")
        fi
        REPOS=$(echo "$REPOS" | sort -u | grep -v '^$')

        # Pull Requests
        SECTION=$((SECTION + 1))
        echo "## $SECTION. GitHub Pull Requests"
        echo ""

        PR_COUNT=0
        PR_OUTPUT=""
        for repo in $REPOS; do
            [ -z "$repo" ] && continue
            prs=$(gh pr list --repo "$repo" --json number,title,url --limit 100 2>/dev/null || echo "[]")
            if [ -n "$prs" ] && [ "$prs" != "[]" ]; then
                while read -r pr_line; do
                    [ -z "$pr_line" ] && continue
                    number=$(echo "$pr_line" | jq -r '.number')
                    title=$(echo "$pr_line" | jq -r '.title')
                    url=$(echo "$pr_line" | jq -r '.url')
                    [ ${#title} -gt 60 ] && title="${title:0:57}..."
                    repo_name=$(basename "$repo")
                    PR_OUTPUT+="| $repo_name | [#$number]($url) | $title |"$'\n'
                    PR_COUNT=$((PR_COUNT + 1))
                done < <(echo "$prs" | jq -c '.[]' 2>/dev/null)
            fi
        done

        if [ $PR_COUNT -gt 0 ]; then
            echo "| Repository | PR | Title |"
            echo "|------------|-----|-------|"
            printf '%s\n' "$PR_OUTPUT"
            echo "**Total Open PRs**: $PR_COUNT"
        else
            echo "✅ No open pull requests"
        fi
        echo ""

        # Issues
        SECTION=$((SECTION + 1))
        echo "## $SECTION. GitHub Issues"
        echo ""

        ISSUE_COUNT=0
        ISSUE_OUTPUT=""
        for repo in $REPOS; do
            [ -z "$repo" ] && continue
            count=$(gh api -X GET search/issues -f q="repo:$repo is:issue is:open" --jq '.total_count' 2>/dev/null || echo "0")
            [[ "$count" =~ ^[0-9]+$ ]] || count=0
            if [ "$count" -gt 0 ]; then
                repo_name=$(basename "$repo")
                issue_url="https://github.com/$repo/issues"
                ISSUE_OUTPUT+="| [$repo_name]($issue_url) | $count |"$'\n'
                ISSUE_COUNT=$((ISSUE_COUNT + count))
            fi
        done

        if [ ${#ISSUE_OUTPUT} -gt 0 ]; then
            echo "| Repository | Open Issues |"
            echo "|------------|-------------|"
            printf '%s\n' "$ISSUE_OUTPUT"
            echo "**Total Open Issues**: $ISSUE_COUNT"
        else
            echo "✅ No open issues"
        fi
        echo ""
    fi

    echo "---"
    echo ""
fi

#######################################
# DONE
#######################################

echo "✅ **Dashboard complete**"
