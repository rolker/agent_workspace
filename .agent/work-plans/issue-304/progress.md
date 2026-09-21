---
issue: 304
---

# Issue #304 — run_script_tests.sh: per-run TMPDIR guard that fails the run on a leaked sandbox (#297 PR 2)

## Issue Review
**Status**: complete
**When**: 2026-09-21 12:09 -0400
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #304

### Scope Assessment

**Well-scoped?** Yes, with one discrepancy (see Recommendations). The issue is a single, mechanical PR: extend `run_script_tests.sh` with a per-run `TMPDIR` guard, add its test coverage, document the guard in `AGENTS.md`, and write up the one-time cleanup note. All items are independently verifiable and fit one PR.

**Right repo?** Yes — `agent_workspace`. This is workspace test-infrastructure (`.agent/scripts/tests/`), matching the plan's own repo and the parent issue #297.

**Dependencies**: PR 1 (#303, "converted every suite onto one top-level sandbox + EXIT trap") is merged to `main` (commit `805d7a3`), and this branch (`feature/issue-304`) already has that merge as an ancestor. No absolute-`/tmp` `mktemp` templates remain under `.agent/scripts/tests/` (verified: `grep -rn "mktemp.*-d */tmp/\|mktemp */tmp/" .agent/scripts/tests/*.sh` returns nothing) — PR 1's normalisation of all ten sites landed as planned. Dependency is satisfied; no other open issue blocks this one.

### Scope-vs-Plan Comparison (plan PR 2, `.agent/work-plans/issue-297/plan.md`, three-round-reviewed)

| Plan PR 2 item | In issue #304? |
|---|---|
| Per-run `TMPDIR` via `mktemp -d /tmp/run-script-tests.XXXXXX`, never derived from `[tests-dir]`, exported for every suite | Yes |
| Sweep inside the per-suite loop, attribute leak to the suite, distinct exit code, unconditional `rm -rf` on exit | Yes |
| `test_run_script_tests.sh`: leak fixture fails with suite named, clean fixture still passes, existing fail-fast cases hold | Yes |
| Update the runner's "Exit codes:" header (current lines 26–27) | Yes |
| `AGENTS.md` Script Reference row for `run_script_tests.sh` mentions the guard | Yes (confirmed missing today) |
| Document (not automate) the one-time `/tmp/tmp.*` cleanup, `.git`-presence filter caveat, age-based alternative | Yes |
| Two suggestions carried from PR 1's review (`test_merge_pr_root_resolution.sh` rev-parse self-check; `test_block_bash_tool_mapping.sh` `TMP_HOME` naming) | Yes — both confirmed in `progress.md` as explicitly deferred to PR 2 by owner checkpoint (lines 554–555), not new scope |
| **"Lint for absolute `/tmp/` mktemp templates under `.agent/scripts/tests/`"** | **Present in issue, not in the approved plan** — see Recommendations |

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | OK | The guard is the enforcement layer the parent issue asked for; failing the run (not just warning) matches the principle |
| A change includes its consequences | OK | `AGENTS.md` row and `test_run_script_tests.sh` coverage are both explicitly in scope |
| Only what's needed | Watch | The lint item adds a check with no live target — every current suite is already normalised — worth confirming its purpose before implementing |
| Improve incrementally | OK | Single, reviewable PR; no design decisions left open (plan review already converged) |
| Test what breaks | OK | Both the leak-failure path and the clean-pass path get fixture coverage per the plan |
| Human control and transparency | OK | Cleanup is documented, not automated, per plan and per the parent issue's principle note |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0011 (adapter contract) | No | `run_script_tests.sh` is the script-test runner, not `TEST_CMD`/`adapter test` — same correction the Issue Review made on #297, still holds here |
| ADR-0013 (`progress.md` entry-type vocabulary) | Yes, for this review's own persistence and later `## Plan Authored`/`## Implementation` entries | No action needed now; applies to subsequent phases |

### Consequences

- None beyond what's already listed in the issue (`AGENTS.md` row, `test_run_script_tests.sh` coverage, exit-codes header). No other script or doc references `run_script_tests.sh`'s exit codes that would need updating.

### Recommendations

- Resolve the "lint for absolute `/tmp/` mktemp templates" bullet before implementing. It traces to Plan Review round-1 finding 4, which offered two alternatives — normalise the five suites' `mktemp` calls, or have the guard lint for the literal-`/tmp/`-template pattern — and the plan's final, approved text (Approach step 7, Files to Change) resolved that finding by choosing **normalisation only**, executed in PR 1 (confirmed merged, confirmed no absolute templates remain). The plan's PR 2 section does not describe a lint check anywhere. The issue's "per plan" attribution for this bullet is not accurate as the plan currently reads. Either: (a) drop the bullet, since normalisation already closes the gap the lint would catch, or (b) keep it as a deliberate regression guard against a *future* suite reintroducing an absolute template, and say so explicitly in the PR description rather than citing it as already-approved plan scope.

### Actions
- [ ] Resolve the "lint for absolute `/tmp/` mktemp templates" bullet before implementing. It traces to Plan Review round-1 finding 4, which offered two alternatives — normalise the five suites' `mktemp` calls, or have the guard lint for the literal-`/tmp/`-template pattern — and the plan's final, approved text (Approach step 7, Files to Change) resolved that finding by choosing normalisation only, executed in PR 1 (confirmed merged, confirmed no absolute templates remain). The plan's PR 2 section does not describe a lint check anywhere. The issue's "per plan" attribution for this bullet is not accurate as the plan currently reads. Either: (a) drop the bullet, since normalisation already closes the gap the lint would catch, or (b) keep it as a deliberate regression guard against a future suite reintroducing an absolute template, and say so explicitly in the PR description rather than citing it as already-approved plan scope.
