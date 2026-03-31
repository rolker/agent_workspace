#!/bin/bash
# .agent/scripts/worktree_create.sh
# Create a git worktree for isolated task development
#
# Usage:
#   ./worktree_create.sh --issue <number> --type workspace|project [--branch <name>] [--plan-file <path>]
#   ./worktree_create.sh --skill <name> --type workspace
#
# Worktree Types:
#   workspace - For infrastructure work (.agent/, docs/, skills/)
#               Created in: worktrees/workspace/issue-<slug>-<N>/
#               Git worktree of the workspace repo
#
#   project   - For changes to the managed project repo
#               Created in: worktrees/project/<repo>/issue-<slug>-<N>/
#               Git worktree of the project/ repo
#               Draft PRs target the project repo (-R <project-remote>)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "$SCRIPT_DIR/_worktree_helpers.sh"

# Try to fetch a specific branch from origin.
fetch_remote_branch() {
    local git_path="$1"
    local branch="$2"
    git -C "$git_path" fetch --quiet origin -- "$branch" 2>/dev/null
}

# Extract a validated owner/repo slug from a GitHub remote URL.
extract_gh_slug() {
    local url="$1"
    local slug
    slug=$(echo "$url" | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')
    if [[ "$slug" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
        echo "$slug"
    fi
}

# Defaults
ISSUE_NUM=""
SKILL_NAME=""
WORKTREE_TYPE=""
BRANCH_NAME=""
REPO_SLUG=""
PLAN_FILE=""
PARENT_ISSUE_NUM=""
WORKFLOW=""

# Skills allowed to create worktrees without a GitHub issue
ALLOWED_SKILLS=("research" "inspiration-tracker")

show_usage() {
    echo "Usage: $0 (--issue <number> | --skill <name>) --type workspace|project [options]"
    echo ""
    echo "Options:"
    echo "  --issue <number>      Issue number (required, unless --skill is used)"
    echo "  --skill <name>        Skill name (alternative to --issue; allowed: ${ALLOWED_SKILLS[*]})"
    echo "  --type <type>         Worktree type: 'workspace' or 'project' (required)"
    echo "  --repo-slug <slug>    Repository slug for naming (auto-detected if not provided)"
    echo "  --branch <name>       Custom branch name (default: feature/issue-<N>)"
    echo "  --parent-issue <N>    Parent issue number; branches from parent's feature branch"
    echo "  --plan-file <path>    Path to approved plan file; creates draft PR"
    echo "  --workflow <name>     Workflow template; initializes progress.md (e.g., collaborative)"
    echo ""
    echo "Examples:"
    echo "  $0 --issue 123 --type workspace"
    echo "  $0 --issue 123 --type project --workflow collaborative"
    echo "  $0 --skill research --type workspace"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --issue)
            ISSUE_NUM="$2"
            shift 2
            ;;
        --skill)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --skill requires a skill name"
                show_usage
                exit 1
            fi
            SKILL_NAME="$2"
            shift 2
            ;;
        --type)
            WORKTREE_TYPE="$2"
            shift 2
            ;;
        --repo-slug)
            REPO_SLUG="$2"
            shift 2
            ;;
        --branch)
            BRANCH_NAME="$2"
            shift 2
            ;;
        --parent-issue)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --parent-issue requires an issue number"
                exit 1
            fi
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --parent-issue value must be a number, got '$2'"
                exit 1
            fi
            PARENT_ISSUE_NUM="$2"
            shift 2
            ;;
        --plan-file)
            PLAN_FILE="$2"
            shift 2
            ;;
        --workflow)
            WORKFLOW="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate --issue XOR --skill
if [ -n "$ISSUE_NUM" ] && [ -n "$SKILL_NAME" ]; then
    echo "Error: --issue and --skill are mutually exclusive"
    exit 1
fi
if [ -z "$ISSUE_NUM" ] && [ -z "$SKILL_NAME" ]; then
    echo "Error: either --issue or --skill is required"
    show_usage
    exit 1
fi
if [ -n "$SKILL_NAME" ] && [ -n "$PARENT_ISSUE_NUM" ]; then
    echo "Error: --parent-issue cannot be used with --skill"
    exit 1
fi

# Validate skill against allowlist
if [ -n "$SKILL_NAME" ]; then
    VALID_SKILL=false
    for allowed in "${ALLOWED_SKILLS[@]}"; do
        if [ "$allowed" == "$SKILL_NAME" ]; then
            VALID_SKILL=true
            break
        fi
    done
    if [ "$VALID_SKILL" = false ]; then
        echo "Error: Skill '$SKILL_NAME' is not in the allowlist"
        echo "Allowed skills: ${ALLOWED_SKILLS[*]}"
        exit 1
    fi
    # Generate synthetic ID with timestamp + collision-resistant suffix
    _SKILL_TS=$(date +"%Y%m%d-%H%M%S")
    _SKILL_NANO=$(date +"%N" 2>/dev/null)
    if [ -z "$_SKILL_NANO" ] || [ "$_SKILL_NANO" = "N" ] || [ "$_SKILL_NANO" = "%N" ]; then
        _SKILL_NANO=$RANDOM
    fi
    SYNTHETIC_ID="${SKILL_NAME}-${_SKILL_TS}-${_SKILL_NANO}"
    unset _SKILL_TS _SKILL_NANO
fi

# Validate worktree type (required)
if [ -z "$WORKTREE_TYPE" ]; then
    echo "Error: --type is required (workspace or project)"
    show_usage
    exit 1
fi
if [ "$WORKTREE_TYPE" != "workspace" ] && [ "$WORKTREE_TYPE" != "project" ]; then
    echo "Error: --type must be 'workspace' or 'project'"
    exit 1
fi

# Validate workflow template if provided
if [ -n "$WORKFLOW" ]; then
    WORKFLOW_FILE="$ROOT_DIR/.agent/workflows/${WORKFLOW}.md"
    if [ ! -f "$WORKFLOW_FILE" ]; then
        echo "Error: Workflow template not found: $WORKFLOW_FILE"
        echo "Available workflows:"
        for wf in "$ROOT_DIR"/.agent/workflows/*.md; do
            [ -f "$wf" ] && [ "$(basename "$wf")" != "README.md" ] && echo "  $(basename "$wf" .md)"
        done
        exit 1
    fi
    if [ -n "$SKILL_NAME" ]; then
        echo "Error: --workflow cannot be used with --skill"
        exit 1
    fi
fi

# For project type, project/ must be configured
if [ "$WORKTREE_TYPE" == "project" ]; then
    PROJECT_DIR="$ROOT_DIR/project"
    if [ ! -d "$PROJECT_DIR" ] || ! git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
        echo "Error: project/ is not configured."
        echo "Run: make setup"
        exit 1
    fi
fi

# --- Auto-detect repo slug ---
if [ -z "$REPO_SLUG" ]; then
    REMOTE_URL=""

    if [ "$WORKTREE_TYPE" == "project" ] && [ -d "$ROOT_DIR/project" ]; then
        REMOTE_URL=$(git -C "$ROOT_DIR/project" remote get-url origin 2>/dev/null || echo "")
    fi

    if [ -z "$REMOTE_URL" ]; then
        REMOTE_URL=$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "")
    fi

    if [ -n "$REMOTE_URL" ]; then
        GH_REPO_SLUG=$(extract_gh_slug "$REMOTE_URL")
        REPO_SLUG=$(basename "$REMOTE_URL" .git)
        # Normalize known workspace repo name
        if [ "$REPO_SLUG" == "agent_workspace" ]; then
            REPO_SLUG="workspace"
        fi
        REPO_SLUG=$(echo "$REPO_SLUG" | sed 's/[^A-Za-z0-9_]/_/g')
    else
        GH_REPO_SLUG=""
        REPO_SLUG="workspace"
    fi
    echo "Auto-detected repository slug: $REPO_SLUG"
else
    # --repo-slug given; still auto-detect GH_REPO_SLUG for gh CLI
    GH_REPO_SLUG=""
    if [ "$WORKTREE_TYPE" == "project" ] && [ -d "$ROOT_DIR/project" ]; then
        _URL=$(git -C "$ROOT_DIR/project" remote get-url origin 2>/dev/null || echo "")
        GH_REPO_SLUG=$(extract_gh_slug "$_URL")
    elif git -C "$ROOT_DIR" remote get-url origin &>/dev/null; then
        _URL=$(git -C "$ROOT_DIR" remote get-url origin)
        GH_REPO_SLUG=$(extract_gh_slug "$_URL")
    fi
    REPO_SLUG=$(echo "$REPO_SLUG" | sed 's/[^A-Za-z0-9_]/_/g')
fi

# --- Determine project GH slug for PR targeting ---
PROJECT_GH_SLUG=""
if [ "$WORKTREE_TYPE" == "project" ] && [ -d "$ROOT_DIR/project" ]; then
    _PROJ_URL=$(git -C "$ROOT_DIR/project" remote get-url origin 2>/dev/null || echo "")
    PROJECT_GH_SLUG=$(extract_gh_slug "$_PROJ_URL")
fi

# --- Validate issue and fetch title ---
ISSUE_TITLE=""
ISSUE_STATE=""
if [ -n "$ISSUE_NUM" ]; then
    # Try git-bug first for issue title and state (offline-capable)
    if command -v git-bug &>/dev/null; then
        _BUG_OUTPUT=$(git -C "$ROOT_DIR" bug select "$ISSUE_NUM" 2>/dev/null \
            && git -C "$ROOT_DIR" bug show 2>/dev/null || echo "")
        if [ -n "$_BUG_OUTPUT" ]; then
            _BUG_TITLE=$(echo "$_BUG_OUTPUT" | head -1 | sed 's/^[^ ]* //')
            _BUG_STATE=$(echo "$_BUG_OUTPUT" | grep -i '^status:' | awk '{print $2}' || echo "")
            if [ -n "$_BUG_TITLE" ]; then
                ISSUE_TITLE="$_BUG_TITLE"
                [[ "${_BUG_STATE,,}" == "closed" ]] && ISSUE_STATE="CLOSED"
                [[ "${_BUG_STATE,,}" == "open" ]] && ISSUE_STATE="OPEN"
            fi
        fi
        git -C "$ROOT_DIR" bug deselect 2>/dev/null || true
    fi

    if command -v gh &>/dev/null; then
        # PR check stays gh-only — git-bug doesn't track PRs
        _PR_CHECK=""
        if [ -n "$GH_REPO_SLUG" ]; then
            _PR_CHECK=$(gh pr view "$ISSUE_NUM" --repo "$GH_REPO_SLUG" --json state --jq '.state' 2>/dev/null || echo "")
        else
            _PR_CHECK=$(gh pr view "$ISSUE_NUM" --json state --jq '.state' 2>/dev/null || echo "")
        fi
        if [ -n "$_PR_CHECK" ]; then
            echo "Error: #$ISSUE_NUM is a pull request, not an issue."
            echo "Use the original issue number instead."
            exit 1
        fi

        # Fall back to gh for title/state individually if git-bug didn't provide them
        if [ -z "$ISSUE_TITLE" ] || [ -z "$ISSUE_STATE" ]; then
            if [ -n "$GH_REPO_SLUG" ]; then
                _ISSUE_INFO=$(gh issue view "$ISSUE_NUM" --repo "$GH_REPO_SLUG" --json title,state --jq '.title + "||" + .state' 2>/dev/null || echo "")
            else
                _ISSUE_INFO=$(gh issue view "$ISSUE_NUM" --json title,state --jq '.title + "||" + .state' 2>/dev/null || echo "")
            fi
            if [[ "$_ISSUE_INFO" == *"||"* ]]; then
                [ -z "$ISSUE_TITLE" ] && ISSUE_TITLE="${_ISSUE_INFO%||*}"
                [ -z "$ISSUE_STATE" ] && ISSUE_STATE="${_ISSUE_INFO##*||}"
            fi
        fi
    fi

    if [ -n "$ISSUE_TITLE" ]; then
        echo "Issue #$ISSUE_NUM: $ISSUE_TITLE"
        if [ "$ISSUE_STATE" = "CLOSED" ]; then
            echo "   ⚠️  Warning: Issue #$ISSUE_NUM is CLOSED"
        fi
    else
        echo "⚠️  Could not fetch issue #$ISSUE_NUM title (offline or issue does not exist)"
        echo "   Proceeding anyway — verify the issue number is correct."
    fi
else
    echo "Skill worktree: $SKILL_NAME (ID: $SYNTHETIC_ID)"
fi
echo ""

# --- Set default branch name ---
if [ -z "$BRANCH_NAME" ]; then
    if [ -n "$SKILL_NAME" ]; then
        BRANCH_NAME="skill/${SYNTHETIC_ID}"
    else
        BRANCH_NAME="feature/issue-${ISSUE_NUM}"
    fi
fi

# Derive parent branch name
PARENT_BRANCH=""
if [ -n "$PARENT_ISSUE_NUM" ]; then
    PARENT_BRANCH="feature/issue-${PARENT_ISSUE_NUM}"
fi

# --- Determine worktree path ---
if [ -n "$SKILL_NAME" ]; then
    DIR_PREFIX="skill-${REPO_SLUG}-${SYNTHETIC_ID}"
else
    DIR_PREFIX="issue-${REPO_SLUG}-${ISSUE_NUM}"
fi

if [ "$WORKTREE_TYPE" == "project" ]; then
    WORKTREE_DIR="$(wt_project_base "$ROOT_DIR" "$REPO_SLUG")/${DIR_PREFIX}"
else
    WORKTREE_DIR="$(wt_workspace_base "$ROOT_DIR")/${DIR_PREFIX}"
fi

# Check if worktree already exists
if [ -d "$WORKTREE_DIR" ]; then
    echo "Error: Worktree already exists at $WORKTREE_DIR"
    if [ -n "$SKILL_NAME" ]; then
        echo "Use 'worktree_enter.sh --skill $SKILL_NAME --type $WORKTREE_TYPE' to enter it"
        echo "Or  'worktree_remove.sh --skill $SKILL_NAME --type $WORKTREE_TYPE' to remove it"
    else
        echo "Use 'worktree_enter.sh --issue $ISSUE_NUM --type $WORKTREE_TYPE' to enter it"
        echo "Or  'worktree_remove.sh --issue $ISSUE_NUM --type $WORKTREE_TYPE' to remove it"
    fi
    exit 1
fi

cd "$ROOT_DIR"

echo "========================================"
echo "Creating Worktree"
echo "========================================"
if [ -n "$SKILL_NAME" ]; then
    echo "  Skill:      $SKILL_NAME"
    echo "  ID:         $SYNTHETIC_ID"
else
    echo "  Issue:      #$ISSUE_NUM"
fi
echo "  Repository: $REPO_SLUG"
echo "  Type:       $WORKTREE_TYPE"
echo "  Branch:     $BRANCH_NAME"
[ -n "$PARENT_BRANCH" ] && echo "  Parent:     #$PARENT_ISSUE_NUM ($PARENT_BRANCH)"
echo "  Path:       $WORKTREE_DIR"
echo ""

mkdir -p "$(dirname "$WORKTREE_DIR")"

# Track whether parent branch was used
PARENT_BRANCH_FOUND=false

# --- Create the worktree ---
if [ "$WORKTREE_TYPE" == "project" ]; then
    # Project worktrees are git worktrees of the project repo
    if git -C "$ROOT_DIR/project" show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        echo "Using existing local branch '$BRANCH_NAME'..."
        git -C "$ROOT_DIR/project" worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
    elif fetch_remote_branch "$ROOT_DIR/project" "$BRANCH_NAME"; then
        echo "Tracking remote branch 'origin/$BRANCH_NAME'..."
        git -C "$ROOT_DIR/project" worktree add --track -b "$BRANCH_NAME" "$WORKTREE_DIR" "origin/$BRANCH_NAME"
    elif [ -n "$PARENT_BRANCH" ]; then
        if git -C "$ROOT_DIR/project" show-ref --verify --quiet "refs/heads/$PARENT_BRANCH"; then
            echo "Creating new branch '$BRANCH_NAME' from parent branch '$PARENT_BRANCH'..."
            git -C "$ROOT_DIR/project" worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR" "$PARENT_BRANCH"
            PARENT_BRANCH_FOUND=true
        elif fetch_remote_branch "$ROOT_DIR/project" "$PARENT_BRANCH"; then
            echo "Creating new branch '$BRANCH_NAME' from parent branch 'origin/$PARENT_BRANCH'..."
            git -C "$ROOT_DIR/project" worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR" "origin/$PARENT_BRANCH"
            PARENT_BRANCH_FOUND=true
        else
            echo "⚠️  Parent branch '$PARENT_BRANCH' not found; falling back to HEAD"
            git -C "$ROOT_DIR/project" worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR"
        fi
    else
        echo "Creating new branch '$BRANCH_NAME' from current HEAD..."
        git -C "$ROOT_DIR/project" worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR"
    fi

    # Check parent branch exists for PR targeting
    if [ -n "$PARENT_BRANCH" ] && [ "$PARENT_BRANCH_FOUND" = false ]; then
        if git -C "$ROOT_DIR/project" show-ref --verify --quiet "refs/heads/$PARENT_BRANCH" || \
           git -C "$ROOT_DIR/project" show-ref --verify --quiet "refs/remotes/origin/$PARENT_BRANCH"; then
            PARENT_BRANCH_FOUND=true
        elif fetch_remote_branch "$ROOT_DIR/project" "$PARENT_BRANCH" && \
             git -C "$ROOT_DIR/project" show-ref --verify --quiet "refs/remotes/origin/$PARENT_BRANCH"; then
            PARENT_BRANCH_FOUND=true
        fi
    fi

else
    # Workspace worktrees are git worktrees of the workspace repo
    if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        echo "Using existing local branch '$BRANCH_NAME'..."
        git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
    elif fetch_remote_branch "$ROOT_DIR" "$BRANCH_NAME"; then
        echo "Tracking remote branch 'origin/$BRANCH_NAME'..."
        git worktree add --track -b "$BRANCH_NAME" "$WORKTREE_DIR" "origin/$BRANCH_NAME"
    elif [ -n "$PARENT_BRANCH" ]; then
        if git show-ref --verify --quiet "refs/heads/$PARENT_BRANCH"; then
            echo "Creating new branch '$BRANCH_NAME' from parent branch '$PARENT_BRANCH'..."
            git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR" "$PARENT_BRANCH"
            PARENT_BRANCH_FOUND=true
        elif fetch_remote_branch "$ROOT_DIR" "$PARENT_BRANCH"; then
            echo "Creating new branch '$BRANCH_NAME' from parent branch 'origin/$PARENT_BRANCH'..."
            git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR" "origin/$PARENT_BRANCH"
            PARENT_BRANCH_FOUND=true
        else
            echo "⚠️  Parent branch '$PARENT_BRANCH' not found; falling back to HEAD"
            git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR"
        fi
    else
        echo "Creating new branch '$BRANCH_NAME' from current HEAD..."
        git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR"
    fi

    if [ -n "$PARENT_BRANCH" ] && [ "$PARENT_BRANCH_FOUND" = false ]; then
        if git show-ref --verify --quiet "refs/heads/$PARENT_BRANCH" || \
           git show-ref --verify --quiet "refs/remotes/origin/$PARENT_BRANCH"; then
            PARENT_BRANCH_FOUND=true
        elif fetch_remote_branch "$ROOT_DIR" "$PARENT_BRANCH" && \
             git show-ref --verify --quiet "refs/remotes/origin/$PARENT_BRANCH"; then
            PARENT_BRANCH_FOUND=true
        fi
    fi
fi

# --- Set up worktree structure ---
echo ""
echo "Setting up worktree..."

# Ensure scratchpad exists
mkdir -p "$WORKTREE_DIR/.agent/scratchpad"

# Persist parent issue for worktree_enter.sh
if [ -n "$PARENT_ISSUE_NUM" ]; then
    echo "$PARENT_ISSUE_NUM" > "$WORKTREE_DIR/.agent/scratchpad/.parent_issue"
fi

# Initialize progress.md if --workflow was provided
if [ -n "$WORKFLOW" ] && [ -n "$ISSUE_NUM" ]; then
    PROGRESS_DIR="$WORKTREE_DIR/.agent/work-plans/issue-${ISSUE_NUM}"
    mkdir -p "$PROGRESS_DIR"
    PROGRESS_FILE="$PROGRESS_DIR/progress.md"
    _PROGRESS_TITLE="${ISSUE_TITLE:-Issue #$ISSUE_NUM}"
    cat > "$PROGRESS_FILE" << PROGRESS_EOF
---
workflow: $WORKFLOW
issue: $ISSUE_NUM
---

# Issue #$ISSUE_NUM — $_PROGRESS_TITLE
PROGRESS_EOF
    echo "Initialized progress.md (workflow: $WORKFLOW)"
fi

echo ""
echo "========================================"
echo "✅ Worktree Created Successfully"
echo "========================================"
if [ -n "$SKILL_NAME" ]; then
    echo "  Skill: $SKILL_NAME (ID: $SYNTHETIC_ID)"
elif [ -n "$ISSUE_TITLE" ]; then
    echo "  Issue #$ISSUE_NUM: $ISSUE_TITLE"
fi
[ -n "$PARENT_BRANCH" ] && echo "  Parent: #$PARENT_ISSUE_NUM ($PARENT_BRANCH)"
[ -n "$WORKFLOW" ] && echo "  Workflow: $WORKFLOW"
echo ""

# --- Create draft PR if --plan-file given ---
if [ -n "$PLAN_FILE" ]; then
    echo "Creating draft PR for issue #${ISSUE_NUM:-${SKILL_NAME}}..."
    echo ""

    if [ -n "$SKILL_NAME" ]; then
        ISSUE_TITLE="Skill update: $SKILL_NAME"
    elif [ -z "$ISSUE_TITLE" ]; then
        echo "  ⚠️  Could not fetch issue title; using generic title"
        ISSUE_TITLE="Issue #$ISSUE_NUM"
    fi

    HAS_PLAN=false
    if [ ! -f "$PLAN_FILE" ]; then
        echo "  ⚠️  Plan file not found: $PLAN_FILE (creating PR without plan comment)"
    else
        HAS_PLAN=true
    fi

    # Auto-detect agent identity
    if [ -z "${AGENT_NAME:-}" ] || [ -z "${AGENT_MODEL:-}" ]; then
        if [ -f "$SCRIPT_DIR/framework_config.sh" ]; then
            # shellcheck source=/dev/null
            source "$SCRIPT_DIR/framework_config.sh"
        fi
        if [ -f "$SCRIPT_DIR/detect_cli_env.sh" ]; then
            # shellcheck source=/dev/null
            source "$SCRIPT_DIR/detect_cli_env.sh" || true
        fi
        if [ -n "${AGENT_FRAMEWORK:-}" ] && [ "$AGENT_FRAMEWORK" != "unknown" ]; then
            FRAMEWORK_KEY="${AGENT_FRAMEWORK%-cli}"
            FRAMEWORK_KEY="${FRAMEWORK_KEY,,}"
            : "${AGENT_NAME:=${FRAMEWORK_NAMES[$FRAMEWORK_KEY]:-AI Agent}}"
            : "${AGENT_MODEL:=${FRAMEWORK_MODELS[$FRAMEWORK_KEY]:-Unknown}}"
        fi
    fi
    DRAFT_AGENT_NAME="${AGENT_NAME:-AI Agent}"
    DRAFT_AGENT_MODEL="${AGENT_MODEL:-Unknown}"

    create_draft_pr() {
        local git_dir="$1"
        local issue_ref="$2"
        local repo_flag="${3:-}"
        local base_flag="${4:-}"

        cd "$git_dir"

        # Push branch
        if ! git rev-parse --verify "origin/$BRANCH_NAME" &>/dev/null; then
            if [ -n "$issue_ref" ]; then
                git commit --allow-empty -m "chore: start work on $issue_ref" || true
            else
                git commit --allow-empty -m "chore: start skill update ($SKILL_NAME)" || true
            fi
        fi
        if ! git push -u origin "$BRANCH_NAME" 2>/dev/null; then
            echo "  ⚠️  Push failed — skipping draft PR (non-fatal)"
            return 1
        fi

        # Check for existing PR
        local existing_pr=""
        if [ -n "$repo_flag" ]; then
            existing_pr=$(gh pr list --repo "$repo_flag" --head "$BRANCH_NAME" --json url --jq '.[0].url' 2>/dev/null || echo "")
        else
            existing_pr=$(gh pr list --head "$BRANCH_NAME" --json url --jq '.[0].url' 2>/dev/null || echo "")
        fi
        if [ -n "$existing_pr" ]; then
            echo "  ℹ PR already exists: $existing_pr"
            if [ "$HAS_PLAN" = true ]; then
                gh pr comment "$existing_pr" --body-file "$PLAN_FILE" >/dev/null 2>&1 && \
                    echo "  ✓ Plan posted as comment on existing PR"
            fi
            return 0
        fi

        # Create draft PR body
        BODY_FILE=$(mktemp /tmp/gh_body.XXXXXX.md)
        if [ -n "$SKILL_NAME" ]; then
            cat > "$BODY_FILE" << PREOF
## Summary

$ISSUE_TITLE

Automated update from the \`$SKILL_NAME\` skill.

---
**Authored-By**: \`${DRAFT_AGENT_NAME}\`
**Model**: \`${DRAFT_AGENT_MODEL}\`
PREOF
        else
            cat > "$BODY_FILE" << PREOF
## Summary

$ISSUE_TITLE

Closes $issue_ref
PREOF
            if [ -n "$PARENT_ISSUE_NUM" ]; then
                echo "Part of #${PARENT_ISSUE_NUM}" >> "$BODY_FILE"
            fi
            cat >> "$BODY_FILE" << PREOF

---
**Authored-By**: \`${DRAFT_AGENT_NAME}\`
**Model**: \`${DRAFT_AGENT_MODEL}\`
PREOF
        fi

        local pr_title="$ISSUE_TITLE"
        if [ -n "$PLAN_FILE" ]; then
            pr_title="[PLAN] $ISSUE_TITLE"
        fi

        local gh_args=(pr create --draft --title "$pr_title" --body-file "$BODY_FILE")
        [ -n "$repo_flag" ] && gh_args+=(--repo "$repo_flag")
        [ -n "$base_flag" ] && gh_args+=(--base "$base_flag")

        GH_STDERR=$(mktemp /tmp/gh_stderr.XXXXXX)
        local pr_url
        pr_url=$(gh "${gh_args[@]}" 2>"$GH_STDERR") && PR_CREATED=true || PR_CREATED=false

        if [ "$PR_CREATED" = true ]; then
            echo "  ✓ Draft PR created: $pr_url"
            if [ "$HAS_PLAN" = true ]; then
                gh pr comment "$pr_url" --body-file "$PLAN_FILE" >/dev/null 2>&1 && \
                    echo "  ✓ Plan posted as PR comment" || \
                    echo "  ⚠️  Failed to post plan comment (non-fatal)"
            fi
        else
            echo "  ⚠️  Draft PR creation failed (non-fatal)"
            cat "$GH_STDERR" >&2
        fi
        rm -f "$GH_STDERR" "$BODY_FILE"
    }

    PR_PARENT_BASE=""
    if [ "$PARENT_BRANCH_FOUND" = true ]; then
        PR_PARENT_BASE="$PARENT_BRANCH"
    fi

    if [ "$WORKTREE_TYPE" == "workspace" ]; then
        if [ -n "$SKILL_NAME" ]; then
            create_draft_pr "$WORKTREE_DIR" ""
        else
            create_draft_pr "$WORKTREE_DIR" "#$ISSUE_NUM" "" "$PR_PARENT_BASE"
        fi
    elif [ "$WORKTREE_TYPE" == "project" ]; then
        if [ -n "$SKILL_NAME" ]; then
            create_draft_pr "$WORKTREE_DIR" "" "$PROJECT_GH_SLUG"
        else
            create_draft_pr "$WORKTREE_DIR" "#$ISSUE_NUM" "$PROJECT_GH_SLUG" "$PR_PARENT_BASE"
        fi
    fi
    cd "$ROOT_DIR"

    echo ""
fi

# --- Next steps ---
if [ -n "$SKILL_NAME" ]; then
    echo "To enter this worktree:"
    echo "  source $SCRIPT_DIR/worktree_enter.sh --skill $SKILL_NAME --type $WORKTREE_TYPE"
    echo ""
    echo "When done, remove with:"
    echo "  $SCRIPT_DIR/worktree_remove.sh --skill $SKILL_NAME --type $WORKTREE_TYPE"
else
    echo "To enter this worktree:"
    echo "  source $SCRIPT_DIR/worktree_enter.sh --issue $ISSUE_NUM --type $WORKTREE_TYPE"
    echo ""
    echo "When done, remove with:"
    echo "  $SCRIPT_DIR/worktree_remove.sh --issue $ISSUE_NUM --type $WORKTREE_TYPE"
fi
echo ""
