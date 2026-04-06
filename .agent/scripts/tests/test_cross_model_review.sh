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

setup() {
    TMPDIR_BASE=$(mktemp -d /tmp/test_cmr.XXXXXX)

    # Create a mock git repo so git rev-parse works
    MOCK_REPO="${TMPDIR_BASE}/repo"
    mkdir -p "${MOCK_REPO}"
    git -C "${MOCK_REPO}" init -q
    git -C "${MOCK_REPO}" -c user.name="Test" -c user.email="test@test" commit --allow-empty -m "init" -q

    # Create mock bin directory
    MOCK_BIN="${TMPDIR_BASE}/bin"
    mkdir -p "${MOCK_BIN}"

    # Mock gemini CLI that just writes "mock review" to the findings file
    cat > "${MOCK_BIN}/gemini" << 'MOCK_EOF'
#!/usr/bin/env bash
# Mock gemini: copy stdin to stdout (findings file via redirect)
cat
MOCK_EOF
    chmod +x "${MOCK_BIN}/gemini"
}

teardown() {
    [[ -n "$TMPDIR_BASE" ]] && rm -rf "$TMPDIR_BASE"
}
trap teardown EXIT

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

    # Run the script with --repo and --sync (to avoid tmux)
    cd "${MOCK_REPO}"
    PATH="${MOCK_BIN}:${PATH}" bash "${SCRIPT_UNDER_TEST}" \
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
# Helper: mirrors the extraction logic from cross_model_review.sh
extract_issue() {
    local body="$1"
    local ref num
    ref=$(printf '%s\n' "$body" | grep -ioE '(^|[^[:alnum:]_])(closes|fixes|resolves)[[:space:]]+([a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+)?#[0-9]+' | head -n1 || true)
    num=$(printf '%s\n' "$ref" | grep -oE '[0-9]+$' || true)
    if [[ -z "$num" ]]; then
        num=$(printf '%s\n' "$body" | grep -oE '(^|[[:space:]])#[0-9]+' | head -n1 | grep -oE '[0-9]+' || true)
    fi
    printf '%s' "${num:-}"
}

test_issue_extraction() {
    echo "TEST: issue number extraction"

    # Positive cases
    assert_eq "Closes #42 -> 42" "42" "$(extract_issue 'Some text\nCloses #42\nMore text')"
    assert_eq "fixes #123 -> 123" "123" "$(extract_issue 'fixes #123')"
    assert_eq "Resolves owner/repo#77 -> 77" "77" "$(extract_issue 'Resolves owner/repo#77')"
    assert_eq "CLOSES #5 -> 5" "5" "$(extract_issue 'CLOSES #5')"

    # Negative: substring false positives should NOT match as close keywords
    assert_eq "encloses #42 -> fallback 42" "42" "$(extract_issue 'encloses #42')"
    assert_eq "prefixes #7 -> fallback 7" "7" "$(extract_issue 'prefixes #7')"
    # But with a real close keyword elsewhere, it should pick the right one
    assert_eq "encloses #42, Closes #99 -> 99" "99" "$(extract_issue 'encloses #42 but Closes #99')"

    # Fallback cases
    assert_eq "Fallback #10 -> 10" "10" "$(extract_issue 'Related to #10 and #20')"
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

    cd "${MOCK_REPO}"
    local exit_code=0
    STDERR=$(PATH="${MOCK_BIN}:${PATH}" bash "${SCRIPT_UNDER_TEST}" \
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

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
