---
issue: 501
---

# Issue #501 — repos-manifest: build

## Issue Review
**Status**: complete
**When**: 2026-11-19 12:00 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #501

### Scope Assessment

**Well-scoped?** Yes, with open questions. One command in one tool, with tests and a by-hand acceptance. The questions below are about failure behaviour and `setup.bash`, not size.
**Right repo?** Yes. The tool is in this repo.
**Serves**: the manifest-design goal of exercising the new design on a real project. Design section `tools/repos-manifest/docs/design.md#build` (the root `docs/design.md` is untouched).
**Design picture?** No change to the root design. The part's design section "build" (design.md line 695) is the spec the issue follows. The questions below may add sentences to that section.
**Dependencies**: `init` and `sync` (merged). Later: `status` and the thin adapter's `build` route (`docs/manifest/roadmap.md` lists `build` among the commands the adapter calls).

**Where things live now.** The issue says `tools/ros-manifest/docs/...`. The tool is `tools/repos-manifest/`, with `docs/design.md` (section "build"), `docs/spec.md`, `docs/roadmap.md` (row "`build` builds the layers in order and writes one setup file") and `docs/prototype.md`. The source is `src/repos_manifest/`. There is no `build` module yet. The issue's links should be read with that rename.

**Does the issue's wording match what `init` writes?**
- Layout: with `--distro-dirs` a distro's layers are in `<root>/<distro>/`, and a flat system has them directly in `<root>/`. The issue's "system directory, or the distro's directory" matches this (design.md lines 100-150, `system.py`).
- The unnamed first layer's repos are in `<distro>/src/`, and a named layer's in `<distro>/<layer>/src/` (`system.py` header). So "the layer's directory" for the unnamed layer is the distro directory itself, which also holds the named layers' directories. The issue does not say this. It matters for where colcon runs and where `build/ install/ log/` go. The resolved-file name for it is `_unnamed.repos`.
- `setup.bash`: `init` already writes one, a stub that prints "nothing is built here yet" and fails when sourced (`SETUP_TEXT` in `system.py`; design.md line 202: "Until `build` is built..."). `sync` recreates it where missing, and leaves a non-file at its place alone. The issue says "written in the system directory", as if new. It is really a replacement of the stub.
- Resolved record: the issue does not name the files `build` reads. In the tool they are under `.repos-manifest/resolved/<distro>/` (or `resolved/` when flat). The issue should say that the order of layers and the repo paths come from there, not from re-resolving the manifest.

**Within a failing layer, and across layers.** The issue says `build` "stops at the first layer that fails" and that `--` arguments go to colcon, so `--continue-on-error` works within a layer. It does not say:
- Whether a layer counts as failed when colcon exits non-zero with `--continue-on-error`, where some packages did build. Presumably yes, and the run stops, since later layers may need the failed packages. This is the case for the Rolling port, where some packages are known to fail.
- What `setup.bash` points at after a layer partly built. "The last layer ... that has been built" is not defined for a partial layer. Options: only layers whose colcon run succeeded; or the partial layer too, since colcon writes its `install/setup.bash` even then; or leave `setup.bash` unchanged on a failed run.
- How `build` knows a layer "has been built" in a later run that builds other layers: the existence of `<layer>/install/setup.bash`, or a record in `state.yaml`. A stale `install/` from an earlier, different selection (the issue's own concern about unselected repos) would count as built under the first option.
- Whether a user wanting every layer attempted despite a failure (to see all failures in one pass on a port) has a way. The issue offers only `build <layer>...` per layer. The owner may want this decided, not assumed.
- What is reported at the end: which layers built, which failed, which were skipped for being empty, which were not tried because of the stop; and the exit status.
- What happens with `build <layer>...` for a layer whose earlier layers were never built (its `install/setup.bash` to source is missing): refuse, or build on what is there.
- Whether the order of the layers named on the command line matters, or the manifest's order is always used.
- Whether `setup.bash` is replaced when it is not the stub (a person's own file, or one `build` wrote). The tool's rule for `init`/`sync` is to leave what exists; `build` must have a rule for overwriting.
- Interrupts: the tool holds stop signals over its other writes (`signals_held`) and writes files in one step. `setup.bash` should be written the same way, never partial.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | The command is the next step on the owner's list for exercising the design; the scope list is tight, and tests and `status` are kept out. |
| Keep one current design | Watch | The design's "build" section already states most of this. The answers to the questions above must be written back into it, and into the stub sentence at design.md line 202 ("Until `build` is built"), in the same change. |
| Verify before claiming | Action needed | The by-hand acceptance records "how far it got"; the pull request must say which packages failed and that the failure is the port's, with the command run. Also, design.md's note on `colcon_defaults.yaml` is "checked with colcon-defaults 0.2.9": any new claim about colcon's exit status with `--continue-on-error` and whether `install/setup.bash` exists after a partial build should be checked against the installed colcon, not assumed. |
| Know whether it works | Action needed | A failing layer, a layer left unbuilt after the stop, and what `setup.bash` now points at must each be said in the output and in the exit status. The issue does not yet define them (see the questions above). |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0022 (a part owns its inside) | Yes | The change is inside the tool, so its design, spec and roadmap rows are the tool's own. The root roadmap row for `build` (docs/manifest/roadmap.md) is touched only when it is done. |
| ADR-0017 (design document is the current picture) | Yes | Update `tools/repos-manifest/docs/design.md` in the same change. |
| ADR-0009 (venv for dev tools) | Watch | Tests run in `.venv`; the tests with small packages need `colcon` available there or skipped with a stated reason, not silently. |

### Consequences

- `tools/repos-manifest/docs/design.md`: the "build" section, the stub sentence at line 202, and the trees at lines 100-150 if the answers change them. `docs/roadmap.md` row ticked. `README.md` command list.
- The tool's `cli.py` command table and its help text.
- `docs/manifest/roadmap.md` is ticked only once the adapter calls `build`.

### Recommendations

- Update the issue's paths from `tools/ros-manifest/` to `tools/repos-manifest/` so the plan reads the right files.
- State in the plan that `init`'s stub `setup.bash` is replaced by `build`, and what `build` does when the file at that place is not the stub or not a file.
- Before planning, ask the owner: when a layer fails, even with `--continue-on-error` inside it, does `build` stop there and leave `setup.bash` pointing at the last fully built layer, or at the partly built one? Is there an option to keep going to later layers?
- Define in the plan how "built" is decided for a layer (colcon success in this run, `install/setup.bash` on disk, or a recorded state), and what `build <layer>` does when an earlier layer is not built.
- Add an acceptance test for a layer where one package fails and another succeeds (with and without `--continue-on-error` passed after `--`), and for the exit status and the summary of what built, failed and was not tried.
- Say in the plan where colcon runs for the unnamed first layer (the distro directory, beside the named layers' directories) and give it a test.

### Actions
- [ ] The by-hand acceptance records "how far it got"; the pull request must say which packages failed and that the failure is the port's, with the command run. New claims about colcon's exit status with `--continue-on-error` and `install/setup.bash` after a partial build are checked against the installed colcon.
- [ ] A failing layer, a layer left unbuilt after the stop, and what `setup.bash` now points at are each said in the output and in the exit status; the issue does not yet define them.
- [ ] Update the issue's paths from `tools/ros-manifest/` to `tools/repos-manifest/` so the plan reads the right files.
- [ ] State in the plan that `init`'s stub `setup.bash` is replaced by `build`, and what `build` does when the file at that place is not the stub or not a file.
- [ ] Before planning, ask the owner: when a layer fails, even with `--continue-on-error` inside it, does `build` stop there and leave `setup.bash` pointing at the last fully built layer, or at the partly built one? Is there an option to keep going to later layers?
- [ ] Define in the plan how "built" is decided for a layer (colcon success in this run, `install/setup.bash` on disk, or a recorded state), and what `build <layer>` does when an earlier layer is not built.
- [ ] Add an acceptance test for a layer where one package fails and another succeeds (with and without `--continue-on-error` passed after `--`), and for the exit status and the summary of what built, failed and was not tried.
- [ ] Say in the plan where colcon runs for the unnamed first layer (the distro directory, beside the named layers' directories) and give it a test.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 09:31 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the open actions are inputs to the plan; none changes the issue's scope)
**After**: issue-actions
**Decision**: proceed

The host read the Issue Review's eight actions. Seven are mechanism and go to the plan: the pull request's record of the by-hand build, what the output and exit status say, the stub setup.bash, how "built" is decided, the partial-failure test, the unnamed first layer, and the corrected paths (the tool is at tools/repos-manifest/; the issue body is left as written and the review comment on the issue carries the correction). One is the owner's: whether build gets an option to keep going to later layers after a layer fails, which the issue text does not ask for ("it stops at the first layer that fails"). The host puts that question to the owner while the plan is written; the plan is written to the issue as it stands (stop at the first failing layer, a layer fails when colcon exits non-zero) and says what the option would add, so the owner's answer can be applied at the plan checkpoint.

## Plan Authored
**Status**: complete
**When**: 2026-11-19 09:33 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-501/plan.md` at `3ffcbf9e`

One pull request: a build command that runs colcon per layer from the resolved files, records built layers in a new built.yaml (colcon writes install/setup.bash even after failures, so that file cannot say built), and writes setup.bash pointing at the last layer of the built prefix. Tests use a stub colcon always and real colcon where present; docs and a CI colcon step (owner's yes) in the same change. Keep-going option written up as a separate section.

## Plan Review
**Status**: complete
**When**: 2026-11-19 09:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #501 — repos-manifest: `build` builds the layers in order and writes one setup file
**Plan**: `.agent/work-plans/issue-501/plan.md` at `3ffcbf9e`
**Branch**: `feature/issue-501`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One command, one record file, tests and docs; about ten files in one tool. One pull request is the right size: the tests are the proof of the decisions, and the design text must land with the command. |
| Issue alignment | Needs work | Covers every Issue Review question (colcon behaviour measured, "built" defined, stub replacement, unnamed-layer cwd, report and exit status, interrupts). But it builds several distros in one run, which the issue ("one distro at a time") and the design's distro table both rule out (finding 1). Serves: "The manifest-design goal of exercising the new design on a real project; `tools/repos-manifest/docs/design.md#build`". The anchor exists; the root goal is not named as a section of `README.md#workspace-goals` (finding 9). |
| File targeting | Good | `build.py`, `system.py`, `cli.py`, tests, design/README/roadmap. `sync.py` wording change confirmed needed (`create_setup`, design "Until `build` is built"). `spec.md` has no `setup.bash` text; only line 457 (reserved layer names), which the plan already relies on. |
| Consequences | Needs work | Design sections beyond "build" are missed: "What is built" (lists `build` as not built), the last "Open questions" bullet (stop or carry on: now decided), the system-directory tree (lines 24-36, `built.yaml`), and the distro table if it changes (finding 6). |
| Principle alignment | Needs work | "Verify before claiming" is done well (the colcon table was run). "Know whether it works" has a hole: the record can say "built" for a layer whose `install/` is half-rewritten or gone (findings 3, 4). "Keep one current design": the invalidation rule contradicts the design sentence "whichever layers this run built" without saying so (finding 2). |
| ADR compliance | Good | ADR-0022 (inside the part), ADR-0017 (design in the same change, modulo finding 6), ADR-0009 (colcon found on PATH plus the venv's bin, like `vcs`). |
| ROS conventions | N/A | Workspace tool; colcon is used generically. |

### Findings

1. **[Issue alignment] High** — Plan step 1 finds distros "as `sync` does" (`distros_for`), and step 9 builds "the next distro" after a failure, with `--distro D]...` repeatable. At the top of a distro-dirs system `distros_for` returns every distro, but design.md "Which distro a command uses" says `build` at the top uses the only distro and is an error listing them when there are several; the issue says "One distro at a time: the one whose directory it is run in, or `--distro`". It is also wrong in substance: each distro needs its own environment (design: "one shell can build only one of them"), so building jazzy and rolling from one shell builds one of them against the wrong ROS. Resolution: one `--distro` (not `append`), the design's refusal at the top with several, and drop the multi-distro test and exit rule.
2. **[Principle alignment / design] High** — Step 5 removes the records of every later layer when an earlier layer is rebuilt successfully, so `build underlay` after a full build leaves `setup.bash` sourcing only `underlay`. The design says `setup.bash` sources "the last layer, in the manifest's order, that has been built, whichever layers this run built", and "`build` with layer names builds only those layers"; a later layer's colcon setup still chains the earlier layer's install path, so it stays usable after an incremental rebuild in the ordinary colcon workflow. As planned, every fix to an earlier layer forces rebuilding all later ones before the system is usable again. Either keep later records on a successful rebuild (optionally noting they were built on its earlier output), or, if the stricter rule is wanted, put it to the owner and rewrite the design sentence explicitly, not as an incidental consequence.
3. **[Principle alignment] High** — The record is only changed at the end (failure removes, success adds, "record ... not changed for the interrupted layer"). colcon rewrites a layer's `install/` in place, so a layer recorded built that is then rebuilt and killed outright (SIGKILL, power loss, a terminal closed with SIGHUP to the whole group racing the handler) keeps a "built" record over a half-written `install/`, and `setup.bash` keeps sourcing it. Remove the layer's record (and, per finding 2's decision, the later ones) and write `built.yaml` before starting its colcon; add it back only on exit 0. Same for the graceful-stop path: "not changed for the interrupted layer" is wrong once colcon has started writing. Add a test that a stop during a recorded layer's rebuild leaves it unrecorded.
4. **[Principle alignment] Medium** — The record can disagree with the disk, and the plan does not say what happens. (a) `install/` removed by hand: the record says built, `setup.bash` sources a missing file, and the next layer's subshell `source` fails. Treat a recorded layer whose `install/setup.bash` is missing as not built (presence is necessary though not sufficient), say so in the report, and test it. (b) A record for a layer that `sync` has since dropped from `layers.txt`: say it is ignored and dropped at the next write. (c) A `sync` that changed a layer's repos (new commits or a new repo) after it was built: the record still says built; that is fine as "has been built", but the report's "recorded built" line should not imply "up to date", and the step-11 note covers only repos removed, not added.
5. **[Approach] Medium** — Step 4 says the first layer gets the caller's environment unchanged. That is the design, but when the caller has already sourced this system's own `setup.bash` (the natural thing to do in a shell where one works), layer 1 is built with layer 3's prefixes on `COLCON_PREFIX_PATH`/`AMENT_PREFIX_PATH`, so the workspace overlays itself; the adapter's own build scrubs these variables first. The plan should detect a prefix under this distro's directory in those variables and refuse or warn (a design sentence too), with a stub-colcon test. Also say that the first layer runs colcon directly, not through `bash -c`, so "unchanged" is literal.
6. **[Consequences] Medium** — design.md needs, in the same change: "What is built" (`build` moves out of "Not built yet" and gets its own sentence), the last "Open questions" bullet (stop at the first failure is now decided: remove it or turn it into the keep-going question for the owner), the system-directory tree at lines 24-36 (`built.yaml` under `.repos-manifest/`), and the stub sentence. `README.md` and `docs/roadmap.md` are already listed.
7. **[Approach] Low** — Refusing `build <layer>` when an earlier layer is unrecorded is strict for a system built before this command or by the adapter's per-layer loop (`adapter_build`, which writes no record): the owner's project11 system will refuse every named build until one full `build`. Plain `build` still works, so this is acceptable, but the refusal message should say that a system built by other means needs one full `repos-manifest build` first, and design.md should say the record is the only thing `build` trusts. The adapter does not read `built.yaml` (`_rc_tool_distro_select` only checks `.repos-manifest/` and `resolved/`, and `resolved/layers.txt` for the flat refusal), so the new file does not trip its refusals.
8. **[Approach] Low** — `setup.bash` rule (step 7): exit 1 when a person's file is left alone is defensible, since writing `setup.bash` is part of what `build` promises, but it differs from `sync`, where a non-file at that place does not change the exit status; the design must state the difference. The sentence about links ("treated by what it points at but replaced as a link is not") is garbled: say plainly that any link is left, warned, exit 1. Also note the stop-signal handling: `signals_end_the_run` raises in Python while colcon runs; a SIGTERM sent to the tool's pid alone does not reach colcon, so the plan must say the tool forwards it to the child and waits for it before writing anything (as the interrupt test will need).
9. **[Issue alignment] Low** — The Serves line names "the manifest-design goal", which is not a section of `README.md#workspace-goals`. Name the root goal section it serves (and keep the part's `#build` anchor).
10. **[Tests / CI] Low** — The plan works without the CI change (stub tests always run; real-colcon tests skip with a reason). If the owner says yes, note that `colcon-core` plus `colcon-cmake` (or `colcon-common-extensions`) could be added to the `test` extra in `pyproject.toml`, beside `vcs2l`, so a local `.venv` gets colcon too; that still changes what CI installs, so it is the same Ask First question, not a way around it. If the owner wants the keep-going option, finding 2's rule decides what "the prefix" is, and the refusal rule in step 8 must be restated against it, as the plan's own section says.

### Summary

The plan is thorough and its colcon facts were measured, but it builds several distros per run against the issue and design, invalidates later layers on a successful rebuild against the design's "whichever layers this run built", and updates the built record only after colcon finishes, so a killed rebuild leaves a false "built". Fix those three and the design-section consequences, and it is ready.

### Recommended Actions

- [ ] One distro per run: a single `--distro`, the design's refusal at the top of a system with several; drop the multi-distro failure rule and test.
- [ ] Decide, with the design text, what a successful rebuild of an earlier layer does to later records; default to the design's "whichever layers this run built" unless the owner chooses the stricter rule.
- [ ] Remove a layer's record (and write `built.yaml`) before its colcon starts; restore only on exit 0; test a stop during a rebuild of a recorded layer.
- [ ] Treat a recorded layer without `install/setup.bash` as not built; say what happens to records of layers no longer in `layers.txt`.
- [ ] Detect this system's own prefixes in the caller's environment before building the first layer; run the first layer's colcon without a bash wrapper.
- [ ] Add to the docs list: design.md "What is built", the "Open questions" bullet on stopping, the system-directory tree.
- [ ] Refusal message for an unrecorded earlier layer mentions systems built by other means; state in design that the record is what `build` trusts.
- [ ] Rewrite the link sentence in step 7; state the exit-status difference from `sync`; say the tool forwards a stop signal to colcon and waits.
- [ ] Name a `README.md#workspace-goals` section in Serves.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 09:36 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work with three high findings; all are mechanism)
**After**: plan
**Decision**: revise

The host read the Plan Review's ten findings and decides them as follows for the revision. (1) One distro per run: a single --distro, and the design's refusal at the top of a system with several distros. (2) A successful rebuild of an earlier layer keeps the later layers' records, as the design sentence says (setup.bash sources the last layer built, whichever layers this run built). (3) A layer's record is removed, and the file written, before colcon starts, and set to built only on exit 0; with a test. (4) A layer recorded built without install/setup.bash counts as not built; records of layers no longer in layers.txt are dropped; the install note covers repos added as well as removed. (5) build warns when the caller's environment already holds this system's own install prefixes, and runs the first layer's colcon directly. (6, 9) The design document and the Serves line are corrected. (7) build <layer> still refuses when an earlier non-empty layer has no record, the message says a plain build fixes it, and the design says the record is the only thing build trusts. (8) A setup.bash that is a person's own file or any link is left alone with a warning and exit 1, the design states the difference from sync, and the tool forwards a stop signal to colcon and waits. (10) The plan must work with and without the CI change. Two questions are with the owner and are not decided here: an opt-in option to keep going to later layers after a failure, and installing colcon in CI (Ask First).

## Plan Authored
**Status**: complete
**When**: 2026-11-19 09:38 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-501/plan.md` at `49c3b137`

Revision after the plan review and checkpoint: one distro per run; records kept across rebuilds (built = record plus install/setup.bash); record removed before colcon and set on exit 0; own-prefix warning; stop signal forwarded; design-document list completed; Serves names a README goal; CI change split out as an optional step; keep-going restated against the new rules.

## Plan Review
**Status**: complete
**When**: 2026-11-19 09:39 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #501 — repos-manifest: `build` builds the layers in order and writes one setup file
**Plan**: `.agent/work-plans/issue-501/plan.md` at `49c3b137`
**Branch**: `feature/issue-501`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one command, one record file, tests and docs in one pull request. |
| Issue alignment | Good | The ten first-review findings are resolved as the checkpoint decided: (1) one `--distro`, the refusal at the top (step 1); (2) later records kept (step 6); (3) record removed and written before colcon, set on exit 0, tested (step 6, tests); (4) record plus `install/setup.bash`, dropped layers, added repos in the note (steps 5, 6, 14); (5) own-prefix warning and direct first colcon (steps 4, 11); (6) the design list (Files table); (7) refusal message and "the record is the only thing `build` trusts" (step 9, Files); (8) link sentence plain, difference from `sync` stated, signal forwarded and waited for (steps 8, 13); (9) Serves names a README section, though a loose fit (finding 4); (10) the plan is complete without the CI step. Serves: "The root README goal "Quality of the work" (`README.md#quality-of-the-work`: a tool that builds the system the same checked way every time, with failures visible rather than silent), under the part's own design `tools/repos-manifest/docs/design.md#build` (ADR-0022)." Both anchors exist. |
| File targeting | Good | As before. Checked: only `sync` calls `distros_for` (sync.py:488); the CLI has `resolve`, `validate`, `init`, `sync` and no command that acts on one distro of a system, so no existing refusal or shared helper exists (finding 3). The stub's first line starts `# Written by repos-manifest.` (system.py:44), so the marker test of step 8 works as a prefix. |
| Consequences | Good | Design sections "build", the tree, the stub sentence (design.md:202), "What is built" and the last "Open questions" bullet are listed; `test_init.py:253` asserts the stub text. |
| Principle alignment | Needs work | "Know whether it works": the revision's three uses of "built" (refusal, environment, `setup.bash`) share the per-layer predicate but choose layers by three different rules, so they disagree after a failure, against step 9's own claim (finding 1). The keep-going section, and one edge in the default path, record a layer as built on a chain that skips a lower layer (finding 2). |
| ADR compliance | Good | ADR-0022, ADR-0017, ADR-0009 as before. |
| ROS conventions | N/A | Workspace tool. |

### Findings

1. **[Principle alignment] High** — One definition of "built" is written once (step 5), per layer, but each use picks layers differently: the refusal (step 9) needs every earlier non-empty layer built, the environment (step 4) sources "an earlier built layer", and `setup.bash` (step 7) sources the last built layer anywhere. After layer 2 fails with layer 3 recorded earlier, `setup.bash` sources layer 3 while `build layer3` refuses because layer 2 is not built; step 9's "they cannot disagree" is false. Recommendation: define once, beside step 5, "the built run": the layers from the bottom, empty ones passed over, up to the first non-empty layer that is not built. `setup.bash` sources the last layer of the built run; the refusal is "an earlier non-empty layer is outside the built run and not named in this run"; the environment is the last layer of the built run below the one being built. Records stay as the checkpoint decided, so once layer 2 is rebuilt the run reaches layer 3 again and `setup.bash` sources it with no rebuild of 3. For a person porting, whose lowest failing layer is built with `--continue-on-error`: neither rule sources that layer's partial output (it is unrecorded under both), and the current rule instead hands them a stale layer 3 chaining a half-rewritten layer 2, which is the worst of both. Under the built-run rule `setup.bash` stays honest (layer 1), and the report says how to use what there is: "layer 2 failed; what it did build can be used with `source <abs>/layer2/install/setup.bash` (it brings in layer 1)". Change steps 4, 7, 9 and 12 (the "built earlier, on <layer>'s older output" line goes; a "recorded built, not used: above failed <layer>" line replaces it), the design paragraph, and the tests (failure at layer 2 with 3 recorded: `setup.bash` sources 1, the report names layer 2's own setup file; rebuild of 2 succeeds: `setup.bash` sources 3).
2. **[Principle alignment] Medium** — A layer's colcon setup chains only the layer sourced when it was built. A layer built on a chain that skips a lower layer stays blind to it even after that layer is built later. The keep-going section records layer 3 as built on layer 1 while layer 2 failed; once layer 2 is fixed, layer 3's record still says built and sourcing it never brings in layer 2. The default path has the same edge: layer 2 empty (skipped) when layer 3 was built, then `sync` gives layer 2 repos. Resolution: record, per layer, the layer it was built on (none for the first); a layer is built only when that recorded base equals the last layer of the built run below it now. This one clause in step 5 closes both cases, keeps the keep-going section switchable without another revision (a layer built over a failed one is then simply not built: tried for its output, not recorded), and needs a test for the empty-then-filled layer.
3. **[File targeting] Low** — Step 1 says "not verified here which of them do". Checked: no existing command refuses at the top of a system with several distros, and there is no shared helper; `distros_for` (system.py:233) is used only by `sync`, and `show`, `freeze` and `status` are not built (`resolve` and `validate` do not read a system). The design table gives `show`, `resolve`, `build` and `freeze` the same refusal, so put it in `system.py` beside `distros_for` (one function, `build` its first caller) and drop the hedge. Also say how a second `--distro` is refused: argparse's plain `store` silently keeps the last.
4. **[Issue alignment] Low** — "Quality of the work" (README.md:33) is about agents' work: time and care, safeguards earning their cost, concise documents, learning from existing code, field safety. Its bullets do not contain the plan's gloss ("builds the system the same checked way every time"). Sibling plans for this tool name "Modular" (issue 498) and "Easy to use" (issue 503), and `build` is what the ros2 module's build route will call. Name "Modular" or "Easy to use" (or both), with the gloss tied to a bullet in the section named.
5. **[Tests] Low** — "a stub killed with SIGKILL mid-build leaves the layer not built" tests a failing colcon, which step 10 already covers. What step 6 protects against is the tool dying while colcon runs. The in-run check of `built.yaml` by the stub already proves the order; either drop the SIGKILL clause or make it kill the tool's process (and the stub) and check `built.yaml` and that the next `build` reports the layer not built.

The two owner questions: the plan is complete without either. The CI step stands alone and can be switched on as written. The keep-going section can be switched on as written once finding 2's clause is in step 5; its sentence "`setup.bash` sources layer 3, which lacks layer 2" then changes under finding 1 to "sources layer 1", which belongs in the same edit.

### Summary

The revision resolves all ten first-review findings as the checkpoint decided. One structural gap remains: "built" is one predicate but three selection rules, so the refusal and `setup.bash` disagree after a failure; define the built run from the bottom once and use it in all three, with the base layer recorded so a layer built over a missing one is never counted. Both are local edits to steps 4, 5, 7, 9 and 12 and their tests.

### Recommended Actions

- [ ] Define "the built run" once beside step 5 and use it for the refusal, the environment and `setup.bash`; the report names the failed layer's own `install/setup.bash` for using its partial output; update the tests and the design paragraph.
- [ ] Record each layer's base layer; a layer whose base is not the current last layer of the built run below it is not built; test the empty-then-filled layer; restate the keep-going section's last sentences.
- [ ] Put the one-distro refusal in `system.py` beside `distros_for`, drop "not verified", say how a repeated `--distro` is refused.
- [ ] Name "Modular" or "Easy to use" in Serves, tied to a bullet.
- [ ] Make the SIGKILL test kill the tool, or drop it.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 09:40 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second plan review: needs-work, one high and one medium finding, both mechanism; this is the host's second revise in a row, so a third answer at this checkpoint is the owner's)
**After**: plan
**Decision**: revise

The host takes the second Plan Review's five findings and its recommendation as written. (1) "The built run" is defined once beside the definition of built: the layers from the bottom up to the first non-empty layer that is not built. All three uses read it: setup.bash sources the run's last layer; build <layer> refuses when an earlier non-empty layer is outside the run and not named in this run; a layer is built with the run's last layer below it sourced. Records of later layers are still kept, so a later successful rebuild of the failed layer brings them back without rebuilding. This narrows decision 2 of the previous checkpoint: the records stay, but setup.bash follows the run, and the design sentence is rewritten to say so. The closing report prints, for a failed layer, the command that sources what it did build. (2) Each layer's record holds its base (the layer sourced when it was built); a layer counts as built only when that base is the current last layer of the run below it; with a test for a layer that was empty and later filled. (3) The several-distros refusal goes in system.py beside distros_for, and a second --distro is refused, not silently replaced. (4) The Serves line names "Modular" or "Easy to use", tied to a bullet of that README section. (5) The kill test kills the tool itself, or is dropped in favour of the stub's check of the record during its run. The two owner questions (keep-going option, colcon in CI) stay open.

## Plan Authored
**Status**: complete
**When**: 2026-11-19 09:42 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-501/plan.md` at `f561d94b`

Second revision after the plan review and checkpoint: "the built run" defined once (bottom layers up to the first non-empty layer not built) and read by setup.bash, the refusal and the environment; each record holds its base and a layer is built only when the base matches; one-distro refusal in system.py and a repeated --distro refused; Serves names "Modular"; the SIGKILL test dropped for the stub's in-run record check; keep-going section aligned.

## Plan Review
**Status**: complete
**When**: 2026-11-19 09:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #501 — repos-manifest: `build` builds the layers in order and writes one setup file
**Plan**: `.agent/work-plans/issue-501/plan.md` at `f561d94b`
**Branch**: `feature/issue-501`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one command, one record file, tests and docs in one pull request. |
| Issue alignment | Good | The second review's five findings are resolved as the checkpoint decided: (1) "the built run" defined once in step 5 and read by steps 4, 7, 9 and 12, the report names the failed layer's own `install/setup.bash`, the design sentence is replaced, tests cover fail-then-rebuild; (2) the record holds the base, a layer is built only when it matches, the empty-then-filled test is listed, the keep-going section restated; (3) the refusal is one helper in `system.py` beside `distros_for` (system.py:233), a repeated `--distro` is refused by its own argparse action, the hedge is gone; (4) Serves names "Modular", tied to its first bullet (README.md:73); (5) the SIGKILL test is dropped for the stub's in-run check of `built.yaml`. Serves: "The root README goal "Modular" (`README.md#modular`, first bullet: knowledge about a kind of project, like ROS best practices, is added as a module without changing the rest of the workspace), since `build` is the command the ros2 module's build route will call, so the ros2 module can build a layered system without the workspace knowing colcon; under the part's own design `tools/repos-manifest/docs/design.md#build` (ADR-0022)." Both anchors exist. |
| File targeting | Good | As before. Checked: the adapter does not write `<distro>/setup.bash` (adapter.sh:97, its `env` emits the sourcing instead), so a system built by the adapter still has the stub and a plain `build` replaces it. |
| Consequences | Good | Design sections, tree, stub sentence, "What is built", "Open questions", README, tool roadmap and the stub-text tests are listed. |
| Principle alignment | Good | One rule picks layers; the six cases below give one consistent answer. Notes 1-3 are wording an implementer needs to get right, not behaviour. |
| ADR compliance | Good | ADR-0022, ADR-0017, ADR-0009 as before. |
| ROS conventions | N/A | Workspace tool. |

### Worked cases (by hand through steps 4-9)

- Three layers built; plain `build` fails at 2: layer 1 rebuilt, 2's record removed, 3's kept with base 2; the run ends at 1, `setup.bash` sources 1, 3 is reported recorded-not-used. Then `build layer2` succeeds (base 1): 3's base 2 is the run's last layer below it, so 3 is built again without a rebuild and `setup.bash` sources 3. Correct. (A plain `build` there rebuilds 3 too, since it tries every layer; see note 3.)
- Layer 2 empty when 3 was built (3's base 1); `sync` fills 2; the run ends at 1 (2 non-empty, no record), `setup.bash` sources 1, `build layer3` refuses naming 2; a plain `build` builds 2 (base 1) and 3 (base 2), `setup.bash` sources 3; `build layer2` alone makes 3's base mismatch, so 3 is not built and the run ends at 2. Correct; see note 1 for the label.
- Middle layer empty throughout: 3 built on 1 (base 1), the run passes over 2, `setup.bash` sources 3; rebuilding 1 leaves 3's base matching. Correct.
- `build layer3` after only layer 1: refuses naming layer 2 when 2 has repos, with "a plain `build` fixes it"; builds 3 on 1 when 2 is empty. Strict (a layer 2 built by other means is not trusted), not wrong.
- Layer 1 rebuilt with 2 and 3 recorded: bases unchanged, so 2 and 3 stay built and `setup.bash` sources 3. That is how colcon overlays behave anyway (an underlay rebuild does not rebuild overlays), and step 5 says the record does not mean up to date; not wrong for a user (note 2).
- System built by other means, plain `build`: no records, so every layer is built in order, layer 1 with colcon directly; no install note (no record); the own-prefix warning fires if the shell has `adapter env` applied; the stub `setup.bash` is replaced and sources the last layer. Correct; colcon reuses the existing `build/` directories where they sit in the same place.

No case gives a result a user would find wrong.

### Findings

1. **[Principle alignment] Low (note for the implementer)** — As written, the predicate of step 5 calls a layer above an unbuilt gap "built" when its base matches the run's last layer below it: in the empty-then-filled case, layer 3 (base 1) matches layer 1, the run's last layer below it, while layer 2 is non-empty and has no record. Behaviour is still right, because the run stops at layer 2 and nothing above is used, but the step 5 parenthetical and the test say "the layer above is then not built", and step 12's line "recorded built, not used: above failed <layer>" does not fit a layer 2 that never failed. Implement the report from the run first: a recorded layer above the run's end is "recorded built, not used: above <layer>, which is not built" (failed, never built, or install missing); "base changed" only for a layer inside the run's reach whose base differs. Write the test assertion against that line, not against the predicate.
2. **[Principle alignment] Low (note)** — After a successful rebuild of a lower layer with later layers kept, the report's "built and in the run" line could add "built against <lower>'s earlier output" so a person knows a plain `build` refreshes them. Optional.
3. **[Tests] Low (note)** — "layer 3 not rebuilt" holds for `build layer2`, not for a plain `build`, which tries every layer; the fail-then-rebuild test uses `build layer2`.

The two owner questions: the plan is complete without either. The CI step stands alone and touches no other step. The keep-going section reads the same run and base rule and can be switched on as written; its "recorded, not used" layer carries the same label point as note 1.

### Summary

All five findings of the second review are resolved as the checkpoint decided, and the built run, the per-layer base, the refusal, the environment and `setup.bash` agree in every case worked by hand. Ready for implementation; the three notes are for the implementer.

### Recommended Actions

- [ ] At implementation: report lines from the run's end first (note 1), and the fail-then-rebuild test with `build layer2` (note 3).

## Checkpoint
**Status**: complete
**When**: 2026-11-19 09:44 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (third plan review: ready, three low notes for the implementer)
**After**: plan
**Decision**: proceed

The host read the third Plan Review: verdict ready, all five earlier findings resolved, six worked cases giving no wrong result. Its three low notes go to the implementer in the handoff: the report says "above <layer>, which is not built" for a layer above where the built run ends, whether or not that layer failed; the report may say that later layers were built against a rebuilt lower layer's earlier output; the fail-then-rebuild test uses build <layer>, not a plain build. The plan is implemented as written, without the keep-going option and without the CI step: both are still with the owner (asked, not yet answered), and the plan's own sections say each can be added afterwards without a plan revision.

## Implementation
**Status**: complete
**When**: 2026-11-19 10:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-501 at `9819c61d`

The owner's answer to the two open questions, relayed by the host: "yes to both" (Q1: an opt-in flag to keep going to later layers after a layer fails; Q2: the pull request may change CI to install colcon for the tool's tests). Both are done here, each in its own commit.

Commits:
- `d2e51c34` the command: `src/repos_manifest/build.py` (new), `system.py` (`built.yaml` read/write, `LayerRecord`, `SETUP_MARKER`, `one_distro_for` beside `distros_for`), `cli.py` (`build [--distro D] [LAYER ...] [-- COLCON_ARGS]`, `--distro` refused when repeated).
- `05855698` the tests: `tests/test_build.py`, `tests/fixtures/stub_colcon/colcon`, a CMake-package helper in `helpers.py`, the `colcon` marker and a colcon line in the report header in `conftest.py`.
- `df2c73b8` the documents: design.md "build" rewritten (record, built run and its three readers, stop at first failure, setup.bash rules and how they differ from sync's, report, own-prefix warning, stop signals), the tree (`built.yaml`), the stub sentence, "What is built", the open question; roadmap row given the check `file-exists src/repos_manifest/build.py` (the table marks done by its check); README.
- `fab4fce9` `--keep-going`, as the plan's section says, with two tests and the design paragraph; the open question on stopping is removed.
- `9819c61d` CI: `.github/workflows/validate.yml`, job `validate-repos-manifest` installs `colcon-common-extensions` and runs the tests with `REPOS_MANIFEST_REQUIRE_COLCON=1`. The workflow, not the `test` extra, so a person installing the test extra does not get colcon and its plugins (they skip with a reason). Checked locally: the package exists on PyPI (0.3.0; it pulls colcon-bash, which writes the `setup.bash` files the tests source); the file passes yamllint and check-yaml. Not checked: that pip's colcon installs and runs on the 3.14 leg, and that `cmake` is on `ubuntu-latest` (the step prints `cmake --version` so a missing one fails visibly). The step is unverified until the push.

Departures from the plan:
- The report's line for a layer above where the built run ends is "recorded built, not used: <layer> (above <end>, which is not built)" for every such layer, failed or not (the review's note 1); a layer whose base differs gets "<layer>: base changed: ..."; a layer kept built over a rebuilt lower layer is listed as "built before, in the run: <layer> (on the earlier output of <lower>)" (note 2). The fail-then-rebuild test uses `build mid` (note 3).
- "First layer runs colcon without bash" is tested by recording the `Popen` argv in-process, not by the stub logging its parent's name: with `exec` in the bash wrapper colcon's parent is the tool either way, so the parent name cannot tell them apart.
- A SIGINT is not forwarded to colcon while the tool is in its terminal's foreground process group (a Ctrl-C there already reached colcon; colcon raises on a second SIGINT that arrives before it ignores further ones). SIGTERM, SIGHUP, and a SIGINT otherwise, are forwarded. design.md says so.
- The CMake helper packages have no `package.xml`: plain `CMakeLists.txt` packages are found by colcon-cmake and chain through `CMAKE_PREFIX_PATH`, checked by hand first; a `package.xml` would make colcon-ros take them where it is installed.
- The refusal message and design.md say "another tool, by hand" rather than naming the workspace adapter: `tests/test_documents.py` forbids naming it in the tool's documents.
- `sync.py` needed no change: it has no "until build is built" wording.

Tests (run with `/usr/bin/python3 -m pytest` and `PYTHONPATH=src` from `tools/repos-manifest`, since the main checkout's `.venv` has no pytest; `PYTHONPATH` made it import the worktree's package, checked):
- Whole tool suite: `1047 passed in 143.32s` (baseline before the change: 1018 passed). Report header: `colcon: /usr/bin/colcon`.
- Real-colcon tests (`-m colcon`): 3 ran, 0 skipped (`3 passed, 26 deselected`).
- No `.agent/scripts/` file changed, so no workspace suite applies; the full pre-commit pass is left to the host.

By hand: a scratch system made with `repos-manifest init` (local file remotes, an unnamed layer with plain CMake package `good`, a layer `top` with `good2` that does `find_package(good)`), built with the real colcon: exit 0, report `built: _unnamed, top` / `setup.bash: sources top`; the written `setup.bash` sources `top/install/setup.bash` by absolute path, and sourcing it puts both `top/install/good2` and `install/good` on `CMAKE_PREFIX_PATH`; `build top` afterwards reports `built before, in the run: _unnamed`.

Still to do, not by this pass: the by-hand acceptance build of `~/project11` is the owner's (no build was run in `/home/roland/project11` or `/home/roland/p11-rolling-test`). Nothing pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 10:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-501 at `d783eaff`
**Base**: main
**Depth**: Deep (reason: ~1950 lines over 13 files, a new command that runs child processes and handles signals, and a CI workflow change)
**Must-fix**: 5 | **Suggestions**: 7
**Round**: 1 | **Ship**: continue — round 1: 5 must-fix; first round always re-reviews after fixes

Run: the tool's whole suite (`1047 passed`, colcon `/usr/bin/colcon`); pre-commit on the changed files (clean); a scratch system with real colcon and plain-CMake packages: failing middle layer with and without `--keep-going` and `-- --continue-on-error`, `build top` refusal, unknown layer, fix and `build mid` (top reported base changed), two distros at the top (refused), a second `--distro` (refused), `setup.bash` as a link, a directory and a person's file (left, exit 1), `sync` afterwards (leaves `setup.bash` and the record alone), SIGTERM to the tool alone (colcon stopped, `setup.bash` back on mid), SIGKILL of the tool, and a signal delivered at the end of each record write. The CI diff only adds the colcon install step and `REPOS_MANIFEST_REQUIRE_COLCON=1` to the `validate-repos-manifest` job. The adapter (`.agent/project_types/ros2_colcon/adapter.sh`, unchanged) reads neither `built.yaml` nor `<distro>/setup.bash` (grep), so its verbs are unaffected; not run against a scratch system. Outside reviewers: gemini and codex both completed.

### Findings
- [x] (must-fix) A stop signal held during a `built.yaml` write is delivered right after it, before `progress.started`/`progress.built` are updated: after the removal write the run says "nothing was changed" while the layer's record is gone and `setup.bash` still sources it; after the success write it says "<layer> was stopped and is not built" while the record has it and `setup.bash` sources it (reproduced; also found by gemini and the Claude adversarial) — `tools/repos-manifest/src/repos_manifest/build.py:454-468`
- [x] (must-fix) Error paths after a layer's record is removed skip the `setup.bash` rewrite, so it keeps sourcing a layer the record no longer has: a `Popen` OSError, and a colcon found through a relative PATH entry (`shutil.which` returns it relative, then it runs from the layer's directory and is not found; reproduced by the Claude adversarial); make the path absolute, drop empty PATH entries, and run `finish_setup` on that path as the Stopped path does (also codex) — `tools/repos-manifest/src/repos_manifest/build.py:231-241,458,595`
- [x] (must-fix) Stop handling does not stop the build: a forwarded SIGTERM kills only colcon's pid, its cmake/make jobs keep writing `build/` and `install/` after the tool exits (reproduced with real colcon); a forwarded SIGINT waits for the current package; a SIGINT sent to the tool's pid while it is in the terminal's foreground group is never forwarded; a second, escalated signal is dropped. Start colcon in its own process group and forward to the group with `killpg`, or correct design.md's "the tool waits for colcon to end" (Claude adversarial, codex, gemini; judges the implementer's SIGINT departure) — `tools/repos-manifest/src/repos_manifest/build.py:244-293`, `tools/repos-manifest/docs/design.md` (build, stop signals)
- [x] (must-fix) Arguments after `--` can break the record: colcon's `--base-paths` is a store action (checked in colcon_recursive_crawl), so a forwarded one replaces the layer's list; `--install-base`/`--build-base` move the output away from `<layer>/install/`; and a colcon exit 0 with no `install/setup.bash` (e.g. `-- --help`) is recorded built, the layers above build without it and the run exits 0. Refuse or document those options, and check `install/setup.bash` before writing the record (codex, gemini) — `tools/repos-manifest/src/repos_manifest/build.py:296-305,463-468`
- [x] (must-fix) `built.yaml` is one file for every distro, rewritten read-modify-write with no lock: two builds at once (natural with `--distro-dirs`) can write back a record the other removed before its colcon started, the "never a built over a half-written install/" promise fails; lock it, split it per distro, or say in design.md as for `state.yaml` (codex, Claude adversarial) — `tools/repos-manifest/src/repos_manifest/system.py:474-487`
- [x] (suggestion) A SIGKILL of the tool (or a power loss) during a layer leaves `setup.bash` sourcing that layer's half-written `install/` until the next build, though its record is gone (reproduced); rewriting `setup.bash` from the record before colcon starts closes it — `tools/repos-manifest/src/repos_manifest/build.py:454-457`
- [x] (suggestion) When no layer starts (every chosen layer empty), `setup.bash` is not reconciled with the built run, so it can keep sourcing a layer outside it (codex, Claude adversarial) — `tools/repos-manifest/src/repos_manifest/build.py:595-598`
- [x] (suggestion) `build <empty layer>` is refused when a lower layer is not built, though it would only be skipped (gemini) — `tools/repos-manifest/src/repos_manifest/build.py:361-377`
- [x] (suggestion) The failed-layer line offers `source .../install/setup.bash` even when colcon wrote none (gemini) — `tools/repos-manifest/src/repos_manifest/build.py:487-493`
- [x] (suggestion) The bash wrapper keeps the command in plain variables `setup` and `command`, which a sourced package hook could overwrite; use prefixed names (gemini) — `tools/repos-manifest/src/repos_manifest/build.py:64-66`
- [x] (suggestion) `repos-manifest build --help` shows no `[-- COLCON_ARGS]` in its usage line, unlike design.md's synopsis — `tools/repos-manifest/src/repos_manifest/cli.py:283-305`
- [x] (suggestion) The adapter's comment "<root>/<distro>/setup.bash is its stub until then" is stale once `build` exists; update it here or in issue 503 — `.agent/project_types/ros2_colcon/adapter.sh:97`

## Implementation
**Status**: complete
**When**: 2026-11-19 10:49 -05:00
**By**: claude-code (claude-opus-5-5)

**Branch**: feature/issue-501 at `62fc5d12`
**Addressed**: Local Review (Pre-Push) at `d783eaff` (2026-11-19 10:13 -05:00)
**Commits**: 82f1dc49, c99d00cf, 62fc5d12

### Actions
- [x] (must-fix) Stop signal around a record write: `started`/`built` now change inside the same `signals_held()` block as the record write (`_put(..., then)`), and every exit path goes through `settle()`; both windows tested (`test_a_stop_held_during_a_record_write_finds_the_run_in_agreement_with_it[removal|success]`) — `build.py` `_put`, `run_build`
- [x] (must-fix) colcon that cannot start: colcon and bash resolved once to absolute paths before any record is touched; empty and relative PATH entries are skipped (not made absolute); a Popen OSError becomes an error after `settle()`; `settle()` is the one function that brings setup.bash into line with the record — `build.py` `find_program`, `run_child`, `_build`
- [x] (must-fix) Stopping stops the build: colcon in a new session; 1st stop signal to the group as itself, 2nd SIGTERM, 3rd+ SIGKILL (each but SIGKILL followed by SIGCONT); the tool waits for colcon, then SIGKILLs what is left of the group and waits up to 10 s for it to go, before writing; SIGTSTP stops the group then the tool, SIGCONT continues the group; checked with /usr/bin/colcon that no make/sleep job survives SIGINT or SIGTERM, and in a pty (`script`) that colcon's status output still shows; design.md's stop paragraph rewritten — `build.py` `run_child`, `docs/design.md`
- [x] (must-fix) Forwarded args: `--base-paths`, `--paths`, `--install-base`, `--build-base`, their `=value` form and abbreviations (colcon allows abbreviation) are refused before the lock or any record; `--merge-install` is allowed (real-colcon test shows the chain holds); package selection and mixins documented; a layer is recorded built only when colcon exits 0 and its `install/setup.bash` was written in this run (inode/mtime/ctime changed), else "not built" and exit 1 — `build.py` `refused_arguments`, `build_layers`
- [x] (must-fix) One record per distro (`.repos-manifest/built-<distro>.yaml`) and an `fcntl.flock` on `.repos-manifest/build-<distro>.lock` held for the run (no existing lock code in sync/init); a second build of the same distro is refused naming the holder's pid; design.md tree and text updated — `system.py` `hold_build_lock`, `read_built`, `put_built_layers`
- [x] (suggestion) setup.bash brought into line right after a layer's record is removed, before colcon starts — `build.py` `build_layers`
- [x] (suggestion) When no layer starts, setup.bash is still settled — `build.py` `_build`
- [x] (suggestion) `build <empty layer>` is skipped, not refused — `build.py` `refusal`
- [x] (suggestion) The failed line offers `source` only when `install/setup.bash` exists — `build.py` `report`
- [x] (suggestion) The wrapper keeps its command in `_repos_manifest_build_setup`/`_repos_manifest_build_command` (names no hook uses), setup still sourced with no arguments — `build.py` `_SOURCE_THEN_RUN`
- [x] (suggestion) `build --help` usage shows `[-- COLCON_ARGS ...]` and an epilog naming the refused options — `cli.py`
- [x] (suggestion) Stale adapter comment corrected (comment only) — `.agent/project_types/ros2_colcon/adapter.sh:94-99`

### Tests
Each fix has a test; each was checked to fail with its fix reverted in a scratch copy (MF1 2 fail, MF2 relative-PATH 1, MF2 Popen 1, MF3 6 incl. both real-colcon stop tests, MF4 refusal 7, MF4 freshness 1, MF5 lock 1, S1-S5 1 each).
- Tool suite: `cd tools/repos-manifest && REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest` — `1075 passed in 170.99s` (real colcon /usr/bin/colcon, none skipped)
- `test_adapter.sh` — 248 passed, 0 failed; `test_ros2_colcon.sh` — 1375 passed, 0 failed, 0 skipped; `test_project_registry.sh` — 425 passed, 0 failed; `test_project_file.sh` — 701 passed, 0 failed; `test_worktree_create.sh` — PASS: 90 FAIL: 0; `test_register_project.sh` — 222 passed, 0 failed
- pre-commit (with SKIP=validate-script-tests) on the changed files: clean. The full pre-commit pass was left to the host.

### Notes
- Commits are grouped rather than one per finding: the five must-fix and S1-S5 all reshape the same run loop in build.py and its tests.
- A SIGKILL of the tool itself still leaves colcon running (it cannot be caught); its layer is already out of the record and setup.bash (design.md says so).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 11:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a2232ae6436041c7a, resume 1 of 3)

**Branch**: feature/issue-501 at `f5775bda`
**Base**: main
**Depth**: Deep (reason: whole branch diff, ~2600 lines; child-process and signal handling, a lock, a CI change; fix-round rule)
**Must-fix**: 4 | **Suggestions**: 7
**Round**: 2 | **Ship**: continue — round 2: 4 must-fix is high; two are design questions

Round 1's five must-fix were re-run and are gone: a signal at the end of either record write now leaves the line, record and `setup.bash` in agreement; a relative PATH entry and an empty one find colcon; SIGTERM, SIGINT and `timeout 5` during a slow make job leave no job running and no `SLOW_DONE`; `--b`/`--pa` are refused; a second build of the distro is refused naming the pid. A no-op rebuild still counts as built (colcon rewrites `install/setup.bash`, mtime/ctime change). Tool suite `1075 passed in 172.74s` with `REPOS_MANIFEST_REQUIRE_COLCON=1`; the 11 signal/stop/lock tests passed 5 runs of 5 (10.2 s each). The Claude adversarial specialist checked Ctrl-C and Ctrl-Z/fg in a real pty, `| tee`, a closed terminal and the stale lock with the real colcon and found them sound except as below. Outside reviewers: codex completed; gemini failed once (stream interrupted), completed on the one retry.

### Findings
- [x] (must-fix) The distro lock ends with the tool, not with colcon: a SIGKILL of the tool's group (a CI cancel, `kill -9 -PGID`) leaves colcon running in its own session, and a second `build` starts at once on the same layer (reproduced: two colcon in `top/`). Let colcon inherit the lock descriptor (`pass_fds`) and adjust the design text (Claude adversarial, codex) — `tools/repos-manifest/src/repos_manifest/build.py:353`, `system.py` `hold_build_lock`
- [x] (must-fix) A non-option argument first after `--` joins the layer's `--base-paths` list (nargs `*`): `build -- mid/src/b` built `b` into the unnamed layer's `install/` (reproduced); put `--base-paths` last or refuse a leading positional (gemini) — `tools/repos-manifest/src/repos_manifest/build.py:400-413`
- [x] (must-fix) A required repo missing from disk is treated like an optional one: with `mid/src/b` moved away, `build mid` said "skipped, no repos on this machine: mid", exit 0 (reproduced), and a layer with some required repos missing is built and recorded from the rest; design.md says only repos left out by the role or skipped as optional are left out. Name or refuse missing required repos (codex) — `tools/repos-manifest/src/repos_manifest/build.py:128-131`, `docs/design.md` (build)
- [x] (must-fix) Package selection that colcon must resolve fails in every layer that lacks the package: `build -- --packages-up-to c` failed the unnamed layer ("Package 'c' specified with --packages-up-to was not found"), removed its record and left `setup.bash: nothing is built` until a plain build (reproduced); design.md says package selection "is passed too". Say which selection options work across layers, or refuse/handle them — `tools/repos-manifest/docs/design.md` (build, arguments after `--`), `build.py`
- [x] (suggestion) `_end_the_rest` waits the full 10 s when the tool is a subreaper or PID 1 (zombies stay in the group; reproduced with `PR_SET_CHILD_SUBREAPER`), and says nothing if members outlive the wait; reap with `waitpid(-pgid, WNOHANG)` and warn (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/build.py:281-291`
- [x] (suggestion) Jobs in colcon's new session cannot open `/dev/tty` (ssh/git credential prompts in FetchContent, sudo), unlike plain colcon; say so in design.md (Claude adversarial) — `tools/repos-manifest/docs/design.md` (build, session paragraph)
- [x] (suggestion) On a terminal hangup the tool exits 120, not by SIGHUP as design.md says: `stop_exit`'s print to the dead tty raises before `raise_signal`; guard it (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/signals.py` `stop_exit`
- [x] (suggestion) The refusal of an ambiguous abbreviation (`--b`, `--pa`, `--i`) says "taken by colcon as <option>", but colcon itself rejects those as ambiguous; word it as "could be" (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/build.py:390-392`
- [x] (suggestion) A failed `settle()` before colcon starts does not stop the run, and a later successful one clears the problem, so the run can exit 0 after `setup.bash` kept sourcing a layer during its rebuild (codex) — `tools/repos-manifest/src/repos_manifest/build.py:595`
- [x] (suggestion) A record's `time` is put into `setup.bash`'s comment as read; a newline in it would put a command line into `setup.bash`. Only by hand-editing, but rejecting control characters in `read_built` is cheap (codex, gemini) — `tools/repos-manifest/src/repos_manifest/system.py` `read_built`, `build.py:194`
- [x] (suggestion) A stop signal between the lock's checks and `holder.append` (the prefix warnings) leaves the lock descriptor open for an in-process caller (codex, gemini) — `tools/repos-manifest/src/repos_manifest/build.py:762-767`

## Implementation
**Status**: complete
**When**: 2026-11-19 11:34 -05:00
**By**: claude-code (claude-opus-5-5)
**Dispatch**: resumed (agent a87bbb2d0d4e6df83, resume 1 of 3)

**Branch**: feature/issue-501 at `3d17c807`
**Addressed**: Local Review (Pre-Push) at `f5775bda` (2026-11-19 11:07 -05:00)
**Commits**: 3d17c807

### Actions
- [x] (must-fix) Lock outlives the tool: colcon inherits the lock descriptor (`pass_fds`); the lock file names the tool's and colcon's pids, and the refusal names the live one, else says `fuser -v <lock>` finds the holder. Checked with /usr/bin/colcon: after SIGKILL of the tool only colcon holds the lock and a second build is refused; once colcon's group ends the lock is free; colcon's make/sh/sleep jobs do not hold it (colcon closes fds), so a daemon a job leaves does not either (design.md says so) — `build.py` `run_child`, `system.py` `hold_build_lock`, `note_lock_holders`
- [x] (must-fix) `--base-paths` now goes after the forwarded arguments; a plain first argument and a second `--` are refused before anything is touched; checked by hand with real colcon that `--packages-select good2 good` and `--cmake-args -DFOO=1` at the end neither swallow nor are swallowed by `--base-paths` — `build.py` `colcon_argv`, `refused_arguments`
- [x] (must-fix) Missing required repos: `build` reads `optional.txt`; a repo listed for a layer this run would build that is not on disk and not optional is refused before anything runs, naming each with its layer and saying to run `sync`; a layer is empty only when all its repos are optional and absent; design.md says exactly this — `build.py` `read_layers`, `missing_repos`
- [x] (must-fix) Package selection: with real colcon, `--packages-up-to`, `-up-to-regex`, `-above`, `-above-and-dependencies`, `-above-depth`, `-start`, `-end` exit 1 on a name the layer lacks; select, skip, ignore, their regex forms, `-by-dep`, `-skip-up-to` and the failed/finished ones only warn. The failing kind (and abbreviations of it) is refused when the run would build more than one layer; any `--packages-` option makes the run a selection run, in which a layer gets its record back only if it counted as built before the run, else the report says the selected packages were built and `build <layer>` without selection records it, later layers are not tried and the exit status is 1; design.md rewritten — `build.py` `package_selection`, `build_layers`, `report`
- [x] (suggestion) `_end_the_rest` reaps its own children in colcon's group (`waitpid(-pgid, WNOHANG)`) while it waits, and warns, with `pgrep -g`, about members still there after 10 s — `build.py`
- [x] (suggestion) design.md says colcon's session has no terminal, so credential prompts fail, and to use ssh-agent, a git credential helper, or fetch with `sync` first — `docs/design.md` (doc only, no test)
- [x] (suggestion) `stop_exit` guards its print, so a closed terminal or pipe still ends by the signal — `signals.py`
- [x] (suggestion) An abbreviation is named as colcon would take it: "colcon reads it as X", or "colcon would reject it as ambiguous, and it could be X" — `build.py` `refused_arguments`
- [x] (suggestion) Every failed rewrite of setup.bash in a run is kept, named in the report and the stop line, and makes the exit status 1, even when a later rewrite works — `build.py` `settle`, `_setup_failed`
- [x] (suggestion) A record with a control character in a layer name, time, repo key or base is unreadable (the existing "repair or remove it" error) — `system.py` `read_built`
- [x] (suggestion) The progress (and its lock) is in `holder` from the moment the lock is taken; a stop before the checks end says "nothing was changed" and releases the lock — `build.py` `_build`, `run_build`

### Tests
Each fix has a test; each was checked to fail with its fix reverted in a scratch copy (14 mutants, all caught). The S2 doc change has none.
- Tool suite: `REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest` — `1099 passed in 194.39s` (real colcon, none skipped)
- Signal, stop and lock tests (`-k "signal or stop or lock or escalate or ctrl_z or session or reaps or terminal_gone or outlive or second_build"`, real-colcon ones included), five runs: `20 passed, 61 deselected` each time; no stray process afterwards
- No workspace script or adapter changed this round, so no `.agent/scripts/tests` suite applies; pre-commit (SKIP=validate-script-tests) on the changed files clean; the full pass was left to the host.

### Notes
- Departure: a resolving selection option is refused only when the run would build more than one layer, so a run that builds none (every named layer empty) passes it instead of being refused; nothing can fail there.
- One commit for the round: the fixes all touch the same argument checks, run loop and report in build.py.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 11:41 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a2232ae6436041c7a, resume 2 of 3)

**Branch**: feature/issue-501 at `afb4c937`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 3 | **Ship**: continue — round 3: 2 must-fix, both in the new package-selection rule; one is a design question

Scope: round 2's findings and the fix diff `a8071871..3d17c807`. Cross-model: skipped (round-3 convergence check, per handoff). Run: tool suite `1099 passed in 194.76s` (`REPOS_MANIFEST_REQUIRE_COLCON=1`); pre-commit on the changed files clean; a fresh Claude adversarial specialist; by hand with the real colcon on a three-layer system with an absent optional repo in mid.

Round 2's must-fix, re-run: (1) gone — after a SIGKILL of the tool's whole group a second build was refused naming the colcon still running, and ran once it ended; a sleeper left by a build step holds no lock fd. (2) gone — `build -- mid/src/b` and a second `--` are refused. (3) gone — with an optional repo absent in mid and a required one (`d`) moved out of top, plain `build` and `build top` refuse naming "d (layer top)", `build mid` builds. (4) the up-to kind is refused across layers; the new selection rule has the two must-fix below. The `fuser -v` hint shows when the pids in the lock file are dead and the lock is held. Round 2's suggestions: all addressed (subreaper reaping checked by the adversarial specialist; the rest read in the code and design.md).

### Findings
- [x] (must-fix) A selection run stops at the first layer that is not built yet, which is usually not the layer with the selected package: on a fresh system `build -- --packages-select c` (c is in top) ran colcon in the unnamed layer only, reported "selected packages built, not recorded: _unnamed (...not all of it was built...)", "not tried: mid, top", exit 1 (reproduced); nothing was selected there and c was never built, and design.md's "the report says the selected packages were built" is false for such a layer. Exit 1 is not what the person would expect after a successful colcon, and here nothing they asked for happened. Proposed: refuse, before anything runs, a selection run that would build a layer outside the built run, naming those layers and saying to build them without selection first; a selection run then only rebuilds built layers and exits 0 — `tools/repos-manifest/src/repos_manifest/build.py:756,780-784,833-836`, `docs/design.md` (Package selection)
- [x] (must-fix) A selection run on a built layer writes a new record listing every repo now on disk, not the record it had: after `sync` cloned the optional `opt` into mid, `build mid -- --packages-select b` recorded `repos: [b, opt]`, exit 0, though `opt` was never built, and the "new since" note is gone afterwards (Claude adversarial, reproduced). design.md says the layer "gets its record back". Restore the previous record's repos, or treat a layer whose repos differ from its record as not built for a selection run — `tools/repos-manifest/src/repos_manifest/build.py:780-784`, `docs/design.md`
- [x] (suggestion) colcon's resume options (`--packages-skip-build-finished`, `--packages-select-build-failed`) make a run a selection run, so a layer completed that way is never recorded and the report says "not all of it was built" (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/build.py` `package_selection`
- [x] (suggestion) `note_lock_holders` truncates and then writes, so a second build reading in between sees no pid and gives the `fuser` hint while the tool is alive; write then truncate to length (Claude adversarial, from the code) — `tools/repos-manifest/src/repos_manifest/system.py` `note_lock_holders`
- [x] (suggestion) A colcon usage error in the forwarded arguments (e.g. ambiguous `-- --packages-ign d`, exit 2) is found only after the first layer's record is removed, so `setup.bash` drops to "nothing is built" until a plain build (reproduced; not new in this round) — `tools/repos-manifest/src/repos_manifest/build.py` `build_layers` (deferred: host decision (Checkpoint 2026-11-19 11:42): telling a usage error from a build failure after the fact is not reliable; design.md now says build <layer> restores it, and the pull request names it)

## Checkpoint
**Status**: complete
**When**: 2026-11-19 11:42 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 found two must-fix, both in the package-selection rule the host itself decided in round 2; a branch with a reproduced wrong result is not published)
**After**: rounds
**Decision**: address

Round 3 confirmed all four round 2 must-fix gone and found two new ones, both reproduced, both in the rule for runs with a package-selection option. The host replaces its round 2 rule with the reviewer's: (1) a run with a package-selection option is refused, before anything runs, when it would build a layer that is not built; the message names those layers and says to build them without selection first; such a run then only rebuilds layers already built and exits 0. (2) After a successful selection run a layer gets back the record it had (its repos list unchanged), and a layer whose repos on disk differ from its record is treated as not built for a selection run. Suggestion 1: --packages-skip-build-finished is not package selection (it finishes a layer, and is how a failed layer is resumed during a port); --packages-select-build-failed stays selection, since packages never tried are not built by it. Suggestion 2 (write the lock file's pids, then cut to length) is fixed. Suggestion 3 (a colcon usage error found only after the first layer's record is removed) is not fixed: telling a usage error from a build failure after the fact is not reliable; design.md says a build <layer> restores it, and the pull request names it. This is the host's first address at this checkpoint.

## Implementation
**Status**: complete
**When**: 2026-11-19 11:51 -05:00
**By**: claude-code (claude-opus-5-5)
**Dispatch**: resumed (agent a87bbb2d0d4e6df83, resume 2 of 3)

**Branch**: feature/issue-501 at `dfbd1936`
**Addressed**: Local Review (Pre-Push) at `afb4c937` (2026-11-19 11:41 -05:00), with the Checkpoint of 2026-11-19 11:42 -05:00
**Commits**: dfbd1936

### Actions
- [x] (must-fix) A run with package selection is refused before anything runs or any record is touched when it would build a layer that is not built; the message names those layers with why and says to build them without selection first. The "selected packages built, not recorded / not tried / exit 1" path, its report line and design text are gone; a selection run exits 0 when colcon succeeds. Checked with /usr/bin/colcon: in a layer where the selection matches nothing, colcon exits 0 and does rewrite `install/setup.bash` (new mtime/ctime), so the "written in this run" check holds and the layer keeps its record; tested (`test_real_colcon_package_selection`) — `build.py` `not_built_for_selection`, `build_layers`
- [x] (must-fix) After a successful selection run a layer gets back exactly the record it had, time included (so the time still says when the whole layer was last built); a layer whose repos on disk differ from its record counts as not built for a selection run (refused, "its repos differ from its record: new n"); the "new since" note shows at the next plain build. Neighbouring case: with `--keep-going`, a layer above a failed one is not tried in a selection run, since it could only be built on another base than its record's — `build.py`
- [x] (suggestion) `--packages-skip-build-finished` (and an abbreviation that can only be it) is not package selection, so a layer completed that way is recorded by the ordinary rule; `--packages-select-build-failed` stays selection. Checked with the real colcon on a layer with one failing package, then fixed: select-build-failed refused, skip-build-finished completes and records it; design.md says how to resume a failed layer — `build.py` `package_selection`, `RESUMING`
- [x] (suggestion) The lock file's pids are written first, then the file is cut to length — `system.py` `note_lock_holders`
- [x] (suggestion) colcon usage error after the first record is removed — not fixed in code (deferred: host decision, Checkpoint 2026-11-19 11:42: telling a usage error from a build failure after the fact is not reliable); design.md now says `build <that layer>` with correct arguments restores it

### Checked by hand with the real colcon
Fresh system `build -- --packages-select c`: refused naming all three layers. Fully built: `build -- --packages-select c` rebuilt every layer, exit 0, record file byte-identical. One layer named (`build top -- --packages-sel c --packages-sel d`): `--packages-sel` is ambiguous to colcon (exit 2), so top failed and lost its record, the case the deferred suggestion describes; the tool treats it as selection, correctly. Selection option given twice (`--packages-select m --packages-select t`): passed through, tested. Lower layer not built, not named (`build top -- --packages-select c` with mid's install gone): refused by the existing "top is built on mid" rule; `build mid -- --packages-select b`: refused as not built. `--keep-going` selection with mid failing: mid failed, top not tried and kept its record, exit 1; then `build mid -- --packages-skip-build-finished` after fixing b: mid built and top back in the run.

### Tests
Each code fix has a test that fails with the fix reverted (6 reverted copies, all caught).
- Tool suite: `REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest` — `1107 passed in 202.06s` (real colcon, none skipped); no stray process afterwards
- No workspace script or adapter changed, so no `.agent/scripts/tests` suite applies; pre-commit (SKIP=validate-script-tests) on the changed files clean; the full pass was left to the host.

### Notes
- Departure: none from the host's rules. One addition the rules did not cover: with `--keep-going`, a selection run does not try a layer above a failed one (restoring its old record would claim a base it was not rebuilt on).
- Possible follow-up, not done (outside the host's decision on suggestion 3): an abbreviation that is ambiguous among the options in `COLCON_BUILD_OPTIONS` could be refused before anything runs, since colcon is sure to reject it.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 11:56 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a2232ae6436041c7a, resume 3 of 3)

**Branch**: feature/issue-501 at `7d8e5261`
**Base**: main
**Depth**: Deep (reason: round 4 convergence check per handoff)
**Must-fix**: 3 | **Suggestions**: 3
**Round**: 4 | **Ship**: continue — round 4: 3 must-fix (all mechanical: two design.md sentences and stray committed files) is above the script's limit of 2

Scope: round 3's findings and the fix diff `69aab154..dfbd1936`. Cross-model: skipped (round-4 convergence check, per handoff). Run: tool suite `1107 passed in 203.41s` (`REPOS_MANIFEST_REQUIRE_COLCON=1`); pre-commit on the changed files clean; a fresh Claude adversarial specialist held to the same scope; by hand with the real colcon.

Round 3's must-fix, re-run: (1) gone — on a fresh system `build -- --packages-select c` is refused before anything runs, naming the three layers; on a built system it rebuilds every layer, exit 0, record file byte-identical. (2) gone — after `sync` cloned the optional `opt` into mid, `build mid -- --packages-select b` is refused ("its repos differ from its record: new opt"), and the next plain `build mid` gives the "new since" note and records `opt`. Suggestions 1 and 2 addressed; suggestion 3 is the documented limit (its sentence is must-fix 2 below). The fixer's `--keep-going` choice is sound: with mid failing in a selection run, top is "not tried", keeps its record, is reported "recorded built, not used", exit 1; after `build mid -- --packages-skip-build-finished` top is back in the run with no rebuild.

### Findings
- [x] (must-fix) Stray colcon log files are committed in dfbd1936: `tools/repos-manifest/log/` (`COLCON_IGNORE`, the `latest` and `latest_version-check` links, `version-check_2026-11-19_11-36-25/logger_all.log`) from a `colcon version-check` run in that directory; remove them from the branch — `tools/repos-manifest/log/`
- [x] (must-fix) design.md's resume sentence is false: colcon's `--packages-skip-build-finished` skips every package whose last build finished in any earlier run, not "the packages it did not finish last time". After a run that failed with a colcon usage error, it built 0 packages (a changed `a` was not rebuilt) and the layer was recorded built, exit 0 (reproduced; the adversarial specialist also showed a dependent of a rebuilt package left stale). Say what colcon does and that the record then says only that every package has been built at some point, or record such a run only when the layer had been built before — `tools/repos-manifest/docs/design.md:928-931`, `build.py` `RESUMING`
- [x] (must-fix) design.md says `repos-manifest build <that layer>` "with correct arguments" restores a layer lost to a colcon usage error; with corrected selection arguments (`-- --packages-select p` after `--packages-sel p`) it is refused as not built: only a build without package selection restores it (Claude adversarial, reproduced) — `tools/repos-manifest/docs/design.md:933-936`
- [x] (suggestion) In a selection run the report says "built: X" for a layer where colcon built nothing ("ignoring unknown package", "0 packages finished"); "rebuilt with selection" would not mislead — `tools/repos-manifest/src/repos_manifest/build.py:847`
- [x] (suggestion) The selection refusal lists a built layer whose repos differ from its record under "not built" — `tools/repos-manifest/src/repos_manifest/build.py` `not_built_for_selection`
- [x] (suggestion) design.md's clause that the "new since" note "still comes at the next build without selection" describes a case a selection run now refuses; drop it — `tools/repos-manifest/docs/design.md:911-912`

## Checkpoint
**Status**: complete
**When**: 2026-11-19 11:57 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 4 found three must-fix, all quick: stray committed files and two false sentences in design.md; this is the host's second address in a row at this checkpoint, so the next answer here is the owner's)
**After**: rounds
**Decision**: address

Round 4 confirmed both round 3 must-fix gone and the fixer's --keep-going choice sound. Its three must-fix are fixed as follows. (1) The colcon log files committed under tools/repos-manifest/log/ are removed from the branch. (2) design.md says what --packages-skip-build-finished really does (colcon skips every package whose most recent build finished, whichever run that was, so changed sources of such a package are not rebuilt) and that a layer recorded after such a run means every package has been built at some point, not that it is up to date; the code is not changed. (3) design.md says that only a build of that layer without package selection brings back a layer lost to a rejected argument. The three suggestions are fixed too: the report says "rebuilt with selection" in a selection run; the selection refusal separates layers that are not built from layers whose repos differ from their record; the clause about the "new since" note that now describes nothing is removed or corrected.

## Implementation
**Status**: complete
**When**: 2026-11-19 12:04 -05:00
**By**: claude-code (claude-opus-5-5)
**Dispatch**: resumed (agent a87bbb2d0d4e6df83, resume 3 of 3)

**Branch**: feature/issue-501 at `153db946`
**Addressed**: Local Review (Pre-Push) at `7d8e5261` (2026-11-19 11:57 -05:00), with the Checkpoint of 2026-11-19 11:57 -05:00
**Commits**: e3c53245, 153db946

### Actions
- [x] (must-fix) The four colcon log files under `tools/repos-manifest/log/` are removed by `git rm` (e3c53245). Their `logger_all.log` records `/usr/bin/colcon version-check` at 11:36:24, after my round 2 hand-back (11:34) and during the round 3 review (entry 11:41); none of my commands ran `version-check`, and they reached the branch through my `git add -A tools/repos-manifest` in dfbd1936. I now stage files by name. No test writes there: every colcon a test starts runs in a layer directory under pytest's tmp_path (checked: after the whole suite no `log/`, `build/` or `install/` directory is in the worktree). `git diff --stat origin/main...HEAD` lists no other non-source file (plan.md and progress.md, the CI workflow, docs, src, tests, the stub fixture, the adapter)
- [x] (must-fix) design.md says what `--packages-skip-build-finished` does (colcon reads each package's last result in `build/` and skips every package whose last build finished, whichever run; checked in colcon-package-selection's source) and that a record after it says only that every package was built at some point. Hand run with real colcon: a changed source of `x` was not rebuilt ("0 packages finished"), and after `x` failed and was fixed the dependent `y` was left on its old build. No code change; README makes no such claim — `docs/design.md`
- [x] (must-fix) design.md says only a build of that layer without package selection brings back a layer lost to an argument colcon rejected; hand run: `--packages-sel x` (colcon exit 2) lost top, `-- --packages-select x` was refused as not built, plain `build top` restored it — `docs/design.md`
- [x] (suggestion) The report says "rebuilt with selection: X" in a selection run — `build.py` `report`, `Progress.selection`
- [x] (suggestion) The selection refusal names "not built: ..." apart from "built, but its repos differ from its record: ...", and says for the second kind that a build without selection records the change — `build.py` `not_built_for_selection`
- [x] (suggestion) The "new since" clause is gone; the sentence now says the time keeps saying when the whole layer was last built without selection — `docs/design.md`

### Re-reading the build section
Each sentence that states what happens was traced to a test or a hand run. Already covered by tests: the record and its shape, setup.bash before and after each layer and on each way a run ends, the lock and its messages, the built run and refusals, named layers, failure and `--keep-going`, the report lines, PATH handling, prefix warnings, stop signals, Ctrl-Z, hangup, reaping, argument refusals and order, `--merge-install`, the selection rules, resolving selection, resuming. Run by hand now with the real colcon: (1) jobs in a new session cannot open `/dev/tty` ("No such device or address" under a pty, while the same command in the session opens it); (2) `--packages-skip-build-finished` skipping a changed package; (3) the stale dependent after a failed and fixed dependency; (4) a layer lost to `--packages-sel` refused for a corrected selection and restored by a plain build; (5) a `colcon_defaults.yaml` with `install-base` in the layer: colcon exits 0, the layer is "not built" naming the missing `install/setup.bash`, and removing the file and building restores it. Changes made on re-reading: the package-selection bullet and two paragraphs reflowed; no other false sentence found.

### Tests
Each code fix has a test that fails with the fix reverted (2 reverted copies, both caught).
- Tool suite: `REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest` — `1107 passed in 202.70s` (real colcon, none skipped)
- After the suite: no `log/`, `build/` or `install/` directory in the worktree; `git status --porcelain` empty after the commits
- No workspace script or adapter changed, so no `.agent/scripts/tests` suite applies; pre-commit (SKIP=validate-script-tests) on the changed files clean; the full pass was left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 12:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-501 at `6ce07fb1`
**Base**: main
**Depth**: Deep (reason: round 5 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 5 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: round 4's findings and the fix diff `7d8e5261..6ce07fb1` (e3c53245, 153db946). Cross-model: skipped (round-5 convergence check, per handoff). Run: tool suite `1107 passed in 219.22s` (`REPOS_MANIFEST_REQUIRE_COLCON=1`, real colcon); pre-commit (black, flake8, the rest) on build.py, test_build.py and design.md clean; a fresh Claude adversarial specialist held to the same scope (no must-fix); by hand with `/usr/bin/colcon` in a scratch system (base layer with x and y, y needing x; top with t needing y). Worktree clean after the suite.

Round 4's six, re-checked: (1) gone: `git ls-files tools/repos-manifest/log` is empty and `git diff --stat origin/main...HEAD` lists only source, tests, the stub fixture, docs, the work plan, the CI workflow and the adapter. (2) true: after x's CMakeLists changed, `build _unnamed -- --packages-skip-build-finished` built nothing ("0 packages finished"), exit 0, and the layer was recorded built; after x failed and was fixed, the same option rebuilt x and skipped its dependent y. (3) true: after `-- --packages-sel t` (colcon exit 2), top lost its record; `-- --packages-select t` was refused as not built; a plain `build top` restored it. (4) true: `build -- --packages-select y` reports "rebuilt with selection: _unnamed, top", and the records are unchanged; test asserts it and that "  built:" is absent. (5) true: by hand the not-built kind is named "not built: top (recorded built, but .../install/setup.bash is missing)"; the test covers the changed kind alone and both kinds together. (6) the "new since" clause is gone; the sentence now there (the time says when the whole layer was last built without selection) holds, since a selection run gives back the record unchanged (seen by hand). The adversarial specialist confirmed each new assertion would fail with the fix reverted.

### Findings
- [ ] (suggestion) With both kinds in the selection refusal, the two steps name the higher layer first (`build top`, then `build mid`); followed in that order, top is built on mid's old output. One step naming all affected layers in manifest order would avoid it — `tools/repos-manifest/src/repos_manifest/build.py:500-517`
- [ ] (suggestion) "built, but its repos differ from its record" reads wrongly when it names two or more layers — `tools/repos-manifest/src/repos_manifest/build.py:510`
- [ ] (suggestion) The stop-signal line ("layers built in this run") and the line used when the record cannot be read still say "built" in a selection run — `tools/repos-manifest/src/repos_manifest/build.py:856,964`
- [ ] (suggestion) The record's time "still says when the whole layer was last built without selection" is loose after a `--packages-skip-build-finished` run, which the next bullet says does not make the layer up to date; "last recorded built" would be exact — `tools/repos-manifest/docs/design.md:910-911`
