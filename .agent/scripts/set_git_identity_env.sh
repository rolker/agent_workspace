#!/bin/bash
# .agent/scripts/set_git_identity_env.sh
# Sets ephemeral git identity using environment variables (session-only, doesn't modify .git/config)
# Also exports agent model identity for signatures
#
# USAGE FOR HOST-BASED AGENTS (Codex CLI, Copilot CLI, Gemini CLI):
#   source .agent/scripts/set_git_identity_env.sh --agent <framework> ["<model>"]
#   source .agent/scripts/set_git_identity_env.sh --detect
#   source .agent/scripts/set_git_identity_env.sh "<Agent Name>" "<email>" ["<model>"]
#
# Examples:
#   source .agent/scripts/set_git_identity_env.sh --agent claude-code "<your-model-id>"
#   source .agent/scripts/set_git_identity_env.sh --agent copilot
#   source .agent/scripts/set_git_identity_env.sh --detect
#   source .agent/scripts/set_git_identity_env.sh "Copilot CLI Agent" "<you>+copilot-cli@<domain>" "Claude Sonnet 4.5"
#
# --agent and --detect derive the email from this checkout's git user.email
# (<local>@<domain>, clone value over global, any +suffix removed) as
# <local>+<framework-suffix>@<domain>; see framework_config.sh and
# identity_base.py. An unset or malformed git email fails with a message.
#
# On ANY failure (unset or malformed git email, unknown framework, bad
# arguments) the script unsets what it owns -- GIT_AUTHOR_NAME,
# GIT_AUTHOR_EMAIL, GIT_COMMITTER_NAME, GIT_COMMITTER_EMAIL, AGENT_NAME,
# AGENT_EMAIL, AGENT_MODEL, AGENT_FRAMEWORK -- and returns 1, so a failed
# re-source never leaves the previous session's identity (or a mix of old
# and new values) in the shell. Re-source successfully before committing.
#
# Source it in the checkout you commit in: the email derives from the git
# user.email resolved in the current directory, not in the repository a
# later `git -C <other>` commit targets.
#
# This sets identity ONLY for the current shell session without modifying .git/config.
# The user's .git/config remains unchanged, allowing them to commit as themselves afterward.
# Also exports AGENT_MODEL for use in AI signatures.
#
# IMPORTANT: Must be sourced (not executed) to export variables to current shell:
#   source .agent/scripts/set_git_identity_env.sh "..." "..." ["..."]   ✓ Correct
#   ./.agent/scripts/set_git_identity_env.sh "..." "..."                ✗ Wrong (variables won't persist)
# user-tier: inert -- this file only defines functions and environment
# variables; it performs no repo-affecting action, so it needs no
# registry_require_root guard (#265 PR 3, ADR-0016).

# Unset every variable this script exports; called before each failure
# return so a failed re-source leaves no stale or mixed identity.
_sgi_clear_identity() {
    unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL \
        AGENT_NAME AGENT_EMAIL AGENT_MODEL AGENT_FRAMEWORK
}

# Load framework identity lookup table from shared configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_CONFIG="${SCRIPT_DIR}/framework_config.sh"

if [ -f "${FRAMEWORK_CONFIG}" ]; then
    # shellcheck source=/dev/null
    source "${FRAMEWORK_CONFIG}"
else
    echo "❌ ERROR: Framework configuration not found at ${FRAMEWORK_CONFIG}."
    echo "This script expects FRAMEWORK_NAMES and FRAMEWORK_SUFFIXES to be defined in a shared config."
    _sgi_clear_identity
    return 1
fi

# Add aliases for backward compatibility
FRAMEWORK_NAMES["copilot-cli"]="${FRAMEWORK_NAMES[copilot]}"
FRAMEWORK_SUFFIXES["copilot-cli"]="${FRAMEWORK_SUFFIXES[copilot]}"
FRAMEWORK_MODELS["copilot-cli"]="${FRAMEWORK_MODELS[copilot]}"
FRAMEWORK_NAMES["gemini-cli"]="${FRAMEWORK_NAMES[gemini]}"
FRAMEWORK_SUFFIXES["gemini-cli"]="${FRAMEWORK_SUFFIXES[gemini]}"
FRAMEWORK_MODELS["gemini-cli"]="${FRAMEWORK_MODELS[gemini]}"

# Check if script is being sourced (not executed)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "❌ ERROR: This script must be sourced, not executed directly."
    echo ""
    echo "Correct usage:"
    echo "  source $0 --agent <framework> [\"<model>\"]"
    echo "  source $0 --detect"
    echo "  source $0 \"<Agent Name>\" \"<email>\" [\"<model>\"]"
    echo ""
    echo "Examples:"
    echo "  source $0 --agent codex \"gpt-5.4\""
    echo "  source $0 --agent copilot"
    echo "  source $0 --detect"
    echo "  source $0 \"Codex CLI Agent\" \"<you>+codex@<domain>\" \"gpt-5.4\""
    exit 1
fi

show_usage() {
    echo "Usage: source $0 [OPTIONS] [\"<Agent Name>\" \"<email>\" [\"<model>\"]]"
    echo ""
    echo "Options:"
    echo "  --agent <framework> [\"<model>\"]"
    echo "                         Use predefined identity for framework (model defaults to the table's)"
    echo "                         Supported: codex, copilot, gemini, antigravity, claude, claude-code"
    echo "  --detect              Auto-detect framework from environment"
    echo ""
    echo "--agent and --detect derive the email from this checkout's git user.email:"
    echo "  <local>+<framework>@<domain>, where <local>@<domain> is \`git config user.email\`"
    echo "  with any +suffix removed (a clone-level value wins over the global one)."
    echo ""
    echo "Examples:"
    echo "  source $0 --agent claude-code \"<your-model-id>\""
    echo "  source $0 --agent codex"
    echo "  source $0 --detect"
    echo "  source $0 \"Codex CLI Agent\" \"<you>+codex@<domain>\" \"gpt-5.4\""
    echo ""
    echo "This sets git identity ONLY for the current shell session using environment variables."
    echo "It does NOT modify .git/config, so the user's identity remains unchanged."
    echo "Also exports AGENT_NAME, AGENT_EMAIL, AGENT_MODEL, and AGENT_FRAMEWORK for use in signatures."
}

# Auto-detect framework
detect_framework() {
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
    _sgi_clear_identity
    return 1
fi

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_usage
    return 0
fi

if [ "$1" == "--agent" ]; then
    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
        echo "Error: --agent requires framework name (and optionally a model)"
        show_usage
        _sgi_clear_identity
        return 1
    fi

    FRAMEWORK="${2,,}"  # Convert to lowercase
    # An empty key is not a valid array subscript: test it first.
    if [ -z "$FRAMEWORK" ] || [ -z "${FRAMEWORK_NAMES[$FRAMEWORK]:-}" ]; then
        echo "Error: Unknown framework '$2'"
        echo "Supported frameworks: ${!FRAMEWORK_NAMES[*]}"
        _sgi_clear_identity
        return 1
    fi
    # Derive the email before assigning anything: a failure exports nothing.
    if ! _SGI_EMAIL="$(framework_email "$FRAMEWORK")"; then
        unset _SGI_EMAIL
        _sgi_clear_identity
        return 1
    fi

    AGENT_NAME="${FRAMEWORK_NAMES[$FRAMEWORK]}"
    AGENT_EMAIL="$_SGI_EMAIL"
    AGENT_MODEL="${3:-${FRAMEWORK_MODELS[$FRAMEWORK]}}"
    AGENT_FRAMEWORK="$FRAMEWORK"
    unset _SGI_EMAIL

elif [ "$1" == "--detect" ]; then
    DETECTED=$(detect_framework)

    if [ "$DETECTED" == "unknown" ]; then
        echo "Error: Could not auto-detect framework"
        echo "Please use --agent <framework> or provide name/email manually"
        _sgi_clear_identity
        return 1
    fi

    # Normalize framework name for lookup (remove -cli suffix from end only)
    FRAMEWORK_KEY="${DETECTED%-cli}"
    FRAMEWORK_KEY="${FRAMEWORK_KEY,,}"
    echo "Detected framework: $DETECTED"

    if [ -z "$FRAMEWORK_KEY" ] || [ -z "${FRAMEWORK_NAMES[$FRAMEWORK_KEY]:-}" ]; then
        echo "Error: no predefined identity for detected framework '$DETECTED'"
        echo "Please use --agent <framework> or provide name/email manually"
        _sgi_clear_identity
        return 1
    fi
    # Derive the email before assigning anything: a failure exports nothing.
    if ! _SGI_EMAIL="$(framework_email "$FRAMEWORK_KEY")"; then
        unset _SGI_EMAIL
        _sgi_clear_identity
        return 1
    fi

    AGENT_NAME="${FRAMEWORK_NAMES[$FRAMEWORK_KEY]}"
    AGENT_EMAIL="$_SGI_EMAIL"
    AGENT_MODEL="${FRAMEWORK_MODELS[$FRAMEWORK_KEY]}"
    AGENT_FRAMEWORK="$DETECTED"
    unset _SGI_EMAIL

elif [ $# -eq 2 ]; then
    # Manual name and email — detect framework for model
    AGENT_NAME="$1"
    AGENT_EMAIL="$2"
    DETECTED=$(detect_framework)
    if [ "$DETECTED" != "unknown" ]; then
        FRAMEWORK_KEY="${DETECTED%-cli}"
        FRAMEWORK_KEY="${FRAMEWORK_KEY,,}"
        AGENT_MODEL="Unknown Model"
        [ -n "$FRAMEWORK_KEY" ] && AGENT_MODEL="${FRAMEWORK_MODELS[$FRAMEWORK_KEY]:-Unknown Model}"
        AGENT_FRAMEWORK="$DETECTED"
    else
        AGENT_MODEL="Unknown Model"
        AGENT_FRAMEWORK="custom"
    fi
elif [ $# -eq 3 ]; then
    # Manual name, email, and model
    AGENT_NAME="$1"
    AGENT_EMAIL="$2"
    AGENT_MODEL="$3"
    AGENT_FRAMEWORK="custom"
else
    echo "Error: Invalid arguments"
    show_usage
    _sgi_clear_identity
    return 1
fi

echo "Setting ephemeral git identity for: $AGENT_NAME <$AGENT_EMAIL>"
echo "Model: $AGENT_MODEL"
echo ""

# Export Git environment variables for this session
# These take precedence over .git/config and global config
export GIT_AUTHOR_NAME="$AGENT_NAME"
export GIT_AUTHOR_EMAIL="$AGENT_EMAIL"
export GIT_COMMITTER_NAME="$AGENT_NAME"
export GIT_COMMITTER_EMAIL="$AGENT_EMAIL"

# Export agent identity for use in signatures
export AGENT_NAME
export AGENT_EMAIL
export AGENT_MODEL
export AGENT_FRAMEWORK

echo "✅ Ephemeral git identity configured for this session!"
echo ""
echo "Environment variables set:"
echo "  GIT_AUTHOR_NAME=$GIT_AUTHOR_NAME"
echo "  GIT_AUTHOR_EMAIL=$GIT_AUTHOR_EMAIL"
echo "  GIT_COMMITTER_NAME=$GIT_COMMITTER_NAME"
echo "  GIT_COMMITTER_EMAIL=$GIT_COMMITTER_EMAIL"
echo "  AGENT_MODEL=$AGENT_MODEL"
echo "  AGENT_FRAMEWORK=$AGENT_FRAMEWORK"
echo ""
echo "Verification:"
AUTHOR_IDENT=$(git var GIT_AUTHOR_IDENT)
AUTHOR_NAME=$(echo "$AUTHOR_IDENT" | sed 's/ <.*//')
AUTHOR_EMAIL=$(echo "$AUTHOR_IDENT" | sed 's/.*<\(.*\)>.*/\1/')
echo "  Current session identity: $AUTHOR_NAME <$AUTHOR_EMAIL>"
echo ""
echo "ℹ️  This identity applies ONLY to this shell session."
echo "ℹ️  The .git/config file remains unchanged."
echo "ℹ️  When the session ends, the user's original identity is restored."
echo "ℹ️  Use \$AGENT_NAME and \$AGENT_MODEL in GitHub signatures."
