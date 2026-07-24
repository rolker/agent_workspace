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
- [ ] Fix: _rc_require_manifest — also require at least one non-comment
  layer entry in layers.txt; an empty/comment-only manifest currently lets
  build/test/env/setup loop zero times and report success (silent failure).
  Add a test with an empty layers.txt.
- [ ] Fix: _rc_distro — stop masking config-sourcing failures
  (`>/dev/null 2>&1 || true`); suppress stdout only (protects eval'd
  `adapter env` output), let stderr flow, and hard-error naming the config
  file when sourcing fails, matching single_project's config-failure
  semantics. Add a test with a failing config.
- [ ] Fix: _rc_ros_root — same masking problem; a broken config silently
  ignores the user's ROS_ROOT_DIR override and falls back to /opt/ros.
  Same fix shape as _rc_distro.
