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

## Plan Review
**Status**: complete
**When**: 2026-09-17 14:46 -04:00
**By**: Claude Code Agent (claude-opus-5), fresh-context evaluator, round 3
**Verdict**: needs-work

**Issue**: #276 — Port run-issue from ros2_agent_workspace: in-process orchestrator over the #269 review loop, no container baggage
**Plan**: `.agent/work-plans/issue-276/plan.md` at `f40a542`
**Branch**: `feature/issue-276`

### Round-2 findings — status in revision 4

| # | Round-2 finding | Status | Evidence checked |
|---|---|---|---|
| 1 | PR 0's motivating claim was wrong (misread #273 gate run) | **Addressed** | plan:55-68 now states it correctly: the gate's refusal named a *post-PR* `## Local Review` at `6737065` vs head `1b5ff2d`, and pre-push is a type the gate never selects. Verified: `issue-265/progress.md:250,256` (post-PR entry at `6737065`), `:370-378` (refusal text), `merge_pr.sh:633` (jq selects only `Local Review`/`Integrated Review`/`External Review`), pre-push entries at `fd8e935/38e0f14/de4589b/2503896` (`:310,329,345,360`). Former PR 0 withdrawn (plan:328); the real question is posed as Open Question 5 (plan:381-393) |
| 2 | Three `merge_pr.sh` Step 1.5 edits under-specified; `last // empty` precedence wrong | **Addressed by removal** | §4 (plan:278-284) and the Not-touched line (plan:328) drop the gate change entirely. Moot. (The `last`-is-chronological and `_gate_r_type == "Local Review"` literal-branch problems I re-confirmed at `merge_pr.sh:633,647` no longer apply to this plan) |
| 3 | `next` not specified tightly enough to test; inline implementation left the machine non-total | **Partially addressed** | The contract is pinned (plan:204-261): `--progress` fixture flag, `action=`/`reason=`/`round=` stdout, exit 0/2/3, one token per row, `--pr` as the only non-timeline input. Inline implementation now writes `## Implementation` (plan:46-48,120-125) and checkpoints are entries (plan:104-113), so the resume claim (plan:191-194) is now real. **But the 22-row table is not total and is not yet writable as a test** — findings 1, 2, 3, 4, 6, 7 below |
| 4 | review-issue persistence under-specified; ordering hole | **Addressed** | §3 (plan:263-276) names the checkbox sources exactly — Principle Alignment rows with status `Action needed`, then Recommendations bullets — which match what exists (`review-issue/SKILL.md:104-118` defines the three statuses; `:133-180` step 7's sections; there are indeed no checkboxes today). "The posted comment **is** the entry" mirrors review-plan. The ordering hole is closed by §1's worktree-first bullet (plan:85-93) plus plan:275-276 |
| 5 | Wrong helper for worktree lookup | **Addressed** | plan:153-160 names `find_worktree_by_issue` for locating and `_resolve_work_plans_dir.sh` only for writes. Verified `find_worktree_by_issue` exists at `_worktree_helpers.sh:315` |
| 6 | PR 1 too large | **Addressed** | Four PRs (plan:395-412): PR 1 = review-issue entry + its test only; ADR-0014 moved to PR 3 |
| 7 | ADR-0014 outline missing one-driver + model tier | **Addressed** | plan:286-298 lists both explicitly, with the model-tier rationale |
| 8 | Opus tier is the opposite of the standing default | **Addressed** | plan:183-184: "scoped to this loop and is not a new default for other work" |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four PRs, each one thing; PR 1 is independently motivated; the gate widening is out |
| Issue alignment | Good | In-process only, containers declined, matches the recorded owner decision |
| File targeting | Good | Helper split is right; `merge_pr.sh` untouched; every named file/line I checked exists as described except the two factual slips in findings 3 and 8 |
| Consequences | Needs work | The consequences table (plan:356-361) omits the merge-gate coupling that finding 8 exposes |
| Principle alignment | Needs work | "Enforcement over documentation" rests on `next` being a total, testable table. It is not yet total: three checkpoint kinds have no routing row and the commonest post-PR path lands on `checkpoint:unexpected` |
| ADR compliance | Needs work | ADR-0008 is not addressed for the ADR-0013 Checkpoint-row edit (finding 5). 0002/0004/0009/0013 are each answered |

### Findings

1. **[Principle alignment / Approach — MUST-FIX]** Row 10's preceding-entry list does not survive the `## Checkpoint` entries revision 4 inserts. The post-PR fix path is: `## Integrated Review` with open findings → row 16 `checkpoint:findings` → host writes `## Checkpoint` (After: Integrated Review, Decision: address) → row 18 `address-findings` → that phase writes `## Implementation`. `P` for that entry is **`## Checkpoint`(findings)**, which is not in row 10's list ("`P` is Checkpoint(plan) or Local Review (Pre-Push) or Integrated Review or Local Review", plan:243). No row matches → row 22 `checkpoint:unexpected` (plan:255). The same happens after a bare `## Local Review` (rows 16/18 route identically). This is the loop's most-travelled state. Fix row 10's `P` list to include `Checkpoint` with `**Decision**: address`, or key the row on the Checkpoint's `**After**` field rather than raw adjacency.

2. **[Principle alignment / Approach — MUST-FIX]** Three of the eight checkpoint tokens have no routing row, so the machine stalls the moment they fire. `checkpoint:rounds` (row 12), `checkpoint:phase-failed` (row 1) and `checkpoint:unexpected` (row 22) each cause the host to write a `## Checkpoint`, and plan:227-228 says "the `## Checkpoint` entry the host writes is what routes the next call" — but rows 14/15 require `Decision: publish`, rows 18/19 require the checkpoint be after an Integrated/Local Review with `address`/`merge`, row 5 requires after Issue Review with `proceed`, rows 8/9 require after Plan Review. So: after `checkpoint:rounds` the owner's natural answer (keep fixing) is `address` after a **pre-push** review — not routed; after `checkpoint:phase-failed` the host's own three offers are "re-dispatch / take over / stop" (plan:186-190) but there is **no `retry` token** in the decision vocabulary (plan:107-108) and no row for a phase-failed checkpoint; after `checkpoint:issue-actions` only `proceed` is routed, so an owner answering `address` lands on row 22. Every checkpoint kind × every decision token it can produce needs a row (or an explicit "not producible" statement) before this table can be called total.

3. **[Approach / factual — MUST-FIX]** `**Ship**` is not a field `next` can read, so row 11 cannot be implemented as written. `review-code/SKILL.md:627` writes it on a shared line: `**Round**: <R> | **Ship**: <recommended | continue> — <reason>`. `progress_read.py:337-341` builds `fields` with `^\*\*([^*]+)\*\*:\s*(.*)$`, which yields `fields["Round"] = "<R> | **Ship**: recommended — …"` and **no `fields["Ship"]` key at all**. Every real pre-push entry in the tree confirms this (`issue-265/progress.md:314,333,349,364`). Plan:51 asserts `progress_read.py` emits "`fields` (e.g. `Verdict`, `Ship`)" — the `Ship` half is wrong. Either row 11 keys on `**Verdict**: approved` only (which is present as its own line and covers the same case in all four #265 examples), or the plan states that `next` substring-parses `fields.Round`, or PR 2 splits the line in `review-code`'s template (a bigger change with its own consequences).

4. **[Approach — MUST-FIX]** The `round=` source does not fit `next`'s inputs. `review_progress.sh round` **requires `--branch`** (`review_progress.sh:104`) and filters to pre-push entries whose correlation branch matches; `next`'s pinned inputs are `--issue`, `--pr`, `--progress` only (plan:207) — no branch. It also returns *prior count + 1*, i.e. the number of the review **about to happen** (`review_progress.sh:124`), so with three pre-push entries it prints `round=4`. Row 12's "round ≥ `MAX_ROUNDS`" (plan:245) is therefore off by one against the "after three pre-push rounds" checkpoint (plan:116). Say where the branch comes from (the newest pre-push entry's `correlation.branch` is available and keeps `--progress` hermetic) and pin which of the two meanings `MAX_ROUNDS` compares against, with the fixture asserting it.

5. **[ADR compliance — MUST-FIX]** The ADR-0013 amendment is an edit to an accepted ADR's **Decision** table and is not covered by ADR-0008 as written. `docs/decisions/0013-…md:3-5` is Accepted; the `## Checkpoint` row (`:63`) says the author is "Human (owner), attesting a sequencing pause was exercised", and `:27` calls it "human-written". ADR-0008 permits Status-line notes, References additions and typo fixes (`0008-…md:47-53`) and requires superseding for "reversing or softening the position" and "anything a reader could mistake for 'this ADR now says something different'" (`:55-61`). Adding "or recorded by `run-issue` on the owner's behalf" (plan:299-302) is precisely a softening of the author constraint. The plan's ADR Compliance table (plan:347-352) never mentions ADR-0008. Decide it in the plan: either a Status-line scoped-exception note pointing at ADR-0014 (permitted), or ADR-0014 supersedes ADR-0013's Checkpoint row — not a silent inline reword.

6. **[Approach — MUST-FIX]** Row 2 is unreachable on the first call of every issue. Exit code 2 is specified for "no progress file" (plan:221), but at the loop's start there is no `progress.md` at all — `plan-task`/`review-issue` create it. So `/run-issue <N>` on a fresh issue exits 2 instead of printing `action=review-issue`. Say that a missing `progress.md` is an empty timeline (which is what `triage-reviews` already does — `triage-reviews/SKILL.md:117`) and reserve exit 2 for a `--progress` path the caller named explicitly.

7. **[Approach]** Two row pairs can match the same state, and top-to-bottom order silently picks the wrong one. (a) Row 15 reads "same, `--pr draft|open`" (plan:248) — if "same" means only "Checkpoint after Local Review (Pre-Push)" without the `publish` decision, then a `Decision: stop` checkpoint on a published PR matches row 15 (`triage-reviews`) *before* row 21 (`stop` → `done`, plan:254). Row 21 is next-to-last, so any stop that also matches an earlier row is swallowed; it only works today for the Plan Review checkpoint. (b) Rows 16-19 say "Integrated/Local Review" while rows 16/17 elsewhere say "bare `## Local Review`" — whether `Local Review (Pre-Push)` is included changes finding 2's answer. (c) Row 20's `--pr merged` disjunct (plan:253) is not conditioned on `E`, so it is pure row-order luck that rows 1-19 don't intercept a merged PR (e.g. `E = ## Implementation`, `--pr merged` → row 10 `review-code`). Make `stop` and `merged` first-class early rows, and spell out every "same"/"or" antecedent literally.

8. **[Consequences]** The merge outcome is not the entry the table assumes. In `--enforce` mode on a workspace PR a refused gate **writes no entry and exits 1** (`merge_pr.sh:737-744`), so `E` stays the merge checkpoint and row 19 returns `merge` forever — the one loop `next` can enter. Conversely `## Merge (report-only)` is written both when the gate passes **and** when it "would have refused" (`merge_pr.sh:745-750`), so row 20's `done` can't tell them apart from the type alone. The plan already anticipates the enforce flip (the #269 work) and §1 offers a re-run of `triage-reviews` on a stale-review report (plan:129-132) — but the table has no row for "merge refused". Add the row (and a consequences-table line: "the merge gate's records or its enforce behaviour → `next` row 19/20 + test").

9. **[Approach — minor]** `next` is specified against two different mechanisms without saying which is authoritative: raw adjacency (row 10's `P`) and the Checkpoint's `**After**` field (rows 5/8/9/14-19). They diverge as soon as a hand-written or out-of-band entry lands. Pick one — `**After**` is the robust choice and is in `fields` — and say so, since finding 1's fix depends on it.

**Other claims I verified and found accurate:** `_progress_entry.sh:26-34` does whitelist `Checkpoint`; `check_branch_updates.sh` exists and is executable; `progress_read.py` does emit `base_type`, `fields`, `correlation`, `findings[].checked` (`:330-348`); `review_progress.sh findings`/`sources` do read `## Local Review (Pre-Push)` (`:347`, `triage-reviews/SKILL.md:107-110`); `triage-reviews` with only a local review does proceed and persist ("stop only if both sides are empty", `triage-reviews/SKILL.md:91-94`) — note this holds only because §1's merge-main-before-review rule keeps the pre-push correlation SHA equal to the pushed head, which `sources` matches on; `review-issue/SKILL.md` step 7 is the last numbered step, so "step 8" is the right slot; `principles_review_guide.md` already carries a script-reference consequences row, so the plan's added rows fit.

### Summary

All eight round-2 findings are genuinely addressed — the withdrawn gate change is correctly re-motivated against the real #273 record, the checkbox source and worktree ordering are named, the helper split is right, and the four-PR split is clean. What is not ready is the piece the plan's whole "enforcement over documentation" argument rests on: the 22-row table is not total (the commonest post-PR path falls to `checkpoint:unexpected`, three checkpoint kinds have no routing row), two of its keys don't exist as specified (`**Ship**` isn't a parsable field, `round` needs a branch and is off by one), row 2 can't fire on a fresh issue, and the ADR-0013 edit needs an ADR-0008 answer.

**Open Question 5** — the recommendation is sound and I would not advise the owner differently. A merge-from-main produces a combination neither review saw, so the gate is right to call it stale; the plan's cheap mitigations (merge main *before* the final review, offer a `triage-reviews` re-run at the merge checkpoint) get the ergonomics without weakening the gate, and keeping any widening as a separate `merge_pr.sh` PR with its own test is the correct scoping. It is an owner call but not a blocker for this plan.

### Recommended Actions

- [ ] Fix row 10's `P` list (or key it on `**After**`) so `## Implementation` written by `address-findings` after a `checkpoint:findings` decision routes to `review-code`, not `checkpoint:unexpected`
- [ ] Give every checkpoint kind × decision token a row: `rounds`+`address`, `phase-failed` (and add a `retry` decision token — the host's own three offers don't fit the current vocabulary), `unexpected`, and `issue-actions` with a non-`proceed` answer
- [ ] Drop or rewrite row 11's `**Ship**` key — `progress_read.py:337-341` produces no `Ship` field because `review-code/SKILL.md:627` shares a line with `**Round**`; correct plan:51's claim too
- [ ] Pin the `round=` source: where the branch `review_progress.sh round` requires comes from under `--progress`, and whether `MAX_ROUNDS` compares against its count+1 output or the entry count
- [ ] Address ADR-0008 for the ADR-0013 Checkpoint-row edit — Status-line scoped-exception note or supersede via ADR-0014 — and add the row to the plan's ADR Compliance table
- [ ] Make a missing `progress.md` an empty timeline (row 2) rather than exit 2, so the first call of a fresh issue works
- [ ] Spell out rows 14/15/16-19's antecedents literally, and hoist `stop` and `--pr merged` above the rows that can intercept them
- [ ] Add a "merge refused" row (enforce-mode refusal writes no entry, `merge_pr.sh:737-744`) and distinguish a passing `## Merge (report-only)` from a would-have-refused one; add the gate coupling to the consequences table
- [ ] State whether `next` routes on entry adjacency or on the Checkpoint's `**After**` field, and use that one mechanism throughout

## Plan Authored
**Status**: complete
**When**: 2026-09-17 14:58 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `f0200b4`

Revision 5 after plan review round 3 (needs-work, 9 findings, all addressed). Three review rounds without an approved verdict: per the #269 standing rule the loop stops here and the owner decides whether to approve revision 5 or run a fourth round. Open Question 5 decided by the owner 2026-09-17: a merge from main gets a new review; no gate change.
