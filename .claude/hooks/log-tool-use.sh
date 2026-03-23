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

set -euo pipefail

LOG_FILE="${HOME}/.claude/tool-use-log.jsonl"

# Read hook input from stdin
INPUT=$(cat)

# Extract fields
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')
PERM_MODE=$(echo "$INPUT" | jq -r '.permission_mode // "unknown"')

# Build a short input summary (first 200 chars of tool_input, single line)
INPUT_SUMMARY=$(echo "$INPUT" | jq -c '.tool_input' | head -c 200)

# Write log entry
jq -n -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg sid "$SESSION_ID" \
  --arg tool "$TOOL_NAME" \
  --arg input "$INPUT_SUMMARY" \
  --arg cwd "$CWD" \
  --arg perm "$PERM_MODE" \
  '{ts:$ts, session_id:$sid, tool:$tool, input_summary:$input, cwd:$cwd, permission_mode:$perm}' \
  >> "$LOG_FILE" 2>/dev/null || true

# Always approve — this hook is for logging only
exit 0
