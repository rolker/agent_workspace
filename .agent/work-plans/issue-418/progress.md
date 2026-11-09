---
issue: 418
---

# Issue #418 — sitrep: report the session's own root, so a project session gets the project's sit-rep

## Issue Review
**Status**: complete
**When**: 2026-11-09 09:49 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #418

### Scope Assessment

**Well-scoped?** Yes, with one Watch -- eight parts (S1-S8) in one PR is large but they are one change (the skill's root) and share tests; if the plan finds S7's deferral rewording or the S4 inbox ordering pulling apart, split them out. The scope matches the owner's 2026-11-09 narrowing (session root only; the combined view is a later "personal" skill, not here).
**Right repo?** Yes -- skill, check runner, tests, design and roadmap all live in the workspace repo; the project is only read.
**Serves**: "Easy to use" and "The long view" -- `docs/design.md#documentation-layers`, `docs/design.md#sessions-and-roots`
**Design picture?** Changes Documentation layers -- the "reads only the workspace root so far" sentence (docs/design.md line 133). The issue already records the owner's decision and names the update (S7), so no new question.
**Dependencies**: #388 (inbox under one lock) touches S4 -- land first or rebase; #408 (distance to done) is independent. Verified both are open.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | OK | Owner decision recorded in the body; S7 updates design.md and the roadmap row in the same change (ADR-0017). |
| A change includes its consequences | Watch | S7 covers the design and roadmap. Also check the skill's frontmatter description ("in a workspace session it may start a due read-only check"), the Problems rule at SKILL.md "In a project session ... the Problems section is the workspace's only" (S3 replaces it), step 2's `awk '$2 == "workspace"'` and step 4's `printf ... workspace` (S5), and the worktree filter `type == "workspace"` in the issue-timeline step. |
| Leave in a project only what it chose to carry | OK | No-Direction case reports and invents nothing; onboarding is only mentioned, not required (D3). |
| Test what breaks | Watch | S8 names a sandbox root. The acceptance bullets should each map to a test: project with section, project without section, workspace unchanged (run-record column stays `workspace`), and the `docs/roadmap.md` then `ROADMAP.md` order. |
| Only what's needed | OK | Combined view explicitly excluded; no new script is proposed. |
| Verify before claiming | OK | The "4 of 7 true" figure is the issue's own run; `sitrep_checks.sh --root/--roadmap` exists and its checks are a fixed vocabulary (no eval, header line 74), so reading a project's roadmap runs no project-authored shell. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0003 project-agnostic | Yes | S8 uses a synthetic sandbox root, as required; keep project names out of skill text and tests. |
| 0013 progress.md vocabulary | No | Only the Issue Review entry itself. |
| 0016 session roots | Yes | S1 must resolve through `session_root.sh` (root/type/project) and never a nested package repo; the registered name for S5 comes from its `project=` line. |
| 0017 design doc is current picture | Yes | Covered by S7. |

### Consequences

- Skill-paths test (`test_skill_paths.sh`) and `test_sitrep_checks.sh` need the project-root case.
- The skill description line must drop the workspace-only wording.
- Existing run-record lines have `workspace` in column 2: S5 keeps that value for the workspace, so old records stay valid; a project name colliding with `workspace` should be refused or noted.

### Recommendations

- Settle in the plan how S2 finds the root's remote for `gh pr list -R` when the root is a multi-repo hosting directory with no remote of its own (ADR-0016: the registered hosting directory is the root, not a nested package repo); say "no pull-request source" rather than guessing.
- Decide S3's "where the root has those files" test as a file-exists check per workspace-shaped check, so the skip line names which check and why.
- In the plan, decide the S7 deferral fate (revisit check or Decided Against) and order the work after #388 or state the rebase.

### Actions
- [ ] Settle in the plan how S2 finds the root's remote for `gh pr list -R` when the root is a multi-repo hosting directory with no remote of its own (ADR-0016: the registered hosting directory is the root, not a nested package repo); say "no pull-request source" rather than guessing.
- [ ] Decide S3's "where the root has those files" test as a file-exists check per workspace-shaped check, so the skip line names which check and why.
- [ ] In the plan, decide the S7 deferral fate (revisit check or Decided Against) and order the work after #388 or state the rebase.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 09:49 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the three open actions are mechanism: how the pull-request source is found for a root with no single remote, a per-check skip line in Problems, and the deferral row's fate plus ordering against #388; none adds or drops a behaviour the owner asked for)
**After**: issue-actions
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. The owner's scope (2026-11-09, quoted in the issue) stands: the session root only. The three actions go to plan-task as plan inputs.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 09:51 -0500
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-418/plan.md` at `8e866811`

One PR: a small read-only helper (sitrep_root.sh) decides the session's root, roadmap, pull-request source (none for a hosting root without its own repository), record name and per-check skips; the skill uses it. Deferral row becomes Decided Against; work lands after #388.
