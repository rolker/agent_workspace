---
issue: 344
---

# Issue #344 — Drop the Copilot CLI as a cross-model reviewer (keep the hosted Copilot PR review as a triage source)

## Issue Review
**Status**: complete
**When**: 2026-10-13 11:02 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**Issue**: #344

### Scope Assessment

**Well-scoped?** Yes. One PR: delete one reviewer arm, its dispatch/validation handling, its tests, and the lines that name it. Nothing new is built. The owner's decision of 2026-10-13 ("It uses the same models under the hood as we already use, so let's stop using copilot cli and only use copilot on github") settles whether to drop it; this review only sizes the removal. Evidence from today's runs supports the sizing: the Copilot CLI's shell is denied headless so it reviewed the diff only; its last round on the #345 work (September) was skipped because quota was exhausted; and it found nothing today that Gemini, Codex and the Claude adversarial pass missed. Its invocation was also never confirmed live after #313 (the `PENDING ONE LIVE CONFIRMATION` block in `_cli_review.sh`), so removing it deletes unverified code, not a working path.
**Right repo?** Yes — workspace infrastructure (`.agent/scripts/`, `.claude/skills/`, `AGENTS.md`, `docs/`).
**Serves**: Quality of the work (reviewers that add independent signal, not same-model repeats) — `docs/design.md#review-loop-and-timeline`
**Design picture?** No change. The Review loop section says only "Reviewers outside Claude run in parallel and synchronously through `cross_model_review.sh` (ADR-0015)" (line 448) and does not name the Copilot CLI; the Decision register row for ADR-0015 ("in force") stays accurate. No design text needs editing, so no "Keep one current design" row. The sizing the issue and the owner asked for is below.
**Dependencies**: #336 (same files) is CLOSED, so the ordering the issue asks for is satisfied. #342 (external reviewer contract, open) lists Copilot in its title; the scope-change note was already posted there, but its title still reads "(Codex, Gemini, Claude, Copilot)" and should be retitled by whoever next touches it. Open pull request #390 does not touch these files.

**Where Copilot-the-CLI-reviewer lives (verified by grep in this worktree)**

| File | What to remove |
|---|---|
| `.agent/scripts/cross_model_review.sh` | `["copilot"]="copilot"` in `AGENT_BINS` (line 185); "Supported agents" header and example (lines 13, 54); `copilot` in the `_cli_review.sh` helper-availability condition (line 602) and the comments at 19, 39, 195, 324, 1444 |
| `.agent/scripts/_cli_review.sh` | the whole `copilot)` arm (lines 569-614, including the PENDING-LIVE-CONFIRMATION note), `codex\|claude\|copilot` in the agent whitelist and its error text (169-170), the usage line (118), the header (2, 7, 17) and the "Verified against ... copilot 1.0.61" paragraph (102-112) |
| `.agent/scripts/tests/test_cross_model_review.sh` | about 73 mentions: the `copilot` mock (2803-2823), `copilot` in the multi-agent argv/EXIT/timeout/concurrency/signal tests (2868-2980, 3236-3263), the missing-CLI cases (3153-3169), `CLI_AGENTS` (3300), the error-marker cases (3465-3495), `test_copilot_stdin_contract` (4110, called at 5568), and the partial-failure cases (4219-4228) |
| `.claude/skills/review-code/SKILL.md` | agent list at 93; "not ported" note at 97-98 (reword: no Copilot-CLI specialist, now by decision); alias `copilot-cli` -> `copilot` and the canonical key list (364-365); the three example `--agents` lines (376-381); "e.g. Copilot while its quota is exhausted" (385); helper description (425) |
| `AGENTS.md` (Ask-First) | Script Reference row for `cross_model_review.sh`: "`_cli_review.sh` for codex/claude/copilot"; row for `_cli_review.sh`: "Codex / Claude / Copilot turn" and "copilot's `-s` response". Line 10 (Copilot framework adapter) stays. |
| `docs/decisions/ADR-0015` | Context (line 16), Decision item 3 (53), Consequences (98, 118) name Copilot |
| `.agent/knowledge/review_depth_classification.md` | Nothing: it says "all available non-caller agents" and its only Copilot hit is the adapter file path. The issue's bullet for this file is a no-op. |
| `docs/design.md` | Nothing (see Design picture). |
| `docs/roadmap.md` | No row names the Copilot CLI reviewer or #344 today, so there is nothing to edit by hand; `update_roadmap.sh` handles the done-marking at merge. |

Stays, deliberately: `.github/copilot-instructions.md` and the Copilot rows in `framework_config.sh`, `detect_*`, `set_git_identity_env.sh` and `check-commit-identity.py` (Copilot as an agent identity); `merge_pr.sh` and `run-issue` handling of the hosted `copilot-pull-request-reviewer` check-run (#300); `triage-reviews` treating Copilot as a bot source; historical `progress.md` / `plan.md` files under `.agent/work-plans/` and the inspiration digests (history).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | Removal of an unverified, redundant reviewer arm with a recorded owner decision and evidence it adds nothing. |
| Use the main tool fully; keep the work tool-neutral | Watch | Copilot stays supported as a framework identity and adapter (`.github/copilot-instructions.md`); only the reviewer role goes. Keep those files and rows untouched so the neutrality claim still holds. |
| A change includes its consequences | Action needed | Every place that names the Copilot CLI as a reviewer must change in the same PR (table above): the AGENTS.md Script Reference rows are Ask-First, so the PR lists the edits and the owner approves them, not this review. |
| Test what breaks | Action needed | Do not only delete the tests: add a regression test that `--agents copilot` and `--agent copilot` fail with exit 2 and a message naming the supported agents (gemini, codex, claude), and that `_cli_review.sh copilot ...` is rejected as an unsupported agent. Both exist as generic paths (`cross_model_review.sh` lines 495-497 and 511-513; `_cli_review.sh` 169-170) but are untested for this key. |
| Know whether it works | Watch | The suite is large (5,600 lines). After the deletion, run `.agent/scripts/tests/run_script_tests.sh` and name the suites that ran; mock-agent counts in the concurrency and signal tests (`codex,copilot` pairs) need a different second agent rather than a bare deletion, or those tests lose their two-agent case. |
| Verify before claiming | OK | The decision and today's evidence are recorded here from the owner's words and the run logs, not asserted fresh. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0015 (parallel sync is the only review dispatch mode) | Yes | Names Copilot in Context, Decision item 3 and two Consequences. Its decision (parallel, synchronous, bounded dispatch) is unchanged. ADR-0008 permits only cross-reference addenda to an accepted ADR, and rewording Decision or Consequences needs a superseding ADR, so the right edit is a Status-line note ("Copilot CLI dropped as a reviewer by owner decision 2026-10-13, #344; the dispatch structure is unchanged") and leaving the body as the record of what was true then. |
| ADR-0013 (progress.md entry vocabulary) | No | `Issue Review` / `External Review` entries are untouched; hosted Copilot review is still consumed as external review. |
| ADR-0017 (design document is the current picture) | Checked, not triggered | No design section changes. |

### Consequences

- AGENTS.md Script Reference: two rows (Ask-First: list the exact text change, do not pre-approve).
- review-code step 5e's alias table: a Copilot CLI session as the caller maps to no reviewer to exclude, so it dispatches gemini, codex and claude; say so rather than leaving a dangling `copilot-cli` alias.
- `make validate` and pre-commit: the `validate-script-tests` hook runs the whole suite, so the PR must show it green.
- #342's title and body list Copilot; update after merge.

### Recommendations

- Remove the copilot arm and every reviewer-role mention in the files listed in the table in Scope Assessment, in separate commits for the scripts, the tests, the skill and the docs, so each is reviewable alone.
- Make `--agents copilot` and `--agent copilot` fail with exit 2 and the existing "Unknown agent ... Supported agents: ..." message, and add tests for both plus the helper's rejection of `copilot` as an agent; sort the "Supported agents" list in the message (it prints associative-array order today).
- Add a Status-line note to ADR-0015 (ADR-0008 cross-reference addendum) instead of rewording its body.
- List the two AGENTS.md Script Reference row edits in the PR description for the owner's approval; do not edit them before that.
- Keep the hosted Copilot PR review wiring untouched (`merge_pr.sh` check-run handling, `run-issue` step, `triage-reviews` bot-source text) and say so in the PR so a reviewer does not mistake it for a missed removal.
- Rework (not just delete) tests that pair `codex,copilot` so they keep a two-agent case using `codex,claude`.

### Actions
- [ ] Every place that names the Copilot CLI as a reviewer must change in the same PR (table above): the AGENTS.md Script Reference rows are Ask-First, so the PR lists the edits and the owner approves them, not this review.
- [ ] Do not only delete the tests: add a regression test that `--agents copilot` and `--agent copilot` fail with exit 2 and a message naming the supported agents (gemini, codex, claude), and that `_cli_review.sh copilot ...` is rejected as an unsupported agent. Both exist as generic paths (`cross_model_review.sh` lines 495-497 and 511-513; `_cli_review.sh` 169-170) but are untested for this key.
- [ ] Remove the copilot arm and every reviewer-role mention in the files listed in the table in Scope Assessment, in separate commits for the scripts, the tests, the skill and the docs, so each is reviewable alone.
- [ ] Make `--agents copilot` and `--agent copilot` fail with exit 2 and the existing "Unknown agent ... Supported agents: ..." message, and add tests for both plus the helper's rejection of `copilot` as an agent; sort the "Supported agents" list in the message (it prints associative-array order today).
- [ ] Add a Status-line note to ADR-0015 (ADR-0008 cross-reference addendum) instead of rewording its body.
- [ ] List the two AGENTS.md Script Reference row edits in the PR description for the owner's approval; do not edit them before that.
- [ ] Keep the hosted Copilot PR review wiring untouched (`merge_pr.sh` check-run handling, `run-issue` step, `triage-reviews` bot-source text) and say so in the PR so a reviewer does not mistake it for a missed removal.
- [ ] Rework (not just delete) tests that pair `codex,copilot` so they keep a two-agent case using `codex,claude`.

## Checkpoint
**Status**: complete
**When**: 2026-10-13 11:03 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

"Proceed, AGENTS.md rows included": all eight Issue Review actions (90b4d026) proceed to the plan. The owner's answer is the Ask-First approval for the two AGENTS.md Script Reference rows (`cross_model_review.sh` and `_cli_review.sh`) — those two rows only — to be edited in the same PR. Owner's direction on the issue, verbatim (2026-10-13): "It uses the same models under the hood as we already use, so let's stop using copilot cli and only use copilot on github."

## Plan Authored
**Status**: complete
**When**: 2026-10-13 11:04 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-344/plan.md` at `cc659563`

Remove the copilot arm from the helper and dispatcher, rework the tests (adding rejection regression tests for both flags and the helper), then update review-code, the two approved AGENTS.md rows and an ADR-0015 status note, in four commits. Hosted Copilot review wiring is untouched.

## Plan Review
**Status**: complete
**When**: 2026-10-13 11:07 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: needs-work

**Issue**: #344 — Drop the Copilot CLI as a cross-model reviewer (keep the hosted Copilot PR review as a triage source)
**Plan**: `.agent/work-plans/issue-344/plan.md` at `cc659563`
**Branch**: `feature/issue-344`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, six files, four commits; nothing new built. |
| Issue alignment | Good | Covers all three acceptance items and all eight Issue Review actions; the issue's `--copilot` flag bullet is moot (no such flag in `cross_model_review.sh`). Serves: "Quality of the work (reviewers that add independent signal, not same-model repeats) — `docs/design.md#review-loop-and-timeline`" — goal exists (README `### Quality of the work`), anchor exists (design.md line 402). |
| File targeting | Good | Independent `grep -rIi copilot` (excluding work-plans and inspiration digests) gives 55 files; every hit outside the six planned files is framework identity (`detect_*`, `framework_config.sh`, `set_git_identity_env.sh`, `configure_git_identity.sh`, `check-commit-identity.py`, adapter-path rows), hosted review (`merge_pr.sh`, `test_merge_pr_gate.sh`, `run-issue`, `triage-reviews`, `onboard-project`, `test_triage_reviews_integration.sh`, design.md:501) or history (ADR-0004/0006/0013/0014, roadmap prose, test fixtures quoting "(Copilot R2)"). The removal map is complete. |
| Consequences | Good | `docs/design.md` names no Copilot CLI reviewer (line 448 says "Reviewers outside Claude"); the ADR-0015 register row stays "in force" because the dispatch decision is unchanged. `docs/roadmap.md` has no #344 or Copilot-CLI-reviewer row. No design change-log row is due. |
| Principle alignment | Needs work | Test what breaks: one planned assertion contradicts the helper's contract (finding 1); one is vacuous as written (finding 2). |
| ADR compliance | Good | ADR-0015 Status-line note matches house practice: the #320 and #363 notes already sit in that Status paragraph, and the body stays as the record. ADR-0008 lists ADR pointers as the example; an issue-pointer note is the precedent ADR-0015 itself set (finding 4 is wording only). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment — must-fix]** Step 2 says "Each new test must also assert no findings file was written", but test (d) runs `_cli_review.sh` directly, and the helper truncates the findings file first (`: > "$FINDINGS_FILE"`, line 136) and `usage_fail` then writes "copilot review could not be started. / Reason: unsupported agent 'copilot' ..." into it before exiting 2 (lines 155-165). The existing `grok` case (test file ~4198-4205) asserts exactly that reason is in the file. Amend the plan: for (d), assert exit 2 and that the findings file names `unsupported agent 'copilot'`; keep "no findings file" only for (a)-(c), where `cross_model_review.sh` exits at argument parsing.
2. **[Principle alignment — suggestion]** "assert ... no copilot mock was invoked" is vacuous once the `copilot)` mock is deleted: with no `copilot` binary in `MOCK_BIN` nothing could record an invocation. Put a sentinel `copilot` stub in `MOCK_BIN` for the four new tests that touches a marker file, and assert the marker is absent; for (b) also assert the codex mock left no `codex.start`/argv file.
3. **[File targeting — suggestion]** The test rework list mislabels and misses cases: 2924-2937 (one agent fails, others complete, `gemini,codex,copilot`) is not listed; 4219-4228 is `test_cli_no_temp_leak`, not partial failure, and its "success + three failure modes" label must change (copilot's ERRMARK case was never a failure mode after #313); the concurrency test's conditional resolves to two agents, because the agy mock writes `agy.pid`/`agy.end` but no `.start` file, so `codex,claude` it is and the "all three agents" PASS text changes; `test_cli_helper_missing_is_unavailable`'s title names copilot. Settle these in the plan rather than at implementation time.
4. **[ADR compliance — suggestion]** Write the ADR-0015 note as a sentence appended to the existing Status paragraph after the #363 sentence, and name the passages it qualifies (Context, Decision item 3, the first and last Consequences bullets) so a reader of the body knows which mentions are history.
5. **[Principle alignment — suggestion]** Pin the "Supported agents" format: `paste -sd,` gives `claude,codex,gemini`, while the plan's test text says `claude, codex, gemini` and today's message is space-separated. Choose one, sort under `LC_ALL=C`, and assert the exact string at both call sites.

### Summary

The removal map is complete and the hosted-review, identity and history hits are correctly left alone; design.md and the roadmap need no change. One test instruction contradicts `_cli_review.sh`'s usage-error contract and must be corrected before implementation; the rest are precision fixes to the test rework list.

### Recommended Actions

- [ ] Amend step 2: for the `_cli_review.sh copilot` test, assert exit 2 and the `unsupported agent 'copilot'` reason in the findings file; limit "no findings file" to the three `cross_model_review.sh` rejection tests.
- [ ] Add a sentinel `copilot` stub to `MOCK_BIN` in the new rejection tests so "no copilot invocation" is a real assertion.
- [ ] List the 2924-2937 one-fails test, relabel 4219-4228 as `test_cli_no_temp_leak` (fix its "three failure modes" label), fix the concurrency test to two agents with its PASS text, and retitle `test_cli_helper_missing_is_unavailable`.
- [ ] Append the ADR-0015 note to the existing Status paragraph and name the body passages it qualifies.
- [ ] Fix the "Supported agents" separator and sort locale, and assert the exact string.

## Checkpoint
**Status**: complete
**When**: 2026-10-13 11:09 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

"Proceed; fix in plan first": implementation starts; its first commit amends the plan with the Plan Review (06246fa0) must-fix (test (d), `_cli_review.sh copilot` run directly, asserts exit 2 and the "unsupported agent" reason in the findings file; "no findings file" only for (a)–(c)) and the four suggestions (stand-in copilot mock leaving a marker; corrected test-rework list incl. the one-agent-fails test, the `test_cli_no_temp_leak` relabel, the concurrency test at two agents, the `test_cli_helper_missing_is_unavailable` title; ADR-0015 note after the #363 sentence naming the passages it qualifies; one exact sorted "Supported agents" format asserted at both print sites), then builds. No third plan review; the pre-push code review sees both.
