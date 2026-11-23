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

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:29 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the pre-push review approved with no findings and the host's full pass passed)
**After**: publish
**Decision**: publish

Read: the Local Review (Pre-Push) at aa28588b, round 1, approved, Ship recommended, no must-fix and no suggestions. The host's full pass (pre-commit over the branch's files against origin/main, no SKIP) passed on this head: every hook Passed or had no files, the script test suites hook included. Part 1 of two: the pull request says Part of #539.

## Integrated Review
**Status**: complete
**When**: 2026-11-20 12:46 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #540 at `2d18390`
**Sources**: 2 (Local Review (Pre-Push) @ `5ce19ed8` (covers `2d18390` via bookkeeping), CI rollup @ `2d18390`)
**Cross-source confirmations**: 0
**CI**: all-pass

No hosted review and no conversation comment on the pull request (fetch_pr_reviews.sh: 0 reviews, 0 comments at `2d18390`). The only review source is the pre-push local review, approved with no findings; the head has moved past it only by the `## Local Review (Pre-Push)` and `## Checkpoint` record commits (`git diff 5ce19ed8..2d18390` touches only this issue's progress.md; `review_progress.sh sources`: no local findings, no dropped entries). Re-checked the one changed line: `report()` in `tools/repos-manifest/src/repos_manifest/sync.py` line 644 prints `up to date (<n>)`, and the remaining `present, not touched` strings in `.agent/scripts/tests/test_ros2_colcon.sh` (lines 4193, 4424) are a distro stub's own echo, not the manifest tool's report, so they correctly stay. CI at `2d18390`: Lint (pre-commit), Validate Adapter Contract, Validate Documentation, repos-manifest tests on Python 3.10 and 3.14 — all success (each listed twice, push and pull_request runs).

### Findings
None open.

### False positives
None.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:52 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

The owner's answer in the dialog, to "Merge pull request 540?": "Merge (Recommended)". The dialog showed: the one changed line; the suite at 1375 passed, 0 failed, 0 skipped with the real-tool case run; the host's full pass before the push; the approved pre-push review and the Integrated Review at 66966fb8 with no open findings; CI all-pass, with the note that CI still skips the changed case until part 2; no hosted review in 900 s, Gemini and Codex skipped at Light depth. The host fetched the pull request again before asking: no reviews, no comments, no failed check. Part 1 of two: the issue stays open for part 2.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 09:59 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: revise

The owner's answer in the dialog, to "How should part 2 be revised?": "Revise, whole part 2 (Recommended)". The dialog showed: part 1 merged as pull request 540; part 2 of the plan is not delivered and cannot be implemented as written, by the Plan Review of 2026-11-20 (needs-work). F1, must-fix: failing on a missing vcs whenever CI is set would break the Lint job; fix by an explicit require-variable set only on the adapter-contract step, as REPOS_MANIFEST_REQUIRE_COLCON is, or by installing vcs in the Lint job too. F2, must-fix: pip install vcstool==0.3.0 does not pin what the plan says and crashed in a fresh venv; use the pinned vcs2l. F3, scope: the skip count stays in part 2 (it had been proposed earlier the same day to hold it for issue 550; the owner chose to keep it, so this pull request closes the issue). Part 2 changes a CI workflow (Ask First); this answer covers planning it and the merge decision covers the change.

## Plan Authored
**Status**: complete
**When**: 2026-11-23 10:01 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-539/plan.md` at `1e47af35`

Revision of part 2 (part 1 is delivered as pull request 540). CI installs `vcs2l==1.1.7` in the adapter-contract job; a missing vcs fails only where `ROS2_COLCON_TESTS_REQUIRE_VCS` is set (that step), so the Lint job, which has no vcs, still skips; the Results line counts the skip; a required isolated-PATH test covers skip versus fail. Mechanism choices are listed for the owner's veto; the part 2 pull request says Closes #539.

## Plan Review
**Status**: complete
**When**: 2026-11-23 10:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #539 — test_ros2_colcon.sh expects the manifest tool's old sync report; CI skips that case and reports 0 skipped
**Plan**: `.agent/work-plans/issue-539/plan.md` at `1e47af35`
**Branch**: `feature/issue-539`

Review of the revised part 2 (part 1 is delivered as pull request 540). Both must-fix findings of the 2026-11-20 review are answered, and the revision follows the owner's checkpoint of 2026-11-23 (whole part 2 revised, skip count kept, so the pull request closes #539). Two points for the implementer (findings 1 and 2), neither a reason to send the plan back.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One workflow job (one install step, one env line), the suite's real-tool function, its summary line and one new test. |
| Issue alignment | Good | Covers items 2 and 3 of the issue and the earlier review's findings: F1 by `ROS2_COLCON_TESTS_REQUIRE_VCS` on the adapter-contract step only; F2 by `vcs2l==1.1.7`; suggestion 3 made required (step 5); suggestion 4 in Prior Art. Serves: "Quality of the work, and "A safeguard has to earn its cost": `docs/design.md#merge-gate`" (README.md line 33/37, design.md line 844: both exist). |
| File targeting | Good | `.github/workflows/validate.yml` and `.agent/scripts/tests/test_ros2_colcon.sh`. The Lint job is now handled by not setting the variable there. |
| Consequences | Good | Lint (CI set, no vcs) keeps the counted skip; no parser of the `skipped` number (re-grepped). One CI interaction in the new test is not spelled out (finding 1). |
| Principle alignment | Good | Test what breaks: required skip-vs-fail test with a mutation check (6b). Prior art named. Ask First for the workflow change is addressed. |
| ADR compliance | Good | ADR-0011 not triggered; no other ADR triggered. |
| ROS conventions | N/A | Workspace plan. |

### Checks run

- Fresh venv (Python 3.14.4): `pip install vcs2l==1.1.7` gave vcs2l 1.1.7 and PyYAML 6.0.4, no setuptools; `vcs --version` printed `vcs 1.1.7`, exit 0. `Requires-Python: >=3.6`, so CI's 3.10 is covered. `pip index versions vcs2l`: newest is 1.1.7. `tools/repos-manifest/pyproject.toml` `[test]` holds `vcs2l>=1.1.7`.
- Full suite with vcs2l's `vcs` first on PATH (system vcs is vcstool 0.3.0): `bash .agent/scripts/tests/test_ros2_colcon.sh` → `1375 passed, 0 failed, 0 skipped`, exit 0, 1m39s; the `TEST: tool route with the real tool and vcs` case ran and passed (no `SKIPPED` line in the log). So CI's planned `vcs` works with the real tool, not only `--version`.
- Isolated-PATH feasibility: extracted `test_tool_real_init_and_sync` and ran it under `set -euo pipefail` in a subshell with `PATH` set to an empty directory: it printed the `TEST:` and `SKIPPED: vcs is not on PATH` lines and `TOOL_SKIPPED=1 FAIL=0`, exit 0. `command -v` and `echo` are builtins; the function needs no external tool before it returns, so the "isolated bin" can be empty.
- `validate.yml`: the Lint job runs `make lint` (= `pre-commit run --all-files`); the `validate-script-tests` hook runs every suite through `run_script_tests.sh`, with `CI` set and no vcs. The adapter-contract job installs `repos-manifest` without extras and runs this suite as its last step, no vcs. `grep skipped` over `run_script_tests.sh`, `test.sh`, `Makefile`, `.pre-commit-config.yaml`, `.github/workflows/` finds only prose.

### Findings

1. **[Consequences / should-fix in implementation]** Step 5 case (a) "variable unset" must unset it explicitly (`unset ROS2_COLCON_TESTS_REQUIRE_VCS` or `env -u`) inside the subshell, and case (b) set it there. The new test runs inside the very adapter-contract step that step 2 sets `ROS2_COLCON_TESTS_REQUIRE_VCS=1` on, so a subshell that only overrides `PATH` inherits the variable: case (a) would get `FAIL=1` on CI while passing locally and in Lint.
2. **[Approach / note]** Step 3 says what to print and count when required but not that the function then returns; it must `return 0` after the FAIL as the skip branch does, or it goes on into the real-tool steps without `vcs`.
3. **[Prior art / note]** The `==1.1.7` pin in the workflow and the `>=1.1.7` floor in the `[test]` extra are two places to keep in step; the plan's own argument against a second install in Lint applies to this pin too. Acceptable as listed for veto; a comment on the step naming the extra would keep them findable.
4. **[Note]** Step 5's "isolated bin directory holding only the tools the function needs" can be an empty directory (checked above); no symlinks are needed, unlike `test_setup_requires_vcs`.

### Summary

The revision answers both must-fix findings with the mechanisms the earlier review suggested and lists them for veto; `vcs2l==1.1.7` was checked to install, run and pass the real-tool case. Ready for implementation, with the explicit unset in the new test's case (a) and the `return` after the FAIL carried into the code.

### Recommended Actions

- [ ] In the new test, unset `ROS2_COLCON_TESTS_REQUIRE_VCS` in case (a)'s subshell and set it in case (b)'s, so the test passes inside the adapter-contract step that sets it.
- [ ] In `test_tool_real_init_and_sync`, return after the required-vcs FAIL.
- [ ] Optionally note on the workflow step that the pin follows the `[test]` extra's floor.

## Checkpoint
**Status**: complete
**When**: 2026-11-23 10:05 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

The owner's answer in the dialog, to "Implement part 2 as planned, with F1 to F3 passed to the implementer?": "Proceed (Recommended)". The dialog showed the Plan Review at 7db5a37c (verdict ready) and part 2 as planned, including that it changes .github/workflows/validate.yml (Ask First). F1, should-fix during implementation: in the new test, the variable-unset case must unset ROS2_COLCON_TESTS_REQUIRE_VCS explicitly inside its subshell and the other case must set it there, because the test runs inside the CI step that sets the variable. F2, note: the real-tool test must return after the required-vcs FAIL, as the skip branch does. F3, note: the workflow pin ==1.1.7 and the test extra's floor >=1.1.7 are two places to keep in step; a comment on the workflow step pointing to the extra. F4, the mechanism choice not to install vcs in the Lint job (the case still skips there, shown as 1 skipped): offered for veto and not vetoed. This proceed covers part 2 only; part 1 is delivered (pull request 540).

## Implementation
**Status**: complete
**When**: 2026-11-23 10:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-539 at `df37b3b4`

Part 2 of the plan (part 1's line untouched).

- `02d07168` test_ros2_colcon.sh: `test_tool_real_init_and_sync` fails (FAIL+1, returns, no real-tool steps; F2) when vcs is missing and `ROS2_COLCON_TESTS_REQUIRE_VCS` is set and non-empty; otherwise the loud skip stays. Comment above the function names the variable and the job. Results line counts `MR_SKIPPED + TOOL_SKIPPED`. New `test_real_tool_case_without_vcs` (registered after `test_setup_requires_vcs`, not behind `mr_test`): two subshells with an empty bin dir as PATH, one unsetting and one exporting the variable explicitly (F1), checking the output and the printed counters (`TOOL_SKIPPED=1 FAIL=0` / `TOOL_SKIPPED=0 FAIL=1`).
- `df37b3b4` validate.yml, Validate Adapter Contract: new step `pip install vcs2l==1.1.7` then `vcs --version`, with a comment that the pin is kept in step with the `[test]` extra's floor (F3); `env: ROS2_COLCON_TESTS_REQUIRE_VCS: '1'` on "Run ros2_colcon adapter tests". Lint job unchanged (the case still skips there, now counted).

Verification (local, vcs = /usr/bin/vcs, vcstool 0.3.0):
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: `=== Results: 1379 passed, 0 failed, 0 skipped ===`, real-tool case ran, no SKIPPED line.
- Same with `ROS2_COLCON_TESTS_REQUIRE_VCS=1` in the environment (as CI): `=== Results: 1379 passed, 0 failed, 0 skipped ===`; the variable-unset case still passes (F1 confirmed).
- Mutation (require branch changed to `&& false`, reverted, tree clean after): `=== Results: 1377 passed, 2 failed, 0 skipped ===`, both "variable set" assertions failed.
- `bash .agent/scripts/tests/test_script_tests_hook_scope.sh` (names test_ros2_colcon.sh): `test_script_tests_hook_scope: 347 passed, 0 failed`.
- Docs checked: no `.md` outside work plans names the suite's summary line, the variable or the adapter-contract job's steps (grep of test_ros2_colcon, REQUIRE_VCS, vcs2l, Validate Adapter Contract); `script_reference.md` and `build_and_test.md` need no change.
- Full pre-commit pass left to the host. Host still to do: CI log check (real-tool case with no SKIPPED line in adapter-contract; Lint green with `1 skipped`) and the job-time measurement before/after.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-23 10:17 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-539 at `e3c3d806`
**Base**: origin/main
**Depth**: Standard (reason: override trigger, .github/workflows/validate.yml)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 1 | **Ship**: recommended — no must-fix findings

Part 2 (02d07168 suite, df37b3b4 workflow) checked against the plan and the 2026-11-23 Plan Review and Checkpoint: F1 (explicit unset/export in the new test's subshells), F2 (return after the required-vcs FAIL) and F3 (pin comment naming the [test] extra) are in the code; the Lint job is left without vcs as decided. Ran: shellcheck --severity=warning and yamllint (clean); the suite with ROS2_COLCON_TESTS_REQUIRE_VCS=1 CI=1 and vcs on PATH: 1379 passed, 0 failed, 0 skipped, exit 0; the suite as Lint runs it (CI=1, PATH rebuilt without vcs): 1370 passed, 0 failed, 1 skipped, exit 0, with the SKIPPED line and banner. Claude adversarial subagent: no must-fix, its run 1379/0/0 with the variable set. Cross-model: gemini and codex both completed (EXIT=0); their points were dropped by the silence filter: subshell abort under set -e (cannot happen: -e is off inside $() and each subshell ends with echo), no TOOL_SKIPPED banner (false: line 5252 prints one), CI silent skip through mr_test (CI already fails in mr_pick_python when no resolver python), =0 counted as set (documented "set and non-empty", same as the plan), separate pip install and pin drift (the owner accepted the commented pin, F3), local-only mr_test skip with the variable set (local run, counted as skipped). Not checked: the hosted CI run and job times (verify step 6c/6d, host's after push).

### Findings
- [ ] No issues found. LGTM.
