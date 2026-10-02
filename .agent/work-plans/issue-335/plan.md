# Plan: Workspace design document: README Goals section + living docs/design.md

## Issue

https://github.com/rolker/agent_workspace/issues/335

## Context

The README "Workspace goals" section is written (six sections, 6 bullets under Easy to
use). The 14 principles are settled in the owner's notes
(`.agent/scratchpad/design-doc-sources/goals-draft-2026-09-24.md`, main tree, gitignored;
the final state is the entry "PASS COMPLETE 2026-10-02", each exact text is in the entry
marked DECIDED for it, later entries override earlier ones). Not yet written:
`docs/principles.md` still has the old 11 principles, the review guide still has the old
rows, and `docs/design.md` is today an architecture/directory-layout document (223 lines,
not a design draft; line 223 even says "Seven guiding principles").

The owner wants a real review before the texts land: study what history shows improved
the quality of project improvements and the efficiency of making them, then compare that
with the revised goals and principles. So the order is review, then principles PR, then
design doc.

Principle texts are copied from the notes at implementation time, verbatim, not frozen
here. Phase 1 may change the list, and one more principle (orientation, undecided) may be
added.

## Approach

### Phase 1 — History review (read-only, findings to the owner)

Question: what improved (a) the quality of project improvements, (b) the efficiency of
making them? Then: which goals and principles does that support, which are missing, which
work against it?

1. **Sources** (all read-only):
   - This repo: `git log` (1584 commits since 2026-03-15), merged and closed PRs/issues
     via `gh`, `.agent/work-plans/issue-*/plan.md` and `progress.md` (69 issue dirs, 57
     with a timeline), `docs/roadmap.md`, ADRs `docs/decisions/`, `.agent/knowledge/`.
   - ros2_agent_workspace (the fork ancestor): local checkout, remote
     `rolker/ros2_agent_workspace` (2313 commits since 2026-01-09; 145 dirs under its
     `.agent/work-plans/`), its closed issues/PRs, roadmap, knowledge docs.
   - The project repos the fork served: only PR/issue metadata and history, to judge
     results (did a workspace change show up as fewer or earlier-caught defects there?).
     Workspace docs name no project; the agents' report goes to the scratchpad, which is
     not tracked, and findings shown to the owner may name them.
2. **What is measured, and what honestly cannot be.**
   - Extractable from data: PRs per month and workspace vs project share; review rounds
     and findings per PR (progress.md `Local Review` / `Integrated Review` entries, review
     comments via `gh`); issue-open to merge time; follow-up fix PRs or reverts that cite
     an earlier PR (a proxy for defects found after merge); how often a review finding
     changed the diff before merge.
   - Only sampled by reading: whether a rule or skill caused an improvement (read the
     issue/PR that introduced it and the work after it); owner interventions (only where
     visible as a comment, a "stop", a reverted agent action); effort or tokens spent
     (not recorded; transcripts exist only for recent weeks).
   - Cannot be known: the counterfactual, and quality outside what a reviewer wrote down.
     Every finding says whether it is counted, sampled, or judged.
3. **Split across read-only background agents** (Sonnet, one per slice, none may write
   outside the report directory, none may push or comment): (A) this repo's change
   history grouped by mechanism introduced (worktrees, review loop, merge gate,
   adapters, hooks); (B) the same for the fork; (C) outcome data from review timelines
   and PR metadata in both, with the counts above; (D) project-repo results for the
   fork's period; (E) the comparison: read the README goals and the 14 principles from
   the worktree and sort every mechanism and every observed improvement or regression
   into supported / missing / works against. One agent per slice reports a table, each
   claim with a commit, PR or file reference. The host reads the raw tables for the claims
   it passes on, and spot-checks a sample of references against the repo.
4. **Output**: one file per slice and a merged report under
   `.agent/scratchpad/design-doc-sources/history-review-<date>/` in the main tree
   (existing convention). The host presents the findings in the session as three
   labelled lists (history supports / missing / works against) with limits stated.
   The owner decides any change to goals or principles, one at a time, in the same
   one-per-turn way as the earlier pass; settled texts are appended to the notes file.
5. **Limits**: the fork's early period predates its progress timelines, so numbers there
   come from git and PR data only; the two repos differ in age and in how much agent
   autonomy they allowed; sample sizes will be small for anything judged by reading.
   The review finds support or contradiction, not proof.

### Phase 2 — Principles PR (after the owner has settled phase 1 changes)

6. Rewrite `docs/principles.md`: settled texts copied verbatim from the notes (name,
   rule, Why, Serves). Remove "The workspace serves the product". Re-copy at this step,
   after phase 1.
7. Rewrite `.agent/knowledge/principles_review_guide.md` "Principle Quick Reference": one
   row per principle (adherence looks like / watch for), using the guide-row checks
   recorded in the notes. Also: drop the "workspace serves the product" row (its
   "sustained workspace-heavy PR ratio" check); fix the ADR-0001 row, which today says
   record every decision in `docs/decisions/` and conflicts with "Keep one current design"
   (settle the wording with the owner); add the test guidance, the level checks and the
   consequence-vs-improvement note named in the notes. None of these three exists in the
   guide today; they are additions, with wording to draft from the notes. Add the
   prior-art row and make sure `plan-task` carries a "what was looked at" step (the
   notes record that the roadmap marks "search before building" done but no skill has it).
8. `plan-task` skill: add to step 2/5 the question "does this change alter the design
   picture, and which design section changes?". `review-plan` and `review-issue`: the
   same question as a check (their citing of design sections waits for phase 3).
9. Consequences, found by grep, to update: `.claude/skills/review-plan/SKILL.md`
   (lines ~216-218 name four principles), `.claude/skills/audit-workspace/SKILL.md`
   (principle table, lines ~36-37), `docs/design.md` line 223 ("Seven guiding
   principles"), `.agent/scripts/tests/test_issue_review_entry.sh` (uses two principle
   names as fixture text; check only if the names are validated, otherwise leave),
   `.agent/knowledge/inspiration_harness-starter-kit_digest.md` (quotes old names;
   historical digest, leave and say so). Skills that only point at the file
   (review-code, review-issue, triage-reviews, brainstorm, gather-project-knowledge)
   need no edit unless they name a principle; recheck by grep before commit.
10. **Needs owner approval, not automatic**: any edit to `AGENTS.md` or `CLAUDE.md`
    (Ask First). Known candidate: the notes list a separate AGENTS.md game-wording item
    (#373). Principles texts that overlap AGENTS.md (Verify before claiming, Name the rule
    before bending it) may suggest an AGENTS.md edit; list, do not make it.
11. Run `make lint` and the script tests; verify every claim in the guide rows against
    the files they cite.

### Phase 3 — docs/design.md (outline only; own detailed plan later)

12. Decide what happens to the existing architecture content (directory tree, project
    repository model, worktree strategy, review loop, governance): it is a current-state
    description, so it likely becomes the "current state" half of each part rather than
    being deleted. Open question for the later plan.
13. Outline from the issue: Purpose (points at README goals and principles); the model
    (sessions and roots, registry and adapters, worktrees, review loop and timeline, merge
    gate and owner control, identity), each item decided or proposed; rules that must stay
    true, each citing a principle; target vs current state per part; decision register
    (ADRs and plan decisions); open questions with owners; change log; children by the
    size rule. Opens with its own upkeep rules and the three levels. Where plans and
    progress live for a low-footprint project is a design item recorded in the notes
    (three options a, b, c). Wire-in of review-issue, review-plan, roadmap and the ADR
    one-line pointers belongs to that plan.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scratchpad/design-doc-sources/history-review-<date>/` (main tree, untracked) | Phase 1 reports |
| `docs/principles.md` | Phase 2: settled texts |
| `.agent/knowledge/principles_review_guide.md` | Phase 2: one row per principle, removals and additions in step 7 |
| `.claude/skills/plan-task/SKILL.md` | Phase 2: design-picture question, prior-art step |
| `.claude/skills/review-plan/SKILL.md`, `.claude/skills/review-issue/SKILL.md` | Phase 2: principle names, design-picture check |
| `.claude/skills/audit-workspace/SKILL.md` | Phase 2: principle table |
| `docs/design.md` | Phase 2: principle-count line; Phase 3: rewrite (own plan) |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Look for prior art before building | Phase 1 is this, applied to our own history |
| Verify before claiming | Phase 1 reports label each number counted, sampled or judged; host spot-checks references |
| Keep one current design | Phase 3 absorbs the existing architecture text instead of adding a second document |
| A change includes its consequences | Step 9 grep list; consequences checked before commit |
| Small steps | Three phases, review gates between; phase 3 gets its own plan |
| Ask about what matters, and show how much | Owner settles each change from phase 1 one at a time |
| Name the rule before bending it | AGENTS.md / CLAUDE.md edits flagged Ask First (step 10) |
| Leave in a project only what it chose to carry | Phase 1 only reads project repos |

(Self-check uses the settled 14 names; the repo copy of the principles is still the old
set until phase 2.)

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0001 | Yes | Guide row for it is revised in step 7; no new ADR (issue: none until a section stops moving) |
| 0003 / project-agnostic | Yes | No project named in tracked workspace docs; reports stay in untracked scratchpad |
| 0008 | Possibly | Any ADR pointer lines are cross-reference addendums only, in phase 3 |
| 0013 | Yes | Plan and later entries recorded through `progress_append.sh` |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| A principle in `docs/principles.md` | Review guide; skills naming it | Yes (steps 7-9) |
| `docs/design.md` | Directory tree and principle-count line; design-section pointers | Yes / phase 3 |
| `AGENTS.md`, `CLAUDE.md` | Framework adapters | No, owner approval first |

## Open Questions

- Phase 1 scope: is the fork's local checkout path the one to read (its `origin` is
  `rolker/ros2_agent_workspace`; it also has a `gitcloud` remote), and may the agents
  call `gh` read-only against the project repos it served, or git history only?
- Phase 1 depth: five Sonnet agents as above, or fewer (A and B merged)? It costs
  mostly wall-clock for the host reading tables, not tokens.
- Orientation principle ("Write for someone who just arrived"): add it before phase 2
  or let the history review test it first (the notes lean to the second).
- ADR-0001 row: soften to "record a decision where it will be found" or keep, given
  "Keep one current design"?
- Do G1 (time for quality) and G2 (field safety) stay at goal level? Notes: let the
  history review test them.

## Estimated Scope

Phase 1: no PR, findings in session. Phase 2: one PR. Phase 3: its own plan and PR.
