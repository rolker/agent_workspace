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
     installed 1.0.61 once Copilot quota returns (open question below).
     **No prompt-size guard** (pre-push review round 1): stdin has no
     argv limit, so any bound could only reject large reviews that would
     otherwise work — the stdin-contract test is the enforcement.
     **Least privilege** (pre-push review round 1): `-p "" -s
     --available-tools='' --disable-builtin-mcps --no-ask-user` instead
     of `--allow-all-tools`, which would escalate privilege on the
     strength of an untrusted diff. `-s` output
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

### Round 1 of address-findings (pre-push review at 45c4b0e)

8. **The copilot prompt-size guard is gone.** It was the owner's
   belt-and-braces choice at plan time, but on the stdin path it can only
   fire where the prompt *would have worked*, re-imposing the very #212
   ceiling this issue removes — and it bites hardest on the Deep-tier PRs
   where an extra reviewer matters most. The stdin-contract test (prompt
   absent from argv, present on stdin) is the enforcement; a new test
   pins that a 128 KiB + 1 prompt is reviewed by all three CLIs.

9. **Copilot runs with no tools at all.** `--allow-all-tools` grants an
   untrusted diff the right to run shell commands; a reviewer needs no
   tools, since the diff is in the prompt. Now `-p "" -s
   --available-tools='' --disable-builtin-mcps --no-ask-user`, all read
   from `copilot --help` on 1.0.61. The empty tool set still needs one
   live confirmation when quota returns; the documented fallback, in a
   comment at the call site, is to drop `--available-tools` and use
   `--deny-tool='shell' --deny-tool='write'` instead.

10. **codex's transcript is never scanned for error markers.** It
    replays the prompt, diff included, so the scan failed this branch's
    own review when the diff mentioned a rate limit. codex now gets its
    own stderr file; only that is scanned, with the `-o` file's emptiness
    and the exit code as the primary signals, and failure reasons excerpt
    the transcript (the only channel that carries codex's diagnostics).

11. **Error detection in a result is an opener match, not a heuristic.**
    Length and "has a heading" both produced false positives on concise
    list findings and false negatives on long, `#`-headed errors. The
    rule is now: the first non-empty line must announce an error or be a
    known error sentence, and a marker must appear somewhere. Tested in
    both directions.

12. **Both helpers wait for their CLI after a TERM.** Killing and exiting
    let the EXIT trap remove TMP_DIR under a running CLI and defeated the
    caller's `timeout -k` backstop, whose SIGKILL targets the helper.
    `_cli_review.sh` and `_agy_review.sh` now kill, wait, and escalate to
    SIGKILL after `REVIEW_KILL_ESCALATION` seconds (default 5, below the
    caller's 10s kill-after grace). Tested with a mock that ignores TERM.

13. **Mocks reproduce the channel that caused the live failure.** The
    codex mock gained a full-prompt-echo knob (the two-line excerpt is
    why the false positive was not caught in round 1) and a TERM-ignoring
    mode; all mocks sleep in slices so a SIGKILL leaves no orphan.

### Round 2 (live gemini + codex re-run of `ca7f87c`)

**The rule this issue ends on: markers explain, they never cause.** Only
machine state may FAIL a review — a non-zero exit status, a missing or
empty result, or a structured error field (claude's `.is_error` /
`.error`). Error *text* only chooses the reason line for a failure one
of those has already established.

That rule is not caution, it is the only thing that survived contact.
Three text-based designs were tried and each one discarded a real
review of this branch:

| Attempt | Failed on |
|---|---|
| Scan the merged stdout transcript (round 0) | codex echoes the prompt, diff included — a diff mentioning a rate limit reads as a rate-limited CLI |
| Scan stderr only (round 1) | codex prints the WHOLE transcript on stderr too, including tool calls and their output: a `jq: error` line from a command codex itself ran failed the run |
| Opener + marker on the result (round 1) | false positive on "# Error Handling in auth.py"; false negative on "API Error: Quota exceeded" |

The residual cost — a CLI that exits 0 with a polite quota message as
its whole answer is passed through as a review — is the lesser evil, and
is stated in the helper's header.

14. **codex**: `-o` file empty/missing or non-zero exit only.
15. **claude**: structured fields only, and `type == "object"` is
    required before indexing. `jq -e .` accepts `"oops"` / `[]` / `1`,
    after which `.is_error` aborted jq and the helper died under
    `set -e` with an EMPTY findings file (codex must-fix 1). Every field
    read is guarded, via `printf -v` rather than `$( )` so a failure
    reaches `fail()` instead of exiting a subshell.
16. **copilot**: non-zero exit or empty `-s` output only. A transient
    `[WARN] overloaded, retrying` no longer fails a completed review.
17. **`cleanup_jobs` reaps before removing `AGENT_TMP_ROOT`** (codex
    must-fix 2), and each job's TERM trap now waits for its helper — the
    job shell exiting at once was what told the parent it was safe to
    drop the temp root under a live CLI. Both bounded
    (`CLEANUP_REAP_TIMEOUT`, default 8s) so nothing can hang the exit.
18. **Escalation vs the caller's grace** (codex must-fix 3, gemini 4):
    both helpers refuse to start when `AGENT_KILL_AFTER` is not greater
    than `REVIEW_KILL_ESCALATION` (exit 2, reason in the findings file);
    `AGENT_KILL_AFTER` is exported to them for the check. Both zero is
    the one legal equal case. Otherwise the caller's SIGKILL lands on the
    helper before it can SIGKILL a CLI that ignored SIGTERM.
19. **Watchdog no longer waited on** (gemini 4): a subshell sleeping in
    `sleep` defers the TERM we send it, so `wait "$watchdog"` cost the
    full window on every clean exit. `wait` on the CLI returns in
    milliseconds; the watchdog is killed and left to exit on its own,
    and re-checks liveness before any `kill -9` so it cannot hit a
    recycled PID. Tested: TERM to a fast-exiting mock returns in under 3s
    with a 5s window.
20. **`terminate_child` disarms its traps on entry** (gemini 6) so a
    second signal cannot start a second watchdog. `_agy_review.sh`
    already cleared `AGY_PID` after the normal reap (gemini 5) and now
    clears it in the handler too.
21. **`jq` is a claude preflight** (gemini 8): missing jq marks claude
    unavailable with a reason instead of failing every claude run.
22. **Copilot invocation is unchanged but annotated** (gemini 7): `-p ""`
    plus stdin stays (the #212-verified form); the call-site comment now
    names BOTH `-p ""` and `--available-tools=''` as pending one live
    confirmation, with the fallback for each.

## Estimated Scope

Single PR. Closes #313 and #212. Does not touch #320 (sequenced after).
