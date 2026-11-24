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
- [x] (must-fix) The URL line's way on leaves a hand clone that goes stale silently: init records the file's path and every sync re-reads it from disk, never fetching (init.py 281, system.py 764), and removing the clone breaks sync. This undoes the owner's 2026-11-13 decisions "never silently stale" and "no kept clone: fetched afresh by each setup and sync" (docs/design.md change log), unsaid. Say in the message that the clone is kept and updated by hand until the tool reads a manifest from git; add "a manifest read from a git URL, fetched afresh" to "What the tool has to give"; stop counting "reads the manifest again on every sync" as covering it for a URL source; mark the mapping table's `--manifest-ref`/`--manifest-path` as the target (init takes neither yet, cli.py 349-374) and give the clone as today's way; name this gap to the owner in the PR — `.agent/project_types/ros2_colcon/adapter.sh:634`, `docs/manifest/design.md:331`, `docs/manifest/design.md:396`, `docs/design.md:493`
- [x] (suggestion) A root the removed route set up keeps its `layers/main/*/src` checkouts (maybe with local work) and `configs/manifest-resolved*` after `init` in the root, which then clones again under `<root>/<distro>/`; the tool route never reads the old ones. Say so in the message and the design, or point at an empty directory as the flat-layout refusal does (adapter.sh 690) — `.agent/project_types/ros2_colcon/adapter.sh:631`
- [x] (suggestion) Print the project's own `--distro`/`--role` from the registry line (`ACTIVE_PROJECT_DISTRO`/`ACTIVE_PROJECT_ROLE`, .agent/scripts/adapter 281-283) when set, instead of placeholders — `.agent/project_types/ros2_colcon/adapter.sh:631`
- [x] (suggestion) "a root set up without --distro-dirs is refused here" reads as this check refusing it; say "by the adapter" — `.agent/project_types/ros2_colcon/adapter.sh:632`

## Implementation
**Status**: complete
**When**: 2026-11-24 10:50 -05:00
**By**: claude-code (claude-opus-5-5)

**Branch**: feature/issue-569 at `750881d8`
**Addressed**: Local Review (Pre-Push) at `ba5c27dc` (2026-11-24 10:31 -05:00)
**Commits**: 82f091d7, 68567f38, b927ea8c, 02ac34fb, 750881d8

### Actions
- [x] register_project.sh refuses a --set of source, source_ref or source_path for a ros2_colcon project before anything is written (no registry line, settings file or directory; a dry run too), through a new per-type data list .agent/project_types/ros2_colcon/registration_refused (the unused_settings grammar, read by registration_refused_setting in _project_registry.sh, checked by validate_adapter.sh), so the script still names no type. The message gives the way on: make the directory, run the manifest tool's init in it, register it without --set source=. source_ref and source_path alone were already refused by the combination check; they now get this refusal first. The phi test asserts the new behaviour; the adapter's refusal for an already registered root stays tested in test_ros2_colcon.sh (test_source_without_tool_root_refused). The NEXT= "its bootstrap_url, say" at the setup call is no longer reached on this path and is right for the remaining one (a bootstrap_url setup), so it is unchanged. project_setting.sh set of the keys on a registered ros2_colcon project stays accepted; ros2_colcon/unused_settings is unchanged — `.agent/scripts/register_project.sh`, `.agent/scripts/tests/test_register_project.sh`
- [x] The URL line says the clone is kept, never fetched by the tool, and pulled by hand before each sync; the message is shorter and points at a new section of docs/manifest/design.md, "A root that sets source", which holds the detail and says plainly what is given up. "What the tool has to give" gains "A manifest read from a git repo"; "reads the manifest again on every sync" no longer covers a URL source; the mapping table marks --manifest-ref/--manifest-path as the target, not taken by init today (verified: cli.py's init takes manifest, --role, --with, --distro, --distro-dirs, --fetch-from, --yes), with the hand clone as today's way. docs/design.md's routes text says the same and its change log gets a 2026-11-24 row for what was given up; the earlier 2026-11-24 row of this branch, which had no issue or line count, gets them (#569, 1252). The 2026-11-13 rows are untouched. The roadmap line covering it is the tool roadmap's "`base` and the manifest itself can be given as a path, a URL, or a file in a git repo" (tools/repos-manifest/docs/roadmap.md; "A manifest can be read from a private git server" is the related one); no roadmap line was added or edited. The PR text is the host's: this gap is to be named to the owner there — `.agent/project_types/ros2_colcon/adapter.sh`, `docs/manifest/design.md`, `docs/design.md`
- [x] The refusal says, when the root holds layers/main or configs/manifest-resolved (a link too), that init does not read the old checkouts under layers/main/<layer>_ws/src or configs/manifest-resolved* and clones again under <root>/<distro>/ (paths checked against d22692ac's adapter.sh); tested both present and absent; the design section says the same — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] The init command carries the registry line's --distro and --role when set, placeholders otherwise, and the unset line names only the fields the line has; tested with both, with distro only, and with none — `.agent/project_types/ros2_colcon/adapter.sh`
- [x] "is refused here" became "the adapter refuses" (now inside the shortened init line) — `.agent/project_types/ros2_colcon/adapter.sh`

### Checks
Suites for the changed scripts (_project_registry.sh, validate_adapter.sh, register_project.sh: their own suites and every suite naming them) and the changed suite files, each run on its own:
- test_register_project.sh: test_register_project: 225 passed, 0 failed
- test_adapter.sh: === Results: 258 passed, 0 failed ===
- test_ros2_colcon.sh: === Results: 1203 passed, 0 failed, 0 skipped ===
- test_project_registry.sh: === Results: 425 passed, 0 failed ===
- test_project_file.sh: === Results: 701 passed, 0 failed ===
- test_capture.sh 41/0; test_discover_governance.sh 32/0; test_dispatch_phase.sh 244/0; test_fresh_clone_no_project.sh 26/0; test_gh_create_issue.sh PASS 88 FAIL 0; test_gh_create_pr.sh PASS 113 FAIL 0; test_merge_pr_gate.sh 213/0; test_merge_pr.sh 175/0; test_merge_pr_skill.sh 132/0; test_precommit_hook_path.sh 19/0; test_project_integration_audit.sh 279/0; test_pr_status.sh 3/0; test_register_session_root.sh 72/0; test_script_tests_hook_scope.sh 358/0; test_session_start_layer.sh 52/0; test_sitrep_checks.sh 253/0; test_sitrep_root.sh 65/0; test_skill_paths.sh 200/0; test_user_tier_guard.sh 64/0; test_validate_workspace_stale.sh 126/0; test_worktree_create.sh PASS 112 FAIL 0; test_worktree_enter_stderr.sh 35/0; test_worktree_remove.sh 136/0
- test_design_anchors.sh: test_design_anchors: 82 passed, 0 failed (docs changed)
- The full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 10:55 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-569 at `81c9477d`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 2
**Round**: 3 | **Ship**: recommended — round 3: 1 mechanical must-fix (prev 2), not rising; fix and ship rather than another full round

Round 3 of part 2: the round-2 findings and the fix diff b34cfe6b..a66382af only (the merge 81c9477d's issue-563 work is out of scope). All five round-2 findings hold as fixed. Checked against the code: `register_project.sh` refuses a `--set` key listed in the type's `registration_refused` at line 653, after argument, name and type checks and before any write of the registry, settings file or directory, on a new path, a `--dry-run` and an adoption alike (the only earlier write is the pre-existing registry lock under projects.d, skipped by a dry run); `_project_type_setting_listed` returns 1 for an empty type or a type with no such file, so nothing is refused for single_project; `project_setting.sh set` is untouched and `ros2_colcon/unused_settings` unchanged (owner decision respected). The adapter refusal: each line checked; the distro/role and `unset` fields print exactly under their conditions, the URL line only for `^(https?|file)://`, the old-checkouts line only when `layers/main` or `configs/manifest-resolved` (or a link) exists; `init --distro-dirs` creates only `<root>/<distro>/` (system.py paths_init_creates), so it runs in an old root. `docs/manifest/design.md` "A root that sets `source`", the root routes text and the new change-log row say the clone is kept, never fetched by the tool, and can fall behind until the tool reads a manifest from git (accepted by the owner 2026-11-24). Run: test_register_project.sh 225 passed 0 failed; test_adapter.sh 258 passed 0 failed; test_ros2_colcon.sh 1203 passed 0 failed 0 skipped; test_design_anchors.sh 82 passed 0 failed; validate_adapter.sh both types pass. shellcheck not run (not installed on this machine). Cross-model: skipped (round-3 convergence check, per handoff).

### Findings
- [x] (must-fix) The new list is missing from the script reference: the `validate_adapter.sh` row names only the `unused_settings` and `registration.conf` checks, not `registration_refused`; the `register_project.sh` row does not say a `--set` key in the type's `registration_refused` is refused before anything is written. Also name the list beside `unused_settings` in docs/design.md's settings paragraph — `.agent/knowledge/script_reference.md:26`, `.agent/knowledge/script_reference.md:28`, `docs/design.md:450`
- [x] (suggestion) "run git pull in it before each sync" fails for a tag `source_ref` (verified: a `git clone --branch v1` is a detached HEAD and `git pull` exits 1, "You are not currently on a branch"); the test itself uses `source_ref=v1`. Say "keep it at `source_ref` by hand (a `git pull` for a branch)" in the message and the design — `.agent/project_types/ros2_colcon/adapter.sh:648`, `docs/manifest/design.md:88`
- [x] (suggestion) The newest change-log row's line count says 1258; after the merge of origin/main the file has 1259 lines — `docs/design.md:1205`

## Checkpoint
**Status**: complete
**When**: 2026-11-24 10:55 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 at 0561a183 left one must-fix and two suggestions, all small and exact; a review with open findings is not published past by the host)
**After**: rounds
**Decision**: address

The three round-3 findings are fixed before the push: the script reference and the root design's settings paragraph name the new `registration_refused` list; the advice to run `git pull` in the hand clone is reworded so it is right when `source_ref` is a tag; and the newest change-log row's line count is corrected after the merge of main. This is the host's first address answer at the rounds checkpoint. The reviewer's Ship line was "recommended" once these are fixed.

Recorded here for the part's later merge checkpoint, the owner's answer of 2026-11-24 to the one design question this part raised (cut the manifest route now and state that a manifest in a git repo needs a clone kept by hand, or wait until the tool reads a manifest from git): "Which ever is easier, I don't think much of this functionality will be used by any other agents until we are done". The host took the cut with the gap stated as the easier of the two, and told him so.

## Implementation
**Status**: complete
**When**: 2026-11-24 10:58 -05:00
**By**: claude-code (claude-opus-5-5)

**Branch**: feature/issue-569 at `785cd360`
**Addressed**: Local Review (Pre-Push) at `81c9477d` (2026-11-24 10:55 -05:00)
**Commits**: 89cc4863, e85f8aaa, 785cd360

### Actions
- [x] (must-fix) The per-type `registration_refused` list is named in the `validate_adapter.sh` row (checked like `unused_settings`) and the `register_project.sh` row (a `--set` key in it is refused with its reason before anything is written) of the script reference, and beside `unused_settings` in the settings paragraph of the design, each sentence checked against `_project_registry.sh`, `register_project.sh` and `validate_adapter.sh`; no other text describes `unused_settings` as the only per-type list (`registration.conf`, the onboard-project skill and the knowledge files mention it only for `build` and `test`) — `.agent/knowledge/script_reference.md:26`, `.agent/knowledge/script_reference.md:28`, `docs/design.md:454`
- [x] (suggestion) "run git pull in it before each sync" now reads "keep it at source_ref by hand before each sync (a git pull for a branch)" in the refusal, its test and the manifest design; the root design never had the phrase — `.agent/project_types/ros2_colcon/adapter.sh:648`, `.agent/scripts/tests/test_ros2_colcon.sh:2816`, `docs/manifest/design.md:88`
- [x] (suggestion) The newest change-log row counts the file's lines after the change (`wc -l`, per the log's header): 1262 after all three fixes, and its text names the settings-paragraph addition and a section growth of 6 lines — `docs/design.md:1208`

### Checks
- `test_ros2_colcon.sh`: === Results: 1203 passed, 0 failed, 0 skipped ===
- `test_design_anchors.sh`: test_design_anchors: 82 passed, 0 failed
- `test_skill_paths.sh`: test_skill_paths: 199 passed, 0 failed
- The other suites the grep names for `adapter.sh` (test_adapter, test_project_file, test_register_project, test_project_registry, test_worktree_create) match the generic file name; none asserts the changed message, so they were left to the host's full pass, as was the full pre-commit pass.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 10:59 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-569 at `062fe620`
**Base**: origin/main
**Depth**: Deep (reason: round 4 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 4 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round 4 of part 2: the round-3 findings and the fix diff 0561a183..062fe620 only (commits 89cc4863, e85f8aaa, 785cd360). All three round-3 findings hold as fixed. Checked against the code: `validate_adapter.sh` runs `project_type_unused_settings_problems` on `<type>/registration_refused` exactly as on `unused_settings` (lines 70-77; a type without the file, single_project, passes, as the header calls the list optional); `register_project.sh` (lines 650-664) refuses a `--set` key the type lists, printing the list's reason, before any write, and `ros2_colcon/registration_refused` lists exactly `source`, `source_ref`, `source_path`; `registration_refused_setting` in `_project_registry.sh` reads it. The script reference rows and the root design's settings paragraph say just that. The adapter's message and its test assert the same new string ("keep it at source_ref by hand before each sync (a git pull for a branch)"), and `docs/manifest/design.md` matches; `git grep "git pull in it"` finds the phrase only in progress.md history. `wc -l docs/design.md` = 1262 = the newest change-log row's count; "Registry and adapters" is 182 lines at HEAD against 176 on origin/main, so "grows by 6 lines" is true. Tests not re-run (the implementation entry records test_ros2_colcon 1203/0/0, test_design_anchors 82/0, test_skill_paths 199/0 at 785cd360; no code changed since). Cross-model: skipped (round-4 convergence check, per handoff).

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 11:10 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: publish
**Decision**: publish

"Publish, new issue (Recommended)"

Asked at the publish checkpoint for part 2 (the cut of the adapter's manifest route) after the round-4 pre-push review at b6d30da0 approved with no findings. The host's full pre-commit pass over the branch's files, with no SKIP, failed in one suite and passed everywhere else (54 of 55 suites; every other hook, shellcheck, the adapter contract and the design anchors included). The failure, shown to him verbatim:

- `test_review_viewer.sh`, 1 of 90 tests: `test_unsearchable_notes_folder_exits_1_one_line` fails with "AssertionError: 2 != 1 : review_viewer: cannot open a window (couldn't connect to display \":0\")".

The host told him it fails the same way on main, that this branch does not touch the review viewer, that the session has no local display (DISPLAY is an ssh-forwarded `localhost:11.0`), and that CI passed this suite on pull request 571. The host did not answer address itself, because the fix would be to an unrelated test. His answer: push part 2, let CI be the check on it, and open a separate issue for the review-viewer test. The other choices offered were to fix it in this branch, to publish with no issue, and to stop.

## Integrated Review
**Status**: complete
**When**: 2026-11-24 11:13 -05:00
**By**: claude-code (claude-opus-5-5)
**Reviews-read**: 6042973987

**PR**: #597 at `860476c`
**Sources**: 3 (Local Review (Pre-Push) round 4 @ `860476c` via the timeline, no open findings; Copilot @ `860476c`, review 6042973987, which says it "was unable to review this pull request because the user who requested the review has insufficient remaining quota", so it holds no findings; CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

### Findings

None. `review_progress.sh sources` at `860476c` returned no open local findings and no dropped entries; no inline or conversation comments on the pull request.

### False positives

None.

CI after waiting about 3 minutes: Validate Adapter Contract and Validate Documentation passed (both runs); Lint (pre-commit) and repos-manifest tests (Python 3.10, 3.14) were still pending in both runs. No failures seen. The copilot-pull-request-reviewer check-run belongs to the could-not-review notice, not to the change.

## Local Review
**Status**: complete
**When**: 2026-11-24 11:16 -05:00
**By**: claude-code (claude-opus-5-5)
**Verdict**: approved

**PR**: #597 at `860476c`
**Depth**: Deep (reason: cold read, cross-model only: codex, per handoff)
**Must-fix**: 0 | **Suggestions**: 3

Codex was the only reviewer, run by `cross_model_review.sh --pr 597 --issue 569 --agents codex` (EXIT=0, complete). It was given the pull request's title, URL and whole diff with `.agent/work-plans/` left out (the script's #312 filter). No plan-context section and no earlier review entries or findings went into the prompt. Nothing else in the diff was left out or cut short. Codex rated findings 1 and 2 must-fix. The lead checked both against the code and kept them as suggestions. Finding 1 needs `.repos-manifest/` to be removed while `setup` is running. Even then, only the project's own configured bootstrap fetch runs, and `_rc_require_manifest` refuses before any `vcs import`. Finding 2 ends in a loud failure that the registration rolls back, and `registration_refused` documents the check as covering `--set` only. The dry run still reports, wrongly, that the registration would go through.

### Findings
- [ ] (suggestion) `adapter_setup` decides the route twice (`_rc_refuse_removed_source`, then `_rc_route`). If `.repos-manifest/` is removed between the two checks, a root that sets `source` reaches `_rc_bootstrap_manifest` and fetches before the later refusal. Decide the route once and pass it to both checks. — `.agent/project_types/ros2_colcon/adapter.sh:1265`
- [ ] (suggestion) The `registration_refused` check reads only `--set` arguments. A settings file kept by `--remove --keep-settings` that sets `source` passes it: `--dry-run` reports the registration would go through, and a real run writes the registry line and then fails at setup or the static gate, which rolls the registration back. Check the settings file as it would be after the run, before the dry-run report and before anything is written. — `.agent/scripts/register_project.sh:653`
- [ ] (suggestion) The migration text says to remove the old checkouts once the new ones are in use. It does not mention package worktrees, whose `env.sh` was written once against the old `layers/main` overlays: they keep sourcing those overlays, and they break once the overlays are removed. Say to save the work in those worktrees and make them again on the tool layout before removing the old checkouts. — `docs/manifest/design.md:97`

## Integrated Review
**Status**: complete
**When**: 2026-11-24 11:21 -05:00
**By**: Claude Code (claude-opus-5-5)
**Reviews-read**: 6042973987

**PR**: #597 at `860476c`
**Sources**: 3 (Local Review @ `860476c` (Codex cold read, at 89fa6870 on the timeline), Copilot @ `860476c` (could-not-review notice: insufficient quota, no findings), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

CI at `860476c` (both runs, 45433939923 and 45433958660): Validate Adapter Contract and Validate Documentation pass; Lint (pre-commit) and repos-manifest tests (#267 prototype) (Python 3.10, Python 3.14) still pending (queued, no start) after a 4-minute wait. Nothing has failed.

### Findings
- [x] (low, Local Review @ `860476c`) `adapter_setup` decides the route twice: `_rc_refuse_removed_source` calls `_rc_route`, then `adapter_setup` calls `_rc_route` again. If `.repos-manifest/` goes away between the two, a root that sets `source` passes the refusal (tool route then) and reaches `_rc_bootstrap_manifest`, which fetches before `_rc_require_manifest`'s refusal fires. Checked at adapter.sh:1265-1270 and 629-632. Decide the route once and pass it to both (the same double read is at 1535-1536 in sync). — `.agent/project_types/ros2_colcon/adapter.sh` (deferred: owner, 2026-11-24, at the findings checkpoint: Merge, defer all three; follow-up issue 599)
- [x] (low, Local Review @ `860476c`) The `registration_refused` check loops over `SETS` only (register_project.sh:650-664). A settings file kept by `--remove --keep-settings` that sets `source` is not read for it: `--dry-run` reports the registration would go through (dry-run block at 836-866 never looks), and a real run writes the registry line before the adapter refuses at setup or validate, and the rollback removes it. Check the keys of the settings file as it will be after the run (existing file plus `--set`) against `registration_refused`, before the dry-run report and before anything is written; add a test for the kept-file case. — `.agent/scripts/register_project.sh` (deferred: owner, 2026-11-24, at the findings checkpoint: Merge, defer all three; follow-up issue 599)
- [x] (low, Local Review @ `860476c`) The migration text (design.md:94-98) says to remove the old checkouts once the new ones are in use, but says nothing of package worktrees. Their `env.sh` is written once at create time with the old `layers/main` overlay paths (adapter.sh:1793-1835), each behind an `if [ -f ]` guard, so once the old overlays are removed the lines are skipped without a word and the worktree's build no longer finds lower-layer packages. Say to save the work in those worktrees and make them again on the tool layout before removing the old checkouts. — `docs/manifest/design.md` (deferred: owner, 2026-11-24, at the findings checkpoint: Merge, defer all three; follow-up issue 599)

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-24 11:23 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: findings
**Decision**: merge

"Merge, defer all three"

Asked at the findings checkpoint for pull request 597 (part 2 of 3: the cut of the adapter's manifest route) after the Integrated Review at e0e2f186, which holds three open low findings from the Codex cold read. The dialog showed each verbatim (F1, the route decided twice in `adapter_setup`; F2, the `registration_refused` check reading only `--set`; F3, the migration text silent on package worktrees), each fix's size, that all three are on the path for the old `source` settings which nothing uses today, and that CI had 2 of 5 checks passed and 3 queued with nothing failed, with no merge until they pass. His answer defers all three to one follow-up issue, opened as #599. The other choices offered were to fix all three first, to fix F3 only, and to stop.

In the same dialog he was asked what follows part 2: part 3 of this issue (removing the old reader from the tool) or issue 498 part 2b (the tool reads a manifest from a git repo). His answer: "Part 3 first".

Earlier the same day, on the one design question this part raised (cut now and state that a manifest in a git repo needs a clone kept by hand, or wait for the tool to read from git): "Which ever is easier, I don't think much of this functionality will be used by any other agents until we are done".

Outside reviewers on this pull request: Codex ran in pre-push rounds 1 and 2 and as the cold read of the final diff, and found the points behind the round-1 and round-2 findings and F1 to F3; Gemini failed in rounds 1 and 2 (its headless run denied a tool call); Copilot was requested once and was not available ("insufficient remaining quota").

## Checkpoint
**Status**: complete
**When**: 2026-11-24 11:42 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: address

"Fix the conflicts (Recommended)"

The merge of pull request 597 on his answer of the same day did not land. `merge_pr.sh --pr 597 --type workspace` passed its review gate ("approved review at head `6771dcb` and a decision summary are present") and its CI wait ("CI checks passed on `6771dcb`"), then stopped with: "ERROR: PR #597 has merge conflicts (mergeable: CONFLICTING) — resolve them before merging". Pull request 568 (issue 551) had merged into main while this one waited on queued CI. The script recorded no merge entry.

The open finding for the fix pass, which the dialog showed him: merge origin/main into this branch and resolve its two conflicts, both in documents. In `.agent/knowledge/script_reference.md` both sides edited the rows for `validate_adapter.sh`, `project_setting.sh` and `register_project.sh`; each row keeps what both sides say. In `docs/design.md` both sides added change-log rows; the rows of both are kept, main's first, with the line counts redone by the change log's own convention for a merge. A trial merge showed no other conflict: the adapter and the tests merged cleanly. A narrow re-review and a triage follow before the merge question is asked again. The other choice offered was stop.

## Implementation
**Status**: complete
**When**: 2026-11-24 11:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #597 at `ff9ce164`
**Addressed**: merge conflicts with main at `6771dcb` (Checkpoint 2026-11-24 11:42 -05:00, `**After**: merge`, `**Decision**: address`)
**Commits**: ff9ce164 (merge of origin/main, after pull request 568 for issue 551)

### Actions
- [x] Merged origin/main into the branch with a merge commit (no rebase); two conflicts, both in documents, as the trial merge showed.
- [x] `.agent/knowledge/script_reference.md`: main changed only the `project_setting.sh` row of the three. The `validate_adapter.sh` and `register_project.sh` rows are this branch's (the `registration_refused` list; the `register_project.sh` refusal of a listed `--set` key). The `project_setting.sh` row keeps main's `doc <name> <goals|design|roadmap>` subcommand and its `goals`/`design`/`roadmap` keys, and this branch's `source` text (accepted but read by no route, refused at use, the manifest-route text removed). Checked against the merged `project_setting.sh` (`doc` at line 252) and `register_project.sh` (`registration_refused_setting` at line 655).
- [x] `docs/design.md`, change log: main's four #551 rows (1258, 1272, 1274 and the first) first, then this branch's two #569 rows with their own counts (1252, 1262), following the change log's own convention ("their line counts are each side's own file at the time"), then one new row recording this merge in the same words as #551's, with the merged file's count, 1283. The rest of the file was checked: the settings paragraph merged cleanly and reads as one (this branch's `source` and `registration_refused` sentences, main's `goals`, `design` and `roadmap` keys); main's Documentation layers text names no manifest route; nothing needed changing.
- [x] Beyond the conflicts: main's side (work-plans aside) adds no mention of `source=`, the manifest route, `manifest-resolved` or three routes (grep of every file main changed; the one `manifest route` hit, in `test_design_anchors.sh`, is a fixture older than both sides). Main's new keys `goals`, `design` and `roadmap` are read by every type, so no `registration_refused` entry is due. Main did not touch `register_project.sh` or `validate_adapter.sh`; its `_project_registry.sh` and `project_setting.sh` changes (the document lookup, the `doc` subcommand, the three keys in `_PROJECT_FILE_KEYS`) merged cleanly beside this branch's list reader, and `validate_adapter.sh` passes on the merged tree.

### Checks
Each suite run on its own from the worktree after the merge:
- `test_ros2_colcon.sh`: === Results: 1203 passed, 0 failed, 0 skipped ===
- `test_register_project.sh`: test_register_project: 225 passed, 0 failed
- `test_project_file.sh`: === Results: 701 passed, 0 failed ===
- `test_project_registry.sh`: === Results: 425 passed, 0 failed ===
- `test_adapter.sh`: === Results: 258 passed, 0 failed ===
- `test_design_anchors.sh`: test_design_anchors: 82 passed, 0 failed
- `test_skill_paths.sh`: test_skill_paths: 199 passed, 0 failed
- `test_project_documents.sh` (issue 551's suite): test_project_documents: 204 passed, 0 failed

The full pre-commit pass is left to the host; commits made with `SKIP=validate-script-tests` per the dispatched-pass hook rule.

## Local Review
**Status**: complete
**When**: 2026-11-24 11:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #597 at `aa47b9cd`
**Depth**: Deep (reason: convergence check per handoff, scoped to merge commit ff9ce164 since the last reviewed head `860476c`; no cross-model reviewers)
**Must-fix**: 0 | **Suggestions**: 0

Scope: the merge of origin/main (pull request 568, issue 551) into the branch. Checked: `git show --cc ff9ce164`; for every file the branch changed, the branch's change lines against main (d2f489ff..ff9ce164) equal its change lines against the merge base (2a1a1730..e3681845) except in the two conflict files. `script_reference.md`: only the `project_setting.sh` row was touched by both sides; the merged row is main's row with exactly the branch's word change (word diff), and the `validate_adapter.sh` and `register_project.sh` rows are the branch's (main left them as at the base). `docs/design.md`: the branch's change lines apply unchanged, plus one merge row; the convention holds (issue 551's merge commits 5c79c7b1, 7a29404e, 0b9e2fb6 have 1258, 1272, 1274 lines, their rows' counts), the branch's file at e3681845 is 1262, and `wc -l docs/design.md` is 1283. Files both sides touched that merged cleanly (`_project_registry.sh`, `projects.local.example`, `test_project_file.sh`, `docs/roadmap.md`): hunks far apart, both texts present. Main's added lines (work plans aside) reintroduce no manifest-route text; `_rc_refuse_removed_source`, `registration_refused_setting` and their tests are intact. Re-run here: `validate_adapter.sh` (both types all 13 verbs), `test_register_project.sh` 225 passed 0 failed, `test_project_file.sh` 701 passed 0 failed, `test_project_documents.sh` 204 passed 0 failed. Cross-model: skipped (convergence check, per handoff).

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-11-24 12:00 -05:00
**By**: Claude Code (claude-opus-5-5)
**Reviews-read**: 6042973987

**PR**: #597 at `aa47b9c`
**Sources**: 3 (Local Review @ `aa47b9cd` (PR mode, after the merge of origin/main, no findings), Copilot could-not-review notice @ `860476c` (review 6042973987: insufficient quota, no findings), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending (after about 6 minutes of polling: Lint (pre-commit), repos-manifest tests (#267 prototype) (Python 3.10) and (Python 3.14) still in progress; Validate Adapter Contract and Validate Documentation pass)

### Findings
- [x] No open findings. The three low findings of the Local Review @ `860476c` were ruled on in the previous Integrated Review (deferred by the owner to issue 599) and are not carried forward; the `sources` helper lists that entry as stale at this head.

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-24 12:09 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

"Merge (Recommended)"

Asked at the merge checkpoint for pull request 597 (part 2 of 3: the cut of the adapter's manifest route) after the Integrated Review at d53f7f7f with nothing open (its one box, a "No open findings." line, was ticked by the host as a placeholder, not a finding). The dialog gave: main merged into the branch and the two document conflicts resolved, with no code changed; the re-review of that merge approved with no findings; all 10 CI checks passing on the pushed head aa47b9cd, the pull request mergeable and main unmoved since; the three low cold-read findings still deferred to issue 599 as he chose; the outside reviewers (Codex in pre-push rounds 1 and 2 and as the cold read, Gemini failed in rounds 1 and 2, Copilot requested and not available for lack of quota, none on the re-review of the merge); and that the issue stays open with part 3 next. The other choices offered were hold and stop.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 12:10 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan checkpoint after a merge, under run-issue step 13's conditions: the plan is unchanged since its last review, 6530c842 reviewed at 99202142, and it names a part not yet delivered)
**After**: plan
**Decision**: proceed

Pull request 597 (part 2 of 3, the cut of the adapter's manifest route) merged on 2026-11-24. The issue is still open because part 3 is to come. Delivered: part 1 (pull request 571) and part 2 (pull request 597). Not delivered: part 3, the removal of the old reader from `tools/repos-manifest`, which closes the issue. The third Plan Review found part 3 sound enough to follow part 2 and left no finding on it. The owner chose on 2026-11-24 that part 3 comes next ("Part 3 first"). The implement handoff tells the implementer that part 2 as merged differs from the plan's text in places (the fix rounds added the `registration_refused` list, rewrote the refusal message and added the section "A root that sets `source`" to `docs/manifest/design.md`), so every file and line the plan names for part 3 is re-read from this branch.

## Implementation
**Status**: partial
**When**: 2026-11-24 12:33 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-569 at `c59fc837`

Part 3 of 3 (remove the reader). Status is partial only because the CI job rename the coordinator relayed mid-pass (owner's words as relayed: "yes, rename the CI job") was denied by this session's permission classifier when I tried to edit `.github/workflows/validate.yml`; it was not attempted another way and is left to the host. Everything the plan's part 3 lists is done.

- `6d1ae05b` code and tests: deleted `schema.py`, `merge.py`, `selectors.py`, `validate.py`, `emit.py`, `extends.py` (grep: nothing kept imported them; no entry point, Makefile, CI step or `.agent/` script or stub uses them or `resolve --layout`/`--cache-dir`). `cli.py`: old `cmd_resolve`/`cmd_validate` halves, `_load_merged`, `_require_old_flags`, `--layout`, `--cache-dir` and their refusals removed; `ManifestError` from `yamlload`. `manifest.py`: `has_repositories_key` and `read_problem` removed; the earlier-format refusal now ends "…the format of the specification, docs/spec.md". `__init__.py`, `pyproject.toml` description and `yamlload.py` docstring no longer say prototype or two readers. Tests deleted: `test_extends`, `test_extends_safety`, `test_acceptance_p11`, `test_schema`, `test_selectors`, `test_validate`, `test_layout`, `test_untrusted_input`, `fixtures/p11/manifest.yaml` (`p11/expected` kept), and the old cases in `test_cli`, `test_output`, `test_masking`; `fixtures_dir` fixture dropped (no user left). Ported: the CLI backstop test (patches `cli.read_manifest`, resolve and validate; show has its own OSError report), and the YAML-loader checks the new reader had no test for (fixed messages for invalid YAML and constructor failures, integer too large and the 64-bit bound, aliases, deep nesting, repeated top-level key, not UTF-8, read as UTF-8 whatever the locale, unreadable file, symlink loop) into `test_manifest_reading.py`. `test_base_reading` uses an inline earlier-format manifest; `test_url_messages` checks `manifest.py` only. New: `test_a_manifest_in_the_earlier_format_is_refused_naming_the_format` (resolve, show, validate; two shapes; exit 1, exact message, nothing written) and `test_the_options_of_the_earlier_format_are_not_accepted` (exit 2).
- `c59fc837` documents: `docs/prototype.md` deleted, `test_documents.py` exclusion dropped; tool README, spec, design updated; root `docs/fork_parity.md` re-pointed to the project11 fixture in the spec's format.
- Tool roadmap lines now true by reading (text and empty check cells left alone): "The prototype's reader and `docs/prototype.md` are removed" and "The resolver no longer has the package dependency section, roles defined by starting packages, or the cache of parents kept between runs".
- Re-grep (`prototype|manifest-dir|earlier format|resolve_chain` over tools/repos-manifest, .agent, docs, work-plans aside): the remaining "earlier format" hits are the refusal and its tests and docs (current behaviour); tool roadmap line 29 (the line itself); root `docs/roadmap.md` row 4 "resolver prototype landed on PR #268" (history); `.agent/knowledge/host_standing_rules.md:29` (unrelated); `test_cli.py` `--layout manifest-dir` (the not-accepted test). Outside that grep: `.github/workflows/validate.yml:67` "(#267 prototype)" (the denied rename).

Suites run: `pytest tools/repos-manifest/tests` (worktree source, main checkout venv): "1988 passed in 728.75s", no skips; `test_ros2_colcon.sh`: "Results: 1203 passed, 0 failed, 0 skipped"; `test_register_project.sh`: "225 passed, 0 failed"; `test_register_session_root.sh`: "72 passed, 0 failed". Pre-commit hooks ran on the touched files at each commit (SKIP=validate-script-tests). The full pass is left to the host.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 12:39 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: phase-failed
**Decision**: retry
**Phase**: implement

"Leave it out (Recommended)"

Part 3's implement pass wrote its entry partial (db392799) for one reason: the rename of the CI job in `.github/workflows/validate.yml`, which the owner had approved mid-pass ("yes, rename the CI job"), was denied by the session's permission check when the background agent tried the edit (reason given: "Undermining Oversight"). The agent tried no other way, and the host did not make the edit on its behalf. Everything else in part 3 is done and committed (6d1ae05b, c59fc837). Shown this, with the one-line edit quoted, the owner chose to leave the rename out of this part and have a small issue opened for it, which is #601. The other choices offered were that he make the edit himself, or that the host make it as a takeover of the step.

So the retry changes no code: it writes the pass's entry again as complete, with the rename named as left out on the owner's decision and tracked in #601, and the workflow file untouched.

## Implementation
**Status**: complete
**When**: 2026-11-24 12:40 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-569 at `2064f7e4`

Part 3 of 3 (remove the reader), complete. This entry replaces the partial one above (db392799) and restates what part 3 changed in full.

- `6d1ae05b` code and tests: deleted `schema.py`, `merge.py`, `selectors.py`, `validate.py`, `emit.py`, `extends.py` (grep: nothing kept imported them; no entry point, Makefile, CI step or `.agent/` script or stub uses them or `resolve --layout`/`--cache-dir`). `cli.py`: old `cmd_resolve`/`cmd_validate` halves, `_load_merged`, `_require_old_flags`, `--layout`, `--cache-dir` and their refusals removed; `ManifestError` from `yamlload`. `manifest.py`: `has_repositories_key` and `read_problem` removed; the earlier-format refusal now ends "…the format of the specification, docs/spec.md". `__init__.py`, `pyproject.toml` description and `yamlload.py` docstring no longer say prototype or two readers. Tests deleted: `test_extends`, `test_extends_safety`, `test_acceptance_p11`, `test_schema`, `test_selectors`, `test_validate`, `test_layout`, `test_untrusted_input`, `fixtures/p11/manifest.yaml` (`p11/expected` kept), and the old cases in `test_cli`, `test_output`, `test_masking`; `fixtures_dir` fixture dropped (no user left). Ported: the CLI backstop test (patches `cli.read_manifest`, resolve and validate; show has its own OSError report), and the YAML-loader checks the new reader had no test for (fixed messages for invalid YAML and constructor failures, integer too large and the 64-bit bound, aliases, deep nesting, repeated top-level key, not UTF-8, read as UTF-8 whatever the locale, unreadable file, symlink loop) into `test_manifest_reading.py`. `test_base_reading` uses an inline earlier-format manifest; `test_url_messages` checks `manifest.py` only. New: `test_a_manifest_in_the_earlier_format_is_refused_naming_the_format` (resolve, show, validate; two shapes; exit 1, exact message, nothing written) and `test_the_options_of_the_earlier_format_are_not_accepted` (exit 2).
- `c59fc837` documents: `docs/prototype.md` deleted, `test_documents.py` exclusion dropped; tool README, spec, design updated; root `docs/fork_parity.md` re-pointed to the project11 fixture in the spec's format.
- `2064f7e4` (this pass) `docs/fork_parity.md`, the first blocker paragraph: "the ros2_colcon adapter calls nothing in `tools/repos-manifest/`. Needs the manifest placed in a project11 repository and the adapter wired to the resolver." now reads "the ros2_colcon adapter calls the manifest tool only for a root the tool set up (its tool route, issue 503), which `p11-rolling` is not. Needs the manifest placed in a project11 repository and a project11 root set up by the tool." (checked against `.agent/project_types/ros2_colcon/adapter.sh`, whose tool route runs the installed `repos-manifest` for sync, status and build). Table row 1's note already said this and is unchanged.
- Tool roadmap lines now true by reading (text and empty check cells left alone): "The prototype's reader and `docs/prototype.md` are removed" and "The resolver no longer has the package dependency section, roles defined by starting packages, or the cache of parents kept between runs".
- Re-grep (`manifest-dir|prototype` over tools/repos-manifest, .agent, docs, work-plans aside; rerun this pass, same files as the first pass found): tool roadmap line 29 (the line itself); root `docs/roadmap.md` row 4 "resolver prototype landed on PR #268" (history); `.agent/knowledge/host_standing_rules.md:29` (unrelated); `test_cli.py` `--layout manifest-dir` (the not-accepted test). The first pass's wider grep also found "earlier format" hits that are the refusal and its tests and docs (current behaviour). Outside that grep: `.github/workflows/validate.yml:67` "(#267 prototype)".

Suites, run on `c59fc837` by the first pass (worktree source, main checkout venv): `pytest tools/repos-manifest/tests`: "1988 passed in 728.75s", no skips; `test_ros2_colcon.sh`: "Results: 1203 passed, 0 failed, 0 skipped"; `test_register_project.sh`: "225 passed, 0 failed"; `test_register_session_root.sh`: "72 passed, 0 failed". This pass changed one document only and ran `pytest tools/repos-manifest/tests/test_documents.py`: "11 passed in 0.01s". Pre-commit hooks ran on the touched files at each commit (SKIP=validate-script-tests); the full pass is left to the host.

The rename of the CI job in `.github/workflows/validate.yml` is left out of this part. The owner first approved it mid-pass, the session's permission check denied the edit, and on 2026-11-24 the owner decided to leave it out ("Leave it out (Recommended)"); it is tracked in issue 601. The workflow file is untouched on this branch.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 12:44 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-569 at `85fd5b9e`
**Base**: origin/main
**Depth**: Deep (reason: 34 files, +350 -4755; removal of a reader that guarded untrusted manifest input)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 1 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Part 3 of 3 (remove the earlier format's reader). Checked: (a) every `repos_manifest` module imports from this branch's source; `--help` of the tool and of `resolve`, `validate`, `show`, `init`, `sync`, `status`, `build` works, and `resolve`/`validate` no longer list `--layout`/`--cache-dir`; nothing in `src`, `pyproject.toml`, the Makefile's install target, `validate.yml`'s steps or `.agent/` (adapter tool route: `init`, `sync`, `status --json`, `build`; the `test_ros2_colcon.sh`, `test_register_project.sh`, `test_register_session_root.sh` callers and its `.venv/bin/repos-manifest` stub) uses removed code or options; repo-wide grep for the deleted modules, `prototype.md`, `fixtures/p11/manifest`, `manifest-dir`, `cache-dir`, `resolve_chain` finds only the roadmap line and the not-accepted test. (b) Each promise of the spec's "Reading a manifest before using it" has a kept test against the new reader (safe loading, aliases, repeated keys, constructor failures, integer bound, nesting depth, containment, `-` values, transports incl. `ext::`, invisible characters, base cycles, a base in a git repo refused); what has no replacement (dependency check, `manifest-dir` layout, name length caps) belonged to the removed reader only. (c) Refusal run by hand in a scratch directory: `resolve`, `show`, `validate`, `init` exit 1 with one line naming the format and the keys, nothing written; `sync`, `status`, `show` on a system whose recorded manifest was rewritten in the earlier format exit 1 with the same message, `config.yaml` unchanged; a `base:` naming an earlier-format manifest is refused naming the parent. (d) README, spec, design and root `docs/fork_parity.md` match the code. Static: flake8 on the changed Python files, only E203 (Black-compatible, ignored). Tests: 8 files (`test_cli`, `test_project11`, `test_base_reading`, `test_manifest_reading`, `test_masking`, `test_output`, `test_url_messages`, `test_documents`) 668 passed; the full suite was not rerun (the implementer's run on c59fc837: 1988 passed). Cross-model: Codex completed (one finding, dropped: a degenerate earlier-format file with only `layers:`/`roles:` and no repos gets the new reader's own error rather than the earlier-format message); Gemini failed (empty response, a headless Bash call auto-denied).

### Findings
- [x] (suggestion) The earlier-format refusal is tested for `resolve`, `show`, `validate` only; add cases for `init` (nothing written in the directory) and `sync`/`status` on a system whose recorded manifest is in the earlier format — `tools/repos-manifest/tests/test_cli.py:39`
- [x] (suggestion) `packages:`, the fourth key in `_EARLIER_FORMAT_KEYS`, is in no test; add it to the CLI or `test_base_reading.py:279` parametrization — `tools/repos-manifest/src/repos_manifest/manifest.py:34`
- [x] (suggestion) The test comment says a manifest "with no `repositories:` or `base:` key" is refused; the code checks only for a missing `repositories:` (a `base:` plus `repos:` manifest is refused too) — `tools/repos-manifest/tests/test_cli.py:46`
- [x] (suggestion) The rewritten package description and module docstring still name "agent_workspace issue #267"; the tool's own text is not to mention the workspace — `tools/repos-manifest/pyproject.toml:8`, `tools/repos-manifest/src/repos_manifest/__init__.py:6`

## Checkpoint
**Status**: complete
**When**: 2026-11-24 12:45 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the pre-push review at 935189b7 approved with four suggestions, each a few lines; fixing them now is cheaper than carrying them open to the findings checkpoint)
**After**: publish
**Decision**: address

All four suggestions of part 3's round-1 review are fixed before the push: tests of the earlier-format refusal for `init`, `sync` and `status`; a test for the `packages:` key; the test comment that misstates when a manifest is refused; and the package description and module docstring that still name the workspace's issue. The host's full pre-commit pass was not run on this head, since the fix pass changes it. Outside reviewers on round 1: Codex ran, one edge-case point, dropped by the reviewer (a file with only `layers:` or `roles:` gets the new reader's own error); Gemini failed (its headless run denied a tool call).

## Implementation
**Status**: complete
**When**: 2026-11-24 12:48 -05:00
**By**: claude-code (claude-opus-5-5)

**Branch**: feature/issue-569 at `707033b7`
**Addressed**: Local Review (Pre-Push) at `85fd5b9e` (2026-11-24 12:44 -05:00)
**Commits**: 0ef6f8f5, 745899c9, 1aef015d, 707033b7

### Actions
- [x] Earlier-format refusal tested beyond resolve/show/validate: `init` exits 1 with the exact one-line message and changes nothing (`test_init_refusals.py`, via `refused`); `sync` and `status` on a system whose recorded manifest is now in the earlier format exit 1 with the message and change nothing (`test_cli.py`). A `base:` pointing at an earlier-format manifest was already covered (`test_base_reading.py` `test_a_parent_in_the_earlier_format_is_refused`); it now checks the whole message — `tools/repos-manifest/tests/test_cli.py:39`
- [x] `packages:` tested: the CLI refusal (resolve/show/validate) and the parent-refusal test are parametrized over `_EARLIER_FORMAT_KEYS` itself, so a fifth key cannot be added untested — `tools/repos-manifest/src/repos_manifest/manifest.py:34`
- [x] Test comment now says what `Reader.part` does (no `repositories:` plus an earlier-format key, with or without `base:`); a `base:` + `repos:` manifest added to the cases — `tools/repos-manifest/tests/test_cli.py:46`
- [x] Package description and module docstring reworded to say what the tool is, without the workspace's issues #267/#497 or its `tools/` path. Other workspace mentions in `tools/repos-manifest`, not rewritten by this branch and left unchanged: `docs/design.md:954` (the workspace makes linked work trees), `docs/design.md:1730-1731` (the workspace's `validate` runs `status --json`, its issue 503), `tests/test_documents.py` (checks the documents do not name the workspace's adapter). Other "workspace" hits are colcon workspaces — `tools/repos-manifest/pyproject.toml:8`, `tools/repos-manifest/src/repos_manifest/__init__.py:6`

### Checks
- pytest (worktree src on PYTHONPATH, main .venv): `tests/test_cli.py tests/test_init_refusals.py tests/test_base_reading.py tests/test_documents.py` — 150 passed in 3.76s
- flake8 clean on the changed files; black ran in the commit hooks. Full pre-commit pass and the whole tool suite left to the host / CI.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 12:59 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-569 at `dcf2eb42`
**Base**: origin/main
**Depth**: Deep (reason: whole-branch classification, 37 files, +554 -4756; fix-round re-review of round 1's four suggestions)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Part 3 of 3, round 2: the fixes 0ef6f8f5, 745899c9, 1aef015d, 707033b7 for round 1's four suggestions. All four hold as fixed. Checked against the code: the `sync`/`status` test overwrites the very manifest `init` recorded (`make_system` writes `sys.manifest.yaml`, `config.yaml` names `../sys.manifest.yaml`), compares the exact refusal line, and `snapshot(tmp_path)` covers the whole tree (remotes, system, manifest); the `init` test's `refused()` snapshots the whole parent directory and the exact stderr is compared; the parametrized cases' expected `named` strings follow the tuple's order as `manifest.py:412-416` writes them; the rewritten comment matches `Manifest.part` (refused when `repositories:` is missing and any `_EARLIER_FORMAT_KEYS` key is there; the `base:` case passes with `base.yaml` absent, so the base is not read). The new description and docstring are true: nothing outside `tools/repos-manifest/` imports the package's modules (the three `.agent/scripts/tests/*.sh` callers run `python -m repos_manifest.cli` or check `repos_manifest.__file__`). Tests: `test_cli.py`, `test_base_reading.py`, `test_init_refusals.py` 139 passed (worktree `src` on `PYTHONPATH`, main checkout's `.venv`). flake8 (max-line-length 100, E203/W503 ignored) clean on the changed files. A mutation run (refusal switched off in a scratch copy) was denied by the permission system and not run. Outside reviewers: Codex completed, two points: the degenerate `layers:`/`roles:`-only file (dropped again, as in round 1) and the README sentence below (kept); Gemini failed (headless run auto-denied a tool call). Claude adversarial subagent: no must-fix; the `packages:` point below kept; a point that "for ROS 2 projects" narrows the description dropped (the tool is built for them; the text is not false).

### Findings
- [x] (suggestion) `packages:` is tested only through `_EARLIER_FORMAT_KEYS` imported from the code under test, so removing it from the tuple fails no test; add one literal `packages:` case or assert the tuple's four keys — `tools/repos-manifest/tests/test_cli.py:77`
- [x] (suggestion) "Every command reads a manifest" is not true of `build`, which reads the saved resolution (`cmd_build` calls `run_build` only); say "every command that reads a manifest" — `tools/repos-manifest/README.md:214`

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:00 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 2 at e0f68dcc approved with two suggestions, each one line; left open they would reach the owner at the findings checkpoint for no gain)
**After**: publish
**Decision**: address

Both round-2 suggestions are fixed before the push: a literal check that `packages:` (and each of the four keys of the earlier format) is refused, so removing a key from the tuple fails a test; and the README sentence "Every command reads a manifest", which is not true of `build`. Outside reviewers on round 2: Codex ran, and the README point is its; Gemini failed (its headless run denied a tool call).

## Implementation
**Status**: complete
**When**: 2026-11-24 13:20 -05:00
**By**: claude-code (claude-sonnet-5-5)

**Branch**: feature/issue-569 at `1e95b622`
**Addressed**: Local Review (Pre-Push) at `dcf2eb42` (2026-11-24 12:59 -05:00)
**Commits**: 71898ea8, 1e95b622

### Actions
- [x] `packages:` literal coverage: new test_the_earlier_format_keys_are_the_four_the_format_had asserts the tuple equals {repos, extends, optional_layers, packages} — `tools/repos-manifest/tests/test_cli.py:77`
- [x] "Every command reads a manifest" now "Every command that reads a manifest reads it only in the format of ..."; same claim fixed in `tools/repos-manifest/docs/design.md:2175` (spec.md has none) — `tools/repos-manifest/README.md:214`

Checks: pytest test_cli.py + test_documents.py: 60 passed. Full pre-commit pass left to the host.
