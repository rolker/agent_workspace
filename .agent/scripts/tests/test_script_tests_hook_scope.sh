#!/usr/bin/env bash
# .agent/scripts/tests/test_script_tests_hook_scope.sh
# Issue #354: the `validate-script-tests` pre-commit hook now runs only on
# commits matching a `files:`/`exclude:` regex, instead of `always_run: true`
# on every commit. This suite guards the regex against drift going forward:
# it does not re-confirm today's known-good path prefixes (that only proves
# today's suites read what today's suites read) — it detects, by shape, every
# suite that derives a *real* repository root (as opposed to a `mktemp -d`
# sandbox root), and requires each one to declare in an allowlist here the
# out-of-tree path prefixes it actually reads from that root. Every declared
# prefix is then checked against the hook's real regex in
# .pre-commit-config.yaml. A suite that starts deriving a root without a
# matching allowlist entry fails this suite loudly, by name, rather than
# silently reading outside the hook's scope.
#
# Root-derivation idioms detected (confirmed against every suite in this
# directory, plan round 2 review):
#   - triple `../../..` (or more) in a path expression
#   - two-level `../..` (e.g. `$SCRIPT_DIR/../../project_types`)
#   - the nested `dirname "$(dirname "$(dirname ...` form
#   - `git ... rev-parse --show-toplevel`
#   - Python `Path(__file__)....parent.parent` / `.parents[N]`
#
# Two special allowlist value forms:
#   - "" (empty) — the suite derives a root but only ever reads from a
#     synthetic sandbox through it (e.g. its own `mktemp -d` tree); nothing
#     real is read, so there is nothing to check against the regex. Presence
#     in the array is tested with `${ROOT_READERS[$s]+x}`, not `-n`, so an
#     empty value still counts as "declared".
#   - a token prefixed `git-history:` — the suite reads that path via
#     `git show <fixed-ref>:<path>` (or similar) against history, not the
#     working tree, so a branch commit cannot change what it sees. Exempt
#     from the regex check for the same reason `test_checkpoint_269.sh`'s
#     own gate is exempt from re-running on a work-plans-only commit.
#   - a token prefixed `manifest:` — the suite's real reads are driven by a
#     manifest file rather than a fixed set of paths (see
#     test_user_tier_guard.sh below); coverage for those reads is asserted
#     separately, by parsing the manifest itself, not by a static prefix.
#
# Hermetic: reads only the real .pre-commit-config.yaml and the real
# .agent/scripts/tests/ directory and .agent/user_tier_scripts.txt; writes
# nothing.
# Run: bash .agent/scripts/tests/test_script_tests_hook_scope.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

CONFIG="$REAL_ROOT/.pre-commit-config.yaml"
MANIFEST="$REAL_ROOT/.agent/user_tier_scripts.txt"

if [[ ! -f "$CONFIG" ]]; then
    fail "$CONFIG not found"
    echo ""
    echo "test_script_tests_hook_scope: ${PASS} passed, ${FAIL} failed"
    exit 1
fi

# --- Parse the validate-script-tests hook block out of the real config ---
BLOCK="$(awk '
    /- id: validate-script-tests/ { flag=1 }
    flag && /- id:/ && !/validate-script-tests/ { exit }
    flag { print }
' "$CONFIG")"

if [[ -z "$BLOCK" ]]; then
    fail "validate-script-tests hook block not found in .pre-commit-config.yaml"
    echo ""
    echo "test_script_tests_hook_scope: ${PASS} passed, ${FAIL} failed"
    exit 1
fi

FILES_REGEX="$(echo "$BLOCK" | grep -m1 -E '^\s*files:' | sed -E 's/^\s*files:\s*//')"
EXCLUDE_REGEX="$(echo "$BLOCK" | grep -m1 -E '^\s*exclude:' | sed -E 's/^\s*exclude:\s*//')"

if [[ -z "$FILES_REGEX" ]]; then
    fail "hook has no files: regex (always_run drift, or regex removed) -- expected a files: line"
else
    pass "parsed files: regex from .pre-commit-config.yaml: $FILES_REGEX"
fi
if echo "$BLOCK" | grep -qE '^\s*always_run:\s*true'; then
    fail "hook still has always_run: true -- mutually exclusive with files:, and defeats the scoping"
else
    pass "always_run: true is gone from the hook"
fi

path_matches_files() { [[ "$1" =~ $FILES_REGEX ]]; }
path_matches_exclude() { [[ -n "$EXCLUDE_REGEX" && "$1" =~ $EXCLUDE_REGEX ]]; }

assert_covered() {  # <label> <path>
    local label="$1" path="$2"
    if path_matches_exclude "$path"; then
        fail "$label: '$path' is excluded by the hook's exclude: regex"
    elif path_matches_files "$path"; then
        pass "$label: '$path' is covered by the hook's files: regex"
    else
        fail "$label: '$path' is NOT covered by the hook's files: regex"
    fi
}

# --- Detect every suite that derives a real repository root ---
IDIOM_REGEX='(\.\./){2,}|dirname "\$\(dirname "\$\(dirname|rev-parse --show-toplevel|\.parent\.parent|parents\['

mapfile -t ROOT_DERIVING < <(
    cd "$SCRIPT_DIR" && grep -lE "$IDIOM_REGEX" test_*.sh test_*.py 2>/dev/null \
        | grep -v '^test_script_tests_hook_scope\.sh$' \
        | sort
)

if [[ ${#ROOT_DERIVING[@]} -eq 0 ]]; then
    fail "root-derivation scan found no suites at all -- scan is almost certainly broken (expected 15+)"
fi

# --- Allowlist: suite -> space-separated out-of-tree read prefixes ---
declare -A ROOT_READERS=(
    [test_adapter.sh]=".agent/scripts .agent/project_types"
    # The real gate itself (GATED_FILES) diffs merge-base..HEAD over these
    # paths -- that's a HEAD-side read, not history the branch can't touch,
    # so only progress.md (read via `git show <base>:...`) is git-history:
    # exempt. Every other GATED_FILES entry is already under .agent/ or
    # .claude/ (covered); .github/PULL_REQUEST_TEMPLATE.md is the one path
    # outside those prefixes, so it is declared here as a real prefix.
    [test_checkpoint_269.sh]="git-history:.agent/work-plans .github/PULL_REQUEST_TEMPLATE.md"
    [test_dispatch_phase.sh]=".agent/project_types .agent/scripts"
    [test_merge_pr_gate.sh]=".agent/scripts"
    [test_merge_pr_root_resolution.sh]=""
    [test_merge_pr.sh]=".agent/scripts"
    [test_precommit_hook_path.sh]="Makefile .agent/scripts"
    [test_progress_read.py]=".agent/scripts"
    [test_project_registry.sh]=".agent/scripts .agent/project_types"
    [test_resolve_work_plans_dir.sh]=""
    [test_ros2_colcon.sh]=".agent/scripts .agent/project_types"
    [test_session_start_layer.sh]=".claude/hooks AGENTS.md .agent/scripts .agent/project_types"
    [test_skill_paths.sh]=".claude/skills"
    [test_sync_gitbug.sh]=".agent/project_types"
    # Reads are manifest-driven (.agent/user_tier_scripts.txt), which
    # includes .claude/hooks/log-tool-use.sh -- a static prefix list can't
    # track manifest drift, so coverage for those is asserted separately
    # below by parsing the manifest itself. Also does a whole-tree
    # `cp -r $WS_ROOT/.agent` / `.claude` (same argument as
    # test_user_tier_install.sh below).
    [test_user_tier_guard.sh]="manifest:.agent/user_tier_scripts.txt .agent/ .claude/"
    [test_user_tier_install.sh]=".agent/ .claude/"
)

for suite in "${ROOT_DERIVING[@]}"; do
    if [[ "${ROOT_READERS[$suite]+x}" != "x" ]]; then
        fail "'$suite' derives a real repo root (matched the root-derivation scan) but has no ROOT_READERS entry -- add one naming the out-of-tree prefixes it reads, or an empty entry if it only reads its own sandbox"
    else
        pass "'$suite' has a declared ROOT_READERS entry"
    fi
done

for suite in "${!ROOT_READERS[@]}"; do
    found=0
    for s in "${ROOT_DERIVING[@]}"; do
        [[ "$s" == "$suite" ]] && found=1 && break
    done
    if [[ $found -eq 0 ]]; then
        fail "'$suite' has a ROOT_READERS entry but the root-derivation scan no longer matches it -- stale allowlist entry (suite renamed/rewritten/removed?)"
    fi
done

for suite in "${!ROOT_READERS[@]}"; do
    prefixes="${ROOT_READERS[$suite]}"
    [[ -z "$prefixes" ]] && continue  # sandbox-only: nothing to check
    for prefix in $prefixes; do
        case "$prefix" in
            git-history:*)
                pass "$suite: '${prefix#git-history:}' read via git history -- exempt from files: coverage"
                ;;
            manifest:*)
                pass "$suite: '${prefix#manifest:}' coverage asserted via manifest scan below"
                ;;
            *)
                assert_covered "$suite" "$prefix"
                ;;
        esac
    done
done

# --- Manifest-driven reads: test_user_tier_guard.sh reads every entry in
#     .agent/user_tier_scripts.txt (plus the manifest file itself). A static
#     prefix can't track this list, so check every real entry against the
#     hook's actual regex directly. ---
if [[ ! -f "$MANIFEST" ]]; then
    fail "$MANIFEST not found -- test_user_tier_guard.sh's real input is missing"
else
    assert_covered "user_tier_scripts.txt manifest itself" ".agent/user_tier_scripts.txt"
    manifest_entries=0
    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        [[ -z "$line" ]] && continue
        manifest_entries=$((manifest_entries + 1))
        assert_covered "user_tier_scripts.txt entry" "$line"
    done < "$MANIFEST"
    if [[ $manifest_entries -eq 0 ]]; then
        fail "no entries parsed from $MANIFEST -- manifest parser or file format drifted"
    else
        pass "checked $manifest_entries manifest entries against the hook's files:/exclude: regex"
    fi
fi

echo ""
echo "test_script_tests_hook_scope: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
