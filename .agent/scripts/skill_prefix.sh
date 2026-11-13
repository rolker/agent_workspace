#!/usr/bin/env bash
# .agent/scripts/skill_prefix.sh
# How workspace skills are named in a Claude Code session started in <dir>
# (ADR-0018 decision 6). A location rule, decided from the filesystem
# alone -- never from a placeholder the model has to copy.
#
#   skill_prefix.sh [--dir <dir>]      (default: the current directory)
#
# Prints one line on stdout and exits 0:
#   skill_prefix=                   bare names (/review-code). <dir> is in
#                                   the workspace checkout's git repository
#                                   -- the checkout, a worktree of it, a
#                                   plain subdirectory of either, or a
#                                   registered root inside its tree with no
#                                   .git of its own (the p11-* shape). The
#                                   bare name is the workspace's own skill
#                                   there (directory walk-up).
#   skill_prefix=agent-workspace:   plugin names (/agent-workspace:review-code),
#                                   anywhere else: a registered root, a git
#                                   repository nested in one (a colcon
#                                   package under src/), or an unregistered
#                                   folder. The plugin is enabled once, at
#                                   user scope, so it reaches every session
#                                   on the machine; a project that sets it
#                                   to false in its own settings has opted
#                                   out, and then neither name exists there.
#
# What a session lists in the workspace's own repository (live suite,
# tests/live/plugin_acceptance.sh, claude 2.1.323, 2026-11-12): the
# checkout's tracked .claude/settings.json sets the plugin to false, so a
# session at the checkout's root or in a worktree of it lists each shipped
# skill once, bare. A session started in a subdirectory of the checkout --
# a plain subdirectory, or a registered root inside its tree with no .git
# of its own -- lists each shipped skill under both names, bare and
# /agent-workspace:<skill>; both run the same skill (the plugin's source
# is this checkout's .claude/skills). The owner accepted that doubling on
# 2026-11-12. This script answers bare there: the bare name works.
#
# Exits 1 with the reason on stderr only when <dir> is not a directory;
# exits 2 on a usage error.
#
# user-tier: inert -- read-only: prints a verdict on stdout (or the reason
# on stderr) and writes nothing; no gh call and no repo-changing git call.
# It answers for every directory, inside a registered root or not, so a
# registry_require_root guard would only refuse what it can answer
# (test_user_tier_guard.sh checks it).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The main checkout, resolved the way dispatch_phase.sh resolves it (#146),
# not $SCRIPT_DIR/../..: a copy of this script in a worktree of the
# workspace (the `|| echo .` fallback in a session launched in one) is
# still the workspace's. Outside any git repository, the script's own
# checkout.
WS_ROOT="$({ git -C "$SCRIPT_DIR" worktree list --porcelain 2>/dev/null | head -n1 | sed 's/^worktree //'; } || true)"
[[ -n "$WS_ROOT" ]] || WS_ROOT="$SCRIPT_DIR/../.."
WS_ROOT="$(cd "$WS_ROOT" && pwd -P)"

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

dir_repo="$(common_dir "$DIR_PHYS")"
ws_repo="$(common_dir "$WS_ROOT")"
if [[ -n "$ws_repo" ]]; then
    [[ -n "$dir_repo" && "$dir_repo" == "$ws_repo" ]] && { echo "skill_prefix="; exit 0; }
elif [[ "$DIR_PHYS" == "$WS_ROOT" || "$DIR_PHYS" == "$WS_ROOT"/* ]]; then
    # A checkout in no git repository: its own tree.
    echo "skill_prefix="
    exit 0
fi
echo "skill_prefix=agent-workspace:"
exit 0
