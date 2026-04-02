#!/usr/bin/env bash
# Framework Identity Configuration
# Shared lookup tables for framework names, email addresses, and default models
# Sourced by: set_git_identity_env.sh, configure_git_identity.sh, detect_agent_identity.sh
#
# CUSTOMIZATION POINT: Update email addresses below to match your domain.
# The pattern is: <your-username>+<framework>@<your-domain>
# Currently configured for: roland@ccom.unh.edu / roland@rolker.net

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

# Framework email lookup table
# Maps framework key to email address
declare -A FRAMEWORK_EMAILS=(
    ["copilot"]="roland+copilot-cli@ccom.unh.edu"
    ["codex"]="roland+codex@rolker.net"
    ["gemini"]="roland+gemini-cli@ccom.unh.edu"
    ["antigravity"]="roland+antigravity@ccom.unh.edu"
    ["claude"]="roland+claude-code@rolker.net"
    ["claude-code"]="roland+claude-code@rolker.net"
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
