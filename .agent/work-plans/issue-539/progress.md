---
issue: 539
---

# Issue #539 — test_ros2_colcon.sh expects the manifest tool's old sync report; CI skips that case and reports 0 skipped

## Issue Review
**Status**: complete
**When**: 2026-11-20 12:16 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #539

### Scope Assessment

**Well-scoped?** Yes. Three small items; the issue already splits them into two pull requests (item 1 alone, then items 2 and 3), as the owner chose on 2026-11-20.
**Right repo?** Yes. The test, the workflow and the suite's summary line are all workspace files.
**Serves**: Quality of the work, and "A safeguard has to earn its cost" (a test that is skipped on CI and reported as `0 skipped` guards nothing) — `docs/design.md#merge-gate`
**Design picture?** No change.
**Dependencies**: none blocking. Item 1 should land before the publish of #428 part 1 (owner's order).

Claims checked against this branch:

1. Stale expected text: confirmed. `.agent/scripts/tests/test_ros2_colcon.sh:5065` asserts `present, not touched (2)`. `report()` in `tools/repos-manifest/src/repos_manifest/sync.py:626` prints `up to date (<n>)` for the `CURRENT` outcome (line 644); no line in `sync.py` prints "present, not touched". The test's needle is stale; the tool is right. The test runs on this machine (`vcs` is at `/usr/bin/vcs`), so it fails here too.
2. CI skips the case: confirmed. `.github/workflows/validate.yml` installs `repos-manifest` (`pip install -e tools/repos-manifest`) but nothing installs `vcs`, then runs the suite at the "Run ros2_colcon adapter tests" step. The skip is at test line 5026.
3. Skip not in the summary count: confirmed. The skip increments `TOOL_SKIPPED` (line 5027), which only prints a separate `=== SKIPPED: the real-tool test ... ===` line (5218-5220). The final line (5226) prints `${MR_SKIPPED} skipped` only, so `TOOL_SKIPPED` never reaches the number.

Other stale strings: none. The two other occurrences, lines 4193 and 4424, are the text of the suite's own stub of `repos-manifest` (the stub at 4185-4196 does `echo "distro stub: present, not touched"`), and line 4424 only checks that the adapter passes the tool's output through. They do not depend on the real `report()` and stay correct. No other line in the suite contains "present, not touched". I did not run the other real-tool assertions around line 5065 (not part of this review) and did not run the suite.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| A safeguard has to earn its cost | Action needed | Item 2 is the real fix (`vcs` on the runner so the case runs on every pull request); item 3 alone only makes the skip visible. Keep both. |
| Verify before claiming | Watch | The issue's "Checks" are testable as written; the third (`vcs` off PATH shows the skip in the summary line) needs the count change, and should be run with PATH edited, not assumed. |
| Atomic commits / small pull requests | OK | Item 1 as its own pull request matches the owner's order. |
| Keep one current design | OK | No design section changes. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0011 (project-type adapters) | Watch | The test covers the ros2_colcon adapter; no adapter contract change. |
| Other ADRs | No | No ADR-level decision involved. |

### Consequences

- Changing `.github/workflows/validate.yml` is a CI change, which AGENTS.md lists as Ask First: the owner's approval of this issue covers the intent; the plan should say so, and the pull request should name the workflow change.
- Item 3 changes the meaning of the summary line's `skipped` number; check whether anything parses it (grep for `skipped` consumers of this suite's output, e.g. the pre-commit suite hook) before changing it.
- If `vcs` is added to CI, pin how it is installed (`pip install vcstool` in the existing Python 3.10 job or apt) and confirm the job time stays acceptable.

### Recommendations

- Part 1 (own pull request, to main first): change the expected text at line 5065 to `up to date (2)`, nothing else; run the suite here with `vcs` present and confirm the real-tool case runs and passes.
- Part 2: install `vcs` in the `validate.yml` job that runs this suite, and add `TOOL_SKIPPED` to the count in the final `Results` line (`MR_SKIPPED + TOOL_SKIPPED`), with the test run once with `vcs` off PATH to show the skip in the summary.
- Part 2 should also decide whether a missing `vcs` in CI should fail rather than skip (as line 2317 does for the resolver "where it is meant to run"); this is a mechanism choice, to be listed in the plan, not a question for the owner.

### Actions
- [ ] Item 2 is the real fix (`vcs` on the runner so the case runs on every pull request); item 3 alone only makes the skip visible. Keep both.
- [ ] Part 1 (own pull request, to main first): change the expected text at line 5065 to `up to date (2)`, nothing else; run the suite here with `vcs` present and confirm the real-tool case runs and passes.
- [ ] Part 2: install `vcs` in the `validate.yml` job that runs this suite, and add `TOOL_SKIPPED` to the count in the final `Results` line (`MR_SKIPPED + TOOL_SKIPPED`), with the test run once with `vcs` off PATH to show the skip in the summary.
- [ ] Part 2 should also decide whether a missing `vcs` in CI should fail rather than skip (as line 2317 does for the resolver "where it is meant to run"); this is a mechanism choice, to be listed in the plan, not a question for the owner.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:16 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review confirms all three items against the code and raises no scope question; its actions are points for the plan)
**After**: issue-actions
**Decision**: proceed

Read: the Issue Review at 2665c097. Its actions go into the plan: part 1 is the one expected string at test line 5065; part 2 is the CI install of vcs and the skip count, and the plan says whether a missing vcs in CI fails the job and whether anything parses the summary line. The CI workflow change in part 2 is on the Ask First list; the owner approved the issue's three items on 2026-11-20 ("Issue + fix main first (Recommended)"), and the part 2 pull request names the workflow change for his merge decision.

## Plan Authored
**Status**: complete
**When**: 2026-11-20 12:17 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-539/plan.md` at `38fcf8de`

Two parts. Part 1: the one expected string becomes the tool's "up to date (2)", verified by running the suite here with vcs present. Part 2: CI installs vcstool 0.3.0 by pip, a missing vcs fails where CI is set, and the Results line counts the real-tool skip (no parser of it found); the workflow change is Ask First and named in the part 2 pull request.

## Plan Review
**Status**: complete
**When**: 2026-11-20 12:21 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #539 — test_ros2_colcon.sh expects the manifest tool's old sync report; CI skips that case and reports 0 skipped
**Plan**: `.agent/work-plans/issue-539/plan.md` at `38fcf8de`
**Branch**: `feature/issue-539`

Part 1 is ready as written and can merge alone. Part 2 needs two changes before it is implemented (findings 1 and 2).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two pull requests on one issue; part 1 is one string, part 2 one workflow step and a suite change. |
| Issue alignment | Good | Covers the issue's three items and the Issue Review's actions. Serves: "Quality of the work, and "A safeguard has to earn its cost": `docs/design.md#merge-gate`" — the goal is under `README.md#quality-of-the-work` (line 37 holds the safeguard bullet) and `docs/design.md#merge-gate` exists (line 844). |
| File targeting | Needs work | Part 2 names `validate.yml`'s `validate-adapter-contract` job only; the suite also runs with `CI` set in the `validate-scripts` (Lint) job (finding 1). |
| Consequences | Concern | The consequence "a missing vcs fails where CI is set" reaches the Lint job, which is not in the table (finding 1). The skipped-count consumer check holds: nothing parses it. |
| Principle alignment | Needs work | "Look for prior art": the workflow already installs `vcs2l` (repos-manifest's `[test]` extra) and gates on an explicit `REPOS_MANIFEST_REQUIRE_COLCON`; neither is named (findings 2, 4). "Test what breaks": step 6's test is optional though a cheap pattern exists (finding 3). |
| ADR compliance | Good | ADR-0011 not triggered (no adapter contract change). No other ADR is triggered. |
| ROS conventions | N/A | Workspace plan. |

### Checks run

- Part 1, by reading: `report()` (`tools/repos-manifest/src/repos_manifest/sync.py:626`) prints `up to date (<n>)` for CURRENT; `_Turn.current()` in `update.py` returns CURRENT when the clone is already on the manifest's version, which is the state `init` leaves both repos in with unchanged remotes.
- Part 1, by running: `bash .agent/scripts/tests/test_ros2_colcon.sh` on this branch, unmodified (`vcs` 0.3.0 at `/usr/bin/vcs`), 2m27s: `1374 passed, 1 failed, 0 skipped`, exit 1. The one failure is `adapter sync: the tool's own report`, and its haystack is exactly `distro fakefox:` then `  up to date (2)`: no `updated` line. Every other assertion of the real-tool test passes (validate, repo_pin, setup's `cloned (1)`, the clone on its pin). So the plan's needle is right and is the only change part 1 needs.
- `vcstool==0.3.0` exists on PyPI (latest; pure-python `py3-none-any` wheel; `Requires-Dist: PyYAML, setuptools`, unpinned).
- In a fresh venv (Python 3.12, which pulled setuptools 84.2.1): `pip install vcstool==0.3.0` then `vcs --version` crashes with `ModuleNotFoundError: No module named 'pkg_resources'` (`vcstool/commands/help.py:4`, imported by every `vcs` command). Not run on Python 3.10.
- In a fresh venv: `pip install "vcs2l>=1.1.7"` gave vcs2l 1.1.7, which installs a `vcs` command; `vcs --version` printed `vcs 1.1.7`, exit 0, with no setuptools installed.
- `ls .agent/scripts/ | grep -i test` gives `tests` and `test.sh`. The runner exists at `.agent/scripts/tests/run_script_tests.sh` and globs every `tests/test_*.sh` (line 350). It is the entry of the pre-commit hook `validate-script-tests`. It has no skipped-count parsing (`grep -i "skip\|Results:"` finds only comments about SKIP=). No other file parses a `skipped` number.
- `make lint` = `pre-commit run --all-files` (Makefile line 123); the `validate-scripts` job runs it on CI, and the hook comment says CI therefore "runs every suite". That job does not install `vcs`.

### Findings

1. **[Consequences / must-fix]** Step 4 (missing `vcs` FAILs when `CI` is set) would make the Lint (pre-commit) job fail on every push. That job runs `make lint`; the `validate-script-tests` hook runs `run_script_tests.sh`, which runs `test_ros2_colcon.sh` with `CI=true` and no `vcs` on PATH. Today the real-tool case skips there; after step 4 it fails. The plan must take one of two routes: install `vcs` in the `validate-scripts` job too, or gate the failure on an explicit variable set only on the adapter-contract step (as `REPOS_MANIFEST_REQUIRE_COLCON: '1'` is gated in this same workflow). That choice is a mechanism decision; list it for veto. Either route keeps the skip counted in the summary line (step 5).
2. **[Principle alignment, prior art / must-fix]** `pip install vcstool==0.3.0` does not pin what the plan says it pins. vcstool 0.3.0 imports `pkg_resources` in every `vcs` command, and current setuptools (84.2.1 here) no longer has it: `vcs --version` crashes in a fresh venv. Whether CI's Python 3.10 works depends on the setuptools that the runner image ships, which is the drift the pin was meant to stop. Use `vcs2l` instead, pinned (for example `vcs2l==1.1.7`). It is the successor of vcstool, it provides the same `vcs` command, `sync.py:81` already names it, and it is already in `tools/repos-manifest`'s `[test]` extra, so the `validate-repos-manifest` job installs it. `pip install -e tools/repos-manifest[test]` in place of the current install line would also work. Keep the `vcs --version` check.
3. **[Principle alignment, test what breaks / suggestion]** Step 6 makes the (b)/(c) test conditional on a stub PATH "if it can be made cheaply". It can: `test_setup_requires_vcs` (suite line 1120) already builds an isolated PATH with no `vcs`. Make the test required, covering `CI` (or the chosen variable) unset → counted skip, and set → FAIL.
4. **[Prior art / suggestion]** The Prior Art section should name what is reused: the `REPOS_MANIFEST_REQUIRE_COLCON` gate and the `vcs2l` install already in `validate.yml`, besides the resolver rule at suite line 2317.
5. **[Split / note]** Part 1 can merge alone. It touches one assertion. On CI that test skips today (no `vcs`), so part 1 changes nothing there, and here it turns the one failure into a pass. Part 2 touches neither part 1's line nor anything part 1 needs.

### Summary

Part 1 is right and its check is real: the tool prints `up to date (2)` and nothing else for this setup, confirmed by a run of the suite. Part 2 needs work before it is implemented. As written, it would break the Lint job, and it installs a `vcs` that crashes under current setuptools. Both have simple fixes already in this workflow: an explicit require-variable, or `vcs` in both jobs, and `vcs2l`.

### Recommended Actions

- [ ] Part 1: implement as planned (no change).
- [ ] Part 2: pick and list for veto how the Lint job is handled: install `vcs` there too, or fail only under an explicit variable set on the adapter-contract step.
- [ ] Part 2: install `vcs2l` (pinned), not `vcstool==0.3.0`, and keep `vcs --version`.
- [ ] Part 2: add the isolated-PATH test for skip vs fail, modelled on `test_setup_requires_vcs`.
- [ ] Part 2: name the reused prior art (`REPOS_MANIFEST_REQUIRE_COLCON`, `vcs2l` in the `[test]` extra) in the plan or the pull request.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:22 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review finds part 1 ready as written and able to merge alone; both must-fix items are in part 2, which is not implemented under this answer)
**After**: plan
**Decision**: proceed

Read: the Plan Review at d68975b2, verdict needs-work. Part 1 (the one expected string) is ready: the reviewer ran the suite and the tool prints "up to date (2)" for this setup. This proceed covers part 1 only; the implement handoff says so. Part 2 is not implemented as planned: its two must-fix items (failing on a missing vcs whenever CI is set would break the Lint job, which runs every suite with CI=true and no vcs; pip install vcstool==0.3.0 depends on an unpinned setuptools and crashed in a fresh venv, use the pinned vcs2l the repos-manifest job already installs) and its suggestions go back to the plan at the plan checkpoint raised after part 1's merge, which the host answers revise. The owner asked for the test fix on main first (2026-11-20: "Issue + fix main first (Recommended)").

## Implementation
**Status**: complete
**When**: 2026-11-20 12:25 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-539 at `1164e166`

- Part 1 only: `.agent/scripts/tests/test_ros2_colcon.sh` assertion "adapter sync: the tool's own report" now expects `up to date (2)` (was `present, not touched (2)`). No other line or file changed; part 2 (CI workflow, fail-in-CI rule, skip count) not implemented, its plan is being revised.
- Ran `bash .agent/scripts/tests/test_ros2_colcon.sh` on its own: `=== Results: 1375 passed, 0 failed, 0 skipped ===`. The real-tool case ran (no `SKIPPED: vcs` line; the assertion passed).
- Committed with `SKIP=validate-script-tests` per the issue-465 interim rule; the full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 12:26 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-539 at `5ce19ed8`
**Base**: origin/main
**Depth**: Light (reason: 1 file, +1 -1 outside work-plans; no override-trigger files)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 1 | **Ship**: recommended — no must-fix findings

Static analysis: shellcheck --severity=warning on `.agent/scripts/tests/test_ros2_colcon.sh` clean (workspace .venv shellcheck). The new needle `up to date (2)` checked against `report()` in `tools/repos-manifest/src/repos_manifest/sync.py` (prints `up to date (<n>)` for the CURRENT outcome; both fixture repos, pkg_u and pkg_a, are current after init). Part 2 (CI installs vcs, skip count) is out of scope for this pull request per the plan. Cross-model: not dispatched (Light tier).

### Findings
- [ ] No issues found. LGTM.
