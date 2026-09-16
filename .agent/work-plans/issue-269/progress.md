---
issue: 269
---

# Issue #269 — Port the review loop from ros2_agent_workspace: progress entry vocabulary, convergence verdict, integrated triage, address-findings, merge gate

## Plan
**Status**: complete
**When**: 2026-09-16 00:00
**By**: Claude Code Agent (claude-sonnet-5)

Plan file: `.agent/work-plans/issue-269/plan.md`.

Six independently mergeable PRs (A: ADR + progress_append.sh + progress_read.py;
B: review-code convergence + decision summary; C: triage-reviews →
Integrated Review; D: address-findings; E: plan-task/review-plan headings;
F: merge gate + PR template), per the owner's 2026-09-16 decision comment
adjustments. Merge-gate Layer 2 (CI/branch-protection) is called out as
Ask-First and left as an open question rather than assumed either way.

## Plan Review
**Status**: complete
**When**: 2026-09-16 (offset not captured by this session; UTC-agnostic timestamp)
**By**: independent reviewer (claude-sonnet-5), fresh context
**Verdict**: needs-work
**Plan**: `.agent/work-plans/issue-269/plan.md` at `15173b7`

### Findings

- [x] (must-fix) PR F's design premise ("this check only adds a precondition before that [existing] banner") cites "the human 'type MERGE to confirm' banner this repo's `merge_pr.sh` already has" (plan.md:234-235, repeated at 258-260 with a dangling "see grep evidence in Files to Change" — the Files to Change table has no such evidence). A full grep of `.agent/scripts/merge_pr.sh` (766 lines) for `confirm`/`read -p`/`WARNING`/`type MERGE` finds no interactive confirmation banner; the real human gate is a human choosing to invoke `make merge-pr PR=<N>`. PR F needs to either build the confirmation step as new work or re-describe the actual (weaker) existing gate accurately. — .agent/work-plans/issue-269/plan.md:234
- [x] (must-fix) The "#265 dependency and progress.md path resolution" section (plan.md:274-302) claims "every skill this plan touches resolves progress.md/plan.md the same way today." In this worktree, `plan-task`/`review-plan` call the strict, fail-loud `resolve_work_plans_dir()` helper (`.agent/scripts/_resolve_work_plans_dir.sh`, from #265 PR1), while `review-code`/`triage-reviews` instead duplicate ad hoc prose ("owning repo's worktree, else current worktree, else create") that never calls the shared resolver and fails silently rather than aborting. Both happen to be git-toplevel-based (neither hardcodes `<ws>/worktrees/...`), so the plan's bottom-line conclusion (no hard block on #265 PRs 2-4) likely survives, but the "resolves the same way" claim is false, and the plan doesn't decide whether to unify onto the shared resolver while PR B/C already touch these two skills. — .agent/work-plans/issue-269/plan.md:281-285
- [x] (must-fix) PR F's Layer-1 gate ("Lands", plan.md:222-235) only checks `progress.md` entries (type, correlation SHA, verdict). Issue #269's original item 7 spec described refusing "unless ... no `## Local Review` entry ... **or no decision summary comment**." The plan silently drops the decision-summary-comment half of that OR condition — unlike every other dropped fork behavior in this plan (Ollama, Copilot-CLI, container dispatcher, #492 disambiguation), which gets an explicit "Dropped" note with rationale. Either add the check or document the drop. — .agent/work-plans/issue-269/plan.md:222
- [x] (suggestion) Owner's decision comment instructed "merge adjacent seams where a PR would otherwise be trivial," but the plan's Estimated Scope (plan.md:400-411) restates the reviewer's original A-F split without showing that test applied. PR C (triage-reviews rename, small) and PR D (address-findings, depends on C's output) are the most plausible merge candidates; the plan should show why they stay split, or merge them. — .agent/work-plans/issue-269/plan.md:400
- [x] (suggestion) plan.md:406-408 states PR D depends on PR B for `## Local Review (Pre-Push)` entries, but PR B's own "Lands" section (plan.md:88-90) and Evidence note this workspace's `review-code` **already** writes `## Local Review (Pre-Push)` with conformant headings today, before PR B lands (PR B only swaps the commit mechanism and adds convergence math). D's hard dependency on B may be overstated — re-verify whether D can land after A+C alone. — .agent/work-plans/issue-269/plan.md:406
- [x] (suggestion) `--force-unreviewed` (plan.md:230-231) bypasses with a "loud warning banner" but the plan doesn't specify a durable record of the bypass (e.g., a `progress.md` marker) beyond terminal stdout at merge time — thin for a rule whose own ADR-0004 lineage is "human control and transparency." — .agent/work-plans/issue-269/plan.md:230
- [x] (suggestion) The decision-summary shape (behaviour change / findings / open human calls / what was verified) is repeated as prose in both PR B and PR F but never pinned to a concrete markdown template (exact headings/fields) — add one worked example so every PR produces the literal same shape. — .agent/work-plans/issue-269/plan.md:95-98,243-247

### Verified claims (spot-checked against fork source at /home/roland/project11, read-only)

- (a) Fork `merge_pr.sh` has no review/progress gate — confirmed: grep for "Local Review"/"progress"/"force-unreviewed"/"decision summary" returns nothing.
- (b) `progress_read.py` exists at `~/project11/.agent/scripts/progress_read.py`; parses ADR-0013 entries into JSON with `type`/`base_type`/`recognized`/`predecessor_of`/`status`/`when`/`when_has_offset`/`by`/`correlation`/`findings`, supports `--type` filtering with predecessor recognition — matches the plan's description.
- (c) Confirmed by reading both SKILL.md files in this worktree: `review-code/SKILL.md` already writes `## Local Review` / `## Local Review (Pre-Push)`; `triage-reviews/SKILL.md` still writes `## External Review` (line 216) and its own inline `git add`/`git commit` (line 228, not yet on `progress_append.sh`).
- (d) Fork citation spot-check, 4 of the plan's "evaluate while porting" citations: #537 (convergence assessment) confirmed in `review-code/SKILL.md` (3 hits); #594 (`progress_append.sh` prompt-free appender) confirmed in the script's own header comment; #492 (`run-issue` orchestrator `## Implementation` disambiguation, correctly dropped as inapplicable) confirmed in `address-findings/SKILL.md`; #481 phase C (address-findings origin) confirmed in fork ADR-0013 and ADR-0015. No wrong or fabricated fork citations found among these four; the plan is appropriately calibrated where it labels claims UNVERIFIED (convergence/#537 and progress_append/#594 outcome claims, both correctly flagged as "cited but not independently re-verified").

### Summary

Scope, issue-alignment, consequences coverage, and principle/ADR self-checks are strong — the plan visibly incorporates all six of the owner's binding adjustments, correctly identifies and honestly flags the ADR-0004 two-layer gap, and its fork-citation discipline (UNVERIFIED labeling, explicit Dropped sections) is good practice this review's spot-checks bore out. But PR F rests part of its design on a "type MERGE to confirm" banner in this repo's `merge_pr.sh` that does not exist (verified by full-file grep), silently narrows the merge-gate spec by dropping the decision-summary-comment check without saying so, and the #265 path-resolution section overclaims uniformity where two different mechanisms actually coexist in this codebase today. None of these look fatal to the six-PR structure, but PR F's "Lands" section needs a rewrite before implementation starts on it, and the path-resolution and decision-summary-comment gaps should be resolved (or explicitly deferred with rationale) before PR F specifically proceeds. PRs A-E are not blocked by these findings.

### Recommended Actions

- [x] Rewrite PR F's "Lands" section to either implement an actual pre-merge confirmation step or accurately describe today's real human gate (invoking `make merge-pr` is itself the gate; no in-script banner exists) — plan.md:234, 259-260
- [x] Correct the "#265 dependency and progress.md path resolution" section's uniformity claim and decide (in-scope or explicitly deferred) whether review-code/triage-reviews should be refactored onto the shared `resolve_work_plans_dir()` helper as part of PR B/C — plan.md:274-302
- [x] Add the decision-summary-comment check to PR F's Layer-1 gate, or add an explicit "Dropped" note with rationale matching the plan's own convention elsewhere — plan.md:222-235
- [x] Re-verify PR D's dependency on PR B given `## Local Review (Pre-Push)` already exists pre-port — plan.md:406-408
- [x] Specify a durable record for `--force-unreviewed` bypass events — plan.md:230-231

## Plan Authored
**Status**: complete
**When**: 2026-09-16 (offset not captured by this session; UTC-agnostic timestamp)
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-269/plan.md` at `2f4e4728ac8ce01fdf982fac9c5b0f031a186560`

Revision 2 — plan-review findings applied. One line per finding →
resolution:

1. **Must-fix 1** (false "type MERGE to confirm" banner claim) →
   removed; full-file grep of `merge_pr.sh` confirms no interactive
   confirmation exists; PR F's Layer 1 check now cited as new work
   inserted between the existing CI-wait step and the existing merge
   call, not a precondition on a pre-existing banner.
2. **Must-fix 2** ("every skill resolves progress.md the same way") →
   replaced with verified reality: only `plan-task` calls the shared
   fail-loud `resolve_work_plans_dir()`; `review-code`/`triage-reviews`
   duplicate ad hoc, silently-falling-back prose; `review-plan` has no
   documented append step at all today. PR B/C now unify `review-code`/
   `triage-reviews` onto the shared resolver with a silent-fallback-gone
   test; PR E is corrected to give `review-plan` its first automated
   append step rather than claiming a rename of one that doesn't exist.
   The #265-PRs-2-4 no-hard-block conclusion still holds and is
   re-verified against the unification decision.
3. **Must-fix 3** (dropped decision-summary-comment check) → restored;
   PR F's Layer 1 now checks both the review-entry condition and a PR
   comment containing the `## Decision summary` marker (via `gh pr view
   --json comments`), refusing if either is absent.
4. **Suggestions** → PR C/D merge evaluated and declined (each carries
   its own non-trivial mechanical scope); PR D's dependency on PR B
   downgraded from hard to soft (`## Local Review (Pre-Push)` already
   exists pre-PR-B) with a defensive-read note; `--force-unreviewed` now
   appends a `## Merge (unreviewed)` progress.md entry (new vocabulary
   type, not in the fork) as its durable audit record; the
   decision-summary shape is pinned to one concrete template in PR B,
   referenced (not re-described) by PR F.

PR sequence unchanged in count and ordering, adjusted in dependency/scope
detail: A (ADR + `progress_append.sh` + `progress_read.py`, foundation) →
B (`review-code`: `progress_append.sh` swap + resolver unification +
convergence + decision-summary template) → C (`triage-reviews`:
`## Integrated Review` + resolver unification) → D (`address-findings`
new skill; depends on A + C, soft-depends on B) → E (`plan-task` heading
rename + `review-plan` heading rename and new automated append step) → F
(merge gate: two-condition Layer 1 gate + unreviewed-bypass audit record
+ Layer 2 left Ask-First + PR template decision-summary section).
