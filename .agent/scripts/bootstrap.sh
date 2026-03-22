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
echo "Checking for git-bug..."
GIT_BUG_VERSION="0.10.1"
GIT_BUG_BIN="/usr/local/bin/git-bug"
if [ ! -x "$GIT_BUG_BIN" ] || ! "$GIT_BUG_BIN" version 2>/dev/null | grep -q "$GIT_BUG_VERSION"; then
    ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    # Pinned checksums — git-bug releases don't publish .sha256 files
    declare -A GIT_BUG_SHA256=(
        [amd64]="3ba2f8b41e526fef1b6e825d5030823be65bb6521a287b1139bd609fed0d54a1"
    )
    GIT_BUG_URL="https://github.com/git-bug/git-bug/releases/download/v${GIT_BUG_VERSION}/git-bug_linux_${ARCH}"
    echo "Installing git-bug v${GIT_BUG_VERSION}..."
    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY-RUN] Would download git-bug from ${GIT_BUG_URL}"
        EXPECTED="${GIT_BUG_SHA256[$ARCH]:-}"
        if [ -n "$EXPECTED" ]; then
            echo "[DRY-RUN] Would verify checksum '${EXPECTED}' for git-bug_linux_${ARCH}"
        else
            echo "  ⚠️  No pinned checksum for arch '${ARCH}' — would skip verification"
        fi
        echo "[DRY-RUN] Would install git-bug to ${GIT_BUG_BIN}"
    else
        curl -fL -o /tmp/git-bug "$GIT_BUG_URL"
        EXPECTED="${GIT_BUG_SHA256[$ARCH]:-}"
        if [ -n "$EXPECTED" ]; then
            ACTUAL=$(sha256sum /tmp/git-bug | awk '{print $1}')
            if [ "$ACTUAL" != "$EXPECTED" ]; then
                echo "  ❌ Checksum mismatch for git-bug_linux_${ARCH}"
                echo "     Expected: $EXPECTED"
                echo "     Got:      $ACTUAL"
                rm -f /tmp/git-bug
                exit 1
            fi
            echo "  ✅ Checksum verified"
        else
            echo "  ⚠️  No pinned checksum for arch '${ARCH}' — skipping verification"
        fi
        chmod +x /tmp/git-bug
        mv /tmp/git-bug "$GIT_BUG_BIN"
        echo "  ✅ git-bug v${GIT_BUG_VERSION} installed"
    fi
else
    echo "  ✅ git-bug v${GIT_BUG_VERSION} already installed"
fi

echo ""
echo "Bootstrap complete."
echo ""
echo "Next steps:"
echo "  1. Authenticate GitHub CLI: gh auth login"
echo "  2. Run setup: make setup"
echo "  3. Configure build/test: edit .agent/project_config.sh"
echo "  Note: To skip git-bug setup, run: make skip-git-bug"
