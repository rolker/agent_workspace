---
issue: 330
---

# Issue #330 — validate: the global validator requires .git at every project root (fails ros2_colcon), and single_project validate checks the whole workspace

## Issue Review
**Status**: complete
**When**: 2026-09-23 09:51 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #330

### Scope Assessment

**Well-scoped?** Yes — both defects are in the same file (`validate_workspace.py`) and the same dispatch seam (`adapter_validate` in `single_project/adapter.sh`), and fixing defect 2 (scoping `single_project`'s validate to the named project) is easiest to land alongside defect 1 (moving shape checks into per-type adapters), since both touch how `validate_workspace.py` walks the registry. Splitting them would leave an awkward half-state where the registry loop still hard-codes `.git`. One PR is right-sized; keep it that way rather than growing into a broader adapter refactor.

**Right repo?** Yes — `validate_workspace.py`, `single_project/adapter.sh`, and `ros2_colcon/adapter.sh` are all workspace infrastructure (`.agent/`). No project-repo content is involved.

**Dependencies**: None blocking. Related context: #317 (session-roots/user-tier work, status Provisional per ADR-0016) and the gz4d/geozui4d#7 acceptance run that surfaced this — worth linking, not worth waiting on.

I verified both claimed defects against current source:
- `validate_workspace.py`'s registry loop (~line 126) does `if not (path / ".git").exists() and not (path.resolve() / ".git").exists(): issues.append(f"project '{name}': {path} is not a git repository")` for every non-parent registry entry, regardless of `ptype`. This is exactly the single_project-shaped assumption the issue describes, and it contradicts the adapter contract's own framing.
- `single_project/adapter.sh`'s `adapter_validate()` (line 85-87) is a one-line `exec python3 .../validate_workspace.py "$@"` — it ignores `ACTIVE_PROJECT_NAME`/`ACTIVE_PROJECT_ROOT` entirely and always validates the whole registry. `ros2_colcon/adapter.sh`'s `adapter_validate` (line 567) does check only its own checkout, confirming the asymmetry the issue reports.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | OK | Fix is code (adapter delegation), not a doc note; issue explicitly asks for tests exercising both defects |
| A change includes its consequences | Action needed | If `single_project`'s `validate` verb changes meaning (named-project-only) and a whole-workspace check moves elsewhere, `AGENTS.md`'s script-reference row for `validate_workspace.py` (currently "Validate project/ configuration") and its `make validate` description should be checked against the new split so they still describe what the commands actually do |
| Test what breaks | OK | Issue's own proposed test plan (registry entry with a `ros2_colcon` type and no `.git`; `--project <name> validate` not reporting other projects) targets the actual regression, not framework glue |
| Workspace vs. project separation | OK | Purely workspace-infra; no project coupling introduced |
| Only what's needed | Watch | The fix could be read as "make every adapter's validate fully self-contained," which is more than this issue needs — the minimal fix is: stop hard-coding the `.git` shape check in the generic registry walker, and scope `single_project`'s verb to its own project. Don't let it grow into re-auditing every adapter's `validate` implementation |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0011 — Project-type adapter contract | Yes | This is squarely an ADR-0011 violation: "Shape-specific behavior lives in `.agent/project_types/<type>/adapter.sh` behind the 12-verb contract; workspace content stays project-agnostic." The generic registry loop in `validate_workspace.py` embeds a single_project-shape assumption (`.git` at the entry root) for every type, and the `validate` verb's contract ("Check checkout shape matches what the type expects") is only honored by `ros2_colcon`, not by `single_project`, which instead re-runs the whole-workspace check. The issue's proposed fix (delegate per-entry shape checks to each type's adapter; scope `single_project`'s `validate` to the named project) is the correct application of the existing contract, not new policy. `validate_adapter.sh` should still pass unchanged since the verb signature doesn't change. |
| 0013 — progress.md entry-type vocabulary | No | No workflow-skill changes involved |
| 0016 — Session roots and the user tier | No (tangential) | Only relevant as "found while" context (gz4d session root check); this issue's fix doesn't touch `user_tier_install.sh` or root resolution |

### Consequences

- `AGENTS.md`'s script-reference table entry for `validate_workspace.py` ("Validate project/ configuration") and the `make validate` line in the Build & Test section should be reviewed once the split lands, so they describe the actual per-project vs. whole-workspace split rather than the current (already slightly stale) single description.
- If a new whole-workspace check surfaces as its own command/verb (the issue suggests keeping "the whole-workspace check as its own command, for example `make validate`"), confirm it doesn't collide with the existing `make validate` semantics documented in `AGENTS.md`/`ARCHITECTURE.md` — either `make validate` keeps meaning "whole workspace" (already true today) and only the per-project adapter verb narrows, or the split needs to be spelled out explicitly wherever `make validate` is documented.

### Recommendations

- Confirm whether `make validate` (no `--project`) is meant to remain "check everything" after this fix, or whether it should also route to "current project" when one is registered as active — the issue's wording ("keep the whole-workspace check as its own command") reads as the former; state that explicitly in the plan so it isn't left ambiguous during implementation.
- When delegating the per-entry shape check to `adapter --project <name> validate`, make sure `validate_workspace.py` still surfaces the *name* of the failing project in its output (today's `project '{name}': {path} is not a git repository` format) — don't lose that context by just shelling out and passing through the adapter's raw stderr.

### Actions
- [ ] If `single_project`'s `validate` verb changes meaning (named-project-only) and a whole-workspace check moves elsewhere, `AGENTS.md`'s script-reference row for `validate_workspace.py` (currently "Validate project/ configuration") and its `make validate` description should be checked against the new split so they still describe what the commands actually do
- [ ] Confirm whether `make validate` (no `--project`) is meant to remain "check everything" after this fix, or whether it should also route to "current project" when one is registered as active — the issue's wording ("keep the whole-workspace check as its own command") reads as the former; state that explicitly in the plan so it isn't left ambiguous during implementation.
- [ ] When delegating the per-entry shape check to `adapter --project <name> validate`, make sure `validate_workspace.py` still surfaces the *name* of the failing project in its output (today's `project '{name}': {path} is not a git repository` format) — don't lose that context by just shelling out and passing through the adapter's raw stderr.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 10:00 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed (Recommended): plan with `make validate` (no project named) staying a whole-workspace check; keep the failing project's name in error output when delegating shape checks to the adapter; update the AGENTS.md `validate_workspace.py` row and the `make validate` description.

## Plan Authored
**Status**: complete
**When**: 2026-09-23 10:06 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-330/plan.md` at `ede84e1`

Scope `single_project`'s `adapter_validate` to the active project (git-repo check on `ACTIVE_PROJECT_ROOT` / legacy `project/`, no more recursion into the whole-workspace validator), and have `validate_workspace.py`'s registry loop delegate each entry's checkout-shape check to `adapter --project <name> validate` instead of hard-coding `.git`, wrapping any failure as `project '<name>': <summary>`. Adds tests for both fixes and updates `AGENTS.md`'s `validate_workspace.py` row.

## Plan Review
**Status**: complete
**When**: 2026-09-23 10:09 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #330 — validate: the global validator requires .git at every project root (fails ros2_colcon), and single_project validate checks the whole workspace
**Plan**: `.agent/work-plans/issue-330/plan.md` at `ede84e1`
**Branch**: `feature/issue-330`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two defects + tests + doc rows; one PR, ~5 files |
| Issue alignment | Good | Both defects addressed; all three Issue Review actions and the owner Checkpoint decisions are carried into the plan |
| File targeting | Needs work | Existing `validate_workspace.py` tests live in `test_project_registry.sh` (L300-370, L796, `make_validate_sandbox`), not `test_adapter.sh`; the module docstring in `validate_workspace.py` is also a target |
| Consequences | Needs work | ARCHITECTURE.md L98-100 does describe `validate_workspace.py` (plan says it doesn't); `validate_workspace.py`'s own docstring (L9-10 "Configured checkouts are valid git repos") goes stale; registry-parse-error interaction with the delegated call is unhandled |
| Principle alignment | Good | Code + tests, minimal, no adapter audit |
| ADR compliance | Good | ADR-0011 correctly applied (shape check moves behind the `validate` verb, no verb signature change) |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Consequences / correctness]** — Delegating to `adapter --project <name> validate` misattributes registry parse errors. `registry_lookup` (`_project_registry.sh` L310-312) returns 2 for *every* name whenever any line of `projects.local` is malformed (`registry_entries_full` returns 2 while still printing the valid lines), so the dispatcher exits 1 for every healthy entry. `validate_workspace.py` would then add `project '<healthy>': <parse diagnostic>` for each valid project on top of the existing `projects.local: ...` issue — blaming healthy projects. Resolution: when `registry_errors` is non-empty, skip delegation (fall back to the plain `path.exists()` result, or report once that shape checks were skipped because the registry has errors), and add a test with one malformed line plus one healthy entry asserting the healthy entry is not reported.
2. **[Correctness]** — Step 1's single_project check must not use a bare `git -C <root> rev-parse` (the idiom in the same file's `adapter_repos`): it succeeds for any directory *inside* another repo, so a non-git hosting dir under the workspace checkout (or under a git sandbox, as in `test_precommit_hook_path.sh`'s `mk_ws`) would pass. Specify the check as `.git` present at the root (resolving symlinks, matching today's `path/.git` / `path.resolve()/.git` test) or `rev-parse --show-toplevel` equal to the resolved root, and cover the "plain dir inside a git repo" case in the test.
3. **[Consequences]** — The plan's consequences row says ARCHITECTURE.md does not describe `validate_workspace.py`; it does (L98-100: "`validate_workspace.py` understands both shapes: legacy `project/` (valid git repo with a remote) and registry entries (well-formed, known project type, checkout present)"). It is not wrong after the change but no longer describes how registry checkouts are checked; update it to say each registry entry's checkout shape is checked by its type's `adapter validate` verb. Add ARCHITECTURE.md to Files to Change.
4. **[Consequences]** — `validate_workspace.py`'s module docstring (L5-12, item 2 "Configured checkouts are valid git repos") goes stale under step 2; update it in the same change.
5. **[File targeting]** — Put the new `validate_workspace.py` registry-loop tests in `test_project_registry.sh` next to the existing `test_validate_*` cases, reusing `make_validate_sandbox`; its `make_sandbox` copies only `single_project`, so the ros2_colcon case must also copy `.agent/project_types/ros2_colcon`. Prefer a real minimal ros2_colcon checkout built with the fixture pattern in `test_ros2_colcon.sh` (validate verb tests ~L1323) over stubbing `adapter_validate`, so the test proves the real verb accepts a non-git root. Re-run the existing `test_validate_*` cases (registry-only, missing checkout, unknown type, parent root) — they now exercise the subprocess path and must still pass.
6. **[Approach — suggestion]** — Summarising with the first non-empty stderr line reports only the first of possibly several ros2_colcon issues (its last line is "Validation failed: N issue(s)."). Consider emitting every `❌` line, each prefixed `project '<name>':`, or appending the count, so `make validate` does not hide issues behind the first.
7. **[Behavior change — suggestion]** — After step 1, `adapter validate` with no `--project` on a registry-only machine (cwd not in a hosting dir → legacy resolution) now fails on the missing `project/` where it previously passed via the whole-workspace check. No in-repo caller runs it that way (`make validate` and `dashboard.sh` call `validate_workspace.py` directly; `session_start_project_layer.sh` L168 uses `--project`), but state the change in the PR description.

### Summary

The approach is right and follows ADR-0011, but the delegation interacts badly with registry parse errors (it would blame healthy projects), the single_project git check needs a precise spec to avoid a false pass for dirs nested in another repo, and two docs the plan says are unaffected (ARCHITECTURE.md L98-100, the validator's own docstring) need updates. Fix these before implementation.

### Recommended Actions

- [ ] Skip or short-circuit delegated shape checks when `projects.local` has parse errors, and test that a healthy entry is not blamed for another line's parse error
- [ ] Specify the single_project root check as `.git` at the root (symlink-resolved) or `--show-toplevel` equality, not bare `rev-parse`, and test a plain dir nested inside a git repo
- [ ] Add ARCHITECTURE.md L98-100 to Files to Change and correct the consequences row that says it does not describe `validate_workspace.py`
- [ ] Update `validate_workspace.py`'s module docstring (item 2) to match the delegated check
- [ ] Target `test_project_registry.sh` (reuse `make_validate_sandbox`; copy `ros2_colcon` into the sandbox) for the registry-loop tests, and confirm the existing `test_validate_*` cases still pass

## Checkpoint
**Status**: complete
**When**: 2026-09-23 10:16 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise, all 7 (Recommended): fix the five must-fix items from the Plan Review (registry parse errors must not be blamed on healthy entries; single_project root check requires .git at the root or show-toplevel equality, tested with a plain dir nested in a repo; ARCHITECTURE.md L98-100 in Files to Change; validate_workspace.py docstring item 2; tests in test_project_registry.sh reusing make_validate_sandbox, existing test_validate_* cases still pass) and adopt both suggestions (prefix every ❌ line with `project '<name>':` rather than the first stderr line; note the no-`--project` adapter validate behaviour change in the PR description).

## Plan Authored
**Status**: complete
**When**: 2026-09-23 10:21 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-330/plan.md` at `60caff4`

Revision addressing all 7 items from the Plan Review (five must-fix, two suggestions), per the owner's "revise, all 7" Checkpoint decision: guard delegated shape checks against registry parse errors so a malformed line no longer blames healthy projects; specify the single_project git check as `.git`-at-root (symlink-resolved), not bare `rev-parse --git-dir`, with a test for a non-git dir nested inside another repo; add ARCHITECTURE.md L98-100 and validate_workspace.py's own docstring to Files to Change; target test_project_registry.sh (reusing make_validate_sandbox, copying ros2_colcon into the sandbox) for the new tests and re-verify existing test_validate_* cases; emit every adapter failure line prefixed `project '<name>':` instead of just the first; and note the no-`--project` adapter-validate behavior change in the PR description.

## Plan Review
**Status**: complete
**When**: 2026-09-23 10:24 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: ready

**Issue**: #330 — validate: the global validator requires .git at every project root (fails ros2_colcon), and single_project validate checks the whole workspace
**Plan**: `.agent/work-plans/issue-330/plan.md` at `60caff4`
**Branch**: `feature/issue-330`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two defects + tests + three doc touch-points; ~5 files, one PR |
| Issue alignment | Good | Both defects addressed; Issue Review actions and both owner Checkpoints carried in |
| File targeting | Good | Tests now in `test_project_registry.sh` reusing `make_validate_sandbox` (verified L302-312; `make_sandbox` L58-68 copies `adapter` + `_project_registry.sh`, so the subprocess path works in-sandbox); ARCHITECTURE.md and the validator docstring added |
| Consequences | Good | ARCHITECTURE.md L98-100, docstring item 2, AGENTS.md L404 row, no-`--project` behavior change all captured; only other caller of `adapter ... validate` is `session_start_project_layer.sh` L168 (uses `--project`), `dashboard.sh` L188 calls the validator directly |
| Principle alignment | Good | Code + tests, minimal, no adapter audit |
| ADR compliance | Good | ADR-0011: shape check moves behind the `validate` verb; no verb-signature change, `validate_adapter.sh` unaffected |
| ROS conventions | N/A | Workspace plan |

### Prior findings (round 1) — verified against source

1. Registry parse errors blamed on healthy entries — **resolved**. Step 2 skips delegation when `registry_errors` is non-empty. Premise confirmed: `registry_lookup` returns 2 on any `registry_entries` failure (`_project_registry.sh` L310-312) and the dispatcher exits 1 for rc≠0 (`adapter` L179-191). Python/shell parser parity is already tested (`test_validate_python_parser_matches_shell`), so `registry_errors` non-empty tracks the shell rc=2 case. New test: malformed line + healthy entry.
2. Imprecise single_project git check — **resolved**. Step 1 specifies `.git` present at `adapter_project_root()`, symlink-resolved, explicitly not bare `rev-parse --git-dir`; test for a non-git dir nested in a repo.
3. ARCHITECTURE.md wrongly called unaffected — **resolved**. L98-100 quoted correctly and in Files to Change; consequences row corrected.
4. Validator docstring item 2 — **resolved**. Docstring (L5-12) in step 4 and Files to Change.
5. Test location — **resolved**. `test_project_registry.sh`, `make_validate_sandbox`, copy `ros2_colcon` into the sandbox, real fixture after `test_ros2_colcon.sh` L1325; all seven existing `test_validate_*` cases listed for re-run (checked: none use a stub type that would change meaning under delegation; `test_validate_parent_root` instances are `single_project` git repos and still pass).
6. Only the first stderr line reported (suggestion) — **resolved**. One `project '<name>': <line>` issue per non-empty stderr line, fixed fallback on empty stderr.
7. No-`--project` behavior change (suggestion) — **resolved**. Consequences row commits to noting it in the PR description.

### Findings

1. **[Approach — suggestion]** — Step 2 says what to do with the adapter's stderr but not its stdout. Capture it (`capture_output=True`) rather than letting `✅ ros2_colcon checkout matches the manifest.` / the single_project pass line print inline, since `make validate` runs `--verbose` (Makefile L126) and its output is the one-line-per-project report; on success keep printing the existing `project '<name>' (<ptype>): <path> OK` verbose line.
2. **[Tests — suggestion]** — The ros2_colcon fixture helpers (`make_colcon_project`, `populate_layer`, `write_repos_file`) live only in `test_ros2_colcon.sh`, not a shared lib, so the new registry test needs its own minimal inline fixture. It must declare a distro (e.g. `distro:` in `configs/manifest/bootstrap.yaml`), because `adapter_validate` counts an unresolvable distro as an issue (`ros2_colcon/adapter.sh` L575-577); a manifest with only layers would fail for the wrong reason.

### Summary

All seven round-1 items are resolved in the plan and hold up against source. The two new points are suggestions, not blockers. The plan is ready for implementation.

### Recommended Actions

- [ ] (suggestion) Capture the delegated adapter's stdout in `validate_workspace.py`; keep the existing verbose `OK` line as the success report
- [ ] (suggestion) Give the inline ros2_colcon registry-test fixture a resolvable distro so the passing case fails only for the reason under test

## Checkpoint
**Status**: complete
**When**: 2026-09-23 10:29 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed + both (Recommended): implement the plan at 60caff4, plus the round-2 Plan Review's two suggestions as instructions — (1) capture the adapter's stdout as well as stderr when validate_workspace.py delegates, so pass lines don't print inline; on success keep the existing `project '<name>' (<ptype>): <path> OK` verbose line; (2) the new ros2_colcon registry test fixture must declare a distro (e.g. `distro:` in configs/manifest/bootstrap.yaml) so it doesn't fail on an unresolvable distro.

## Implementation
**Status**: complete
**When**: 2026-09-23 10:39 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-330 at `ac562ff`

Implemented the plan at `60caff4` plus the owner's two round-2 instructions.

- `.agent/project_types/single_project/adapter.sh` — `adapter_validate` no longer execs the whole-workspace validator; it checks only `adapter_project_root()` for a `.git` at the root (symlink-resolved, not `git rev-parse`), `❌` lines to stderr, `✅` pass line to stdout. Messages name the path, not the project (the validator adds the prefix).
- `.agent/scripts/validate_workspace.py` — registry loop keeps the hosting-dir presence check, then delegates the shape check to `adapter --project <name> validate` (new `delegate_shape_check`), capturing stdout and stderr; each non-empty stderr line becomes `project '<name>': <line>`, empty stderr gives a fixed fallback with the exit code; success keeps the verbose `project '<name>' (<ptype>): <path> OK` line. Delegation is skipped when `projects.local` has parse errors (hosting-dir presence only) and for unknown types (no OK line printed for them either). Docstring item 2 updated.
- `.agent/scripts/tests/test_project_registry.sh` — 7 new tests (ros2_colcon entry with no `.git` passes, fixture declares `distro: fakefox`; failing ros2_colcon entry reports every adapter line prefixed; malformed line does not blame a healthy entry; nested non-git dir fails the whole-workspace check; scoped `--project` validate ignores broken siblings; scoped validate fails a non-git dir nested in a repo; legacy no-`--project` validate checks `project/` only) and an `assert_not_contains` helper. Existing `test_validate_*` cases unchanged and passing.
- `ARCHITECTURE.md`, `AGENTS.md` — describe per-type delegation and the `make validate` (whole workspace) vs `adapter --project <name> validate` (one project) split.

Tests: `run_script_tests.sh` — all 27 suites passed (registry suite 240/240). Against this machine's registry (worktree code in a scratch copy): whole-workspace validation passes with gz4d, p11-jazzy and p11-rolling OK; `adapter --project gz4d validate` passes. Pre-change main code fails both on p11-jazzy/p11-rolling "is not a git repository".

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-23 10:45 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-330 at `d58c7da`
**Base**: main
**Depth**: Deep (reason: 662 changed lines, ~240 outside work-plans; AGENTS.md governance file)
**Must-fix**: 0 | **Suggestions**: 3
**Round**: 1 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Specialists: static (pre-commit shellcheck/black/flake8/pylint clean), governance, plan drift, Claude adversarial, cross-model (gemini: 5 findings, 2 kept as suggestions, 1 downgraded, 2 dropped; codex: no issues). All 27 script suites pass (registry 240/240). Real registry: gz4d and p11-rolling pass; `adapter --project gz4d validate` passes; p11-jazzy fails in the worktree only because the gitignored `.agent/projects.d/p11-jazzy.sh` (its ROS_DISTRO) is absent there — it passes from the main checkout.

Beyond-plan calls: (a) unknown-type entries no longer print the verbose OK line — accepted; the old line printed OK next to an "unknown project type" error, which was wrong. (b) unknown-type entries get no `.git` check — accepted; an unknown type has no known shape to check, the entry already fails, and the code comment says so. Hosting-dir-missing is still reported for them.

Dropped: CDPATH stdout on `cd` in single_project adapter_validate (root is always absolute, so CDPATH never applies); empty `.git` directory passes (deliberate parity with the validator's existing presence test, per plan step 1).

### Findings
- [ ] (suggestion) Under registry parse errors, the verbose line still says `OK` though only hosting-dir presence was checked; say so (e.g. "hosting dir present; shape not checked — registry has parse errors") — `.agent/scripts/validate_workspace.py:173`
- [ ] (suggestion) `delegate_shape_check` has no `timeout=`; bound it and report "adapter validate timed out" on `TimeoutExpired` so a future adapter cannot hang `make validate` — `.agent/scripts/validate_workspace.py:67`
- [ ] (suggestion) On non-zero exit with empty stderr, fall back to the adapter's stdout lines (prefixed) before the generic "exited N" message — `.agent/scripts/validate_workspace.py:78`
