---
issue: 551
---

# Issue #551 — Where a project keeps its goals, design and roadmap

## Issue Review
**Status**: complete
**When**: 2026-11-23 17:08 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #551

### Scope Assessment

**Well-scoped?** Watch: one PR is possible only if the three readers' changes are small. The issue touches six readers (`sitrep_root.sh`, `update_roadmap.sh`, `check_design_anchors.sh`, `onboard-project`, `audit-project`, design-discussion), one setting grammar, a footprint question and the design text. Suggest two PRs: (1) setting keys, validation and the three scripts, with tests; (2) the skills' question and wording. The three open questions need the owner's answer first.
**Right repo?** Yes. Workspace: `.agent/scripts/`, `.claude/skills/`, `docs/design.md`. No project repo is changed.
**Serves**: Projects keep their own documents (the goal on where each level's documents live, and a project asked to keep none of it, "Put each thing at the level it applies to"); `docs/design.md#documentation-layers` (also `docs/design.md#registry-and-adapters` for the settings file).
**Design picture?** Changes `docs/design.md#documentation-layers` (its Target, and the Open question OQ-1 it answers) and the roadmap's Direction Format paragraph. The design change goes to the owner on its own (see the three questions below; the issue itself says so).
**Dependencies**:
- #393 (open): the records lookup. It shares the settings file and `project_setting.sh`, and one open question here is whether they share a lookup. It does not block this issue (see Q1).
- #370 (open): design-discussion's Part 2 depends on this issue.
- #452 (open, driven at the same time): edits `.claude/skills/onboard-project/SKILL.md` and `.claude/skills/audit-project/SKILL.md` for its Copilot review item. This issue also edits both (step 3 and 5 of onboard-project; audit-project's `ARCHITECTURE.md` / `docs/design.md` check). Different sections, but expect a textual merge conflict: land #452 first or rebase on it.
- The roadmap lists this as a Path 2 line, `A project says where it keeps its goals, design and roadmap (#551)`, check `gh-issue 551 closed`: nothing to add.

### What is already decided, and what is open

**Q1. One lookup shared with #393, or a separate one?**
- Recorded: #393 builds "one place that answers where are the records (work plan and progress timeline) for this project and this issue", fed by `location`, `location_path`, `tracking` (#393 body, Mechanism 1; `docs/design.md#worktrees` Target). Its unsettled list (tracking=repo commits, `--work-plans-dir`, package repos, defaults) does not mention goals, design or roadmap. The owner's comment on #393 only says #551 "may share this records lookup; that is one of its open questions".
- Not recorded anywhere: whether documents and records share a lookup. Open.
- Difference of kind: records are per issue, per worktree, written by every phase, with a tracking mode and a merge gate. Documents are per project, read mostly, stable paths. The two share only the storage (the settings file) and the writer (`project_setting.sh`), and #332 already built that.
- Recommendation: separate keys in the same settings file (for example `goals`, `design`, `roadmap`, each a project-relative tracked path, optionally `path#heading`), one small resolver function beside `project_records_default` in `_project_registry.sh` that the six readers call. Do not wait for #393 and do not fold documents into its lookup. Undoing it costs little: the keys are three lines in `.agent/projects.d/<name>`, the resolver is one function, and merging later into #393's lookup is a rename inside that function; the readers call the resolver, not the file. Folding into #393 now would cost more to undo (couples this to an unbuilt mechanism and its open merge-gate redesign, see the 2026-11-23 comment on #393).

**Q2. Which kinds of location, and how ADR-0022 parts relate?**
- Recorded: `docs/design.md#documentation-layers` Now: "Each project maps each role to a file, a section of a file, a place outside the repository, or nothing." The Target is `proposed`: "Where that mapping is kept is not decided", and OQ-1 (`docs/design.md#open-questions`, owner) asks it. So the roles may already be sections, outside places or nothing; where the mapping is stored is the open part.
- Recorded for parts: ADR-0022 rule 4, "The root's roadmap points at a part's roadmap in its `## Direction` section, with a `| Sub-roadmap | Root |` table"; the design says a part with documents of its own "is one instance of such a mapping, inside a root; it does not answer OQ-1". `check_design_anchors.sh` and `sitrep_checks.sh` already follow that table one level.
- Open: whether the setting accepts (a) a tracked path in the project, (b) a path outside the project, (c) a separate repository, (d) "nothing".
- Recommendation: first version accepts (a) with an optional `#heading` for a section, and (d) as an explicit `none` (so "no goals document" is an answer, not an unset question). Refuse (b) and (c): a session works only under its root (`docs/design.md#sessions-and-roots`), the sit-rep reads the session root's files, and `check_design_anchors.sh` scans tracked files; an outside document would need the same named bend #393 needs for records. The setting names the root's own documents; a part's documents stay named by the root's pointer table only, and a setting naming a file the table also names is reported by `audit-project`, not resolved twice. Undoing it: adding (b) or (c) later is additive (a wider validator); narrowing later would break projects that stored an outside path, so start narrow.

**Q3. How the design text describes a location that varies**
- Recorded: Documentation layers table says "Where it lives for the workspace" (already the workspace's own mapping, not a rule); the Direction row hard-codes `docs/roadmap.md`; the Target says the sit-rep checks "`docs/roadmap.md`, else `ROADMAP.md`"; the Direction Format paragraph describes the grammar, not the location. `update_roadmap.sh` reads three candidates (`ROADMAP.md`, `docs/ROADMAP.md`, `docs/roadmap.md`), the sit-rep two, so the readers disagree today.
- Open: the wording.
- Recommendation: the Target drops "not decided" and says the mapping is the three keys in the settings file, with the fixed search as the fallback for an unset key; OQ-1 is marked answered by #551; the Direction row keeps saying the workspace's own file; the Format paragraph gains one line: the grammar applies to the file the roadmap key names. One shared candidate list in the resolver ends the sit-rep/`update_roadmap.sh` disagreement. Undoing: text only.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | Changes `docs/design.md#documentation-layers` (Target status `proposed` to decided, OQ-1 answered) and the roadmap Format paragraph. The issue says the design change goes to the owner on its own; bring Q1 to Q3 to him as one design question with the recommendations above before the plan, then update the sections and the changelog in the same PR (ADR-0017). |
| Put each thing at the level it applies to | OK | Per-project setting in the project's settings file; a part's documents stay with the root's pointer table (ADR-0022). |
| A project is never forced | OK | "Decide later" and unset keeps today's fixed search. |
| Only what's needed | Watch | Six readers plus a skill question; one resolver function keeps it to one place. Do not add the outside-path and repository kinds without a case. |
| Enforcement stays with the code | Watch | Tests for the resolver (set, unset, `none`, bad path, a part also named in the pointer table) and for each reader following it. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0017 (one current design) | Yes | Design text and changelog in the same PR. |
| ADR-0022 (a part owns its inside) | Yes | The setting names the root's own documents; the pointer table stays the way to name a part's. |
| ADR-0013 (progress timeline) | Yes | Entry persisted by this review. |
| ADR-0016 (session roots) | Watch | Refusing outside paths keeps "a session works only under its root". |
| ADR-0009 (no bare pip) | No | |

### Consequences

- `docs/design.md`: Documentation layers (Target, Now sit-rep and `update_roadmap.sh` candidate text), Registry and adapters (new keys), Open questions (OQ-1), changelog; `docs/roadmap.md` Format paragraph.
- `_project_registry.sh` header (key grammar, `unused_settings`), `project_setting.sh` help, `.agent/knowledge/script_reference.md`, `check_design_anchors.sh` and `sitrep_checks.sh` headers, and their tests (`test_update_roadmap.sh` and the sit-rep tests).
- `onboard-project` and `audit-project` `SKILL.md`, the design-discussion skill; regenerate nothing else.

### Recommendations

- Bring the three design questions to the owner as one question with the recommendations above (separate keys in the same settings file with one shared resolver; tracked project paths with optional `#heading` and an explicit `none`, no outside paths or repositories in the first version; Target, OQ-1 and Format wording as listed) before `plan-task`.
- Sequence after #452, or rebase on it, because both edit `onboard-project` and `audit-project` `SKILL.md`.
- Plan two PRs: setting keys, resolver, script readers and tests; then the skills' question and the design-discussion "ask when unset".
- State in the plan the single candidate list the resolver uses, so `update_roadmap.sh` and `sitrep_root.sh` stop disagreeing about `docs/ROADMAP.md`.

### Actions
- [ ] Changes `docs/design.md#documentation-layers` (Target status `proposed` to decided, OQ-1 answered) and the roadmap Format paragraph. The issue says the design change goes to the owner on its own; bring Q1 to Q3 to him as one design question with the recommendations above before the plan, then update the sections and the changelog in the same PR (ADR-0017).
- [ ] Bring the three design questions to the owner as one question with the recommendations above (separate keys in the same settings file with one shared resolver; tracked project paths with optional `#heading` and an explicit `none`, no outside paths or repositories in the first version; Target, OQ-1 and Format wording as listed) before `plan-task`.
- [ ] Sequence after #452, or rebase on it, because both edit `onboard-project` and `audit-project` `SKILL.md`.
- [ ] Plan two PRs: setting keys, resolver, script readers and tests; then the skills' question and the design-discussion "ask when unset".
- [ ] State in the plan the single candidate list the resolver uses, so `update_roadmap.sh` and `sitrep_root.sh` stop disagreeing about `docs/ROADMAP.md`.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 18:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

The owner answered the issue review's two open design questions (2026-11-23):
- Q1, one lookup shared with issue 393 or separate: "Separate, same file (Recommended)". Documents get their own settings (`goals`, `design`, `roadmap`) in `.agent/projects.d/<name>`, read through one helper all six readers call; this issue does not wait for 393.
- Q2, allowed locations: "Inside the project only (Recommended)". A tracked path inside the project, optionally with `#heading` for a section, or `none`; paths outside the project and separate repositories are refused; a part's documents stay named only by the root's `| Sub-roadmap | Root |` pointer table (ADR-0022).

Host decisions on the rest of the actions (owner may veto):
- Q3, the design text wording, follows from Q1 and Q2 and is a host decision: the Documentation layers Target drops "not decided" and names the three settings with the fixed search as the fallback for an unset one; OQ-1 is marked answered by this issue; the Direction Format paragraph says its grammar applies to the file the roadmap setting names.
- One shared candidate list in the helper replaces the differing fixed searches of `update_roadmap.sh` and `sitrep_root.sh`.
- Two pull requests: first the settings, helper, script readers and tests; then the skills' onboarding and design-discussion question.
- Sequencing: issue 452 (Copilot review optional) also edits `onboard-project` and `audit-project`; whichever merges second merges main first. No wait: 551's first pull request does not touch the skills.

## Plan Authored
**Status**: complete
**When**: 2026-11-23 18:13 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-551/plan.md` at `ea96d2d3`

Two pull requests: PR 1 adds the goals/design/roadmap settings, one resolver helper, the sitrep_root/update_roadmap/check_design_anchors readers, tests and the design text; PR 2 edits onboard-project, audit-project and design-discussion. PR 1 does not touch the two skills issue 452 is editing.

## Plan Review
**Status**: complete
**When**: 2026-11-23 18:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #551 — Where a project keeps its goals, design and roadmap: asked at onboarding, stored once, followed by every reader
**Plan**: `.agent/work-plans/issue-551/plan.md` at `ea96d2d3`
**Branch**: `feature/issue-551`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two PRs as the issue review and checkpoint asked; PR 1 avoids #452's skill files. |
| Issue alignment | Needs work | Serves line as written: "Goal "Projects keep their own documents" (README workspace goals), under `docs/design.md#documentation-layers` and `docs/design.md#registry-and-adapters`." Both anchors resolve; the goal name does not exist under `README.md#workspace-goals` (finding 5). The ARCHITECTURE.md design fallback breaks the issue's "with no setting, each keeps today's fixed search" (finding 1). |
| File targeting | Needs work | Missing `.claude/skills/sitrep/SKILL.md` (finding 2) and `.agent/scripts/_bookkeeping.sh` / `merge_pr.sh` bookkeeping paths (finding 3). |
| Consequences | Needs work | Merge-gate bookkeeping list and the sit-rep skill's own `docs/design.md` reads not in the table. |
| Principle alignment | Good | Design text in PR 1 (Keep one current design); unset/none/decide later (A project is never forced); one helper (Only what's needed). Test plan is per reader. |
| ADR compliance | Good | ADR-0017, -0022, -0016, -0013 addressed; OQ-1 wording over-claims (suggestion 6). |
| ROS conventions | N/A | Workspace plan. |

### Fallback lists checked against the code that reads them

- **roadmap** (`docs/roadmap.md`, `docs/ROADMAP.md`, `ROADMAP.md`): matches `update_roadmap.sh:169` and `_bookkeeping.sh:22` (same set); `sitrep_root.sh:324` reads only `docs/roadmap.md ROADMAP.md`. Adding `docs/ROADMAP.md` to the sit-rep is the host's shared-list decision; accepted.
- **design** (`docs/design.md`, `ARCHITECTURE.md`): `audit-project/SKILL.md:186` and `discover_governance.sh:114-115` accept both. But the script readers the plan routes through the helper accept only `docs/design.md`: `check_design_anchors.sh:174` (exit 2 without it), `sitrep_root.sh:354-357`, and the sitrep skill's Audit/Documentation blocks. design-discussion (`SKILL.md:130`) names only `docs/design.md`. So the second candidate is right for audit-project, wrong for the script readers (finding 1).
- **goals** (`README.md`): no script reads goals. design-discussion (`SKILL.md:135-138`) accepts "the goals its own design or README names" and asks when none is found; the workspace's is `README.md#workspace-goals`. A bare `README.md` fallback is wider than that: nearly every project has a README, so the lookup would almost never report "missing" (finding 4).

### Findings

1. **[Issue alignment / File targeting]** — `ARCHITECTURE.md` as a design fallback for the script readers changes behaviour for projects that never set the key, against the issue ("With no setting, each keeps today's fixed search"). Today a project with only `ARCHITECTURE.md` gets `check_design_anchors.sh` exit 2 and the sit-rep's decision_register/design_anchors/documentation checks skipped; under the plan they would run against `ARCHITECTURE.md`. Worse, `check_design_anchors.sh`'s citation grammar only recognises paths ending in `design.md#` (header lines 18-66), and any `design.md` other than `docs/design.md` is treated as a part's design. So a design key or fallback naming `ARCHITECTURE.md` gets only its in-file links checked, citations `ARCHITECTURE.md#x` are never seen, and a key naming e.g. `docs/arch/design.md` would be both the root design and a "part design". Resolve: either keep the script readers' fallback at `docs/design.md` only (ARCHITECTURE.md stays an audit-project/discover_governance display name), or have step 5 define how citations of a root design with another file name are recognised and resolved, with tests (key naming a non-`design.md` file; key naming a `design.md` that is not `docs/design.md`; key with `#heading`).
2. **[File targeting]** — `.claude/skills/sitrep/SKILL.md` reads the design file itself: Audit reads `$ROOT/docs/design.md` (line 868), Documentation runs `git log ... -- docs/design.md` (lines 915-921) and the text at lines 77, 949 and 968 names the fixed paths. Step 3 moves only `sitrep_root.sh`'s `check` gate to the helper, so the gate would say "run" for one file while the skill reads another. Add the skill to PR 1 (it is not one of #452's files), e.g. have `sitrep_root.sh` print a `design=` line the skill reads, as it already does for `roadmap=`.
3. **[Consequences]** — The merge gate's bookkeeping allow-list is fixed: `_bookkeeping.sh:22` `BOOKKEEPING_ROADMAP_PATHS` feeds `_review_bookkeeping_between` (line 190) and `merge_pr.sh:1663` `MERGE_PR_CI_BOOKKEEPING_PATTERNS`. Once `update_roadmap.sh` ticks a key-named roadmap at another path, that post-review edit is no longer bookkeeping, so the review goes stale / the gate blocks. Either the bookkeeping paths include the resolved roadmap key, or the plan says why not; add a test in the bookkeeping/merge tests.
4. **[Issue alignment]** — The helper does not say whether a result came from the key or from the fallback (step 2 marks only explicit `none`). PR 2 needs exactly that: onboarding "offer the detected candidate" and design-discussion "ask when a key is unset" (issue item 4). Add a source field (`set` / `fallback` / `none`) to the helper output and the `doc` CLI, with tests. With that, reconsider the goals fallback: a bare `README.md` makes "goals found" almost always true; either no goals fallback in the scripts, or the readers treat a fallback as "suggested, ask".
5. **[Issue alignment]** — The `## Serves` goal "Projects keep their own documents" is not a heading under `README.md#workspace-goals` (they are Quality of the work, Trust control and information, Flexibility, Modular, Light touch on projects, Easy to use, The long view). Name the real goal (most likely "Light touch on projects"); the issue review used the same non-existent name.

Suggestions (do not by themselves need another plan round):

6. OQ-1 asks where a project records its mapping of the **seven** roles; this maps three. Word the design change as "answered for where (the settings file); goals, design and direction have keys, the other four roles are unmapped", rather than marking the seven-role Target fully decided.
7. Step 4: say `update_roadmap.sh --root` finds the project name through `project_document_name_for_root` (an unregistered root uses the candidates).
8. State per reader what a `#heading` on `roadmap`/`design` does (sitrep_checks scans the `## Direction` section of the file; check_design_anchors checks all headings of the file), so a `README.md#Design` value has defined behaviour and a test.
9. `project_integration_audit.sh:941` checks `docs/roadmap.md` for ignore rules; consider the key's path there (could be PR 2).

### Summary

The structure (keys, one helper, two PRs, design text with PR 1) is right and follows the owner's decisions. Before implementation, fix the design fallback so unset projects keep today's behaviour in the script readers, add the sitrep skill and the merge-gate bookkeeping list to PR 1, give the helper a set/fallback marker that PR 2 needs, and correct the Serves goal.

### Recommended Actions

- [ ] Restrict or define the `ARCHITECTURE.md` design fallback for `check_design_anchors.sh` and the sit-rep checks; add tests for non-`design.md` design keys (finding 1).
- [ ] Add `.claude/skills/sitrep/SKILL.md` (Audit, Documentation, line 77) to PR 1, reading the design path from `sitrep_root.sh` (finding 2).
- [ ] Add `_bookkeeping.sh` / `merge_pr.sh` bookkeeping paths to PR 1 so a key-named roadmap tick stays bookkeeping, with a test (finding 3).
- [ ] Give `project_document_path` and `project_setting.sh doc` a set/fallback/none source field; revisit the goals `README.md` fallback (finding 4).
- [ ] Correct the `## Serves` goal to a real `README.md#workspace-goals` heading (finding 5).

## Checkpoint
**Status**: complete
**When**: 2026-11-23 18:15 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (plan review needs-work, five findings, approach unchanged; first host revise at plan)
**After**: plan
**Decision**: revise

Revise for all five Plan Review findings and the Q3 suggestion. Host decisions (owner may veto):
- F1: an unset key keeps each reader's behaviour exactly as today. The `design` fallback is `docs/design.md` only (no `ARCHITECTURE.md` for the scripts; audit-project's existing reporting of `ARCHITECTURE.md` is untouched). When the `design` key names another file, `check_design_anchors.sh` recognises citations of that path (`<path>#<section>`) as root citations, with tests; a part's design stays recognised as today.
- F2: add `.claude/skills/sitrep/SKILL.md` to PR 1; `sitrep_root.sh` prints a `design=` line beside `roadmap=` and the skill reads it instead of hard-coding `docs/design.md`.
- F3: `_bookkeeping.sh`'s roadmap bookkeeping paths include the path the `roadmap` key names, so a post-review tick there still counts as bookkeeping in the review check and `merge_pr.sh`; with tests.
- F4: the helper reports where the answer came from (set / fallback / none). `goals` has no fallback: unset reads as unset, and design-discussion's own "the goals its design or README names" rule stays.
- F5: the Serves goal is "Light touch on projects", as written in README.md's goals; check the exact wording there.
- Q3 correction (review's suggestion, adopted): OQ-1 is answered for where a project records its mapping, for three roles; the other four roles stay unmapped, said so in the text.
- The other suggestions: say how `update_roadmap.sh --root` finds the project name; define what `#heading` does in each reader (or refuse it where a reader cannot use it); `project_integration_audit.sh:941` follows the key in PR 2.

## Plan Authored
**Status**: complete
**When**: 2026-11-23 18:16 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-551/plan.md` at `7ab07af2`

Revised for the five plan-review findings: design fallback is docs/design.md only (citations of a key-named design file recognised), sitrep skill reads a design= line, merge-gate bookkeeping includes the roadmap key's path, helper reports set/fallback/none and goals has no fallback, Serves goal is "Light touch on projects". OQ-1 worded as three of seven roles; heading behaviour per reader defined. PR 1 still avoids the onboard-project and audit-project skills.

## Plan Review
**Status**: complete
**When**: 2026-11-23 18:17 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #551 — Where a project keeps its goals, design and roadmap: asked at onboarding, stored once, followed by every reader
**Plan**: `.agent/work-plans/issue-551/plan.md` at `7ab07af2`
**Branch**: `feature/issue-551`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two PRs as the issue review and checkpoint set; PR 1 avoids #452's two skill files (the sit-rep skill it adds is not one of them). |
| Issue alignment | Good | Serves: "Goal "Light touch on projects" (`README.md#workspace-goals`, heading checked), under `docs/design.md#documentation-layers` and `docs/design.md#registry-and-adapters`." `### Light touch on projects` exists at README.md:80; both design anchors resolve (design.md:87, :395). Unset keys keep today's behaviour (only the host-decided `docs/ROADMAP.md` addition to the sit-rep); onboarding question, stored setting, readers and design-discussion "ask when unset" are all covered across the two PRs. |
| File targeting | Good | Sit-rep skill, `_bookkeeping.sh`/`merge_pr.sh` and `project_integration_audit.sh:941` now listed; line references checked (`sitrep_root.sh:322-326`, `:354-357`; `check_design_anchors.sh:174`; `_bookkeeping.sh:22`, `:190`; `merge_pr.sh:1663`). |
| Consequences | Good | Table covers keys/help/reference, sit-rep headers and skill, update_roadmap, merge-gate bookkeeping, integration-audit ignore check, design and roadmap Format text. |
| Principle alignment | Good | Design text in PR 1 (Keep one current design); unset/none/decide later (A project is never forced); one helper, no outside kinds (Only what's needed); tests per reader and per refused value. |
| ADR compliance | Good | ADR-0017 (design + change log in PR 1), ADR-0022 (pointer table untouched, part-design recognition unchanged), ADR-0016 (outside paths and symlink escapes refused at read), ADR-0013. OQ-1 now worded as three of seven roles (design.md:1047). |
| ROS conventions | N/A | Workspace plan. |

### Earlier findings (Plan Review at `ea96d2d3`)

1. ARCHITECTURE.md fallback — resolved: `design` fallback is `docs/design.md` only; step 5 recognises `<design key path>#<section>` as root citations and stops treating that path as a part design; tests for a non-`design.md` key, a non-`docs/` `design.md` key, `#heading`, `none`.
2. Sit-rep skill — resolved: step 6a, `design=` line from `sitrep_root.sh` (step 3) read by Audit/Documentation.
3. Merge-gate bookkeeping — resolved: step 6b, one function feeding both call sites, tests in `test_merge_pr_gate.sh`.
4. Source field — resolved: `set`/`fallback`/`none` with exit codes; `goals` has no fallback.
5. Serves goal — resolved: "Light touch on projects", heading verified.
Suggestions 6-9 adopted (OQ-1 wording, `--root` name lookup, per-reader `#heading` behaviour with `roadmap` heading refused at `set`, integration-audit check in PR 2).

### Findings

None blocking. Suggestions (do not by themselves need another plan round):

1. **[File targeting]** — Step 6b: `_review_bookkeeping_between` gets only `<wt>` (and runs through a CLI bridge for non-bash callers), and the key's path is relative to the project root while `_only_bookkeeping_between` matches paths relative to the worktree's repository. `registry_resolve_session_dir` does map a project worktree to its project, so the lookup works; say in the code that the key's path is added only when the worktree's repository is the project root's own (single-repository project or the root repo), not a package repository of a multi-repo project, and cover the unregistered/workspace case (adds nothing) in the test.
2. **[Consequences]** — `check_design_anchors.sh` (step 5) needs the project name for `--root` the same way step 4 states for `update_roadmap.sh` (`project_document_name_for_root`); state it, and test the workspace root (unregistered) still reads `docs/design.md`.
3. **[Principle alignment]** — Documentation layers is already about 75 lines (change-log row 2026-11-18); the plan notes the budget. Keep the key grammar and helper exit codes in the `_project_registry.sh` header and script_reference, and only the decision in the design section.

### Summary

All five earlier findings are resolved in plan.md and the checkpoint's host decisions are reflected faithfully; none of them looks wrong. The plan is ready for implementation; the three suggestions are implementation notes.

### Recommended Actions

- [ ] (Suggestion) Bound the step 6b bookkeeping addition to worktrees of the project root's own repository; test unregistered root adds nothing.
- [ ] (Suggestion) State and test how `check_design_anchors.sh --root` finds the project name.
- [ ] (Suggestion) Keep design-section additions to the decision; mechanics in script headers.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 18:18 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (second plan review: ready, all earlier findings resolved, three suggestions only)
**After**: plan
**Decision**: proceed

Implement PR 1 of the plan. The second Plan Review's three suggestions are adopted and carried in the implement handoff (owner may veto):
- Bookkeeping: add the `roadmap` setting's path only when the worktree's repository is the project root's own; an unregistered root (the workspace) adds nothing; tests for both.
- `check_design_anchors.sh --root` finds the project name the same way `update_roadmap.sh` does; test that the workspace root still reads `docs/design.md`.
- `docs/design.md` Documentation layers: only the decision goes there (the section is already past its length limit); details go in script headers and `script_reference.md`.
