---
issue: 235
---

# Issue #235 — ros2_colcon adapter core: 10-verb contract for layered colcon workspaces with distro parameterization (#172 step 6, phase 1)

## External Review
**Status**: complete
**When**: 2026-07-24 12:10
**By**: Claude Code Agent (claude-fable-5)

**PR**: #236 — 1 review (Copilot), 3 comments, 3 valid, 0 false positives
**CI**: all-pass

### Actions
- [x] Fix: _rc_require_manifest — also require at least one non-comment
  layer entry in layers.txt; an empty/comment-only manifest currently lets
  build/test/env/setup loop zero times and report success (silent failure).
  Add a test with an empty layers.txt.
- [x] Fix: _rc_distro — stop masking config-sourcing failures
  (`>/dev/null 2>&1 || true`); suppress stdout only (protects eval'd
  `adapter env` output), let stderr flow, and hard-error naming the config
  file when sourcing fails, matching single_project's config-failure
  semantics. Add a test with a failing config.
- [x] Fix: _rc_ros_root — same masking problem; a broken config silently
  ignores the user's ROS_ROOT_DIR override and falls back to /opt/ros.
  Same fix shape as _rc_distro.

## External Review (round 2)
**Status**: complete
**When**: 2026-07-24 12:35
**By**: Claude Code Agent (claude-fable-5)

**PR**: #236 — round 2 (head 924c6d7): 2 comments, 1 valid, 1 false positive
**CI**: all-pass

### Actions
- [x] Fix: validate layer names in _rc_require_manifest — layers.txt
  entries build filesystem paths unvalidated; '../x' would escape the
  hosting dir. Restore the ros2 setup_layers.sh rule (^[A-Za-z0-9_-]+$,
  which also excludes '.'), fail loud on violation, add a traversal test.
- [x] No action: grep '^distro:' anchoring is correct — bootstrap.yaml is
  the established flat top-level-key format (ros2 setup_layers.sh parses
  git_url/branch/layer with the same ^key: anchors); a leading-whitespace
  distro: would be a NESTED YAML key that top-level parsing must not
  match (it could belong to a future variant-scoped mapping). The miss
  path is loud and actionable, not silent.

## External Review (round 3)
**Status**: complete
**When**: 2026-07-24 13:00
**By**: Claude Code Agent (claude-fable-5)

**PR**: #236 — round 3 (head 7084845): 1 comment, 1 valid, 0 false positives
**CI**: all-pass

### Actions
- [x] Fix (human-approved 2026-07-24): add
  test_ros2_colcon.sh to validate.yml's Validate Adapter Contract job,
  which already runs test_adapter.sh. test_project_registry.sh (#227) has
  the same gap and should be added in the same step. Without this, adapter
  regressions can merge unnoticed — enforcement-over-documentation says
  the suites belong in CI.

## External Review (round 4)
**Status**: complete
**When**: 2026-07-24 13:20
**By**: Claude Code Agent (claude-fable-5)

**PR**: #236 — round 4 (head 1dd194f): 1 comment (4 locations), 1 valid
**CI**: all-pass (both new suites green on the runner)

### Actions
- [ ] Fix: scope the nounset relaxation to the ROS source calls only —
  adapter_build/adapter_test currently `set +u` at function top and never
  restore, weakening the adapter's own logic. Add a _rc_source_setup
  helper (set +u; source; set -u) with a fail-loud error at each call
  site; drop the function-top set +u lines.
