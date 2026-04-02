#!/usr/bin/env bash
# Cross-model adversarial review via Gemini CLI
#
# Launches a Gemini CLI session to provide an independent adversarial review
# of a PR. Writes prompt and findings to .agent/work-plans/issue-<N>/
# alongside the work plan. These files can be committed as review artifacts.
#
# Two execution modes:
#   tmux (default) — runs Gemini in a background tmux session
#   sync           — runs Gemini synchronously (for sandboxed environments)
#
# Sync mode is selected automatically when tmux is unavailable, or explicitly
# with --sync.
#
# Usage:
#   .agent/scripts/cross_model_review.sh --pr <N>          # tmux (or auto-sync)
#   .agent/scripts/cross_model_review.sh --pr <N> --sync   # force sync mode
#
# The script runs in whichever repo worktree it's invoked from.
# Workspace issues run in workspace worktrees, project issues in project worktrees.
#
# Output (stdout):
#   MODE=tmux|sync                 (machine-parseable)
#   TMUX_SESSION=<session-name>    (tmux mode only)
#   FINDINGS_FILE=<path-to-findings> (machine-parseable)
#   followed by informational lines for human consumption
#
# Exit codes:
#   0 — review launched (tmux) or completed (sync) successfully
#   1 — missing dependencies (gh or gemini)
#   2 — invalid arguments
#   3 — failed to create prompt or launch session

set -euo pipefail

# --- Argument parsing ---
PR_NUMBER=""
FORCE_SYNC=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: Missing value for --pr" >&2
                echo "Usage: $0 --pr <N> [--sync]" >&2
                exit 2
            fi
            PR_NUMBER="$2"
            shift 2
            ;;
        --sync)
            FORCE_SYNC=true
            shift
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "Usage: $0 --pr <N> [--sync]" >&2
            exit 2
            ;;
    esac
done

if [[ -z "$PR_NUMBER" ]]; then
    echo "ERROR: --pr <N> is required" >&2
    echo "Usage: $0 --pr <N> [--sync]" >&2
    exit 2
fi

# --- Dependency checks ---
if ! command -v gh &>/dev/null; then
    echo "WARNING: GitHub CLI (gh) not installed — required for PR metadata" >&2
    exit 1
fi

# Determine execution mode
USE_SYNC=false
if [[ "$FORCE_SYNC" == true ]]; then
    USE_SYNC=true
elif ! command -v tmux &>/dev/null; then
    echo "INFO: tmux not available — falling back to sync mode" >&2
    USE_SYNC=true
fi

# Find gemini CLI — check PATH first, then common install locations
GEMINI_BIN=""
if command -v gemini &>/dev/null; then
    GEMINI_BIN="$(command -v gemini)"
else
    # Common install paths for npm/nvm global installs
    FALLBACK_PATHS=(
        "${HOME}/.nvm/versions/node"/*/bin/gemini
        "${HOME}/.local/bin/gemini"
        "${HOME}/.npm-global/bin/gemini"
        /usr/local/bin/gemini
    )
    for candidate in "${FALLBACK_PATHS[@]}"; do
        if [[ -x "$candidate" ]]; then
            GEMINI_BIN="$candidate"
            echo "INFO: gemini not in PATH, found at: ${GEMINI_BIN}" >&2
            break
        fi
    done
fi

if [[ -z "$GEMINI_BIN" ]]; then
    echo "WARNING: gemini CLI not found — Gemini adversarial review unavailable" >&2
    echo "  PATH searched: ${PATH}" >&2
    echo "  Also checked: ~/.nvm/versions/node/*/bin/, ~/.local/bin/, ~/.npm-global/bin/, /usr/local/bin/" >&2
    exit 1
fi

# --- Resolve issue number from PR ---
ISSUE_NUMBER=""
PR_BODY=$(gh pr view "$PR_NUMBER" --json body --jq '.body' 2>/dev/null || echo "")
if [[ -n "$PR_BODY" ]]; then
    # Look for "Closes #N", "Fixes #N", or "Resolves #N" first (portable, no PCRE)
    ISSUE_NUMBER=$(printf '%s\n' "$PR_BODY" | sed -nE 's/.*(Closes|Fixes|Resolves)[[:space:]]+#([0-9]+).*/\2/p' | head -n1)
    if [[ -z "$ISSUE_NUMBER" ]]; then
        # Fallback: first occurrence of "#N" anywhere in the body
        ISSUE_NUMBER=$(printf '%s\n' "$PR_BODY" | sed -nE 's/.*#([0-9]+).*/\1/p' | head -n1)
    fi
fi

# Fall back to PR number if no issue found
if [[ -z "$ISSUE_NUMBER" ]]; then
    ISSUE_NUMBER="$PR_NUMBER"
fi

# --- Set up artifact directory (absolute paths for tmux session) ---
WORK_PLANS_DIR="$(git rev-parse --show-toplevel)/.agent/work-plans/issue-${ISSUE_NUMBER}"
mkdir -p "$WORK_PLANS_DIR"

PROMPT_FILE="${WORK_PLANS_DIR}/review-gemini-prompt.md"
FINDINGS_FILE="${WORK_PLANS_DIR}/review-gemini-findings.md"
SESSION_NAME="review-gemini-${ISSUE_NUMBER}"

# --- Get PR metadata ---
PR_TITLE=$(gh pr view "$PR_NUMBER" --json title --jq '.title' 2>/dev/null || echo "PR #${PR_NUMBER}")
PR_URL=$(gh pr view "$PR_NUMBER" --json url --jq '.url' 2>/dev/null || echo "")

# --- Write prompt ---
# Use a quoted heredoc for the static header to prevent shell expansion,
# then stream the diff directly from gh to avoid storing it in a variable
# (which could hit shell limits for large Deep-tier PRs).
cat > "$PROMPT_FILE" << 'PROMPT_HEADER'
# Adversarial Code Review

## Your Role

You are an independent adversarial reviewer. Your job is to find issues that
other reviewers missed: edge cases, security implications, incorrect
assumptions, subtle bugs, and logic errors.

Review the diff below with fresh eyes. Do not assume previous reviewers caught
everything. Focus on:

- **Edge cases**: What inputs or states could break this code?
- **Security**: Are there injection, auth, or data exposure risks?
- **Assumptions**: What does the code assume that might not hold?
- **Subtle bugs**: Off-by-one, race conditions, resource leaks, null/undefined
- **Logic errors**: Does the code actually do what the PR title claims?

## PR Under Review

PROMPT_HEADER

# Append PR metadata (needs expansion)
printf '**Title**: %s\n**URL**: %s\n**PR Number**: #%s\n\n' \
    "$PR_TITLE" "$PR_URL" "$PR_NUMBER" >> "$PROMPT_FILE"

# Stream diff directly into the prompt file
printf '## Diff\n\n```diff\n' >> "$PROMPT_FILE"
if ! gh pr diff "$PR_NUMBER" >> "$PROMPT_FILE" 2>/dev/null; then
    echo "ERROR: Could not retrieve diff for PR #${PR_NUMBER}" >&2
    exit 3
fi
printf '```\n\n' >> "$PROMPT_FILE"

# Append output format instructions (quoted heredoc, no expansion)
cat >> "$PROMPT_FILE" << 'PROMPT_FOOTER'
## Output Format

Write your findings to this exact format so they can be parsed:

### Findings

| # | Severity | File | Line | Finding |
|---|----------|------|------|---------|
| 1 | must-fix / suggestion | `path/to/file` | line number | Description of the issue |

If you find no issues, write:

### Findings

No issues found.

### Summary

Write a 1-3 sentence overall assessment after the findings table.
PROMPT_FOOTER

# --- Run Gemini review ---
if [[ "$USE_SYNC" == true ]]; then
    # --- Sync mode: run Gemini directly ---
    echo "MODE=sync"
    echo "FINDINGS_FILE=${FINDINGS_FILE}"
    echo ""
    echo "Running Gemini adversarial review synchronously for PR #${PR_NUMBER} (issue #${ISSUE_NUMBER})..."
    echo "  Prompt:  ${PROMPT_FILE}"
    echo "  Results: ${FINDINGS_FILE}"

    if "${GEMINI_BIN}" -p < "${PROMPT_FILE}" > "${FINDINGS_FILE}" 2>&1; then
        echo '--- Review complete ---' >> "${FINDINGS_FILE}"
        echo ""
        echo "Review complete. Results: ${FINDINGS_FILE}"
    else
        echo '--- Review failed ---' >> "${FINDINGS_FILE}"
        echo "ERROR: Gemini CLI exited with an error" >&2
        exit 3
    fi
else
    # --- Tmux mode: run Gemini in background session ---
    # Initialize findings file
    cat > "$FINDINGS_FILE" << 'FINDINGS_EOF'
<!-- Gemini adversarial review findings — this file is populated by Gemini CLI -->
<!-- Waiting for review to complete... -->
FINDINGS_EOF

    # Kill existing session if present
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        tmux kill-session -t "$SESSION_NAME"
    fi

    # Pipe the prompt file via stdin. Paths are absolute (resolved above) so the
    # tmux session works regardless of CWD. On Gemini failure, an error marker is
    # written so downstream consumers can distinguish "crashed" from "still running".
    tmux new-session -d -s "$SESSION_NAME" \
        "\"${GEMINI_BIN}\" -p < \"${PROMPT_FILE}\" > \"${FINDINGS_FILE}\" 2>&1 && echo '--- Review complete ---' >> \"${FINDINGS_FILE}\" || echo '--- Review failed ---' >> \"${FINDINGS_FILE}\""

    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "ERROR: Failed to launch tmux session '${SESSION_NAME}'" >&2
        exit 3
    fi

    echo "MODE=tmux"
    echo "TMUX_SESSION=${SESSION_NAME}"
    echo "FINDINGS_FILE=${FINDINGS_FILE}"
    echo ""
    echo "Gemini adversarial review launched for PR #${PR_NUMBER} (issue #${ISSUE_NUMBER})"
    echo "  Monitor: tmux attach -t ${SESSION_NAME}"
    echo "  Prompt:  ${PROMPT_FILE}"
    echo "  Results: ${FINDINGS_FILE}"
fi
