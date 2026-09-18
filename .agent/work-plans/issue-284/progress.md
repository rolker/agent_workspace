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
