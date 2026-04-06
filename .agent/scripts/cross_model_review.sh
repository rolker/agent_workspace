#!/usr/bin/env bash
# Cross-model adversarial review via external CLI agents
#
# Launches an external CLI agent to provide an independent adversarial review
# of a PR. Writes prompt and findings to .agent/work-plans/issue-<N>/
# alongside the work plan. These files can be committed as review artifacts.
#
# Supported agents: gemini, codex, claude, copilot
#
# Two execution modes:
#   tmux (default) — runs the agent in a background tmux session
#   sync           — runs the agent synchronously (for sandboxed environments)
#
# Sync mode is selected automatically when tmux is unavailable, or explicitly
# with --sync.
#
# Usage:
#   .agent/scripts/cross_model_review.sh --pr <N>                              # gemini (default)
#   .agent/scripts/cross_model_review.sh --pr <N> --agent codex                # specific agent
#   .agent/scripts/cross_model_review.sh --pr <N> --agent claude --sync        # force sync
#   .agent/scripts/cross_model_review.sh --pr <N> --repo owner/repo            # explicit repo target
#   .agent/scripts/cross_model_review.sh --pr <N> --work-dir /path/to/worktree # explicit artifact dir
#
# The script runs in whichever repo worktree it's invoked from.
# Workspace issues run in workspace worktrees, project issues in project worktrees.
#
# Output (stdout):
#   MODE=tmux|sync                 (machine-parseable)
#   AGENT=<agent-key>              (machine-parseable)
#   TMUX_SESSION=<session-name>    (tmux mode only)
#   FINDINGS_FILE=<path-to-findings> (machine-parseable)
#   followed by informational lines for human consumption
#
# Exit codes:
#   0 — review launched (tmux) or completed (sync) successfully
#   1 — missing dependencies (gh or target agent CLI)
#   2 — invalid arguments
#   3 — failed to create prompt or launch session

set -euo pipefail

# --- Agent configuration ---
# Binary name to search for in PATH and fallback locations.
declare -A AGENT_BINS=(
    ["gemini"]="gemini"
    ["codex"]="codex"
    ["claude"]="claude"
    ["copilot"]="copilot"
)

# Build the shell command string to invoke an agent.
# Args: agent_key, bin_path, prompt_file, findings_file
# Stdout: a shell command string safe for tmux new-session.
# All agents use stdin-based invocation to avoid argv limits on large diffs.
build_invoke_cmd() {
    local agent="$1" bin="$2" prompt="$3" findings="$4"

    case "$agent" in
        gemini)
            echo "\"${bin}\" -p < \"${prompt}\" > \"${findings}\" 2>&1"
            ;;
        codex)
            # Codex exec reads prompt via stdin
            echo "\"${bin}\" exec < \"${prompt}\" > \"${findings}\" 2>&1"
            ;;
        claude)
            echo "\"${bin}\" -p < \"${prompt}\" > \"${findings}\" 2>&1"
            ;;
        copilot)
            echo "\"${bin}\" -p < \"${prompt}\" > \"${findings}\" 2>&1"
            ;;
        *)
            # Unknown agent — try stdin style as fallback
            echo "\"${bin}\" -p < \"${prompt}\" > \"${findings}\" 2>&1"
            ;;
    esac
}

# Run an agent directly (sync mode) without eval.
# Args: agent_key, bin_path, prompt_file, findings_file
# Returns: exit code from the agent CLI.
run_agent_sync() {
    local agent="$1" bin="$2" prompt="$3" findings="$4"

    case "$agent" in
        gemini)  "$bin" -p < "$prompt" > "$findings" 2>&1 ;;
        codex)   "$bin" exec < "$prompt" > "$findings" 2>&1 ;;
        claude)  "$bin" -p < "$prompt" > "$findings" 2>&1 ;;
        copilot) "$bin" -p < "$prompt" > "$findings" 2>&1 ;;
        *)       "$bin" -p < "$prompt" > "$findings" 2>&1 ;;
    esac
}

# --- Argument parsing ---
PR_NUMBER=""
FORCE_SYNC=false
TARGET_AGENT="gemini"
EXPLICIT_REPO=""
EXPLICIT_WORK_DIR=""
USAGE="Usage: $0 --pr <N> [--agent <name>] [--repo owner/repo] [--work-dir <path>] [--sync]"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: Missing value for --pr" >&2
                echo "$USAGE" >&2
                exit 2
            fi
            PR_NUMBER="$2"
            shift 2
            ;;
        --agent)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: Missing value for --agent" >&2
                echo "$USAGE" >&2
                exit 2
            fi
            TARGET_AGENT="${2,,}"  # lowercase
            shift 2
            ;;
        --repo|-R)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: Missing value for --repo" >&2
                echo "$USAGE" >&2
                exit 2
            fi
            EXPLICIT_REPO="$2"
            shift 2
            ;;
        --work-dir)
            if [[ $# -lt 2 ]]; then
                echo "ERROR: Missing value for --work-dir" >&2
                echo "$USAGE" >&2
                exit 2
            fi
            EXPLICIT_WORK_DIR="$2"
            shift 2
            ;;
        --sync)
            FORCE_SYNC=true
            shift
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "$USAGE" >&2
            exit 2
            ;;
    esac
done

if [[ -z "$PR_NUMBER" ]]; then
    echo "ERROR: --pr <N> is required" >&2
    echo "$USAGE" >&2
    exit 2
fi

# Validate agent
if [[ -z "${AGENT_BINS[$TARGET_AGENT]+x}" ]]; then
    echo "ERROR: Unknown agent '${TARGET_AGENT}'" >&2
    echo "Supported agents: ${!AGENT_BINS[*]}" >&2
    exit 2
fi

# Validate --repo slug (before dependency checks so bad input always exits 2)
if [[ -n "$EXPLICIT_REPO" && ! "$EXPLICIT_REPO" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
    echo "ERROR: --repo value '${EXPLICIT_REPO}' is not a valid owner/repo slug" >&2
    exit 2
fi

# --- Dependency checks ---
if ! command -v gh &>/dev/null; then
    echo "WARNING: GitHub CLI (gh) not installed — required for PR metadata" >&2
    exit 1
fi

# Resolve repo slug for explicit -R targeting (prevents misrouting in nested repos)
if [[ -n "$EXPLICIT_REPO" ]]; then
    GH_REPO_SLUG="$EXPLICIT_REPO"
else
    GH_REPO_SLUG=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//' || echo "")
fi
GH_REPO_ARGS=()
if [[ -n "$GH_REPO_SLUG" && "$GH_REPO_SLUG" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
    GH_REPO_ARGS=("-R" "$GH_REPO_SLUG")
fi

# Determine execution mode
USE_SYNC=false
if [[ "$FORCE_SYNC" == true ]]; then
    USE_SYNC=true
elif ! command -v tmux &>/dev/null; then
    echo "INFO: tmux not available — falling back to sync mode" >&2
    USE_SYNC=true
fi

# Find target agent CLI — check PATH first, then common install locations
AGENT_BIN_NAME="${AGENT_BINS[$TARGET_AGENT]}"
AGENT_BIN=""

if command -v "$AGENT_BIN_NAME" &>/dev/null; then
    AGENT_BIN="$(command -v "$AGENT_BIN_NAME")"
else
    FALLBACK_PATHS=(
        "${HOME}/.nvm/versions/node"/*/bin/"${AGENT_BIN_NAME}"
        "${HOME}/.local/bin/${AGENT_BIN_NAME}"
        "${HOME}/.npm-global/bin/${AGENT_BIN_NAME}"
        /usr/local/bin/"${AGENT_BIN_NAME}"
    )
    for candidate in "${FALLBACK_PATHS[@]}"; do
        if [[ -x "$candidate" ]]; then
            AGENT_BIN="$candidate"
            echo "INFO: ${AGENT_BIN_NAME} not in PATH, found at: ${AGENT_BIN}" >&2
            break
        fi
    done
fi

if [[ -z "$AGENT_BIN" ]]; then
    echo "WARNING: ${AGENT_BIN_NAME} CLI not found — ${TARGET_AGENT} adversarial review unavailable" >&2
    echo "  PATH searched: ${PATH}" >&2
    echo "  Also checked: ~/.nvm/versions/node/*/bin/, ~/.local/bin/, ~/.npm-global/bin/, /usr/local/bin/" >&2
    exit 1
fi

# --- Resolve issue number from PR ---
ISSUE_NUMBER=""
PR_BODY=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json body --jq '.body' 2>/dev/null || echo "")
if [[ -n "$PR_BODY" ]]; then
    # Look for GitHub close keywords (case-insensitive): Closes #N, Fixes #N, Resolves #N
    # Requires word boundary before keyword to avoid "encloses", "prefixes", etc.
    # Also handles cross-repo form: Closes owner/repo#N (extracts just N)
    ISSUE_REF=$(printf '%s\n' "$PR_BODY" | grep -ioE '(^|[^[:alnum:]_])(closes|fixes|resolves)[[:space:]]+([a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+)?#[0-9]+' | head -n1 || true)
    ISSUE_NUMBER=$(printf '%s\n' "$ISSUE_REF" | grep -oE '[0-9]+$' || true)
    if [[ -z "$ISSUE_NUMBER" ]]; then
        # Fallback: first standalone #N (not part of a URL path or hex color)
        ISSUE_NUMBER=$(printf '%s\n' "$PR_BODY" | grep -oE '(^|[[:space:]])#[0-9]+' | head -n1 | grep -oE '[0-9]+')
    fi
fi

# Fall back to PR number if no issue found
if [[ -z "$ISSUE_NUMBER" ]]; then
    echo "INFO: Could not extract issue number from PR body — using PR number" >&2
    ISSUE_NUMBER="$PR_NUMBER"
fi

# --- Set up artifact directory (absolute paths for tmux session) ---
if [[ -n "$EXPLICIT_WORK_DIR" ]]; then
    # Resolve to absolute path so tmux sessions find the directory
    EXPLICIT_WORK_DIR=$(cd "$EXPLICIT_WORK_DIR" && pwd)
    WORK_PLANS_DIR="${EXPLICIT_WORK_DIR}/.agent/work-plans/issue-${ISSUE_NUMBER}"
else
    WORK_PLANS_DIR="$(git rev-parse --show-toplevel)/.agent/work-plans/issue-${ISSUE_NUMBER}"
fi
mkdir -p "$WORK_PLANS_DIR"

PROMPT_FILE="${WORK_PLANS_DIR}/review-${TARGET_AGENT}-prompt.md"
FINDINGS_FILE="${WORK_PLANS_DIR}/review-${TARGET_AGENT}-findings.md"
SESSION_NAME="review-${TARGET_AGENT}-${ISSUE_NUMBER}"

# --- Get PR metadata ---
PR_TITLE=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json title --jq '.title' 2>/dev/null || echo "PR #${PR_NUMBER}")
PR_URL=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json url --jq '.url' 2>/dev/null || echo "")

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
DIFF_START_LINE=$(wc -l < "$PROMPT_FILE")
if ! gh pr diff "$PR_NUMBER" "${GH_REPO_ARGS[@]}" >> "$PROMPT_FILE" 2>/dev/null; then
    echo "ERROR: Could not retrieve diff for PR #${PR_NUMBER}" >&2
    echo '--- Review error: failed to retrieve diff ---' > "$FINDINGS_FILE"
    exit 3
fi
DIFF_END_LINE=$(wc -l < "$PROMPT_FILE")

# Guard: if diff is empty, abort with a clear error instead of launching an
# agent with no content to review
if [[ "$DIFF_END_LINE" -le "$DIFF_START_LINE" ]]; then
    echo "ERROR: PR #${PR_NUMBER} diff is empty — nothing to review" >&2
    echo "  This usually means the PR was not found in the target repo." >&2
    echo "  Try passing --repo <owner/repo> explicitly." >&2
    echo '--- Review error: diff was empty (PR not found or no changes) ---' > "$FINDINGS_FILE"
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

# --- Run review ---
if [[ "$USE_SYNC" == true ]]; then
    # --- Sync mode: run agent directly (no eval) ---
    echo "MODE=sync"
    echo "AGENT=${TARGET_AGENT}"
    echo "FINDINGS_FILE=${FINDINGS_FILE}"
    echo ""
    echo "Running ${TARGET_AGENT} adversarial review synchronously for PR #${PR_NUMBER} (issue #${ISSUE_NUMBER})..."
    echo "  Prompt:  ${PROMPT_FILE}"
    echo "  Results: ${FINDINGS_FILE}"

    if run_agent_sync "$TARGET_AGENT" "$AGENT_BIN" "$PROMPT_FILE" "$FINDINGS_FILE"; then
        echo '--- Review complete ---' >> "${FINDINGS_FILE}"
        echo ""
        echo "Review complete. Results: ${FINDINGS_FILE}"
    else
        echo '--- Review failed ---' >> "${FINDINGS_FILE}"
        echo "ERROR: ${TARGET_AGENT} CLI exited with an error" >&2
        exit 3
    fi
else
    # --- Tmux mode: run agent in background session ---
    # Build command string for tmux (tmux requires a single shell command string)
    INVOKE_CMD=$(build_invoke_cmd "$TARGET_AGENT" "$AGENT_BIN" "$PROMPT_FILE" "$FINDINGS_FILE")

    # Kill existing session if present
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        tmux kill-session -t "$SESSION_NAME"
    fi

    # Launch agent in tmux. On failure, an error marker is written so downstream
    # consumers can distinguish "crashed" from "still running".
    tmux new-session -d -s "$SESSION_NAME" \
        "${INVOKE_CMD} && echo '--- Review complete ---' >> \"${FINDINGS_FILE}\" || echo '--- Review failed ---' >> \"${FINDINGS_FILE}\""

    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "ERROR: Failed to launch tmux session '${SESSION_NAME}'" >&2
        exit 3
    fi

    echo "MODE=tmux"
    echo "AGENT=${TARGET_AGENT}"
    echo "TMUX_SESSION=${SESSION_NAME}"
    echo "FINDINGS_FILE=${FINDINGS_FILE}"
    echo ""
    echo "${TARGET_AGENT} adversarial review launched for PR #${PR_NUMBER} (issue #${ISSUE_NUMBER})"
    echo "  Monitor: tmux attach -t ${SESSION_NAME}"
    echo "  Prompt:  ${PROMPT_FILE}"
    echo "  Results: ${FINDINGS_FILE}"
fi
