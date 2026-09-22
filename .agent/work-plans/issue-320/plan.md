# Plan: cross_model_review: run Gemini/Codex at the Standard tier and pass the plan's Approach as context

## Issue

https://github.com/rolker/agent_workspace/issues/320

## Context

`cross_model_review.sh` currently runs only at Deep tier. Standard-tier
PRs — the common case — get no cross-model specialist, and no agent ever
sees the plan the diff is meant to implement. Per the owner's checkpoint
decision: ADR-0015 addendum (ADR-0008 style), implement only after #313
merges to `main` and `git merge origin/main` runs on this branch first,
state the added Standard-tier cost in the PR description (Light stays
static-only), one PR unless review gets unwieldy.

**Sequencing**: #313 adds per-agent result validation inside
`run_agent_sync`/`run_agent_job`; it doesn't touch the shared-prompt
builder or the skill's tier table, so this plan's changes are additive on
top of whatever #313 lands, not conflicting.

## Approach

1. **Tier tables** (`review-code` SKILL.md + `review_depth_classification.md`)
   — In both files, change step 5e's / Standard's activation from "Deep
   only" to "Standard, Deep": add cross-model adversarial to Standard's
   specialist list, and update the depth-tiers summaries so Standard's
   one-liner names it and Deep's reads "Standard tier" (same specialist
   set now — Deep differs only in the report's Cross-Model Reviews
   section). Tier *criteria* (thresholds) and Light are untouched.

2. **`cross_model_review.sh` plan context** — After the diff is embedded
   in `$SHARED_PROMPT`, before the `PROMPT_FOOTER` heredoc: if
   `$WORK_PLANS_DIR/plan.md` exists and `$NO_PROGRESS` is false, extract
   its `## Approach` section (to the next `## ` heading or EOF, `awk`,
   same style as `filter_work_plans_diff()`), cap at 200 lines, and
   append under a `## Plan Context` heading stating it is context ("the
   plan this change is meant to implement; flag divergences between the
   diff and it; do not review the plan itself"). Built once into
   `$SHARED_PROMPT` before per-agent copies; gemini's Tool Use footer
   still appends per-copy, after. Absent when no plan.md, or under
   `--no-progress`.

3. **Tests** — Add: plan present → `## Plan Context` in every prompt
   file; no plan.md → absent; `--no-progress` → absent even if a plan
   exists; `## Approach` over 200 lines → truncated to 200. Run full
   suite green (179 existing assertions, unaffected).

4. **ADR-0015 addendum (ADR-0008 style)** — Status-line note: "Scoped
   exception in issue #320: cross-model dispatch also runs at Standard
   tier, not Deep only." Append #320 to the References list (alongside
   #313). No edits to Decision/Consequences — dispatch mechanics are
   unchanged, only the trigger tier.

5. **PR description** — State the added cost: Standard-tier PRs now pay
   cross-model dispatch latency (~2.5-3.5 min, bounded by
   `AGENT_TIMEOUT`/`AGY_PRINT_TIMEOUT`) and consume Gemini/Codex/Copilot
   quota previously reserved for Deep only. State Light is unaffected.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/review-code/SKILL.md` | Tier summary + 5e: Deep only → Standard, Deep |
| `.agent/knowledge/review_depth_classification.md` | Standard's specialist list gains cross-model adversarial |
| `.agent/scripts/cross_model_review.sh` | New `## Plan Context` section in `$SHARED_PROMPT`, capped at 200 lines, conditional on plan.md + not `--no-progress` |
| `.agent/scripts/tests/test_cross_model_review.sh` | New present/absent/truncated/no-progress assertions |
| `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md` | Status-line addendum + References entry for #320 |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Light stays static-only; added cost is Standard/Deep only, stated in the PR |
| A change includes its consequences | Both tier-table locations, the ADR addendum, and the test land in the same PR |
| Capture decisions, not just implementations | ADR-0015 addendum keeps the ADR accurate on *when* dispatch runs |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0015 (parallel sync is the only dispatch mode) | Yes | Addendum only; mechanics unchanged |
| 0008 (permit cross-reference addendums) | Yes | Status-line note + References entry, no Decision/Consequences rewrite |

## Open Questions

- None blocking. Procedural precondition only: confirm #313 has merged to
  `main` and this branch has run `git merge origin/main` before the first
  implementation commit.

## Estimated Scope

Single PR (checkpoint decision). If review proves unwieldy, split along
the Issue Review's suggested line: tier change (steps 1, 5) vs.
plan-context (steps 2-3), with the ADR addendum (step 4) traveling with
the tier-change half.
