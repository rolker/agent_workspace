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
