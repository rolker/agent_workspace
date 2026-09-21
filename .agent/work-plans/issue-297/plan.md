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

A second file already uses the target convention and is worth reading
alongside `test_worktree_enter_stderr.sh` (lines 22–23):
`test_resolve_work_plans_dir.sh` lines 174–184 — an eager top-level
`TMP_ROOT=$(mktemp -d)` (177) with `trap 'rm -rf "$TMP_ROOT"' EXIT` (184)
and a helper `make_temp_repo()` (178–183) that builds `${TMP_ROOT}/$base`
subdirectories, carrying an explicit comment (174–176) about why the
helper cannot register from inside `$(...)`. That is exactly the helper
shape PR 1 wants, already argued for in-tree.

Verified by reading each of the eight files directly and confirmed by the
measured leak table below (paths and line references are from the current
`main` tree, after merging `main` into this branch — see Implementation
Notes):

| Suite | Defect shape | Registration site(s) |
|---|---|---|
| `test_ros2_colcon.sh` | `make_sandbox()` (71–82): `sb="$(mktemp -d)"` (73) + `SANDBOXES+=("$sb")` (74), called as `sb="$(make_sandbox)"` at ~20 sites, plus `make_worktree_sandbox()` (202–218) which itself calls `make_sandbox` inside `$()` (204). Array + `trap cleanup EXIT` at 61–68 | 61–68, 71–82, 202–218 |
| `test_merge_pr.sh` | `make_merge_sandbox()` (158–184): `sb="$(mktemp -d)"` (160) + `SANDBOXES+=("$sb")` (161), and a second append for the string-derived bare remote `bare="${sb}.remote.git"` (176) at 178 — both swallowed, since every call site is `sb="$(make_merge_sandbox)"`. Three appends in test *bodies* — `SANDBOXES+=("$bare")` at 652 (`${sb}.project.remote.git`, 651) and 687 (`${sb}.farrepo.remote.git`, 686), and `SANDBOXES+=("$outside")` at 682 for `outside="$(mktemp -d)"` (681) — **do** work, because those functions (`test_legacy_single_repo_project_pr_regression` 644, `test_registered_project_root_pr_regression` 677) are invoked as plain commands (750, 751), not inside `$()`. Array + trap at 59–66 | 59–66, 158–184; working appends at 652, 682, 687 |
| `test_precommit_hook_path.sh` | `mk_ws()` (28–50): `sb="$(mktemp -d)"; SANDBOXES+=("$sb")` (30) swallowed at all three call sites (58, 120, 135). The `nogit="$(mktemp -d)"; SANDBOXES+=("$nogit")` at 69 is top-level and *does* register (measured: 3 leaks, one per `mk_ws` call, none for `nogit`), but should still fold into the single-sandbox convention. Array + trap at 24–26 | 24–26, 28–50, 69 |
| `test_project_registry.sh` | `make_sandbox()` (59–70): `sb="$(mktemp -d)"` (61) + `SANDBOXES+=("$sb")` (62), swallowed at every `sb="$(make_sandbox)"` call site. Five `outside="$(mktemp -d)"` + `SANDBOXES+=("$outside")` pairs in test bodies (726/727, 989/990, 1086/1087, 1113/1114, 1165/1166) **do** register, since those test functions are called as plain commands. Array + trap at 50–57 | 50–57, 59–70; working appends at 727, 990, 1087, 1114, 1166 |
| `test_adapter.sh` | `make_sandbox()` (72–83): `sb="$(mktemp -d)"` (75) + `SANDBOXES+=("$sb")` (76), swallowed at every call site. Array + trap at 62–69 | 62–69, 72–83 |
| `test_merge_pr_gate.sh` | `SANDBOXES+=` appears **exactly twice in the whole file**, at 137 and 146, and both are inside `make_sandbox()` (136–167), so both are swallowed: `sb="$(mktemp -d)"; SANDBOXES+=("$sb")` (137) and `bare="${sb}.remote.git"; git init --bare …; SANDBOXES+=("$bare")` (146). There is **no `$outside` variable in this file**, and lines 679–692 create no sandboxes. `bare` is a string-derived sibling of `$sb`, and its path string is the `gh` fixture *filename key* (`pr_view_<path with / → _>_${PR}.json`) at 165, re-derived as `remote="${sb}.remote.git"` at 216 and 236 (`make_ci_sandbox()`) and keyed again at 241 — it leaks today exactly like `$sb` (measured: `.remote.git` entries dominate this suite's 112 leaked directories). Array + trap at 26–28 | 26–28, 136–167 |
| `test_dispatch_phase.sh` | `mk_sandbox()` (27–38, `sb="$(mktemp -d)"` at 29) has no `SANDBOXES` array and no per-sandbox trap — only `TMPD="$(mktemp -d)"` (17), a single scratch dir for fixture files, is trapped (18). Three `mk_sandbox` call sites: `SB0` (121), `SB` (350), `SBX` (424). **`SBP1` (394) and `SBP2` (410) are direct top-level `"$(mktemp -d)"` assignments, not `mk_sandbox` calls** — same fix, different site. Five sandboxes leak per run (measured: 5) | 17–18, 27–38, 121, 350, 394, 410, 424 |
| `test_checkpoint_269.sh` | `_sandbox_repo()` (139–145) does `dir=$(mktemp -d)` (141) and echoes it, called as `REPO=$(_sandbox_repo)` (161, 273) and `ORIGIN=$(_sandbox_repo)` (238) — **no `SANDBOXES` array and no `EXIT` trap anywhere in the file** (`set -u` only, 34). Two further **top-level** sandboxes exist that earlier revisions missed: `SHALLOW=$(mktemp -d)` (244) and `NOREMOTE=$(mktemp -d)` (261). Cleanup is explicit `rm -rf` on the success path only — `rm -rf "$REPO"` (201), `rm -rf "$ORIGIN" "$SHALLOW" "$NOREMOTE"` (269), `rm -rf "$REPO"` (288) — so a clean pass leaks nothing (measured: 0) but any abort or early exit leaks everything live at that point. This is the one suite `run_script_tests.sh` hard-requires by name, so it belongs in the conversion set rather than staying an exception. | 34, 139–145, 161, 201, 238, 244, 261, 269, 273, 288 |

Plan Review (finding 5) also caught that this plan's earlier draft claimed
"no additional suites with this shape were found beyond the seven above" —
that was wrong; `test_checkpoint_269.sh` is the eighth, added above. All
eight suites above are the full inventory of the `$()`-swallowed-array /
untrapped-helper shape; every other `test_*.sh` file either uses no
sandbox or already assigns `mktemp -d` directly at top level outside any
function/subshell.

Separately, five suites call `mktemp` with an **absolute `/tmp/...`
template**, which ignores `TMPDIR` entirely and so would be invisible to
the PR 2 guard even after conversion (Plan Review round-1 finding 4,
round-2 finding 1). Full per-site inventory:

| Suite | Absolute-template sites | Cleanup today |
|---|---|---|
| `test_block_bash_tool_mapping.sh` | 22 (`TMP_HOME=$(mktemp -d /tmp/tool-mapping-test-XXXXXX)`) | `trap 'rm -rf "$TMP_HOME"' EXIT` (23) |
| `test_cross_model_review.sh` | 19 (`TMPDIR_BASE=$(mktemp -d /tmp/test_cmr.XXXXXX)`, inside `setup`) | `trap teardown EXIT` (57) |
| `test_sync_gitbug.sh` | 28 (`TMPDIR_BASE=$(mktemp -d /tmp/test_sync_gitbug.XXXXXX)`, inside `setup`) | `trap teardown EXIT` (51) |
| `test_merge_pr_root_resolution.sh` | 23 (`TMPDIR_BASE=$(mktemp -d /tmp/test_mpr.XXXXXX)`, inside `setup_main_and_worktree`); 122 (`tmp=$(mktemp -d /tmp/test_mpr_norepo.XXXXXX)`, inside `test_resolution_outside_repo`) | 23 → `trap teardown EXIT` (48); **122 → only the inline `rm -rf "$tmp"` at 126**, which the trap never sees (`teardown` only knows `TMPDIR_BASE`) |
| `test_gh_create_pr.sh` | **Six sites**: 27 (`SHIM_DIR=$(mktemp -d /tmp/gh_create_pr_shim-XXXXXX)`); 140, 157, 207, 239 (`TMPF=$(mktemp /tmp/test_body.XXXXXX.md)`); 350 (`TMPF_MX=$(mktemp /tmp/test_body.XXXXXX.md)`) | 27 → `trap 'rm -rf "$SHIM_DIR"' EXIT` (31); the five `TMPF`/`TMPF_MX` files → inline `rm -f` on the success path only (153, 176, 217, 253, 358) |

None of these five leak on a clean pass (see the measured table below) —
but every one of them writes outside `TMPDIR`, so PR 2's sweep would never
see them, and the five inline-`rm -f` files in `test_gh_create_pr.sh`
survive any abort. `test_merge_pr_root_resolution.sh:122` is also the case
whose `outside-any-repo` semantics is why PR 2 step 1 rules out
`.agent/scratchpad/` for the per-run `TMPDIR`.

### Measured leak table

Each suite was run individually from a clean tree with `TMPDIR`, `TMP` and
`TEMP` all pointed at a fresh empty directory, and the entries remaining in
that directory counted afterwards; `/tmp`'s top level was diffed around
each run separately to catch absolute-template writes. All 23 suites exited
0, so these are clean-pass leaks, not failure-path leaks.

| Suite | Entries left in `$TMPDIR` | New `/tmp` entries |
|---|---|---|
| `test_merge_pr_gate.sh` | 112 (`tmp.*` sandboxes **and** their `tmp.*.remote.git` siblings) | 0 |
| `test_project_registry.sh` | 56 | 0 |
| `test_ros2_colcon.sh` | 55 | 0 |
| `test_adapter.sh` | 47 | 0 |
| `test_merge_pr.sh` | 42 (sandboxes + `.remote.git` / `.project.remote.git` / `.farrepo.remote.git` siblings) | 0 |
| `test_dispatch_phase.sh` | 5 (`SB0`, `SB`, `SBX`, `SBP1`, `SBP2`) | 0 |
| `test_precommit_hook_path.sh` | 3 (one per `mk_ws` call; the top-level `nogit` at 69 is cleaned) | 0 |
| the other 16 suites | 0 | 0 |
| **total** | **320 per full run** | **0** |

Two things this measurement settles that reading alone could not: (a) the
per-run leak is ~320 directories, not ~100 — the issue's estimate was low,
and `test_merge_pr_gate.sh` alone accounts for a third of it because each
sandbox leaks together with its `.remote.git` sibling; (b) the five
absolute-template suites and `test_checkpoint_269.sh` leak *nothing* on a
clean pass, which confirms they are in scope for correctness (abort paths,
guard visibility) rather than for the boot-stall symptom.

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
3. Every extra sandbox drops its separate `SANDBOXES+=` append — after
   this change there is no array to maintain at all; cleanup is just
   `rm -rf "$SANDBOX"`. Two distinct shapes, each with its own rule:

   a. **String-derived siblings — leave the derivation alone.** The bare
      remotes are not separate `mktemp` calls: `test_merge_pr_gate.sh:146`
      (`bare="${sb}.remote.git"`, re-derived at 216/236) and
      `test_merge_pr.sh:176` (`${sb}.remote.git`), `:651`
      (`${sb}.project.remote.git`), `:686` (`${sb}.farrepo.remote.git`).
      Once `sb` is `mktemp -d -p "$SANDBOX"`, these land under `$SANDBOX`
      automatically and need no further handling. **(Plan Review round-2
      finding 4 — suggestion)** The rule for the implementer: *keep `bare`
      derived from `$sb` by string append; never give it its own
      `mktemp`.* The `gh` stub's fixture filenames are computed from that
      exact path string (`test_merge_pr_gate.sh:165`, `:241`;
      `test_merge_pr.sh`'s equivalents), so changing the path shape
      silently breaks fixture lookup.

   b. **Real `mktemp -d` "outside" sandboxes — make them siblings, not
      children.** **(Plan Review round-1 finding 9 — suggestion)** These
      exist specifically to sit *outside* the per-test sandbox root:
      `test_project_registry.sh` (726, 989, 1086, 1113, 1165) and
      `test_merge_pr.sh` (681). Note these appends currently *work* (their
      test functions are called as plain commands, not inside `$()`), so
      this is a convention change, not a leak fix. When folding them under
      `$SANDBOX`, make them siblings of the per-test subdirectory
      (`$SANDBOX/outside-<x>`, sibling of `$SANDBOX/<x>`), never children
      of the per-test `$sb`, so "outside the sandbox workspace root" still
      holds relative to what the test under it treats as its root.
      `test_merge_pr_gate.sh` has **no** `$outside` variable — nothing of
      this shape to fold there.
4. `test_dispatch_phase.sh` gets the same treatment for `mk_sandbox()`
   (line 29, currently unregistered anywhere) and can fold its existing
   `TMPD` scratch dir (17–18) into the same top-level `$SANDBOX` rather
   than keeping two separate trapped directories. **(Plan Review round-2
   finding 5 — suggestion)** Converting the helper is not enough:
   `SBP1` (394) and `SBP2` (410) are **direct top-level
   `"$(mktemp -d)"` assignments, not `mk_sandbox` calls**, and must be
   converted to `mktemp -d -p "$SANDBOX"` in the same edit.
5. `test_precommit_hook_path.sh`'s already-correct top-level `nogit="$(mktemp
   -d)"` fixture (line 69) moves under `$SANDBOX` too, for one convention
   instead of two coexisting ones in the same file.
6. **(Plan Review round-1 finding 5, round-2 finding 2 — must-fix)**
   `test_checkpoint_269.sh` gets the same conversion, and it has **three**
   `mktemp -d` sites, not one:
   - `_sandbox_repo()`'s `dir=$(mktemp -d)` (141) → `mktemp -d -p "$SANDBOX"`;
   - `SHALLOW=$(mktemp -d)` (244) → `mktemp -d -p "$SANDBOX"`;
   - `NOREMOTE=$(mktemp -d)` (261) → `mktemp -d -p "$SANDBOX"`.

   A top-level `SANDBOX` + `EXIT` trap is added (the file currently has
   neither — `set -u` at 34 is all there is). Only *after* all three are
   routed under `$SANDBOX` are the explicit success-path `rm -rf` calls
   dropped in favour of the trap: `rm -rf "$REPO"` (201),
   `rm -rf "$ORIGIN" "$SHALLOW" "$NOREMOTE"` (269), `rm -rf "$REPO"` (288).
   Order matters — dropping 269 while converting only `_sandbox_repo()`
   would remove `SHALLOW`'s and `NOREMOTE`'s *only* cleanup and turn a
   clean-pass-safe suite (measured: 0 leaks today) into an unconditional
   two-directory leak on every run. The file is the one suite
   `run_script_tests.sh` hard-requires by name, so it is no longer
   excluded from the conversion set.
7. **(Plan Review round-1 finding 4, round-2 finding 1 — must-fix)**
   Normalise **all ten** absolute `/tmp/...` `mktemp` sites across the five
   suites (they ignore `TMPDIR` and so stay invisible to the PR 2 guard
   even after this conversion). Drop the hardcoded `/tmp/` prefix so
   `mktemp` honors `TMPDIR`, folding each into that suite's own top-level
   `$SANDBOX` per steps 1–2:
   - `test_block_bash_tool_mapping.sh:22` (`TMP_HOME`) — its existing
     `trap` (23) becomes the `$SANDBOX` trap.
   - `test_cross_model_review.sh:19` (`TMPDIR_BASE`) — keep `teardown` /
     `trap` (57); the dir moves under `$SANDBOX`.
   - `test_sync_gitbug.sh:28` (`TMPDIR_BASE`) — same, trap at 51.
   - `test_gh_create_pr.sh` — **six sites, not one**: 27
     (`SHIM_DIR`), 140, 157, 207, 239 (`TMPF=$(mktemp /tmp/test_body.XXXXXX.md)`)
     and 350 (`TMPF_MX`). All six become `mktemp [-d] -p "$SANDBOX"`
     (the `.md` cases as `mktemp "$SANDBOX/test_body.XXXXXX.md"`), and the
     file's single `trap 'rm -rf "$SHIM_DIR"' EXIT` (31) becomes
     `trap 'rm -rf "$SANDBOX"' EXIT` with `SHIM_DIR` a subdirectory of it.
     **Disposition of the inline `rm -f` calls (153, 176, 217, 253, 358):
     drop all five.** They only fire on the success path — the abort path
     they leave uncovered is precisely what the trap now handles — and each
     `TMPF` gets a fresh unique name, so nothing depends on the file being
     gone before the next case. Keeping them would duplicate cleanup while
     adding no abort-time protection; the one convention per file is the
     trap.
   - `test_merge_pr_root_resolution.sh` — see below; two sites (23, 122).

   `test_merge_pr_root_resolution.sh` is the one exception:
   its line 23 fixture normalises the same way, but line 122
   (`test_resolution_outside_repo`) hardcodes `/tmp` *on purpose* to
   guarantee the probe sits outside any git work tree — per finding 2
   below, `TMPDIR` itself will now always be outside a work tree too, so
   this one can switch to `mktemp -d` (honoring `TMPDIR`) once that holds;
   line 122's `tmp` is also outside the `teardown` EXIT trap (48) today —
   its only cleanup is the inline `rm -rf "$tmp"` at 126, success-path only
   (Plan Review round-1 finding 5, smaller instance) — and it picks up trap
   coverage via `$SANDBOX` in this same edit.
8. Verification per suite: run it directly with `TMPDIR` pointed at an
   empty scratch directory under `/tmp` (`TMPDIR=$(mktemp -d) bash
   .agent/scripts/tests/test_X.sh; find "$TMPDIR" -mindepth 1`) and confirm
   the directory is empty afterward, in addition to the suite's own pass
   count staying unchanged. The measured leak table above is the baseline
   these runs are compared against: every non-zero row must go to 0, and no
   currently-zero row may become non-zero (the `test_checkpoint_269.sh`
   regression risk in step 6).
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
   **(Plan Review round-2 finding 7 — suggestion)** The guard's per-run
   directory comes from `mktemp -d /tmp/run-script-tests.XXXXXX` and is
   **never derived from the caller-supplied `[tests-dir]` argument**
   (`TESTS_DIR="${1:-$SCRIPT_DIR}"`, line 59 of the runner) — otherwise
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
| `.agent/scripts/tests/test_ros2_colcon.sh` | Single top-level `SANDBOX` + trap (replacing 61–68); `make_sandbox()`'s `mktemp -d` (73) → `mktemp -d -p "$SANDBOX"`, drop the append at 74; `make_worktree_sandbox()` (202–218) needs no change beyond its `make_sandbox` call |
| `.agent/scripts/tests/test_merge_pr.sh` | Same (replacing 59–66); `make_merge_sandbox()`'s `mktemp -d` (160) → `-p "$SANDBOX"`, drop appends at 161/178; keep `bare` string-derived (176, 651, 686 — fixture keys depend on the path string), drop appends at 652/687; `outside="$(mktemp -d)"` (681) → `mktemp -d -p "$SANDBOX"` as a *sibling* of `$sb`, drop append at 682 |
| `.agent/scripts/tests/test_precommit_hook_path.sh` | Same (replacing 24–26); `mk_ws()`'s `mktemp -d` (30) → `-p "$SANDBOX"`; fold the already-correct top-level `nogit` fixture (69) into `$SANDBOX` too |
| `.agent/scripts/tests/test_project_registry.sh` | Same (replacing 50–57); `make_sandbox()`'s `mktemp -d` (61) → `-p "$SANDBOX"`, drop append at 62; the five `outside="$(mktemp -d)"` sites (726, 989, 1086, 1113, 1165) become `$SANDBOX` **siblings** of the per-test dir, dropping their (currently working) appends at 727, 990, 1087, 1114, 1166 |
| `.agent/scripts/tests/test_adapter.sh` | Same (replacing 62–69); `make_sandbox()`'s `mktemp -d` (75) → `-p "$SANDBOX"`, drop append at 76 |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Same (replacing 26–28); `make_sandbox()` (136–167) is the **only** site: `mktemp -d` (137) → `-p "$SANDBOX"`, drop the appends at 137 and 146. Keep `bare="${sb}.remote.git"` (146) as a string-derived sibling — it is the `gh` fixture filename key at 165, re-derived at 216/236 and keyed at 241. No `$outside` in this file; no sandboxes at 679–692 |
| `.agent/scripts/tests/test_dispatch_phase.sh` | Same; `mk_sandbox()`'s `mktemp -d` (29) → `-p "$SANDBOX"`; fold existing `TMPD` (17–18) into `$SANDBOX`; **also convert the direct top-level `SBP1` (394) and `SBP2` (410) `mktemp -d` calls** — they are not `mk_sandbox` calls |
| `.agent/scripts/tests/test_checkpoint_269.sh` | Add top-level `SANDBOX` + `EXIT` trap (file currently has neither); route **all three** `mktemp -d` sites through `-p "$SANDBOX"` — `_sandbox_repo()` (141), `SHALLOW` (244), `NOREMOTE` (261) — *then* drop the success-path `rm -rf` calls at 201, 269, 288 |
| `.agent/scripts/tests/test_block_bash_tool_mapping.sh` | Normalise absolute `/tmp/...` `mktemp` (22) to honor `TMPDIR`; existing trap (23) becomes the `$SANDBOX` trap |
| `.agent/scripts/tests/test_cross_model_review.sh` | Same (19; trap/teardown at 57 retained) |
| `.agent/scripts/tests/test_gh_create_pr.sh` | Normalise **all six** absolute `/tmp` templates — 27 (`SHIM_DIR`), 140, 157, 207, 239 (`TMPF`), 350 (`TMPF_MX`); single `$SANDBOX` trap replaces the `SHIM_DIR` trap (31); drop the five inline `rm -f` calls (153, 176, 217, 253, 358) in favour of the trap |
| `.agent/scripts/tests/test_sync_gitbug.sh` | Same as `test_cross_model_review.sh` (28; trap/teardown at 51) |
| `.agent/scripts/tests/test_merge_pr_root_resolution.sh` | Normalise 23; normalise 122 and give its `tmp` trap coverage (today only the inline `rm -rf` at 126, outside `teardown`'s trap at 48); keep 122's outside-repo semantics (safe once PR 2's `TMPDIR` is always outside a work tree) |
| `.agent/scripts/tests/run_script_tests.sh` (PR 2) | Per-run `TMPDIR` under `/tmp`, per-suite sweep with suite attribution, fail on leak, cleanup-command comment + caveat, exit-codes header (26–27) updated |
| `.agent/scripts/tests/test_run_script_tests.sh` (PR 2) | Leak/no-leak fixture cases against the new guard; guard's per-run dir always from `mktemp -d /tmp/run-script-tests.XXXXXX`, never from the caller-supplied `[tests-dir]` (runner line 59) |
| `AGENTS.md` (PR 2) | Script Reference table entry for `run_script_tests.sh` notes the guard |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | The whole point of PR 2 — the per-suite fixes alone don't stop a future suite from reintroducing the bug; the guard does, and it now also covers absolute-template `mktemp` calls via PR 1's normalisation rather than being blind to them |
| A change includes its consequences | All eight affected suites are in scope (not just the three the issue named, and not just the original seven — `test_checkpoint_269.sh` added per Plan Review finding 5); `AGENTS.md`'s script table updated alongside the runner change |
| Only what's needed | No new sandbox abstraction/helper library introduced — each suite keeps its own inline `SANDBOX`/`trap`, matching the one file that already does this correctly rather than centralizing into shared code the issue didn't ask for |
| Improve incrementally | Two small, independently reviewable PRs instead of one large one; PR 1 changes no test behavior, PR 2 changes no suite content; PR 2 lands promptly after PR 1 to close the unguarded gap |
| Test what breaks | The pre-change leak table was measured per suite, so the verification step has a numeric baseline to compare against rather than a claim; it re-runs every suite under an empty `TMPDIR` and asserts it's empty afterward; PR 2 adds leak/no-leak cases to `test_run_script_tests.sh` so the enforcement layer itself is tested, not just the suites it protects |
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
| Ten hardcoded `/tmp/...` `mktemp` sites across five suites | The guard that will now export `TMPDIR` — those calls silently ignore it and stay invisible to the sweep | Yes — PR 1 normalises all ten (`test_merge_pr_root_resolution.sh:122` keeps its outside-repo semantics, which hold once `TMPDIR` is itself outside any work tree) |

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
- All five must-fix findings and all five suggestions from the round-1
  Plan Review are folded into the Approach and Files to Change sections
  above rather than tracked separately; see the inline `(Plan Review
  finding N — must-fix/suggestion)` tags throughout.
- **Revision 2** (after the round-2 Plan Review's `needs-work` verdict and
  the owner's second `revise` checkpoint) folds in all seven round-2
  findings. Every line number and variable name in the Context,
  Approach, and Files to Change sections was re-verified by opening each
  file; corrections made: `test_gh_create_pr.sh` has six absolute-template
  sites (not one), `test_checkpoint_269.sh` has three `mktemp -d` sites
  (not one), and the `test_merge_pr_gate.sh` rows previously described
  code from `test_merge_pr.sh` (no `$outside`, no sandboxes at 679–692).
- The leak table in Context is **measured, not read**: each suite was run
  in isolation with `TMPDIR`/`TMP`/`TEMP` redirected to a fresh empty
  directory and the leftovers counted, with `/tmp`'s top level diffed
  around each run. This is what round-1 and round-2 reviews could only
  infer from source. It also corrected the issue's own "~100 per run"
  estimate to ~320.
