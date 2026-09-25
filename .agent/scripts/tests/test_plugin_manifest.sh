#!/usr/bin/env bash
# .agent/scripts/tests/test_plugin_manifest.sh
# Mechanical check of the agent-workspace Claude Code plugin manifest
# (ADR-0017, #345):
#   - .claude-plugin/plugin.json and marketplace.json are valid JSON, carry
#     the names user_tier_install.sh enables (agent-workspace@agent-workspace),
#     and the marketplace's one plugin is sourced from the checkout root;
#   - plugin.json's `skills` array is exactly the skills whose SKILL.md
#     declares `session_scope: project` or `both` -- re-derived here with its
#     own frontmatter parser, not by calling the generator that wrote it, so
#     a generator bug and a hand edit are both caught;
#   - every listed path is a skill directory with a SKILL.md;
#   - `claude plugin validate` passes, when the claude CLI is on PATH
#     (skipped with a note otherwise -- CI and Codex-only machines lack it).
#     Validation is read-only: no session, no settings written;
#   - nothing but skills ships (no default plugin component directory at
#     the checkout root, no other component key in the manifest).
#
# Fix a skills-array failure with `make generate-user-tier-skills` and commit
# the rewritten manifest.
#
# Run: bash .agent/scripts/tests/test_plugin_manifest.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PLUGIN="$WS_ROOT/.claude-plugin/plugin.json"
MARKET="$WS_ROOT/.claude-plugin/marketplace.json"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required" >&2; exit 1; }

# ----------------------------------------------------------- shape ---
for f in "$PLUGIN" "$MARKET"; do
    if jq -e . "$f" >/dev/null 2>&1; then
        pass "$(basename "$f") is valid JSON"
    else
        fail "$(basename "$f") is missing or not valid JSON"
    fi
done

[[ "$(jq -r '.name // ""' "$PLUGIN" 2>/dev/null)" == "agent-workspace" ]] \
    && pass "plugin name is agent-workspace" \
    || fail "plugin.json name is not agent-workspace"
[[ "$(jq -r '.name // ""' "$MARKET" 2>/dev/null)" == "agent-workspace" ]] \
    && pass "marketplace name is agent-workspace (the installer enables agent-workspace@agent-workspace)" \
    || fail "marketplace.json name is not agent-workspace"
[[ "$(jq -c '[.plugins[]? | {name, source}]' "$MARKET" 2>/dev/null)" == '[{"name":"agent-workspace","source":"./"}]' ]] \
    && pass "the marketplace lists exactly one plugin, agent-workspace, sourced from ./" \
    || fail "marketplace.json plugins entry is not [{name: agent-workspace, source: ./}] (got $(jq -c '.plugins' "$MARKET" 2>/dev/null))"
[[ "$(jq -r '.skills | type' "$PLUGIN" 2>/dev/null)" == "array" ]] \
    && pass "plugin.json skills is an array of per-skill paths" \
    || fail "plugin.json skills is not an array"

# ------------------------------------- skills match session_scope ---
# Independent of user_tier_install.sh's selected_skills(): the frontmatter
# is the block between a first-line `---` and the next `---`.
scope_of() {  # <SKILL.md>
    local line in_fm=0 n=0
    while IFS= read -r line; do
        n=$((n + 1))
        if [[ "$n" -eq 1 ]]; then
            [[ "$line" == "---" ]] || return 0
            in_fm=1; continue
        fi
        [[ "$line" == "---" ]] && return 0
        if [[ "$in_fm" -eq 1 && "$line" =~ ^session_scope:[[:space:]]*[\"\']?([a-z]+) ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
            return 0
        fi
    done < "$1"
}
expected=()
for d in "$WS_ROOT"/.claude/skills/*/; do
    [[ -f "$d/SKILL.md" ]] || continue
    case "$(scope_of "$d/SKILL.md")" in
        project|both) expected+=("./.claude/skills/$(basename "$d")") ;;
    esac
done
want="$(printf '%s\n' "${expected[@]}" | LC_ALL=C sort)"
got="$(jq -r '.skills[]?' "$PLUGIN" 2>/dev/null | LC_ALL=C sort)"
if [[ "$want" == "$got" ]]; then
    pass "plugin.json skills == the session_scope project|both skills (${#expected[@]})"
else
    fail "plugin.json skills differ from session_scope frontmatter -- run \`make generate-user-tier-skills\` and commit:"
    diff <(echo "$want") <(echo "$got") | sed 's/^/      /'
fi
[[ "${#expected[@]}" -gt 0 ]] \
    && pass "at least one skill is exposed (the frontmatter parse found something)" \
    || fail "no session_scope project|both skill found -- the parser or the tree is wrong"

missing=0
while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    [[ -f "$WS_ROOT/${p#./}/SKILL.md" ]] || { fail "listed skill path has no SKILL.md: $p"; missing=1; }
done <<< "$got"
[[ "$missing" -eq 0 ]] && pass "every listed skill path is a skill directory with a SKILL.md"

# Generated /make_* skills are gitignored per-machine files; they must never
# be shipped through the plugin.
if grep -q '/make_' <<< "$got"; then
    fail "plugin.json lists a generated /make_* skill"
else
    pass "no generated /make_* skill is listed"
fi

# The plugin root is the checkout root, and Claude Code loads a plugin's
# default component locations from it whether or not plugin.json names them.
# This PR ships skills only (hooks are #351): nothing else may appear there
# or in the manifest by accident.
extra=()
for c in commands agents hooks bin output-styles .mcp.json .lsp.json; do
    [[ -e "$WS_ROOT/$c" ]] && extra+=("$c")
done
for k in commands agents hooks mcpServers lspServers outputStyles; do
    jq -e --arg k "$k" 'has($k)' "$PLUGIN" >/dev/null 2>&1 && extra+=("plugin.json:$k")
done
[[ "${#extra[@]}" -eq 0 ]] \
    && pass "the plugin ships skills only (no default component dirs at the root, no other manifest keys)" \
    || fail "the plugin would also ship: ${extra[*]}"

# -------------------------------------------- claude plugin validate ---
if command -v claude >/dev/null 2>&1; then
    if vout="$(cd "$WS_ROOT" && claude plugin validate . 2>&1)"; then
        pass "claude plugin validate passes"
    else
        fail "claude plugin validate failed:"
        sed 's/^/      /' <<< "$vout"
    fi
else
    echo "  SKIP: claude CLI not on PATH -- claude plugin validate not run"
fi

echo ""
echo "test_plugin_manifest: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
