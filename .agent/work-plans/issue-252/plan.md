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
**runtime chaining** (scrub `COLCON_PREFIX_PATH`/`AMENT_PREFIX_PATH`/
`CMAKE_PREFIX_PATH`/`AMENT_CURRENT_PREFIX`, source the distro underlay, then each
layer's `install/local_setup.bash` in ascending order) — never baked chains — matching
upstream's ADR-0016 fix. Two hosted instances exist side by side today (`p11-jazzy`,
`p11-rolling`), each a separate `ACTIVE_PROJECT_ROOT` selected via
`.agent/scripts/adapter --project <name>` (#227, #248).

**The single-repo assumption lives in five generic scripts, not one.** A project
worktree today is exactly one `git worktree add` against one repo, and that is baked
into `worktree_create.sh` (lines 469-493), `worktree_remove.sh` (dirty check at
228-240 and removal at 247-274), `merge_pr.sh` (PR lookup against only the workspace
and `project/` remotes at 130-285, `feature/issue-N` parsing, cleanup at 389-410),
`worktree_list.sh` (directory-name regex at 118-125, `git status` at the worktree root
at 238-248) and `dashboard.sh` (count at 337-346). For `ros2_colcon` the registered
hosting dir (e.g. `p11-jazzy/`) is not itself a git repo, so `--type project` cannot
work for a colcon instance at all today.

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
branch through the symlink.

**Existing-tool scan (2026-09-15).** Nothing packaged does "subset of a multi-repo
manifest → git worktrees → colcon overlay on an already-built install → cleanup".
Nearest generic tools (multree, Canopy) orchestrate worktree sets from their own
manifests with no vcstool/colcon awareness; vcstool's 2025 rewrite has no worktree
subcommand; Zephyr `west` has only an unimplemented proposal. `vcs` remains the right
engine for manifest reading and multi-repo status; the aggregate worktree and the
policy around it are ours to build.

## Design comparison 1 — worktree layout (required by the issue)

| | A. Hybrid mirror | B. Pure overlay |
|---|---|---|
| Dependents workflow | Untouched siblings resolve via symlink into main automatically; a dependent can be rebuilt in place without re-listing it | Untouched siblings resolve via the hosted instance's already-built layer *install* (normal colcon underlay); rebuilding a dependent needs it named explicitly (`--package-repos a,b`) |
| Build reuse / rebuild cost | Reuses main's builds for everything not named; still full per-worktree symlink tree to construct/maintain | Reuses main's builds identically (via install, not source symlink); worktree build only ever touches named packages — smaller `colcon build` scope |
| Scoping to a hosted instance | Already solved at `_rc_root`/`ACTIVE_PROJECT_ROOT`; no difference | Same — no difference |
| Path/env bug classes invited | Reintroduces upstream's exact classes: `sys.path`/`PYTHONPATH` shadowing from symlinked main builds (#427), and the symlink-fallback-on-failure hazard (#598) is structurally tempting because the "else branch" for non-git paths sits right next to a large mirrored tree | No mirrored tree exists, so there is nothing to fall back to *by construction*; only genuine git-repo worktrees are ever created |
| What `sync`/`validate`/`build`/`test` must do from inside a worktree | Need new logic to distinguish "this is a symlink to main, skip" from "this is a real worktree, act" in every verb that walks the layer tree | No adapter verb needs to run inside the worktree; a generated `env.sh` sources the hosting instance's lower-layer + same-layer installs as an underlay and the worktree builds only its own `src/` |
| Implementation size | Large: symlink-tree generation, generated setup.bash with path force-prepend, remove/merge_pr changes to skip symlinked entries | Medium: per-repo worktree loop, small generated env/build/test wrappers, cleanup loops over named package repos only |

**Chosen: B.** Colcon's own overlay semantics reproduce A's "reuse untouched siblings"
benefit without a symlink into the main checkout, so #427 and #598 have no surface.
The no-symlink hard-stop rule (issue body, `docs/PRINCIPLES.md` "Enforcement over
documentation") is satisfied structurally: no code path ever reaches a non-git-repo
fallback for a package worktree; ordinary `git worktree add` failure handling (capture
stderr, hard-stop, never `ln -s`) is still implemented explicitly.

## Design comparison 2 — where the multi-repo logic lives (from PR #254 review)

| | C. Type checks inside generic scripts | D. Adapter verbs (ADR-0011) |
|---|---|---|
| ADR-0011 | Violates "workflow scripts never branch on project type"; the ADR's own verb test ("the workflow needs this, and the how differs per type") is met, so a verb is warranted | Compliant; contract extended by two verbs |
| Where the five single-repo assumptions get fixed | Five `if ros2_colcon` branches, one per script | Once: generic scripts loop over a per-worktree repo manifest; the verb produces it |
| Next project type (monorepo sparse checkout, Rust workspace, …) | Re-does all five | Implements two verbs |
| Size | Smaller now | Larger now: two verbs × two adapters, factor the branch waterfall into a per-repo function, new ADR |

**Chosen: D** (decided 2026-09-15 with the owner after the tool scan).

## Approach

1. **CLI — explicit, nothing inferred** (decided 2026-09-15; upstream #526 wrong-repo
   pick came from resolving a bare issue number). #255 (`--repo` → `--project`) is merged.

   ```
   worktree_create.sh --type project --project p11-jazzy \
       --issue rolker/cube_bathymetry#111 \
       --layer platforms --package-repos cube_bathymetry,marine_msgs
   ```

   - `--issue` accepts `owner/repo#N` for any project type. For `ros2_colcon` it is
     **required** in that form and `--layer` + `--package-repos` are required; a bare
     number is a usage error, never a guess. For `single_project` the extra flags are
     rejected. Validation lives in the `worktree_repos` verb (step 2), not in the script.
   - `--package-repos` takes package-repo directory names (what `adapter repos` prints),
     not ROS package names (a documented confusion upstream). `--type layer` is rejected.
   - Worktree directory: `worktrees/project/<project>/issue-<project>-<owner-repo>-<N>/`.
     `worktree_enter.sh`, `worktree_remove.sh`, `merge_pr.sh` take the same qualified
     `--issue` and refuse a bare number for this shape.
   - **Branch names** (decided 2026-09-15): owning repo `feature/issue-<N>`; every other
     repo `feature/<owner-repo>-issue-<N>` (e.g. `feature/cube_bathymetry-issue-111` in
     `marine_msgs`), PR body references `owner/repo#N`.

2. **Two new contract verbs** (ADR-0012, new — ADR-0011 fixes the verb count in its
   decision text, so this is a substantive change per ADR-0008, not an addendum):

   - `worktree_repos --issue <ref> [--layer <l>] [--package-repos <a,b>]` → one line per
     repo to worktree: `<origin_repo_abs_path>\t<rel_path_in_worktree>\t<branch>`.
     Validates its own flags; unknown repo names or a repo outside `--layer` are hard
     errors naming where it was found. `single_project`: one line
     (`<project_dir>\t.\tfeature/issue-N`; rejects `--layer`/`--package-repos`).
     `ros2_colcon`: resolves paths via the existing `adapter_repos` manifest walk
     (line 618); rel path `<layer>_ws/src/<repo>`.
   - `worktree_env --worktree <dir>` → sourceable bash, or empty. `single_project`:
     empty. `ros2_colcon`: the same scrub `adapter_build` does at line 452, distro
     underlay, every layer **below** the target layer's `install/local_setup.bash`
     from the hosted instance in `layers.txt` order, the hosted instance's
     **same-layer** install, then `<dir>/<layer>_ws/install/local_setup.bash` if it
     exists — canonical colcon precedence, no force-prepend.
   - `REQUIRED_VERBS` in `.agent/scripts/adapter` → 12; `validate_adapter.sh` and
     `test_adapter.sh` cover both types.

3. **Per-worktree repo manifest.** `worktree_create.sh` writes
   `<worktree>/.worktree-repos` (outside every repo's tree, so never committed): a
   header `# project=<name> issue=<owner/repo#N> layer=<l>` followed by the
   `worktree_repos` output. Every later script (`enter`, `remove`, `merge_pr`, `list`,
   `dashboard`) reads that file and never calls the adapter or checks the type.
   **Directory names are never parsed for this shape** — project, issue and owning
   repo come from the header, which sidesteps the hyphen ambiguity in
   `issue-<project>-<owner-repo>-<N>` (project, owner and repo names can all contain
   hyphens). A worktree without the file is a legacy single-repo worktree: today's
   regex and root-as-the-one-entry fallback apply.

4. **`worktree_create.sh`**: factor the branch-resolution waterfall (local → remote →
   parent → new; lines 469-493) into `_wt_add_repo <origin> <dest> <branch>` that
   captures stderr at every attempt (drop `2>/dev/null`). Loop over `worktree_repos`
   entries, tracking each success; on any failure print the collected stderr,
   `git worktree remove --force` every entry added so far, delete the aggregate dir,
   `exit 1` — never `ln -s`. Before each add, `git -C <origin> rev-parse --git-dir`
   must succeed (a non-git manifest entry is a manifest bug: distinct error, still no
   symlink). Then, if `worktree_env` prints anything, write `<worktree>/env.sh`
   (its output), `build.sh` (`source env.sh` → `colcon build` in `<layer>_ws`) and
   `test.sh` (`source env.sh` → `colcon build` if no install yet → `source env.sh`
   again so the fresh overlay is on top → `colcon test` + `colcon test-result`).
   `env.sh` is the entry point for an issue shell that must retain the overlay; an
   executed `build.sh` cannot set the caller's environment.

5. **`worktree_remove.sh`**: read `.worktree-repos`; preflight `git status --porcelain`
   on **every** entry before removing any (unless `--force`); remove each via
   `git -C <origin> worktree remove` + `prune`; delete the aggregate dir last.

6. **`merge_pr.sh`**: accept `--repo owner/repo` (or a qualified `owner/repo#N` PR
   ref) and, when given, query only that repo; otherwise today's workspace/`project/`
   behaviour. Locate the worktree by scanning `worktrees/project/*/*/.worktree-repos`
   (and legacy) for an entry whose branch matches the PR head. Cleanup rule: delete the
   merged branch in its own repo and sync that repo; **remove the worktree only when
   every other entry's branch has no open PR** (`gh pr list --head -R`), otherwise keep
   it and print which package PRs are still open. Accept both branch-name forms when
   extracting the issue number.

7. **`worktree_list.sh` / `dashboard.sh`**: when `.worktree-repos` exists, issue,
   project and owning repo come from its header (step 3), and branch/dirty state from
   its entries (aggregate dirty = any entry dirty, changed-file count summed); the
   directory-name regex is only the legacy path. Dashboard counts
   `worktrees/project/*/*`. **Remove `wt_layer_branch`/`wt_layer_is_dirty`** from
   `_worktree_helpers.sh` (added for #25, zero callers, and they encode design A's
   symlink-skipping layout that design B rejects).

8. **`/start-task` SKILL.md**: update the argument-compatibility note. Creation flags
   (`--layer`, `--package-repos`) are creation-only like `--branch`/`--plan-file`;
   re-entry uses `--issue owner/repo#N --type project --project <name>` only.

9. **Hermetic tests**: `test_adapter.sh` — both verbs on both types with fake repos.
   `test_ros2_colcon.sh` — create success (two fake package repos, one worktreed, the
   other untouched and `[ -L ]` false); **failure on the second repo** rolls back the
   first and leaves no aggregate dir; multi-package dirty removal refuses before
   touching anything; `env.sh` sourcing order under a pre-polluted
   `COLCON_PREFIX_PATH`; `worktree_list.sh --json` reports issue, project, branches
   and dirty state for a nested worktree; `merge_pr.sh` keeps the worktree while a
   sibling PR is open (stub `gh`).

10. **Smoke test on `p11-jazzy` only** (decided 2026-09-15): one real package
    worktree, `build.sh` does a real colcon build, hosted install untouched,
    `worktree_remove.sh`, main checkout unaffected.

11. **Docs**: `docs/decisions/0012-worktree-composition-is-an-adapter-concern.md`;
    ADR-0011 gets an ADR-0008 cross-reference addendum in its Status section
    ("amended by ADR-0012: +2 verbs") so its 10-verb table does not go stale;
    `.agent/knowledge/principles_review_guide.md` line 37 ("10-verb contract") and its
    ADR table updated per that guide's own consequences map;
    `docs/ROADMAP.md` row 6 → phase 3 done; `.agent/WORKTREE_GUIDE.md` subsection on
    package worktrees (qualified `--issue`, `--layer`, `--package-repos`, branch
    naming, `env.sh`/`build.sh`/`test.sh`, structural no-symlink rule). **`AGENTS.md`
    untouched** (decided 2026-09-15).

## Files to Change

| File | Change |
|---|---|
| `.agent/scripts/adapter` | `REQUIRED_VERBS` += `worktree_repos worktree_env` |
| `.agent/project_types/single_project/adapter.sh` | Implement both verbs (single-entry / empty) |
| `.agent/project_types/ros2_colcon/adapter.sh` | Implement both verbs; share scrub/underlay helpers with `adapter_build` |
| `.agent/scripts/validate_adapter.sh` | Covered by `REQUIRED_VERBS`; confirm passes |
| `.agent/scripts/worktree_create.sh` | Qualified `--issue`, `--layer`, `--package-repos`; `_wt_add_repo` loop with captured stderr, rollback, hard-stop; write `.worktree-repos`; generate `env.sh`/`build.sh`/`test.sh` |
| `.agent/scripts/worktree_enter.sh` | Qualified `--issue`; new directory name |
| `.agent/scripts/worktree_remove.sh` | Manifest-driven preflight-all-then-remove-all; aggregate dir last |
| `.agent/scripts/merge_pr.sh` | `--repo`/qualified PR ref; manifest-driven worktree lookup; sibling-PR cleanup rule; both branch forms |
| `.agent/scripts/worktree_list.sh` | New name regex; per-entry branch/dirty from manifest |
| `.agent/scripts/dashboard.sh` | Count `worktrees/project/*/*` |
| `.agent/scripts/_worktree_helpers.sh` | `.worktree-repos` writer/reader with legacy fallback, shared by the five scripts; delete dead `wt_layer_branch`/`wt_layer_is_dirty` |
| `.agent/scripts/tests/test_adapter.sh`, `test_ros2_colcon.sh` | Cases in step 9 |
| `.claude/skills/start-task/SKILL.md` | Compat note (step 8) |
| `docs/decisions/0012-…md` | New ADR |
| `docs/decisions/0011-project-type-adapter-contract.md` | Status-section cross-reference addendum (ADR-0008) |
| `.agent/knowledge/principles_review_guide.md` | "10-verb" wording and ADR table |
| `docs/ROADMAP.md`, `.agent/WORKTREE_GUIDE.md` | Step 11 |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Human control and transparency | Hard-stop with full stderr on any worktree-add failure, rollback of partial state; `merge_pr.sh` says which sibling PRs block cleanup |
| Enforcement over documentation | No-symlink rule structural (B) plus `rev-parse` check and the forced-failure test; verb presence enforced by `validate_adapter.sh` in pre-commit and CI |
| Capture decisions, not just implementations | Two comparisons above; ADR-0012 records the contract extension |
| A change includes its consequences | All five single-repo scripts, list/dashboard, skill note, docs and tests are in scope |
| Only what's needed | Two verbs, not three (arg validation folded into `worktree_repos`); a flat manifest file instead of adapter calls from every script |
| Improve incrementally | Builds on phases 1/2/4; `single_project` behaviour unchanged, legacy worktrees keep working via fallback |
| Test what breaks | Second-repo failure, multi-package dirty, polluted env, sibling-PR cleanup — the regressions that matter |
| Workspace vs. project separation | Generic scripts know nothing about ROS; shape knowledge stays in the adapter |
| Primary framework first, portability where free | Bash, framework-agnostic; skill note is Claude-only by nature |
| The workspace serves the product | Real per-issue package isolation on `p11-jazzy` |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0002 (worktree isolation) | Yes | Package worktrees, never branch-switching the main checkout |
| ADR-0004/0005 (enforcement hierarchy) | Yes | Hermetic tests + `validate_adapter.sh` are the mechanical checks |
| ADR-0008 (addendums) | Yes | Adding verbs changes ADR-0011's decision text → new ADR-0012, not an addendum |
| ADR-0011 (adapter contract) | Yes | Generic scripts no longer branch on type; two verbs added via ADR-0012; `validate_adapter.sh` extended automatically by `REQUIRED_VERBS` |
| ADR-0016 equivalent (runtime chaining, embedded in `adapter_env`/`adapter_build`) | Yes | `worktree_env` sources `local_setup.bash` only, ascending, scrub first |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Adapter contract (+2 verbs) | Both adapters, `validate_adapter.sh`, `test_adapter.sh`, ADR-0012, ADR-0011 status addendum, `principles_review_guide.md` | Yes |
| `worktree_create.sh` CLI | `WORKTREE_GUIDE.md`, `/start-task` SKILL.md; `AGENTS.md` deliberately not | Yes |
| Worktree directory/branch naming | `worktree_list.sh`, `dashboard.sh`, `worktree_enter.sh` | Yes |
| Cleanup logic (`remove`, `merge_pr`) | Tests for those scripts | Yes — new cases in `test_ros2_colcon.sh` with a stubbed `gh`; no standalone suites exist today |
| ROADMAP.md row 6 | Steps 4/7 remain open in the row text | Yes |

## Decisions (resolved 2026-09-15 with the owner)

- Design B (pure overlay) and design D (adapter verbs, after an existing-tool scan
  found nothing packaged).
- AGENTS.md untouched; smoke on `p11-jazzy` only; CLI explicit, nothing inferred;
  non-owning repos branch as `feature/<owner-repo>-issue-<N>`.

## Open Questions

- None blocking. During coding: whether `worktree_enter.sh --print-path` should also
  accept the directory name directly for dispatchers that already know it.

## Estimated Scope

**Two PRs**, both under this issue:

1. Verbs + ADR-0012 + `worktree_create`/`enter`/`remove`/`list`/`dashboard` + tests +
   docs. Mergeable alone: worktrees can be created, built, listed and removed; merging
   a package PR meanwhile is `gh pr merge` + `worktree_remove.sh` by hand.
2. `merge_pr.sh` multi-repo resolution and sibling-PR cleanup rule. Closes #252.
