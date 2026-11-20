#!/bin/bash
# .agent/scripts/worktree_remove.sh
# Remove a git worktree and clean up
#
# Usage:
#   ./worktree_remove.sh --issue <number> --type workspace|project [--project <name>] [--repo-slug <slug>] [--force]
#   ./worktree_remove.sh --skill <name> --type workspace|project [--project <name>] [--repo-slug <slug>] [--force]
#   ./worktree_remove.sh --path <worktree> --type workspace|project [--project <name>] [--force]
#
# --path names the worktree itself (issue 478): merge_pr.sh resolves a skill
# pull request's worktree by the PR's head branch and removes exactly that
# one, so two worktrees of the same skill never get mixed up. The path must
# be a linked single-repository git worktree (its own top folder, not a main
# checkout, not a package worktree's container or one of its entries) of
# the repository --type names: the workspace checkout, or the project's own
# repository (--project picks it when several are registered).
#
# Examples:
#   ./worktree_remove.sh --issue 123 --type workspace
#   ./worktree_remove.sh --issue 123 --type project --force
#   ./worktree_remove.sh --skill research --type workspace
#   ./worktree_remove.sh --path worktrees/workspace/skill-workspace-research-20261115-101010-1 --type workspace
#
# This will:
#   1. Check for uncommitted changes (unless --force)
#   2. Remove the worktree directory, first giving its directories that
#      lack any of u=rwx full owner permission (a build's install tree can
#      leave read-only ones, which would block the removal; directories
#      only, symlinks never followed, mounts never crossed; issue 428)
#   3. Prune the git worktree reference
#   4. Show branch deletion instructions

set -eo pipefail

CALLER_PWD="$(pwd -P)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ISSUE_NUM=""
SKILL_NAME=""
PATH_ARG=""
WORKTREE_TYPE=""
FORCE=false
REPO_SLUG=""
PROJECT_REPO=""

show_usage() {
    echo "Usage: $0 (--issue <number> | --skill <name> | --path <worktree>) --type workspace|project [options]"
    echo ""
    echo "Options:"
    echo "  --issue <number>        Issue number (required, unless --skill is used)"
    echo "  --skill <name>          Skill name (alternative to --issue)"
    echo "  --path <worktree>       The worktree's own path (alternative to --issue/--skill;"
    echo "                          a linked single-repository worktree only)"
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
        --path)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                echo "Error: --path requires a worktree path"
                show_usage
                exit 1
            fi
            PATH_ARG="$2"
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
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

# ---------------------------------------------------- user-tier guard (#265) ---
# This script is promoted to the user tier (.agent/user_tier_scripts.txt), so
# it can be invoked from any cwd on the machine. Refuse outside the workspace
# checkout and outside every registered project root, BEFORE any git/gh call,
# so a stray invocation in an unrelated repo touches nothing. See
# docs/decisions/0016-session-roots-and-the-user-tier.md.
registry_require_root "$ROOT_DIR" || exit 1

if [ -n "$REPO_SLUG" ]; then
    REPO_SLUG=$(echo "$REPO_SLUG" | sed 's/[^A-Za-z0-9_]/_/g')
fi

# ADR-0012: a package worktree's --issue is qualified (owner/repo#N).
# ISSUE_REF keeps the raw value for find_worktree_by_issue (exact
# .worktree-repos header match); ISSUE_NUM is the trailing number, used
# elsewhere (messages, legacy directory-name construction).
ISSUE_REF="$ISSUE_NUM"
if [ -n "$ISSUE_NUM" ] && [[ "$ISSUE_NUM" == *#* ]]; then
    ISSUE_NUM="${ISSUE_NUM##*#}"
fi

_SELECTORS=0
[ -n "$ISSUE_NUM" ] && _SELECTORS=$((_SELECTORS + 1))
[ -n "$SKILL_NAME" ] && _SELECTORS=$((_SELECTORS + 1))
[ -n "$PATH_ARG" ] && _SELECTORS=$((_SELECTORS + 1))
if [ "$_SELECTORS" -gt 1 ]; then
    echo "Error: --issue, --skill and --path are mutually exclusive"
    show_usage
    exit 1
fi
if [ "$_SELECTORS" -eq 0 ]; then
    echo "Error: one of --issue, --skill or --path is required"
    show_usage
    exit 1
fi
# --type is optional when the cwd already says which checkout this is
# (#317): a cwd under a registered project root derives `--type project
# --project <name>`, a cwd inside the workspace checkout derives `--type
# workspace`. An explicit flag always wins -- this only fills a blank.
if [ -z "$WORKTREE_TYPE" ]; then
    _WT_DERIVED="$(registry_derive_type_from_dir "$ROOT_DIR" "$PWD" 2>/dev/null)" || _WT_DERIVED=""
    if [ -n "$_WT_DERIVED" ]; then
        WORKTREE_TYPE="$(cut -f1 <<< "$_WT_DERIVED")"
        _WT_DERIVED_PROJECT="$(cut -f2 <<< "$_WT_DERIVED")"
        if [ -z "$PROJECT_REPO" ] && [ -n "$_WT_DERIVED_PROJECT" ]; then
            PROJECT_REPO="$_WT_DERIVED_PROJECT"
        fi
        echo "Note: --type omitted; derived --type $WORKTREE_TYPE${PROJECT_REPO:+ --project $PROJECT_REPO} from $PWD" >&2
        unset _WT_DERIVED_PROJECT
    fi
    unset _WT_DERIVED
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
    local type="$1" _cwd_entry=""
    NEW_BASE=""

    if [ "$type" == "workspace" ]; then
        NEW_BASE="$(wt_workspace_base "$ROOT_DIR")"
    else
        # Fail closed: a malformed registry means we cannot tell which
        # worktree belongs to which project — never remove on partial state.
        registry_entries "$ROOT_DIR" >/dev/null 2>&1 || {
            [ $? -eq 2 ] && { echo "Error: project registry is malformed; fix .agent/projects.local before removing project worktrees" >&2; return 1; }; }
        if [ -n "$PROJECT_REPO" ]; then
            # A parent root resolves to its instance, exactly as create did (#265).
            PROJECT_REPO="$(registry_resolve_project_arg "$ROOT_DIR" "$PROJECT_REPO")" || exit 1
            if ! NEW_BASE="$(wt_project_base "$ROOT_DIR" "$PROJECT_REPO")"; then
                exit 1
            fi
        elif _cwd_entry="$(registry_resolve_session_dir "$ROOT_DIR" "$PWD" 2>/dev/null)"; then
            # The registered root the cwd is in (its hosting dir or its
            # worktrees= dir), as worktree_create.sh picks it; a parent root
            # resolves to its instance.
            PROJECT_REPO="$(registry_resolve_project_arg "$ROOT_DIR" "$(cut -f1 <<< "$_cwd_entry")")" || exit 1
            NEW_BASE="$(wt_project_base "$ROOT_DIR" "$PROJECT_REPO")" || exit 1
        else
            # Auto-detect: find the single project with a worktree dir, or
            # list every candidate for --project to disambiguate (#265).
            local -a candidates=()
            local cname cdir
            while IFS=$'\t' read -r cname cdir; do
                [ -z "$cdir" ] && continue
                candidates+=("$cname"$'\t'"$cdir")
            done < <(wt_registry_worktree_dirs "$ROOT_DIR" 2>/dev/null)
            local -a names=()
            local c n
            for c in "${candidates[@]}"; do
                n="$(cut -f1 <<< "$c")"
                [[ " ${names[*]} " == *" $n "* ]] || names+=("$n")
            done
            if [ "${#names[@]}" -eq 1 ]; then
                PROJECT_REPO="${names[0]}"
                NEW_BASE="$(wt_project_base "$ROOT_DIR" "$PROJECT_REPO")" || exit 1
            elif [ "${#names[@]}" -gt 1 ]; then
                echo "Error: Multiple projects registered. Use --project to specify:" >&2
                for n in "${names[@]}"; do
                    echo "  --project $n" >&2
                done
                return 1
            fi
        fi
        # Issue #265 part 4: no transition (worktrees/project/<name>/) or
        # legacy (project/worktrees/) location is searched any more.
    fi
}

WORKTREE_DIR=""

if [ -n "$PATH_ARG" ]; then
    # No lookup: the caller names the worktree. It must be a linked
    # single-repository worktree's own top folder; a main checkout (the
    # workspace's or a project's), a folder inside a worktree, or a package
    # worktree's container (not a git checkout itself) is refused.
    if [ ! -d "$PATH_ARG" ]; then
        echo "Error: --path '$PATH_ARG' is not a directory"
        exit 1
    fi
    _p_abs="$(cd "$PATH_ARG" && pwd -P)"
    _p_top="$(git -C "$_p_abs" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -z "$_p_top" ] || [ "$(cd "$_p_top" && pwd -P)" != "$_p_abs" ]; then
        echo "Error: --path '$PATH_ARG' is not a git worktree's top folder"
        exit 1
    fi
    _p_gitdir="$(git -C "$_p_abs" rev-parse --path-format=absolute --git-dir 2>/dev/null || true)"
    _p_common="$(git -C "$_p_abs" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [ -z "$_p_gitdir" ] || [ "$_p_gitdir" = "$_p_common" ]; then
        echo "Error: --path '$PATH_ARG' is a main checkout, not a linked worktree; it is never removed"
        exit 1
    fi
    # A package worktree's entry is a linked worktree's top folder too, but
    # it is one repository of several: removing it alone would leave the
    # package worktree half-gone. Any folder above it with a .worktree-repos
    # manifest marks it as such; that worktree is removed with --issue.
    _p_up="$(dirname "$_p_abs")"
    while :; do
        if [ -f "$_p_up/.worktree-repos" ]; then
            echo "Error: --path '$PATH_ARG' is an entry of the package worktree $_p_up; --path removes a single-repository worktree only (use --issue)"
            exit 1
        fi
        [ "$_p_up" = "/" ] && break
        _p_up="$(dirname "$_p_up")"
    done
    if wt_is_package_worktree "$_p_abs"; then
        echo "Error: --path '$PATH_ARG' is a package worktree; --path removes a single-repository worktree only (use --issue)"
        exit 1
    fi
    # The worktree must belong to the repository --type (and --project)
    # names: the workspace checkout, or the project's own repository.
    if [ "$WORKTREE_TYPE" = "workspace" ]; then
        _p_repo="$ROOT_DIR"
    elif ! _p_repo="$(wt_resolve_project_repo_root "$ROOT_DIR" "$PROJECT_REPO")"; then
        echo "Error: could not resolve the project repository for --path '$PATH_ARG'${PROJECT_REPO:+ (--project $PROJECT_REPO)}"
        exit 1
    fi
    _p_want="$(git -C "$_p_repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    _p_want="$( [ -n "$_p_want" ] && cd "$_p_want" 2>/dev/null && pwd -P || true)"
    _p_have="$(cd "$_p_common" 2>/dev/null && pwd -P || true)"
    if [ -z "$_p_want" ] || [ "$_p_have" != "$_p_want" ]; then
        echo "Error: --path '$PATH_ARG' is not a worktree of the $WORKTREE_TYPE repository ($_p_repo)"
        exit 1
    fi
    WORKTREE_DIR="$_p_abs"
    unset _p_abs _p_top _p_gitdir _p_common _p_up _p_repo _p_want _p_have
elif ! _resolve_base_dirs "$WORKTREE_TYPE"; then
    exit 1
fi

if [ -n "$PATH_ARG" ]; then
    :
elif [ -n "$SKILL_NAME" ]; then
    if [ -n "$NEW_BASE" ] && FOUND=$(find_worktree_by_skill "$NEW_BASE" "$SKILL_NAME" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
    else
        echo "Error: No $WORKTREE_TYPE worktree found for skill '$SKILL_NAME'"
        echo ""
        echo "List worktrees with: ./.agent/scripts/worktree_list.sh"
        exit 1
    fi
else
    if [ -n "$NEW_BASE" ] && FOUND=$(find_worktree_by_issue "$NEW_BASE" "$ISSUE_REF" "$REPO_SLUG"); then
        WORKTREE_DIR="$FOUND"
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
if [ -n "$PATH_ARG" ]; then
    :
elif [ -n "$SKILL_NAME" ]; then
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
    if [ -n "$PATH_ARG" ]; then
        echo "   Then re-run:     $0 --path $WORKTREE_DIR --type $WORKTREE_TYPE"
    elif [ -n "$SKILL_NAME" ]; then
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
declare -a ENTRY_ORIGINS=()
while IFS=$'\t' read -r _m_origin _m_rel _m_branch; do
    [ -z "$_m_rel" ] && continue
    if [ "$_m_rel" = "." ]; then
        ENTRY_DESTS+=("$WORKTREE_DIR")
    else
        ENTRY_DESTS+=("$WORKTREE_DIR/$_m_rel")
    fi
    ENTRY_ORIGINS+=("$_m_origin")
done <<< "$MANIFEST_ENTRIES"

# --- Resolve every entry's owning repository before removing any ---
# From the entry itself (its git-common-dir), not from the manifest's
# recorded origin path: the checkout is the ground truth if a repo has since
# moved. An existing entry whose owner cannot be resolved refuses the whole
# removal (issue #265 part 4: there is no project/ to fall back on), so an
# aggregate worktree is never half removed. ENTRY_OWNERS stays index-aligned
# with ENTRY_DESTS; an entry already gone has an empty owner.
declare -a ENTRY_OWNERS=()
for _i in "${!ENTRY_DESTS[@]}"; do
    _dest="${ENTRY_DESTS[$_i]}"
    if [ ! -d "$_dest" ]; then
        ENTRY_OWNERS+=("")
        continue
    fi
    # The entry must be a checkout's own top folder: git would otherwise walk
    # up from a plain directory to an enclosing repository (the root the
    # worktree dir lies in, say) and name that as the owner.
    _common_dir=""
    _top="$(git -C "$_dest" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$_top" ] && [ "$(cd "$_top" 2>/dev/null && pwd -P)" = "$(cd "$_dest" && pwd -P)" ]; then
        _common_dir="$(git -C "$_dest" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    fi
    if [ -z "$_common_dir" ]; then
        echo "Error: cannot resolve the repository that owns ${_dest}; nothing was removed."
        echo "It is not a git checkout's own top folder, so this script cannot tell what removing it would lose."
        # The check-first text is the one every removal hint uses
        # (CHECK_BEFORE_REMOVING, _project_registry.sh); paths are quoted
        # as the shell must read them.
        _qdest="$(printf '%q' "$_dest")"
        if [ "$_dest" = "$WORKTREE_DIR" ]; then
            # The worktree is this one entry: once it is gone there is
            # nothing left for this command to find, so git's record of it
            # is dropped by hand.
            _origin="${ENTRY_ORIGINS[$_i]:-}"
            if [ -n "$_origin" ] && [ "$_origin" != "$WORKTREE_DIR" ]; then
                echo "Only $CHECK_BEFORE_REMOVING, delete it by hand (rm -r $_qdest), then drop git's record of the worktree in the repository it was made from: git -C $(printf '%q' "$_origin") worktree prune."
            else
                echo "Only $CHECK_BEFORE_REMOVING, delete it by hand (rm -r $_qdest), then drop git's record of the worktree in the repository it was made from: git -C <that repository> worktree prune."
            fi
        else
            echo "Only $CHECK_BEFORE_REMOVING, delete it by hand (rm -r $_qdest), then run this command again: an entry already gone is skipped."
        fi
        exit 1
    fi
    ENTRY_OWNERS+=("$(dirname "$_common_dir")")
done

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

# A build or install step can leave read-only directories in the tree
# (`cmake --install` did, issue 428), and a file in a directory without
# write permission cannot be unlinked, so `git worktree remove` and the
# final `rm -rf` fail half way. Directories only, because that is what
# blocks the unlink, and only under the one tree given, never its parent.
# A directory missing read or search permission blocks the walk the same
# way, so any directory without all of u=rwx gets u+rwx.
# -P and -type d: a symlink, as the starting point or met on the walk, is
# never followed or changed, so an entry that links elsewhere cannot make
# this touch another checkout. -xdev: a mount inside the tree (a bind
# mount, say) is not crossed. `--`: a path is never read as an option.
# `-exec ... \;`, not `+`: each directory is repaired when find reaches it,
# before find tries to read it, so a directory under one that lacked r or
# x is reached too (a batched `+` runs after the walk, too late for that).
# A failed chmod does not stop the removal: the removal's own error is the
# one to show.
_make_dirs_writable() {  # <dir>
    [ -d "$1" ] && [ ! -L "$1" ] || return 0
    find -P -- "$1" -xdev -type d ! -perm -u=rwx -exec chmod u+rwx {} \; 2>/dev/null || true
}

for _i in "${!ENTRY_DESTS[@]}"; do
    _dest="${ENTRY_DESTS[$_i]}"
    _owner="${ENTRY_OWNERS[$_i]}"
    [ -n "$_owner" ] || continue
    [ -d "$_dest" ] || continue
    _make_dirs_writable "$_dest"
    if [ "$FORCE" = true ]; then
        git -C "$_owner" worktree remove --force "$_dest"
    else
        git -C "$_owner" worktree remove "$_dest"
    fi
    git -C "$_owner" worktree prune
done

# Aggregate dir last: a no-op for the single-entry shape (already
# removed above, since dest == WORKTREE_DIR); deletes the leftover
# .worktree-repos/env.sh/build.sh/test.sh/layer dirs for a package worktree.
# Only $WORKTREE_DIR itself is removed — never its parent (the root's
# worktrees/ dir). This script never deletes a directory the user may have
# customized (a worktrees= override, say), so an empty worktrees/ dir is
# simply left behind. The single-entry tree is already gone by now, so
# the guard in _make_dirs_writable skips it.
_make_dirs_writable "$WORKTREE_DIR"
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
