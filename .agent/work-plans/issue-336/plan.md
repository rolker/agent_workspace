# Plan: Gemini (agy) reviews fail on real branches: headless read_file denied, output-token limit on large prompts

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
   on claude 2.1.281 (verified live in this session), every observed
   failure mode — bad `--model` (404), `--max-turns` hit, `--max-budget-usd`
   hit — exits **1**, and `_cli_review.sh` fails on that nonzero exit
   *before* it ever reads the JSON body, so the real reason (which is in
   the JSON) is discarded. The current code also only reads `.error`, but
   live captures show the CLI puts the reason in an `.errors` array with no
   `.result` at all in these cases.

Both fixes land in the same branch as **separate commits** (per the issue
review's Recommendation and the owner's checkpoint decision).

## Live-captured claude failure shapes (claude 2.1.281, captured this session)

All three below exited **1**, so today's code never reads past
`CLI_EXIT -ne 0` for any of them:

```jsonc
// bad --model (unrecognized-model, api_error_status 404)
{"is_error": true, "subtype": "success", "api_error_status": 404,
 "errors": null, "result": "There's an issue with the selected model ..."}

// --max-turns 1 hit
{"is_error": true, "subtype": "error_max_turns",
 "errors": ["Reached maximum number of turns (1)"], "result": null}

// --max-budget-usd 0.0001 hit
{"is_error": true, "subtype": "error_max_budget_usd",
 "errors": ["Reached maximum budget ($0.0001)"], "result": null}
```

Note the bad-model case is `subtype: "success"` with `is_error: true` and a
`.result` string but no `.errors` — the opposite shape from the other two
(`.errors` array, no `.result`). Both must be read.

A "not logged in" shape could not be captured live in this session without
de-authenticating the installed CLI (which would break other work in this
environment); it is left uncaptured. The fix reads `.errors`/`.error`
generically so it does not depend on enumerating every subtype, and the
existing `.error`-shape test coverage (string and object) is kept.

## Approach

1. **Gemini prompt change** (`.agent/scripts/cross_model_review.sh`,
   the gemini-only `## Tool Use` heredoc, ~line 1119-1136): replace "You may
   read files in the repository for surrounding context" with an
   instruction that Gemini gets the diff and plan context inline, has no
   file-reading tool available, must not simulate/pretend to call one, and
   should name any context it's missing rather than guess. Add a
   concise-output instruction (findings table + short summary only, no
   restating the diff) to reduce output-token pressure. This block is
   already gemini-only (confirmed in the issue review) — no change needed
   to isolate it from codex/claude/copilot.

2. **Treat agy's output-token cutoff as a clear failure**
   (`.agent/scripts/_agy_review.sh`, the `STATUS != "SUCCESS"` branch
   ~line 249-251): today this already fails and reports `ERROR_MSG`, but
   the token-limit case is worth a dedicated, precise reason line rather
   than whatever `.error` happens to contain, since agy's messaging for
   this case ("response was cut off because it exceeded the output token
   limit") is distinct from other ERROR causes (quota, auth). Detect it by
   matching the ERROR_MSG/response text for "cut off" / "output token
   limit" and emit a specific reason: `"response was cut off because it
   exceeded the output token limit (status ERROR); the prompt or response
   was too large"`. Fall back to the existing generic
   `"result status ${STATUS}${ERROR_MSG:+: ${ERROR_MSG}}"` for any other
   ERROR status.

3. **Claude arm: parse JSON regardless of exit status**
   (`.agent/scripts/_cli_review.sh`, the `claude)` case, ~line 325-379):
   - Move the `CLI_EXIT -ne 0` check to *after* the JSON-object check and
     field reads, not before. If stdout is not a JSON object, keep today's
     immediate `claude did not emit a JSON result object` failure (covers
     a real crash/no-output case) — that check does not depend on exit
     status. If stdout *is* a JSON object, read the fields first; then:
     - if `IS_ERROR` or a non-success `SUBTYPE`, fail with the detailed
       reason (existing logic), regardless of exit code;
     - else if `CLI_EXIT -ne 0`, fail with `"claude exited ${CLI_EXIT}"`
       (today's message) — a nonzero exit with a clean success JSON
       shouldn't happen, but if it does, it's still a failure;
     - else proceed as success.
   - Add `.errors` array as the preferred source: read a new field
     `ERRORS_ARR` via `(.errors // []) | join("; ")` and prefer it over
     `.error` when non-empty. Keep `.error` as the fallback (per the
     review's recommendation — do not delete the existing string/object
     `.error` handling, which is still real for other subtypes such as
     `error_during_execution`).
   - Update `CLAUDE_DETAIL` to prefer `ERRORS_ARR`, then `ERROR_MSG`, then
     `RESULT`.

4. **Tests — agy** (`.agent/scripts/tests/test_cross_model_review.sh`,
   near the existing `MOCK_AGY_ERROR` case ~line 1071):
   - Keep the existing headless-denial test (`MOCK_AGY_DENY=1`) — already
     covers "denied read_file" at the `ViewFile` layer; add/confirm one
     case where `denied_actions` names `ViewFile` specifically (today's
     mock uses `RunCommand`) so the reason text is exercised for a file
     read denial too.
   - Add `MOCK_AGY_ERROR="response was cut off because it exceeded the
     output token limit"` case asserting the findings file names the
     token-limit condition precisely (not just "result status ERROR").

5. **Tests — claude** (`.agent/scripts/tests/test_cross_model_review.sh`,
   near `test_cli_claude_error_payload_in_reason` ~line 3266):
   - Keep both existing `.error` cases (object and string) unchanged —
     they still exercise a real shape (`error_during_execution`).
   - Add three new cases using `MOCK_CLAUDE_RAW` + `MOCK_CLAUDE_EXIT=1`
     (the shared exit-code knob already exists) reproducing the three
     live-captured shapes above verbatim, asserting:
     - bad-model shape: reason contains the `.result` text (no `.errors`
       to prefer here);
     - max-turns shape: reason contains `"Reached maximum number of turns"`
       from `.errors`;
     - max-budget shape: reason contains `"Reached maximum budget"` from
       `.errors`.
   - Each new test's comment records "captured live against claude
     2.1.281" per the issue's ask to record the CLI version.

6. **Live acceptance test** (manual, not committed as a script): run
   ```
   .agent/scripts/cross_model_review.sh --branch --agents gemini
   ```
   on this feature branch once it has a Deep-sized diff (the branch itself,
   after all commits above, should be large enough — if not, pad by
   including this plan's own diff history) and confirm it completes with
   `EXIT=0` and a real Gemini review in the findings file, not a failure.
   Record the result in the progress.md entry for implementation/review.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/cross_model_review.sh` | Gemini-only `## Tool Use` heredoc: no-file-tools + concise-output instructions |
| `.agent/scripts/_agy_review.sh` | Precise reason line for the output-token-cutoff ERROR case |
| `.agent/scripts/_cli_review.sh` | Claude arm: parse JSON before failing on exit status; prefer `.errors` array, fall back to `.error` |
| `.agent/scripts/tests/test_cross_model_review.sh` | New agy mock cases (ViewFile denial, output-limit ERROR); new claude mock cases (live-captured `.errors` shapes, exit 1 + JSON) |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Every new failure path gets a mock case with a precise assertion on the reason text, not just the exit code. |
| A change includes its consequences | Confirmed `.agent/knowledge/review_depth_classification.md` needs no update — it governs finding severity, not prompt size/token limits. |
| Only what's needed | No machine-config change, no read_file allow-rule, no #342 scope (isolation/schema/pinned model) — matches the owner's checkpoint decision exactly. |
| Human control and transparency | The chosen fix is entirely in-repo (prompt text + parsing logic); nothing touches per-machine settings. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Yes | No change to per-agent job structure, timeouts, or the own-marker/`EXIT=` contract — only the prompt content and result-parsing logic inside the existing per-agent helpers. |
| 0013 — progress.md entry-type vocabulary | No | No schema change. |

## Consequences

- None identified beyond the two files already covered by tests above.
  `review_depth_classification.md` checked and confirmed not applicable.

## Open Questions

None — the owner's checkpoint already resolved the Gemini-fix option
choice, the separate-commits requirement, and the mock-retention policy.

## Estimated Scope

Single PR, two commits (Gemini prompt/output-limit fix; claude `.errors`
parsing fix), plus their respective test additions in the same branch.
