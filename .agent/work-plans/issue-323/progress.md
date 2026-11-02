---
issue: 323
---

# Issue #323 — Small tooling fixes

## Issue Review
**Status**: complete
**When**: 2026-11-02 11:53 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #323

### Scope Assessment

**Well-scoped?** Yes — three independent small fixes, already specified as three atomic commits each with its test. Checked today against the tree: none has landed (`worktree_create.sh` still runs `git worktree add -b` from current HEAD in its no-parent branch; `gh_create_issue.sh` has no signature code; `_bookkeeping.sh` still prints "which is not a merge-time document file").
**Right repo?** Yes — all three are workspace scripts.
**Serves**: Quality of the work (worktree base, merge-line wording) and Trust, control and information (agent-created issues carry who wrote them) — `docs/design.md#worktrees`, `docs/design.md#merge-gate`, `docs/design.md#identity`
**Design picture?** No change — item 1 restores the intent of the Worktrees section; item 3 keeps the "one rule in `_bookkeeping.sh`" statement in Merge gate true. If item 3 is solved by folding patterns into Step 2, the design text stays as written.
**Dependencies**: none identified. Item 1 touches the `--parent-issue` path, so it should not disturb sub-issue worktrees.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | Action needed | The issue names `test_worktree_create*.sh`, but no such suite exists (tests mentioning `worktree_create` only use it as a fixture), and there is no `gh_create_issue` suite either. Create both, and make each new test fail without its fix. |
| Small steps; step back when they stop converging | Watch | Three commits in one PR is fine; keep them separable so a review round on one does not hold the others. |
| A change includes its consequences | Watch | Item 3 changes a printed line; check the existing `test_merge_pr_gate.sh` fixtures and any doc quoting the old wording. Item 1 changes where new branches start: `.agent/WORKTREE_GUIDE.md` should say so if it describes the base. |
| Leave a trail; start limits strict | Watch | Item 2 should follow `gh_create_pr.sh` exactly, including the hard-fail when identity is unset and a body is given, so no unsigned issue slips through. |
| Put each thing at the level it applies to | OK | Item 1 uses `_resolve_default_branch.sh`, with no project names. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0002 — Worktree isolation | Yes (item 1) | Worktree creation behaviour. |
| 0012 — Worktree composition is an adapter concern | Yes (item 1) | Keep the base-branch change in the generic path and loop over the `.worktree-repos` manifest, with no project-type checks. For project worktrees, resolve the default branch per repo. |
| 0013 — progress.md vocabulary | No | |

### Consequences

- `.agent/WORKTREE_GUIDE.md` and the AGENTS.md worktree text, if they state the base branch.
- Script table row for `gh_create_issue.sh` in AGENTS.md should mention the signature and `--no-signature`.
- Any callers that pass a body to `gh_create_issue.sh` without identity set will now hard-fail; grep skills and scripts for them.

### Recommendations

- Decide the item 3 variant before planning: folding the bookkeeping patterns into Step 2 is preferred, since it leaves one rule (matching the Merge gate design text) instead of a reworded message over two.
- For item 1, define the behaviour when `origin/<default>` is unreachable (offline): fall back to the local default branch with a printed warning, never silently to HEAD. For issue worktrees, state in the plan whether `--parent-issue` remains the only way to branch from a feature branch.
- Item 2 recently recurred (workspace issue 415, "onboard-project fixes from the first real onboarding run", was signed by hand with `gh issue edit`); consider doing it first.
