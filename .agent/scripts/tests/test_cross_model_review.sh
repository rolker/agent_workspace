#!/usr/bin/env bash
# Tests for cross_model_review.sh
#
# Tests argument parsing, issue extraction, artifact path resolution, and
# empty diff guard. Uses mock gh/agent binaries to avoid real API calls.
#
# Run: bash .agent/scripts/tests/test_cross_model_review.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_UNDER_TEST="${SCRIPT_DIR}/../cross_model_review.sh"

PASS=0
FAIL=0
TMPDIR_BASE=""

# One sandbox for the whole run, created at top level (not inside $()) so
# the trap actually fires — see issue #297. No hardcoded /tmp template:
# `mktemp -d` honors TMPDIR, so the run stays inside whatever temp root the
# caller set. Each test's setup/teardown still carves and drops its own
# TMPDIR_BASE under it; the trap is the backstop for an abort.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

setup() {
    TMPDIR_BASE=$(mktemp -d -p "$SANDBOX")

    # Create a mock git repo so git rev-parse works
    MOCK_REPO="${TMPDIR_BASE}/repo"
    mkdir -p "${MOCK_REPO}"
    git -C "${MOCK_REPO}" init -q
    git -C "${MOCK_REPO}" -c user.name="Test" -c user.email="test@test" commit --allow-empty -m "init" -q

    # Create mock bin directory
    MOCK_BIN="${TMPDIR_BASE}/bin"
    mkdir -p "${MOCK_BIN}"

    # Mock agy CLI (the gemini agent's binary post-#223), implementing the
    # stream-json contract _agy_review.sh drives (#274, #288):
    #   * argv is recorded to MOCK_AGY_LOG when set (one arg per line);
    #   * the prompt arrives on stdin as one NDJSON line
    #     {"event":"user","message":{"role":"user","content":...}};
    #   * stdout is an NDJSON event stream ending in a `result` event
    #     whose `response` echoes the prompt content back.
    # Knobs (env):
    #   MOCK_AGY_DENY=1     empty response + denied_actions, exit 0 (#288)
    #   MOCK_AGY_TIMEOUT=1  SUCCESS result + the print-timeout stderr marker
    #   MOCK_AGY_EXIT=<n>   exit <n> after printing "boom" on stderr
    cat > "${MOCK_BIN}/agy" << 'MOCK_EOF'
#!/usr/bin/env bash
if [[ -n "${MOCK_AGY_LOG:-}" ]]; then
    printf '%s\n' "$@" >> "${MOCK_AGY_LOG}"
fi
if [[ -n "${MOCK_AGY_EXIT:-}" ]]; then
    echo "boom" >&2
    exit "${MOCK_AGY_EXIT}"
fi
# Stream-json contract: exactly one NDJSON message per line. A
# pretty-printed (multi-line) message is a contract violation even if a
# lenient JSON reader would accept it, so the mock refuses it.
input=$(cat)
if [[ "$(printf '%s\n' "$input" | wc -l)" -ne 1 ]]; then
    echo "mock agy: stdin is not a single NDJSON line" >&2
    exit 9
fi
echo '{"event":"init","init":{"tools":[]}}'
if [[ -n "${MOCK_AGY_DENY:-}" ]]; then
    echo 'jetski: no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied.' >&2
    echo '{"event":"result","result":{"status":"SUCCESS","response":"","denied_actions":[{"action":"command","display_name":"RunCommand"}]}}'
    exit 0
fi
if [[ -n "${MOCK_AGY_TIMEOUT:-}" ]]; then
    echo '[agy] print timeout after 1s with turn in progress; returning partial output' >&2
    echo '{"event":"result","result":{"status":"SUCCESS","response":"partial text"}}'
    exit 0
fi
# Echo the prompt back as the response. Streamed, never a shell variable
# or argv: the whole point of the stdin contract is prompts larger than
# the kernel's per-argument limit, and the mock must not reintroduce it.
printf '%s\n' "$input" | jq -r 'select(.event == "user") | .message.content' \
    | jq -c -Rs '{event:"result",result:{status:"SUCCESS",response:.}}'
MOCK_EOF
    chmod +x "${MOCK_BIN}/agy"

    # Mock gh: valid PR body, non-empty diff. MOCK_GH_DIFF_FILE (env)
    # substitutes a prepared diff for `gh pr diff`.
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2; PR="$1"; shift
    [[ "${1:-}" == "-R" ]] && shift 2
    if [[ "$1" == "--json" && "$2" == "body" ]]; then
        echo "Closes #42"
    elif [[ "$1" == "--json" && "$2" == "title" ]]; then
        echo "Test PR"
    elif [[ "$1" == "--json" && "$2" == "url" ]]; then
        echo "https://github.com/test/repo/pull/99"
    fi
elif [[ "$1" == "pr" && "$2" == "diff" ]]; then
    if [[ -n "${MOCK_GH_DIFF_FILE:-}" ]]; then
        cat "${MOCK_GH_DIFF_FILE}"
    else
        echo "diff --git a/file.txt b/file.txt"
        echo "--- a/file.txt"
        echo "+++ b/file.txt"
        echo "@@ -1 +1 @@"
        echo "-old"
        echo "+new"
    fi
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"
}

teardown() {
    [[ -n "$TMPDIR_BASE" ]] && rm -rf "$TMPDIR_BASE"
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" pattern="$2" text="$3"
    if echo "$text" | grep -qE "$pattern"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    pattern not found: $pattern"
        echo "    in: $text"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local label="$1" pattern="$2" text="$3"
    if echo "$text" | grep -qE "$pattern"; then
        echo "  FAIL: $label"
        echo "    unexpected pattern found: $pattern"
        echo "    in: $text"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    fi
}

assert_exit_code() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS: $label (exit $actual)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label"
        echo "    expected exit: $expected"
        echo "    actual exit:   $actual"
        FAIL=$((FAIL + 1))
    fi
}

# ---- Test: --repo flag is accepted and overrides auto-detection ----
test_repo_flag_accepted() {
    echo "TEST: --repo flag is accepted"
    setup

    # Mock gh that records arguments and returns direct values for --jq-style
    # queries used by the test.
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
echo "$@" >> "${MOCK_GH_LOG}"
# Detect which gh subcommand
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2  # consume "pr view"
    PR_NUM="$1"; shift
    # Consume -R flag if present
    if [[ "${1:-}" == "-R" ]]; then
        echo "REPO_FLAG=$2" >> "${MOCK_GH_LOG}"
        shift 2
    fi
    if [[ "$1" == "--json" && "$2" == "body" ]]; then
        echo "Closes #42"
        exit 0
    elif [[ "$1" == "--json" && "$2" == "title" ]]; then
        echo "Test PR"
        exit 0
    elif [[ "$1" == "--json" && "$2" == "url" ]]; then
        echo "https://github.com/test/repo/pull/99"
        exit 0
    fi
elif [[ "$1" == "pr" && "$2" == "diff" ]]; then
    shift 2
    PR_NUM="$1"; shift
    if [[ "${1:-}" == "-R" ]]; then
        echo "REPO_FLAG=$2" >> "${MOCK_GH_LOG}"
        shift 2
    fi
    echo "diff --git a/file.txt b/file.txt"
    echo "--- a/file.txt"
    echo "+++ b/file.txt"
    echo "@@ -1 +1 @@"
    echo "-old"
    echo "+new"
    exit 0
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"

    export MOCK_GH_LOG="${TMPDIR_BASE}/gh_calls.log"
    true > "$MOCK_GH_LOG"

    # Run the script with --repo and --sync (to avoid tmux). Set
    # WORKTREE_ISSUE=42 (matching the mock PR body's "Closes #42") so the
    # work-plans-dir resolver (issue #147) accepts the invocation instead
    # of aborting with "not in matching worktree."
    cd "${MOCK_REPO}"
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --repo test/repo --sync >/dev/null 2>&1 || true

    # Verify gh was called with -R test/repo
    if grep -q "REPO_FLAG=test/repo" "$MOCK_GH_LOG"; then
        echo "  PASS: --repo flag passed through to gh as -R"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: --repo flag not passed through to gh"
        echo "    gh log: $(cat "$MOCK_GH_LOG")"
        FAIL=$((FAIL + 1))
    fi

    teardown
}

# ---- Test: issue extraction from PR body ----
# Helper: mirrors the extraction logic from cross_model_review.sh.
# Post-#149: keyword-only — no loose "#N anywhere" fallback.
extract_issue() {
    local body="$1"
    local ref num
    ref=$(printf '%s\n' "$body" \
        | grep -ioE '(^|[^[:alnum:]_])(closes|fixes|resolves)[[:space:]]+([a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+)?#[0-9]+' \
        | head -n1 || true)
    num=$(printf '%s\n' "$ref" | grep -oE '[0-9]+$' || true)
    printf '%s' "${num:-}"
}

test_issue_extraction() {
    echo "TEST: issue number extraction (keyword-only, post-#149)"

    # Positive cases — keyword match wins
    assert_eq "Closes #42 -> 42" "42" "$(extract_issue 'Some text. Closes #42. More text.')"
    assert_eq "fixes #123 -> 123" "123" "$(extract_issue 'fixes #123')"
    assert_eq "Resolves owner/repo#77 -> 77" "77" "$(extract_issue 'Resolves owner/repo#77')"
    assert_eq "CLOSES #5 -> 5" "5" "$(extract_issue 'CLOSES #5')"
    # A real keyword later in the body wins over substring false positives
    assert_eq "encloses #42, Closes #99 -> 99" "99" "$(extract_issue 'encloses #42 but Closes #99')"

    # Post-#149: no keyword means empty — no loose "#N anywhere" fallback
    assert_eq "encloses #42 (substring only) -> empty" "" "$(extract_issue 'encloses #42')"
    assert_eq "prefixes #7 (substring only) -> empty" "" "$(extract_issue 'prefixes #7')"
    assert_eq "no keyword, '#N' in body -> empty" "" "$(extract_issue 'Related to #10 and #20')"
    assert_eq "No issue ref -> empty" "" "$(extract_issue 'No issue reference here')"
}

# ---- Test: --work-dir controls artifact placement ----
test_work_dir_flag() {
    echo "TEST: --work-dir controls artifact placement"
    setup

    local custom_dir="${TMPDIR_BASE}/custom_workdir"
    mkdir -p "$custom_dir"

    # Mock gh
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2; PR="$1"; shift
    [[ "${1:-}" == "-R" ]] && shift 2
    if [[ "$1" == "--json" && "$2" == "body" ]]; then
        echo "Closes #42"
    elif [[ "$1" == "--json" && "$2" == "title" ]]; then
        echo "Test PR"
    elif [[ "$1" == "--json" && "$2" == "url" ]]; then
        echo "https://github.com/test/repo/pull/99"
    fi
elif [[ "$1" == "pr" && "$2" == "diff" ]]; then
    echo "diff --git a/file.txt b/file.txt"
    echo "--- a/file.txt"
    echo "+++ b/file.txt"
    echo "@@ -1 +1 @@"
    echo "-old"
    echo "+new"
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"

    cd "${MOCK_REPO}"
    PATH="${MOCK_BIN}:${PATH}" bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --work-dir "${custom_dir}" --sync >/dev/null 2>&1 || true

    # Check that artifacts were written under custom_dir, not repo root
    if [[ -d "${custom_dir}/.agent/work-plans/issue-42" ]]; then
        echo "  PASS: artifacts written under --work-dir"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: artifacts not found under --work-dir"
        echo "    expected dir: ${custom_dir}/.agent/work-plans/issue-42"
        echo "    ls custom_dir: $(find "${custom_dir}" -type f 2>/dev/null || echo 'empty')"
        FAIL=$((FAIL + 1))
    fi

    # Also verify artifacts are NOT under the repo root
    if [[ -d "${MOCK_REPO}/.agent/work-plans/issue-42" ]]; then
        echo "  FAIL: artifacts leaked to repo root despite --work-dir"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: no artifacts in repo root"
        PASS=$((PASS + 1))
    fi

    teardown
}

# ---- Test: empty diff guard ----
test_empty_diff_guard() {
    echo "TEST: empty diff guard exits with error"
    setup

    # Mock gh that returns empty diff
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2; PR="$1"; shift
    [[ "${1:-}" == "-R" ]] && shift 2
    if [[ "$1" == "--json" && "$2" == "body" ]]; then
        echo "Closes #42"
    elif [[ "$1" == "--json" && "$2" == "title" ]]; then
        echo "Test PR"
    elif [[ "$1" == "--json" && "$2" == "url" ]]; then
        echo "https://github.com/test/repo/pull/99"
    fi
elif [[ "$1" == "pr" && "$2" == "diff" ]]; then
    # Return empty diff (no output)
    true
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"

    # WORKTREE_ISSUE=42 matches the mock PR's "Closes #42" so the resolver
    # (issue #147) accepts the invocation; this test exercises the empty-
    # diff guard, not the worktree check.
    cd "${MOCK_REPO}"
    local exit_code=0
    STDERR=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --sync 2>&1) || exit_code=$?

    assert_exit_code "empty diff exits 3" "3" "$exit_code"
    assert_contains "error message mentions empty diff" "diff is empty" "$STDERR"

    # Check that an error marker was written to findings file
    local findings_file="${MOCK_REPO}/.agent/work-plans/issue-42/review-gemini-findings.md"
    if [[ -f "$findings_file" ]]; then
        local content
        content=$(cat "$findings_file")
        assert_contains "findings file has error marker" "Review error" "$content"
    else
        echo "  FAIL: findings file not created for error marker"
        FAIL=$((FAIL + 1))
    fi

    teardown
}

# ---- Test: missing --pr flag ----
test_missing_pr_flag() {
    echo "TEST: missing --pr flag exits 2"

    local exit_code=0
    bash "${SCRIPT_UNDER_TEST}" --agent gemini 2>/dev/null || exit_code=$?
    assert_exit_code "missing --pr exits 2" "2" "$exit_code"
}

# ---- Test: unknown argument ----
test_unknown_argument() {
    echo "TEST: unknown argument exits 2"

    local exit_code=0
    bash "${SCRIPT_UNDER_TEST}" --pr 1 --bogus 2>/dev/null || exit_code=$?
    assert_exit_code "unknown arg exits 2" "2" "$exit_code"
}

# ---- Test: --repo with invalid slug ----
test_invalid_repo_slug() {
    echo "TEST: --repo with invalid slug exits 2"
    setup

    local exit_code=0
    STDERR=$(PATH="${MOCK_BIN}:${PATH}" bash "${SCRIPT_UNDER_TEST}" --pr 1 --repo "not-a-slug" 2>&1) || exit_code=$?
    assert_exit_code "invalid slug exits 2" "2" "$exit_code"
    assert_contains "error mentions invalid slug" "not a valid owner/repo" "$STDERR"

    teardown
}

# ---- Test: resolver refuses outside matching worktree ----
test_resolver_refuses_without_worktree_issue() {
    echo "TEST: resolver refuses when WORKTREE_ISSUE unset / mismatched"
    setup

    # Mock gh returns a PR body with "Closes #42"
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2; PR="$1"; shift
    [[ "${1:-}" == "-R" ]] && shift 2
    if [[ "$1" == "--json" && "$2" == "body" ]]; then
        echo "Closes #42"
    fi
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"

    cd "${MOCK_REPO}"

    # Case 1: WORKTREE_ISSUE unset -> resolver rule 3 aborts with exit 4.
    local exit_code=0
    STDERR=$(unset WORKTREE_ISSUE; PATH="${MOCK_BIN}:${PATH}" \
        bash "${SCRIPT_UNDER_TEST}" --pr 99 --sync 2>&1) || exit_code=$?
    assert_exit_code "unset WORKTREE_ISSUE exits 4" "4" "$exit_code"
    assert_contains "error mentions worktree" "worktree" "$STDERR"

    # Case 2: WORKTREE_ISSUE mismatched -> same abort, different message.
    exit_code=0
    STDERR=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=100 \
        bash "${SCRIPT_UNDER_TEST}" --pr 99 --sync 2>&1) || exit_code=$?
    assert_exit_code "mismatched WORKTREE_ISSUE exits 4" "4" "$exit_code"
    assert_contains "error names the mismatch" "'100', not '42'" "$STDERR"

    teardown
}

# ---- Test: flag-as-value is rejected ----
test_flag_as_value_rejected() {
    echo "TEST: --flag --other-flag pattern is rejected"

    local exit_code=0
    STDERR=$(bash "${SCRIPT_UNDER_TEST}" --work-plans-dir --sync 2>&1) || exit_code=$?
    assert_exit_code "--work-plans-dir --sync exits 2" "2" "$exit_code"
    assert_contains "error mentions missing value" "Missing value for --work-plans-dir" "$STDERR"

    exit_code=0
    STDERR=$(bash "${SCRIPT_UNDER_TEST}" --pr --sync 2>&1) || exit_code=$?
    assert_exit_code "--pr --sync exits 2" "2" "$exit_code"
    assert_contains "error mentions missing value" "Missing value for --pr" "$STDERR"
}

# ---- Test: gh repo view resolves SSH host alias / Enterprise URLs (#150) ----
#
# Before #150, GH_REPO_SLUG was extracted via a sed pipeline on `git
# remote get-url origin` that assumed a literal `github.com` hostname.
# SSH host aliases (`git@github-work:owner/repo.git`) and Enterprise
# hostnames (`git@github.mycorp.com:owner/repo.git`) produced garbage
# slugs that were either silently dropped or misrouted to the wrong repo.
#
# Post-#150, the script defers to `gh repo view --json nameWithOwner`,
# which uses gh's own repo-resolution (reads ~/.ssh/config, respects
# GH_HOST, etc.). This test mocks a git remote using an SSH alias and a
# `gh repo view` response that returns the intended slug, then asserts
# the `-R` flag forwarded to downstream `gh pr view` matches.
test_gh_repo_view_resolves_alias() {
    echo "TEST: gh repo view resolves SSH alias / Enterprise URLs (#150)"
    setup

    # Point the mock repo's origin at an SSH host alias from the old
    # sed pipeline would have mangled.
    git -C "${MOCK_REPO}" remote add origin "git@github-work:real-owner/real-repo.git" 2>/dev/null \
        || git -C "${MOCK_REPO}" remote set-url origin "git@github-work:real-owner/real-repo.git"

    export MOCK_GH_LOG="${TMPDIR_BASE}/gh_calls.log"
    true > "$MOCK_GH_LOG"

    # Mock gh: `repo view` returns the intended slug (as real gh would
    # via ~/.ssh/config); `pr view` / `pr diff` record their -R args.
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
echo "$@" >> "${MOCK_GH_LOG}"
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    # Respond only when asked for nameWithOwner (what the script wants)
    if [[ " $* " == *" --json nameWithOwner "* ]]; then
        echo "real-owner/real-repo"
        exit 0
    fi
    exit 0
elif [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2; PR="$1"; shift
    if [[ "${1:-}" == "-R" ]]; then
        echo "REPO_FLAG=$2" >> "${MOCK_GH_LOG}"
        shift 2
    fi
    if [[ "$1" == "--json" && "$2" == "body" ]]; then
        echo "Closes #42"
    elif [[ "$1" == "--json" && "$2" == "title" ]]; then
        echo "Test PR"
    elif [[ "$1" == "--json" && "$2" == "url" ]]; then
        echo "https://github.com/real-owner/real-repo/pull/99"
    fi
elif [[ "$1" == "pr" && "$2" == "diff" ]]; then
    echo "diff --git a/file.txt b/file.txt"
    echo "--- a/file.txt"
    echo "+++ b/file.txt"
    echo "@@ -1 +1 @@"
    echo "-old"
    echo "+new"
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"

    cd "${MOCK_REPO}"
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --sync >/dev/null 2>&1 || true

    # Assert `gh repo view --json nameWithOwner` was called.
    if grep -q "^repo view --json nameWithOwner" "$MOCK_GH_LOG"; then
        echo "  PASS: gh repo view --json nameWithOwner was called"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: gh repo view was not invoked for slug resolution"
        echo "    gh log:"
        sed 's/^/      /' "$MOCK_GH_LOG"
        FAIL=$((FAIL + 1))
    fi

    # Assert downstream pr view received the resolved slug as -R.
    if grep -q "REPO_FLAG=real-owner/real-repo" "$MOCK_GH_LOG"; then
        echo "  PASS: resolved slug forwarded to downstream gh as -R"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: resolved slug not forwarded; would have misrouted"
        echo "    gh log:"
        sed 's/^/      /' "$MOCK_GH_LOG"
        FAIL=$((FAIL + 1))
    fi

    teardown
}

# ---- Test: gh repo view failure falls back cleanly (no -R, no abort) ----
#
# If the cwd isn't a recognized gh repo (no remote, or a non-github
# remote), `gh repo view --json nameWithOwner` exits non-zero. The
# script should treat this as "no explicit slug" and omit -R, letting
# downstream gh calls do their own resolution rather than aborting.
test_gh_repo_view_failure_falls_back() {
    echo "TEST: gh repo view failure => no -R, script continues"
    setup

    export MOCK_GH_LOG="${TMPDIR_BASE}/gh_calls.log"
    true > "$MOCK_GH_LOG"

    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
echo "$@" >> "${MOCK_GH_LOG}"
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    # Simulate "not a github repo" — exit non-zero, no output.
    exit 1
elif [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2; PR="$1"; shift
    if [[ "${1:-}" == "-R" ]]; then
        echo "REPO_FLAG=$2" >> "${MOCK_GH_LOG}"
        shift 2
    fi
    if [[ "$1" == "--json" && "$2" == "body" ]]; then
        echo "Closes #42"
    elif [[ "$1" == "--json" && "$2" == "title" ]]; then
        echo "Test PR"
    elif [[ "$1" == "--json" && "$2" == "url" ]]; then
        echo "https://github.com/fallback/repo/pull/99"
    fi
elif [[ "$1" == "pr" && "$2" == "diff" ]]; then
    echo "diff --git a/file.txt b/file.txt"
    echo "--- a/file.txt"
    echo "+++ b/file.txt"
    echo "@@ -1 +1 @@"
    echo "-old"
    echo "+new"
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"

    cd "${MOCK_REPO}"
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --sync >/dev/null 2>&1 || true

    # -R should NOT have been passed since slug resolution failed.
    if grep -q "REPO_FLAG=" "$MOCK_GH_LOG"; then
        echo "  FAIL: -R was passed despite gh repo view failing"
        echo "    gh log:"
        sed 's/^/      /' "$MOCK_GH_LOG"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: no -R when gh repo view fails"
        PASS=$((PASS + 1))
    fi

    # Script should still have proceeded to pr view (graceful fallback).
    if grep -q "^pr view" "$MOCK_GH_LOG"; then
        echo "  PASS: script proceeded to pr view after slug-resolve failure"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: script did not proceed past slug resolution"
        FAIL=$((FAIL + 1))
    fi

    teardown
}

# ---- Test: --issue flag overrides PR-body extraction (#149) ----
#
# When --issue <N> is passed, the script must honour it verbatim without
# consulting the PR body. This is the escape hatch for PRs that don't
# use Closes/Fixes/Resolves keywords (rollup PRs, long-running
# investigations, etc.).
test_issue_flag_overrides_extraction() {
    echo "TEST: --issue overrides PR-body extraction (#149)"
    setup

    export MOCK_GH_LOG="${TMPDIR_BASE}/gh_calls.log"
    true > "$MOCK_GH_LOG"

    # Mock gh: PR body has NO closure keyword — extraction would fail
    # without --issue. With --issue the body shouldn't even be queried
    # for body (but we still need view for title/url; returning body
    # anyway is harmless because the script skips extraction).
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
echo "$@" >> "${MOCK_GH_LOG}"
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2; PR="$1"; shift
    [[ "${1:-}" == "-R" ]] && shift 2
    if [[ "$1" == "--json" && "$2" == "body" ]]; then
        echo "A PR body with no closure keyword. See also #42."
    elif [[ "$1" == "--json" && "$2" == "title" ]]; then
        echo "Test PR"
    elif [[ "$1" == "--json" && "$2" == "url" ]]; then
        echo "https://github.com/test/repo/pull/99"
    fi
elif [[ "$1" == "pr" && "$2" == "diff" ]]; then
    echo "diff --git a/file.txt b/file.txt"
    echo "--- a/file.txt"
    echo "+++ b/file.txt"
    echo "@@ -1 +1 @@"
    echo "-old"
    echo "+new"
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"

    cd "${MOCK_REPO}"
    # --issue 123 matches WORKTREE_ISSUE so the resolver accepts it; the
    # wrong match (#42 from the loose fallback) would have been picked
    # before #149 and broken this test.
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=123 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --issue 123 --sync >/dev/null 2>&1 || true

    # Artifacts should land under issue-123 (from --issue), not issue-42
    # (from the PR body).
    if [[ -d "${MOCK_REPO}/.agent/work-plans/issue-123" ]]; then
        echo "  PASS: --issue value used as issue number"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: --issue value not used"
        echo "    ls work-plans: $(ls "${MOCK_REPO}/.agent/work-plans/" 2>/dev/null || echo 'empty')"
        FAIL=$((FAIL + 1))
    fi
    if [[ -d "${MOCK_REPO}/.agent/work-plans/issue-42" ]]; then
        echo "  FAIL: loose fallback still used — routed to #42"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: PR-body #42 not used"
        PASS=$((PASS + 1))
    fi

    # Also assert the script skipped the PR-body extraction entirely
    # when --issue was supplied (no `gh pr view ... --json body` call).
    # Tightens the test per review feedback on PR #154.
    if grep -qE "^pr view .* --json body" "$MOCK_GH_LOG"; then
        echo "  FAIL: gh pr view --json body was called despite --issue"
        echo "    gh log:"
        sed 's/^/      /' "$MOCK_GH_LOG"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: PR-body extraction skipped when --issue is set"
        PASS=$((PASS + 1))
    fi

    teardown
}

# ---- Test: missing closure keyword aborts with guidance (#149) ----
#
# Before #149 the script silently routed artifacts to the first '#N'
# found anywhere in the PR body, or fell back to the PR number. Both
# behaviors hid real errors. Now: no keyword + no --issue => exit 2.
test_missing_keyword_aborts() {
    echo "TEST: missing closure keyword without --issue aborts (#149)"
    setup

    # Mock gh: PR body deliberately has only a loose '#N' reference and
    # a substring like "encloses #42" that should not be picked up.
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2; PR="$1"; shift
    [[ "${1:-}" == "-R" ]] && shift 2
    if [[ "$1" == "--json" && "$2" == "body" ]]; then
        echo "Related to #42 (encloses #7). No closure keyword here."
    elif [[ "$1" == "--json" && "$2" == "title" ]]; then
        echo "Test PR"
    elif [[ "$1" == "--json" && "$2" == "url" ]]; then
        echo "https://github.com/test/repo/pull/99"
    fi
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"

    cd "${MOCK_REPO}"
    local exit_code=0
    local stderr
    stderr=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --sync 2>&1) || exit_code=$?

    assert_exit_code "missing keyword exits 2" "2" "$exit_code"
    # Pattern avoids `|` (which grep -E would treat as alternation and
    # accept a partial match). Testing an unambiguous fragment of the
    # error message instead — per review feedback on PR #154.
    assert_contains "error mentions missing keyword" \
        "body has no 'Closes" "$stderr"
    # Pattern must not start with "--" so grep -E doesn't treat it as a flag.
    assert_contains "error suggests --issue flag" "Pass --issue" "$stderr"

    # No artifacts should have been written (abort before resolver).
    if [[ -d "${MOCK_REPO}/.agent/work-plans/issue-42" ]] || \
       [[ -d "${MOCK_REPO}/.agent/work-plans/issue-7" ]]; then
        echo "  FAIL: artifacts leaked from the loose fallback"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: no artifacts written when extraction fails"
        PASS=$((PASS + 1))
    fi

    teardown
}

# ---- Test: --issue validates positive integer shape (#149) ----
test_issue_flag_validates_integer() {
    echo "TEST: --issue rejects non-integer values (#149)"

    local exit_code=0
    local stderr
    stderr=$(bash "${SCRIPT_UNDER_TEST}" --pr 99 --issue not-a-number 2>&1) || exit_code=$?
    assert_exit_code "non-integer --issue exits 2" "2" "$exit_code"
    assert_contains "error mentions integer contract" \
        "not a positive integer" "$stderr"

    exit_code=0
    stderr=$(bash "${SCRIPT_UNDER_TEST}" --pr 99 --issue 0 2>&1) || exit_code=$?
    assert_exit_code "--issue 0 rejected" "2" "$exit_code"

    exit_code=0
    stderr=$(bash "${SCRIPT_UNDER_TEST}" --pr 99 --issue -5 2>&1) || exit_code=$?
    assert_exit_code "--issue -5 rejected" "2" "$exit_code"
    # Post-review: require_value was narrowed from -* to --*, so -5
    # now reaches the integer validator instead of being caught as a
    # "missing value" flag. Both paths exit 2; the integer message is
    # more accurate.
    assert_contains "error mentions integer contract for -5" \
        "not a positive integer" "$stderr"
}

# ---- Test: gh pr view failure produces a retrieval-specific error (#149) ----
#
# Regression test for the review fix: when gh fails (auth/permissions/
# network), the script must NOT emit the "no closure keyword" guidance,
# which would point users at the wrong remediation.
test_gh_pr_view_failure_distinct_error() {
    echo "TEST: gh pr view failure produces a distinct error (#149)"
    setup

    # Mock gh that fails on `pr view --json body` (exit non-zero).
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2; PR="$1"; shift
    [[ "${1:-}" == "-R" ]] && shift 2
    if [[ "$1" == "--json" && "$2" == "body" ]]; then
        # Simulate auth/network/permission failure
        echo "gh: authentication required" >&2
        exit 1
    fi
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"

    cd "${MOCK_REPO}"
    local exit_code=0
    local stderr
    stderr=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --sync 2>&1) || exit_code=$?

    assert_exit_code "gh failure exits 2" "2" "$exit_code"
    assert_contains "error mentions retrieval failure" \
        "Failed to retrieve body" "$stderr"
    # Must NOT fall through to the no-keyword remediation — that would
    # be misleading when the real problem is auth/network.
    assert_not_contains "no-keyword guidance suppressed on gh failure" \
        "body has no 'Closes" "$stderr"

    teardown
}

# ---- Gemini/agy tests (#223, #274, #288, #312) ----
#
# The Gemini CLI migrated to the `agy` binary (#223). cross_model_review.sh
# drives it through _agy_review.sh, which feeds the prompt over stdin as a
# stream-json message (#274: no argv size limit) and validates the result
# event (#288: a headless permission denial exits 0 with an empty response).
# The mock agy in setup() implements that contract; see its knobs there.

# Run the script in sync mode for PR 99 (issue 42) and echo the exit code.
run_gemini_sync() {
    cd "${MOCK_REPO}"
    local exit_code=0
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --sync < /dev/null >/dev/null 2>&1 || exit_code=$?
    echo "$exit_code"
}

FINDINGS_REL=".agent/work-plans/issue-42/review-gemini-findings.md"
PROMPT_REL=".agent/work-plans/issue-42/review-gemini-prompt.md"

test_agy_stdin_invocation() {
    echo "TEST: gemini agent feeds agy the prompt over stdin, argv carries only flags (#274)"
    setup

    export MOCK_AGY_LOG="${TMPDIR_BASE}/agy_calls.log"
    true > "$MOCK_AGY_LOG"
    local exit_code
    exit_code=$(run_gemini_sync)
    unset MOCK_AGY_LOG

    assert_exit_code "review completes (exit 0)" "0" "$exit_code"

    local agy_log
    agy_log=$(cat "${TMPDIR_BASE}/agy_calls.log")
    assert_contains "agy received --input-format=stream-json" "^--input-format=stream-json$" "$agy_log"
    assert_contains "agy received --output-format=stream-json" "^--output-format=stream-json$" "$agy_log"
    assert_contains "agy received --print-timeout" "^--print-timeout$" "$agy_log"
    assert_contains "agy received --disable-slash-commands" "^--disable-slash-commands$" "$agy_log"
    assert_contains "agy received an empty -p=" "^-p=$" "$agy_log"
    assert_not_contains "prompt content is NOT on argv" "Adversarial Code Review" "$agy_log"

    local content
    content=$(cat "${MOCK_REPO}/${FINDINGS_REL}")
    assert_contains "findings file holds agy's response (prompt echoed via stdin)" \
        "Adversarial Code Review" "$content"
    assert_contains "findings file has completion marker" "Review complete" "$content"
    assert_not_contains "no denial note on a clean run" "denied in headless mode" "$content"

    teardown
}

test_agy_large_prompt() {
    echo "TEST: a >200 KiB prompt reaches agy (argv limit no longer applies, #274)"
    setup

    # ~256 KiB of diff: well past MAX_ARG_STRLEN (128 KiB on Linux). An
    # argv regression fails here with E2BIG on a real kernel.
    local big="${TMPDIR_BASE}/big.diff"
    {
        echo "diff --git a/big.txt b/big.txt"
        echo "--- a/big.txt"
        echo "+++ b/big.txt"
        echo "@@ -0,0 +1,4096 @@"
        local i
        for ((i = 0; i < 4096; i++)); do
            printf '+%063d\n' "$i"
        done
    } > "$big"

    export MOCK_GH_DIFF_FILE="$big"
    local exit_code
    exit_code=$(run_gemini_sync)
    unset MOCK_GH_DIFF_FILE

    assert_exit_code "large prompt review completes (exit 0)" "0" "$exit_code"
    local size
    size=$(wc -c < "${MOCK_REPO}/${PROMPT_REL}")
    if [[ "$size" -gt 200000 ]]; then
        echo "  PASS: prompt file is >200 KiB (${size} bytes)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: prompt file only ${size} bytes — test did not exercise the limit"
        FAIL=$((FAIL + 1))
    fi
    assert_contains "findings file has completion marker" "Review complete" \
        "$(tail -n 1 "${MOCK_REPO}/${FINDINGS_REL}")"

    teardown
}

test_agy_denial_is_failure() {
    echo "TEST: headless permission denial is reported as a failed review (#288)"
    setup

    export MOCK_AGY_DENY=1
    local exit_code
    exit_code=$(run_gemini_sync)
    unset MOCK_AGY_DENY

    assert_exit_code "denied review exits 3" "3" "$exit_code"
    local content
    content=$(cat "${MOCK_REPO}/${FINDINGS_REL}")
    assert_contains "findings file has failed marker" "Review failed" "$content"
    assert_not_contains "findings file has NO complete marker" "Review complete" "$content"
    assert_contains "findings file names the denied action" "RunCommand" "$content"
    assert_contains "findings file explains the denial" "auto-denied in headless mode" "$content"

    teardown
}

test_agy_timeout_is_failure() {
    echo "TEST: print-timeout expiry is a failed review, not a partial success (#288)"
    setup

    export MOCK_AGY_TIMEOUT=1
    local exit_code
    exit_code=$(run_gemini_sync)
    unset MOCK_AGY_TIMEOUT

    assert_exit_code "timed-out review exits 3" "3" "$exit_code"
    local content
    content=$(cat "${MOCK_REPO}/${FINDINGS_REL}")
    assert_contains "findings file has failed marker" "Review failed" "$content"
    assert_contains "findings file names the timeout" "print timeout" "$content"
    assert_not_contains "partial response is discarded" "partial text" "$content"

    teardown
}

test_agy_findings_truncated() {
    echo "TEST: a failed run never leaves the previous run's findings in place (#288)"
    setup

    mkdir -p "${MOCK_REPO}/.agent/work-plans/issue-42"
    echo "STALE FINDINGS FROM LAST RUN" > "${MOCK_REPO}/${FINDINGS_REL}"

    export MOCK_AGY_EXIT=7
    local exit_code
    exit_code=$(run_gemini_sync)
    unset MOCK_AGY_EXIT

    assert_exit_code "crashed agy exits 3" "3" "$exit_code"
    local content
    content=$(cat "${MOCK_REPO}/${FINDINGS_REL}")
    assert_not_contains "stale findings are gone" "STALE FINDINGS" "$content"
    assert_contains "reason names the exit status" "agy exited 7" "$content"
    assert_contains "reason carries agy stderr" "boom" "$content"
    assert_contains "findings file has failed marker" "Review failed" "$content"

    teardown
}

test_agy_no_temp_leak() {
    echo "TEST: the helper leaves no temp files behind on success or failure"
    setup

    # Point TMPDIR at a private dir so only the helper's mktemp lands there;
    # the mock repo and findings live under TMPDIR_BASE, outside it.
    local leak_dir="${TMPDIR_BASE}/leakcheck"
    mkdir -p "$leak_dir"

    cd "${MOCK_REPO}"
    TMPDIR="$leak_dir" PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 \
        bash "${SCRIPT_UNDER_TEST}" --pr 99 --sync < /dev/null >/dev/null 2>&1 || true
    MOCK_AGY_DENY=1 TMPDIR="$leak_dir" PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 \
        bash "${SCRIPT_UNDER_TEST}" --pr 99 --sync < /dev/null >/dev/null 2>&1 || true
    MOCK_AGY_EXIT=3 TMPDIR="$leak_dir" PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 \
        bash "${SCRIPT_UNDER_TEST}" --pr 99 --sync < /dev/null >/dev/null 2>&1 || true

    local leftovers
    leftovers=$(ls -A "$leak_dir")
    assert_eq "no temp files left after success + denial + crash" "" "$leftovers"

    teardown
}

test_agy_tmux_invocation() {
    echo "TEST: tmux mode invokes the helper with quoted args and no findings redirect"
    setup

    # Mock tmux: records the new-session command string (its final arg),
    # reports the session as present afterwards, never runs anything.
    cat > "${MOCK_BIN}/tmux" << 'TMUX_EOF'
#!/usr/bin/env bash
if [[ "$1" == "new-session" ]]; then
    printf '%s\n' "${@: -1}" > "${MOCK_TMUX_LOG}"
    exit 0
fi
if [[ "$1" == "has-session" ]]; then
    [[ -f "${MOCK_TMUX_LOG}" ]] && exit 0 || exit 1
fi
exit 0
TMUX_EOF
    chmod +x "${MOCK_BIN}/tmux"

    export MOCK_TMUX_LOG="${TMPDIR_BASE}/tmux_cmd.log"
    cd "${MOCK_REPO}"
    local exit_code=0 stdout
    stdout=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 < /dev/null 2>/dev/null) || exit_code=$?
    unset MOCK_TMUX_LOG

    assert_exit_code "tmux launch exits 0" "0" "$exit_code"
    assert_contains "script reports tmux mode" "^MODE=tmux$" "$stdout"

    local cmd
    cmd=$(cat "${TMPDIR_BASE}/tmux_cmd.log")
    assert_contains "command invokes _agy_review.sh" "/_agy_review.sh " "$cmd"
    assert_contains "helper receives the findings path" "review-gemini-findings.md" "$cmd"
    assert_contains "helper receives the print timeout" " 30m " "$cmd"
    # The helper invocation is everything before the first " && " (the
    # marker clauses that follow legitimately append to the findings file).
    local helper_part="${cmd%% && *}"
    assert_not_contains "no redirect in the helper invocation" ">" "$helper_part"
    assert_contains "complete marker clause present" "Review complete" "$cmd"
    assert_contains "failed marker clause present" "Review failed" "$cmd"

    # Round-trip: the recorded string, run by a shell, must produce the
    # same findings as sync mode (the quoting is real, not cosmetic).
    (cd "${MOCK_REPO}" && PATH="${MOCK_BIN}:${PATH}" bash -c "$cmd") >/dev/null 2>&1 || true
    local content
    content=$(cat "${MOCK_REPO}/${FINDINGS_REL}")
    assert_contains "executed tmux command produced findings" "Adversarial Code Review" "$content"
    assert_contains "executed tmux command appended the complete marker" "Review complete" "$content"

    teardown
}

test_prompt_tool_use_guidance() {
    echo "TEST: tool-use paragraph is present for gemini and absent for codex (#288)"
    setup

    run_gemini_sync >/dev/null
    local gemini_prompt
    gemini_prompt=$(cat "${MOCK_REPO}/${PROMPT_REL}")
    assert_contains "gemini prompt tells the model not to run commands" \
        "Do NOT run shell commands" "$gemini_prompt"

    # codex: a mock that consumes stdin and prints something.
    cat > "${MOCK_BIN}/codex" << 'CODEX_EOF'
#!/usr/bin/env bash
cat > /dev/null
echo "codex ran"
CODEX_EOF
    chmod +x "${MOCK_BIN}/codex"
    cd "${MOCK_REPO}"
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --sync --agent codex < /dev/null >/dev/null 2>&1 || true
    local codex_prompt
    codex_prompt=$(cat "${MOCK_REPO}/.agent/work-plans/issue-42/review-codex-prompt.md")
    assert_not_contains "codex prompt has no tool-use paragraph" \
        "Do NOT run shell commands" "$codex_prompt"

    teardown
}

test_work_plans_excluded_from_diff() {
    echo "TEST: .agent/work-plans/** sections are stripped from the embedded diff (#312)"
    setup

    local mixed="${TMPDIR_BASE}/mixed.diff"
    cat > "$mixed" << 'DIFF_EOF'
diff --git a/src/code.py b/src/code.py
--- a/src/code.py
+++ b/src/code.py
@@ -1 +1 @@
-old code
+new code
diff --git a/.agent/work-plans/issue-42/plan.md b/.agent/work-plans/issue-42/plan.md
new file mode 100644
--- /dev/null
+++ b/.agent/work-plans/issue-42/plan.md
@@ -0,0 +1 @@
+PLAN BOOKKEEPING
diff --git a/.agent/work-plans/issue-42/progress.md b/.agent/work-plans/issue-42/progress.md
--- a/.agent/work-plans/issue-42/progress.md
+++ b/.agent/work-plans/issue-42/progress.md
@@ -1 +1 @@
-PROGRESS OLD
+PROGRESS NEW
diff --git a/src/after.py b/src/after.py
--- a/src/after.py
+++ b/src/after.py
@@ -1 +1 @@
-x
+y
diff --git a/.agent/work-plans/issue-42/tool.sh b/src/tool.sh
similarity index 90%
rename from .agent/work-plans/issue-42/tool.sh
rename to src/tool.sh
--- a/.agent/work-plans/issue-42/tool.sh
+++ b/src/tool.sh
@@ -1 +1 @@
-RENAMED OUT old
+RENAMED OUT new
diff --git "a/.agent/work-plans/issue-42/odd name.md" "b/.agent/work-plans/issue-42/odd name.md"
--- "a/.agent/work-plans/issue-42/odd name.md"
+++ "b/.agent/work-plans/issue-42/odd name.md"
@@ -1 +1 @@
-q
+QUOTED BOOKKEEPING
DIFF_EOF

    export MOCK_GH_DIFF_FILE="$mixed"
    local exit_code
    exit_code=$(run_gemini_sync)
    unset MOCK_GH_DIFF_FILE

    assert_exit_code "mixed diff review completes" "0" "$exit_code"
    local prompt
    prompt=$(cat "${MOCK_REPO}/${PROMPT_REL}")
    assert_contains "code file before the bookkeeping is kept" "\+new code" "$prompt"
    assert_contains "code file after the bookkeeping is kept" "diff --git a/src/after.py" "$prompt"
    assert_not_contains "plan.md section is dropped" "PLAN BOOKKEEPING" "$prompt"
    assert_not_contains "progress.md section is dropped" "PROGRESS NEW" "$prompt"
    assert_contains "file renamed OUT of work-plans stays in review (b/ path decides)" \
        "RENAMED OUT new" "$prompt"
    assert_not_contains "quoted work-plans path is dropped" "QUOTED BOOKKEEPING" "$prompt"
    assert_not_contains "no work-plans post-image header survives" \
        " \"?b/.agent/work-plans" "$prompt"

    # All-bookkeeping diff: nothing to review.
    local only="${TMPDIR_BASE}/only.diff"
    cat > "$only" << 'DIFF_EOF'
diff --git a/.agent/work-plans/issue-42/plan.md b/.agent/work-plans/issue-42/plan.md
--- a/.agent/work-plans/issue-42/plan.md
+++ b/.agent/work-plans/issue-42/plan.md
@@ -1 +1 @@
-a
+b
DIFF_EOF
    export MOCK_GH_DIFF_FILE="$only"
    cd "${MOCK_REPO}"
    local stderr exit2=0
    stderr=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --sync < /dev/null 2>&1 >/dev/null) || exit2=$?
    unset MOCK_GH_DIFF_FILE
    assert_exit_code "all-bookkeeping diff exits 3" "3" "$exit2"
    assert_contains "error names the work-plans exclusion" "work-plans" "$stderr"

    teardown
}

test_branch_mode_filter_survives_noprefix() {
    echo "TEST: branch mode filters work-plans even with diff.noprefix=true (#312)"
    setup

    # Feature branch off the mock repo's default branch with one code
    # file and one work-plans file; diff.noprefix set to defeat a naive
    # a/ b/ match.
    local base
    base=$(git -C "${MOCK_REPO}" branch --show-current)
    git -C "${MOCK_REPO}" checkout -q -b feature/issue-42
    mkdir -p "${MOCK_REPO}/src" "${MOCK_REPO}/.agent/work-plans/issue-42"
    echo "BRANCH CODE" > "${MOCK_REPO}/src/code.py"
    echo "BRANCH BOOKKEEPING" > "${MOCK_REPO}/.agent/work-plans/issue-42/plan.md"
    git -C "${MOCK_REPO}" add -A
    git -C "${MOCK_REPO}" -c user.name="Test" -c user.email="test@test" commit -q -m "feature"
    git -C "${MOCK_REPO}" config diff.noprefix true

    cd "${MOCK_REPO}"
    local exit_code=0
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --branch "$base" --sync < /dev/null >/dev/null 2>&1 || exit_code=$?

    assert_exit_code "branch review completes" "0" "$exit_code"
    local prompt
    prompt=$(cat "${MOCK_REPO}/${PROMPT_REL}")
    assert_contains "code file kept" "BRANCH CODE" "$prompt"
    assert_not_contains "work-plans file dropped despite diff.noprefix" "BRANCH BOOKKEEPING" "$prompt"

    teardown
}

# ---- Run all tests ----
echo "=== cross_model_review.sh tests ==="
echo ""

test_missing_pr_flag
test_unknown_argument
test_invalid_repo_slug
test_issue_extraction
test_repo_flag_accepted
test_work_dir_flag
test_empty_diff_guard
test_resolver_refuses_without_worktree_issue
test_flag_as_value_rejected
test_gh_repo_view_resolves_alias
test_gh_repo_view_failure_falls_back
test_issue_flag_overrides_extraction
test_missing_keyword_aborts
test_issue_flag_validates_integer
test_gh_pr_view_failure_distinct_error
test_agy_stdin_invocation
test_agy_large_prompt
test_agy_denial_is_failure
test_agy_timeout_is_failure
test_agy_findings_truncated
test_agy_no_temp_leak
test_agy_tmux_invocation
test_prompt_tool_use_guidance
test_work_plans_excluded_from_diff
test_branch_mode_filter_survives_noprefix

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
