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
