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
