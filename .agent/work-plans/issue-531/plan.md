# Plan: repos-manifest build refuses --packages-skip on a layer's first build

## Issue

https://github.com/rolker/agent_workspace/issues/531

## Context

`package_selection` in `tools/repos-manifest/src/repos_manifest/build.py` reads every
`--packages-` option except `--packages-skip-build-finished` as package selection, so a run
with `--packages-skip` is refused on a layer with no record. With the real colcon (Issue Review
entry in `progress.md`), `--packages-skip`, `--packages-skip-regex`, `--packages-ignore` and
`--packages-ignore-regex` build the whole layer minus the named packages and install the rest.
Checked again for this plan with colcon on plain CMake packages: a repeated option does not
add up, colcon keeps the last occurrence (`--packages-skip a --packages-skip b` left out only
b; `--packages-skip a b --packages-skip c` only c); skip and ignore together combine;
`--packages-skip=a` takes one value; an ambiguous abbreviation (`--packages-ig`) is rejected
by colcon; `--packages-skip-r` reads as `--packages-skip-regex`.

## Approach

1. **Classify** (`build.py`) — a constant `LEFT_OUT` of the four options. An option is "left
   out" only when `_could_be(name)` is exactly one option and it is in `LEFT_OUT` (so
   `--packages-skip`, `--packages-skip-r`, `--packages-skip-re`, `--packages-ignore-regex`, and
   the `=value` forms). A prefix that could be several options (`--packages-s`,
   `--packages-skip-`, `--packages-i`, `--packages-ig`, which colcon rejects as ambiguous)
   stays selection as now, so a run that colcon would reject is refused before anything
   runs on a layer with no record, never recorded. `--packages-skip-build-finished` and its
   unambiguous prefixes (`--packages-skip-bu...`) stay the resume option. `--packages-skip-by-dep`,
   `--packages-skip-up-to`, `--packages-skip-test-passed` stay selection: what they leave out
   comes from the dependency graph or from test results in `build/`, not from a list. Any other
   selection option beside a skip makes the run selection, so `--packages-skip x --packages-select y`
   on a layer with no record is refused as now.
2. **Read the list** (`build.py`, new `left_out(colcon_args)`) — returns a mapping of the
   full option name to its values, for the options classified above. Values are the arguments
   up to the next argument starting with `-`; the `=` form has one value. Following colcon, a
   repeated option keeps its last occurrence; different options (skip beside ignore) are all
   kept. Values are kept as given (a regex stays text, not the names it matched). Option
   names are written in full, so an abbreviation and the full name give the same record.
3. **Record field** (`system.py`) — `LayerRecord` gains `without: Dict[str, List[str]]`
   (default empty). `put_built_layers` writes `without:` only when it is not empty.
   `read_built` adds `without` to the optional keys of `_check_keys`; absent means empty, so
   an old record reads as before. It must be a mapping whose keys are among the four options
   and whose values are non-empty lists of strings; the control-character check covers the
   keys and values. Anything else is a `bad(...)` error naming the file and the key, like
   the other fields. `format` stays 1. An older version of the tool, whose `_check_keys` has
   no optional key, reads such a file as "`layers.<layer>.without` is not read by this
   version" and refuses it ("repair or remove it"); that is stated in design.md, and is why
   the new tool writes the field only when a list was given.
4. **Build** (`build_layers`) — a run that is not selection writes the record with the list
   `left_out(colcon_args)` gave, whatever it is. A run with selection writes back `had`
   unchanged, so a recorded list stays as it was, and a skip list given beside the
   selection is not recorded (the run was refused on a layer with no record; on a built one it
   only rebuilds part). The report says so for such a run: "skip options given with package
   selection are not recorded". `--packages-skip-build-finished` with a skip list is not
   selection, so the list is recorded as for any non-selection run; it says what this run
   left out, and an earlier run that did not skip the package may have built it (the same
   stale-install caveat). Progress gets `without` (layer to list for layers built in this
   run) and `without_changed` (layer to (was, now), only when the layer had a record and the
   lists differ as sets of (option, set of values)).
5. **Report** — `built without: <layer> (--packages-skip a b; --packages-ignore-regex ^x$)`
   for each layer built in the run with a list, and `skip list changed: <layer> (was
   --packages-skip a, now --packages-skip c)` when it changed (`none` when the list was
   dropped), beside the lines for repos added or dropped. A changed list is an ordinary rebuild
   of the layer on the same chain, so `why_not_built` is not touched and the layers above stay
   in the built run: a package newly left out stays installed from the earlier build, and a
   package newly unskipped was missing when they were built, so they did not use it. No text
   says the tool checks dependents of a left-out package: colcon builds one anyway, and it
   fails only in its own build step, so the layer is not built then, as without a skip. The
   report and design.md say the list is what the last run left out, not what `install/`
   holds, since colcon does not clean `install/` (checked: `--packages-skip b` then
   `--packages-skip d` left a, b, c, d installed).
6. **Tests** (`tests/test_build.py`, `tests/test_system.py`; stub colcon and, marked
   `colcon`, the real one with `packages_system`):
   - stub: first build with `--packages-skip x` records built with `without`; a layer above
     builds on it; the same list again leaves the list unchanged and prints no "changed"
     line; another list prints the change and the layers above stay built (not "not used");
     `--packages-ignore` likewise; the regex forms record the option text; abbreviation
     `--packages-skip-r` records `--packages-skip-regex`; `--packages-ig` and
     `--packages-s` on a layer with no record are refused; `--packages-skip-by-dep`,
     `-up-to` and `-test-passed` are still refused there.
   - skip beside `--packages-select` on a layer with no record is refused; `--packages-select`
     alone is still refused; on a built layer a selection run keeps the recorded list and
     the report says a given skip list is not recorded.
   - repeats and several values: stub test that `--packages-skip a --packages-skip b` records
     only `[b]`, `--packages-skip a b` records both, `--packages-skip=a` one, skip beside ignore
     both options; one real-colcon test confirming the last occurrence wins (the order of
     installed packages).
   - `--packages-skip-build-finished` with a skip list records the list.
   - `test_system.py`: an old record without the field reads with empty `without`; one with it
     round-trips; a non-mapping, an unknown option key, an empty list, a non-string and a
     control character are each an error naming the file; an empty list is not written.
   - real colcon: a first build with `--packages-skip` records the list, the skipped package is not
     installed, a layer above builds, and a changed list is reported.
7. **Documents** (`tools/repos-manifest/docs/design.md`, `README.md`) — design.md:
   the record's YAML sample and the paragraph after it (the optional `without` field, its
   meaning, how an old record and an older tool treat it); the sentence "Package selection,
   any `--packages-` option but `--packages-skip-build-finished`, is passed too" (selection is
   any `--packages-` option but the resume option and the four left-out options; the three
   skip-by-... options and why); the bullet on options that only warn (skip and ignore
   move out of "selection options"); a new bullet for the left-out options (classification,
   abbreviations, repeats, last occurrence wins, regex as text, the stale-install caveat, no
   check of dependents, the `--packages-skip-build-finished` and selection-run cases); the
   report passage (the two new lines) and the sentence that a layer rebuilt in place keeps the
   layers above it (a changed list is another case of it). README: the sentence "A run with
   package selection or `--cmake-target` after `--` only rebuilds layers that are built" gets
   "(not `--packages-skip` or `--packages-ignore`, which leave named packages out of a whole
   layer and are recorded)".

## Files to Change

| File | Change |
|------|--------|
| `tools/repos-manifest/src/repos_manifest/build.py` | `LEFT_OUT`, classification, `left_out`, record, report, Progress |
| `tools/repos-manifest/src/repos_manifest/system.py` | `LayerRecord.without`, `read_built`, `put_built_layers` |
| `tools/repos-manifest/tests/test_build.py`, `test_system.py` | the tests of step 6 |
| `tools/repos-manifest/docs/design.md`, `README.md` | step 7 |

## Prior Art

The existing `RESUMING` carve-out in `package_selection` is the pattern taken: one option kind
let through, by `_could_be`, so abbreviations resolve as colcon does. The built record's
optional-key handling in `_check_keys` is reused. A manifest-side list of skipped packages is
issue 532, not built here.

## Serves

"Trust, control and information" and "Easy to use" (workspace goals in `README.md`), under
`tools/repos-manifest/docs/design.md#build`.

## Design Picture

Changes the part's own design, `tools/repos-manifest/docs/design.md#build` (ADR-0022); no change
to the root `docs/design.md`.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Verify before claiming | Option behavior, repeats and stale `install/` checked with real colcon; documents say what was checked |
| Tests with the fix | Stub and real colcon, old-record and older-tool cases |
| Only what's needed | Ignore pair added because colcon builds the same layer; 532 and the workspace adapter stay out |
| Keep one current design | design.md changes in the same change |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0022 | Yes | Change stays inside the part and its design |
| ADR-0017 | Yes | design.md updated in the same change |
| ADR-0013 | Yes | `progress.md` entries |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `package_selection` | refusal text, tests quoting "package selection" for skip runs | Yes |
| `built-<distro>.yaml` shape | design.md sample, `read_built`, older-tool note | Yes |
| `sync.py`, lock holder message, `state.yaml` (issue 500 part 2, in parallel) | Not touched | Out of scope |

## Open Questions

- None blocking. The record's `format` stays 1 (an older tool refuses the file either way).

## Estimated Scope

Single PR.
