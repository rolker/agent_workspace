---
issue: 499
---

# Issue #499 — repos-manifest: show prints what a manifest comes to for a machine

## Issue Review
**Status**: complete
**When**: 2026-11-20 11:26 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #499

### Scope Assessment

**Well-scoped?** Yes, with two corrections. One PR can hold it, but the text predates the code in three places: (1) it names `tools/ros-manifest/`, now `tools/repos-manifest/` (design: `tools/repos-manifest/docs/design.md#show`); (2) it asks for "any of the three location forms (`--manifest-ref`, `--manifest-path`)", but `tools/repos-manifest/src/repos_manifest/base.py` and `manifest.py` read a location given as a path only ("not yet an" URL or git form), and `cli.py` has no `--manifest-ref` or `--manifest-path`; so `show` can take a path now and the other forms come with whatever issue builds them; (3) `show <manifest>` takes the manifest positionally, as `init` does, while `resolve` and `validate` take `--manifest`.
**Right repo?** Yes: workspace repo, part `tools/repos-manifest` (ADR-0022).
**Serves**: the roadmap line "`show` prints what a manifest comes to for a machine, with what is left out and why" in `tools/repos-manifest/docs/roadmap.md`; the workspace goal is the manifest design in `docs/manifest/design.md` (the session shows what a manifest comes to before fetching) and the roadmap line in `docs/manifest/roadmap.md` ("the tool has the commands the adapter calls").
**Design picture?** No change. `tools/repos-manifest/docs/design.md#show` already specifies the output. The design sentence in "init" ("prints a summary until `show` is built, and then what `show` prints") means this issue should also make `init` print `show`'s output, or hand that to a follow-up; see recommendations.
**Dependencies**: none blocking. #498 (resolver reads the format) and #500 (`init`/`sync`) are merged in the tree. The no-argument form depends on `init`, which now exists, so it can be built here (see recommendations). The URL and git-ref location forms and `fetch_from` (#519) are outside this issue.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | OK | `show` is in the design; update `docs/manifest/design.md` line ~234 (lists `show` as not built) and the roadmap lines when it lands |
| Only what's needed | OK | A person-readable command; scripts form excluded |
| Verify before claiming | Watch | Acceptance wants a run on the project11 draft manifest pasted in the PR. The draft lives in ~/project11, which the owner has asked not to touch while a port is under way. Use `tools/repos-manifest/tests/fixtures/project11/project11.manifest.yaml` (used by `tests/test_project11.py` for all six role/distro pairs) and say so in the PR |
| Put each thing at the level it applies to | OK | |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0022 (a part owns its inside) | Yes | Work stays inside the part; the root's design changes only for the "not built yet" list in `docs/manifest/design.md` |
| ADR-0017 (design is the current picture) | Yes | Roadmap rows in both roadmaps tick when this lands |
| ADR-0013 (progress timeline) | Yes | Entry recorded here |

### Consequences

- Resolved data does not carry what `show` needs. `selection.Selected` has no source manifest, and `Resolved` has no left-out list or reasons (group off, not on this distro). `merge.py` has per-entry `source` and `sources` provenance, but `combine.merge_parts` produces a `Manifest` whose `Repo` drops it. So this is more than a printer: the resolver must expose provenance and the left-out reasons, with tests of its own.
- Masking: print URLs through `masking.mask_url` as `init.summary` does (design "Masking"); the sketch's `git@github.com:...` has no password and prints as is.
- `init.summary` is the existing printer to replace or reuse; keep `init` output in step (`tests/test_init.py` pins the old text).
- Tick the "`show` prints ..." line in `tools/repos-manifest/docs/roadmap.md` and the "not built yet" list in `docs/manifest/design.md`; the CLI help and a README mention if one lists commands.
- `validate` already prints a role/distro table; leave it.

### Recommendations

- Reword scope to the code as it is: `tools/repos-manifest`, the manifest as a positional path, and the URL and git-ref forms left for the issue that builds the reader for them (name it in the PR).
- Build the no-argument form here: `init` (#500) is in, so `show` inside a system directory should use what `config.yaml` records; if that proves large, say so in the PR and split it.
- Extend the resolver to carry each entry's source manifest and a left-out list with reasons ("group X is off", "not on DISTRO") as a tested step before the printer; decide the layout in the plan.
- Decide in the plan whether `init` switches to `show`'s output in this PR (the design says it should once `show` exists) or in a follow-up, and tick the roadmap accordingly.
- For the acceptance run use the in-repo project11 fixture for robot, operator and developer on jazzy and rolling, not ~/project11.

### Actions
- [ ] Acceptance wants a run on the project11 draft manifest pasted in the PR. The draft lives in ~/project11, which the owner has asked not to touch while a port is under way. Use `tools/repos-manifest/tests/fixtures/project11/project11.manifest.yaml` (used by `tests/test_project11.py` for all six role/distro pairs) and say so in the PR
- [ ] Reword scope to the code as it is: `tools/repos-manifest`, the manifest as a positional path, and the URL and git-ref forms left for the issue that builds the reader for them (name it in the PR).
- [ ] Build the no-argument form here: `init` (#500) is in, so `show` inside a system directory should use what `config.yaml` records; if that proves large, say so in the PR and split it.
- [ ] Extend the resolver to carry each entry's source manifest and a left-out list with reasons ("group X is off", "not on DISTRO") as a tested step before the printer; decide the layout in the plan.
- [ ] Decide in the plan whether `init` switches to `show`'s output in this PR (the design says it should once `show` exists) or in a follow-up, and tick the roadmap accordingly.
- [ ] For the acceptance run use the in-repo project11 fixture for robot, operator and developer on jazzy and rolling, not ~/project11.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 11:27 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review's actions are mechanism questions for the plan; none changes what the issue is for)
**After**: issue-actions
**Decision**: proceed

Read the Issue Review at b5a7f3cc: verdict proceed to plan-task, no question for the owner. Its open actions (the manifest as a positional path like `init`, the URL and git-ref location forms left to another issue because the reader takes a local path only, the no-argument form, the resolver carrying where each entry came from and what was left out, whether `init` switches to `show`'s output in this pull request, the acceptance run on the in-repo project11 fixture rather than ~/project11) go to the plan, and the owner sees the plan's answers at the plan checkpoint.

## Plan Authored
**Status**: complete
**When**: 2026-11-20 11:29 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-499/plan.md` at `fc5e1c6c`

Six steps in one pull request: the resolver carries each entry's source and the left-out repos with reasons (tested first), a pure renderer following the design's sketch, the `show` command with the no-argument system form, `init` switching to the same output, the acceptance run on the in-repo project11 fixture, and the design, roadmap and README updates. The eight decisions for the owner's veto are listed in the plan.

## Plan Review
**Status**: complete
**When**: 2026-11-20 11:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #499 — repos-manifest: `show` prints what a manifest comes to for a machine
**Plan**: `.agent/work-plans/issue-499/plan.md` at `fc5e1c6c`
**Branch**: `feature/issue-499`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR; resolver fields, a renderer, one command, `init` switch, docs. ~460 lines is within one PR. |
| Issue alignment | Needs work | Covers every issue-review action (positional path, URL/git-ref forms left out and named, no-argument form, resolver provenance first, `init` decision, fixture not ~/project11). Serves line as written: "Goal: the manifest design's step 'the session shows what a manifest comes to before fetching' (`README.md#workspace-goals`, the manifest design in `docs/manifest/design.md`); design section `tools/repos-manifest/docs/design.md#show`, roadmap row ...". The design anchor exists; no section name under `README.md#workspace-goals` is named (finding 1). |
| File targeting | Needs work | Code claims checked and true: `Repo` has no source, `combine._repo` takes only `given` (needs `parts[first[key]].source` passed in), `selection.resolve` skips left-out repos silently, `check_role_and_distro` returns the groups on, `find_system`/`read_config`/`one_distro_for` exist, `read_manifest` refuses `://`. Wrong test module for chains (finding 2); `test_init_refusals.py` pins no summary text (finding 5). |
| Consequences | Needs work | `init`'s per-layer `src/` paths and the design's "init" paragraph that describes them (finding 3); repo-level `absent` with no distros (finding 4); root list line also stale for `build` (finding 7). |
| Principle alignment | Good | Tests before printer, masking reused, prior art named, design updates in the same change. |
| ADR compliance | Good | ADR-0022 (inside the part, one root line), ADR-0017 (step 6), ADR-0013. |
| ROS conventions | N/A | Workspace tool plan. |

### Findings

1. **[Issue alignment]** (minor) — `## Serves` names no goal section of `README.md#workspace-goals` (sections: Quality of the work, Trust control and information, Flexibility, Modular, Light touch on projects, Easy to use, The long view). Name one (likely "Trust, control and information": the person sees what a manifest comes to before fetching) alongside the part's own roadmap row.
2. **[File targeting]** (medium) — Step 1 puts chain/provenance tests in `tests/test_extends.py`, but that module tests the prototype's `extends`/`merge_chain` reader. The new format's `base` chains are tested in `tests/test_base_merge.py` (uses `base.load_manifest` and `selection.resolve`). Put the source-of-a-repo tests there.
3. **[Consequences]** (medium) — `init.summary` today prints each layer's `src/` directory (`layer_src_parts`, differs flat vs `--distro-dirs`), and `tools/repos-manifest/docs/design.md` lines 213-216 describe exactly that summary. The sketch names layers, not directories, so step 4 drops where each layer is cloned and repeats the manifest/base/role head once per distro. The plan only removes the clause "until `show` is built"; the whole paragraph needs rewriting, and the plan should say whether `init` keeps the `src/` paths (e.g. a line per layer after `show`'s output) or drops them deliberately.
4. **[Consequences]** (minor) — A repo with `absent: true` in a manifest without `distros:` is always left out; `not_on_distro(None)` would print "not on None". Give that case its own words (e.g. "absent, and no distro adds it") and a test.
5. **[File targeting]** (minor) — Step 4 says `test_init_refusals.py` pins the old summary text; it does not (only `tests/test_init.py` lines 183-184 and 327). Drop it from the list or say what it pins.
6. **[Consequences / #502 overlap]** (minor) — `cli.py` edits are local enough to merge with #502: `cmd_show` and the parser before `init`'s, and the `from .show` import sits apart from a `from .status` import (`.signals` between). The docs are not: the design's "Not built yet" line (`` `add-distro`, `show`, `status`, ``), `docs/manifest/design.md` line 234, the end of "What is built" and README "What works today" will be edited at the same lines by both drives, so the second to land gets a conflict there. Trivial to resolve; place `show`'s "What is built" and README paragraphs next to the `init`/`sync` paragraph rather than at the end, and expect the list-line conflict.
7. **[Consequences]** (minor) — `docs/manifest/design.md` line 234 also lists `build` as not built, though `build.py` is in and the tool roadmap row is checked. Since this plan edits the line, drop `build` too (or note it is left for another change).
8. **[File targeting]** (minor) — `Repo` and `Selected` are built positionally (`tests/test_update.py:511` builds `Selected` with five positional args); the new `source` fields must go last with a default, as the plan's "defaults keep them working" implies. Say so explicitly. Also the plan puts the system-directory lookup in `show.py` while calling it a pure renderer; keep the lookup in `cli.py` or a separate function so `render` stays pure for `init`.
9. **[Issue alignment]** (minor) — The project11 fixture has no `base`, so the six acceptance runs never show a `base` line or `from <manifest>`; the built-manifest whole-string test is the only cover for them. Note that in the PR next to the pasted run.

### Summary

The plan answers every issue-review action and its claims about the code hold. It needs small corrections before implementation: the chain tests go to the wrong module, `init`'s switch drops the `src/` paths the design currently promises without saying so, the Serves line names no workspace goal, and an edge case of the left-out reason has no words.

### Recommended Actions

- [ ] Name a `README.md#workspace-goals` section in `## Serves`
- [ ] Move step 1's chain/source tests from `tests/test_extends.py` to `tests/test_base_merge.py`
- [ ] Decide whether `init` keeps each layer's `src/` path after `show`'s output; rewrite the design's "init" summary paragraph (lines ~213-216) to match, not only its first clause
- [ ] Give repo-level `absent` without distros its own left-out words and a test
- [ ] Correct the `test_init_refusals.py` claim
- [ ] Place doc paragraphs to reduce conflict with #502 and expect the shared list-line conflicts
- [ ] Drop stale `build` from `docs/manifest/design.md` line 234, or note it
- [ ] State that `source` fields go last with defaults, and keep `render` free of the system lookup

## Checkpoint
**Status**: complete
**When**: 2026-11-20 11:31 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work and each of its nine findings is a mechanism fix to the plan)
**After**: plan
**Decision**: revise

Read the Plan Review at f15db74e (verdict needs-work, no question for the owner). All nine findings go back to plan-task. Host decision on finding 3, listed for the owner's veto: `init` keeps printing each layer's `src/` directory. It prints what `show` prints, then the directories it will create, so nothing a person sees today is lost; the manifest, base and role lines are printed once, not once per distro; the design paragraph on `init`'s summary is rewritten whole. Undoing it is a change to `init`'s printed text and its tests.

## Plan Authored
**Status**: complete
**When**: 2026-11-20 11:33 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-499/plan.md` at `15afac5e`

Revision answering the nine findings of the plan review: the `Serves` line names "Trust, control and information"; chain tests move to `test_base_merge.py`; `init` keeps each layer's `src/` directory after `show`'s output with the head printed once and the design paragraph rewritten whole (host decision, listed with its undo cost); repo-level `absent` with no distros gets its own words; `test_init_refusals.py` dropped; `show`'s doc paragraphs sit next to the `init`/`sync` ones; `build` dropped from the root's stale list line; new `source` fields go last with defaults and `render` stays pure; the fixture's lack of a `base` is noted for the PR.

## Plan Review
**Status**: complete
**When**: 2026-11-20 11:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #499 — repos-manifest: `show` prints what a manifest comes to for a machine
**Plan**: `.agent/work-plans/issue-499/plan.md` at `15afac5e`
**Branch**: `feature/issue-499`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR: resolver fields, a pure renderer, one command, `init`'s summary, docs. |
| Issue alignment | Good | All issue-review actions covered. Serves: "Goal: 'Trust, control and information' (`README.md#workspace-goals`): the person sees what a manifest comes to before anything is fetched (step 3 of the manifest design, `docs/manifest/design.md`); design section `tools/repos-manifest/docs/design.md#show`, roadmap row '`show` prints what a manifest comes to for a machine'." The goal section and the `#show` anchor both exist. |
| File targeting | Good | Checked against the code: `Repo` is built only in `combine._repo` (a manifest with no `base` also goes through `merge_parts`, so every repo gets a source); `parts[first[key]].source` is what fills it; leaf sources are the location as given (`read_manifest(..., source=location)`) and base sources are the same strings `Resolved.bases` holds, so `chain` compares like with like; `Selected` is built positionally only at `selection.py:120` and `tests/test_update.py:511`; `Resolved` only at `selection.py:126`; the only tests pinning `init.summary` text are `test_init.py` 183-184 and 327 (the `Layout:` lines at 99, 127, 186 stay). Two leftovers in the text (findings 1, 2). |
| Consequences | Good | `init`'s `src/` paths kept per the checkpoint; design "init" paragraph rewritten whole; root list line drops `show` and stale `build`; #502 overlap placed and expected. One gap in `init`'s new text for a manifest with no distros (finding 3). |
| Principle alignment | Good | Tests before printer, sketch pinned whole, masking reused, prior art named, design and roadmaps in the same change. |
| ADR compliance | Good | ADR-0022 (inside the part, one root line), ADR-0017 (step 6), ADR-0013. |
| ROS conventions | N/A | Workspace tool plan. |

### First review's nine findings

1. Serves names a goal section: answered ("Trust, control and information").
2. Chain tests in `test_base_merge.py`: answered in step 1; the Files table still lists `test_extends.py` (finding 1 below).
3. `init`'s `src/` paths and the design paragraph: answered (step 4, Files table, host decision row); the Design Picture section still says only the clause changes (finding 2 below).
4. `absent` with no `distros:`: answered (`absent_no_distro`, its words and a test). The logic holds against `_version_on`: with no distro the entry is never consulted, so `repo.absent` alone decides.
5. `test_init_refusals.py`: answered (checked, not touched).
6. #502 overlap: answered (placement next to `init`/`sync`, list-line conflict expected).
7. Stale `build` on the root list line: answered.
8. `source` last with default, lookup out of `show.py`: answered (step 1, step 3).
9. Fixture has no `base`: answered (step 5, PR note).

### Findings

1. **[File targeting]** (minor) — The Files to Change row for tests still names `test_extends.py`, which step 1 now says is not used. Drop it from the row.
2. **[Principle alignment / Keep one current design]** (minor) — `## Design Picture` says "init" changes only in "the 'until `show` is built' clause"; step 4 and the Files table rewrite the paragraph whole. Make the section say the same.
3. **[Consequences]** (minor) — Step 4 prints "for each planned distro a `distro <name>` line". A manifest without `distros:` plans one distro `None` (the case `test_init.py:327` runs). Say what prints there: no `distro` line, or `distro (none)`, and pin it in the rewritten test at line 327.

### Summary

The revision answers all nine findings, and the new parts hold against the code: `render_head` once plus `render_body` per distro fits `init` (role and groups are the same for every distro it resolves), the provenance comparison uses consistent source names, and `absent_no_distro` matches the selection rules. Three small text fixes remain, none blocking; ready for implementation.

### Recommended Actions

- [ ] Drop `test_extends.py` from the Files to Change test row
- [ ] Align `## Design Picture` with the whole rewrite of the "init" paragraph
- [ ] Say what `init` prints in place of the `distro <name>` line when the manifest has no distros, and pin it at `test_init.py:327`

## Checkpoint
**Status**: complete
**When**: 2026-11-20 11:35 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second plan review finds the plan ready to implement, with three minor wording points and no question for the owner)
**After**: plan
**Decision**: proceed

Read the Plan Review at db66afbe: all nine findings of the first review are answered and the revision's new parts hold against the code. Its three minor findings go to the implementer in the handoff rather than a third plan round: the Files to Change row that still names `test_extends.py` is read as `test_base_merge.py`; the `init` summary paragraph of the design is rewritten whole, as step 4 says; and, a host decision listed for the owner's veto, for a manifest with no `distros:` `init` leaves the `distro` line out rather than printing a placeholder, pinned in the test at `test_init.py:327`. Undoing that is one line of output and its test.

## Implementation
**Status**: complete
**When**: 2026-11-20 12:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-499 at `455ec748`

Seven commits, in the plan's order:

- `e0dcf7b6` Resolver: `Repo.source` and `Selected.source` (last, default `""`), filled in `combine._repo` from the manifest where the key first appears; `Resolved.groups_on`, `Resolved.left_out` (`LeftOut`: key, layer, reason `group_off` / `not_on_distro` / `absent_no_distro`, the repo's groups, the distro) and the `chain` property. Tests in `tests/test_selection.py` and `tests/test_base_merge.py` (the Files table's `test_extends.py` read as `test_base_merge.py`, per the checkpoint).
- `a4f6b93b` `show.py`: pure `render_head`, `render_body`, `render`; the sketch pinned whole in `tests/test_show.py`, plus no roles/distros (`(none)`, `(unnamed layer)`, "absent, and no distro adds it"), several groups off, a masked password URL.
- `97faf793` `show` command in `cli.py` (subparser before `init`'s); the system-directory form in `_show_in_system` (`find_system`, `read_config`, `one_distro_for`; `--role`/`--with` refused; a manifest error names where its path is recorded). Tests in `tests/test_cli.py` and a new `tests/test_show_system.py`.
- `146ea892` `init.summary`: `render_head` once, then per distro a `distro <name>` line (left out when the manifest has no `distros:`, per the checkpoint), `render_body` and a `will create` list of each layer's `src/`, then the `Layout:` line. `tests/test_init.py` (the distro-dirs test and the one at line 327) rewritten; the latter pins the no-distro summary whole.
- `e886a8f2` `tests/test_project11.py`: `show` for the six role/distro pairs succeeds, the three roles differ, and each lists as many repos as `validate` counts (20, 30, 44).
- `8d68d15e` Docs: tool design "show" (left-out words, source rule, system form), the "init" summary paragraph rewritten whole (checkpoint point 2), a `show` paragraph in "What is built" next to `init`/`sync`/`build`, `show` out of "Not built yet"; README paragraph next to `init`/`sync`, `show` in the masking sentence and the example block; tool roadmap row checked with `file-exists src/repos_manifest/show.py`; `docs/manifest/design.md` not-built list drops `show` and the stale `build`. `docs/manifest/roadmap.md` line 28 left open, as the plan says.
- `455ec748` Rename of a local in `show.py` (`url_column` to `from_indent`): `tests/test_url_messages.py` read the name as a URL formatted into text.

Departures from the plan: the sketch's `base` line shows a URL, a ref and a path; this version prints the base's path only, since only local paths are read. "Masking" in the design has no heading of its own, so the "show" section points at "sync" for the masking rules. The `.venv` had no pytest; it was installed there with `.venv/bin/pip install pytest` (no bare pip), and tests ran with `PYTHONPATH=src` so the worktree's code was used rather than the main checkout's editable install.

Tests: the whole tool suite, `PYTHONPATH=src .venv/bin/python -m pytest tests` from `tools/repos-manifest`: `1796 passed in 551.19s (0:09:11)` (the run before the rename had `1 failed, 1795 passed`, the `test_url_messages.py[show.py]` case, fixed in `455ec748`). No script under `.agent/scripts/` and no skill or knowledge text changed, so no shell suite applies. The full pre-commit pass was left to the host.

Acceptance run on the in-repo fixture, not `~/project11` (nothing was read, written or run there). The fixture has no `base`, so no `base` line or `from <manifest>` appears; `tests/test_show.py`'s whole-string test covers both. All six pairs (robot, operator, developer on jazzy and rolling) exit 0. One run:

```
$ PYTHONPATH=src .venv/bin/python -m repos_manifest.cli show tests/fixtures/project11/project11.manifest.yaml --role robot --distro jazzy
manifest  tests/fixtures/project11/project11.manifest.yaml
role      robot    groups on: (none)    distro: jazzy

underlay
  ros2launch_gui                jazzy       https://github.com/rolker/ros2launch_gui.git
  ros2launch_session            jazzy       https://github.com/rolker/ros2launch_session.git
  geographic_info               ros2        https://github.com/ros-geographic-info/geographic_info.git
  nmea_navsat_driver            add_pashr   https://github.com/rolker/nmea_navsat_driver.git
core
  manda_coverage                jazzy       https://github.com/rolker/manda_coverage.git
  marine_ais                    jazzy       https://github.com/rolker/marine_ais.git
  marine_control                jazzy       https://github.com/rolker/marine_control.git
  udp_bridge                    jazzy       https://github.com/rolker/udp_bridge.git
  unh_marine_navigation         jazzy       https://github.com/rolker/unh_marine_navigation.git
  s57_tools                     jazzy       https://github.com/rolker/s57_tools.git
  unh_marine_autonomy           jazzy       https://github.com/rolker/unh_marine_autonomy.git
platforms
  mru_transform                 jazzy       https://github.com/rolker/mru_transform.git
site
  site_config                   jazzy       git@github.com:example/site_config.git   optional
sensors
  unh_marine_radar              jazzy       https://github.com/rolker/unh_marine_radar.git
  cube_bathymetry               jazzy       https://github.com/rolker/cube_bathymetry.git
  unh_marine_perception         jazzy       https://github.com/rolker/unh_marine_perception.git
  marine_tools                  jazzy       https://github.com/rolker/marine_tools.git
  imagenex_deltat               jazzy       https://github.com/rolker/imagenex_deltat.git
  starlink_stats_ros            jazzy       https://github.com/rolker/starlink_stats_ros.git
  ros2_network_monitor          jazzy       https://github.com/rolker/ros2_network_monitor.git

left out
  audio_common                  group ui is off
  detection_visualizer          group ui is off
  norbit                        group sonar-drivers is off
  ros2sonic                     group sonar-drivers is off
  vrx                           group simulation is off
  ben_project11                 group ben-hardware is off
  ben_description               group ben-hardware is off
  seafloor_echoboat_project11   group echoboat-hardware is off
  unh_echoboats_project11       group unh-echoboat-hardware is off
  lr30_project11                group lr30-hardware is off
  drix_description              group drix-hardware is off
  mobile_lab                    group mobile-lab is off
  edgetech_sonar                group sonar-drivers is off
  ben_gazebo                    group simulation is off
  drix_gazebo                   group simulation is off
  unh_marine_simulation         group simulation is off
  camp                          group ui is off
  rqt_operator_tools            group ui is off
  rqt_marine_radar              group ui is off
  rqt_udp_bridge                group ui is off
  rviz_sonar_image              group ui is off
  marine_perception_tools       group ui is off
  marine_colormap               group ui is off
  marine_sonar_widgets          group ui is off
```

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 12:09 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-499 at `67fcacd7`
**Base**: main
**Depth**: Deep (reason: about 1300 lines across 19 files, resolver data model and CLI)
**Must-fix**: 1 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) A later manifest may change a repo's `url` (docs/spec.md:390-391), but `Repo.source` stays the manifest where the key first appears. `show` then prints that later URL with no `from` line, and the design and comment claim the source "gave its `type` and `url`". Track which manifest set the url, or narrow the claim and test the case — `tools/repos-manifest/docs/design.md:510`, `tools/repos-manifest/src/repos_manifest/manifest.py:99`, `tools/repos-manifest/src/repos_manifest/show.py:518`
- [x] (suggestion) `show --role X` outside a system directory gives the in-system refusal, not "no manifest given, and no system directory"; check `find_system` first — `tools/repos-manifest/src/repos_manifest/cli.py:190`
- [x] (suggestion) Path labels are inconsistent: `base` lines print the real path, while the manifest and `from` lines print the label as given. Inside a system directory the labels are relative to the system directory, not to cwd, and the output does not say so — `tools/repos-manifest/src/repos_manifest/show.py:471`
- [x] (suggestion) Manifest and base path labels are printed with control characters and newlines left as they are (masking does not escape them); escape them on display — `tools/repos-manifest/src/repos_manifest/show.py:471`
- [x] (suggestion) No test covers the refusal of `--distro ""` — `tools/repos-manifest/src/repos_manifest/cli.py:197`
- [x] (suggestion) The "show" section says no-argument `show` "also shows the effect of `fetch_from`", which is not built; mark it as planned there — `tools/repos-manifest/docs/design.md:521`

## Implementation
**Status**: complete
**When**: 2026-11-20 12:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-499 at `a9ef9586`
**Addressed**: Local Review (Pre-Push) at `67fcacd7` (2026-11-20 12:09 -05:00)
**Commits**: e1799037, bde7beb1, c8645784, 2252e647, 9230e6b7, ad2fd187, a9ef9586

### Actions
- [x] (must-fix) A repo's `source` is now the manifest that gave the `url` in effect: where the key first appears, or the last manifest in reading order that changed the url. A later manifest that changes only `version` or `type` (the spec lets a later manifest change any key) leaves it, and the design's "show" section says so, including that the version printed may come from a later manifest than the one named. Tests on a chain where a later manifest points a repo at a fork, on a diamond, and on show's `from` line — `tools/repos-manifest/src/repos_manifest/combine.py:132`, `tools/repos-manifest/tests/test_base_merge.py`, `tools/repos-manifest/tests/test_show.py` (e1799037)
- [x] (suggestion) `show` with no manifest checks for the system directory first, so `--role`/`--with` outside one get "no manifest given, and no system directory"; tested — `tools/repos-manifest/src/repos_manifest/cli.py:188`, `tools/repos-manifest/tests/test_show_system.py` (bde7beb1)
- [x] (suggestion) Paths: inside a system directory with no argument, the recorded manifest is printed as an absolute path with links followed, as the bases are; a manifest given on the command line is printed as given. Each manifest prints the same way on every line that names it. The design says which, and a test runs show from a directory below the system with a base elsewhere — `tools/repos-manifest/src/repos_manifest/cli.py`, `tools/repos-manifest/docs/design.md` "show", `tools/repos-manifest/tests/test_show_system.py` (9230e6b7)
- [x] (suggestion) Control characters: `show.shown_path` escapes a control or invisible character (`\xXX`/`\uXXXX`), a non-UTF-8 byte (`\xXX`) and a backslash (doubled) on the manifest, base and from lines, and `init` uses it for the system directory in its question. A manifest path with such a character is already refused by `init` before it prints (the resolved files' head comment check), so `init`'s only such path is the question's. Tests on `shown_path`, on show with a base in an oddly named directory, and on init's question — `tools/repos-manifest/src/repos_manifest/show.py`, `tools/repos-manifest/src/repos_manifest/init.py`, `tools/repos-manifest/tests/test_show.py`, `tools/repos-manifest/tests/test_init_refusals.py` (ad2fd187)
- [x] (suggestion) Test that `show --distro ""` is refused, with and without a manifest — `tools/repos-manifest/tests/test_cli.py` (c8645784)
- [x] (suggestion) The design's "show" section says showing the effect of `fetch_from` is planned, not built — `tools/repos-manifest/docs/design.md` (2252e647)

### Host decisions (recorded as the host's; the owner may veto)
1. Fix the must-fix by tracking the manifest that gave the url, not by narrowing the claim; check the spec on `type`/`version` and claim only what the code does; test a chain and a diamond.
2. Print each manifest path one way; inside a system directory print paths that open from where the person is; the design and a test say which (chosen: absolute, links followed).
3. Escape control characters where `show` and `init` print a path, with a test.
4. `show --role X` outside a system directory gets the no-system refusal; test `--distro ""`; the design marks `fetch_from` in show as planned.

### Checks
- `tests/test_base_merge.py tests/test_show.py tests/test_selection.py`: 78 passed (after the must-fix)
- `tests/test_show.py tests/test_show_system.py tests/test_init.py tests/test_init_refusals.py tests/test_cli.py tests/test_url_messages.py`: 160 passed
- Whole tool suite (`PYTHONPATH=src .venv/bin/python -m pytest tests`, at ad2fd187; a9ef9586 after it only rewraps design text): 1812 passed in 547.49s (0:09:07)
- Every commit with `SKIP=validate-script-tests` (issue #465 rule); every other hook ran. The full pre-commit pass is left to the host. Nothing under ~/project11 was read, written or run.
- a9ef9586 also rewraps one long line of the "show" section left by the must-fix edit.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 12:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-499 at `c21b92cb`
**Base**: main
**Depth**: Deep (reason: about 1500 lines across 20 files, resolver data model and CLI; fix round classified on the whole diff)
**Must-fix**: 0 | **Suggestions**: 5
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

All six round-1 findings are fixed, checked by hand on scratch manifests: a chain changing only the version (no `from`), only the url (`from` the fork's manifest), the url back to the original (`from` the manifest that restored it), and a diamond; `show` with no argument from a subdirectory reached through a symlink prints absolute real paths; `--role`/`--with` outside a system get the no-system refusal; `--distro ""` is refused with and without a manifest. Targeted tests (test_show, test_show_system, test_cli, test_base_merge, test_selection, test_init, test_init_refusals): 170 passed; flake8 clean on the changed Python files.

### Findings
- [x] (suggestion) A later manifest that restates a repo's url unchanged moves its source (the merge loop records every manifest that gives `url`), so `show` prints `from <that manifest>`; the design and comments say "changed its url". Keep the source when the value is equal, or say "gave", and test a restated url — `tools/repos-manifest/src/repos_manifest/combine.py:66`, `tools/repos-manifest/docs/design.md:513`
- [x] (suggestion) `shown_path` writes a code point above U+FFFF with five hex digits (`1`), which reads the same as U+E000 followed by `1`; use `\UXXXXXXXX` there and fix the design's "`\uXXXX` above" — `tools/repos-manifest/src/repos_manifest/show.py:39`, `tools/repos-manifest/docs/design.md:523`
- [x] (suggestion) An unsafe character U+0080–U+00FF and the undecodable byte of the same value print alike (`a\x85b` for U+0085 and for byte 0x85), so two different paths can look the same; give bytes and characters different forms (e.g. `\u0085` for the character) — `tools/repos-manifest/src/repos_manifest/show.py:34`
- [x] (suggestion) In a system directory `show` opens the realpath of the recorded manifest, not the recorded path `sync` opens: a recorded `missing/../pub/m.yaml` reads in `show` and is "not found" in `sync`. Open the recorded path and print the canonical one; use `system.is_url` instead of the bare `"://"` test — `tools/repos-manifest/src/repos_manifest/cli.py:210`
- [x] (suggestion) The new no-system refusal prints `cwd` unescaped, so a directory name with a newline splits the message; pass it through `shown_path` (the tool's general `ERROR:` path, unchanged from main, has the same gap) — `tools/repos-manifest/src/repos_manifest/cli.py:194`

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:32 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review approved with five suggestions; four are real defects with small fixes, two of them sentences in the design that are false, and the quality standard says to fix them while they are in reach)
**After**: publish
**Decision**: address

Read the Local Review (Pre-Push) at c6fb2f5f (round 2, approved, no must-fix, five suggestions, each reproduced by the reviewer). All five are addressed before publishing: a manifest that repeats a repo's url unchanged must not move its source (keep the source when the value is equal, and test it); a character above U+FFFF is written so it cannot be read as another path, and the design's sentence corrected; an unsafe character and a raw byte of the same value print differently; inside a system directory `show` opens the recorded manifest path as `sync` does and prints the canonical one, using `system.is_url`; and the no-system refusal prints the current directory escaped. No full pass was run: the publish checkpoint was answered `address`, so the full pass runs when publish is raised again.

## Implementation
**Status**: complete
**When**: 2026-11-20 12:46 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-499 at `b911e926`
**Addressed**: Local Review (Pre-Push) at `c21b92cb` (2026-11-20 12:31 -05:00)
**Commits**: 96e003c4, a5b121f2, 001ae690, 47c346ec, b911e926

### Actions
- [x] (suggestion) A later manifest that repeats a repo's url unchanged keeps the source: the merge skips a `url` equal to the one in effect. The design's "show" section says a manifest that repeats the url unchanged does not change the manifest named. Tests: a url repeated twice (once with a new version) keeps the first manifest; a url changed to a fork and back names the manifest that changed it back — `tools/repos-manifest/src/repos_manifest/combine.py`, `tools/repos-manifest/docs/design.md`, `tools/repos-manifest/tests/test_base_merge.py` (96e003c4)
- [x] (suggestion) `shown_path` writes a character above U+FFFF as `\UXXXXXXXX`; the design and docstring say `\uXXXX` up to U+FFFF and `\UXXXXXXXX` above. Tests: U+E0001 then `1`, and U+E000 then `11` — `tools/repos-manifest/src/repos_manifest/show.py`, `tools/repos-manifest/docs/design.md`, `tools/repos-manifest/tests/test_show.py` (a5b121f2)
- [x] (suggestion) Scheme chosen: `\xXX` is a character only below 0x80 and a non-UTF-8 byte otherwise (bytes are always 0x80 or above); a character from U+0080 up is `\uXXXX`. So byte 0x85 prints `\x85` and U+0085 prints `\u0085`. The design says so with that example; tests on both — `tools/repos-manifest/src/repos_manifest/show.py`, `tools/repos-manifest/docs/design.md`, `tools/repos-manifest/tests/test_show.py` (001ae690)
- [x] (suggestion) Inside a system directory `show` opens the recorded manifest path as `sync` does (`read_manifest(config.manifest, system, ...)`), naming it by its canonical path when that path opens and by the recorded one when it does not, so a refusal reads as sync's; `system.is_url` replaces the bare `"://"` test. `read_manifest` gained an optional `shown` label (default unchanged). The design says the recorded path is opened as `sync` opens it. Tests: a recorded `sub/../m.yaml` reads and prints canonical; a recorded `missing/../m.yaml` is refused by both `show` and `sync`, each naming it as recorded (this test fails on the code before the fix) — `tools/repos-manifest/src/repos_manifest/cli.py`, `tools/repos-manifest/src/repos_manifest/system.py`, `tools/repos-manifest/tests/test_show_system.py`, `tools/repos-manifest/docs/design.md` (47c346ec)
- [x] (suggestion) The no-system refusal prints the current directory through `shown_path`; the design says the refusal names it on one line. Test: a directory named `a\nERROR: fake` gives one stderr line with `\x0a`. The tool's general `ERROR:` printer and `init`'s path refusals are left as they are: messages reaching that printer carry text built from git's output and other parts whose line breaks were not audited, and escaping there without doubling backslashes would not be unambiguous, so it is not one small shared change that leaves every message without a control character unchanged. A follow-up issue can be proposed for it — `tools/repos-manifest/src/repos_manifest/cli.py`, `tools/repos-manifest/tests/test_show_system.py`, `tools/repos-manifest/docs/design.md` (b911e926)

### Checks
- Targeted: `tests/test_base_merge.py tests/test_show.py` 55 passed; `tests/test_show_system.py tests/test_sync.py tests/test_init.py tests/test_cli.py` 92 passed; `tests/test_show.py tests/test_show_system.py tests/test_init_refusals.py tests/test_init.py` 78 passed.
- Whole tool suite (`PYTHONPATH=src .venv/bin/python -m pytest tests`, at b911e926): 1821 passed in 550.69s (0:09:10).
- Every commit with `SKIP=validate-script-tests` (issue #465 rule); every other hook ran, flake8 and black included. No `.agent/scripts/` file changed, so no script suite applies. The full pre-commit pass is left to the host. Nothing under ~/project11 was read, written or run.
- `cli.py` edits are limited to `_show_in_system` and the `show` import; `system.read_manifest` gained an optional argument whose default keeps every other caller as it was.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 12:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-499 at `f310d62b`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff; whole diff stays Deep)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Cross-model: skipped (round-3 convergence check, per handoff). All five round-2 findings are fixed in the code (96e003c4, a5b121f2, 001ae690, 47c346ec, b911e926). Checked by hand on scratch manifests and systems: a later manifest repeating `https://example.org/nav.git` keeps the base as source; `nav.git/` and `nav` move the source to the later manifest, and that manifest's spelling is the url printed, so the design's "the one that gave the URL printed" holds (merge compares the text exactly; `update.same_url` treats them as one place, but the printed url did change). Escapes: U+0085 -> `\u0085`, byte 0x85 -> `\x85`, U+E000+`1` -> `1`, U+E0001 -> `\U000e0001`, `\` doubled; each form decodes one way, and it matches the design's words. `read_manifest`'s new `shown` defaults to the old label; `sync` (sync.py:714), `init` (init.py:258) and `build`/`show <manifest>` (cli.py:78, cli.py:230) call it unchanged, and `Repo.source` is read only by `show`. The general `ERROR:` printer (cli.py:412) and `init`'s path refusals are unchanged from main; the reason given holds (that printer gets two-part refusals and git text, so escaping there is a per-message change, not one line), and a follow-up issue is still to be filed. Targeted tests (test_show, test_show_system, test_base_merge, test_init, test_cli): 116 passed; flake8 clean on the changed lines.

### Findings
- [ ] (suggestion) "a refusal names the path as recorded" is true only for a path that does not exist: `opens` tests `os.path.exists`, so a recorded path that exists but cannot be read (a directory) or does not parse (through a link) is named canonical by `show` and as recorded by `sync`. Narrow the sentence and the comment to "a path that does not exist", or name every refusal as recorded — `tools/repos-manifest/docs/design.md:524`, `tools/repos-manifest/src/repos_manifest/cli.py:212`

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:50 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 approved with no must-fix; the host's full pass passed on this head)
**After**: publish
**Decision**: publish

Read the Local Review (Pre-Push) at e54b043b (round 3, approved, ship recommended, one suggestion). The full pass (`pre-commit run --files` over the branch's files, no SKIP, branch even with origin/main) passed: every hook Passed or Skipped for no files, black and flake8 included. The one open suggestion goes to the pull request's triage rather than a fourth pre-push round: the design's "show" section says a refusal names the path as recorded, which holds only when the recorded path does not exist; when it exists but cannot be read, `show` names the canonical path and `sync` the recorded one.

## Integrated Review
**Status**: complete
**When**: 2026-11-20 12:59 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #541 at `4431a59`
**Sources**: 2 (Local Review (Pre-Push) @ `f310d62` (covers 4431a59 via bookkeeping), CI rollup); no GitHub reviews, inline comments or conversation comments, and no Copilot review
**Cross-source confirmations**: 0
**CI**: pending

### Findings
- [x] (suggestion, Local Review (Pre-Push) @ `f310d62`) Verified against the code: "a refusal names the path as recorded" holds only when the recorded path does not exist. `_show_in_system` (`cli.py:212`) passes `os.path.realpath(recorded)` as the label whenever `os.path.exists(recorded)`, so a recorded path that exists but is a directory, unreadable, not UTF-8 or fails to parse is named canonical by `show` (`_read_text`/`parse_part` use that label), while `sync` (`sync.py:714`, no `shown`) names it as recorded. Narrow the design sentence and the comment to "a path that does not exist", or pass the recorded path as the label on every refusal so both commands agree — `tools/repos-manifest/docs/design.md`, `tools/repos-manifest/src/repos_manifest/cli.py`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:59 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (one open suggestion, valid against the code, with a small fix; the table lets the host answer address)
**After**: findings
**Decision**: address

Read the Integrated Review at 2b073c88 (one open finding, no outside review arrived, CI pending). The finding: the design's "show" section and the comment in `cli.py` say a refusal names the manifest path as recorded, which is true only when the recorded path does not exist. Host decision, listed for the owner's veto: fix the code rather than narrow the sentence, so that every refusal by `show` inside a system directory names the path as recorded, as `sync` does, and the canonical path is printed only when the manifest was read. Undoing it is one label and its tests.

## Implementation
**Status**: complete
**When**: 2026-11-20 13:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #541 at `3b21957`
**Addressed**: Integrated Review at `4431a59` (2026-11-20 12:59 -05:00)
**Commits**: 3b21957

### Actions
- [x] show named a recorded manifest that exists but does not read (a directory, unreadable, not UTF-8, does not parse) by its canonical path while sync named it as recorded. Fixed in the code: `_show_in_system` now reads and resolves under the recorded name, as sync does, so every refusal and warning names the path as recorded; the canonical path replaces it only after a successful read (the manifest line and the leaf's `from` lines). Design sentence and comment rewritten to match; parametrised test compares show's and sync's refusals for the directory and parse-failure cases (both fail on the old code) — `tools/repos-manifest/src/repos_manifest/cli.py:189`, `tools/repos-manifest/docs/design.md:523`, `tools/repos-manifest/tests/test_show_system.py`

### Checks
- `PYTHONPATH=src pytest tests/test_show_system.py tests/test_show.py tests/test_sync.py tests/test_init.py tests/test_cli.py`: 113 passed in 66.04s
- No script under `.agent/scripts/` changed, so no script suite applies; the full pre-commit pass is left to the host.

## Local Review
**Status**: complete
**When**: 2026-11-20 13:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #541 at `d02ab66`
**Depth**: Light (reason: narrow re-review of one fix commit, 3b21957f, per handoff; no cross-model reviewers)
**Must-fix**: 0 | **Suggestions**: 1

Scope: commit 3b21957f (show names the recorded manifest as recorded on every refusal) and what it could break. Hand-checked in a scratch system directory with a local git repo, comparing `show` and `sync` with no argument: a recorded path that is missing, a directory, not UTF-8 and does not parse (through `sub/../` and through a link) is named as recorded by both; a recorded role the manifest lacks is refused under the recorded name by both; the top manifest's unknown-key warning names the recorded path in both; a successful read through `..`, a link, and `link/../` prints the canonical path on the `manifest` line and the leaf's `from` lines, bases unchanged; a url recorded in `config.yaml` is refused by `read_config` identically in both. `is_url` has no use left in `cli.py` (still used in `system.py`). The source swap after resolve cannot hit a base's repos: bases are labelled by real path, and a base equal to the leaf is refused as a cycle. Design sentence (`docs/design.md:523`) and comment (`cli.py:206`) match the code. `pytest tests/test_show_system.py tests/test_show.py`: 35 passed.

### Findings
- [ ] (suggestion) The design sentence now promises every warning and refusal names the recorded path, but the new test covers only the directory and parse cases; add a case for a warning on the top manifest and a resolve refusal (recorded role not in the manifest), both hand-verified correct — `tools/repos-manifest/tests/test_show_system.py:203`

## Integrated Review
**Status**: complete
**When**: 2026-11-20 13:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #541 at `d02ab66`
**Sources**: 2 (Local Review @ `d02ab66` (covers 19f5ad9 via bookkeeping), CI rollup; no GitHub reviews, inline comments or conversation comments, no Copilot review)
**Cross-source confirmations**: 0
**CI**: pending

### Findings
- [ ] (suggestion, Local Review @ `d02ab66`) Verified against the code: the design ("show", `design.md:523`) now promises that every refusal and warning names the recorded manifest as recorded, but the new parametrised test covers only two refusals from reading (a directory, YAML that does not parse). Warnings take another path: `read_manifest` passes them to `system.warn` on a successful read, labelled by `Manifest.source`, and the resolve refusals come from `selection.resolve`; neither is tested under a recorded path whose canonical form differs. The code is right by construction (read and resolve both use the recorded name in `_show_in_system`), so this is test coverage for a promise in the design. Add to the test, using `sub/../m.yaml`: (a) a top manifest with an unknown top-level key, where show succeeds and its stderr warning names `sub/../m.yaml`, never the canonical path, the same as sync's; (b) a recorded role not in the manifest, where show and sync refuse it naming `sub/../m.yaml` — `tools/repos-manifest/tests/test_show_system.py:203`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-20 13:06 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (one open suggestion, two missing test cases for behaviour the design now promises; a small fix the table lets the host answer)
**After**: findings
**Decision**: address

Read the Integrated Review at 1a41a6be (one open finding, no outside review, CI pending). The design promises that every refusal and warning names the manifest by its path as recorded, and the test covers two refusals only. Add the two cases the review names, with a recorded `sub/../m.yaml`: a top manifest with an unknown top-level key, where the warning from `show` and from `sync` names the recorded path; and a recorded role that is not in the manifest, refused by both under the recorded name. Tests only; no code change is expected.
