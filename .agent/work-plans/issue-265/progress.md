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

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 12:21 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**Branch**: feature/issue-265-pr2 at `2503896`
**Base**: main
**Depth**: Deep (reason: verification of the round-3 list fix)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 4 | **Ship**: recommended — round-3 item fixed; two same-file consistency gaps (--json, pre-#25 scan) fixed in 97384ae; loop has run four rounds, merge decision handed to the owner per the standing rules

### Findings
- [x] (suggestion) --json summary showed project 0 with no malformed signal — `.agent/scripts/worktree_list.sh` → null + registry_malformed flag
- [x] (suggestion) pre-#25 project/worktrees scan ran outside the gate, contradicting the summary — `.agent/scripts/worktree_list.sh` → gated

## Merge (report-only)
**Status**: complete
**When**: 2026-09-17 13:12 -04:00
**By**: merge_pr.sh (Claude Code Agent)

**PR**: #273 at `1b5ff2d`
**Mode**: report-only
**Scope**: workspace
**Conditions**: latest Local Review entry is at `6737065`, not the PR head `1b5ff2d` (stale review)

## Checkpoint
**Status**: complete
**When**: 2026-11-16 12:38 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

Records the owner's merges of the earlier parts, made before this timeline kept merge answers: pull requests 266 (part 1, merged 2026-09-16), 273 (part 2, merged 2026-09-17) and 326 (part 3, delivered under issue 317, merged 2026-09-23), all shown as merged on GitHub. The host asked on 2026-11-16: "May I record on the timeline that you merged parts 1 to 3 of issue 265, so the drive can move on to planning part 4? (yes / no)". The owner answered: "yes".

His direction for part 4, given the same day when he started this drive: "265, pickerel does not have any projects yet so it has nothing to retire. We can retire the old project folders now. I did test the workspace at home as well with various project types, all outside the workspace dir structure so we are ready for this step."

## Checkpoint
**Status**: complete
**When**: 2026-11-16 12:38 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan dates from 2026-09-16 and was last reviewed before parts 2 and 3; part 3 was delivered under issue 317, and onboarding, the plugin and the session-root rule changed the ground since, so run-issue step 13 allows only revise)
**After**: plan
**Decision**: revise

The plan is rewritten for part 4 only (retire `project/` and `projects/` and the worktree fallback, and register the project11 instances, as the roadmap's deferral line words it), then reviewed, before any implementation. The owner's direction of 2026-11-16 goes into the plan-task and review-plan handoffs: "265, pickerel does not have any projects yet so it has nothing to retire. We can retire the old project folders now. I did test the workspace at home as well with various project types, all outside the workspace dir structure so we are ready for this step."

## Plan Authored
**Status**: complete
**When**: 2026-11-16 12:41 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-265/plan.md` at `a0460f10`

Revision 3, part 4 only: retire the `project/` symlink, the `projects/<name>` default and the `worktrees/project/` fallback so the registry is the only link. One pull request: registry and worktree scripts, dispatcher and project-reading scripts, a stale-shape warning in validate, skills and docs, tests. No directory on disk is removed; registering the project11 instances is out of scope (second-machine agent).

## Plan Review
**Status**: complete
**When**: 2026-11-16 12:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #265 — Step 5: hosted projects under projects/ with project-rooted sessions and per-project CLAUDE.md
**Plan**: `.agent/work-plans/issue-265/plan.md` at `a0460f10`
**Branch**: `feature/issue-265`

Revision 3, part 4 only (retire `project/`, the `projects/<name>` default and the `worktrees/project/` fallback). Judged against the source on this branch (main at 319f437a plus the plan), the issue and its comments, the issue 295 plan and timeline, and this machine's `.agent/projects.local`, `.agent/projects.d/` and `.agent/project_config.sh` (read only, nothing changed).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Concern | The issue 295 plan (2026-11-12, owner-directed fold of 2026-09-18) already plans this pull request as "B and C", which "Closes #265" and also removes the `.sh` and shared-config reading; revision 3 never cites it and drops C on a wrong ground (finding 1). About 60 files; split point after step 3 is the wrong cut (S1). |
| Issue alignment | Needs work | Serves line, as checked: "Goals 'Light touch on projects' and 'Flexibility' (README Workspace goals); design sections `docs/design.md#sessions-and-roots` with `docs/design.md#registry-and-adapters` and `docs/design.md#worktrees`." Correct and sufficient. Not covered: the two suggestions the owner ordered carried into this plan when pull request 454 merged (finding 6); the 2026-11-13 issue comment's `AGENTS.md:19-20` and the `gather-project-knowledge` question (finding 5, Q5); whether this closes #265 (finding 8). |
| File targeting | Needs work | Missed sites listed in finding 5 (both type adapters' `$WORKSPACE_ROOT/project` default, `registry_resolve_project_arg`, three knowledge/skill pages, two design register rows, the design `sync` row). |
| Consequences | Concern | "Removing the code paths changes no resolution" is false on this machine (finding 2); the adapter's no-project refusal breaks `make sync` and `test_fresh_clone_no_project.sh` (finding 3); the `projects/` warning fires falsely on two registered roots (finding 4). |
| Principle alignment | Needs work | "Test what breaks": one planned test exercises the existing guard, not the new code, and several changed scripts have no named refusal test (finding 7). "Keep one current design": design sections named, but the ADR register rows and the `sync` row are missing (finding 5). Prior art: does not name the issue 295 plan's B and C section, the nearest prior art (finding 1). |
| ADR compliance | Needs work | ADR-0016 decision 1 says "a project registered inside the workspace tree is still a project"; the step 4 warning treats such a root as a retired shape (finding 4). ADR-0017: met only if findings 5 and S1 are followed. ADR-0002/0011 left unedited and raised for the owner: correct per the new-ADR rule (Q4). ADR-0003: plan text is clean; tests touched still use a `p11` shape name (S3). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Scope] must-fix, needs a re-plan (and owner question Q1).** `.agent/work-plans/issue-295/plan.md` lines 5 and 80-107 plan "Pull request B and C (one pull request), closing issue 265": the `project/` and `projects/` fallbacks (B) and the `.sh`/shared-config reading (C, "item 4 of #265's plan"), with a per-key stale-file report and five owner-machine steps. That follows the owner's 2026-09-18 comment on #265 ("PR 4 (retire hosting): remove the workspace/project special cases at the same time as the `project/` / `projects/` fallbacks"); the collapse itself was later moved to #295's later pull requests, C was not. Revision 3 does not cite that plan and keeps the `.sh` layer because "#332 keeps it on purpose", but #332's own text calls it "the legacy projects.d/<name>.sh" (`_project_registry.sh` header lines 53 and 109-114) and design.md line 1015 calls it the legacy layer. On this machine the layer is load-bearing: `projects.d/p11-jazzy.sh` sets `ROS_DISTRO` and `MANIFEST_BOOTSTRAP_URL`, and the shared `.agent/project_config.sh` gives the single-repository project its `INSTALL_CMD` (its settings file holds only `build` and `test`). Re-plan: either include C (and the 295 plan's machine step 1 ordering, so the install command is not lost silently) or record the split explicitly, update the 295 plan's "closing issue 265" text, and put the scope change to the owner. Revision 3 also drops, without saying so, the 295 plan's grep acceptance (step 11), which this revision would benefit from (finding 5).

2. **[Consequences] must-fix, bounded instruction.** The claim "Every project here is registered with an absolute path, so removing the code paths changes no resolution" is false for every call that names no project. On this machine `~/agent_workspace/project` is a symlink to a git checkout and three non-parent projects are registered. Today `wt_resolve_project_repo_root` step 2 (`_worktree_helpers.sh:191`), `session_root.sh:204`, `worktree_create.sh:515`, and the adapter's legacy step 3 (`adapter:258`, used by `make build`, `make test`, `make install`, `make sync` from the workspace root with no `PROJECT=`) all resolve to that checkout. After the change each refuses ("multiple projects registered") and `make sync` from the workspace root syncs only the workspace. Loud, so acceptable, but the implement pass must state this in the plan's place in the PR description and in the design change-log row, and test "a `project/` checkout present, three registered, no name: refuses naming `--project`".

3. **[Consequences] must-fix, bounded instruction.** Step 3's dispatcher refusal ("with no `--project` and a cwd in no registered root, exit with a message") applies to `sync` too: `make sync` reaches `adapter sync` (`sync_project.py`), and with nothing resolved it takes the legacy branch today. That breaks `test_fresh_clone_no_project.sh` assertions (d) and (f) (lines 147-240), which the plan says "stays", and the design.md Now bullet (line 300: "`make sync` succeed[s]"). Carry the 295 plan's exception: `sync` with no project syncs the workspace alone and prints the existing "No project was synced" line; every other verb refuses. Name which code path runs that workspace-only sync once `_resolve_project_type` and the `project/` default are gone, and keep the fresh-clone suite green unchanged.

4. **[ADR compliance] must-fix, bounded instruction.** Step 4 warns "when a registered path lies under the workspace's `projects/`" that "the shape is no longer read". ADR-0016 decision 1 allows a project registered inside the workspace tree (and `test_user_tier_install.sh`, `skill_prefix.sh` use one). On this machine `p11-jazzy` and `p11-rolling` are registered at `~/agent_workspace/projects/…`, so the warning fires on every `make validate` with a false message. Warn instead on what the retired default would have read: a directory under `<ws>/projects/` that no registry entry owns; keep the `<ws>/project` and `<ws>/worktrees/project/` legs. Test the registered-in-tree case as silent.

5. **[File targeting] must-fix, bounded instruction.** Sites the plan misses, from `grep` on this branch: `.agent/project_types/ros2_colcon/adapter.sh:73` and `.agent/project_types/single_project/adapter.sh:220` (`${ACTIVE_PROJECT_ROOT:-$WORKSPACE_ROOT/project}`) and the single_project header line 3; `_project_registry.sh` `registry_resolve_project_arg` (lines 481-500: an unregistered name "is printed back unchanged so legacy callers keep working"; it should refuse with the `register_project.sh` remedy) and the `registry_worktree_dir` comment (502-508); `_worktree_helpers.sh` `wt_ensure_exclusion` comment ("the transition fallback") and `wt_count_project_worktrees`; `lib/workspace.py` helpers `get_project_path`, `is_project_configured`, `get_project_remote_url` (delete once `sync.py` stops importing them, not only line 248); `register_project.sh:26` header; `.claude/skills/review-code/SKILL.md:251` and `.agent/knowledge/review_static_analysis.md:24` (`project/**` path classes); `.agent/knowledge/documentation_verification.md:82`; `docs/design.md` ADR register rows for 0002 (line 920) and 0011 (line 929), which describe the fallback as present, and the Table 2 `sync` row (466); `AGENTS.md` lines 19-20 and 28 as well as 10-11 (the 2026-11-13 issue comment names 19-20). Add the 295 plan's grep acceptance, run and quoted in the Implementation entry: `grep -rn "project/\|worktrees/project\|wt_legacy_project\|wt_transition\|wt_project_base_glob\|projects/<name>" .claude .agent docs Makefile AGENTS.md`, excluding `.agent/work-plans/`, `docs/decisions/` and digests, every remaining hit a record or listed as deliberate.

6. **[Issue alignment] must-fix, bounded instruction.** When pull request 454 (#295 part A) merged on 2026-11-12 the owner chose "merge now, carried into the next pull request's plan (the legacy fallbacks go)" for two suggestions (issue 295 progress, Integrated Review and Checkpoint): F1, four comments (`single_project/sync.py:188`, `validate_workspace.py:154`, `dashboard.sh:156`, `test_fresh_clone_no_project.sh:187`) describe the old common-dir rule, and `Makefile:41` `WS_ROOT` keeps it; F2, a linked worktree of a `--separate-git-dir` checkout reports "none registered" with a registry present (add the case to `test_main_checkout_helpers`, consider "no registry found here"). Revision 3 carries neither. Add both, or record why not for the owner.

7. **[Principle alignment] must-fix, bounded instruction.** Step 6's "`adapter` with no project and a cwd outside every root errors" exercises the existing `registry_require_root` guard (`adapter` lines 168-185), not the new code. The new refusal needs a cwd inside the workspace and in no registered root (the workspace root and a plain subdirectory), with a `project/` symlink to a git checkout in the sandbox, asserting it is not used. Name a refusal test, with the message naming `register_project.sh` or `--project`, for each script whose branch goes: `worktree_list.sh`, `merge_pr.sh` (no name, several registered; the main-tree guard without `$ROOT_DIR/project`), `dispatch_phase.sh`, `sitrep_root.sh`, `session_root.sh`, `gh_create_pr.sh`/`gh_create_issue.sh` (an unregistered `project/` checkout's slug is refused), `single_project/setup.sh` and `sync.py` (`--project-root` required, except the workspace-only sync of finding 3), `configure_git_identity.sh`, `discover_governance.sh`, `pr_status.sh`, `worktree_remove.sh` (empty owner). Synthetic sandboxes only, as planned.

8. **[Issue alignment] must-fix, owner question Q3 then bounded.** The plan does not say whether the pull request closes #265. The roadmap deferral row (line 86) is checked by `gh-issue 265 open`, and the step 5 row (line 181) makes the project11 port-to-rolling the acceptance for step 5. If registering the project11 instances moves to an agent on the second machine, it needs a tracking issue for the roadmap row's check, and closing #265 without that acceptance is the owner's call.

### Suggestions

- **S1 [Scope]** The split point "after step 3" puts the docs (ADR-0017) and the `review-plan` skill fix in the second pull request while the first deletes `wt_legacy_worktree_dirs`, which `review-plan/SKILL.md` step 1 calls. If a split is wanted, split by shape, each half with its tests, skills and design text: (i) the worktree fallback and the `projects/<name>` default (registry, worktree scripts, `review-plan`, `start-task`, WORKTREE_GUIDE, design Worktrees); (ii) the `project/` readers (adapter, `gh_create_*`, `merge_pr`, `session_root`, setup/sync, Sessions and roots, Registry and adapters). One pull request of about 60 files, like the 295 plan's estimate of 55, is also defensible.
- **S2 [Consequences]** In `worktree_remove.sh`, resolve every entry's owner before removing any, so an empty owner refuses before half an aggregate worktree is gone.
- **S3 [ADR compliance]** While rewriting fixtures, rename the `p11` shape names (`test_merge_pr.sh` `worktrees/project/p11/…`, `test_session_root.sh:182`, `test_skill_prefix.sh:38-70`) to neutral ones.
- **S4 [Consequences]** Open branches overlap: issue 465 changes `dispatch_phase.sh`, `test_dispatch_phase.sh` and `script_reference.md`; issue 477 (open pull request 479) changes `docs/roadmap.md`. Add an overlap line and sequence (rebase after whichever merges first).
- **S5 [Issue alignment]** `gather-project-knowledge`: the 2026-11-13 comment asks whether it is still wanted. Reword it for registered roots here, and leave the keep-or-retire question to the owner (Q5) rather than deciding it by rewording.

### For the owner (goal, scope, outward or hard to undo)

- **Q1** The plan for this pull request written on 2026-11-12 also stopped reading the old per-project `.sh` files and the shared `project_config.sh`. This revision keeps reading them. Should this pull request remove them too (then this machine's install command for the single-repository project and the two project11 instances' distro and bootstrap URL move into their settings files first), or leave that for later?
- **Q2** "We can retire the old project folders now": does that mean also deleting the `project` symlink and the two project11 clones under `~/agent_workspace/projects/` on this machine after the merge (on 2026-11-12 you said they "can go"), or only stopping the code from reading them and leaving the folders?
- **Q3** Should this pull request close issue 265 even though the project11 acceptance (the port-to-rolling cycle) and registering the instances happen elsewhere? If yes, which issue tracks the registering?
- **Q4** `AGENTS.md` is Ask First. May the pull request change lines 10-11, 19-23 and 28 so a project is "any folder registered with the workspace (`register_project.sh`), wherever it lives; git and a hosting service are optional", the repo-ownership paragraph says a workspace session works in the workspace checkout and a project session in the project's own folder, and the table row says "its registered folder" instead of `project/`? (Your 2026-11-12 decision that a project is any registered folder replaces the wording you did not approve then; the implement pass shows the exact text in a separate last commit, held for your yes.) Separately: add a status line to ADR-0002 and ADR-0011, which still describe the old shapes?
- **Q5** Is the `gather-project-knowledge` skill still wanted, or should it be retired?

### Summary

The retirement is the right next step and the inventory is mostly right, but the plan was written without the issue 295 plan that already planned this pull request, so it silently narrows the agreed scope, drops two owner-ordered carry-overs and a grep acceptance, and makes a false "no resolution changes" claim for this machine. Three mechanism defects (the `sync` refusal breaking the fresh-clone suite, the false warning on registered in-tree roots, a test that hits the old guard) and the missed sites are bounded. Re-plan the scope after Q1 to Q3; the rest can ride the implement handoff.

### Recommended Actions

- [ ] Re-plan scope against `.agent/work-plans/issue-295/plan.md` B and C (finding 1), after the owner answers Q1 to Q3
- [ ] Correct the "no resolution changes" claim and test the no-name refusal with a `project/` checkout present (finding 2)
- [ ] Keep `sync` with no project as a workspace-only sync; fresh-clone suite unchanged and green (finding 3)
- [ ] Warn on an unregistered directory under `<ws>/projects/`, never on a registered in-tree root (finding 4)
- [ ] Add the missed sites and the grep acceptance (finding 5)
- [ ] Carry F1 and F2 from pull request 454 (finding 6)
- [ ] Name a refusal test per changed script; fix the adapter test's cwd (finding 7)
- [ ] Say whether the pull request closes #265 and where registering is tracked (finding 8)
- [ ] Draft the AGENTS.md text for Q4 as a held last commit

## Checkpoint
**Status**: complete
**When**: 2026-11-16 12:48 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work and its finding 1 needs a re-plan; second host revise in a row at this checkpoint, so the next plan answer is the owner's)
**After**: plan
**Decision**: revise

The host's first handoff did not point plan-task at the recorded design: `.agent/work-plans/issue-295/plan.md`, section "Pull request B and C (one pull request): the legacy fallbacks and the `.sh` reading go", written 2026-11-12 by the owner's direction ("done together with the fourth pull request of issue 265"), "Planned as one pull request, closing issue 265". The review's owner questions Q1 and Q3 are answered by that record and are not asked again: this pull request also stops reading the old per-project `.sh` files and the shared `project_config.sh`, and it closes issue 265. Q2 (deleting the `project` symlink and the clones under `projects/` on this machine) is the record's "machine steps", run after the merge and only on the owner's yes at that time. Q4 (AGENTS.md) is the record's held last commit, shown to the owner at the merge checkpoint. Q5 (whether gather-project-knowledge is still wanted) is parked in the inbox; the skill is only reworded where it names an old shape.

The re-plan carries the review's findings 2 to 7 and suggestions S1 to S5 as binding instructions. The owner's direction of 2026-11-16 stands: "265, pickerel does not have any projects yet so it has nothing to retire. We can retire the old project folders now. I did test the workspace at home as well with various project types, all outside the workspace dir structure so we are ready for this step."
