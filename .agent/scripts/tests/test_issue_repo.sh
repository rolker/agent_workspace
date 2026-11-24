#!/usr/bin/env bash
# .agent/scripts/tests/test_issue_repo.sh
# Tests for .agent/scripts/issue_repo.sh (issue 581): the repository the
# review-issue, plan-task and review-plan skills name on every gh call.
#
# Each case checks stdout, the exit code and the gh call log, against the
# contract table in the script's header:
#   - a qualified owner/repo#N is printed as given, with no git and no gh;
#   - a bare number in a checkout whose only GitHub remote is origin, with
#     no gh default and no GH_REPO, is decided with no gh call (offline);
#   - another GitHub remote (upstream), a gh default or GH_REPO makes it ask
#     gh once, with the invocation project_integration_audit.sh uses, and a
#     different answer is refused (exit 2) naming both repositories;
#   - in a package worktree (.worktree-repos manifest) the header's
#     repository is the expected one in the issue checkout only; a sibling
#     checkout's own origin decides; the top folder is exit 3 naming the
#     header's owner/repo#N;
#   - gh missing, failing or silent when it must be asked: exit 5;
#   - no git repository: exit 3; no GitHub remote: exit 4; a bad ref: 1.
#
# Hermetic: one mktemp -d sandbox with its own HOME and git config;
# remotes are only URLs (nothing is fetched), local ones of the form
# <sandbox>/fake_remotes/github.com/<owner>/<repo>.git, the only local form
# extract_gh_slug reads as a GitHub repository; a stub gh on the PATH
# answers `gh repo view` the way real gh picks a remote (GH_REPO, a remote
# with gh-resolved=base, upstream, github, origin) and logs every call. No
# network, no real repository touched.
#
# Run: bash .agent/scripts/tests/test_issue_repo.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$(cd "$SCRIPT_DIR/.." && pwd)/issue_repo.sh"
BASH_BIN="$(command -v bash)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
SANDBOX="$(cd "$SANDBOX" && pwd -P)"

unset GH_REPO GH_HOST GH_STUB WORKTREE_ISSUE
export HOME="$SANDBOX/home"
export GIT_CONFIG_GLOBAL="$SANDBOX/gitconfig" GIT_CONFIG_NOSYSTEM=1
export GIT_CEILING_DIRECTORIES="$SANDBOX"
mkdir -p "$HOME"
printf '[init]\n\tdefaultBranch = main\n[user]\n\tname = t\n\temail = t@t\n' > "$GIT_CONFIG_GLOBAL"

FR="$SANDBOX/fake_remotes/github.com"
fr() { echo "$FR/$1.git"; }

# --- the stub gh ---------------------------------------------------------
STUB="$SANDBOX/stubbin"
mkdir -p "$STUB"
export GH_LOG="$SANDBOX/gh.log"
cat > "$STUB/gh" <<'EOF'
#!/usr/bin/env bash
stdin=$(readlink "/proc/$$/fd/0" 2>/dev/null || echo unknown)
printf '%s | cwd=%s GH_HOST=%s GH_PROMPT_DISABLED=%s stdin=%s\n' \
    "$*" "$PWD" "${GH_HOST:-}" "${GH_PROMPT_DISABLED:-}" "$stdin" >> "${GH_LOG:?}"
case "${GH_STUB:-}" in
    fail) echo "To get started with GitHub CLI, please run:  gh auth login (not logged in)" >&2; exit 4 ;;
    silent) exit 0 ;;
esac
[ "$1 $2" = "repo view" ] || { echo "stub gh: unexpected call: $*" >&2; exit 9; }
if [ -n "${GH_REPO:-}" ]; then echo "${GH_REPO#*github.com/}"; exit 0; fi
pick=""
for r in $(git remote 2>/dev/null); do
    [ "$(git config --get "remote.$r.gh-resolved")" = base ] && pick="$r"
done
if [ -z "$pick" ]; then
    for r in upstream github origin; do
        git remote get-url "$r" >/dev/null 2>&1 && { pick="$r"; break; }
    done
fi
[ -n "$pick" ] || { echo "no git remotes found" >&2; exit 1; }
url=$(git remote get-url "$pick"); nwo="${url#*github.com[:/]}"; echo "${nwo%.git}"
EOF
chmod +x "$STUB/gh"
STUB_PATH="$STUB:$PATH"

# A PATH with git and the tools the script needs, and no gh.
NOGH="$SANDBOX/nogh"
mkdir -p "$NOGH"
for t in git dirname sed head tail tr mktemp rm cat readlink; do
    ln -s "$(command -v "$t")" "$NOGH/$t"
done
# A PATH with no git and no gh: only dirname (the script finds its own
# folder with it).
BARE="$SANDBOX/bare"
mkdir -p "$BARE"
ln -s "$(command -v dirname)" "$BARE/dirname"

# --- repositories ----------------------------------------------------------
mkrepo() {  # <dir> [<remote>=<url>]...
    local d="$1" kv; shift
    mkdir -p "$d"
    git -C "$d" init -q
    for kv in "$@"; do git -C "$d" remote add "${kv%%=*}" "${kv#*=}"; done
}
ALPHA="$SANDBOX/alpha";  mkrepo "$ALPHA" "origin=$(fr own/alpha)"
BETA="$SANDBOX/beta";    mkrepo "$BETA" "origin=$(fr own/beta)" "upstream=$(fr other/beta)"
UPPER="$SANDBOX/upper";  mkrepo "$UPPER" "origin=https://GitHub.COM/own/upper.git"
SAME="$SANDBOX/same";    mkrepo "$SAME" "origin=$(fr own/same)" "github=git@github.com:own/same.git"
NOREM="$SANDBOX/norem";  mkrepo "$NOREM"
GITLAB="$SANDBOX/gitlab"; mkrepo "$GITLAB" "origin=git@gitlab.com:o/r.git"
GLUP="$SANDBOX/glup";    mkrepo "$GLUP" "origin=git@gitlab.com:o/r.git" "upstream=$(fr own/glup)"
PLAIN="$SANDBOX/plain";  mkdir -p "$PLAIN"

# Package worktree PW for up/pkg#7: the issue checkout src/pkg (origin the
# fork fork/pkg, upstream up/pkg) and a sibling src/sib (origin own/sib).
PW="$SANDBOX/pw"
mkdir -p "$PW/src"
printf '# project=p issue=up/pkg#7 layer=main\n%s\tsrc/pkg\tfeature/issue-7\n%s\tsrc/sib\tfeature/sib-issue-7\n' \
    "$(fr fork/pkg)" "$(fr own/sib)" > "$PW/.worktree-repos"
mkrepo "$PW/src/pkg" "origin=$(fr fork/pkg)" "upstream=$(fr up/pkg)"
mkrepo "$PW/src/sib" "origin=$(fr own/sib)"
# The same layout with the worktree's top folder inside another git
# repository (a hosting folder in the workspace tree).
HOSTREPO="$SANDBOX/hostrepo"; mkrepo "$HOSTREPO" "origin=$(fr own/host)"
PWH="$HOSTREPO/wt"
mkdir -p "$PWH/src"
cp "$PW/.worktree-repos" "$PWH/.worktree-repos"
mkrepo "$PWH/src/pkg" "origin=$(fr fork/pkg)" "upstream=$(fr up/pkg)"
# PW3 for up/pkg#8: the issue checkout's origin is up/pkg itself.
PW3="$SANDBOX/pw3"
mkdir -p "$PW3/src"
printf '# project=p issue=up/pkg#8 layer=main\n%s\tsrc/pkg\tfeature/issue-8\n' "$(fr up/pkg)" > "$PW3/.worktree-repos"
mkrepo "$PW3/src/pkg" "origin=$(fr up/pkg)"
# PW4 for hdr/x#7, issue checkout with origin own/q only.
PW4="$SANDBOX/pw4"
mkdir -p "$PW4/src"
printf '# project=p issue=hdr/x#7 layer=main\n%s\tsrc/q\tfeature/issue-7\n' "$(fr own/q)" > "$PW4/.worktree-repos"
mkrepo "$PW4/src/q" "origin=$(fr own/q)"
# PW5: a bare issue=7 header.
PW5="$SANDBOX/pw5"
mkdir -p "$PW5/src"
printf '# project=p issue=7 layer=main\n%s\tsrc/q\tfeature/issue-7\n' "$(fr own/q)" > "$PW5/.worktree-repos"
mkrepo "$PW5/src/q" "origin=$(fr own/q)"

# --- the runner ------------------------------------------------------------
# run <dir> <path> [VAR=value...] -- <args...>: sets OUT, ERR, RC; the gh log
# starts empty for every run. stdin is a here-string, not /dev/null, so the
# stub can tell whether the script closed it.
run() {
    local dir="$1" path="$2"; shift 2
    local -a envs=()
    while [[ $# -gt 0 && "$1" != -- ]]; do envs+=("$1"); shift; done
    shift
    : > "$GH_LOG"
    local errf="$SANDBOX/err"
    OUT=$(cd "$dir" && env PATH="$path" "${envs[@]}" "$BASH_BIN" "$H" "$@" 2>"$errf" <<< "x"); RC=$?
    ERR=$(cat "$errf")
}
gh_calls() { grep -c . "$GH_LOG" 2>/dev/null || true; }

expect() {  # <label> <want stdout> <want rc> <want gh calls>
    local label="$1" want_out="$2" want_rc="$3" want_calls="$4" calls
    calls=$(gh_calls)
    if [[ "$OUT" == "$want_out" && "$RC" -eq "$want_rc" && "$calls" -eq "$want_calls" ]]; then
        pass "$label"
    else
        fail "$label (stdout='$OUT' want '$want_out'; exit $RC want $want_rc; gh calls $calls want $want_calls; stderr: ${ERR:0:300})"
    fi
}
err_has() {  # <label> <fixed text>...
    local label="$1" t; shift
    for t in "$@"; do
        grep -qF -- "$t" <<< "$ERR" || { fail "$label: stderr does not say '$t' (stderr: ${ERR:0:400})"; return; }
    done
    pass "$label"
}
err_lacks() {  # <label> <fixed text>
    if grep -qF -- "$2" <<< "$ERR"; then fail "$1: stderr says '$2'"; else pass "$1"; fi
}

PINNED="repo view --json nameWithOwner --jq .nameWithOwner | cwd=%s GH_HOST=github.com GH_PROMPT_DISABLED=1"

echo "=== case 1: a qualified ref, any cwd, no git, no gh ==="
run "$ALPHA" "$BARE" -- "own/beta#7";  expect "own/beta#7 from alpha" "own/beta" 0 0
run "$BETA" "$BARE" -- "own/beta#7";   expect "own/beta#7 from beta" "own/beta" 0 0
run "$PLAIN" "$BARE" -- "own/beta#7";  expect "own/beta#7 from a folder in no git repository" "own/beta" 0 0
run "$PW" "$BARE" -- "up/pkg#7";       expect "up/pkg#7 from a package worktree's top folder" "up/pkg" 0 0
run "$PLAIN" "$BARE" -- "Own.x/re_po-1#12"; expect "owner and repo characters as parse_issue_ref allows them" "Own.x/re_po-1" 0 0

echo "=== case 2: origin is the only GitHub remote: decided locally ==="
run "$ALPHA" "$STUB_PATH" -- 7;  expect "alpha, bare 7: origin, no gh call" "own/alpha" 0 0
run "$ALPHA" "$NOGH" -- 7;       expect "alpha with no gh on PATH: origin (works offline)" "own/alpha" 0 0
run "$UPPER" "$NOGH" -- 7;       expect "origin with the host in upper case" "own/upper" 0 0
run "$SAME" "$NOGH" -- 7;        expect "another remote naming the same repository leaves no choice" "own/same" 0 0

echo "=== cases 3 and 4: gh asked when the local facts leave a choice ==="
run "$BETA" "$STUB_PATH" -- 7
expect "beta (upstream other/beta): gh names upstream, refused" "" 2 1
err_has "beta: names both repositories and the fixes" "own/beta" "other/beta" "gh repo set-default own/beta" "other/beta#7"
err_lacks "beta: never advises a default toward upstream" "set-default other/beta"
if [[ "$(head -n1 "$GH_LOG")" == "$(printf "$PINNED" "$BETA") stdin="* ]]; then
    pass "beta: gh asked once, the pinned invocation in the checkout (GH_HOST, no prompt)"
else
    fail "beta: unexpected gh call: $(head -n1 "$GH_LOG")"
fi
if [[ -e /proc/self/fd/0 ]]; then
    if grep -q 'stdin=/dev/null$' "$GH_LOG"; then pass "beta: gh's stdin is closed"
    else fail "beta: gh's stdin is not /dev/null: $(head -n1 "$GH_LOG")"; fi
fi
git -C "$BETA" config remote.origin.gh-resolved base
run "$BETA" "$STUB_PATH" -- 7;  expect "beta with origin as gh's default: gh asked, origin" "own/beta" 0 1
git -C "$BETA" config --unset remote.origin.gh-resolved
git -C "$ALPHA" config remote.origin.gh-resolved base
run "$ALPHA" "$STUB_PATH" -- 7; expect "a gh-resolved setting alone makes it ask gh" "own/alpha" 0 1
git -C "$ALPHA" config --unset remote.origin.gh-resolved
run "$ALPHA" "$STUB_PATH" GH_REPO=own/other -- 7
expect "GH_REPO naming another repository: refused" "" 2 1
err_has "GH_REPO: the message says gh used GH_REPO" "GH_REPO" "own/other" "own/alpha" "own/other#7"
err_lacks "GH_REPO: no set-default advice" "set-default"
run "$ALPHA" "$STUB_PATH" GH_REPO=own/alpha -- 7
expect "GH_REPO naming origin's repository: gh asked, origin" "own/alpha" 0 1
run "$GLUP" "$STUB_PATH" -- 7
expect "origin off GitHub, upstream on it: no GitHub repository here (exit 4), no gh call" "" 4 0

echo "=== cases 5 to 7 and A, B: package worktrees ==="
run "$PW/src/pkg" "$STUB_PATH" -- 7
expect "issue checkout, fork origin, gh names up/pkg through upstream" "up/pkg" 0 1
git -C "$PW/src/pkg" config remote.origin.gh-resolved base
run "$PW/src/pkg" "$STUB_PATH" -- 7
expect "issue checkout where gh names the fork: refused" "" 2 1
err_has "fork default: names the header and offers its default" "up/pkg#7" "gh repo set-default up/pkg" "fork/pkg"
err_lacks "fork default: never offers the fork as the default" "set-default fork/pkg"
git -C "$PW/src/pkg" config --unset remote.origin.gh-resolved
run "$PW3/src/pkg" "$NOGH" -- 8
expect "issue checkout whose origin is the header's repository: no gh call" "up/pkg" 0 0
mkdir -p "$PW/src/pkg/deep/er"
run "$PW/src/pkg/deep/er" "$STUB_PATH" -- 7
expect "a folder below the issue checkout counts as that checkout" "up/pkg" 0 1
# A: the sibling checkout.
run "$PW/src/sib" "$STUB_PATH" -- 7
expect "sibling checkout: its own origin decides, no gh call" "own/sib" 0 0
git -C "$PW/src/sib" remote add upstream "$(fr up/pkg)"
run "$PW/src/sib" "$STUB_PATH" -- 7
expect "sibling checkout with an upstream naming the header's repository: refused" "" 2 1
err_has "sibling: advises its own origin" "gh repo set-default own/sib"
err_lacks "sibling: never advises the header's repository" "set-default up/pkg"
git -C "$PW/src/sib" remote remove upstream
# B: the top folder.
run "$PW" "$STUB_PATH" -- 7
expect "package worktree's top folder (no git): exit 3, no gh call" "" 3 0
err_has "top folder: names the header's ref and the issue checkout" "up/pkg#7" "$PW/src/pkg"
run "$PWH" "$STUB_PATH" -- 7
expect "top folder inside another git repository: exit 3, no gh call" "" 3 0
err_has "top folder in another repository: names the header's ref" "up/pkg#7"
run "$PWH/src/pkg" "$STUB_PATH" -- 7
expect "issue checkout under a top folder inside another repository" "up/pkg" 0 1
# Headers that do not count.
run "$PW4/src/q" "$NOGH" -- 9
expect "a header naming another number is ignored: origin, no gh call" "own/q" 0 0
run "$PW5/src/q" "$NOGH" -- 7
expect "a bare issue=7 header is ignored: origin, no gh call" "own/q" 0 0
run "$PW4/src/q" "$STUB_PATH" -- 7
expect "a header for this number whose repository is not origin's: gh asked, refused" "" 2 1
err_has "hdr/x#7: offers the header's default" "gh repo set-default hdr/x"
run "$PW/src/pkg" "$STUB_PATH" -- 9
expect "issue checkout, another number: the header is ignored, origin vs upstream refused" "" 2 1
err_has "another number: advises the checkout's own origin" "gh repo set-default fork/pkg"

echo "=== case 8: gh asked and cannot answer ==="
run "$BETA" "$STUB_PATH" GH_STUB=fail -- 7
expect "gh not logged in: exit 5" "" 5 1
err_has "gh not logged in: quotes gh and names the qualified form" "not logged in" "own/beta#7"
run "$BETA" "$STUB_PATH" GH_STUB=silent -- 7
expect "gh silent: exit 5" "" 5 1
err_has "gh silent: says so" "gh gave no answer"
run "$BETA" "$NOGH" -- 7
expect "no gh on PATH with an upstream: exit 5" "" 5 0
err_has "no gh: says gh is not installed" "gh is not installed"
run "$PW/src/pkg" "$NOGH" -- 7
expect "no gh in a fork-origin issue checkout: exit 5" "" 5 0
err_has "no gh in the package checkout: names the header's ref" "up/pkg#7"

echo "=== case 9: not inside a git repository ==="
run "$PLAIN" "$STUB_PATH" -- 7
expect "folder in no git repository: exit 3, no gh call" "" 3 0
err_has "no git: names the qualified form" "owner/repo#7"

echo "=== case 10: no GitHub repository ==="
run "$NOREM" "$STUB_PATH" -- 7;  expect "no remote at all: exit 4, no gh call" "" 4 0
err_has "no remote: a note, not an error" "no gh call will be made"
run "$GITLAB" "$STUB_PATH" -- 7; expect "origin on another host: exit 4, no gh call" "" 4 0

echo "=== case 11: bad ref ==="
for bad in abc o/r 'o/r#' '' '#7' 'o/r#7x' 'a/b/c#7'; do
    run "$ALPHA" "$STUB_PATH" -- "$bad"
    expect "bad ref '$bad': exit 1" "" 1 0
done
run "$ALPHA" "$STUB_PATH" --
expect "no argument: exit 1" "" 1 0
run "$ALPHA" "$STUB_PATH" -- 7 8
expect "two arguments: exit 1" "" 1 0

echo ""
echo "test_issue_repo: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
