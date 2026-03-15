#!/usr/bin/env bash
# .agent/scripts/test.sh
# Run the project test command.
#
# Reads TEST_CMD from .agent/project_config.sh (gitignored, per-developer).
# If project_config.sh is missing or TEST_CMD is unset, prints a helpful message.
#
# Usage:
#   .agent/scripts/test.sh [args...]
#   (or via: make test)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_FILE="$ROOT_DIR/.agent/project_config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ No project_config.sh found."
    echo ""
    echo "Create $CONFIG_FILE with your test command:"
    echo ""
    echo "  cat > .agent/project_config.sh << 'EOF'"
    echo "  # Per-developer project configuration (gitignored)"
    echo "  BUILD_CMD=\"make\"          # or: cmake --build build, cargo build, etc."
    echo "  TEST_CMD=\"make test\"      # or: cargo test, pytest, etc."
    echo "  EOF"
    echo ""
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

if [ -z "${TEST_CMD:-}" ]; then
    echo "❌ TEST_CMD is not set in $CONFIG_FILE"
    echo ""
    echo "Add to $CONFIG_FILE:"
    echo "  TEST_CMD=\"make test\"   # or your project's test command"
    echo ""
    exit 1
fi

echo "Running: $TEST_CMD $*"
echo ""
# Run in project directory
cd "$ROOT_DIR/project"
# shellcheck disable=SC2086
exec $TEST_CMD "$@"
