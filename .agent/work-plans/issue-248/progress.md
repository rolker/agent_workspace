---
issue: 248
---

# Issue #248 — ros2_colcon second distro instance: p11-rolling beside p11-jazzy, isolation smoke without a build (#172 step 6, phase 4)

## Smoke run (this machine, 2026-09-14)
**Status**: complete
**By**: Claude Code Agent (claude-fable-5-1)

Gate: rolker/unh_marine_autonomy#384 closed via PR #387 (merged into
`rolling` at 3a36e78) — the raw `rolling` bootstrap.yaml carries
`git_url`, `branch: rolling`, `layer: core`, `distro: rolling`.

Registry lines (`.agent/projects.local`, per machine):

```
p11-jazzy    ros2_colcon     /home/roland/agent_workspace/projects/p11-jazzy
p11-rolling  ros2_colcon     /home/roland/agent_workspace/projects/p11-rolling
```

Per-project config (`.agent/projects.d/p11-rolling.sh`) carries only
`MANIFEST_BOOTSTRAP_URL` (the branch's `distro:` key resolves the distro;
p11-jazzy still needs `ROS_DISTRO=jazzy` because the jazzy manifest has no
distro key). The p11-rolling hosting dir did not exist before this run.

| Check | Result |
|-------|--------|
| `setup` (p11-rolling) | ✅ bootstrapped from the rolling branch (Pattern B), 7 layers / 44 repos imported, 24 s |
| `validate` (p11-rolling) | ✅ checkout matches the rolling manifest |
| `validate` (p11-jazzy, after) | ✅ unchanged |
| `env` (p11-rolling) | scrub + `source /opt/ros/rolling/setup.bash` only (no layer built yet) |
| `env` (p11-jazzy) | scrub + `/opt/ros/jazzy` + its own seven layer installs |
| cross-reference grep | 0 mentions of the other instance's dir or distro in either env output |
| cwd discovery | from inside `p11-rolling/layers/main/core_ws/src` → p11-rolling; from inside `p11-jazzy/layers/main/ui_ws` → p11-jazzy |
| manifest branch per instance | jazzy → `jazzy`, rolling → `rolling` (same repo, separate checkouts) |
| `repos` | 44 entries in each |
| symlinks crossing hosting dirs | 0 |
| p11-jazzy build health | no-op incremental rebuild of its site layer: 1 package, 0.77 s |

**Not run, by decision:** `make build PROJECT=p11-rolling`. Every `.repos` pin
except the manifest repo is still its jazzy ref and no Rolling port exists;
a build is expected to fail and belongs to project-side porting work.

### Findings
- No adapter changes were needed. Distro resolution from the manifest,
  bootstrap into a fresh hosting dir, registry-based discovery, and the
  per-instance env chain all behaved as designed with two instances of the
  same project on one machine.
- The multi-distro = multi-instance rule (2026-07-24 decision) is
  load-bearing in the adapter: the clone-reuse guard only warns on a branch
  mismatch, so pointing a second instance at an existing hosting dir would
  reuse the first instance's manifest. Fresh hosting dir per instance is the
  contract; documented in the projects.local example.
