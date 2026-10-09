#!/bin/bash
# scripts/lock.sh
#
# Advisory workspace lock (`make lock` / `make unlock`). Locking writes
# .agent/scratchpad/workspace.lock (who, why, when); unlock.sh removes it.
# The only reader is dashboard.sh, which shows "Workspace is LOCKED" in its
# status output. Nothing else reads the file, so it does not stop any script
# or agent: it is a note for the people and agents who look at the dashboard.
# It is unrelated to the GitHub-issue task locking in
# .agent/WORKFORCE_PROTOCOL.md.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
LOCK_FILE="$ROOT_DIR/.agent/scratchpad/workspace.lock"

# Ensure .agent/scratchpad exists
mkdir -p "$ROOT_DIR/.agent/scratchpad"

if [ -f "$LOCK_FILE" ]; then
    echo "❌ Workspace is already LOCKED."
    echo "Lock info:"
    cat "$LOCK_FILE"
    exit 1
fi

REASON=${1:-"Unknown task"}
USER_ID=${USER:-"Agent"}
TIMESTAMP=$(date)

echo "LOCKED_BY=\"$USER_ID\"" > "$LOCK_FILE"
echo "REASON=\"$REASON\"" >> "$LOCK_FILE"
echo "TIMESTAMP=\"$TIMESTAMP\"" >> "$LOCK_FILE"

echo "LOCKED: Workspace locked by $USER_ID for: $REASON"
