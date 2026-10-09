---
issue: 335
---

# Issue #335 — Workspace design document

## Plan Authored
**Status**: complete
**When**: 2026-10-02 12:00 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `1fa5368`

Three phases: read-only history review of both workspaces, then the principles PR, then a design.md outline.

## Plan Review
**Status**: complete
**When**: 2026-10-02 12:24 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: needs-work

**Issue**: #335 — Workspace design document
**Plan**: `.agent/work-plans/issue-335/plan.md` at `1fa5368`
**Branch**: `feature/issue-335`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | Phase 1 is the largest part and the least specified for evidence quality; plan is 190 lines vs the 30-80 guideline |
| Issue alignment | Needs work | Phase 1 adds a project-repo slice (D) the owner did not ask for; principles are handed to agents too early |
| File targeting | Good | Skills and guide rows right; a few missed spots below |
| Consequences | Needs work | Grep list misses the review-issue/plan-task principle templates, the README label, and the review-depth tier note |
| Principle alignment | Needs work | Self-check covers 8 of 14; "Only what's needed" and "Verify before claiming" weakly applied to Phase 1's five-agent design |
| ADR compliance | Good | 0001, 0008, 0013 handled; 0003 is superseded by 0011 and the table should say so |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Method, step 3]** — Agent E gets the goals and 14 principles alongside the history. Slices A-D should record mechanisms and outcomes without knowing the principles; only the comparison step sees them, and it works from A-D's tables, not raw history. This is the main confirmation-bias control and costs nothing.
2. **[Issue alignment, step 1 third bullet, step 3 slice D]** — Slice D (project-repo results) is not in the owner's direction, which names two workspaces. It is also the weakest evidence (confounded, no counterfactual) and takes the work to named projects and cross-repo gh reads. Drop it by default; offer it as an owner-approved follow-up if A-C leave a specific question.
3. **[Method, step 2]** — Counted / sampled / judged is stated well. Missing: a fixed claim-table format (claim, evidence ref, label, n) so tables are comparable, and a rule that "judged" claims cannot alone justify a principle change. Counted proxies (follow-up fix PRs citing an earlier PR) need a stated detection rule or they become narrative.
3b. **[Design, step 3]** — Pilot one slice first (one repo, one mechanism, e.g. the review loop); host reads the table and spot-checks references; fix the format; then fan out. Cheaper shape: one reading agent per repo (A+B merged, same format), C as rerunnable git/gh counting commands rather than an agent summarising numbers, comparison done by the host in session since the owner decides one item at a time anyway. Two reading agents plus scripts plus host.
4. **[Sources, step 1]** — The fork's local checkout is named only as "local checkout"; I could not find it under /home/roland to depth 6. Record the path (or say it is cloned read-only into the scratchpad) before launch. The repo already holds `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md` and roadmap fork-parity history; agents should start from them (prior art), and the plan should say so.
5. **[Issue alignment]** — The owner's request (what improved quality and efficiency, compared with goals/principles for missing or working-against) is covered. Beyond it: the five-slice structure, slice D, and Open Questions on the orientation principle and G1/G2. Frame the latter two as hypotheses the review may inform, not added scope. The "supported" list is harmless; keep it short.
6. **[Consequences, step 9]** — Missed: (a) `.claude/skills/review-issue/SKILL.md` (~134-176) and `.claude/skills/plan-task/SKILL.md` (~197-201) hold principle-table templates; check for rows naming old principles before deciding they need no edit; (b) `README.md:24` labels `docs/principles.md` "Guiding principles"; (c) `.agent/knowledge/review_depth_classification.md:106` lists `docs/principles.md` as a governance file, so the Phase 2 PR is Deep-tier; state the expected review cost; (d) historical `issue-*/` plans and progress use old names; leave and say so. Verified correct: review-plan 215-218, audit-workspace 36-37, design.md:223. `test_issue_review_entry.sh` 56/58 is fixture text only, so leaving it is right.
7. **[Length]** — 190 lines. Cut: Context paragraph 2 and Estimated Scope (restate the phases); Self-Check to the rows that bite (Verify before claiming, Ask about what matters, Name the rule before bending it, Only what's needed); Phase 3 step 13 to three lines; step 10 to one line; step 9 folded into Files to Change plus the added spots; step 5 Limits folded into step 2. Keep: the question, sources, counted/sampled/judged, claim format, Phase 2 file list with line refs, Ask-First flag, Open Questions. Target about 100 lines; 80 would drop needed Phase 2 detail.
8. **[Project-agnostic]** — The plan names no project (no daddy_camp, project11 or gz4d); `ros2_agent_workspace` is already named in README.md and is fine. Risk is in Phase 2: principle texts and guide rows are copied from the owner's private notes, which may name projects. Add a grep for project names on copied text before commit. Phase 1 reports stay in the untracked scratchpad (as planned).
9. **[ADR table]** — Row "0003 / project-agnostic" should cite 0011 (0003 superseded; the doctrine lives in the review-guide row).

### Summary

The plan does what the owner asked, plus one extra slice, and its agent split invites confirmation bias and plausible narrative. Cheap fixes: hold principles back until the final comparison, pilot one slice, count with rerunnable commands, drop slice D by default. Phase 2 is sound with the added consequences. Length can roughly halve.

### Recommended Actions

- [ ] Withhold goals and principles from the history slices; compare only at the end from their tables
- [ ] Drop slice D or make it an owner-approved follow-up
- [ ] Add a fixed claim-table format and a pilot-slice gate before fan-out
- [ ] Do the counting with rerunnable git/gh commands, not agent summaries
- [ ] Record the fork checkout path and point agents at the existing fork digest
- [ ] Add the review-issue and plan-task templates, README label and Deep-tier note to Phase 2 consequences
- [ ] Add a project-name grep on copied principle texts before commit
- [ ] Trim the plan to about 100 lines

## Plan Authored
**Status**: complete
**When**: 2026-10-02 13:00 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `2f20dd1`

Revision after the plan review: history agents are not given the goals, a pilot slice comes first, counts come from a saved script, the project-repo slice is an open question, phase 2 consequences extended.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-08 09:40 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-335 at `73d59e8`
**Base**: origin/main
**Depth**: Standard (reason: governance files — docs/principles.md, principles_review_guide.md, skill files)
**Must-fix**: 2 | **Suggestions**: 9
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Specialists: static (pre-commit, clean); governance (Sonnet); plan drift (Sonnet); Claude adversarial (Sonnet); cross-model gemini/codex/copilot all EXIT=0.
False positives dropped: Gemini "Design picture? nested under project-only check" (it is under Assess scope); Copilot "failing-first stricter than the principle" (the principle says a test that fails without the fix); Gemini hard-coded README URL (owner's text).

### Findings
- [ ] (must-fix) ADR-0001 row "supersede it, do not edit it" contradicts the ADR-0008 row's permitted status-line/References addendums; add the exception — `.agent/knowledge/principles_review_guide.md:36`
- [ ] (must-fix) plan-task Design Picture step and template name `docs/design.md` unconditionally, but plan-task also runs on project issues whose design lives elsewhere or nowhere (Codex + Gemini) — `.claude/skills/plan-task/SKILL.md:124,211`
- [ ] (suggestion) OPEN HUMAN CALL: "Leave in a project only what it chose to carry" row and README Light-touch bullet describe behaviour the tooling does not have yet (plan-task/progress_append commit work-plans into project worktrees by default); state the interim rule or mark as target — `.agent/knowledge/principles_review_guide.md:27`, `README.md:80`
- [ ] (suggestion) OPEN HUMAN CALL: README rewrite drops Quick Start / Common Commands / Worktree Workflow and adapter links; `make setup` now documented only in docs/design.md (4 reviewers) — `README.md:11-16`
- [ ] (suggestion) review-issue "Design picture?" check has no slot in the comment template or Actions routing; route it as an Action-needed Principle Alignment row (adversarial + Gemini) — `.claude/skills/review-issue/SKILL.md:128-132,154-160`
- [ ] (suggestion) ADR-0001 gets an ADR-0008 status-line note pointing at "Keep one current design" and the guide row, so the ADR and its checklist do not silently disagree — `docs/decisions/0001-adopt-architecture-decision-records.md`
- [ ] (suggestion) code comment cites the removed "workspace-improvements-cascade-to-projects" principle — `.agent/scripts/_resolve_default_branch.sh:28`
- [ ] (suggestion) review-plan "failing-first test" → "a test that fails without the fix" to match the principle; note docs/skill-only changes — `.claude/skills/review-plan/SKILL.md:219`
- [ ] (suggestion) audit-workspace step 1 still flags every principle without a hook, which the revised "Enforce what matters" principle no longer asks for (Codex) — `.claude/skills/audit-workspace/SKILL.md:31-41`
- [ ] (suggestion) "Name the rule before bending it" row: say AGENTS.md Never / Ask-First rules are not bendable by naming them (adversarial) — `.agent/knowledge/principles_review_guide.md:28`
- [ ] (suggestion) bookkeeping before PR: Implementation entry on this timeline; refresh stale plan text (14 principles / six sections / open questions); PR description notes README goals rewrite rides along and lists held AGENTS.md candidates (plan drift) — `.agent/work-plans/issue-335/plan.md:9,145-149`

## Implementation
**Status**: complete
**When**: 2026-10-08 10:05 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `fe8705f`
**Branch**: feature/issue-335 at `4e478d8`

### Summary
Phase 2 of the plan (the principles PR). Phase 1, the history review of both workspaces and their projects, ran 2026-10-02 in the scratchpad (private; results settled with the owner in session) and produced the 16th principle "Know whether it works" and the README "The long view" section. Phase 3 (docs/design.md rewrite) is deferred to its own plan.

### Commits
- 091532c principles.md: 16 settled principles, verbatim from the owner-settled notes
- 2b8e43a review guide: one row per principle; ADR-0001 row revised (owner accepted 2026-10-08)
- 8951d00 plan-task / review-plan / review-issue: design-picture and prior-art checks
- 9bbf75c audit-workspace rows and design.md principle line
- e7d49f6 "Only what's needed" also serves The long view (owner decision D2)
- 0b8c583, 0baae47, fe8c066, fe8705f, and the ADR-0001 pointer: pre-push review round 1 fixes (M1, M2, H3, S1–S6)

### Owner decisions recorded 2026-10-08
- ADR-0001 row accepted as drafted, plus the ADR-0008 addendum exception.
- "Each project says what healthy and the right direction mean" stays at goal level (design-only; Direction role).
- Project-footprint row left as a target; README setup-command removal intended.

### Held (Ask First, not in this PR)
AGENTS.md candidates: fold Documentation Accuracy into "Verify before claiming"; point Quality Standard at docs/principles.md; add "does the design picture change?" to Post-Task Verification. Owed: test guidance into the test-engineering skill.

## Integrated Review
**Status**: complete
**When**: 2026-10-08 11:20 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #375 at `ca53f45`
**Sources**: 7 (Copilot bot R1 @ `e66cf2c`, cross-model PR-mode gemini/codex/copilot @ `e66cf2c` all EXIT=0, Sonnet governance R2, Sonnet adversarial R2, Local Review (Pre-Push) @ `73d59e8`, CI rollup)
**Cross-source confirmations**: 3
**CI**: all-pass (at e66cf2c; re-running on ca53f45)

### Findings
- [x] (cross-confirmed ×4: Codex, Copilot CLI, Copilot bot, adversarial) narrowed ADR trigger is substantive under ADR-0008; needs a superseding ADR, not a status note — owner chose ADR-0017 in this PR; ADR-0001 status is now a pointer; guide gains the 0017 row (ca53f45) — `docs/decisions/0017-design-document-is-the-current-picture.md`
- [x] (cross-confirmed ×2: governance, adversarial) audit-workspace prose allowed a status the table lacked — `Not needed` added, summary counts it as enforced (d7993e2) — `.claude/skills/audit-workspace/SKILL.md`
- [x] (cross-confirmed ×2: adversarial R2, review-plan text) docs-only test exemption lived only in review-plan — added to the guide's Test row (d7993e2) — `.agent/knowledge/principles_review_guide.md`
- [x] (must-fix, Copilot bot) Implementation entry's Branch field said `HEAD`; ADR-0013 needs a SHA — `4e478d8` (d7993e2) — `.agent/work-plans/issue-335/progress.md`
- [x] (suggestion, Codex) review-issue design-picture check re-asked settled decisions — now `OK` with a pointer when the issue records the decision (d7993e2) — `.claude/skills/review-issue/SKILL.md`
- [x] (suggestion, Gemini) comment template scope block gains a Design picture line (d7993e2) — `.claude/skills/review-issue/SKILL.md`
- [x] (suggestion, Copilot bot) "python" → "Python" in README history (d7993e2) — `README.md`
- [x] (suggestion, governance R2, pre-existing) ADR-0016 guide row's unescaped `||` split the row — escaped (d7993e2) — `.agent/knowledge/principles_review_guide.md`
- [ ] (owner decision, left) Never/Ask-First carve-out lives in the guide row, not the principle (H3: guide row only) — `docs/principles.md`
- [ ] (owner decision, left) README setup commands removed on purpose (Copilot CLI, Gemini raised again) — `README.md`
- [ ] (owner decision, left) project-footprint row stays a target until zero-footprint mode exists — `.agent/knowledge/principles_review_guide.md`

### False positives
- Gemini: "Design picture? nested under project-only check" — it sits under "Assess scope" (checked twice).
- Gemini: review-issue and plan-task templates "still list old principles" — both use `...` placeholders.
- Gemini: hard-coded README URL — owner's text.

## Integrated Review
**Status**: complete
**When**: 2026-10-08 13:45 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #375 at `61f8d5b`
**Sources**: 2 (Copilot bot R2 @ `9641604`, CI rollup)
**Cross-source confirmations**: 0
**CI**: all-pass (at 9641604; re-running on 61f8d5b)

### Findings
- [x] (must-fix, Copilot bot) ADR-0017 made the known-stale docs/design.md authoritative before phase 3 rewrites it — transition bullet now says the current file does not override an accepted ADR until the rewrite lands; reviewers read the newer of the two (61f8d5b) — `docs/decisions/0017-design-document-is-the-current-picture.md`
- [x] (must-fix, Copilot bot) audit-workspace step 2 flagged any accepted ADR whose implementation drifted, which ADR-0017 now expects — step checks status/supersession links and that design.md records current behaviour; drift is "superseded in practice", not an error (61f8d5b) — `.claude/skills/audit-workspace/SKILL.md`

### False positives
- none

## Integrated Review
**Status**: complete
**When**: 2026-10-08 15:40 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #376 at `b8a837a`
**Sources**: 2 (Copilot bot @ `b8a837a` — approval recommended, 0 findings; CI rollup)
**Cross-source confirmations**: 0
**CI**: all-pass

### Findings
- [ ] No issues found. LGTM. (Four owner-approved AGENTS.md edits + hook section rename; test_session_start_layer 42/42.)

### False positives
- none

## Plan Authored
**Status**: complete
**When**: 2026-10-08 16:05 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `0f604b7`

### Summary
Phase-3 plan (rewrite docs/design.md as the current picture) committed as the issue's plan.md, replacing the three-phase outline. Drafted from the prior-art comparison (design-doc-sources/prior-art-comparison-2026-10-08) and the owner's 2026-10-05 decisions (How it works at the top; documentation layers as roles; Direction role serves the healthy/direction goal). Fifteen open questions ordered for the owner. Next: review-plan, then owner decisions one at a time.

## Plan Review
**Status**: complete
**When**: 2026-10-09 08:25 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: needs-work

**Issue**: #335 — Workspace design document
**Plan**: `.agent/work-plans/issue-335/plan.md` at `0f604b7`
**Branch**: `feature/issue-335`

Persisted record of a review run without persistence. The reviewer was a read-only Sonnet sub-agent on 2026-10-08, launched from the Fable host session; this entry was written afterwards from its returned findings. The reviewer's own per-dimension table was not kept, so the table below is derived from the findings (a dimension with no finding says "none raised").

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | Line rule and the 17-row register cannot both hold (F8) |
| Issue alignment | Needs work | Section order and status vocabulary do not match the owner's settled shape (F3, F7) |
| File targeting | Needs work | "Already lives" claims wrong for three destinations (F1) |
| Consequences | Needs work | Guide row, roadmap stale copy, ADR pointer limits missed (F2, F4, F5) |
| Principle alignment | Needs work | Self-check lacks three principles that bite (S6) |
| ADR compliance | Needs work | Addenda exceed ADR-0008; ADR-0017 link broken (F5) |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[File targeting]** (must-fix, F1) — three "already lives" claims are wrong. Resolution order lives in the `.agent/scripts/adapter` header, not in the registry headers. The workspace lock is not in `.agent/WORKFORCE_PROTOCOL.md` (its section 3 is GitHub-issue task locking). The review-loop lifecycle file lacks ADR-0014's exit contract and `--check-exit`. Check each against the real file and fill or drop.
2. **[Consequences]** (must-fix, F2) — `.agent/knowledge/principles_review_guide.md` Consequences Map row "Work-plan directory convention" cites the design.md directory tree. The plan deletes the tree but never updates that row.
3. **[Approach]** (must-fix, F3) — "How it works" must be the first H1-level section of the new design.md. Drop the HTML-comment list of section names. Choose one heading, "Rules" or "Rules that stay true", and say why.
4. **[Consequences]** (must-fix, F4) — roadmap wire-in applies only to open or planned items. The roadmap's "Cross-cutting Decisions" section is a stale second copy of the design; reconcile it with design.md or mark it as history.
5. **[ADR compliance]** (must-fix, F5) — one-line "Current description" addenda pointing at design.md exceed what ADR-0008 permits. Register only, or add a scope note. ADR-0017's link to ADR-0008 uses a wrong filename (`...-in-accepted-adrs.md`; the file is `0008-permit-cross-reference-addendums-in-adrs.md`); fix it.
6. **[Plan currency]** (must-fix, F6) — merge main, then update the plan for the merged state (PR #376 in, AGENTS.md 442 lines).
7. **[Approach]** (must-fix, F7) — Status vocabulary needs a "decided, not proven" value (ADR-0016 is Provisional).
8. **[Scope]** (must-fix, F8) — the line-counting rule plus the decision register (17 rows) cannot fit in the 20 lines allotted; fix the arithmetic or the rule.
9. **[File targeting]** (suggestion, S1) — move the anchor test into PR B so section names and their checker land together.
10. **[Approach]** (suggestion, S2) — write `$WS_ROOT/docs/design.md` in skills that run in both scopes.
11. **[Scope]** (suggestion, S3) — rules section keeps only rules with an enforcement fact AGENTS.md lacks.
12. **[Approach]** (suggestion, S4) — regroup the open questions; drop Q14 (session-clearing advice).
13. **[File targeting]** (suggestion, S5) — synthetic names in the `_project_registry.sh` header and WORKTREE_GUIDE belong in PR A.
14. **[Principle alignment]** (suggestion, S6) — add self-check rows for "Small steps", "Test what breaks", "Enforce what matters".
15. **[Approach]** (suggestion, S7) — the decision register gets a "re-examined / not yet" marker and a Purpose line.
16. **[Consequences]** (suggestion, S8) — the README goals heading is `## Workspace goals`; verify and use the real heading.

### Summary

The approach is sound and matches the owner's shape, but several destination claims are false, a consequences row and the roadmap's stale copy are missed, the ADR pointers go past ADR-0008, and the line budget does not add up. Revise before the owner reviews it.

### Recommended Actions

- [ ] Correct the three "already lives" claims against the files (F1)
- [ ] Add the review-guide Consequences row and the roadmap reconciliation (F2, F4)
- [ ] Put "How it works" first; pick one rules heading (F3)
- [ ] Limit ADR changes to what ADR-0008 allows; fix the ADR-0017 link (F5)
- [ ] Update for the merged state (F6)
- [ ] Add "decided, not proven"; resolve the line-count arithmetic (F7, F8)
- [ ] Apply suggestions S1–S8 or say why not

## Plan Authored
**Status**: complete
**When**: 2026-10-09 09:10 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `aec3cbd`

Revision 2 of the phase-3 plan, answering the round-1 Plan Review (`6f8c643`, needs-work) and the owner's 2026-10-08 decision on document shape (five Status values, Now/Target, no hard line cap). Main merged (PR #376 in). The plan's closing section lists what changed per review item.

## Plan Review
**Status**: complete
**When**: 2026-10-09 08:30 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: needs-work

**Issue**: #335 — Workspace design document
**Plan**: `.agent/work-plans/issue-335/plan.md` at `aec3cbd`
**Branch**: `feature/issue-335`

Round 2. Revision 2 of the plan (336 lines), read against the files in the worktree at 34ad41e. All eight round-1 must-fix items and all eight suggestions are resolved in the plan text, not only in its change log. The "already lives" claims were each re-opened: the `adapter` header, `projects.local.example`, `validate_workspace.py` docstring, `ros2_colcon/adapter.sh` header, Makefile header, `WORKTREE_GUIDE.md`, `lock.sh`/`unlock.sh`/`dashboard.sh`, `WORKFORCE_PROTOCOL.md`, `review_loop_lifecycle.md`, `dispatch_phase.sh` header, ADR-0008/0016/0017, README, roadmap. Two new must-fix items and a few small false facts remain.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | No line cap per owner Q1; three PRs; the 17-row register is no longer squeezed |
| Issue alignment | Good | Issue scope item 3 (one-line ADR pointers) is dropped for ADR-0008 reasons and asked as B1, but the plan never says it departs from the issue text (S-N3) |
| File targeting | Needs work | PR A real-name sweep is described as three files; more files carry real names (N3) |
| Consequences | Needs work | Anchor test does not cover the citation forms the plan itself creates (N2) |
| Principle alignment | Needs work | "Test what breaks" / "Enforce what matters": the test has no case that fails (N2) |
| ADR compliance | Good | Register only; link fix is within ADR-0008 "Permitted"; ADR-0016 as `decided, not proven` is right |
| ROS conventions | N/A | Workspace plan |

### Round-1 items

All resolved: F1 (plan.md 118-126), F2 (161-162, Files to Change), F3 (63-69, "Why Rules"), F4 (Wire-in 4), F5 (Wire-in 3, ADR-0017 line 27 link fix in PR A), F6 (main merged at 306938a; #375 `b7e8838`, #376 `ea0df4a`, AGENTS.md 442 lines all match git and `wc -l`), F7 (five-value Status table), F8 (cap removed, 60-line prompt, line count in change log). S1 to S8 applied. Verified true: resolution order is in the `adapter` header; the workspace lock is documented nowhere (`lock.sh` has no header, `dashboard.sh` line 196 is the only reader, `WORKFORCE_PROTOCOL.md` section 3 is issue-based task locking); the lifecycle file cites ADR-0014 once (line 5) and never names `--check-exit` or ADR-0015; the Makefile header lists three stamps and `design.md` two; README heading is `## Workspace goals` (line 26); ADR-0003 is superseded by ADR-0011; `no-commit-to-branch`, `check-commit-identity`, `verify-issue-branch` exist in `.pre-commit-config.yaml`; all three both-scope skills have `session_scope: both` and the `$WS_ROOT` idiom.

### Findings

1. **[Approach]** (must-fix, N1) — The Status key says each part opens with a `Status:` line "taking exactly one of five values", but the section table gives compound statuses: row 3 "roles decided; per-project mapping proposed", row 5 "decided, not proven; Target open", row 6 "decided (ADR-0011/0012); rest proposed or open", row 7 "decided; footprint proposed", row 8 "decided; candidates proposed". Under the key as written none of these can be written. Decide whether Status attaches to each block (Now and Target each carry one) or per part, and make the key and the table agree. This is the control the owner chose in Q1, so it has to be consistent before sections are drafted.
2. **[Consequences / Test what breaks]** (must-fix, N2) — `test_design_anchors.sh` is specified to check "every `design.md#...` citation in skills, knowledge files, the roadmap and the guide". Today there are zero `design.md#` citations in the repo (grep), the skill edits in PR C cite sections "by its heading" in prose (Wire-in 2), and the README pointer `docs/design.md#how-it-works` is outside the listed scope. So the test passes vacuously and cannot catch a rename of the sections the plan actually cites. Fix: fix a citation form (a link with an anchor) for skills, README and roadmap; include design.md's own cross-references and the register's "section that carries it" column; and give the test a negative fixture (a deliberately broken anchor must fail), so it is shown to fail when the thing breaks.
3. **[File targeting]** (should-fix, N3) — S5 says real project names appear "in three files". Also: `Makefile` line 80 (`make build PROJECT=gz4d`, user-visible help), `.agent/knowledge/principles_review_guide.md` line 51 (ADR-0016 row names `gz4d`), `ros2_colcon/adapter.sh` line 835 and `merge_pr.sh` line 497 (comments naming `p11-jazzy`/`p11`). ADR-0016 and test fixtures are history or fixtures. Either widen PR A to the Makefile line and the guide row, or state the boundary ("only the examples design.md points at"). The word "checked" in the S5 change-log row overstates what was checked.
4. **[Open questions]** (suggestion) — B3 (keep the anchor test) is settled by "Test what breaks"; drop it or turn it into a statement. D1 to D4 are wording changes to principles and guide, "not this document"; they belong on their own issue or in a note, not in the list the owner must answer for #335. A1 asks whether Status applies to "every part"; the plan text already says every part and Q1 decided the marking, so reduce A1 to Now/Target only.
5. **[Issue alignment]** (suggestion) — Issue scope item 3 says "existing ADRs get a one-line pointer to their design section". The plan departs (register only) with good reason (ADR-0008, ADR-0017 "history"), but only B1 mentions it. Say in Wire-in 3 that this departs from the issue text, and that the issue body is updated or the departure recorded on the issue. The issue also lists a "Purpose" part pointing at README goals and `docs/principles.md`; the table has no row that carries it (How it works and the documentation-layers row may, but say so).
6. **[Accuracy]** (suggestion, small) — "Directory tree (lines 11-66)": the tree is lines 11 to 58; "Project Repository Model" starts at line 60 and lines 60-66 are its opening on the 12-verb contract. `projects.local.example` "lines 62-67": the resolution text runs 62 to 69 (the default_instance sentence is 67-69).
7. **[Scope]** (suggestion) — Register column "Re-examined: `yes` with the date when the rewrite checked the decision against the code" implies 17 checks against code; Estimated Scope does not size that. Say which ADRs are checked in PR B and that the rest are `not yet` (the issue allows "re-examined or 'not yet'").
8. **[Consequences]** (suggestion) — The "System design" label for `docs/design.md` also appears in `AGENT_ONBOARDING.md` line 91 (`AGENTS.md` and `CLAUDE.md` are Ask First). The plan changes the label in README only; say whether the others stay.

### Summary

Revision 2 resolves every round-1 item in the plan text, and the previously false "already lives" claims are now correct against the files. Two things remain to fix before the owner reads it: the Status key and the section table disagree, and the anchor test as specified cannot fail. A small number of line references and the "three files" claim are off. No owner question is missing that the plan can't answer from files, other than the ones in finding 4.

### Recommended Actions

- [ ] Make the Status key and the section table agree (finding 1)
- [ ] Specify the citation form, widen the anchor test scope, add a failing fixture (finding 2)
- [ ] Widen PR A's name sweep or state its boundary (finding 3)
- [ ] Trim B3, D1 to D4 and A1 from the owner list (finding 4)
- [ ] Record the departure from issue scope item 3 (finding 5)
- [ ] Correct line ranges; size the register check; decide the label question (findings 6 to 8)

## Plan Authored
**Status**: complete
**When**: 2026-10-09 08:34 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `7a91301`

Revision 3 of the phase-3 plan, answering the round-2 Plan Review (`9cfd1fe`, needs-work): Status is now per block so the key and section table agree, the anchor test is re-specified with one citation form and a negative fixture, and the suggestions are applied (real-name sweep widened, owner list trimmed, issue departure stated, register check sized, onboarding label). The plan's closing section lists what changed per item.

## Plan Review
**Status**: complete
**When**: 2026-10-09 08:38 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: needs-work

**Issue**: #335 — Workspace design document
**Plan**: `.agent/work-plans/issue-335/plan.md` at `7a91301`
**Branch**: `feature/issue-335`

Round 3. Revision 3 of the plan (418 lines), read end to end against the worktree at 955c589. The owner's Q1 decision, the three reviser choices awaiting the owner (label wording, `## Purpose` row, anchor targets) and the A/B/C questions were not re-opened. All nine round-2 items are resolved in the plan text. One new must-fix remains: the planned anchor test collides with the existing `validate-script-tests` hook scope and its guard suite, and the plan does not mention either.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | No cap; three PRs; 17-row register sized (9 re-examined, 8 not yet) |
| Issue alignment | Good | Departure from issue scope item 3 stated in Issue and Wire-in 3; Purpose has its own row (3) |
| File targeting | Needs work | PR B's anchor test needs `.pre-commit-config.yaml` and `test_script_tests_hook_scope.sh` changes that are not listed (finding 1) |
| Consequences | Needs work | Same gap; also the "System design" label in `AGENT_ONBOARDING.md` (finding 4) |
| Principle alignment | Needs work | "Test what breaks": the anchor test would not run on a docs-only commit that renames a heading (finding 1) |
| ADR compliance | Good | Register only; ADR-0017 link fix is within ADR-0008 "Permitted"; ADR-0016 as `decided, not proven` matches its Status |
| ROS conventions | N/A | Workspace plan |

### Round-2 items

- N1 (Status key vs table): resolved. Status is per block; the Now and Target columns each carry one of the five values. Every table cell is a single value, with parenthetical citations only. Small residue in finding 5.
- N2 (anchor test cannot fail): resolved in the spec (one citation form, widened scope, negative fixture, register-anchor count against the 17 files in `docs/decisions/`). New gaps are findings 1 to 3.
- N3 (real names): resolved. The Makefile line 80 and the guide line 51 are in PR A; the boundary is stated. Checked: `gz4d`/`p11`/`project11` appear outside tests, ADRs, roadmap and work-plans only in the files PR A lists plus `ros2_colcon/adapter.sh` line 835 and `merge_pr.sh` line 497, which the boundary keeps.
- Round-2 finding 4 (B3, D1 to D4, A1): resolved (B3 dropped; follow-up subsection; A1 cut to the Now label).
- Finding 5 (departure from item 3; Purpose row): resolved (Issue section, Wire-in 3, row 3).
- Finding 6 (line ranges): resolved. `docs/design.md` Directory Structure is lines 11 to 58 and Project Repository Model starts at 60; `.agent/projects.local.example` resolution text is lines 62 to 69.
- Finding 7 (register sizing): resolved in the register row and Estimated Scope; see finding 6 for the one ADR that does not match.
- Finding 8 (label elsewhere): resolved, see finding 4.

Verified true this round: every line reference in Files to Change and Wire-in (README 22 and 26, `AGENT_ONBOARDING.md` 91, `AGENTS.md` 436, `CLAUDE.md` 36, guide lines 51 and 71, Makefile 80, WORKTREE_GUIDE 72 and 181, `_project_registry.sh` 11 to 14, `projects.local.example` 52 and 72 to 76, ADR-0017 line 27, roadmap Cross-cutting at 405 with Design History at 484); the 12 adapter verbs; `lock.sh` has no header and only `dashboard.sh` line 196 reads the lock file; WORKFORCE_PROTOCOL section 3 is task locking; `--check-exit` results OK/PARTIAL/FAILED/MISSING; ADR-0003 superseded by 0011, ADR-0016 Provisional; commits `b7e8838` and `ea0df4a` exist; `AGENTS.md` is 442 lines; 16 principles, and every name in the self-check exists in `docs/principles.md`; `docs/decisions/` holds exactly 17 files.

### Findings

1. **[File targeting / Consequences / Test what breaks]** (must-fix) — The anchor test reads the real tree (`docs/design.md`, `README.md`, `docs/roadmap.md`). The `validate-script-tests` hook in `.pre-commit-config.yaml` has `files: ^(\.agent/|\.claude/|AGENTS\.md$|Makefile$|\.pre-commit-config\.yaml$|\.github/PULL_REQUEST_TEMPLATE)`, so a commit that only renames a heading in `docs/design.md` (or edits README or the roadmap) does not run the suite locally; only `make lint` (`pre-commit run --all-files`, the CI lint job) would. The existing guard `.agent/scripts/tests/test_script_tests_hook_scope.sh` (issue #354) makes a suite that derives a real root declare its out-of-tree read prefixes in `ROOT_READERS`, each of which must match the hook regex; and it asserts at lines 454 and 455 that `README.md` and `docs/roadmap.md` are NOT covered. So `test_design_anchors.sh` as planned fails the guard whichever way it declares: prefixes `docs/design.md`, `README.md`, `docs/roadmap.md` are uncovered, and widening the regex breaks the two negative assertions. Neither file is in Files to Change or the Consequences table. Add both to PR B and state the choice: widen the hook regex to those three paths and amend the two assertions (reverses part of #354's scoping), or accept CI-only coverage and say so (an empty `ROOT_READERS` entry is meant for sandbox-only or git-ignored reads, so it does not fit). The Principles Self-Check row "Test what breaks" and Wire-in 1 ("the anchor test catches a miss") should say where it runs.
2. **[Approach]** (suggestion) — "every `(#...)` link in design.md" will match issue references; the plan's own text has `(#295)`, `(#332)`, `(#310)`. Specify the form as a Markdown link, `](#<slug>)` with a slug that is not all digits.
3. **[Approach]** (suggestion) — Wire-in 2 tells the skills to write the literal `docs/design.md#<slug>`. `.claude/skills/*/SKILL.md` is in the test scope, so the checker would flag `<slug>` as a broken anchor after PR C. Exclude placeholders (`#<`) in the regex or reword the skill text. Also say where the checker lives (a function in the test file or a separate script; none is listed in Files to Change).
4. **[Consequences]** (suggestion) — `.agent/AGENT_ONBOARDING.md` is the "Other" framework adapter in the `AGENTS.md` adapter table, and the plan keeps `AGENTS.md` and `CLAUDE.md` out as Ask First while editing the label there in PR C. Either treat it like the other two (add it to the follow-up) or note that the owner's plan approval covers it.
5. **[Approach]** (suggestion, small) — Row 6 Target is `open (#295)`, but the rule above says a question goes to Open questions "not into a block that claims a status". Say that an `open` block holds only a pointer. Row 5 Now is `decided` while its enforced-by column awaits A3; fine if the column is a separate Target-free note, worth one clause.
6. **[Register]** (suggestion) — The Re-examined split is 9 yes / 8 not yet. Eight of the nine match a section row that cites the ADR (0002 Worktrees; 0011/0012 Registry; 0013/0014/0015 Review loop; 0016 Sessions; 0017 The design). ADR-0003 is cited by no section row (Registry cites only 0011/0012). Add it to Registry ("superseded by ADR-0011") or move it to `not yet`. Conversely the Rules section's enforced-by column is ADR-0004/0005 territory, both marked `not yet`; one line saying why is enough.
7. **[Wire-in 4]** (suggestion) — "Rows whose status is planned, in progress or deferred name the design section they would change": `docs/roadmap.md` has 27 `planned`, 4 `in progress`, 3 `deferred` cells, many in "To Consider". Limit it to rows that would change the design picture, or the PR C size is unbounded.
8. **[Consequences]** (suggestion, small) — `.claude/skills/brainstorm/SKILL.md` line 34 describes `docs/design.md` as "system design and layering constraints"; one-line label touch in PR C. `discover_governance.sh`, `validate.yml` (file-exists check) and `PULL_REQUEST_TEMPLATE.md` need no change.

### Summary

Revision 3 closes every round-2 item and the factual claims I re-opened are true. One consequence is missing: the anchor test cannot be added under the current hook scope and its guard suite without a decision the plan does not state, and without it the test does not run on the very commits it exists for. Fix finding 1 (add two files and the choice); the suggestions can be taken or declined.

### Recommended Actions

- [ ] Add `.pre-commit-config.yaml` and `test_script_tests_hook_scope.sh` to PR B and state the hook-scope choice (finding 1)
- [ ] Define the in-file link regex so issue references do not match; handle `<slug>` placeholders (findings 2, 3)
- [ ] Decide the `AGENT_ONBOARDING.md` Ask First question (finding 4)
- [ ] Apply or decline suggestions 5 to 8

## Plan Authored
**Status**: complete
**When**: 2026-10-09 08:42 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `81c2119`

Revision 4 of the phase-3 plan, answering the round-3 Plan Review (`e3c3eac`, needs-work): the anchor check gets its own cheap pre-commit hook and a grep-level checker script so it runs on docs-only commits without widening the script-tests hook (#354 scoping kept), and its suite tests the checker with fixtures only. Suggestions applied: in-file link form excludes issue refs, placeholders ignored, onboarding label covered by plan approval, open-block pointer rule, ADR-0003 cited by Registry, roadmap rows limited to design-changing ones, brainstorm label. The plan's closing section lists what changed per item.

## Plan Review
**Status**: complete
**When**: 2026-10-09 08:45 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: needs-work

**Issue**: #335 — Workspace design document
**Plan**: `.agent/work-plans/issue-335/plan.md` at `81c2119`
**Branch**: `feature/issue-335`

Round 4. Revision 4 of the plan (496 lines), read end to end against the worktree at 321e49a. Q1, the A/B/C owner questions (including B4), the follow-up subsection and the three reviser choices were not re-opened. All eight round-3 items are resolved in the plan text and the new hook design is sound against `.pre-commit-config.yaml`, the #354 guard and CI. One new must-fix: the commit order the plan prescribes cannot pass its own checker.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three PRs; checker, hook and suite are small additions |
| Issue alignment | Good | Departure from scope item 3 stated; Purpose row present |
| File targeting | Good | Files to Change now lists the checker, hook and suite; guard file correctly excluded |
| Consequences | Good | Hook, label and roadmap rows present |
| Principle alignment | Needs work | "Test what breaks": the checker runs locally on the right commits, but the order of commits (finding 1) makes it fail by design |
| ADR compliance | Good | ADR-0005 layering (CI enforcement, pre-commit local feedback) matches the plan's wording; ADR-0008 link fix permitted |
| ROS conventions | N/A | Workspace plan |

### Round-3 items

- Finding 1 (must-fix, hook scope): resolved. A separate local hook `check-design-anchors` placed before `validate-script-tests` leaves that hook's block unchanged: the guard's awk (`/- id: validate-script-tests/` to the next `- id:`) reads only that block, so its `files:` regex, always_run check and the negative assertions at lines 454 and 455 (README.md, docs/roadmap.md) stay true. `test_design_anchors.sh` under `.agent/scripts/tests/` is covered by the existing `files:` (`^(\.agent/|...)`). The guard's `IDIOM_REGEX` needs `../../` (repeated slash), `rev-parse --show-toplevel/--show-cdup` or three nested dirname; a single `$SCRIPT_DIR/../check_design_anchors.sh` matches none, so no ROOT_READERS entry is needed. `.github/workflows/validate.yml` job `Lint (pre-commit)` runs `make lint` = `pre-commit run --all-files`, with `SKIP` listing only the four identity/branch hooks, so the new hook runs in CI.
- Findings 2 and 3 (link form, placeholder): resolved in Wire-in 6; the `[a-z0-9][a-z0-9-]*` pattern does not match `<section>`, and `(#295)`/`[x](#12)` are excluded by form. Checker home named. Grep confirms no `design.md#` citation exists today.
- Finding 4 (`AGENT_ONBOARDING.md`): resolved. `AGENTS.md` line 12 is the "Other" row naming it; plan approval covers the one-line edit.
- Finding 5 (`open` blocks, row 5): resolved.
- Finding 6 (ADR-0003): resolved. Row 7 cites it; 0004/0005 `not yet` reasoned.
- Finding 7 (roadmap bound): resolved. Recounted: 27 planned, 4 in progress, 3 deferred.
- Finding 8 (brainstorm label): resolved. `.claude/skills/brainstorm/SKILL.md` line 34 reads "system design and layering constraints".

Verified true: README lines 22 and 26; `AGENT_ONBOARDING.md` 91; `AGENTS.md` 436 and 442 lines; `CLAUDE.md` 36; guide lines 51 and 71; Makefile 80; WORKTREE_GUIDE 72 and 181; `_project_registry.sh` 11; `projects.local.example` 52 and 72; ADR-0017 line 27 link names `...-in-accepted-adrs.md` while the file is `0008-permit-cross-reference-addendums-in-adrs.md`; `docs/decisions/` holds 17 files; roadmap Cross-cutting at 405, Design History at 484. No false claim found.

### Findings

1. **[Approach / Test what breaks]** (must-fix) — PR B says "the checker and hook land first, so each later section commit is checked" (PR split), but Wire-in 6 makes the checker fail "when design.md holds no in-file anchor links at all" and when the register has fewer anchored rows than the 17 files in `docs/decisions/`. Today `docs/design.md` has 0 `](#` links and no register. So the first PR B commit (the hook, whose `files:` includes `.pre-commit-config.yaml`) fails its own hook, and so does every section commit until the Decision register (table row 13, near the end of the document order) lands. CI `make lint` on the pushed feature branch fails the same way. The implementer must either `SKIP` the hook (the plan never says so) or reorder. Pick one and say it: land the checker, hook and suite with or after the register commit (sections before it are then unchecked, say so), or make the two vacuity guards apply only once design.md has the register heading.
2. **[Approach]** (suggestion) — "the Decision register" is not defined for the checker. Say how it finds the rows (for example table rows containing `](#`, counted against `docs/decisions/*.md`), or the count test cannot be written unambiguously.
3. **[Approach]** (suggestion, small) — the citation pattern `[a-z0-9][a-z0-9-]*` silently ignores a wrongly cased citation such as `design.md#How-it-works` (the capital never matches), so a mistyped anchor passes. A one-line fixture or a case-insensitive match that then fails on lookup closes it.
4. **[Scope of check]** (suggestion, small) — the checker's scope omits `AGENTS.md`, `CLAUDE.md`, `docs/principles.md` and `docs/decisions/`; fine today (none cite an anchor), but the follow-up label change to `AGENTS.md`/`CLAUDE.md` could later add one unchecked. One clause in the follow-up list is enough.

### Summary

The round-3 fix is correct and cheap: the hook is a separate, tree-reading check that does not touch the #354 guard, and CI runs it. The remaining defect is ordering: as written, the checker's anti-vacuity guards make the first commits of PR B fail. One sentence choosing the commit order fixes it; then the plan is ready for the owner.

### Recommended Actions

- [ ] State the commit order or guard timing so no PR B commit fails the checker before the register exists (finding 1)
- [ ] Define how the checker finds the register rows (finding 2)
- [ ] Apply or decline suggestions 3 and 4

## Plan Authored
**Status**: complete
**When**: 2026-10-09 08:47 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `e22d500`

Revision 5 of the phase-3 plan, answering the round-4 Plan Review (`ffa20fe`, needs-work): the anchor checker's two anti-vacuity guards now apply only once a `decision-register` heading exists in design.md, so the checker, hook and suite land first without failing; the PR B commit order is stated (checker and hook, section commits, register). Suggestions applied: register rows defined, wrongly cased citations flagged as malformed anchors, checker-scope widening added to the follow-up list. The plan's closing section lists what changed per item.

## Plan Authored
**Status**: complete
**When**: 2026-10-09 09:11 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `acd2cc3`

Revision 6 of the phase-3 plan, applying the owner's four decisions of 2026-10-09: the `check-design-anchors` hook is approved and also watches `docs/decisions/` (B4 decided); the "System design" label stays everywhere, so all label edits and Wire-in 7 are gone; the Purpose row and the `#how-it-works` / `#the-design` anchors are accepted; a last `## Glossary` section is added, with a new question C6 (which terms go in) to settle with the owner before PR B writes it. The plan's closing section lists what changed per item.

## Plan Review
**Status**: complete
**When**: 2026-10-09 09:13 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: ready

**Issue**: #335 — Workspace design document
**Plan**: `.agent/work-plans/issue-335/plan.md` at `acd2cc3`
**Branch**: `feature/issue-335`

Round 5. Revision 6 of the plan (554 lines), read end to end against the worktree at a96973c. Q1, the owner decisions of 2026-10-09 (hook with `docs/decisions/` in scope, "System design" label kept, Purpose row and the two anchors, Glossary section), C6 and the other owner questions, and the `Rules` heading were not re-opened. All four round-4 items are resolved in the plan text and revision 6's edits leave no dangling reference that would mislead the implementer. No must-fix. Two small suggestions.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three PRs; glossary adds a section commit, not a new component |
| Issue alignment | Good | Departure from scope item 3 stated; Purpose row and Glossary present |
| File targeting | Good | Files to Change lists checker, hook (eight paths), suite, guide row, glossary |
| Consequences | Good | New-ADR-file and glossary rows added; label rows correctly gone |
| Principle alignment | Good | "Test what breaks" and "Enforce what matters" now backed by a commit order that passes its own checker |
| ADR compliance | Good | 0005 layering, 0008 link-fix-only, 0016 `decided, not proven` unchanged |
| ROS conventions | N/A | Workspace plan |

### Round-4 items

- Finding 1 (must-fix, commit order): resolved. Wire-in 6 keys both anti-vacuity guards on a heading with slug `decision-register`; without it only the resolve check runs. PR B states the order (1) checker, hook and suite, (2) section commits, (3) register, (4) glossary. Walked through against the current tree: commit 1 passes (no `docs/design.md#` citation exists today in README, onboarding, skills, knowledge files or roadmap; current design.md has no `](#` link and no register heading); section commits pass while their links resolve; the register commit turns on guards (a) and (b) and needs 17 anchored rows, matching the 17 files in `docs/decisions/`; a broken or wrongly cased anchor fails the resolve check at every stage. Fixtures (e), (f), (g) cover before, after and the new-ADR-file case.
- Finding 2 (register-row definition): resolved. Lines beginning `|` between the register heading and the next heading of equal or higher level that contain `](#`, counted against `ls docs/decisions/*.md`.
- Finding 3 (malformed anchor): resolved. A fragment run of `[A-Za-z0-9_-]` that does not match `[a-z0-9][a-z0-9-]*` exits 1 as malformed; an empty run (the `#<section>` placeholder) is ignored; fixture (d) covers `#How-it-works`.
- Finding 4 (follow-up line): resolved, and correctly narrowed in revision 6 now that `docs/decisions/` is in the hook's scope.

### Revision 6 cross-reference check

- No reference to the removed Wire-in 7 remains outside the historical change logs for revisions 3 and 4, which record what those revisions said. Wire-in 1 to 6 are cited consistently (rows 16, Wire-in 1, 2).
- "Eight paths" is consistent in Wire-in 6, Files to Change, Consequences and the suite note; counted: design.md, README.md, roadmap.md, AGENT_ONBOARDING.md, docs/decisions/, .agent/knowledge/, .claude/skills/, .pre-commit-config.yaml. "Seven" survives only in "seven roles" (correct) and the revision 4 log (history).
- The "System design" label rows are gone from Consequences and Files to Change; the "Not touched" row lists the five label sites, and all five were confirmed (README.md 22, AGENT_ONBOARDING.md 91, brainstorm SKILL.md 34 reads "system design", AGENTS.md 436, CLAUDE.md 36).
- Facts re-verified against the files: plan 554 lines, AGENTS.md 442, current design.md 223, 17 ADR files, ADR-0017 line 27 links `...-accepted-adrs.md` while the file is `0008-permit-cross-reference-addendums-in-adrs.md`, test_script_tests_hook_scope.sh lines 454 and 455 are the README.md and docs/roadmap.md not-covered assertions, `validate-script-tests` block as described, guide lines 51 and 71, Makefile line 80, README `## Workspace goals` at line 26.

### Findings

1. **[File targeting] Suggestion** — Guard (b) needs 17 rows that each contain an in-file `](#` link, but the plan only says each row links "the design section that carries it". Eight ADRs are `not yet` (0001, 0004 to 0010) and several have no section (0001 ADR process, 0006 AGENTS.md as shared file, 0007 make, 0009 Python policy, 0010 git-bug optional). Say in the register row definition where such a row links (for example to `#decision-register` itself or the nearest section, such as `#rules` for 0004 and 0005), so the implementer does not invent a section to satisfy the count.
2. **[Process] Suggestion** — The section commits in step (2) run the resolve check on in-file links; a section that links forward to one not yet written fails its own commit. One sentence in the PR split ("a section links only to sections already committed; the register links last") would remove the trap.

### Summary

Revision 6 applies the owner's decisions cleanly and the conditional-guard design is not vacuous at any stage: hook-adding commit, section commits, register commit and glossary commit all behave as intended, and a broken anchor fails throughout. The one residue (a rewrite that drops the register heading disables the guards) is acknowledged in the plan and left to review and the change log. Ready for owner approval and implementation.

### Recommended Actions

- [ ] Optionally add the two one-line clarifications above (register link target for ADRs without a section; no forward in-file links before the register).
- [ ] Settle C6 with the owner before PR B's glossary commit; no action needed on the plan itself.

## Checkpoint
**Status**: complete
**When**: 2026-10-09 09:30 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Owner approval of the phase-3 plan, 2026-10-09. Plan `.agent/work-plans/issue-335/plan.md` at `acd2cc3` (revision 6); plan review round 5 at `65fb3c4`, verdict ready ("approved with suggestions").

- Plan approved at revision 6; the two round-5 suggestions (register link target for ADRs without a section; no forward in-file links before the register) are folded in before PR B.
- PR A may start now.
- Heading "Rules" kept.
- Label "System design" kept.
- Anchor hook approved, with `docs/decisions/` in its scope.
- Purpose section and the `#how-it-works` / `#the-design` anchors accepted.
- Glossary terms (C6) to be settled with the owner before PR B writes the glossary.

## Implementation
**Status**: complete
**When**: 2026-10-09 11:10 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `acd2cc3`
**Branch**: feature/issue-335 at `fb79191`

### Summary
PR A of the phase-3 plan (revision 6): fill the gaps the new `docs/design.md` will point at, replace real project names in user-visible text with synthetic ones, fix the ADR-0017 link. Nothing is deleted from `docs/design.md`; no push.

### Commits
- c4ff312 progress: Checkpoint entry recording the owner's approval of 2026-10-09
- a80936e `review_loop_lifecycle.md`: "Exit contract and dispatch" section (`dispatch_phase.sh --check-exit`, its OK / PARTIAL / FAILED / MISSING results, fresh sub-agent per phase with the repeat-phase exception, ADR-0014, ADR-0015)
- 959abbb `lock.sh`: header says what the lock is (file path, only reader `dashboard.sh`, advisory)
- d19ba93 `validate_workspace.py`: docstring names the `project '<name>':` failure prefix
- 8510202 synthetic names: `_project_registry.sh`, `projects.local.example`, `WORKTREE_GUIDE.md`, `Makefile` help line, `principles_review_guide.md` ADR-0016 row
- fb79191 ADR-0017: ADR-0008 link filename corrected to `0008-permit-cross-reference-addendums-in-adrs.md`

### Synthetic names
`gz4d` -> `boat_sim`; `p11` -> `shore_tools`; `p11-jazzy` / `p11-rolling` -> `shore_tools-jazzy` / `shore_tools-rolling`; `project11-ng` -> `shore_tools`. The guide's ADR-0016 row now reads "#317's acceptance run in a registered project" (no name).

### Tests
`run_script_tests.sh` (all 30 `test_*.sh` suites) ran through the `validate-script-tests` pre-commit hook on the commits touching `.agent/` and `Makefile` (a80936e, 959abbb, d19ba93, 8510202) and passed; the hook skipped on the ADR-0017 commit (no matching files). No suite reads `projects.local.example`. All other hooks passed on every commit.

### Verified facts behind the new text
- `workspace.lock`: readers are `dashboard.sh` (line 196) and `unlock.sh` (removes it); no other script or test reads it.
- `project '<name>':` appears in `validate_workspace.py` at the adapter-delegation, unknown-type and missing-hosting-dir failures.
- ADR-0015 governs `cross_model_review.sh` dispatch (inside `review-code`), not phase handoff; the lifecycle paragraph says so rather than attributing the fresh-sub-agent rule to it.

### Deviations from the plan
- The Checkpoint `**Decision**` is `proceed`, not `approve`: `proceed` is the token `dispatch_phase.sh` accepts for `After: plan`.
- The plan's `Makefile` line 80, `.agent/projects.local.example` lines 52 and 72-76, `WORKTREE_GUIDE.md` lines 72 and 181, `_project_registry.sh` lines 11-14, guide line 51 and ADR-0017 line 27 were all as stated; no line reference was wrong.
- `WORKTREE_GUIDE.md` still contains `rolker/cube_bathymetry#111` (a real package-repo example); the plan did not list it, so it was left.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-09 09:40 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-335 at `fb79191`
**Base**: a80936e^ (PR A commits a80936e..fb79191 only; the branch also carries the phase-2 principles work, whose pre-push review was round 1, so this is round 2 by the script count)
**Depth**: Standard (reason: 9 files; governance and enforcement paths touched)
**Must-fix**: 1 | **Suggestions**: 6
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

### Findings
- [x] (must-fix) `OK` is defined as "newest entry is Status complete", but an implement / address-findings Implementation entry that is complete without the PR/Branch line is PARTIAL, so the two bullets overlap; qualify OK (Gemini) — `.agent/knowledge/review_loop_lifecycle.md:87-91`
- [x] (suggestion) "hands each phase to a fresh sub-agent" omits the owner-chosen takeover, which the host runs inline (row 27); name it beside the 4a exception (adversarial) — `.agent/knowledge/review_loop_lifecycle.md:73`
- [x] (suggestion) the command example omits --pr (required for triage-reviews; PR-mode review-code checks a different entry type), --type and --project; --check-exit can also exit 2 or 3 with no status line (Codex, adversarial) — `.agent/knowledge/review_loop_lifecycle.md:83`
- [x] (suggestion) "The only reader is dashboard.sh ... does not stop any script": lock.sh and unlock.sh also test the file, and a second `make lock` is refused while it exists — `.agent/scripts/lock.sh:6-8`
- [x] (suggestion) the `project '<name>':` prefix claim does not cover type-project parent roots, which report as `parent root '<name>':`; qualify or add (Codex) — `.agent/scripts/validate_workspace.py:20`
- [x] (suggestion) help text "Lock workspace (prevent concurrent agent work)" now contradicts the lock.sh header (advisory, stops nothing); predates the diff — `Makefile:88`
- [ ] (suggestion) user-visible prose still names the real project (README "project11", west-variant "p11"); outside the plan's stated boundary, so decide whether to extend it — `tools/ros-manifest/README.md:6`

## Implementation
**Status**: complete
**When**: 2026-10-09 09:55 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Branch**: feature/issue-335 at `42f4714`
**Addressed**: Local Review (Pre-Push) at `fb79191` (2026-10-09 09:40 -04:00)
**Commits**: `1682437`, `195cf60`, `42f4714`

### Actions
- [x] `OK` overlapped `PARTIAL` — `OK` now also requires the `**PR**` / `**Branch**` line for an implement / address-findings `## Implementation` entry, `PARTIAL` reworded to "a complete ... entry that lacks" it, and "none of the three above" now names `complete`, `partial` or `failed` (matches `dispatch_phase.sh` 424-440) — `.agent/knowledge/review_loop_lifecycle.md:87-100` (`1682437`)
- [x] "fresh sub-agent" omitted the owner-chosen takeover — now names the 4a resumed-agent case and the row-27 `mode=inline` takeover (`run-issue` section 5) — `.agent/knowledge/review_loop_lifecycle.md:73-79` (`1682437`)
- [x] `--check-exit` example — now mentions `--pr` (required for `triage-reviews`, PR-mode `review-code` uses `## Local Review`), `--type` / `--project`, and exit 2 / 3 with no `status=` line — `.agent/knowledge/review_loop_lifecycle.md:83-102` (`1682437`)
- [x] `lock.sh` "only reader is dashboard.sh" — header now says `lock.sh` / `unlock.sh` also test the file, a second `make lock` is refused (exit 1), still advisory for every other script — `.agent/scripts/lock.sh:4-10` (`195cf60`)
- [x] `validate_workspace.py` prefix claim — docstring now covers `parent root '<name>':` and the unprefixed indented "Clone the project there" follow-up — `.agent/scripts/validate_workspace.py:20-27` (`42f4714`)
- [x] `Makefile` help text contradicted the lock.sh header — now "Advisory workspace lock, shown by the dashboard (a second lock is refused)" — `Makefile:88` (`195cf60`)
- [ ] user-visible prose still names the real project — NOT addressed: owner decision (extend the synthetic-name boundary to `tools/ros-manifest/`?); the files were not touched — `tools/ros-manifest/README.md:6`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-09 09:57 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: approved

**Branch**: feature/issue-335 at `0aab56d`
**Base**: a80936e^ (PR A commits a80936e..0aab56d)
**Depth**: Standard (reason: 9 files; governance and enforcement paths touched; whole-branch classification)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings

### Findings
- [ ] No issues found. LGTM. (Round-2 must-fix and suggestions 1-5 verified resolved; suggestion 6 and the cube_bathymetry example stay with the owner. Gemini's two round-3 findings were a false positive and the owner-held item.)
