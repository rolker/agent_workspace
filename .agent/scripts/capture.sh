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
#            cwd is inside this workspace checkout, else `none`; `unknown`
#            when the registry cannot be read (the line is still written)
#   issue    $WORKTREE_ISSUE, else N from a `feature/issue-N` or
#            `feature/ISSUE-N-...` branch at the cwd, else `-`
#   text     tabs, CRs and newlines collapsed to single spaces
#
# The inbox path is the `inbox` key of .agent/settings.local (see
# _settings.sh and .agent/settings.local.example). The script creates the
# file but never its directory. It never calls gh, git-bug or any issue
# creator: capturing a thought is not filing it.
#
# Exit codes:
#   0  saved
#   1  not saved: inbox not set, or the inbox could not be written. The text
#      is printed back after `not saved:` so it can be pasted elsewhere.
#   2  usage (no text)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
project="unknown"
# shellcheck source=_project_registry.sh
if source "$SCRIPT_DIR/_project_registry.sh" 2>/dev/null; then
    rc=0
    derived="$(registry_derive_type_from_dir "$ROOT" "$PWD" 2>/dev/null)" || rc=$?
    case "$rc" in
        0)
            if [ "${derived%%$'\t'*}" = "project" ]; then
                project="${derived#*$'\t'}"
            else
                project="workspace"
            fi
            ;;
        1) project="none" ;;
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

# One printf, one append: a single O_APPEND write, so parallel callers
# never interleave within a line.
if ! { printf '%s\n' "$line" >> "$inbox"; } 2>/dev/null; then
    not_saved "could not write to the inbox: $inbox"
fi
echo "saved to $inbox"
