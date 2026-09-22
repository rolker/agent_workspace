# Plan: cross_model_review.sh: codex/claude/copilot arms have no result validation

## Issue

https://github.com/rolker/agent_workspace/issues/313 (folds in #212)

## Context

`_agy_review.sh` gives gemini a forced gate: truncate findings first, own
the file, `fail()` on exit!=0/timeout/empty/denied, success writes only the
review text. The codex/claude/copilot arms in `run_agent_sync`
(`cross_model_review.sh:213-217`) are still bare `timeout ... "$bin" ... <
"$prompt" > "$findings" 2>&1`, gated on exit code alone. Round-1 plan review
(49e5b16, needs-work) found the first draft's copilot form put the whole
prompt on argv (an #274 regression against `cross_model_review.sh:203`'s
no-argv-bound invariant), its sourced shared skeleton could fail before
truncating, and it dropped INT/TERM/HUP forwarding. The owner's Checkpoint
(Decision: revise) chose one exec'd dispatcher over four files; this
revision replaces the sourced-skeleton/three-helper design and folds in all
eight round-1 action items.

## Approach

1. **One script, `_cli_review.sh <agent> <bin> <prompt-file> <findings-file>
   [<timeout>]`**, exec'd by `run_agent_sync` exactly as `_agy_review.sh` is
   today (gemini stays on `_agy_review.sh` — its stream-json parsing has no
   shared shape with the other three). First statement, before any guard:
   `: > "$FINDINGS_FILE"` or `fail`, matching `_agy_review.sh:69-72` so a bad
   arg never leaves stale findings under a fresh failure marker. `case
   "$agent" in codex|claude|copilot)` selects the invocation +
   result-extraction block; anything else is a usage error (exit 2).
2. **Spawn/wait/trap copied from `_agy_review.sh:105-141`**: `mktemp -d`
   under the inherited `$TMPDIR`, EXIT trap set right after; INT/TERM/HUP
   traps armed *before* the CLI is spawned, killing the recorded child PID;
   the CLI runs as a background job, `wait`ed on, so the parent's `exec env
   TMPDIR="$AGENT_TMP_ROOT" timeout -k "$AGENT_KILL_AFTER" "$AGENT_TIMEOUT"
   "$CLI_REVIEW_HELPER" "$agent" "$bin" "$prompt" "$findings"` reaches the
   CLI instead of leaving it running. codex's `-o` file and per-CLI
   stdout/stderr logs live inside this temp dir, so `AGENT_TMP_ROOT` and
   `run_script_tests.sh`'s leak sweep cover them.
3. **Per-agent invocation + validation**:
   - **codex**: `"$bin" exec -o "$out_file" < "$prompt"` (no `[PROMPT]` arg,
     so stdin is read; `-o` writes only the final message). stdout/stderr go
     to a log, discarded on success, tailed into the failure reason on
     failure. `fail` on exit!=0 or `$out_file` missing/empty. No documented
     codex error markers; report exit code + log excerpt.
   - **claude**: `"$bin" -p --output-format json --permission-prompts none
     < "$prompt"`. `--permission-prompts none` auto-denies anything that
     would prompt instead of hanging, mirroring agy;
     `--dangerously-skip-permissions` is rejected as unsafe for a
     reviewer. No `--permission-mode plan` (owner Checkpoint, round-2
     plan-review finding 1): plan mode's terminal move is presenting a
     plan for approval, which would pass every gate below while putting a
     plan rather than a review in the findings file. Parse the
     single JSON object with `jq`; `fail` on exit!=0, invalid JSON,
     `.is_error == true`, `.subtype != "success"`, or empty `.result`.
     Surface `.result`/error text containing `usage limit`, `rate limit`,
     `overloaded`, `not logged in` in the failure reason.
   - **copilot** (fixes #212): `"$bin" -p "" --allow-all-tools -s <
     "$prompt"` — stdin, the form #212 verified on 1.0.48. Re-confirm on the
     installed 1.0.61 once Copilot quota returns (open question below);
     until then, a belt-and-braces guard: prompt > 128 KiB (Linux
     MAX_ARG_STRLEN, per the owner Checkpoint and round-2 finding 2) →
     `fail` before invoking copilot. At exactly that bound the guard can
     only fire where an argv regression would have exec-failed anyway, so
     it never turns a working stdin review into a failure; the real
     enforcement of the channel is the stdin-contract test. `-s` output
     used as-is — no second
     footer strip (drops round 1's `sed '/^Changes$/q'`, which risked
     truncating a review body containing a bare `Changes` line). `fail` on
     exit!=0 or empty stdout.
4. **`cross_model_review.sh` wiring**: extend the availability precheck
   (currently `AGY_REVIEW_HELPER`-only, ~line 467) to also require
   `CLI_REVIEW_HELPER` present + executable **for codex/claude/copilot
   only** (round-2 finding 3: a missing `_cli_review.sh` must not mark a
   gemini-only run unavailable); `run_agent_sync`'s
   codex/claude/copilot arms (213-217) call it per point 2, `EXIT=`
   semantics unchanged; update the header comment (~31-36, documents the
   bare `<cli> -p < prompt` invocation) and `run_agent_job`'s non-gemini
   timeout message (~882, "partial output above, if any" — false once
   `_cli_review.sh` truncates first).
5. **Exec bit**: `chmod +x .agent/scripts/_cli_review.sh`.
6. **Docs**: `AGENTS.md` row for `_cli_review.sh` + update the existing
   `cross_model_review.sh` row; review-code SKILL.md's result-reading note
   if exit-code-only; ADR-0015's "still missing for Codex, Claude and
   Copilot; that is #313" bullet closed out; `agent_wait_patterns.md` gets a
   line if gemini-only today (confirm during implementation).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_cli_review.sh` | New: single exec'd helper, per-agent case, truncate-first + spawn/wait/trap from `_agy_review.sh` |
| `.agent/scripts/cross_model_review.sh` | Precheck extended to `CLI_REVIEW_HELPER`; arms call it; header comment (~31-36) and timeout message (~882) updated |
| `.agent/scripts/tests/test_cross_model_review.sh` | `make_mock_agent` reworked (arms no longer redirect the CLI's own stdout); per-CLI mocks (codex `-o` file + transcript; claude JSON; copilot stdin + `-s`); argv-contract assertion (~1366) updated; success/empty/nonzero-exit/timeout/error-marker per CLI; copilot stdin-contract (#212) + size-guard tests; TERM-forwarding/kill assertion per CLI |
| `AGENTS.md` | New `_cli_review.sh` row; `cross_model_review.sh` row updated |
| `.claude/skills/review-code/SKILL.md` | Update result-reading note if exit-code-only assumption exists |
| `docs/decisions/0015-...md` | Close the "still missing" consequence bullet |
| `.agent/knowledge/agent_wait_patterns.md` | Add a line if gemini-only today |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Forced gate per CLI, truncate-first before any guard, matching gemini exactly. |
| Test what breaks | Mocks reproduce each CLI's real shape; timeout/kill, empty, non-zero exit, error markers, #212 stdin regression all asserted. |
| Only what's needed | Single dispatcher (owner's decision) replaces the four-file design. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0015 | Yes | `exec`/`timeout -k`/background-job/`EXIT=` structure untouched; only each arm's exec'd command changes. Closing bullet updated. |

## Consequences

Covered inline above: failure-file content change → `run_agent_job` timeout
message (~882); availability precheck → AGENTS.md + ADR-0015 bullet;
copilot invocation channel → #212 regression test + size guard.

## Open Questions

- Copilot's stdin form is confirmed on 1.0.48 (#212), not re-verified on the
  installed 1.0.61 (quota exhausted). The 100 KiB guard mitigates until a
  live check is possible; note in the PR description.

## Implementation Notes

Written during implementation; each item is a decision the plan did not
settle, or a deviation from it.

1. **A background child's stdin is `/dev/null`.** The first draft of
   `run_cli` put the `< "$prompt"` redirect on the *call* to the helper
   function rather than on the backgrounded command inside it. Bash
   points an asynchronous command's stdin at `/dev/null` unless that
   command carries its own redirect, so every CLI would have been handed
   an empty prompt — the exact failure this issue exists to catch, and a
   silent one (copilot's mock still answered). Caught by the new
   stdin-contract test, not by inspection; the redirect now lives on the
   backgrounded command, as it does in `_agy_review.sh`. A
   `test_cli_prompt_reaches_every_cli_on_stdin` case pins it for all
   three CLIs.

2. **`EXIT=` for codex/claude/copilot is now the helper's status.** A
   failed review reports `EXIT=1` (the helper's "no usable result"), not
   the CLI's own exit code, exactly as gemini has since #288; the CLI's
   status is named in the findings file's reason. This changed an
   existing assertion (`test_agents_partial_failure` expected `EXIT=7`)
   and is documented in the script header, ADR-0015's consequence bullet
   and the review-code skill's result-reading note.

3. **Error-marker scanning is asymmetric on purpose.** The full marker
   set (quota / rate limit / usage limit / overloaded / not logged in /
   unauthorized / authentication failed) is matched against the CLI's own
   stderr or transcript, where any hit is an error. Against the *result*
   it is matched only when the text is short (<= 400 chars) and carries
   no markdown heading — an adversarial review may legitimately discuss
   rate limits or authentication, and failing a real review would be
   worse than missing an error. `test_cli_error_marker_is_failure`
   asserts both halves.

4. **`run_agent_sync`'s default arm routes through the helper.** Rather
   than keep a bare `"$bin" -p` fallback for an agent key that cannot
   occur (the list is validated at parse time), `*)` now execs
   `_cli_review.sh`, which rejects an unknown agent with exit 2 and a
   readable reason in the findings file instead of running a CLI blind.

5. **codex's empty-result reason says "empty response".** The distinct
   condition (`--output-last-message` file missing or empty) is still
   named, but the shared vocabulary keeps one assertion working across
   all three CLIs and matches how the failure reads to a human.

6. **`agent_wait_patterns.md` did not name the helpers** (the conditional
   in step 6): it now carries a quick-reference row and a See-also entry
   for the inner half of the wait — CLI as a waited-on background child
   with signals forwarded.

7. **Test suite: 196 -> 298 assertions.** `make_mock_agent` now emits a
   per-CLI mock reproducing that CLI's real output shape (codex:
   transcript on stdout, final message to the `-o` file; claude: one JSON
   object; copilot: stdin + `-s`). New cases: transcript-never-becomes-
   the-review, prompt-on-stdin for all three, empty / non-zero exit /
   error marker / timeout-with-kill per CLI, claude's JSON contract
   (non-JSON, `is_error`, bad subtype, envelope not leaked), the copilot
   stdin contract (#212), the 128 KiB guard (and that codex is not
   subject to it), TERM forwarding to the CLI child, truncate-first plus
   usage errors, a temp-leak sweep, and a missing-`_cli_review.sh`
   precheck case that leaves gemini usable.

## Estimated Scope

Single PR. Closes #313 and #212. Does not touch #320 (sequenced after).
