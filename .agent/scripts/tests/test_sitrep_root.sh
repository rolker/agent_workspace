#!/usr/bin/env bash
# .agent/scripts/tests/test_sitrep_root.sh
# Tests for .agent/scripts/sitrep_root.sh (issue #418): the root the sit-rep
# reports on (the session's own, never a fallback to the workspace), what
# can be read there, and which worktrees that root's report lists.
#
# Hermetic: a sandbox workspace (a git repository holding a copy of the
# checkout's .agent/scripts and .agent/project_types), a sandbox registry of
# synthetic project roots, and real git worktrees, all under one
# `mktemp -d` sandbox (honours TMPDIR). HOME is redirected; no gh call, no
# network, no real hosted project.
#
# Run: bash .agent/scripts/tests/test_sitrep_root.sh

set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SB="$(mktemp -d)"
SB="$(cd "$SB" && pwd -P)"
trap 'rm -rf "$SB"' EXIT
GIT_CEILING_DIRECTORIES="$(dirname "$SB")"
export GIT_CEILING_DIRECTORIES
export HOME="$SB/home"
mkdir -p "$HOME"
g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }

[[ -f "$SRC/sitrep_root.sh" ]] || fail "script under test missing: sitrep_root.sh"

# --- the sandbox workspace ---------------------------------------------------
WSC="$SB/ws"
mkdir -p "$WSC/.agent" "$WSC/docs" "$WSC/.agent/knowledge" "$WSC/projects/inner"
cp -r "$SRC" "$WSC/.agent/scripts"
cp -r "$SRC/../project_types" "$WSC/.agent/project_types"
rm -rf "$WSC/.agent/scripts/tests"
printf '# Design\n' > "$WSC/docs/design.md"
printf '# Digest\n' > "$WSC/.agent/knowledge/research_digest.md"
printf '## Direction\n' > "$WSC/docs/roadmap.md"
printf 'x\n' > "$WSC/projects/inner/README.md"
g -C "$WSC" init -q
g -C "$WSC" remote add origin https://github.com/acme/ws.git
g -C "$WSC" add -A && g -C "$WSC" commit -q -m init
SR="$WSC/.agent/scripts/sitrep_root.sh"

# --- the project roots ------------------------------------------------------
R="$SB/roots"
mkroot() {  # <name> <remote or -> : a git root with one commit on main
    mkdir -p "$R/$1"
    g -C "$R/$1" init -q
    [[ "$2" == - ]] || g -C "$R/$1" remote add origin "$2"
    g -C "$R/$1" commit -q --allow-empty -m init
}
mkroot proj https://github.com/acme/proj.git
mkdir -p "$R/proj/docs"
printf '# Roadmap\n\n## Direction\n\n| Line | Check |\n|---|---|\n| A file | file-exists docs/roadmap.md |\n' > "$R/proj/docs/roadmap.md"
mkroot noroad https://github.com/acme/noroad.git
mkroot both https://github.com/acme/both.git
mkdir -p "$R/both/docs"; printf 'a\n' > "$R/both/docs/roadmap.md"; printf 'b\n' > "$R/both/ROADMAP.md"
mkroot onlyr https://github.com/acme/onlyr.git
printf '# Roadmap\n\nNo section here.\n' > "$R/onlyr/ROADMAP.md"
mkroot named-ws https://github.com/acme/named-ws.git
mkroot trunk https://github.com/acme/trunk.git
g -C "$R/trunk" branch -q -m main trunk
g -C "$R/trunk" update-ref refs/remotes/origin/trunk HEAD
g -C "$R/trunk" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
mkroot nodefault -
g -C "$R/nodefault" branch -q -m main dev
mkroot twodefault -
g -C "$R/twodefault" branch -q master
mkroot other https://github.com/acme/other.git
mkroot dangling https://github.com/acme/dangling.git
g -C "$R/dangling" update-ref refs/remotes/origin/develop HEAD
g -C "$R/dangling" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
mkroot forms https://github.com/acme/forms.git
mkroot gitlab git@gitlab.com:acme/proj.git
mkdir -p "$R/host"
mkroot host/inst https://github.com/acme/inst.git
cat > "$WSC/.agent/projects.local" <<REG
proj        single_project  $R/proj
noroad      single_project  $R/noroad
both        single_project  $R/both
onlyr       single_project  $R/onlyr
workspace   single_project  $R/named-ws
trunk       single_project  $R/trunk
nodefault   single_project  $R/nodefault
twodefault  single_project  $R/twodefault
other       single_project  $R/other
dangling    single_project  $R/dangling
forms       single_project  $R/forms
gitlab      single_project  $R/gitlab
inst        single_project  $R/host/inst  parent=host
host        project         $R/host
inner       single_project  $WSC/projects/inner
REG

# root_of <dir>: runs the helper from <dir>; sets OUT, ERR, RC
root_of() {
    RC=0
    OUT="$(cd "$1" && bash "$SR" 2>"$SB/err")" || RC=$?
    ERR="$(cat "$SB/err")"
}
val() { sed -n "s/^$1=//p" <<< "$OUT"; }

echo "TEST: the workspace root: every check runs, the record name is workspace"
root_of "$WSC"
[[ $RC -eq 0 && "$(val root)" == "$WSC" && "$(val type)" == workspace && "$(val record_name)" == workspace \
    && "$(val roadmap)" == "$WSC/docs/roadmap.md" && "$(val own_repo)" == yes && "$(val default_branch)" == main \
    && "$(val pr_source)" == acme/ws ]] \
    && pass "workspace: root, type, record name, roadmap, own repository, default branch, pull-request source" \
    || fail "workspace: rc=$RC '$OUT' err='$ERR'"
[[ "$(grep -c '^check_.*=run$' <<< "$OUT")" -eq 4 && "$(grep -c '^check_' <<< "$OUT")" -eq 4 ]] \
    && pass "workspace: all four Problems checks run" || fail "workspace checks: '$OUT'"
mkdir -p "$WSC/worktrees/workspace"
g -C "$WSC" worktree add -q -b feature/issue-3 "$WSC/worktrees/workspace/issue-workspace-3" 2>/dev/null
root_of "$WSC/worktrees/workspace/issue-workspace-3"
[[ $RC -eq 0 && "$(val root)" == "$WSC" && "$(val type)" == workspace ]] \
    && pass "workspace: a session in a workspace worktree reports the main checkout" || fail "workspace worktree: rc=$RC '$OUT' err='$ERR'"

echo "TEST: a project root with a Direction section in docs/roadmap.md"
root_of "$R/proj"
[[ $RC -eq 0 && "$(val root)" == "$R/proj" && "$(val type)" == project && "$(val project)" == proj \
    && "$(val record_name)" == proj && "$(val roadmap)" == "$R/proj/docs/roadmap.md" \
    && "$(val own_repo)" == yes && "$(val pr_source)" == acme/proj ]] \
    && pass "project: its own root, record name and roadmap, never the workspace's" || fail "project: rc=$RC '$OUT' err='$ERR'"
[[ "$(val check_decision_register)" == "skipped (docs/design.md not in this root)" \
    && "$(val check_research_digest)" == "skipped (.agent/knowledge/research_digest.md not in this root)" \
    && "$(val check_design_anchors)" == "skipped (docs/design.md not in this root)" \
    && "$(val check_documentation)" == "skipped (docs/design.md not in this root)" ]] \
    && pass "project: each workspace-shaped check is skipped, naming the file" || fail "project checks: '$OUT'"
OUTR="$(bash "$WSC/.agent/scripts/sitrep_checks.sh" --root "$R/proj" --roadmap "$(val roadmap)" 2>&1)"
[[ "$(cut -f1-3 <<< "$OUTR")" == $'line\tA file\ttrue' ]] \
    && pass "project: the check runner reads the project's own Direction rows" || fail "project rows: '$OUTR'"

echo "TEST: a project root's own design files turn its checks on"
mkdir -p "$R/other/docs" "$R/other/.agent/knowledge"
printf '# D\n' > "$R/other/docs/design.md"; printf '# R\n' > "$R/other/.agent/knowledge/research_digest.md"
root_of "$R/other"
[[ "$(grep -c '^check_.*=run$' <<< "$OUT")" -eq 4 ]] && pass "project with its own docs/design.md and digest: the checks run" || fail "other checks: '$OUT'"

echo "TEST: no roadmap, or a roadmap with no Direction section"
root_of "$R/noroad"
[[ $RC -eq 0 && "$(val roadmap)" == "" && "$OUT" == *$'\nroadmap=\n'* ]] \
    && pass "no roadmap: roadmap= is empty" || fail "noroad: rc=$RC '$OUT'"
root_of "$R/onlyr"
[[ "$(val roadmap)" == "$R/onlyr/ROADMAP.md" ]] && pass "only ROADMAP.md: it is the roadmap" || fail "onlyr: '$OUT'"
OUTR="$(bash "$WSC/.agent/scripts/sitrep_checks.sh" --root "$R/onlyr" --roadmap "$(val roadmap)" 2>&1)"
[[ "$(cut -f1-3 <<< "$OUTR")" == $'section\t(no Direction section)\tunchecked' ]] \
    && pass "no Direction section: one section row, no line invented" || fail "onlyr rows: '$OUTR'"
root_of "$R/both"
[[ "$(val roadmap)" == "$R/both/docs/roadmap.md" ]] && pass "both present: docs/roadmap.md comes first" || fail "both: '$OUT'"

echo "TEST: roots with no git repository of their own"
root_of "$R/host"
[[ $RC -eq 0 && "$(val type)" == project && "$(val project)" == host && "$(val own_repo)" == no \
    && "$(val pr_source)" == none && "$(val default_branch)" == "" ]] \
    && pass "hosting root with no repository: own_repo=no, pr_source=none, no default branch" || fail "host: rc=$RC '$OUT' err='$ERR'"
root_of "$WSC/projects/inner"
[[ $RC -eq 0 && "$(val root)" == "$WSC/projects/inner" && "$(val own_repo)" == no && "$(val pr_source)" == none ]] \
    && pass "a registered root inside the workspace tree: not the workspace's repository" || fail "inner: rc=$RC '$OUT' err='$ERR'"
mkdir -p "$WSC/projects/inner/docs"; printf '# D\n' > "$WSC/projects/inner/docs/design.md"
root_of "$WSC/projects/inner"
[[ "$(val check_documentation)" == "skipped (this root is not a git repository of its own)" \
    && "$(val check_decision_register)" == "skipped (this root is not a git repository of its own)" \
    && "$(val check_design_anchors)" == run ]] \
    && pass "no repository of its own: the checks that read history are skipped, saying why" || fail "inner checks: '$OUT'"

echo "TEST: a project named workspace does not share the workspace's record column"
root_of "$R/named-ws"
[[ "$(val record_name)" == "project:workspace" && "$(val project)" == workspace ]] \
    && pass "project named workspace: record_name=project:workspace" || fail "named-ws: '$OUT'"

echo "TEST: the default branch"
root_of "$R/trunk"
[[ "$(val default_branch)" == trunk ]] && pass "origin/HEAD names trunk: default_branch=trunk" || fail "trunk: '$OUT'"
root_of "$R/nodefault"
[[ $RC -eq 0 && "$OUT" == *$'\ndefault_branch=\n'* && "$(val pr_source)" == none ]] \
    && pass "no origin/HEAD, neither main nor master: default branch empty (cannot tell)" || fail "nodefault: '$OUT'"
root_of "$R/twodefault"
[[ "$OUT" == *$'\ndefault_branch=\n'* ]] && pass "both main and master: default branch empty, never a guess" || fail "twodefault: '$OUT'"

root_of "$R/dangling"
[[ "$(val default_branch)" == main ]] \
    && pass "origin/HEAD names a branch with no local branch: falls through to the one of main/master" || fail "dangling: '$OUT'"
mkdir -p "$R/nodefault/docs" "$R/nodefault/.agent/knowledge"
printf '# D\n' > "$R/nodefault/docs/design.md"; printf '# R\n' > "$R/nodefault/.agent/knowledge/research_digest.md"
root_of "$R/nodefault"
[[ "$(val check_decision_register)" == "skipped (no default branch)" \
    && "$(val check_research_digest)" == "skipped (no default branch)" \
    && "$(val check_documentation)" == "skipped (no default branch)" \
    && "$(val check_design_anchors)" == run ]] \
    && pass "no default branch: the checks that read it are skipped, saying so; design_anchors still runs" || fail "nodefault checks: '$OUT'"

echo "TEST: the pull-request source is a github.com repository only"
root_of "$R/gitlab"
[[ $RC -eq 0 && "$(val own_repo)" == yes && "$(val pr_source)" == none ]] \
    && pass "an origin on another host (scp-style gitlab.com): pr_source=none, never a guess" || fail "gitlab: rc=$RC '$OUT'"
forms_ok=true
while IFS='|' read -r url want; do
    g -C "$R/forms" remote set-url origin "$url"
    root_of "$R/forms"
    [[ "$(val pr_source)" == "$want" ]] || { forms_ok=false; echo "    $url: got '$(val pr_source)', want '$want'"; }
done <<'URLS'
https://github.com/acme/forms.git|acme/forms
https://github.com/acme/forms|acme/forms
https://token@github.com/acme/forms.git|acme/forms
git@github.com:acme/forms.git|acme/forms
git@GitHub.com:Acme/Forms.git|Acme/Forms
ssh://git@github.com/acme/forms.git|acme/forms
ssh://git@github.com:22/acme/forms.git|acme/forms
git://github.com/acme/forms.git|acme/forms
https://github.com/acme/my.repo.git|acme/my.repo
https://gitlab.com/acme/forms.git|none
git@gitlab.com:acme/forms.git|none
ssh://git@github.com.evil.example/acme/forms.git|none
git@github.com.evil.example:acme/forms.git|none
https://evil.example/github.com/acme/forms.git|none
https://github.com/acme/forms/extra|none
/srv/git/acme/forms.git|none
acme/forms|none
github-work:acme/forms.git|none
URLS
$forms_ok && pass "each github.com form gives <owner>/<repo>; another host, a lookalike host, a path or an ssh alias gives none" || fail "URL forms (cases above)"
g -C "$R/forms" config url."https://github.com/".insteadOf "gh:"
g -C "$R/forms" remote set-url origin "gh:acme/viaalias.git"
root_of "$R/forms"
[[ "$(val pr_source)" == acme/viaalias ]] \
    && pass "a git insteadOf shorthand is read as git rewrites it" || fail "insteadOf: '$OUT'"

echo "TEST: a malformed registry: exit 2, the reason said, no root"
cp "$WSC/.agent/projects.local" "$SB/projects.saved"
printf 'broken\n' >> "$WSC/.agent/projects.local"
root_of "$R/proj"
[[ $RC -eq 2 && -z "$OUT" && "$ERR" == *"could not be decided"* && "$ERR" != *"is in no root"* ]] \
    && pass "malformed registry: exit 2, nothing printed, not called outside every root" || fail "malformed: rc=$RC '$OUT' err='$ERR'"
cp "$SB/projects.saved" "$WSC/.agent/projects.local"

echo "TEST: a directory outside every root: nothing on stdout, exit 1, no workspace fallback"
mkdir -p "$SB/elsewhere"
root_of "$SB/elsewhere"
[[ $RC -eq 1 && -z "$OUT" && "$ERR" == *"no sit-rep"* ]] \
    && pass "outside every root: exit 1, nothing printed, the reason on stderr" || fail "elsewhere: rc=$RC '$OUT' err='$ERR'"
RC=0; OUT="$(cd "$SB/elsewhere" && bash "$SR" --worktrees 2>/dev/null)" || RC=$?
[[ $RC -eq 1 && -z "$OUT" ]] && pass "outside every root, --worktrees: exit 1, no list" || fail "elsewhere --worktrees: rc=$RC '$OUT'"

echo "TEST: usage"
RC=0; bash "$SR" --bogus >/dev/null 2>&1 || RC=$?
[[ $RC -eq 2 ]] && pass "unknown option exits 2" || fail "usage rc=$RC"
RC=0; (cd "$WSC" && bash "$SR" --rows x >/dev/null 2>&1) || RC=$?
[[ $RC -eq 2 ]] && pass "--rows without --worktrees exits 2" || fail "--rows alone rc=$RC"

# --- worktrees --------------------------------------------------------------
# proj: plain worktrees 4, 12, 13; package worktree 20 (bare header, both
# checkouts acme/proj) and 21 (header names acme/pkgx). other: 6. inst
# (an instance of the hosting root host): 5. The workspace: 3 (above).
wt() {  # <root dir> <name> <issue>: a plain worktree in the root's worktrees/
    mkdir -p "$1/worktrees"
    g -C "$1" worktree add -q -b "feature/issue-$3" "$1/worktrees/issue-$2-$3" 2>/dev/null
}
wt "$R/proj" proj 4; wt "$R/proj" proj 12; wt "$R/proj" proj 13
wt "$R/other" other 6; wt "$R/host/inst" inst 5
pkg() {  # <n> <header issue> <origin of checkout b>
    local d="$R/proj/worktrees/issue-proj-$1"
    mkdir -p "$d/src"
    g init -q "$d/src/a"; g -C "$d/src/a" remote add origin https://github.com/acme/proj.git
    g init -q "$d/src/b"; g -C "$d/src/b" remote add origin "$3"
    printf '# project=proj issue=%s layer=l1\n/o/a\tsrc/a\tfeature/issue-%s\n/o/b\tsrc/b\tfeature/issue-%s\n' "$2" "$1" "$1" > "$d/.worktree-repos"
}
pkg 20 20 git@github.com:acme/proj.git
pkg 21 acme/pkgx#21 https://github.com/acme/pkgx.git
pkg 22 22 https://github.com/acme/pkgx.git
pkg 23 ACME/Proj#23 https://github.com/acme/pkgx.git
pkg 24 24 git@gitlab.com:acme/proj.git
g -C "$R/proj/worktrees/issue-proj-24/src/a" remote set-url origin git@gitlab.com:acme/proj.git

# wts <dir> [rows file]: --worktrees from <dir>; sets RC, OUT (one
# "<type> <repo> <issue> <own>" line per kept entry), JSON
wts() {
    RC=0
    JSON="$(cd "$1" && bash "$SR" --worktrees ${2:+--rows "$2"} 2>"$SB/err")" || RC=$?
    OUT="$(python3 -c '
import json, sys
for w in json.load(sys.stdin)["worktrees"]:
    print("%s %s %s %s" % (w["type"], w.get("repo"), w.get("issue"), w.get("own")))' <<< "$JSON" 2>&1 | sort)"
}
printf 'line\tProject other validates\tfalse\tscript adapter --project other validate\t2026-11-09\nline\tProject issue\tfalse\tgh-issue acme/proj#12 closed\t2026-11-09\ndeferral\tLater\tfalse\tgh-issue acme/proj#13 closed\t2026-11-09\n' > "$SB/rows-ws.tsv"

echo "TEST: --worktrees from the workspace: its own plus what its Direction lines name"
wts "$WSC" "$SB/rows-ws.tsv"
want=$'main None None yes\nproject other 6 no\nproject proj 12 no\nworkspace workspace 3 yes'
[[ $RC -eq 0 && "$OUT" == "$want" ]] \
    && pass "workspace: its own worktree and main kept; adapter --project and <owner/repo>#N name project work; an un-named project worktree (and a deferral's) dropped" \
    || fail "workspace --worktrees: rc=$RC got '$OUT' err='$(cat "$SB/err")'"
[[ "$(python3 -c 'import json,sys; print(sorted(json.load(sys.stdin)))' <<< "$JSON")" == "['worktrees']" ]] \
    && pass "the output is {\"worktrees\": [...]}" || fail "shape: '$JSON'"
wts "$WSC"
[[ "$OUT" == $'main None None yes\nworkspace workspace 3 yes' ]] \
    && pass "workspace, no rows file: only its own worktrees" || fail "workspace no rows: '$OUT'"
wts "$WSC" "$SB/missing.tsv"
[[ $RC -eq 0 && "$OUT" == $'main None None yes\nworkspace workspace 3 yes' ]] \
    && pass "workspace, rows file missing: only its own worktrees, no error" || fail "workspace missing rows: rc=$RC '$OUT'"

echo "TEST: --worktrees from a project root: its own, plus workspace work its Direction names"
printf 'line\tWorkspace work\tfalse\tgh-issue acme/ws#3 closed\t2026-11-09\n' > "$SB/rows-p.tsv"
wts "$R/proj" "$SB/rows-p.tsv"
want=$'project proj 12 yes\nproject proj 13 yes\nproject proj 20 yes\nproject proj 21 no\nproject proj 22 no\nproject proj 23 yes\nproject proj 24 no\nproject proj 4 yes\nworkspace workspace 3 no'
[[ $RC -eq 0 && "$OUT" == "$want" ]] \
    && pass "project: its plain worktrees own; a package worktree own when its header or agreeing checkouts are this repository; another root's dropped; a named workspace worktree kept, not own" \
    || fail "project --worktrees: rc=$RC got '$OUT' err='$(cat "$SB/err")'"
wts "$R/proj/worktrees/issue-proj-4"
[[ $RC -eq 0 && "$OUT" == *"project proj 4 yes"* && "$OUT" != *workspace* ]] \
    && pass "project: a session in one of its worktrees lists the same root" || fail "project from a worktree: rc=$RC '$OUT' err='$(cat "$SB/err")'"

# field <issue> <name>: a field of the kept entry with that issue, from $JSON
field() { python3 -c '
import json, sys
for w in json.load(sys.stdin)["worktrees"]:
    if str(w.get("issue")) == sys.argv[1]:
        v = w.get(sys.argv[2], "(absent)")
        print("\n".join(v) if isinstance(v, list) else v)' "$1" "$2" <<< "$JSON"; }
PKG="$R/proj/worktrees/issue-proj"
wts "$R/proj" "$SB/rows-p.tsv"
[[ "$(field 4 pr_branch)" == feature/issue-4 && "$(field 20 pr_branch)" == feature/issue-20 \
    && "$(field 23 pr_branch)" == feature/issue-23 && "$(field 21 pr_branch)" == "" && "$(field 3 pr_branch)" == "" ]] \
    && pass "pr_branch: a plain own worktree's branch; an own package worktree's branch of its repository's checkouts, not the comma-joined list; none when not own" \
    || fail "pr_branch: 4='$(field 4 pr_branch)' 20='$(field 20 pr_branch)' 23='$(field 23 pr_branch)' 21='$(field 21 pr_branch)' 3='$(field 3 pr_branch)'"
[[ "$(field 20 branch)" == "feature/issue-20,feature/issue-20" ]] || fail "fixture: package 20's branch is not the comma-joined list: '$(field 20 branch)'"
[[ "$(field 4 repository)" == acme/proj && "$(field 4 repository_dirs)" == "$PKG-4" && "$(field 4 repository_why)" == "" \
    && "$(field 21 repository)" == acme/pkgx && "$(field 21 repository_dirs)" == "$PKG-21/src/b" \
    && "$(field 20 repository)" == acme/proj && "$(field 20 repository_dirs)" == "$PKG-20/src/a"$'\n'"$PKG-20/src/b" \
    && "$(field 22 repository)" == "" && "$(field 22 repository_dirs)" == "" \
    && "$(field 22 repository_why)" == "its checkouts are not all in one GitHub repository" \
    && "$(field 24 repository)" == "" && "$(field 24 own)" == no ]] \
    && pass "repository: a plain worktree's origin; a package worktree's header or agreeing checkouts, with those checkouts; none (with why) when they disagree or are not on GitHub" \
    || fail "repository fields: $JSON"
[[ "$(field 4 named)" == no && "$(field 12 named)" == no && "$(field 3 named)" == yes ]] \
    && pass "named: workspace work a gh-issue <owner/repo>#N check names is named; the root's own unnamed work is not" \
    || fail "named: 4='$(field 4 named)' 12='$(field 12 named)' 3='$(field 3 named)'"
wts "$R/proj"
[[ "$(field 4 named)" == "(absent)" ]] && pass "named: absent without a rows file (the path cannot be told)" || fail "named without rows: '$(field 4 named)'"

echo "TEST: --worktrees reads Direction checks by the check runner's grammar, names without regard to case"
printf '%s\n' \
    $'line\tBare numbers (#4, #13)\tfalse\tgh-issue 12 closed\t2026-11-09' \
    $'line\tAn argument\tfalse\tfile-contains docs/a.md gh-issue acme/ws#3 closed\t2026-11-09' \
    $'line\tTwo checks\tfalse\t`file-exists a.md` ; `gh-issue ACME/Proj#21 closed`\t2026-11-09' \
    $'line\tNot a state\tfalse\tgh-issue acme/proj#22 later\t2026-11-09' > "$SB/rows-g.tsv"
wts "$R/proj" "$SB/rows-g.tsv"
[[ $RC -eq 0 && "$OUT" != *workspace* ]] \
    && pass "a gh-issue reference inside a file-contains argument names nothing (the workspace worktree is not kept)" || fail "grammar keep: rc=$RC '$OUT'"
[[ "$(field 4 named)" == yes && "$(field 13 named)" == yes && "$(field 12 named)" == yes \
    && "$(field 21 named)" == no && "$(field 22 named)" == no && "$(field 20 named)" == no ]] \
    && pass "named: (#N) lists and gh-issue N name own work; another repository's issue of the same number is not named by a bare number; a malformed state names nothing" \
    || fail "named by grammar: 4='$(field 4 named)' 13='$(field 13 named)' 12='$(field 12 named)' 21='$(field 21 named)' 22='$(field 22 named)' 20='$(field 20 named)'"
printf '%s\n' $'line\tCased\tfalse\t`file-exists a.md` ; `gh-issue Acme/PkgX#21 closed`\t2026-11-09' > "$SB/rows-c.tsv"
wts "$R/proj" "$SB/rows-c.tsv"
[[ "$(field 21 named)" == yes ]] && pass "named: a backticked check after \` ; \` with Acme/PkgX matches acme/pkgx" || fail "named by case: '$(field 21 named)'"
printf 'line\tW\tfalse\tgh-issue ACME/proj#12 closed\t2026-11-09\n' > "$SB/rows-wc.tsv"
wts "$WSC" "$SB/rows-wc.tsv"
[[ "$OUT" == *"project proj 12 no"* ]] && pass "(b): gh-issue ACME/proj#12 keeps acme/proj's worktree 12" || fail "(b) case: '$OUT'"

echo "TEST: the helper writes nothing: no temporary file, the roots' trees unchanged"
mkdir -p "$SB/tmpcheck"
before="$(g -C "$WSC" status --porcelain; g -C "$R/proj" status --porcelain)"
(cd "$R/proj" && TMPDIR="$SB/tmpcheck" bash "$SR" >/dev/null 2>&1; TMPDIR="$SB/tmpcheck" bash "$SR" --worktrees --rows "$SB/rows-g.tsv" >/dev/null 2>&1)
(cd "$WSC" && TMPDIR="$SB/tmpcheck" bash "$SR" --worktrees --rows "$SB/rows-ws.tsv" >/dev/null 2>&1)
after="$(g -C "$WSC" status --porcelain; g -C "$R/proj" status --porcelain)"
[[ -z "$(ls -A "$SB/tmpcheck")" && "$before" == "$after" ]] \
    && pass "both modes: nothing in TMPDIR, git status unchanged" || fail "writes: tmp='$(ls -A "$SB/tmpcheck")' before='$before' after='$after'"

echo "TEST: --worktrees from a hosting root: its instances' worktrees, none its own"
wts "$R/host"
[[ $RC -eq 0 && "$OUT" == "project inst 5 no" ]] \
    && pass "hosting root: an instance's worktree is listed, not own (no repository of its own)" || fail "host --worktrees: rc=$RC '$OUT' err='$(cat "$SB/err")'"

echo "TEST: --worktrees passes a worktree_list.sh failure through"
cp "$WSC/.agent/scripts/worktree_list.sh" "$SB/wl.saved"
printf '#!/usr/bin/env bash\necho "registry broken" >&2\nexit 3\n' > "$WSC/.agent/scripts/worktree_list.sh"
RC=0; OUT="$(cd "$WSC" && bash "$SR" --worktrees 2>"$SB/err")" || RC=$?
[[ $RC -eq 3 && -z "$OUT" && "$(cat "$SB/err")" == *"registry broken"* ]] \
    && pass "a failing worktree_list.sh: its exit status and stderr, never an empty list" || fail "failure: rc=$RC '$OUT' err='$(cat "$SB/err")'"
printf '#!/usr/bin/env bash\necho "not json"\n' > "$WSC/.agent/scripts/worktree_list.sh"
RC=0; OUT="$(cd "$WSC" && bash "$SR" --worktrees 2>"$SB/err")" || RC=$?
[[ $RC -eq 1 && -z "$OUT" && "$(cat "$SB/err")" == *"no worktree list"* ]] \
    && pass "output that is not JSON: exit 1, said so, no list" || fail "not json: rc=$RC '$OUT' err='$(cat "$SB/err")'"
cp "$SB/wl.saved" "$WSC/.agent/scripts/worktree_list.sh"

echo ""
echo "test_sitrep_root: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
