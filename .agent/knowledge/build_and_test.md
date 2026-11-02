# Build & Test

Build and test configuration, moved here from `AGENTS.md` (issue #259).

Build and test commands are project-specific. Configure them in `.agent/project_config.sh`
(gitignored, per-developer):

```bash
# .agent/project_config.sh
PROJECT_TYPE="single_project"  # project-type adapter (ADR-0011); defaults to single_project
BUILD_CMD="make"       # or: cmake --build build, cargo build, npm run build, etc.
TEST_CMD="make test"   # or: cargo test, pytest, npm test, etc.
INSTALL_CMD=""         # optional deploy/install command; empty = make install no-ops
```

Then run:

```bash
make build    # runs BUILD_CMD in project/
make test     # runs TEST_CMD in project/
make install  # runs INSTALL_CMD (no-op when unset)
make lint     # pre-commit on all files
make validate # check workspace config
make dashboard
```

These dispatch through the project-type adapter (`.agent/scripts/adapter`),
which resolves `PROJECT_TYPE` and calls that type's implementation in
`.agent/project_types/<type>/adapter.sh`. See ADR-0011.
