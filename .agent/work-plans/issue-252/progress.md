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

**Deferred:**
- The real `p11-jazzy` smoke test (plan step 10) — explicitly out of scope
  for the implementer; left for the reviewer.
- `merge_pr.sh` multi-repo resolution and the sibling-PR cleanup rule (plan
  step 6) — PR 2, untouched here.

(The manifest-header worktree-resolution gap noted above and in the initial
Implement entry is closed — see the "Post-review fixes" entry below.)

**Verification:** `validate_adapter.sh` passes (12/12 verbs, both types);
`test_adapter.sh` 86/86; `test_ros2_colcon.sh` 142/142; `test_project_registry.sh`
54/54 (unchanged, still passing against the rewritten `worktree_create.sh`);
`pre-commit run --all-files` passes.

## Post-review fixes (PR 1)
**Status**: complete
**When**: 2026-09-15 (post-review session)
**By**: Claude Code Agent (claude-sonnet-5)

Reviewer found three defects in PR 1. Each fixed as its own commit with a
regression test:

1. **`env.sh` generation-time snapshot** — `adapter_worktree_env`'s
   `[ -f ... ]` guard ran at *generation* time (worktree-create, before any
   build), so a not-yet-built install line was permanently omitted from
   `env.sh`'s text — `test.sh`'s "re-source `env.sh` after building" never
   actually picked up the fresh overlay, since the source line for it was
   never written. Fixed: every conditional source is now emitted as a
   runtime-guarded line (`[ -f <path> ] && source <path>`, `%q`-quoted) for
   both the hosted-instance layer installs and the worktree's own install.
   New test: generate `env.sh` before the worktree's own install exists,
   then create it with a stub `local_setup.bash` that sets a marker,
   re-source the *same* (unregenerated) `env.sh`, assert the marker is set.
2. **`.worktree-repos` written into single-repo checkouts** — every
   `--type project` worktree got a `.worktree-repos` file, including
   `single_project`'s one-entry ("." rel path) shape, where the worktree
   root *is* the tracked repo checkout — a permanent untracked file (or an
   accidental commit) in every single-repo project worktree.
   `wt_read_manifest`'s legacy fallback already reconstructs that exact
   shape with no file, so the fix is simply not writing it when there's
   exactly one entry with rel path ".". New test in
   `test_project_registry.sh`: create a `single_project` worktree, assert
   no `.worktree-repos` and an empty `git status --porcelain`.
3. **Bare-number disambiguation defeated the explicit-CLI decision** —
   `worktree_enter.sh`/`worktree_remove.sh` reduced a qualified `--issue
   owner/repo#N` to its numeric suffix before lookup, so two package
   worktrees for the same issue number in different sibling repos under one
   project were ambiguous, and the error suggested `--repo-slug`, which
   cannot disambiguate sibling package repos within the same project (it
   only disambiguates different registered projects). Fixed: a new
   `find_worktree_by_issue` (`_worktree_helpers.sh`) matches a qualified ref
   against each glob candidate's `.worktree-repos` header `issue=` field
   exactly (never by directory name/trailing number alone for a qualified
   ref); a bare number that still matches more than one candidate now names
   the qualified `--issue owner/repo#N` form for each, instead of
   `--repo-slug`, whenever any candidate carries a manifest. `plan.md` step
   5 updated — the disambiguation gap it called out is now closed. New
   test: two fake package worktrees for the same issue number in different
   repos; qualified `--issue` resolves each via `--print-path`; the bare
   number errors and names both qualified refs.

**Verification (post-fix):** `validate_adapter.sh` 12/12 both types;
`test_adapter.sh` 86/86; `test_ros2_colcon.sh` 156/156; `test_project_registry.sh`
57/57; `pre-commit run --all-files` clean.

## Smoke Test (plan step 10)
**Status**: complete
**When**: 2026-09-15 18:30
**By**: Claude Code Agent (claude-fable-5-1)

Real `p11-jazzy` instance, package worktree for `rolker/ros2_network_monitor#27`
(layer `sensors`). Three rounds; rounds 1-2 found five defects that the hermetic
suites could not (wrong-repo issue lookup, no rollback after a post-add failure,
`env.sh` last-line status aborting `build.sh` under `set -e`, banner printing the
ambiguous bare-number form, colcon override warning). All fixed with regression
tests. Round 3, scripts as generated: `build.sh` exit 0 (3 packages, no override
warning), `test.sh` exit 0 (107 tests, 0 failures), hosted `sensors_ws/install`
byte-for-byte unchanged, `ros2 pkg prefix` resolves to the worktree overlay, zero
symlinks, `worktree_list.sh` reports the nested worktree, `worktree_remove.sh`
leaves the package repo with one worktree on `jazzy` and clean. Reviewer verdict:
PR 1 ready. `merge_pr.sh` (plan step 6) follows as PR 2.

## Implement (PR 2)
**Status**: complete
**When**: 2026-09-15 (implementation session)
**By**: Claude Code Agent (claude-sonnet-5)

Implemented plan step 6 (`merge_pr.sh` multi-repo resolution + sibling-PR
cleanup rule) — the remaining piece before closing #252.

**Landed as designed:**
- `--repo owner/repo` flag, and an equivalent qualified `--pr owner/repo#N`
  ref (conflicting `--repo`/qualified-ref values are a usage error); when
  given, `query_pr` is called against exactly that repo and the whole
  workspace/`project/` two-remote auto-detection block is skipped. Without
  it, behavior is byte-for-byte the pre-PR-2 script.
- Issue-number extraction now accepts both `feature/issue-<N>` and
  `feature/<repo>-issue-<N>` (one combined regex with an optional
  `<repo>-` prefix group; verified against every branch shape the old
  single-pattern regex matched, so this is a pure addition, not a
  behavior change for existing branches).
- Manifest-driven worktree lookup: scans
  `worktrees/project/*/*/.worktree-repos`, resolving each entry's owning
  repo via `git remote get-url origin` + `extract_gh_slug` and matching
  against the merged PR's repo + branch — never parses a directory name.
  A miss (no manifest matches) falls through unchanged to the existing
  `find_worktree_for_branch` path for legacy/single-repo/workspace PRs.
- Sibling-PR cleanup rule: after merge, checks every *other* manifest
  entry's repo for an open PR on its branch (`gh pr list -R <repo> --head
  <branch> --state open`); if any is open, the worktree is kept and the
  blocking repo(s)/branch(es) are printed; only when none are open does
  `worktree_remove.sh --issue <qualified> --type project --project <name>`
  (values read from the manifest header, never guessed) actually run.
- Roadmap update is skipped for a package-repo PR with a one-line note
  (the roadmap lives in this repo, not the package repo); unchanged for
  workspace/project-repo PRs.
- `Makefile`'s `merge-pr` target passes through `PR=owner/repo#N` and a new
  `REPO=owner/repo` variable (`#` in a `make` command-line assignment does
  not need escaping — verified with a throwaway Makefile before relying on
  it).

**Deviation from plan step 6 (and why):** the plan's phrasing — "delete the
merged branch in its own repo and sync that repo" — describes it as
unconditional. Implemented as written, this fails every time: the merged
repo's local branch is still checked out in the (not-yet-removed) package
worktree entry at the point the merge completes, and `git branch -d` refuses
to delete a branch checked out in *any* worktree (linked or main), not just
the current one. Writing it exactly as specified would make every local
branch delete a silent no-op until some later, unrelated `merge_pr.sh` run
happened to remove that worktree for other reasons — a real cleanup gap, not
a cosmetic one. Fixed by sequencing: the *remote* branch delete and the own
repo's `pull --ff-only` still run unconditionally right after the merge
(neither needs the branch to be free of a local checkout); the *local*
branch delete is deferred until immediately after `worktree_remove.sh`
succeeds, which is only reached in the no-sibling-PR-open case — exactly the
case where the branch has actually been freed. When a sibling PR keeps the
worktree, the local branch correctly stays too, since that checkout is still
live.

**Tests:** new `.agent/scripts/tests/test_merge_pr.sh` (27 cases, all
passing) — the plan noted no merge_pr suite existed; a dedicated file was
cleaner than extending `test_ros2_colcon.sh`'s adapter-focused fixtures with
merge-specific `gh` stubbing. Covers: qualified-`--pr`-ref resolution finds
the package worktree by manifest and queries only that repo; the
`feature/<repo>-issue-N` branch form extracts the issue number; an open
sibling PR keeps the worktree and names the blocker (and leaves the merged
repo's local branch untouched, since it's still checked out); `--repo
owner/repo --pr N` behaves identically to the qualified-ref form; a
conflicting `--repo`/qualified-`--pr` combination is a usage error (exit 2);
and two regression cases — a legacy workspace PR and a legacy single-repo
`project/` PR (neither has a `.worktree-repos` manifest) — resolve and clean
up exactly as before PR 2. `gh` is replaced by a fixture-driven stub (no
network, no auth); `git pull --ff-only` in the legacy sync step is made to
succeed offline by pointing each sandbox repo's `origin` at a local bare
clone instead of a real GitHub URL.

**Verification:** `test_merge_pr.sh` 27/27; `test_ros2_colcon.sh` 179/179
(unchanged, still passing); `test_adapter.sh` 86/86; `test_project_registry.sh`
57/57; `test_merge_pr_root_resolution.sh` 5/5 (unchanged); `validate_adapter.sh`
12/12 both types; `pre-commit run --all-files` clean.

**Undone:** nothing from plan step 6. `test_merge_pr.sh` is not wired into
`.github/workflows/validate.yml` — consistent with the workspace's existing
convention, where several other test files under `.agent/scripts/tests/`
(e.g. `test_merge_pr_root_resolution.sh`, `test_gh_create_pr.sh`) are also
not CI-wired; only `test_adapter.sh`, `test_project_registry.sh`, and
`test_ros2_colcon.sh` currently run in CI. Not changed here since it wasn't
asked for and is a workspace-wide convention question, not specific to this
issue.
