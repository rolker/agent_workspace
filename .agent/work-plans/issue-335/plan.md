# Plan: Workspace design document: README Goals section + living docs/design.md

## Issue

https://github.com/rolker/agent_workspace/issues/335

## Context

The README "Workspace goals" section is written (seven sections as of 2026-10-02). The 16 principles are
settled in the owner's notes (`.agent/scratchpad/design-doc-sources/goals-draft-2026-09-24.md`,
main tree, gitignored; final state is the entry "PASS COMPLETE 2026-10-02", exact texts in
the entries marked DECIDED, later entries override earlier ones). Not yet written:
`docs/principles.md` and the review guide still have the old principles, and
`docs/design.md` is today a 223-line architecture/directory document, not a design draft.

The owner wants a review first: what in the history of this workspace and
ros2_agent_workspace improved the quality of project improvements and the efficiency of
making them, compared with the revised goals and principles. Order: review, principles PR,
design doc. Principle texts are copied from the notes at implementation time, not frozen
here; phase 1 may change the list. The orientation principle and the two undecided goal
bullets (time for quality, field safety) are hypotheses the review may inform. They do not
block phase 1.

## Approach

### Phase 1 — History review (read-only; findings to the owner in session)

1. **Sources.** This repo: git history, merged PRs and closed issues (`gh`),
   `.agent/work-plans/issue-*/plan.md` and `progress.md` (69 issue dirs, 57 timelines),
   `docs/roadmap.md`, ADRs, `.agent/knowledge/`. The fork: its local checkout (path is
   given in the agents' handoff at run time, deliberately not written in tracked files),
   remote `rolker/ros2_agent_workspace`, its closed issues/PRs, work-plans, roadmap.
   Agents read first, as prior art, `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`
   and the fork-parity items in `docs/roadmap.md` (both exist). The project repos each
   workspace served are read too (owner, 2026-10-02), with a short baseline from before
   agents were used; private projects are reported under labels, with no names, titles or
   numbers saved.
2. **Bias control.** Reading agents are NOT given the goals or principles. They record
   mechanisms (what was introduced, when, why) and outcomes. The host does the comparison
   in session, from their tables.
3. **Evidence format.** Every claim is a row: claim | evidence reference (commit / PR /
   file) | label (counted / sampled / judged) | n. Counted: PRs per month, workspace vs
   project share, review rounds and findings per PR (progress.md entries, review comments),
   issue-open to merge time. Sampled: whether a mechanism caused an improvement (read the
   introducing issue/PR and the work after it); owner interventions where visible as a
   comment or reverted action. Judged: everything else. Not knowable: the counterfactual,
   effort and tokens, quality nobody wrote down. Rule: a claim that is only "judged" cannot
   by itself justify changing a goal or principle.
4. **Defect proxy, detection rule.** A follow-up fix is a later PR or commit whose title,
   body or message names an earlier PR/issue number or commit and starts with fix, revert,
   hotfix or "follow-up", within 30 days and touching a file the earlier PR changed. Found
   by a saved script; matches are listed, not interpreted.
5. **Shape.** Counts come from rerunnable git/gh commands saved as a script in the report
   directory, not from an agent summarising numbers. Pilot first: one agent, one slice
   (the review loop in this repo); the host reads the table and spot-checks references
   against the repo; the table format is then fixed. After the pilot: two reading agents
   (Sonnet, read-only, one per workspace), same format.
6. **Output.** `.agent/scratchpad/design-doc-sources/history-review-<date>/` in the main
   tree (untracked, so it may name projects). The host presents three labelled lists
   (history supports / missing / works against) with limits stated. The owner decides any
   change to goals or principles one at a time; settled texts are appended to the notes.
   Limits: the fork's early period predates progress timelines (git/PR data only); the two
   repos differ in age and agent autonomy; reading samples are small. The review finds
   support or contradiction, not proof.

### Phase 2 — Principles PR (after the owner settles phase 1 changes)

7. Rewrite `docs/principles.md` from the notes, verbatim; remove "The workspace serves the
   product". Rewrite `.agent/knowledge/principles_review_guide.md` Quick Reference: one row
   per principle using the guide-row checks in the notes; drop the serves-the-product row;
   revise the ADR-0001 row (wording agreed with the owner; it conflicts with "Keep one
   current design"); add the prior-art row; add the test guidance, level checks and
   consequence-vs-improvement note named in the notes (none exists in the guide today).
   The ADR-0003 row stays: ADR-0003 is superseded by ADR-0011, as the row says.
8. `plan-task`: add "does this change alter the design picture, and which design section
   changes?" and a "what was looked at" prior-art step (the roadmap marks "search before
   building" done but no skill has it). Same design-picture check in `review-plan` and
   `review-issue`.
9. Other spots, each opened and verified: `.claude/skills/review-plan/SKILL.md` 216-218
   (names four principles); `.claude/skills/audit-workspace/SKILL.md` 36-37 (principle
   table); `.claude/skills/review-issue/SKILL.md` 128 (names the workspace vs. project
   separation principle) and the table templates at 134-145 and 174-180;
   `.claude/skills/plan-task/SKILL.md` 197-201 (template); `README.md:24` (link label
   "Guiding principles"; check it still fits); `docs/design.md:223` ("Seven guiding
   principles"). Left as is: old names in historical `.agent/work-plans/*/` plans and
   progress entries, `inspiration_*_digest.md`, and fixture text in
   `.agent/scripts/tests/test_issue_review_entry.sh` 56/58.
10. Review cost: `docs/principles.md`, the skills and `.agent/knowledge/*.md` are governance
    files in `review_depth_classification.md` (line 101-110), so the PR is at least
    Standard; Deep at 200+ changed lines or 10+ files. Standard and Deep run the same
    specialists, including cross-model review, so expect the full report.
11. Before commit: grep the copied principle texts and guide rows for project names (the
    notes are private and may name projects; the workspace stays project-agnostic); run
    `make lint` and the script tests; verify guide-row claims against the files cited.
12. Ask First, not automatic: any edit to `AGENTS.md` or `CLAUDE.md`. List candidates in
    the PR description (e.g. overlap with Verify before claiming, Name the rule before
    bending it).

### Phase 3 — docs/design.md (outline only; own detailed plan later)

13. The existing architecture text likely becomes the "current state" half of each part.
    Outline from the issue: purpose; the model (sessions and roots, registry and adapters,
    worktrees, review loop and timeline, merge gate, identity) each marked decided or
    proposed; rules citing principles; target vs current state; decision register; open
    questions; change log. The wire-in of review skills, roadmap and ADR pointers belongs
    to that plan.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scratchpad/design-doc-sources/history-review-<date>/` (main tree, untracked) | Phase 1 script, tables, report |
| `docs/principles.md`, `.agent/knowledge/principles_review_guide.md` | Phase 2: step 7 |
| `.claude/skills/{plan-task,review-plan,review-issue,audit-workspace}/SKILL.md` | Phase 2: steps 8-9 |
| `README.md`, `docs/design.md` | Phase 2: label check; principle-count line. Phase 3: design.md rewrite |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Verify before claiming | Claims carry a label and a reference; host spot-checks; the pilot gates fan-out |
| Only what's needed | Pilot, two agents and a script, not a five-agent fan-out; no project-repo slice |
| Ask about what matters, and show how much | Owner settles each phase 1 change one at a time |
| Name the rule before bending it | AGENTS.md / CLAUDE.md edits flagged Ask First (step 12) |
| A change includes its consequences | Step 9 list, found by grep and opened |

(Uses the settled names; the repo copy was rewritten in phase 2, commit 091532c.)

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0001 | Yes | Guide row revised (step 7); no new ADR until a section stops moving |
| 0011 (supersedes 0003) | Yes | Workspace stays project-agnostic; reports stay untracked; grep in step 11 |
| 0008 | Possibly | ADR pointers in phase 3 are cross-reference addendums only |
| 0013 | Yes | Entries via `progress_append.sh` |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| A principle in `docs/principles.md` | Review guide; skills naming it | Yes (steps 7-9) |
| `AGENTS.md`, `CLAUDE.md` | Framework adapters | No, owner approval first |

## Open Questions

All closed (2026-10-08):

- ADR-0001 row wording: accepted as drafted, plus the ADR-0008 addendum exception.
- Orientation principle: shipped as "Give the user what they need now" (16th principle).
- Time for quality and field safety: stay at goal level, no principle.
- "Each project says what healthy and the right direction mean": stays at goal level;
  served by the Direction role in the documentation-layers design (design-only).
