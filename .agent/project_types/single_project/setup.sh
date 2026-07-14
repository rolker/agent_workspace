#!/usr/bin/env bash
# .agent/scripts/setup_project.sh
# Bootstrap the project/ directory.
#
# Logic:
#   1. If project/ exists and is a valid git repo → report URL, optionally pull
#   2. If project/ is empty or missing → prompt for URL or local path
#      - Local path → create symlink: ln -s <path> project
#      - Git URL    → clone: git clone <url> project/
#
# After setup, project/.git/config (or symlink target's .git/config) is the
# source of truth for the project URL.  No configs/ directory is needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

PROJECT_DIR="$ROOT_DIR/project"

# --- Helper: check if project/ is a valid git repo ---
is_git_repo() {
    local dir="$1"
    [ -d "$dir" ] && git -C "$dir" rev-parse --git-dir &>/dev/null
}

# --- Helper: get remote URL from a git repo ---
get_remote_url() {
    local dir="$1"
    git -C "$dir" remote get-url origin 2>/dev/null || echo ""
}

# --- Case 1: project/ already exists and is a valid git repo ---
if is_git_repo "$PROJECT_DIR"; then
    REMOTE_URL="$(get_remote_url "$PROJECT_DIR")"
    echo "✅ project/ is already configured."
    if [ -n "$REMOTE_URL" ]; then
        echo "   Remote: $REMOTE_URL"
    else
        echo "   (no remote configured)"
    fi

    # If on default branch and clean, offer to pull
    BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "")
    if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
        DIRTY=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null || echo "")
        if [ -z "$DIRTY" ]; then
            echo ""
            echo "Pulling latest changes on branch '$BRANCH'..."
            git -C "$PROJECT_DIR" pull --rebase 2>/dev/null && echo "   ✅ Up to date." || echo "   ⚠️  Pull failed (continuing anyway)"
        fi
    fi

    echo ""
    echo "Setup complete. Run 'make dashboard' to check workspace status."
    exit 0
fi

# --- Case 2: project/ is missing or empty — prompt for URL or path ---

echo "========================================"
echo "Project Setup"
echo "========================================"
echo ""
echo "No project configured yet."
echo ""
echo "Enter the git URL or local path to your project repository."
echo "  Examples:"
echo "    https://github.com/owner/repo.git"
echo "    git@github.com:owner/repo.git"
echo "    /path/to/existing/local/clone"
echo ""
printf "Project URL or path: "
read -r PROJECT_INPUT

if [ -z "$PROJECT_INPUT" ]; then
    echo "Error: no input provided. Aborting."
    exit 1
fi

# Detect if input is a local path
if [ -d "$PROJECT_INPUT" ]; then
    # Local path — validate it's a git repo
    if ! git -C "$PROJECT_INPUT" rev-parse --git-dir &>/dev/null; then
        echo "Error: '$PROJECT_INPUT' exists but is not a git repository."
        exit 1
    fi

    # Remove project/ if it's an empty placeholder directory
    if [ -d "$PROJECT_DIR" ] && [ -z "$(ls -A "$PROJECT_DIR" 2>/dev/null)" ]; then
        rmdir "$PROJECT_DIR"
    fi

    # Create symlink to avoid duplicating the repo on disk
    RESOLVED_PATH="$(cd "$PROJECT_INPUT" && pwd -P)"
    ln -s "$RESOLVED_PATH" "$PROJECT_DIR"
    echo ""
    echo "✅ Symlinked: project → $RESOLVED_PATH"
else
    # Treat as a git URL — clone it
    # Remove project/ if it's an empty placeholder directory
    if [ -d "$PROJECT_DIR" ] && [ -z "$(ls -A "$PROJECT_DIR" 2>/dev/null)" ]; then
        rmdir "$PROJECT_DIR"
    fi

    echo ""
    echo "Cloning '$PROJECT_INPUT'..."
    if git clone "$PROJECT_INPUT" "$PROJECT_DIR"; then
        echo ""
        echo "✅ Cloned to project/"
    else
        echo "Error: git clone failed."
        exit 1
    fi
fi

# Verify the result
if is_git_repo "$PROJECT_DIR"; then
    REMOTE_URL="$(get_remote_url "$PROJECT_DIR")"
    echo ""
    echo "Setup complete."
    if [ -n "$REMOTE_URL" ]; then
        echo "  Remote: $REMOTE_URL"
    fi
    echo ""
    echo "Run 'make dashboard' to check workspace status."
else
    echo "Error: project/ is still not a valid git repository after setup."
    exit 1
fi
