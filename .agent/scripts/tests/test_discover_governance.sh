#!/usr/bin/env bash
# Tests for .agent/scripts/discover_governance.sh (issue #334).
#
# The script derives ROOT_DIR from its own location (two levels above
# .agent/scripts/), so each fixture copies it into <sandbox>/.agent/scripts/
# and lays governance files out under <sandbox>/ (workspace scope) and
# <sandbox>/project/ (project scope). No environment override is used.
#
# The fixtures run on case-sensitive (Linux) and case-insensitive (macOS
# default) filesystems alike: the suite probes which one TMPDIR is and
# builds the "one file, two spellings" fixture accordingly. On either,
# a file is expected under the name it is stored as.
#
# Run: bash .agent/scripts/tests/test_discover_governance.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISCOVER="${SCRIPT_DIR}/../discover_governance.sh"

PASS=0
FAIL=0

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Case-insensitive filesystem? (a stored lowercase name opens as uppercase)
CASE_INSENSITIVE=false
touch "$TMP_ROOT/case_probe"
[[ -e "$TMP_ROOT/CASE_PROBE" ]] && CASE_INSENSITIVE=true
rm -f "$TMP_ROOT/case_probe"
echo "filesystem under TMPDIR: $($CASE_INSENSITIVE && echo case-insensitive || echo case-sensitive)"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# assert_row <label> <tsv-output> <path> <type> <scope>
assert_row() {
    local label="$1" out="$2" path="$3" type="$4" scope="$5"
    if printf '%s\n' "$out" | awk -F'\t' -v p="$path" -v t="$type" -v s="$scope" \
        '$1==p && $2==t && $4==s {found=1} END {exit !found}'; then
        pass "$label"
    else
        fail "$label (no row '$path' $type $scope in:"$'\n'"$out)"
    fi
}

# assert_row_count <label> <tsv-output> <type> <scope> <expected>
assert_row_count() {
    local label="$1" out="$2" type="$3" scope="$4" expected="$5" n
    n=$(printf '%s\n' "$out" | awk -F'\t' -v t="$type" -v s="$scope" '$2==t && $4==s' | wc -l | tr -d ' ')
    if [[ "$n" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label (expected $expected $type/$scope rows, got $n in:"$'\n'"$out)"
    fi
}

# make_sandbox -> prints a fresh sandbox dir holding a copy of the script
make_sandbox() {
    local sb
    sb="$(mktemp -d "$TMP_ROOT/sb.XXXXXX")"
    mkdir -p "$sb/.agent/scripts"
    cp "$DISCOVER" "$sb/.agent/scripts/discover_governance.sh"
    cp "$(dirname "$DISCOVER")/_real_case_path.sh" "$sb/.agent/scripts/_real_case_path.sh"
    echo "$sb"
}

run_discover() {  # <sandbox> [args...]
    local sb="$1"; shift
    "$sb/.agent/scripts/discover_governance.sh" "$@"
}

echo "TEST: workspace scope, new lowercase docs/ spelling only (the workspace's own shape)"
sb="$(make_sandbox)"
mkdir -p "$sb/docs"
echo "# Design" > "$sb/docs/design.md"
echo "# Principles" > "$sb/docs/principles.md"
out="$(run_discover "$sb")"
assert_row "(A1) docs/design.md found as architecture, workspace scope" "$out" docs/design.md architecture workspace
assert_row "(A2) docs/principles.md found as principles, workspace scope" "$out" docs/principles.md principles workspace
assert_row_count "(A3) exactly one architecture row" "$out" architecture workspace 1
assert_row_count "(A4) exactly one principles row" "$out" principles workspace 1

echo "TEST: project scope, old root/uppercase spelling"
sb="$(make_sandbox)"
mkdir -p "$sb/project"
echo "# Architecture" > "$sb/project/ARCHITECTURE.md"
echo "# Principles" > "$sb/project/PRINCIPLES.md"
out="$(run_discover "$sb")"
assert_row "(B1) project/ARCHITECTURE.md found, project scope" "$out" project/ARCHITECTURE.md architecture project
assert_row "(B2) project/PRINCIPLES.md found, project scope" "$out" project/PRINCIPLES.md principles project
assert_row_count "(B3) no workspace-scope architecture row from an empty workspace" "$out" architecture workspace 0

echo "TEST: project scope, old docs/PRINCIPLES.md spelling"
sb="$(make_sandbox)"
mkdir -p "$sb/project/docs"
echo "# Principles" > "$sb/project/docs/PRINCIPLES.md"
out="$(run_discover "$sb")"
assert_row "(B4) project/docs/PRINCIPLES.md still found" "$out" project/docs/PRINCIPLES.md principles project

echo "TEST: project scope, new lowercase docs/ spelling"
sb="$(make_sandbox)"
mkdir -p "$sb/project/docs"
echo "# Design" > "$sb/project/docs/design.md"
echo "# Principles" > "$sb/project/docs/principles.md"
out="$(run_discover "$sb")"
assert_row "(C1) project/docs/design.md found, project scope" "$out" project/docs/design.md architecture project
assert_row "(C2) project/docs/principles.md found, project scope" "$out" project/docs/principles.md principles project

echo "TEST: one file reachable under both docs/ spellings is reported once, under its stored name"
# On a case-insensitive filesystem the one stored docs/PRINCIPLES.md already
# answers both probes. On a case-sensitive one a symlink stands in for the
# second spelling (it exercises the -ef same-file guard).
sb="$(make_sandbox)"
mkdir -p "$sb/docs"
echo "# Principles" > "$sb/docs/PRINCIPLES.md"
$CASE_INSENSITIVE || ln -s PRINCIPLES.md "$sb/docs/principles.md"
out="$(run_discover "$sb")"
assert_row_count "(D1) same file under both spellings: one principles row" "$out" principles workspace 1
assert_row "(D2) the row names the stored spelling docs/PRINCIPLES.md" "$out" docs/PRINCIPLES.md principles workspace

echo "TEST: a stored lowercase docs/principles.md is reported as docs/principles.md"
# On a case-insensitive filesystem the docs/PRINCIPLES.md probe (checked
# first) also opens this file; the report must still use the stored name.
sb="$(make_sandbox)"
mkdir -p "$sb/project/docs"
echo "# Principles" > "$sb/project/docs/principles.md"
out="$(run_discover "$sb")"
assert_row_count "(D3) one principles row" "$out" principles project 1
assert_row "(D4) the row names the stored spelling project/docs/principles.md" "$out" project/docs/principles.md principles project

echo "TEST: --json emits the new-spelling rows too"
sb="$(make_sandbox)"
mkdir -p "$sb/docs"
echo "# Design" > "$sb/docs/design.md"
out="$(run_discover "$sb" --json)"
if [[ "$out" == *'"path":"docs/design.md","type":"architecture"'*'"scope":"workspace"'* ]]; then
    pass "(E1) --json: docs/design.md architecture row"
else
    fail "(E1) --json output: $out"
fi

echo "TEST: without _real_case_path.sh the report still runs, with a warning"
# The helper is sourced at startup; a copy without it must not abort
# (set -euo pipefail) — it warns on stderr naming the helper and reports
# using the candidate spellings.
sb="$(make_sandbox)"
rm "$sb/.agent/scripts/_real_case_path.sh"
mkdir -p "$sb/docs" "$sb/project"
echo "# Design" > "$sb/docs/design.md"
echo "# Architecture" > "$sb/project/ARCHITECTURE.md"
rc=0
out="$(run_discover "$sb" 2>"$TMP_ROOT/nohelper.err")" || rc=$?
err="$(cat "$TMP_ROOT/nohelper.err")"
if [[ $rc -eq 0 ]]; then
    pass "(F1) helper missing: exits 0"
else
    fail "(F1) helper missing: exit $rc, stderr: $err"
fi
if [[ "$err" == *"WARNING"*"_real_case_path.sh not found"* ]]; then
    pass "(F2) helper missing: stderr warning names _real_case_path.sh"
else
    fail "(F2) helper missing: stderr was: $err"
fi
assert_row "(F3) helper missing: docs/design.md still reported" "$out" docs/design.md architecture workspace
assert_row "(F4) helper missing: project/ARCHITECTURE.md still reported" "$out" project/ARCHITECTURE.md architecture project

echo ""
echo "test_discover_governance:${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
