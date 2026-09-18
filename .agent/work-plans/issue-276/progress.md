---
issue: 276
---

# Issue #276 — Port run-issue from ros2_agent_workspace: in-process orchestrator over the #269 review loop, no container baggage

## Implementation
**Status**: complete
**When**: 2026-09-18 11:46 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `cd1de96`

**Branch**: `feature/issue-276-pr1` at `0457029`
**Mode**: inline

PR 1 of the #276 port (PR #291): review-issue step 8 writes an ADR-0013 `## Issue Review` entry (170f513); test_issue_review_entry.sh, 6 cases (0457029). Plan §3 implemented as written; no deviations.

## Local Review
**Status**: complete
**When**: 2026-09-18 11:50 -04:00
**By**: Claude Code Agent (lead: claude-fable-5-1; specialists: claude-sonnet-5 governance + adversarial; shellcheck)
**Verdict**: approved

**PR**: #291 at `bf88e00`
**Depth**: Standard (reason: 211 lines; skill + test, no enforcement script)
**Must-fix**: 0 | **Suggestions**: 3

### Findings
- [x] (suggestion, governance) skill description now mentions the progress entry — `.claude/skills/review-issue/SKILL.md:3`
- [ ] (suggestion, adversarial; carried to PR 2) `progress_read.py` tags checkboxes by section but does not filter; `dispatch_phase.sh next` must count only `section == "Actions"` boxes for rows 5/6, with a distractor fixture — `.agent/scripts/progress_read.py:213-245`
- [ ] (suggestion, adversarial; carried to PR 2) review-code's LGTM placeholder is an unchecked box while Issue Review's no-actions box is checked; rows 13-15 route on `**Verdict**`, not boxes, so no change here, but the asymmetry is noted for the dispatcher's fixtures — `.claude/skills/review-code/SKILL.md:637`
- [ ] (suggestion, governance; unassigned) review-plan's "check review-issue comments" prose could name the persisted `### Actions` as a source — `.claude/skills/review-plan/SKILL.md:165`

## Implementation
**Status**: complete
**When**: 2026-09-18 12:35 -04:00
**By**: Claude Code Agent (implementer: claude-sonnet-5; lead: claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `cd1de96`

**Branch**: `feature/issue-276-pr2` at `ba88f24`

PR 2 of the #276 port (PR #293): dispatch_phase.sh (03121fe), test_dispatch_phase.sh with 73 cases incl. all 28 next rows and five end-to-end timelines (28bbd1a), and one plan deviation decided by the lead: PR-mode Local Review routes on **Verdict** for rows 22a/22b, not open boxes, because the unchecked LGTM placeholder would loop forever (ba88f24). Plan text to be updated under PR 3.

## Local Review
**Status**: complete
**When**: 2026-09-18 12:43 -04:00
**By**: Claude Code Agent (lead: claude-fable-5-1; specialists: claude-sonnet-5 governance + adversarial; shellcheck; gemini skipped per owner)
**Verdict**: changes-requested

**PR**: #293 at `ba88f24`
**Depth**: Deep (reason: 990 lines; enforcement script)
**Must-fix**: 1 | **Suggestions**: 2

### Findings
- [x] (must-fix, adversarial) round_count counted partial/failed Pre-Push reviews, so a retried round hit MAX_ROUNDS one round early; filter status == complete, fixture added — `.agent/scripts/dispatch_phase.sh:425-435`
- [x] (suggestion, adversarial) no --type project fixture for resolve_worktree; two added — `.agent/scripts/tests/test_dispatch_phase.sh`
- [x] (suggestion, adversarial) --check-exit inspects only the newest entry when a phase writes twice; comment added — `.agent/scripts/dispatch_phase.sh:287`

## Local Review
**Status**: complete
**When**: 2026-09-18 12:44 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**PR**: #293 at `f84c784`
**Depth**: Light (reason: round 2; delta ba88f24..f84c784 is the one fix commit, verified by reading the diff and rerunning the suite)
**Must-fix**: 0 | **Suggestions**: 0

### Findings
- [ ] No issues found. LGTM. test_dispatch_phase 76/76, full suite 22/22, shellcheck clean.

## Implementation
**Status**: complete
**When**: 2026-09-18 13:17 -04:00
**By**: Claude Code Agent (implementer: claude-sonnet-5; lead: claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-276/plan.md` at `0ace344`

**Branch**: `feature/issue-276-pr3` at `6d12f37`

PR 3 of the #276 port (PR #294): run-issue SKILL.md (0b1efa4), ADR-0014 + ADR-0013 note (673f14f), lifecycle note + principles guide + onboarding + ARCHITECTURE (7bae93c), AGENTS.md script row (6d12f37). Skill is ~325 lines vs the plan's ~300 target; claims verified against dispatch_phase.sh as merged.

## Local Review
**Status**: complete
**When**: 2026-09-18 13:25 -04:00
**By**: Claude Code Agent (lead: claude-fable-5-1; specialists: claude-sonnet-5 doc-accuracy/adversarial + governance; gemini skipped per owner)
**Verdict**: changes-requested

**PR**: #294 at `6e7063c`
**Depth**: Standard (reason: 639 lines of skill + docs; AGENTS.md one row under standing rule 2)
**Must-fix**: 3 | **Suggestions**: 2

### Findings
- [x] (must-fix, adversarial) step 4's before-count called progress_read.py on a not-yet-existing progress.md (exit 1); guarded, missing file = 0 — `.claude/skills/run-issue/SKILL.md`
- [x] (must-fix, adversarial) step 4 never checked `mode=inline`, which row 27 emits for any taken-over phase; step 4 checks first and step 5 covers non-implement takeovers with no **Mode** field — `.claude/skills/run-issue/SKILL.md`
- [x] (must-fix, governance) step 10 omitted that entry commits after the last review are pushed before merging and why that is safe (#286 ancestry rule) — `.claude/skills/run-issue/SKILL.md`
- [x] (suggestion, governance) Scope section with the three owner notes (#208/#209, #265, ADR-0012) — `.claude/skills/run-issue/SKILL.md`
- [x] (suggestion, adversarial) ADR-0013 References bullet trimmed to a pointer; routing detail moved to ADR-0014 Decision — `docs/decisions/0013-progress-md-entry-type-vocabulary.md`

## Local Review
**Status**: complete
**When**: 2026-09-18 13:26 -04:00
**By**: Claude Code Agent (lead: claude-fable-5-1; round-2 verifier: claude-sonnet-5)
**Verdict**: approved

**PR**: #294 at `c350499`
**Depth**: Light (reason: round 2; delta 6e7063c..c350499 is the one fix commit, each item verified against dispatch_phase.sh and merge_pr.sh)
**Must-fix**: 0 | **Suggestions**: 0

### Findings
- [ ] No issues found. LGTM. All five round-1 items resolved; no new inaccuracy introduced.
