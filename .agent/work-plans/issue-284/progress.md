---
issue: 284
---

# Issue #284 — merge_pr.sh: gate record push moves the PR head after the CI wait; retries duplicate the Merge entry

## Plan Authored
**Status**: complete
**When**: 2026-09-18 09:00 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-284/plan.md` at `ac7d040`

Keep server-side protection; wait for CI on the reviewed head via a SHA-targeted check-runs poll (fixes #271), exempt a progress.md-only record commit from a second CI round, and make the Merge record idempotent per PR.

## Plan Review
**Status**: complete
**When**: 2026-09-18 09:01 -04:00
**By**: Independent plan reviewer (claude-sonnet-5)
**Verdict**: needs-work

**PR**: https://github.com/rolker/agent_workspace/pull/285 — [PLAN] merge_pr.sh: wait for CI on the reviewed head; exempt progress.md-only record commits; idempotent Merge record
**Issue**: #284 — merge_pr.sh: gate record push moves the PR head after the CI wait; retries duplicate the Merge entry
**Plan**: `.agent/work-plans/issue-284/plan.md` at `ac7d040`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Tightly bounded to `merge_pr.sh` + its two test files + two docs; single PR; folds in #271 correctly (same Step-2 code path). |
| Issue alignment | Good | Implements the owner's 2026-09-18 comment literally: server-side protection untouched, exemption scoped to `progress.md` only, roadmap commit still waits for full CI, idempotent-per-PR record, #271 folded in. |
| File targeting | Good | Right files. Minor: `gh pr checks --watch --fail-fast` is named in at least 5 places in `agent_wait_patterns.md` (lines ~31, 40, 57, 58, 65), not one row. |
| Consequences | Needs work | Repos with no CI configured, and a concurrent-push/force-push race, are not accounted for (Findings 1 and 3). |
| Principle alignment | Needs work | Human control and transparency: Finding 2's skip-without-comparing-conditions can leave the Merge record stale on a second run with different reasons. |
| ADR compliance | Good | ADR-0013 and ADR-0004 correctly triggered and addressed; ADR-0010 N/A. |
| ROS conventions | N/A | workspace plan |

### Findings

1. **[Consequences]** (must-fix) — Zero-CI-configured repos will always time out and fail to merge under the new poll. "Zero check runs registered" is indistinguishable from "this repo never registers checks" (project repos without workflows, test sandboxes); those burn the full timeout and hard-fail every merge unless `--no-wait`. The plan needs a way to tell "hasn't started" from "will never start", e.g. check whether the repo has any registered workflows before polling, or treat an empty rollup for the whole window as a pass, and say so explicitly.
2. **[Consequences / Human control and transparency]** (must-fix) — The idempotency rule ("latest entry is a Merge record for this PR → skip") does not compare the stored `**Conditions**` to the freshly computed gate reasons. If a second run's reasons differ, the skip leaves an inaccurate record. Refresh (append) when reasons differ; skip only on an exact match.
3. **[Consequences]** (must-fix) — No ancestry or local-availability check before the `HEAD_REVIEWED..HEAD_NOW` diff. A concurrent agent could push to the same branch between the record push and the re-read, or a force-push could rewrite history; the diff may fail (SHA not fetched) or wrongly grant the exemption. Fetch before diffing, confirm `git merge-base --is-ancestor HEAD_REVIEWED HEAD_NOW`, and fall back to a full CI wait on `HEAD_NOW` whenever ancestry cannot be established.
4. **[Test plan]** (suggestion; must-fix if 1 and 3 are adopted) — Missing cases: no-CI-repo behaviour; mergeability poll never leaving `UNKNOWN` (clear timeout error); PR-comment fallback combined with the per-PR idempotency rule; the ancestry/local-availability race.

### Summary

The plan implements the owner's decision and stays tightly scoped, but has three consequence gaps: no-CI repos would start failing every merge after a full timeout, the idempotency skip can leave a stale audit record, and the progress-only diff trusts local availability and linear ancestry it never verifies. Fixable within the existing approach; resolve before implementation, with the matching test cases.

### Recommended Actions

- [ ] Add an explicit rule distinguishing "CI hasn't started" from "this repo has no CI"
- [ ] Compare current gate reasons against the latest Merge entry's `**Conditions**`; refresh when they differ, skip only on exact match
- [ ] `git fetch` + `git merge-base --is-ancestor` before trusting the path-only diff, with a full-CI-wait fallback
- [ ] Extend tests: no-CI repo, mergeability never settles, PR-comment fallback + idempotency, ancestry race

## Plan Authored
**Status**: complete
**When**: 2026-09-18 09:06 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-284/plan.md` at `c4f81f4`

Revision 2 after the plan review: the CI poll distinguishes "no CI configured" (proceed) from "configured but unregistered" (grace-window error); the Merge record is idempotent per PR and per conditions; the progress.md exemption requires a fetch, ancestry, and a one-path diff; seven extra test cases.

## Plan Review
**Status**: complete
**When**: 2026-09-18 09:08 -04:00
**By**: Independent plan reviewer (claude-sonnet-5)
**Verdict**: ready

**PR**: https://github.com/rolker/agent_workspace/pull/285 — [PLAN] merge_pr.sh: wait for CI on the reviewed head; exempt progress.md-only record commits; idempotent Merge record
**Issue**: #284 — merge_pr.sh: gate record push moves the PR head after the CI wait; retries duplicate the Merge entry
**Plan**: `.agent/work-plans/issue-284/plan.md` at `c4f81f4`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged from round 1; single PR, tightly bounded. |
| Issue alignment | Good | Owner's decision honoured literally. |
| File targeting | Good | Same files. |
| Consequences | Good | No-CI-repo gap and ancestry/local-availability gap now covered in the Approach and Consequences table. |
| Principle alignment | Good | Idempotency refreshes on differing conditions; audit trail no longer risks going stale. |
| ADR compliance | Good | Unchanged. |
| ROS conventions | N/A | workspace plan |

### Findings

Round-1 findings re-checked against revision c4f81f4:

1. **No-CI rule** — Resolved. Three cases: zero workflows + no runs → proceed with a note; workflows but nothing registered within the grace window → explicit error naming the SHA; registered but pending → poll to the timeout.
2. **Idempotency** — Resolved. Skip keyed on PR + entry type + exact `**Conditions**` match; any difference appends a fresh entry; applies to the PR-comment fallback; both cases tested.
3. **Ancestry / fetch / single-path diff** — Resolved. Fetch, local resolution, `merge-base --is-ancestor`, and a one-path diff are all required; otherwise full CI wait on the new head with the failed condition named.
4. **Test cases** — Resolved. Seven added cases cover every round-1 gap.

No new problems found; the added logic is consistent with the script's existing worktree resolution, PR-comment fallback, and package-PR exclusion.

### Summary

All four must-fix items are addressed with matching test coverage and no new gaps. Ready for implementation.

### Recommended Actions

- [x] None outstanding; proceed to implementation

## Plan Authored
**Status**: complete
**When**: 2026-09-18 09:13 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-284/plan.md` at `83e9355`

Revision 3 on the owner's answer: the CI exemption covers every document file the script itself commits once the merge is approved (roadmap and progress.md), keyed on the paths actually committed in the run. One test case added.

## Implementation
**Status**: complete
**When**: 2026-09-18 09:54 -04:00
**By**: Claude Code Agent (implementer: claude-sonnet-5; lead: claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-284/plan.md` at `2561ff9`

**Branch**: `feature/issue-284` at `2561ff9`

Four commits: 96e716e (merge_pr.sh: reviewed-head capture, committed-path tracking, fetch + ancestry + paths-only exemption, SHA-targeted check-runs/status poll with no-CI / not-registered / registered rules, mergeability settle poll with one retry, per-PR per-conditions idempotent record; also fixed a latent `${var:-{}}` brace-parsing bug that corrupted JSON), f0fa2aa (15 new gate test cases, 41 total), d307b31 (agent_wait_patterns.md, AGENTS.md row), 2561ff9 (plan synced; REST-fallback decision in Implementation Notes).

Deviation: REST merge fallback not added; the observed #282 failure was `mergeable: UNKNOWN`, which the settle poll fixes. Tests: gate 41/41, merge 91/91, root-resolution 5/5, full suite 20/20; shellcheck clean.

## Local Review
**Status**: complete
**When**: 2026-09-18 09:59 -04:00
**By**: Claude Code Agent (lead: claude-fable-5-1; specialists: claude-sonnet-5 governance + adversarial, gemini cross-model, shellcheck)
**Verdict**: changes-requested

**PR**: #285 at `4068195`
**Depth**: Deep (reason: 1107 lines changed; enforcement script + AGENTS.md)
**Must-fix**: 2 | **Suggestions**: 6

### Findings
- [ ] (must-fix, cross-confirmed: gemini + adversarial) a failed `gh api` call (rate limit, network, 5xx) is folded into "no CI configured" and the script proceeds to merge unverified; distinguish API failure from an empty result and retry/error instead — `.agent/scripts/merge_pr.sh:913-918,963-965`
- [ ] (must-fix, gemini) `startup_failure` (and `stale`) check-run conclusions are not in the failed list, so a broken workflow counts as success — `.agent/scripts/merge_pr.sh:924`
- [ ] (suggestion, adversarial) check-runs call is not paginated; failures past the 30th run are invisible — `.agent/scripts/merge_pr.sh:913`
- [ ] (suggestion, gemini) `_wait_for_mergeable` returns 0 on `CONFLICTING`; fail early with a clear message instead of letting `gh pr merge` fail — `.agent/scripts/merge_pr.sh:940-959`
- [ ] (suggestion, gemini) guard the empty-array append of `_ROADMAP_STAGED_PATHS` like line 868 does — `.agent/scripts/merge_pr.sh:568`
- [ ] (suggestion, adversarial) no test covers the CI wait when no local worktree exists (the `_ci_wt` empty branch at 860-862) — `.agent/scripts/tests/test_merge_pr_gate.sh`
- [ ] (suggestion, governance) header comment says `--no-wait` skips all of Step 2, but the CI-target computation runs unconditionally — `.agent/scripts/merge_pr.sh:32`
- [ ] (suggestion, governance) note near `_gate_already_recorded` that matching on PR number without the SHA is a deliberate exception to ADR-0013's SHA correlation — `.agent/scripts/merge_pr.sh:765`
