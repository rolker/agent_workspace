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
#   1. Decide, before removing or changing anything, each entry the
#      manifest names: present (reached), proven absent (its name is not
#      there, found without passing a symbolic link), or refused, with or
#      without --force (issue 428). Refused is everything else: a folder on
#      the way that cannot be entered (give it back u+rwx by hand), or a
#      symbolic link on the way or as the entry that does not lead to a
#      folder inside the worktree: dangling, to a file, or outside. For a
#      refused link, remove the link by hand (rm on a link removes only
#      the link, never what it points to) and run this again. Then check
#      present entries for uncommitted changes (unless --force; a folder
#      git status cannot open counts as not checked)
#   2. Remove the worktree directory, first giving its directories that
#      lack any of u=rwx full owner permission (a build's install tree can
#      leave read-only ones, which would block the removal; directories
#      only, symlinks never followed, a mount of another filesystem
#      neither walked nor changed, its top folder included, except a
#      package worktree's entry that is itself on another filesystem,
#      which is walked from its own top folder; issue 428)
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
#
# Each entry ends in exactly one of three states, decided here, before
# anything is removed or any permission changed (issue 428 review). The
# rule is "refuse unless proven": a case this function does not know is
# refused, never taken as gone, because an entry taken as gone gets no
# dirty check and the chmod and `rm -rf` below would delete it.
#   PRESENT  (0): reached; prints its physical path, inside the worktree.
#                 It then gets the owner check and the dirty check below.
#   ABSENT   (1): proven gone: the walk went down from the worktree
#                 through real folders only (no link), entering each, and
#                 in the last one entered the next name does not exist at
#                 all, as a file, a folder or a link.
#   REFUSED  (2): everything else; prints what was found and where, and
#                 what to do about it.
# The walk looks a name up only in a folder it has entered, so a failed
# lookup there means "not there", never "cannot look". A link is read one
# level at a time (`readlink`) and the walk goes on along what it names,
# under the same rules: the entry is PRESENT only when that path, inside
# the worktree, is reached. A link written as an absolute path outside the
# worktree's physical path, a dangling link, a link to a file, or a name
# missing behind a link is refused, with the advice to remove the link by
# hand (rm on a link removes only the link). A folder that cannot be
# entered is refused naming it; it is a real folder inside the worktree,
# so the advised chmod lands there and nowhere else.
_entry_state() {  # <worktree_dir (physical, entered)> <dest>
    local wt="$1" cur="$1" rest part name target link="" hops=0
    if [ "$2" = "$wt" ]; then printf '%s' "$wt"; return 0; fi
    rest="${2#"$wt"/}"
    while [ -n "$rest" ]; do
        part="${rest%%/*}"
        if [ "$part" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
        case "$part" in
            ""|.) continue ;;
            ..)
                if [ "$cur" = "$wt" ]; then
                    if [ -n "$link" ]; then
                        printf '%s\n' "the symbolic link $link leads outside this worktree (through ..)." \
                            "Remove the link by hand (rm $(printf '%q' "$link"); that removes only the link), then run this command again."
                    else
                        printf '%s\n' "its path in the manifest (.worktree-repos) climbs out of this worktree (..)." \
                            "Correct the manifest by hand, then run this command again."
                    fi
                    return 2
                fi
                cur="$(dirname -- "$cur")"
                continue
                ;;
        esac
        name="$cur/$part"
        if [ -L "$name" ]; then
            hops=$((hops + 1))
            link="$name"
            target="$(readlink -- "$name" 2>/dev/null)" || target=""
            if [ -z "$target" ] || [ "$hops" -gt 40 ]; then
                printf '%s\n' "$name is a symbolic link that cannot be followed." \
                    "Remove the link by hand (rm $(printf '%q' "$name")), then run this command again."
                return 2
            fi
            case "$target" in
                "$wt") cur="$wt" ;;
                "$wt"/*) cur="$wt"; rest="${target#"$wt"/}${rest:+/$rest}" ;;
                /*)
                    printf '%s\n' "$name is a symbolic link to $target, which leads outside this worktree." \
                        "Remove the link by hand (rm $(printf '%q' "$name"); that removes only the link), then run this command again."
                    return 2
                    ;;
                *) rest="$target${rest:+/$rest}" ;;
            esac
            continue
        fi
        if [ ! -e "$name" ]; then
            [ -z "$link" ] && return 1
            printf '%s\n' "$name does not exist, and the way to it runs through the symbolic link $link (a dangling link, or an entry gone behind a link)." \
                "Remove the link by hand (rm $(printf '%q' "$link")), then run this command again."
            return 2
        fi
        if [ ! -d "$name" ]; then
            if [ -n "$link" ]; then
                printf '%s\n' "$name is not a folder, and the way to it runs through the symbolic link $link." \
                    "Remove the link by hand (rm $(printf '%q' "$link")), then run this command again."
            else
                printf '%s\n' "$name is not a folder, where a folder should be." \
                    "Check what it is and remove it by hand, then run this command again."
            fi
            return 2
        fi
        if ! (cd "$name" 2>/dev/null); then
            printf '%s\n' "cannot enter $name: no search permission on it, so this script cannot tell what the entry holds." \
                "Check what it holds, give it back its owner permission by hand (chmod u+rwx $(printf '%q' "$name")), then run this command again."
            return 2
        fi
        cur="$name"
    done
    printf '%s' "$cur"
    return 0
}

declare -a ENTRY_OWNERS=()
for _i in "${!ENTRY_DESTS[@]}"; do
    _dest="${ENTRY_DESTS[$_i]}"
    # A `..` segment could make the walk stop at a missing name before it
    # and take an entry further on as absent; the scripts never write one.
    case "/${_dest#"$WORKTREE_DIR"}/" in
        */../*)
            echo "Error: cannot remove ${_dest}: a manifest path may not contain ..; correct .worktree-repos by hand. Nothing was removed."
            exit 1
            ;;
    esac
    _state_rc=0
    _state_out="$(_entry_state "$WORKTREE_DIR" "$_dest")" || _state_rc=$?
    case "$_state_rc" in
        0)  # PRESENT: from here on the entry is its physical path, reached.
            # The link check is the walk itself: every link on the way was
            # followed to a real folder inside. Asserted once more, so a
            # path outside can never reach `git worktree remove`.
            case "$_state_out/" in
                "$WORKTREE_DIR/"*) ;;
                *)
                    echo "Error: cannot remove ${_dest}: it resolves to ${_state_out}, outside this worktree; nothing was removed."
                    exit 1
                    ;;
            esac
            ENTRY_DESTS[_i]="$_state_out"
            _dest="$_state_out"
            ;;
        1)  # ABSENT: nothing to remove for it.
            ENTRY_OWNERS+=("")
            continue
            ;;
        *)  # REFUSED, with or without --force.
            echo "Error: cannot remove ${_dest}: nothing was removed."
            printf '%s\n' "$_state_out" | sed 's/^/  /'
            exit 1
            ;;
    esac
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
# Only the entries found above (an owner): those taken as gone were proven
# gone, not merely unreadable. "Clean" must mean git looked at everything:
# git status skips a folder it cannot open with a warning and exit 0, which
# would hide untracked work in it until the chmod below had opened it. A
# failed status, or one that names a permission denial (C locale, so the
# text is git's own English), counts as "cannot tell" and is refused like a
# dirty entry.
declare -a DIRTY_DESTS=()
declare -a UNREAD_DESTS=()
declare -a UNREAD_WHY=()
_status_err="$(mktemp)"
for _i in "${!ENTRY_DESTS[@]}"; do
    [ -n "${ENTRY_OWNERS[$_i]}" ] || continue
    _dest="${ENTRY_DESTS[$_i]}"
    _status_rc=0
    _porcelain="$(LC_ALL=C git -C "$_dest" status --porcelain 2>"$_status_err")" || _status_rc=$?
    if [ "$_status_rc" -ne 0 ] || grep -q 'Permission denied' "$_status_err"; then
        UNREAD_DESTS+=("$_dest")
        UNREAD_WHY+=("$(grep -m1 . "$_status_err" || echo "git status exited $_status_rc")")
    elif [ -n "$_porcelain" ]; then
        DIRTY_DESTS+=("$_dest")
    fi
done
rm -f "$_status_err"

if [ "${#UNREAD_DESTS[@]}" -gt 0 ] && [ "$FORCE" != true ]; then
    for _i in "${!UNREAD_DESTS[@]}"; do
        echo "Error: cannot read all of ${UNREAD_DESTS[$_i]}, so this script cannot tell whether it holds uncommitted work; nothing was removed."
        echo "  git status: ${UNREAD_WHY[$_i]}"
    done
    echo "Give the folder it names back its owner permission by hand (chmod u+rwx on it) and run this command again, or use --force to remove anyway."
    exit 1
fi

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
# this touch another checkout. -xdev and the device test: a mount of
# another filesystem inside the tree is neither walked nor changed, its top
# folder included (-xdev alone stops below that folder but still lists it,
# and opening it would let `rm -rf` unlink what the mount holds). A bind
# mount from the same filesystem has the same device and is walked. This
# limits only what the chmod opens: `rm -rf` below still deletes into a
# mount it can already write, as it did before issue 428. `--`: a path is
# never read as an option.
# `-exec ... \;`, not `+`: each directory is repaired when find reaches it,
# before find tries to read it, so a directory under one that lacked r or
# x is reached too (a batched `+` runs after the walk, too late for that).
# A failed chmod does not stop the removal: the removal's own error is the
# one to show.
_make_dirs_writable() {  # <dir>
    [ -d "$1" ] && [ ! -L "$1" ] || return 0
    # The device number: GNU stat, else BSD stat. When neither gives it,
    # nothing is changed and the removal's own error shows.
    local dev
    dev="$(stat -c %d -- "$1" 2>/dev/null || stat -f %d -- "$1" 2>/dev/null)" || return 0
    find -P -- "$1" -xdev -type d ! -perm -u=rwx -exec sh -c '
        d="$(stat -c %d -- "$2" 2>/dev/null || stat -f %d -- "$2" 2>/dev/null)" &&
            [ "$d" = "$1" ] && chmod u+rwx -- "$2"
    ' _ "$dev" {} \; 2>/dev/null || true
}

# Once over the whole tree before any entry goes: a read-only container
# directory between the worktree and an entry (layer_ws/src, say) would
# otherwise make `git worktree remove` fail part way, after an earlier
# entry was already removed. Each entry of a package worktree is walked
# again on its own, which also reaches an entry on another filesystem,
# where the tree's walk stopped at that mount and left its top folder as
# it was; the single-entry shape's one entry is the tree itself, already
# walked.
_make_dirs_writable "$WORKTREE_DIR"

for _i in "${!ENTRY_DESTS[@]}"; do
    _dest="${ENTRY_DESTS[$_i]}"
    _owner="${ENTRY_OWNERS[$_i]}"
    [ -n "$_owner" ] || continue
    [ -d "$_dest" ] || continue
    [ "$_dest" = "$WORKTREE_DIR" ] || _make_dirs_writable "$_dest"
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
# simply left behind. Its directories were made writable before the
# entry loop, so nothing more is needed here.
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
