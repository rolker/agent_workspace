# Plan: test_ros2_colcon.sh expects the manifest tool's old sync report (#539)

## Approach

Two parts on this one issue and timeline. Part 1 goes to main first and does not wait for part 2's design.

### Part 1 - the stale expected text (pull request body says `Part of #539`)

Files: `.agent/scripts/tests/test_ros2_colcon.sh` only.

1. Near line 5065, in `test_tool_real_init_and_sync`, change the needle `present, not touched (2)` to `up to date (2)`. The tool's `report()` in `tools/repos-manifest/src/repos_manifest/sync.py` prints `up to date (<n>)` for the CURRENT outcome. Nothing else changes: not the stub strings at lines 4193 and 4424 (they are the suite's own stub's text and stay correct), not the summary line, not the workflow.
2. Verify on this machine (`vcs` is at /usr/bin/vcs): `cd <worktree> && bash .agent/scripts/tests/test_ros2_colcon.sh`. Pass: exit 0, the output shows `TEST: tool route with the real tool and vcs ...` with no `SKIPPED: vcs is not on PATH` line, and `adapter sync: the tool's own report` passes.

### Part 2 - CI runs the real-tool case and the skip is counted (pull request body says `Closes #539`)

Files: `.github/workflows/validate.yml`, `.agent/scripts/tests/test_ros2_colcon.sh`. Part 2 starts after part 1 and touches neither part 1's line.

3. Workflow, job `validate-adapter-contract`: add a step after "Install repos-manifest": `pip install vcstool==0.3.0` then `vcs --version`. Package from PyPI (the job already installs Python tools with pip, and the actions Python is the one the suite uses); pinned to 0.3.0, the version of the apt package on this machine, so a new release cannot change the real-tool case on its own. apt was not chosen: it adds a package-index step and ties the version to the runner image.
4. Suite: where `vcs` is missing, FAIL instead of skip when `vcs` is meant to be present, mirroring the resolver rule near line 2317: when `CI` is set. Reason: the adapter-contract job installs it now, and a quiet skip there would pass the job without running the case, which is the defect this issue reports. A machine without `CI` set keeps the loud skip (a developer without ROS tools still gets the other tests). The failure counts in FAIL and not in TOOL_SKIPPED.
5. Suite: the final line becomes `=== Results: P passed, F failed, $((MR_SKIPPED + TOOL_SKIPPED)) skipped ===`. Consumers checked: the only references to this suite's output are its own lines; `validate.yml` runs it as one `bash` step and reads the exit status; no workflow, `.pre-commit-config.yaml`, `Makefile`, `.agent/scripts/test.sh` or other suite parses a `skipped` count (grep done). The `SKIPPED:` explanatory lines stay.
6. Verify: (a) normal run: the line shows `0 skipped`; (b) with `vcs` off PATH and CI unset: a PATH holding no `vcs`, e.g. `env -u CI PATH=<dir with only the tools the suite needs> bash ...`: the line shows `1 skipped`; (c) the same with `CI=1`: exit nonzero and a FAIL line naming vcs. Add a test for (b)/(c) in the suite if a stub-PATH can be made cheaply, else record the manual runs in the PR.

### Ask First

Part 2 changes a CI workflow, which AGENTS.md lists as Ask First. The owner approved the issue's three items on 2026-11-20 ("Issue + fix main first (Recommended)"); the part 2 pull request names the workflow change so the owner's merge decision covers it.

## Prior Art

The resolver's fail-where-meant-to-run rule at test line 2317 is reused for `vcs`. Nothing new is built.

## Serves

Quality of the work, and "A safeguard has to earn its cost": `docs/design.md#merge-gate`.

## Design Picture

No change to the design picture.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A safeguard has to earn its cost | Part 2 makes the real-tool case run on every pull request and fail, not skip, when it cannot |
| Verify before claiming | Each part names its exact run and its pass signal |
| Atomic commits / small pull requests | Two pull requests; part 1 is one line |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0011 | No | No adapter contract change |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| The summary line's skipped number | Parsers of it | Yes: none found (step 5) |
| validate.yml | Job time | Yes: one pip install, seconds |

## Open Questions

None for the owner. Mechanism choices (pip pin, fail on CI) are listed for veto.

## Estimated Scope

Two pull requests: part 1 (one line), part 2 (workflow step, suite change).
