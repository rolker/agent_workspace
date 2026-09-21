---
issue: 297
---

# Issue #297 — script tests: mktemp sandboxes registered inside $() never get cleaned — ~100 leaked into /tmp per run, stalling boot 2 min

## Issue Review
**Status**: complete
**When**: 2026-09-21 09:49 -0400
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #297

### Scope Assessment

**Well-scoped?** Mostly, but the fix list is incomplete. Verified against
the code on `main`: `test_ros2_colcon.sh`, `test_merge_pr.sh`, and
`test_precommit_hook_path.sh` all have the reported bug (`SANDBOXES+=`
inside a `make_sandbox`/`mk_ws` helper that's only ever invoked as
`sb="$(helper)"`, so the append happens in the command-substitution
subshell and never reaches the parent's array). But three more suites in
the same directory have the **identical** pattern and are not in the
issue's fix list:

- `test_project_registry.sh` — `make_sandbox()` (line 59) appends inside
  the function; every call site is `sb="$(make_sandbox)"` (7+ sites,
  e.g. lines 114, 122, 132, 142...). Same bug, same leak.
- `test_adapter.sh` — identical `make_sandbox()` shape, same
  `sb="$(make_sandbox)"` call pattern (lines 113, 121, 143...).
- `test_merge_pr_gate.sh` — `make_sandbox()` (line 135) does
  `sb="$(mktemp -d)"; SANDBOXES+=("$sb")` internally, called as
  `sb="$(make_sandbox ...)"` at 25+ sites. Same bug.

A fourth, different-shaped leak: `test_dispatch_phase.sh`'s `mk_sandbox()`
(line 27) creates a sandbox with `sb="$(mktemp -d)"` and returns it, but
never registers it in any array or under the file's own `$TMPD` (which
only covers fixture files, cleaned via its own `trap ... EXIT`) — every
call unconditionally leaks, no subshell involved at all.

If the goal is to stop the boot-stalling leak, fixing 3 of at least 7
affected suites leaves the other 4 leaking on every commit. Recommend
widening scope to all suites with this shape, or explicitly scoping this
issue to the reported 3 and opening a follow-up for the rest — right now
neither is stated.

**Right repo?** Yes — `.agent/scripts/tests/` is workspace test
infrastructure.

**Dependencies**: None blocking, but one worth flagging for merge
ordering: `test_worktree_enter_stderr.sh` on the not-yet-merged
`feature/issue-194` branch already uses the pattern this issue should
converge everything on — a single `SANDBOX="$(mktemp -d)"` assigned
directly at top level (no wrapper function, no `$()` around a
multi-statement helper) with `trap 'rm -rf "$SANDBOX"' EXIT`. Whichever
of #194 / #297 merges first, the other should match this shape rather
than inventing a second "correct" pattern.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | Action needed | The issue's second bullet ("Consider a suite-level guard... run the suite under a per-run `TMPDIR`... and sweep it at the end") is the only mechanism that would catch a *future* suite reintroducing this bug, and it's phrased as optional. Given 4 of ~23 suites already have it independently, an opt-in per-file discipline has already failed twice over. This should be a required part of the fix, not a "consider." |
| A change includes its consequences | Action needed | See Scope Assessment above — `test_project_registry.sh`, `test_adapter.sh`, `test_merge_pr_gate.sh`, and `test_dispatch_phase.sh` share the reported defect (or a variant of it) and aren't in the fix list. Leaving them means the "assert dir is empty after `TMPDIR`-redirected run" bar from the issue's own Fix section wouldn't actually pass suite-wide even after this PR lands. |
| Capture decisions | Watch | The correct pattern (register in the caller's shell, never inside a `$()` capture; prefer one top-level `mktemp -d` + `trap ... EXIT` over a per-call array where a single sandbox suffices) isn't written down anywhere discoverable before suite #24 gets added. Worth a short convention note — a comment block in `run_script_tests.sh`, or a line in the script-test entry of `AGENTS.md`'s reference table — pointing at `test_worktree_enter_stderr.sh` as the reference shape. |
| Test what breaks | OK | The issue's own verification step (re-run under an empty `TMPDIR`, assert empty afterward) directly targets the regression rather than just re-running the existing suites, which pass today despite leaking. |
| Only what's needed | OK | The 3 named fixes are proportionate to the files named; the "widen scope" concern above is about completeness, not over-building. |
| Improve incrementally | OK | Bounded, mechanical fix; no rewrite. |
| Human control and transparency | OK | No hidden behavior change — cleanup traps start doing what they already claimed to do. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0011 — Project-type adapter contract | No — but the issue's proposed runner path is wrong | The issue's second bullet says the guard belongs in ".agent/scripts/test.sh → adapter test". That's the **project's** test command (`TEST_CMD` from `project_config.sh`, dispatched per project type) — unrelated to this repo's own script-test suite. The suite that actually runs `test_*.sh` under `.agent/scripts/tests/` is `run_script_tests.sh`, wired directly into pre-commit as the `validate-script-tests` hook (`.pre-commit-config.yaml` line 57-59) — it never goes through the adapter. A TMPDIR sweep belongs in `run_script_tests.sh` (or the hook invocation), not in the adapter/`test.sh` path. Worth correcting before implementation starts so effort isn't spent wiring the guard into the wrong runner. |
| 0013 — `progress.md` entry-type vocabulary | Yes (mechanically, for this review) | This review's own persistence uses the canonical `## Issue Review` heading via `review_progress.sh persist`. No action needed from the issue itself. |

### Consequences

- If `run_script_tests.sh` gains a TMPDIR-sweep guard, its one-line
  description in `AGENTS.md`'s Script Reference table should note the
  guard so the table stays accurate (Consequences Map: "A script in
  `.agent/scripts/` → Script reference table in `AGENTS.md`").
- If the fix set is widened per the Scope Assessment above, the issue
  body's own repro table and fix bullet list should be updated (or a
  follow-up issue opened) so the tracked scope matches what actually
  ships.

### Recommendations

- Widen the fix to all suites sharing this shape — at minimum add
  `test_project_registry.sh`, `test_adapter.sh`, `test_merge_pr_gate.sh`,
  and `test_dispatch_phase.sh` to the file list, or explicitly split them
  into a tracked follow-up issue before closing this one.
- Make the "suite-level `TMPDIR` guard" a required part of this issue's
  fix, not an optional "consider" — it's the only enforcement-layer
  defense against a fifth suite reintroducing the same bug.
- Point the guard at `run_script_tests.sh` (the actual suite runner wired
  into the `validate-script-tests` pre-commit hook), not at
  `.agent/scripts/test.sh` / `adapter test`, which runs the project's own
  `TEST_CMD` and has nothing to do with this repo's script-test suite.
- Standardize on the single-`mktemp`-plus-`trap`-at-top-level shape
  already used by `test_worktree_enter_stderr.sh` (`feature/issue-194`,
  unmerged) rather than inventing a new correct pattern in this PR —
  reference it explicitly so whichever branch merges second reconciles
  onto the same convention instead of a second bespoke fix.

### Actions
- [ ] The issue's second bullet ("Consider a suite-level guard... run the suite under a per-run `TMPDIR`... and sweep it at the end") is the only mechanism that would catch a *future* suite reintroducing this bug, and it's phrased as optional. Given 4 of ~23 suites already have it independently, an opt-in per-file discipline has already failed twice over. This should be a required part of the fix, not a "consider."
- [ ] See Scope Assessment above — `test_project_registry.sh`, `test_adapter.sh`, `test_merge_pr_gate.sh`, and `test_dispatch_phase.sh` share the reported defect (or a variant of it) and aren't in the fix list. Leaving them means the "assert dir is empty after `TMPDIR`-redirected run" bar from the issue's own Fix section wouldn't actually pass suite-wide even after this PR lands.
- [ ] Widen the fix to all suites sharing this shape — at minimum add `test_project_registry.sh`, `test_adapter.sh`, `test_merge_pr_gate.sh`, and `test_dispatch_phase.sh` to the file list, or explicitly split them into a tracked follow-up issue before closing this one.
- [ ] Make the "suite-level `TMPDIR` guard" a required part of this issue's fix, not an optional "consider" — it's the only enforcement-layer defense against a fifth suite reintroducing the same bug.
- [ ] Point the guard at `run_script_tests.sh` (the actual suite runner wired into the `validate-script-tests` pre-commit hook), not at `.agent/scripts/test.sh` / `adapter test`, which runs the project's own `TEST_CMD` and has nothing to do with this repo's script-test suite.
- [ ] Standardize on the single-`mktemp`-plus-`trap`-at-top-level shape already used by `test_worktree_enter_stderr.sh` (`feature/issue-194`, unmerged) rather than inventing a new correct pattern in this PR — reference it explicitly so whichever branch merges second reconciles onto the same convention instead of a second bespoke fix.

## Checkpoint
**Status**: complete
**When**: 2026-09-21 10:00 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed to planning (Recommended) — the Issue Review's action items carry into the plan: widen the fix to all seven leaking suites (add test_project_registry.sh, test_adapter.sh, test_merge_pr_gate.sh, test_dispatch_phase.sh); make the suite-level per-run TMPDIR guard + sweep required, in run_script_tests.sh (not .agent/scripts/test.sh); standardise on the top-level mktemp + trap shape used by test_worktree_enter_stderr.sh on feature/issue-194.

## Plan Authored
**Status**: complete
**When**: 2026-09-21 10:04 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-297/plan.md` at `8fb917f`

Two PRs: PR 1 converts all seven suites with the $()-swallowed-array (or,
for test_dispatch_phase.sh, never-registered) sandbox leak — the three the
issue named plus test_project_registry.sh, test_adapter.sh,
test_merge_pr_gate.sh, and test_dispatch_phase.sh, found by the Issue
Review — to a single top-level `SANDBOX="$(mktemp -d)"` + `trap 'rm -rf
"$SANDBOX"' EXIT`, matching test_worktree_enter_stderr.sh on the unmerged
feature/issue-194 branch. PR 2 adds the required per-run TMPDIR guard +
sweep to run_script_tests.sh (not adapter test/test.sh), updates AGENTS.md's
script table, and documents (not automates) a one-time cleanup command for
the ~2,800 pre-existing /tmp/tmp.* leaks. PR 1 lands before PR 2 so the
guard passes on first run instead of failing on suites not yet converted.

## Plan Review
**Status**: complete
**When**: 2026-09-21 10:09 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #297 — script tests: mktemp sandboxes registered inside $() never get cleaned — ~100 leaked into /tmp per run, stalling boot 2 min
**Plan**: `.agent/work-plans/issue-297/plan.md` at `8fb917f`
**Branch**: `feature/issue-297`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | Two-PR split and ordering are sound and well argued. But the inventory misses an eighth suite with the same shape, and five suites whose `mktemp` calls the PR 2 guard structurally cannot see are out of scope. |
| Issue alignment | Good | All six Issue Review action items and the owner's checkpoint decision (seven suites, required guard in `run_script_tests.sh`, the `test_worktree_enter_stderr.sh` shape) are carried into the plan. |
| File targeting | Needs work | `test_run_script_tests.sh` (the runner's own suite) and `test_checkpoint_269.sh` are both missing from the Files to Change table. |
| Consequences | Needs work | `AGENTS.md` script table is covered. The runner's own test suite, and its header "Exit codes:" contract, are not. |
| Principle alignment | Needs work | "Enforcement over documentation" is the plan's stated point, but the enforcement layer ships with no test ("Test what breaks"). |
| ADR compliance | Good | ADR-0011 correction (guard belongs in `run_script_tests.sh`, not `adapter test`) carried from the Issue Review; ADR-0013 satisfied by this plan's own persistence. No other ADR triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Approach] (must-fix)** — PR 1 step 2 says per-test subdirectories can be named by "a monotonic counter or the calling test's function name". A counter reintroduces exactly the bug being fixed: the helpers are invoked as `sb="$(make_sandbox)"`, so a counter incremented inside the helper increments a subshell copy, the parent's value never moves, and every call returns the same subdirectory — tests silently share one sandbox instead of leaking. Use `mktemp -d "$SANDBOX/XXXXXX"` (or `mktemp -d -p "$SANDBOX"`) inside the helper: unique without any parent-shell state, everything under the one trapped root.

2. **[Approach / File targeting] (must-fix)** — Putting the per-run `TMPDIR` under `.agent/scratchpad/` places every sandbox *inside the workspace git work tree*. `test_adapter.sh` and `test_project_registry.sh` `make_sandbox()` deliberately create sandbox roots that are **not** git repos (they `git init` only nested fixture repos) and then run `adapter` / `_project_registry.sh` inside them; `test_merge_pr_root_resolution.sh::test_resolution_outside_repo` (line 122) asserts root resolution returns empty outside any repo — and hardcodes `/tmp` for precisely this reason. Inside the repo tree, upward `git rev-parse` discovery finds the real workspace root and those become false passes or false failures. Put the per-run dir under `/tmp` — AGENTS.md permits `/tmp` for ephemeral files cleaned up in the same command, and the guard deletes it unconditionally — or anywhere outside a git work tree.

3. **[Consequences] (must-fix)** — PR 2 changes `run_script_tests.sh` but the plan omits `.agent/scripts/tests/test_run_script_tests.sh`, the existing suite that tests the runner against scratch tests directories via its `[tests-dir]` argument. As written the enforcement layer ships untested. Add cases: a fixture suite that leaks into `TMPDIR` makes the runner fail with the leak message, a clean fixture still passes. Also update the runner's header "Exit codes:" block (lines 26–27), and if a distinct exit code is chosen, re-check the existing fail-fast case's exit-code assertion. Related: derive the guard's directory from `SCRIPT_DIR`, not the caller-supplied `TESTS_DIR`, or the nested runs inside that suite write to the wrong place.

4. **[Scope / Approach] (must-fix)** — The guard is blind to `mktemp` invoked with an absolute template, which ignores `TMPDIR`. Five suites do this today: `test_block_bash_tool_mapping.sh:22`, `test_cross_model_review.sh:19`, `test_gh_create_pr.sh:27`, `test_merge_pr_root_resolution.sh:23,122`, `test_sync_gitbug.sh:28`. A future suite copying that shape leaks straight past the sweep, so the plan's claim that the guard stops an eighth suite reintroducing the bug does not hold as designed. Either normalise those to `TMPDIR`-honouring form in PR 1 (subject to finding 2 for the no-repo test), or have the guard also lint for literal `/tmp/` mktemp templates under `.agent/scripts/tests/`.

5. **[Issue alignment / File targeting] (must-fix)** — The plan's statement "No additional suites with this shape were found beyond the seven above" is not accurate. `test_checkpoint_269.sh` has `_sandbox_repo()` (lines 139–145) doing `dir=$(mktemp -d)` and echoing it, called as `REPO=$(_sandbox_repo)` (161, 273) and `ORIGIN=$(_sandbox_repo)` (238), with **no `SANDBOXES` array and no `EXIT` trap anywhere in the file** (`set -u` only, line 34); cleanup is explicit `rm -rf` on the success path (201, 269, 288). It does not leak on a clean pass, but leaks on any abort or early exit — the `test_dispatch_phase.sh` shape with a happy-path-only mitigation — and it is the one suite `run_script_tests.sh` hard-requires. Fold it into PR 1 as an eighth file or state explicitly why it is excluded. Smaller instance of the same: `test_merge_pr_root_resolution.sh:122`'s `tmp` has no trap coverage.

6. **[Context] (suggestion)** — #194 merged while this plan was being written: `main` is at `f1e6694` "Merge pull request #299 from rolker/feature/issue-194". The plan's instructions to read the reference shape via `git show origin/feature/issue-194:...` are stale — read `.agent/scripts/tests/test_worktree_enter_stderr.sh` on `main`. This worktree's branch predates the merge and does not contain that file; rebase onto `main` before implementing so the converted suites and the reference suite share a base.

7. **[Approach] (suggestion)** — Sweep inside the existing per-suite loop rather than once after it. The runner already iterates suite by suite, so sweeping after each gives exact attribution instead of "which suite ran last" (which is only accurate on the fail-fast path) and stops the run at the suite that actually leaked.

8. **[Approach] (suggestion)** — The documented one-time cleanup filters on `[ -d "$1/.git" ]`, but many leaked sandbox roots are never git-init'd (`test_adapter.sh` / `test_project_registry.sh` `make_sandbox()` create plain directories; `test_dispatch_phase.sh`'s fixture dirs likewise). The command will clear only part of the ~2,800 and leave the boot-stall symptom partly in place. Say so where it is documented, and offer a complementary selector (content match such as `.agent/scripts/adapter`, or a plain age-based variant for the owner to run with judgement).

9. **[Approach] (suggestion)** — When folding the extra `outside` / `bare` sandboxes into `$SANDBOX`, preserve their semantics: the `outside` dirs in `test_project_registry.sh` (726, 989, 1086, 1113, 1165) and `test_merge_pr.sh` (681) exist to be *outside* the sandbox workspace root, so they must become siblings under `$SANDBOX`, never children of `$sb`.

10. **[Scope] (suggestion)** — The PR split and ordering are right on the merits: PR 1 is behaviour-neutral plumbing, PR 2 is the enforcement layer, and landing the guard first would turn pre-commit red on `main` for every suite not yet converted. One caveat: PR 1's only verification is a manual per-suite `TMPDIR` check, so nothing protects the gap between the two — land PR 2 promptly and verify it with a full `run_script_tests.sh` run.

### Summary

The plan's diagnosis, scope widening, PR split and ordering are all sound, and it carries every Issue Review action item and the owner's checkpoint decision. It is not ready to implement as written: the per-test subdirectory scheme reintroduces the same subshell bug, the per-run `TMPDIR` location would silently break the suites that depend on sandboxes sitting outside a git repo, the guard cannot see the five suites that pass `mktemp` an absolute `/tmp` template, and the enforcement layer arrives with no test because the runner's own suite is missing from the file list.

### Recommended Actions

- [ ] Replace the counter/function-name subdirectory scheme with `mktemp -d "$SANDBOX/XXXXXX"` inside each helper (finding 1)
- [ ] Move the per-run `TMPDIR` out of the git work tree — `/tmp`, deleted unconditionally by the guard (finding 2)
- [ ] Add `.agent/scripts/tests/test_run_script_tests.sh` to PR 2's file list with leak/no-leak cases, and update the runner's "Exit codes:" header (finding 3)
- [ ] Decide how the guard covers absolute-template `mktemp` calls — normalise the five suites or lint for the pattern (finding 4)
- [ ] Add `test_checkpoint_269.sh` to PR 1's file list, or record why it is excluded; correct the plan's "no additional suites" claim (finding 5)
- [ ] Update the plan's `feature/issue-194` references to `main` and rebase this worktree onto `main` (finding 6)
- [ ] Consider per-suite sweeping, a fuller cleanup-command caveat, and `outside`/`bare` sibling placement (findings 7–9)

## Checkpoint
**Status**: complete
**When**: 2026-09-21 10:26 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise the plan with all ten Plan Review findings folded in (5 must-fix: mktemp -d under the trapped root, not a counter; per-run TMPDIR outside the git work tree; test_run_script_tests.sh cases for the guard; absolute-template mktemp sites normalised or linted; test_checkpoint_269.sh as the eighth file). Owner asked whether .agent/scratchpad/ being gitignored changes finding 2 — it does not: ignore rules affect tracking, not `git rev-parse` discovery, so a sandbox there still resolves to the workspace root.

## Plan Authored
**Status**: complete
**When**: 2026-09-21 12:00 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-297/plan.md` at `cadf1a9`

Revised plan folding in all ten Plan Review findings (five must-fix, five
suggestions): replaced the counter-based per-test subdirectory scheme with
`mktemp -d -p "$SANDBOX"`, moved the PR 2 per-run `TMPDIR` from
`.agent/scratchpad/` to `/tmp` (outside any git work tree), added
`test_run_script_tests.sh` leak/no-leak coverage for the new guard,
normalised the five suites that hardcode an absolute `/tmp` `mktemp`
template, added `test_checkpoint_269.sh` as the eighth suite in scope
(correcting the earlier "no additional suites" claim), and moved the sweep
inside the per-suite loop, sibling-not-child placement for `outside`/`bare`
fixtures, a fuller one-time-cleanup caveat, and PR 2 landing promptly after
PR 1. `main` (with #194 / PR #299) was merged into this branch first so the
plan's reference to `test_worktree_enter_stderr.sh` points at `main`
instead of the old unmerged branch.

## Plan Review
**Status**: complete
**When**: 2026-09-21 10:35 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #297 — script tests: mktemp sandboxes registered inside $() never get cleaned — ~100 leaked into /tmp per run, stalling boot 2 min
**Plan**: `.agent/work-plans/issue-297/plan.md` at `cadf1a9`
**Branch**: `feature/issue-297`
**Round**: 2 (revision of the `needs-work` review at round 1)

### Round-1 findings — verification against the tree

| # | Round-1 finding | Resolved? |
|---|---|---|
| 1 | counter/function-name subdirs | Yes — step 2 now mandates `mktemp -d -p "$SANDBOX"` and explains why counters collapse inside `$()` |
| 2 | `TMPDIR` under `.agent/scratchpad/` | Yes — PR 2 step 1 puts it under `/tmp`, with the git-discovery rationale and the gitignore caveat |
| 3 | `test_run_script_tests.sh` coverage | Yes — PR 2 step 3 adds leak/no-leak fixture cases, the exit-codes header update, and the re-check of the fail-fast assertion. Verified against the file: the runner's header block is lines 26–27 as cited; the existing cases (b)/(c) assert `rc -ne 0`, not an exact code, so a new distinct code will not break them |
| 4 | absolute `/tmp/...` templates | **Partial** — see must-fix 1 |
| 5 | eighth suite `test_checkpoint_269.sh` | **Partial** — the suite is now in scope, but see must-fix 2 |
| 6 | stale `origin/feature/issue-194` reference | Yes — `main` merged (`f56458c`); `.agent/scripts/tests/test_worktree_enter_stderr.sh` exists on this branch with `SANDBOX="$(mktemp -d)"` (line 22) + `trap ... EXIT` (line 23) |
| 7 | sweep inside the per-suite loop | Yes — PR 2 step 2 sweeps after each suite, names the offending suite and paths, stops the run, uses a distinct exit code, and `rm -rf`s the per-run dir unconditionally |
| 8 | `.git` filter clears only part of the ~2,800 | Yes — PR 2 step 5 states the partial coverage and offers complementary selectors for the owner |
| 9 | `outside` / `bare` must stay siblings | Yes — step 3 requires `$SANDBOX/outside-<x>` as a sibling of `$SANDBOX/<x>` |
| 10 | gap between the two PRs | Yes — stated in the Approach preamble and Estimated Scope |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two-PR split and ordering are right; PR 1 stays behaviour-neutral |
| Issue alignment | Good | Covers the three named suites plus the five the reviews found |
| File targeting | Needs work | Two per-line inventories are still incomplete and one file's shape is described incorrectly (must-fix 1–3) |
| Consequences | Good | `AGENTS.md` script table, `test_run_script_tests.sh`, exit-code consumers all covered |
| Principle alignment | Good | Enforcement over documentation, only-what's-needed, human control on the cleanup command |
| ADR compliance | Good | ADR-0011 correction (runner, not `adapter test`) carried through; ADR-0013 persistence noted |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[File targeting] (must-fix)** — The absolute-template inventory (Context, and Files to Change) is still incomplete for `test_gh_create_pr.sh`. It names only line 27 (`SHIM_DIR=$(mktemp -d /tmp/gh_create_pr_shim-XXXXXX)`), but the same file has five more absolute `/tmp` templates: lines 140, 157, 207, 239 (`TMPF=$(mktemp /tmp/test_body.XXXXXX.md)`) and 350 (`TMPF_MX=...`). They are `rm -f`'d inline on the success path (153, 176, 217, 253, 358), so they are not the recurring leak — but they ignore `TMPDIR` exactly as line 27 does, survive any abort, and are invisible to PR 2's sweep, which is the precise failure mode round-1 finding 4 raised. An implementer working from the per-line list will normalise one of six sites. List all six (and say whether the inline `rm -f` calls stay or are dropped in favour of the trap).

2. **[File targeting / Approach] (must-fix)** — `test_checkpoint_269.sh` has two further top-level `mktemp -d` sandboxes the plan does not mention anywhere: `SHALLOW=$(mktemp -d)` (line 244) and `NOREMOTE=$(mktemp -d)` (line 261). Today they are cleaned only by the explicit `rm -rf "$ORIGIN" "$SHALLOW" "$NOREMOTE"` at line 269 — one of the three `rm -rf` calls PR 1 step 6 directs the implementer to *drop* in favour of the new trap. As written, the conversion removes their only cleanup while routing only `_sandbox_repo()` under `$SANDBOX`, turning a clean-pass-safe pattern into an unconditional leak on every run. Step 6, the Context row, and the Files to Change row must name lines 244 and 261 and route both through `mktemp -d -p "$SANDBOX"`.

3. **[File targeting] (must-fix)** — The `test_merge_pr_gate.sh` row in the Context table is factually wrong, and the error is repeated in Files to Change. The plan says "several call sites also do a second `SANDBOXES+=("$outside")` / `SANDBOXES+=("$bare")` directly in the test body (those direct appends *do* work …), plus per-test extra sandboxes (e.g. 679–692)". In that file `SANDBOXES+=` appears exactly twice — lines 137 and 146 — both inside `make_sandbox()`, both swallowed by the `$()`; there is no `$outside` variable in the file and lines 679–692 create no sandboxes. The shape described belongs to `test_merge_pr.sh` (direct appends at 652, 682, 687). Consequence for the implementer: line 146's `bare="${sb}.remote.git"` leaks today too and is currently mis-filed as "works", and the Files to Change row asks them to fold a `$outside` that does not exist. Correct both rows. (The round-1 review asked specifically for this inventory to be verified against the tree, so the accuracy bar here is the finding's own bar.)

4. **[Approach] (suggestion)** — Several sandboxes are string-derived siblings of `$sb`, not separate `mktemp` calls: `test_merge_pr_gate.sh:146` (`${sb}.remote.git`, re-derived at line 236 in `make_ci_sandbox` and used as the `gh` fixture *filename key* at 241) and `test_merge_pr.sh` (`${sb}.project.remote.git`, `${sb}.farrepo.remote.git`). Once `sb` becomes `mktemp -d -p "$SANDBOX"` these land under `$SANDBOX` automatically and need no separate handling — but the fixture key is computed from that path, so the plan should state the rule explicitly ("keep `bare` derived from `$sb` by string append; do not give it its own `mktemp`") rather than leaving "fold `$bare` into `$SANDBOX`" open to an implementation that changes the path shape and silently breaks fixture lookup.

5. **[File targeting] (suggestion)** — The `test_dispatch_phase.sh` row calls `SBP1` / `SBP2` "`mk_sandbox` calls"; lines 394 and 410 are direct top-level `SBP1="$(mktemp -d)"` / `SBP2="$(mktemp -d)"`, not helper calls. Same fix applies (fold under `$SANDBOX`), but the Files to Change row should name them so they are not missed while converting the helper.

6. **[Context] (suggestion)** — `test_worktree_enter_stderr.sh` is not the only file already using the target convention: `test_resolve_work_plans_dir.sh` (lines 174–184) does eager top-level `TMP_ROOT=$(mktemp -d)` + `trap 'rm -rf "$TMP_ROOT"' EXIT` with an explicit comment about why the helper cannot register from inside `$(...)`. Citing it as a second reference — a helper that builds `${TMP_ROOT}/$base` subdirs — gives the implementer a worked example of the exact helper shape PR 1 wants, and confirms the convention was already the considered choice elsewhere in the tree.

7. **[Approach] (suggestion)** — PR 2 step 3's "derive the guard's per-run `TMPDIR` from `SCRIPT_DIR` context (i.e. it is always a location the guard itself controls under `/tmp`)" reads as a contradiction: the directory comes from `mktemp -d /tmp/run-script-tests.XXXXXX` and has nothing to do with `SCRIPT_DIR`. The intent from round-1 finding 3 is "never derive it from the caller-supplied `[tests-dir]`" — say that plainly and drop the `SCRIPT_DIR` phrasing.

### Summary

The revision folds in all ten round-1 findings and the two substantive design decisions (per-run `TMPDIR` under `/tmp`, per-suite sweep with attribution) are now well argued and correct. What is still not right is the thing round-1 finding 5 was about: the per-line inventories. Spot-checking the tree turns up six absolute-template sites in `test_gh_create_pr.sh` where the plan lists one, two untracked sandboxes in `test_checkpoint_269.sh` whose only cleanup the plan tells the implementer to delete, and a `test_merge_pr_gate.sh` row describing code that is not in that file. These are small edits to the plan but each one changes what an implementer does.

### Recommended Actions

- [ ] List all six absolute-`/tmp` `mktemp` sites in `test_gh_create_pr.sh` (27, 140, 157, 207, 239, 350) and say what happens to the inline `rm -f` calls
- [ ] Add `test_checkpoint_269.sh:244` (`SHALLOW`) and `:261` (`NOREMOTE`) to the Context row, step 6, and the Files to Change row; route both through `mktemp -d -p "$SANDBOX"` before dropping the `rm -rf` at line 269
- [ ] Correct the `test_merge_pr_gate.sh` Context and Files-to-Change rows: the only appends are 137 and 146, both inside `make_sandbox()` and both swallowed; no `$outside`; no sandboxes at 679–692
- [ ] State that `bare` stays a string-derived sibling of `$sb` so the `gh` fixture filename key keeps resolving
- [ ] Name `test_dispatch_phase.sh:394` / `:410` as direct top-level `mktemp -d` sites, not `mk_sandbox()` calls
- [ ] Cite `test_resolve_work_plans_dir.sh:174–184` as a second in-tree reference for the target helper shape
- [ ] Reword PR 2 step 3's `SCRIPT_DIR` sentence to "not derived from the caller-supplied `[tests-dir]`"
