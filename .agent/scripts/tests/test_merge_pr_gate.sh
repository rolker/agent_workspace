#!/usr/bin/env bash
# .agent/scripts/tests/test_merge_pr_gate.sh
# Tests for merge_pr.sh's review-loop merge gate (issue #269 PR F, Layer 1):
#   --report-only — each gap fixture proceeds to `gh pr merge`, prints
#     the "would have refused" line naming the failing condition(s), and
#     records a `## Merge (report-only)` entry; the all-good fixture prints
#     nothing and records nothing
#   enforce (the default), workspace scope — each gap fixture refuses (exit 1,
#     no merge call, worktree untouched); the all-good fixture merges
#   enforce, project scope — stays report-only (asserted explicitly)
#   --force-unreviewed — bypasses with the banner and a `## Merge (unreviewed)`
#     entry, in both modes
#   no open worktree — the record is posted as a PR comment
#   a project registered outside project/ — the gate reads, and Step 1.5
#     writes, the timeline in that repo's worktree; its main checkout on the
#     PR branch is never used (#379)
# The gh stub answers `pr view` from fixture files, logs every call, and
# `pr merge` exits GH_MERGE_EXIT (set to 1 so a report-only run stops right
# after reaching Step 3 and the worktree survives for assertions).
# Run: bash .agent/scripts/tests/test_merge_pr_gate.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
tail_of() {  # <text> <n>: the last n characters (all of a shorter text)
    local t="$1" n="$2"
    (( ${#t} > n )) && t="${t:${#t}-n}"
    printf '%s' "$t"
}
# One sandbox for the whole run, created at top level (not inside $()) so
# the trap actually fires — see issue #297. make_sandbox() carves per-test
# directories out of it with `mktemp -d -p "$SANDBOX"`, which needs no
# shared state and so survives being called as `sb="$(make_sandbox)"`.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export AGENT_NAME="Test Agent"
export AGENT_EMAIL="test+agent@example.com"
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT

HEAD_SHA="abc1234abc1234abc1234abc1234abc1234abc12"
PR=70

write_gh_stub() {
    cat > "$1/stubbin/gh" <<'EOF'
#!/usr/bin/env bash
: "${GH_FIXTURES_DIR:?}"
log="${GH_CALL_LOG:-/dev/null}"
printf '%s\n' "$*" >> "$log"
sanitize() { printf '%s' "$1" | tr '/' '_'; }
if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    num="$3"; shift 3; repo=""; jsonflds=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -R) repo="$2"; shift 2 ;;
            --json) jsonflds="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    base="$GH_FIXTURES_DIR/pr_view_$(sanitize "$repo")_${num}"
    f="${base}.json"
    [ -f "$f" ] || { echo "GraphQL: Could not resolve to a PullRequest with the number of '$num'." >&2; exit 1; }
    if [ "$jsonflds" = "mergeable,mergeStateStatus" ]; then
        # Sequenced per call so a test can express "UNKNOWN for the first
        # N pr view calls, then MERGEABLE" without any real sleeping:
        # <base>.mergeable_<N>.json for call N, else the static
        # <base>.mergeable.json fallback, else GH_MERGEABLE_DEFAULT
        # (UNKNOWN forever when unset — ci-8 relies on that; run_merge sets
        # it to MERGEABLE so the always-on settle (#290) resolves at once).
        # GH_MERGEABLE_DEFAULT=FAIL makes the fallback a failed lookup (an
        # unreachable GitHub) instead of an answer.
        cnt_file="${base}.mergeable_seq"
        n=$(( $(cat "$cnt_file" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$cnt_file"
        mf="${base}.mergeable_${n}.json"
        [ -f "$mf" ] || mf="${base}.mergeable.json"
        if [ -f "$mf" ]; then cat "$mf"; else d="${GH_MERGEABLE_DEFAULT:-UNKNOWN}"; [ "$d" = "FAIL" ] && { echo "error connecting to api.github.com" >&2; exit 1; }; printf '{"mergeable":"%s","mergeStateStatus":"%s"}\n' "$d" "$d"; fi
    else
        cat "$f"
    fi
    exit 0
elif [ "$1" = "pr" ] && [ "$2" = "merge" ]; then
    # Sequenced per call (#290): merge_exit_<N> / merge_stderr_<N> under
    # GH_FIXTURES_DIR drive call N; absent files fall back to GH_MERGE_EXIT
    # and no stderr, so every pre-existing test behaves as before.
    mcnt="$GH_FIXTURES_DIR/.merge_seq"
    m=$(( $(cat "$mcnt" 2>/dev/null || echo 0) + 1 )); echo "$m" > "$mcnt"
    [ -f "$GH_FIXTURES_DIR/merge_stderr_${m}" ] && cat "$GH_FIXTURES_DIR/merge_stderr_${m}" >&2
    if [ -f "$GH_FIXTURES_DIR/merge_exit_${m}" ]; then exit "$(cat "$GH_FIXTURES_DIR/merge_exit_${m}")"; fi
    exit "${GH_MERGE_EXIT:-0}"
elif [ "$1" = "pr" ] && [ "$2" = "checks" ]; then exit 0
elif [ "$1" = "pr" ] && [ "$2" = "comment" ]; then
    shift 3; body=""
    while [ $# -gt 0 ]; do case "$1" in --body-file) body="$2"; shift 2 ;; *) shift ;; esac; done
    [ -n "$body" ] && cat "$body" >> "$GH_FIXTURES_DIR/comments_posted.md"
    exit 0
elif [ "$1" = "pr" ] && [ "$2" = "list" ]; then echo 0; exit 0
elif [ "$1" = "api" ]; then
    # merge_pr.sh's SHA-targeted CI poll (issue #284/#271): check-runs,
    # legacy commit status, and the workflow count. Sequenced the same
    # way as `pr view --json mergeable,...` above: api_<key>_<N>.json for
    # call N against that exact path, else the static api_<key>.json,
    # else an empty/zero default — so "empty for the first N calls, then
    # green" needs no real sleeping either. A sibling api_<key>_<N>.exit
    # (or the static api_<key>.exit) file, containing a nonzero exit code,
    # makes that call fail (empty stdout, that exit code) instead of
    # answering from the .json fixture — simulates a `gh api` failure
    # (rate limit, network, 5xx, auth) independent of the JSON payload.
    path="$2"
    # Method check (#289): real `gh api` turns `-f`/`-F` into a POST unless
    # `-X GET` is given, and GitHub 404s a POST to these read endpoints.
    # Mirror that so a missing `-X GET` fails here instead of only live.
    has_param=false; has_get=false; prev=""
    for a in "$@"; do
        case "$a" in -f|-F|--raw-field|--field) has_param=true ;; esac
        [ "$prev" = "-X" ] && [ "$a" = "GET" ] && has_get=true
        [ "$a" = "--method=GET" ] && has_get=true
        prev="$a"
    done
    if [ "$has_param" = true ] && [ "$has_get" = false ]; then
        echo 'gh: Not Found (HTTP 404) — -f without -X GET sends a POST' >&2
        exit 1
    fi
    key="$(sanitize "$path")"
    cnt_file="$GH_FIXTURES_DIR/.api_seq_${key}"
    n=$(( $(cat "$cnt_file" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$cnt_file"
    ef="$GH_FIXTURES_DIR/api_${key}_${n}.exit"
    [ -f "$ef" ] || ef="$GH_FIXTURES_DIR/api_${key}.exit"
    if [ -f "$ef" ]; then
        echo "simulated gh api failure" >&2
        exit "$(cat "$ef")"
    fi
    f="$GH_FIXTURES_DIR/api_${key}_${n}.json"
    [ -f "$f" ] || f="$GH_FIXTURES_DIR/api_${key}.json"
    if [ -f "$f" ]; then cat "$f"; else echo '{}'; fi
    exit 0
else exit 1; fi
EOF
    chmod +x "$1/stubbin/gh"
}

# A workspace sandbox: the sandbox itself is the workspace repo (ROOT_DIR),
# with a bare origin, a feature/issue-7 worktree, and a progress.md fixture.
make_sandbox() {  # <progress-body|""> [with_summary]
    local sb bare
    sb="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$sb/.agent/scripts" "$sb/stubbin" "$sb/gh_fixtures"
    for f in _bookkeeping.sh merge_pr.sh worktree_remove.sh worktree_list.sh _worktree_helpers.sh _issue_helpers.sh _project_registry.sh _resolve_default_branch.sh progress_read.py progress_append.sh _progress_entry.sh _resolve_work_plans_dir.sh update_roadmap.sh _real_case_path.sh; do
        cp "$REAL_ROOT/.agent/scripts/$f" "$sb/.agent/scripts/"
    done
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"; chmod +x "$sb/stubbin/git-bug"
    write_gh_stub "$sb"
    git -C "$sb" init --quiet -b main
    git -C "$sb" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
    # String-derived sibling of $sb (so it lands under $SANDBOX too); the
    # gh fixture filenames are keyed on this exact path string.
    bare="${sb}.remote.git"; git init --bare --quiet "$bare"; git -C "$bare" symbolic-ref HEAD refs/heads/main
    git -C "$sb" remote add origin "$bare"
    git -C "$sb" push --quiet -u origin main
    # the PR's worktree with its timeline
    mkdir -p "$sb/worktrees/workspace"
    git -C "$sb" worktree add --quiet "$sb/worktrees/workspace/issue-workspace-7" -b feature/issue-7 >/dev/null 2>&1
    if [[ -n "$1" ]]; then
        mkdir -p "$sb/worktrees/workspace/issue-workspace-7/.agent/work-plans/issue-7"
        printf -- '---\nissue: 7\n---\n\n# Issue #7\n\n%s\n' "$1" > "$sb/worktrees/workspace/issue-workspace-7/.agent/work-plans/issue-7/progress.md"
        git -C "$sb/worktrees/workspace/issue-workspace-7" add -A
        git -C "$sb/worktrees/workspace/issue-workspace-7" -c user.name=t -c user.email=t@t commit --quiet -m "progress"
    fi
    git -C "$sb/worktrees/workspace/issue-workspace-7" push --quiet -u origin feature/issue-7
    # PR fixture keyed on the workspace remote. with_summary puts the section
    # in a comment; body_summary puts it in the PR body (the template's place).
    local comments='[]' body='"## Summary\n\nplain body"'
    [[ "${2:-}" == with_summary ]] && comments='[{"body":"## Decision summary\n\n**What changed**: x\n\n**Recommendation**: merge"}]'
    [[ "${2:-}" == body_summary ]] && body='"## Summary\n\nx\n\n## Decision summary\n\n**What changed**: in the body\n\n**Recommendation**: merge"'
    printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":%s,"body":%s}\n' "$HEAD_SHA" "$comments" "$body" \
        > "$sb/gh_fixtures/pr_view_$(printf '%s' "$bare" | tr '/' '_')_${PR}.json"
    echo "$sb"
}

run_merge() {  # <sb> [args...]
    local sb="$1"; shift
    # The mergeability settle runs even under --no-wait (#290): default the
    # stub to MERGEABLE and zero sleeps so these cases never poll for real.
    (cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" GH_MERGE_EXIT="${GH_MERGE_EXIT:-1}" \
        GH_MERGEABLE_DEFAULT="${GH_MERGEABLE_DEFAULT:-MERGEABLE}" MERGE_PR_CI_POLL_SECONDS=0 \
        MERGE_PR_CI_GRACE_SECONDS="${MERGE_PR_CI_GRACE_SECONDS:-5}" \
        "$sb/.agent/scripts/merge_pr.sh" --pr "$PR" --type workspace --no-wait --no-roadmap-update "$@")
}
progress_of() { cat "$1/worktrees/workspace/issue-workspace-7/.agent/work-plans/issue-7/progress.md" 2>/dev/null; }
merged_called() { grep -q "^pr merge" "$1/gh_calls.log" 2>/dev/null; }
merge_count() { grep -c "^pr merge" "$1/gh_calls.log" 2>/dev/null || echo 0; }

# ---- Helpers for the CI-target / CI-wait / mergeability tests (#284) ----
# The sandbox's origin is a plain local bare-repo path, not a github.com
# URL, so extract_gh_slug (correctly) resolves PR_REPO_SLUG to "". Every
# gh-api fixture path below is built with that same empty slug so it
# matches exactly what merge_pr.sh itself requests.
ci_wt() { echo "$1/worktrees/workspace/issue-workspace-7"; }
api_key() { printf '%s' "$1" | tr '/' '_'; }
checkruns_path() { printf 'repos//commits/%s/check-runs' "$1"; }
status_path()    { printf 'repos//commits/%s/status' "$1"; }
workflows_path() { printf 'repos//actions/workflows'; }
write_api_fixture() {  # <sb> <path> <json> [seq_n]
    local sb="$1" path="$2" json="$3" n="${4:-}" key f
    key="$(api_key "$path")"
    if [[ -n "$n" ]]; then f="$sb/gh_fixtures/api_${key}_${n}.json"; else f="$sb/gh_fixtures/api_${key}.json"; fi
    printf '%s' "$json" > "$f"
}
write_checkruns() { write_api_fixture "$1" "$(checkruns_path "$2")" "$3" "${4:-}"; }
write_workflows() { write_api_fixture "$1" "$(workflows_path)" "$2" "${3:-}"; }
write_api_exit() {  # <sb> <path> <code> [seq_n]
    local sb="$1" path="$2" code="$3" n="${4:-}" key f
    key="$(api_key "$path")"
    if [[ -n "$n" ]]; then f="$sb/gh_fixtures/api_${key}_${n}.exit"; else f="$sb/gh_fixtures/api_${key}.exit"; fi
    printf '%s' "$code" > "$f"
}
write_checkruns_exit() { write_api_exit "$1" "$(checkruns_path "$2")" "$3" "${4:-}"; }
write_workflows_exit() { write_api_exit "$1" "$(workflows_path)" "$2" "${3:-}"; }
CHECKRUNS_SUCCESS='{"check_runs":[{"conclusion":"success","status":"completed"}]}'
CHECKRUNS_PENDING='{"check_runs":[{"conclusion":null,"status":"in_progress"}]}'
CHECKRUNS_FAILED='{"check_runs":[{"conclusion":"failure","status":"completed"}]}'
CHECKRUNS_STARTUP_FAILURE='{"check_runs":[{"conclusion":"startup_failure","status":"completed"}]}'
CHECKRUNS_STALE='{"check_runs":[{"conclusion":"stale","status":"completed"}]}'
CHECKRUNS_NONE='{"check_runs":[]}'
# Copilot's review check-run (#300): excluded from CI classification by name.
COPILOT_RUN='{"name":"copilot-pull-request-reviewer","conclusion":"failure","status":"completed"}'
COPILOT_RUN_RUNNING='{"name":"copilot-pull-request-reviewer","conclusion":null,"status":"in_progress"}'
CHECKRUNS_COPILOT_ONLY="{\"check_runs\":[${COPILOT_RUN}]}"
CHECKRUNS_COPILOT_ONLY_RUNNING="{\"check_runs\":[${COPILOT_RUN_RUNNING}]}"
CHECKRUNS_COPILOT_PLUS_LINT_SUCCESS="{\"check_runs\":[${COPILOT_RUN},{\"name\":\"Lint (pre-commit)\",\"conclusion\":\"success\",\"status\":\"completed\"}]}"
CHECKRUNS_COPILOT_PLUS_LINT_PENDING="{\"check_runs\":[${COPILOT_RUN},{\"name\":\"Lint (pre-commit)\",\"conclusion\":null,\"status\":\"in_progress\"}]}"
# A re-triggered review: one completed run and one still running, same name.
CHECKRUNS_COPILOT_TWICE_PLUS_LINT_SUCCESS="{\"check_runs\":[${COPILOT_RUN},${COPILOT_RUN_RUNNING},{\"name\":\"Lint (pre-commit)\",\"conclusion\":\"success\",\"status\":\"completed\"}]}"
CHECKRUNS_COPILOT_RUNNING_PLUS_LINT_SUCCESS="{\"check_runs\":[${COPILOT_RUN_RUNNING},{\"name\":\"Lint (pre-commit)\",\"conclusion\":\"success\",\"status\":\"completed\"}]}"
CHECKRUNS_COPILOT_PLUS_LINT_FAILED="{\"check_runs\":[${COPILOT_RUN},{\"name\":\"Lint (pre-commit)\",\"conclusion\":\"failure\",\"status\":\"completed\"}]}"
write_mergeable_fixture() {  # <sb> <state> [seq_n]
    local sb="$1" state="$2" n="${3:-}" remote base f
    remote="${sb}.remote.git"
    base="$sb/gh_fixtures/pr_view_$(printf '%s' "$remote" | tr '/' '_')_${PR}"
    if [[ -n "$n" ]]; then f="${base}.mergeable_${n}.json"; else f="${base}.mergeable.json"; fi
    printf '{"mergeable":"%s","mergeStateStatus":"%s"}\n' "$state" "$state" > "$f"
}
write_merge_fixture() {  # <sb> <exit_code> <stderr> <seq_n> -- drives the Nth `gh pr merge` call (#290)
    local sb="$1" rc="$2" err="$3" n="$4"
    printf '%s\n' "$rc" > "$sb/gh_fixtures/merge_exit_${n}"
    [[ -n "$err" ]] && printf '%s\n' "$err" > "$sb/gh_fixtures/merge_stderr_${n}"
    return 0
}
# A sandbox whose PR fixture's headRefOid is the REAL current SHA of the
# feature branch (not the fake constant $HEAD_SHA), so `git merge-base
# --is-ancestor` and `git diff` against it (Step 2's CI-target decision)
# are meaningful.
make_ci_sandbox() {  # <progress-body> [with_summary]
    local sb wt real_head remote comments body
    sb="$(make_sandbox "$1" "${2:-}")"
    wt="$(ci_wt "$sb")"
    real_head=$(git -C "$wt" rev-parse HEAD)
    remote="${sb}.remote.git"
    comments='[]'; body='"## Summary\n\nplain body"'
    [[ "${2:-}" == with_summary ]] && comments='[{"body":"## Decision summary\n\n**What changed**: x\n\n**Recommendation**: merge"}]'
    [[ "${2:-}" == body_summary ]] && body='"## Summary\n\nx\n\n## Decision summary\n\n**What changed**: in the body\n\n**Recommendation**: merge"'
    printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":%s,"body":%s}\n' "$real_head" "$comments" "$body" \
        > "$sb/gh_fixtures/pr_view_$(printf '%s' "$remote" | tr '/' '_')_${PR}.json"
    echo "$sb"
}
run_merge_wait() {  # <sb> [args...] -- no --no-wait; zero-sleep CI/mergeability env
    local sb="$1"; shift
    (cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" \
        GH_MERGE_EXIT="${GH_MERGE_EXIT:-0}" \
        MERGE_PR_CI_POLL_SECONDS=0 \
        MERGE_PR_CI_GRACE_SECONDS="${MERGE_PR_CI_GRACE_SECONDS:-5}" \
        MERGE_PR_CI_TIMEOUT_SECONDS="${MERGE_PR_CI_TIMEOUT_SECONDS:-5}" \
        "$sb/.agent/scripts/merge_pr.sh" --pr "$PR" --type workspace --no-roadmap-update --report-only "$@")
}

APPROVED_AT_HEAD="## Local Review
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)
**Verdict**: approved

**PR**: #70 at \`abc1234\`

### Findings
- [ ] No issues found. LGTM."
STALE="## Local Review
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)
**Verdict**: approved

**PR**: #70 at \`0000000\`

### Findings
- [ ] No issues found. LGTM."
CHANGES_REQUESTED="${APPROVED_AT_HEAD/approved/changes-requested}"
IR_OPEN="## Integrated Review
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)

**PR**: #70 at \`abc1234\`

### Findings
- [ ] (cross-confirmed) still open — \`x.sh\`"
IR_CLEAN="## Integrated Review
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)

**PR**: #70 at \`abc1234\`

### Findings
- [x] (must-fix) fixed — \`x.sh\`
- [ ] (suggestion) later — \`y.sh\`"

# ================================================= --report-only (the pre-#300 default) =====
echo "TEST: --report-only mode — every gap proceeds to the merge call, names why, records an entry"
run_case() {  # <label> <progress body> <with_summary|""> <expected reason fragment>
    local sb out rc=0
    sb="$(make_sandbox "$2" "$3")"
    out="$(run_merge "$sb" --report-only 2>&1)" || rc=$?
    if merged_called "$sb" && [[ "$out" == *"would have refused"*"$4"* ]] \
        && progress_of "$sb" | grep -q '^## Merge (report-only)$' \
        && progress_of "$sb" | grep -q "^\*\*PR\*\*: #70 at \`abc1234\`" \
        && progress_of "$sb" | grep -q "^\*\*Conditions\*\*: .*$4"; then
        pass "$1"
    else
        fail "$1 (rc=$rc merged=$(merged_called "$sb" && echo y || echo n) out=${out:0:300})"
    fi
}
run_case "(a) no progress.md at all"                     ""                   ""            "no progress.md for issue #7"
run_case "(a2) progress.md without any review entry"     "## Plan Authored
**Status**: complete
**When**: 2026-09-17 09:00 -04:00
**By**: t (m)
**Plan**: \`p.md\` at \`1111111\`" ""            "no ## Local Review"
run_case "(b) review at a stale SHA"                     "$STALE"             with_summary  "not the PR head"
run_case "(c) changes-requested at the head"             "$CHANGES_REQUESTED" with_summary  "not approved"
run_case "(d) approved at head, no decision summary"     "$APPROVED_AT_HEAD"  ""            "no \"## Decision summary\" heading in the PR body or a PR comment"
run_case "(d2) Integrated Review with an open cross-confirmed finding" "$IR_OPEN" with_summary "open must-fix/cross-confirmed"
# A partial or failed Integrated Review decided nothing (#309): no open
# must-fix of its own is not enough; condition (a) needs **Status**: complete.
IR_PARTIAL="${IR_CLEAN/\*\*Status\*\*: complete/**Status**: partial}"
IR_FAILED="${IR_CLEAN/\*\*Status\*\*: complete/**Status**: failed}"
run_case "(d3) partial Integrated Review with no open must-fix" "$IR_PARTIAL" with_summary "partial, not complete"
run_case "(d4) failed Integrated Review with no open must-fix"  "$IR_FAILED"  with_summary "failed, not complete"
# No **Status** line at all: refused, and named as <missing>.
IR_NO_STATUS="${IR_CLEAN/\*\*Status\*\*: complete
/}"
run_case "(d5) Integrated Review with no **Status** line" "$IR_NO_STATUS" with_summary "<missing>, not complete"
# Case and padding do not matter: " Complete " is complete.
sb="$(make_sandbox "${IR_CLEAN/\*\*Status\*\*: complete/**Status**:  Complete  }" with_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"Review gate: approved review at head"* && "$out" != *"not complete"* ]]; then
    pass "(e5) a mixed-case, padded **Status**: Complete passes like complete"
else
    fail "(e5) padded Complete (out=${out:0:300})"
fi
# record is pushed to origin (survives the worktree's later removal)
sb="$(make_sandbox "$STALE" with_summary)"; run_merge "$sb" --report-only >/dev/null 2>&1 || true
[[ "$(git -C "${sb}.remote.git" log -1 --format=%s feature/issue-7)" == "progress: merge (report-only) for #7" ]] \
    && pass "report-only record is committed by progress_append.sh and pushed to origin before the merge" || fail "record pushed (subj=$(git -C "${sb}.remote.git" log -1 --format=%s feature/issue-7))"
# all good: no line, no entry, merge reached
sb="$(make_sandbox "$APPROVED_AT_HEAD" with_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if merged_called "$sb" && [[ "$out" != *"would have refused"* ]] && [[ "$out" == *"Review gate: approved review at head"* ]] \
    && ! progress_of "$sb" | grep -q '^## Merge'; then
    pass "(e) approved at head + decision summary: passes, records nothing"
else
    fail "(e) all-good (out=${out:0:300})"
fi
sb="$(make_sandbox "$IR_CLEAN" with_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
[[ "$out" == *"Review gate: approved review at head"* ]] && pass "(e2) Integrated Review at head with only a suggestion open passes" || fail "(e2) IR clean (out=${out:0:300})"
# the decision summary in the PR BODY (where the template puts it) satisfies (b)
sb="$(make_sandbox "$APPROVED_AT_HEAD" body_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
[[ "$out" == *"Review gate: approved review at head"* ]] && pass "(e3) decision summary in the PR body (no comment) satisfies condition (b)" || fail "(e3) body summary (out=${out:0:300})"
# a legacy External Review at the head is honoured as Integrated Review's predecessor
EXT_CLEAN="${IR_CLEAN/Integrated Review/External Review}"
sb="$(make_sandbox "$EXT_CLEAN" with_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
[[ "$out" == *"Review gate: approved review at head"* ]] && pass "(e4) a legacy External Review at head with no open must-fix passes (ADR-0013 predecessor)" || fail "(e4) External Review (out=${out:0:300})"
# a malformed progress.md is named as such, not as "no review entry"
sb="$(make_sandbox $'## Implementation\n```\nunterminated' with_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
[[ "$out" == *"could not be parsed"* && "$out" != *"no ## Local Review"* ]] && pass "(f) a malformed progress.md is reported as malformed, not as missing" || fail "(f) malformed (out=${out:0:300})"
# push refused after the record commit: the commit is undone and ONE PR comment posted
sb="$(make_sandbox "$STALE" with_summary)"
rm -rf "${sb}.remote.git"; mkdir -p "${sb}.remote.git"   # origin gone -> push fails
before=$(git -C "$sb/worktrees/workspace/issue-workspace-7" rev-parse HEAD)
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$(git -C "$sb/worktrees/workspace/issue-workspace-7" rev-parse HEAD)" == "$before" ]] \
    && [[ -z "$(git -C "$sb/worktrees/workspace/issue-workspace-7" status --porcelain)" ]] \
    && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md" 2>/dev/null)" -eq 1 ]] \
    && [[ "$out" == *"could not be pushed"*"posted as a comment"* ]]; then
    pass "(g) push failure undoes the timeline commit and posts exactly one PR comment"
else
    fail "(g) push failure (out=${out:0:300})"
fi
# the PR comment carries the workspace signature (Authored-By + Model)
grep -q '^\*\*Model\*\*: `' "$sb/gh_fixtures/comments_posted.md" && grep -q '^\*\*Authored-By\*\*: `Test Agent`' "$sb/gh_fixtures/comments_posted.md" \
    && pass "(h) PR comment record carries the AI signature (Authored-By + Model)" || fail "(h) signature"

# ================================================= enforce is the default (#300) =====
echo "TEST: default mode (no flag) enforces on a workspace PR — a gap refuses, all-good merges, --report-only opts out"
sb="$(make_sandbox "$STALE" with_summary)"
rc=0; out="$(run_merge "$sb" 2>&1)" || rc=$?
if [[ "$rc" -ne 0 ]] && ! merged_called "$sb" && [[ "$out" == *"review gate refused"*"not the PR head"* ]] \
    && [[ "$out" == *"--report-only"* ]] && ! progress_of "$sb" | grep -q '^## Merge'; then
    pass "(def-1) no flag + a gate gap: refused (exit 1), no merge, no entry, --report-only named as the opt-out"
else
    fail "(def-1) (rc=$rc merged=$(merged_called "$sb" && echo y || echo n) out=${out:0:300})"
fi
sb="$(make_sandbox "$APPROVED_AT_HEAD" with_summary)"
rc=0; out="$(GH_MERGE_EXIT=0 run_merge "$sb" 2>&1)" || rc=$?
[[ "$rc" -eq 0 ]] && merged_called "$sb" && [[ "$out" == *"Review gate: approved review at head"* ]] \
    && pass "(def-2) no flag + all-good: merges (exit 0)" || fail "(def-2) (rc=$rc out=${out:0:300})"
sb="$(make_sandbox "$STALE" with_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"would have refused"* ]] && progress_of "$sb" | grep -q '^## Merge (report-only)$'; then
    pass "(def-3) --report-only on the same gap: proceeds with the would-have-refused line and a record"
else
    fail "(def-3) (out=${out:0:300})"
fi

# A workspace merge started from inside a package checkout (another
# repository, in a package worktree for an unrelated issue) gates exactly as
# from anywhere else: the records gate judges the gate's timeline by its own
# worktree, not by the directory the merge was started in (issue 429 round 2).
sb="$(make_sandbox "$APPROVED_AT_HEAD" with_summary)"
pkgwt="$sb/worktrees/project/demo/issue-demo-owner-pkg_a-901"
mkdir -p "$pkgwt/l1_ws/src"
git init --quiet -b feature/issue-901 "$pkgwt/l1_ws/src/pkg_a"
git -C "$pkgwt/l1_ws/src/pkg_a" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
printf '# project=demo issue=owner/pkg_a#901 layer=l1\n%s\tl1_ws/src/pkg_a\tfeature/issue-901\n' "$pkgwt" > "$pkgwt/.worktree-repos"
rc=0; out="$(cd "$pkgwt/l1_ws/src/pkg_a" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" GH_MERGE_EXIT=0 \
    GH_MERGEABLE_DEFAULT=MERGEABLE MERGE_PR_CI_POLL_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=5 \
    "$sb/.agent/scripts/merge_pr.sh" --pr "$PR" --type workspace --no-wait --no-roadmap-update 2>&1)" || rc=$?
[[ "$rc" -eq 0 ]] && merged_called "$sb" && [[ "$out" == *"Review gate: approved review at head"* && "$out" != *"records gate refused"* ]] \
    && pass "(def-pkg) all-good workspace merge started inside a package checkout: the gate reads the timeline and merges" \
    || fail "(def-pkg) (rc=$rc out=${out:0:400})"

# ================================================= --enforce, workspace =====
echo "TEST: --enforce on a workspace PR refuses every gap; passes the all-good fixture"
enforce_refuses() {  # <label> <progress> <with_summary|""> <reason fragment>
    local sb out rc=0
    sb="$(make_sandbox "$2" "$3")"
    out="$(run_merge "$sb" --enforce 2>&1)" || rc=$?
    if [[ "$rc" -ne 0 ]] && ! merged_called "$sb" && [[ "$out" == *"review gate refused"*"$4"* ]] \
        && [[ -d "$sb/worktrees/workspace/issue-workspace-7" ]] && ! progress_of "$sb" | grep -q '^## Merge'; then
        pass "$1"
    else
        fail "$1 (rc=$rc merged=$(merged_called "$sb" && echo y || echo n) out=${out:0:300})"
    fi
}
enforce_refuses "(a) no progress.md"                 "" "" "no progress.md for issue #7"
enforce_refuses "(b) stale SHA"                      "$STALE" with_summary "not the PR head"
enforce_refuses "(c) changes-requested"              "$CHANGES_REQUESTED" with_summary "not approved"
enforce_refuses "(d) no decision summary"            "$APPROVED_AT_HEAD" "" "Decision summary"
enforce_refuses "(d3) partial Integrated Review, no open must-fix" "$IR_PARTIAL" with_summary "**Status**: partial, not complete — a partial or failed triage decided nothing"
sb="$(make_sandbox "$APPROVED_AT_HEAD" body_summary)"
out="$(GH_MERGE_EXIT=0 run_merge "$sb" --enforce 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] && merged_called "$sb" && pass "(e-body) --enforce with the summary in the PR body merges" || fail "(e-body) (rc=$rc out=${out:0:200})"
sb="$(make_sandbox "$APPROVED_AT_HEAD" with_summary)"
out="$(GH_MERGE_EXIT=0 run_merge "$sb" --enforce 2>&1)"; rc=$?
[[ "$rc" -eq 0 ]] && merged_called "$sb" && pass "(e) --enforce with both conditions met merges (exit 0)" || fail "(e) enforce all-good (rc=$rc out=${out:0:300})"

# ================================================= --force-unreviewed =====
echo "TEST: --force-unreviewed bypasses with a banner and a Merge (unreviewed) record"
sb="$(make_sandbox "" "")"
out="$(run_merge "$sb" --enforce --force-unreviewed 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"--force-unreviewed: bypassing the review gate"* ]] \
    && progress_of "$sb" | grep -q '^## Merge (unreviewed)$' \
    && progress_of "$sb" | grep -q '^\*\*Mode\*\*: enforce, --force-unreviewed'; then
    pass "under --enforce (workspace): merge reached, banner printed, Merge (unreviewed) recorded"
else
    fail "force under enforce (out=${out:0:300})"
fi
sb="$(make_sandbox "" "")"
out="$(run_merge "$sb" --force-unreviewed 2>&1)" || true
if [[ "$out" == *"bypassing the review gate"* ]] && [[ "$out" != *"would have refused"* ]] \
    && progress_of "$sb" | grep -q '^## Merge (unreviewed)$' && ! progress_of "$sb" | grep -q '^## Merge (report-only)$'; then
    pass "under report-only: banner instead of the would-have-refused line; Merge (unreviewed) not (report-only)"
else
    fail "force under report-only (out=${out:0:300})"
fi

# ================================================= no open worktree =====
echo "TEST: no open worktree for the PR's repo — the record is posted as a PR comment"
sb="$(make_sandbox "" "")"
git -C "$sb" worktree remove --force "$sb/worktrees/workspace/issue-workspace-7" >/dev/null 2>&1
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"would have refused"* ]] && [[ "$out" == *"posted as a comment"* ]] \
    && grep -q '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md" 2>/dev/null \
    && grep -q '^\*\*Conditions\*\*: ' "$sb/gh_fixtures/comments_posted.md"; then
    pass "record posted as a PR comment with the same fields"
else
    fail "PR comment fallback (out=${out:0:300})"
fi

echo "TEST: with no timeline, the duplicate check compares with the newest record comment of either type"
# The same no-worktree sandbox: the PR's comments are the only store. The
# conditions A are the ones the run above posted. Each case sets the PR's
# comments, runs once, and says whether a new record comment was posted.
sb="$(make_sandbox "$STALE" with_summary)"
git -C "$sb" worktree remove --force "$sb/worktrees/workspace/issue-workspace-7" >/dev/null 2>&1
run_merge "$sb" --report-only >/dev/null 2>&1 || true
cond_a=$(grep -m1 '^\*\*Conditions\*\*: ' "$sb/gh_fixtures/comments_posted.md" | sed 's/^\*\*Conditions\*\*: //')
ws_fixture="$sb/gh_fixtures/pr_view_$(printf '%s' "${sb}.remote.git" | tr '/' '_')_${PR}.json"
rec_body() {  # <type> <conditions>
    printf '## %s\n**Status**: complete\n**When**: 2026-11-13 08:00 -05:00\n**By**: merge_pr.sh (t)\n\n**PR**: #%s at `abc1234`\n**Mode**: m\n**Scope**: workspace\n**Conditions**: %s\n\n---\n**Authored-By**: `t`\n' "$1" "$PR" "$2"
}
dedup_case() {  # <label> <flag> <expect: skips|records> <comment body>...
    local label="$1" flag="$2" expect="$3" b args='[]' out n
    shift 3
    args=$(jq -n '[{"body":"## Decision summary\n\n**What changed**: x"}]')
    for b in "$@"; do args=$(jq --arg b "$b" '. + [{"body": $b}]' <<<"$args"); done
    jq --argjson c "$args" '.comments = $c' "$ws_fixture" > "$ws_fixture.tmp" && mv "$ws_fixture.tmp" "$ws_fixture"
    : > "$sb/gh_fixtures/comments_posted.md"
    out="$(run_merge "$sb" "$flag" 2>&1)" || true
    n=$(grep -c '^## Merge (' "$sb/gh_fixtures/comments_posted.md")
    if [[ "$expect" == skips && "$n" -eq 0 && "$out" == *"already recorded (as a PR comment), same conditions"* ]] \
        || [[ "$expect" == records && "$n" -eq 1 && "$out" != *"already recorded"* ]]; then
        pass "(dedup-c $label) $expect"
    else
        fail "(dedup-c $label) expected $expect (posted=$n out=$(tail_of "$out" 500))"
    fi
}
if [[ -n "$cond_a" ]]; then
    dedup_case "unreviewed A, then report-only A; --force-unreviewed with A" --force-unreviewed records \
        "$(rec_body 'Merge (unreviewed)' "$cond_a")" "$(rec_body 'Merge (report-only)' "$cond_a")"
    dedup_case "report-only A, then unreviewed A; --report-only with A" --report-only records \
        "$(rec_body 'Merge (report-only)' "$cond_a")" "$(rec_body 'Merge (unreviewed)' "$cond_a")"
    dedup_case "last comment unreviewed A; --force-unreviewed with A" --force-unreviewed skips \
        "$(rec_body 'Merge (unreviewed)' "$cond_a")"
    dedup_case "last comment unreviewed with other conditions; --force-unreviewed with A" --force-unreviewed records \
        "$(rec_body 'Merge (unreviewed)' "something else")"
    dedup_case "last comment report-only A; --force-unreviewed with A" --force-unreviewed records \
        "$(rec_body 'Merge (report-only)' "$cond_a")"
    dedup_case "no record comment; --force-unreviewed" --force-unreviewed records
    dedup_case "unreviewed A, then a comment quoting a report-only heading mid-body; --force-unreviewed with A" --force-unreviewed skips \
        "$(rec_body 'Merge (unreviewed)' "$cond_a")" "A note quoting a record:
$(rec_body 'Merge (report-only)' "$cond_a")"
    dedup_case "report-only A with CRLF line ends; --report-only with A" --report-only skips \
        "$(rec_body 'Merge (report-only)' "$cond_a" | sed 's/$/\r/')"
    dedup_case "report-only A with trailing blanks after the conditions; --report-only with A" --report-only skips \
        "$(rec_body 'Merge (report-only)' "$cond_a  ")"
    dedup_case "report-only A, then a comment whose first line is the heading plus text; --report-only with A" --report-only skips \
        "$(rec_body 'Merge (report-only)' "$cond_a")" "$(rec_body 'Merge (report-only) — why we forced' "something else")"
    dedup_case "only a comment whose first line is the heading plus text, conditions A; --report-only with A" --report-only records \
        "$(rec_body 'Merge (report-only) — why we forced' "$cond_a")"
else
    fail "(dedup-c) could not read the conditions the calibration run posted"
fi

# ================================================= package worktree (issue 429 part 2) =====
# A package worktree: a container (no repository) nested inside the workspace
# checkout, holding the owning checkout A (pkg_a on feature/issue-901, the
# issue's timeline) and a sibling B (pkg_b on feature/pkg_b-issue-901). Each
# repository's "origin" is a local bare repository under a github-shaped path,
# so extract_gh_slug gives owner/pkg_a and owner/pkg_b.
# Usage: make_pkg_container <sb> <project> <progress-body|""> [base]
# Prints the container path. A second call for another project in the same
# sandbox makes its own clones (git refuses one branch in two worktrees of a
# repository), with the same remotes.
make_pkg_container() {
    local sb="$1" proj="$2" body="$3" base="${4:-}" r cont hdr
    mkdir -p "$sb/fake_remotes/github.com/owner" "$sb/origins_$proj"
    for r in pkg_a pkg_b; do
        if [[ ! -d "$sb/fake_remotes/github.com/owner/$r.git" ]]; then
            git init --bare --quiet "$sb/fake_remotes/github.com/owner/$r.git"
            git -C "$sb/fake_remotes/github.com/owner/$r.git" symbolic-ref HEAD refs/heads/main
        fi
        git init --quiet -b main "$sb/origins_$proj/$r"
        git -C "$sb/origins_$proj/$r" remote add origin "$sb/fake_remotes/github.com/owner/$r.git"
        if git -C "$sb/origins_$proj/$r" fetch --quiet origin main 2>/dev/null; then
            git -C "$sb/origins_$proj/$r" reset --quiet --hard origin/main
        else
            git -C "$sb/origins_$proj/$r" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
            git -C "$sb/origins_$proj/$r" push --quiet -u origin main
        fi
    done
    cont="$sb/worktrees/project/$proj/issue-$proj-owner-pkg_a-901"
    mkdir -p "$cont/l1_ws/src"
    git -C "$sb/origins_$proj/pkg_a" worktree add --quiet -B feature/issue-901 "$cont/l1_ws/src/pkg_a" main >/dev/null 2>&1
    git -C "$sb/origins_$proj/pkg_b" worktree add --quiet -B feature/pkg_b-issue-901 "$cont/l1_ws/src/pkg_b" main >/dev/null 2>&1
    hdr="# project=$proj issue=owner/pkg_a#901 layer=l1"
    [[ -n "$base" ]] && hdr="$hdr base=$base"
    printf '%s\n%s\tl1_ws/src/pkg_a\tfeature/issue-901\n%s\tl1_ws/src/pkg_b\tfeature/pkg_b-issue-901\n' \
        "$hdr" "$sb/origins_$proj/pkg_a" "$sb/origins_$proj/pkg_b" > "$cont/.worktree-repos"
    if [[ -n "$body" ]]; then
        mkdir -p "$cont/l1_ws/src/pkg_a/.agent/work-plans/issue-901"
        printf -- '---\nissue: 901\n---\n\n# Issue #901\n\n%s\n' "$body" > "$cont/l1_ws/src/pkg_a/.agent/work-plans/issue-901/progress.md"
        git -C "$cont/l1_ws/src/pkg_a" add -A
        git -C "$cont/l1_ws/src/pkg_a" -c user.name=t -c user.email=t@t commit --quiet -m "progress"
    fi
    git -C "$cont/l1_ws/src/pkg_a" push --quiet -f origin feature/issue-901 2>/dev/null
    git -C "$cont/l1_ws/src/pkg_b" push --quiet -f origin feature/pkg_b-issue-901 2>/dev/null
    echo "$cont"
}
# Usage: pkg_pr_fixture <sb> <repo> <branch> <with_summary|""> [baseRefName]
pkg_pr_fixture() {
    local comments='[]' base=""
    [[ "$4" == with_summary ]] && comments='[{"body":"## Decision summary\n\n**What changed**: x\n\n**Recommendation**: merge"}]'
    [[ -n "${5:-}" ]] && base=",\"baseRefName\":\"$5\""
    printf '{"state":"OPEN","headRefName":"%s","title":"Pkg PR","headRefOid":"%s","comments":%s,"body":""%s}\n' \
        "$3" "$HEAD_SHA" "$comments" "$base" > "$1/gh_fixtures/pr_view_owner_${2}_901.json"
}
run_pkg_merge() {  # <sb> <owner/repo#N> [args...]
    local sb="$1" ref="$2"; shift 2
    (cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" GH_MERGE_EXIT=1 \
        GH_MERGEABLE_DEFAULT=MERGEABLE MERGE_PR_CI_POLL_SECONDS=0 \
        "$sb/.agent/scripts/merge_pr.sh" --pr "$ref" --no-wait --no-roadmap-update "$@" 2>&1)
}
pkg_progress() { cat "$1/l1_ws/src/pkg_a/.agent/work-plans/issue-901/progress.md" 2>/dev/null; }
# The gh stub writes posted comments to comments_posted.md; GitHub would show
# them on the next `pr view`. Copy them into pkg_a#901's fixture.
pkg_comments_to_fixture() {  # <sb>
    local f="$1/gh_fixtures/pr_view_owner_pkg_a_901.json" tmp
    tmp=$(mktemp -p "$1")
    jq --rawfile c "$1/gh_fixtures/comments_posted.md" '.comments += [{"body": $c}]' "$f" > "$tmp" && mv "$tmp" "$f"
}

echo "TEST: an owning package PR with no timeline: the record lands in the owning checkout, nowhere else"
sb="$(make_sandbox "" "")"
cont="$(make_pkg_container "$sb" demo "")"
A="$cont/l1_ws/src/pkg_a"
pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
root_before=$(git -C "$sb" rev-parse HEAD); status_before=$(git -C "$sb" status --porcelain)
b_before=$(git -C "$cont/l1_ws/src/pkg_b" rev-parse HEAD)
out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
if [[ "$(git -C "$sb" rev-parse HEAD)" == "$root_before" ]] && [[ "$(git -C "$sb" status --porcelain | grep -v 'gh_calls.log\|comments_posted')" == "$(grep -v 'gh_calls.log\|comments_posted' <<< "$status_before")" ]] \
    && [[ ! -e "$sb/.agent/work-plans" ]] && [[ ! -e "$cont/.agent" ]] \
    && [[ "$(git -C "$cont/l1_ws/src/pkg_b" rev-parse HEAD)" == "$b_before" ]] && [[ ! -e "$cont/l1_ws/src/pkg_b/.agent" ]] \
    && [[ "$out" == *"report-only: gate enforcement applies to workspace PRs only"* ]] \
    && [[ "$out" == *"no progress.md for issue #901 in an open worktree (looked for $A)"* ]] \
    && [[ "$out" == *"Merge (report-only) entry recorded in $A/.agent/work-plans/issue-901/progress.md and pushed"* ]] \
    && pkg_progress "$cont" | grep -q '^## Merge (report-only)$' \
    && [[ "$(git -C "$A" rev-parse HEAD)" == "$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)" ]] \
    && git -C "$A" log -1 --format=%s | grep -qi '^progress: merge (report-only) for #901' \
    && [[ ! -s "$sb/gh_fixtures/comments_posted.md" ]] && merged_called "$sb"; then
    pass "(pkg-1) owning PR, no progress.md: report-only, record committed and pushed in A; main tree, container and B untouched; no PR comment"
else
    fail "(pkg-1) owning PR, no progress.md (out=${out:0:600})"
fi

echo "TEST: an owning package PR reads its review in the owning checkout"
sb="$(make_sandbox "" "")"
cont="$(make_pkg_container "$sb" demo "$APPROVED_AT_HEAD")"
A="$cont/l1_ws/src/pkg_a"
pkg_pr_fixture "$sb" pkg_a feature/issue-901 with_summary
a_before=$(git -C "$A" rev-parse HEAD)
out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
if [[ "$out" == *"Review gate: approved review at head \`abc1234\`"* ]] && [[ "$out" != *"would have refused"* ]] \
    && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] && ! pkg_progress "$cont" | grep -q '^## Merge' \
    && [[ ! -s "$sb/gh_fixtures/comments_posted.md" ]]; then
    pass "(pkg-2) owning PR with an approved review at the head in A: the gate passes, nothing recorded"
else
    fail "(pkg-2) owning PR approved in A (out=${out:0:600})"
fi
sb="$(make_sandbox "" "")"
cont="$(make_pkg_container "$sb" demo "$STALE")"
A="$cont/l1_ws/src/pkg_a"
pkg_pr_fixture "$sb" pkg_a feature/issue-901 with_summary
out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
if [[ "$out" == *"latest Local Review entry is at \`0000000\`, not the PR head \`abc1234\` (review coverage could not be confirmed: \`0000000\` does not resolve to one commit in $A)"* ]] \
    && pkg_progress "$cont" | grep -q '^## Merge (report-only)$' && merged_called "$sb"; then
    pass "(pkg-3) owning PR with a stale review: the ancestry check runs in A, the record lands in A"
else
    fail "(pkg-3) owning PR stale in A (out=${out:0:600})"
fi
# A second run in the same situation records nothing new (idempotency reads A).
a_before=$(git -C "$A" rev-parse HEAD)
out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
if [[ "$out" == *"already recorded at"*"same conditions"* ]] && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] \
    && [[ "$(pkg_progress "$cont" | grep -c '^## Merge (report-only)$')" -eq 1 ]]; then
    pass "(pkg-4) a repeat run with the same conditions finds the record in A and adds none"
else
    fail "(pkg-4) repeat run (out=${out:0:600})"
fi

echo "TEST: a sibling repository's PR never reads or records in the owning checkout's timeline"
sb="$(make_sandbox "" "")"
cont="$(make_pkg_container "$sb" demo "$APPROVED_AT_HEAD")"
A="$cont/l1_ws/src/pkg_a"
pkg_pr_fixture "$sb" pkg_b feature/pkg_b-issue-901 with_summary
a_before=$(git -C "$A" rev-parse HEAD); a_remote_before=$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)
b_before=$(git -C "$cont/l1_ws/src/pkg_b" rev-parse HEAD)
out="$(run_pkg_merge "$sb" owner/pkg_b#901)" || true
if [[ "$out" == *"a sibling repository's pull request: this issue's records are in $A, and a sibling's gate is not read there"* ]] \
    && [[ "$out" != *"approved review at head"* ]] \
    && [[ "$out" == *"a sibling repository's pull request records on its own PR, not in the owning checkout's timeline — Merge (report-only) record posted as a comment on owner/pkg_b#901"* ]] \
    && grep -q '^pr comment 901 -R owner/pkg_b ' "$sb/gh_calls.log" \
    && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] && ! pkg_progress "$cont" | grep -q '^## Merge' \
    && [[ "$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)" == "$a_remote_before" ]] \
    && [[ "$(git -C "$cont/l1_ws/src/pkg_b" rev-parse HEAD)" == "$b_before" ]] && [[ ! -e "$cont/.agent" ]]; then
    pass "(pkg-5) sibling PR: A's approved review not used, A and its origin untouched, record posted on the sibling's PR"
else
    fail "(pkg-5) sibling PR (out=${out:0:600})"
fi
# A sibling in a worktree whose manifest has no owning entry says so.
sb="$(make_sandbox "" "")"
cont="$(make_pkg_container "$sb" demo "")"
sed -i '/\tfeature\/issue-901$/d' "$cont/.worktree-repos"
pkg_pr_fixture "$sb" pkg_b feature/pkg_b-issue-901 with_summary
out="$(run_pkg_merge "$sb" owner/pkg_b#901)" || true
if [[ "$out" == *"a sibling repository's pull request: package worktree $cont has no single checkout on feature/issue-901, so no timeline is read for it"* ]] \
    && grep -q '^pr comment 901 -R owner/pkg_b ' "$sb/gh_calls.log"; then
    pass "(pkg-6) sibling PR, no owning entry in the manifest: the reason says so, record on the sibling's PR"
else
    fail "(pkg-6) sibling PR, no owning entry (out=${out:0:600})"
fi

echo "TEST: --project picks the worktree, and the owning checkout read is that worktree's"
sb="$(make_sandbox "" "")"
# demo is made last, so its owning branch is the one on the shared origin
# and its record push in (pkg-9) is a fast-forward.
cont2="$(make_pkg_container "$sb" demo2 "$APPROVED_AT_HEAD")"
cont1="$(make_pkg_container "$sb" demo "$STALE")"
pkg_pr_fixture "$sb" pkg_a feature/issue-901 with_summary
c1_before=$(git -C "$cont1/l1_ws/src/pkg_a" rev-parse HEAD); c2_before=$(git -C "$cont2/l1_ws/src/pkg_a" rev-parse HEAD)
rc=0; out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || rc=$?
if [[ "$rc" -eq 2 ]] && [[ "$out" == *"worktreed under more than one project"* ]] && ! merged_called "$sb"; then
    pass "(pkg-7) the same owning branch in two projects without --project: refused, nothing merged"
else
    fail "(pkg-7) ambiguous (rc=$rc out=${out:0:400})"
fi
# Both projects share pkg_a's origin; the owning checkout's timeline is read
# only when it contains origin's copy of the branch, so each run below first
# makes origin's branch that project's.
git -C "$cont2/l1_ws/src/pkg_a" push -q -f origin feature/issue-901
out="$(run_pkg_merge "$sb" owner/pkg_a#901 --project demo2)" || true
if [[ "$out" == *"Review gate: approved review at head"* ]] \
    && [[ "$(git -C "$cont1/l1_ws/src/pkg_a" rev-parse HEAD)" == "$c1_before" ]] && [[ "$(git -C "$cont2/l1_ws/src/pkg_a" rev-parse HEAD)" == "$c2_before" ]]; then
    pass "(pkg-8) --project demo2: the gate reads demo2's owning checkout (approved), demo's stale one untouched"
else
    fail "(pkg-8) --project demo2 (out=${out:0:600})"
fi
: > "$sb/gh_calls.log"
git -C "$cont1/l1_ws/src/pkg_a" push -q -f origin feature/issue-901
out="$(run_pkg_merge "$sb" owner/pkg_a#901 --project demo)" || true
if [[ "$out" == *"does not resolve to one commit in $cont1/l1_ws/src/pkg_a"* ]] \
    && pkg_progress "$cont1" | grep -q '^## Merge (report-only)$' \
    && [[ "$(git -C "$cont2/l1_ws/src/pkg_a" rev-parse HEAD)" == "$c2_before" ]]; then
    pass "(pkg-9) --project demo: the gate reads and records in demo's owning checkout only"
else
    fail "(pkg-9) --project demo (out=${out:0:600})"
fi

echo "TEST: an owning package PR with --enforce stays report-only"
sb="$(make_sandbox "" "")"
cont="$(make_pkg_container "$sb" demo "$STALE")"
pkg_pr_fixture "$sb" pkg_a feature/issue-901 with_summary
rc=0; out="$(run_pkg_merge "$sb" owner/pkg_a#901 --enforce)" || rc=$?
if [[ "$out" == *"report-only: gate enforcement applies to workspace PRs only"* ]] && merged_called "$sb" \
    && pkg_progress "$cont" | grep -q '^## Merge (report-only)$'; then
    pass "(pkg-10) --enforce on a package PR: report-only, the merge is reached, the record lands in A"
else
    fail "(pkg-10) enforce on package (rc=$rc out=${out:0:600})"
fi

echo "TEST: an owning package PR whose record push is refused falls back to a PR comment, A left as it was"
sb="$(make_sandbox "" "")"
cont="$(make_pkg_container "$sb" demo "")"
A="$cont/l1_ws/src/pkg_a"
pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
a_before=$(git -C "$A" rev-parse HEAD)
printf '#!/bin/sh\necho "refused by hook" >&2\nexit 1\n' > "$sb/fake_remotes/github.com/owner/pkg_a.git/hooks/pre-receive"
chmod +x "$sb/fake_remotes/github.com/owner/pkg_a.git/hooks/pre-receive"
out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
if [[ "$out" == *"the timeline commit could not be pushed to origin (undone locally)"*"posted as a comment on owner/pkg_a#901"* ]] \
    && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] && [[ -z "$(git -C "$A" status --porcelain)" ]] \
    && grep -q '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md"; then
    pass "(pkg-11) owning PR, push refused: the commit in A is undone, the record goes on the PR"
else
    fail "(pkg-11) push refused (out=${out:0:600} status=$(git -C "$A" status --porcelain))"
fi
# The same with progress.md present before the record: it is put back as it was.
sb="$(make_sandbox "" "")"
cont="$(make_pkg_container "$sb" demo "$STALE")"
A="$cont/l1_ws/src/pkg_a"
pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
a_before=$(git -C "$A" rev-parse HEAD); p_before=$(pkg_progress "$cont")
printf '#!/bin/sh\necho "refused by hook" >&2\nexit 1\n' > "$sb/fake_remotes/github.com/owner/pkg_a.git/hooks/pre-receive"
chmod +x "$sb/fake_remotes/github.com/owner/pkg_a.git/hooks/pre-receive"
out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
if [[ "$out" == *"the timeline commit could not be pushed to origin (undone locally)"*"posted as a comment on owner/pkg_a#901"* ]] \
    && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] && [[ -z "$(git -C "$A" status --porcelain)" ]] \
    && [[ "$(pkg_progress "$cont")" == "$p_before" ]] \
    && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]]; then
    pass "(pkg-11b) owning PR with a timeline, push refused: the commit is undone, progress.md as it was, one PR comment"
else
    fail "(pkg-11b) push refused, timeline present (out=${out:0:600} status=$(git -C "$A" status --porcelain))"
fi

echo "TEST: a commit hook in the owning repository refuses the record: A is left as it was, the record goes on the PR once"
# progress.md absent before, then present before. The second run reads no
# leftover entry in A (there is none) and finds the record on the PR's
# comments (copied into the fixture, as GitHub would show it): no second
# comment.
for shape in absent present; do
    sb="$(make_sandbox "" "")"
    if [[ "$shape" == absent ]]; then cont="$(make_pkg_container "$sb" demo "")"; else cont="$(make_pkg_container "$sb" demo "$STALE")"; fi
    A="$cont/l1_ws/src/pkg_a"
    pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
    # A worktree's hooks are its repository's (origins_demo/pkg_a/.git/hooks).
    printf '#!/bin/sh\necho "commit refused by the package hook" >&2\nexit 1\n' > "$sb/origins_demo/pkg_a/.git/hooks/pre-commit"
    chmod +x "$sb/origins_demo/pkg_a/.git/hooks/pre-commit"
    a_before=$(git -C "$A" rev-parse HEAD); p_before=$(pkg_progress "$cont")
    a_remote_before=$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)
    want="the timeline commit in $A was refused (progress_append.sh exit 3: a git failure such as a commit hook), and the entry was taken back out — Merge (report-only) record posted as a comment on owner/pkg_a#901"
    ok=true; detail=""
    for run in 1 2; do
        out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
        detail="$detail run$run=$(tail_of "$out" 700) status=$(git -C "$A" status --porcelain)"
        if [[ "$run" -eq 1 ]]; then
            [[ "$out" == *"$want"* && "$out" != *"already recorded"* && "$out" != *"and pushed"* ]] || ok=false
            pkg_comments_to_fixture "$sb"
        else
            [[ "$out" == *"already recorded (as a PR comment), same conditions"* && "$out" != *"posted as a comment"* ]] || ok=false
        fi
        [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" && -z "$(git -C "$A" status --porcelain)" ]] || ok=false
        [[ "$(pkg_progress "$cont")" == "$p_before" ]] || ok=false
        [[ "$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)" == "$a_remote_before" ]] || ok=false
        [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]] || ok=false
    done
    if [[ "$shape" == absent && -e "$A/.agent" ]]; then ok=false; fi
    if [[ "$ok" == true ]]; then
        pass "(pkg-12 $shape) hook refuses the record commit, progress.md $shape before: A clean and as it was; one comment across two runs"
    else
        fail "(pkg-12 $shape) hook refuses the record commit ($detail)"
    fi
done

echo "TEST: an owning checkout off the PR's branch: its timeline is not read, the record goes on the PR once"
for shape in other-branch detached; do
    sb="$(make_sandbox "" "")"
    cont="$(make_pkg_container "$sb" demo "$STALE")"
    A="$cont/l1_ws/src/pkg_a"
    pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
    if [[ "$shape" == other-branch ]]; then
        git -C "$A" checkout -q -b feature/issue-901-old
        want="the owning checkout $A is on feature/issue-901-old, not feature/issue-901"
    else
        git -C "$A" checkout -q --detach
        want="the owning checkout $A has a detached HEAD, not feature/issue-901"
    fi
    a_before=$(git -C "$A" rev-parse HEAD); p_before=$(pkg_progress "$cont")
    a_remote_before=$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)
    out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    pkg_comments_to_fixture "$sb"
    out2="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    if [[ "$out" == *"would have refused — $want; its timeline is not read for issue #901"* ]] && [[ "$out" != *"does not resolve"* ]] \
        && [[ "$out" == *"$want; the record is not committed there — Merge (report-only) record posted as a comment on owner/pkg_a#901"* ]] && [[ "$out" != *"and pushed"* ]] \
        && [[ "$out2" == *"already recorded (as a PR comment), same conditions"* ]] && [[ "$out2" != *"posted as a comment"* ]] \
        && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] && [[ -z "$(git -C "$A" status --porcelain)" ]] \
        && [[ "$(pkg_progress "$cont")" == "$p_before" ]] \
        && [[ "$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)" == "$a_remote_before" ]] \
        && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]]; then
        pass "(pkg-13 $shape) owning checkout not on the PR's branch: no timeline read, no commit, nothing pushed; one comment across two runs, with a true reason"
    else
        fail "(pkg-13 $shape) owning checkout off the PR branch (out=$(tail_of "$out" 700) out2=$(tail_of "$out2" 400))"
    fi
done

echo "TEST: an owning PR's duplicate check compares with the newest record across the timeline and the PR's comments"
# Run 1, conditions X1 (no decision summary): the push is refused, so the
# record is a PR comment. Run 2, X2 (a summary added): committed in the
# timeline. Run 3, X1 again. The comment's **When** is then set against the
# timeline record's: older (the timeline is newest: X2, so run 3 records),
# equal or unreadable (doubt: run 3 records), newer (the comment is newest
# and matches X1: run 3 skips).
for variant in older tie unreadable newer; do
    sb="$(make_sandbox "" "")"
    cont="$(make_pkg_container "$sb" demo "$STALE")"
    A="$cont/l1_ws/src/pkg_a"
    pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
    F="$sb/gh_fixtures/pr_view_owner_pkg_a_901.json"
    hook="$sb/fake_remotes/github.com/owner/pkg_a.git/hooks/pre-receive"
    printf '#!/bin/sh\nexit 1\n' > "$hook"; chmod +x "$hook"
    out1="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    rm -f "$hook"
    pkg_comments_to_fixture "$sb"
    jq '.comments += [{"body":"## Decision summary\n\n**What changed**: x"}]' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    out2="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    t_when=$(python3 "$sb/.agent/scripts/progress_read.py" "$A/.agent/work-plans/issue-901/progress.md" --type "Merge (report-only)" | jq -r '.entries[-1].fields.When')
    case "$variant" in
        older) c_when=$(python3 -c 'import sys,datetime as d; t=d.datetime.strptime(sys.argv[1],"%Y-%m-%d %H:%M %z")-d.timedelta(hours=1); print(t.strftime("%Y-%m-%d %H:%M ")+t.strftime("%z")[:3]+":"+t.strftime("%z")[3:])' "$t_when") ;;
        newer) c_when=$(python3 -c 'import sys,datetime as d; t=d.datetime.strptime(sys.argv[1],"%Y-%m-%d %H:%M %z")+d.timedelta(hours=1); print(t.strftime("%Y-%m-%d %H:%M ")+t.strftime("%z")[:3]+":"+t.strftime("%z")[3:])' "$t_when") ;;
        tie) c_when="$t_when" ;;
        unreadable) c_when="soon" ;;
    esac
    jq --arg w "$c_when" '.comments |= map(select(.body | startswith("## Decision summary") | not)
        | if (.body | startswith("## Merge")) then .body |= sub("\\*\\*When\\*\\*: [^\n]*"; "**When**: " + $w) else . end)' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    head2=$(git -C "$A" rev-parse HEAD)
    out3="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    n_tl=$(pkg_progress "$cont" | grep -c '^## Merge (report-only)$')
    ok=true
    [[ "$out1" == *"could not be pushed to origin (undone locally) — Merge (report-only) record posted as a comment"* ]] || ok=false
    [[ "$out2" == *"entry recorded in $A/.agent/work-plans/issue-901/progress.md and pushed"* ]] || ok=false
    [[ "$(jq -r '.comments[] | select(.body | startswith("## Merge")) | .body' "$F" | grep -m1 '^\*\*When\*\*: ')" == "**When**: $c_when" ]] || ok=false
    if [[ "$variant" == newer ]]; then
        [[ "$out3" == *"already recorded (as a PR comment), same conditions"* && "$n_tl" -eq 1 && "$(git -C "$A" rev-parse HEAD)" == "$head2" ]] || ok=false
    else
        [[ "$out3" != *"already recorded"* && "$out3" == *"entry recorded in $A/.agent/work-plans/issue-901/progress.md and pushed"* && "$n_tl" -eq 2 ]] || ok=false
        if [[ "$variant" != older ]]; then [[ "$out3" == *"cannot be told apart — recording rather than skipping on doubt"* ]] || ok=false; fi
    fi
    if [[ "$ok" == true ]]; then
        pass "(pkg-18 $variant) X1 as a comment, X2 in the timeline, X1 again with the comment $variant: $( [[ "$variant" == newer ]] && echo 'the newest record matches, skipped' || echo 'recorded')"
    else
        fail "(pkg-18 $variant) (c_when=$c_when t_when=$t_when n_tl=$n_tl out1=$(tail_of "$out1" 300) out2=$(tail_of "$out2" 300) out3=$(tail_of "$out3" 600))"
    fi
done

echo "TEST: a stale approval in the owning checkout never passes: off the branch, or behind origin's branch"
# The PR branch: H (code), R1 (approved at H), R2 (changes-requested at H);
# origin and the PR head are at R2. A holds R1's timeline in four shapes.
# Only the last (on the branch, up to date) may read it.
pkg16_setup() {  # <sb> <cont>: prints "H R1 R2"
    local A="$2/l1_ws/src/pkg_a" h r1 r2 body
    echo code > "$A/code.txt"; git -C "$A" add code.txt
    git -C "$A" -c user.name=t -c user.email=t@t commit -q -m "code"
    h=$(git -C "$A" rev-parse HEAD)
    mkdir -p "$A/.agent/work-plans/issue-901"
    body="${APPROVED_AT_HEAD/abc1234/${h:0:7}}"
    printf -- '---\nissue: 901\n---\n\n# Issue #901\n\n%s\n' "$body" > "$A/.agent/work-plans/issue-901/progress.md"
    git -C "$A" add -A; git -C "$A" -c user.name=t -c user.email=t@t commit -q -m "progress: approved"
    r1=$(git -C "$A" rev-parse HEAD)
    printf '\n%s\n' "${body/approved/changes-requested}" >> "$A/.agent/work-plans/issue-901/progress.md"
    git -C "$A" -c user.name=t -c user.email=t@t commit -q -am "progress: changes requested"
    r2=$(git -C "$A" rev-parse HEAD)
    git -C "$A" push -q -f origin feature/issue-901
    printf '{"state":"OPEN","headRefName":"feature/issue-901","title":"Pkg PR","headRefOid":"%s","comments":[{"body":"## Decision summary\\n\\n**What changed**: x"}],"body":""}\n' "$r2" \
        > "$1/gh_fixtures/pr_view_owner_pkg_a_901.json"
    echo "$h $r1 $r2"
}
for shape in detached other-branch behind up-to-date-at-R1; do
    sb="$(make_sandbox "" "")"
    cont="$(make_pkg_container "$sb" demo "")"
    A="$cont/l1_ws/src/pkg_a"
    read -r h r1 r2 <<< "$(pkg16_setup "$sb" "$cont")"
    case "$shape" in
        detached) git -C "$A" checkout -q --detach "$r1"
            want="would have refused — the owning checkout $A has a detached HEAD, not feature/issue-901; its timeline is not read" ;;
        other-branch) git -C "$A" checkout -q -b feature/issue-901-local "$r1"
            want="would have refused — the owning checkout $A is on feature/issue-901-local, not feature/issue-901; its timeline is not read" ;;
        behind) git -C "$A" reset -q --hard "$r1"
            want="would have refused — the owning checkout $A does not contain origin's feature/issue-901 at ${r2:0:7} (local ${r1:0:7}); its timeline is not read" ;;
        up-to-date-at-R1)
            # Control: origin and the PR head also at R1. The approval at H
            # is the branch's newest review, and it passes.
            git -C "$A" reset -q --hard "$r1"
            git -C "$A" push -q -f origin feature/issue-901
            sed -i "s/$r2/$r1/" "$sb/gh_fixtures/pr_view_owner_pkg_a_901.json"
            want="Review gate: approved review at head" ;;
    esac
    out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    if [[ "$shape" == up-to-date-at-R1 ]]; then
        if [[ "$out" == *"$want"* && "$out" != *"would have refused"* ]]; then
            pass "(pkg-16 control) on the branch and up to date at R1: the approval is the branch's newest review, and passes"
        else
            fail "(pkg-16 control) (out=$(tail_of "$out" 700))"
        fi
    elif [[ "$out" == *"$want"* ]] && [[ "$out" != *"approved review at head"* ]] && [[ "$out" != *"covers head"* ]]; then
        pass "(pkg-16 $shape) A at R1 (approved), the PR branch at R2 (changes requested): no timeline read, no pass, the reason says why"
    else
        fail "(pkg-16 $shape) stale approval (out=$(tail_of "$out" 700))"
    fi
done

echo "TEST: a progress.md that is not a regular file is left exactly as found; the record goes on the PR"
for shape in dangling-symlink symlink-to-file directory; do
    sb="$(make_sandbox "" "")"
    cont="$(make_pkg_container "$sb" demo "")"
    A="$cont/l1_ws/src/pkg_a"
    pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
    mkdir -p "$A/.agent/work-plans/issue-901"
    P="$A/.agent/work-plans/issue-901/progress.md"
    case "$shape" in
        dangling-symlink) ln -s "$sb/nowhere/progress.md" "$P"; what="is a symlink" ;;
        symlink-to-file) printf 'keep me\n' > "$sb/elsewhere.md"; ln -s "$sb/elsewhere.md" "$P"; what="is a symlink" ;;
        directory) mkdir "$P"; printf 'x\n' > "$P/inner"; what="is not a regular file" ;;
    esac
    st_before=$(git -C "$A" status --porcelain=v1 --untracked-files=all | od -c)
    link_before=$(readlink "$P" 2>/dev/null || echo "-"); a_before=$(git -C "$A" rev-parse HEAD)
    out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    st_after=$(git -C "$A" status --porcelain=v1 --untracked-files=all | od -c)
    ok=true
    [[ "$st_after" == "$st_before" && "$(readlink "$P" 2>/dev/null || echo "-")" == "$link_before" && "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] || ok=false
    case "$shape" in
        dangling-symlink) [[ -L "$P" && ! -e "$P" ]] || ok=false ;;
        symlink-to-file) [[ -L "$P" && "$(cat "$sb/elsewhere.md")" == "keep me" ]] || ok=false ;;
        directory) [[ -d "$P" && "$(cat "$P/inner")" == "x" ]] || ok=false ;;
    esac
    [[ "$out" == *".agent/work-plans/issue-901/progress.md in $A $what, so the record is not written there (left as found) — Merge (report-only) record posted as a comment on owner/pkg_a#901"* ]] || ok=false
    [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]] || ok=false
    if [[ "$ok" == true ]]; then
        pass "(pkg-17 $shape) progress.md a $shape: status byte-identical, left as found, the record on the PR with a true reason"
    else
        fail "(pkg-17 $shape) (out=$(tail_of "$out" 700) status: $(diff <(echo "$st_before") <(echo "$st_after")))"
    fi
done

echo "TEST: an owning checkout that is gone or no longer a checkout never resolves to an enclosing repository"
# no-checkout: A's .git file is gone and the folder sits inside another
# repository (an enclosing repository at l1_ws, on the PR's branch, with
# pkg_a's origin), which the gate, the CI target and the record would
# otherwise use. A keeps an approved review at the head, which must not pass.
for shape in no-checkout missing; do
    sb="$(make_sandbox "" "")"
    cont="$(make_pkg_container "$sb" demo "$APPROVED_AT_HEAD")"
    A="$cont/l1_ws/src/pkg_a"
    pkg_pr_fixture "$sb" pkg_a feature/issue-901 with_summary
    if [[ "$shape" == no-checkout ]]; then
        rm -f "$A/.git"
        git -C "$cont/l1_ws" init -q -b feature/issue-901
        git -C "$cont/l1_ws" -c user.name=t -c user.email=t@t commit -q --allow-empty -m enclosing
        git -C "$cont/l1_ws" remote add origin "$sb/fake_remotes/github.com/owner/pkg_a.git"
        enc_before=$(git -C "$cont/l1_ws" for-each-ref --format='%(refname) %(objectname)'; git -C "$cont/l1_ws" rev-parse HEAD)
        want="the owning checkout $A is not a git checkout's top folder"
    else
        git -C "$sb/origins_demo/pkg_a" worktree remove --force "$A"
        enc_before=""
        want="the owning checkout $A does not exist"
    fi
    out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    enc_after=""
    [[ "$shape" == no-checkout ]] && enc_after=$(git -C "$cont/l1_ws" for-each-ref --format='%(refname) %(objectname)'; git -C "$cont/l1_ws" rev-parse HEAD)
    if [[ "$out" == *"would have refused — $want, so no timeline is read for issue #901"* ]] && [[ "$out" != *"approved review at head"* ]] \
        && [[ "$out" == *"$want — Merge (report-only) record posted as a comment on owner/pkg_a#901"* ]] \
        && [[ "$enc_after" == "$enc_before" ]] && [[ "$out" != *"CI target"* ]] \
        && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]]; then
        pass "(pkg-14 $shape) owning checkout $shape: no timeline read, no enclosing repository used, the record on the PR"
    else
        fail "(pkg-14 $shape) owning checkout $shape (out=${out:0:700} enclosing: $(diff <(echo "$enc_before") <(echo "$enc_after")))"
    fi
done

echo "TEST: the CI-target fetch in a narrowed owning clone still refreshes origin/<PR branch>"
sb="$(make_sandbox "" "")"
cont="$(make_pkg_container "$sb" demo "")"
A="$cont/l1_ws/src/pkg_a"
stale=$(git -C "$A" rev-parse origin/feature/issue-901)
git -C "$A" config remote.origin.fetch '+refs/heads/main:refs/remotes/origin/main'
git clone -q --branch feature/issue-901 "$sb/fake_remotes/github.com/owner/pkg_a.git" "$sb/other_a"
echo change > "$sb/other_a/code.txt"
git -C "$sb/other_a" add code.txt
git -C "$sb/other_a" -c user.name=t -c user.email=t@t commit -q -m "a code change pushed from elsewhere"
git -C "$sb/other_a" push -q origin feature/issue-901
newhead=$(git -C "$sb/other_a" rev-parse HEAD)
printf '{"state":"OPEN","headRefName":"feature/issue-901","title":"Pkg PR","headRefOid":"%s","comments":[],"body":""}\n' "$newhead" \
    > "$sb/gh_fixtures/pr_view_owner_pkg_a_901.json"
out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
# A is behind origin's branch now, so its timeline is not read (pkg-16);
# the repository still answers the CI target.
if [[ "$(git -C "$A" rev-parse origin/feature/issue-901)" == "$newhead" ]] \
    && [[ "$out" == *"does not contain origin's feature/issue-901 at ${newhead:0:7} (local ${stale:0:7})"* ]] \
    && [[ "$out" != *"CI target"*"${stale:0:7}"* ]] && [[ "$out" != *"CI target: new head"* ]]; then
    pass "(pkg-15) narrowed owning clone: origin/feature/issue-901 is refreshed to the PR head, the stale SHA is never the CI target"
else
    fail "(pkg-15) narrowed clone CI target (stale=${stale:0:7} new=${newhead:0:7} now=$(git -C "$A" rev-parse --short origin/feature/issue-901) out=$(tail_of "$out" 700))"
fi

echo "TEST: an owning checkout ahead of origin (unpushed commits): not read, nothing pushed, the record on the PR once"
# wip: the triage's input, an unpushed code commit on a stale timeline.
# Before the fix the record was committed on top and pushed, taking the WIP
# commit to origin's branch. approval: an unpushed commit that adds an
# approved review at the head; before the fix it was read and passed.
for shape in wip approval; do
    sb="$(make_sandbox "" "")"
    cont="$(make_pkg_container "$sb" demo "$STALE")"
    A="$cont/l1_ws/src/pkg_a"
    if [[ "$shape" == wip ]]; then
        pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
        echo "work in progress" > "$A/wip_code.txt"
        git -C "$A" add wip_code.txt
        git -C "$A" -c user.name=t -c user.email=t@t commit -q -m "WIP: unpushed developer commit"
    else
        pkg_pr_fixture "$sb" pkg_a feature/issue-901 with_summary
        printf '\n%s\n' "$APPROVED_AT_HEAD" >> "$A/.agent/work-plans/issue-901/progress.md"
        git -C "$A" -c user.name=t -c user.email=t@t commit -q -am "progress: an approval not pushed"
    fi
    origin_tip=$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)
    a_before=$(git -C "$A" rev-parse HEAD); p_before=$(pkg_progress "$cont")
    want="the owning checkout $A has 1 commit not on origin's feature/issue-901 at ${origin_tip:0:7} (local ${a_before:0:7})"
    out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    pkg_comments_to_fixture "$sb"
    out2="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    ok=true
    [[ "$out" == *"would have refused — $want; its timeline is not read for issue #901"* ]] || ok=false
    [[ "$out" == *"$want; the record is not committed there — Merge (report-only) record posted as a comment on owner/pkg_a#901"* ]] || ok=false
    [[ "$out" != *"approved review at head"* && "$out" != *"and pushed"* ]] || ok=false
    [[ "$out2" == *"already recorded (as a PR comment), same conditions"* && "$out2" != *"posted as a comment"* ]] || ok=false
    [[ "$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)" == "$origin_tip" ]] || ok=false
    ! git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" merge-base --is-ancestor "$a_before" feature/issue-901 2>/dev/null || ok=false
    [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" && -z "$(git -C "$A" status --porcelain)" && "$(pkg_progress "$cont")" == "$p_before" ]] || ok=false
    [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]] || ok=false
    if [[ "$ok" == true ]]; then
        pass "(pkg-19 $shape) owning checkout one unpushed commit ahead: not read, origin's branch unchanged, the commit still local only; one comment across two runs, with a true reason"
    else
        fail "(pkg-19 $shape) ahead of origin (origin=$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse --short feature/issue-901) out=$(tail_of "$out" 900) out2=$(tail_of "$out2" 300))"
    fi
done
# Diverged (a local commit and a different one on origin): the neighbour of
# behind, with the same reason, and nothing pushed.
sb="$(make_sandbox "" "")"
cont="$(make_pkg_container "$sb" demo "$STALE")"
A="$cont/l1_ws/src/pkg_a"
pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
git clone -q --branch feature/issue-901 "$sb/fake_remotes/github.com/owner/pkg_a.git" "$sb/other_a"
echo there > "$sb/other_a/there.txt"; git -C "$sb/other_a" add there.txt
git -C "$sb/other_a" -c user.name=t -c user.email=t@t commit -q -m "pushed from elsewhere"
git -C "$sb/other_a" push -q origin feature/issue-901
echo here > "$A/here.txt"; git -C "$A" add here.txt
git -C "$A" -c user.name=t -c user.email=t@t commit -q -m "local only"
origin_tip=$(git -C "$sb/other_a" rev-parse HEAD); a_before=$(git -C "$A" rev-parse HEAD)
out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
if [[ "$out" == *"would have refused — the owning checkout $A does not contain origin's feature/issue-901 at ${origin_tip:0:7} (local ${a_before:0:7}); its timeline is not read"* ]] \
    && [[ "$out" != *"and pushed"* ]] && [[ "$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)" == "$origin_tip" ]] \
    && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] \
    && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]]; then
    pass "(pkg-19 diverged) owning checkout diverged from origin: not read, nothing pushed, the record on the PR"
else
    fail "(pkg-19 diverged) (out=$(tail_of "$out" 900))"
fi

echo "TEST: an owning checkout whose progress.md is not as committed: no record commit, the file left as found, the record on the PR"
# Before the fix the record commit took the uncommitted text with it and
# pushed it. clean and absent are pkg-3 and pkg-1 (committed and pushed).
for shape in unstaged staged staged-and-unstaged untracked deleted; do
    sb="$(make_sandbox "" "")"
    if [[ "$shape" == untracked ]]; then cont="$(make_pkg_container "$sb" demo "")"; else cont="$(make_pkg_container "$sb" demo "$STALE")"; fi
    A="$cont/l1_ws/src/pkg_a"
    P="$A/.agent/work-plans/issue-901/progress.md"
    pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
    note="DEV-UNCOMMITTED-NOTE"
    case "$shape" in
        unstaged) echo "$note" >> "$P"; what="has unstaged changes" ;;
        staged) echo "$note" >> "$P"; git -C "$A" add "$P"; what="has staged changes" ;;
        staged-and-unstaged) echo "$note" >> "$P"; git -C "$A" add "$P"; echo "$note 2" >> "$P"; what="has staged and unstaged changes" ;;
        untracked) mkdir -p "$(dirname "$P")"; printf -- '---\nissue: 901\n---\n\n%s\n\n%s\n' "$STALE" "$note" > "$P"; what="is untracked" ;;
        deleted) rm "$P"; what="has unstaged changes" ;;
    esac
    st_before=$(git -C "$A" status --porcelain=v1 --untracked-files=all | od -c)
    f_before=$(od -c "$P" 2>/dev/null || echo absent)
    a_before=$(git -C "$A" rev-parse HEAD)
    origin_tip=$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)
    out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    ok=true
    [[ "$out" == *".agent/work-plans/issue-901/progress.md in $A $what, so the record is not committed there (left as found) — Merge (report-only) record posted as a comment on owner/pkg_a#901"* ]] || ok=false
    [[ "$out" != *"and pushed"* ]] || ok=false
    [[ "$(git -C "$A" status --porcelain=v1 --untracked-files=all | od -c)" == "$st_before" ]] || ok=false
    [[ "$(od -c "$P" 2>/dev/null || echo absent)" == "$f_before" ]] || ok=false
    [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] || ok=false
    [[ "$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)" == "$origin_tip" ]] || ok=false
    ! git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" grep -q "$note" feature/issue-901 2>/dev/null || ok=false
    [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]] || ok=false
    if [[ "$ok" == true ]]; then
        pass "(pkg-20 $shape) progress.md $shape: nothing committed or pushed, status and file byte-identical, one comment with a true reason"
    else
        fail "(pkg-20 $shape) (out=$(tail_of "$out" 900) status now: $(git -C "$A" status --porcelain))"
    fi
done

echo "TEST: an owning PR's duplicate check: a CRLF record comment matches, a heading-plus-text comment is not a record"
# Run 1: the push is refused, so the record (conditions X) is a PR comment
# and the timeline has no record. The comments are then reshaped and run 2
# (push still refused) must find X as the newest record and post nothing.
for variant in crlf heading-plus-text; do
    sb="$(make_sandbox "" "")"
    cont="$(make_pkg_container "$sb" demo "$STALE")"
    pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
    F="$sb/gh_fixtures/pr_view_owner_pkg_a_901.json"
    hook="$sb/fake_remotes/github.com/owner/pkg_a.git/hooks/pre-receive"
    printf '#!/bin/sh\nexit 1\n' > "$hook"; chmod +x "$hook"
    out1="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    pkg_comments_to_fixture "$sb"
    if [[ "$variant" == crlf ]]; then
        jq '.comments |= map(.body |= gsub("\n"; "\r\n"))' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    else
        jq '.comments += [{"body": "## Merge (report-only) — why we forced\n**When**: 2099-01-01 00:00 +00:00\n**Conditions**: something else\n"}]' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    fi
    : > "$sb/gh_fixtures/comments_posted.md"
    out2="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    if [[ "$out1" == *"could not be pushed to origin (undone locally) — Merge (report-only) record posted as a comment"* ]] \
        && [[ "$out2" == *"already recorded (as a PR comment), same conditions"* ]] && [[ ! -s "$sb/gh_fixtures/comments_posted.md" ]]; then
        pass "(pkg-21 $variant) owning PR, record comment $variant: the real record is the newest and matches, nothing posted"
    else
        fail "(pkg-21 $variant) (out1=$(tail_of "$out1" 300) out2=$(tail_of "$out2" 600))"
    fi
done

echo "TEST: an origin that does not answer: the gate's fetch and the record push are ended by WT_FETCH_TIMEOUT"
# An ssh origin whose "ssh" blocks, as a passphrase or host-key prompt with
# no agent, or a stalled host, would. Only WT_FETCH_TIMEOUT (2s) can end
# it; the ceiling below is far above the limit and far below the block.
hang_shim() {  # <sb>: writes $sb/hang-ssh, which records its pid and blocks
    printf '#!/usr/bin/env bash\necho $$ >> "%s"\nexec sleep 300\n' "$1/hang-ssh.pids" > "$1/hang-ssh"
    chmod +x "$1/hang-ssh"
}
hang_reap() {  # <sb>: kills every blocked shim; prints "reached" and the pids still alive
    local p left=""
    [[ -s "$1/hang-ssh.pids" ]] || { echo "not-reached"; return; }
    while read -r p; do kill "$p" 2>/dev/null || true; done < "$1/hang-ssh.pids"
    sleep 0.2
    while read -r p; do kill -0 "$p" 2>/dev/null && left="$left $p"; done < "$1/hang-ssh.pids"
    echo "reached$left"
}
# A shim that serves an ssh origin from the local bare repository (the URL
# path is its absolute path), so a test can make only some calls block:
# HANG_MODE=applied: a push is applied, then the shim blocks (origin took
#   the record, then stalled); every other call is served.
# HANG_MODE=applied-ontop: as applied, and another commit lands on top of
#   the pushed branch before the shim blocks (a push by someone else).
# HANG_MODE=silent: a push blocks without applying, and every call after it
#   blocks too (origin cannot be asked about it).
serve_shim() {  # <sb>
    cat > "$1/serve-ssh" <<SHIM
#!/usr/bin/env bash
cmd="\${@: -1}"
pids="$1/hang-ssh.pids"; marker="$1/push-started"
case "\$cmd" in
    git-receive-pack*)
        if [ "\$HANG_MODE" = applied ] || [ "\$HANG_MODE" = applied-ontop ]; then
            sh -c "\$cmd"
            if [ "\$HANG_MODE" = applied-ontop ]; then
                bare="\$HANG_BARE"
                tip=\$(git --git-dir="\$bare" rev-parse "refs/heads/\$HANG_BRANCH")
                new=\$(GIT_AUTHOR_NAME=o GIT_AUTHOR_EMAIL=o@o GIT_COMMITTER_NAME=o GIT_COMMITTER_EMAIL=o@o \
                    git --git-dir="\$bare" commit-tree "\$tip^{tree}" -p "\$tip" -m "pushed on top")
                git --git-dir="\$bare" update-ref "refs/heads/\$HANG_BRANCH" "\$new"
            fi
        else
            : > "\$marker"
        fi
        echo \$\$ >> "\$pids"; exec sleep 300 ;;
    git-upload-pack*)
        if [ -e "\$marker" ]; then echo \$\$ >> "\$pids"; exec sleep 300; fi
        exec sh -c "\$cmd" ;;
    *) exit 1 ;;
esac
SHIM
    chmod +x "$1/serve-ssh"
}
if command -v timeout >/dev/null 2>&1; then
    # A review at R in A and the head R plus a progress.md commit, all in A
    # and on origin. With origin answering, A contains origin's branch, the
    # review covers the head and the gate passes (the control run below);
    # with origin silent, A cannot be shown to be current, and the gate
    # must not pass.
    sb="$(make_sandbox "" "")"
    cont="$(make_pkg_container "$sb" demo "")"
    A="$cont/l1_ws/src/pkg_a"
    r=$(git -C "$A" rev-parse --short HEAD)
    mkdir -p "$A/.agent/work-plans/issue-901"
    printf -- '---\nissue: 901\n---\n\n# Issue #901\n\n%s\n' "${APPROVED_AT_HEAD/abc1234/$r}" > "$A/.agent/work-plans/issue-901/progress.md"
    git -C "$A" add -A && git -C "$A" -c user.name=t -c user.email=t@t commit -q -m "progress: review"
    echo "bookkeeping" >> "$A/.agent/work-plans/issue-901/progress.md"
    git -C "$A" -c user.name=t -c user.email=t@t commit -q -am "progress: checkpoint"
    git -C "$A" push -q origin feature/issue-901
    newhead=$(git -C "$A" rev-parse HEAD)
    printf '{"state":"OPEN","headRefName":"feature/issue-901","title":"Pkg PR","headRefOid":"%s","comments":[{"body":"## Decision summary\\n\\n**What changed**: x"}],"body":""}\n' "$newhead" \
        > "$sb/gh_fixtures/pr_view_owner_pkg_a_901.json"
    hang_shim "$sb"
    git -C "$A" remote set-url origin "ssh://git@github.com/owner/pkg_a.git"
    a_before=$(git -C "$A" rev-parse HEAD); p_before=$(pkg_progress "$cont")
    started=$SECONDS
    out="$(GIT_SSH_COMMAND="$sb/hang-ssh" WT_FETCH_TIMEOUT=2 run_pkg_merge "$sb" owner/pkg_a#901)" || true
    elapsed=$((SECONDS - started))
    reap="$(hang_reap "$sb")"
    if [[ "$reap" == reached ]] && [[ "$elapsed" -lt 120 ]] \
        && [[ "$out" == *"would have refused — origin's feature/issue-901 could not be fetched in the owning checkout $A (timed out after 2s), so it is not known to be current; its timeline is not read for issue #901"* ]] \
        && [[ "$out" != *"approved review at head"* ]] \
        && [[ "$out" == *"; the record is not committed there — Merge (report-only) record posted as a comment on owner/pkg_a#901"* ]] \
        && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] && [[ -z "$(git -C "$A" status --porcelain)" ]] \
        && [[ "$(pkg_progress "$cont")" == "$p_before" ]]; then
        pass "(hang-1) origin silent at the gate's fetch: ended by the limit (${elapsed}s), a refusal reason not a pass; no commit in A, the record on the PR; no shim left"
    else
        fail "(hang-1) origin silent (reap=$reap elapsed=${elapsed}s out=$(tail_of "$out" 900))"
    fi
    # Control: the same fixture with origin answering passes the gate.
    git -C "$A" remote set-url origin "$sb/fake_remotes/github.com/owner/pkg_a.git"
    : > "$sb/gh_fixtures/comments_posted.md"
    out="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    if [[ "$out" == *"review at \`$r\` covers head \`${newhead:0:7}\`"* ]] && [[ "$out" == *"Review gate: approved review at head"* ]] \
        && [[ "$out" != *"would have refused"* ]]; then
        pass "(hang-1 control) the same fixture with origin answering: the gate passes, so the hang alone made the difference"
    else
        fail "(hang-1 control) (out=$(tail_of "$out" 700))"
    fi

    # Only the push is silent (pushurl): the fetches and the ls-remote
    # answer, origin does not have the record commit, and the push takes
    # the undo path.
    sb="$(make_sandbox "" "")"
    cont="$(make_pkg_container "$sb" demo "$STALE")"
    A="$cont/l1_ws/src/pkg_a"
    pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
    hang_shim "$sb"
    git -C "$A" config remote.origin.pushurl "ssh://git@github.com/owner/pkg_a.git"
    a_before=$(git -C "$A" rev-parse HEAD); p_before=$(pkg_progress "$cont")
    a_remote_before=$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)
    started=$SECONDS
    out="$(GIT_SSH_COMMAND="$sb/hang-ssh" WT_FETCH_TIMEOUT=2 run_pkg_merge "$sb" owner/pkg_a#901)" || true
    elapsed=$((SECONDS - started))
    reap="$(hang_reap "$sb")"
    if [[ "$reap" == reached ]] && [[ "$elapsed" -lt 120 ]] \
        && [[ "$out" == *"the timeline commit was not pushed: the push timed out after 2s and origin's feature/issue-901 does not contain it (undone locally) — Merge (report-only) record posted as a comment on owner/pkg_a#901"* ]] \
        && [[ "$out" != *"and pushed"* ]] \
        && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] && [[ -z "$(git -C "$A" status --porcelain)" ]] \
        && [[ "$(pkg_progress "$cont")" == "$p_before" ]] \
        && [[ "$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)" == "$a_remote_before" ]] \
        && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]]; then
        pass "(hang-2) the record push times out and origin answers without it (${elapsed}s): the commit is undone, progress.md as it was, one PR comment; no shim left"
    else
        fail "(hang-2) push times out (reap=$reap elapsed=${elapsed}s out=$(tail_of "$out" 700))"
    fi

    # Origin applies the push, then stalls: the fetch after the timeout
    # finds the record commit on origin's branch, so it is kept and reported
    # pushed, and no comment. ontop: another commit lands on top before the
    # check, so origin's tip is not the record commit but contains it.
    for mode in applied applied-ontop; do
        sb="$(make_sandbox "" "")"
        cont="$(make_pkg_container "$sb" demo "$STALE")"
        A="$cont/l1_ws/src/pkg_a"
        pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
        serve_shim "$sb"
        git -C "$A" remote set-url origin "ssh://git@github.com$sb/fake_remotes/github.com/owner/pkg_a.git"
        a_before=$(git -C "$A" rev-parse HEAD)
        started=$SECONDS
        out="$(GIT_SSH_COMMAND="$sb/serve-ssh" GIT_SSH_VARIANT=simple HANG_MODE=$mode HANG_BRANCH=feature/issue-901 HANG_BARE="$sb/fake_remotes/github.com/owner/pkg_a.git" WT_FETCH_TIMEOUT=2 run_pkg_merge "$sb" owner/pkg_a#901)" || true
        elapsed=$((SECONDS - started))
        reap="$(hang_reap "$sb")"
        tip=$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)
        rec=$(git -C "$A" rev-parse HEAD)
        tip_ok=false
        if [[ "$mode" == applied ]]; then [[ "$tip" == "$rec" ]] && tip_ok=true
        else [[ "$tip" != "$rec" && "$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse "$tip^")" == "$rec" ]] && tip_ok=true; fi
        if [[ "$reap" == reached ]] && [[ "$elapsed" -lt 120 ]] && [[ "$tip_ok" == true ]] \
            && [[ "$out" == *"Merge (report-only) entry recorded in $A/.agent/work-plans/issue-901/progress.md and pushed (the push timed out after 2s; origin's feature/issue-901 contains the record commit)"* ]] \
            && [[ "$(git -C "$A" rev-parse HEAD^)" == "$a_before" ]] && [[ -z "$(git -C "$A" status --porcelain)" ]] \
            && pkg_progress "$cont" | grep -q '^## Merge (report-only)$' && [[ ! -s "$sb/gh_fixtures/comments_posted.md" ]]; then
            pass "(hang-3 $mode) origin takes the record push, then stalls (${elapsed}s): its branch contains the commit, which is kept and reported pushed, no comment; no shim left"
        else
            fail "(hang-3 $mode) push applied then stalled (reap=$reap elapsed=${elapsed}s tip_ok=$tip_ok out=$(tail_of "$out" 700))"
        fi
    done

    # Origin stalls on the push and cannot be asked afterwards: whether it
    # took the commit is unknown, so it is undone in A and the record is
    # posted on the PR (a second copy if origin did take it), never left
    # only in a local commit. The next run, origin answering, finds the
    # record on the PR's comments, not in A's timeline, and adds none.
    sb="$(make_sandbox "" "")"
    cont="$(make_pkg_container "$sb" demo "$STALE")"
    A="$cont/l1_ws/src/pkg_a"
    pkg_pr_fixture "$sb" pkg_a feature/issue-901 ""
    serve_shim "$sb"
    git -C "$A" remote set-url origin "ssh://git@github.com$sb/fake_remotes/github.com/owner/pkg_a.git"
    a_before=$(git -C "$A" rev-parse HEAD); p_before=$(pkg_progress "$cont")
    a_remote_before=$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)
    started=$SECONDS
    out="$(GIT_SSH_COMMAND="$sb/serve-ssh" GIT_SSH_VARIANT=simple HANG_MODE=silent WT_FETCH_TIMEOUT=2 run_pkg_merge "$sb" owner/pkg_a#901)" || true
    elapsed=$((SECONDS - started))
    reap="$(hang_reap "$sb")"
    git -C "$A" remote set-url origin "$sb/fake_remotes/github.com/owner/pkg_a.git"
    pkg_comments_to_fixture "$sb"
    out2="$(run_pkg_merge "$sb" owner/pkg_a#901)" || true
    if [[ "$reap" == reached ]] && [[ "$elapsed" -lt 120 ]] \
        && [[ "$out" == *"the timeline commit was not known to be pushed: the push timed out after 2s and origin could not be asked afterwards (timed out after 2s) (undone locally); if origin took it, this comment is a second copy — Merge (report-only) record posted as a comment on owner/pkg_a#901"* ]] \
        && [[ "$out" != *"and pushed"* ]] && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] && [[ -z "$(git -C "$A" status --porcelain)" ]] \
        && [[ "$(pkg_progress "$cont")" == "$p_before" ]] \
        && [[ "$(git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" rev-parse feature/issue-901)" == "$a_remote_before" ]] \
        && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]] \
        && [[ "$out2" == *"already recorded (as a PR comment), same conditions"* ]] && [[ "$out2" != *"already recorded at"* ]] \
        && [[ "$(git -C "$A" rev-parse HEAD)" == "$a_before" ]] \
        && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]]; then
        pass "(hang-4) push stalls and origin cannot be asked (${elapsed}s): the commit is undone, the record posted on the PR and said so; the next run finds that comment, claims no timeline record, adds none; no shim left"
    else
        fail "(hang-4) push stalls, origin silent (reap=$reap elapsed=${elapsed}s out=$(tail_of "$out" 700) out2=$(tail_of "$out2" 500))"
    fi

    # The same outcome for a workspace PR under --report-only and
    # --force-unreviewed: the record commit in the PR's worktree is undone
    # and the record is posted on the PR, never left only in a local commit.
    for flag in --report-only --force-unreviewed; do
        sb="$(make_sandbox "$STALE" with_summary)"
        wt="$sb/worktrees/workspace/issue-workspace-7"
        bare="${sb}.remote.git"
        serve_shim "$sb"
        ssh_url="ssh://git@github.com$bare"
        git -C "$sb" remote set-url origin "$ssh_url"
        cp "$sb/gh_fixtures/pr_view_$(printf '%s' "$bare" | tr '/' '_')_${PR}.json" \
            "$sb/gh_fixtures/pr_view_$(printf '%s' "$ssh_url" | tr '/' '_')_${PR}.json"
        etype="Merge (report-only)"; [[ "$flag" == --force-unreviewed ]] && etype="Merge (unreviewed)"
        w_before=$(git -C "$wt" rev-parse HEAD); p_before=$(progress_of "$sb")
        o_before=$(git --git-dir="$bare" rev-parse feature/issue-7)
        started=$SECONDS
        out="$(GIT_SSH_COMMAND="$sb/serve-ssh" GIT_SSH_VARIANT=simple HANG_MODE=silent WT_FETCH_TIMEOUT=2 run_merge "$sb" "$flag" 2>&1)" || true
        elapsed=$((SECONDS - started))
        reap="$(hang_reap "$sb")"
        if [[ "$reap" == reached ]] && [[ "$elapsed" -lt 120 ]] \
            && [[ "$out" == *"the timeline commit was not known to be pushed: the push timed out after 2s and origin could not be asked afterwards (timed out after 2s) (undone locally); if origin took it, this comment is a second copy — $etype record posted as a comment"* ]] \
            && [[ "$(git -C "$wt" rev-parse HEAD)" == "$w_before" ]] && [[ -z "$(git -C "$wt" status --porcelain)" ]] \
            && [[ "$(progress_of "$sb")" == "$p_before" ]] && [[ "$(git --git-dir="$bare" rev-parse feature/issue-7)" == "$o_before" ]] \
            && [[ "$(grep -c "^## $etype\$" "$sb/gh_fixtures/comments_posted.md")" -eq 1 ]]; then
            pass "(hang-ws $flag) a workspace PR's record push stalls and origin cannot be asked (${elapsed}s): the commit is undone, the record posted on the PR; no shim left"
        else
            fail "(hang-ws $flag) (reap=$reap elapsed=${elapsed}s out=$(tail_of "$out" 900))"
        fi
    done
else
    echo "  SKIP: no timeout command (hang-1 to hang-4, hang-ws)"
fi

# ================================================= main tree on the PR branch =====
echo "TEST: the main tree checked out on the PR branch never receives the record commit"
sb="$(make_sandbox "$STALE" with_summary)"
git -C "$sb" worktree remove --force "$sb/worktrees/workspace/issue-workspace-7" >/dev/null 2>&1
git -C "$sb" checkout -q feature/issue-7      # the forbidden shape: feature branch in the main tree
root_before=$(git -C "$sb" rev-parse HEAD)
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$(git -C "$sb" rev-parse HEAD)" == "$root_before" ]] \
    && ! git -C "$sb" log -1 --format=%s | grep -q '^progress: merge' \
    && [[ "$out" == *"checked out in the main tree"*"posted as a comment"* ]] \
    && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md" 2>/dev/null)" -eq 1 ]]; then
    pass "main tree on the PR branch: no commit there, record posted as a PR comment"
else
    fail "main tree on PR branch (out=${out:0:400})"
fi

# ============================== enforce (the default), project scope =====
echo "TEST: a project PR stays report-only under the enforce default"
sb="$(make_sandbox "" "")"
# a legacy project/ checkout with its own remote and a PR fixture there
mkdir -p "$sb/fake_remotes/github.com/owner"
git init --bare --quiet "$sb/fake_remotes/github.com/owner/proj.git"; git -C "$sb/fake_remotes/github.com/owner/proj.git" symbolic-ref HEAD refs/heads/main
git -C "$sb" init --quiet -b main project >/dev/null 2>&1 || { mkdir -p "$sb/project"; git -C "$sb/project" init --quiet -b main; }
git -C "$sb/project" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
git -C "$sb/project" remote add origin "$sb/fake_remotes/github.com/owner/proj.git"
git -C "$sb/project" push --quiet -u origin main
printf '{"state":"OPEN","headRefName":"feature/issue-9","title":"Proj PR","headRefOid":"%s","comments":[]}\n' "$HEAD_SHA" \
    > "$sb/gh_fixtures/pr_view_$(printf '%s' "$sb/fake_remotes/github.com/owner/proj.git" | tr '/' '_')_9.json"
out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" GH_MERGE_EXIT=1 \
    GH_MERGEABLE_DEFAULT=MERGEABLE MERGE_PR_CI_POLL_SECONDS=0 \
    "$sb/.agent/scripts/merge_pr.sh" --pr 9 --type project --no-wait --no-roadmap-update 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"would have refused"* ]] && [[ "$out" == *"applies to workspace PRs only"* ]] && [[ "$out" != *"--enforce"* ]] \
    && [[ "$out" != *"review gate refused"* ]]; then
    pass "project scope under enforce: report-only line names the scoping rule, not a flag the caller may not have passed"
else
    fail "project scope enforce (out=${out:0:400})"
fi

# ============================== project registered outside project/ (#379) =====
# The case above cannot catch a gate that looks in the wrong place: it builds
# a legacy $sb/project checkout, so the registry-aware root and the hard-coded
# $ROOT_DIR/project are the same directory, and its PR has no timeline at all.
# Here nothing exists at $sb/project; the one project is registered at
# $sb/projects/proj_x, and the PR's timeline lives in that repo's worktree.
# Before #379 the gate looked in $sb/project, found no worktree and reported
# "no progress.md" in every scenario below.
make_registered_sandbox() {  # <with_summary|""> <worktree|main>
    local sb pj bare wt
    sb="$(make_sandbox "" "")"
    pj="$sb/projects/proj_x"
    mkdir -p "$sb/fake_remotes/github.com/owner"
    bare="$sb/fake_remotes/github.com/owner/proj_x.git"
    git init --bare --quiet "$bare"; git -C "$bare" symbolic-ref HEAD refs/heads/main
    mkdir -p "$pj"; git -C "$pj" init --quiet -b main
    git -C "$pj" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
    git -C "$pj" remote add origin "$bare"
    git -C "$pj" push --quiet -u origin main
    echo "proj_x single_project $pj" >> "$sb/.agent/projects.local"
    if [[ "$2" == main ]]; then
        # the forbidden shape: the PR branch checked out in the registered
        # project's main checkout
        wt="$pj"; git -C "$pj" checkout --quiet -b feature/issue-9
    else
        wt="$sb/worktrees/project/issue-proj_x-9"
        mkdir -p "$(dirname "$wt")"
        git -C "$pj" worktree add --quiet "$wt" -b feature/issue-9 >/dev/null 2>&1
    fi
    mkdir -p "$wt/.agent/work-plans/issue-9"
    printf -- '---\nissue: 9\n---\n\n# Issue #9\n\n%s\n' "${APPROVED_AT_HEAD/\#70/#9}" > "$wt/.agent/work-plans/issue-9/progress.md"
    git -C "$wt" add -A
    git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "progress"
    git -C "$wt" push --quiet -u origin feature/issue-9
    local comments='[]'
    [[ "$1" == with_summary ]] && comments='[{"body":"## Decision summary\n\n**What changed**: x\n\n**Recommendation**: merge"}]'
    printf '{"state":"OPEN","headRefName":"feature/issue-9","title":"Proj PR","headRefOid":"%s","comments":%s,"body":"plain body"}\n' "$HEAD_SHA" "$comments" \
        > "$sb/gh_fixtures/pr_view_$(printf '%s' "$bare" | tr '/' '_')_9.json"
    echo "$sb"
}
run_merge_registered() {  # <sb>
    (cd "$1" && PATH="$1/stubbin:$PATH" GH_FIXTURES_DIR="$1/gh_fixtures" GH_CALL_LOG="$1/gh_calls.log" GH_MERGE_EXIT=1 \
        GH_MERGEABLE_DEFAULT=MERGEABLE MERGE_PR_CI_POLL_SECONDS=0 \
        "$1/.agent/scripts/merge_pr.sh" --pr 9 --type project --no-wait --no-roadmap-update)
}
registered_progress() { cat "$1/worktrees/project/issue-proj_x-9/.agent/work-plans/issue-9/progress.md" 2>/dev/null; }

echo "TEST: a project registered outside project/ — the gate finds the PR's timeline in that repo's worktree (#379)"
sb="$(make_registered_sandbox with_summary worktree)"
out="$(run_merge_registered "$sb" 2>&1)" || true
if [[ "$out" == *"Review gate: approved review at head \`abc1234\` and a decision summary are present"* ]] \
    && [[ "$out" != *"no progress.md"* ]] && [[ "$out" != *"would have refused"* ]] \
    && merged_called "$sb" \
    && ! registered_progress "$sb" | grep -q '^## Merge' \
    && [[ ! -s "$sb/gh_fixtures/comments_posted.md" ]]; then
    pass "(reg-a) all good: covering review found, gate passes, no record written"
else
    fail "(reg-a) (merged=$(merged_called "$sb" && echo y || echo n) out=${out:0:500})"
fi

sb="$(make_registered_sandbox "" worktree)"
out="$(run_merge_registered "$sb" 2>&1)" || true
pushed="$(git -C "$sb/fake_remotes/github.com/owner/proj_x.git" show feature/issue-9:.agent/work-plans/issue-9/progress.md 2>/dev/null)"
if [[ "$out" == *"would have refused"*"no \"## Decision summary\" heading"* ]] && [[ "$out" != *"no progress.md"* ]] \
    && [[ "$out" == *"entry recorded in $sb/worktrees/project/issue-proj_x-9/"*"and pushed"* ]] \
    && registered_progress "$sb" | grep -q '^## Merge (report-only)$' \
    && grep -q '^## Merge (report-only)$' <<< "$pushed" \
    && merged_called "$sb" \
    && ! grep -q '^## Merge' "$sb/gh_fixtures/comments_posted.md" 2>/dev/null; then
    pass "(reg-b) missing decision summary: reason names it, record committed in the registered worktree's timeline and pushed, no PR comment"
else
    fail "(reg-b) (merged=$(merged_called "$sb" && echo y || echo n) out=${out:0:500})"
fi

sb="$(make_registered_sandbox "" main)"
pj_before=$(git -C "$sb/projects/proj_x" rev-parse HEAD)
out="$(run_merge_registered "$sb" 2>&1)" || true
# The CI-target line is the `_ci_is_main` guard's witness: with the registered
# main checkout taken as the PR's worktree, Step 2 fetches there, sees the
# real branch tip (not the fixture's head) and prints "CI target: new head".
if [[ "$(git -C "$sb/projects/proj_x" rev-parse HEAD)" == "$pj_before" ]] \
    && [[ "$out" == *"would have refused"*"no \"## Decision summary\" heading"* ]] \
    && [[ "$out" == *"checked out in the main tree"*"posted as a comment"* ]] \
    && [[ "$out" != *"CI target: new head"* ]] \
    && [[ "$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md" 2>/dev/null)" -eq 1 ]]; then
    pass "(reg-c) PR branch in the registered main checkout: no commit there, not used for the CI target, record posted as a PR comment"
else
    fail "(reg-c) (head_moved=$([[ "$(git -C "$sb/projects/proj_x" rev-parse HEAD)" == "$pj_before" ]] && echo n || echo y) out=${out:0:600})"
fi

# ================================================= idempotent record (issue #284) =====
echo "TEST: idempotent record — identical conditions across runs append no second entry; differing conditions do"
sb="$(make_sandbox "$CHANGES_REQUESTED" with_summary)"
run_merge "$sb" --report-only >/dev/null 2>&1 || true
before_sha=$(git -C "${sb}.remote.git" rev-parse feature/issue-7)
out2="$(run_merge "$sb" --report-only 2>&1)" || true
after_sha=$(git -C "${sb}.remote.git" rev-parse feature/issue-7)
count=$(progress_of "$sb" | grep -c '^## Merge (report-only)$')
if [[ "$count" -eq 1 ]] && [[ "$before_sha" == "$after_sha" ]] && [[ "$out2" == *"already recorded"*"same conditions"* ]]; then
    pass "(idem-1) identical conditions ('changes-requested') across runs: no second entry, nothing pushed"
else
    fail "(idem-1) (count=$count before=$before_sha after=$after_sha out=${out2:0:300})"
fi

sb="$(make_sandbox "$STALE" with_summary)"
run_merge "$sb" --report-only >/dev/null 2>&1 || true
# Simulate the underlying situation genuinely changing between runs (e.g. a
# fresh Local Review landed): append a SECOND Local Review entry with a
# different verdict directly to the worktree's progress.md (uncommitted is
# fine -- the gate reads file content, not git history). progress_read.py
# takes the LATEST Local Review entry, so this changes what the next run
# computes, independent of the fake constant $HEAD_SHA used by make_sandbox.
printf '\n%s\n' "$CHANGES_REQUESTED" >> "$sb/worktrees/workspace/issue-workspace-7/.agent/work-plans/issue-7/progress.md"
out2="$(run_merge "$sb" --report-only 2>&1)" || true
count=$(progress_of "$sb" | grep -c '^## Merge (report-only)$')
if [[ "$count" -eq 2 ]] && [[ "$out2" != *"already recorded"* ]]; then
    pass "(idem-2) differing conditions (a newer review entry changed the reason): a fresh entry is appended"
else
    fail "(idem-2) (count=$count out=${out2:0:300})"
fi

echo "TEST: idempotent record — the PR-comment fallback follows the same rule"
# The gh stub's `pr comment` doesn't feed posted comments back into the `pr
# view` fixture (no real GitHub round-trip), so this test constructs the
# existing-comment fixture directly: run once for real (to prove a comment
# does get posted), then drive the SECOND run's `_gate_already_recorded`
# PR-comment branch with a synthetic prior comment whose Conditions text is
# read back from what the first run actually computed.
sb="$(make_sandbox "" "")"
git -C "$sb" worktree remove --force "$sb/worktrees/workspace/issue-workspace-7" >/dev/null 2>&1
out1="$(run_merge "$sb" --report-only 2>&1)" || true
why1="${out1#*would have refused — }"; why1="${why1%%$'\n'*}"
count=$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md" 2>/dev/null || echo 0)
remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
old_comment_body="## Merge (report-only)
**Status**: complete
**When**: 2026-01-01 00:00 +00:00
**By**: merge_pr.sh (test)

**PR**: #70 at \`deadbee\`
**Mode**: report-only
**Scope**: workspace
**Conditions**: ${why1}"
comments_json=$(jq -n --arg a "$old_comment_body" '[{body:$a}]')
plain_body='"plain"'
printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":%s,"body":%s}\n' "$HEAD_SHA" "$comments_json" "$plain_body" \
    > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
out2="$(run_merge "$sb" --report-only 2>&1)" || true
count2=$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md" 2>/dev/null || echo 0)
if [[ "$count" -eq 1 ]] && [[ "$count2" -eq 1 ]] && [[ "$out2" == *"already recorded"* ]]; then
    pass "(idem-3) PR-comment fallback: an existing comment with identical conditions is not re-posted"
else
    fail "(idem-3) (count=$count count2=$count2 why1=$why1 out2=${out2:0:300})"
fi
# now the fixture also carries a real decision summary -- condition (b) is
# satisfied on the next run, so the freshly computed reasons differ from
# the existing comment's recorded Conditions
decision_comment_body='## Decision summary

**What changed**: x

**Recommendation**: merge'
comments_json2=$(jq -n --arg a "$old_comment_body" --arg b "$decision_comment_body" '[{body:$a},{body:$b}]')
printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":%s,"body":%s}\n' "$HEAD_SHA" "$comments_json2" "$plain_body" \
    > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
out3="$(run_merge "$sb" --report-only 2>&1)" || true
count3=$(grep -c '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md" 2>/dev/null || echo 0)
if [[ "$count3" -eq 2 ]] && [[ "$out3" != *"already recorded"* ]]; then
    pass "(idem-4) PR-comment fallback: differing conditions (a decision summary now exists) post a second comment"
else
    fail "(idem-4) (count3=$count3 out=${out3:0:300})"
fi

# ================================================= CI target / CI wait / mergeability (issue #284, fixes #271) =====
echo "TEST: CI target — Step 1.5's own progress.md push is exempt; check-runs targets the reviewed (pre-push) head"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 run_merge_wait "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"CI target: reviewed head \`${reviewed:0:7}\`"* ]] \
    && grep -qF "api repos//commits/${reviewed}/check-runs" "$sb/gh_calls.log"; then
    pass "(ci-1) progress-only diff: exempt, check-runs targets the reviewed head, merge proceeds"
else
    fail "(ci-1) (out=${out:0:400})"
fi

echo "TEST: CI target — a roadmap commit (Step 1) plus the progress.md commit (Step 1.5) are both exempt"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"
mkdir -p "$wt/docs"
printf -- '# Roadmap\n\n- [ ] Something (#7)\n' > "$wt/docs/ROADMAP.md"
git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "add roadmap"
git -C "$wt" push --quiet origin feature/issue-7
reviewed=$(git -C "$wt" rev-parse HEAD)
remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
comments='[{"body":"## Decision summary\n\n**What changed**: x\n\n**Recommendation**: merge"}]'
body='"## Summary\n\nplain body"'
printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":%s,"body":%s}\n' "$reviewed" "$comments" "$body" \
    > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
# Step 1's roadmap commit uses the ambient git identity (unlike Step 1.5,
# which goes through progress_append.sh and AGENT_NAME/AGENT_EMAIL), so
# supply one explicitly: CI runners have no user.name/user.email.
out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" GH_MERGE_EXIT=0 \
    MERGE_PR_CI_POLL_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=5 MERGE_PR_CI_TIMEOUT_SECONDS=5 \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
    "$sb/.agent/scripts/merge_pr.sh" --pr "$PR" --type workspace --report-only 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"Roadmap updated"* ]] && [[ "$out" == *"CI target: reviewed head \`${reviewed:0:7}\`"* ]] \
    && grep -qF "api repos//commits/${reviewed}/check-runs" "$sb/gh_calls.log"; then
    pass "(ci-2) roadmap + progress.md commits both exempt: check-runs still targets the reviewed head"
else
    fail "(ci-2) (out=${out:0:400})"
fi

echo "TEST: CI target — the same with the lowercase docs/roadmap.md spelling (#334)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"
mkdir -p "$wt/docs"
printf -- '# Roadmap\n\n- [ ] Something (#7)\n' > "$wt/docs/roadmap.md"
git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "add roadmap"
git -C "$wt" push --quiet origin feature/issue-7
reviewed=$(git -C "$wt" rev-parse HEAD)
remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
comments='[{"body":"## Decision summary\n\n**What changed**: x\n\n**Recommendation**: merge"}]'
body='"## Summary\n\nplain body"'
printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":%s,"body":%s}\n' "$reviewed" "$comments" "$body" \
    > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" GH_MERGE_EXIT=0 \
    MERGE_PR_CI_POLL_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=5 MERGE_PR_CI_TIMEOUT_SECONDS=5 \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
    "$sb/.agent/scripts/merge_pr.sh" --pr "$PR" --type workspace --report-only 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"Roadmap updated"* ]] && [[ "$out" == *"CI target: reviewed head \`${reviewed:0:7}\`"* ]] \
    && [[ "$out" == *"docs/roadmap.md: #7"* ]] && [[ "$out" == *"only touches bookkeeping: merge-time document files (work plans, roadmap) and paths this script committed itself (docs/roadmap.md,"* ]] \
    && grep -qF "api repos//commits/${reviewed}/check-runs" "$sb/gh_calls.log"; then
    pass "(ci-2b) lowercase docs/roadmap.md: updated, and its commit is exempt like the uppercase one"
else
    fail "(ci-2b) (out=${out:0:400})"
fi

echo "TEST: CI target — a head that also touches a path the script didn't commit voids the exemption"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"
reviewed=$(git -C "$wt" rev-parse HEAD)
echo "unrelated change" > "$wt/some_file.txt"
git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "unrelated change"
git -C "$wt" push --quiet origin feature/issue-7
out="$(MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
new_head=$(git -C "${sb}.remote.git" rev-parse feature/issue-7)
if [[ "$out" == *"CI target: new head \`${new_head:0:7}\`"*"touches \`some_file.txt\`"* ]] \
    && grep -qF "api repos//commits/${new_head}/check-runs" "$sb/gh_calls.log" \
    && ! grep -qF "api repos//commits/${reviewed}/check-runs" "$sb/gh_calls.log"; then
    pass "(ci-3) a committed path the script didn't write voids the exemption; check-runs targets the new head"
else
    fail "(ci-3) (reviewed=$reviewed new=$new_head out=${out:0:400})"
fi

echo "TEST: CI wait — check-runs empty for the first calls then green: merges (#271)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_workflows "$sb" '{"total_count":1}'
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_NONE" 1
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_NONE" 2
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_GRACE_SECONDS=5 run_merge_wait "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"CI checks passed"* ]]; then
    pass "(ci-4) check-runs empty for the first calls then green: merges once registered (#271)"
else
    fail "(ci-4) (out=${out:0:400})"
fi

echo "TEST: CI wait — CI configured but checks never register: grace-window error, no merge (distinct from no-CI)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_workflows "$sb" '{"total_count":1}'
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_NONE"
out="$(MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"no checks registered for"*"${reviewed:0:7}"* ]]; then
    pass "(ci-5) CI configured but checks never register: grace-window error, no merge"
else
    fail "(ci-5) (out=${out:0:400})"
fi

echo "TEST: CI wait — a failed check-run: error, no merge"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_FAILED"
out="$(run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"CI checks failed on"*"${reviewed:0:7}"* ]]; then
    pass "(ci-6) a failed check-run: error, no merge call"
else
    fail "(ci-6) (out=${out:0:400})"
fi

echo "TEST: CI wait — a startup_failure check-run: error, no merge (review round 1, must-fix 2)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_STARTUP_FAILURE"
out="$(run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"CI checks failed on"*"${reviewed:0:7}"* ]]; then
    pass "(ci-12) a startup_failure check-run: error, no merge call"
else
    fail "(ci-12) (out=${out:0:400})"
fi

echo "TEST: CI wait — a stale check-run: error, no merge (review round 2)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_STALE"
out="$(run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"CI checks failed on"*"${reviewed:0:7}"* ]]; then
    pass "(ci-12b) a stale check-run: error, no merge call"
else
    fail "(ci-12b) (out=${out:0:400})"
fi

echo "TEST: CI wait — Copilot review check-run failed but real CI green: merges, excluded run named as not blocking (#300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_PLUS_LINT_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 run_merge_wait "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"CI checks passed"* ]] \
    && [[ "$out" == *"check-run 'copilot-pull-request-reviewer' conclusion=failure"*"not used to block the merge"* ]] \
    && [[ "$out" != *"CI checks failed"* ]]; then
    pass "(ci-19) Copilot failure + Lint success: merges; excluded run reported as not blocking"
else
    fail "(ci-19) (out=${out:0:400})"
fi

echo "TEST: CI wait — Copilot review check-run failed, real CI still running: waits (times out), no false failure (#300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_PLUS_LINT_PENDING"
out="$(MERGE_PR_CI_TIMEOUT_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"CI checks did not complete on"*"${reviewed:0:7}"* ]] \
    && [[ "$out" != *"CI checks failed"* ]]; then
    pass "(ci-20) Copilot failure + Lint in_progress: pending until timeout, never a CI failure"
else
    fail "(ci-20) (out=${out:0:400})"
fi

echo "TEST: CI wait — Copilot failure alongside a genuine CI failure: still fails, culprit named (#300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_PLUS_LINT_FAILED"
out="$(run_merge_wait "$sb" 2>&1)" || true
# The copilot assertion is line-scoped (grep), not a whole-output glob: the
# excluded-run note is printed by the poll loop after the "CI failed:" line,
# so `*"CI failed:"*"copilot"*` would match across two unrelated lines.
if ! merged_called "$sb" && [[ "$out" == *"CI checks failed on"*"${reviewed:0:7}"* ]] \
    && [[ "$out" == *"CI failed: Lint (pre-commit) (failure)"* ]] \
    && ! grep -q "CI failed:.*copilot-pull-request-reviewer" <<<"$out"; then
    pass "(ci-21) Copilot failure + Lint failure: error, no merge; only the real failure is named"
else
    fail "(ci-21) (out=${out:0:400})"
fi

echo "TEST: CI wait — Copilot review check-run is the ONLY run: treated as no checks registered, no merge (#300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_workflows "$sb" '{"total_count":1}'
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_ONLY"
out="$(MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"no checks registered for"*"${reviewed:0:7}"* ]] \
    && [[ "$out" != *"CI checks passed"* ]]; then
    pass "(ci-22) Copilot-only head: never-registered error, not a false success"
else
    fail "(ci-22) (out=${out:0:400})"
fi

echo "TEST: CI wait — Copilot review check-run still running is the ONLY run: still no checks registered (#300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_workflows "$sb" '{"total_count":1}'
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_ONLY_RUNNING"
out="$(MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"no checks registered for"*"${reviewed:0:7}"* ]] \
    && [[ "$out" != *"CI checks did not complete"* ]] \
    && [[ "$out" == *"check-run 'copilot-pull-request-reviewer' status=in_progress"* ]]; then
    pass "(ci-23) Copilot-only head, conclusion null: never-registered (not pending/timeout); note reports status"
else
    fail "(ci-23) (out=${out:0:400})"
fi

echo "TEST: CI wait — the excluded-run note is printed once per run, not once per poll (#300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
# Poll 1 sees Lint pending (sequenced _1), poll 2+ falls back to the static
# green fixture — so the wait loop runs at least twice with the excluded
# Copilot run present in both.
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_PLUS_LINT_PENDING" 1
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_PLUS_LINT_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_GRACE_SECONDS=5 run_merge_wait "$sb" 2>&1)" || true
note_count=$(grep -c "check-run 'copilot-pull-request-reviewer'" <<<"$out" || true)
# Guard the guard: if only one poll ran, "exactly once" would pass vacuously.
poll_count=$(grep -c "check-runs" "$sb/gh_calls.log" 2>/dev/null || true)
if merged_called "$sb" && [[ "$out" == *"CI checks passed"* ]] \
    && [[ "$poll_count" -ge 2 ]] && [[ "$note_count" -eq 1 ]]; then
    pass "(ci-24) two poll iterations: excluded-run note printed exactly once"
else
    fail "(ci-24) (polls=${poll_count} note_count=${note_count}) (out=${out:0:400})"
fi

echo "TEST: CI wait — Copilot review still running, real CI green: holds the merge (owner rule, #300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_RUNNING_PLUS_LINT_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"review check-run 'copilot-pull-request-reviewer' still in progress on"*"${reviewed:0:7}"* ]] \
    && [[ "$out" == *"--allow-pending-review"* ]] \
    && [[ "$out" == *"review still in progress — waiting"* ]] \
    && [[ "$out" != *"CI checks passed"* ]] && [[ "$out" != *"CI checks failed"* ]]; then
    pass "(ci-25) Copilot running + Lint success: no merge; review-pending error names the opt-in flag"
else
    fail "(ci-25) (out=${out:0:400})"
fi

echo "TEST: CI wait — Copilot review still running, real CI green, --allow-pending-review: merges (#300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_RUNNING_PLUS_LINT_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 run_merge_wait "$sb" --allow-pending-review 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"CI checks passed"* ]] \
    && [[ "$out" == *"not used to block the merge"* ]] \
    && [[ "$out" != *"still in progress"* ]]; then
    pass "(ci-26) Copilot running + Lint success + --allow-pending-review: merges, opt-in honoured"
else
    fail "(ci-26) (out=${out:0:400})"
fi

echo "TEST: CI wait — Copilot review still running on a repo with no CI: still holds the merge (#300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_workflows "$sb" '{"total_count":0}'
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_ONLY_RUNNING"
out="$(MERGE_PR_CI_TIMEOUT_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"review check-run 'copilot-pull-request-reviewer' still in progress on"* ]] \
    && [[ "$out" != *"no CI configured"* ]]; then
    pass "(ci-27) Copilot running, no CI workflows: review-pending error, not a no-CI merge"
else
    fail "(ci-27) (out=${out:0:400})"
fi

echo "TEST: CI wait — Copilot review running then completed across polls: merges once it completes (#300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_RUNNING_PLUS_LINT_SUCCESS" 1
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_PLUS_LINT_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_GRACE_SECONDS=5 run_merge_wait "$sb" 2>&1)" || true
note_count=$(grep -c "check-run 'copilot-pull-request-reviewer'" <<<"$out" || true)
if merged_called "$sb" && [[ "$out" == *"CI checks passed"* ]] \
    && [[ "$out" == *"review still in progress — waiting"* ]] \
    && [[ "$out" == *"conclusion=failure is a review signal"* ]] \
    && [[ "$note_count" -eq 2 ]]; then
    pass "(ci-28) Copilot running then completed: waited, then merged; one note per state"
else
    fail "(ci-28) (note_count=${note_count}) (out=${out:0:400})"
fi

echo "TEST: CI wait — a re-triggered review (completed + running runs of the same name) still holds (#300 round 3)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_TWICE_PLUS_LINT_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"review check-run 'copilot-pull-request-reviewer' still in progress on"* ]] \
    && [[ "$out" != *"CI checks passed"* ]]; then
    pass "(ci-29) completed + running Copilot runs on one head: the running one still holds the merge"
else
    fail "(ci-29) (out=${out:0:400})"
fi

echo "TEST: CI target — a host-pushed progress-only commit after a green head reuses that head's verdict (#300 owner rule)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; green=$(git -C "$wt" rev-parse HEAD)
printf '\n## Checkpoint\n**Status**: complete\n**When**: 2026-09-22 12:00 -04:00\n**By**: t (m)\n**Decided-by**: owner\n**After**: merge\n**Decision**: merge\n\nok\n' >> "$wt/.agent/work-plans/issue-7/progress.md"
git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "progress: checkpoint"
git -C "$wt" push --quiet origin feature/issue-7
head_now=$(git -C "$wt" rev-parse HEAD)
remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":[{"body":"## Decision summary\\n\\n**What changed**: x\\n\\n**Recommendation**: merge"}],"body":"plain"}\n' "$head_now" \
    > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
write_workflows "$sb" '{"total_count":1}'
write_checkruns "$sb" "$head_now" "$CHECKRUNS_NONE"      # CI never registered on the bookkeeping tip
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"      # ...but the code head is green
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"CI target: \`${green:0:7}\`"*"bookkeeping commits"* ]] \
    && [[ "$out" == *"CI checks passed on \`${green:0:7}\`"* ]] \
    && grep -qF "api repos//commits/${green}/check-runs" "$sb/gh_calls.log"; then
    pass "(ci-30) progress-only commit after a green head: CI target walks back to the green head, merges"
else
    fail "(ci-30) (green=${green:0:7} head=${head_now:0:7} out=${out:0:500})"
fi

for roadmap_rel in docs/ROADMAP.md docs/roadmap.md; do
    echo "TEST: CI target — a host-pushed $roadmap_rel-only commit after a green head is bookkeeping (#334)"
    sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
    wt="$(ci_wt "$sb")"; green=$(git -C "$wt" rev-parse HEAD)
    mkdir -p "$wt/docs"; printf -- '# Roadmap\n\n- [x] Something (#7)\n' > "$wt/$roadmap_rel"
    git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "roadmap"
    git -C "$wt" push --quiet origin feature/issue-7
    head_now=$(git -C "$wt" rev-parse HEAD)
    remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
    printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":[{"body":"## Decision summary\\n\\n**What changed**: x\\n\\n**Recommendation**: merge"}],"body":"plain"}\n' "$head_now" \
        > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
    write_workflows "$sb" '{"total_count":1}'
    write_checkruns "$sb" "$head_now" "$CHECKRUNS_NONE"
    write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
    write_mergeable_fixture "$sb" "MERGEABLE"
    out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
    if merged_called "$sb" && [[ "$out" == *"CI target: \`${green:0:7}\`"*"bookkeeping commits"* ]] \
        && [[ "$out" == *"CI checks passed on \`${green:0:7}\`"* ]]; then
        pass "(ci-30 $roadmap_rel) roadmap-only commit after a green head: walks back to the green head, merges"
    else
        fail "(ci-30 $roadmap_rel) (green=${green:0:7} head=${head_now:0:7} out=${out:0:500})"
    fi
done

echo "TEST: CI target — a code commit after the green head is NOT walked over (#300)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; green=$(git -C "$wt" rev-parse HEAD)
echo "real change" > "$wt/some_file.sh"
git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "code change"
git -C "$wt" push --quiet origin feature/issue-7
head_now=$(git -C "$wt" rev-parse HEAD)
remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":[{"body":"## Decision summary\\n\\n**What changed**: x\\n\\n**Recommendation**: merge"}],"body":"plain"}\n' "$head_now" \
    > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
write_workflows "$sb" '{"total_count":1}'
write_checkruns "$sb" "$head_now" "$CHECKRUNS_NONE"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
out="$(MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"no checks registered for"*"${head_now:0:7}"* ]] \
    && [[ "$out" != *"bookkeeping commits"* ]]; then
    pass "(ci-31) code commit after the green head: no walk-back, waits on the new head (never-registered)"
else
    fail "(ci-31) (out=${out:0:500})"
fi

echo "TEST: CI target — a code file renamed into a work-plan dir after the green head is NOT walked over (#309)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"
echo "real code" > "$wt/moved.sh"
git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "code"
green=$(git -C "$wt" rev-parse HEAD)
mkdir -p "$wt/.agent/work-plans/issue-7"
git -C "$wt" mv moved.sh .agent/work-plans/issue-7/moved.sh
git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "move code into the plan dir"
git -C "$wt" push --quiet origin feature/issue-7
head_now=$(git -C "$wt" rev-parse HEAD)
remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":[{"body":"## Decision summary\\n\\n**What changed**: x\\n\\n**Recommendation**: merge"}],"body":"plain"}\n' "$head_now" \
    > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
write_workflows "$sb" '{"total_count":1}'
write_checkruns "$sb" "$head_now" "$CHECKRUNS_NONE"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
out="$(MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"no checks registered for"*"${head_now:0:7}"* ]] \
    && [[ "$out" != *"bookkeeping commits"* ]]; then
    pass "(ci-31b) code renamed into a work-plan dir: no walk-back, waits on the new head"
else
    fail "(ci-31b) (out=${out:0:500})"
fi

echo "TEST: CI target — a non-ASCII work-plan file after the green head is walked over (core.quotePath=true, #309)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; green=$(git -C "$wt" rev-parse HEAD)
mkdir -p "$wt/.agent/work-plans/issue-7/notes"
printf 'note\n' > "$wt/.agent/work-plans/issue-7/notes/café.md"
git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "plan(#7): note"
git -C "$wt" push --quiet origin feature/issue-7
head_now=$(git -C "$wt" rev-parse HEAD)
remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":[{"body":"## Decision summary\\n\\n**What changed**: x\\n\\n**Recommendation**: merge"}],"body":"plain"}\n' "$head_now" \
    > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
write_workflows "$sb" '{"total_count":1}'
write_checkruns "$sb" "$head_now" "$CHECKRUNS_NONE"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.quotePath GIT_CONFIG_VALUE_0=true \
    GH_MERGE_EXIT=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"CI target: \`${green:0:7}\`"*"bookkeeping commits"* ]] \
    && [[ "$out" == *"CI checks passed on \`${green:0:7}\`"* ]]; then
    pass "(ci-31d) non-ASCII work-plan file after a green head: walks back to the green head, merges"
else
    fail "(ci-31d) (green=${green:0:7} head=${head_now:0:7} out=${out:0:500})"
fi

echo "TEST: CI target — diff.ignoreSubmodules=all cannot hide a submodule bump after the green head (#309)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"
base_sha=$(git -C "$wt" rev-parse HEAD)
git -C "$wt" update-index --add --cacheinfo "160000,${base_sha},vendor/sub"
git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "add submodule"
green=$(git -C "$wt" rev-parse HEAD)
git -C "$wt" update-index --cacheinfo "160000,${green},vendor/sub"   # a different pointer
git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "bump submodule"
git -C "$wt" push --quiet origin feature/issue-7
head_now=$(git -C "$wt" rev-parse HEAD)
remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":[{"body":"## Decision summary\\n\\n**What changed**: x\\n\\n**Recommendation**: merge"}],"body":"plain"}\n' "$head_now" \
    > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
write_workflows "$sb" '{"total_count":1}'
write_checkruns "$sb" "$head_now" "$CHECKRUNS_NONE"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
out="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=diff.ignoreSubmodules GIT_CONFIG_VALUE_0=all \
    MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"no checks registered for"*"${head_now:0:7}"* ]] \
    && [[ "$out" != *"bookkeeping commits"* ]]; then
    pass "(ci-31c) submodule bump under diff.ignoreSubmodules=all: no walk-back, waits on the new head"
else
    fail "(ci-31c) (green=${green:0:7} head=${head_now:0:7} out=${out:0:500})"
fi

# make_walkback_sandbox: the ci-30 shape — a progress-only commit pushed on
# top of a green code head — with the caller free to set each head's
# check-runs. Prints "<sb> <green> <head_now>".
make_walkback_sandbox() {
    local sb wt green head_now remote_key
    sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
    wt="$(ci_wt "$sb")"; green=$(git -C "$wt" rev-parse HEAD)
    printf '\n## Checkpoint\n**Status**: complete\n**When**: 2026-09-22 12:00 -04:00\n**By**: t (m)\n**Decided-by**: owner\n**After**: merge\n**Decision**: merge\n\nok\n' >> "$wt/.agent/work-plans/issue-7/progress.md"
    git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "progress: checkpoint"
    git -C "$wt" push --quiet origin feature/issue-7
    head_now=$(git -C "$wt" rev-parse HEAD)
    remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
    printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":[{"body":"## Decision summary\\n\\n**What changed**: x\\n\\n**Recommendation**: merge"}],"body":"plain"}\n' "$head_now" \
        > "$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
    write_workflows "$sb" '{"total_count":1}'
    write_mergeable_fixture "$sb" "MERGEABLE"
    echo "$sb $green $head_now"
}

echo "TEST: CI target — the walk-back must not drop a review still running on the real head (#300 round 4)"
read -r sb green head_now <<<"$(make_walkback_sandbox)"
write_checkruns "$sb" "$head_now" "$CHECKRUNS_COPILOT_ONLY_RUNNING"  # review still running on the head
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"                  # code head green, no review run
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"CI target: \`${green:0:7}\`"*"bookkeeping commits"* ]] \
    && [[ "$out" == *"review check-run 'copilot-pull-request-reviewer' still in progress on"*"${head_now:0:7}"* ]] \
    && [[ "$out" == *"review still in progress — waiting"* ]]; then
    pass "(ci-32) walked-back CI target, review running on the head: holds the merge on the head's review"
else
    fail "(ci-32) (green=${green:0:7} head=${head_now:0:7} out=${out:0:500})"
fi

echo "TEST: CI target — the same shape with --allow-pending-review merges on the walked-back verdict (#300 round 4)"
read -r sb green head_now <<<"$(make_walkback_sandbox)"
write_checkruns "$sb" "$head_now" "$CHECKRUNS_COPILOT_ONLY_RUNNING"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" --allow-pending-review 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"CI checks passed on \`${green:0:7}\`"* ]] \
    && [[ "$out" != *"still in progress"* ]]; then
    pass "(ci-33) walked-back CI target + --allow-pending-review: merges on the green head's verdict"
else
    fail "(ci-33) (green=${green:0:7} head=${head_now:0:7} out=${out:0:500})"
fi

echo "TEST: CI target — a failed head re-read right after the walk-back keeps the hold (#300 round 5)"
read -r sb green head_now <<<"$(make_walkback_sandbox)"
# Call 1 on the head (the pre-switch poll) sees the review running; call 2 —
# the first re-read after the walk-back switched the target — fails; later
# calls recover. Without the pre-`continue` seed, call 2's error would leave
# the carry-over empty and the green target would merge past the review.
write_checkruns "$sb" "$head_now" "$CHECKRUNS_COPILOT_ONLY_RUNNING" 1
write_checkruns_exit "$sb" "$head_now" 1 2
write_checkruns "$sb" "$head_now" "$CHECKRUNS_COPILOT_ONLY_RUNNING"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
head_polls=$(grep -cF "api repos//commits/${head_now}/check-runs" "$sb/gh_calls.log" 2>/dev/null || true)
if ! merged_called "$sb" && [[ "$out" == *"review check-run 'copilot-pull-request-reviewer' still in progress on"*"${head_now:0:7}"* ]] \
    && [[ "$head_polls" -ge 2 ]] && [[ "$out" != *"CI checks passed"* ]]; then
    pass "(ci-34) head re-read fails on the first post-switch poll: the seeded carry-over still holds the merge"
else
    fail "(ci-34) (head_polls=${head_polls} green=${green:0:7} head=${head_now:0:7} out=${out:0:500})"
fi

# ============================== stale headRefOid: host bookkeeping after gh's head (#323) =====
# The PR 322 shape: gh's headRefOid still names the green code head (it has
# not caught up with the host's push), the host pushed a commit after it,
# and this run's Step 1.5 record commit lands on top. Step 2 compares gh's
# head with the real one, so the host's commit is in its diff although this
# run did not make it.
set_pr_head() {  # <sb> <sha> -- rewrite the PR fixture's headRefOid
    local remote_key
    remote_key="$(printf '%s' "${1}.remote.git" | tr '/' '_')"
    printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":[{"body":"## Decision summary\\n\\n**What changed**: x\\n\\n**Recommendation**: merge"}],"body":"plain"}\n' "$2" \
        > "$1/gh_fixtures/pr_view_${remote_key}_${PR}.json"
}
# make_stale_sandbox <kind>: the host's commit after the green head is
# roadmap (docs/roadmap.md), other-plan (another issue's work-plan dir),
# progress (this issue's progress.md), code, rename (code moved into a
# work-plan dir) or submodule (a submodule bump). gh's headRefOid stays
# at the green head. Prints "<sb> <green> <host>".
make_stale_sandbox() {
    local kind="$1" sb wt green base_sha
    sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
    wt="$(ci_wt "$sb")"
    case "$kind" in
        rename)
            echo "real code" > "$wt/moved.sh"
            git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "code" ;;
        submodule)
            base_sha=$(git -C "$wt" rev-parse HEAD)
            git -C "$wt" update-index --add --cacheinfo "160000,${base_sha},vendor/sub"
            git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "add submodule" ;;
    esac
    green=$(git -C "$wt" rev-parse HEAD)
    case "$kind" in
        roadmap)
            mkdir -p "$wt/docs"; printf -- '# Roadmap\n\n- [x] Something (#7)\n' > "$wt/docs/roadmap.md" ;;
        other-plan)
            mkdir -p "$wt/.agent/work-plans/issue-99"; printf 'other issue\n' > "$wt/.agent/work-plans/issue-99/progress.md" ;;
        progress)
            printf '\n## Checkpoint\n**Status**: complete\n**When**: 2026-09-22 12:00 -04:00\n**By**: t (m)\n**Decided-by**: owner\n**After**: merge\n**Decision**: merge\n\nok\n' >> "$wt/.agent/work-plans/issue-7/progress.md" ;;
        code)
            echo "real change" > "$wt/some_file.sh" ;;
        rename)
            mkdir -p "$wt/.agent/work-plans/issue-7"
            git -C "$wt" mv moved.sh .agent/work-plans/issue-7/moved.sh ;;
        submodule)
            git -C "$wt" update-index --cacheinfo "160000,${green},vendor/sub" ;;
    esac
    git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "host: $kind"
    git -C "$wt" push --quiet origin feature/issue-7
    # Every later push's new tip, so a test can name this run's own record
    # commit even after a merge deleted the branch on origin.
    # (A branch deletion pushes the all-zero SHA, which is skipped.)
    printf '#!/bin/bash\nwhile read -r _old new _ref; do case "$new" in *[1-9a-f]*) echo "$new" >> "%s/pushed_tips.log" ;; esac; done\n' "$sb" \
        > "${sb}.remote.git/hooks/post-receive"
    chmod +x "${sb}.remote.git/hooks/post-receive"
    set_pr_head "$sb" "$green"
    write_workflows "$sb" '{"total_count":1}'
    write_mergeable_fixture "$sb" "MERGEABLE"
    echo "$sb $green $(git -C "$wt" rev-parse HEAD)"
}
last_pushed_tip() { tail -n1 "$1/pushed_tips.log" 2>/dev/null; }  # <sb>
first_waited_sha() {  # <output> -- the SHA of the first "Waiting for CI on" line
    sed -n 's/^  Waiting for CI on `\([0-9a-f]*\)`.*/\1/p' <<<"$1" | head -n1
}

for kind in roadmap other-plan; do
    echo "TEST: CI target — stale headRefOid, a host $kind commit after gh's head: Step 2 targets the reviewed head at once (#323)"
    read -r sb green host <<<"$(make_stale_sandbox "$kind")"
    write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
    out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
    waited="$(first_waited_sha "$out")"
    if [[ "$out" == *"CI target: reviewed head \`${green:0:7}\` — new head"*"only touches bookkeeping: merge-time document files (work plans, roadmap)"* ]] \
        && [[ "$out" != *"which is not a merge-time document file"* ]] \
        && [[ "$waited" == "${green:0:7}" ]] && merged_called "$sb"; then
        pass "(ci-35 $kind) stale headRefOid + host $kind commit: CI target is the reviewed head, first wait on it, merges"
    else
        fail "(ci-35 $kind) (green=${green:0:7} host=${host:0:7} waited=${waited} lines: $(grep -E 'CI target|Waiting for CI' <<<"$out" | tr '\n' '|'))"
    fi
done

for kind in code rename submodule; do
    echo "TEST: CI target — stale headRefOid, a host $kind commit after gh's head: still targets the new head (#323)"
    read -r sb green host <<<"$(make_stale_sandbox "$kind")"
    write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
    out="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=diff.ignoreSubmodules GIT_CONFIG_VALUE_0=all \
        MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
    head_now=$(last_pushed_tip "$sb")
    if [[ -n "$head_now" && "$out" == *"CI target: new head \`${head_now:0:7}\` — touches"* ]] \
        && [[ "$(first_waited_sha "$out")" == "${head_now:0:7}" ]] && ! merged_called "$sb"; then
        pass "(ci-36 $kind) stale headRefOid + host $kind commit: not bookkeeping, waits on the new head, no merge"
    else
        fail "(ci-36 $kind) (green=${green:0:7} host=${host:0:7} head=${head_now:0:7} lines: $(grep -E 'CI target|Waiting for CI' <<<"$out" | tr '\n' '|'))"
    fi
done

echo "TEST: CI target — stale headRefOid, review running on the host's commit: the hold reads the host's commit, not the CI target (#323)"
read -r sb green host <<<"$(make_stale_sandbox progress)"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"                 # code head green, no review run
write_checkruns "$sb" "$host" "$CHECKRUNS_COPILOT_ONLY_RUNNING"      # review running on the host's commit
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
head_now=$(last_pushed_tip "$sb")
if ! merged_called "$sb" && [[ -n "$head_now" && "$head_now" != "$host" ]] \
    && [[ "$out" == *"CI target: reviewed head \`${green:0:7}\`"* ]] \
    && [[ "$out" == *"review check-run 'copilot-pull-request-reviewer' still in progress on"*"${host:0:7}"* ]] \
    && [[ "$out" == *"review still in progress — waiting"* ]]; then
    pass "(ci-37) stale headRefOid, review on the host's commit under this run's record commit: holds the merge"
else
    fail "(ci-37) (green=${green:0:7} host=${host:0:7} head=${head_now:0:7} lines: $(grep -E 'CI target|Waiting for CI|in progress|passed|Merg' <<<"$out" | tr '\n' '|'))"
fi

# The review SHA differs from the CI target here (stale headRefOid: CI on
# the green head, review on the host's commit under this run's record
# commit), so its check-runs are a read of their own. Until that read has
# succeeded once the hold is unresolved: a failed first read must never
# count as "no review running" (#323 review).
echo "TEST: review hold — the review SHA's first read fails once, its review finished: merges only after reading it (#323)"
read -r sb green host <<<"$(make_stale_sandbox progress)"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
write_checkruns "$sb" "$host" "$CHECKRUNS_COPILOT_ONLY"
write_checkruns_exit "$sb" "$host" 1 1                               # first read of the review SHA fails
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=10 MERGE_PR_CI_GRACE_SECONDS=10 run_merge_wait "$sb" 2>&1)" || true
reads=$(grep -cF "api repos//commits/${host}/check-runs" "$sb/gh_calls.log" 2>/dev/null || echo 0)
if merged_called "$sb" && [[ "$reads" -ge 2 ]] && [[ "$out" != *"still in progress"* ]]; then
    pass "(ci-41) a one-time failed read of the review SHA: re-read ($reads reads), then merges on its finished review"
else
    fail "(ci-41) (green=${green:0:7} host=${host:0:7} reads=$reads merged=$(merged_called "$sb" && echo yes || echo no) lines: $(grep -E 'CI target|Waiting for CI|in progress|passed|ERROR|Merg' <<<"$out" | tr '\n' '|'))"
fi

echo "TEST: review hold — the review SHA's first read fails once, its review still running: holds (#323)"
read -r sb green host <<<"$(make_stale_sandbox progress)"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
write_checkruns "$sb" "$host" "$CHECKRUNS_COPILOT_ONLY_RUNNING"
write_checkruns_exit "$sb" "$host" 1 1
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=2 MERGE_PR_CI_GRACE_SECONDS=2 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"review check-run 'copilot-pull-request-reviewer' still in progress on"*"${host:0:7}"* ]]; then
    pass "(ci-42) a one-time failed read, then a running review: the green CI target does not merge past it"
else
    fail "(ci-42) (green=${green:0:7} host=${host:0:7} lines: $(grep -E 'CI target|Waiting for CI|in progress|passed|ERROR|Merg' <<<"$out" | tr '\n' '|'))"
fi

echo "TEST: review hold — the review SHA's check-runs never read: refuses at the grace deadline (#323)"
read -r sb green host <<<"$(make_stale_sandbox progress)"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
write_checkruns_exit "$sb" "$host" 1                                 # every read fails
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=30 MERGE_PR_CI_GRACE_SECONDS=1 run_merge_wait "$sb" 2>&1)"; rc=$?
if ! merged_called "$sb" && [[ "$rc" -ne 0 ]] \
    && [[ "$out" == *"could not read the check-runs of \`${host:0:7}\`, the commit the review runs on, within 1s"* ]]; then
    pass "(ci-43) review SHA unreadable throughout: no merge, refusal at the grace deadline naming the review commit"
else
    fail "(ci-43) (rc=$rc green=${green:0:7} host=${host:0:7} lines: $(grep -E 'CI target|Waiting for CI|in progress|passed|ERROR|Merg' <<<"$out" | tr '\n' '|'))"
fi
echo "TEST: review hold — review SHA unreadable but --allow-pending-review: merges (#323)"
read -r sb green host <<<"$(make_stale_sandbox progress)"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
write_checkruns_exit "$sb" "$host" 1
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=30 MERGE_PR_CI_GRACE_SECONDS=1 run_merge_wait "$sb" --allow-pending-review 2>&1)" || true
if merged_called "$sb" && [[ "$out" != *"could not read the check-runs"* ]]; then
    pass "(ci-44) --allow-pending-review: an unreadable review state does not hold the merge"
else
    fail "(ci-44) (green=${green:0:7} host=${host:0:7} lines: $(grep -E 'CI target|in progress|passed|ERROR|Merg' <<<"$out" | tr '\n' '|'))"
fi

echo "TEST: CI target — a review re-triggered by this run's own record push does not hold the merge (#323)"
read -r sb green host <<<"$(make_stale_sandbox progress)"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
write_checkruns "$sb" "$host" "$CHECKRUNS_COPILOT_ONLY"             # the host commit's review finished
# This run's record commit (the new head) is never read for the hold: a
# review its own push re-triggers would otherwise hold every merge.
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
head_now=$(last_pushed_tip "$sb")
if merged_called "$sb" && [[ -n "$head_now" && "$head_now" != "$host" ]] && [[ "$out" != *"still in progress"* ]] \
    && ! grep -qF "api repos//commits/${head_now}/check-runs" "$sb/gh_calls.log"; then
    pass "(ci-38) the hold never reads this run's own record commit: merges on the reviewed head"
else
    fail "(ci-38) (green=${green:0:7} host=${host:0:7} head=${head_now:0:7} lines: $(grep -E 'CI target|Waiting for CI|in progress|passed' <<<"$out" | tr '\n' '|'))"
fi

echo "TEST: review hold — Step 1's roadmap commit whose own push failed is still this run's commit (#323)"
# Step 1's push is refused (once), so Step 1.5's push carries the roadmap
# commit to origin. Both are this run's commits: the hold walks over both
# and reads the reviewed head, where the review is still running.
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"
mkdir -p "$wt/docs"
printf -- '# Roadmap\n\n- [ ] Something (#7)\n' > "$wt/docs/roadmap.md"
git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "add roadmap"
git -C "$wt" push --quiet origin feature/issue-7
reviewed=$(git -C "$wt" rev-parse HEAD)
set_pr_head "$sb" "$reviewed"
printf '#!/bin/bash\n[ -f refused_once ] && exit 0\ntouch refused_once\necho "refusing the first push" >&2\nexit 1\n' > "${sb}.remote.git/hooks/pre-receive"
chmod +x "${sb}.remote.git/hooks/pre-receive"
write_workflows "$sb" '{"total_count":1}'
write_mergeable_fixture "$sb" "MERGEABLE"
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_COPILOT_RUNNING_PLUS_LINT_SUCCESS"
out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" GH_MERGE_EXIT=0 \
    MERGE_PR_CI_POLL_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
    "$sb/.agent/scripts/merge_pr.sh" --pr "$PR" --type workspace --report-only 2>&1)" || true
head_now=$(git -C "${sb}.remote.git" rev-parse feature/issue-7)
if ! merged_called "$sb" && [[ "$out" == *"Roadmap push failed"* ]] \
    && [[ "$(git -C "${sb}.remote.git" rev-list --count "${reviewed}..${head_now}")" -eq 2 ]] \
    && [[ "$out" == *"review check-run 'copilot-pull-request-reviewer' still in progress on"*"${reviewed:0:7}"* ]]; then
    pass "(ci-39) roadmap commit pushed by Step 1.5 after its own push failed: the hold still reads the reviewed head"
else
    fail "(ci-39) (reviewed=${reviewed:0:7} head=${head_now:0:7} lines: $(grep -E 'Roadmap|CI target|Waiting for CI|in progress|passed|Merg' <<<"$out" | tr '\n' '|'))"
fi

# A host push that lands on top of this run's record commit before Step 2's
# fetch: the remote's post-receive hook, on this run's push, adds a
# bookkeeping commit (another work-plan file) on top of it, as a host
# pushing at that moment would, and writes that commit's check-runs
# fixture (its SHA is known only then). The hold walks back only over this
# run's own commits, so it must stop at the host's commit, the head.
add_late_host_push() {  # <sb> <check-runs json for the host commit>
    local sb="$1" json="$2" hook="${1}.remote.git/hooks/post-receive"
    printf '%s' "$json" > "$sb/late_host_checkruns.json"
    cat > "$hook" <<EOF
#!/bin/bash
[ -f "$sb/late_host.sha" ] && exit 0
while read -r _old new ref; do
    [ "\$ref" = refs/heads/feature/issue-7 ] || continue
    export GIT_INDEX_FILE="$sb/late_host.index"
    git read-tree "\$new"
    blob=\$(printf 'host notes\n' | git hash-object -w --stdin)
    git update-index --add --cacheinfo "100644,\$blob,.agent/work-plans/issue-7/host-notes.md"
    tree=\$(git write-tree)
    rm -f "\$GIT_INDEX_FILE"
    late=\$(GIT_AUTHOR_NAME=host GIT_AUTHOR_EMAIL=h@h GIT_COMMITTER_NAME=host GIT_COMMITTER_EMAIL=h@h \
        git commit-tree "\$tree" -p "\$new" -m "host: notes after the record commit")
    git update-ref refs/heads/feature/issue-7 "\$late" "\$new"
    echo "\$new" > "$sb/late_record.sha"
    echo "\$late" > "$sb/late_host.sha"
    cp "$sb/late_host_checkruns.json" "$sb/gh_fixtures/api_repos__commits_\${late}_check-runs.json"
done
EOF
    chmod +x "$hook"
}

echo "TEST: review hold — a host push lands on top of this run's record commit before Step 2: the hold reads the host's commit (#323)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
green=$(git -C "$(ci_wt "$sb")" rev-parse HEAD)
write_workflows "$sb" '{"total_count":1}'
write_mergeable_fixture "$sb" "MERGEABLE"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
add_late_host_push "$sb" "$CHECKRUNS_COPILOT_ONLY_RUNNING"          # review running on the host's commit
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
late=$(cat "$sb/late_host.sha" 2>/dev/null); record=$(cat "$sb/late_record.sha" 2>/dev/null)
if [[ -n "$late" && -n "$record" ]] && ! merged_called "$sb" \
    && [[ "$(git -C "${sb}.remote.git" rev-parse "${late}^")" == "$record" ]] \
    && [[ "$(git -C "${sb}.remote.git" rev-parse "${record}^")" == "$green" ]] \
    && [[ "$out" == *"CI target: reviewed head \`${green:0:7}\` — new head \`${late:0:7}\` only touches bookkeeping"* ]] \
    && [[ "$out" == *"review check-run 'copilot-pull-request-reviewer' still in progress on"*"${late:0:7}"* ]] \
    && [[ "$out" == *"review still in progress — waiting"* ]]; then
    pass "(ci-40) host commit on top of this run's record commit: the hold reads the host's commit and holds the merge"
else
    fail "(ci-40) (green=${green:0:7} record=${record:0:7} late=${late:0:7} lines: $(grep -E 'CI target|Waiting for CI|in progress|passed|Merg' <<<"$out" | tr '\n' '|'))"
fi

echo "TEST: review hold — the same late host push with its review finished: merges, the hold read the host's commit (#323)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
green=$(git -C "$(ci_wt "$sb")" rev-parse HEAD)
write_workflows "$sb" '{"total_count":1}'
write_mergeable_fixture "$sb" "MERGEABLE"
write_checkruns "$sb" "$green" "$CHECKRUNS_SUCCESS"
add_late_host_push "$sb" "$CHECKRUNS_COPILOT_ONLY"                  # the host commit's review finished
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_TIMEOUT_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
late=$(cat "$sb/late_host.sha" 2>/dev/null); record=$(cat "$sb/late_record.sha" 2>/dev/null)
if [[ -n "$late" ]] && merged_called "$sb" && [[ "$out" != *"still in progress"* ]] \
    && grep -qF "api repos//commits/${late}/check-runs" "$sb/gh_calls.log" \
    && ! grep -qF "api repos//commits/${record}/check-runs" "$sb/gh_calls.log"; then
    pass "(ci-40b) late host commit's review finished: merges; the hold read the host's commit, never this run's record commit"
else
    fail "(ci-40b) (green=${green:0:7} record=${record:0:7} late=${late:0:7} lines: $(grep -E 'CI target|Waiting for CI|in progress|passed|Merg' <<<"$out" | tr '\n' '|'))"
fi

echo "TEST: mergeability — UNKNOWN for the first pr-view calls then MERGEABLE: merge proceeds"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_SUCCESS"
write_mergeable_fixture "$sb" "UNKNOWN" 1
write_mergeable_fixture "$sb" "UNKNOWN" 2
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_GRACE_SECONDS=5 run_merge_wait "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"mergeability: MERGEABLE"* ]]; then
    pass "(ci-7) mergeable UNKNOWN settles after a few polls: merge proceeds"
else
    fail "(ci-7) (out=${out:0:400})"
fi

echo "TEST: mergeability — UNKNOWN for the whole grace window: error, no merge"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_SUCCESS"
out="$(MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"mergeability for PR #${PR} never settled"* ]]; then
    pass "(ci-8) mergeable stays UNKNOWN for the whole grace window: error, no merge"
else
    fail "(ci-8) (out=${out:0:400})"
fi

# ---- --no-wait keeps the mergeability settle and the merge retry (#290) ----
echo "TEST: --no-wait still polls mergeability before merging (#290)"
sb="$(make_sandbox "$APPROVED_AT_HEAD" with_summary)"
write_mergeable_fixture "$sb" "UNKNOWN" 1
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 run_merge "$sb" --report-only 2>&1)" || true
mg_line=$(grep -n "mergeable,mergeStateStatus" "$sb/gh_calls.log" 2>/dev/null | head -1 | cut -d: -f1)
mr_line=$(grep -n "^pr merge" "$sb/gh_calls.log" 2>/dev/null | head -1 | cut -d: -f1)
# Two polls: the UNKNOWN answer was read and waited through, not skipped.
mg_polls=$(grep -c "mergeable,mergeStateStatus" "$sb/gh_calls.log" 2>/dev/null || true)
if [[ -n "$mg_line" && -n "$mr_line" && "$mg_line" -lt "$mr_line" ]] && [[ "$mg_polls" -ge 2 ]] && [[ "$out" == *"CI wait skipped (--no-wait)"* ]] && [[ "$out" == *"mergeability: MERGEABLE"* ]]; then
    pass "(nw-1) --no-wait: CI poll skipped, mergeability polled (UNKNOWN then MERGEABLE) before gh pr merge"
else
    fail "(nw-1) (mergeable-poll line=${mg_line:-none} polls=${mg_polls} merge line=${mr_line:-none} out=${out:0:300})"
fi

echo "TEST: --no-wait with mergeability UNKNOWN for the whole grace window: error, no merge (#290)"
sb="$(make_sandbox "$APPROVED_AT_HEAD" with_summary)"
out="$(GH_MERGE_EXIT=0 GH_MERGEABLE_DEFAULT=UNKNOWN MERGE_PR_CI_GRACE_SECONDS=0 run_merge "$sb" --report-only 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"mergeability for PR #${PR} never settled"* ]]; then
    pass "(nw-2) --no-wait: mergeability never settles -> error, no gh pr merge"
else
    fail "(nw-2) (out=${out:0:300})"
fi

echo "TEST: --no-wait with every mergeability poll failing to reach GitHub: lookup-failure error, no merge (#290)"
sb="$(make_sandbox "$APPROVED_AT_HEAD" with_summary)"
out="$(GH_MERGE_EXIT=0 GH_MERGEABLE_DEFAULT=FAIL MERGE_PR_CI_GRACE_SECONDS=0 run_merge "$sb" --report-only 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"could not reach GitHub"* ]] && [[ "$out" != *"still UNKNOWN"* ]]; then
    pass "(nw-2b) --no-wait: failed mergeability lookups -> error names the lookup failure, not UNKNOWN; no gh pr merge"
else
    fail "(nw-2b) (out=${out:0:300})"
fi

echo "TEST: --no-wait still retries once after a 'not mergeable' refusal (#290)"
sb="$(make_sandbox "$APPROVED_AT_HEAD" with_summary)"
write_merge_fixture "$sb" 1 "GraphQL: Pull Request is not mergeable (mergePullRequest)" 1
write_merge_fixture "$sb" 0 "" 2
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$(merge_count "$sb")" == "2" ]] && [[ "$out" == *"re-polling mergeability once and retrying"* ]] && [[ "$out" == *"PR merged"* ]]; then
    pass "(nw-3) --no-wait: first merge refused 'not mergeable', re-polled and retried once, merged"
else
    fail "(nw-3) (merges=$(merge_count "$sb") out=${out:0:300})"
fi

echo "TEST: mergeability — CONFLICTING settles to a distinct fail-fast error, not a merge attempt"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_SUCCESS"
write_mergeable_fixture "$sb" "CONFLICTING"
out="$(run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"merge conflicts"*"CONFLICTING"* ]]; then
    pass "(ci-13) mergeable CONFLICTING: clear error, no gh pr merge call"
else
    fail "(ci-13) (out=${out:0:400})"
fi

echo "TEST: CI wait — zero workflows and no runs: proceeds with a 'no CI configured' note (not a failure)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"
write_workflows "$sb" '{"total_count":0}'
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 run_merge_wait "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"no CI configured for"* ]]; then
    pass "(ci-9) zero workflows configured, nothing registered: proceeds, merges"
else
    fail "(ci-9) (out=${out:0:400})"
fi

echo "TEST: CI wait — registered but stuck pending: overall timeout error, no merge"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_PENDING"
out="$(MERGE_PR_CI_TIMEOUT_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"CI checks did not complete on"*"${reviewed:0:7}"* ]]; then
    pass "(ci-11) a check-run stuck pending forever: overall timeout error, no merge (distinct from never-registered)"
else
    fail "(ci-11) (out=${out:0:400})"
fi

echo "TEST: CI wait — gh api fails on every check-runs call: bounded retry, then a distinct hard error, no merge"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns_exit "$sb" "$reviewed" 1
out="$(MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"gh api failed repeatedly"*"${reviewed:0:7}"* ]]; then
    pass "(ci-14) gh api failing on every call: bounded retry then hard error, no merge (not folded into no-CI)"
else
    fail "(ci-14) (out=${out:0:400})"
fi

echo "TEST: CI wait — gh api fails on the first check-runs calls, then recovers: merges"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns_exit "$sb" "$reviewed" 1 1
write_checkruns_exit "$sb" "$reviewed" 1 2
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 MERGE_PR_CI_GRACE_SECONDS=5 run_merge_wait "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"CI checks passed"* ]]; then
    pass "(ci-15) gh api recovers after transient failures: merges once check-runs succeeds"
else
    fail "(ci-15) (out=${out:0:400})"
fi

echo "TEST: CI wait — the workflows-count call fails while check-runs stays empty: never-registered, not no-ci"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"; reviewed=$(git -C "$wt" rev-parse HEAD)
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_NONE"
write_workflows_exit "$sb" 1
out="$(MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
if ! merged_called "$sb" && [[ "$out" == *"no checks registered for"*"${reviewed:0:7}"* ]] && [[ "$out" != *"no CI configured"* ]]; then
    pass "(ci-16) workflows-count lookup fails: treated as unknown, waits and errors (never assumes zero workflows)"
else
    fail "(ci-16) (out=${out:0:400})"
fi

echo "TEST: CI wait — no local worktree for the PR's branch: targets HEAD_NOW directly and still waits/merges"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"
git -C "$sb" worktree remove --force "$wt" >/dev/null 2>&1
head_now=$(git -C "${sb}.remote.git" rev-parse feature/issue-7)
write_checkruns "$sb" "$head_now" "$CHECKRUNS_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(GH_MERGE_EXIT=0 run_merge_wait "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"CI checks passed on \`${head_now:0:7}\`"* ]] \
    && grep -qF "api repos//commits/${head_now}/check-runs" "$sb/gh_calls.log"; then
    pass "(ci-17) no local worktree: CI target falls back to HEAD_NOW (via gh), waits and merges correctly"
else
    fail "(ci-17) (head_now=$head_now out=${out:0:400})"
fi

echo "TEST: CI target — a concurrent force-push after this run's own push denies the exemption (ancestry check)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"
reviewed=$(git -C "$wt" rev-parse HEAD)
remote="${sb}.remote.git"
cat > "$remote/hooks/post-update" <<'HOOK'
#!/bin/bash
# Simulate a concurrent force-push landing right after our own push: once
# (guarded by a marker so a later `git fetch` in the same test doesn't
# re-trigger it), rewrite the branch ref to an unrelated commit.
marker=".concurrent_done"
[ -f "$marker" ] && exit 0
touch "$marker"
tree=4b825dc642cb6eb9a060e54bf8d69288fbee4904
sha=$(GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
    git --git-dir=. commit-tree "$tree" -m "concurrent push (unrelated history)")
git --git-dir=. update-ref refs/heads/feature/issue-7 "$sha"
HOOK
chmod +x "$remote/hooks/post-update"
out="$(MERGE_PR_CI_GRACE_SECONDS=0 run_merge_wait "$sb" 2>&1)" || true
new_head=$(git -C "$remote" rev-parse feature/issue-7)
if [[ "$new_head" != "$reviewed" ]] \
    && [[ "$out" == *"CI target: new head \`${new_head:0:7}\`"*"not an ancestor"* ]] \
    && grep -qF "api repos//commits/${new_head}/check-runs" "$sb/gh_calls.log"; then
    pass "(ci-10) a concurrent force-push after our own push denies the exemption; targets the new (non-descendant) head"
else
    fail "(ci-10) (reviewed=$reviewed new=$new_head out=${out:0:400})"
fi

echo "TEST: CI target — a same-tree commit (empty diff) after the reviewed head is exempt (#286)"
sb="$(make_ci_sandbox "$CHANGES_REQUESTED" with_summary)"
wt="$(ci_wt "$sb")"
reviewed=$(git -C "$wt" rev-parse HEAD)
git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m "empty"
git -C "$wt" push --quiet origin feature/issue-7
write_checkruns "$sb" "$reviewed" "$CHECKRUNS_SUCCESS"
write_mergeable_fixture "$sb" "MERGEABLE"
out="$(run_merge_wait "$sb" 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"CI target: reviewed head \`${reviewed:0:7}\`"* ]] \
    && grep -qF "api repos//commits/${reviewed}/check-runs" "$sb/gh_calls.log"; then
    pass "(ci-18) empty-diff head after the reviewed head: exempt, check-runs targets the reviewed head"
else
    fail "(ci-18) (out=${out:0:400})"
fi

# ============================== gate condition (a): ancestry (#286) =====
# A review entry is committed to progress.md on the branch, so the literal
# head is always one commit past the SHA the entry names. The gate must
# read "review at R" as current for head H when R is an ancestor of H and
# only merge-time document files changed between them.
#
# make_gate_sandbox <mode>: real two-commit history. Commit a code change
# (reviewed state R), then optionally an extra commit per <mode>, then the
# review entry citing R, and point the PR fixture at the resulting head H.
#   progress-only  R -> progress.md (the live failure shape)
#   code-after     R -> some_file.sh -> progress.md
#   roadmap-after  R -> docs/ROADMAP.md -> progress.md
#   roadmap-after-lower  R -> docs/roadmap.md -> progress.md (#334)
#   plan-after     R -> work-plans/issue-7/plan.md -> progress.md
#   other-issue-after    R -> work-plans/issue-70/progress.md -> progress.md
#   plan-nonascii-after  R -> work-plans/issue-7/notes/café.md -> progress.md (#309)
#   code-rawbytes-after  R -> bad-<0xff><CR><ESC>.sh (code) -> progress.md (#309)
#   rename-into-plan     R -> reviewed.sh moved into work-plans/issue-7/ -> progress.md
#   unrelated      review cites a commit on main that is not in H's history
make_gate_sandbox() {  # <mode>
    local mode="$1" sb wt r head remote comments body review
    sb="$(make_sandbox "" with_summary)"
    wt="$(ci_wt "$sb")"
    echo "reviewed code" > "$wt/reviewed.sh"
    git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "reviewed code"
    r=$(git -C "$wt" rev-parse HEAD)
    case "$mode" in
        code-after)
            echo "later code" > "$wt/some_file.sh"
            git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "later code" ;;
        roadmap-after)
            mkdir -p "$wt/docs"; printf -- '# Roadmap\n\n- [x] Something (#7)\n' > "$wt/docs/ROADMAP.md"
            git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "roadmap" ;;
        roadmap-after-lower)
            mkdir -p "$wt/docs"; printf -- '# Roadmap\n\n- [x] Something (#7)\n' > "$wt/docs/roadmap.md"
            git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "roadmap" ;;
        other-issue-after)
            mkdir -p "$wt/.agent/work-plans/issue-70"
            printf -- '# Issue #70\n' > "$wt/.agent/work-plans/issue-70/progress.md"
            git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "stray timeline" ;;
        plan-after)
            mkdir -p "$wt/.agent/work-plans/issue-7"
            printf -- '# Plan\n\n## Addendum 1\n\nowner rule\n' > "$wt/.agent/work-plans/issue-7/plan.md"
            git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "plan(#7): addendum" ;;
        code-rawbytes-after)
            # A code file named with an invalid UTF-8 byte, a CR and an ESC.
            printf 'code\n' > "$wt/bad-"$'\xff\r\e'".sh"
            git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "raw-byte name" ;;
        plan-nonascii-after)
            mkdir -p "$wt/.agent/work-plans/issue-7/notes"
            printf -- 'note\n' > "$wt/.agent/work-plans/issue-7/notes/café.md"
            git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "plan(#7): note" ;;
        rename-into-plan)
            mkdir -p "$wt/.agent/work-plans/issue-7"
            git -C "$wt" mv reviewed.sh .agent/work-plans/issue-7/reviewed.sh
            git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "move code into the plan dir" ;;
        unrelated)
            git -C "$sb" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m "elsewhere"
            r=$(git -C "$sb" rev-parse HEAD) ;;
    esac
    review="${APPROVED_AT_HEAD/abc1234/${r:0:7}}"
    mkdir -p "$wt/.agent/work-plans/issue-7"
    printf -- '---\nissue: 7\n---\n\n# Issue #7\n\n%s\n' "$review" > "$wt/.agent/work-plans/issue-7/progress.md"
    git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "progress: local review"
    git -C "$wt" push --quiet origin feature/issue-7
    head=$(git -C "$wt" rev-parse HEAD)
    remote="${sb}.remote.git"
    comments='[{"body":"## Decision summary\n\n**What changed**: x\n\n**Recommendation**: merge"}]'
    body='"## Summary\n\nplain body"'
    printf '{"state":"OPEN","headRefName":"feature/issue-7","title":"Test PR","headRefOid":"%s","comments":%s,"body":%s}\n' "$head" "$comments" "$body" \
        > "$sb/gh_fixtures/pr_view_$(printf '%s' "$remote" | tr '/' '_')_${PR}.json"
    echo "$sb"
}

echo "TEST: gate (a) — a review followed only by its own progress.md commit is current (#286)"
sb="$(make_gate_sandbox progress-only)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"covers head"* ]] && [[ "$out" == *"✅ Review gate"* ]] && [[ "$out" != *"would have refused"* ]] \
    && ! progress_of "$sb" | grep -q '^## Merge'; then
    pass "(g1) review + its own progress.md commit: gate passes, nothing recorded"
else
    fail "(g1) (out=${out:0:400})"
fi

echo "TEST: gate (a) — a code commit after the review is still stale"
sb="$(make_gate_sandbox code-after)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"would have refused"*"stale review"*"touches \`some_file.sh\`"* ]] \
    && progress_of "$sb" | grep -q '^## Merge (report-only)$'; then
    pass "(g2) code commit after the review: stale, names the path"
else
    fail "(g2) (out=${out:0:400})"
fi

echo "TEST: gate (a) — a review SHA that is not an ancestor of the head is stale"
sb="$(make_gate_sandbox unrelated)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"would have refused"*"stale review"*"not an ancestor"* ]]; then
    pass "(g3) review SHA outside the head's history: stale, says not an ancestor"
else
    fail "(g3) (out=${out:0:400})"
fi

echo "TEST: gate (a) — --enforce merges the progress-only shape"
sb="$(make_gate_sandbox progress-only)"
out="$(GH_MERGE_EXIT=0 run_merge "$sb" --enforce 2>&1)" || true
if merged_called "$sb" && [[ "$out" != *"review gate refused"* ]]; then
    pass "(g4) --enforce: review + own progress.md commit merges"
else
    fail "(g4) (out=${out:0:400})"
fi

echo "TEST: gate (a) — a leftover roadmap commit between review and head is also current"
sb="$(make_gate_sandbox roadmap-after)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"covers head"* ]] && [[ "$out" != *"would have refused"* ]]; then
    pass "(g5) roadmap + progress.md after the review: gate passes"
else
    fail "(g5) (out=${out:0:400})"
fi

echo "TEST: gate (a) — the same with the lowercase docs/roadmap.md spelling (#334)"
sb="$(make_gate_sandbox roadmap-after-lower)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"covers head"* ]] && [[ "$out" != *"would have refused"* ]]; then
    pass "(g5b) docs/roadmap.md + progress.md after the review: gate passes"
else
    fail "(g5b) (out=${out:0:400})"
fi

echo "TEST: gate (a) — a plan addendum committed after the review keeps it current (#300 owner rule)"
sb="$(make_gate_sandbox plan-after)"
out="$(GH_MERGE_EXIT=0 run_merge "$sb" 2>&1)" || true
if [[ "$out" == *"covers head"* ]] && [[ "$out" != *"would have refused"* ]] \
    && [[ "$out" != *"review gate refused"* ]] && merged_called "$sb"; then
    pass "(g6) plan.md addendum after the review: gate passes under the default (enforce)"
else
    fail "(g6) (out=${out:0:400})"
fi

echo "TEST: gate (a) — another issue's work-plan dir is not exempt, even with a prefix-sharing number (#309)"
sb="$(make_gate_sandbox other-issue-after)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"would have refused"*"stale review"*"touches \`.agent/work-plans/issue-70/progress.md\`"* ]]; then
    pass "(g8) issue-70 timeline after an issue-7 review: stale, names the path"
else
    fail "(g8) (out=${out:0:400})"
fi

echo "TEST: gate (a) — a code file renamed into this issue's work-plan dir is not bookkeeping (#309)"
sb="$(make_gate_sandbox rename-into-plan)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"would have refused"*"stale review"*"touches \`reviewed.sh\`"* ]]; then
    pass "(g9) code renamed into work-plans/issue-7/: stale, names the old path"
else
    fail "(g9) (out=${out:0:400})"
fi

echo "TEST: gate (a) — a non-ASCII work-plan file after the review keeps it current (core.quotePath=true, #309)"
sb="$(make_gate_sandbox plan-nonascii-after)"
out="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.quotePath GIT_CONFIG_VALUE_0=true \
    GH_MERGE_EXIT=0 run_merge "$sb" 2>&1)" || true
if [[ "$out" == *"covers head"* ]] && [[ "$out" != *"would have refused"* ]] \
    && [[ "$out" != *"review gate refused"* ]] && merged_called "$sb"; then
    pass "(g13) work-plans/issue-7/notes/café.md after the review: gate passes under the default (enforce)"
else
    fail "(g13) (out=${out:0:400})"
fi

echo "TEST: gate (a) — a raw-byte code path is quoted safe ASCII in the reason and the record; progress.md stays parseable (#309)"
sb="$(make_gate_sandbox code-rawbytes-after)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
pf="$sb/worktrees/workspace/issue-workspace-7/.agent/work-plans/issue-7/progress.md"
if [[ "$out" == *"would have refused"*"stale review"*'touches `bad-\377\r\033.sh`'* ]] \
    && progress_of "$sb" | grep -qF '**Conditions**: latest Local Review entry is at' \
    && progress_of "$sb" | grep -qF 'touches `bad-\377\r\033.sh`' \
    && ! LC_ALL=C grep -q $'[\x80-\xff\r\x1b]' "$pf" \
    && python3 "$sb/.agent/scripts/progress_read.py" "$pf" --type "Merge (report-only)" \
        | jq -e '.entries | length == 1' >/dev/null; then
    pass "(g14) raw-byte path: stale reason and Merge (report-only) record are safe ASCII; progress_read.py still parses the file"
else
    fail "(g14) (out=$(printf %q "${out:0:600}"))"
fi

# safe_reason_and_record <sb> <out> -- the printed reason line and the
# committed Merge record (the fixture's own entries may hold raw bytes) are
# valid UTF-8 with no control byte but newline
# (the script's own text may carry UTF-8 such as an em dash; quoted values
# may not carry raw bytes), and progress_read.py still parses the file.
utf8_no_ctrl() {  # stdin: text -> rc 0 when valid UTF-8 with no C0 control but \n, and no DEL
    python3 -c 'import re, sys
try:
    t = sys.stdin.buffer.read().decode("utf-8")
except UnicodeDecodeError:
    sys.exit(1)
sys.exit(1 if re.search(r"[\x00-\x09\x0b-\x1f\x7f]", t) else 0)'
}
safe_reason_and_record() {
    local pf
    pf="$(ci_wt "$1")/.agent/work-plans/issue-7/progress.md"
    grep 'would have refused' <<<"$2" | utf8_no_ctrl \
        && sed -n '/^## Merge (report-only)$/,$p' "$pf" | utf8_no_ctrl \
        && python3 "$1/.agent/scripts/progress_read.py" "$pf" --type "Merge (report-only)" \
            | jq -e '.entries | length == 1' >/dev/null
}
echo "TEST: gate (a) — control bytes in a heading suffix and a **Status** value are quoted safe ASCII in the reason and the record (#309)"
IR_CTRL="${IR_CLEAN/\#\# Integrated Review/## Integrated Review (Round $'\e'[31m2$'\a')}"
IR_CTRL="${IR_CTRL/\*\*Status\*\*: complete/**Status**: partial$'\e'[0m}"
sb="$(make_sandbox "$IR_CTRL" with_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *'would have refused'*'latest Integrated Review (Round \033[31m2\007) at the head has **Status**: partial\033[0m, not complete'* ]] \
    && progress_of "$sb" | grep -qF '**Conditions**: latest Integrated Review (Round \033[31m2\007) at the head has **Status**: partial\033[0m' \
    && safe_reason_and_record "$sb" "$out"; then
    pass "(g15) ESC/BEL in the heading suffix and the Status value: reason and Merge record are safe ASCII; progress.md still parses"
else
    fail "(g15) (out=$(printf %q "${out:0:600}"))"
fi
sb="$(make_sandbox "${STALE/\#\# Local Review/## Local Review (Round $'\e'[1m3)}" with_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *'would have refused'*'latest Local Review (Round \033[1m3) entry is at `0000000`, not the PR head'* ]] \
    && safe_reason_and_record "$sb" "$out"; then
    pass "(g15b) ESC in the heading suffix of a not-covering entry: the stale/unconfirmed reason is safe ASCII"
else
    fail "(g15b) (out=$(printf %q "${out:0:600}"))"
fi
echo "TEST: gate (a) — a control byte in a **Verdict** value is quoted safe ASCII (#309)"
sb="$(make_sandbox "${APPROVED_AT_HEAD/approved/approved$'\e'[2J}" with_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *'would have refused'*'**Verdict**: approved\033[2J, not approved'* ]] \
    && safe_reason_and_record "$sb" "$out"; then
    pass "(g16) ESC in the Verdict value: reason and Merge record are safe ASCII"
else
    fail "(g16) (out=$(printf %q "${out:0:600}"))"
fi
echo "TEST: gate (a) — an operator-local worktree path with raw bytes is quoted safe ASCII (#309)"
_saved_sandbox="$SANDBOX"
SANDBOX="$SANDBOX/raw-"$'\xff\e'"-root"; mkdir -p "$SANDBOX"
sb="$(make_sandbox "" with_summary)"
SANDBOX="$_saved_sandbox"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *'would have refused'*'no progress.md for issue #7 in an open worktree (looked for '*'raw-\377\033-root'* ]] \
    && progress_of "$sb" | grep -qF 'raw-\377\033-root' \
    && safe_reason_and_record "$sb" "$out"; then
    pass "(g17) worktree root with 0xff/ESC: the looked-for path is C-quoted in the reason and the record"
else
    fail "(g17) (out=$(printf %q "${out:0:600}"))"
fi
raw_root_sandbox() {  # <progress-body> -- make_sandbox under a root named with 0xff/ESC
    local saved="$SANDBOX" sb
    SANDBOX="$SANDBOX/raw-"$'\xff\e'"-root"; mkdir -p "$SANDBOX"
    sb="$(make_sandbox "$1" with_summary)"
    SANDBOX="$saved"
    echo "$sb"
}
sb="$(raw_root_sandbox $'## Implementation\n```\nunterminated')"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *'would have refused'*'progress.md at '*'raw-\377\033-root'*'could not be parsed'* ]] \
    && grep 'would have refused' <<<"$out" | utf8_no_ctrl; then
    pass "(g17b) malformed progress.md under a raw-byte root: the progress.md path is C-quoted in the reason"
else
    fail "(g17b) (out=$(printf %q "${out:0:600}"))"
fi
sb="$(raw_root_sandbox "$STALE")"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *'would have refused'*'does not resolve to one commit in '*'raw-\377\033-root'* ]] \
    && safe_reason_and_record "$sb" "$out"; then
    pass "(g17c) unresolvable review SHA under a raw-byte root: the worktree path is C-quoted in the reason and the record"
else
    fail "(g17c) (out=$(printf %q "${out:0:600}"))"
fi

echo "TEST: gate (a) — an unverifiable coverage check (git failure, helper rc 3) is still not covered, worded as unconfirmed (#309)"
sb="$(make_gate_sandbox roadmap-after)"
# A git shim in the sandbox's stub PATH fails only the ancestry check.
printf '#!/bin/bash\n[[ "$1 $2" == "merge-base --is-ancestor" || "$3 $4" == "merge-base --is-ancestor" ]] && { echo "error: shim" >&2; exit 128; }\nexec %q "$@"\n' \
    "$(command -v git)" > "$sb/stubbin/git"
chmod +x "$sb/stubbin/git"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"would have refused"*"review coverage could not be confirmed: could not check whether"*"git exit 128"* ]] \
    && [[ "$out" != *"covers head"* && "$out" != *"stale review"* ]]; then
    pass "(g10) ancestry check failing with exit 128: not covered, worded as unconfirmed (not stale), reason quoted"
else
    fail "(g10) (out=${out:0:400})"
fi

echo "TEST: gate (a) — a review SHA that does not resolve locally is unconfirmed, not stale (#309)"
sb="$(make_sandbox "$STALE" with_summary)"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"would have refused"*"review coverage could not be confirmed: \`"*"does not resolve to one commit"* ]] \
    && [[ "$out" != *"stale review"* ]]; then
    pass "(g11) unresolvable review SHA: worded as unconfirmed, not stale"
else
    fail "(g11) (out=${out:0:400})"
fi

echo "TEST: gate (a) — a PR head missing from the local worktree is unconfirmed, not stale (#309)"
sb="$(make_gate_sandbox progress-only)"
remote_key="$(printf '%s' "${sb}.remote.git" | tr '/' '_')"
fixture="$sb/gh_fixtures/pr_view_${remote_key}_${PR}.json"
jq -c '.headRefOid = "0123456789abcdef0123456789abcdef01234567"' "$fixture" > "$fixture.tmp" && mv "$fixture.tmp" "$fixture"
out="$(run_merge "$sb" --report-only 2>&1)" || true
if [[ "$out" == *"would have refused"*"review coverage could not be confirmed: head \`0123456\` is not present locally"* ]] \
    && [[ "$out" != *"stale review"* ]]; then
    pass "(g12) PR head not present locally: worded as unconfirmed, not stale"
else
    fail "(g12) (out=${out:0:400})"
fi

echo ""
echo "test_merge_pr_gate: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
