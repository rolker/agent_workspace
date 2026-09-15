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

## Plan Review
**Status**: complete
**When**: 2026-09-15 16:20
**By**: Claude Code Agent (claude-sonnet-5)

Reviewed `.agent/work-plans/issue-252/plan.md` directly (not PR #254's body)
per `/review-plan`. Every cited source line was checked against the live
files: `.agent/scripts/adapter` (10-verb `REQUIRED_VERBS`, `--project`
resolution), `worktree_create.sh` (469-493 branch-resolution waterfall),
`worktree_remove.sh` (228-240 dirty check, 247-274 removal), `merge_pr.sh`
(130-268 PR lookup/issue parsing, 389-410 cleanup), `worktree_list.sh`
(115-126 directory regex, 238-248 per-worktree `git status`),
`dashboard.sh` (337-346 count), and `ros2_colcon/adapter.sh` (452 scrub,
471-473/488-490 ascending local_setup.bash chaining, 618 `adapter_repos`
manifest walk). All held exactly as cited — no fabricated or stale line
references found. Design comparisons 1 and 2, the ADR-0008 supersession
analysis for ADR-0012, and the acceptance-criteria coverage (hard-stop
w/ captured stderr, no symlink fallback, hermetic + p11-jazzy smoke tests,
ROADMAP row 6) are all sound and traceable to source.

### Findings

1. **Consequences** — The plan's own Consequences table lists "ADR-0011
   status line" as a required update for the adapter-contract change, but
   Approach step 11 and the Files to Change table never carry that action
   forward — only the new `docs/decisions/0012-…md` file is listed. Without
   an explicit cross-reference addendum (permitted under ADR-0008) on
   ADR-0011, its "10-verb contract" table goes stale the moment
   `worktree_repos`/`worktree_env` land. Add it as an explicit step-11/
   Files-to-Change item.
2. **Consequences / ADR compliance** — `.agent/knowledge/principles_review_guide.md`
   still states "the 10-verb contract" (line 37) and its own Consequences
   Map requires "An ADR in `docs/decisions/`" to update "This review
   guide's ADR table." Neither the plan's Consequences table nor Files to
   Change mentions this file at all. Needs an explicit action to update the
   verb count and add an ADR-0012 row.
3. **File targeting / Only what's needed** — `.agent/scripts/_worktree_helpers.sh`
   already defines `wt_layer_branch` and `wt_layer_is_dirty` (from #25);
   grep across the repo shows zero callers anywhere — dead code. Both
   functions walk `*_ws` directories and explicitly skip symlinked
   layers/packages, i.e. they encode Design A's hybrid-mirror layout that
   this plan's chosen Design B (pure overlay, no symlinks) structurally
   rejects. The plan's Files-to-Change entry for this file only adds a
   `.worktree-repos` reader; it doesn't address these now-contradictory,
   unused functions. Recommend removing them in the same PR (or recording
   why they're kept) rather than leaving two competing layout conventions
   in one helper file.
4. **File targeting / Consequences** — Step 7's `issue-<project>-<owner-repo>-<N>`
   directory-name parsing for `worktree_list.sh`/`dashboard.sh` is
   ambiguous by regex alone: project names, owner names, and repo names can
   all contain hyphens (the plan's own rationale for why today's regex
   fails). `.agent/scripts/_project_registry.sh` already exposes
   `registry_names`/`registry_lookup`, which could resolve the leading
   `<project>` segment against the known registry before splitting the
   remainder into `<owner-repo>` and `<N>`. The plan doesn't specify this
   (or any) disambiguation mechanism — worth naming explicitly before
   implementation rather than improvising a regex under review pressure.

### Summary

The plan is well-verified against source (no bad line references found)
and the design/ADR reasoning holds up. It has four specific, fixable gaps
in consequence-completeness and dead-code cleanup — none block starting
implementation, but items 1-2 should be folded into step 11/Files-to-Change
and item 3 into the `_worktree_helpers.sh` change before this is called
done, to avoid a second review round-trip.

### Recommended Actions

- [ ] Add "ADR-0011 status line cross-reference to ADR-0012" as an explicit
      action in Approach step 11 and Files to Change.
- [x] Add `.agent/knowledge/principles_review_guide.md` (verb count +
      ADR-0012 row) to Files to Change.
- [ ] Decide on and record disposition of `wt_layer_branch`/`wt_layer_is_dirty`
      (remove as dead/superseded, or state why kept) in the
      `_worktree_helpers.sh` Files-to-Change entry.
- [ ] Specify the disambiguation mechanism for parsing
      `issue-<project>-<owner-repo>-<N>` in `worktree_list.sh`/`dashboard.sh`
      (e.g. registry-first segment resolution) before coding step 7.

## Plan revision 3
**Status**: complete
**When**: 2026-09-15 16:05
**By**: Claude Code Agent (claude-fable-5-1)

All four plan-review actions folded in: ADR-0011 status addendum and
principles_review_guide.md added to scope; dead `wt_layer_branch`/
`wt_layer_is_dirty` removed in PR 1; `.worktree-repos` gains a header carrying
project/issue/layer so directory names are never parsed for this shape.
