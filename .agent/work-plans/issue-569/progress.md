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
