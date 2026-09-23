#!/usr/bin/env bash
# Tests for .agent/scripts/worktree_enter.sh error-output routing (issue #194)
#
# Every failure path must write to stderr only, so callers using the
# exit-code-checked idiom `WT=$(worktree_enter.sh ... 2>/dev/null)` never
# capture error or usage text into $WT. PR #180 routed the "not found"
# paths; the argument-validation paths and the "must be sourced" path were
# missed and regressed silently because nothing exercised them.
#
# Run: bash .agent/scripts/tests/test_worktree_enter_stderr.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/../worktree_enter.sh"

PASS=0
FAIL=0

# One sandbox for the whole run, created at top level (not inside $()) so
# the trap actually fires — see issue #297.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# ---- Offline guarantee (suite-wide) ----
#
# Any path that reaches the script's issue-title lookup
# (`_issue_helpers.sh: issue_lookup`) would otherwise hit the network
# (`gh issue view`) and mutate the shared local git-bug store
# (`git bug bridge pull github`) on every suite run — and this suite runs
# from the pre-commit hook. Both entry points are gated behind
# `command -v gh` / `command -v git-bug`, and `git bug …` dispatches to
# `git-bug` on PATH, so shadowing those two names with inert stubs makes
# the lookup a no-op: it finds nothing and leaves no state behind.
#
# The stubs are installed once here and exported on PATH for the whole
# run, so the guarantee is structural rather than per-test — an added test
# cannot forget the override and leak a real call. The stubs log every
# call so the suite can assert that nothing network-reaching was attempted.
STUB_BIN="$SANDBOX/stub-bin"
STUB_LOG="$SANDBOX/stub-calls.log"

make_offline_stubs() {
    mkdir -p "$STUB_BIN"
    local name
    for name in gh git-bug; do
        cat > "$STUB_BIN/$name" <<STUB
#!/usr/bin/env bash
# Inert stub: records the call, reaches nothing, fails like a missing tool.
printf '%s %s\n' "$name" "\$*" >> "$STUB_LOG"
exit 1
STUB
        chmod +x "$STUB_BIN/$name"
    done
}

make_offline_stubs
: > "$STUB_LOG"
export PATH="$STUB_BIN:$PATH"

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: ${expected}"
        echo "    actual:   ${actual}"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    needle:   ${needle}"
        echo "    haystack: ${haystack}"
        FAIL=$((FAIL + 1))
    fi
}

# Run the script as a command with the given args. Captures stdout and
# stderr separately and the exit status, then asserts: empty stdout,
# non-zero exit, and that stderr carries the expected message.
check_error_path() {
    local label="$1" expected_stderr="$2"
    shift 2
    echo "TEST: $label"

    local stdout stderr rc=0
    stdout=$(bash "$SCRIPT" "$@" 2>/dev/null) || rc=$?
    assert_eq "stdout is empty" "" "$stdout"
    assert_eq "exit status is non-zero" "1" "$([[ $rc -ne 0 ]] && echo 1 || echo 0)"

    stderr=$(bash "$SCRIPT" "$@" 2>&1 >/dev/null) || true
    assert_contains "stderr carries the error" "$expected_stderr" "$stderr"
}

# ---- Argument-validation paths ----

test_unknown_option() {
    check_error_path "unknown option (issue #194 repro)" \
        "Error: Unknown option --foo" \
        --foo bar --print-path
}

test_missing_skill_name() {
    check_error_path "--skill without a name" \
        "Error: --skill requires a skill name" \
        --skill --print-path
}

test_issue_and_skill_exclusive() {
    check_error_path "--issue and --skill together" \
        "Error: --issue and --skill are mutually exclusive" \
        --issue 1 --skill research --type workspace --print-path
}

test_neither_issue_nor_skill() {
    check_error_path "neither --issue nor --skill" \
        "Error: either --issue or --skill is required" \
        --type workspace --print-path
}

# --type became OPTIONAL in #317: when the cwd is inside the workspace
# checkout (as it is here) or under a registered project root, the script
# derives it. The "--type is required" branch survives as a defensive
# fallback for a cwd that derives nothing -- which the user-tier guard
# already refuses, so it is no longer reachable in normal use and is not
# asserted here.
test_missing_type_is_derived() {
    echo "TEST: --type omitted inside the workspace checkout is derived"
    local stderr rc=0
    stderr=$(bash "$SCRIPT" --issue 1 --print-path 2>&1 >/dev/null) || rc=$?
    assert_contains "stderr announces the derivation" \
        "derived --type workspace" "$stderr"
    if [[ "$stderr" != *"--type is required"* ]]; then
        echo "  PASS: no '--type is required' error"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: still reports --type as required despite deriving it"
        FAIL=$((FAIL + 1))
    fi
}

test_invalid_type() {
    check_error_path "--type with an invalid value" \
        "Error: --type must be 'workspace' or 'project'" \
        --issue 1 --type bogus --print-path
}

test_print_path_and_shell_snippet_exclusive() {
    check_error_path "--print-path and --shell-snippet together" \
        "Error: --print-path and --shell-snippet are mutually exclusive" \
        --issue 1 --type workspace --print-path --shell-snippet
}

test_project_requires_project_type() {
    check_error_path "--project with --type workspace" \
        "Error: --project is only valid with --type project" \
        --issue 1 --type workspace --project x --print-path
}

# ---- The usage block on error paths goes to stderr too ----

test_usage_on_error_path_not_on_stdout() {
    echo "TEST: usage block on an error path does not reach stdout"
    local stdout stderr
    stdout=$(bash "$SCRIPT" --foo bar --print-path 2>/dev/null) || true
    stderr=$(bash "$SCRIPT" --foo bar --print-path 2>&1 >/dev/null) || true
    assert_eq "stdout is empty" "" "$stdout"
    assert_contains "usage text is on stderr" "Usage:" "$stderr"
}

test_help_stays_on_stdout() {
    echo "TEST: -h/--help keeps usage on stdout with exit 0"
    local stdout rc=0
    stdout=$(bash "$SCRIPT" --help 2>/dev/null) || rc=$?
    assert_eq "exit status is 0" "0" "$rc"
    assert_contains "usage text is on stdout" "Usage:" "$stdout"
}

# ---- "Must be sourced" path (line ~365) ----
#
# Reaching this path needs the worktree to resolve first. The script's
# last-resort lookup accepts the current git toplevel when its basename
# is `issue-*-<N>` under a `worktrees/workspace/` segment, so stage
# exactly that shape in the sandbox with an issue number no real worktree
# uses. Asserting on the stderr text (not just the exit code) is what
# proves this path — and not an earlier "not found" exit — was taken.
#
# On the way there the script runs its issue-title lookup, which the
# suite-level stubs above neutralise; this test clears the stub log first
# so it can assert those calls landed on the stubs.
test_must_be_sourced() {
    echo "TEST: running as a command without --print-path/--shell-snippet"
    local issue=999999
    local wt="$SANDBOX/worktrees/workspace/issue-workspace-$issue"
    mkdir -p "$wt"
    git -C "$wt" init -q

    : > "$STUB_LOG"

    # worktree_enter.sh is user-tier promoted (#317): it refuses when the
    # cwd is neither inside ITS OWN workspace checkout nor under a
    # registered root. This case deliberately runs from a sandbox worktree,
    # so drive a copy of the script whose workspace root IS that sandbox --
    # otherwise the guard (correctly) refuses before the must-be-sourced
    # message this test is about.
    mkdir -p "$SANDBOX/.agent/scripts"
    local f
    for f in worktree_enter.sh _worktree_helpers.sh _project_registry.sh \
             _issue_helpers.sh _resolve_default_branch.sh; do
        [ -f "${SCRIPT_DIR}/../$f" ] && cp "${SCRIPT_DIR}/../$f" "$SANDBOX/.agent/scripts/"
    done
    local sandbox_script="$SANDBOX/.agent/scripts/worktree_enter.sh"

    local stdout stderr rc=0
    stdout=$(cd "$wt" && bash "$sandbox_script" \
        --issue "$issue" --type workspace 2>/dev/null) || rc=$?
    assert_eq "stdout is empty" "" "$stdout"
    assert_eq "exit status is 1" "1" "$rc"

    stderr=$(cd "$wt" && bash "$sandbox_script" \
        --issue "$issue" --type workspace 2>&1 >/dev/null) || true
    assert_contains "stderr says it must be sourced" "must be sourced" "$stderr"
    assert_contains "stderr carries the follow-up hint" "Use --print-path or --shell-snippet" "$stderr"

    # Prove the shadowing was actually in effect: the lookup's calls landed
    # on the stubs, so no real `gh` / `git-bug` ran — no network request and
    # no write to the shared git-bug store. The stubs are on PATH for the
    # whole run, so the lookup's `command -v` gates always resolve to them
    # and the log is always written — assert it unconditionally.
    assert_eq "issue lookup was served by the inert stubs" \
        "1" "$([[ -s "$STUB_LOG" ]] && echo 1 || echo 0)"
}

# ---- Invariants against future additions ----
#
# Per-path tests only cover the paths that exist today. These two greps
# turn the rule the fix establishes into something the suite enforces:
# every line that emits an `Error:` message carries `>&2`, and every
# `show_usage` call except the one on the -h|--help path carries `>&2`.
#
# The emitter pattern matches `echo` and `printf` alike, and doesn't
# anchor on the quoting style, so a future `printf "Error: ..."` or
# `printf 'Error: %s\n' ...` is covered too.
test_invariant_error_echoes_routed() {
    echo "TEST: no echo/printf line emitting \"Error:\" lacks >&2"
    # Assumes one emitter per line with its redirect on the same line: a
    # `{ echo "Error: ..."; } >&2` block, a line-continued printf, or a
    # comment holding both tokens would be misread by this line-scoped grep.
    local unrouted
    unrouted=$(grep -nE '(echo|printf)[[:space:]].*Error:' "$SCRIPT" | grep -v '>&2' || true)
    assert_eq "un-routed Error emitters" "" "$unrouted"
}

test_invariant_show_usage_routed() {
    echo "TEST: every show_usage call except -h|--help carries >&2"
    local unrouted count prev
    unrouted=$(grep -nE '^[[:space:]]*show_usage([[:space:]]|$)' "$SCRIPT" | grep -v '>&2' || true)
    count=$(printf '%s' "$unrouted" | grep -c . || true)
    assert_eq "exactly one un-routed show_usage call" "1" "$count"
    # ...and that one must be the -h|--help case.
    local line
    line=$(printf '%s' "$unrouted" | cut -d: -f1)
    prev=$(awk -v n="$line" 'NR==n-1' "$SCRIPT")
    assert_contains "the un-routed call is the -h|--help path" "-h|--help)" "$prev"
}

# ---- Run all tests ----
echo "=== worktree_enter.sh stderr routing tests ==="
echo ""

test_unknown_option
test_missing_skill_name
test_issue_and_skill_exclusive
test_neither_issue_nor_skill
test_missing_type_is_derived
test_invalid_type
test_print_path_and_shell_snippet_exclusive
test_project_requires_project_type
test_usage_on_error_path_not_on_stdout
test_help_stays_on_stdout
test_must_be_sourced
test_invariant_error_echoes_routed
test_invariant_show_usage_routed

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
