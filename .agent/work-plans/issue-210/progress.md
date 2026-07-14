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
- Step 11's parity gate generalized: it must not depend on daddy_camp (a
  project this workspace hosts in another context). Behavioral parity is
  pinned by the sandboxed test suite against synthetic projects; pre-adapter
  configs resolve to `single_project` and behave identically.

## Local Review
**Status**: complete
**When**: 2026-07-14 (UTC)
**By**: Claude Code Agent (claude-fable-5)
**Verdict**: changes-requested

**PR**: #211 at `c5d1452`
**Depth**: Deep (reason: 20 files / 1815 lines + enforcement & governance files)
**Must-fix**: 3 | **Suggestions**: 10

### Findings
- [ ] (must-fix) `|| return 1` disables errexit inside `_single_project_load_cmd`; a failing `source project_config.sh` is swallowed and build/test/install proceed — breaks the zero-behavior-change claim — `.agent/project_types/single_project/adapter.sh:35`
- [ ] (must-fix) `scope_for_pr` mis-parses `ssh://host:port/owner/repo` URLs: SCP-form regex matches first and silently returns `port/owner` — `.agent/project_types/single_project/adapter.sh:127`
- [ ] (must-fix) Validator false-passes an adapter whose top-level code calls `exit 0` (prints "all verbs implemented"); top-level `exit 1` kills the validator with no diagnostic — `.agent/scripts/validate_adapter.sh:44`
- [ ] (suggestion) `PROJECT_TYPE` inherited from caller environment, new env sensitivity vs old scripts — `.agent/scripts/adapter:66`
- [ ] (suggestion) `WORKSPACE_ROOT`/`ADAPTER_TYPE_DIR` exported into every BUILD/TEST/INSTALL process env — `.agent/scripts/adapter:118`
- [ ] (suggestion) config sourced twice per invocation; first source's failures fully hidden — `.agent/scripts/adapter:66`
- [ ] (suggestion) adapter source-time stdout pollutes machine-read verbs (`env` is eval'd by callers) — `.agent/scripts/adapter:121`
- [ ] (suggestion) sync shim execs at import time; wrap in `if __name__ == "__main__"` — `.agent/scripts/sync_project.py:11`
- [ ] (suggestion) test gaps: no exit-code-propagation tests (plan step 7 promised them), unguarded `$(...)` asserts abort suite under set -e, shim-chain build test doesn't assert cwd, moved sync.py's lib import never executed — `.agent/scripts/tests/test_adapter.sh`
- [ ] (suggestion) validator: empty project_types glob gives misleading `*` diagnostic; export `ADAPTER_TYPE_DIR` before sourcing — `.agent/scripts/validate_adapter.sh:33`
- [ ] (suggestion) README.md config example lacks `PROJECT_TYPE`/`INSTALL_CMD`; Common Commands lacks `make install` — `README.md:42`
- [ ] (suggestion) `.agent/knowledge/README.md:20` claims setup_project.sh creates the workspace-context symlink — it never did (pre-existing, surfaced by move)
- [ ] (suggestion) scheme regex `^[a-z+]+://` misses digits/uppercase schemes; harden while fixing the SSH-port bug — `.agent/project_types/single_project/adapter.sh:130`

Pre-existing defects surfaced (follow-up issues, not PR regressions):
`sync_gitbug` uses invalid `git bug bridge list` so git-bug sync never ran;
no `rebase --abort` on failed `pull --rebase` (setup.sh + sync.py); broken
symlink at `project/` defeats setup cleanup. Tooling: cross_model_review.sh
gemini binary renamed to `agy`; copilot `-p` bug confirmed (#212);
`_resolve_work_plans_dir` requires `WORKTREE_ISSUE`, which EnterWorktree-based
`/start-task` sessions don't set.
