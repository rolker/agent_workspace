---
issue: 173
---

# Issue #173 — merge_pr.sh: project PRs fail silently when --type is omitted

## Plan
**Status**: complete
**When**: 2026-05-07 21:30
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-173/plan.md`.

Replace path-based auto-detect with `git worktree list --porcelain`
enumeration; try both workspace and project remotes for the PR lookup so
type can be determined from the first repo that returns a hit; add
`MERGE_PR_ARGS` passthrough on the Makefile rule.

## Plan Review
**Status**: complete
**When**: 2026-05-07 22:00
**By**: Independent reviewer (general-purpose subagent)
**Verdict**: changes-requested (minor)

Findings 1, 2, 4, 5 applied to the plan; finding 3 (test scaffold)
declined per "Only what's needed" — manual smoke test committed in
the plan with deterministic reproduction documented in PR description.

## Implementation
**Status**: complete
**When**: 2026-05-07 22:30
**By**: Claude Code Agent (claude-opus-4-7)

- Added `find_worktree_for_branch` helper near top of script — wraps
  `git worktree list --porcelain` so paths come from git rather than
  string concatenation.
- Replaced lines 88–143 (resolve_gh_repo_args + initial gh pr view +
  old auto-detect) with: workspace/project remote discovery (with
  explicit "missing project remote" error), `query_pr` helper that
  distinguishes not-found from auth/network errors, two-repo collision-
  safe lookup with 0/1/2-hit semantics.
- Replaced lines 156–162 path-building in roadmap-update step with the
  same `find_worktree_for_branch` helper.
- Removed redundant `resolve_gh_repo_args` call before `gh pr merge`
  (GH_REPO_ARGS now set during PR resolution).
- Added `$(MERGE_PR_ARGS)` passthrough on Makefile `merge-pr:` rule.
- Diff size: +141/-56 in merge_pr.sh, +1/-1 in Makefile.

### Smoke tests (pre-PR)

- [x] `bash -n` — syntax clean.
- [x] `shellcheck --severity=warning` — no new findings; three pre-
      existing SC2015 infos in untouched lines remain.
- [x] Helper sanity check — `find_worktree_for_branch` correctly
      finds workspace worktrees, project worktrees in multi-project
      layout (`worktrees/project/<repo>/...`), and returns empty for
      non-existent branches and wrong-repo queries.
- [x] **End-to-end auto-detect verified**: `merge_pr.sh --pr 72` (open
      project PR, no `--type`) resolved to project repo, extracted
      issue #71, ran roadmap update, and reached the merge step where
      gh correctly refused due to unrelated merge conflicts on #72.
      **This is the bug being fixed** — pre-fix this exited silently
      with `Error 1`.
- [x] Closed-PR error path: `merge_pr.sh --pr 84` errors cleanly with
      "PR #84 not open in either workspace or project."
- [x] Type-aware not-found: `merge_pr.sh --pr 99999 --type project`
      errors with "PR #99999 not open in project repo."
- [x] Workspace PR auto-detect: `merge_pr.sh --pr 177` (own draft PR)
      correctly resolved to workspace; gh refused merge of draft as
      expected.
