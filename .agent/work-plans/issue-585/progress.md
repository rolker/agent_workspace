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
