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
