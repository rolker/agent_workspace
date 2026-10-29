#!/usr/bin/env bash
# .agent/scripts/tests/test_script_tests_hook_scope.sh
# Issue #354: the `validate-script-tests` pre-commit hook now runs only on
# commits matching a `files:`/`exclude:` regex, instead of `always_run: true`
# on every commit. This suite guards the regex against drift going forward:
# it does not re-confirm today's known-good path prefixes (that only proves
# today's suites read what today's suites read) — it detects, by shape,
# suites that derive a *real* repository root via a known idiom (as opposed
# to a `mktemp -d` sandbox root), and requires each one to declare in an
# allowlist here the out-of-tree path prefixes it actually reads from that
# root. Every declared
# prefix is then checked against the hook's real regex in
# .pre-commit-config.yaml. A suite that starts deriving a root without a
# matching allowlist entry fails this suite loudly, by name, rather than
# silently reading outside the hook's scope.
#
# Root-derivation idioms detected (confirmed against every suite in this
# directory, plan round 2 review; extended round 3 with the shell/Python
# forms a scratch suite could still hide behind):
#   - triple `../../..` (or more) in a path expression
#   - two-level `../../` with the slash repeated (e.g.
#     `$SCRIPT_DIR/../../project_types`) -- a same-depth `../..` *without*
#     the repeated slash (e.g. `$dir/../..`) does not match; that gap falls
#     under the heuristic-miss disclaimer below
#   - the nested `dirname "$(dirname "$(dirname ...` form
#   - `git ... rev-parse --show-toplevel` or `--show-cdup`
#   - Python `Path(__file__)....parent.parent` / `.parents[N]`
#   - Python nested `os.path.dirname(os.path.dirname(...))` chains
#   - shell suffix-stripping parameter expansion, shortest or longest
#     match, e.g. `${SCRIPT_DIR%/.agent/scripts/tests}`, `${common%/.git}`
#     or `${SCRIPT_DIR%%/.agent/*}`
#
# This is a heuristic match on known idioms, not a semantic read-detector:
# it cannot see a root reached through a variable indirection, a pathspec,
# or a call into another script, and it only knows the forms listed above.
# A suite using an idiom not on this list will not be flagged. Widen the
# list (and re-run this suite) when a new one turns up, rather than
# treating today's list as closed.
#
# Three special allowlist value forms:
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
# Issue #410 adds, at the end: the hook entry pin (`--files`,
# pass_filenames, require_serial), drift checks on the suite map that
# suites_for_files.sh derives (every suite maps to something; each
# ROOT_READERS prefix agrees with the derived map; every `# covers:` /
# `# scans:` path is tracked), and real-tree checks of the mapper itself
# (a hub guard on register_project.sh, the all-files list runs everything,
# every .agent/scripts/_*.sh helper runs everything, a file no code names
# runs everything).
#
# Hermetic: reads only the real .pre-commit-config.yaml, the real
# .agent/scripts/tests/ directory, .agent/user_tier_scripts.txt and the
# repository's tracked files (`git ls-files`, `git grep`, and
# suites_for_files.sh, which only reads); writes nothing.
# Run: bash .agent/scripts/tests/test_script_tests_hook_scope.sh
#
# Selection declaration for run_script_tests.sh --files (issue #410): every
# check here scans the whole suites directory, so any change under it must
# select this suite.
# scans: .agent/scripts/tests/

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
IDIOM_REGEX='(\.\./){2,}|dirname "\$\(dirname "\$\(dirname|rev-parse --show-(toplevel|cdup)|\.parent\.parent|parents\[|\$\{[A-Za-z_]+%{1,2}/[^}]*\}|os\.path\.dirname\(os\.path\.dirname'

mapfile -t ROOT_DERIVING < <(
    cd "$SCRIPT_DIR" && grep -lE "$IDIOM_REGEX" test_*.sh test_*.py 2>/dev/null \
        | grep -v '^test_script_tests_hook_scope\.sh$' \
        | sort
)

if [[ ${#ROOT_DERIVING[@]} -eq 0 ]]; then
    fail "root-derivation scan found no suites at all -- scan is almost certainly broken (expected 15+)"
fi

# --- Allowlist: suite -> space-separated out-of-tree read prefixes ---
#
# Issue #410: these prefixes say where a suite reads or copies from the
# real root. They do NOT select suites for run_script_tests.sh --files
# (`.agent/scripts` alone would pull in ten suites); they feed drift check
# (b) at the end of this file only, which requires each suite's derived map
# to include a tracked file under each of its prefixes. A suite that
# *scans* a whole prefix (a `git grep`, a directory walk) is a different
# kind: copying a file in is visible in the text of what runs, scanning is
# not. Such a suite carries a `# scans: <prefix>` line in its own header
# (test_skill_paths.sh, test_plugin_manifest.sh, this suite), which does
# select it. Check (b) does not cover scanning suites; their `# scans:`
# lines do.
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
    # Reads the real plugin manifests and every skill's frontmatter
    # (`claude plugin validate` runs on the checkout root too).
    [test_plugin_manifest.sh]=".claude-plugin .claude/skills"
    [test_progress_read.py]=".agent/scripts"
    # Copies the real scripts and the two adapters into its sandbox workspace.
    [test_project_file.sh]=".agent/scripts .agent/project_types"
    [test_project_registry.sh]=".agent/scripts .agent/project_types"
    # Copies the real scripts, project types, user-tier list, .claude and
    # .claude-plugin into its sandbox workspace.
    [test_register_project.sh]=".agent/scripts .agent/project_types .agent/user_tier_scripts.txt .claude .claude-plugin"
    [test_resolve_work_plans_dir.sh]=""
    [test_ros2_colcon.sh]=".agent/scripts .agent/project_types"
    # Whole-tree `cp -r $WS_ROOT/.agent` into its sandbox workspace.
    [test_session_root.sh]=".agent/"
    [test_session_start_layer.sh]=".claude/hooks AGENTS.md .agent/scripts .agent/project_types"
    # Runs the sit-rep skill's own shell steps, read from its SKILL.md.
    [test_sitrep_checks.sh]=".claude/skills"
    # SKILL.md scan, plus the #389 git grep for live pointers to the old
    # what-next skill over these hook-covered prefixes (docs/ and README.md
    # are deliberately not read: the hook's files: regex does not cover them).
    [test_skill_paths.sh]=".agent/ .claude/ AGENTS.md Makefile"
    # Whole-tree `cp -r $WS_ROOT/.agent` into its sandbox workspace.
    [test_skill_prefix.sh]=".agent/"
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
#
# The synthetic probe proves coverage of the prefix as a whole (including
# files added later), but not of any one real file under it: an exclude:
# naming a single file (e.g. `^\.agent/scripts/_bookkeeping\.sh$`) leaves
# the probe covered. So a directory prefix also checks every file git
# tracks under it (`git ls-files`), reporting one pass line per prefix and
# one fail line per uncovered file. Files under TRACKED_FILE_EXEMPT are
# skipped: that is the hook's deliberate exclude: (work-plans), carried
# only by the whole-tree `.agent/` copies, and asserted on the skip side at
# the bottom of this suite.
TRACKED_FILE_EXEMPT_RE='^\.agent/work-plans/'
assert_prefix_covered() {  # <label> <prefix>
    local label="$1" prefix="$2" path="$2"
    is_literal_file_prefix "$prefix" || path="${prefix%/}/coverage-probe.txt"
    assert_covered "$label" "$path"
    is_literal_file_prefix "$prefix" && return 0
    local f checked=0 uncovered=0
    while IFS= read -r f; do
        [[ "$f" =~ $TRACKED_FILE_EXEMPT_RE ]] && continue
        checked=$((checked + 1))
        if path_matches_exclude "$f" || ! path_matches_files "$f"; then
            uncovered=$((uncovered + 1))
            fail "$label: tracked file '$f' under '$prefix' is NOT covered by the hook's files:/exclude: regex"
        fi
    done < <(git -C "$REAL_ROOT" ls-files -- "${prefix%/}/")
    if [[ $checked -eq 0 ]]; then
        fail "$label: no tracked files found under '$prefix' -- prefix is stale, or git ls-files failed"
    elif [[ $uncovered -eq 0 ]]; then
        pass "$label: all $checked tracked files under '$prefix' are covered"
    fi
}

# Only these suites may claim git-history:/manifest: -- see the header
# comment above ROOT_READERS's declaration for why each is restricted.
ALLOWED_GIT_HISTORY_SUITES=("test_checkpoint_269.sh")
ALLOWED_MANIFEST_SUITES=("test_user_tier_guard.sh")
in_list() { local needle="$1" x; shift; for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done; return 1; }

# strip_line_comments: strips comments from stdin -- both whole-line (`#...`)
# and trailing (`code  # ...`) -- from the first whitespace-or-line-start `#`
# onward. This is a simple heuristic, not a shell parser: it does not
# understand quoting, so a literal `#` inside a quoted string would also be
# stripped. No suite's real `git ... show <ref>:<path>` line contains a `#`,
# so this never clips a legitimate match.
strip_line_comments() { sed -E 's/(^|[[:space:]])#.*$//'; }

# git_history_shape_match <path_re>: reads candidate source lines from stdin
# (after strip_line_comments), and checks for the real
# `git ... show <ref>:<path>` shape -- literal `git`, then `show` as its own
# whitespace-delimited word (so `--show-toplevel` does not count), then the
# `<ref>:` token directly after it (no whitespace between `show` and the
# `:`), then the path -- not just the bare word "show" anywhere on the line,
# which a comment could satisfy on its own. POSIX ERE only (no `\b`), and
# every one of those parts is pinned by a direct case further down. This is the single
# source of truth for the shape check: both the real ROOT_READERS scan below
# and the direct comment-stripping test further down call this same
# function, so a regression in either the stripping or the match regex is
# caught by the test rather than silently passing a stale copy.
git_history_shape_match() {
    local path_re="$1"
    strip_line_comments \
        | grep -qE "git[^#]*[[:space:]]show[[:space:]]+[^[:space:]]*:.*${path_re}"
}

for suite in "${!ROOT_READERS[@]}"; do
    prefixes="${ROOT_READERS[$suite]}"
    [[ -z "$prefixes" ]] && continue  # sandbox-only or git-ignored: nothing to check
    for prefix in $prefixes; do
        case "$prefix" in
            git-history:*)
                path="${prefix#git-history:}"
                # Regex-quote the path (dots are the only metachar prefixes
                # here use) and require the real `git ... show <ref>:<path>`
                # shape via git_history_shape_match (see its definition
                # above for the comment-stripping and matching rules).
                path_re="${path//./\\.}"
                if ! in_list "$suite" "${ALLOWED_GIT_HISTORY_SUITES[@]}"; then
                    fail "$suite: 'git-history:' is restricted to ${ALLOWED_GIT_HISTORY_SUITES[*]} -- '$suite' may not claim it for '$path'"
                elif ! git_history_shape_match "$path_re" < "$SCRIPT_DIR/$suite" 2>/dev/null; then
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

# --- Direct check on the git-history comment-stripping logic itself: a
#     trailing comment on a code line (e.g. `foo  # git show main:...`)
#     must not satisfy the `git ... show <ref>:<path>` shape -- only real
#     code should. This calls the SAME git_history_shape_match function the
#     real ROOT_READERS scan above uses (not a private copy), so a
#     regression in the real check trips this test too. Synthetic input
#     strings only, no files written, so this stays within the suite's
#     hermetic contract. ---
if printf '%s\n' 'foo  # git show main:.agent/work-plans/x' \
        | git_history_shape_match '\.agent/work-plans/x'; then
    fail "git-history comment-stripping: a trailing comment ('foo  # git show ...') still satisfies the shape check"
else
    pass "git-history comment-stripping: a trailing comment ('foo  # git show ...') does not satisfy the shape check"
fi
if printf '%s\n' 'git -C "$repo" show "${base_ref}:.agent/work-plans/x"' \
        | git_history_shape_match '\.agent/work-plans/x'; then
    pass "git-history comment-stripping: the legitimate code line (no '#') still matches"
else
    fail "git-history comment-stripping: the legitimate code line (no '#') no longer matches -- stripping broke real code"
fi
# The match regex itself: a `git <ref>:<path>` line without `show` (here
# `git log`) must not match -- this pins the `show` requirement, which
# the two cases above do not depend on.
if printf '%s\n' 'git log main:.agent/work-plans/x' \
        | git_history_shape_match '\.agent/work-plans/x'; then
    fail "git-history shape: a 'git log <ref>:<path>' line (no 'show') still satisfies the shape check -- the 'show' requirement is gone"
else
    pass "git-history shape: a 'git log <ref>:<path>' line (no 'show') does not satisfy the shape check"
fi
# A real `git ... show <ref>:<path>` code line followed by a trailing
# comment must still match: stripping removes only the comment, not the code.
if printf '%s\n' 'git -C "$repo" show "${base_ref}:.agent/work-plans/x"  # read the base plan' \
        | git_history_shape_match '\.agent/work-plans/x'; then
    pass "git-history shape: a real 'git ... show <ref>:<path>' line with a trailing comment still matches"
else
    fail "git-history shape: a real 'git ... show <ref>:<path>' line with a trailing comment no longer matches -- stripping clipped the code"
fi

# Each remaining part of the shape regex, pinned by a line that only that
# part rejects (loosening any one of them makes exactly its case match):
#   - `git` required:            no `git` on the line at all
#   - space before `show`:       `show` as the tail of another word
#   - space after `show`:        a ref that merely starts with `show`
#   - `<ref>:` right after show: the `:<path>` is further along the line
#   - both spaces together:      `--show-toplevel`, which the old `\bshow\b`
#                                form wrongly accepted
while IFS='|' read -r shape_why shape_line; do
    if printf '%s\n' "$shape_line" | git_history_shape_match '\.agent/work-plans/x'; then
        fail "git-history shape: $shape_why still satisfies the shape check: $shape_line"
    else
        pass "git-history shape: $shape_why does not satisfy the shape check"
    fi
done <<'SHAPE_NEGATIVES'
a line without 'git'|echo show main:.agent/work-plans/x
'show' inside another word|git log --grep=reshow main:.agent/work-plans/x
a ref starting with 'show'|git log showcase:.agent/work-plans/x
'show' not followed by a '<ref>:' token|git show HEAD >/dev/null; cat "$root":.agent/work-plans/x
'--show-toplevel'|root="$(git rev-parse --show-toplevel)":.agent/work-plans/x
SHAPE_NEGATIVES

# --- Direct check on the root-derivation IDIOM_REGEX's suffix-stripping
#     form: both shortest (`%`) and longest (`%%`) match must be detected,
#     and a plain `${VAR}` must not. Synthetic strings only. ---
for idiom_case in 'ROOT="${SCRIPT_DIR%/.agent/scripts/tests}"' 'ROOT="${SCRIPT_DIR%%/.agent/*}"'; do
    if printf '%s\n' "$idiom_case" | grep -qE "$IDIOM_REGEX"; then
        pass "root-derivation scan: suffix-stripping idiom detected: $idiom_case"
    else
        fail "root-derivation scan: suffix-stripping idiom NOT detected: $idiom_case"
    fi
done
if printf '%s\n' 'cd "${SCRIPT_DIR}"' | grep -qE "$IDIOM_REGEX"; then
    fail "root-derivation scan: a plain '\${SCRIPT_DIR}' is flagged as a root-derivation idiom"
else
    pass "root-derivation scan: a plain '\${SCRIPT_DIR}' is not flagged"
fi

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

# --- The hook's own inputs: everything above checks paths ROOT_READERS (or
#     the manifest scan) declares. Nothing yet forces the hook's own
#     trigger set -- .pre-commit-config.yaml itself, the runner it invokes,
#     and the suites directory it runs -- to actually be covered. Dropping
#     .pre-commit-config.yaml from files:, or adding an exclude: for
#     .agent/scripts/tests/, would silently pass every assertion above while
#     leaving a config or suite change unable to trigger the hook locally.
#     Assert coverage of those inputs directly. ---
assert_covered "hook config itself" ".pre-commit-config.yaml"
assert_covered "hook runner script" ".agent/scripts/tests/run_script_tests.sh"
assert_covered "a suite under .agent/scripts/tests/" ".agent/scripts/tests/test_script_tests_hook_scope.sh"

# --- Negative assertions: the whole point of files:/exclude: is that most
#     commits skip the hook. Assert that directly, on the skip side, not
#     just on what happens to be covered. ---
assert_not_covered "plain docs file" "README.md"
assert_not_covered "docs tree" "docs/roadmap.md"
assert_not_covered "work-plans progress.md" ".agent/work-plans/issue-354/progress.md"

# ===================================================================
# Issue #410: scoped runs. The hook passes the changed files and
# run_script_tests.sh runs only the suites suites_for_files.sh selects.
# ===================================================================

# --- (e) The hook entry passes the files, in one process. ---
ENTRY="$(echo "$BLOCK" | grep -m1 -E '^\s*entry:' | sed -E 's/^\s*entry:\s*//; s/\s+$//')"
if [[ "$ENTRY" == *"run_script_tests.sh --files" ]]; then
    pass "hook entry ends in 'run_script_tests.sh --files': $ENTRY"
else
    fail "hook entry does not end in 'run_script_tests.sh --files' (scoped runs need the file list): $ENTRY"
fi
if echo "$BLOCK" | grep -qE '^\s*pass_filenames:\s*true\s*$'; then
    pass "pass_filenames: true"
else
    fail "hook lacks pass_filenames: true -- the runner would get no files and run every suite"
fi
if echo "$BLOCK" | grep -qE '^\s*require_serial:\s*true\s*$'; then
    pass "require_serial: true"
else
    fail "hook lacks require_serial: true -- pre-commit could split the file list across parallel runner processes"
fi

MAPPER="$SCRIPT_DIR/suites_for_files.sh"
REL_TESTS=".agent/scripts/tests"
# map_once <file>...: one mapper run; sets map_out (its stdout: ALL or suite
# names) and map_err (its "suites_for_files: ..." reason lines).
map_once() {
    local both
    both="$(bash "$MAPPER" -- "$@" 2>&1)"
    map_out="$(grep -v '^suites_for_files: ' <<<"$both")"
    map_err="$(grep '^suites_for_files: ' <<<"$both")"
}
assert_covered "suite mapper" "$REL_TESTS/suites_for_files.sh"

# --- The derived map, for the drift checks. ---
DUMP="$(bash "$MAPPER" --dump 2>/dev/null)"
if [[ -z "$DUMP" || "$(head -n1 <<<"$DUMP")" == "ALL" ]]; then
    fail "suites_for_files.sh --dump produced no map (it errored): $(bash "$MAPPER" --dump 2>&1 | tail -n 3)"
    DUMP=""
fi

shopt -s nullglob
ALL_SUITES=("$SCRIPT_DIR"/test_*.sh)
shopt -u nullglob

# (a) every suite maps to something: a derived reference or a declaration.
#     A suite with neither would join every scoped run silently.
for sp in "${ALL_SUITES[@]}"; do
    sn="$(basename "$sp")"
    if grep -qP "^\Q$sn\E\t" <<<"$DUMP"; then
        pass "(a) $sn has a derived reference or a declaration"
    else
        fail "(a) $sn derives no reference and has no '# covers:' / '# scans:' line -- declare what it reads"
    fi
done

# map_paths <suite>...: the ref and covers paths of those suites.
map_paths() {
    local s
    for s in "$@"; do
        awk -F'\t' -v s="$s" '$1 == s && ($2 == "ref" || $2 == "covers") { print $3 }' <<<"$DUMP"
    done
}

# (b) real-root readers only: each declared prefix agrees with the derived
#     map. A ROOT_READERS key that is not a test_*.sh (test_progress_read.py)
#     is checked through the suites that map it (other than this suite, which
#     names every ROOT_READERS key by design).
for suite in "${!ROOT_READERS[@]}"; do
    owners=()
    if [[ "$suite" == test_*.sh ]]; then
        owners=("$suite")
    else
        mapfile -t owners < <(awk -F'\t' -v p="$REL_TESTS/$suite" -v self="$(basename "${BASH_SOURCE[0]}")" \
            '($2 == "ref" || $2 == "covers") && $3 == p && $1 != self { print $1 }' <<<"$DUMP" | sort -u)
        if [[ ${#owners[@]} -eq 0 ]]; then
            fail "(b) $suite: no suite maps it -- declare it with a '# covers:' line in the suite that runs it"
            continue
        fi
    fi
    paths="$(map_paths "${owners[@]}")"
    for prefix in ${ROOT_READERS[$suite]}; do
        case "$prefix" in git-history:*|manifest:*) continue ;; esac
        p="${prefix%/}"
        if awk -v p="$p" '$0 == p || index($0, p "/") == 1 { found = 1 } END { exit !found }' <<<"$paths"; then
            pass "(b) $suite: derived map includes a file under its declared prefix '$prefix'"
        else
            fail "(b) $suite: declares '$prefix' but its derived map has no file under it -- it reads paths text derivation cannot see; add a '# covers:' line naming them"
        fi
    done
done

# (c) every declared path is tracked: an exact '# covers:' file by name, a
#     '# scans:' prefix by having at least one tracked file under it.
while IFS=$'\t' read -r suite kind path; do
    case "$kind" in
        covers)
            if git -C "$REAL_ROOT" ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
                pass "(c) $suite: '# covers: $path' is a tracked file"
            else
                fail "(c) $suite: '# covers: $path' is not a tracked file (stale or misspelt declaration)"
            fi
            ;;
        scans)
            if [[ -n "$(git -C "$REAL_ROOT" ls-files -- "$path" | head -n1)" ]]; then
                pass "(c) $suite: '# scans: $path' has tracked files"
            else
                fail "(c) $suite: '# scans: $path' matches no tracked file (stale or misspelt declaration)"
            fi
            ;;
    esac
done <<<"$DUMP"

# --- Real-tree checks of the mapper. ---

# Hub guard: a single script change stays selective. register_project.sh
# selects 4 suites today (test_register_project.sh, this suite through its
# ROOT_READERS text, test_checkpoint_269.sh always, and test_skill_paths.sh
# through its '# scans: .agent/'). A file that starts naming everything
# turns this red instead of silently restoring the full run.
HUB_MAX=5
map_once .agent/scripts/register_project.sh
hub_out="$map_out"
hub_n="$(grep -c . <<<"$hub_out")"
if [[ "$hub_out" != "ALL" && "$hub_n" -le $HUB_MAX ]] \
        && grep -qx 'test_register_project.sh' <<<"$hub_out"; then
    pass "hub guard: register_project.sh selects $hub_n suites (at most $HUB_MAX), including test_register_project.sh"
else
    fail "hub guard: register_project.sh should select at most $HUB_MAX suites including test_register_project.sh; got: $(tr '\n' ' ' <<<"$hub_out")"
fi

# The all-files list (what CI's `pre-commit run --all-files` passes) runs
# every suite. Not by running them: this suite only asks the mapper.
mapfile -t all_in_scope < <(
    git -C "$REAL_ROOT" ls-files | while IFS= read -r f; do
        path_matches_files "$f" && ! path_matches_exclude "$f" && printf '%s\n' "$f"
    done
)
map_once "${all_in_scope[@]}"
pin_out="$map_out" pin_err="$map_err"
if [[ "$pin_out" == "ALL" && "$pin_err" != *"error:"* ]]; then
    pass "all ${#all_in_scope[@]} in-scope tracked files select ALL"
else
    fail "all ${#all_in_scope[@]} in-scope tracked files should select ALL (not by error); got: $(tr '\n' ' ' <<<"$pin_out") / $pin_err"
fi

# Every shared helper runs everything, matched by the same glob the mapper
# uses, so a new helper needs no edit here.
shopt -s nullglob
helpers=("$REAL_ROOT"/.agent/scripts/_*.sh)
shopt -u nullglob
if [[ ${#helpers[@]} -eq 0 ]]; then
    fail "no .agent/scripts/_*.sh helpers found -- the glob or the tree changed"
fi
for h in "${helpers[@]}"; do
    rel=".agent/scripts/$(basename "$h")"
    map_once "$rel"
    h_out="$map_out" h_err="$map_err"
    if [[ "$h_out" == "ALL" && "$h_err" == *"shared helper"* ]]; then
        pass "helper $rel selects ALL"
    else
        fail "helper $rel should select ALL as a shared helper; got: $(tr '\n' ' ' <<<"$h_out") / $h_err"
    fi
done

# A currently unmapped in-scope file still runs everything, despite the
# '# scans:' prefixes (which cover nearly the whole scope). The candidate
# is chosen without the mapper: a tracked .agent/knowledge/*.md whose
# basename appears in no tracked non-markdown file, so no suite or code
# file can name it.
unmapped=""
while IFS= read -r f; do
    base="$(basename "$f")"
    if [[ -z "$(git -C "$REAL_ROOT" grep -l -F -e "$base" -- ':(exclude)*.md' ':(exclude).agent/work-plans/' 2>/dev/null)" ]]; then
        unmapped="$f"
        break
    fi
done < <(git -C "$REAL_ROOT" ls-files -- '.agent/knowledge/*.md')
if [[ -z "$unmapped" ]]; then
    fail "no tracked .agent/knowledge/*.md is unnamed by every non-markdown file -- pick another candidate source for this check"
else
    map_once "$unmapped"
    u_out="$map_out" u_err="$map_err"
    if [[ "$u_out" == "ALL" && "$u_err" == *"maps to no suite"* ]]; then
        pass "unmapped in-scope file $unmapped selects ALL (scan prefixes do not count as a mapping)"
    else
        fail "unmapped in-scope file $unmapped should select ALL as unmapped; got: $(tr '\n' ' ' <<<"$u_out") / $u_err"
    fi
fi

echo ""
echo "test_script_tests_hook_scope: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
