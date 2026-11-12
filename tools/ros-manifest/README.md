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
`.agent/work-plans/issue-267/plan.md`. The workspace `Makefile` only installs it (see
[Installing](#installing)).

## What this is

A resolver for a manifest format that lets multiple ROS 2 repos compose into one build:

- **Composition**: a manifest may `extends` another (local path, or a git `url` + `ref` + `path`).
  Extensions may only *add* repos, groups, and roles — they can never remove or re-version a
  repo the base manifest already defines (that's a hard error).
- **Layers**: a fixed, ordered list of colcon-overlay build units. Roles only ever *subtract*
  from a layer's repo list. `optional_layers` (a list of names from the same manifest's own
  `layers`) marks layers whose fetch or build a consumer may let fail without aborting; across
  `extends` the optional layers are the union, in chain order. So only a manifest that lists a
  layer in its own `layers` can mark it optional, and no manifest can mark it required again:
  a base you extend decides which of its layers are failure-tolerant, and a leaf that lists the
  same layer and adds repositories to it gets them failure-tolerant too. To make a base's optional layer
  required, change the base.
- **Per-distro refs**: each repo has a default `ref`, with optional per-distro overrides, and can
  be entirely absent for a given distro.
- **Roles**: two selector models are implemented so they can be compared on real data (see
  `docs/west-variant.md` and the parent plan's Open Questions) — default-include/exclude
  **groups** that a role subtracts from or opts into, and a **dependency closure** over root
  packages using `package.xml` `exec_depend`/`depend`.
- **Output**: one vcstool/vcs2l-compatible `.repos` file per layer, for a given `(role, distro)`
  pair, with a provenance comment header naming which manifest in the extends chain contributed
  each repo. A manifest on the local filesystem is named by its file path; a manifest read from
  a git-backed `extends` is named `url#ref:path@<commit>` (the commit that was resolved), never
  by its cache path. A git ref cannot contain `:`, so a ref such as `release/2` reads
  unambiguously.

See `.agent/work-plans/issue-267/plan.md` in the workspace repo for the full design and the
west-based variant comparison plan (`docs/west-variant.md` in this directory).

## Usage

```bash
ros-manifest resolve --manifest path/to/manifest.yaml --role dev --distro jazzy --out ./out
ros-manifest validate --manifest path/to/manifest.yaml --role dev --distro jazzy
```

`resolve` writes one `.repos` file for every layer in the composed manifest, skipping a layer
with zero selected repos for that role and distro. If every layer is skipped it prints a
warning and still exits 0. `--layout` picks the output shape:

- `--layout flat` (the default): `<out>/<layer>.repos` and nothing else.
- `--layout manifest-dir`: `<out>/repos/<layer>.repos`, `<out>/layers.txt` (the layers written,
  in order, one per line) and `<out>/optional_layers.txt` (the written layers listed in
  `optional_layers`; always written, possibly empty). Each text file starts with a `#` line
  naming the role, the distro and the manifests (base first). A skipped layer is in neither
  file. This is the manifest directory shape the workspace's `ros2_colcon` adapter reads.

`validate` prints the per-role inclusion table and runs the dependency check, exiting non-zero
on a violation.

### What a manifest may contain

A manifest, and every manifest it `extends`, is treated as untrusted: its names become file
paths and its values become lines of the generated files. Anything outside these rules is an
error that names the manifest and the key:

- Names: a layer is letters, digits, `_` and `-` (the `ros2_colcon` adapter's rule); a
  repository is letters, digits, `_`, `.` and `-`, not starting with `.` or `-`; a group is
  letters, digits, `_`, `:` and `-` (`hw:deltat`), not starting with `:` or `-`; a role is
  letters, digits, `_` and `-`, not starting with `-`; a distro is lower-case letters, digits
  and `_`, starting with a letter. A name is at most 64 characters. Two names of one kind that
  differ only in case (`core` and `Core`) are refused, within a manifest and across the
  `extends` chain: on a case-insensitive disk one would overwrite the other.
- `url`, `ref`, each per-distro `ref`, `type`, a package's `repo`, and every `extends` field
  must be strings. Quote a ref that YAML would read as something else: `ref: '1.10'`
  (unquoted, it is the number 1.1), `'yes'`, `'2024-01-01'`. A per-distro `absent` must be
  `true` or `false`.
- A `url` (a repository's, or `extends.url`) must have one of these shapes, matched whole;
  anything else is refused, and the message lists the shapes without printing the URL:
  - `https://<host>[:port]/<path>`
  - `ssh://<user>@<host>[:port]/<path>`
  - `<user>@<host>:<path>` (scp-style, as `git@github.com:org/repo.git`)
  - `file:///<absolute path>`, for local and test use

  Host, user and path are letters, digits, `.`, `_` and `-`, with `/` in a path; none starts
  with `-`. There is no place for a password or token (use a credential helper or an ssh
  remote), a query, a fragment, whitespace, or git's `<transport>::` form. Plain `http://`,
  `git://` and a bare local path are not accepted. A local base is still named with
  `extends: {path: ...}` and no `url`; that path must stay inside the declaring manifest's
  directory.
- A `ref` (a repository's, each per-distro one, `extends.ref`) is letters, digits, `.`, `_`, `/`
  and `-`, starting with a letter or digit, with no `..` and not ending in `/` or `.lock`. It
  cannot start with `-`, so neither git nor `vcs import` can read it as an option.
- No key or value may contain a control character (newline, carriage return, tab, ...), a line
  or paragraph separator, an invisible or bidirectional formatting character (zero-width space,
  byte-order mark, right-to-left override) or a space other than the ASCII one.
- YAML aliases (`*name`) and repeated mapping keys are refused. A YAML error is reported by line
  and column only, never with the document's text; a value YAML cannot build (`!!int 0xz`, an
  unquoted `2024-13-45`) is reported as invalid YAML with no position. An integer past 64 bits
  is refused.

As a second line, `resolve` refuses to write a line that holds any of those characters or a file
that would land outside `--out`, and writes nothing in that case. The `extends` clone states
the transports git may use (`https`, `ssh`, `file`; everything else, such as `ext::`, refused)
on its own command line rather than relying on git's defaults.

No error message prints a value from a manifest: it names only the manifest, a key or name that
passed the rules above, a type, or a line and column (a failed `extends` clone gives git's exit
status, not its output). Any other failure prints `ERROR: internal error (<exception type>)`
and exits 1: never the exception's text, never a traceback.

### The `extends` cache

A git-backed `extends` is cloned with `git clone --branch <ref> --depth 1` into the cache
directory (`--cache-dir`, default `.ros-manifest-cache` in the current directory) and reused on
every later run with the same url and ref, so a branch that moved on the remote is **not**
followed while that cache entry exists. To resolve what the remote holds now, delete the cache
directory or pass a fresh `--cache-dir`. `extends.ref` must be a branch or a tag (`git clone
--branch` cannot take a commit).

## Installing

From the workspace repo (main checkout or any worktree):

```bash
make install-ros-manifest   # also part of `make setup`
```

This installs the package editable into the workspace's shared `.venv` from the main checkout,
so the command is `.venv/bin/ros-manifest` there. It is a make target and not a line in the
workspace `requirements.txt` (ADR-0009): that file lists PyPI tools and is installed before
the recipe changes to the main checkout, so a relative `-e tools/ros-manifest` in it would
follow the caller's directory. Installing needs PyPI (PyYAML, and setuptools to build).

## Development

```bash
# from the workspace repo root, inside the workspace dev venv (ADR-0009)
.venv/bin/pip install -e tools/ros-manifest[test]
.venv/bin/pytest tools/ros-manifest/tests
```

## Not built yet

The west-based variant (see `docs/west-variant.md` for its planned shape and the conformance
matrix it must pass) is not built. The `ros2_colcon` adapter calling this resolver (with
`--layout manifest-dir`) is in progress in agent_workspace issue #436.
