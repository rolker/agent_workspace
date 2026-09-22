#!/usr/bin/env bash
# .agent/scripts/tests/test_session_start_layer.sh
# Tests for .claude/hooks/session_start_project_layer.sh (#317, #265 PR 3).
#
# Two concerns:
#
# 1. Heading drift. The hook renders the workspace layer from a PINNED list
#    of AGENTS.md headings. A rename or deletion upstream would otherwise
#    produce a silently empty layer -- the session would look normal and
#    simply carry no rules. For every pinned heading this asserts that it
#    exists verbatim in AGENTS.md, that the extracted section is non-empty,
#    and that extraction STOPS at the next same-level heading rather than
#    swallowing the rest of the file.
#
# 2. The silent / inject branches. This is the hermetic proxy for the live
#    acceptance test (plan review finding 13): the hook is driven directly
#    with a synthetic registry and a {"cwd": ...} payload, so both branches
#    are covered without a live `claude` session. What only a live session
#    can prove -- that Claude Code actually splices this stdout into context
#    -- stays in the acceptance test.
#
# Hermetic: one `mktemp -d` sandbox, which honours TMPDIR; HOME redirected, no
# network, no gh.
#
# Run: bash .agent/scripts/tests/test_session_start_layer.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOK="$WS_ROOT/.claude/hooks/session_start_project_layer.sh"
AGENTS_MD="$WS_ROOT/AGENTS.md"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

for req in "$HOOK" "$AGENTS_MD"; do
    [[ -f "$req" ]] || { echo "FATAL: missing $req" >&2; exit 1; }
done
command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required" >&2; exit 1; }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# ------------------------------------------------------- heading drift ---
# The pinned list is read back out of the hook itself, so the test cannot
# drift from the renderer: adding a heading there adds a case here.
mapfile -t HEADINGS < <(
    awk '/^WORKSPACE_SECTIONS=\(/ {inside=1; next}
         inside && /^\)/ {exit}
         inside {gsub(/^[[:space:]]*"/, ""); gsub(/"[[:space:]]*$/, ""); print}
    ' "$HOOK"
)

if [[ "${#HEADINGS[@]}" -gt 0 ]]; then
    pass "read ${#HEADINGS[@]} pinned headings out of the hook"
else
    fail "could not read WORKSPACE_SECTIONS out of the hook -- the array's shape changed"
fi

# Same extractor the hook uses, kept in lockstep deliberately: if the hook's
# extraction changes, this test's expectations must be revisited with it.
extract_section() {  # <file> <heading>
    awk -v want="## $2" '
        $0 == want { inside = 1; print; next }
        inside && /^## / { exit }
        inside { print }
    ' "$1"
}

for h in "${HEADINGS[@]}"; do
    # (a) the heading exists verbatim
    if grep -qxF "## $h" "$AGENTS_MD"; then
        pass "heading exists verbatim in AGENTS.md: ## $h"
    else
        fail "PINNED HEADING MISSING from AGENTS.md: ## $h -- renaming a section without updating the hook empties the workspace layer"
        continue
    fi

    body="$(extract_section "$AGENTS_MD" "$h")"

    # (b) the extracted section has content beyond its own heading line
    lines=$(wc -l <<< "$body")
    content=$(grep -vcE '^[[:space:]]*$' <<< "$body")
    if [[ "$lines" -gt 1 && "$content" -gt 1 ]]; then
        pass "section is non-empty: ## $h ($((content - 1)) content lines)"
    else
        fail "section '## $h' extracted empty -- the heading exists but has no body"
    fi

    # (c) extraction stops at the next same-level heading
    other_h2=$(grep -cE '^## ' <<< "$body")
    if [[ "$other_h2" -eq 1 ]]; then
        pass "extraction stops at the next '## ' heading: ## $h"
    else
        fail "section '## $h' swallowed $((other_h2 - 1)) further '## ' heading(s) -- the extractor is not bounded"
    fi
done

# A negative control: the extractor must return nothing for a heading that
# is not in the file, so case (b) above can actually fail when it should.
if [[ -z "$(extract_section "$AGENTS_MD" "No Such Heading Anywhere")" ]]; then
    pass "extractor returns nothing for an absent heading (negative control)"
else
    fail "extractor returned content for an absent heading -- case (b) cannot fail"
fi

# --------------------------------------------- silent / inject branches ---
# A sandbox workspace copy with its own registry, a registered project root,
# and an unrelated repo. The hook is invoked by absolute path with a
# {"cwd": ...} payload, exactly as Claude Code would.
WSC="$SANDBOX/ws"
mkdir -p "$WSC/.claude/hooks" "$WSC/.agent/scripts"
cp "$HOOK" "$WSC/.claude/hooks/"
cp "$WS_ROOT/.agent/scripts/_project_registry.sh" "$WSC/.agent/scripts/"
cp -r "$WS_ROOT/.agent/project_types" "$WSC/.agent/"
cp "$AGENTS_MD" "$WSC/AGENTS.md"

PROOT="$SANDBOX/demo"
mkdir -p "$PROOT/.agent"
echo "demo single_project $PROOT" > "$WSC/.agent/projects.local"

OUTSIDE="$SANDBOX/unrelated"
mkdir -p "$OUTSIDE"

FAKE_HOME="$SANDBOX/home"
mkdir -p "$FAKE_HOME/.claude"

run_hook() {  # <cwd>
    HOME="$FAKE_HOME" bash "$WSC/.claude/hooks/session_start_project_layer.sh" \
        <<< "$(jq -n --arg cwd "$1" '{hook_event_name: "SessionStart", cwd: $cwd}')" 2>&1
}

out=$(run_hook "$OUTSIDE"); rc=$?
if [[ "$rc" -eq 0 && -z "$out" ]]; then
    pass "unrelated repo: silent (no output, exit 0)"
else
    fail "unrelated repo produced output (rc=$rc out=${out:0:200})"
fi

out=$(run_hook "$WSC"); rc=$?
if [[ "$rc" -eq 0 && -z "$out" ]]; then
    pass "workspace checkout itself: silent (its own layer already loads)"
else
    fail "workspace checkout produced output (rc=$rc out=${out:0:200})"
fi

out=$(run_hook "$PROOT"); rc=$?
if [[ "$rc" -ne 0 ]]; then
    fail "registered root: hook exited $rc"
else
    ok=1
    # shellcheck disable=SC2088  # these are literal strings to find in the
    # hook's output, not paths this script expands
    for want in \
        "agent_workspace session layer" \
        "Project: demo" \
        "Project root: $PROOT" \
        "--- Workspace root ---" \
        "~/.claude/agent-workspace-root" \
        "relative to" \
        "Workspace rules (rendered from AGENTS.md)" \
        "## Boundaries" \
        "## Quality Standard" \
        "--- Project layer: demo ---" \
        "adapter\" --project demo build" \
        "end agent_workspace session layer"
    do
        [[ "$out" == *"$want"* ]] || { fail "registered root: layer is missing '$want'"; ok=0; }
    done
    [[ "$ok" -eq 1 ]] && pass "registered root: both layers printed, with the workspace-root idiom"
fi

# A cwd deeper inside the root injects the same way (ancestor match).
mkdir -p "$PROOT/src/deep"
out=$(run_hook "$PROOT/src/deep")
[[ "$out" == *"Project: demo"* ]] \
    && pass "a cwd deep inside a registered root injects the layer" \
    || fail "deep cwd did not inject"

# The idiom line must come BEFORE the workspace rules it qualifies --
# otherwise a reader meets bare `.agent/scripts/` paths first.
idiom_at=$(grep -n -- "--- Workspace root ---" <<< "$out" | head -n1 | cut -d: -f1)
rules_at=$(grep -n "Workspace rules (rendered from AGENTS.md)" <<< "$out" | head -n1 | cut -d: -f1)
if [[ -n "$idiom_at" && -n "$rules_at" && "$idiom_at" -lt "$rules_at" ]]; then
    pass "the workspace-root idiom precedes the rendered workspace rules"
else
    fail "the workspace-root idiom does not precede the workspace rules (idiom=$idiom_at rules=$rules_at)"
fi

# The project's own agent guide is included verbatim when it exists.
printf '# demo conventions\nAlways run the demo linter.\n' > "$PROOT/.agent/CLAUDE.md"
out=$(run_hook "$PROOT")
if [[ "$out" == *"Always run the demo linter."* && "$out" == *"demo's own agent guide"* ]]; then
    pass "the project's own .agent/CLAUDE.md is included verbatim"
else
    fail "the project's own .agent/CLAUDE.md was not included"
fi

# No KEY=value line a script could be tempted to parse (ADR-0016: hook
# stdout is context text, never environment).
if grep -qE '^(WORKTREE_TYPE|PROJECT|AGENT_WORKSPACE_ROOT)=' <<< "$out"; then
    fail "the layer prints a script-parseable KEY=value line -- hook stdout is not environment"
else
    pass "the layer prints no script-parseable KEY=value lines"
fi

# A malformed payload must not break a session.
out=$(HOME="$FAKE_HOME" bash "$WSC/.claude/hooks/session_start_project_layer.sh" <<< 'not json' 2>&1); rc=$?
[[ "$rc" -eq 0 ]] && pass "a malformed payload still exits 0 (never blocks a session start)" \
    || fail "a malformed payload exited $rc"

echo ""
echo "test_session_start_layer: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
