#!/usr/bin/env bash
# .agent/scripts/skill_prefix.sh
# How workspace skills are named in a Claude Code session started in <dir>
# (ADR-0018 decision 6). A location rule, decided from the filesystem and
# the registry alone -- never from a placeholder the model has to copy.
#
#   skill_prefix.sh [--dir <dir>]      (default: the current directory)
#
# Prints one line on stdout and exits 0:
#   skill_prefix=                   bare names (/review-code). <dir> is in
#                                   the workspace checkout's git repository
#                                   -- the checkout, a worktree of it, or a
#                                   registered root inside its tree with no
#                                   .git of its own (the p11-* shape). The
#                                   installer never enables the plugin
#                                   there: the plugin's source IS this
#                                   checkout's .claude/skills, so it would
#                                   load every shipped skill twice.
#   skill_prefix=agent-workspace:   plugin names (/agent-workspace:review-code).
#                                   A session in <dir> reads the local
#                                   settings of a registered root, which is
#                                   where the installer enables the plugin.
# Exits 1 with the reason on stderr, printing nothing on stdout, when
# neither holds: <dir> is under no registered root, or its sessions read no
# registered root's local settings (e.g. a git repository nested in a root,
# such as a colcon package under src/). Live case G observed that such a
# repository does not see the root's plugin; whether the workspace's bare
# skills reach one under a root inside the workspace tree (directory
# walk-up) has not been checked. A caller stops there rather than guess. Exits 2 on a usage error.
#
# Which directories read a root's local settings follows what the live
# suite observed (tests/live/plugin_acceptance.sh case G, claude 2.1.282):
# a session reads the local settings of its project root, which is its git
# toplevel (the main repository's, for a worktree), or its own directory
# when it is in no git repository. The installer's same_project() is the
# same rule.

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
WS_ROOT="$(cd "$WS_ROOT" && pwd)"
# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

DIR="$PWD"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            [[ $# -ge 2 && -n "$2" ]] || { echo "usage: skill_prefix.sh [--dir <dir>]" >&2; exit 2; }
            DIR="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,/^set -uo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'
            exit 0 ;;
        *)
            echo "usage: skill_prefix.sh [--dir <dir>]" >&2
            exit 2 ;;
    esac
done

if ! DIR_PHYS="$(cd "$DIR" 2>/dev/null && pwd -P)"; then
    echo "skill_prefix: $DIR is not a directory" >&2
    exit 1
fi

# The repository <dir> belongs to, as the pwd -P form of its git common dir
# (shared by a repository's main worktree, its linked worktrees and every
# plain directory in it); empty when <dir> is in no git repository.
common_dir() {  # <dir>
    local c
    c="$(cd "$1" 2>/dev/null && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
    [[ -n "$c" ]] || return 0
    (cd "$c" 2>/dev/null && pwd -P)
}

# 1. In the workspace checkout's own repository: bare.
dir_repo="$(common_dir "$DIR_PHYS")"
ws_repo="$(common_dir "$WS_ROOT")"
if [[ -n "$dir_repo" && -n "$ws_repo" && "$dir_repo" == "$ws_repo" ]]; then
    echo "skill_prefix="
    exit 0
fi

# 2. Reading a registered root's local settings: the plugin's names. A root
#    in git reaches every directory of the same repository; a root in no
#    git repository reaches only sessions started in that directory.
entries="$(registry_entries_full "$WS_ROOT" 2>/dev/null)" || true
under=""
while IFS=$'\t' read -r name _type path _fields; do
    [[ -n "$name" ]] || continue
    root_phys="$(cd "$path" 2>/dev/null && pwd -P)" || continue
    root_repo="$(common_dir "$root_phys")"
    if [[ -n "$root_repo" ]]; then
        if [[ -n "$dir_repo" && "$dir_repo" == "$root_repo" ]]; then
            echo "skill_prefix=agent-workspace:"
            exit 0
        fi
    elif [[ "$DIR_PHYS" == "$root_phys" ]]; then
        echo "skill_prefix=agent-workspace:"
        exit 0
    fi
    if [[ "$DIR_PHYS" == "$root_phys"/* && -z "$under" ]]; then
        under="$name ($root_phys)"
    fi
done <<< "$entries"

if [[ -n "$under" ]]; then
    echo "skill_prefix: $DIR_PHYS lies under the registered root $under, but a session there does not read that root's local settings (its project root is its own git repository, or its own directory), so the plugin enabled at that root does not reach it (observed, live case G); whether the workspace's bare skills do has not been checked -- start the session at a registered root or a worktree of one" >&2
else
    echo "skill_prefix: $DIR_PHYS is neither in the workspace checkout ($WS_ROOT) nor in any registered project root, so there is no rule for how workspace skills are named there -- register the project (.agent/projects.local) or start the session in a registered root" >&2
fi
exit 1
