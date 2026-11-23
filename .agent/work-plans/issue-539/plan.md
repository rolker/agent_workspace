# Plan: test_ros2_colcon.sh expects the manifest tool's old sync report (#539)

## Approach

Two parts on this one issue and timeline. Part 1 is delivered; part 2 is revised on 2026-11-23 (owner: "Revise, whole part 2") after the Plan Review of 2026-11-20 (needs-work).

### Part 1 - the stale expected text: DELIVERED (pull request 540, merged; body said `Part of #539`)

Kept as the record. In `.agent/scripts/tests/test_ros2_colcon.sh`, in `test_tool_real_init_and_sync`, the needle `present, not touched (2)` became `up to date (2)`, the text `report()` in `tools/repos-manifest/src/repos_manifest/sync.py` prints for the CURRENT outcome. The stub strings at lines 4193 and 4424 are the suite's own stub text and stay. The suite ran `1375 passed, 0 failed, 0 skipped` here with the real-tool case run.

### Part 2 - CI runs the real-tool case, a missing vcs fails where it is required, the skip is counted (pull request body says `Closes #539`)

Files: `.github/workflows/validate.yml`, `.agent/scripts/tests/test_ros2_colcon.sh`. Part 1's line is not touched.

State checked on this branch on 2026-11-23 (even with origin/main apart from the checkpoint commit): `validate-adapter-contract` installs repos-manifest and runs the suite as its last step, with no `vcs` installed; `validate-scripts` (Lint) runs `make lint`, whose `validate-script-tests` hook runs every suite with `CI` set and no `vcs`; `tools/repos-manifest/pyproject.toml` `[test]` extra holds `vcs2l>=1.1.7`; `validate-repos-manifest` installs it and sets `REPOS_MANIFEST_REQUIRE_COLCON: '1'` on its test step.

1. **Workflow, install**: in `validate-adapter-contract`, after the "Install repos-manifest" step, add a step `pip install vcs2l==1.1.7` then `vcs --version`. `vcs2l` provides the `vcs` command and is what the repos-manifest `[test]` extra already installs (lower bound 1.1.7; PyPI's newest is 1.1.7, so the pin is the version the extra resolves to today). `vcstool==0.3.0` is not used: its `vcs` imports `pkg_resources`, which current setuptools no longer ships (the review's fresh venv crashed). vcs2l 1.1.7 ran `vcs --version` in a fresh venv with no setuptools (review). The `vcs --version` line makes a broken install fail at the install step.
2. **Workflow, require-variable (finding 1, mechanism decision)**: on the existing "Run ros2_colcon adapter tests" step add `env: ROS2_COLCON_TESTS_REQUIRE_VCS: '1'`, as `REPOS_MANIFEST_REQUIRE_COLCON: '1'` is set on the repos-manifest test step.
3. **Suite, fail where required**: in `test_tool_real_init_and_sync`, when `vcs` is not on PATH: if `ROS2_COLCON_TESTS_REQUIRE_VCS` is set and non-empty, print `  FAIL: vcs is not on PATH, though ROS2_COLCON_TESTS_REQUIRE_VCS says it is meant to be present` and `FAIL=$((FAIL + 1))`, not counted in `TOOL_SKIPPED`; otherwise the loud skip stays as is. A comment above the function names the variable and the job that sets it.
4. **Suite, count the skip**: the final line becomes `=== Results: ${PASS} passed, ${FAIL} failed, $((MR_SKIPPED + TOOL_SKIPPED)) skipped ===`. The `SKIPPED:` explanation lines stay. Consumers re-checked on 2026-11-23: no workflow, `.pre-commit-config.yaml`, `Makefile`, `.agent/scripts/test.sh` or `run_script_tests.sh` reads a `skipped` count from a suite (grep of `skipped` there finds only prose); `validate.yml` and the runner read exit status.
5. **Suite, test (required, review suggestion 3)**: add `test_real_tool_case_without_vcs`, modelled on `test_setup_requires_vcs` (line 1120): build an isolated bin directory holding only the tools the function needs (it returns before using any when `vcs` is missing; `echo` and `command` are builtins) and no `vcs`, then run `test_tool_real_init_and_sync` in a subshell with `PATH` set to it and `TOOL_SKIPPED=0 FAIL=0`, printing the two counters at the end of the subshell so the outer `PASS`/`FAIL`/`TOOL_SKIPPED` are untouched. Two cases: (a) variable unset: output has `SKIPPED: vcs is not on PATH`, counters `TOOL_SKIPPED=1 FAIL=0`; (b) variable `1`: output has `FAIL:` naming vcs, counters `TOOL_SKIPPED=0 FAIL=1`. Register it next to `test_setup_requires_vcs` in the run list (not behind `mr_test`: it needs no manifest-route python). The subshell's inner `FAIL:` line must not read as a suite failure: the test prints it through `assert_contains` on the captured text, not to the console.
6. **Verify**: (a) here with vcs present: `bash .agent/scripts/tests/test_ros2_colcon.sh` shows `0 skipped`, exit 0; (b) the new test passes, and mutated to ignore the variable it fails (run once, recorded); (c) after the push, the "Run ros2_colcon adapter tests" log shows the `TEST: tool route with the real tool and vcs` case with no `SKIPPED:` line, and the Lint job stays green (its skip is counted, not failed); (d) the job times of "Validate Adapter Contract" before and after, read from the run, are put in the pull request.

### Mechanism decisions open to the owner's veto

- Require-variable on the adapter-contract step, not `CI`: `CI` is also set in the Lint job, which has no vcs, so failing on `CI` would break Lint. The other route, installing `vcs2l` in Lint too, was not chosen: Lint already runs every suite and is the long job (issue 550 is about CI time), the real-tool case already runs in the adapter-contract job, and a second install adds a second place to keep the pin. Cost of the choice: in Lint the case still skips (now counted as `1 skipped`).
- `pip install vcs2l==1.1.7` over apt: the job already installs with pip, the version does not follow the runner image, and it is the package the `[test]` extra names.
- Variable name `ROS2_COLCON_TESTS_REQUIRE_VCS`: follows `REPOS_MANIFEST_REQUIRE_COLCON`.

### Ask First

Part 2 changes a CI workflow, which AGENTS.md lists as Ask First. The owner's answer of 2026-11-23 ("Revise, whole part 2") covers planning it; the part 2 pull request names the workflow change, and the owner's merge decision covers the change. The skip count stays in part 2 by the owner's choice, so part 2's pull request closes #539.

## Prior Art

Reused: the `REPOS_MANIFEST_REQUIRE_COLCON` pattern in this workflow (an explicit variable, set on one step, turns a missing tool from a skip into a failure) for the require-variable; `vcs2l` as the `[test]` extra and `validate-repos-manifest` already install it, for the package and its version floor; `test_setup_requires_vcs`'s isolated-PATH construction for the new test; the resolver rule near suite line 2352 (fail where the tool is meant to be present) for the intent. Rejected: `vcstool==0.3.0` (needs `pkg_resources`), failing on `CI` (breaks Lint), apt. Related, not part of this work: issue 550 (revisit CI so it keeps catching defects without stalling merges), which may change what CI runs; this part adds one pip install and no new job.

## Serves

Quality of the work, and "A safeguard has to earn its cost": `docs/design.md#merge-gate`.

## Design Picture

No change to the design picture.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A safeguard has to earn its cost | Part 2 makes the real-tool case run on every pull request and fail, not skip, where it is required; the Lint-job cost is kept honest (decisions above) |
| Verify before claiming | Each part names its exact run and its pass signal; the skip-vs-fail test is required |
| Atomic commits / small pull requests | Two pull requests; part 1 delivered, part 2 is one workflow step plus a suite change |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0011 | No | No adapter contract change |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| The summary line's skipped number | Parsers of it | Yes: none found (step 4) |
| validate.yml, adapter-contract job | Job time | Yes: one pip install of a pure-python package, measured in verify (d); Lint job unchanged |
| Require-variable | Lint job (no vcs, CI set) | Yes: variable set on the one step only |

## Open Questions

None for the owner. Mechanism choices (require-variable vs installing in Lint, pip pin, variable name) are listed for veto above.

## Estimated Scope

Two pull requests: part 1 (one line, merged), part 2 (workflow step and variable, suite change, one new test).
