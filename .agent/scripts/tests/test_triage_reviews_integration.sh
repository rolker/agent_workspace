#!/usr/bin/env bash
# .agent/scripts/tests/test_triage_reviews_integration.sh
# Tests for the triage-reviews integrator mechanics (issue #269 PR C):
#   - review_progress.sh sources: local review findings at the PR head +
#     GitHub inline comments -> candidate cross-source confirmations (one row
#     for a finding both sources raise on the same file at the same head SHA,
#     not two), with stale-head comments and other-head local entries excluded
#   - sources coverage (#309): a review at an ancestor with only bookkeeping
#     changes since (this issue's work-plan dir, the roadmap files) still
#     covers the head, in real git histories; stale / unverifiable entries
#     are listed in dropped_entries, never silently lost
#   - review_progress.sh persist for an `## Integrated Review` entry through
#     triage-reviews' own call site: strict abort on a mismatched worktree,
#     compatibility notice + inline commit, matching worktree no-notice,
#     degradation (skill worktree / no linked issue) skips without aborting
#
# All cases run in mktemp -d sandboxes; host worktree state is cleared first.
# Run: bash .agent/scripts/tests/test_triage_reviews_integration.sh

set -u
unset WORKTREE_ISSUE WORK_PLANS_DIR_OVERRIDE PROGRESS_PERSISTENCE_STRICT
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RP="$SCRIPT_DIR/../review_progress.sh"
PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
export AGENT_NAME="Test Agent"
export AGENT_EMAIL="test+agent@example.com"

# ========================================================== sources =====
HEAD=abc1234def5678
PROG="$TMPD/progress.md"
cat > "$PROG" <<'EOF'
---
issue: 7
---

# Issue #7 — Fixture

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 10:00 -04:00
**By**: t (m)
**Verdict**: changes-requested

**Branch**: feature/issue-7 at `0ld0000`
**Base**: main
**Must-fix**: 1 | **Suggestions**: 0

### Findings
- [x] (must-fix) stale finding fixed since — `.agent/scripts/old.sh:3`

## Local Review
**Status**: complete
**When**: 2026-09-17 11:00 -04:00
**By**: t (m)
**Verdict**: changes-requested

**PR**: #70 at `abc1234`
**Depth**: Standard
**Must-fix**: 2 | **Suggestions**: 1

### Findings
- [ ] (must-fix) unchecked append redirect exits 0 on failure — `.agent/scripts/progress_append.sh:142`
- [ ] (must-fix) gate pools fields across adjacent blocks — `.agent/scripts/tests/test_checkpoint_269.sh:72-76`
- [ ] (suggestion) doc nit — `AGENTS.md`

### False positives
- (Copilot) jq missing breaks suites — bootstrap installs jq
EOF
REVIEWS="$TMPD/reviews.json"
cat > "$REVIEWS" <<EOF
{
  "pr": 70, "repo": "o/r", "head_sha": "$HEAD",
  "reviews": [
    {"review_id": 1, "state": "COMMENTED", "body": "", "commit_id": "$HEAD", "user_login": "copilot-pull-request-reviewer", "user_type": "Bot",
     "comments": [
       {"path": ".agent/scripts/progress_append.sh", "line": 143, "body": "The append redirection is not checked; a failed write reports success."},
       {"path": ".pre-commit-config.yaml", "line": 62, "body": "jq is not provisioned."}
     ]},
    {"review_id": 2, "state": "COMMENTED", "body": "", "commit_id": "0ld00001111", "user_login": "copilot-pull-request-reviewer", "user_type": "Bot",
     "comments": [
       {"path": ".agent/scripts/tests/test_checkpoint_269.sh", "line": 76, "body": "stale-head comment on the gate"}
     ]}
  ],
  "ci_checks": [], "conversation_comments": []
}
EOF
out=$("$RP" sources --progress "$PROG" --head "$HEAD" --reviews "$REVIEWS"); rc=$?
n_local=$(printf '%s' "$out" | jq '.local_findings | length')
n_cand=$(printf '%s' "$out" | jq '.candidates | length')
cand_file=$(printf '%s' "$out" | jq -r '.candidates[0].file')
if [[ "$rc" -eq 0 && "$n_local" -eq 3 && "$n_cand" -eq 1 && "$cand_file" == ".agent/scripts/progress_append.sh" ]]; then
    pass "sources: one Local Review finding + one Copilot comment on the same file at the same head -> exactly one candidate row"
else
    fail "sources: single cross-source candidate (rc=$rc local=$n_local cand=$n_cand file=$cand_file)"
fi
# the other-head local entry and the stale-head GitHub comment are excluded from matching
stale_local=$(printf '%s' "$out" | jq '[.local_findings[] | select(.sha == "0ld0000")] | length')
stale_gh=$(printf '%s' "$out" | jq '[.github_comments[] | select(.at_head == false)] | length')
gate_cand=$(printf '%s' "$out" | jq '[.candidates[] | select(.file | test("checkpoint"))] | length')
if [[ "$stale_local" -eq 0 && "$stale_gh" -eq 1 && "$gate_cand" -eq 0 ]]; then
    pass "sources: local entries at another head are dropped; a stale-head GitHub comment is listed but never matched"
else
    fail "sources: head-SHA correlation (stale_local=$stale_local stale_gh=$stale_gh gate_cand=$gate_cand)"
fi
# false-positive bullets are not findings
fp=$(printf '%s' "$out" | jq '[.local_findings[] | select(.text | test("jq missing"))] | length')
[[ "$fp" -eq 0 ]] && pass "sources: a prior 'False positives' bullet is not a local finding" || fail "sources: false positives excluded (fp=$fp)"
# no progress file at all -> GitHub side only, still exit 0
out=$("$RP" sources --head "$HEAD" --reviews "$REVIEWS"); rc=$?
[[ "$rc" -eq 0 && "$(printf '%s' "$out" | jq '.local_findings | length')" -eq 0 && "$(printf '%s' "$out" | jq '.github_comments | length')" -eq 3 ]] \
    && pass "sources: no progress.md -> GitHub comments only, exit 0" || fail "sources: absent timeline (rc=$rc)"
# malformed progress.md -> loud failure, not a silent empty timeline
printf '## Implementation\n```\nopen\n' > "$TMPD/bad.md"
"$RP" sources --progress "$TMPD/bad.md" --head "$HEAD" --reviews "$REVIEWS" >/dev/null 2>&1; rc=$?
[[ "$rc" -ne 0 ]] && pass "sources: malformed progress.md fails loudly (rc=$rc)" || fail "sources: malformed progress.md should fail"
# --progress given a directory -> error, not "empty timeline"
err=$("$RP" sources --progress "$TMPD" --head "$HEAD" --reviews "$REVIEWS" 2>&1 >/dev/null); rc=$?
[[ "$rc" -eq 2 && "$err" == *"not a regular file"* ]] && pass "sources: --progress pointing at a directory is an error (rc 2)" || fail "sources: directory progress (rc=$rc err=$err)"
# malformed reviews JSON -> clean error, rc 2, no traceback
printf '{"reviews": [' > "$TMPD/trunc.json"
err=$("$RP" sources --head "$HEAD" --reviews "$TMPD/trunc.json" 2>&1 >/dev/null); rc=$?
[[ "$rc" -eq 2 && "$err" == error:*"not valid JSON"* && "$err" != *Traceback* ]] && pass "sources: truncated reviews JSON is a clean rc-2 error" || fail "sources: bad reviews json (rc=$rc err=$err)"
# matching rules: every cited file counts; exact path only; checked findings are not open
cat > "$TMPD/rules.md" <<'EOF2'
## Local Review
**Status**: complete
**When**: 2026-09-17 11:00 -04:00
**By**: t (m)

**PR**: #70 at `abc1234`

### Findings
- [ ] (must-fix) two files cited, first is the real one — `scripts/x.sh:3` and `docs/y.md`
- [ ] (must-fix) unrelated file whose path is a suffix of a comment path — `scripts/foo.sh:9`
- [x] (must-fix) already resolved on this head — `.pre-commit-config.yaml:62`
EOF2
cat > "$TMPD/rules.json" <<EOF2
{"head_sha": "$HEAD", "reviews": [{"review_id": 1, "commit_id": "$HEAD", "user_login": "c", "user_type": "Bot", "comments": [
  {"path": "scripts/x.sh", "line": 3, "body": "on the first cited file"},
  {"path": "vendor/scripts/foo.sh", "line": 9, "body": "different file, same tail"},
  {"path": ".pre-commit-config.yaml", "line": 62, "body": "matches only a resolved finding"}
]}], "ci_checks": [], "conversation_comments": []}
EOF2
out=$("$RP" sources --progress "$TMPD/rules.md" --head "$HEAD" --reviews "$TMPD/rules.json")
c_first=$(printf '%s' "$out" | jq '[.candidates[] | select(.file == "scripts/x.sh")] | length')
c_suffix=$(printf '%s' "$out" | jq '[.candidates[] | select(.file == "vendor/scripts/foo.sh")] | length')
c_checked=$(printf '%s' "$out" | jq '[.candidates[] | select(.file == ".pre-commit-config.yaml")] | length')
n_open=$(printf '%s' "$out" | jq '.local_findings | length')
if [[ "$c_first" -eq 1 && "$c_suffix" -eq 0 && "$c_checked" -eq 0 && "$n_open" -eq 2 ]]; then
    pass "sources: first-cited file matches; suffix-only path does not; checked findings are excluded"
else
    fail "sources: matching rules (first=$c_first suffix=$c_suffix checked=$c_checked open=$n_open)"
fi

# ============================================ sources: coverage (#309) =====
# Real git histories. A review recorded at R still covers head H when R is an
# ancestor of H and only this issue's work-plan dir / the roadmap files
# changed (the merge gate's shared rule, _bookkeeping.sh). Git runs in the
# CURRENT directory's repository — the PR worktree — never the workspace
# the script lives in. Fixtures stay under this suite's TMPDIR allocation.
HIST="$TMPD/history"
mkdir -p "$HIST/.agent/work-plans/issue-7" "$HIST/docs" "$HIST/scripts"
git -C "$HIST" init -q -b feature/issue-7
hist_commit() {
    git -C "$HIST" add -A &&
        git -C "$HIST" -c user.name=t -c user.email=t@t commit -q -m "$1"
}
hist_head() { git -C "$HIST" rev-parse HEAD; }
printf 'original\n' > "$HIST/scripts/code.sh"
hist_commit reviewed
REVIEWED=$(hist_head)
HP="$HIST/.agent/work-plans/issue-7/progress.md"
cat > "$HP" <<EOF
---
issue: 7
---

# Issue #7

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 11:00 -04:00
**By**: t (m)
**Verdict**: changes-requested

**Branch**: feature/issue-7 at \`${REVIEWED:0:7}\`

### Findings
- [ ] (must-fix) still open — \`scripts/code.sh:1\`
- [x] (must-fix) already fixed — \`scripts/code.sh:2\`

### False positives
- dismissed — \`scripts/code.sh:3\`
EOF
hist_commit "progress: checkpoint"          # the live #309 shape
BOOK_HEAD=$(hist_head)
HERR="$TMPD/history.err"
hist_sources() {  # <head> [progress] -- run from the target repository
    (cd "$HIST" && "$RP" sources --progress "${2:-$HP}" --head "$1" --reviews "$REVIEWS" 2>"$HERR")
}
n_local() { jq '.local_findings | length' <<<"$1"; }

# (h1) the regression: a bookkeeping-only commit after the review.
out=$(hist_sources "$BOOK_HEAD"); rc=$?
if [[ "$rc" -eq 0 ]] && jq -e --arg sha "${REVIEWED:0:7}" '
    (.local_findings | length) == 1 and
    .local_findings[0].sha == $sha and .local_findings[0].covers_head == true and
    .local_findings[0].coverage == "bookkeeping" and
    (.local_findings[0].text | contains("still open")) and
    (.dropped_entries | length) == 0' <<<"$out" >/dev/null && [[ ! -s "$HERR" ]]; then
    pass "sources (h1): progress-only commit after the review keeps its open finding at its own SHA; checked/false positives stay excluded"
else
    fail "sources (h1): checkpoint coverage (rc=$rc out=$out err=$(<"$HERR"))"
fi
# (h2) exact match, full and short head: coverage "exact", no git needed.
for h in "$REVIEWED" "${REVIEWED:0:7}"; do
    out=$(hist_sources "$h")
    jq -e '(.local_findings | length) == 1 and .local_findings[0].coverage == "exact"' <<<"$out" >/dev/null \
        && pass "sources (h2): head \`${#h}\`-char exact match reports coverage exact" \
        || fail "sources (h2): exact coverage metadata (head=$h out=$out)"
done

# (h3) every allowed document class, cumulatively: the issue's plan (any
# file in its work-plan dir), both legacy roadmap spellings, and the #334
# lowercase docs/roadmap.md.
for doc in .agent/work-plans/issue-7/plan.md .agent/work-plans/issue-7/notes/extra.md \
        ROADMAP.md docs/ROADMAP.md docs/roadmap.md; do
    mkdir -p "$(dirname "$HIST/$doc")"
    printf 'bookkeeping\n' >> "$HIST/$doc"
    hist_commit "$doc"
    out=$(hist_sources "$(hist_head)")
    [[ "$(n_local "$out")" == 1 && "$(jq -r '.local_findings[0].coverage' <<<"$out")" == bookkeeping ]] \
        && pass "sources (h3): retains the finding after a $doc commit" \
        || fail "sources (h3): lost the finding after $doc (out=$out)"
done
DOC_HEAD=$(hist_head)

# (h4) a covered finding pairs only with GitHub comments AT the head.
OLD_REVIEWS="$REVIEWS"
REVIEWS="$TMPD/history-reviews.json"
jq -n --arg head "$DOC_HEAD" --arg old "$REVIEWED" '{reviews: [
    {commit_id: $head, comments: [{path: "scripts/code.sh", line: 1, body: "current"}]},
    {commit_id: $old, comments: [{path: "scripts/code.sh", line: 1, body: "stale"}]}
]}' > "$REVIEWS"
out=$(hist_sources "$DOC_HEAD")
jq -e '(.candidates | length) == 1 and .candidates[0].github == "current"' <<<"$out" >/dev/null \
    && pass "sources (h4): a bookkeeping-covered finding matches the current-head GitHub comment only" \
    || fail "sources (h4): covered cross-source candidate (out=$out)"
REVIEWS="$OLD_REVIEWS"

# (h5) a code change (plus bookkeeping) is a genuinely stale review — and
# (h6) a later checkpoint cannot hide it (endpoint diff, not last commit).
printf 'changed\n' >> "$HIST/scripts/code.sh"
printf 'more\n' >> "$HIST/docs/roadmap.md"
hist_commit "code + roadmap"
out=$(hist_sources "$(hist_head)")
if [[ "$(n_local "$out")" == 0 ]] && jq -e '.dropped_entries | length == 1 and .[0].reason == "stale"
        and .[0].open_findings == 1 and (.[0].why | contains("scripts/code.sh"))' <<<"$out" >/dev/null \
        && [[ ! -s "$HERR" ]]; then
    pass "sources (h5): code change since the review -> dropped as stale, naming the path, no warning"
else
    fail "sources (h5): code change accepted or not reported (out=$out err=$(<"$HERR"))"
fi
printf 'later checkpoint\n' >> "$HP"
hist_commit later-checkpoint
out=$(hist_sources "$(hist_head)")
[[ "$(n_local "$out")" == 0 ]] && jq -e '.dropped_entries[0].reason == "stale"' <<<"$out" >/dev/null \
    && pass "sources (h6): a later checkpoint cannot hide an earlier code change" \
    || fail "sources (h6): code hidden by checkpoint (out=$out)"

# (h7) another issue's work-plan dir is not exempt — including one whose
# number merely starts with this issue's (issue-70 vs issue-7).
for other in issue-8 issue-70; do
    git -C "$HIST" checkout -q -B "other-$other" "$DOC_HEAD"
    mkdir -p "$HIST/.agent/work-plans/$other"
    printf 'other issue\n' > "$HIST/.agent/work-plans/$other/progress.md"
    hist_commit "$other timeline"
    out=$(hist_sources "$(hist_head)")
    [[ "$(n_local "$out")" == 0 ]] && jq -e '.dropped_entries[0].reason == "stale"' <<<"$out" >/dev/null \
        && pass "sources (h7): $other's timeline is not exempt for issue 7" \
        || fail "sources (h7): $other accepted (out=$out)"
done

# (h8) an identical tree is not enough when the review is not an ancestor.
DIVERGED=$(printf 'unrelated root\n' | git -C "$HIST" -c user.name=t -c user.email=t@t commit-tree "${DOC_HEAD}^{tree}")
out=$(hist_sources "$DIVERGED")
[[ "$(n_local "$out")" == 0 ]] && jq -e '.dropped_entries[0].reason == "stale"
        and (.dropped_entries[0].why | contains("not an ancestor"))' <<<"$out" >/dev/null \
    && pass "sources (h8): non-ancestor review with an identical tree is stale" \
    || fail "sources (h8): divergent history accepted (out=$out)"

# (h9-h12) whatever cannot be checked is dropped as "unverifiable" — never
# silently: it is listed with the reason and warned about on stderr — and
# never an error (rc 0; exact matches still work).
unverifiable_ok() {  # <out> <rc> <why-substring>
    [[ "$2" == 0 && "$(n_local "$1")" == 0 ]] \
        && jq -e --arg w "$3" '.dropped_entries | length == 1 and .[0].reason == "unverifiable"
            and (.[0].why | contains($w))' <<<"$1" >/dev/null \
        && grep -q "warning: sources: review at" "$HERR"
}
out=$(hist_sources 0000000000000000000000000000000000000000); rc=$?
unverifiable_ok "$out" "$rc" "does not resolve" \
    && pass "sources (h9): unresolvable head -> unverifiable, warned, rc 0" \
    || fail "sources (h9): unresolved head (rc=$rc out=$out err=$(<"$HERR"))"
mkdir -p "$TMPD/external/.agent/work-plans/issue-7"
sed "s/${REVIEWED:0:7}/0000000/" "$HP" > "$TMPD/external/.agent/work-plans/issue-7/progress.md"
out=$(hist_sources "$DOC_HEAD" "$TMPD/external/.agent/work-plans/issue-7/progress.md"); rc=$?
unverifiable_ok "$out" "$rc" "review \`0000000\` does not resolve" \
    && pass "sources (h10): review SHA missing from the repository -> unverifiable, warned, rc 0" \
    || fail "sources (h10): unresolved review (rc=$rc out=$out err=$(<"$HERR"))"
cp "$HP" "$TMPD/noncanonical.md"
out=$(hist_sources "$DOC_HEAD" "$TMPD/noncanonical.md"); rc=$?
unverifiable_ok "$out" "$rc" "only an exact head-SHA match counts" \
    && pass "sources (h11): a non-canonical --progress path gets exact matching only (unverifiable, warned)" \
    || fail "sources (h11): noncanonical path (rc=$rc out=$out err=$(<"$HERR"))"
# No repository at all: GIT_CEILING_DIRECTORIES stops discovery at TMPD, so
# this holds even when TMPDIR itself sits inside some checkout.
mkdir -p "$TMPD/norepo"
for head in "$REVIEWED" "$DOC_HEAD"; do
    out=$(cd "$TMPD/norepo" && GIT_CEILING_DIRECTORIES="$TMPD" "$RP" sources --progress "$HP" \
        --head "$head" --reviews "$REVIEWS" 2>"$HERR"); rc=$?
    if [[ "$head" == "$REVIEWED" ]]; then
        [[ "$rc" == 0 && "$(n_local "$out")" == 1 ]] \
            && pass "sources (h12): no repository -> exact match still retained" \
            || fail "sources (h12): no-repository exact match (rc=$rc out=$out)"
    else
        unverifiable_ok "$out" "$rc" "not a git repository" \
            && pass "sources (h12): no repository -> non-exact review unverifiable, warned, rc 0" \
            || fail "sources (h12): no-repository fallback (rc=$rc out=$out err=$(<"$HERR"))"
    fi
done

# (h13) the timeline may be stored outside the target repository (a
# workspace timeline for a project worktree): git still runs in the cwd.
cp "$HP" "$TMPD/external/.agent/work-plans/issue-7/progress.md"
out=$(hist_sources "$DOC_HEAD" "$TMPD/external/.agent/work-plans/issue-7/progress.md")
[[ "$(n_local "$out")" == 1 ]] \
    && pass "sources (h13): externally stored timeline is checked against the cwd repository" \
    || fail "sources (h13): wrong repository resolution (out=$out)"

# (h14) the bridge refuses a malformed call (rc 2) rather than guessing.
bash "$SCRIPT_DIR/../_bookkeeping.sh" --review "$HIST" "$REVIEWED" >/dev/null 2>&1; rc=$?
[[ "$rc" == 2 ]] && pass "sources (h14): _bookkeeping.sh bridge usage error is rc 2" \
    || fail "sources (h14): bridge usage (rc=$rc)"
# (h15) a ref name is never resolved as a recorded SHA.
bash "$SCRIPT_DIR/../_bookkeeping.sh" --review "$HIST" HEAD "$DOC_HEAD" 7 >/dev/null 2>&1; rc=$?
[[ "$rc" == 3 ]] && pass "sources (h15): a non-hex review 'SHA' (HEAD) is unverifiable, not resolved" \
    || fail "sources (h15): ref name resolved (rc=$rc)"
# (h16) a code file renamed INTO this issue's work-plan dir is not
# bookkeeping: the rename's source path is a code change (--no-renames).
git -C "$HIST" checkout -q -B rename-into-plan "$DOC_HEAD"
git -C "$HIST" mv scripts/code.sh .agent/work-plans/issue-7/code.sh
hist_commit "move code into the work-plan dir"
out=$(hist_sources "$(hist_head)")
[[ "$(n_local "$out")" == 0 ]] && jq -e '.dropped_entries[0].reason == "stale"
        and (.dropped_entries[0].why | contains("scripts/code.sh"))' <<<"$out" >/dev/null \
    && pass "sources (h16): a code file renamed into the work-plan dir is stale, naming its old path" \
    || fail "sources (h16): rename into the exempt dir accepted (out=$out)"

# (h17-h20) git failing inside the check is "unverifiable" (warned), never
# a verified "stale". Each damaging case runs on its own copy of the history.
copy_hist() { cp -R "$HIST" "$TMPD/$1" && echo "$TMPD/$1"; }
loose_object() { echo "$1/.git/objects/${2:0:2}/${2:2}"; }
src_in() {  # <repo> <head> -- sources run from <repo>
    (cd "$1" && "$RP" sources --progress "$HP" --head "$2" --reviews "$REVIEWS" 2>"$HERR")
}
# (h17) a commit on the ancestry walk is unreadable: git exits 1 but says so
# on stderr, which must not read as "not an ancestor".
C17=$(copy_hist missing-commit)
if rm "$(loose_object "$C17" "$BOOK_HEAD")" 2>/dev/null; then
    out=$(src_in "$C17" "$DOC_HEAD"); rc=$?
    unverifiable_ok "$out" "$rc" "could not check whether" \
        && pass "sources (h17): unreadable commit on the ancestry walk -> unverifiable, warned, rc 0" \
        || fail "sources (h17): missing ancestry object (rc=$rc out=$out err=$(<"$HERR"))"
else
    fail "sources (h17): fixture: $BOOK_HEAD is not a loose object in the copy"
fi
# (h18) the ancestry check passes but the diff cannot read the review's tree.
C18=$(copy_hist missing-tree)
if rm "$(loose_object "$C18" "$(git -C "$C18" rev-parse "${REVIEWED}^{tree}")")" 2>/dev/null; then
    out=$(src_in "$C18" "$DOC_HEAD"); rc=$?
    unverifiable_ok "$out" "$rc" "could not diff" \
        && pass "sources (h18): failed diff -> unverifiable, warned, rc 0" \
        || fail "sources (h18): failed diff (rc=$rc out=$out err=$(<"$HERR"))"
else
    fail "sources (h18): fixture: the review's tree is not a loose object in the copy"
fi
# (h19) a shallow clone that holds both commits but not the history between
# them answers "not an ancestor" for a real ancestor.
git -C "$HIST" branch -f review-tip "$REVIEWED"
git -C "$HIST" branch -f doc-tip "$DOC_HEAD"
git clone -q --depth 1 --no-single-branch "file://$HIST" "$TMPD/shallow" 2>/dev/null
if [[ "$(git -C "$TMPD/shallow" rev-parse --is-shallow-repository 2>/dev/null)" == true ]] \
        && git -C "$TMPD/shallow" cat-file -e "${REVIEWED}^{commit}" 2>/dev/null; then
    out=$(src_in "$TMPD/shallow" "$DOC_HEAD"); rc=$?
    unverifiable_ok "$out" "$rc" "shallow" \
        && pass "sources (h19): non-ancestor in a shallow repository -> unverifiable, warned, rc 0" \
        || fail "sources (h19): shallow history (rc=$rc out=$out err=$(<"$HERR"))"
else
    fail "sources (h19): fixture: shallow clone missing or without the review commit"
fi
# (h20) an ancestry check exiting other than 0/1 is unverifiable (rc 3), not
# stale: a git shim fails only `merge-base`, silently.
mkdir -p "$TMPD/gitshim"
printf '#!/bin/bash\nfor a in "$@"; do [[ "$a" == merge-base ]] && exit 128; done\nexec %q "$@"\n' \
    "$(command -v git)" > "$TMPD/gitshim/git"
chmod +x "$TMPD/gitshim/git"
why=$(PATH="$TMPD/gitshim:$PATH" bash "$SCRIPT_DIR/../_bookkeeping.sh" --review "$HIST" "$REVIEWED" "$DOC_HEAD" 7); rc=$?
[[ "$rc" == 3 && "$why" == *"git exit 128"* ]] \
    && pass "sources (h20): ancestry check exit 128 -> bridge rc 3 (unverifiable), reason names the exit" \
    || fail "sources (h20): ancestry exit 128 (rc=$rc why=$why)"
# (h23) a verified non-ancestor stays stale (rc 1) when git writes stderr
# that is not an error: with GIT_TRACE=1 set by the caller, and with a shim
# that prints a warning before a clean "no". Only error:/fatal: lines count.
why=$(GIT_TRACE=1 bash "$SCRIPT_DIR/../_bookkeeping.sh" --review "$HIST" "$DOC_HEAD" "$REVIEWED" 7 2>/dev/null); rc=$?
[[ "$rc" == 1 && "$why" == *"not an ancestor"* ]] \
    && pass "sources (h23): GIT_TRACE=1 does not turn a verified non-ancestor into unverifiable" \
    || fail "sources (h23): GIT_TRACE=1 non-ancestor (rc=$rc why=$why)"
printf '#!/bin/bash\nfor a in "$@"; do [[ "$a" == merge-base ]] && { echo "warning: some notice" >&2; exit 1; }; done\nexec %q "$@"\n' \
    "$(command -v git)" > "$TMPD/gitshim/git"
why=$(PATH="$TMPD/gitshim:$PATH" bash "$SCRIPT_DIR/../_bookkeeping.sh" --review "$HIST" "$REVIEWED" "$DOC_HEAD" 7); rc=$?
[[ "$rc" == 1 && "$why" == *"not an ancestor"* ]] \
    && pass "sources (h23): a non-error stderr line with exit 1 is a verified non-ancestor (rc 1)" \
    || fail "sources (h23): non-error stderr (rc=$rc why=$why)"

# (h21) supersession (owner decision "Newest current review wins"): a Local
# Review with open findings, then an Integrated Review and its own progress
# commit. Both cover the head; only the newest feeds local_findings and the
# older one is dropped as superseded (its findings are not re-listed).
git -C "$HIST" checkout -q -B superseded "$DOC_HEAD"
cat >> "$HP" <<EOF

## Integrated Review
**Status**: complete
**When**: 2026-09-17 12:00 -04:00
**By**: t (m)

**PR**: #70 at \`${DOC_HEAD:0:7}\`
**Sources**: 1 (Local Review @ \`${REVIEWED:0:7}\`)

### Findings
- [ ] (must-fix) integrated finding — \`scripts/code.sh:9\`
EOF
hist_commit "progress: integrated review"
SUP_HEAD=$(hist_head)
out=$(hist_sources "$SUP_HEAD"); rc=$?
if [[ "$rc" == 0 ]] && jq -e --arg lr "${REVIEWED:0:7}" --arg ir "${DOC_HEAD:0:7}" '
    (.local_findings | length) == 1 and .local_findings[0].entry_type == "Integrated Review"
    and .local_findings[0].sha == $ir and (.local_findings[0].text | contains("integrated finding"))
    and (.dropped_entries | length) == 1 and .dropped_entries[0].reason == "superseded"
    and .dropped_entries[0].sha == $lr and .dropped_entries[0].open_findings == 1
    and (.dropped_entries[0].why | contains("Integrated Review") and contains($ir))' <<<"$out" >/dev/null \
    && [[ ! -s "$HERR" ]]; then
    pass "sources (h21): a newer covering Integrated Review supersedes the Local Review; only its findings listed"
else
    fail "sources (h21): supersession (rc=$rc out=$out err=$(<"$HERR"))"
fi
# (h22) the newest covering review has no open findings: nothing is listed,
# and the older one is still superseded (it was disposed of, not re-opened).
sed -i 's/^- \[ \] (must-fix) integrated finding/- [x] (must-fix) integrated finding/' "$HP"
hist_commit "progress: integrated finding addressed"
out=$(hist_sources "$(hist_head)")
[[ "$(n_local "$out")" == 0 ]] && jq -e '(.dropped_entries | length) == 1
        and .dropped_entries[0].reason == "superseded"' <<<"$out" >/dev/null \
    && pass "sources (h22): newest covering review with no open findings still supersedes the older one" \
    || fail "sources (h22): closed newest review (out=$out)"
rm -f "$HERR"

# ========================================================== persist =====
mk_repo() { mkdir -p "$1"; git -C "$1" init -q -b "$2"; git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init; }
ENTRY=$'## Integrated Review\n**Status**: complete\n**When**: 2026-09-17 12:00 -04:00\n**By**: t (m)\n\n**PR**: #70 at `abc1234`\n**Sources**: 2 (Copilot @ `abc1234`, Local Review @ `abc1234`)\n**Cross-source confirmations**: 1\n**CI**: all-pass\n\n### Findings\n- [ ] (cross-confirmed) unchecked append redirect — `.agent/scripts/progress_append.sh`\n\n### False positives\n- (Copilot) jq missing — bootstrap installs jq'

# strict + mismatched worktree -> abort rc 4, nothing written
MIS="$TMPD/issue-workspace-99"; mk_repo "$MIS" feature/issue-99
out=$(cd "$MIS" && printf '%s\n' "$ENTRY" | WORKTREE_ISSUE=99 "$RP" persist --issue 7 --strict 2>&1); rc=$?
[[ "$rc" -eq 4 && "$out" == *worktree_enter.sh* && ! -e "$MIS/.agent/work-plans/issue-7/progress.md" ]] \
    && pass "persist (Integrated Review) strict: mismatched worktree aborts rc 4 with remediation" || fail "persist strict mismatched (rc=$rc out=$out)"
# compat + mismatched -> notice + inline commit with the entry-type subject
out=$(cd "$MIS" && printf '%s\n' "$ENTRY" | WORKTREE_ISSUE=99 "$RP" persist --issue 7 --title "Seven" 2>&1); rc=$?
if [[ "$rc" -eq 0 && "$out" == *"would have aborted"*"PROGRESS_PERSISTENCE_STRICT=0"* ]] \
    && grep -q '^## Integrated Review$' "$MIS/.agent/work-plans/issue-7/progress.md" \
    && [[ "$(git -C "$MIS" log -1 --format=%s)" == "progress: integrated review for #7" ]]; then
    pass "persist (Integrated Review) compat: notice printed, entry committed inline with 'progress: integrated review for #7'"
else
    fail "persist compat mismatched (rc=$rc out=$out subj=$(git -C "$MIS" log -1 --format=%s))"
fi
# matching worktree, compat -> no notice; strict -> progress_append.sh commit
MATCH="$TMPD/issue-workspace-7"; mk_repo "$MATCH" feature/issue-7
out=$(cd "$MATCH" && printf '%s\n' "$ENTRY" | "$RP" persist --issue 7 --title "Seven" 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" != *notice* ]] && pass "persist compat: matching worktree produces no notice" || fail "persist compat matching (rc=$rc out=$out)"
out=$(cd "$MATCH" && printf '%s\n' "${ENTRY//abc1234/def5678}" | "$RP" persist --issue 7 --strict 2>&1); rc=$?
[[ "$rc" -eq 0 && "$(git -C "$MATCH" log -1 --format='%s|%an')" == "progress: integrated review for #7|Test Agent" ]] \
    && pass "persist strict: matching worktree commits via progress_append.sh with the agent identity" || fail "persist strict matching (rc=$rc out=$out)"
# degradation: no issue derivable -> skip, never abort
SK="$TMPD/skillwt"; mk_repo "$SK" skill/research-20260917-120000
out=$(cd "$SK" && "$RP" persist --issue "" --strict < /dev/null 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "Progress persistence skipped (no linked issue — skill worktree)" ]] \
    && pass "persist degrade: skill worktree skips (even under strict)" || fail "persist degrade skill (rc=$rc out=$out)"
OB="$TMPD/oneoff"; mk_repo "$OB" hotfix/typo
out=$(cd "$OB" && "$RP" persist --issue "" < /dev/null 2>&1); rc=$?
[[ "$rc" -eq 0 && "$out" == "Progress persistence skipped (no linked issue)" ]] \
    && pass "persist degrade: ordinary branch with no issue skips" || fail "persist degrade ordinary (rc=$rc out=$out)"

echo ""
echo "test_triage_reviews_integration: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
