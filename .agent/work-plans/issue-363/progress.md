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
- [x] (must-fix) ADR-0015 amended in place adds two Consequences bullets and reverses the recorded `AGENT_KILL_AFTER=0` exception. ADR-0008 says that needs a superseding or new ADR. Either move the job-lifecycle rules into a new ADR with an ADR-0015 Status pointer (permitted), or get the owner's explicit waiver — `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md:7-10,126-145`
- [x] (must-fix) Plan-review F1 reopens on util-linux flock without `-E` (pre-2.25 from memory, unverified): `-E` is a usage error (exit 64 here for an unknown option), which counts as "error, proceed unserialized", so a contended lock runs unserialized. Treat only util-linux's error codes (65/71) as errors, or probe `-E` support first — `.agent/scripts/cross_model_review.sh:703-715`
- [x] (suggestion) The `REVIEW_KILL_ESCALATION < AGENT_KILL_AFTER` check compares rounded whole seconds (2.49/2.51 is accepted). Since setsid this margin is the only protection against an orphan, so compare unrounded values; "enforced strictly" in the ADR and AGENTS.md overstates it — `.agent/scripts/_cli_review.sh:188`, `.agent/scripts/_agy_review.sh:141`
- [x] (suggestion) The await loop is bounded by ticks, not time (500 ticks = 5.5 s), and does not stop when the child died before setsid (5.6 s shutdown). "Costs no time beyond the window" (comments, ADR) is false. Budget by elapsed time and stop early on a zombie or dead PID — `.agent/scripts/_cli_review.sh:270-276`, `.agent/scripts/_agy_review.sh:206-212`
- [x] (suggestion) A TERM after `wait` but before `CLI_PID=""` waits the full window, then `kill -KILL`s a reaped PID, contrary to the "unreaped child" comment. Clear `CLI_PID`/`AGY_PID` right after `wait` and use a local for the sweep — `.agent/scripts/_cli_review.sh:392-396`, `.agent/scripts/_agy_review.sh:316-320`
- [x] (suggestion) Watchdog cancel race: after `pkill -P` kills its `sleep`, the subshell can still run its kill body (1 in 100 trials), plus "Killed sleep" job notices on stderr (about 58/100). Use `sleep … && signal_cli 0 … && signal_cli KILL …` — `.agent/scripts/_cli_review.sh:315-316,341`, `.agent/scripts/_agy_review.sh:251-252,277`
- [x] (suggestion) Lock fd 9 is inherited by git/gh/python run between locking and launch. A daemon they spawn (e.g. git fsmonitor) would hold the lock and refuse later runs with exit 5 (speculative). Close fd 9 on those calls — `.agent/scripts/cross_model_review.sh:693-715`
- [x] (suggestion) When `cleanup_jobs` runs out of reap budget it SIGKILLs the job shell only. The parent's exit then releases the lock while a helper may still write findings, so a new run can start in the same dir. Note this in the ADR or PR alongside the untracked kill_tree gap — `.agent/scripts/cross_model_review.sh:868-870`
- [x] (suggestion) Test gaps: dead-before-setsid, TERM-after-wait, watchdog-expiry boundary, util-linux without `-E`, no-flock warning path — `.agent/scripts/tests/test_cross_model_review.sh`

## Implementation
**Status**: complete
**When**: 2026-10-01 11:07 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-363 at `d205f9a`
**Addressed**: Local Review (Pre-Push) at `f272bc1` (2026-10-01 10:12 -04:00)
**Commits**: `372d002`, `41bbb23`, `3a3df27`, `862b034`, `3b79c34`, `012d749`, `bcf534a`, `2143feb`, `d205f9a`

Round 1 fixes. All 3 must-fix and 7 suggestions are addressed. Each fix has a test that fails on the code before it, except where noted below. Nothing pushed.

### Actions
- [x] M1, the boundary race between the watchdog and the group wait (`372d002`). The handler now TERMs both the PID and the group. Before setsid() runs, only the PID reaches the child. The watchdog SIGKILLs the PID and the group at the deadline without first checking that the group exists. The group-wait loop is gone. The new test runs a pre-setsid stage and a CLI that both ignore TERM, with setsid landing between 0.3 and 0.6 s around a 0.4 s window. On the previous code the 0.41, 0.42 and 0.43 s cases hung. — `_cli_review.sh`, `_agy_review.sh` `terminate_child`
- [x] M2, ADR-0015 amended in place (`d205f9a`). The owner chose option 1. The ADR is back to main's text, plus one navigational sentence on the Status line: the `AGENT_KILL_AFTER=0` exception was withdrawn by #363, and the job lifecycle is described in the three script headers. Those headers and the AGENTS.md rows now carry what the removed bullets said, corrected for this round. Two claims in the removed bullets were wrong and are not carried over: "enforced strictly" (the check rounded the values) and "a signal before setsid waits for the group inside the window" (that wait is gone). `git diff origin/main` on the ADR shows only the Status sentence. — `docs/decisions/0015-…md`
- [x] M3, util-linux flock without `-E` (`3b79c34`). Measured on this host (util-linux 2.39.3): an unknown option exits 64, a contended lock with `-E 75` exits 75, a plain contended lock exits 1, and a bad fd exits 65. Per the man page, real errors use sysexits codes, and a failed flock(2) gives 65 or 71. I combined both of the review's options. Only 65 and 71 warn and proceed. A 64 retries without `-E` and counts any failure as a conflict. Every other code also exits 5. A contended lock now exits 5 on every flock variant tested: real util-linux, util-linux without `-E` (mocked), and a non-util-linux flock. — `cross_model_review.sh` lock block
- [x] S1, unrounded comparison (`862b034`). The escalation and the kill grace are now compared as given. The review's example of a wrong acceptance cannot happen: rounding is monotonic, so it could only wrongly refuse (2.6 against 2.9 was refused). The setsid comment now says that the strict check does not reserve the few milliseconds the watchdog needs to start. — `_cli_review.sh`, `_agy_review.sh`
- [x] S2, the tick-bounded await loop (`372d002`). The loop is removed by the M1 fix. The post-exit poll is now bounded by the watchdog's lifetime, which is elapsed time. A child that died before setsid no longer costs a full window. Test: the dead case took 5.5 s before and is now under 1 s. — same files
- [x] S3, TERM after `wait` (`41bbb23`). `CLI_PID`/`AGY_PID` is cleared as soon as `wait` returns. The group still to be swept is kept in `CLI_GROUP`/`AGY_GROUP`, and the handler runs that sweep when it is still pending. Tests: a TERM injected right after the reap (through a `BASH_ENV` `wait` wrapper) returns at once, where the previous code took 5.5 s. A handler in the "PID cleared, sweep pending" state kills a leftover group that ignores TERM. — same files
- [x] S4, the watchdog cancel race and the job notices (`3a3df27`). The watchdog is now `sleep && kill`, it is reaped after its SIGKILL, and its stderr is dropped. The "Killed" notices appeared in 30 of 30 runs on the previous code. The test asserts there are none. The race in which a killed sleep still let the kill body run cannot be reproduced on demand and has no test. — same files
- [x] S5, the lock fd inherited by git/gh/python (`012d749`). git and gh now run through wrappers that close fd 9, and the one python call closes it directly. Shims on PATH confirm the fix for git and gh (they saw fd 9 open on the previous code). The python call has no test, because the script runs the workspace `.venv` python by absolute path. — `cross_model_review.sh`
- [x] S6, cleanup SIGKILLed only the job shell (`bcf534a`). **This is an owner-directed scope addition beyond the plan.** The owner's words: "D1 option 1, D2, can it be fixed in this issue?" The host's answer was yes. I ported the fork's `kill_tree` (rolker/ros2_agent_workspace PR #662) and adapted it to the process groups. It collects the job's tree with `pgrep -P`, SIGKILLs it deepest first, and then SIGKILLs every group a tree member leads (timeout's group, and the CLI's group from setsid). It then waits, for at most 5 s, until none of it is running, so the exit that releases the lock comes after. In the test, a wedged helper that ignores TERM runs a CLI in its own group, with a child that was re-parented away and a child of its own. The test polls the lock during cleanup. When the lock first comes free, none of the four processes may still be running. On the previous code all four were. This supersedes the "untracked kill_tree gap" note meant for the PR description. — `cross_model_review.sh` `kill_tree`, `cleanup_jobs`
- [x] S7, the test gaps (`2143feb` plus the fix commits). Dead-before-setsid and the boundary at window expiry are in `372d002`. TERM-after-wait is in `41bbb23`. util-linux without `-E` is in `3b79c34`. The no-flock warning path is in `2143feb`. — `tests/test_cross_model_review.sh`

### Tests
- `test_cross_model_review.sh`: 878 passed, 0 failed. `run_script_tests.sh`: all 30 suites pass.
- Each new test was run against the helpers or script from before its fix, using scratch copies, and failed there. The exceptions are the no-flock test, which covers an existing path, and the two untested parts named above.

### Notes
- The previous code produced "Killed" notices from two places. The helper reported the unreaped watchdog job, and when the machine was under load the watchdog subshell also reported its killed `sleep`. The second source surfaced only in the pre-commit run, so the watchdog's stderr is now dropped as well.
- The older wedged-job test's cleanup line (`kill -9` on a stub that was already dead, under `set -e`) aborted the suite once kill_tree started killing the stub. It now asserts that the stub was killed and tolerates the failed kill.
- These shutdown paths have not been re-run live with the real CLIs. The last live run was at `1487b59`.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-01 11:24 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a168f8abfb0d44c34, resume 1 of 3)

**Branch**: feature/issue-363 at `38721ea`
**Base**: main
**Depth**: Deep (reason: 2135 changed lines; enforcement scripts plus AGENTS.md, ADR and skill edits)
**Must-fix**: 1 | **Suggestions**: 6
**Round**: 2 | **Ship**: continue — round 2: 1 must-fix with a design/correctness concern (not mechanical)

Round-1 items checked: M1, M3, S1-S5 and S7 are fixed as described. M2 matches the owner's choice: `git diff origin/main` on ADR-0015 shows only the Status sentence. That sentence notes the withdrawn exception and points to the script headers, and does not reword the Decision or Consequences, so it stays within ADR-0008's Status-line allowance. The script headers and the AGENTS.md rows carry the lifecycle rules. The new `kill_tree` was read cold.

Reviewers:
- Claude adversarial (fresh) ran the full suite: 878 passed, 0 failed, no leftovers. It ran each new test against the code before its fix; all failed there except the one in suggestion 5.
- Codex completed with 2 findings, with a reproduction.
- Gemini completed with 6 findings: 1 kept, 5 false positive or settled.
- Copilot skipped: quota exhausted.
- shellcheck clean.

Gemini findings rejected:
- `run_agent_job` re-adopts a reaped PID: `child` is never cleared, and the trap behaviour is unchanged from main.
- Bash < 4.4 `set -u` on the parent's arrays: these lines predate this branch, and the parent needs bash 4 anyway.
- Subscripts running git with fd 9: this script runs none.
- ADR body left as it was: the owner's choice.
- AGENTS.md Ask-First: settled at the plan stage.

### Findings
- [x] (must-fix) If the parent is SIGKILLed (or its whole process group is, as a harness kill would do), the lock is released while the job chain keeps running. `timeout`, the helper and the CLI sit in their own groups and none of them hold fd 9, so a second run can start and its findings get overwritten. Reproduced by the adversarial reviewer: `flock -n` succeeded 0.3 s after `kill -9` of the parent group, with 3 codex-chain processes alive, and the findings were written afterwards. Fix: let the job shell, `timeout` and the helper keep fd 9 (they are bounded by `timeout -k`) and close it only at the CLI and agy launch — `.agent/scripts/cross_model_review.sh:1414`, `.agent/scripts/_cli_review.sh` run_cli, `.agent/scripts/_agy_review.sh` agy launch
- [x] (suggestion) `kill_tree` finds the CLI's group only through a live leader. It misses that group once the CLI has been reaped but its children remain, and it misses a descendant that called setsid itself and was re-parented. Codex reproduced this with the real function. It is reachable only with a wedged helper, so either record the CLI's group id for the parent or soften "none of it runs" in the header — `.agent/scripts/cross_model_review.sh:902-923`
- [x] (suggestion) Group liveness in `kill_tree` and the test's `assert_orphan_gone` use a raw `kill -0`, so zombies count as live. Under a PID 1 that does not reap (containers), that gives a 5 s stall plus a false warning, and false test failures — `.agent/scripts/cross_model_review.sh:935-937`, `.agent/scripts/tests/test_cross_model_review.sh:4264`
- [x] (suggestion) SIGKILL the recorded groups before the PIDs. A group can otherwise empty out between being listed and being killed; it is only theoretical, since hitting another group needs a PID wrap — `.agent/scripts/cross_model_review.sh:913-923`
- [x] (suggestion) The "5s" bound is 50 polls per over-budget job, each with forks, so 4 wedged jobs can hold the exit and the lock for about 8 + 4×5 s. Make it one shared deadline, or fix the warning text — `.agent/scripts/cross_model_review.sh:928-942`
- [x] (suggestion) `test_helper_term_after_the_cli_was_reaped` passes on `41bbb23~1`, because 372d002 had already removed the symptom it times. It does not observe the TERM-to-reaped-PID hazard that 41bbb23 fixed — `.agent/scripts/tests/test_cross_model_review.sh:4948`
- [x] (suggestion) Docs:
  - The `_agy_review.sh` header still says `timeout -k` is the only sender of SIGKILL; `kill_tree` now sends it too.
  - Exit 4 when the directory cannot be opened for the lock is missing from the header's exit-code list and from SKILL.md, and the remediation given there does not fit this case.
  - The header could say that on NFSv4 every run takes the 65 warn-and-proceed path — `.agent/scripts/_agy_review.sh:40-46`, `.agent/scripts/cross_model_review.sh:723`, `.claude/skills/review-code/SKILL.md`

## Implementation
**Status**: complete
**When**: 2026-10-01 12:04 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a8021c18b0b8a229a, resume 1 of 3)

**Branch**: feature/issue-363 at `cd23df4`
**Addressed**: Local Review (Pre-Push) at `38721ea` (2026-10-01 11:24 -04:00)
**Commits**: `7c656ad`, `6394eab`, `c8a473a`, `9194dfb`, `5bd44cd`, `5113c60`, `cd23df4`

Round 2 fixes. The must-fix and all 6 suggestions are addressed, each in its own commit. Nothing pushed. ADR-0015 and `docs/design.md` are untouched.

### Actions
- [x] M1, a SIGKILLed parent released the lock while its jobs ran on (`7c656ad`). I followed the host's direction, which I checked first. The job shell, `timeout` and the helper now inherit fd 9. The helpers close it only where they launch the CLI or agy, and for their watchdog. This keeps the reason `9>&-` was added in the first place: the CLI (with whatever it leaves running) is the only process that can outlive `timeout -k`, because it runs in its own process group. The CLI still never holds the lock. Every process that does hold it is in timeout's group or waits on timeout.
  - **Longest hold after the parent dies:** until each job ends, at the latest `AGENT_TIMEOUT + AGENT_KILL_AFTER` after it launched. For gemini it is `GEMINI_BACKSTOP + AGENT_KILL_AFTER`. With the defaults that is 1810 s, or 2110 s for gemini. At that point `timeout -k` SIGKILLs the helper's group, and the job shell writes its marker and exits.
  - **Test:** SIGKILL the parent in the middle of a review. A second run must exit 5, the lock must never come free while a helper of the first run is alive, and it must come free once that job has finished its findings. On the previous code the lock was free at once and the second run proceeded. The fd probe now checks agy as well as codex. — `cross_model_review.sh` job launch, `_cli_review.sh` run_cli, `_agy_review.sh` launch
- [x] S1, `kill_tree` missed a group whose leader had been reaped, and a setsid descendant (`5bd44cd`). Each job now carries a unique `CROSS_MODEL_REVIEW_JOB` environment marker. On Linux, `kill_tree` also collects every process whose `/proc/*/environ` carries that marker, and kills every process group that any found process belongs to, except the script's own group.
  - The header and AGENTS.md now say exactly what is not found: a descendant that both left those groups and changed its environment, or, without /proc, one re-parented outside the CLI's group.
  - **Test:** the over-budget stub adds a descendant that runs setsid itself, and a child of a second CLI that has already been reaped. On the previous code exactly those two ran on. — `cross_model_review.sh` kill_tree, run_agent_sync
- [x] S2, zombie groups were counted as live (`9194dfb`). The new `group_running` reads each member's state through `pgrep -g` and /proc, and ignores zombies. The test helper `assert_orphan_gone` uses `running_state`.
  - **Test:** a group whose only member is a zombie, with a python parent that never reaps it. The previous code waited 5.9 s on it and warned. — `cross_model_review.sh` await_killed
- [x] S3, kill the groups before the PIDs (`6394eab`). This was theoretical (it needs a PID wrap), so there is no test.
- [x] S4, the "5s" bound applied per job (`c8a473a`). `kill_tree` now only kills and records. `await_killed` runs once, with one shared deadline of at least 5 s and at most 6 s (`SECONDS` counts whole seconds), and its warning says "at least 5s".
  - **Test:** one survivor listed under three killed jobs gives a single 5–6 s wait and the warning. With nothing left running there is no wait. The total extra hold on the exit and the lock is now at most 6 s.
- [x] S5, the TERM-after-reap test proved nothing (`5113c60`). I replaced it with `test_helper_term_with_the_sweep_pending`. A BASH_ENV DEBUG trap TERMs each helper right before its post-exit sweep runs, which is the state where the PID is cleared and the sweep is pending. A `kill` wrapper logs every signal the helper sends.
  - The test asserts exit 143, that the CLI's child which ignores TERM is gone, and that the reaped CLI's bare PID is never signalled.
  - It fails when the handler's sweep-pending branch is removed. On 372d002 (the commit before the round-1 S3 fix) the injection point does not exist and the helper exits 0.
- [x] S6, the docs (`cd23df4`):
  - The `_agy_review.sh` header now names both senders of SIGKILL.
  - Exit 4 for an artifact directory that cannot be opened for its lock is now in the script header and the review-code skill, with its own remedy.
  - There is an NFS note: every run on NFS takes the 65 warn-and-proceed path. I checked this in util-linux `flock.c`. With an fd argument it does not retry read-write, and its comment calls this EBADF "probably NFSv4".

### Tests
- `test_cross_model_review.sh` passes 894 with 0 failures, and `run_script_tests.sh` passes all 30 suites.
- Every new or changed test was also run against scratch copies of the scripts from before its fix, and failed there. S3 has no test.

### Notes
- The first M1 commit attempt failed the suite's leftover check. A SIGKILLed run cannot remove its own temp files, so the test now points that run's TMPDIR into its sandbox.
- When I first ran the S1 test against the old code, it failed on every process, not just the two new ones. The stub helper had passed the lock fd to its fake CLIs, unlike the real helper, so the lock never came free at all. The stub now launches its CLIs without fd 9, and the failure on the old code is exactly the two processes that `kill_tree` used to miss.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-01 12:18 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a168f8abfb0d44c34, resume 2 of 3)

**Branch**: feature/issue-363 at `e4ec91b`
**Base**: main
**Depth**: Deep (reason: 2488 changed lines; enforcement scripts plus AGENTS.md, ADR and skill edits)
**Must-fix**: 1 | **Suggestions**: 6
**Round**: 3 | **Ship**: recommended — round 3: 1 mechanical must-fix (prev 1), not rising — fix and ship rather than another full round

Round-2 items checked:
- M1: fixed. Every holder of fd 9 is the parent, the job shell, or a process in `timeout`'s group, and the CLI, agy and the watchdog launch with `9<&-`. So the hold after a parent SIGKILL really is bounded by `AGENT_TIMEOUT` (gemini: `GEMINI_BACKSTOP`) + `AGENT_KILL_AFTER`.
- S1-S6: fixed.
- The marker scan's reach was probed by running:
  - The match is exact (`-z -x -F`). The marker is a fresh `mktemp -d` path, so it is unique per run.
  - The script's own group and the caller's group cannot be reached.
- ADR-0015 is unchanged since round 2.

Reviewers:
- Claude adversarial (fresh): full suite 894 passed, 0 failed, no leftovers.
- Codex: completed, 1 finding (10 lines, short).
- Gemini: failed, agy hit its output-token limit (status ERROR).
- Copilot: skipped, quota exhausted.

### Findings
- [x] (must-fix) `kill_tree`'s `g=$(ps -o pgid= -p "$p" | tr -d ' ')` (and `own_group=` likewise) fails when a found PID exits before `ps` runs.
  - Under `set -euo pipefail` that aborts `cleanup_jobs` inside the EXIT trap before any kill: the CLI and helper stay alive, the temp root is left behind and the exit status is 1, not 143.
  - Reproduced 5/5 by the adversarial reviewer with a busy stub CLI. The errexit-in-trap abort was confirmed here. The 759ef51 code passed the same repro.
  - Fix: tolerate the failure (or read the pgid from `/proc/<pid>/stat`, falling back to `ps`), skip all group kills when `own_group` is empty, and add a busy-child variant of the cleanup test. That also covers BusyBox `ps`, which rejects `-p`.
  — `.agent/scripts/cross_model_review.sh:952,954`
- [x] (suggestion) The `/proc/[0-9]*/environ` grep reads every process the user owns. A process stuck on a hung NFS/FUSE mount could block the exit path with no limit while fd 9 is held. Traced by reading kernel behaviour only. Bound it with `timeout` — `.agent/scripts/cross_model_review.sh:950`
- [x] (suggestion) The marker scan SIGKILLs the whole group of any on-demand daemon the CLI started on this run's interrupt path (git fsmonitor, gpg-agent, a tmux server). Consider guarding against `g` 0/1 and re-checking the marker before each kill — `.agent/scripts/cross_model_review.sh:940-972`
- [ ] (suggestion) Exit 5 says "wait for that run to finish". After a SIGKILLed run no run is visible, yet its helpers hold the lock for up to 1810 s (gemini about 2110 s). The message, header and SKILL should say so, give the bound and name `fuser -v <dir>`/`lsof +d <dir>` — `.agent/scripts/cross_model_review.sh:776`, `.claude/skills/review-code/SKILL.md:442`
- [ ] (suggestion) Codex: if `timeout -k` ever SIGKILLs a helper before its watchdog fires, the setsid'd CLI survives, and the marker sweep does not run on normal job completion. This is the design dependency already accepted at plan stage (escalation < kill grace, so it needs a wedged helper). Defense in depth: sweep marked descendants when a job ends 124/137 — `.agent/scripts/cross_model_review.sh:1059`
- [ ] (suggestion) The header reads "waits (at least 5 s, at most 6 s in total)"; it means up to 5-6 s — `.agent/scripts/cross_model_review.sh:117`
- [ ] (suggestion) Possible flake: the second run must reach `flock` within the mock's 3 s sleep. Use a longer `MOCK_CODEX_SLEEP` — `.agent/scripts/tests/test_cross_model_review.sh:4732`

## Checkpoint
**Status**: complete
**When**: 2026-10-01 12:40 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: address

"address everything regarding 363" — asked after pre-push round 3 (1 must-fix M1: interrupt cleanup aborts when a found PID exits before its pgid lookup; suggestions S1–S6). The host had recommended a narrow round that left S4 (sweep a job's marked processes when it ends with 124/137) to a follow-up issue; the owner chose the option that fixes S4 on this branch too. The round also includes one live interrupt test with the real reviewer CLIs. Then review round 4 and back to the owner for the publish decision.
