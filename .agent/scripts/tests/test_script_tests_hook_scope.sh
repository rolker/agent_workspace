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
# directory, plan round 2 review; extended round 3 with the shell/Python
# forms a scratch suite could still hide behind):
#   - triple `../../..` (or more) in a path expression
#   - two-level `../..` (e.g. `$SCRIPT_DIR/../../project_types`)
#   - the nested `dirname "$(dirname "$(dirname ...` form
#   - `git ... rev-parse --show-toplevel` or `--show-cdup`
#   - Python `Path(__file__)....parent.parent` / `.parents[N]`
#   - Python nested `os.path.dirname(os.path.dirname(...))` chains
#   - shell suffix-stripping parameter expansion, e.g.
#     `${SCRIPT_DIR%/.agent/scripts/tests}` or `${common%/.git}`
#
# This is a heuristic match on known idioms, not a semantic read-detector:
# it cannot see a root reached through a variable indirection, a pathspec,
# or a call into another script, and it only knows the forms listed above.
# A suite using an idiom not on this list will not be flagged. Widen the
# list (and re-run this suite) when a new one turns up, rather than
# treating today's list as closed.
#
# Two special allowlist value forms:
#   - "" (empty) — the suite derives a root but only ever reads from a
#     synthetic sandbox through it (e.g. its own `mktemp -d` tree), or reads
#     a real but git-ignored path that a commit can never change (e.g.
#     `.venv/`); either way nothing tracked is read, so there is nothing to
#     check against the regex. Presence in the array is tested with
#     `${ROOT_READERS[$s]+x}`, not `-n`, so an empty value still counts as
#     "declared".
#   - a token prefixed `git-history:` — the suite reads that path via
#     `git show <fixed-ref>:<path>` (or similar) against history, not the
#     working tree, so a branch commit cannot change what it sees. Exempt
#     from the regex check for the same reason `test_checkpoint_269.sh`'s
#     own gate is exempt from re-running on a work-plans-only commit. This
#     is a strong claim, so it is checked, not taken on faith: restricted to
#     an explicit allowlist of suites (below) and required to actually
#     appear as a `git ... show <ref>:<path>` read in that suite's own
#     source -- a suite cannot claim `git-history:` for a path it reads
#     straight off the working tree.
#   - a token prefixed `manifest:` — the suite's real reads are driven by a
#     manifest file rather than a fixed set of paths (see
#     test_user_tier_guard.sh below); coverage for those reads is asserted
#     separately, by parsing the manifest itself, not by a static prefix.
#     Also restricted to an explicit allowlist, and the value must name the
#     real manifest file the suite actually parses -- otherwise a suite
#     could claim `manifest:` to dodge coverage for reads that are not
#     manifest-driven at all.
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

# assert_not_covered <label> <path>
# The mirror of assert_covered: <path> must NOT run the hook, either
# because exclude: carves it out or because files: never matched it. Guards
# the skip side directly, so removing the work-plans exclude:, or widening
# files: onto plain docs, fails this suite instead of only being caught
# (or not) by whoever notices the hook running on every commit.
assert_not_covered() {  # <label> <path>
    local label="$1" path="$2"
    if path_matches_exclude "$path"; then
        pass "$label: '$path' is excluded by the hook's exclude: regex, as required"
    elif ! path_matches_files "$path"; then
        pass "$label: '$path' is not matched by the hook's files: regex, as required"
    else
        fail "$label: '$path' WOULD run the hook -- files:/exclude: no longer skips it"
    fi
}

# --- Detect every suite that derives a real repository root ---
IDIOM_REGEX='(\.\./){2,}|dirname "\$\(dirname "\$\(dirname|rev-parse --show-(toplevel|cdup)|\.parent\.parent|parents\[|\$\{[A-Za-z_]+%/[^}]*\}|os\.path\.dirname\(os\.path\.dirname'

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
    # Real read is `git -C "$SCRIPT_DIR" rev-parse --git-common-dir` then
    # `${...%/.git}/.venv/bin/python3` -- a real repo root, but .venv/ is
    # git-ignored (never part of a commit diff), so there is nothing a
    # files:/exclude: regex could cover.
    [test_cross_model_review.sh]=""
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

# Prefixes naming a literal file (not a directory) are tested as-is;
# everything else is a directory-shaped prefix and gets a synthetic
# descendant appended before the regex check (see assert_prefix_covered).
LITERAL_FILE_PREFIXES=(
    "AGENTS.md" "Makefile" ".agent/user_tier_scripts.txt"
    ".github/PULL_REQUEST_TEMPLATE.md"
)
is_literal_file_prefix() {
    local p="$1" f
    for f in "${LITERAL_FILE_PREFIXES[@]}"; do
        [[ "$f" == "$p" ]] && return 0
    done
    return 1
}

# assert_prefix_covered <label> <prefix>
# Like assert_covered, but a directory-shaped prefix (e.g. ".claude/skills")
# is checked via a synthetic descendant ("<prefix>/coverage-probe.txt"),
# never the bare prefix string itself -- a files:/exclude: regex anchored
# with a trailing "/" (e.g. `^\.claude/skills/`) only matches a real path
# under it, and checking the bare prefix would silently stop proving
# coverage the moment such a regex replaced a looser one (round-N review).
assert_prefix_covered() {  # <label> <prefix>
    local label="$1" prefix="$2" path="$2"
    is_literal_file_prefix "$prefix" || path="${prefix%/}/coverage-probe.txt"
    assert_covered "$label" "$path"
}

# Only these suites may claim git-history:/manifest: -- see the header
# comment above ROOT_READERS's declaration for why each is restricted.
ALLOWED_GIT_HISTORY_SUITES=("test_checkpoint_269.sh")
ALLOWED_MANIFEST_SUITES=("test_user_tier_guard.sh")
in_list() { local needle="$1" x; shift; for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done; return 1; }

for suite in "${!ROOT_READERS[@]}"; do
    prefixes="${ROOT_READERS[$suite]}"
    [[ -z "$prefixes" ]] && continue  # sandbox-only or git-ignored: nothing to check
    for prefix in $prefixes; do
        case "$prefix" in
            git-history:*)
                path="${prefix#git-history:}"
                if ! in_list "$suite" "${ALLOWED_GIT_HISTORY_SUITES[@]}"; then
                    fail "$suite: 'git-history:' is restricted to ${ALLOWED_GIT_HISTORY_SUITES[*]} -- '$suite' may not claim it for '$path'"
                elif ! grep -qE "show.*${path}" "$SCRIPT_DIR/$suite" 2>/dev/null; then
                    fail "$suite: no 'git ... show <ref>:$path' read found in the suite's source -- 'git-history:$path' is unjustified"
                else
                    pass "$suite: '$path' read via git history ('git show') -- exempt from files: coverage"
                fi
                ;;
            manifest:*)
                path="${prefix#manifest:}"
                if ! in_list "$suite" "${ALLOWED_MANIFEST_SUITES[@]}"; then
                    fail "$suite: 'manifest:' is restricted to ${ALLOWED_MANIFEST_SUITES[*]} -- '$suite' may not claim it for '$path'"
                elif [[ "$REAL_ROOT/$path" != "$MANIFEST" ]]; then
                    fail "$suite: 'manifest:$path' does not name the real manifest ($MANIFEST) -- coverage for its entries would not actually be checked below"
                else
                    pass "$suite: '$path' coverage asserted via manifest scan below"
                fi
                ;;
            *)
                assert_prefix_covered "$suite" "$prefix"
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

# --- Negative assertions: the whole point of files:/exclude: is that most
#     commits skip the hook. Assert that directly, on the skip side, not
#     just on what happens to be covered. ---
assert_not_covered "plain docs file" "README.md"
assert_not_covered "docs tree" "docs/roadmap.md"
assert_not_covered "work-plans progress.md" ".agent/work-plans/issue-354/progress.md"

echo ""
echo "test_script_tests_hook_scope: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
