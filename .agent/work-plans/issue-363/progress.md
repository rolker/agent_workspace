---
issue: 363
---

# Issue #363 — Cross-model reviewer scripts still lack seven hardening fixes the fork found

## Issue Review
**Status**: complete
**When**: 2026-09-29 13:28 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #363

### Scope Assessment

**Well-scoped?** Partly. Every item is concrete and cites a fork commit, and I re-verified the file claims against main (details below). As one PR it is too large and mixes two risk profiles: P1a-P1d change process-lifecycle behaviour in all three scripts and need mock CLIs that spawn TERM-ignoring children, while P1e-P1g are small, independent text/logic fixes in `cross_model_review.sh` and its test. Recommend two PRs (see Recommendations).
**Right repo?** Yes. All files are workspace infrastructure under `.agent/scripts/`.
**Dependencies**: none blocking. Overlaps to sequence around: #344 (drop the Copilot CLI reviewer) edits the same `_cli_review.sh` and its dispatch in `cross_model_review.sh`; #342 (external reviewer contract) is the umbrella and names none of these seven. Parent: #172.

**Claims verified against current source**
- P1a: confirmed. `cross_model_review.sh:165,191` (`allow_zero` true for `AGENT_KILL_AFTER`), and both-zero carve-outs at `_cli_review.sh:180` and `_agy_review.sh:133`. The outer calls at `cross_model_review.sh:257,263` pass `timeout -k "$AGENT_KILL_AFTER"`, so a `0` disables the escalation there. Refusing zero also lets both carve-outs be deleted (the helper's own `REVIEW_KILL_ESCALATION` default must stay below `AGENT_KILL_AFTER`, which still needs a positive value).
- P1b: confirmed. No `setsid` or group signalling anywhere; the helpers watchdog-kill only the PID (`_cli_review.sh:243`, `_agy_review.sh:174` use `kill -9 "$CLI_PID"`/`"$AGY_PID"`).
- P1c: confirmed as a pattern. PID is captured from `$!` after launch at `_cli_review.sh:289`, `_agy_review.sh:208`.
- P1d: confirmed. No `flock` in any of the three scripts. Agent jobs are launched at `cross_model_review.sh:1189,1235`; findings/prompt names are fixed per agent, so concurrent runs into one issue dir clobber each other.
- P1e: confirmed. `--work-dir` branch at `cross_model_review.sh:647-655` runs before the `--no-progress` branch at 656, and `ISSUE_NUMBER=noprogress` is set at ~574-577, giving `<work-dir>/.agent/work-plans/issue-noprogress`.
- P1f: confirmed. The keyword regex at `cross_model_review.sh:613` is `(closes|fixes|resolves)[[:space:]]+...#N`, so `Close`, `Fixed`, `Resolved` and `Closes: #N` are refused. The error text at ~618 names only the three keywords and needs updating too.
- P1g: confirmed with a line drift. `assert_contains` is at `tests/test_cross_model_review.sh:190-192` and `assert_not_contains` at 203-205, both using `echo "$text" | grep -qE` (line 9 is just `set -euo pipefail`). The issue names only `assert_contains`; fix both.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | OK | Each item is a code fix with a test, not a doc note. |
| Test what you change | Watch | P1c is not deterministically testable (the fork says so too); the plan should say what is asserted (adoption logic via a seam) and what is left untested, not skip silently. P1b needs mock CLIs that start a TERM-ignoring child. |
| Improve incrementally / small PRs | Watch | Seven items across 2000 lines of scripts in one PR is heavy to review; split as recommended. |
| Workspace project-agnostic | OK | No project references involved. |
| Only what's needed | Watch | P1d is described as fixing a leak that "does not exist yet". Port the lock and the `9>&-` fix as one unit (as the issue says), not the fd fix alone. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0015 (cross-model review, bounded agents) | Yes | P1a-P1d change the timeout/kill contract in section 3; the ADR text and the script header comments that describe zero-legal `AGENT_KILL_AFTER` must be updated. |
| ADR-0013 (progress.md) | Watch | P1e changes where `--work-dir` writes progress artifacts; keep the `--no-progress` contract intact. |

### Consequences

- Header comments in `_cli_review.sh` / `_agy_review.sh` and the Script Reference row for `cross_model_review.sh` / `_cli_review.sh` in `AGENTS.md` (documents `AGENT_KILL_AFTER`, the escalation rule, exit codes) need updating if behaviour changes; a new exit code 5 (busy lock) needs documenting.
- The "no closure keyword" error message and any test asserting it (P1f).
- Existing tests that assert `AGENT_KILL_AFTER=0` is accepted must flip to expect exit 2 (P1a).
- `setsid` availability differs on macOS; keep the PID-only fallback and test it.

### Recommendations

- Split into two PRs. PR 1: P1a + P1b + P1c + P1d, the lifecycle work in the three scripts (P1a first, since refusing zero simplifies the carve-outs P1b then touches). PR 2: P1e + P1f + P1g, small independent fixes in `cross_model_review.sh` and its test that can land first or in parallel. If the owner wants a smaller first step, PR 1 could be P1a+P1b only, with P1c+P1d as a third PR, since both build on the group-kill structure.
- Sequence PR 1 against #344 (drop Copilot CLI): whichever lands second rebases across `_cli_review.sh`; ideally decide #344's timing before planning.
- In the plan, state how P1c is covered (what is asserted, what is not) instead of leaving it implicit.
- Fix `assert_not_contains` together with `assert_contains` in P1g, and update the closing-keyword error text with P1f.

### Actions
- [ ] Split into two PRs. PR 1: P1a + P1b + P1c + P1d, the lifecycle work in the three scripts (P1a first, since refusing zero simplifies the carve-outs P1b then touches). PR 2: P1e + P1f + P1g, small independent fixes in `cross_model_review.sh` and its test that can land first or in parallel. If the owner wants a smaller first step, PR 1 could be P1a+P1b only, with P1c+P1d as a third PR, since both build on the group-kill structure.
- [ ] Sequence PR 1 against #344 (drop Copilot CLI): whichever lands second rebases across `_cli_review.sh`; ideally decide #344's timing before planning.
- [ ] In the plan, state how P1c is covered (what is asserted, what is not) instead of leaving it implicit.
- [ ] Fix `assert_not_contains` together with `assert_contains` in P1g, and update the closing-keyword error text with P1f.
