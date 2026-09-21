# Plan: script tests: mktemp sandboxes registered inside $() never get cleaned — ~100 leaked into /tmp per run, stalling boot 2 min

## Issue

https://github.com/rolker/agent_workspace/issues/297

## Context

Every `test_*.sh` suite under `.agent/scripts/tests/` that wants an isolated
sandbox builds one with `mktemp -d`. Seven of the ~23 suites register that
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
The owner's checkpoint decision (progress.md) directs widening the fix to
all seven suites, making the suite-level guard required (not optional), and
standardizing on the `test_worktree_enter_stderr.sh` shape from the
unmerged `feature/issue-194` branch: one `SANDBOX="$(mktemp -d)"` at top
level (never inside a `$()`), one `trap 'rm -rf "$SANDBOX"' EXIT`, with any
per-test isolation done as subdirectories under that single sandbox rather
than one `mktemp -d` per test.

Verified by reading each of the seven files directly (paths and line
references below are from the current `main` tree the worktree branched
from):

| Suite | Defect shape | Registration site(s) |
|---|---|---|
| `test_ros2_colcon.sh` | `make_sandbox()` (`SANDBOXES=()` + `trap cleanup EXIT` at top; `SANDBOXES+=("$sb")` inside the function) called as `sb="$(make_sandbox)"` — 7 call sites, plus `make_worktree_sandbox()` which itself calls `make_sandbox` inside `$()` | lines 71–82, 202–218 |
| `test_merge_pr.sh` | Same shape; `make_merge_sandbox()` also registers a second path (`$bare`, the local bare remote) inside the same swallowed subshell | lines 59–66, 158–184 |
| `test_precommit_hook_path.sh` | `mk_ws()` registers via `SANDBOXES+=("$sb")` inside the function, called as `sb="$(mk_ws)"`; a second bare `sb="$(mktemp -d)"` at top level for a no-git fixture is *not* leaking (line 69, direct assignment outside a function) but should still fold into the single-sandbox convention | lines 24–50, 69 |
| `test_project_registry.sh` | `make_sandbox()`, identical shape, called as `sb="$(make_sandbox)"` — 10+ call sites across registry, dispatcher, and worktree test groups | lines 50–70 |
| `test_adapter.sh` | `make_sandbox()`, identical shape, called as `sb="$(make_sandbox)"` throughout | lines 62–83 |
| `test_merge_pr_gate.sh` | `make_sandbox()` takes args, still swallows `SANDBOXES+=` inside `$()`; several call sites also do a second `SANDBOXES+=("$outside")` / `SANDBOXES+=("$bare")` directly in the test body (those direct appends *do* work, since they're not inside a `$()` — only the ones inside `make_sandbox()` itself leak) | lines 26–28, 135–167, plus per-test extra sandboxes (e.g. 679–692) |
| `test_dispatch_phase.sh` | `mk_sandbox()` (line 27–38) has no `SANDBOXES` array and no per-sandbox trap at all — only `TMPD` (a single scratch dir for fixture files) is trapped; every `mk_sandbox` call (`SB0`, `SBX`, `SB`, `SBP1`, `SBP2`, ~5 sandboxes per run) leaks unconditionally | lines 17–38, 121, 350, 394–420, 425 |

No additional suites with this shape were found beyond the seven above —
the remaining `test_*.sh` files either use no sandbox, or already assign
`mktemp -d` directly at top level outside any function/subshell (the
correct shape).

## Approach

Two PRs, in this order, so CI never sits red between them:

**PR 1 — convert all seven suites to the single-top-level-sandbox
convention.** Mechanical, per-file:

1. For each suite, replace the per-call `mktemp -d` + swallowed-registration
   helper with one `SANDBOX="$(mktemp -d)"` assigned directly at the top of
   the script (not inside any function or `$()`), and `trap 'rm -rf
   "$SANDBOX"' EXIT` immediately after, matching
   `test_worktree_enter_stderr.sh` on `feature/issue-194`
   (`.agent/scripts/tests/test_worktree_enter_stderr.sh`, read via `git show
   origin/feature/issue-194:...` since that branch isn't merged yet).
2. Every place that built a *fresh* sandbox per test (all seven suites call
   their helper once per `test_*` function, so tests don't interfere with
   each other via shared state) becomes a fresh subdirectory under
   `$SANDBOX` instead — e.g. `local sb="$SANDBOX/$test_name_or_counter"`. A
   monotonic counter or the calling test's function name is enough to keep
   subdirectories from colliding; nothing in these suites relies on the
   sandbox being literally `/tmp/tmp.XXXXXXXX` rather than a subdirectory of
   one.
3. `test_merge_pr.sh`'s extra `$bare` (local bare remote) and
   `test_merge_pr_gate.sh`'s extra `$outside` / `$bare` sandboxes become
   subdirectories of the same `$SANDBOX` too, dropping their separate
   `SANDBOXES+=` appends entirely (there is only one array to maintain
   after this change: none — cleanup is just `rm -rf "$SANDBOX"`).
4. `test_dispatch_phase.sh` gets the same treatment for `mk_sandbox()`
   (currently unregistered anywhere) and can fold its existing `TMPD`
   scratch dir into the same top-level `$SANDBOX` rather than keeping two
   separate trapped directories.
5. `test_precommit_hook_path.sh`'s already-correct top-level `nogit="$(mktemp
   -d)"` fixture (line 69) moves under `$SANDBOX` too, for one convention
   instead of two coexisting ones in the same file.
6. Verification per suite: run it directly with `TMPDIR` pointed at an
   empty scratch directory (`TMPDIR=$(mktemp -d) bash
   .agent/scripts/tests/test_X.sh; find "$TMPDIR" -mindepth 1`) and confirm
   the directory is empty afterward, in addition to the suite's own pass
   count staying unchanged.
7. No suite's test *logic* changes — assertions, fixtures, and stubs are
   untouched. This keeps the PR reviewable as "sandbox plumbing only."

**PR 2 — the enforcement layer + the one-time cleanup note**, once PR 1 has
landed and every suite is confirmed leak-free (so the new guard passes on
first run rather than immediately failing on suites PR 1 hasn't reached
yet):

1. Add a suite-level guard to `.agent/scripts/tests/run_script_tests.sh`
   (the runner wired into the `validate-script-tests` pre-commit hook — not
   `.agent/scripts/test.sh`/`adapter test`, which runs the *project's* own
   `TEST_CMD` and has nothing to do with this repo's script-test suite,
   per the Issue Review's ADR-0011 correction). Before the suite loop,
   create a per-run `TMPDIR` beneath `.agent/scratchpad/` (per the
   `AGENTS.md` scratchpad rule) and export it so every suite's `mktemp -d`
   calls land there instead of `/tmp`; after the loop (both the
   all-passed and the fail-fast-stop paths), sweep the directory:
   `find` for any remaining entries and fail the run (distinct exit code
   or a clear message) if the sweep finds anything, naming which suite ran
   last so a future regression is traceable to the suite that introduced
   it. `rm -rf` the per-run `TMPDIR` unconditionally afterward regardless
   of the sweep's verdict, so a failed run doesn't itself leak.
2. Update `AGENTS.md`'s Script Reference table entry for
   `run_script_tests.sh` to mention the guard, per the Consequences Map
   entry ("A script in `.agent/scripts/` → Script reference table in
   `AGENTS.md`").
3. Document the one-time cleanup for the ~2,800 pre-existing
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

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/tests/test_ros2_colcon.sh` | Single top-level `SANDBOX` + trap; per-test dirs as subdirs |
| `.agent/scripts/tests/test_merge_pr.sh` | Same; fold `$bare` into `$SANDBOX` |
| `.agent/scripts/tests/test_precommit_hook_path.sh` | Same; fold the already-correct `nogit` fixture into `$SANDBOX` too |
| `.agent/scripts/tests/test_project_registry.sh` | Same |
| `.agent/scripts/tests/test_adapter.sh` | Same |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Same; fold `$outside` / `$bare` extra sandboxes into `$SANDBOX` |
| `.agent/scripts/tests/test_dispatch_phase.sh` | Same; fold existing `TMPD` into `$SANDBOX` |
| `.agent/scripts/tests/run_script_tests.sh` (PR 2) | Per-run `TMPDIR` under `.agent/scratchpad/`, post-run sweep, fail if non-empty, cleanup-command comment |
| `AGENTS.md` (PR 2) | Script Reference table entry for `run_script_tests.sh` notes the guard |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | The whole point of PR 2 — the per-suite fixes alone don't stop an eighth suite from reintroducing the bug; the guard does |
| A change includes its consequences | All seven affected suites are in scope (not just the three the issue named); `AGENTS.md`'s script table updated alongside the runner change |
| Only what's needed | No new sandbox abstraction/helper library introduced — each suite keeps its own inline `SANDBOX`/`trap`, matching the one file that already does this correctly rather than centralizing into shared code the issue didn't ask for |
| Improve incrementally | Two small, independently reviewable PRs instead of one large one; PR 1 changes no test behavior, PR 2 changes no suite content |
| Test what breaks | Verification step re-runs every suite under an empty `TMPDIR` and asserts it's empty afterward — the actual regression this issue is about, not just "tests still pass" |
| Human control and transparency | The historical `/tmp` cleanup is a documented, manually-run command, not something either PR executes automatically |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 — progress.md entry-type vocabulary | Yes, for this plan's own persistence | This plan is recorded via `review_progress.sh persist` under `## Plan Authored`, per the canonical heading |
| ADR-0011 — Project-type adapter contract | No, but the issue's original text pointed at the wrong runner (`adapter test`) | Corrected per the Issue Review: the guard belongs in `run_script_tests.sh`, the actual runner behind `validate-script-tests`, not the project's `TEST_CMD` path |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| A script in `.agent/scripts/` (`run_script_tests.sh`) | Script reference table in `AGENTS.md` | Yes — PR 2 step 2 |
| Seven `test_*.sh` suites' internal sandbox helpers | Nothing external references these helper names (`make_sandbox`, `mk_ws`, `mk_sandbox`, `make_merge_sandbox` are all file-local) | Yes — confirmed no cross-file references via the file reads above |
| `run_script_tests.sh`'s exit behavior (new failure mode on leak) | CI / pre-commit hook consumers of its exit code — no change needed; a leak is already supposed to be impossible, so the new failure mode only fires on a genuine regression | No further action needed |

## Open Questions

None — the owner's checkpoint decision already resolved scope (all seven
suites), guard placement (`run_script_tests.sh`, required not optional),
and convention (the `feature/issue-194` shape). The two-PR split and the
non-automatic cleanup command are this plan's own design choices, flagged
here for `review-plan` rather than as open questions needing a decision
before implementation starts.

## Estimated Scope

Two PRs. PR 1 (mechanical sandbox-convention conversion across seven test
files) is larger in diff size but lower risk — no test behavior changes.
PR 2 (runner guard + doc update + cleanup note) is small but is the actual
enforcement mechanism the issue asked for. Splitting avoids a window where
the guard is live but suites are still being converted, which would turn
pre-commit red on `main` between merges.
