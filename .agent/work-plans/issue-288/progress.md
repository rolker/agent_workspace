---
issue: 288
---

# Issue #288 — cross_model_review.sh: headless gemini permission denial reported as a completed review

## Plan Authored
**Status**: complete
**When**: 2026-09-22 09:30 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-288/plan.md` at `8b2733e`

Feed agy the prompt over stdin via stream-json (fixes #274) and validate the result event so a headless permission denial with empty output is reported as a failed review (fixes #288); a shared helper serves both tmux and sync modes.

## Plan Review
**Status**: complete
**When**: 2026-09-22 09:34 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**PR**: https://github.com/rolker/agent_workspace/pull/311 — [PLAN] cross_model_review.sh: headless gemini permission denial reported as a completed review
**Issue**: #288 — cross_model_review.sh: headless gemini permission denial reported as a completed review (plan also closes #274)
**Plan**: `.agent/work-plans/issue-288/plan.md` at `8b2733e`
**Branch**: `feature/issue-288`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One code path, one PR. Closing #274 alongside #288 is justified — both are the same gemini invocation arm. |
| Issue alignment | Needs work | #288 fully addressed. #274 asks for stdin **and** prompt trimming ("Ideally both"); the plan does not mention trimming at all, not even to defer it. |
| File targeting | Needs work | `.gitignore` is missing from the Files-to-Change table although the plan introduces a new artifact file. Which component owns writing the findings file in tmux mode is left unspecified. |
| Consequences | Needs work | The new `review-gemini-stream.ndjson` is not covered by any existing ignore rule; the tmux wrapper's `> findings 2>&1` redirect is a consequence of the helper change that the plan does not trace. |
| Principle alignment | Good, with one gap | "Enforcement over documentation" is honoured (mechanical result-event detection). "Test what breaks" is undercut: the default execution path (tmux) stays untested. |
| ADR compliance | Good | ADR-0003/0004/0005/0013 assessments hold. Artifacts remain uncommitted **provided** finding 1 is fixed. |
| ROS conventions | N/A | Workspace-only plan. |

### Findings

1. **[Consequences — must-fix]** The raw stream sidecar leaks into git. `.gitignore` only covers `.agent/work-plans/*/review-*-prompt.md` and `.agent/work-plans/*/review-*-findings.md` (lines 63–64). `review-gemini-stream.ndjson` matches neither, so it shows up as untracked and can be committed — and it echoes the entire prompt (the 242 KB diff from #274) back, which is precisely the recursive-bloat failure mode #193 and that gitignore comment exist to prevent. Add a `.gitignore` row (`.agent/work-plans/*/review-*.ndjson`) to the Files-to-Change table, or name the file so it matches the existing `review-*-findings.md` rule, and add a `git check-ignore` assertion to the test suite. Separately: under `--work-dir` / `--work-plans-dir` the sidecar lands in a *project* repo whose `.gitignore` this workspace does not control — say what happens there (write the stream only under the resolved dir when ignored, or always to a tmpdir).

2. **[File targeting — must-fix]** Findings-file double-writer in tmux mode. Both current gemini arms end with `> "$findings" 2>&1` (`cross_model_review.sh:82`, `:110`). If `_agy_review.sh` writes the findings file itself (as Approach step 1 states), the wrapper redirect must be dropped for gemini — otherwise the shell truncates the file and the helper's own write races/clobbers it. The alternative (helper writes the response to stdout, wrapper keeps redirecting) is cleaner but then the helper's diagnostics must not go to stdout. The plan does not choose. Decide explicitly and assert it.

3. **[Test gaps — must-fix]** Every existing test in `test_cross_model_review.sh` passes `--sync`; `build_invoke_cmd` — the **default** execution path — has zero coverage today, and all four proposed tests are sync-shaped. The tmux path is exactly where the new risk lives: quoting the helper invocation into a single shell command string for `tmux new-session`, and the redirect interaction in finding 2. Add a test that either captures `build_invoke_cmd`'s output directly or runs with a mock `tmux` on `PATH` that records the command string, asserting the helper path and its three arguments are quoted and that no stray findings-file redirect remains.

4. **[Approach — concern]** The "do not run shell commands" prompt paragraph is applied to **all** agents (Approach step 3), but only agy needs it. `codex exec` has shell as essentially its only file-reading tool, so the instruction contradicts the same paragraph's "reading repository files for context is fine" and can strip codex of context; `claude -p` and `copilot -p` lose grep/git lookups they use productively. Scope the paragraph to the gemini prompt or make the footer agent-conditional, and make `test_prompt_has_tool_use_guidance` assert present-for-gemini / absent-for-codex rather than just "footer text present".

5. **[Edge case — concern]** `--print-timeout` expiry is unverified. `agy --help` documents the default as `0s` ("waits until the turn completes"); the script forces `30m`. The plan verifies the SUCCESS and denied paths against agy 1.2.8 but says nothing about what the stream emits on timeout. If expiry yields a `result` event with `status: SUCCESS` and a truncated `response`, the plan's success test (`result` + SUCCESS + non-empty) passes a partial review as complete — the same silent-degradation class as #288 itself. Verify the timeout path, treat it as failure or annotate it like `denied_actions`, and add a mock test (`MOCK_AGY_TRUNCATED=1`).

6. **[Issue alignment — suggestion]** #274's second half is dropped silently. Stdin removes the argv ceiling, but every agent still receives a prompt dominated by `.agent/work-plans/**` review bookkeeping — quota cost and signal dilution. Either add a path exclusion to the diff generation (`gh pr diff` piped through a filter, or `git diff ... -- ':(exclude).agent/work-plans/**'` in branch mode) or state in the plan why trimming is deferred and open the follow-up issue. A plan that closes #274 should account for everything #274 asked for.

7. **[Edge case — suggestion]** jq handling. jq is confirmed a bootstrap dependency (`bootstrap.sh:42`) and exit 1 matches the script's documented "missing dependencies" code — good. But `_agy_review.sh` is executed standalone, so it should carry its own `command -v jq` guard rather than trusting the caller. Also note `set -euo pipefail` + `jq ... | agy ...`: if agy exits early, jq dies on SIGPIPE and pipefail surfaces jq's status, masking agy's. Capture agy's status explicitly (`PIPESTATUS` or a temp file) and capture agy's stderr to a separate file — the plan wants the stderr notice as a failure reason, but stdout is NDJSON, so `2>&1` is not available.

8. **[Documentation — suggestion]** Approach step 1 says failure makes "the script exit 3". That is true only in **sync** mode; in tmux mode `cross_model_review.sh` has already exited 0 at launch and the `--- Review failed ---` marker appears later, asynchronously. Correct the wording, and make the `review-code` SKILL.md note (Approach step 5, around `SKILL.md:358`) describe the marker + reason line, not an exit code.

9. **[Scope — acceptable, no action]** Two issues in one PR is fine here. Verified: PR #311's body lists `Closes #288` before `Closes #274`, so the script's own first-closure-keyword resolver routes artifacts to 288; `merge_pr.sh` derives `ISSUE_NUM` from the branch name (`feature/issue-288`), so roadmap/gate handling is unambiguous; and neither issue has a `docs/ROADMAP.md` row, so no stale roadmap entry results. Worth one line in the PR body noting that #274 has no timeline of its own.

10. **[Edge case — suggestion, low]** Consider passing `--disable-slash-commands` to agy. Prompt content is author-controlled diff text and slash/skill expansion in print mode is an avoidable variable.

11. **[Process — note, no penalty]** `review-issue` was not run for #288 (no `## Issue Review` entry in this timeline). Optional step; noted for completeness.

### Summary

The diagnosis is right and the stream-json approach is the correct fix for both bugs — the plan is well-researched and the failure-detection design is sound. It is not ready to implement as written: a new artifact file has no ignore rule, the tmux arm's findings-file ownership is undefined, and the one execution path the change actually ships on (tmux) has no test coverage in the plan or the existing suite.

### Recommended Actions

- [ ] Add a `.gitignore` row for the stream sidecar (and decide its behaviour under `--work-dir` / `--work-plans-dir`), with a `git check-ignore` assertion in the test suite
- [ ] State explicitly whether `_agy_review.sh` or the wrapper writes the findings file, and drop the conflicting `> "$findings" 2>&1` from the gemini tmux arm accordingly
- [ ] Add a tmux-mode test (mock `tmux`, or direct `build_invoke_cmd` capture) covering the helper invocation string's quoting and redirect
- [ ] Scope the "do not run shell commands" paragraph to the gemini prompt; assert present-for-gemini / absent-for-codex
- [ ] Verify agy's `--print-timeout` expiry behaviour and add a truncated-response failure test
- [ ] Address #274's prompt-trimming half, or record in the plan and PR why it is deferred
- [ ] Give the helper its own jq guard, explicit agy exit-status capture (not pipefail), and separate stderr capture
- [ ] Fix the "exits 3" wording (sync-only) and write the `review-code` note against the marker + reason line

## Plan Authored
**Status**: complete
**When**: 2026-09-22 09:38 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Plan**: `.agent/work-plans/issue-288/plan.md` at `2fd9866`

Revision after plan review round 1: the helper owns the findings file with no wrapper redirect, agy's raw stream lives in mktemp files (kept only on failure) so nothing new lands under the work-plans dir, the print-timeout stderr marker is treated as a failed review, the tool-use paragraph is gemini-only, and a mock-tmux test covers the default execution path.
