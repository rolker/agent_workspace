#!/bin/bash
# .agent/scripts/worktree_remove.sh
# Remove a git worktree and clean up
#
# Usage:
#   ./worktree_remove.sh --issue <number> --type workspace|project [--project <name>] [--repo-slug <slug>] [--force]
#   ./worktree_remove.sh --skill <name> --type workspace|project [--project <name>] [--repo-slug <slug>] [--force]
#
# Examples:
#   ./worktree_remove.sh --issue 123 --type workspace
#   ./worktree_remove.sh --issue 123 --type project --force
#   ./worktree_remove.sh --skill research --type workspace
#
# This will:
#   1. Check for uncommitted changes (unless --force)
#   2. Remove the worktree directory
#   3. Prune the git worktree reference
#   4. Show branch deletion instructions

set -eo pipefail

CALLER_PWD="$(pwd -P)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ISSUE_NUM=""
SKILL_NAME=""
WORKTREE_TYPE=""
FORCE=false
REPO_SLUG=""
PROJECT_REPO=""

show_usage() {
    echo "Usage: $0 (--issue <number> | --skill <name>) --type workspace|project [options]"
    echo ""
    echo "Options:"
    echo "  --issue <number>        Issue number (required, unless --skill is used)"
    echo "  --skill <name>          Skill name (alternative to --issue)"
    echo "  --type <type>           Worktree type: 'workspace' or 'project' (required)"
    echo "  --project <name>        Registered project name (for multi-project disambiguation; alias: --repo)"
    echo "  --repo-slug <slug>      Repository slug (optional, for disambiguation)"
    echo "  --force                 Force removal even with uncommitted changes"
}

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
            PROJECT_REPO="$2"
            shift 2
            ;;
        --repo-slug)
            REPO_SLUG="$2"
            shift 2
            ;;
        --force|-f)
            FORCE=true
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

# Derive ROOT_DIR from the script's location, consistent with all other
# worktree scripts. This works regardless of CWD — even if called from
# inside a project worktree (where git context is the project repo, not
# the workspace repo).
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "$SCRIPT_DIR/_worktree_helpers.sh"

if [ -n "$REPO_SLUG" ]; then
    REPO_SLUG=$(echo "$REPO_SLUG" | sed 's/[^A-Za-z0-9_]/_/g')
fi

# ADR-0012: a package worktree's --issue is qualified (owner/repo#N);
# resolution here is still by the numeric suffix.
if [ -n "$ISSUE_NUM" ] && [[ "$ISSUE_NUM" == *#* ]]; then
    ISSUE_NUM="${ISSUE_NUM##*#}"
fi

if [ -n "$ISSUE_NUM" ] && [ -n "$SKILL_NAME" ]; then
    echo "Error: --issue and --skill are mutually exclusive"
    show_usage
    exit 1
fi
if [ -z "$ISSUE_NUM" ] && [ -z "$SKILL_NAME" ]; then
    echo "Error: either --issue or --skill is required"
    show_usage
    exit 1
fi
if [ -z "$WORKTREE_TYPE" ]; then
    echo "Error: --type is required (workspace or project)"
    show_usage
    exit 1
fi
if [ "$WORKTREE_TYPE" != "workspace" ] && [ "$WORKTREE_TYPE" != "project" ]; then
    echo "Error: --type must be 'workspace' or 'project'"
    exit 1
fi
if [ -n "$PROJECT_REPO" ] && [ "$WORKTREE_TYPE" == "workspace" ]; then
    echo "Error: --project is only valid with --type project"
    exit 1
fi

# Resolve base directories for the specified type
_resolve_base_dirs() {
    local type="$1"
    NEW_BASE=""
    LEGACY_BASE=""

    if [ "$type" == "workspace" ]; then
        NEW_BASE="$(wt_workspace_base "$ROOT_DIR")"
        LEGACY_BASE="$(wt_legacy_workspace_base "$ROOT_DIR")"
    else
        if [ -n "$PROJECT_REPO" ]; then
            if ! NEW_BASE="$(wt_project_base "$ROOT_DIR" "$PROJECT_REPO")"; then
                exit 1
            fi
        else
            local proj_base
            proj_base="$(wt_project_base_glob "$ROOT_DIR")"
            if [ -d "$proj_base" ]; then
                local repo_dirs=()
                for d in "$proj_base"/*/; do
                    [ -d "$d" ] && repo_dirs+=("$d")
                done
                if [ "${#repo_dirs[@]}" -eq 1 ]; then
                    NEW_BASE="${repo_dirs[0]%/}"
                elif [ "${#repo_dirs[@]}" -gt 1 ]; then
                    echo "Error: Multiple projects registered. Use --project to specify:" >&2
                    for d in "${repo_dirs[@]}"; do
                        echo "  --project $(basename "${d%/}")" >&2
                    done
                    return 1
                fi
            fi
        fi
        LEGACY_BASE="$(wt_legacy_project_base "$ROOT_DIR")"
    fi
}

WORKTREE_DIR=""

_resolve_base_dirs "$WORKTREE_TYPE" || exit 1

if [ -n "$SKILL_NAME" ]; then
    if [ -n "$NEW_BASE" ] && FOUND=$(find_worktree_by_skill "$NEW_BASE" "$SKILL_NAME" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
    elif [ -n "$LEGACY_BASE" ] && FOUND=$(find_worktree_by_skill "$LEGACY_BASE" "$SKILL_NAME" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
        echo "⚠️  Found worktree in legacy location." >&2
    else
        echo "Error: No $WORKTREE_TYPE worktree found for skill '$SKILL_NAME'"
        echo ""
        echo "List worktrees with: ./.agent/scripts/worktree_list.sh"
        exit 1
    fi
else
    if [ -n "$NEW_BASE" ] && FOUND=$(find_worktree "$NEW_BASE" "$ISSUE_NUM" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
    elif [ -n "$LEGACY_BASE" ] && FOUND=$(find_worktree "$LEGACY_BASE" "$ISSUE_NUM" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
        echo "⚠️  Found worktree in legacy location." >&2
    else
        echo "Error: No $WORKTREE_TYPE worktree found for issue #$ISSUE_NUM"
        echo ""
        echo "List worktrees with: ./.agent/scripts/worktree_list.sh"
        exit 1
    fi
fi

# Get branch name
cd "$ROOT_DIR"
BRANCH_NAME=$(git -C "$WORKTREE_DIR" branch --show-current 2>/dev/null || echo "")

echo "========================================"
echo "Removing Worktree"
echo "========================================"
if [ -n "$SKILL_NAME" ]; then
    echo "  Skill:  $SKILL_NAME"
else
    echo "  Issue:  #$ISSUE_NUM"
fi
echo "  Type:   $WORKTREE_TYPE"
echo "  Path:   $WORKTREE_DIR"
echo "  Branch: ${BRANCH_NAME:-detached HEAD}"
echo ""

if [[ ! -d "$WORKTREE_DIR" ]]; then
    echo "❌ Error: Worktree directory '$WORKTREE_DIR' does not exist."
    exit 1
fi
if ! WORKTREE_DIR="$(cd "$WORKTREE_DIR" && pwd -P)"; then
    echo "❌ Error: Failed to access worktree directory '$WORKTREE_DIR'."
    exit 1
fi
if [[ "$CALLER_PWD" == "$WORKTREE_DIR" || "$CALLER_PWD" == "$WORKTREE_DIR/"* ]]; then
    echo "❌ Error: Your shell is currently inside this worktree."
    echo ""
    echo "   Run this first:  cd $ROOT_DIR"
    if [ -n "$SKILL_NAME" ]; then
        echo "   Then re-run:     $0 --skill $SKILL_NAME --type $WORKTREE_TYPE"
    else
        echo "   Then re-run:     $0 --issue $ISSUE_NUM --type $WORKTREE_TYPE"
    fi
    exit 1
fi

# --- Resolve every entry this worktree is made of ---
# .worktree-repos (ADR-0012), or the legacy single-entry fallback for a
# worktree without one. Either way: never parse the directory name, never
# call the adapter, never check the project type.
MANIFEST_ENTRIES="$(wt_read_manifest "$WORKTREE_DIR")"
declare -a ENTRY_DESTS=()
while IFS=$'\t' read -r _m_origin _m_rel _m_branch; do
    [ -z "$_m_rel" ] && continue
    if [ "$_m_rel" = "." ]; then
        ENTRY_DESTS+=("$WORKTREE_DIR")
    else
        ENTRY_DESTS+=("$WORKTREE_DIR/$_m_rel")
    fi
done <<< "$MANIFEST_ENTRIES"

# --- Preflight every entry before removing any (unless --force) ---
declare -a DIRTY_DESTS=()
for _dest in "${ENTRY_DESTS[@]}"; do
    [ -d "$_dest" ] || continue
    _porcelain="$(git -C "$_dest" status --porcelain 2>/dev/null || true)"
    [ -n "$_porcelain" ] && DIRTY_DESTS+=("$_dest")
done

if [ "${#DIRTY_DESTS[@]}" -gt 0 ] && [ "$FORCE" != true ]; then
    echo "⚠️  Warning: worktree has uncommitted changes in:"
    for _dest in "${DIRTY_DESTS[@]}"; do
        echo ""
        echo "  ${_dest#"$WORKTREE_DIR"/}:"
        git -C "$_dest" status --short | sed 's/^/    /'
    done
    echo ""
    echo "Use --force to remove anyway, or commit/stash your changes first."
    exit 1
fi

# --- Remove every entry, then the aggregate dir last ---
echo "Removing worktree..."

declare -a ENTRY_OWNERS=()
for _dest in "${ENTRY_DESTS[@]}"; do
    [ -d "$_dest" ] || continue
    # Resolve the owning repo from the entry itself (its git-common-dir),
    # not from the manifest's recorded origin path — the checkout is the
    # ground truth if a repo has since moved.
    _common_dir="$(git -C "$_dest" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [ -n "$_common_dir" ]; then
        _owner="$(dirname "$_common_dir")"
    else
        _owner="$ROOT_DIR/project"
    fi
    if [ "$FORCE" = true ]; then
        git -C "$_owner" worktree remove --force "$_dest"
    else
        git -C "$_owner" worktree remove "$_dest"
    fi
    git -C "$_owner" worktree prune
    ENTRY_OWNERS+=("$_owner")
done

# Aggregate dir last: a no-op for the legacy/single-entry shape (already
# removed above, since dest == WORKTREE_DIR); deletes the leftover
# .worktree-repos/env.sh/build.sh/test.sh/layer dirs for a package worktree.
rm -rf "$WORKTREE_DIR"

echo ""
echo "✅ Worktree removed successfully"

# Show branch deletion instructions per entry.
_shown_branch=""
_i=0
while IFS=$'\t' read -r _m_origin _m_rel _m_branch; do
    [ -z "$_m_rel" ] && continue
    _owner="${ENTRY_OWNERS[$_i]:-}"
    _i=$((_i + 1))
    [ -z "$_owner" ] && continue
    [ -z "$_m_branch" ] && continue
    if git -C "$_owner" show-ref --verify --quiet "refs/heads/$_m_branch" 2>/dev/null; then
        echo ""
        echo "The branch '$_m_branch' still exists in $_owner."
        echo "To delete it locally:"
        echo "  git -C $_owner branch -d $_m_branch"
        echo "To delete it on origin (if pushed):"
        echo "  git -C $_owner push origin --delete $_m_branch"
        _shown_branch="yes"
    fi
done <<< "$MANIFEST_ENTRIES"
unset _shown_branch _i _owner _m_origin _m_rel _m_branch

echo ""
echo "Remaining worktrees:"
"$SCRIPT_DIR/worktree_list.sh" 2>/dev/null || git worktree list
