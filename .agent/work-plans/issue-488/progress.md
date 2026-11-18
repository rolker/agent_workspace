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

## Plan Authored
**Status**: complete
**When**: 2026-11-18 08:30 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-488/plan.md` at `505e7106`

Seven commits: a new ADR-0022 and the design text with the pointer format fixed first (a `Sub-roadmap | Root` table in the Direction section); sit-rep follows pointers one level with `part` problem rows and part lines kept out of the root's totals; sit-rep skill; part-design citations in the anchor check; Serves wording in the review skills; project-session tests; and the manifest pointers last, conditional on #486 and #487 merging.

## Plan Review
**Status**: complete
**When**: 2026-11-18 08:23 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #488 — Sub-roadmaps: a part of a root carries its own goals, design and roadmap, for the workspace and for projects
**Plan**: `.agent/work-plans/issue-488/plan.md` at `505e7106`
**Branch**: `feature/issue-488`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | Seven commits, three scripts, four skills, a knowledge file, the ADR, design and roadmap text, four test files. Large for one PR, but the plan orders it as the Issue Review asked and names the split point (steps 2–3 to a sub-issue). Acceptable with that fallback. |
| Issue alignment | Needs work | Follows the owner's checkpoint decisions (Part owns its inside; new ADR-0022 beside ADR-0017, no edit to 0017) and every Issue Review action: pointer format first and naming the Root, citation form, broken/circular pointer reporting, totals, conditional acceptance. Gaps: the default next-step rule does not meet acceptance bullet 3 (finding 2), and the Serves line names no README goal. Serves as checked: "How I interact with the system and keep track of what's relevant" and "Keep one current design" — `docs/design.md#documentation-layers`; the anchor resolves (Documentation layers, line 87), but the first is a quote from `docs/roadmap.md` line 7, not a section of `README.md#workspace-goals`, and the second is a principle (finding 3). |
| File targeting | Needs work | Scripts, tests, skills and design text are the right set. `check_design_anchors.sh`'s citer list (README, onboarding, `docs/roadmap.md`, skills, knowledge) misses the files where part citations will actually live (finding 1). |
| Consequences | Needs work | Table is thorough. Missing: the sitrep skill's "named work" matching for `gh-issue` checks in sub-roadmap lines (finding 5); the Registry and adapters manifest-route bullet against the new rule (finding 4). |
| Principle alignment | Good | One level, no cross-repo pointers, run record unchanged ("Only what's needed"); broken pointers reported, not skipped ("Enforcement over documentation"); prior art stated (Cargo/Bazel members, existing `--root`/`--roadmap`, `slug()`); Design Picture names `docs/design.md#documentation-layers`. |
| ADR compliance | Good | ADR-0017 scoped by a new ADR-0022, ADR-0008 respected; 0022 is free (highest in `docs/decisions/` is 0021, no local or remote branch carries a 0022). ADR-0018 delivery copy is checked in step 5. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[File targeting] Major** — The part-citation rule does not fit where part citations will appear. The plan resolves `<path>/design.md#x` relative to the citing root, but (a) the citer list in `check_design_anchors.sh` (lines 286–289) is README, onboarding, `docs/roadmap.md`, skills and knowledge; the places that will cite a part's sections are `docs/design.md` (the root's pointer at the part), `docs/roadmap.md`, and the part's own roadmap and design, and only one of those is scanned; (b) Markdown links in `docs/` resolve relative to the file, as both drafts write them (`[manifest/design.md](manifest/design.md)` in `docs/design.md` and `docs/roadmap.md` on `feature/issue-487`; `../../tools/ros-manifest/docs/design.md` in `docs/manifest/design.md`), so `manifest/design.md#x` written in `docs/roadmap.md` would be resolved as `<root>/manifest/design.md` and fail, or must be read file-relative; the existing relative-form regex excludes a leading `/`, so today it is simply unseen; (c) a URL such as `https://github.com/<owner>/<repo>/blob/main/docs/design.md#x` matches the "any prefix" root form today and becomes "any other path" → a missing-file error under the new rule, although the plan says URL citations are not checked. Resolution: state each form's base (backtick citation root-relative; Markdown link target file-relative), exclude `scheme://` prefixes explicitly, add `docs/design.md`'s links to part designs, each followed sub-roadmap and each part design to the citers (from the pointer table or a glob), widen the hook `files:` filter to match, and test `manifest/design.md#x` from `docs/roadmap.md`, `docs/manifest/design.md#x` from a skill, and a URL citation.
2. **[Issue alignment] Major** — Step 3 makes the part's next step appear only "when the root has none left, or when asked". The root's Direction section will have open lines for the foreseeable future, so a default `/sitrep` would not report the manifest sub-roadmap's next step, which is acceptance bullet 3. Report, in every run, each followed part's first line not true (marked by its sub-roadmap path), beside the root's next step, and make the step 7 check test that.
3. **[Issue alignment] Minor** — Serves: name a section of `README.md#workspace-goals` (likely "Trust, control and information", with "Light touch on projects" or "Modular" for the project case), not a quote from `docs/roadmap.md` and a principle. The same fix applies to the Issue Review's Serves line it copied.
4. **[Principle alignment] Minor** — Step 1 adds a "Rules table row for the new check" without saying which rule or check. The rule that matters, "the root's design describes a part only by what crosses its boundary", has no machine check; say it is `review only` and add the matching row to `principles_review_guide.md`. The plan also asserts the rule "applies to both examples as written" without checking: `docs/design.md`'s Registry and adapters manifest-route bullet (around lines 424–462) holds the route's mechanics, and the 487 branch keeps that text unchanged while `docs/manifest/design.md` also describes "the route step by step". Either confirm in the plan that the bullet states only what crosses the boundary (settings, registry line, resolver install) or name trimming it as a consequence, here or in #487.
5. **[Consequences] Minor** — The sitrep skill marks work in flight as named by a Direction line through its `gh-issue` checks (SKILL.md around lines 244–257, and the Path marking around 287–321). Sub-roadmap lines carry `gh-issue 486 closed` and `gh-issue 436 closed` (487 draft). Say whether `subline` checks name work in flight and which path such work is marked with, and test it. Also tidy the citation-form wording: "`<path>` is the part's directory" contradicts the examples, which include the part's `docs/` (`tools/ros-manifest/docs/design.md#x`); say `<path>` is the design file's directory.

### Summary

The plan follows the owner's decisions and covers every Issue Review action with concrete mechanism choices listed for veto; the pointer format, depth limit, problem reporting and totals rule are sound. It needs work on two points before implementation: the anchor check's citation forms and citer scope must match how the parts' documents actually link (file-relative Markdown links, citations in `docs/design.md`, part roadmaps and designs, URLs), and the sit-rep must report each part's next step in a default run, or acceptance bullet 3 is not met.

### Recommended Actions

- [ ] Define the base of each part-citation form (backtick root-relative, Markdown link file-relative), exclude URLs, extend the citer list and hook filter to `docs/design.md`'s part links, followed sub-roadmaps and part designs, and add the tests named in finding 1.
- [ ] Change step 3 so every run reports each followed part's next step by its path, and test it.
- [ ] Replace the Serves goal with a `README.md#workspace-goals` section name.
- [ ] Name the Rules row ADR-0022 adds, mark the boundary rule `review only` with a review-guide row, and check the Registry and adapters manifest-route bullet against the rule.
- [ ] Say how `gh-issue` checks in sub-roadmap lines feed the sit-rep's named-work and path marking; fix the `<path>` wording.

## Checkpoint
**Status**: complete
**When**: 2026-11-18 08:59 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: revise

The owner chose "Revise the plan" for the Plan Review's five findings and for one instruction of his own.

His instruction on nesting, in his words (2026-11-18): "The excuses for sticking to one level are just minor technical ones, so sure, only support one level with the scripts, and that actually probably makes sense when looking at the big picture to not get bogged down in details, but I see no reason to not allow however many levels of planning and design I need for my work."

As put to him and accepted: the decision record puts no limit on levels of planning and design; one level is stated as what the checker follows today; and a pointer inside a sub-roadmap is listed as "not followed", not as a problem.

He chose "Keep both" for the planner's two other choices: a part's lines do not count in the root's totals, and a pointer to a roadmap in another repo is deferred until there is a case.

## Plan Authored
**Status**: complete
**When**: 2026-11-18 09:00 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-488/plan.md` at `05cd445e`

Revision after the Plan Review and the owner's `revise`. The decision record sets no limit on levels; the checker follows one, and a nested pointer is "not-followed", not a problem. Anchor citations get a base per form (backtick from the root, link from the file), a scheme skip and a wider citer list and hook filter; the default sit-rep reports each part's next step by path (`--next-steps`, tested); Serves names README goals; the boundary rule is review only with a review-guide row, and the audit finds the 487 manifest-route bullet needs a trim; sub-roadmap `gh-issue` checks name work in flight, marked by the sub-roadmap path.

## Plan Review
**Status**: complete
**When**: 2026-11-18 09:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #488 — Sub-roadmaps: a part of a root carries its own goals, design and roadmap, for the workspace and for projects
**Plan**: `.agent/work-plans/issue-488/plan.md` at `05cd445e`
**Branch**: `feature/issue-488`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | Unchanged in size: seven commits over three scripts, four skills, the ADR, design and roadmap text and four test files. The order the Issue Review asked for is kept, and the split point (steps 2 and 3 to a sub-issue) is named. Acceptable with that fallback. |
| Issue alignment | Good | Follows the owner's decisions: "Part owns its inside", a new ADR-0022 beside ADR-0017 for the workspace and for projects, no limit on levels in the record with one level named as the checker's, a nested pointer as `not-followed` (not a problem), part lines out of the root's totals, cross-repo pointers deferred. Every Issue Review action is covered, and acceptance bullet 3 is now met in a default run (`--next-steps`, step 3, checked in step 7). Serves as checked: `README.md#trust-control-and-information`; for project work `README.md#light-touch-on-projects` — falls under `docs/design.md#documentation-layers`. Both goal headings exist (`README.md` lines 50 and 80) and the design anchor resolves (line 87). |
| File targeting | Good | Right set. Part designs and followed sub-roadmaps are now citers, and the hook filter is widened. One discovery rule needs narrowing (finding 1). |
| Consequences | Good | Adds the manifest-route trim, named work through sub-roadmap `gh-issue` checks, the review-guide row and the hook filter. The Paths marking is the one gap (finding 5). |
| Principle alignment | Good | The boundary rule is `review only` with a review-guide row, and the audit is done rather than asserted. I checked it: `main`'s `docs/design.md` names the resolver only at the CLI boundary (lines 451-465), and on `feature/issue-487` the manifest-route bullet (lines 402-430) mixes boundary facts with route mechanics (the flock on `configs/.lock.source`, the relinked directory, what `validate` compares, `env.sh`) that `docs/manifest/design.md` also gives. Prior art and Design Picture are stated. |
| ADR compliance | Good | ADR-0022 scopes ADR-0017 without editing it (ADR-0008); 0022 is still free (highest is 0021, and no branch carries a 0022); the ADR-0018 delivery copy is checked in step 5. |
| ROS conventions | N/A | Workspace plan. |

### Earlier findings (Plan Review at `505e7106`)

1. Anchor check forms and citer scope: **resolved**. Each form has a base (backtick from the root, Markdown link from the file), a scheme is skipped first, the citers now include `docs/design.md`'s part links, followed sub-roadmaps and part designs, the hook filter is widened, and the tests named in the finding are listed. Findings 1 and 4 below are smaller points in the same area.
2. Part's next step in a default run: **resolved**. Every run reports each followed part's first line that is not true, by sub-roadmap path, from `--next-steps`, tested in step 2 (j) and checked in step 7. Finding 2 below concerns how the skill calls it.
3. Serves: **resolved**. It names two `README.md#workspace-goals` sections, and both anchors exist. The Issue Review's own Serves line stays as written because it is history.
4. Rules row and boundary audit: **resolved**. There are two named rows: the part-citation check (`hook`) and the boundary rule (`review only`, with a new review-guide row under "Keep one current design"). The audit was done and matches the branch: the 486 text conforms, and the 487 bullet needs a trim, done here or recorded on #487.
5. Named work through `gh-issue` in sub-roadmap lines, and the `<path>` wording: **resolved**. `subline` rows feed the `named` match, test (k) and the step 6 project case cover it, and `<path>` is now the design file's directory. Finding 5 below covers the Paths side of the marking.

### Findings

1. **[File targeting] Minor** — "Any `docs/**/design.md` below the root" sweeps untracked trees. The main checkout holds `worktrees/` (git-ignored, `.gitignore:15`), and today that contains `worktrees/workspace/issue-workspace-486/tools/ros-manifest/docs/design.md`, `.../issue-workspace-487/docs/manifest/design.md` and every worktree's `docs/design.md`. If this is built as written, a `make lint` or a `script check_design_anchors.sh` sit-rep check run in the main checkout would check stale drafts of other branches. A `.venv` or a project checkout inside the root could do the same. Resolution: list part designs with `git ls-files` (tracked files only, the same regex as the widened hook filter), in addition to the design beside each followed sub-roadmap, and add a test with an untracked `worktrees/x/docs/design.md` holding a broken link that is not reported.
2. **[Approach] Minor** — `--next-steps` as described runs the checks again. The skill already runs the checks once, saves the rows and counts from them (`--summary-from`), so a second run doubles the `gh` calls and can disagree with the rows shown. Since `subline` items carry the sub-roadmap path, derive the next steps from saved rows (for example `--next-steps-from <rows-file>`, with the same exit-2 and exit-3 rules as `--summary-from`), and test that it agrees with the rows.
3. **[Approach] Minor** — The plan is inconsistent about an unreadable target. The Mechanism decisions list it with the broken pointers (result `unchecked`), but step 2 gives it `unknown`, which matches the checker's existing roadmap-not-readable rule. Pick `unknown` in both places. Step 3 already sends both to Problems.
4. **[Approach] Minor** — Relative backtick citations will behave in a way that surprises writers. In a `docs/` citer, a backtick `design.md#x` keeps today's meaning (the root's design, so in effect file-relative), but a backtick `manifest/design.md#x` in the same file is root-relative and fails as a missing file, which test 4 expects. Either say this in the script header and the `docs/roadmap.md` Format paragraph, with the message for that case naming the two working forms, or make backtick citations in a `docs/` citer resolve file-relative first, so both readings agree.
5. **[Consequences] Minor** — The plan changes the meaning of Paths but leaves that out of the design text. The skill marks named work `Path 1` today (`.claude/skills/sitrep/SKILL.md` line 427), and the Direction row in `docs/design.md#documentation-layers` says a Paths paragraph names "the two paths the owner runs in parallel" and that work is marked with the path it serves. The plan marks work named through a sub-roadmap with the sub-roadmap's path and offers that in the closing question "beside the root's Paths", which is a third kind of focus. Say this in the Direction row's design text (step 1). Also say what happens to a sub-roadmap's own Paths paragraph: ignored, or shown under the part.

### Summary

The revision resolves all five findings of the earlier review and follows the owner's nesting instruction exactly: the record sets no limit on levels, the checker follows one, and a nested pointer is `not-followed`, not a problem. The five new findings are small and can be fixed in the step they belong to without another plan round. The one most likely to cause harm if built as written is finding 1 (the part-design glob sweeping git-ignored worktrees).

### Recommended Actions

- [ ] Step 4: find part designs with `git ls-files` plus the designs beside followed sub-roadmaps, not a filesystem glob; test that an untracked `worktrees/` copy is ignored.
- [ ] Step 2: derive `--next-steps` from saved rows, not from a second run of the checks; test that it agrees with the rows.
- [ ] Use `unknown` for an unreadable sub-roadmap in both the Mechanism decisions and step 2.
- [ ] Step 4: state, or remove, the different bases for relative backtick citations in a `docs/` citer.
- [ ] Step 1: write the sub-roadmap path as a focus in the closing question into the Direction row of `docs/design.md#documentation-layers`, and say how a sub-roadmap's own Paths paragraph is treated.
