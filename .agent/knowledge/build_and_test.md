# Build & Test

Build and test configuration, moved here from `AGENTS.md` (issue #259).

Build and test commands are project-specific. A registered project's commands live in its settings
file `.agent/projects.d/<name>` (gitignored, per machine; issue #332), written with
`.agent/scripts/project_setting.sh` (or by `register_project.sh --set` at registration):

```bash
.agent/scripts/project_setting.sh set <name> build=make "test=make test"
.agent/scripts/project_setting.sh set <name> install=none   # a recorded "no install step"
.agent/scripts/project_setting.sh check <name>
```

Each value is one command, split on blanks and run without a shell from the project root; anything
that needs a shell is a script the key points at (`build=./scripts/build.sh`). A `ros2_colcon`
project's build and test come from colcon, so only `install` (and `bootstrap_url` or `source`) apply
to it. The settings file is the only source: issue #265 part 4 retired the shared
`.agent/project_config.sh` and the per-project `.agent/projects.d/<name>.sh`, which no script reads
for a value; `make validate` and `make dashboard` name any still on disk and what is left in them to
move.

Then run:

```bash
make build PROJECT=<name>    # runs the project's build setting in its root
make test PROJECT=<name>     # runs its test setting
make install PROJECT=<name>  # runs its install setting (no-op when unset or none)
make lint                    # pre-commit on all files
make validate                # check workspace config
make dashboard
```

Without `PROJECT=`, the project is the registered root the current directory is in; from the
workspace with nothing selected these refuse and list the registered projects (`make sync` alone
then syncs the workspace).

These dispatch through the project-type adapter (`.agent/scripts/adapter`), which takes the type from
the project's registry line and calls that type's implementation in
`.agent/project_types/<type>/adapter.sh`. See ADR-0011.
