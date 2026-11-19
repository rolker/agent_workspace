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

## Plan Authored
**Status**: complete
**When**: 2026-11-19 14:59 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-531/plan.md` at `e9c7c366`

The four skip and ignore options stop counting as selection (only unambiguous spellings); the record gains an optional `without` mapping (option to values, last occurrence of a repeat wins as in colcon); the report says "built without" and names a changed list, which keeps the layers above. Documents and tests (stub and real colcon) change in the same PR.

## Plan Review
**Status**: complete
**When**: 2026-11-19 15:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #531 — repos-manifest build: --packages-skip on a layer's first build is refused
**Plan**: `.agent/work-plans/issue-531/plan.md` at `e9c7c366`
**Branch**: `feature/issue-531`

Checked with the real `/usr/bin/colcon` (colcon-core 0.21.3, colcon-package-selection 0.2.10, Python 3.14.4) on a scratch system of CMake packages a; b needs a (`find_package`); c needs b; d alone. `colcon list` for the spellings, `colcon build` for what is installed.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, four files plus tests, inside `tools/repos-manifest/`. |
| Issue alignment | Needs work | Every issue line and every Issue Review action is covered, except the empty value list (finding 1). Serves: "Trust, control and information" and "Easy to use" (workspace goals in `README.md`), under `tools/repos-manifest/docs/design.md#build`; both goals and the `### build` heading exist. |
| File targeting | Good | `build.py`, `system.py`, both test files, design.md, README. `sync.py` and `state.yaml` are untouched; issue 500's part 2 only calls `read_built`, which still reads every record it read before. |
| Consequences | Good, one gap | The colcon-defaults bullet, the `colcon_defaults.yaml` bullet and `_defaults_note` speak of "package selection" set in a defaults file; a skip set there is not in `without` (note 1). |
| Principle alignment | Good | Verified claims, tests with each rule, design.md in the same change. |
| ADR compliance | Good | ADR-0022 (inside the part), ADR-0017 (design in the same change), ADR-0013 (entries). |
| ROS conventions | N/A | Workspace tool; no ROS interfaces change. |

What real colcon does, against the plan:
- Exact, `=value`, abbreviation: `--packages-skip b`, `--packages-skip-r ^b$`, `--packages-skip-re=^b$` and `--packages-ignore- ^b$` each leave b out; `--packages-ig`, `--packages-s` and `--packages-skip-` exit 2 as ambiguous. Agrees with the plan's classification through `_could_be`.
- Repeats: `--packages-skip a --packages-skip d` built and installed a, b, c, leaving out only d; `--packages-skip a b --packages-skip c` listed a, b, d. Last occurrence wins, confirmed; distinct dests (skip, skip-regex, ignore, ignore-regex) combine, and an abbreviation and the full name share one dest (`--packages-skip-regex ^d$ --packages-skip-r ^a$` left out only a), so writing names in full before taking the last is right.
- `--packages-skip=a b`: colcon exits 2 ("unrecognized arguments: b"); the layer fails, nothing is recorded. Fine.
- Beside `--packages-select`, and beside `--packages-skip-build-finished` (also as `--packages-skip-bu`): both act; the plan's handling matches.
- Dependents: `--packages-skip b` and `--packages-ignore b` on a fresh layer: c fails in `find_package(b)`, exit 1, not built. On a layer whose `install/` already held b: exit 0, c built against the old b, and `install/` still held a, b, c, d. The plan's words (the list is what the last run left out, not what `install/` holds; no claim of checking dependents) are true.

### Findings

1. **[Issue alignment / record]** (needs-work) — The four options take zero or more values (`nargs='*'`): `--packages-skip` alone skips nothing, and `--packages-skip b --packages-skip` skips nothing either (real `colcon build` installed a, b, c, d). The plan reads values "up to the next argument starting with `-`" and keeps the last occurrence, which gives `{--packages-skip: []}`; step 3 writes `without:` whenever the mapping is not empty, and `read_built` then refuses a list that is empty, so the next `build` of the distro stops with "repair or remove it", and removing the file loses every layer's record. If instead empty occurrences are dropped before the last is taken, the record says `[b]` when colcon left out nothing. Resolution: say in step 2 that the last occurrence is taken first and an option whose last occurrence has no values is not in the list (nothing left out), and add stub tests for `--packages-skip` alone (recorded built with no `without`) and `--packages-skip b --packages-skip` (no `without`).

### Notes for the implementer

1. A skip set in a colcon defaults file or a mixin is not seen and not in `without`. design.md's paragraph on the field says it holds the left-out options given after `--`; the defaults bullet, the `colcon_defaults.yaml` bullet and `_defaults_note` ("package selection ... is recorded built as a whole") are reworded so they still cover a skip set there.
2. The report already has "built without sourcing <layer> (failed), so not used: ..."; a new line beginning "built without: ..." reads close to it. A distinct wording ("built leaving out:") avoids a reader, or a test matching a prefix, confusing the two.
3. `-1` as a regex value: argparse takes it as a value (colcon has no negative-number options), while the plan's "starts with `-`" rule ends the list before it. Harmless with finding 1 fixed (the option drops out of the record); worth one sentence or leaving the regex rule as colcon's.
4. Say whether "built without:" is printed for a layer built with `--keep-going` but not used; it should be, since its record holds the list.
5. design.md is also being edited for issue 500 in other sections ("sync", "the system directory"); expect a textual merge, not a conflict in substance.
6. The older-tool refusal is acceptable for an unreleased command, and design.md stating it is enough; `format` 1 is right since the new tool still reads every record it read before.

### Summary

The classification, the record field, the changed-list rule and the document changes are right and match real colcon. One gap would write a record the tool then refuses (or a false list): an option given with no values. One sentence in step 2 and two stub tests close it.

### Recommended Actions

- [ ] State in step 2 that the last occurrence is taken first and an option whose last occurrence has no values is left out of `without`; add stub tests for `--packages-skip` alone and `--packages-skip b --packages-skip`.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 15:03 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's one needs-work finding is a gap in how an option with no values is read; mechanism)
**After**: plan
**Decision**: revise

The host takes the Plan Review's finding and six notes as written. An option's last occurrence is taken first, and an option whose last occurrence has no values is not recorded, since colcon then leaves nothing out; stub tests for --packages-skip alone and for --packages-skip b --packages-skip. Notes: design.md says the field holds the options given after --, and the three texts about a defaults file or mixin are reworded to cover a skip set there; the new report line is worded "built leaving out:" so it cannot be mixed up with "built without sourcing"; a value that starts with - ends the list, which is harmless; the line is printed for a layer built under --keep-going but not used too; design.md says an older tool refuses a record that has the field; format stays 1.

## Plan Authored
**Status**: complete
**When**: 2026-11-19 15:04 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-531/plan.md` at `831c2a10`

Revision after the plan review: the last occurrence of an option is taken first and one with no values is not recorded; the report line reads "built leaving out:" (also for a layer built under --keep-going but not used); design.md and the defaults-file texts say the field holds the options given after `--`; stub tests for the no-value shapes and a write-then-read round trip.

## Plan Review
**Status**: complete
**When**: 2026-11-19 15:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #531 — repos-manifest build: --packages-skip on a layer's first build is refused
**Plan**: `.agent/work-plans/issue-531/plan.md` at `831c2a10`
**Branch**: `feature/issue-531`

Second review, of the revision after the Plan Review at `e9c7c366` and the Checkpoint that followed it. Read: the diff `e9c7c366..831c2a10` of the plan, then the revised plan once whole.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one PR; `_defaults_note` added to the `build.py` row. |
| Issue alignment | Good | The earlier finding is resolved (below). Serves: "Trust, control and information" and "Easy to use" (workspace goals in `README.md`), under `tools/repos-manifest/docs/design.md#build`. |
| File targeting | Good | Same files; `sync.py`, `state.yaml` and issue 500's parts stay out. |
| Consequences | Good | The defaults-file and mixin texts are now in step 7. |
| Principle alignment | Good | Each rule has a test; the round trip covers the write and read sides together. |
| ADR compliance | Good | ADR-0022, ADR-0017, ADR-0013 as before. |
| ROS conventions | N/A | Workspace tool. |

Earlier finding and notes, checked against `831c2a10`:
- Finding 1 (empty value list): resolved. Step 2 takes the last occurrence of each option first and leaves out an option whose last occurrence has no values; step 3 says `left_out` never returns an option with no values, so a written `without` always passes `read_built`, with a write-read-build test. Step 6 has stub tests for `--packages-skip` alone and `--packages-skip b --packages-skip` (recorded built, no `without`, no line).
- Note 1 (defaults file, mixin): resolved. Step 7 says the field holds the options given after `--`, and the colcon-defaults bullet, the `colcon_defaults.yaml` bullet and `_defaults_note` are reworded to say a skip set there is not seen nor recorded.
- Note 2 (wording): resolved. Every quotation of the line reads "built leaving out:" (steps 5, 6 and 7); "built without" now appears only where the plan names the existing "built without sourcing" line.
- Note 3 (`-1` as a value): addressed in step 2 (see note 1 below).
- Note 4 (`--keep-going`): resolved in step 5, with a test in step 6.
- Note 5 (merge with issue 500): unchanged, nothing to do in the plan.
- Note 6 (older tool, `format`): resolved; step 7 has design.md say an older tool refuses a record with the field, and `format` stays 1.

No inconsistency introduced: a list dropped by a trailing empty occurrence on a layer that had one is reported "skip list changed: ... now none", as step 5 already says for a dropped list; a selection run still writes `had` unchanged.

### Findings

None blocking.

### Notes for the implementer

1. Step 2's aside "colcon then rejects or reads it its own way" is loose: argparse takes a value like `-1` (it looks like a negative number) and keeps reading, so `--packages-skip-regex -1 x` leaves out what `x` matches while the plan's rule records nothing for that option. A regex starting with `-1` cannot match a package name, which starts with a letter, so only that contrived order loses a value. Either stop at an argument starting with `-` that is not a negative number, as argparse does, or keep the rule and say this case in the design.md bullet; one sentence either way.
2. Step 6's `test_system.py` line "an empty list is not written" now overlaps the round-trip test in step 3; one test of each is enough.

### Summary

The revision closes the one gap and the six notes as the Checkpoint decided, without making anything else inconsistent. Ready for implementation.

### Recommended Actions

- [ ] None before implementation; the notes are for the implementer.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 15:05 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second plan review: ready, two notes)
**After**: plan
**Decision**: proceed

The two notes go to the implementer: a value list ends only at an argument that starts with - and is not a number, as colcon reads it, so --packages-skip-regex -1 x is recorded as given; one of the two overlapping "empty list is not written" tests is enough.
