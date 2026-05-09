---
issue: 186
---

# Issue #186 — Replace gh pr checks --watch busy-poll with native Monitor in merge flows

## Plan
**Status**: complete
**When**: 2026-05-09 14:55
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-186/plan.md`.

The issue's title implies "swap busy-poll for `Monitor`", but `Monitor` is
a Claude Code SDK tool that bash can't invoke — so the script-side
(`merge_pr.sh`) and agent-side (knowledge doc / future slash command)
surfaces need different mechanisms. Plan recommends doing both:
script-side `gh pr checks --watch` insertion to fix the manual-second-
invocation pain for everyone, plus a knowledge doc for the agent-side
`Monitor` pattern. Three Open Questions surfaced for approval before
implement.

## Plan Review
**Status**: complete
**When**: 2026-05-09 15:25
**By**: Claude Code Agent (claude-opus-4-7) + Roland

Walked the three architectural decisions one at a time with concrete
previews. Outcomes (see plan.md `## Decisions` for detail):

1. Surface scope: **both** — script-side bash wait in `merge_pr.sh`
   plus new `agent_wait_patterns.md` knowledge doc.
2. Wait behaviour: **`--fail-fast`** — exit on first failed check, abort
   merge with clear context.
3. Smoke test: **documented manual verification** — ~5 LOC procedure
   in script header; automation declined as out-of-scope for #186.

Plan refined: Open Questions section replaced with Decisions; flag
surface table added showing the new `--no-wait` flag.

## Implement
**Status**: complete (pending self-test)
**When**: 2026-05-09 15:50
**By**: Claude Code Agent (claude-opus-4-7)

Three commits across three logical pieces:

- `8efa4bd` — new `.agent/knowledge/agent_wait_patterns.md` (Surface 2)
- `2129e5e` — `merge_pr.sh` wait + `--no-wait` flag + header (Surface 1)
- `5712812` — `AGENTS.md` script-reference row update (cascade)

### Decisions

Local choices made during implement that weren't pre-decided in plan
review. Skim and redirect anything that's wrong before self-test.

1. **Step renumbering, not "Step 1.5".** Inline `# --- Step N: ---`
   comments shifted (Merge: 2→3, Remove worktree: 3→4, Delete
   branches: 4→5, Sync: 5→6) so the new wait can be Step 2 rather
   than 1.5. Consistent integer numbering reads better than 1.5; the
   churn is comment-only.

2. **USAGE string extracted to a single variable.** Was duplicated in
   the unknown-arg branch and the missing-`--pr` branch. Same
   refactor pattern as cross_model_review.sh in #3 — drift between
   the two strings was a latent bug surface.

3. **Wait error message structure.** Three pieces of information per
   failure: `gh exit <code>` (so debug knows the failure class), PR
   URL (so the user can click through to the failed run without
   re-deriving), and the `--no-wait` escape hatch (so a known-broken
   CI doesn't block the merge if the user explicitly accepts it).

4. **Local-var naming with leading underscore** (`_wait_rc`,
   `_pr_url`) — matches existing convention in this script
   (`_WT_REPO`, `_WT_ROOT`, `_WT_BRANCH`). Not strictly necessary in
   bash but visually scopes "this is a local helper, not a global".

5. **No cross-link from `merge_pr.sh` to the knowledge doc.**
   Considered adding a `# See: .agent/knowledge/agent_wait_patterns.md`
   comment in the script header; declined. The doc is
   self-discoverable in the knowledge dir; bidirectional linking adds
   a sync dependency without much payoff. The doc itself does
   reference back to `merge_pr.sh` (consumer-side reference).

6. **Knowledge doc includes a `cross_model_review.sh` row marked
   "OK as-is".** That script's tmux session-status busy-poll is
   explicitly out-of-scope for #186 (matches plan AC). Documenting
   why prevents future readers from refactoring it on auto-pilot.

7. **Knowledge doc notes the #187 (Routines) connection in "See
   also".** If Routines lands, some of these wait patterns get
   replaced by event-driven Routines fired by GitHub events. Surfaces
   the relationship without committing to either path now.

### What's next

Self-test (per plan): run the new wait path against a real merge.
Since this PR (#189) will merge eventually, the smoke test could be
"the next `make merge-pr` invocation in this session demonstrates the
wait fires correctly". Otherwise the documented manual-verification
procedure in `merge_pr.sh`'s header is the standing reference.
