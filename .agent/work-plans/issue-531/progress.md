---
issue: 531
---

# Issue #531 — repos-manifest build refuses --packages-skip on a layer's first build

## Issue Review
**Status**: complete
**When**: 2026-11-19 14:55 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #531

### Scope Assessment

**Well-scoped?** Yes — one behavior change in one tool (`repos-manifest build`): which `--packages-` options count as building part of a layer, plus a record field and a report line. One short plan and one pull request are enough. The pieces (option classification, record field, report, tests with stub and real colcon, design.md and README) are one concern and cannot be released apart. Issue 532 (a manifest that says which packages a distro leaves out) is a separate issue and out of scope; this issue only has to leave it a record field to read.
**Right repo?** Yes — `tools/repos-manifest/` in the workspace repo (`build.py`, `system.py`, its `docs/design.md` and README).
**Serves**: "Trust, control and information" (the record says what a layer was built without) and "Easy to use" (a layer that only builds minus some packages is built by the tool, not by hand-placed `COLCON_IGNORE` files) — `tools/repos-manifest/docs/design.md#build`; at the root, `docs/design.md#the-parts` is unchanged.
**Design picture?** No change to the root design; changes the part's own design, `tools/repos-manifest/docs/design.md#build` (the package-selection bullets and the "built run" passage), which the issue already says it updates (ADR-0022 keeps this inside the part).
**Dependencies**: none identified. 532 builds on this one, not the reverse.

Claims in the issue, checked:
- The refusal is real. `package_selection` in `build.py` treats every `--packages-` option except `--packages-skip-build-finished` as selection, and `not_built_for_selection` refuses it on a layer with no record, with the message quoted in the issue. design.md ("build", the bullet starting "Package selection, any `--packages-` option but `--packages-skip-build-finished`") says the same. Its other bullet already states that `--packages-skip` and `--packages-ignore` only warn about a name a layer does not have.

What colcon does (real `/usr/bin/colcon`, scratch system of packages a; b needs a; c needs b; d alone; `ament_python`, with `exec_depend` and again with `depend`):
- `--packages-skip b`, `--packages-skip-regex ^b$`, `--packages-ignore b`, `--packages-ignore-regex ^b$`: each builds a, c, d, installs only those, exits 0 and writes `install/setup.bash`. The layer is the whole layer minus the packages the list names. They can be given together (`--packages-skip b --packages-skip-regex ^d$` built a and c). An unknown name only warns ("ignoring unknown package") and exits 0, so the list is not checked against the layer.
- The ignore pair gives the same build as the skip pair. They differ in that ignore drops the package from discovery, as the `COLCON_IGNORE` workaround does (b is absent from `colcon list`), so they belong with skip as "named packages left out". The issue does not name them; the plan should decide to include them, and say so, since they are the same kind.
- `--packages-skip-by-dep a` and `--packages-skip-by-dep c` skipped nothing in the scratch system, and `--packages-skip-up-to c` skipped only c. What they leave out follows from the dependency graph in the sources, not from names the user wrote. `--packages-skip-test-passed` skipped nothing (it reads test results left in `build/`). None of these is a fixed list, so a record of the option cannot say what the layer holds: they stay selection, as the issue proposes, with this as the reason.
- Rebuilding in the same `install/` with a different list does not clean up: after `--packages-skip b` then `--packages-skip d`, `install/` held a, b, c and d. The package newly skipped stays installed from the earlier build, so the record of a skip list says what the last run left out, not what `install/` holds. design.md ("build") already says the same for repos that left a layer. The report and design text should not claim more than that.

A skipped package that another package needs:
- colcon does not stop or warn: with b skipped, c (which needs b) still ran, finished and the run exited 0, whether the dependency was `exec_depend` or `depend`. A dependent fails only where its own build step needs the missing package (for example CMake `find_package`), and then colcon exits 1 and the layer is not built, as without a skip. With `--keep-going` the layers above it are not tried, as design.md already states. A package in a layer above that needs a skipped package behaves the same way, since colcon sees one layer at a time. So the tool cannot know of the problem and should not pretend to: the record and the closing report say "built without: <list>", and they should not say that nothing needs those packages. This is what the owner already faces by hand with `grid_map`, where the skip list names both the demos and the metapackage that depends on it.

The record and the built run:
- `LayerRecord` holds `time`, `repos` and `below`, and `read_built` checks the file to exactly the shape `put_built_layers` writes. A skip field has to be optional in reading, absent meaning no list, or every existing record reads as bad and every layer is rebuilt. The plan has to say how an old record and a record with the field are told apart, and add tests for both.
- The built-run rule compares layer names only (`why_not_built`: record present, `install/setup.bash` present, `below` equal to the run below). A changed skip list does not alter that chain, and design.md says a layer rebuilt in place on the same chain keeps the layers above it, as a changed repo set does. So parity says: do not take the layers above out of the run. This holds: a newly unskipped package was missing when the layers above were built, so they did not use it; a newly skipped one stays installed. The plan should state that decision and its reason, and the report should name the change ("skip list changed: was a b, now c") as it does for repos added or dropped. The decision on the report line is the one the issue leaves open; the recommendation is to report it.
- A regex in the list: record the option text as given, not the package names it matched; the names depend on what is in the layer then, and recording text avoids a field that goes stale.

Edge cases the plan must cover, since they decide whether the rule is whole:
- A run that also has another selection (`--packages-skip x --packages-select y`) is selection and stays refused on a layer with no record; the new rule applies only when every package option is skip, skip-regex, ignore or ignore-regex (or `--packages-skip-build-finished`).
- Abbreviations (colcon accepts them; `package_selection` already reads them through `_could_be`): an abbreviation that could be a skip option and a selection option is not a skip and must stay selection or be refused as ambiguous.
- Values: `--packages-skip a b` takes several values up to the next option, `=` form takes one, and repeating an option should be tried with real colcon (not tried here) before the plan says the record holds both occurrences or the last.
- A skip list of the same names in the same order or in another: compare as sets.
- A run that skips a package in a layer where it does not exist: colcon warns only. The layer is still recorded built with the list as given, since the run is one for all layers (`build -- --packages-skip x` over every layer).
- `--packages-select` on a layer with no record is still refused: say so in a test, as the issue's acceptance already does.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Verify before claiming | Action needed | design.md and README must say what colcon does for each skip-like option, checked as above (colcon-core version stated, as the existing bullets do), including that a skipped package's dependents are not stopped. |
| Keep one current design | OK | The part's own design (`tools/repos-manifest/docs/design.md#build`) is updated in the same change, as the issue states; the root design is not touched. |
| Tests with the fix | Action needed | Acceptance asks for stub and real colcon tests; add the edge cases above (old record without the field, abbreviations, mixed skip and select, list changed) as tests too. |
| Only what's needed | Watch | The ignore pair is not in the issue; include it only because it is the same kind and one classification covers it. 532 (the manifest side) stays out. |
| Safeguards earn their cost | OK | The refusal for selection stays; only a fixed-list kind of option is let through. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0022 (parts with their own design) | Yes | The change stays inside `tools/repos-manifest/` and its design; the root design is unchanged. |
| ADR-0017 (design kept current) | Yes | Same-change design update; the issue already names it. |
| ADR-0013 (review timeline) | Yes | This entry; later phases append theirs. |

### Consequences

- `tools/repos-manifest/docs/design.md` ("build": the package-selection bullets, the resolving-options bullet that lists skip and ignore as warn-only, the built-run passage, the report text) and the README passage about package selection change together.
- Any text or test that quotes the refusal message or "rebuilt with selection" for a skip-only run changes.
- Records written before this change must still read, and `status` or any other reader of `built-<distro>.yaml` must tolerate the new field.

### Recommendations

- Treat `--packages-skip`, `--packages-skip-regex`, `--packages-ignore` and `--packages-ignore-regex` as one kind, "named packages left out" (the ignore pair is not in the issue; colcon builds the same layer with it); keep `--packages-skip-by-dep`, `--packages-skip-up-to` and `--packages-skip-test-passed` as selection, because what they leave out follows from the dependency graph or from test results in `build/`, not from a list.
- Record the skip options as the user gave them (regex as text, not matched names) in an optional record field, so records written before this change still read, and state in design.md that the list is what the last run left out, not what `install/` holds (colcon does not remove an earlier build's packages).
- State that a changed skip list is an ordinary rebuild on the same chain and keeps the layers above in the built run (the chain compares layer names), and have the report name the change as it does repos added or dropped.
- Say in the report and in design.md that colcon does not check the dependents of a skipped package: such a package either builds or fails in its own build, and a failing layer is not built as without a skip; the tool does not claim otherwise.
- Keep the plan and the pull request to one each, and name issue 532 as out of scope in the plan.
- Add the edge-case tests above (old record, abbreviation, skip mixed with select, repeated option tried with real colcon) to the acceptance tests.

### Actions
- [ ] design.md and README must say what colcon does for each skip-like option, checked as above (colcon-core version stated, as the existing bullets do), including that a skipped package's dependents are not stopped.
- [ ] Acceptance asks for stub and real colcon tests; add the edge cases above (old record without the field, abbreviations, mixed skip and select, list changed) as tests too.
- [ ] Treat `--packages-skip`, `--packages-skip-regex`, `--packages-ignore` and `--packages-ignore-regex` as one kind, "named packages left out" (the ignore pair is not in the issue; colcon builds the same layer with it); keep `--packages-skip-by-dep`, `--packages-skip-up-to` and `--packages-skip-test-passed` as selection, because what they leave out follows from the dependency graph or from test results in `build/`, not from a list.
- [ ] Record the skip options as the user gave them (regex as text, not matched names) in an optional record field, so records written before this change still read, and state in design.md that the list is what the last run left out, not what `install/` holds (colcon does not remove an earlier build's packages).
- [ ] State that a changed skip list is an ordinary rebuild on the same chain and keeps the layers above in the built run (the chain compares layer names), and have the report name the change as it does repos added or dropped.
- [ ] Say in the report and in design.md that colcon does not check the dependents of a skipped package: such a package either builds or fails in its own build, and a failing layer is not built as without a skip; the tool does not claim otherwise.
- [ ] Keep the plan and the pull request to one each, and name issue 532 as out of scope in the plan.
- [ ] Add the edge-case tests above (old record, abbreviation, skip mixed with select, repeated option tried with real colcon) to the acceptance tests.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 14:55 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the eight open actions are inputs to the plan; none changes the issue's scope)
**After**: issue-actions
**Decision**: proceed

The Issue Review confirmed the claim and tried each skip-like option with the real colcon. The host takes its findings as the plan's content: the skip pair and the ignore pair (--packages-skip, --packages-skip-regex, --packages-ignore, --packages-ignore-regex) build a whole layer minus named packages and stop counting as building part of a layer; the other three (--packages-skip-by-dep, --packages-skip-up-to, --packages-skip-test-passed) stay selection, since what they leave out comes from the dependency graph or from test results; the record gains an optional field holding the option text as given; a changed list is an ordinary rebuild that keeps the layers above and is named in the report; the report says "built without" and does not claim the tool checks dependents; design.md and the README say what colcon does. Adding the ignore pair is within the issue's own line "the other skip options are looked at one by one".
