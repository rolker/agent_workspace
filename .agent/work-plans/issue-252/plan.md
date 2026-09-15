# Plan: ros2_colcon adapter phase 3: layer/package worktrees (no symlink fallback)

## Issue

https://github.com/rolker/agent_workspace/issues/252

## Context

`ros2_colcon` adapter (`.agent/project_types/ros2_colcon/adapter.sh`) implements all
10 contract verbs today: `setup`/`sync`/`validate`/`build`/`test`/`install`/`env`/
`project_root`/`repos`/`scope_for_pr`. It hosts a project as ordered layers under
`$(_rc_root)/layers/main/<layer>_ws/src/<pkg>` (each `<pkg>` a separate git checkout
imported by `vcs`), driven by an in-tree manifest (`configs/manifest/layers.txt`,
`repos/<layer>.repos`). `adapter_env`/`adapter_build`/`adapter_test` already do
**runtime chaining** (distro underlay, then each layer's `install/local_setup.bash`
in ascending order) — never baked chains — matching upstream's ADR-0016 fix.
Two hosted instances exist side by side today (`p11-jazzy`, `p11-rolling`), each a
separate `ACTIVE_PROJECT_ROOT` selected via `.agent/scripts/adapter --project <name>`
(#227, #248) — instance scoping is already solved at the adapter layer.

`worktree_create.sh --type project` today git-worktrees a **single** `PROJECT_DIR`
(the legacy `project/` symlink or a registry entry's hosting dir) — see lines 252-298
and 469-480. For `ros2_colcon`, the registered hosting dir (e.g. `p11-jazzy/`) is
**not itself a git repo** — it is a plain directory containing many independent repo
checkouts under `layers/main/*/src/*` plus a `configs/manifest` symlink. `git -C
$PROJECT_DIR rev-parse --git-dir` fails there, so `--type project` cannot work for a
colcon instance today. `worktree_remove.sh` (`_COMMON_DIR`/`git worktree remove`,
lines 247-274) and `merge_pr.sh` (branch delete/sync, lines 389-410) have the same
single-repo assumption and don't loop over multiple package repos.

Upstream (`ros2_agent_workspace/scripts/worktree_create.sh`, lines 860-1032) solves
this with a **hybrid mirror**: `--type layer --layer <l> --packages <a,b>` git-worktrees
only the named packages inside the target layer, then `ln -s` every *other* package in
that layer and every *other* layer wholesale into the worktree, and a generated
`setup.bash` force-prepends the worktree's own build/install paths onto `PYTHONPATH`
(upstream #427) because the symlinked main tree's stale build dir otherwise shadows the
worktree's packages on `sys.path`. Upstream's fallback chain for `git worktree add`
swallows stderr (`2>/dev/null`) at every attempt and, on total failure, silently
`ln -s`'s the **real package clone** into the worktree and reports success
(`ros2_agent_workspace#598`) — a dispatched agent then switched the main clone's
branch through the symlink. `ros2_agent_workspace` ADR-0016 (runtime vs. baked layer
chaining) independently establishes that sourcing each layer's `local_setup.bash` in
ascending order, never a baked `install/setup.bash`, is the only chaining mechanism
that doesn't invert overlay precedence or go stale — the same discipline this repo's
`adapter_env`/`adapter_build` already follow.

## Design comparison (required by the issue)

| | A. Hybrid mirror | B. Pure overlay |
|---|---|---|
| Dependents workflow | Untouched siblings resolve via symlink into main automatically; a dependent can be rebuilt in place without re-listing it | Untouched siblings resolve via the hosted instance's already-built layer *install* (normal colcon underlay); rebuilding a dependent needs it named explicitly (`--package-repos a,b`) |
| Build reuse / rebuild cost | Reuses main's builds for everything not named; still full per-worktree symlink tree to construct/maintain | Reuses main's builds identically (via install, not source symlink); worktree build only ever touches named packages — smaller `colcon build` scope |
| Scoping to a hosted instance | Already solved at `_rc_root`/`ACTIVE_PROJECT_ROOT`; no difference | Same — no difference |
| Path/env bug classes invited | Reintroduces upstream's exact classes: `sys.path`/`PYTHONPATH` shadowing from symlinked main builds (#427), and the symlink-fallback-on-failure hazard (#598) is structurally tempting because the "else branch" for non-git paths sits right next to a large mirrored tree | No mirrored tree exists, so there is nothing to fall back to *by construction*; only genuine git-repo worktrees are ever created |
| What `sync`/`validate`/`build`/`test` must do from inside a worktree | Need new logic to distinguish "this is a symlink to main, skip" from "this is a real worktree, act" in every verb that walks the layer tree | No adapter verb needs to run inside the worktree at all — a small generated `build.sh`/`test.sh` (analogous to upstream's, minus the force-prepend hack) sources the hosting instance's lower-layer + same-layer installs as an underlay and builds only the overlaid `src/` |
| Implementation size | Large: worktree_create.sh layer/package branch, full symlink-tree generation, generated setup.bash with path force-prepend, and remove/merge_pr changes to skip symlinked entries | Medium: worktree_create.sh layer/package branch using existing `adapter repos` to resolve paths, small generated build/test wrapper, remove/merge_pr changes (loop over named package repos only — no symlinks to skip) |

## Recommendation

**Design B (pure overlay).** The adapter already does runtime layer chaining
(`.agent/project_types/ros2_colcon/adapter.sh` `adapter_env`/`adapter_build`,
lines 391-476) exactly the way ADR-0016 mandates — sourcing each layer's
`local_setup.bash` in ascending order, never a baked chain. Colcon's own overlay
semantics (source the hosted instance's target-layer `install/local_setup.bash` as an
underlay, then build only the named packages in the worktree's own `src/`, then source
*its* `install/local_setup.bash` last) reproduce the "reuse untouched siblings' builds"
benefit of Design A's symlink tree without ever needing a symlink into the main
checkout. That means the entire class of bugs the issue calls out — #427 (stale main
build dir shadowing the worktree on `sys.path`, which only exists because A symlinks
source trees) and #598 (silent symlink fallback on `git worktree add` failure) — has
no surface to appear on: no path in this design is ever a "symlink to main" that a
verb must special-case, only real git-repo worktrees of the named package(s). This
also keeps the change medium-sized (`worktree_create.sh` gains one new branch reusing
the existing `adapter repos` verb output, not a new symlink-tree generator), matching
"Only what's needed." **The no-symlink hard-stop rule (issue body, `docs/PRINCIPLES.md`
"Enforcement over documentation") is satisfied structurally**: Design B never
constructs a path where a non-git-repo fallback branch could be reached for a package
worktree, so the rule doesn't need a runtime check protecting a mirror step — it needs
only the ordinary `git worktree add` failure handling (capture stderr, hard-stop, never
`ln -s` a git repo), which the plan still implements explicitly since a target package
directory could theoretically be non-git if the manifest is malformed.

## Approach

0. **Prerequisite: #255** renames the worktree scripts' project selector from
   `--repo <name>` to `--project <name>` (alias kept). This plan is written against
   `--project`.
1. **`worktree_create.sh` CLI — explicit, nothing inferred** (decided 2026-09-15;
   upstream's #526 wrong-repo pick came from resolving a bare issue number):

   ```
   worktree_create.sh --type project --project p11-jazzy \
       --issue rolker/cube_bathymetry#111 \
       --layer platforms --package-repos cube_bathymetry,marine_msgs
   ```

   - Valid only when the `--project` registry entry's adapter type is `ros2_colcon`
     (look up via `_project_registry.sh`); for that type all three of `--issue`
     (qualified), `--layer`, `--package-repos` are **required** and the plain
     single-repo branch (lines 469-480) is skipped.
   - `--issue` **must** be `owner/repo#N` for package worktrees. A bare number is a
     usage error, never a guess. The owning repo comes from the reference.
   - `--layer` is required and validated: every listed repo must live in that layer;
     otherwise hard error naming the layer each was actually found in.
   - `--package-repos` takes package-repo directory names (what `adapter repos`
     prints), validated against that verb's output; unknown names are a hard error.
     Named `--package-repos`, not upstream's `--packages`, because the values are
     repos, not ROS package names (a documented confusion upstream).
   - `--type layer` is rejected with a message pointing at this form.
   - Worktree directory: `worktrees/project/<project>/issue-<project>-<owner-repo>-<N>/`
     so two package repos' issue N never collide on disk. `worktree_enter.sh`,
     `worktree_remove.sh`, `merge_pr.sh` take the same qualified `--issue` and refuse a
     bare number for this shape.
2. Resolve target package paths by calling
   `.agent/scripts/adapter --project <name> repos` (existing verb, `adapter_repos` in
   `ros2_colcon/adapter.sh` line 618) and matching requested names against the
   `name:path` output — reuses the manifest-walking logic already tested, no duplicate
   path construction in `worktree_create.sh`.
3. For each resolved package path: run the **existing** branch-resolution waterfall
   (local branch → remote branch → parent branch → new branch) into
   `<worktree>/<layer>_ws/src/<repo>/`, capturing stderr at every attempt (drop
   `2>/dev/null`). On total failure: print the collected stderr and hard-stop
   (`exit 1`) — never `ln -s`. Verify with `git -C <path> rev-parse --git-dir` before
   attempting (a manifest entry that resolves to a non-git path is a manifest bug, not
   a fallback case — hard-stop with a distinct error, still no symlink).
   **Branch names** (decided 2026-09-15, option 2): the owning repo gets
   `feature/issue-<N>`; every other repo in the worktree gets
   `feature/<owner-repo>-issue-<N>` (e.g. `feature/cube_bathymetry-issue-111` in
   `marine_msgs`) so it can never collide with that repo's own issue N, and its PR body
   references the issue as `owner/repo#N`. `merge_pr.sh` cleanup loops per repo and
   knows both forms.
4. Generate `<layer>_ws/build.sh` and `<layer>_ws/test.sh` in the worktree (small,
   ros2_colcon-specific templates, not a new adapter verb per ADR-0011's
   "differs-per-type AND the workflow needs it" test — this is worktree-internal
   tooling, analogous to upstream's generated scripts): source the distro underlay
   (reuse `_rc_underlay`/`_rc_ros_root` logic from the hosted instance's config),
   source every layer **below** the target layer's `install/local_setup.bash` from the
   hosted instance in `layers.txt` order, source the hosted instance's **same-layer**
   `install/local_setup.bash` as the underlay for untouched siblings, run
   `colcon build`/`colcon test` scoped to the worktree's own `<layer>_ws` (only the
   named packages exist in its `src/`), then source the worktree's own
   `install/local_setup.bash` last so it outranks the hosted instance's same-layer
   install — canonical colcon overlay precedence, no force-prepend hack needed.
5. **`worktree_remove.sh`**: extend the "determine which git repo owns this worktree"
   block (lines 247-274) — when the worktree dir contains `<layer>_ws/src/*` package
   subdirectories (ros2_colcon shape) instead of being itself a worktree of one repo,
   loop `git -C <pkg_dir> worktree remove` per package, then `worktree prune` each
   package's origin repo.
6. **`merge_pr.sh`**: extend the branch-delete/sync block (lines 389-410) similarly —
   when the merged worktree is ros2_colcon-shaped, loop branch delete + `pull --ff-only`
   over each package repo instead of assuming one `project/` repo.
7. **Smoke test on `p11-jazzy` only** (decided 2026-09-15: `p11-rolling` is not yet
   buildable): create a package worktree for one real package,
   run the generated `build.sh` (expect a real, not no-op, colcon build against that
   package's `src/`), confirm the hosted instance's install is untouched, then
   `worktree_remove.sh` and confirm the package repo's main checkout is unaffected.
8. **Hermetic script test** in `.agent/scripts/tests/test_ros2_colcon.sh` (extends the
   existing suite, ~903 lines): success path (fake layer with two fake git package
   repos, worktree one, assert the other is untouched and NOT symlinked, assert
   generated build.sh sources things in the right order); forced-failure path (make
   `git worktree add` fail for the target repo — e.g. lock the repo or pass a
   colliding branch — assert hard-stop, stderr is printed, and `[ -L path ]` is false).
9. **`docs/ROADMAP.md`** row 6: update to "Phase 3 done" with a one-line summary, note
   remaining steps 4/7 + retiring `ros2_agent_workspace`.
10. **`.agent/WORKTREE_GUIDE.md`**: add a "ros2_colcon package worktrees" subsection
    documenting the qualified `--issue`, `--layer`, `--package-repos`, the branch
    naming for non-owning repos, the generated `build.sh`/`test.sh`, and that the
    no-symlink rule holds structurally under this design. **`AGENTS.md` is not touched
    by this PR** (decided 2026-09-15): its worktree section stays type-agnostic; the
    script's usage error names the required flags and points at the guide, and the
    per-project `CLAUDE.md` from #172 step 5 will carry the reminder once it exists.

## Files to Change

| File | Change |
|---|---|
| `.agent/scripts/worktree_create.sh` | Add qualified `--issue owner/repo#N`, `--layer`, `--package-repos`; reject `--type layer` and bare issue numbers for this shape; ros2_colcon branch: resolve via `adapter repos`, per-repo worktree-add with captured stderr and hard-stop, owning/non-owning branch names, generate `build.sh`/`test.sh` |
| `.agent/scripts/worktree_enter.sh` | Accept the qualified `--issue` form and the `issue-<project>-<owner-repo>-<N>` directory name |
| `.agent/scripts/worktree_remove.sh` | Same qualified `--issue`; detect ros2_colcon-shaped worktree; loop per-repo `git worktree remove` + prune |
| `.agent/scripts/merge_pr.sh` | Loop per-repo branch delete (both branch-name forms) + sync for ros2_colcon-shaped worktrees |
| `.agent/scripts/tests/test_ros2_colcon.sh` | New cases: package worktree success path, forced-failure hard-stop (no symlink) |
| `docs/ROADMAP.md` | Row 6: phase 3 done |
| `.agent/WORKTREE_GUIDE.md` | New subsection on package worktrees for ros2_colcon |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Hard-stop with full stderr on worktree-add failure — no silent fallback; generated scripts print what they source before running |
| Enforcement over documentation | No-symlink rule is structural (Design B), plus an explicit `rev-parse --git-dir` check before any worktree-add attempt, backed by the hermetic forced-failure test |
| Capture decisions, not just implementations | This plan's design comparison and recommendation stand as the record; no separate ADR needed unless the adapter contract itself changes (see ADR Compliance) |
| A change includes its consequences | worktree_remove.sh, merge_pr.sh, ROADMAP.md, WORKTREE_GUIDE.md all included, not deferred |
| Only what's needed | No new contract verb; generated build/test scripts instead of a symlink-tree generator |
| Improve incrementally | Builds on phases 1/2/4 (#235/#237/#248) already merged; doesn't touch single_project |
| Test what breaks | Forced-failure path is the regression that matters (#598-class bug); prioritized over coverage padding |
| Workspace vs. project separation | ros2_colcon-specific logic stays behind the adapter/registry type check in the generic scripts, mirroring how `--repo` already branches generically |
| Primary framework first, portability where free | Bash scripts remain framework-agnostic; no Claude-specific behavior added |
| The workspace serves the product | This unblocks real per-issue package isolation on the hosted `p11-jazzy`/`p11-rolling` instances, not speculative tooling |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0002 (worktree isolation) | Yes — this *is* worktree isolation for a new shape | Package worktrees, never branch-switching the main checkout |
| ADR-0004/0005 (enforcement hierarchy) | Yes — no-symlink rule needs mechanical enforcement | Hermetic test's forced-failure case is the mechanical check; no hook exists (or is needed) since Design B has no code path to guard beyond the explicit `rev-parse` check |
| ADR-0011 (adapter contract) | Yes — this is adapter-adjacent work | **No new contract verb.** Everything needed (`repos` for path resolution) already exists; the generated build/test scripts are worktree-internal tooling, not a dispatcher-visible verb, so this is not a contract change and needs no ADR addendum (ADR-0008) or supersession. `validate_adapter.sh` is unaffected — confirm it still passes after this change |
| ADR-0016 equivalent (this repo has no numbered peer — runtime chaining is embedded directly in `adapter_env`/`adapter_build`) | Yes — generated `build.sh`/`test.sh` must chain the same way | Followed explicitly in step 4: `local_setup.bash` sourcing only, ascending order, no baked `install/setup.bash` |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `worktree_create.sh` CLI surface (`--issue owner/repo#N`, `--layer`, `--package-repos`) | `.agent/WORKTREE_GUIDE.md`; `/start-task` SKILL.md argument-compatibility note | WORKTREE_GUIDE.md yes; start-task note yes (one line); AGENTS.md deliberately not (see step 10) |
| Worktree directory / branch naming for package worktrees | `worktree_list.sh` output, `dashboard.sh` worktree listing | Verify both still list the new directory shape correctly; include in the smoke test |
| `worktree_remove.sh`/`merge_pr.sh` cleanup logic | `.agent/scripts/tests/` for those scripts if such tests exist | Checked: no `test_worktree_remove.sh`/`test_merge_pr.sh` exist today (only `test_ros2_colcon.sh`/`test_adapter.sh`); out of scope to add net-new test scaffolding for scripts that have none — flagged as a pre-existing gap, not created here |
| ROADMAP.md row 6 | Roadmap phase tracking for steps 4/7 | Yes, row updated; steps 4/7 remain open in the row text |

## Decisions (resolved 2026-09-15 with the owner)

- **AGENTS.md untouched**; documentation goes in `WORKTREE_GUIDE.md` plus a
  self-explanatory usage error. Per-project `CLAUDE.md` (#172 step 5) later.
- **Smoke test on `p11-jazzy` only**; `p11-rolling` is not buildable yet.
- **CLI is explicit, nothing inferred**: `--type project` (no `--type layer`),
  qualified `--issue owner/repo#N`, required `--layer`, `--package-repos` validated
  against `adapter repos`. Rationale: upstream #526 (bare issue number resolved to the
  wrong repo). Depends on #255 (`--repo` → `--project`).
- **Non-owning repos get `feature/<owner-repo>-issue-<N>`** to avoid branch collisions.

## Open Questions

- None blocking. Implementation detail to settle during coding: whether
  `worktree_enter.sh --print-path` for this shape should also accept the directory
  name directly, for dispatchers that already know it.

## Estimated Scope

Single PR. The change set (worktree_create.sh branch, worktree_remove.sh/merge_pr.sh
loops, one generated-script template, hermetic tests, smoke test, two doc updates) is
cohesive and none of the pieces are independently mergeable — a partial version (e.g.
create without remove/merge_pr cleanup) would leave orphaned package worktrees.
