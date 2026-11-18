---
issue: 498
---

# Issue #498 — repos-manifest: the resolver reads the format in the spec

## Issue Review
**Status**: complete
**When**: 2026-11-18 13:05 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #498

### Scope Assessment

**Well-scoped?** No, as one pull request. It rewrites the schema, merge, selector, emit and validate code (about 1,700 source lines and 2,700 test lines, all for the old shape), adds three location readers with their safety rules, and converts the adapter's fixtures. Cut it into three pull requests, each leaving the tool and the adapter working (details in Recommendations). Old and new manifests are told apart by shape (`repositories:` against the old `repos:` / `extends:` / `ref`), not by `format:`, because the spec makes an absent `format` mean 1.
**Right repo?** Yes. The tool is in `tools/repos-manifest/`, in the workspace repo; the adapter and its tests are too. The issue text still says `tools/ros-manifest/` (before the rename in #497); the plan should use the new paths.
**Serves**: Modular (the tool is a module the workspace uses; the owner's aim of exercising the new design on project11), design section `tools/repos-manifest/docs/design.md#commands` (`resolve`) and `#what-is-built`; the format is `tools/repos-manifest/docs/spec.md`. The root design `docs/design.md` is not changed beyond what `docs/manifest/design.md` says about the adapter's route.
**Design picture?** Changes `tools/repos-manifest/docs/design.md#what-is-built` (the prototype paragraph becomes false as parts land) and `docs/manifest/design.md` "The manifest route, step by step" (the resolver call, and what `optional_layers.txt` means). The first is the part's own design (ADR-0022) and is updated in the same change (ADR-0017). The second needs the owner's decision on the optional-layer question below, so ask it on its own.
**Dependencies**: #497 (merged). Blocks #499 to #503. #503 (thin adapter) replaces the adapter route this issue keeps alive. Also touches #447 (open hardening list for untrusted input) because the rules it tracks are rewritten here.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | `design.md#what-is-built` and `docs/manifest/design.md` describe the prototype and the adapter's call; update them in the pull request that changes what they describe. `prototype.md` is removed or rewritten only in the last part, when the old reader goes, so the documents never describe code that is not there. |
| Ask about what matters | Action needed | Two questions are the owner's, not the implementer's: how a repo's `optional` becomes the adapter's layer-level `optional_layers.txt`, and the on-disk name of the unnamed layer in the adapter's layout (see Recommendations). The issue says to raise spec gaps, so list them before the plan, not during coding. |
| Verify before claiming | Watch | Two tool tests fail on main under Python 3.14.4 (`test_an_extends_path_too_long_is_a_message_without_the_path`, both parametrizations; 331 pass). The cause is read in `extends.py` `resolve_chain`/`_resolve_one`: on 3.14 `Path.resolve()` no longer raises for the long name, so the later error is "extends path not found: <the whole path>", which prints the manifest's own value (the test's secret) where the test wants "(File name too long)". This is a real leak of a manifest value into an error, not only a test problem. CI runs 3.10, so it is green there. |
| Only what's needed | Watch | The resolver keeps `--cache-dir` only because the adapter passes it (and a test asserts the log line). Drop it from the adapter in the same part that removes the cache, not by keeping a dead option. |
| A safeguard has to earn its cost | Watch | The spec's safety list is long; each rule needs a test (the issue says so), and the checks that need a real destination (symlink, case-insensitive collision) cannot be tested at `resolve` time beyond the output directory. Say which rules are tested where. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0022 (a part owns its inside) | Yes | The tool's design is the part's; the root's design changes only where the adapter's call or output crosses the boundary. |
| ADR-0017 (design is the current picture) | Yes | See the Keep one current design row. |
| ADR-0011 (adapter contract) | Yes | The adapter's manifest route must keep its tests passing at every part. |
| ADR-0009 (venv for dev tools) | Watch | Tests run from the repo's venv or `PYTHONPATH=src`; the tool test run in this review needed `PYTHONPATH=src` because the package is not installed in the system Python. |

### Consequences

- `.github/workflows/validate.yml` job "repos-manifest tests (#267 prototype)" and the adapter-contract job: the name may change, and both run on Python 3.10 while the failing tests show on 3.14; consider a 3.14 job, or fix the code so both agree.
- `Makefile` `install-repos-manifest` and `.agent/knowledge/script_reference.md`/`build_and_test.md` if they mention the old format; `tools/repos-manifest/README.md`, `docs/roadmap.md` lines 29 to 32 (the check column for the migration note, the new-format and drop-the-old-things lines).
- `docs/manifest/design.md` (adapter route text, "Installing the resolver"), `docs/manifest/roadmap.md`.
- `.agent/scripts/tests/test_ros2_colcon.sh`: `write_mr_manifest` and the `extends`-based tests (`test_mr_extends_base_no_user_hooks_or_filters`, `test_mr_stale_extends_base`, the resolver-failure tests) move to the new format and `base`.
- The existing fixture `tests/fixtures/p11/{manifest.yaml,expected/}` is in the old format and stays until the old reader goes; the new fixture is made from the draft.

### Recommendations

- Cut the issue into three pull requests, each green. Part 1 (tool only, additive): the new-format reader for a single manifest, with no `base`. Covers the superset shape, versions and distros, layers, groups and roles, the safety rules for a single file, the per-layer `.repos` output with provenance, whole-or-nothing output, `validate`, a plain `.repos` file resolving to itself, and the project11 fixture (6 expected outputs: three roles by two distros) plus the Python 3.14 fix. The CLI reads whichever shape it is given; the old reader and the adapter are untouched. Part 2 (tool only): `base` (one or a list; path, http(s) URL, file in a git repo; reading order, each manifest once, cycle error, key-by-key merge, new entries complete, git clone safeguards, no parent cache), still additive, tested with local and `file://` git bases. Part 3 (adapter and removal): the new reader writes the `--layout manifest-dir` output (`layers.txt`, `optional_layers.txt`, `repos/<layer>.repos`) and the adapter's fixtures and tests are converted; then the old reader, `packages:` and the dependency check, `roots`, the parent cache and `--cache-dir`, optional layers and group defaults and `add`/`subtract` are deleted; `prototype.md` is rewritten to describe the code as it is; the migration note goes in. Part 3 depends on the owner's answers below.
- Answer the existing-user question as: this resolver keeps writing the manifest-dir layout from a new-format manifest, and the adapter test fixtures are converted in part 3. Do not keep the old reader past part 3: the issue removes the features the old format's tests cover. The note for an instance on an old-format manifest: convert the manifest (repos out of the layer nesting into one `repositories:` list with `layer:`, `ref` becomes `version`, `extends` becomes `base`, `optional_layers` becomes `optional: true` on repos, group `default` and role `add`/`subtract`/`roots` become groups and roles as lists), then run `sync`; until then it fails with a message that names this note. Say whether the old reader is refused with that message or kept for one release; the plan should pick refusal, since an instance has the resolver editable-installed from the same checkout.
- Ask the owner (spec gap, adapter-facing): the new format marks repos optional, the adapter's `optional_layers.txt` and its `validate`/`setup` skip layers. Options: a layer goes in `optional_layers.txt` when every repo in it is optional (works for project11, where `ccomjhc_project11` is alone in `site`, and loses the repo-level meaning for mixed layers, so a mixed layer must be refused or have its optional repos reported another way), or the resolver also writes the optional repo names to a new file the adapter reads (an adapter change, so it belongs with #503). Pick before part 3.
- Raise these spec gaps in the plan and in a comment on the owner, as the issue requires; do not guess. (1) The name of the unnamed first layer on disk: design says `_unnamed.repos`, the spec says its directories are `src`/`build`/`install`/`log`, and the adapter builds `layers/main/<layer>_ws` and reads a layer name from `layers.txt`, so `_unnamed` would give `_unnamed_ws`; the draft names every layer, so the project11 fixture does not need it, but a plain `.repos` file does ("resolves to itself in one layer"). (2) "Checked on the real destination" (links, names the disk treats as the same): `resolve` only writes into `--out`, so state which of those checks run at `resolve` and which wait for `init`/`sync` (#500). The prototype also refused names differing only in case across the chain; the spec does not. (3) `url` values: the spec allows `https` with embedded user and token and puts urls into provenance comments and error messages; the prototype refused credentials. Decide whether credentials in a url are refused, and whether a url or version value may be printed in an error. (4) Relative `base` path from a manifest that is itself at a URL or in a git repo: "from the directory of the manifest that names it" is defined for a local file only; the git `path` may not contain `..`, so it cannot reach a sibling; the design's "reads the parent from the local disk too" covers only the local-in-repo case. (5) Identity of a manifest for "each read once" and "builds on itself": the same file by two spellings (a symlink, `./a` and `a`), or the same git repo at two versions. (6) `distros:` absent but a `distros:` key on a repo: is "absent" judged per file or on the merged chain? A later manifest of a one-distro base would otherwise be refused. The same question for `roles:` and "a role is required". (7) Types: `version` or `url` as a number (`version: 1.10` reads as 1.1), `type` other than `git`, an unknown key inside a repo entry, an empty `distros:` entry (`jazzy:` with a null value, which the spec says counts), a role or `groups` given as a string. State the rule for each; the prototype required strings. (8) Name rules: the spec allows upper case in a distro and `-` first-letter-only starts; the prototype allowed `:` in a group (`hw:deltat`). Names in the project11 draft all satisfy the spec's rule. (9) Provenance comment "saying where each came from": per repo, or per file? For a git-located manifest, the commit that was read is the useful identity (the prototype wrote `url#ref:path@commit`); the spec does not say. (10) "Resolved output replaced whole or not at all": a directory cannot be replaced atomically by `rename` when it exists and is not empty; say whether write-to-a-sibling-then-swap-by-two-renames (a short window with neither) is acceptable, or the output is a link to a generated directory as the adapter does. (11) `git` clone behaviour: the design lets git and ssh ask for a password at a terminal and fail without one; the prototype forbade prompts and killed the process group on timeout and signal. State which of the prototype's protections stay (no hooks, no filters, transport allow-list, timeout) for `base` git locations; the issue lists "Remove ... the parent cache" but not these.
- The project11 fixture: copy the draft to `tests/fixtures/p11/manifest.yaml` (the draft is gitignored scratch, so copy it, do not link) and generate the six expected outputs by hand-checking against the old fixture's `expected/jazzy` and `expected/rolling` (the draft was made mechanically from the same layer files, with the `developer` role switching on every group, so `developer` on `jazzy` should reproduce the 44 repos of the old `expected/jazzy`). The draft has 44 repos, one `distros:` block (`unh_marine_autonomy`'s `rolling` branch), one `optional: true` (`ccomjhc_project11`, layer `site`), seven layers, nine groups. NOTES.md says the group names are the author's guesses and the released URLs are not final, so name the fixture's source and date, and keep it as test data that does not need to follow later changes to the real manifest.
- Add tests for the rules that are easy to leave out because the draft does not use them: `absent: true` on the repo with and without a distro entry (an empty entry counts), `distros: {}` replacing a base's block, a later `optional: false` or `absent: false` undoing an earlier one, a base listed twice through two parents (the diamond order `C, A, B, manifest`), a manifest that builds on itself directly and through another, `base` as a list, and every refusal in "Reading a manifest before using it", one test each, including the bidirectional-character and `name::address` cases.
- Fix the 3.14 failures in part 1 by making the error message independent of `Path.resolve()` raising: check the length and existence of the base path before use, and never print the manifest's own path value; keep the test's secret check, and run the tool tests on 3.10 and 3.14. Do not weaken the test.
- Before part 3, run the adapter suite (`.agent/scripts/tests/test_ros2_colcon.sh`) with the new resolver on the original fixtures converted one by one, and list which `test_mr_*` tests assert resolver behaviour (hooks, filter drivers, a commit as `extends.ref`, timeouts) that moves with the old code; a test that no longer applies is removed with a line saying why, not left skipped.

### Actions
- [ ] `design.md#what-is-built` and `docs/manifest/design.md` describe the prototype and the adapter's call; update them in the pull request that changes what they describe. `prototype.md` is removed or rewritten only in the last part, when the old reader goes, so the documents never describe code that is not there.
- [ ] Two questions are the owner's, not the implementer's: how a repo's `optional` becomes the adapter's layer-level `optional_layers.txt`, and the on-disk name of the unnamed layer in the adapter's layout (see Recommendations). The issue says to raise spec gaps, so list them before the plan, not during coding.
- [ ] Cut the issue into three pull requests, each green. Part 1 (tool only, additive): the new-format reader for a single manifest, with no `base`. Covers the superset shape, versions and distros, layers, groups and roles, the safety rules for a single file, the per-layer `.repos` output with provenance, whole-or-nothing output, `validate`, a plain `.repos` file resolving to itself, and the project11 fixture (6 expected outputs: three roles by two distros) plus the Python 3.14 fix. The CLI reads whichever shape it is given; the old reader and the adapter are untouched. Part 2 (tool only): `base` (one or a list; path, http(s) URL, file in a git repo; reading order, each manifest once, cycle error, key-by-key merge, new entries complete, git clone safeguards, no parent cache), still additive, tested with local and `file://` git bases. Part 3 (adapter and removal): the new reader writes the `--layout manifest-dir` output (`layers.txt`, `optional_layers.txt`, `repos/<layer>.repos`) and the adapter's fixtures and tests are converted; then the old reader, `packages:` and the dependency check, `roots`, the parent cache and `--cache-dir`, optional layers and group defaults and `add`/`subtract` are deleted; `prototype.md` is rewritten to describe the code as it is; the migration note goes in. Part 3 depends on the owner's answers below.
- [ ] Answer the existing-user question as: this resolver keeps writing the manifest-dir layout from a new-format manifest, and the adapter test fixtures are converted in part 3. Do not keep the old reader past part 3: the issue removes the features the old format's tests cover. The note for an instance on an old-format manifest: convert the manifest (repos out of the layer nesting into one `repositories:` list with `layer:`, `ref` becomes `version`, `extends` becomes `base`, `optional_layers` becomes `optional: true` on repos, group `default` and role `add`/`subtract`/`roots` become groups and roles as lists), then run `sync`; until then it fails with a message that names this note. Say whether the old reader is refused with that message or kept for one release; the plan should pick refusal, since an instance has the resolver editable-installed from the same checkout.
- [ ] Ask the owner (spec gap, adapter-facing): the new format marks repos optional, the adapter's `optional_layers.txt` and its `validate`/`setup` skip layers. Options: a layer goes in `optional_layers.txt` when every repo in it is optional (works for project11, where `ccomjhc_project11` is alone in `site`, and loses the repo-level meaning for mixed layers, so a mixed layer must be refused or have its optional repos reported another way), or the resolver also writes the optional repo names to a new file the adapter reads (an adapter change, so it belongs with #503). Pick before part 3.
- [ ] Raise these spec gaps in the plan and in a comment on the owner, as the issue requires; do not guess. (1) The name of the unnamed first layer on disk: design says `_unnamed.repos`, the spec says its directories are `src`/`build`/`install`/`log`, and the adapter builds `layers/main/<layer>_ws` and reads a layer name from `layers.txt`, so `_unnamed` would give `_unnamed_ws`; the draft names every layer, so the project11 fixture does not need it, but a plain `.repos` file does ("resolves to itself in one layer"). (2) "Checked on the real destination" (links, names the disk treats as the same): `resolve` only writes into `--out`, so state which of those checks run at `resolve` and which wait for `init`/`sync` (#500). The prototype also refused names differing only in case across the chain; the spec does not. (3) `url` values: the spec allows `https` with embedded user and token and puts urls into provenance comments and error messages; the prototype refused credentials. Decide whether credentials in a url are refused, and whether a url or version value may be printed in an error. (4) Relative `base` path from a manifest that is itself at a URL or in a git repo: "from the directory of the manifest that names it" is defined for a local file only; the git `path` may not contain `..`, so it cannot reach a sibling; the design's "reads the parent from the local disk too" covers only the local-in-repo case. (5) Identity of a manifest for "each read once" and "builds on itself": the same file by two spellings (a symlink, `./a` and `a`), or the same git repo at two versions. (6) `distros:` absent but a `distros:` key on a repo: is "absent" judged per file or on the merged chain? A later manifest of a one-distro base would otherwise be refused. The same question for `roles:` and "a role is required". (7) Types: `version` or `url` as a number (`version: 1.10` reads as 1.1), `type` other than `git`, an unknown key inside a repo entry, an empty `distros:` entry (`jazzy:` with a null value, which the spec says counts), a role or `groups` given as a string. State the rule for each; the prototype required strings. (8) Name rules: the spec allows upper case in a distro and `-` first-letter-only starts; the prototype allowed `:` in a group (`hw:deltat`). Names in the project11 draft all satisfy the spec's rule. (9) Provenance comment "saying where each came from": per repo, or per file? For a git-located manifest, the commit that was read is the useful identity (the prototype wrote `url#ref:path@commit`); the spec does not say. (10) "Resolved output replaced whole or not at all": a directory cannot be replaced atomically by `rename` when it exists and is not empty; say whether write-to-a-sibling-then-swap-by-two-renames (a short window with neither) is acceptable, or the output is a link to a generated directory as the adapter does. (11) `git` clone behaviour: the design lets git and ssh ask for a password at a terminal and fail without one; the prototype forbade prompts and killed the process group on timeout and signal. State which of the prototype's protections stay (no hooks, no filters, transport allow-list, timeout) for `base` git locations; the issue lists "Remove ... the parent cache" but not these.
- [ ] The project11 fixture: copy the draft to `tests/fixtures/p11/manifest.yaml` (the draft is gitignored scratch, so copy it, do not link) and generate the six expected outputs by hand-checking against the old fixture's `expected/jazzy` and `expected/rolling` (the draft was made mechanically from the same layer files, with the `developer` role switching on every group, so `developer` on `jazzy` should reproduce the 44 repos of the old `expected/jazzy`). The draft has 44 repos, one `distros:` block (`unh_marine_autonomy`'s `rolling` branch), one `optional: true` (`ccomjhc_project11`, layer `site`), seven layers, nine groups. NOTES.md says the group names are the author's guesses and the released URLs are not final, so name the fixture's source and date, and keep it as test data that does not need to follow later changes to the real manifest.
- [ ] Add tests for the rules that are easy to leave out because the draft does not use them: `absent: true` on the repo with and without a distro entry (an empty entry counts), `distros: {}` replacing a base's block, a later `optional: false` or `absent: false` undoing an earlier one, a base listed twice through two parents (the diamond order `C, A, B, manifest`), a manifest that builds on itself directly and through another, `base` as a list, and every refusal in "Reading a manifest before using it", one test each, including the bidirectional-character and `name::address` cases.
- [ ] Fix the 3.14 failures in part 1 by making the error message independent of `Path.resolve()` raising: check the length and existence of the base path before use, and never print the manifest's own path value; keep the test's secret check, and run the tool tests on 3.10 and 3.14. Do not weaken the test.
- [ ] Before part 3, run the adapter suite (`.agent/scripts/tests/test_ros2_colcon.sh`) with the new resolver on the original fixtures converted one by one, and list which `test_mr_*` tests assert resolver behaviour (hooks, filter drivers, a commit as `extends.ref`, timeouts) that moves with the old code; a test that no longer applies is removed with a line saying why, not left skipped.

## Checkpoint
**Status**: complete
**When**: 2026-11-18 13:00 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the Issue Review's actions are about how the issue is cut and about gaps in the spec that the owner's recorded decisions already answer; none changes what the work is for; each host choice below is listed for his veto)
**After**: issue-actions
**Decision**: proceed

The host, running /orchestrator, read the Issue Review. Instructions for the plan:

Delivery. Three pull requests on this one issue, each leaving the tool and the adapter working, as the review proposes: (1) a reader for a single new-format manifest with no base, its per-layer output, validate, and the project11 fixture, added beside the old reader; (2) base: the three location forms, the reading order, the cycle error, the merge rules; (3) the new reader writes the layout the adapter reads, the adapter's fixtures and tests are converted, the old reader and the dropped features are removed, prototype.md is rewritten or removed, and the note on moving from the old format is written. The plan covers all three and names the parts; each part but the last says "Part of #498".

The tool's tests pass on Python 3.14 as well as on CI's Python at the end of part 1. The owner's machine runs 3.14 and the project11 test happens there.

Spec gaps, settled by the host from what the owner already decided. Each part updates tools/repos-manifest/docs/spec.md or design.md where it settles one, so the documents say what the code does:
- An error message may print a value from the manifest. The owner dropped the rule against it on 2026-11-17 ("Reading a manifest before using it" lists what a tool checks; this is not on it).
- Credentials in a url are not looked for or refused, for the same reason; the workspace's design already says so.
- resolve checks the rules that can be checked on the text (names, keys, no key inside another, transports, options). The check on the real destination belongs to init and sync, which write there.
- A relative base path is taken from where the naming manifest is: beside it on disk; in the same repo at the same version for a manifest in a git repo; relative to its URL for one at a URL.
- A manifest is identified by its resolved location (an absolute path, a URL, or a repo URL with version and path) for "read once" and "builds on itself".
- "No distros:" is judged on the merged chain, like every other rule that reads the result of combining.
- url, type and version are strings; an unknown key on a repo is warned about and kept out of the output, as an unknown top-level key is.
- Names follow the spec's rule (a single word: letters, digits, _ and -, starting with a letter). Names the prototype allowed and the spec does not are refused.
- The comment at the head of each output file says which manifest, role, distro and extra groups it came from.
- Output is written to a new directory beside the target and moved into place, so it is replaced whole or not at all.
- Reading a base from a git repo keeps the time limit on git calls and the transport rule, uses git as it is set up on the machine, and lets git or ssh ask for a password at a terminal. The no-hook, no-filter and no-prompt guards go, by the owner's decision of 2026-11-17 on how far the tool's checks go. No parent cache is kept between runs.

The existing user (part 3). The adapter keeps reading layers.txt, optional_layers.txt and repos/<layer>.repos. In that layout a layer is listed as optional when every repo in it is optional, and the unnamed layer is written as _unnamed. An old-format manifest is refused with a message that points at the note on moving. Optional repos inside a layer that also has required repos are not expressible in that layout; say so in the note, and leave the per-repo form to the thin adapter (issue 503).

## Plan Authored
**Status**: complete
**When**: 2026-11-18 13:40 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-498/plan.md` at `b9ed981a`

Three pull requests: (1) a reader for one new-format manifest with its per-layer output, validate, the project11 fixture (private repo renamed) and the 3.14 fix, beside the old reader; (2) base in its three location forms with reading order and merge; (3) the manifest-dir layout, converted adapter fixtures, removal of the old reader and the note on moving. Ten open questions for the owner are listed in the plan, each with a default.

## Plan Review
**Status**: complete
**When**: 2026-11-18 13:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #498 — repos-manifest: the resolver reads the format in the spec
**Plan**: `.agent/work-plans/issue-498/plan.md` at `b9ed981a`
**Branch**: `feature/issue-498`
**Serves**: Goal: Modular (`README.md#modular`; the tool is a module the workspace uses, and the owner's aim is to exercise the new design on project11). Design: `tools/repos-manifest/docs/design.md#resolve` and `#what-is-built`; the format is `tools/repos-manifest/docs/spec.md`; adapter route `docs/manifest/design.md` "The manifest route, step by step". Checked: `README.md` has `### Modular` (line 71); the tool's design has `### resolve` and `## What is built`.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three PRs, as the Checkpoint ordered. Each part is additive until part 3, and old and new manifests are told apart by a top-level `repositories:` key, which no old manifest can have (the old `schema.py` refuses an unknown top-level key). |
| Issue alignment | Needs work | Almost every spec rule has a part and a test (table below). Not covered: the issue's and the spec's "the layer order" and "which repos are optional" as resolve output (finding 1). The Issue Review's actions and the Checkpoint's eleven settled gaps are all taken up. |
| File targeting | Needs work | Part 3 misses `_rc_relabel_provenance` and its test, the adapter's role/distro preflight and validate checks, and the `.cache` names in the adapter's sweep and cleanup (findings 2, 3, 6). |
| Consequences | Needs work | The adapter's role and distro are required today and the distro is the ROS distro, so "pass `--role`/`--distro` only when recorded" cannot work for a manifest with no `distros:` (finding 2). |
| Principle alignment | Needs work | "Test what breaks" is well served. "Only what's needed": keeping `--cache-dir` defined only so it can be refused contradicts the plan's own "No option is kept dead" (finding 9). "Keep one current design": design#resolve says resolve writes the layer order and which repos are optional, and parts 1 and 2 would leave that false (finding 1). |
| ADR compliance | Good | ADR-0022, 0017, 0011, 0009 and 0013 are named and followed. No other ADR is triggered. |
| ROS conventions | N/A | Workspace plan. |

How the spec's rules map to the plan, checked one by one against `tools/repos-manifest/docs/spec.md`:

- What a manifest is (a `.repos` file is a manifest; one variant, one layer): part 1 step 6 plus a test. Q2 (refusing a `type` other than `git`) goes against this for an hg or svn `.repos` file. See Q2 below.
- Top-level keys (`format` higher is refused, an unknown key is warned about, `repositories` required in the first manifest): part 1 step 3 and part 2 step 4, each with a test.
- Repo keys (unique, a path, matched by the whole key in `base`): unique comes from the moved loader's duplicate-key refusal. Matching by key is in part 2's merge tests.
- Repo fields (`type`, `url` required; `version`, `absent`, `layer`, `groups`, `distros`, `optional`): part 1 step 3. A test for each type rule is in step 8.
- Versions and distros (no `version` gives no line, per-distro `version`/`absent`, `absent: true` on the repo, an empty entry counts): part 1 step 4. Step 8 tests all four cases of `absent`.
- Optional repos: read and checked, but never written out by resolve (finding 1). Reporting a repo that failed to fetch belongs to `sync` (#500).
- Distros (a distro outside the list is an error, a repo entry for such a distro is ignored, no `distros:` means no distro is given): steps 3, 4 and 8. With `base` this is judged on the merged chain (part 2 step 4).
- Layers (order, the unnamed layer first, a `layer:` not in the list is an error): steps 4 and 5. In the default layout the order is not written (finding 1).
- Groups and roles (every group off unless switched on, any group on selects the repo, every name declared, a role required only when `roles:` exists): steps 3, 4 and 8.
- Base: the location forms, reading order, read once, cycles, merge key by key, completeness: all in part 2, each with a test. "A tool that meets a location it cannot read says so and stops" has no test (a mapping with keys other than `url`/`version`/`path`, or a string that is neither a path nor an http(s) URL). Add one.
- What resolving produces: finding 1.
- Reading before using:
  - safe load: covered;
  - key and name rules, reserved layer names: covered;
  - the check on the real destination: left to `init`/`sync`, as the Checkpoint says;
  - a leading `-`: covered;
  - transports: covered, `git://` and `ext::` included;
  - invisible and bidirectional characters: covered only if the check reads the raw text (finding 4).

### Findings

1. **[Issue alignment / Keep one current design] High.** The issue's "The output" bullet, the spec's "What resolving produces" and design.md#resolve all say resolve writes three things: one `.repos` file per layer, the layer order, and which repos are optional. In the default layout, parts 1 and 2 write only the per-layer files. Names like `<layer>.repos` lose the order, and the optional repos go nowhere (Q1 default: only `validate` prints them). Part 3's manifest-dir layout writes the order, but only a layer-level optional list, and per the Checkpoint a mixed layer is not expressible there. So the per-repo "which repos are optional" is met in no part, and the design text that part 1 edits would stay false. Resolution: in part 1, write both in the default layout. One small file is enough, for example `layers.txt` (in order, `_unnamed` included) and `optional.txt` (repo keys), each with the head comment. Test it in part 1 and record it in design#resolve. This is also what `sync` (#500) will read. Part 3 then derives `optional_layers.txt` from the same data.

2. **[Consequences] High.** Part 3 step 3, "pass `--role`/`--distro` only when recorded (a manifest with no `roles:` takes none)", does not fit the adapter. `_rc_manifest_prepare` (adapter.sh about line 1125) refuses to run without `role=`. `_rc_distro` (line 242) refuses without `distro=`. `validate` (line 1224) fails with no role. `docs/manifest/design.md` step 1 says "Check that a role and a distro are recorded". And the distro is always needed, because it is the ROS distro behind `/opt/ros/<distro>`. With the Q5 default (`--distro` given to a manifest with no `distros:` is an error), the adapter's own test "a plain `.repos` file as `source`" fails: the recorded `--distro jazzy` is refused, and so is the required role. Resolution: state the rule in the plan. Two possible rules: (a) the resolver accepts `--distro`/`--role` for a manifest that has no `distros:`/`roles:` and ignores them with a note, an owner call against the spec's "no distro is given"; (b) the adapter learns from the resolver whether the manifest has distros and roles (for example a `validate` output line) and passes them only then. Either way, list the changes to the preflight, the `validate` check and `docs/manifest/design.md` step 1.

3. **[File targeting] Medium.** For a URL source, the adapter's `_rc_relabel_provenance` (adapter.sh about line 1020) rewrites every `#` line in the resolver's output, replacing the literal `--manifest` path it passed with `url#ref:path@commit`. `test_mr_provenance_names_the_source` asserts the result. Part 2 identifies a local manifest by `Path.resolve()`, and the head comment lists manifests by that identity. If the head comment prints the resolved path rather than the string given, the awk replacement silently finds nothing (for example when the project root has a symlink in its path). Also, the adapter's comment "name it as the resolver names an extends base, url#ref:path@commit" stops being true once part 2 names a git base `url version path`. Resolution: say that the head comment prints the leaf location as given. Add `_rc_relabel_provenance`, its comment and `test_mr_provenance_names_the_source` to part 3's list.

4. **[Principle alignment: Test what breaks] Medium.** The spec says "The file has no invisible characters and none that change the direction of text", which covers comments, where hidden text tricks usually sit. The plan "reuses `has_unsafe_char`". The existing `_refuse_unsafe_chars` walks the parsed data, so comments are never checked. `has_unsafe_char` on the raw text would refuse every newline, because `Cc` includes `\n`. Resolution: run the check on the raw text with newline allowed (and decide about tab), and add a test with a bidirectional override inside a comment.

5. **[Consequences] Medium (Q7).** Part 2 runs git under `subprocess` with a timeout and leaves the terminal to git and ssh. On timeout, `subprocess` kills git only. An ssh that git started and that is waiting at a passphrase prompt stays alive, holding the terminal with echo off. A process-group kill cannot simply come back: a child in its own process group cannot read the terminal (SIGTTIN), and a new session has no terminal at all. Also, a fixed 60 s races a person who is typing. Resolution: put this to the owner with Q7 (see below), and in either case say what happens to git's children when the limit ends git.

6. **[File targeting] Low.** Part 3 drops `--cache-dir` and `rm -rf "$tmp.cache"`, but `.cache` also appears in `_rc_resolve_cleanup` (line 1041), in the sweep patterns `(\.cache|\.link|\.src)?` (lines 1084 and 1106), in the header comments around lines 865 to 868, and in the tests `mr_no_temp`, `test_mr_interrupt_cleans_up` (its stub resolver parses `--cache-dir`) and `test_mr_swap_interrupt_and_sweep` (a `gen-Ab12Cd.cache` fixture). Decide whether the sweep keeps removing `.cache` leftovers of older runs, then change all of these together. The plan's grep for `--cache-dir` finds only some of them.

7. **[Scope] Low.** The dispatch rule should be explicit: "new reader only when the file reads, parses and has a top-level `repositories:`; any read or parse failure goes down the old path unchanged". Otherwise existing tests change. `test_cli_any_other_exception_is_one_fixed_line` passes a missing `m.yaml` and patches `cli.resolve_chain`. The leaf-path tests in `test_untrusted_input.py` (a long path, a symlink loop) expect the old reader's messages.

8. **[Principle alignment] Low.** Leftover `.<out>.new-*` and `.<out>.old-*` siblings after a SIGKILL are never removed by anyone: they are dot-prefixed precisely so the adapter's sweep skips them. Either have the tool remove stale siblings that carry its marker, or say in design#resolve that they can be left behind.

9. **[Principle alignment: Only what's needed] Low.** Part 3 keeps `--cache-dir` defined only to refuse it with a message naming the change. That is an option kept dead, which the self-check rules out. Note also that argparse's own "unrecognized arguments" (exit 2) is what the adapter's stale-resolver check matches on, and only together with `--layout`. Pick one approach and say why.

10. **[Verify before claiming] Low.** The baseline is "2 failed, 331 passed" (333 tests), not "fail 2 of 331". I ran it here on Python 3.14.4. Part 3's end check "seven layers and `optional_layers.txt` with `site`" holds only for a role that selects every layer. Name `developer` there.

11. **[File targeting] Low.** `select.py` shadows the standard library's `select` (which `subprocess` and `selectors` import) whenever the package directory is on `sys.path[0]`, as in `python src/repos_manifest/cli.py`. The old `selectors.py` already has this problem. A name like `selection.py` avoids it at no cost.

12. **[Issue alignment] Note.** The plan does not mark its additions as a list. These are the ones beyond the spec and the Checkpoint, with my view on each:
    - the marker file and refusing a non-empty unmarked `--out`: justified, because replacing an output directory whole could otherwise delete a person's directory;
    - dot-prefixed temporary siblings: justified, but see finding 8;
    - `type` must be `git`: see Q2;
    - refusing `a//b`, `./`, a trailing `/` and a backslash: justified, because they would get round the no-key-inside-another rule. Add a `.` component;
    - `distros: []` refused: justified;
    - the http(s) limits: justified, but add redirects to non-http(s) schemes (urllib follows to `ftp`);
    - the commit in the head comment: justified;
    - a warning for a mixed layer: justified, rather than silence;
    - `--cache-dir` as a named error: finding 9;
    - `validate` resolving every role and distro: justified, as the design's "checks against the specification".

The 3.14 fix. Keeping the old reader's test until part 3 and making the old code meet it is sound. Deleting the test now (which the Checkpoint would allow) would let 3.10 and 3.14 behave differently in a reader still in use, with nothing to show it. A smaller form of the same fix than the plan's: in `_resolve_one`, replace `candidate.is_file()` with `candidate.stat()`. Raise the "not found" message on `FileNotFoundError` (and on a non-regular file), and let any other `OSError` go to `resolve_chain`'s existing "its extends cannot be followed (<strerror>)" handler. `stat` already raises `ENAMETOOLONG` for both parametrizations (a single name of over 5,000 characters, and components of over 300). The `pathconf(PC_NAME_MAX)` branch is not needed, and `test_a_symlink_loop_is_a_message` still gets one ERROR line (ELOOP).

### Open questions

- **Q1. Wrong.** It contradicts design#resolve ("which repos are optional") and the issue's output bullet. Write it in part 1 (finding 1).
- **Q2. Acceptable, but it contradicts spec "A `.repos` file is already a valid manifest" for hg/svn entries.** If kept, record it in spec.md as a settled point (owner-visible), not only in code.
- **Q3. Right.** Add a `.` component. A leading `/` is already "not relative".
- **Q4. Right.**
- **Q5. Right for the tool, per the spec, but it collides with the adapter (finding 2).** The plan must resolve that collision.
- **Q6. Right.** Also refuse a redirect to any scheme but http(s).
- **Q7. As written, it fits the Checkpoint's words but goes against the design's intent ("When a command is run at a terminal and git or ssh needs a password, it asks"), and it leaves an ssh holding the terminal on timeout (finding 5).** Suggested default for the owner: the limit applies when there is no terminal (where the design says git fails and does not wait); at a terminal there is no limit, and Ctrl-C reaches git and ssh together.
- **Q8. Right.**
- **Q9. Right.** The adapter acts on what was selected for the machine, and warning on a mixed layer is better than silence.
- **Q10. The plan correctly leaves CI unchanged** and asks first, as AGENTS.md requires. Until the owner answers, 3.14 is checked only locally. Note that the CI job's name still says "#267 prototype"; renaming it is the same ask-first change.

### Summary

The plan is thorough, follows the Checkpoint, and its factual claims about the code and fixtures hold. Checked: the draft has 44 repos in the same per-layer order as the old `p11/expected/jazzy`; jazzy and rolling differ only in `unh_marine_autonomy`; the adapter's call and layer-name rule; the `test_mr_*` names; the two `prototype.md` links. Two gaps need fixing before part 1 starts or before part 3 is planned in detail: resolve output without the layer order or the optional repos, and the adapter's required role and ROS distro against a manifest with neither. The rest are smaller. Not ready as written.

### Recommended Actions

- [ ] Part 1 writes the layer order and the optional repo keys in the default layout, tests them, and records the format in design#resolve (finding 1, Q1).
- [ ] State how the adapter's always-recorded ROS distro and required role meet a manifest with no `distros:`/`roles:`, and list the preflight, `validate` and `docs/manifest/design.md` step 1 changes (finding 2).
- [ ] Add `_rc_relabel_provenance`, its comment and `test_mr_provenance_names_the_source` to part 3, and print the leaf location as given in the head comment (finding 3).
- [ ] Run the invisible-character check on the raw file text, newline allowed, and test a bidirectional character inside a comment (finding 4).
- [ ] Put Q7 to the owner with the orphan-ssh consequence, and say what happens to git's children on timeout (finding 5).
- [ ] List every `.cache` use in the adapter and its tests and change them together (finding 6). Make the dispatch-on-failure rule explicit (finding 7).
- [ ] Smaller items: leftover siblings (8), `--cache-dir` (9), baseline count and the `developer` role in the end check (10), the `select.py` name (11), a test for a location form the tool cannot read, a `.` key component, non-http(s) redirects.
- [ ] 3.14 fix: use `stat()` in place of `is_file()` in `_resolve_one`, with no `pathconf` branch.

## Checkpoint
**Status**: complete
**When**: 2026-11-18 13:13 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the Plan Review's verdict is needs-work with two high findings; revising a plan is a mechanism answer the checkpoint table allows the host; the answers to the plan's open questions below are listed for the owner's veto)
**After**: plan
**Decision**: revise

The host, running /orchestrator, read the Plan Review (verdict needs-work: two high, three medium, six low findings, and a note on additions). Revise for every finding, with these answers.

Findings:
1. (high) resolve writes all three parts of its output from part 1 on, as the spec and the design say: the per-layer .repos files, the layer order, and which repos are optional (by repo key). Tests for each.
2. (high) The adapter and a manifest without roles or distros. The tool keeps the spec's rule: a role given to a manifest with no roles, or a distro to one with no distros, is an error. The adapter's current route always records a role and a distro and needs the distro to find the ROS install, so on that route it requires a manifest that has roles and distros, and passes the tool's error through otherwise. Drop the plan's part 3 test of the adapter with a plain .repos source; say in the note on moving that the adapter's current route needs roles: and distros: in the manifest, and that a manifest without them is for the tool used directly until the thin adapter (issue 503). List the preflight, validate and docs/manifest/design.md changes this needs, if any.
3. (medium) Part 3 covers _rc_relabel_provenance and test_mr_provenance_names_the_source: say what the head comment prints for the manifest's location so the adapter's rewrite still finds it, and correct the comment that will be false after part 2.
4. (medium) The check for invisible and direction-changing characters reads the raw file text, comments included, with newline allowed. Test with such a character inside a comment.
5. (medium) The time limit on git calls applies only when there is no terminal. At a terminal git or ssh may ask for a password and wait for a person, as the design says. Record that in design.md.
6-11. (low) Take each as the review states it: find every use of the cache directory in the adapter and its tests, not only the option; a read or parse failure goes to the old reader while both exist, so existing error-message tests keep their behaviour; leftover temporary output directories from a killed run are swept on the next run; --cache-dir is removed, not kept as a named error; fix the baseline count (333 tests: 331 pass, 2 fail on 3.14) and the "seven layers" end check, which holds for the developer role; do not name a module select.py or anything else that shadows a standard library module.
12. List the plan's additions in the plan, each with its reason. Also refuse a "." path part in a repo key, and a redirect to any scheme other than http or https. Add a test for a location form the tool cannot read.

The Python 3.14 fix: use the smaller form the review gives (in the old reader, stat the candidate; "not found" on FileNotFoundError, any other OSError to the existing "cannot be followed" handler). The old test stays until part 3.

The plan's ten open questions, answered:
1. The list of optional repos is written in the output (finding 1).
2. A type other than git is refused by these tools, with a message. Record in spec.md that the format takes any type a .repos file takes and that these tools read git only.
3. Odd repo keys (a doubled or leading or trailing slash, a "." or ".." part, a backslash) are refused.
4. An empty distros list is refused.
5. A role given to a manifest with no roles, or a distro to one with no distros, is an error (and see finding 2).
6. An http or https base: a 60 second limit, a 1 MiB size limit, and a redirect to anything but http or https refused, as is one from https to http.
7. The git time limit applies only when there is no terminal (finding 5).
8. The head comment names the commit read for a base in a git repo.
9. In the layout the adapter reads, "every repo in the layer is optional" counts the repos selected for the machine, with a warning on a mixed layer.
10. Adding Python 3.14 to the CI job is the owner's to decide and has been put to him; until he answers, the plan leaves CI unchanged.

## Plan Authored
**Status**: complete
**When**: 2026-11-18 13:15 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-498/plan.md` at `090edff6` (revision answering the `revise` Checkpoint)

Findings 1 to 12: resolve writes the per-layer files, `layers.txt` and `optional.txt` (repo keys) from part 1, and part 3's manifest-dir layout is a second writer over the same data; the adapter keeps its role and distro requirement (the tool's error passes through, no preflight code changes, comments and `docs/manifest/design.md` step 1 change, one new test, the plain-.repos adapter test dropped, the note says so); the git limit applies only with no terminal and ends the whole process group; `_rc_relabel_provenance`, its test and every cache use in the adapter and tests are listed with line numbers; the raw-text character check, `selection.py`, dispatch on parse failure, leftover sibling sweep, `--cache-dir` removed outright, baseline 333 tests, `developer` role in the end check, the `stat()` 3.14 fix, a test for unreadable location forms, `.` key part and redirect rules are in. The plan lists its additions with reasons. Questions 1 to 9 are carried as the host answered; question 10 (CI on 3.14) stays open with the plan written for either answer and nothing under `.github/` changed meanwhile.

## Plan Review
**Status**: complete
**When**: 2026-11-18 13:20 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #498 — repos-manifest: the resolver reads the format in the spec
**Plan**: `.agent/work-plans/issue-498/plan.md` at `090edff6`
**Branch**: `feature/issue-498`
**Serves**: Goal: Modular (`README.md#modular`); design `tools/repos-manifest/docs/design.md#resolve` and `#what-is-built`; format `tools/repos-manifest/docs/spec.md`; adapter route `docs/manifest/design.md` "The manifest route, step by step". Checked: `README.md:71` `### Modular`; the tool's design `### resolve` (line 269) and `## What is built` (line 655); `docs/manifest/design.md:56`.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three PRs, as ordered. The dispatch rule is explicit, but it misses a base-only leaf in part 2 (finding 3). |
| Issue alignment | Good | All three outputs come from part 1. Every spec rule has a part. Two groups of rules lack a named test (finding 5). |
| File targeting | Good | Checked against the code: the adapter line numbers (914–922, 954–956, 1020, 1037–1041, 1084–1085, 1106, 1122, 1224, 574), every `cache` hit in `test_ros2_colcon.sh` (2522, 2523, 2691, 3278, 3472–3506, 3796; also 3284, which the plan's grep-and-account step covers), the `prototype.md` links (`README.md:99`, `adapter.sh:574`), the old `_TOP_LEVEL_KEYS` and `_resolve_one`. |
| Consequences | Needs work | Two gaps. Leftover hidden siblings on the adapter route are never swept (finding 1). Signals no longer reach git when it runs in its own session (finding 2). Two root-design lines go stale earlier than part 3 (finding 6). |
| Principle alignment | Good | "Test what breaks" is well served. "Only what's needed": `--cache-dir` is removed outright. "Keep one current design": see finding 6. |
| ADR compliance | Good | ADR-0022, 0017, 0011, 0009 and 0013 are named and followed. |
| ROS conventions | N/A | Workspace plan. |

Baseline re-run here on Python 3.14.4: `PYTHONPATH=src python3 -m pytest tools/repos-manifest/tests` gives 2 failed and 331 passed, the two being `test_an_extends_path_too_long_is_a_message_without_the_path` (both parametrizations). This matches the plan. I did not run the adapter suite. I did not re-check the `stat()` fix: running it in a scratch copy was denied. The earlier review had checked it.

**Earlier findings, carried?**
1. Yes. Part 1 step 5 writes `<layer>.repos`, `layers.txt` and `optional.txt`; step 8 tests them; step 9 records them in design#resolve.
2. Yes. Part 3 step 3. The claim that no adapter code is needed holds. `_rc_manifest_resolve` prints the resolver's stderr (`[ -n "$err" ] && printf …`), then "the manifest resolver failed … nothing changed", and returns 1. The registry checks (`_rc_manifest_prepare` 1125, `_rc_distro` 249, validate 1224) already require `role=` and `distro=`. Gap: finding 4.
3. Yes. The head comment prints the `--manifest` string as given, and the adapter comment is corrected. Gap for a base next to a URL source: finding 7.
4. Yes. The check reads the raw text, allows newline, CR and tab, and refuses every other `Cc`/`Cf`/`Zl`/`Zp` and non-ASCII `Zs`. There is a test with the character inside a comment.
5. Yes, but a new gap: finding 2.
6. Yes. Every `.cache` use is listed, and the sweep keeps old leftovers on purpose.
7. Yes. The rule is right for the tests named (`test_cli_any_other_exception_is_one_fixed_line` passes a missing `m.yaml`, which reads and fails, goes to the old path and hits the patched `cli.resolve_chain`). Gap for part 2: finding 3.
8. Partly. The sweep exists, but it is keyed to the same `--out` name, which the adapter never reuses (finding 1).
9. Yes. Removed outright; argparse gives exit 2, and the adapter's stale-resolver check also needs `--layout` in the text (`adapter.sh:925`).
10. Yes. 333 tests; the end check names `developer`.
11. Yes. `selection.py`.
12. Yes. The additions table is present. The `.` part, the non-http(s) redirect and the test for an unreadable location form are in.

**Host answers 1–10, carried?** 1 yes (`optional.txt`). 2 yes (part 1 step 3 and the spec.md record in step 9). 3 yes (`a//b`, `a/./b`, `./a`, `a/`, `/a`, `a\b`, `..`, `.git`). 4 yes. 5 yes (part 3 step 3, plus the note). 6 yes. 7 yes, with finding 2. 8 yes (part 2 step 5). 9 yes (part 3 step 2). 10 yes. `.github/` is unchanged unless the owner says yes, and the plan works either way. Nit: in the yes branch, going from `python-version: '3.10'` to a matrix is more than "one line" (a `strategy.matrix` block plus `${{ matrix.python-version }}`). The part 1 proof already lists every changed line, so nothing is lost.

**Spec rules to parts and tests.** Each section of `spec.md` has a part:
- top-level keys: part 1 step 3 and part 2 step 4;
- repo keys and fields, versions and distros: part 1 steps 3, 4 and 8;
- optional repos: written in part 1; reporting a skipped fetch is `sync`, #500;
- distros, layers, groups and roles: part 1;
- base, locations, order and merge: part 2;
- what resolving produces: part 1 step 5 and part 3 step 2;
- reading before using: part 1 step 8 and part 2 step 6; the destination check is #500.

Two groups of rules have a part but no named test (finding 5).

### Findings

1. **[Consequences] Medium: on the adapter route, leftover temporary output directories are never swept.** The tool sweeps only `.<out>.new-*` and `.<out>.old-*` for the same `<out>` name. The adapter passes a new `mktemp -d` name every run (`configs/manifest-resolved.gen-XXXXXX`, `adapter.sh:893`). So the tool's sweep never sees a previous run's `.manifest-resolved.gen-AAAAAA.new-*`. The adapter's sweeps glob `manifest-resolved.gen-*` (lines 1081, 1103), which by design skips dot names. A killed resolve therefore leaves a hidden directory in `configs/` for good. No planned test sees this, because every tool test reuses one `--out`. A SIGTERM to the tool's process group leaves one too: Python's default SIGTERM action runs no `finally` (see finding 2). Resolution, part 3: extend the adapter's locked sweep (`_rc_resolve_sweep`) to remove `.manifest-resolved.gen-XXXXXX.{new,old}-*` directories that hold the marker file or are empty. Test it in `test_mr_swap_interrupt_and_sweep` next to the `gen-Ab12Cd.cache` fixture. Alternatively, the tool's sweep could match any marked `.*.new-*`/`.*.old-*` beside `--out`; that is broader, so the adapter route is simpler.

2. **[Consequences] Medium: with no terminal, git runs in its own session, so a signal to the tool's group no longer reaches it.** Part 2 step 2 starts git with `start_new_session=True` when there is no terminal. The Prior Art section drops the old signal handling ("the process-group and signal machinery", which it says the Checkpoint drops; the Checkpoint dropped the hook, filter and no-prompt guards and the cache, not signal handling). Suppose the caller ends the run: a CI cancel, or an agent harness timeout that signals the process group. The tool dies, but git and the ssh it started live on with no limit at all, because the tool that kept the timer is gone. On SIGTERM, Python also skips `finally`, so the clone directory and the `.new-*` output sibling stay. This is the "no terminal" case the time limit was meant for. Resolution, folded into part 2 step 2 and part 1 step 5: while `resolve` runs, SIGTERM and SIGHUP raise an exception, as SIGINT already does. A `finally` around the git call sends SIGTERM and then SIGKILL to git's group if it is still alive, and removes the clone. The output writer's `finally` removes `.new-*`. Add one test: a stub git that sleeps, SIGTERM sent to the tool, and afterwards the stub's child is gone and no clone or sibling is left. Correct the Prior Art line to match.

3. **[Scope] Low: in part 2, the dispatch rule sends a base-only leaf to the old reader.** The rule for parts 1 and 2 is that a top-level `repositories:` goes to the new reader. Part 2 makes "a later manifest that adds no repo needs no `repositories:`" valid and tests it (step 6), but a leaf of that kind has only `base:` and would go to the old reader. There it fails as an unknown top-level key (`schema.py` `_TOP_LEVEL_KEYS` has no `base`). Resolution: from part 2, dispatch on a top-level `repositories:` or `base:`. Neither is an old key, so the old tests are unaffected. The failing test would show this at once.

4. **[File targeting] Low: the converted adapter fixture needs a `distros:` list.** Part 3 step 1 converts `write_mr_manifest` with `roles:` but names no `distros:`. The adapter always passes `--distro`, and the suite uses `fakefox`, `otherfox` and `emptyfox` (`test_ros2_colcon.sh` lines 2478, 3308, 3424). Without the list, every converted test hits "distro given to a manifest with no distros". Add `distros: [fakefox, otherfox, emptyfox]`, or whichever ones each test needs. `write_mr_base` can leave it out (the leaf's list replaces it).

5. **[Test what breaks] Low: two groups of rules have no named test.**
   - "An undeclared group anywhere is an error" (an issue bullet): step 8 tests only `--with`. Add a test for a repo's `groups:` and one for a role naming an undeclared group.
   - The part 2 merge rules for top-level lists have no test in step 6 (the diamond test may touch some):
     - a role replaces the earlier one by name;
     - `groups:` appends without repeating;
     - `layers:` appends, and a layer already listed keeps its place;
     - `distros:` replaces the list;
     - a later entry giving `layer:` to a repo moves it out of the unnamed layer (the spec's own example).

   Add one test each.

6. **[Keep one current design] Low: the root's `docs/manifest/design.md` "What the tool has to give" goes stale before part 3.** Line 237–240 says "The tool's design says where `resolve` writes and not what a failure leaves behind". That is false once part 1 records replace-whole in design#resolve. Line 235 says "the resolver bounds its clones of parent manifests", and line 108–109 says the clone "runs no user hook or filter driver and is bounded by `REPOS_MANIFEST_GIT_TIMEOUT`". After part 2, both hold only with no terminal, or no longer hold, but the plan edits this file only in part 3. The same applies to the adapter comment at 576–582: "while the source lock is held, every call that asks a remote has a limit … the resolver's for each base" stops being true at a terminal, yet the plan's comment list for 572–580 leaves that sentence out. Resolution: update the line 237–240 bullet in part 1. Update lines 108–109 and 235, and add the comment sentence at 576–582, in part 3's list.

7. **[Consequences] Low: a base next to a URL source prints a temporary path.** For a URL source the adapter passes `--manifest $tmp.src/<path>`, and `_rc_relabel_provenance` replaces only that exact string. Part 2 prints a relative local base "as written resolved against its parent", which gives `$tmp.src/<dir>/common.yaml`. That does not contain the leaf's string, so a path that is gone after the run stays in the header. Resolution: say what the head comment prints for a base next to the leaf (for example, the leaf's string with its file name replaced, so a prefix rewrite can find it, or the path relative to the leaf). Extend the planned "no temporary path in the header" assertion to a URL source with a sibling base.

8. **[Note] The additions table** is complete against the plan body. It still lists "Refusing … a trailing or leading `/`", which is accurate. One row is missing: part 3 writes `optional.txt` in the manifest-dir layout too, with the reason "#500 reads it". #500 reads the default layout, not the adapter's, so the real reason is "costs nothing". Either drop it there or record it with that reason.

**Checked hardest, and sound apart from the findings above:**
- The three-part output: `_unnamed` cannot clash with a name that starts with a letter, `.repos` and `.txt` cannot clash, and the adapter's layer regex `^[A-Za-z0-9_-]+$` accepts `_unnamed`.
- One structure with two writers, `optional_layers.txt` derived from `optional.txt`.
- The `/dev/tty` rule, with `has_terminal()` replaceable in tests, and no new session at a terminal.
- The whole-or-nothing swap fits the adapter: its `--out` is an empty `mktemp -d`, which the "empty or marked" rule accepts.
- The no-code-change claim for the adapter.

### Summary

The revision carries all twelve earlier findings and all ten host answers. Its claims about the code check out, and the tool baseline was reproduced. No finding would make an implementer build the wrong thing overall. Two mediums are gaps an implementer following the plan would build in and no planned test would catch: the sweep never runs on the adapter route, and signals do not reach git once it is in its own session. Each has a short fix that can be given as a Checkpoint instruction without another planning round. Ready, with the actions below carried into implementation.

### Recommended Actions

- [ ] Part 3: the adapter's locked sweep removes marked or empty `.manifest-resolved.gen-XXXXXX.{new,old}-*` directories; test it (finding 1).
- [ ] Parts 1 and 2: SIGTERM and SIGHUP raise during `resolve`; a `finally` ends git's group and removes the clone and the `.new-*` sibling; one test with SIGTERM sent to the tool; correct the Prior Art line (finding 2).
- [ ] Part 2: dispatch on top-level `repositories:` or `base:` (finding 3).
- [ ] Part 3: the converted `write_mr_manifest` lists the distros the suite uses (finding 4).
- [ ] Tests: an undeclared group on a repo and in a role; the part 2 list-merge rules and moving a repo's layer (finding 5).
- [ ] `docs/manifest/design.md` lines 237–240 in part 1; lines 108–109 and 235, and adapter comment 576–582, in part 3 (finding 6).
- [ ] Part 2/3: what the header prints for a base next to a URL source, and a test for it (finding 7).

## Checkpoint
**Status**: complete
**When**: 2026-11-18 13:21 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second Plan Review's verdict is ready; it says its two medium and five low findings can be passed on as instructions without a third planning round)
**After**: plan
**Decision**: proceed

The host, running /orchestrator, read the second Plan Review (verdict ready). The plan is implemented one part at a time, each part its own pull request; this proceed starts part 1 only. Instructions for the implementer of each part, from the review's findings:

Part 1 (the reader for one new-format manifest):
- Signals (finding 2). While resolving, SIGTERM and SIGHUP end the run through an exception, and a finally block removes the temporary output directory, so a cancelled run leaves nothing behind. One test. Correct the plan's Prior Art line that says signal handling was dropped: only the old reader's detailed handling goes with the old reader. (The part that ends git's process group belongs to part 2, where git is first called by the new reader.)
- Tests the plan does not name (finding 5): an undeclared group on a repo, and in a role.
- docs/manifest/design.md lines that go stale in part 1 are corrected in part 1 (finding 6), not left for part 3.
- The additions table: the reason given for writing optional.txt in the adapter's layout is wrong; the default layout is what init and sync (issue 500) will read (finding 8).
- CI: nothing under .github/ changes. The owner has been asked whether the tool's test job should also run on Python 3.14 and has not answered.

Part 2 (base):
- Dispatch between the readers (finding 3): a manifest with a top-level repositories: or base: goes to the new reader; a manifest that has only base: is valid.
- With no terminal, git runs in its own session; when the tool itself is signalled, the finally block also ends git's process group and removes the clone (finding 2).
- Tests for the merge rules for lists (finding 5): a role replaced by name, groups: and layers: appended, distros: replaced, a repo's layer moved.
- What the head comment prints for a relative base beside a manifest read from a URL, with a test (finding 7).
- docs/manifest/design.md lines that go stale in part 2 are corrected in part 2.

Part 3 (the switch):
- The adapter's locked sweep also removes marked or empty leftover temporary directories of the tool beside its generated directories, with a test (finding 1).
- The converted adapter fixture lists the distros the adapter's tests pass (finding 4).
- The adapter comment that says every remote call has a time limit is corrected: at a terminal there is none (finding 6).

## Implementation
**Status**: partial
**When**: 2026-11-18 13:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-498 at `32f847e2`

Part 1 of 3 (the reader for one manifest with no `base`). Everything in the newest Checkpoint's "Part 1" list is done except the CI change. That change is why the status is partial.

- `3e690378`: the Python 3.14 fix in the old reader, in the form the first Plan Review gave. `_resolve_one` stats the candidate. Only `FileNotFoundError` or a file that is not regular means "not found". Any other `OSError` goes to the existing "cannot be followed" handler. The test is unchanged.
- `bb202e42`: the safe YAML loader moved unchanged from `schema.py` to `yamlload.py`.
- `193c905d` `manifest.py`: reads and checks one manifest. `yamlload.first_unsafe_in_text` checks the raw file text, comments included, and allows only newline, CR and tab.
- `96c89471` `selection.py`: picks the repos of each layer for a role, a distro and extra groups.
- `cd5b8830` `output.py` and `cli.py`:
  - A file with a top-level `repositories:` goes to the new reader. Any other file goes to the old one, including a file that does not read or parse.
  - The new reader writes `<layer>.repos`, `layers.txt` and `optional.txt` with the head comment. The output is written whole or not at all, with the marker file and a sweep of leftover siblings.
  - SIGTERM and SIGHUP end a resolve through an exception, and a `finally` removes the temporary directory. One test covers this.
  - `--role`, `--distro` and `--with` are optional flags. `validate` resolves every role and distro the manifest lists.
  - `--layout` and `--cache-dir` are refused for the new format. The old format still needs `--role` and `--distro`, and argparse refuses a missing one with exit 2.
- `7bdb7183`: the project11 fixture. The private repo is renamed `site_config` with a made-up URL and a comment saying so. There are 6 expected output directories. `developer` matches the old 44-repo fixture apart from that repo.
- `32f847e2`: documents. `spec.md` records the points settled for part 1. `design.md` changes under "resolve" and "What is built". `prototype.md` has a pointer note, `README.md` has the new usage, and `docs/manifest/design.md` lines 237–240 are corrected. `roadmap.md` is unchanged: no row is fully true until `base` is read.

CI, not done. While I worked, the coordinator relayed the owner's answer to question 10 (2026-11-18): "yes, add python 3.14 to CI". My edit of `.github/workflows/validate.yml` (a 3.10/3.14 matrix in `validate-repos-manifest` only) was refused by the permission system as a change to CI. I did not try another way. Nothing under `.github/` changed, and `git diff origin/main -- .github` is empty. The host or the owner needs to make or allow that change before the pull request.

Suites run:
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest tools/repos-manifest/tests` on Python 3.14.4: `487 passed`. The baseline was 333, with 2 failing.
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: `=== Results: 1014 passed, 0 failed, 0 skipped ===`. The suite runs this checkout's `tools/repos-manifest/src` through PYTHONPATH, so it checks the branch.
- Python 3.10 was not run here. CI checks it after the push.
- The full pre-commit pass was left to the host.

Not done from the plan or the Checkpoint:
- The plan's Prior Art line on signal handling is not corrected. The dispatch said nothing under `.agent/` changes.
- The plan's step 9 put the output file names and `_unnamed` in `spec.md`. They are in `design.md#resolve` instead, because the spec says layout on disk belongs to the tools.

Questions not settled by the spec or a Checkpoint. Each was given the narrowest reading:
1. A distro entry that gives both `version` and `absent: true` is refused.
2. An unknown key inside a distro entry is warned about, like a repo key.
3. A host in a `url` that starts with `-` is refused. This is written into the spec as part of "no value makes git run a program".
4. Only `user@host:path` is taken as the scp form; `host:path` with no user is refused.
5. A role with no value (`robot:`) is refused; `[]` is required. Recorded in the spec.
6. A `--out` that is a symbolic link is refused.
7. A file starting with a byte-order mark is refused (U+FEFF is invisible).
8. Names of one kind that differ only in case (`Core` and `core`) are not refused, since that is a destination check. The two layer files would collide in `--out` on a case-insensitive disk.
9. `repositories: {}` is accepted and gives no files.

## Checkpoint
**Status**: complete
**When**: 2026-11-18 13:40 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: phase-failed
**Decision**: takeover
**Phase**: implement

The implementation of part 1 came back partial for one reason: the agent's edit to .github/workflows/validate.yml was refused by the permission system, because the owner's approval ("yes, add python 3.14 to CI", 2026-11-18) reached it as a relayed message. Asked how the CI change should be made, the owner chose "You make that one edit": the host edits the workflow file itself for this step only, commits it, and records the implementation as complete. The change: the tool's test job runs on Python 3.10 and 3.14 and its name gains the Python version; no other job is touched.

## Implementation
**Status**: complete
**When**: 2026-11-18 13:40 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Branch**: feature/issue-498 at `d2802211`
**Mode**: inline

Part 1 of 3, finished by the host on the owner's takeover answer. The dispatched pass built everything else (its entry above, partial, lists it: the 3.14 fix in the old reader, the YAML loader moved, manifest.py, selection.py, output.py and the CLI, the project11 fixture, the documents); this entry adds the one step it was not allowed to make.

- .github/workflows/validate.yml: the tool's test job, validate-repos-manifest, runs on Python 3.10 and 3.14 through a version matrix (fail-fast off, so one version's failure does not hide the other's), and its name gains "(Python <version>)". No other job is touched. The owner's words: "yes, add python 3.14 to CI" (2026-11-18).
- Not run by the host: the tool suite. The dispatched pass ran it on Python 3.14.4 here (487 passed) and the adapter suite (1014 passed, 0 failed); Python 3.10 is checked by CI after the push. The full pre-commit pass runs before the push.
- Left from the dispatched pass's report, for the review to weigh: nine readings it chose where the spec and the Checkpoints were silent (listed in its entry), the plan's Prior Art line on signals not corrected, and the tool's roadmap unchanged because no row is fully true until base is read.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 13:46 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-498 at `764f1195`
**Base**: origin/main
**Depth**: Deep (reason: input-safety checks and an output writer that deletes and replaces directories; 68 files, +3870 -169; touches .github/workflows)
**Must-fix**: 7 | **Suggestions**: 11
**Round**: 1 | **Ship**: continue — round 1: 7 must-fix; first round always re-reviews after fixes

Part 1 only (one manifest, no `base`). Selection was checked against the spec rule by rule and by hand-written manifests (role, distro, extra groups, `absent` on the repo and under a distro, unlisted distro entries, several groups, the unnamed layer, no roles/distros/layers): no bug found. Old reader: its tests are untouched; behaviour unchanged apart from the 3.14 stat fix. CI diff is only the tool's job gaining a 3.10/3.14 matrix used by setup-python, and its name; YAML parses. Fixture: 43 public repos plus the made-up `example/site_config` (does not exist). New code parses with Python 3.10 grammar and uses no newer library feature found.

Suites on Python 3.14.4: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest tools/repos-manifest/tests` gives `487 passed`; `bash .agent/scripts/tests/test_ros2_colcon.sh` gives `=== Results: 1014 passed, 0 failed, 0 skipped ===`. Python 3.10 not run here.

Specialists: static analysis (no linter beyond pre-commit for these files; Python 3.10 grammar parse run), governance and plan drift (Claude subagent), Claude adversarial (subagent), cross-model gemini and codex (both completed, EXIT=0).

Readings where the spec was silent: (1) distro entry with `version` and `absent: true` refused: right. (2) unknown distro-entry key warned: right, matches repo keys. (3) url host starting with `-` refused: right, the spec says so; the code's host extraction is wrong (must-fix 2). (4) scp form needs a user: matches the spec's text; `host:path` with an ssh alias is common, owner may widen. (5) a role with no value refused: right, the spec says a role is always a list. (6) symlinked `--out` refused: right. (7) BOM refused: right, U+FEFF is invisible; untested. (8) names differing only in case: layer names should be refused (they are file names in `--out` and directories later), and reserved layer names compared without case; repo keys can stay with the destination check; needs a spec line, owner to confirm. (9) `repositories: {}` accepted: right, an empty `.repos` is valid.

### Findings
- [x] (must-fix) Invisible characters accepted, in comments and in keys/values: variation selectors U+FE00-FE0F/U+E0100-E01EF, Hangul fillers U+115F/U+1160/U+3164/U+FFA0, U+034F, U+2800, unassigned code points; `ok` and `"okㅤ"` resolve as two repos that look the same; refuse default-ignorable, Cn and Co characters — `tools/repos-manifest/src/repos_manifest/yamlload.py:148`
- [x] (must-fix) url host check takes the text after the first `@` across the whole url and ignores `[...]`: `ssh://a@b@-oProxyCommand=x/p`, `ssh://[-oProxyCommand=x]/p` and `git@[-o...]:p` pass, `https://example.org/repo@-v1.git` is refused; take the authority before the first `/`, the part after the last `@`, brackets stripped — `tools/repos-manifest/src/repos_manifest/manifest.py:195`
- [x] (must-fix) Ctrl-C between the two renames deletes the previous output and leaves no `--out`: SIGINT is not held, `except OSError` misses KeyboardInterrupt, and `finally` removes `old`; hold SIGINT too and remove `old` only once the new output is in place — `tools/repos-manifest/src/repos_manifest/output.py:44`
- [x] (must-fix) `roles: {}` is accepted and `validate` prints "valid" with no role checked, although `resolve` can never succeed; refuse it like `distros: []`, with a spec line and a test — `tools/repos-manifest/src/repos_manifest/manifest.py:242`
- [x] (must-fix) New tracked test names the private repo `ccomjhc_project11` (visibility PRIVATE), against the rule that new mentions name only public repos; take the old key from the old fixture's `site.repos` instead of spelling it — `tools/repos-manifest/tests/test_project11.py:44`
- [x] (must-fix) The third Checkpoint ordered the plan's Prior Art line on signal handling corrected; still says the process-group and signal machinery is rejected; also the stale optional.txt reason at line 38 — `.agent/work-plans/issue-498/plan.md:99`
- [x] (must-fix) The tool's design document names the workspace's ros2_colcon adapter; say it from a general user's view (a caller that needs `layers.txt` and `optional_layers.txt` passes `--layout manifest-dir`) — `tools/repos-manifest/docs/design.md:698`
- [x] (suggestion) A SIGTERM/SIGHUP held during the swap is delivered after it, and the CLI prints "nothing was written" although `--out` was replaced — `tools/repos-manifest/src/repos_manifest/cli.py:76`
- [x] (suggestion) A repo key starting with `#` (quoted) is written to optional.txt and read back as a comment; refuse it or define the encoding (owner, spec line) — `tools/repos-manifest/src/repos_manifest/output.py:88`
- [x] (suggestion) The sweep removes any marked `.<name>.new-*`/`.old-*` sibling: another run's live temp directory, or a real output whose name has that shape; tie leftovers to their destination or a lock — `tools/repos-manifest/src/repos_manifest/output.py:113`
- [x] (suggestion) A new-format file that does not parse (duplicate key, alias, syntax) or a missing file, given to `validate` without `--role`/`--distro`, reports "arguments are required: --role, --distro" instead of the read or parse error — `tools/repos-manifest/src/repos_manifest/cli.py:172`
- [x] (suggestion) Checks on `--out` run outside the OSError handler: an unreadable existing `--out` gives "internal error (PermissionError)" — `tools/repos-manifest/src/repos_manifest/output.py:144`
- [x] (suggestion) Refuse layer names that differ only in case (`Core`/`core` collide in `--out` on a case-insensitive disk) and compare reserved layer names without case (`Src`, `INSTALL`) — `tools/repos-manifest/src/repos_manifest/manifest.py:231`
- [x] (suggestion) The `::` check refuses valid IPv6 urls (`ssh://user@[::1]/repo`); match only a leading `<word>::` — `tools/repos-manifest/src/repos_manifest/manifest.py:189`
- [x] (suggestion) An ssh user or port starting with `-` is accepted (`ssh://-oX@host/p`, `ssh://host:-oX/p`); git blocks or ignores both, but the spec's "no value makes git run a program" argues for refusing — `tools/repos-manifest/src/repos_manifest/manifest.py:195`
- [x] (suggestion) No test pins readings 2 and 7 (unknown key in a distro entry warned; a BOM refused) — `tools/repos-manifest/tests/test_manifest_reading.py:165`
- [x] (suggestion) Job name still says "#267 prototype" though it now tests the new reader too; owner's call, mention in the PR — `.github/workflows/validate.yml:56` (deferred: host decision: the job name keeps (#267 prototype); nothing under .github/ changes in this round)
- [x] (suggestion) `test_developer_gets_the_44_repos_of_the_earlier_fixture` reads `fixtures/p11`, which part 3 deletes; add it to part 3's list — `tools/repos-manifest/tests/test_project11.py:69`

## Implementation
**Status**: complete
**When**: 2026-11-18 14:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-498 at `0e345f33`
**Addressed**: Local Review (Pre-Push) at `764f1195` (2026-11-18 13:46 -05:00)
**Commits**: 066f284a f656ee2a 766bd700 41cbff57 de03f0fd 49bc8151 62d137f8 88c6e3cc fa1d9aa6 79b5dee7 2ca89190 0856619b 7f23a75c 346f97d9 0e345f33

Fix round for part 1. Every must-fix has a test that failed before its fix, except must-fix 6 (a plan file, which no test reads). The test for must-fix 7 is its own commit (fa1d9aa6), and it fails on the design text before 88c6e3cc.

### Actions
- [x] (must-fix 1) Invisible characters. `has_unsafe_char` now also refuses categories Cn, Co and Cs, Unicode's default-ignorable code points (the full list, as Python's unicodedata does not give that property) and U+2800. Both the raw-text check (comments included) and the walk over parsed keys and values use it. Tests cover 18 such characters in a comment, a key and a value, `ok` against `"ok"` followed by U+3164, a BOM, and visible non-ASCII text that is still accepted. spec.md says what the rule covers. — `yamlload.py`, 066f284a
- [x] (must-fix 2) The url host. It is found in the authority (up to the first `/`, `?` or `#`), after its last `@`, with brackets taken off; a `[` that is never closed is refused. `ssh://a@b@-oX/p`, `ssh://[-oX]/p`, `git@[-oX]:p` and `a@b@-oX:p` are refused. `https://example.org/repo@-v1.git` is accepted. — `manifest.py`, f656ee2a
- [x] (must-fix 3) The swap. SIGINT is held with SIGTERM and SIGHUP. Whatever stops the run, the `finally` reads the disk: if `--out` is missing, the previous output goes back from `old`. Tests: SIGINT is in the held mask during the swap; a real SIGINT sent between the renames leaves the new output; a KeyboardInterrupt raised between them, as on a platform where signals cannot be held, leaves the old output. Neither leaves a temporary directory behind. design.md#resolve is updated. — `output.py`, 41cbff57
- [x] (must-fix 4) `roles: {}` is refused, with a spec line and a test. — `manifest.py`, de03f0fd
- [x] (must-fix 5) The private repo's name. `test_project11.py` reads the key and url from the old fixture's `site.repos` at run time. Its guard test now also checks the test file itself, and it failed when the name was appended to the file. The plan's mention is reworded. — `tests/test_project11.py`, 49bc8151
- [x] (must-fix 6) plan.md. The Prior Art line now says only the old reader's detailed signal handling goes, and names what the new reader keeps. The manifest-dir `optional.txt` reason is corrected, since `init` and `sync` (#500) read the default layout, and it has a row in the additions table. — `plan.md`, 62d137f8
- [x] (must-fix 7) The tool's design says "a caller that needs `repos/<layer>.repos`, `layers.txt` and `optional_layers.txt`" and no longer names the adapter. `tests/test_documents.py` checks README.md and docs/*.md, leaving out prototype.md, which goes in part 3. — `docs/design.md`, 88c6e3cc, fa1d9aa6
- [x] (suggestion 1) A signal delivered after the swap now prints "stopped by SIGTERM after --out <out> was replaced by the new output". `write_output` takes an `on_replaced` callback for this. Tested. — `cli.py`, 41cbff57
- [x] (suggestion 2) A repo key that starts with `#` is refused (host decision), with a spec line. `a#b` is still accepted. — `manifest.py`, 79b5dee7
- [x] (suggestion 3) The sweep. Temporary directories are named `.<name>.(new|old)-<pid>-<random>`. The sweep removes only a directory with exactly that shape, named for this output, whose process has ended, and only if it holds the marker or is empty. A live run's directory and names that merely look similar are left alone. An `--out` named like a temporary directory is refused. Tested. design.md and the module docstring are updated. — `output.py`, 2ca89190
- [x] (suggestion 4) Without `--role` and `--distro`, a missing file or one that does not parse now reports its own error, for both resolve and validate. Tested. — `cli.py`, `manifest.py` (`read_problem`), 0856619b
- [x] (suggestion 5) The checks on `--out` run inside an OSError handler: "cannot be checked (Permission denied)" instead of an internal error. Tested. — `output.py`, 7f23a75c
- [x] (suggestion 6) Layer names that differ only in case are refused, and reserved layer names are compared without case (host decision). spec.md has two lines for this. Repo keys keep the destination check. — `manifest.py`, 79b5dee7
- [x] (suggestion 7) Only a leading `<word>::` is the transport form. IPv6 urls (`ssh://user@[::1]/repo`, `ssh://[::1]:22/repo`, `https://[2001:db8::1]/a.git`, `git@[::1]:repo`) are accepted. — `manifest.py`, f656ee2a
- [x] (suggestion 8) A url's user or port that starts with `-` is refused. spec.md now names the user, host and port. — `manifest.py`, f656ee2a
- [x] (suggestion 9) The BOM test went in with must-fix 1 (066f284a). The unknown key in a distro entry has its own test (346f97d9). — `tests/test_manifest_reading.py`
- [x] (suggestion 10) CI job name — `.github/workflows/validate.yml:56` (deferred: host decision: the job name keeps "(#267 prototype)"; nothing under .github/ changes in this round)
- [x] (suggestion 11) Added to part 3 step 4 of the plan: before `tests/fixtures/p11/` goes, the 44-repo test is removed with a line saying why, and the private-name guard is given another source or removed with a line saying why. The test itself is unchanged beyond must-fix 5. — `plan.md`, 62d137f8
- [x] (host decision) The scp form also accepts `host:path` with no user, for ssh host aliases, and the bracketed `[::1]:path`. The host is still checked and every `name::address` form is still refused. A path with a `/` before its first `:`, or with no `:`, is a path on the local disk, so a relative one is refused. spec.md's transport line is updated. — `manifest.py`, 766bd700

Host decisions recorded here for the owner's veto: layer names compared without case (suggestion 6); repo keys starting with `#` refused (suggestion 2); the scp form without a user accepted; the CI job name kept.

Left open for the host:
- progress.md still names the private repo in the Issue Review entry (lines 53, 55, 65, 67) and in the Local Review finding at line 482. Those are earlier entries in the timeline, and this pass did not rewrite them.
- On Python 3.10, whose Unicode tables are older, characters assigned after Unicode 13 are refused as unassigned. On 3.14 they are accepted if they are visible.

Suites run on Python 3.14:
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest tools/repos-manifest/tests`: `619 passed in 11.41s`
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: `=== Results: 1014 passed, 0 failed, 0 skipped ===`
- Python 3.10 was not run here. The changed files parse with the 3.10 grammar (`ast.parse(..., feature_version=(3,10))`), and CI runs 3.10.
- The full pre-commit pass was left to the host. Every commit ran its hooks with `SKIP=validate-script-tests`. black reformatted three times, and those commits were made again after the reformat. flake8 found one long line, which was fixed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 14:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-498 at `765a5a39`
**Base**: origin/main
**Depth**: Deep (reason: fix-round re-review classified on the whole diff: input-safety checks and an output writer that replaces and deletes directories; 69 files, +4447 -173; touches .github/workflows)
**Must-fix**: 1 | **Suggestions**: 15
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 7), not rising; fix and ship rather than another full round

Part 1 only. All 7 round 1 must-fix items are fixed, and each of the three tests checked by mutation in a scratch copy fails without its fix: `roles: {}` accepted fails `test_an_empty_roles_mapping_is_refused`; the host taken after the first `@` fails `test_other_transports_are_refused[ssh://a@b@-oProxyCommand=x/p...]`; no restore of `old` fails the two put-back tests in test_output.py. Selection still shows no bug, and the old reader's tests are untouched. The old reader's behaviour has changed in one way: it shares `has_unsafe_char`, so it now refuses the wider set of characters too (suggestion 15). `git diff -U0 origin/main -- .github` is still only the 3.10/3.14 matrix and the job name. Outside .agent/work-plans/, no changed file spells out the private repo's name, and the fixture names only public repos plus the made-up `example/site_config`. All changed .py files parse with the 3.10 grammar, and no newer library feature was found. Python 3.10 was not run here.

The default-ignorable list matches DerivedCoreProperties exactly. Accented letters (NFC and NFD), CJK, Arabic, Hebrew and plain emoji are accepted. The url probes git would read as an option or as a command transport are refused, with two exceptions: the percent-encoded ones and those with `?`/`#` before an `@` in ssh:// (must-fix 1). git 2.53 shows both: it decodes `ssh://%2doProxyCommand=x/p` and then blocks it itself, and it hands ssh `h?x@-oProxyCommand=y` for `ssh://h?x@-oProxyCommand=y/p`. IPv6, ports, `file://`, ssh aliases, `C:/x` (read as scp, as git does), and `@` or `:` in a path are accepted. SIGTERM during the swap, SIGKILL before either rename, and a dead pid above pid_max are each handled.

Host decisions, reviewer's view: layer names compared without case, agree. Repo keys starting with `#` refused, agree. The scp form without a user accepted, agree: it matches git, and the host is still checked. The CI job name kept, agree: no required check names it.

Suites on Python 3.14.4: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests` gives `619 passed`; `bash .agent/scripts/tests/test_ros2_colcon.sh` gives `=== Results: 1014 passed, 0 failed, 0 skipped ===`.

Specialists: static analysis (3.10 grammar parse; pre-commit covers the rest), governance and plan drift (Claude subagent), Claude adversarial (subagent), cross-model codex (completed, EXIT=0). Cross-model gemini failed (EXIT=1): empty response, after a Bash tool action was auto-denied in headless mode. Governance also flagged the private repo's name in this timeline's earlier entries. The handoff exempts the timeline as history, so it is not a finding.

### Findings
- [x] (must-fix) The url authority is not parsed as git parses it: `%`-encoded `-` passes (`ssh://%2doProxyCommand=x/p`, `ssh://h:%2d1/p`; git decodes, then only git's own check stops it), and for ssh:// the authority is cut at `?`/`#` though git and spec.md:438 cut at `/` only (`ssh://h?x@-oProxyCommand=y/p` passes; git hands ssh `h?x@-oProxyCommand=y`); for ssh:// split at `/` only, and unquote the authority (or refuse `%` in it) before the checks, with tests — `tools/repos-manifest/src/repos_manifest/manifest.py:214`
- [x] (suggestion) A comment with `⚠️`/`❤️` (U+FE0F), a ZWJ emoji sequence, or Persian/Indic text with ZWNJ/ZWJ is refused, and a character newer than the running Python's Unicode is refused as unassigned (3.10 refuses what 3.14 accepts). The code matches the spec, so this is the owner's call: allow U+200C, U+200D, U+FE0E and U+FE0F in the whole-text check, since keys and values have their own check. Either way, say in spec.md that the Unicode version of the Python running the tool decides "unassigned" — `tools/repos-manifest/src/repos_manifest/yamlload.py:24`
- [x] (suggestion) A lone carriage return (not before a newline) is allowed. A terminal returns to column 0 at it, so a comment after it can hide a `url` under `cat`. Allow CR only as part of CRLF, and say so in spec.md — `tools/repos-manifest/src/repos_manifest/yamlload.py:71`
- [x] (suggestion) A sibling named `.out.new-99999999999999999999-abcdefgh` makes every resolve fail with "internal error (OverflowError)" from `os.kill`; treat a pid out of range as not known to have ended — `tools/repos-manifest/src/repos_manifest/output.py:130`
- [x] (suggestion) After a SIGKILL between the renames there is no `--out`, and the next run sweeps the marked `.old-*` copy before writing; if that run then fails on an OS error, the last output is gone. Move it back to `--out` in the sweep when `--out` is missing — `tools/repos-manifest/src/repos_manifest/output.py:145`
- [x] (suggestion) If `rmtree(old)` is cut short after it has deleted the marker, the remaining directory is neither marked nor empty, and no later run sweeps it; delete the marker last — `tools/repos-manifest/src/repos_manifest/output.py:241`
- [x] (suggestion) A SIGINT held during the swap comes out after it as a bare KeyboardInterrupt with a traceback and no "after --out was replaced" line; route it through `Stopped` like SIGTERM — `tools/repos-manifest/src/repos_manifest/cli.py:64`
- [x] (suggestion) `--out` is resolved lexically. `--out .` replaces the current directory, leaving the shell in a deleted one (rc 0), and `--out link/../x` writes beside `link`, not where the kernel resolves the path, while the printed paths point to the other place. Refuse the cwd and its ancestors, and resolve the parent with realpath — `tools/repos-manifest/src/repos_manifest/output.py:173`
- [x] (suggestion) Replacing an existing `--out` drops its mode (a 0700 output becomes 0755); keep the previous directory's mode — `tools/repos-manifest/src/repos_manifest/output.py:213`
- [x] (suggestion) Two runs on the same `--out` end whole, but some fail with misleading messages ("Directory not empty", "exists and is not a directory"); take an flock beside `--out`, or say in design.md that concurrent runs are not supported — `tools/repos-manifest/src/repos_manifest/output.py:217`
- [x] (suggestion) In the bracketed scp form, the user and port inside the brackets are not split out (`[a@-oX]:p`, `[h:-p]:path` accepted). git passes them as one argument, so this is harmless, but it differs from the spec's rule — `tools/repos-manifest/src/repos_manifest/manifest.py:44`
- [x] (suggestion) spec.md does not say two things the code does: an unknown key in a distro entry is warned about (line 133 names repo entries only), and an entry for an unlisted distro is still checked, though not used (line 208 says "ignored") — `tools/repos-manifest/docs/spec.md:208`
- [x] (suggestion) design.md says `validate` checks "without resolving it for a machine" at line 207 and "resolves it for every role and distro" at line 697; and no document says that `--role`/`--distro`/`--with` narrow the check — `tools/repos-manifest/docs/design.md:207`
- [x] (suggestion) Plan drift for the PR description: plan line 45's job name lacks the `(Python <version>)` suffix; the Files to Change table lists `docs/manifest/design.md` for part 3 only (it changed in part 1) and lacks `tests/test_documents.py` — `.agent/work-plans/issue-498/plan.md:45` (deferred: host decision: answered by the host, who writes the pull request body and states the three items there; the plan is not edited)
- [x] (suggestion) `test_documents.py` bans the word `adapter` anywhere in the tool's documents, which a generic use would trip; match `ros2_colcon` and the workspace adapter's wording, or say in the docstring that the word is banned on purpose — `tools/repos-manifest/tests/test_documents.py:19`
- [x] (suggestion) The old reader now refuses the wider character set (it imports the shared `has_unsafe_char`), against the plan's "moved unchanged"; say so in design.md or the PR, or keep the old predicate for `schema.py` — `tools/repos-manifest/src/repos_manifest/yamlload.py:63` (deferred: host decision: the check stays shared; the Implementation entry states it for the pull request, and the old reader goes in part 3)

## Implementation
**Status**: complete
**When**: 2026-11-18 14:25 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-498 at `b03c1da9`
**Addressed**: Local Review (Pre-Push) at `765a5a39` (2026-11-18 14:13 -05:00)
**Commits**: 91d7f4ec 74a3acc8 1d9cc0f7 17c6807f 752383de d82fbb01 7eb17a0d 15eabd60 096ded8b 73d68032 570c4b4d 5092d5a9 b03c1da9

Second fix round for part 1. Each code fix has a test that was run against the source as it was at `fbaca8b4` and failed there; the document-only fixes (9, 11, 12) have none.

### Actions
- [x] (must-fix) The url's user, host and port are read as git 2.53 reads them, checked against what git hands ssh (GIT_SSH set to a script that prints its arguments). They run to the first `/` after the host, so a `?` or `#` before it is part of them. git finds a host in brackets after the first `@[` wherever it is, so `ssh://x/@[-oProxyCommand=y]/p` and `h:p@[-oProxyCommand=y]:q` were holes too (git hands ssh `x/@-oProxyCommand=y`), and both are now refused. A `%` in the user, host or port is refused for every transport and the scp form; spec.md says why. Refused in tests: `ssh://%2doProxyCommand=x/p`, `ssh://h:%2d1/p`, `ssh://h?x@-oProxyCommand=y/p`, `ssh://h#x@...`, `https://h?x@-y/p`, `%2dh:a.git`. Accepted in tests: `%`, `?`, `#` and `@-` in the path. — `manifest.py`, 91d7f4ec
- [x] (suggestion 1) The rule stays (host decision). spec.md says it refuses an emoji with a variation selector or a zero-width joiner, and the joiners Persian and the Indic scripts use, comments included. It also says "unassigned" follows the running Python's Unicode tables, and that the message names code point, line and column. The message already did. A new test shows it for U+FE0F, U+200D and U+200C in a comment. — `spec.md`, `tests/test_manifest_reading.py`, 74a3acc8
- [x] (suggestion 2) A carriage return is allowed only as part of CRLF. A manifest is now read from the disk with `newline=""`. Text mode had turned a lone CR into a newline before the check could see it, so the file test failed before the fix. — `yamlload.py`, `manifest.py`, 74a3acc8
- [x] (suggestion 3) A pid that `os.kill` cannot take (OverflowError, ValueError) is not known to have ended, so the directory is left alone. Tested with `99999999999999999999`, `2147483648` and `0`. — `output.py`, 1d9cc0f7
- [x] (suggestion 4) When `--out` is missing, the next run first moves the newest marked `.<name>.old-*` of an ended process back into place. The test sets up the post-kill state on disk and then makes the run fail, and the previous output is still there. — `output.py`, `design.md`, 752383de
- [x] (suggestion 5) Temporary directories are removed by `_remove_ours`, marker last. A removal cut short leaves the marker, and the next run sweeps the directory. Tested by making unlink fail. — `output.py`, 17c6807f
- [x] (suggestion 6) SIGINT ends the run through `Stopped`, as SIGTERM does. It prints "stopped by SIGINT after --out ... was replaced" or "nothing was written" and exits 130. With Python's default handler it shows no KeyboardInterrupt and no traceback; another handler is delivered the signal again. — `cli.py`, `design.md`, d82fbb01
- [x] (suggestion 7) `--out` is found on the disk first: its directory is realpath'ed, its last part kept, and `.`/`..` resolved. The current directory and its parents are refused, and the printed paths are the ones written. Tested: `.`, `..`, `../..`, and `link/../x`, which is now written beside the link's target. — `output.py`, `design.md`, 7eb17a0d
- [x] (suggestion 8) A replaced output keeps the mode of the directory it replaces. A new one gets mkdir's mode as before. Tested with 0700, 0750 and 02775, and umask 027. — `output.py`, 15eabd60
- [x] (suggestion 9) No lock (host decision). design.md says two runs on one output at once are not supported. Each still leaves a whole output, and a lock belongs with init and sync (issue 500). — `design.md`, 096ded8b
- [x] (suggestion 10) Chosen by what git does: inside the brackets of the scp form, ssh reads a user before the last `@` and git a port after a `:`. The parts are split and checked, so `[a@-oX]:p`, `[-oX@h]:p` and `[h:-p]:path` are refused. spec.md says so. — `manifest.py`, `spec.md`, 91d7f4ec
- [x] (suggestion 11) spec.md now says an unknown key in a distro entry is warned about, and an entry for an unlisted distro is checked but never used. — `spec.md`, 570c4b4d
- [x] (suggestion 12) design.md's command table and "What is built" now say `validate` resolves every role and distro and writes nothing. They also say what `--role`, `--distro` and `--with` do there. — `design.md`, 73d68032
- [x] (suggestion 13) Plan drift — `plan.md:45` (deferred: host decision: answered by the host, who states the three items in the pull request body; the plan is not edited)
- [x] (suggestion 14) `test_documents.py` bans `ros2_colcon`, `.agent/`, "project-type adapter", "workspace('s) adapter" and "the adapter", not the word itself. The docstring says what it guards, and a second test shows a general use passes. — `tests/test_documents.py`, 5092d5a9
- [x] (suggestion 15) The old reader shares `has_unsafe_char` — `yamlload.py:63` (deferred: host decision: it stays shared; for the pull request, the old reader in `schema.py` now refuses the wider set of invisible characters too, against the plan's "moved unchanged", and it is removed in part 3)

Host decisions recorded for the owner's veto: the invisible-character rule kept as written, emoji with selectors or joiners included (suggestion 1); no lock for two runs at once (suggestion 9); the old reader keeps the shared check (suggestion 15). This pass also chose to refuse `%` in the scp form's user and host, though git does not decode it there, so the rule reads the same for every form. It also chose to refuse a bracketed port that starts with `-`, which git would not take as a port.

Suites run on Python 3.14:
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest tools/repos-manifest/tests`: `674 passed in 11.62s`
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: `=== Results: 1014 passed, 0 failed, 0 skipped ===`
- Python 3.10 was not run. Every changed .py file parses with the 3.10 grammar, and nothing newer than 3.8's library is used.
- The full pre-commit pass was left to the host. Every commit ran its hooks with `SKIP=validate-script-tests`, and black and flake8 passed on each.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 14:33 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-498 at `304fded6`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff; whole diff is Deep: input-safety checks and an output writer that replaces and deletes directories, 69 files, +4880 -175)
**Must-fix**: 2 | **Suggestions**: 4
**Round**: 3 | **Ship**: continue — round 3: must-fix rising (1 -> 2); both are mechanical one-place fixes, so the host may choose fix-and-ship over a fourth round

Round 3 convergence check: the round 2 findings and `git diff fbaca8b4..HEAD` (91d7f4ec..304fded6) only. The round 2 must-fix is fixed for what it named: `ssh://%2doProxyCommand=x/p`, `ssh://h:%2d1/p` and `ssh://h?x@-oProxyCommand=y/p` are refused, with tests. But git decodes the whole url before it looks for `@[`, so an encoded `@[` in the path still gets a host starting with `-` to ssh (must-fix 1). The other 14 round 2 items were checked against the code and docs: done as the Implementation entry says (CR only in CRLF, invalid pid left alone, marker removed last, put-back of the marked old copy, `--out` resolved on the disk, mode kept, spec and design lines, narrowed documents test). One fix brought a regression: SIGINT now ends with a plain exit 130 instead of death by SIGINT (must-fix 2).

Checked by running: about 25 urls against git 2.53 with a GIT_SSH that prints its arguments, plus an independent probe of about 45 by the adversarial subagent. Ordinary urls pass: https with a port, `ssh://git@host:2222/path`, `git@host:owner/repo.git`, `host:path`, IPv6 in brackets (ssh:// and scp forms), `file:///abs`, absolute paths, `%20`, `?`, `#` and `@` in a path. `--out` under the current directory (`sub/out`, `./sub/deep/out2`, `../../out` from below) is accepted; `.`, `..`, `sub/..`, `sub/deep/../..` are refused. Put-back moves a dead run's marked `.old` copy back and leaves a live run's copy alone; the kept mode (0700) survives. A CRLF manifest validates, error line and column are right in CRLF files, a lone CR is refused at its position; `has_repositories_key` still reads in universal-newline mode, which only routes the file and gives the same result. The old reader does not use the text check, so `newline=""` does not change it. The fixer's two choices for the owner's veto (`%` refused in the scp form; a bracketed port starting with `-` refused): reviewer agrees with both.

Suites on Python 3.14.4: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests` gives `674 passed in 11.49s`; `bash .agent/scripts/tests/test_ros2_colcon.sh` gives `=== Results: 1014 passed, 0 failed, 0 skipped ===`. `git diff fbaca8b4..HEAD -- .github` is empty. Every changed .py parses with the 3.10 grammar; the new library calls (`Path.unlink(missing_ok=)`, `signal.raise_signal`) are 3.8. Python 3.10 not run here.

Specialists: static analysis (3.10 grammar parse; pre-commit covers the rest), governance and plan drift inline (docs updated with the design per ADR-0017; no plan drift beyond round 2's deferred item), Claude adversarial (fresh subagent; found must-fix 2 and suggestion 1, both re-run here). Cross-model: skipped (round-3 convergence check, per handoff).

### Findings
- [x] (must-fix) git url-decodes the whole `ssh://` url before its host_end() looks for `@[`, so an encoded `@[` in the path passes: `ssh://host/x%40[-oProxyCommand=y]/p`, `ssh://host/x@%5b-oProxyCommand=y]/p` and `ssh://host/x%40%5b-oProxyCommand=y%5d/p` are accepted and git hands ssh `host/x@-oProxyCommand=y` (OpenSSH 10.2 then refuses the hostname, as git did for round 2's case); for urls with `://`, find the host on the decoded text (or refuse `%40`/`%5b` in the path), and fix spec.md's "refusing `%` there is simpler than decoding" line, with tests — `tools/repos-manifest/src/repos_manifest/manifest.py:216`
- [x] (must-fix) A Ctrl-C now ends `resolve` with a normal exit 130, not death by SIGINT (Python's own KeyboardInterrupt exit did that before), so a shell loop over `resolve` keeps going: reproduced, `exit=130 run 1`, `exit=0 run 2`, `loop-done`; for SIGINT set `SIG_DFL` and `raise_signal` after the message, with a test on the exit signal — `tools/repos-manifest/src/repos_manifest/cli.py:94`
- [x] (suggestion) The kept mode is applied to the new directory before its files are written, so an existing `--out` with mode 0555 can no longer be replaced ("cannot be written (Permission denied)"); chmod after writing. With a read-only old copy, `_remove_ours(old)` also fails silently and leaves a marked `.old` each later sweep fails on — `tools/repos-manifest/src/repos_manifest/output.py:285`
- [x] (suggestion) An `@[` with no `]` is refused as "the host has an unclosed '['" where git takes no bracketed host: `ssh://h/p@[x`, `git@h:p@[x`, `https://h/x@[y`; follow git (no bracketed host) — `tools/repos-manifest/src/repos_manifest/manifest.py:241`
- [x] (suggestion) If a removal of the old copy after a good swap is cut short (marker kept, files partly gone) and the person then deletes `--out`, the next run puts the partial copy back as the output, and it stays if that run fails; remove `old` by first renaming it to a `.new-` name, which is swept but never put back — `tools/repos-manifest/src/repos_manifest/output.py:171`
- [x] (suggestion) design.md: "the new one keeps its mode" reads as the new hidden directory; say "the new output keeps the mode of the one it replaces" — `tools/repos-manifest/docs/design.md:301`

## Checkpoint
**When**: 2026-11-18 14:34 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 found two located must-fix items; fixing them is mechanism, and the owner is told and may veto)
**After**: rounds
**Decision**: address

Round 3 (a convergence check) asked for two more fixes, so the limit of three rounds was reached without approval. The host answers address once: fix the two must-fix items and the four suggestions, then publish.

Host decisions for this fix round (owner may veto):
- The url rule stops following git's parser case by case. Three rounds each found another way to write an ssh address that git reads differently from the check. The owner's stated balance is that a manifest is read like a snippet of code from the internet and that unlikely corner cases should not take much time, so the rule becomes simple and structural: in an ssh:// url and in the scp form, a % is refused anywhere, and [ and ] are allowed only around the host at the start of the address. A path with % or brackets in an ssh address is refused; https and file urls keep % in the path. Undoing it: decode and search as git does.
- Ctrl-C on resolve ends the process by the signal again, after the message, so a shell loop stops.

## Implementation
**Status**: complete
**When**: 2026-11-18 14:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-498 at `3c2d0775`
**Addressed**: Local Review (Pre-Push) at `304fded6` (2026-11-18 14:33 -05:00)
**Commits**: 7f790c23, 8d54346c, 0a188846, 3c2d0775

Third fix round, per the Checkpoint of 2026-11-18 14:34: the url rule for ssh addresses is now structural rather than following git's parser case by case. Each code fix has a test that fails on the code before it (run against a copy of the previous source: 20 url cases, the SIGINT exit, the three output cases).

Check with git 2.53 itself (GIT_SSH set to a script that logs its arguments, GIT_SSH_VARIANT=ssh, `git ls-remote <url>`), 20 urls: the review's three encoded urls, `ssh://x/@[-oProxyCommand=y]/p`, `h:p@[-oProxyCommand=y]:q`, `ssh://h?x@-oProxyCommand=y/p`, `ssh://h:%2d1/p`, `ssh://[h]:-p/p` and `git@-oProxyCommand=x:a` are refused by the tool (git hands ssh hosts such as `host/x@-oProxyCommand=y` and `h:-1` for them); `ssh://git@host:2222/owner/repo.git`, `git@github.com:owner/repo.git`, `host:path`, `ssh://user@[::1]/repo`, `[::1]:repo`, `user@[::1]:repo`, `ssh://user@[::1]:22/p`, `ssh://git@example.org/a?b@-c#d.git`, `ssh://git@example.org/a@-b.git`, `ssh://a@b@[h]:22/p` and `[git@h:22]:a.git` are accepted, and for none of them does ssh get an argument starting with `-` other than git's own `-o SendEnv=GIT_PROTOCOL` and `-p <port>` (ports 2222 and 22).

Suites on Python 3.14.4: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest tools/repos-manifest/tests` gives `695 passed in 11.76s`; `bash .agent/scripts/tests/test_ros2_colcon.sh` gives `=== Results: 1014 passed, 0 failed, 0 skipped ===`. Changed .py files parse with the 3.10 grammar; Python 3.10 itself not run. Commits used `SKIP=validate-script-tests` (dispatched pass, #465); black, flake8 and pylint ran on each commit (black reformatted the first, then passed). The full pre-commit pass is left to the host. Nothing under .github/ changed.

### Actions
- [x] (must-fix) An ssh address (`ssh://` url or the scp form) now holds no `%` anywhere, and `[`/`]` only as one pair around the host at its start (after an optional `user@`); anything else is refused. The `@[`-anywhere search and the unclosed-bracket case are gone; https, http and file urls keep `%`, `[`, `]` in the path; spec.md states the rule and its reason; the review's three urls and earlier rounds' urls are tested refused, the ordinary forms accepted — `tools/repos-manifest/src/repos_manifest/manifest.py:218`, `tools/repos-manifest/docs/spec.md:446`
- [x] (must-fix) The command's entry point `run()` (console script, now `repos_manifest.cli:run` in pyproject.toml, and `python -m`) ends the process by the signal after the message and cleanup: SIG_DFL then raise_signal, for SIGINT, SIGTERM and SIGHUP; `main()` still returns 128 + the signal for in-process callers. Test: the return code of a subprocess is `-signum` for all three (SIGINT was 130 before); design.md says so — `tools/repos-manifest/src/repos_manifest/cli.py:280`
- [x] (suggestion) The kept mode is applied after the files are written, so a 0555 `--out` is replaced and keeps 0555; a directory is made writable before it is removed, and a failed removal of the previous copy is reported as a WARNING on stderr — `tools/repos-manifest/src/repos_manifest/output.py:142`
- [x] (suggestion) Covered by must-fix 1's rule: a bracket outside the host position is refused in an ssh address (`ssh://h/p@[x`, `git@h:p@[x`), and in https and file urls a `[` in the path is no longer read as a bracketed host (`https://h/x@[y` accepted) — `tools/repos-manifest/src/repos_manifest/manifest.py:48`
- [x] (suggestion) After a good swap the previous copy is renamed to a `.new-` name, which a later run sweeps but never puts back, before it is removed; test: a cut-short removal, `--out` deleted, a failing run leaves no output — `tools/repos-manifest/src/repos_manifest/output.py:162`
- [x] (suggestion) design.md says "The new output keeps the mode of the one it replaces" — `tools/repos-manifest/docs/design.md:302`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 14:51 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-498 at `b88a372a`
**Base**: origin/main
**Depth**: Deep (reason: round 4 convergence check per handoff; whole diff is Deep: input-safety checks and an output writer that replaces and deletes directories, 70 files, +5130 -177)
**Must-fix**: 0 | **Suggestions**: 3
**Round**: 4 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round 4 convergence check: the round 3 findings and `git diff 2993b76b..HEAD` (7f790c23, 8d54346c, 0a188846, 3c2d0775 and the progress commits) only. Both round 3 must-fix items are fixed, and all four suggestions are done as the Implementation entry says. The url rule is implemented as the Checkpoint states it: in an `ssh://` url and the scp form a `%` is refused anywhere, and `[`/`]` only as one pair around the host at the start (after an optional `user@` with no `/` or `:`); https, http and file urls keep `%`, `[`, `]` in the path. The Checkpoint's decision and its cost (e.g. `ssh://git@[fe80::1%25eth0]/r`, Azure `%20` paths, `ssh://h/r[1]` refused) are not findings.

Checked by running: about 60 urls of the reviewer's own against the checker and git 2.53 (GIT_SSH set to a script printing its arguments, GIT_SSH_VARIANT=ssh, `git ls-remote`), plus the adversarial subagent's randomized fuzz (seeds 1, 2, 7; 30000 tries; 2578 accepted urls). No accepted url gave ssh an argument starting with `-` other than git's own `-o SendEnv=GIT_PROTOCOL` and `-p <port>`. Ordinary urls are accepted: `ssh://git@host:2222/owner/repo.git`, `git@github.com:owner/repo.git`, `host:path`, `git@host:~/repo.git`, `ssh://git@host/~user/repo.git`, `ssh://user@[::1]:22/repo`, `[::1]:repo`, `[git@h:22]:a.git`, `ssh://user@review.example.com:29418/proj`, `git@ssh.dev.azure.com:v3/org/proj/repo`, https with `user:pass@` and IPv6 with port, `file:///abs/p%20q`, `file:///abs/path[1]`. Signals: the subprocess test gives return code `-signum` for SIGINT, SIGTERM and SIGHUP with "nothing was written" and no leftovers; the subagent ran `cli.run()` with a SIGTERM held during the swap (message "after --out out was replaced", -15, no leftovers) and a second SIGINT in the middle of removing the old copy (-2; a marked `.out.new-` left, swept by the next run, `out` intact). SIGTERM/SIGHUP end the process inside `_stopped` after the `with` has restored handlers and write_output's `finally` has run, so cleanup is finished first; in-process `main()` still returns 128+n; pyproject's console script is `repos_manifest.cli:run`, and `python -m repos_manifest.cli` reaches `run()`. Output writer: a 0555 output is replaced and keeps 0555; a SIGKILL during removal of the old copy leaves only a `.new-` directory, never put back; a kill between the `doomed` mkdtemp and its rename leaves an empty `.new-` and a full `.old-` beside an existing `out`, so put-back does not run and the sweep removes both.

Suites on Python 3.14.4: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests` gives `695 passed in 11.70s`; `bash .agent/scripts/tests/test_ros2_colcon.sh` gives `=== Results: 1014 passed, 0 failed, 0 skipped ===`. `git diff 2993b76b..HEAD -- .github` is empty. The five changed .py files parse with the 3.10 grammar (`ast.parse(feature_version=(3,10))`); new library calls (`signal.raise_signal`, `typing.Tuple`) are 3.8 or older. Python 3.10 itself not run.

Specialists: static analysis (pre-commit on the eight changed tool files: black, flake8 and the rest passed), governance and plan drift inline (spec.md and design.md updated with the code per ADR-0017; no drift from the Checkpoint's decisions), Claude adversarial (fresh subagent; no must-fix, suggestions 1 and 3 below). Cross-model: skipped (round-4 convergence check, per handoff).

### Findings
- [ ] (suggestion) `_remove_ours` makes only the top directory writable, so a read-only subdirectory a person added inside a marked output blocks removal of the previous copy; the WARNING says "a later resolve to the same place tries again", but `_sweep_leftovers` ignores the result and every later run fails on it silently, leaving `.out.new-<pid>-…` (reproduced: `mkdir out/sub; touch out/sub/f; chmod 555 out/sub`, two resolves, both exit 0); make subdirectories writable too (rmtree onerror chmod and retry) or reword — `tools/repos-manifest/src/repos_manifest/output.py:149`
- [ ] (suggestion) spec.md says the user, host and port "run to the first `/` after the host"; for https, http and file urls the code now ends them at the first `/` (a bracketed host is not looked through), so `https://[-x/y]/p` and `file://[-x/y]/p` are accepted though the spec's reading gives a host `-x/y`; harmless (not handed to ssh; curl rejects it), but say the "after the host" reading is for ssh addresses — `tools/repos-manifest/docs/spec.md:440`
- [ ] (suggestion) Urls git cannot use pass validation and fail only in git: no path (`ssh://h`, `ssh://[::1]:22`), an empty host (`[]:r`, `ssh://[]/r`, ssh gets an empty host argument), a path starting with `-` in the scp form (`h:-x`, `u:-x@h:p`; git refuses "strange pathname"); none hands ssh an option, likely older than this diff — `tools/repos-manifest/src/repos_manifest/manifest.py:218`

## Checkpoint
**When**: 2026-11-18 14:52 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 4 approved with no must-fix, and the full pre-commit pass passed at 20b12119)
**After**: publish
**Decision**: publish

The full pass (every hook, no SKIP, over the files the branch changes) passed on 20b12119. Published as part 1 of 3: the pull request says "Part of #498" and does not close the issue. Round 4's three suggestions go to the pull request's fix round with whatever its review finds.

## Integrated Review
**Status**: complete
**When**: 2026-11-18 15:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #506 at `0145c79`
**Sources**: 2 (Local Review (Pre-Push) @ `b88a372` (covers `0145c79` via bookkeeping), CI rollup); no hosted review (Copilot: 0 reviews, 0 comments at `0145c79`)
**Cross-source confirmations**: 0
**CI**: failures-noted

CI: "repos-manifest tests (#267 prototype) (Python 3.10)" fails in both the push and pull-request runs (run 44384980943, job 135086942894: 2 failed, 693 passed); Python 3.14, lint and the validation jobs pass. Cause, from Python 3.10's `Lib/pathlib.py` (3.10 branch): `_NormalAccessor.unlink = os.unlink` is bound when the class is defined, and `Path.unlink` calls `self._accessor.unlink(self)`. `_cut_short_removal` in `test_output.py` patches `output.os.unlink` (the `os` module's attribute), which `Path.unlink` on 3.10 never looks up again, while 3.12+ calls `os.unlink` at call time. `_remove_ours` removes the top-level files with `entry.unlink()`, so on 3.10 nothing fails, the removal completes, no WARNING is printed and no `.out.new-` directory is left; both assertions then fail. The fault is in the tests only: a real `OSError` from `Path.unlink` is raised and caught by `_remove_ours`' `except OSError` the same way on 3.10, so output.py reports a failed removal on 3.10 too. Must-fix all the same: a required interpreter fails.

### Findings
- [x] (must-fix, CI Python 3.10) `_cut_short_removal` patches `os.unlink`, which `Path.unlink` does not call through on Python 3.10 (pathlib binds `os.unlink` into `_NormalAccessor` at import), so the two cut-short-removal tests fail on 3.10; inject the failure where every supported version looks it up, e.g. `monkeypatch.setattr(output.Path, "unlink", ...)` failing for every name but the marker (and keep `os.unlink` patched for `shutil.rmtree`'s subdirectories), then run the suite under 3.10 if one can be had (uv/pyenv) or rely on the CI job — `tools/repos-manifest/tests/test_output.py:376`
- [x] (must-fix, Local Review (Pre-Push) @ `b88a372`, covers via bookkeeping) `_remove_ours` makes only the top directory writable, so a read-only subdirectory inside a marked previous output blocks its removal; the WARNING promises "a later resolve to the same place tries again", but `_sweep_leftovers` discards `_remove_ours`' result, so every later run fails on it without a word and the `.out.new-` directory stays forever. A silent failure, not a nit: make subdirectories writable as well (rmtree `onerror` that chmods the parent and retries, or a chmod walk first) and test a read-only subdirectory; also decide whether a sweep that cannot remove a leftover warns — `tools/repos-manifest/src/repos_manifest/output.py:143`
- [x] (should-fix, Local Review (Pre-Push) @ `b88a372`, covers via bookkeeping) spec.md says the user, host and port "run to the first `/` after the host", but for https, http and file urls the code ends them at the first `/` (manifest.py `url`, the non-ssh branch); the spec and code disagree, so say the "after the host" reading is for ssh addresses (`ssh://` and the scp form) and the others end at the first `/` — `tools/repos-manifest/docs/spec.md:440`
- [x] (should-fix, Local Review (Pre-Push) @ `b88a372`, covers via bookkeeping) Missing validation: urls git cannot use pass the check and fail only later in git: an ssh url with no path (`ssh://h`, `ssh://[::1]:22`), an empty bracketed host (`[]:r`, `ssh://[]/r`), an scp-form path starting with `-` (`h:-x`, `u:-x@h:p`). None hands ssh an option (no security hole), but the spec promises a manifest is checked before use; refuse them with the same `_URL_RULE` message and add cases to `test_manifest_reading.py` — `tools/repos-manifest/src/repos_manifest/manifest.py:218`

### False positives

Cross-model pass: warranted before merge. Gemini and Codex last saw `fbaca8b4`; since then 22 commits changed manifest.py's url checks (the guard against `git`/`ssh` reading a value as an option) and output.py's replace-and-remove of the previous output (it deletes directories on the user's disk), both places where a second model's adversarial read has found defects before. One pass on the head after this fix round, not one per round.

## Checkpoint
**When**: 2026-11-18 15:08 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (four located findings, one of them a failing CI job; fixing them is mechanism)
**After**: findings
**Decision**: address

Fix all four findings of the Integrated Review: the two tests that fail on Python 3.10 because they patch os.unlink, which pathlib does not go through there; the silent failure when a previous copy holds a read-only subdirectory; the spec line on where a url's user, host and port end; and the urls git cannot use that pass the check. The triage recommends one cross-model pass on the head after this fix round; the post-fix review of the pull request runs at full depth and includes it.

## Implementation
**Status**: complete
**When**: 2026-11-18 15:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #506 at `9b118f18`
**Addressed**: Integrated Review at `0145c79` (2026-11-18 15:07 -05:00)
**Commits**: d2142c6f, 0f90ae18, 91a7b971, 9b118f18

### Actions
- [x] (must-fix, CI Python 3.10) `_cut_short_removal` now patches `output.Path.unlink` (failing for every name but the marker) as well as `os.unlink` (kept for `shutil.rmtree`). Checked against cpython 3.10's `Lib/pathlib.py` (`_NormalAccessor.unlink = os.unlink` bound at class definition; `Path.unlink` calls `self._accessor.unlink(self)`) and `Lib/shutil.py` (`_rmtree_safe_fd` calls `os.unlink(entry.name, dir_fd=topfd)` by name at call time); on 3.14 `Path.unlink` calls `os.unlink` at call time, so the patched `Path.unlink` serves both. No 3.10 here: with a plugin emulating 3.10's bound `Path.unlink`, the old helper fails both tests and the new one passes, and the whole suite passes (718) — `tools/repos-manifest/tests/test_output.py:376`
- [x] (must-fix) `_remove_ours` makes every directory in the tree writable first (`_make_writable`: `os.walk`, top-down, chmod each real directory before it is entered; links are not followed or chmodded), and `_sweep_leftovers` prints a WARNING naming a leftover it cannot remove. Tests: a read-only (r-x and none) subdirectory inside the previous output, a leftover with a read-only subdirectory, a sweep that cannot remove a leftover warns and the next run sweeps it, a link in a copy keeps its target's mode; design.md says so — `tools/repos-manifest/src/repos_manifest/output.py:143`
- [x] (should-fix) spec.md now says where the user, host and port end for each kind of url: an `ssh://` url at the first `/` after the host, the scp form at the first `:` after the host, `https`, `http` and `file` at the first `/` after `://` — `tools/repos-manifest/docs/spec.md:440`
- [x] (should-fix) Refused: an `ssh://` url with no path, an empty host in any ssh address (bracketed or not: `[]:r`, `ssh://[]/r`, `ssh:///r`, `u@:r`), and an scp-form path starting with `-` (`h:-x`, `u:-x@h:p`); each with its own message rather than `_URL_RULE`, which does not explain them. New spec line; 17 refused cases and one accepted case in `test_manifest_reading.py`, all 17 failing before the change. The Checkpoint's ssh structural rule (no `%`, brackets only around the host) is unchanged — `tools/repos-manifest/src/repos_manifest/manifest.py:218`

### Python 3.10 check
Read every test file the branch adds or changes (test_output.py, test_manifest_reading.py, test_selection.py, test_documents.py, test_project11.py) and output.py, cli.py, manifest.py, selection.py, yamlload.py for the same class of problem. The only `os`/`shutil` patch reached through pathlib was `_cut_short_removal`; the `os.rename` patches reach `os.rename` calls made directly in output.py (never `Path.rename`), and `_write_text` is patched on the module. Behaviour that differs between 3.10 and 3.14 but gives the same result: `Path.exists`/`is_file` raise on EACCES on 3.10 and return False on 3.14, and the unreadable-out test gets "Permission denied" either way (from `is_file` on 3.10, `iterdir` on 3.14). No `onexc`/`onerror` on rmtree, `Path.walk`, `tomllib`, `except*` or other 3.11+ call; `is_relative_to`, `signal.raise_signal`, `pthread_sigmask`, `unlink(missing_ok=)` and `X | None` (with `from __future__ import annotations`, valid on 3.10 anyway) exist on 3.10. The unicode characters the tests use are assigned the same in Unicode 13.0 (3.10) and 16.0 (3.14), or are noncharacters, private-use or in the hard-coded default-ignorable table.

### Checks
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest tools/repos-manifest/tests` (Python 3.14.4): 718 passed in 11.69s
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: === Results: 1014 passed, 0 failed, 0 skipped ===
- Commits ran every hook but `validate-script-tests` (black and flake8 passed). The full pre-commit pass is left to the host; Python 3.10 itself was not run here (not installed) and is left to CI.

## Local Review
**Status**: complete
**When**: 2026-11-18 15:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #506 at `1c32487`
**Depth**: Deep (reason: input-safety checks on urls and an output writer that replaces and deletes directories on the user's disk; 70 files, +5376 -177)
**Must-fix**: 0 | **Suggestions**: 8

PR-mode review, round 1 (first PR-mode review), on the whole pull-request diff. Specialists: static analysis (flake8 and yamllint, from the pre-commit cache, on the changed .py and YAML files: clean; pylint's files pattern covers only `.agent/`), governance and plan drift inline, Claude adversarial (fresh subagent: no must-fix, four suggestions), cross-model (`cross_model_review.sh --pr 506 --issue 498 --agents gemini,codex`; `--issue` was needed because the body says "Part of #498"): Codex completed (5 rows marked must-fix, 2 suggestions; checked below), Gemini failed twice, the same way each time ("empty response; 1 tool action auto-denied in headless mode (Bash)"), so no Gemini review of the code after fbaca8b4 exists.

Codex's must-fix rows, checked against the code: the gap between the two renames is the plan's choice (renameat2 rejected, a reader runs after `resolve`, not during it): not a finding. The old reader's stricter character check is a host decision listed in the PR body: not a finding. The umask, the failed put-back and the non-strict realpath are real but need an unlikely path to matter: suggestions 1-3. The drive-letter keys (Windows) and the CI row (owner-approved; the repo's ruleset requires no status checks, so the job rename blocks nothing): dropped.

Checked by running: `--out regular-file/../out` and `--out missing/../out2` both write `./out` and `./out2` (exit 0) where `ls regular-file/../out` gives "Not a directory". The adversarial subagent ran urls against git 2.53 with a GIT_SSH that prints its arguments: no accepted url hands ssh an option or runs a program (a leading space gets past the `::` regex, but git then gives ssh a host starting with a space, which ssh refuses). It also checked links inside a replaced output (outside targets keep their content and mode), signals during writing and during the swap (the process ends by the signal: -2, -15, -1; no leftovers), and the YAML and selection rules against the spec.

CI at 1c32487b, push and pull_request runs: "repos-manifest tests (#267 prototype) (Python 3.10)" pass, "(Python 3.14)" pass, Lint (pre-commit) pass, Validate Adapter Contract pass, Validate Documentation pass. Suites on Python 3.14.4: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests` gives `718 passed in 11.82s`; `bash .agent/scripts/tests/test_ros2_colcon.sh` gives `=== Results: 1014 passed, 0 failed, 0 skipped ===`.

### Findings
- [ ] (suggestion) `_on_disk` resolves the parent with non-strict realpath, so `--out regular-file/../out` and `--out missing/../out` write `./out` where the system refuses the path; design.md's "found on the disk ... as the system finds it" does not hold for them (only a marked or empty directory can be replaced). Use strict resolution of the existing part — `tools/repos-manifest/src/repos_manifest/output.py:259` (Codex, confirmed by lead)
- [ ] (suggestion) When putting the previous output back fails, the error says only "cannot be written"; it does not say `--out` is now missing and the previous copy is in `.<name>.old-…` (the next run puts it back). Name it in the message — `tools/repos-manifest/src/repos_manifest/output.py:352` (Codex)
- [ ] (suggestion) The mode is found by setting the process umask to 0 and back. A Stopped between the two calls leaves umask 0 for an in-process `main()` caller. Read it without changing it — `tools/repos-manifest/src/repos_manifest/output.py:326` (Codex)
- [ ] (suggestion) `ssh://u:p@[::1]/r` is refused because `_bracketed_host` refuses a user with `:`. spec.md says the text before the last `@` is a user, and git accepts this url. Allow it or state the limit — `tools/repos-manifest/src/repos_manifest/manifest.py:57` (Claude adversarial)
- [ ] (suggestion) The cleanup in write_output's `finally` and the steps just after each `mkdtemp` are not shielded from a second signal. Ctrl-C twice leaves a marked `.<name>.new-…` (swept by the next run), against design.md's "removes the hidden directory". Hold the signals during the cleanup or say so — `tools/repos-manifest/src/repos_manifest/output.py:346` (Claude adversarial)
- [ ] (suggestion) A `version` of `heads/-x` or `tags/-x` passes the "no leading `-`" rule, but vcstool strips the prefix and runs `git checkout -x --`. No program runs, but spec.md's "so git cannot read one as an option" is not true for it. Refuse `-` after a leading `heads/` or `tags/` — `tools/repos-manifest/docs/spec.md:438` (Claude adversarial)
- [ ] (suggestion) A leftover's liveness is judged by its pid alone, and `pid == os.getpid()` counts as ended. Runs on one disk from different PID namespaces (containers on a bind mount, two of them as PID 1) can sweep or put back each other's live directories. It fails closed, but design.md should state the assumption — `tools/repos-manifest/src/repos_manifest/output.py:126` (Claude adversarial)
- [ ] (suggestion) `_make_writable` stops the whole removal when it cannot chmod a directory it does not own, for example an empty root-owned subdirectory that rmtree alone could remove. It ends in a WARNING and a leftover. Ignore EPERM on a subdirectory chmod — `tools/repos-manifest/src/repos_manifest/output.py:156` (lead)

## Integrated Review
**Status**: complete
**When**: 2026-11-18 15:32 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #506 at `42e2663`
**Sources**: 2 (Local Review @ `1c32487` (covers `42e2663` via bookkeeping; its rows from Codex and the Claude adversarial pass, checked by the lead), CI rollup); no hosted review (0 reviews, 0 inline comments, 0 conversation comments at `42e2663`); Gemini failed twice (empty response)
**Cross-source confirmations**: 0
**CI**: pending

CI: at `1c32487b` every job passed in both runs, Python 3.10 included. At `42e2663` (a progress-only commit) every job has passed except "Lint (pre-commit)", pending in both runs at 15:32. The stale Local Review (Pre-Push) at `b88a372` (3 open boxes) was ruled on by the Integrated Review at `0145c79` and fixed in the Implementation at `9b118f18`; not re-listed.

Item 6 checked by running, in a scratch directory with a local bare repository (`file://`, no network). The installed `vcs` is vcstool 0.3.0 at `/usr/bin/vcs` (python3-vcstool); there is no `vcs` or vcs2l in the workspace `.venv`. vcstool's `import_` strips `heads/` and, for an existing checkout without `--skip-existing`, runs `git checkout <rest> --`. Results: a fresh `vcs import --skip-existing` with `version: heads/-x` runs `git clone -b -x`, which takes `-x` as the branch name (fine), and `tags/-x` checks out `tags/-x` (fine). A second `vcs import` without `--skip-existing` and `version: heads/-x` gives "Could not checkout ref '-x': error: unknown switch `x'". With `version: heads/-f`, against a remote that has a branch `-f`, that second import runs `git checkout -f --` and throws away a local edit without saying so (`git status` showed ` M f` before and nothing after, exit 0). The adapter's own call (`vcs import --skip-existing`, adapter.sh:1340) never takes that path. A person who runs `vcs import` on the output does, and spec.md's "so `git` cannot read one as an option" is false there.

### Findings
- [x] (should-fix, Local Review @ `1c32487` (Claude adversarial), confirmed by running) A `version` of `heads/-…` passes the "no leading `-`" rule, but vcstool strips `heads/`, and on a re-import without `--skip-existing` it runs `git checkout -<x> --`; `heads/-f` discards local changes silently (reproduced above). spec.md:438's "so `git` cannot read one as an option" is false for it. Refuse a `version` (repo and distro entry) whose text after a leading `heads/` or `tags/` starts with `-` (tags/ is safe in vcstool 0.3.0 but costs nothing to refuse alike), say so in spec.md, and add cases to `test_manifest_reading.py`. Fix before merge: a false statement in the spec, and a silent loss of work — `tools/repos-manifest/src/repos_manifest/manifest.py:469`
- [x] (should-fix, Local Review @ `1c32487` (Codex)) When putting the previous output back fails (`old = None` in `write_output`'s `finally`), the run ends with only "cannot be written (…)". `--out` is gone, and the previous copy sits in `.<name>.old-<pid>-…`, which the message does not say. design.md:311 promises "the previous one or the new one, never neither" and does not mention this exception. Rare (two renames in one directory failing in a row), but the output vanishes without the message saying so. Name the aside directory and say the next `resolve` to the same place puts it back (a WARNING before the error is enough), say so in design.md, and test it with the existing rename patches. Fix before merge: a silent state change against a documented guarantee — `tools/repos-manifest/src/repos_manifest/output.py:354`
- [x] (should-fix, Local Review @ `1c32487` (Codex), confirmed by lead) `_on_disk` resolves the parent with non-strict `realpath`, so `--out regular-file/../out` writes `./out` (exit 0) where `mkdir` gives "Not a directory". design.md:305's "as the system finds it" is false for it. It is harmless, since only a marked or empty `./out` is ever replaced, but the sentence is wrong. Refuse when the given parent fails with ENOTDIR (`os.stat` of the head as given; ENOENT keeps today's behaviour, since `mkdir -p missing/../out` also lands on `./out`), with the same "a part of the path is not a directory" message `write_output` already uses, plus a test. Fix before merge: a false statement in a document, five minutes — `tools/repos-manifest/src/repos_manifest/output.py:259`

### False positives
- (Local Review @ `1c32487` (Codex), umask set to 0 and back) No action. Between the two `os.umask` calls only a signal handler can run. The command's handlers (`cli.py` `_signals_end_the_run`, `main`) end the process by that signal, so the umask dies with it. SIGTSTP only pauses the process, and it resumes at the next call. The adapter runs the resolver as a command only (adapter.sh:16-17, "called by CLI only"); no in-process caller ships. If an in-process API is ever offered, wrap the two calls in `_signals_held()`.
- (Local Review @ `1c32487` (Claude adversarial), `ssh://u:p@[::1]/r` refused) No action. Git hands ssh `u:p@::1` (checked with a GIT_SSH that prints its arguments: `-o SendEnv=GIT_PROTOCOL u:p@::1 git-upload-pack '/r'`), so ssh would use the login name `u:p`. ssh takes no password from its address, so the url cannot work as written. A password has no place in a manifest, which people share and read anyway. The refusal is loud and fails closed, like the other urls git cannot use that were refused in the last round. The spec does not promise a user with `:`. Its message ("'[' and ']' are allowed only around the host") is imprecise for this input but names the url.
- (Local Review @ `1c32487` (Claude adversarial), a second signal during cleanup) No action. The cleanup removes a handful of small files, a window of milliseconds. What a second Ctrl-C leaves is a marked `.<name>.new-…` that the next `resolve` sweeps. design.md:311-313 already says a run ended before its cleanup can leave one and the next run removes it. Holding signals over the cleanup would trade that for a Ctrl-C that does not answer.
- (Local Review @ `1c32487` (Claude adversarial), liveness by pid across PID namespaces) No action. Leftovers are matched by the output's own name, so only runs to the same output can meet. design.md:320 already says two runs writing to the same output at once are not supported. A dead container's leftover whose pid is live on the host is kept, not removed (fails closed: a hidden marked directory).
- (Local Review @ `1c32487` (lead), `_make_writable` stops at a directory it cannot chmod) No action. It needs a directory owned by another user (root) inside an output that `resolve` generates and that holds only `.repos` files. Even then the result is a WARNING naming the leftover on every run, never a silent failure. rmtree alone would succeed only when that directory is empty; a non-empty one needs the other user to remove it either way.

## Checkpoint
**When**: 2026-11-18 15:33 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (three located should-fix findings: two false statements in the documents and one loss that is not reported)
**After**: findings
**Decision**: address

Fix the three open findings of the Integrated Review: an --out whose parent is not a directory is refused as the system refuses it; the message when the previous output cannot be put back names where it is and says the next resolve restores it, and the design says so; a version of heads/-x or tags/-x is refused, with the spec line. The five the triage ruled no action stay as ruled.

## Implementation
**Status**: complete
**When**: 2026-11-18 15:37 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #506 at `ee6683a`
**Addressed**: Integrated Review at `42e2663` (2026-11-18 15:32 -05:00)
**Commits**: 61ac9c5, 3c48fca, ee6683a

### Actions
- [x] A `version` (repo and per-distro entry) whose text after a leading `heads/` or `tags/` starts with `-` is refused; vcstool 0.3.0 (`/usr/lib/python3/dist-packages/vcstool/clients/git.py`, `import_` and `_check_version_type`) strips those two prefixes and no other. One spec line; tests for `heads/-f`, `tags/-x`, `heads/--orphan=x` refused and `heads/main`, `tags/v1.0`, `feature/-x`, `refs/heads/-x` read — `tools/repos-manifest/src/repos_manifest/manifest.py` (`version`), `tools/repos-manifest/docs/spec.md`
- [x] An `--out` that goes through something that is not a directory (`a-file/../out`, `a-file/../sub/out`, `a-file/..`) is refused with "cannot be written (Not a directory)"; a part that does not exist yet (`missing/../out`) is written as before. design.md says so; tests for both — `tools/repos-manifest/src/repos_manifest/output.py` (`_on_disk`, `write_output`), `tools/repos-manifest/docs/design.md`
- [x] When moving the previous output back fails, a WARNING says `--out` is now missing, names the `.old-` directory the previous output is in and says the next `resolve` to the same place puts it back; design.md states the one exception to "never neither". Test with the rename patches, including the next run putting it back — `tools/repos-manifest/src/repos_manifest/output.py` (`write_output` finally), `tools/repos-manifest/docs/design.md`

Suites on Python 3.14.4: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest tools/repos-manifest/tests`: 730 passed in 11.65s. `bash .agent/scripts/tests/test_ros2_colcon.sh`: === Results: 1014 passed, 0 failed, 0 skipped ===. Commits carry SKIP=validate-script-tests per the dispatched-pass hook rule; the full pre-commit pass is left to the host. The five findings ruled no action were not touched.

## Local Review
**Status**: complete
**When**: 2026-11-18 15:45 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #506 at `0d062ef`
**Depth**: Deep (reason: whole pull-request diff, fix-round rule: input-safety checks on urls and versions and an output writer that replaces and deletes directories on the user's disk; 70 files, +5559 -177)
**Must-fix**: 1 | **Suggestions**: 5

PR-mode review, round 2, after the fix round 61ac9c5, 3c48fca, ee6683a. The three fixes do what the Integrated Review asked, with tests. Ordinary inputs are unchanged, checked by running `resolve` and `validate`. These `--out` values were written where `mkdir -p` puts them: `out`, `./o2`, `sub/o3`, `sub/../o4`, absolute paths with and without `..`, `lnk/o7` and `lnk/inner/../o9` (beside the link's target), `lnk/../o8`, `missing/deep/o10`, `missing/../o11`, and `../o12` from a subdirectory. These were refused with "Not a directory": `afile/../x`, `afile/x`, `afile/..` and `flink/../y`. These versions were accepted in a repo and in a distro entry: `main`, `v1.2.3`, `heads/main`, `tags/v1`, a 40-character hash, `release/2.x`, `feature/-x` and `refs/heads/-x`. `heads/-x`, `tags/-x`, `heads/--orphan=x` and `-x` were refused in both places. vcstool 0.3.0's git.py strips only `heads/` and `tags/` (lines 344-348), as spec.md says.

On the fixer's question about an empty `--out` that had no marker: if the put-back fails, the next run sweeps the empty aside copy and writes a new output, so the WARNING's "puts it back" is not literally true. The only thing lost is an empty directory and its mode, after two failed renames in a row, so the wording needs no change. Codex's row 2 (a kill between the two renames with an empty `--out`) is the same case and is dropped for the same reason.

Codex's other rows: rows 1 and 4 and row 7 (`fail-fast` is quoted in the pull request body's owner-approved CI diff) are settled rulings or host decisions. Row 6 (a file replaced between the format check and the read) is dropped as not worth doing, since the wrong reader refuses loudly. Rows 3 and 5 are suggestions below.

CI at `0d062ef`, push and pull_request runs: "repos-manifest tests (#267 prototype) (Python 3.10)" pass, "(Python 3.14)" pass, Validate Documentation pass, Validate Adapter Contract pass, and Lint (pre-commit) was still pending at 15:45. Suites on Python 3.14.4: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests` gives `730 passed in 11.82s`; `bash .agent/scripts/tests/test_ros2_colcon.sh` gives `=== Results: 1014 passed, 0 failed, 0 skipped ===`. flake8 and black (pre-commit's cached environments) are clean on the four changed .py files.

Specialists: static analysis; governance and plan drift inline (spec.md and design.md changed with the code, per ADR-0017); Claude adversarial (a fresh subagent found the must-fix and suggestions 2 and 3, and the lead reproduced the must-fix); cross-model (`cross_model_review.sh --pr 506 --agents gemini,codex --issue 498`). Codex completed with 5 rows marked must-fix and 2 suggestions, triaged above. Gemini failed: agy exited 3 with "NOT_FOUND (code 404): Requested entity was not found."

### Findings
- [x] (must-fix, mechanical) A part that does not exist, followed by `..`, hides a file later in the path: the stat of the path as given fails with ENOENT, which is skipped, and realpath then removes `nope/..` by text alone. `--out nope/../afile/../p1` wrote `./p1` (exit 0), while `mkdir -p zz/../afile/../p3` gives "Not a directory". So design.md's "a path through something that is not a directory is refused" is false for this path, and the docstring's "left to `mkdir`" is inexact. The path is unusual and only harmless output results. Either check each part in order as `mkdir -p` does, or narrow the sentence to "a path whose existing parts go through a file". — `tools/repos-manifest/src/repos_manifest/output.py:263`, `tools/repos-manifest/docs/design.md:306` (Claude adversarial, reproduced by lead)
- [x] (suggestion) The marker check follows a link, so a directory with a person's files and a `.repos-manifest-output` link to any file counts as an output and is replaced. Nobody makes one by accident. Check that the marker is not a link, in `_is_ours_or_empty` and in the put-back — `tools/repos-manifest/src/repos_manifest/output.py:113` (Codex)
- [ ] (suggestion) A repo key with a leading or trailing space, or only spaces (`" "`, `" a"`, `"a "`), is accepted and written as a line of `optional.txt`. A reader that trims lines (bash `read`) or skips blank lines changes or loses it. Refuse leading and trailing whitespace in a key, as `#` is refused for the same list — `tools/repos-manifest/src/repos_manifest/manifest.py:433` (Codex, checked by lead)
- [ ] (suggestion) The WARNING promises that the next resolve puts the previous output back, but if anything makes `--out` first (a person's `mkdir out`), the sweep removes the marked `.old-` copy without a message. Say "if `--out` is still missing", or warn before sweeping an `.old-` copy — `tools/repos-manifest/src/repos_manifest/output.py:367` (Claude adversarial)
- [ ] (suggestion) `version: "heads/"` and `version: "tags/"` are accepted. From vcstool's source (not run), they leave an empty name, and `tags/` then skips the checkout in an existing repo. Refuse an empty remainder — `tools/repos-manifest/src/repos_manifest/manifest.py:206` (Claude adversarial)
- [ ] (suggestion) The pull request body's Verified and Reviews lines are stale (695 tests, four pre-push rounds). Refresh them before the merge — PR #506 body (lead)
