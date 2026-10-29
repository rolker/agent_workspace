---
issue: 410
---

# Issue #410 — Pre-commit script-test hook: run only the suites whose declared files changed

## Issue Review
**Status**: complete
**When**: 2026-10-29 08:13 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #410

### Scope Assessment

**Well-scoped?** Mostly. One PR can carry it, but the issue's premise is off (see Recommendations): the existing declaration covers only 5 of 39 suites and says which out-of-tree prefixes a suite reads, not which script it tests. The scoping map has to be built, not just reused.
**Right repo?** Yes. Hook, runner and tests are workspace infrastructure.
**Serves**: Quality of the work (and wall-clock of the review loop) — `docs/design.md#rules` (hook rows) and `docs/design.md#review-loop-and-timeline`
**Design picture?** No change, provided the backstop stays: the Rules table says the Lint job runs every hook on all files. Narrowing CI would change that row and is a separate decision (the issue already says so).
**Dependencies**: none blocking. Related #399 (SKIP rule, whose wording may need a touch), #384.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforce what matters, as simply as possible | Action needed | A suite-to-file map risks drifting (a suite starts reading a new file and the hook silently skips it). The map needs an enforced check, like the existing scope test, and the safe default for an undeclared or unmapped suite must be "run it". |
| Verify before claiming | Watch | The "under a minute for a typical fix commit" acceptance needs a measured typical case (which suites a commit to one script triggers), not an estimate. |
| Only what's needed | Watch | Keep to the hook; CI narrowing stays out of scope as the issue says. |
| Keep one current design | OK | No design change; the Rules row on CI running all hooks stays true. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (progress timeline) | No | The progress.md vocabulary suites keep their own triggers. |
| ADR-0011 (adapter) | No | Not touched. |

### Consequences

- Update the header comments in `run_script_tests.sh` and the `.pre-commit-config.yaml` comment block, plus the #399 wording ("final no-SKIP run over `git diff --name-only main...HEAD`"), so they describe scoped behaviour.
- `test_run_script_tests.sh` and `test_script_tests_hook_scope.sh` need new cases for the scoped mode and the full-run triggers.
- The hook uses `pass_filenames: false`; the runner must now receive the changed files (or the hook must pass them) and keep the full run when invoked with none (`make lint`, CI `--all-files`).

### Recommendations

- Correct the premise in the plan: `test_script_tests_hook_scope.sh` declares only 5 `ROOT_READERS` entries (suites that derive a real repo root) and lists out-of-tree prefixes read, not the script under test. Say how the suite-to-file map is made (a new declaration per suite, or derived from the suite name and its `SCRIPT_DIR` references) and how a missing entry is caught.
- Make the fail-safe explicit: a changed file that maps to no suite, a suite with no entry, or a runner/shared-helper/hook-config change runs everything.
- List the shared helpers every suite sources, and test that a change to each triggers the full run.
- State the measured timing for one or two typical fix commits in the plan, and confirm `make lint` / CI `--all-files` still runs all 39.

### Actions
- [ ] A suite-to-file map risks drifting (a suite starts reading a new file and the hook silently skips it). The map needs an enforced check, like the existing scope test, and the safe default for an undeclared or unmapped suite must be "run it".
- [ ] Correct the premise in the plan: `test_script_tests_hook_scope.sh` declares only 5 `ROOT_READERS` entries (suites that derive a real repo root) and lists out-of-tree prefixes read, not the script under test. Say how the suite-to-file map is made (a new declaration per suite, or derived from the suite name and its `SCRIPT_DIR` references) and how a missing entry is caught.
- [ ] Make the fail-safe explicit: a changed file that maps to no suite, a suite with no entry, or a runner/shared-helper/hook-config change runs everything.
- [ ] List the shared helpers every suite sources, and test that a change to each triggers the full run.
- [ ] State the measured timing for one or two typical fix commits in the plan, and confirm `make lint` / CI `--all-files` still runs all 39.

## Checkpoint
**Status**: complete
**When**: 2026-10-29 08:13 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (all five open Actions are plan-level requirements: how the suite-to-file map is built, its enforced drift check, the run-everything fail-safe, the shared-helper list and measured timing; none changes what the issue is for or its scope, so /orchestrator's table lets the host answer proceed)
**After**: issue-actions
**Decision**: proceed

The Issue Review found the issue well-scoped and in the right repository, with one premise to correct: `test_script_tests_hook_scope.sh` declares only 5 ROOT_READERS entries (out-of-tree prefixes read), not a suite-to-file map, so the map has to be built. All five Actions are carried into the plan-task handoff as plan requirements.
