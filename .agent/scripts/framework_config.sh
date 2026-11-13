#!/usr/bin/env bash
# Framework Identity Configuration
# Shared lookup tables for framework names, agent email suffixes, and default models
# Sourced by: set_git_identity_env.sh, configure_git_identity.sh, detect_agent_identity.sh
#
# No email address is stored here (issue #455). An agent's email is
#   <local>+<suffix>@<domain>
# where <local>@<domain> is the checkout's configured `git config user.email`
# (a clone-level value wins over the global one) with any +suffix removed.
# The derivation lives in identity_base.py, shared with the commit-identity hook.
# An unset or malformed git email makes framework_email fail with a message.

# shellcheck disable=SC2034

# Framework name lookup table
# Maps framework key to display name
declare -A FRAMEWORK_NAMES=(
    ["copilot"]="Copilot CLI Agent"
    ["codex"]="Codex CLI Agent"
    ["gemini"]="Gemini CLI Agent"
    ["antigravity"]="Antigravity Agent"
    ["claude"]="Claude Code Agent"
    ["claude-code"]="Claude Code Agent"
)

# Framework email suffix lookup table
# Maps framework key to the +suffix of the agent's email address
declare -A FRAMEWORK_SUFFIXES=(
    ["copilot"]="copilot-cli"
    ["codex"]="codex"
    ["gemini"]="gemini-cli"
    ["antigravity"]="antigravity"
    ["claude"]="claude-code"
    ["claude-code"]="claude-code"
)

# Framework default model lookup table
# Maps framework key to typical/default model name
# NOTE: These are FALLBACK defaults only, used when the agent does not
# self-report its model (e.g., 2-arg call to set_git_identity_env.sh).
# Agents that know their model should pass it directly — do not edit
# this table to match a specific session's model.
declare -A FRAMEWORK_MODELS=(
    ["copilot"]="GPT-4o"
    ["codex"]="gpt-5.4"
    ["gemini"]="Gemini 2.0 Flash"
    ["antigravity"]="Gemini 2.5 Pro"
    ["claude"]="Claude Opus 4.6"
    ["claude-code"]="Claude Opus 4.6"
)

_FRAMEWORK_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# agent_email_for_suffix <suffix>
# Prints <local>+<suffix>@<domain> from the current checkout's git user.email.
# On an unset or malformed email, prints the helper's message to stderr and
# returns 1 with nothing on stdout.
agent_email_for_suffix() {
    python3 "$_FRAMEWORK_CONFIG_DIR/identity_base.py" agent "$1"
}

# framework_email <framework-key>
# Prints the agent email for a framework key of FRAMEWORK_SUFFIXES; returns 1
# (message on stderr) for an unknown key or an unusable git email.
framework_email() {
    local suffix=""
    # An empty key is not a valid array subscript: test it first.
    [ -n "$1" ] && suffix="${FRAMEWORK_SUFFIXES[$1]:-}"
    if [ -z "$suffix" ]; then
        echo "Error: no email suffix configured for framework '$1'" >&2
        return 1
    fi
    agent_email_for_suffix "$suffix"
}
