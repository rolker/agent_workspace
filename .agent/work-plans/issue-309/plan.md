# Plan: retain review findings across bookkeeping commits

## Issue

https://github.com/rolker/agent_workspace/issues/309

## Context

`review_progress.sh sources` currently compares seven-character SHAs and drops
open findings after the loop commits its own timeline. The merge gate already
recognizes ancestor reviews when the tree diff only changes bookkeeping files.

## Approach

1. Add real Git fixtures to `test_triage_reviews_integration.sh`, the existing
   sources suite, and reproduce the checkpoint regression before changing code.
2. Extract `_only_bookkeeping_between` into `_bookkeeping.sh`. Preserve the merge
   gate and CI callers' policies. Share the review policy (this issue's entire
   work-plan directory, `ROADMAP.md`, `docs/ROADMAP.md`) between gate and sources.
   Use endpoint tree equivalence, as the existing gate does, not a new per-commit
   policy. Another issue's work-plan directory is not exempt.
3. Keep the current exact-short-SHA compatibility path. For other SHAs, resolve
   commits in the current target worktree, require ancestry and the shared diff
   rule. Never infer the Git repo from the workspace script location. Derive the
   issue from the canonical progress path; noncanonical paths get exact matching
   only. Missing repositories/objects fall back to exact matching without fetch.
4. Retain each finding's original `sha`, add `covers_head` and a coverage reason
   (`exact` or `bookkeeping`). Preserve checked/false-positive exclusion and
   current-head GitHub matching. Cache the result for each distinct review SHA.
5. Update the triage skill's sources contract, including original-review provenance.
   This consequential documentation edit was included in the user-approved fix
   workflow. Do not alter framework eligibility or instruction policy in this PR.
6. Record Codex workflow observations in `codex-workflow-notes.md` beside the plan,
   separating exercised capabilities from untested proposals.

## Files to Change

| File | Change |
| --- | --- |
| `.agent/scripts/_bookkeeping.sh` | Shared diff and review policy helpers |
| `.agent/scripts/merge_pr.sh` | Source helpers; preserve gate/CI behavior |
| `.agent/scripts/review_progress.sh` | Coverage-aware local sources |
| `.agent/scripts/tests/test_triage_reviews_integration.sh` | Real-history regression and boundaries |
| `.agent/scripts/tests/test_merge_pr_gate.sh`, `test_merge_pr.sh` | Include shared helper in merge fixtures |
| `.claude/skills/triage-reviews/SKILL.md` | Document coverage and provenance |
| `.agent/work-plans/issue-309/` | Plan, timeline, Codex observations |

## Validation

Test progress-only, work-plan, both roadmap paths, mixed code/docs, code-only,
another issue, divergent identical trees, missing objects, no repository, exact
matching, checked/false-positive exclusion, cross-source candidates, and running
from a separate target repository. Use fixtures under the suite's private TMPDIR.
Run triage integration and merge gate suites, Bash syntax/ShellCheck, required
pre-commit hooks and the script suite. Review the branch independently, address
findings, publish the PR with `Closes #309`, then integrate external reviews.

## Principles Self-Check

| Principle | Consideration |
| --- | --- |
| Only what's needed | Extract the existing rule; no new orchestrator or CI policy |
| A change includes its consequences | Consumer documentation and gate regression coverage |
| Test what breaks | Real histories reproduce silent loss and reject stale reviews |
| Capture decisions | Record path scope and Codex observations with evidence |

## ADR Compliance

| ADR | How addressed |
| --- | --- |
| 0002 | Isolated issue-309 workspace worktree |
| 0011 | Generic Git logic; no project-shape branches |
| 0013 | Existing entry types and original SHA correlation remain intact |
| 0014 | Manual phase workflow; no claim to running the Claude-only orchestrator |

## Consequences

The public sources contract changes additively; triage documentation moves with it.
The generic merge helper's existing diagnostic and explicit allowed-path callers
remain supported. No Make target, new skill, entry type, or CI rule is introduced.
AGENTS.md instruction edits and broader Codex workflow changes are outside scope.

## Open Questions

None blocking. Match the current merge gate's issue-directory allowance, which is
broader than the original issue's progress-only example.

## Estimated Scope

One fix PR, plus an evidence-based Codex assessment kept with its work plan.
