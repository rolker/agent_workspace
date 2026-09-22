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
    for f in merge_pr.sh worktree_remove.sh worktree_list.sh _worktree_helpers.sh _issue_helpers.sh _project_registry.sh _resolve_default_branch.sh progress_read.py progress_append.sh _progress_entry.sh update_roadmap.sh; do
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

# ================================================= package worktree (nested container) =====
echo "TEST: a package-worktree PR (container nested inside the workspace checkout) never commits a record into the main tree"
sb="$(make_sandbox "" "")"
# a package repo with a github-shaped remote so extract_gh_slug -> owner/pkg_a
mkdir -p "$sb/fake_remotes/github.com/owner" "$sb/origins"
git init --bare --quiet "$sb/fake_remotes/github.com/owner/pkg_a.git"; git -C "$sb/fake_remotes/github.com/owner/pkg_a.git" symbolic-ref HEAD refs/heads/main
git -C "$sb/origins" init --quiet -b main pkg_a >/dev/null 2>&1 || { mkdir -p "$sb/origins/pkg_a"; git -C "$sb/origins/pkg_a" init --quiet -b main; }
git -C "$sb/origins/pkg_a" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
git -C "$sb/origins/pkg_a" remote add origin "$sb/fake_remotes/github.com/owner/pkg_a.git"
git -C "$sb/origins/pkg_a" push --quiet -u origin main
# the container: under the sandbox's own worktrees/project/, NOT a repo itself
cont="$sb/worktrees/project/p11/issue-p11-owner-pkg_a-901"
mkdir -p "$cont/l1_ws/src"
git -C "$sb/origins/pkg_a" worktree add --quiet -b feature/issue-901 "$cont/l1_ws/src/pkg_a" >/dev/null 2>&1
printf '# project=p11 issue=owner/pkg_a#901 layer=l1\n%s\tl1_ws/src/pkg_a\tfeature/issue-901\n' "$sb/origins/pkg_a" > "$cont/.worktree-repos"
printf '{"state":"OPEN","headRefName":"feature/issue-901","title":"Pkg PR","headRefOid":"%s","comments":[],"body":""}\n' "$HEAD_SHA" > "$sb/gh_fixtures/pr_view_owner_pkg_a_901.json"
root_before=$(git -C "$sb" rev-parse HEAD); status_before=$(git -C "$sb" status --porcelain)
out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" GH_MERGE_EXIT=1 \
    GH_MERGEABLE_DEFAULT=MERGEABLE MERGE_PR_CI_POLL_SECONDS=0 \
    "$sb/.agent/scripts/merge_pr.sh" --pr owner/pkg_a#901 --no-wait --no-roadmap-update 2>&1)" || true
if [[ "$(git -C "$sb" rev-parse HEAD)" == "$root_before" ]] && [[ "$(git -C "$sb" status --porcelain | grep -v 'gh_calls.log\|comments_posted')" == "$(grep -v 'gh_calls.log\|comments_posted' <<< "$status_before")" ]] \
    && [[ ! -e "$sb/.agent/work-plans" ]] && [[ ! -e "$cont/.agent" ]] \
    && [[ "$out" == *"package worktrees carry no issue timeline"*"posted as a comment"* ]] \
    && grep -q '^## Merge (report-only)$' "$sb/gh_fixtures/comments_posted.md"; then
    pass "package PR: main tree untouched, container untouched, record posted as a PR comment"
else
    fail "package PR nested container (out=${out:0:400})"
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

# ================================================= --enforce, project scope =====
echo "TEST: --enforce on a project PR stays report-only"
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
    "$sb/.agent/scripts/merge_pr.sh" --pr 9 --type project --no-wait --no-roadmap-update --enforce 2>&1)" || true
if merged_called "$sb" && [[ "$out" == *"would have refused"* ]] && [[ "$out" == *"--enforce applies to workspace PRs only"* ]] && [[ "$out" != *"review gate refused"* ]]; then
    pass "project scope under --enforce: proceeds with the report-only line naming the scoping rule"
else
    fail "project scope enforce (out=${out:0:400})"
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
#   plan-after     R -> work-plans/issue-7/plan.md -> progress.md
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
        plan-after)
            mkdir -p "$wt/.agent/work-plans/issue-7"
            printf -- '# Plan\n\n## Addendum 1\n\nowner rule\n' > "$wt/.agent/work-plans/issue-7/plan.md"
            git -C "$wt" add -A && git -C "$wt" -c user.name=t -c user.email=t@t commit --quiet -m "plan(#7): addendum" ;;
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

echo "TEST: gate (a) — a plan addendum committed after the review keeps it current (#300 owner rule)"
sb="$(make_gate_sandbox plan-after)"
out="$(GH_MERGE_EXIT=0 run_merge "$sb" 2>&1)" || true
if [[ "$out" == *"covers head"* ]] && [[ "$out" != *"would have refused"* ]] \
    && [[ "$out" != *"review gate refused"* ]] && merged_called "$sb"; then
    pass "(g6) plan.md addendum after the review: gate passes under the default (enforce)"
else
    fail "(g6) (out=${out:0:400})"
fi

echo ""
echo "test_merge_pr_gate: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
