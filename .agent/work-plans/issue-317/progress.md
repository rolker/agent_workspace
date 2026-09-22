---
issue: 317
---

# Issue #317 — #265 PR 3: minimal session layer — user-tier hook + install, root-resolved skills, cwd-derived type/project (gz4d acceptance)

## Issue Review
**Status**: complete
**When**: 2026-09-22 12:19 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #317

### Scope Assessment

**Well-scoped?** Mostly yes — the six enumerated scope items map cleanly onto
the #265 plan §2/§3 and the 2026-09-18 #295 fold. One gap: the issue's
**Acceptance** section requires the full `/run-issue` loop (review-issue →
plan-task → review-plan → implement → review-code → publish) through the
merge checkpoint, which is more than the plan's own PR-sequence note assigns
to PR 3 ("Acceptance test steps 1–3"). Steps 4–5 (`/plan-task`,
`/review-code --branch`, `gh_create_pr.sh` targeting, stopping short of an
actual merge) were originally scoped to run with PR 4. Nothing in those
steps actually depends on PR 4's deferred work (hosting retirement,
`register_project.sh`, p11 migration) — `gz4d` is already registered — so
this is achievable, but it's a silent expansion of PR 3's tested surface
that should be reconciled (update the plan's PR-sequence table, or say
explicitly in the issue that this PR now covers part of steps 4–5).

**Right repo?** Yes — workspace infrastructure (`agent_workspace`).

**Dependencies**: #300 (merge_pr.sh CI-check counting) and #314 (run-issue
wall-clock fixes) are open and unrelated to this PR's mechanics — correctly
not blockers. #292 (sub-PR merge cleanup removes the parent's worktree) is
inert here: no worktree currently exists for parent #265, confirmed via
`worktree_list.sh`. PR 1 (registry schema) and PR 2 (`#273`, worktrees under
each root) are already merged, so PR 3 builds on a landed foundation.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| A change includes its consequences | Action needed | The plan's curated-skill-subset table (§2) classifies only 20 of the workspace's 22 skills. `run-issue` and `address-findings` aren't in the table at all, and `review-issue` is classified `workspace`-only. This issue's acceptance test needs `/run-issue` (which dispatches `review-issue` as its first phase) to run from the `gz4d` project session — that requires `session_scope: both` (or `project`) plus curated-symlink coverage for at least `run-issue` and `review-issue`, and neither is called out in the issue's scope list. |
| Capture decisions, not just implementations | Action needed | The plan's ADR Compliance table calls for a new ADR ("session roots and the user tier", status Provisional) recording decisions 2–6, the user-tier "inert outside registered roots" rule, and the registry-only discovery order that supersedes part of ADR-0011 — all surface introduced by this PR (hook, install/check, guard). The issue's scope items don't mention drafting or updating this ADR. |
| Only what's needed / Improve incrementally | OK | The scope split matches the 2026-09-18 #295-fold decision (pinned workspace registry entry in scope; `--type` special-case collapse deferred to PR 4) and today's minimality direction. |
| Workspace vs. project separation | OK | User-tier rule stays "inert outside registered roots"; tool-mapping and log-tool-use hooks get the same registry guard (plan §2). |
| Enforcement over documentation | OK | `registry_require_root` guard + `user_tier_install.sh --check` wired into `make validate`, plus the heading-drift test for the `AGENTS.md` renderer — enforcement-based per the plan. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0001 (Adopt ADRs) | Yes | New ADR not yet drafted — see Action-needed row above. |
| 0006 (shared AGENTS.md, thin adapters) | Yes | The SessionStart hook renders `AGENTS.md` sections by heading list rather than forking content, matching scope item 2; ship the heading-drift test (`tests/test_session_start_layer.sh`) with it. |
| 0011 (adapter contract) | Yes, deferred correctly | Dropping the `project/` fallback (registry-only discovery) is PR 4 work per the plan; no conflict in PR 3's scope. |
| 0014 (in-process phase handoff) | Yes | `/run-issue`'s dispatch path is exercised by the acceptance test from a project-rooted session — ties back to the missing skill-scope classification for `run-issue`/`review-issue`/`address-findings` above. |

### Consequences

- Curated skill subset table needs `session_scope` entries for `run-issue`
  and `address-findings` (currently absent), and `review-issue` needs
  reclassifying from `workspace`-only, before the acceptance test's
  `/run-issue` step can execute from `~/src/gz4d`.
- The new ADR ("session roots and the user tier", Provisional) should be
  authored alongside the hook/install/guard work landing in this PR, per the
  plan's ADR Compliance table.
- The plan's PR-sequence note ("PR 3: Acceptance test steps 1–3") should be
  updated to reflect that PR 3 now exercises parts of steps 4–5 via
  `/run-issue`, per today's owner direction — otherwise the plan and what's
  actually tested drift apart.
- Minor/deferrable: `.agent/WORKTREE_GUIDE.md` / `README.md` /
  `ARCHITECTURE.md` user-tier wording (plan's Files-to-Change table) isn't
  in the issue's scope — fine to leave for PR 4 given the minimality
  direction, flagging only so it isn't forgotten.

### Recommendations

- Add `session_scope: both` for `run-issue` and `review-issue` in this PR
  (and decide `address-findings`'s scope), and confirm the
  `make generate-user-tier-skills` symlink step covers them — otherwise the
  acceptance test as written in the issue cannot run.
- Draft the new ADR ("session roots and the user tier", status Provisional)
  as part of this PR, since the hook/install/guard surface it must cover
  lands here.
- Note in the PR description (or update the plan) that PR 3's acceptance
  coverage now includes parts of the plan's steps 4–5, so the plan's
  PR-sequence table doesn't silently drift from what's actually tested.

### Actions
- [ ] The plan's curated-skill-subset table (§2) classifies only 20 of the workspace's 22 skills. `run-issue` and `address-findings` aren't in the table at all, and `review-issue` is classified `workspace`-only. This issue's acceptance test needs `/run-issue` (which dispatches `review-issue` as its first phase) to run from the `gz4d` project session — that requires `session_scope: both` (or `project`) plus curated-symlink coverage for at least `run-issue` and `review-issue`, and neither is called out in the issue's scope list.
- [ ] The plan's ADR Compliance table calls for a new ADR ("session roots and the user tier", status Provisional) recording decisions 2–6, the user-tier "inert outside registered roots" rule, and the registry-only discovery order that supersedes part of ADR-0011 — all surface introduced by this PR (hook, install/check, guard). The issue's scope items don't mention drafting or updating this ADR.
- [ ] Add `session_scope: both` for `run-issue` and `review-issue` in this PR (and decide `address-findings`'s scope), and confirm the `make generate-user-tier-skills` symlink step covers them — otherwise the acceptance test as written in the issue cannot run.
- [ ] Draft the new ADR ("session roots and the user tier", status Provisional) as part of this PR, since the hook/install/guard surface it must cover lands here.
- [ ] Note in the PR description (or update the plan) that PR 3's acceptance coverage now includes parts of the plan's steps 4–5, so the plan's PR-sequence table doesn't silently drift from what's actually tested.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 12:23 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed to plan-task with the issue-review actions folded in: run-issue, review-issue and address-findings classified for project sessions (session_scope both) and covered by the curated-skill symlink step; the provisional ADR "session roots and the user tier" drafted in this PR; the acceptance scope (full /run-issue loop from ~/src/gz4d through the merge checkpoint) recorded against the parent plan's PR-sequence table.
