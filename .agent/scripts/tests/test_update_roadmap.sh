#!/usr/bin/env bash
# Tests for .agent/scripts/update_roadmap.sh roadmap discovery (issue #334):
# ROADMAP.md, docs/ROADMAP.md and docs/roadmap.md are all discovered, and a
# file reachable under two candidate spellings is processed once.
#
# Run: bash .agent/scripts/tests/test_update_roadmap.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE="${SCRIPT_DIR}/../update_roadmap.sh"

PASS=0
FAIL=0

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

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
# Stands in for a case-insensitive filesystem (macOS default).
root="$(mktemp -d "$TMP_ROOT/root.XXXXXX")"
mkdir -p "$root/docs"
printf '%s' "$roadmap_body" > "$root/docs/ROADMAP.md"
ln -s ROADMAP.md "$root/docs/roadmap.md"
stdout="$("$UPDATE" --issue 7 --root "$root" 2>"$TMP_ROOT/alias.err")"
stderr="$(cat "$TMP_ROOT/alias.err")"
# Without the same-file guard the second spelling is visited again and
# reports "docs/roadmap.md: #7 already checked" on stderr.
if [[ "$stdout" == "$root/docs/ROADMAP.md" ]] && [[ "$stderr" != *"docs/roadmap.md"* ]]; then
    pass "(alias) same file under both spellings: processed and reported once"
else
    fail "(alias) stdout='$stdout' stderr='$stderr'"
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

echo ""
echo "test_update_roadmap: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
