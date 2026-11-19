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
