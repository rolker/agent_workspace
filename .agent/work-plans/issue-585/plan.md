# Plan: worktree_create/enter/list.sh share the ROOT-resolution bug (all four worktree scripts)

## Issue

https://github.com/rolker/agent_workspace/issues/585

## Context

`worktree_create.sh:35`, `worktree_enter.sh:25`, `worktree_list.sh:21` and `worktree_remove.sh:131` all
set `ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"`. Run as the copy inside a linked worktree (a
session whose `$WS_ROOT` fell back to `.`, or `merge_pr.sh` run from a worktree calling its own
`$SCRIPT_DIR/worktree_remove.sh`), `ROOT_DIR` is that worktree. Two failures follow, both shown in the
issue review: new worktrees are made under `<worktree>/worktrees/workspace/` (nested), and the registry
(`.agent/projects.local`, gitignored, so only in the main checkout) reads empty, so registered projects
are "not registered" or missing from the listing. `worktree_remove.sh` deletes, so it is the worst case.
The issue's talk of a fix already made to `worktree_remove.sh` and its `#508`/`#509` belong to the older
repository; here none of the four has the fix.

## Approach

1. **Helper `wt_main_root <script_dir> [<script name>]` in `.agent/scripts/_worktree_helpers.sh`** (that
   file already sources `_project_registry.sh`, so every caller has it). It never reads the cwd, never
   reads `~/.claude/agent-workspace-root` (design.md#sessions-and-roots: workspace scripts take their
   root from their location; so the user tier changes nothing), and does:
   - `own` = `cd -P "<script_dir>/../.."` (physical, so a `scripts/` symlink or a symlinked checkout does
     not skew it);
   - if `registry_main_checkout_fallback "$own"` is true (a linked worktree whose main checkout git does
     not name, e.g. a `--separate-git-dir` clone): refuse;
   - `root=$(registry_main_checkout "$own")`; it must be the top level of its own git checkout
     (`git -C "$root" rev-parse --show-toplevel` equals `$root`): else refuse (not a git checkout, or a
     plain directory inside another repository, which must not borrow that repository);
   - `$root/.agent/scripts/_worktree_helpers.sh` must exist: else refuse (the main checkout found is not
     a workspace checkout).
   - Success: prints the physical path of the main checkout, one line, return 0. Refusal: nothing on
     stdout, one `ERROR:` line on stderr naming the script, the directory and the reason, and, where
     known, what to do ("run it from the main checkout `<path>`"), return 1.
2. **Contract by case** (all printed paths physical):

   | Case | Result |
   |---|---|
   | Copy in the main checkout (git dir = common dir) | prints that checkout |
   | Copy in a linked worktree of the workspace (also one nested under `worktrees/`) | prints the main checkout |
   | Copy in a worktree of a project repository (not the workspace's) whose main checkout holds no `_worktree_helpers.sh` | refuses "not a workspace checkout" |
   | Copy in a project repository that itself carries `.agent/scripts` (marker present) | prints that project's own main checkout; it is a checkout git names and whose scripts these are, not a guess (see Open Questions) |
   | Script reached by an absolute path of the workspace while the cwd is in a project worktree (the user-tier call) | unaffected: only the script's location counts; prints the workspace main checkout |
   | With or without `~/.claude/agent-workspace-root`, or with it naming another directory | same output; the file is never read |
   | Not a git checkout, or a plain directory inside another repository | refuses |
   | Linked worktree whose main checkout git does not name | refuses |

3. **One line per script** (the `source` of `_worktree_helpers.sh` already comes first in each; where
   `ROOT_DIR=` precedes the `source` lines, move it below them):
   - `worktree_create.sh:35`, `worktree_list.sh:21`, `worktree_remove.sh:131`:
     `ROOT_DIR="$(wt_main_root "$SCRIPT_DIR" "<script>.sh")" || exit 1`
   - `worktree_enter.sh:25` (sourced, no `set -e`, must not kill the caller's shell): the same with
     `|| { return 1 2>/dev/null || exit 1; }`, the idiom already on its line 38 for the user-tier guard.
     `SCRIPT_DIR` there comes from `BASH_SOURCE[0]`, so sourcing works as before.
   - On a refusal each script has done nothing: the assignment is before any git, `gh`, `cd`, `rm` or
     registry call. `worktree_remove.sh` in particular exits 1 with the helper's message before parsing
     the registry, before `cd "$ROOT_DIR"` (line 343) and before every delete; it never falls back to the
     worktree's own root, and there is no flag that overrides it.
   - Correct the comment at `worktree_remove.sh:127-130` ("regardless of CWD ... consistent with all
     other worktree scripts") to say: the root is the main checkout of the workspace found from the
     script's location, so a copy inside a linked worktree still acts on the main checkout's worktrees
     and registry; the cwd plays no part.
   - `registry_require_root "$ROOT_DIR"` stays after it in the three scripts that have it; with
     `ROOT_DIR` the main checkout, a cwd inside `worktrees/workspace/...` is still accepted by prefix.
4. **Tests: new `.agent/scripts/tests/test_worktree_main_root.sh`** (`chmod +x`; sandbox only, `mktemp -d`
   with a trap, `HOME` set to a sandbox directory, fake `git` identity, no `gh` call: runs stop at the
   point the assertion needs, using the existing suites' sandbox shape from `test_worktree_remove.sh`
   `make_sandbox`). Fixture: a workspace repository with the real four scripts and their helper files
   committed (so a linked worktree holds copies), `.agent/projects.local` (untracked, only in the main
   checkout) registering one project that is a git repository with its own root, and a linked worktree
   `worktrees/workspace/issue-workspace-3`.
   - Helper cases: one per row of the table above, plus the user-tier decoy: a
     `$HOME/.claude/agent-workspace-root` naming another sandbox, present and absent, and the result
     identical.
   - Nested-worktree failure gone: run `worktree_create.sh --issue 9 --type workspace --print-path-only`
     (or the flags the existing create tests use to avoid `gh`) as the copy inside worktree 3, and assert
     the new directory is `<main>/worktrees/workspace/issue-workspace-9`, that
     `<worktree 3>/worktrees` does not exist, and that `git worktree list` from the main checkout lists
     it. Same for `worktree_enter.sh --print-path` for worktree 3 and for the project (path under the
     project's own base), and `worktree_remove.sh --issue 3`.
   - Empty-registry failure gone: from the same copy, `worktree_create.sh --type project --project <name>`
     makes the worktree under the registered project's base (before the fix: "not registered");
     `worktree_list.sh --json` from the copy contains the registered project's worktree (before the fix:
     absent); `worktree_enter.sh --type project --project <name> --print-path` and
     `worktree_remove.sh --type project --project <name> --issue 5` find and remove it.
   - Each script's refusal: for the `--separate-git-dir` linked worktree, a non-git directory and a plain
     directory inside another repository, each of the four exits non-zero with `ERROR:` on stderr and
     nothing on stdout; for remove, the worktree directory, its branch and the `git worktree list` entry
     are all still there afterwards, and a project worktree is untouched. For enter, run it as
     `bash -c 'source <copy> ...; echo survived rc=$?'` and assert the caller's shell survives with
     rc 1.
   - Red first: commit this suite before the fix and record that the nested-base, empty-registry and
     refusal cases fail against the four scripts as they are on `main`, then commit the fix and show the
     suite pass. The report names the suites run: the new suite, `test_worktree_create.sh`,
     `test_worktree_remove.sh`, `test_worktree_enter_stderr.sh`, `test_project_registry.sh`,
     `test_user_tier_guard.sh`; the full pass is the host's, once (`run_script_tests.sh -j 4`).
5. **Documentation, same change.** `.agent/knowledge/script_reference.md`: one clause on each of the four
   rows (the root is the main checkout found from the script's location, also as a copy in a linked
   worktree; refuses with exit 1 when it cannot be found) and the helper named once. `.agent/WORKTREE_GUIDE.md`:
   one sentence where it says the scripts are called from anywhere. `docs/design.md#sessions-and-roots`:
   the sentence "Workspace scripts do not read the file; they resolve their own root from their location"
   gets "(the main checkout, when the copy is in a linked worktree: `wt_main_root`)".
6. **Follow-ups listed, not fixed** (open as one issue after merge, with this list; none touched here):
   scripts with the same `dirname`/`../..` root line: `lock.sh`, `unlock.sh`, `dashboard.sh:28` (it calls
   `worktree_list.sh` by its own `SCRIPT_DIR`, which now works from a copy), `discover_governance.sh`,
   `git_bug_setup.sh`, `fetch_pr_reviews.sh`, `pr_status.sh`, `project_setting.sh`,
   `project_integration_audit.sh`, `registration_verify.sh`, `capture.sh`, `generate_make_skills.sh`,
   `update_roadmap.sh`, `gh_create_pr.sh`, `gh_create_issue.sh` (some only locate their own files, or are
   meant to run in the main checkout, as `register_project.sh` is; each needs its own call). A second
   implementation of the same rule, `git worktree list | head -n1`, sits in `merge_pr.sh:236`,
   `dispatch_phase.sh:159` and `session_root.sh:73` (no checks of its own: wrong in a project worktree
   copy); folding those into `wt_main_root` is a follow-up. The Makefile case stays issue 239.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_worktree_helpers.sh` | add `wt_main_root` |
| `.agent/scripts/worktree_create.sh` | line 35 |
| `.agent/scripts/worktree_enter.sh` | line 25 (sourced idiom) |
| `.agent/scripts/worktree_list.sh` | line 21 |
| `.agent/scripts/worktree_remove.sh` | line 131 and the comment at 127-130 |
| `.agent/scripts/tests/test_worktree_main_root.sh` | new suite, `chmod +x` |
| `.agent/knowledge/script_reference.md`, `.agent/WORKTREE_GUIDE.md`, `docs/design.md` | the clauses in step 5 |

## Prior Art

`registry_main_checkout` and `registry_main_checkout_fallback` (`_project_registry.sh`) are the rule for
"main checkout of this checkout", already used by the dashboard, `discover_governance.sh`,
`_bookkeeping.sh`, `update_roadmap.sh` and others: taken whole, so the fallback and the
separate-git-dir case are decided in one place. `merge_pr.sh`, `dispatch_phase.sh` and `session_root.sh`
use `git worktree list | head -n1` with no checks: rejected, since in a project worktree copy it returns
the project's checkout and in a damaged case an empty or wrong path. `~/.claude/agent-workspace-root`
rejected as the source: ADR-0016 and design.md say workspace scripts do not read it, and it may be absent.

## Serves

Easy to use: `docs/design.md#worktrees`.

## Design Picture

No change to how the parts fit. `docs/design.md#worktrees` already says work happens in a worktree and the
scripts are called from anywhere; the one sentence in `docs/design.md#sessions-and-roots` about where the
root comes from is made exact (step 5).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Fix completely (Quality Standard) | all four scripts, one helper, tests that fail before the fix, the misleading comment corrected |
| Never act on a guess | every refusal case ends before any delete or `git` write; remove has no override |
| Only what's needed | other scripts with the line are listed, not changed; no new ADR, no new file beyond the helper and the suite |
| Verify before claiming | the line numbers were re-read in this repository; the red-first commit shows the failures |
| Workspace project-agnostic | the helper and the tests name no project; the registered project in the fixture is synthetic |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0002 (worktree isolation) | Yes | the scripts keep its layout when run from a worktree |
| ADR-0016 (user tier) | Yes | the helper reads no user-tier file; the guard `registry_require_root` still follows; tested with and without the file |
| ADR-0013 (records) | Yes | this plan and the later entries go through `progress_append.sh` |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| root rule of the four scripts | `script_reference.md`, `WORKTREE_GUIDE.md`, `design.md#sessions-and-roots` | Yes (step 5) |
| `worktree_remove.sh` called by `merge_pr.sh` (lines 2411, 2511, 2523, passing no root) and `dashboard.sh` calling `worktree_list.sh` | nothing: they pass no root and assume only the script's own `SCRIPT_DIR`; after the fix a copy of `merge_pr.sh` in a worktree removes the right tree | Yes, checked; covered by the remove cases |
| `worktree_enter.sh` hint lines 461-463 print `$ROOT_DIR/.agent/scripts/worktree_remove.sh` | now the main checkout's script, which is the one to run | Yes (no edit) |
| `/start-task` and `run-issue` call `$WS_ROOT/.agent/scripts/...` | nothing | Yes, checked |
| the other scripts with the root line | one follow-up issue | No, follow-up |

## Open Questions

- A project repository that carries its own copy of `.agent/scripts` passes the marker check and gets its
  own main checkout as root. Accepted as what git says and the scripts' own location; a stricter marker
  needs a workspace-only file, and none is named in the issue. Veto if the owner wants a refusal.

## Estimated Scope

Single PR, about 30 lines of script change and one new suite.
