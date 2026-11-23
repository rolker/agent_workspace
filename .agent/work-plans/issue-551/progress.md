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
