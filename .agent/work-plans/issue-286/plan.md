# Plan: merge_pr.sh gate: a review entry's own progress commit makes every review look stale

## Issue

https://github.com/rolker/agent_workspace/issues/286

## Context

Gate condition (a) compares the latest review entry's SHA (first 7 chars)
with the PR head. Recording the review commits `progress.md` on the branch,
so the head is always one commit past the SHA the entry names. Every live
run (#273, #282, #285) reported "stale review". #284 already added the
rule that resolves this for the CI target: a later head is equivalent when
the reviewed SHA is an ancestor and the diff touches only paths the script
writes itself. Owner rule (#284): any document file updated at merge time
is exempt.

## Approach

1. **Extract one helper** `_only_bookkeeping_between <wt> <from> <to>
   <allowed-path>...` from Step 2's CI-target block: returns 0 when `from`
   resolves locally, is an ancestor of `to`, and every path in
   `git diff --name-only from to` is in the allowed set; on failure prints
   the reason (not resolvable / not an ancestor / offending path) on
   stdout for the caller to quote. Step 2 calls it with `HEAD_REVIEWED`,
   `HEAD_NOW`, and the paths this run committed (behaviour unchanged, same
   messages).
2. **Gate condition (a) uses the same helper.** When the review SHA is not
   the head, resolve the entry's short SHA in `_gate_wt`
   (`git rev-parse --verify <sha>^{commit}`, after a `git fetch origin
   <branch>` so the head is local), then call the helper with allowed
   paths = the issue's `progress.md` plus `_STEP1_COMMITTED_PATHS` (the
   roadmap commit Step 1 made moments earlier). Pass → treat the review as
   at head and say so ("review at `R` covers head `H`: only progress.md
   changed since"). Fail → the existing stale-review reason, now naming
   why (offending path, or not an ancestor). No worktree → stale as today
   (no local diff to verify).
3. **Tests** in `test_merge_pr_gate.sh`: (g1) approved review at `R`,
   then a progress.md-only commit on top → gate passes, no Merge entry;
   (g2) approved review at `R`, then a code commit → stale, names the
   path; (g3) approved review at `R` on an unrelated history (not an
   ancestor) → stale; (g4) `--enforce` with (g1) merges. Existing
   "(b) review at a stale SHA" fixture keeps its meaning (its SHA
   `0000000` does not resolve).
4. **Docs**: gate header comment in `merge_pr.sh` (condition (a) wording);
   the `## Merge` gate description in the #269 follow-up is on the issue,
   not in docs. AGENTS.md row unchanged (it does not describe (a)).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Helper extracted; gate (a) calls it; header comment |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Four gate cases |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Unblocks enforce-by-default with code and tests, not a wider rule |
| Only what's needed | One helper, two call sites; no new flags or env vars |
| Test what breaks | The exact live failure shape (review, then its own commit) is a test |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | Yes | Entry shapes unchanged; correlation still by SHA, with an ancestry-equivalence rule at consumption, documented in the gate comment |
| ADR-0004 | Yes | Layer 1 only |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Gate condition (a) semantics | merge_pr.sh header comment | Yes |
| Step 2 exemption code moves into a helper | Existing 48 gate tests must still pass unchanged | Yes |

## Open Questions

None. The owner's #284 rule covers which paths are exempt.

## Estimated Scope

Single PR, under 200 lines.
