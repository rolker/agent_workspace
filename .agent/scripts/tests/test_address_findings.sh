#!/usr/bin/env bash
# .agent/scripts/tests/test_address_findings.sh
# Tests for the address-findings mechanics (issue #269 PR D):
#   review_progress.sh findings — selects the single latest Integrated Review
#     / Local Review (Pre-Push) entry (never a legacy External Review, never
#     the post-PR Local Review) and lists its open findings with indexes
#   review_progress.sh check — flips exactly one box, optionally with a
#     (deferred: reason) annotation; refuses re-checks and bad indexes
#   the closing ## Implementation entry, written through persist, carries
#     **Addressed** pointing at the source entry and parses with a
#     branch correlation
# Hermetic: mktemp -d sandboxes only.
# Run: bash .agent/scripts/tests/test_address_findings.sh

set -u
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RP="$SCRIPT_DIR/../review_progress.sh"
PR="$SCRIPT_DIR/../progress_read.py"
PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export AGENT_NAME="Test Agent"
export AGENT_EMAIL="test+agent@example.com"

# Fixture (plan: 2 unchecked findings, 1 must-fix + 1 suggestion) preceded by
# entries that must NOT be selected: a legacy External Review with open
# boxes, a post-PR Local Review, and an older Pre-Push review with an open box.
REPO="$TMPD/issue-workspace-7"; mkdir -p "$REPO"; git -C "$REPO" init -q -b feature/issue-7
git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
PROG="$REPO/.agent/work-plans/issue-7/progress.md"; mkdir -p "$(dirname "$PROG")"
cat > "$PROG" <<'EOF'
---
issue: 7
---

# Issue #7 — Fixture

## External Review
**Status**: complete
**When**: 2026-09-10 09:00 -04:00
**By**: t (m)

**PR**: #70 at `0000001`

### Actions
- [ ] legacy open action that must never be selected

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-16 09:00 -04:00
**By**: t (m)
**Verdict**: changes-requested

**Branch**: feature/issue-7 at `1111111`
**Base**: main

### Findings
- [ ] (must-fix) older round, superseded — `a.sh:1`

## Local Review
**Status**: complete
**When**: 2026-09-16 10:00 -04:00
**By**: t (m)
**Verdict**: changes-requested

**PR**: #70 at `2222222`

### Findings
- [ ] (must-fix) post-PR local review, not a source for address-findings — `b.sh:1`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)
**Verdict**: changes-requested

**Branch**: feature/issue-7 at `abc1234`
**Base**: main
**Must-fix**: 1 | **Suggestions**: 1

### Findings
- [x] (must-fix) already handled last round — `z.sh:9`
- [ ] (must-fix) unchecked append redirect exits 0 on failure — `.agent/scripts/progress_append.sh:142`
- [ ] (suggestion) usage text mentions a removed flag — `.agent/scripts/review_progress.sh:59`

### False positives
- (Copilot) jq missing — bootstrap installs jq
EOF
git -C "$REPO" add -A && git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m fixture

# ---- findings ----
out=$("$RP" findings --progress "$PROG"); rc=$?
stype=$(printf '%s' "$out" | jq -r '.source.type'); ssha=$(printf '%s' "$out" | jq -r '.source.correlation.sha')
n_open=$(printf '%s' "$out" | jq '.open | length'); idx=$(printf '%s' "$out" | jq -c '[.open[].index]')
if [[ "$rc" -eq 0 && "$stype" == "Local Review (Pre-Push)" && "$ssha" == "abc1234" && "$n_open" -eq 2 && "$idx" == "[1,2]" ]]; then
    pass "findings: selects the latest Pre-Push entry (sha abc1234), 2 open of 3, indexes skip the checked one"
else
    fail "findings: selection (rc=$rc type=$stype sha=$ssha open=$n_open idx=$idx)"
fi
# an Integrated Review appended later becomes the source instead
cp "$PROG" "$TMPD/with_ir.md"
printf '\n## Integrated Review\n**Status**: complete\n**When**: 2026-09-17 11:00 -04:00\n**By**: t (m)\n\n**PR**: #70 at `abc1234`\n\n### Findings\n- [ ] (cross-confirmed) the redirect — `.agent/scripts/progress_append.sh`\n' >> "$TMPD/with_ir.md"
out=$("$RP" findings --progress "$TMPD/with_ir.md")
[[ "$(printf '%s' "$out" | jq -r '.source.type')" == "Integrated Review" && "$(printf '%s' "$out" | jq '.open|length')" -eq 1 ]] \
    && pass "findings: a later Integrated Review supersedes the Pre-Push entry as the source" || fail "findings: IR supersedes"
# no qualifying entry -> source null, exit 0
printf -- '---\nissue: 8\n---\n\n## External Review\n**PR**: #1 at `x`\n\n### Actions\n- [ ] legacy\n' > "$TMPD/none.md"
out=$("$RP" findings --progress "$TMPD/none.md"); rc=$?
[[ "$rc" -eq 0 && "$(printf '%s' "$out" | jq '.source')" == "null" ]] && pass "findings: only a legacy External Review -> source null (never acted on)" || fail "findings: legacy only (rc=$rc out=$out)"
# malformed file -> loud
printf '## Implementation\n```\nopen\n' > "$TMPD/bad.md"
"$RP" findings --progress "$TMPD/bad.md" >/dev/null 2>&1; rc=$?
[[ "$rc" -ne 0 ]] && pass "findings: malformed progress.md fails loudly" || fail "findings: malformed should fail"

# ---- check ----
line=$("$RP" check --progress "$PROG" --index 1); rc=$?
if [[ "$rc" -eq 0 && "$line" == "- [x] (must-fix) unchecked append redirect exits 0 on failure — \`.agent/scripts/progress_append.sh:142\`" ]] \
    && [[ "$(grep -c '^- \[x\] (must-fix) unchecked append' "$PROG")" -eq 1 ]] \
    && [[ "$(grep -c '^- \[ \] (must-fix) older round' "$PROG")" -eq 1 ]] \
    && [[ "$(grep -c '^- \[ \] (must-fix) post-PR local review' "$PROG")" -eq 1 ]]; then
    pass "check: index 1 flips only that box in the latest source entry; older entries' boxes untouched"
else
    fail "check: fix-and-check (rc=$rc line=$line)"
fi
line=$("$RP" check --progress "$PROG" --index 2 --deferred "flag is still documented on purpose"); rc=$?
[[ "$rc" -eq 0 && "$line" == *"- [x] (suggestion) usage text"*"(deferred: flag is still documented on purpose)" ]] \
    && pass "check: --deferred checks the box and appends the reason" || fail "check: defer (rc=$rc line=$line)"
"$RP" check --progress "$PROG" --index 1 >/dev/null 2>&1; rc=$?
[[ "$rc" -eq 2 ]] && pass "check: re-checking an already checked box is refused (rc 2)" || fail "check: re-check (rc=$rc)"
"$RP" check --progress "$PROG" --index 3 >/dev/null 2>&1; rc=$?
[[ "$rc" -eq 2 ]] && pass "check: out-of-range index is refused (rc 2)" || fail "check: range (rc=$rc)"
out=$("$RP" findings --progress "$PROG")
[[ "$(printf '%s' "$out" | jq '.open|length')" -eq 0 ]] && pass "findings: after both checks the source entry has no open findings (idempotent re-run)" || fail "findings: none open after checks"
# the deferred annotation survives the parser: still a finding, checked
n=$(python3 "$PR" "$PROG" --type "Local Review (Pre-Push)" | jq '[.entries[-1].findings[] | select(.checked)] | length')
[[ "$n" -eq 3 ]] && pass "check: progress_read.py still parses all three boxes as checked findings" || fail "check: parser (n=$n)"

# ---- Implementation entry via persist, Addressed points at the source ----
# ---- divergence traps (round-1 review): a fenced decoy, an indented box, and
#      a header-area box must not shift indexes or be flipped ----
TRAP="$TMPD/trap.md"
cat > "$TRAP" <<'EOF'
## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)
- [ ] header-area box, not a finding

**Branch**: feature/issue-7 at `abc1234`

### Findings
```
- [ ] fenced example, not a finding
```
  - [ ] indented, not a finding
- [ ] (must-fix) real finding A — `a.sh:1`
- [ ] (suggestion) real finding B — `b.sh:2`
EOF
out=$("$RP" findings --progress "$TRAP")
[[ "$(printf '%s' "$out" | jq '.open|length')" -eq 2 && "$(printf '%s' "$out" | jq -r '.open[0].text')" == *"real finding A"* ]] \
    && pass "findings: decoys (header box, fenced box, indented box) are not findings" || fail "findings: decoys (out=$out)"
line=$("$RP" check --progress "$TRAP" --index 0)
if [[ "$line" == *"real finding A"* ]] && grep -q '^- \[x\] (must-fix) real finding A' "$TRAP" \
    && grep -q '^- \[ \] header-area box' "$TRAP" && grep -q '^- \[ \] fenced example' "$TRAP" && grep -q '^  - \[ \] indented' "$TRAP"; then
    pass "check: index 0 flips real finding A, never a decoy line"
else
    fail "check: decoy divergence (line=$line)"
fi
# CRLF file stays CRLF, only the one line changes
CR="$TMPD/crlf.md"
printf '## Local Review (Pre-Push)\r\n**Branch**: feature/issue-7 at `abc1234`\r\n\r\n### Findings\r\n- [ ] one — `x:1`\r\n- [ ] two — `y:2`\r\n' > "$CR"
before=$(md5sum < "$CR")
"$RP" check --progress "$CR" --index 1 --deferred "reason" >/dev/null
crlf=$(grep -c $'\r$' "$CR"); flipped=$(grep -c $'^- \[x\] two — `y:2` (deferred: reason)\r$' "$CR")
[[ "$crlf" -eq 6 && "$flipped" -eq 1 && "$(md5sum < "$CR")" != "$before" ]] \
    && pass "check: a CRLF file keeps CRLF on every line; only the target line changes" || fail "check: CRLF (crlf=$crlf flipped=$flipped)"
# --deferred "" is an error, not a silent plain check
"$RP" check --progress "$TRAP" --index 1 --deferred "" >/dev/null 2>&1; rc=$?
[[ "$rc" -eq 2 ]] && grep -q '^- \[ \] (suggestion) real finding B' "$TRAP" && pass "check: --deferred with an empty reason is refused (rc 2), box untouched" || fail "check: empty deferred (rc=$rc)"

git -C "$REPO" add -A && git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m "fix: findings"
ENTRY_FILE="$TMPD/impl_entry.md"
cat > "$ENTRY_FILE" <<'EOF'
## Implementation
**Status**: complete
**When**: 2026-09-17 12:00 -04:00
**By**: Test Agent (m)

**Branch**: feature/issue-7 at `def5678`
**Addressed**: Local Review (Pre-Push) at `abc1234` (2026-09-17 10:00 -04:00)
**Commits**: def5678

### Actions
- [x] unchecked append redirect exits 0 on failure — `.agent/scripts/progress_append.sh:142`
- [x] usage text mentions a removed flag — `.agent/scripts/review_progress.sh:59` (deferred: flag is still documented on purpose)
EOF
out=$(cd "$REPO" && "$RP" persist --issue 7 --branch feature/issue-7 --strict < "$ENTRY_FILE" 2>&1); rc=$?
impl=$(python3 "$PR" "$PROG" --type Implementation | jq -c '.entries[-1] | {kind: .correlation.kind, branch: .correlation.branch, n: (.findings|length), checked: ([.findings[]|select(.checked)]|length)}')
if [[ "$rc" -eq 0 && "$impl" == '{"kind":"branch","branch":"feature/issue-7","n":2,"checked":2}' ]] \
    && grep -q '^\*\*Addressed\*\*: Local Review (Pre-Push) at `abc1234`' "$PROG" \
    && [[ "$(git -C "$REPO" log -1 --format=%s)" == "progress: implementation for #7" ]]; then
    pass "Implementation entry: committed via persist, branch-correlated, Addressed names the source entry and its SHA, both actions checked"
else
    fail "Implementation entry (rc=$rc impl=$impl out=$out)"
fi

echo ""
echo "test_address_findings: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
