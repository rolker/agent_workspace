---
issue: 354
---

# Issue #354 — Pre-commit: run the script test suites only when a commit touches what they test (~133 s on every commit today)

## Issue Review
**Status**: complete
**When**: 2026-09-28 11:31 -0400
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #354

### Scope Assessment

**Well-scoped?** Yes — single, bounded change: add a `files:` regex to the
`validate-script-tests` pre-commit hook, following the existing
`validate-adapter-contract` pattern in the same file. The acceptance criteria
are concrete and checkable (regex coverage, docs-only skip, CI unaffected,
stale-cost text updated).

**Right repo?** Yes — `.pre-commit-config.yaml` and `.agent/scripts/tests/`
are workspace infrastructure, not project content.

**Dependencies**: None identified. Builds on #269 (which introduced the
always_run hook) but doesn't require any other open issue.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | OK | Narrows *when* the hook runs, doesn't remove it; CI (`make lint`) stays unconditional per ADR-0005's layering, so nothing is enforced only in docs. |
| Only what's needed | OK | Directly targets a measured, growing cost (10 suites/~18 s at #269 to 29 suites/~133 s today) rather than speculative tuning. |
| A change includes its consequences | Action needed | Issue names updating stale "~18 s" guidance but should also confirm no other doc/skill references the always-run cost or count (see below). |
| Test what breaks | Action needed | The acceptance criteria call for deriving the regex from what suites actually read, but the real risk — a future suite silently drifting outside the regex — needs its own regression test, not just careful derivation. Plan should name it explicitly. |
| Improve incrementally | OK | Small, reviewable, single-file-plus-tests change. |
| Workspace vs. project separation | OK | Pure workspace-infra change. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0004/0005 — Enforcement hierarchy / layered enforcement | Yes | Directly on point: local pre-commit is fast local feedback, CI is authoritative. Scoping the local hook while CI keeps running all suites is exactly the intended layering — issue already states this correctly. |
| ADR-0013 — progress.md entry-type vocabulary | Yes (process, not content) | Any progress.md entries this work produces must use canonical entry types via `review_progress.sh persist` / `progress_append.sh`. No effect on the fix itself. |
| Others (0001–0003, 0006–0012, 0014–0016) | No | Not a design-decision record, not adapter/project-type, not worktree/dispatch/session-root machinery. |

### Consequences

- Confirmed: no currently-live guidance doc (AGENTS.md, docs/roadmap.md,
  docs/design.md) states an "~18 s" or fixed suite-count figure for this
  hook — only the immutable issue-269 work-plan/progress history does,
  which is a historical record and shouldn't be rewritten. The issue's
  "update stale ~18 s guidance" acceptance item may therefore have no live
  target; the plan should confirm this rather than edit history.
- `.agent/scripts/tests/tests/test_pre_commit_config` or equivalent (none
  currently exists) — worth checking whether any script test already
  asserts on `.pre-commit-config.yaml` hook shape, since this change edits
  that shape.

### Recommendations

- In the plan, enumerate the path-family evidence per suite (script,
  skill/SKILL.md, template, adapter/project_type, Makefile, doc) rather
  than a single merged regex derivation, so a reviewer can check coverage
  claim-by-claim.
- Add a regression test asserting the `files:` regex matches every path
  referenced by the suites (e.g., derived from the same source list used
  to build the regex), so a new suite added later that reads outside the
  regex fails loudly instead of silently skipping.
- Verify the regex also covers `.pre-commit-config.yaml` itself and
  `Makefile`, since suites test hook/target wiring, not just script bodies.

### Actions
- [ ] Issue names updating stale "~18 s" guidance but should also confirm no other doc/skill references the always-run cost or count (see below).
- [ ] The acceptance criteria call for deriving the regex from what suites actually read, but the real risk — a future suite silently drifting outside the regex — needs its own regression test, not just careful derivation. Plan should name it explicitly.
- [ ] In the plan, enumerate the path-family evidence per suite (script, skill/SKILL.md, template, adapter/project_type, Makefile, doc) rather than a single merged regex derivation, so a reviewer can check coverage claim-by-claim.
- [ ] Add a regression test asserting the `files:` regex matches every path referenced by the suites (e.g., derived from the same source list used to build the regex), so a new suite added later that reads outside the regex fails loudly instead of silently skipping.
- [ ] Verify the regex also covers `.pre-commit-config.yaml` itself and `Makefile`, since suites test hook/target wiring, not just script bodies.

## Plan Authored
**Status**: complete
**When**: 2026-09-28 11:39 -0400
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-354/plan.md` at `ef453fd`

Scope the `validate-script-tests` pre-commit hook with a `files:` regex
(`^(\.agent/|\.claude/|AGENTS\.md$|Makefile$|\.pre-commit-config\.yaml$)`)
derived from every suite's real (non-sandbox) path reads, remove
`always_run: true`, and add a regression suite that parses the regex out
of `.pre-commit-config.yaml` and asserts it covers every real path any
other suite references — so a future suite reading outside the regex
fails loudly instead of silently skipping.

## Plan Review
**Status**: complete
**When**: 2026-09-28 11:44 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**PR**: https://github.com/rolker/agent_workspace/pull/355 — [PLAN] Pre-commit: run the script test suites only when a commit touches what they test (~133 s on every commit today)
**Issue**: #354 — Pre-commit: run the script test suites only when a commit touches what they test (~133 s on every commit today)
**Plan**: `.agent/work-plans/issue-354/plan.md` at `ef453fd`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One config line plus one test suite. |
| Issue alignment | Concern | The proposed regex skips almost no real commits (finding 1); "docs-only commit skips" holds for README/docs/ only, not for work-plans/progress commits. |
| File targeting | Good | `.pre-commit-config.yaml` plus the new suite; nothing missing. |
| Consequences | Good | Checked: no live doc states the ~18 s figure. |
| Principle alignment | Needs work | "Test what breaks": the proposed drift test mostly re-confirms paths already under `.agent/` and misses several idioms the suites actually use (finding 2). |
| ADR compliance | Good | ADR-0004/0005 layering is kept: CI `--all-files` still runs every suite. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment]** `^\.agent/` includes `.agent/work-plans/**`. Of the last 300 non-merge commits on main, 262 touch only `.agent/work-plans/` and only 4 would be skipped by the proposed regex. So the review loop's progress.md commits (`review_progress.sh persist` / `progress_append.sh` run `git commit`, and the hook fires on it) would still pay the ~133 s. The whole-tree argument does not hold for work-plans. `test_user_tier_install.sh` and `test_user_tier_guard.sh` `cp -r` `.agent`, but they only read `.agent/user_tier_scripts.txt`, `.agent/scripts/*` and `.agent/projects.local`, which they overwrite. The installer never reads work-plans. The only work-plans read is `test_checkpoint_269.sh`'s real gate, which does `git show <base>:.agent/work-plans/issue-269/progress.md`. That reads main's copy from git history, not the branch's staged file, so a branch commit cannot change it. Fix: add `exclude: ^\.agent/work-plans/` to the hook and keep the rest of the regex.
2. **[Principle alignment]** The extractor idioms (`cp "$REAL_ROOT/<path>"`, `"$WS_ROOT/<path>"`, `"$SCRIPT_DIR/../<path>"`) miss real forms that exist today:
   - `ROOT_DIR` in test_sync_gitbug.sh
   - `$(dirname x3)` in test_merge_pr.sh
   - `cp "$REAL_ROOT/.agent/scripts/$f"` loops in test_merge_pr_gate.sh and test_precommit_hook_path.sh
   - `"$WS_ROOT/$rel"` from a manifest in test_user_tier_guard.sh
   - `Path(__file__).parent.parent` in test_progress_read.py
   - git-history reads in test_checkpoint_269.sh

   It passes today only because every path is under `.agent/` anyway, which is false confidence. Suggested replacement: detect where a suite derives the repo root (`/../../..`, `show-toplevel`, triple `dirname`, `parents[`). Then require each such suite to name the out-of-tree paths it reads in an allowlist that the test checks against the regex, and fail on any new root-deriving suite that is not in the allowlist. That catches the risky case: a new suite reaching outside `.agent/`/`.claude/`.
3. **[Issue alignment]** Step 3 says the parser matches "other suites that read `.pre-commit-config.yaml`". The plan's own table says none read it. Drop that claim.

### Summary

The direction is right and the root-file coverage (AGENTS.md, Makefile) is correct. As written, though, the regex does not deliver the goal for the commits the loop makes most often, and the drift test checks the wrong thing. Once findings 1 and 2 are applied, the plan is ready.

### Recommended Actions

- [ ] Add `exclude: ^\.agent/work-plans/` (with a one-line rationale citing the user-tier suites' actual reads) and make the acceptance cover a progress.md-only commit skipping the hook.
- [ ] Rework the drift suite to detect repo-root derivation plus a declared-reads allowlist, not path-idiom extraction.
- [ ] Remove the incorrect "existing style" claim in step 3.
