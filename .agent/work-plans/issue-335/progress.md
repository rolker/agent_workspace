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
**Plan**: `.agent/work-plans/issue-335/plan.md` at `0f604b7`

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

## Checkpoint
**Status**: complete
**When**: 2026-10-09 10:20 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Decided-by**: owner
**After**: publish
**Decision**: publish

Owner decisions 2026-10-09 for PR A (phase-3 plan `acd2cc3`). Pre-push review round 3 approved (reviewed `0aab56d`, entry recorded in `cab33dc`).

- Make the `WORKTREE_GUIDE.md` package-worktree example synthetic too (`acme/sonar_driver#111`); done in `c6c85f5`, after the reviewed head.
- Leave the `tools/ros-manifest/` prose as is; the synthetic-name boundary is unchanged. Round-2 finding 6 is owner-decided "leave", not addressed.
- Publish PR A now (Part of the design-doc issue; PR B follows).

## Integrated Review
**Status**: complete
**When**: 2026-10-09 11:37 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**PR**: #377 at `4e9cab3`
**Sources**: 2 (Copilot R1 @ `4e9cab3`, CI rollup); no local-review entry covers this head (the round-3 approval at `0aab56d` is stale: `c6c85f5` touched `.agent/WORKTREE_GUIDE.md`)
**Cross-source confirmations**: 0
**CI**: all-pass

### Findings
- [x] (low, Copilot R1) The "Anything but `OK` is a `phase-failed` checkpoint" sentence contradicts the paragraph above it: exits 2 and 3 print no `status=` line and are errors in the check itself, while `run-issue` routes only returned `PARTIAL|FAILED|MISSING` to `checkpoint:phase-failed`. Reword to "Any returned status other than `OK` (`PARTIAL`, `FAILED`, `MISSING`) is a `phase-failed` checkpoint ...; exit 2 or 3 is a failure of the check, fix it and re-run" — `.agent/knowledge/review_loop_lifecycle.md:108`
- [x] (medium, Copilot R1) The `## Plan Authored` entry for plan commit `0f604b7` carries `**Plan**: `0f604b7`` without the path; ADR-0013 requires `` `<path>` at `<plan-commit-sha>` `` and `progress_read.py::_corr_plan` returns no correlation for it. Change to `` `.agent/work-plans/issue-335/plan.md` at `0f604b7` `` (the commit exists; sibling entries use that form) — `.agent/work-plans/issue-335/progress.md:192`

### False positives
- none

Carried forward, not re-listed: `tools/ros-manifest/` real-name prose is owner-decided "leave" (Checkpoint at `4e9cab3`); earlier-round findings from the phase-2 principles work are stale prior rounds, not PR A scope.

## Implementation
**Status**: complete
**When**: 2026-10-09 11:50 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**PR**: #377 at `bdab476`
**Addressed**: Integrated Review at `4e9cab3` (2026-10-09 11:37 -04:00)
**Commits**: `fcafa3c`, `bdab476`

### Actions
- [x] (low, Copilot) "Anything but `OK` is a `phase-failed` checkpoint" contradicted exits 2 and 3 — reworded: a returned `PARTIAL` / `FAILED` / `MISSING` is the checkpoint; exit 2 or 3 means the check itself failed, is fixed and re-run, raises no checkpoint (`run-issue` routes only returned `PARTIAL|FAILED|MISSING` to `phase-failed`) — `.agent/knowledge/review_loop_lifecycle.md:107-110` (`fcafa3c`)
- [x] (medium, Copilot) `## Plan Authored` for `0f604b7` lacked the path — `**Plan**` now `` `.agent/work-plans/issue-335/plan.md` at `0f604b7` ``; `progress_read.py --type "Plan Authored"` now returns a plan correlation (path + sha `0f604b7`) for it — `.agent/work-plans/issue-335/progress.md:192` (`bdab476`)

## Local Review
**Status**: complete
**When**: 2026-10-09 11:50 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: approved

**PR**: #377 at `8ae90e0`
**Depth**: Standard (reason: whole-PR classification, 11 files, governance and enforcement paths touched)
**Must-fix**: 0 | **Suggestions**: 0

### Findings
- [ ] No issues found. LGTM. (Copilot's two PR findings are resolved at fcafa3c and bdab476; external reviewers' round findings were checked against dispatch_phase.sh and lock.sh and are false positives.)

## Plan Authored
**Status**: complete
**When**: 2026-10-09 12:56 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `1b561b8`

Revision 7 of the phase-3 plan, applying owner decisions of 2026-10-09 after the revision 6 approval: PR A is recorded as merged (#377, 249a8d0) with what it landed; C1 is decided (register only in PR B, a drifted ADR gets standing "superseded in practice", no ADR file edited, supersession later one at a time); C6 is decided (the eight phase names are not glossary entries, the settled list of 15 terms with the owner's definitions sits in row 16, WIP limit and appetite left out). The two accepted round-5 suggestions are folded in (register rows for ADRs with no section link to the register itself; sections link only to already-committed sections, the register last). The plan's closing section lists what changed per item.

## Plan Authored
**Status**: complete
**When**: 2026-10-09 13:59 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `0d7ea07`

Revision 8 of the phase-3 plan, applying two owner decisions of 2026-10-09 after the revision 6 approval. C2 (workspace as a registered project, #295): stays open as a pointer; row 7 gains an inventory of where the workspace path differs from the registered-project path (8 script rows) and a classification of the 12 adapter verbs (3 no-op, 5 thin wrapper, 4 real), so #295 is decided by reading it after the ADR-0016 acceptance run. C3 (where an issue's work plan and progress timeline live): lands in row 8 (Worktrees); Now is records committed in the project repo on the feature branch; Target is two per-project registry settings, location and tracking, with derived defaults, three mechanisms and one source-of-truth rule, tested against a colleague's single-repo project. The Now block also shows a gap found while checking: merge_pr.sh anchors the gate's timeline lookup at the legacy project/ checkout. Both questions move to Decided; the plan's closing section lists what changed per item.

## Plan Authored
**Status**: complete
**When**: 2026-10-09 14:52 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `16283cc`

Revision 9 of the phase-3 plan, applying the owner's A-group decisions of 2026-10-09 ("Go for group A") and citing issue #379. A1: every section carries the label Now, also with no Target. A2: the admission rule is the opening paragraph of "The design"; How it works stays first and unencumbered. A3: the Rules table gets the enforced-by column (hook, script, CI, review only, nothing). A4: no per-section dates; the register's Re-examined column is the checked-date and PR C adds one line to audit-workspace step 2 (the skill's "Report, don't fix" guideline gets a one-cell exception). A5: Instruction layers is a real section with status proposed; the tree pointer is dropped. #379 is cited as the tracker of the merge gate's legacy-path timeline lookup (its one-line fix does not wait for the records resolver); the roadmap gets no row for it. Only B1, B2, C4 and C5 remain open. The plan's closing section lists what changed per item.

## Implementation
**Status**: partial
**When**: 2026-10-09 15:40 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `16283cc`
**Branch**: feature/issue-335 at `46794b3`

### Summary
PR B, commit 1 of the phase-3 plan (revision 9): the design-anchor checker, its pre-commit hook and its script-tests suite. Tooling only: `docs/design.md`, `AGENTS.md`, `CLAUDE.md` and every section are untouched. Remaining PR B commits (sections, register, glossary, deletions, guide row) are not started; no push.

### Commits
- 46794b3 `check_design_anchors.sh`, the `check-design-anchors` hook (placed before `validate-script-tests`, `files:` the eight paths of Wire-in 6 including `docs/decisions/`; hook approved by the owner 2026-10-09, B4) and `test_design_anchors.sh`

### Tests
`run_script_tests.sh`: all 31 suites passed (also through the `validate-script-tests` hook on the commit); `test_design_anchors.sh` has 26 cases (fixtures (a) to (g) plus slug, fence, scope, usage and `DESIGN_ANCHORS_ROOT` cases) and passes with gawk and mawk; `test_script_tests_hook_scope.sh` passes with no ROOT_READERS entry. The checker exits 0 on this repo (no `docs/design.md#` citation and no register heading exist yet). shellcheck (style severity) clean on both scripts.

### Deviations from the plan
- Guard (a) and guard (b) are both live only when the register heading AND `docs/decisions/` exist, as Wire-in 6 words it; a register heading with no ADR directory leaves both off.
- In-file `](#...)` links are matched up to the closing `)`; an all-digit fragment or one containing `<` is ignored (not only the empty `#<section>` form), so `[y](#<slug>)` placeholders do not fail. Links inside fenced code in design.md are not links; citations in fenced code of the citing files still count.
- The hook's `files:` line exceeds yamllint's 120 characters, so it carries a `yamllint disable-line` comment rather than being split.

## Plan Authored
**Status**: complete
**When**: 2026-10-09 15:21 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `aa5765f`

Revision 10 of the phase-3 plan, applying one owner decision of 2026-10-09 about writing order. The owner does not write "How it works" first: the first section commit creates `# How it works` as a stub (heading plus "Written last; see the change log.") so the anchor exists, the other sections are written in table order, and an agent drafts How it works last from the fact list and the owner's recorded phrasings only, with no new ideas, for the owner to edit when he has bandwidth. Process step 2, the PR B commit order, row 1 and Estimated Scope are reworded; PR B is written in two dispatches (rows 1 to 9, then rows 10 to 16 and the draft). Nothing else changes.

## Implementation
**Status**: partial
**When**: 2026-10-09 15:34 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `aa5765f`
**Branch**: feature/issue-335 at `b9d689a`

### Summary
PR B part 1: the skeleton and rows 3 to 9 of the section table in `docs/design.md` (Purpose, Documentation layers, Rules, Sessions and roots, Registry and adapters, Worktrees, Review loop and timeline), one commit per section, after plan revision 10 (How it works is a stub first and drafted last). The document is 446 lines. Rows 10 to 16 (Merge gate, Identity, Instruction layers, Decision register, Open questions content, Change log content, Glossary) and the How it works draft are part 2. No push.

### Commits
- aa5765f plan revision 10; f413beb its Plan Authored entry
- 5007c8d skeleton (stub, The design opening and Status key, change log)
- 2edd550 Purpose; fe8ef6d Documentation layers; bf0f050 Rules
- 73e7472 Open questions, started (OQ-1)
- b884c28 Sessions and roots (OQ-2); d128f0a Registry and adapters (C4)
- e5217b9 Worktrees; b9d689a Review loop and timeline (C5; review guide work-plan row now names this section)

### Deviations from the plan
- The Open questions section was started early (own commit, before Sessions) so gaps found while writing had a place; new sections are inserted before `## Open questions`, so part 2's rows 10 to 13 go in the same place. New IDs OQ-1 and OQ-2; the plan's C4 and C5 keep their IDs.
- Rules: the plan listed "issue number matches the branch" as a hook. `verify-issue-branch.py` only prints the issue and always returns 0, so the row says `nothing`. Four hooks that read local state are skipped in CI (`SKIP` in validate.yml); the column's check cell says so. Added rows: hooks not skipped (CI), adapter contract (hook), design anchors (hook), no project names, Ask First (review only), PR signature (script), secrets (nothing).
- Sessions and roots has two Target blocks, `decided, not built` (registry-only discovery, register_project.sh, workspace hosts no project, memory) and `open` (#295 pointer), because one block may hold one status.
- The review guide's work-plan row edit (plan line 71) went into the Review loop commit, the section it now names.
- Review loop and timeline keeps three `(candidate)` Target lines for the owner to accept or drop; the Status key does not mention the marker.
- The Change log section has no Now block yet (its content is part 2). Sections over 60 lines (Sessions 63, Registry 83, Worktrees 80, Review loop 70) carry the plan's question answered in their change-log row.
- Local commits for Purpose, Rules, Open questions, Sessions and Registry were amended before the checker ran at the next commit (unpushed, wording only).

## Implementation
**Status**: complete
**When**: 2026-10-09 15:43 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-335/plan.md` at `aa5765f`
**Branch**: feature/issue-335 at `5ac0fc5`

### Summary
PR B part 2: rows 10 to 16 of the section table and the How it works draft, finishing the content of `docs/design.md` (688 lines). With part 1 (5420953) the PR B content is complete. Not done, by design: PR C (skills, roadmap, README pointer), the with/without test of process step 4, and the owner's edit of the How it works draft. No push.

### Commits
- 3cbffa5 Merge gate; eceeb89 Identity; d91ea1e Instruction layers (all `proposed`)
- fc74627 Decision register (17 rows; both checker guards live from here, checked by deleting a row in a scratch copy: exit 1)
- 9281306 Open questions table finished (OQ-1 to OQ-5, C4, C5); c92402d Change log Now block
- d07b25a Glossary (15 entries); 5ac0fc5 How it works, agent draft from the fact list, marked in the change log

### Checks
`check_design_anchors.sh` exit 0 at every commit and at HEAD; `make lint` exit 0 (all 20 hooks passed, including the anchors hook and the script-tests suite); no private project name in `docs/design.md`; no `docs/design.md#` self-citation.

### Superseded in practice (register rows, for the owner one at a time, C1-c)
ADR-0002 (project worktree location), ADR-0011 (discovery order; 12 verbs), ADR-0013 (the dispatched implement pass writes `## Implementation`, there is no implement skill), ADR-0014 (`implement` is dispatched since #314, not inline). No ADR file was edited. The coordinator named three; ADR-0014 is a fourth found while checking the register.

### Deviations from the plan
- Instruction layers: the four layers are one `proposed` block with the sizes as citations; no budget number is set.
- Register: carrying sections for ADRs the plan does not list: 0004 and 0005 link Rules, 0008 links Documentation layers, 0017 links The design. Standing `in force` for the `not yet` rows is read from each ADR's Status line, not re-examined, and the register says so.
- Open questions gains OQ-3 (home for "healthy" and measures), OQ-4 (instruction budget) and OQ-5 (server-side merge gate). B1 and B2 stay out as wire-in questions.
- Identity text stays on ephemeral identity; the persistent (container) identity of AI_IDENTITY_STRATEGY.md is not described.
- Seen and not acted on: ADR-0007's examples describe ROS layer setup that this workspace's Makefile does not have (register says `not yet`).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-09 16:05 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-335 at `5500dc0`
**Base**: 071a03f (PR B scope: checker commit 46794b3 through 5500dc0)
**Depth**: Standard (reason: governance docs, .pre-commit-config.yaml, scripts and tests)
**Must-fix**: 10 | **Suggestions**: 14
**Round**: 4 | **Ship**: continue — round 4: 10 must-fix is high; another independent read warranted

### Findings
- [x] (must-fix) "`dispatch_phase.sh next` reads only the newest entry" is false: `round_count()` reads every earlier pre-push review and `skill_for()` earlier Implementation entries; say it routes on the newest entry (same wrong sentence is in review_loop_lifecycle.md) — `docs/design.md:411`
- [x] (must-fix) Table 2 `setup` row cites "`setup-dev` and `git-bug` stamps (`Makefile` header, line 98)"; line 98 is `setup: $(STAMP)/project.done $(STAMP)/git-bug.done`, the header lists setup-dev.done, git-bug.done, project.done — `docs/design.md:277`
- [x] (must-fix) "each run by a fresh sub-agent" / "Each phase runs in a fresh sub-agent" omits that a repeat phase may resume the earlier agent (review_loop_lifecycle.md line 77, run-issue step 4a, ADR-0014 #314) — `docs/design.md:11` and `docs/design.md:415`
- [x] (must-fix) "a merge that does not end merged goes to `merge-refused`" is too broad: only a run that recorded a merge entry re-routes (run-issue step 11); line 475-476 says it correctly — `docs/design.md:403`
- [x] (must-fix) All four gate flags are said to be passed only on the owner's answer per run-issue step 11, which lists only `--report-only`, `--no-wait` and `--allow-pending-review` — `docs/design.md:458`
- [x] (must-fix) "`progress.md` is 726 lines (`wc -l`, 2026-10-09)"; the file is 782 lines at the reviewed head — `docs/design.md:442`
- [x] (must-fix) Checker closes a fence on any line starting with the fence characters, even with an info string; probe: "```md / ```bash / more / ``` / [x](#nope)" exits 0 with the broken link unseen — `.agent/scripts/check_design_anchors.sh:140`
- [x] (must-fix) A punctuation-only heading (`## !!!`) gives an empty slug, `SLUGS[""]` fails with "bad array subscript" and the checker still exits 0; handle empty slugs and test it — `.agent/scripts/check_design_anchors.sh:183`
- [x] (must-fix) Heading lines `next` before link extraction, so `## [See](#gone)` is never checked; probe exits 0 — `.agent/scripts/check_design_anchors.sh:157`
- [x] (must-fix) Three `Proposed (candidate)` bullets remain; the plan says each is accepted or dropped by the owner and no marker survives into the final text (owner call) — `docs/design.md:437`
- [ ] (suggestion) Register guard (b) compares only a row count to the ADR file count; duplicate or non-ADR linked rows can satisfy it; match each docs/decisions/NNNN to a row — `.agent/scripts/check_design_anchors.sh:242`
- [ ] (suggestion) Guards are off whenever no heading slugs to `decision-register`; now that the register exists, a rename switches them off silently — `.agent/scripts/check_design_anchors.sh:231`
- [ ] (suggestion) `slug()` keeps `_` but `ANCHOR_RE` rejects it, so such a heading can never be cited; link titles (`](#x "t")`) and inline-code links give false positives; GitHub `#L42` permalinks fail as malformed — `.agent/scripts/check_design_anchors.sh:130`
- [ ] (suggestion) Test gaps: tilde fences, closing #s, info-string closer, link in heading, empty slug, underscore heading, `\|` cell — `.agent/scripts/tests/test_design_anchors.sh`
- [x] (suggestion) ADR-0011 register row cites "12 verbs, not 10" as drift, but ADR-0011's own Status already says "now 12 verbs"; only the resolution order is real drift — `docs/design.md:569`
- [x] (suggestion) ADR-0012 row links `#worktrees`, which never cites ADR-0012 or the two verbs (they are under Registry and adapters) — `docs/design.md:570`
- [ ] (suggestion) Instruction layers cites `prior-art-comparison-2026-10-08/summary.md` and `prior-art-alignment-agent-frameworks.md`, which exist only under the gitignored `.agent/scratchpad/` (.gitignore:38) — `docs/design.md:535`
- [ ] (suggestion) Glossary "convergence" ("each finds fewer must-fix items than the last") differs from the `review_progress.sh verdict` rule (zero, or round >= 2, <= 2, not rising, mechanical); owner-settled wording, so flag only — `docs/design.md:654`
- [x] (suggestion) Gate (a) names `Local Review` or `Integrated Review`; `merge_pr.sh:718` also takes `External Review` as newest — `docs/design.md:462`
- [x] (suggestion) Table 1 `worktree_list.sh` row omits the second recognised path `*/.workspace-worktrees/*` (worktree_list.sh:149) — `docs/design.md:263`
- [x] (suggestion) "grep finds only help text and docstrings" also hits the `single_project` default at `.agent/scripts/adapter:73` — `docs/design.md:235`
- [ ] (suggestion) The `open` rule says an open block holds no question text, but the Open questions section is itself an `open` block holding the table; add the exception to the Status key — `docs/design.md:68`
- [x] (suggestion) Change-log row says the Decision register section is 40 lines; it is 46 (539-584) — `docs/design.md:631`
- [ ] (suggestion) "Plan-level decisions that never got an ADR: none are listed" departs from plan row 13 without a recorded reason — `docs/design.md:577`

## Implementation
**Status**: partial
**When**: 2026-10-09 16:12 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Branch**: feature/issue-335 at `625c987`
**Addressed**: Local Review (Pre-Push) at `5500dc0` (2026-10-09 16:05 -04:00)
**Commits**: 1e852db, ec38c57, 625c987

### Actions
- [x] Routing wording (newest entry; earlier entries for round count and failed-Implementation skill) — `docs/design.md:413`, `.agent/knowledge/review_loop_lifecycle.md:50`
- [x] `setup` row: line 98 is `setup: $(STAMP)/project.done $(STAMP)/git-bug.done`, header lists three stamps — `docs/design.md:279`
- [x] Repeat-phase resume exception (run-issue 4a) — `docs/design.md:11`, `docs/design.md:419`
- [x] `merge-refused` only after the run recorded a merge entry — `docs/design.md:405`
- [x] Gate flags: the three step 11 lists; `--force-unreviewed` described as the fourth bypass — `docs/design.md:463`
- [x] progress.md line count recomputed, 820 at 57cfca4 (`wc -l`, 2026-10-09) — `docs/design.md:447`
- [x] Checker: a fence closes only on a bare fence line; suite cases for a bash-tagged line and tilde fences — `.agent/scripts/check_design_anchors.sh:142`
- [x] Checker: an empty slug is skipped, awk failure exits 2, `${LINKS[@]}` is set -u safe; suite case — `.agent/scripts/check_design_anchors.sh:165`
- [x] Checker: heading lines keep link extraction; suite case — `.agent/scripts/check_design_anchors.sh:165`
- [x] ADR-0011 register row: only the resolution order is drift — `docs/design.md:575`
- [x] ADR-0012 row now links Registry and adapters — `docs/design.md:576`
- [x] Gate (a) names `External Review` — `docs/design.md:468`
- [x] Table 1 `worktree_list.sh` row names `*/.workspace-worktrees/*` — `docs/design.md:265`
- [x] `adapter:73` default named — `docs/design.md:238`
- [x] Register section length 46 — `docs/design.md:637`
- [ ] Three Review-loop proposals (owner decision pending in this entry's commits): the owner's decision to keep all three as plain `Proposed:` lines was relayed mid-pass; the edit is made in the working tree but not committed because the commit was denied by the permission classifier — `docs/design.md:442`
- [ ] Partly done: `slug()`/`ANCHOR_RE` now agree on `_` and the suite covers closing #s, link in heading, empty slug, underscore heading; link titles, inline-code links, `#L42` permalinks and the `\|` cell case are not addressed — `.agent/scripts/check_design_anchors.sh:130`, `.agent/scripts/tests/test_design_anchors.sh`
- [ ] Not addressed (outside the brief): register guard (b) row-to-ADR matching, guards switching off on a renamed register heading — `.agent/scripts/check_design_anchors.sh:231`, `:242`
- [ ] Not addressed (left for the owner): scratchpad citations, glossary "convergence" wording, open-block rule vs Open questions, plan-level decisions line — `docs/design.md:535`, `:654`, `:68`, `:577`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-09 16:40 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: approved

**Branch**: feature/issue-335 at `5691639`
**Base**: 071a03f (PR B scope: checker commit 46794b3 through 5691639)
**Depth**: Standard (reason: governance docs, .pre-commit-config.yaml, scripts and tests; whole-branch classification)
**Must-fix**: 0 | **Suggestions**: 14
**Round**: 5 | **Ship**: recommended — no must-fix findings

### Findings
- [ ] (suggestion) Rules table lacks the owner's standing rule that the owner decides every merge; it is written only in a `merge_pr.sh` comment, not in `docs/principles.md` or the Rules section; add a Rules row (enforced by: `review only` or `nothing`) — `docs/design.md:139`
- [ ] (suggestion) "`progress.md` is 820 lines" was true when written and is 850 now; the file grows with each entry, so say "more than 800" — `docs/design.md:447`
- [ ] (suggestion) Fence opener accepts any indentation (a 4-space-indented fence is code in CommonMark, but a fence nested in a list item is valid); Codex and Copilot flagged it, so decide the rule and test it — `.agent/scripts/check_design_anchors.sh:143`
- [ ] (suggestion) An empty ATX heading (`##`) does not reset the register-section boundary, so later anchored rows can count toward guard (b) — `.agent/scripts/check_design_anchors.sh:162`
- [ ] (suggestion) Duplicate slugs: headings `A`, `A`, `A-1` give `a`, `a-1`, `a-1`; GitHub gives the third `a-1-1` — `.agent/scripts/check_design_anchors.sh:166`
- [ ] (suggestion) The external-citation `grep` discards its exit status and stderr, so an unreadable citer passes silently — `.agent/scripts/check_design_anchors.sh:253`
- [ ] (suggestion) Open, known: register guard (b) counts rows, not one row per ADR number — `.agent/scripts/check_design_anchors.sh:242`
- [ ] (suggestion) Open, known: guards switch off if the `decision-register` heading is renamed — `.agent/scripts/check_design_anchors.sh:231`
- [ ] (suggestion) Open, known: link titles, inline-code links and `#L42` permalinks give false positives; test gaps for tilde fences, closing #s, `\|` cells — `.agent/scripts/check_design_anchors.sh:130`
- [ ] (suggestion) Open, known: Instruction layers cites two prior-art notes that exist only in the gitignored scratchpad — `docs/design.md:540`
- [ ] (suggestion) Open, known: "Plan-level decisions that never got an ADR: none are listed" departs from plan row 13 without a recorded reason — `docs/design.md:582`
- [ ] (suggestion) Open, known: the `open` block rule says no question text, but the Open questions section is itself an `open` block holding the table — `docs/design.md:68`
- [ ] (suggestion) Open, known: glossary "convergence" wording differs from the `review_progress.sh verdict` rule (owner-settled wording) — `docs/design.md:659`
- [ ] (suggestion) Open, known: the ADR-0011 and register wording otherwise fine; Review-loop Target bullets 2 and 3 repeat the Worktrees Target (lookup) and could shrink to pointers — `docs/design.md:445`

## Checkpoint
**Status**: complete
**When**: 2026-10-09 17:05 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Decided-by**: owner
**After**: publish
**Decision**: publish

Owner decisions 2026-10-09 for PR B (pre-push review round 5, approved, reviewed at `5691639`, entry recorded in `d0d7dcc`).

- Publish PR B now (Part of #335; PR C follows).
- Two suggestions folded in before publishing: the Rules row for the owner deciding every merge (`803ae39`), and the `progress.md` size stated as "more than 800 lines" (`fb422b8`).
- The checker edge cases from Codex and Copilot (fence indentation, empty heading and register boundary, duplicate-slug numbering, citation grep exit status) go to a follow-up issue, not this PR.
- Stopping point for the weekend: the PR is open and unmerged; the merge decision stays with the owner.

The last checkbox of the round-5 review entry (Review-loop Target bullets 2 and 3 as pointers) is unverified filler per the reviewer and is not a finding.

## Integrated Review
**Status**: complete
**When**: 2026-10-12 08:42 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #380 at `be87238`
**Sources**: 2 (Copilot R1 @ `be87238`, CI rollup); no local review entry covers this head (round 5 approval and earlier rounds are stale by code changes since)
**Cross-source confirmations**: 0
**CI**: all-pass

### Findings
- [x] (should-fix, Copilot) "How it works" says each of the eight phases runs in a fresh sub-agent and leaves one entry; `publish` and `merge` are host steps (`run-issue/SKILL.md` steps 7 and 11; `dispatch_phase.sh` dispatches only review-issue, plan-task, review-plan, implement, review-code, triage-reviews, address-findings), `mode=inline` runs a phase in the host (step 5), `publish` has no entry type and a passing merge gate records nothing. Same overstatement in the Review loop bullet heading "One entry per phase" (line 408) and "Each phase runs in a fresh sub-agent" (line 420) — `docs/design.md`
- [x] (should-fix, Copilot) "How it works" Projects paragraph states per-project footprint choice ("records go into a project only if the user chose that") as current; Worktrees Now says records are always committed in the owning repository and the choice is a proposed Target (line 28) — `docs/design.md`
- [x] (should-fix, Copilot) Sessions and roots Now says a session runs in one of three places including the user tier in `~/.claude`; ADR-0016 decision 1 and the next bullet name two session roots, the user tier is the layer injected into them (line 165) — `docs/design.md`
- [x] (should-fix, Copilot) Worktrees Records says plan and timeline are committed in the project repository; for a workspace issue (this one) they are in the workspace repository; line 403 already states the owning-repository rule (line 330) — `docs/design.md`
- [x] (minor, Copilot) Rules row "Nothing committed to the workspace names a particular project" is broader than the boundary decided 2026-10-09 (plan lines 468-472: real names stay in code-origin comments, test fixtures, ADRs and roadmap as history, `tools/ros-manifest/` prose); design.md states that boundary nowhere. Qualify the row with the boundary; the guide row it cites says the same broad thing (line 152) — `docs/design.md`
- [x] (minor, Copilot) Process step 1 says "this is revision 9" under a revision 10 header (line 56) — `.agent/work-plans/issue-335/plan.md`

### False positives

## Implementation
**Status**: complete
**When**: 2026-10-12 09:05 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #380 at `9e67ca6`
**Addressed**: Integrated Review at `be87238` (2026-10-12 08:42 -04:00)
**Commits**: `978bbd5`, `bdc2006`, `9e67ca6`

### Actions
- [x] F1: `publish` and `merge` are host steps; `publish` writes no entry, `merge` one only when its gate is relaxed; a failed phase can run in the host (`mode=inline`). How it works paragraph and the Review loop bullets "One entry per dispatched phase" and "Each phase but `publish` and `merge` runs in a fresh sub-agent" — `docs/design.md:10`, `docs/design.md:412`, `docs/design.md:426`
- [x] F2: the per-project footprint is stated as meant, with records today always in the owning repository and the choice proposed under Worktrees — `docs/design.md:24`
- [x] F3: two session roots; the user tier is the layer injected into them (ADR-0016 decisions 1 and 3) — `docs/design.md:166`
- [x] F4: records committed in the repository that owns the issue — `docs/design.md:331`
- [x] F5: Rules row states the 2026-10-09 boundary and the owner's rule of 2026-10-12 (a real name only for a public repository); same clause added to the review guide row "Put each thing at the level it applies to"; `marine_msgs` replaced by synthetic `sonar_msgs` (with `acme/` owner) in the worktree guide and review-plan; `documentation_verification.md` line 5 kept — `docs/design.md:155`, `.agent/knowledge/principles_review_guide.md:22`, `.agent/WORKTREE_GUIDE.md:183`, `.claude/skills/review-plan/SKILL.md:358`
- [x] F6: process step 1 says revision 10 — `.agent/work-plans/issue-335/plan.md:56`

Change log: two rows of 2026-10-12 appended (706 and 707 lines). Pre-commit hooks passed on each commit, including check-design-anchors and the script-tests suite.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-12 09:12 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-335 at `3dc4de5`
**Base**: be87238
**Depth**: Standard (reason: governance-file triggers — principles_review_guide.md, review-plan SKILL.md; 6 files, ~99 lines since be87238)
**Must-fix**: 1 | **Suggestions**: 2
**Round**: 6 | **Ship**: continue — round 6: must-fix rising (0 -> 1); the one must-fix is a mechanical wording fix

### Findings
- [x] (must-fix) `merge` entry rule is incomplete: a project PR with a gap and no flag also records `## Merge (report-only)` (gate report-only by default there, `merge_pr.sh:916-931`); a relaxed flag with no gap records nothing. Contradicts design.md's own Records bullet (gate report-only for project PRs). Cross-confirmed: Copilot, Claude adversarial, lead — `docs/design.md:414`
- [x] (suggestion) Rules row lists "work plans" as a history exception and attributes all exceptions to the 2026-10-09 owner decision; the plan's boundary (`plan.md:468-472`) names code-origin comments, fixtures, ADRs, roadmap and `tools/ros-manifest/` prose, not work plans — label work plans as the 2026-10-12 addition or drop them — `docs/design.md:154`
- [x] (suggestion) The edited example keeps `mission_manager` beside synthetic `sonar_msgs`; it is an existing mention of a public repository's package, so allowed, but a synthetic name would match "examples use synthetic names" (optional) — `.claude/skills/review-plan/SKILL.md:359` (deferred: owner decision 2026-10-12: keep mission_manager, an existing mention of a public repository's package, which the rule allows)

## Implementation
**Status**: complete
**When**: 2026-10-12 09:19 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-335 at `b84762a`
**Addressed**: Local Review (Pre-Push) at `3dc4de5` (2026-10-12 09:12 -04:00)
**Commits**: 57919ba, b84762a

### Actions
- [x] (must-fix) `merge` writes an entry only when the gate finds a gap and does not refuse it (a relaxing flag, or a project pull request); checked against `merge_pr.sh` Step 1.5 (lines 909-931, comment at 642); change-log row added (708 lines); the earlier 2026-10-12 row is left as history — `docs/design.md:414`
- [x] (suggestion) Rules row credits work plans as history to the owner's 2026-10-12 decision; change-log row added (709 lines) — `docs/design.md:154`
- [x] (suggestion) `mission_manager` kept in the review-plan example — `.claude/skills/review-plan/SKILL.md:359` (deferred: owner decision 2026-10-12, an existing mention of a public repository's package, which the rule allows)

## Checkpoint
**Status**: complete
**When**: 2026-10-12 09:19 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: findings
**Decision**: address

Recorded late: this answer was given before the Implementation entry at 3dc4de5, and the host did not write it then. Answers to the triage of Copilot's review at be87238 (Integrated Review, six findings F1-F6).

On F5 (real project names), after the host proposed the Rules row text "history (ADRs, roadmap, work plans), code-origin comments, test fixtures, tools/ros-manifest/ prose", synthetic names for marine_msgs in WORKTREE_GUIDE.md and review-plan SKILL.md, and keeping the documentation_verification.md origin link:

> It's all fine except going forward, only reference projects if they are public.

To "start the six fixes (address-findings in a background agent, re-review, back to the owner before any push)?" and "add the public-only clause to the review guide row 'Put each thing at the level it applies to'?":

> yes to both.

## Checkpoint
**Status**: complete
**When**: 2026-10-12 09:19 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Recorded late: this answer was given before the Implementation entry at 49064bd. Pre-push round 6 (at 4079641) reached MAX_ROUNDS with one must-fix (M1, merge-entry wording) and two suggestions. Host recommendation: fix M1 and S1, leave S2 (mission_manager, a public repository's package), then push and let the PR-mode review replace another local round.

> go ahead with your recommendation

## Local Review
**Status**: complete
**When**: 2026-10-12 09:28 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #380 at `306564b`
**Depth**: Deep (reason: whole-PR diff +2138/-344 over 10 files, governance files touched; focus be87238..306564b)
**Must-fix**: 1 | **Suggestions**: 5

### Findings
- [x] (must-fix) Anchor checker fence rule accepts any indentation: a 4+-space-indented ``` line (indented code, not a fence) opens a fence that never closes, so every later heading, link and the register guards are skipped and the hook passes silently; cap the opener at 3 spaces and/or report a fence still open at EOF, with a regression test (Codex + Copilot, cross-confirmed) — `.agent/scripts/check_design_anchors.sh:143`
- [x] (suggestion) Duplicate-heading suffixes are counted per raw slug, not against generated ones: `A`, `A`, `A-1` gives `a`, `a-1`, `a-1`, so a valid `#a-1-1` is rejected (fails loud); reserve every emitted slug (Codex + Copilot + Gemini) — `.agent/scripts/check_design_anchors.sh:166`
- [x] (suggestion) Glossary "progress timeline: the per-issue file where every phase writes an entry" now contradicts the fixed sentences (`publish` writes none, `merge` only when its gate is relaxed); the definition is the owner's C6 wording, so his call — e.g. "each dispatched phase" — `docs/design.md:679`
- [x] (suggestion) `merge` "writes one" entry in progress.md, but `_gate_record` falls back to a PR comment when no worktree can take the commit (merge_pr.sh 834-850); a short qualifier would make it exact — `docs/design.md:413`
- [x] (suggestion) Records parenthetical names workspace and project issues only; package-repo issues (`--issue owner/repo#N`) are a third owner, and merge_pr.sh says package worktrees carry no issue timeline (~line 843) — `docs/design.md:332`
- [x] (suggestion) Citations are matched only as `docs/design\.md#`; a relative `design.md#x` from `docs/roadmap.md` (a listed citer) is skipped silently; none exist today (Gemini) — `.agent/scripts/check_design_anchors.sh:259`

## Implementation
**Status**: complete
**When**: 2026-10-12 09:49 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #380 at `6e2d16c`
**Addressed**: Local Review at `306564b` (2026-10-12 09:28 -04:00)
**Commits**: `046f567`, `4d8d15c`, `e8337f3`, `b7fc22f`, `6bd9c80`, `6e2d16c`

### Actions
- [x] (must-fix) A backtick or tilde line indented more than 3 spaces past its list item's content column (0 outside a list) is indented code, not a fence; a closer sits no deeper than its opener could; a fence still open at end of file is a finding. Tests: indented code before a broken link, an unclosed fence, fences in bullet, wide ordered and nested list items, an indented code line under an item, an indented closer in a top-level fence — `.agent/scripts/check_design_anchors.sh:151`
- [x] (suggestion) Repeated slugs follow GitHub's slugger (first free `-N`): `A`, `A`, `A-1` give `a`, `a-1`, `a-1-1`; test also covers `B-1`, `B`, `B` — `.agent/scripts/check_design_anchors.sh:201`
- [x] (suggestion) Glossary "progress timeline" now reads "the loop records each step and decision": owner decision 2026-10-12 (option B), revising his C6 wording; change-log row added — `docs/design.md:688`
- [x] (suggestion) `merge` entry that no worktree on the branch can commit and push is posted on the pull request (`_gate_record`, `merge_pr.sh` 784-850); change-log row added — `docs/design.md:419`
- [x] (suggestion) Records names the package-repository case: no timeline, gate record on the pull request (`merge_pr.sh` 801, 843); change-log row added — `docs/design.md:334`
- [x] (suggestion) Relative `design.md#x` and `./design.md#x` citations from files directly in `docs/` (docs/roadmap.md) are checked; tests for broken, valid, no double report, and `../design.md#` left alone — `.agent/scripts/check_design_anchors.sh:291`

Tests: `test_design_anchors.sh` 46 passed (was 33; the new cases fail against the checker at `a88a4df`), also passing with `mawk` as `awk`; `run_script_tests.sh` all 31 suites passed; the checker passes on the real tree. Boxes in the source entry were ticked by hand: `review_progress.sh check` only takes an Integrated Review or Local Review (Pre-Push) as source. Not done: the `check-design-anchors` hook's `files:` filter does not include the checker script itself, so a checker-only commit skips the hook (it ran by hand here); changing `.pre-commit-config.yaml` is left to the owner.

## Local Review
**Status**: complete
**When**: 2026-10-12 09:57 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #380 at `a4dd163`
**Depth**: Deep (reason: 2720 lines over 10 files, governance doc plus a new pre-commit gate; fix round a88a4df..a4dd163 reviewed in focus)
**Must-fix**: 0 | **Suggestions**: 4

### Findings
- [ ] (suggestion) A fence on a list-marker line (`- ```text`) is not recognised: its contents are scanned as live headings/links and its closer reads as an opener, giving a false "never closed" finding; test the rest of the marker line for an opener with the item's column as base (Codex, rated must-fix; Claude adversarial) — `.agent/scripts/check_design_anchors.sh:171`
- [ ] (suggestion) A backtick opener whose info string holds a backtick is inline code, not a fence (CommonMark): a line starting ```` ```x``` is code ```` gives a false "never closed" finding (Claude adversarial, lead reproduced) — `.agent/scripts/check_design_anchors.sh:180`
- [ ] (suggestion) Fence closer edge cases: a trailing tab (`[ \t]*$` allowed by CommonMark) keeps the fence open to EOF (false finding); a closer indented less than the item's content column still closes a list-item fence (rare) — `.agent/scripts/check_design_anchors.sh:157`
- [ ] (suggestion) Headings inside an HTML comment (`<!--` ... `-->`) are registered as anchors, so a link to a commented-out heading passes silently; outside the fix range (unchanged heading scan), none in design.md today (Codex) — `.agent/scripts/check_design_anchors.sh:191`

## Integrated Review
**Status**: complete
**When**: 2026-10-12 09:59 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #380 at `a4dd163`
**Sources**: 4 (Local Review @ `a4dd163` covering via bookkeeping at `70cc024`, Copilot R2 @ `306564b` and R3 @ `a4dd163` with no comments, CI rollup)
**Cross-source confirmations**: 1 (list-marker fence opener: Codex and the Claude adversarial reviewer inside the Local Review)
**CI**: pending (pull_request Lint run failed on the known flaky h17/h18 fixture, #361; the push run on the same SHA passed; failed job re-run)

### Findings
- [x] (should-fix, owner-approved 2026-10-12) Add `.agent/scripts/check_design_anchors.sh` to the `check-design-anchors` hook's `files:` filter, so a checker-only commit runs the checker on the real tree (raised by the fixer and Gemini) — `.pre-commit-config.yaml`
- [x] (cross-confirmed, suggestion) A fence opened on a list-marker line is not recognised (false "never closed"; fails loudly) — deferred to #381 — `.agent/scripts/check_design_anchors.sh`
- [x] (suggestion, Local Review) Backtick opener with a backtick in its info string read as a fence (fails loudly) — deferred to #381 — `.agent/scripts/check_design_anchors.sh`
- [x] (suggestion, Local Review) Fence closer with a trailing tab; closer indented less than the item's content column (fails loudly / rare) — deferred to #381 — `.agent/scripts/check_design_anchors.sh`
- [x] (suggestion, Codex) Headings inside HTML comments registered as anchors (silent, but design.md has no HTML comments) — deferred to #381 — `.agent/scripts/check_design_anchors.sh`
- [x] (note, Claude adversarial) `## _Italic_ title` slug mismatch with GitHub (fails loudly, unchanged slug()) — deferred to #381 — `.agent/scripts/check_design_anchors.sh`

Rule applied (consistent with this timeline's earlier deferral of checker edge cases to a follow-up issue): a checker gap that lets a broken link pass silently in today's files is fixed in this PR; one that fails loudly, or cannot occur in today's files, goes to #381.

### False positives
- (Copilot) Unquoted array expansion at `check_design_anchors.sh:273` — `${LINKS[@]+"${LINKS[@]}"}` quotes each element inside the alternate expansion; no word splitting occurs.
- (Copilot) ADR guard counts register rows instead of matching each ADR — the planned design (plan Wire-in 6), approved in plan review.

## Implementation
**Status**: complete
**When**: 2026-10-12 10:03 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**PR**: #380 at `be04425`
**Addressed**: Integrated Review at `a4dd163` (2026-10-12 09:59 -04:00)
**Commits**: be04425

### Actions
- [x] Add `.agent/scripts/check_design_anchors.sh` to the `check-design-anchors` hook's `files:` filter — `.pre-commit-config.yaml`

## Local Review
**Status**: complete
**When**: 2026-10-12 10:04 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: approved

**PR**: #380 at `1d54c8e`
**Base**: origin/main
**Depth**: Light (reason: re-review of a4dd163..1d54c8e only; one regex alternative in a pre-commit `files:` filter; the whole PR was approved at Deep depth at `a4dd163`)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 2 | **Ship**: ready

Specialists: static (pre-commit `check-design-anchors` and `yamllint` --all-files passed; checker exit 0). Cross-model reviewers: skipped (Light depth; a one-alternative filter change that cannot alter checker behaviour).

### Findings
- [x] Regex anchored and escaped correctly: `\.agent/scripts/check_design_anchors\.sh$` matches the checker, not `.sh.bak`, a nested copy, or `tests/test_design_anchors.sh` (the last is deliberate: tests are covered by validate-script-tests) — `.pre-commit-config.yaml:67`
- [x] The `# yamllint disable-line rule:line-length` comment sits on the line directly above and still applies; yamllint passes — `.pre-commit-config.yaml:66`
- [x] No doc lists the hook's trigger files; `docs/design.md:152` names the hook and script only, so nothing disagrees

## Integrated Review
**Status**: complete
**When**: 2026-10-12 10:10 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #380 at `fbe11ea`
**Sources**: 3 (Local Review light @ `1d54c8e` approved, recorded at `fbe11ea`; Copilot R4 @ `1d54c8e` with no comments; CI rollup)
**Cross-source confirmations**: 0
**CI**: all-pass

### Findings

No open findings. The only change since the Integrated Review at `a4dd163` is `be04425` (the checker added to its hook's `files:` filter, owner-approved), reviewed light and approved; `review_progress.sh sources` lists no open local finding and no GitHub comment at this head.

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-10-12 10:30 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

PR C (wire-in) open questions B1 and B2 from the plan's Open Questions, answered before PR C starts. The plan was approved at revision 6 (2026-10-09); these answers pick the plan's own defaults, so no plan text other than marking them decided changes.

> B1, keep the default, B2 mark it as history

B1: ADRs carry no pointer to their design section; the mapping stays in the Decision register only (Wire-in 3). B2: the roadmap's "Cross-cutting Decisions" section is marked as history with a one-line note pointing at the design sections, "Storage model" and "Progress as lifecycle record" replaced by a pointer to "Review loop and timeline", the rest kept as dated rationale (Wire-in 4).

## Implementation
**Status**: complete
**When**: 2026-10-12 10:42 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-335 at `33da086`

PR C (wire-in), implemented from the plan at revision 11.

- `cde0bec` Skills: review-issue cites `$WS_ROOT/docs/design.md#how-it-works` for the goal an issue serves; plan-task and review-plan cite `$WS_ROOT/docs/design.md#the-design` for the section list and Status key; all three cite the section as `docs/design.md#<section>` and keep the project branch (Wire-in 2)
- `f0f37ca` audit-workspace step 2 sets the register's `Re-examined` cell (`docs/design.md#decision-register`) to `yes <today>`; the "Report, don't fix" bullet names that one exception (A4). design.md's register paragraph now says the audit does this instead of "is meant to"; change-log row added (719 lines)
- `dc4d627` Roadmap: 12 of the 34 open rows get a "design section:" note (Registry and adapters 7, Sessions and roots 2, Review loop and timeline 2, Worktrees 1); 22 open rows and every done row untouched (Wire-in 4)
- `3c363f7` Roadmap: Cross-cutting Decisions marked as history with a pointer to `design.md#the-design`; Storage model and Progress as lifecycle record replaced by a pointer to Review loop and timeline; the other four kept (B2)
- `c53d958` README: one closing sentence under Workspace goals pointing at `docs/design.md#how-it-works`
- `33da086` Plan revision 11: B1 and B2 moved to Decided, change log added
- Already done, not redone: the review guide's work-plan row (Wire-in 5, PR B) and the ADR-0017 link fix (PR A). No ADR edited (B1), no label edited, `brainstorm` untouched

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-12 10:56 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-335 at `eb10efd`
**Base**: main
**Depth**: Standard (reason: governance files — four skills, docs/design.md, roadmap, README; ~166 lines)
**Must-fix**: 2 | **Suggestions**: 5
**Round**: 7 | **Ship**: continue — 2 must-fix include a design/correctness concern (not mechanical)

PR C (wire-in). Specialists: static (pre-commit on the 9 changed files: all passed; `check_design_anchors.sh` exit 0; `test_design_anchors.sh` 46/46; `test_skill_paths.sh` 51/51), governance, plan drift, Claude adversarial (fresh Sonnet sub-agent), cross-model Gemini, Codex, Copilot (all EXIT=0). Both must-fix items are one owner decision on how the audit's register write lands; cross-confirmed by Codex, Gemini and the Claude adversarial.

### Findings
- [x] (must-fix) audit-workspace now edits a tracked file (`Re-examined` cell) but says nothing about where: no worktree, issue, commit or PR; the skill is not on the skill-worktree allowlist, so run from the main tree it edits main — `.claude/skills/audit-workspace/SKILL.md:59`
- [x] (must-fix) "the audit sets it and nothing else" conflicts with design.md's Change log rule (one row per change to the file, in the same change); either exempt date-only `Re-examined` refreshes there or let the audit append the row — `.claude/skills/audit-workspace/SKILL.md:141` / `docs/design.md:632`
- [x] (suggestion) Plan text still frames B1/B2 as open after revision 11: Consequences row "Yes (PR C; B2 open)" and the closing "is **B1**" / "is **B2**" sentences of Wire-in 3 and 4 — `.agent/work-plans/issue-335/plan.md:594`, `:349`, `:364`
- [x] (suggestion) The design.md register-paragraph edit is correct and required (ADR-0017: "is meant to refresh it" became untrue), but plan Files to Change has no PR C design.md row; add it or say so in the PR description — `.agent/work-plans/issue-335/plan.md:519`
- [x] (suggestion) Storage model pointer drops the rejected git-refs (`refs/agent-state`) alternative, which now appears in no tracked doc; owner call whether one line stays under the pointer or goes to Decided Against — `docs/roadmap.md:411`
- [x] (suggestion) Auto-triggering skills (#26) re-shapes the Skill layer named in Instruction layers; candidate for a "design section:" note (the other omissions, coordinator agent included, hold under the rule) — `docs/roadmap.md:190` (deferred: dismissed at Checkpoint 413d259: the Instruction layers section is all proposed, so no design-section note yet)
- [x] (suggestion) review-issue sends the agent to `#how-it-works` "for the goal the issue serves" and then asks it to name a design section; goals live in README per Documentation layers, and How it works does not link every section; consider adding the section list at `#the-design` — `.claude/skills/review-issue/SKILL.md:132`

## Checkpoint
**Status**: complete
**When**: 2026-10-12 11:02 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Pre-push round 7 on PR C (wire-in) at 20cff9d: must-fix M1/M2 (audit-workspace register edit has no landing path; conflicts with the design.md change-log rule), suggestions S1-S5. Round count includes PR B's rounds on the same branch name.

Q1 (how the audit's Re-examined dates land; R1 = audit reports the exact cell changes and offers a one-line PR through the normal issue/worktree flow, R2 = audit commits them itself from a skill worktree, needing an AGENTS.md allowlist change and a change-log exemption):

> Q1, I'm not sure I have the context needed to understand this. Is it consequential enough that I need to look at it closer or are you confident in your recomendation?

Host answer: low consequence (only how a date column is refreshed; worst case under R1 is stale dates; easy to undo); host decides R1 within its limits and records it here.

Q2 (the rejected git-refs storage alternative dropped by the Storage model pointer):

> Q2, move to decided against. We should note that it doesn't mean we can't reconsider stuff in that list later if things change.

Host-decided small items: S1 (plan B1/B2 stale mentions) fix; S2 (plan Files to Change row for the design.md register edit) fix; S5 (review-issue also cites #the-design) fix; S4 (auto-triggering skills roadmap note) skip, its section is all proposed.

## Implementation
**Status**: complete
**When**: 2026-10-12 11:12 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-335 at `e2a6c5b`
**Addressed**: Local Review (Pre-Push) at `eb10efd` (2026-10-12 10:56 -04:00), with the decisions of Checkpoint `413d259`
**Commits**: 8e32b3c, dea968b, 2d197b8, 9ca4361, e2a6c5b

PR C (wire-in), review round 7 addressed. Checks: `check_design_anchors.sh` exit 0; `test_design_anchors.sh` 46/46; `test_skill_paths.sh` 51/51; pre-commit passed on every commit.

### Actions
- [x] M1 (R1): `/audit-workspace` step 2 no longer edits the register; its report lists each `Re-examined` cell change under a new Register updates part (cited via `docs/design.md#decision-register`) and asks the user whether to open a small PR through the normal issue and worktree flow — `.claude/skills/audit-workspace/SKILL.md:59` (8e32b3c)
- [x] M2 (R1): that PR adds the design.md change-log row like any other change; "Report, don't fix" has no exception and says the register dates are reported, not written; design.md's register paragraph states the R1 flow, change-log row added (721 lines) — `.claude/skills/audit-workspace/SKILL.md:150`, `docs/design.md:573` (8e32b3c). Plan agrees: Wire-in 2, section-dates paragraph, Files to Change, Self-Check, Consequences, Decided A4, Estimated Scope, Revision 12 change log (dea968b)
- [x] S1: B1/B2 no longer read as open in the plan (Issue section, Wire-in 3 and 4, Consequences row) — `.agent/work-plans/issue-335/plan.md` (dea968b)
- [x] S2: Files to Change gains a PR C row for the design.md register paragraph — `.agent/work-plans/issue-335/plan.md` (dea968b)
- [x] S3 (owner Q2): git-refs storage alternative added to Decided Against (2026-03-22, wording from the old Storage model text); section intro says an item can be reconsidered if things change — `docs/roadmap.md:256` (2d197b8)
- [x] S4 — `docs/roadmap.md:190` (deferred: dismissed at Checkpoint 413d259, the Instruction layers section is all proposed)
- [x] S5: review-issue also cites `$WS_ROOT/docs/design.md#the-design` for the section list — `.claude/skills/review-issue/SKILL.md:132` (9ca4361)

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-12 11:19 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-335 at `d3d3afc`
**Base**: main
**Depth**: Standard (reason: governance files — four skills, docs/design.md, roadmap, README; whole PR C diff re-classified per fix-round rule)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 8 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

PR C (wire-in), re-review after the round 7 fixes (8e32b3c..d3d3afc). Every Checkpoint `413d259` decision verified: R1 (audit reports the cells, offers a small PR, does not write the register) reads the same in `audit-workspace` step 2 and Guidelines, the design.md register paragraph and plan revision 12 (Wire-in 2, Files to Change, A4, Consequences, Self-Check, Estimated Scope); Q2 git-refs row in Decided Against, date 2026-03-22 traced to `d253141a`, intro sentence added; S1, S2, S5 fixed; S4 dismissed as recorded. Specialists: static (pre-commit on the 9 changed files exit 0; `check_design_anchors.sh` exit 0; `test_design_anchors.sh` 46/46; `test_skill_paths.sh` 51/51; design.md 721 lines matches the last change-log row), governance, plan drift, Claude adversarial (fresh Sonnet sub-agent), cross-model Gemini, Codex, Copilot (all EXIT=0). Dismissed: Gemini "Design picture nested under project-repo block" (it is in step 3, not step 2's project list), Gemini "remove change-log row 719" (rows are append-only per commit; PR B's 708 row corrects 706 the same way), Gemini `$WS_ROOT` unset (each skill defines the idiom; skill-path test passes), Gemini review-plan anchor wording (applies only when a section changes), Claude adversarial "2026-03-22 unsourced" (commit `d253141a`), Claude adversarial push-policy note (judgment within the Wire-in 4 rule, passed round 7).

### Findings
- [x] (suggestion) Register updates lists only the `Re-examined` cell; when the audit finds an ADR newly superseded in practice, applying the listed cells would record `in force | yes <today>` for a drifted ADR; also list the `Standing` cell change in that case — `.claude/skills/audit-workspace/SKILL.md:59`
- [x] (suggestion) "Checked in this revision: step 2 ... says nothing about a register or a date" now sits under the revision 12 header and is untrue after PR C; say "Checked in revision 9" — `.agent/work-plans/issue-335/plan.md:162`

## Checkpoint
**Status**: complete
**When**: 2026-10-12 11:20 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: publish
**Decision**: address

Pre-push round 8 at 0d68805 approved with two suggestions: S1 (audit-workspace Register updates should also list a Standing cell change when an ADR is found superseded in practice) and S2 (plan.md:162 "Checked in this revision" should read "Checked in revision 9"). Host recommendation: fix both, a quick check, then publish.

> fix then publish

## Implementation
**Status**: complete
**When**: 2026-10-12 11:32 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Branch**: feature/issue-335 at `302094d`
**Addressed**: Local Review (Pre-Push) at `0d68805` (2026-10-12 11:19 -04:00), round 8
**Commits**: 6f188fd, 302094d

PR C (wire-in), review round 8 addressed. Checks: `check_design_anchors.sh` exit 0; `test_skill_paths.sh` run; pre-commit passed on both commits. design.md left alone (its register paragraph says the report "lists the cells to change", still true).

### Actions
- [x] S1: `/audit-workspace` step 2 and the Register updates format now also list the `Standing` cell change and one line on what the code does instead when an ADR is no longer `in force`; plan Revision 12 change log gains item 4 — `.claude/skills/audit-workspace/SKILL.md:59` (6f188fd)
- [x] S2: "Checked in this revision" reads "Checked in revision 9" — `.agent/work-plans/issue-335/plan.md:162` (302094d)

## Local Review
**Status**: complete
**When**: 2026-10-12 11:26 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Verdict**: approved

**PR**: #382 at `b2d9cfaa`
**Depth**: Light (reason: user-requested override; scope limited to 6f188fd9 and 302094d5 since the round 8 approval at 0d68805; SKILL.md would otherwise classify Standard)
**Must-fix**: 0 | **Suggestions**: 1

### Findings
- [ ] (suggestion) "what the code does instead" fits `superseded in practice` but not plain `superseded` (a later ADR replaced it, per design.md register paragraph); optionally say "or the ADR that replaced it" — `.claude/skills/audit-workspace/SKILL.md:63`

Cross-model reviewers: none dispatched (Light override requested by host; skipped).

## Integrated Review
**Status**: complete
**When**: 2026-10-12 11:32 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #382 at `0cdc94c`
**Sources**: 4 (Copilot R1 @ `b2d9cfa` 3 inline, Copilot R2 @ `0cdc94c` overview, Local Review light @ `302094d` recorded at `0cdc94c`, CI rollup)
**Cross-source confirmations**: 1 (audit Standing line: Local Review light suggestion + Copilot R2 overview)
**CI**: all-pass

### Findings
- [x] (cross-confirmed, suggestion) The audit's Standing line says "what the code does instead", which fits `superseded in practice` but not `superseded` (a later ADR replaced it); add "or the ADR that replaced it" — `.claude/skills/audit-workspace/SKILL.md`
- [x] (should-fix, Copilot) Issue #335 scope item 3: review-issue and review-plan "cite the goal and design section an issue serves and flag one that serves none or breaks a stated rule". The skills ask only when the work changes the design picture, so ordinary work passes with no alignment check; plan-task records a section only then. The approved plan (Wire-in 2) did not record this as a departure. Owner decision needed: unconditional "Serves" check, or record a departure — `.claude/skills/review-issue/SKILL.md`, `.claude/skills/review-plan/SKILL.md`, `.claude/skills/plan-task/SKILL.md`
- [x] (should-fix, Copilot) review-issue names `#how-it-works` as where the goals are; `docs/design.md` (Purpose, lines 82-84) says the goals are in `README.md` under `## Workspace goals`. Point the goal at `$WS_ROOT/README.md#workspace-goals` — `.claude/skills/review-issue/SKILL.md`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-10-12 11:40 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: findings
**Decision**: address

Q3 from the Integrated Review at 0cdc94c: issue #335 scope item 3 asks review-issue / review-plan to cite the goal and design section an issue serves and flag one that serves none or breaks a stated rule; the skills asked only when the design picture changes. Option A: add an unconditional, light "Serves" line (goal in README Workspace goals, design section by anchor; flag none or a broken rule) to review-issue and review-plan, and plan-task records it in every plan; the design-change question stays separate; project issues use the project's own goals and design doc, or "none", without forcing a convention. Option B: record a departure instead.

> A

## Implementation
**Status**: complete
**When**: 2026-10-12 12:02 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #382 at `8fb5990`
**Addressed**: Integrated Review at `0cdc94c` (2026-10-12 11:32 -04:00), with the owner's decision in Checkpoint `f8d593a` (Option A)
**Commits**: de5baee, 0db388c, 8fb5990

### Actions
- [x] Audit Standing line: for `superseded` it names the ADR that replaced it; "what the code does instead" is for `superseded in practice` (step 2 and the report's Register updates line) — `.claude/skills/audit-workspace/SKILL.md:63`
- [x] Unconditional "Serves" line (Option A): plan-task writes `## Serves` in every plan; review-issue adds `**Serves**` to the Scope Assessment and flags no goal or a broken rule as an Action-needed Principle Alignment row; review-plan checks it under Issue alignment and makes a missing line, no goal or a broken rule a finding; project issues use their own goals and design document or "none"; design-change question unchanged; plan revision 13 records it in Wire-in 2. `docs/design.md` not touched: it does not describe what these skills check — `.claude/skills/review-issue/SKILL.md:128`, `.claude/skills/review-plan/SKILL.md:194`, `.claude/skills/plan-task/SKILL.md:124`, `.agent/work-plans/issue-335/plan.md`
- [x] Goal source points at `$WS_ROOT/README.md#workspace-goals` (anchor checked by hand: `## Workspace goals`, README line 26), not `#how-it-works` — `.claude/skills/review-issue/SKILL.md:130`

## Local Review
**Status**: complete
**When**: 2026-10-12 12:10 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #382 at `003c668`
**Depth**: Standard (reason: skill files are governance triggers; scope 0cdc94c..003c668, earlier commits approved in pre-push round 8)
**Must-fix**: 0 | **Suggestions**: 5

Serves line (Option A) meets issue #335 scope item 3: review-issue and review-plan cite the goal and design section and flag no goal or a broken rule; it reaches the issue comment (Scope Assessment template), the Issue Review entry (verbatim copy) and its Actions (Action-needed row), the Plan Review (Issue alignment Notes; no-findings header) and the plan (`## Serves`). Light and consistent across the three skills; the design-change question stays separate. docs/design.md needs no change (its Review loop table lists what each phase produces, not what it checks). Anchors `README.md#workspace-goals`, `docs/design.md#rules`, `#the-design` resolve; check-design-anchors passes. Cross-model: gemini, codex, copilot all completed.

### Findings
- [ ] (suggestion) "breaks a stated rule (a principle, or a row of docs/design.md#rules)" is not scoped to workspace issues; for a project issue say the project's own rules (plus the workspace principles already applied), so the project branch stays non-forcing — `.claude/skills/review-issue/SKILL.md:136`, `.claude/skills/review-plan/SKILL.md:203`
- [ ] (suggestion) Standing change is listed only when an ADR is "no longer in force"; a move back to `in force` (ADR-0016 Provisional to Accepted, drift resolved) is not reported — list it whenever the checked standing differs from the cell (codex, gemini) — `.claude/skills/audit-workspace/SKILL.md:63`
- [ ] (suggestion) Change-log row says /audit-workspace "now sets" the Re-examined cell, which never held on main; the next row corrects it — fold the two rows into one (copilot rated must-fix; gemini) — `docs/design.md:667`
- [ ] (suggestion) Wire-in 2 still says "The skill text uses only the two real anchors above"; the skills now also cite `docs/design.md#rules` and `README.md#workspace-goals` — `.agent/work-plans/issue-335/plan.md:346`
- [ ] (suggestion) The skills' goal source `README.md#workspace-goals` is outside check_design_anchors.sh's scope (docs/design.md citations only), so renaming that heading breaks three skills silently; note it or extend the check — `.claude/skills/review-issue/SKILL.md:131`

## Integrated Review
**Status**: complete
**When**: 2026-10-12 12:11 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #382 at `0b04393`
**Sources**: 3 (Local Review @ `003c668` recorded at `0b04393`, approved with 5 suggestions incl. Codex/Gemini/Copilot CLI; Copilot PR bot R3 @ `003c668`; CI rollup pending at triage)
**Cross-source confirmations**: 1 (stale change-log row: Copilot CLI inside the Local Review + Local Review lead)
**CI**: pending

### Findings
- [x] (suggestion, Local Review) "Breaks a stated rule (a principle, or a row of docs/design.md#rules)" is not scoped to workspace issues; for a project issue use the project's own rules — `.claude/skills/review-issue/SKILL.md`, `.claude/skills/review-plan/SKILL.md`
- [x] (suggestion, Codex + Gemini via Local Review) audit Register updates lists a Standing change only when an ADR is no longer `in force`; report it whenever the checked standing differs from the cell (e.g. Provisional to in force) — `.claude/skills/audit-workspace/SKILL.md`
- [x] (cross-confirmed, suggestion) design.md change-log row 667 says the audit "now sets" the Re-examined cell, never true on main (row 668 corrects it); both rows are unmerged in this PR, so fold them into one true row — `docs/design.md`
- [x] (suggestion, Local Review) plan Wire-in 2 says "the skill text uses only the two real anchors above"; the skills now also cite `docs/design.md#rules` and `README.md#workspace-goals` — `.agent/work-plans/issue-335/plan.md`
- [x] (should-fix, Copilot PR bot) PR description stale: goal source, Standing wording, revisions 11-12 only (host updates the PR body) — PR #382 description
- [x] (suggestion, Local Review) No check covers the `README.md#workspace-goals` anchor the three skills cite (renaming the heading breaks them silently); deferred to #381 with a comment there (the checker's scope widening is already a follow-up in the plan) — `.agent/scripts/check_design_anchors.sh`

### False positives
- (Copilot PR bot) plan-task:134 and review-plan:238 "Serves only when the design changes" — these are Copilot's R1 comments (original commit b2d9cfa) carried forward to the new head; 8fb5990 added the unconditional Serves line in both skills (plan-task step 3 and `## Serves` template; review-plan "Serves (every plan)" under Issue alignment), confirmed by the Local Review at 003c668.

## Checkpoint
**Status**: complete
**When**: 2026-10-12 12:24 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: findings
**Decision**: address

Integrated Review at 0b04393: S1 (project issues use their own rules), S2 (audit reports any Standing change), S3 (fold change-log rows 667/668), S4 (plan Wire-in 2 anchor count); the host updates the stale PR description; the unchecked README anchor went to #381. Host recommendation: fix S1-S4, quick check, update the description, then the merge decision.

> fix first

## Implementation
**Status**: complete
**When**: 2026-10-12 12:38 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**PR**: #382 at `edf565d`
**Addressed**: Integrated Review at `0b04393` (2026-10-12 12:11 -04:00)
**Commits**: 00f0654, 4891a61, a85cf0b, edf565d

### Actions
- [x] project issues and plans use the project's own rules, not the workspace Rules table — `.claude/skills/review-issue/SKILL.md`, `.claude/skills/review-plan/SKILL.md`
- [x] audit reports any Standing change, including back to in force — `.claude/skills/audit-workspace/SKILL.md`
- [x] change-log rows folded into one true row, line count 720 — `docs/design.md`
- [x] plan Wire-in 2 names the anchors the skills cite; Revision 13 item 4 — `.agent/work-plans/issue-335/plan.md`
- [ ] PR description stale — left open for the host (PR #382 description)
