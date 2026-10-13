#!/usr/bin/env bash
# .agent/scripts/session_root.sh
# The root of a session started in <dir>, and whether an issue belongs to
# it (ADR-0018 decision 6; docs/design.md, "Sessions and roots").
#
# The rule (owner, 2026-10-13): an agent works on stuff in the directory
# where it was launched. A session's root is the directory it was launched
# in -- the workspace checkout or a registered project root -- and it only
# changes things under that root. Work that belongs to another root becomes
# an issue (or an inbox line) there, not a fix from here. Reading across
# roots stays allowed. A multi-repo project's root is its registered
# hosting directory, never a package repository nested in it.
#
#   session_root.sh [--dir <dir>]
#       Prints the root of a session in <dir> (default: the current
#       directory) and exits 0:
#           root=<absolute pwd -P path>
#           type=workspace|project
#           project=<registered name>      (empty for the workspace)
#
#   session_root.sh [--dir <dir>] --type workspace|project [--project <name>]
#       Also resolves the root an issue of that --type/--project belongs to,
#       the way worktree_create.sh resolves it, and exits 1 -- naming the
#       directory to start a session in -- when it is not <dir>'s root.
#       On success it prints the same three lines.
#
# <dir>'s root: the registered root that contains it (longest match, so an
# instance beats its parent; registered roots before the workspace, so a
# root inside the workspace tree is its own root), or one whose
# worktrees= directory contains it, else the workspace checkout when <dir>
# is inside it or in its repository. Anywhere else: exit 1. A session
# there must also read that root's local settings -- be in the root's git
# repository, or be the root itself when it is in no git repository --
# or it exits 1 too: skill_prefix.sh refuses the same directories (a
# package repository nested in a root, a subdirectory of a no-git root).
#
# The issue's root, for --type project: --project <name> (a parent root
# becomes its default or only instance). Without --project, in a project
# session it is the session's own project -- callers then pass that name on
# as --project, so worktree_create.sh agrees -- and in a workspace session
# it follows worktree_create.sh's fallback: the legacy project/ checkout,
# else the single registered project.
# A parent root also owns its instances: an issue of an instance passes in
# a session started at the parent root. An unregistered legacy project/
# lives in the workspace tree, so its root is the workspace.
#
# Worktrees live under their root, so a session that keeps to this rule
# stays under its root. Callers read this, and skill_prefix.sh, once,
# before the run enters any worktree.
#
# Exits 1 with the reason on stderr; 2 on a usage or registry parse error.
#
# user-tier: inert -- read-only: prints a verdict on stdout (or the reason
# on stderr) and writes nothing; no gh call and no repo-changing git call.
# Outside the workspace and every registered root it exits 1 saying so,
# which is its job, so a registry_require_root guard would only replace
# that message with a less useful one (test_user_tier_guard.sh checks it).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The main checkout, resolved the way dispatch_phase.sh resolves it (#146),
# not $SCRIPT_DIR/../..: a copy of this script in a worktree of the
# workspace (the `|| echo .` fallback in a session launched in one) would
# otherwise read that worktree's registry, which does not exist
# (projects.local is gitignored). Outside any git repository, the
# script's own checkout.
WS_ROOT="$({ git -C "$SCRIPT_DIR" worktree list --porcelain 2>/dev/null | head -n1 | sed 's/^worktree //'; } || true)"
[[ -n "$WS_ROOT" ]] || WS_ROOT="$SCRIPT_DIR/../.."
WS_ROOT="$(cd "$WS_ROOT" && pwd -P)"
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

usage() {
    echo "usage: session_root.sh [--dir <dir>] [--type workspace|project [--project <name>]]" >&2
    exit 2
}

DIR="$PWD"
TYPE=""
PROJECT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)     [[ $# -ge 2 && -n "$2" ]] || usage; DIR="$2"; shift 2 ;;
        --type)    [[ $# -ge 2 && -n "$2" ]] || usage; TYPE="$2"; shift 2 ;;
        --project) [[ $# -ge 2 && -n "$2" ]] || usage; PROJECT="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,/^set -uo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'
            exit 0 ;;
        *) usage ;;
    esac
done
case "$TYPE" in
    ""|workspace|project) ;;
    *) usage ;;
esac
[[ -n "$PROJECT" && "$TYPE" != "project" ]] && usage

phys() { (cd "$1" 2>/dev/null && pwd -P); }

# The pwd -P form of the git common dir <dir> belongs to (shared by a
# repository's main worktree, its linked worktrees and every plain
# directory in it); empty when <dir> is in no git repository.
common_dir() {  # <dir>
    local c
    c="$(cd "$1" 2>/dev/null && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
    [[ -n "$c" ]] || return 0
    phys "$c"
}
# A linked worktree of the workspace is the workspace's, wherever it lives.
WS_REPO="$(common_dir "$WS_ROOT")"

if ! DIR_PHYS="$(phys "$DIR")"; then
    echo "session_root: $DIR is not a directory" >&2
    exit 1
fi

ENTRIES="$(registry_entries_full "$WS_ROOT")" || {
    echo "session_root: cannot parse $(registry_file "$WS_ROOT")" >&2
    exit 2
}

# root_of <abs dir>: prints "<type>US<name>US<root abs>" (US = the unit
# separator, not whitespace, so an empty name survives `read`) for the root
# that owns <dir>, or returns 1.
US=$'\x1f'
root_of() {
    local d="$1" entry rc=0 name _type path rp best=""
    entry="$(registry_resolve_session_dir "$WS_ROOT" "$d")" || rc=$?
    [[ $rc -eq 2 ]] && return 2
    if [[ $rc -eq 0 ]]; then
        IFS=$'\t' read -r name _type path <<< "$entry"
        rp="$(phys "$path")" && best="project${US}${name}${US}${rp}"
    fi
    if [[ -z "$best" ]] && { [[ "$d" == "$WS_ROOT" || "$d" == "$WS_ROOT"/* ]] \
            || [[ -n "$WS_REPO" && "$(common_dir "$d")" == "$WS_REPO" ]]; }; then
        best="workspace${US}${US}${WS_ROOT}"
    fi
    [[ -n "$best" ]] || return 1
    printf '%s\n' "$best"
}

if ! SESSION="$(root_of "$DIR_PHYS")"; then
    echo "session_root: $DIR_PHYS is neither in the workspace checkout ($WS_ROOT) nor under a registered project root ($(registry_file "$WS_ROOT")), so it is no session's root -- start the session in the workspace checkout or a registered project root" >&2
    exit 1
fi
IFS="$US" read -r S_TYPE S_NAME S_ROOT <<< "$SESSION"

# A session reads the local settings of its own project root: its git
# repository (the main one, for a worktree), or its own directory outside
# git. Unless that is the root's, neither the root's plugin nor its layer
# reaches the session, so it is no place to work from -- the same
# directories skill_prefix.sh refuses (a package repository nested in a
# root, a subdirectory of a root in no git repository), with the same
# advice.
S_REPO="$(common_dir "$S_ROOT")"
if [[ -n "$S_REPO" && "$(common_dir "$DIR_PHYS")" != "$S_REPO" ]] \
        || [[ -z "$S_REPO" && "$DIR_PHYS" != "$S_ROOT" ]]; then
    echo "session_root: $DIR_PHYS lies under the root $S_ROOT, but a session there does not read that root's local settings (its project root is its own git repository, or its own directory) -- start the session at $S_ROOT or a worktree of it" >&2
    exit 1
fi

report() {
    echo "root=$S_ROOT"
    echo "type=$S_TYPE"
    echo "project=$S_NAME"
}

if [[ -z "$TYPE" ]]; then
    report
    exit 0
fi

# --- the issue's root ------------------------------------------------------
[[ "$TYPE" == "project" && -z "$PROJECT" && "$S_TYPE" == "project" ]] && PROJECT="$S_NAME"
if [[ "$TYPE" == "workspace" ]]; then
    ISSUE_DIR="$WS_ROOT"
    ISSUE_WHAT="a workspace issue"
elif [[ -n "$PROJECT" ]]; then
    rc=0
    entry="$(registry_lookup "$WS_ROOT" "$PROJECT")" || rc=$?
    if [[ $rc -ne 0 ]]; then
        [[ $rc -eq 2 ]] && exit 2
        echo "session_root: project '$PROJECT' is not registered in $(registry_file "$WS_ROOT")" >&2
        exit 1
    fi
    name="$(registry_resolve_project_arg "$WS_ROOT" "$PROJECT")" || exit 1
    entry="$(registry_lookup "$WS_ROOT" "$name")" || exit 1
    ISSUE_DIR="$(cut -f2 <<< "$entry")"
    ISSUE_WHAT="an issue of project '$name'"
elif [[ -d "$WS_ROOT/project" ]] && git -C "$WS_ROOT/project" rev-parse --git-dir >/dev/null 2>&1; then
    # Hosted by the workspace whatever project/ points at (it may be a
    # symlink): its worktrees go under the workspace's worktrees/project/.
    ISSUE_DIR="$WS_ROOT"
    ISSUE_WHAT="an issue of the legacy project/ checkout"
else
    singles="$(awk -F'\t' -v p="$REGISTRY_PARENT_TYPE" 'NF && $2 != p' <<< "$ENTRIES")"
    count=0
    [[ -n "$singles" ]] && count="$(wc -l <<< "$singles")"
    if [[ "$count" -ne 1 ]]; then
        echo "session_root: --type project names no project here (no legacy project/ and $count registered projects) -- pass --project <name>" >&2
        exit 1
    fi
    ISSUE_DIR="$(cut -f3 <<< "$singles")"
    ISSUE_WHAT="an issue of project '$(cut -f1 <<< "$singles")'"
fi

if ! ISSUE_PHYS="$(phys "$ISSUE_DIR")" || ! ISSUE="$(root_of "$ISSUE_PHYS")"; then
    echo "session_root: the checkout for $ISSUE_WHAT ($ISSUE_DIR) is not on disk" >&2
    exit 1
fi
IFS="$US" read -r I_TYPE I_NAME I_ROOT <<< "$ISSUE"

if [[ "$I_ROOT" == "$S_ROOT" ]]; then
    report
    exit 0
fi
# A parent root owns its instances.
if [[ "$S_TYPE" == "project" && "$I_TYPE" == "project" ]] \
        && [[ "$(registry_field "$WS_ROOT" "$I_NAME" parent 2>/dev/null)" == "$S_NAME" ]]; then
    report
    exit 0
fi

echo "session_root: $ISSUE_WHAT belongs to the root $I_ROOT, but this session's root is $S_ROOT. A session works only under the root it was launched in: start a session in $I_ROOT for this issue, or open an issue (or an inbox line) there instead of fixing it from here." >&2
exit 1
