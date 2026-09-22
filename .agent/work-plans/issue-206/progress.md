---
issue: 206
---

# Issue #206 — cross_model_review.sh: reconsider tmux-default; sync should be parallel (and gstack has a non-tmux pattern worth borrowing)

## Issue Review
**Status**: complete
**When**: 2026-09-22 10:43 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #206

### Scope Assessment

**Well-scoped?** Partially. The core ask — replace the sequential `--sync`
fallback with a parallel `&`+`wait` dispatch and make it the default, keeping
tmux behind an explicit `--tmux` flag — is a single reviewable PR. Two things
should be split out before implementation:
1. The gstack `benchmark-models` adapter-pattern discussion is explicitly
   speculative ("if multi-agent review becomes a workspace-wide pattern
   beyond review-code") — not part of this change; treat as a reference,
   not scope.
2. The `rolker` comment reports a separate, already-diagnosed bug: `copilot
   -p < prompt` is broken against the current Copilot CLI (missing an empty
   value for `-p` and `--allow-all-tools`). Verified still present at HEAD
   (`cross_model_review.sh` lines 104 and 124, both `build_invoke_cmd` and
   `run_agent_sync`). The commenter themselves suggested filing it
   separately — do that; it's an independent one-line fix unrelated to the
   dispatch-mode question and shouldn't block or bloat this PR.

**Right repo?** Yes — `cross_model_review.sh` and the `review-code` skill
are workspace infrastructure.

**Dependencies**: None blocking. Downstream `rolker/ros2_agent_workspace#461`
is watching this decision for its Copilot-only port but isn't blocking.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| A change includes its consequences | Action needed | `.claude/skills/review-code/SKILL.md` step 5d currently documents three sequential invocations (lines 325-332 at HEAD) — must be rewritten to the new `--agents` single-invocation shape in the same PR, not as follow-up. The consequences map (`principles_review_guide.md`) explicitly pairs `review-code` skill changes with `cross_model_review.sh` changes. |
| Capture decisions, not just implementations | Action needed | No ADR documents the tmux-dispatch decision today (only work-plan/knowledge-digest mentions from issues #2, #65, #66, #106, #181). Reversing a default that was deliberately chosen for interactivity is exactly the kind of decision ADR-0001 asks to be recorded — file a new ADR (or extend an existing one via ADR-0008 addendum if the reversal is framed as a correction) rather than letting the rationale live only in this issue thread. |
| Only what's needed | Watch | Keep the gstack adapter-pattern (`Promise.allSettled`, typed per-agent `RunResult`) out of scope — it requires a bun/node runtime the workspace doesn't otherwise depend on. The proposal's own bash `&`+`wait` option satisfies the actual need without new runtime dependencies. |
| Test what breaks | Action needed | The new parallel-dispatch path (background jobs, per-agent exit-code files, `wait -n` or equivalent) needs its own coverage in `test_cross_model_review.sh` (currently 1344 lines with an existing mock-tmux test from #311) — background-job error handling in bash is exactly the kind of logic that fails silently if untested. |
| Improve incrementally | OK | Scoped correctly (parallel-sync-default) this is an incremental, reviewable change. |
| Workspace improvements cascade to projects | Watch | If `--agents` becomes the recommended invocation, downstream consumers reading `cross_model_review.sh` as a reference (the linked `ros2_agent_workspace#461` port) should see the pattern land before or alongside their port to avoid diverging. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0001 — Adopt ADRs | Yes | See "Capture decisions" above — this reverses a prior, deliberate default with no ADR of record. |
| 0013 — progress.md entry-type vocabulary | Yes (process, not content) | Standard for any issue driven through the review loop; no special handling needed beyond the normal `review_progress.sh persist` calls. |
| 0011 — Project-type adapter contract | No | `cross_model_review.sh` doesn't branch on project shape; this is agent-dispatch logic, not project-type logic. |

### Consequences

- `.claude/skills/review-code/SKILL.md` step 5d (sequential per-agent invocation examples) must be updated to the new `--agents` shape.
- `cross_model_review.sh`'s own usage header (currently documents tmux as default, lines 22-26/39-46) must be rewritten.
- `test_cross_model_review.sh` needs new tests for the parallel-sync path, not just a rename of the existing sync test.
- `.agent/knowledge/` digests referencing tmux dispatch (`research_digest.md`, inspiration digests) are historical notes, not living docs — no update needed, but don't let plan-task confuse them for current behavior docs.

### Recommendations

- Split the Copilot `-p`/`--allow-all-tools` fix into its own issue (trivial, already diagnosed) and land it independently of this decision.
- File or extend an ADR capturing the tmux-default reversal before or alongside the implementation PR, per ADR-0001.
- Keep the gstack adapter-pattern out of this issue's scope; reference it in the ADR's "considered alternatives" instead of implementing it.
- Add explicit background-job/error-handling test cases (partial failure, one agent times out while others succeed) to `test_cross_model_review.sh` as part of the same PR.

### Actions
- [ ] `.claude/skills/review-code/SKILL.md` step 5d currently documents three sequential invocations (lines 325-332 at HEAD) — must be rewritten to the new `--agents` single-invocation shape in the same PR, not as follow-up. The consequences map (`principles_review_guide.md`) explicitly pairs `review-code` skill changes with `cross_model_review.sh` changes.
- [ ] No ADR documents the tmux-dispatch decision today (only work-plan/knowledge-digest mentions from issues #2, #65, #66, #106, #181). Reversing a default that was deliberately chosen for interactivity is exactly the kind of decision ADR-0001 asks to be recorded — file a new ADR (or extend an existing one via ADR-0008 addendum if the reversal is framed as a correction) rather than letting the rationale live only in this issue thread.
- [ ] The new parallel-dispatch path (background jobs, per-agent exit-code files, `wait -n` or equivalent) needs its own coverage in `test_cross_model_review.sh` (currently 1344 lines with an existing mock-tmux test from #311) — background-job error handling in bash is exactly the kind of logic that fails silently if untested.
- [ ] Split the Copilot `-p`/`--allow-all-tools` fix into its own issue (trivial, already diagnosed) and land it independently of this decision.
- [ ] File or extend an ADR capturing the tmux-default reversal before or alongside the implementation PR, per ADR-0001.
- [ ] Keep the gstack adapter-pattern out of this issue's scope; reference it in the ADR's "considered alternatives" instead of implementing it.
- [ ] Add explicit background-job/error-handling test cases (partial failure, one agent times out while others succeed) to `test_cross_model_review.sh` as part of the same PR.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 10:46 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed. The plan must address the four review actions: a new ADR recording the tmux-default reversal (gstack pattern under considered alternatives, out of scope); rewrite the review-code skill's dispatch step to the single-invocation shape in the same PR; explicit parallel-dispatch failure-mode tests (one agent fails, one times out while others succeed); the Copilot -p / --allow-all-tools fix stays in #212 and out of this PR.

## Plan Authored
**Status**: complete
**When**: 2026-09-22 10:51 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-206/plan.md` at `b4e5a78`

Refactors `cross_model_review.sh` to a single `--agents a,b,c` invocation that
dispatches agents in parallel background jobs by default (`&`+`wait`, per-agent
exit codes via `wait PID`), rewrites `review-code` skill step 5e to the new
shape, adds a new ADR-0015 for the tmux-default reversal, moves tmux behind an
explicit `--tmux` opt-in (recommended: keep, not remove), and adds partial-
failure/timeout tests for the new parallel path.

## Plan Review
**Status**: complete
**When**: 2026-09-22 10:54 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #206 — cross_model_review.sh: reconsider tmux-default; sync should be parallel (and gstack has a non-tmux pattern worth borrowing)
**Plan**: `.agent/work-plans/issue-206/plan.md` at `b4e5a78`
**Branch**: `feature/issue-206`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Single PR: ADR + script + skill + tests. Copilot `-p` fix correctly left in #212; gstack pattern correctly reference-only. |
| Issue alignment | Good | Covers the issue's ask (parallel default, tmux behind a flag) and all four owner-checkpoint requirements. |
| File targeting | Needs work | Misses `.agent/knowledge/agent_wait_patterns.md` and the `AGENTS.md` script table (finding 7). |
| Consequences | Needs work | Shared-diff/prompt error paths are single-findings-file today and undefined for N agents (finding 4); the two docs above (finding 7). |
| Principle alignment | Needs work | "A change includes its consequences" — the two missed living docs. "Test what breaks" — the timeout test as written is not implementable against the current code (finding 1). |
| ADR compliance | Good | ADR-0001 satisfied; 0015 is the next free number (0014 is the highest in `docs/decisions/`). ADR-0008 correctly assessed N/A. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Approach / Test what breaks — must-fix]** *No per-agent timeout exists for codex/claude/copilot.* Only gemini is bounded, by `AGY_PRINT_TIMEOUT` inside `_agy_review.sh`; `run_agent_sync` runs the other three with no cap. Today tmux hides that (the hang is detached); making blocking sync the unconditional default promotes an unbounded hang to the default failure mode, and a single hung agent hangs the whole multi-agent call. This is also why `test_agents_flag_one_times_out` is not implementable as written — there is no injectable timeout for a non-gemini mock. Resolution: wrap non-gemini agents in `timeout "$AGENT_TIMEOUT"` (default matching `AGY_PRINT_TIMEOUT`, env-overridable so the test can inject seconds), and treat the timeout exit as that agent's failure.
2. **[Approach — must-fix]** *Agent-binary resolution and the gemini-helper check are single-agent and hard-exit 1* (script lines 287–320). Under `--agents gemini,codex,copilot`, one missing CLI would abort the whole run before any agent starts — directly contradicting `review-code` SKILL.md ("One agent's unavailability does not block the others"), which is the behaviour the current three-call shape provides for free. Resolution: resolve binaries per agent; a missing CLI/helper becomes that agent's `EXIT=1` + `--- Review failed ---` (with the reason in its findings file); exit 1 only when no selected agent is available. Needs a test.
3. **[Approach — must-fix]** *Marker placement contradicts the plan's own timeout-test assertion.* Step 3 writes `--- Review complete/failed ---` in the parent after an in-order `wait "$pid"` loop, but `test_agents_flag_one_times_out` asserts the fast agent's findings/marker are "not delayed by the slow one." With in-order waiting they are delayed whenever the slow agent sorts first. Resolution: each background subshell appends its own marker based on its own exit status; the parent's `wait` loop only collects exit codes for the `EXIT=` lines. This also makes `tail -f` (the plan's advertised tmux substitute) truthful.
4. **[Consequences]** *Shared-diff failure paths are undefined for N agents.* Lines 566/572/586/592 write `--- Review error: ... ---` into a single `$FINDINGS_FILE`. With a shared diff fetch there is no single findings file. Specify: write the error marker into every selected agent's findings file (truncating, not appending), keep exit 3, and emit no `AGENT=` triplets. Add a test for empty-diff under `--agents`.
5. **[Approach]** *`--agents` input hygiene unspecified.* `--agents gemini,gemini` would launch two jobs writing the same prompt/findings file and the same tmux session name; empty entries (`gemini,,codex`), a trailing comma, surrounding whitespace and case are likewise unspecified (`--agent` lowercases via `${2,,}`). Specify: trim, lowercase, reject empty entries and duplicates with exit 2 (or dedupe), and test at least the duplicate and empty-entry cases.
6. **[Approach]** *`--tmux` interactions unspecified.* (a) `--tmux --sync` together — error or `--tmux` wins? (b) `--tmux --agents a,b` stdout shape is undefined: is it `MODE=tmux` with repeated `AGENT=`/`TMUX_SESSION=`/`FINDINGS_FILE=` triplets, and is there an `EXIT=` line (there is no exit status for a launched session)? Define both, or restrict `--tmux` to `--agent` for this PR and say so.
7. **[Consequences — missing files]** Two living docs are not in "Files to Change": (a) `.agent/knowledge/agent_wait_patterns.md` — its "Decision quick-reference" row (line 63) and See-also entry (lines 72–74) present tmux-session polling as *the* cross-model-review wait pattern; after this change the default wait is a bounded parallel `wait` in-process. This is current-state guidance, not a historical digest, so the plan's blanket "`.agent/knowledge/` mentions are historical" does not cover it. (b) `AGENTS.md` script-table row for `cross_model_review.sh` (it enumerates flags) needs `--agents` and the parallel-sync default. `.agent/knowledge/review_depth_classification.md:75` is generic and needs no change — worth saying so explicitly in the consequences table.
8. **[Approach — clarity]** State that the *flag*, not the agent count, selects the output shape: `--agent X` → `MODE=sync` (no `EXIT=`), `--agents X` (single entry) → `MODE=parallel-sync` with an `EXIT=` line. Otherwise implementer and skill can disagree on the N=1 case.
9. **[Test]** *Harness gaps.* The suite mocks `agy`, `gh`, `git` and `tmux`; the new tests need mock `codex`/`copilot` binaries with injectable exit codes. Add a real concurrency assertion (slow mock + fast mock: wall clock well under the serial sum, and the fast agent's findings file complete before the slow one finishes) — without it, "parallel" is untested and a sequential implementation passes. Also pin the per-agent independence of markers (already planned) and the setup-failure case from finding 4.
10. **[Approach — low]** Require that background jobs write nothing to stdout, so the machine-parseable `MODE=`/`AGENT=`/`FINDINGS_FILE=`/`EXIT=` block stays contiguous and unmangled by interleaving.

### Open Questions — answers

**Q1: keep tmux behind `--tmux`, or remove it?** Keep behind `--tmux`, agreeing with the plan, but on a narrower rationale than the plan gives: `tail -f` covers live observation, so the only capability tmux uniquely provides is **non-blocking dispatch** — with sync as the default, an interactive caller now blocks for up to the timeout. The ADR should say that, record tmux as retained-but-deprecated with an explicit removal criterion ("no in-repo caller passes `--tmux`; remove when the timeout cap makes blocking dispatch acceptable"), and the plan must define its multi-agent semantics (finding 6). Full removal is a defensible second choice — it deletes `build_invoke_cmd` and with it exactly the quoted-command-string risk the ADR cites as a reason to prefer sync — but it is a scope change the owner should choose, not the implementer.

**Q2: aggregate exit-code contract.** Endorse the plan's "0 if all succeed, 3 if any agent failed, all findings files still fully written." Do not swallow failures to 0 (a caller that never parses stdout would then see success), and do not add a new code. One condition: exit 3 is already used for pre-dispatch setup failures (prompt/diff), so the script header and the skill must state the disambiguator — **exit 3 with no `AGENT=` triplet on stdout = setup failure; exit 3 with triplets = per-agent failures, read `EXIT=`** — and a test must pin it (finding 4).

### Summary

The plan is structurally sound, correctly scoped, and satisfies all four owner-checkpoint requirements; it also flags the `set -e`/`wait` pitfall accurately. It is not yet ready to implement: three must-fixes (no timeout for non-gemini agents, single-agent binary resolution that would abort a whole multi-agent run, marker placement that contradicts its own test) plus two missing consequence docs.

### Recommended Actions

- [ ] Add a per-agent timeout for codex/claude/copilot (env-overridable) and make it the mechanism the timeout test exercises (finding 1)
- [ ] Make agent-binary and `_agy_review.sh` availability per-agent soft failures; exit 1 only when no selected agent is available; add a test (finding 2)
- [ ] Move the `--- Review complete/failed ---` marker write into each background subshell; parent collects exit codes only (finding 3)
- [ ] Define shared-diff/prompt failure behaviour for N agents (error marker into every selected findings file, exit 3, no triplets) + test (finding 4)
- [ ] Specify `--agents` parsing hygiene: trim, lowercase, reject/dedupe duplicates and empty entries (finding 5)
- [ ] Define `--tmux` + `--sync` and `--tmux` + `--agents` semantics, or restrict `--tmux` to `--agent` for this PR (finding 6)
- [ ] Add `.agent/knowledge/agent_wait_patterns.md` and the `AGENTS.md` script-table row to Files to Change; note `review_depth_classification.md` as no-change (finding 7)
- [ ] State that the flag, not the agent count, picks the output shape (finding 8)
- [ ] Add mock `codex`/`copilot` binaries and a wall-clock concurrency assertion to the test plan (finding 9)
- [ ] ADR-0015: record the blocking-by-default consequence, tmux as retained-but-deprecated with a removal criterion, and the exit-3 disambiguation (Q1, Q2)

## Checkpoint
**Status**: complete
**When**: 2026-09-22 11:02 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise. Fold in the round-1 plan review's action items (per-agent timeout with env override for every agent, per-agent binary resolution so one missing CLI does not abort the others, completion markers written inside each background job, per-agent findings files on the shared-diff error path, --agents hygiene, doc consequences in agent_wait_patterns.md and the AGENTS.md script row, mock codex/copilot binaries and a wall-clock concurrency assertion, exit-code disambiguator). Owner decision on the tmux open question: REMOVE the tmux path entirely, no --tmux flag; the ADR records the removal and why (headless reviews, parallel sync replaces the overlap, no quoted command strings). The existing mock-tmux test is retired with the path.

## Plan Authored
**Status**: complete
**When**: 2026-09-22 11:08 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-206/plan.md` at `340e4e4`

Revision of the round-1 plan: folds in all ten plan-review action items
(per-agent timeout with env override, per-agent binary resolution so one
missing CLI doesn't abort the run, in-job completion markers, per-agent
findings files on the shared-diff error path, `--agents` hygiene, doc
consequences in `agent_wait_patterns.md` and the `AGENTS.md` script row,
mock codex/copilot/claude binaries plus a wall-clock concurrency test, and
the exit-3 disambiguator) and implements the owner's checkpoint decision to
remove tmux entirely (no `--tmux` flag; `--sync` also removed as it has no
remaining meaning once tmux is gone).

## Plan Review
**Status**: complete
**When**: 2026-09-22 11:14 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: ready

**Issue**: #206 — cross_model_review.sh: reconsider tmux-default; sync should be parallel (and gstack has a non-tmux pattern worth borrowing)
**Plan**: `.agent/work-plans/issue-206/plan.md` at `340e4e4`
**Branch**: `feature/issue-206`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Single PR: ADR + script + tests + three docs. Copilot `-p` fix still out (#212); gstack still reference-only. 159 lines is over the 60-120 guideline but every extra line is a folded round-1 finding — not padding. |
| Issue alignment | Good | Implements the owner checkpoint exactly: tmux removed outright, no `--tmux` flag, ADR records the removal. All ten round-1 action items are addressed (see Findings for the two answered by deviating with a stated rationale). |
| File targeting | Good | `agent_wait_patterns.md` (line 63 row + See-also 72-74) and the `AGENTS.md` script row are now listed; `review_depth_classification.md` explicitly checked and declared no-change. Verified: neither knowledge doc mentions `--sync`, so nothing else goes stale. |
| Consequences | Good | Shared-diff error path defined for N agents; `--sync` removal traced to its one non-test caller (`review-code` SKILL.md:347, rewritten here) and to ~20 `--sync` invocations in the test suite (finding 4). |
| Principle alignment | Good | "Consequences" — the two missed living docs are in. "Test what breaks" — timeout, per-agent binary failure, marker independence, hygiene, shared-diff failure and concurrency all have cases. "Only what's needed" — gstack stays in the ADR. |
| ADR compliance | Good | ADR-0001 satisfied by 0015 (still the next free number); ADR-0008 correctly N/A; ADR-0013 process-only. `AGENTS.md` is an Ask-First instruction file, but the owner's round-1 checkpoint named that script row explicitly — approval exists, don't re-ask. |
| ROS conventions | N/A | Workspace plan. |

### Findings

All suggestions — none blocks implementation.

1. **[Approach — `--sync`, low]** Removing `--sync` to exit 2 is the right call, not a no-op shim. The blast radius is one non-test caller (rewritten in this PR) and the test suite; no knowledge doc names the flag. The only exposure is a live agent session that memorised it, and there the failure is loud, immediate and trivially retried — whereas a silent no-op would need its own test, its own removal follow-up, and would keep documenting a choice that no longer exists. One cheap improvement: special-case `--sync` in the argument parser with a named message ("`--sync` was removed in #206 — parallel sync is the only dispatch mode") while still exiting 2, so a stale caller reads the answer instead of a bare unknown-argument usage dump. Assert that string in the rejection test.
2. **[Approach — exit contract, low]** Item 4 (exit 1 when *no* selected agent resolves) and item 7 (exit 3 when any agent failed) leave the all-unavailable `--agents` case undefined on stdout. State it: exit 1, no `MODE=`/`AGENT=` lines, reasons in each findings file — and put it in the skill's disambiguator next to the exit-3 split, so `review-code` has all three cases (1 = nothing runnable, 3 + no triplets = setup, 3 + triplets = per-agent).
3. **[Test — concurrency, medium]** A pure wall-clock bound ("three `N`s mocks finish well under `3N`") is the one new test that can flake on a loaded runner. Make the primary assertion structural: each mock writes a start and an end timestamp (or start/end marker files), and the test asserts *overlap* — agent B started before agent A finished. Keep the wall-clock check as a loose secondary (`< 2N`, with `N` >= 2) rather than the sole signal. Overlap is what "parallel" means and it holds under arbitrary scheduler delay; a tight wall-clock bound does not.
4. **[Test — sweep, low]** The tests row says "retire `test_agy_tmux_invocation`; add tests below" but not that roughly twenty existing invocations pass `--sync` (to avoid tmux) and must all drop it once the flag exits 2. Loud failures, so no risk of silent drift — but naming the sweep in the plan keeps the diff's size unsurprising at code review.
5. **[Approach — timeout, low]** `AGENT_TIMEOUT=1800` matching `AGY_PRINT_TIMEOUT` is a sound default: it is the longest any agent has ever been allowed, and with parallel dispatch it bounds the whole call rather than 3x. Gemini's exemption is justified (an outer SIGTERM would race `_agy_review.sh`'s timeout-then-partial-response contract from #288), but it leaves gemini unbounded if `agy` ignores its own `--print-timeout`. Optional backstop: wrap gemini in `timeout` at a value comfortably above its internal one (e.g. `AGY_PRINT_TIMEOUT` + 300s), which cannot race the normal path because the inner timeout always fires first.
6. **[Approach — shared-diff failure, low]** Writing the error marker into every selected findings file while printing no triplets means the caller is told nothing about files that were just written. That is coherent only because the skill learns the disambiguator in the same PR — so make sure the rewritten 5d/5e says, in words, that on exit 3 with no triplets there is nothing to read and the error is on stderr. Keep the truncating (`>`) write the plan specifies, so a stale findings file from a previous run can't be misread as this run's output.

### Summary

The revision folds in all ten round-1 items — the two it answers by deviating (dedupe silently instead of exit 2; gemini exempt from the outer timeout) both state a rationale I accept. The owner's tmux decision is implemented cleanly and simplifies the design rather than complicating it: no `build_invoke_cmd`, no quoted command strings, one dispatch path. The remaining items are implementation-level and code review will catch them. Ready to implement.

### Recommended Actions

- [ ] Reject `--sync` with a named message ("removed in #206 — parallel sync is the only mode") rather than the generic unknown-argument dump; assert the message in the test (finding 1)
- [ ] Define the all-agents-unavailable stdout/exit case (exit 1, no triplets) and put all three exit cases in the skill's disambiguator (finding 2)
- [ ] Make the concurrency test assert interval overlap between agents, with wall clock as a loose secondary bound (finding 3)
- [ ] Note in the plan/PR that every existing `--sync` invocation in `test_cross_model_review.sh` is swept out (finding 4)
- [ ] Optional: outer `timeout` backstop for gemini set above `AGY_PRINT_TIMEOUT` so it cannot race the #288 contract (finding 5)
- [ ] In the rewritten 5d/5e, state that exit 3 with no triplets means nothing to read; keep the truncating write on the error path (finding 6)

## Checkpoint
**Status**: complete
**When**: 2026-09-22 11:13 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed to implementation with the round-2 suggestions folded in: overlap-based concurrency assertion (wall clock only as a loose secondary), one defined exit code for the all-agents-unavailable case, sweep the existing --sync test invocations, and name --sync explicitly in the rejection message.

## Implementation
**Status**: complete
**When**: 2026-09-22 11:40 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Branch**: feature/issue-206 at `8f5f53f`
**Mode**: inline

- tmux removed from cross_model_review.sh (build_invoke_cmd, session launch, auto-detect, TMUX_SESSION=); --sync rejected as removed (exit 2, message names it).
- --agents a,b,c with hygiene (trim/lowercase/empty-entry reject incl. leading/trailing comma/dedupe/unknown exit 2), mutually exclusive with --agent; shared prompt built once; per-agent timeout -k AGENT_KILL_AFTER AGENT_TIMEOUT (gemini keeps its helper's print-timeout); per-agent binary resolution; one background job per agent writing its own marker; parent wait "$pid" || rc=$?; MODE=parallel-sync + upfront findings paths + AGENT=/FINDINGS_FILE=/EXIT= triplets; exit 0/3 with the no-triplets disambiguator; exit 1 = no usable CLI, nothing written; interrupt/exit cleanup kills every job (traps armed before spawn, in the job and in _agy_review.sh).
- ADR-0015 (docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md); review-code SKILL.md dispatch step rewritten to one --agents call keyed on EXIT=; agent_wait_patterns.md, AGENTS.md script row, principles_review_guide.md ADR table updated.
- Tests: tmux test retired, --sync sweep, parallel suite (all succeed, partial failure, timeout, overlap concurrency, missing CLI, none usable, hygiene, shared-diff failure, SIGTERM cleanup, single-agent output unchanged): 163 assertions, 23 runner suites green.
- Three live Gemini+Codex parallel runs of this branch; their findings fixed in commits 5d45484 and 959dc79. Commits: 5e3d919, 5d45484, 959dc79, plus the plan sync.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 11:46 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-206 at `c00b2c7`
**Base**: main
**Depth**: Deep (reason: enforcement + governance files — review dispatch script, its skill, a new ADR; cross-model: run by host during implementation, findings incorporated)
**Must-fix**: 2 | **Suggestions**: 9
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) Stale Gemini-only naming for the cross-model specialist: Deep-tier list, 5e heading, graceful-degradation guideline contradict the new `--agents` single-call model — `.claude/skills/review-code/SKILL.md:54,212,705`
- [x] (must-fix) gemini has no outer bound (`--print-timeout` only covers a turn already running); round-2 plan-review finding 5 unchecked and its recorded rebuttal does not apply to a backstop set *above* `AGY_PRINT_TIMEOUT`; `AGY_PRINT_TIMEOUT` is also hardcoded, so no test can exercise it — `.agent/scripts/cross_model_review.sh:107,133`
- [x] (suggestion) Header overclaims that findings files "always end with" a complete/failed marker — the abort and interrupt paths do not — `.agent/scripts/cross_model_review.sh:63`
- [x] (suggestion) Comment says pipefail reports "the first failing stage's" status; bash reports the last non-zero — `.agent/scripts/cross_model_review.sh:654`
- [x] (suggestion) INT traps in background children are dead code (SIGINT ignored on entry, cannot be trapped); comments imply coverage that only TERM provides — `.agent/scripts/cross_model_review.sh:767`, `.agent/scripts/_agy_review.sh:97`
- [x] (suggestion) Generic mock ignores argv, so the per-agent invocation contract (`codex exec` vs `-p`) is untested — `.agent/scripts/tests/test_cross_model_review.sh:1265`
- [x] (suggestion) No regression guard that gemini is exempt from `AGENT_TIMEOUT` (ADR-0015 §3) — `.agent/scripts/tests/test_cross_model_review.sh:1368`
- [x] (suggestion) `AGENT_TIMEOUT`/`AGENT_KILL_AFTER` unvalidated (bad value = opaque exit 125); `--pr` never shape-checked while `--issue`/`--repo` are — `.agent/scripts/cross_model_review.sh:115`
- [x] (suggestion) Wall-clock 5.5s assertion is the one load-sensitive check; interval overlap already proves concurrency — `.agent/scripts/tests/test_cross_model_review.sh:1414`
- [x] (suggestion) Plan still names the ADR `0015-parallel-sync-is-the-default-...`; it landed as `...-is-the-only-...` — `.agent/work-plans/issue-206/plan.md:29`
- [x] (suggestion) Exit-1 description says each unavailable agent is named on stderr; not true for the missing-`gh` branch — `.claude/skills/review-code/SKILL.md:377`

## Implementation
**Status**: complete
**When**: 2026-09-22 11:59 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-206 at `c1d5516`
**Addressed**: Local Review (Pre-Push) at `c00b2c7` (2026-09-22 11:46 -04:00)
**Commits**: 238d272, 5db8c11, c1d5516

### Actions
- [x] (must-fix) Cross-model specialist renamed throughout review-code: Deep-tier bullet, the 5e heading, and the graceful-degradation guideline now describe the `--agents` single-call model and per-agent `EXIT=` semantics (an unavailable agent fails only itself; the review proceeds with whichever agents completed; exit 1 is the only case that drops the specialist) — `.claude/skills/review-code/SKILL.md:54,212,704`
- [x] (must-fix) Gemini now has an outer bound: `AGY_PRINT_TIMEOUT` is env-overridable and the gemini job runs under `timeout -k "$AGENT_KILL_AFTER" "$GEMINI_BACKSTOP"`, derived as print-timeout + `GEMINI_BACKSTOP_MARGIN` (default 300s). The margin is what keeps the backstop from racing `_agy_review.sh`'s timeout-then-partial-response contract (#288) — the helper's own print-timeout stays the primary path and always fires first in normal operation. Header comment, ADR-0015 §3, plan item 3 and the review-code timeout sentence all updated; new test `test_gemini_backstop_cuts_off_wedged_agy` drives a stalled mock agy with `AGY_PRINT_TIMEOUT=1s GEMINI_BACKSTOP_MARGIN=2` and asserts EXIT=124, the `--- Review failed ---` marker, and that the wedged process is dead — `.agent/scripts/cross_model_review.sh:107-160,180`
- [x] (suggestion) Header no longer claims every findings file ends with a complete/failed marker; it names the two marker-less paths (shared-prompt abort, interrupt) and tells readers to handle them — `.agent/scripts/cross_model_review.sh:63`
- [x] (suggestion) pipefail comment corrected to bash's rule (the pipeline's status is the last non-zero stage's) — `.agent/scripts/cross_model_review.sh:700`
- [x] (suggestion) Job shells now trap TERM only, with a comment explaining that bash makes background children of a non-interactive shell ignore SIGINT so an INT trap could never run; `_agy_review.sh` keeps its INT trap (live for a direct interactive invocation) and says so — `.agent/scripts/cross_model_review.sh:812`, `.agent/scripts/_agy_review.sh:101`
- [x] (suggestion) Generic agent mock records argv to `MOCK_ARGV_DIR`; `test_agents_all_succeed` asserts the per-agent invocation contract (`codex exec`, `copilot -p`) — `.agent/scripts/tests/test_cross_model_review.sh:1275,1330`
- [x] (suggestion) Added `test_gemini_not_bound_by_agent_timeout`: `AGENT_TIMEOUT=1` kills a 3s codex while a 3s gemini completes, guarding ADR-0015 §3 against a future change routing gemini through the plain timeout path — `.agent/scripts/tests/test_cross_model_review.sh`
- [x] (suggestion) All four duration knobs (`AGENT_TIMEOUT`, `AGENT_KILL_AFTER`, `AGY_PRINT_TIMEOUT`, `GEMINI_BACKSTOP_MARGIN`) are shape-validated at startup and `--pr` is checked as a positive integer, each exit 2 with a message naming the value; `test_duration_knobs_validated` covers all five — `.agent/scripts/cross_model_review.sh:130,345`
- [x] (suggestion) Wall-clock 5.5s assertion dropped from the concurrency test; interval overlap is the whole assertion, with a comment recording why the clock bound was removed — `.agent/scripts/tests/test_cross_model_review.sh:1440`
- [x] (suggestion) Plan's ADR filename corrected to `0015-parallel-sync-is-the-only-review-dispatch-mode.md` — `.agent/work-plans/issue-206/plan.md:29`
- [x] (suggestion) Exit-1 paragraph now distinguishes the two dependency failures: no usable agent CLI (each named on stderr) vs. a missing `gh` in PR mode, which aborts before agent resolution with a single warning — `.claude/skills/review-code/SKILL.md:377`

### Verification
- `bash .agent/scripts/tests/test_cross_model_review.sh` — 185 passed, 0 failed
- `bash .agent/scripts/tests/run_script_tests.sh` — all 23 suites passed (62s)
- pre-commit (incl. shellcheck) clean on every commit; nothing pushed

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 12:02 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-206 at `48d0ca9`
**Base**: main
**Depth**: Deep (reason: enforcement + governance files; round-2 re-review of the round-1 fixes only — cross-model: run by host during implementation, findings incorporated)
**Must-fix**: 1 | **Suggestions**: 2
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

### Findings
- [x] (must-fix) Duration knobs are shape-validated but not range-validated, so `0` passes: `AGENT_TIMEOUT=0` makes coreutils `timeout` impose no limit at all, silently voiding the "every agent is bounded" guarantee of ADR-0015 §3, and `GEMINI_BACKSTOP_MARGIN=0` collapses the backstop onto `AGY_PRINT_TIMEOUT` — the exact race the comment two lines below names ("Passing a margin of 0 would reintroduce that race") but does not prevent. Require > 0 for `AGENT_TIMEOUT` and `GEMINI_BACKSTOP_MARGIN` (`AGENT_KILL_AFTER=0` stays legitimate) — `.agent/scripts/cross_model_review.sh:130-166`
- [x] (suggestion) `duration_to_seconds` accepts a unit-less number and a `d` suffix, which coreutils `timeout` understands but Go's `ParseDuration` does not; `AGY_PRINT_TIMEOUT` is passed straight to agy's `--print-timeout`, so `AGY_PRINT_TIMEOUT=90` or `=1d` passes validation and then fails inside agy at runtime. Validate that knob against the Go-duration subset the header already claims for it — `.agent/scripts/cross_model_review.sh:133-146`
- [x] (suggestion) On backstop expiry `timeout -k` SIGKILLs the helper after `AGENT_KILL_AFTER`, which skips `_agy_review.sh`'s EXIT trap and leaves its `agy-review.XXXXXX` tmpdir behind. Inherent to SIGKILL and only reachable from a wedged helper, but worth a line in the helper's "no temp files survive any exit path" contract — `.agent/scripts/_agy_review.sh:33,98`

### Round-1 items verified resolved
- [x] Gemini-only naming retired at SKILL.md:54, 212 and in the Graceful-degradation guideline, now describing per-agent `EXIT=` failure; AGENTS.md row and ADR-0015 §3 updated to match
- [x] Gemini now bounded by an outer `timeout -k "$AGENT_KILL_AFTER" "$GEMINI_BACKSTOP"` derived as `AGY_PRINT_TIMEOUT + GEMINI_BACKSTOP_MARGIN`; rationale corrected in header, ADR and plan; distinct 124 message names which bound fired; `AGY_PRINT_TIMEOUT` made env-overridable and exercised by `test_gemini_backstop_cuts_off_wedged_agy`
- [x] Marker "always ends with" overclaim replaced with the abort/interrupt carve-out and a reader instruction
- [x] pipefail comment corrected to bash's last-non-zero rule
- [x] Dead INT trap removed from `run_agent_job`; `_agy_review.sh` keeps its INT trap with the direct-interactive-invocation justification stated
- [x] Mock records argv; `codex exec` vs `-p` asserted
- [x] `test_gemini_not_bound_by_agent_timeout` guards the ADR-0015 §3 exemption
- [x] Duration knobs validated up front (exit 2, named message) instead of an opaque `timeout` exit 125; `--pr` gets the positive-integer check
- [x] Load-sensitive wall-clock assertion dropped; interval overlap is the sole concurrency proof, with the reasoning recorded in the test and the plan
- [x] Plan's ADR filename corrected to `...-is-the-only-...`
- [x] SKILL.md exit-1 paragraph now separates the no-usable-CLI case from the missing-`gh` case

## Implementation
**Status**: complete
**When**: 2026-09-22 12:10 -04:00
**By**: Claude Code Agent (claude-opus-5)

**Branch**: feature/issue-206 at `2512600`
**Addressed**: Local Review (Pre-Push) at `48d0ca9` (2026-09-22 12:02 -04:00)
**Commits**: 0e31f90, 2512600

### Actions
- [x] (must-fix) Duration knobs are now range-validated as well as shape-validated. `AGENT_TIMEOUT`, `AGY_PRINT_TIMEOUT` and `GEMINI_BACKSTOP_MARGIN` require > 0, each with a message saying what zero would remove (coreutils `timeout 0` = no limit, voiding ADR-0015 §3; agy's `--print-timeout 0s` = wait forever; a zero margin collapses the backstop onto the print-timeout and reintroduces the #288 race). `AGENT_KILL_AFTER=0` stays valid — SIGKILL immediately after the SIGTERM is a real choice. Validation moved into a `validate_duration_knob` helper carrying per-knob allow-zero / reason — `.agent/scripts/cross_model_review.sh:147-193`
- [x] (suggestion) `AGY_PRINT_TIMEOUT` is additionally held to the Go-duration subset, since it is passed straight to agy's `--print-timeout` and `time.ParseDuration` rejects both the bare number and the `d` suffix coreutils accepts. An explicit `s`/`m`/`h` unit is required and the message says why; `AGENT_TIMEOUT` keeps the full coreutils shape — `.agent/scripts/cross_model_review.sh:162-168`
- [x] (suggestion) SIGKILL tmpdir leak fixed rather than documented (three lines): `cross_model_review.sh` creates one `cross-model-review-tmp.XXXXXX` scratch root, hands it to the gemini job as `TMPDIR`, and removes it in `cleanup_jobs`, which already runs on every exit path. `_agy_review.sh`'s contract now names SIGKILL as the one path its traps cannot cover and points at the parent-owned root. Rationale recorded in plan.md's Implementation Notes — `.agent/scripts/cross_model_review.sh:625,644,182`, `.agent/scripts/_agy_review.sh:33`

### Verification
- `bash .agent/scripts/tests/test_cross_model_review.sh` — 196 passed, 0 failed (was 185; the validation case now covers shape, range, the Go subset, `AGENT_KILL_AFTER=0` and a unit-less `AGENT_TIMEOUT`, and the backstop case asserts its scratch root is empty afterwards)
- `bash .agent/scripts/tests/run_script_tests.sh` — all 23 suites passed (61s)
- pre-commit (incl. shellcheck) clean on both commits; nothing pushed

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 12:14 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-206 at `c1e84de`
**Base**: main
**Depth**: Deep (reason: enforcement + governance files; round-3 re-review of the round-2 fixes only — cross-model: run by host during implementation, findings incorporated)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

### Findings
- [ ] No must-fix findings. All three round-2 items verified resolved in code and under test; no regressions found. Ready to push.
- [ ] (suggestion) ADR-0015's env-knob consequence still reads "all four are shape-validated up front"; validation is now shape + range (non-zero) + a Go-duration subset for `AGY_PRINT_TIMEOUT`. One-line precision fix, not blocking — `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md:100`

### Round-2 items verified resolved
- [x] Zero rejected where it removes a bound: `validate_duration_knob` refuses `AGENT_TIMEOUT=0`, `AGY_PRINT_TIMEOUT=0s` and `GEMINI_BACKSTOP_MARGIN=0` with a per-knob message naming why zero is wrong; `AGENT_KILL_AFTER=0` stays valid via the explicit `allow_zero` argument and is exercised by a real run, not just an error assertion. Rounding is handled — the message says "whole seconds after rounding", so `0.4` is caught too
- [x] `AGY_PRINT_TIMEOUT` held to the Go-duration subset (`^[0-9]+(\.[0-9]+)?[smh]$`) before the coreutils check, so `90` and `1d` — valid for `timeout`, rejected by `time.ParseDuration` — now fail at startup instead of inside agy after the job launched; `AGENT_TIMEOUT=90` still accepted, and both directions are tested
- [x] SIGKILL tmpdir leak closed rather than documented: the parent creates one `cross-model-review-tmp.XXXXXX` scratch root, hands it to the gemini job as `TMPDIR`, and removes it in the `cleanup_jobs` EXIT trap it already runs. The backstop test now asserts the scratch root is empty afterwards, which covers the prompt file and the helper's dir together

### Regression checks
- [x] `exec env TMPDIR=... timeout -k ...` keeps the signal chain intact: `env` execs rather than forks, so the PID the job shell holds is still `timeout`'s, and the parent's TERM still reaches agy through the helper
- [x] `test_agy_no_temp_leak` is not weakened — it points `TMPDIR` at a private dir, and both the scratch root and the helper's dir are created under it, so the `ls -A` assertion still covers the whole chain
- [x] `AGENT_TMP_ROOT` is referenced in `run_agent_sync` but only ever called after the assignment, so `set -u` is satisfied; `_agy_review.sh`'s contract now names SIGKILL as the one untrappable path and points at the parent-owned root

## Checkpoint
**Status**: complete
**When**: 2026-09-22 12:18 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: publish
**Decision**: publish

Publish. Pre-push review approved at round 3 (7f2edf7), zero must-fixes; push the branch as reviewed and open the PR.

## Integrated Review
**Status**: complete
**When**: 2026-09-22 12:24 -04:00
**By**: Claude Code Agent (claude-opus-5)

**PR**: #318 at `3b762b4`
**Sources**: 1 (Local Review (Pre-Push) round 3 @ `c1e84de` — the reviewed code head; `3b762b4` adds progress.md bookkeeping only) + CI rollup. No GitHub review source: the sole PR review is Copilot's quota-limit notice ("unable to review this pull request because the user who requested the review has reached their quota limit"), which carries no findings and is not waited on. No human reviews, no inline comments, no conversation comments.
**Cross-source confirmations**: 0 (only one findings-bearing source exists, so confirmation is not possible this round)
**CI**: all-pass — the four real checks on the head are green (Lint (pre-commit), Validate Documentation, Validate Adapter Contract, ros-manifest tests (#267 prototype)). The `copilot-pull-request-reviewer` check-run reports failure; that is the same quota exhaustion, not a code or test failure.

### Findings
- [ ] (suggestion, Local Review round 3 @ `c1e84de`) ADR-0015's env-knob consequence still reads "all four are shape-validated up front", but `validate_duration_knob` now enforces shape **plus** a non-zero range check (`AGENT_TIMEOUT`, `AGY_PRINT_TIMEOUT`, `GEMINI_BACKSTOP_MARGIN`; `AGENT_KILL_AFTER=0` stays legal via `allow_zero`) **plus** a Go-duration subset for `AGY_PRINT_TIMEOUT`. Verified against the code at this head: `.agent/scripts/cross_model_review.sh:156-181` vs the ADR text. Valid — the ADR under-describes an enforcement rule it is the record for, which is a documentation-accuracy defect, not a style nit. Fix: one line at `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md:100` — say the four knobs are shape- and range-validated up front (zero rejected where it would remove a bound; `AGENT_KILL_AFTER=0` excepted), with `AGY_PRINT_TIMEOUT` additionally held to agy's Go-duration subset. Non-blocking for merge; no code change, no test change.

### Rounds carried forward
- Round 1 @ `c00b2c7`: 2 must-fix, 9 suggestions — all resolved and verified by round 2.
- Round 2 @ `48d0ca9`: 1 must-fix, 2 suggestions — all resolved and verified by round 3.
- Round 3 @ `c1e84de`: approved, 0 must-fix, 1 suggestion — the item above, still open.
- Nothing from an earlier round is re-listed; no round-3 conclusion is contradicted by the code read at this head. The only commits after `c1e84de` are progress.md bookkeeping (`7f2edf7`, `3b762b4`), so the round-3 review covers the shipped code in full.

### False positives
- (Copilot) Not a finding at all: the review body is a quota-exhaustion notice with no code claims. Recorded here so the absence of bot findings is not mistaken for a clean bot review; treat this PR as reviewed by the local timeline plus CI only.

### Merge recommendation
Merge-ready. Zero open must-fix findings, four green CI checks on the head, three converging local review rounds (2 → 1 → 0 must-fix). The single open suggestion is a one-line ADR wording correction with no code impact — the permanent fix is a minute's work, so the preferred path is to apply it via `/address-findings` and merge; merging first and correcting the ADR in a follow-up is acceptable but leaves an inaccurate governance record in `main`. No GitHub review is pending: Copilot is out of quota, so nothing is gained by waiting.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 12:27 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: findings
**Decision**: address

Address then merge: apply the one open suggestion (ADR-0015 line 101 says the four env knobs are "shape-validated"; they are shape + non-zero range + a Go-duration subset for AGY_PRINT_TIMEOUT), then merge.
