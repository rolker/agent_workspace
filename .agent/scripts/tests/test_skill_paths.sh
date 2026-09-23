#!/usr/bin/env bash
# .agent/scripts/tests/test_skill_paths.sh
# Keeps project-capable skills free of workspace-relative paths (#317).
#
# A skill whose SKILL.md declares `session_scope: project` or `both` can run
# in a session started in a project checkout. There, a bare
# `.agent/scripts/...` does not resolve -- it names a workspace path from a
# cwd that is not the workspace. Such a skill must write the path as
# `$WS_ROOT/.agent/scripts/...` and resolve $WS_ROOT from
# ~/.claude/agent-workspace-root (ADR-0016).
#
# This test fails on any such reference introduced after this PR.
#
# Scope: SKILL.md files ONLY. The tracked .claude/settings.json keeps its two
# existing relative hook commands as-is -- it is Ask-First and this PR does
# not edit it; the user tier gets its own generated copy with absolute paths
# (user_tier_install.sh). Workspace-scoped skills (no session_scope field --
# `workspace` is the documented default) keep relative paths, which are
# correct for them: they only ever run in the workspace checkout.
#
# Hermetic: reads tracked files only. No HOME access, no network, no gh.
#
# Run: bash .agent/scripts/tests/test_skill_paths.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SKILLS="$WS_ROOT/.claude/skills"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

[[ -d "$SKILLS" ]] || { echo "FATAL: no skills directory at $SKILLS" >&2; exit 1; }

scope_of() {  # <SKILL.md> -- prints the declared session_scope, or "workspace"
    local scope
    scope="$(awk '
        NR == 1 && $0 == "---" { fm = 1; next }
        fm && $0 == "---" { exit }
        fm && /^session_scope:/ { sub(/^session_scope:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit }
    ' "$1")"
    echo "${scope:-workspace}"
}

# A workspace-relative reference: `.agent/scripts/` or `.claude/hooks/` NOT
# already prefixed by $WS_ROOT (or by another path component, which would
# make it part of a longer path rather than a bare relative one).
# Extended past .agent/scripts: a project-capable skill citing any workspace
# directory relatively has the same problem (round 1 review -- audit-project,
# document-project and test-engineering cited .agent/templates/ and
# .agent/knowledge/ and were missed by the narrower pattern).
BAD_RE='(^|[^/A-Za-z0-9_.$-])\.(agent/(scripts|templates|knowledge|project_types|work-plans)|claude/(hooks|skills))/'

scoped=0
for d in "$SKILLS"/*/; do
    f="$d/SKILL.md"
    [[ -f "$f" ]] || continue
    name="$(basename "$d")"
    scope="$(scope_of "$f")"
    case "$scope" in
        project|both) ;;
        workspace) continue ;;
        *)
            fail "$name declares an unknown session_scope: '$scope' (expected project, both, or no field)"
            continue
            ;;
    esac
    scoped=$((scoped + 1))

    # Two exclusions from the scan:
    #  - the YAML frontmatter, whose `description` names files in prose (it
    #    is what the skill picker reads, never a command to run);
    #  - the "Workspace root" section, which states the idiom and so has to
    #    quote the bare paths it is explaining.
    #  - a table explicitly marked `<!-- skill-paths: patterns-not-commands -->`,
    #    whose cells are path PATTERNS matched against a diff, not commands to
    #    run (the marker covers the table rows that follow it).
    body="$(awk '
        NR == 1 && $0 == "---" { fm = 1; next }
        fm { if ($0 == "---") fm = 0; next }
        /^## Workspace root[[:space:]]*$/ { skip = 1; next }
        skip && /^## / { skip = 0 }
        /skill-paths: patterns-not-commands/ { tbl = 1; next }
        tbl && /^[[:space:]]*\|/ { next }
        tbl && /^[[:space:]]*$/ { next }
        tbl { tbl = 0 }
        !skip { print }
    ' "$f")"

    hits="$(grep -nE "$BAD_RE" <<< "$body" || true)"
    if [[ -z "$hits" ]]; then
        pass "$name ($scope): no workspace-relative paths outside the idiom section"
    else
        n=$(grep -c . <<< "$hits")
        fail "$name ($scope): $n workspace-relative reference(s) -- write them as \$WS_ROOT/.agent/scripts/... :"
        head -n3 <<< "$hits" | sed 's/^/        /'
    fi

    # A skill that uses $WS_ROOT must also say where it comes from...
    if grep -q '\$WS_ROOT' "$f"; then
        if grep -q 'agent-workspace-root' "$f"; then
            pass "$name ($scope): \$WS_ROOT is resolved from ~/.claude/agent-workspace-root"
        else
            fail "$name ($scope): uses \$WS_ROOT but never says it comes from ~/.claude/agent-workspace-root"
        fi

        # ...and EVERY resolution must carry the `|| echo .` fallback. The
        # user tier is optional (ADR-0016, and --check says so), so without
        # the fallback $WS_ROOT is empty on a machine that never installed
        # it and every command becomes `/.agent/scripts/...` -- a regression
        # on the relative path this idiom replaced.
        bare=$(grep -nF 'cat ~/.claude/agent-workspace-root' "$f" \
               | grep -v '2>/dev/null || echo \.' || true)
        if [[ -z "$bare" ]]; then
            pass "$name ($scope): every \$WS_ROOT resolution carries the || echo . fallback"
        else
            n=$(grep -c . <<< "$bare")
            fail "$name ($scope): $n bare \`cat\` of agent-workspace-root (no || echo . fallback):"
            head -n3 <<< "$bare" | sed 's/^/        /'
        fi
    fi
done

if [[ "$scoped" -gt 0 ]]; then
    pass "scanned $scoped project-capable skill(s)"
else
    fail "no skill declares session_scope project or both -- the scoped set is empty, so this test proves nothing"
fi

# The frontmatter set itself: the scoped skills are a deliberate list, and a
# typo in the field name would silently drop a skill from the user tier.
for name in start-task plan-task review-plan review-code triage-reviews \
            test-engineering what-next run-issue review-issue address-findings; do
    f="$SKILLS/$name/SKILL.md"
    [[ -f "$f" ]] || { fail "expected skill is missing: $name"; continue; }
    [[ "$(scope_of "$f")" == "both" ]] \
        && pass "$name declares session_scope: both" \
        || fail "$name should declare session_scope: both (got '$(scope_of "$f")')"
done
for name in document-project audit-project onboard-project; do
    f="$SKILLS/$name/SKILL.md"
    [[ -f "$f" ]] || { fail "expected skill is missing: $name"; continue; }
    [[ "$(scope_of "$f")" == "project" ]] \
        && pass "$name declares session_scope: project" \
        || fail "$name should declare session_scope: project (got '$(scope_of "$f")')"
done

echo ""
echo "test_skill_paths: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
