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

## Implementation
**Status**: complete
**When**: 2026-11-19 15:19 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-531 at `87bca0cb`

What changed (one commit, `87bca0cb`):
- `build.py`: `--packages-skip`, `--packages-skip-regex`, `--packages-ignore`, `--packages-ignore-regex` (the full name, or an abbreviation that stands for one of them only) are no longer package selection, so a run with them builds a layer that is not built yet. New `left_out()` reads them as colcon does (last occurrence of an option counts, `=value` takes one value, an option whose last occurrence has no values is dropped). A non-selection run writes the list into the layer's record; a selection run gives back the record it had, list unchanged. Report lines "built leaving out:", "skip list changed:" (with the stale-`install/` caveat when the run now leaves something out) and "not recorded, given with package selection: ...". `_defaults_note` says a skip set in a defaults file is not recorded either.
- `system.py`, only these: `LayerRecord` (new `without` field, default empty), a new constant `LEFT_OUT` beside it (the four options; `system.py` cannot import `build.py`), `read_built` (accepts the optional `without` key, checked by a new helper `_read_without`: a non-empty mapping of the four options to non-empty lists of strings; control characters checked in keys and values) and `put_built_layers` (writes `without` only when it is not empty). The lock holder message, `state.yaml` and `sync.py` are not touched.
- Tests: stub tests in `tests/test_build.py` (first build with a list, the layer above builds on it, the same list again, another list, a dropped list, every way of writing the options, the no-value shapes, the cases still refused, a selection run beside a recorded list, `--keep-going`, a written record read back, the defaults note) and two real-colcon tests (the issue's case through a three-layer system; the last occurrence counts). `tests/test_system.py`: an old record, a write-read round trip (which also shows that an empty list is not written), and seven malformed `without` shapes. Every new test fails against the code at `65bf43d5` except the eight "still refused" cases, which guard behaviour that stays.
- `docs/design.md`: the record sample and a paragraph on `without`, the selection bullet, the warn-only bullet, a new "Packages left out" bullet, the defaults and `colcon_defaults.yaml` bullets, the report passage, the rebuilt-in-place sentence. `README.md`: the sentence on package selection.

Departure from the plan: a value list ends at an argument colcon reads as one of its own options (`--`, an option of `colcon build` or an abbreviation of one, `-h`), not at any argument starting with `-`. Checked with the real colcon (colcon-core 0.21.3, colcon-package-selection 0.2.10, Python 3.14.4): colcon's parser turns an argument it does not recognise into a value, so `--packages-skip-regex ^a$ -DX ^b$`, `... --foo ...`, `... -.5 ...`, `... - ...` and `... -1 ...` all built and left out a and b, with a warning for the odd value. `--packages-skip` and `--packages-ignore` then reject such a value with exit 2 (`--packages-skip b -DX`, `--packages-ignore ^a$ -1 ^b$`), so the layer fails and nothing is recorded. This matches the checkpoint's note (`--packages-skip-regex -1 x` records both values) and goes one step further.

Tests: `cd tools/repos-manifest && REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest -p no:cacheprovider` gave `1189 passed in 276.60s` (1151 before, 38 new, real-colcon tests run). `tests/test_documents.py` ran again after the last document edit: `11 passed`. No workspace script changed, so no `.agent/scripts/tests/` suite applies; the full pre-commit pass is left to the host.

By hand, real colcon, a system made with `repos-manifest init` from local file remotes (unnamed layer: `base`; `mid`: `broken`, which fails in CMake, and `core`, which needs `base`; `top`: `app`, which needs `core`), the tool run through `repos_manifest.cli:run`:
- `build -- --packages-select core` on the fresh system: refused, "a run with package selection builds only part of a layer ... not built: _unnamed (not built), mid (not built), top (not built); nothing was run", exit 1.
- `build -- --packages-skip broken`: "built: _unnamed, mid, top", "built leaving out: _unnamed, mid, top (--packages-skip broken)", "setup.bash: sources top", exit 0. Each record has `without: {--packages-skip: [broken]}`; `mid/install` holds `core` and no `broken`; `top` (`app`, which finds `core`) built on it.
- `build mid -- --packages-skip broken` again: "built leaving out: mid (--packages-skip broken)", "built before, in the run: _unnamed, top (on the earlier output of mid)", no "changed" line; the list in the record is the same.
- `build mid -- --packages-skip-regex '^bro'`: "skip list changed: mid (was --packages-skip broken, now --packages-skip-regex '^bro'); what an earlier build installed of a package left out now is still in <sys>/mid/install/", top still in the built run; the record holds `--packages-skip-regex: [^bro]`.

Documents: every changed sentence in `docs/design.md` and `README.md` re-read against the code and the colcon checks above; neither names the workspace adapter (`tests/test_documents.py` passes).

### For the pull request body

`repos-manifest build` now accepts `--packages-skip`, `--packages-skip-regex`, `--packages-ignore` and `--packages-ignore-regex` after `--` on a layer's first build. They build the whole layer except the packages named, so they are no longer treated as package selection. A layer whose colcon exits 0 is recorded as built, and its record gets an optional `without` field holding the options as given: each option in full, its values as typed, a regex as text, and only the last occurrence of a repeated option, as colcon reads it. Records written before this change still read; an older version of the tool refuses a record that has the field, so the field is written only when something was left out.

Everything else stays strict. `--packages-select` and the other selection options are still refused on a layer that is not built, and so is a skip given beside one of them. `--packages-skip-by-dep`, `--packages-skip-up-to` and `--packages-skip-test-passed` stay selection, because what they leave out comes from the dependency graph or from test results in `build/`, not from a list a record can hold. An abbreviation that could stand for several options (`--packages-s`, `--packages-ig`), which colcon rejects as ambiguous, is still refused before anything runs.

The closing report says "built leaving out: <layers> (<options>)", worded differently from the existing "built without sourcing ..." line. When a layer's list differs from its record's, it says "skip list changed: <layer> (was ..., now ...)", and the layers above stay in the built run, as for any rebuild in place on the same chain. A selection run keeps each layer's recorded list and says that skip options given with it are not recorded.

Two caveats. The tool does not check what depends on a package left out: colcon builds a dependent anyway, and a dependent that needs the package fails in its own build, so the layer is not built, as without a list. The list says what the last run left out, not what `install/` holds: colcon does not clean `install/`, so a package an earlier build installed stays there after a later run leaves it out. The "skip list changed" line says so.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 15:40 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-531 at `6b33f161`
**Base**: origin/main
**Depth**: Deep (reason: ~960 lines across 8 files; changes the on-disk record format read by every build)
**Must-fix**: 3 | **Suggestions**: 4
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) A left-out value holding a control character (`--packages-skip $'grid\nmap'`, a tab in a regex) is written into `built-<distro>.yaml`, which `read_built` then refuses ("holds a control character; repair or remove it"): reproduced with real colcon, the run exits 1 after colcon built and every later `build` is refused until the file is repaired. Refuse such values (and values not encodable as UTF-8: `$'grid\xffmap'` gives "internal error (UnicodeEncodeError)" in the report) in `refused_arguments` before anything runs, with a test that the old record survives — `tools/repos-manifest/src/repos_manifest/build.py:639`, `system.py:607`
- [x] (must-fix) Every layer the run builds is recorded and reported as "built leaving out" the given list, also a layer that has none of the packages: reproduced `built leaving out: _unnamed, mid (--packages-skip grid_map_demos grid_map)` and, on a later plain `build`, `skip list changed: _unnamed (was --packages-skip grid_map_demos grid_map, now none)` for a layer with no grid_map. The report line and design.md ("`without` holds the options ... that left named packages out of the layer", "the layers built leaving packages out") are false for such a layer; reword report and documents to say these are the options given to the layer's colcon, whether or not the layer has the packages — `tools/repos-manifest/src/repos_manifest/build.py:1186`, `tools/repos-manifest/docs/design.md:746`
- [x] (must-fix) design.md says a package no longer left out "was missing when they [the layers above] were built, so they did not use it"; the same paragraph says `install/` is not cleaned, so a package installed before the run that skipped it was still there and the layers above may have used it. Reword — `tools/repos-manifest/docs/design.md:1036`
- [x] (suggestion) The value list ends only at an option in the static `COLCON_BUILD_OPTIONS`; an option from a colcon extension not in it (`--meson-args`, `--cargo-args`) is swallowed into the record as skip values while colcon reads it as an option. Ending a `--packages-skip`/`--packages-ignore` list at any `--x` (colcon rejects such a name anyway) narrows this; or document the limit — `tools/repos-manifest/src/repos_manifest/build.py:627`
- [x] (suggestion) colcon `lstrip()`s `--packages-skip`/`--packages-ignore` values (colcon_package_selection/argument.py); the record keeps `' foo'`, so `foo` -> `' foo'` prints a false "skip list changed" — `tools/repos-manifest/src/repos_manifest/build.py:639`
- [x] (suggestion) "not recorded, given with <selection>" is printed even when every layer of the selection run failed (its record was removed, not given back) — `tools/repos-manifest/src/repos_manifest/build.py:1200`
- [x] (suggestion) The stale-install note on "skip list changed" is printed when the list only shrank, where nothing newly left out can be stale — `tools/repos-manifest/src/repos_manifest/build.py:1193`

## Implementation
**Status**: complete
**When**: 2026-11-19 16:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-531 at `8df0f714`
**Addressed**: Local Review (Pre-Push) at `6b33f161` (2026-11-19 15:40 -05:00)
**Commits**: 4a00ff45, db009e78, 5475f89b, 9514e7b5, 0bd2af4b, 9dc5473f, 211042b0, 8df0f714 (box checks: 369cb220)

### Actions
- [x] (must-fix 1) A skip or ignore value holding a control or invisible character, or not UTF-8, is refused in `refused_arguments` before the lock, the record or colcon is touched, with the option named and the value shown escaped (`'grid\x0amap'`, `'grid\xffmap'`); tests: a newline, a tab in a regex, a non-UTF-8 byte, a bidirectional override beside selection, each leaving the record and `setup.bash` byte for byte and printing no report; and a property test that builds with 56 awkward values under `--packages-skip` and `--packages-ignore-regex` and reads every record back (20 of them fail without the fix) — `tools/repos-manifest/src/repos_manifest/build.py` (`refused_values`, `_shown`), `4a00ff45`
- [x] (must-fix 2) Report and documents say the options were given to colcon, whether or not the layer has such packages: "built with <options> given to colcon: <layers>" and "skip and ignore options given to colcon changed: <layer> (was ..., now ...)"; options print as colcon arguments joined by spaces; every test quoting the lines updated, and a test for a layer with none of the packages — `build.py` `report`, `system.py` comments and one reader message, `docs/design.md`, `README.md`, `db009e78`
- [x] (must-fix 3) design.md: the layers above stay in the built run because a changed list is an ordinary rebuild in place on the same chain; a package now left out may still be in `install/`, one no longer left out may also have been there from before, so the layers above may or may not have used it, and `build` does not check — `docs/design.md`, `5475f89b`
- [x] (suggestion a) A `--packages-skip`/`--packages-ignore` value list ends at any argument starting with `-`; `-regex` lists end only at an option `build` knows; design.md states the limit — `build.py` `left_out`, `9514e7b5`, `8df0f714`
- [x] (suggestion b) Package names are recorded with leading whitespace stripped, as colcon strips them; patterns as given — `build.py` `left_out`, `0bd2af4b`
- [x] (suggestion c) The "not recorded, given with ..." line is printed only when the run built a layer — `build.py` `report`, `9dc5473f`
- [x] (suggestion d) The stale-install note is added only when the options name a package or pattern the old ones did not (a name counts once whether skipped or ignored; patterns compared as text) — `build.py` `_newly_given`, `211042b0`

### Notes
Departures: the refusal uses the tool's own `has_unsafe_char` rule (the one manifest names and values follow), broader than control characters: it also refuses invisible and bidirectional characters, non-ASCII spaces and private-use code points, since a value holding one is printed in report lines and package names never hold one. `read_built` itself is unchanged (it still refuses only C0 controls and DEL), so the refusal is stricter than the reader, which keeps the property. "The report printing its lines twice" did not reproduce (in-process, through a pipe and on a pseudo-terminal, the non-UTF-8 path printed the report head once and then "internal error (UnicodeEncodeError)"); that path no longer exists, since the value is refused before anything runs, and the refusal tests assert no report is printed at all.

colcon checks (colcon-core 0.21.3, colcon-package-selection 0.2.10, `colcon list` on a three-package workspace): an unknown `--foo`, `--meson-args` or `-x` after `--packages-skip`/`--packages-ignore` is read as a value and rejected ("unrecognized argument: --foo", nothing built); after a `-regex` form it is taken as a pattern and colcon goes on. So where colcon builds, a package-name list never holds a value starting with `-`, and the new rule matches colcon in every such case; with an extension that has the option, colcon reads it as an option and the tool now ends the list there too. For `-regex` lists the tool still records an unknown extension option as a pattern (design.md says so). `--packages-skip " alpha"` and `--packages-ignore $'\talpha'` skip `alpha`; `--packages-skip-regex " ^alpha"` skips nothing: colcon strips leading whitespace from names only.

Tests: `cd tools/repos-manifest && REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest -p no:cacheprovider` gave `1315 passed in 385.97s` (1189 before; 126 new, 112 of them the parametrized property test). Each fix's new tests were run against the code without it and failed. No workspace script changed, so no `.agent/scripts/tests/` suite applies; the full pre-commit pass is left to the host. `sync.py`, the lock holder message and `state.yaml` handling are untouched.

Documents: each changed sentence of `tools/repos-manifest/docs/design.md` and `README.md` re-read against the code and the colcon checks above.

### For the pull request body

The closing report names the skip and ignore options as what colcon was given, since a run gives them to every layer it builds, including one that has none of the packages they name:

- `built with --packages-skip x y given to colcon: _unnamed, mid`
- `skip and ignore options given to colcon changed: mid (was --packages-skip y x, now --packages-skip z); what an earlier build installed of a package they skip or ignore now stays in <system>/mid/install/` (the note only when the options name a package or pattern the old ones did not)
- `skip and ignore options given to colcon changed: mid (was --packages-skip z, now none)`
- `not recorded, given with package selection: --packages-skip y (a run that builds only part of a layer gives each layer back the record it had)` (only when the run built a layer)

A record's `without` holds the skip and ignore options given to the layer's colcon when it was last built, as colcon read them, whether or not the layer has such packages. A list of package names ends at any argument starting with `-` and is recorded with leading whitespace stripped, as colcon reads it; a list of patterns is recorded as given and ends only at an option colcon is known to have, so an option of an unlisted colcon extension after a `-regex` list is recorded as patterns (documented). A skip or ignore value holding a control or invisible character, or not UTF-8, is refused before anything runs, e.g. `ERROR: the --packages-skip value 'grid\x0amap' holds a control or invisible character, which the layer's record cannot hold as one line of text; nothing was run. Give the package name or pattern in plain text`; the record and `setup.bash` are untouched.

When a layer is rebuilt with another list, the layers above stay in the built run, because that is an ordinary rebuild of the layer in place on the same chain; a package now left out may still be in its `install/` from an earlier build, and one no longer left out may also have been there from before, so the layers above may or may not have used it, and `build` does not check.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 16:29 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent aacb37fd465dca92c, resume 1 of 3)

**Branch**: feature/issue-531 at `37edd856`
**Base**: origin/main
**Depth**: Deep (reason: whole branch diff ~1320 lines across 8 files; changes the on-disk record format read by every build)
**Must-fix**: 0 | **Suggestions**: 5
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round 1's three must-fix are fixed and re-checked with real colcon: `--packages-skip $'grid\nmap'` and `$'grid\xffmap'` are refused before anything runs, with no record written; on a run that builds three layers, of which only `mid` has the packages, the report reads `built with --packages-skip grid_map_demos grid_map given to colcon: _unnamed, mid, top`; the design.md sentence on the layers above now says they may or may not have used the package. Every fix's rule, reverted in a copy of the tool, fails its new test (8 of 8 mutants caught). Full suite: 1315 passed. black and flake8 pass.

### Findings
- [ ] (suggestion) A `--packages-skip`/`--packages-ignore` value whose control or line-separator characters are leading whitespace (`$'\nfoo'`, `$' foo'`, `$'\n'`) is stripped to `foo`/`''` and not refused. That matches colcon (`argument_package_name` returns `value.lstrip()`), and the record round-trips, but the design.md sentence "A value that holds a control or invisible character ... is refused" should say "as colcon reads it, after leading whitespace is stripped" — `tools/repos-manifest/docs/design.md:1045`, `build.py:661`
- [ ] (suggestion) README and design.md say the record keeps the options given "when it was last built"; a selection run rebuilds part of a layer and gives back the old record, so it is the last build that was not a selection — `tools/repos-manifest/README.md:116`, `tools/repos-manifest/docs/design.md:746`
- [ ] (suggestion) A `-regex` pattern that starts with `--packages` (`--packages-skip-regex --packages-x`) makes `package_selection` read the run as selection, because `_option_names` takes every `--` argument as an option name, although colcon takes it as a pattern and `left_out` records it as one. This errs on the safe side (refused on an unbuilt layer); either skip the values `left_out` consumes or note the exception — `tools/repos-manifest/src/repos_manifest/build.py:801`
- [ ] (suggestion) `read_built` checks `without` with `_CONTROL` (C0 and DEL) while the command line refuses with `has_unsafe_char`, so a hand-edited record holding `‮`, `\x9b` or a lone surrogate is read and printed in the "changed" line (a surrogate raises UnicodeEncodeError). Only a hand edit can produce it — `tools/repos-manifest/src/repos_manifest/system.py:608`
- [ ] (suggestion) Where colcon-mixin is not installed, colcon takes a `--mixin` after a `-regex` list as a pattern while `left_out` ends the list there, so the record holds fewer patterns than colcon used. design.md states only the reverse case (an unlisted extension's option recorded as patterns); add this one — `tools/repos-manifest/docs/design.md:1037`
