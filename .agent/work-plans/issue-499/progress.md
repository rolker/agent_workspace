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
