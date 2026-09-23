#!/bin/bash
# Log every tool use to a JSONL file for permission analysis.
# Configured as a PreToolUse hook — runs on every tool call, always approves.
#
# Log location: ~/.claude/tool-use-log.jsonl
# Each line: {"ts", "session_id", "tool", "input_summary", "cwd", "permission_mode"}
#
# Analyze with:
#   jq -s 'group_by(.tool) | map({tool: .[0].tool, count: length}) | sort_by(-.count)' ~/.claude/tool-use-log.jsonl
#   jq 'select(.tool == "Bash")' ~/.claude/tool-use-log.jsonl

LOG_FILE="${HOME}/.claude/tool-use-log.jsonl"

# Ensure log file has restrictive permissions
umask 077

# Bail gracefully if jq is not available — never block tool usage
if ! command -v jq &>/dev/null; then
    exit 0
fi

# Read hook input from stdin
INPUT=$(cat)


# ---------------------------------------------------- user-tier guard (#265) ---
# Promoted to the user tier: an absolute-path PreToolUse entry in
# ~/.claude/settings.json makes this hook fire in EVERY session on this
# machine. Stay inert outside the workspace checkout and outside every
# registered project root -- exit 0 before writing any log line, so an
# unrelated repo's tool use is never recorded.
#
# BASH_SOURCE is resolved through symlinks because the user tier installs
# this file as a symlink under ~/.claude/hooks/.
# See docs/decisions/0016-session-roots-and-the-user-tier.md.
_UT_HOOK_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
_UT_WS_ROOT="$(cd "$(dirname "$_UT_HOOK_PATH")/../.." 2>/dev/null && pwd)"
_UT_CWD="$(echo "$INPUT" | jq -r '.cwd // ""')"
[[ -z "$_UT_CWD" ]] && _UT_CWD="$PWD"
# Fail CLOSED, not open. If the workspace root or the registry helper cannot
# be resolved -- a moved clone, a deleted checkout, a broken symlink -- we
# cannot tell whether this cwd is a root we govern. Acting anyway would mean
# logging a stranger's tool use in a repo that may have nothing to do with the workspace, which is
# exactly what the user-tier rule forbids. So: do nothing and exit 0.
if [[ -z "$_UT_WS_ROOT" || ! -f "$_UT_WS_ROOT/.agent/scripts/_project_registry.sh" ]]; then
    exit 0
fi
# shellcheck source=../../.agent/scripts/_project_registry.sh
source "$_UT_WS_ROOT/.agent/scripts/_project_registry.sh" 2>/dev/null || exit 0
registry_require_root "$_UT_WS_ROOT" "$_UT_CWD" >/dev/null 2>&1 || exit 0

# Extract fields and write log entry; any failure is silently ignored
{
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
    CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')
    PERM_MODE=$(echo "$INPUT" | jq -r '.permission_mode // "unknown"')
    # 2000-byte cap on input_summary. Earlier value (200) clipped ~40% of Bash
    # entries mid-command, blunting permission-pattern analysis. 2000 captures
    # typical heredoc bodies and `python3 -c` scripts intact.
    INPUT_SUMMARY=$(echo "$INPUT" | jq -c '.tool_input' | head -c 2000)

    jq -n -c \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg sid "$SESSION_ID" \
      --arg tool "$TOOL_NAME" \
      --arg input "$INPUT_SUMMARY" \
      --arg cwd "$CWD" \
      --arg perm "$PERM_MODE" \
      '{ts:$ts, session_id:$sid, tool:$tool, input_summary:$input, cwd:$cwd, permission_mode:$perm}' \
      >> "$LOG_FILE"
} 2>/dev/null || true

# Always approve — this hook is for logging only
exit 0
