#!/usr/bin/env bash
# .agent/scripts/capture.sh
# Append one thought to this machine's inbox as a single line (issue #386).
#
# Usage: capture.sh "<text>"
#   Several arguments are joined with spaces.
#
# The line is:  <date>\t<project>\t<issue>\t<text>
#   date     local time with offset, `YYYY-MM-DD HH:MM +ZZZZ`
#   project  the registered project the cwd is in, else `workspace` when the
#            cwd is inside this workspace checkout or any checkout of the
#            same repository (the main checkout or a linked worktree), else
#            `none`; `unknown` when the registry cannot be read (the line is
#            still written). The registry read is this checkout's
#            .agent/projects.local, or, when this is a linked worktree
#            without one, the main checkout's (the same fallback as the
#            settings file).
#   issue    $WORKTREE_ISSUE, else N from a `feature/issue-N` or
#            `feature/ISSUE-N-...` branch at the cwd, else `-`
#   text     tabs, CRs and newlines collapsed to single spaces
#
# The inbox path is the `inbox` key of .agent/settings.local (see
# _settings.sh and .agent/settings.local.example). The script creates the
# file but never its directory. It never calls gh, git-bug or any issue
# creator: capturing a thought is not filing it.
#
# Parallel callers: the line is written while holding an exclusive `flock`
# on the inbox (10 s wait), because bash writes a line longer than 4 KB in
# several write() calls that another caller's line could land between.
# Without `flock` (macOS by default) the write is unlocked, and lines over
# 4 KB from simultaneous captures can interleave.
#
# Exit codes:
#   0  saved
#   1  not saved: inbox not set, or the inbox could not be written. The text
#      is printed back after `not saved:` so it can be pasted elsewhere.
#   2  usage (no text)

set -uo pipefail

# -P: through the repo-root `scripts/` symlink, a logical path's `../..`
# would be the checkout's parent.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

# shellcheck source=_settings.sh
source "$SCRIPT_DIR/_settings.sh"

shopt -s extglob
text="$*"
text="${text//+([$'\t\r\n'])/ }"
text="${text##+([[:space:]])}"
text="${text%%+([[:space:]])}"
if [ -z "$text" ]; then
    echo "usage: capture.sh \"<text>\"" >&2
    exit 2
fi

not_saved() {
    echo "$1" >&2
    printf 'not saved: %s\n' "$text"
    exit 1
}

if ! inbox="$(settings_path "$ROOT" inbox)"; then
    looked="$(settings_candidates "$ROOT" | sed 's/^/  /')"
    not_saved "inbox not set: add a line 'inbox=<path>' to the settings file (template: .agent/settings.local.example). Looked in:
$looked"
fi

inbox_dir="$(dirname "$inbox")"
[ -d "$inbox_dir" ] || not_saved "inbox directory does not exist: $inbox_dir"

# --- project ---
# git_common <dir>: the absolute git common dir of <dir>'s repository (the
# main checkout's .git for every linked worktree too); returns 1 outside git.
git_common() {
    local d
    d="$(cd "$1" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)" || return 1
    [ -n "$d" ] || return 1
    (cd "$1" && cd "$d" 2>/dev/null && pwd -P)
}
ws_common="$(git_common "$ROOT")" || ws_common=""
reg_root="$ROOT"
if [ ! -f "$ROOT/.agent/projects.local" ] && [ -n "$ws_common" ] \
    && [ -f "$(dirname "$ws_common")/.agent/projects.local" ]; then
    reg_root="$(dirname "$ws_common")"
fi

project="unknown"
# shellcheck source=_project_registry.sh
if source "$SCRIPT_DIR/_project_registry.sh" 2>/dev/null; then
    rc=0
    derived="$(registry_derive_type_from_dir "$reg_root" "$PWD" 2>/dev/null)" || rc=$?
    case "$rc" in
        0)
            if [ "${derived%%$'\t'*}" = "project" ]; then
                project="${derived#*$'\t'}"
            else
                project="workspace"
            fi
            ;;
        1)
            project="none"
            cwd_abs="$(pwd -P)"
            if [ "$cwd_abs" = "$ROOT" ] || [[ "$cwd_abs" == "$ROOT/"* ]]; then
                project="workspace"
            elif [ -n "$ws_common" ] && [ "$(git_common "$cwd_abs" 2>/dev/null)" = "$ws_common" ]; then
                project="workspace"
            fi
            ;;
        *) project="unknown" ;;
    esac
fi

# --- issue ---
issue="-"
if [[ "${WORKTREE_ISSUE:-}" =~ ^[0-9]+$ ]]; then
    issue="$WORKTREE_ISSUE"
else
    branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [[ "$branch" =~ ^feature/(issue|ISSUE)-([0-9]+)(-.*)?$ ]]; then
        issue="${BASH_REMATCH[2]}"
    fi
fi

line="$(date '+%Y-%m-%d %H:%M %z')"$'\t'"$project"$'\t'"$issue"$'\t'"$text"

[ ! -d "$inbox" ] || not_saved "the inbox is a directory: $inbox"

# write_line: called with fd 9 open for append on the inbox. Holds the
# lock (see the header) for the one printf.
write_line() {
    if command -v flock >/dev/null 2>&1; then
        flock -x -w 10 9 || { echo "inbox is locked by another writer: $inbox" >&2; return 3; }
    fi
    printf '%s\n' "$line" >&9
}
rc=0
{ write_line 9>>"$inbox"; } 2>/dev/null || rc=$?
case "$rc" in
    0) ;;
    3) not_saved "the inbox stayed locked for 10 s: $inbox" ;;
    *) not_saved "could not write to the inbox: $inbox" ;;
esac
echo "saved to $inbox"
