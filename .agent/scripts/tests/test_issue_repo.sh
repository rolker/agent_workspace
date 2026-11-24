#!/usr/bin/env bash
# .agent/scripts/tests/test_issue_repo.sh
# Tests for .agent/scripts/issue_repo.sh (issue 581): the repository the
# review-issue, plan-task and review-plan skills name on every gh call.
#
# Each case checks stdout, the exit code and the gh call log, against the
# contract table in the script's header:
#   - a qualified owner/repo#N is printed as given only when owner/repo is
#     this checkout's repository (no gh call); another repository, or none,
#     is refused (exit 6: the session-root rule), and so is any qualified
#     ref where no GitHub repository is read from origin (another host, an
#     SSH host alias, no origin), with no gh call;
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
#   - a package worktree's top folder (whatever its header), and a matching
#     header whose issue checkout cannot be found: exit 3;
#   - no git repository: exit 3; no GitHub remote: exit 4; a bad ref
#     (leading zeros included): 1;
#   - plan-task step 8's block, run as written in the skill: the draft pull
#     request's head names origin's owner when origin is a fork of the
#     repository the helper names, an existing pull request is taken only
#     from that head's owner (two from it: stop), and an issue title holding a backtick,
#     $(...) and $VAR reaches gh literally, with nothing run;
#   - plan-task steps 6 and 7, each in a fresh shell: the plan commit and
#     the Plan Authored entry's plan-commit SHA, free text kept literal;
#   - review-plan's file path form: a plan in this checkout goes on, a plan
#     in another checkout (or one nested in this one's tree) is refused.
#
# Hermetic: one mktemp -d sandbox with its own HOME and git config;
# remotes are only URLs (nothing is fetched), local ones of the form
# <sandbox>/fake_remotes/github.com/<owner>/<repo>.git, the only local form
# extract_gh_slug reads as a GitHub repository; a stub gh on the PATH
# answers `gh repo view` the way real gh picks a remote (GH_REPO, a remote
# with gh-resolved=base, upstream, github, origin) and logs every call. No network, no real repository touched.
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
# plan-task step 8's pull request calls, logged above. `pr list` answers from
# the JSON file GH_STUB_PRS (none: no pull request): the entries whose
# headRefName is the --head value, through the --jq expression, as gh does.
if [ "$1 $2" = "pr list" ]; then
    head="" jqx="."
    while [ $# -gt 0 ]; do
        case "$1" in --head) head="$2"; shift ;; --jq) jqx="$2"; shift ;; esac
        shift
    done
    [ -n "${GH_STUB_PRS:-}" ] || exit 0
    jq --arg h "$head" '[.[] | select(.headRefName == $h)]' "$GH_STUB_PRS" | jq -r "$jqx"
    exit
fi
case "$1 $2" in "pr create"|"pr edit") exit 0 ;; esac
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
ALIAS="$SANDBOX/alias";  mkrepo "$ALIAS" "origin=git@github-work:own/alias.git"
ALIASUP="$SANDBOX/aliasup"; mkrepo "$ALIASUP" "origin=git@github-work:own/aliasup.git" "upstream=$(fr other/x)"
CHARS="$SANDBOX/chars";  mkrepo "$CHARS" "origin=$(fr Own-x_1/re_po.x-1)"

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
# PW6 for up/pkg#7 whose manifest puts no entry on feature/issue-7: the
# issue checkout cannot be found (issue_checkout_of refuses).
PW6="$SANDBOX/pw6"
mkdir -p "$PW6/src"
printf '# project=p issue=up/pkg#7 layer=main\n%s\tsrc/pkg\tfeature/other\n' "$(fr up/pkg)" > "$PW6/.worktree-repos"
mkrepo "$PW6/src/pkg" "origin=$(fr up/pkg)"
# PWH5: a bare issue=7 header, its top folder inside another repository.
PWH5="$HOSTREPO/wt5"
mkdir -p "$PWH5/src"
cp "$PW5/.worktree-repos" "$PWH5/.worktree-repos"

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

echo "=== case 1: a qualified ref names this checkout's repository, or is refused ==="
run "$BETA" "$NOGH" -- "own/beta#7";   expect "own/beta#7 from beta (upstream other/beta): this checkout's, no gh call" "own/beta" 0 0
run "$ALPHA" "$NOGH" -- "OWN/Alpha#7"; expect "case ignored, printed in this checkout's casing" "own/alpha" 0 0
run "$CHARS" "$NOGH" -- "Own-x_1/re_po.x-1#12"; expect "owner and repo characters a GitHub repository may hold" "Own-x_1/re_po.x-1" 0 0
run "$ALPHA" "$STUB_PATH" -- "own/beta#7"
expect "own/beta#7 from alpha: another repository's issue, refused (exit 6), no gh call" "" 6 0
err_has "foreign ref: names both repositories and where to run from" "own/beta#7" "own/alpha" "run this from a checkout of own/beta"
run "$BETA" "$STUB_PATH" -- "other/beta#7"
expect "other/beta#7 from beta, whose upstream it is: refused, no gh call" "" 6 0
run "$PLAIN" "$STUB_PATH" -- "own/beta#7"
expect "own/beta#7 from a folder in no git repository: exit 3, no gh call" "" 3 0
err_has "qualified ref, no git: says where to run from" "Run from a checkout of own/beta"
run "$PW" "$STUB_PATH" -- "up/pkg#7"
expect "up/pkg#7 from a package worktree's top folder: exit 3, no gh call" "" 3 0
err_has "qualified ref, top folder: names the issue checkout" "$PW/src/pkg"
run "$PW/src/pkg" "$NOGH" -- "up/pkg#7"
expect "up/pkg#7 in its issue checkout (origin the fork): the header's repository, no gh call" "up/pkg" 0 0
run "$PW/src/pkg" "$NOGH" -- "UP/Pkg#7"
expect "UP/Pkg#7 there: printed in the header's casing" "up/pkg" 0 0
run "$PW/src/pkg" "$STUB_PATH" -- "fork/pkg#7"
expect "fork/pkg#7 in up/pkg#7's issue checkout: refused" "" 6 0
err_has "fork ref in the issue checkout: says the header decides" "up/pkg's (from the package worktree's manifest)"
run "$PW/src/pkg" "$NOGH" -- "fork/pkg#9"
expect "fork/pkg#9 there (another number: the header is ignored, origin decides)" "fork/pkg" 0 0
run "$PW/src/sib" "$STUB_PATH" -- "up/pkg#7"
expect "up/pkg#7 in the sibling checkout: refused" "" 6 0
run "$PW/src/sib" "$NOGH" -- "own/sib#7"
expect "own/sib#7 in the sibling checkout: its own" "own/sib" 0 0
echo "--- no GitHub repository read from origin: a qualified ref is refused, no gh call ---"
run "$ALIAS" "$STUB_PATH" -- 7
expect "SSH host alias origin, bare 7: exit 4, no gh call" "" 4 0
err_has "exit 4 names the SSH alias case" "SSH host alias" "ssh.github.com:443" "only an origin URL on github.com"
run "$ALIAS" "$STUB_PATH" -- "own/alias#7"
expect "SSH host alias origin, its own repository's ref: cannot be shown, refused" "" 6 0
err_has "no GitHub origin: says why and what works" "cannot be shown to be its repository" "whose origin is on github.com" "pass the bare number 7"
run "$ALIAS" "$STUB_PATH" -- "own/other#7"
expect "SSH host alias origin, another repository: refused" "" 6 0
# The two cases where gh, asked, would answer with upstream, not origin.
run "$GLUP" "$STUB_PATH" -- "own/glup#7"
expect "origin on another host beside a GitHub upstream: upstream's ref refused, no gh call" "" 6 0
run "$ALIASUP" "$STUB_PATH" -- "other/x#7"
expect "SSH alias origin beside a GitHub upstream: upstream's ref refused, no gh call" "" 6 0
run "$ALIASUP" "$STUB_PATH" -- "own/aliasup#7"
expect "SSH alias origin beside a GitHub upstream: origin's own ref refused too (cannot be shown), no gh call" "" 6 0
run "$NOREM" "$STUB_PATH" GH_REPO=own/x -- "own/x#7"
expect "no remote, GH_REPO naming the ref: refused, no gh call" "" 6 0
run "$GITLAB" "$STUB_PATH" -- "o/r#7"
expect "origin on another host: a qualified ref is refused, no gh call" "" 6 0

echo "=== case 2: origin is the only GitHub remote: decided locally ==="
run "$ALPHA" "$STUB_PATH" -- 7;  expect "alpha, bare 7: origin, no gh call" "own/alpha" 0 0
run "$ALPHA" "$NOGH" -- 7;       expect "alpha with no gh on PATH: origin (works offline)" "own/alpha" 0 0
run "$UPPER" "$NOGH" -- 7;       expect "origin with the host in upper case" "own/upper" 0 0
run "$SAME" "$NOGH" -- 7;        expect "another remote naming the same repository leaves no choice" "own/same" 0 0

echo "=== cases 3 and 4: gh asked when the local facts leave a choice ==="
run "$BETA" "$STUB_PATH" -- 7
expect "beta (upstream other/beta): gh names upstream, refused" "" 2 1
err_has "beta: names both repositories and the fixes" "own/beta" "other/beta" "gh repo set-default own/beta" "pass own/beta#7" "a checkout of other/beta"
err_lacks "beta: never advises passing the other repository's ref" "pass other/beta#7"
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
err_has "GH_REPO: the message says gh used GH_REPO" "GH_REPO" "own/other" "own/alpha" "Unset GH_REPO" "own/alpha#7"
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
run "$PW/src/pkg" "$STUB_PATH" GH_REPO=fork/pkg -- 7
expect "issue checkout with GH_REPO naming the fork: refused" "" 2 1
err_has "GH_REPO in the issue checkout: says to unset it" "Unset GH_REPO" "up/pkg#7"
err_lacks "GH_REPO in the issue checkout: no set-default advice, which GH_REPO overrides" "set-default"
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
run "$PWH" "$STUB_PATH" -- 9
expect "top folder inside another repository, another number: still exit 3, not the host's origin" "" 3 0
err_has "top folder, another number: names the worktree's issue" "The worktree is for up/pkg#7"
run "$PWH5" "$STUB_PATH" -- 7
expect "top folder inside another repository, bare issue=7 header: exit 3, not the host's origin" "" 3 0
mkdir -p "$PWH/src/notrepo"
run "$PWH/src/notrepo" "$STUB_PATH" -- 7
expect "a folder of the worktree that is no checkout: exit 3" "" 3 0
run "$PW" "$STUB_PATH" -- 9
expect "top folder (no git), another number: exit 3" "" 3 0
# S1: a matching header whose issue checkout cannot be found.
run "$PW6/src/pkg" "$STUB_PATH" -- 7
expect "a matching header with no entry on feature/issue-7: exit 3, as the dispatcher refuses" "" 3 0
err_has "no issue checkout: quotes issue_checkout_of and names the branch" "its issue checkout cannot be found" "feature/issue-7"
run "$PW6/src/pkg" "$NOGH" -- 8
expect "the same checkout, another number: the header is ignored, origin decides" "up/pkg" 0 0
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
err_has "no git: says where to run from" "Run from the checkout of the repository that owns issue 7"

echo "=== case 10: no GitHub repository ==="
run "$NOREM" "$STUB_PATH" -- 7;  expect "no remote at all: exit 4, no gh call" "" 4 0
err_has "no remote: a note, not an error" "no gh call will be made"
run "$GITLAB" "$STUB_PATH" -- 7; expect "origin on another host: exit 4, no gh call" "" 4 0

echo "=== case 11: bad ref ==="
for bad in abc o/r 'o/r#' '' '#7' 'o/r#7x' 'a/b/c#7' 0 007 'own/alpha#07' 'own/alpha#0'; do
    run "$ALPHA" "$STUB_PATH" -- "$bad"
    expect "bad ref '$bad': exit 1" "" 1 0
done
run "$ALPHA" "$STUB_PATH" --
expect "no argument: exit 1" "" 1 0
run "$ALPHA" "$STUB_PATH" -- 008
err_has "leading zeros: says why" "without leading zeros"
run "$ALPHA" "$STUB_PATH" -- 7 8
expect "two arguments: exit 1" "" 1 0

echo "=== plan-task step 8: the draft pull request's head, and the title kept literal ==="
# The block exactly as the skill writes it, placeholders filled in. Its
# WS_ROOT comes from ~/.claude/agent-workspace-root (this checkout, so it
# runs this branch's scripts); origin is a bare repository at a
# fake_remotes path, so the push is local.
SKILL="$(cd "$SCRIPT_DIR/../../.." && pwd)/.claude/skills/plan-task/SKILL.md"
mkdir -p "$HOME/.claude"
(cd "$SCRIPT_DIR/../../.." && pwd) > "$HOME/.claude/agent-workspace-root"
STEP8=$(awk '/^### 8\. /{s=1} s && /^```bash$/{b=1; next} b && /^```$/{exit} b' "$SKILL")
TITLE='`touch PWNED1` $(touch PWNED2) $HOME it'"'"'s "q"'
STEP8=${STEP8//"<ref>"/7}
STEP8=${STEP8//"<N>"/7}
STEP8=${STEP8//"<issue title>"/"$TITLE"}
mkplanrepo() {  # <dir> <origin slug> [upstream slug]
    local d="$1"
    git init -q --bare "$(fr "$2")"
    mkrepo "$d" "origin=$(fr "$2")" ${3:+"upstream=$(fr "$3")"}
    git -C "$d" checkout -q -b feature/issue-7
    mkdir -p "$d/.agent/work-plans/issue-7"
    echo "# Plan" > "$d/.agent/work-plans/issue-7/plan.md"
    git -C "$d" add -A && git -C "$d" commit -q -m plan
}
run_step8() {  # <dir> [<pull requests JSON>]
    : > "$GH_LOG"
    local prs=""
    if [[ -n "${2:-}" ]]; then prs="$SANDBOX/prs.json"; printf '%s\n' "$2" > "$prs"; fi
    OUT=$(cd "$1" && env -u WORKTREE_ISSUE GH_STUB_PRS="$prs" PATH="$STUB_PATH" "$BASH_BIN" -c "$STEP8" 2>&1 </dev/null); RC=$?
}
pr_json() {  # <owner:url>...: open pull requests on feature/issue-7
    local sep="" o
    printf '['
    for o in "$@"; do
        printf '%s{"url":"%s","headRefName":"feature/issue-7","headRepositoryOwner":{"login":"%s"}}' "$sep" "${o#*:}" "${o%%:*}"
        sep=","
    done
    printf ']'
}
if [[ -z "$STEP8" ]] || ! grep -q 'gh pr create' <<< "$STEP8"; then
    fail "plan-task step 8: the block was not found in $SKILL"
else
    # The fork-origin package checkout: origin fork2/pkg, the header up/pkg#7.
    PW7="$SANDBOX/pw7"
    mkdir -p "$PW7/src"
    printf '# project=p issue=up/pkg#7 layer=main\n%s\tsrc/pkg\tfeature/issue-7\n' "$(fr fork2/pkg)" > "$PW7/.worktree-repos"
    mkplanrepo "$PW7/src/pkg" fork2/pkg up/pkg
    run_step8 "$PW7/src/pkg"
    created=$(grep '^pr create ' "$GH_LOG")
    if [[ $RC -eq 0 && "$created" == "pr create -R github.com/up/pkg --draft --head fork2:feature/issue-7 --title [PLAN] $TITLE --body-file "* ]]; then
        pass "fork origin: the pull request goes to up/pkg with --head fork2:feature/issue-7, the title literal"
    else
        fail "fork origin: exit $RC; gh pr create: '${created:-none}'; output: ${OUT:0:400}"
    fi
    if git --git-dir="$(fr fork2/pkg)" rev-parse -q --verify refs/heads/feature/issue-7 >/dev/null; then
        pass "fork origin: the branch was pushed to origin"
    else
        fail "fork origin: the branch is not on origin"
    fi
    # The ordinary case: origin is the repository the helper names.
    PLANR="$SANDBOX/planr"
    mkplanrepo "$PLANR" own/planr
    run_step8 "$PLANR"
    created=$(grep '^pr create ' "$GH_LOG")
    if [[ $RC -eq 0 && "$created" == "pr create -R github.com/own/planr --draft --head feature/issue-7 --title [PLAN] $TITLE --body-file "* ]]; then
        pass "origin is the repository: --head is the bare branch"
    else
        fail "origin is the repository: exit $RC; gh pr create: '${created:-none}'; output: ${OUT:0:400}"
    fi
    # Another fork's pull request on the same branch name is never edited.
    run_step8 "$PW7/src/pkg" "$(pr_json Someone:https://x/pull/2 FORK2:https://x/pull/1)"
    edited=$(grep '^pr edit ' "$GH_LOG")
    if [[ $RC -eq 0 && "$edited" == "pr edit https://x/pull/1 -R github.com/up/pkg "* ]] && ! grep -q '^pr create ' "$GH_LOG"; then
        pass "fork origin: of two pull requests on the branch name, the one from fork2 is edited (owner compared without case)"
    else
        fail "fork origin, two pull requests: exit $RC; gh log: $(cut -c1-200 "$GH_LOG" | tr '\n' ' '); output: ${OUT:0:300}"
    fi
    run_step8 "$PLANR" "$(pr_json someone:https://x/pull/2)"
    if [[ $RC -eq 0 ]] && ! grep -q '^pr edit ' "$GH_LOG" && grep -q '^pr create .*--head feature/issue-7 ' "$GH_LOG"; then
        pass "only another owner's pull request on the branch name: not edited, a new one is created"
    else
        fail "another owner's pull request only: exit $RC; gh log: $(cut -c1-200 "$GH_LOG" | tr '\n' ' '); output: ${OUT:0:300}"
    fi
    run_step8 "$PLANR" "$(pr_json own:https://x/pull/3 own:https://x/pull/4)"
    if [[ $RC -ne 0 ]] && ! grep -qE '^pr (edit|create) ' "$GH_LOG" && grep -qF 'https://x/pull/3' <<< "$OUT" && grep -qF 'https://x/pull/4' <<< "$OUT"; then
        pass "two pull requests from this head: stops and lists them, edits none"
    else
        fail "two pull requests from this head: exit $RC; gh log: $(cut -c1-200 "$GH_LOG" | tr '\n' ' '); output: ${OUT:0:300}"
    fi
    if compgen -G "$SANDBOX/**/PWNED*" >/dev/null || [[ -e "$PW7/src/pkg/PWNED1" || -e "$PW7/src/pkg/PWNED2" || -e "$PLANR/PWNED1" || -e "$PLANR/PWNED2" ]]; then
        fail "the issue title ran a command"
    else
        pass "the issue title ran no command"
    fi
fi

echo "=== plan-task steps 6 and 7: each block in a fresh shell ==="
# Steps 6 and 7 as the skill writes them, each run in its own shell (no
# WORK_PLANS_DIR or PLAN_SHA carried over): the plan commit and the
# Plan Authored entry with the plan-commit SHA; the summary and the title,
# holding a backtick, $(...) and $HOME, kept literal.
step_block() {  # <heading regex>
    awk -v h="$1" '$0 ~ h {s=1} s && /^```bash$/{b=1; next} b && /^```$/{exit} b' "$SKILL"
}
fill() {  # <block>: the placeholders filled in, hostile free text
    local b="$1"
    b=${b//"<ref>"/7}; b=${b//"<N>"/7}
    b=${b//"<issue title>"/"$TITLE"}
    b=${b//"<one-line summary of the approach>"/"$TITLE"}
    b=${b//"<1-2 sentence summary of the approach>"/"$TITLE"}
    b=${b//"<YYYY-MM-DD HH:MM ±HH:MM>"/"2026-11-24 14:00 -05:00"}
    b=${b//"<agent name> (<model>)"/"t (m)"}
    b=${b//" [--strict]"/}
    printf '%s' "$b"
}
STEP6=$(fill "$(step_block '^### 6\\. ')")
STEP7=$(fill "$(step_block '^### 7\\. ')")
if [[ "$STEP6" != *"git commit"* || "$STEP7" != *"persist"* ]]; then
    fail "plan-task steps 6 and 7: the blocks were not found in $SKILL"
else
    P67="$SANDBOX/p67"
    mkplanrepo "$P67" own/p67
    echo "more" >> "$P67/.agent/work-plans/issue-7/plan.md"
    OUT=$(cd "$P67" && env -u WORKTREE_ISSUE PATH="$STUB_PATH" "$BASH_BIN" -c "$STEP6" 2>&1 </dev/null); RC=$?
    sha6=$(git -C "$P67" rev-parse --short HEAD)
    msg=$(git -C "$P67" log -1 --format=%B)
    if [[ $RC -eq 0 && "$msg" == *"$TITLE"* && "$OUT" == *"$sha6"* ]]; then
        pass "step 6 in a fresh shell: commits the plan with the summary literal and prints its SHA"
    else
        fail "step 6: exit $RC; message: ${msg:0:200}; output: ${OUT:0:300}"
    fi
    OUT=$(cd "$P67" && env -u WORKTREE_ISSUE PATH="$STUB_PATH" "$BASH_BIN" -c "$STEP7" 2>&1 </dev/null); RC=$?
    prog="$P67/.agent/work-plans/issue-7/progress.md"
    if [[ $RC -eq 0 ]] && grep -qxF "**Plan**: \`.agent/work-plans/issue-7/plan.md\` at \`$sha6\`" "$prog" 2>/dev/null \
        && grep -qxF "$TITLE" "$prog"; then
        pass "step 7 in a fresh shell: the Plan line names the plan and its commit, the summary literal"
    else
        fail "step 7: exit $RC; output: ${OUT:0:300}; progress: $(head -c 600 "$prog" 2>/dev/null)"
    fi
    if [[ -e "$P67/PWNED1" || -e "$P67/PWNED2" ]]; then
        fail "steps 6 and 7: free text ran a command"
    else
        pass "steps 6 and 7: free text ran no command"
    fi
fi

echo "=== review-plan's file path form: only a plan in this checkout ==="
# The block as the skill writes it, run from sandbox checkout RA with the
# path of a plan in RA, in another checkout RB, and in a checkout nested
# inside RA's tree (as worktrees sit inside the workspace checkout).
RPSKILL="$(cd "$SCRIPT_DIR/../../.." && pwd)/.claude/skills/review-plan/SKILL.md"
FPB=$(awk '/^\*\*File path\*\* /{s=1} s && /^```bash$/{b=1; next} b && /^```$/{exit} b' "$RPSKILL")
run_fp() {  # <cwd> <plan path>
    local blk=${FPB//"<ref>"/45}
    blk=${blk//"<path-to-plan.md>"/"$2"}
    : > "$GH_LOG"
    OUT=$(cd "$1" && env -u WORKTREE_ISSUE PATH="$STUB_PATH" "$BASH_BIN" -c "$blk" 2>&1 </dev/null); RC=$?
}
if [[ "$FPB" != *'_OWN'* ]]; then
    fail "review-plan file path form: the block was not found in $RPSKILL"
else
    RA="$SANDBOX/ra"; RB="$SANDBOX/rb"
    for r in "$RA" "$RB" "$RA/worktrees/nested"; do
        mkrepo "$r" "origin=$(fr "own/$(basename "$r")")"
        mkdir -p "$r/.agent/work-plans/issue-45"
        echo "# Plan" > "$r/.agent/work-plans/issue-45/plan.md"
    done
    run_fp "$RA" "./.agent/work-plans/issue-45/plan.md"
    if [[ $RC -eq 0 && "$OUT" == *"Plan: ./.agent/work-plans/issue-45/plan.md"* ]]; then
        pass "file path form: a plan in this checkout goes on"
    else
        fail "file path form, own plan: exit $RC; output: ${OUT:0:300}"
    fi
    run_fp "$RA" "$RB/.agent/work-plans/issue-45/plan.md"
    if [[ $RC -ne 0 && "$OUT" == *"is in $RB, not in this checkout ($RA)"* && "$OUT" == *"Run review-plan from $RB."* && "$OUT" != *"Plan: "* ]]; then
        pass "file path form: a plan in another checkout is refused, naming its checkout"
    else
        fail "file path form, another checkout's plan: exit $RC; output: ${OUT:0:300}"
    fi
    run_fp "$RA" "./worktrees/nested/.agent/work-plans/issue-45/plan.md"
    if [[ $RC -ne 0 && "$OUT" == *"is in $RA/worktrees/nested, not in this checkout"* ]]; then
        pass "file path form: a plan in a checkout nested in this one's tree is refused"
    else
        fail "file path form, nested checkout's plan: exit $RC; output: ${OUT:0:300}"
    fi
fi

echo ""
echo "test_issue_repo: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
