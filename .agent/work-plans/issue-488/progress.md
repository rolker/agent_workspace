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

## Checkpoint
**Status**: complete
**When**: 2026-11-18 09:19 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

The owner chose "Proceed to implementation" after the second Plan Review (verdict ready, five minor findings), with those five findings handed to the implementer as instructions: find part designs among tracked files only, with a test; have --next-steps work from the saved rows; give an unreadable sub-roadmap the result unknown in both places; state one rule for a backtick path inside a file under docs/; and write the third kind of focus (work marked by a sub-roadmap's path) into the design text.

## Implementation
**Status**: complete
**When**: 2026-11-18 09:46 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-488 at `62764641`

Seven commits (plan steps 1 to 6; step 7 left out, see below):

- `check_design_anchors.sh` (step 4, committed first because a modified `.pre-commit-config.yaml` must be staged in every commit while it differs): a part's design is any `design.md` under a `docs/` directory other than the root's, checked against its own headings. One base rule per form, which also answers the second Plan Review's finding 4: a Markdown link resolves from its file's directory; any other citation (backticks or prose) from the citing file's directory first, then from the root, so in a file under `docs/` a backtick path and a link with the same text agree whenever the file exists, and `docs/design.md#x` still means the root's design. A leading `$VAR/` or `/` anchors at the root; a target with a scheme or `//` is skipped. Citers: the old list plus `docs/design.md`, every tracked (`git ls-files`) design or roadmap under a `docs/` directory, and each sub-roadmap the pointer table names with the design beside it. An untracked `worktrees/` copy is never read, which answers finding 1 and is tested. The hook's `files:` filter is widened to `(.*/)?docs/(.*/)?(design|roadmap)\.md`. Seventeen new tests in section (h) of `test_design_anchors.sh`; a later commit builds the fixture's `../` steps from a variable so the hook-scope suite's root-derivation scan does not misread them.
- ADR-0022 "A part owns its inside" (step 1) scopes ADR-0017 without editing it and puts no limit on levels: the checker follows one. Its context records the audit: the 486 text on `main` conforms. The manifest-route bullet on `main` does not, and the #487 branch already trims it (its commit `ea99713d`, "the manifest text in the main design keeps what crosses the boundary"), so no comment on #487 was needed. In `docs/design.md`: the Documentation layers Now paragraph and Direction row (the pointer, each part's next step in every run, and the sub-roadmap path as a third kind of focus; a sub-roadmap's own Paths paragraphs are not read, answering finding 5), the Target's relation to OQ-1, two Rules rows (`hook`; `review only`), register row 0022 and a Change log row. The section is 74 lines, past the 60-line prompt, which the change-log row notes. The review guide's "Keep one current design" row and a new ADR-0022 applicability row are updated.
- `sitrep_checks.sh` (step 2): it follows the `| Sub-roadmap | Root |` table one level with `part` rows: `true`; `unknown` for an unreadable target (finding 3); `unchecked` for broken, circular or repeated pointers, a self pointer, or a sub-roadmap with nothing to check; `not-followed` for a nested pointer. It also prints `subline`, `subdeferral` and `subformat` rows prefixed by the sub-roadmap path. Totals count the root's rows only. `--no-follow` reads the root only, and `--next-steps-from <rows>` works from saved rows (finding 2). Tests (a) to (l) are in section 15.
- Sit-rep (step 3): step 1 prints `--- next steps` from the saved rows, and step 5 reports each part's next step in every run. Part problems go under Problems, and a not-followed pointer goes on a separate line. `sitrep_root.sh --worktrees` reads `subline` rows and adds `named_part`, which step 3 prints as the work's mark and the closing question offers as a focus. `docs/roadmap.md`'s Format paragraph documents the pointer and the citation rule. `update_roadmap.sh` is confirmed to leave sub-roadmaps alone, with a test. `discover_governance.sh` lists no roadmaps, so it needs no change.
- Review skills (step 5): review-issue, review-plan and plan-task accept `<path>/design.md#<section>` for a part. The plugin lists the skill directories in place, so there is no second copy.
- Project-session tests (step 6) in `test_sitrep_root.sh` cover:
  - a project pointing from `docs/roadmap.md` (Root `.`)
  - a project pointing from `ROADMAP.md` (a Root of its own)
  - a workspace session with a broken pointer
  - a worktree named through a sub-roadmap's `gh-issue` check, marked with the sub-roadmap's path

Step 7 is left out. Neither part is on `main`: `git ls-tree origin/main` shows `tools/ros-manifest/docs/` holding only `west-variant.md`, `docs/manifest` is absent, pull request 494 (#486) is open, and #487 is a local branch. So the real pointer rows are not added, and acceptance bullet 3 stays open on the issue. The synthetic tests of steps 2, 4 and 6 are the acceptance that does not depend on them.

Final run: `.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, with no SKIP, passed every hook. `validate-script-tests` ran all 52 suites and all passed. The first run had failed `test_script_tests_hook_scope.sh`, fixed in the last commit.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 10:41 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-488 at `db157fde`
**Base**: origin/main
**Depth**: Deep (reason: 1604 changed lines in 19 files, with governance files: ADR, skills, .pre-commit-config.yaml)
**Must-fix**: 5 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 5 must-fix; first round always re-reviews after fixes

Specialists: static analysis (shellcheck clean on the 7 changed scripts; the anchor check passes on the worktree), governance, plan drift, Claude adversarial, and cross-model gemini and codex (both completed). Reproduced in fixtures: findings 1 and 2. Confirmed by reading the code: findings 3, 4 and 9. Four suites pass: test_design_anchors, test_sitrep_checks, test_sitrep_root and test_update_roadmap.

### Findings
- [x] (must-fix) A backtick or prose citation of a missing part design in a file under docs/ falls back to the root and passes silently. Example: `manifest/design.md#gone` in docs/roadmap.md exits 0. Keep the file-relative target when the root fallback is not a design either, and add a test. Found by gemini, codex and the lead. — `.agent/scripts/check_design_anchors.sh:450`
- [x] (must-fix) `--no-follow` on a Direction section that holds only pointers counts the pointers it suppressed in SCAN_ROWS. The run prints one blank line, and `--summary-from` then exits 2 ("no rows"). Found by gemini, codex and the lead. — `.agent/scripts/sitrep_checks.sh:803`
- [x] (must-fix) A sub-roadmap whose only table is a nested pointer table stays `part ... true read`, and `--next-steps-from` says "none open", a false all-clear. The header says this case is `unchecked` ("no Line or Deferral table"). For a part, count only line and deferral content. Found by the adversarial reviewer and gemini. — `.agent/scripts/sitrep_checks.sh:727`
- [x] (must-fix) `next_steps` uses an empty item as its "none chosen yet" marker, so an open line with an empty Line cell is overwritten by a later one. Test `fres` instead, and add a test. Found by the adversarial reviewer, gemini and codex. — `.agent/scripts/sitrep_checks.sh:269`
- [x] (must-fix) PART_RE checks only a design under a docs/ directory. ADR-0022 decision 6, docs/design.md and the three review skills define `<path>` as any design file's directory, and sitrep_checks.sh follows a sub-roadmap anywhere. So a `tools/x/design.md#x` citation, or the design beside a followed `tools/x/ROADMAP.md`, is never checked, and the hook's `files:` filter does not fire for it. Either check the design beside every followed sub-roadmap, or state the docs/ requirement in the ADR, the design and the skills and report a pointer outside it. Found by the adversarial reviewer and gemini. — `.agent/scripts/check_design_anchors.sh:327`
- [x] (suggestion) The pointer-table parser in the anchor check differs from the one in sitrep_checks.sh. It does not strip CR (a CRLF roadmap gives no pointers), it does not stop at Setext headings, it does not require the 2-cell header, it does not normalise or deduplicate pointer paths (`./docs/x` and `docs/x`), and it does not check that a target stays inside the root. Found by the adversarial reviewer, gemini and codex. — `.agent/scripts/check_design_anchors.sh:398`
- [x] (suggestion) The URL skip treats any `word:` prefix as a scheme, so `main:docs/design.md#broken` is never checked. Require `://` or a known scheme. Found by gemini. — `.agent/scripts/check_design_anchors.sh:435`
- [x] (suggestion) A pointer whose target sits in a nested git repository or submodule is followed, although ADR-0022 decision 8 says a pointer into another repository is not supported. A bare `gh-issue N` there queries the nested repository's origin. Report it as `unchecked`. Found by codex. — `.agent/scripts/sitrep_checks.sh:847`
- [x] (suggestion) `named_part` tries the bare, then owner/repo, then project matches across all parts. It does not pick the first followed sub-roadmap, which is what the header at line 132 says. Found by gemini; the lead confirmed it by reading the code. — `.agent/scripts/sitrep_root.sh:559`
- [x] (suggestion) #486 is now on main (merged in db157fde), and the real `tools/ros-manifest/docs/roadmap.md` is followed correctly (checked with a temporary pointer row). Step 7's #486 half can land now: add the pointer row, and add the root design's link to `tools/ros-manifest/docs/design.md`, which ADR-0022 decision 2 requires and which docs/design.md:474 lacks. Also correct the ADR context's "conforms as it stands". Otherwise record why both halves wait for #487. Found by plan drift and the lead. — `docs/roadmap.md` Direction; `docs/decisions/0022-a-part-owns-its-inside.md:31` (deferred: no pointer row in this pull request (host): the plan makes step 7 conditional on #486 and #487, and #487 (pull request 496) edits the same docs/roadmap.md rows; both rows and the root design's link to tools/ros-manifest/docs/design.md wait for #487. The ADR context is corrected in this commit)

## Implementation
**Status**: complete
**When**: 2026-11-18 10:56 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-488 at `4402b3db`
**Addressed**: Local Review (Pre-Push) at `db157fde` (2026-11-18 10:41 -05:00)
**Commits**: `86ea0b84`, `6cd7bae3`, `5b3b5b9d`, `64c89ea1`, `484c0eb1`, `99135314`, `81abb9d6`, `4402b3db`

Host guidance for this round (mechanism choices within what the owner approved, recorded as the host's): must-fix 5 is fixed in the code to match ADR-0022, docs/design.md and the review skills (a part's design in any directory), not by narrowing the documents to docs/; suggestion 5 adds no pointer row in this pull request, and the ADR context is corrected to what is true on origin/main.

Each fix has a test that fails on the script before the fix (checked by running the suite against the previous version).

### Actions
- [x] (must-fix 1) A backtick citation whose file exists neither beside the citer nor from the root is now an error naming both paths, never a silent fallback (`manifest/design.md#gone` in docs/roadmap.md fails) — `.agent/scripts/check_design_anchors.sh` (`99135314`)
- [x] (must-fix 2) `--no-follow` ignores the pointer table, so a pointer-only section prints the `(no Line or Deferral table)` section row and `--summary-from` counts 0/0 — `.agent/scripts/sitrep_checks.sh` scan_roadmap (`6cd7bae3`)
- [x] (must-fix 3) A nested pointer is not content: a sub-roadmap whose only table points further is `part unchecked` "no Line or Deferral table", and `--next-steps-from` gives it no "none open" — `.agent/scripts/sitrep_checks.sh` scan_roadmap (`6cd7bae3`)
- [x] (must-fix 4) `next_steps` marks "chosen" by the result, so an open line with an empty Line cell keeps its place — `.agent/scripts/sitrep_checks.sh` next_steps (`86ea0b84`)
- [x] (must-fix 5) Any file named design.md other than the root's is a part's design: the one beside every followed sub-roadmap, wherever it is, is read and its links checked, and any citation of it is checked; the hook's `files:` filter takes any `design.md`, `roadmap.md` or `ROADMAP.md`; docs/design.md and the script reference say any directory. Two #335 cases in test (b) change with the rule: `../design.md#` from docs/ and a bare `design.md#` in README.md name the root-level design.md, an error when missing — `.agent/scripts/check_design_anchors.sh`, `.pre-commit-config.yaml` (`99135314`)
- [x] (suggestion 1) One pointer parser: `sitrep_checks.sh --list-pointers` prints the sub-roadmaps it would follow without running a check, and the anchor check reads the table through it (CRLF, Setext end, 2-cell header, `./` dedupe, inside the root, same repository); a failed call is a finding — `.agent/scripts/check_design_anchors.sh`, `.agent/scripts/sitrep_checks.sh` (`484c0eb1`)
- [x] (suggestion 2) Only `://` or a leading `//` makes a URL; `main:docs/design.md#broken` is resolved and fails — `.agent/scripts/check_design_anchors.sh` (`81abb9d6`)
- [x] (suggestion 3) A target or Root in a nested git repository or submodule is `part unchecked` "in another repository", not read, no gh call — `.agent/scripts/sitrep_checks.sh` follow_pointer (`5b3b5b9d`)
- [x] (suggestion 4) `named_part` takes, of the parts each rule finds, the one followed first — `.agent/scripts/sitrep_root.sh` (`64c89ea1`)
- [x] (suggestion 5) ADR-0022's context corrected: on origin/main the root design names the tool only at its boundary but has no link to `tools/ros-manifest/docs/design.md`, which decision 2 requires; that link comes with the tool's pointer row — `docs/decisions/0022-a-part-owns-its-inside.md` (`4402b3db`) (deferred: no pointer row in this pull request, per the host; plan step 7 is conditional on #486 and #487, and #487, pull request 496, edits the same `docs/roadmap.md` rows, so both pointer rows and the design link wait for #487; acceptance bullet 3 stays open)

### Checks
Suites run, each on its own from the worktree:
- `test_design_anchors.sh`: `test_design_anchors: 69 passed, 0 failed`
- `test_sitrep_checks.sh`: `test_sitrep_checks: 252 passed, 0 failed`
- `test_sitrep_root.sh`: `test_sitrep_root: 65 passed, 0 failed`
- `test_skill_paths.sh`: `test_skill_paths: 163 passed, 0 failed`
- `test_update_roadmap.sh`: `test_update_roadmap:16 passed, 0 failed`

`check_design_anchors.sh` on the worktree exits 0. Every commit ran the hooks with `SKIP=validate-script-tests` (owner rule of 2026-11-13, #465). The full pre-commit pass over the branch was left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 11:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-488 at `45b2d243`
**Base**: origin/main
**Depth**: Deep (reason: 1896 changed lines in 19 files, with governance files: ADR, skills, .pre-commit-config.yaml; fix-round re-review classified on the whole diff)
**Must-fix**: 1 | **Suggestions**: 6
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 5), not rising — fix and ship rather than another full round

Specialists: static analysis (shellcheck clean on the 7 changed scripts, yamllint clean on `.pre-commit-config.yaml`, the anchor check exits 0 on the worktree), governance, plan drift, Claude adversarial, and cross-model gemini and codex (both completed). All ten round 1 findings are fixed, apart from suggestion 5, which was deferred by the host until #487 lands. Each code fix has a test that fails on the scripts at `28b2028f`, checked by running HEAD's suites against that tree: 5 failures in test_design_anchors, 7 in test_sitrep_checks and 1 in test_sitrep_root. At HEAD the four suites pass: test_design_anchors 69, test_sitrep_checks 252, test_sitrep_root 65, test_update_roadmap 16.

### Findings
- [x] (must-fix) The citation scan runs awk inside `done < <(citations ...)` and never checks its exit status. When a citer cannot be opened, awk stops and every later citer goes unchecked, yet the hook exits 0. This contradicts the header's "never a silent skip", and it matters more now that any tracked or pointed part file is a citer. Fix: capture the output and check the status first, as `design_records` already does, and pass `--` (or `./`) so that a path containing `=` is not read as an awk assignment. Add a test with an unreadable citer. Found by codex, gemini and the adversarial reviewer, who reproduced it with `chmod 000`. — `.agent/scripts/check_design_anchors.sh:493`
- [x] (suggestion) A pointer to a root-level `ROADMAP.md` adds the citer `./design.md`, which is never normalised. The same file is then loaded a second time as `design.md`, and every finding in it is printed twice. Fix: normalise the path, and add a test. Found by gemini and the adversarial reviewer (reproduced). — `.agent/scripts/check_design_anchors.sh:417`
- [x] (suggestion) The header says "`docs/design.md#x` still means the root's design from any citer". That is false for a citer whose directory has its own `docs/design.md`, for example `tools/t/ROADMAP.md`: the backtick citation resolves to `tools/t/docs/design.md`. Either state the exception in the header and in docs/roadmap.md, or resolve a literal `docs/design.md` from the root first. Add a collision test. Found by gemini and codex. — `.agent/scripts/check_design_anchors.sh:46`
- [x] (suggestion) An angle-bracket link destination, `](<manifest/design.md#x>)`, is not recognised as a link. It gets the prose rule (beside the file, then the root) instead of resolving file-relative only. Found by codex. — `.agent/scripts/check_design_anchors.sh:434`
- [ ] (suggestion) The #488 Change log row records 1189 lines, but the file now has 1190: commit `99135314` added a line and did not update the count. Found by gemini. — `docs/design.md:1136`
- [x] (suggestion) The design text and the skill both say `named_part` comes from a part line's `gh-issue` check. `sitrep_root.sh` also matches `adapter --project` checks and issue numbers in the Line cell, by the same rules as root lines. Found by gemini. — `docs/design.md:105`, `.claude/skills/sitrep/SKILL.md:460`
- [ ] (suggestion) `update_roadmap.sh` still edits `ROADMAP.md` and `docs/ROADMAP.md` beside `docs/roadmap.md`. A sub-roadmap at one of those paths would therefore have its items ticked, although the docs say the updater leaves sub-roadmaps alone; the added test covers only paths outside its candidate list. Either skip a candidate that the active roadmap's pointer table names, or narrow the claim. Found by codex. — `.agent/scripts/update_roadmap.sh:169`
