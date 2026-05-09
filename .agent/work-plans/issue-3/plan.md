# Plan: Add branch mode to /review-code (local pre-push self-review)

## Issue

https://github.com/rolker/agent_workspace/issues/3

## Context

`/review-code` runs after a PR is open on GitHub. Step 1 fetches diff and
metadata via `gh pr view` / `gh pr diff`; Step 8 persists findings to
`progress.md` keyed by the issue number derived from the PR's "Closes #N"
reference. Specialists 5b (governance) and 5c (plan-drift) consume the diff;
5e (cross-model adversarial) calls `cross_model_review.sh --pr <N>`, which
itself fetches the diff via `gh pr diff`.

For Mode-2 push-when-ready, the same review needs to run *before* the PR
exists. The minimal surface that needs to fork:

- Branch-local diff source (`git diff <base>...HEAD`) instead of `gh pr diff`
- Branch-local issue resolution (parse `feature/issue-<N>`) instead of
  "Closes" keyword
- A skip on the "Existing review comments" sub-step (no PR yet)
- A second entry point on `cross_model_review.sh` (`--branch [<ref>]`)

The rest of the pipeline — depth classification, specialists 5a/5b/5c/5d,
silence filter, report format, progress.md persistence — is reused
unchanged. This is the "one reviewer with two entry points" rescope from
PR #157.

## Approach

1. **Add `--branch [<base>]` to `/review-code`.** Flag toggles branch mode;
   optional base value resolved from `git symbolic-ref refs/remotes/origin/HEAD`
   with a fallback to `main`. Step 1 forks: PR mode keeps `gh pr view/diff`;
   branch mode uses `git diff <base>...HEAD` and `git diff --name-only
   <base>...HEAD`. Issue-number resolution forks too: PR mode parses
   "Closes #N" from the PR body; branch mode parses `feature/issue-<N>`
   from `git branch --show-current`, with `--issue <N>` as override.

2. **Specialists run unchanged.** Depth-classification signals (line count,
   file count, override-trigger files) operate on the local diff identically.
   5a (static), 5b (governance), 5c (plan-drift), 5d (Claude adversarial),
   5e (cross-model) need no per-mode logic *internally* — only their inputs
   come from a different source. 5b's "Existing review comments" sub-step
   is the one part that's skipped in branch mode (no PR exists).

3. **Add `--branch [<ref>]` to `cross_model_review.sh`.** Mutually
   exclusive with `--pr` (hard error if both). Branch mode swaps the prompt
   header (`Local branch <name>` instead of PR title/URL) and replaces
   `gh pr diff` with `git diff <base>...HEAD`. Issue-number resolution
   forks to parse `feature/issue-<N>` from the current branch; `--issue <N>`
   override unchanged. Below the diff capture, the prompt-write,
   agent-dispatch, findings-collection pipeline is unchanged.

4. **Step 8 progress-log differentiation.** Branch mode appends
   `## Local Review (Pre-Push)` instead of `## Local Review`, so the same
   issue can carry both a pre-push and a post-PR review entry on its
   timeline without one overwriting the other in summary skims.

5. **Generalize `review_depth_classification.md`.** Replace "from PR
   metadata (`gh pr view` output)" with "from diff metadata (PR or local
   branch)". Add one paragraph noting branch-mode applicability. No tier
   criteria change.

6. **Document the modes.** Add a "Modes" sub-section near the top of
   `SKILL.md` describing PR mode (default) and branch mode (`--branch`),
   and update the lifecycle diagram in the Overview. Add a one-line flag
   note to `.agent/AGENT_ONBOARDING.md`'s review-code reference.

7. **Self-test.** Once branch mode is built, run `/review-code --branch`
   against this very feature branch as the first smoke test; record the
   run in progress.md. Findings worth fixing get a follow-up commit on
   the same branch.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/review-code/SKILL.md` | Add "Modes" section; fork Step 1 into PR-mode and branch-mode sub-steps; mark Step 5b "Existing review comments" as PR-only; differentiate Step 8 step header for branch mode |
| `.agent/scripts/cross_model_review.sh` | Add `--branch [<ref>]` (mutually exclusive with `--pr`); branch-mode prompt header; branch-mode diff capture via `git diff <base>...HEAD`; branch-mode issue resolution from `feature/issue-<N>` |
| `.agent/knowledge/review_depth_classification.md` | Generalize "PR metadata" wording; add branch-mode paragraph |
| `.agent/AGENT_ONBOARDING.md` | One-line note on the `--branch` flag |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Branch mode is opt-in via flag; report format identical to PR mode; same silence filter |
| Capture decisions, not just implementations | This plan plus the rescoping comment on #3 capture the "two entry points, one reviewer" choice |
| A change includes its consequences | `review-code` ↔ `review_depth_classification.md` ↔ `cross_model_review.sh` are all updated in the same PR |
| Only what's needed | Reuses every specialist; flag-based dispatch instead of a duplicate skill |
| Workspace improvements cascade to projects | Branch mode works for both workspace and project worktrees from day one (acceptance criterion) |
| Primary framework first, portability where free | Skill body lives in `.claude/skills/`; `cross_model_review.sh` is portable shell |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0002 — Worktree isolation | Yes | Work happens in `worktrees/workspace/issue-workspace-3/`; branch mode itself respects worktree boundaries via the existing `_resolve_work_plans_dir.sh` |
| 0003 — Project-agnostic workspace | Yes | Branch mode must work on both workspace and project repos (acceptance criterion); both pass a base-ref defaulting to `main` |
| 0010 — git-bug optional | Partial | Branch mode reads local files first; `gh` only enters via the cross-model review when adversarial dispatch needs it. Graceful degradation preserved |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `review-code` skill | `review_depth_classification.md`; `cross_model_review.sh` | Yes (steps 3, 5) |
| `review_depth_classification.md` | `review-code` skill | Yes (steps 1, 5 stay in sync) |
| Workflow skill list | Skill list in non-Claude adapters | Partial — review-code already listed; only flag note added (step 6) |

## Open Questions

These are the architectural decisions worth your eyes before implement begins.
Numbered so you can answer "1=A, 2=B, ..." or override individually.

1. **Default base ref** — recommend dynamic resolution via
   `git symbolic-ref refs/remotes/origin/HEAD`, fall back to `main`.
   Both workspace and project default to `main` today, so this is mostly
   future-proofing. Alternative: hardcode `main`. (Recommend dynamic.)

2. **Static analysis in branch mode** — the issue body says "static analysis
   optional — pre-commit already runs". Two reasonable defaults:
   - **(a) On**: matches Standard tier exactly; silence filter drops
     linter-clean files; safety net for `--no-verify` bypasses.
   - **(b) Off, with `--with-static` opt-in**: branch mode is faster;
     trusts pre-commit as the gate.
   Recommend (a) — the speed delta is small and `--no-verify` does happen.

3. **Issue-number resolution fallback** — when branch isn't
   `feature/issue-<N>` and `--issue` isn't passed:
   - **(a) Hard error** with remediation message ("pass --issue or rename
     branch"). Strict but avoids silent artifact misrouting (the #149
     failure mode).
   - **(b) Soft skip**: run review without progress-log persistence.
   Recommend (a).

4. **Mutual exclusion of `--pr` and `--branch`** — recommend hard error if
   both provided. Allowing both could mean "review the local branch in the
   context of the existing PR" but doubles the test surface for unclear
   benefit.

5. **Self-test scope** — once branch mode is built, running it on this
   feature branch is the obvious smoke test. Two options:
   - **(a) Same PR**: include any minor findings in this PR. Bigger
     findings → follow-up issue.
   - **(b) Separate run** after merge, treat as initial dogfood.
   Recommend (a) — fast feedback loop.

## Estimated Scope

Single PR, ~250 LOC across the four files. Most volume in
`cross_model_review.sh` (arg parsing + diff path) and `SKILL.md` (mode
sub-sections). No new tests — there is no existing test harness for
`cross_model_review.sh`, and a parity-only addition would be out of scope
for #3.

## Implementation Notes

_(populated during implement phase per skill convention)_
