#!/usr/bin/env bash
# .agent/scripts/build.sh
# Run the project build command.
#
# Reads BUILD_CMD from .agent/project_config.sh (gitignored, per-developer).
# If project_config.sh is missing or BUILD_CMD is unset, prints a helpful message.
#
# Usage:
#   .agent/scripts/build.sh [args...]
#   (or via: make build)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_FILE="$ROOT_DIR/.agent/project_config.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ No project_config.sh found."
    echo ""
    echo "Create $CONFIG_FILE with your build command:"
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

if [ -z "${BUILD_CMD:-}" ]; then
    echo "❌ BUILD_CMD is not set in $CONFIG_FILE"
    echo ""
    echo "Add to $CONFIG_FILE:"
    echo "  BUILD_CMD=\"make\"   # or your project's build command"
    echo ""
    exit 1
fi

echo "Running: $BUILD_CMD $*"
echo ""
# Run in project directory
cd "$ROOT_DIR/project"
# shellcheck disable=SC2086
exec $BUILD_CMD "$@"
