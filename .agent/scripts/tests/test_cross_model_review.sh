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
    #   MOCK_AGY_ERROR=<m>  status ERROR with an object-valued `error`
    #                       whose message is <m>, exit 0 (API failure)
    #   MOCK_AGY_DENY_PARTIAL=1  normal response PLUS one denied action
    #   MOCK_AGY_SLEEP=<s>  sleep <s> before answering normally
    #   MOCK_AGY_STALL=1    read the prompt, then never answer (sleep 60):
    #                       agy wedged past its own --print-timeout, which
    #                       only the caller's outer backstop can cut off
    #   MOCK_TIMES_DIR=<d>  write agy.pid at start, agy.end on completion
    # Every run also prints a non-JSON banner line on stdout first, as a
    # real CLI may (update notice), so the parser must skip it.
    cat > "${MOCK_BIN}/agy" << 'MOCK_EOF'
#!/usr/bin/env bash
if [[ -n "${MOCK_AGY_LOG:-}" ]]; then
    printf '%s\n' "$@" >> "${MOCK_AGY_LOG}"
fi
[[ -n "${MOCK_TIMES_DIR:-}" ]] && echo $$ > "${MOCK_TIMES_DIR}/agy.pid"
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
if [[ -n "${MOCK_AGY_STALL:-}" ]]; then
    # Wedged: the prompt was consumed, but no result event and no
    # --print-timeout handling ever happens. Only an outer bound ends it.
    # `exec` so the recorded pid IS the sleep: killing it leaves no
    # orphaned child behind.
    exec sleep 60
fi
[[ -n "${MOCK_AGY_SLEEP:-}" ]] && sleep "${MOCK_AGY_SLEEP}"
echo 'agy: a newer version is available (mock banner, not JSON)'
echo '{"event":"init","init":{"tools":[]}}'
if [[ -n "${MOCK_AGY_DENY:-}" ]]; then
    echo 'jetski: no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied.' >&2
    echo '{"event":"result","result":{"status":"SUCCESS","response":"","denied_actions":[{"action":"command","display_name":"RunCommand"}]}}'
    exit 0
fi
if [[ -n "${MOCK_AGY_ERROR:-}" ]]; then
    jq -cn --arg m "$MOCK_AGY_ERROR" '{event:"result",result:{status:"ERROR",response:"",error:{code:429,message:$m}}}'
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
if [[ -n "${MOCK_AGY_DENY_PARTIAL:-}" ]]; then
    printf '%s\n' "$input" | jq -r 'select(.event == "user") | .message.content' \
        | jq -c -Rs '{event:"result",result:{status:"SUCCESS",response:.,denied_actions:[{"action":"command","display_name":"RunCommand"}]}}'
    exit 0
fi
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

    # Run the script with --repo. Set
    # WORKTREE_ISSUE=42 (matching the mock PR body's "Closes #42") so the
    # work-plans-dir resolver (issue #147) accepts the invocation instead
    # of aborting with "not in matching worktree."
    cd "${MOCK_REPO}"
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --repo test/repo  >/dev/null 2>&1 || true

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
        --pr 99 --work-dir "${custom_dir}"  >/dev/null 2>&1 || true

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
        --pr 99  2>&1) || exit_code=$?

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
        bash "${SCRIPT_UNDER_TEST}" --pr 99  2>&1) || exit_code=$?
    assert_exit_code "unset WORKTREE_ISSUE exits 4" "4" "$exit_code"
    assert_contains "error mentions worktree" "worktree" "$STDERR"

    # Case 2: WORKTREE_ISSUE mismatched -> same abort, different message.
    exit_code=0
    STDERR=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=100 \
        bash "${SCRIPT_UNDER_TEST}" --pr 99  2>&1) || exit_code=$?
    assert_exit_code "mismatched WORKTREE_ISSUE exits 4" "4" "$exit_code"
    assert_contains "error names the mismatch" "'100', not '42'" "$STDERR"

    teardown
}

# ---- Test: flag-as-value is rejected ----
test_flag_as_value_rejected() {
    echo "TEST: --flag --other-flag pattern is rejected"

    local exit_code=0
    STDERR=$(bash "${SCRIPT_UNDER_TEST}" --work-plans-dir --no-progress 2>&1) || exit_code=$?
    assert_exit_code "--work-plans-dir --no-progress exits 2" "2" "$exit_code"
    assert_contains "error mentions missing value" "Missing value for --work-plans-dir" "$STDERR"

    exit_code=0
    STDERR=$(bash "${SCRIPT_UNDER_TEST}" --pr --no-progress 2>&1) || exit_code=$?
    assert_exit_code "--pr --no-progress exits 2" "2" "$exit_code"
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
        --pr 99  >/dev/null 2>&1 || true

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
        --pr 99  >/dev/null 2>&1 || true

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
        --pr 99 --issue 123  >/dev/null 2>&1 || true

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
        --pr 99  2>&1) || exit_code=$?

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
        --pr 99  2>&1) || exit_code=$?

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

# Run the script (single-agent gemini) for PR 99 (issue 42) and echo the exit code.
run_gemini_sync() {
    cd "${MOCK_REPO}"
    local exit_code=0
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99  < /dev/null >/dev/null 2>&1 || exit_code=$?
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

test_agy_partial_denial_is_noted() {
    echo "TEST: a response with a denied action completes but carries a note"
    setup

    export MOCK_AGY_DENY_PARTIAL=1
    local exit_code
    exit_code=$(run_gemini_sync)
    unset MOCK_AGY_DENY_PARTIAL

    assert_exit_code "partial-denial review completes (exit 0)" "0" "$exit_code"
    local content
    content=$(cat "${MOCK_REPO}/${FINDINGS_REL}")
    assert_contains "response is kept" "Adversarial Code Review" "$content"
    assert_contains "denial note appended" "1 tool action\(s\) were denied in headless mode \(RunCommand\)" "$content"
    assert_contains "findings file has completion marker" "Review complete" "$content"

    teardown
}

test_diff_fetch_failure_is_marked() {
    echo "TEST: a failing diff fetch writes the error marker and exits 3 (not a bare set -e abort)"
    setup

    # gh: PR metadata fine, `gh pr diff` fails after emitting one line.
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 2; shift
    [[ "${1:-}" == "-R" ]] && shift 2
    case "$2" in
        body) echo "Closes #42" ;;
        title) echo "Test PR" ;;
        url) echo "https://github.com/test/repo/pull/99" ;;
    esac
    exit 0
elif [[ "$1" == "pr" && "$2" == "diff" ]]; then
    echo "diff --git a/file.txt b/file.txt"
    echo "gh: connection reset" >&2
    exit 1
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"

    cd "${MOCK_REPO}"
    local exit_code=0 stderr
    stderr=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99  < /dev/null 2>&1 >/dev/null) || exit_code=$?

    assert_exit_code "failed diff fetch exits 3" "3" "$exit_code"
    assert_contains "error message names the diff retrieval" "Could not retrieve diff" "$stderr"
    local content
    content=$(cat "${MOCK_REPO}/${FINDINGS_REL}" 2>/dev/null || echo "MISSING")
    assert_contains "findings file carries the error marker" "Review error: failed to retrieve diff" "$content"

    teardown
}

test_agy_api_error_message_kept() {
    echo "TEST: a non-SUCCESS result keeps agy's error message, even as an object (#288)"
    setup

    export MOCK_AGY_ERROR="quota exceeded for model"
    local exit_code
    exit_code=$(run_gemini_sync)
    unset MOCK_AGY_ERROR

    assert_exit_code "API error exits 3" "3" "$exit_code"
    local content
    content=$(cat "${MOCK_REPO}/${FINDINGS_REL}")
    assert_contains "reason names the status" "result status ERROR" "$content"
    assert_contains "reason carries the error message" "quota exceeded for model" "$content"
    assert_contains "findings file has failed marker" "Review failed" "$content"

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
        bash "${SCRIPT_UNDER_TEST}" --pr 99  < /dev/null >/dev/null 2>&1 || true
    MOCK_AGY_DENY=1 TMPDIR="$leak_dir" PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 \
        bash "${SCRIPT_UNDER_TEST}" --pr 99  < /dev/null >/dev/null 2>&1 || true
    MOCK_AGY_EXIT=3 TMPDIR="$leak_dir" PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 \
        bash "${SCRIPT_UNDER_TEST}" --pr 99  < /dev/null >/dev/null 2>&1 || true

    local leftovers
    leftovers=$(ls -A "$leak_dir")
    assert_eq "no temp files left after success + denial + crash" "" "$leftovers"

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
        --pr 99  --agent codex < /dev/null >/dev/null 2>&1 || true
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
        --pr 99  < /dev/null 2>&1 >/dev/null) || exit2=$?
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
        --branch "$base"  < /dev/null >/dev/null 2>&1 || exit_code=$?

    assert_exit_code "branch review completes" "0" "$exit_code"
    local prompt
    prompt=$(cat "${MOCK_REPO}/${PROMPT_REL}")
    assert_contains "code file kept" "BRANCH CODE" "$prompt"
    assert_not_contains "work-plans file dropped despite diff.noprefix" "BRANCH BOOKKEEPING" "$prompt"

    teardown
}

# ---- Parallel dispatch tests (#206, ADR-0015) ----
#
# tmux is gone: every agent runs in its own background job, all in
# parallel, bounded by AGENT_TIMEOUT (non-gemini).
#
# Since #313 the codex/claude/copilot arms no longer exec their CLI
# directly: they exec _cli_review.sh, which owns the findings file and
# validates the result. The mocks below therefore reproduce each CLI's
# real output shape rather than "write the review to stdout" — a generic
# mock would pass a gate that the real CLIs would not:
#   * codex writes its transcript (banner, echoed prompt, chatter) to
#     stdout and only the final message to the `-o` file;
#   * claude prints one JSON result object;
#   * copilot reads the prompt from stdin (`-p ""` + `-s`) and prints
#     only the response.
#
# Shared knobs (env, per agent, NAME upper-cased):
#   MOCK_<NAME>_SLEEP=<s>    sleep before answering
#   MOCK_<NAME>_EXIT=<n>     exit status (default 0)
#   MOCK_<NAME>_EMPTY=1      produce an empty result at exit 0 (the #288
#                            class: denial / aborted turn)
#   MOCK_<NAME>_ERRMARK=<m>  return <m> as the result at exit 0 (a quota /
#                            rate-limit / auth error printed as output)
#   MOCK_<NAME>_STDERR=<m>   also write <m> to stderr (codex: to the
#                            merged transcript)
#   MOCK_CLAUDE_RAW=<s>      claude prints <s> verbatim instead of JSON
#   MOCK_CLAUDE_SUBTYPE=<s>  claude result subtype (default success)
#   MOCK_CLAUDE_IS_ERROR=<b> claude is_error (default false)
#   MOCK_TIMES_DIR=<dir>     where <name>.start / .end / .pid are written
#   MOCK_ARGV_DIR=<dir>      where <name>.argv is written (one arg per
#                            line) so each CLI's invocation contract can
#                            be asserted — including that the prompt is
#                            never on argv (#212, #274)
#   MOCK_STDIN_DIR=<dir>     where <name>.stdin (everything the CLI read
#                            from stdin) is written

# Preamble shared by every mock: record argv, times, pid and stdin.
MOCK_PREAMBLE='
name=$(basename "$0")
[[ -n "${MOCK_ARGV_DIR:-}" ]] && printf "%s\n" "$@" > "${MOCK_ARGV_DIR}/${name}.argv"
[[ -n "${MOCK_TIMES_DIR:-}" ]] && date +%s.%N > "${MOCK_TIMES_DIR}/${name}.start"
[[ -n "${MOCK_TIMES_DIR:-}" ]] && echo $$ > "${MOCK_TIMES_DIR}/${name}.pid"
prompt=$(cat)
[[ -n "${MOCK_STDIN_DIR:-}" ]] && printf "%s" "$prompt" > "${MOCK_STDIN_DIR}/${name}.stdin"
'

make_mock_agent() {
    local name="$1"
    case "$name" in
        codex)
            {
                echo '#!/usr/bin/env bash'
                echo "$MOCK_PREAMBLE"
                cat << 'CODEX_EOF'
# codex exec [-o FILE]: the final message goes to FILE, everything else
# (banner, echoed prompt, tool chatter) to the transcript on stdout.
out=""
args=("$@"); i=0
while [[ $i -lt ${#args[@]} ]]; do
    [[ "${args[$i]}" == "-o" || "${args[$i]}" == "--output-last-message" ]] && out="${args[$((i + 1))]}"
    i=$((i + 1))
done
[[ -n "${MOCK_CODEX_SLEEP:-}" ]] && sleep "${MOCK_CODEX_SLEEP}"
echo "codex-cli 0.155.1 (mock banner)"
echo "MOCK TRANSCRIPT: prompt was ${#prompt} bytes"
printf '%s\n' "$prompt" | head -n 2
[[ -n "${MOCK_CODEX_STDERR:-}" ]] && echo "${MOCK_CODEX_STDERR}" >&2
if [[ -z "$out" ]]; then
    echo "mock codex: no -o file given; the helper must ask for the final message" >&2
    exit 9
fi
if [[ -n "${MOCK_CODEX_EMPTY:-}" ]]; then
    : > "$out"
elif [[ -n "${MOCK_CODEX_ERRMARK:-}" ]]; then
    printf '%s\n' "${MOCK_CODEX_ERRMARK}" > "$out"
else
    printf '### Findings\nreviewed by codex\n' > "$out"
fi
[[ -n "${MOCK_TIMES_DIR:-}" ]] && date +%s.%N > "${MOCK_TIMES_DIR}/codex.end"
exit "${MOCK_CODEX_EXIT:-0}"
CODEX_EOF
            } > "${MOCK_BIN}/codex"
            ;;
        claude)
            {
                echo '#!/usr/bin/env bash'
                echo "$MOCK_PREAMBLE"
                cat << 'CLAUDE_EOF'
# claude -p --output-format json: exactly one result object on stdout.
[[ -n "${MOCK_CLAUDE_SLEEP:-}" ]] && sleep "${MOCK_CLAUDE_SLEEP}"
[[ -n "${MOCK_CLAUDE_STDERR:-}" ]] && echo "${MOCK_CLAUDE_STDERR}" >&2
if [[ -n "${MOCK_CLAUDE_RAW:-}" ]]; then
    printf '%s\n' "${MOCK_CLAUDE_RAW}"
else
    result=$'### Findings\nreviewed by claude'
    [[ -n "${MOCK_CLAUDE_EMPTY:-}" ]] && result=""
    [[ -n "${MOCK_CLAUDE_ERRMARK:-}" ]] && result="${MOCK_CLAUDE_ERRMARK}"
    jq -cn --arg r "$result" --arg s "${MOCK_CLAUDE_SUBTYPE:-success}" \
        --argjson e "${MOCK_CLAUDE_IS_ERROR:-false}" \
        '{type:"result",subtype:$s,is_error:$e,result:$r}'
fi
[[ -n "${MOCK_TIMES_DIR:-}" ]] && date +%s.%N > "${MOCK_TIMES_DIR}/claude.end"
exit "${MOCK_CLAUDE_EXIT:-0}"
CLAUDE_EOF
            } > "${MOCK_BIN}/claude"
            ;;
        copilot)
            {
                echo '#!/usr/bin/env bash'
                echo "$MOCK_PREAMBLE"
                cat << 'COPILOT_EOF'
# copilot -p "" --allow-all-tools -s: prompt on stdin (#212), response
# only (no stats footer) on stdout. A prompt smuggled onto argv would
# show up in <name>.argv and fail the stdin-contract test.
[[ -n "${MOCK_COPILOT_SLEEP:-}" ]] && sleep "${MOCK_COPILOT_SLEEP}"
[[ -n "${MOCK_COPILOT_STDERR:-}" ]] && echo "${MOCK_COPILOT_STDERR}" >&2
if [[ -n "${MOCK_COPILOT_EMPTY:-}" ]]; then
    :
elif [[ -n "${MOCK_COPILOT_ERRMARK:-}" ]]; then
    printf '%s\n' "${MOCK_COPILOT_ERRMARK}"
else
    printf '### Findings\nreviewed by copilot\n'
fi
[[ -n "${MOCK_TIMES_DIR:-}" ]] && date +%s.%N > "${MOCK_TIMES_DIR}/copilot.end"
exit "${MOCK_COPILOT_EXIT:-0}"
COPILOT_EOF
            } > "${MOCK_BIN}/copilot"
            ;;
        *)
            echo "make_mock_agent: unknown agent '${name}'" >&2
            return 1
            ;;
    esac
    chmod +x "${MOCK_BIN}/${name}"
}

# Run --agents <list> for PR 99 (issue 42); stdout captured to $1, exit
# code echoed. Extra args after the list are passed through.
# RUN_AGENTS_PATH (env) replaces the PATH prefix so a test can hide the
# real CLIs installed on the developer's machine (~/.local/bin etc.).
run_agents() {
    local out_file="$1" agents="$2"; shift 2
    cd "${MOCK_REPO}"
    local exit_code=0
    PATH="${RUN_AGENTS_PATH:-${MOCK_BIN}:${PATH}}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --agents "$agents" "$@" < /dev/null > "$out_file" 2>/dev/null || exit_code=$?
    echo "$exit_code"
}

# A PATH that has the mocks and the system tools but none of the real
# agent CLIs; paired with HOME pointed at an empty dir so the script's
# ~/.local/bin-style fallbacks find nothing either.
HIDDEN_CLI_PATH() { echo "${MOCK_BIN}:/usr/bin:/bin"; }

findings_of() { cat "${MOCK_REPO}/.agent/work-plans/issue-42/review-$1-findings.md"; }

test_sync_flag_rejected() {
    echo "TEST: --sync is rejected as removed (#206)"
    setup
    cd "${MOCK_REPO}"
    local exit_code=0 stderr
    stderr=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --sync 2>&1 >/dev/null) || exit_code=$?
    assert_exit_code "--sync exits 2" "2" "$exit_code"
    assert_contains "message names --sync and the removal" "\-\-sync was removed" "$stderr"
    teardown
}

test_agents_all_succeed() {
    echo "TEST: --agents runs every agent, prints one triplet each, exits 0 (#206)"
    setup
    make_mock_agent codex; make_mock_agent copilot
    local argv="${TMPDIR_BASE}/argv"; mkdir -p "$argv"
    local out="${TMPDIR_BASE}/out.txt" exit_code
    exit_code=$(MOCK_ARGV_DIR="$argv" run_agents "$out" "gemini,codex,copilot")
    assert_exit_code "all-succeed exits 0" "0" "$exit_code"
    # Per-agent invocation contract, now owned by _cli_review.sh (#313):
    # codex takes `exec` plus a final-message file, copilot takes an empty
    # -p with --allow-all-tools -s. Both read the prompt from stdin, so
    # neither may carry the prompt in argv (#212, #274).
    local codex_argv copilot_argv
    codex_argv=$(cat "$argv/codex.argv")
    copilot_argv=$(cat "$argv/copilot.argv")
    assert_eq "codex invoked as 'codex exec'" "exec" "$(head -n 1 "$argv/codex.argv")"
    assert_contains "codex asked for a final-message file" "^-o$" "$codex_argv"
    assert_eq "copilot argv is -p '' --allow-all-tools -s" \
        "$(printf -- '-p\n\n--allow-all-tools\n-s')" "$copilot_argv"
    assert_not_contains "codex prompt is not on argv" "Adversarial Code Review" "$codex_argv"
    assert_not_contains "copilot prompt is not on argv" "Adversarial Code Review" "$copilot_argv"
    local stdout; stdout=$(cat "$out")
    assert_contains "MODE=parallel-sync printed once" "^MODE=parallel-sync$" "$stdout"
    assert_eq "exactly one MODE line" "1" "$(grep -c '^MODE=' "$out")"
    assert_eq "three AGENT= lines" "3" "$(grep -c '^AGENT=' "$out")"
    assert_eq "three EXIT=0 lines" "3" "$(grep -c '^EXIT=0$' "$out")"
    assert_not_contains "no TMUX_SESSION line" "TMUX_SESSION" "$stdout"
    # Findings paths are announced before the agents run (tail -f contract):
    # the informational line for codex must precede its AGENT= triplet.
    local info_line triplet_line
    info_line=$(grep -n "^  codex: .*review-codex-findings.md" "$out" | head -n1 | cut -d: -f1)
    triplet_line=$(grep -n "^AGENT=codex$" "$out" | head -n1 | cut -d: -f1)
    if [[ -n "$info_line" && -n "$triplet_line" && "$info_line" -lt "$triplet_line" ]]; then
        echo "  PASS: findings path announced before the triplet"; PASS=$((PASS + 1))
    else
        echo "  FAIL: findings path not announced before the triplet (info=${info_line:-none} triplet=${triplet_line:-none})"; FAIL=$((FAIL + 1))
    fi
    # Triplet order follows the --agents order; EXIT immediately follows FINDINGS_FILE.
    local block; block=$(grep -E '^(AGENT|FINDINGS_FILE|EXIT)=' "$out" | tr '\n' ' ')
    assert_contains "triplets in selection order" \
        "AGENT=gemini FINDINGS_FILE=[^ ]*review-gemini-findings.md EXIT=0 AGENT=codex FINDINGS_FILE=[^ ]*review-codex-findings.md EXIT=0 AGENT=copilot" "$block"
    assert_contains "gemini findings complete" "Review complete" "$(findings_of gemini)"
    assert_contains "codex findings hold its output" "reviewed by codex" "$(findings_of codex)"
    assert_contains "codex findings complete" "Review complete" "$(findings_of codex)"
    assert_contains "copilot findings complete" "Review complete" "$(findings_of copilot)"
    assert_contains "each agent got its own prompt" "Adversarial Code Review" \
        "$(cat "${MOCK_REPO}/.agent/work-plans/issue-42/review-codex-prompt.md")"
    teardown
}

test_agents_partial_failure() {
    echo "TEST: one failing agent does not disturb the others; exit 3 with per-agent EXIT= (#206)"
    setup
    make_mock_agent codex; make_mock_agent copilot
    local out="${TMPDIR_BASE}/out.txt" exit_code
    exit_code=$(MOCK_CODEX_EXIT=7 run_agents "$out" "gemini,codex,copilot")
    assert_exit_code "partial failure exits 3" "3" "$exit_code"
    # EXIT= is the job's status. Since #313 that is _cli_review.sh's own
    # exit 1 ("no usable result"); the CLI's status is in the findings
    # file's reason, the same shape gemini has had since #288.
    assert_contains "codex EXIT=1" "^EXIT=1$" "$(cat "$out")"
    assert_contains "codex findings name the CLI's own status" "codex exited 7" "$(findings_of codex)"
    assert_eq "two EXIT=0 lines" "2" "$(grep -c '^EXIT=0$' "$out")"
    assert_contains "codex findings marked failed" "Review failed" "$(findings_of codex)"
    assert_not_contains "codex findings not marked complete" "Review complete" "$(findings_of codex)"
    assert_contains "gemini findings still complete" "Review complete" "$(findings_of gemini)"
    assert_contains "copilot findings still complete" "Review complete" "$(findings_of copilot)"
    teardown
}

test_agents_timeout() {
    echo "TEST: a hung agent is cut off by AGENT_TIMEOUT; the fast agent's marker is not delayed (#206)"
    setup
    make_mock_agent codex; make_mock_agent copilot
    local times="${TMPDIR_BASE}/times"; mkdir -p "$times"
    local out="${TMPDIR_BASE}/out.txt" exit_code
    exit_code=$(AGENT_TIMEOUT=1 MOCK_CODEX_SLEEP=6 MOCK_TIMES_DIR="$times" run_agents "$out" "codex,copilot")
    assert_exit_code "timeout run exits 3" "3" "$exit_code"
    assert_contains "codex EXIT=124 (timeout)" "^EXIT=124$" "$(cat "$out")"
    assert_contains "codex findings name the timeout" "timed out \(AGENT_TIMEOUT=1\)" "$(findings_of codex)"
    assert_contains "codex findings marked failed" "Review failed" "$(findings_of codex)"
    assert_contains "copilot findings complete" "Review complete" "$(findings_of copilot)"
    # codex must have been killed: its mock only writes .end when it ran
    # to completion, which AGENT_TIMEOUT=1 forbids.
    if [[ -f "$times/codex.end" ]]; then
        echo "  FAIL: codex ran to completion despite AGENT_TIMEOUT=1"; FAIL=$((FAIL + 1))
    else
        echo "  PASS: codex was killed before it could finish"; PASS=$((PASS + 1))
    fi
    teardown
}

test_agents_concurrency() {
    echo "TEST: agents run concurrently, not one after another (#206)"
    setup
    make_mock_agent codex; make_mock_agent copilot; make_mock_agent claude
    local times="${TMPDIR_BASE}/times"; mkdir -p "$times"
    local out="${TMPDIR_BASE}/out.txt" exit_code
    exit_code=$(MOCK_CODEX_SLEEP=2 MOCK_COPILOT_SLEEP=2 MOCK_CLAUDE_SLEEP=2 MOCK_TIMES_DIR="$times" \
        run_agents "$out" "codex,copilot,claude")
    assert_exit_code "concurrent run exits 0" "0" "$exit_code"
    # Interval overlap is the whole assertion: every agent started before
    # the first one ended, which sequential dispatch cannot produce. A
    # wall-clock bound was tried and dropped — it was the suite's one
    # load-sensitive check and could fail on a busy machine with nothing
    # actually regressed.
    local first_end; first_end=$(sort -n "$times"/*.end | head -n 1)
    local overlap=true a
    for a in codex copilot claude; do
        if ! awk -v s="$(cat "$times/$a.start")" -v e="$first_end" 'BEGIN{exit !(s < e)}'; then overlap=false; fi
    done
    if [[ "$overlap" == true ]]; then
        echo "  PASS: all three agents started before the first finished (intervals overlap)"; PASS=$((PASS + 1))
    else
        echo "  FAIL: agent intervals did not overlap"; FAIL=$((FAIL + 1))
    fi
    teardown
}

test_gemini_backstop_cuts_off_wedged_agy() {
    echo "TEST: a wedged agy is cut off by the outer gemini backstop (#206)"
    setup
    local times="${TMPDIR_BASE}/times"; mkdir -p "$times"
    local out="${TMPDIR_BASE}/out.txt" exit_code
    # agy consumes the prompt and never answers, so _agy_review.sh's own
    # --print-timeout handling never runs. Backstop = print-timeout (1s) +
    # margin (2s) = 3s; only that bound can end the run.
    local scratch="${TMPDIR_BASE}/scratch"; mkdir -p "$scratch"
    exit_code=$(TMPDIR="$scratch" AGY_PRINT_TIMEOUT=1s GEMINI_BACKSTOP_MARGIN=2 AGENT_KILL_AFTER=1 \
        MOCK_AGY_STALL=1 MOCK_TIMES_DIR="$times" run_agents "$out" "gemini")
    assert_exit_code "backstopped run exits 3" "3" "$exit_code"
    assert_contains "gemini EXIT=124 (timeout)" "^EXIT=124$" "$(cat "$out")"
    assert_contains "findings name the backstop and the print-timeout" \
        "GEMINI_BACKSTOP=3s, above AGY_PRINT_TIMEOUT=1s" "$(findings_of gemini)"
    assert_contains "gemini findings marked failed" "Review failed" "$(findings_of gemini)"
    # The wedged agy must be dead, not merely abandoned.
    sleep 0.3
    local agy_pid; agy_pid=$(cat "$times/agy.pid" 2>/dev/null || echo "")
    if [[ -n "$agy_pid" ]] && kill -0 "$agy_pid" 2>/dev/null; then
        kill "$agy_pid" 2>/dev/null || true
        echo "  FAIL: the wedged agy process survived the backstop"; FAIL=$((FAIL + 1))
    else
        echo "  PASS: the wedged agy process was killed"; PASS=$((PASS + 1))
    fi
    # Nothing is left in the scratch root: the parent owns the helper's
    # TMPDIR precisely because a SIGKILLed helper skips its own EXIT trap.
    assert_eq "no temp files survive the backstopped run" "0" "$(ls -A "$scratch" | wc -l)"
    teardown
}

test_gemini_not_bound_by_agent_timeout() {
    echo "TEST: gemini is not wrapped by the plain AGENT_TIMEOUT path (ADR-0015 §3) (#206)"
    setup
    make_mock_agent codex
    local out="${TMPDIR_BASE}/out.txt" exit_code
    # AGENT_TIMEOUT=1 kills codex (3s) but must not touch gemini, whose
    # bound is AGY_PRINT_TIMEOUT plus the backstop derived above it. If a
    # future change routed gemini through AGENT_TIMEOUT, its 3s turn would
    # be cut off and this test would fail.
    exit_code=$(AGENT_TIMEOUT=1 MOCK_AGY_SLEEP=3 MOCK_CODEX_SLEEP=3 run_agents "$out" "gemini,codex")
    assert_exit_code "mixed run exits 3 (codex timed out)" "3" "$exit_code"
    assert_contains "codex EXIT=124 under AGENT_TIMEOUT=1" "^EXIT=124$" "$(cat "$out")"
    assert_contains "codex findings name AGENT_TIMEOUT" "timed out \(AGENT_TIMEOUT=1\)" "$(findings_of codex)"
    assert_contains "gemini completed anyway" "Review complete" "$(findings_of gemini)"
    assert_not_contains "gemini not marked failed" "Review failed" "$(findings_of gemini)"
    assert_not_contains "gemini findings carry no AGENT_TIMEOUT note" "AGENT_TIMEOUT" "$(findings_of gemini)"
    teardown
}

# Run the script with one knob overridden; echoes "<exit>|<stderr>".
run_with_knob() {
    local assignment="$1" ec=0 stderr
    stderr=$(env "$assignment" PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 \
        bash "${SCRIPT_UNDER_TEST}" --pr 99 --agents codex 2>&1 >/dev/null) || ec=$?
    printf '%s|%s' "$ec" "$stderr"
}

test_duration_knobs_validated() {
    echo "TEST: bad duration knobs and a bad --pr exit 2 with a clear message (#206)"
    setup
    cd "${MOCK_REPO}"
    local ec stderr knob result
    # Shape: a non-duration is rejected for every knob.
    for knob in AGENT_TIMEOUT AGENT_KILL_AFTER GEMINI_BACKSTOP_MARGIN; do
        result=$(run_with_knob "${knob}=abc")
        assert_exit_code "bad ${knob} exits 2" "2" "${result%%|*}"
        assert_contains "message names ${knob} and the shape" "${knob} value 'abc' is not a valid duration" "${result#*|}"
    done

    # Range: 0 is a shape-valid value that silently removes a bound, so
    # the knobs whose whole purpose is a bound must refuse it.
    for knob in AGENT_TIMEOUT GEMINI_BACKSTOP_MARGIN; do
        result=$(run_with_knob "${knob}=0")
        assert_exit_code "${knob}=0 exits 2" "2" "${result%%|*}"
        assert_contains "${knob}=0 message demands a positive value" \
            "${knob} value '0' must be greater than zero" "${result#*|}"
    done
    result=$(run_with_knob "AGY_PRINT_TIMEOUT=0s")
    assert_exit_code "AGY_PRINT_TIMEOUT=0s exits 2" "2" "${result%%|*}"
    assert_contains "AGY_PRINT_TIMEOUT=0s message demands a positive value" \
        "AGY_PRINT_TIMEOUT value '0s' must be greater than zero" "${result#*|}"
    # AGENT_KILL_AFTER=0 is legitimate: SIGKILL immediately after SIGTERM.
    local out="${TMPDIR_BASE}/out.txt"
    make_mock_agent codex
    ec=$(AGENT_KILL_AFTER=0 run_agents "$out" "codex")
    assert_exit_code "AGENT_KILL_AFTER=0 is accepted" "0" "$ec"

    # Go-duration subset: AGY_PRINT_TIMEOUT reaches agy's --print-timeout,
    # which needs an explicit s/m/h unit and has no `d`. Both shapes below
    # are valid for coreutils `timeout` and would otherwise pass.
    for knob in "AGY_PRINT_TIMEOUT=90" "AGY_PRINT_TIMEOUT=1d"; do
        result=$(run_with_knob "$knob")
        assert_exit_code "${knob} exits 2" "2" "${result%%|*}"
        assert_contains "${knob} message names the Go-duration requirement" \
            "is not a valid Go duration" "${result#*|}"
    done
    # The same unit-less value stays valid for the coreutils-only knob.
    ec=$(AGENT_TIMEOUT=90 run_agents "$out" "codex")
    assert_exit_code "AGENT_TIMEOUT=90 (unit-less) is accepted" "0" "$ec"

    ec=0; stderr=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 \
        bash "${SCRIPT_UNDER_TEST}" --pr 9x --agents codex 2>&1 >/dev/null) || ec=$?
    assert_exit_code "non-integer --pr exits 2" "2" "$ec"
    assert_contains "--pr message names the value" "\-\-pr value '9x' is not a positive integer" "$stderr"
    teardown
}

test_agents_missing_binary() {
    echo "TEST: a missing CLI fails only that agent (#206)"
    setup
    make_mock_agent codex
    # copilot deliberately not mocked and hidden from PATH fallbacks.
    local out="${TMPDIR_BASE}/out.txt" exit_code
    exit_code=$(HOME="${TMPDIR_BASE}/nohome" RUN_AGENTS_PATH="$(HIDDEN_CLI_PATH)" run_agents "$out" "codex,copilot")
    assert_exit_code "missing-binary run exits 3" "3" "$exit_code"
    assert_contains "codex EXIT=0" "^EXIT=0$" "$(cat "$out")"
    assert_contains "copilot EXIT=1" "^EXIT=1$" "$(cat "$out")"
    assert_contains "copilot findings name the missing CLI" "copilot CLI not found" "$(findings_of copilot)"
    assert_contains "copilot findings marked failed" "Review failed" "$(findings_of copilot)"
    assert_contains "codex findings complete" "Review complete" "$(findings_of codex)"
    teardown
}

test_agents_none_usable() {
    echo "TEST: no usable CLI at all is a dependency error, exit 1 (#206)"
    setup
    local out="${TMPDIR_BASE}/out.txt" exit_code
    exit_code=$(HOME="${TMPDIR_BASE}/nohome" RUN_AGENTS_PATH="$(HIDDEN_CLI_PATH)" run_agents "$out" "codex,copilot")
    assert_exit_code "none usable exits 1" "1" "$exit_code"
    assert_not_contains "no triplets printed" "^AGENT=" "$(cat "$out")"
    teardown
}

test_agents_argument_hygiene() {
    echo "TEST: --agents hygiene — exclusion, unknown, empty entry, dedupe, case/space (#206)"
    setup
    make_mock_agent codex
    cd "${MOCK_REPO}"
    local ec stderr
    ec=0; stderr=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --agent codex --agents gemini 2>&1 >/dev/null) || ec=$?
    assert_exit_code "--agent with --agents exits 2" "2" "$ec"
    assert_contains "mutual-exclusion message" "mutually exclusive" "$stderr"

    ec=0; stderr=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --agents gemini,grok 2>&1 >/dev/null) || ec=$?
    assert_exit_code "unknown agent exits 2" "2" "$ec"
    assert_contains "unknown agent named" "Unknown agent 'grok'" "$stderr"

    ec=0; stderr=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --agents "gemini,,codex" 2>&1 >/dev/null) || ec=$?
    assert_exit_code "empty entry exits 2" "2" "$ec"
    assert_contains "empty-entry message" "empty entry" "$stderr"

    ec=0; stderr=$(PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --agents "codex," 2>&1 >/dev/null) || ec=$?
    assert_exit_code "trailing comma exits 2" "2" "$ec"

    local out="${TMPDIR_BASE}/out.txt"
    ec=$(run_agents "$out" " Codex , codex ")
    assert_exit_code "dedupe + trim + case run exits 0" "0" "$ec"
    assert_eq "duplicate collapses to one triplet" "1" "$(grep -c '^AGENT=' "$out")"
    assert_contains "normalised to lowercase codex" "^AGENT=codex$" "$(cat "$out")"
    teardown
}

test_agents_shared_diff_failure() {
    echo "TEST: a failed shared diff marks every selected findings file, no triplets, exit 3 (#206)"
    setup
    make_mock_agent codex
    cat > "${MOCK_BIN}/gh" << 'GH_EOF'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    shift 3; [[ "${1:-}" == "-R" ]] && shift 2
    case "$2" in body) echo "Closes #42" ;; title) echo "Test PR" ;; url) echo "https://github.com/test/repo/pull/99" ;; esac
    exit 0
elif [[ "$1" == "pr" && "$2" == "diff" ]]; then
    echo "gh: connection reset" >&2; exit 1
fi
exit 0
GH_EOF
    chmod +x "${MOCK_BIN}/gh"
    local out="${TMPDIR_BASE}/out.txt" exit_code
    exit_code=$(run_agents "$out" "gemini,codex")
    assert_exit_code "shared diff failure exits 3" "3" "$exit_code"
    assert_not_contains "no AGENT= triplets" "^AGENT=" "$(cat "$out")"
    assert_contains "gemini findings carry the error marker" "Review error: failed to retrieve diff" "$(findings_of gemini)"
    assert_contains "codex findings carry the error marker" "Review error: failed to retrieve diff" "$(findings_of codex)"
    teardown
}

test_agents_interrupt_kills_jobs() {
    echo "TEST: terminating the script stops the running agents promptly (#206)"
    setup
    make_mock_agent codex; make_mock_agent copilot
    local times="${TMPDIR_BASE}/times"; mkdir -p "$times"
    cd "${MOCK_REPO}"
    # SIGTERM, not SIGINT: bash ignores INT in background children of a
    # non-interactive shell, so a test-sent INT would never arrive. TERM
    # is what timeouts and callers send.
    local t0; t0=$(date +%s)
    MOCK_CODEX_SLEEP=30 MOCK_COPILOT_SLEEP=30 MOCK_TIMES_DIR="$times" \
        PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --agents codex,copilot < /dev/null > /dev/null 2>&1 &
    local script_pid=$!
    local i
    for ((i = 0; i < 50; i++)); do
        [[ -f "$times/codex.pid" && -f "$times/copilot.pid" ]] && break
        sleep 0.1
    done
    kill -TERM "$script_pid" 2>/dev/null || true
    local ec=0; wait "$script_pid" || ec=$?
    local elapsed=$(( $(date +%s) - t0 ))
    assert_exit_code "terminated script exits 143" "143" "$ec"
    if [[ "$elapsed" -lt 10 ]]; then
        echo "  PASS: script returned in ${elapsed}s, not after the agents' 30s sleep"; PASS=$((PASS + 1))
    else
        echo "  FAIL: script took ${elapsed}s to return after TERM"; FAIL=$((FAIL + 1))
    fi
    sleep 0.3
    local alive=0 p
    for p in codex copilot; do
        if [[ -f "$times/$p.pid" ]] && kill -0 "$(cat "$times/$p.pid")" 2>/dev/null; then
            alive=$((alive + 1))
            kill "$(cat "$times/$p.pid")" 2>/dev/null || true
        fi
    done
    assert_eq "no agent process survives the termination" "0" "$alive"
    teardown
}

test_single_agent_output_unchanged() {
    echo "TEST: --agent keeps the single-agent stdout contract (no EXIT=, no triplets) (#206)"
    setup
    make_mock_agent codex
    cd "${MOCK_REPO}"
    local out="${TMPDIR_BASE}/out.txt" ec=0
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${SCRIPT_UNDER_TEST}" \
        --pr 99 --agent codex < /dev/null > "$out" 2>/dev/null || ec=$?
    assert_exit_code "single agent exits 0" "0" "$ec"
    local stdout; stdout=$(cat "$out")
    assert_contains "MODE=sync" "^MODE=sync$" "$stdout"
    assert_contains "AGENT=codex" "^AGENT=codex$" "$stdout"
    assert_contains "FINDINGS_FILE line" "^FINDINGS_FILE=.*review-codex-findings.md$" "$stdout"
    assert_not_contains "no EXIT= line in single-agent mode" "^EXIT=" "$stdout"
    assert_contains "completion line" "^Review complete. Results:" "$stdout"
    assert_contains "codex findings complete" "Review complete" "$(findings_of codex)"
    teardown
}

# ---- _cli_review.sh result validation (#313, folding in #212) ----
#
# The codex/claude/copilot arms used to be gated on the CLI's exit code
# alone, so an empty response, a quota error printed as output, or (for
# codex) the raw stdout transcript all landed in the findings file as if
# they were a review. Each case below is one of those failure modes.

CLI_HELPER_UNDER_TEST="${SCRIPT_DIR}/../_cli_review.sh"
CLI_AGENTS=(codex claude copilot)

# Invoke _cli_review.sh directly (no cross_model_review.sh around it).
# Echoes the exit code; the findings file is the caller's to inspect.
run_cli_helper() {
    local agent="$1" prompt="$2" findings="$3" ec=0
    shift 3
    TMPDIR="${TMPDIR_BASE}/helper-tmp" PATH="${MOCK_BIN}:${PATH}" \
        bash "$CLI_HELPER_UNDER_TEST" "$agent" "${MOCK_BIN}/${agent}" \
        "$prompt" "$findings" "$@" >/dev/null 2>&1 || ec=$?
    echo "$ec"
}

test_cli_codex_transcript_not_in_findings() {
    echo "TEST: codex's stdout transcript never becomes the review (#313)"
    setup
    make_mock_agent codex
    local out="${TMPDIR_BASE}/out.txt" exit_code
    exit_code=$(run_agents "$out" "codex")
    assert_exit_code "codex run exits 0" "0" "$exit_code"
    local content; content=$(findings_of codex)
    assert_contains "findings hold the final message" "reviewed by codex" "$content"
    assert_not_contains "banner is not in the findings" "mock banner" "$content"
    assert_not_contains "echoed prompt is not in the findings" "MOCK TRANSCRIPT" "$content"
    assert_contains "findings complete" "Review complete" "$content"
    teardown
}

test_cli_prompt_reaches_every_cli_on_stdin() {
    echo "TEST: the prompt reaches every CLI on stdin, not /dev/null (#313)"
    setup
    local stdin_dir="${TMPDIR_BASE}/stdin"; mkdir -p "$stdin_dir"
    local agent out exit_code
    for agent in "${CLI_AGENTS[@]}"; do
        make_mock_agent "$agent"
    done
    out="${TMPDIR_BASE}/out.txt"
    exit_code=$(MOCK_STDIN_DIR="$stdin_dir" run_agents "$out" "codex,claude,copilot")
    assert_exit_code "all three exit 0" "0" "$exit_code"
    for agent in "${CLI_AGENTS[@]}"; do
        assert_contains "${agent} read the whole prompt from stdin" "Adversarial Code Review" \
            "$(cat "${stdin_dir}/${agent}.stdin" 2>/dev/null || echo "")"
    done
    teardown
}

test_cli_empty_response_is_failure() {
    echo "TEST: an empty response at exit 0 is a failed review for every CLI (#313, #288 class)"
    setup
    local agent out exit_code content
    for agent in "${CLI_AGENTS[@]}"; do
        make_mock_agent "$agent"
        out="${TMPDIR_BASE}/out-${agent}.txt"
        # run_agents is a shell function, so the knob is exported rather
        # than prefixed through `env`.
        export "MOCK_${agent^^}_EMPTY=1"
        exit_code=$(run_agents "$out" "$agent")
        unset "MOCK_${agent^^}_EMPTY"
        assert_exit_code "${agent} empty response exits 3" "3" "$exit_code"
        content=$(findings_of "$agent")
        assert_contains "${agent} findings name the empty response" "empty response" "$content"
        assert_contains "${agent} findings marked failed" "Review failed" "$content"
        assert_not_contains "${agent} findings not marked complete" "Review complete" "$content"
    done
    teardown
}

test_cli_nonzero_exit_is_failure() {
    echo "TEST: a non-zero CLI exit is reported with its status for every CLI (#313)"
    setup
    local agent out exit_code content
    for agent in "${CLI_AGENTS[@]}"; do
        make_mock_agent "$agent"
        out="${TMPDIR_BASE}/out-${agent}.txt"
        export "MOCK_${agent^^}_EXIT=7" "MOCK_${agent^^}_STDERR=boom"
        exit_code=$(run_agents "$out" "$agent")
        unset "MOCK_${agent^^}_EXIT" "MOCK_${agent^^}_STDERR"
        assert_exit_code "${agent} crash exits 3" "3" "$exit_code"
        content=$(findings_of "$agent")
        assert_contains "${agent} findings name the exit status" "${agent} exited 7" "$content"
        assert_contains "${agent} findings carry the CLI's output" "boom" "$content"
        assert_contains "${agent} findings marked failed" "Review failed" "$content"
    done
    teardown
}

test_cli_error_marker_is_failure() {
    echo "TEST: a quota / rate-limit error printed as the answer is a failed review (#313)"
    setup
    local agent out exit_code content
    for agent in "${CLI_AGENTS[@]}"; do
        make_mock_agent "$agent"
        out="${TMPDIR_BASE}/out-${agent}.txt"
        # Exit 0 throughout: the marker is the only signal there is.
        export "MOCK_${agent^^}_ERRMARK=Error: you have exceeded your usage limit."
        exit_code=$(run_agents "$out" "$agent")
        unset "MOCK_${agent^^}_ERRMARK"
        assert_exit_code "${agent} quota error exits 3" "3" "$exit_code"
        content=$(findings_of "$agent")
        assert_contains "${agent} findings name the error" "usage limit" "$content"
        assert_contains "${agent} findings marked failed" "Review failed" "$content"
        assert_not_contains "${agent} findings not marked complete" "Review complete" "$content"
    done
    # The same markers in a real review body must NOT fail it: an
    # adversarial review may legitimately discuss rate limits.
    make_mock_agent copilot
    local long_review="### Findings

1. The retry path ignores the rate limit header, so an unauthorized
   response is retried forever. This is a long review body that happens
   to mention quota handling and authentication failed states, and it
   must still be accepted as a review rather than read as an error.
"
    local out2="${TMPDIR_BASE}/out-long.txt" ec2
    ec2=$(MOCK_COPILOT_ERRMARK="$long_review" run_agents "$out2" "copilot")
    assert_exit_code "a long review mentioning rate limits still passes" "0" "$ec2"
    assert_contains "the review body is kept" "retry path ignores the rate limit" "$(findings_of copilot)"
    teardown
}

test_cli_timeout_kills_the_cli() {
    echo "TEST: AGENT_TIMEOUT cuts off each CLI through the helper (#313)"
    setup
    local agent out exit_code times
    for agent in "${CLI_AGENTS[@]}"; do
        make_mock_agent "$agent"
        times="${TMPDIR_BASE}/times-${agent}"; mkdir -p "$times"
        out="${TMPDIR_BASE}/out-${agent}.txt"
        export "MOCK_${agent^^}_SLEEP=6"
        exit_code=$(AGENT_TIMEOUT=1 AGENT_KILL_AFTER=1 MOCK_TIMES_DIR="$times" \
            run_agents "$out" "$agent")
        unset "MOCK_${agent^^}_SLEEP"
        assert_exit_code "${agent} timeout exits 3" "3" "$exit_code"
        assert_contains "${agent} EXIT=124" "^EXIT=124$" "$(cat "$out")"
        assert_contains "${agent} findings name the timeout" "timed out \(AGENT_TIMEOUT=1\)" "$(findings_of "$agent")"
        if [[ -f "$times/${agent}.end" ]]; then
            echo "  FAIL: ${agent} ran to completion despite AGENT_TIMEOUT=1"; FAIL=$((FAIL + 1))
        else
            echo "  PASS: ${agent} was killed before it could finish"; PASS=$((PASS + 1))
        fi
        # The CLI process itself must be gone, not merely abandoned: the
        # helper forwards the TERM to its child.
        sleep 0.3
        local pid; pid=$(cat "$times/${agent}.pid" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            echo "  FAIL: the ${agent} process survived the timeout"; FAIL=$((FAIL + 1))
        else
            echo "  PASS: the ${agent} process was killed"; PASS=$((PASS + 1))
        fi
    done
    teardown
}

test_cli_claude_json_contract() {
    echo "TEST: claude's JSON result is validated, not trusted (#313)"
    setup
    make_mock_agent claude
    local out="${TMPDIR_BASE}/out.txt" ec

    ec=$(MOCK_CLAUDE_RAW="not json at all" run_agents "$out" "claude")
    assert_exit_code "non-JSON output exits 3" "3" "$ec"
    assert_contains "reason names the missing JSON result" "did not emit a JSON result object" "$(findings_of claude)"
    assert_not_contains "the raw output is not kept as a review" "not json at all" \
        "$(head -n 1 "${MOCK_REPO}/.agent/work-plans/issue-42/review-claude-findings.md")"

    ec=$(MOCK_CLAUDE_IS_ERROR=true MOCK_CLAUDE_ERRMARK="something broke" run_agents "$out" "claude")
    assert_exit_code "is_error=true exits 3" "3" "$ec"
    assert_contains "reason names is_error" "is_error=true" "$(findings_of claude)"

    ec=$(MOCK_CLAUDE_SUBTYPE=error_during_execution run_agents "$out" "claude")
    assert_exit_code "non-success subtype exits 3" "3" "$ec"
    assert_contains "reason names the subtype" "subtype is 'error_during_execution'" "$(findings_of claude)"

    ec=$(run_agents "$out" "claude")
    assert_exit_code "a valid result exits 0" "0" "$ec"
    assert_contains "findings hold .result only" "reviewed by claude" "$(findings_of claude)"
    assert_not_contains "the JSON envelope is not in the findings" "subtype" "$(findings_of claude)"
    teardown
}

test_copilot_stdin_contract() {
    echo "TEST: copilot's prompt goes over stdin, never argv (#212, #274)"
    setup
    make_mock_agent copilot
    local argv="${TMPDIR_BASE}/argv" stdin="${TMPDIR_BASE}/stdin"
    mkdir -p "$argv" "$stdin"
    local out="${TMPDIR_BASE}/out.txt" ec
    ec=$(MOCK_ARGV_DIR="$argv" MOCK_STDIN_DIR="$stdin" run_agents "$out" "copilot")
    assert_exit_code "copilot run exits 0" "0" "$ec"
    local argv_text stdin_text
    argv_text=$(cat "$argv/copilot.argv")
    stdin_text=$(cat "$stdin/copilot.stdin")
    assert_not_contains "prompt content is NOT on argv" "Adversarial Code Review" "$argv_text"
    assert_contains "argv is the empty-prompt print form" "^-p$" "$argv_text"
    assert_contains "argv carries --allow-all-tools" "^--allow-all-tools$" "$argv_text"
    assert_contains "argv carries -s (response only)" "^-s$" "$argv_text"
    assert_contains "the prompt arrived on stdin" "Adversarial Code Review" "$stdin_text"
    teardown
}

test_cli_copilot_prompt_size_guard() {
    echo "TEST: the copilot prompt-size guard fires at 128 KiB and only for copilot (#313)"
    setup
    make_mock_agent copilot; make_mock_agent codex
    mkdir -p "${TMPDIR_BASE}/helper-tmp"
    # 128 KiB + 1: exactly the point where an argv form would exec-fail
    # with E2BIG (Linux MAX_ARG_STRLEN).
    local big="${TMPDIR_BASE}/big-prompt.md"
    head -c 131073 /dev/zero | tr '\0' 'x' > "$big"
    local findings="${TMPDIR_BASE}/big-findings.md" ec
    ec=$(run_cli_helper copilot "$big" "$findings" 1800)
    assert_exit_code "oversized copilot prompt exits 1" "1" "$ec"
    assert_contains "reason names the guard and the limit" "131072-byte guard" "$(cat "$findings")"
    assert_contains "reason says the prompt is passed on stdin" "passed on stdin" "$(cat "$findings")"
    # A prompt just under the bound is fine, and the guard is copilot-only.
    local ok="${TMPDIR_BASE}/ok-prompt.md"
    head -c 131072 /dev/zero | tr '\0' 'x' > "$ok"
    ec=$(run_cli_helper copilot "$ok" "$findings" 1800)
    assert_exit_code "a prompt at exactly the bound is accepted" "0" "$ec"
    ec=$(run_cli_helper codex "$big" "$findings" 1800)
    assert_exit_code "codex is not subject to the copilot guard" "0" "$ec"
    teardown
}

test_cli_helper_forwards_term() {
    echo "TEST: TERM to the helper kills its CLI child, not just the helper (#313)"
    setup
    make_mock_agent codex
    local times="${TMPDIR_BASE}/times"; mkdir -p "$times" "${TMPDIR_BASE}/helper-tmp"
    local prompt="${TMPDIR_BASE}/prompt.md" findings="${TMPDIR_BASE}/findings.md"
    echo "review this" > "$prompt"
    MOCK_CODEX_SLEEP=30 MOCK_TIMES_DIR="$times" TMPDIR="${TMPDIR_BASE}/helper-tmp" \
        PATH="${MOCK_BIN}:${PATH}" bash "$CLI_HELPER_UNDER_TEST" codex "${MOCK_BIN}/codex" \
        "$prompt" "$findings" 1800 >/dev/null 2>&1 &
    local helper_pid=$! i
    for ((i = 0; i < 50; i++)); do
        [[ -f "$times/codex.pid" ]] && break
        sleep 0.1
    done
    kill -TERM "$helper_pid" 2>/dev/null || true
    local ec=0; wait "$helper_pid" || ec=$?
    assert_exit_code "helper exits 143 on TERM" "143" "$ec"
    sleep 0.3
    local pid; pid=$(cat "$times/codex.pid" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        echo "  FAIL: the codex mock survived the helper's TERM"; FAIL=$((FAIL + 1))
    else
        echo "  PASS: the codex mock was killed with the helper"; PASS=$((PASS + 1))
    fi
    assert_eq "no helper temp dir survives the TERM" "0" "$(ls -A "${TMPDIR_BASE}/helper-tmp" | wc -l)"
    teardown
}

test_cli_findings_truncated_and_usage_errors() {
    echo "TEST: the helper truncates stale findings first and refuses bad usage (#313)"
    setup
    make_mock_agent codex
    mkdir -p "${TMPDIR_BASE}/helper-tmp"
    local prompt="${TMPDIR_BASE}/prompt.md" findings="${TMPDIR_BASE}/findings.md" ec
    echo "review this" > "$prompt"

    # Stale findings from a previous run must not survive a failure.
    echo "STALE FINDINGS FROM LAST RUN" > "$findings"
    ec=$(MOCK_CODEX_EXIT=7 run_cli_helper codex "$prompt" "$findings" 1800)
    assert_exit_code "crashed CLI exits 1" "1" "$ec"
    assert_not_contains "stale findings are gone" "STALE FINDINGS" "$(cat "$findings")"

    # An unknown agent is a usage error (exit 2) with the reason recorded.
    echo "STALE FINDINGS FROM LAST RUN" > "$findings"
    ec=0
    TMPDIR="${TMPDIR_BASE}/helper-tmp" bash "$CLI_HELPER_UNDER_TEST" grok "${MOCK_BIN}/codex" \
        "$prompt" "$findings" >/dev/null 2>&1 || ec=$?
    assert_exit_code "unknown agent exits 2" "2" "$ec"
    assert_not_contains "stale findings gone on a usage error too" "STALE FINDINGS" "$(cat "$findings")"
    assert_contains "reason names the unsupported agent" "unsupported agent 'grok'" "$(cat "$findings")"

    # A missing prompt file fails with a reason rather than running the CLI.
    ec=$(run_cli_helper codex "${TMPDIR_BASE}/nope.md" "$findings" 1800)
    assert_exit_code "missing prompt exits 1" "1" "$ec"
    assert_contains "reason names the prompt file" "prompt file not readable" "$(cat "$findings")"

    assert_eq "no helper temp files left behind" "0" "$(ls -A "${TMPDIR_BASE}/helper-tmp" | wc -l)"
    teardown
}

test_cli_no_temp_leak() {
    echo "TEST: _cli_review.sh leaves no temp files on success or failure (#313)"
    setup
    make_mock_agent codex; make_mock_agent claude; make_mock_agent copilot
    local leak_dir="${TMPDIR_BASE}/leakcheck"; mkdir -p "$leak_dir"
    local out="${TMPDIR_BASE}/out.txt"
    cd "${MOCK_REPO}"
    TMPDIR="$leak_dir" PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 \
        bash "${SCRIPT_UNDER_TEST}" --pr 99 --agents codex,claude,copilot \
        < /dev/null > "$out" 2>/dev/null || true
    MOCK_CODEX_EMPTY=1 MOCK_CLAUDE_EXIT=4 MOCK_COPILOT_ERRMARK="Error: rate limit reached" \
        TMPDIR="$leak_dir" PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 \
        bash "${SCRIPT_UNDER_TEST}" --pr 99 --agents codex,claude,copilot \
        < /dev/null > "$out" 2>/dev/null || true
    assert_eq "no temp files left after success + three failure modes" "" "$(ls -A "$leak_dir")"
    teardown
}

test_cli_helper_missing_is_unavailable() {
    echo "TEST: a missing _cli_review.sh makes only codex/claude/copilot unavailable (#313)"
    setup
    make_mock_agent codex
    # A copy of the scripts dir with _cli_review.sh removed: the precheck
    # must fail codex and leave gemini (whose own helper is still there)
    # untouched. The whole dir is copied because the script sources
    # siblings (_resolve_work_plans_dir.sh and friends) from beside itself.
    local fake_dir="${TMPDIR_BASE}/fakescripts"
    mkdir -p "$fake_dir"
    cp "${SCRIPT_DIR}/.."/*.sh "$fake_dir/"
    rm -f "${fake_dir}/_cli_review.sh"
    cd "${MOCK_REPO}"
    local out="${TMPDIR_BASE}/out.txt" ec=0
    PATH="${MOCK_BIN}:${PATH}" WORKTREE_ISSUE=42 bash "${fake_dir}/cross_model_review.sh" \
        --pr 99 --agents gemini,codex < /dev/null > "$out" 2>/dev/null || ec=$?
    assert_exit_code "run with a missing helper exits 3" "3" "$ec"
    assert_contains "codex findings name the missing helper" "_cli_review.sh is missing or not executable" \
        "$(findings_of codex)"
    assert_contains "gemini still completed" "Review complete" "$(findings_of gemini)"
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
test_agy_partial_denial_is_noted
test_diff_fetch_failure_is_marked
test_agy_api_error_message_kept
test_agy_findings_truncated
test_agy_no_temp_leak
test_prompt_tool_use_guidance
test_work_plans_excluded_from_diff
test_branch_mode_filter_survives_noprefix
test_sync_flag_rejected
test_agents_all_succeed
test_agents_partial_failure
test_agents_timeout
test_agents_concurrency
test_gemini_backstop_cuts_off_wedged_agy
test_gemini_not_bound_by_agent_timeout
test_duration_knobs_validated
test_agents_missing_binary
test_agents_none_usable
test_agents_argument_hygiene
test_agents_shared_diff_failure
test_agents_interrupt_kills_jobs
test_single_agent_output_unchanged
test_cli_codex_transcript_not_in_findings
test_cli_prompt_reaches_every_cli_on_stdin
test_cli_empty_response_is_failure
test_cli_nonzero_exit_is_failure
test_cli_error_marker_is_failure
test_cli_timeout_kills_the_cli
test_cli_claude_json_contract
test_copilot_stdin_contract
test_cli_copilot_prompt_size_guard
test_cli_helper_forwards_term
test_cli_findings_truncated_and_usage_errors
test_cli_no_temp_leak
test_cli_helper_missing_is_unavailable

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
