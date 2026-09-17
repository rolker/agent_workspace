---
issue: 276
---

# Issue #276 — Port run-issue from ros2_agent_workspace: in-process orchestrator over the #269 review loop, no container baggage

## Plan Authored
**Status**: complete
**When**: 2026-09-17 14:14 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `0d10096`

Three-PR port of run-issue as an in-process host: a tested dispatcher with a mechanical decision table, the skill plus docs, then a live exercise. Everything that existed only for containers is declined.

## Plan Review
**Status**: complete
**When**: 2026-09-17 14:18 -04:00
**By**: Claude Code Agent (claude-sonnet-5), fresh-context evaluator
**Verdict**: needs-work
**Plan**: `.agent/work-plans/issue-276/plan.md` at `0d10096`

### Findings
- [x] (must-fix) review-issue writes no `## Issue Review` entry; the table's first rows could never fire → revision 2 adds a persistence step to review-issue (PR 1)
- [x] (must-fix) model table asserted Opus as matching the owner's Sonnet-for-subagents rule → revision 2: Sonnet default, tier is Open Question 1
- [x] (suggestion) fork's implement phase: digest says dispatched, plan says inline → verified inline against the scratchpad clone; digest stale
- [x] (suggestion) split the gate change out of PR 1 → PR 0
- [x] (suggestion) state partial/failed handling, concurrency, resume, Claude-Code-only scoping → revision 2

## Plan Authored
**Status**: complete
**When**: 2026-09-17 14:20 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `73eac30`

Revision 2, addressing all five plan-review findings; four PRs (0-3); four open questions for the owner, one of them the model tier.

## Plan Authored
**Status**: complete
**When**: 2026-09-17 14:27 -04:00
**By**: Claude Code Agent (claude-fable-5-1), with owner decisions
**Plan**: `.agent/work-plans/issue-276/plan.md` at `4e60515`

Revision 3: owner (2026-09-17) chose the fork's Opus tier for review phases; three-round surface is a constant; worktree entry is the skill's own job. Implementation may start with PR 0 once the owner approves the plan.

## Plan Review
**Status**: complete
**When**: 2026-09-17 14:42 -04:00
**By**: Claude Code Agent (claude-opus-5), fresh-context evaluator, round 2
**Verdict**: needs-work

**Issue**: #276 — Port run-issue from ros2_agent_workspace: in-process orchestrator over the #269 review loop, no container baggage
**Plan**: `.agent/work-plans/issue-276/plan.md` at `4e60515`
**Branch**: `feature/issue-276`

### Round-1 items — all five are addressed in the plan text

| Round-1 finding | Status in revision 3 |
|---|---|
| review-issue writes no `## Issue Review` | Addressed — PR 1 adds a persistence step (but see finding 1 and 4: the spec is thin and has an ordering hole) |
| Model table contradicted the owner's rule | Addressed — Open Question 1 now records the owner's 2026-09-17 decision (Opus for review phases) and §2's table matches it. No contradiction left in the text |
| Fork's implement phase claim unverified | Verified by me against `/home/roland/agent_workspace/.agent/scratchpad/inspiration/ros2_agent_workspace/.claude/skills/run-issue/SKILL.md` — "there is no `implement` skill yet. After `## Plan Review`, the host runs implementation **inline**". Plan's claim is accurate |
| Split the gate change out | Addressed — PR 0 |
| Partial/failed, concurrency, resume, Claude-Code-only | All four stated (§2 bullets). Resume conflicts with the table — finding 3 |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | PR 1 still bundles four independent things; the review-issue entry is its own PR-0-sized fix |
| Issue alignment | Good | In-process-only port, containers declined, matches the recorded owner decision |
| File targeting | Needs work | `_resolve_work_plans_dir.sh` is the wrong helper for worktree lookup; the `merge_pr.sh` change is bigger than the plan says |
| Consequences | Good | Three-row table; the entry-type ↔ `next` coupling and ADR-0013 are both covered |
| Principle alignment | Needs work | "Enforcement over documentation" claims the table is code, but `next`'s contract is not yet writable-as-a-test (finding 3) |
| ADR compliance | Good | 0002/0004/0009/0013 each answered; ADR-0013's `## Issue Review` required field (`**Issue**: #<N>`) matches what PR 1 proposes to write |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[File targeting / factual]** — PR 0's motivating claim is wrong, and the change as written would not have fixed the case it cites. The plan says "the first live run flagged a pre-push review at the head as 'stale' (#269 comment)". The actual record (`.agent/work-plans/issue-265/progress.md:370-378`) says: `latest Local Review entry is at 6737065, not the PR head 1b5ff2d`. That entry is a plain post-PR `## Local Review` (line 250), not a pre-push one — pre-push entries are excluded from the gate's selection entirely, because `Local Review (Pre-Push)` is a *distinct* canonical type in `progress_read.py` (`CANONICAL_TYPES`, `_canonical_base` keeps the parenthetical) and the gate's jq selects only `base_type == "Local Review" | "Integrated Review" | "External Review"`. Worse: the four pre-push entries on that branch are at `fd8e935 / 38e0f14 / de4589b / 2503896`, none of them the PR head `1b5ff2d` (a merge from main landed after the last review). So "accept a pre-push entry whose correlation SHA is the PR head" would still have refused this run. Either re-motivate PR 0 honestly, or decide the real question: should a pre-push review at the branch tip *before* a main-merge commit count? That is an owner-facing design question, not a one-line widening.

2. **[File targeting]** — §3 says the gate change is "the reader's `--type` list gains it", which is only a third of it. Three edits are needed in `merge_pr.sh` Step 1.5: (a) the `--type` args on the `progress_read.py` call; (b) the jq `select(.base_type == …)` list; (c) the verdict branch — `_gate_r_type == "Local Review"` is a literal string test, so a pre-push entry falls through to the *Integrated Review* branch and would be judged by `open_mustfix`, not by `**Verdict**`. Also, the plan's "a post-PR entry at the head still takes precedence when both exist" is not what `last // empty` does: `last` is chronological, and on #265 the pre-push entries come *after* the post-PR one, so last-wins would pick the pre-push. Precedence needs real logic, and a second test case.

3. **[Approach / Enforcement]** — `dispatch_phase.sh next` is not specified tightly enough to write its test first. Missing, each of them blocking a fixture test: (a) **input** — `next --issue <N>` has no `--progress <path>`, so a hermetic fixture timeline can only be fed through an undocumented `WORK_PLANS_DIR_OVERRIDE`; say which; (b) **output shape** — "prints `action=<…>` with a one-line reason" does not say whether the reason is the same line, a `reason=` line, or stderr, nor the exit codes; (c) **vocabulary mismatch** — the prose table's states are "checkpoint *then* plan-task", i.e. two actions, while the action list has only one `ask:<reason>` token; which one does the row emit?; (d) **non-timeline inputs** — "PR published → `triage-reviews` after review comments land" and the publish/idempotency rows cannot be decided from `progress.md` alone; does `next` call `gh` (breaking hermeticity) or take the PR state as an argument?; (e) **round count** — the three-round surface needs the round number; `review_progress.sh round` already counts prior `## Local Review (Pre-Push)` entries (line 115), so say `next` uses it rather than re-deriving.
   **The substantive hole underneath (d):** the `## Plan Review` row is "checkpoint (always), then inline implementation, then `review-code --branch`", but inline implementation writes no entry (the fork says so explicitly). So after implementation the newest entry is *still* `## Plan Review`, and `next` returns the same action forever. That directly contradicts §2's resume claim ("every invocation re-derives the next action from the newest entry… never keeps state outside `progress.md`"): resuming a half-done issue in that state re-runs the checkpoint and re-does implementation. Resolve it in the plan — either inline implementation writes a `## Implementation` entry (cheap, and it makes the state machine total), or `next` is explicitly documented as returning a state that the host must disambiguate from the worktree diff, and the resume claim is narrowed.

4. **[Scope / Issue alignment]** — the review-issue persistence step is under-specified against what the skill produces today. `review-issue/SKILL.md` step 7 emits a GitHub comment with **Scope Assessment / Principle Alignment / ADR Applicability / Consequences / Recommendations** — no ADR-0013 header fields, no `**Issue**:` line, and **no checkboxes anywhere**. The plan says "the open-question actions as checkboxes" but there is no "open questions" section to draw from; it must name the source (Recommendations? principle rows with status *Action needed*? both?), since that list is the routing key for `next`'s first two rows. It should also say, as `review-plan` does, whether the comment text and the entry are the same text (review-plan's "the report IS the progress entry") or two products.
   **Ordering hole:** `review_progress.sh persist` resolves through `_resolve_work_plans_dir.sh`, which refuses outside the issue's worktree. review-issue runs *first* in the table ("none → `review-issue`"), i.e. before a worktree normally exists — with `--soft` that is a printed notice and no entry, so the `## Issue Review` row still never fires. The plan needs one explicit sentence: run-issue creates/enters the issue's worktree (start-task semantics) *before* dispatching review-issue. Open Question 4 gestures at this but only about where the skill runs from, not about the ordering constraint that makes PR 1 work.

5. **[File targeting / factual]** — §2 says `dispatch_phase.sh` "resolves the issue's worktree with `_resolve_work_plans_dir.sh`'s rules". That helper does not resolve another issue's worktree; it validates that the *current* tree matches the issue and otherwise refuses (rules 2 / 2b / 3). Locating the worktree for issue N is `find_worktree_by_issue` in `.agent/scripts/_worktree_helpers.sh`. Name both and say which does what, or the script gets written against the wrong contract. (Everything else I checked is accurate: `progress_read.py` does emit `base_type` / `fields` / `correlation` / `findings[].checked`; `## Issue Review`'s correlation is `{"kind":"issue","issue":N}`, so PR 1's test assertion is well-founded; `review_progress.sh findings` does select the latest Integrated Review or Local Review (Pre-Push); `set_git_identity_env.sh` does export `AGENT_NAME` / `AGENT_EMAIL`.)

6. **[Scope]** — PR 1 is still too large and is not one logical change. It carries (i) the dispatcher + decision table, (ii) `review-issue` persistence + its own test, (iii) ADR-0014. (ii) is an independent ADR-0013 conformance gap — review-issue has owed an `## Issue Review` entry since #269 — and is exactly the shape of PR 0: small, load-bearing, independently motivated, and a prerequisite the dispatcher's first two rows depend on. Split it out as its own PR before the dispatcher. ADR-0014 documents a contract the skill embodies and reads naturally with PR 2's prose; moving it there leaves PR 1 as one thing: script + test.

7. **[Consequences]** — §4's ADR-0014 outline omits two things §2 promises will live there: the "one driver per issue" convention, and any record of the per-phase model tier (a reader asking "why Opus for review phases" finds only a table in a bash script). Add both to the outline. Otherwise the outline covers what a reader needs — context, what each side provides, the ADR-0004 layer, sources, and what was declined.

8. **[Principle alignment — note, not a blocker]** — the Opus-for-review-phases tier is recorded as an owner decision dated 2026-09-17, which is the right way to carry it. Flagging only that it is the opposite of the standing default; the implementer should treat it as scoped to this loop, not as a new global default.

**Nothing in the plan is an unlabelled owner question.** All four Open Questions carry their disposition, Open Question 2 explicitly invites disagreement, PR 3's merge is marked as the owner's call, and the AGENTS.md edit cites the #269 standing rule. The one *new* owner-facing question is the one hiding inside finding 1 (should a pre-push review survive a later merge-from-main commit?), which the plan does not currently pose at all.

### Summary

Every round-1 finding is genuinely addressed in the text, and the three owner decisions are recorded cleanly. The plan is not ready as written for two reasons: PR 0 rests on a misread of the live gate run and, as specified, would not fix it (findings 1-2), and `next` — the piece the whole "table is code" argument rests on — cannot yet be turned into a test, with a real gap where inline implementation leaves the state machine non-total and breaks the resume claim (finding 3). Findings 4-6 are the difference between a plan an implementer can follow and one they'll have to re-decide mid-PR.

### Recommended Actions

- [ ] Correct PR 0's motivation against `.agent/work-plans/issue-265/progress.md:370-378`, and decide/pose the real question: does a pre-push review at the branch tip still count after a merge-from-main lands on the PR head?
- [ ] Spell out all three `merge_pr.sh` Step 1.5 edits (type args, jq select, the Verdict-vs-open_mustfix branch) and make "post-PR takes precedence" explicit logic with its own test case
- [ ] Pin `next`'s contract: fixture input flag, exact stdout shape and exit codes, one action token per table row, how PR state enters, and where the round count comes from
- [ ] Close the inline-implementation hole — either it writes `## Implementation`, or narrow the resume claim and say how the host disambiguates
- [ ] Say which part of today's review-issue output becomes the checkboxes, and state that run-issue creates/enters the worktree before dispatching review-issue
- [ ] Replace `_resolve_work_plans_dir.sh` with `find_worktree_by_issue` (`_worktree_helpers.sh`) for worktree lookup; keep the resolver for the in-worktree refusal
- [ ] Split review-issue persistence into its own PR ahead of the dispatcher; move ADR-0014 to PR 2
- [ ] Add the one-driver convention and the model-tier rationale to ADR-0014's outline

## Plan Authored
**Status**: complete
**When**: 2026-09-17 14:45 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `f40a542`

Revision 4 after plan review round 2 (needs-work, 8 findings, all addressed): former PR 0 withdrawn (misread gate run), checkpoints and inline implementation become entries, `next` contract pinned with 22 rows, review-issue checkbox source named, four-PR split. One owner question remains open (Open Question 5: review surviving a merge-from-main), with a no-gate-change recommendation.
