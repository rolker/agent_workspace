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
#   project   - For changes to a project repo
#               Created in: <registered root>/worktrees/issue-<slug>-<N>/
#               (or, for an unregistered project — legacy project/ symlink
#               only — the transition fallback
#               worktrees/project/<repo>/issue-<slug>-<N>/, #265)
#               Git worktree of the project repo
#               Draft PRs target the project repo (-R <project-remote>)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "$SCRIPT_DIR/_worktree_helpers.sh"
source "$SCRIPT_DIR/_issue_helpers.sh"
source "$SCRIPT_DIR/_project_registry.sh"

# ---------------------------------------------------- user-tier guard (#265) ---
# This script is promoted to the user tier (.agent/user_tier_scripts.txt), so
# it can be invoked from any cwd on the machine. Refuse outside the workspace
# checkout and outside every registered project root, BEFORE any git/gh call,
# so a stray invocation in an unrelated repo touches nothing. See
# docs/decisions/0016-session-roots-and-the-user-tier.md.
registry_require_root "$ROOT_DIR" || exit 1

# ADR-0012: a package worktree names its layer and package repos
# explicitly; --issue must then be the qualified owner/repo#N form so
# worktree_repos can tell the issue's own repo from its siblings.
LAYER=""
PACKAGE_REPOS=""

# Try to fetch a specific branch from origin.
fetch_remote_branch() {
    local git_path="$1"
    local branch="$2"
    git -C "$git_path" fetch --quiet origin -- "$branch" 2>/dev/null
}

# extract_gh_slug is provided by _issue_helpers.sh (sourced above)

# Defaults
ISSUE_NUM=""
SKILL_NAME=""
WORKTREE_TYPE=""
BRANCH_NAME=""
REPO_SLUG=""
PROJECT_REPO=""
PLAN_FILE=""
PARENT_ISSUE_NUM=""
WORKFLOW=""
PRINT_PATH_ONLY=false

# Pre-scan for --print-path-only so quiet-mode redirection activates BEFORE
# the main argument parser runs. Without this, parse-time errors (unknown
# flag, missing required value) would leak to stdout and pollute the path
# channel. The flag is still consumed by the main parse loop below — this
# pre-scan only handles the redirect side-effect.
for _arg in "$@"; do
    if [ "$_arg" = "--print-path-only" ]; then
        PRINT_PATH_ONLY=true
        exec 3>&1
        exec 1>&2
        break
    fi
done
unset _arg

# Skills allowed to create worktrees without a GitHub issue
ALLOWED_SKILLS=("research" "inspiration-tracker")

show_usage() {
    echo "Usage: $0 (--issue <number> | --skill <name>) --type workspace|project [options]"
    echo ""
    echo "Options:"
    echo "  --issue <number>      Issue number (required, unless --skill is used)"
    echo "  --skill <name>        Skill name (alternative to --issue; allowed: ${ALLOWED_SKILLS[*]})"
    echo "  --type <type>         Worktree type: 'workspace' or 'project' (required)"
    echo "  --project <name>      Registered project name from .agent/projects.local (alias: --repo)"
    echo "                        (--type project only; default: legacy project/, or the"
    echo "                        single registered project when project/ is absent)"
    echo "  --repo-slug <slug>    Repository slug for naming (auto-detected if not provided)"
    echo "  --layer <name>        Layer to worktree (ros2_colcon package worktrees; requires"
    echo "                        --package-repos and a qualified --issue owner/repo#N)"
    echo "  --package-repos <a,b> Comma-separated package-repo directory names to worktree"
    echo "                        (requires --layer)"
    echo "  --branch <name>       Custom branch name (default: feature/issue-<N>)"
    echo "  --parent-issue <N>    Parent issue number; branches from parent's feature branch"
    echo "  --plan-file <path>    Path to approved plan file; creates draft PR"
    echo "  --workflow <name>     Workflow template; initializes progress.md (e.g., collaborative)"
    echo "  --print-path-only     Suppress all stdout except the final worktree path on success"
    echo "                        (errors go to stderr; exit code reflects success/failure)"
    echo ""
    echo "Examples:"
    echo "  $0 --issue 123 --type workspace"
    echo "  $0 --issue 123 --type project --workflow collaborative"
    echo "  $0 --skill research --type workspace"
    echo "  WT=\$($0 --issue 123 --type workspace --print-path-only)"
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
        --project|--repo)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --project requires a project name"
                show_usage
                exit 1
            fi
            PROJECT_REPO="$2"
            shift 2
            ;;
        --repo-slug)
            REPO_SLUG="$2"
            shift 2
            ;;
        --layer)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --layer requires a layer name"
                exit 1
            fi
            LAYER="$2"
            shift 2
            ;;
        --package-repos)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --package-repos requires a comma-separated list of repo names"
                exit 1
            fi
            PACKAGE_REPOS="$2"
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
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --workflow requires a workflow name"
                show_usage
                exit 1
            fi
            WORKFLOW="$2"
            shift 2
            ;;
        --print-path-only)
            PRINT_PATH_ONLY=true
            shift
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

# (Quiet-mode redirect was set up by the pre-scan above, before parsing.)

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
if [ "$WORKTREE_TYPE" = "layer" ]; then
    echo "Error: --type layer no longer exists."
    echo "Use: --type project --layer <name> --package-repos <a,b> --issue owner/repo#N"
    exit 1
fi
if [ "$WORKTREE_TYPE" != "workspace" ] && [ "$WORKTREE_TYPE" != "project" ]; then
    echo "Error: --type must be 'workspace' or 'project'"
    exit 1
fi

# --- Qualified --issue (owner/repo#N), and --layer/--package-repos gating ---
# ADR-0012: nothing about a package worktree is inferred. A qualified
# --issue is required whenever --layer/--package-repos are used (so
# worktree_repos can tell the issue's own repo from its siblings); a bare
# number is otherwise accepted unchanged (workspace worktrees, legacy
# single-repo project worktrees).
ISSUE_REF="$ISSUE_NUM"
ISSUE_OWNER_REPO=""
if [ -n "$ISSUE_NUM" ] && [[ "$ISSUE_NUM" == *#* ]]; then
    if [[ "$ISSUE_NUM" =~ ^([^/#]+/[^/#]+)#([0-9]+)$ ]]; then
        ISSUE_OWNER_REPO="${BASH_REMATCH[1]}"
        ISSUE_REF="$ISSUE_NUM"
        ISSUE_NUM="${BASH_REMATCH[2]}"
    else
        echo "Error: qualified --issue must be owner/repo#N, got '$ISSUE_NUM'"
        exit 1
    fi
fi
if [ -n "$LAYER" ] || [ -n "$PACKAGE_REPOS" ]; then
    if [ "$WORKTREE_TYPE" != "project" ]; then
        echo "Error: --layer/--package-repos are only valid with --type project"
        exit 1
    fi
    if [ -z "$LAYER" ] || [ -z "$PACKAGE_REPOS" ]; then
        echo "Error: --layer and --package-repos must be given together"
        exit 1
    fi
    if [ -z "$ISSUE_OWNER_REPO" ]; then
        echo "Error: --layer/--package-repos require a qualified --issue owner/repo#N"
        exit 1
    fi
fi

# Validate workflow template if provided
if [ -n "$WORKFLOW" ]; then
    if [ -n "$SKILL_NAME" ]; then
        echo "Error: --workflow cannot be used with --skill"
        exit 1
    fi
    if ! [[ "$WORKFLOW" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        echo "Error: Invalid workflow name '$WORKFLOW' — must match [a-z0-9][a-z0-9_-]*"
        exit 1
    fi
    WORKFLOW_FILE="$ROOT_DIR/.agent/workflows/${WORKFLOW}.md"
    if [ ! -f "$WORKFLOW_FILE" ]; then
        echo "Error: Workflow template not found: $WORKFLOW_FILE"
        echo "Available workflows:"
        for wf in "$ROOT_DIR"/.agent/workflows/*.md; do
            [ -f "$wf" ] && [ "$(basename "$wf")" != "README.md" ] && echo "  $(basename "$wf" .md)"
        done
        exit 1
    fi
fi

if [ -n "$PROJECT_REPO" ] && [ "$WORKTREE_TYPE" != "project" ]; then
    echo "Error: --project is only valid with --type project"
    exit 1
fi

# For project type, resolve the project checkout: an explicit --project name
# from the registry, the legacy project/ symlink, or — when project/ is
# absent — the single registered project (issue #227).
PROJECT_NAME=""
if [ "$WORKTREE_TYPE" == "project" ]; then
    PROJECT_DIR=""
    if [ -n "$PROJECT_REPO" ]; then
        # --project (alias: --repo)
        _RC=0
        _ENTRY="$(registry_lookup "$ROOT_DIR" "$PROJECT_REPO")" || _RC=$?
        if [ "$_RC" -ne 0 ]; then
            if [ "$_RC" -eq 1 ]; then
                echo "Error: project '$PROJECT_REPO' is not registered in $(registry_file "$ROOT_DIR")"
                _NAMES="$(registry_names "$ROOT_DIR" 2>/dev/null || true)"
                if [ -n "$_NAMES" ]; then
                    echo "Registered projects:"
                    sed 's/^/  /' <<< "$_NAMES"
                else
                    echo "  (no projects registered — see .agent/projects.local.example)"
                fi
            fi
            exit 1
        fi
        PROJECT_NAME="$PROJECT_REPO"
        PROJECT_DIR="$(cut -f2 <<< "$_ENTRY")"
        # A parent root (#265): use its default_instance / only instance —
        # the same resolution enter/remove apply, so the round trip holds.
        if [ "$(cut -f1 <<< "$_ENTRY")" = "$REGISTRY_PARENT_TYPE" ]; then
            PROJECT_NAME="$(registry_resolve_project_arg "$ROOT_DIR" "$PROJECT_REPO")" || exit 1
            _ENTRY="$(registry_lookup "$ROOT_DIR" "$PROJECT_NAME")" || exit 1
            PROJECT_DIR="$(cut -f2 <<< "$_ENTRY")"
            echo "Using instance '$PROJECT_NAME' of '$PROJECT_REPO' ($PROJECT_DIR)"
        fi
    elif [ -d "$ROOT_DIR/project" ] && git -C "$ROOT_DIR/project" rev-parse --git-dir &>/dev/null; then
        PROJECT_DIR="$ROOT_DIR/project"
    else
        # No legacy project/ — fall back to the registry (parent roots are
        # not candidates: their instances are, #265).
        _ENTRIES="$(registry_entries "$ROOT_DIR")" || exit 1
        [ -n "$_ENTRIES" ] && _ENTRIES="$(awk -F'\t' -v p="$REGISTRY_PARENT_TYPE" '$2 != p' <<< "$_ENTRIES")"
        _COUNT=0
        [ -n "$_ENTRIES" ] && _COUNT="$(wc -l <<< "$_ENTRIES")"
        if [ "$_COUNT" -eq 1 ]; then
            PROJECT_NAME="$(cut -f1 <<< "$_ENTRIES")"
            PROJECT_DIR="$(cut -f3 <<< "$_ENTRIES")"
            echo "Using registered project '$PROJECT_NAME' ($PROJECT_DIR)"
        elif [ "$_COUNT" -gt 1 ]; then
            echo "Error: Multiple projects registered. Use --project to specify:"
            cut -f1 <<< "$_ENTRIES" | sed 's/^/  --project /'
            exit 1
        else
            echo "Error: project/ is not configured."
            echo "Run: make setup  (or register a project in .agent/projects.local)"
            exit 1
        fi
    fi
    if [ ! -d "$PROJECT_DIR" ] || ! git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
        echo "Error: project checkout is not a git repository: $PROJECT_DIR"
        [ -n "$PROJECT_NAME" ] && echo "Clone the project there or fix .agent/projects.local"
        exit 1
    fi
fi

# --- Auto-detect repo slug ---
if [ -z "$REPO_SLUG" ]; then
    REMOTE_URL=""

    if [ "$WORKTREE_TYPE" == "project" ] && [ -d "$PROJECT_DIR" ]; then
        REMOTE_URL=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo "")
    fi

    if [ -n "$PROJECT_NAME" ]; then
        # Registry-selected project: the registry name is the worktree repo
        # key (worktrees/project/<name>/ — matches enter/remove --project), so
        # it must be used raw. Its charset is validated by the registry
        # parser and is a subset of what wt_project_base accepts; sanitizing
        # '.'/'-' to '_' here would break enter/remove --project <name> lookup.
        GH_REPO_SLUG=$(extract_gh_slug "$REMOTE_URL")
        REPO_SLUG="$PROJECT_NAME"
    else
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
    fi
    echo "Auto-detected repository slug: $REPO_SLUG"
else
    # --repo-slug given; still auto-detect GH_REPO_SLUG for gh CLI
    GH_REPO_SLUG=""
    if [ "$WORKTREE_TYPE" == "project" ] && [ -d "$PROJECT_DIR" ]; then
        _URL=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo "")
        GH_REPO_SLUG=$(extract_gh_slug "$_URL")
    elif git -C "$ROOT_DIR" remote get-url origin &>/dev/null; then
        _URL=$(git -C "$ROOT_DIR" remote get-url origin)
        GH_REPO_SLUG=$(extract_gh_slug "$_URL")
    fi
    REPO_SLUG=$(echo "$REPO_SLUG" | sed 's/[^A-Za-z0-9_]/_/g')
fi

# --- Determine project GH slug for PR targeting ---
PROJECT_GH_SLUG=""
if [ "$WORKTREE_TYPE" == "project" ] && [ -d "$PROJECT_DIR" ]; then
    _PROJ_URL=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo "")
    PROJECT_GH_SLUG=$(extract_gh_slug "$_PROJ_URL")
fi

# --- Validate issue and fetch title ---
ISSUE_TITLE=""
ISSUE_STATE=""
# Display form for messages: the qualified ref when --issue was qualified,
# else the bare number (unchanged from before ADR-0012).
if [ -n "$ISSUE_OWNER_REPO" ]; then
    ISSUE_DISPLAY_REF="${ISSUE_OWNER_REPO}#${ISSUE_NUM}"
else
    ISSUE_DISPLAY_REF="#${ISSUE_NUM}"
fi
if [ -n "$ISSUE_NUM" ]; then
    # A qualified --issue owner/repo#N names its own repo explicitly — the
    # lookup, the PR-not-issue check, and any error/status message must all
    # target that repo, never the workspace remote or an auto-detected
    # GH_REPO_SLUG (which is the *project*'s repo, not necessarily the
    # issue's — e.g. a package worktree's owning repo can differ from the
    # registered project's own remote).
    if [ -n "$ISSUE_OWNER_REPO" ]; then
        _LOOKUP_REPO="$ISSUE_OWNER_REPO"
    else
        # Look up issue via git-bug (with sync-on-miss) then gh fallback
        _LOOKUP_REPO="${GH_REPO_SLUG:-}"
        if [ -z "$_LOOKUP_REPO" ]; then
            # Best-effort: extract from workspace remote
            _WS_URL=$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || echo "")
            _LOOKUP_REPO=$(extract_gh_slug "$_WS_URL")
        fi
    fi
    if [ -n "$_LOOKUP_REPO" ]; then
        issue_lookup "$ISSUE_NUM" --repo "$_LOOKUP_REPO" --root "$ROOT_DIR" || true
    fi
    # Fallback: if slug extraction failed (non-GitHub remote), try gh without --repo
    if [ -z "$ISSUE_TITLE" ] && [ -z "$_LOOKUP_REPO" ] && command -v gh &>/dev/null; then
        ISSUE_TITLE=$(gh issue view "$ISSUE_NUM" --json title --jq '.title' 2>/dev/null || echo "")
        ISSUE_STATE=$(gh issue view "$ISSUE_NUM" --json state --jq '.state' 2>/dev/null || echo "")
    fi

    # PR check stays gh-only — git-bug doesn't track PRs. Same repo as the
    # lookup above: the qualified ref's own repo, or the fallback chain.
    if command -v gh &>/dev/null; then
        _PR_CHECK=""
        if [ -n "$_LOOKUP_REPO" ]; then
            _PR_CHECK=$(gh pr view "$ISSUE_NUM" --repo "$_LOOKUP_REPO" --json state --jq '.state' 2>/dev/null || echo "")
        else
            _PR_CHECK=$(gh pr view "$ISSUE_NUM" --json state --jq '.state' 2>/dev/null || echo "")
        fi
        if [ -n "$_PR_CHECK" ]; then
            echo "Error: $ISSUE_DISPLAY_REF is a pull request, not an issue."
            echo "Use the original issue number instead."
            exit 1
        fi
    fi

    if [ -n "$ISSUE_TITLE" ]; then
        echo "Issue $ISSUE_DISPLAY_REF: $ISSUE_TITLE"
        if [ "$ISSUE_STATE" = "CLOSED" ]; then
            echo "   ⚠️  Warning: Issue $ISSUE_DISPLAY_REF is CLOSED"
        fi
    else
        echo "⚠️  Could not fetch issue $ISSUE_DISPLAY_REF title (offline or issue does not exist)"
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

# --- Resolve the worktree repo manifest (ADR-0012, --type project only) ---
# worktree_repos is the single source of truth for which repos compose the
# worktree and what to name their branches — this script never decides
# that itself, and never checks the project type.
REPO_LINES=""
if [ "$WORKTREE_TYPE" == "project" ]; then
    WR_ADAPTER_ARGS=()
    [ -n "$PROJECT_NAME" ] && WR_ADAPTER_ARGS+=(--project "$PROJECT_NAME")
    WR_VERB_ARGS=(--issue "$ISSUE_REF")
    [ -n "$LAYER" ] && WR_VERB_ARGS+=(--layer "$LAYER")
    [ -n "$PACKAGE_REPOS" ] && WR_VERB_ARGS+=(--package-repos "$PACKAGE_REPOS")
    if ! REPO_LINES="$("$SCRIPT_DIR/adapter" "${WR_ADAPTER_ARGS[@]}" worktree_repos "${WR_VERB_ARGS[@]}")"; then
        exit 1
    fi
    if [ -z "$REPO_LINES" ]; then
        echo "Error: worktree_repos returned no repos to worktree"
        exit 1
    fi
fi

# --- Determine worktree path ---
if [ -n "$SKILL_NAME" ]; then
    DIR_PREFIX="skill-${REPO_SLUG}-${SYNTHETIC_ID}"
elif [ -n "$LAYER" ]; then
    # Package worktree: the directory name carries the qualified issue for
    # human legibility only — every script that needs project/issue/layer
    # reads the .worktree-repos header instead of parsing this name.
    DIR_PREFIX="issue-${REPO_SLUG}-${ISSUE_OWNER_REPO/\//-}-${ISSUE_NUM}"
else
    DIR_PREFIX="issue-${REPO_SLUG}-${ISSUE_NUM}"
fi

if [ "$WORKTREE_TYPE" == "project" ]; then
    if [ -n "$PROJECT_NAME" ]; then
        # Registry-selected project: its own root's worktree dir.
        WORKTREE_DIR="$(wt_project_base "$ROOT_DIR" "$PROJECT_NAME")/${DIR_PREFIX}"
    else
        # Legacy project/ checkout: always the transition location. Going
        # through the registry here would let a registered project that
        # happens to share this checkout's repo-slug name capture the
        # worktree under ITS root while git operations target project/
        # (#273 round-2 review).
        WORKTREE_DIR="$(wt_project_base_glob "$ROOT_DIR")/${REPO_SLUG}/${DIR_PREFIX}"
    fi
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
    echo "  Issue:      $ISSUE_DISPLAY_REF"
fi
echo "  Repository: $REPO_SLUG"
echo "  Type:       $WORKTREE_TYPE"
echo "  Branch:     $BRANCH_NAME"
[ -n "$PARENT_BRANCH" ] && echo "  Parent:     #$PARENT_ISSUE_NUM ($PARENT_BRANCH)"
echo "  Path:       $WORKTREE_DIR"
echo ""

# For a registered project, ensure its root excludes worktrees/ from its
# own git status (and, for ros2_colcon roots, from colcon) before the
# first worktree lands there. Idempotent; a no-op for legacy/unregistered
# projects (#265).
if [ "$WORKTREE_TYPE" == "project" ] && [ -n "$PROJECT_NAME" ]; then
    wt_ensure_exclusion "$ROOT_DIR" "$PROJECT_NAME"
fi

mkdir -p "$(dirname "$WORKTREE_DIR")"

# Track whether parent branch was used
PARENT_BRANCH_FOUND=false

# --- Create the worktree ---
if [ "$WORKTREE_TYPE" == "project" ]; then
    # Project worktrees loop over the worktree_repos manifest — one
    # git-worktree-add per entry, via the shared waterfall helper. Never
    # falls back to a symlink (ADR-0012).
    #
    # Rollback state + trap: WT_ADDED_ENTRIES records every entry actually
    # added this run (dest, origin, branch, whether that branch already
    # existed before the add). The trap is armed right after the FIRST
    # successful add — from that point on, ANY failure (a later add, the
    # manifest write, worktree_env, or env.sh/build.sh/test.sh generation)
    # rolls back every entry added so far and deletes the aggregate dir,
    # via one function rather than an ad-hoc rm/worktree-remove at each
    # call site. It is disarmed once the worktree is fully valid, so an
    # unrelated later failure elsewhere in the script (e.g. --plan-file
    # draft-PR creation) never undoes an otherwise-successful worktree.
    WT_ADDED_ENTRIES=()

    _wt_rollback_package_worktree() {
        local rc=$?
        trap - ERR EXIT
        echo "ERROR: worktree creation failed — rolling back ${#WT_ADDED_ENTRIES[@]} already-created worktree(s)..." >&2
        local entry dest origin branch existed
        for entry in "${WT_ADDED_ENTRIES[@]}"; do
            IFS='|' read -r dest origin branch existed <<< "$entry"
            git -C "$origin" worktree remove --force "$dest" 2>/dev/null || true
            if [ "$existed" = "no" ] && [ -n "$branch" ]; then
                git -C "$origin" branch -D "$branch" 2>/dev/null || true
            fi
        done
        rm -rf "$WORKTREE_DIR"
        exit "${rc:-1}"
    }

    while IFS=$'\t' read -r WR_ORIGIN WR_REL WR_BRANCH; do
        [ -z "$WR_ORIGIN" ] && continue
        if [ "$WR_REL" = "." ]; then
            WR_DEST="$WORKTREE_DIR"
        else
            WR_DEST="$WORKTREE_DIR/$WR_REL"
        fi
        if ! git -C "$WR_ORIGIN" rev-parse --git-dir >/dev/null 2>&1; then
            echo "ERROR: manifest entry is not a git repository: $WR_ORIGIN" >&2
            if [ "${#WT_ADDED_ENTRIES[@]}" -eq 0 ]; then
                rm -rf "$WORKTREE_DIR"
            fi
            exit 1
        fi
        mkdir -p "$(dirname "$WR_DEST")"
        echo "Adding worktree for $WR_ORIGIN at $WR_DEST (branch '$WR_BRANCH')..."
        WR_BRANCH_EXISTED=no
        git -C "$WR_ORIGIN" show-ref --verify --quiet "refs/heads/$WR_BRANCH" && WR_BRANCH_EXISTED=yes
        if ! _wt_add_repo "$WR_ORIGIN" "$WR_DEST" "$WR_BRANCH" "$PARENT_BRANCH"; then
            if [ "${#WT_ADDED_ENTRIES[@]}" -eq 0 ]; then
                rm -rf "$WORKTREE_DIR"
            fi
            exit 1
        fi
        WT_ADDED_ENTRIES+=("$WR_DEST|$WR_ORIGIN|$WR_BRANCH|$WR_BRANCH_EXISTED")
        if [ "${#WT_ADDED_ENTRIES[@]}" -eq 1 ]; then
            trap _wt_rollback_package_worktree ERR EXIT
        fi
        if [ "$WR_BRANCH" = "$BRANCH_NAME" ] || [ "$WR_REL" = "." ]; then
            # Owning-repo entry: check parent-branch-found for PR targeting,
            # matching the pre-#252 single-repo semantics.
            if [ -n "$PARENT_BRANCH" ] && [ "$PARENT_BRANCH_FOUND" = false ]; then
                if git -C "$WR_ORIGIN" show-ref --verify --quiet "refs/heads/$PARENT_BRANCH" || \
                   git -C "$WR_ORIGIN" show-ref --verify --quiet "refs/remotes/origin/$PARENT_BRANCH"; then
                    PARENT_BRANCH_FOUND=true
                fi
            fi
        fi
    done <<< "$REPO_LINES"

    # Write the per-worktree repo manifest (.worktree-repos, ADR-0012) so
    # every later script (enter/remove/list/dashboard/merge_pr) can compose
    # this worktree's repos without calling the adapter or checking type —
    # EXCEPT when there is exactly one entry with rel path ".": there, the
    # worktree root IS the repo checkout, and wt_read_manifest's legacy
    # fallback already reconstructs that single entry with no file needed.
    # Writing the file in that case would add a permanently untracked file
    # to every single_project (and legacy) worktree's own git status.
    _REPO_LINE_COUNT="$(printf '%s\n' "$REPO_LINES" | grep -c . || true)"
    _WRITE_MANIFEST=true
    if [ "${_REPO_LINE_COUNT:-0}" -eq 1 ]; then
        IFS=$'\t' read -r _rl_origin _rl_rel _rl_branch <<< "$REPO_LINES"
        [ "$_rl_rel" = "." ] && _WRITE_MANIFEST=false
    fi
    if [ "$_WRITE_MANIFEST" = true ]; then
        printf '%s\n' "$REPO_LINES" | wt_write_manifest "$WORKTREE_DIR" "${PROJECT_NAME:-project}" "$ISSUE_REF" "$LAYER"
    fi

    # Generate env.sh/build.sh/test.sh for a package worktree when
    # worktree_env has something to say (ros2_colcon). env.sh is the entry
    # point for a shell that must keep the overlay; build.sh/test.sh are
    # one-shot wrappers that source it fresh.
    if [ -n "$LAYER" ]; then
        WE_ADAPTER_ARGS=()
        [ -n "$PROJECT_NAME" ] && WE_ADAPTER_ARGS+=(--project "$PROJECT_NAME")
        WE_OUTPUT="$("$SCRIPT_DIR/adapter" "${WE_ADAPTER_ARGS[@]}" worktree_env --worktree "$WORKTREE_DIR")" || {
            echo "Error: worktree_env failed for the new worktree" >&2
            exit 1
        }
        if [ -n "$WE_OUTPUT" ]; then
            printf '%s\n' "$WE_OUTPUT" > "$WORKTREE_DIR/env.sh"
            cat > "$WORKTREE_DIR/build.sh" << BUILD_EOF
#!/usr/bin/env bash
set -e
SELF_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "\$SELF_DIR/env.sh"
cd "\$SELF_DIR/${LAYER}_ws"
# A package worktree exists to override same-layer packages the hosted
# instance already built — colcon warns (and may hard-error in a future
# release) without --allow-overriding for exactly those. Computed here at
# run time (colcon list, not this generation-time script) so it always
# matches whatever's actually under src/, including packages added later.
OVERRIDES="\$(colcon list --names-only --base-paths src | tr '\n' ' ')"
if [ -n "\$OVERRIDES" ]; then
    # shellcheck disable=SC2086
    colcon build --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \\
        --allow-overriding \$OVERRIDES "\$@"
else
    colcon build --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON "\$@"
fi
BUILD_EOF
            chmod +x "$WORKTREE_DIR/build.sh"
            cat > "$WORKTREE_DIR/test.sh" << TEST_EOF
#!/usr/bin/env bash
set -e
SELF_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "\$SELF_DIR/env.sh"
cd "\$SELF_DIR/${LAYER}_ws"
if [ ! -d install ]; then
    # See build.sh: --allow-overriding is required for a package worktree's
    # whole reason for existing (overriding the hosted instance's same-layer
    # install), computed at run time from what's actually under src/.
    OVERRIDES="\$(colcon list --names-only --base-paths src | tr '\n' ' ')"
    if [ -n "\$OVERRIDES" ]; then
        # shellcheck disable=SC2086
        colcon build --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \\
            --allow-overriding \$OVERRIDES
    else
        colcon build --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    fi
fi
# Re-source so the freshly built overlay is on top (mirrors adapter_test).
# shellcheck source=/dev/null
source "\$SELF_DIR/env.sh"
colcon test --event-handlers console_direct+ --return-code-on-test-failure "\$@"
colcon test-result --verbose
TEST_EOF
            chmod +x "$WORKTREE_DIR/test.sh"
            echo "Generated env.sh, build.sh, test.sh"
        fi
    fi

    # The worktree is now fully valid — disarm. A failure anywhere later in
    # this script (e.g. --plan-file draft-PR creation) must not roll it back.
    trap - ERR EXIT

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
    if [ -n "${ISSUE_TITLE:-}" ]; then
        _PROGRESS_HEADING="# Issue #$ISSUE_NUM — $ISSUE_TITLE"
    else
        _PROGRESS_HEADING="# Issue #$ISSUE_NUM"
    fi
    cat > "$PROGRESS_FILE" << PROGRESS_EOF
---
workflow: $WORKFLOW
issue: $ISSUE_NUM
---

$_PROGRESS_HEADING
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
    echo "  Issue $ISSUE_DISPLAY_REF: $ISSUE_TITLE"
fi
[ -n "$PARENT_BRANCH" ] && echo "  Parent: #$PARENT_ISSUE_NUM ($PARENT_BRANCH)"
[ -n "$WORKFLOW" ] && echo "  Workflow: $WORKFLOW"
echo ""

# --- Create draft PR if --plan-file given ---
if [ -n "$PLAN_FILE" ] && [ -n "$LAYER" ]; then
    echo "⚠️  --plan-file draft PR creation is not supported for package worktrees"
    echo "   (the aggregate dir is not itself a git repo; multi-repo PR"
    echo "   resolution is tracked separately). Create PRs per package repo by hand."
elif [ -n "$PLAN_FILE" ]; then
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
# A qualified --issue owner/repo#N (ADR-0012) must be echoed back qualified
# here too — worktree_enter.sh/worktree_remove.sh resolve a package
# worktree by matching that exact ref against its .worktree-repos header
# (find_worktree_by_issue); a bare number is ambiguous for a project that
# has more than one package worktree and would send the user to the wrong
# command. --project is included whenever this worktree was created
# against a registered project, for the same reason.
_NEXT_STEPS_ISSUE="$ISSUE_NUM"
[ -n "$ISSUE_OWNER_REPO" ] && _NEXT_STEPS_ISSUE="$ISSUE_REF"
_NEXT_STEPS_PROJECT_FLAG=""
[ -n "$PROJECT_NAME" ] && _NEXT_STEPS_PROJECT_FLAG=" --project $PROJECT_NAME"

# Shared pre-commit hook preflight (issue #272): a worktree runs the hook of
# the repository that OWNS it — the workspace's .git/hooks for a workspace
# worktree, the project checkout's for a project worktree — and that hook
# pins the interpreter that installed it. If that path is gone (a hook
# installed from a since-removed worktree's venv), every commit here fails
# with "`pre-commit` not found" unless a venv happens to be on PATH. Ask each
# checkout that commits will actually run in which common dir it belongs
# to: the worktree itself for workspace and single-repo project worktrees,
# every manifest entry for a package worktree (its container is a plain
# directory inside the project tree — asking it would walk up to the
# enclosing repo and report a hook that never runs for these commits).
_HOOK_CHECKOUTS=()
for _hook_entry in ${WT_ADDED_ENTRIES[@]+"${WT_ADDED_ENTRIES[@]}"}; do
    _HOOK_CHECKOUTS+=("${_hook_entry%%|*}")
done
[ "${#_HOOK_CHECKOUTS[@]}" -gt 0 ] || _HOOK_CHECKOUTS=("$WORKTREE_DIR")
_HOOK_SEEN=" "
for _hook_checkout in "${_HOOK_CHECKOUTS[@]}"; do
    _HOOK_COMMON="$(git -C "$_hook_checkout" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    [ -n "$_HOOK_COMMON" ] && [ -f "$_HOOK_COMMON/hooks/pre-commit" ] || continue
    case "$_HOOK_SEEN" in *" $_HOOK_COMMON "*) continue ;; esac
    _HOOK_SEEN="$_HOOK_SEEN$_HOOK_COMMON "
    _HOOK_PY="$(sed -n 's/^INSTALL_PYTHON=//p' "$_HOOK_COMMON/hooks/pre-commit" | head -1 | tr -d "'\"")"
    if [ -n "$_HOOK_PY" ] && [ ! -x "$_HOOK_PY" ]; then
        echo "⚠️  The shared pre-commit hook points to a Python that no longer exists ($(dirname "$_HOOK_COMMON")):" >&2
        echo "     $_HOOK_PY" >&2
        echo "   Commits in this (and every) worktree of that repo will fail with '\`pre-commit\` not found'." >&2
        echo "   Fix once, from that checkout:  make -C \"$(dirname "$_HOOK_COMMON")\" repair" >&2
        echo "" >&2
    fi
done

if [ -n "$SKILL_NAME" ]; then
    echo "To enter this worktree:"
    echo "  source $SCRIPT_DIR/worktree_enter.sh --skill $SKILL_NAME --type $WORKTREE_TYPE"
    echo ""
    echo "When done, remove with:"
    echo "  $SCRIPT_DIR/worktree_remove.sh --skill $SKILL_NAME --type $WORKTREE_TYPE"
else
    echo "To enter this worktree:"
    echo "  source $SCRIPT_DIR/worktree_enter.sh --issue $_NEXT_STEPS_ISSUE --type $WORKTREE_TYPE$_NEXT_STEPS_PROJECT_FLAG"
    echo ""
    echo "When done, remove with:"
    echo "  $SCRIPT_DIR/worktree_remove.sh --issue $_NEXT_STEPS_ISSUE --type $WORKTREE_TYPE$_NEXT_STEPS_PROJECT_FLAG"
fi
echo ""

# Quiet mode: emit only the worktree path on the original stdout (fd 3).
if [ "$PRINT_PATH_ONLY" = true ]; then
    echo "$WORKTREE_DIR" >&3
fi
