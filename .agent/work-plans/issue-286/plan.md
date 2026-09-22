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
2. **Gate condition (a) uses the same helper, against `HEAD_REVIEWED`.**
   The gate keeps comparing with `HEAD_REVIEWED` (the head captured before
   Step 1, per the comment at the top of Step 1.5), so this run's own
   roadmap commit is never inside the `R → HEAD_REVIEWED` range and
   `_STEP1_COMMITTED_PATHS` is not part of the gate's allowed set. What
   can be inside that range: review/merge-record commits to the issue's
   `progress.md`, and a roadmap commit left by an earlier failed merge
   run. Allowed paths for the gate are therefore
   `.agent/work-plans/issue-<N>/progress.md`, `ROADMAP.md`, and
   `docs/ROADMAP.md` (the two files `update_roadmap.sh` manages), which is
   the owner's #284 rule applied to the same documents. Resolution: after
   `git fetch origin <branch>` in `_gate_wt`, resolve the entry's 7-char
   SHA with `git rev-parse --verify --quiet <sha>^{commit}`; a miss **or an
   ambiguous prefix** both fail resolution and fall to the stale reason.
   Pass → treat the review as at head and say so ("review at `R` covers
   head `H`: only progress.md changed since"). Fail → the existing
   stale-review reason, now naming why (unresolvable SHA, not an ancestor,
   or the offending path). No worktree → stale as today.
3. **Tests** in `test_merge_pr_gate.sh`, built on a new
   `make_gate_sandbox` that mirrors `make_ci_sandbox`: commit a code
   change in the worktree, take its real SHA `R`, write the review entry
   with `**PR**: #70 at \`R[0:7]\``, commit that (head `H`), push, and
   point the PR fixture's `headRefOid` at `H`. Cases: (g1) that shape →
   gate passes, no Merge entry, output names the covering rule; (g2) same
   plus a code commit before `H` → stale, names the path; (g3) review SHA
   from a branch not in `H`'s history → stale, "not an ancestor"; (g4)
   `--enforce` with the g1 shape merges; (g5) g1 shape plus a leftover
   `docs/ROADMAP.md` commit → passes. Existing "(b) review at a stale SHA"
   fixture keeps its meaning (`0000000` does not resolve).
4. **Docs**: gate header comment in `merge_pr.sh` (condition (a) wording),
   and a short ADR-0008-style addendum on ADR-0013 stating the
   ancestry-equivalence interpretation of the SHA correlation key once
   (now shared by the CI target and the gate). AGENTS.md row unchanged
   (it does not describe (a)).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/merge_pr.sh` | Helper extracted; gate (a) calls it; header comment |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | `make_gate_sandbox` builder; five gate cases |
| `docs/decisions/0013-progress-md-entry-type-vocabulary.md` | Addendum: ancestry-equivalence reading of the SHA key |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Unblocks enforce-by-default with code and tests, not a wider rule |
| Only what's needed | One helper, two call sites; no new flags or env vars |
| Test what breaks | The exact live failure shape (review, then its own commit) is a test |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | Yes | Entry shapes unchanged; correlation still by SHA, with an ancestry-equivalence rule at consumption, recorded once as an addendum (ADR-0008) |
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
