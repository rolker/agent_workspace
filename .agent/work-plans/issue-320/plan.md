# Plan: cross_model_review: run Gemini/Codex at the Standard tier and pass the plan's Approach as context

## Issue

https://github.com/rolker/agent_workspace/issues/320

## Context

`cross_model_review.sh` currently runs only at Deep tier (`review-code`
SKILL.md step 5e, `review_depth_classification.md`). Standard-tier PRs —
the common case — get only the in-process Claude adversarial specialist
(5d), leaving real defects to the caller model's own blind spots and
leaving cross-model quota idle on most reviews. Separately, every
external agent reviews the diff with no knowledge of what the change was
meant to accomplish, so a deliberate deviation from the plan reads as an
unexplained anomaly instead of a flagged divergence.

This plan implements both changes from issue #320, folding in the four
owner-decided requirements from the `## Checkpoint` entry in this issue's
progress.md: an ADR-0015 addendum (ADR-0008 style) for the tier change;
implementation blocked on #313 merging into `main` and `main` merged into
this branch first; the added Standard-tier latency/quota cost stated in
the PR description, with Light staying static-only; one PR unless review
becomes unwieldy.

**Sequencing dependency**: #313 (result validation for the codex/claude/
copilot arms) is open and unimplemented, and edits `cross_model_review.sh`
in the same script (adds validation inside each agent's invocation path).
It does not touch the shared-prompt builder (the `SHARED_PROMPT` heredoc
block, lines ~662-834) or `review-code`'s tier table — the two areas this
plan touches — so the changes are additive on top of whatever #313 lands,
not conflicting. Implementation on this issue does not start until #313's
PR is merged to `main` and this branch has run `git merge origin/main` to
pick it up, per the checkpoint decision.

## Approach

1. **Tier change — `review-code` SKILL.md** — Move 5e's activation line
   from "Deep only" to "Standard, Deep" (matching 5d's phrasing), and add
   `cross_model_review.sh --agents ...` to the Standard tier's specialist
   list (currently 5a-5d only) alongside Deep's list (already includes it).
   Update the depth-tiers summary near the top (currently: Standard =
   "Static Analysis, Governance, Plan Drift + Claude adversarial"; Deep =
   "Standard tier + cross-model adversarial") so Standard's one-liner also
   names cross-model adversarial, and Deep's becomes "Standard tier"
   (identical specialist set — Deep is now distinguished only by the
   Report Format's added Cross-Model Reviews section, since specialists no
   longer differ). Leave Light's line ("static analysis only") unchanged.

2. **Tier change — `review_depth_classification.md`** — In the Standard
   tier's "Specialists dispatched" list, add "Cross-model adversarial (all
   available non-caller agents, via `cross_model_review.sh`)". Update
   Deep's list to note it is the same specialist set as Standard plus the
   Cross-Model Reviews report section (not an additional specialist).
   Leave the tier *criteria* (line/file/trigger thresholds) and Light tier
   untouched — this issue changes which specialists run at a given tier,
   not how the tier is chosen.

3. **Plan-context in `cross_model_review.sh`** — After the diff is
   embedded and before the `PROMPT_FOOTER` output-format heredoc (current
   line ~788-791, right after the diff's closing ` ``` `), add a new
   section to `$SHARED_PROMPT`:
   - Resolve the plan path via `$WORK_PLANS_DIR/plan.md` (the same
     resolver already in scope — `WORK_PLANS_DIR` is set by
     `resolve_work_plans_dir` earlier in the script, line ~599).
   - Skip entirely when the file doesn't exist, or when `$NO_PROGRESS` is
     true (matches `--no-progress`'s existing contract of no per-issue
     artifact dir; `ISSUE_NUMBER` is the `"noprogress"` sentinel in that
     case, so there is no real plan to read anyway).
   - When present, extract the plan's `## Approach` section (from that
     heading to the next `## ` heading or EOF) with `awk`, matching the
     style of `filter_work_plans_diff()` already in the file. Cap it at
     the first 200 lines of that section.
   - Emit it under a heading that frames it as context, not a review
     target, e.g.:
     ```
     ## Plan Context

     The following is the Approach section from the work plan this change
     is meant to implement. It is context, not something to review in its
     own right: flag divergences between the diff above and this plan,
     but do not critique the plan's wording or design choices themselves.

     <first 200 lines of ## Approach>
     ```
   - This happens once, on `$SHARED_PROMPT` (built once, copied per
     agent per the existing comment at the top of that block), so every
     agent's prompt gets it uniformly — no per-agent branching needed
     (unlike the gemini-only Tool Use footer, which stays agent-specific
     and is appended after copying, so ordering is: diff → plan context →
     output-format footer → gemini's Tool Use appendix last).

4. **Tests — `test_cross_model_review.sh`** — Add cases:
   - A plan.md with a `## Approach` section present in the resolved
     work-plans dir → assert the `## Plan Context` section appears in
     every generated per-agent prompt file.
   - No plan.md present → assert no `## Plan Context` section in any
     prompt file (and no error).
   - `--no-progress` set (even if a plan.md happens to exist somewhere
     reachable) → assert no `## Plan Context` section.
   - A plan.md whose `## Approach` section exceeds 200 lines → assert the
     embedded section is truncated to 200 lines, not the full section.
   - Re-run the existing suite unmodified assertions to confirm no
     regression (currently 179 `assert` calls in this file — the "~196"
     figure some earlier context cited does not match the current file
     and should not be treated as a target count).

5. **ADR-0015 addendum** — Per ADR-0008 (cross-reference addendums are
   permitted on accepted ADRs without superseding), add:
   - A Status-line note: e.g. *"Scoped exception in issue #320: cross-model
     dispatch also runs at Standard tier, not Deep only."*
   - A `## Consequences` list item is *not* the right place (that section
     already documents the current call-sites as of ADR-0015's acceptance
     and is not itself an addendum target under ADR-0008); instead append
     to the existing **References** section: add issue #320 alongside the
     existing #313 reference, since #320 is the issue that changes when
     the script documented by ADR-0015 gets invoked.
   - Do not reword ADR-0015's Decision or Consequences sections — the
     dispatch *mechanics* (parallel, per-agent timeout, EXIT= triplets)
     are unchanged; only the *trigger tier* changes, which is exactly the
     class of addendum ADR-0008 permits.

6. **PR description** — State the added cost explicitly: Standard-tier
   PRs now pay the cross-model dispatch latency (~2.5-3.5 min per the
   issue, bounded by `AGENT_TIMEOUT`/`AGY_PRINT_TIMEOUT`) and consume
   Gemini/Codex/Copilot quota that was previously reserved for Deep-tier
   PRs only. Confirm and state that Light tier is unaffected (static
   analysis only, no specialist list change).

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/review-code/SKILL.md` | Tier summary + step 5e activation line: Deep only → Standard, Deep; Standard's specialist list gains cross-model adversarial |
| `.agent/knowledge/review_depth_classification.md` | Standard tier's "Specialists dispatched" list gains cross-model adversarial; Deep tier's list updated to reflect it's the same set plus the report section |
| `.agent/scripts/cross_model_review.sh` | New `## Plan Context` section appended to `$SHARED_PROMPT` after the diff, before the output-format footer; sourced from `$WORK_PLANS_DIR/plan.md`'s `## Approach`, capped at 200 lines, absent when no plan or `--no-progress` |
| `.agent/scripts/tests/test_cross_model_review.sh` | New assertions: plan-context present/absent/truncated/no-progress-absent |
| `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md` | Status-line addendum note + References entry for #320 (ADR-0008 style; no Decision/Consequences rewrite) |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Light tier explicitly stays static-only; the added cost lands only on Standard/Deep, and is stated in the PR description per the checkpoint decision |
| A change includes its consequences | Tier-table changes are made in both places that state it (SKILL.md and the classification doc) in the same PR, plus the ADR addendum and the test |
| Capture decisions, not just implementations | ADR-0015 addendum keeps the ADR accurate about *when* dispatch runs, without reopening its Decision |
| Enforcement over documentation | The tier change is still LLM-interpreted from markdown (pre-existing pattern per the Issue Review; not a new gap) |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0015 (parallel sync is the only review dispatch mode) | Yes | Addendum only (Status line + References); dispatch mechanics unchanged |
| ADR-0008 (permit cross-reference addendums) | Yes | This plan's ADR-0015 change follows ADR-0008's permitted-addendum contract exactly (Status-line note + References entry, no Decision/Consequences rewrite) |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `review-code` tier table (SKILL.md) | `review_depth_classification.md` tier table | Yes — step 2 |
| `cross_model_review.sh` prompt builder | `test_cross_model_review.sh` | Yes — step 4 |
| ADR-0015's documented trigger condition | ADR-0015 addendum | Yes — step 5 |
| Standard-tier review cost | PR description stating the tradeoff | Yes — step 6 |

## Open Questions

- None blocking. The one open item is procedural, not a design choice:
  confirm #313 has merged to `main` and this branch has `git merge
  origin/main` before the first implementation commit, per the checkpoint
  decision — this is a precondition to starting, not a question needing
  an answer during planning.

## Estimated Scope

Single PR, per the checkpoint decision ("one PR unless review gets
unwieldy"). If review of the combined tier-change + plan-context diff
proves unwieldy, split along the same line the Issue Review flagged as
independently shippable: tier change (steps 1-2, 6) vs. plan-context
(steps 3-4), with the ADR addendum (step 5) traveling with the tier-change
PR.
