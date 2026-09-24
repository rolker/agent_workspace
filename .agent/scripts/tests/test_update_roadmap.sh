#!/usr/bin/env bash
# Tests for .agent/scripts/update_roadmap.sh roadmap discovery (issue #334):
# ROADMAP.md, docs/ROADMAP.md and docs/roadmap.md are all discovered, and a
# file reachable under two candidate spellings is processed once, under the
# name it is stored as. Runs on case-sensitive (Linux) and case-insensitive
# (macOS default) filesystems: the suite probes TMPDIR and adapts the
# "one file, two spellings" fixture.
#
# Run: bash .agent/scripts/tests/test_update_roadmap.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE="${SCRIPT_DIR}/../update_roadmap.sh"

PASS=0
FAIL=0

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

CASE_INSENSITIVE=false
touch "$TMP_ROOT/case_probe"
[[ -e "$TMP_ROOT/CASE_PROBE" ]] && CASE_INSENSITIVE=true
rm -f "$TMP_ROOT/case_probe"
echo "filesystem under TMPDIR: $($CASE_INSENSITIVE && echo case-insensitive || echo case-sensitive)"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

roadmap_body='# Roadmap

- [ ] Something (#7)
'

for rel in ROADMAP.md docs/ROADMAP.md docs/roadmap.md; do
    echo "TEST: roadmap at $rel is discovered and updated"
    root="$(mktemp -d "$TMP_ROOT/root.XXXXXX")"
    mkdir -p "$root/docs"
    printf '%s' "$roadmap_body" > "$root/$rel"
    stdout="$("$UPDATE" --issue 7 --root "$root" 2>/dev/null)"
    if [[ "$stdout" == "$root/$rel" ]] && grep -qF -- '- [x] Something (#7)' "$root/$rel"; then
        pass "($rel) checked off; changed path printed once"
    else
        fail "($rel) stdout='$stdout' file=$(tr '\n' '|' < "$root/$rel")"
    fi
done

echo "TEST: a file reachable as both docs/ROADMAP.md and docs/roadmap.md is processed once"
# On a case-insensitive filesystem the stored docs/ROADMAP.md answers both
# probes; on a case-sensitive one a symlink stands in for the second
# spelling (it exercises the -ef same-file guard).
root="$(mktemp -d "$TMP_ROOT/root.XXXXXX")"
mkdir -p "$root/docs"
printf '%s' "$roadmap_body" > "$root/docs/ROADMAP.md"
$CASE_INSENSITIVE || ln -s ROADMAP.md "$root/docs/roadmap.md"
stdout="$("$UPDATE" --issue 7 --root "$root" 2>"$TMP_ROOT/alias.err")"
stderr="$(cat "$TMP_ROOT/alias.err")"
# Without the same-file guard the second spelling is visited again and
# reports "docs/roadmap.md: #7 already checked" on stderr.
if [[ "$stdout" == "$root/docs/ROADMAP.md" ]] && [[ "$stderr" != *"docs/roadmap.md"* ]]; then
    pass "(alias) same file under both spellings: processed and reported once"
else
    fail "(alias) stdout='$stdout' stderr='$stderr'"
fi

echo "TEST: a stored docs/roadmap.md keeps its name through the update"
# On a case-insensitive filesystem the docs/ROADMAP.md probe (checked
# first) opens this file; it must be reported, and written back, as
# docs/roadmap.md.
root="$(mktemp -d "$TMP_ROOT/root.XXXXXX")"
mkdir -p "$root/docs"
printf '%s' "$roadmap_body" > "$root/docs/roadmap.md"
stdout="$("$UPDATE" --issue 7 --root "$root" 2>/dev/null)"
stored="$(cd "$root/docs" && printf '%s\n' *)"
if [[ "$stdout" == "$root/docs/roadmap.md" ]] && [[ "$stored" == "roadmap.md" ]]; then
    pass "(stored-name) reported as docs/roadmap.md; directory still holds roadmap.md"
else
    fail "(stored-name) stdout='$stdout' docs/ holds: $stored"
fi

echo "TEST: distinct root and docs/ roadmaps are both still processed"
root="$(mktemp -d "$TMP_ROOT/root.XXXXXX")"
mkdir -p "$root/docs"
printf '%s' "$roadmap_body" > "$root/ROADMAP.md"
printf '%s' "$roadmap_body" > "$root/docs/roadmap.md"
stdout="$("$UPDATE" --issue 7 --root "$root" 2>/dev/null)"
if [[ "$stdout" == "$root/ROADMAP.md"$'\n'"$root/docs/roadmap.md" ]]; then
    pass "(both) two distinct roadmap files: both updated"
else
    fail "(both) stdout='$stdout'"
fi

echo "TEST: without _real_case_path.sh the roadmap is still updated, with a warning"
# update_roadmap.sh never blocks a merge: a copy of it with no helper beside
# it warns on stderr naming the helper and updates via the candidate spelling.
# The fixture is stored as docs/ROADMAP.md — the first docs/ probe — so the
# candidate spelling that finds it is its stored name on case-sensitive and
# case-insensitive filesystems alike (a stored docs/roadmap.md would be found,
# and reported, as docs/ROADMAP.md on macOS without the helper).
nohelper="$(mktemp -d "$TMP_ROOT/nohelper.XXXXXX")"
cp "$UPDATE" "$nohelper/update_roadmap.sh"
[[ ! -e "$nohelper/_real_case_path.sh" ]] || fail "(no-helper) fixture: helper unexpectedly present"
root="$(mktemp -d "$TMP_ROOT/root.XXXXXX")"
mkdir -p "$root/docs"
printf '%s' "$roadmap_body" > "$root/docs/ROADMAP.md"
rc=0
stdout="$("$nohelper/update_roadmap.sh" --issue 7 --root "$root" 2>"$TMP_ROOT/nohelper.err")" || rc=$?
stderr="$(cat "$TMP_ROOT/nohelper.err")"
if [[ "$stderr" == *"_real_case_path.sh not found"* ]]; then
    pass "(no-helper) stderr warning names _real_case_path.sh"
else
    fail "(no-helper) stderr was: $stderr"
fi
if [[ $rc -eq 0 ]] && [[ "$stdout" == "$root/docs/ROADMAP.md" ]] \
    && grep -qF -- '- [x] Something (#7)' "$root/docs/ROADMAP.md"; then
    pass "(no-helper) roadmap still checked off; changed path printed"
else
    fail "(no-helper) rc=$rc stdout='$stdout' file=$(tr '\n' '|' < "$root/docs/ROADMAP.md")"
fi

echo ""
echo "test_update_roadmap:${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
