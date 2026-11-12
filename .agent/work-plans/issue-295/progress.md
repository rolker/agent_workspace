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
