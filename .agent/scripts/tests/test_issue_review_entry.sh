#!/usr/bin/env bash
# .agent/scripts/tests/test_issue_review_entry.sh
# Tests for issue #276 PR 1 — review-issue step 8 writes `## Issue Review`:
#   a fixture comment persisted exactly as step 8 says (comment body minus
#     the "## Review" line and the signature, plus `### Actions`) is
#     accepted by review_progress.sh persist (strict path, matching
#     worktree) and parses with progress_read.py as
#       correlation == {"kind":"issue","issue":N}
#       findings[] == exactly the Action-needed rows' Notes, in table order,
#                     then the Recommendations bullets, in order — nothing
#                     from Watch rows, ADR notes or Consequences
#   the no-actions form (`- [x] No actions needed.`) parses with one
#     checked box and zero open boxes
#   an entry that keeps the "## Review" heading is refused (two top-level
#     headings = two entries)
# Hermetic: mktemp -d sandboxes only.
# Run: bash .agent/scripts/tests/test_issue_review_entry.sh
set -u
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD="$SCRIPT_DIR/../progress_read.py"
PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export AGENT_NAME="Test Agent"
export AGENT_EMAIL="test+agent@example.com"

# A workspace-shaped sandbox whose cwd is issue 42's worktree, so the strict
# resolver accepts the write (mirrors test_plan_correlation.sh).
SB="$TMPD/ws"
mkdir -p "$SB/.agent/scripts"
for f in review_progress.sh progress_append.sh _progress_entry.sh _resolve_work_plans_dir.sh _worktree_helpers.sh progress_read.py; do
    cp "$SCRIPT_DIR/../$f" "$SB/.agent/scripts/"
done
git -C "$SB" init -q -b main
git -C "$SB" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
WT="$SB/worktrees/workspace/issue-workspace-42"
mkdir -p "$SB/worktrees/workspace"
git -C "$SB" worktree add -q "$WT" -b feature/issue-42 >/dev/null 2>&1

# The comment body exactly as step 7 posts it (minus signature), minus the
# "## Review" line, plus the derived Actions — i.e. what step 8 appends.
ENTRY_BODY='### Scope Assessment

**Well-scoped?** Yes — one script and its test
**Right repo?** Yes — workspace
**Dependencies**: none identified

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | Action needed | Add a test for the new hook path |
| Only what is needed | Watch | Scope creep risk in the docs step |
| Test what breaks | Action needed | Cover the empty-input case |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 | Yes | Entry vocabulary applies |

### Consequences

- Update the script table row in AGENTS.md

### Recommendations

- Split the docs change into its own commit
- Name the new env var in the header comment

### Actions
- [ ] Add a test for the new hook path
- [ ] Cover the empty-input case
- [ ] Split the docs change into its own commit
- [ ] Name the new env var in the header comment'

HEADER='## Issue Review
**Status**: complete
**When**: 2026-09-18 12:00 -04:00
**By**: Test Agent (test-model)

**Issue**: #42
'

echo "TEST: step-8 entry persists (strict, matching worktree) and parses with issue correlation + exact Actions"
out=$(cd "$WT" && printf '%s\n%s\n' "$HEADER" "$ENTRY_BODY" | "$SB/.agent/scripts/review_progress.sh" persist --issue 42 --branch feature/issue-42 --title "Test issue" --strict --soft 2>&1) || true
PF="$WT/.agent/work-plans/issue-42/progress.md"
if [[ -f "$PF" ]] && [[ "$out" == *"Progress persisted"* ]]; then
    pass "persist wrote the entry (${out##*$'\n'})"
else
    fail "persist did not write the entry (out=${out:0:300})"
fi
json=$(python3 "$PRD" "$PF" --type "Issue Review" 2>/dev/null || echo "")
corr=$(jq -c '.entries[-1].correlation' <<<"$json" 2>/dev/null || echo "")
if [[ "$corr" == '{"kind":"issue","issue":42}' ]]; then
    pass "correlation is {kind: issue, issue: 42}"
else
    fail "correlation was $corr"
fi
texts=$(jq -r '.entries[-1].findings[] | "\(.checked)|\(.text)"' <<<"$json" 2>/dev/null || echo "")
expected='false|Add a test for the new hook path
false|Cover the empty-input case
false|Split the docs change into its own commit
false|Name the new env var in the header comment'
if [[ "$texts" == "$expected" ]]; then
    pass "findings are exactly the two Action-needed rows then the two Recommendations, in order, all open"
else
    fail "findings were:
$texts"
fi
if ! jq -e '.entries[-1].findings[] | select(.text | test("Scope creep|AGENTS.md|Entry vocabulary"))' <<<"$json" >/dev/null 2>&1; then
    pass "Watch rows, Consequences and ADR notes did not become findings"
else
    fail "a non-action line became a finding"
fi

echo "TEST: no-actions form carries one checked box and no open box"
NOACT="$HEADER
### Scope Assessment

**Well-scoped?** Yes

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what is needed | OK | fine |

### Recommendations

### Actions
- [x] No actions needed."
out=$(cd "$WT" && printf '%s\n' "$NOACT" | "$SB/.agent/scripts/review_progress.sh" persist --issue 42 --branch feature/issue-42 --title "Test issue" --strict --soft 2>&1) || true
json=$(python3 "$PRD" "$PF" --type "Issue Review" 2>/dev/null || echo "")
n_open=$(jq '[.entries[-1].findings[] | select(.checked | not)] | length' <<<"$json" 2>/dev/null || echo "?")
n_all=$(jq '.entries[-1].findings | length' <<<"$json" 2>/dev/null || echo "?")
if [[ "$n_open" == "0" && "$n_all" == "1" ]]; then
    pass "no-actions entry: 1 finding, 0 open"
else
    fail "no-actions entry: findings=$n_all open=$n_open (out=${out:0:200})"
fi

echo "TEST: keeping the '## Review' heading inside the entry is refused"
BAD="$HEADER
## Review

### Actions
- [x] No actions needed."
out=$(cd "$WT" && printf '%s\n' "$BAD" | "$SB/.agent/scripts/review_progress.sh" persist --issue 42 --branch feature/issue-42 --title "Test issue" --strict --soft 2>&1) || true
if [[ "$out" == *"Progress persistence failed"* ]] && [[ "$(grep -c '^## Issue Review$' "$PF")" == "2" ]]; then
    pass "second top-level heading refused; timeline still has exactly the two good entries"
else
    fail "bad entry handling (out=${out:0:300}; entries=$(grep -c '^## Issue Review$' "$PF"))"
fi

echo ""
echo "test_issue_review_entry: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
