---
issue: 210
---

# Issue #210 — Workspace redesign foundation: 10-verb adapter contract + single_project adapter

## Plan
**Status**: complete
**When**: 2026-05-17 (UTC)
**By**: Claude Code Agent (claude-opus-4-7)

Plan file: `.agent/work-plans/issue-210/plan.md`.

Approach: build bottom-up — dispatcher → `single_project` adapter (10 verb facades) → config fields → validator → rewire `build`/`test`/`setup`/`sync` as dispatch shims → new `make install` → tests asserting delegation (not just exit code) → ADR-0011 superseding ADR-0003 in the same PR → AGENTS.md and review-guide cascade → validator wired to both pre-commit and CI → no-behavior-change verification on daddy_camp. Parent branch `feature/issue-172` was created off main as an empty integration branch so this PR can target it as the issue intends.

## Implementation
**Status**: complete
**When**: 2026-07-14 (UTC)
**By**: Claude Code Agent (claude-fable-5)

All 11 plan steps implemented (open questions resolved per the plan's
recommended answers: ADR supersession in same PR; workspace-config-only
resolution with `--from` reserved; validator in both pre-commit and CI;
`env` line protocol specified in the dispatcher header).

Verification: `test_adapter.sh` — 45/45 assertions pass (dispatcher failure
modes, per-verb delegation observability, shim chains); all 4 pre-existing
test suites still pass; `pre-commit run --all-files` clean (includes the new
validate-adapter-contract hook and shellcheck on all new scripts).

Deviations from plan (rationale in plan.md Implementation Notes):
- setup/sync implementations moved into `.agent/project_types/single_project/`
  (shim + callback would recurse); commits group the move with the shim
  rewiring so every commit stays green.
- Config-field step landed as documentation + default (`PROJECT_TYPE`
  defaults to `single_project`) because `project_config.sh` is per-machine
  and doesn't exist in the repo.
- Step 11 (daddy_camp parity run) could not run on this machine — no
  project/ or project_config.sh configured here. Run `make build && make test`
  comparison on a daddy_camp machine before merging to main.
