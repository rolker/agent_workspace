#!/usr/bin/env bash
# Tests for .agent/scripts/_real_case_path.sh (issue #334).
#
# real_case_relpath resolves the stored spelling of a path by listing each
# directory, so its case-insensitive branch is exercised on a case-sensitive
# (Linux) filesystem too: asking for docs/principles.md where only
# docs/PRINCIPLES.md is stored is exactly the lookup a case-insensitive
# filesystem answers with that file. The discovery scripts only call it on
# paths that exist, so on macOS the same fixtures hold.
#
# Run: bash .agent/scripts/tests/test_real_case_path.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../_real_case_path.sh
source "${SCRIPT_DIR}/../_real_case_path.sh"

PASS=0
FAIL=0

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# expect <label> <base> <rel> <expected>
expect() {
    local label="$1" base="$2" rel="$3" want="$4" got
    got="$(real_case_relpath "$base" "$rel")"
    if [[ "$got" == "$want" ]]; then
        pass "$label"
    else
        fail "$label (real_case_relpath '$rel' -> '$got', want '$want')"
    fi
}

CASE_INSENSITIVE=false
touch "$TMP_ROOT/case_probe"
[[ -e "$TMP_ROOT/CASE_PROBE" ]] && CASE_INSENSITIVE=true
rm -f "$TMP_ROOT/case_probe"

echo "TEST: stored uppercase name is returned for a lowercase request"
b="$(mktemp -d "$TMP_ROOT/b.XXXXXX")"
mkdir -p "$b/docs"
touch "$b/docs/PRINCIPLES.md"
expect "(R1) docs/principles.md -> docs/PRINCIPLES.md" "$b" docs/principles.md docs/PRINCIPLES.md
expect "(R2) exact request unchanged" "$b" docs/PRINCIPLES.md docs/PRINCIPLES.md

echo "TEST: stored lowercase name is returned for an uppercase request"
b="$(mktemp -d "$TMP_ROOT/b.XXXXXX")"
mkdir -p "$b/docs"
touch "$b/docs/roadmap.md"
expect "(R3) docs/ROADMAP.md -> docs/roadmap.md" "$b" docs/ROADMAP.md docs/roadmap.md

echo "TEST: every component below the base is resolved, dot-entries included"
b="$(mktemp -d "$TMP_ROOT/b.XXXXXX")"
mkdir -p "$b/Project/Docs" "$b/.Agents"
touch "$b/Project/Docs/Design.md" "$b/.Agents/Readme.md"
expect "(R4) project/docs/design.md -> Project/Docs/Design.md" "$b" project/docs/design.md Project/Docs/Design.md
expect "(R5) .agents/README.md -> .Agents/Readme.md" "$b" .agents/README.md .Agents/Readme.md

echo "TEST: a missing path is kept as given from the first missing component"
b="$(mktemp -d "$TMP_ROOT/b.XXXXXX")"
mkdir -p "$b/Docs"
expect "(R6) Docs resolved, missing leaf kept" "$b" docs/nothing.md Docs/nothing.md
expect "(R7) missing directory: rest kept verbatim" "$b" none/Docs/x.md none/Docs/x.md

if ! $CASE_INSENSITIVE; then
    echo "TEST: when a directory holds both spellings, the exact one wins"
    b="$(mktemp -d "$TMP_ROOT/b.XXXXXX")"
    mkdir -p "$b/docs"
    touch "$b/docs/PRINCIPLES.md" "$b/docs/principles.md"
    expect "(R8) exact lowercase wins" "$b" docs/principles.md docs/principles.md
    expect "(R9) exact uppercase wins" "$b" docs/PRINCIPLES.md docs/PRINCIPLES.md
fi

echo "TEST: the caller's nocasematch setting is left untouched"
shopt -u nocasematch
real_case_relpath "$b" docs/x.md >/dev/null
if shopt -q nocasematch; then
    fail "(R10) nocasematch leaked into the caller"
else
    pass "(R10) nocasematch still off in the caller"
fi

echo ""
echo "test_real_case_path: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
