---
issue: 265
---

# Issue #265 — Step 5: hosted projects under projects/ with project-rooted sessions and per-project CLAUDE.md

## Plan
**Status**: complete
**When**: 2026-09-15 14:29
**By**: Claude Code Agent (claude-sonnet-5)

Plan file: `.agent/work-plans/issue-265/plan.md`.

Formalizes `projects/<name>/` as the primary hosting shape: `adapter setup`
renders a per-project `CLAUDE.md` from a per-type template; the legacy
`project/` symlink gets a deprecate-and-warn path (not hard removal) with
a migration helper; out-of-tree projects use a physical bind-mount under
`projects/<name>/` (per the logical-vs-physical-path test in the issue
comment) rather than a symlink, since Claude Code resolves `process.cwd()`
past symlinks and never walks the logical ancestor chain; the `.claude/`
launch-dir limitation (skills/hooks/commands not ancestor-walked) is
documented, not worked around.

## Plan (revision 2)

**Status**: complete
**When**: 2026-09-16
**By**: Claude Code Agent (claude-fable-5-1)

Plan rewritten as the design-B definition after the owner's 2026-09-16
direction (issue comments) and the eight-experiment spike
(`spike-results.md`, Claude Code 2.1.273; four experiments re-run by the
owner with real credentials). Projects live anywhere; separate session
roots; worktrees under each root; workspace + project layers injected by a
registry-gated user-tier SessionStart hook (ancestor loading does not cross
a worktree boundary, so ancestry is not relied on); registry gains
`parent`/`worktrees`/`role`/`distro`; `project/` and `projects/` retired
outright; four additive PRs; acceptance test on real `gz4d` issues. Design A
recorded as set aside with the finding that removed its advantage. Manifest
support (step 4) re-scoped to #267 (general ROS manifest resolver).

## Plan review

**Status**: complete (findings applied)
**When**: 2026-09-16
**By**: independent Sonnet reviewer via /review-plan; findings applied by Claude Code Agent (claude-fable-5-1)

Nine findings, one Concern (user-tier allow-rules for scripts with no
registry awareness). Applied: `require_registered_root` guard + generated
allow-list manifest + behaviour test; legacy no-entry worktree fallback for
the PR 2→4 window; heading-drift test for the SessionStart renderer;
`dashboard.sh` substring logic called out; parent-root instance selection
decided (pending owner confirmation); project11 cycle stated as not
depending on #267; `registry_resolve_from_dir` claim corrected; discovery-
order change moved into the new ADR; PR title fixed. Review posted on PR
#266.

## Implement — PR 1 of 4 (registry)

**Status**: complete
**When**: 2026-09-16
**By**: Claude Code Agent (claude-fable-5-1)

Commit `35ea1ed`: trailing `key=value` registry fields (`parent`,
`worktrees`, `role`, `distro`, `default_instance`), parent roots
(pseudo-type `project`), `registry_entries_full` / `registry_field` /
`registry_instances` / `registry_default_instance` /
`registry_worktree_dir` (legacy fallback until PR 4) /
`registry_require_root`; adapter parent→instance resolution and
`ACTIVE_PROJECT_ROLE/DISTRO`; ros2_colcon distro from the registry with
manifest-mismatch hard error; worktree_create parent handling; validate and
dashboard parent awareness; Python parser parity. 15 new tests; all suites
green; pre-commit clean. Docs: ARCHITECTURE.md, WORKTREE_GUIDE.md,
projects.local.example, ROADMAP rows for steps 4/5 and cutover rows 1–3.

## Local Review
**Status**: complete
**When**: 2026-09-16 17:40 -04:00
**By**: independent reviewer (claude-sonnet-5), fresh context, in-process
**Verdict**: changes-requested

**PR**: #266 at `90b8c62`
**Mode**: post-PR
**Depth**: standard (reason: registry/adapter/worktree-lifecycle infrastructure)
**Must-fix**: 6 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — six open must-fixes incl. a parser whose result depends on the caller's cwd

### Findings
- [x] (must-fix) unquoted `$rest` word-splits with pathname expansion — `_project_registry.sh:97`
- [x] (must-fix) CRLF: shell keeps `\r` in paths, Python strips it (parity) — `_project_registry.sh:72`
- [x] (must-fix) absolute `worktrees=` outside the root passes parse but fails `registry_require_root` — `_project_registry.sh:130`
- [x] (must-fix) legacy fallback concatenates an unvalidated name (`../../outside`) — `_project_registry.sh:348`
- [x] (must-fix) parent→instance resolution only in create; enter/remove use the raw name — `worktree_enter.sh:167`, `worktree_remove.sh:144`
- [x] (must-fix) dashboard reports a parent with zero instances as healthy — `dashboard.sh:160`
- [x] (suggestion) two entries resolving to one canonical path accepted — `_project_registry.sh:360`
- [x] (suggestion) registry `distro=` regex allows hyphens; adapter's does not — `ros2_colcon/adapter.sh:158`
- [x] (suggestion) plan names `require_registered_root`; code is `registry_require_root` — `plan.md:249`
- [ ] (suggestion) workflow script branches on the pseudo-type vs ADR-0011 — `worktree_create.sh:337` (deferred to the new ADR, PR 3)
- [x] (suggestion) "first definition wins" stated only in the Python parser — `_project_registry.sh` header

## Integrated Review
**Status**: complete
**When**: 2026-09-16 17:45 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #266 at `90b8c62`
**Sources**: Copilot round 1 (4, at `9b790c5`), Copilot round 2 (6, at `90b8c62`), Local Review round 1 (11)
**Cross-source confirmations**: 5 — unquoted glob, `worktrees=` root bound, legacy-fallback name, create/enter/remove inconsistency, stale plan name (Copilot r2 ∩ Local Review r1); dashboard empty-parent (Copilot r2 ∩ Local Review r1)
**Local-only**: CRLF parity, aliased paths, distro regex parity, config-fallback comment, doc asymmetry
**False positives**: none

### Fix plan
- [x] all six must-fixes (see Local Review round 1)
- [x] aliased/duplicate canonical paths rejected in both parsers
- [x] distro regex aligned with ros2_colcon; role keeps hyphens
- [x] ros2_colcon comment: ROS_DISTRO config is a pure fallback
- [x] plan.md helper name
- [ ] ADR-0011 pseudo-type branch — carried to the new ADR (PR 3)

## Implementation
**Status**: complete
**When**: 2026-09-16 17:58 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #266 at `063b76b`
Addressed every open item of the Integrated Review in one commit
(`063b76b`) with tests: glob safety, CRLF, worktrees bound, fallback name
validation, aliased paths, distro/role regexes, create/enter/remove round
trip via the shared `registry_resolve_project_arg`; Python parity test
extended. Registry suite 146, adapter 86, ros2_colcon 184; pre-commit and
CI green. Next: re-review (round 2) for the ship verdict.

## Local Review
**Status**: complete
**When**: 2026-09-16 13:17 -04:00
**By**: independent reviewer (claude-sonnet-5), fresh context, round 2
**Verdict**: changes-requested

**PR**: #266 at `063b76b`
**Mode**: post-PR
**Depth**: standard (reason: registry/adapter/worktree-lifecycle infrastructure)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 2 | **Ship**: recommended (must-fix count down from 6 to 2, both mechanical, not rising) — apply the two fixes in this round, then merge

### Findings
- [ ] (must-fix) `_registry_field_of` still does unquoted `for f in $fields` (word-splitting/pathname expansion on every getter call — `registry_field`, `worktrees`/`parent`/`default_instance` lookups all go through it) — `_project_registry.sh:230`
- [ ] (must-fix) root-bound check (`_registry_path_under`, both parsers) is lexical only; `worktrees=../outside` is accepted and resolves one level above the workspace root (confirmed empirically in both the shell and Python parser) — `_project_registry.sh:165`, `lib/workspace.py:168`
- [ ] (suggestion) plan.md still names the guard `require_registered_root` at one of its three mentions; the other two were fixed to `registry_require_root` — `plan.md:247`
- [ ] (suggestion) the "python parser agrees with the shell parser" test never runs the shell parser — it only runs `workspace.read_projects_registry()` and diffs against a hard-coded string, so a shell-side regression would not be caught — `test_project_registry.sh:811`
- [ ] (suggestion, carried from round 1, unchanged) `worktree_create.sh` branches directly on the `project` pseudo-type instead of routing through the adapter, per ADR-0011 — deferred to the new ADR (PR 3) — `worktree_create.sh:339`

## Implementation
**Status**: complete
**When**: 2026-09-16 18:40 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #266 (round-2 fixes)
Both round-2 must-fixes closed: `_registry_field_of` iterates an array
(no globbing on any getter call); `worktrees=` and entry paths are
lexically normalized before the containment check in both parsers, so
`../outside` is rejected and an in-root `..` is kept normalized. The two
suggestions closed too: the last stale `require_registered_root` mention
in plan.md; the parity test now runs BOTH parsers on one sandbox (13
lines incl. CRLF, alias collision, `..` escape, distro regex) and asserts
identical entries and errors. Deferred, unchanged: the ADR-0011
pseudo-type note (new ADR, PR 3). Registry suite 154, adapter 86,
ros2_colcon 184, merge_pr 5; pre-commit clean.

## Implementation (PR 2)
**Status**: complete
**When**: 2026-09-16 (date per session)
**By**: Claude Code Agent (claude-sonnet-5)

**PR**: "feat(#265): worktrees under each registered root (step 5, PR 2 of 4)"
(branch `feature/issue-265-pr2`), built on PR 1 (#266, merged).

Implements plan §4 ("Worktrees under the root"): every script that walked
`<ws>/worktrees/project/<repo>/` now resolves a project's worktree dir via
`registry_worktree_dir` (PR 1), iterating the registry instead of assuming
`$PWD` is the workspace. Scope, precisely:

- `_worktree_helpers.sh`: sources `_project_registry.sh` itself so every
  caller gets registry helpers for free; `wt_project_base` now delegates
  to `registry_worktree_dir` (registered name -> its own root/override,
  unregistered name -> the pre-#265 fallback, unchanged); new
  `wt_registry_worktree_dirs` / `wt_legacy_worktree_dirs` enumerate every
  registered non-parent root's (existing) worktree dir plus the legacy
  fallback; `wt_count_project_worktrees` sums worktree counts across both
  for dashboard.sh; `wt_resolve_project_repo_root` resolves a project's
  checkout root (explicit name / legacy `project/` / the single registered
  project) for merge_pr.sh's PR/branch resolution; `wt_ensure_exclusion`
  writes `<root>/.git/info/exclude` (append-if-absent) and, for
  `ros2_colcon` roots, an untracked `worktrees/COLCON_IGNORE` marker —
  idempotent, never touches a tracked file, a no-op for unregistered
  projects (their fallback location is already under the workspace's own
  gitignored `worktrees/`).
- `worktree_create.sh`: calls `wt_ensure_exclusion` for a registered
  project right before the first worktree lands under its root.
- `worktree_enter.sh` / `worktree_remove.sh`: `--project`-less auto-detect
  now scans the registry (+ legacy fallback) instead of globbing
  `<ws>/worktrees/project/*`; the `EnterWorktree`-toplevel fallback in
  `worktree_enter.sh` also recognizes a toplevel one level under any
  registered root's worktree dir.
- `worktree_list.sh`: registry-driven enumeration replaces the
  `worktrees/project/*/` glob; footer text updated.
- `merge_pr.sh`: the project checkout root used for PR/branch resolution,
  the manifest scan for package worktrees, the post-merge worktree
  removal, and the final branch-delete/sync step all resolve through
  `wt_resolve_project_repo_root` / `wt_registry_worktree_dirs` instead of
  hardcoding `$ROOT_DIR/project`; `--project` is forwarded to
  `worktree_remove.sh` when given.
- `dashboard.sh`: self-location classification drops the dead
  `*/worktrees/project/*` / `*/project/worktrees/*` branches (dashboard.sh
  is workspace-only; a project worktree can never contain it post-#265);
  worktree counting uses `wt_count_project_worktrees`.
- Unregister-time orphaning (item 5): unchanged by design —
  `worktree_remove.sh` only ever deletes the specific worktree dir, never
  its parent, so an emptied `worktrees/` dir is left in place; documented
  inline. Unregistering a project is PR 4's concern.
- `cross_model_review.sh --work-dir` (item 6): verified — its default
  (no `--work-dir`) resolves via `_resolve_work_plans_dir.sh`, which uses
  `git rev-parse --show-toplevel` / `$WORKTREE_ISSUE`, neither of which
  hardcodes a worktree location. No change needed.
- Docs: `.agent/WORKTREE_GUIDE.md` and `ARCHITECTURE.md` describe the new
  per-root location, the transition fallback, and the exclusion/
  COLCON_IGNORE writes. `.agent/projects.local.example` already matched
  (no wording changes needed).
- Tests: extended `test_project_registry.sh` (existing worktree-location
  assertions updated to the new per-root paths; new: legacy-still-works
  end to end, out-of-tree registered-root exclusion + idempotency,
  `ros2_colcon` `COLCON_IGNORE`, no-op on an unregistered name, registry
  enumeration for dashboard's counting function, and a full
  create -> merge_pr-driven removal cycle under an out-of-tree root),
  `test_ros2_colcon.sh` (path assertions updated to the new location under
  the instance's own root; `.worktree-repos` manifest behaviour
  unaffected), `test_merge_pr.sh` (new: a registered out-of-tree project's
  PR is resolved and its worktree, under its own root, is cleaned up).

**Results**: test_project_registry 180/180, test_adapter 86/86,
test_ros2_colcon 184/184, test_merge_pr 85/85,
test_merge_pr_root_resolution 5/5, test_cross_model_review 52/52,
test_resolve_work_plans_dir 21/21 — all green.

**Not in this PR** (deferred per plan's PR sequence): the user tier (hook,
install/check, skill `session_scope`, tool-mapping guard, permissions
subset, `register_project.sh`, `register-project` command) is PR 3;
retiring `project/`/`projects/`, the `projects/<name>` default path, and
migrating p11 instances is PR 4.

## Local Review
**Status**: complete
**When**: 2026-09-16 (date per session)
**By**: independent reviewer (claude-sonnet-5), fresh context, round 1
**Verdict**: changes-requested

**PR**: #273 at `6737065`
**Mode**: post-PR
**Depth**: standard (reason: registry/adapter/worktree-lifecycle infrastructure; skip fork-only cross-model tooling)
**Must-fix**: 1 | **Suggestions**: 2
**Round**: 1 | **Ship**: continue — one must-fix (a skill's plan-file fallback glob doesn't cover the registered-root location this PR just introduced)

### Findings
- [x] (must-fix) `review-plan`'s plan-file fallback glob only searches `worktrees/project/*/issue-*-<N>/` (the workspace tree); it can never find a plan file for a project worktree under a registered out-of-tree root, the exact case PR 2 makes real — `.claude/skills/review-plan/SKILL.md:62`
- [x] (suggestion) `WORKFORCE_PROTOCOL.md` and `start-task/SKILL.md` still state the pre-#265 `worktrees/project/<repo>/...` location unconditionally, with no mention of the registered-root case or the transition fallback; acceptable to defer to PR 3's skill-path pass per the plan's PR sequencing, but worth flagging so it isn't dropped — `.agent/WORKFORCE_PROTOCOL.md:27`, `.claude/skills/start-task/SKILL.md:136`
- [x] (suggestion) `merge_pr.sh`'s ambiguous-registration case (`WORKTREE_TYPE=project`, no `--project`, more than one non-parent project registered) prints `wt_resolve_project_repo_root`'s error to stderr but doesn't exit — falls through with `PJ_REPO_ROOT=""` into the rest of the script rather than failing fast; not covered by a test — `.agent/scripts/merge_pr.sh:206-213`

## Implementation

**Status**: complete
**When**: 2026-09-16
**By**: Claude Code Agent (claude-sonnet-5)

**PR**: #273 at `34c6e1e`

Addressed every open item of the round-1 Local Review:

- `.claude/skills/review-plan/SKILL.md:62` (must-fix) — `eac75e9`: the
  `--issue <N>` fallback now sources `_worktree_helpers.sh` and enumerates
  `wt_registry_worktree_dirs` + `wt_legacy_worktree_dirs` (every registered
  root's worktree dir, plus the legacy fallback) instead of only globbing
  `worktrees/project/*/issue-*-<N>/`; hermetic test
  `test_review_plan_issue_fallback_finds_plan_under_registered_root` added
  to `test_project_registry.sh`, driving the exact helper invocation the
  skill prescribes.
- `.agent/scripts/merge_pr.sh:206-213` (suggestion) — `ec4250b`: when
  `--type project` is explicit and `wt_resolve_project_repo_root` fails
  (ambiguous registration, nothing configured, etc.), the script now exits
  1 with the resolver's error instead of falling through with
  `PJ_REPO_ROOT=""` (which line ~485 would otherwise default to
  `$ROOT_DIR/project`, silently operating on the wrong or a nonexistent
  checkout). `test_ambiguous_project_root_type_project_fails_fast` added
  to `test_merge_pr.sh`.
- `.agent/WORKFORCE_PROTOCOL.md:27`, `.claude/skills/start-task/SKILL.md:136`
  (suggestion) — `34c6e1e`: one sentence each noting a registered project's
  worktrees live under its own root (`registry_worktree_dir`) and that
  `worktrees/project/<repo>/` is the legacy/unregistered fallback. No
  larger rewrite (that's PR 3).

**Results** (all seven suites): test_project_registry 182/182, test_adapter
86/86, test_ros2_colcon 184/184, test_merge_pr 88/88,
test_merge_pr_root_resolution 5/5, test_cross_model_review 52/52,
test_resolve_work_plans_dir 21/21 — all green.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 11:23 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-265-pr2 at `fd8e935`
**Base**: main
**Depth**: Deep (reason: 16 files, 790 lines; every worktree script + two skills)
**Must-fix**: 4 | **Suggestions**: 1
**Round**: 1 | **Ship**: continue — round 1: 4 must-fix, one a design gap (transition orphaning), one an ADR-0012 human call

### Findings
- [ ] (must-fix) registering a project orphans its pre-existing legacy-path worktrees: enumeration skips names that resolve in the registry, and remove's explicit --project path never searches the transition location — `.agent/scripts/_worktree_helpers.sh:91-101` (Copilot #1 confirmed)
- [ ] (must-fix) merge_pr compares the raw --project parent name against the manifest's resolved instance name, skipping the real manifest — `.agent/scripts/merge_pr.sh:458` (Copilot #2 confirmed)
- [ ] (must-fix) review-plan's --issue fallback never checks the workspace worktree its prose says to check first — `.claude/skills/review-plan/SKILL.md:61-75` (Copilot #3 confirmed)
- [ ] (must-fix) ADR-0012: wt_ensure_exclusion branches on `etype = ros2_colcon` inside the shared helper; the plan specified the COLCON_IGNORE marker without routing it through an adapter verb — `.agent/scripts/_worktree_helpers.sh:192` (human call: adapter verb now, or documented scoped exception)
- [ ] (suggestion) AGENTS.md worktree section still describes the old location; plan defers to PR 4 (Ask-First) — `AGENTS.md`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 12:06 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-265-pr2 at `38e0f14`
**Base**: main
**Depth**: Deep (reason: re-review of the four round-1 fixes; Copilot's second pass integrated)
**Must-fix**: 2 | **Suggestions**: 0
**Round**: 2 | **Ship**: continue — round-1 items all fixed; Copilot's second pass found 2 new must-fix in the same subsystem, fixed in de4589b

### Findings
- [x] (must-fix) legacy project/ create resolved its worktree dir through the registry; a same-named registered project captured it under the wrong root — `.agent/scripts/worktree_create.sh:548` (Copilot #4 confirmed) → fixed
- [x] (must-fix) wt_legacy_worktree_dirs / wt_transition_project_base treated a malformed registry (rc 2) like "not registered" and enumerated on partial state — `.agent/scripts/_worktree_helpers.sh:101` (Copilot #5 confirmed) → fixed; enter/remove refuse

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 12:14 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-265-pr2 at `de4589b`
**Base**: main
**Depth**: Deep (reason: re-review of the round-2 fixes and their fail-closed story end to end)
**Must-fix**: 1 | **Suggestions**: 0
**Round**: 3 | **Ship**: continue — round-2 items fixed; one display-layer gap in the same fail-closed story, fixed in 2503896

### Findings
- [x] (must-fix) worktree_list.sh silently showed 0 project worktrees on a malformed registry (fail-open at the display layer) — `.agent/scripts/worktree_list.sh:324` → fixed: warning + NOT LISTED
