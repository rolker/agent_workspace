# ros-manifest (placeholder name)

**Status: prototype.** This directory, the `ros-manifest` command name, and the Python package
name (`ros_manifest`) are all placeholders — see
[agent_workspace#267](https://github.com/rolker/agent_workspace/issues/267). It is a general ROS
2 multi-repo manifest resolver, not project11 or agent-workspace infrastructure. It lives here
temporarily because it doesn't have a repo of its own yet.

**Extraction candidate.** This package is self-contained by design (own `pyproject.toml`, own
tests, own README, no imports from anything outside `tools/ros-manifest/`) so it can be pulled
out into its own repository later with a history-preserving subtree split, without having to
first untangle it from workspace code. Nothing in `.agent/` or the workspace `Makefile` imports
Python from this package — integration is CLI-only (subprocess), per the design in
`.agent/work-plans/issue-267/plan.md`.

## What this is

A resolver for a manifest format that lets multiple ROS 2 repos compose into one build:

- **Composition**: a manifest may `extends` another (local path, or a git `url` + `ref` + `path`).
  Extensions may only *add* repos, groups, and roles — they can never remove or re-version a
  repo the base manifest already defines (that's a hard error).
- **Layers**: a fixed, ordered list of colcon-overlay build units. Roles only ever *subtract*
  from a layer's repo list.
- **Per-distro refs**: each repo has a default `ref`, with optional per-distro overrides, and can
  be entirely absent for a given distro.
- **Roles**: two selector models are implemented so they can be compared on real data (see
  `docs/west-variant.md` and the parent plan's Open Questions) — default-include/exclude
  **groups** that a role subtracts from or opts into, and a **dependency closure** over root
  packages using `package.xml` `exec_depend`/`depend`.
- **Output**: one vcstool/vcs2l-compatible `.repos` file per layer, for a given `(role, distro)`
  pair, with a provenance comment header naming which manifest in the extends chain contributed
  each repo.

See `.agent/work-plans/issue-267/plan.md` in the workspace repo for the full design and the
west-based variant comparison plan (`docs/west-variant.md` in this directory).

## Usage

```bash
ros-manifest resolve --manifest path/to/manifest.yaml --role dev --distro jazzy --out ./out
ros-manifest validate --manifest path/to/manifest.yaml --role dev --distro jazzy
```

`resolve` writes `<out>/<layer>.repos` for every layer in the composed manifest (skipping a
layer with zero selected repos for that distro). `validate` prints the per-role inclusion table
and runs the dependency check, exiting non-zero on a violation.

## Development

```bash
# from the workspace repo root, inside the workspace dev venv (ADR-0009)
.venv/bin/pip install -e tools/ros-manifest[test]
.venv/bin/pytest tools/ros-manifest/tests
```

## Not built yet

The west-based variant (see `docs/west-variant.md` for its planned shape and the conformance
matrix it must pass) and the `ros2_colcon` adapter wiring are follow-up milestones, not this
prototype.
