---
issue: 252
---

# Issue #252 — ros2_colcon adapter phase 3: layer/package worktrees (no symlink fallback)

## Plan
**Status**: complete
**When**: 2026-09-15 09:05
**By**: Claude Code Agent (claude-sonnet-5, drafting for claude-fable-5-1)

Plan file: `.agent/work-plans/issue-252/plan.md`.

Recommends Design B (pure overlay: colcon-native overlay on the hosted instance's
existing layer installs, no symlinked siblings/layers) over Design A (upstream's
hybrid mirror), because it satisfies the no-symlink hard-stop rule structurally and
avoids reintroducing the #427/#598 bug classes, at medium rather than large
implementation cost.

## Plan revision
**Status**: complete
**When**: 2026-09-15 09:40
**By**: Claude Code Agent (claude-fable-5-1)

Resolved the three open questions with the owner: AGENTS.md untouched, p11-jazzy-only
smoke, explicit CLI (`--type project --project <name> --issue owner/repo#N --layer
--package-repos`, nothing inferred) with qualified branch names in non-owning repos.
Depends on #255 (`--repo` → `--project` rename).

## External Review
**Status**: complete
**When**: 2026-09-15 15:10
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #254 — 1 review(s), 8 valid, 0 false positives
**CI**: all-pass

All eight Copilot comments target `plan.md` (plan-only PR, no implementation
yet). Each was verified against the cited script lines and holds; the plan
needs revision before `/review-plan`.

### Actions
- [x] Decide (owner): ADR-0011 conflict — steps 1/5/6 branch generic scripts on `ros2_colcon`; ADR's own verb test ("workflow needs it, how differs per type") says add adapter verbs (e.g. `worktree_add` / `worktree_remove` / `worktree_env`, with `single_project` implementing today's single-repo path) or record a superseding decision
- [x] Plan step 6: `merge_pr.sh` resolution starts too early to fix at lines 389-410 — it queries only workspace + `project/` remotes and parses `feature/issue-N`; package PRs (other repos, `feature/<owner-repo>-issue-N`) need repo-qualified PR lookup, aggregate-worktree lookup, and a rule for cleanup when sibling package PRs are still open
- [x] Plan step 3: multi-repo creation must roll back earlier successful `git worktree add`s on a later failure; hermetic test must fail on the *second* repo
- [x] Plan step 4: generated `build.sh`/`test.sh` must `unset COLCON_PREFIX_PATH AMENT_PREFIX_PATH CMAKE_PREFIX_PATH AMENT_CURRENT_PREFIX` before sourcing the underlay (mirror `adapter_build` line 452); add a polluted-shell ordering test
- [x] Plan step 4: `test.sh` must source the worktree `install/local_setup.bash` *before* `colcon test` (mirror `adapter_test`); provide a sourceable `env.sh` since an executed script cannot set the caller's env
- [x] Plan step 5: `worktree_remove.sh` dirty check (lines 228-240) runs `git status` at the aggregate root, which is not a repo — preflight every nested package repo before removing any, remove the aggregate dir last; add multi-package dirty case to hermetic suite
- [x] Files to Change: add `.claude/skills/start-task/SKILL.md` (compat note) and state that re-entry uses the `--issue owner/repo#N --type project --project <name>` form only, consistent with existing creation-only flags
- [x] Files to Change: add `worktree_list.sh` (regex at lines 118-125 rejects `issue-<project>-<owner-repo>-<N>` — hyphens in project names — and lines 238-248 run git at the aggregate root) and `dashboard.sh` (lines 337-346 count only `$PROJECT_DIR/worktrees`); hermetic test for issue metadata + dirty state of nested worktrees

## Plan revision 2
**Status**: complete
**When**: 2026-09-15 15:40
**By**: Claude Code Agent (claude-fable-5-1)

Owner chose adapter verbs (design D) over type checks in scripts after a
Sonnet landscape scan found no packaged tool for manifest-subset worktrees
with colcon overlay (nearest: multree, Canopy — generic, no vcs/colcon
awareness). Plan now adds `worktree_repos` + `worktree_env` verbs via new
ADR-0012, a per-worktree `.worktree-repos` manifest read by all five generic
scripts, rollback on partial creation, preflight-all removal, sibling-PR
cleanup rule in `merge_pr.sh`, list/dashboard parsing, `env.sh` ordering
fix, and splits delivery into two PRs. All eight PR #254 review actions
addressed.
