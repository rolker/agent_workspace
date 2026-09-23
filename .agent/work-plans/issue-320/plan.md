# Plan: cross_model_review: run Gemini/Codex at the Standard tier and pass the plan's Approach as context

## Issue

https://github.com/rolker/agent_workspace/issues/320

## Context

`cross_model_review.sh` currently runs only at Deep tier. Standard-tier
PRs — the common case — get no cross-model specialist, and no agent ever
sees the plan the diff is meant to implement. Per the owner's checkpoint
decision: ADR-0015 addendum (ADR-0008 style), implement only after #313
merges to `main` and `git merge origin/main` runs on this branch first
(#313 touches `run_agent_sync`/`run_agent_job`, not the shared-prompt
builder or the skill's tier table, so this plan's changes are additive,
not conflicting), state the added Standard-tier cost in the PR
description (Light stays static-only), one PR unless review gets
unwieldy.

## Approach

1. **Tier tables** (`review-code` SKILL.md + `review_depth_classification.md`)
   — In both files, change step 5e's / Standard's activation from "Deep
   only" to "Standard, Deep": add cross-model adversarial to Standard's
   specialist list **and** its Report-format row gains the Cross-Model
   Reviews section (currently Deep-only in both files) — dispatching at
   Standard without also landing the report section would drop the
   findings on the floor. State plainly what still distinguishes Deep
   from Standard after this change: nothing but the classification
   thresholds that select the tier in the first place. Tier *criteria*
   and Light are untouched.

2. **`cross_model_review.sh` plan context** — After the diff, before the
   `PROMPT_FOOTER` heredoc: if `$WORK_PLANS_DIR/plan.md` exists,
   `$NO_PROGRESS` is false, and it has a non-empty `## Approach` section,
   extract it (to next `## ` heading or EOF, `awk`, same style as
   `filter_work_plans_diff()`), cap at 200 lines, append under a `## Plan
   Context` heading stating it is context ("the plan this change is meant
   to implement; flag divergences between the diff and it; do not review
   the plan itself"). Omit entirely when plan.md is absent, has no `##
   Approach`, or that section is empty — never fall back to the whole
   plan or an empty heading. Over 200 lines: truncate and append a
   visible marker inside the section, e.g. `_[truncated: N more lines]_`.
   `test_branch_mode_filter_survives_noprefix` (line 1237) already writes
   a `plan.md` with no `## Approach` at this exact path — nothing is
   injected there under this spec, so its existing "BRANCH BOOKKEEPING
   absent from prompt" assertion keeps passing unchanged. Built once,
   shared by all agent copies; gemini's Tool Use footer (still appended
   per-copy, after) rewords "files under `.agent/work-plans/` ... are
   deliberately excluded" to "excluded **from the diff**".

3. **Tests** — Named functions, each writing its fixture `plan.md` into
   the resolved `WORK_PLANS_DIR` (not the mock repo's working tree) and
   added to the `# ---- Run all tests ----` list: `test_plan_context_
   present`, `_absent_no_plan`, `_absent_no_approach_section`,
   `_truncated`, `_no_progress` (`--no-progress` + `--work-plans-dir`,
   the one combination where a plan.md could exist under
   `--no-progress`). Full suite green. (As implemented on top of #313 the
   suite runs 379 assertions at the time of writing; the pre-#313 count of
   179 quoted at planning time no longer applies, and the figure moves with
   every #313 merge, so treat it as a snapshot rather than a contract.)

4. **ADR-0015 addendum (ADR-0008 style)** — Plain navigational Status-line
   note, not "scoped exception" wording: "Trigger tier for cross-model
   dispatch is recorded in issue #320 (Standard + Deep); dispatch
   mechanics unchanged." Append #320 to References (alongside #313). No
   Decision/Consequences edits — ADR-0015 never qualified the trigger by
   tier, so nothing there needs reopening.

5. **PR description** — State the cost: Standard-tier PRs now pay
   cross-model dispatch latency (~2.5-3.5 min, bounded by
   `AGENT_TIMEOUT`/`AGY_PRINT_TIMEOUT`) and consume Gemini/Codex/Copilot
   quota previously reserved for Deep only; Light is unaffected.

6. **AGENTS.md script-reference row** (owner-approved) — Its closing
   clause, "the embedded diff excludes `.agent/work-plans/**`", stays
   true of the diff but now tells only half the story; add a clause
   noting the plan's `## Approach` is separately admitted as labelled
   context, capped at 200 lines.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/review-code/SKILL.md` | Tier summary + 5e activation + Standard's report body: step 1 |
| `.agent/knowledge/review_depth_classification.md` | Standard's specialist list + Report-format row: step 1 |
| `.agent/scripts/cross_model_review.sh` | `## Plan Context` section + reworded Tool Use footer: step 2 |
| `.agent/scripts/tests/test_cross_model_review.sh` | Five new tests: step 3 |
| `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md` | Addendum: step 4 |
| `AGENTS.md` | Script-reference row update (owner-approved): step 6 |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Light stays static-only; added cost is Standard/Deep only, stated in the PR |
| A change includes its consequences | Tier tables (both files, dispatch + report), ADR addendum, tests, AGENTS.md row all land in the same PR |
| Capture decisions, not just implementations | ADR-0015 addendum (navigational, ADR-0008-compliant) keeps the ADR accurate on *when* dispatch runs, no Decision/Consequences rewrite |

## Open Questions

- None blocking. Precondition: superseded by the owner decision recorded
  under Implementation Notes — `feature/issue-313` was merged into this
  branch directly instead of waiting for it to reach `main`.

## Implementation Notes

- **Branch-on-#313 (owner decision, 2026-09-22)** — The plan's "wait for
  #313 to merge to `main`, then `git merge origin/main`" gate was replaced:
  `feature/issue-313` (the `_cli_review.sh` helper and its rewired
  `run_agent_sync` arms) was merged into `feature/issue-320` at `6ed80f6`,
  and #320 is implemented on top of it. #313 is still being fixed and will
  be merged again; this branch therefore leaves `_cli_review.sh`,
  `_agy_review.sh`, and `run_agent_sync` / the availability precheck in
  `cross_model_review.sh` untouched. #320's edits to that script are
  confined to the shared-prompt builder and the gemini Tool Use footer, and
  its tests are added alongside #313's rather than reworking its mocks.

- **Fence balancing in the plan-context block (round-1 review fix)** — The
  plan specified the 200-line cap but not what a cut does to markdown. Two
  things can leave a code fence open inside the emitted block: the cap
  itself landing mid-fence, and the (deliberately not fence-aware)
  extractor stopping at a heading-shaped or `---` line inside a fence. An
  unclosed fence swallows everything after it — including the `## Output
  Format` footer — into one code block, so the reviewer never sees its
  instructions. Rule adopted: after the body is cut, count fence toggles
  (a closing fence must match the marker that opened it, so ``` inside a
  `~~~` block is content) and emit the matching closer before the
  truncation marker. The extractor also now stops at any H1/H2 heading or
  a thematic break, so its one-sided guarantee — possibly shorter, never
  longer, never content from a later section — actually holds.

- **No `printf | head` (round-1 review fix)** — The cap is applied with
  here-strings. Under `set -o pipefail`, `printf | head -n 200` makes
  printf take SIGPIPE once the Approach exceeds the pipe buffer (~64 KiB)
  and the whole script dies with exit 141 before any agent is dispatched.

## Addendum: fix-round re-review depth (owner, 2026-09-23)

Scope added at the publish checkpoint ("yes, update 320 with same
codex/gemini rules"), after PR #327's ~60-line fix round was re-reviewed
without Gemini/Codex at the reviewer's discretion. Rule (owner's choice at
the round-3 checkpoint, "Same as whole PR"): a fix-round re-review (PR mode
after `address-findings`; pre-push round ≥ 2) is classified exactly as a
first review, on the whole PR/branch diff with the same tier table.
Standard/Deep dispatches the cross-model specialist as usual; the reviewer
may raise the tier, never lower it; the `**Depth**` line records the tier
and its reason. Prose-only: no script computes tiers.

A first version classified only the fix round's own delta (changes since
the last reviewed SHA). Round-3 review dropped it: a small fix to a large
PR would fall to Light — static analysis only, no governance, Claude
adversarial or cross-model pass checking that the earlier findings were
resolved — so it could lower a re-review below the whole-PR tier. It also
needed a "last reviewed SHA" rule, merge and conflict-resolution handling,
and pathspec/rename/binary edge cases that the whole-diff rule avoids.

| File | Change |
|------|--------|
| `.agent/knowledge/review_depth_classification.md` | New *Fix-Round Re-Reviews* section |
| `.claude/skills/review-code/SKILL.md` | Step 2 fix-round rule; user override applies to fix rounds |
| `.claude/skills/address-findings/SKILL.md` | Next-step note: the re-review keeps the whole diff's tier |
| `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md` | Status-line pointer extended |

## Estimated Scope

Single PR (checkpoint decision). If review proves unwieldy, split along
the Issue Review's suggested line: tier change (steps 1, 5, 6) vs.
plan-context (steps 2-3), with the ADR addendum (step 4) traveling with
the tier-change half.
