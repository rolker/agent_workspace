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
