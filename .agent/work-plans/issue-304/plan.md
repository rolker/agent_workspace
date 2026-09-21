# Plan: run_script_tests.sh — per-run TMPDIR guard that fails the run on a leaked sandbox (#297 PR 2)

## Issue

https://github.com/rolker/agent_workspace/issues/304

## Context

PR 1 (#303, merged as `805d7a3`) converted every `.agent/scripts/tests/test_*.sh`
suite onto one top-level `$SANDBOX` + `EXIT` trap and normalised all ten
absolute-`/tmp/...` `mktemp` sites so every suite honors `TMPDIR`. Measured
leak went from 320 dirs/run to 0. That fixed the current leak but added no
enforcement: nothing stops a future suite from reintroducing an absolute
`mktemp -d /tmp/...` template or an unregistered sandbox.

This PR — PR 2 of the parent plan (`.agent/work-plans/issue-297/plan.md`,
three review rounds, final verdict ready) — is the enforcement layer, and
closes both #304 and its parent #297. Nothing here is a new design: it is
PR 2 as already approved, plus one addition the owner made at this issue's
Checkpoint (`.agent/work-plans/issue-304/progress.md`, `## Checkpoint`,
2026-09-21): keep the lint the issue proposed for absolute-`/tmp/` `mktemp`
templates, declared explicitly as a regression guard beyond the parent
plan's approved PR 2 text, not as already-approved scope.

`.agent/scripts/tests/run_script_tests.sh` currently (verified against the
file on this branch):
- Line 58: `TESTS_DIR="${1:-$SCRIPT_DIR}"` — the caller-supplied `[tests-dir]`.
- Lines 26–27: the `# Exit codes:` header, documenting only `0` (all passed)
  and `1` (a suite failed, or `test_checkpoint_269.sh` missing).
- Lines 99–110: the per-suite loop — `for s in "${suites[@]}"; ... if ! bash
  "$s"; then ... exit 1; fi; done`. No `TMPDIR` is set for the suites today;
  they inherit whatever `TMPDIR` the caller's shell already has (or none,
  falling back to `/tmp`).

`.agent/scripts/tests/test_run_script_tests.sh` drives the runner against
scratch copies of a tests directory via `[tests-dir]` (never the real
`.agent/scripts/tests/`). Existing fail-fast assertions: case (b) (line 68,
missing checkpoint suite) and case (c) (line 99, first-failure stop) both
check `rc -ne 0`, not a specific code — a new distinct exit code for the
leak case does not break either.

## Approach

1. **Per-run TMPDIR guard in `run_script_tests.sh`.** Immediately before the
   per-suite loop (before line 99), create
   `RUN_TMPDIR=$(mktemp -d /tmp/run-script-tests.XXXXXX)` — hardcoded under
   `/tmp`, independent of `$TESTS_DIR`/`[tests-dir]` so nested runs (PR 2's
   own test suite calling the runner against a scratch tests-dir) don't
   redirect the guard at that scratch dir. Export it as `TMPDIR`, `TMP`, and
   `TEMP` for every suite invocation. Add
   `trap 'rm -rf "$RUN_TMPDIR"' EXIT` right after creating it, so the
   directory is removed unconditionally on every exit path (pass, suite
   failure, leak failure, or an early `exit 1` from the existing preflight
   checks above the loop).

2. **Sweep inside the per-suite loop.** After each `bash "$s"` call returns
   successfully (i.e. after the existing `if ! bash "$s"; then ... fi`
   block, only on the path that would otherwise continue to the next
   suite), check whether `$RUN_TMPDIR` is non-empty
   (`find "$RUN_TMPDIR" -mindepth 1 -print -quit`, or equivalent). A leak
   fails the run immediately — before advancing to the next suite — with a
   distinct exit code (`2`, since `1` is already "a suite failed /
   checkpoint missing") and a message naming the suite that just ran and the
   leaked path(s). This attributes the leak to the suite that caused it,
   not to whichever suite happens to run last.

3. **Exit codes header.** Update lines 26–27 to document all three codes:
   `0` all suites passed; `1` a suite failed, or `test_checkpoint_269.sh` is
   missing; `2` a suite left files in `TMPDIR` after it ran (leak detected,
   named in the failure message).

4. **`test_run_script_tests.sh` coverage** (new cases, added alongside the
   existing (a)–(d)):
   - **Leak case**: a fixture suite that writes a file directly into
     `$TMPDIR` (not a subdir it registers/cleans) and exits 0. Running the
     runner against a scratch tests-dir containing this fixture must exit
     `2` and print a message naming that fixture's filename. Assert the
     check does **not** depend on the scratch tests-dir path itself — the
     guard's own `RUN_TMPDIR` is independent of `[tests-dir]`, so the
     fixture's leak must be detected regardless of where the scratch tests
     directory lives.
   - **Clean case**: a fixture suite that creates and cleans up its own temp
     file within `$TMPDIR` before exiting must still let the run pass (exit
     0) — confirms the guard doesn't false-positive on ordinary, non-leaking
     `TMPDIR` usage inside a suite.
   - Re-check existing cases (a)–(d) still pass unmodified: (b) and (c)
     assert `rc -ne 0` (not a specific code), so the new code 2 doesn't
     affect them; (d)'s tool-preflight case asserts `rc -eq 1` specifically
     and runs before any suite executes, so it is unaffected by the
     post-suite sweep.

5. **Lint addition (owner-directed, beyond the parent plan's approved PR 2
   text — declare this explicitly in the PR description, not as inherited
   plan scope).** Add a check — in `run_script_tests.sh` itself (run once,
   before the suite loop, alongside the existing tool preflight) or as a
   case in `test_run_script_tests.sh` — that fails if any
   `.agent/scripts/tests/*.sh` contains an absolute `/tmp` `mktemp` template,
   using the same pattern PR 1's verification used:
   `grep -rnE 'mktemp[^|]*/tmp/' .agent/scripts/tests/*.sh`. Today this
   returns nothing (PR 1's normalisation is complete and verified in the
   Issue Review), so the check passes with no live target — it is a
   regression guard against a *future* suite reintroducing an absolute
   template that would bypass `TMPDIR` and this guard's sweep. Add one test
   case: a fixture file containing an absolute-`/tmp/` `mktemp` call makes
   the lint fail, naming the offending file.

6. **`AGENTS.md` Script Reference row.** Single-row edit (line 411) — update
   the `run_script_tests.sh` description to mention the leak guard. This is
   a standing-rule exception to the "Ask First: modifying instruction files"
   boundary: the workspace's own convention (used throughout this plan's
   history) treats a single Script Reference row edit as routine
   documentation-of-consequence, not a governance change, so it does not
   need separate Ask-First approval.

7. **One-time cleanup note — document, do not automate.** Add a comment near
   the new guard in `run_script_tests.sh` plus a paragraph in the PR
   description (and post it to the #297 closing comment, since that's where
   the ~2,800-directory figure was originally measured and is most
   discoverable) covering:
   - The recommended command, scoped to sandbox roots recognizable as this
     repo's own (contain a nested `.git`, i.e. came from a test that
     `git init`'d inside its sandbox) and old enough not to catch an
     in-flight run:
     ```bash
     find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +1 \
         -exec sh -c '[ -d "$1/.git" ] && rm -rf "$1"' _ {} \;
     ```
   - The caveat: this `.git`-presence filter only catches sandbox roots that
     were themselves `git init`'d. `test_adapter.sh`, `test_project_registry.sh`
     (their `make_sandbox()` roots), and `test_dispatch_phase.sh`'s fixture
     dirs are plain directories — only *nested* fixture repos inside them are
     git repos — so the command clears only part of the ~2,800 and leaves the
     rest in place.
   - An age-based alternative for the owner to run with judgement, with no
     `.git` filter, left for a human to eyeball before running:
     `find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +7`.
   - This is a one-time manual cleanup, not something the PR's code runs —
     per the "human control and transparency" principle, nothing here
     deletes arbitrary `/tmp` entries automatically.

8. **Carried from PR 1's review (deferred to this PR by owner checkpoint,
   `.agent/work-plans/issue-297/progress.md` lines 554–555):**
   - `test_merge_pr_root_resolution.sh`, `test_resolution_outside_repo()`
     (currently lines 128–137; the `mktemp -d -p "$SANDBOX"` call is at
     line 133): add a `git rev-parse --is-inside-work-tree` (or
     `--show-toplevel`) self-check immediately after creating `tmp`, that
     asserts the precondition — `tmp` is genuinely outside any git work
     tree — before asserting `resolve_root "$tmp"` returns empty. Without
     this, a future change to where `$SANDBOX` is rooted could silently
     move the probe inside a repo and the test would still "pass" for the
     wrong reason.
   - `test_block_bash_tool_mapping.sh`, line 29: `TMP_HOME="$SANDBOX/home"`
     (via `mkdir -p`) is a fixed-name subdirectory, not
     `mktemp -d -p "$SANDBOX"`. Decision: keep the fixed name. Nothing in
     this suite creates more than one `TMP_HOME` per run — it's a single,
     purpose-named fixture (a fake `$HOME`), not a per-test-iteration
     sandbox that needs per-call uniqueness the way the `mktemp -d -p
     "$SANDBOX"` sites do elsewhere in this plan. State this rationale in
     the PR description rather than silently leaving the suggestion
     unaddressed.

9. **Verification.**
   - Full `.agent/scripts/tests/run_script_tests.sh` (no `[tests-dir]` arg,
     the real suite set) passes.
   - The new leak fixture, run through `test_run_script_tests.sh`, fails the
     runner and names the offending suite.
   - Re-run PR 1's per-suite `TMPDIR=$(mktemp -d) bash test_X.sh; find
     "$TMPDIR" -mindepth 1` measurement across all suites — still 0 for
     every suite (confirms this PR's own changes, including the
     `TMP_HOME` fixed-name decision, introduced no new leak).
   - `git bug`/`gh`: this PR closes `#304` and, per the issue body and the
     Issue Review's dependency check, `#297` (`Closes #304`, `Closes #297`).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/tests/run_script_tests.sh` | Per-run `RUN_TMPDIR` (created before the suite loop, exported as `TMPDIR`/`TMP`/`TEMP`, unconditional `EXIT` trap); post-suite leak sweep inside the loop with distinct exit code 2; absolute-`/tmp` `mktemp` lint over `.agent/scripts/tests/*.sh`; updated `# Exit codes:` header (lines 26–27); one-time-cleanup comment near the guard |
| `.agent/scripts/tests/test_run_script_tests.sh` | New leak-fixture case (exit 2, names the suite); new clean-fixture case (still passes); new lint-fixture case (absolute-`/tmp` template fails the lint, names the file); confirm existing (a)–(d) cases unaffected |
| `.agent/scripts/tests/test_merge_pr_root_resolution.sh` | `test_resolution_outside_repo()` (~line 133) gains a `git rev-parse` self-check asserting the outside-any-repo precondition |
| `.agent/scripts/tests/test_block_bash_tool_mapping.sh` | No code change; PR description states why the fixed-name `TMP_HOME` (line 29) is kept as-is |
| `AGENTS.md` | Script Reference row for `run_script_tests.sh` (line 411) mentions the leak guard |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | The guard fails the run (exit 2) rather than warning; the lint fails rather than warning — both are hard stops, matching the parent issue's ask |
| A change includes its consequences | `AGENTS.md` row and `test_run_script_tests.sh` coverage are both in this PR; the one-time cleanup is documented, not silently left for someone to discover later |
| Only what's needed | The lint has no live target today (PR 1 already normalised every site) — kept only because the owner explicitly decided, at Checkpoint, to keep it as a regression guard; declared as such rather than folded in as inherited plan scope |
| Improve incrementally | Single PR, no open design decisions — plan review already converged on PR 2's shape; the two PR 1 carry-overs are small, scoped edits |
| Test what breaks | Leak path, clean path, and lint path each get a fixture case; existing fail-fast cases re-verified against the new exit code |
| Human control and transparency | Cleanup command is documented, not run by the code; the `TMP_HOME` decision and the lint's owner-directed origin are both stated explicitly in the PR rather than silently absorbed |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0011 (adapter contract) | No | `run_script_tests.sh` is the script-test runner wired into the `validate-script-tests` pre-commit hook, not `TEST_CMD`/`adapter test` — same correction the Issue Review and #297's Issue Review both made; this PR doesn't touch the adapter |
| ADR-0013 (`progress.md` entry-type vocabulary) | Yes | This plan's own `## Plan Authored` entry, and later `## Implementation`/review entries, follow the vocabulary; no other action needed now |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| A script in `.agent/scripts/` (`run_script_tests.sh`'s behavior) | Script Reference table in `AGENTS.md` | Yes — step 6 |
| A test suite's exit-code contract | Its own header comment, and any caller that inspects the code | Yes — header updated; no other script inspects `run_script_tests.sh`'s exit code beyond "zero or nonzero" (pre-commit hook, CI) so no further updates needed |
| Parent issue #297's scope | #297's closure | Yes — this PR closes both #304 and #297 |

## Open Questions

None — the parent plan's PR 2 section is three-round reviewed and approved;
the one addition (the lint) was resolved at this issue's Checkpoint
(proceed, keep the lint, declared as an addition beyond the parent plan).

## Estimated Scope

Single PR — one script change (`run_script_tests.sh`), one test file
(`test_run_script_tests.sh`) plus small edits to two existing test files
carried from PR 1's review, one `AGENTS.md` row, and the cleanup note in the
PR description / #297 closing comment. Proportionate to the parent issue's
own estimate ("~1 script change, ~1 test file, one doc row, one note").
