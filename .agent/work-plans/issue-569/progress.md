---
issue: 569
---

# Issue #569 — repos-manifest: remove the prototype's reader

## Issue Review
**Status**: complete
**When**: 2026-11-24 08:58 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #569

### Scope Assessment

**Well-scoped?** Yes, with a Watch. It is one removal across the tool, its docs and a few outside references; step 1 can land alone. Step 2 is the large part (code path, `--layout manifest-dir`, parent-manifest cache, `prototype.md`, tests and fixtures) and may be better as its own PR after step 1, but it is still one coherent change.
**Right repo?** Yes. The tool (`tools/repos-manifest`), the `ros2_colcon` adapter and the outside docs are all in the workspace repo.
**Serves**: Light touch on projects and Quality of the work (less to keep working; no document describing something that is gone) — `docs/design.md#registry-and-adapters`, and the part's own `tools/repos-manifest/docs/design.md#where-the-manifest-comes-from`.
**Design picture?** No change to how the parts fit. The tool's design and spec mention the prototype and get brought up to date (step 3); the issue says the format and spec do not change. The owner's decision (no old-format manifest exists) is recorded in the issue.
**Dependencies**: Step 2 depends on the adapter's older route being cut. Checked at this commit: `.agent/project_types/ros2_colcon/adapter.sh` still calls `resolve --layout manifest-dir` (line 1639) and tests for the flag (line 1644), so the reader still has a caller today. The workspace-side roadmap lines "The adapter's own manifest fetch and generated directories are removed" and "The bootstrap route is removed" are both not yet true (`docs/manifest/roadmap.md`). Issue #498 (open) is touched by step 4.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | Removes a reader with no user; the owner confirmed nothing on the old format exists on either machine. |
| Keep one current design | OK | Documents are updated in the same change (step 3). |
| Fail loudly / no silent failure (Quality Standard) | OK | The issue requires a named-reason error for an old-format manifest instead of a fall-through. |
| Keep one current design (adapter ordering) | Action needed | The plan must state whether the adapter's older route is cut in this issue or whether step 2 waits for it. As written, removing the reader first breaks `adapter.sh`, which still passes `--layout manifest-dir`. |
| Consequences checked | Watch | `.github/workflows/validate.yml:67` names the job "(#267 prototype)" and `tools/repos-manifest/tests/test_documents.py` mentions the prototype; neither is in the issue's step 3 list. `adapter.sh:751` cites `prototype.md` in a comment. `docs/roadmap.md:273` says "The resolver prototype landed on PR #268", which is history and may stay. `host_standing_rules.md` matches only on the unrelated word "prototypes", so it may need no change. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0017 (design document is the current picture) | Yes | Tool design and spec are updated in step 3. |
| ADR-0022 (a part owns its inside) | Yes | The tool has its own design; its roadmap and design are the part's, the root's design changes only where the boundary does (it does not). |
| ADR-0013 (progress entry vocabulary) | Yes | The review is recorded as an Issue Review entry. |

### Consequences

- Tests that read `tools/repos-manifest/tests/fixtures/p11/manifest.yaml` (the only old-format manifest) and the adapter's tests that exercise `--layout manifest-dir` go with the reader or must be re-pointed.
- The CI job name in `.github/workflows/validate.yml` and the pre-commit/doc checks in `test_documents.py` that refer to `prototype.md` need updating when the file goes (changing CI config is an Ask-First item for the owner; the job name is a label only).

### Recommendations

- State in the plan whether the adapter's older route is cut here, or land step 1 now and hold step 2 until the route is cut; cutting the route in the same PR is cleaner than leaving the reader with a caller.
- Add `.github/workflows/validate.yml` (job name), `tools/repos-manifest/tests/test_documents.py` and the `adapter.sh:751` comment to the step 3 list, and re-grep for `prototype` and `manifest-dir` before closing.
- Make the acceptance test for the error concrete: a manifest with no `repositories:` or `base:` key exits non-zero with a message naming the unread format, covered by a test.

### Actions
- [ ] The plan must state whether the adapter's older route is cut in this issue or whether step 2 waits for it. As written, removing the reader first breaks `adapter.sh`, which still passes `--layout manifest-dir`.
- [ ] State in the plan whether the adapter's older route is cut here, or land step 1 now and hold step 2 until the route is cut; cutting the route in the same PR is cleaner than leaving the reader with a caller.
- [ ] Add `.github/workflows/validate.yml` (job name), `tools/repos-manifest/tests/test_documents.py` and the `adapter.sh:751` comment to the step 3 list, and re-grep for `prototype` and `manifest-dir` before closing.
- [ ] Make the acceptance test for the error concrete: a manifest with no `repositories:` or `base:` key exits non-zero with a message naming the unread format, covered by a test.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 08:57 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review's open actions are all for the plan and none changes what the work is for; /orchestrator lets the host answer proceed)
**After**: issue-actions
**Decision**: proceed

The host read the Issue Review at f1f85471. Its four actions are directions to the plan, passed on in the plan-task handoff. Host decisions, listed for the owner's veto:

- The adapter's older route (its own manifest fetch, `resolve --layout manifest-dir`, the generated directories) is cut in this issue, not waited for. The workspace-side roadmap already has lines for removing it, and the owner said on 2026-11-24 that no machine has anything on the old format.
- The issue is delivered in parts: the roadmap line first, on its own pull request ("Part of #569"); the cut of the adapter's older route and the removal of the reader after it.
- The CI job name in `.github/workflows/validate.yml` is a change to CI configuration, which is the owner's to approve (AGENTS.md, Ask First). The plan lists it as waiting for his yes and does not make it without one.

## Plan Authored
**Status**: complete
**When**: 2026-11-24 08:58 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-569/plan.md` at `351700c2`

Three parts, each its own PR: (1) the tool roadmap line, no check possible (no absence check in the vocabulary); (2) cut the adapter's manifest route (about 650 adapter lines, test_ros2_colcon.sh lines 2334-4024), the only caller of manifest-dir; the bootstrap route is separate code and left out; (3) remove the reader, add the error test, delete prototype.md, closes #569. CI job name and the #498 trim wait for the owner.

## Plan Review
**Status**: complete
**When**: 2026-11-24 09:00 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #569 — repos-manifest: remove the prototype's reader, and drop the roadmap line about moving from its format
**Plan**: `.agent/work-plans/issue-569/plan.md` at `351700c2`
**Branch**: `feature/issue-569`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three parts, each its own PR, ordered so the reader loses its only caller (part 2) before it goes (part 3). Leaving the bootstrap route out is right: it calls no resolver code (`_rc_bootstrap_manifest`, adapter.sh 581-700, is curl and a clone). |
| Issue alignment | Needs work | All four steps and the Issue Review's actions are covered, but part 3 as listed leaves most of the old reader in place (finding 3), which would not meet "no reader for the old format". Serves: "Workspace goals: projects and quality of the work (less to keep working, no document describing what is gone); `docs/design.md#registry-and-adapters` and `tools/repos-manifest/docs/design.md#where-the-manifest-comes-from`". Both anchors exist; "projects" should name the goal "Light touch on projects". |
| File targeting | Concern | Part 2's delete/keep list for adapter.sh is wrong in both directions (findings 1, 2); part 3 names 3 of the 9 affected test files and 2 of the 6 prototype modules (findings 3, 4). |
| Consequences | Needs work | The root `docs/design.md` (Registry and adapters bullet, lines 484-495) and `.agent/projects.local.example` (lines 44-52, 78-94) describe the manifest route and how to register from `source=`; neither is in the plan (finding 5). |
| Principle alignment | Needs work | Fail loudly: the `source`-without-tool-root refusal is planned for five verbs only (finding 6). Keep one current design: the plan says the root design does not change, which is not so (finding 5). |
| ADR compliance | Needs work | ADR-0017 and ADR-0022 triggered. ADR-0022 keeps in the root design what crosses the boundary, and the manifest route's settings keys and resolver call are exactly that text, so part 2 must edit the root design. ADR-0013: fine. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[File targeting] High** — Part 2 lists `_rc_source_setup` among the manifest-route functions to delete. It is not a manifest-route function: it sources a ROS setup file (adapter.sh 1986-1998) and is called by `_rc_tool_build` (2116) and by `adapter_build`/`adapter_test` on every route (2189, 2208, 2268, 2273). Deleting it breaks build and test on the tool and bootstrap routes. Resolution: keep it (and move it out of the deleted range).
2. **[File targeting] High** — The keep-list omits `_rc_resolver_bin` (adapter.sh 1390), which the tool route (835, 850, 1016, 1154, 2109) and the bootstrap route's error message (605) call; "delete roughly lines 1335 to 1990" removes it. Conversely, three helpers the plan keeps have no caller outside the deleted range and become dead: `_rc_source_is_url`, `_rc_file_stamp`, `_rc_check_single_source` (and `_rc_registry_field_missing`, `_RC_TRANSPORTS`, whose only users go too). Resolution: replace the list with one derived from callers (live after the cut: `_rc_name`, `_rc_layer_lines`, `_rc_resolver_bin`, `_rc_source_setup`), and state it in the plan.
3. **[Issue alignment] High** — The old reader is more than `_load_merged`, `resolve_chain` and `LAYOUT_MANIFEST_DIR`. `schema.py` (its own Manifest/load_manifest_file/ExtendsRef), `merge.py` (`merge_chain`), `selectors.py`, `validate.py` (`build_validation_table`, `check_dependencies`) and all of `emit.py` (both layouts; the new reader writes through `output.py`) are used only by the old path in `cli.py` (`cmd_resolve`/`cmd_validate` after `has_repositories_key` is false) and by `extends.py`. `base.py` imports nothing from `extends.py`, so "keep what the new base: reader shares" keeps nothing there. Resolution: name these modules for removal in part 3 (keeping `ManifestError`, which `cli.py` imports via `schema`, from `yamlload`), plus `_require_old_flags` and the `--layout` option if no layout remains.
4. **[File targeting] Medium** — Part 3's test list misses `test_extends.py`, `test_extends_safety.py`, `test_acceptance_p11.py` (all import `resolve_chain`), `test_schema.py`, `test_selectors.py`, `test_validate.py` (the old modules), `test_cli.py` (p11 fixture at 8/30/50/101, `resolve_chain` monkeypatch at 86), `test_masking.py:304` (`--cache-dir`). And the p11 fixture is not only old-reader coverage: `test_project11.py` reads `fixtures/p11/expected` (OLD_EXPECTED, lines 15, 22, 57) and `test_base_reading.py:298` uses `p11/manifest.yaml` to test that the new reader refuses the earlier format as a base. Resolution: list each, and re-point those two (keep `p11/expected` or move what test_project11 needs; give test_base_reading a small inline old-format manifest) rather than "delete any fixture only they use".
5. **[Consequences] Medium** — Documented paths that point at the removed route and are not in part 2: the root `docs/design.md` Registry-and-adapters bullet (484-495: "The other two (#436) ... On the manifest route the manifest ... is named by `source`", one-source rule, `register_project.sh ... --set source=`); `.agent/projects.local.example` 44-52 (registering a ros2_colcon instance "from a manifest in the new format ... --set source=") and 78-94; `register_project.sh` header 33-37 ("A --set source=... does not choose the type") and the setup-failure hint at 1135 ("its bootstrap_url or source"); and the bootstrap route's own error at adapter.sh 600-602, which still advises `project_setting.sh set <name> source=...` (tested at test_ros2_colcon.sh ~4016-4022, inside the section part 2 deletes, so the message would stay and go untested). Resolution: add each to part 2, each pointing at the tool route (`repos-manifest init` in the root, then registering that root, which `register_project.sh` already detects by `.repos-manifest`, line 626); drop the plan's "root `docs/design.md` does not change".
6. **[Principle alignment] Medium** — The refusal for `source` set without `.repos-manifest/` is planned for `setup`, `sync`, `build`, `test`, `validate`. `adapter_build` and `adapter_test` have no manifest branch today, and `env`, `repos`, `worktree_repos`, `worktree_env` and `repo_pin` reach the manifest only through `_rc_require_manifest`. With only `_rc_route` changed to return `bootstrap`, those verbs would read `configs/manifest` silently. The manifest-route branches in the shared helpers `_rc_manifest_dir` (177), `_rc_pin_manifest_dir` (206), `_rc_check_manifest` (303) and `_rc_distro` (419) are also not in the plan's list. Resolution: put the refusal in one shared place every verb passes (`_rc_route` or `_rc_require_manifest`, plus `setup`/`sync` before `_rc_bootstrap_manifest`), remove the four helper branches, and test it on at least one verb that is not in the five (e.g. `repos` or `env`).
7. **[Consequences] Low** — `docs/manifest/design.md` also mentions the route at 270 ("on the bootstrap and manifest routes"), 403 (`source_ref` may be a commit today) and 439-446 (the settings keys and how they map to the tool); the plan names only the step-by-step section, the route list, "Which route" and line 72. Resolution: re-grep the file for "manifest route" and `source` in part 2.

### Summary

The split into three parts and their order are right, and the bootstrap route is correctly separate code. But part 2's function list would delete a helper every route needs (`_rc_source_setup`) and the resolver lookup the tool route uses (`_rc_resolver_bin`), and part 3 names only a fraction of the old reader and its tests. Fix the lists from callers and imports before implementation.

### Recommended Actions

- [ ] Part 2: keep `_rc_source_setup` and `_rc_resolver_bin`; drop the now-dead `_rc_source_is_url`, `_rc_file_stamp`, `_rc_check_single_source`, `_rc_registry_field_missing`, `_RC_TRANSPORTS`; state the keep-list as derived from callers.
- [ ] Part 2: remove the manifest branches in `_rc_manifest_dir`, `_rc_pin_manifest_dir`, `_rc_check_manifest`, `_rc_distro`; put the `source`-without-tool-root refusal at one shared point every verb passes, and test it on a verb outside the five.
- [ ] Part 2: update root `docs/design.md` (Registry and adapters), `.agent/projects.local.example`, `register_project.sh` comments and hint, and the bootstrap error at adapter.sh 600-602, each pointing at `repos-manifest init` plus registering the root; keep a test for the bootstrap error's new text.
- [ ] Part 3: name `schema.py`, `merge.py`, `selectors.py`, `validate.py`, `emit.py` for removal along with `extends.py`'s old path; keep `ManifestError` imported from `yamlload`.
- [ ] Part 3: list every affected test file (findings 4), and re-point `test_project11.py` and `test_base_reading.py` instead of deleting the p11 fixture out from under them.
- [ ] Serves: name the goal as "Light touch on projects".

## Checkpoint
**Status**: complete
**When**: 2026-11-24 09:01 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the Plan Review's verdict is needs-work with three high findings, all about the plan's delete lists; none changes what the work is for)
**After**: plan
**Decision**: revise

The host read the Plan Review at 8c8e27df. The three parts and their order stand. The plan is revised to fix all eight findings: the adapter's delete and keep lists (`_rc_source_setup` and `_rc_resolver_bin` are used by every route and stay; helpers left without a caller go), the refusal for a root with `source` set and no `.repos-manifest/` placed where every verb passes through it, the full list of old-reader modules and their tests in the tool, the fixtures that the new reader's tests still use, and the documents that still point at the removed route (the root design's Registry and adapters text, `projects.local.example`, `register_project.sh`'s header and hint, the bootstrap route's error message).

## Plan Authored
**Status**: complete
**When**: 2026-11-24 09:05 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-569/plan.md` at `774fb12d`

Revision after the Plan Review. Part 2's delete and keep lists are rebuilt function by function from callers (`_rc_source_setup`, `_rc_resolver_bin` kept; dead helpers removed; `test_ros2_colcon.sh` keeps its resolver-python helpers); the source-without-tool-root refusal sits in `_rc_require_manifest` plus the top of setup and sync, tested over ten verbs; part 3 names every old-reader module and test file and re-points the p11 fixtures; the documents move into part 2; Serves names "Light touch on projects".

## Plan Review
**Status**: complete
**When**: 2026-11-24 09:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #569 — repos-manifest: remove the prototype's reader, and drop the roadmap line about moving from its format
**Plan**: `.agent/work-plans/issue-569/plan.md` at `774fb12d`
**Branch**: `feature/issue-569`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three parts in the right order. Part 1 stands alone: one roadmap row, and `test_documents.py` does not read it. Part 3 depends on part 2 as stated. |
| Issue alignment | Good | All four steps of the issue and both earlier reviews are covered. Serves: "Workspace goal "Light touch on projects" (`README.md#workspace-goals` ...), `docs/design.md#registry-and-adapters` (part 2) and `tools/repos-manifest/docs/design.md#where-the-manifest-comes-from` (part 3)". The goal is now named, as the first review asked. |
| File targeting | Needs work | The adapter lists hold up against `grep -nw` (each delete-list function I checked has callers only inside the deleted code, and each keep-list caller is where the plan says). The test boundary at 2396/2397 is right: after line 4012, no `make_mr_*`, `write_mr_*`, `run_mr`, `mr_settings` or `mr_gen` is used. Only `MR_SRC`, `MR_PY`, `MR_SKIPPED` and `mr_test` are, and they live in 2334-2396. The part 3 module list checks out against the imports: no kept module imports `schema`, `merge`, `selectors`, `validate`, `emit` or `extends`, `ManifestError` is defined in `yamlload.py:15`, and `read_problem`/`has_repositories_key` are called only in `cli.py`. Gaps are in findings 1 to 5. |
| Consequences | Needs work | `single_project/unused_settings` and two root documents are missed (findings 2 and 7). |
| Principle alignment | Good | Fail loudly: the refusal point is right. Every verb that reads the manifest off the tool route calls `_rc_require_manifest` (env 2015, build 2185, test 2232, validate 2385, repos 2452, worktree_repos 2500, worktree_env 2571, repo_pin 2841), and setup and sync are handled at their tops. `install` (2432), `project_root` (2007) and `scope_for_pr` (2955) read no manifest and need no exemption beyond what the plan says. |
| ADR compliance | Good | ADR-0017 and ADR-0022: the root design changes in part 2, the tool's own design in part 3. ADR-0013: fine. |
| ROS conventions | N/A | Workspace plan. |

### First review's findings

All eight are answered in the plan's text, checked against the code. 1: `_rc_source_setup` kept (callers 2116, 2189, 2208, 2268, 2273). 2: `_rc_resolver_bin` kept (605, 835, 850, 1016, 1154, 2109), and the dead helpers are on the delete list. 3: the six modules are named. 4: every affected test file is named, and the p11 fixtures are re-pointed. 5: the documents moved into part 2. 6: the refusal sits at one shared point, and the four helper branches are removed. 7: the `docs/manifest/design.md` lines are listed. Serves: fixed. Finding 4 has one gap in what it deletes (finding 4 below).

### Findings

1. **[File targeting] Medium**: Part 2 says "`ACTIVE_PROJECT_SOURCE_REF` / `_SOURCE_PATH` reads in the adapter go". Two of those reads, at adapter.sh 1293-1294, are in `_rc_tool_validate`, on the tool route. They flag a leftover `source_ref`/`source_path` as a second record and name `project_setting.sh unset`. `test_tool_route_order` (test_ros2_colcon.sh 4357) asserts this check. Resolution: limit the removal to the reads inside the deleted functions (1473-1474, 1661-1674, 1931-1932), and keep 1291-1294.
2. **[Consequences] Medium**: `.agent/project_types/single_project/unused_settings` lines 9-11 give as the reason "only a ros2_colcon project reads it, as its manifest: register it as type ros2_colcon". That is false after part 2. `test_project_file.sh` 1893-1894 and `test_register_project.sh` 688 assert the text. The plan's "re-read; if ..." should be a concrete edit of all three. It also says `test_project_file.sh` only tests keys that stay, which misses 1893-1894. Related, and the plan should say which way it goes: issue 332's rule ("a setting is never stored and silently ignored") would put `source`, `source_ref` and `source_path` in `ros2_colcon/unused_settings` too, refusing them at `set` time. That conflicts with the tool route's validate message and with the separate roadmap line for removing the keys, so the plan should state why it does not.
3. **[File targeting] Medium**: In `test_register_project.sh`, the plan replaces the #436 block (692-742) with a registration "where `repos-manifest init` ran ... asserting setup runs". Two problems. First, `register_project.sh` runs setup only when the root does not exist (line 784), so after `init` it does not run. Second, the tool-route registration test already exists at 1056-1080. It uses `MR_SRC`/`MR_PY`, found inside the #436 block ("MR_PY, found above"), along with the fail-or-skip logic at 735-741. Resolution: delete only the #436 test body, and keep the `MR_SRC`/`MR_PY` finder and its fail-or-skip lines so the 1056 test still runs. No new registration test is needed beyond the existing one.
4. **[File targeting] Medium**: `test_cli.py` 76-95 (`test_cli_any_other_exception_is_one_fixed_line`) is the only test of `cli.py`'s internal-error backstop (line 454; the one other mention, `test_build.py:1760`, only asserts its absence). The plan deletes it because it monkeypatches `resolve_chain`. Resolution: port it to the new reader (monkeypatch `cli.read_manifest` or `selection.resolve`) rather than delete it. The `--out` cannot-be-written case at 97-104 is covered for the new reader by `test_output.py:241`, so deleting that one is fine.
5. **[File targeting] Low**: `test_output.py` 776-780 asserts "--cache-dir is for a manifest in the earlier format". It goes too once `--cache-dir` is removed (argparse exits 2). The plan names only 772-774 and 842.
6. **[Principle alignment] Low**: The new refusal test asserts "no `vcs`, `curl` or `git` call logged". `make_toolchain_stubs` has no git or curl stub, and a refusal message that names the resolver through `_rc_resolver_bin` itself runs `git rev-parse`. Resolution: state the check as nothing fetched or imported (an empty `vcs.log`, no curl stub run), or allow that `rev-parse`. `test_tool_route_order` (4344) already covers `source` plus `.repos-manifest/` taking the tool route. Fold the control in there, and drop its now-vacuous "validate does not take the manifest route" assertion (4360). `test_bootstrap_no_url_names_the_tool` (5524) already asserts the `init` text, so the rewritten `test_bootstrap_no_url_names_source` can be folded into it too.
7. **[Consequences] Low**: `docs/fork_parity.md` is the root's (`docs/fork_parity.md:83`: "the resolver is a tested prototype nothing calls"), not under `tools/repos-manifest/docs/` as part 3 says. Root `docs/roadmap.md:273` says "the adapter's manifest route with #436, whose acceptance is still open". That is current tense and stale after part 2, so it belongs in part 2. And the tool roadmap row at line 31 ("no ... cache of parents kept between runs") becomes true in part 3; the plan should say so.

### Summary

The revision fixes everything the first review raised, and the adapter and module lists now match the code. The refusal sits where every manifest-reading verb passes. Before implementing, correct four specific misreadings: the tool route's validate still reads `source_ref`/`source_path`; the `single_project` refusal text and its tests point at the removed route; `test_register_project.sh` must keep its resolver finder, and its replacement test cannot expect setup to run; and the CLI's internal-error backstop test must be ported, not deleted.

### Recommended Actions

- [ ] Part 2: keep `_rc_tool_validate`'s reads of `ACTIVE_PROJECT_SOURCE_REF`/`_PATH` (1291-1294); limit the variable sweep to the deleted functions.
- [ ] Part 2: edit `single_project/unused_settings` 9-11 and its asserts in `test_project_file.sh` 1893-1894 and `test_register_project.sh` 688; say whether `ros2_colcon/unused_settings` gains the `source*` keys, and why.
- [ ] Part 2: in `test_register_project.sh`, delete the #436 test but keep the `MR_SRC`/`MR_PY` finder and its fail-or-skip lines; rely on the existing tool-route registration test (1056).
- [ ] Part 2: put root `docs/roadmap.md:273` and root `docs/fork_parity.md:83` on the right part's list; fold the new tests into `test_tool_route_order` and `test_bootstrap_no_url_names_the_tool`; restate the "no fetch" check.
- [ ] Part 3: port `test_cli.py` 76-95 to the new reader; also remove `test_output.py` 776-780; note that tool roadmap row 31 becomes true.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 09:09 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second Plan Review at af2b47b4 has no high finding, confirms the three parts, their order and the delete and keep lists, and none of its seven findings touches part 1)
**After**: plan
**Decision**: proceed

This answer starts part 1 only: the one row of the tool's roadmap, which the review found stands alone. The seven findings of the second Plan Review are all about parts 2 and 3. They are not dropped: after part 1 merges, the plan checkpoint that follows is answered revise, the plan takes all seven in, and it is reviewed again before part 2 is implemented.

Host decision on the review's open question, for the owner's veto: `ros2_colcon/unused_settings` does not gain `source`, `source_ref` and `source_path` in this issue. The workspace-side roadmap has its own line for removing those keys, and the tool route's validate already names leftover ones; the revised plan says so.

## Implementation
**Status**: complete
**When**: 2026-11-24 09:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-569 at `30b56f4d`

Part 1 of 3: the tool roadmap row only.

- `tools/repos-manifest/docs/roadmap.md` line 29: the row "The first resolver that reads the new format comes with a note on moving from the prototype's format, command and output layout" is replaced by "The prototype's reader and `docs/prototype.md` are removed". The check cell stays empty (sitrep_checks has no absence check), as the plan says.
- Nothing else reads the old row's text: a grep across the repo (tests included, work plans aside) for its words found only the roadmap itself.
- `sitrep_checks.sh --root <worktree>` reads the new row as `subline` of `tools/repos-manifest/docs/roadmap.md`, `unchecked`, check `none`; no `format` row is printed.
- Suites: `pytest tools/repos-manifest/tests/test_documents.py`: 11 passed. No script under `.agent/scripts/` changed, so no script suite applies. Pre-commit hooks on the commit passed (validate-script-tests skipped per #465). The full pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 09:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-569 at `81267304`
**Base**: main
**Depth**: Deep (reason: whole-branch diff is 496 lines over 3 files, 495 of them the plan and progress records; the code change is one roadmap row)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 1 | **Ship**: recommended — no must-fix findings

Part 1 of 3 reviewed as part 1 (parts 2 and 3 are deliberately off this branch per the Checkpoint at 127f305d). Specialists: static (pre-commit on the roadmap file, all applicable hooks passed), governance, plan drift (matches Part 1 steps 1 to 3 exactly), Claude adversarial (no findings; `sitrep_checks.sh --root .` reads the row as `unchecked none`, `test_documents.py` 11 passed), Codex (no findings), Gemini (three suggestions, all dropped: the wording is the issue's own step 1 text; a grep finds no other reference to the old row; the new reader already exists, so the row's order does not leave the tool without a reader).

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 09:13 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the pre-push review at 82ea5179 approved with no findings, and the host's full pre-commit pass over the branch's files passed)
**After**: publish
**Decision**: publish

Part 1 of 3: the one row of the tool's roadmap. The full pass ran with no SKIP over the files changed since origin/main; every hook that applied passed, and no script suite applied (no script changed). Outside reviewers on round 1: Codex ran and found nothing; Gemini ran and made three suggestions, all dropped by the reviewer as without substance for this change. The pull request says "Part of #569".

## Integrated Review
**Status**: complete
**When**: 2026-11-24 09:16 -05:00
**By**: claude-code (claude-opus-5-5)
**Reviews-read**: none

**PR**: #571 at `e6ef187f`
**Sources**: 2 (Local Review (Pre-Push) @ `81267304` (covers e6ef187f via bookkeeping), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

### Findings

None. The PR changes one row of `tools/repos-manifest/docs/roadmap.md` (the migration-note line becomes "The prototype's reader and `docs/prototype.md` are removed"). Checked: no other reference to the removed wording in `tools/` or `docs/`; the empty check cell is deliberate, since `sitrep_checks.sh` has no absence check (plan, part 1 item 2). The pre-push local review approved with no findings; no GitHub review or conversation comment exists. CI: Validate Documentation passed; Lint (pre-commit), Validate Adapter Contract and the repos-manifest tests (Python 3.10, 3.14) were still pending after a 150-second wait.

### False positives

## Local Review
**Status**: complete
**When**: 2026-11-24 09:32 -05:00
**By**: claude-code (claude-opus-5-5)
**Verdict**: approved

**PR**: #571 at `e6ef187f`
**Depth**: Deep (reason: cold read, cross-model only: codex, per handoff)
**Must-fix**: 0 | **Suggestions**: 0

Codex (EXIT=0) read the PR title, URL and final diff only and reported no issues; it noted GitHub was unreachable from its sandbox, so it worked from the supplied diff and the local checkout. Specialists 5a-5d were skipped per the cold-read handoff. Tier by size: 523 changed lines.

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-11-24 09:33 -05:00
**By**: claude-code (claude-opus-5-5)
**Reviews-read**: 6040846319

**PR**: #571 at `e6ef187f`
**Sources**: 4 (Local Review (Pre-Push) @ `81267304` (covers e6ef187f via bookkeeping), Local Review (Codex cold read) @ `e6ef187f`, Copilot @ `e6ef187f` (could not review), CI rollup)
**Cross-source confirmations**: 0
**CI**: all-pass

### Findings

None. The change is one row of `tools/repos-manifest/docs/roadmap.md`. The Codex cold read (newest `## Local Review`, approved) found nothing; its "No issues found. LGTM." line is a verdict, not a finding, and the `sources` helper returned no open local findings at this head. Copilot's review 6040846319 at `e6ef187f` says, in its own words, "Copilot was unable to review this pull request because the user who requested the review has insufficient remaining quota": it holds no findings because it did not review, not because it reviewed and found nothing. No conversation comments, no inline comments.

CI at `e6ef187f`: Lint (pre-commit), Validate Adapter Contract, Validate Documentation, and the repos-manifest tests (Python 3.10 and 3.14) all succeeded (each reported twice, push and pull_request). The `copilot-pull-request-reviewer` check-run concluded `failure`; that is Copilot's quota notice above, not a CI failure of the change, and it is not counted as a failing check.

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-24 09:37 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

"Merge (Recommended)"

Asked at the merge checkpoint for pull request 571 (part 1 of 3: the one row of the tool's roadmap) after the Integrated Review at 0fcef131 with no open findings. The dialog gave: the old and new row text; the pre-push review approved with no findings and two triages with nothing open; all 10 CI checks passing on head e6ef187f, with the copilot-pull-request-reviewer check's failure named as its quota notice; the outside reviewers (Codex and Gemini before the push, Copilot requested and not available for lack of quota, the Codex cold read of the final diff with nothing found); and that the issue stays open, with the plan revised for the second Plan Review's seven findings and reviewed again before part 2. The other choices offered were hold and stop.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 09:38 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan checkpoint after a merge; the second Plan Review at af2b47b4 left seven findings on parts 2 and 3 that the plan has not taken in, so proceed is not open to the host)
**After**: plan
**Decision**: revise

Pull request 571 (part 1 of 3, the tool's roadmap row) merged on 2026-11-24. The issue is still open because parts 2 and 3 are to come. Delivered: part 1. Not delivered: part 2 (cut the adapter's manifest route) and part 3 (remove the reader). The plan is unchanged since its last review (774fb12d), but that review's verdict was needs-work for parts 2 and 3, and the host's proceed of the same day covered part 1 only. The plan now takes in all seven findings and is reviewed again before part 2 is implemented. Main has moved since the plan was written (other merges changed `test_ros2_colcon.sh` and `worktree_create.sh`), so the plan's line numbers are re-read from this branch.

## Plan Authored
**Status**: complete
**When**: 2026-11-24 09:41 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-569/plan.md` at `6530c842`

Revision after the second Plan Review and the merge of part 1 (pull request 571, marked delivered). All seven findings are in, each checked against the code: `_rc_tool_validate` keeps its `source_ref`/`source_path` reads; exact new text for `single_project/unused_settings` with its two test assertions; no new registration test, and the `MR_SRC`/`MR_PY` finder kept in `test_register_project.sh`; the CLI backstop test ported to `cli.read_manifest`; `test_output.py`'s `--cache-dir` case in part 3; the refusal test asserts nothing fetched or imported and is folded into `test_tool_route_order` and `test_bootstrap_no_url_names_the_tool`; root `fork_parity.md`, root `roadmap.md` (part 2) and tool roadmap row 31 (part 3) named. Host decision recorded: `ros2_colcon/unused_settings` does not gain the `source*` keys here. Line numbers re-read on `df2f5010`; `adapter.sh` did not change on main.

## Plan Review
**Status**: complete
**When**: 2026-11-24 09:45 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #569 — repos-manifest: remove the prototype's reader, and drop the roadmap line about moving from its format
**Plan**: `.agent/work-plans/issue-569/plan.md` at `6530c842`
**Branch**: `feature/issue-569`

Third review. Verdict ready on condition: the five findings below are small, exact and leave no design choice, so they go to the implementer as the directions under Recommended Actions instead of a fourth plan round.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Part 1 is delivered (PR 571). Part 2 (the adapter cut) and part 3 (the reader) are in the right order, and each is one PR. |
| Issue alignment | Good | All four steps of the issue are covered. Step 2's dependency is settled: the cut is made here, in part 2. Serves: "Workspace goal "Light touch on projects" (`README.md#workspace-goals`; ...), `docs/design.md#registry-and-adapters` (part 2) and `tools/repos-manifest/docs/design.md#where-the-manifest-comes-from` (part 3)". |
| File targeting | Needs work (small) | Findings 1 and 2. The adapter's delete list, checked with `grep -nw` per helper, holds. The test boundaries hold: 2336-2396 kept, 2397-4013 deleted, calls 5814 and 5817-5850. Outside the deleted range, only `test_tool_route_order` (4353, 4362) touches `source`. |
| Consequences | Needs work (small) | Findings 4 and 5: six text sites are not on the list. |
| Principle alignment | Good | Fail loudly holds. Every manifest-reading verb off the tool route reaches `_rc_require_manifest` (env 2015, build 2185, test 2232, validate 2385, repos 2452, worktree_repos 2500, worktree_env 2571, repo_pin 2841), and setup and sync get the refusal at their tops. Finding 3 is a test that would pass vacuously. |
| ADR compliance | Good | ADR-0017 and ADR-0022: the root design changes in part 2, the tool's design in part 3. ADR-0013: entries recorded. |
| ROS conventions | N/A | Workspace plan. |

### Second review's findings

All seven were checked against the code. Six are answered in full and one in part.
1. Answered. `_rc_tool_validate` reads `source`, `source_ref` and `source_path` at adapter.sh 1292-1294, and the plan keeps them. `test_tool_route_order` 4361 still asserts them.
2. Answered. Exact new text for `single_project/unused_settings` 9-11. The asserts match: test_project_file.sh 1894 and test_register_project.sh 683/688. The old "says it once" `assert_not_contains` stays green. The `ros2_colcon/unused_settings` decision is stated.
3. Answered. The finder is at 698-706, the wrapper and python3 link at 708-713, and fail-or-skip at 735-742. The tool-route registration test (1063) uses `MR_PY`/`MR_SRC` (1077, 1117) and has its own fail-or-skip at 1174.
4. Answered. `read_manifest` is imported into `cli` (cli.py line 40), and `_load_new` (78) calls it first in both new commands, so `monkeypatch.setattr(cli, "read_manifest", ...)` is reached. `main`'s `except Exception` arm (451) catches every one of the five types.
5. Answered. test_output.py 776-780 is named.
6. Answered in part. The check is restated and the tests are folded in. But the plan says `make_toolchain_stubs` makes a `curl` stub, and it does not (test_ros2_colcon.sh 111-147 makes only `colcon` and `vcs`). See finding 3.
7. Answered. Root `fork_parity.md:83` is split across parts 2 and 3, root `roadmap.md:273` is in part 2, and tool roadmap row 31 is in part 3.

### Findings

1. **[File targeting] Medium, part 2.** The plan deletes the manifest-route header "from its `# --- Manifest route` line, 701, to just before the 'Tool route' header". The header is at 702 and the Tool route header at 801. That range also holds `_rc_route` (792-800) and its comment (788-791), which the plan keeps and rewrites elsewhere. Read literally, it deletes the route function. Resolution: delete 702-787 (through "...run through _rc_nofd and inherit neither lock."), and keep 788-800.
2. **[File targeting] Medium, part 2.** `adapter_sync` has a second block that only the manifest route uses. It is at 2364-2371: `if [ "$route" = manifest ]`, printing "source: N repositor... not checked out yet" and the `_RC_LAYERS_CHANGED` note. Its counter `missing` (local at 2318, increment at 2341) is read nowhere else. The plan names only the block at 2321 and the comment at 2310. `_RC_LAYERS_CHANGED` is set only in deleted code (1627, 1732).
3. **[Principle alignment] Low, part 2.** The new `test_source_without_tool_root_refused` asserts "no `$sb/curl.log`". No stub writes that file unless the test creates one: `make_toolchain_stubs` has no curl stub, and only `make_tool_root` (4212) writes one. As planned, the "nothing fetched" half passes whether or not curl runs. Separately, the bootstrap block the plan cites as 603-604 is 603-605 (`if`, `echo`, `fi`), and the kept tool line is 606.
4. **[Consequences] Low, part 2.** These text sites describe the cut route and are not on the plan's list. The plan's `grep -n 'manifest route'` does not catch them. (a) `.agent/knowledge/script_reference.md:27`: the `project_setting.sh` row calls `source`/`source_ref`/`source_path` "a `ros2_colcon` project's manifest in the new format, issue #436". (b) `.agent/project_types/ros2_colcon/registration.conf` 9-12: "or resolved from its source (a manifest in the new format; issue #436)". (c) `.agent/scripts/_project_registry.sh` header 69-70: "(for ros2_colcon, its manifest; issue #436)". (d) The adapter.sh header, 8-11 ("Three routes ... the two older ones (issue #436)") and 14-19 (`source` ... `configs/manifest-resolved` ... "see 'Manifest route' below"). (e) Root `docs/design.md:439`: "`source`, `source_ref` and `source_path` (where its source description lives, #436)". (f) `docs/manifest/design.md` 38-46: 42 is "`register_project.sh` writes both, with ... `--set source=...`" and 46 is "three routes". Only 39 and 51 of that range are on the list, and "three routes" is caught by none of the plan's re-grep terms. No skill under `.claude/skills/` and no other knowledge file names `source=` or the route; I grepped `.claude` and `.agent/knowledge`.
5. **[Consequences] Low, part 2.** The root design bullet (`docs/design.md#registry-and-adapters`, 484-496) is planned only for removals. The new refusal is boundary behavior and should be stated there too: a `source` set on a root without `.repos-manifest/` is refused at every manifest-reading verb and at setup and sync, naming `init` and the `unset`.

On the host's question about `project_setting.sh` and `register_project.sh`: after part 2, `project_setting.sh set <ros2_colcon> source=...` still succeeds. It is checked in full by `_project_source_combination` (`_project_registry.sh` 1275-1305: a URL needs `source_ref`, a path takes neither, not beside `bootstrap_url`). The dispatcher (`.agent/scripts/adapter` 331-335) still exports the keys. Every verb off the tool route then refuses, and on the tool route `validate` names the leftover keys as a second record. `register_project.sh ... ros2_colcon --set source=...` therefore fails loudly: setup is refused for a missing root (line 1135), and the static gate's `adapter validate` is refused for an existing one. This is what the plan's `unused_settings` decision intends ("accepted by `set` ... refused at use ..., never silently ignored"). It is consistent with the issue. Nothing in it is silent.

The suites part 2 could break: `test_project_registry.sh` `test_dispatcher_exports_source_keys` (2135) stays green, since the dispatcher still exports. `test_adapter.sh` 396-405 checks the `single_project` list, which keeps its keys. `test_design_anchors.sh:617` writes its own fixture text. `validate_adapter.sh` checks verbs, silence at source and `unused_settings` reasons, none of which part 2 removes. `test_skill_paths.sh` and the other suites do not reference the route.

### Summary

The plan is sound and its lists match the code. Parts 2 and 3 can be implemented with the five directions below handed over verbatim. None needs a design choice.

### Recommended Actions

- [ ] Part 2, adapter.sh: delete the manifest-route header comment as lines 702-787 only. Keep `_rc_route` and its comment (788-800), and rewrite that comment for two routes.
- [ ] Part 2, adapter.sh `adapter_sync`: also delete the `if [ "$route" = manifest ]` block after the layer loop (2364-2371), the `missing` local and its increment (2318, 2341), and the `route` local if only these used it. Afterwards `grep -n _RC_LAYERS_CHANGED` must return nothing.
- [ ] Part 2, adapter.sh `_rc_bootstrap_manifest`: remove the whole `if [ -n "${ACTIVE_PROJECT_NAME:-}" ]` block that echoes `source=` (603-605), and keep the "Or set the root up with the manifest tool" line (606).
- [ ] Part 2, test_ros2_colcon.sh `test_source_without_tool_root_refused`: before the verbs run, write the curl stub into `$sb/bin`, as `make_tool_root` does at 4212 (`printf '#!/usr/bin/env bash\necho "CURL_RAN:$*" >> "%s"\nexit 1\n' "$sb/curl.log" > "$sb/bin/curl"; chmod +x "$sb/bin/curl"`). Then the "no `$sb/curl.log`" assertion can fail.
- [ ] Part 2, text: rewrite these to say `source`/`source_ref`/`source_path` are still accepted by `project_setting.sh` but read by no route. A `ros2_colcon` root without `.repos-manifest/` that sets them is refused at use, naming `repos-manifest init` and the `unset`. On the tool route, `validate` names them as a second record. Their removal is the workspace roadmap's own line. The sites: `.agent/knowledge/script_reference.md:27`, `.agent/project_types/ros2_colcon/registration.conf` 9-12, `.agent/scripts/_project_registry.sh` 69-70, adapter.sh header 8-19, root `docs/design.md:439`, and `docs/manifest/design.md` 38-46 (including "three routes" at 46 and `--set source=` at 42). Add one sentence for that refusal to the root design's routes bullet (484-496). Before the PR, also re-grep `adapter.sh`, `docs/` and `.agent/` (work-plans aside) for `three routes`, `manifest-resolved`, `lock.source` and `#436`, and name each remaining hit as history.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 09:46 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the third Plan Review at 99202142 finds the plan ready to implement; its five remaining findings, two medium and three low, are all on part 2, need no design choice, and are written as exact directions for the implementer)
**After**: plan
**Decision**: proceed

This answer starts part 2: the cut of the adapter's manifest route, with its tests and the documents that describe it. The plan is unchanged since that review (6530c842), and part 2 is not yet delivered (part 1 is, as pull request 571). The implement handoff quotes the review's "Directions for the implementer" in full and tells the implementer to follow them where they differ from the plan's text: the header comment's range (keep `_rc_route`), the second manifest-only block in `adapter_sync`, the bootstrap error's `source=` block, the curl stub for the refusal test, and the six text sites plus the one sentence for the root design's routes bullet. Part 3 follows as its own pull request after part 2 merges.

## Implementation
**Status**: complete
**When**: 2026-11-24 10:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-569 at `fa159e0e`

Part 2 of 3: the adapter's manifest route is cut. Part 3 (the reader under `tools/repos-manifest`) is not touched; the tool keeps `--layout manifest-dir`. The CI job name and every GitHub issue are left for the owner.

- `2fc5cef0` adapter.sh (+64 −892): the manifest-route header (the old 702-787), the route's 18 functions from `_RC_TRANSPORTS` to `_rc_validate_manifest_route`, `_rc_source_is_url`, `_rc_registry_field_missing`, `_rc_file_stamp`, `_rc_check_single_source`, `_rc_pin_manifest_dir`, `_rc_unpin_manifest_dir`, `_rc_remove_generated` and their variables are deleted; the manifest branches of `_rc_manifest_dir`, `_rc_check_manifest`, `_rc_distro`, `adapter_setup`, `adapter_sync` (the block after the layer loop, `missing` and `route` included; `grep _RC_LAYERS_CHANGED` finds nothing) and `adapter_validate` go; the `source=` block of `_rc_bootstrap_manifest`'s no-URL error goes, the manifest tool line stays. `_rc_route` returns tool or bootstrap, comment rewritten. New `_rc_refuse_removed_source`, run first by `_rc_require_manifest`, `adapter_setup` and `adapter_sync`. Every kept `_rc_*` function has a caller; no deleted name is left in `.agent`, `docs`, `.claude` or `tools`.
- Same commit, tests: test_ros2_colcon.sh (+58 −1669) loses `make_mr_resolver` through `test_bootstrap_no_url_names_source` and their calls, keeps `MR_SRC`/`MR_PY`/`mr_pick_python`/`mr_test` as "toolchain for the tool-route tests", drops the vacuous `resolved-from` assertion, adds `test_source_without_tool_root_refused` (ten verbs refused with the message; curl stub written into `$sb/bin` first; no vcs, colcon or curl run; install, project_root and scope_for_pr not refused) and the `source=` absence assertion in `test_bootstrap_no_url_names_the_tool`. `single_project/unused_settings` takes the plan's text, with test_project_file.sh and test_register_project.sh following; the #436 registration test is deleted, the `MR_PY` finder and wrapper kept.
- `fa159e0e` text: script_reference.md:27, registration.conf, the `_project_registry.sh` header, register_project.sh (header and setup hint), projects.local.example, root docs/design.md (439, the manifest-directory bullet, the routes bullet with the refusal sentence, a change-log row), docs/manifest/design.md ("Two routes"; the step-by-step section and the route's guarantees go; later sections speak of the removed route in the past), root docs/roadmap.md:273, docs/fork_parity.md:83.

Differences from the plan and directions, checked against the code: the bootstrap block was at 602-604, not 603-605 (the tool line was 605). `_rc_nofd` and `_rc_git_local_vars` also lose their `8<&- 9>&-` redirections: nothing opens fd 8 or 9 after the cut. The link `docs/design.md` -> `manifest/design.md#the-manifest-route-step-by-step` now points at `#two-routes`.

Remaining hits for `three routes`, `manifest-resolved`, `lock.source`, `#436` (and "manifest route"), all history: design.md change-log rows of 2026-11-13 and 2026-11-18; ADR-0019:115 and ADR-0022:41-45,102; docs/manifest/roadmap.md:17, 37 (#436 acceptance) and 48 (the #481 deferral, now due, for the owner); manifest/design.md's past-tense lines about the removed route; root roadmap.md:448 and 481-485 and the inspiration digest (ros2's own #436, unrelated); `_project_registry.sh:1275` and the #436 test labels in test_project_registry.sh, test_project_file.sh, test_adapter.sh (the source keys, which stay); test_design_anchors.sh:617 (its own fixture text); adapter.sh:15 and the new refusal's comment (name the removal).

Suites run, each on its own from the worktree (all exit 0): test_ros2_colcon.sh "Results: 1154 passed, 0 failed, 0 skipped" (no real-tool test skipped); test_register_project.sh 216 passed, 0 failed; test_project_file.sh 701 passed, 0 failed; test_project_registry.sh 425 passed, 0 failed; test_adapter.sh 248 passed, 0 failed; test_design_anchors.sh 82 passed, 0 failed; test_skill_paths.sh 200 passed, 0 failed; validate_adapter.sh: all 13 verbs implemented for both types. Also every suite naming `_project_registry.sh` or `register_project.sh`, all exit 0: test_gh_create_issue, test_discover_governance (32), test_dispatch_phase (244), test_capture (41), test_fresh_clone_no_project (26), test_merge_pr_gate (213), test_gh_create_pr, test_merge_pr (175), test_precommit_hook_path (19), test_pr_status (3), test_merge_pr_skill (132), test_session_start_layer (52), test_validate_workspace_stale (126), test_user_tier_guard (64), test_worktree_enter_stderr (35), test_sitrep_checks (253), test_worktree_remove (136), test_sitrep_root (65), test_worktree_create, test_register_session_root (72), test_project_integration_audit (279), test_script_tests_hook_scope (358). shellcheck --severity=warning is clean on the changed scripts. pytest of tools/repos-manifest was not run (nothing there changed). The full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 10:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-569 at `3ff95fa5`
**Base**: origin/main
**Depth**: Deep (reason: 16 files, +569 -2880; deletes the adapter's manifest route, ~890 adapter and ~1670 test lines, and changes the root design)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 1 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Part 2 of 3 (the adapter cut). Checked: (a) no tool-route or bootstrap-route code went with the cut; every deleted `_rc_*` name has zero hits in .agent, docs, .claude, tools, Makefile and .github; the deleted tests covered only deleted code, except `_rc_nofd`'s GIT_* scrub, still tested on the tool route. (b) `_rc_refuse_removed_source` runs first in `_rc_require_manifest` (env, build, test, validate, repos, worktree_repos, worktree_env, repo_pin) and at the top of setup and sync, before `_rc_bootstrap_manifest`'s curl; it returns 0 on the tool route and when `source` is unset; `source_ref`/`source_path` without `source` are refused earlier by the settings-file check. (c) the `8<&- 9>&-` removal is safe: nothing left in adapter.sh opens fd 8 or 9; register_project.sh's fd 8 lock is closed on every child it starts (`8>&-` at 1136, 1142, 1148, 1156, 1160); `_project_registry.sh`'s fd 9 lock lives in the settings writer's subshell. (d) docs/design.md and docs/manifest/design.md agree with each other and the code; the `#two-routes` anchor resolves, no link to a removed heading remains. Departures from the plan (fd redirections, wider manifest/design.md rewrite, design.md link fix) are sound. Not edited, by plan: docs/manifest/roadmap.md (the "fetch and generated directories are removed" line is now true with no check; deferrals #447 and #481 are now due and go in the PR for the owner).

Run: test_ros2_colcon.sh 1154 passed 0 failed 0 skipped; test_register_project.sh 216 passed; test_project_file.sh 701 passed; shellcheck --severity=warning clean on the six changed scripts; check_design_anchors.sh rc 0 (adversarial). Cross-model: Codex completed (two points, merged into the first suggestion and judged suggestion, not must-fix: no instance uses the route, and the flat-layout limit is the tool route's own); Gemini failed (headless agy auto-denied a Bash tool call, empty response).

### Findings
- [x] (suggestion) The refusal's way on does not fit two old `source` setups: `repos-manifest init` takes a local path only, so a URL `source` needs "clone at `source_ref`, pass the file at `source_path`"; a manifest with no `distros:` cannot use `--distro-dirs` and the adapter refuses the flat layout — say so in the message (Codex) — `.agent/project_types/ros2_colcon/adapter.sh:628`
- [x] (suggestion) "Some of what the adapter gives today is not in the tool's design yet" is stale: the lock, fetch limits and kept directory are now what the removed route gave — `docs/manifest/design.md:331`
- [x] (suggestion) `test_tool_route_order` runs only env and validate with `source` set on a tool root; add a `setup` (and `sync`) call before the settings file is replaced — `.agent/scripts/tests/test_ros2_colcon.sh:2718`
- [x] (suggestion) No test that `register_project.sh <new path> ros2_colcon --set source=...` (the formerly documented way) is refused at setup with the new message and rolled back — `.agent/scripts/tests/test_register_project.sh`

## Checkpoint
**Status**: complete
**When**: 2026-11-24 10:12 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the pre-push review at eb8d6e00 approved with four suggestions; all four are small, real and within reach, and the workspace's quality standard says not to leave them)
**After**: publish
**Decision**: address

All four suggestions of the round-1 review are fixed before the push, none deferred: the refusal's way on for a URL `source` and for a manifest with no `distros:`; the stale sentence in `docs/manifest/design.md`; `setup` and `sync` added to `test_tool_route_order`; and a test that registering a new path with `--set source=` is refused at setup with the new message and rolled back. The host's full pre-commit pass was not run on this head, since the fix pass changes it. Outside reviewers on round 1: Codex ran and its two points became the first suggestion; Gemini failed (the headless run denied a tool call and returned nothing).

## Implementation
**Status**: complete
**When**: 2026-11-24 10:18 -05:00
**By**: claude-code (claude-opus-5-5)

**Branch**: feature/issue-569 at `deb6660c`
**Addressed**: Local Review (Pre-Push) at `3ff95fa5` (2026-11-24 10:12 -05:00)
**Commits**: 07e99799, bdcb8a2b, ee186590, deb6660c

### Actions
- [x] The refusal's way on now fits the old setups: a line says the manifest must list its distros (init --distro-dirs refuses one that does not, and the adapter refuses a root set up without --distro-dirs), and for a URL source (https, http or file URL, as the registry judges it) a line names the clone at source_ref and the file at source_path inside it (manifest.yaml when unset, the removed route's default), as init reads a local file only (verified in tools/repos-manifest/src/repos_manifest/init.py check_distros and system.py read_manifest); tests assert both lines and the URL case; docs/design.md's sentence quoting the message updated — `.agent/project_types/ros2_colcon/adapter.sh:631`
- [x] "What the tool has to give" opens with what is true now: the status is given, the rest is what the removed route gave and the tool does not give yet — `docs/manifest/design.md:331`
- [x] test_tool_route_order runs setup and sync on the tool root with source set, before the settings file is replaced: exit 0, not refused, the tool's sync ran in the root — `.agent/scripts/tests/test_ros2_colcon.sh:2733`
- [x] New test: `register_project.sh <new path> ros2_colcon --set source=...` writes the line and the settings file, runs setup, which refuses with the new message before making the directory, and the rollback removes the line and the settings file; no directory is left and nothing is named on KEPT=. No defect in register_project.sh — `.agent/scripts/tests/test_register_project.sh:691`

### Checks
- test_ros2_colcon.sh: === Results: 1183 passed, 0 failed, 0 skipped ===
- test_register_project.sh: test_register_project: 220 passed, 0 failed
- test_design_anchors.sh: test_design_anchors: 82 passed, 0 failed
- test_adapter.sh: === Results: 248 passed, 0 failed ===
- test_project_registry.sh: === Results: 425 passed, 0 failed ===
- test_project_file.sh: === Results: 701 passed, 0 failed ===
- test_worktree_create.sh: PASS: 112, FAIL: 0
- The full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 10:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-569 at `ba5c27dc`
**Base**: origin/main
**Depth**: Deep (reason: whole-branch diff, 16 files +672 -2882, deletes the adapter's manifest route and changes the root design; fix round classified on the whole diff)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 2 | **Ship**: continue — round 2: must-fix rising (0 -> 2); both are precise text or guard fixes, but the second touches a recorded owner decision

Round 2 of part 2, after the fix pass 07e99799..deb6660c. Checked against the code: each fix sentence that is in the message holds on its own (`init --distro-dirs` refuses a manifest with no `distros:`, init.py 80-84; the adapter refuses a flat layout, adapter.sh 755; `read_manifest` reads a path only, system.py 764; `manifest.yaml` is the removed route's default; the URL test `^(https?|file)://` is the registry's, _project_registry.sh 1300, and the registry requires `source_ref` with a URL). The new tests can fail (exact strings, exact `tool.log` line). The two must-fix are about what the message and documents leave out or say in the wrong context. Run: test_ros2_colcon.sh 1183 passed 0 failed; test_register_project.sh 220 passed 0 failed (adversarial); test_design_anchors.sh 82 passed; shellcheck --severity=warning clean on the six changed scripts. Cross-model: Codex completed (its must-fix is finding 2, its suggestion folded into finding 2); Gemini failed (headless agy auto-denied a Bash tool call, empty response).

### Findings
- [x] (must-fix) At registration (`register_project.sh <new path> ros2_colcon --set source=...`) the refusal's steps are wrong: "in <root>, run init" names a directory that does not exist, "the registered root then takes the tool route" and the `project_setting.sh unset` name a project the rollback removes, and NEXT= says "its bootstrap_url"; the new phi test locks that text in. `--set source*` with ros2_colcon can never register (setup or validate refuses it), so refuse it in register_project.sh before anything is written, saying: make the directory, run init in it, register it without `--set source=`; change the test to match — `.agent/scripts/register_project.sh:1136`, `.agent/scripts/tests/test_register_project.sh:692`
- [ ] (must-fix) The URL line's way on leaves a hand clone that goes stale silently: init records the file's path and every sync re-reads it from disk, never fetching (init.py 281, system.py 764), and removing the clone breaks sync. This undoes the owner's 2026-11-13 decisions "never silently stale" and "no kept clone: fetched afresh by each setup and sync" (docs/design.md change log), unsaid. Say in the message that the clone is kept and updated by hand until the tool reads a manifest from git; add "a manifest read from a git URL, fetched afresh" to "What the tool has to give"; stop counting "reads the manifest again on every sync" as covering it for a URL source; mark the mapping table's `--manifest-ref`/`--manifest-path` as the target (init takes neither yet, cli.py 349-374) and give the clone as today's way; name this gap to the owner in the PR — `.agent/project_types/ros2_colcon/adapter.sh:634`, `docs/manifest/design.md:331`, `docs/manifest/design.md:396`, `docs/design.md:493`
- [x] (suggestion) A root the removed route set up keeps its `layers/main/*/src` checkouts (maybe with local work) and `configs/manifest-resolved*` after `init` in the root, which then clones again under `<root>/<distro>/`; the tool route never reads the old ones. Say so in the message and the design, or point at an empty directory as the flat-layout refusal does (adapter.sh 690) — `.agent/project_types/ros2_colcon/adapter.sh:631`
- [x] (suggestion) Print the project's own `--distro`/`--role` from the registry line (`ACTIVE_PROJECT_DISTRO`/`ACTIVE_PROJECT_ROLE`, .agent/scripts/adapter 281-283) when set, instead of placeholders — `.agent/project_types/ros2_colcon/adapter.sh:631`
- [x] (suggestion) "a root set up without --distro-dirs is refused here" reads as this check refusing it; say "by the adapter" — `.agent/project_types/ros2_colcon/adapter.sh:632`
