# Plan: Pin codex's sandbox/approval flags in _cli_review.sh instead of relying on CLI defaults

## Issue

https://github.com/rolker/agent_workspace/issues/350

## Context

`.agent/scripts/_cli_review.sh`'s codex arm (line ~311) invokes:

```bash
run_cli "$STDOUT_FILE" "$STDERR_FILE" "$CLI_BIN_RESOLVED" exec -o "$CODEX_OUT_FILE"
```

This relies on codex-cli's current defaults (`sandbox: read-only`,
`approval: never`) rather than pinning them. A future codex-cli release or a
host `~/.codex/config.toml` override could silently grant write/full-access
execution to a headless review turn reading an untrusted diff, with nothing
in the script to catch it.

`-a/--ask-for-approval` is a top-level `codex` flag, not an `exec` subcommand
flag — confirmed against the installed codex-cli **0.156.1**:

```
$ codex exec -a never --help
error: unexpected argument '-a' found
$ codex -a never exec -s read-only --help
(OK)
```

So the fix must place `-s`/`-a` before `exec`, not after.

The matching test assertion (`test_cross_model_review.sh:2849`) currently
checks only `head -n 1 codex.argv == "exec"` — presence/position of `exec`
as the first token, not that the new flags precede it correctly.

Grepped `.agent/scripts/*.sh` for other codex invocations: `framework_config.sh`,
`detect_agent_identity.sh`, `detect_cli_env.sh`, `set_git_identity_env.sh`, and
`cross_model_review.sh` only reference codex for identity detection / dispatch
into `_cli_review.sh` — none invoke `codex exec` directly or expect write
access during a review turn. `_cli_review.sh` is the only place codex is
actually run, so pinning flags there is sufficient; no other code path needs
updating.

## Approach

1. **Pin the flags in `_cli_review.sh`** — change the codex `run_cli` call
   (`.agent/scripts/_cli_review.sh:311`) from
   `"$CLI_BIN_RESOLVED" exec -o "$CODEX_OUT_FILE"` to
   `"$CLI_BIN_RESOLVED" -s read-only -a never exec -o "$CODEX_OUT_FILE"`.
   Add a short comment above the `run_cli` call noting *why* (explicit >
   CLI default; `-a` must precede `exec`, verified on codex-cli 0.156.1)
   so a future edit doesn't accidentally move `-a`/`-s` after `exec`.

2. **Tighten the existing test assertion**
   (`.agent/scripts/tests/test_cross_model_review.sh`, `test_agents_all_succeed`,
   around line 2849) — replace the single-token check
   `assert_eq "codex invoked as 'codex exec'" "exec" "$(head -n 1 "$argv/codex.argv")"`
   with an assertion on the full leading argv sequence, so the test locks in
   *placement* (flags before `exec`), not just presence:
   `assert_eq "codex invoked with -s/-a pinned before exec" "-s\nread-only\n-a\nnever\nexec" "$(head -n 5 "$argv/codex.argv")"`
   (exact `assert_eq`/`head -n` wiring may need adjusting to the file's
   existing helper conventions — keep the intent: fail if `-s`/`-a` are
   missing, reordered, or appear after `exec`).

3. **Add a placement-regression case** — a new assertion (or small dedicated
   test) that would have caught the bug this issue describes: constructing
   the wrong invocation (`exec -a never -s read-only -o <file>`, flags
   *after* `exec`) and confirming it's distinguishable from the fixed argv,
   OR — simpler and sufficient — assert the exact expected prefix as in
   step 2, which already fails if flags land after `exec`. Prefer the
   simpler exact-prefix assertion (step 2) over adding a second test unless
   review flags the single assertion as insufficient.

4. **Note the codex-cli version checked** in the PR description: 0.156.1
   (this host, confirmed via `codex --version`), matching the version the
   issue was filed against.

5. **No other files need changes** — confirmed via grep that no other
   workspace script invokes `codex exec` or depends on codex having write
   access during a review turn.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_cli_review.sh` | Pin `-s read-only -a never` before `exec` in the codex `run_cli` call; add rationale comment |
| `.agent/scripts/tests/test_cross_model_review.sh` | Replace the single-token `codex.argv` assertion with one that checks `-s`/`-a` precede `exec` |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Flags become explicit in the script instead of implicit CLI defaults — the sandbox/approval posture is now visible and reviewable. |
| Enforcement over documentation | The fix is itself enforcement (explicit flags checked by a test), not a comment-only note. |
| Test what breaks | New assertion locks in flag *placement*, which is the actual failure mode (`-a` after `exec` errors on codex-cli 0.156.1) — not just flag presence. |
| Only what's needed | Two flags, one comment, one tightened assertion — no new abstraction or config surface. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Yes (touches `_cli_review.sh`) | Only the codex arm's invocation changes; dispatch mode, parallelism, and per-agent failure handling are untouched. |
| 0009 — Python package management | No | Bash-only change. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| codex's argv shape in `_cli_review.sh` | `test_cross_model_review.sh`'s codex-argv assertion | Yes — step 2 |
| flag placement contract | grep for other codex-write-expecting code paths | Yes — confirmed none exist (see Context) |

## Open Questions

- None — issue and Issue Review actions are fully addressed by this plan.
  If review considers a dedicated placement-regression test (step 3's
  alternative) necessary beyond the tightened assertion, that's a small
  addition during implementation, not a plan change.

## Estimated Scope

Single PR, two files.
