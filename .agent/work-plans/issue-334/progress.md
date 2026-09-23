---
issue: 334
---

# Issue #334 — Docs reorganisation: move planning docs into docs/ with lowercase names; ARCHITECTURE.md becomes docs/design.md; discovery accepts both spellings

## Issue Review
**Status**: complete
**When**: 2026-09-23 12:52 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #334

### Scope Assessment

**Well-scoped?** Yes — mechanical, no content decisions (deferred to companion issue #335), single PR feasible.
**Right repo?** Yes — workspace infrastructure (`docs/`, scripts, skills, templates).
**Dependencies**: #335 (design-document content) depends on this landing first; issue states that correctly.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| A change includes its consequences | OK | Issue explicitly scopes script updates + tests + reference sweep in the same PR. |
| Workspace vs. project separation | OK | Scope item 4 correctly keeps discovery from forcing a naming convention on projects. |
| Only what's needed | OK | Scope is mechanical; content rewrite explicitly deferred. |
| Enforcement over documentation | Watch | Acceptance relies on a manual `grep` sweep rather than a script/test asserting no stale references remain; consider whether `discover_governance.sh`'s own test suite should assert this. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0008 (cross-reference addendums in ADRs) | Yes | Issue correctly treats ADR bodies as immutable and doesn't propose editing them. |
| ADR-0013 (progress.md vocabulary) | No | Not touched by this issue. |

### Consequences

- Confirmed: `merge_pr.sh`'s bookkeeping allow-list and `update_roadmap.sh`'s discovery both need the `docs/roadmap.md` path, with `test_merge_pr_gate.sh` coverage — matches the issue's claim.
- Confirmed: `discover_governance.sh`'s `scan_scope()` runs identically over both the workspace root and a registered project (`scan_scope "$ROOT_DIR" "workspace"` at line 82, `scan_scope "$project_dir" "project"` at line 88). Moving the workspace's own `ARCHITECTURE.md` to `docs/design.md` will make the workspace's own architecture doc disappear from discovery unless a `docs/design.md` (or equivalent) check is added — this is a workspace-scope consequence, not just the project-scope "don't force a convention" concern the issue frames it as. The acceptance criterion ("Governance discovery finds both old- and new-spelling files in a project") doesn't cover this workspace-scope regression; recommend widening it.
- `.agent/knowledge/inspiration_*_digest.md` files (e.g. `inspiration_ros2_agent_workspace_digest.md`, `inspiration_engram_digest.md`) contain historical, factual statements about other repos' `ROADMAP.md`/`ARCHITECTURE.md` files. These match the acceptance criterion's `grep` sweep but must not be rewritten — doing so would misstate what those external/historical snapshots actually said. The stated exemption list ("outside ADR bodies and historical work plans") doesn't cover them; recommend adding inspiration digests to the exemption.

### Recommendations

- Verify against the repo before merging (this review already caught two count/claim errors) rather than trusting the issue's numbers verbatim.
- Add `.agent/knowledge/inspiration_*_digest.md` to the acceptance criterion's exemption list alongside ADR bodies and historical work plans.
- Extend the "discovery accepts both spellings" acceptance test to also cover the workspace's own scan (root scope), not only a project fixture — otherwise `discover_governance.sh` output for the workspace itself loses its architecture-doc line after the move.

### Actions
- [ ] Add `.agent/knowledge/inspiration_*_digest.md` to the acceptance criterion's exemption list alongside ADR bodies and historical work plans.
- [ ] Extend the "discovery accepts both spellings" acceptance test to also cover the workspace's own scan (root scope), not only a project fixture — otherwise `discover_governance.sh` output for the workspace itself loses its architecture-doc line after the move.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 12:56 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed (Recommended): plan with both Issue Review actions — (1) the "accepts both spellings" test also covers the workspace's own scan (discover_governance.sh scan_scope runs on the workspace root too; after the move it must still find docs/design.md), (2) exempt .agent/knowledge/inspiration_*_digest.md from the old-path sweep — and the three corrections: discover_governance.sh / project_governance.md do not look for ROADMAP.md (only PRINCIPLES.md and ARCHITECTURE.md); nine skills read the principles, not eight; no ADR mentions these paths, so there is no ADR References work.

## Plan Authored
**Status**: complete
**When**: 2026-09-23 13:40 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-334/plan.md` at `26e871f`

Mechanical `git mv` of `ARCHITECTURE.md`→`docs/design.md`,
`docs/ROADMAP.md`→`docs/roadmap.md`, `docs/PRINCIPLES.md`→`docs/principles.md`;
`discover_governance.sh` gains new-spelling checks (accepts both) plus a new
test suite; `merge_pr.sh`/`update_roadmap.sh`/their tests get path fixes; a
~20-file reference sweep excludes ADR bodies, inspiration digests, and
historical work-plans. Owner decided CLAUDE.md stays at the root (retirement
is a separate later issue) — folded into the plan, no open questions remain.

## Plan Review
**Status**: complete
**When**: 2026-09-23 13:08 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #334 — Docs reorganisation: move planning docs into docs/ with lowercase names; ARCHITECTURE.md becomes docs/design.md; discovery accepts both spellings
**Plan**: `.agent/work-plans/issue-334/plan.md` at `26e871f`
**Branch**: `feature/issue-334`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Single PR, mechanical; two-commit split (pure renames, then sweep) is right. |
| Issue alignment | Good | Both Issue Review actions and the three checkpoint corrections are folded in; CLAUDE.md-stays-at-root decision recorded. |
| File targeting | Needs work | Sweep misses `.github/workflows/validate.yml` (CI hard-requires root `ARCHITECTURE.md`) and `.claude/skills/inspiration-tracker/SKILL.md` (writes to `docs/ROADMAP.md`); `docs/design.md`'s own tree/self-references are not addressed. |
| Consequences | Concern | `merge_pr.sh` bookkeeping patterns swap `docs/ROADMAP.md` for `docs/roadmap.md` instead of accepting both — breaks pre-rename branches and project repos that keep the uppercase roadmap. |
| Principle alignment | Needs work | "Don't force a convention on projects" is honoured in `discover_governance.sh` / `update_roadmap.sh` but step 6's blanket "each reference becomes the new path" would rewrite project-scope mentions (project `PRINCIPLES.md` / `ARCHITECTURE.md`) in skills and `review_depth_classification.md`. |
| ADR compliance | Good | ADR-0008 not triggered (no ADR mentions the paths; verified by grep). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences]** — `merge_pr.sh` step 4 replaces `"docs/ROADMAP.md"` with `"docs/roadmap.md"` in both bookkeeping lists (line 776 `_only_bookkeeping_between`, line 1097 `MERGE_PR_CI_BOOKKEEPING_PATTERNS`). These lists apply to project PRs too, and `update_roadmap.sh` (per step 4) keeps finding and editing `docs/ROADMAP.md` — so a project with `docs/ROADMAP.md`, or a workspace branch that predates the rename (its worktree still has `docs/ROADMAP.md` and its host-pushed roadmap commit touches that path), would get a roadmap commit that the gate no longer treats as bookkeeping → stale-review hold / fresh CI wait. Resolution: add `"docs/roadmap.md"` alongside the existing entries in both lists (keep `docs/ROADMAP.md` permanently, matching `update_roadmap.sh`), and add a `test_merge_pr_gate.sh` case for each spelling rather than only rewriting the existing fixtures.
2. **[File targeting]** — `.github/workflows/validate.yml:73` has `required_files="README.md ARCHITECTURE.md AGENTS.md"`; after the `git mv` the Validate Documentation job fails on this PR and every later one. Not in the plan's list. Resolution: change to `docs/design.md`; this is a CI change (AGENTS.md "Ask First"), so surface it to the owner at the implement checkpoint.
3. **[Principle alignment]** — Step 6 rule "each reference becomes the new path" is too blunt: several hits are project-scope, not the workspace's own files — `audit-project` SKILL.md lines 80/81/148, `review-code` l.200, `review-plan` l.176, `review-issue` l.120, `brainstorm` l.36-37, `gather-project-knowledge` l.112, and `review_depth_classification.md:98` (`docs/PRINCIPLES.md`, `PRINCIPLES.md` governance-file tier, applies to project diffs). Resolution: split the sweep into workspace-path references (rename) vs project-scope references (list both spellings, e.g. "`PRINCIPLES.md` / `docs/principles.md`", "`ARCHITECTURE.md` / `docs/design.md`"); for `review_depth_classification.md` add `docs/principles.md` (and `docs/design.md` if architecture docs belong in that tier) without dropping the old spellings.
4. **[File targeting]** — `.claude/skills/inspiration-tracker/SKILL.md` lines 251 and 259 direct writes to `docs/ROADMAP.md` (plus line 161 `ARCHITECTURE.md` as a tracked config file of *other* repos — that one should stay). Not in the plan's list; would write to a non-existent file after the move. Resolution: add it, updating 251/259 only.
5. **[Consistency]** — "content unchanged" for `docs/design.md` conflicts with step 10's grep gate: the moved file's own directory tree (lines 47, 52 — `ARCHITECTURE.md # This file` at root, `PRINCIPLES.md` under docs/) and line 222 (`docs/PRINCIPLES.md`) become factually wrong and will match the verify grep. Resolution: update those path mentions in a separate commit after the pure-rename commit (path fixes, not content rewrite), and list `docs/roadmap.md` line 340 (`AGENTS.md / PRINCIPLES.md` prose) as intentionally left.
6. **[File targeting]** — Minor: `what-next` SKILL.md line 35 (`project/ROADMAP.md`) is project-scope — should also accept `project/docs/ROADMAP.md` / `docs/roadmap.md`, matching `update_roadmap.sh`'s three candidates; `.agent/AGENT_ONBOARDING.md:91` uses a relative `../ARCHITECTURE.md` link → `../docs/design.md`.
7. **[Transition]** — Case-only rename `docs/ROADMAP.md`→`docs/roadmap.md` (and PRINCIPLES): Linux/GitHub merges of pre-rename branches that edit the old path resolve via rename detection, but a branch that *adds* a new line to `docs/ROADMAP.md` after a non-rename-aware rebase could recreate the uppercase file. Resolution: in step 10's verify, also assert `git ls-files docs/ROADMAP.md docs/PRINCIPLES.md ARCHITECTURE.md` is empty after each `main` merge; note in the PR body that case-insensitive clones (macOS) need a clean pull.
8. **[Concurrency]** — Conflict risk, not a blocker: #328 (retire the Bash tool-mapping hook) edits CLAUDE.md's "Enforced by hook" paragraph and tool-mapping table; this plan touches only CLAUDE.md's `## References` list (line 65) — separate hunks, low risk. #320 edits one AGENTS.md script-table row; this plan touches AGENTS.md line 420 (References) — separate hunks. Step 9's merge-`main` discipline covers both; add #328 to step 9's list.

### Summary

Sound, mechanical plan with the review-issue feedback folded in, but it misses a CI workflow that hard-requires the old root file, and its merge-gate change removes rather than adds the old roadmap spelling — which breaks both pre-rename branches and projects that keep `docs/ROADMAP.md`. The sweep also needs a workspace-vs-project split so it does not impose the new names on projects.

### Recommended Actions

- [ ] Keep `docs/ROADMAP.md` and add `docs/roadmap.md` in both `merge_pr.sh` bookkeeping lists (lines 776, 1097); add gate test cases for both spellings.
- [ ] Add `.github/workflows/validate.yml` (`ARCHITECTURE.md` → `docs/design.md` in `required_files`) to the plan and flag it to the owner as an Ask-First CI change.
- [ ] Split step 6 into workspace-path renames vs project-scope mentions that list both spellings (audit-project, review-code, review-plan, review-issue, brainstorm, gather-project-knowledge, `review_depth_classification.md`).
- [ ] Add `.claude/skills/inspiration-tracker/SKILL.md` lines 251/259 (`docs/ROADMAP.md` → `docs/roadmap.md`) to the sweep.
- [ ] Fix `docs/design.md`'s own tree/self-references (lines 47, 52, 222) in a commit after the pure rename, and record `docs/roadmap.md:340` as intentionally unchanged.
- [ ] Update `what-next` project roadmap discovery to the same candidate set as `update_roadmap.sh`; fix `AGENT_ONBOARDING.md:91` relative link.
- [ ] Extend step 10 verify with `git ls-files` checks that the old paths are not re-introduced after each `main` merge.
- [ ] Add #328 to step 9's merge-`main` conflict watch list.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 13:17 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise, all 8 (Recommended): fix the three must-fix items from the Plan Review — (1) keep docs/ROADMAP.md permanently in both merge_pr.sh bookkeeping lists and add docs/roadmap.md, with gate tests for each spelling; (2) .github/workflows/validate.yml required_files: ARCHITECTURE.md -> docs/design.md (owner APPROVED this CI edit, Ask-First, 2026-09-23); (3) rename only references to the workspace's own files; references to project files list both spellings — and adopt suggestions 4-8 (inspiration-tracker writes; fix docs/design.md's own links in a commit after the pure rename; what-next probes the same three roadmap locations as update_roadmap.sh and fix AGENT_ONBOARDING.md's relative link; a git ls-files check after each main merge plus a macOS case-only-rename note in the PR body; add #328 to the branches to watch).
