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
