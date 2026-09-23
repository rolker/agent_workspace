# Plan: Gemini (agy) reviews fail on real branches: headless read_file denied, output-token limit on large prompts

**Revision 2** — folds in all 12 Recommended Actions from the `## Plan Review`
at commit `ce728e4` (verdict: needs-work) per the owner's checkpoint decision
("Revise the plan (Recommended): fold in all 12 items ... then one more plan
review"). Each subsection below is tagged `[Review #N]` so the next
review-plan pass can trace every item back to its source finding.

## Issue

https://github.com/rolker/agent_workspace/issues/336

## Context

Two independent bugs, bundled by owner decision (same failure class: a
helper misreads its CLI's real output):

1. **Gemini/agy** (`.agent/scripts/_agy_review.sh`, `cross_model_review.sh`):
   on real Deep-tier reviews, agy either auto-denies a `ViewFile` read in
   headless mode (empty response, already correctly reported as a failure)
   or returns result status `ERROR` with "response was cut off because it
   exceeded the output token limit" (also already reported as a failure,
   but with a generic reason). **Owner's chosen fix ("Prompt change,
   Recommended")**: stop telling Gemini it may read files at all, and tell
   it to be concise. No machine-config change (no `read_file` permission
   allow-rule) — that stays the owner's own-machine decision, out of scope.

2. **Claude arm of `_cli_review.sh`** (owner-approved addendum, from #340):
   every observed claude failure mode — bad `--model` (404), `--max-turns`
   hit, `--max-budget-usd` hit — exits **1**, and `_cli_review.sh` fails on
   that nonzero exit *before* it ever reads the JSON body, so the real
   reason (which is in the JSON) is discarded.

Both fixes land in the same branch as **separate commits** (per the issue
review's Recommendation and the owner's checkpoint decision).

## Live-captured claude failure shapes (claude 2.1.281, re-captured in full this session)

`claude --version` → `2.1.281 (Claude Code)`. All captured from an isolated
scratch directory (no repo context, no CLAUDE.md), `--permission-prompts
none`. `session_id` / `uuid` scrubbed to `<scrubbed>`; no other field
dropped or restructured. `[Review #4]`

**Bad `--model bogus-model-xyz`** — exit 1, `.result` carries the reason,
**no `.errors` key at all**, `api_error_status: 404`, `subtype: "success"`
despite `is_error: true`:

```json
{
  "api_error_status": 404,
  "duration_api_ms": 0,
  "duration_ms": 611,
  "fast_mode_disabled_reason": "sdk_opt_in_required",
  "fast_mode_state": "off",
  "is_error": true,
  "modelUsage": {},
  "num_turns": 1,
  "permission_denials": [],
  "queued_turn_count": 0,
  "result": "There's an issue with the selected model (bogus-model-xyz). It may not exist or you may not have access to it. Run --model to pick a different model.",
  "result_index": 0,
  "session_id": "<scrubbed>",
  "stop_reason": "stop_sequence",
  "subagent_stats": {"by_type": {}, "completed": 0, "failed": 0, "killed": {"parent": 0, "system": 0, "user": 0}, "max_depth": 0, "refused": {"budget": 0, "concurrency_limit": 0, "depth_limit": 0}, "requested": {"background": 0, "foreground": 0, "unset": 0}, "spawned": 0, "spawned_by_subagents": 0, "started_in_background": 0},
  "subtype": "success",
  "terminal_reason": "api_error",
  "total_cost_usd": 0,
  "type": "result",
  "usage": {"cache_creation": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0, "inference_geo": "", "input_tokens": 0, "iterations": [], "output_tokens": 0, "output_tokens_details": {"thinking_tokens": 0}, "server_tool_use": {"web_fetch_requests": 0, "web_search_requests": 0}, "service_tier": "standard", "speed": "standard"},
  "uuid": "<scrubbed>"
}
```

**`--max-turns 1`** — exit 1, `.errors` is an array, **`.result` is `null`**:

```json
{
  "duration_api_ms": 2561,
  "duration_ms": 2707,
  "errors": ["Reached maximum number of turns (1)"],
  "fast_mode_disabled_reason": "sdk_opt_in_required",
  "fast_mode_state": "off",
  "is_error": true,
  "modelUsage": {"claude-opus-5-5": {"cacheCreationInputTokens": 0, "cacheReadInputTokens": 19247, "canonicalModel": "claude-opus-5-5", "contextWindow": 1000000, "costBasis": "list", "costUSD": 0.0071774000000000004, "inputTokens": 2, "maxOutputTokens": 128000, "outputTokens": 166, "provider": "firstParty", "thinkingTokens": 50, "webSearchRequests": 0}},
  "num_turns": 2,
  "permission_denials": [{"tool_input": {"command": "~/.claude/bin/agent-status \"three ocean haiku\" \"DONE: haiku written, nothing pending\"", "description": "Update status line to show haiku task done"}, "tool_name": "Bash", "tool_use_id": "toolu_01ChTvAnFmDeesB9mJLXkSkw"}],
  "queued_turn_count": 0,
  "result_index": 0,
  "session_id": "<scrubbed>",
  "stop_reason": "tool_use",
  "subagent_stats": {"by_type": {}, "completed": 0, "failed": 0, "killed": {"parent": 0, "system": 0, "user": 0}, "max_depth": 0, "refused": {"budget": 0, "concurrency_limit": 0, "depth_limit": 0}, "requested": {"background": 0, "foreground": 0, "unset": 0}, "spawned": 0, "spawned_by_subagents": 0, "started_in_background": 0},
  "subtype": "error_max_turns",
  "terminal_reason": "max_turns",
  "total_cost_usd": 0.0071774000000000004,
  "type": "result",
  "usage": {"cache_creation": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 19247, "inference_geo": "not_available", "input_tokens": 2, "iterations": [{"cache_creation": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 19247, "input_tokens": 2, "output_tokens": 166, "type": "message"}], "output_tokens": 166, "output_tokens_details": {"thinking_tokens": 50}, "server_tool_use": {"web_fetch_requests": 0, "web_search_requests": 0}, "service_tier": "standard", "speed": "standard"},
  "uuid": "<scrubbed>"
}
```

**`--max-budget-usd 0.0001`** — exit 1, `.errors` array, `.result` is `null`:

```json
{
  "duration_api_ms": 0,
  "duration_ms": 3429,
  "errors": ["Reached maximum budget ($0.0001)"],
  "fast_mode_disabled_reason": "sdk_opt_in_required",
  "fast_mode_state": "off",
  "is_error": true,
  "modelUsage": {"claude-opus-5-5": {"cacheCreationInputTokens": 0, "cacheReadInputTokens": 19261, "canonicalModel": "claude-opus-5-5", "contextWindow": 1000000, "costBasis": "list", "costUSD": 0.0080202, "inputTokens": 2, "maxOutputTokens": 128000, "outputTokens": 208, "provider": "firstParty", "thinkingTokens": 170, "webSearchRequests": 0}},
  "num_turns": 1,
  "permission_denials": [],
  "queued_turn_count": 0,
  "result_index": 0,
  "session_id": "<scrubbed>",
  "stop_reason": "end_turn",
  "subagent_stats": {"by_type": {}, "completed": 0, "failed": 0, "killed": {"parent": 0, "system": 0, "user": 0}, "max_depth": 0, "refused": {"budget": 0, "concurrency_limit": 0, "depth_limit": 0}, "requested": {"background": 0, "foreground": 0, "unset": 0}, "spawned": 0, "spawned_by_subagents": 0, "started_in_background": 0},
  "subtype": "error_max_budget_usd",
  "terminal_reason": "budget_exhausted",
  "total_cost_usd": 0.0080202,
  "type": "result",
  "usage": {"cache_creation": {"ephemeral_1h_input_tokens": 0, "ephemeral_5m_input_tokens": 0}, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0, "inference_geo": "", "input_tokens": 0, "iterations": [], "output_tokens": 0, "output_tokens_details": {"thinking_tokens": 0}, "server_tool_use": {"web_fetch_requests": 0, "web_search_requests": 0}, "service_tier": "standard", "speed": "standard"},
  "uuid": "<scrubbed>"
}
```

**Success** (`echo 'reply with exactly: OK' | claude -p ...`) — exit 0,
`.result` present, no `.errors` key, requested by the review as the fourth
shape to capture:

```json
{
  "api_error_status": null,
  "duration_api_ms": 2254,
  "duration_ms": 2369,
  "fast_mode_disabled_reason": "sdk_opt_in_required",
  "fast_mode_state": "off",
  "first_content_frame_ms": 834,
  "is_error": false,
  "modelUsage": {"claude-opus-5-5": {"cacheCreationInputTokens": 7291, "cacheReadInputTokens": 11945, "canonicalModel": "claude-opus-5-5", "contextWindow": 1000000, "costBasis": "list", "costUSD": 0.062805, "inputTokens": 2, "maxOutputTokens": 128000, "outputTokens": 104, "provider": "firstParty", "thinkingTokens": 100, "webSearchRequests": 0}},
  "num_turns": 1,
  "permission_denials": [],
  "queued_turn_count": 0,
  "result": "OK",
  "result_index": 0,
  "session_id": "<scrubbed>",
  "stop_reason": "end_turn",
  "subagent_stats": {"by_type": {}, "completed": 0, "failed": 0, "killed": {"parent": 0, "system": 0, "user": 0}, "max_depth": 0, "refused": {"budget": 0, "concurrency_limit": 0, "depth_limit": 0}, "requested": {"background": 0, "foreground": 0, "unset": 0}, "spawned": 0, "spawned_by_subagents": 0, "started_in_background": 0},
  "subtype": "success",
  "terminal_reason": "completed",
  "time_to_request_ms": 115,
  "total_cost_usd": 0.062805,
  "ttft_ms": 1835,
  "ttft_stream_ms": 834,
  "type": "result",
  "usage": {"cache_creation": {"ephemeral_1h_input_tokens": 7291, "ephemeral_5m_input_tokens": 0}, "cache_creation_input_tokens": 7291, "cache_read_input_tokens": 11945, "inference_geo": "not_available", "input_tokens": 2, "iterations": [{"cache_creation": {"ephemeral_1h_input_tokens": 7291, "ephemeral_5m_input_tokens": 0}, "cache_creation_input_tokens": 7291, "cache_read_input_tokens": 11945, "input_tokens": 2, "output_tokens": 104, "type": "message"}], "output_tokens": 104, "output_tokens_details": {"thinking_tokens": 100}, "server_tool_use": {"web_fetch_requests": 0, "web_search_requests": 0}, "service_tier": "standard", "speed": "standard"},
  "uuid": "<scrubbed>"
}
```

Two things this confirms that the reorder logic (Approach step 3) depends
on: (a) the bad-model shape has **no `.errors`** and the reason lives in
`.result` even though `subtype` is `"success"`; a reader must not assume
`.errors` is always present when `is_error` is true. (b) All three failure
shapes exit **1** — today's `CLI_EXIT -ne 0` short-circuit before any JSON
read discards every one of these reasons.

A "not logged in" shape and a real agy output-token-cutoff shape could not
be captured live in this session — the former needs de-authenticating the
installed CLI (would break other work in this environment), the latter
needs an extremely large real prompt/response that reliably exceeds agy's
output-token ceiling, which is neither cheap nor deterministic to trigger
on demand. Both are left uncaptured; see the cutoff-handling item below for
how the plan compensates. `[Review #4, #7]`

## Approach

1. **Gemini prompt change** (`.agent/scripts/cross_model_review.sh`,
   gemini-only `## Tool Use` heredoc, ~line 1119-1136, plus the comment
   immediately above the per-agent loop at ~line 1111-1114):
   - Replace "You may read files in the repository for surrounding context"
     with: the diff and (when present) the Plan Context section are the
     *only* material available; there is no file-reading tool in this
     session; **do not call any tools** (file reads and shell commands are
     both denied in this headless session and a denied call ends the
     review with no output); if context is missing, say so as a
     `suggestion`-severity row or in the `### Summary` — never invent it,
     and never simulate having read a file. Keep the existing "Do NOT run
     shell commands" sentence (it already covers the shell-command half).
     `[Review #9]`
   - Add a concise-output instruction to the **same gemini-only heredoc**
     (not the shared `PROMPT_FOOTER`): ask for the findings table and a
     short summary only, explicitly not restating the diff or quoting
     large spans back — this is the mitigation for the output-token-limit
     failure. `[Review #9]`
   - Update the stale comment above the per-agent loop ("Reading files is
     permitted, so the reviewer keeps that.") to describe the new
     no-tools policy instead — it becomes false the moment the heredoc
     changes. `[Review #8]`
   - This block is already gemini-only (confirmed in the issue review) —
     no isolation change needed, but see the new test in item 4 below that
     makes the isolation an assertion, not just a fact about the code.

2. **Treat agy's output-token cutoff as a clear failure**
   (`.agent/scripts/_agy_review.sh`, the `STATUS != "SUCCESS"` branch,
   ~line 249-251): add phrase detection against **`ERROR_MSG` and the agy
   stderr excerpt only** — never against `RESPONSE`. Rationale: `RESPONSE`
   is the model's own text and can legitimately contain the phrase (this
   plan's own diff mentions "output token limit" verbatim, and a real
   review of that diff would otherwise mis-classify an unrelated ERROR as
   a cutoff). The existing code already builds its failure message from
   `ERROR_MSG` alone (never `RESPONSE`), so this item only adds pattern
   matching on top of what's already read, not a new data source. `[Review #7]`
   - On a match (`cut off` and `output token limit` both present in
     `ERROR_MSG` or the stderr excerpt, case-insensitive), emit:
     `"response was cut off because it exceeded the output token limit
     (status ERROR); the prompt or response was too large for this
     turn"`. Otherwise keep the existing generic
     `"result status ${STATUS}${ERROR_MSG:+: ${ERROR_MSG}}"`.
   - **Where agy actually puts this text is not verified.** The mock
     coverage below is explicitly modelled on the issue's quoted CLI text
     (`.error` string field, following the existing `MOCK_AGY_ERROR`
     convention of an object `{code, message}` — see
     `test_agy_api_error_message_kept`), not on a captured live shape.
     State this in the test's comment rather than implying it was
     observed. `[Review #7]`
   - Never take agy's continue/retry path — any non-SUCCESS status
     (including a cutoff) is a failure, full stop; this is already true
     today (`STATUS != "SUCCESS"` fails unconditionally) and this item
     does not change that contract, only the reason text.

3. **Claude arm: parse JSON before failing on exit status, and preserve
   the exit-code reason when there is no JSON to read**
   (`.agent/scripts/_cli_review.sh`, the `claude)` case, ~line 325-382).
   Replace the current "exit check first, JSON check second" order with:

   ```
   run_cli ...
   if ! jq -e 'type == "object"' "$STDOUT_FILE" >/dev/null 2>&1; then
       # No parseable JSON at all. If the CLI also exited non-zero, that
       # exit code IS the reason (crash, OOM/SIGKILL → 137, etc.) — keep
       # today's message and its bound/marker notes so that information
       # isn't lost. [Review #1]
       if [[ "$CLI_EXIT" -ne 0 ]]; then
           fail "claude exited ${CLI_EXIT}$(bound_note)$(marker_note "$STDERR_FILE")$(log_excerpt 'claude stderr' "$STDERR_FILE")"
       fi
       fail "claude did not emit a JSON result object$(log_excerpt 'claude stdout' "$STDOUT_FILE")$(log_excerpt 'claude stderr' "$STDERR_FILE")"
   fi
   # ... read_claude_field calls (see below) ...
   if [[ "$IS_ERROR" == "true" ]]; then
       fail "claude returned is_error=true (subtype ${SUBTYPE})${CLAUDE_DETAIL:+: ${CLAUDE_DETAIL}}${CLI_EXIT:+$( [[ "$CLI_EXIT" -ne 0 ]] && printf ' (claude also exited %s)' "$CLI_EXIT" )}$(log_excerpt 'claude stderr' "$STDERR_FILE")"
   fi
   if [[ "$SUBTYPE" != "success" ]]; then
       fail "claude result subtype is '${SUBTYPE}', not 'success'${CLAUDE_DETAIL:+: ${CLAUDE_DETAIL}}$( [[ "$CLI_EXIT" -ne 0 ]] && printf ' (claude also exited %s)' "$CLI_EXIT" )$(log_excerpt 'claude stderr' "$STDERR_FILE")"
   fi
   # New: a clean-looking JSON result (is_error=false, subtype=success)
   # that still exited non-zero is not trustworthy — fail on the exit
   # code even though the JSON looked fine. [Review #1]
   if [[ "$CLI_EXIT" -ne 0 ]]; then
       fail "claude exited ${CLI_EXIT} despite a successful-looking JSON result$(bound_note)$(marker_note "$STDERR_FILE")$(log_excerpt 'claude stderr' "$STDERR_FILE")"
   fi
   ```

   This preserves every existing passing case (exit 0, is_error=false,
   subtype=success → success) while (a) never losing the exit code for a
   no-JSON crash (bad-model/max-turns/max-budget all still hit the
   `IS_ERROR`/`SUBTYPE` branches with `CLAUDE_DETAIL` populated from JSON,
   since they DO emit valid JSON — the reorder only changes ordering, not
   which branch a real capture lands in) and (b) adding a new terminal
   branch for the pathological "JSON says success but exit was nonzero"
   case that could not happen before because the exit check always fired
   first. `[Review #1]`

   - Field reads: add two new fields alongside the existing four
     (`IS_ERROR`, `SUBTYPE`, `RESULT`, `ERROR_MSG`):
     ```
     read_claude_field ERRORS_ARR '(.errors // []) | if type == "array" then (map(if type == "string" then . else tojson end) | join("; ")) else tostring end' || CLAUDE_READ_FAILED=".errors"
     read_claude_field API_ERROR_STATUS '(.api_error_status // empty) | tostring' || CLAUDE_READ_FAILED=".api_error_status"
     read_claude_field TERMINAL_REASON '(.terminal_reason // empty) | tostring' || CLAUDE_READ_FAILED=".terminal_reason"
     ```
     The `.errors` expression is type-safe: an array of strings joins
     directly, an array containing a non-string element (object, number)
     is `tojson`'d instead of feeding a non-string into `join` (which jq
     rejects), and a non-array `.errors` (unexpected, but possible) falls
     back to `tostring` rather than crashing the whole read. `[Review #3]`
   - `CLAUDE_DETAIL` construction, in preference order — `.errors` (the
     live-captured shapes show this is where max-turns/max-budget put
     their reason and where `.result` is null), then `.error` (the
     existing fallback, still needed for shapes like
     `error_during_execution` that were not captured live), then
     `.result` (the bad-model shape's only source, since it has no
     `.errors` key):
     ```
     CLAUDE_DETAIL="${RESULT:-}"
     [[ -n "$ERROR_MSG" ]] && CLAUDE_DETAIL="${ERROR_MSG}${RESULT:+ | result: ${RESULT}}"
     [[ -n "$ERRORS_ARR" ]] && CLAUDE_DETAIL="${ERRORS_ARR}${RESULT:+ | result: ${RESULT}}"
     [[ -n "$API_ERROR_STATUS" ]] && CLAUDE_DETAIL="${CLAUDE_DETAIL} (api_error_status: ${API_ERROR_STATUS})"
     [[ -n "$TERMINAL_REASON" ]] && CLAUDE_DETAIL="${CLAUDE_DETAIL} (terminal_reason: ${TERMINAL_REASON})"
     ```
     `[Review #2, #3]`

4. **Tests — agy** (`.agent/scripts/tests/test_cross_model_review.sh`,
   near the existing `MOCK_AGY_ERROR` case at
   `test_agy_api_error_message_kept`, ~line 1071):
   - Add a ViewFile-specific denial case alongside the existing
     `test_agy_denial_is_failure` (which uses `RunCommand`): a
     `denied_actions` entry naming `ViewFile`, asserting the reason names
     `ViewFile` — the issue's literal failure signature.
   - Add `MOCK_AGY_ERROR` case with a message containing "response was cut
     off because it exceeded the output token limit" and, separately, a
     **non-empty partial `response`** field (extend the mock, since today
     `MOCK_AGY_ERROR` always sends `response: ""` — add a
     `MOCK_AGY_ERROR_RESPONSE` knob for the partial text). Assert:
     `EXIT=1`, the findings file names the token-limit condition
     precisely, and the findings file does **not** contain the partial
     response text (proving a cut-off turn is never recorded as a
     review). `[Review #6]`
   - Add a case where the diff/prompt itself contains the phrase "output
     token limit" but the agy status is `SUCCESS` (a real, unrelated
     review), asserting the review is accepted normally — proving the
     phrase match only fires on `ERROR_MSG`/stderr, never on `RESPONSE`.
     `[Review #7]`

5. **Tests — claude** (`.agent/scripts/tests/test_cross_model_review.sh`,
   near `test_cli_claude_error_payload_in_reason`, ~line 3266):
   - **Relabel** the two existing `.error`-shape cases: change their
     comments from implying observed CLI behavior to explicitly "synthetic
     fallback coverage for the `.error` branch — not observed CLI output;
     the live max-turns capture below shows claude 2.1.281 actually uses
     `.errors`, not `.error`, for that subtype." Keep both cases
     unmodified otherwise (per the owner's decision to keep them).
     `[Review #5]`
   - Add four new cases using `MOCK_CLAUDE_RAW` with the **full verbatim
     JSON objects captured above** (scrub only `session_id`/`uuid`) and
     `MOCK_CLAUDE_EXIT=1` for the three failure shapes (the shared
     `MOCK_CLAUDE_EXIT` knob already exists — no new mock plumbing
     needed), each test comment recording `claude 2.1.281`:
     - bad-model: `MOCK_CLAUDE_EXIT=1`; assert the reason contains the
       `.result` text AND `"404"` (from `api_error_status`). `[Review #2, #4]`
     - max-turns: `MOCK_CLAUDE_EXIT=1`; assert the reason contains
       `"Reached maximum number of turns"` (from `.errors`) and
       `"max_turns"` (from `.terminal_reason`). `[Review #4]`
     - max-budget: `MOCK_CLAUDE_EXIT=1`; assert the reason contains
       `"Reached maximum budget"` and `"budget_exhausted"`. `[Review #4]`
     - success: `MOCK_CLAUDE_EXIT=0`; assert the review is accepted
       (`EXIT=0`) — this is the control case proving the reorder didn't
       break the passing path. `[Review #4]`
   - Add a **no-JSON + non-zero-exit** case: `MOCK_CLAUDE_RAW='not json'
     MOCK_CLAUDE_EXIT=137`, asserting the reason is `"claude exited 137"`
     (not "did not emit a JSON result object") and still carries
     `bound_note`/`marker_note` content when applicable. This is the case
     the plan's reorder must not regress. `[Review #1]`
   - Add an object-element `.errors` case:
     `MOCK_CLAUDE_RAW='{"type":"result","subtype":"error_during_execution","is_error":true,"result":"","errors":[{"code":1,"message":"boom"}]}'`,
     asserting the read does not fail with "could not be read (.errors)"
     and the reason contains the `tojson`'d object (or its `message`,
     whichever the implementation picks — the test only needs to prove no
     crash and no information loss). `[Review #3]`

6. **Test — prompt isolation** (extend the existing
   `test_prompt_tool_use_guidance`, ~line 1180, rather than adding a new
   test): assert the gemini prompt contains the new "do not call any
   tools" instruction and the concise-output instruction, and no longer
   contains "You may read files"; assert the codex prompt (already
   asserted not to contain "Do NOT run shell commands") also does not
   contain either new instruction. Add the same negative assertions for
   claude via a minimal claude mock in the same test, mirroring the
   existing codex block. `[Review #10]`

7. **Live acceptance — Gemini, Deep-sized, from a detached scratch
   worktree** (manual, recorded in the progress.md entry for
   implementation/review — not a committed script):
   - `48b0d82` (current `main` tip) is the merge commit for #341
     (feature/issue-320). `48b0d82^1` is `main` immediately before that
     merge; `48b0d82^2` is the tip of `feature/issue-320`. Verified this
     session: `git diff 48b0d82^1 48b0d82^2` is 23 files,
     3408 insertions / 699 deletions, **268,391 bytes** — comfortably
     Deep-tier (the issue's own reference run was ~57 KB). `[Review #11]`
   - Create a detached scratch worktree at that tip:
     ```
     git worktree add --detach /tmp/.../scratch-320-review 48b0d82^2
     cd /tmp/.../scratch-320-review
     /home/roland/agent_workspace/worktrees/workspace/issue-workspace-336/.agent/scripts/cross_model_review.sh \
         --branch 48b0d82^1 --agents gemini --no-progress
     ```
     (absolute path into this branch's own script, per the review's
     instruction — confirms the fixed helpers resolve correctly from
     their own directory regardless of cwd).
   - Record in the progress entry: the prompt size in bytes (from the
     generated `review-gemini-prompt.md` under the `--no-progress` tmp
     artifact dir, printed by the script), `agy --version` (`1.2.9`,
     confirmed installed this session), `EXIT=` for the gemini job, and
     the first ~10 lines of the gemini findings file.
   - Remove the scratch worktree afterward
     (`git worktree remove /tmp/.../scratch-320-review`) regardless of
     outcome.
   - If the run fails, the progress entry says so plainly — it is not
     recorded as an accepted acceptance run. `[Review #11]`

8. **Live acceptance — claude, optional bad-model check** (manual,
   recorded alongside item 7): write a two-line wrapper executable
   (`#!/usr/bin/env bash` + `exec claude --model no-such-model-xyz "$@"`)
   into the session scratchpad, `chmod +x` it, and invoke
   `.agent/scripts/_cli_review.sh claude <wrapper-path> <prompt-file>
   <findings-file>` directly (its own 4-arg contract, no
   `cross_model_review.sh` needed for this check). Confirm the findings
   file's reason contains the model-not-found text and `404`, not just
   `"claude exited 1"`. Record `EXIT=` and the findings file content in
   the progress entry. Remove the wrapper afterward. `[Review #12]`

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/cross_model_review.sh` | Gemini-only `## Tool Use` heredoc: no-tools + concise-output instructions; update the stale "Reading files is permitted" comment above the per-agent loop |
| `.agent/scripts/_agy_review.sh` | Precise reason line for the output-token-cutoff ERROR case, matched against `ERROR_MSG`/stderr only |
| `.agent/scripts/_cli_review.sh` | Claude arm: parse JSON before failing on exit status (preserving the exit-code reason when there's no JSON), add `.errors`/`api_error_status`/`terminal_reason` to the reason, type-safe `.errors` read |
| `.agent/scripts/tests/test_cross_model_review.sh` | New agy mock cases (ViewFile denial, output-limit ERROR with partial response, unrelated-phrase-in-diff control); new/relabeled claude mock cases (4 live-captured shapes, no-JSON+exit137, object-element `.errors`); extended prompt-isolation test |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Every new failure path (agy cutoff, claude reorder, no-JSON+nonzero-exit, `.errors` type safety, prompt isolation) gets a mock case with a precise assertion on the reason text or prompt content, not just the exit code. |
| A change includes its consequences | Confirmed `.agent/knowledge/review_depth_classification.md` needs no update (severity classification, not token limits). Stale comment at `cross_model_review.sh` ~1111-1114 is now in Files to Change. |
| Only what's needed | No machine-config change, no read_file allow-rule, no #342 scope (isolation/schema/pinned model), no #344 scope (Copilot removal) — matches the owner's checkpoint decision exactly. |
| Verify against source, not assumption | Every claude shape in this plan is a full, verbatim, live capture against the installed CLI (2.1.281), not a guess; the two kept `.error` mocks are now explicitly labelled synthetic since no live capture supports that shape. The agy cutoff shape is explicitly labelled unverified/modelled-on-issue-text, not claimed as observed. |
| Human control and transparency | The chosen fix is entirely in-repo (prompt text + parsing logic); nothing touches per-machine settings. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Yes | No change to per-agent job structure, timeouts, or the own-marker/`EXIT=` contract — only prompt content and result-parsing logic inside the existing per-agent helpers. |
| 0013 — progress.md entry-type vocabulary | No | No schema change. |

## Consequences

- None beyond the files already listed. `review_depth_classification.md`
  checked and confirmed not applicable.

## Open Questions

None — the owner's checkpoints have resolved the Gemini-fix option choice,
the separate-commits requirement, the mock-retention policy, and (this
revision) all 12 plan-review findings.

## Estimated Scope

Single PR, two commits (Gemini prompt/output-limit fix; claude `.errors`
parsing fix), plus their respective test additions in the same branch, plus
two manual live-acceptance runs recorded in progress.md (not committed as
scripts).

## Implementation Notes

- Revision 2 (this version) folds in all 12 Recommended Actions from the
  `## Plan Review` at `ce728e4`. See the `[Review #N]` tags throughout for
  traceability back to that entry's numbered findings.
