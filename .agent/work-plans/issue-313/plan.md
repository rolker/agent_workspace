# Plan: cross_model_review.sh: codex/claude/copilot arms have no result validation

## Issue

https://github.com/rolker/agent_workspace/issues/313 (folds in #212)

## Context

`_agy_review.sh` gives the gemini arm a forced validation gate: it owns the
findings file, truncates it first, treats exit!=0, timeout, empty response,
and non-SUCCESS status as failure via `fail()`, and only a real response
reaches the file. The codex/claude/copilot arms in `run_agent_sync`
(`.agent/scripts/cross_model_review.sh:213-217`) are still bare
`timeout ... "$bin" ... < "$prompt" > "$findings" 2>&1`, gated on exit code
alone. Two concrete bugs ride on this gap:
- codex (#313 comment): `codex exec < prompt` echoes the whole prompt and
  tool transcript to stdout before the final answer; `-o/--output-last-message
  <FILE>` (confirmed in `codex exec --help`) writes only the final message.
- copilot (#212): `-p < prompt` is wrong — `-p, --prompt <text>` takes the
  prompt as an **argument**, not stdin; `--allow-all-tools` is required or
  the CLI blocks on an interactive permission prompt with stdin closed.

Confirmed from `--help` (no live prompts run, per quota constraints):
- **codex**: `codex exec [OPTIONS] [PROMPT]` — reads stdin as prompt only
  when no `[PROMPT]` arg is given ("If not provided as an argument (or if
  `-` is used), instructions are read from stdin"); `-o <FILE>` for the
  final message; no native JSON result object, so "empty" means an empty/
  absent `-o` file. No documented error-marker vocabulary — detect via
  empty file + stderr excerpt.
- **claude**: `-p/--print` with `--output-format json` returns a single
  JSON result object (mirrors agy's `result` event) — parseable via `jq`,
  same shape of validation as `_agy_review.sh`.
- **copilot**: `-p, --prompt <text>` is an argument, not stdin; `--allow-all-tools`
  required for non-interactive; `-s/--silent` "output only the agent response
  (no stats)"; `--output-format json` (JSONL) available but `text` + `-s` is
  simplest to validate (non-empty stdout after silencing stats).

## Approach

1. **Add `.agent/scripts/_review_helper_common.sh`** (sourced, not
   executed) — the shared skeleton: `rh_truncate_findings`, `rh_fail`
   (writes reason to findings file + stderr, `exit 1`), `rh_mktemp_dir`
   (under `$TMPDIR`, EXIT/INT/TERM/HUP traps matching `_agy_review.sh`),
   `rh_stderr_excerpt` (last 20 lines). Keep `_agy_review.sh`'s own shape
   as-is — it already implements this contract correctly and is
   agy-specific (stream-json parsing has no analog in the other three);
   refactoring it onto the shared skeleton is out of scope (churn without
   benefit) but the new helpers mirror its function names/behavior 1:1 so
   a future refactor is mechanical.
2. **Add three thin per-CLI helpers** using the shared skeleton, one
   invocation + one result-extraction function each:
   - `.agent/scripts/_codex_review.sh <codex-bin> <prompt-file> <findings-file> [<timeout>]`
     — runs `"$bin" exec -o "$out_file" < "$prompt"` with stdout/stderr to a
     temp log (kept only on failure, appended via `rh_stderr_excerpt`);
     `fail` on exit!=0, on `$out_file` missing/empty after trim. No known
     text markers documented for codex; report exit code + stderr excerpt.
   - `.agent/scripts/_claude_review.sh <claude-bin> <prompt-file> <findings-file> [<timeout>]`
     — runs `"$bin" -p --output-format json < "$prompt"`, parses the single
     JSON object with `jq`; `fail` on exit!=0, invalid JSON, `.is_error ==
     true`, `.subtype != "success"`, or empty/missing `.result`. Detect
     `.result`/error text containing `usage limit`, `rate limit`, `overloaded`,
     `not logged in` as known markers (surfaced in the failure reason, not a
     separate gate — the JSON status fields are authoritative).
   - `.agent/scripts/_copilot_review.sh <copilot-bin> <prompt-file> <findings-file> [<timeout>]`
     — fixes #212: `"$bin" -p "$(cat "$prompt")" --allow-all-tools -s`
     (argument, not stdin — `$()` strips no meaningful content since the
     prompt is text, and the CLI takes `-p <text>` only as an argument per
     `--help`); `fail` on exit!=0 or empty stdout after trim. Known markers:
     `quota`, `rate limit`, `not authenticated`/`login required`.
   Each helper: truncates findings first, `fail()` writes reason + exits 1,
   success writes only the review text (strip copilot's
   `Changes / Requests / Tokens` footer per #212's note, via
   `sed -n '/^Changes$/q;p'` or equivalent before writing).
3. **Wire `run_agent_sync`** (`cross_model_review.sh:213-217`) to call the
   three new helpers exactly the way gemini already calls `_agy_review.sh`:
   `exec env TMPDIR="$AGENT_TMP_ROOT" timeout -k "$AGENT_KILL_AFTER"
   "$AGENT_TIMEOUT" "$CODEX_REVIEW_HELPER" "$bin" "$prompt" "$findings"`
   (same for claude/copilot). Resolve `CODEX_REVIEW_HELPER` /
   `CLAUDE_REVIEW_HELPER` / `COPILOT_REVIEW_HELPER` next to
   `AGY_REVIEW_HELPER`'s existing resolution. `EXIT=` semantics in the
   `--agents` output loop (lines ~920-936) are unchanged — the helper's own
   exit code already flows through `wait`.
4. **Tests** in `.agent/scripts/tests/test_cross_model_review.sh`: extend
   `make_mock_agent` (or add per-CLI mock functions) so each mock
   reproduces its CLI's real output shape:
   - codex mock: writes banner + prompt echo to stdout, writes only the
     final message to the file named by its `-o` arg.
   - claude mock: reads `--output-format json`, emits a single JSON object
     (`{"type":"result","subtype":"success","is_error":false,"result":"..."}`)
     on stdout.
   - copilot mock: asserts it was invoked with `-p <text>` as an argument
     (not via stdin) and `--allow-all-tools`/`-s` present — fails loudly if
     invoked the old (#212) way; prints only the response.
   Cover per CLI: success, empty response, non-zero exit, timeout (reuse
   existing timeout harness), and one known-error-marker case. Add an
   explicit copilot-invocation-contract assertion (#212 regression test).
   Keep the existing 196 assertions green; run
   `.agent/scripts/tests/run_script_tests.sh`.
5. **Exec bit**: `chmod +x` the three new helper scripts (and
   `_review_helper_common.sh` if made executable — it's sourced, so leave
   it non-executable to signal that).
6. **Docs**:
   - `AGENTS.md` Script Reference — add rows for `_codex_review.sh`,
     `_claude_review.sh`, `_copilot_review.sh`, `_review_helper_common.sh`,
     following the `_agy_review.sh` row's pattern.
   - `.claude/skills/review-code/SKILL.md` — update the "reading the
     result" note if it currently assumes exit-code-only validation for
     codex/claude/copilot.
   - `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md`
     — update the Consequences bullet "The per-agent result validation that
     Gemini has (#288) is still missing for Codex, Claude and Copilot; that
     is #313, unchanged by this decision" to reflect closure.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_review_helper_common.sh` | New: shared truncate/fail/tempdir/stderr-excerpt skeleton |
| `.agent/scripts/_codex_review.sh` | New: codex headless turn + validation (`-o` file, no stdout echo) |
| `.agent/scripts/_claude_review.sh` | New: claude headless turn + validation (`--output-format json`) |
| `.agent/scripts/_copilot_review.sh` | New: copilot headless turn + validation, fixes #212's `-p`/`--allow-all-tools` bug |
| `.agent/scripts/cross_model_review.sh` | `run_agent_sync`: codex/claude/copilot arms call the new helpers, same `exec`/`timeout -k` discipline as gemini |
| `.agent/scripts/tests/test_cross_model_review.sh` | Per-CLI mocks matching real output shapes; success/empty/nonzero-exit/timeout/error-marker cases; #212 copilot invocation regression test |
| `AGENTS.md` | Script Reference rows for the four new/shared scripts |
| `.claude/skills/review-code/SKILL.md` | Update result-reading note if exit-code-only assumption exists |
| `docs/decisions/0015-parallel-sync-is-the-only-review-dispatch-mode.md` | Close out the "still missing for Codex, Claude and Copilot" consequence bullet |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | Each CLI gets a forced gate matching gemini's, not just better logging — codex/claude/copilot cannot report success on an empty or auto-denied response. |
| Test what breaks | Mocks reproduce each CLI's real failure shapes; timeout, empty response, non-zero exit, and error markers are all covered, plus the #212 invocation regression. |
| Only what's needed | Shared skeleton avoids three duplicated truncate/fail/tempdir blocks; `_agy_review.sh` is left alone since its stream-json parsing isn't shared logic. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Yes | `run_agent_sync`'s `exec`/`timeout -k`/background-job structure is unchanged; only the per-agent command each arm execs into changes. The ADR's closing consequence bullet is updated to reflect this issue landing. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| codex/claude/copilot findings-file content on failure | `review-code`'s reading of `EXIT=` per agent | Yes — `EXIT=` contract itself is unchanged (helper's own exit code), no `review-code` change needed beyond confirming this |
| Copilot invocation flags | `AGENTS.md` script table, ADR-0015 consequence bullet | Yes |

## Open Questions

- None blocking. Codex/claude error-marker vocabulary (quota/auth/rate-limit
  text) is inferred from general CLI conventions, not confirmed against a
  live failing run (quota-constrained); the helper's stderr-excerpt fallback
  covers unrecognized failure text, so this doesn't block implementation.

## Estimated Scope

Single PR. Closes #313 and #212. Does not touch #320 (Standard tier +
plan-as-context for gemini/codex), which is explicitly sequenced after this
issue per its own "Related" note.
