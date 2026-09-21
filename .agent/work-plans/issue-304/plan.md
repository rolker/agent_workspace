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
   `RUN_TMPDIR=$(mktemp -d --tmpdir=/tmp run-script-tests.XXXXXX)` —
   hardcoded under `/tmp`, independent of `$TESTS_DIR`/`[tests-dir]` so
   nested runs (PR 2's own test suite calling the runner against a scratch
   tests-dir) don't redirect the guard at that scratch dir. This form is
   deliberate, not stylistic: step 5 adds a lint for the pattern
   `mktemp[^|]*/tmp/`, and this line has to keep passing that lint on every
   run of the suite it lives in. `mktemp -d /tmp/run-script-tests.XXXXXX`
   matches the pattern (the literal `/tmp/` sits right after `mktemp`);
   `mktemp -d --tmpdir=/tmp run-script-tests.XXXXXX` does not (no `/tmp/`
   token follows `mktemp` — `--tmpdir=/tmp` has no trailing slash before the
   template, and the template itself is a bare relative name), while
   producing the same directory location and the same random-suffix
   semantics as `-d`'s directory-creation form. This keeps the plan's
   invariant — "no absolute template anywhere under
   `.agent/scripts/tests/`" — literally true rather than carved out by
   exception. Export `RUN_TMPDIR` as `TMPDIR`, `TMP`, and `TEMP` for every
   suite invocation. Add `trap 'rm -rf "$RUN_TMPDIR"' EXIT` right after
   creating it, so the directory is removed unconditionally on every exit
   path (pass, suite failure, leak failure, lint failure, or an early
   `exit 1` from the existing preflight checks above the loop).

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

3. **Exit codes header.** Update lines 26–27 to document all applicable
   codes: `0` all suites passed; `1` a suite failed, `test_checkpoint_269.sh`
   is missing, a required tool is missing, or the absolute-`/tmp`-`mktemp`
   lint (step 5) found a violation — all preflight-class failures, same
   code, distinguished only by message; `2` a suite left files in `TMPDIR`
   after it ran (leak detected, named in the failure message).

4. **`test_run_script_tests.sh` coverage** (new cases, added alongside the
   existing (a)–(d)):
   - **Leak case**: a fixture suite that writes a file directly into
     `$TMPDIR` (not a subdir it registers/cleans) and exits 0. Running the
     runner against a scratch tests-dir containing this fixture must exit
     `2` and print a message naming that fixture's filename. Concrete
     independence check: run the same leak fixture from a scratch tests-dir
     that is **not** located under `$TMPDIR` (e.g. created via
     `mktemp -d -p "$SANDBOX"` where `$SANDBOX` is outside `$TMPDIR`) and
     assert exit `2` either way — this is the observable form of "the
     guard's own `RUN_TMPDIR` is independent of `[tests-dir]`," since a
     guard that accidentally keyed off the tests-dir path would behave
     differently depending on where the scratch directory sits.
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
   plan scope).** Lives in `run_script_tests.sh` itself, as a preflight
   step run once before the per-suite loop, alongside the existing
   tool-availability preflight (same class of failure — see step 3). It
   lints `$TESTS_DIR` (the caller-supplied `[tests-dir]`, line 58) rather
   than a hardcoded `.agent/scripts/tests/`, so `test_run_script_tests.sh`
   can actually exercise it: a fixture file with an absolute-`/tmp/`
   template placed in a scratch tests-dir is reachable via `[tests-dir]`
   only in this form — a hardcoded path would always lint the real
   directory and could never see a fixture. Pattern (same one PR 1's
   verification used): `grep -rnE 'mktemp[^|]*/tmp/' "$TESTS_DIR"/*.sh`.
   Because the guard dir in step 1 uses `--tmpdir=/tmp` (not
   `/tmp/...`), it does not match this pattern, so the lint stays green on
   `run_script_tests.sh`'s own first run rather than failing on the line
   that introduces it. On a match, print the offending file and exit `1`
   (documented in step 3's header as the same preflight-failure code used
   for the missing-tool case) before any suite runs. Today the real
   `.agent/scripts/tests/` directory has no live target (PR 1's
   normalisation is complete and verified in the Issue Review), so the
   check passes with no match on ordinary runs — it is a regression guard
   against a *future* suite reintroducing an absolute template that would
   bypass `TMPDIR` and this guard's sweep. Add one test case: a fixture
   file containing an absolute-`/tmp/` `mktemp` call, placed in a scratch
   tests-dir, makes the lint fail with exit `1` and names the offending
   file.

6. **`AGENTS.md` Script Reference row.** Single-row edit (line 411) — update
   the `run_script_tests.sh` description to mention the leak guard. This
   touches an instruction file, which normally needs Ask-First approval;
   that approval was already given — the owner approved this specific
   one-row edit at this issue's `## Checkpoint` (`revise` decision,
   `.agent/work-plans/issue-304/progress.md`, 2026-09-21). Cite that
   checkpoint in the PR description as the approval, not a general standing
   rule for Script Reference edits.

7. **One-time cleanup note — document, do not automate.** Add a comment near
   the new guard in `run_script_tests.sh` plus a paragraph in the PR
   description (and post it to the #297 closing comment, since that's where
   the directory count is most discoverable) covering:
   - A dry-run form first, so the owner sees the match set before anything
     is removed — scoped to sandbox roots recognizable as this repo's own
     (a `.git` directory sitting directly at depth 1 of the sandbox root,
     i.e. the root itself was `git init`'d) and old enough not to catch an
     in-flight run:
     ```bash
     find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +1 \
         -exec sh -c '[ -d "$1/.git" ] && echo "$1"' _ {} \;
     ```
   - The deleting form, run only after reviewing the dry-run's output:
     ```bash
     find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +1 \
         -exec sh -c '[ -d "$1/.git" ] && rm -rf "$1"' _ {} \;
     ```
   - The caveat, restated on the actual mechanism: the filter only matches
     when `.git` sits directly at depth 1 of the sandbox root — i.e. the
     sandbox root itself was `git init`'d. Most suites nest their fixture
     repos deeper (a `.git` two or more levels down, inside a subdirectory
     of the sandbox), which this depth-1 check does not reach, and
     `test_adapter.sh`, `test_project_registry.sh`, and
     `test_dispatch_phase.sh` create no git repos at all (verified: no
     `git init` call in any of the three) — none of their leaked
     directories match the filter, regardless of nesting. Measured
     2026-09-21: 16,679 `/tmp/tmp.*` directories on this machine, 5,934
     with a depth-1 `.git` (~a third) — the command clears roughly that
     fraction and leaves the rest, including all of the three suites'
     output, in place.
   - An age-based alternative for the owner to run with judgement, with no
     `.git` filter, left for a human to eyeball before running:
     `find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +7`.
   - This is a one-time manual cleanup, not something the PR's code runs —
     per the "human control and transparency" principle, nothing here
     deletes arbitrary `/tmp` entries automatically.
   - **Guard coverage boundary (state explicitly in the PR, not just here):**
     the sweep only sees what lands in `TMPDIR` during a suite's run; the
     lint (step 5) only covers `.agent/scripts/tests/*.sh`. Eight absolute-
     `/tmp` `mktemp` sites remain in production scripts that suites may
     invoke — verified against the current tree: `worktree_create.sh:933,974`,
     `pr_status.sh:321,336`, `gh_create_pr.sh:237,306`,
     `fetch_pr_reviews.sh:148`, `gh_create_issue.sh:205` — and any temp
     files those calls create bypass both `TMPDIR` and this guard's sweep.
     Fixing those sites is out of scope for this PR; stating the boundary
     here keeps the guard from reading as total coverage.

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
| `.agent/scripts/tests/run_script_tests.sh` | Per-run `RUN_TMPDIR` via `mktemp -d --tmpdir=/tmp run-script-tests.XXXXXX` (created before the suite loop, exported as `TMPDIR`/`TMP`/`TEMP`, unconditional `EXIT` trap); post-suite leak sweep inside the loop with distinct exit code 2; absolute-`/tmp` `mktemp` preflight lint over `$TESTS_DIR`/*.sh, exit 1; updated `# Exit codes:` header (lines 26–27); one-time-cleanup comment near the guard, including the guard's coverage boundary |
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
