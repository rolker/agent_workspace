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

## Checkpoint
**Status**: complete
**When**: 2026-09-29 13:49 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Split: "Core here, small split off (Recommended)" — this issue = P1a–P1d; P1e–P1g moved to #369.
Order: "#363 first (Recommended)" — plan against today's code; #344 rebases after.
Also carry into the plan: state how P1c is covered (asserted vs not).

## Plan Authored
**Status**: complete
**When**: 2026-09-29 13:52 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-363/plan.md` at `a205f07`

Ports P1a-P1d from the fork (refuse AGENT_KILL_AFTER=0, setsid group kill with PID-only fallback, launch-window adoption of `$!`, per-issue-dir non-blocking flock with exit 5 and `9>&-` on jobs) in five atomic commits, with ADR-0015, AGENTS.md rows and review-code exit-5 text updated. P1c is covered by existing TERM tests plus a bounded staggered-TERM stress test; the exact window is stated as not deterministically asserted. P1e-P1g stay in #369.

## Plan Review
**Status**: complete
**When**: 2026-09-29 13:58 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #363 — Cross-model reviewer scripts still lack seven hardening fixes the fork found
**Plan**: `.agent/work-plans/issue-363/plan.md` at `a205f07`
**Branch**: `feature/issue-363`

Compared against the fork's diffs (5af570f, 69a6907, 5818535, b5f080a, plus their prerequisites 06871f4 and a2b04c8) and our current `cross_model_review.sh`, `_cli_review.sh`, `_agy_review.sh` and `tests/test_cross_model_review.sh`. No external reviewers were run for this plan review.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | P1a-P1d only, per the owner's split; one PR, five atomic commits is right-sized. |
| Issue alignment | Good | All four items covered; the review-issue asks (state P1c coverage, sequence against #344) are addressed. |
| File targeting | Needs work | The watchdog-cancel fix that 69a6907 is built on is missing (finding 1); `CROSS_MODEL_ENV_PASSTHROUGH` does not exist here (finding 5). |
| Consequences | Needs work | Exit-5 consumer check can be settled now (finding 7); lock-file footprint in project worktrees is not covered by the workspace `.gitignore` (finding 6). |
| Principle alignment | Needs work | "Test what you change": two planned tests cannot fail on the old code (findings 2, 3). |
| ADR compliance | Needs work | ADR-0001/0008 immutability not addressed for the ADR-0015 edit (finding 8). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[File targeting / Approach 2] Must-fix: the watchdog is still cancelled with TERM, which it ignores.** Both helpers' `terminate_child` run `trap '' INT TERM HUP` and then fork the watchdog, which inherits the ignored TERM, so the `kill "$watchdog"` at `_cli_review.sh:250` / `_agy_review.sh:178` does nothing. The watchdog outlives every clean shutdown by the full escalation window and then runs `kill -9` on the dead CLI's PID. Once P1b is in, that becomes `kill -KILL -- -PGID` on a pgid that may belong to a new group by then. The fork fixed this before PR #662, in 06871f4 and a2b04c8, and 69a6907's diff assumes the fix. The plan mentions `pkill -KILL -P "$watchdog"` "before killing the watchdog" but never says the cancel itself becomes `kill -KILL "$watchdog"`. Fix: port that cancel explicitly (`pkill -KILL -P "$watchdog"; kill -KILL "$watchdog"`), correct the "re-checks liveness ... cannot hit a recycled PID" comment, and add the fork's assertion that the watchdog is gone when the helper returns. That assertion fails on today's code.
2. **[Tests / P1a] Must-fix: the direct helper test as written passes on today's code.** With the default `REVIEW_KILL_ESCALATION=5`, `AGENT_KILL_AFTER=0` is already refused because 0 ≤ 5 and not both are zero. Only the case where both are zero reaches the carve-out. The direct `_cli_review.sh` / `_agy_review.sh` calls must set `AGENT_KILL_AFTER=0 REVIEW_KILL_ESCALATION=0`. That case exits 0 today and must fail after the change. The parent-level flip at L3050 is fine as planned.
3. **[Tests / P1c] Must-fix: the stress test cannot detect a missing adoption, and as specified it is flaky.** The window lies between `&` returning and `CLI_PID=$!`, a few microseconds wide. TERMs spread over 0-150 ms essentially never land in it, so the test passes with the adoption code deleted. The claim that it "can only fail if the adoption is broken" does not hold. It also runs in CI and in every pre-commit (`make lint` → `validate-script-tests`), and it will fail spuriously in two ways. First, an early TERM kills the helper before the mock starts, so no orphan pidfile exists, and the fork's `assert_orphan_gone` counts a missing pidfile as FAIL. Second, if the mock finishes within 150 ms the helper exits 0, not 143. Replace it with, or at least add, a deterministic seam test. The suite already has `extract_fn`: extract `terminate_child` (and the `run_agent_job` trap and `cleanup_jobs`), start `setsid sleep 30 &` with `CLI_PID=""`, `CLI_LAUNCHING=true` and `CLI_LAUNCH_PREV=<$! before>`, call the handler in a subshell, and assert the sleep is gone. That fails when the adoption is removed. If the timing test stays, treat a missing pidfile as nothing spawned, give it a settle delay before the check, and make the mock sleep well past the last TERM.
4. **[Approach 2] Suggestion: say what setsid changes about `timeout`.** GNU `timeout` (without `--foreground`) sends its TERM, and the `-k` KILL, to its whole process group. Today that group includes the CLI and the CLI's children. After setsid the CLI's session is outside it, so the helper's forwarding is the only path to the CLI. If the helper is SIGKILLed, nothing reaches the CLI group any more. That is acceptable only because `REVIEW_KILL_ESCALATION < AGENT_KILL_AFTER` is enforced. The plan and the ADR bullet should state this dependency. Also check the margin: the post-wait poll (`ESCALATION_SECONDS*10` × `sleep 0.1` plus the fork of each `sleep`) can overrun ESCALATION by a few hundred ms. That is fine at the 5 s default against 10 s, but tight when the grace is `KILL_AFTER = ESCALATION + 1`.
5. **[Tests / P1b] Suggestion: correct two test details.** `CROSS_MODEL_ENV_PASSTHROUGH` is fork-only (it came with a2b04c8's codex env allowlist). Our mocks inherit the environment, so drop that step. The mocks' orphan child must stay in the CLI's process group: a plain `( ... ) &` from the fork's mock, with no setsid or nohup-into-a-new-group, or the test proves nothing. For the no-setsid fallback test, a PATH shim with every tool except setsid means symlinking bash, jq, mktemp, awk, sleep, pkill, tail, grep and the rest. Either list them in the test, or accept a clearly named test-only override. Also write the empty-array expansion as `${CLI_SETSID[@]+"${CLI_SETSID[@]}"}`: the helpers run `set -u`, and bash before 4.4 treats `"${arr[@]}"` of an empty array as unbound, which is exactly the no-setsid fallback path.
6. **[Consequences / Approach 4] Suggestion: lock the directory itself, not a lock file.** `cross_model_review.sh` also runs in project worktrees, where the workspace `.gitignore` entry does not apply, so the lock file would appear untracked in project repos. That works against the zero-footprint goal (#335). `flock(1)` works on a directory: `exec 9< "$WORK_PLANS_DIR"; flock -n 9`. That leaves no file, needs no `.gitignore` change and has no stale-file question. The fd probe then checks that fd 9 is open, not that it is writable. If the lock-file approach stays, add a Consequences row for project repos.
7. **[Consequences] Suggestion: settle the exit-5 consumer question now.** A grep shows the only caller that reads exit codes is `.claude/skills/review-code/SKILL.md` (L414-436). `run-issue` and `dispatch_phase.sh` never call the script. Replace the "check during implementation" row with that result. The SKILL text doesn't mention exit 4 either; add it next to exit 5.
8. **[ADR compliance / Approach 5] Suggestion: square the ADR-0015 edit with ADR-0001/0008.** ADR-0001 makes accepted ADRs immutable, and ADR-0008 allows only navigational addendums. Rewording the `AGENT_KILL_AFTER` clause and adding a lifecycle bullet is a substantive edit. ADR-0015 has been amended in place before (#313, #320), and #320 recorded it on the Status line. Follow that precedent: add a Status-line note ("Amended by #363: ...") alongside the text change, and put the ADR-0001/0008 tension in the PR description so the owner sees it. Amending is the right choice over superseding, since the decision is unchanged.
9. **[Approach 2] Suggestion: run each real CLI once before the PR.** setsid detaches each CLI from any controlling tty, and the post-exit group KILL removes anything the CLI deliberately left running, such as an agy or MCP helper daemon. The mocks cannot show either effect. After P1b, run `cross_model_review.sh --branch --agents gemini,codex --no-progress` once.
10. **[Scope] Note: the fork's `kill_tree` is not tracked here.** Our `cleanup_jobs` still hard-kills only the job shell when its reap budget runs out (from a2b04c8), which orphans `timeout`, the helper and the CLI. The plan is right to leave it out, but check that #369 or another issue tracks it.

### Summary

The plan is a faithful, well-scoped port of the four fork commits, but it misses a prerequisite fork fix: the watchdog is still cancelled with a TERM it ignores, and group signalling makes that bug more dangerous. Two planned tests (the direct P1a helper call and the P1c stress test) would pass with their fix removed, and the stress test would be flaky in CI. Fix findings 1-3 before implementing; the rest can be handled during implementation.

### Recommended Actions

- [ ] Add the watchdog SIGKILL cancel (fork 06871f4/a2b04c8) to P1b in both helpers, with a watchdog-gone assertion (finding 1)
- [ ] P1a direct-helper test: use `AGENT_KILL_AFTER=0 REVIEW_KILL_ESCALATION=0` so it fails on today's code (finding 2)
- [ ] P1c: add deterministic `extract_fn` seam tests of each adoption branch; drop the timing stress test or harden it against a missing pidfile and early completion (finding 3)
- [ ] State the setsid/`timeout` process-group trade-off and its reliance on the escalation < grace invariant (finding 4)
- [ ] Drop the `CROSS_MODEL_ENV_PASSTHROUGH` step; keep the orphan in the CLI's group; use a `set -u`-safe empty-array expansion (finding 5)
- [ ] Decide directory flock vs lock file; if lock file, add the project-repo consequence (finding 6)
- [ ] Replace the exit-code "check later" row with the grep result; document exit 4 and 5 in review-code (finding 7)
- [ ] ADR-0015: Status-line amendment note, and raise the ADR-0001/0008 tension in the PR (finding 8)
- [ ] One real-CLI smoke run after P1b (finding 9)
- [ ] Confirm `kill_tree` is tracked (finding 10)

## Checkpoint
**Status**: complete
**When**: 2026-09-29 14:11 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise, take all (Recommended) — fix M1–M3 and fold in S4–S10 (including locking the issue folder rather than a lock file).

## Plan Authored
**Status**: complete
**When**: 2026-09-29 14:13 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-363/plan.md` at `8658c58`
**Dispatch**: resumed (agent a222271354b5b9331, resume 1 of 3)

Revision after the needs-work plan review (owner: revise, take all). Adds the watchdog SIGKILL cancel, the both-zero direct-helper P1a test, deterministic extracted-function tests of each adoption branch in place of the stress test, and locks the work-plans directory itself; folds in S4-S10 (setsid/timeout trade-off, no env-passthrough step, review-code exits 4 and 5, ADR-0015 Status-line note with the ADR-0001/0008 tension, live CLI run, kill_tree untracked).

## Plan Review
**Status**: complete
**When**: 2026-09-29 14:20 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready
**Dispatch**: resumed (agent a164f026f89c7408d, resume 1 of 3)

**Issue**: #363 — Cross-model reviewer scripts still lack seven hardening fixes the fork found
**Plan**: `.agent/work-plans/issue-363/plan.md` at `8658c58`
**Branch**: `feature/issue-363`

Round 2. I checked the revised plan against the round-1 findings (entry 294391a) and against the fork's a2b04c8 test and helper diffs, and I checked the new material. No external reviewers were run.

### Round-1 findings: status

| Round-1 finding | Status |
|---|---|
| M1 watchdog cancel | Closed. Uses the a2b04c8 form (`pkill -KILL -P` then `kill -KILL`), corrects the comment, and adds a cancel assertion plus an orphan-sleep check. |
| M2 both-zero helper test | Closed. |
| M3 stress test | Closed. Replaced by extracted-function tests of all four adoption branches, each with a no-adopt guard case. |
| S4 setsid vs `timeout` | Closed, with a measure-the-overrun step. |
| S5 test details | Closed: no passthrough, orphan stays in the CLI's group, `set -u`-safe expansion, PATH-shim fallback test. |
| S6 directory lock | Closed for the primary path; see finding 1 about the fallback. |
| S7 exit 4 and 5 documented | Closed. |
| S8 ADR Status note and ADR-0001/0008 tension | Closed. |
| S9 live CLI run | Closed. |
| S10 `kill_tree` | Closed: stated as untracked and flagged in the PR. |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Still P1a-P1d; about six commits. |
| Issue alignment | Good | Round-1 actions all addressed. |
| File targeting | Good | `.gitignore` correctly dropped from the primary path. |
| Consequences | Good | Exit-code consumers resolved by grep; lock has no footprint. |
| Principle alignment | Needs work | The lock fallback as worded can silently disable serialization (finding 1). |
| ADR compliance | Good | Amend-in-place with Status note and the tension raised in the PR. One stale row (finding 4). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Approach 4] Must-fix during implementation: drop the directory-lock "probe" fallback, or make it tell the two failures apart.** The plan says to "probe once with `flock -n 9` right after the open" and fall back to the lock file if the host "cannot lock a directory". But `flock -n 9` also fails when another run holds the lock. Read literally, a contended second run would fall back to the lock file, take that lock uncontended, and proceed. That removes exactly the serialization P1d exists for. The fallback is also very likely dead code. `flock(2)` on a read-only directory fd works on Linux and the BSDs/macOS, and the no-`flock`-binary case is already the separate warn-and-proceed branch. Simplest fix: delete the lock-file fallback. Otherwise distinguish the two cases by exit status: util-linux has `-E/--conflict-exit-code`, but other `flock` ports may not. Whichever way, a contended lock must always end in exit 5.
2. **[Tests / P1c] Suggestion: make the `terminate_child` no-adopt guard fail fast.** The "unrelated background job" should be `setsid sleep 30`, and it needs no parent pipe (`</dev/null >/dev/null 2>&1`). If the guard were broken, a plain `sleep` would be adopted. `kill -- -PID` then misses it, because it is not a group leader, and the handler's `wait` blocks for the full 30 s before the test notices. A `setsid` sleep is killed at once. Also, `cleanup_jobs` needs `job_finished` and `proc_state` extracted with it, and every test `sleep` should be killed at the end of the test whatever the outcome, so a failure does not hold the suite's output pipe open.
3. **[Tests / M1] Suggestion: scope the orphan-sleep check to this test.** The fork's check is `pgrep -fx 'sleep 5s'`, which matches any such sleep on the host, including one from another agent's suite running at the same time. Use an escalation value no one else will use (e.g. `REVIEW_KILL_ESCALATION=7.3s`), or match the sleep by parent PID. `pkill` and `pgrep` come from procps. A host without them turns the new cancel into a no-op that leaves only a stray `sleep`, which is harmless. Guarding it with `command -v pkill` is optional.
4. **[Plan text] Suggestion: fix two leftovers from round 1.** The ADR Compliance row for 0013 still says "the lock file is a gitignored sibling". The Files table's test row still lists "env passthrough". Correct both so the implementer is not misled.
5. **[Tests / P1b] Note: the PATH-shim tool list is hand-kept.** The mocks also need whatever they call, such as `cat` and `sleep` (both listed), and `#!/usr/bin/env bash` resolves `bash` through the shim. If a tool is missing, the test fails loudly rather than passing, so this is acceptable. Build the shim from `command -v` so a tool missing on the host is reported by name.

### Summary

Every round-1 finding is closed, and the deterministic adoption tests do fail when the adoption `if` is removed. The one real defect is the lock fallback: as worded it would turn a contended lock into an unserialized run. It is a one-line change to make during implementation (delete the fallback, or require that a contended lock always gives exit 5), so the plan is ready, with that change carried as a required action.

### Recommended Actions

- [ ] P1d: remove the lock-file fallback (or distinguish conflict from unsupported by exit code); a contended lock must always give exit 5 (finding 1)
- [ ] Use a fd-detached `setsid sleep` for the `terminate_child` no-adopt case; extract `job_finished`/`proc_state` with `cleanup_jobs`; always kill test sleeps (finding 2)
- [ ] Scope the orphan-sleep check to this test (distinctive escalation value or parent PID) (finding 3)
- [ ] Fix the stale ADR-0013 row and the "env passthrough" Files-table text (finding 4)
- [ ] Build the no-setsid PATH shim from `command -v` with named failures (finding 5)

## Checkpoint
**Status**: complete
**When**: 2026-09-29 14:55 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: stop

Stop here (asked after the round-2 plan review: ready, with F1 must-do during implementation — drop the directory-lock fallback so a contended lock always exits 5 — and suggestions F2–F5).

## Checkpoint
**Status**: complete
**When**: 2026-10-01 08:57 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Resumed from the 2026-09-29 stop: "Have an agent work on B in the background while we work on A" (B = this issue). Implement with plan-review F1 as must-do (drop the directory-lock fallback so a contended lock always exits 5); F2–F5 are suggestions.

## Implementation
**Status**: complete
**When**: 2026-10-01 09:54 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-363 at `85a6037`

Implemented P1a-P1d from the plan, plus three follow-up fixes for problems the plan's live verification run found. 10 commits, not pushed.

- `a73f7c0` P1a: `AGENT_KILL_AFTER=0` refused (exit 2); the helpers' both-zero carve-out is gone.
- `42aa034` Watchdog cancel: `pkill -KILL -P` then `kill -KILL` in both helpers (prerequisite M1).
- `7e9e59b` P1b: the CLI runs under `setsid`, and its whole process group is signalled. The post-exit sweeps run in group mode only; there is a PID fallback without setsid and a `set -u`-safe empty-array expansion. Measured poll overrun: 5.05s at 5s and 10.11s at 10s (about 1%), so the tick loop is kept.
- `c49a7fa` P1c: launch-window adoption in both helpers, in `run_agent_job`'s trap and in `cleanup_jobs`.
- `8088a5e` P1d: a non-blocking `flock` on the artifact directory itself, exit 5 on contention, jobs launched with `9>&-`, exit 5 in the header.
- `3fd41e4` Docs: ADR-0015 amended in place, with a Status-line note. Updated the AGENTS.md rows for the three scripts and documented exits 4 and 5 in the review-code SKILL.
- `1487b59`, `a3e877a` Follow-up (found by Codex in the live runs): a signal that lands between the fork and `setsid()` found no group, so the TERM missed and so did the watchdog. Now the watchdog starts first and the handler waits for the group within the escalation window. If the window ends first, it SIGKILLs the unreaped PID.
- `1ca06c8` Follow-up (Gemini suggestion): util-linux `flock -E 75` tells a conflict (exit 5) from an error (warn and proceed unserialized). Any other `flock` still treats every failure as a conflict.
- `85a6037` The ADR-0015 bullets now cover both follow-ups.

Plan-review findings:
- F1 (must-do): done. There is no lock-file fallback, and a contended lock always exits 5. This is still true after `1ca06c8`.
- F2: done. The no-adopt cases use a detached `setsid sleep`, `cleanup_jobs` is extracted with `job_finished` and `proc_state`, and every probe sleep is killed.
- F3: done. The orphan-sleep check matches a per-run escalation value (`5.0$$s`).
- F4: skipped. I left the approved plan's text alone. Neither stale phrase (the lock file as a gitignored sibling, and env passthrough) affected the implementation.
- F5: done. The no-setsid PATH shim is built from `command -v` and names any missing tool.

Tests: each fix has a test that fails on the code before it. For the adoption tests and the `9>&-` test, this was checked on scratch copies with the fix removed. `test_cross_model_review.sh` passes 767 assertions with 0 failures. `run_script_tests.sh` passes all 30 suites.

Live verification ran `--branch --agents gemini,codex --no-progress` with the real CLIs:
- In both runs codex and agy were their own session and group leaders (pid = pgid = sid).
- No agy or codex process outlived either run.
- Run 1: codex completed. The gemini job failed on a syntax error because I edited `_agy_review.sh` while bash was still reading it. My mistake, not a defect.
- Run 2: both completed (EXIT=0) at `1487b59`. The shutdown-path fixes made after run 2 (`a3e877a`, `1ca06c8`) were not run live again; a successful run does not exercise those paths.

Run-2 review findings not acted on:
- Gemini 3/4 (the sweep does not deduct `wait` time): false positive. The watchdog fires at the end of the window counted from its start and kills the group, so the poll loop ends there.
- Gemini 7/8 (the post-exit sweep is unconditional): checking liveness before the KILL does not narrow the check-then-signal window. This is the accepted post-exit sweep design from the plan.
- Gemini 10 (AGENTS.md edits): script rows need no Ask-First.
- Codex 2 on run 1 (a watchdog `sleep` can be orphaned when `pkill -P` scans before the fork): skipped. The orphan is a bare `sleep` whose parent is already dead, so it exits on its own and no kill follows.

Not covered: the no-`flock`-binary warn path (no test); that bash actually delivers a TERM inside the real `&`-to-`$!` gap.

For the PR description:
- The fork's `kill_tree` fix is untracked here. `cleanup_jobs` still SIGKILLs only the job shell when its budget runs out.
- Amending ADR-0015 in place sits in tension with ADR-0001 and ADR-0008.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-01 10:12 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-363 at `f272bc1`
**Base**: main
**Depth**: Deep (reason: 1605 changed lines; enforcement scripts plus ADR, AGENTS.md and skill edits)
**Must-fix**: 3 | **Suggestions**: 7
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

Reviewers: static analysis (shellcheck clean), governance, plan drift, Claude adversarial, Codex (complete, 1 finding with a reproduction). Gemini failed: agy hit its output-token limit (status ERROR). Copilot was skipped because its quota is exhausted. Checked by running code: the new tests fail on main's scripts (30 FAIL), and the group-wait test fails at 7e9e59b (10 FAIL). shellcheck is clean. The group-wait test was reproduced with extracted functions.

### Findings
- [x] (must-fix) Watchdog/group-wait boundary race: the watchdog fires at the end of the window, finds no group yet, and exits without killing. `await_cli_group` then finds the group late (its tick loop overruns about 10%), and the TERM goes to a TERM-ignoring CLI. `wait` then blocks with no watchdog left, and the outer `timeout -k` orphans the detached CLI. Codex found it; reproduced here at escalation 0.4 s with setsid delayed 0.42/0.43 s: the handler hung until the CLI exited. Keep escalation armed until the child is gone (or SIGKILL the group directly when await succeeds after the watchdog has exited) and add a boundary test — `.agent/scripts/_cli_review.sh:315-327`, `.agent/scripts/_agy_review.sh:251-266`
- [ ] (must-fix) ADR-0015 amended in place adds two Consequences bullets and reverses the recorded `AGENT_KILL_AFTER=0` exception. ADR-0008 says that needs a superseding or new ADR. Either move the job-lifecycle rules into a new ADR with an ADR-0015 Status pointer (permitted), or get the owner's explicit waiver — `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md:7-10,126-145`
- [x] (must-fix) Plan-review F1 reopens on util-linux flock without `-E` (pre-2.25 from memory, unverified): `-E` is a usage error (exit 64 here for an unknown option), which counts as "error, proceed unserialized", so a contended lock runs unserialized. Treat only util-linux's error codes (65/71) as errors, or probe `-E` support first — `.agent/scripts/cross_model_review.sh:703-715`
- [x] (suggestion) The `REVIEW_KILL_ESCALATION < AGENT_KILL_AFTER` check compares rounded whole seconds (2.49/2.51 is accepted). Since setsid this margin is the only protection against an orphan, so compare unrounded values; "enforced strictly" in the ADR and AGENTS.md overstates it — `.agent/scripts/_cli_review.sh:188`, `.agent/scripts/_agy_review.sh:141`
- [x] (suggestion) The await loop is bounded by ticks, not time (500 ticks = 5.5 s), and does not stop when the child died before setsid (5.6 s shutdown). "Costs no time beyond the window" (comments, ADR) is false. Budget by elapsed time and stop early on a zombie or dead PID — `.agent/scripts/_cli_review.sh:270-276`, `.agent/scripts/_agy_review.sh:206-212`
- [x] (suggestion) A TERM after `wait` but before `CLI_PID=""` waits the full window, then `kill -KILL`s a reaped PID, contrary to the "unreaped child" comment. Clear `CLI_PID`/`AGY_PID` right after `wait` and use a local for the sweep — `.agent/scripts/_cli_review.sh:392-396`, `.agent/scripts/_agy_review.sh:316-320`
- [x] (suggestion) Watchdog cancel race: after `pkill -P` kills its `sleep`, the subshell can still run its kill body (1 in 100 trials), plus "Killed sleep" job notices on stderr (about 58/100). Use `sleep … && signal_cli 0 … && signal_cli KILL …` — `.agent/scripts/_cli_review.sh:315-316,341`, `.agent/scripts/_agy_review.sh:251-252,277`
- [x] (suggestion) Lock fd 9 is inherited by git/gh/python run between locking and launch. A daemon they spawn (e.g. git fsmonitor) would hold the lock and refuse later runs with exit 5 (speculative). Close fd 9 on those calls — `.agent/scripts/cross_model_review.sh:693-715`
- [x] (suggestion) When `cleanup_jobs` runs out of reap budget it SIGKILLs the job shell only. The parent's exit then releases the lock while a helper may still write findings, so a new run can start in the same dir. Note this in the ADR or PR alongside the untracked kill_tree gap — `.agent/scripts/cross_model_review.sh:868-870`
- [x] (suggestion) Test gaps: dead-before-setsid, TERM-after-wait, watchdog-expiry boundary, util-linux without `-E`, no-flock warning path — `.agent/scripts/tests/test_cross_model_review.sh`
