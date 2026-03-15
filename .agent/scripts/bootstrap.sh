#!/usr/bin/env bash
# .agent/scripts/bootstrap.sh
# Install system-level prerequisites for the agent workspace.
#
# Run this once on a fresh machine before running 'make setup'.
# Requires sudo.
#
# Usage:
#   sudo .agent/scripts/bootstrap.sh
#   # or with dry-run:
#   DRY_RUN=1 .agent/scripts/bootstrap.sh

set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

run() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

echo "=== Agent Workspace Bootstrap ==="
echo ""

# Check for apt (Debian/Ubuntu)
if ! command -v apt-get &>/dev/null; then
    echo "This script requires apt-get (Debian/Ubuntu). Adjust for your distro."
    exit 1
fi

echo "Installing system packages..."
run apt-get update -qq
run apt-get install -y \
    git \
    python3 \
    python3-venv \
    python3-pip \
    curl \
    jq

echo ""
echo "Checking for GitHub CLI (gh)..."
if ! command -v gh &>/dev/null; then
    echo "Installing GitHub CLI..."
    run curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
    run echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    run apt-get update -qq
    run apt-get install -y gh
    echo "  ✅ gh installed"
else
    echo "  ✅ gh already installed ($(gh --version | head -1))"
fi

echo ""
echo "Bootstrap complete."
echo ""
echo "Next steps:"
echo "  1. Authenticate GitHub CLI: gh auth login"
echo "  2. Run setup: make setup"
echo "  3. Configure build/test: edit .agent/project_config.sh"
