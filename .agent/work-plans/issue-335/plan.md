# Plan: Workspace design document, phase 3 (rewrite docs/design.md as the current picture)

## Issue

https://github.com/rolker/agent_workspace/issues/335 (phase 3 of 3; phases 1 and 2 are done, the
principles PR merged as b7e8838; open PR #376 holds AGENTS.md follow-ups and should merge first).

## Context

`docs/design.md` is 223 lines of directory tree, registry field detail and script behaviour. Almost
all of that detail already lives, or belongs, next to the code (see "What leaves design.md").
ADR-0017 makes the design document the authority for how the parts fit and says the rewrite
reconciles it with the ADRs; until it lands, existing ADRs stand. The owner has settled what the
document is for: a short "How it works" at the top (H1: agents are strong within one piece of work
and weak across time, so the workspace is a day-to-day harness plus a long view, and the principles
connect them), the documentation layers as roles (Goals, How it works, Principles, Design,
Decisions, Direction, Measures; each project maps each role to a file, section, outside place or
none; this document holds the workspace's own mapping), and the "healthy / right direction" goal
served by the Direction role (G2). The owner writes plain prose and wants text he can edit, not a spec.

## Approach

### Process (how the document gets written)

1. Land after PR #376 merges. Worktree for #335, this plan committed, `review-plan`, owner
   approval. No section is written before approval.
2. **"How it works" first, in the owner's words.** The agent supplies only a list of the facts and
   decisions it must cover (from H1 and the 16 principles' Serves lines), not prose. The owner writes
   or edits the paragraphs; the agent trims nothing without asking. Everything below hangs off it.
3. **Then one section at a time**, in the order of the table below. Per section the agent drafts
   "Now" from code and records only (each line cites a script, ADR or file it was checked against),
   drafts "Target" only from recorded decisions, and turns every gap into an Open Questions row. The
   owner edits; one commit per section (atomic, so a dropped section drops cleanly).
4. **Cheap with/without test**, same shape as the 2026-10-02 Why-line test: before merging, put the
   same five questions (for example "does `onboard-project` register a project?", "where does a
   session started in a project get its skills?", "who decides a merge?") to fresh read-only agents
   given the old file, then the new file; compare correct answers and what each had to open. Ten
   short Sonnet reads. Ask the owner first before launching (standing rule: no silent sub-agents).
5. Verification before the PR: every "Now" line spot-checked against its cited source (Documentation
   Accuracy); grep for project names (private projects stay unnamed; the fork name
   `ros2_agent_workspace` is fine); `make lint`; script tests.

### The new document: sections, line budget, status

**Budget: about 205 lines for the core sections, up to about 225 if the owner accepts the optional candidates (section 10 and section dates), hard cap 240.** Reason: the current file is 223 lines and is mostly tree
and detail; the cap keeps the new one readable in one sitting (about 15 minutes) and short enough
that an agent reading it for one section pays little. The budget is the admission rule made
countable (candidate, research finding 3): a fact is in only if two parts could otherwise choose
incompatibly or a newcomer cannot see it from the code. A part that outgrows about a page (60
lines) gets `docs/design/<part>.md` and a pointer (issue's size rule); none does at first.

How a reader tells decided from proposed, and now from target (no special syntax, plain markdown):

- Every part opens with one line `Status:` taking exactly one of **decided** (an owner decision is
  on record, cited: ADR number or issue/date), **decided, not built**, **proposed** (agent or owner
  suggestion, not decided), or **open** (a question, listed under Open Questions).
- Each part has a `Now` block and, only where it differs, a `Target` block. `Now` states only what
  the code does today and cites where to check it. Nothing proposed appears in `Now`. `Target`
  paragraphs start with "Target:"; each proposal inside starts with "Proposed:" and moves to `Now`
  when built (the change that builds it makes the move, per "A change includes its consequences").
- Research candidates are marked `(candidate)` in the draft so the owner accepts or drops each
  before the PR; marked candidates must be gone from the final text.

| # | Section (stable name) | What goes in | Status | Lines |
|---|---|---|---|---|
| 0 | Header | One-line admission rule (candidate, finding 3); the split "this file = reference, ADRs = rationale and history, `progress.md` = per-issue history" and that the reference updates at merge (candidate, finding 1); the fixed section-name list (see Wire-in) | decided (ADR-0017) | 12 |
| 1 | How it works | Owner's words. Core ideas, day-to-day harness plus long view, principles connect them; README Goals ends with a pointer. Optional one-line tree picture (goals as roots, plans and work as leaves, the bare tree is the as-built design) if the owner wants it | decided (H1) | 20 |
| 2 | Documentation layers | The seven roles; table of where each lives for the workspace (Goals: README `## Goals`; How it works and Design: this file; Principles: `docs/principles.md` and the review guide; Decisions: `docs/decisions/`; Direction: `docs/roadmap.md` (what "healthy" means: no home yet); Measures: none yet). Shows the two gaps honestly. How a project maps its own is Target: proposed, seeded by `discover_governance.sh` types | roles decided; per-project mapping proposed | 20 |
| 3 | Rules that stay true | One table: rule, principle it implements (cited, not restated), enforced by (hook / script / CI / review only / nothing; candidate, findings 4 and 7). About 12 rules, for example worktree for all work, issue first, owner decides merge, no commit to main, progress entries via the script | decided | 24 |
| 4 | Sessions and roots | A session starts in the workspace or in a project root; the user tier supplies the workspace layer to project sessions (ADR-0016, Provisional, so `Status: decided, not proven` until the `/run-issue` acceptance run). Target: the workspace as a registered project (#295) is **open** | decided / open | 16 |
| 5 | Registry and adapters | Registry maps names to roots and types; a 12-verb adapter contract per project type; resolution order in one sentence. Target: `onboard-project` as the one registration path (#332), mixed-flavour projects (#310), project lifecycle register to unregister: **proposed/open**. GitHub is not a project dependency, the workspace uses it for now (owner 2026-10-05) | decided (ADR-0011/0012); rest open | 18 |
| 6 | Worktrees | Two kinds, workspace and project; why (ADR-0002); where they live is a pointer to the guide. Footprint on projects: what a project carries by choice, Target (zero-footprint mode; candidate, finding 9) | decided; footprint proposed | 12 |
| 7 | Review loop and timeline | Phase order, one entry per phase in `progress.md` (the only loop state), fresh-context sub-agents per phase (ADR-0013/0014/0015); which claims code verifies (exit contracts, entry validation, merge gate) versus self-reported (candidate, finding 7); what a finding must contain and reviewer independence (candidate, finding 6; Open Q6); how a new session finds the records for its issue (candidate, finding 8); size bound on records and look-back (candidate, finding 10) | decided; candidates proposed | 24 |
| 8 | Merge gate | The owner decides every merge; the gate checks review currency and CI on the reviewed head; bookkeeping-only commits exempt; enforce by default on workspace PRs (`merge_pr.sh`, `_bookkeeping.sh`) | decided | 10 |
| 9 | Identity | Agents sign work with framework identity, ephemeral per session; pointer to `AI_IDENTITY_STRATEGY.md`; tool-neutral rule and what degrades without the main tool (principle 9 cited) | decided | 8 |
| 10 | Instruction layers (candidate, finding 5) | Only if accepted: the four layers (always loaded, path-scoped, skill, on demand), a size budget for the always-loaded layer (`AGENTS.md` is 431 lines against vendor guidance under 200), this file is not always loaded. Changing `AGENTS.md` is Ask First and is not part of this plan | proposed | 10 |
| 11 | Decision register | One row per ADR (17): one-line decision, current standing (in force / superseded in practice / Provisional) and the design section that carries it. Plan-level decisions that never got an ADR listed with their issue. ADR-0003 already superseded by 0011 | decided | 20 |
| 12 | Open questions | Table: ID, question, owner, what it changes. Seeded from the questions below | open | 12 |
| 13 | Change log | Date, section, one line, issue/PR; appended in the same change that alters a section | decided | 8 |

Section dates (candidate, finding 2, Open Q1): if accepted, each part carries `Checked: <date>`
against the code, refreshed by `/audit-workspace` step 2, which ADR-0017 work already pointed at
this file. Costs about 8 lines.

### What leaves design.md and where it lands

| Current text | Lands in | Action at implementation |
|---|---|---|
| Directory tree (lines 11-66) | nowhere; `ls` and the script table in `AGENTS.md` show it | Delete. Keep only the three roots (workspace, project, user tier) inside section 4 |
| Registry field syntax (`parent=`, `worktrees=`, `role=`, `distro=`, `default_instance=`) and resolution order | `.agent/projects.local.example` header and `_project_registry.sh` header (both already hold it) | Verify, then delete |
| `validate_workspace.py` paragraph | `validate_workspace.py` docstring (already holds it) | Verify, then delete |
| `ros2_colcon` detail (layers, bootstrap URL order, distro rule) | `.agent/project_types/ros2_colcon/adapter.sh` header (already holds it) | Verify, then delete; keep one sentence in section 5 |
| Worktree locations, exclusion and `COLCON_IGNORE` detail | `.agent/WORKTREE_GUIDE.md` (already covers it) | Verify, then delete |
| Stamp-based setup (ADR-0007) | `Makefile` header (already holds it) and ADR-0007 | Delete |
| Build and Test (`project_config.sh` variables) | `AGENTS.md` Build & Test (duplicate) | Delete |
| Multi-agent coordination, lock | `.agent/WORKFORCE_PROTOCOL.md` | Delete; one line in section 7 if needed |
| Identity management | `.agent/AI_IDENTITY_STRATEGY.md` | Compress to section 9 |
| Review loop lifecycle paragraph (script and checkpoint detail) | `.agent/knowledge/review_loop_lifecycle.md` (one-page summary), `run-issue` skill and `dispatch_phase.sh` header | Compress to section 7; add anything missing to the knowledge file first |
| Governance bullets | `AGENTS.md` Boundaries and `docs/principles.md` | Delete (duplicates) |
| Two-shape (legacy `project/` vs registry) history | issue #172 and #265 plan | Reduced to one Target sentence; delete when legacy shape is dropped |

Rule for moves: nothing is deleted before its destination is confirmed to hold the text (open the
destination, quote the matching lines in the PR description); gaps are filled first.

### Wire-in and stable section names

1. Names. Section 0 carries an HTML comment listing the fixed names (How it works, Documentation
   layers, Rules, Sessions and roots, Registry and adapters, Worktrees, Review loop and timeline,
   Merge gate, Identity, Decision register, Open questions, Change log). Headings use exactly those
   words, so the GitHub slugs (`#sessions-and-roots`) are stable. Renaming a heading is a design
   change that updates every citer in the same change.
2. Skills. `review-issue` ("Design picture?" check and comment template), `review-plan` and
   `plan-task` (Design Picture template) change from "which design section" to "name the section by
   its heading from the list in `docs/design.md`", and `review-issue` also names the goal bullet an
   issue serves. Project issues keep the existing "the project's own design document, or say there
   is none" branch.
3. ADR pointers. Each of the ADRs with a design section gets a one-line ADR-0008 addendum "Current
   description: `docs/design.md#<section>`" (cross-reference only, no edit to the decision).
4. Roadmap. Each `docs/roadmap.md` item names the section it moves.
5. Guide. The "Keep one current design" row cites the section list; the ADR-0017 row stays.
6. Test (Test what breaks; gated by Open Q, cheap): `test_design_anchors.sh` checks that each
   listed name exists as a heading and every `design.md#...` citation in skills, knowledge files
   and ADRs resolves. `chmod +x` the new script.

### PR split

PR A: confirm and fill destinations (script headers, knowledge file), nothing deleted yet.
PR B: the new `docs/design.md` and the deletions, section commits kept separate. PR C: wire-in
(skills, ADR addenda, roadmap, guide row, anchor test), `Closes #335`. B and C may merge together if
the owner prefers fewer reviews; review depth is at least Standard (governance files).

## Files to Change

| File | Change |
|------|--------|
| `docs/design.md` | Rewrite per the section table |
| `README.md` | Goals section ends with a pointer to `#how-it-works`; Documentation list label |
| `.agent/projects.local.example`, `.agent/scripts/_project_registry.sh`, `.agent/scripts/validate_workspace.py`, `.agent/project_types/ros2_colcon/adapter.sh`, `.agent/WORKTREE_GUIDE.md`, `.agent/knowledge/review_loop_lifecycle.md` | Fill any gap found when checking the destinations (PR A) |
| `.claude/skills/{review-issue,review-plan,plan-task,audit-workspace}/SKILL.md` | Section-name wording; audit-workspace checks the dates if Open Q1 is accepted |
| `docs/decisions/*.md` (those with a section) | ADR-0008 cross-reference addendum, one line each |
| `docs/roadmap.md` | Items name the design section |
| `.agent/knowledge/principles_review_guide.md` | "Keep one current design" row cites the section list |
| `.agent/scripts/tests/test_design_anchors.sh` (new, `chmod +x`) | Anchor test, if accepted |
| Not touched | `AGENTS.md`, `CLAUDE.md` (Ask First; PR #376 owns the held edits), `docs/principles.md` (Open Q3-Q5 would be a separate change) |

## Prior Art

Not re-researched. Used: `prior-art-comparison-2026-10-08/summary.md` (ten findings, each folded
above as a marked candidate; detail in `comparison-with-se-approaches.md`,
`how-human-processes-fail-with-agents.md`, `what-others-do.md`); the 2026-10-01 notes
`prior-art-alignment-human-teams.md` (ADR practice, Google design docs, arc42 solution strategy),
`prior-art-alignment-agent-frameworks.md` and `prior-art-alignment-agents-evidence.md`;
`oss-doc-survey.md` (vision and design live in README prose, no separate VISION file);
`redesign-fragments.md` section 13 (document kinds; roadmap needs a forcing function);
`zero-footprint-inventory.md`. Taken: reference plus dated records with a merge-time update step
(finding 1, matches ADR-0017); the admission test; the draft-then-merge shape of the world-store
design draft. Held as candidates, not taken: dated sections, enforced-by column, instruction-layer
budget. Rejected for now: a separate VISION file; a document-kind vocabulary from the fork's
planning-document proposal beyond the seven roles the owner chose.

## Design Picture

This plan is the change to the design picture: `docs/design.md` is rewritten whole. It also changes
which design section the planning and review skills cite (the section list above).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | The deliverable. Status marks keep decided, built and proposed apart; section dates (if accepted) show currency |
| Only what's needed | Admission rule and line cap; detail goes next to code; ten research candidates are each owner-accepted, not added by default |
| A change includes its consequences | Moves confirmed before deletion; skills, ADR pointers, roadmap, guide and README updated in PR C |
| Leave a trail; start limits strict | Decision register and change log; each section its own commit |
| Ask about what matters, and show how much | Design questions asked one at a time with what each changes (list below) |
| Verify before claiming | Every "Now" line cites its source and is spot-checked; gaps become open questions, nothing undecided is smoothed into prose |
| Know whether it works | With/without test; section dates; a Measures role mapped honestly as "none yet" |
| Put each thing at the level it applies to | Script detail to script headers; per-project mapping is project-level, the workspace's own mapping is here |
| Leave in a project only what it chose to carry | Footprint is Target, not described as built |
| Look for prior art before building | Prior Art section above |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0017 | Yes | The plan implements it; the rewrite reconciles design and ADRs and records standing in the register |
| 0001 | Yes | No new ADR here; one is written only if the rewrite changes a decision two parts could choose incompatibly |
| 0008 | Yes | ADR pointers are cross-reference addendums only |
| 0016 | Yes | Provisional: shown as "decided, not proven" until the acceptance run |
| 0003 / 0011 | Yes | Workspace stays project-agnostic; no project names |
| 0013 | Yes | Entries via `progress_append.sh` |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Design section names | Skills, ADR addenda, roadmap, guide row, anchor test | Yes (PR C) |
| Detail removed from design.md | Its destination file | Yes (PR A, verified first) |
| Registry or adapter text | `adapter` and registry headers | Yes (PR A) |
| README Goals pointer | README Documentation list | Yes |
| `AGENTS.md` (instruction budget, finding 5) | Framework adapters | No, Ask First |

## Open Questions

Order of asking, each alone (design questions are asked on their own). "R" is the research summary's
numbering; the progress notes list the session-clearing question as q6, the summary has it as 8.

1. **Shape: the status marks (Now / Target, decided / proposed) and the 240-line cap.** Changes the
   whole document; easy to undo before the first section is written, expensive after. Ask first.
2. **R1 and candidate finding 2: a `Checked: <date>` line per section, refreshed by `/audit-workspace`.**
   Changes every section and one skill; easy to drop later, but adds upkeep.
3. **R7: the "enforced by" column in the Rules table.** Shows gaps; needs upkeep; easy to undo.
4. **Decision register scope, and which ADRs the rewrite supersedes (ADR-0016 Provisional).**
   Superseding an ADR is the hardest step to undo; wording of standing per ADR is easy.
5. **Workspace as a registered project (#295) or ADR-0016's interim rule made permanent.** Deferred
   twice. Changes sections 4 and 5 and the next `#265` PR. Hard to undo once built; the document can
   carry it as **open** instead if the owner is not ready.
6. **R2: where a zero-footprint project's design and records live** (workspace repo, a store outside
   both repos, or host-tool memory only). Decides section 6's Target and the work-plans conflict;
   moderate to hard to undo. Can stay open.
7. **`onboard-project` as the only registration path (#332) and the project lifecycle (unregister,
   one project on two machines); mixed-flavour projects (#310).** Shapes section 5 Target; can stay
   open; undo is easy while only in design text.
8. **R6: what a review finding must contain: principle, guide row, or design text only.** If design
   text only, section 7; if a principle, a separate change to `docs/principles.md`. Easy to move.
9. **Candidate sections and the tree picture:** instruction layers (section 10), the tree line in
   section 1, which of findings 6 to 10 enter section 7. Each is an add or drop; cheap either way.
10. **Anchor test (`test_design_anchors.sh`).** Small; protects the section names; easy to remove.
11. **R3: a countable step-back trigger for "Small steps" (a review-round limit).** Changes a
    principle's wording in a separate change, not this document; easy to undo.
12. **R4: "Only what's needed" adds "after recording why it was there".** Principle wording, separate
    change; easy to undo.
13. **R5: where a rule on editing or deleting existing tests belongs.** Principle, guide or
    neither; separate change; easy to undo.
14. **R8: mention session-clearing advice at all?** Conflicts with the standing rule against
    proposing it; lowest stakes. The draft leaves it out unless the owner says otherwise.
15. **Roadmap cadence:** does `docs/roadmap.md` get a stated re-read trigger (Direction role)? Small;
    can be a Target line.

## Estimated Scope

Three PRs (A: destinations; B: the rewrite; C: wire-in), merge-able as two. The writing is paced by
the owner's edits (step 2 first), not by drafting.
