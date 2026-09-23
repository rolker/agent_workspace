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

## Plan Authored
**Status**: complete
**When**: 2026-09-23 14:20 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-334/plan.md` at `c77cd67`

Revision addressing all 8 items from the Plan Review (79e5555): merge_pr.sh
bookkeeping lists now add `docs/roadmap.md` alongside `docs/ROADMAP.md`
instead of replacing it; `.github/workflows/validate.yml`'s required_files
gets the owner-approved Ask-First edit (`ARCHITECTURE.md` -> `docs/design.md`);
the reference sweep is split into workspace-own renames vs project-scope
dual-spelling additions; plus inspiration-tracker's roadmap writes,
`docs/design.md`'s own self-references (separate follow-up commit),
what-next's three-candidate project probe + AGENT_ONBOARDING.md link fix,
a post-merge `git ls-files` re-introduction check with a macOS note, and
#328 added to the merge-main watch list.

## Plan Review
**Status**: complete
**When**: 2026-09-23 13:30 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #334 — Docs reorganisation: move planning docs into docs/ with lowercase names; ARCHITECTURE.md becomes docs/design.md; discovery accepts both spellings
**Plan**: `.agent/work-plans/issue-334/plan.md` at `c77cd67`
**Branch**: `feature/issue-334`

Round 2 — re-review of the revision addressing the round-1 Plan Review (79e5555), checked against source at `db012b3` (main already merged; `git merge-base --is-ancestor main HEAD` true).

### Prior findings (round 1)

| # | Item | Status |
|---|---|---|
| 1 | `merge_pr.sh` bookkeeping lists additive + gate tests per spelling | Resolved — steps 4–5; lines 776/1097 confirmed; existing `docs/ROADMAP.md` fixtures (629, 1227) kept |
| 2 | `.github/workflows/validate.yml:73` `required_files` | Resolved — step 6, owner-approved Ask-First; line 73 confirmed; no other `.github/` hit |
| 3 | Workspace-own renames vs project-scope dual spelling | Partially — the split is right, but step 7 omits four workspace-own `docs/PRINCIPLES.md` lines (finding 1 below) |
| 4 | `inspiration-tracker` 251/259 | Resolved — 161 left alone, correctly |
| 5 | `docs/design.md` self-refs in a post-rename commit; `docs/roadmap.md:340` recorded | Resolved — step 9 line numbers are swapped (finding 3) |
| 6 | `what-next` three candidates; `AGENT_ONBOARDING.md:91` link | Resolved |
| 7 | `git ls-files` re-introduction check + macOS note | Resolved — step 13 |
| 8 | #328 on the merge-main watch list | Resolved in name; the description of #328's footprint is wrong and misses its `docs/ROADMAP.md` edit (finding 2) |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Single PR; three-commit split (pure rename / sweep+scripts+CI / design.md self-refs) keeps "content unchanged" literally true. |
| Issue alignment | Good | Both Issue Review actions, the three checkpoint corrections, and the CLAUDE.md-stays decision are in. |
| File targeting | Needs work | Step 7 misses four workspace-own `docs/PRINCIPLES.md` references (finding 1). |
| Consequences | Good | Additive merge-gate/roadmap handling, CI fix, discovery for both scopes, re-introduction check all present. |
| Principle alignment | Good | Workspace/project split now honours "don't force a convention on projects". |
| ADR compliance | Good | ADR-0008 not triggered (no ADR mentions the paths; re-verified by grep). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[File targeting — must-fix]** — Step 7 lists four workspace-scope skills, but four more skills name the workspace's *own* principles file and are listed in step 8 only for their project-scope lines: `.claude/skills/review-code/SKILL.md:276`, `.claude/skills/review-issue/SKILL.md:116`, `.claude/skills/review-plan/SKILL.md:172` (each "`docs/PRINCIPLES.md` — workspace principles"), and `.claude/skills/gather-project-knowledge/SKILL.md:110` ("Workspace principles (from `docs/PRINCIPLES.md`)"). After the `git mv` these point at a file that no longer exists in the three review skills that load principles on every run. Resolution: add all four lines to step 7 (rename to `docs/principles.md`) and to the Files-to-Change table (so the "4 skills" / "6 skills" rows become 8 workspace-scope rename sites across 8 skills plus the 6 project-scope ones), keeping step 8's dual-spelling edits on lines 200/176/120/112.
2. **[Concurrency — suggestion]** — The #328 description in Context and step 12 is out of date against the #328 plan (`feature/issue-328`, `15281bc`): #328 deletes CLAUDE.md's whole `## Tool Mapping` section (lines 15–43, not just the paragraph and table), rewords AGENTS.md's "Tool Usage" bullet (~line 118, not a script-table row), and **edits `docs/ROADMAP.md:373`** (drops `block-bash-tool-mapping` from the "Fail-closed hook audit" example list) — the one file this plan case-renames. Hunks are still disjoint from this plan's (CLAUDE.md:65, AGENTS.md:420), and merge-ort's rename detection carries a content edit across a 100%-similar rename in either order, so no plan change is needed beyond: (a) correct the #328 footprint in Context/step 12 and add `docs/ROADMAP.md:373` to the watch list; (b) if #334 lands first, #328's merge of `main` is the risky direction — note in this PR body (or as a comment on #328) that #328 should run the same `git ls-files docs/ROADMAP.md docs/PRINCIPLES.md ARCHITECTURE.md` check after merging `main` and confirm its roadmap edit landed in `docs/roadmap.md`.
3. **[Accuracy — suggestion]** — Step 9's line numbers are swapped: in the current `ARCHITECTURE.md`, line 47 is `│   ├── PRINCIPLES.md` (already under `docs/`, rename to `principles.md`) and line 52 is `├── ARCHITECTURE.md        # This file` (move under `docs/` as `design.md`). Line 222 is correct. Intent is clear; fix the numbers so the reviewer of commit 3 can audit against them.
4. **[Test design — suggestion]** — Step 3 says to run `discover_governance.sh` "with `ROOT_DIR` pointed at a sandbox", but `ROOT_DIR` is derived from `SCRIPT_DIR` (`$(cd "$SCRIPT_DIR/../.." && pwd)`, line 17), not overridable from the environment, and the project scan only looks at `$ROOT_DIR/project`. Resolution: have the test copy the script into `<sandbox>/.agent/scripts/` and build fixtures under `<sandbox>/` (workspace scope) and `<sandbox>/project/` (project scope) — no script change needed; do not add an env override just for the test.
5. **[File targeting — suggestion]** — `.agent/knowledge/principles_review_guide.md:60` also names "`ARCHITECTURE.md` directory tree" (workspace's own file), not only the principles file line 48; step 7 describes the file as referencing only the principles file. Rename both.

### Summary

The revision resolves round 1's merge-gate, CI, and scope-split problems and adopts every suggestion. One must-fix remains: four workspace-own `docs/PRINCIPLES.md` references (review-code, review-issue, review-plan, gather-project-knowledge) are missing from the rename list and would dangle after the move. The rest is watch-list accuracy (#328 also edits the roadmap file being renamed) and small corrections. All are mechanical; they can be folded into the plan or applied at implement time.

### Recommended Actions

- [ ] Add `review-code/SKILL.md:276`, `review-issue/SKILL.md:116`, `review-plan/SKILL.md:172`, `gather-project-knowledge/SKILL.md:110` to step 7 (rename to `docs/principles.md`) and the Files-to-Change table.
- [ ] Correct #328's footprint in Context/step 12 (whole `## Tool Mapping` section; AGENTS.md "Tool Usage" bullet; `docs/ROADMAP.md:373`) and flag that whichever branch merges `main` second runs the `git ls-files` re-introduction check.
- [ ] Fix step 9's swapped line numbers (47 = `PRINCIPLES.md` under docs/, 52 = `ARCHITECTURE.md # This file`).
- [ ] Step 3: build the discovery fixtures by copying the script into `<sandbox>/.agent/scripts/` (ROOT_DIR is not env-overridable).
- [ ] Include `principles_review_guide.md:60` (`ARCHITECTURE.md` directory tree) in the rename.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 13:39 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed + all 5 (Recommended): implement the plan at c77cd67 plus the round-2 Plan Review (815174e) items as instructions — must-fix: rename the workspace-principles references at .claude/skills/review-code/SKILL.md:276, review-issue/SKILL.md:116, review-plan/SKILL.md:172 and gather-project-knowledge/SKILL.md:110 to docs/principles.md (step 7 + Files to Change), keeping step 8's dual-spelling edits on lines 200/176/120/112; S1: #328 deletes CLAUDE.md's whole ## Tool Mapping section, rewords the AGENTS.md Tool Usage bullet and edits docs/ROADMAP.md:373 — whichever branch lands second runs the git ls-files check and confirms the roadmap edit landed in docs/roadmap.md; S2: step 9's line numbers are swapped (47 = PRINCIPLES.md under docs/, 52 = ARCHITECTURE.md # This file); S3: the discover_governance test copies the script into <sandbox>/.agent/scripts/ and builds fixtures under <sandbox>/ and <sandbox>/project/ (no env override); S4: also rename .agent/knowledge/principles_review_guide.md:60's ARCHITECTURE.md reference.

## Implementation
**Status**: complete
**When**: 2026-09-23 13:57 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-334 at `e2fa0c1`

Plan at `c77cd67` plus the five round-2 checkpoint instructions, in four commits:

- `c1a32d3` — pure `git mv`, content unchanged: `ARCHITECTURE.md` → `docs/design.md`, `docs/ROADMAP.md` → `docs/roadmap.md`, `docs/PRINCIPLES.md` → `docs/principles.md`.
- `bc4452e` — discovery accepts both spellings: `discover_governance.sh` adds `docs/design.md` / `docs/principles.md`; `update_roadmap.sh` adds `docs/roadmap.md`; `merge_pr.sh` adds `docs/roadmap.md` to both bookkeeping lists (old entries kept). A path that is the same file as an earlier spelling (case-insensitive filesystems) is reported/processed once. `validate.yml` `required_files` → `docs/design.md` (owner-approved). `project_governance.md` notes the lowercase names. Tests: new `test_discover_governance.sh` (sandbox copy of the script, workspace + project fixtures, both spellings, alias-once) and `test_update_roadmap.sh`; `test_merge_pr_gate.sh` gains ci-2b, ci-30 ×2 spellings, g5b.
- `50de10c` — reference sweep: workspace-own references renamed (README, AGENTS.md, CLAUDE.md, PR template, AGENT_ONBOARDING.md, principles_review_guide.md:48,60, eight skills' workspace-principles lines incl. review-code/review-issue/review-plan/gather-project-knowledge, inspiration-tracker 251/259, what-next workspace probe); project-scope references list both spellings (audit-project, review-code, review-plan, review-issue, brainstorm, gather-project-knowledge, review_depth_classification.md; what-next project probe = update_roadmap.sh's three candidates). README opening line: "one or more external project repositories".
- `e2fa0c1` — `docs/design.md` self-references (tree lines 47/52, Governance line 222).

Verified: `run_script_tests.sh` 29/29 suites green; old-path grep sweep leaves only the intended categories (project-scope dual spellings, old-spelling checks/fixtures, template example, inspiration-tracker:161); `git ls-files docs/ROADMAP.md docs/PRINCIPLES.md ARCHITECTURE.md` empty; validate.yml required-files logic passes locally; `discover_governance.sh` reports `docs/design.md` and `docs/principles.md` for the workspace. `docs/roadmap.md:340` checked and left as written. Main has not moved since the last merge.

Deviations: the same-file guard in both discovery scripts and `test_update_roadmap.sh` are additions beyond the plan (the macOS case-only rename would otherwise double-report `docs/PRINCIPLES.md`/`docs/principles.md` and double-visit the roadmap).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-23 14:12 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-334 at `247682a`
**Base**: main
**Depth**: Deep (reason: 29 files / +348 -51 outside work-plans; CI workflow + AGENTS.md/CLAUDE.md + skills are override triggers)
**Must-fix**: 1 | **Suggestions**: 1
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

Verified: `git show -M c1a32d3` = three renames at 100% similarity, 0 insertions/0 deletions; old-path grep (excluding ADRs, inspiration digests, other issues' work plans) leaves only project-scope dual spellings, old-spelling checks/fixtures, the template example, inspiration-tracker:161 and roadmap.md:340; no relative links inside docs/design.md; `git ls-files docs/ROADMAP.md docs/PRINCIPLES.md ARCHITECTURE.md` empty; main merged, origin/main 0 ahead; validate.yml required-files loop passes locally; test_discover_governance / test_update_roadmap / test_merge_pr_gate green; pre-commit (shellcheck, yamllint, script-test suite) clean on all changed files. Cross-model: codex complete (1 finding, below); gemini failed (headless ViewFile auto-denied, empty response). Claude adversarial: no findings.

Deviations: (a) `-ef` same-file guard — accepted (cheap, correct, tested on Linux; see must-fix for its tests); (b) extra `test_update_roadmap.sh` — accepted (plan had no coverage for the new roadmap candidate or the guard); (c) middle commit split in two — accepted (scripts/tests/CI vs reference sweep are separate logical changes; atomic-commit rule); (d) brainstorm/SKILL.md:37 at 114 chars — accepted (no markdown line-length lint; the file already has 117- and 139-char lines).

### Findings
- [x] (must-fix) New same-file tests break on the case-insensitive filesystems they target: `ln -s` onto an existing name aborts under `set -e`, and lowercase-path assertions (A2, C2, the docs/roadmap.md loop case) see the uppercase spelling checked first; detect case-insensitivity and adapt fixtures/assertions (also decide which spelling discovery reports there) — `.agent/scripts/tests/test_discover_governance.sh:104`, `.agent/scripts/tests/test_update_roadmap.sh:45`
- [x] (suggestion) Generic "ROADMAP.md" mentions that now describe the workspace's docs/roadmap.md missed the sweep (the verify grep only matched `docs/ROADMAP.md`) — `.claude/skills/what-next/SKILL.md:3,21`, `.claude/skills/inspiration-tracker/SKILL.md:228,341`

## Implementation
**Status**: complete
**When**: 2026-09-23 14:22 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-334 at `4038a8b`
**Addressed**: Local Review (Pre-Push) at `247682a` (2026-09-23 14:12 -04:00)
**Commits**: 97644a2, 4038a8b

### Actions
- [x] (must-fix) Case-insensitive filesystems: discovery now reports the file's stored name (host decision), resolved by a new sourced helper `.agent/scripts/_real_case_path.sh` (lists each directory; exact spelling first, else the case-variant entry). `discover_governance.sh` reports it; `update_roadmap.sh` reads, writes back and prints it (stdout feeds merge_pr.sh's git add), falling back with a warning if the helper is missing (it never blocks a merge). Tests probe TMPDIR case sensitivity: the one-file/two-spellings fixture skips `ln -s` on a case-insensitive FS and keeps the symlink (the `-ef` guard) on Linux; new D2/D3/D4 and stored-name roadmap cases assert the stored spelling; new `test_real_case_path.sh` exercises the case-insensitive lookup on Linux by requesting a spelling the directory does not hold; `test_merge_pr_gate.sh` copies the helper into its sandbox — `.agent/scripts/tests/test_discover_governance.sh`, `.agent/scripts/tests/test_update_roadmap.sh`
- [x] (suggestion) Generic ROADMAP.md mentions now say docs/roadmap.md / "the roadmap"; other repos' roadmaps untouched — `.claude/skills/what-next/SKILL.md:3,21`, `.claude/skills/inspiration-tracker/SKILL.md:228,341`

Verified: `run_script_tests.sh` 30/30 suites green; pre-commit (shellcheck, shebang/executable, script-test suite) clean on both commits. Not run on a real case-insensitive filesystem (none available on this Linux host); that path is covered by the resolver unit test and the adaptive fixtures.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-23 14:29 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-334 at `059c3a9`
**Base**: main
**Depth**: Deep (reason: whole-branch diff, 31 files outside work-plans; CI workflow + AGENTS.md/CLAUDE.md + skills are override triggers; fix round re-classified on the whole diff per #320)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round-1 findings resolved: the case-insensitive test must-fix (adaptive fixtures + stored-name reporting via `_real_case_path.sh`, D2–D4 / stored-name / R1–R10 cases) and the generic ROADMAP.md suggestion (what-next, inspiration-tracker).

Verified: shellcheck --severity=warning clean on all changed scripts/tests; yamllint clean on validate.yml; test_real_case_path 10/10, test_update_roadmap 6/6, test_discover_governance 15/15, test_merge_pr_gate 82/82. Merge from main (059c3a9): CLAUDE.md has no `## Tool Mapping` section and keeps the References edit; AGENTS.md carries #328's "Prefer dedicated tools where they fit" wording; `docs/roadmap.md` is byte-identical to main's `docs/ROADMAP.md` (includes #328's "Fail-closed hook audit" edit), `docs/principles.md` identical to main's `docs/PRINCIPLES.md`; `git ls-files docs/ROADMAP.md docs/PRINCIPLES.md ARCHITECTURE.md` empty; origin/main 0 ahead. update_roadmap.sh prints `$ROOT_DIR/<stored name>`, which merge_pr.sh strips to a toplevel-relative path for `git add` — correct for both spellings. Helper is bash-3.2 safe (array-guarded expansions, nocasematch not `${x,,}`, subshell-scoped shopt); Claude adversarial ran edge cases (empty rel, slashes, `./`, spaces, glob metacharacters) — all correct. Fallback-with-warning in update_roadmap.sh judged the right failure mode (the script never blocks a merge; on case-sensitive filesystems the fallback is exact). Cross-model: gemini failed (agy output-token limit), codex failed (usage limit) — no cross-model review this round.

### Findings
- [ ] (suggestion) discover_governance.sh sources `_real_case_path.sh` unguarded under `set -euo pipefail`, so a missing helper aborts with no output while update_roadmap.sh falls back with a warning — make the two consistent (soft fallback or a clear error) — `.agent/scripts/discover_governance.sh:19`
- [ ] (suggestion) update_roadmap.sh's helper-missing fallback (warning + candidate spelling) has no test; add a case that runs a copy without the helper and asserts the warning and the update — `.agent/scripts/update_roadmap.sh:28`
