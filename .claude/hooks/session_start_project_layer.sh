#!/bin/bash
# .claude/hooks/session_start_project_layer.sh
# SessionStart hook: inject the workspace layer and the project layer into a
# session started anywhere under a registered project root (#317, #265 PR 3).
#
# Today a session only sees the workspace's skills, hooks and instructions
# when it is started in the workspace checkout, because Claude Code loads
# them launch-dir first. This hook closes that gap for project sessions:
# user_tier_install.sh registers it at the user tier with an absolute path,
# so it runs for EVERY session on this machine, and it decides from the
# session's own cwd whether it has anything to say.
#
# Behaviour:
#   - cwd outside the workspace checkout and outside every registered root:
#     exit 0 with no output. Silence is the contract -- an unrelated repo's
#     session must look exactly as it does today.
#   - cwd under a registered root: print the header, the workspace-root
#     idiom, the workspace layer (rendered from AGENTS.md by a pinned
#     heading list) and the project layer.
#
# What this hook deliberately does NOT print: any `KEY=value` line meant for
# a script to parse. SessionStart stdout is context text for the model; it
# never reaches a Bash tool call's fresh shell as environment. Scripts that
# need to know which project they are in call registry_resolve_from_dir on
# their own $PWD (see dispatch_phase.sh), and skills locate workspace
# scripts through ~/.claude/agent-workspace-root. Both are recorded in
# docs/decisions/0016-session-roots-and-the-user-tier.md.
#
# Input: the SessionStart JSON payload on stdin (`.cwd` is the only field
# read). Output: plain text on stdout. Always exits 0 -- a hook that fails
# must never stop a session from starting.

set -u

# The user tier installs this file as a symlink under ~/.claude/hooks/, so
# resolve through it to find the workspace checkout this hook belongs to.
_HOOK_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
WS_ROOT="$(cd "$(dirname "$_HOOK_PATH")/../.." 2>/dev/null && pwd)" || exit 0
[[ -n "$WS_ROOT" && -f "$WS_ROOT/.agent/scripts/_project_registry.sh" ]] || exit 0

INPUT="$(cat 2>/dev/null || true)"
CWD=""
if command -v jq >/dev/null 2>&1 && [[ -n "$INPUT" ]]; then
    CWD="$(jq -r '.cwd // ""' <<< "$INPUT" 2>/dev/null || echo "")"
fi
[[ -z "$CWD" ]] && CWD="$PWD"

# shellcheck source=../../.agent/scripts/_project_registry.sh
source "$WS_ROOT/.agent/scripts/_project_registry.sh" 2>/dev/null || exit 0

ENTRY="$(registry_resolve_from_dir "$WS_ROOT" "$CWD" 2>/dev/null)" || exit 0
[[ -n "$ENTRY" ]] || exit 0

IFS=$'\t' read -r P_NAME P_TYPE P_PATH <<< "$ENTRY"
[[ -n "$P_NAME" ]] || exit 0

# ---------------------------------------------------------------------------
# The AGENTS.md sections rendered as the workspace layer. Pinned here on
# purpose: a renamed or deleted heading would otherwise produce a silently
# empty layer, so test_session_start_layer.sh asserts every entry still
# exists in AGENTS.md, extracts a non-empty body, and stops at the next
# same-level heading.
# ---------------------------------------------------------------------------
WORKSPACE_SECTIONS=(
    "Boundaries"
    "Communication Standards"
    "Quality Standard"
    "Tool Usage"
    "Issue-First Policy"
    "AI Signature (Required on all GitHub Issues/PRs/Comments)"
    "Documentation Accuracy"
    "Workspace Cleanliness"
    "Post-Task Verification"
)

# Print the body of `## <heading>` from a markdown file, stopping at the
# next same-level (`## `) heading. Nested `### ` headings are kept.
extract_section() {  # <file> <heading>
    local file="$1" heading="$2"
    awk -v want="## $heading" '
        $0 == want { inside = 1; print; next }
        inside && /^## / { exit }
        inside { print }
    ' "$file"
}

echo "=== agent_workspace session layer ==="
echo "Project: $P_NAME (type: $P_TYPE)"
echo "Project root: $P_PATH"
echo "Session cwd: $CWD"
echo ""

# --- the workspace-root idiom -------------------------------------------
# Stated once, before the workspace layer, because the AGENTS.md sections
# below quote workspace scripts by their workspace-relative path
# (`.agent/scripts/...`). From a project cwd those paths do not resolve
# on their own, and nothing in a tool-call shell knows where the workspace
# is -- this file is how a command chain finds out.
echo "--- Workspace root ---"
echo "This session's cwd is NOT the workspace checkout. Every path written"
echo "as \`.agent/scripts/...\` or \`.claude/hooks/...\` below is relative to"
echo "the WORKSPACE ROOT, not to this project. The workspace root is"
echo "recorded in ~/.claude/agent-workspace-root; read it at the head of any"
echo "command chain that needs a workspace script:"
echo ""
echo "    WS_ROOT=\"\$(cat ~/.claude/agent-workspace-root)\""
echo "    \"\$WS_ROOT/.agent/scripts/<script>\" ..."
echo ""
echo "It is a plain file, not an environment variable and not something this"
echo "hook exports: hook output is context text, never shell environment."
echo "(For this machine right now it holds: $WS_ROOT)"
echo ""

# --- workspace layer -----------------------------------------------------
echo "--- Workspace rules (rendered from AGENTS.md) ---"
AGENTS_MD="$WS_ROOT/AGENTS.md"
if [[ -f "$AGENTS_MD" ]]; then
    for heading in "${WORKSPACE_SECTIONS[@]}"; do
        body="$(extract_section "$AGENTS_MD" "$heading")"
        if [[ -n "$body" ]]; then
            printf '%s\n\n' "$body"
        else
            echo "## $heading"
            echo "(section missing from AGENTS.md -- the renderer's heading list is"
            echo "stale; test_session_start_layer.sh should have caught this)"
            echo ""
        fi
    done
else
    echo "(AGENTS.md not found at $AGENTS_MD)"
    echo ""
fi

# --- project layer -------------------------------------------------------
echo "--- Project layer: $P_NAME ---"
echo "Name:  $P_NAME"
echo "Type:  $P_TYPE"
echo "Root:  $P_PATH"

INSTANCES="$(registry_instances "$WS_ROOT" "$P_NAME" 2>/dev/null || true)"
if [[ -n "$INSTANCES" ]]; then
    echo "Instances: $(tr '\n' ' ' <<< "$INSTANCES")"
    DEFAULT_INSTANCE="$(registry_field "$WS_ROOT" "$P_NAME" default_instance 2>/dev/null || true)"
    [[ -n "$DEFAULT_INSTANCE" ]] && echo "Default instance: $DEFAULT_INSTANCE"
fi

PARENT="$(registry_field "$WS_ROOT" "$P_NAME" parent 2>/dev/null || true)"
[[ -n "$PARENT" ]] && echo "Parent root: $PARENT"
DISTRO="$(registry_field "$WS_ROOT" "$P_NAME" distro 2>/dev/null || true)"
[[ -n "$DISTRO" ]] && echo "Distro: $DISTRO"
ROLE="$(registry_field "$WS_ROOT" "$P_NAME" role 2>/dev/null || true)"
[[ -n "$ROLE" ]] && echo "Role: $ROLE"

WT_DIR="$(registry_worktree_dir "$WS_ROOT" "$P_NAME" 2>/dev/null || true)"
[[ -n "$WT_DIR" ]] && echo "Worktrees: $WT_DIR"
echo ""

echo "Build and test go through the adapter, with this project named"
echo "explicitly (several projects are registered on this machine):"
echo ""
echo "    WS_ROOT=\"\$(cat ~/.claude/agent-workspace-root)\""
echo "    \"\$WS_ROOT/.agent/scripts/adapter\" --project $P_NAME build"
echo "    \"\$WS_ROOT/.agent/scripts/adapter\" --project $P_NAME test"
echo "    \"\$WS_ROOT/.agent/scripts/adapter\" --project $P_NAME env"
echo "    \"\$WS_ROOT/.agent/scripts/adapter\" --project $P_NAME validate"
echo ""
echo "Issue scope: issues and PRs for work in this checkout belong to THIS"
echo "project's repo, not agent_workspace. Confirm with \`gh repo view\`."
echo ""

# The project's own conventions, verbatim and unedited -- the workspace
# reads this file, it never writes it.
PROJECT_CLAUDE="$P_PATH/.agent/CLAUDE.md"
if [[ -f "$PROJECT_CLAUDE" ]]; then
    echo "--- $P_NAME's own agent guide ($PROJECT_CLAUDE) ---"
    cat "$PROJECT_CLAUDE"
    echo ""
fi

echo "=== end agent_workspace session layer ==="
exit 0
