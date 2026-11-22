# Plan: A skill for high-level design discussions

## Issue

https://github.com/rolker/agent_workspace/issues/370

## Context

The owner restated the goal (comment 7069803282 and the checkpoint of 2026-11-21 16:54): a discussion bigger than one session must save its details where every later implementation session finds them, until the work is done. The skill works at one of three levels (the workspace, a project, a part of a project, ADR-0022) in three ways: **Create** goals, design and roadmap where a level has none; **Revise** them where it has them; **Carve** a sub-component or new feature out as a sub-design of the parent. The old scope (a challenge conversation ending in a private scratchpad summary) is superseded; this plan replaces the earlier one. Issue Review actions A1-A8 (the newest `## Issue Review`, owner-accepted) are constraints; "Review actions" below answers each.

**Delivery in parts** (#459). **This plan is Part 1 only**; its PR says `Part of #370`, not `Closes #370`.

- **Part 1 (this plan):** the skill, with the level framing, Revise and Carve, writing into the level's tracked documents. Locations only where today's readers accept them.
- **Part 2 (later, `Closes #370`):** Create, plus asking and storing where a project keeps its goals, design and roadmap (an onboarding step 3 question with suggested locations, "decide later" valid, one stored setting, readers keyed to it). It depends on #551 (where a project keeps its goals, design and roadmap: asked at onboarding, stored once, followed by every reader; filed beside #393). Part 2 adds the Create mode, the settings and onboarding changes and the `docs/design.md#documentation-layers` edit, each with tests.

**Name `design-discussion`, the trial banner and the 2026-12-31 revisit date** stay (owner decisions earlier on this timeline). The banner text must change (see action 8), because its two cases ("a fresh idea", "an existing design") no longer match the three uses.

## Approach

1. **Rework `.claude/skills/design-discussion/SKILL.md`** (already on the branch; keep `session_scope: both`, the trial banner, the plain-names and question rules, and the method of purpose first, attack, defend, rounds, own-words check, decision-record pass, landing checks and fresh-session second pass). Changes:
   - **Delete "Where summaries live"** and every `$DD_DIR` use in Steps 1, 5 and 7: the folder resolution, the `git check-ignore` probe, the session file, the `<date>-<plain-topic>.md` summary, the "look in `$DD_DIR` for earlier sessions" lookup. Scratchpad stays only as in-session notes (text says: one machine, untracked, never the home of a decision).
   - **New Step 0, "Level and documents".** Ask which level (workspace, a project, a part) and which use (Revise or Carve; a level with no goals/design/roadmap is Create, not yet available, see below). Read the parent's goals for a part. Find the level's documents with what today's readers accept, and where none exists say so and ask, never guess:
     - roadmap: `docs/roadmap.md`, else `ROADMAP.md` (what `sitrep_root.sh` reports as `roadmap=`; `update_roadmap.sh` also accepts `docs/ROADMAP.md`);
     - design: `docs/design.md`; a part's design is the `design.md` in the sub-roadmap file's directory (`check_design_anchors.sh` reads "the design.md beside it"; the `Root` cell is only the directory the sub-roadmap's checks are relative to, not where the design is), cited `<path>/design.md#<section>`, `<path>` the design file's directory;
     - goals: the repository's `README.md#<goals section>` for the workspace; for a project, the goals the project's own design or README names; if none, say so.
     Everything else is per project and waits for #551 (Q-c below: say so and ask, record the answer on the issue).
   - **The discussion's issue is its anchor (Q-a, F7).** Before its first tracked write the skill asks the user for the issue, or offers to open one (Issue-First Policy; `design-discussion` is not in the Skill Worktree Exception allowlist and Part 1 does not extend it). Every session writes to that issue and resumes from it. For a project that uses no issues, the anchor is the draft PR body, or the skill asks. The branch for drafts uses the root's own worktree route for that issue.
   - **Step 1 resume rule** now reads the issue first (its latest state comment, F1), then the tracked documents: the level's design, roadmap Direction lines, the branch or draft PR holding the draft, open issues citing them; the first output is the one-liner of the overall task, then progress against the roadmap's lines, then only the context for the detail. Delete the "plan" wording ("progress against its plan", round-1 suggestion).
   - **Drafts live in the documents from the first session.** The first time the user says what is decided, the skill proposes the target document and section; on the user's yes it puts the draft into that document on a branch (a worktree under the root's own rules) and offers a draft PR, so the next session finds it by reading the document. Each later decision is a tracked edit on a yes of its own, one at a time. No decision waits in scratch.
   - **Step 7 "Record" rewritten.** Tracked writes on each yes, by kind (all of it also noted on the anchor issue): design decisions into the level's design (ADR-0017: one current picture, no layers; the design's own change rule followed or said to be set aside); work into roadmap `## Direction` lines with a check each (`| Line | Check |`, grammar in `sitrep_checks.sh`'s header) and the issues those lines cite; a deferral into the `| Deferral | Revisit check |` table with its reason and what brings it back; a rejected option into Decided Against; an offered but unsettled idea into To Consider, marked offered. Remove the "only on a continue landing" gate: every ending (continue, prune, shelve, clearer-but-undecided) writes what was decided. Two further tracked writes, on every ending and on the user's yes mid-session:
     - **Undecided state (F1):** a comment on the anchor issue (or the draft PR body for a project with no issues) with the open questions, the options still in play and where the discussion stands; the resume rule reads it first. A session cut off mid-round leaves the last such comment.
     - **The why (F2):** each decision's reason goes to the Decisions role of `docs/design.md#documentation-layers`: a comment or progress entry on the anchor issue, and an ADR draft when the decision is a rule. The design keeps the current picture only (ADR-0017), so the reasoning has its own destination or later sessions reopen what was settled.
     - **No document (F3, Q-b):** if a level has no goals, design or roadmap (Create, Part 2) or a Revise target is missing (say, no Direction section), the conversation still runs; drafts and open questions are recorded as a comment on the anchor issue, not left in the conversation (no new file at a location nobody reads), and the skill says Create comes in Part 2.
   - **Carve** (a new section): the part's design and roadmap are written as the part's own files, `design.md` beside `roadmap.md` in one directory (F5; the checkers read the design beside the sub-roadmap). The skill proposes the part's directory and the pointer row's `Root` cell (the part directory or `.`; every check path in the sub-roadmap resolves against it) and confirms both with the user. The part's goals are a goals section of its `design.md` (F6; no reader looks for goals elsewhere, ADR-0022 decision 1), and each names the root goal it serves (ADR-0022 decision 7). The parent design keeps only what crosses the boundary plus a pointer cited `<path>/design.md#<section>` (ADR-0022 decision 6); the parent roadmap gets one `| Sub-roadmap | Root |` row (one level followed). Landing check: run `check_design_anchors.sh` over the new files and `sitrep_checks.sh` on the parent roadmap and report the result; a broken pointer blocks calling it landed. If the parent is itself a part, `sitrep_checks.sh` lists the new row as "not followed" (one level only); the check reports that as expected, not as a failure.
   - **Revise** keeps the existing Steps 4 and 6 decision-list pass (kept / waits / changed / dropped) and the ban on "the design still stands". Add the upward check from the 2026-10-02 and 2026-10-12 comments in its smallest form: before landing, compare the draft with the history (issues, branches, deferrals) and sort each finding by level (goal, principle, design, detail) before showing it; label evidence counted, sampled or judged. Mark as *untested*.
   - **Absorbed from the old follow-up (a)** (goals-down): sort what the user says by level, one item per turn with current and proposed text side by side, user's words first, "let's keep thinking" mode, check each sentence's level before showing it. Only what an observed failure backs (cited by comment date); the side-thoughts queue file is not included (still untested).
   - Synthetic names only; keep the *Why* only where a failure backs it; rules from no failure stay marked *untested*.
2. **Banner (action 8).** Rewrite the trial banner: trial until two uses are recorded, one Revise and one Carve (Create's use comes with Part 2, which keeps the trial open for that mode); outcome and the settle / revise / remove decision go in a comment on #370; revisit 2026-12-31 or both uses done, whichever first. The date stays right for Part 1 (about 40 days from today); it judges Part 1 only, since Part 2 waits on #551, and the banner says so.
3. **`.agent/knowledge/skill_workflows.md`**: add a `design-discussion` row to the Utility skills table (round-1 suggestion, still valid).
4. **Rerun, do not redo.** Already on the branch and unchanged: the `brainstorm` "What this is not" pointer, the skill count 24 in `docs/design.md#instruction-layers` with its change-log row, the `.agent/AGENT_ONBOARDING.md` list entry, the `principles_review_guide.md` row fix. Regenerate the manifest (`make generate-user-tier-skills`) only if the skill's front matter changes (it should not), and run `test_plugin_manifest.sh` and `test_skill_paths.sh` after the rewrite (the latter flags the path idioms; the `agent-workspace-root` idiom stays only where the skill calls `sitrep_root.sh` or `check_design_anchors.sh`).
5. **Follow-up issue drafts (text only, nothing filed, per A8):** see the end of this plan.
6. **Trial uses.** The owner runs, or asks for, one Revise and one Carve session; the SKILL.md PR description says it is a trial.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/design-discussion/SKILL.md` | Rework: level framing step, Revise and Carve, tracked-write record step, resume-from-documents, summary mechanism removed, banner rewritten |
| `.agent/knowledge/skill_workflows.md` | New skill row |
| Already on the branch, unchanged | `brainstorm/SKILL.md`, `docs/design.md` (count), `.agent/AGENT_ONBOARDING.md`, `principles_review_guide.md`, `.claude-plugin/plugin.json` |

## Review actions

Numbered as the Issue Review's Actions list (A1-A8, in order).

1. **A1 Part 1 stays inside the design as it is.** Carve uses parts and `| Sub-roadmap | Root |` as ADR-0022 and #488 define them; no new layout. The Documentation layers change (location setting) is Part 2 and goes to the owner with #551.
2. **A2 Location is a per-project answer, stored once.** Not in the skill or scratchpad. Part 1 reads only today's accepted locations (step 1, Step 0); the question and storage are Part 2. The owner chose a new issue beside #393; it is filed as #551. Part 1 does not depend on it.
3. **A3 Scratchpad mechanism dropped.** Step 1 above removes "Where summaries live" and with it the round-1 must-fix findings (folder resolution, root-less file names); the remaining round-1 suggestions are answered by the resume rewrite and the `skill_workflows.md` row (step 3); the `agent-workspace-root` wording survives only if the skill still calls workspace scripts.
4. **A4 Two parts.** Context above: `Part of #370` now, `Closes #370` on Part 2.
5. **A5 New location issue.** Filed as #551; Part 2's dependency, cited above.
6. **A6 Locations the readers accept today.** Step 0 lists them (`sitrep_root.sh`, `update_roadmap.sh`, `check_design_anchors.sh`, `sitrep_checks.sh`); where none exists, say so and ask.
7. **A7 Rework, not discard.** Step 1 keeps the method and replaces the summary and the continue-only offer; the F5/F6 resolution code goes.
8. **A8 Follow-ups.** (a) dropped, absorbed into step 1; (b) revised below; (c) conditional, below.

## Prior Art

Earlier plan's prior art stands (gstack `office-hours` and `plan-ceo-review`, BMAD `bmad-forge-idea`, `reason-grill` and `devils-advocate`; rejected: size, startup framing, one-way grilling; `brainstorm`, `review-plan` and `review-issue` checked, none attacks and defends or lands decisions). Added: the roadmap Direction grammar, Decided Against / To Consider, the deferral table and the `Sub-roadmap | Root` pointer (all existing, used as is); `orchestrator` and `sitrep` for the one-liner-then-progress resume shape; ADR-0022's own boundary rule for what a parent keeps about a part. No new mechanism is built.

## Serves

The long view, Trust, control and information, and Quality of the work (`README.md#workspace-goals`); `docs/design.md#documentation-layers` (Direction row, parts) and `docs/design.md#instruction-layers` (skills).

## Design Picture

No change to the design picture in Part 1: a skill text over existing documents and the parts mechanism; only the skill count in `docs/design.md#instruction-layers` changed (already on the branch). Part 2 changes `docs/design.md#documentation-layers` (a stored location for goals, design and roadmap, and the readers keyed to it), brought to the owner via #551.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Capture decisions where they will be found | Open questions, state and reasons go to the anchor issue on every ending; drafts and decisions go to the level's tracked documents on a branch or draft PR from the first session; scratch is in-session only; resume reads the documents first |
| Keep one current design | Revisions edit the level's one design; a part's design is separate and the parent keeps only the boundary (ADR-0017, ADR-0022) |
| Put each thing at the level it applies to | Level named first; locations per level, project locations left to Part 2 (#551); synthetic names in the skill |
| Small steps | Part 1 is Revise and Carve over existing locations; Create and settings are Part 2 |
| Look for prior art | Above |
| Only what's needed | Goals-down skill absorbed rather than a second skill; side-thoughts queue not included; untested rules marked |
| A safeguard has to earn its cost | Two-use trial (Revise, Carve) and the 2026-12-31 revisit |
| Test what breaks | `check_design_anchors.sh` and `sitrep_checks.sh` as Carve's landing check; manifest and skill-path tests |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0022 A part owns its inside | Yes | Carve writes the part's own `design.md` (with a goals section naming the root goal served) beside its `roadmap.md`, a pointer row and a boundary-only parent entry cited `<path>/design.md#<section>` (decisions 1, 6, 7) |
| 0017 Design is the current picture | Yes | Revisions land in the one design; count update already done |
| 0018 Plugin delivery | Yes | `session_scope: both`; manifest test |
| 0013 Progress timeline | Yes | A checkpoint after Part 1 before Part 2 starts |
| 0016 User tier | Light | `$WS_ROOT` idiom only where the skill calls workspace scripts |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Skill text | `skill_workflows.md` row; manifest and skill-path tests | Yes (steps 3, 4) |
| Carve writes sub-roadmap pointers | Landing check with `check_design_anchors.sh`, `sitrep_checks.sh` | Yes (step 1) |
| Location of project goals/design/roadmap (#551) | `project_setting.sh`, `_project_registry.sh`, onboard-project step 3, `docs/design.md#documentation-layers` | No, Part 2 |
| Round-1 findings about the scratchpad | Withdrawn with the mechanism | Yes |
| Undecided state, the why and no-document drafts | Anchor issue comments and the Decisions role; resume reads the issue first | Yes (step 1) |

## Open Questions

None. Settled by the owner (Checkpoint 2026-11-21 17:10, "Accept all three") and carried into the Approach above: Q-a the issue is the anchor (project with no issues: draft PR body, or ask); Q-b a level with no documents gets the conversation with drafts and open questions on the issue, and is told Create comes in Part 2; Q-c where a project's goals live: say so, ask, record the answer on the issue (#551 settles it for Part 2).

## Estimated Scope

One PR for Part 1 (`Part of #370`); Part 2 is a separate plan and PR(s) after #551.

## Follow-up issue drafts (text only; none filed)

**(b) Title**: Long view: derive a whole roadmap from a design, check drift, measure
**Body**: Part of #370. Comments of 2026-10-12 on #370 (D1-D8, M1-M10) record failures on two redesigns. `design-discussion` (Part 1) writes decided items into the Direction lines of the level's roadmap one at a time; what remains: deriving a whole route from a design for each acceptance case (M1, D1), drift checks between design, roadmap and open issues (M4, M5, M6), a check that nothing in flight was missed before publishing (D6), measures of whether a change helped (M7), protection of the acceptance case from meta-work (M8), and status said in conversation but never checked (M9). Deferral homes (M3, D3) are covered by the skill's record step and are out of scope here. Touches `docs/design.md` (Direction and Measures roles), so it goes to the owner on its own.

**(c) Title**: Shared conversation rules for design-discussion and the orchestrator
**Body**: Part of #370; related #398. If `orchestrator` repeats `design-discussion`'s conversation rules (questions per turn, no dependent questions, plain names, one-liner first on resume, parking conditions, own-words before a conclusion counts), move them to one knowledge file both skills cite. File only once the duplication is shown (the goals-down skill, previously (a), is absorbed into `design-discussion`, so it is no longer a third party).

(a), the goals-down skill, is not filed: absorbed (step 1).
