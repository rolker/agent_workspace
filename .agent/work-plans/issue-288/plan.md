# Plan: cross_model_review.sh — make the Gemini (agy) reviewer reliable in headless mode

## Issue

https://github.com/rolker/agent_workspace/issues/288 (also closes
https://github.com/rolker/agent_workspace/issues/274 — same code path, one fix)

## Context

`cross_model_review.sh --agent gemini` runs the `agy` binary (Gemini CLI's
successor, v1.2.8 on this machine) in print mode. Two defects share one root
cause — the script treats agy like the old `gemini` CLI:

1. **#274** — the whole prompt is passed as the `-p` argument value, so any
   prompt over the kernel's per-argument limit (~128 KiB) fails with
   `Argument list too long`. Deep-tier PRs that embed a plan and progress.md
   in the diff hit this routinely.
2. **#288** — when the model decides to run a shell command (e.g. `git log`),
   headless agy auto-denies it, prints a `jetski: no output produced` notice
   on **stderr**, and exits **0** with an empty response. The script sees
   exit 0 and appends `--- Review complete ---`, so a Deep-tier review
   silently loses its cross-model specialist.

Verified against agy 1.2.8 (2026-09-22):

- `--input-format=stream-json --output-format=stream-json -p=` reads one
  NDJSON message per line from **stdin**: `{"event":"user","message":{"role":"user","content":"<prompt>"}}`.
  This removes the argv limit entirely. (`-p ""` with plain stdin is rejected
  as "empty prompt"; `--print` with no value swallows the next flag.)
- The terminal `{"event":"result",...}` line carries `status`, the full
  multi-line `response`, and, when a tool was auto-denied, a non-empty
  `denied_actions` array. Exit code stays 0 on denial — it is **not** a
  usable failure signal; the result event is.
- Neither `--sandbox` nor `--mode plan` auto-approves commands headlessly.
  An allow-rule in agy's user-global `~/.gemini/antigravity-cli/settings.json`
  would, but that is per-machine config the script cannot ship.
- A plain "do not run commands" instruction in the prompt was honoured in a
  probe where the same prompt without it triggered `run_command`.

## Approach

1. **New helper `.agent/scripts/_agy_review.sh <agy-bin> <prompt-file> <findings-file>`**
   (executed, not sourced) so tmux mode and sync mode share one code path:
   - `jq -Rs '{event:"user",message:{role:"user",content:.}}' "$prompt"`
     piped into `agy --input-format=stream-json --output-format=stream-json
     --print-timeout <T> -p=`; raw stream saved next to the findings file
     as `review-gemini-stream.ndjson` (regenerated each run, gitignored with
     the other artifacts) for debugging.
   - Parse the `result` event with jq. **Success** = agy exited 0, a
     `result` event exists, `status == "SUCCESS"`, and `response` is
     non-empty → write `response` to the findings file, exit 0. If
     `denied_actions` is non-empty but a response exists, append a
     `> Note: N tool action(s) were denied in headless mode` line so the
     integrator knows the review ran with less context.
   - **Failure** (anything else: E2BIG-style launch error, non-zero exit,
     no result event, `status != SUCCESS`, or empty response — the #288
     case) → write a one-paragraph reason into the findings file (the agy
     `error` field, or the stderr notice, or "denied: <actions>") and exit
     1. The existing wrappers then append `--- Review failed ---` and the
     script exits 3, which `review-code` already reports as "specialist
     unavailable".
2. **`cross_model_review.sh`**: the `gemini` arms of `build_invoke_cmd` and
   `run_agent_sync` call the helper; `AGY_PRINT_TIMEOUT` is passed through.
   Header comment and the "agy is the exception" note updated. Fail fast
   with the existing exit 1 if `jq` is missing for the gemini agent (jq is a
   bootstrap dependency already, `bootstrap.sh:42`).
3. **Prompt footer** (all agents, not just gemini): add a short "Tool use"
   paragraph — the diff is complete; reading repository files for context is
   fine; do **not** run shell commands, this is a headless session and
   command execution is denied without a prompt. This is the answer to the
   issue's "owner call": prompt instruction + hard detection, not a global
   allow-rule. The owner can still add `command(git log*)`-style rules to
   his own agy settings; the script must not depend on it.
4. **Tests** in `test_cross_model_review.sh`:
   - Replace the argv-based `agy` mock with one that implements the
     stream-json contract (reads NDJSON on stdin, echoes the prompt back
     inside a `result` event; `MOCK_AGY_DENY=1` emits empty `response` +
     `denied_actions`; `MOCK_AGY_EXIT` forces a non-zero exit).
   - `test_agy_stdin_invocation` — prompt content arrives via stdin, argv
     carries only flags, findings file gets the response and
     `--- Review complete ---`.
   - `test_agy_large_prompt` — `gh pr diff` mock emits a >200 KiB diff; the
     run succeeds. This genuinely exercises #274: an argv regression fails
     with E2BIG on a real kernel.
   - `test_agy_denial_is_failure` — denial → `--- Review failed ---`, exit
     3, findings file names the denied action (#288).
   - `test_prompt_has_tool_use_guidance` — footer text present.
5. **Docs**: `AGENTS.md` script table row for `_agy_review.sh`;
   `review-code` SKILL.md "Collecting findings" note that a
   `--- Review failed ---` file now carries the reason on the line above.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_agy_review.sh` | New: stdin stream-json invocation + result-event validation |
| `.agent/scripts/cross_model_review.sh` | gemini arms call the helper; prompt footer tool-use guidance; header comments |
| `.agent/scripts/tests/test_cross_model_review.sh` | New agy mock; four tests above; retire the `-p`-value assertions |
| `AGENTS.md` | Script reference row |
| `.claude/skills/review-code/SKILL.md` | One line: failed marker carries a reason |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | The failure is detected mechanically from the result event, not by asking the model to behave. The prompt instruction is a mitigation on top, not the guard. |
| Test what breaks | Both bugs get a regression test; the large-prompt test would fail for real under an argv regression. |
| A change includes its consequences | Script table, review-code skill, and test mock move together (consequences map rows for `.agent/scripts/` and `review-code`). |
| Human control and transparency | A lost specialist is now reported as failed with a reason instead of an empty "complete" review. |
| Only what's needed | No global permission changes, no `--dangerously-skip-permissions`. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0003 (project-agnostic workspace) | Yes | Helper takes paths as arguments; no project assumptions. |
| ADR-0004/0005 (enforcement hierarchy) | Yes | Mechanical detection in the script; tests run in the `validate-script-tests` pre-commit hook. |
| ADR-0013 (progress entry vocabulary) | No | Findings files stay uncommitted artifacts; progress.md shape unchanged. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| A script in `.agent/scripts/` | `AGENTS.md` script table | Yes |
| `cross_model_review.sh` behaviour | `review-code` skill collecting-findings note | Yes |
| agy mock contract in tests | `test_agy_invocation` (#223) assertions | Yes — replaced |

## Open Questions

- None blocking. If the owner prefers agy to be allowed read-only git
  commands during review, that is an allow-rule in his agy settings and
  independent of this change.

## Estimated Scope

Single PR.
