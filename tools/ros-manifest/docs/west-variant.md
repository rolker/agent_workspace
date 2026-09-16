# West-based variant — design (not implemented this milestone)

**Status**: specification only. This document exists so the next milestone can implement
against a concrete shape instead of re-deriving one, and so the own-resolver-vs-west decision
(issue #267) is made from two working artifacts. See the parent plan
(`.agent/work-plans/issue-267/plan.md`) for why it wasn't built this run: west needs a real
git-backed workspace to resolve anything (compromise-list item 1, posted on the issue
2026-09-16) — building it hermetically against synthetic fixtures without network access is a
separate exercise from the own resolver, which was designed to work with plain file reads.

## Shape

### Per-layer `west.yml`

West resolves one manifest with an `import:` chain, not our `extends`. The converter that
produces the per-run `west.yml` mirrors our extends chain: the base manifest (e.g.
`unh_marine_autonomy`) becomes the root `west.yml`; each manifest further out in the chain
becomes an `import:` entry pointing at the next repo/ref/path. Layers are not a west concept —
each of our layers becomes its own `west.yml` (or its own `manifest-name`), and the layer build
order is recovered by resolving each layer's `west.yml` independently and using our own
`layers.txt`-equivalent list to sequence `colcon build` the same way `ros2_colcon`'s adapter
does today.

```yaml
# generated: west.yml for layer "core", distro jazzy, role dev
manifest:
  projects:
    - name: unh_marine_navigation
      url: https://github.com/rolker/unh_marine_navigation.git
      revision: jazzy
    - name: unh_marine_autonomy
      url: https://github.com/rolker/unh_marine_autonomy.git
      revision: jazzy   # rolling variant: revision: rolling — computed by our pre-processor
  # ... one project entry per repo in this layer for this distro
```

### Group-filter mapping (role model (a), groups)

Our default-include/default-exclude groups map directly onto west's `groups:` +
`group-filter:`:

```yaml
manifest:
  projects:
    - name: gui_repo
      groups: [gui]          # our default-include group
    - name: hw_repo
      groups: [hw-deltat]    # our default-exclude group ('+' prefix marks default-off in west)
  group-filter: [-gui, +hw-deltat]   # role's subtract/add, translated 1:1
```

West's own docs describe group-filter precedence for the *simple* case only ("the last filter
element in the final concatenated list wins", concatenated in import order). Our compromise list
flagged this as the main open risk for the real 7-layer × role matrix — an import chain with
groups redeclared at multiple levels (the way our own resolver's group-extension test,
`test_group_can_be_extended_with_more_repos`, exercises) is not documented behavior. The
conformance test below is the way to find out rather than assume.

### Per-distro pre-processing

West has exactly one `revision:` per project — no per-distro concept (compromise-list item 4).
The per-distro ref/absent resolution has to happen **before** west ever sees a manifest: our
pre-processor takes the merged manifest (same `merge.py` output the own resolver uses) and a
target distro, resolves every repo's ref/absence for that distro, and emits the distro-specific
`west.yml` on the fly. This means, as the compromise list already noted, west would never be
"the" source of truth even in the west-based variant — ours is, in both prototypes; west is
only ever handed an already-resolved, single-distro view.

### `.repos` converter

West's own resolved output is its internal YAML (`west list -f "{name} {url} {revision}"` or the
manifest's freeze form), not vcstool's `.repos` schema. The converter walks west's resolved
project list (already distro/role-filtered — see above) and emits the same
`{repositories: {name: {type, url, version}}}` shape `emit.py` produces, so the vcs2l fetch step
and every downstream consumer (`adapter_setup`'s `vcs import` loop) is identical regardless of
which resolver produced the `.repos` files.

## Conformance matrix (next milestone's acceptance test)

Minimum matrix to trust the group-filter-through-import behavior on real shape, not a toy:

| Layer | Roles tested | Distros tested |
|---|---|---|
| underlay | dev | jazzy, rolling |
| core | dev | jazzy, rolling |
| platforms | dev, izzyboat, bizzyboat | jazzy |
| site | dev | jazzy |
| sensors | dev, izzyboat (hw:deltat) | jazzy |
| simulation | dev (sim group present) | jazzy |
| ui | dev | jazzy |

Pass criterion: for every (layer, role, distro) cell, the west-based variant's resolved repo set
for that layer equals the own resolver's (`select_repos` + `resolve_distro_ref` in
`ros_manifest.selectors`) resolved set for the same inputs, exactly — this reuses the own
resolver's already-passing acceptance fixture (`tests/fixtures/p11/`) as the oracle, so the two
prototypes are compared against each other and both against the real jazzy `.repos` files
already verified by `tests/test_acceptance_p11.py`.

If the matrix fails anywhere (the documented risk), that's a finding to record on issue #267,
not a bug to route around silently — west's precedence rule for that cell needs to be worked out
from its importer source (per the issue's survey note) before the tool decision can rely on it.

## Role-model experiment (open question, both prototypes)

Concrete experiment to close the "groups vs. dependency closure" question from the parent plan's
Open Questions, runnable against either prototype's resolved repo tree:

1. Take a real bringup package for a role (e.g. `izzyboat_bringup`).
2. Walk its `package.xml` `exec_depend` (and `depend`) closure over the layer's resolved
   packages — this is exactly what `ros_manifest.selectors.select_repos_by_closure` implements
   against the `packages:` manifest section already, using synthetic `package.xml`-equivalent
   data since the fixture manifests don't check out real repos (see the parent plan's Open
   Questions on dependency-check fidelity).
3. Diff that repo set against the groups-model result for the equivalent role
   (`select_repos_by_groups`) on the same manifest.
4. Record: do the two sets match? If not, is the mismatch a missing group tag (annotation
   burden favors closure) or a missing/incorrect `exec_depend` entry in a real `package.xml`
   (favors groups, since closure now depends on every repo's package metadata being accurate)?

`tests/test_selectors.py::test_closure_model_walks_exec_depend_and_depend` and
`test_groups_roles_compose` already give worked examples of each model's mechanics on synthetic
data; the next milestone's job is running this comparison against package.xml data pulled from
real checked-out p11 repos, which the current fixtures (metadata-only, no checkouts) don't have.
