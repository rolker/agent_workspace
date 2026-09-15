# ADR-0012: Worktree Composition Is an Adapter Concern

## Status

Accepted. Extends [ADR-0011](0011-project-type-adapter-contract.md)'s
adapter contract with two verbs.

## Context

[ADR-0011](0011-project-type-adapter-contract.md) isolated project-*shape*
knowledge behind a fixed adapter contract, but five generic scripts
(`worktree_create.sh`, `worktree_remove.sh`, `merge_pr.sh`,
`worktree_list.sh`, `dashboard.sh`) still hardcode a single-repo assumption:
a project worktree is exactly one `git worktree add` against one repo.
Issue #252 needs `ros2_colcon` package worktrees — an isolated worktree for
one or more package repos inside one layer of a hosted instance, overlaying
that instance's already-built lower layers via colcon's normal install
precedence.

Two designs were compared for *where* the multi-repo composition knowledge
should live:

- **Type checks inside generic scripts** — smaller now, but violates
  ADR-0011's own rule ("workflow scripts never branch on project type") and
  re-does the same branching in every future project type.
- **Adapter verbs** — larger now (two verbs, both adapters, a per-repo
  helper factored out of the branch-resolution waterfall), but the generic
  scripts stay type-agnostic: they loop over a manifest the adapter
  produces and never call the adapter or check the type themselves.

Adding verbs changes ADR-0011's decision text (it fixes the verb count at
10), so per [ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md)
this is a substantive change requiring a new ADR, not an addendum.

An existing-tool scan (2026-09-15) found nothing packaged for "subset of a
multi-repo manifest → git worktrees → colcon overlay on an already-built
install → cleanup" (multree and Canopy orchestrate worktree sets from their
own manifests with no vcstool/colcon awareness; vcstool's 2025 rewrite has
no worktree subcommand; Zephyr `west` has only an unimplemented proposal).

## Decision

Extend the adapter contract with two verbs (`REQUIRED_VERBS` → 12):

- `worktree_repos --issue <ref> [--layer <l>] [--package-repos <a,b>]` —
  one line per repo to worktree:
  `<origin_repo_abs_path>\t<rel_path_in_worktree>\t<branch>`. Validates its
  own flags; unknown repo names or a repo outside `--layer` are hard errors
  naming where it was actually found. `single_project` prints one entry
  (the project root, rel path `.`) and rejects `--layer`/`--package-repos`.
  `ros2_colcon` requires a qualified `--issue owner/repo#N` plus both
  `--layer` and `--package-repos`; the issue's own repo gets
  `feature/issue-<N>`, every other named repo gets
  `feature/<repo>-issue-<N>`.
- `worktree_env --worktree <dir>` — sourceable bash, or nothing.
  `single_project` emits nothing. `ros2_colcon` emits the same prefix-path
  scrub `adapter_build` does, the distro underlay, every layer **below**
  the worktree's target layer (ascending, from the hosted instance),
  the hosted instance's **same-layer** install, then the worktree's own
  `<layer>_ws/install/local_setup.bash` if it has been built — canonical
  colcon overlay precedence, no force-prepend.

A per-worktree manifest file, `.worktree-repos` (written by
`worktree_create.sh`, read by every other worktree script), carries the
`worktree_repos` output plus a header (`project`, `issue`, `layer`) so the
five generic scripts loop over repo entries without ever calling the
adapter or checking the project type. A worktree without this file is a
legacy single-repo worktree; the pre-#252 directory-name parsing and
root-as-the-one-entry behavior remain the fallback.

No symlink fallback exists anywhere in this path: worktree creation either
produces real git worktrees for every named repo or rolls back everything
it already created and hard-stops, matching the issue's no-symlink
requirement structurally rather than by convention.

## Consequences

**Positive:**
- The five generic scripts stay project-agnostic; a future project type
  (e.g. a monorepo with sparse checkouts) implements the same two verbs
  instead of adding a sixth branch to every generic script.
- `ros2_colcon` package worktrees reuse colcon's own overlay semantics for
  untouched sibling packages and lower layers — no symlinked source tree,
  no `PYTHONPATH` shadowing class of bug, no fallback path that could ever
  reach `ln -s`.
- Mechanically enforced the same way as the original 10 verbs:
  `validate_adapter.sh` requires both new verbs on every type; wired to
  pre-commit and CI.

**Negative:**
- The adapter contract grows again, and — as ADR-0011 already flagged —
  every addition raises the bar for every existing and future adapter.
  `single_project`'s implementations are trivial (one entry, empty env),
  which is the intended shape: the contract's cost falls on the type that
  actually needs the behavior.
- `worktree_create.sh`'s branch-resolution waterfall, previously inline,
  is now a shared helper (`_wt_add_repo`) called in a loop; a bug in that
  helper affects every repo in every worktree it creates, single- and
  multi-repo alike (mitigated by the hermetic test suite exercising it for
  both shapes, including forced mid-loop failure).

## References

- [ADR-0011](0011-project-type-adapter-contract.md) — the adapter contract
  this extends (amended by this ADR: +2 verbs, 12 total)
- [ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md) — why this
  is a new ADR rather than an addendum to ADR-0011
- [ADR-0002](0002-worktree-isolation-over-branch-switching.md) — worktree
  isolation this preserves for multi-repo package worktrees
- Issue #252 (`ros2_colcon` adapter phase 3: layer/package worktrees)
