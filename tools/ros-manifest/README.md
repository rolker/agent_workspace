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
error that says where the problem is. Most errors name the manifest and the key. Two names that
differ only in case are named with their manifest, or with "the composed extends chain" when they
come from different manifests. An `extends` path that escapes its directory names the path and
the declaring directory or clone, and a local one that is not found names the full path looked
for. A YAML error names the manifest and, where the parser gives one, a line and column; a value
YAML cannot build, a document nested too deeply and a character the YAML reader refuses (such as
NUL) give no position. These rules describe what the checks aim at; the cases they are known not
to reach are described where they apply and tracked in #447. The rules:

- Names: a layer is letters, digits, `_` and `-` (the `ros2_colcon` adapter's rule); a
  repository is letters, digits, `_`, `.` and `-`, not starting with `.` or `-`; a group is
  letters, digits, `_`, `:` and `-` (`hw:deltat`), not starting with `:` or `-`; a role is
  letters, digits, `_` and `-`, not starting with `-`; a distro is lower-case letters, digits
  and `_`, starting with a letter. A name is at most 64 characters. Two names of one kind that
  differ only in case (`core` and `Core`) are refused, within a manifest and across the
  `extends` chain: on a case-insensitive disk one would overwrite the other.
- `url`, `ref`, each per-distro `ref`, `type`, a package's `repo`, and `extends`' `path`, `url`
  and `ref` must be strings. Quote a ref that YAML would read as something else: `ref: '1.10'`
  (unquoted, it is the number 1.1), `'yes'`, `'2024-01-01'`. A per-distro `absent` must be
  `true` or `false`.
- A `url` (a repository's, or `extends.url`) must have one of these shapes, matched whole;
  anything else is refused, and the message lists the shapes without printing the URL:
  - `https://<host>[:port]/<path>`
  - `ssh://<user>@<host>[:port]/<path>`
  - `<user>@<host>:<path>` (scp-style, as `git@github.com:org/repo.git`)
  - `file:///<absolute path>`, for local and test use

  A host is letters, digits, `.` and `-`; a user and a path also allow `_`, and a path `/`;
  none starts with `-`. There is no place for a password or token (use a credential helper or an ssh
  remote), a query, a fragment, whitespace, or git's `<transport>::` form. Plain `http://`,
  `git://` and a bare local path are not accepted. A local base is still named with
  `extends: {path: ...}` and no `url`; that path must stay inside the declaring manifest's
  directory.
- A `ref` (a repository's, each per-distro one, and `extends.ref` beside a `url`) is letters,
  digits, `.`, `_`, `/` and `-`, starting with a letter or digit, with no `..` and not ending in
  `/` or `.lock`. It cannot start with `-`, so neither git nor `vcs import` can read it as an
  option.
- No string key or value may contain a control character (newline, carriage return, tab, ...),
  a line or paragraph separator, an invisible or bidirectional formatting character (zero-width
  space, byte-order mark, right-to-left override) or a space other than the ASCII one. The rule
  is applied to mappings, sequences and the strings in them. A key or value YAML builds as bytes
  (`!!binary`), and a string inside any other collection YAML can build (such as `!!set`,
  `!!pairs` or `!!omap`) under a key the tool ignores, are not checked by this rule
  ([#447](https://github.com/rolker/agent_workspace/issues/447)).
- YAML aliases (`*name`) and repeated mapping keys are refused. A YAML error is reported with at
  most a line and column, never with the document's text; a value YAML cannot build (`!!int
  0xz`, an unquoted `2024-13-45`) is reported as invalid YAML with no position. An integer past
  64 bits is refused.

As a second line, `resolve` refuses to write a header line, or a line of `layers.txt` or
`optional_layers.txt`, that holds any of those characters, or a file that would land outside
`--out`, and writes nothing in that case. The repository entries under a `.repos` header are not
checked again there; the character rule above is what keeps those characters out of them. The
`extends` clone states the transports git may use (`https`, `ssh`, `file`; everything else,
such as `ext::`, refused) on its own command line and in `GIT_ALLOW_PROTOCOL`, so a user's own
`protocol.<name>.allow=always` cannot widen them.

The tree of an `extends` base is untrusted too, so its clone uses none of the user's git
configuration that would run a program on it: no hook (a global `core.hooksPath` included), no
fsmonitor, no submodule, and no filter driver, text conversion, `ident` or encoding (the clone
checks nothing out; `.git/info/attributes` switches those off before `git reset --hard` checks
the commit out, so git-lfs's filter, which would contact a host the base names, never runs).
git's repository-locating environment variables (`GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`
and the rest of `git rev-parse --local-env-vars`, which git sets inside a hook) are removed;
`GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT`, the user's own settings such as credentials and
`url.<base>.insteadOf`, are kept. git runs in a session of its own with no terminal, stdin
closed, `GIT_TERMINAL_PROMPT=0`, an empty `core.askPass`, no `GIT_ASKPASS` or `SSH_ASKPASS`
and `SSH_ASKPASS_REQUIRE=never`, so neither git nor ssh can ask for a password or passphrase;
a credential helper you configured still runs. Each git call that asks the remote is limited to
`ROS_MANIFEST_GIT_TIMEOUT` seconds (default 60; set it in the environment to change it): when
the limit runs out, git and everything still in its process group are killed (a program that
left the group, which ssh does not, is not) and `resolve` fails, saying so. An interrupt, a
SIGTERM or a SIGHUP while git runs kills git's group the same way, removes the partial clone and
ends `resolve` by that signal.

A `url` or `ref` that fails its rule is never printed, nor is a group's `default` that is not
`include` or `exclude`; a failed `extends` clone gives git's exit status, not its output. Some
error messages do still print a value from the manifest: an `extends` path, an `optional_layers`
entry, an entry of a reference list (a group's `repos`; a role's `subtract`, `add` or `roots`; a
package's `repo`, `depend` or `exec_depend`), a key, and a name that fails its rule. Closing that
is [#447](https://github.com/rolker/agent_workspace/issues/447).

An unexpected error prints one line, `ERROR: internal error (<exception type>)`, and exits 1:
never the exception's text, never a traceback. Two cases still escape that line, also in #447:
Ctrl-C prints a traceback, and a broken pipe found at exit prints Python's `BrokenPipeError`
notice. Neither holds manifest text.

### The `extends` cache

A git-backed `extends` is cloned one commit deep (`git clone --no-checkout --branch <ref>
--depth 1`, then checked out as described above) into the cache directory (`--cache-dir`,
default `.ros-manifest-cache` in the current directory). The clone is made in a temporary
`.<key>.partial-*` directory beside its entry and renamed into place only when complete, so a
failed, timed-out or interrupted clone leaves no entry a later run would trust (a run killed
outright may leave a `.partial-*` directory, which is never read: delete it). An entry is reused on
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
