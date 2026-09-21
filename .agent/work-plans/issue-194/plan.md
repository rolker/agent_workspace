# Plan: worktree_enter.sh: route Unknown-option (and other arg-validation) errors to stderr

## Issue

https://github.com/rolker/agent_workspace/issues/194

## Context

`.agent/scripts/worktree_enter.sh`'s argument-parsing and validation errors
mix `echo` (stdout) and `echo ... >&2` (stderr) inconsistently. PR #180
(commit d7d8fa8) routed the not-found-issue/skill paths (current lines 234,
285) to stderr, but several `Error: ...` messages were missed. This breaks
the `2>/dev/null` idiom `/start-task`'s SKILL.md relies on to suppress
"no worktree found yet" noise while falling through to `worktree_create.sh`.

Current un-routed `echo "Error: ..."` (and two related unrouted `echo`
lines) in `worktree_enter.sh`, confirmed by reading the file at this
revision:

| Line | Message |
|---|---|
| 74 | `Error: --skill requires a skill name` |
| 106 | `Error: Unknown option $1` (the issue's headline case) |
| 125 | `Error: --issue and --skill are mutually exclusive` |
| 130 | `Error: either --issue or --skill is required` |
| 135 | `Error: --type is required (workspace or project)` |
| 140 | `Error: --type must be 'workspace' or 'project'` |
| 144 | `Error: --print-path and --shell-snippet are mutually exclusive` |
| 148 | `Error: --project is only valid with --type project` |
| 365 | `Error: This script must be sourced for interactive use.` (+ its follow-up usage line) |
| 383 | `Error: Failed to cd to $WORKTREE_DIR` |

Lines 171, 203, 234, 285 already route to stderr (prior work / `_resolve_base_dirs`
callers) — no change needed there.

The issue text calls out lines 104/125-148 by number from an earlier
revision; the Issue Review confirmed the additional line-74 case and the
125-148 cluster carry into this plan. This plan additionally includes
lines 365 and 383, found during this pass, because the issue's own
acceptance criterion ("All `Error: ...` messages ... route to stderr")
covers every `Error:`-prefixed echo in the file by intent, not just the
ones enumerated in the issue body.

## Approach

1. **Route every un-routed `Error:` echo to stderr** — add `>&2` to each
   line listed above in `.agent/scripts/worktree_enter.sh`. No behavioral
   change: exit codes, `show_usage` calls, and control flow are untouched;
   only the output file descriptor changes. `show_usage()` itself writes
   the multi-line help via `echo` with no explicit stream — leave that as
   stdout (usage/help text is conventionally stdout, and the issue's
   acceptance criteria and repro command target only the `Error: ...`
   lines, not `show_usage`'s body).
2. **Add a regression test** — new file
   `.agent/scripts/tests/test_worktree_enter_stderr.sh`, following the
   style of `test_resolve_work_plans_dir.sh` (plain bash, `assert_*`
   helpers, `PASS`/`FAIL` counters, non-zero exit on failure). For each of
   the four required error paths (unknown option, missing `--skill` name,
   mutually-exclusive `--issue`/`--skill`, missing `--type`), invoke
   `worktree_enter.sh` as a subprocess with `2>/dev/null` and assert stdout
   is empty and the exit status is non-zero. Also cover the remaining
   un-routed paths found in step 1 (either/or missing, `--type` value
   validation, `--print-path`/`--shell-snippet` mutual exclusivity,
   `--project` without `--type project`) for full coverage of what
   changed, and register the new file in `run_script_tests.sh`'s
   discovery if that script requires explicit registration (verify — it
   may glob `test_*.sh` automatically).
3. **Manual verification** — re-run the issue's own repro command
   (`worktree_enter.sh --foo bar --print-path 2>/dev/null`) and confirm
   empty output, matching acceptance criterion 1.
4. **SKILL.md caveat removal (acceptance criterion 3)** — `.claude/skills/start-task/SKILL.md`
   line 70 reads: "The `worktree_enter.sh` 'Unknown option' path still
   writes to stdout ... see #194 for routing that to stderr too." Remove
   that sentence (and the dangling `#194` reference) now that the fix
   lands, so the PR doesn't leave that comment stale. (Confirmed in
   scope: the Issue Review's Consequences section flags this as required
   in the same PR, not deferred.)

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/worktree_enter.sh` | Add `>&2` to the 10 un-routed `Error: ...` echo lines listed above |
| `.agent/scripts/tests/test_worktree_enter_stderr.sh` | New regression test covering all error paths under `2>/dev/null` |
| `.claude/skills/start-task/SKILL.md` (line 70) | Remove/tighten the stdout-leak caveat now that all paths route to stderr |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | This is exactly a "no test existed, regression already happened once" case (PR #180 fixed some paths, missed others) — the new test file directly targets that failure mode. |
| A change includes its consequences | SKILL.md caveat removal is included in this plan, not deferred, per the Issue Review's explicit flag. |
| Only what's needed | Scope stays to stream-routing only; no exit-code or interface changes, no touching `worktree_create.sh` (explicitly out of scope in the issue). |
| Improve incrementally | Small, single-file behavioral fix plus one small test file — reviewable in one PR. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0012 — Worktree composition is an adapter concern | No | No change to multi-repo composition logic, `.worktree-repos`, or adapter verbs — pure output-stream routing. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `worktree_enter.sh` error routing | `start-task/SKILL.md`'s stdout-leak caveat | Yes — step 4 |
| `worktree_enter.sh` error routing | Regression test coverage | Yes — step 2 |
| Test suite | `run_script_tests.sh` discovery (if not auto-globbed) | Yes — verified in step 2 |

## Open Questions

None — issue and Issue Review action items give the full required scope.

## Estimated Scope

Single PR. One script edit (~10 one-line changes), one new test file, one
SKILL.md tightening.
