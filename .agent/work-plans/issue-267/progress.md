---
issue: 267
---

# Issue #267 — Prototype a general ROS 2 manifest resolver (west-based) with a temporary home in the workspace (#172 step 4 re-scope)

## Plan
**Status**: complete
**When**: 2026-09-16 00:00
**By**: Claude Code Agent (claude-sonnet-5)

Plan file: `.agent/work-plans/issue-267/plan.md`.

Dual prototype: own resolver (Python, PyYAML-only, in `tools/ros-manifest/`) built and tested
this milestone against the real p11-jazzy manifest fixture; west-based variant specified in
`tools/ros-manifest/docs/west-variant.md` for the next milestone, not implemented yet. Role
model (groups vs. dependency closure) left open by design — both are built into the resolver so
the comparison is evidence-based.
