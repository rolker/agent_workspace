# Plan: Prototype a general ROS 2 manifest resolver (west-based) with a temporary home in the workspace

## Issue

https://github.com/rolker/agent_workspace/issues/267 (Part of #172, re-scopes step 4)

## Context

`ros2_colcon` today reads an in-tree manifest (`layers.txt`, `optional_layers.txt`,
`repos/<layer>.repos`, `bootstrap.yaml`) directly (`.agent/project_types/ros2_colcon/adapter.sh`,
`_rc_bootstrap_manifest` / `adapter_setup`). Per-distro is handled by branching the whole
manifest repo (jazzy vs rolling); the real p11 manifests at
`projects/p11-jazzy/configs/manifest/` and `projects/p11-rolling/configs/manifest/` differ by
exactly 3 lines (`bootstrap.yaml` branch + a new `distro:` field, and
`repos/core.repos: unh_marine_autonomy version: jazzy` → `rolling`) — confirmed by `diff -r`
against both checkouts. 44 repos across 7 layers (underlay 9, core 7, platforms 8, sensors 8,
simulation 3, site 1, ui 8); `site` is the one optional layer.

Issue #267 (owner decisions 2026-09-16, quoted in full below) asks for a **general, extractable**
manifest resolver — not a project11 or workspace component — built as a **dual prototype**: an
own resolver (Python, PyYAML-only) and a west-based variant, evaluated against the same matrix,
so the tool choice is made on working evidence. The owner has approved `vcs2l` as the fetch-layer
replacement for `vcstool` and the dual-prototype approach (issue comments, 2026-09-16); the
resolver choice itself (own vs. west) is **not** decided yet.

`.agent/work-plans/issue-265/plan.md` §1 documents the registry fields the adapter will consume
once this lands: `role=` and `distro=` on a `ros2_colcon` registry line are passed through as
`ACTIVE_PROJECT_ROLE` / `ACTIVE_PROJECT_DISTRO`; `ros2_colcon` uses `distro` today (replacing
`ROS_DISTRO`), and will use `role` "once #267's resolver lands." This plan's CLI contract is
designed so that wiring is a thin adapter change, not a redesign.

## Approach

### Manifest schema

- **Composition**: a manifest may declare `extends: {url, ref, path}` (or a bare local path).
  Extension is additive only — repos, groups, and roles add; an extension may not remove or
  re-version a base repo (**hard error** at resolve time, not a silent override). First
  definition wins across the extends chain. A manifest can describe repos it doesn't live in.
- **Layers**: one fixed, ordered list per manifest (build-order units). Roles only subtract from
  a layer's repo list — nothing is defined per-role — so a new repo is one edit and can't be
  silently missing from a role.
- **Per-repo ref**: a default `ref` plus an optional `distros: {<distro>: {ref: ... | absent:
  true}}` map. A repo absent for a distro is dropped from that distro's resolved output, not
  an error — matches the p11 rolling-first-development pattern.
- **Selectors — two candidate role models, both built into the prototype for comparison**:
  1. **Groups** (west-shaped): default-include groups (`gui`, `sim`) that a role subtracts, and
     default-exclude groups (`hw:deltat`, `hw:m3`) that a role opts into. Roles compose
     (`izzyboat = platform + hw:deltat`). Maps ~1:1 onto west's `group-filter`.
  2. **Dependency closure**: a role is a set of root packages; `package.xml` `exec_depend`
     (and other depend tags) walked over the resolved repo tree selects the rest. No per-repo
     tagging; a boundary (e.g. operator role must not reach platform repos) is self-enforcing
     if true, and a violation surfaces as a validation failure instead of being possible to omit.
  This is genuinely open — see Open Questions.
- **Output**: one `.repos` (vcstool/vcs2l-compatible) file per layer per (role, distro), with a
  provenance header comment naming the manifest file/extends-chain entry that contributed each
  repo.
- **Validation**: a per-role table (repo → included/excluded + reason) and a ROS-aware dependency
  check — a selected package must not depend (incl. `exec_depend`) on an excluded repo.

### Dual prototype

- **Own resolver** (`tools/ros-manifest/`, Python, **PyYAML the only runtime dependency**):
  YAML schema loader → extends resolution (local path now; git url+ref+path via a cache dir,
  git-only, no network fetch inside tests — tests use `file://` / local-clone fixtures) →
  first-definition-wins merge with the override-refusal check → per-distro ref resolution →
  group/role selection (both models implemented so the comparison is real, not asserted) →
  `.repos` emission with provenance → validation table + dependency check (uses `catkin_pkg`
  if present for `package.xml` parsing; degrades to a documented no-op with a clear message
  if the fixture has no real `package.xml` files, since fixtures are metadata-only).
- **West-based variant**: **not built this run** (owner scoped it to prototype comparison, and
  west needs a real git-backed workspace per its "compromise list" item 1 — building it against
  synthetic fixtures without network is a separate exercise). Instead, `tools/ros-manifest/docs/
  west-variant.md` (this run) specifies the concrete shape precisely enough that the next
  milestone is "implement against this doc," not "re-derive the design": per-layer `west.yml`
  with an `import:` chain mirroring the extends chain, the group-filter mapping for role model
  (1), the per-distro pre-processing step (since west has no native per-distro ref — confirmed
  in the issue's compromise list item 4), and the YAML→`.repos` converter. It also states the
  conformance matrix the west milestone must pass (7 layers × 2 roles × 2 distros minimum) and
  the concrete role-model-comparison experiment: resolve `izzyboat` via groups vs. via
  `izzyboat_bringup` + `package.xml` exec_depend closure over the same resolved tree, diff the
  two repo sets, and record which is closer to hand-maintained intent with less annotation.

### Acceptance test (own resolver only, this run)

A test manifest authored from the `p11-jazzy` fixture (copied into
`tools/ros-manifest/tests/fixtures/p11/`, **not** read from `projects/p11-jazzy` at test time —
that tree is read-only project data, not a workspace fixture) resolves for `role=dev,
distro=jazzy` to `.repos` files byte-identical to the real fixture's `repos/*.repos`, modulo the
provenance header. Resolving `distro=rolling` reproduces the exact 3-line difference (branch
context is out of scope for the resolver — only the `unh_marine_autonomy` ref change is a
resolver concern; the `bootstrap.yaml` branch/`distro:` fields belong to the adapter's bootstrap
step, unchanged by this issue).

### Extraction constraints

`tools/ros-manifest/` is a self-contained package from day one: its own `pyproject.toml`
(PyYAML only), its own `README.md` (states the directory/command names are placeholders), its
own `tests/`, and a top-of-file "extraction candidate" marker comment in the package `__init__.py`
and README pointing at issue #267. No imports from `.agent/scripts/` or any workspace module —
the future adapter wiring calls the installed `ros-manifest` CLI as a subprocess, never imports
Python from it. A dedicated CI job (`.github/workflows/validate.yml`) runs its test suite so the
lane is visible and moves with the code when the directory is subtree-split out later.

### vcs2l swap

Deferred to a separate small PR per the issue ("may be a separate small PR"). This run only
plans for it: the resolver emits `.repos` files (vcstool-format, which vcs2l reads unchanged per
the issue's compromise-list note that "the `.repos` format is unchanged"), so the swap is
`adapter_setup`'s `vcs import` → `vcs` from `python3-vcs2l` instead of `python3-vcstool`, with no
resolver-side change.

### Adapter integration (design only, not wired this run)

Once a milestone lands a resolver choice, `ros2_colcon`'s `adapter_setup` gains a step between
`_rc_bootstrap_manifest` and the existing `vcs import` loop: if the hosting dir's manifest is the
new schema (detected by a marker file, e.g. `manifest.yaml` vs. today's `layers.txt`), call
`ros-manifest resolve --manifest <path> --role "$ACTIVE_PROJECT_ROLE" --distro
"$ACTIVE_PROJECT_DISTRO" --out <tmp-or-cache-dir>` to materialize `.repos` files, then run the
existing `vcs import --skip-existing` loop unchanged against the generated files instead of the
hand-maintained ones. `layers.txt`/`repos/*.repos` stay supported (legacy shape) until every
hosted project migrates — this plan does not remove that path. CLI-only integration matches the
issue's constraint ("adapter calls the CLI, agents never run west/the resolver directly").

## Files to Change

| File | Change |
|------|--------|
| `tools/ros-manifest/pyproject.toml` | New package, PyYAML-only runtime dep |
| `tools/ros-manifest/README.md` | Placeholder-name notice, usage, extraction marker |
| `tools/ros-manifest/src/ros_manifest/__init__.py` | Package init + extraction-candidate marker |
| `tools/ros-manifest/src/ros_manifest/schema.py` | YAML manifest loader + validation errors |
| `tools/ros-manifest/src/ros_manifest/extends.py` | Extends-chain resolution (local path + git url/ref/path cache) |
| `tools/ros-manifest/src/ros_manifest/merge.py` | First-definition-wins merge, override-refusal errors |
| `tools/ros-manifest/src/ros_manifest/selectors.py` | Groups model + dependency-closure model |
| `tools/ros-manifest/src/ros_manifest/emit.py` | `.repos` emitter with provenance headers |
| `tools/ros-manifest/src/ros_manifest/validate.py` | Validation table + dependency check |
| `tools/ros-manifest/src/ros_manifest/cli.py` | `ros-manifest resolve` / `validate` CLI |
| `tools/ros-manifest/tests/fixtures/p11/*` | Manifest authored from `projects/p11-jazzy` (copied, read-only source untouched) |
| `tools/ros-manifest/tests/test_*.py` | Schema, extends/override, distro, groups/roles, acceptance tests |
| `tools/ros-manifest/docs/west-variant.md` | West-based design spec + conformance matrix (next milestone) |
| `.github/workflows/validate.yml` | New CI job running `tools/ros-manifest` tests |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Own resolver is thin (schema/extends/merge/selectors/emit/validate); west variant deferred to a doc, not built speculatively this run |
| A change includes its consequences | Adapter integration is designed in this plan but explicitly not wired yet — avoids half-migrating `ros2_colcon` ahead of the tool decision |
| Workspace vs. project separation | Fixtures are copied into the tool's own tests dir; `projects/p11-jazzy` is read-only source, never modified |
| Capture decisions, not just implementations | Plan states role-model and west-vs-own as explicitly open, with the concrete experiments that will close them |
| Test what breaks | Acceptance test is exact-match against real fixture data, not synthetic-only |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0009 (no bare pip install) | Yes | `.venv/bin/pip install -e tools/ros-manifest[test]` inside the workspace dev venv only; documented in progress.md |
| ADR-0011 (project-type adapter contract) | Design-only this run | Adapter change is scoped and described but deferred to the milestone that lands a resolver choice, so the adapter contract isn't touched mid-flight |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Add `tools/ros-manifest/` | CI (`.github/workflows/validate.yml`) | Yes — new job this run |
| Manifest schema is designed | `ros2_colcon` adapter, `.agent/work-plans/issue-265/plan.md` role wiring | No — deferred to the milestone after the resolver is chosen; noted in Open Questions |
| `vcs2l` swap | `adapter_setup`'s tool-presence check (`command -v vcs`) | No — separate small PR per issue scope |

## Open Questions

- **Role model** (groups vs. dependency closure) — left open per the issue; the prototype
  implements both and the comparison happens on the p11 fixture plus (for west) the doc's
  experiment. Decided in a follow-up milestone, not this one.
- **West vs. own resolver** — not decided. This run only builds the own resolver and specifies
  the west variant; the comparison and decision are the next milestone's job.
- **Dependency-check fidelity** — the p11 fixture repos have no real `package.xml` files (test
  fixtures are metadata-only manifests, not full checkouts); the dependency-closure and
  `exec_depend` check will be exercised with small synthetic `package.xml` fixtures rather than
  the real p11 source tree. Flagged so reviewers don't expect the real-repo dependency graph to
  be validated by this milestone.

## Estimated Scope

Single PR for this milestone (plan + own-resolver skeleton + tests + CI job + west-variant doc).
Adapter wiring and the west-based implementation are separate follow-up PRs.
