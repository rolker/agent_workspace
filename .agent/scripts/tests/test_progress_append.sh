#!/usr/bin/env bash
# .agent/scripts/tests/test_progress_append.sh
# Tests the prompt-free progress.md appender (.agent/scripts/progress_append.sh).
# Ported from ros2_agent_workspace's test_progress_append.sh (issue #269 PR A).
#
# The script's whole contract is scope discipline: derived target path, fixed
# commit message, only-that-file commits, fail-loud identity. These cases pin
# each of those properties plus the failure modes, plus this workspace's
# extended writable-type whitelist (Checkpoint, Merge (report-only), Merge
# (unreviewed)).
#
# Run: bash .agent/scripts/tests/test_progress_append.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PA="$SCRIPT_DIR/../progress_append.sh"
TEST_PASS=0
TEST_FAIL=0

pass() { echo "PASS: $1"; TEST_PASS=$((TEST_PASS + 1)); }
fail() { echo "FAIL: $1"; TEST_FAIL=$((TEST_FAIL + 1)); }

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
REPO="$TMPD/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q -b main
export AGENT_NAME="Test Agent"
export AGENT_EMAIL="test+agent@example.com"
PROG=".agent/work-plans/issue-7/progress.md"

# 1. creates file with frontmatter + title heading, appends entry, commits with
#    the fixed message and the agent identity
out=$(printf '## Local Review (Pre-Push)\n**Status**: complete\n' \
      | "$PA" -C "$REPO" 7 --title "Fix the thing" 2>&1); rc=$?
if [ "$rc" -eq 0 ] \
    && grep -q '^issue: 7$' "$REPO/$PROG" \
    && grep -q '^# Issue #7 — Fix the thing$' "$REPO/$PROG" \
    && grep -q '^## Local Review (Pre-Push)$' "$REPO/$PROG" \
    && [ "$(git -C "$REPO" log -1 --format=%s)" = "progress: local review (pre-push) for #7" ] \
    && [ "$(git -C "$REPO" log -1 --format='%an <%ae>')" = "Test Agent <test+agent@example.com>" ]; then
    pass "creates file (frontmatter+title), appends, commits with fixed message + agent identity"
else
    fail "creates file (frontmatter+title), appends, commits (rc=$rc, out=$out)"
fi

# 2. second append: both entries present, file not truncated, new commit
printf '## Implementation\n**Status**: complete\n' | "$PA" -C "$REPO" 7 > /dev/null 2>&1
if grep -q '^## Local Review (Pre-Push)$' "$REPO/$PROG" \
    && grep -q '^## Implementation$' "$REPO/$PROG" \
    && [ "$(git -C "$REPO" log -1 --format=%s)" = "progress: implementation for #7" ]; then
    pass "appends rather than truncates; per-entry commit"
else
    fail "appends rather than truncates; per-entry commit"
fi

# 3. scope: a dirty index is untouched — unrelated staged file stays staged
#    and out of the progress commit
echo "unrelated" > "$REPO/unrelated.txt"
git -C "$REPO" add unrelated.txt
printf '## Issue Review\nbody\n' | "$PA" -C "$REPO" 7 > /dev/null 2>&1
committed=$(git -C "$REPO" show --name-only --format= HEAD)
if [ "$committed" = "$PROG" ] \
    && git -C "$REPO" diff --cached --name-only | grep -q '^unrelated.txt$'; then
    pass "commits only the progress file; unrelated staged file untouched"
else
    fail "commits only the progress file (committed: $committed)"
fi
git -C "$REPO" reset -q unrelated.txt && rm -f "$REPO/unrelated.txt"

# 4. non-numeric issue number -> exit 2, no commit
head_before=$(git -C "$REPO" rev-parse HEAD)
printf '## Implementation\n' | "$PA" -C "$REPO" seven > /dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && [ "$(git -C "$REPO" rev-parse HEAD)" = "$head_before" ] \
    && pass "non-numeric issue exits 2" || fail "non-numeric issue exits 2 (rc=$rc)"

# 5. empty stdin -> exit 2, file untouched
"$PA" -C "$REPO" 7 < /dev/null > /dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && pass "empty stdin exits 2" || fail "empty stdin exits 2 (rc=$rc)"

# 6. entry without '## ' heading -> exit 2
printf 'not a heading\n' | "$PA" -C "$REPO" 7 > /dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && pass "missing '##' heading exits 2" || fail "missing '##' heading exits 2 (rc=$rc)"

# 7. identity unset (env cleared, no args) -> exit 2, fail loud, no fallback commit
out=$(printf '## Implementation\n' | env -u AGENT_NAME -u AGENT_EMAIL "$PA" -C "$REPO" 7 2>&1)
rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qi 'identity'; then
    pass "unset identity fails loud (exit 2)"
else
    fail "unset identity fails loud (rc=$rc, out=$out)"
fi

# 8. --name/--email args substitute for env identity
out=$(printf '## Plan Review\nx\n' \
      | env -u AGENT_NAME -u AGENT_EMAIL "$PA" -C "$REPO" 7 --name "Arg Agent" --email "arg@example.com" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$REPO" log -1 --format=%an)" = "Arg Agent" ]; then
    pass "--name/--email args substitute for env identity"
else
    fail "--name/--email args substitute for env identity (rc=$rc, out=$out)"
fi

# 9. new file without --title gets the bare heading
printf '## Issue Review\nx\n' | "$PA" -C "$REPO" 8 > /dev/null 2>&1
if grep -q '^# Issue #8$' "$REPO/.agent/work-plans/issue-8/progress.md"; then
    pass "no --title -> bare '# Issue #N' heading"
else
    fail "no --title -> bare '# Issue #N' heading"
fi

# 10. outside a git repo -> exit 2
NOREPO="$TMPD/norepo"
mkdir -p "$NOREPO"
printf '## Implementation\n' | "$PA" -C "$NOREPO" 7 > /dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && pass "non-repo dir exits 2" || fail "non-repo dir exits 2 (rc=$rc)"

# 10b. non-canonical entry type (well-formed '## ' heading, not an ADR-0013
#      writable type) -> exit 2 listing the allowed types, no commit
head_before=$(git -C "$REPO" rev-parse HEAD)
out=$(printf '## Bogus Type\nbody\n' | "$PA" -C "$REPO" 7 2>&1); rc=$?
if [ "$rc" -eq 2 ] \
    && printf '%s' "$out" | grep -qi 'not a writable' \
    && printf '%s' "$out" | grep -q 'Implementation' \
    && [ "$(git -C "$REPO" rev-parse HEAD)" = "$head_before" ]; then
    pass "non-canonical entry type exits 2 with allowed list, no commit"
else
    fail "non-canonical entry type exits 2 (rc=$rc, out=$out)"
fi

# 11. CRLF / padded heading: trailing \r and spaces must not leak into the
#     commit subject (entry type is trimmed).
printf '## Plan Authored  \r\nbody\n' | "$PA" -C "$REPO" 9 > /dev/null 2>&1
subj=$(git -C "$REPO" log -1 --format=%s)
if [ "$subj" = "progress: plan authored for #9" ]; then
    pass "trailing CR/space in heading trimmed from commit subject"
else
    fail "trailing CR/space in heading trimmed (subj='$subj')"
fi

# 12. idempotency: if the entry is already the file tail, a re-run must not
#     double-append AND must exit 0 — the already-committed success path is not
#     a git failure (exit 3). The rc assertion pins that exit semantics; without
#     it the entry-count check alone passes even on the spurious exit-3.
PROG9="$REPO/.agent/work-plans/issue-9/progress.md"
before=$(grep -c '^## Implementation$' "$PROG9")
printf '## Implementation\nsame body\n' | "$PA" -C "$REPO" 9 > /dev/null 2>&1   # first append+commit
out=$(printf '## Implementation\nsame body\n' | "$PA" -C "$REPO" 9 2>/dev/null)  # identical re-run (stdout only)
rc=$?
after=$(grep -c '^## Implementation$' "$PROG9")
# The re-run's stdout must be the distinct no-op message, not the misleading
# "appended + committed ..." — the entry was neither appended nor committed.
if [ "$before" -eq 0 ] && [ "$after" -eq 1 ] && [ "$rc" -eq 0 ] \
    && printf '%s' "$out" | grep -qi 'no-op' \
    && ! printf '%s' "$out" | grep -qi 'appended + committed'; then
    pass "identical entry as file tail is not re-appended, re-run exits 0 + no-op stdout (idempotent replay)"
else
    fail "idempotent replay (before=$before after=$after rc=$rc out=$out)"
fi

# 13. this workspace's new writable types (Checkpoint, Merge (report-only),
#     Merge (unreviewed)) — added for issue #269 PR A/F, not present in the
#     fork's whitelist — are accepted and committed.
for t in "Checkpoint" "Merge (report-only)" "Merge (unreviewed)"; do
    head_before=$(git -C "$REPO" rev-parse HEAD)
    out=$(printf '## %s\n**Status**: complete\n' "$t" | "$PA" -C "$REPO" 7 2>&1); rc=$?
    head_after=$(git -C "$REPO" rev-parse HEAD)
    if [ "$rc" -eq 0 ] && [ "$head_after" != "$head_before" ] \
        && grep -qF "## $t" "$REPO/$PROG"; then
        pass "new writable type '$t' accepted and committed"
    else
        fail "new writable type '$t' accepted and committed (rc=$rc, out=$out)"
    fi
done

# 14. -C targets a worktree outside the conventional <ws>/worktrees/... tree
#     (a plain mktemp -d git repo, already exercised by $REPO above) — confirms
#     nothing in the script assumes a workspace-relative layout. $REPO is
#     already such a path (under $TMPD, not under any worktrees/ tree); this
#     case makes that assumption explicit rather than incidental.
case "$REPO" in
    */worktrees/*) fail "-C path resolution is layout-agnostic (test setup assumption violated: \$REPO is under worktrees/)" ;;
    *)
        out=$(printf '## Issue Review\nx\n' | "$PA" -C "$REPO" 42 --title "Layout check" 2>&1); rc=$?
        if [ "$rc" -eq 0 ] && grep -q '^# Issue #42' "$REPO/.agent/work-plans/issue-42/progress.md"; then
            pass "-C path resolution is layout-agnostic (non-worktrees/ sandbox repo)"
        else
            fail "-C path resolution is layout-agnostic (rc=$rc, out=$out)"
        fi
        ;;
esac

# 15. non-canonical entry type error also excludes "External Review" from the
#     allowed list (read-only predecessor, never freshly writable).
out=$(printf '## External Review\nbody\n' | "$PA" -C "$REPO" 7 2>&1); rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qi 'not a writable' \
    && ! printf '%s' "$out" | grep -q '"External Review"'; then
    pass "'External Review' is rejected as a fresh write (read-only predecessor)"
else
    fail "'External Review' is rejected as a fresh write (rc=$rc, out=$out)"
fi

# 16. one entry per call: a body with a second top-level '## ' heading (e.g. a
#     forged '## Checkpoint' smuggled inside an '## Implementation' body) is
#     rejected outright — nothing appended, nothing committed. The whitelist
#     only checks the first heading, so this is what keeps it meaningful.
head_before=$(git -C "$REPO" rev-parse HEAD)
before=$(grep -c '^## Checkpoint$' "$REPO/$PROG")
out=$(printf '## Implementation\n**Status**: complete\n\n## Checkpoint\n**PR**: #1\n**Review entry SHA**: x\n**Resolver-hit**: y\n**Decision summary URL**: z\n' \
      | "$PA" -C "$REPO" 7 2>&1); rc=$?
after=$(grep -c '^## Checkpoint$' "$REPO/$PROG")
if [ "$rc" -eq 2 ] && [ "$before" -eq "$after" ] \
    && [ "$(git -C "$REPO" rev-parse HEAD)" = "$head_before" ] \
    && printf '%s' "$out" | grep -qi 'more than one'; then
    pass "second top-level heading in the body is rejected (no smuggled entries)"
else
    fail "second top-level heading in the body is rejected (rc=$rc before=$before after=$after out=$out)"
fi

# 16b. ...but a heading quoted inside a fenced code block is body text, not a
#      second entry, and is accepted.
out=$(printf '## Implementation\nquoting:\n```\n## Checkpoint\n```\ndone\n' | "$PA" -C "$REPO" 7 2>&1); rc=$?
if [ "$rc" -eq 0 ] && grep -q '^done$' "$REPO/$PROG"; then
    pass "a '## ' line inside a code fence is accepted as body text"
else
    fail "a '## ' line inside a code fence is accepted (rc=$rc, out=$out)"
fi

# 16c. an unterminated fence in the entry is refused at write time: every
#      reader's fence state spans the file, so it would hide all later entries.
head_before=$(git -C "$REPO" rev-parse HEAD)
out=$(printf '## Implementation\n```\nforgot to close\n' | "$PA" -C "$REPO" 7 2>&1); rc=$?
if [ "$rc" -eq 2 ] && [ "$(git -C "$REPO" rev-parse HEAD)" = "$head_before" ] \
    && printf '%s' "$out" | grep -qi 'unterminated code fence'; then
    pass "an entry with an unterminated code fence is rejected (would hide later entries)"
else
    fail "an entry with an unterminated code fence is rejected (rc=$rc, out=$out)"
fi

# 17. --title with an embedded newline would forge lines in the new file's
#     header (the title is written verbatim); it must be rejected, no file.
out=$(printf '## Issue Review\nx\n' | "$PA" -C "$REPO" 55 --title $'Real\n\n## Checkpoint\n**PR**: forged' 2>&1); rc=$?
if [ "$rc" -eq 2 ] && [ ! -e "$REPO/.agent/work-plans/issue-55/progress.md" ] \
    && printf '%s' "$out" | grep -qi 'single line'; then
    pass "--title with a newline is rejected before any file is written"
else
    fail "--title with a newline is rejected (rc=$rc, out=$out)"
fi

# 18. append failure is not reported as success: an unwritable progress.md
#     must exit 3 with no commit, not fall through to the exit-0 no-op path.
if [ "$(id -u)" -eq 0 ]; then
    pass "unwritable progress.md exits 3 (skipped: running as root, chmod is not enforced)"
else
    head_before=$(git -C "$REPO" rev-parse HEAD)
    chmod a-w "$REPO/$PROG"
    out=$(printf '## Implementation\nnew body\n' | "$PA" -C "$REPO" 7 2>&1); rc=$?
    chmod u+w "$REPO/$PROG"
    if [ "$rc" -eq 3 ] && [ "$(git -C "$REPO" rev-parse HEAD)" = "$head_before" ] \
        && printf '%s' "$out" | grep -qi 'could not append' \
        && ! printf '%s' "$out" | grep -qi 'already committed'; then
        pass "unwritable progress.md exits 3 with no commit (not a false no-op success)"
    else
        fail "unwritable progress.md exits 3 (rc=$rc, out=$out)"
    fi
fi

echo ""
echo "test_progress_append: $TEST_PASS passed, $TEST_FAIL failed"
[ "$TEST_FAIL" -eq 0 ]
