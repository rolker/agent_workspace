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

## Implement (PR 1)
**Status**: complete
**When**: 2026-09-15 (implementation session)
**By**: Claude Code Agent (claude-sonnet-5)

Implemented Approach steps 1-5 and 7-11 (step 6, `merge_pr.sh`, is PR 2 —
untouched). Merged `origin/main` first to pick up #255 (`--repo` → `--project`
rename), since the plan's CLI examples assume it landed.

**Landed as designed:**
- `worktree_repos`/`worktree_env` adapter verbs (`REQUIRED_VERBS` → 12) on both
  `single_project` and `ros2_colcon`; `validate_adapter.sh` passes; both
  verbs covered on both types in `test_adapter.sh`/`test_ros2_colcon.sh`.
- ADR-0012 (new); ADR-0011 gets the Status/References cross-reference
  addendum; `principles_review_guide.md` and `ARCHITECTURE.md` updated from
  "10-verb" to "12-verb".
- `.worktree-repos` manifest writer/reader + legacy fallback in
  `_worktree_helpers.sh`; `wt_layer_branch`/`wt_layer_is_dirty` removed
  (confirmed zero callers via grep before deleting).
- `worktree_create.sh`: qualified `--issue owner/repo#N`, `--layer`,
  `--package-repos`; `--type layer` rejected with a pointer to the new form;
  branch-resolution waterfall factored into `_wt_add_repo` (captures every
  attempt's stderr); loops over `worktree_repos` output for **every**
  `--type project` worktree (not just package worktrees) — `single_project`'s
  one-entry manifest reproduces today's single-repo behavior exactly, verified
  by the existing `test_project_registry.sh` worktree-create suite unchanged
  and passing. `rev-parse --git-dir` check before each add; on failure, prints
  collected stderr, rolls back every entry already added, deletes the
  aggregate dir, exits 1 — never `ln -s`. Writes `.worktree-repos`; generates
  `env.sh`/`build.sh`/`test.sh` when `worktree_env` has output (`test.sh`
  re-sources `env.sh` after building).
- `worktree_remove.sh`: preflights every manifest entry's `git status
  --porcelain` before removing any (unless `--force`); removes each from its
  own owning repo (resolved via that entry's `git-common-dir`, not the
  manifest's stored origin path); aggregate dir last.
- `worktree_list.sh`/`dashboard.sh`: manifest header/entries when present
  (aggregate dirty = any entry dirty, changed-file counts summed); directory
  regex stays legacy-only; dashboard counts `worktrees/project/*/*`.
- Hermetic tests: real (git-backed) package-worktree create/remove/list
  integration tests in `test_ros2_colcon.sh` — create success (named package
  worktreed, sibling untouched and not a symlink, env.sh sourcing order,
  manifest written), second-repo failure rolls back the first with no
  aggregate dir left and stderr surfaced, multi-package dirty removal refuses
  before touching anything, `worktree_list.sh --json` reporting for a nested
  worktree. These tests found and fixed two real bugs:
  (1) `adapter_worktree_repos`'s git-repo check used `rev-parse --git-dir`,
  which walks up to an ancestor's `.git` when the package dir has none of its
  own — fixed to compare `rev-parse --show-toplevel` against the package dir;
  (2) `worktree_list.sh` read the manifest header via `wt_read_manifest`'s
  side-effect globals inside a `$(...)` subshell, losing them — fixed to
  parse the header directly.
- Docs: `.agent/WORKTREE_GUIDE.md` package-worktree subsection;
  `docs/ROADMAP.md` row 6 (phase 3 done in PR 1 terms); `/start-task`
  SKILL.md's argument-compatibility note.
- `plan.md` synced inline: branch-naming wording for non-owning repos
  clarified to match what was actually built (`feature/<repo>-issue-<N>`,
  repo name only — the plan's prose was ambiguous about whether "owner-repo"
  meant the joined form; the worked example always meant repo-only); step 5
  annotated with what "qualified `--issue` resolution" actually means in PR 1
  (numeric-suffix matching via the existing glob, not full manifest-header
  disambiguation across multiple candidates).

**Deferred / left as a known gap:**
- Full manifest-header-based worktree resolution in `worktree_enter.sh`/
  `worktree_remove.sh` when multiple candidates share a trailing issue number
  under one repo slug — the pre-existing "Multiple worktrees found, use
  `--repo-slug`" path still applies instead. Not expected to matter in
  practice (the qualified issue ref is unique per repo slug in the intended
  workflow) but is a real gap versus the plan's original phrasing.
- The real `p11-jazzy` smoke test (plan step 10) — explicitly out of scope
  for the implementer; left for the reviewer.
- `merge_pr.sh` multi-repo resolution and the sibling-PR cleanup rule (plan
  step 6) — PR 2, untouched here.

**Verification:** `validate_adapter.sh` passes (12/12 verbs, both types);
`test_adapter.sh` 86/86; `test_ros2_colcon.sh` 142/142; `test_project_registry.sh`
54/54 (unchanged, still passing against the rewritten `worktree_create.sh`);
`pre-commit run --all-files` passes.
