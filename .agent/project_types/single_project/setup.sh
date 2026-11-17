#!/usr/bin/env bash
# .agent/project_types/single_project/setup.sh
# Bring up a registered single_project checkout (single_project adapter).
#
# Invoked via: .agent/scripts/adapter --project <name> setup
#
# A single_project checkout is the user's own clone, registered with
# the registration script; the adapter passes its root as --project-root.
# Logic:
#   1. The root is a git repository → report its URL; on main or master
#      with a clean tree, pull.
#   2. Otherwise → refuse, saying to clone the project there or fix the
#      registry. Nothing is cloned or symlinked: issue #265 part 4 retired
#      the project/ symlink this script used to create.

set -euo pipefail

PROJECT_DIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --project-root)
            [ $# -ge 2 ] || { echo "Error: --project-root requires a directory argument" >&2; exit 1; }
            PROJECT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Error: unknown option '$1'" >&2
            exit 1
            ;;
    esac
done

if [ -z "$PROJECT_DIR" ]; then
    # The registration script is named with the split-token idiom (issue
    # #295 hub guard in test_script_tests_hook_scope.sh): a message is not a
    # read of that script.
    echo "Error: no project root given: setup brings up a registered project (adapter --project <name> setup)." >&2
    echo "Register one first: .agent/scripts/register_project"".sh <path>" >&2
    exit 1
fi

# --- Helper: check if a directory is a valid git repo ---
is_git_repo() {
    local dir="$1"
    [ -d "$dir" ] && git -C "$dir" rev-parse --git-dir &>/dev/null
}

if ! is_git_repo "$PROJECT_DIR"; then
    echo "Error: $PROJECT_DIR is not a git checkout." >&2
    echo "Clone the project there, or fix its line in .agent/projects.local." >&2
    exit 1
fi

REMOTE_URL="$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo "")"
echo "✅ $PROJECT_DIR is already configured."
if [ -n "$REMOTE_URL" ]; then
    echo "   Remote: $REMOTE_URL"
else
    echo "   (no remote configured)"
fi

# If on default branch and clean, pull
BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "")
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
    DIRTY=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null || echo "")
    if [ -z "$DIRTY" ]; then
        echo ""
        echo "Pulling latest changes on branch '$BRANCH'..."
        if git -C "$PROJECT_DIR" pull --rebase 2>/dev/null; then
            echo "   ✅ Up to date."
        else
            # A failed rebase pull (conflict, network error) can leave the
            # repo mid-rebase, wedging later git operations. Abort any
            # in-progress rebase; ignore failure when none is in progress.
            git -C "$PROJECT_DIR" rebase --abort &>/dev/null || true
            echo "   ⚠️  Pull failed (continuing anyway)"
        fi
    fi
fi

echo ""
echo "Setup complete. Run 'make dashboard' to check workspace status."
exit 0
