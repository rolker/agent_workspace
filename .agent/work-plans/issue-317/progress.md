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

## Plan Authored
**Status**: complete
**When**: 2026-09-22 13:05 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-317/plan.md` at `beea1cb`

Minimal PR-3 user-tier session layer: registry-gated SessionStart hook rendering both layers, registry_require_root guard on promoted scripts, session_scope frontmatter (with run-issue/review-issue/address-findings folded in as "both"), cwd-derived --type/--project, and the new provisional ADR-0015 "session roots and the user tier" drafted in this PR. Acceptance test is the full /run-issue loop from ~/src/gz4d through the merge checkpoint, per the owner's issue-review checkpoint. Notes the branch is 13 commits behind main with two in-flight PRs (#319, #316/#318) touching dispatch_phase.sh/run-issue — merge required before implementation and again before final review.

## Plan Review
**Status**: complete
**When**: 2026-09-22 12:33 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #317 — #265 PR 3: minimal session layer — user-tier hook + install, root-resolved skills, cwd-derived type/project (gz4d acceptance)
**Plan**: `.agent/work-plans/issue-317/plan.md` at `beea1cb`
**Branch**: `feature/issue-317`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | Defensible overall, but three blocks can move to PR 4 without touching the gz4d acceptance (register-project stub, promoting the two hooks, part of the script manifest), and step 2 is already implemented on main |
| Issue alignment | Good | Covers all six issue scope items plus the three issue-review actions the owner's checkpoint folded in (session_scope for run-issue/review-issue/address-findings, the provisional ADR, the parent-plan reconciliation) |
| File targeting | Needs work | Branch-currency section misattributes the in-flight work; spike 7's "11 skills" list is stale (15 of 22 today); `registry_require_root` already exists |
| Consequences | Needs work | `test_skill_paths.sh` as specified fails on day one against the tracked `settings.json`; `make validate` gains a check that fails on any machine without the user tier |
| Principle alignment | Good | Enforcement-over-documentation is real here (guard + manifest + behaviour test + heading-drift test); "only what's needed" is where the trims below apply |
| ADR compliance | Concern | ADR-0015 is already taken by an open PR; the ADR-0011 addendum shape contradicts the parent plan and ADR-0008's test |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Approach — high]** `dispatch_phase.sh` cannot resolve a project worktree
   on this machine. `resolve_worktree()` only builds a project base when
   **exactly one** project is registered (`.agent/scripts/dispatch_phase.sh`
   lines 98–121; the header comment says "No `--project` disambiguation flag
   here"). The live registry has three entries (`gz4d`, `p11-jazzy`,
   `p11-rolling`), so `--type project` falls through to the legacy
   `project/` base and the acceptance test's
   `/run-issue <N> --type project` fails at the first dispatch. Step 8 is
   worded as *defaulting* `--project`; it must **add** the flag and thread it
   through `resolve_worktree` (and the usage/header text). This is the one
   finding that blocks acceptance outright.

2. **[Approach — high]** "Default `--type`/`--project` from the hook's
   `WORKTREE_TYPE=`/`PROJECT=` session lines" is not a mechanism scripts
   have. SessionStart stdout is context text for the model, not environment;
   scripts must derive from `$PWD` via `registry_resolve_from_dir` (which
   already does longest-prefix ancestor matching). The same gap hits
   `${AGENT_WORKSPACE_ROOT:-.}` in step 9: nothing sets that variable in the
   Bash tool's shell (a fresh shell per call), so in a project session the
   `:-.` fallback silently resolves against the project cwd and the script is
   simply not found — and the workspace session masks it, because `.` is
   correct there. Decide the idiom before rewriting skill files: either the
   hook prints the absolute root and the skills instruct the agent to
   substitute it literally, or every skill command chain begins by exporting
   it. As written, the 11 (really 15 — finding 7) rewrites are a no-op in the
   session they exist for.

3. **[ADR compliance — high]** ADR-0015 is already claimed:
   `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md`
   on open PR #318 (issue #206, branch `feature/issue-206`). Use 0016, and
   re-check the highest number at the pre-review merge.

4. **[ADR compliance — medium]** The ADR-0011 addendum shape contradicts the
   parent plan and ADR-0008's own test. The parent plan (`issue-265/plan.md`,
   ADR Compliance row for ADR-0011) says the discovery-order change is
   *substantive* by ADR-0008's test and is therefore recorded in the new ADR
   (superseding that part), **not** as an addendum. ADR-0008 permits only
   navigational edits (Status note, References entry). Also, this PR does not
   change the discovery order at all — PR 4 removes the `project/` fallback —
   so an addendum here would document a change that has not happened. Keep
   any ADR-0011 edit to a pointer; put the supersession in the new ADR.

5. **[File targeting — medium]** The branch-currency section has the in-flight
   work inverted. PR #319 is issue #300 and touches `merge_pr.sh`,
   `run-issue/SKILL.md`, `review-code/SKILL.md`, `AGENTS.md`, `Makefile` —
   **not** `dispatch_phase.sh`. The branch that touches `dispatch_phase.sh`
   (plus `test_dispatch_phase.sh` and ADR-0014) is `feature/issue-314`, which
   is **local and unpushed with no PR**, so step 1's `git merge origin/main`
   will not surface it — the stated mitigation does not cover the actual
   conflict. The real overlaps to plan around are: `run-issue/SKILL.md` and
   `AGENTS.md` (#319 and #318) against step 9's 22-file frontmatter sweep and
   step 3's heading list, and `Makefile` (#319) against step 10.

6. **[Consequences — medium]** `test_skill_paths.sh` as specified fails the
   moment it is written: it is to fail on any relative `.agent/scripts` /
   `.claude/hooks` reference "in `SKILL.md` **or `settings.json`**", and the
   tracked `.claude/settings.json` carries two relative hook commands today
   (spike 7) which this PR deliberately does not edit. It runs in CI, via
   `make lint` → the `validate-script-tests` pre-commit hook. Either allowlist
   those two existing entries explicitly or scope the test to `SKILL.md` for
   this PR — otherwise the plan's own Ask-First promise gets forced open by a
   red test.

7. **[File targeting — medium]** Spike 7's "11 of 20 skills" is stale (measured
   2026-09-16). Today **15 of 22** `SKILL.md` files carry relative
   `.agent/scripts` / `.claude/hooks` references, including exactly the ones
   the acceptance loop needs from the gz4d session: `run-issue` (17
   references), `address-findings` (4), `review-plan` (4), `review-issue` (1).
   Re-grep at implementation rather than working from the list of 11.

8. **[Scope — medium]** Step 2 is already done. `registry_require_root` exists
   at `.agent/scripts/_project_registry.sh:479` (landed with PR 1), with the
   workspace-checkout special case and the one-line refusal message. Its
   signature is `registry_require_root <ws_root> [dir]`, not `[dir]` — every
   promoted script must therefore resolve the workspace root itself
   (`BASH_SOURCE`, as several already do) before calling it. Step 2 becomes
   "call it", not "add it".

9. **[Scope — medium]** What can move to PR 4 without breaking the gz4d
   acceptance:
   - **Step 6's register-project stub** and its install/uninstall/`--check`
     paths: `gz4d` is already registered, and `register_project.sh` is PR 4.
   - **Step 5 entirely** — but as promote-or-defer, not guard-or-not. Nothing
     in the acceptance needs `block-bash-tool-mapping.sh` / `log-tool-use.sh`
     in a project session; leave them project-scoped and both the guards and
     their tests disappear. If they *are* promoted, the guard is mandatory
     (spike 3b) and must ship with them.
   - **Step 7's manifest**, trimmed to what the loop actually invokes from
     `gz4d` (`worktree_create/enter/remove/list`, `gh_create_pr`,
     `gh_create_issue`, `fetch_pr_reviews`, `cross_model_review`, `merge_pr`,
     `adapter`, `build`, `test`). `dashboard.sh` is not in the loop; each
     manifest row costs a guard call plus a test row.
   - **Step 9's frontmatter sweep**: only the 13 `project`/`both` skills need
     the field; `workspace` is the documented default for the other 9.
   Keep step 12 (parent-plan PR-sequence row) — it is the owner's checkpoint
   decision and it is one table row.

10. **[Consequences — medium]** Wiring `user_tier_install.sh --check` into
    `make validate` makes that command fail on any machine or clone where the
    user tier is not installed (the ROS machine, a fresh checkout, a
    contributor). `--check` should exit 0 with a "not installed" note unless
    explicitly asked to require it. Related: the new suites run in CI through
    `make lint` → `run_script_tests.sh`, so `test_user_tier_guard.sh` and the
    `--check` drift cases must redirect `HOME`, never read or write the real
    `~/.claude`, and need no network or `gh` auth — which also means the guard
    call has to precede any `gh`/`git` call for the "refuses and touches
    nothing" assertion to hold.

11. **[Approach — low]** Rendering `AGENTS.md` by heading list is the right
    call (ADR-0006, render-not-fork), but the drift test as specified only
    asserts the headings exist. Add two assertions: each rendered section is
    non-empty, and extraction stops at the next same-level heading. Two open
    PRs already modify `AGENTS.md` and #259 will rewrite it, so this test is
    the only thing between a rename and a silently empty workspace layer.

12. **[Approach — low]** The pinned workspace registry entry (step 8) has no
    specified shape, and its blast radius is wide: a registry line whose path
    is the workspace root makes every workspace cwd resolve as a project
    through `registry_resolve_from_dir`, which feeds `adapter --from`
    discovery, `dashboard.sh` classification and `registry_worktree_dir`
    (default `<root>/worktrees/`, while workspace worktrees live at
    `<ws>/worktrees/workspace/`). Specify the entry's type, its `worktrees=`
    override and which consumers skip it — or drop it from PR 3 and branch on
    "cwd under the workspace checkout", which `registry_require_root` already
    does.

13. **[Testing — low]** There is a hermetic proxy for two of step 14's four
    cases, and step 13 already names it: drive
    `session_start_project_layer.sh` with a synthetic registry and a
    `{"cwd": …}` payload — exactly spike 2's method — for both the silent
    branch ("unrelated repo sees nothing") and the inject branch ("both layers
    printed under a registered root"). Say so in step 14, so the live run
    carries only what a test cannot: that Claude Code splices the stdout into
    context, that the symlinked skills are listed by name, and that the full
    loop runs. Allow-rule non-firing stays non-hermetic; the closest proxy is
    asserting every generated settings entry is absolute-path and
    marker-tagged.

**Ask-First check (clean)**: the Files-to-Change list contains neither
`AGENTS.md` nor the tracked `.claude/settings.json`, and the Open Questions
section states the reasoning correctly. The only way an Ask-First edit gets
forced is finding 6.

### Summary

The design is right and the scope discipline is mostly honest, but the plan
cannot be implemented as written: `dispatch_phase.sh` has no `--project`
disambiguation and will not find the `gz4d` worktree with three projects
registered (finding 1), and the `AGENT_WORKSPACE_ROOT` / session-line
mechanism the plan leans on does not reach scripts or the Bash tool's shell
(finding 2). Both sit directly under the acceptance test. Fix those two, take
the ADR number and shape corrections (3, 4), correct the in-flight-work
attribution (5), and the remaining items are trims and test hardening.

### Recommended Actions

- [ ] Step 8: add a real `--project` flag to `dispatch_phase.sh` and thread it through `resolve_worktree`; derive `--type`/`--project` from `$PWD` via `registry_resolve_from_dir`, not from hook output
- [ ] Step 9: settle how skills reach the workspace root in a project session before rewriting any file — `${AGENT_WORKSPACE_ROOT:-.}` silently resolves to the project cwd there
- [ ] Step 11: number the new ADR 0016 (0015 is claimed by open PR #318) and re-check at the pre-review merge
- [ ] Step 11: keep the ADR-0011 edit navigational only (ADR-0008); record the discovery-order supersession in the new ADR, as the parent plan requires
- [ ] Rewrite the branch-currency paragraph: #319 is issue #300 (merge_pr.sh, run-issue/SKILL.md, AGENTS.md, Makefile); `dispatch_phase.sh` is touched by the unpushed local `feature/issue-314`, which merging main will not reveal
- [ ] Step 9: scope `test_skill_paths.sh` to `SKILL.md`, or allowlist the two existing relative hook commands in the tracked `settings.json`
- [ ] Step 9: re-grep the skills (15 of 22 today, not 11) instead of reusing spike 7's list
- [ ] Step 2: call the existing `registry_require_root` (`_project_registry.sh:479`, signature `<ws_root> [dir]`) rather than adding it
- [ ] Trim to acceptance: drop the register-project stub and the two-hook promotion to PR 4; trim the script manifest to what the loop invokes; put `session_scope` only on the 13 project/both skills
- [ ] Make `user_tier_install.sh --check` a no-op when the user tier is not installed; redirect `HOME` in every new test suite (they run in CI via `make lint`)
- [ ] Step 4: assert rendered sections are non-empty and bounded at the next same-level heading, not just that headings exist
- [ ] Step 8: specify the pinned workspace registry entry's shape and its consumers, or defer it
- [ ] Step 14: name the hermetic hook-driver test as the proxy for the silent/inject cases; keep the live run for context splicing, skill listing and the full loop

## Checkpoint
**Status**: complete
**When**: 2026-09-22 12:49 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise the plan with all thirteen plan-review findings: add and thread `--project` through dispatch_phase.sh's worktree resolution (three projects are registered); decide the workspace-root idiom for project sessions before rewriting skills (hook stdout is context, not environment; `${AGENT_WORKSPACE_ROOT:-.}` is never set in tool shells); derive type/project from $PWD via registry_resolve_from_dir; ADR number 0016 (0015 is claimed by PR #318); the ADR-0011 change is a pointer only, supersession lives in the new ADR; correct the in-flight overlap analysis (#319 merged; the dispatch_phase.sh overlap is the local #314 branch); scope the skill-paths test to SKILL.md or allowlist the two tracked settings.json hook commands; re-grep the 15-of-22 cwd-relative skills; step 2 becomes "call registry_require_root <ws_root> [dir]"; trims: drop the register-project stub, drop the two hook guards unless the hooks are promoted, shrink the promoted-script manifest to what the loop invokes from gz4d, frontmatter only on the 13 project/both skills; `user_tier_install.sh --check` exits 0 with a "not installed" note under `make validate` unless required explicitly, and the new suites redirect HOME and need no network; drift test asserts non-empty sections and stop-at-next-heading; specify the pinned workspace entry's shape and consumers or drop it in favour of "cwd under the workspace checkout"; hermetic proxy for the silent/inject hook cases via spike 2's method.

## Plan Authored
**Status**: complete
**When**: 2026-09-22 13:35 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Dispatch**: resumed (planner, resume 1 of 3)
**Plan**: `.agent/work-plans/issue-317/plan.md` at `45f3a16`

Revision 2, addressing the plan review at 421d8ac (needs-work, 13 findings) per the owner's revise checkpoint, plus two owner overrides issued after that checkpoint. Fixes both acceptance-blocking issues: dispatch_phase.sh gets a real --project flag threaded through resolve_worktree (it previously only resolved a project base with exactly one registered project; this machine has three), and the workspace-root idiom for skills is now a file (~/.claude/agent-workspace-root) rather than hook-output environment, since SessionStart stdout is context text, not environment reaching the Bash tool's shell. Also: ADR number corrected to 0016 (0015 taken by merged PR #318), ADR-0011 gets a pointer only, in-flight-work attribution corrected (#319 merged; the real dispatch_phase.sh overlap is the local unpushed feature/issue-314), and scope trimmed (register-project stub and dashboard.sh guard dropped; frontmatter only on the 13 project/both skills). Owner overrides (2026-09-22, after the revise checkpoint): tool-mapping/log-tool-use hook promotion stays in PR 3 with the registry guard, reversing the review's trim; the pinned workspace registry entry is deferred to PR 4 (to land with the --type special-case collapse) rather than dropped, revising the 2026-09-18 #295 fold's first half.

## Plan Review
**Status**: complete
**When**: 2026-09-22 13:01 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Dispatch**: resumed (plan reviewer, resume 1 of 3)
**Verdict**: ready

**Issue**: #317 — #265 PR 3: minimal session layer — user-tier hook + install, root-resolved skills, cwd-derived type/project (gz4d acceptance)
**Plan**: `.agent/work-plans/issue-317/plan.md` at `45f3a16`
**Branch**: `feature/issue-317`

Round 2. Reviews revision 2 against the round-1 entry at `421d8ac`
(needs-work, 13 findings) and the owner's `revise` checkpoint plus the two
later overrides (hooks stay in PR 3 with the guard; the pinned workspace
registry entry is deferred to PR 4). The overrides are not re-opened here.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Minimal for the gz4d acceptance with the owner's two keeps: register-project stub and `dashboard.sh`'s guard dropped, frontmatter on 13 skills, manifest trimmed to what the loop invokes |
| Issue alignment | Good | Both acceptance-blocking mechanisms fixed at the mechanism level; live step scoped to what only a live session proves |
| File targeting | Good | Files-to-Change matches the steps; `dispatch_phase.sh` and the two hooks are the only pre-existing files with behaviour change |
| Consequences | Good | Two new rows for the idiom change and the deferred entry; `#314` overlap carried as an explicit timing call |
| Principle alignment | Good | Guard + trimmed manifest + guard test now cover the hooks too; heading-drift test hardened |
| ADR compliance | Good | 0016 confirmed free on `main`; ADR-0011 pointer only, substance in the new ADR — matches ADR-0008's test and the parent plan |
| ROS conventions | N/A | Workspace plan |

### Round-1 findings — disposition

All thirteen resolved or decided: 1 → step 9 (`--project` added and threaded,
`$PWD` derivation, legacy fallback kept); 2 → step 6 (file idiom, hook
informational only); 3 → step 13 (ADR-0016; verified `0015` is on `main` from
the merged #318); 4 → step 13 (References pointer only); 5 → branch-currency
rewritten (see finding 2 below for one residual slip); 6 → step 11
(`test_skill_paths.sh` scoped to `SKILL.md`, tracked `settings.json`
untouched); 7 → step 11 (re-grep, 15-of-22 list carried); 8 → step 2 ("call
it", correct signature and line reference); 9 → trims taken except the two
owner overrides; 10 → step 7 (`--check` exits 0 when not installed,
`--require` opt-in) and step 15 (`HOME` redirected, no network/`gh`);
11 → step 4 (non-empty + bounded extraction); 12 → step 10 (deferred per
owner, with the PR-3 substitute stated); 13 → step 15 names the hermetic
hook driver, step 16 keeps only what it can't prove.

New-design checks: the step-6 snippet is concrete, works with a fresh shell
per tool call (it is a file read, not state), degrades to `.` in a workspace
session where cwd is the worktree — and I verified the exact snippet is
**not** blocked by `block-bash-tool-mapping.sh` (the `2>/dev/null` redirect
exempts it), which matters because this PR promotes that hook into project
sessions. Step 9's derivation uses `ROOT_DIR` (resolved from `BASH_SOURCE`
via `git worktree list`), so the registry file resolves correctly when the
script is invoked by absolute path from `gz4d`. Step 8's guard test covers
both hooks' stand-down hermetically. #318 and #319 are both merged (16:42 and
16:37 UTC today); `feature/issue-314` is still local and unpushed.

### Findings

1. **[Approach — medium]** The injected workspace layer will carry relative
   script paths into project sessions. The renderer keys on `AGENTS.md`
   sections including **Worktree Workflow** and **GitHub CLI Patterns**,
   whose code blocks read `.agent/scripts/worktree_create.sh …`,
   `source .agent/scripts/worktree_enter.sh …`,
   `.agent/scripts/gh_create_pr.sh …`. Rendered verbatim into a `gz4d`
   session those resolve against the project checkout and fail — the same
   class of problem step 6 fixes for skills, but `test_skill_paths.sh` is
   scoped to `SKILL.md` and does not see `AGENTS.md`. Cheap fix, decide it at
   implementation: have the renderer prefix the workspace layer with one line
   stating the step-6 idiom and that the snippets below are workspace-root
   relative, or have it rewrite bare `.agent/scripts/` occurrences to
   `"$WS_ROOT"/.agent/scripts/` on the way out. Not a blocker — the acceptance
   run would surface it — but it is exactly the kind of thing the run should
   not be spending its budget on.

2. **[File targeting — low]** One residual factual slip in the corrected
   branch-currency paragraph: it says `feature/issue-314` "claims the ADR
   number `0015` (freed by #318's merge, which used that number for its own
   ADR)". Both halves are wrong and mutually contradictory — #318's merge
   *took* `0015` (it is on `main` now), and `feature/issue-314` adds no new
   ADR at all; it appends 12 lines to the existing
   `0014-in-process-phase-handoff.md`. The `0016` conclusion is unaffected;
   delete the parenthetical so the plan doesn't carry a false claim into
   implementation.

3. **[Consequences — low]** Step 10 makes `--type` optional on the worktree
   scripts (derived from `$PWD`), but `AGENTS.md`'s Worktree Workflow section
   states "`--type` is **required** on all worktree scripts" — and that is one
   of the sections the hook renders into every project session. The wording
   fix is correctly deferred to PR 4 (Ask-First), so this is doc lag by
   design; record it as a known lag in the PR description and in PR 4's list,
   rather than leaving it silent. Behaviour stays additive (explicit flags
   still win), so nothing breaks.

### Summary

Revision 2 is implementable as written. Both acceptance blockers are fixed at
the mechanism level, the workspace-root idiom is concrete and survives the
fresh-shell constraint, the ADR number and shape are right, and the scope is
minimal for the gz4d acceptance given the owner's two keeps. The three
findings above are implementation-time refinements, not gates.

### Recommended Actions

- [ ] Step 3/4: decide how the rendered `AGENTS.md` sections present their relative script paths to a project session (preamble line or rewrite on render)
- [ ] Branch-currency paragraph: drop the false "#314 claims ADR 0015" parenthetical (#314 only amends ADR-0014; `0015` is on `main` from the merged #318)
- [ ] Record the `--type`-required wording lag in the PR description and PR 4's list

## Checkpoint
**Status**: complete
**When**: 2026-09-22 13:03 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed to implementation of plan revision 2 (45f3a16) with the three round-2 notes folded in: the hook's rendered workspace layer carries the workspace-root idiom (prefix line, or rewrite bare `.agent/scripts/` occurrences to the root-qualified form) so the AGENTS.md snippets work from a project checkout; delete the false ADR-number parenthetical in the branch-currency paragraph; record the AGENTS.md "`--type` is required" doc lag in the PR description and PR 4's list. Per the owner's orchestrator rule the implement pass is dispatched to a background agent.

## Implementation

**Status**: complete
**When**: 2026-09-22 13:45 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Plan**: `.agent/work-plans/issue-317/plan.md` at `08424ef`
**Branch**: feature/issue-317 at 9765ecb

Plan revision 2's steps 1–15 are done. Step 16 (the live gz4d acceptance
run) is the host's, not this pass's.

### Per plan step

- **1. Merge `main`** — `876bb69` at the start, then **again at the end**
  (`9765ecb`): `feature/issue-314` landed as PR #322 *during* this pass, so
  the plan's open question resolved itself and its `dispatch_phase.sh`
  rewrite is taken rather than re-derived. `dispatch_phase.sh` auto-merged
  — #322's `implement` case, `**Addressed**`-keyed `skill_for()` and
  `--check-exit` correlation check live in different functions from
  #317's `derive_project_name()`, which is what keeping the new work in its
  own functions was for. Two additive conflicts resolved (both test
  sections kept; #322's prose kept with #317's `$WS_ROOT` prefixes).
- **2. Call `registry_require_root`** — `01e8e88`. Existing function, now
  called; no new guard written.
- **3. SessionStart hook** — `8332695`, `.claude/hooks/session_start_project_layer.sh`.
  Silent outside; header + workspace-root idiom + `AGENTS.md`-rendered
  workspace layer + project layer under a registered root. No `KEY=value`
  lines, asserted by test.
- **4. Heading-drift test** — `8332695`. The pinned heading list is read
  back out of the hook, so adding a heading adds a case; per heading:
  verbatim existence, non-empty body, extraction bounded at the next `##`,
  plus a negative control proving the emptiness check can fail.
- **5. Both hooks promoted with the guard** — `01e8e88`. They guard on the
  payload's own `.cwd` and resolve `BASH_SOURCE` through symlinks (the user
  tier installs them as symlinks).
- **6. Workspace-root idiom** — `1a9fb0b` (the file) and `3e7147a` (the
  skills). Option (b) as decided: a file, not hook-spliced environment.
- **7. `user_tier_install.sh`** — `1a9fb0b`. Idempotent; `--check`
  (+`--require`), `--uninstall`, `--list-skills`, `--sync-skills`. Writes
  only inside `$HOME/.claude`.
- **8. Manifest + guard test** — `01e8e88`, `.agent/user_tier_scripts.txt`
  and `test_user_tier_guard.sh`. **One scope change, see below.**
- **9. `dispatch_phase.sh --project` + `$PWD` derivation** — `a6d57f0`.
  Additive: with neither a name nor a resolvable cwd, behaviour is
  identical to before.
- **10. Worktree scripts + `/start-task`** — `3e7147a`. New
  `registry_derive_type_from_dir` makes `--type` optional on create / enter
  / remove. `/start-task`'s "Move to the workspace root" step is *replaced*,
  not rewritten: its `cd "$(git rev-parse --show-toplevel)"` would, from a
  project session, cd to the **project** root and discard the cwd the
  derivation depends on.
- **11. Skills** — `3e7147a`. 13 `session_scope` declarations; re-grepped at
  implementation time (not from the plan's count) and rewrote 61
  workspace-relative references across nine skills. `test_skill_paths.sh`
  scopes to `SKILL.md` only; the tracked `.claude/settings.json` is
  untouched.
- **12. `make generate-user-tier-skills`** — `1a9fb0b`, plus
  `user-tier-install` and `validate` running `--check` (no `--require`).
- **13. ADR-0016** — `7ced4f8`, status Provisional. `0016` reconfirmed free
  against `docs/decisions/` immediately before writing. ADR-0011 gets a
  References pointer only.
- **14. Parent-plan reconciliation** — `7d1609c`, its own commit.
- **15. Hermetic tests** — across the above plus `f99e2fe`. Every new suite
  redirects `HOME` to a sandbox, needs no network and no `gh` auth.
- **16. Live acceptance** — not run here; the host's.

### Owner's three plan-checkpoint notes

- **(1) Workspace-root idiom in the rendered layer** — took the *prefix*
  option, not the rewrite: the layer opens with a "Workspace root" section
  stating that the `.agent/scripts/...` paths below are workspace-root
  relative, where the root is recorded, and how to read it.
  `test_session_start_layer.sh` asserts the section is present **and
  precedes** the rules it qualifies.
- **(2) False ADR-0015 parenthetical** — deleted in `08424ef`, its own
  commit. (`0015` on `main` is the parallel-sync ADR; the claim that #318
  had taken it was wrong. Only "0015 is taken" was load-bearing.)
- **(3) `AGENTS.md` doc lag** — recorded, not fixed. Its "Worktree
  Workflow" section still says "`--type` is **required** on all worktree
  scripts (create, enter, remove)", which step 10 makes false. `AGENTS.md`
  is Ask-First and its wording is PR 4 scope, so it is on the plan's PR-4
  list (`08424ef`) and repeated here for the PR description.

### Test results

| Suite | Result |
|---|---|
| `run_script_tests.sh` (all 27 suites) | **pass**, 78s |
| `test_dispatch_phase.sh` | 99 passed (was 76; +12 `--project`, +11 from #322) |
| `test_user_tier_guard.sh` (new) | 43 passed |
| `test_session_start_layer.sh` (new) | 37 passed |
| `test_user_tier_install.sh` (new) | 33 passed |
| `test_skill_paths.sh` (new) | 36 passed |
| `test_project_registry.sh` | 214 passed (+6 derivation cases) |
| `test_block_bash_tool_mapping.sh` | 113 passed |
| `test_adapter.sh` / `test_ros2_colcon.sh` | 86 / 191 passed |
| `user_tier_install.sh --check` on this machine | exits 0, "not installed" |
| shellcheck (pre-commit) on every touched script | pass |

### Three things the reviewer should look at

- [ ] **`cross_model_review.sh` was de-promoted** (`f99e2fe`) — it is no
  longer in the user-tier manifest and has no guard. It **cannot** satisfy
  the user-tier rule: reviewing a repo that is neither the workspace nor
  registered is a documented feature of it (`--repo`, `--work-dir`,
  `--no-progress` exist for exactly that), so a cwd guard would refuse its
  own interface. Rather than carve an exception into the rule, the rule was
  applied as written. Cost: it gets no generated allow-rule, so invoking it
  from a project session goes through the normal permission prompt. The
  alternative — guarding it anyway and skipping the guard when an explicit
  target flag is passed — was written and then backed out as a rule-shaped
  hole. **This is a deviation from the plan's step-8 list and wants a
  yes/no.**
- [ ] **`--type is required` is now unreachable** on the worktree scripts.
  The guard passes only when the cwd is the workspace or a registered root,
  and the derivation succeeds in exactly those cases, so the error survives
  only as a defensive fallback.
  `test_worktree_enter_stderr.sh`'s case was rewritten to assert the
  derivation instead of the dead error.
- [ ] **Two silent-failure bugs were found by the new tests**, both in code
  written this pass: `sync_skills` deleted the first selected skill right
  after linking it (pipefail + `grep -q`'s early exit SIGPIPEing the
  producer, so the pipeline reported 141), and `--check`'s missing-rule
  comparison reported every rule present (`$have | index(.)` rebinds `.` to
  `$have` inside the pipe). Both are fixed and covered; flagging them
  because the same two shapes could plausibly exist elsewhere.

### Ask-First

None taken. `AGENTS.md` and the tracked `.claude/settings.json` are
unmodified — confirmed by `git diff main --stat` on both paths.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 13:55 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-317 at `5f07025`
**Base**: main
**Depth**: Standard (reason: 52 files / +3681 across enforcement + governance files; Deep's cross-model specialist scoped out for the time box — see note)
**Must-fix**: 4 | **Suggestions**: 12
**Round**: 1 | **Ship**: continue — round 1: 4 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) A malformed `~/.claude/settings.json` is silently replaced, losing every user key — verified live in a sandbox HOME (`model` and a user allow-rule gone, exit 0, no backup): `jq '.' || echo '{}'` treats unparseable as empty — `.agent/scripts/user_tier_install.sh:146`
- [x] (must-fix) A second workspace checkout (or a run from a worktree) overwrites `~/.claude/agent-workspace-root` unconditionally, repointing every skill's `$WS_ROOT`; the first checkout's `--check` then fails `installed()` and prints "not installed (optional)" exit 0, so the "another workspace checkout" drift note and `make validate` never fire — `.agent/scripts/user_tier_install.sh:368` and `:141`
- [x] (must-fix) The `$WS_ROOT` idiom lost the fallback the plan specified (`2>/dev/null || echo .`, plan.md:135): all 13 rewritten skills use a bare `cat`, so on any machine where the user tier is not installed — a state `--check` and ADR-0016 explicitly call supported and optional — `$WS_ROOT` is empty and every rewritten command becomes `/.agent/scripts/...`. Regression for workspace sessions, which worked from relative paths before — `.claude/skills/*/SKILL.md` (e.g. `review-code/SKILL.md:20`)
- [x] (must-fix) ADR-0016 has no row in the ADR Applicability table, which the file's own consequences map requires and every future review reads to decide which ADRs are triggered — `.agent/knowledge/principles_review_guide.md:41`
- [x] (suggestion) `review-code`'s static-analysis *file-location* table had `$WS_ROOT` substituted into it mechanically; that cell is a path pattern to match changed files against, not a command, and now matches nothing — `.claude/skills/review-code/SKILL.md:203`
- [x] (suggestion) The jq dependency check runs before mode dispatch, so `make validate` exits 3 on a jq-less machine — the exact case the script's own header says must stay green — `.agent/scripts/user_tier_install.sh:84`
- [x] (suggestion) Uninstall matches allow-rules against the *current* manifest, so rules from an earlier manifest generation stay in `~/.claude/settings.json` forever; `--check` only tests for missing rules, never extra ones — `.agent/scripts/user_tier_install.sh:243`
- [x] (suggestion) The two promoted hooks fail *open*: if `_UT_WS_ROOT` or `_project_registry.sh` cannot be resolved (deleted checkout, moved clone) the guard block is skipped and `log-tool-use.sh` logs an unrelated repo's commands — `.claude/hooks/log-tool-use.sh:40`, `.claude/hooks/block-bash-tool-mapping.sh:74`
- [x] (suggestion) `test_user_tier_guard.sh` never exercises the `guarded-by:` shims: both loops iterate `NONINERT`, which excludes them, so `build.sh` / `test.sh` and their `probe_args` cases are dead code — `.agent/scripts/tests/test_user_tier_guard.sh:109` and `:172`
- [x] (suggestion) The adapter's guard validates `$PWD` but `--from <dir>` is parsed afterwards, so `adapter --from /unrelated build` from the workspace passes and a legitimate `--from <workspace>` from elsewhere is refused — `.agent/scripts/adapter:104`
- [x] (suggestion) `derive_project_name` misses worktrees hosted under the workspace root via a `worktrees=` override; with several projects registered it falls back to the single-project path and reports "no project worktree found" — `.agent/scripts/dispatch_phase.sh:128`
- [x] (suggestion) The hook's "cwd is NOT the workspace checkout" paragraph is false for a project registered at the default `projects/<name>` path inside the workspace tree — `.claude/hooks/session_start_project_layer.sh:100`
- [x] (suggestion) The project's `.agent/CLAUDE.md` is `cat`ed verbatim with no size cap, on top of ~5.6 KB of rendered AGENTS.md, into every session — `.claude/hooks/session_start_project_layer.sh:176`
- [x] (suggestion) `write_settings` `mv`s over `~/.claude/settings.json`, replacing it if the user symlinks it into a dotfiles repo — `.agent/scripts/user_tier_install.sh:162`
- [x] (suggestion) Mode flags are last-one-wins with no validation: `--uninstall --check` silently runs check only, `--require` without `--check` is accepted and ignored — `.agent/scripts/user_tier_install.sh:66`
- [x] (suggestion) `for cmd in $(hook_commands)` word-splits and globs; a checkout path with a space or glob char makes `--check` report permanent spurious drift — `.agent/scripts/user_tier_install.sh:281`
- [x] (suggestion) `.agent/WORKTREE_GUIDE.md:9` and `:135` still say `--type` is required and that workspace-vs-project "is never ambiguous"; unlike AGENTS.md this file is not Ask-First, so the correction could land here

## Implementation

**Status**: complete
**When**: 2026-09-22 14:09 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-317 at 05fe7e4
**Addressed**: Local Review (Pre-Push) at `5f07025` (2026-09-22 13:55 -04:00)
**Dispatch**: resumed (implementer, resume 1 of 3)
**Commits**: 1c31060, f372295, 7054283, 9e770bd, 05fe7e4

All 17 findings actioned — 4 must-fix and 13 suggestions. None deferred.

### Actions

- [x] (must-fix) Unparseable `~/.claude/settings.json` silently replaced — `.agent/scripts/user_tier_install.sh:146` → `settings_unparseable()` is its own state; `require_parseable_settings()` refuses before any write naming the file and how to inspect it; `--check` reports it and exits 1 rather than calling it drift and advising the re-run that would have overwritten it; `backup_settings()` writes a timestamped copy before every rewrite regardless. Test feeds a truncated file and asserts it is byte-for-byte untouched by install, uninstall and check (`1c31060`)
- [x] (must-fix) Second checkout silently steals `~/.claude/agent-workspace-root` — `:368`/`:141` → `installed_elsewhere()` separates "installed for another checkout" from "not installed"; install refuses with both paths unless `--force`; `--check` reports it and exits 1 (also under `--require`); `--force` announces the takeover. Tested with a real second workspace copy (`1c31060`)
- [x] (must-fix) `$WS_ROOT` idiom lost the `2>/dev/null || echo .` fallback in all 13 skills → restored everywhere, and each skill's Workspace root section now states *why* it is required, so it does not read as decoration to be tidied away. The reviewer's extra catch is folded in: the rewrite was too narrow, so `.agent/templates/`, `.agent/knowledge/`, `.agent/project_types/`, `.agent/work-plans/` and `.claude/skills/` are now in scope too, which gives `audit-project`, `document-project` and `test-engineering` the section they previously did not need (`f372295`)
- [x] (must-fix) ADR-0016 missing from the ADR Applicability table — `.agent/knowledge/principles_review_guide.md:41` → row added with real trigger conditions and the rule in one line, fallback included (`7054283`)
- [x] (suggestion) `$WS_ROOT` substituted into `review-code`'s file-location *pattern* table — `review-code/SKILL.md:203` → reverted, with a line saying what the column is and a `<!-- skill-paths: patterns-not-commands -->` marker so the test skips those rows instead of a future round re-introducing the same "fix" (`f372295`)
- [x] (suggestion) jq check before mode dispatch made `make validate` exit 3 on a jq-less machine — `:84` → per-mode now; `--check` degrades to a note and exit 0 (`1c31060`)
- [x] (suggestion) Uninstall matched the current manifest only, orphaning earlier generations' rules — `:243` → install records the generation it wrote to `~/.claude/agent-workspace-rules.json`; uninstall removes the union of record and manifest, and only then deletes the record; `--check` reports rules the manifest no longer names (`05fe7e4`)
- [x] (suggestion) Both hooks failed **open** when the root or registry could not be resolved — `log-tool-use.sh:40`, `block-bash-tool-mapping.sh:74` → both now exit 0 without acting. The safe direction is the same for each: a hook that cannot prove it governs this cwd must not log it and must not block it (`9e770bd`)
- [x] (suggestion) `test_user_tier_guard.sh` never exercised the `guarded-by:` shims — `:109`/`:172` → own loop; `build.sh`/`test.sh` must refuse through their guarded target (`9e770bd`)
- [x] (suggestion) Adapter guard ran before `--from` was parsed — `adapter:104` → guard moved after parsing, onto the effective dir; a non-existent `--from` falls back to `$PWD` to match the discovery below it (`05fe7e4`)
- [x] (suggestion) Mode flags last-one-wins — `:66` → mutually exclusive; `--require` without `--check` rejected (`1c31060`)
- [x] (suggestion) `for cmd in $(hook_commands)` word-split — `:281` → while-read (`1c31060`)
- [x] (suggestion) `mv` over a symlinked settings.json detached dotfiles — `:162` → written through the symlink; tested (`1c31060`)
- [x] (suggestion) Project guide `cat`ed uncapped into every session — `session_start_project_layer.sh:176` → capped at 16 KB with a truncation note naming the file (`9e770bd`)
- [x] (suggestion) False "cwd is NOT the workspace checkout" claim — `:100` → contrasts the two concrete paths instead of asserting something it cannot know; its quoted idiom carries the fallback (`9e770bd`)
- [x] (suggestion) `derive_project_name` missed `worktrees=`-override worktrees — `dispatch_phase.sh:128` → second pass over registered worktree dirs, longest match wins, explicit `--project` still overrides (`05fe7e4`)
- [x] (suggestion) `.agent/WORKTREE_GUIDE.md:9`/`:135` stale on `--type` → corrected (not Ask-First): optional when the cwd resolves, explicit always wins, refusal rather than a guess when neither (`7054283`)

Also, from the review's closing notes: ADR-0016 gains an explicit clause that the Provisional→Accepted flip is a status-line edit under ADR-0008 and that a forced Decision change takes a superseding ADR instead; and the plan's step-8 manifest list, which still named `cross_model_review.sh`, is corrected in place with the reason (`7054283`).

### Tests

| Suite | Before | After |
|---|---|---|
| `run_script_tests.sh` (27 suites) | pass | **pass**, 82s |
| `test_user_tier_install.sh` | 33 | **53** |
| `test_user_tier_guard.sh` | 43 | **48** |
| `test_session_start_layer.sh` | 37 | **42** |
| `test_skill_paths.sh` | 36 | **51** |
| `test_dispatch_phase.sh` | 99 | **102** |
| `test_adapter.sh` | 86 | 86 |

shellcheck clean on every touched script. Nothing pushed.

### For the re-review

Two of the round-1 fixes changed behaviour rather than just hardening it, and are the places to look first: the adapter now guards `--from` rather than `$PWD` (so an invocation that used to pass can now refuse, and vice versa), and `derive_project_name` resolves from worktree dirs as well as hosting dirs (a cwd that used to derive nothing now derives a project). Both are covered, but both widen what the code says yes to.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 14:17 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested
**Dispatch**: resumed (round-1 reviewer, resume 1 of 3)

**Branch**: feature/issue-317 at `6f3a628`
**Base**: main
**Depth**: Standard, scoped to the fix range 5f07025..6f3a628 (time box; no full re-read of the round-1 surface)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 4), not rising — fix and ship rather than another full round

### Findings
- [x] (must-fix) `--force` is the remedy its own error message prescribes, but it takes over incompletely and exits 0 claiming success: verified in a sandbox HOME with two real checkouts — after `cloneB --force`, `~/.claude/settings.json` holds **two** SessionStart entries (both layers injected every session) plus cloneA's PreToolUse entries, and every skill symlink still points into cloneA, so `$WS_ROOT` moves but the skills do not. `cloneB --check` then reports drift immediately after a successful install. Two causes: the install jq prunes only entries tagged with *this* checkout, and `sync_skills` treats a link into another checkout as "not ours to replace" — `.agent/scripts/user_tier_install.sh:412` and `:184`
- [x] (suggestion) The symlinked-settings path writes with `cat "$tmp" > "$SETTINGS"`, which truncates before writing — non-atomic, and an interruption leaves the user's dotfile-managed settings truncated. Resolving the link (`readlink -f`) and `mv`ing onto the target keeps both the dotfile and atomicity — `.agent/scripts/user_tier_install.sh:250`
- [x] (suggestion) Every install run writes another timestamped backup with no pruning, so `~/.claude` accumulates `settings.json.agent-workspace-backup.*` indefinitely; two runs in the same second overwrite each other. Keep the newest N — `.agent/scripts/user_tier_install.sh:236`
- [x] (suggestion) `derive_project_name`'s new worktree-dir pass is correct, but a `worktrees=` override pointing at a broad directory (e.g. the workspace's own `worktrees/`) would make a *workspace* worktree cwd derive that project name. It only affects `--type project` dispatches with no `--project`, where the alternative was a wrong single-project guess, so this is a note, not a defect — `.agent/scripts/dispatch_phase.sh:145`

### Round-1 resolution
All four round-1 must-fix items are closed and tested. Re-verified independently: the unparseable-settings clobber now refuses in install, uninstall and `--check`, leaving the file byte-for-byte untouched, with a timestamped backup before every rewrite; a second checkout refuses and names both paths, and its `--check` exits 1 instead of the cheerful "not installed (optional)"; the `|| echo .` fallback is present in all 12 scoped skills that reference a workspace script (`what-next` references none), with no bare `cat` left anywhere; the ADR-0016 row is in the review guide. Of the 13 suggestions, 12 are resolved as described — `review-code`'s path-pattern cell is reverted, the jq check no longer reddens `make validate`, the hooks fail closed, the adapter guards the effective `--from` dir, the project guide is capped at 16 KiB, orphaned allow-rules are now recorded and cleared. The two widening fixes were cold-read first: nothing repo-affecting runs in the adapter between its old and new guard position (argument parsing only), `FROM_DIR` is initialised before use under `set -euo pipefail`, a non-existent `--from` correctly falls back to `$PWD`, and both widened directions match the guard's stated contract. Fail-closed is the safe direction for both hooks: neither is a security boundary, and the failure they now avoid — blocking or logging a stranger's commands in an unrelated repo — is the one the user-tier rule exists to prevent; in the workspace checkout the project-tier registration still covers the blocker. 27/27 suites pass (76s), shellcheck clean.

## Implementation

**Status**: complete
**When**: 2026-09-22 14:23 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-317 at a7dc5d4
**Addressed**: Local Review (Pre-Push) at `6f3a628` (round 2)
**Dispatch**: resumed (implementer, resume 2 of 3)
**Commits**: a7dc5d4

All four round-2 findings actioned — 1 must-fix, 3 suggestions. None deferred.

### Actions

- [x] (must-fix) `--force` took the tier over incompletely and exited 0 claiming success — `user_tier_install.sh:412` and `:184`. Both causes fixed. The install jq pruned only entries tagged with *this* checkout; under `--force` it now prunes every entry carrying the `_agent_workspace` marker whatever its value, because taking the tier over means taking the entries over too. `sync_skills` treated a link into another checkout as "not ours to replace"; new `foreign_skill_link()` recognises a link into a different agent_workspace checkout — by the `.agent/user_tier_scripts.txt` that only a checkout has — and, under `--force` only, repoints it. The stale-link sweep recognises those links too, so a skill this checkout does not select cannot survive as a link into the checkout we just took the tier from. Entries with no marker (the user's own) are untouched in both modes.
- [x] (suggestion) Non-atomic write through a symlinked settings.json — `:250` → `readlink -f`, stage beside the real file, `mv` onto it. `cat >` truncated first, so an interrupted write left a half-file where a valid settings.json had been; the dotfiles symlink still survives.
- [x] (suggestion) Backups unbounded and same-second collisions — `:236` → nanosecond stamp with a pid fallback where `%N` is not expanded, a uniquifying counter, newest 5 kept.
- [x] (suggestion) `derive_project_name`'s worktree pass is broader than "overrides under the workspace root" — `dispatch_phase.sh:145` → scope note added. Comment only, no behaviour change, as asked.

### Tests

`test_user_tier_install.sh` **53 → 60**. The two-checkout case now asserts the takeover is *complete* rather than merely announced: exactly one `SessionStart` entry, no entry tagged with the old checkout, no hook command pointing into it, every skill symlink repointed into the taking-over checkout, `--check` clean immediately afterwards, and the user's own untagged entry still present. Plus backup rotation across seven back-to-back installs.

`run_script_tests.sh`: **27/27 suites green, 79s.** shellcheck clean on every touched script. Nothing pushed.

### Note for the re-review

Two test fixtures had to be re-established inside their own blocks rather than inherited: the round-1 malformed-settings case deletes and rebuilds `settings.json`, so the user's untagged `/opt/mine.sh` entry and the user allow-rule no longer survive into later blocks. That is a property of the suite's ordering, not of the code — but it means an assertion about "the user's own entry survives" is only meaningful if the block sets it up itself.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 14:27 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved
**Dispatch**: resumed (round-1 reviewer, resume 2 of 3)

**Branch**: feature/issue-317 at `134ea2f`
**Base**: main
**Depth**: Standard, scoped to the fix range 6f3a628..134ea2f (one code commit)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

### Findings
- [x] (suggestion) No test covers `foreign_skill_link()`'s negative case: a user's own skill symlink pointing somewhere that is not an agent_workspace checkout, under `--force`. Verified correct by reading — the manifest probe three levels up is what gates it — but the existing "a skill directory the user owns is never replaced" case uses a real directory, not a symlink elsewhere, so the one branch that could newly clobber a user's link is unasserted — `.agent/scripts/tests/test_user_tier_install.sh:213`
- [x] (suggestion) The symlinked-`settings.json` write path (`readlink -f`, stage beside the real file, atomic `mv`) has no test; a dotfiles-managed settings.json is exactly the case where a regression would be silent and expensive — `.agent/scripts/user_tier_install.sh:269`

### Round-2 resolution
The round-2 must-fix is closed. The install jq now drops every `_agent_workspace`-marked entry under `--force` regardless of which checkout tagged it, and the no-`--force` path is byte-identical in behaviour to round 2 (`$force` false makes the added `select` a tautology, so only entries tagged with this checkout are pruned) — confirmed by reading the filter, not by report. Unmarked user entries survive in both modes. `foreign_skill_link()` gates on `$FORCE`, resolves the link, walks up three levels and requires `.agent/user_tier_scripts.txt` there plus a root different from this one, so it cannot repoint a symlink that is not into an agent_workspace checkout; the stale-link sweep uses the same predicate. The two-checkout test asserts exactly one SessionStart entry, no entry tagged with the old checkout, no hook command into it, every symlink repointed, `--check` clean immediately after, and the user's untagged entry still present — and it re-creates that untagged fixture immediately before the takeover, with a comment naming the malformed-settings rebuild that had dropped the earlier one, so the assertion is real rather than vacuous. Backup rotation is asserted end-to-end (seven back-to-back installs leave exactly five backups, which also proves the same-second collision is gone). The symlink write is now atomic. 27/27 suites pass (78s), shellcheck clean.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 14:32 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: publish
**Decision**: address

Address the two round-3 test-coverage suggestions (negative case for `foreign_skill_link()` on a user's own non-workspace symlink under `--force`; a test for the symlinked-settings.json atomic write path) before publishing. Not started today: the owner's stop is 15:00 and a fix pass plus re-review would not finish. Next session starts here: address-findings (implementer has 1 resume left; round-1 reviewer has 1 resume left), then merge origin/main (behind by PR #316's three registry commits, no overlap), re-review, publish.

## Implementation

**Status**: complete
**When**: 2026-09-22 14:40 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-317 at 76468c8
**Addressed**: Local Review (Pre-Push) at `134ea2f` (round 3)
**Dispatch**: resumed (implementer, resume 3 of 3)
**Commits**: 76468c8

Both round-3 test-coverage findings actioned. Tests only — no production
code changed in this round (`git diff` touches one file).

### Actions

- [x] (suggestion) No coverage of `foreign_skill_link()`'s negative case — `test_user_tier_install.sh:213` → new case builds a skill symlink the *user* made, pointing into a plain directory with no `.agent/user_tier_scripts.txt` three levels up, runs install `--force`, and asserts the link still points where it did and that the run reports it as "not ours to replace". It also asserts the fixture genuinely is not a checkout, so the case cannot pass for the wrong reason.
- [x] (suggestion) No coverage of the symlinked-`settings.json` write path — `user_tier_install.sh:269` → new case symlinks `settings.json` into a dotfiles directory and asserts it is still a symlink to the same path, that the dotfiles file itself received the marker entries, that no stray staging file is left beside it or in `~/.claude`, and that `--check` is clean afterwards.

### The second test needed one more assertion than the brief listed

The set above did **not** discriminate the fix from the bug it replaced. A
truncating `cat > "$SETTINGS"` also leaves a symlink pointing at the same
target with the right content and no stray files — it passed every one of
those assertions. What separates the two is the real file's **inode**: a
rename allocates a new one, truncate-in-place keeps it. The case now
records the inode before the install and requires it to change, which is
the property the round-2 fix was actually about (an interrupted write must
not leave a half-written settings.json).

Both cases were mutation-checked against the code they guard:

| Mutation | Result |
|---|---|
| Drop the `.agent/user_tier_scripts.txt` probe from `foreign_skill_link()` | case 1 fails (link repointed, no "not ours" message) |
| Revert the symlink write to `cat > "$SETTINGS"` | case 2 fails on the inode assertion |

Without the mutation check the second case would have been coverage that
could never fail — worth stating, because that is the failure mode
test-coverage findings are meant to close.

### Tests

`test_user_tier_install.sh` **60 → 70**. `run_script_tests.sh`: **27/27
suites green, 77s.** shellcheck clean (two `ls | grep` counts replaced with
globs after SC2010). Committed with the full pre-commit suite, including
`validate-script-tests`. Nothing pushed.

Elapsed: ~15 minutes.
