#!/bin/bash
# .agent/scripts/detect_agent_identity.sh
# Detects full agent identity (framework, name, email, and model)
# and writes to .agent/.identity file (runtime, not template)
#
# Usage:
#   .agent/scripts/detect_agent_identity.sh [--write] [--export]
#
# Options:
#   --write    Write detected identity to .agent/.identity (runtime file, git-ignored)
#   --export   Export identity as environment variables
#   (no args)  Display detected identity only
#
# Exports (with --export):
#   AGENT_NAME - Full agent name (e.g., "Copilot CLI Agent")
#   AGENT_EMAIL - Agent email address, derived from the checkout's git
#                 user.email as <local>+<framework-suffix>@<domain>
#                 (framework_config.sh)
#   AGENT_MODEL - Detected or default model name
#   AGENT_FRAMEWORK - Framework identifier (copilot, gemini, etc.)
#
# On failure (unset or malformed git email, missing framework_config.sh)
# nothing is written and the script unsets what it owns -- AGENT_NAME,
# AGENT_EMAIL, AGENT_MODEL, AGENT_FRAMEWORK -- before returning 1 (exit 1
# when run), so a sourced caller is left with no stale or mixed identity.
# set_git_identity_env.sh does the same for its variables (it also owns the
# GIT_AUTHOR_* / GIT_COMMITTER_* ones).
#
# Note: The .agent/.identity file is runtime-generated and git-ignored.
#       The template is at .agent/.identity.template

# Don't exit on error for sourced scripts
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_ROOT="$(dirname "$SCRIPT_DIR")"
IDENTITY_FILE="$AGENT_ROOT/.identity"
export IDENTITY_TEMPLATE="$AGENT_ROOT/.identity.template"

# Load framework configuration
if [ -f "$SCRIPT_DIR/framework_config.sh" ]; then
    source "$SCRIPT_DIR/framework_config.sh"
else
    echo "❌ ERROR: Framework configuration not found at $SCRIPT_DIR/framework_config.sh"
    unset AGENT_NAME AGENT_EMAIL AGENT_MODEL AGENT_FRAMEWORK
    return 1 2>/dev/null || exit 1
fi

# Detect the framework in a subshell: detect_cli_env.sh exports
# AGENT_FRAMEWORK, and nothing identity-related is assigned in the caller's
# shell before the email is derived.
if [ -f "$SCRIPT_DIR/detect_cli_env.sh" ]; then
    _DAI_FRAMEWORK="$(source "$SCRIPT_DIR/detect_cli_env.sh" >/dev/null 2>&1; echo "${AGENT_FRAMEWORK:-unknown}")"
else
    echo "⚠️  WARNING: Framework detection script not found"
    _DAI_FRAMEWORK="unknown"
fi
[ -n "$_DAI_FRAMEWORK" ] || _DAI_FRAMEWORK="unknown"

# Get framework details (into _DAI_* only; AGENT_* is assigned after the
# email has been derived)
_DAI_NAME=""
_DAI_SUFFIX=""
_DAI_MODEL=""
if [ "$_DAI_FRAMEWORK" != "unknown" ]; then
    # Normalize framework name (remove -cli suffix from end only)
    _DAI_KEY="${_DAI_FRAMEWORK%-cli}"
    _DAI_KEY="${_DAI_KEY,,}"  # lowercase
    # An empty key is not a valid array subscript: skip the lookups.
    if [ -n "$_DAI_KEY" ]; then
        _DAI_NAME="${FRAMEWORK_NAMES[$_DAI_KEY]:-}"
        _DAI_SUFFIX="${FRAMEWORK_SUFFIXES[$_DAI_KEY]:-}"
        _DAI_MODEL="${FRAMEWORK_MODELS[$_DAI_KEY]:-}"
    fi
    unset _DAI_KEY
fi
# If lookups failed (or the framework is unknown), use defaults
[ -n "$_DAI_NAME" ] || _DAI_NAME="AI Agent"
[ -n "$_DAI_SUFFIX" ] || _DAI_SUFFIX="ai-agent"
[ -n "$_DAI_MODEL" ] || _DAI_MODEL="Unknown Model"

# Try to detect actual model from environment or APIs
# This is framework-specific and may not always be available
detect_actual_model() {
    local detected_model=""

    case "$1" in
        codex)
            if [ -n "$CODEX_MODEL" ]; then
                detected_model="$CODEX_MODEL"
            elif [ -n "$OPENAI_MODEL" ]; then
                detected_model="$OPENAI_MODEL"
            elif [ -f "$HOME/.codex/config.toml" ]; then
                detected_model="$(sed -n 's/^model = \"\\(.*\\)\"$/\\1/p' "$HOME/.codex/config.toml" | head -n 1)"
            else
                detected_model="${FRAMEWORK_MODELS[codex]}"
            fi
            ;;
        copilot*)
            # GitHub Copilot doesn't expose model info easily
            # Use default from config
            detected_model="${FRAMEWORK_MODELS[copilot]}"
            ;;
        gemini*)
            # Gemini CLI might have model info in env or config
            # Check common environment variables
            if [ -n "$GEMINI_MODEL" ]; then
                detected_model="$GEMINI_MODEL"
            else
                detected_model="${FRAMEWORK_MODELS[gemini]}"
            fi
            ;;
        antigravity)
            # Antigravity might have model info
            if [ -n "$ANTIGRAVITY_MODEL" ]; then
                detected_model="$ANTIGRAVITY_MODEL"
            else
                detected_model="${FRAMEWORK_MODELS[antigravity]}"
            fi
            ;;
        claude*)
            # Claude CLI model detection
            if [ -n "$CLAUDE_MODEL" ]; then
                detected_model="$CLAUDE_MODEL"
            else
                detected_model="${FRAMEWORK_MODELS[claude]}"
            fi
            ;;
        *)
            # For unknown frameworks, check generic environment variable
            if [ -n "$AI_MODEL_NAME" ]; then
                detected_model="$AI_MODEL_NAME"
            fi
            ;;
    esac

    echo "$detected_model"
}

# Attempt to detect actual model
_DAI_DETECTED_MODEL=$(detect_actual_model "$_DAI_FRAMEWORK")
if [ -n "$_DAI_DETECTED_MODEL" ]; then
    _DAI_MODEL="$_DAI_DETECTED_MODEL"
fi
unset _DAI_DETECTED_MODEL

# Parse command line options
WRITE_FILE=false
EXPORT_VARS=false

for arg in "$@"; do
    case "$arg" in
        --write)
            WRITE_FILE=true
            ;;
        --export)
            EXPORT_VARS=true
            ;;
        --help|-h)
            echo "Usage: $0 [--write] [--export]"
            echo ""
            echo "Options:"
            echo "  --write    Write detected identity to .agent/.identity"
            echo "  --export   Export identity as environment variables"
            echo "  (no args)  Display detected identity only"
            echo ""
            echo "On failure (e.g. git user.email unset) nothing is written and"
            echo "AGENT_NAME, AGENT_EMAIL, AGENT_MODEL and AGENT_FRAMEWORK are unset"
            echo "(set_git_identity_env.sh also unsets its GIT_AUTHOR_*/GIT_COMMITTER_*)."
            exit 0
            ;;
    esac
done

# Derive the email from the checkout's git user.email. On an unset or
# malformed email the helper prints the fix to stderr; stop before anything
# is displayed or written, and unset the AGENT_* variables this script owns
# so a sourced caller keeps no stale or mixed identity (return when sourced,
# exit when run).
if ! _DAI_EMAIL="$(agent_email_for_suffix "$_DAI_SUFFIX")"; then
    unset _DAI_EMAIL _DAI_SUFFIX _DAI_NAME _DAI_MODEL _DAI_FRAMEWORK
    unset AGENT_NAME AGENT_EMAIL AGENT_MODEL AGENT_FRAMEWORK
    return 1 2>/dev/null || exit 1
fi
AGENT_NAME="$_DAI_NAME"
AGENT_EMAIL="$_DAI_EMAIL"
AGENT_MODEL="$_DAI_MODEL"
AGENT_FRAMEWORK="$_DAI_FRAMEWORK"
unset _DAI_EMAIL _DAI_SUFFIX _DAI_NAME _DAI_MODEL _DAI_FRAMEWORK

# Display detected identity
echo "Detected Agent Identity:"
echo "  Framework:  $AGENT_FRAMEWORK"
echo "  Name:       $AGENT_NAME"
echo "  Email:      $AGENT_EMAIL"
echo "  Model:      $AGENT_MODEL"
echo ""

# Write to file if requested
if [ "$WRITE_FILE" = true ]; then
    # Values are written POSIX single-quoted (an embedded ' becomes '\''):
    # a model name or framework taken from the environment may hold quotes,
    # `$(...)`, tabs, newlines or non-ASCII, and the file is meant to be
    # sourced by bash or a POSIX sh alike (printf %q may emit bash-only $'...').
    _dai_sq() { printf "'%s'" "${1//\'/\'\\\'\'}"; }
    {
        cat << EOF
# Agent Identity Configuration
# Auto-generated by detect_agent_identity.sh on $(date)
# This is a RUNTIME file (git-ignored). The template is at .agent/.identity.template
#
# WARNING: This file may become stale if the model or configuration changes
# during a session. Prefer using environment variables set by
# set_git_identity_env.sh which are always current for the active shell.

EOF
        printf 'AGENT_NAME=%s\n' "$(_dai_sq "$AGENT_NAME")"
        printf 'AGENT_EMAIL=%s\n' "$(_dai_sq "$AGENT_EMAIL")"
        printf 'AGENT_MODEL=%s\n' "$(_dai_sq "$AGENT_MODEL")"
        printf 'AGENT_FRAMEWORK=%s\n' "$(_dai_sq "$AGENT_FRAMEWORK")"
    } > "$IDENTITY_FILE"
    unset -f _dai_sq
    echo "✅ Identity written to: $IDENTITY_FILE"
    echo "   (This is a runtime file, git-ignored)"
    echo ""
fi

# Export variables if requested
if [ "$EXPORT_VARS" = true ]; then
    export AGENT_NAME
    export AGENT_EMAIL
    export AGENT_MODEL
    export AGENT_FRAMEWORK
    echo "✅ Identity exported to environment variables"
    echo ""
fi
