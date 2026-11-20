#!/usr/bin/env bash
# .agent/scripts/tests/test_fetch_pr_reviews.sh
# Tests for fetch_pr_reviews.sh's `notice_only` mark (issue 428, item 5).
# The hosted reviewer answers a pull request it cannot review (no quota, an
# error) with a review in form only: its own account, state COMMENTED, no
# inline comments, a short body with the phrase "unable to review this pull
# request". Such a review holds no findings and is marked; every other
# review is read as before:
#   - positives: the three notice wordings (two quota texts and the error
#     text), under both spellings of the reviewer's login
#   - negatives: a long real review by the reviewer (overview marker), a
#     short real review by the reviewer with a finding in its body and no
#     inline comments, a short human review, a reviewer review with inline
#     comments (phrase and all), the phrase from another author, and the
#     phrase in a review that is not COMMENTED
# The gh stub answers from fixtures (no network). Review texts are made up
# in the observed shapes.
# Run: bash .agent/scripts/tests/test_fetch_pr_reviews.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
# One sandbox for the whole run, created at top level so the trap fires
# (issue #297).
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# A workspace sandbox ($sb is the root the script derives) with the real
# script and its registry helper, and a gh stub answering from $sb/fix.
sb="$SANDBOX/ws"
mkdir -p "$sb/.agent/scripts" "$sb/stubbin" "$sb/fix"
for f in fetch_pr_reviews.sh _project_registry.sh; do
    cp "$REAL_ROOT/.agent/scripts/$f" "$sb/.agent/scripts/"
done
cat > "$sb/stubbin/gh" <<'EOF'
#!/usr/bin/env bash
: "${GH_FIX:?}"
case "$*" in
    "repo view --json nameWithOwner --jq .nameWithOwner") echo "acme/widget" ;;
    "pr view 5 --json headRefOid --jq .headRefOid") echo "0123456789abcdef0123456789abcdef01234567" ;;
    "api --paginate repos/acme/widget/pulls/5/reviews") cat "$GH_FIX/reviews.json" ;;
    "api --paginate repos/acme/widget/pulls/5/comments") cat "$GH_FIX/comments.json" ;;
    "api --paginate repos/acme/widget/issues/5/comments") echo '[]' ;;
    "api --paginate repos/acme/widget/commits/"*"/check-runs") echo '{"check_runs":[]}' ;;
    *) echo "gh stub: unexpected call: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$sb/stubbin/gh"

BOT="copilot-pull-request-reviewer[bot]"
BOT_PLAIN="copilot-pull-request-reviewer"
review() {  # <id> <login> <user type> <state> <body>
    jq -n --argjson id "$1" --arg login "$2" --arg type "$3" --arg state "$4" --arg body "$5" \
        '{id: $id, submitted_at: "2026-11-09T12:00:00Z", state: $state, body: $body,
          commit_id: "0123456789abcdef0123456789abcdef01234567", user: {login: $login, type: $type}}'
}
OVERVIEW_BODY="<!-- ccr-overview-v2 -->
## Pull request overview

This pull request changes the widget loader and its tests.
$(printf 'A line of the overview that makes this a long review. %.0s' $(seq 1 60))"

{
    review 101 "$BOT" Bot COMMENTED "Copilot was unable to review this pull request because the user who requested the review has insufficient remaining quota."
    review 102 "$BOT_PLAIN" Bot COMMENTED "Copilot was unable to review this pull request because the user who requested the review has run out of remaining quota."
    review 103 "$BOT" Bot COMMENTED "Copilot encountered an error and was unable to review this pull request. Try again later."
    review 201 "$BOT" Bot COMMENTED "$OVERVIEW_BODY"
    review 202 "$BOT" Bot COMMENTED "Human assessment is needed because an unpublished finding concerns the error path in loader.sh: a failed read is treated as empty."
    review 203 alice User COMMENTED "Looks fine to me."
    review 204 "$BOT" Bot COMMENTED "Copilot was unable to review this pull request in full; see the comments below."
    review 205 bob User COMMENTED "Copilot was unable to review this pull request because the user who requested the review has insufficient remaining quota."
    review 206 "$BOT" Bot APPROVED "Copilot was unable to review this pull request because the user who requested the review has insufficient remaining quota."
} | jq -s '.' > "$sb/fix/reviews.json"
# Review 204 has an inline comment: a review with findings is never a notice.
jq -n '[{pull_request_review_id: 204, path: "loader.sh", line: 3, side: "RIGHT", body: "This read can fail.", diff_hunk: "@@", user: {login: "copilot-pull-request-reviewer[bot]", type: "Bot"}}]' \
    > "$sb/fix/comments.json"

echo "TEST: notice_only marks only the hosted reviewer's could-not-review notice"
rc=0
out="$(cd "$sb" && PATH="$sb/stubbin:$PATH" GH_FIX="$sb/fix" "$sb/.agent/scripts/fetch_pr_reviews.sh" --pr 5 2>/dev/null)" || rc=$?
if [ "$rc" -ne 0 ] || ! jq -e . >/dev/null 2>&1 <<<"$out"; then
    fail "the script ran and printed JSON (rc=$rc out=${out:0:300})"
else
    pass "the script ran and printed JSON"
    flag() { jq -r --argjson id "$1" '.reviews[] | select(.review_id == $id) | .notice_only' <<<"$out"; }
    expect() {  # <id> <true|false> <label>
        local got; got="$(flag "$1")"
        if [ "$got" = "$2" ]; then pass "$3 (notice_only=$2)"; else fail "$3 (want notice_only=$2, got '$got')"; fi
    }
    expect 101 true  "quota notice, first wording, [bot] login"
    expect 102 true  "quota notice, second wording, plain login"
    expect 103 true  "error notice wording"
    expect 201 false "long real review by the reviewer (overview marker)"
    expect 202 false "short real review by the reviewer with a finding in its body, no inline comments"
    expect 203 false "short human review"
    expect 204 false "reviewer review with the phrase and an inline comment"
    expect 205 false "the phrase from another author"
    expect 206 false "the phrase in a review that is not COMMENTED"
    n_reviews="$(jq '.reviews | length' <<<"$out")"
    n_flagged="$(jq '[.reviews[] | select(.notice_only == true)] | length' <<<"$out")"
    if [ "$n_reviews" = 9 ] && [ "$n_flagged" = 3 ]; then
        pass "every review is still listed (9), three of them marked"
    else
        fail "review count or mark count (reviews=$n_reviews marked=$n_flagged)"
    fi
fi

echo ""
echo "test_fetch_pr_reviews: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
