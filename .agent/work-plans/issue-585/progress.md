---
issue: 585
---

# Issue #585 — worktree_create/enter/list.sh share the ROOT-resolution bug

## Issue Review
**Status**: complete
**When**: 2026-11-24 13:20 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #585

### Scope Assessment

**Well-scoped?** Yes, once its text is brought up to date. The defect is real and the same one line sits in all four scripts. As written the issue still describes the fork (it speaks of a "correction to worktree_remove.sh" that does not exist here), and it does not say what the fix should be.
**Right repo?** Yes. Workspace plumbing (`.agent/scripts/`).
**Serves**: Easy to use — `docs/design.md#worktrees`
**Design picture?** No change. `docs/design.md#worktrees` already says work happens in a worktree and the scripts are called from anywhere; the fix makes the scripts do that. No design update needed.
**Dependencies**: none identified. Separate from #239 here (the Makefile root detection), which is open and covers only the Makefile; the same root rule could be shared, but neither blocks the other.

What was checked (all four scripts, read in this worktree):

| Script | How it decides the root | What goes wrong when run as a copy inside a feature worktree |
|---|---|---|
| `worktree_create.sh:35` | `ROOT_DIR=$(dirname $(dirname $SCRIPT_DIR))` | `ROOT_DIR` is the worktree. New worktrees go to `<worktree>/worktrees/workspace/...` (line 55 `wt_workspace_base` = `$1/worktrees/workspace`), nested inside the feature worktree; `registry_*` lookups (project type, `--project`) read `<worktree>/.agent/projects.local`, which does not exist (it is gitignored, so only the main checkout has it); workflows, remote URL and branch cleanup (`git -C "$ROOT_DIR"`) act on the worktree. |
| `worktree_enter.sh:25` | same line | same: base dir nested, registry empty, `issue_lookup --root`, the printed `worktree_remove.sh` path and `check_branch_updates.sh` all point into the worktree. |
| `worktree_list.sh:21` | same line, then `cd "$ROOT_DIR"` (line 100) | Partly masked: `git worktree list --porcelain` lists every worktree from any of them, so the workspace section looks right. The project section reads the registry from `ROOT_DIR` and finds none, so registered projects' worktrees go missing from the listing. Shown here: `registry_entries` on this worktree's root returns nothing while the main checkout's `.agent/projects.local` has `gz4d`. |
| `worktree_remove.sh:131` | same line (its comment at 127-130 says "regardless of CWD", which is true of the cwd and false of the script's own location) | Does not have the fix. Same nested base, empty registry; line 343 `cd "$ROOT_DIR"` and the line-372 hint point at the worktree. |

Shown without changing anything: `bash -c 'source _worktree_helpers.sh; source _project_registry.sh; ...'` with the root computed the scripts' way from this worktree printed `ROOT=.../worktrees/workspace/issue-workspace-585`, `wt_workspace_base` = `.../issue-workspace-585/worktrees/workspace`, and `registry_entries` empty; `registry_main_checkout` on the same root printed `/home/roland/agent_workspace`. `.agent/projects.local` exists only in the main checkout (`ls` from the worktree: no such file).

How other scripts find the main checkout: `registry_main_checkout "$root"` in `_project_registry.sh:766` (first entry of `git worktree list --porcelain`, checked to share the common dir, falls back to `<root>`); `registry_main_checkout_fallback` says when it fell back; `~/.claude/agent-workspace-root` (written by `user_tier_install.sh`) is what skills use and is optional; several scripts use `--git-common-dir`. `registry_require_root` already accepts a worktree path as "inside the workspace" only by prefix, so it does not catch this.

What no longer applies: the fork's "fix to `worktree_remove.sh`" and its #508/#509 are not in this repository (its `#508`/`#509` are unrelated issues here); `worktree_remove.sh` is not the one with a fix, it is the fourth with the bug. The triage note's "one of the first three to do" is wrong in this repository: all four have it, so the smallest correct scope is all four.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Fix completely (Quality Standard) | Action needed | Fix all four scripts with one shared helper (for example `wt_main_root` in `_worktree_helpers.sh`, built on `registry_main_checkout`), not four copies of a new line. Decide the helper's behaviour when the main checkout cannot be found (`registry_main_checkout_fallback` true): refuse with a clear message rather than quietly use the worktree. |
| Tests with the fix | Action needed | Add a case to `test_worktree_create.sh`, `test_worktree_remove.sh` (and a new or extended case for enter and list) that runs the script as the copy inside a linked worktree of a sandbox repository and checks the root, the new worktree's base directory, and that a registered project is found. |
| Verify before claiming | Watch | The issue's line numbers are the fork's (`worktree_remove.sh:130` is now 131); the plan should re-read the scripts rather than trust them. |
| Only what's needed | Watch | `dispatch_phase.sh` and other scripts may carry the same line; check with a grep (`dirname "$(dirname "$SCRIPT_DIR")"`) and list hits as follow-ups unless they run from a worktree copy too. #239 (Makefile) stays its own issue. |
| Keep one current design | OK | `docs/design.md#worktrees` is already what the fix implements. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0002 (worktree isolation) | Yes | The fix makes the scripts honour its layout when run from a worktree. |
| ADR-0016 (user tier) | Watch | A user-tier copy of the script (promoted, invoked from any cwd) must still resolve the workspace correctly; the `registry_require_root` guard runs on `ROOT_DIR`, so check the helper in that mode too. |
| ADR-0003/0004/0006 | No | Not touched. |

### Consequences

- `.agent/knowledge/script_reference.md` and `.agent/WORKTREE_GUIDE.md` need a line only if the scripts' documented behaviour changes (a new refusal message does).
- Correct the comment at `worktree_remove.sh:127-130`.

### Recommendations

- Retitle or amend the plan's scope to "all four scripts (create, enter, list, remove)"; drop the fork's `worktree_remove.sh` fix and its #508/#509 references as not applying here.
- Put the root rule in one helper used by all four scripts, built on `registry_main_checkout`, with a clear refusal when the main checkout cannot be found.
- Add tests that run each script as the copy inside a linked worktree and check the resolved root, the base directory for the new worktree, and a registered project.
- Grep the other scripts for the same `dirname "$(dirname "$SCRIPT_DIR")"` line and list any that run from worktree copies as follow-ups; leave #239 (Makefile) separate.

### Actions
- [ ] Fix all four scripts with one shared helper (for example `wt_main_root` in `_worktree_helpers.sh`, built on `registry_main_checkout`), not four copies of a new line. Decide the helper's behaviour when the main checkout cannot be found (`registry_main_checkout_fallback` true): refuse with a clear message rather than quietly use the worktree.
- [ ] Add a case to `test_worktree_create.sh`, `test_worktree_remove.sh` (and a new or extended case for enter and list) that runs the script as the copy inside a linked worktree of a sandbox repository and checks the root, the new worktree's base directory, and that a registered project is found.
- [ ] Retitle or amend the plan's scope to "all four scripts (create, enter, list, remove)"; drop the fork's `worktree_remove.sh` fix and its #508/#509 references as not applying here.
- [ ] Put the root rule in one helper used by all four scripts, built on `registry_main_checkout`, with a clear refusal when the main checkout cannot be found.
- [ ] Add tests that run each script as the copy inside a linked worktree and check the resolved root, the base directory for the new worktree, and a registered project.
- [ ] Grep the other scripts for the same `dirname "$(dirname "$SCRIPT_DIR")"` line and list any that run from worktree copies as follow-ups; leave #239 (Makefile) separate.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:13 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review confirms the defect in all four worktree scripts, which is the scope the owner accepted at the triage: "four worktree scripts find the wrong root when run from a worktree copy"; its actions are directions for the plan)
**After**: issue-actions
**Decision**: proceed

The owner started this drive with "start those 3" (2026-11-24). Instructions for the plan (host decisions, listed for the owner's veto):
- Scope: all four scripts (worktree_create.sh, worktree_enter.sh, worktree_list.sh, worktree_remove.sh). The issue's text about a fix already made to worktree_remove.sh, and its #508 and #509, belong to the old repository; here that script has the same defect.
- One shared helper for the main checkout, built on what the repository already has (registry_main_checkout in _project_registry.sh), used by all four; when the main checkout cannot be found, a clear refusal, never a guess. Check it with and without the user tier (ADR-0016).
- Tests that run each script as the copy inside a linked worktree of a sandbox repository: the resolved root, where a new worktree would be made, and that a registered project is found. A destructive path (remove) is tested in the sandbox only.
- The misleading comment in worktree_remove.sh ("regardless of CWD") is corrected with the fix.
- Other scripts with the same root line are listed in the plan as follow-ups, not fixed here. The Makefile case (issue 239) stays separate.
- worktree_remove.sh is live-path code that deletes: the full standard applies to it, including what it does when the helper refuses.

## Plan Authored
**Status**: complete
**When**: 2026-11-24 13:16 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-585/plan.md` at `1e8602b7`

One helper, wt_main_root in _worktree_helpers.sh (built on registry_main_checkout and its fallback; reads no user-tier file), sets ROOT_DIR in all four worktree scripts and refuses with exit 1 before any action when the main checkout is not found. A new sandbox suite runs each script as the copy in a linked worktree, committed red before the fix; other scripts with the same root line are listed as follow-ups.

## Plan Review
**Status**: complete
**When**: 2026-11-24 13:22 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #585 — worktree_create/enter/list.sh share the ROOT-resolution bug fixed in #508
**Plan**: `.agent/work-plans/issue-585/plan.md` at `1e8602b7`
**Branch**: `feature/issue-585`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One helper, four one-line call sites, one new suite, three doc clauses: one PR. Other scripts with the root line are follow-ups, as the checkpoint said. |
| Issue alignment | Good | Covers every checkpoint direction: all four scripts, one helper on `registry_main_checkout`, refusal (never the worktree as fallback, no override on remove), tests as the copy in a linked worktree, with and without the user-tier file, comment at `worktree_remove.sh:127-130` corrected, follow-ups listed, issue 239 separate. The issue's own "location-based fallback" is rightly replaced by the checkpoint's refusal. Serves: "Easy to use: `docs/design.md#worktrees`" (README `### Easy to use` and design `## Worktrees` both exist). |
| File targeting | Needs work | Two existing suites encode the old root and fail after the fix but are not in Files to Change (finding 1). Line numbers checked: create 35, enter 25 (idiom on 38), list 21, remove 131 / comment 127-130 / `cd` 343 / hint 372, enter hints 461-463, `merge_pr.sh` 2411/2511/2523: all true on this branch. |
| Consequences | Needs work | The design.md edit needs a Change log row (finding 5); the remove-its-own-tree case that the fix newly enables is claimed as a benefit but not reasoned or tested (finding 3); the data files the copy now reads from the main checkout are not mentioned (finding 8). Callers checked: `/start-task`, `onboard-project`, `research` call `$WS_ROOT/.agent/scripts/...` (unaffected); `merge_pr.sh` calls `$SCRIPT_DIR/worktree_remove.sh` after `cd "$ROOT_DIR"` (main, via `git worktree list`); `dispatch_phase.sh` calls none of the four; `sitrep_root.sh` prefers `$WS_ROOT`'s `worktree_list.sh`; `dashboard.sh` uses its own `$SCRIPT_DIR`. |
| Principle alignment | Good | Never act on a guess (refusal before any git/rm), Test what breaks (red first), Only what's needed, prior art (`registry_main_checkout` taken; `git worktree list \| head -n1` rejected with reason). Keep one current design: one sentence made exact, see finding 5. |
| ADR compliance | Good | ADR-0016 decision 7 (scripts take their root from their location, never the user-tier file) is what the helper does; ADR-0002 layout kept; ADR-0013 records via `progress_append.sh`. |
| ROS conventions | N/A | Workspace plan. |

What was checked against the code, for the invocations the host asked about:

- Relative path from the main checkout: `own` = main, git dir = common dir, prints main. Unchanged.
- Relative path from inside a workspace worktree (the defect, and the normal state after `/start-task` `cd`s the session into a worktree when the user-tier file is absent so `$WS_ROOT` is `.`): prints main; `registry_require_root main` then accepts the cwd by prefix, since workspace worktrees live under `main/worktrees/workspace/`.
- Absolute `$WS_ROOT/.agent/scripts/...` from a project session or a project worktree: the script's location is the workspace main checkout, so `ROOT_DIR` is unchanged. Nothing used `ROOT_DIR` for the project side: the project root comes from the registry (`registry_lookup`, `registry_resolve_session_dir "$ROOT_DIR" "$PWD"`, `wt_project_base`, `wt_resolve_project_repo_root`), and the caller's directory from `CALLER_DIR`/`$PWD`. So the fix only makes the registry readable from a copy.
- Symlinked path: the plan's `cd -P "<script_dir>/../.."` is wrong for one shape (finding 4); a symlinked checkout is fine either way.
- Behaviour that works today and keeps working: `worktree_list.sh` from a worktree copy (git lists every worktree; now the project section appears too); `worktree_enter.sh` sourced from a worktree (now finds the target instead of looking under `<worktree>/worktrees/`); the hints now name the main checkout's scripts, which are the right ones.
- Refusal cases are the unusual ones: a `--separate-git-dir` main checkout passes (git dir = common dir), only its linked worktrees refuse; a bare-plus-worktrees layout has no main checkout to hold the registry and refuses (clearly); the main checkout on a feature branch changes nothing; a second clone resolves to its own main checkout, as today. This machine's workspace has a plain `.git` directory.
- `worktree_remove.sh`: every path it deletes is still derived after the root (manifest entries from the worktree, owners from each entry's own common dir, read-only and manifest-path guards unchanged); a refusal exits before the registry parse, the `cd` at 343 and every delete.
- Red-first commit: fits the hooks. Dispatched implement passes commit with `SKIP=validate-script-tests` (`.pre-commit-config.yaml` comment, issue 465), the host's publish run and CI (`make lint`) run on the pushed head only. The cost is one red commit for anyone bisecting; record the red run's output (command, failing case names) in the implementation entry.

### Findings

1. **[File targeting]** (medium) Two existing suites assert the old root and will fail after the fix; add both to Files to Change and update their fixtures, never loosen the helper. (a) `test_worktree_create.sh:392-394`, the race case: "Run from $FEAT, the script's root is that worktree", with `RACE_MSG` naming `$FEAT` and `RACE_DEST="$FEAT/worktrees/workspace/issue-origin-38"`; after the fix the root is `$SB`, so the message says `$SB` and the destination is under `$SB/worktrees/workspace/`. (b) `test_worktree_enter_stderr.sh:215-222`, the must-be-sourced case: it copies `worktree_enter.sh` into `$SANDBOX/.agent/scripts`, and `$SANDBOX` is a plain `mktemp -d` (only the worktree beneath it is `git init`ed), so `wt_main_root` refuses "not a git checkout" on line 25 before the must-be-sourced message the case asserts; `git init` the sandbox root (and commit the copied scripts so the marker check holds).
2. **[Consequences / tests]** (medium) The remove refusal tests prove "deletes nothing" only where something could be deleted. For the non-git directory and the plain directory inside another repository there is no worktree on the path the script would act on, so the assertion is vacuous. In each refusal fixture put a real linked worktree at the path the script would have targeted from `own` (for example `<own>/worktrees/workspace/issue-workspace-3`, and for the `--separate-git-dir` case a linked worktree of that clone named by `--issue`), then assert directory, branch and `git worktree list` entry survive and stdout is empty. That makes the test fail if a later edit lets the script proceed.
3. **[Consequences]** (low-medium) The fix newly enables a script removing the worktree its own copy runs from: `merge_pr.sh` run as a worktree's copy `cd`s to the main checkout and calls `$SCRIPT_DIR/worktree_remove.sh`, the copy inside the worktree being removed (today it fails "No workspace worktree found", so cleanup is reported incomplete). It works on Linux (bash holds the script open; nothing is sourced after the delete; line 719's `"$SCRIPT_DIR/worktree_list.sh" 2>/dev/null \|\| git worktree list` falls back), but the plan should say it is intended, and the case "copy inside worktree 3 removes worktree 3" should name its cwd (the main checkout: a cwd inside the target is refused at line 369) and assert exit 0, the tree gone, and the closing listing printed.
4. **[Approach]** (low) `own = cd -P "<script_dir>/../.."` does not do what the plan says for a symlinked `.agent/scripts`: `cd -P` resolves `..` after the link, so it lands on the link target's grandparent, not the checkout (checked in the scratchpad: `ws/.agent/scripts -> elsewhere/deep/scripts` gives `elsewhere`). Use the logical parent first, then resolve: `own="$(cd "$(dirname "$(dirname "$script_dir")")" && pwd -P)"`, which keeps today's location rule and only makes the checkout's path physical. No such link exists in this repository today, so this is correctness of the stated contract, not a live bug.
5. **[Consequences / design]** (low) The new `docs/design.md#sessions-and-roots` sentence over-reaches: "Workspace scripts ... resolve their own root from their location (the main checkout, when the copy is in a linked worktree: `wt_main_root`)" is true only of the four worktree scripts; the other scripts with the `dirname`/`../..` line still take the copy's own checkout, and `merge_pr.sh`, `dispatch_phase.sh`, `session_root.sh` use `git worktree list \| head -n1`. Scope it to "the worktree scripts (`wt_main_root`)". The design document's own Change log rule ("One row per change to this file, appended in the same change that alters a section", with the line count) asks for a row; add it. Also, neither `docs/design.md#worktrees` nor `.agent/WORKTREE_GUIDE.md` contains the "called from anywhere" sentence the plan cites, so step 5's WORKTREE_GUIDE edit needs a chosen place (the Worktree Entry or script-usage part).
6. **[Tests]** (low) The implement pass's named suites leave out suites that run these scripts from sandbox copies and will be reached by `_worktree_helpers.sh` changing: `test_project_registry.sh`, `test_ros2_colcon.sh`, `test_precommit_hook_path.sh`, `test_merge_pr.sh`, `test_merge_pr_skill.sh`, `test_package_issue_loop.sh`, `test_sitrep_root.sh`. Run `run_script_tests.sh --files <changed files>` (what the hook would select) rather than a hand list, so a fixture like finding 1's is found in the implement pass, not at the host's publish run.
7. **[Follow-ups]** (low) The hand list of scripts with the root line is incomplete: a grep for `dirname "$(dirname "$SCRIPT_DIR")"` / `SCRIPT_DIR/../..` also hits `check_agents_md_budget.sh`, `register_project.sh`, `register_session_root.sh`, `sitrep_checks.sh`, `sitrep_root.sh`, `skill_prefix.sh`, `user_tier_install.sh` (several only locate their own files). Build the follow-up issue's list from the grep.
8. **[Consequences]** (low) With the root now the main checkout, a worktree's copy reads two things from the main checkout rather than its own branch: `--workflow` files (`worktree_create.sh:475`, `$ROOT_DIR/.agent/workflows/`) and `check_branch_updates.sh` (`worktree_enter.sh:450`). That is right for normal use, but a branch adding a workflow cannot try it through its own copy; say so in the `script_reference.md` clause.
9. **[Accuracy]** (low) Step 3 says `registry_require_root` stays "in the three scripts that have it": all four have it (create 52, enter 38, list 31, remove 143).
10. **[Approach]** (low, optional) A git failure that is not "no repository" (for example a `safe.directory` / dubious-ownership refusal) would be reported as "not a git checkout"; carry git's own stderr line into the `ERROR:` so the refusal says what actually failed.

**Open question (a project carrying its own `.agent/scripts`)**: a real but harmless case; fine to leave, no owner decision needed. Projects get the workspace's scripts through `$WS_ROOT` (the user-tier file) and the plugin, never as a copy; `.agent/user_tier_scripts.txt` promotes by absolute-path permission rules, not by copying. On this machine `/home/roland/project11` holds its own `.agent/scripts/_worktree_helpers.sh` (an older workspace-shaped checkout, not registered): its scripts resolve to its own main checkout, which is what they already do when run from that checkout, so this is the same location rule, not a guess. The plugin cache (`~/.claude/plugins/cache/agent-workspace/agent-workspace/<sha>/`) is a full copy of `.agent/scripts` but not a git checkout, so the helper refuses there, which is the right outcome if anything ever ran a script from it (the skills do not: they use `$WS_ROOT`).

### Summary

The helper's contract is right for every way the four scripts are really invoked, the refusals are the unusual layouts, and `worktree_remove.sh` keeps every derivation and guard after the new root. The gaps are in the test and documentation details, chiefly two existing suites that encode the old root and a remove-refusal test that cannot yet fail; each can be taken in implementation without a new plan.

### Recommended Actions

- [ ] Add `test_worktree_create.sh` (race case, lines 392-394) and `test_worktree_enter_stderr.sh` (must-be-sourced sandbox, lines 215-222) to Files to Change and update their fixtures to the main-checkout root.
- [ ] Give each remove-refusal fixture a real worktree on the path the script would act on, and assert it survives.
- [ ] State the remove-its-own-copy case as intended and test it with cwd = main checkout, exit 0, tree gone, listing printed.
- [ ] Compute `own` as the logical grandparent made physical (`cd "$(dirname "$(dirname "$script_dir")")" && pwd -P`), not `cd -P "<dir>/../.."`.
- [ ] Scope the design.md sentence to the worktree scripts, add the Change log row, and pick the WORKTREE_GUIDE place for the new sentence.
- [ ] Select the implement pass's suites with `run_script_tests.sh --files <changed files>`; record the red run's output in the implementation entry.
- [ ] Build the follow-up issue's script list from a grep; mention the main-checkout workflow and `check_branch_updates.sh` reads in `script_reference.md`; correct "three scripts" to four.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:23 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is ready; every finding is one the reviewer says can be handled during implementation)
**After**: plan
**Decision**: proceed

Implement the plan at 1e8602b7 with these instructions, which answer the Plan Review at e770230e and bind the implementer (host decisions, listed for the owner's veto):
- Finding 1: the two existing tests that assume the old root are updated with the fix (test_worktree_create.sh, the race case; test_worktree_enter_stderr.sh, which runs a copied script from a folder that is not a git repository): each keeps testing what it tested, in a fixture the new helper accepts.
- Finding 2: every refusal test for worktree_remove.sh has a real worktree on the path the script would act on, so "nothing was deleted" proves something.
- Finding 3: merge_pr.sh run as a worktree's copy can, after the fix, remove the worktree its own scripts are running from. That is intended (it is what the merge is asked to do, and it fails today only by accident); say so in the script reference and test it with the working directory in the main checkout.
- Finding 4: resolve the root with cd "$(dirname "$(dirname "$script_dir")")" && pwd -P, which is right when .agent/scripts is a symbolic link.
- Finding 5: the sentence added to docs/design.md says what is true of the four worktree scripts only, with the Change log row the document's rule asks for; the worktree guide gets its sentence where it describes running the scripts from inside a worktree.
- Finding 6: choose the suites to run with run_script_tests.sh --files <changed files> -j 4 (check the flags in its help first), so the suites that run these scripts from sandbox copies are included; name each with its result line.
- Finding 7: the follow-up list of other scripts with the same root line is built from a grep and goes in the pull request text; none is fixed here.
- Finding 8: the script reference says that, run from a worktree, these scripts now read --workflow files and check_branch_updates.sh from the main checkout.
- Finding 9: registry_require_root is in all four scripts; the text says so.
- Finding 10: when git itself fails (a safe.directory refusal, for example), the refusal includes git's own error line.
- The plan's open question (a project that carries its own copy of the workspace's scripts takes its own main checkout as root) is left as it is: the reviewer found it real but harmless, since projects get the scripts through the plugin and the workspace root, never by copy.
- worktree_remove.sh deletes: it must never act on a root it did not verify. No flag overrides a refusal.

## Implementation
**Status**: complete
**When**: 2026-11-24 13:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-585 at `d59c03c6`

Commits (red first, then the fix):
- `d423a01c` (the red commit): new suite `test_worktree_main_root.sh` and a `test_merge_pr.sh` case (`merge_pr.sh` run as the copy inside the PR's worktree, cwd the main checkout, removes that worktree). Red run against the four scripts as on `main`: `bash .agent/scripts/tests/test_worktree_main_root.sh` gave `test_worktree_main_root: 31 passed, 100 failed` (every `wt_main_root` case: "command not found"; create from worktree 3's copy made `issue-workspace-9` nested under worktree 3; create/remove `--type project` from the copy: "project 'demo' is not registered (registered: none)"; the copy could not remove its own worktree from the main checkout: "refusing to run: <main> is neither inside the workspace (<worktree>)"; each refusal fixture: create made a branch, enter printed the target and the sourced enter returned 0, list printed, and remove from the non-git copy deleted the worktree on its path). `bash .agent/scripts/tests/test_merge_pr.sh` gave `Results: 177 passed, 4 failed` (the new case: "Worktree removal failed").
- `cae735d5` the fix: `wt_main_root <script_dir> [<name>]` in `_worktree_helpers.sh`; the root line of `worktree_create.sh`, `worktree_enter.sh` (sourced idiom), `worktree_list.sh`, `worktree_remove.sh` (comment corrected) moved below the `source` lines and replaced. `worktree_create.sh` calls the main checkout's adapter and sources the main checkout's `_pr_base.sh` (see Decisions). Updated: `test_worktree_create.sh` (race case and the eight stop messages now name the main checkout `$SB`, the race destination is under `$SB/worktrees/workspace/`), `test_worktree_enter_stderr.sh` (must-be-sourced case: `git init` of the sandbox, so it is a main checkout holding the scripts).
- `42e242b6` the new suite's `ROOT_READERS` entry in `test_script_tests_hook_scope.sh` (the selection run asked for it).
- `d59c03c6` docs: `script_reference.md` (four rows, `merge_pr.sh` row), `WORKTREE_GUIDE.md` (Worktree Entry bullet), `docs/design.md` Sessions and roots (one sentence on the four worktree scripts) and its Change log row (1288 lines).

Helper contract: prints the physical main checkout git names for the logical grandparent of `<script_dir>` made physical; never reads the cwd or `~/.claude/agent-workspace-root`. Refuses (exit 1, nothing on stdout, one `ERROR: <name>: ...` line naming the directory, with "run the copy in the workspace's main checkout") when that directory is not the top level of its own git checkout (git's own first error line quoted), is inside another checkout, is a linked worktree whose main checkout git does not name (`registry_main_checkout_fallback`), or has a main checkout without `.agent/scripts/_worktree_helpers.sh`. `registry_require_root` follows in all four scripts.

Checkpoint instructions:
- F1: both suites updated, each still tests what it tested.
- F2: every remove refusal case has a real linked worktree on the path the script would act on (`<own>/worktrees/workspace/issue-workspace-3` for the non-git and plain-directory copies, `issue-workspace-4` under the `--separate-git-dir` worktree) and asserts directory, branch and `git worktree list` entry survive, plain and `--force`.
- F3: tested in both suites with the cwd in the main checkout; stated as intended in `script_reference.md` (`worktree_remove.sh` and `merge_pr.sh` rows) and `WORKTREE_GUIDE.md`.
- F4: `cd "$(dirname "$(dirname "$script_dir")")" && pwd -P`; tested with a symlinked `.agent/scripts` and a symlinked checkout path.
- F5: the design sentence is scoped to the four worktree scripts; Change log row added; `test_design_anchors.sh` run.
- F6: suites selected with `run_script_tests.sh -j 4 --files <changed files>` (the runner is at `.agent/scripts/tests/run_script_tests.sh`; no `--help`, its usage line lists `-j N` and `--files`).
- F7: follow-up list below, from a grep; none fixed.
- F8: `script_reference.md` names the `--workflow` files, `check_branch_updates.sh` and the adapter as read from the main checkout.
- F9: the reference says all four run `registry_require_root` after the root.
- F10: git's own error line is in the refusal; tested with a `.git` file naming a missing git dir.

Decisions not in the plan or checkpoint:
- `worktree_create.sh` called `$SCRIPT_DIR/adapter`, and the adapter takes its root from its own location, so from a worktree copy `create --type project` still read the worktree's empty registry (the new suite caught it). Its two adapter calls now use `$ROOT_DIR/.agent/scripts/adapter`, and `_pr_base.sh` (whose `pr_base_for` calls the adapter beside it) is sourced from `$ROOT_DIR/.agent/scripts/`. From the main checkout these are the same files. The adapter itself is unchanged (it is on the follow-up list). The package-worktree path through `_pr_base.sh` from a worktree copy has no test of its own here; `test_package_issue_loop.sh` and `test_ros2_colcon.sh` cover it from the main checkout and pass.
- The marker check is file existence in the main checkout, not a committed file (the existing suites keep the scripts untracked in their main checkout).

Follow-up list for the pull request text (from `grep -nE 'dirname "\$\(dirname "\$[A-Z_]*(SCRIPT_DIR|_DIR)"\)"|SCRIPT_DIR/\.\./\.\.'` and a grep for `worktree list --porcelain ... head -n1`; none fixed here; several only locate their own files):
- Same location root: `adapter:77`, `capture.sh:45`, `check_agents_md_budget.sh:19`, `dashboard.sh:28`, `discover_governance.sh:17`, `dispatch_phase.sh:603`, `fetch_pr_reviews.sh:21`, `generate_make_skills.sh:17`, `gh_create_issue.sh:93,128,195`, `gh_create_pr.sh:87,139`, `git_bug_setup.sh:21`, `lock.sh:15`, `unlock.sh:5`, `pr_status.sh:11`, `project_integration_audit.sh:209`, `project_setting.sh:81`, `register_project.sh:154`, `registration_verify.sh:74`, `update_roadmap.sh:97`, `user_tier_install.sh:159`; as a fallback after `git worktree list`: `register_session_root.sh:78`, `session_root.sh:77`, `sitrep_root.sh:200`, `skill_prefix.sh:57`, `sitrep_checks.sh:490`.
- `git worktree list --porcelain | head -n1` with no checks of its own: `merge_pr.sh:236`, `dispatch_phase.sh:162`, `register_session_root.sh:77`, `session_root.sh:76`, `sitrep_root.sh:199`, `skill_prefix.sh:56`.
- `dispatch_phase.sh:808` sources its own `_pr_base.sh` (adapter beside it).

Suites run (each on its own, final run after the last change to it):
- `test_worktree_main_root.sh`: `test_worktree_main_root: 131 passed, 0 failed`
- `test_worktree_create.sh`: `PASS: 112` / `FAIL: 0`
- `test_worktree_enter_stderr.sh`: `=== Results: 35 passed, 0 failed ===`
- `test_merge_pr.sh`: `=== Results: 181 passed, 0 failed ===`
- `test_script_tests_hook_scope.sh`: `test_script_tests_hook_scope: 374 passed, 0 failed`
- `test_design_anchors.sh`: `test_design_anchors: 82 passed, 0 failed`
- `test_skill_paths.sh`: `test_skill_paths: 212 passed, 0 failed`
- `run_script_tests.sh -j 4 --files <the 12 changed files>`: 57 suites selected, 56 passed (among them `test_worktree_remove.sh`, `test_project_registry.sh`, `test_user_tier_guard.sh`, `test_ros2_colcon.sh`, `test_precommit_hook_path.sh`, `test_merge_pr_skill.sh`, `test_package_issue_loop.sh`, `test_sitrep_root.sh`, `test_merge_pr_root_resolution.sh`, `test_adapter.sh`); `test_script_tests_hook_scope.sh` failed for the missing `ROOT_READERS` entry, fixed in `42e242b6` and rerun on its own (above). Every suite that names one of the five changed scripts was in the selection.
- The full pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 13:51 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-585 at `00a0130c`
**Base**: origin/main
**Depth**: Deep (reason: 969 changed lines in 15 files, including worktree_remove.sh, which deletes)
**Must-fix**: 1 | **Suggestions**: 4
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

Specialists: static analysis (shellcheck --severity=warning on the 10 changed scripts: clean), governance, plan drift, Claude adversarial (all five touched suites re-run: 131/0, 112/0, 35/0, 181/0, 374/0), cross-model Gemini (ran, complete) and Codex (ran, complete).

### Findings
- [x] (must-fix) `wt_main_root` silently returns the linked worktree itself when git's `--path-format=absolute --git-dir`/`--git-common-dir` calls fail (git older than 2.31, or any failure after `--show-toplevel` succeeded): `_registry_main_checkout_status` then prints `<own>\t0`, the same answer as a real main checkout, and the marker file exists in the copy, so the old wrong root comes back with no ERROR line (nested create; remove against the worktree). Refuse instead: when the answer is `$own`, confirm with git that `$own`'s git dir equals its common dir and refuse on any failure; add a case with a git shim that fails those calls. Found by the Claude adversarial pass and Codex, each reproduced with a shim — `.agent/scripts/_worktree_helpers.sh:101` (via `_project_registry.sh:788`)
- [x] (suggestion) The rewritten call sites `source "$ROOT_DIR/.agent/scripts/_pr_base.sh"` and the `worktree_env` adapter call (the `--layer` path) have no test as a worktree's copy; only the main checkout's run covers them (`test_package_issue_loop.sh`, `test_ros2_colcon.sh`) — `.agent/scripts/worktree_create.sh:845,1087`
- [x] (suggestion) The `merge_pr.sh` self-removal case starts in the main checkout; the usual call is from inside the worktree (merge_pr.sh `cd`s out itself). Start it from `$wt` too — `.agent/scripts/tests/test_merge_pr.sh:901`
- [x] (suggestion) The sourced `worktree_enter.sh` refusal check drops stderr and reads only the last stdout line; assert stdout is exactly `survived rc=1` and stderr has `ERROR:` — `.agent/scripts/tests/test_worktree_main_root.sh:369`
- [x] (suggestion) design.md Table 1 cites `worktree_enter.sh` 142-176 for the `--type` derivation, true on main and now 146-180 after this change; refresh (the create, remove and list citations there were already off on main) — `docs/design.md:552`

## Implementation
**Status**: complete
**When**: 2026-11-24 14:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-585 at `363b07b8`
**Addressed**: Local Review (Pre-Push) at `00a0130c` (2026-11-24 13:51 -05:00)
**Commits**: `eb6d309f` (F1), `d2d8cea9` (F4), `5106434f` (F3), `8a2b817d` (F5), `ab6e0871` (F2), `363b07b8` (F1 doc)

### Actions
- [x] F1 (must-fix): `wt_main_root` no longer takes the registry helper's "the folder itself" as "this is the main checkout". When that answer equals the folder, it asks git again with plain `rev-parse --git-dir` and `--git-common-dir` (git 2.5 on, relative answers made absolute from the folder, so CDPATH plays no part) and refuses, exit 1, nothing on stdout, one ERROR line, when a call fails ("cannot confirm that <own> is the main checkout of its repository (git: <git's first line>)"), when an answer is not a directory, or when the two differ ("<own> is a linked worktree (git dir X, common dir Y) whose main checkout could not be confirmed"). Could not tell is never yes. Plain calls rather than `--path-format=absolute`, so a git older than 2.31 still confirms a real main checkout. `_project_registry.sh` unchanged. Header comment and `script_reference.md` name the new refusal — `.agent/scripts/_worktree_helpers.sh:63`
  - Tests (`test_worktree_main_root.sh`): a git shim first on the sandbox PATH for these runs only, two modes: "old" fails `rev-parse --git-dir/--git-common-dir` only with `--path-format=absolute`, "all" fails every such call (the fixture checks each mode fails exactly those calls). Red run before the fix: `194 tests, 45 failed` (helper printed the worktree; create made a worktree nested under the copy's worktree; enter printed the nested path and the sourced enter returned 0; list and remove ran). After: the helper refuses for the linked worktree's copy in both modes with the expected message (git's shim line quoted in "all"); the main checkout's copy is still accepted in "old" and refused in "all". Each of the four scripts as the worktree's copy refuses in both modes (`refusal_case`): create makes no worktree and no branch; enter `--print-path` and sourced refuse; list refuses; remove and `remove --force` refuse with a real linked worktree on the path the defect would act on (`<worktree>/worktrees/workspace/issue-workspace-8`), whose folder, branch and git entry survive.
- [x] F2 (suggestion): new case in `test_ros2_colcon.sh` (`test_worktree_create_package_from_worktree_copy`): the existing package-worktree fixture with the scripts committed, `worktree_create.sh --layer l1 --package-repos pkg_a` run as a linked worktree's copy with that copy's own `_pr_base.sh` and `adapter` removed; asserts the package worktree lands under the registered project, `base=fakefox` from the pin (the main checkout's `_pr_base.sh`), `env.sh` written (the main checkout's adapter, `worktree_env`), and nothing made under the copy's worktree. A mutation check (pointing the source back at the copy's `_pr_base.sh`) was refused by the permission system and not run — `.agent/scripts/tests/test_ros2_colcon.sh`
- [x] F3 (suggestion): the `merge_pr.sh` self-removal case runs twice, cwd the main checkout and cwd inside the worktree; both pass — `.agent/scripts/tests/test_merge_pr.sh:881`
- [x] F4 (suggestion): the sourced `worktree_enter.sh` refusal asserts stdout is exactly `survived rc=1` and stderr has `ERROR:` — `.agent/scripts/tests/test_worktree_main_root.sh:369`
- [x] F5 (suggestion): Table 1 citations this change moved: `worktree_enter.sh` 142-176 to 146-180, and `worktree_list.sh` 171 to 175 (171 was right on main, contrary to the review's note, and this change moved it); Change log row added (1289 lines) — `docs/design.md:552`

Host directions followed (listed for the owner's veto): F1 fixed in `wt_main_root` only, `_project_registry.sh` untouched; F2 added as a short case because the existing fixture covered it; F5 corrects only citations this change moved.

For the pull request text:
- Table 1 citations already wrong on main, not fixed here: `worktree_create.sh` (`370-386` for the `--type` derivation, which on main is at 381-410; `427-431` for the `--layer`/`--package-repos` gating, on main at 419-452; `600-605`, `689-718`, `768-773`, `1294-1302` point at other code on main) and `worktree_remove.sh` `155-185` (on main the derivation and check are at 172-202). The `merge_pr.sh`, `dispatch_phase.sh`, `gh_create_pr.sh` and `_project_registry.sh` citations were not checked (this change does not touch those files).
- Follow-up, not done here: `_registry_main_checkout_status` (`_project_registry.sh`) reports a failed git call as `<root>\t0`, the same as a main checkout; its other callers may want that failure reported as such (a third status) rather than each caller confirming it.

Suites run (each on its own, after the last change):
- `test_worktree_main_root.sh`: `test_worktree_main_root: 199 passed, 0 failed`
- `test_merge_pr.sh`: `=== Results: 187 passed, 0 failed ===`
- `test_worktree_create.sh`: `PASS: 112` / `FAIL: 0`
- `test_worktree_remove.sh`: `test_worktree_remove: 138 passed, 0 failed`
- `test_worktree_enter_stderr.sh`: `=== Results: 35 passed, 0 failed ===`
- `test_project_registry.sh`: `=== Results: 425 passed, 0 failed ===`
- `test_design_anchors.sh`: `test_design_anchors: 82 passed, 0 failed`
- `test_skill_paths.sh`: `test_skill_paths: 212 passed, 0 failed`
- `test_script_tests_hook_scope.sh`: `test_script_tests_hook_scope: 374 passed, 0 failed`
- `test_ros2_colcon.sh`: `=== Results: 1209 passed, 0 failed, 0 skipped ===`
- `run_script_tests.sh -j 4 --files <the 6 changed files>`: `run_script_tests: all 57 suites passed in 300s` (among them `test_ros2_colcon.sh`, `test_package_issue_loop.sh`, `test_worktree_create.sh`)
- The full pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 14:15 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a5a07de4e76c3aa52, resume 1 of 3)
**Verdict**: changes-requested

**Branch**: feature/issue-585 at `3e739e87`
**Base**: origin/main
**Depth**: Deep (reason: whole-branch diff, 1240 changed lines in 16 files, including worktree_remove.sh, which deletes; fix round classified on the whole diff)
**Must-fix**: 1 | **Suggestions**: 0
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 1), not rising — fix and ship rather than another full round

Round 1 findings, all closed: F1 (`wt_main_root` confirms a folder that answers as its own main checkout with plain `rev-parse --git-dir`/`--git-common-dir` and refuses on any failure or difference; the shim tests prove the refusal for all four scripts, remove plain and `--force` with a real worktree on the defect's path, and that a real main checkout still passes with an old git); F2 (`--layer` case as a worktree's copy in `test_ros2_colcon.sh`); F3 (self-removal from inside the worktree); F4 (sourced-enter exact stdout and ERROR); F5 (Table 1 enter 146-180 and list 175, both checked; Change log row, 1289 lines).

Checked this round: shellcheck --severity=warning on the four changed scripts: clean; `test_merge_pr.sh`: 187 passed, 0 failed (both self-removal cases); `test_worktree_main_root.sh`: 199 passed, 0 failed (fresh adversarial run). Follow-up on `_registry_main_checkout_status` (a failed git call reported as the folder with the not-a-fallback flag): right to leave for a follow-up in the pull request text; `wt_main_root` no longer depends on it, and its other callers only read the registry for messages and lookups and delete nothing.

### Findings
- [x] (must-fix) An exported `GIT_DIR` (with or without `GIT_WORK_TREE`/`GIT_COMMON_DIR`) still gives a silent wrong root: `git -C "$own"` answers for `GIT_DIR`'s repository, so with `GIT_DIR=<main>/.git` or another repository's git dir, the copy in a linked worktree passes `--show-toplevel` (the cwd), `_registry_main_checkout_status` and the new confirm step (git dir equals common dir), and `wt_main_root` prints the worktree with exit 0, which is the original defect, silently. Reproduced in a sandbox by the adversarial pass; raised by Gemini in both rounds (dropped in round 1, reversed now). Run the helper's git calls, including the `registry_main_checkout*` calls, without `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE` and `GIT_COMMON_DIR` (prior art: `_project_document_git` in `_project_registry.sh:1546`, `_bookkeeping.sh:58`), and add a case with `GIT_DIR` exported — `.agent/scripts/_worktree_helpers.sh:66`

## Implementation
**Status**: complete
**When**: 2026-11-24 14:28 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a7f64e2a2e21cf19f, resume 1 of 3)

**Branch**: feature/issue-585 at `b0aa259d`
**Addressed**: Local Review (Pre-Push) at `3e739e87` (2026-11-24 14:15 -05:00)
**Commits**: `6dde7c80` (the fix and its tests), `b0aa259d` (Table 1 citation)

### Actions
- [x] (must-fix) An exported `GIT_DIR` gave a silent wrong root — `.agent/scripts/_worktree_helpers.sh:66`
  - Helper: every git call in `wt_main_root` runs through `_wt_git`, which is `env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR git "$@"`, the same body as `_project_document_git`. That covers `--show-toplevel`, its error re-run, and the confirm step's `--git-dir`/`--git-common-dir` and their error re-run. The `registry_main_checkout_fallback` and `registry_main_checkout` calls run in a subshell that unsets the same four (a test plus a command substitution), because `env -u` cannot run a shell function. The caller's environment is unchanged after the helper returns (tested). `_project_registry.sh` is not edited.
  - The four scripts' own git calls: with the helper fixed, a rerun showed `worktree_create.sh` still followed an exported `GIT_DIR` to an unrelated repository. It made a worktree of that repository (`worktrees/workspace/issue-unrelated-12`, its branch in that repository). `worktree_list.sh` listed that repository's worktrees, and `worktree_remove.sh` would act through the same calls. So `worktree_create.sh`, `worktree_list.sh` and `worktree_remove.sh` now `unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR` before the root line. Each runs as its own process, so this changes nothing outside it, and it is one line per script against a call-by-call `env -u` in dozens of places. I chose this over refusing when `GIT_DIR` names another repository: a refusal would still let a `GIT_DIR` naming the root's own repository steer the `git -C <project repo>` calls of a project worktree to the workspace. `worktree_enter.sh` is sourced, so unsetting there would change the caller's shell, and it is left as is: its own git calls (`rev-parse --show-toplevel` as a fallback when the issue's worktree is not found, the `origin` slug for the title, the branch name after the cd) only read, and none creates or removes anything.
  - Red run (both fixes absent): `test_worktree_main_root: 222 passed, 23 failed`. For both GIT_DIR values the helper printed `<ws>/worktrees/workspace/issue-workspace-7`. Create made its worktree nested under the copy's worktree. Enter printed the nested path. With the main checkout's GIT_DIR, remove exited 0 having deleted the nested worktree `issue-workspace-8`. The unrelated repository's refs and worktrees changed. With the helper fixed and the scripts not yet: 6 failed, all in the unrelated-repository case (as above). After both: `245 passed, 0 failed`.
  - Tests (`test_worktree_main_root.sh`): GIT_DIR is exported inside each run's own subshell only (`use_test_git_dir`, which refuses a path outside the sandbox), set first to the main checkout's git dir and then to an unrelated sandbox repository's. Checked for each: the helper from a linked worktree's copy prints the main checkout, exit 0, empty stderr, and the caller's GIT_DIR is kept. Create from the copy puts the worktree under the main checkout, listed in its repository, with nothing nested. Enter `--print-path` finds it. List shows it and nothing of the unrelated repository. Remove for the nested path's issue, plain and `--force`, does not act: the nested worktree's folder, its branch and git's entry for it survive. Remove from the copy deletes the main checkout's worktree. The unrelated repository's branches and worktrees are unchanged.
- Consequence: the new `unset` block moved `worktree_list.sh`'s workspace-path check from line 175 to 182. Table 1 and this change's Change log row now say 182 (still 1289 lines). The create and remove citations were already off on main and stay on the pull-request list.

Host direction followed (listed for the owner's veto): the helper's own calls, including the `registry_main_checkout*` calls, run with the four unset, through the `_project_document_git` / `_bookkeeping.sh` `env -u` idiom; `_project_registry.sh` is not edited.

Suites run (each on its own, after the last change):
- `test_worktree_main_root.sh`: `test_worktree_main_root: 245 passed, 0 failed`
- `test_worktree_create.sh`: `PASS: 112` / `FAIL: 0`
- `test_worktree_remove.sh`: `test_worktree_remove: 138 passed, 0 failed`
- `test_worktree_enter_stderr.sh`: `=== Results: 35 passed, 0 failed ===`
- `test_merge_pr.sh`: `=== Results: 187 passed, 0 failed ===`
- `test_design_anchors.sh`: `test_design_anchors: 82 passed, 0 failed`
- `run_script_tests.sh -j 4 --files <the 6 changed files>`: `run_script_tests: all 57 suites passed in 349s`
- The full pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 14:29 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a5a07de4e76c3aa52, resume 2 of 3)
**Verdict**: approved

**Branch**: feature/issue-585 at `a4c3cea7`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings

Cross-model: skipped (round-3 convergence check, per handoff). Scope: the round 2 finding and the fix diff 41e5965b..a4c3cea7.

Round 2 finding closed: every git call in `wt_main_root` runs through `_wt_git` (the four variables unset, as `_project_document_git` does) and the two registry calls in a subshell with them unset; the caller's `GIT_DIR` is unchanged on return (tested). `worktree_create.sh`, `worktree_list.sh` and `worktree_remove.sh` unset the four before their root line; no git call precedes it in any of the three (checked), so every later git call, the sourced helpers' and the adapter's included, acts on the directory it names. Right for a git hook: a hook's `GIT_DIR` names the hook's repository, and these scripts act on the workspace found from their location; a commit hook's `GIT_INDEX_FILE` reaching `git worktree add` would be worse than ignored. No caller in the repository sets one of the four for these scripts (grep; the two suites that set one run other tools). `worktree_enter.sh` left alone is safe: it is sourced, so an `unset` would change the caller's shell; its root comes from the helper, and its own git calls only read. Tests: with `GIT_DIR` exported to the main checkout's git dir and to an unrelated repository's, the copy makes, finds, lists and removes in the main checkout only, the unrelated repository's refs and worktrees are unchanged, and remove plain and `--force` of the nested path's issue exits non-zero with the real worktree there kept (folder, branch, git's entry). Design Table 1 `worktree_list.sh` 182 checked; design.md 1289 lines, as the row says.

Run this round: shellcheck --severity=warning on the four changed scripts: clean; `test_worktree_main_root.sh` 245 passed, 0 failed; `test_worktree_remove.sh` 138 passed, 0 failed; `test_worktree_create.sh` PASS 112, FAIL 0.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 14:34 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 of the pre-push review approved with nothing open, Ship: recommended; the host's full pre-commit pass over the changed files passed, every hook, no SKIP, on the code at a4c3cea7, run beside the round 3 review, which added a record commit only)
**After**: publish
**Decision**: publish

Three pre-push rounds: round 1 found 1 must-fix (a failed git call read as "is the main checkout") and 4 suggestions; round 2 found 1 must-fix (an exported GIT_DIR); round 3 (a convergence check, no cross-model reviewers) found both closed and nothing new. Gemini and Codex ran in rounds 1 and 2. Main was merged in twice (pull requests 603 and 604), with no conflict.
