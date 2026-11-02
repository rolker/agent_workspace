#!/usr/bin/env bash
# Tests for .agent/scripts/worktree_create.sh's start point for a new
# branch (issue #323): a skill or issue worktree starts from the repo's
# default branch as origin has it (origin/<default>), never from the
# invoking checkout's HEAD, unless --parent-issue names a parent branch.
#
# Run: bash .agent/scripts/tests/test_worktree_create.sh
#
# Sandbox: a workspace-shaped repo (the worktree scripts committed into it,
# so a feature worktree carries its own copy, as a real one does) with a
# bare origin whose main is one commit ahead of the local main, and a
# feature worktree two commits ahead of main. gh and git-bug are stubbed
# to fail, so issue lookups degrade offline (as test_project_registry.sh
# does).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "${SANDBOX:?}"' EXIT

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset WORKTREE_ISSUE

gitq() { git "$@" >/dev/null 2>&1; }

# A workspace-shaped repo at <dir> on branch main with the worktree scripts
# committed, plus the gh/git-bug stubs (untracked).
make_ws_repo() {
    local sb="$1" f
    mkdir -p "$sb/.agent/scripts" "$sb/.agent/project_types" "$sb/stubbin"
    for f in worktree_create.sh worktree_enter.sh _worktree_helpers.sh _resolve_default_branch.sh \
             _issue_helpers.sh _project_registry.sh adapter; do
        cp "$REAL_ROOT/.agent/scripts/$f" "$sb/.agent/scripts/"
    done
    cp -r "$REAL_ROOT/.agent/project_types/single_project" "$sb/.agent/project_types/"
    printf 'worktrees/\nstubbin/\n' > "$sb/.gitignore"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/gh"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$sb/stubbin/git-bug"
    chmod +x "$sb/stubbin/gh" "$sb/stubbin/git-bug"
    gitq -C "$sb" init -q -b main
    gitq -C "$sb" add -A
    gitq -C "$sb" commit -q -m "workspace scripts"
}

# A bare origin for <repo> holding its current main, with origin/HEAD set,
# then one more commit pushed to origin only (from a scratch clone), so
# origin/main is ahead of the local main.
add_origin_ahead() {
    local repo="$1" bare="$2" scratch="$3"
    gitq init -q --bare -b main "$bare"
    gitq -C "$repo" remote add origin "$bare"
    gitq -C "$repo" push -q origin main
    gitq -C "$repo" remote set-head origin main
    gitq clone -q "$bare" "$scratch"
    gitq -C "$scratch" commit -q --allow-empty -m "landed on origin"
    gitq -C "$scratch" push -q origin main
}

run_create() {  # <cwd> <script> <args...>; sets OUT, RC
    local cwd="$1" script="$2"
    shift 2
    OUT="$(cd "$cwd" && PATH="$SB/stubbin:$PATH" "$script" "$@" 2>&1)"
    RC=$?
}

newest_branch() {  # <repo> <ref pattern>
    git -C "$1" for-each-ref --sort=-creatordate --format='%(refname:short)' "$2" | head -n1
}

# --------------------------------------------------------------- sandbox ---
SB="$SANDBOX/ws"
make_ws_repo "$SB"
add_origin_ahead "$SB" "$SANDBOX/origin.git" "$SANDBOX/scratch"
gitq -C "$SB" fetch -q origin
ORIGIN_MAIN="$(git -C "$SB" rev-parse origin/main)"
LOCAL_MAIN="$(git -C "$SB" rev-parse main)"
# Not fetched into local main: the fix must use origin's tip.
gitq -C "$SB" update-ref refs/remotes/origin/main "$LOCAL_MAIN"

FEAT="$SB/worktrees/workspace/issue-workspace-5"
mkdir -p "$SB/worktrees/workspace"
gitq -C "$SB" worktree add -q "$FEAT" -b feature/issue-5 main
gitq -C "$FEAT" commit -q --allow-empty -m "feature commit 1"
gitq -C "$FEAT" commit -q --allow-empty -m "feature commit 2"
FEAT_TIP="$(git -C "$FEAT" rev-parse HEAD)"
FEAT_SCRIPT="$FEAT/.agent/scripts/worktree_create.sh"

if [[ "$ORIGIN_MAIN" = "$LOCAL_MAIN" || ! -x "$FEAT_SCRIPT" ]]; then
    echo "FATAL: sandbox setup failed"
    exit 1
fi

# Checks a new branch: its base is <want> and it has no upstream.
check_base() {  # <label> <branch> <want-sha> <want-label>
    local label="$1" br="$2" want="$3" wl="$4" mb
    if [[ -z "$br" ]]; then
        fail "$label: no branch was created (rc=$RC): ${OUT:0:400}"
        return
    fi
    mb="$(git -C "$SB" merge-base "$br" "$want" 2>/dev/null)"
    if [[ "$(git -C "$SB" rev-parse "$br")" = "$want" && "$mb" = "$want" ]]; then
        pass "$label: $br starts at $wl"
    else
        fail "$label: $br starts at $(git -C "$SB" rev-parse --short "$br"), want $wl"
    fi
    if git -C "$SB" merge-base --is-ancestor "$FEAT_TIP" "$br" 2>/dev/null \
       || [[ "$(git -C "$SB" rev-list --count "$want..$br")" -ne 0 ]]; then
        fail "$label: $br carries commits that are not on $wl"
    else
        pass "$label: $br has none of the feature commits"
    fi
    if git -C "$SB" rev-parse --abbrev-ref "$br@{upstream}" >/dev/null 2>&1; then
        fail "$label: $br has an upstream ($(git -C "$SB" rev-parse --abbrev-ref "$br@{upstream}"))"
    else
        pass "$label: $br has no upstream (--no-track)"
    fi
}

echo
echo "=== Invoked from inside a feature worktree ahead of main ==="
run_create "$FEAT" "$FEAT_SCRIPT" --skill research --type workspace
check_base "--skill research" "$(newest_branch "$SB" 'refs/heads/skill/research-*')" "$ORIGIN_MAIN" "origin/main"

run_create "$FEAT" "$FEAT_SCRIPT" --issue 6 --type workspace
check_base "--issue 6" "$(git -C "$SB" rev-parse --verify --quiet feature/issue-6 >/dev/null && echo feature/issue-6)" \
    "$ORIGIN_MAIN" "origin/main"

echo
echo "=== --parent-issue still branches from the parent feature branch ==="
run_create "$FEAT" "$FEAT_SCRIPT" --issue 9 --type workspace --parent-issue 5
if [[ "$RC" -eq 0 ]] && [[ "$(git -C "$SB" rev-parse feature/issue-9 2>/dev/null)" = "$FEAT_TIP" ]]; then
    pass "--parent-issue 5: feature/issue-9 starts at feature/issue-5's tip"
else
    fail "--parent-issue 5: rc=$RC base=$(git -C "$SB" rev-parse --short feature/issue-9 2>/dev/null): ${OUT:0:300}"
fi

echo
echo "=== A missing parent branch falls back to the default branch, not HEAD ==="
run_create "$FEAT" "$FEAT_SCRIPT" --issue 10 --type workspace --parent-issue 404
if [[ "$OUT" == *"Parent branch 'feature/issue-404' not found"* ]]; then
    pass "missing parent: warned"
else
    fail "missing parent: no warning: ${OUT:0:300}"
fi
check_base "--parent-issue 404" "$(git -C "$SB" rev-parse --verify --quiet feature/issue-10 >/dev/null && echo feature/issue-10)" \
    "$ORIGIN_MAIN" "origin/main"

echo
echo "=== Origin unreachable: the local default, with a warning ==="
gitq -C "$SB" remote set-url origin "file:///nonexistent/origin.git"
gitq -C "$SB" update-ref refs/remotes/origin/main "$LOCAL_MAIN"
run_create "$FEAT" "$FEAT_SCRIPT" --issue 7 --type workspace
if [[ "$RC" -eq 0 && "$OUT" == *"WARNING: could not fetch 'main' from origin"*"local 'main'"* ]]; then
    pass "unreachable origin: created, warning names the local fallback"
else
    fail "unreachable origin: rc=$RC: ${OUT:0:400}"
fi
check_base "unreachable origin" "$(git -C "$SB" rev-parse --verify --quiet feature/issue-7 >/dev/null && echo feature/issue-7)" \
    "$LOCAL_MAIN" "local main"
if [[ "$OUT" == *"WARNING: could not fetch 'main' from origin in "*"(fatal: "*"does not appear to be a git repository)"* ]]; then
    pass "unreachable origin: the warning carries git's first error line"
else
    fail "unreachable origin: the warning does not name git's error: ${OUT:0:400}"
fi
# origin is unreachable, but an earlier fetch left origin/feature/issue-15:
# the branch exists there, so creation stops rather than start a new one.
gitq -C "$SB" update-ref refs/remotes/origin/feature/issue-15 "$LOCAL_MAIN"
run_create "$FEAT" "$FEAT_SCRIPT" --issue 15 --type workspace
if [[ "$RC" -ne 0 && "$OUT" == *"ERROR: could not fetch 'feature/issue-15' from origin"*"as of the last fetch (origin/feature/issue-15)"* ]] \
   && ! git -C "$SB" rev-parse --verify --quiet refs/heads/feature/issue-15 >/dev/null; then
    pass "unreachable origin that had the branch: stops, no new branch started"
else
    fail "unreachable origin that had the branch: rc=$RC: ${OUT:0:400}"
fi
gitq -C "$SB" update-ref -d refs/remotes/origin/feature/issue-15

echo
echo "=== A fetch that would prompt or hang is bounded ==="
# An ssh origin whose "ssh" records GIT_TERMINAL_PROMPT and then hangs,
# as a passphrase or host-key prompt would. WT_FETCH_TIMEOUT=2 must end
# the fetch and fall back to the local default with the timeout named.
# The start-point helper is called directly, under set -euo pipefail as
# worktree_create.sh runs it: the script's other origin calls (the
# target-branch fetch in _wt_add_repo) are not what this case is about.
if command -v timeout >/dev/null 2>&1; then
    SSH_SHIM="$SB/stubbin/hang-ssh"
    PROMPT_SEEN="$SANDBOX/prompt-seen"
    printf '#!/usr/bin/env bash\nprintf "%%s" "${GIT_TERMINAL_PROMPT-unset}" > "%s"\nexec sleep 30\n' \
        "$PROMPT_SEEN" > "$SSH_SHIM"
    chmod +x "$SSH_SHIM"
    gitq -C "$SB" remote set-url origin "ssh://git@example.invalid/origin.git"
    started=$SECONDS
    OUT="$(GIT_SSH_COMMAND="$SSH_SHIM" WT_FETCH_TIMEOUT=2 bash -c '
        set -euo pipefail
        source "$1/.agent/scripts/_worktree_helpers.sh"
        start=$(_wt_default_start_point "$1")
        echo "START=$start"' _ "$SB" 2>&1)"
    RC=$?
    elapsed=$((SECONDS - started))
    if [[ "$RC" -eq 0 && "$OUT" == *"could not fetch 'main' from origin in "*"(timed out after 2s)"*"local 'main'"* \
          && "$OUT" == *"START=main"* && "$elapsed" -lt 20 ]]; then
        pass "hanging fetch: ended by WT_FETCH_TIMEOUT (${elapsed}s), local 'main' with the timeout named"
    else
        fail "hanging fetch: rc=$RC elapsed=${elapsed}s: ${OUT:0:400}"
    fi
    if [[ "$(cat "$PROMPT_SEEN" 2>/dev/null)" = "0" ]]; then
        pass "hanging fetch: git ran with GIT_TERMINAL_PROMPT=0"
    else
        fail "hanging fetch: GIT_TERMINAL_PROMPT was '$(cat "$PROMPT_SEEN" 2>/dev/null || echo 'not recorded')'"
    fi

    # The other origin calls are bounded the same way: worktree_create.sh's
    # fetch_remote_branch (the issue branch on origin) end to end, and
    # _wt_add_repo's target fetch (the package-worktree path). A named
    # branch whose fetch timed out may exist on origin, so creation stops
    # instead of starting a branch that would diverge from it.
    : > "$PROMPT_SEEN"
    started=$SECONDS
    OUT="$(cd "$FEAT" && PATH="$SB/stubbin:$PATH" GIT_SSH_COMMAND="$SSH_SHIM" WT_FETCH_TIMEOUT=2 \
        "$FEAT_SCRIPT" --issue 13 --type workspace 2>&1)"
    RC=$?
    elapsed=$((SECONDS - started))
    if [[ "$RC" -ne 0 && "$OUT" == *"ERROR: fetching 'feature/issue-13' from origin in "*"timed out after 2s"*"not started in its place"* \
          && "$elapsed" -lt 20 ]] && ! git -C "$SB" rev-parse --verify --quiet feature/issue-13 >/dev/null; then
        pass "hanging fetch: worktree_create.sh's branch fetch is bounded (${elapsed}s) and stops, no branch started"
    else
        fail "hanging fetch, worktree_create.sh end to end: rc=$RC elapsed=${elapsed}s: ${OUT:0:600}"
    fi
    if [[ "$(cat "$PROMPT_SEEN" 2>/dev/null)" = "0" ]]; then
        pass "hanging fetch: worktree_create.sh's fetch ran with GIT_TERMINAL_PROMPT=0"
    else
        fail "hanging fetch: worktree_create.sh's fetch GIT_TERMINAL_PROMPT was '$(cat "$PROMPT_SEEN" 2>/dev/null)'"
    fi
    started=$SECONDS
    OUT="$(GIT_SSH_COMMAND="$SSH_SHIM" WT_FETCH_TIMEOUT=2 bash -c '
        set -euo pipefail
        source "$1/.agent/scripts/_worktree_helpers.sh"
        # As worktree_create.sh calls it: inside an `if`, so set -e is off.
        if _wt_add_repo "$1" "$2" feature/issue-14 feature/issue-404; then echo "ADDED"; else echo "REFUSED"; fi' _ "$SB" "$SANDBOX/pkg-wt-14" 2>&1)"
    RC=$?
    elapsed=$((SECONDS - started))
    if [[ "$RC" -eq 0 && "$OUT" == *"REFUSED"* && "$elapsed" -lt 20 ]] \
       && [[ "$OUT" == *"ERROR: fetching 'feature/issue-14' from origin in "*"timed out after 2s"* ]] \
       && ! git -C "$SB" rev-parse --verify --quiet feature/issue-14 >/dev/null && [[ ! -e "$SANDBOX/pkg-wt-14" ]]; then
        pass "hanging fetch: _wt_add_repo's target fetch is bounded (${elapsed}s) and refuses, no branch or worktree"
    else
        fail "hanging fetch, _wt_add_repo: rc=$RC elapsed=${elapsed}s: ${OUT:0:600}"
    fi
    gitq -C "$SB" remote set-url origin "file:///nonexistent/origin.git"
else
    echo "  SKIP: hanging fetch (no timeout command on this machine)"
fi

echo
echo "=== No resolvable default: refuse with the set-head hint, never HEAD ==="
SB2="$SANDBOX/ws2"
make_ws_repo "$SB2"
gitq -C "$SB2" branch -m main trunk
FEAT2="$SB2/worktrees/workspace/issue-workspace-5"
mkdir -p "$SB2/worktrees/workspace"
gitq -C "$SB2" worktree add -q "$FEAT2" -b feature/issue-5 trunk
gitq -C "$FEAT2" commit -q --allow-empty -m "feature commit"
OUT="$(cd "$FEAT2" && PATH="$SB2/stubbin:$PATH" "$FEAT2/.agent/scripts/worktree_create.sh" --issue 11 --type workspace 2>&1)"
RC=$?
if [[ "$RC" -ne 0 && "$OUT" == *"git"*"remote set-head origin -a"* ]] \
   && ! git -C "$SB2" rev-parse --verify --quiet feature/issue-11 >/dev/null; then
    pass "no default branch: exit $RC with the set-head hint, no branch created"
else
    fail "no default branch: rc=$RC branch=$(git -C "$SB2" rev-parse --verify --quiet feature/issue-11 || echo none): ${OUT:0:400}"
fi

echo
echo "=== A project worktree starts from its own repo's default ==="
# The legacy project/ checkout (as test_precommit_hook_path.sh uses):
# its default is `develop`, its origin is ahead of the local develop, and
# its HEAD is a feature branch ahead of develop.
SB3="$SANDBOX/ws3"
make_ws_repo "$SB3"
P="$SB3/project"
gitq init -q -b develop "$P"
gitq -C "$P" commit -q --allow-empty -m "project init"
gitq init -q --bare -b develop "$SANDBOX/project-origin.git"
gitq -C "$P" remote add origin "$SANDBOX/project-origin.git"
gitq -C "$P" push -q origin develop
gitq -C "$P" remote set-head origin develop
gitq clone -q "$SANDBOX/project-origin.git" "$SANDBOX/project-scratch"
gitq -C "$SANDBOX/project-scratch" commit -q --allow-empty -m "landed on project origin"
gitq -C "$SANDBOX/project-scratch" push -q origin develop
P_ORIGIN="$(git -C "$SANDBOX/project-origin.git" rev-parse develop)"
gitq -C "$P" checkout -q -b feature/local-work
gitq -C "$P" commit -q --allow-empty -m "project feature commit"
P_HEAD="$(git -C "$P" rev-parse HEAD)"
OUT="$(cd "$SB3" && PATH="$SB3/stubbin:$PATH" "$SB3/.agent/scripts/worktree_create.sh" --issue 8 --type project 2>&1)"
RC=$?
P_BR="$(git -C "$P" rev-parse --verify --quiet feature/issue-8 2>/dev/null)"
if [[ "$RC" -eq 0 && "$P_BR" = "$P_ORIGIN" ]]; then
    pass "project: feature/issue-8 starts at the project's origin/develop"
else
    fail "project: rc=$RC base=${P_BR:-none} want origin/develop $P_ORIGIN (HEAD $P_HEAD): ${OUT:0:400}"
fi
if git -C "$P" rev-parse --abbrev-ref "feature/issue-8@{upstream}" >/dev/null 2>&1; then
    fail "project: feature/issue-8 has an upstream"
else
    pass "project: feature/issue-8 has no upstream (--no-track)"
fi

echo
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
