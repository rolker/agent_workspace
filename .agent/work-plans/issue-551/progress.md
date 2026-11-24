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

## Implementation
**Status**: complete
**When**: 2026-11-23 19:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-551 at `5c9bc978`

PR 1 of the plan (settings, helper, script readers, sit-rep skill, tests, design text), in two commits (`ea81c197` code and tests, `5c9bc978` design and reference text). `onboard-project` and `audit-project` SKILL.md are untouched.

- **Settings**: `goals`, `design`, `roadmap` in `_PROJECT_FILE_KEYS`; `_project_document_value_error`: `none` or a project-relative file (no leading `/` or `~`, no `..`/`.`/empty component, no trailing `/`, no blanks, control characters, backslash or glob characters, not a URL), `#<heading>` on goals and design only (refused on roadmap at `set` and in the parser). Header of `_project_registry.sh` and `projects.local.example` document it.
- **Helper** (`_project_registry.sh`): `project_document_candidates`, `project_document_path <ws> <name> <key> [<dir>]` printing `set <path>[#h]` / `fallback <path>` / `none` (exit 1 nothing to read, 2 invalid settings/registry or a path that resolves outside the root at read time), `project_document_name_for_root <ws> <dir>` (a registered root, or the top of a worktree of the root's own repository when the root is the top of that repository; a checkout of the workspace's own repository returns 1 before the registry is read, so the workspace's own hook never depends on the registry), `project_document_for_dir`. A parent root reads the candidates (a hand-written file there is exit 2). `project_setting.sh doc <name> <key>` prints the same line.
- **Readers**: `sitrep_root.sh` prints `roadmap=`/`roadmap_why=` and `design=`/`design_why=`, and the three design checks use the design file (kept even when only the default branch has it, so the older-branch case behaves as before); `sitrep_checks.sh`'s default roadmap uses the lookup (`roadmap=none` gives `(roadmap not found: <root> keeps no roadmap (roadmap=none))`, an unreadable setting `(roadmap not readable: <reason>)`); `update_roadmap.sh` edits the set file only, does nothing for `none` or a set file that is missing or unreadable, else every existing candidate (walked in its old order, so output and same-file dedupe are unchanged); `check_design_anchors.sh` takes the root design and the pointer-table roadmap from the lookup, recognises `<path>ARCHITECTURE.md#x` style citations only when they resolve to the root design, treats a key-named `docs/arch/design.md` as the root (not a part), skips root-design checks for `design=none`, exits 2 for a missing set file; `_bookkeeping.sh` `bookkeeping_roadmap_paths <wt>` adds the set file only when `<wt>` is the top of a checkout of the project root's own repository (nothing for the workspace, unset, none, a root inside another repository), used by `_review_bookkeeping_between` and `merge_pr.sh`'s `MERGE_PR_CI_BOOKKEEPING_PATTERNS`.
- **Sit-rep skill**: Audit and Documentation read `design=` instead of `docs/design.md`; the roadmap text names the setting and the fallback.
- **Design text**: Documentation layers Now gains the decision (one paragraph, about 10 lines; mechanics stay in script headers and `script_reference.md`), the `update_roadmap.sh` sentence and the Target's "not decided" are revised (decided for three roles, four with no setting), Registry and adapters names the keys, OQ-1 answered for three roles and open for four, change-log row; `docs/roadmap.md` Format paragraph says which file the grammar applies to; `script_reference.md` rows updated.
- **Second plan review's suggestions**: bookkeeping bounded to the project root's own repository with tests for the workspace (adds nothing) and a root inside another repository; `check_design_anchors.sh <root>` finds the project name through `project_document_name_for_root`, the same as `update_roadmap.sh --root`, with a test that the workspace root still reads `docs/design.md` (and does so with a broken registry); design text kept to the decision.

Deviations from plan.md: registry-bound cases for `update_roadmap.sh`, `check_design_anchors.sh`, `sitrep_checks.sh` and the bookkeeping rule live in the new `test_project_documents.sh` (one sandbox registry) rather than `test_update_roadmap.sh`, `test_design_anchors.sh` and `test_merge_pr_gate.sh`, which have none; `test_project_registry.sh` is not extended (the set/parse cases are in `test_project_documents.sh`; `test_project_file.sh`'s known-keys line is updated). `check_design_anchors.sh` takes its root positionally (there is no `--root`). It now needs `_project_registry.sh` beside it (`test_design_anchors.sh`'s symlink fixture copies it).

Suites run (each on its own, after the last code change unless noted): test_project_documents: 86 passed, 0 failed; test_design_anchors: 82 passed, 0 failed; test_sitrep_root: 72 passed, 0 failed; test_sitrep_checks: 252 passed, 0 failed; test_update_roadmap: 16 passed, 0 failed; test_project_file: 694 passed, 0 failed; test_project_registry: 425 passed, 0 failed; test_merge_pr_gate: 213 passed, 0 failed; test_merge_pr: 175 passed, 0 failed; test_merge_pr_skill: 132 passed, 0 failed; test_triage_reviews_integration: 69 passed, 0 failed; test_skill_paths: 198 passed, 0 failed; test_adapter: 248 passed, 0 failed; test_precommit_hook_path: 19 passed, 0 failed; test_gh_create_pr: PASS 113, FAIL 0; test_gh_create_issue: PASS 88, FAIL 0; test_capture: 41 passed, 0 failed; test_pr_status: 3 passed, 0 failed; test_discover_governance: 32 passed, 0 failed; test_fresh_clone_no_project: 26 passed, 0 failed; test_dispatch_phase: 244 passed, 0 failed; test_session_start_layer: 52 passed, 0 failed; test_worktree_remove: 138 passed, 0 failed; test_worktree_create: PASS 109, FAIL 0; test_user_tier_guard: 64 passed, 0 failed; test_validate_workspace_stale: 126 passed, 0 failed; test_worktree_enter_stderr: 35 passed, 0 failed; test_ros2_colcon: 1513 passed, 0 failed, 3 skipped; test_register_project: 213 passed, 0 failed; test_project_integration_audit: 279 passed, 0 failed; test_checkpoint_269: 43 passed, 0 failed; test_merge_pr_root_resolution: 6 passed, 0 failed; test_package_issue_loop: 220 passed, 0 failed; test_records_write_gate: 68 passed, 0 failed. (After that run only `check_design_anchors.sh`'s header comments and one test's shellcheck directive changed; test_design_anchors and test_project_documents were rerun and pass.) The full pre-commit pass was left to the host.

### Decision summary

- Where a project keeps its goals, design and roadmap is three settings in `.agent/projects.d/<name>` (owner, 2026-11-23): `none` or a file inside the project; `#<heading>` on goals and design, not roadmap; outside paths, URLs and other repositories refused.
- One lookup (`project_document_path`) for every reader; unset falls back to `docs/roadmap.md`, `docs/ROADMAP.md`, `ROADMAP.md` and `docs/design.md`; goals has no fallback. The sit-rep now also finds `docs/ROADMAP.md` (host decision: one shared list).
- The workspace is not registered and always uses the fallback, without reading the registry.
- A design file not named `design.md` is cited as `<path>#<section>`; the anchors checker counts such a citation only when it resolves to the root design.
- The merge gate counts a post-review tick of the setting's roadmap as bookkeeping only in a checkout of the project root's own repository.
- OQ-1 is answered for three of the seven roles; the other four have no setting. PR 2 (onboard-project, audit-project, design-discussion, `project_integration_audit.sh`) follows; this PR is Part of #551.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 19:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-551 at `1d14eed1`
**Base**: main
**Depth**: Deep (reason: 1490 lines over 19 files; merge-gate bookkeeping (`merge_pr.sh`, `_bookkeeping.sh`), the pre-commit anchors hook and design.md)
**Must-fix**: 3 | **Suggestions**: 10
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

Specialists: static analysis (shellcheck --severity=warning on all changed .sh: clean), governance, plan drift, Claude adversarial, cross-model gemini (complete) and codex (complete). Adversarial ran test_project_documents (86), test_design_anchors (82), test_sitrep_root (72), test_update_roadmap (16), test_project_file (694), test_sitrep_checks (252): all pass.

Implementation deviations judged: (a) registry-backed cases in the new `test_project_documents.sh`: accepted (one sandbox registry; the other suites have none). (b) no `--root` flag on `check_design_anchors.sh`: accepted (positional root, as before). (c) needs `_project_registry.sh` beside it: accepted (same directory; the symlink fixture copies it). (d) unset `sitrep_root.sh` still passes `docs/design.md` when only the default branch has it: correct, it keeps today's behaviour. Workspace independence verified: a workspace checkout returns from `project_document_name_for_root` before the registry is read (adversarial: workspace anchors rc=0 with a broken registry; test covers it); `sitrep_root.sh` passes an empty project name for the workspace.

### Findings
- [x] (must-fix) A project with none of the three keys set changes behaviour when its settings file holds an invalid unrelated value (e.g. `build=make; rm -rf /`) or the registry has a bad line: `project_document_path` returns 2 on any `project_file_entries` failure and `project_document_name_for_root` on any registry parse error, so `check_design_anchors.sh` exits 2, `update_roadmap.sh` ticks nothing (merge proceeds with only a warning), `sitrep_root.sh` skips all three design checks and `sitrep_checks.sh` reports the roadmap unreadable; on main all four worked. Also an unregistered non-workspace root (and `test_design_anchors.sh`'s temp roots) now fail on a broken machine registry. Against the owner's "with no setting, each keeps today's fixed search": decide fail-closed only when the read key itself cannot be told, else the candidates; tests for both — `_project_registry.sh:1442,1523`, `check_design_anchors.sh:207`, `update_roadmap.sh:208`, `sitrep_root.sh:368`, `sitrep_checks.sh:374`
- [x] (must-fix) `check_design_anchors.sh <relative root>` regressed: `cd "$ROOT"` runs before `project_document_for_dir ... "$ROOT"`, which resolves the relative path again from inside it; reproduced (`check_design_anchors.sh issue-workspace-551` from its parent: exit 2 "no design file", main: exit 0). Use `ROOT="$(pwd -P)"` after the `cd`, add a test — `check_design_anchors.sh:190-207`
- [x] (must-fix) A `roadmap` value may name any file (`roadmap=src/main.py`), and `bookkeeping_roadmap_paths` then exempts post-review commits to it from the review-staleness and CI-staleness checks of the merge gate. Restrict roadmap values (e.g. to `*.md`) at `set` and in the parser, with a test — `_project_registry.sh` `_project_document_value_error`, `_bookkeeping.sh:54`
- [x] (suggestion) Duplicate citations/findings when the design setting's basename ends in `design.md` (e.g. `docs/my-design.md`): the `design\.md#` regex and the `DESIGN_ALT` scan both emit the token — `check_design_anchors.sh:530,549`
- [x] (suggestion) A symlinked candidate (`docs/design.md`, `docs/roadmap.md`) resolving outside the root now fails closed (exit 2) for a project with no keys; intended under ADR-0016 but a behaviour change not stated in the design text or PR — `_project_registry.sh` `_project_document_file_error`
- [x] (suggestion) `update_roadmap.sh` (unset key) still ticks every existing candidate with only `[[ -f ]]`; the lookup's containment check covers only the first, so `ROADMAP.md` symlinked outside the root is edited (as on main); check each candidate with `_project_document_file_error` — `update_roadmap.sh:220`
- [x] (suggestion) A set roadmap that is a symlink inside the root is accepted, but `update_roadmap.sh` writes by moving a temp file over it, replacing the link and leaving the target unticked; resolve the link or refuse a symlink for `roadmap` — `update_roadmap.sh`, `_project_registry.sh:1472`
- [x] (suggestion) A hand-made `git worktree add` of a project outside its root and its `worktrees=` directory reads the candidates, not the settings (worktrees from `worktree_create.sh` are covered); match on the shared git common dir, or state the limit — `_project_registry.sh:1442`
- [x] (suggestion) The lookup's reason can carry a tab (from a refused value) into `sitrep_checks.sh`'s TSV `section` row; strip tabs/CRs from `_why` — `sitrep_checks.sh:374`
- [x] (suggestion) The roadmap `#heading` refusal suggests `roadmap=<path>` before the path is validated (`roadmap=../r.md#x` advises `roadmap=../r.md`); validate the path first — `_project_registry.sh` `_project_document_value_error`
- [x] (suggestion) `project_setting.sh doc` exits 1 for a usage error, the same code as "nothing to read"; use a distinct code — `project_setting.sh:244-247`
- [x] (suggestion) `project_document_candidates` word-splits `${!var}` under the caller's IFS; set `local IFS=' '` — `_project_registry.sh:1364`
- [x] (suggestion) Test gaps: `sitrep_checks.sh --root` of a keyed project reads `## Direction` from the set file over a decoy `docs/roadmap.md`; `design=none` with clean parts exits 0; a part named in a key-named roadmap's pointer table; `merge_pr.sh`'s `MERGE_PR_CI_BOOKKEEPING_PATTERNS` with a set roadmap — `tests/test_project_documents.sh`

## Implementation
**Status**: complete
**When**: 2026-11-23 19:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-551 at `1de1d2b6`
**Addressed**: Local Review (Pre-Push) at `1d14eed1` (2026-11-23 19:13 -05:00)
**Commits**: 7da33a70 (code and tests; the fixes share the lookup's lines, so one commit), 1de1d2b6 (design text, script_reference.md)

### Actions
- [x] (must-fix) Fail open outside the key (host's decision from the owner's words on the issue): `project_document_path` exits 2 only when the key read is itself unusable (set twice, an invalid value, a file outside the root, a roadmap symlink). A broken registry, an unregistered name (with a directory), a parent root's stray settings file, an unreadable settings file or another key's bad line give one `warning:` line on stderr and the key as written when its own line is valid, else the candidates; `project_document_for_dir` likewise on a broken registry (the registry's own parse errors are silenced there so the warning is the one line). New `project_document_query` runs either lookup for every reader (check_design_anchors.sh, update_roadmap.sh, sitrep_checks.sh, sitrep_root.sh) and passes warnings through. Tests: unrelated bad key → candidates in doc, check_design_anchors.sh, update_roadmap.sh, sitrep_checks.sh and the bookkeeping paths, exactly one warning line; bad key beside a valid design → the setting; bad key beside an invalid design → exit 2; design set twice → exit 2; broken registry → candidates for a project root and a keyed root, an unregistered temp root still checked by check_design_anchors.sh, update_roadmap.sh uses the candidates — `_project_registry.sh` `project_document_path`, `project_document_for_dir`, `project_document_query`
- [x] (must-fix) `ROOT="$(pwd -P)"` after the `cd`; test runs the checker with a relative root from its parent — `check_design_anchors.sh:190`
- [x] (must-fix) `roadmap` must end in `.md` at `set` and in the parser; tests: `set` refuses `src/main.py`, `ROADMAP`, `notes/plan.txt`; a hand-written `roadmap=src/main.py` fails `check` and `doc` (exit 2); `design` still takes any file — `_project_registry.sh` `_project_document_value_error`
- [x] (suggestion) Duplicate citations: the `DESIGN_ALT` scan is skipped when the name itself ends in `design.md` (the main regex already finds it); test: `docs/my-design.md#gone` reported once — `check_design_anchors.sh` `citations()`
- [x] (suggestion) Symlinked candidate resolving outside the root fails closed (exit 2) for a project with no keys: kept, and now stated in the `_project_registry.sh` header, `docs/design.md`, the check_design_anchors.sh exit codes and the Decision summary below; test: `doc candout design` exits 2 — `_project_registry.sh`
- [x] (suggestion) update_roadmap.sh checks each candidate with `_project_document_file_error` and skips one outside `--root` with a message; test: `ROADMAP.md` linked outside is skipped, `docs/roadmap.md` ticked, the outside file untouched — `update_roadmap.sh`
- [x] (suggestion) Symlinked roadmap setting: refused, not written through (a write-through would change the target's path, which the merge gate's bookkeeping exemption does not name, so the tick would make the review stale). `project_document_path` exits 2 for a set roadmap that is a link or reached through one; tests: `doc` exits 2 naming the link, update_roadmap.sh edits nothing and the link stays a link — `_project_registry.sh` `project_document_path`
- [x] (suggestion) Hand-made worktree outside the root and its `worktrees=` directory: the limit is stated in `project_document_name_for_root`'s comment (matching every root's git common dir would cost a git call per registered project on every lookup) — `_project_registry.sh`
- [x] (suggestion) Tab in the reason: `project_document_query` turns every control character in the reason into a blank (emit() already stripped tabs, CR/newline were not); test: a hand-written `roadmap=notes/a<TAB>b.md` keeps the section row at five fields — `_project_registry.sh`, `sitrep_checks.sh`
- [x] (suggestion) The path is validated before the roadmap heading refusal; test: `roadmap=../r.md#x` gives the `..` error, not a suggestion of `roadmap=../r.md` — `_project_registry.sh` `_project_document_value_error`
- [x] (suggestion) `project_setting.sh doc`: a usage error or unknown project exits 3 (other commands keep 1); `doc` prints the answer only on exit 0; tests for an unknown document, no document, an unknown project — `project_setting.sh`
- [x] (suggestion) `local IFS=' '` in `project_document_candidates`; test with `IFS=,` — `_project_registry.sh`
- [x] (suggestion) The four test gaps: sitrep_checks.sh `--root` of a keyed project reads `## Direction` from the set file over a decoy `docs/roadmap.md`; `design=none` with sound parts exits 0; a part named in a key-named roadmap's pointer table is read and the decoy's is not; merge_pr.sh's `MERGE_PR_CI_BOOKKEEPING_PATTERNS` (run from its own text) adds the set roadmap with a worktree and is the fixed list without — `tests/test_project_documents.sh`

### Checks
Suites run, each on its own from the worktree (the full pre-commit pass is left to the host):
- test_project_documents.sh: `test_project_documents: 140 passed, 0 failed`
- test_design_anchors.sh: `test_design_anchors: 82 passed, 0 failed` (a first run failed once while check_design_anchors.sh was being edited mid-run; rerun on the final file passed)
- test_adapter.sh `248 passed, 0 failed`; test_capture.sh `41 passed, 0 failed`; test_discover_governance.sh `32 passed, 0 failed`; test_dispatch_phase.sh `244 passed, 0 failed`; test_fresh_clone_no_project.sh `26 passed, 0 failed`; test_gh_create_issue.sh `FAIL: 0`; test_gh_create_pr.sh `FAIL: 0`; test_merge_pr.sh `175 passed, 0 failed`; test_merge_pr_gate.sh `213 passed, 0 failed`; test_merge_pr_skill.sh `132 passed, 0 failed`; test_pr_status.sh `3 passed, 0 failed`; test_precommit_hook_path.sh `19 passed, 0 failed`; test_project_file.sh `694 passed, 0 failed`; test_project_integration_audit.sh `279 passed, 0 failed`; test_project_registry.sh `425 passed, 0 failed`; test_register_project.sh `213 passed, 0 failed`; test_ros2_colcon.sh `1513 passed, 0 failed, 3 skipped`; test_session_start_layer.sh `52 passed, 0 failed`; test_sitrep_checks.sh `252 passed, 0 failed`; test_sitrep_root.sh `72 passed, 0 failed`; test_skill_paths.sh `198 passed, 0 failed`; test_update_roadmap.sh `16 passed, 0 failed`; test_user_tier_guard.sh `64 passed, 0 failed`; test_validate_workspace_stale.sh `126 passed, 0 failed`; test_worktree_create.sh `FAIL: 0`; test_worktree_enter_stderr.sh `35 passed, 0 failed`; test_worktree_remove.sh `138 passed, 0 failed`

### Decision summary
- Fail open outside the key, closed on it (host decision from the owner's "with no setting, each keeps today's fixed search"; owner may veto): a reader exits 2 only when the key it reads is set twice, invalid, names a file outside the root, or (roadmap) is a symbolic link; every other unreadable registry or settings file gives one warning and the key as written, else the candidates.
- Behaviour change: a fallback candidate (`docs/design.md`, `docs/roadmap.md`, ...) that resolves outside the root now stops the reader (exit 2) even for a project with no keys; on main it was read. Intended (ADR-0016: a document is inside the project); update_roadmap.sh skips such a candidate when another one is the first found.
- A symlinked roadmap setting is refused rather than written through, so the path the merge gate exempts is the path git changes.
- `roadmap` names a `*.md` file only, since commits to it after review count as bookkeeping.
- `project_setting.sh doc` exits 3 for its usage errors and an unknown project, apart from 1 "nothing to read".
- A hand-made worktree outside a root's `worktrees=` directory reads the candidates; stated, not built.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 21:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a6ccd3d48db033a11, resume 1 of 3)

**Branch**: feature/issue-551 at `6cf34cdc`
**Base**: main
**Depth**: Deep (reason: whole-diff classification, fix round 2: about 1900 lines over 19 files; merge-gate bookkeeping, the anchors pre-commit hook, design.md)
**Must-fix**: 2 | **Suggestions**: 8
**Round**: 2 | **Ship**: continue — round 2: 2 must-fix include a design/correctness concern (not mechanical)

Specialists: static analysis (shellcheck on changed .sh: clean in round 1; fix diff is shell only), governance, plan drift, Claude adversarial (fresh subagent), cross-model gemini (complete) and codex (complete). Suites run this round: test_project_documents 140/0, test_design_anchors 82/0, test_sitrep_root 72/0, test_sitrep_checks 252/0, test_update_roadmap 16/0, test_project_file 694/0.

Round-1 findings: all 13 verified fixed in 7da33a70/1de1d2b6 (relative root; `.md` roadmap; duplicate DESIGN_ALT; per-candidate containment in update_roadmap.sh; symlinked roadmap setting refused; worktree limit stated; control characters stripped; path checked before the heading message; `doc` exit 3; `local IFS`; four test gaps), except where the two must-fix below say otherwise.

Host decision checked ("fail closed only when the key being read is itself set and unusable; otherwise warn and use the fixed candidates"): the code follows it for a bad registry line, an unregistered name with a directory, a stray parent-root file, an unreadable settings file and another key's bad line (one warning; the key as written when its own line is valid, else the candidates; raw parser agrees with the real one on `key = value`, CR and comments). Stated behaviour changes against the owner's rule: symlinked roadmap setting refused, roadmap must be `.md`, and `doc` exit 3 on usage all apply only to a set key or a new command, so they keep "with no setting, each keeps today's fixed search"; the symlinked-fallback change does not (must-fix 1). Workspace independence holds: `project_document_name_for_root` returns before the registry for a workspace checkout, `sitrep_root.sh` passes an empty name.

### Findings
- [x] (must-fix) A fallback candidate that resolves outside the root (key unset) now stops every reader with exit 2 (`doc`, `check_design_anchors.sh`, sit-rep "setting cannot be read", `update_roadmap.sh` nothing updated, or a later such candidate skipped); on main it was read. The key is not set, so the host's decision (fail closed only on a set, unusable key) and the owner's "with no setting, each keeps today's fixed search" say warn and read it as today. ADR-0016 (session roots and the user tier) does not require it. Either read it with a warning, or take an explicit owner call accepting the change — `_project_registry.sh` `project_document_path` candidate loop, `update_roadmap.sh` per-candidate check, `tests/test_project_documents.sh` `candout`
- [x] (must-fix) The round-1 fix (`roadmap` must end in `.md`) leaves the merge-gate exemption open for any Markdown file: `roadmap=README.md`, `AGENTS.md`, `docs/design.md` makes post-review commits to it bookkeeping (codex). The setting's path is also matched as an extglob pattern (`_bookkeeping.sh` `_only_bookkeeping_between` `[[ "$p" == $a ]]`, `merge_pr.sh` `_is_bookkeeping_path`); the grammar allows `( ) | ! @ +`, so `roadmap='!(nope).md'` (with such a file) matches every `.md` (adversarial). Match the setting's path literally, and bound the exemption (e.g. only changes update_roadmap.sh makes, or refuse instruction/design files) — `_bookkeeping.sh:bookkeeping_roadmap_paths`, `_project_registry.sh` `_project_document_value_error`
- [x] (suggestion) A broken registry line makes a project with a set `roadmap` read the candidates: `update_roadmap.sh` ticks a decoy `docs/roadmap.md` the project did not choose, and merge_pr `git add`s it; `check_design_anchors.sh` says "design is not set" when it cannot be told. Follows the host decision as written; a writer could do nothing when it cannot tell, and the reason say "cannot be told" — `_project_registry.sh:1657`, `update_roadmap.sh:203`
- [x] (suggestion) `design=none` with a tracked `docs/design.md`: it is still a citer and is checked as a part design (`is_part_design` with empty DESIGN), against the header's "no root design is checked (no in-file links ...)"; exclude it or say so in the header (gemini, codex) — `check_design_anchors.sh:415`
- [x] (suggestion) A dangling symlink as the roadmap setting gives exit 1 ("set but missing") rather than the stated exit 2, since `readlink -f` resolves a dangling last component; test `-L` first — `_project_registry.sh:1488-1505,1626`
- [x] (suggestion) The settings warning prints twice per reader run (design and roadmap lookups in `check_design_anchors.sh`, `sitrep_root.sh`), with an unnormalised `.../scripts/../../.agent/projects.local` path — `check_design_anchors.sh`, `sitrep_root.sh:371,374`
- [x] (suggestion) `git -C` calls in `project_document_name_for_root` and `bookkeeping_roadmap_paths` do not clear `GIT_DIR`/`GIT_WORK_TREE`; run under a git hook of another repository they can misread a project as the workspace (the workspace's own hook is unaffected: it returns early either way) — `_project_registry.sh:1456`, `_bookkeeping.sh:49`
- [x] (suggestion) With the roadmap key unset, an in-root symlinked candidate is still replaced by a regular file on write; the set-key symlink rule does not cover candidates (as on main) — `update_roadmap.sh:229`
- [x] (suggestion) The Target block keeps `Status: proposed` while the text says decided for three roles (plan step 8 said `decided`; the adopted Q3 wording supports keeping it): say which in the change-log row — `docs/design.md:161`

## Implementation
**Status**: complete
**When**: 2026-11-23 21:57 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a5c9a1e1d1aa2635c, resume 1 of 3)

**Branch**: feature/issue-551 at `262907d4`
**Addressed**: Local Review (Pre-Push) at `6cf34cdc` (2026-11-23 21:24 -05:00)
**Commits**: c8e2c303 (lookup, readers, writers, tests; the fixes share the lookup's lines), 2d0f02a7 (design text, change-log row, script_reference.md), 262907d4 (update_roadmap.sh link note after the same-file guard, from a test_update_roadmap.sh failure)

### Actions
- [x] (must-fix) Host decision: with the key unset, a fallback candidate that resolves outside the root is read as on main, with one `warning:` line (only when it is a regular file; a dangling candidate is passed over, as main's `-e`/`-f` did). update_roadmap.sh no longer skips such a candidate: handled as on main (the edited copy replaces the link, the outside file untouched), with a warning. Only a SET key that is unusable exits 2. Tests: `doc candout design` → `fallback docs/design.md` + warning; candlink → both candidates processed as on main, outside file untouched, warning — `_project_registry.sh` `project_document_path`, `update_roadmap.sh`
- [x] (must-fix) Host decision: `bookkeeping_roadmap_paths` escapes every character of the setting's path but letters, digits and `. _ / -`, so `_only_bookkeeping_between` and merge_pr.sh's `_is_bookkeeping_path` (both fed by it) match it literally; `set` and the parser refuse a roadmap naming README.md, AGENTS.md, CLAUDE.md, CODEX.md (any directory, any case), `docs/design.md`, or the design setting's file (`_project_document_pair_error`, also applied in the fail-open path). Tests: the seven refused names, the pair refusal at `set`, in the parser and beside another bad line; `roadmap='notes/!(nope).md'` matches itself and not `notes/other.md` (also with extglob on), and a commit to `notes/other.md` after review is not bookkeeping — `_bookkeeping.sh`, `_project_registry.sh`, `merge_pr.sh` (comment)
- [x] (suggestion) Host decision: `PROJECT_DOC_STRICT=1` makes the lookup return 3 when whether the key is set cannot be told (registry unparsable, settings file unreadable); update_roadmap.sh (a writer) ticks nothing and says "which file is the roadmap cannot be told: <reason>"; the bookkeeping list adds only the fixed paths. Readers keep the warning and fallback, and when no fallback exists say "whether design is set cannot be told (...)", not "not set". Tests: broken registry → update_roadmap.sh ticks neither the set file nor the decoy, says "cannot be told"; bookkeeping list is the fixed three; check_design_anchors.sh on a keyed root says "cannot be told" — `_project_registry.sh`, `update_roadmap.sh`
- [x] (suggestion) `design=none` with a docs/design.md in the tree: said in the header (no register guards, no root citations; a docs/design.md left there is read as a part's design), not excluded — the existing `nonep` test shows that behaviour — `check_design_anchors.sh` header
- [x] (suggestion) A dangling symlink: `_project_document_file_error` returns 3 for it; a set key exits 2 ("resolves to no file"); an unset key's dangling candidate is passed over. Tests: `doc dangl roadmap` → 2, `doc dangl design` (unset, dangling candidate) → 1 — `_project_registry.sh`
- [x] (suggestion) Duplicate warning and path: warnings are key-agnostic, `project_document_query` prints each once per shell, and the workspace path is normalised (`pwd -P`). Tests: check_design_anchors.sh and sitrep_root.sh on a root with a bad settings line print exactly one `warning:`, without `/../` — `_project_registry.sh`
- [x] (suggestion) `GIT_DIR`/`GIT_WORK_TREE`: `_project_document_git` (`env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR git`) in `project_document_name_for_root`, the same in `bookkeeping_roadmap_paths`. Tests: with `GIT_DIR` (and `GIT_WORK_TREE`) of the workspace, a root and a worktree still resolve to their project, and the bookkeeping list still adds the setting — `_project_registry.sh`, `_bookkeeping.sh`
- [x] (suggestion) An in-root symlinked candidate is edited through the link (the link stays); one leading outside is handled as on main (see must-fix 1). The note prints after the same-file guard. Test: `ROADMAP.md -> docs/roadmap.md` → target ticked, link still a link, one path printed — `update_roadmap.sh`
- [x] (suggestion) The Target keeps `Status: proposed` (three of seven roles have a home); the change-log row says so and why — `docs/design.md`

### Checks
Each suite run on its own from the worktree; the full pre-commit pass is left to the host.
- After c8e2c303: test_project_documents.sh `174 passed, 0 failed`; test_adapter.sh `248 passed, 0 failed`; test_capture.sh `41 passed, 0 failed`; test_checkpoint_269.sh `43 passed, 0 failed`; test_design_anchors.sh `82 passed, 0 failed`; test_discover_governance.sh `32 passed, 0 failed`; test_dispatch_phase.sh `244 passed, 0 failed`; test_fresh_clone_no_project.sh `26 passed, 0 failed`; test_gh_create_issue.sh `FAIL: 0`; test_gh_create_pr.sh `FAIL: 0`; test_merge_pr.sh `175 passed, 0 failed`; test_merge_pr_gate.sh `213 passed, 0 failed`; test_merge_pr_root_resolution.sh `6 passed, 0 failed`; test_merge_pr_skill.sh `132 passed, 0 failed`; test_package_issue_loop.sh `220 passed, 0 failed`; test_pr_status.sh `3 passed, 0 failed`; test_precommit_hook_path.sh `19 passed, 0 failed`; test_project_file.sh `694 passed, 0 failed`; test_project_registry.sh `425 passed, 0 failed`; test_records_write_gate.sh `68 passed, 0 failed`; test_ros2_colcon.sh `1513 passed, 0 failed, 3 skipped`; test_session_start_layer.sh `52 passed, 0 failed`; test_sitrep_checks.sh `252 passed, 0 failed`; test_sitrep_root.sh `72 passed, 0 failed`; test_skill_paths.sh `198 passed, 0 failed`; test_triage_reviews_integration.sh `69 passed, 0 failed`; test_user_tier_guard.sh `64 passed, 0 failed`; test_validate_workspace_stale.sh `126 passed, 0 failed`; test_worktree_create.sh `FAIL: 0`; test_worktree_enter_stderr.sh `35 passed, 0 failed`; test_worktree_remove.sh `138 passed, 0 failed`; test_update_roadmap.sh `15 passed, 1 failed` (alias case: the link note named a link to a file already processed)
- After 262907d4 (the fix), the suites naming update_roadmap.sh: test_update_roadmap.sh `16 passed, 0 failed`; test_project_documents.sh `174 passed, 0 failed`; test_merge_pr_skill.sh `132 passed, 0 failed`; test_merge_pr_gate.sh `213 passed, 0 failed`

### Decision summary
- Closed only on a SET key that is unusable (set twice, an invalid value, a file outside the root, a dangling link, a roadmap that is a link or names the design): exit 2. With no setting, the fallback search is today's: a candidate leading outside the root is read with a warning (this reverses round 1's fail-closed candidate, per the host's decision).
- Readers fail open when the key cannot be read for a reason outside it (warning, the key's own line, else the fallback); writers (update_roadmap.sh, the bookkeeping list) do nothing when whether the key is set cannot be told (`PROJECT_DOC_STRICT=1`, exit 3), and messages say "cannot be told".
- The merge gate matches the roadmap setting literally; a roadmap may not name README.md, AGENTS.md, CLAUDE.md, CODEX.md, docs/design.md or the design's file, and must end in `.md`.
- A symlinked roadmap setting is refused; a symlinked in-root candidate is edited through the link; one leading outside is handled as on main.
- With `design=none`, a docs/design.md left in the tree is checked as a part's design (stated, not changed).
- The Target stays `Status: proposed`.
- `project_setting.sh doc` exits 3 for its usage errors (round 1, unchanged); a hand-made worktree outside a root's `worktrees=` directory reads the fallback (stated limit, unchanged).

## Implementation
**Status**: complete
**When**: 2026-11-23 22:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a5c9a1e1d1aa2635c, resume 2 of 3)

**Branch**: feature/issue-551 at `5c79c7b1`
**Addressed**: merge of origin/main before the round-3 pre-push review
**Commits**: 5c79c7b1 (merge of origin/main, PR 566 / issue 452), 7763df53 (ROOT_READERS entry for test_project_documents.sh)

### Actions
- [x] `.agent/knowledge/script_reference.md` (1 hunk, three table rows): kept both sides per row. `review_progress.sh` and `pr_start.py` rows taken from main (they add `cold-read`, issue 452; this branch had not changed them). `_bookkeeping.sh` row taken from this branch (it adds `bookkeeping_roadmap_paths <wt>`, issue 551; main had not changed it). A word diff of the two sides showed no other difference.
- [x] `docs/design.md` (1 hunk, the change log): kept both sides' rows. Main's three #452 rows go first because they are already on main, then this branch's #551 row. Each row keeps its own count, as the 2026-11-18 merge row for #488 sets out: #452's rows say 1240 and #551's says 1234, each its own side's file at the time. **This differs from the handoff's "fix any line count a row states":** rewriting those counts would make old rows false. Instead a new change-log row records this merge and carries the merged file's count, 1258, which matches `wc -l docs/design.md` after the merge.
- [x] Found while running the requested suites: `test_script_tests_hook_scope.sh` failed once (352 passed, 1 failed). `test_project_documents.sh`, added on this branch, derives a real repository root but had no `ROOT_READERS` entry. I added one, `.agent/scripts .agent/project_types` (the suite copies both into its sandbox), the same as `test_project_file.sh` (7763df53).

### Checks
Suites run one at a time from the worktree. The full pre-commit pass is left to the host. The merge commit ran its hooks with `SKIP=validate-script-tests`.
- test_design_anchors.sh: `test_design_anchors: 82 passed, 0 failed`
- test_project_documents.sh: `test_project_documents: 174 passed, 0 failed`
- test_skill_paths.sh: `test_skill_paths: 200 passed, 0 failed`
- test_script_tests_hook_scope.sh: `352 passed, 1 failed` on the merge alone (the missing `ROOT_READERS` entry above). After 7763df53: `test_script_tests_hook_scope: 359 passed, 0 failed`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 22:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a6ccd3d48db033a11, resume 2 of 3)

**Branch**: feature/issue-551 at `61623b58`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: the round-2 findings and the fix diff since `f53fef8c` (c8e2c303, 2d0f02a7, 262907d4), the merge 5c79c7b1's two conflict resolutions and 7763df53; PR 566's own content not reviewed. Cross-model: skipped (round-3 convergence check, per handoff). Suites run: test_project_documents 174/0, test_update_roadmap 16/0, test_design_anchors 82/0.

Round-2 findings, checked against the host decisions:
- Must-fix 1 (unset key, candidate outside the root): fixed. The candidate loop reads a regular file outside the root with one warning ("read as before, since <key> is not set"); a dangling candidate (new return 3) is passed over, as main's `-e`/`-f` did; only a set key that is unusable returns 2 (the set path maps every non-1 file error to 2). update_roadmap.sh no longer skips it: edited as on main, with a warning.
- Must-fix 2 (bookkeeping exemption): fixed. `bookkeeping_roadmap_paths` escapes every character but `[A-Za-z0-9._/-]`, so `_only_bookkeeping_between` and merge_pr.sh match the setting literally (test: `notes/!(nope).md` matches itself, not `notes/other.md`, extglob on). The value rule refuses README.md, AGENTS.md, CLAUDE.md, CODEX.md (any directory, any case), docs/design.md, and (`_project_document_pair_error`, in the parser and the fail-open path) the design setting's file.
- Writers do nothing when it cannot be told: `PROJECT_DOC_STRICT=1` returns 3 for an unparsable registry or unreadable settings file; update_roadmap.sh and the bookkeeping list set it; readers keep warning plus fallback and say "cannot be told" when no fallback exists. Another key's bad line is not "untold" (the key's own line is read), as decided.
- Suggestions: `design=none` behaviour stated in the header; dangling set key exits 2; one warning per shell with a normalised path; `env -u GIT_DIR ...` for the lookup's git calls; Target stays `proposed`, said in the change-log row. All verified in the diff.

Merge: script_reference.md keeps main's #452 rows and this branch's #551 rows; the change log keeps both sides' rows with their own counts and adds a merge row with the merged file's count (1258 = `wc -l docs/design.md`). Right: it follows the same pattern as the three earlier merge rows (2026-11-13 twice, 2026-11-18 for #488) and keeps old rows true. 7763df53's `ROOT_READERS` entry matches what the suite copies.

### Findings
- [x] (suggestion) An in-root symlinked candidate (key unset) is now edited through the link and reported under the target's path; when the target is not one of the fixed three (e.g. `ROADMAP.md -> notes/plan.md`), merge_pr.sh commits a path the bookkeeping list does not name, so the review goes stale; on main the link was replaced by `ROADMAP.md`, which is bookkeeping. Edit through only when the target is a fixed candidate, else as on main — `update_roadmap.sh` candidate loop
- [x] (suggestion) `project_document_query`'s once-per-shell check uses the warning text unquoted as a `case` pattern, so a warning holding `*`, `?` or `[` (a path) may print twice; quote `"$line"` in the pattern — `_project_registry.sh` `project_document_query` (deferred: already quoted: the pattern is *$'\n'"$line"$'\n'*, so the text matches literally; a test now pins it (warnings aZZb, a*b, a*b, a?b print once each))

## Checkpoint
**Status**: complete
**When**: 2026-11-23 22:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (round 3 approved, but suggestion 1 is a failure mode that blocks a merge silently; fixing it before publish is cheaper than after)
**After**: publish
**Decision**: address

Address both round-3 suggestions before publish:
- Suggestion 1: with the key unset, `update_roadmap.sh` edits through a symlinked fallback roadmap only when the link's target is one of the fixed bookkeeping roadmap paths; otherwise it behaves as on main (the edited copy replaces the link, which counts as bookkeeping) and says so. A test with `ROADMAP.md -> notes/plan.md`.
- Suggestion 2: quote the warning text in `project_document_query`'s `case` match; a test with a warning holding `*`.
The full pre-commit pass has not run yet; it runs when publish is raised again.

## Implementation
**Status**: complete
**When**: 2026-11-23 22:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a5c9a1e1d1aa2635c, resume 3 of 3)

**Branch**: feature/issue-551 at `6f9732f5`
**Addressed**: Local Review (Pre-Push) at `61623b58` (2026-11-23 22:05 -05:00)
**Commits**: 6f9732f5

### Actions
- [x] (suggestion) When the roadmap key is unset, `update_roadmap.sh` now edits through a symlinked fallback only when the link's target is one of the fixed roadmap paths (`ROADMAP.md`, `docs/ROADMAP.md`, `docs/roadmap.md`), which the merge gate counts as bookkeeping. A link to any other path inside the root is handled as on main: the edited copy replaces the link and the target is untouched. The script then prints "is a link to <target>, not a fixed roadmap path; edited as before". Test with `ROADMAP.md -> notes/plan.md`: the script reports `ROADMAP.md`, the link becomes a ticked regular file, `notes/plan.md` is untouched, and the message is printed. The existing `ROADMAP.md -> docs/roadmap.md` test still edits through the link — `update_roadmap.sh` candidate loop
- [x] (suggestion) Warning text in `project_document_query`'s `case` pattern — `_project_registry.sh` `project_document_query` (deferred: already quoted. The pattern is `*$'\n'"$line"$'\n'*`, so the text matches literally, and no code changed. A new test pins it: the warnings `aZZb`, `a*b`, `a*b` and `a?b` in turn print `aZZb`, `a*b` and `a?b`, once each)

### Checks
Each suite was run on its own from the worktree. The full pre-commit pass is left to the host.
- test_update_roadmap.sh: `test_update_roadmap:16 passed, 0 failed`
- test_project_documents.sh: `test_project_documents: 180 passed, 0 failed`
- test_script_tests_hook_scope.sh: `test_script_tests_hook_scope: 359 passed, 0 failed`
- The other suites that name update_roadmap.sh: test_merge_pr_skill.sh `132 passed, 0 failed`, test_merge_pr_gate.sh `213 passed, 0 failed`

### Decision summary
- This round changes one earlier decision: with the key unset, a symlinked fallback is edited through the link only when the target is a fixed roadmap path. Any other target is handled as on main (the edited copy replaces the link), so `merge_pr.sh` never commits a roadmap path that the bookkeeping list does not name.
- Every other decision from round 2 and the merge stands:
  - Only a set key that cannot be used makes a reader fail.
  - Writers do nothing when they cannot tell whether the key is set.
  - The roadmap path is matched literally, and the names it may not use are refused.
  - The Target stays `proposed`.
  - Each change-log row keeps its own line count; the merge row has the merged file's count.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 22:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a6ccd3d48db033a11, resume 3 of 3)

**Branch**: feature/issue-551 at `bdcc27e3`
**Base**: main
**Depth**: Deep (reason: round 4 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 4 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: the round-3 review's two suggestions and the fix diff since `28f5462f` (6f9732f5). Cross-model: skipped (round-4 convergence check, per handoff). Suites run: test_project_documents 180/0, test_update_roadmap 16/0.

- Round-3 suggestion 1 (symlinked fallback roadmap): fixed. `update_roadmap.sh` edits through a link only when its target is one of `ROADMAP.md`, `docs/ROADMAP.md`, `docs/roadmap.md` inside `--root` (all three in the bookkeeping list); a link to any other in-root path is edited as on main (the copy replaces the link, reported under the candidate's own name, which is bookkeeping) with a message; one leading outside keeps the round-3 behaviour. The new `candplan` test (`ROADMAP.md -> notes/plan.md`) and the existing `candin` test cover both branches.
- Round-3 suggestion 2 (unquoted `case` pattern): my round-3 reading was wrong. At `28f5462f` the pattern was already `*$'\n'"$line"$'\n'*` (`_project_registry.sh:1765`), so the warning text matched literally; no code change was needed. The new test (warnings `aZZb`, `a*b`, `a*b`, `a?b` print three lines, once each) pins it.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 22:28 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (round-4 pre-push review approved with nothing open; the host's full pre-commit pass passed, exit 0)
**After**: publish
**Decision**: publish

Pushing and opening PR 1 of 2 (Part of #551).

## Integrated Review
**Status**: complete
**When**: 2026-11-23 22:29 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Reviews-read**: none

**PR**: #568 at `0b252b08`
**Sources**: 5 (Local Review (Pre-Push) rounds 1 @ `1d14eed1` and 2 @ `6cf34cdc` with Gemini and Codex, round 3 @ `61623b58`, round 4 @ `bdcc27e3` (covers `0b252b08` via bookkeeping); CI rollup. No PR reviews or conversation comments; no Copilot review requested.)
**Cross-source confirmations**: 0
**CI**: pending

Rounds 1-3 raised 5 must-fix and 20 suggestions; every one is ticked in its fix entry and was verified fixed (or, for the round-3 `case`-pattern suggestion, shown already correct and pinned by a test) by the following round. Round 4 found nothing. The `sources` helper returns no open finding covering the head. CI at triage time: Validate Documentation passed in both runs; Lint (pre-commit), Validate Adapter Contract and the repos-manifest tests still pending.

### Findings
- No open findings.

### False positives
- None.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 23:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: merge
**Decision**: address

Owner's answer: "Resolve, then merge". PR 567 (issue 545) merged into main after PR 568 was reviewed, and both added a change-log row at the same place in docs/design.md, so PR 568 no longer merges. A fix pass merges origin/main and keeps both rows (no other change), then a narrow review, the host's full pre-commit pass and CI. His answer authorizes the merge (merge commit) once that is clean; anything new found goes back to him.

## Implementation

**When**: 2026-11-23 23:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Status**: complete
**Addressed**: merge of origin/main after PR 567, at the owner's merge checkpoint
**PR**: #568 at 7a29404e2cdc5b74b5cc5dd351bed761aeb92b6d

### Conflicts

- `docs/design.md` change log (the only conflict): both sides kept. #545's row (already on main, count 1253) placed after #452's rows and before #551's two rows (counts 1234 and 1258 unchanged), following the previous merge's main-first convention; one new Change log merge row added with the merged file's `wc -l` (1272).
- Auto-merged without conflict: `.agent/scripts/tests/test_script_tests_hook_scope.sh` (ROOT_READERS keeps main's `test_review_viewer.py` and the branch's `test_project_documents.sh`) and `.agent/knowledge/script_reference.md` (main's `review_viewer.py` row present alongside the branch's rows).

### Tests

- `test_design_anchors.sh`: test_design_anchors: 82 passed, 0 failed
- `test_project_documents.sh`: test_project_documents: 180 passed, 0 failed
- `test_script_tests_hook_scope.sh`: test_script_tests_hook_scope: 365 passed, 0 failed
- `test_skill_paths.sh`: test_skill_paths: 200 passed, 0 failed

Not pushed (host owns the push).

## Local Review
**Status**: complete
**When**: 2026-11-23 23:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #568 at `cfa1ee47`
**Depth**: Standard (reason: merge-conflict re-review scoped by handoff to merge commit 7a29404e; cross-model skipped per handoff, conflict-resolution re-review)
**Must-fix**: 0 | **Suggestions**: 0

Scope: only how merge 7a29404e (origin/main after PR 567) was resolved, plus the progress entry cfa1ee47. Checked: `git show --remerge-diff` shows the one conflict (docs/design.md change log) resolved by keeping both sides' rows (#545's row before #551's, as in the previous merge) plus one new merge row; no conflict markers remain. Line counts verified with `wc -l`: #545 row 1253 = main's file at c11c6816, #551 rows 1234/1258 unchanged, new row 1272 = merged file. `git diff ace1ee2d 7a29404e` equals exactly main's 8-file change set (review_viewer files, issue-545 work plan, script_reference.md row, ROOT_READERS entry, design.md bullet + row); `git diff c11c6816 7a29404e` on the hook-scope test shows only the branch's `test_project_documents.sh` entry, so ROOT_READERS holds both; script_reference.md holds main's `review_viewer.py` row and the branch's `project_setting.sh`/`update_roadmap.sh` rows. Tests run at HEAD: test_script_tests_hook_scope.sh 365/0, test_project_documents.sh 180/0, test_project_registry.sh 425/0, test_review_viewer.sh OK (1 skipped). Branch behaviour unchanged by the merge.

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-11-23 23:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a799f36118ba87898, resume 1 of 3)
**Reviews-read**: none

**PR**: #568 at `cfa1ee47`
**Sources**: 2 (Local Review @ `cfa1ee47` (PR mode, merge-conflict re-review of 7a29404e, approved, 0 findings); CI rollup. No PR reviews or conversation comments; no Copilot review requested.)
**Cross-source confirmations**: 0
**CI**: pending

Re-triage after the merge of origin/main (7a29404e, after PR 567) at the owner's checkpoint ("Resolve, then merge"). The only conflict, the `docs/design.md` change log, was resolved by keeping both sides' rows and adding one merge row (1272 lines, the merged file's `wc -l`). The Local Review at `cfa1ee47` verified the resolution, and the `sources` helper finds no open finding covering the head and no dropped entries. The previous Integrated Review (at `0b252b08`) closed every pre-push finding. CI at triage time: Validate Documentation and Validate Adapter Contract passed; Lint (pre-commit) and the repos-manifest tests (Python 3.10, 3.14) were pending.

### Findings
- No open findings.

### False positives
- None.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 23:09 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: merge
**Decision**: merge

The owner's answer at the previous merge checkpoint, "Resolve, then merge", authorized this merge once the conflict resolution was clean. It is: the PR-mode re-review approved with no findings, the re-triage found nothing open, the PR shows no reviews, and the PR body has its Decision summary. CI on the head was still finishing; merge_pr.sh waits for it and refuses on a failure.
