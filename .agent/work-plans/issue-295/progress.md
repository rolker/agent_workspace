---
issue: 295
---

# Issue #295 — Treat the workspace as a registered project (pinned registry entry + workspace adapter) instead of a --type special case

## Issue Review
**Status**: complete
**When**: 2026-11-12 12:38 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #295

### Scope Assessment

**Well-scoped?** No, not as written. The issue is an idea plus a 2026-09-18 survey, not a design. It names no adapter body, no entry shape and no per-site replacement, and its "First step" (a plan) was never done. Together with #265 PR 4 it is at least three pull requests, not one. The survey counts are stale: `grep` for type, project and path branches now finds worktree_create 70, merge_pr 74, worktree_enter 43, dispatch_phase 31, worktree_remove 29, _project_registry 27, _worktree_helpers 17 matching lines (a loose count, not branch sites; the plan must recount by reading). The design's Registry inventory (docs/design.md, Table 1 with line ranges, Table 2 with the 12 verbs: 3 no-op, 5 thin wrapper, 4 real) is the better survey and already answers "what differs".
**Right repo?** Yes. All of it is workspace infrastructure.
**Serves**: Workspace goal "The workspace is project-agnostic and usable on any project" (the synthetic-test-project argument in the issue) and the machine-independence of fresh clones — `docs/design.md#registry-and-adapters` (Target), with `docs/design.md#sessions-and-roots` (Target, decided not built: registry-only discovery).
**Design picture?** Changes `docs/design.md#registry-and-adapters` and `docs/design.md#sessions-and-roots`. The registry-only half is already decided (ADR-0016 decision 2, Accepted 2026-11-09; Sessions and roots Target "Discovery becomes registry-only: PR 4 of #265"). "The workspace is a registered project" is only listed as "Target (open)", so it is not decided. See the owner questions in Recommendations.
**Dependencies**: #265 (PR 4 is folded in by the owner, 2026-09-18 and 2026-11-12). Overlaps in the same scripts: #429 part 2 (`worktree_create.sh`, `merge_pr.sh`, `dispatch_phase.sh`), #446 (`user_tier_install.sh`, `register_project.sh`, `skill_prefix.sh`), #437 (records write gate, PR 448). Sequence behind or rebase onto these, never edit the same functions in parallel.

### Findings from the code (main at 3486edba)

- Registry half of #265 PR 3 is not built: `.agent/project_types/` holds only `ros2_colcon` and `single_project`; `_project_registry.sh` has no pinned entry. Confirmed.
- Legacy fallbacks still live: `adapter` header step 3 and lines ~216-224 (`project/` symlink + shared `project_config.sh`); `_worktree_helpers.sh` (`wt_legacy_worktree_dirs`, `wt_legacy_workspace_base`, `wt_legacy_project_base`, the `project/worktrees/` shape, the "no project configured" error at ~183); `_project_registry.sh` `registry_worktree_dir` maps an unregistered name to `<root>/worktrees/project/<name>` (~481-510); `merge_pr.sh` `PJ_ROOT_EFFECTIVE` falls back to `project/`; `gh_create_pr.sh` accepts the slug of the legacy `project/`; `dashboard.sh`, `sitrep_root.sh`, `session_root.sh`, `worktree_list.sh`, `discover_governance.sh`, `configure_git_identity.sh`, `lib/workspace.py`, `validate_workspace.py` mention it.
- Loose end 1 confirmed: `validate_workspace.py` lines 171-198 add "project/ directory does not exist" and "Run: make setup" whenever `project/` is absent and the registry has no entries; with entries it only prints in verbose mode. A workspace with no project fails. It also checks `project/` remote origin.
- Loose end 2 confirmed: Makefile line 98 `setup: $(STAMP)/project.done ...` and lines 192-198 run `setup_project.sh` (the `single_project` setup verb, which prompts for a repo) when `project/` is absent. `make help` (lines 67-84) and the header comments (3-22) describe the legacy shape and `project_config.sh`. README and AGENTS.md (lines 10 and 28: "the managed product in `project/`") do the same.
- `--type` has deep reach: `session_root.sh --type workspace|project` (also the `case` at line 93), `agent start-task`, `dispatch_phase.sh` (four modes), `worktree_create/enter/remove.sh`, `merge_pr.sh --type`, `gh_create_pr.sh` targeting, and the `--type` mention in 8 skills (start-task 20 mentions, run-issue 21, plan-task 5, triage-reviews 4, research 4, onboard-project 3, inspiration-tracker 2, gather-project-knowledge 2). The `registry_derive_type_from_dir` helper already derives it from the cwd.
- Machine state: this machine's registry still holds `p11-jazzy` and `p11-rolling` under `projects/` and a `project -> /home/roland/src/gz4d` symlink. Owner (2026-11-12): no symlink to gz4d needed, p11 clones can go, so no migration. Removal is `register_project.sh --remove` per entry (refuses live worktrees), which is a machine step and not code.
- #265 plan item 4 also lists: delete the `projects.d/<name>.sh` reading and the shared-config fallback for registered projects. That is a separate, larger removal than the `project/` fallbacks. The owner's 2026-09-18 comment names only "the `project/` / `projects/` fallbacks" for the special-case collapse; the `.sh` and shared-config retirement is in the plan, and this machine still has `p11-*.sh` files and `.agent/project_config.sh`. Whether it is in this round is unclear.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | Whether the workspace becomes a registered project (a pinned entry, a workspace adapter, and what that does to `--type`, to the root rule in `session_root.sh`, and to the eight skills that take `--type`) is "Target (open)" in `docs/design.md#registry-and-adapters` and `#sessions-and-roots`. It is the owner's call on its own; the Registry inventory is the evidence, and the plan must update both sections in the same change (ADR-0017). Registry-only discovery is already decided and needs no ask. |
| A change includes its consequences | Action needed | Fresh-clone loose ends are consequences of the old layout and must be in scope, not follow-ups: `validate_workspace.py` hard-fail, `make setup` prompting for a repository, README / AGENTS.md / Makefile help describing `project/`, and a regression test for a workspace with no project (`validate`, `setup`). |
| Only what's needed | Watch | The issue's idea is plausible, but Table 2 gives 4 real, 5 thin and 3 no-op verbs for a workspace adapter; the benefit has to be shown per branch site. Collapse only the sites whose workspace branch is only a base-dir/slug difference; keep tooling-hosting properties (changing `merge_pr.sh` mid-run, Ask-First instruction files) as entry properties, as the issue says. |
| Workspace vs project separation | Watch | A pinned workspace entry makes the workspace appear as a "project" in registry listings, `dashboard.sh`, `register_project.sh --remove` and the user-tier installer (which enables the plugin per registered root). The plan must say these skip or special-case the pinned entry deliberately, and that `register_project.sh` refuses to add or remove it. |
| Improve incrementally | OK | Three small pull requests in the order below, each independently mergeable. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0011 (adapter contract) | Yes | A new type adds a workspace `adapter.sh` implementing all 12 verbs (`validate_adapter.sh` checks it) plus a `registration.conf`. ADR-0011's discovery order is superseded by ADR-0016 (Accepted) for the `project/` step. |
| ADR-0016 (session roots, Accepted) | Yes | Decision 2 (tree hosts no project) is what PR 4 builds. The root rule (a session works only under the root it was launched in) uses `session_root.sh --type`; the plan must say what the workspace's pinned entry means for it. |
| ADR-0018 (plugin skill delivery) | Yes | The skills that take `--type` and #446 (plugin at user scope) overlap; a pinned entry must not make the installer enable the plugin in the workspace root twice. |
| ADR-0012 (worktree composition) | Watch | The workspace entry's `worktree_repos` is a single `.` line; `worktree_create.sh` does not call it for the workspace today. |
| ADR-0008 (ADR scope) | Watch | Making the workspace a project is a substantive change to ADR-0011's resolution, so it probably needs an ADR (or a superseding note), not just design text. |
| ADR-0017 (design kept current) | Yes | The Registry inventory tables are "cut back once #295 is decided" by their own text; do that in the deciding change. |

### Consequences

- `docs/design.md`: Registry and adapters (inventory cut back, Target resolved), Sessions and roots (Target items), Change log, line counts.
- Makefile (`setup`, `project.done`, help text, header), `validate_workspace.py`, README, `AGENTS.md` (Ask First; lines 10 and 28 and the Terminology table), `.agent/WORKTREE_GUIDE.md`, `.agent/projects.local.example`, roadmap Direction.
- Scripts: every file in Findings above; tests `test_project_registry.sh`, `test_worktree_create.sh` and the others that build a `project/` fixture.
- Skills that document `--type` (start-task, run-issue, plan-task, triage-reviews, research, inspiration-tracker, gather-project-knowledge, onboard-project), and `skill_prefix.sh`.
- Machine steps (not code): unregister `p11-jazzy` and `p11-rolling`, delete `projects/`, remove the `project` symlink; no migration (owner, 2026-11-12).

### Recommendations

- Not ready to plan as one unit. Plan it as three pull requests, and ask the owner the design questions below before the plan fixes PR 2 and PR 3; PR 1 needs no design decision and can start now.
- PR 1, "a workspace with no project works" (the host's leaning, confirmed): drop the `project/` and `projects/` fallbacks and their docs. Concretely: `validate_workspace.py` passes with no project and no registry entries (no `project/` checks, no remote-origin check on `project/`); `make setup` depends only on the venv/pre-commit and git-bug stamps, with project registration left to `register_project.sh` (drop `project.done` and the `setup_project.sh` prompt from `setup`); remove the `adapter` legacy step 3, `wt_legacy_*` helpers, the `registry_worktree_dir` unregistered-name fallback, the `PJ_ROOT_EFFECTIVE` fallback in `merge_pr.sh`, and the `project/` branch in `gh_create_pr.sh`, `dashboard.sh`, `sitrep_root.sh`, `session_root.sh`, `worktree_list.sh`, `discover_governance.sh`, `configure_git_identity.sh`, `lib/workspace.py`; rewrite README, AGENTS.md terminology (Ask First), Makefile help and header, WORKTREE_GUIDE, `projects.local.example` and the design's Sessions-and-roots Target (move it to Now); tests with a no-project fixture asserting `make validate` and `make setup` succeed from a fresh clone. Sequence behind #429 part 2 and #437, since it touches `worktree_create.sh`, `merge_pr.sh` and `dispatch_phase.sh`; do a rebase check against #446 for `user_tier_install.sh`, `register_project.sh`, `skill_prefix.sh`.
- PR 1 also decides, with the owner, what happens to the `projects.d/<name>.sh` reading and the shared `project_config.sh` fallback (#265 plan item 4). Recommend making it a separate PR 1b after PR 1, because it changes how registered projects get their commands and this machine still has `p11-*.sh` and `project_config.sh`. The host should confirm that "do it with 265" includes it.
- PR 2, the pinned entry and the workspace adapter: add `.agent/project_types/workspace/` with `adapter.sh` (12 verbs, per Table 2) and `registration.conf`, and a pinned entry in `_project_registry.sh` that `registry_entries_full` always returns first and that cannot be added or removed by `register_project.sh`. Acceptance: Table 2 verbs run through `adapter` for the workspace, `validate_adapter.sh` passes, `validate_workspace.py` does not recurse through the workspace `validate` verb. No branch site changes yet.
- PR 3, the special-case collapse: replace each branch site in Table 1 with the registry lookup, one script per commit, with tests; recount the sites at plan time by reading, not by the 2026-09-18 numbers. Keep `--type` working until the owner decides (below).
- Owner question A (design, on its own): does `--type workspace|project` survive as a deprecated alias, as an override of what is derived from the cwd (today's documented behaviour in Sessions and roots), or go? It changes eight skills' argument lists and `session_root.sh`; it is cheap to keep as an alias, costly to retire later because dispatched phases and skill texts pass it.
- Owner question B (design, on its own): is the workspace a registered project, with a pinned entry, a `workspace` type and a one-lookup path, or does the registry-only discovery (PR 1) stand alone and the `--type workspace` branch stay as the one special case? Table 2's tally (3 no-op, 5 thin, 4 real) is the evidence; the design text says no conclusion is drawn from it. If the answer is no, #295 closes after PR 1 and the inventory is cut back.
- Owner question C (design, on its own): the session root rule. If the workspace is a registered root, can a workspace session launched at the workspace root run an issue of the workspace through the same `session_root.sh` lookup as a project session, and does the user tier then enable the plugin for the workspace root by registration or by its existing install path (ADR-0018, #446)?
- Owner question D (small, may be a host call listed for veto): should `make setup` ever prompt for a project, or point at `register_project.sh <path>` in its output? The loose-end text says setup must not depend on a project; the printed pointer is a mechanism choice.
- Add the fresh-clone check as the acceptance test of PR 1 and of the whole issue: clone the workspace to an empty directory with no `project/`, no registry, and run `make setup`, `make validate`, `make test`. The second-machine move (the pickerel transition) is the real run.
- Do not widen: leave #429, #446 and #437 alone; list their overlap on the issue so the plan sequences against them.

### Actions
- [ ] Whether the workspace becomes a registered project (a pinned entry, a workspace adapter, and what that does to `--type`, to the root rule in `session_root.sh`, and to the eight skills that take `--type`) is "Target (open)" in `docs/design.md#registry-and-adapters` and `#sessions-and-roots`. It is the owner's call on its own; the Registry inventory is the evidence, and the plan must update both sections in the same change (ADR-0017). Registry-only discovery is already decided and needs no ask.
- [ ] Fresh-clone loose ends are consequences of the old layout and must be in scope, not follow-ups: `validate_workspace.py` hard-fail, `make setup` prompting for a repository, README / AGENTS.md / Makefile help describing `project/`, and a regression test for a workspace with no project (`validate`, `setup`).
- [ ] Not ready to plan as one unit. Plan it as three pull requests, and ask the owner the design questions below before the plan fixes PR 2 and PR 3; PR 1 needs no design decision and can start now.
- [ ] PR 1, "a workspace with no project works" (the host's leaning, confirmed): drop the `project/` and `projects/` fallbacks and their docs. Concretely: `validate_workspace.py` passes with no project and no registry entries (no `project/` checks, no remote-origin check on `project/`); `make setup` depends only on the venv/pre-commit and git-bug stamps, with project registration left to `register_project.sh` (drop `project.done` and the `setup_project.sh` prompt from `setup`); remove the `adapter` legacy step 3, `wt_legacy_*` helpers, the `registry_worktree_dir` unregistered-name fallback, the `PJ_ROOT_EFFECTIVE` fallback in `merge_pr.sh`, and the `project/` branch in `gh_create_pr.sh`, `dashboard.sh`, `sitrep_root.sh`, `session_root.sh`, `worktree_list.sh`, `discover_governance.sh`, `configure_git_identity.sh`, `lib/workspace.py`; rewrite README, AGENTS.md terminology (Ask First), Makefile help and header, WORKTREE_GUIDE, `projects.local.example` and the design's Sessions-and-roots Target (move it to Now); tests with a no-project fixture asserting `make validate` and `make setup` succeed from a fresh clone. Sequence behind #429 part 2 and #437, since it touches `worktree_create.sh`, `merge_pr.sh` and `dispatch_phase.sh`; do a rebase check against #446 for `user_tier_install.sh`, `register_project.sh`, `skill_prefix.sh`.
- [ ] PR 1 also decides, with the owner, what happens to the `projects.d/<name>.sh` reading and the shared `project_config.sh` fallback (#265 plan item 4). Recommend making it a separate PR 1b after PR 1, because it changes how registered projects get their commands and this machine still has `p11-*.sh` and `project_config.sh`. The host should confirm that "do it with 265" includes it.
- [ ] PR 2, the pinned entry and the workspace adapter: add `.agent/project_types/workspace/` with `adapter.sh` (12 verbs, per Table 2) and `registration.conf`, and a pinned entry in `_project_registry.sh` that `registry_entries_full` always returns first and that cannot be added or removed by `register_project.sh`. Acceptance: Table 2 verbs run through `adapter` for the workspace, `validate_adapter.sh` passes, `validate_workspace.py` does not recurse through the workspace `validate` verb. No branch site changes yet.
- [ ] PR 3, the special-case collapse: replace each branch site in Table 1 with the registry lookup, one script per commit, with tests; recount the sites at plan time by reading, not by the 2026-09-18 numbers. Keep `--type` working until the owner decides (below).
- [ ] Owner question A (design, on its own): does `--type workspace|project` survive as a deprecated alias, as an override of what is derived from the cwd (today's documented behaviour in Sessions and roots), or go? It changes eight skills' argument lists and `session_root.sh`; it is cheap to keep as an alias, costly to retire later because dispatched phases and skill texts pass it.
- [ ] Owner question B (design, on its own): is the workspace a registered project, with a pinned entry, a `workspace` type and a one-lookup path, or does the registry-only discovery (PR 1) stand alone and the `--type workspace` branch stay as the one special case? Table 2's tally (3 no-op, 5 thin, 4 real) is the evidence; the design text says no conclusion is drawn from it. If the answer is no, #295 closes after PR 1 and the inventory is cut back.
- [ ] Owner question C (design, on its own): the session root rule. If the workspace is a registered root, can a workspace session launched at the workspace root run an issue of the workspace through the same `session_root.sh` lookup as a project session, and does the user tier then enable the plugin for the workspace root by registration or by its existing install path (ADR-0018, #446)?
- [ ] Owner question D (small, may be a host call listed for veto): should `make setup` ever prompt for a project, or point at `register_project.sh <path>` in its output? The loose-end text says setup must not depend on a project; the printed pointer is a mechanism choice.
- [ ] Add the fresh-clone check as the acceptance test of PR 1 and of the whole issue: clone the workspace to an empty directory with no `project/`, no registry, and run `make setup`, `make validate`, `make test`. The second-machine move (the pickerel transition) is the real run.
- [ ] Do not widen: leave #429, #446 and #437 alone; list their overlap on the issue so the plan sequences against them.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 12:39 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review keeps the issue's goal and the owner's 2026-11-12 direction to do it together with issue 265's fourth pull request; it orders the work as three pull requests and finds the first needs no design decision)
**After**: issue-actions
**Decision**: proceed

The host read the Issue Review entry at 15b85e63. Planning goes ahead for the first pull request only: a workspace with no project validates and sets up, the legacy `project/` and `projects/` fallbacks and their documentation go, the `projects.d/<name>.sh` reading and the shared-config fallback go with them (item 4 of issue 265's plan; the owner's "no migration necessary" removes the only users), with a fresh-clone no-project test. Order against other work, decided by the host: this pull request goes ahead of issue 429 part 2, which rebases onto it, because the second machine cannot validate until it lands and issue 429 part 2 is to be driven from that machine; it waits only for issue 437 (pull request 448).

The review's owner questions, as the host reads the record: B (is the workspace a registered project) is the owner's own idea of 2026-09-18 and the issue's title, so it is not re-asked. A (whether --type survives) was delegated to the plan by his 2026-09-18 comment ("Decide in the plan whether `--type` survives as a deprecated alias"), so the plan for the second and third pull requests decides it and lists it for his veto. C (what a pinned entry changes for the session-root rule and the plugin) is put to him on its own when the second pull request is planned. D (make setup points at register_project.sh) is a host decision: yes. The AGENTS.md wording change is Ask First and is shown to him before it is committed.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 12:45 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-295/plan.md` at `14b714c4`

Pull request 1 of three is planned in full (a workspace with no project validates and sets up; the project/ and projects/ fallbacks, the .sh and shared-config reading, and the worktrees/project transition are removed, each with a test; docs and a fresh-clone test included; the AGENTS.md wording is a separate last commit awaiting the owner). Pull requests 2 (pinned entry and workspace adapter) and 3 (special-case collapse) are an outline with the open questions; --type is proposed to survive as a deprecated alias for the owner's veto.

## Plan Review
**Status**: complete
**When**: 2026-11-12 12:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #295 — Treat the workspace as a registered project (pinned registry entry + workspace adapter) instead of a --type special case
**Plan**: `.agent/work-plans/issue-295/plan.md` at `14b714c4`
**Branch**: `feature/issue-295`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Concern | One pull request of ~55 files, +1,000/-1,700, 12 commits, removal-heavy. The plan's reason for not splitting ("cannot be split without leaving a half-legacy state that fails validate") is contradicted by the fresh-clone run below: only one check fails, and every other legacy branch is dormant when `project/` is absent. Split recommended (finding 1). |
| Issue alignment | Good | Covers the Issue Review's PR 1 list, the owner's 2026-11-12 directions and #265 item 4. Serves, as checked: "Workspace goal 'The workspace is project-agnostic and usable on any project' (README, Workspace goals) and machine independence of a fresh clone; `docs/design.md#sessions-and-roots` (registry-only discovery, Target to Now) and `docs/design.md#registry-and-adapters`." Goal and sections exist; no rule broken. |
| File targeting | Needs work | Missed sites: `gh_create_issue.sh` 172-173 and `pr_status.sh` 40 read `project/`; `.claude/skills/review-plan/SKILL.md` 104-123 calls `wt_legacy_worktree_dirs`, which step 6 deletes; docs not listed (finding 4). |
| Consequences | Needs work | Machine step 3 silently drops the install command of the owner's registered single-repo project (finding 3); `make sync` refusal creates a new fresh-clone loose end (finding 5). |
| Principle alignment | Needs work | "Improve incrementally": the split is possible and serves the blocked machine (finding 1). "Test what breaks": the fresh-clone test must not do network installs inside the pre-commit-run suite (finding 6). Design picture and prior art are stated. |
| ADR compliance | Good | ADR-0011, 0012, 0016, 0017, 0018 handled as the plan says; ADR-0011's mention of `setup_project.sh` is a record and needs no edit. |
| ROS conventions | N/A | Workspace plan. |

### Fresh-clone check (point 2 of the brief): run, not left unverified

`git clone` of this worktree (at 6b0754db) into the session scratchpad, then `env -i PATH=/usr/bin:/bin HOME=<scratch home> make validate </dev/null`. Nothing installed. Output:

```
Validating workspace...

  venv: not installed (run make setup)
  pre-commit hook: not installed (run make setup)
============================================================
Workspace Validation Results
============================================================
❌ Workspace validation FAILED
   project/ directory does not exist
     Run: make setup  (will prompt for repo URL or path)
============================================================
make: *** [Makefile:126: validate] Error 1
```

Exit 2. The second machine's report is reproduced. Then, in the scratch clone only, the two `issues.append(...)` lines of `validate_workspace.py` (172-173) were replaced by `pass` and `make validate` re-run: "✅ Workspace validation PASSED!" (plus a stray "project remote: None" line from the remote-origin block), then `user_tier_install.sh --check` printed "agent_workspace user tier: not installed (optional; ...)" and exited 0; `make validate` exit 0. So validate needs only the `project/` block (159-198) removed. `make setup` was not run (it installs a venv over the network); by reading, its only project dependency is `$(STAMP)/project.done` → `setup_project.sh`, which prompts.

### Findings

1. **[Scope]** (must-fix) Split pull request 1 into three. The fresh-clone run shows the second machine is blocked by two things only, validate's `project/` block and `make setup`'s `project.done`; the legacy branches elsewhere (adapter step 3, `wt_legacy_*`, `PJ_ROOT_EFFECTIVE`, `session_root.sh`, `registry_worktree_dir`'s transition dir) only fire when `project/` exists or a name is unregistered, so leaving them one more pull request breaks nothing on a machine without `project/`. Recommended:
   - **A, "a fresh clone works with no project"** (Part of #295 and #265): `validate_workspace.py` drops 159-198 (keep the `lib/workspace.py` helpers, `sync.py` imports them, until B); Makefile `setup` without `project.done`, the pointer lines, `help` text and header comment (leave the MAIN_ROOT cases for B); delete `setup_project.sh` and its `script_reference.md` row; the registry-slug acceptance in `gh_create_pr.sh` and `gh_create_issue.sh` (finding 2, additive; needed on the second machine as soon as a project is registered there); `make sync` with nothing resolvable syncs the workspace alone (finding 5); AGENTS.md Terminology, Repo ownership, table row and Build & Test (true already: the settings file is read first today); `docs/design.md` setup row and a Sessions-and-roots note; `test_validate_workspace_no_project.sh` and `test_fresh_clone_no_project.sh` (assertions a, b, c, plus `make dashboard` and `make sync` exit 0; d and e move to B). Acceptance: in a scratch clone with a scratch HOME and nothing registered, `make validate`, `make setup </dev/null` (stamps pre-seeded, finding 6), `make dashboard` and `make sync` exit 0 and write no `project/` or `projects/`; after `register_project.sh <demo> --skip-run`, `gh_create_pr.sh` run in the demo checkout passes its repo-safety check. Roughly 10-12 files.
   - **B, "the `project/` and `projects/` fallbacks go"** (steps 1's registry-path rule, 3, 4, 6, 7, 8 minus the gh_* scripts, plus `pr_status.sh`, the skill/doc sites of finding 4, design Target to Now, `.gitignore` `project`/`projects/` lines). Acceptance: the plan's refusal tests, the fresh-clone assertions d and e, the grep in finding 4 returns only records. Machine steps 1-2 (unregister the two clones, remove `projects/` and the symlink) follow its merge.
   - **C, "`.sh` and shared-config reading go"** (steps 5 and 9, `register_project.sh`, `registration_verify.sh`, ROS tests, `.gitignore` `project_config.sh` line), Closes #265. Acceptance: the plan's step-5/9 tests, and the install move of finding 3 done before machine step 3. Sequence C after #446's second pull request (both edit `register_project.sh`).
   B and C can merge into one if the host prefers fewer rounds; A must not wait for either. With A merged, the second machine can drive B and C itself.
2. **[File targeting]** (must-fix) `gh_create_issue.sh` 160-190 has the same repo-safety check as `gh_create_pr.sh`, and neither the plan nor its file table lists it; `pr_status.sh` 40 (`make pr-triage`) also reads `project/`. This is what a registered single-repo project relies on today: in that project's session, `gh_create_pr.sh` and `gh_create_issue.sh` accept its repository only because `project/` is a symlink to its checkout (run-issue's publish step passes `-R` only for package issues, `run-issue/SKILL.md` 676-685). On a machine without the symlink, or here after machine step 2, PR and issue creation from that project's sessions is refused. Step 8's registered-roots loop must cover both scripts, and must read the registry of the main checkout (resolve it from the git common dir as the Makefile's `WS_ROOT` does): both scripts compute `_WORKSPACE_ROOT` from their own directory, which in a workspace worktree has no `.agent/projects.local`. Test: a registered sandbox root's slug is accepted by both, an unrelated slug refused.
3. **[Consequences]** (must-fix) Machine step 3 deletes `.agent/project_config.sh`, but on this machine that file's `INSTALL_CMD` (a `cmake --install` line) is the install command of the registered single-repo project: its settings file `.agent/projects.d/<name>` holds only `build` and `test`, so `adapter install` falls through to the shared file today (`single_project/adapter.sh` 37-66, 197-208). After step 5 plus machine step 3, `make install PROJECT=<name>` prints "INSTALL_CMD not set — nothing to install (this is fine for most projects)" and exits 0: a silent loss. Add a machine step before step 3: `project_setting.sh set <name> install=<the command>` (or the owner says install is not wanted). Make the stale-file report for `project_config.sh` name each command key it sets that a registered project's settings file lacks, so the same loss on another machine is told, not silent. "No migration necessary" holds for the clones, not for this one key.
4. **[File targeting]** (must-fix) Sites the plan does not list: `.claude/skills/review-plan/SKILL.md` 92-123 (calls `wt_legacy_worktree_dirs`; after step 6 its lookup prints "command not found" and its text describes the removed fallback); `.claude/skills/start-task/SKILL.md` 205; `.agent/WORKFORCE_PROTOCOL.md` 27; `.agent/AI_IDENTITY_STRATEGY.md` 91, 117, 251 (describes `configure_git_identity.sh` on `project/`, which step 8 changes); `.agent/knowledge/documentation_verification.md` 82; `.agent/knowledge/review_static_analysis.md` 24 and `.claude/skills/review-code/SKILL.md` 247 (`project/**` path classes). Make the acceptance a grep the implement pass runs: `grep -rn "project/\|project_config\|worktrees/project\|wt_legacy\|wt_transition\|wt_project_base_glob" .claude .agent docs Makefile`, excluding `.agent/work-plans/`, `docs/decisions/`, `docs/fork_parity.md` and digests (records); every remaining hit is either a record or deliberate.
5. **[Consequences]** (should-fix) Veto the `make sync` refusal. Today it syncs the workspace repo, then `project/` (`single_project/sync.py` 164-172); on a clone with nothing registered it is the way to update the workspace. A refusal there is a new fresh-clone loose end, against the owner's "keep up with the loose ends". With no `PROJECT=` and nothing resolvable: sync the workspace repo and print that no project was synced. Cover it in the fresh-clone test.
6. **[Principle alignment]** (should-fix) The fresh-clone test runs under `run_script_tests.sh`, which the pre-commit hook runs; a `make setup` that creates a venv and pip-installs from the network does not belong there (slow, flaky offline, and the "skipped part" branch makes the result depend on the network). Always pre-seed `.make/setup-dev.done` and set `CI=1`, so the test checks the Makefile wiring (no prompt, the pointers, no `project/`), never pip. The test clones committed content only; say so in its header. If #444 lands first, re-run `test_script_tests_hook_scope.sh` for its drift rule on the two new suites.
7. **[Accuracy]** (note) The plan says `project/worktrees/` does not exist on this machine. It does: it is the registered project's own in-tree worktree dir, seen through the `project` symlink (empty; its `git worktree list` shows only the main checkout). Nothing to migrate, so the conclusion holds; the Makefile's `/project/worktrees/` MAIN_ROOT case has no real path to match.
8. **[Instruction file]** (note) The proposed AGENTS.md wording is true of the code after A (Terminology, Repo ownership, table row) and true today for Build & Test (the settings file is read first; `project_setting.sh set` takes several `key=value` pairs). Line count: the bullet is 3 lines for 2 (+1), the paragraph 4 for 5 (-1), but Build & Test is 4 lines for 3 (+1), not 0: AGENTS.md goes 199 to 200, still within the 200 budget. The plan says "current text on the left of each becomes" but shows only the new text; give the implement pass the replaced ranges: 10-11, 18-22, 28, 157-159.
9. **[Approach]** (note) `ROS_ROOT_DIR` from the environment reverses current behaviour: `_rc_ros_root` clears it before sourcing the config (`ros2_colcon/adapter.sh` 185-190), in line with #332's "only a config file sets it". Acceptable as the plan proposes (only tests and non-standard installs use it, and no registered project on either machine needs it once the clones go), but the adapter header and `projects.local.example` should say it is the one value read from the environment.

### Open questions (calls, for the host to list for the owner's veto)

- `--type` as a deprecated alias for one release: agree; there are no releases, so tie removal to the roadmap deferral with a `gh-issue` check, and refuse a contradicting value as planned.
- `ROS_ROOT_DIR` from the process environment: agree, with the header note of finding 9.
- Removing `register_project.sh`'s adoption copy from `<name>.sh`: agree; the only `.sh` files on either machine belong to the clones being deleted.
- Stale `.sh` and shared files warn, not fail: agree, with the per-key report of finding 3 for the shared file.
- `make sync` refuses with no project: veto; sync the workspace alone (finding 5).

### Overlap (point 6 of the brief)

Nothing beyond "merge main in before review", given the split: PR 448 (#437) touches `test_package_issue_loop.sh` (records-gate hunks only, not the `demo.sh` fixture), `script_reference.md` and `docs/design.md`, line-level; #394's branch adds a `.gitignore` hunk away from the `project/` lines; #444 changes the runner and the hook-scope drift test (finding 6); #446's second pull request edits `register_project.sh`, which under the split only C touches, so C goes after it. #429 part 2 rebases onto B (it shares `worktree_create.sh`, `merge_pr.sh`, `dispatch_phase.sh`), not onto A.

### Summary

The plan's content is sound and the refusal rule is right, but pull request 1 is three changes, and only the smallest is what the second machine is waiting for; the fresh-clone run shows A alone clears it. Four sites are missing, and one of them (`gh_create_issue.sh`, with `gh_create_pr.sh`) is what the owner's registered project uses today through the symlink, and the shared-config removal silently drops that project's install command. Revise, then implement A first.

### Recommended Actions

- [ ] Split pull request 1 into A (fresh clone works), B (`project/`/`projects/` fallbacks) and C (`.sh` and shared-config reading), with the acceptance in finding 1; A goes first and alone.
- [ ] Cover `gh_create_issue.sh` and `pr_status.sh`; make the registered-roots slug check read the main checkout's registry; ship it in A (finding 2).
- [ ] Add the machine step moving the install command into the registered project's settings file before the shared file is deleted, and the per-key stale-file report (finding 3).
- [ ] Add the missed skill and doc sites and the grep acceptance (finding 4).
- [ ] `make sync` with nothing resolvable syncs the workspace alone (finding 5).
- [ ] Fresh-clone test: pre-seed stamps always, no network; add `make dashboard` and `make sync` (finding 6).
- [ ] AGENTS.md: correct the net line count to +1 (200) and name the replaced ranges (finding 8).

## Checkpoint
**Status**: complete
**When**: 2026-11-12 12:51 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work: four must-fix and two should-fix findings, all about how the first pull request is cut and which sites it covers, none a change to what the owner asked for; first host revise on this plan)
**After**: plan
**Decision**: revise

The host read the Plan Review entry at 89a00dfb. All nine findings are taken as written. The first pull request is split three ways as the review gives it: A (a fresh clone works with no project) goes first and alone, because the fresh-clone run showed the second machine is blocked by two things only; B (the `project/` and `projects/` fallbacks go) and C (the `.sh` and shared-config reading go, after issue 446's second pull request) follow, B and C as one pull request unless the plan finds a reason to keep them apart. Host decisions on the plan's open questions, listed for the owner's veto: `--type` survives as a deprecated alias, its removal tied to a roadmap deferral; ROS_ROOT_DIR is read from the environment and documented as the one such value; the adoption copy in register_project.sh goes; stale config files warn and name each command key a registered project lacks; `make sync` with no project syncs the workspace alone. The machine steps gain the reviewer's step for the registered single-repository project's install command before the shared config file is deleted. Each of A, B and C is its own pull request on its own timeline step; the revised plan details A fully and B and C enough to plan from.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 12:55 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-295/plan.md` at `dfee1b5c`

Revision after the plan review (needs-work) and the host's checkpoint. The first pull request is split: A (a fresh clone works with no project: validate drops its project/ block, make setup loses project.done and prints the pointers, setup_project.sh deleted, both gh_create_* scripts accept any registered project's repository via a new registry_repo_slugs read from the main checkout's registry, make sync says no project was synced, two new offline tests, small design edit, AGENTS.md wording as a held last commit with its exact ranges) is planned in full; B and C are one pull request (closes 265) planned in detail for its own plan review, with the install-command machine step first, the per-key stale-file report and the grep acceptance; the pinned entry and the special-case collapse stay an outline, with --type a deprecated alias tied to a roadmap deferral. Findings 1-9 each answered in the plan. dispatch_phase.sh says nothing about several pull requests per issue; next takes the pull request state from the host, so the host passes none for the B and C section, as issue 429's part 2 did.

## Plan Review
**Status**: complete
**When**: 2026-11-12 12:59 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #295 — Treat the workspace as a registered project (pinned registry entry + workspace adapter) instead of a --type special case
**Plan**: `.agent/work-plans/issue-295/plan.md` at `dfee1b5c`
**Branch**: `feature/issue-295`

Second plan review, narrow: pull request A ("a fresh clone works with no project") in full against the code; the B and C section only for findings 3, 4, 7, 9 of the first review and for anything that boxes A in. Ready with five should-fix notes the implement pass carries; none changes what A builds.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | A is about 13 files (dashboard.sh added by finding 5), 7 commits, the cut the first review gave. |
| Issue alignment | Good | Serves, as checked: "Workspace goal 'The workspace is project-agnostic and usable on any project' (README, Workspace goals) and machine independence of a fresh clone; `docs/design.md#sessions-and-roots` (registry-only discovery, Target to Now) and `docs/design.md#registry-and-adapters`." First review's findings 1, 2, 5, 6, 8 are answered in A; 3, 4, 7, 9 in the B and C section. |
| File targeting | Needs work (minor) | `dashboard.sh` (finding 5) and the existing validate test in `test_project_registry.sh` (finding 2) are missing from A's table. Every other A site checked and correct; AGENTS.md ranges 10-11, 19-23, 28, 157-159 verified against the 199-line file. |
| Consequences | Good | Legacy-machine check below: A breaks nothing for a machine with `project/` and registered projects. |
| Principle alignment | Good | Tests offline (stamps pre-seeded, `CI=1`, `git_bug_setup.sh` exits 0 on `CI`); design edit in the same change; AGENTS.md held as its own commit. |
| ADR compliance | Good | ADR-0011 (record only), 0016, 0017, 0018 as the plan states. |
| ROS conventions | N/A | Workspace plan. |

### Checked by running (a scratch clone of this worktree at 54121c0a, scratch HOME, `env -i PATH=/usr/bin:/bin CI=1`, `.make/setup-dev.done` pre-seeded, `origin` a local bare repository)

- `make dashboard` with nothing registered: **exit 0**, no `project/` or `projects/` created (the plan's one unverified point). It prints "⚠️ project/ not configured. Run: make setup" and "Status: ⚠️ Not configured (run: make setup)" (finding 5).
- `make sync`: exit 0, workspace fetched, then "⚠️ project/ not configured. Run: make setup" (the line A step 4 replaces).
- `make setup </dev/null` with `setup:` edited to depend on `git-bug.done` only: "CI environment — skipping git-bug setup. / ✅ Setup complete.", exit 0, no `project/`.
- `validate_workspace.py --verbose` with only the planned lines 159 and 171-200 removed: `NameError: name 'remote_url' is not defined` at the final verbose print (finding 1).
- `register_project.sh <demo> --skip-run`: refused and rolled back ("FAIL: no build command", "FAIL: no test command", `STATUS=refused`); with `--set build=none --set test=none --skip-run`: registered (finding 4).
- `gh_create_pr.sh --title t --body b --no-signature` in the demo checkout (origin `github.com/demo-owner/demo`, `gh` stubbed): today refused, "gh would target 'demo-owner/demo' ... Project repo: <not configured>", exit 2: the defect A step 3 fixes is reproduced.
- The same script run from a worktree of the scratch clone, cwd in the demo checkout: refused earlier, by the user-tier guard: "refusing to run: ... neither inside the workspace (<worktree>) nor under a registered project root (<worktree>/.agent/projects.local)", exit 1 (finding 3).
- `make build` with nothing registered: still "❌ No project_config.sh found. Create .../project_config.sh", exit 2: B and C's (step 4), not A's; A's new `help` text for `build` disagrees with it until B lands (note 6).

### Legacy machine (`project/` symlink plus registered projects) under A

Nothing breaks. `validate` loses only the `project/` checks (registry entries still delegate to `adapter validate`); `setup` loses a rule whose stamp is already present; the `gh_create_*` accepted set only grows (workspace, `project/` slug, every registered root's slug); the `sync.py` and `dashboard.sh` message changes are in the branches taken only when `project/` is absent; `setup_project.sh` has no caller besides the Makefile rule (grep: Makefile, `script_reference.md`, the `single_project/adapter.sh` comment); the AGENTS.md wording is true there too.

### B and C section

First-review findings answered: 3 (machine step 1 moves the install command before the shared file goes; step 9's per-key stale-file report), 4 (step 11 lists every missed site and carries the grep acceptance), 7 (the correction in step 6), 9 (the `ROS_ROOT_DIR` sentence in the adapter header and `projects.local.example`, step 5). Nothing in it boxes A in: B step 3 keeps A's "No project was synced" path outside the dispatcher's refusal, and B step 8 deletes the `project/` branch A leaves in the `gh_create_*` scripts. If finding 3 drops the git-common-dir resolution, B step 8 needs no change.

### Findings

1. **[File targeting]** (should-fix) A step 1 names lines 159-198, but the end of `validate_workspace()` (lines 335-336, `if verbose: print(f"   project remote: {remote_url}")`) reads `remote_url` from the removed block; removing only the named range makes `make validate` (always `--verbose`) crash with `NameError` (run above). Remove 335-336 with the block. `get_git_branch` (51-64) is then unused, as are the `get_project_path` and `get_project_remote_url` imports.
2. **[Consequences]** (should-fix) `test_project_registry.sh` `test_validate_neither_shape` (382-389) asserts exit 1 and "project/ directory does not exist"; A makes both false. Rewrite it to exit 0 and the "no project registered" line, in the commit that changes validate, and list `test_project_registry.sh` for that too. That file's `make_validate_sandbox`/`run_validate` fixtures already build the no-project and one-project sandboxes A step 1 asks for; the implement pass may put A step 1's cases there instead of a new `test_validate_workspace_no_project.sh` (B and C step 1 and 9 then name that file).
3. **[Approach]** (should-fix) A step 3's git-common-dir resolution is unreachable, and its planned test cannot pass. Both scripts run `registry_require_root "$_UT_SCRIPT_DIR/../.."` first (`gh_create_pr.sh` 87, `gh_create_issue.sh` 82); a worktree copy run with cwd in a project checkout is refused there, before the repo-safety check (run above), and a worktree copy run with cwd in the worktree targets the workspace slug, already accepted. Project sessions run the main checkout's copy (`$WS_ROOT` from `~/.claude/agent-workspace-root`, `run-issue/SKILL.md` 676), whose `_WORKSPACE_ROOT` holds the registry. Resolution: `registry_repo_slugs "$_WORKSPACE_ROOT"` (drop the common-dir resolution; do not widen `registry_require_root` in A), and the tests run a sandbox main checkout's copy with cwd in the registered demo checkout (accepted) and in an unrelated `github.com` checkout (refused by the guard; and a registered root whose slug differs from the current repository's, refused by the safety check). Both scripts run `set -euo pipefail` (pr 71, issue 65): `registry_repo_slugs` returns 0 on a parse error or missing registry, as the plan says it prints nothing, or the caller adds `|| true`.
4. **[Accuracy]** (should-fix) `register_project.sh <demo path> --skip-run` refuses and rolls back with no build or test command (run above). A's acceptance text and assertion (e) of `test_fresh_clone_no_project.sh` use `register_project.sh <demo path> --set build=none --set test=none --skip-run`.
5. **[Consequences]** (should-fix) `make dashboard` exits 0 with nothing registered (the plan's open point, now verified), so A step 5(c)'s "fix it in A if it fails" does not fire, but its two no-project pointers, `dashboard.sh` 163 (`check_warn "project/ not configured. Run: make setup"`) and 345 (`Not configured (run: make setup)`), send a fresh clone to a `make setup` that, after A, configures no project. Reword both to the A pointer ("No project is registered. Register one: .agent/scripts/register_project.sh <path>"), add `dashboard.sh` to A's files, and have assertion (c) check the dashboard output names `register_project.sh` and does not say "Run: make setup". Both lines sit in branches a machine with `project/` never takes. (`adapter.sh` 229 and `worktree_create.sh` 492 carry the same pointer in code B and C deletes; they stay B's.)
6. **[Accuracy]** (note) Line references to re-read, no change of intent: the `sync.py` message is at 178-180 (plan: 164-172); the design `setup` row is line 391 (plan: 392). Between A and B, `make build` with nothing registered still says to create `project_config.sh` while A's `help` text says "the project's settings file (PROJECT=<name>)"; B and C step 4 replaces that message, so A leaves it.

### Summary

A is right and buildable from the plan; the acceptance holds by the runs above once findings 1 and 4 are applied, and A breaks nothing on a machine that still has `project/` and registered projects. Pull request A: ready, with the five should-fix notes carried by the implement pass. The B and C section answers findings 3, 4, 7 and 9 and does not constrain A.

### Recommended Actions

- [ ] Remove `validate_workspace.py` 335-336 and the then-unused `get_git_branch` and imports with the `project/` block (finding 1).
- [ ] Rewrite `test_validate_neither_shape` to the exit-0 outcome in the validate commit (finding 2).
- [ ] `registry_repo_slugs "$_WORKSPACE_ROOT"`, no common-dir resolution; test with the sandbox main checkout's copy; return 0 on parse errors (finding 3).
- [ ] `--set build=none --set test=none` on the demo registration in the acceptance and test (finding 4).
- [ ] Reword `dashboard.sh` 163 and 345 to the `register_project.sh` pointer and assert it in (c) (finding 5).

## Checkpoint
**Status**: complete
**When**: 2026-11-12 13:01 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second plan review's verdict is ready for pull request A, verified in a scratch clone, with five should-fix notes and one accuracy note the implement pass can carry; none changes what is built)
**After**: plan
**Decision**: proceed

The host read the Plan Review entry at 3ad2d4f4. This implement pass builds pull request A only ("a fresh clone works with no project"). The review's findings 1 to 6 are requirements equal to the plan, and where they differ the review wins. The AGENTS.md commit is not made in this pass: the owner has been shown the four passages and has not yet answered. Pull request B and C's section gets its own plan review before it is implemented.

## Implementation
**Status**: complete
**When**: 2026-11-12 13:33 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-295 at `c6c897d5`

Pull request A only ("a fresh clone works with no project"), with the plan review's findings 1 to 6 applied. AGENTS.md is untouched: its held commit (A step 7) was not made, the owner has not approved the wording; everything below is true and passes without it. The B and C section and the outline were not started.

Commits (one logical change each, tests with their code):

- `323684b7` validate: the `project/` block, the trailing `project remote` print (finding 1), `get_git_branch` and the `get_project_path`/`get_project_remote_url` imports go; no entries and no parse errors prints, in verbose mode, "no project registered (register one with .agent/scripts/register_project.sh <path>)". `test_validate_neither_shape` now asserts exit 0 and that line (finding 2); a verbose registered-project case added. A step 1's cases went into `test_project_registry.sh`'s existing sandbox fixtures, so there is no `test_validate_workspace_no_project.sh` (B and C step 1 and 9 must name `test_project_registry.sh` instead).
- `0d81b1ae` make setup depends on `git-bug.done` only; the `project.done` rule, its header line and `setup_project.sh` (with its `script_reference.md` row) go; `single_project/adapter.sh` comment fixed; help text as planned. Deviation for veto: the "No project is registered" line prints only when the main checkout's `.agent/projects.local` has no entry line, so a machine with registered projects is not told none are registered; the user-tier pointer always prints.
- `1b102653` `registry_repo_slugs <root>` in `_project_registry.sh` (github.com origins of registered non-parent roots; nothing and status 0 on a missing or unparseable registry); both `gh_create_*` scripts call it with `$_WORKSPACE_ROOT`, no git-common-dir resolution, `registry_require_root` unchanged (finding 3); the refusal lists every accepted project slug ("<none registered>" when empty). Tests: two unit cases in `test_project_registry.sh`; in `test_gh_create_pr.sh` and `test_gh_create_issue.sh` a sandbox main checkout's copy run from a registered demo checkout (accepted), from a scratch clone inside it with another slug (refused by the safety check), from an unregistered checkout (refused by the guard), and from the workspace with a broken registry (not broken).
- `5c2fbc68` sync.py: "No project was synced (none registered; register one: .agent/scripts/register_project.sh <path>)", workspace still synced, exit 0. Deviation for veto: when the registry has entries but none was selected (a registry-only machine running `make sync` from the workspace root), it says "No project was synced (none selected; registered: <names>; pass PROJECT=<name>)" instead, so the message is never false. Two `test_adapter.sh` cases through the real shim, adapter and sync.py.
- `39820700`, `96f654b2` dashboard.sh lines 163 and 345 reworded to the `register_project.sh` pointer (finding 5); with a malformed registry the check line is not printed and the status line says the registry is malformed. Test in `test_project_file.sh`, run with `--quick` (without it the dashboard reaches `gh auth status`, which contacts GitHub).
- `9a9aefd3` New finding, not in the plan: `validate_workspace.py` and `single_project/sync.py` are reached by about 30 suites, and `suites_for_files.sh` reads every Python string as a possible path, so their pointer text made `register_project.sh` select 32 to 35 suites and turned the hub guard in `test_script_tests_hook_scope.sh` red (3 failures; main passes it). Both now print from `REGISTER_PROJECT_POINTER` in `lib/workspace.py`, assembled from two literals with a comment saying why; the printed text is unchanged. After it `register_project.sh` selects 9 suites. Mechanism decision for veto; B and C will meet the same guard when the `adapter` refusal names the script.
- `d39ffe20` `test_fresh_clone_no_project.sh` (executable; `git archive HEAD` into a scratch repository, so committed content only, said in its header; scratch HOME, `CI=1`, `.make/setup-dev.done` pre-seeded, origin a local bare repository, `gh` stubbed; no real project named). Assertions: (a) `make validate` exits 0 and prints the "no project registered" line; (b) `make setup </dev/null` exits 0 and prints both pointer lines; (c) `make dashboard` exits 0, names `register_project.sh` and never says "run: make setup"; (d) `make sync` exits 0, syncs the workspace and prints "No project was synced"; none of a-d writes `project/` or `projects/`; (e) `register_project.sh <demo> --set build=none --set test=none --skip-run` (finding 4) registers, then `gh_create_pr.sh` in the demo checkout reaches `gh pr create`. Result: 15 passed, 0 failed (1.2 s). The same suite run against main's tree fails assertions in a, b, c, d and e. `test_script_tests_hook_scope.sh` asked for a ROOT_READERS entry (not a `# covers:` header): `Makefile .agent/scripts .agent/project_types`; it then passes 299/0. Issue 444 has not landed, so no re-run against its runner.
- `c6c897d5` design.md: Table 2 `setup` row loses the `project` stamp (line 397 now); Table 1's `gh_create_pr.sh` row says registered roots are consulted (lines 131-184); a Sessions and roots bullet on the no-project workspace, placed in Now rather than the plan's Target because it describes built behaviour and the status rule keeps built facts in Now; change log row, 902 lines.

Verification: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files <the branch's changed files, the deleted setup_project.sh excluded>` with no SKIP, one run: exit 0, every hook Passed or Skipped, the `.agent/scripts/tests/` suite hook Passed (a full run: the branch touches `_project_registry.sh` and the Makefile). No flake re-run was needed. Suites also run by hand during the work: `test_project_registry.sh` 294/0, `test_adapter.sh` 121/0, `test_project_file.sh` 479/0, `test_gh_create_pr.sh` 107/0, `test_gh_create_issue.sh` 70/0, `test_fresh_clone_no_project.sh` 15/0, `test_script_tests_hook_scope.sh` 299/0.

On the owner's first machine (project/ symlink plus registered projects): `make validate` no longer checks or prints `project/` (a broken symlink there is no longer reported; registered entries are still checked); `make setup` no longer runs the project step (its stale `project.done` stamp is harmless) and prints only the user-tier pointer line; `make help` text changed; the `gh_create_*` accepted set grows by the registered roots' slugs. Sync and dashboard messages change only in branches taken without `project/`.

Out of scope, reported not fixed: none found beyond the hub-guard interaction above.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 13:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-295 at `cecf7709`
**Base**: main
**Depth**: Standard (reason: Makefile and docs/design.md are governance files; 21 files, +1095 -102, most of it tests and the timeline)
**Must-fix**: 2 | **Suggestions**: 4
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Pull request A only ("a fresh clone works with no project"), held against the plan's A section and the second Plan Review's findings 1 to 6. The AGENTS.md rewording is left out on purpose and is not a finding.

### Findings
- [x] (must-fix) `registry_repo_slugs` walks up to an enclosing repository when a registered root is not itself a git checkout, so that repository's slug is accepted. On the first machine both ros2_colcon roots under `projects/` print `rolker/agent_workspace` (run with the main checkout's registry). The header says such an entry "prints nothing". Fix: skip the entry unless `git -C "$path" rev-parse --show-toplevel` equals the root's resolved path. Add a test with a root inside another repository; the `nogit` case passes only because its sandbox is outside any repository. Cross-confirmed by Gemini and the Claude adversarial pass. — `.agent/scripts/_project_registry.sh:637-646`
- [x] (must-fix) Inside a workspace worktree, `make validate` and `make sync` now say "no project registered (register one with …)" and "No project was synced (none registered; register one: …)". On the first machine, which has three projects registered, both are false (run in this worktree). `sync.py` and `validate_workspace.py` read the registry from `get_workspace_root()`, which is the worktree, and `.agent/projects.local` is gitignored there. `make setup` (`$(WS_ROOT)`) and `dashboard.sh` (`MAIN_ROOT`) read the main checkout, so the three targets disagree inside one worktree. Pick one: read the main checkout's registry for these messages (git common dir, as the Makefile does), or name the file read ("none registered in <path>"). — `.agent/project_types/single_project/sync.py:188-199`, `.agent/scripts/validate_workspace.py:152-153`
- [x] (suggestion) Two pointers still send a user to `make setup`, which no longer configures a project after this change: `adapter repos` prints "project/ is not configured (run: make setup)", and `worktree_create.sh --type project` with nothing registered prints "Run: make setup (or register …)". The plan review left both for B, but A is what makes them wrong. The fix is two strings plus the `test_adapter.sh:499` assertion. — `.agent/project_types/single_project/adapter.sh:230`, `.agent/scripts/worktree_create.sh:491-492`
- [x] (suggestion) The `make help` line for sync says "Fetch/pull workspace + registered projects repos". `make sync` actually syncs the workspace and at most one project: the one selected, or the legacy `project/`. Say "workspace + the selected project (PROJECT=<name>)". — `Makefile:76`
- [x] (suggestion) The merge resolution keeps the rows in the right order: main's two #437 rows, then this branch's. But this branch's row still gives the document as 902 lines. After the merge it is 909, and the rule is "the line count of the document after the change". — `docs/design.md:855`
- [x] (suggestion) No test covers the first machine's shape, a legacy `project/` checkout plus registered roots with the same slug, which the `awk` dedup handles. The plan's validate case for a registry line missing its path was not carried over when the cases moved into `test_project_registry.sh`. — `.agent/scripts/tests/test_gh_create_pr.sh`, `.agent/scripts/tests/test_project_registry.sh`

### Decisions for veto (implement pass)
1. `REGISTER_PROJECT_POINTER` split in two: accept for this pull request. The selector deliberately over-approximates: any path token counts as a read. A message string is a false positive, so hiding it loses no test relevance. The comment says why, and the printed text is unchanged. Teaching the selector an exception means touching a full-run trigger and the hook-scope test, which issue 444 also edits, so that is bigger. B's `adapter` refusal will meet the same guard, so B should carry a selector annotation (or a follow-up issue should) rather than repeat the split.
2. Setup prints the "No project is registered" line only when the registry is empty: accept. It avoids a false line on the first machine.
3. Sync says "none selected; registered: …": accept. It is true from the main checkout. From a worktree, see must-fix 2.
4. A malformed registry gets its own dashboard status line: accept. `check_fail` already counts it.
5. The design sentence in Now: accept. It describes built behaviour.

### Legacy machine
On the first machine the accepted repository set of `gh_create_*` does not grow. Run with its registry, it is the workspace slug plus the `project/` slug, because the registered single_project root is the same repository. With the walk-up fixed, the ros2_colcon roots add nothing. In general, a cwd must first pass `registry_require_root`, and the slug is the cwd's own `origin`. A pull request or issue can therefore only go to a registered repository from a clone of that repository: the same class as the old `project/` rule. `make validate` no longer checks `project/`, but its target is a registered root there and is still checked by its adapter.

### Outside reviewers
- Gemini: ran (2 KB, about one minute). Its must-fix (resolve the git common dir as the plan said) is a false positive: Plan Review finding 3 dropped that resolution, because the user-tier guard refuses a worktree copy first. Its walk-up note is must-fix 1. Its test-file note is the accepted plan-review finding 2.
- Codex: ran (1 KB, short, read-only). It raised the same common-dir point as Gemini, the same false positive.
- Claude adversarial: ran. It confirmed must-fix 1 and 2 and suggestions 1 and 4, and ran the touched suites with 0 failed.

## Implementation
**Status**: complete
**When**: 2026-11-12 14:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-295 at `426dbed6`
**Addressed**: Local Review (Pre-Push) at `cecf7709` (2026-11-12 13:48 -05:00)
**Commits**: `0548b660`, `3b1af1ff`, `a1fd5027`, `731a84fc`, `d3497d47`, `1bc469b7`, `426dbed6`

### Actions
- [x] (must-fix) `registry_repo_slugs` skips an entry unless `rev-parse --show-toplevel` (resolved) equals the root's resolved path, so a plain directory inside another repository no longer borrows its origin; header updated. New test `test_registry_repo_slugs_no_walk_up`: the sandbox workspace is itself a repository with a GitHub origin, a registered plain directory and a registered path deeper inside it print nothing. It fails on the old code (2 failures) and passes on the new. — `.agent/scripts/_project_registry.sh`
- [x] (must-fix) Host direction applied: every "is a project registered?" message reads the main checkout's registry, found through git's common dir as the Makefile's WS_ROOT is. `get_main_checkout_root()` in `lib/workspace.py` serves `validate_workspace.py` (the verbose "no project registered" line) and `sync.py` (the "none registered" / "registered: <names>" line); `registry_main_checkout` in `_project_registry.sh` serves `dashboard.sh`'s two lines (a new `NONE_REGISTERED`; its status line gains a third case, "(legacy project/ not configured)", for a registry that MAIN_ROOT and the common dir disagree on); `make setup` already read `$(WS_ROOT)`. Both helpers fall back to the checkout itself when git gives no answer or the checkout is not the top level of its own repository (same rule as must-fix 1, so a sandbox copy inside another repository never reads that repository's registry). Which registry the validate checks and the adapter's resolution read is unchanged. Test: `test_fresh_clone_no_project.sh` case (f), a worktree of the sandbox copy outside `worktrees/workspace/` with the demo project registered in the main checkout: validate, sync, setup and dashboard none say no project is registered (20 passed, 0 failed). By hand in this worktree: validate no longer prints the line, sync prints "none selected; registered: <three names>". A red run of (f) against the old code was not made: the temporary-commit-and-reset step was denied by the permission system and was not retried another way. — `.agent/scripts/lib/workspace.py`, `.agent/scripts/validate_workspace.py`, `.agent/project_types/single_project/sync.py`, `.agent/scripts/dashboard.sh`
- [x] (suggestion) `adapter repos` now says "no project selected and project/ is not configured (register one: …register_project.sh <path>; select one: --project <name>)"; `worktree_create.sh --type project` says "project/ is not configured and no project is registered in <root>/.agent/projects.local" and "Register one: …register_project.sh <path>" (it names the file it read, since its registry is the script copy's checkout). `test_adapter.sh` assertion updated (and asserts no "make setup"); new case in `test_worktree_create.sh`. Selector check: with the path written whole in both files, `suites_for_files.sh register_project.sh` selected 36 suites (33 with only `adapter.sh` split); the branch's approach was used (path split in two literals, with a comment saying why), after which it selects 11 and `test_script_tests_hook_scope.sh` passes 301/0. The selector was not changed. — `.agent/project_types/single_project/adapter.sh`, `.agent/scripts/worktree_create.sh`, `.agent/scripts/tests/test_adapter.sh`
- [x] (suggestion) `make help` sync line: "Fetch/pull workspace + the selected project (PROJECT=<name>)". — `Makefile:76`
- [x] (suggestion) Change-log row's line count is 909, the document's count after the merge (unchanged by this pass). — `docs/design.md:855`
- [x] (suggestion) `test_gh_create_pr.sh`: a legacy `project/` checkout plus two registered roots cloned from one repository (ssh and https origins) list that slug once in the refusal, and `project/` and both roots are accepted. `test_project_registry.sh` `test_validate_entry_path_missing_no_legacy`: with no `project/`, a line without a path (default absent) and a line naming a missing path are both reported as "hosting dir does not exist", exit 1, no "no project registered", nothing created. — `.agent/scripts/tests/test_gh_create_pr.sh`, `.agent/scripts/tests/test_project_registry.sh`

### Verification
Intermediate commits used `SKIP=validate-script-tests`. Final run, no SKIP: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only --diff-filter=d main...HEAD)` at `426dbed6`: exit 0, every hook Passed or Skipped, the `.agent/scripts/tests/` suite hook Passed (it ran past 600 s and finished in the background; its exit was waited for). No flake re-run needed. By hand: `test_project_registry.sh` 302/0, `test_gh_create_pr.sh` 111/0, `test_adapter.sh` 122/0, `test_worktree_create.sh` 59/0, `test_fresh_clone_no_project.sh` 20/0, `test_script_tests_hook_scope.sh` 301/0.

### Reported, not fixed
- From a workspace worktree, sync's message "none selected; registered: <names>; pass PROJECT=<name>" (this pull request's text) is now true about what is registered, but its advice does not work there: `adapter --project <name>` resolves names from the worktree's own registry, which is empty, and refuses ("project '<name>' is not registered in <worktree>/.agent/projects.local"). The adapter's resolution was left as the host directed; from the main checkout the advice works.
- From a worktree, `make validate` still checks the worktree's registry entries (none), so registered projects are not checked there; unchanged by direction.

## Implementation
**Status**: complete
**When**: 2026-11-12 14:39 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Branch**: feature/issue-295 at `f70d534f`

Consequence of merging main at 4b1e7cb3 (main's new `ros-manifest.done` setup step):
- test_fresh_clone_no_project.sh seeds `.make/ros-manifest.done` beside `setup-dev.done` (the scratch copy has no .venv, so the resolver install would fail and must never pip-install); comment says why. 20 passed, 0 failed.
- Makefile `help` line for `make setup` now names the resolver install.
- docs/design.md change-log row for #295: line count 909 -> 910 (`wc -l`).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 14:45 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-295 at `17b686b2`
**Base**: main
**Depth**: Standard (reason: Makefile and docs/design.md are governance files; 23 files, +1408 -104, whole-diff classification at round 2)
**Must-fix**: 2 | **Suggestions**: 2
**Round**: 2 | **Ship**: recommended — round 2: 2 mechanical must-fix (prev 2), not rising; fix and ship rather than another full round

Pull request A only ("a fresh clone works with no project"). Re-review of the six round 1 findings (fix commits 0548b660, 3b1af1ff, a1fd5027, 731a84fc, d3497d47, 1bc469b7, 426dbed6), the merge of main at 4b1e7cb3 and f70d534f. All six round 1 findings are closed as written. The merge resolution is right: `setup: $(STAMP)/git-bug.done $(STAMP)/ros-manifest.done`, the `project.done` rule and header line gone, main's `ros-manifest.done` rule and help line kept; the fresh-clone test seeds `.make/ros-manifest.done`. The two new must-fix are mechanical: one false message left in the case round 1's must-fix 2 was about, and design rows this branch or its merge left untrue.

### Findings
- [x] (must-fix) From a workspace worktree, `make sync` says "No project was synced (none registered; register one: …)" when the main checkout's registry exists but every line fails to parse: `sync.py` drops `_errors`. Validate (`not main_entries and not main_errors`), the dashboard (`NONE_REGISTERED` stays 0) and setup (any non-comment line) do not say "none registered" there. From the main checkout the adapter fails closed first, so only a worktree reaches it. Reproduced by the Claude adversarial pass (bad line in a copy's registry, `sync_project.py --dry-run` in its worktree); also raised by Gemini. Fix: when `_errors` is non-empty, say the registry has malformed lines (run `make validate` in the main checkout); add the case to `test_fresh_clone_no_project.sh` (f) or `test_adapter.sh`. — `.agent/project_types/single_project/sync.py:192-203`
- [x] (must-fix) Design rows untrue at HEAD (ADR-0017). (a) Table 2 `setup` row, rewritten by this branch: "The `git-bug` stamp (`Makefile` line 98; the header lists `setup-dev` and `git-bug` …)"; after the merge `setup:` is line 100, depends on `git-bug.done` and `ros-manifest.done`, and the header lists `ros-manifest.done` too. (b) Decision-register ADR-0007 row: "here the stamps are setup-dev, then project and git-bug"; this branch removed the `project` stamp (and main added `ros-manifest`). (c) Table 1 `worktree_create.sh` row cites 505-510, 594-607, 629-641, 1103-1109; this branch added 6 lines near 491, so each is now +6 (checked by diffing main's ranges against HEAD's shifted ones). Fix the three rows; the change-log row says what changed (the line count stays 910 if no line is added). — `docs/design.md:398`, `docs/design.md:744`, `docs/design.md:378`
- [x] (suggestion) The two main-checkout helpers say they find the main checkout "the way the Makefile's WS_ROOT is found", but differ from it and from git in two edge cases: a common dir not ending in `/.git` (`git clone --separate-git-dir`, a submodule) returns the git dir itself, so `validate --verbose` in such a main checkout printed "no project registered" with an entry present (reproduced by the Claude adversarial pass; the Makefile's WS_ROOT has the same behaviour on main); and `WS_ROOT` has no "top level is the root" guard, so for a plain copy inside another repository `make setup` reads that repository's registry while the other three read the copy's. Either compare `--git-dir` with `--git-common-dir` (equal means main checkout: return the root) and take a worktree's main checkout from the first line of `git worktree list --porcelain`, or reword the two comments so they do not claim to match WS_ROOT. — `.agent/scripts/lib/workspace.py:45-77`, `.agent/scripts/_project_registry.sh:625-645`
- [x] (suggestion) No test calls `get_main_checkout_root` or `registry_main_checkout`, and case (f) covers only a standard worktree whose main checkout has a registry; removing either helper's "top level is the root" guard leaves every suite green (the dashboard no-project sandbox is outside any repository). Add a unit case per helper: a plain directory nested in a repository that has a registry, and a non-git directory. (`registry_repo_slugs`' own guard is covered: `test_registry_repo_slugs_no_walk_up` fails without it.) — `.agent/scripts/tests/test_project_registry.sh`, `.agent/scripts/tests/test_fresh_clone_no_project.sh`

### Round 1 findings
- Must-fix 1 (walk-up in `registry_repo_slugs`): closed; the guard resolves both sides with `pwd -P`, returns 0 under `set -euo pipefail`; `test_registry_repo_slugs_no_walk_up` covers it.
- Must-fix 2 (worktree "no project registered"): closed for every well-formed registry; validate, sync, setup and dashboard agree in case (f). Residual malformed-registry case is the first must-fix above. The red run of (f) against the pre-fix code was not made: the scratch-clone command was denied by the permission system and not retried another way.
- Suggestions 1-4 (pointers, sync help line, change-log count, legacy-plus-registered test and missing-path test): closed.

### Items the fix pass reported and did not fix (host's question)
1. From a worktree, `make sync`'s "pass PROJECT=<name>" fails (the adapter resolves names from the worktree's empty registry): can wait for pull request B, which rewrites the adapter's resolution and its refusal text (B step 4) and would otherwise repeat the problem ("Registered: <names>" read from the worktree). B's plan must add which registry the adapter reads from a worktree; it does not say so today. Not a regression: before this branch the same worktree run said "project/ not configured. Run: make setup", which was worse.
2. From a worktree, `make validate` checks only the worktree's (empty) registry: can wait for B, same root cause and the same plan addition (one rule for which registry a worktree reads). On main a worktree's validate did not check registered entries either.

### Resolver install on a fresh second machine (main's behaviour, a note)
`ros-manifest.done` runs `pip install -e tools/ros-manifest` into the venv. It needs the network: pip's isolated build environment fetches `setuptools>=68` (the venv has none), and `PyYAML>=6.0` is already present through pre-commit. But `setup-dev.done`, which it depends on, already pip-installs `requirements.txt` from PyPI, so `make setup` was never offline-capable and this adds no new requirement. On failure the recipe's `&& touch $@` is skipped, make stops with an error at that rule, "Setup complete" and the pointer lines are not printed, and a re-run retries. Found by reading the Makefile and `pyproject.toml` and `pip show` on the existing venv; an offline install in a scratch venv was denied by the permission system and not run. This branch does not make it worse.

### Outside reviewers
- Gemini: ran (2.6 KB). Must-fix "resolve the main checkout in `gh_create_*`" is the round 1 false positive again (Plan Review finding 3 dropped it; the user-tier guard refuses a worktree copy first; plan.md step 3 still describes the dropped resolution, which keeps misleading outside readers). Its sync.py malformed-registry note is the first must-fix. Its dashboard note (malformed main registry not reported from a worktree outside `worktrees/workspace/`) falls to the neutral status line, not a false one: not carried. Its test-placement note was accepted in round 1.
- Codex: ran (1.1 KB, short, read-only, no tests). Same `gh_create_*` false positive only.
- Claude adversarial: ran. Raised both must-fix and both suggestions, with reproductions.

### Verification
Static: shellcheck (warning) clean on the changed shell files; flake8 shows only E402 at the existing `sys.path` import pattern in `sync.py` and `validate_workspace.py` (pre-commit passed). Suites run one at a time at `17b686b2`: `test_fresh_clone_no_project.sh` 20/0, `test_project_registry.sh` 302/0, `test_worktree_create.sh` 59/0, `test_gh_create_pr.sh` 0 failed, `test_gh_create_issue.sh` 70/0, `test_adapter.sh` 122/0, `test_script_tests_hook_scope.sh` 301/0. `test_project_file.sh` not run (load on the machine; the fix round did not touch the dashboard test).

## Implementation
**Status**: complete
**When**: 2026-11-12 15:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-295 at `752be3e1`
**Addressed**: Local Review (Pre-Push) at `17b686b2` (2026-11-12 14:45 -05:00)
**Commits**: `425f1c02`, `e0481904`, `ba7d2bcf`, `7537b7ee`, `752be3e1`

### Actions
- [x] (must-fix) `sync.py` keeps the registry's parse errors: with malformed lines it says "The project registry in <main checkout> has N malformed line(s); run make validate in that checkout to see them", and with no well-formed line "No project was synced (no well-formed registry line)", never "none registered"; a registry with names and malformed lines prints both lines. Test: `test_fresh_clone_no_project.sh` case (f) continued, a main registry whose only line is malformed, `make sync` in the worktree. It failed against the committed old code (20/1) and passes after (21/0). — `.agent/project_types/single_project/sync.py`, `.agent/scripts/tests/test_fresh_clone_no_project.sh`
- [x] (must-fix) `docs/design.md`: Table 2 `setup` row names the `git-bug` and `ros-manifest` stamps, `Makefile` line 100, the header listing `setup-dev`, `ros-manifest` and `git-bug`; ADR-0007 register row "setup-dev, then git-bug and ros-manifest (no project stamp since #295)"; Table 1 `worktree_create.sh` 505-510, 594-607, 629-641, 1103-1109 to 511-516, 600-613, 635-647, 1109-1115 (each checked equal to main's range); Table 2 `install` row `Makefile` line 164 to 173 (this branch's setup recipe adds 3 lines before it; main has it at 170). Every other numeric citation of the files this branch edits was re-read: `gh_create_pr.sh` 131-184 is right; `worktree_create.sh` 301-313 and 351-357 sit before this branch's change. The change-log row says what changed; 910 lines, unchanged. — `docs/design.md:378`, `docs/design.md:398`, `docs/design.md:403`, `docs/design.md:744`, `docs/design.md:856`
- [x] (suggestion) Both helpers rewritten to the reviewer's first option: not the top level of its own repository gives the root; `--git-dir` equal to `--git-common-dir` (a main checkout, also a `--separate-git-dir` one) gives the root; a linked worktree gives the first `git worktree list --porcelain` entry, when that is a directory that is its own top level and shares the common dir, else the root. Comments say what they do and no longer claim to match WS_ROOT; the Makefile's WS_ROOT is unchanged. The Python one is split into `_git_out`, `_git_common_dir` and `_is_own_toplevel` (pylint too-many-return-statements). — `.agent/scripts/lib/workspace.py`, `.agent/scripts/_project_registry.sh`
- [x] (suggestion) `test_main_checkout_helpers` in `test_project_registry.sh` runs both helpers (the shell one given the directory, the Python one from a copy of `lib/workspace.py` under it) on a plain directory nested in a repository with a registry, a non-git directory, a main checkout, a linked worktree and a `git clone --separate-git-dir` main checkout: 5 cases, each asserting both answers. — `.agent/scripts/tests/test_project_registry.sh`

### Verification
Intermediate commits used `SKIP=validate-script-tests`. Final run, no SKIP: `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only --diff-filter=d main...HEAD)` at `752be3e1`: exit 0, every hook Passed or Skipped, the `.agent/scripts/tests/` suite hook Passed (every suite: a shared helper changed). It passed 600 s, moved to the background and its exit was waited for. No flake re-run. By hand: `test_fresh_clone_no_project.sh` 21/0, `test_project_registry.sh` 307/0, `test_script_tests_hook_scope.sh` 301/0.

### Denied, not run
- A scratch experiment of how `git worktree list` names the main checkout for a linked worktree of a `--separate-git-dir` checkout was denied by the permission system and not retried another way; that combination is not tested, and the helpers fall back to the worktree itself if git names a path that is not a checkout sharing the common dir.
- A red run of `test_main_checkout_helpers` against the committed old helpers (copies from `git show HEAD:` into the scratchpad) was denied and not retried another way.

### Reported, not fixed
- `docs/design.md:384`, Table 1 `_project_registry.sh` row, cites 485-500 for `registry_derive_type_from_dir`; the function is at 575-600 (header comment from 575, body 585-600) on main and on this branch. This branch's changes there come after line 624, so they did not shift it.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 15:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a35cdf54273683d8b, resume 1 of 3)

**Branch**: feature/issue-295 at `94395d86`
**Base**: main
**Depth**: Standard (reason: round 3 convergence check per handoff; whole-diff tier Standard: Makefile and docs/design.md are governance files)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 3 | **Ship**: recommended — no must-fix findings

Pull request A only ("a fresh clone works with no project"). Narrow convergence check of the round 2 findings against the fix diff `c05c8fd9..94395d86` (425f1c02, e0481904, ba7d2bcf, 7537b7ee, 752be3e1). All four round 2 findings are closed: sync.py reports a malformed main registry instead of "none registered" (new case in (f)); the setup, install, worktree_create.sh and ADR-0007 design rows are true at HEAD (Makefile 100 and 173 checked; the four worktree_create.sh ranges are main's +6); both helpers decide by `--git-dir` against `--git-common-dir`, then the first `git worktree list --porcelain` entry; `test_main_checkout_helpers` runs both on five checkouts, and fails if the old "common dir minus /.git" rule returns (separate-git-dir case). The Claude adversarial pass ran both helpers under `set -euo pipefail` on 14 layouts (spaces, non-ASCII, symlinked parents, bare-backed and separate-git-dir worktrees, inside a pre-commit hook with `GIT_DIR` set): exit 0 and the same answer every time. No cross-model reviewers (round 3, per handoff).

### Findings
- [ ] (suggestion) Comments still say the registry is "found through git's common dir as make setup … find it", which is no longer how the helpers work, and `make setup` keeps the old rule (`WS_ROOT` = common dir minus `/.git`), so in a `--separate-git-dir` main checkout setup prints "No project is registered" while validate, sync and the dashboard do not. Reword the four comments to name `get_main_checkout_root` / `registry_main_checkout`; aligning `WS_ROOT` is B's (it also decides `STAMP` and `VENV_DIR`). — `.agent/project_types/single_project/sync.py:188`, `.agent/scripts/validate_workspace.py:154`, `.agent/scripts/dashboard.sh:156`, `.agent/scripts/tests/test_fresh_clone_no_project.sh:187`, `Makefile:41`
- [ ] (suggestion) The fix pass's untested combination behaves as it guessed and gives a false message: in a linked worktree of a `--separate-git-dir` main checkout, git 2.43 lists the git dir (`…/sep.git`) as the first worktree, which is not a checkout, so both helpers return the worktree itself and sync and validate say "none registered" with a registry present in the main checkout. Git does not record that checkout, so it cannot be found from git alone; add the case to `test_main_checkout_helpers` so the fallback is a recorded decision, and consider "no registry found here" over "none registered" when the helper fell back from a linked worktree. Rare layout; not needed for this pull request. — `.agent/scripts/tests/test_project_registry.sh:~414`, `.agent/scripts/_project_registry.sh:658-666`, `.agent/scripts/lib/workspace.py:74-80`

### Notes (not findings)
- `docs/design.md:384` (`_project_registry.sh` row cites 485-500 for `registry_derive_type_from_dir`, which is at 585 here and on main): not caused by this branch; a note for pull request B, which rewrites that table.
- Several `worktree_create.sh` ranges in Table 1 did not land on the described code on main either; the +6 shift carried them over faithfully. Also for B.
- The adversarial pass reports one of its own setup commands was denied and that it then split it into script files; that is a workaround of a denial, surfaced here for the owner. Its sandbox is left at the session scratchpad `r3/` (and a `t1-link` symlink beside it); not removed by this review.

### Verification
`test_fresh_clone_no_project.sh` 21/0 (includes the new malformed-registry case), `test_project_registry.sh` 307/0 (includes `test_main_checkout_helpers`, 5 cases), run one at a time at `94395d86`. Design citations checked by `sed -n` on the Makefile and grep on `_project_registry.sh` here and on main.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 15:15 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 approved with no must-fix; all ten findings of rounds 1 and 2 are closed)
**After**: publish
**Decision**: publish

The host read the round 3 Local Review (Pre-Push) entry at d355e2ef: verdict approved, Ship recommended, two open suggestions (four comments that still name the old lookup rule; a linked worktree of a separate-git-dir main checkout, where the helpers fall back and the message says "none registered"). Both concern a layout the reviewer calls rare and neither is needed for this pull request; they stay open boxes so triage raises them, and whether they are fixed here or carried into pull request B's plan is put to the owner with the merge decision. The AGENTS.md rewording is not in this pull request: the owner did not approve the proposed wording and decided on 2026-11-12 that a project is any registered folder, so it is redrafted from that.

## Integrated Review
**Status**: complete
**When**: 2026-11-12 15:16 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #454 at `11a4012`
**Sources**: 2 (Local Review (Pre-Push) round 3 @ `94395d8` (covers `11a4012` via bookkeeping), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

Pull request A ("a fresh clone works with no project"). No GitHub reviews, inline comments or conversation comments on the pull request at `11a4012`. Rounds 1 and 2 left no open boxes (all ten findings ticked); round 3 approved with two open suggestions, both checked against the code at HEAD and still true (`validate_workspace.py:153-155` comment and `Makefile:41` `WS_ROOT` rule; `_project_registry.sh:656-666` fallback to the root). Per the publish Checkpoint they stay open: fixing them on this pull request or carrying them into pull request B's plan is the owner's call at the merge decision. CI at entry time: Validate Documentation and ros-manifest tests passed; Lint (pre-commit) and Validate Adapter Contract still running.

### Findings
- [x] (suggestion, Local Review (Pre-Push) R3 @ `94395d8`) Comments still say the registry is "found through git's common dir as make setup … find it", which is no longer how the helpers work, and `make setup` keeps the old rule (`WS_ROOT` = common dir minus `/.git`), so in a `--separate-git-dir` main checkout setup prints "No project is registered" while validate, sync and the dashboard do not. Reword the four comments to name `get_main_checkout_root` / `registry_main_checkout`; aligning `WS_ROOT` is B's (it also decides `STAMP` and `VENV_DIR`). — `.agent/project_types/single_project/sync.py:188`, `.agent/scripts/validate_workspace.py:154`, `.agent/scripts/dashboard.sh:156`, `.agent/scripts/tests/test_fresh_clone_no_project.sh:187`, `Makefile:41` (deferred: owner 2026-11-12: merge now, carried into the next pull request's plan (the legacy fallbacks go))
- [x] (suggestion, Local Review (Pre-Push) R3 @ `94395d8`) The fix pass's untested combination behaves as it guessed and gives a false message: in a linked worktree of a `--separate-git-dir` main checkout, git 2.43 lists the git dir (`…/sep.git`) as the first worktree, which is not a checkout, so both helpers return the worktree itself and sync and validate say "none registered" with a registry present in the main checkout. Git does not record that checkout, so it cannot be found from git alone; add the case to `test_main_checkout_helpers` so the fallback is a recorded decision, and consider "no registry found here" over "none registered" when the helper fell back from a linked worktree. Rare layout; not needed for this pull request. — `.agent/scripts/tests/test_project_registry.sh:~414`, `.agent/scripts/_project_registry.sh:658-666`, `.agent/scripts/lib/workspace.py:74-80` (deferred: owner 2026-11-12: merge now, carried into the next pull request's plan (the legacy fallbacks go))

### False positives

### Reviewer outcomes
- Copilot: not requested (automatic review switched off 2026-11-12); checked once, no review or comment on the pull request.
- Gemini: ran in rounds 1 and 2 (pre-push); its findings were triaged there and are closed; not run in round 3 (per handoff).
- Codex: ran in rounds 1 and 2 (pre-push, short, read-only); only the common-dir false positive both times; not run in round 3.
- Human: none requested.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 15:24 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: findings
**Decision**: merge

"q16 yes."

Q16 as put to him: what to do with pull request 454 once CI is green; the option he chose: merge it, with the two open suggestions carried into the next pull request's plan. F1: four code comments describe the old way of finding the main checkout (and `make setup`'s WS_ROOT keeps the old rule). F2: in a linked worktree of a clone made with a separate git directory, a message says "none registered" when a registry exists. Said to him: both concern one rare layout that cannot occur on his machines as they are set up, and the next pull request (the legacy fallbacks go) touches the same code. The merge waits for the lint job to pass.
