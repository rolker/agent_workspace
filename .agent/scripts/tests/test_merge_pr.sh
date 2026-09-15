#!/usr/bin/env bash
# Tests for merge_pr.sh's repo-qualified PR resolution, manifest-driven
# worktree lookup, and sibling-PR cleanup rule (issue #252 PR 2).
#
# Everything runs against sandbox workspaces (mktemp) with the real
# merge_pr.sh / worktree_remove.sh / worktree_list.sh / _worktree_helpers.sh
# / _issue_helpers.sh copied in. `gh` is replaced by a fixture-driven stub
# (no network, no auth) that answers `pr view` / `pr merge` / `pr checks` /
# `pr list` from files under a fixtures directory. `git pull --ff-only`
# (unconditional in the legacy sync step) is made to succeed offline by
# pointing each sandbox repo's `origin` at a local bare clone instead of a
# real GitHub URL.
#
# Run: bash .agent/scripts/tests/test_merge_pr.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

PASS=0
FAIL=0

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

# ---- Sandbox helpers ----

SANDBOXES=()
cleanup() {
    local sb
    for sb in ${SANDBOXES[@]+"${SANDBOXES[@]}"}; do
        rm -rf "$sb"
    done
}
trap cleanup EXIT

# A fixture-driven `gh` stub: `pr view` and `pr list` answer from files
# under $GH_FIXTURES_DIR (written by the tests), keyed by repo+number or
# repo+branch. `pr merge` and `pr checks` always succeed (tests use
# --no-wait, so `pr checks` is never actually invoked, but a stub is
# provided for completeness). Every invocation is appended to
# $GH_CALL_LOG (one line per call) so tests can assert which repo/branch
# a lookup targeted.
write_gh_stub() {
    local sb="$1"
    cat > "$sb/stubbin/gh" <<'EOF'
#!/usr/bin/env bash
: "${GH_FIXTURES_DIR:?}"
log="${GH_CALL_LOG:-/dev/null}"
printf '%s\n' "$*" >> "$log"
sanitize() { printf '%s' "$1" | tr '/' '_'; }

if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
    num="$3"
    shift 3
    repo=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -R) repo="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    f="$GH_FIXTURES_DIR/pr_view_$(sanitize "$repo")_${num}.json"
    if [ -f "$f" ]; then
        cat "$f"
        exit 0
    fi
    echo "GraphQL: Could not resolve to a PullRequest with the number of '$num'." >&2
    exit 1
elif [ "$1" = "pr" ] && [ "$2" = "merge" ]; then
    exit "${GH_MERGE_EXIT:-0}"
elif [ "$1" = "pr" ] && [ "$2" = "checks" ]; then
    exit 0
elif [ "$1" = "pr" ] && [ "$2" = "list" ]; then
    shift 2
    repo="" branch=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -R) repo="$2"; shift 2 ;;
            --head) branch="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    if [ -n "${GH_PR_LIST_FAIL:-}" ]; then
        echo "${GH_PR_LIST_FAIL_MSG:-gh: pr list failed}" >&2
        exit 1
    fi
    f="$GH_FIXTURES_DIR/pr_list_$(sanitize "$repo")_$(sanitize "$branch").count"
    if [ -f "$f" ]; then
        cat "$f"
    else
        echo 0
    fi
    exit 0
else
    exit 1
fi
EOF
    chmod +x "$sb/stubbin/gh"
}

write_pr_view_fixture() {
    local sb="$1" repo="$2" num="$3" branch="$4" title="${5:-Test PR}"
    mkdir -p "$sb/gh_fixtures"
    printf '{"state":"OPEN","headRefName":"%s","title":"%s"}\n' "$branch" "$title" \
        > "$sb/gh_fixtures/pr_view_$(printf '%s' "$repo" | tr '/' '_')_${num}.json"
}

write_pr_list_fixture() {
    local sb="$1" repo="$2" branch="$3" count="$4"
    mkdir -p "$sb/gh_fixtures"
    echo "$count" > "$sb/gh_fixtures/pr_list_$(printf '%s' "$repo" | tr '/' '_')_$(printf '%s' "$branch" | tr '/' '_').count"
}

# A base sandbox: merge_pr.sh + its dependencies, an offline gh/git-bug
# stub, and $sb itself as a real git repo standing in for the workspace
# (ROOT_DIR). `origin` points at a local bare clone (not a real GitHub
# URL) so the legacy Step 6 `git pull --ff-only` succeeds offline.
make_merge_sandbox() {
    local sb bare curbr
    sb="$(mktemp -d)"
    SANDBOXES+=("$sb")
    mkdir -p "$sb/.agent/scripts" "$sb/stubbin" "$sb/gh_fixtures"
    cp "$REAL_ROOT/.agent/scripts/merge_pr.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_list.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_worktree_helpers.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_issue_helpers.sh" "$sb/.agent/scripts/"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"
    chmod +x "$sb/stubbin/git-bug"
    write_gh_stub "$sb"

    git -C "$sb" init --quiet
    git -C "$sb" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init

    bare="${sb}.remote.git"
    git init --bare --quiet "$bare"
    SANDBOXES+=("$bare")
    git -C "$sb" remote add origin "$bare"
    curbr="$(git -C "$sb" symbolic-ref --short HEAD)"
    git -C "$sb" push --quiet -u origin "$curbr"

    echo "$sb"
}

# A real (committed) git repo standing in for a package repo's checkout,
# with `origin` pointing at a real local bare clone — reachable offline, so
# `git ls-remote`/push/pull against it behave exactly as they would against
# a real (reachable) GitHub remote, deterministically, with no network. The
# bare clone's path is nested under a `github.com/<owner>/` directory
# purely so `extract_gh_slug` (plain text substitution on "github.com[:/]",
# not URL/DNS validation) still resolves it to "<owner>/<name>" the same
# way it would a real `git@github.com:<owner>/<name>.git` URL.
make_origin_repo() {
    local sb="$1" name="$2" owner="${3:-owner}"
    local dir="$sb/origins/$name"
    local remote_dir="$sb/fake_remotes/github.com/${owner}/${name}.git"
    mkdir -p "$dir" "$(dirname "$remote_dir")"
    git init --bare --quiet "$remote_dir"
    git -C "$dir" init --quiet
    echo "$name" > "$dir/README.md"
    git -C "$dir" add README.md
    git -C "$dir" -c user.name=t -c user.email=t@t commit --quiet -m init
    git -C "$dir" branch -m main 2>/dev/null || true
    git -C "$dir" remote add origin "$remote_dir"
    git -C "$dir" push --quiet -u origin main
    echo "$dir"
}

# Build a package worktree by hand (no need to drive the ros2_colcon
# adapter/worktree_create.sh for these tests): writes .worktree-repos and
# a real `git worktree add` per entry. Entries: "origin_dir|rel|branch".
# Usage: wt=$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-111" \
#     p11 "owner/pkg_a#111" l1 "$origin_a|l1_ws/src/pkg_a|feature/issue-111" ...)
make_package_worktree() {
    local sb="$1" wt_rel="$2" project="$3" issue="$4" layer="$5"
    shift 5
    local wt="$sb/$wt_rel"
    mkdir -p "$wt"
    printf '# project=%s issue=%s layer=%s\n' "$project" "$issue" "$layer" > "$wt/.worktree-repos"
    local entry origin rel branch
    for entry in "$@"; do
        IFS='|' read -r origin rel branch <<< "$entry"
        mkdir -p "$(dirname "$wt/$rel")"
        git -C "$origin" worktree add --quiet -b "$branch" "$wt/$rel" >/dev/null 2>&1
        printf '%s\t%s\t%s\n' "$origin" "$rel" "$branch" >> "$wt/.worktree-repos"
    done
    echo "$wt"
}

run_merge_pr() {
    local sb="$1"
    shift
    (cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIXTURES_DIR="$sb/gh_fixtures" GH_CALL_LOG="$sb/gh_calls.log" \
        "$sb/.agent/scripts/merge_pr.sh" "$@")
}

# ---- Tests ----

test_qualified_pr_ref_resolves_package_worktree() {
    echo "TEST: qualified --pr owner/repo#N resolves the right repo and finds the package worktree by manifest"
    local sb out rc=0 origin_a origin_b wt
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    origin_b="$(make_origin_repo "$sb" pkg_b owner)"
    wt="$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-111" \
        p11 "owner/pkg_a#111" l1 \
        "$origin_a|l1_ws/src/pkg_a|feature/issue-111" \
        "$origin_b|l1_ws/src/pkg_b|feature/pkg_b-issue-111")"
    # pkg_b is untouched: no PR (0 open), and — unlike the orphaned-branch
    # sweep test below — a real commit not on its main, so `branch -d`
    # safely refuses to delete it (git's own "not fully merged" guard) even
    # though the post-removal sweep considers it, since its branch was
    # never pushed to origin either.
    git -C "$wt/l1_ws/src/pkg_b" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m wip
    write_pr_view_fixture "$sb" "owner/pkg_a" 111 "feature/issue-111"
    write_pr_list_fixture "$sb" "owner/pkg_b" "feature/pkg_b-issue-111" 0

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#111 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "queried only the qualified repo" "pr view 111 -R owner/pkg_a" "$(<"$sb/gh_calls.log")"
    assert_contains "checked the sibling's own repo for open PRs" \
        "pr list -R owner/pkg_b --head feature/pkg_b-issue-111" "$(<"$sb/gh_calls.log")"
    assert_eq "package worktree removed (no sibling PR open)" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "pkg_a's local branch deleted after removal" "false" \
        "$(git -C "$origin_a" show-ref --verify --quiet refs/heads/feature/issue-111 && echo true || echo false)"
    assert_eq "pkg_b's branch left untouched (it's the sibling, not the merged PR)" "true" \
        "$(git -C "$origin_b" show-ref --verify --quiet refs/heads/feature/pkg_b-issue-111 && echo true || echo false)"
}

test_sibling_form_issue_number_extraction() {
    echo "TEST: feature/<repo>-issue-N branch form extracts the issue number"
    local sb out rc=0 origin_b wt
    sb="$(make_merge_sandbox)"
    origin_b="$(make_origin_repo "$sb" pkg_b owner)"
    wt="$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_b-222" \
        p11 "owner/pkg_b#222" l1 \
        "$origin_b|l1_ws/src/pkg_b|feature/pkg_b-issue-222")"
    write_pr_view_fixture "$sb" "owner/pkg_b" 222 "feature/pkg_b-issue-222"

    out="$(run_merge_pr "$sb" --pr owner/pkg_b#222 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "issue number extracted from feature/<repo>-issue-N" \
        "Merging PR #222 (issue #222)" "$out"
}

test_sibling_pr_open_keeps_worktree() {
    echo "TEST: an open sibling PR keeps the worktree and names it"
    local sb out rc=0 origin_a origin_b wt
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    origin_b="$(make_origin_repo "$sb" pkg_b owner)"
    wt="$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-333" \
        p11 "owner/pkg_a#333" l1 \
        "$origin_a|l1_ws/src/pkg_a|feature/issue-333" \
        "$origin_b|l1_ws/src/pkg_b|feature/pkg_b-issue-333")"
    write_pr_view_fixture "$sb" "owner/pkg_a" 333 "feature/issue-333"
    write_pr_list_fixture "$sb" "owner/pkg_b" "feature/pkg_b-issue-333" 1

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#333 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "names the blocking sibling PR's repo" "owner/pkg_b" "$out"
    assert_contains "names the blocking sibling PR's branch" "feature/pkg_b-issue-333" "$out"
    assert_contains "explains why the worktree is kept" "sibling package PR" "$out"
    assert_eq "worktree kept" "true" "$([ -d "$wt" ] && echo true || echo false)"
    assert_eq "pkg_a's local branch NOT deleted (still checked out in the kept worktree)" "true" \
        "$(git -C "$origin_a" show-ref --verify --quiet refs/heads/feature/issue-333 && echo true || echo false)"
}

test_repo_flag_equivalent_to_qualified_ref() {
    echo "TEST: --repo owner/repo --pr N behaves like --pr owner/repo#N"
    local sb out rc=0 origin_a wt
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    wt="$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-444" \
        p11 "owner/pkg_a#444" l1 \
        "$origin_a|l1_ws/src/pkg_a|feature/issue-444")"
    write_pr_view_fixture "$sb" "owner/pkg_a" 444 "feature/issue-444"

    out="$(run_merge_pr "$sb" --pr 444 --repo owner/pkg_a --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "queried only the given repo" "pr view 444 -R owner/pkg_a" "$(<"$sb/gh_calls.log")"
    assert_eq "package worktree removed" "false" "$([ -e "$wt" ] && echo true || echo false)"
}

test_conflicting_repo_and_qualified_ref_rejected() {
    echo "TEST: --repo conflicting with a qualified --pr is a usage error"
    local sb out rc=0
    sb="$(make_merge_sandbox)"
    out="$(run_merge_pr "$sb" --pr owner/pkg_a#1 --repo someone/else --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 2" "2" "$rc"
    assert_contains "names the conflict" "conflicts with qualified --pr" "$out"
}

test_sibling_check_failure_fails_closed() {
    echo "TEST: a gh failure checking a sibling's PRs fails closed — keeps the worktree and names the repo"
    local sb out rc=0 origin_a origin_b wt
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    origin_b="$(make_origin_repo "$sb" pkg_b owner)"
    wt="$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-555" \
        p11 "owner/pkg_a#555" l1 \
        "$origin_a|l1_ws/src/pkg_a|feature/issue-555" \
        "$origin_b|l1_ws/src/pkg_b|feature/pkg_b-issue-555")"
    write_pr_view_fixture "$sb" "owner/pkg_a" 555 "feature/issue-555"
    # No pr_list fixture for owner/pkg_b: GH_PR_LIST_FAIL forces that call
    # to fail outright (simulating a gh outage — network, auth, rate
    # limit) instead of quietly answering "0 open PRs".

    out="$(GH_PR_LIST_FAIL=1 GH_PR_LIST_FAIL_MSG='rate limit exceeded' \
        run_merge_pr "$sb" --pr owner/pkg_a#555 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "names the repo the check could not be completed for" "owner/pkg_b" "$out"
    assert_contains "explains what happened" "COULD NOT CHECK" "$out"
    assert_contains "surfaces gh's own error" "rate limit exceeded" "$out"
    assert_contains "tells the user how to finish cleanup once confirmed" \
        "worktree_remove.sh --issue owner/pkg_a#555 --type project --project p11" "$out"
    assert_eq "worktree kept (fail closed, not fail open)" "true" "$([ -d "$wt" ] && echo true || echo false)"
    assert_eq "pkg_a's local branch NOT deleted (still checked out in the kept worktree)" "true" \
        "$(git -C "$origin_a" show-ref --verify --quiet refs/heads/feature/issue-555 && echo true || echo false)"
}

test_orphaned_local_branch_swept_on_final_merge() {
    echo "TEST: a local branch left over from an earlier merge (remote already gone) is swept once the last sibling merges"
    local sb out rc=0 origin_a origin_b wt
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    origin_b="$(make_origin_repo "$sb" pkg_b owner)"
    # pkg_a's PR merged earlier: its remote branch is already gone (never
    # pushed here — ls-remote sees the same "no such ref" either way), but
    # its local branch survived because pkg_b's PR was still open at the
    # time. Now pkg_b's PR merges too.
    wt="$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_b-666" \
        p11 "owner/pkg_b#666" l1 \
        "$origin_a|l1_ws/src/pkg_a|feature/issue-666" \
        "$origin_b|l1_ws/src/pkg_b|feature/pkg_b-issue-666")"
    write_pr_view_fixture "$sb" "owner/pkg_b" 666 "feature/pkg_b-issue-666"
    write_pr_list_fixture "$sb" "owner/pkg_a" "feature/issue-666" 0

    out="$(run_merge_pr "$sb" --pr owner/pkg_b#666 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_eq "worktree removed" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "pkg_a's orphaned local branch swept" "false" \
        "$(git -C "$origin_a" show-ref --verify --quiet refs/heads/feature/issue-666 && echo true || echo false)"
    assert_eq "pkg_b's own local branch deleted too" "false" \
        "$(git -C "$origin_b" show-ref --verify --quiet refs/heads/feature/pkg_b-issue-666 && echo true || echo false)"
    assert_contains "reports pkg_a's sweep" "Local branch deleted (feature/issue-666" "$out"
    assert_contains "reports pkg_b's sweep" "Local branch deleted (feature/pkg_b-issue-666" "$out"
}

test_legacy_workspace_pr_regression() {
    echo "TEST: a plain workspace PR (no manifest) is resolved and cleaned up exactly as before #252 PR 2"
    local sb out rc=0 wt ws_remote
    sb="$(make_merge_sandbox)"
    # Keep origin pointed at the local bare clone (set up by
    # make_merge_sandbox) so the unconditional legacy `git pull --ff-only`
    # in Step 6 succeeds offline. The gh fixture is keyed on that same
    # remote string — merge_pr.sh queries gh with whatever `git remote
    # get-url origin` returns, GitHub URL or not.
    ws_remote="$(git -C "$sb" remote get-url origin)"
    # No new commit on the feature branch: `gh pr merge` is stubbed (it
    # never actually merges anything at the git level), so a real new
    # commit here would leave the branch "not fully merged" and the
    # legacy Step 5 `branch -d` (safe delete) would refuse — same commit
    # as main is trivially "merged" and lets that step behave as it would
    # after a real merge.
    git -C "$sb" branch feature/issue-999
    wt="$sb/worktrees/workspace/issue-workspace-999"
    mkdir -p "$(dirname "$wt")"
    git -C "$sb" worktree add --quiet "$wt" feature/issue-999
    write_pr_view_fixture "$sb" "$ws_remote" 999 "feature/issue-999"

    out="$(run_merge_pr "$sb" --pr 999 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "workspace type auto-detected" "Merging PR #999 (issue #999)" "$out"
    assert_eq "workspace worktree removed" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "feature branch deleted in the workspace repo" "false" \
        "$(git -C "$sb" show-ref --verify --quiet refs/heads/feature/issue-999 && echo true || echo false)"
}

test_legacy_single_repo_project_pr_regression() {
    echo "TEST: a legacy single-repo project/ PR (no manifest) is resolved and cleaned up exactly as before #252 PR 2"
    local sb out rc=0 wt bare curbr pj_remote
    sb="$(make_merge_sandbox)"
    mkdir -p "$sb/project"
    git -C "$sb/project" init --quiet
    git -C "$sb/project" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
    bare="${sb}.project.remote.git"
    SANDBOXES+=("$bare")
    git init --bare --quiet "$bare"
    # Same offline-pull trick as make_merge_sandbox: origin is a local bare
    # clone, and the gh fixture is keyed on that same string, whatever it is.
    git -C "$sb/project" remote add origin "$bare"
    curbr="$(git -C "$sb/project" symbolic-ref --short HEAD)"
    git -C "$sb/project" push --quiet -u origin "$curbr"
    pj_remote="$(git -C "$sb/project" remote get-url origin)"
    # No new commit on the feature branch — see the workspace-PR test above
    # for why: `gh pr merge` is stubbed, so a real new commit would leave
    # the branch "not fully merged" and defeat the safe `branch -d`.
    git -C "$sb/project" branch feature/issue-77
    wt="$sb/worktrees/project/proj_repo/issue-proj_repo-77"
    mkdir -p "$(dirname "$wt")"
    git -C "$sb/project" worktree add --quiet "$wt" feature/issue-77
    write_pr_view_fixture "$sb" "$pj_remote" 77 "feature/issue-77"

    out="$(run_merge_pr "$sb" --pr 77 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "project type auto-detected" "Merging PR #77 (issue #77)" "$out"
    assert_eq "project worktree removed" "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "feature branch deleted in the project repo" "false" \
        "$(git -C "$sb/project" show-ref --verify --quiet refs/heads/feature/issue-77 && echo true || echo false)"
}

# ---- Run all tests ----
echo "=== merge_pr.sh package-worktree tests (#252 PR 2) ==="
echo ""

test_qualified_pr_ref_resolves_package_worktree
test_sibling_form_issue_number_extraction
test_sibling_pr_open_keeps_worktree
test_repo_flag_equivalent_to_qualified_ref
test_conflicting_repo_and_qualified_ref_rejected
test_sibling_check_failure_fails_closed
test_orphaned_local_branch_swept_on_final_merge
test_legacy_workspace_pr_regression
test_legacy_single_repo_project_pr_regression

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
