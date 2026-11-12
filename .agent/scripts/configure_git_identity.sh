#!/bin/bash
# .agent/scripts/configure_git_identity.sh
# Configures git identity for AI agents across workspace and all cloned repositories
#
# Usage:
#   ./configure_git_identity.sh "<Agent Name>" "<email>"
#   ./configure_git_identity.sh --agent <framework>
#   ./configure_git_identity.sh --detect
#
# Examples:
#   ./configure_git_identity.sh --agent copilot
#   ./configure_git_identity.sh --detect
#   ./configure_git_identity.sh "Copilot CLI Agent" "<you>+copilot-cli@<domain>"
#
# --agent and --detect derive the email per repository written to, from that
# repository's own git user.email (<local>+<framework-suffix>@<domain>; see
# framework_config.sh): a clone with its own address keeps it as its base.
# The address written keeps the same base, because the +suffix is removed
# when the base is derived again. Every address is derived before anything is
# written: an unset or malformed git email in any of the repositories fails
# with nothing written.

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error: This script should be executed, not sourced."
    echo "  Run: ${BASH_SOURCE[0]} $*"
    return 1
fi

# Load framework identity lookup table from shared configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_CONFIG="${SCRIPT_DIR}/framework_config.sh"

if [ -f "${FRAMEWORK_CONFIG}" ]; then
    # shellcheck source=/dev/null
    source "${FRAMEWORK_CONFIG}"
else
    echo "❌ ERROR: Framework configuration not found at ${FRAMEWORK_CONFIG}."
    echo "This script expects FRAMEWORK_NAMES and FRAMEWORK_SUFFIXES to be defined in a shared config."
    exit 1
fi

# Add aliases for backward compatibility
FRAMEWORK_NAMES["copilot-cli"]="${FRAMEWORK_NAMES[copilot]}"
FRAMEWORK_SUFFIXES["copilot-cli"]="${FRAMEWORK_SUFFIXES[copilot]}"
FRAMEWORK_NAMES["gemini-cli"]="${FRAMEWORK_NAMES[gemini]}"
FRAMEWORK_SUFFIXES["gemini-cli"]="${FRAMEWORK_SUFFIXES[gemini]}"

show_usage() {
    echo "Usage: $0 [OPTIONS] [\"<Agent Name>\" \"<email>\"]"
    echo ""
    echo "Options:"
    echo "  --agent <framework>    Use predefined identity for framework"
    echo "                         Supported: codex, copilot, gemini, antigravity, claude, claude-code"
    echo "  --detect              Auto-detect framework from environment"
    echo ""
    echo "--agent and --detect derive the email from this checkout's git user.email:"
    echo "  <local>+<framework>@<domain>, where <local>@<domain> is \`git config user.email\`"
    echo "  with any +suffix removed."
    echo ""
    echo "Examples:"
    echo "  $0 --agent copilot"
    echo "  $0 --agent gemini"
    echo "  $0 --detect"
    echo "  $0 \"Copilot CLI Agent\" \"<you>+copilot-cli@<domain>\""
    echo ""
    echo "This configures git identity in:"
    echo "  - The workspace repository (agent_workspace)"
    echo "  - All repositories under project/"
}

# Auto-detect framework from environment
detect_framework() {
    # Source the detection script if available
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/detect_cli_env.sh" ]; then
        source "$SCRIPT_DIR/detect_cli_env.sh"
        echo "$AGENT_FRAMEWORK"
    else
        echo "unknown"
    fi
}

# Parse arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_usage
    exit 0
fi

if [ "$1" == "--agent" ]; then
    if [ $# -ne 2 ]; then
        echo "Error: --agent requires framework name"
        show_usage
        exit 1
    fi

    FRAMEWORK="${2,,}"  # Convert to lowercase
    AGENT_NAME="${FRAMEWORK_NAMES[$FRAMEWORK]}"

    if [ -z "$AGENT_NAME" ]; then
        echo "Error: Unknown framework '$2'"
        echo "Supported frameworks: ${!FRAMEWORK_NAMES[*]}"
        exit 1
    fi
    FW_KEY="$FRAMEWORK"

elif [ "$1" == "--detect" ]; then
    DETECTED=$(detect_framework)

    if [ "$DETECTED" == "unknown" ]; then
        echo "Error: Could not auto-detect framework"
        echo "Please use --agent <framework> or provide name/email manually"
        exit 1
    fi

    echo "Detected framework: $DETECTED"
    AGENT_NAME="${FRAMEWORK_NAMES[$DETECTED]}"
    if [ -z "$AGENT_NAME" ]; then
        echo "Error: no predefined identity for detected framework '$DETECTED'"
        echo "Please use --agent <framework> or provide name/email manually"
        exit 1
    fi
    FW_KEY="$DETECTED"

elif [ $# -eq 2 ]; then
    # Manual name and email
    AGENT_NAME="$1"
    AGENT_EMAIL="$2"
    FW_KEY=""
else
    echo "Error: Invalid arguments"
    show_usage
    exit 1
fi

# The repositories written to: the workspace (the current directory) and
# every repository under project/.
REPOS=(".")
if [ -d "project" ]; then
    while IFS= read -r git_dir; do
        REPOS+=("$(dirname "$git_dir")")
    done < <(find project -type d -name ".git" -not -path "*/worktrees/*")
fi

# Derive each repository's address before writing any (manual mode uses the
# given address everywhere).
declare -A REPO_EMAILS=()
for repo_dir in "${REPOS[@]}"; do
    if [ -n "$FW_KEY" ]; then
        if ! REPO_EMAILS["$repo_dir"]="$(cd "$repo_dir" && framework_email "$FW_KEY")"; then
            echo "Error: cannot derive the agent email for $repo_dir; nothing was written." >&2
            exit 1
        fi
    else
        REPO_EMAILS["$repo_dir"]="$AGENT_EMAIL"
    fi
done

echo "Configuring git identity for: $AGENT_NAME"
echo ""

# Configure workspace repository
echo "Configuring workspace repository..."
git config user.name "$AGENT_NAME"
git config user.email "${REPO_EMAILS[.]}"
echo "  ✓ Workspace repository configured <${REPO_EMAILS[.]}>"

# Configure all repositories in project/
if [ -d "project" ]; then
    REPO_COUNT=0
    for repo_dir in "${REPOS[@]}"; do
        [ "$repo_dir" = "." ] && continue
        echo "Configuring $repo_dir <${REPO_EMAILS[$repo_dir]}>..."

        # Capture failure but don't crash whole script immediately if one fails
        if ! git -C "$repo_dir" config user.name "$AGENT_NAME" || \
           ! git -C "$repo_dir" config user.email "${REPO_EMAILS[$repo_dir]}"; then
            echo "  ✗ Failed to configure $repo_dir" >&2
            continue
        fi
        ((REPO_COUNT++))
    done

    if [ $REPO_COUNT -gt 0 ]; then
        echo "  ✓ Configured $REPO_COUNT repositories in project/"
    else
        echo "  ℹ No repositories found in project/ yet"
    fi
else
    echo "  ℹ No project/ directory found yet"
fi

echo ""
echo "✅ Git identity configuration complete!"
echo ""
echo "Verification:"
echo "  Workspace: $(git config user.name) <$(git config user.email)>"
