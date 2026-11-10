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

# A git test double first on PATH: it passes everything through to the
# real git except what the STUB_* variables ask for. STUB_LOG records each
# fetch's last argument (its refspec); STUB_FETCH=fail fails every fetch
# fast, STUB_FETCH=noop exits 0 having fetched nothing; STUB_LS_HANG,
# STUB_LS_OK and STUB_LS_FAIL make `ls-remote` for that ref hang, say
# found, or fail fast.
REAL_GIT="$(command -v git)"
GITSTUB="$SANDBOX/gitstub"
mkdir -p "$GITSTUB"
cat > "$GITSTUB/git" <<STUB_EOF
#!/usr/bin/env bash
args=("\$@"); i=0
while [ "\$i" -lt "\${#args[@]}" ]; do
    case "\${args[\$i]}" in -C|-c) i=\$((i + 2)) ;; *) break ;; esac
done
sub="\${args[\$i]:-}"; last="\${args[\${#args[@]}-1]}"
if [ "\$sub" = fetch ]; then
    [ -n "\${STUB_LOG:-}" ] && echo "fetch \$last" >> "\$STUB_LOG"
    case "\${STUB_FETCH:-}" in
        fail) echo "fatal: stub fetch failed" >&2; exit 128 ;;
        noop) exit 0 ;;
    esac
elif [ "\$sub" = ls-remote ]; then
    [ "\$last" = "\${STUB_LS_HANG:-}" ] && exec sleep 30
    [ "\$last" = "\${STUB_LS_OK:-}" ] && exit 0
    if [ "\$last" = "\${STUB_LS_FAIL:-}" ]; then echo "fatal: stub ls-remote failed" >&2; exit 128; fi
fi
exec "$REAL_GIT" "\$@"
STUB_EOF
chmod +x "$GITSTUB/git"

run_stubbed() {  # [VAR=value...] <worktree_create.sh args...>; from $FEAT, git stubbed; sets OUT, RC
    local envs=()
    while [[ "${1:-}" == [A-Z]*=* ]]; do envs+=("$1"); shift; done
    OUT="$(cd "$FEAT" && env PATH="$GITSTUB:$SB/stubbin:$PATH" ${envs[@]+"${envs[@]}"} "$FEAT_SCRIPT" "$@" 2>&1)"
    RC=$?
}

add_repo() {  # [VAR=value...] <repo> <dest> <branch> [<parent>]; sets OUT (ADDED or REFUSED), RC
    local envs=()
    while [[ "${1:-}" == [A-Z]*=* ]]; do envs+=("$1"); shift; done
    OUT="$(env PATH="$GITSTUB:$PATH" ${envs[@]+"${envs[@]}"} bash -c '
        set -euo pipefail
        source "$1/.agent/scripts/_worktree_helpers.sh"
        # As worktree_create.sh calls it: inside an `if`, so set -e is off.
        if _wt_add_repo "$2" "$3" "$4" "${5:-}"; then echo "ADDED"; else echo "REFUSED"; fi' _ "$SB" "$@" 2>&1)"
    RC=$?
}

has_branch() {  # <repo> <branch>
    git -C "$1" rev-parse --verify --quiet "refs/heads/$2" >/dev/null
}

# The whole stop message each new-branch caller prints when origin cannot
# tell (wt_lookup_for_new_branch): for the branch itself, and for a
# sub-issue branch whose parent it cannot tell about.
msg_target() {  # <repo> <branch> <reason> [<limit>]
    printf "ERROR: cannot tell whether origin has '%s' (in %s): %s; a new '%s' is not started, since it would diverge from one origin may have. Retry when origin answers (for a slow origin, raise WT_FETCH_TIMEOUT, now %ss), or pass --allow-unverified-branch to start it anyway." \
        "$2" "$1" "$3" "$2" "${4:-60}"
}
msg_parent() {  # <repo> <parent> <new> <reason> [<limit>]
    printf "ERROR: cannot tell whether origin has the parent branch '%s' of '%s' (in %s): %s; '%s' is not started from the default branch in its place, since origin may have the parent. Retry when origin answers (for a slow origin, raise WT_FETCH_TIMEOUT, now %ss), or pass --allow-unverified-branch to start it anyway." \
        "$2" "$3" "$1" "$4" "$3" "${5:-60}"
}
# The existing-branch caller's warning for a parent origin cannot tell about.
msg_existing_unknown() {  # <parent> <reason>
    printf "WARNING: cannot tell whether origin has parent branch '%s': %s. A draft PR that --plan-file opens here targets the default branch; if origin has '%s', retarget it with: gh pr edit --base %s" \
        "$1" "$2" "$1" "$1"
}

# A stop: the exit status, the whole message, and no branch made.
check_stop() {  # <label> <want-rc: nonzero|0> <repo> <branch> <message> [<dest>]
    local label="$1" want="$2" repo="$3" br="$4" msg="$5" dest="${6:-}"
    if [[ "$OUT" == *"$msg"* ]] \
       && { [[ "$want" = nonzero && "$RC" -ne 0 ]] || [[ "$want" = refused && "$RC" -eq 0 && "$OUT" == *"REFUSED"* ]]; } \
       && ! has_branch "$repo" "$br" && { [[ -z "$dest" ]] || [[ ! -e "$dest" ]]; }; then
        pass "$label"
    else
        fail "$label: rc=$RC branch=$(has_branch "$repo" "$br" && echo made || echo none): want [$msg] in: ${OUT:0:800}"
    fi
}

# A branch tracking origin/<branch> at <sha>.
check_tracks() {  # <label> <repo> <branch> <sha>
    local label="$1" repo="$2" br="$3" want="$4" up
    up="$(git -C "$repo" rev-parse --abbrev-ref "$br@{upstream}" 2>/dev/null)"
    if [[ "$(git -C "$repo" rev-parse --verify --quiet "refs/heads/$br" 2>/dev/null)" = "$want" && "$up" = "origin/$br" ]]; then
        pass "$label"
    else
        fail "$label: rc=$RC $br at $(git -C "$repo" rev-parse --short --verify --quiet "refs/heads/$br" || echo none), upstream ${up:-none}, want origin's $want: ${OUT:0:600}"
    fi
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
# Through the git double with a fetch log: the parent is asked about once,
# not a second time by the existing-branch block.
FETCH_LOG="$SANDBOX/fetch-log-10"
run_stubbed STUB_LOG="$FETCH_LOG" --issue 10 --type workspace --parent-issue 404
if [[ "$OUT" == *"⚠️  Parent branch 'feature/issue-404' not found (origin has no branch 'feature/issue-404'); falling back to the default branch"* ]]; then
    pass "missing parent: warned with the reason"
else
    fail "missing parent: no warning: ${OUT:0:400}"
fi
check_base "--parent-issue 404" "$(git -C "$SB" rev-parse --verify --quiet feature/issue-10 >/dev/null && echo feature/issue-10)" \
    "$ORIGIN_MAIN" "origin/main"
PARENT_FETCHES="$(grep -cE '^fetch (\+refs/heads/)?feature/issue-404(:|$)' "$FETCH_LOG" 2>/dev/null)"
if [[ "$PARENT_FETCHES" = 1 ]]; then
    pass "missing parent: origin asked about the parent once"
else
    fail "missing parent: origin asked about the parent ${PARENT_FETCHES:-0} times: $(cat "$FETCH_LOG" 2>/dev/null)"
fi
# _wt_add_repo, the package-worktree path, does the same.
add_repo "$SB" "$SANDBOX/pkg-wt-25" feature/issue-25 feature/issue-404
if [[ "$OUT" == *"ADDED"* && "$OUT" == *"WARNING: parent branch 'feature/issue-404' is not in $SB (origin has no branch 'feature/issue-404'); starting 'feature/issue-25' from the default branch"* \
      && "$(git -C "$SB" rev-parse --verify --quiet feature/issue-25)" = "$ORIGIN_MAIN" ]]; then
    pass "missing parent, _wt_add_repo: warned with the reason, started from origin/main"
else
    fail "missing parent, _wt_add_repo: rc=$RC: ${OUT:0:400}"
fi
# An existing branch whose parent is not on origin: only the draft PR's
# base depends on it, so creation goes on, with a warning.
gitq -C "$SB" branch feature/issue-33 "$LOCAL_MAIN"
run_create "$FEAT" "$FEAT_SCRIPT" --issue 33 --type workspace --parent-issue 408
if [[ "$RC" -eq 0 && "$OUT" == *"WARNING: parent branch 'feature/issue-408' is neither local nor on origin (origin has no branch 'feature/issue-408'); a draft PR that --plan-file opens here targets the default branch. Once 'feature/issue-408' is on origin, retarget it with: gh pr edit --base feature/issue-408"* ]]; then
    pass "existing branch, parent not on origin: created, the draft PR base warned with the reason"
else
    fail "existing branch, parent not on origin: rc=$RC: ${OUT:0:600}"
fi

echo
echo "=== A branch only on origin is checked out, also in a narrowed clone ==="
# Branches pushed to origin from the scratch clone, never fetched here.
for b in feature/issue-20 feature/issue-21; do
    gitq -C "$SANDBOX/scratch" checkout -q -b "$b" main
    gitq -C "$SANDBOX/scratch" commit -q --allow-empty -m "$b on origin"
    gitq -C "$SANDBOX/scratch" push -q origin "$b"
done
gitq -C "$SANDBOX/scratch" checkout -q main
REMOTE_20="$(git -C "$SANDBOX/scratch" rev-parse feature/issue-20)"
REMOTE_21="$(git -C "$SANDBOX/scratch" rev-parse feature/issue-21)"
# The fetch refspec a --single-branch clone has: a plain `git fetch origin
# <b>` would write FETCH_HEAD only.
gitq -C "$SB" config remote.origin.fetch "+refs/heads/main:refs/remotes/origin/main"
run_create "$FEAT" "$FEAT_SCRIPT" --issue 20 --type workspace
check_tracks "narrowed refspec, worktree_create.sh: feature/issue-20 tracks origin's" "$SB" feature/issue-20 "$REMOTE_20"
run_create "$FEAT" "$FEAT_SCRIPT" --issue 22 --type workspace --parent-issue 21
if [[ "$RC" -eq 0 && "$(git -C "$SB" rev-parse --verify --quiet feature/issue-22)" = "$REMOTE_21" ]]; then
    pass "narrowed refspec, worktree_create.sh: feature/issue-22 starts at origin's parent feature/issue-21"
else
    fail "narrowed refspec, parent only on origin: rc=$RC: ${OUT:0:400}"
fi
gitq -C "$SB" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
# _wt_add_repo in a --single-branch clone and in a --depth clone.
gitq clone -q --single-branch "file://$SANDBOX/origin.git" "$SANDBOX/clone-single"
gitq clone -q --depth 1 "file://$SANDBOX/origin.git" "$SANDBOX/clone-depth"
for kind in single depth; do
    add_repo "$SANDBOX/clone-$kind" "$SANDBOX/clone-$kind-wt" feature/issue-20
    check_tracks "--$kind clone, _wt_add_repo: feature/issue-20 tracks origin's" "$SANDBOX/clone-$kind" feature/issue-20 "$REMOTE_20"
done

echo
echo "=== A fetch that fails fast: origin is asked, and any doubt stops ==="
# The git double fails every fetch; ls-remote answers as the case needs.
run_stubbed STUB_FETCH=fail STUB_LS_OK=refs/heads/feature/issue-28 --issue 28 --type workspace
check_stop "fetch failed, origin has the branch: worktree_create.sh stops" nonzero "$SB" feature/issue-28 \
    "$(msg_target "$FEAT" feature/issue-28 "origin has 'feature/issue-28', but fetching it failed (fatal: stub fetch failed)")"
add_repo STUB_FETCH=fail STUB_LS_OK=refs/heads/feature/issue-410 "$SB" "$SANDBOX/pkg-wt-29" feature/issue-29 feature/issue-410
check_stop "fetch failed, origin has the parent: _wt_add_repo refuses, naming the sub-issue branch" refused "$SB" feature/issue-29 \
    "$(msg_parent "$SB" feature/issue-410 feature/issue-29 "origin has 'feature/issue-410', but fetching it failed (fatal: stub fetch failed)")" \
    "$SANDBOX/pkg-wt-29"
run_stubbed STUB_FETCH=noop --issue 34 --type workspace
check_stop "fetch exited 0 without the ref: worktree_create.sh stops" nonzero "$SB" feature/issue-34 \
    "$(msg_target "$FEAT" feature/issue-34 "the fetch exited 0 but wrote no origin/feature/issue-34")"
# ls-remote fails too, and an earlier fetch left origin/<parent>.
gitq -C "$SB" update-ref refs/remotes/origin/feature/issue-405 "$LOCAL_MAIN"
run_stubbed STUB_FETCH=fail STUB_LS_FAIL=refs/heads/feature/issue-405 --issue 16 --type workspace --parent-issue 405
check_stop "origin unasked, it had the parent: worktree_create.sh stops, naming the sub-issue branch" nonzero "$SB" feature/issue-16 \
    "$(msg_parent "$FEAT" feature/issue-405 feature/issue-16 "fetching 'feature/issue-405' failed (fatal: stub fetch failed), and origin could not be asked; it had 'feature/issue-405' at the last fetch (origin/feature/issue-405)")"
add_repo STUB_FETCH=fail STUB_LS_FAIL=refs/heads/feature/issue-405 "$SB" "$SANDBOX/pkg-wt-17" feature/issue-17 feature/issue-405
check_stop "origin unasked, it had the parent: _wt_add_repo refuses, naming the sub-issue branch" refused "$SB" feature/issue-17 \
    "$(msg_parent "$SB" feature/issue-405 feature/issue-17 "fetching 'feature/issue-405' failed (fatal: stub fetch failed), and origin could not be asked; it had 'feature/issue-405' at the last fetch (origin/feature/issue-405)")" \
    "$SANDBOX/pkg-wt-17"
gitq -C "$SB" update-ref -d refs/remotes/origin/feature/issue-405
if command -v timeout >/dev/null 2>&1; then
    run_stubbed STUB_FETCH=fail STUB_LS_HANG=refs/heads/feature/issue-24 WT_FETCH_TIMEOUT=2 --issue 24 --type workspace
    check_stop "fetch failed, then ls-remote timed out: worktree_create.sh stops" nonzero "$SB" feature/issue-24 \
        "$(msg_target "$FEAT" feature/issue-24 "fetching 'feature/issue-24' failed (fatal: stub fetch failed), and asking origin for it timed out after 2s" 2)"
    add_repo STUB_FETCH=fail STUB_LS_HANG=refs/heads/feature/issue-26 WT_FETCH_TIMEOUT=2 "$SB" "$SANDBOX/pkg-wt-26" feature/issue-26
    check_stop "fetch failed, then ls-remote timed out: _wt_add_repo refuses" refused "$SB" feature/issue-26 \
        "$(msg_target "$SB" feature/issue-26 "fetching 'feature/issue-26' failed (fatal: stub fetch failed), and asking origin for it timed out after 2s" 2)" \
        "$SANDBOX/pkg-wt-26"
    run_stubbed STUB_FETCH=fail STUB_LS_HANG=refs/heads/feature/issue-409 WT_FETCH_TIMEOUT=2 --issue 27 --type workspace --parent-issue 409
    check_stop "parent fetch failed, then ls-remote timed out: worktree_create.sh stops" nonzero "$SB" feature/issue-27 \
        "$(msg_parent "$FEAT" feature/issue-409 feature/issue-27 "fetching 'feature/issue-409' failed (fatal: stub fetch failed), and asking origin for it timed out after 2s" 2)"
else
    echo "  SKIP: ls-remote timeouts (no timeout command on this machine)"
fi

echo
echo "=== Origin unreachable: stop, unless --allow-unverified-branch ==="
gitq -C "$SB" remote set-url origin "file:///nonexistent/origin.git"
gitq -C "$SB" update-ref refs/remotes/origin/main "$LOCAL_MAIN"
GIT_LINE="$(git -C "$SB" fetch --quiet origin 2>&1 | head -n1)"
UNREACH_7="fetching 'feature/issue-7' failed ($GIT_LINE), and origin could not be asked whether it has 'feature/issue-7'"
run_create "$FEAT" "$FEAT_SCRIPT" --issue 7 --type workspace
check_stop "unreachable origin, no tracking ref: worktree_create.sh stops" nonzero "$SB" feature/issue-7 \
    "$(msg_target "$FEAT" feature/issue-7 "$UNREACH_7")"
add_repo "$SB" "$SANDBOX/pkg-wt-31" feature/issue-31
check_stop "unreachable origin, no tracking ref: _wt_add_repo refuses" refused "$SB" feature/issue-31 \
    "$(msg_target "$SB" feature/issue-31 "fetching 'feature/issue-31' failed ($GIT_LINE), and origin could not be asked whether it has 'feature/issue-31'")" \
    "$SANDBOX/pkg-wt-31"
run_create "$FEAT" "$FEAT_SCRIPT" --issue 7 --type workspace --allow-unverified-branch
if [[ "$RC" -eq 0 && "$OUT" == *"WARNING: cannot tell whether origin has 'feature/issue-7' (in $FEAT): $UNREACH_7. --allow-unverified-branch was given, so 'feature/issue-7' is started afresh; if origin has it, its first push is rejected."* \
      && "$OUT" == *"WARNING: could not fetch 'main' from origin"*"local 'main'"* ]]; then
    pass "unreachable origin, --allow-unverified-branch: created, both warnings name their reason"
else
    fail "unreachable origin, --allow-unverified-branch: rc=$RC: ${OUT:0:600}"
fi
check_base "unreachable origin" "$(git -C "$SB" rev-parse --verify --quiet feature/issue-7 >/dev/null && echo feature/issue-7)" \
    "$LOCAL_MAIN" "local main"
if [[ "$OUT" == *"WARNING: could not fetch 'main' from origin in "*"(fatal: "*"does not appear to be a git repository)"* ]]; then
    pass "unreachable origin: the warning carries git's first error line"
else
    fail "unreachable origin: the warning does not name git's error: ${OUT:0:400}"
fi
add_repo WT_ALLOW_UNVERIFIED_BRANCH=true "$SB" "$SANDBOX/pkg-wt-35" feature/issue-35
if [[ "$OUT" == *"ADDED"* && "$OUT" == *"WARNING: cannot tell whether origin has 'feature/issue-35' (in $SB): fetching 'feature/issue-35' failed ($GIT_LINE), and origin could not be asked whether it has 'feature/issue-35'. --allow-unverified-branch was given, so 'feature/issue-35' is started afresh; if origin has it, its first push is rejected."* ]] \
   && has_branch "$SB" feature/issue-35; then
    pass "unreachable origin, opt-out, _wt_add_repo: created with the warning"
else
    fail "unreachable origin, opt-out, _wt_add_repo: rc=$RC: ${OUT:0:600}"
fi
# origin is unreachable, but an earlier fetch left origin/feature/issue-15:
# the branch exists there, so creation stops rather than start a new one.
gitq -C "$SB" update-ref refs/remotes/origin/feature/issue-15 "$LOCAL_MAIN"
run_create "$FEAT" "$FEAT_SCRIPT" --issue 15 --type workspace
check_stop "unreachable origin that had the branch: stops, no new branch started" nonzero "$SB" feature/issue-15 \
    "$(msg_target "$FEAT" feature/issue-15 "fetching 'feature/issue-15' failed ($GIT_LINE), and origin could not be asked; it had 'feature/issue-15' at the last fetch (origin/feature/issue-15)")"
gitq -C "$SB" update-ref -d refs/remotes/origin/feature/issue-15
# An existing branch whose parent origin cannot be asked about: warned.
gitq -C "$SB" branch feature/issue-32 "$LOCAL_MAIN"
run_create "$FEAT" "$FEAT_SCRIPT" --issue 32 --type workspace --parent-issue 407
if [[ "$RC" -eq 0 && "$OUT" == *"$(msg_existing_unknown feature/issue-407 "fetching 'feature/issue-407' failed ($GIT_LINE), and origin could not be asked whether it has 'feature/issue-407'")"* ]]; then
    pass "existing branch, unreachable origin: created, the draft PR base warned with the reason"
else
    fail "existing branch, unreachable origin: rc=$RC: ${OUT:0:600}"
fi

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
    check_stop "hanging fetch: worktree_create.sh stops, no branch started" nonzero "$SB" feature/issue-13 \
        "$(msg_target "$FEAT" feature/issue-13 "fetching 'feature/issue-13' timed out after 2s" 2)"
    if [[ "$elapsed" -lt 20 ]]; then
        pass "hanging fetch: worktree_create.sh's branch fetch is bounded (${elapsed}s)"
    else
        fail "hanging fetch: worktree_create.sh took ${elapsed}s"
    fi
    if [[ "$(cat "$PROMPT_SEEN" 2>/dev/null)" = "0" ]]; then
        pass "hanging fetch: worktree_create.sh's fetch ran with GIT_TERMINAL_PROMPT=0"
    else
        fail "hanging fetch: worktree_create.sh's fetch GIT_TERMINAL_PROMPT was '$(cat "$PROMPT_SEEN" 2>/dev/null)'"
    fi
    started=$SECONDS
    add_repo GIT_SSH_COMMAND="$SSH_SHIM" WT_FETCH_TIMEOUT=2 "$SB" "$SANDBOX/pkg-wt-14" feature/issue-14 feature/issue-404
    elapsed=$((SECONDS - started))
    check_stop "hanging fetch: _wt_add_repo refuses, no branch or worktree" refused "$SB" feature/issue-14 \
        "$(msg_target "$SB" feature/issue-14 "fetching 'feature/issue-14' timed out after 2s" 2)" "$SANDBOX/pkg-wt-14"
    if [[ "$elapsed" -lt 20 ]]; then
        pass "hanging fetch: _wt_add_repo's target fetch is bounded (${elapsed}s)"
    else
        fail "hanging fetch: _wt_add_repo took ${elapsed}s"
    fi
    # The issue branch already exists, so the parent only sets the draft
    # PR's base: a parent fetch that timed out is said, not taken in
    # silence as "no parent".
    gitq -C "$SB" branch feature/issue-18 "$LOCAL_MAIN"
    started=$SECONDS
    OUT="$(cd "$FEAT" && PATH="$SB/stubbin:$PATH" GIT_SSH_COMMAND="$SSH_SHIM" WT_FETCH_TIMEOUT=2 \
        "$FEAT_SCRIPT" --issue 18 --type workspace --parent-issue 406 2>&1)"
    RC=$?
    elapsed=$((SECONDS - started))
    if [[ "$RC" -eq 0 && "$OUT" == *"$(msg_existing_unknown feature/issue-406 "fetching 'feature/issue-406' timed out after 2s")"* \
          && "$elapsed" -lt 20 ]]; then
        pass "hanging fetch: an existing branch's parent fetch is bounded (${elapsed}s) and the draft PR base warned"
    else
        fail "hanging fetch, existing branch's parent: rc=$RC elapsed=${elapsed}s: ${OUT:0:600}"
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
