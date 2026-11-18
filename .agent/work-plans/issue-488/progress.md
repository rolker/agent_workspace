---
issue: 488
---

# Issue #488 — Sub-roadmaps: a part of a root carries its own goals, design and roadmap, for the workspace and for projects

## Issue Review
**Status**: complete
**When**: 2026-11-17 14:57 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #488

### Scope Assessment

**Well-scoped?** Partly. The five items hang together as one concept, but they touch the design doc, `sitrep_checks.sh`/`sitrep_root.sh`, four skills, `check_design_anchors.sh` and tests for two session kinds. One PR is possible only if the concept is fixed first. Suggest the plan order it as concept and design text, then sit-rep, then anchors and skills, then the project-session case, as separate commits (or sub-issues if the sit-rep part grows).
**Right repo?** Yes. All of it is workspace infrastructure; the issue itself says the project case works through the same scripts.
**Serves**: "How I interact with the system and keep track of what's relevant" (the sit-rep following a pointer) and "Keep one current design" — `docs/design.md#documentation-layers`
**Design picture?** Changes `docs/design.md#documentation-layers` (the Target block already proposes a project's own mapping of the seven roles, which overlaps) and touches the sit-rep description in the Direction row. The issue names the design update but records no owner decision on the boundary, so this goes to the owner.
**Dependencies**: #486 (manifest tool's own documents; PR 494 not merged) and #487 (workspace manifest documents; local branch only). The issue says to finish after them. Both exist as drafts, so the plan can be shaped from them now, but the third acceptance bullet (sit-rep reports the manifest sub-roadmap's next step) cannot be shown until both merge.

What the two real cases show that the issue text does not say (read from `origin/feature/issue-486:tools/ros-manifest/docs/roadmap.md` and `feature/issue-487:docs/manifest/roadmap.md`):

- They differ in root. The tool's roadmap says its check paths are relative to the tool's directory (`--root tools/ros-manifest`); the workspace's manifest roadmap says its paths are relative to the workspace root. The pointer therefore has to say, or imply by rule, which root a sub-roadmap's checks run against. The checker already takes `--root` and `--roadmap` separately, so this is a pointer-format decision, not a checker change.
- The tool is meant to move to its own repo. After that, `gh-issue` checks in its roadmap need `owner/repo#N` form, and a pointer into another repo is a different case from a pointer to a directory.
- Neither sub-roadmap names a goal section in `README.md`, so "Serves" for work inside a part needs a rule: the part's goals, plus the root goal the part serves.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | Decide with the owner where the boundary sits between the root's design and a part's design, and whether it needs an ADR beside ADR-0017. ADR-0008 allows only status notes and typo fixes on an accepted ADR, so the boundary is either a new ADR or a decided block in `docs/design.md` citing this issue. Ask this on its own, not folded into plan review. |
| Ask about what matters, and show how much | Watch | The design-boundary question above is the one for the owner. The pointer format, cycle and depth limits are mechanism choices the plan can make and list. |
| Put each thing at the level it applies to | OK | A part's design owns the part, the root keeps how it fits and a pointer; this is the principle applied. |
| Only what's needed | Watch | Two real cases (#486, #487) justify the concept. Keep it to one level of nesting unless a case needs more, and say so in the plan. |
| Verify before claiming | Watch | The "State, checked 2026-11-16" claims are accurate: `sitrep_checks.sh` takes `--roadmap` and `--root`, `sitrep_root.sh` picks the first of `docs/roadmap.md` / `ROADMAP.md`, and `check_design_anchors.sh` checks only the root's `docs/design.md`. The plan should still re-read them. |
| Enforcement over documentation | Watch | A pointer that is only prose will rot. The root's Direction line should be machine-read (the sit-rep follows it) and a broken pointer (missing file, cycle) should be reported, not silently skipped. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0017 (design.md is the one current picture) | Yes | A second design document needs a stated boundary; see the Action row. |
| ADR-0008 (addenda in ADRs) | Yes | Limits how ADR-0017 can be amended in place. |
| ADR-0013 (progress.md vocabulary) | No | No new entry type. |
| ADR-0011 / ADR-0019 (adapter contract, project types) | Watch | Only if project-session behaviour is routed through the adapter; the sit-rep uses `sitrep_root.sh`, so likely not. |

### Consequences

- `docs/design.md`: Documentation layers (Now and Target), the Direction row, and the Rules table if a new check is enforced; update the Decision register if an ADR is added.
- `.agent/scripts/check_design_anchors.sh` header: it treats "any prefix" before `docs/design.md#` as a citation of the root's design. A citation of `tools/ros-manifest/docs/design.md#x` would match that pattern and be checked against the root's headings, so the plan must define the form for a part's design and test that this case is not misread.
- Skills: `review-issue`, `review-plan`, `plan-task` (Serves wording), `sitrep` (roadmap discovery, run record counts per root: say whether sub-roadmap lines are counted in the root's totals), and `.agent/knowledge/principles_review_guide.md`.
- `update_roadmap.sh` and `discover_governance.sh`: confirm they ignore or handle a sub-roadmap (the issue already flags the first).
- `sitrep_checks.sh` header grammar and `docs/roadmap.md` Format paragraph: document the pointer.
- Tests: `test_sitrep_checks.sh`, `test_sitrep_root.sh`, `test_design_anchors.sh` with a synthetic project, in workspace and project sessions; include a missing target, a cycle and a sub-roadmap with its own root.

### Recommendations

- Put the boundary question (and the ADR question) to the owner before the plan is committed, with a proposed answer from the two drafts.
- In the plan, fix the pointer format first, and have it state the sub-roadmap's root as well as its file, since the two real cases differ.
- Define the citation form for a part's design and add an anchor-check test that `<part>/docs/design.md#x` is not resolved against the root's design.
- Decide, and test, how a broken or circular pointer is reported by the sit-rep, and how the sub-roadmap's next step is marked (by its own path name) in the report.
- State whether sub-roadmap lines count toward the root's run-record totals.
- Make the third acceptance bullet conditional on #486 and #487 merging, and say in the issue or plan that the synthetic tests are the acceptance that does not depend on them.


### Actions
- [ ] Decide with the owner where the boundary sits between the root's design and a part's design, and whether it needs an ADR beside ADR-0017. ADR-0008 allows only status notes and typo fixes on an accepted ADR, so the boundary is either a new ADR or a decided block in `docs/design.md` citing this issue. Ask this on its own, not folded into plan review.
- [ ] Put the boundary question (and the ADR question) to the owner before the plan is committed, with a proposed answer from the two drafts.
- [ ] In the plan, fix the pointer format first, and have it state the sub-roadmap's root as well as its file, since the two real cases differ.
- [ ] Define the citation form for a part's design and add an anchor-check test that `<part>/docs/design.md#x` is not resolved against the root's design.
- [ ] Decide, and test, how a broken or circular pointer is reported by the sit-rep, and how the sub-roadmap's next step is marked (by its own path name) in the report.
- [ ] State whether sub-roadmap lines count toward the root's run-record totals.
- [ ] Make the third acceptance bullet conditional on #486 and #487 merging, and say in the issue or plan that the synthetic tests are the acceptance that does not depend on them.

## Checkpoint
**Status**: complete
**When**: 2026-11-18 08:20 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

The owner answered three questions put to him at this checkpoint, each by choosing the first option offered:

- Q1, where the boundary sits between the root's design and a part's design: "Part owns its inside". As the option was described to him: the root's design describes a part only by what crosses its boundary and points at the part's design, which is the one current picture of that part. It applies to both manifest examples as written.
- Q2, where the boundary rule is written down: "A new decision record". As described: a new ADR beside ADR-0017 states the rule for parts, for the workspace and for projects.
- Q3, whether to go on to planning with those answers and with the review's remaining actions as instructions to the planner: "Proceed to planning".

The remaining actions of the Issue Review are instructions for the plan, not owner decisions: fix the pointer format first and have it name the sub-roadmap's root; define how a part's design is cited and test the anchor check against it; decide how a broken or circular pointer is reported; say whether sub-roadmap lines count in the root's totals; make the acceptance that depends on the two manifest pull requests conditional.
