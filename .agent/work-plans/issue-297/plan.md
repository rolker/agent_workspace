# Plan: script tests: mktemp sandboxes registered inside $() never get cleaned — ~100 leaked into /tmp per run, stalling boot 2 min

## Issue

https://github.com/rolker/agent_workspace/issues/297

## Context

Every `test_*.sh` suite under `.agent/scripts/tests/` that wants an isolated
sandbox builds one with `mktemp -d`. Eight of the ~23 suites register that
sandbox inside a helper function that is only ever called as
`sb="$(helper)"` — the `SANDBOXES+=("$sb")` (or equivalent) line runs inside
the `$()` command-substitution subshell, so it mutates a copy of the array
that vanishes when the subshell exits. The parent shell's `SANDBOXES` stays
empty, `trap cleanup EXIT` faithfully iterates nothing, and every sandbox
directory is abandoned in `/tmp`. On this machine `/tmp` sits on plain ext4
(no tmpfs); systemd's `D /tmp` tmpfiles rule deletes the accumulated
leftovers synchronously at boot, and that sweep has run 12s–114s some
mornings this week.

The issue names three suites (`test_ros2_colcon.sh`, `test_merge_pr.sh`,
`test_precommit_hook_path.sh`). The Issue Review found the identical
`$()`-swallowed-array defect in `test_project_registry.sh`, `test_adapter.sh`,
and `test_merge_pr_gate.sh`, plus a fourth shape in `test_dispatch_phase.sh`,
whose `mk_sandbox()` creates a directory and returns it but never registers
it anywhere — no array, no trap coverage, unconditional leak on every call.
This plan's revision adds an eighth suite, `test_checkpoint_269.sh` (Plan
Review finding 5), whose `_sandbox_repo()` has the same untrapped shape as
`test_dispatch_phase.sh` and was missed in the original inventory. The
owner's checkpoint decision (progress.md) directs widening the fix to all
eight suites, making the suite-level guard required (not optional), and
standardizing on the `test_worktree_enter_stderr.sh` shape, now merged to
`main` (#194, PR #299 — this plan reads it as
`.agent/scripts/tests/test_worktree_enter_stderr.sh` on `main`, not the old
unmerged-branch reference): one `SANDBOX="$(mktemp -d)"` at top level
(never inside a `$()`), one `trap 'rm -rf "$SANDBOX"' EXIT`, with any
per-test isolation done as subdirectories under that single sandbox rather
than one `mktemp -d` per test.

Verified by reading each of the eight files directly (paths and line
references below are from the current `main` tree, after merging `main`
into this branch — see Implementation Notes):

| Suite | Defect shape | Registration site(s) |
|---|---|---|
| `test_ros2_colcon.sh` | `make_sandbox()` (`SANDBOXES=()` + `trap cleanup EXIT` at top; `SANDBOXES+=("$sb")` inside the function) called as `sb="$(make_sandbox)"` — 7 call sites, plus `make_worktree_sandbox()` which itself calls `make_sandbox` inside `$()` | lines 71–82, 202–218 |
| `test_merge_pr.sh` | Same shape; `make_merge_sandbox()` also registers a second path (`$bare`, the local bare remote) inside the same swallowed subshell | lines 59–66, 158–184 |
| `test_precommit_hook_path.sh` | `mk_ws()` registers via `SANDBOXES+=("$sb")` inside the function, called as `sb="$(mk_ws)"`; a second bare `sb="$(mktemp -d)"` at top level for a no-git fixture is *not* leaking (line 69, direct assignment outside a function) but should still fold into the single-sandbox convention | lines 24–50, 69 |
| `test_project_registry.sh` | `make_sandbox()`, identical shape, called as `sb="$(make_sandbox)"` — 10+ call sites across registry, dispatcher, and worktree test groups | lines 50–70 |
| `test_adapter.sh` | `make_sandbox()`, identical shape, called as `sb="$(make_sandbox)"` throughout | lines 62–83 |
| `test_merge_pr_gate.sh` | `make_sandbox()` takes args, still swallows `SANDBOXES+=` inside `$()`; several call sites also do a second `SANDBOXES+=("$outside")` / `SANDBOXES+=("$bare")` directly in the test body (those direct appends *do* work, since they're not inside a `$()` — only the ones inside `make_sandbox()` itself leak) | lines 26–28, 135–167, plus per-test extra sandboxes (e.g. 679–692) |
| `test_dispatch_phase.sh` | `mk_sandbox()` (line 27–38) has no `SANDBOXES` array and no per-sandbox trap at all — only `TMPD` (a single scratch dir for fixture files) is trapped; every `mk_sandbox` call (`SB0`, `SBX`, `SB`, `SBP1`, `SBP2`, ~5 sandboxes per run) leaks unconditionally | lines 17–38, 121, 350, 394–420, 425 |
| `test_checkpoint_269.sh` | `_sandbox_repo()` (lines 139–145) does `dir=$(mktemp -d)` and echoes it, called as `REPO=$(_sandbox_repo)` (161, 273) / `ORIGIN=$(_sandbox_repo)` (238) — **no `SANDBOXES` array and no `EXIT` trap anywhere in the file** (`set -u` only, line 34). Cleanup is explicit `rm -rf` on the success path only (201, 269, 288), so a clean pass doesn't leak but any abort or early exit does. This is the one suite `run_script_tests.sh` hard-requires by name, so it belongs in the conversion set rather than staying an exception. | lines 34, 139–145, 161, 201, 238, 269, 273, 288 |

Plan Review (finding 5) also caught that this plan's earlier draft claimed
"no additional suites with this shape were found beyond the seven above" —
that was wrong; `test_checkpoint_269.sh` is the eighth, added above. All
eight suites above are the full inventory of the `$()`-swallowed-array /
untrapped-helper shape; every other `test_*.sh` file either uses no
sandbox or already assigns `mktemp -d` directly at top level outside any
function/subshell.

Separately, five suites call `mktemp` with an **absolute `/tmp/...`
template**, which ignores `TMPDIR` entirely and so would leak straight past
the PR 2 guard even after conversion (Plan Review finding 4):
`test_block_bash_tool_mapping.sh:22`, `test_cross_model_review.sh:19`,
`test_gh_create_pr.sh:27`, `test_merge_pr_root_resolution.sh:23,122`,
`test_sync_gitbug.sh:28`. `test_merge_pr_root_resolution.sh:122` additionally
has no trap coverage on that `tmp` var at all (Plan Review finding 5,
smaller instance) — it is also the suite whose `outside-any-repo` case
(same line) is why finding 2 below rules out `.agent/scratchpad/` for the
per-run `TMPDIR`.

## Approach

Two PRs, in this order, so CI never sits red between them:

**PR 1 — convert all eight suites to the single-top-level-sandbox
convention, and normalise the five absolute-template `mktemp` sites.**
Mechanical, per-file:

1. For each suite, replace the per-call `mktemp -d` + swallowed-registration
   (or, for `test_dispatch_phase.sh` / `test_checkpoint_269.sh`,
   unregistered) helper with one `SANDBOX="$(mktemp -d)"` assigned directly
   at the top of the script (not inside any function or `$()`), and `trap
   'rm -rf "$SANDBOX"' EXIT` immediately after, matching
   `.agent/scripts/tests/test_worktree_enter_stderr.sh` on `main` (merged
   via #194 / PR #299).
2. **(Plan Review finding 1 — must-fix)** Every place that built a *fresh*
   sandbox per test becomes `mktemp -d "$SANDBOX/XXXXXX"` (or `mktemp -d -p
   "$SANDBOX"`) inside the helper — never a counter or the calling
   function's name assembled by the parent shell. The helpers are invoked
   as `sb="$(helper)"`: anything the helper computes and stores in a
   variable to derive uniqueness (a counter it increments, a name it
   builds) lives inside that `$()` subshell and is invisible to the next
   call, so a counter-based scheme silently collapses every call onto the
   same subdirectory — tests would share one sandbox instead of leaking.
   `mktemp -d -p "$SANDBOX"` needs no shared state to stay unique, so this
   sidesteps the subshell problem entirely rather than working around it.
3. `test_merge_pr.sh`'s extra `$bare` (local bare remote) and
   `test_merge_pr_gate.sh`'s extra `$outside` / `$bare` sandboxes become
   subdirectories of the same `$SANDBOX` too, dropping their separate
   `SANDBOXES+=` appends entirely (there is only one array to maintain
   after this change: none — cleanup is just `rm -rf "$SANDBOX"`).
   **(Plan Review finding 9 — suggestion)** These `outside` / `bare`
   sandboxes exist specifically to sit *outside* the per-test sandbox root
   in `test_project_registry.sh` (lines 726, 989, 1086, 1113, 1165) and
   `test_merge_pr.sh` (line 681) — when folding them under `$SANDBOX`, make
   them siblings of the per-test subdirectory (`$SANDBOX/outside-<x>`, a
   sibling of `$SANDBOX/<x>`), never children of the per-test `$sb`, so
   "outside the sandbox workspace root" still holds relative to what the
   test under it treats as its root.
4. `test_dispatch_phase.sh` gets the same treatment for `mk_sandbox()`
   (currently unregistered anywhere) and can fold its existing `TMPD`
   scratch dir into the same top-level `$SANDBOX` rather than keeping two
   separate trapped directories.
5. `test_precommit_hook_path.sh`'s already-correct top-level `nogit="$(mktemp
   -d)"` fixture (line 69) moves under `$SANDBOX` too, for one convention
   instead of two coexisting ones in the same file.
6. **(Plan Review finding 5 — must-fix)** `test_checkpoint_269.sh` gets the
   same conversion: `_sandbox_repo()` (lines 139–145) moves to
   `mktemp -d -p "$SANDBOX"`, a top-level `SANDBOX` + `EXIT` trap is added
   (the file currently has neither), and the explicit success-path `rm -rf`
   calls (201, 269, 288) are dropped in favor of the trap — the file is the
   one suite `run_script_tests.sh` hard-requires by name, so it is no
   longer excluded from the conversion set.
7. **(Plan Review finding 4 — must-fix)** Normalise the five suites that
   call `mktemp` with an absolute `/tmp/...` template (which ignores
   `TMPDIR` and would leak past the PR 2 guard even after this
   conversion): `test_block_bash_tool_mapping.sh:22`,
   `test_cross_model_review.sh:19`, `test_gh_create_pr.sh:27`,
   `test_sync_gitbug.sh:28` — drop the hardcoded `/tmp/` prefix so `mktemp`
   honors `TMPDIR`, folding each into that suite's own top-level `$SANDBOX`
   per steps 1–2. `test_merge_pr_root_resolution.sh` is the one exception:
   its line 23 fixture normalises the same way, but line 122
   (`test_resolution_outside_repo`) hardcodes `/tmp` *on purpose* to
   guarantee the probe sits outside any git work tree — per finding 2
   below, `TMPDIR` itself will now always be outside a work tree too, so
   this one can switch to `mktemp -d` (honoring `TMPDIR`) once that holds;
   it also has no trap coverage today (Plan Review finding 5, smaller
   instance) and picks up one in this same edit.
8. Verification per suite: run it directly with `TMPDIR` pointed at an
   empty scratch directory under `/tmp` (`TMPDIR=$(mktemp -d) bash
   .agent/scripts/tests/test_X.sh; find "$TMPDIR" -mindepth 1`) and confirm
   the directory is empty afterward, in addition to the suite's own pass
   count staying unchanged.
9. No suite's test *logic* changes — assertions, fixtures, and stubs are
   untouched. This keeps the PR reviewable as "sandbox plumbing only."

**PR 2 — the enforcement layer, its own test coverage, and the one-time
cleanup note**, landed promptly once PR 1 has merged and every suite is
confirmed leak-free (so the new guard passes on first run rather than
immediately failing on suites PR 1 hasn't reached yet). **(Plan Review
finding 10 — suggestion)** PR 1's per-suite manual `TMPDIR` check is the
only protection against a regression in the gap between the two PRs
landing, so PR 2 should follow PR 1 with no unrelated work in between, and
its own landing is verified with a full `run_script_tests.sh` run (not
just the new suite in isolation):

1. Add a suite-level guard to `.agent/scripts/tests/run_script_tests.sh`
   (the runner wired into the `validate-script-tests` pre-commit hook — not
   `.agent/scripts/test.sh`/`adapter test`, which runs the *project's* own
   `TEST_CMD` and has nothing to do with this repo's script-test suite,
   per the Issue Review's ADR-0011 correction). **(Plan Review finding 2 —
   must-fix)** Create the per-run `TMPDIR` under `/tmp` (e.g. `TMPDIR=$(
   mktemp -d /tmp/run-script-tests.XXXXXX)`), *not* under
   `.agent/scratchpad/`: `.agent/scratchpad/` sits inside the workspace git
   work tree, and `test_adapter.sh` / `test_project_registry.sh`
   deliberately build sandbox roots that are *not* themselves git repos
   (they `git init` only nested fixture repos), while
   `test_merge_pr_root_resolution.sh::test_resolution_outside_repo`
   (line 122) asserts root resolution returns empty outside any repo. A
   `TMPDIR` inside the work tree makes upward `git rev-parse` discovery
   find the real workspace root from inside those sandboxes, turning both
   cases into false passes or false failures. This holds regardless of
   `.agent/scratchpad/` being gitignored — ignore rules affect what git
   tracks, not what `git rev-parse --show-toplevel` discovers walking
   upward, so a sandbox under the gitignored scratchpad still resolves to
   the workspace root. `/tmp` is permitted by `AGENTS.md`'s "ephemeral
   files cleaned up in the same command" rule since the guard deletes the
   directory unconditionally at the end of the run. Export `TMPDIR` before
   the suite loop so every suite's `mktemp -d` calls land there.
2. **(Plan Review finding 7 — suggestion)** Sweep for leftover entries
   inside the existing per-suite loop, immediately after each suite
   returns, rather than once after the whole loop — this attributes a leak
   to the exact suite that caused it (not just "whichever suite ran last,"
   which is only reliable on the fail-fast path) and stops the run at that
   suite rather than continuing. Fail the run (distinct exit code from a
   suite failure) with a message naming the offending suite and the
   leaked path(s). `rm -rf` the per-run `TMPDIR` unconditionally when the
   run ends (pass, suite failure, or leak failure), so a failed run
   doesn't itself leak.
3. **(Plan Review finding 3 — must-fix)** Add cases to
   `.agent/scripts/tests/test_run_script_tests.sh` (the runner's own
   suite, which drives `run_script_tests.sh` against a scratch copy of the
   tests directory via its `[tests-dir]` argument): a fixture suite that
   intentionally leaks into `TMPDIR` must make the runner fail with the
   leak message from step 2, and a clean fixture suite must still pass.
   Update the runner's `# Exit codes:` header comment (currently lines
   26–27) to document the new leak-failure exit code alongside the
   existing "a suite failed" / "test_checkpoint_269.sh missing" codes, and
   re-check the existing fail-fast case's exit-code assertion in
   `test_run_script_tests.sh` still matches after the new code is added.
   Derive the guard's per-run `TMPDIR` from `SCRIPT_DIR` context (i.e. it
   is always a location the guard itself controls under `/tmp`), not from
   the caller-supplied `[tests-dir]` argument — otherwise
   `test_run_script_tests.sh`'s nested runs would point the guard at the
   scratch tests-dir instead of a real per-run temp location.
4. Update `AGENTS.md`'s Script Reference table entry for
   `run_script_tests.sh` to mention the guard, per the Consequences Map
   entry ("A script in `.agent/scripts/` → Script reference table in
   `AGENTS.md`").
5. Document the one-time cleanup for the ~2,800 pre-existing
   `/tmp/tmp.*` directories as a comment near the new guard in
   `run_script_tests.sh` (discoverable next to the code that now prevents
   recurrence) plus in the PR description — not something the fix runs
   automatically, since a script silently deleting arbitrary `/tmp/tmp.*`
   entries on someone else's machine is exactly the kind of hidden
   automation the "human control and transparency" principle flags.
   Recommended command, scoped to dirs that are recognizably one of this
   repo's own sandboxes (contain a `.git` directory, i.e. came from a test
   that `git init`'d inside its sandbox) and old enough not to catch an
   in-flight run:
   ```bash
   find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +1 \
       -exec sh -c '[ -d "$1/.git" ] && rm -rf "$1"' _ {} \;
   ```
   **(Plan Review finding 8 — suggestion)** This filter only catches
   sandbox roots that were themselves `git init`'d. `test_adapter.sh` /
   `test_project_registry.sh`'s `make_sandbox()` roots and
   `test_dispatch_phase.sh`'s fixture dirs are plain directories (only
   nested fixture repos inside them are git repos), so this command will
   clear only part of the ~2,800 and leave the boot-stall symptom partly
   in place. Say so explicitly in the PR description and offer the owner a
   complementary selector to run at their judgement — e.g. a content-match
   variant (`-exec grep -qr '.agent/scripts/adapter' {} \;`-style, scoped
   to whatever these fixtures reliably contain) or a plain age-only
   variant (`find /tmp -maxdepth 1 -type d -name 'tmp.*' -mtime +7`) with
   no `.git` filter, left for a human to eyeball before running.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/tests/test_ros2_colcon.sh` | Single top-level `SANDBOX` + trap; per-test dirs via `mktemp -d -p "$SANDBOX"` |
| `.agent/scripts/tests/test_merge_pr.sh` | Same; fold `$bare` into `$SANDBOX` as a sibling |
| `.agent/scripts/tests/test_precommit_hook_path.sh` | Same; fold the already-correct `nogit` fixture into `$SANDBOX` too |
| `.agent/scripts/tests/test_project_registry.sh` | Same; fold `outside` sandboxes into `$SANDBOX` as siblings, not children |
| `.agent/scripts/tests/test_adapter.sh` | Same |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Same; fold `$outside` / `$bare` extra sandboxes into `$SANDBOX` as siblings |
| `.agent/scripts/tests/test_dispatch_phase.sh` | Same; fold existing `TMPD` into `$SANDBOX` |
| `.agent/scripts/tests/test_checkpoint_269.sh` | Add top-level `SANDBOX` + `EXIT` trap (currently has neither); `_sandbox_repo()` uses `mktemp -d -p "$SANDBOX"`; drop success-path `rm -rf` calls |
| `.agent/scripts/tests/test_block_bash_tool_mapping.sh` | Normalise absolute `/tmp/...` `mktemp` (line 22) to honor `TMPDIR` |
| `.agent/scripts/tests/test_cross_model_review.sh` | Same (line 19) |
| `.agent/scripts/tests/test_gh_create_pr.sh` | Same (line 27) |
| `.agent/scripts/tests/test_sync_gitbug.sh` | Same (line 28) |
| `.agent/scripts/tests/test_merge_pr_root_resolution.sh` | Normalise line 23; add trap coverage for line 122's `tmp`; keep line 122's outside-repo semantics (now safe once PR 2's `TMPDIR` is always outside a work tree) |
| `.agent/scripts/tests/run_script_tests.sh` (PR 2) | Per-run `TMPDIR` under `/tmp`, per-suite sweep with suite attribution, fail on leak, cleanup-command comment + caveat, exit-codes header updated |
| `.agent/scripts/tests/test_run_script_tests.sh` (PR 2) | Leak/no-leak fixture cases against the new guard; guard `TMPDIR` derived from `SCRIPT_DIR`, not `[tests-dir]` |
| `AGENTS.md` (PR 2) | Script Reference table entry for `run_script_tests.sh` notes the guard |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | The whole point of PR 2 — the per-suite fixes alone don't stop a future suite from reintroducing the bug; the guard does, and it now also covers absolute-template `mktemp` calls via PR 1's normalisation rather than being blind to them |
| A change includes its consequences | All eight affected suites are in scope (not just the three the issue named, and not just the original seven — `test_checkpoint_269.sh` added per Plan Review finding 5); `AGENTS.md`'s script table updated alongside the runner change |
| Only what's needed | No new sandbox abstraction/helper library introduced — each suite keeps its own inline `SANDBOX`/`trap`, matching the one file that already does this correctly rather than centralizing into shared code the issue didn't ask for |
| Improve incrementally | Two small, independently reviewable PRs instead of one large one; PR 1 changes no test behavior, PR 2 changes no suite content; PR 2 lands promptly after PR 1 to close the unguarded gap |
| Test what breaks | Verification step re-runs every suite under an empty `TMPDIR` and asserts it's empty afterward; PR 2 adds leak/no-leak cases to `test_run_script_tests.sh` so the enforcement layer itself is tested, not just the suites it protects |
| Human control and transparency | The historical `/tmp` cleanup is a documented, manually-run command with an explicit caveat about its partial coverage, not something either PR executes automatically |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 — progress.md entry-type vocabulary | Yes, for this plan's own persistence | This plan is recorded via `review_progress.sh persist` under `## Plan Authored`, per the canonical heading |
| ADR-0011 — Project-type adapter contract | No, but the issue's original text pointed at the wrong runner (`adapter test`) | Corrected per the Issue Review: the guard belongs in `run_script_tests.sh`, the actual runner behind `validate-script-tests`, not the project's `TEST_CMD` path |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| A script in `.agent/scripts/` (`run_script_tests.sh`) | Script reference table in `AGENTS.md` | Yes — PR 2 |
| Eight `test_*.sh` suites' internal sandbox helpers | Nothing external references these helper names (`make_sandbox`, `mk_ws`, `mk_sandbox`, `make_merge_sandbox`, `_sandbox_repo` are all file-local) | Yes — confirmed no cross-file references via the file reads above |
| `run_script_tests.sh`'s behavior (new per-run `TMPDIR` export, new leak-failure exit code) | `test_run_script_tests.sh`, the runner's own test suite | Yes — PR 2 adds leak/no-leak cases and updates the exit-codes header |
| `run_script_tests.sh`'s exit behavior (new failure mode on leak) | CI / pre-commit hook consumers of its exit code — no change needed; a leak is already supposed to be impossible, so the new failure mode only fires on a genuine regression | No further action needed |
| Five suites' hardcoded `/tmp/...` `mktemp` templates | The guard that will now export `TMPDIR` — those five calls would silently ignore it and leak past the sweep | Yes — PR 1 normalises them (one exception, `test_merge_pr_root_resolution.sh:122`, kept intentionally outside-repo per its own test) |

## Open Questions

None — the owner's checkpoint decision already resolved scope (all eight
suites, per the revised inventory), guard placement (`run_script_tests.sh`,
required not optional), and convention (the `test_worktree_enter_stderr.sh`
shape, now on `main`). The two-PR split, the per-run `TMPDIR` location
under `/tmp`, the per-suite sweep, the absolute-template normalisation, and
the non-automatic (and now caveated) cleanup command are this plan's own
design choices, flagged here for `review-plan` rather than as open
questions needing a decision before implementation starts.

## Estimated Scope

Two PRs. PR 1 (mechanical sandbox-convention conversion across eight test
files, plus normalising five absolute-`/tmp`-template `mktemp` sites) is
larger in diff size but lower risk — no test behavior changes. PR 2
(runner guard, its own test coverage in `test_run_script_tests.sh`, doc
update, and cleanup note) is small but is the actual enforcement mechanism
the issue asked for. Splitting avoids a window where the guard is live but
suites are still being converted, which would turn pre-commit red on
`main` between merges; PR 2 should land immediately after PR 1 merges,
since PR 1's manual per-suite `TMPDIR` check is the only protection against
a regression in the gap between them.

## Implementation Notes

- This plan was revised after a Plan Review verdict of `needs-work` (ten
  findings, five must-fix) and the owner's `revise` checkpoint decision.
  Before revising, `main` was merged into `feature/issue-297`
  (`git fetch && git merge origin/main`) to pick up #194 / PR #299, which
  landed `.agent/scripts/tests/test_worktree_enter_stderr.sh` — the
  reference shape this plan's PR 1 now cites directly from `main` instead
  of an unmerged branch.
- All five must-fix findings and all five suggestions from the Plan Review
  are folded into the Approach and Files to Change sections above rather
  than tracked separately; see the inline `(Plan Review finding N —
  must-fix/suggestion)` tags throughout.
