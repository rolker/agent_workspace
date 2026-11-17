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

## Plan Authored
**Status**: complete
**When**: 2026-11-16 12:55 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-265/plan.md` at `bb27a842`

Revision 4, part 4 as one pull request (`Closes #265`, `Part of #295`), rebuilt from the issue 295 plan's B and C section re-verified against the tree: the `project/`, `projects/` and worktree fallbacks go, and so does the reading of per-project `.sh` files and the shared `project_config.sh`; eight commits by shape (the last is the held AGENTS.md text); stale-shape report, named refusal tests, the 454 carry-overs, after-merge machine steps kept separate. Nothing is deleted on any machine.

## Plan Review
**Status**: complete
**When**: 2026-11-16 13:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #265 — Step 5: hosted projects under projects/ with project-rooted sessions and per-project CLAUDE.md
**Plan**: `.agent/work-plans/issue-265/plan.md` at `bb27a842`
**Branch**: `feature/issue-265`

Second review, of revision 4. Judged against the source on this branch (main `d06cce95` plus the plan), the issue 295 plan's B and C section, the first review and the host Checkpoint, and this machine's main checkout (`.agent/projects.local`, `.agent/projects.d/`, `.agent/project_config.sh`, `project`, `projects/`; read only, nothing changed). Verdict ready means: no finding needs a re-plan; the six must-fix items below are bounded instructions the implement handoff carries.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One pull request rebuilt from the 295 plan's B and C, `Closes #265`, `Part of #295`; about 55 files. The stated split point is not yet coherent (N4), fixed by moving three items between commits. |
| Issue alignment | Good | Serves line, as checked: "Goals 'Light touch on projects' and 'Flexibility' (README Workspace goals); design sections `docs/design.md#sessions-and-roots`, `docs/design.md#registry-and-adapters` and `docs/design.md#worktrees`." Correct. First-review findings 1 to 8 and S1 to S5 are all answered (table below). |
| File targeting | Good | Every reader of the old shapes found by grep on this branch is in the work list (`adapter`, both types, the worktree scripts, `merge_pr`, `gh_create_*`, `pr_status`, `discover_governance`, `configure_git_identity`, `session_root`, `dashboard`, `setup.sh`, `lib/workspace.py`, the two skills). One swallowed error the C1 contract change makes silent: `merge_pr.sh:637` (S6). |
| Consequences | Needs work | Removing the `.gitignore` lines makes the main checkout dirty on this machine and stops `make sync` syncing the workspace (N1). `make install` for the single-repository project goes silent at the moment of use, and the planned notices do not cover it (N2). The shared-file per-key report would give false advice for the two ROS instances (N3). |
| Principle alignment | Good | "Fail loudly": met once N2 and N3 are carried. "Test what breaks": named refusal tests per script, with a `project/` symlink present. "Keep one current design": sections, register rows, Table 2 rows and a change-log row named. |
| ADR compliance | Good | ADR-0011: the `sync` constant is acceptable as written (point 3 below). ADR-0016 decision 1 respected by the warning; N1 is the one place the plan works against it. ADR-0003: synthetic fixtures, names only in the after-merge record. No ADR edited (Q-ADR stays the owner's). |
| ROS conventions | N/A | Workspace plan. |

### First review, item by item (checked in the plan text and against the tree)

| Item | Closed? | Evidence |
|---|---|---|
| 1 scope | Closed | Restarted from the 295 plan's B and C; `.sh` and shared-config reading in (C4); `Closes #265`. |
| 2 machine consequence | Closed | Context paragraph names each no-name call site (verified: `_worktree_helpers.sh:191`, `session_root.sh:204`, `worktree_create.sh:515`, `adapter:212`/258, `merge_pr.sh:999`/1312, `gh_create_*` 144/172, `pr_status.sh:40`, `discover_governance.sh:127`); adapter test from inside the workspace with a `project/` symlink and three registered. |
| 3 `sync` | Closed | Constant to `single_project`; `sync.py` with no `--project-root` is the workspace-only branch (verified `sync.py` 167-210); fresh-clone (d), (f) unchanged. N1 affects whether that sync actually syncs on this machine. |
| 4 warning | Closed | Only an unowned directory under `projects/`; registered in-tree roots silent and tested. |
| 5 missed sites | Closed | All sites listed; grep check in C7, plus an exact symbol grep. |
| 6 F1, F2 | Closed | C6. |
| 7 tests | Closed | Test plan table, one row per script. |
| 8 closing | Closed | `Closes #265` (Checkpoint). Registering is "no tracking issue" in the plan, but the Direction row for #433 covers the Rolling instance on the second machine (S7). |
| S1 split by shape | Partly | Split by shape adopted, but the C1/C2/C3 contents do not yet match it (N4). |
| S2 remove resolves owners first | Closed | C2. |
| S3 neutral fixture names | Closed | Test plan. |
| S4 overlaps | Closed | Overlap table matches `git diff --stat main...` for 465, 477 (PR 479 open) and 429 (empty). |
| S5 skill reworded only | Closed | Q5 parked. |

### Findings

- **N1 [Consequences] must-fix, bounded: keep the five `.gitignore` lines.** On this machine, removing them makes the main checkout show `?? project`, `?? projects/` and `?? .agent/project_config.sh` (`git check-ignore` today attributes them to `.gitignore` lines 5, 10 and 48). `make sync` reaches `single_project/sync.py`, whose `sync_repo` skips any repository where `git status --porcelain` is non-empty (`sync.py:50-74`, untracked files count), so `make sync` prints "Skipping: Uncommitted changes detected." for the workspace, then "No project was synced", then "Sync complete": nothing is synced, the very exception C3 keeps. `dashboard.sh:250` and 318 report "uncommitted changes" too. This lasts until machine steps 6 and 7 run, and for ever if the owner keeps the clones (step 5 is "if the clones go"), and on any machine with a root registered under `<ws>/projects/`, which ADR-0016 decision 1 allows and the plan's own C5 rule keeps silent. `merge_pr.sh`'s `git pull --ff-only` (2470) is not affected. Instruction: C7 keeps the lines, with the comment reworded to say these are retired shapes, still ignored so a machine that keeps them stays clean, and that the stale-shape report names them. Drop the Decisions bullet and the `.gitignore` part of the C7 grep expectation accordingly. (Listed for the owner's veto: it reverses one line of the 295 plan, a mechanism choice.)

- **N2 [Consequences] must-fix, bounded: make the lost install command loud at `make install`, not only in `make validate`.** After C4, `make install PROJECT=gz4d`-shaped calls (settings file without `install`, shared file setting `INSTALL_CMD`) print "INSTALL_CMD not set — nothing to install (this is fine for most projects)." and exit 0 (`single_project/adapter.sh:204-207`; `ros2_colcon/adapter.sh:1636-1638` says the same). C5's adapter NOTE fires only for a `<name>.sh`, not for the shared file, and `make validate`/`dashboard` run only on demand (no hook or session start runs them). Instruction: (a) the adapter's stderr NOTE also fires when `.agent/project_config.sh` exists and, by N3's rule, applies to the active project, naming each key it sets that the settings file lacks and the exact `project_setting.sh set` command; (b) `install` with no `install` key in that case exits non-zero with that text instead of "nothing to install" (the stale file is detected, not read for a value). Test both in `test_adapter.sh`. And see Q-PRE: machine steps 1 to 3 change nothing under today's code (the settings file and the registry `distro=` win over both old files; the bootstrap single-source check runs only on the manifest route, `ros2_colcon/adapter.sh:715`, and both instances are on the bootstrap route), so they can run before the merge and close the window entirely.

- **N3 [Consequences] must-fix, bounded: the per-key report must follow today's resolution order.** Today the shared `.agent/project_config.sh` is read only for a project with no `.agent/projects.d/<name>.sh` (`project_command_source`, `_single_project_resolve_cmd`, `_rc_config_file`, ros2 `adapter_install`). C5 as written reports "per registered project and key", excluding only `build`/`test` for ros2_colcon. On this machine both ROS instances have a `<name>.sh`, so the shared file never applied to them, yet the report would say "`.agent/project_config.sh` sets INSTALL_CMD, which `.agent/projects.d/p11-jazzy` lacks: `project_setting.sh set p11-jazzy install=<command>`", and following it would give a ROS instance the other project's `cmake --install` line. Instruction: the shared file is reported only for projects without a `<name>.sh`; a `<name>.sh` gets its own per-key lines, each with the right remedy: `BUILD_CMD`/`TEST_CMD`/`INSTALL_CMD`/`MANIFEST_BOOTSTRAP_URL` via `project_setting.sh set` (key names `build test install bootstrap_url`), `ROS_DISTRO` via `distro=<v>` on the registry line by hand and only when neither the registry nor the manifest declares one (`project_setting.sh` has no `distro` key: `_PROJECT_FILE_KEYS`, `_project_registry.sh:727`), `ROS_ROOT_DIR` via the environment. The plan's generic text "move its settings with `project_setting.sh set`" is wrong for `ROS_DISTRO`, the one load-bearing value in `p11-jazzy.sh`. Add a test: a `<name>.sh` beside a shared file with `INSTALL_CMD` reports nothing from the shared file for that project. Keep a reader for the old files for this report (C4 deletes `_project_config_value` "if nothing else uses it"; C5 then needs it or a Python equivalent; say which).

- **N4 [Scope] must-fix, bounded: move three items so each commit, and the stated split, leaves the suites green.** (a) C1 changes `registry_worktree_dir` to refuse an unknown name, but `wt_project_base` (`_worktree_helpers.sh:76`), `wt_legacy_worktree_dirs` (133) and `wt_transition_project_base` (149) rely on its `<ws>/worktrees/project/<name>` fallback until C2 deletes them; `test_project_registry.sh` 1183 ("legacy fallback") and 1409 ("an unregistered project (legacy project/ symlink only) still worktrees under `<ws>/worktrees/project/<repo>/`") fail at C1. Move that refusal to C2. (b) C1's `registry_resolve_project_arg` refusal breaks the legacy `--project <unregistered>` paths of `worktree_enter.sh:200` and `worktree_remove.sh:204` before C2 removes them; move it to C2. (c) C2 removes the unregistered worktree key (`worktree_create.sh` 561, 771-776), but the `project/` branch that feeds it (`worktree_create.sh:515-516`), `wt_resolve_project_repo_root` step 2 (`_worktree_helpers.sh:191`) and `worktree_enter.sh:346-347` stay until C3, so between C2 and C3 (and in the first pull request of a split) a `project/` checkout leads into a removed path. Move those three into C2, so C2 is "the worktree scripts are registry-only" and C3 is the remaining `project/` readers. With that, C1+C2 versus C3 to C7 is a coherent cut.

- **N5 [Principle alignment, Verify before claiming] must-fix, bounded: the held AGENTS.md text says `make build`, `make test` with no project.** After C3, `make build` and `make test` from the workspace with no `PROJECT=` refuse (the plan's own fresh-clone (g)), so the new Build & Test sentence "then `make build`, `make test` ..." is false as written; it should read `make build PROJECT=<name>`, `make test PROJECT=<name>`. Also "Set a registered project's build and test commands" is true only for types that use them: for `ros2_colcon`, colcon owns build and test (`registration.conf`, `unused_settings`); a clause saying so, or "a single-repository project's", keeps it true. The other three edits are true of the code after the change: the 200-line budget holds (199 + 1; `check_agents_md_budget.sh` LIMIT=200, "at most"); "git and a hosting service are optional" matches the 2026-11-12 decision and `test_register_project.sh:354` ("no remote: supported"); the repo-ownership paragraph is true, with the edge that a root registered inside the workspace tree is a separate folder nested in it.

- **N6 [Consequences] must-fix, bounded: stale step reference in the machine steps.** "88 repositories under the two ROS clones were checked clean ...; re-check before step 3" carries the 295 plan's numbering: step 3 is now the bootstrap URLs; the deletion is step 6. Instruction: "re-check before step 6". Also step 2 (distro) is pointless if step 5 removes the entries, like step 3; say so.

### Suggestions

- **S6 [File targeting]** `merge_pr.sh:637` `registry_resolve_project_arg ... 2>/dev/null || echo "$PROJECT_ARG"` swallows the refusal C1/C2 introduces. The resolution block at 312-333 exits on an unresolvable `--project` only when `--type project` is explicit; otherwise an unregistered name reaches 637 and is compared raw, matching nothing, silently. Make it refuse there (or validate `--project` up front whatever the type), test it, and add the `registry_resolve_project_arg .* || echo` pattern to the C7 exact grep.
- **S7 [Issue alignment]** The plan says registering the project11 instances has "no tracking issue"; the Direction row "The Rolling instance builds on the second machine ... (#433)" tracks it (#433 open). Cite #433 in the Consequences row and in row 181's tail instead of "by its own agent".
- **S8 [Consequences]** Keep `project_config_extra_vars` for the stale report: a `.sh` or shared file that exports a variable beyond the read set (a PATH or SDK variable) should be named when its commands are moved, as `register_project.sh`'s `EXTRA_WARN` does today. None of this machine's files do, so this is for other machines.
- **S9 [Consequences]** Roadmap: `update_roadmap.sh` (called by `merge_pr.sh:742` at merge) marks rows 181 and 202 `done` itself (issue column `#265`), so C7's hand edit is consistent and becomes a no-op then. Deleting row 86 is safe for `sitrep_checks.sh` (a table with fewer rows; the suites that read a roadmap use synthetic ones). Run `sitrep_checks.sh` on the edited roadmap once and quote the deferral lines in the Implementation entry.

### Points the host asked about

- **2, silent cases after C4 on a machine with only the old files.** Build and test of the single-repository project: unaffected (settings file has both). Install: silent today as planned (N2). `ROS_DISTRO` of the jazzy instance: loud ("cannot resolve the ROS distro"), but the NOTE's remedy text is wrong (N3). Bootstrap URLs: needed only when `configs/manifest` is missing; both clones have one; the failure is loud and names `project_setting.sh`. `ROS_ROOT_DIR`: neither file sets it here. Order: steps 1 to 3 are harmless under today's code, so the safe order is steps 1 to 3 before the merge (Q-PRE), then merge, then 4 to 8; with N2 the window is loud even if they run after.
- **3, the `sync` constant against ADR-0011.** Acceptable as written. ADR-0011's own dispatcher rule (lines 52-54) says the dispatcher resolves the type "(default: `single_project`)"; the "never branch on project type" rule (57-59) binds workflow scripts and skills, not the dispatcher. The constant keeps that default without the config read. Moving `sync_repo`/`sync_gitbug` to `lib/` now would be redone by the 295 plan's later pull request, which adds a `workspace` adapter type whose `sync` is the natural home; the constant's comment should name that pull request as its replacement. No owner decision on the ADR is needed beyond Q-ADR.
- **4, `.gitignore`.** N1. No script requires a clean main checkout to run, but `make sync` skips a dirty one and the dashboard flags it. `git clean` is denied to agents (`.claude/settings.json` deny list).
- **5, AGENTS.md.** N5.
- **6, roadmap.** S9 and S7: consistent at merge; parsing unaffected.
- **7, size and order.** About 55 files, eight commits, implementable; N4 fixes the order.

### For the owner (goal, scope, outward or hard to undo)

- **Q-PRE** Moving three settings on your first machine before the merge instead of after it: the single-repository project's install command into its settings file, `distro=jazzy` on the jazzy instance's registry line, and the two bootstrap URLs into the instances' settings files. Under today's code these change nothing (the new values win over the old files and are the same values); done before the merge, `make install` for that project never goes silent. May the host do them at the merge checkpoint, before merging? (Changes: the order of the machine steps only; undo is deleting three settings.)
- **Q-ADR, Q-AGENTS, Q-ROADMAP, Q5** stand as the plan words them; Q-AGENTS should be shown with N5's correction.

### Summary

Revision 4 closes every first-review finding and is ready to implement. Six bounded must-fix instructions ride the implement handoff: keep the `.gitignore` lines (N1), make the lost install loud at `make install` (N2), report the shared file only where it applied today, with the right remedy per key (N3), move three items between commits so each commit and the split point stay green (N4), correct the held AGENTS.md Build & Test sentence (N5), and fix a stale step number (N6). None needs a re-plan; Q-PRE is the one new owner question.

### Recommended Actions

- [ ] Keep the five `.gitignore` lines, comment reworded (N1)
- [ ] Adapter NOTE for the shared file and a non-zero `install` when a stale file sets `INSTALL_CMD` the settings file lacks; tests (N2)
- [ ] Per-key report follows today's resolution order; per-key remedies for `<name>.sh`, `ROS_DISTRO` via the registry line; test (N3)
- [ ] Move `registry_worktree_dir` and `registry_resolve_project_arg` refusals, and the worktree scripts' `project/` branches, into C2 (N4)
- [ ] AGENTS.md Build & Test: `PROJECT=<name>`, type clause (N5)
- [ ] "re-check before step 6" (N6)
- [ ] Ask Q-PRE at the merge checkpoint

## Checkpoint
**Status**: complete
**When**: 2026-11-17 08:19 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Asked on 2026-11-17: "Q2 — start implementing the folder retirement? (issue 265 part 4: retire `project/`, `projects/` and the worktree fallback.)" with the note that plan revision 4 was reviewed "ready" with six must-fix points and four suggestions going into the implement handoff, and that the AGENTS.md wording commit, moving three settings on this machine, and the after-merge disk deletions stay held for his word at the merge checkpoint. His answer, verbatim: "q1 yes, q2, yes, q3 3a".

## Implementation
**Status**: complete
**When**: 2026-11-17 10:15 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-265 at `a80f3dc2`

Plan revision 4 implemented as C1 to C8 (C2 in two commits, per S4), plus one plan-text commit. 76 files, +2562 / -2023 against `ce62ee3e`. Nothing on this machine was touched: no change to the main checkout's registry, settings files, `project_config.sh`, `project` or `projects/`. No push.

Commits:
- `b8fd9673` plan: N1 (keep the `.gitignore` lines), N5 (AGENTS.md Build & Test text), N6 ("re-check before step 6"; step 2 pointless if step 5 removes the entries), S7 (#433).
- `0b6eb259` C1: a pathless registry entry is a parse error (shell and Python, same text); `registry_no_project_message`.
- `c3019e08` C2a: `dispatch_phase.sh` `resolve_worktree` searches registered worktree dirs only.
- `52d9ee12` C2b: the five legacy worktree helpers and their callers go; `registry_worktree_dir` and `registry_resolve_project_arg` refuse an unregistered name (moved here by N4, with `worktree_create.sh`'s `project/` branch, `wt_resolve_project_repo_root` step 2 and `worktree_enter.sh`'s `project/.git` read); `worktree_remove.sh` resolves every owner first (S2); `merge_pr.sh` refuses an unregistered `--project` up front (S6).
- `b89e0a01` C3: nothing reads `project/`; the dispatcher refuses with no project except `sync` (`_WORKSPACE_ONLY_SYNC_TYPE`); `setup.sh` requires `--project-root`; `PJ_ROOT_EFFECTIVE` goes; gh_create, pr_status, discover_governance, configure_git_identity and dashboard read the registry; Makefile walk-up cases go.
- `b68e1e17` C4: the legacy `.sh` and shared config are read by no adapter; `ROS_ROOT_DIR` from the environment; `project_command_source` is file or missing.
- `184dc4c8` C5: `registry_stale_report` in validate (after the results) and dashboard (warnings); adapter NOTE for a `.sh` or the shared file by the old order (N3); `install` refuses while a retired file sets `INSTALL_CMD` the settings lack (N2).
- `0fb34faf` C6: F1 (comments; `make setup` reads the registry through `registry_main_checkout`; `WS_ROOT` comment) and F2 (fallback reported by both helpers; "no registry found from this linked worktree; run it from the main checkout").
- `b67d0268` C7: `.gitignore` kept with reworded comments (N1); design.md register rows 0002 and 0011 and a change-log row with the machine paragraph; roadmap edits (proposed, owner's veto); S3 renames in `test_skill_prefix.sh` and `test_session_start_layer.sh`.
- `a80f3dc2` C8, held for the owner (Ask First), the last code commit (this entry's commit follows it and touches only this file).

AGENTS.md (C8), before and after, as committed:

- Lines 10-11 before: "- **Project**: the managed product in `project/` — what's actually being built. / Product features, deployment, and user-facing behavior are project scope." After: "- **Project**: the managed product, any folder registered with the workspace / (`register_project.sh`), wherever it lives; git and a hosting service are / optional. Features, deployment and user-facing behavior are project scope."
- Repo ownership before: "The working directory contains files from both repos (workspace infrastructure is layered onto the project checkout). Don't assume which GitHub repo you're in based on directory contents — ..." After: "A workspace session works in the workspace checkout and a project session in the project's own registered folder; the two are separate folders. Don't assume which repo you're in based on directory contents — ..."
- Table row before: "The product being built (`project/`)". After: "The product being built (its registered folder)".
- Build & Test before: "Configure the project's build and test commands in `.agent/project_config.sh` (gitignored); then `make build`, `make test`, `make lint` (pre-commit on all files) and `make validate` (workspace config). See ..." After (N5): "Set a single-repository project's build and test commands with `project_setting.sh set <name> build=<command>` (a `ros2_colcon` project's come from colcon); then `make build PROJECT=<name>`, `make test PROJECT=<name>`, `make lint` (pre-commit on all files) and `make validate`. See ..." AGENTS.md is 200 lines; `check_agents_md_budget.sh` passes.

Mechanism decisions the plan did not settle (each listed for veto):
- With no `--project`, `worktree_create.sh` and `wt_resolve_project_repo_root` (so `merge_pr.sh` and `worktree_remove.sh --path`) use the registered root the cwd is in before the single-registered fallback, so the refusal's "here (cwd ...)" is true. Undo: drop one block in each.
- `registry_worktree_dir` and `registry_resolve_project_arg` refuse with "project 'X' is not registered (registered: ...); register it: ...".
- `adapter --from <dir>` that is not a directory is refused (it used to fall back, to the legacy root).
- `single_project/setup.sh` keeps only the "already a checkout: pull" case; a registered root that is not a git checkout is refused (no clone, no symlink).
- `worktree_remove.sh` takes an entry's owner only when the entry is its checkout's own top folder (git would otherwise walk up to the enclosing root and remove the wrong worktree; found by the S2 test).
- `configure_git_identity.sh` reads the registry of the current directory's main checkout (its "workspace" is the cwd), never the script's own checkout, so its tests never reach a real registry; repositories are every `.git` under each non-parent root, its `worktrees/` skipped.
- `discover_governance.sh` scans non-parent roots with scope `project`; a root outside the workspace is reported by its absolute path.
- N3's reader is the shell `_project_config_value` / `_stale_config_values` with `_PROJECT_CONFIG_READ_VARS` and `project_config_extra_vars` kept; `validate_workspace.py` calls `registry_stale_report` through bash, so there is one rule.
- `ROS_DISTRO` is reported only while the registry line has no `distro=`, worded "if its manifest declares no distro": the report does not read a manifest, which would be ros2_colcon knowledge in a generic helper (ADR-0011).
- A `.sh` with nothing left gets "delete it" from the report and the adapter NOTE; the shared file gets the NOTE only when it still sets something for the active project.
- The dashboard's orphan check skips a `<name>.sh` (the report names it).
- `make setup` also says "no registry found from this linked worktree" on the F2 fallback.
- `test_fresh_clone_no_project.sh` (h) uses the existing (e) registration (`build=none`) rather than registering again with `build=true`.
- C2 was amended in place before C3's commit was rebuilt on it (no push): the first C2 left one hub-guard assertion failing (`test_merge_pr.sh` named the registration script whole); the amended C2 passes `test_script_tests_hook_scope.sh` (333 passed, 0 failed) and `test_merge_pr.sh`, and C3's tree is unchanged.

Grep checks (C7). Exact symbol grep: only `_PROJECT_CONFIG_READ_VARS` and `project_config_extra_vars` in `_project_registry.sh`, kept on purpose (N3, S8); `registry_resolve_project_arg .* || echo` has no hit. Broad grep: 539 hits, read: outside tests they are retirement comments naming what went, the stale-report code and messages, the records combination `project/project`, `projects.d/<name>` and `project/issue/layer` prose; in tests, fixtures that build a `project/`, `worktrees/project/` or unowned `projects/` on purpose to show it is ignored or reported, and roots registered under `projects/` (ADR-0016 decision 1); in records, the design change log, register rows, Table rows, and roadmap history (row 185, and the Backlog row "Local integration branches" naming `worktrees/project/<repo>/integration/`, owner's record text, not edited). `make generate-skills` not run: no `.PHONY` target changed.

S9: `sitrep_checks.sh --root .` on the edited roadmap: `lines 1/4 deferrals 4/7`; the deferral rows are #323 (false), #415 (true), #428 (true), #431 (true), audit trials #429 (true), #338/#295 (false), #398 (false); the #265 row is gone and the table parses.

Suites run (each with `bash .agent/scripts/tests/<suite>` from the worktree, final head unless said): test_adapter.sh 219 passed, 0 failed; test_project_registry.sh 390 passed, 0 failed; test_fresh_clone_no_project.sh 26 passed, 0 failed (at `0fb34faf`; it exports HEAD); test_validate_workspace_stale.sh (new) 34 passed, 0 failed; test_pr_status.sh (new) 3 passed, 0 failed; test_project_file.sh 701 passed, 0 failed; test_ros2_colcon.sh 1014 passed, 0 failed, 0 skipped; test_merge_pr.sh 161 passed, 0 failed; test_merge_pr_gate.sh 201 passed, 0 failed; test_merge_pr_skill.sh 132 passed, 0 failed; test_merge_pr_root_resolution.sh 6 passed, 0 failed; test_dispatch_phase.sh 234 passed, 0 failed; test_worktree_create.sh PASS 80, FAIL 0; test_worktree_enter_stderr.sh 35 passed, 0 failed; test_session_root.sh 71 passed, 0 failed; test_register_project.sh 201 passed, 0 failed; test_register_session_root.sh 66 passed, 0 failed; test_project_integration_audit.sh 279 passed, 0 failed; test_package_issue_loop.sh 220 passed, 0 failed; test_gh_create_pr.sh PASS 113, FAIL 0; test_gh_create_issue.sh PASS 71, FAIL 0; test_discover_governance.sh 27 passed, 0 failed; test_commit_identity.sh 95 passed, 0 failed; test_sitrep_root.sh 56 passed, 0 failed; test_sitrep_checks.sh 211 passed, 0 failed; test_precommit_hook_path.sh 19 passed, 0 failed; test_capture.sh 41 passed, 0 failed; test_sync_gitbug.sh 10 passed, 0 failed; test_user_tier_guard.sh 64 passed, 0 failed; test_user_tier_install.sh 276 passed, 0 failed; test_records_write_gate.sh 68 passed, 0 failed; test_checkpoint_269.sh 43 passed, 0 failed; test_triage_reviews_integration.sh 69 passed, 0 failed; test_review_code_convergence.sh 38 passed, 0 failed; test_plan_correlation.sh 18 passed, 0 failed; test_issue_review_entry.sh 6 passed, 0 failed; test_run_script_tests.sh 170 passed, 0 failed; test_script_tests_hook_scope.sh 342 passed, 0 failed; test_skill_paths.sh 163 passed, 0 failed; test_skill_prefix.sh 25 passed, 0 failed; test_session_start_layer.sh 52 passed, 0 failed; test_design_anchors.sh 47 passed, 0 failed; test_agents_md_budget.sh 7 passed, 0 failed. Changed scripts with no suite of their own: `bootstrap.sh`, `registration_verify.sh` (reached through test_register_project.sh). The full pre-commit pass and every other suite are left to the host.

Not done, and why: ADR-0002 and ADR-0011 still describe the retired shapes (Q-ADR, the owner's); `test_ros2_colcon.sh` keeps its `p11` fixture name (not in S3's list); the after-merge machine steps and Q-PRE wait for the owner at the merge checkpoint.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-17 10:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-265 at `6bc841b1`
**Base**: origin/main
**Depth**: Deep (reason: 77 files, +3429/-2403; enforcement and governance files: AGENTS.md, Makefile, .gitignore, registry and adapter dispatcher)
**Must-fix**: 3 | **Suggestions**: 10
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

Specialists: static (shellcheck --severity=warning on 49 changed shell files: clean; flake8 on 3 Python files: only pre-existing E402/E203), governance, plan drift, two Claude adversarial sub-reviews (registry/adapters; worktree/merge scripts), Gemini (agy) ran: 6 findings; Codex ran: 3 findings; Copilot CLI not a reviewer here (#344). Must-fix 1 and 2 were reproduced in throwaway sandboxes.

ADRs: besides 0002 and 0011, ADR-0018 (decision 6 text, lines 261 and 304: "the legacy unregistered `project/` is hosted by the workspace") and ADR-0003 line 33 (reusability test "configuring a new `project/` directory") are now contradicted; for the owner's Q-ADR.

### Findings
- [x] (must-fix) registry_stale_report reads a malformed registry as empty (`|| entries=""`, and `! registry_lookup` treats rc 2 as unregistered): with one bad line (now including any pathless entry) it tells the user to remove registered `projects/<name>` checkouts and delete `.sh` files that still hold settings (reproduced) — `.agent/scripts/_project_registry.sh:1503`, `:1550`
- [x] (must-fix) `adapter install` exits 0 "nothing to install" when the retired file cannot be sourced (state unknown), defeating plan review N2; refuse install with no install setting in that case too (reproduced; Codex and Gemini) — `.agent/scripts/adapter:345`
- [x] (must-fix) held AGENTS.md text says "git and a hosting service are optional", but registration refuses a folder in no git repository (design.md 384-386 calls it a named gap; register_session_root.sh 54-56); say git is not yet optional, or "a hosting service is optional" — `AGENTS.md:11-12`
- [x] (suggestion) retired files are sourced (executed) twice on every adapter verb for the stale NOTE, though "nothing reads them"; limit to install/validate or parse without executing (Codex) — `.agent/scripts/adapter:334-350`
- [x] (suggestion) project link advice: a registry line naming `<ws>/project` itself as a symlink is told "remove it" (breaks the entry); a dangling link is told "register it" — `.agent/scripts/_project_registry.sh:1505-1520`
- [x] (suggestion) worktrees/project check looks at depth 1, so the warning stays after the advised removals leave `<name>/` dirs; a `worktrees=` override under there is reported as unfound (Gemini) — `.agent/scripts/_project_registry.sh:1522`
- [x] (suggestion) ROS_DISTRO lines are given for non-ros2 types, and the shared-file ROS_DISTRO line is unconditional, so "delete it" is never reached (Gemini) — `.agent/scripts/_project_registry.sh:1577`
- [x] (suggestion) cwd step uses registry_resolve_from_dir (hosting dir only), not registry_resolve_session_dir, so from a worktree under a `worktrees=` override it says "no registered project here"; worktree_enter/remove do no cwd step at all — `.agent/scripts/_worktree_helpers.sh:124`, `.agent/scripts/worktree_create.sh:521`
- [x] (suggestion) parse errors read as absence: configure_git_identity `|| true` ends "No registered project repositories found" (and `find` lost `-type d`); dispatch_phase resolve_worktree reports rc 2 as not found — `.agent/scripts/configure_git_identity.sh:151`, `.agent/scripts/dispatch_phase.sh` resolve_worktree
- [x] (suggestion) refusal remedy "remove the worktree by hand or with --path" cannot work: --path refuses the same non-top-folder entry — `.agent/scripts/worktree_remove.sh:398`
- [x] (suggestion) single_project setup tells a registered non-git folder to "Clone the project there", against the owner's 2026-11-12 decision that git is optional — `.agent/project_types/single_project/setup.sh:47-50`
- [x] (suggestion) design.md cites `adapter` line 85 for `_WORKSPACE_ONLY_SYNC_TYPE` (it is 82); Table 1's registry_derive_type_from_dir range is stale (Gemini) — `docs/design.md:318`, `:419`, `:474`
- [x] (suggestion) 17 new fixture lines use the `p11` name (project-derived; S3's neutral-name rule) — `.agent/scripts/tests/test_ros2_colcon.sh`

## Implementation
**Status**: complete
**When**: 2026-11-17 10:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-265 at `2681aea4`
**Addressed**: Local Review (Pre-Push) at `6bc841b1` (2026-11-17 10:24 -05:00)
**Commits**: `53931f16`, `6e8603b4`, `078634fa`, `557fffe5`, `56295a6e`, `115046e1`, `19547d22`, `1e3be5e4`, `9e5e1f17`, `892d86e2`, `2681aea4` (box checks)

Fix round 1: all 3 must-fix and all 10 suggestions fixed, none deferred. Each behaviour fix has a test that was run against the pre-fix script and failed there (stale report 23 failures, adapter install 5, adapter machine verbs 6, worktree cwd step 9, configure_git_identity 2, dispatch_phase 2; the worktree_remove and setup.sh text tests assert the old text is gone). Nothing in the main checkout was touched; no push.

### Actions
- [x] M1, a registry with errors read as empty by the stale report — `.agent/scripts/_project_registry.sh` (`53931f16`). registry_stale_report now prints one line (".agent/projects.local has errors, so which retired shapes are still in use cannot be told: fix the registry (make validate names each bad line), then read this report again") and nothing else; registry_stale_settings_lines returns 1 with a line when the registry has errors or the project's settings file is invalid, never "lacks". Tests in `test_validate_workspace_stale.sh` (a pathless entry and an unknown field: one line, no remove/delete/register advice; an invalid settings file: no "lacks", no "delete it").
- [x] M2, `adapter install` exits 0 when the retired file cannot be sourced — `.agent/scripts/adapter` (`6e8603b4`). With no install setting, install refuses when what the retired file holds cannot be told (cannot be sourced, registry or settings errors). Test `test_install_refuses_when_retired_file_unreadable` (shared file and `<name>.sh`; `install=none` still exits 0).
- [x] M3, AGENTS.md said git is optional — `AGENTS.md` (`557fffe5`, touches only AGENTS.md, on top of the held `a80f3dc2`; no history rewritten; 200 lines, budget hook passed). Against main, the Terminology bullet: before "- **Project**: the managed product in `project/` — what's actually being built. / Product features, deployment, and user-facing behavior are project scope." After "- **Project**: the managed product, any folder registered with the workspace (`register_project.sh`), / wherever it lives. A hosting service is optional; git is meant to be, but registration still needs it. / Features, deployment and user-facing behavior are project scope." The Repo ownership, table row and Build & Test text are unchanged from `a80f3dc2` (quoted in the Implementation entry above).
- [x] S, retired files run on every adapter verb — `.agent/scripts/adapter` (`078634fa`). The check runs for setup, sync, validate, build, test, install only. Test `test_retired_settings_not_run_for_machine_verbs` (project_root, env, repos do not run the file; build, test still give the NOTE).
- [x] S, project link advice — `.agent/scripts/_project_registry.sh` (`53931f16`). A registry line naming `<ws>/project` (a link) is silent; a dangling link gets "remove it", never "register"; a link to an unregistered folder names the target to register and says to remove the link. Tests in `test_validate_workspace_stale.sh`.
- [x] S, worktrees/project depth and worktrees= override — `.agent/scripts/_project_registry.sh` (`53931f16`). A checkout (a `.git` file or directory) at any depth under the retired locations, outside every registered root and `worktrees=` dir. Tests: a real worktree two levels down is named, silent after the advised `git worktree remove` leaves `alpha/`; a registered `worktrees=` dir under `worktrees/project/` is not named, an unregistered worktree beside it is.
- [x] S, ROS_* lines for non-ROS types — `.agent/scripts/_project_registry.sh` (`53931f16`). ROS_DISTRO and ROS_ROOT_DIR lines only for a type that reads them; the shared file's ROS_DISTRO is now per project it applied to, ROS_ROOT_DIR once when one applied project reads it, so "delete it" is reachable. Tests in `test_validate_workspace_stale.sh`.
- [x] S, cwd step ignores worktrees= dirs; enter/remove had none — `.agent/scripts/_worktree_helpers.sh`, `.agent/scripts/worktree_create.sh`, `.agent/scripts/worktree_enter.sh`, `.agent/scripts/worktree_remove.sh` (`56295a6e`). registry_resolve_session_dir in create and wt_resolve_project_repo_root; enter and remove (with `--type project`, no `--project`) take the cwd's root before the single-candidate step. Test `test_worktree_scripts_cwd_in_worktrees_override` in `test_project_registry.sh`.
- [x] S, parse errors read as absence — `.agent/scripts/configure_git_identity.sh`, `.agent/scripts/dispatch_phase.sh` (`19547d22`). configure_git_identity refuses on registry errors with nothing written, and `find` regains `-type d`; resolve_worktree returns 2 with "the project registry ... has errors" (dispatch and `base` exit 2). Tests in `test_commit_identity.sh` and `test_dispatch_phase.sh`.
- [x] S, worktree_remove remedy named --path — `.agent/scripts/worktree_remove.sh` (`115046e1`). Says to inspect, delete the entry by hand and run again (an entry already gone is skipped); the test follows that advice to a clean removal.
- [x] S, single_project setup said "Clone the project there" — `.agent/project_types/single_project/setup.sh` (`1e3be5e4`). Not a git checkout: "nothing was changed", setup updates with git and a single_project needs a git repository today (adapter validate checks it), fix the line if it names the wrong folder; a missing root: "does not exist; nothing was changed", put the project there or fix the line. No non-git registration added. Tests in `test_adapter.sh` (no "Clone").
- [x] S, design.md line citations — `docs/design.md` (`9e5e1f17`). `adapter` line 82 (two places); Table 1 ranges for `registry_derive_type_from_dir` (644-659) and the worktree_create, enter/remove and dispatch_phase rows this branch shifted, re-read at this commit; the Discovery and Retirement paragraphs say what this round changed.
- [x] S, `p11` fixture name — `.agent/scripts/tests/test_ros2_colcon.sh` (`892d86e2`). The whole file renamed to `tiered` (165 occurrences, all the word p11; mechanical); suite stays at 1014 passed.

Mechanism decisions (each listed for veto):
- The stale-report fixes (M1 and three suggestions) are one commit: they rewrite the same two functions and could not be split without a hand-staged patch.
- A registry with errors: the report gives one line and nothing else, the worktree-location check included (what is registered decides it too).
- "Does a type read ROS_DISTRO / ROS_ROOT_DIR" is answered by the type's own `adapter.sh` naming `ACTIVE_PROJECT_DISTRO` / `ROS_ROOT_DIR` (`_stale_type_reads`): no script names a type (ADR-0011); an empty or unknown type answers yes, so advice is never dropped. Undo: report both for every type again.
- The adapter's retired-file check runs for the verbs a person runs (setup sync validate build test install), not only install and validate as the review offered: build and test are where a lost command shows, setup and sync where a lost bootstrap URL shows. The two sourcings (values in a subshell; extra variables in a clean `env -i` shell) stay as they are on those verbs.
- install refuses on "cannot be told" for every cause registry_stale_settings_lines returns 1 for (unsourceable file, registry errors, invalid settings file); an invalid settings file already stops the adapter earlier.
- configure_git_identity refuses on a registry with errors (exit 1, nothing written), matching its existing "nothing written when any repository's email cannot be derived".
- worktree_enter and worktree_remove's cwd step runs only with `--type project` and no `--project`; `registry_derive_type_from_dir` (the `--type`-omitted derivation) is unchanged and still matches hosting dirs only, so a cwd under a `worktrees=` override that lies inside the workspace derives `workspace`. Not in the finding; left as is, for the next review to judge.
- AGENTS.md wording: "A hosting service is optional; git is meant to be, but registration still needs it." Reflowed the bullet to three lines to stay at 200.

Suites run (each `bash .agent/scripts/tests/<suite>` from the worktree at `892d86e2`, all scripts final): test_adapter.sh 240 passed, 0 failed; test_capture.sh 41 passed, 0 failed; test_commit_identity.sh 97 passed, 0 failed; test_discover_governance.sh 27 passed, 0 failed; test_dispatch_phase.sh 236 passed, 0 failed; test_fresh_clone_no_project.sh 26 passed, 0 failed; test_gh_create_issue.sh PASS 71, FAIL 0; test_gh_create_pr.sh PASS 113, FAIL 0; test_issue_review_entry.sh 6 passed, 0 failed; test_merge_pr_gate.sh 201 passed, 0 failed; test_merge_pr_root_resolution.sh 6 passed, 0 failed; test_merge_pr.sh 161 passed, 0 failed; test_merge_pr_skill.sh 132 passed, 0 failed; test_package_issue_loop.sh 220 passed, 0 failed; test_plan_correlation.sh 18 passed, 0 failed; test_precommit_hook_path.sh 19 passed, 0 failed; test_project_file.sh 701 passed, 0 failed; test_project_integration_audit.sh 279 passed, 0 failed; test_project_registry.sh 404 passed, 0 failed; test_pr_status.sh 3 passed, 0 failed; test_records_write_gate.sh 68 passed, 0 failed; test_register_project.sh 201 passed, 0 failed; test_review_code_convergence.sh 38 passed, 0 failed; test_ros2_colcon.sh 1014 passed, 0 failed, 0 skipped; test_session_start_layer.sh 52 passed, 0 failed; test_sitrep_checks.sh 211 passed, 0 failed; test_sitrep_root.sh 56 passed, 0 failed; test_skill_paths.sh 163 passed, 0 failed; test_triage_reviews_integration.sh 69 passed, 0 failed; test_user_tier_guard.sh 64 passed, 0 failed; test_user_tier_install.sh 276 passed, 0 failed; test_validate_workspace_stale.sh 64 passed, 0 failed; test_worktree_create.sh PASS 80, FAIL 0; test_worktree_enter_stderr.sh 35 passed, 0 failed. `single_project/setup.sh` is not under `.agent/scripts/`; test_adapter.sh covers it. The full pre-commit pass and every other suite are left to the host.

Not done, and why: ADR-0002, ADR-0003 (line 33), ADR-0011 and ADR-0018 (lines 261, 304) still describe the retired shapes (the owner's Q-ADR; no ADR or CLAUDE.md edited). The AGENTS.md commits `a80f3dc2` and `557fffe5` wait for the owner at the merge checkpoint.
