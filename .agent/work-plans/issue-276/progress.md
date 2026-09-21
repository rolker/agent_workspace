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

## Plan Review
**Status**: complete
**When**: 2026-09-17 15:14 -04:00
**By**: Claude Code Agent (claude-opus-5), fresh-context evaluator, round 4
**Verdict**: needs-work

**Issue**: #276 — Port run-issue from ros2_agent_workspace: in-process orchestrator over the #269 review loop, no container baggage
**Plan**: `.agent/work-plans/issue-276/plan.md` at `f0200b4`
**Branch**: `feature/issue-276`

### Round-3 findings — status in revision 5

| # | Round-3 finding | Status | Evidence checked |
|---|---|---|---|
| 1 | Row 10's adjacency (`P`) list broke on the post-PR path | **Addressed** | Adjacency is gone as a routing key: plan:238-239 "Adjacency to the entry before `E` is never consulted"; row 12 (plan:283) routes *any* `## Implementation` to `review-code` regardless of what preceded it. I walked the post-PR path (`Integrated Review` open → 19 → Checkpoint findings/address → 22 → `address-findings` → `## Implementation` → 12) and it no longer reaches row 28. One contradicting leftover survives (my finding 3) |
| 2 | Three checkpoint kinds had no routing row; no `retry` token | **Addressed** | The vocabulary table (plan:257-265) now defines decisions per `**After**` for all nine kinds, and `retry`/`takeover` exist. I enumerated all 9 kinds × their allowed decisions (21 pairs incl. `stop`): every one lands on a row other than 28 — `stop`→2, issue-actions/proceed→7, plan/proceed→10, plan/revise→11, publish|rounds/publish→16 or 17, publish|rounds/address→18, findings|merge/merge→21, findings|merge/address→22, merge-refused/retriage→24, merge-refused/address→25, phase-failed/retry→26, phase-failed/takeover→27. **No pair is uncovered** |
| 3 | `**Ship**` is not a readable field | **Addressed** | plan:52-56 states it correctly. Verified: `review-code/SKILL.md:627` writes `**Round**: <R> \| **Ship**: …` on one line, and `progress_read.py:339` uses `^\*\*([^*]+)\*\*:\s*(.*)$` per header line, so `fields` gets `Round` only. Rows 13-15 key on `**Verdict**`, which is its own line (`review-code/SKILL.md:620`). (Note: `review-code/SKILL.md:462` carries a *second*, differently-formatted Round/Ship template; irrelevant to `next` because it keys on Verdict, but it is a latent trap for any Round-substring parser) |
| 4 | `round=` source didn't fit `next`'s inputs; off by one | **Addressed** | plan:56-58 and plan:241-244: `next` counts *completed* pre-push entries itself, keyed on the newest pre-push entry's `correlation.branch` (hermetic under `--progress`). Verified the two facts it rests on: `review_progress.sh:104` hard-requires `--branch`, `:124` prints `len(mine)+1` (the upcoming round). With `MAX_ROUNDS=3` against completed count, the third `needs-work` review fires row 14 — matches "after three pre-push rounds" (plan:120-123) |
| 5 | ADR-0008 not answered for the ADR-0013 edit | **Addressed** | plan:350-354 takes the permitted form only (Status-line "Scoped exception in ADR-0014" + References; Decision untouched), which is verbatim what `docs/decisions/0008-permit-cross-reference-addendums-in-adrs.md:49-53` allows, and avoids `:55-61`. ADR Compliance gains the 0008 row (plan:404). Also verified the plan's supporting claim: `0013-…md:63` already says a checkpoint's "Required fields are defined by the checkpoint's own plan section, not fixed here", so `next` reading `**After**`/`**Decision**` needs no ADR change at all |
| 6 | Row 2 unreachable on a fresh issue | **Addressed** | plan:226-230 makes a missing progress file an empty timeline; row 4 handles it; exit 2 reserved for a caller-named `--progress` path or no worktree. Precedent verified: `triage-reviews/SKILL.md:118` "A missing `progress.md` is treated as an empty timeline" |
| 7 | `stop` / `merged` interceptable; "same"/"or" antecedents vague | **Addressed in the table** | Rows 1 and 2 are hoisted (plan:272-273) and every row 16-25 antecedent is written out literally. Two residuals below: row 1 cannot actually be reached after a merge (my finding 4), and `stop` is absorbing (my finding 8) |
| 8 | Merge-refused row + gate coupling in consequences | **Addressed** | Row 23 (plan:294) + consequences rows for the gate and for `review-code`'s lines (plan:415-416). **Correction to round 3:** its premise was wrong and revision 5 correctly did *not* adopt it — `_gate_record` is called only from the `--force-unreviewed` and report-only-refusal branches (`merge_pr.sh:736,749`); a **passing** gate (`_gate_reasons` empty, `:729-731`) writes **no entry at all**. So `## Merge (report-only)` always means "would have refused", exactly as row 23 assumes, and `0013-…md:64` says the same. The enforce-refusal half of the round-3 claim is right: `merge_pr.sh:738-746` exits 1 with no record |
| 9 | Two mechanisms (adjacency vs `**After**`) | **Addressed except for one leftover** | plan:116 and plan:238-239 pick `**After**`/`**Decision**` and say adjacency is never used — but plan:131-132 still says "`next` tells them apart by the preceding entry" (my finding 3) |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four PRs, each one thing; PR 1 independently motivated; `merge_pr.sh` untouched |
| Issue alignment | Good | In-process only; every container element explicitly declined and listed |
| File targeting | Good | Every file/line I checked exists as described (`review-code:627`, `progress_read.py:339`, `review_progress.sh:104,124`, `triage-reviews:118`, `0008:49-61`, `0013:63-64`, `_progress_entry.sh:26-36`, `merge_pr.sh:729-751`, `_worktree_helpers.sh:315`) |
| Consequences | Good | The gate-coupling and `review-code`-line rows round 3 asked for are both there (plan:415-416) |
| Principle alignment | **Needs work** | "Enforcement over documentation" now holds for the *checkpoint* half of the machine — the 28 rows are total over ADR-0013 types and over the checkpoint vocabulary. It does not hold for the **PR-state** half: `--pr` cannot express `plan-task`'s `[PLAN]` draft, which silently disables the entire pre-push loop (finding 1), and no step in the plan owns pushing (finding 2) |
| ADR compliance | Good | 0008 answered in the permitted form; 0013 needs no Decision edit; 0002/0004/0009 answered. One schema nit (finding 6) |
| Test what breaks | Good, with two blind spots | One fixture per row + three end-to-end timelines is the right shape; the two non-timeline outcomes (`--check-exit MISSING`, enforce refusal) cannot be covered by a timeline fixture (finding 7) |

### Findings

1. **[Principle alignment / Approach — MUST-FIX]** `plan-task` opens a `[PLAN]` **draft PR by default**, so `--pr draft` is the normal state from `## Plan Authored` onward — and the table treats `draft` as "published". `plan-task/SKILL.md:243-278`: step 8 skips only on `--no-pr`/no-`gh`; otherwise it pushes and runs `gh pr create --draft --title "[PLAN] …"`. ADR-0013 (`0013-…md:56`) calls a draft PR part of `## Plan Authored`. Consequences in the default run: (a) row 12 (plan:283) sends the first `## Implementation` to `review-code` **PR mode**, not `--branch`, so rows 13-15, `round=`, `MAX_ROUNDS` and `checkpoint:rounds` are **unreachable** and the run goes first-implementation → `## Local Review` → row 19/20 → `checkpoint:merge`, with no pre-push review ever; (b) row 16 `publish` is likewise unreachable, and row 17 would dispatch `triage-reviews` against a draft whose body is the plan, not a decision summary — failing the gate's condition (b); (c) §1's publish step (`gh pr create` via `gh_create_pr.sh`, plan:148-149) fails outright because a PR already exists on the branch — it needs `gh pr ready` + body replace. §1 knows about the distinction ("an open non-`[PLAN]` PR means already published", plan:150) but the `--pr` vocabulary cannot carry it, **and** the host's own probe (plan:149-150, `--json number,state,isDraft`) omits `title`, so the host cannot detect `[PLAN]` either. Fix: either dispatch `plan-task --no-pr` under run-issue (then `--pr none` until publish, and publish really does create the PR), or add a distinct `--pr` value for the plan draft and add `title` to the probe — and say which, because rows 12/16/17 and the publish step all change with it.

2. **[Approach — MUST-FIX]** Nobody pushes, and the exit contract forbids it. `address-findings/SKILL.md:161` is explicit: "push here; the calling session decides when to push." The handoff block's exit contract (plan:183-185) tells every dispatched phase "never push". So after publish, the post-PR loop — `address-findings` → `## Implementation` → row 12 `review-code` PR mode → `triage-reviews` → merge gate — all read a PR head that does not contain the fixes, and `triage-reviews`' SHA correlation (which §1 relies on at plan:152-155) matches the wrong head. The same clause is also factually wrong for `plan-task`, which *must* push to create its draft (`plan-task/SKILL.md:257-262`). Assign the push: name a host step (after every post-publish `## Implementation`, and before `review-code` PR mode / `triage-reviews`), and narrow the exit contract from "never push" to "never push except `plan-task`'s draft-PR step" or move that push to the host too.

3. **[Approach — MUST-FIX]** A stale adjacency claim survives, and rows 26/27's `**Phase**` is underdetermined on resume. plan:131-132 still reads "Same type `address-findings` writes; `next` tells them apart by the preceding entry" — directly contradicting plan:116 and plan:238-239 ("Adjacency … is never consulted"), which is the very mechanism round-3 finding 9 asked to be made single. It is not merely cosmetic: when a `## Implementation` carries `**Status**: failed`, row 3 fires and the host must write `**Phase**` on the checkpoint (plan:264), but the inline pass and `address-findings` write the *same* type with no distinguishing field, so a host resuming a half-done issue from the timeline alone (the plan's own resume claim, plan:117-119) cannot fill `**Phase**` correctly — and rows 26/27 then re-dispatch the wrong thing (`address-findings` vs `implement` + `mode=inline`). Fix: delete plan:131-132's clause, and have the inline pass stamp a distinguishing field on its `## Implementation` (e.g. `**Mode**: inline`, or a fixed `**By**`), with `**Phase**` derived from it. Also say what `next` does when a `phase-failed` checkpoint has no `**Phase**` at all.

4. **[Approach — MUST-FIX]** Row 1 (`--pr merged` → `done`) cannot fire after a merge, because the merge removed the worktree. `merge_pr.sh` step 4 runs `worktree_remove.sh` (`merge_pr.sh:961`) and deletes the branch (`:970`) as part of the merge flow. `next`'s input resolution (plan:222-230) locates `progress.md` through `find_worktree_by_issue` and exits 2 when there is no worktree — before any row is evaluated. So the terminating call of every successful run exits 2 instead of printing `action=done`, and the host's cwd is inside a removed directory. Fix: state that `--pr merged` short-circuits to `done` **before** worktree/progress resolution (a one-line ordering rule with its own fixture), and that the host `cd`s out before merging.

5. **[Approach — minor]** Internal count mismatch on the checkpoint vocabulary: plan:122 says `**After**` is "one of the eight `checkpoint:` names in §2", §2 lists **nine** (plan:250-252), and the Principles Self-Check says "Nine checkpoint kinds" (plan:389). §1's own enumeration (plan:119-123) lists only the seven kept from the fork, omitting `merge-refused` and `unexpected`, which are exactly the two revision 5 added. Make §1's list the nine and drop "eight".

6. **[ADR compliance — minor]** The `## Checkpoint` field list (plan:108-113) omits ADR-0013's mandatory header. `0013-…md:70-76` requires `**Status**`, `**When**` (with numeric offset) and `**By**: <agent name> (<model>)` on *every* entry; the plan specifies `**By**: <owner>` (a different meaning for the same field, where `**Recorded-by**` is the natural home for the agent) and no `**Status**`/`**When**`. `_progress_entry.sh:40-85` validates only the heading and fences, so a non-conformant checkpoint lands silently and the run's own timeline becomes the one ADR-0013-violating artifact in the loop. Spell the full header out in §1.

7. **[Test what breaks / Principle alignment — suggestion]** Two loop-freedom obligations sit in prose, outside the table and outside any fixture. Both are states where the timeline does **not** change and `next` would re-emit the same action: (a) an `--enforce` gate refusal (`merge_pr.sh:738-746`, no entry, exit 1) leaves `E` = Checkpoint(merge)/merge, so row 21 re-emits `merge`; (b) a dispatch that returns `MISSING` writes nothing, so the row that produced it fires again. The plan covers both by *instructing the host* (plan:141-144, plan:198-202) to write a `## Checkpoint` first, and the totality argument at plan:301-310 acknowledges the dependence. That is convention, not enforcement, in a plan whose headline claim is that the table is code. Cheap close: make the host's "write the checkpoint before calling `next` again" an explicit contract line in `run-issue`'s prose *and* add the corresponding fixtures (checkpoint present → correct row) so the test at least pins the intended shape. Same applies to `_gate_record`'s PR-comment fallback path (`merge_pr.sh:719-724`), where a report-only refusal record never reaches the timeline at all.

8. **[Approach — suggestion]** `stop` is absorbing, which qualifies the resume claim. Row 2 returns `done` for *any* later `/run-issue <N>` while a `stop` checkpoint is newest — so after the owner stops at, say, the plan checkpoint and then does work by hand that writes no entry, run-issue cannot be restarted on that issue at all (recovery means hand-running one phase so a new entry lands). That is defensible semantics, but it contradicts plan:117-119's unqualified "resumes from the newest entry". Add one sentence, and have row 2's `reason=` say how to resume.

9. **[Approach — suggestion]** Exit 3 has two sources but one definition, and the two malformed-checkpoint cases are asymmetric. plan:236 defines exit 3 as "`progress_read.py` exit 2 propagated, its message on stderr", while plan:254-255 and the test line (plan:370) also make an out-of-vocabulary `**Decision**` exit 3 — which `progress_read.py` never produces. Meanwhile an unrecognised `**After**` is handled *gracefully* (row 28 → `checkpoint:unexpected` → `stop` → `done`). A hand-written or mistyped `**Decision**` therefore kills the host outright with no route forward, where the sibling error politely ends the run. Route both to row 28, or state the asymmetry and give exit 3 its own definition line.

**Other claims I verified and found accurate:** `_progress_entry.sh:26-36` whitelists `Checkpoint`, `Merge (report-only)` and `Merge (unreviewed)`; `progress_read.py:` `CANONICAL_TYPES` keeps `Local Review (Pre-Push)` as a base_type distinct from `Local Review`, so the plan's "`## Local Review` means that exact `base_type`" (plan:245-246) is sound and rows 13-15 cannot be intercepted by 19/20; `Checkpoint` is deliberately in neither correlation set (`progress_read.py:` comment), consistent with routing on `**After**` instead; merge-gate entries carry `**Status**: complete` (`merge_pr.sh:668`), so row 3 cannot intercept row 23; `find_worktree_by_issue` exists at `_worktree_helpers.sh:315`; the plan's Consequences additions match the guide's existing consequences-map style (`principles_review_guide.md:58`).

### Summary

Revision 5 genuinely closes eight of the nine round-3 findings and over-delivers on two of them — the checkpoint half of the state machine is now total (I enumerated all eleven ADR-0013 types and all twenty-one `**After**`×`**Decision**` pairs; none falls to row 28 unintentionally), the `**Ship**`/`round=` corrections are exactly right against the source, and the ADR-0008 answer is the permitted form; round 3's own claim about `## Merge (report-only)` on a passing gate was wrong and the plan wisely did not repeat it. What blocks approval is the other routing input: `--pr` cannot express `plan-task`'s `[PLAN]` draft PR, which silently disables the whole pre-push loop, `publish`, and the rounds checkpoint in the default run; nobody in the plan owns pushing, so the post-PR loop reviews a stale head; one adjacency sentence survives and leaves rows 26/27's `**Phase**` underdetermined; and row 1 cannot fire after a merge because the merge deletes the worktree `next` resolves through.

### Recommended Actions

- [ ] Decide how `plan-task`'s `[PLAN]` draft PR enters `next` — dispatch `plan-task --no-pr`, or add a distinct `--pr` value plus `title` to the host's `gh pr list --json` probe — and update rows 12/16/17 and the publish step (`gh pr ready` + body replace, not `gh pr create`) accordingly
- [ ] Assign the push: name the host step that pushes after every post-publish `## Implementation` (before `review-code` PR mode / `triage-reviews`), and narrow the handoff exit contract's "never push" so it does not contradict `plan-task/SKILL.md:257-262`
- [ ] Delete plan:131-132's "tells them apart by the preceding entry", and give the inline implementation pass a distinguishing field on its `## Implementation` so rows 26/27 can fill `**Phase**` from the timeline alone; say what happens when `**Phase**` is absent
- [ ] State that `--pr merged` short-circuits to `done` before worktree/progress resolution (with its own fixture), and that the host leaves the worktree before merging — `merge_pr.sh:961` removes it
- [ ] Fix the "eight checkpoint names" count at plan:122 and list all nine in §1
- [ ] Add ADR-0013's mandatory `**Status**`/`**When**`/`**By**: <agent> (<model>)` header to §1's `## Checkpoint` field list (`0013-…md:70-76`), keeping the owner in `**By**`-equivalent prose or `**Recorded-by**`
- [ ] (suggestion) Make "write the merge-refused / phase-failed checkpoint before calling `next` again" an explicit contract line in `run-issue`, and add fixtures for those checkpoint states
- [ ] (suggestion) Qualify the resume claim at plan:117-119 for an absorbing `stop`, and say how to resume in row 2's `reason=`
- [ ] (suggestion) Give exit 3 a definition covering both sources, or route an out-of-vocabulary `**Decision**` to row 28 as an unrecognised `**After**` already is

## Plan Authored
**Status**: complete
**When**: 2026-09-17 15:18 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `52472fa`

Revision 6 after plan review round 4 (needs-work, 4 must-fix + 5 minor, all addressed). Round 4's must-fixes were integration edges (plan-task's draft PR, who pushes, Mode on the inline entry, worktree removed by the merge), not the table's core; owner decides whether to approve revision 6 or run round 5.

## Plan Review
**Status**: complete
**When**: 2026-09-17 15:25 -04:00
**By**: Claude Code Agent (claude-opus-5), fresh-context evaluator, round 5
**Verdict**: needs-work

**Issue**: #276 — Port run-issue from ros2_agent_workspace: in-process orchestrator over the #269 review loop, no container baggage
**Plan**: `.agent/work-plans/issue-276/plan.md` at `52472fa`
**Branch**: `feature/issue-276`

### Round-4 findings — status in revision 6

| # | Round-4 finding | Status | Evidence checked |
|---|---|---|---|
| 1 | `[PLAN]` draft PR makes `--pr draft` the normal state and disables the pre-push loop | **Addressed, one residual** | plan:163-168 dispatches `plan-task --no-pr`, so `--pr` is `none` until publish and rows 12/16/17 read literally. Verified at source: `plan-task/SKILL.md:242-249` — "Skip this step if the user passed `--no-pr`", and the push (`git push -u origin HEAD`, `:257`) lives **inside** step 8, so `--no-pr` skips the push as well as the PR; the plan is still committed in step 7. `review-plan` genuinely works without a PR: `review-plan/SKILL.md:16-20` ("The file path and `--issue` forms enable offline plan review without a PR") and its PR-less entry format at `:260-272`. The host probe now includes `title` (plan:173-174), closing round 4's other half. Residual: the `[PLAN]`-PR publish path loops (my finding 2) |
| 2 | Nobody pushes; exit contract says "never push" | **Addressed** | plan:178-183 assigns every push to the host; with `--no-pr` the contract is no longer contradicted by `plan-task`. `address-findings/SKILL.md:161` ("Do not push here; the calling session decides when to push") now matches the host-owned rule exactly. Enumeration check below (my finding 9/10 are residuals, not gaps in what the plan defines) |
| 3 | Stale adjacency sentence; `**Phase**` underdetermined | **Addressed** | The "tells them apart by the preceding entry" clause is gone (grep: no hit in the file); plan:144-150 stamps `**Mode**: inline` on the inline pass and derives `phase=` from it (plan:274-277), and plan:311 routes a `phase-failed` checkpoint without `**Phase**` to row 28. `**Mode**` is machine-readable: `progress_read.py:337-341` puts every `^\*\*Key\*\*: value` header line into `fields`, so `Mode` parses as long as it sits above the first `###`. Residuals: partial `## Checkpoint`/`## External Review` have no `phase=` mapping (finding 5); takeover ambiguity (finding 6) |
| 4 | Row 1 unreachable — the merge removes the worktree | **Addressed** | plan:184-188 and plan:258-260: `--pr merged` short-circuits to `done` before worktree/progress resolution, and the host `cd`s out first. Verified: `merge_pr.sh:961` runs `worktree_remove.sh`, `:980` `git branch -d`, `:981` `push origin --delete` (round 4 cited 961/970; the branch deletion is at 980-981). `worktree_remove.sh` blocks only on *uncommitted* changes (`:281-297`), so committed-but-unpushed entries do not stop it — see finding 9 |
| 5 | "eight checkpoint names" vs nine | **Addressed** | plan:129-135 lists all nine and "eight" no longer appears anywhere in the file |
| 6 | `## Checkpoint` missing ADR-0013's mandatory header | **Addressed, naming nit** | plan:110-113 now spells out `**Status**: complete`, `**When**` with offset, `**By**: <host agent> (<model>)` — exactly what `docs/decisions/0013-progress-md-entry-type-vocabulary.md:70-76` requires — with the owner in `**Decided-by**`. Nit: §5 still says `**Recorded-by**` (finding 8) |
| 7 | Loop-freedom obligations sat in prose with no fixtures | **Addressed** | plan:136-138 makes "the host writes the checkpoint entry **before** calling `next` again" a contract line and gives each checkpoint state a fixture; plan:353-357 states the dependence explicitly. Test-count nit at finding 7 |
| 8 | `stop` is absorbing, contradicting the resume claim | **Addressed, one hole** | plan:124-128 qualifies it, row 2's `reason=` names the stopped checkpoint and `--resume`, and `--resume` records a fresh `## Checkpoint` with the same `**After**`. I walked it (stop at `plan` → row 2 `done` → `--resume` → new Checkpoint After=`plan`/`proceed` → row 10 `implement`+`mode=inline`): no misroute, because every row keys on the *newest* entry only. The hole is `phase-failed` (finding 4) |
| 9 | Exit 3 had two sources; malformed `**Decision**` killed the run | **Addressed** | plan:279-284 reserves exit 3 for `progress_read.py` propagation and states that an unrecognised `**After**`, an out-of-vocabulary `**Decision**` and a missing `**Phase**` are "never exit 3: it routes to row 28"; the test row (plan:420) says the same |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four PRs, each one thing; no existing script's behaviour changes; `merge_pr.sh` still untouched |
| Issue alignment | Good | In-process only; container elements enumerated and declined (plan:19-27, 194-197) |
| File targeting | Good | Every claim I spot-checked is accurate: `plan-task/SKILL.md:242-257`, `review-plan/SKILL.md:16-20,260`, `address-findings/SKILL.md:161`, `merge_pr.sh:632-656,961,980-981`, `progress_read.py:337-341`, `0013-…md:70-76`, `gh` 2.100.0 has `gh pr ready` |
| Consequences | Good | Consequences table gains the `--no-pr` row (plan:467) and the worktree-removal row (plan:468) — both exactly the couplings revision 6 introduced |
| Principle alignment | **Needs work** | "Enforcement over documentation": the table is now total over the checkpoint vocabulary *and* the PR states, but one routing decision is wrong (finding 1 — the loop can merge without ever integrating GitHub-side reviews) and one host rule re-emits an action on an unchanged state (finding 2) |
| ADR compliance | Good | 0013 header now conformant; 0008 answered in the permitted form (plan:400-404); 0002/0004/0009 answered |
| Test what breaks | Good | One fixture per row + end-to-end timelines + the two non-timeline states; count mismatch only (finding 7) |

### Findings

1. **[Approach / Principle alignment — MUST-FIX]** Rows 19/20 send a **PR-mode `## Local Review`** to the merge checkpoints, so after the first post-PR fix round `triage-reviews` never runs again and GitHub-side reviews are never integrated. Path: `## Integrated Review` open → row 19 → Checkpoint `findings`/`address` → row 22 `address-findings` → `## Implementation` → row 12 → `review-code` **PR mode** (plan:330) → that phase writes `## Local Review` (`review-code/SKILL.md:615-616`: `## Local Review` in PR mode, `## Local Review (Pre-Push)` in branch mode) → rows 19/20 (plan:337-338) → `checkpoint:merge` → row 21 `merge`. The skill's own lifecycle says otherwise: `review-code/SKILL.md:647-648` — "Verdict `approved` → push (branch mode) or **hand to `triage-reviews`** (PR mode)" — and §1's design says the same (plan:189-193). Nothing catches it downstream: the gate accepts an approved `## Local Review` at the head (`merge_pr.sh:643-648`), so the run merges with bot/human PR comments that arrived after publish never triaged, and the `merge` checkpoint's vocabulary (plan:310, `merge`/`address`/`stop`) offers the owner no way to ask for a triage. Fix: split row 19/20 so a PR-mode `## Local Review` routes to `triage-reviews` (open boxes → `address-findings` or `checkpoint:findings`, none open → `triage-reviews`), leaving `## Integrated Review` on the merge checkpoints. This also restores §4's claim (plan:379-381) that the entry the gate reads is always the `## Integrated Review`.

2. **[Approach — MUST-FIX]** The `[PLAN]` pre-existing-PR publish path re-emits `publish` forever, and names a mechanism `gh_create_pr.sh` does not have. plan:174-177: "If a PR titled `[PLAN] …` exists anyway …, the host treats it as `none` for routing and publishes with `gh pr ready` plus a body replace". After that publish the PR is open and non-draft but its **title still begins `[PLAN]`**, so the host's own rule maps it to `none` again on the next turn, row 16 (plan:334) fires `publish` again on an unchanged timeline — `gh pr ready` then errors on a non-draft PR — and the run cannot leave the publish state. This is exactly the loop class §2's totality argument claims cannot exist (plan:353-357). Two mechanical points in the same fix: (a) `gh_create_pr.sh` is create-only — it ends in `gh pr create "${FINAL_ARGS[@]}"` (`gh_create_pr.sh:330,337,344,370`) and has no edit/ready mode, so the plan must name `gh pr edit --title … --body-file …` and say who appends the AI signature the wrapper would otherwise inject (`gh_create_pr.sh:97`, AGENTS.md policy); (b) key the treat-as-`none` rule on `isDraft == true` (the probe already fetches it, plan:173-174) and retitle in the same step, so the state actually changes. The gate side of this path is fine as claimed: condition (b) reads `.body` as well as comments (`merge_pr.sh:654-657`, `jq` over `[(.body), (.comments[].body)] | test("(^|\\n)## Decision summary")`), so a body replace carrying the pinned summary satisfies it.

3. **[Approach — minor]** `dispatch_phase.sh`'s pinned signature has no channel for skill flags, yet revision 6's central fix is "dispatch `plan-task` with `--no-pr`". plan:201-202 fixes the interface at `--issue/--skill/--prompt-file/--entry-type/--model`; the handoff block's task line is "run `/<skill>` for issue #N in worktree <path>" (plan:215-217). Nothing carries `--no-pr` into the sub-agent, and row 26 (`phase-failed`/`retry` → the token from `**Phase**`) would re-dispatch `plan-task` with no memory of it — reopening exactly the `[PLAN]` draft the plan just removed. Either add `--skill-args`/pin `--no-pr` into the `plan-task` row of the skill→entry-type table, or state that the handoff's task line is `/plan-task <N> --no-pr` verbatim.

4. **[Approach — minor]** `--resume` cannot recover a `phase-failed` stop. §1 says `**Phase**` is "copied from the `phase=` line `next` printed with that action" (plan:114-117), but on a resume the newest entry is the stopped checkpoint, `next` returns row 2 `done` (plan:320) and prints **no** `phase=` — so the host has no sanctioned source for `**Phase**` on the replacement checkpoint, and plan:311's "absent → row 28" then ends the run at `checkpoint:unexpected`. One sentence closes it: on `--resume`, copy `**Phase**` from the stopped checkpoint entry (or have row 2's `reason=` echo it).

5. **[Approach — minor]** `phase=` is underdetermined for two entry types that row 3 can select. Row 3 (plan:321) fires on *any* entry with `**Status**: partial|failed`, and `phase=` is "the failed entry's type mapped through the entry-type→skill table" (plan:274-277) — but that table (plan:212-214) covers only the six phase types. A partial `## Checkpoint` (the host interrupted mid-write) or a partial `## External Review` has no mapping. It degrades safely (no `phase=` → host writes a checkpoint without `**Phase**` → row 28 → `unexpected` → `stop`), so this is a documentation gap, not a hole in totality — say so in the `phase=` bullet and give it a fixture. `## Plan Authored` and the two `## Merge (…)` types are fine (the merge entries are always `**Status**: complete`, `merge_pr.sh:668`).

6. **[Approach — minor]** `**Mode**: inline` has two candidate meanings once row 27 exists. Row 27 (plan:345) hands a `takeover` back to the host with `mode=inline` — including a takeover of `address-findings`, which writes `## Implementation`. If the host stamps `**Mode**: inline` on that entry (it *is* running inline), a later failure maps `phase=implement` (plan:275-276) and row 26 re-dispatches the wrong phase — the precise failure round-4 finding 3 was about. State that `**Mode**: inline` marks the post-plan inline implementation pass only, and that a takeover writes the entry the taken-over skill would have written.

7. **[Test what breaks — minor]** End-to-end fixture count disagrees with itself: plan:358-360 names **four** timelines (clean run to merge; needs-work plan then revise; three pre-push rounds then stop; stop then `--resume`), the Files-to-Change test row (plan:420) says **three**. The row also predates the publish-path fixtures; add "`publish` → `--pr` flips `none`→`open` → row 17" as its own case, since that flip is the only thing that stops row 16 re-emitting.

8. **[Capture decisions — minor]** Field-name drift between the two places the checkpoint schema is written: §1 uses `**Decided-by**: owner` (plan:112), §5's ADR-0014 description says the entries carry `**Recorded-by**` (plan:400). Under §1's scheme `**By**` is already the recorder, so `**Recorded-by**` is both redundant and contradictory. Pick one before ADR-0014 is written.

9. **[Human control and transparency — suggestion]** Everything committed after the last push is silently discarded at merge, and the plan should say so deliberately. `progress_append.sh` commits each entry, so the terminal `## Integrated Review`, the `merge` checkpoint and any `## Merge (report-only)` record sit as unpushed commits on the branch; `merge_pr.sh` merges the *remote* head, then removes the worktree (`:961`) and deletes both branches (`:980-981`) with `|| true`, so those entries never reach `main` and no longer exist anywhere. Pushing them instead is not an option: the gate compares the review entry's correlation SHA to the remote head exactly (`merge_pr.sh:632-646`, `at_head`), so an entry commit pushed after the review makes the head ≠ the reviewed SHA and the gate refuses. One explicit rule in §1 ("the host pushes code, never entry commits, after the last review; the post-review timeline is local and dies with the branch"), or a decision to preserve it, closes the audit question the checkpoint design exists to answer.

10. **[Approach — suggestion]** Push enumeration, walked end to end: publish (plan:172-173) ✓; after every post-publish `## Implementation`, before `review-code` PR mode / `triage-reviews` (plan:178-183) ✓ — this also covers a row-27 takeover, which writes the same type. The one flow with no push rule is a branch that falls **behind main after publish**: §1's merge-from-main rule is scoped to "before each `review-code --branch` dispatch" (plan:151-153), which is pre-push only, and the `merge-refused` vocabulary (plan:310: `retriage`/`address`/`stop`) has no token for "merge main and re-review". If the repo ever requires an up-to-date branch to merge, the loop dead-ends at `merge-refused`. Add an `update` decision, or state that keeping the branch current after publish is the owner's call at the merge checkpoint.

**Output-line consistency (task item e) — checked, no finding:** the `mode=`/`phase=`/`round=` contract at plan:271-278 matches every row that emits them — row 10 `implement` + `mode=inline` (host runs it), row 26 `mode=inline` only when the failed phase was the inline pass, row 27 always, row 3 emits `phase=` with `checkpoint:phase-failed` — and §1's checkpoint spec (plan:110-117) consumes them in exactly that shape.

**Loop / reachability re-walk (task item 4) — otherwise clean:** with `--pr none` until publish, rows 13-15, 16 and `checkpoint:rounds` are reachable for the first time; row 16→17 is broken by the `--pr` flip, not by a timeline change, which is sound because the host re-reads `gh` each turn (plan:173-176); row 12's PR-mode branch, rows 19-25 and rows 26-28 are all reachable; the only two rows that could re-emit on an unchanged timeline are finding 1's merge path (routing, not a loop) and finding 2's `[PLAN]` publish (a true loop). `--pr merged` → row 1 → `done` fires correctly from the main tree after cleanup.

### Summary

Revision 6 closes all nine round-4 findings at the level they were raised, and its four new claims hold against the tree — `plan-task --no-pr` really does skip the push as well as the draft PR, `review-plan` reads a plan from the branch with no PR, `merge_pr.sh` really does remove the worktree and delete both branches, `gh pr ready` exists, `**Mode**` parses into `fields`, and the `## Checkpoint` header now matches ADR-0013:70-76. What blocks approval is the host↔script seam the fixes opened: a PR-mode `## Local Review` routes straight to the merge checkpoints, so after the first post-PR fix round `triage-reviews` never runs and the loop can merge with GitHub-side reviews never integrated; and the `[PLAN]` pre-existing-PR publish path leaves the title unchanged, so the host's own treat-as-`none` rule re-emits `publish` on an unchanged state — with `gh pr ready` failing on the second pass and `gh_create_pr.sh` having no body-replace mode to begin with.

### Recommended Actions

- [ ] **(must-fix)** Split rows 19/20 by base type: `## Integrated Review` keeps the `findings`/`merge` checkpoints; a PR-mode `## Local Review` routes to `triage-reviews` (or to `address-findings` when it has open boxes), per `review-code/SKILL.md:647-648` and §1's wait-for-reviews design — and restate §4's gate claim accordingly
- [ ] **(must-fix)** Make the `[PLAN]` publish path change state: key treat-as-`none` on `isDraft`, retitle in the same step, and name `gh pr edit --title --body-file` (with who adds the AI signature) instead of "body replace" — `gh_create_pr.sh` only creates
- [ ] Give `dispatch_phase.sh` a channel for `--no-pr` (pin it in the `plan-task` row or add `--skill-args`), so a row-26 retry cannot resurrect the `[PLAN]` draft
- [ ] Say where `**Phase**` comes from on a `--resume` of a `phase-failed` stop (row 2 prints no `phase=`)
- [ ] State that `phase=` is omitted for partial entry types with no skill mapping (`## Checkpoint`, `## External Review`) and that the run then ends at `checkpoint:unexpected`; add the fixture
- [ ] Define `**Mode**: inline` as the post-plan inline pass only, and say what entry a row-27 takeover writes
- [ ] Reconcile the end-to-end fixture count (plan:358 says four, plan:420 says three) and add the `publish` → `--pr` flip case
- [ ] Pick one of `**Decided-by**` (plan:112) / `**Recorded-by**` (plan:400) before ADR-0014 is written
- [ ] (suggestion) State the push rule for entry commits after the last review — they cannot be pushed without failing the gate's exact-SHA check (`merge_pr.sh:632-646`) and are destroyed by `merge_pr.sh:961,980-981`
- [ ] (suggestion) Add an `update`/merge-main decision to the `merge-refused` vocabulary, or state that a branch falling behind main after publish is handled by the owner at the merge checkpoint

## Plan Authored
**Status**: complete
**When**: 2026-09-17 15:30 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `ad23fd5`

Revision 7 after plan review round 5 (needs-work, 2 must-fix + 8 minor, all addressed). Round 5 confirmed all nine round-4 fixes against the tree; its must-fixes were the PR-mode re-review routing and the draft-PR publish loop. #284 gains the exact-SHA gate scope this plan depends on for enforce.

## Plan Review
**Status**: complete
**When**: 2026-09-18 11:23 -04:00
**By**: Independent plan reviewer (claude-opus-5)
**Verdict**: needs-work

**PR**: https://github.com/rolker/agent_workspace/pull/283 — [PLAN] Port run-issue: in-process orchestrator over the #269 review loop
**Issue**: #276 — Port run-issue from ros2_agent_workspace: in-process orchestrator over the #269 review loop, no container baggage
**Plan**: `.agent/work-plans/issue-276/plan.md` at `ad23fd5`

### Evaluation
| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Four PRs; containers/field mode/Copilot/context-fence declined and enumerated |
| Issue alignment | Good | In-process only; no gate widening |
| File targeting | Needs work | Dispatch contract cannot express three of six phases' invocations; `find_worktree_by_issue` lacks a base dir/type input; §1/§4 attribute the gate fix to the wrong issue and call it unlanded |
| Consequences | Good | Table covers entry-type↔next, gate records, --no-pr, worktree removal, review-code line format |
| Principle alignment | Good | 28-row table re-walked for publish, post-PR fix round, merge-refused, phase-failed/resume; no unintended row 28 |
| ADR compliance | Good | 0008 form for the 0013 note; 0002/0004/0009/0013 answered; Checkpoint header matches 0013 |
| ROS conventions | N/A | workspace plan |

### Prior findings
- Rounds 1–5: every must-fix resolved in revision 7 and re-confirmed against the plan text (R2 PR 0 withdrawal, `next` contract, worktree lookup split, four-PR split, ADR-0014; R3 checkpoint vocabulary, `**Ship**`, round counting, row 23; R4 `--no-pr`, host owns pushes, `**Mode**: inline`, `--pr merged`, exit 3; R5 rows 22a/22b, publish via `gh pr ready`, `**Phase**` on resume, unmapped phase → row 28, five fixtures).

### Findings
1. **[File targeting / Approach]** (must-fix) — The dispatch task line "run `/<skill>` for issue #N in worktree <path>" has no argument channel: `review-code` needs `--branch` vs `<pr-number>`, `triage-reviews` needs `<pr-number>`; the PR number never reaches the sub-agent. And the skill→entry-type table gives `review-code` one type, but it writes `## Local Review (Pre-Push)` in branch mode and `## Local Review` in PR mode, so `--check-exit` reports MISSING on every successful PR-mode review (always `checkpoint:phase-failed`). Fix: per-row task lines carrying the arguments, and a mode-aware entry-type lookup with fixtures for both modes.
2. **[File targeting]** (must-fix) — `find_worktree_by_issue` takes `(base_dir, issue_ref, repo_slug)`; `next`/`--check-exit` take only `--issue/--pr/--progress`, and neither §1 nor §2 says where the base dir / `--type` comes from. Pin it: workspace-only for now, or carry `--type`/repo slug through run-issue → dispatch_phase.sh.
3. **[Consequences / factual]** (must-fix) — §1's entry-commit bullet and §4 are stale: the progress-only-commits-count-as-at-head fix is #286 (merged in #287), #284 was the CI-target change (merged in #285); both are on main. Drop "until #284 lands" and state the exemption's real shape (ancestry + progress.md/roadmap paths only; ambiguous short SHAs stay stale).
4. **[Consequences]** (suggestion) — "the host owns every push" has one exception: `merge_pr.sh`'s own record push in `_gate_record`. Name it so an implementer does not "fix" it.

### Summary
Rounds 1–5 are genuinely closed and the 28-row table holds under a fresh re-walk. What remains is the host↔skill seam: the dispatch handoff cannot invoke review-code in either mode or triage-reviews at all, expects the wrong entry type from a PR-mode review, the worktree lookup has no type input, and §4's prerequisite is stale. All three are mechanical edits to §1/§2/§4.

### Recommended Actions
- [ ] Argument channel in dispatch_phase.sh (per-skill task lines with `--branch` / `<pr-number>` / `--issue`); mode-aware entry-type lookup for review-code; fixtures for both modes
- [ ] Pin the worktree base dir / `--type` for `find_worktree_by_issue` and publish/merge
- [ ] Correct §1/§4: #286 is the gate fix (merged), #284 the CI target (merged); state the exemption's shape
- [ ] (suggestion) Name merge_pr.sh's record push as the exception to host-owns-every-push

## Plan Authored
**Status**: complete
**When**: 2026-09-18 11:27 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `b21f467`

Revision 8 after round 6: dispatch_phase.sh gets per-skill literal task lines (review-code --branch vs <pr>, triage-reviews <pr> required) and a mode-aware expected-entry table with fixtures for both review-code modes; --type (default workspace) threads from run-issue through find_worktree_by_issue, publish and merge; §1/§4 corrected to cite #286 as the merged gate fix and #284 as the merged CI-target change with nothing outstanding; merge_pr.sh's own record push named as the exception to host-owns-every-push.

## Checkpoint
**Status**: complete
**When**: 2026-09-18 11:38 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: approve
**Plan**: `.agent/work-plans/issue-276/plan.md` at `cd1de96`

Owner approved revision 8 for implementation on 2026-09-18 ("approve with notes") after asking about field mode (not ported: #208/#209), ROS-specific content (none; package worktrees are an adapter concern), and the hosted-project layout (#265 governs `--type project` end to end and skill availability from project-rooted sessions). The three notes are recorded in the plan's Consequences table and Estimated Scope. First cut targets workspace issues. PR 1 (review-issue writes `## Issue Review`) starts now.

## Implementation
**Status**: complete
**When**: 2026-09-18 11:46 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `cd1de96`

**Branch**: `feature/issue-276-pr1` at `0457029`
**Mode**: inline

PR 1 of the #276 port (PR #291): review-issue step 8 writes an ADR-0013 `## Issue Review` entry (170f513); test_issue_review_entry.sh, 6 cases (0457029). Plan §3 implemented as written; no deviations.

## Local Review
**Status**: complete
**When**: 2026-09-18 11:50 -04:00
**By**: Claude Code Agent (lead: claude-fable-5-1; specialists: claude-sonnet-5 governance + adversarial; shellcheck)
**Verdict**: approved

**PR**: #291 at `bf88e00`
**Depth**: Standard (reason: 211 lines; skill + test, no enforcement script)
**Must-fix**: 0 | **Suggestions**: 3

### Findings
- [x] (suggestion, governance) skill description now mentions the progress entry — `.claude/skills/review-issue/SKILL.md:3`
- [ ] (suggestion, adversarial; carried to PR 2) `progress_read.py` tags checkboxes by section but does not filter; `dispatch_phase.sh next` must count only `section == "Actions"` boxes for rows 5/6, with a distractor fixture — `.agent/scripts/progress_read.py:213-245`
- [ ] (suggestion, adversarial; carried to PR 2) review-code's LGTM placeholder is an unchecked box while Issue Review's no-actions box is checked; rows 13-15 route on `**Verdict**`, not boxes, so no change here, but the asymmetry is noted for the dispatcher's fixtures — `.claude/skills/review-code/SKILL.md:637`
- [ ] (suggestion, governance; unassigned) review-plan's "check review-issue comments" prose could name the persisted `### Actions` as a source — `.claude/skills/review-plan/SKILL.md:165`

## Implementation
**Status**: complete
**When**: 2026-09-18 12:35 -04:00
**By**: Claude Code Agent (implementer: claude-sonnet-5; lead: claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `cd1de96`

**Branch**: `feature/issue-276-pr2` at `ba88f24`

PR 2 of the #276 port (PR #293): dispatch_phase.sh (03121fe), test_dispatch_phase.sh with 73 cases incl. all 28 next rows and five end-to-end timelines (28bbd1a), and one plan deviation decided by the lead: PR-mode Local Review routes on **Verdict** for rows 22a/22b, not open boxes, because the unchecked LGTM placeholder would loop forever (ba88f24). Plan text to be updated under PR 3.

## Local Review
**Status**: complete
**When**: 2026-09-18 12:43 -04:00
**By**: Claude Code Agent (lead: claude-fable-5-1; specialists: claude-sonnet-5 governance + adversarial; shellcheck; gemini skipped per owner)
**Verdict**: changes-requested

**PR**: #293 at `ba88f24`
**Depth**: Deep (reason: 990 lines; enforcement script)
**Must-fix**: 1 | **Suggestions**: 2

### Findings
- [x] (must-fix, adversarial) round_count counted partial/failed Pre-Push reviews, so a retried round hit MAX_ROUNDS one round early; filter status == complete, fixture added — `.agent/scripts/dispatch_phase.sh:425-435`
- [x] (suggestion, adversarial) no --type project fixture for resolve_worktree; two added — `.agent/scripts/tests/test_dispatch_phase.sh`
- [x] (suggestion, adversarial) --check-exit inspects only the newest entry when a phase writes twice; comment added — `.agent/scripts/dispatch_phase.sh:287`

## Local Review
**Status**: complete
**When**: 2026-09-18 12:44 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**PR**: #293 at `f84c784`
**Depth**: Light (reason: round 2; delta ba88f24..f84c784 is the one fix commit, verified by reading the diff and rerunning the suite)
**Must-fix**: 0 | **Suggestions**: 0

### Findings
- [ ] No issues found. LGTM. test_dispatch_phase 76/76, full suite 22/22, shellcheck clean.

## Plan Authored
**Status**: complete
**When**: 2026-09-18 13:08 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `0ace344`

Revision 9, sync with landed code: PR 1 (#291) and PR 2 (#293) merged; rows 22a/22b route on **Verdict** (the unchecked LGTM placeholder would loop an open-box rule); round counts only completed Pre-Push reviews. No design change beyond those two PR-2 outcomes.

## Implementation
**Status**: complete
**When**: 2026-09-18 13:17 -04:00
**By**: Claude Code Agent (implementer: claude-sonnet-5; lead: claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `0ace344`

**Branch**: `feature/issue-276-pr3` at `6d12f37`

PR 3 of the #276 port (PR #294): run-issue SKILL.md (0b1efa4), ADR-0014 + ADR-0013 note (673f14f), lifecycle note + principles guide + onboarding + ARCHITECTURE (7bae93c), AGENTS.md script row (6d12f37). Skill is ~325 lines vs the plan's ~300 target; claims verified against dispatch_phase.sh as merged.

## Local Review
**Status**: complete
**When**: 2026-09-18 13:25 -04:00
**By**: Claude Code Agent (lead: claude-fable-5-1; specialists: claude-sonnet-5 doc-accuracy/adversarial + governance; gemini skipped per owner)
**Verdict**: changes-requested

**PR**: #294 at `6e7063c`
**Depth**: Standard (reason: 639 lines of skill + docs; AGENTS.md one row under standing rule 2)
**Must-fix**: 3 | **Suggestions**: 2

### Findings
- [x] (must-fix, adversarial) step 4's before-count called progress_read.py on a not-yet-existing progress.md (exit 1); guarded, missing file = 0 — `.claude/skills/run-issue/SKILL.md`
- [x] (must-fix, adversarial) step 4 never checked `mode=inline`, which row 27 emits for any taken-over phase; step 4 checks first and step 5 covers non-implement takeovers with no **Mode** field — `.claude/skills/run-issue/SKILL.md`
- [x] (must-fix, governance) step 10 omitted that entry commits after the last review are pushed before merging and why that is safe (#286 ancestry rule) — `.claude/skills/run-issue/SKILL.md`
- [x] (suggestion, governance) Scope section with the three owner notes (#208/#209, #265, ADR-0012) — `.claude/skills/run-issue/SKILL.md`
- [x] (suggestion, adversarial) ADR-0013 References bullet trimmed to a pointer; routing detail moved to ADR-0014 Decision — `docs/decisions/0013-progress-md-entry-type-vocabulary.md`

## Local Review
**Status**: complete
**When**: 2026-09-18 13:26 -04:00
**By**: Claude Code Agent (lead: claude-fable-5-1; round-2 verifier: claude-sonnet-5)
**Verdict**: approved

**PR**: #294 at `c350499`
**Depth**: Light (reason: round 2; delta 6e7063c..c350499 is the one fix commit, each item verified against dispatch_phase.sh and merge_pr.sh)
**Must-fix**: 0 | **Suggestions**: 0

### Findings
- [ ] No issues found. LGTM. All five round-1 items resolved; no new inaccuracy introduced.
