#!/usr/bin/env bash
# .agent/scripts/tests/test_checkpoint_269.sh
# Mechanical enforcement for issue #269's "checkpoint after PR B": no PR may
# touch a gated file (the files issue #269 plans to change in PR C, PR D,
# PR E, PR F, or PR B2) until a `## Checkpoint` entry with all four required
# fields is present in `.agent/work-plans/issue-269/progress.md` on
# origin/main (or the merge-base, when origin/main isn't reachable). See
# .agent/work-plans/issue-269/plan.md, "New vocabulary: `## Checkpoint`..."
# and "Checkpoint enforcement" sections, and
# docs/decisions/0013-progress-md-entry-type-vocabulary.md's `## Checkpoint`
# row.
#
# This script has two roles, both exercised every time it runs (both must
# pass for the script to exit 0):
#
#   1. REAL GATE: checks *this* repo's actual current branch against
#      origin/main. This is the enforcement — it is what makes this file
#      block a real PR from merging once run_script_tests.sh wires it into
#      the validate-script-tests pre-commit hook.
#   2. HERMETIC SELF-TESTS: the gate-checking logic itself (`checkpoint_gate`
#      / `checkpoint_entry_complete` below) is exercised against synthetic,
#      throwaway git repos (mktemp -d) — never the real repo — so these
#      cases don't depend on this branch's actual state and can't be broken
#      by future commits to this branch or to main.
#
# Defense in depth against this file (or the runner's explicit mention of
# it) being edited/deleted to route around the gate: this script also
# asserts its own filename appears in run_script_tests.sh's explicit
# presence-assertion (REQUIRED_SUITE). See "Protecting the checkpoint test
# from edit/deletion" in the plan.
#
# Run: bash .agent/scripts/tests/test_checkpoint_269.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run_script_tests.sh"
SELF_NAME="$(basename "${BASH_SOURCE[0]}")"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# The files this workspace's issue #269 plan names as gated by the checkpoint
# after PR B: everything PR C, PR D, PR E, and PR F land (per "Files to
# Change" in .agent/work-plans/issue-269/plan.md), plus the two files PR B2
# touches that are not already covered by PR B's own (ungated) change —
# review-code/SKILL.md is intentionally excluded: PR B lands it before the
# checkpoint exists, so it is not part of the gated set.
GATED_FILES=(
    ".claude/skills/triage-reviews/SKILL.md"
    ".agent/scripts/tests/test_triage_reviews_integration.sh"
    ".claude/skills/address-findings/SKILL.md"
    ".agent/scripts/tests/test_address_findings.sh"
    ".claude/skills/plan-task/SKILL.md"
    ".claude/skills/review-plan/SKILL.md"
    ".agent/scripts/tests/test_plan_correlation.sh"
    ".agent/scripts/merge_pr.sh"
    ".agent/scripts/tests/test_merge_pr_gate.sh"
    ".github/PULL_REQUEST_TEMPLATE.md"
    "Makefile"
)

# checkpoint_entry_complete <content>
# True (rc 0) iff $content contains a "## Checkpoint" entry with all four
# required fields (PR A / ADR-0013's Checkpoint row): **PR**,
# **Review entry SHA**, **Resolver-hit**, **Decision summary URL**. Reads
# fields, not just heading presence — a Checkpoint heading with one field
# missing still fails.
checkpoint_entry_complete() {
    local content="$1" entry
    entry=$(printf '%s\n' "$content" | awk '
        /^## Checkpoint[[:space:]]*$/ { flag=1; next }
        /^## / { flag=0 }
        flag { print }
    ')
    [[ -n "$entry" ]] || return 1
    grep -q '^\*\*PR\*\*:' <<<"$entry" || return 1
    grep -q '^\*\*Review entry SHA\*\*:' <<<"$entry" || return 1
    grep -q '^\*\*Resolver-hit\*\*:' <<<"$entry" || return 1
    grep -q '^\*\*Decision summary URL\*\*:' <<<"$entry" || return 1
    return 0
}

# checkpoint_gate <repo-dir> <base-ref> <head-ref>
# True (rc 0) iff no GATED_FILES entry differs between base-ref and
# head-ref, OR base-ref's .agent/work-plans/issue-269/progress.md has a
# complete "## Checkpoint" entry. False (rc 1) otherwise.
checkpoint_gate() {
    local repo="$1" base_ref="$2" head_ref="$3" changed content
    changed=$(git -C "$repo" diff --name-only "$base_ref" "$head_ref" -- "${GATED_FILES[@]}" 2>/dev/null)
    if [[ -z "$changed" ]]; then
        return 0
    fi
    content=$(git -C "$repo" show "${base_ref}:.agent/work-plans/issue-269/progress.md" 2>/dev/null)
    checkpoint_entry_complete "$content"
}

COMPLETE_ENTRY=$'## Checkpoint\n**Status**: complete\n**When**: 2026-09-20 10:00 -04:00\n**By**: Owner (human)\n\n**PR**: #300\n**Review entry SHA**: `abc1234`\n**Resolver-hit**: resolved correctly against #265 PR 2\n**Decision summary URL**: https://github.com/rolker/agent_workspace/pull/300#issuecomment-1\n'

_sandbox_repo() {
    local dir
    dir=$(mktemp -d)
    git -C "$dir" init -q -b main
    git -C "$dir" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
    printf '%s' "$dir"
}

_write_progress() {
    local repo="$1" body="$2"
    mkdir -p "$repo/.agent/work-plans/issue-269"
    printf '%s' "$body" > "$repo/.agent/work-plans/issue-269/progress.md"
    git -C "$repo" add -A
    git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q -m "progress.md"
}

# --- Hermetic self-tests: one case per gated file (plan requirement: "a
#     synthetic PR diff touching each gated file... fails against a fixture
#     progress.md with no ## Checkpoint entry, and passes against a fixture
#     with a complete one; a fixture ... missing one required field still
#     fails"). ---
for gf in "${GATED_FILES[@]}"; do
    REPO=$(_sandbox_repo)
    _write_progress "$REPO" ""   # no Checkpoint entry at all on "main"
    mkdir -p "$REPO/$(dirname "$gf")"
    printf 'base content\n' > "$REPO/$gf"
    git -C "$REPO" add -A
    git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q -m "add $gf"
    BASE_SHA=$(git -C "$REPO" rev-parse HEAD)
    git -C "$REPO" checkout -q -b feature
    printf 'changed content\n' >> "$REPO/$gf"
    git -C "$REPO" add -A
    git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q -m "touch $gf"

    if ! checkpoint_gate "$REPO" "$BASE_SHA" HEAD; then
        pass "gate refuses '$gf' change with no Checkpoint entry on base"
    else
        fail "gate refuses '$gf' change with no Checkpoint entry on base"
    fi

    # Now retro-fit base with a complete Checkpoint entry (simulating the
    # entry having landed on main) and confirm the same diff now passes.
    git -C "$REPO" checkout -q main
    _write_progress "$REPO" "$COMPLETE_ENTRY"
    COMPLETE_BASE_SHA=$(git -C "$REPO" rev-parse HEAD)
    if checkpoint_gate "$REPO" "$COMPLETE_BASE_SHA" feature; then
        pass "gate passes '$gf' change once a complete Checkpoint entry exists on base"
    else
        fail "gate passes '$gf' change once a complete Checkpoint entry exists on base"
    fi

    # An entry missing one required field (Resolver-hit) still fails — the
    # gate reads fields, not just heading presence.
    INCOMPLETE_ENTRY=$'## Checkpoint\n**Status**: complete\n**When**: 2026-09-20 10:00 -04:00\n**By**: Owner (human)\n\n**PR**: #300\n**Review entry SHA**: `abc1234`\n**Decision summary URL**: https://github.com/rolker/agent_workspace/pull/300#issuecomment-1\n'
    _write_progress "$REPO" "$INCOMPLETE_ENTRY"
    INCOMPLETE_BASE_SHA=$(git -C "$REPO" rev-parse HEAD)
    if ! checkpoint_gate "$REPO" "$INCOMPLETE_BASE_SHA" feature; then
        pass "gate refuses '$gf' change against a Checkpoint entry missing one required field"
    else
        fail "gate refuses '$gf' change against a Checkpoint entry missing one required field"
    fi

    rm -rf "$REPO"
done

# --- A file NOT on the gated list is unaffected by an absent Checkpoint
#     entry (the gate is scoped, not a blanket refusal of every PR). ---
REPO=$(_sandbox_repo)
_write_progress "$REPO" ""
printf 'base\n' > "$REPO/untouched-by-gate.md"
git -C "$REPO" add -A
git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q -m base
BASE_SHA=$(git -C "$REPO" rev-parse HEAD)
git -C "$REPO" checkout -q -b feature
printf 'edited\n' >> "$REPO/untouched-by-gate.md"
git -C "$REPO" add -A
git -C "$REPO" -c user.name=t -c user.email=t@example.com commit -q -m edit
if checkpoint_gate "$REPO" "$BASE_SHA" feature; then
    pass "gate does not refuse a PR that touches no gated file, even with no Checkpoint entry"
else
    fail "gate does not refuse a PR that touches no gated file, even with no Checkpoint entry"
fi
rm -rf "$REPO"

# --- Self-check: this file's own name must appear in run_script_tests.sh's
#     explicit presence-assertion, so a PR that edits the runner to drop that
#     check (leaving only the glob) fails this self-check. ---
if [[ -f "$RUNNER" ]] && grep -q "$SELF_NAME" "$RUNNER"; then
    pass "own filename ('$SELF_NAME') appears in run_script_tests.sh's presence assertion"
else
    fail "own filename ('$SELF_NAME') appears in run_script_tests.sh's presence assertion"
fi

# --- Real gate: this repo's actual current branch vs. origin/main (falling
#     back to the merge-base with main, then to main itself, if origin/main
#     isn't a resolvable ref — e.g. a shallow or remote-less clone). This is
#     the enforcement that actually blocks a PR: if it fails here, a gated
#     file changed on this branch and no complete Checkpoint entry exists on
#     the base. No network access is required — only local refs already
#     fetched are read. ---
REAL_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REAL_ROOT" ]]; then
    fail "real gate: could not resolve this repo's toplevel"
else
    BASE_REF=""
    if git -C "$REAL_ROOT" rev-parse --verify -q origin/main >/dev/null; then
        BASE_REF="origin/main"
    elif git -C "$REAL_ROOT" rev-parse --verify -q main >/dev/null; then
        BASE_REF="main"
    fi
    if [[ -z "$BASE_REF" ]]; then
        echo "note: real gate skipped — neither origin/main nor main is a resolvable ref in this checkout" >&2
        pass "real gate: skipped (no origin/main or main ref available — not a failure of the gate itself)"
    else
        MERGE_BASE="$(git -C "$REAL_ROOT" merge-base HEAD "$BASE_REF" 2>/dev/null)"
        if [[ -z "$MERGE_BASE" ]]; then
            fail "real gate: could not compute merge-base of HEAD and $BASE_REF"
        elif checkpoint_gate "$REAL_ROOT" "$MERGE_BASE" HEAD; then
            pass "real gate: this branch vs. $BASE_REF (merge-base $MERGE_BASE) — no gated file blocked"
        else
            fail "real gate: this branch touches a checkpoint-gated file (${GATED_FILES[*]}) without a complete ## Checkpoint entry on $BASE_REF's .agent/work-plans/issue-269/progress.md"
        fi
    fi
fi

echo ""
echo "test_checkpoint_269: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
