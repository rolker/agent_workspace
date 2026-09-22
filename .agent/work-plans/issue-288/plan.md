# Plan: cross_model_review.sh — make the Gemini (agy) reviewer reliable in headless mode

## Issue

https://github.com/rolker/agent_workspace/issues/288 (also closes
https://github.com/rolker/agent_workspace/issues/274 — same code path, one fix — and
https://github.com/rolker/agent_workspace/issues/312, the prompt-trimming half of #274, folded in by owner decision)

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
- Headless file reads need no permission: a probe asking agy to read a
  workspace file with `view_file` succeeded with no `denied_actions`. Only
  `run_command` is auto-denied.
- `--print-timeout` expiry (probed with `3s`): agy prints
  `[agy] print timeout after 3s with turn in progress; returning partial output`
  on stderr and still emits a `result` event with `status: SUCCESS` (empty
  response in the probe; may be a truncated one). So a SUCCESS result is not
  sufficient on its own — the stderr timeout marker must also be checked.

## Approach

1. **New helper `.agent/scripts/_agy_review.sh <agy-bin> <prompt-file> <findings-file> [<print-timeout>]`**
   (executed, not sourced) so tmux mode and sync mode share one code path.
   **The helper owns the findings file**; the wrapper arms pass no stdout
   redirect (see step 2). Helper diagnostics go to stderr only.
   - **First statement, before any guard**: truncate the findings file
     (`: > "$findings"`). The wrapper redirect used to do this; without it a
     helper that dies at a guard would leave the previous run's review in
     place under a fresh `--- Review failed ---` marker, which review-code
     would read as current.
   - Guards: `jq` present (exit 1 with a message otherwise); prompt file
     readable.
   - `jq -c -Rs '{event:"user",message:{role:"user",content:.}}' "$prompt"`
     (compact: one NDJSON line) is written to a temp file first, then fed
     as agy's stdin:
     `agy --input-format=stream-json --output-format=stream-json
     --print-timeout <T> --disable-slash-commands -p=`. agy's stdout goes to
     a `mktemp` stream file and its stderr to a `mktemp` stderr file, so the
     agy exit status is read directly (no pipeline, no pipefail/SIGPIPE
     masking). Nothing is written under the work-plans dir except the
     findings file, so no new `.gitignore` rule and no behaviour question
     under `--work-dir` / `--work-plans-dir`. Both temp files are removed
     on every exit path (`trap ... EXIT`); on failure the findings file
     itself carries the diagnostics — agy's `error` field, the result
     event's `denied_actions`, and the first 20 lines of agy's stderr — so
     nothing is left on disk for `run_script_tests.sh`'s leftover sweep to
     trip over.
   - Parse the last `result` event with jq. **Success** = agy exited 0, a
     `result` event exists, `status == "SUCCESS"`, `response` is non-empty,
     and stderr does **not** contain the `print timeout after` marker →
     write `response` to the findings file with a plain `>` (no staging
     temp: the file was truncated at helper start, and readers key off the
     wrapper's `--- Review complete ---` marker, which is appended only
     after the helper exits), exit 0. If `denied_actions` is
     non-empty but a response exists, append a
     `> Note: N tool action(s) were denied in headless mode` line so the
     integrator knows the review ran with less context.
   - **Failure** (anything else: launch error, non-zero exit, no result
     event, `status != SUCCESS`, empty response — the #288 case — or the
     timeout marker — a truncated review) → write a one-paragraph reason
     into the findings file (agy's `error` field, the stderr excerpt, the
     denied actions, or "print timeout — partial output discarded") and
     exit 1. The wrappers then append `--- Review failed ---` (sync: the
     script exits 3; tmux: the `||` branch in the session command), which
     `review-code` already reports as "specialist unavailable".
2. **`cross_model_review.sh`**: the `gemini` arms of `build_invoke_cmd` and
   `run_agent_sync` invoke the helper with `"$AGY_PRINT_TIMEOUT"`, **without**
   the `> "$findings" 2>&1` redirect the other arms keep (the helper writes
   the file; a wrapper redirect would truncate it). Header comment and the
   "agy is the exception" note updated, and the `AGY_PRINT_TIMEOUT`
   comment corrected: agy's default is `0s` (wait until the turn ends),
   not 5m; the script keeps an explicit 30m cap so a hung review cannot
   block a tmux session or a sync caller forever. The `--- Review complete ---` /
   `--- Review failed ---` markers stay the wrappers' job.
3. **Prompt footer, gemini only**: when `TARGET_AGENT == gemini`, append a
   short "Tool use" paragraph — the diff is complete; reading repository
   files for context is fine (verified: headless `view_file` is not denied);
   do **not** run shell commands, this is a
   headless session and command execution is denied without a prompt.
   Not added for codex/claude/copilot: `codex exec` reads files through the
   shell, so the line would cost it context. This is the answer to the
   issue's "owner call": prompt instruction + hard detection, not a global
   allow-rule. The owner can still add `command(git log*)`-style rules to
   his own agy settings; the script must not depend on it.
4. **Tests** in `test_cross_model_review.sh`:
   - Replace the argv-based `agy` mock with one that implements the
     stream-json contract (reads NDJSON on stdin, echoes the prompt back
     inside a `result` event; `MOCK_AGY_DENY=1` emits empty `response` +
     `denied_actions`; `MOCK_AGY_TIMEOUT=1` prints the timeout marker on
     stderr with a SUCCESS result; `MOCK_AGY_EXIT` forces a non-zero exit).
   - `test_agy_stdin_invocation` — prompt content arrives via stdin, argv
     carries only flags, findings file gets the response and
     `--- Review complete ---`, no stray temp files remain.
   - `test_agy_findings_truncated` — pre-seed the findings file with stale
     text, force a guard failure (`MOCK_AGY_EXIT` or missing prompt); assert
     the stale text is gone and only the reason + `--- Review failed ---`
     remain. Every failure-path test also asserts the suite's TMPDIR is
     empty afterwards (the runner enforces this with exit 2).
   - `test_agy_large_prompt` — `gh pr diff` mock emits a >200 KiB diff; the
     run succeeds. This genuinely exercises #274: an argv regression fails
     with E2BIG on a real kernel.
   - `test_agy_denial_is_failure` — denial → `--- Review failed ---`, exit
     3, findings file names the denied action (#288).
   - `test_agy_timeout_is_failure` — timeout marker → failed, exit 3.
   - `test_agy_tmux_invocation` — mock `tmux` on `PATH` that records the
     `new-session` command string; assert the helper path and its
     arguments are quoted, no `>` redirect onto the findings file, and the
     complete/failed marker clauses are present. First coverage of the
     default (tmux) path.
   - `test_prompt_tool_use_guidance` — paragraph present for gemini, absent
     for codex.
5. **Docs**: `AGENTS.md` script table row for `_agy_review.sh`;
   `review-code` SKILL.md "Collecting findings": a `--- Review failed ---`
   file now carries the reason on the lines above the marker.
6. **#312 folded in (owner decision 2026-09-22)**: strip `.agent/work-plans/**`
   file sections from the embedded diff in both PR and branch mode. A small
   awk filter over the unified diff (`diff --git a/<path> b/<path>` headers)
   drops those sections, keyed on the b/ path only so a file renamed out of
   work-plans stays in review, tolerant of git-quoted paths; branch mode
   passes explicit `--src-prefix=a/ --dst-prefix=b/` so `diff.noprefix`
   cannot defeat it. Both pipeline stages' exit statuses are checked. If nothing remains after filtering, the existing empty-diff guard
   fires with a message that names the exclusion. Test: a mock diff with a
   code file and a `.agent/work-plans/issue-42/plan.md` section; assert the
   prompt keeps the former and lacks the latter, and that an all-bookkeeping
   diff aborts with exit 3. PR also closes #312.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_agy_review.sh` | New: stdin stream-json invocation, result-event + timeout validation, owns the findings file |
| `.agent/scripts/cross_model_review.sh` | gemini arms call the helper with no stdout redirect; gemini-only tool-use footer; work-plans sections filtered out of the diff (#312); header comments |
| `.agent/scripts/tests/test_cross_model_review.sh` | New agy mock; seven tests above incl. a mock-tmux test and a stale-findings test; retire the `-p`-value assertions |
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

- None blocking. Plan review round 1 (needs-work) findings 1–5 are folded in
  above: no sidecar under the work-plans dir, helper owns the findings file,
  tmux-path test, gemini-only prompt paragraph, timeout marker treated as
  failure. Round 2 findings folded in: helper truncates the findings file
  first, no temp files survive any exit path, no staging `mv`, #312 opened
  for the trimming half of #274, timeout comment corrected, headless file
  reads verified. If the owner prefers agy to be allowed read-only git
  commands during review, that is an allow-rule in his agy settings and
  independent of this change.

## Estimated Scope

Single PR (closes #288, #274, #312).

## Implementation Notes

- Two live Gemini reviews of this branch through the new path were run
  during implementation (2026-09-22). Both completed over stdin with no
  denial and no temp leaks, and both found real defects that were fixed:
  non-compact NDJSON, bare-binary resolution, the filter dropping files
  renamed out of work-plans, `diff.noprefix`, and a tab-separated field
  parse that lost the error message. The mock agy now refuses multi-line
  input so the first of those cannot regress silently.
- jq 1.7 replaces invalid UTF-8 in the prompt with U+FFFD rather than
  failing, so no sanitising step was added.
- Out of scope, noted for the PR: the codex/claude/copilot arms keep the
  old `> findings 2>&1` invocation with no result validation, so the #288
  failure class is still undetected for them.
