#!/usr/bin/env bash
# .agent/scripts/tests/test_project_documents.sh
# Tests for where a project keeps its goals, design and roadmap (issue
# #551): the goals/design/roadmap settings (value grammar, at `set` and in
# the parser), the one lookup (project_document_path,
# project_document_name_for_root, project_document_for_dir in
# _project_registry.sh) and `project_setting.sh doc`, and the readers that
# need a registry to show the setting is followed: update_roadmap.sh,
# check_design_anchors.sh, sitrep_checks.sh's default roadmap and the merge
# gate's bookkeeping paths (_bookkeeping.sh). sitrep_root.sh's design= and
# roadmap= lines are tested in test_sitrep_root.sh.
#
# Hermetic: a sandbox workspace (a git repository holding a copy of the
# checkout's .agent/scripts and .agent/project_types), a sandbox registry of
# synthetic project roots and real git worktrees, all under one
# `mktemp -d` sandbox. HOME is redirected; no gh call, no network.
#
# Run: bash .agent/scripts/tests/test_project_documents.sh

set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
# check <label> <condition...>: pass when the command succeeds.
check() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }

SB="$(mktemp -d)"
SB="$(cd "$SB" && pwd -P)"
trap 'rm -rf "$SB"' EXIT
GIT_CEILING_DIRECTORIES="$(dirname "$SB")"
export GIT_CEILING_DIRECTORIES
export HOME="$SB/home"
mkdir -p "$HOME"
g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }

# --- the sandbox workspace ---------------------------------------------------
WSC="$SB/ws"
mkdir -p "$WSC/.agent" "$WSC/docs"
cp -r "$SRC" "$WSC/.agent/scripts"
cp -r "$SRC/../project_types" "$WSC/.agent/project_types"
rm -rf "$WSC/.agent/scripts/tests"
printf '# Design\n\n## Overview\n' > "$WSC/docs/design.md"
printf '# Roadmap\n\n- [ ] Workspace item (#7)\n' > "$WSC/docs/roadmap.md"
printf 'See docs/design.md#overview.\n' > "$WSC/README.md"
g -C "$WSC" init -q
g -C "$WSC" add -A && g -C "$WSC" commit -q -m init
S="$WSC/.agent/scripts"

# --- the project roots ------------------------------------------------------
R="$SB/roots"
mkroot() {  # <name>: a git root with its files committed on main
    mkdir -p "$R/$1"
    g -C "$R/$1" init -q
}
commit_all() { g -C "$1" add -A && g -C "$1" commit -q -m "${2:-files}"; }

# keyed: every setting names a file away from the candidates.
mkroot keyed
mkdir -p "$R/keyed/docs/arch" "$R/keyed/notes"
printf '# Arch\n\n## Overview\n\n## Parts\n' > "$R/keyed/docs/arch/design.md"
printf '# Plan\n\n- [ ] Keyed item (#7)\n' > "$R/keyed/notes/plan.md"
printf '# Roadmap\n\n- [ ] Decoy item (#7)\n' > "$R/keyed/docs/roadmap.md"
printf '# Keyed\n\n## Goals\n\nSee docs/arch/design.md#overview and docs/arch/design.md#parts.\n' > "$R/keyed/README.md"
commit_all "$R/keyed"
# plain: no settings; the candidates as today, docs/ROADMAP.md included.
mkroot plain
mkdir -p "$R/plain/docs"
printf '# Design\n\n## Overview\n' > "$R/plain/docs/design.md"
printf '# Roadmap\n\n- [ ] Plain item (#7)\n' > "$R/plain/docs/ROADMAP.md"
commit_all "$R/plain"
# nonep: design=none and roadmap=none while the candidate files exist.
mkroot nonep
mkdir -p "$R/nonep/docs/part"
printf '# Design\n\n## Overview\n' > "$R/nonep/docs/design.md"
printf '# Roadmap\n\n## Direction\n\n| Line | Check |\n|---|---|\n| A | file-exists README.md |\n\n- [ ] None item (#7)\n' > "$R/nonep/docs/roadmap.md"
printf '# Part\n\n## Intro\n' > "$R/nonep/docs/part/design.md"
printf 'See docs/part/design.md#intro and docs/part/design.md#gone.\n' > "$R/nonep/README.md"
commit_all "$R/nonep"
# missing: the settings name files that do not exist; the candidates do.
mkroot missing
mkdir -p "$R/missing/docs"
printf '# Design\n' > "$R/missing/docs/design.md"
printf '# Roadmap\n\n- [ ] Missing item (#7)\n' > "$R/missing/docs/roadmap.md"
commit_all "$R/missing"
# escape: the settings name links that leave the root.
mkroot escape
mkdir -p "$R/escape/docs"
printf '# Outside\n' > "$SB/outside.md"
ln -s ../../../outside.md "$R/escape/docs/link.md"
commit_all "$R/escape"
# arch: design=ARCHITECTURE.md, a file not named design.md.
mkroot arch
mkdir -p "$R/arch/docs"
printf '# Architecture\n\n## Overview\n' > "$R/arch/ARCHITECTURE.md"
printf 'Good: `ARCHITECTURE.md#overview`, [link](ARCHITECTURE.md#overview).\nBad: ARCHITECTURE.md#gone\nOther file: docs/ARCHITECTURE.md#whatever\n' > "$R/arch/README.md"
printf 'From docs: ARCHITECTURE.md#overview and /ARCHITECTURE.md#nothere\n' > "$R/arch/docs/roadmap.md"
commit_all "$R/arch"
# headed: design names a section; the checker uses the whole file.
mkroot headed
mkdir -p "$R/headed/docs"
printf '# Design\n\n## Overview\n' > "$R/headed/docs/design.md"
printf 'See docs/design.md#overview.\n' > "$R/headed/README.md"
commit_all "$R/headed"
# host/sub: a root inside another repository.
mkroot host
mkdir -p "$R/host/sub/notes"
printf '# Plan\n' > "$R/host/sub/notes/plan.md"
commit_all "$R/host"
# fam: a parent root with one instance.
mkdir -p "$R/fam"
mkroot fam/fam1
mkdir -p "$R/fam/docs"
printf '# Roadmap\n' > "$R/fam/docs/roadmap.md"

# loose: no document settings; its settings file is given bad lines below.
mkroot loose
mkdir -p "$R/loose/docs"
printf '# Design\n\n## Overview\n' > "$R/loose/docs/design.md"
printf '# Other\n\n## Overview\n' > "$R/loose/docs/other.md"
printf '# Roadmap\n\n## Direction\n\n| Line | Check |\n|---|---|\n| Loose line | file-exists README.md |\n\n- [ ] Loose item (#7)\n' > "$R/loose/docs/roadmap.md"
printf 'See docs/design.md#overview.\n' > "$R/loose/README.md"
commit_all "$R/loose"
# linkr: roadmap names a symbolic link inside the root.
mkroot linkr
mkdir -p "$R/linkr/notes"
printf '# Plan\n\n- [ ] Link item (#7)\n' > "$R/linkr/notes/real.md"
ln -s real.md "$R/linkr/notes/link.md"
commit_all "$R/linkr"
# candlink: no settings; ROADMAP.md is a link out of the root, docs/roadmap.md
# a file.
mkroot candlink
mkdir -p "$R/candlink/docs"
printf '# Outside roadmap\n\n- [ ] Outside item (#7)\n' > "$SB/outside_roadmap.md"
ln -s ../../outside_roadmap.md "$R/candlink/ROADMAP.md"
printf '# Roadmap\n\n- [ ] Inside item (#7)\n' > "$R/candlink/docs/roadmap.md"
commit_all "$R/candlink"
# candout: no settings; the candidate docs/design.md is a link out of the root.
mkroot candout
mkdir -p "$R/candout/docs"
ln -s ../../../outside.md "$R/candout/docs/design.md"
commit_all "$R/candout"
# mydes: a design file whose name ends in design.md.
mkroot mydes
mkdir -p "$R/mydes/docs"
printf '# Design\n\n## Overview\n' > "$R/mydes/docs/my-design.md"
printf 'Good: docs/my-design.md#overview. Bad: docs/my-design.md#gone\n' > "$R/mydes/README.md"
commit_all "$R/mydes"
# nonec: design=none, and its part's citations are all sound.
mkroot nonec
mkdir -p "$R/nonec/docs/part"
printf '# Part\n\n## Intro\n' > "$R/nonec/docs/part/design.md"
printf 'See docs/part/design.md#intro.\n' > "$R/nonec/README.md"
commit_all "$R/nonec"
# ptr: roadmap=notes/plan.md, whose Direction holds a line and a pointer
# table; the decoy docs/roadmap.md points elsewhere.
mkroot ptr
mkdir -p "$R/ptr/docs" "$R/ptr/notes" "$R/ptr/tools/x" "$R/ptr/tools/y"
printf '# Design\n\n## Overview\n' > "$R/ptr/docs/design.md"
printf '# Plan\n\n## Direction\n\n| Line | Check |\n|---|---|\n| Plan line | file-exists README.md |\n\n| Sub-roadmap | Root |\n|---|---|\n| tools/x/ROADMAP.md | tools/x |\n' > "$R/ptr/notes/plan.md"
printf '# Roadmap\n\n## Direction\n\n| Line | Check |\n|---|---|\n| Decoy line | file-exists README.md |\n\n| Sub-roadmap | Root |\n|---|---|\n| tools/y/ROADMAP.md | tools/y |\n' > "$R/ptr/docs/roadmap.md"
for t in x y; do
    printf '# %s\n\n## Ok\n\n[%s](#gone-%s)\n' "$t" "$t" "$t" > "$R/ptr/tools/$t/design.md"
    printf '# %s roadmap\n' "$t" > "$R/ptr/tools/$t/ROADMAP.md"
done
printf 'Ptr.\n' > "$R/ptr/README.md"
commit_all "$R/ptr"

cat > "$WSC/.agent/projects.local" <<REG
keyed    single_project  $R/keyed
plain    single_project  $R/plain
nonep    single_project  $R/nonep
missing  single_project  $R/missing
escape   single_project  $R/escape
arch     single_project  $R/arch
headed   single_project  $R/headed
sub      single_project  $R/host/sub
fam1     single_project  $R/fam/fam1  parent=fam
fam      project         $R/fam
loose    single_project  $R/loose
linkr    single_project  $R/linkr
candlink single_project  $R/candlink
candout  single_project  $R/candout
mydes    single_project  $R/mydes
nonec    single_project  $R/nonec
ptr      single_project  $R/ptr
REG

PS() { (cd "$WSC" && bash "$S/project_setting.sh" "$@"); }

echo "TEST: set accepts the document settings and refuses values outside the grammar"
out="$(PS set keyed design=docs/arch/design.md roadmap=notes/plan.md 'goals=README.md#Goals' 2>&1)"; rc=$?
check "set stores design, roadmap and goals ($out)" test "$rc" -eq 0
check "get returns the heading with the path" test "$(PS get keyed goals 2>/dev/null)" = "README.md#Goals"
# shellcheck disable=SC2088  # a literal '~' is the value under test
for bad in /abs/design.md '~/design.md' ../design.md docs/../design.md ./design.md docs//design.md docs/ \
           'https://example.com/design.md' 'docs/my design.md' 'docs/d*.md' 'docs\d.md' 'design.md#'; do
    out="$(PS set plain "design=$bad" 2>&1)"; rc=$?
    check "set refuses design=$bad" test "$rc" -ne 0
done
out="$(PS set plain 'roadmap=docs/roadmap.md#Direction' 2>&1)"; rc=$?
check "set refuses a heading on roadmap" test "$rc" -ne 0
[[ "$out" == *"roadmap takes a file, not a section"* ]] && pass "the refusal says why" || fail "roadmap heading refusal: '$out'"
check "a refused set wrote nothing" test ! -e "$WSC/.agent/projects.d/plain"
out="$(PS set fam design=docs/design.md 2>&1)"; rc=$?
check "set refuses a parent root (settings belong to instances)" test "$rc" -ne 0
check "none is accepted" PS set nonep design=none roadmap=none goals=none
PS set missing design=docs/gone.md roadmap=notes/gone.md >/dev/null 2>&1 || fail "set missing"
PS set escape design=docs/link.md roadmap=docs/link.md >/dev/null 2>&1 || fail "set escape"
PS set arch design=ARCHITECTURE.md >/dev/null 2>&1 || fail "set arch"
PS set headed 'design=docs/design.md#Overview' >/dev/null 2>&1 || fail "set headed"
PS set sub roadmap=notes/plan.md >/dev/null 2>&1 || fail "set sub"
PS set linkr roadmap=notes/link.md >/dev/null 2>&1 || fail "set linkr"
PS set mydes design=docs/my-design.md >/dev/null 2>&1 || fail "set mydes"
PS set nonec design=none >/dev/null 2>&1 || fail "set nonec"
PS set ptr roadmap=notes/plan.md >/dev/null 2>&1 || fail "set ptr"

echo "TEST: roadmap names a Markdown file; the path is checked before the heading"
for bad in src/main.py ROADMAP notes/plan.txt; do
    out="$(PS set plain "roadmap=$bad" 2>&1)"; rc=$?
    check "set refuses roadmap=$bad" test "$rc" -ne 0
done
[[ "$out" == *"must name a Markdown file"* ]] && pass "the .md refusal says why" || fail "md refusal: '$out'"
check "design may name a file of any type" PS set plain design=docs/design.txt
PS unset plain design >/dev/null 2>&1
out="$(PS set plain 'roadmap=../r.md#x' 2>&1)"; rc=$?
check "set refuses roadmap=../r.md#x" test "$rc" -ne 0
[[ "$out" == *"no '..'"* && "$out" != *"roadmap=../r.md)"* ]] && pass "the path error comes first, not a suggestion of the bad path" || fail "path first: '$out'"
check "a refused set wrote nothing" test ! -e "$WSC/.agent/projects.d/plain"

echo "TEST: a hand-written bad value fails the parser"
printf 'design=../outside.md\n' > "$WSC/.agent/projects.d/plain"
out="$(PS check plain 2>&1)"; rc=$?
check "check exits 2 on design=../outside.md" test "$rc" -eq 2
[[ "$out" == *"design must be 'none' or a file inside the project"* ]] && pass "the parser names the rule" || fail "parser: '$out'"
out="$(PS doc plain design 2>&1)"; rc=$?
check "doc exits 2 when the design key itself is invalid" test "$rc" -eq 2
printf 'roadmap=src/main.py\n' > "$WSC/.agent/projects.d/plain"
out="$(PS check plain 2>&1)"; rc=$?
check "the parser refuses a hand-written roadmap=src/main.py" test "$rc" -eq 2
out="$(PS doc plain roadmap 2>&1)"; rc=$?
check "doc roadmap exits 2 for roadmap=src/main.py" test "$rc" -eq 2
rm -f "$WSC/.agent/projects.d/plain"

echo "TEST: a settings file bad only in other lines fails open (issue owner: no setting, today's search)"
LF="$WSC/.agent/projects.d/loose"
printf 'build=make; rm -rf /\n' > "$LF"
out="$(PS doc loose design 2>"$SB/err")"; rc=$?
check "an unrelated bad key: doc design reads the candidate" test "$rc:$out" = "0:fallback docs/design.md"
grep -q '^warning: .*has errors' "$SB/err" && pass "one warning names the problem" || fail "warning: '$(cat "$SB/err")'"
check "exactly one warning line" test "$(wc -l < "$SB/err")" -eq 1
out="$(bash "$S/check_design_anchors.sh" "$R/loose" 2>&1)"; rc=$?
check "check_design_anchors.sh still checks the candidate design ($out)" test "$rc" -eq 0
out="$(bash "$S/update_roadmap.sh" --issue 7 --root "$R/loose" --dry-run 2>&1 >/dev/null)"
[[ "$out" == *"docs/roadmap.md: #7"* ]] && pass "update_roadmap.sh still finds the candidate roadmap" || fail "loose roadmap: '$out'"
out="$(bash "$S/sitrep_checks.sh" --root "$R/loose" 2>/dev/null)"
[[ "$out" == *"Loose line"* && "$out" != *"not readable"* ]] && pass "sitrep_checks.sh reads the candidate's Direction" || fail "loose checks: '$out'"
(source "$S/_bookkeeping.sh"; bookkeeping_roadmap_paths "$R/loose") > "$SB/bk" 2>&1
check "the merge gate's bookkeeping paths are the fixed list" test "$(wc -l < "$SB/bk")" -eq 3
printf 'build=make; rm -rf /\ndesign=docs/other.md\n' > "$LF"
out="$(PS doc loose design 2>"$SB/err")"; rc=$?
check "an unrelated bad key beside a valid design: the setting is read" test "$rc:$out" = "0:set docs/other.md"
grep -q '^warning: .*other lines' "$SB/err" && pass "the warning says the key is read as written" || fail "warning2: '$(cat "$SB/err")'"
printf 'build=make; rm -rf /\ndesign=../x.md\n' > "$LF"
out="$(PS doc loose design 2>&1)"; rc=$?
check "an unrelated bad key beside an invalid design: exit 2" test "$rc" -eq 2
printf 'design=docs/other.md\ndesign=docs/design.md\n' > "$LF"
out="$(PS doc loose design 2>&1)"; rc=$?
check "design set twice: exit 2" test "$rc" -eq 2
[[ "$out" == *"set more than once"* ]] && pass "the duplicate is named" || fail "dup: '$out'"
check "design set twice: roadmap (unset) still reads the candidate" test "$(PS doc loose roadmap 2>/dev/null)" = "fallback docs/roadmap.md"
rm -f "$LF"

echo "TEST: project_setting.sh doc reports set, fallback and none"
check "doc design (set)" test "$(PS doc keyed design)" = "set docs/arch/design.md"
check "doc goals keeps the heading" test "$(PS doc keyed goals)" = "set README.md#Goals"
check "doc design (fallback)" test "$(PS doc plain design)" = "fallback docs/design.md"
check "doc roadmap (fallback, docs/ROADMAP.md is a candidate)" test "$(PS doc plain roadmap)" = "fallback docs/ROADMAP.md"
check "doc design (none)" test "$(PS doc nonep design)" = "none"
out="$(PS doc plain goals 2>&1)"; rc=$?
check "doc goals unset: exit 1, no fallback" test "$rc" -eq 1
[[ "$out" == *"no fallback for goals"* ]] && pass "unset goals says there is no fallback" || fail "goals: '$out'"
out="$(PS doc missing design 2>&1)"; rc=$?
check "doc design naming a missing file: exit 1 (not the candidate)" test "$rc" -eq 1
[[ "$out" == *"docs/gone.md does not exist"* ]] && pass "the missing file is named" || fail "missing: '$out'"
out="$(PS doc escape design 2>&1)"; rc=$?
check "doc design through a link out of the root: exit 2" test "$rc" -eq 2
[[ "$out" == *"resolves outside"* ]] && pass "the escape is named" || fail "escape: '$out'"
check "doc at a parent root reads the candidates" test "$(PS doc fam roadmap)" = "fallback docs/roadmap.md"
out="$(PS doc keyed readme 2>&1)"; rc=$?
check "doc refuses an unknown document (exit 3, not 1)" test "$rc" -eq 3
out="$(PS doc keyed 2>&1)"; rc=$?
check "doc without a document: exit 3" test "$rc" -eq 3
out="$(PS doc nosuch design 2>&1)"; rc=$?
check "doc for an unknown project: exit 3" test "$rc" -eq 3
out="$(PS doc linkr roadmap 2>&1)"; rc=$?
check "a roadmap setting that is a symbolic link: exit 2" test "$rc" -eq 2
[[ "$out" == *"symbolic link"* ]] && pass "the link is named" || fail "link: '$out'"
out="$(PS doc candout design 2>&1)"; rc=$?
check "an unset key whose candidate leaves the root: exit 2 (fails closed)" test "$rc" -eq 2
check "the candidates split on blanks whatever the caller's IFS" \
    test "$( (source "$S/_project_registry.sh"; IFS=,; project_document_candidates roadmap) | wc -l)" -eq 3

echo "TEST: project_document_name_for_root and project_document_for_dir"
g -C "$R/keyed" worktree add -q "$R/keyed/worktrees/wt" -b feature
g -C "$WSC" worktree add -q "$WSC/worktrees/wsb" -b wsb
name_of() { (source "$S/_project_registry.sh"; project_document_name_for_root "$WSC" "$1"); }
for_dir() { (source "$S/_project_registry.sh"; project_document_for_dir "$WSC" "$1" "$2"); }
check "a registered root is its project" test "$(name_of "$R/keyed")" = keyed
check "a worktree of the root's own repository is its project" test "$(name_of "$R/keyed/worktrees/wt")" = keyed
check "a subdirectory of a root is not" test -z "$(name_of "$R/keyed/docs" 2>/dev/null)"
check "a root inside another repository is its project" test "$(name_of "$R/host/sub")" = sub
check "the workspace is no project" test -z "$(name_of "$WSC" 2>/dev/null)"
check "a workspace worktree is no project" test -z "$(name_of "$WSC/worktrees/wsb" 2>/dev/null)"
check "a parent root is its own name" test "$(name_of "$R/fam")" = fam
check "the worktree reads the setting" test "$(for_dir "$R/keyed/worktrees/wt" roadmap)" = "set notes/plan.md"
check "the workspace reads docs/design.md" test "$(for_dir "$WSC" design)" = "fallback docs/design.md"
check "a workspace worktree reads docs/design.md" test "$(for_dir "$WSC/worktrees/wsb" design)" = "fallback docs/design.md"
check "an unregistered directory reads the candidates" test "$(for_dir "$R/host" design 2>/dev/null; echo "rc=$?")" = "rc=1"

echo "TEST: the workspace checkout never reads the registry"
cp "$WSC/.agent/projects.local" "$SB/projects.local.good"
printf 'broken line with = in path\n' >> "$WSC/.agent/projects.local"
check "a broken registry: the workspace still reads docs/design.md" test "$(for_dir "$WSC" design 2>/dev/null)" = "fallback docs/design.md"
out="$(for_dir "$R/plain" design 2>"$SB/err")"; rc=$?
check "a broken registry: a project root reads the candidate" test "$rc:$out" = "0:fallback docs/design.md"
grep -q '^warning: the registry' "$SB/err" && pass "a broken registry: one warning names it" || fail "registry warning: '$(cat "$SB/err")'"
check "a broken registry: exactly one warning line" test "$(wc -l < "$SB/err")" -eq 1
check "a broken registry: a keyed root reads the candidate, not the setting" test "$(for_dir "$R/keyed" roadmap 2>/dev/null)" = "fallback docs/roadmap.md"
mkdir -p "$SB/unreg/docs"
printf '# Design

## Overview
' > "$SB/unreg/docs/design.md"
printf 'See docs/design.md#overview.
' > "$SB/unreg/README.md"
out="$(bash "$S/check_design_anchors.sh" "$SB/unreg" 2>&1)"; rc=$?
check "a broken registry: an unregistered root is still checked ($out)" test "$rc" -eq 0
out="$(bash "$S/update_roadmap.sh" --issue 7 --root "$R/plain" --dry-run 2>&1 >/dev/null)"
[[ "$out" == *"docs/ROADMAP.md: #7"* ]] && pass "a broken registry: update_roadmap.sh uses the candidates" || fail "broken registry roadmap: '$out'"
out="$( (source "$S/_project_registry.sh"; project_document_path "$WSC" plain design "$R/plain") 2>/dev/null)"; rc=$?
check "a broken registry: project_document_path with a directory reads the candidates" test "$rc:$out" = "0:fallback docs/design.md"
cp "$SB/projects.local.good" "$WSC/.agent/projects.local"
out="$( (source "$S/_project_registry.sh"; project_document_path "$WSC" nosuch design "$R/plain") 2>&1)"; rc=$?
check "an unregistered name with a directory: the candidates, with a warning" test "$rc" -eq 0
[[ "$out" == *"warning: project 'nosuch' is not registered"* ]] && pass "the warning names the name" || fail "unregistered: '$out'"

echo "TEST: update_roadmap.sh follows the roadmap setting"
UR="$S/update_roadmap.sh"
out="$(bash "$UR" --issue 7 --root "$R/keyed/worktrees/wt" 2>/dev/null)"
check "a key-named roadmap in a worktree: only that file is edited" test "$out" = "$R/keyed/worktrees/wt/notes/plan.md"
grep -qF -- '- [x] Keyed item (#7)' "$R/keyed/worktrees/wt/notes/plan.md" && pass "the setting's file is ticked" || fail "keyed tick"
grep -qF -- '- [ ] Decoy item (#7)' "$R/keyed/worktrees/wt/docs/roadmap.md" && pass "the candidate docs/roadmap.md is left alone" || fail "decoy ticked"
out="$(bash "$UR" --issue 7 --root "$R/nonep" 2>&1 >/dev/null)"
grep -qF -- '- [ ] None item (#7)' "$R/nonep/docs/roadmap.md" && pass "roadmap=none: nothing is edited" || fail "none ticked"
[[ "$out" == *"keeps no roadmap"* ]] && pass "roadmap=none says so" || fail "none message: '$out'"
out="$(bash "$UR" --issue 7 --root "$R/missing" 2>&1 >/dev/null)"
grep -qF -- '- [ ] Missing item (#7)' "$R/missing/docs/roadmap.md" && pass "a setting naming a missing file: the candidate is not edited" || fail "missing ticked"
[[ "$out" == *"roadmap=notes/gone.md"* ]] && pass "the missing file is named" || fail "missing message: '$out'"
out="$(bash "$UR" --issue 7 --root "$R/plain" 2>/dev/null)"
check "unset: the docs/ROADMAP.md candidate is edited" test "$out" = "$R/plain/docs/ROADMAP.md"
out="$(bash "$UR" --issue 7 --root "$WSC" 2>/dev/null)"
check "the workspace root: docs/roadmap.md is edited" test "$out" = "$WSC/docs/roadmap.md"
out="$(bash "$UR" --issue 7 --root "$R/escape" 2>&1)"
[[ "$out" == *"could not tell which file is the roadmap"* ]] && pass "a setting that leaves the root: nothing is edited, with the reason" || fail "escape: '$out'"
out="$(bash "$UR" --issue 7 --root "$R/linkr" 2>&1)"
check "a roadmap setting that is a link: the link is left a link" test -L "$R/linkr/notes/link.md"
grep -qF -- '- [ ] Link item (#7)' "$R/linkr/notes/real.md" && pass "a roadmap setting that is a link: nothing is edited (refused)" || fail "link ticked"
[[ "$out" == *"symbolic link"* ]] && pass "the refusal names the link" || fail "link message: '$out'"
out="$(bash "$UR" --issue 7 --root "$R/candlink" 2>"$SB/err")"
check "unset: a candidate linked out of the root is skipped, the inside one edited" test "$out" = "$R/candlink/docs/roadmap.md"
grep -qF -- '- [ ] Outside item (#7)' "$SB/outside_roadmap.md" && pass "the file outside the root is not edited" || fail "outside ticked"
grep -q 'skipping ROADMAP.md' "$SB/err" && pass "the skip is said" || fail "skip message: '$(cat "$SB/err")'"
g -C "$WSC" checkout -q -- docs/roadmap.md

echo "TEST: check_design_anchors.sh reads the design setting"
CDA="$S/check_design_anchors.sh"
out="$(cd "$R" && bash "$CDA" keyed 2>&1)"; rc=$?
check "a relative root is resolved once ($out)" test "$rc" -eq 0
out="$(bash "$CDA" "$R/mydes" 2>&1)"; rc=$?
check "a design named my-design.md: the broken citation fails" test "$rc" -eq 1
check "a design named my-design.md: each citation is reported once" test "$(grep -c "broken anchor '#gone'" <<< "$out")" -eq 1
out="$(bash "$CDA" "$R/nonec" 2>&1)"; rc=$?
check "design=none with sound parts: exit 0 ($out)" test "$rc" -eq 0
out="$(bash "$CDA" "$R/ptr" 2>&1)"; rc=$?
check "a key-named roadmap's pointer table is followed" test "$rc" -eq 1
[[ "$out" == *"#gone-x"* && "$out" != *"#gone-y"* ]] && pass "the part it names is read; the decoy's is not" || fail "ptr: '$out'"
out="$(bash "$CDA" "$R/keyed" 2>&1)"; rc=$?
check "a design named docs/arch/design.md: its citations resolve ($out)" test "$rc" -eq 0
printf 'Broken: docs/arch/design.md#nope\n' >> "$R/keyed/README.md"
out="$(bash "$CDA" "$R/keyed" 2>&1)"; rc=$?
check "a broken citation of the key-named design is found" test "$rc" -eq 1
[[ "$out" == *"no such heading in docs/arch/design.md"* ]] && pass "checked against the root design's headings" || fail "keyed broken: '$out'"
g -C "$R/keyed" checkout -q -- README.md
out="$(bash "$CDA" "$R/arch" 2>&1)"; rc=$?
check "ARCHITECTURE.md as the design: a broken citation fails" test "$rc" -eq 1
[[ "$out" == *"README.md:2: broken anchor '#gone' (no such heading in ARCHITECTURE.md)"* ]] && pass "ARCHITECTURE.md#gone is a root citation" || fail "arch gone: '$out'"
[[ "$out" == *"docs/roadmap.md:1: broken anchor '#nothere'"* ]] && pass "an anchored /ARCHITECTURE.md# citation is checked" || fail "arch anchored: '$out'"
[[ "$out" != *"#overview"* ]] && pass "ARCHITECTURE.md#overview resolves (backtick, link, and from docs/)" || fail "arch overview: '$out'"
[[ "$out" != *"whatever"* ]] && pass "docs/ARCHITECTURE.md#... (another file) is not a citation" || fail "arch other: '$out'"
check "exactly the two findings" test "$(grep -c 'broken anchor' <<< "$out")" -eq 2
out="$(bash "$CDA" "$R/headed" 2>&1)"; rc=$?
check "a design setting with #heading: the file is checked whole ($out)" test "$rc" -eq 0
out="$(bash "$CDA" "$R/nonep" 2>&1)"; rc=$?
check "design=none: the root design is not checked; a part's still is" test "$rc" -eq 1
[[ "$out" == *"keeps no design"* && "$out" == *"#gone"* && "$out" != *"#intro"* ]] && pass "design=none names itself and checks the part" || fail "none: '$out'"
out="$(bash "$CDA" "$R/missing" 2>&1)"; rc=$?
check "a design setting naming a missing file: exit 2" test "$rc" -eq 2
out="$(bash "$CDA" "$WSC" 2>&1)"; rc=$?
check "the workspace root reads docs/design.md ($out)" test "$rc" -eq 0
printf 'See docs/design.md#gone.\n' > "$WSC/README.md"
out="$(bash "$CDA" "$WSC" 2>&1)"; rc=$?
check "the workspace root: a broken docs/design.md citation fails" test "$rc" -eq 1
g -C "$WSC" checkout -q -- README.md

echo "TEST: sitrep_checks.sh's default roadmap"
SC="$S/sitrep_checks.sh"
out="$(bash "$SC" --root "$R/nonep" 2>&1)"
[[ "$out" == *"(roadmap not found: $R/nonep keeps no roadmap (roadmap=none))"* ]] && pass "roadmap=none: the existing docs/roadmap.md is not read" || fail "checks none: '$out'"
out="$(bash "$SC" --root "$R/missing" 2>&1)"
[[ "$out" == *"(roadmap not found: $R/missing/notes/gone.md)"* ]] && pass "a missing set file is the one named" || fail "checks missing: '$out'"
out="$(bash "$SC" --root "$R/escape" 2>&1)"
[[ "$out" == *"(roadmap not readable: "*"resolves outside"* ]] && pass "a setting that leaves the root is not readable, with the reason" || fail "checks escape: '$out'"
out="$(bash "$SC" --root "$R/ptr" 2>&1)"
[[ "$out" == *"Plan line"* && "$out" != *"Decoy line"* ]] && pass "a keyed project's Direction comes from the set file, not docs/roadmap.md" || fail "checks ptr: '$out'"
printf 'roadmap=notes/a\tb.md\n' > "$WSC/.agent/projects.d/loose"
out="$(bash "$SC" --root "$R/loose" 2>/dev/null | grep '^section')"
check "a refused value's reason keeps the section row at five fields ($out)" test "$(awk -F'\t' '{print NF}' <<< "$out")" = 5
[[ "$out" == *"not readable"* ]] && pass "the row says not readable" || fail "tab row: '$out'"
rm -f "$WSC/.agent/projects.d/loose"

echo "TEST: the merge gate's bookkeeping paths include the roadmap setting's file"
bk_paths() { (source "$S/_bookkeeping.sh"; bookkeeping_roadmap_paths "$1"); }
check "a worktree of a keyed project adds notes/plan.md" test "$(bk_paths "$R/keyed/worktrees/wt" | tail -n1)" = "notes/plan.md"
check "the fixed list is still there" test "$(bk_paths "$R/keyed/worktrees/wt" | head -n3 | tr '\n' ' ')" = "ROADMAP.md docs/ROADMAP.md docs/roadmap.md "
check "the workspace adds nothing" test "$(bk_paths "$WSC" | wc -l)" -eq 3
check "a workspace worktree adds nothing" test "$(bk_paths "$WSC/worktrees/wsb" | wc -l)" -eq 3
check "an unset setting adds nothing" test "$(bk_paths "$R/plain" | wc -l)" -eq 3
check "roadmap=none adds nothing" test "$(bk_paths "$R/nonep" | wc -l)" -eq 3
check "a root inside another repository adds nothing (its path is not the repository's)" test "$(bk_paths "$R/host/sub" | wc -l)" -eq 3
# merge_pr.sh's CI bookkeeping patterns, run from its own text with the
# PR's worktree (_ci_wt) set and without.
ci_patterns() {
    (source "$S/_bookkeeping.sh"; _ci_wt="$1"
     eval "$(sed -n '/^MERGE_PR_CI_BOOKKEEPING_PATTERNS=(/,/^fi$/p' "$S/merge_pr.sh")"
     printf '%s\n' "${MERGE_PR_CI_BOOKKEEPING_PATTERNS[@]}")
}
check "merge_pr.sh's CI patterns with a keyed worktree add the set roadmap" \
    test "$(ci_patterns "$R/keyed/worktrees/wt" | tr '\n' ' ')" = ".agent/work-plans/* ROADMAP.md docs/ROADMAP.md docs/roadmap.md notes/plan.md "
check "merge_pr.sh's CI patterns without a worktree are the fixed list" \
    test "$(ci_patterns "" | tr '\n' ' ')" = ".agent/work-plans/* ROADMAP.md docs/ROADMAP.md docs/roadmap.md "
WT="$R/keyed/worktrees/wt"
g -C "$WT" add -A && g -C "$WT" commit -q -m "code"
REVIEWED="$(g -C "$WT" rev-parse HEAD)"
printf -- '- [x] More (#7)\n' >> "$WT/notes/plan.md"
g -C "$WT" commit -q -am "Update roadmap: mark #7 as done"
TICK="$(g -C "$WT" rev-parse HEAD)"
why="$(bash "$S/_bookkeeping.sh" --review "$WT" "$REVIEWED" "$TICK" 7)"; rc=$?
check "a tick of the key-named roadmap after review is bookkeeping ($why)" test "$rc" -eq 0
printf 'x\n' > "$WT/notes/plan.md.bak"
g -C "$WT" add -A && g -C "$WT" commit -q -m "neighbour"
why="$(bash "$S/_bookkeeping.sh" --review "$WT" "$REVIEWED" "$(g -C "$WT" rev-parse HEAD)" 7)"; rc=$?
check "a neighbouring file is not bookkeeping" test "$rc" -eq 1
[[ "$why" == *"notes/plan.md.bak"* ]] && pass "the neighbour is named" || fail "neighbour: '$why'"

echo ""
echo "test_project_documents: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
