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
# The CI-target decision, the SHA-targeted `gh api` check-runs/mergeability
# poll, and the idempotent Merge record (issue #284) have their own
# hermetic coverage in test_merge_pr_gate.sh; every case here uses
# --no-wait, so none of that machinery (or `gh pr checks`, which the
# script no longer calls at all — see the stub comment below) is exercised
# by this suite.
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

# One sandbox for the whole run, created at top level (not inside $()) so
# the trap actually fires — see issue #297. Helpers carve per-test
# directories out of it with `mktemp -d -p "$SANDBOX"`, which needs no
# shared state and so survives being called as `sb="$(make_merge_sandbox)"`.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# A fixture-driven `gh` stub: `pr view` and `pr list` answer from files
# under $GH_FIXTURES_DIR (written by the tests), keyed by repo+number or
# repo+branch. `pr merge` always succeeds per GH_MERGE_EXIT; `pr checks`
# is stubbed for completeness but merge_pr.sh does not call it any more
# (issue #284 replaced `gh pr checks --watch` with a SHA-targeted `gh api`
# poll — see test_merge_pr_gate.sh). Every case in this suite uses
# --no-wait, so neither `pr checks` nor the new `gh api` poll is ever
# invoked here. Every gh invocation is appended to $GH_CALL_LOG (one line
# per call) so tests can assert which repo/branch a lookup targeted.
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
    repo=""; jf=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -R) repo="$2"; shift 2 ;;
            --json) jf="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    # merge_pr.sh's mergeability settle runs even under --no-wait (#290);
    # answer it as settled so these resolution/cleanup cases never poll.
    if [ "$jf" = "mergeable,mergeStateStatus" ]; then
        echo '{"mergeable":"MERGEABLE","mergeStateStatus":"CLEAN"}'; exit 0
    fi
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
    sb="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$sb/.agent/scripts" "$sb/stubbin" "$sb/gh_fixtures"
    cp "$REAL_ROOT/.agent/scripts/merge_pr.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_remove.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/worktree_list.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_worktree_helpers.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_issue_helpers.sh" "$sb/.agent/scripts/"
    cp "$REAL_ROOT/.agent/scripts/_project_registry.sh" "$sb/.agent/scripts/"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"
    chmod +x "$sb/stubbin/git-bug"
    write_gh_stub "$sb"

    git -C "$sb" init --quiet
    git -C "$sb" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init

    # String-derived sibling of $sb (so it lands under $SANDBOX too); the
    # gh fixture filenames are keyed on this exact path string.
    bare="${sb}.remote.git"
    git init --bare --quiet "$bare"
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
    # HEAD must point at main explicitly: on a host with no init.defaultBranch
    # (GitHub's runners) a bare init points HEAD at `master`, and a later
    # `git clone` of it lands on an unborn branch, so `push origin main` fails
    # with "src refspec main does not match any" (seen once run_script_tests
    # wired this suite into CI).
    git init --bare --quiet "$remote_dir"
    git -C "$remote_dir" symbolic-ref HEAD refs/heads/main
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
        MERGE_PR_CI_POLL_SECONDS=0 MERGE_PR_CI_GRACE_SECONDS=5 \
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

test_sibling_without_remote_fails_closed() {
    echo "TEST: a sibling whose GitHub remote cannot be resolved fails closed — keeps the worktree"
    local sb out rc=0 origin_a origin_b wt
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    origin_b="$(make_origin_repo "$sb" pkg_b owner)"
    # Strip pkg_b's origin so its slug cannot be resolved: the PR check is
    # unverifiable, which must block cleanup exactly like a gh failure.
    git -C "$origin_b" remote remove origin
    wt="$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-556" \
        p11 "owner/pkg_a#556" l1 \
        "$origin_a|l1_ws/src/pkg_a|feature/issue-556" \
        "$origin_b|l1_ws/src/pkg_b|feature/pkg_b-issue-556")"
    write_pr_view_fixture "$sb" "owner/pkg_a" 556 "feature/issue-556"

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#556 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "names the unverifiable sibling" "$origin_b" "$out"
    assert_contains "says why" "no resolvable GitHub remote" "$out"
    assert_contains "explains what happened" "COULD NOT CHECK" "$out"
    assert_eq "worktree kept (fail closed)" "true" "$([ -d "$wt" ] && echo true || echo false)"
}

test_own_repo_sync_failure_is_reported() {
    echo "TEST: a failed pull --ff-only in the merged repo is reported, not swallowed"
    local sb out rc=0 origin_a wt tmp_clone
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    wt="$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-557" \
        p11 "owner/pkg_a#557" l1 \
        "$origin_a|l1_ws/src/pkg_a|feature/issue-557")"
    write_pr_view_fixture "$sb" "owner/pkg_a" 557 "feature/issue-557"
    # Diverge: one commit on origin's main via a scratch clone, a different
    # one on the local main checkout — pull --ff-only must refuse.
    tmp_clone="$sb/scratch_clone"
    git clone --quiet "$(git -C "$origin_a" remote get-url origin)" "$tmp_clone"
    echo remote > "$tmp_clone/remote.txt"
    git -C "$tmp_clone" add remote.txt
    git -C "$tmp_clone" -c user.name=t -c user.email=t@t commit --quiet -m remote
    git -C "$tmp_clone" push --quiet origin main
    echo local > "$origin_a/local.txt"
    git -C "$origin_a" add local.txt
    git -C "$origin_a" -c user.name=t -c user.email=t@t commit --quiet -m local

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#557 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0 (merge itself succeeded)" "0" "$rc"
    assert_contains "sync failure is reported" "Could not fast-forward owner/pkg_a" "$out"
    assert_contains "git's own error is surfaced" "fast-forward" "$out"
    assert_contains "final summary marks cleanup incomplete" "cleanup incomplete" "$out"
    assert_eq "worktree still removed (sync failure does not block removal)" "false" "$([ -d "$wt" ] && echo true || echo false)"
}

test_package_repo_without_worktree_never_uses_legacy_cleanup() {
    echo "TEST: --repo on a package repo with no matching worktree merges and cleans nothing (never the legacy path)"
    local sb out rc=0 origin_a decoy
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    # Decoy: a legacy-shaped project worktree for the SAME issue number in an
    # unrelated project — the legacy path would find and remove it.
    decoy="$sb/worktrees/project/other/issue-other-558"
    mkdir -p "$decoy" && touch "$decoy/marker"
    write_pr_view_fixture "$sb" "owner/pkg_a" 558 "feature/issue-558"

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#558 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "says nothing local matched" "nothing local to clean up" "$out"
    assert_eq "decoy worktree untouched" "true" "$([ -f "$decoy/marker" ] && echo true || echo false)"
    assert_eq "no legacy removal attempted" "false" "$(grep -q 'Removing worktree' <<< "$out" && echo true || echo false)"
}

test_repo_conflicting_type_rejected() {
    echo "TEST: --repo with a contradicting --type is rejected before merging"
    local sb out rc=0
    sb="$(make_merge_sandbox)"
    make_origin_repo "$sb" pkg_a owner >/dev/null
    write_pr_view_fixture "$sb" "owner/pkg_a" 559 "feature/issue-559"
    out="$(run_merge_pr "$sb" --pr owner/pkg_a#559 --type workspace --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 2" "2" "$rc"
    assert_contains "names the conflict" "conflicts with --repo owner/pkg_a" "$out"
    assert_eq "nothing merged" "false" "$(grep -q 'pr merge' "$sb/gh_calls.log" 2>/dev/null && echo true || echo false)"
}

test_same_repo_under_two_instances_requires_project() {
    echo "TEST: the same repo+branch worktreed under two instances is rejected without --project, selected with it"
    local sb out rc=0 origin_a origin_a2 wt1 wt2
    sb="$(make_merge_sandbox)"
    # Two checkouts of the "same" GitHub repo (same owner/name slug, distinct
    # local clones), one per instance, each with a package worktree on the
    # same branch.
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    origin_a2="$sb/origins2/pkg_a"
    mkdir -p "$(dirname "$origin_a2")"
    git clone --quiet "$(git -C "$origin_a" remote get-url origin)" "$origin_a2"
    wt1="$(make_package_worktree "$sb" "worktrees/project/inst1/issue-inst1-owner-pkg_a-560" \
        inst1 "owner/pkg_a#560" l1 "$origin_a|l1_ws/src/pkg_a|feature/issue-560")"
    wt2="$(make_package_worktree "$sb" "worktrees/project/inst2/issue-inst2-owner-pkg_a-560" \
        inst2 "owner/pkg_a#560" l1 "$origin_a2|l1_ws/src/pkg_a|feature/issue-560")"
    write_pr_view_fixture "$sb" "owner/pkg_a" 560 "feature/issue-560"

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#560 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 2 without --project" "2" "$rc"
    assert_contains "lists inst1" "--project inst1" "$out"
    assert_contains "lists inst2" "--project inst2" "$out"
    assert_eq "nothing merged" "false" "$(grep -q 'pr merge' "$sb/gh_calls.log" 2>/dev/null && echo true || echo false)"
    assert_eq "both worktrees intact" "true" "$([ -d "$wt1" ] && [ -d "$wt2" ] && echo true || echo false)"

    rc=0
    out="$(run_merge_pr "$sb" --pr owner/pkg_a#560 --project inst2 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0 with --project inst2" "0" "$rc"
    assert_eq "inst2 worktree removed" "false" "$([ -d "$wt2" ] && echo true || echo false)"
    assert_eq "inst1 worktree untouched" "true" "$([ -d "$wt1" ] && echo true || echo false)"
}

test_project_parent_alias_selects_instance_manifest() {
    echo "TEST: --project <parent> matches a manifest whose header names the resolved instance (#273 round-2 review)"
    local sb out rc=0 origin_a wt
    sb="$(make_merge_sandbox)"
    # Registry: parent p11 with default instance p11-rolling. worktree_create
    # resolves the parent before writing the manifest header, so the header
    # says p11-rolling; the user still types --project p11.
    mkdir -p "$sb/p11root/rolling"
    git -C "$sb/p11root/rolling" init --quiet
    printf 'p11 project %s default_instance=p11-rolling\np11-rolling ros2_colcon %s parent=p11\n' \
        "$sb/p11root" "$sb/p11root/rolling" >> "$sb/.agent/projects.local"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    wt="$(make_package_worktree "$sb" "worktrees/project/p11-rolling/issue-p11-rolling-owner-pkg_a-562" \
        p11-rolling "owner/pkg_a#562" l1 "$origin_a|l1_ws/src/pkg_a|feature/issue-562")"
    write_pr_view_fixture "$sb" "owner/pkg_a" 562 "feature/issue-562"

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#562 --project p11 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0 with --project p11 (parent alias)" "0" "$rc"
    assert_eq "instance's package worktree removed" "false" "$([ -d "$wt" ] && echo true || echo false)"
    assert_eq "merged" "true" "$(grep -q 'pr merge' "$sb/gh_calls.log" 2>/dev/null && echo true || echo false)"
}

test_remote_branch_already_gone_is_not_a_failure() {
    echo "TEST: a head branch GitHub already auto-deleted counts as cleaned up, not incomplete"
    local sb out rc=0 origin_a wt
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    wt="$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-561" \
        p11 "owner/pkg_a#561" l1 "$origin_a|l1_ws/src/pkg_a|feature/issue-561")"
    write_pr_view_fixture "$sb" "owner/pkg_a" 561 "feature/issue-561"
    # make_package_worktree creates the branch locally only; it was never
    # pushed, so origin has no such ref — exactly the auto-deleted shape.

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#561 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "reports the branch as already gone" "Remote branch already gone" "$out"
    assert_eq "no false incomplete warning" "false" "$(grep -q 'cleanup incomplete' <<< "$out" && echo true || echo false)"
    assert_eq "worktree removed" "false" "$([ -d "$wt" ] && echo true || echo false)"
}

test_sweep_reports_unmerged_local_branch() {
    echo "TEST: the post-removal sweep reports (and keeps) a sibling branch with unmerged work"
    local sb out rc=0 origin_a origin_b
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    origin_b="$(make_origin_repo "$sb" pkg_b owner)"
    make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-562" \
        p11 "owner/pkg_a#562" l1 \
        "$origin_a|l1_ws/src/pkg_a|feature/issue-562" \
        "$origin_b|l1_ws/src/pkg_b|feature/pkg_b-issue-562" >/dev/null
    # pkg_b: an unmerged commit on its branch, never pushed (remote ref absent
    # → sweep tries branch -d → git refuses).
    echo abandoned > "$sb/worktrees/project/p11/issue-p11-owner-pkg_a-562/l1_ws/src/pkg_b/abandoned.txt"
    git -C "$sb/worktrees/project/p11/issue-p11-owner-pkg_a-562/l1_ws/src/pkg_b" add abandoned.txt
    git -C "$sb/worktrees/project/p11/issue-p11-owner-pkg_a-562/l1_ws/src/pkg_b" -c user.name=t -c user.email=t@t commit --quiet -m abandoned
    write_pr_view_fixture "$sb" "owner/pkg_a" 562 "feature/issue-562"
    write_pr_list_fixture "$sb" "owner/pkg_b" "feature/pkg_b-issue-562" 0 2>/dev/null || true

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#562 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "sweep reports the kept branch" "Kept local branch 'feature/pkg_b-issue-562'" "$out"
    assert_contains "surfaces git's reason" "not fully merged" "$out"
    assert_eq "pkg_b branch still exists" "true" \
        "$(git -C "$origin_b" show-ref --verify --quiet refs/heads/feature/pkg_b-issue-562 && echo true || echo false)"
}

test_failed_worktree_removal_marks_cleanup_incomplete() {
    echo "TEST: a failed worktree removal (dirty nested checkout) is reported as cleanup incomplete, not success"
    local sb out rc=0 origin_a wt
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    wt="$(make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-563" \
        p11 "owner/pkg_a#563" l1 "$origin_a|l1_ws/src/pkg_a|feature/issue-563")"
    write_pr_view_fixture "$sb" "owner/pkg_a" 563 "feature/issue-563"
    echo dirty > "$wt/l1_ws/src/pkg_a/uncommitted.txt"

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#563 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0 (merge itself succeeded)" "0" "$rc"
    assert_contains "removal failure surfaced" "Worktree removal failed" "$out"
    assert_contains "banner says cleanup incomplete" "cleanup incomplete" "$out"
    assert_eq "banner does not claim cleaned up" "false" "$(grep -q 'cleaned up, and synced' <<< "$out" && echo true || echo false)"
    assert_eq "worktree still present" "true" "$([ -d "$wt" ] && echo true || echo false)"
}

test_kept_worktree_banner() {
    echo "TEST: when a sibling PR keeps the worktree, the banner says so rather than 'cleaned up'"
    local sb out rc=0 origin_a origin_b
    sb="$(make_merge_sandbox)"
    origin_a="$(make_origin_repo "$sb" pkg_a owner)"
    origin_b="$(make_origin_repo "$sb" pkg_b owner)"
    make_package_worktree "$sb" "worktrees/project/p11/issue-p11-owner-pkg_a-564" \
        p11 "owner/pkg_a#564" l1 \
        "$origin_a|l1_ws/src/pkg_a|feature/issue-564" \
        "$origin_b|l1_ws/src/pkg_b|feature/pkg_b-issue-564" >/dev/null
    write_pr_view_fixture "$sb" "owner/pkg_a" 564 "feature/issue-564"
    write_pr_list_fixture "$sb" "owner/pkg_b" "feature/pkg_b-issue-564" 1

    out="$(run_merge_pr "$sb" --pr owner/pkg_a#564 --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "banner says worktree kept" "worktree kept until the sibling package PR" "$out"
    assert_eq "banner does not claim cleaned up" "false" "$(grep -q 'cleaned up, and synced' <<< "$out" && echo true || echo false)"
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

    # --report-only: this sandbox has no review timeline and the gate
    # enforces by default on workspace PRs (#300); the test is about cleanup.
    out="$(run_merge_pr "$sb" --pr 999 --no-wait --no-roadmap-update --report-only 2>&1)" || rc=$?
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

test_registered_project_root_pr_regression() {
    echo "TEST: a registered (out-of-tree) single-repo project PR is resolved and its worktree, under the project's OWN root, is cleaned up (#265 PR 2)"
    local sb out rc=0 wt bare curbr pj_remote outside
    sb="$(make_merge_sandbox)"
    # Sibling of $sb under $SANDBOX, never a child of it: the test needs a
    # repo that sits outside the sandbox workspace root.
    outside="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$outside/farrepo"
    git -C "$outside/farrepo" init --quiet
    git -C "$outside/farrepo" -c user.name=t -c user.email=t@t commit --quiet --allow-empty -m init
    bare="${sb}.farrepo.remote.git"
    git init --bare --quiet "$bare"
    git -C "$outside/farrepo" remote add origin "$bare"
    curbr="$(git -C "$outside/farrepo" symbolic-ref --short HEAD)"
    git -C "$outside/farrepo" push --quiet -u origin "$curbr"
    pj_remote="$(git -C "$outside/farrepo" remote get-url origin)"
    echo "farrepo single_project $outside/farrepo" >> "$sb/.agent/projects.local"

    # No new commit on the feature branch (see the legacy-project test
    # above for why: `gh pr merge` is stubbed, so a real new commit would
    # leave the branch "not fully merged" and defeat the safe `branch -d`).
    git -C "$outside/farrepo" branch feature/issue-78
    wt="$outside/farrepo/worktrees/issue-farrepo-78"
    mkdir -p "$(dirname "$wt")"
    git -C "$outside/farrepo" worktree add --quiet "$wt" feature/issue-78
    write_pr_view_fixture "$sb" "$pj_remote" 78 "feature/issue-78"

    out="$(run_merge_pr "$sb" --pr 78 --project farrepo --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exit 0" "0" "$rc"
    assert_contains "project type auto-detected" "Merging PR #78 (issue #78)" "$out"
    assert_eq "worktree removed from under the registered (out-of-tree) root" \
        "false" "$([ -e "$wt" ] && echo true || echo false)"
    assert_eq "feature branch deleted in the registered project's own repo" "false" \
        "$(git -C "$outside/farrepo" show-ref --verify --quiet refs/heads/feature/issue-78 && echo true || echo false)"
}

test_ambiguous_project_root_type_project_fails_fast() {
    echo "TEST: --type project with >1 non-parent project registered and no --project fails fast instead of falling through with an empty project root (#273 round-1 review)"
    local sb out rc=0
    sb="$(make_merge_sandbox)"
    echo "alpha single_project $sb/alpha" >> "$sb/.agent/projects.local"
    echo "beta single_project $sb/beta" >> "$sb/.agent/projects.local"

    out="$(run_merge_pr "$sb" --pr 88 --type project --no-wait --no-roadmap-update 2>&1)" || rc=$?
    assert_eq "exits nonzero" "1" "$rc"
    assert_contains "surfaces wt_resolve_project_repo_root's ambiguity error" \
        "multiple projects registered; pass --project" "$out"
    assert_eq "no gh calls made (fails before any PR lookup)" \
        "false" "$([ -f "$sb/gh_calls.log" ] && echo true || echo false)"
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
test_sibling_without_remote_fails_closed
test_own_repo_sync_failure_is_reported
test_package_repo_without_worktree_never_uses_legacy_cleanup
test_repo_conflicting_type_rejected
test_same_repo_under_two_instances_requires_project
test_project_parent_alias_selects_instance_manifest
test_remote_branch_already_gone_is_not_a_failure
test_sweep_reports_unmerged_local_branch
test_failed_worktree_removal_marks_cleanup_incomplete
test_kept_worktree_banner
test_orphaned_local_branch_swept_on_final_merge
test_legacy_workspace_pr_regression
test_legacy_single_repo_project_pr_regression
test_registered_project_root_pr_regression
test_ambiguous_project_root_type_project_fails_fast

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
