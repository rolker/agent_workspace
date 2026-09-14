---
issue: 237
---

# Issue #237 — ros2_colcon real-project smoke: register p11-jazzy against a fresh hosting dir and build (#172 step 6, phase 2)

## Smoke run (this machine, 2026-09-14)
**Status**: complete
**By**: Claude Code Agent (claude-fable-5-1)

Registry line (`.agent/projects.local`, per machine):

```
p11-jazzy    ros2_colcon   /home/roland/agent_workspace/projects/p11-jazzy
```

Per-project config (`.agent/projects.d/p11-jazzy.sh`):

```
ROS_DISTRO="jazzy"
MANIFEST_BOOTSTRAP_URL="https://raw.githubusercontent.com/rolker/unh_marine_autonomy/jazzy/config/bootstrap.yaml"
```

The hosting dir did not exist before this run.

| Verb | Result |
|------|--------|
| `setup` | Bootstrapped the manifest (Pattern B: `unh_marine_autonomy` cloned into `core_ws/src`, `configs/manifest` symlinked to its `config/`), then imported 7 layers / 44 repos. 24 s wall clock. |
| `validate` | ✅ checkout matches the manifest |
| `repos` | 44 `name:path` lines |
| `env` | eval-able; `ROS_DISTRO=jazzy` after eval |
| `project_root` | hosting dir |
| `scope_for_pr <pkg>/package.xml` | **failed** — `git -C` needs a directory. Fixed in both adapters (file paths resolve via parent), tests added. |
| `build` (`make build PROJECT=p11-jazzy`) | ✅ all 7 layers, 123 packages, 852 s wall clock (16 cores). Per layer: underlay 22 / 44 s, core 42 / 4m56, platforms 12 / 60 s, site 1 / 2 s, sensors 19 / 2m03, simulation 10 / 48 s, ui 17 / 4m36. Python packages emit the usual setuptools stderr noise; no failures. |
| `env` (post-build) | AMENT_PREFIX_PATH chain ends at the ui layer's installs, underlay-first order preserved |
| `validate` (post-build) | ✅ |

Hosting dir after build: 2.2 GB+ (`projects/p11-jazzy`, gitignored). The
`make` invocation ran from the issue worktree, whose path
(`worktrees/workspace/…`) the Makefile treats as its own root, so the
worktree's adapter and registry were exercised — not the main tree's.

### Findings
- Phase 1 deferred manifest bootstrap-from-URL; a fresh hosting dir was
  unusable without it (`setup` failed at `_rc_require_manifest`). Ported
  ros2's `setup_layers.sh` bootstrap non-interactively into `adapter_setup`.
- `scope_for_pr` rejected file paths (real-world call shape: a changed
  `package.xml`). Same bug in `single_project`; fixed together.
