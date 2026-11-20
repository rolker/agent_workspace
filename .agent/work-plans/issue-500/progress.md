---
issue: 500
---

# Issue #500 — repos-manifest: init and sync set up and update a system directory

## Issue Review
**Status**: complete
**When**: 2026-11-18 16:15 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #500

### Scope Assessment

**Well-scoped?** Not as written; yes after a split — as written it is the whole system-directory machinery (init, layout, distro dirs, local manifest, a state file, per-repo update rules, optional repos, `--` passthrough) in one PR, and the owner's aim needs only part of it. Deliver in parts (see Recommendations).
**Right repo?** Yes — `tools/repos-manifest` in the workspace repo.
**Serves**: the manifest tool's goal of one system directory set up and kept in line from one manifest — `tools/repos-manifest/docs/design.md#the-system-directory`, `#sync`, `#more-than-one-distro`; root: the project-setup path in `docs/manifest/design.md` (read from `origin/feature/issue-495`, PR #508, not yet merged).
**Design picture?** No change by this issue itself, but it builds on design text that is not on `main`: PR #508 (issue #495, the layout with `--distro-dirs`, `add-distro`, `layout` and `distros` in `config.yaml`) is open. Four questions are explicitly left to the building of `init` and `sync` (what `init` prints for several distros; a role or group missing from one distro's manifest; `sync`'s exit status when one distro is reported and the others go on; removing a distro). Each must be decided in the plan, and the decision written back into the design in the same change (ADR-0017).
**Dependencies**: Issue #498 part 2 (reading `base`) is not on this branch; #499 `show` is open (init prints what `show` prints, and `show` is the code that reads a manifest from the three location forms); PR #508 (#495) is open and unmerged; #501 `build` follows. #498 part 1 (PR #506) is merged and is on this branch: `resolve`, `validate`, the reader (`yamlload.py`, `manifest.py`, `selection.py`) and the whole-or-nothing output writer (`output.py`).

#### Statements in the issue that are stale, and the true ones

| Issue says | True now |
|---|---|
| Design in `tools/ros-manifest/docs/design.md` (also the "Where this fits" paragraph, with `tools/ros-manifest/docs/spec.md` and `roadmap.md`) | The tool is `tools/repos-manifest/`; the docs are `tools/repos-manifest/docs/{design,spec,roadmap}.md`. |
| "A directory per layer with `src/`; the unnamed first layer's `src/` directly in the system directory" | Correct only for a flat system. With `--distro-dirs` each distro has its own directory holding its layers (or a bare colcon workspace) and its own `setup.bash`; `.repos-manifest/resolved/<distro>/` holds that distro's resolved files. Also in the layout: `setup.bash` and `build/ install/ log/` (these last belong to #501). |
| "A directory per distro. The design follow-up (#495) decides how ... build what that issue settles, and if it is not settled when this starts, raise it at the plan checkpoint." | Settled in PR #508 (open): flat by default; `init --distro-dirs` chosen once at `init` and never changed; a flat system cannot gain a distro; `add-distro <name> [--manifest-ref <ref>]` adds one later. The plan checkpoint question is answered; the remaining dependency is the PR merging. |
| `init <manifest> --role <role> --distro <distro> [--with <group>]...` | Also `--distro-dirs` (one or more `--distro`), `--manifest-ref`, `--manifest-path` for the git form, `--yes`, and `-- <vcs import arguments>`. Without `--distro-dirs`, one `--distro` (none when the manifest has no `distros:`). |
| "creates `.repos-manifest/` with the record of what it was given" | `.repos-manifest/` and `config.yaml` are made in one step (written aside and moved into place); before that nothing exists and `init` can be run again. `config.yaml` records `manifest`, `local_manifest`, `role`, `groups`, `layout` (`flat` / `distro-dirs`) and `distros` (a mapping; an entry may carry `manifest_version`). If the first sync fails or is interrupted, `sync` finishes it. |
| "prints what `show` prints and asks before fetching" | Also prints, for a flat system with a distro, the one `Layout:` line that `--yes` does not skip. What `init` prints for several distros is an open question. |
| Not in scope: "an `init` that can be run again ... They are part of the design follow-up (#495) and come after it." | `init` runs again until the `config.yaml` step, and refuses an already set-up directory, with the Refusals table (14 rows, 8 for `init`, checked in the listed order, fetch-free checks first). That is now part of `init` and needs tests. The lock, time limits, failed-resolve-changes-nothing and commit-named manifest are still not in the tool's design: see Recommendations. |
| `sync`: "update the clone the local manifest is in ... resolve; clone what is missing; update what is there" | Per distro, in the order of `distros`; after step 1 the manifest read is checked against `config.yaml` and a distro it no longer lists (or a flat system whose manifest gained `distros:`) is reported and `sync` goes on with the others, changing nothing of that distro. A distro the manifest lists and the system does not record: nothing happens. `sync --distro <name>` (repeatable) selects distros. |
| "Arguments after `--` passed to `vcs import`" | Passed to the `vcs import` of missing repos only; existing repos are handled one at a time with `git`. |
| "the record of the version and commit last put on each repo, in `.repos-manifest/state.yaml`" | Correct, kept per distro; the inner shape is not fixed, and writing one distro's state must leave every other distro's as it was. A repo with no record is recorded and followed if on the manifest's version, and treated as moved by a person if not. |
| "commits not on `origin` ... put back on top of what was fetched" | Add the failure rule: if they do not go on cleanly the repo is put back as it was and reported. |
| "`local_manifest`: set by `init` when the manifest is a file in a git repo that the manifest lists" | Also a per-distro rule: with `--distro-dirs` it is a path inside each distro's directory, the same path in each; the copy read is the first of local copy then the `manifest` location at the distro's `manifest_version`. |

#### `add-distro`: this issue or its own?
Its own issue. It is a separate command with its own 6-row refusals table, `--manifest-ref` handling and its own read of the manifest (at the ref, not the local copy), and the owner's aim (one machine, ROS Rolling, a directory per distro) does not need it. It does share code with `init` (record a distro, sync one distro), so write `init`'s per-distro sync as a function that takes one distro. State this boundary in the plan. #495 deferred the "removing a distro" question; it stays out of both.

#### Can it be built now?
Yes in part. It can build on what is on this branch: the new reader, `resolve(manifest, role, distro, groups)`, `check_role_and_distro`, and `write_output` (the whole-or-nothing writer that already meets "a failed resolve changes nothing" for the resolved files). It has to wait for: PR #508 merging, so the layout and `config.yaml` shape it writes are the design on `main` (the plan can be written against the PR branch, but the merge should precede the code review); #499 for the "print what `show` prints" step and for reading a manifest from a URL or git repo (the new reader reads a file path only, and the old reader still holds the git/URL code until part 3 of #498); #498 part 2 only when the project11 manifest uses `base` — check this before planning (if the draft manifest has no `base`, no wait). For the owner's case with a local manifest file, #499 and #498 part 2 are avoidable.

Suggested parts:
1. `init` and first `sync`, one distro, flat and with `--distro-dirs`: the system directory, `config.yaml`, refusals, resolve to `.repos-manifest/resolved[/<distro>]/`, clone missing repos with `vcs import`, record `state.yaml`, `local_manifest`. This is the owner's aim.
2. `sync` on a system that already has clones: the update rules (follow, moved branch, dirty, unpushed commits rebased, repo removed from manifest), the manifest-vs-config check, `--distro`, optional repos.
3. `add-distro`.
The risk-bearing part is 2; part 1 only clones, so part 1 can land and be used first. Part 1 still has to write `state.yaml` and clone through a function part 2 reuses.

#### The cloning tool: vcstool or vcs2l
This machine has `/usr/bin/vcs` from the Debian package `python3-vcstool` 0.3.0 (checked: `vcs --version` → `vcs 0.3.0`; `dpkg -l` shows `python3-vcstool 0.3.0-1` and `python3-vcstools 0.1.42-1`). There is no vcs2l in `.venv/bin` and `tools/repos-manifest/pyproject.toml` depends on `PyYAML` only. The design says `vcs`, "from vcs2l", and records its behaviours as tested on vcs2l 1.1.7. The issue should require a `vcs` command on `PATH` that provides `vcs import` with `--input`, `--skip-existing`, `--recursive`, `--shallow` and `--retry` (all present in 0.3.0), accept either vcstool or vcs2l (vcs2l is a maintained fork with the same command line), and not add either as a Python dependency (the design says the tools call `vcs` as a command). Detect it by `shutil.which("vcs")` and a run of `vcs --version` before anything is created (a missing tool is a refusal that changes nothing), and say how to install it. Two real risks: (a) the design's statement that `vcs import` is used only for missing repos was tested on vcs2l; the plan has to test the same two behaviours on vcstool 0.3.0 (it should not be relied on for existing repos at all, so this is mostly moot if `sync` only passes missing repos); (b) `vcs 0.3.0` prints a `pkg_resources` DeprecationWarning on every call, so output must not be parsed from stderr and the failure of one repo must be found from the exit status and a per-repo check, not by reading text. Also: "an optional repo that cannot be fetched is skipped and listed" needs a way to tell which repo failed, since one `vcs import` over a whole `.repos` file only gives a failing exit status; the plan should say how (import the optional repos in a call of their own, or check each path after the call). The design's "What the tools rely on" section should say vcstool is accepted if that is decided.

#### What the workspace asks of the tool (from `docs/manifest/design.md`, "What the tool has to give")
| Ask | Include in #500? |
|---|---|
| A failed resolve changes nothing | Include: `write_output` already replaces the output whole or not at all; `sync` must also say that the manifest is what failed and leave other repos as they were. Add an acceptance test. |
| Protection against two runs at once | Include a minimal lock on `init`/`sync` or a separate issue before the adapter is made thin. It is the most likely to cause real damage because `sync` rebases and moves repos. I recommend a separate small issue that lands before part 2; at minimum, the plan states how part 1 behaves under two runs. |
| Time limits on fetches | Separate issue (a time limit on `vcs import` and each `git fetch`, with `--retry`); not needed for the owner's aim. State "no limit yet" in the issue's Not-in-scope. |
| A manifest named by a commit | Separate issue; the git form takes a branch or tag and the design says so. |
| A status a script can read | Separate; that is #502. |
All five are asked by the workspace for the adapter (#503); none of them is in the tool's design as a section yet, so putting them in #500 would make the issue build undesigned behaviour. The issue's Not-in-scope paragraph should list each by name and link to the issues that hold them, rather than point at #495.

#### Risks to people's clones, against the issue's acceptance criteria
| Promise in the design | Tested by the issue's acceptance list? |
|---|---|
| A repo still on the version with nothing local follows the manifest, and moves to a new version | Yes ("a version change followed"). |
| A repo a person moved to another branch is left alone and reported | Yes, "each left-alone case", but not named: list it. |
| Uncommitted changes: left alone and reported | Same: list it. Also untracked files and a mid-rebase or mid-merge state, which the design does not mention; decide and test. |
| Commits not on `origin` are never switched to another version | Partly: "unpushed commits kept across a `sync`" does not test the manifest changing the version while commits are unpushed. Add it. |
| While on the manifest's branch the unpushed commits are rebased on what was fetched | Not tested as a rebase. Add a test with new upstream commits and local commits. |
| If the rebase does not go on cleanly the repo is put back as it was and reported | No. Add a conflicting-rebase test that checks HEAD, branch, index and working tree are byte-identical afterwards. |
| A repo no longer in the manifest is left on disk and reported; nothing is deleted | Named in the text, no test. Add a test that the directory and its contents survive. |
| A repo with no state record: followed if on the manifest's version, otherwise treated as moved | No. Add (matters when `state.yaml` is lost or after an interrupted first sync). |
| URL of a repo changed: `vcs import` refuses; handled with `git` | No. Add the case (remote URL differs from the manifest's). |
| Step 1 updates the manifest's own clone by the same rules; a developer editing the manifest gets the edited manifest | Partly ("local manifest winning once it exists"). Add a dirty-manifest-clone test. |
| Writing one distro's state leaves the others as they were; a distro the manifest no longer lists is reported with nothing moved, and `sync` goes on | No (the issue predates this). Add, with a two-distro `--distro-dirs` fixture. |
| An optional repo that cannot be fetched is skipped and listed every time; any other repo that cannot be fetched is an error | The first half is tested; the error for a non-optional repo is not. Add. |
| An interrupted `init`: nothing exists, or `sync` finishes it | No. Add: kill after `config.yaml` is written and before the clone; `init` again gives the refusal and `sync` finishes. |
| Refusals change nothing | No. A test per row of the `init` table, each asserting that the directory is unchanged. |
The list "unpushed commits", "moved branch", "dirty" and "removed" are a data-loss class, so the issue should say that each case is tested against real local git repos and that no test accepts a deleted file or reset branch.

#### Acceptance: the by-hand test
Change it to the owner's case: `init --distro-dirs --distro rolling --role developer` from the project11 draft manifest on this machine (ROS Rolling, a directory per distro), a second `sync` changing nothing, and `git status` and `git log` of a repo with a local commit unchanged after a `sync`. Drop the "second machine" wording if it is a different machine. Recording the commands in the PR stays.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | The issue was written before PR #508; its layout, flags and `config.yaml` description are stale (table above). Update the issue's references (new tool path, `--distro-dirs`, `distros`/`layout` in `config.yaml`, the refusals, per-distro `sync`), decide the four open questions in the plan, and write the answers into `tools/repos-manifest/docs/design.md` in the same change (ADR-0017). Remove `init` and `add-distro` from "What is built". |
| Only what's needed | Action needed | Split the issue: `init` + first `sync` for one distro (flat and `--distro-dirs`) first; existing-clone updates second; `add-distro` third (its own issue). The owner's aim needs only the first. |
| A change is only done when its consequences are done | Action needed | Acceptance omits tests for most promises in the "never discard work" list and for the Refusals table (table above); add them. |
| Verify before claiming | Watch | The design's claim on `vcs import` behaviour was tested on vcs2l 1.1.7; this machine has vcstool 0.3.0. The plan has to run the behaviours on the tool in use. |
| Ask about what matters | Watch | Four design questions are left to this work; bring each to the owner at the plan checkpoint with the choices (what `init` prints for several distros; a role or group missing from one distro's manifest; `sync` exit status when one distro is reported and the rest go on; removing a distro, which can stay for a later issue). |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0017 (design kept current) | Yes | Design sections change with the answers to the four open questions and the vcstool decision. |
| ADR-0022 (a part with its own design) | Yes | Work is inside `tools/repos-manifest`; Serves names the root goal and the part's design sections. |
| ADR-0009 (no bare pip install, `.venv`) | Watch | If vcs2l is wanted for tests, install it in `.venv`, not system-wide; the tool itself adds no dependency. |
| ADR-0013 (progress timeline) | Yes | This entry. |

### Consequences

- `tools/repos-manifest/README.md` and the design's "What is built" and "What the tools rely on" sections change.
- `docs/manifest/roadmap.md` and `tools/repos-manifest/docs/roadmap.md` need the split into parts and the new issue for `add-distro`.
- Tests: a local-git-repo fixture for the update rules; a fixture with two distros under `--distro-dirs`.
- `.agent/knowledge/` build/test page, if it lists the tool's runtime requirements (add `vcs`, `git`).

### Recommendations

- Correct the issue text before planning, per the stale-statements table: `tools/repos-manifest` paths; `--distro-dirs`, `--manifest-ref`, `--manifest-path`, `--yes`, `--` and `--distro` on `sync`; `config.yaml` with `layout` and `distros`; the Refusals table; per-distro `sync`; the distro-not-listed reports; `state.yaml` per distro. Do this as a new comment or an edit by the owner; this review does not change the body.
- Split: keep #500 as `init` and the first `sync` for one distro (flat and `--distro-dirs`) with the clone-only path, open a second issue for `sync` against existing clones (the left-alone rules, rebase, per-distro report, optional repos), and a third for `add-distro`. If the owner prefers one PR, order the commits that way.
- Write the plan against PR #508's design now but do not start implementation review until #508 merges; wait for #499 only if `init` must print what `show` prints on the same PR (otherwise print a short summary and replace it when #499 lands, noting it in the plan).
- Check whether the project11 draft manifest uses `base`; if it does, #498 part 2 has to land first.
- Require `vcs` from vcstool or vcs2l found on `PATH`; no Python dependency; check before creating anything; test the behaviours the design relies on on the installed tool; do not parse stderr.
- Make a failed-resolve-changes-nothing check part of the acceptance (it comes with `write_output`); open separate issues for the lock between two runs, time limits on fetches and a manifest named by a commit, and name them in Not-in-scope; the script-readable status is #502.
- Add the missing acceptance tests: one for each row of the risks table above, a per-row test of the `init` Refusals table that asserts nothing changed, an interrupted-`init` test, a two-distro state test.
- Change the by-hand acceptance to `--distro-dirs --distro rolling --role developer` on this machine, and add a check that a repo with a local commit and a dirty file keeps both across `sync`.
- Decide at the plan checkpoint the four questions the design left open, and write the answers into the design in the same change.

### Actions
- [ ] 
- [ ] 
- [ ] 
- [ ] Correct the issue text before planning, per the stale-statements table: `tools/repos-manifest` paths; `--distro-dirs`, `--manifest-ref`, `--manifest-path`, `--yes`, `--` and `--distro` on `sync`; `config.yaml` with `layout` and `distros`; the Refusals table; per-distro `sync`; the distro-not-listed reports; `state.yaml` per distro. Do this as a new comment or an edit by the owner; this review does not change the body.
- [ ] Split: keep #500 as `init` and the first `sync` for one distro (flat and `--distro-dirs`) with the clone-only path, open a second issue for `sync` against existing clones (the left-alone rules, rebase, per-distro report, optional repos), and a third for `add-distro`. If the owner prefers one PR, order the commits that way.
- [ ] Write the plan against PR #508's design now but do not start implementation review until #508 merges; wait for #499 only if `init` must print what `show` prints on the same PR (otherwise print a short summary and replace it when #499 lands, noting it in the plan).
- [ ] Check whether the project11 draft manifest uses `base`; if it does, #498 part 2 has to land first.
- [ ] Require `vcs` from vcstool or vcs2l found on `PATH`; no Python dependency; check before creating anything; test the behaviours the design relies on on the installed tool; do not parse stderr.
- [ ] Make a failed-resolve-changes-nothing check part of the acceptance (it comes with `write_output`); open separate issues for the lock between two runs, time limits on fetches and a manifest named by a commit, and name them in Not-in-scope; the script-readable status is #502.
- [ ] Add the missing acceptance tests: one for each row of the risks table above, a per-row test of the `init` Refusals table that asserts nothing changed, an interrupted-`init` test, a two-distro state test.
- [ ] Change the by-hand acceptance to `--distro-dirs --distro rolling --role developer` on this machine, and add a check that a repo with a local commit and a dirty file keeps both across `sync`.
- [ ] Decide at the plan checkpoint the four questions the design left open, and write the answers into the design in the same change.

## Checkpoint
**When**: 2026-11-18 16:11 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review's actions correct stale text and order the work; none narrows what the owner asked for. He started this drive on 2026-11-18: "do 1 and 2", then "Merge and carry on")
**After**: issue-actions
**Decision**: proceed

Proceed to planning, with these instructions for the plan.

What the owner wants first, in his words: "test the tool to build the project directory tree" for his project on this machine, on ROS Rolling. So the plan is in parts, one pull request each, and the first is the smallest thing that does that.

- Part 1: init and the first sync, clone only. One distro flat, and one or more with --distro-dirs. It writes .repos-manifest/ with config.yaml in one step, resolves with the reader and output writer that part 1 of issue 498 put on main, clones each layer's repos with vcs import, writes the resolved files and state, and gives setup.bash where the design says so. Every init refusal in the design's table is built and tested. A sync on a system whose repos all exist reports and changes nothing in this part.
- Part 2: sync against clones that exist: following a version change, the rules for leaving a repo alone, rebasing unpushed commits, a repo removed from the manifest, per-distro reports, optional repos. This is where a person's work is at risk, so it has its own pull request and the tests the review lists.
- add-distro is not in this issue. The host will propose a separate issue to the owner. Part 1's per-distro sync is one function that takes a distro, so add-distro can reuse it.
- The design basis is pull request 508 (issue 495), branch origin/feature/issue-495, not yet merged: plan against it and say what changes if it changes. The issue's own text is stale where the review says so; the review's corrections stand in for it.
- The manifest location in part 1 is a local file path only. The owner's draft manifest uses no base and can be given as a file. The git form and URL form of a location, and base, come with part 2 of issue 498, which adds the fetching; the plan says how init takes them up once that lands, without building a second fetcher here.
- vcs: the tool calls a vcs command found on PATH, from vcstool or vcs2l, and refuses before creating anything when there is none. This machine has vcstool 0.3.0: the plan re-tests on it every vcs import behaviour the design relies on, and the tool never parses vcs's stderr.
- The four questions the design leaves to this issue (what init prints for several distros; a role or group missing from one distro's manifest; sync's exit status when one distro is reported and the others go on; removing a distro) and the two the review found uncovered (untracked files; a repo in the middle of a rebase) are answered in the plan where they are mechanism, and listed for the owner with a recommendation where they change what a person's clone ends up as.
- Of the things the workspace asks of the tool, this issue includes only "a failed resolve changes nothing", with its test. The lock, fetch time limits and a manifest named by a commit stay out and are named as out of scope.
- The design documents are updated in the same change as the code (ADR-0017), and "What is built" says what is.
- Lessons from the resolver's part 1, to plan for from the start: state each rule once and structurally; documents say exactly what the code does; tests use local git repositories, never the network; no test patches an os function reached through pathlib; nothing needs a Python newer than 3.10; do not harden against inputs nobody writes.

## Plan Authored
**Status**: complete
**When**: 2026-11-18 16:18 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-500/plan.md` at `584c1514`

Two pull requests: part 1 is `init` and a `sync` that only clones what is missing (one `vcs import` call per missing repo, success by exit status, debris of a failed clone removed, `state.yaml` per distro keyed by repo key with layer, version and commit, placeholder `setup.bash`, every `init` refusal with a nothing-changed test); part 2 is `sync` against existing clones, one rule and one test per row. Four owner questions: untracked files, the stub `setup.bash`, a changed repo url, and a CI change to install `vcs`.

## Plan Review
**Status**: complete
**When**: 2026-11-18 16:23 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #500 — repos-manifest: `init` and `sync` set up and update a system directory
**Plan**: `.agent/work-plans/issue-500/plan.md` at `584c1514`
**Branch**: `feature/issue-500`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | Part 1 as planned is about 1,700 lines (650 code, 900 tests, 150 docs) in eight new modules (the plan says "seven" in one place and "nine" in another). It can be one pull request after the cuts in findings 6 and 7. The split into parts and keeping `add-distro` out are right. |
| Issue alignment | Needs work | It follows the review's corrections and the checkpoint. Two things the design says `init` and `sync` do are missing (finding 2), and two refusal messages point at a command that does not exist (finding 4). Serves: "one system directory set up and kept in line from one manifest", under `tools/repos-manifest/docs/design.md#the-system-directory`, `#setting-up-with-init`, `#refusals`, `#sync`. These anchors are in 508's text (checked on `origin/feature/issue-495`); 508 is still OPEN as of this review. |
| File targeting | Good | All the right files are named: README, both roadmaps, `build_and_test.md`, the design and the tests. Finding 9 removes the CI file from the list. |
| Consequences | Good | `test_output.py` and the resolve signal tests are covered. Finding 3 removes the `write_output(marker_text=)` change and the test it would need. |
| Principle alignment | Needs work | "Never discard work": the debris rule can remove another run's clone (finding 1). "Only what's needed": the module split, the vcs behaviour tests for existing repos, and `--local-manifest` are more than part 1 needs. "Keep one current design": handled; the design is edited in the same change. |
| ADR compliance | Good | ADR-0017, 0022, 0009 and 0013 are handled. On the by-hand venv see finding 10. |
| ROS conventions | N/A | Workspace tool. |

### What vcstool 0.3.0 does (tried on local repositories in the scratchpad)

- One call per layer with four repos: a good branch, a url that is not a repository, a version that does not exist, and a nested key at a tag. The call exits 1. The bad url leaves an empty directory. The bad version leaves a complete clone on `main`. The good repos are cloned correctly. This confirms what the planner found.
- `--skip-existing` over those leftovers exits 0. A plain second call exits 1, switches nothing and leaves the leftovers in place.
- `git -C <empty dir> rev-parse --verify -q HEAD` exits 0 when the system directory is inside a git repository that has a commit. Git finds the parent repository. So the plan's "not a complete clone" check misses an empty leftover directory in that case.
- Cloning into a fresh temporary directory, then `mv` of `<tmp>/grp/c` to `src/grp/c`, gives a working clone. This was tried with `--shallow` and a nested key; HEAD is detached at the tag and the clone is shallow.
- Cost: four repos took 0.84 s as four separate calls and 0.21 s as one call. That is about 0.2 s of start-up per call, so about 10 s for 50 repos, which is small next to the network clones themselves. What one call per repo really loses is the parallel clones: vcstool runs one worker per CPU and drops to one worker by itself when an ssh host key is unknown.
- vcstool runs `git ls-remote` with `GIT_TERMINAL_PROMPT=0`. A private https repo with no credential helper therefore fails instead of asking. ssh prompts go to the tty. All 18 of the owner's urls for `simulator`/`rolling` are public `https://github.com/` urls, so neither affects his test.
- An unknown flag exits 2 and creates nothing.

### Findings

1. **[Principle: never discard work] High.** The debris rule ("remove the path if it did not exist before the call") can remove a clone the tool did not create. Two runs at once (the plan accepts that there is no lock): both see the path missing; run A clones it; run B's `vcs import` fails because the path exists; B's `finally` then removes A's clone, possibly while A is still cloning. The fix is structural and removes rules instead of adding them. Clone each missing repo into a fresh `tempfile.mkdtemp` directory under the layer's `src/` (hidden, for example `.repos-manifest-clone-XXXX`). On exit status 0, rename `<tmp>/<key>` to its place, making the parent directories first; `os.rename` refuses a target that is not empty. Always remove the temporary directory. Then:
   - only a directory made by `mkdtemp` is ever removed;
   - a path that exists is always a complete clone or something a person put there;
   - the "not a complete clone" listing and its wrong `rev-parse` check (above) can go;
   - the SIGKILL row of the interruption table shrinks to "a hidden temporary directory is left", which the next `sync` can remove by the dead-pid rule `output.py` already has, or simply ignore.
2. **[Issue alignment] Medium. The check on the real destination is missing.** spec.md ("Reading a manifest before using it") and design.md (`resolve`: "The check on the real destination ... is made by `init` and `sync`, which clone the repos there") require it: a link already on the disk, or two names the disk treats as one, must not send a repo outside its place. Before the rename, check that the target's parent, with links resolved (`os.path.realpath`), is the layer `src/` joined with the key's parent. The refused rename covers the collision case. Add a test with a symbolic link inside `src/`. Otherwise list it as cut, but the design says the commands that clone make this check.
3. **[Principle: only what's needed] Medium. Do not create `.repos-manifest/` with `write_output`.** `write_output` puts its `.repos-manifest-output` marker in the directory, and that marker is what lets `write_output` replace the directory. `.repos-manifest/` would then carry a marker saying it may be replaced whole, `config.yaml` and `state.yaml` included. The plan already needs a new `marker_text` keyword to make that marker's words true. The design asks for "written aside and moved into place": `mkdtemp` beside it, write `config.yaml`, `os.rename`. That is about 6 lines, needs no marker and no change to `output.py`. A killed run leaves a hidden temporary directory that a second `init` does not look at.
4. **[Issue alignment] Medium. Refusals 1 and 7 must not name `add-distro` while it is not built.** As planned, the messages give `add-distro <name>` as the next step. That command does not exist until its own issue lands, so the next step fails. Until then, row 1 says `sync`, and row 7 says to set up with the distros the manifest lists, or to add the distro to its `distros:`. The design's table then gets a sentence that the `add-distro` step is given once it is built. This is the same treatment the plan already gives `--manifest-ref`.
5. **[Approach: `vcs import`] Recommendation.** Keep one call per missing repo, with success judged by its exit status, and add the temporary-directory change from finding 1.
   - Why not one call per layer: a layer call's exit status says nothing per repo. To learn which repos failed, the tool would have to check each repo afterwards: is the clone's top level the path itself (not a parent repository), and is HEAD at the version (a branch vs. a tag or commit, and vcstool's `heads/` and `tags/` prefixes). That is a second set of rules, and part 2 has to own them anyway. A layer call into a temporary directory could fall back to one call per repo after a failure, but that is two code paths.
   - Which matches the design: the design's wording ("Missing repos are cloned with `vcs import`"; "bring the layer's `src/` in line with its `.repos` file") allows either.
   - Which is more robust on 0.3.0: one call per repo, because the result is the exit status only.
   - The cost is serial clones. That is fine for the owner's 18 repos and acceptable at 50. Parallel clones can come later if wanted.
   - Prompts: with one call per repo, an ssh key without an agent asks for its passphrase about twice per repo (`ls-remote`, then `clone`). The owner uses `ssh-add`, so this does not apply to him. Say it in the README.
6. **[Scope] Medium. What to cut from part 1.**
   - Cut (a), `--local-manifest` and the local-copy read. The owner's manifest is a scratch file in no repo, and the design has `init` set `local_manifest` itself only for the git form, which comes with 498 part 2. `locations.py` then becomes a one-line `load_manifest` call and can go.
   - Cut (c), the `--` pass-through. The owner's test does not need it, and `argparse.REMAINDER` after a subcommand is fiddly. It can come back with part 2.
   - Cut (d), the "not a complete clone" listing. It is wrong as written (above) and not needed after finding 1.
   - Keep (b), `setup.bash` (see the open questions).
   - Shrink `test_vcs_behaviours.py` to what part 1's code relies on: exit 0 means the repo is cloned at its version; a nested key; one failing repo gives a non-zero exit. The existing-repo cases justify part 2's design and belong in part 2. The debris cases stop mattering after finding 1.
7. **[Scope] Low to medium. Module split.** Eight new modules is more structure than about 500 lines need.
   - `config.py`, `layout.py` and `state.py` could be one `system.py`: finding the system, `config.yaml`, paths, `distros_for`, `state.yaml`. That is under 250 lines.
   - The vcs and git calls in `tools.py` (three small functions) could live in `sync.py`.
   - That gives `signals.py`, `system.py`, `sync.py` and `init.py`.
   - Keeping the pure path functions separate for testing is fine. That does not need its own module.
   - The name `layout.py` also clashes with the existing `--layout` option and `test_layout.py`, which mean something else.
8. **[Approach] Low. Errors on disk.** `cli.main`'s catch-all prints only `internal error (PermissionError)` for an `OSError`, for example a read-only directory or a full disk while making directories or renaming. For `init` and `sync`, an `OSError` should be reported with the path and `strerror`. Say in which function, and add one test (for example a layer `src/` that cannot be written; skip it when running as root, as `test_output.py` does).
9. **[Consequences / CI] Medium. Without `vcs`, the clone tests should fail, not skip.** This tool's main job is to clone. If the clone tests are skipped in CI, every later change to `init` and `sync` merges with its main path untested, and the skip is easy to miss. Instead, add `vcs2l` to the `test` extra in `pyproject.toml`. vcs2l 1.1.7 is on PyPI. The CI job already runs `pip install -e tools/repos-manifest[test]`, so `validate.yml` does not change and no CI change is needed, though the owner should still hear of it. Then make the tests require `vcs`: a conftest check that fails with "install vcs2l or vcstool" when `vcs` is missing. This drops the plan's `needs_vcs` skip and open question 4.
10. **[By-hand commands] Low. They work on this machine, with three fixes.** Checked: the draft file exists and has no `base`; it resolves for `--role simulator --distro rolling` to 18 repos in the six layers named (underlay 5, core 6, platforms 3, sensors 1, simulation 1, ui 2), all public https; `python3 -m venv` works (Python 3.14); `~/p11-venv` and `~/p11-test` do not exist yet.
    - `pip install -e` points the venv at this worktree, which is deleted when the pull request merges. Install without `-e`, or from the main checkout after the merge.
    - `echo dirty >> README.md` makes an untracked file when the chosen repo has no `README.md`. Modify a file the repo tracks, for example the first file `git ls-files` lists.
    - The check compares `git log` but not `git status`. Save both before the `sync` and diff both after. `<repo>` has to be filled in by hand; say so.
    - `source rolling/setup.bash` returns 1 by design.
11. **[Tests] Low. Coverage.**
    - Every refusal row has a test. So do the interruption points (after the config step, during a clone, and the SIGKILL state built by hand). So does the failed resolve, in `test_sync_first.py` (a missing role, then a file that does not parse, with the snapshot equal).
    - Not covered in tests: the owner's own shape, `--distro-dirs --distro rolling --role simulator` with six layers. Add one test from `tests/fixtures/p11/manifest.yaml` with every `url` rewritten to a local remote. It proves the six-layer tree without the network.
    - Add one test where two distros are synced in one run and the run is stopped during the second distro: the first distro's state is complete and the second's holds what it finished.
    - No `os` patching, local remotes, and Python 3.10 limits: the plan states each, and they hold.
12. **[Approach] Low. `state.yaml`.** Isolation between distros is real within one run. Each distro's write reads the whole file, replaces one entry and swaps the file in with `os.replace`. A stop between two distros leaves the first distro's entry complete. Two processes at once can lose an update, which falls under the lock that is out of scope; the design text should say so next to the "Two runs at once" sentence. `layer` in each record exists only for a part 2 rule. It costs little, so it can stay.
13. **[Approach] Low.** `init` step 3 calls `check_role_and_distro` and step 4 calls `resolve`, which calls it again. Once is enough: `resolve` alone, with its errors standing.

### Open questions and mechanism items

- **Q1, untracked files; Q3, a changed `url`.** Both are owner questions, since they change what a clone ends up as. Both are part 2 questions, so ask them in part 2's plan, where the owner sees them with the rules around them. Recommendations as the plan gives (a) for both. For Q3, one condition: only for a repo that otherwise follows (on its recorded version, clean), and always reported.
- **Q2, `setup.bash`.** This is not an owner question; the design already answers it. The Refusals row says `init` refuses "a file it writes such as `setup.bash`", and the system directory section says `setup.bash` "sources the layers that are built", which right after `init` is none. So `init` writes it. A file that prints "nothing is built here yet" on stderr and returns 1 is better for a person than "No such file": it says what is going on, and the non-zero status stops a script that sources it before any build. Keep it, and do not cut (b). Its text should not tell the person to run `repos-manifest build` while issue 501 has not landed.
- **Q4, CI.** See finding 9. With the test extra this is not a workflow change.
- **Mechanism items.** The summary for several distros, the `sync` exit status, a role or group the manifest lacks (reported per distro), and a repo mid-rebase left alone are all fine as mechanism. One is not: "a layer change of an already cloned repo: left where it is, reported". That decides where a person's clone lives, and with it what `build` finds, since `build` gets the resolved layer's paths. It belongs to the owner. Ask it in part 2's plan, next to Q1 and Q3.

### Dependencies

Part 1 depends on 508 for the `config.yaml` keys (`layout`, `distros`), the Refusals table and the anchors; the plan says this, and 508 is OPEN at this review. It does not quietly depend on 498 part 2. Manifests are read only through `load_manifest` on a path, which refuses `base`, and the owner's draft has no `base` (checked). One quiet interaction: the existing `resolve` command, run inside a system directory, still needs `--manifest` and `--out` and does not write to `.repos-manifest/resolved/`. The plan keeps it unchanged, which is right, but the design's "What is built" has to say so.

### Summary

The split, the refusal order, the two-phase resolve-then-apply and the interruption analysis are sound, and the vcstool findings hold when re-run. Before implementation, the clone step needs one structural change: a temporary directory and a rename. That makes deletion provably limited to the tool's own temporary directory and removes three rules (debris removal, the incomplete-clone listing, its SIGKILL case). The plan also needs the destination check the spec requires, `.repos-manifest/` made without the output marker, and refusal messages that do not point at `add-distro`. Make the cuts and merge the modules so the first pull request is the smallest thing that builds the owner's tree.

### Recommended Actions

- [ ] Clone each missing repo into a `mkdtemp` directory and rename it into place; remove only that temporary directory; drop the "remove a path that did not exist before the call" rule and the "not a complete clone" listing (findings 1 and 5).
- [ ] Add the real-destination check before the rename (no link in the target's parent path; refuse an existing target), with a test (finding 2).
- [ ] Make `.repos-manifest/` with `mkdtemp` and `os.rename`, not `write_output`; drop `write_output(marker_text=)` (finding 3).
- [ ] Refusals 1 and 7: no `add-distro` in the message until it is built; say so in the design's table (finding 4).
- [ ] Cut `--local-manifest` and the local-copy read, the `--` pass-through, and the incomplete-clone listing from part 1; keep the stub `setup.bash`; shrink `test_vcs_behaviours.py` to what part 1 relies on (finding 6).
- [ ] Merge `config.py`, `layout.py`, `state.py` and `locations.py` into one module, and `tools.py` into `sync.py`; fix the module count (finding 7).
- [ ] Report an `OSError` in `init` and `sync` with its path and reason, with a test (finding 8).
- [ ] Add `vcs2l` to the `test` extra; make a missing `vcs` fail the tests instead of skipping them; drop open question 4 (finding 9).
- [ ] Fix the by-hand commands: no `-e` into the worktree, a tracked file for "dirty", and compare `git status` too (finding 10).
- [ ] Add the six-layer owner-shape test from `fixtures/p11` with local remotes, and a two-distro stop test (finding 11).
- [ ] Move Q1, Q3 and the layer-change question to part 2's plan as owner questions; answer Q2 from the design (finding on open questions).

## Checkpoint
**When**: 2026-11-18 16:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the Plan Review's verdict is needs-work; its findings are mechanism and make part 1 smaller)
**After**: plan
**Decision**: revise

Revise the plan with every finding of the Plan Review. Host decisions where it left a choice (owner may veto):

- Cloning (finding 1): each missing repo is cloned into a temporary directory made beside its destination, under the layer's src/, and renamed into place when vcs import exits 0; on any failure only that temporary directory is removed. The tool never removes a path it did not make in that same call. One call per missing repo, success by exit status. The "not a complete clone" listing goes.
- The destination check (finding 2) is in part 1, as the spec says: the real path of the destination's parent stays inside the layer's src/, and an existing destination is never written into.
- .repos-manifest/ is made with a temporary directory and one rename, not with the output writer; output.py is not changed for it (finding 3).
- Messages do not name a command that is not built: no add-distro, no build (findings 4 and the stub's text).
- vcs for the tests: vcs2l goes in the package's test extra, so the clone tests run in CI as it is and fail, not skip, when vcs is missing. No change under .github/. The tool itself still accepts vcs from vcstool or vcs2l on PATH and has no new runtime dependency.
- Modules (finding 7): signals.py, system.py (config, paths, state, reading the manifest from its location), sync.py, init.py. No layout.py.
- Cut from part 1: --local-manifest and the local-copy read; the -- pass-through of vcs import arguments; the "not a complete clone" listing; the vcs behaviour tests that part 1 does not rely on. Each is listed in the plan as moved to part 2 or to its own later step, not dropped from the issue.
- Kept in part 1: setup.bash, a file that says nothing is built yet and returns a failure when sourced, as the design's refusals table implies init writes it.
- Findings 8 to 11 as stated: an OSError reported with its path and reason; a test in the owner's own shape (six layers, --distro-dirs, one distro, a role) from the existing fixture with local remotes; a two-distro sync stopped during the second; state.yaml's no-lock note; resolve called once.
- The by-hand commands: install from the main checkout after the merge, not from the worktree; make the dirty file from one the repo tracks; compare git status as well as git log.
- Questions moved to part 2's own plan checkpoint, for the owner then: untracked files when sync updates a repo; a repo whose url changed in the manifest; a cloned repo whose layer changed.
- No question remains for the owner on part 1.

## Plan Authored
**Status**: complete
**When**: 2026-11-18 16:29 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-500/plan.md` at `9afc4552`

Revision after the plan review and its checkpoint. Part 1 is `init` and a clone-only first `sync` in four modules (signals, system, sync, init): each missing repo is cloned by `vcs import` into a temporary directory under the layer's `src/` and renamed into place on exit status 0, with the destination check, `.repos-manifest/` made aside and renamed, vcs2l in the test extra, and no change to `output.py` or `.github/`. Cut items are listed as moved to part 2; no open question remains for part 1.

## Plan Review
**Status**: complete
**When**: 2026-11-18 16:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #500 — repos-manifest: `init` and `sync` set up and update a system directory
**Plan**: `.agent/work-plans/issue-500/plan.md` at `9afc4552`
**Branch**: `feature/issue-500`

Second review, of the revised plan. Design read from `origin/feature/issue-495` at `657302b7` (pull request 508, still OPEN at this review); `spec.md`, `output.py` and `cli.py` from this branch.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | About 480 lines of code in four modules, one pull request. Each cut is listed with where it went. One more cut is possible (state.yaml, below) but the first checkpoint put state in part 1, so it is the host's call, not a finding. |
| Issue alignment | Good | Every finding of the first review is answered (table below). Serves: "one system directory set up and kept in line from one manifest", under `tools/repos-manifest/docs/design.md#the-system-directory`, `#setting-up-with-init`, `#refusals`, `#sync`, and root `docs/manifest/design.md` ("What the tool has to give"). The anchors exist in 508's text. |
| File targeting | Good | All the right files are listed, and `output.py` and `.github/` are left alone. |
| Consequences | Good | README, both roadmaps, `build_and_test.md`, the design and `pyproject.toml` are covered. |
| Principle alignment | Needs work (small) | "State a rule once": the sweep is run in four kinds of place and the destination check is written as two equalities. Both shrink if the temporary directory moves (findings 1 and 2). "Verify before claiming": two claims are wrong in their reasoning (findings 4 and 7). |
| ADR compliance | Good | ADR-0017, 0022, 0009 and 0013 are handled. |
| ROS conventions | N/A | Workspace tool. Checked anyway: colcon and rosdep skip hidden directories (finding 1). |

### The first review's findings

| # | Finding | Answered? |
|---|---|---|
| 1 | Temporary directory and rename; drop the debris rule and the incomplete-clone listing | Yes ("Cloning one missing repo", steps 1 to 7) |
| 2 | Check on the real destination | Yes, with one wrong claim (finding 4) |
| 3 | `.repos-manifest/` made with `mkdtemp` and one rename, not `write_output` | Yes (init step 8) |
| 4 | No `add-distro` in refusals 1 and 7 | Yes. Also `--manifest-ref` in row 6, with a sentence for the design's table |
| 5 | Cut `--local-manifest`, `--`, the listing; keep `setup.bash`; shrink the vcs tests | Yes ("Cut from part 1") |
| 6 | Merge modules | Yes: signals, system, sync, init |
| 7 | `OSError` reported with path and reason, with a test | Yes (`reporting_oserror`, the mode `0o500` test) |
| 8 | vcs2l in the test extra; fail, not skip | Yes, but the PATH fixture keeps vcstool from being tested here (finding 3) |
| 9 | By-hand commands: no `-e`, a tracked file, compare `git status` | Yes |
| 10 | Owner-shape test; two-distro stop test | Yes. The plan rightly uses `fixtures/project11` (the new format, developer role, seven layers); the first review's `fixtures/p11` is the earlier format |
| 11 | Q1, Q3 and layer change moved to part 2; Q2 answered from the design | Yes |

Also answered: the state.yaml no-lock note and resolve called once.

### What vcstool 0.3.0 does here (local repositories in the scratchpad, no network)

Each try ran `vcs import T` with a one-repo text on stdin, `T` made by `mktemp -d` in `src/`, then `mv T/K src/K`.

- A plain key on `main`, a nested key `grp/sub/b` on branch `dev`, a tag `v1`, and no version all exit 0. The clone is at `T/<key>`, and for the nested key `T/grp/sub` is made inside `T`. After the rename, `git status` is clean, it is on the branch or detached at the tag, and `origin` is the url given. `rev-parse --show-toplevel` is the new place. A git repository survives the rename because its `.git` holds no absolute paths. Submodule gitdirs are relative too.
- A url that is not a repository exits 1 and leaves `T/bad` empty. A missing version exits 1 and leaves a full clone on `main` at `T/badv`. Both are inside `T` only, so removing `T` cleans them up. `T/grp/sub` stays in `T` after the nested rename, as the plan says.
- Killing `vcs` does not kill its `git clone`. vcstool runs git as a child of its own. When the Python process ends with an exception, `subprocess.run` kills `vcs` only. The `git clone` was then orphaned (parent pid 1) and went on running in `T/<key>` (tried with a slow `git` wrapper and a SIGTERM delivered to the Python process only). A Ctrl-C at a terminal reaches the whole process group, so git stops in that case. A SIGTERM to the tool alone, or a `timeout`, leaves git writing into `T` while `finally` removes it. See finding 5.
- colcon does not look in hidden directories: `colcon_recursive_crawl` 0.2.3 drops directory names that start with `.`. A `src/.repos-manifest-tmp-123-abcdefgh/pkg_a` beside `src/pkg_a` was not visited. catkin_pkg's `find_package_paths` (used by rosdep) also skips hidden directories. vcstool's own `find_repositories` (`vcs status src`, `vcs pull src`) does not skip them, so a killed run's `T` with a complete clone shows up there as an extra repo.

### vcs2l 1.1.7's command line (wheel downloaded to the scratchpad, read, not installed or run)

- `vcs import` has the same arguments as vcstool 0.3.0: `--input` with default `-` (stdin), and the positional path with `nargs='?'` ("Base path to clone repositories to"). `--force`, `--shallow`, `--recursive`, `--retry` and `--skip-existing` are the same. Its exit status is `1 if any_error else 0`, as in vcstool. The git client's `import_` differs only in passing `--retry` through. vcs2l also skips a repo whose entry is empty, which a one-repo text never has.
- The plan's reason for Python 3.14 is wrong, though its conclusion holds. `vcs2l/commands/vcs.py` imports `vcs2l.commands.help` at the top, so every `vcs` call loads it, `vcs import` and `vcs --version` included. Its `pkg_resources` import is under a version guard and is used only on Python 3.5 and 3.6. From 3.8 on it uses `importlib.metadata`. No other removed module is imported.
- The wheel also installs a top-level `vcstool` package, a deprecated shim that re-exports vcs2l. It is harmless in a venv.
- Running the extracted vcs2l on this machine's Python 3.14 was denied by the permission system, so vcs2l's behaviour is checked by reading its source only. CI's first run is still the first execution, as the plan says.

### Findings

1. **[Approach] Medium. Put the clone's temporary directory in `.repos-manifest/`, not in the layer's `src/`.** Either place is on the same filesystem as the destination in practice, so the rename stays atomic. Inside `.repos-manifest/` is better:
   - A killed run leaves nothing under any `src/`, so `vcs status src` and anything else that crawls `src/` never sees a half-made repo.
   - Every temporary this tool makes after `init` is in one directory. That includes `replace_file`'s temporary files: `os.replace` from `.repos-manifest/` to `setup.bash` or `state.yaml` is atomic on one filesystem. So the sweep has one place: `.repos-manifest/`, swept once at the start of a `sync` or of `init`'s step 9. `init` keeps its own sweep of the system directory for its step 8 temporary.
   - This replaces the list "`.repos-manifest/`, the distro's directory, each layer's `src/`, per distro". Sweeping once, before the run makes anything there, also makes the own-process rule of `_process_has_ended` safe by construction. With a sweep per distro it is safe only because of how the steps happen to be ordered.
   - A destination on another filesystem (a person's mount point under the system directory) then gives `EXDEV`. That is reported by the `OSError` rule, and `T` is removed. No more is needed.
   - Keep the hidden prefix anyway.
2. **[State a rule once] Low. The destination check is one equality.** `realpath(parent of P) == join(realpath(system_dir), *parts, *key_dirs)` already fails when `S` or any directory on the way is a link. The plan's first equality (on `S`) is implied by it. Write it once. The tests listed (`src/grp` a link, the layer directory a link, a link inside `src/`, each destination type for `lexists`) are enough.
3. **[Tests] Medium. As planned, vcstool 0.3.0 is never tested automatically.** The session fixture puts the directory of `sys.executable` *first* on `PATH`. With the extra installed in `.venv` on this machine, `.venv/bin/vcs` (vcs2l) then shadows `/usr/bin/vcs` (vcstool), and CI also has vcs2l only. The checkpoint asks for the behaviours to be re-tested on vcstool 0.3.0.
   - Fix: *append* that directory to `PATH` instead. A `vcs` already on `PATH` wins, and the venv's is the fallback. This machine then tests vcstool and CI tests vcs2l.
   - Add a `pytest_report_header` that prints `vcs --version` and its path, so every run says which `vcs` it tested.
   - The three `test_vcs_behaviours.py` tests (exit 0 and the place, nested key, failing url) are what part 1 relies on. Add a missing version giving a non-zero exit: vcstool leaves a full clone on the wrong branch in that case, and part 1 depends on exit 1 for it.
4. **[Verify before claiming] Low. Correct two claims.**
   - (a) The vcs2l paragraph: `help.py` is loaded by every `vcs` call, and its `pkg_resources` import is dead code below 3.7. The conclusion stands.
   - (b) "Two names the disk treats as one cannot both pass". `realpath` does not fold case. On a case-insensitive disk, keys `A` and `a/b` both pass the check, and `a/b` is cloned inside repo `A`. Keys `A` and `a` give "present" for the second without an error. The reader refuses layer names that differ only in case, but not keys. The owner is on ext4, so do not build anything for this. Say in the plan and in the design's "What is built" that case-folding disks are not checked in part 1, rather than claiming it.
5. **[Approach] Low. Do not claim "`T` is not removed under a running clone".** It does not hold for a signal sent to the tool alone (tried, above). The cheap, true rule:
   - Run `vcs` with `start_new_session=True` and send `os.killpg` to its group on an exception before `T` is removed. This is a `Popen` and about six lines.
   - Or keep `subprocess.run`, make the `finally` removal of `T` a warning when it fails rather than an exception (which would also replace `Stopped` and lose the 128+n exit), and let the next sweep take it.
   - Either way, the plan says which.
6. **[Approach] Low. Progress.** Output of `vcs` is captured, and the result is printed only after each distro. With 18 network clones the person sees nothing for minutes. Print one line per repo as its clone starts (`cloning core/src/<key>`). That is one `print`.
7. **[Tests] Low. Git config in tests.** `GIT_AUTHOR_*`/`GIT_COMMITTER_*` do not stop git from reading the global and system config, despite what the plan says. Set `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1` in the same fixture, so that a person's `commit.gpgsign`, hooks path or url rewrite cannot break or change the tests. This machine has only `user.name` and `user.email`, but a contributor's may not.
8. **[Approach] Low. Loose ends, one line each in the plan.**
   - `init` step 8 sets `chmod 0o755`, but `output.py` uses `0o777 & ~umask`. Use the umask, one rule.
   - Say that `sync` calls `require_tools()` before phase two.
   - A rename refused because the target is not empty (two runs at once) is that repo's error, and the others go on, like "appeared meanwhile". It should not end the run through the `OSError` rule. As written, the plan says both.
   - The owner-shape test makes 44 remotes. Build one remote per distinct version and point the urls at those, or build them once per session. Otherwise that one test costs about 10 seconds of remote-making on top of about 9 seconds of `vcs` calls.

### Sweep, destination check, `.repos-manifest/` aside

- **Sweep.** It can remove only an entry whose whole name is `.repos-manifest-tmp-<digits>-<8 of [a-z0-9_]>` (Python's `mkdtemp` alphabet, checked), that is not a link, and whose process has ended. Nothing a person names that way is likely. It is a different rule from `output.py`'s sweep, which also needs the marker or an empty directory, and reuses only `_process_has_ended`, by import. That is not a second copy. Import `output._make_writable` the same way rather than writing "as output.py does" again. The two patterns cannot match each other's names (`.new-`/`.old-` against `-tmp-`).
- **Destination check.** It is the spec's rule ("Reading a manifest before using it": the check on the real destination), apart from finding 4b.
- **`.repos-manifest/` aside.** The aside is `mkdtemp` in the system directory: the same directory, so the same filesystem. Its name is not `.repos-manifest`, so `find_system` never takes a half-made one for a system. A leftover from a killed step 8 leaves no `.repos-manifest`, so `init` runs again and sweeps it. `sync` finds no system and says `init`. A rename onto a `.repos-manifest` that another `init` made in the meantime fails `ENOTEMPTY`, because it holds `config.yaml`, and is reported.

### Refusal messages and the design's table

The plan's edits keep the table true: row 1 gives `sync`, rows 6 and 7 give "add the distro to its `distros:`" (always true in part 1, since no manifest is in the git form yet), a sentence under the table says the `add-distro` and `--manifest-ref` steps come once they are built, and a new row covers `vcs`/`git`. The one helper that checks every refusal's text for unbuilt command names is the right structural check.

### 508

Nothing in the code depends on 508's text, only the design edits do. Implementation can start now. The plan's route is sound: merge `origin/main` into `feature/issue-500` after 508 merges, and make the design edits on top as the last commit of the part. 508 does not touch `spec.md`, and the roadmap it changes is merged before the plan's roadmap edit.

### Optional further cut (host's call)

`state.yaml` could move to part 2 without making part 1 wrong. Part 2's no-record rule ("followed if on the manifest's version") already covers repos cloned before any state exists. Moving it would drop `read_state`/`put_distro_state`, the state assertions and the state half of the two-distro stop test, about 40 lines of code and 60 of tests. The first checkpoint put "writes the resolved files and state" in part 1, so this is not a finding.

### Summary

The revision answers every finding, and part 1 is now the right size and shape. The clone steps work as the plan says on vcstool 0.3.0, and vcs2l 1.1.7's command line is the same. None of the findings blocks implementation: each is a sentence or a few lines, and can be taken in the implementation without another plan round. The ones worth doing are moving `T` into `.repos-manifest/` with a single sweep (finding 1) and appending, not prepending, the venv to `PATH` so vcstool is really tested here (finding 3).

### Recommended Actions

- [ ] Make `T` (and `replace_file`'s temporary) in `.repos-manifest/`; sweep `.repos-manifest/` once per run; `init` keeps its system-directory sweep for step 8 (finding 1).
- [ ] State the destination check as one equality (finding 2).
- [ ] Append, not prepend, the venv's directory to `PATH`; print the `vcs` tested in the report header; add the missing-version test (finding 3).
- [ ] Correct the vcs2l/`pkg_resources` reasoning and the case-folding claim; list case-folding disks as not checked (finding 4).
- [ ] Choose process-group kill or a non-raising `finally` for `T`, and say which (finding 5).
- [ ] Print one line per repo as its clone starts (finding 6).
- [ ] `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1` in the test fixture (finding 7).
- [ ] umask mode; `sync` calls `require_tools`; a refused rename is that repo's error; cheaper remotes for the 44-repo test (finding 8).

## Checkpoint
**When**: 2026-11-18 16:37 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second Plan Review says the plan is ready to build and that none of its new findings needs another plan round; the owner started this drive: "do 1 and 2", "Merge and carry on")
**After**: plan
**Decision**: proceed

Build part 1 ("Part of #500": init and a first sync that clones what is missing). Apply the second Plan Review's findings while building; where this entry and the plan differ, this entry wins.

1. Temporaries: every temporary directory the tool makes after init sits in .repos-manifest/, with the hidden prefix the plan gives: the clone's temporary directory and the aside copy for replacing a file. One sweep, once per run, before the run makes anything, removes leftovers there by the plan's rule (the name pattern, not a link, the process in the name has ended). Nothing is ever made under a src/ except by the final rename.
2. The destination check is one equality: the real path of the destination's parent equals the system directory's real path joined with the expected parts. The design says that names a case-insensitive disk treats as one are not checked in this part.
3. vcs in the tests: an existing vcs on PATH wins, and the test environment's own directory is appended, so this machine tests vcstool and CI tests vcs2l. The pytest header prints which vcs was used. A test shows a missing version gives a failure.
4. Correct the two claims the review names (how vcs2l loads pkg_resources; names differing only in case).
5. A stopped run: no process-group handling in this part. vcs runs in the tool's own process group, so a Ctrl-C at a terminal reaches git and a password prompt works. If removing the temporary directory fails because a clone is still writing into it, that is a warning, the next run's sweep removes it, and the run's exit status stays the stop's (128 + the signal). Say so in the design.
6. One line is printed per repo as its clone starts.
7. The test fixture sets GIT_CONFIG_GLOBAL=/dev/null and GIT_CONFIG_NOSYSTEM=1.
8. .repos-manifest/ gets its mode from the umask; sync checks for vcs and git as init does; a rename refused because the place was filled meanwhile is that repo's error and the others go on; the 44-repo test uses few distinct remotes.
9. state.yaml stays in part 1: it is small, and it records the exact commit each repo was put on.

Design documents: the code does not depend on pull request 508's text. Build first. The design edits are the last commit, made after 508 has merged and origin/main has been merged into this branch; if 508 has not merged when the code is done, the implementation is recorded complete for the code with the design edits listed as the one step left, and the host brings main in.

## Implementation
**Status**: complete
**When**: 2026-11-18 16:55 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-500 at `bffb6d55`

Part 1 of #500: `init`, and a `sync` that clones what is missing and touches nothing that is there. The code is complete; the design edits are the one step left (see the end). Design read from `origin/feature/issue-495` at `03d7fa7d` (pull request 508, still OPEN); `origin/main` (`4d319d9d`) does not have the layout design (no `--distro-dirs` in its design.md), so no design edit was made and `origin/main` was not merged.

Commits (each "Part of #500"):
- `291848eb` stop-signal handling moved from `cli.py` to `signals.py` (`Stopped`, `signals_end_the_run`, `stop_exit`); the resolve signal tests pass unchanged.
- `d64943dc` `system.py`: `config.yaml` (`config_text`, `read_config`, whose errors name the file and say to repair or remove the folder), `find_system`, `distros_for`, the path functions and `paths_init_creates`, `is_in_place` (the check on the real destination as one equality), `state.yaml` per distro (`read_state`, `put_distro_state`), `replace_file`, `oserror_message` and `reporting_oserror` (the one `OSError` rule), and `read_manifest`, the only caller of `load_manifest` (resolve and validate now use it too, so 498 part 2's `base.py` is a one-line change there).
- `f5033ca4` `vcs2l>=1.1.7` in the `test` extra (no runtime dependency, nothing under `.github/`); a `vcs` fixture that appends the Python's directory to PATH, fails (not skips) with "install vcs2l or vcstool" when no `vcs` is found, and sets `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`; the pytest header names the `vcs`; `test_vcs_behaviours.py` (six tests, a missing version included).
- `bffb6d55` `sync.py` (`require_tools`, `sweep_temporaries`, `clone_repo`, `sync_distro`, `sync_distros`, `resolve_all`, `run_sync`) and `init.py` (`check_distros`, `summary`, `make_system_dir`, `run_init`), the `init` and `sync` parsers in `cli.py`, and tests: `test_init.py`, `test_init_refusals.py`, `test_clone.py`, `test_sync.py`, `test_interrupted.py`.

Checks run:
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests`: 823 passed (736 before, none changed; 87 new). The `vcs` used: `/usr/bin/vcs (vcs 0.3.0)`, vcstool, as the report header prints. vcs2l was not installed or run here; CI's first run is its first execution.
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: `Results: 1014 passed, 0 failed, 0 skipped`.
- black and flake8 by the commit hooks; pylint's hook does not cover `tools/`. The full pre-commit pass is left to the host.
- Hand run in the session scratchpad with local remotes (two layers, three repos, one optional with a url that does not exist), `init --distro-dirs --distro rolling --role dev --yes`: exit 0, two clones, the optional one skipped and listed; `sync`: nothing cloned but the optional retried, "present, not touched (2)"; after deleting one clone, `sync` cloned it again and recorded it. Removed afterwards.

Readings where the design, plan and Checkpoints were silent:
- Refusal row 3 (`--manifest-ref`/`--manifest-path` without the git form) is not built: neither option exists in part 1, so argparse refuses them.
- Rows 6 and 7 (a distro not listed) are checked by `init` itself before `resolve`, so each gets its own next step; the condition is the resolver's.
- `read_manifest(location, base)` takes a location and a base directory rather than `(system, config)`, because `init` has no config yet; it is still the one place.
- A sweep of `.repos-manifest/` runs once per run in `sync_distros` (shared by `init` and `sync`); `init`'s step 8 sweeps the system directory for its own aside.
- An error after `.repos-manifest/` exists in `init` says "the system is set up: run `repos-manifest sync` to finish".
- `write_output`'s own errors name `--out <path>` (output.py is unchanged), so a resolved directory that cannot be written reads "--out .../.repos-manifest/resolved...".
- `setup.bash` is written after a distro's clones, only when absent and only when its directory passes the destination check.
- The summary prints a `Layout:` line for every layout; the design's exact line for a flat system with a distro.

Not built (with reason): everything in the plan's "Cut from part 1" table (`--local-manifest` and the local-copy read, the `--` pass-through, the incomplete-clone listing, existing-repo vcs tests); updating present clones (part 2); `add-distro` (its own issue); refusal row 3 (above); case-folding disks are not checked (Checkpoint 2).

Left: the design edits the plan lists for part 1, with the README and both roadmaps (pull request 508 changes the same three files), as the last commit after 508 merges and `origin/main` is merged into this branch.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 17:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-500 at `bee08a84`
**Base**: origin/main
**Depth**: Deep (reason: 3568 lines over 17 files; new code that creates directories, clones and removes temporaries on a person's disk)
**Must-fix**: 4 | **Suggestions**: 10
**Round**: 1 | **Ship**: continue — round 1: 4 must-fix; first round always re-reviews after fixes

Contract read from `origin/feature/issue-495` (pull request 508, not merged). Suites: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests` 823 passed (vcs: /usr/bin/vcs, vcstool 0.3.0; Python 3.14); `bash .agent/scripts/tests/test_ros2_colcon.sh` 1014 passed, 0 failed, 0 skipped. No existing test file edited (conftest.py only gains the fixture). pre-commit (black, flake8) passed on the changed files. Specialists: static, governance, plan drift, Claude adversarial, gemini and codex all completed.

Hand runs with local remotes: the owner's case (`--distro-dirs --distro rolling`, unnamed + two named layers, nested key, optional repo that cannot be cloned), flat, no distros, and two distros gave the design's trees, config.yaml, state.yaml and resolved/<distro>/; clones on the manifest's version with `origin` as given. Every init refusal changed nothing (listing compared). Links on the way (src, a layer directory, a key's parent) were refused per repo and nothing was written outside. Sweep: dead-pid temporaries removed (a read-only one included), a live pid's, a link and wrong-length names kept. SIGINT/SIGTERM/SIGHUP during clones: exit 130/143/129, no temporaries left, the next `sync` finished. A broken manifest after init changed nothing, and the message says the manifest failed. vcs2l 1.1.7's `vcs import <dir>` with stdin has the same semantics and exit status as vcstool 0.3.0's (import_.py and the git client's import_ compared).

### Findings
- [x] (must-fix) The design's init refusal "two --distro that differ only in case, with --distro-dirs" is not built and not listed as not built; the manifest reader accepts distros [rolling, Rolling], and init then makes both directories (on a case-folding disk the second distro would replace the first's resolved files). Check it in check_distros before the manifest's list — `tools/repos-manifest/src/repos_manifest/init.py:48`
- [x] (must-fix) Errors from write_output, reached by init and sync, name `--out` ("--out …/.repos-manifest/resolved: cannot be written", "is a symbolic link; give the directory itself", "is the current directory or one of its parents"), an option neither command has; give write_output the label to use, or rephrase at the call — `tools/repos-manifest/src/repos_manifest/sync.py:196`
- [x] (must-fix) read_config and read_state check only the top level: `layout: distro-dirs` with no distros and a scalar distro entry in state.yaml give "internal error (TypeError/AttributeError)" with no file named; `groups: abc` and `distros: jazzy` are split into characters and reported as "the manifest is what failed"; `distros: {}` makes sync a silent no-op. One shape check per file that names the file (the design: an unreadable config.yaml is an error that names it) — `tools/repos-manifest/src/repos_manifest/system.py:113`, `system.py:248`
- [x] (must-fix) `vcs import` and `git rev-parse HEAD` inherit GIT_DIR/GIT_WORK_TREE: with GIT_DIR set (git hooks, `submodule foreach`), init exits 0 and state.yaml records the other repo's HEAD for every repo (reproduced). Remove the repo-locating variables as extends.py's `_LOCAL_ENV_FLOOR` does (that rule shared, not copied; without its no-prompt part, since clones must still prompt) — `tools/repos-manifest/src/repos_manifest/sync.py:123`, `sync.py:137`
- [x] (suggestion) A stop or kill after the rename and before the distro's end loses that repo's (or the whole distro's) state record; part 2's no-record rule heals it, but holding signals over rename + record and writing state per repo is cheap — `tools/repos-manifest/src/repos_manifest/sync.py:171`
- [x] (suggestion) init's sweep of the person's directory removes any dead-pid entry with a temporary's name whatever it holds; remove only an empty directory or one holding only config.yaml — `tools/repos-manifest/src/repos_manifest/init.py:114`
- [x] (suggestion) setup.bash is checked with lexists then written with os.replace, which would overwrite a file made in between; os.link of the temporary refuses instead (the directory renames' windows are not worth closing) — `tools/repos-manifest/src/repos_manifest/sync.py:217`
- [x] (suggestion) stop_exit re-raises the signal without flushing stdout, so `report()` lines of finished distros are lost when output is redirected — `tools/repos-manifest/src/repos_manifest/signals.py:44`
- [x] (suggestion) "run sync to finish once they can be fetched" is printed after a Permission denied or a link-on-the-way failure, which another sync will not fix — `tools/repos-manifest/src/repos_manifest/sync.py:279`
- [x] (suggestion) A file or a dangling link where a required repo belongs counts as "present, not touched" with exit 0; part 2 owns it, but saying "not a directory" now costs one line — `tools/repos-manifest/src/repos_manifest/sync.py:155`
- [x] (suggestion) Owner's call: staging clones in .repos-manifest/ (Checkpoint point 1) makes every clone fail with "Invalid cross-device link" when a distro or layer directory is a separate mount; say so in the design, or stage beside the destination — `tools/repos-manifest/src/repos_manifest/sync.py:161`
- [x] (suggestion) init in a read-only directory names the tool's temporary path ("…/.repos-manifest-tmp-…: Permission denied") rather than the directory — `tools/repos-manifest/src/repos_manifest/init.py:115`
- [x] (suggestion) sync.py and init.py use output.py's private `_process_has_ended`, `_make_writable` and `_signals_held`; make them public names since they are shared — `tools/repos-manifest/src/repos_manifest/sync.py:89`
- [x] (suggestion) A second signal during the finally blocks aborts cleanup and the state write; the next sweep and part 2's no-record rule recover, so not worth more than a note — `tools/repos-manifest/src/repos_manifest/signals.py:22`

## Implementation
**Status**: complete
**When**: 2026-11-18 17:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-500 at `317f66d8`
**Addressed**: Local Review (Pre-Push) at `bee08a84` (2026-11-18 17:05 -05:00)
**Commits**: `e61d8104` (merge of origin/main), `3c72eb98`, `6d1fea11`, `c4767294`, `18c4d2bf`, `e21742bb`, `abe90f09`, `58083832`, `2a26390c`, `eed91acc`, `f03a972d`, `b6222bb5`, `02dcbb47`, `d59d8088`, `317f66d8`

origin/main (`0a1502b4`, with pull request 508's layout design) merged cleanly as `e61d8104`; the tool's suite passed on it unchanged (823 passed). Each code fix has a test that failed before it, except the renames of suggestion 9 (no behaviour) and the regression case of suggestion 2's empty aside. Suggestions are done by host decision (the handoff), listed for the owner's veto.

### Actions
- [x] (must-fix) Two `--distro` that differ only in case, with `--distro-dirs`, are refused ("Name one of them"), checked after "more than one --distro without --distro-dirs" and before the manifest is read, as the design's table orders it; tested with a manifest that lists both, one, and none. Found: the new reader (`manifest.py`, `names()`) accepts `distros: [rolling, Rolling]` (its name rule is `[A-Za-z][A-Za-z0-9_-]*`, with a duplicate check only); the old reader's lower-case distro rule in `schema.py` does not apply to it. Not changed here (another issue's code) — `tools/repos-manifest/src/repos_manifest/init.py:48`
- [x] (must-fix) `write_output` takes `label` (default `--out <out>`) and `again` (default "resolve to the same place"); `sync_distro` passes "the resolved files' directory <path>" and "sync". resolve's messages and `test_output.py` are unchanged — `tools/repos-manifest/src/repos_manifest/output.py:272`, `sync.py`
- [x] (must-fix) One shape check each in `read_config` and `_read_state_data`: wrong types at any level, unknown `layout`, `distro-dirs` without distros, empty `distros`, a flat system with two distros, a setting in a distro's entry ("not read in this version"); every error names the file and what is wrong. CLI test: no shape gives "internal error" or exit 0 — `tools/repos-manifest/src/repos_manifest/system.py`
- [x] (must-fix) `require_tools` asks `git rev-parse --local-env-vars` once per run and returns the environment without those names; every `vcs import` and `git` call gets it; a git that cannot be asked is a refusal. Nothing about prompts is set. Test: with `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE` set to another repo, `init` clones and records each clone's own commit, the other repo unchanged (before: all three clones failed) — `tools/repos-manifest/src/repos_manifest/sync.py:55`
- [x] (suggestion 1) The commit is read from the clone before the rename; signals held over the rename and the state write; state written whole after each repo. Test: a SIGKILL during the second clone keeps the first's record (before: no state.yaml) — `sync.py` `clone_repo`
- [x] (suggestion 2) `init`'s `sweep_asides` removes only a dead-pid directory that is empty or holds only config.yaml; anything else of that name is left with a warning — `init.py`
- [x] (suggestion 3) `create_file` writes a temporary in `.repos-manifest/` and hard-links it into place; a file made meanwhile is left — `system.py`
- [x] (suggestion 4) `stop_exit` flushes stdout and stderr before re-raising the signal — `signals.py`
- [x] (suggestion 5) `closing()` (shared by init and sync): "run sync to finish once they can be fetched" only for a failed fetch; for a repo in the way, "another sync will not change that" — `sync.py`
- [x] (suggestion 6) A place that is there and is not a directory (file, dangling link) is that repo's error (skipped when optional), exit 1 — `sync.py`
- [x] (suggestion 7) Temporaries stay in `.repos-manifest/`; an EXDEV rename gives a message naming both places and the one-filesystem limit, no copy fallback; stated in the design. Tested on a constructed EXDEV error (no test can mount a filesystem) — `sync.py` `rename_failure`
- [x] (suggestion 8) `init` in an unwritable directory: "<dir>: cannot be written (Permission denied); nothing was set up" — `init.py` `make_system_dir`
- [x] (suggestion 9) `process_has_ended`, `make_writable`, `signals_held` are public in output.py; behaviour and tests unchanged — `output.py`
- [x] (suggestion 10) No code; the design says a second stop signal during cleanup cuts it short and the next run's sweep removes what is left — `docs/design.md`

### Design documents (`317f66d8`, on main's text)
- `tools/repos-manifest/docs/design.md`: "Setting up with init" (the aside and its sweep, config.yaml's shape errors, the stub setup.bash, the summary for several distros, the question and `--yes`); Refusals (rows for no vcs/git and a non-terminal input, and a note that next steps naming `add-distro` or `--manifest-ref` are left out until built); "Where the resolved files and state go" (state.yaml's shape, written after each repo, no lock); resolve's lock sentence no longer names issue 500; "sync" (a role or group a distro's manifest lacks; a distro that does not resolve is reported and the others go on; the exit status; how a missing repo is cloned, the one-filesystem limit, what a stop, a second stop or a kill leaves, the closing advice); "What the tools rely on" (vcs from vcs2l or vcstool on PATH; the git variables removed); "What is built" (init and sync to part 1's extent, with what is not built); "Open questions" (three removed; removing a distro and the add-distro half of the role/group question stay).
- `tools/repos-manifest/README.md`: "What works today" (init and sync, what they need) and "Development" (the test extra, git, vcs).
- Left unchanged: `tools/repos-manifest/docs/roadmap.md` and `docs/manifest/roadmap.md` — their Direction tables hold no status, and no line is fully true yet ("init and sync set up and update", "gains another later", "the commands the adapter calls" all need part 2 or add-distro). `.agent/knowledge/build_and_test.md` has no line on the tool (the plan's "nothing fetches yet" line is not there). The plan's README sentence on ssh passphrase prompts was not added: not verified here.

### Checks
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests`: 868 passed; vcs: /usr/bin/vcs (vcs 0.3.0), vcstool.
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: Results: 1014 passed, 0 failed, 0 skipped.
- `bash .agent/scripts/check_design_anchors.sh`: exit 0, no output.
- black and flake8 by the commit hooks. Full pre-commit pass left to the host. No script under `.agent/scripts/` changed.
- Hand run (scratchpad, local remotes, two layers, an optional repo with no remote): `init ../m.manifest.yaml --distro-dirs --distro rolling --role developer --yes` exit 0, cloned 2, optional skipped; `sync` exit 0, optional retried and skipped, "present, not touched (2)"; tree, config.yaml and state.yaml as the design says. Removed afterwards.

Left open: none from this review. The manifest reader's acceptance of distro names differing only in case is for the reader's owner.

## Implementation
**Status**: complete
**When**: 2026-11-18 17:40 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-500 at `5310062f`
**Commits**: `1ace9a41` (merge of origin/main, with pull request 511's `base`), `5310062f`

Main brought in again before the next review: pull request 511 made the tool read `base` and moved the manifest loader from `manifest.py` to `base.py`.

### Actions
- [x] Merge of origin/main as `1ace9a41` (a merge commit, no rebase). Two conflicts, as expected, nothing else:
  - `tools/repos-manifest/src/repos_manifest/cli.py` `_load_new`: kept this branch's `read_manifest(args.manifest, Path("."))`, the one place a manifest is read; main's unused `base` import dropped. Nothing main prints is lost: `read_manifest` calls `base.load_manifest(path, source=location)` and prints each warning as `WARNING: ...` to stderr as main did; `validate`'s `base:` lines and the head comment's `# base:` lines come from the returned manifest's `bases`, which is unchanged.
  - `tools/repos-manifest/README.md` "What works today": main's sentence on `base` read from local paths kept; its "Nothing fetches, syncs or builds yet" dropped, since `init` and `sync` now clone (this branch's paragraph already says nothing builds yet).
- [x] `system.py` imports `load_manifest` from `.base` (and `UNNAMED_LAYER`, `Manifest` still from `.manifest`); `read_manifest`'s docstring says it reads the chain. No import cycle: `base.py` imports `combine`, `manifest`, `yamlload` only. No other moved name (`parse_manifest`, `has_repositories_key`, `UNNAMED_LAYER`, `Manifest`) is used by this branch's modules or tests.
- [x] `init` and `sync` with `base` simply work: the resolved result is the merged chain, a relative `base` is taken from the manifest's own directory (`base.py` follows links, then joins). Test `test_a_manifest_with_base_sets_up_the_merged_chain` in `tests/test_init.py` (`5310062f`): a leaf in `manifests/` builds on `parent.manifest.yaml` beside it; `init ../manifests/leaf.manifest.yaml` from the system directory clones both manifests' repos into their layers, state.yaml records both, `layers.txt` carries `# base: <parent>`, and `sync` then clones nothing.
- [x] `tools/repos-manifest/docs/design.md` merged without conflict; "What is built", "resolve", "Where the manifest comes from" and the `base` sentences read together without a contradiction ("What is built" says `base` is read from local paths and `init`/`sync` are built to part 1's extent). No edit.

### Checks
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests`: 962 passed; vcs: /usr/bin/vcs (vcs 0.3.0), vcstool. No test from either side edited; one test added.
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: Results: 1014 passed, 0 failed, 0 skipped.
- `bash .agent/scripts/check_design_anchors.sh`: exit 0, no output.
- Hand run (scratchpad, leaf with `base: parent.yaml`): `validate` printed `base: <parent>`, the role/distro line and `valid`, exit 0; `resolve --out` wrote the three files with `# base: <parent>` in the head comment, exit 0. Removed afterwards.
- black and flake8 by the commit hooks. Full pre-commit pass left to the host.

Left open: none.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 17:52 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-500 at `03171755`
**Base**: origin/main
**Depth**: Deep (reason: whole-branch diff, 4363 lines over 20 files; new code that creates directories, clones and removes temporaries on a person's disk; fix-round rule, same tier as round 1)
**Must-fix**: 3 | **Suggestions**: 12
**Round**: 2 | **Ship**: continue — round 2: 3 must-fix is high (all mechanical, down from 4); another independent read warranted

Suites: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests` 962 passed (vcs: /usr/bin/vcs, vcs 0.3.0, vcstool; Python 3.14; no 3.10 interpreter here, a grep found no 3.11+ feature); `bash .agent/scripts/tests/test_ros2_colcon.sh` 1014 passed, 0 failed, 0 skipped. pre-commit on the changed files: clean. `git diff origin/main...HEAD -- .github` empty. Existing test files unchanged; conftest.py only gains lines. No new test patches an os function reached through pathlib. Specialists: static, governance, plan drift, Claude adversarial, gemini and codex (both EXIT=0).

Round 1 must-fix: 1 (case twins) fixed, refused before the manifest is read; 2 (`--out` in init/sync messages) fixed, resolve's messages and tests unchanged; 3 (shape checks) partly fixed: wrong types at every level are named, but unknown keys, missing fields and `format` pass (below); 4 (git variables) fixed for GIT_DIR, GIT_WORK_TREE, GIT_INDEX_FILE, GIT_OBJECT_DIRECTORY: correct clones and commits, the other repo untouched, nothing set that stops a prompt; GIT_NAMESPACE is not in git's list (suggestion below).

Hand runs with local remotes: the owner's case (`--distro-dirs --distro rolling --role developer`, unnamed and three named layers, nested key, branch, tag, unclonable optional) with `--yes` and at a pseudo-terminal answering y (two distros): trees, config.yaml, state.yaml, resolved/<distro>/ and setup.bash as the design says; piped y without `--yes` refused. Kill during the third clone: SIGKILL left one temporary in .repos-manifest/ and a state.yaml (parses) with the two finished repos; SIGTERM/SIGINT left no temporary, exit by the signal, same state; each next `sync` swept, cloned the rest, exit 0. `manifest` is recorded as given at init (e.g. `../mf/leaf.yaml`), read from the system directory: a later `sync` from a subdirectory finds it and its relative `base` (from the manifest's own directory); after moving the system or a parent the error names the recorded path. `validate` prints `base:` lines; init's and resolve's head comments carry `# base:`. init's aside sweep, the non-directory place, the closing advice and the unwritable directory behave as fixed.

### Findings
- [x] (must-fix) config.yaml and state.yaml shape checks are open: unknown top-level config keys pass silently, including the design's `local_manifest`, `fetch_from`, `remotes` (fetch_from set, sync clones from the manifest's URL, exit 0) while a distro setting is an error; the design's git-form `manifest` mapping gets "is not a mapping with a `manifest`"; state.yaml accepts any `format`, repo entries missing `layer`/`version`/`commit`, and unknown keys, though design.md:284 says one of the wrong shape is an error (lead, gemini, Claude adversarial) — `tools/repos-manifest/src/repos_manifest/system.py:144`, `system.py:316`
- [x] (must-fix) Refusals table row "`--manifest-ref` or `--manifest-path` is given and the manifest is not given in the git form" is a check init does not make (argparse refuses the unknown option) and the row is not marked not built; the add-distro rows likewise (lead) — `tools/repos-manifest/docs/design.md:244`
- [x] (must-fix) "exits with 1 when ... a repo that is not optional could not be cloned or is in the way" is false: an optional repo with a link on the way, one that appeared meanwhile, a failed mkdir or a failed rename is FAILED (exit 1); only the not-a-directory and fetch cases use the optional rule; one rule for all (Claude adversarial, gemini, lead) — `tools/repos-manifest/src/repos_manifest/sync.py:206`, `sync.py:217`, `sync.py:224`, `sync.py:229`
- [x] (suggestion) GIT_NAMESPACE is not among `--local-env-vars`: with it set, local-path remotes clone empty, recorded as cloned with `commit: null`; drop it too and treat an unreadable HEAD as that repo's failure (lead) — `tools/repos-manifest/src/repos_manifest/sync.py:97`
- [x] (suggestion) setup.bash creation is unguarded: a file where a distro directory belongs gives an uncaught "File exists" after cloning every repo into nowhere, and EXDEV/EPERM from os.link on a separate mount or a filesystem without hard links names a temporary; both end the run before the report and other distros (gemini, Claude adversarial, lead) — `tools/repos-manifest/src/repos_manifest/sync.py:271`
- [x] (suggestion) A manifest error after the system moved names the recorded relative path without saying it is taken from the system directory or that `manifest` in config.yaml records it (Claude adversarial, lead) — `tools/repos-manifest/src/repos_manifest/sync.py:326`
- [x] (suggestion) sync from inside .repos-manifest/resolved/ is told to "give a directory beside or below it", which sync cannot (gemini, Claude adversarial) — `tools/repos-manifest/src/repos_manifest/output.py:301`
- [x] (suggestion) Ctrl-C before `signals_end_the_run()` (reading config and manifest, `vcs --version`) prints a KeyboardInterrupt traceback; nothing has changed (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/sync.py:338`, `init.py:188`
- [x] (suggestion) A removed current directory gives "internal error (FileNotFoundError)" from init and sync: `os.getcwd()` is outside `reporting_oserror` (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/sync.py:330`, `init.py:186`
- [x] (suggestion) A present repo behind a link on the way counts as present before the destination check runs; harmless while part 1 touches nothing present, but part 2 must check first (gemini) — `tools/repos-manifest/src/repos_manifest/sync.py:201`
- [x] (suggestion) A file where a layer or key directory belongs is found only after a full clone; check ancestors first (gemini) — `tools/repos-manifest/src/repos_manifest/sync.py:205`
- [x] (suggestion) The repair advice for a broken config.yaml, "remove that .repos-manifest/ folder to set up again", leads to init's refusal for the existing src/ and setup.bash (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/system.py:133`
- [x] (suggestion) design.md says init writes setup.bash; sync also re-creates a missing one: say so (Claude adversarial) — `tools/repos-manifest/docs/design.md:197`
- [x] (suggestion) Not worth doing, noted: rename over an empty directory made in the check-to-rename window (no RENAME_NOREPLACE in Python); a state write failing after the rename leaves an unrecorded clone that part 2's no-record rule heals; non-UTF-8 output or file names give internal error; URLs with credentials printed in the summary (codex, gemini, Claude adversarial) — `tools/repos-manifest/src/repos_manifest/sync.py:227` (deferred: the review's own reason: not worth doing, only noted (no RENAME_NOREPLACE in Python; an unrecorded clone is healed by part 2's no-record rule; non-UTF-8 output and credentialed URLs are noted))

## Implementation
**Status**: complete
**When**: 2026-11-18 18:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-500 at `f2cdeb68`
**Addressed**: Local Review (Pre-Push) at `03171755` (2026-11-18 17:52 -05:00)
**Commits**: ef753c39, 6d1c12cb, 47f574e3, 30953239, c75cda13, 3d5aea1f, 1fee7f32, cbf4753d, 943da14b, 237f4412, 19fc7d6e, 874430e1, f2cdeb68

Decisions on each finding are the host's (dispatch of round 2's fix pass), listed for the owner's veto.

### Actions
- [x] (must-fix) Shape checks, one rule per file: config.yaml and state.yaml are accepted only with exactly the shape this version writes. config.yaml: `manifest` (a path; the git form and a URL are refused), `layout`, and `role`, `groups`, `distros` when set, each of its type, each distro entry empty; any other key is an error naming the file and key ("is not read by this version"). state.yaml: `format: 1`, each distro `{repos: ...}`, each repo exactly `layer`, `version` (string or null), `commit` (string); unknown keys at any level named. design.md says each in one sentence; its config.yaml table marks `local_manifest`, `fetch_from`, `remotes` and the git/URL `manifest` as not read in this part — `system.py` `_check_keys`, `read_config`, `_read_state_data` (ef753c39)
- [x] (must-fix) Refusals table: a note above it names the `init` row for `--manifest-ref`/`--manifest-path` and every `add-distro` row as not built in this part — `docs/design.md` "Refusals" (6d1c12cb)
- [x] (must-fix) Optional repos, one rule at one decision point: `clone_repo` turns any failure of `_put_in_place` into skipped for an optional repo (never non-zero exit) and an error otherwise; the design states the rule once in "sync" — `sync.py` `clone_repo` (47f574e3)
- [x] (suggestion 1) `GIT_NAMESPACE` is removed with the names `--local-env-vars` lists; a clone whose HEAD cannot be read is that repo's failure, not put in place; `RepoRecord.commit` is a string — `sync.py` `require_tools`, `_put_in_place` (30953239)
- [x] (suggestion 2) setup.bash is created with one exclusive `open(..., "x")`, no temporary or hard link; a failure is an ERROR line with path and reason after that distro's report, the other distros go on, exit 1 — `sync.py` `create_setup` (c75cda13)
- [x] (suggestion 3) A manifest that cannot be read: the message says its path is `manifest` in config.yaml, taken from the system directory, and names both — `sync.py` `resolve_all` (3d5aea1f)
- [x] (suggestion 4) sync from inside the resolved files: "run `sync` from the system directory or from below it, outside .repos-manifest/"; `write_output` gains an `elsewhere` argument whose default keeps resolve's message — `output.py`, `sync.py` (1fee7f32)
- [x] (suggestion 6) A removed current directory is "the current directory no longer exists; change to one that does and run it again" for init and sync — `system.py` `current_directory` (cbf4753d)
- [x] (suggestion 5) The stop signals are caught from the first step of `init` and `sync`: one line, no traceback; sync says "nothing was changed" before it changes anything, init keeps its tested "nothing was created" until its system directory is made — `init.py` `run_init`, `sync.py` `run_sync` (943da14b)
- [x] (suggestion 7) plan.md part 2 table: the destination check runs before a repo is treated as present — `.agent/work-plans/issue-500/plan.md` (237f4412)
- [x] (suggestion 8) Done as one check in the existing destination check: `is_in_place` became `place_problem`, which also requires the nearest existing directory on the path to be a directory and returns the reason ("src/grp is on the way and is not a directory; not cloned"), so the file is found before the clone — `system.py` `place_problem` (19fc7d6e)
- [x] (suggestion 9) Broken config.yaml advice: "repair the file, or, to set up again, move <system> aside and run `repos-manifest init` in an empty directory"; design matches — `system.py` `read_config` (874430e1)
- [x] (suggestion 10) design.md says `sync` writes a missing setup.bash too — `docs/design.md` (f2cdeb68)
- [x] (suggestion 11) Not worth doing, noted — (deferred: the review's own reason; no action)

### Tests
Each code fix has a test that failed before it (checked by running it against the unfixed source): test_system.py (shape cases), test_clone.py (optional one rule for link/file/appeared meanwhile; GIT_NAMESPACE; unreadable HEAD; file on the way found before the clone), test_sync.py (setup.bash with a file where the distro belongs and in a read-only directory; manifest after the system moved; sync inside resolved/; removed cwd), test_interrupted.py (Ctrl-C during `vcs --version` for init and sync, a real SIGINT to a child process).

### Checks
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests`: 1001 passed in 101.63s (vcs: /usr/bin/vcs, vcs 0.3.0, vcstool; Python 3.14)
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: 1014 passed, 0 failed, 0 skipped
- `bash .agent/scripts/check_design_anchors.sh`: exit 0
- Hand check with local remotes: `fetch_from: x` in config.yaml gives "config.yaml: `fetch_from` is not read by this version; repair the file, ...", exit 1; an optional repo's place made a regular file gives "skipped src/b (optional): is there and is not a directory; left as it is", "optional, skipped (1): src/b", exit 0.
- Hooks ran on every commit with `SKIP=validate-script-tests`; the full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 18:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-500 at `52656a19`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff; whole-branch tier Deep, 4969 lines over 20 files)
**Must-fix**: 1 | **Suggestions**: 6
**Round**: 3 | **Ship**: recommended — round 3: 1 mechanical must-fix (prev 3), not rising — fix and ship rather than another full round

Scope: the round 2 findings and `git diff b8e39507..HEAD`. Specialists: static (pre-commit on the fix round's files: black, flake8, design anchors and the rest passed), governance, plan drift, Claude adversarial. Cross-model: skipped (round-3 convergence check, per handoff).

Suites: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests` 1001 passed in 101.49s (vcs: /usr/bin/vcs, vcstool 0.3.0; Python 3.14, no 3.10 interpreter here; a grep of the fix diff found no 3.11+ feature); `bash .agent/scripts/tests/test_ros2_colcon.sh` 1014 passed, 0 failed, 0 skipped. `git diff origin/main...HEAD -- .github` empty. No new test patches an os function reached through pathlib. Edits to earlier tests weaken nothing: they follow the renamed `place_problem`, the new advice text, and complete state fixtures (commit now required); resolve/validate/output/cli tests untouched.

Round 2 must-fix: 1 (shape checks) fixed; 2 (Refusals table note) fixed; 3 (one optional rule) fixed.

Hand runs with local remotes (the tool's entry point `cli.run`): init, then sync twice, exit 0 and no refusal of the tool's own files in every layout: flat with a distro, flat with no distro, distro-dirs with one and with two distros, role plus `--with`, a role with no extra groups, a manifest with `base`. `groups` is written only with `--with`. 30 hand-made config.yaml/state.yaml variants: each wrong one refused naming the file and key (fetch_from, local_manifest, remotes, git-form and URL manifest, missing keys, null role, distro settings, format 2/true/"1", extra keys, null commit, int version); version null and an unknown distro in state accepted. Obstacles (optional / required): nonexistent url, link on the way, file at the place, file where a parent directory belongs, empty remote: optional skipped with the reason, exit 0; required ERROR, exit 1; the other new repo cloned; the obstacle unchanged; no temporary left. Read-only src/: the optional skipped, required failed (the beside repo fails too, same src/). setup.bash: an existing file, link, dangling link, directory never replaced; read-only distro directory and a file where the distro directory belongs: ERROR after that distro's report, the other distro goes on, exit 1, as design.md says. Ctrl-C (SIGINT) with a FIFO manifest (init and sync), at init's prompt on a pseudo-terminal, during a clone (init and sync): one line, no traceback, process ended by SIGINT; "nothing was created/changed" before any change, "run sync to finish" after; no temporary left; the next sync finishes, exit 0. Messages: moved system, manifest a directory, missing `base`, sync inside resolved/, removed cwd, broken config.yaml: each true and actionable.

### Findings
- [x] (must-fix) A clone whose HEAD cannot be read (an empty remote, no commits yet) is FAILED with fetch=False, so `closing` says "another sync will not change that: the ERROR lines above say what is in the way"; nothing is in the way and a later sync after a push clones it. Mark it fetch=True (or give it its own advice) and match design.md:639 (Claude adversarial; confirmed by run) — `tools/repos-manifest/src/repos_manifest/sync.py:241`
- [x] (suggestion) `SETUP_TEXT` says "# Written by repos-manifest init" though sync now writes a missing setup.bash too (Claude adversarial; confirmed by run) — `tools/repos-manifest/src/repos_manifest/system.py:44`
- [x] (suggestion) create_setup: a write failure (ENOSPC, EIO) or a stop signal between the exclusive open and the write leaves an empty or partial setup.bash, which later syncs leave as it is and which sources with 0; unlink what this call created on failure and hold the signals over open and write (Claude adversarial, read) — `tools/repos-manifest/src/repos_manifest/sync.py:313`
- [x] (suggestion) A failed rename names the temporary, removed by the time it is read ("…/.repos-manifest-tmp-…/zz -> …/core/src/zz: Permission denied"); now also on the optional "skipped" line. Pre-existing and tested, so outside round-3 scope; `place: reason` would do — `tools/repos-manifest/src/repos_manifest/sync.py:177`
- [x] (suggestion) setup.bash failure repeats its path: "jazzy/setup.bash: cannot be created: jazzy/setup.bash: Permission denied" — `tools/repos-manifest/src/repos_manifest/sync.py:319`
- [x] (suggestion) design.md config.yaml table: the `manifest` row's "A distro with its own `manifest_version` reads it at that version" and the `distros` row's "each with its settings" carry no "Not read in this part" mark, though a distro setting is refused; the optional-rule list at design.md:675 omits "a file where a directory on its path belongs" — `tools/repos-manifest/docs/design.md:79`
- [x] (suggestion) Not worth doing, noted: mkdtemp failing or vcs/git vanishing mid-run ends the whole run, outside the optional rule; a recorded `manifest` containing `://` whose file was removed is reported as a URL (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/sync.py:227` (deferred: no action: the review notes it as not worth doing (mkdtemp failing or vcs/git vanishing mid-run, a removed manifest path with ://), per the host's checkpoint)

## Checkpoint
**When**: 2026-11-18 18:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 left one mechanical must-fix and its ship line recommends fixing it and publishing)
**After**: rounds
**Decision**: address

Fix the round 3 review's one must-fix and its suggestions 1 to 5, then publish. Suggestion 6 is no action, for the review's own reason.

- Must-fix: a clone whose HEAD cannot be read (a remote with no commits yet) is a failure a later sync can fix, and the closing advice says so; the design's sentence matches.
- 1: setup.bash's first line names no command that wrote it, or names both.
- 2: a setup.bash that could not be written whole is not left behind: what this call created is removed on failure, and the stop signals are held over creating and writing it.
- 3: a failed rename's message names the repo's place and the reason, not a temporary that is gone.
- 4: the setup.bash failure message gives its path once.
- 5: the config.yaml table marks what is not read in this part on the manifest and distros rows; the optional-repo rule's list includes a file where a directory on the repo's path belongs.

## Implementation
**Status**: complete
**When**: 2026-11-18 18:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-500 at `23f5b9d8`
**Addressed**: Local Review (Pre-Push) at `52656a19` (2026-11-18 18:24 -05:00)
**Commits**: 9d95114b, e325844e, ff75f679, 5b0cabd4, 05ef224f, 23f5b9d8

### Actions
- [x] (must-fix) A clone whose HEAD cannot be read is marked fetch=True, so the closing advice says to run sync once it can be fetched; design.md says so. Test with an empty local remote for a required repo, then a sync after its first commit clones it — `tools/repos-manifest/src/repos_manifest/sync.py:241`
- [x] (suggestion 1) setup.bash's first line is "# Written by repos-manifest. Nothing is built here yet."; test checks the first line of one sync wrote — `tools/repos-manifest/src/repos_manifest/system.py:44`
- [x] (suggestion 2) create_setup holds the stop signals over the create and the write and removes the file it created when the write fails; an existing one is never touched. Test: RLIMIT_FSIZE below the stub's size (no os function patched); design.md sentence added — `tools/repos-manifest/src/repos_manifest/sync.py:302`
- [x] (suggestion 3) A failed rename's message is "<place>: <reason>", not the temporary; test updated — `tools/repos-manifest/src/repos_manifest/sync.py:175`
- [x] (suggestion 4) The setup.bash failure gives its path once ("<path>: cannot be created: Permission denied"); an error on another path (the parent's mkdir) still names that path; test updated — `tools/repos-manifest/src/repos_manifest/sync.py:323`
- [x] (suggestion 5) design.md config.yaml table: the manifest and distros rows mark a distro's settings and its own manifest_version as not read in this part; the optional-repo rule lists a file where a directory on the path belongs — `tools/repos-manifest/docs/design.md:79`
- [x] (suggestion 6) no action — `tools/repos-manifest/src/repos_manifest/sync.py:227` (deferred: the review notes it as not worth doing; the host's checkpoint agrees)

### Checks
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests`: 1003 passed in 102.36s (vcs: /usr/bin/vcs, vcstool 0.3.0)
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: 1014 passed, 0 failed, 0 skipped
- `bash .agent/scripts/check_design_anchors.sh`: exit 0
- Hand check: `init --yes` with a required repo whose remote has no commits: "ERROR: src/empty: the clone's HEAD cannot be read; not put in place", failed (1), "Some repos failed; run `repos-manifest sync` to finish once they can be fetched.", exit 1; after a commit on that remote, `sync` cloned it, exit 0.
- No script under .agent/scripts changed, so no other suite applies; the full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 18:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-500 at `32da65b5`
**Base**: main
**Depth**: standard (reason: round 4 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 4 | **Ship**: recommended — the round 3 must-fix is fixed and every suggestion answered; nothing new in the fix diff

Scope: the round 3 review's findings and `git diff b026c50f..HEAD` (9d95114b, e325844e, ff75f679, 5b0cabd4, 05ef224f, 23f5b9d8 and the record commits). Cross-model: skipped (round-4 convergence check, per handoff). Governance, plan-drift and adversarial reads done by this reviewer, not dispatched: the diff is small.

Round 3 must-fix fixed. Hand runs with local remotes: `init --yes` with a required repo whose remote has no commits: "ERROR: src/empty: the clone's HEAD cannot be read; not put in place", "Some repos failed; run `repos-manifest sync` to finish once they can be fetched.", exit 1; after a commit on that remote, `sync` cloned it at the remote's HEAD, recorded in state.yaml, exit 0. The same as optional: "skipped src/empty (optional): …", listed, exit 0; the later sync cloned it. design.md:640 says the same.

create_setup (sync.py:305): the unlink runs only after the exclusive create succeeded, so it can remove only a file this call created; a FileExistsError returns before it; signals held over create and write. Tries: an existing setup.bash with content, a partial one, a symlink, a dangling link, a directory: each unchanged after `sync`, exit 0. Read-only system directory: "ERROR: <path>/setup.bash: cannot be created: Permission denied" (path once), exit 1, nothing left; the next sync writes it. create_setup under RLIMIT_FSIZE 16: "<path>: cannot be created: File too large", nothing left; with a partial file already there, untouched. Rename failure (read-only src/): "ERROR: src/b: <system>/src/b: Permission denied", no temporary named, no temporary left. Stub first line "# Written by repos-manifest. Nothing is built here yet.", asserted in test_sync.py. Each message asserted by a test.

design.md table marks (manifest and distros rows) match system.py's refusal of any distro setting; the optional-rule list's new item matches place_problem. The new test restores the file-size limit and SIGXFSZ in `finally`, patches no os function, is skipped where SIGXFSZ or `resource` is missing; nothing needs Python newer than 3.10. Only test_clone.py and test_sync.py changed among tests; resolve/validate tests untouched.

Checks: `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests`: 1003 passed in 102.83s (vcs: /usr/bin/vcs, vcstool 0.3.0; Python 3.14.4). `bash .agent/scripts/tests/test_ros2_colcon.sh`: 1014 passed, 0 failed, 0 skipped.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**When**: 2026-11-18 18:39 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 4 approved with no findings, and the full pre-commit pass passed at e06bebd6)
**After**: publish
**Decision**: publish

The full pass (every hook, no SKIP, over the files the branch changes) passed on e06bebd6. Published as part 1: the pull request says "Part of #500" and does not close the issue. Part 2 (sync against clones that exist) remains, with three questions held for the owner at its plan checkpoint.

## Integrated Review
**Status**: complete
**When**: 2026-11-18 18:52 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #512 at `5d7a913`
**Sources**: 2 (Local Review (Pre-Push) round 4 @ `32da65b5`, covering `5d7a913` through bookkeeping-only commits; CI rollup at `5d7a913`). No hosted reviews: 0 reviews, 0 inline comments, 0 conversation comments on the pull request when checked at 18:52.
**Cross-source confirmations**: 0
**CI**: all-pass

CI, both runs (push 44422615292 and pull_request 44422618459), every job pass: Lint (pre-commit), Validate Adapter Contract, Validate Documentation, repos-manifest tests (Python 3.10), repos-manifest tests (Python 3.14). This is the first run of the code on Python 3.10 and with vcs2l:
- Python 3.10.22: pytest header `vcs: /opt/hostedtoolcache/Python/3.10.22/x64/bin/vcs (vcs 1.1.7)`, vcs2l 1.1.7 installed from the test extra; `1003 passed` in both runs, no skipped, no failed.
- Python 3.14.10: header `vcs: /opt/hostedtoolcache/Python/3.14.10/x64/bin/vcs (vcs 1.1.7)`; `1003 passed` in both runs, no skipped, no failed.
- 1003 is the local count (Python 3.14.4, vcstool 0.3.0), so every clone test and the RLIMIT_FSIZE test ran under vcs2l on both versions; none fell back to a skip.

Timeline: `review_progress.sh sources` at this head found no open local finding and no dropped entry. Every finding of pre-push rounds 1 to 3 is ticked, closed by the fix rounds or, for the "not worth doing" notes (round 2 item 11, round 3 item 6), by the review's own reason and the host's Checkpoint. Round 4's only box is its "No issues found" line, not a finding. The open boxes in the Issue Review and both Plan Reviews were ruled by the Checkpoints after them. The pull request's host decisions are for the owner's veto and are not findings.

Cross-model: the outside models (gemini, codex) last read this branch at round 2 (`03171755`). Since then two fix rounds changed code that decides what is created or removed on a person's disk: `create_setup` now unlinks a setup.bash it created when the write fails, `place_problem` replaced the destination check, and the optional-repo rule moved to one decision point; rounds 3 and 4 were Claude-only narrow checks. A narrow cross-model pass over `git diff 03171755..5d7a913 -- tools/repos-manifest/src` before merge is recommended; it is the owner's call, not an open finding.

Open before the merge decision: no findings. The one thing outstanding is the optional cross-model pass above.

### Findings
None open.

### False positives
None (no hosted comments).

## Checkpoint
**When**: 2026-11-18 18:54 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: address

The owner chose "Outside pass, then merge (Recommended)" in a dialog (2026-11-18) for pull request 512. The option as shown to him: run Gemini and Codex over the last two fix rounds' code only; "If they find nothing of substance, I merge without asking again and reinstall the tool on main; if they find something, I fix it and come back to you."

What is addressed: the outside models last read the branch at 03171755 (pre-push round 2). The step is a PR-mode review of pull request 512 with the cross-model reviewers, centred on `git diff 03171755..HEAD -- tools/repos-manifest/src`. It is a review, not a fix round; nothing in the code changes unless it finds something.

## Local Review
**Status**: complete
**When**: 2026-11-18 19:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #512 at `047e8413`
**Depth**: Deep (reason: +5065/-116 over 20 files; code that creates, renames and removes on a person's disk; centred on `git diff 03171755..HEAD -- tools/repos-manifest/src`)
**Must-fix**: 3 | **Suggestions**: 9

Cross-model: gemini completed (EXIT=0), codex completed (EXIT=0); Claude adversarial completed. Each point checked against the code; the must-fixes reproduced with local repos in the session scratchpad.

### Findings
- [x] (must-fix) `require_tools` drops `GIT_CONFIG_COUNT` and `GIT_CONFIG_PARAMETERS` (listed by `git rev-parse --local-env-vars`), so git config passed in the environment or by `git -c` (an `insteadOf`, a CI credential header) is silently lost for every clone; git's own move to another repo keeps those two. Keep them; correct the docstring ("variables that point git at a repository") and the design sentence; add a test (Claude adversarial; reproduced) — `tools/repos-manifest/src/repos_manifest/sync.py:99`
- [x] (must-fix) A flat system set up from a manifest without distros, whose manifest then gains `distros:`: `sync` prints the resolver's "has distros; give one of ['jazzy', 'rolling']", and `sync --distro jazzy` is refused ("this system does not record it"). design.md ("sync", the disagreements list) says the message says nothing has been moved and a system with distros is set up in a new directory with `init` (`--distro-dirs` for more than one); "What is built" does not list this as unbuilt (Claude adversarial; reproduced) — `tools/repos-manifest/src/repos_manifest/sync.py:391`
- [x] (must-fix) design.md and `sweep_asides`'s docstring say a later `init` "names anything else of that name and leaves it"; a link of that name (dead pid) is skipped with no warning. Warn for it too, or say links are left unnamed (gemini; read from code) — `tools/repos-manifest/src/repos_manifest/init.py:135`, `tools/repos-manifest/docs/design.md:187`
- [x] (suggestion) The rename can replace an empty directory made at the place after the last check; `_head` and `mkdir` sit inside that window. Run `_head` before the re-check to narrow it; no-replace rename is not in the stdlib (codex, gemini, Claude adversarial) — `tools/repos-manifest/src/repos_manifest/sync.py:236`
- [x] (suggestion) A state write that fails after the rename ends the run with only the path error; say that the repo was put in place but not recorded (part 2's rule records an unrecorded repo that is on the manifest's version) (codex, Claude adversarial) — `tools/repos-manifest/src/repos_manifest/sync.py:255`
- [x] (suggestion) A failed clone's ERROR quotes vcs's transcript, which names the removed temporary; a note or the place's name would match `rename_failure` (Claude adversarial; reproduced) — `tools/repos-manifest/src/repos_manifest/sync.py:234` (deferred: host decision, no action: the transcript is vcs's own output, quoted as vcs printed it; the ERROR line already names the place)
- [x] (suggestion) `create_setup` says nothing when a directory or a dangling link is at `setup.bash`; it is left as it is, a warning would help (Claude adversarial; reproduced) — `tools/repos-manifest/src/repos_manifest/sync.py:311`
- [x] (suggestion) `make_system_dir`: a failed write of config.yaml prints a bare "ERROR: File too large" (no path, no "nothing was set up"); wrap it as the mkdtemp failure is (gemini; reproduced with RLIMIT_FSIZE) — `tools/repos-manifest/src/repos_manifest/init.py:164`
- [x] (suggestion) Not worth doing: an unlink that fails after a failed setup.bash write replaces the write error and leaves the partial file (needs permissions changed mid-call) (gemini, Claude adversarial) — `tools/repos-manifest/src/repos_manifest/sync.py:326` (deferred: host decision, no action: not worth doing, as the review says (needs permissions changed mid-call))
- [x] (suggestion) Not worth doing: setup.bash is visible empty for the moment between the exclusive create and the write, and a SIGKILL there leaves it empty (codex) — `tools/repos-manifest/src/repos_manifest/sync.py:320` (deferred: no action: the review marks it not worth doing)
- [x] (suggestion) Not worth doing: repeated `--with g` is recorded twice in config.yaml; harmless (gemini) — `tools/repos-manifest/src/repos_manifest/init.py:228` (deferred: no action: the review marks it not worth doing (harmless))
- [x] (suggestion) Not worth doing: state.yaml accepts `format: 1.0` and non-string keys, which the tool never writes (gemini) — `tools/repos-manifest/src/repos_manifest/system.py:353` (deferred: no action: the review marks it not worth doing (the tool never writes those))

Dropped: gemini 1 (`_head` walking up into an enclosing repo: the manifest takes git repos only, and a `vcs import` that exits 0 leaves a git clone); gemini 2a (an unreadable directory named like an aside ends `init` with an error naming it, before anything is made); gemini 4 (distro names are single words checked by the manifest reader; a config.yaml edited to a path still needs the manifest to resolve that distro); gemini 9 (test conftest with PATH unset); gemini 10 and codex 8 (divergences from the plan recorded in design.md and the Checkpoints); codex 3 (a link a person puts at `.repos-manifest/resolved`; `write_output` replaces only an empty directory or its own marked output); codex 4 (no lock: host decision); codex 5 (no process-group handling: host decision); codex 6 (the person's own manifest URLs printed to their terminal, as vcs prints them).

Checks: CI at 047e8413: tool tests (Python 3.10, 3.14), Validate Adapter Contract, Validate Documentation pass; Lint (pre-commit) pending. Local: `pytest tools/repos-manifest/tests` 1003 passed; `test_ros2_colcon.sh` 1014 passed, 0 failed, 0 skipped; `vcs` /usr/bin/vcs from vcstool 0.3.0 (python3-vcstool). flake8 (F, E501) clean on the changed files. Mergeable: MERGEABLE.

## Implementation
**Status**: complete
**When**: 2026-11-18 19:22 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #512 at `8a72ba6c`
**Addressed**: Local Review at `047e8413` (2026-11-18 19:02 -05:00)
**Commits**: eafea0f2, 45fbf5e9, f728ebea, a560898d, 7dcf17f2, 4f575b0e, 8a72ba6c

### Actions
- [x] (must-fix, host decision) Rule: every `vcs` and `git` gets the environment without the names `git rev-parse --local-env-vars` prints, except `GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT`, which carry configuration and are kept; `GIT_NAMESPACE` is removed too. Docstring and design ("What the tools rely on") say exactly this. Git's own `sanitize_repo_env` (run-command.c, used by `prepare_other_repo_env`) keeps exactly those two and removes `GIT_CONFIG`, which `git help config` says names a file for `git config` alone (vcstool runs `git config --get`); so `GIT_CONFIG` stays removed, a narrowing of the host's "every name beginning GIT_CONFIG", listed for the host's veto. Tests: `init` clones through a url rewrite in `GIT_CONFIG_COUNT` (failed before); `GIT_CONFIG` dropped, the two kept; the GIT_DIR test still passes — `tools/repos-manifest/src/repos_manifest/sync.py:60` (eafea0f2)
- [x] (must-fix, host decision) Rule: a flat system recorded without distros whose manifest now has `distros:` ends `sync` with exit 1 and nothing changed, saying the manifest now has distros, the system was set up without one and nothing in it has been moved or changed, and a system with distros is set up in a new directory with `init`, with `--distro-dirs` for more than one; it names no `--distro`. Design sentence matches. Test: message, status, snapshot, no refused option — `tools/repos-manifest/src/repos_manifest/sync.py:391`, `tools/repos-manifest/docs/design.md:604` (45fbf5e9)
- [x] (must-fix, host decision) Rule: `init`'s sweep removes only a directory of the aside's name, not a link, whose process has ended, that is empty or holds only `config.yaml`; any other entry of that name, a link among them, is left and named in a warning. Code, docstring and design say this. Test for the link added (failed before). Consequence: an entry of that name whose process is alive is now warned about as well — `tools/repos-manifest/src/repos_manifest/init.py:129`, `tools/repos-manifest/docs/design.md:186` (f728ebea)
- [x] (suggestion 1) Rule: the clone's HEAD is read before the last check of its place, so nothing slow sits between that check and the rename; one call moved. Test: a place made while HEAD is read is found, not replaced (failed before); the existing "appeared meanwhile" stub now makes a real git repo — `tools/repos-manifest/src/repos_manifest/sync.py:241` (a560898d)
- [x] (suggestion 2) Rule: a failed write of `state.yaml` after the rename ends the run saying the clone is in place but was not recorded, naming `state.yaml` and the reason. Design's state.yaml paragraph says so. Test (failed before) — `tools/repos-manifest/src/repos_manifest/sync.py:255` (7dcf17f2)
- [x] (suggestion 3) A failed clone's ERROR quoting vcs's transcript — `tools/repos-manifest/src/repos_manifest/sync.py:234` (deferred: host decision, no action: vcs's own output)
- [x] (suggestion 4) Rule: something at `setup.bash`'s place that is not a file or a link to one (a directory, a dangling link) is left and named in one WARNING line after that distro's report, from `sync` and `init`; exit status unchanged; a file or a link to one is left silently. Design says so. Tests for sync (four cases) and init (a directory made while it runs) — `tools/repos-manifest/src/repos_manifest/sync.py:311` (4f575b0e)
- [x] (suggestion 5) Rule: a failed write of `config.yaml` during `init` names `.repos-manifest/config.yaml` and the reason and says nothing was set up. Test with RLIMIT_FSIZE in a child process (failed before) — `tools/repos-manifest/src/repos_manifest/init.py:164` (8a72ba6c)
- [x] (suggestion 6) unlink after a failed setup.bash write — `tools/repos-manifest/src/repos_manifest/sync.py:326` (deferred: host decision, not worth doing)
- [x] (suggestion 7) setup.bash empty for a moment — `tools/repos-manifest/src/repos_manifest/sync.py:320` (deferred: the review marks it not worth doing)
- [x] (suggestion 8) repeated `--with g` recorded twice — `tools/repos-manifest/src/repos_manifest/init.py:228` (deferred: the review marks it not worth doing)
- [x] (suggestion 9) state.yaml accepts `format: 1.0` and non-string keys — `tools/repos-manifest/src/repos_manifest/system.py:353` (deferred: the review marks it not worth doing)

### Checks
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests`: 1015 passed (vcs: /usr/bin/vcs, vcstool 0.3.0)
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: 1014 passed, 0 failed, 0 skipped
- `bash .agent/scripts/check_design_anchors.sh`: exit 0
- Hand check (a), scratchpad, local remote: `init --yes` with `GIT_CONFIG_COUNT=1` and a url rewrite from a made-up `file://` prefix: "cloned (1): src/a", exit 0.
- Hand check (b): flat system from a manifest with no distros, then `distros: [jazzy]` added, `sync`: the new message, exit 1, tree unchanged.
- Full pre-commit pass left to the host; commits made with `SKIP=validate-script-tests`.

## Local Review
**Status**: complete
**When**: 2026-11-18 19:33 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #512 at `824e1d2b`
**Depth**: Deep (reason: whole-diff classification, +5382/-118 over 20 files; code that creates, renames and removes on a person's disk; fix round, same tier)
**Must-fix**: 1 | **Suggestions**: 3

Cross-model: codex completed (EXIT=0); gemini failed twice (EXIT=1: empty response, a Bash tool action auto-denied in headless mode), so this round has one outside model. Claude adversarial completed. Every point checked against the code; the must-fix reproduced with local repos in the session scratchpad.

The first PR-mode review's three must-fix are fixed, each run by hand and asserted by a test:
- Environment: kept `GIT_CONFIG_PARAMETERS` and `GIT_CONFIG_COUNT`, removed `GIT_CONFIG`. The fixer's narrowing is right: git's `sanitize_repo_env` (run-command.c, called by `prepare_other_repo_env`) skips exactly `CONFIG_DATA_ENVIRONMENT` and `CONFIG_COUNT_ENVIRONMENT`, and `git help config` says `GIT_CONFIG` affects `git config` alone. `GIT_CONFIG_KEY_<n>`/`VALUE_<n>` are not in `git rev-parse --local-env-vars` and pass through; so do `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_SYSTEM`, `GIT_CONFIG_NOSYSTEM`, `GIT_SSH_COMMAND`, `GIT_SSH`, `GIT_ASKPASS`, `SSH_ASKPASS`, `SSH_AUTH_SOCK`, `GIT_TERMINAL_PROMPT`, `HOME`, `XDG_CONFIG_HOME` (probe of `require_tools`). `init` cloned through a `file:///nowhere/` rewrite given by COUNT/KEY_0/VALUE_0 with `GIT_DIR`/`GIT_WORK_TREE` at another repo, by `GIT_CONFIG_PARAMETERS` in the `git -c` form with `GIT_DIR`, and through a real `git -c ... <alias>`: exit 0 each, the other repo untouched; without a rewrite it fails.
- Flat system gaining `distros:`: the new message, exit 1, tree unchanged; `sync --distro jazzy` there is refused ("this system does not record it (it records: none)"), and the message names no `--distro`. Neighbours: dropping `distros:` and no longer listing the recorded distro each end "the manifest is what failed; nothing was changed" naming the distro, exit 1, unchanged; a `--distro-dirs` system whose manifest gains rolling: exit 0, nothing made for rolling, no `add-distro` named; `--distro rolling` there is refused. All consistent with design.md "sync" and "What is built".
- Sweep: dead-pid empty and config-only asides removed; a dead-pid directory with another file, a file, and a link left and warned; a live process's aside left and warned.
The four suggestions taken (HEAD before the last check, state.yaml not recorded, setup.bash not a file, config.yaml write failure) each have a test and design.md matches; the config.yaml failure is covered by design's "before that step nothing of the system exists".

### Findings
- [x] (must-fix) A refusal after `.repos-manifest/` is made: `head_comment`'s unsafe-character check first runs in `sync_distro`, after `make_system_dir`, so a manifest whose path holds a no-break space or control character makes the system and then prints "refusing to write the head comment ...; the system is set up: run `repos-manifest sync` to finish", and every `sync` fails the same way. False against init.py's docstring and design.md:182 ("before anything is created"). Build `output_files` for each resolved distro in phase one (init and `resolve_all`) and pass them on; add a test (Claude adversarial; reproduced) — `tools/repos-manifest/src/repos_manifest/init.py:262`, `tools/repos-manifest/src/repos_manifest/sync.py:294`
- [x] (suggestion, worth doing) A live process's aside, which is exactly what init leaves (a second init at the same moment, or a crashed init's pid reused), is warned as "named like a temporary of repos-manifest, but not what init leaves"; say its process may still be running (Claude adversarial; hand check) — `tools/repos-manifest/src/repos_manifest/init.py:146`
- [x] (suggestion) The flat-gains-distros message and the wrapped resolver errors start with `manifest` as recorded (relative to the system directory); from a subdirectory `../m.yaml` points elsewhere. Add the "taken from the system directory" note the read error has (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/sync.py:424`
- [x] (suggestion) Not worth doing beyond wording: a failed `os.rename` of init's aside (something made at `.repos-manifest` after the check) gives a bare error naming the removed aside, without "nothing was set up" (Claude adversarial, read from code) — `tools/repos-manifest/src/repos_manifest/init.py:183` (deferred: no action: the review ruled it not worth doing beyond wording (a failed rename of init's aside needs something made at .repos-manifest after the check))

Dropped: codex 1 (no-replace rename / parent swapped for a link: ruled suggestion, not worth doing, last round; reason still true); codex 2 (clone in place but unrecorded after a failed state write: the run now says so, and design's rule records an unrecorded repo on the manifest's version when part 2 is built); codex 3 (link at `.repos-manifest/resolved`: ruled last round); codex 4 (setup.bash empty for an instant: ruled not worth doing); codex 5 (staging in `.repos-manifest/`: host decision); codex 6 (present-entry rule differs from the plan: recorded in design.md and the Checkpoints).

Checks: CI at 824e1d2b, push and pull_request runs, every job pass: Lint (pre-commit), Validate Adapter Contract, Validate Documentation, repos-manifest tests Python 3.10 (header `vcs 1.1.7`, `1015 passed`) and Python 3.14 (`vcs 1.1.7`, `1015 passed`), none skipped. Local: `pytest tools/repos-manifest/tests` 1015 passed (vcstool 0.3.0); `test_ros2_colcon.sh` 1014 passed, 0 failed, 0 skipped; flake8 (F, E501, E9) clean on the changed files. Mergeable: MERGEABLE.

## Implementation
**Status**: complete
**When**: 2026-11-18 19:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #512 at `51a70dfa`
**Addressed**: Local Review at `824e1d2b` (2026-11-18 19:33 -05:00)
**Commits**: 62f61361, bd7faebf, 8a1024bb; merge of origin/main 51a70dfa (clean)

### Actions
- [x] (must-fix) A refusal after `.repos-manifest/` is made: the text of every distro's resolved files, head comment included, is now built in phase one by `sync.plan_distros` (called by `init` right after resolving, and by `sync.resolve_all`), carried as `Planned(resolved, files)`; `sync_distro` only writes `planned.files`. `init` with a manifest reached through a folder with a no-break space is refused with the existing message, exit 1, nothing created; `sync` there changes nothing and says "the manifest's output is what failed; nothing was changed". Both tests fail on the code before. design.md "Setting up with init" and the part-1 paragraph on `sync` updated — `tools/repos-manifest/src/repos_manifest/init.py:244`, `tools/repos-manifest/src/repos_manifest/sync.py:290`
- [x] (suggestion) A live process's aside is now warned as "a temporary of repos-manifest whose process is still running (another init may be setting up here); left as it is"; other entries keep "not what init leaves". Test with a running child's pid; design.md sentence updated — `tools/repos-manifest/src/repos_manifest/init.py:140`
- [x] (suggestion) One helper, `sync.recorded_manifest`, gives the "taken from the system directory" note; the read error, the flat-gains-distros error and the wrapped resolver errors end with it. Tests' expected text updated; design.md says so — `tools/repos-manifest/src/repos_manifest/sync.py:430`
- [x] (suggestion) A failed `os.rename` of init's aside — `tools/repos-manifest/src/repos_manifest/init.py:183` (deferred: no action: the review ruled it not worth doing beyond wording)

### Checks
- `PYTHONPATH=tools/repos-manifest/src python3 -m pytest -q tools/repos-manifest/tests`: 1018 passed (vcs from /usr/bin/vcs, python3-vcstool 0.3.0).
- `bash .agent/scripts/tests/test_ros2_colcon.sh`: 1030 passed, 0 failed, 0 skipped.
- `bash .agent/scripts/check_design_anchors.sh`: exit 0.
- Hand check: `init "../m<NBSP>dir/m.yaml" --yes` in an empty directory printed `ERROR: refusing to write the head comment: the manifest's location or a name holds a control or invisible character`, exit 1; `ls -A` empty.
- Full pre-commit pass over the branch left to the host; commits made with `SKIP=validate-script-tests`.

## Local Review
**Status**: complete
**When**: 2026-11-18 20:01 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #512 at `39e1cfb4`
**Depth**: Deep (reason: round 3 convergence check per handoff; whole-diff tier Deep, scope the round 2 findings and `git diff b6f52636..HEAD -- tools/`)
**Must-fix**: 0 | **Suggestions**: 3

Cross-model: skipped (round-3 convergence check, per handoff). Static analysis (flake8 F, E501, E9 on the five changed Python files: clean), governance, plan drift and a fresh Claude adversarial ran.

The round 2 must-fix is fixed. `init` reaches `make_system_dir` only after reading the manifest, `check_distros`, resolving and `plan_distros` (every distro's files, head comment included), the exists-checks of `paths_init_creates`, `require_tools` and the terminal/--yes check. After the system's record is made, what can still raise: `sweep_temporaries`'s directory read (an OS error), `read_state` (state.yaml cannot exist in the folder just made unless something writes it meanwhile), `write_output`'s checks on `.repos-manifest/resolved/<distro>` (inside the folder just made: never the cwd or above, a distro name starts with a letter so never a temporary's name, a link or file there only if made meanwhile; otherwise OS errors), each clone (per repo, a failure not a refusal) and its `state.yaml` record (an OS error), and `create_setup` (returns a reason, does not raise). None could be known earlier. Hand runs with local remotes in the scratchpad: `init` through a no-break-space folder, in an empty directory and beside an unrelated file, refused with exit 1 and `ls -A` the same; the same through a base reached by a link to that folder; `sync` with the recorded path through it: "the manifest's output is what failed; nothing was changed", exit 1, tree and state.yaml unchanged (a missing clone and a missing setup.bash not made). Ordinary case: `init --distro-dirs --distro jazzy --distro rolling --role full --yes` with a `base` manifest, then `sync`, then a clone removed and `sync`: exit 0 each, the clone back; head comments hold `# manifest:`, `# base:`, `# role:`, `# distro:`. `resolve` and `validate`, eight argument sets, print and write exactly what the code at b6f52636 does; no test of theirs changed. The unsafe-character check exists once (`head_comment`). The recorded-manifest note ends the read error, the flat-gains-distros error and the wrapped resolver errors, and reads right from `jazzy/core`; design.md says the same.

### Findings
- [ ] (suggestion) The "whose process is still running (another init may be setting up here)" warning is taken whenever `process_has_ended` is False, before the contents are looked at: a live pid's directory holding a file init never writes, and a pid of 0 or one too large for `os.kill`, get it too (both reproduced). Take it only for a directory holding nothing or only `config.yaml` whose pid is found running; the rest get "named like ..., but not what init leaves" (Claude adversarial, review hand check) — `tools/repos-manifest/src/repos_manifest/init.py:140`
- [ ] (suggestion) `sync`'s "the manifest's output is what failed" error names no path, though the likeliest bad location is the recorded manifest path; end it with `recorded_manifest(system)` too (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/sync.py:461`
- [ ] (suggestion) `init`'s head-comment refusal does not say that nothing was set up, as its other phase-one errors do (Claude adversarial) — `tools/repos-manifest/src/repos_manifest/init.py:246`

Dropped: adversarial 4 (design.md does not place the output check in the refusal table's order: it runs where resolution already ran; no claim is false).

Checks: CI at 39e1cfb4, push and pull_request runs, every job pass: Lint (pre-commit), Validate Adapter Contract, Validate Documentation, repos-manifest tests Python 3.10 and 3.14 (each header `vcs 1.1.7`, `1018 passed`). Local: `pytest tools/repos-manifest/tests` 1018 passed (/usr/bin/vcs, vcstool 0.3.0); `test_ros2_colcon.sh` 1030 passed, 0 failed, 0 skipped. `git diff b6f52636..HEAD --stat -- tools/` lists only the three fix commits' six files. Mergeable: MERGEABLE.

## Integrated Review
**Status**: complete
**When**: 2026-11-18 20:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #512 at `c84189eb`
**Sources**: 2 (Local Review round 3, PR mode, @ `39e1cfb4`, covers `c84189eb` via bookkeeping: the commits since touch only this issue's progress.md; CI rollup). No hosted reviews: 0 reviews, 0 inline comments, 0 conversation comments on the pull request when fetched at 20:00.
**Cross-source confirmations**: 0
**CI**: all-pass at the code head `39e1cfb4`; at `c84189eb` (a progress-only commit) Lint (pre-commit) still pending in both runs after about 5 minutes, every other job pass

CI at `39e1cfb4`, push run 44431995841 and pull_request run 44431998275, every job pass: Lint (pre-commit), Validate Adapter Contract (adapter 248, project registry 425, ros2_colcon 1030 passed, 0 failed, 0 skipped), Validate Documentation, repos-manifest tests Python 3.10 and Python 3.14 (vcs2l 1.1.7 installed, header `vcs 1.1.7`, `1018 passed` in each of the four jobs, none skipped or failed). At `c84189eb`, runs 44433774537 (push) and 44433771612 (pull_request): Validate Adapter Contract, Validate Documentation, repos-manifest tests 3.10 and 3.14 pass; Lint (pre-commit) pending when checked at 20:07. `merge_pr.sh` gates on CI at the head either way.

Timeline: `review_progress.sh sources` at `c84189eb` returned the three suggestions of the round 3 Local Review as the only open findings, no dropped entries and no candidates. Every finding of the four pre-push rounds and of PR-mode rounds 1 and 2 is ticked, closed by a fix round or marked no action with the review's own reason. Unticked boxes elsewhere in this file are not open findings: the Issue Review's actions (three empty template boxes and the recommendations) were ruled by the Checkpoint at 16:11; the two Plan Reviews' actions by the Checkpoints at 16:25 (revise) and 16:37 (proceed, every finding applied while building); "No issues found. LGTM." in pre-push round 4 is a placeholder, not a finding.

PR body (read at 20:05): every statement checked against this file, CI logs and the code head is true, with two imprecisions, neither false about the code: "approved with 3 small wording suggestions" (suggestion 1 is about when a warning is printed, not only its words); "CI on the pushed head" (the 1018 counts are from `39e1cfb4`; at the pushed head `c84189eb` Lint is still pending). `gh pr view 512 --json mergeable`: MERGEABLE.

Open before the merge decision: no findings. Only Lint at the record-only head `c84189eb` is still running.

### Findings
- [x] (suggestion, Local Review @ `39e1cfb4`, covers `c84189eb` via bookkeeping) `init`'s sweep warns "whose process is still running" for a hand-made entry with a live pid holding other files, or a pid of 0 or too large for `os.kill` — `tools/repos-manifest/src/repos_manifest/init.py` — closed, no action in this pull request (host ruling): it is only a warning about a hand-made entry, nothing is removed, and no ordinary use reaches it; noted for part 2 of #500, which touches the same module
- [x] (suggestion, Local Review @ `39e1cfb4`, covers `c84189eb` via bookkeeping) `sync`'s "the manifest's output is what failed" error does not name the recorded manifest's path — `tools/repos-manifest/src/repos_manifest/sync.py:461` — closed, deferred to part 2 of #500 (host ruling): not a wrong behaviour, a loss or a false statement
- [x] (suggestion, Local Review @ `39e1cfb4`, covers `c84189eb` via bookkeeping) `init`'s head-comment refusal does not say that nothing was set up — `tools/repos-manifest/src/repos_manifest/init.py:246` — closed, deferred to part 2 of #500 (host ruling): not a wrong behaviour, a loss or a false statement

### False positives
None (no hosted comments).

## Checkpoint
**When**: 2026-11-18 20:12 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

The owner chose "Merge and carry on (Recommended)" in a dialog (2026-11-18) for pull request 512 (part 1: init and a first sync that clones what is missing): merge it, reinstall the tool on main, then start part 1B of the adapter (issue 503). The issue stays open: part 2 (sync against clones that exist) remains, with three questions held for the owner at its plan checkpoint, and three wording suggestions from the last review noted for it.

## Checkpoint
**Status**: complete
**When**: 2026-11-19 14:34 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan checkpoint after a merge: plan.md has changed since its last review (9afc4552 reviewed, 237f4412 now) and part 2 is only an outline, so proceed is not open; revise)
**After**: plan
**Decision**: revise

Part 1 merged as pull request 512; the issue is open because part 2 (sync against clones that exist) is not delivered. The plan for part 2 is to be written out in full and reviewed. The owner answered the three questions the outline held for him, in a dialog on 2026-11-19, each with the options and what they change shown. His answers, verbatim: untracked files: "Update it (Recommended)" (untracked files do not count as local work; the clone is fast-forwarded as if clean; if an incoming commit would overwrite one of those files git itself refuses, and the clone is then left as it was and reported). A changed url in the manifest for a cloned repo: "Repoint origin (Recommended)" (sync sets the clone's origin to the new URL, keeps every local branch and file, then applies the ordinary rules; a clone with commits not on the new origin is left alone and reported). A repo given another layer: "Report, do not move (Recommended)" (sync leaves the clone where it is, reports it with the exact mv command, and clones nothing at the new place while the old one exists). New input since the outline: first real use (comment on the issue, 2026-11-19) showed that a changed version for a cloned repo is not followed, state.yaml keeps the old version, and the adapter's validate still passes; pull request 518 added build, its per-distro record and a per-distro build lock, and changed system.py.

## Plan Authored
**Status**: complete
**When**: 2026-11-19 14:41 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-500/plan.md` at `5562540e`

Part 2 written out in full: a 15-rung ladder for a repo that is there (the owner's three answers quoted and followed), the exact git commands and put-back checks, per-distro reports, the existing per-distro build lock taken by sync for a distro's phase two, a sync-written note for built layers whose repos moved, and the stop/kill table. Step 1, local_manifest, --local-manifest and the -- pass-through go to a part 3 (reason in the plan). Git behaviours relied on were run on git 2.53.0 (untracked clash refuses ff, rebase abort restores, tag clobber exit 1, url probe, insteadOf).

## Plan Review
**Status**: complete
**When**: 2026-11-19 14:45 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #500 — repos-manifest: `init` and `sync` set up and update a system directory
**Plan**: `.agent/work-plans/issue-500/plan.md` at `5562540e`
**Branch**: `feature/issue-500`

Scope of this review: part 2 ("Part 2: `sync` against clones that exist") and the plan's marking of part 1. The doubtful git behaviours were tried with git 2.53.0 on local repositories in the session scratchpad (scripts `t1.sh`, `t2.sh`; results quoted in the findings).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One pull request is reasonable (about 500 lines of code, 900 of tests, 120 of docs); the split to part 3 holds (finding 12) |
| Issue alignment | Needs work | Follows the owner's three answers in form, but answer 1's premise ("git itself refuses") is false for ignored files (finding 1), and the url rule undoes a person's own `origin` (finding 2). The issue comment's acceptance case is covered (rung 12 tests) |
| File targeting | Good | `update.py`, `sync.py`, `system.py`, tests, docs; `build.py` unchanged is right |
| Consequences | Concern | The lock's holder text in `system.py`/`build.py` (finding 8); `state.yaml` shape if the url is recorded (finding 2) |
| Principle alignment | Needs work | "Never discard work": findings 1, 3; "Verify before claiming": the ladder's safety checks do not cover ignored files, and the after-abort check would pass the loss |
| ADR compliance | Good | ADR-0017 (design in the same change), ADR-0022 (Serves cites the part's design), ADR-0013 |
| ROS conventions | N/A | Workspace tool |

**Serves** (as checked): Goal "one system directory set up and kept in line from one manifest", under `tools/repos-manifest/docs/design.md#sync` (and `#the-system-directory`, `#setting-up-with-init`, `#refusals`), root `docs/manifest/design.md`. The `#sync` section exists on this branch; the work serves it and breaks no stated rule once findings 1 to 3 are fixed.

### Findings

1. **[Principle: never discard work] (needs-work)** — `git merge --ff-only`, `git switch` and `git rebase` silently overwrite an ignored file that an incoming commit adds as tracked; git refuses only for untracked files that are not ignored. Tried: an ignored `local.yaml` holding `PRECIOUS`, upstream commits a tracked `local.yaml`, `merge --ff-only` exits 0 and the file now holds the upstream text. Worse on the rebase path: the rebase overwrote the ignored file, hit a conflict, `rebase --abort` restored `HEAD` and the branch and then deleted `local.yaml` (it is not in `B`); the plan's after-abort check (`HEAD`, branch ref, `status --untracked-files=no`, no `rebase-*`) passes and reports "put back as it was". The owner's answer 1 promises that "if an incoming commit would overwrite one of those files, git itself refuses, and the clone is then left as it was"; that is true only for untracked, not-ignored files. Fix: before every tree-changing call, list the paths the move adds (`git diff --name-only --diff-filter=A H T`, for a rebase `H`'s merge-base with `O` against `O`) and, for each and each of its parent directories, `os.path.lexists` in the work tree; any hit that is not tracked in `H` leaves the repo alone, reported with the paths. Add an ignored-file test to each of the ff, switch, rebase and rebase-abort rows; `snapshot_repo` already hashes every file outside `.git`.
2. **[Issue alignment, url rule] (needs-work)** — Repointing whenever the manifest's url differs from the clone's raw `remote.origin.url` undoes a person's deliberate `origin` (ssh for pushing, a fork) as soon as everything committed is on the manifest's url, which for an ssh/https pair of the same repo is always. The owner does this today by hand in some clones, so the first part 2 `sync` on his real system would switch those clones back to https. The owner's answer is about the manifest giving a repo a new url, and the tool's rule is that what a person changed is left alone. Recommendation below.
3. **[Principle: never discard work] (needs-work)** — The rebase is run with the person's configuration, and some of it changes more than the one branch. Tried: with `rebase.updateRefs=true`, rebasing `main` also rewrote another local branch (`stacked`) that pointed into the rebased range. Pass `--no-update-refs` (and keep `--no-autosquash` explicit, though git 2.53.0 did not autosquash a non-interactive rebase with `rebase.autoSquash=true`). Separately, `--no-verify` skips the person's `pre-rebase` hook, whose usual purpose is to refuse rebasing published commits: drop `--no-verify` so a refusing hook means "left alone", which is the safe answer.
4. **[Principle: never discard work] (needs-work)** — "Commits not on origin" is measured against `origin/V` only, so after an upstream force-push the old upstream commits count as local work and are rebased onto the new branch. Tried: upstream rewrote `B` to `C`; `rev-list --count HEAD --not origin/main` is 1 and the rebase put the old upstream `B` on top of `C`, exit 0, reported as "rebased 1 local commits". The record holds the commit `sync` last put there: commits reachable from it are not a person's. Count local commits as `HEAD --not O --not <recorded commit>` (with no record, fall back to `--fork-point`), and when that differs from the plain count, leave the repo alone and report that origin was rewritten. Same count for rungs 12 and 13.
5. **[Consequences, submodules] (needs-work)** — A clone with an initialised submodule is made "dirty" by `sync`'s own fast-forward: after the superproject moves the submodule's pointer, `status --porcelain=v2 --untracked-files=no` shows `1 .M SC..` for it (tried), so every later `sync` leaves the repo alone with "has uncommitted changes". Part 3 holds `--recursive` for new clones, but existing clones may already have submodules. The plan must state what part 2 does (for example: count a submodule line as local work only when the submodule has its own changes or commits, `S.M.`/`S..U`, not when only its checked-out commit differs, `SC..`; and report "submodules not updated"), and test it. Shallow clones: say in the design that the ancestry checks work on the fetched history and test one existing shallow clone through the follow row.
6. **[Worktrees] (needs-work)** — A branch checked out in a linked worktree cannot be switched to: tried, `git switch rolling` exits 128 ("already used by worktree at ..."). The move table defines failure of the second step only; the failure of `git switch V` itself has no row. Add it: left alone, reported with git's message, repo checked unchanged. Also say in the design what rebasing `V` in the main clone means for package worktrees branched from `V` (their base commits are rewritten under them; nothing is lost, but they diverge), and note that the url rule's `--branches` count is what keeps a worktree's unpushed branch safe.
7. **[Exit status] (needs-work, design consistency)** — The pending layer move (rung 0) should exit 1. The design's own rule is "whatever stops a repo from being put in place ... for any other repo it is an error, and the exit status is 1"; after rung 0 the repo is not at its place and `build` refuses that layer. Exit 0 is only for "a repo that is there and left as it is", which rung 0's repo is not at its new place. The other question (a repo left alone while the manifest names another version, rungs 13 and 14) is mechanism and the design's rule stands: exit 0, reported, `status` is the script-readable check.
8. **[Consequences, the lock] (needs-work, small)** — Taking the per-distro build lock for a distro's phase two is right, and passing it to `git` calls that change the tree is right (the same reason `build` passes it to colcon). Three gaps: (a) `note_lock_holders` writes "tool colcon" by position and `hold_build_lock`'s refusal reads the second pid as "its colcon (process N) still runs"; a `git` holding it for `sync` would be named colcon. Either do not note `git` children (the refusal then falls to the `fuser` text) or make the second slot's name follow the holder. (b) `git fetch`, `merge` and `rebase` may start `gc --auto`/`maintenance --auto` in the background, which inherits the descriptor and keeps the lock after `sync` ends, and runs a `gc`/`prune` the plan says is never run: run every call with `-c gc.auto=0 -c maintenance.auto=false`. (c) Say whether `init`'s first sync takes the lock (it calls `sync_distro`). Issue 510 asks for the general lock to land before part 2; the plan's reasoning for not waiting is sound, and the design should say this lock is the build lock reused, until 510.
9. **[Kill table] (note)** — A `SIGKILL` mid-`switch` or mid-`merge --ff-only` leaves incoming files in the tree that the next `sync` reports as "has uncommitted changes (n files)"; a person may commit them as their own. A `SIGKILL` mid-rebase reports "a rebase is in progress" without saying `sync` started it. Neither is repaired, which is right; record an intent line in `state.yaml` before each tree-changing call (repo, from-sha, to-sha) and, when the next run finds it, word the left-alone report as "a sync was stopped while moving this repo from <from> to <to>; `git status` shows what it left". Also the probe's refs are deleted "at the start of the next probe", which never comes once the url matches: delete them at every rung 7 instead.
10. **[Tags] (note)** — `git fetch --prune --tags origin` did not prune a local-only tag (tried), so no loss there. A tag moved on the remote fails the whole fetch, so a repo on a branch is reported as failed (exit 1) on every run until a person deletes the tag; say so in the report's next step.
11. **[Hooks] (note)** — `post-checkout` and `post-merge` hooks (git-lfs installs both) run on `switch` and `merge`; a failing `post-checkout` hook becomes `switch`'s exit status after the switch happened. Decide on the state checked afterwards (`HEAD`), not on the exit status alone, and test with a failing hook. A branch whose upstream is not `origin`: the plan follows `origin/V` regardless; say so in the design.
12. **[Split] (good)** — Nothing in part 3 is needed for part 2's rules to be correct or safe, given finding 5 (part 2 states its own behaviour for existing shallow and submodule clones rather than leaving it to part 3). One interaction to state: when the recorded manifest file is inside a clone that `sync` updates, phase one has already read the old text; the next `sync` reads the new one.
13. **[Part 1 marking] (note)** — "Its text below is the record of what was planned and built" is not exact: for example part 1's plan puts the clone's temporary directory in the layer's `src/`, while the merged `sync.py` (line 236) and the design put it in `.repos-manifest/`. Say "planned", and point to the design and pull request 512 for what was built.
14. **[Tests] (note)** — The tests use local remotes and need no network; `snapshot_repo` comparing every ref, the config, the index, the full status and every file is the right proof. Add ignored files and a linked worktree to the fixtures `snapshot_repo` runs on, so findings 1 and 6 are covered by the same comparison.

### Recommendation on the url rule (finding 2)

Record the url. `state.yaml` gains `url` per repo (`format` stays 1; a missing `url` is read as "not recorded"), written whenever the repo is recorded. Then, with `U` the manifest's url, `Ur` the recorded one and `W` the clone's raw `remote.origin.url`:

- `W == U`: nothing to do.
- `W == Ur != U`: the manifest changed the url, so the owner's answer applies: probe, repoint or leave alone exactly as the plan says.
- `W != U` and `W != Ur` (or no `Ur`): a person set `origin`. Leave it as it is, do not count the repo as left alone for that reason, go on with the ladder fetching from the person's `origin`, and report one line: `origin is <W>, the manifest says <U>; left as set (git -C <P> remote set-url origin <U> to use the manifest's)`. Record `url: U`, so a later change of the manifest's url is still told apart from the person's choice.
- Systems made before the record had the url (only the owner's, from part 1): no `Ur` is the third case, so `sync` never repoints a clone whose url it cannot account for; a clone whose `origin` equals the manifest's simply gets `url` recorded.

The design should also name `remote.origin.pushurl` (or `url.<base>.pushInsteadOf`) as the way to push over ssh while fetching from the manifest's url. If the plan keeps repointing without a record, that undoes a person's change and is a must-fix against the tool's principle.

### Summary

The ladder is careful and the owner's three answers are followed in form, and the per-repo record, put-back checks and whole-repo snapshot tests are the right shape. Five things can still lose or silently rewrite a person's work: ignored files overwritten (and deleted by the abort), the url rule undoing a person's `origin`, the rebase acting on other branches through the person's config, an upstream force-push replayed as local work, and the submodule state `sync` itself makes dirty; with the worktree row, the layer-move exit status and the lock's holder text, it needs one more revision before implementation.

### Recommended Actions

- [ ] Add the ignored/untracked path precheck before every tree-changing call; tests with an ignored file on the ff, switch, rebase and abort rows (finding 1); restate the owner's answer 1 mechanism in the design accordingly
- [ ] Record `url` in `state.yaml` and repoint only when the manifest's url changed since the record; a person's `origin` is left and the ladder goes on (finding 2)
- [ ] Rebase with `--no-update-refs`, `--no-autosquash`, without `--no-verify` (finding 3)
- [ ] Count local commits excluding the recorded commit's history; report a rewritten origin (finding 4)
- [ ] State and test part 2's behaviour for existing clones with submodules and shallow clones (finding 5)
- [ ] Add the row for a switch refused because the branch is in a linked worktree; say what a rebase of `V` means for worktrees (finding 6)
- [ ] Make the pending layer move exit 1; keep exit 0 for left-alone version mismatches (finding 7)
- [ ] Fix the lock holder's second-slot wording, disable auto gc/maintenance for `sync`'s git calls, say whether `init` takes the lock (finding 8)
- [ ] Notes 9 to 14 for the implementer: intent record for killed moves, probe-ref cleanup at every rung 7, the moved-tag next step, hooks judged by state, the manifest-in-a-clone ordering, the part 1 marking wording, fixtures with ignored files and a linked worktree

## Checkpoint
**Status**: complete
**When**: 2026-11-19 14:48 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work; the one point that changes scope was put to the owner and his answer is quoted below; the rest is mechanism)
**After**: plan
**Decision**: revise

Owner, 2026-11-19, asked whether the rebase of unpushed commits belongs in this pull request, with the reviewer's three findings on it shown (an ignored file overwritten and then deleted by the abort; the rebase running under the person's git settings; a force-pushed upstream replayed as local commits). His answer: "Later, its own part (Recommended)" (this pull request leaves a clone with unpushed commits alone and reports it, with the git pull --rebase command to run by hand; the rebase rule gets its own pull request with these three findings as its test list; the design keeps the rule and says it is not built yet).

Host decisions on the Plan Review's other findings. (1) No tree-changing call may overwrite a file git does not track, ignored files included: before a fast-forward or a switch, the paths the move adds are checked against the work tree, and a clone where one is in the way is left as it was and reported; the owner's first answer (untracked files do not count as local work) stands, and this is how "git itself refuses" is made true for ignored files too. (2) The url rule follows the reviewer's recommendation: state.yaml records each repo's url; origin is repointed only when the clone's origin equals the recorded url and the manifest now names another; an origin that differs from both, or a repo with no recorded url, was set by a person and is left as it is, the update goes on from it, one line gives the set-url command, and the manifest's url is recorded. So a system made before the record held urls is never repointed. The design names pushurl / pushInsteadOf as the way to push over ssh. (5) Existing clones with submodules and existing shallow clones get a stated, tested behaviour in this part. (6) A branch checked out in a linked worktree gets its own row: left alone and reported. (7) A pending layer move makes sync exit 1 for a non-optional repo, as the design's rule for a repo that cannot be put in place; a repo left alone while the manifest names another version stays exit 0. (8) The lock: the holder message does not call git "its colcon"; git runs with gc.auto=0 and maintenance.auto=false; the plan says whether init's first sync takes the lock; the design says this is the build lock reused until issue 510. Notes 9 to 14 go to the plan as written (an intent line in state.yaml for a kill mid-switch; probe refs deleted at every url check; success judged by the resulting state, not a hook's exit status; a moved remote tag reported as needing a person; the part 1 marking says "planned" and points to pull request 512). With the rebase rule out, findings 3 and 4 move to the later part with it and are listed there.

## Plan Authored
**Status**: complete
**When**: 2026-11-19 14:52 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-500/plan.md` at `6059fcd0`

Part 2 revised per the plan review and checkpoint: no rebase (later part 4, with its three findings as the test list); a paths check before every fast-forward and switch makes "git itself refuses" true for ignored files; the url is recorded and a person's origin is never repointed; stated and tested behaviour for submodules and shallow clones; a linked-worktree row; a pending layer move exits 1; the lock's holder wording, gc/maintenance off, init does not take the lock; notes 9 to 14 applied (a moving intent line, probe refs deleted at every url check, success judged by state, moved-tag next step).

## Plan Review
**Status**: complete
**When**: 2026-11-19 14:57 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #500 — repos-manifest: `init` and `sync` set up and update a system directory
**Plan**: `.agent/work-plans/issue-500/plan.md` at `6059fcd0`
**Branch**: `feature/issue-500`

Scope of this review: part 2 as revised ("Part 2: `sync` against clones that exist"), second review. Each finding and note of the first part-2 review was checked against the checkpoint's decisions, then part 2 was read whole and the doubtful rules were tried with git 2.53.0 on local repositories in the session scratchpad (script `t1.sh`, seven cases; results quoted below).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One pull request (about 490 lines of code, 900 of tests, 120 of docs); dropping the rebase made it smaller and simpler; parts 3 and 4 are named with their reasons |
| Issue alignment | Good | The owner's four answers are quoted and followed: untracked files do not block (rung 8), the paths check makes "git itself refuses" true for ignored files, the url rule repoints only a manifest change, a layer move is reported with the `mv` command, unpushed commits are left alone with the `git pull --rebase` command. The issue comment's acceptance case is rung 13's tests |
| File targeting | Good | `update.py` new, `sync.py`, `system.py`, `init.py`, tests, docs; `build.py` unchanged is right |
| Consequences | Good | `state.yaml` keys `url` and `moving` with `format: 1` kept; lock wording; build hint; part 1 tests that change are found by grep and named |
| Principle alignment | Good | "Never discard work": every rung that changes the tree has a check before and a state check after, and the whole-repo snapshot comparison is the proof; two precision notes on the paths check (1, 2 below) |
| ADR compliance | Good | ADR-0017 (design in the same change), ADR-0022 (Serves cites the part's design), ADR-0013 |
| ROS conventions | N/A | Workspace tool |

**Serves** (as checked): Goal "one system directory set up and kept in line from one manifest", under `tools/repos-manifest/docs/design.md#the-system-directory`, `#setting-up-with-init`, `#refusals` and `#sync`, and root `docs/manifest/design.md`. All four anchors exist in the tool's design on this branch; the work serves them and breaks no stated rule.

### The first review's findings, as the checkpoint decided

| # | Decision | In the revised plan |
|---|---|---|
| 1 Ignored files | Paths check before every fast-forward and switch | Done ("The paths check"), with ignored and untracked tests on each tree-changing row; see notes 1 and 2 for two cases its wording leaves open |
| 2 Url rule | Record the url; repoint only a manifest change | Done, as recommended, with the owner's real system (no recorded url) never repointed |
| 3, 4 Rebase config, force-push | Moved to part 4 with the rebase | Listed as part 4's test list; the force-pushed case is left alone here (rung 11) |
| 5 Submodules, shallow | Stated and tested | Done; tried again: `SC..` after a pointer move, shallow follow |
| 6 Linked worktree | Its own row | Done, before `git switch` is called |
| 7 Layer move | Exit 1 for a non-optional repo | Done; left-alone version mismatches stay exit 0 |
| 8 Lock | Wording, gc/maintenance off, init said | Done; see note 5 on the reason given for `init` |
| Notes 9 to 14 | To the plan | All applied (moving line, probe refs at every rung 7, state-judged success, moved-tag next step, manifest-in-a-clone ordering, part 1 marking, fixtures) |

### What was run with real git (git 2.53.0, local bare remotes, no network)

- T1: a tracked directory `foo/` with an ignored `foo/keep.log`; upstream replaces the directory with a file `foo`. `merge --ff-only` exits 0 and `keep.log` is gone. `git diff --diff-filter=A H O` lists `foo`; `git ls-files` lists `foo/a`, not `foo`.
- T1b: the same with an untracked, not ignored file: git refuses ("would lose untracked files"), file kept.
- T2: an ignored symlink `lnk -> ../elsewhere` where upstream adds `lnk/new`: `os.path.isdir('lnk')` is True; `merge --ff-only` exits 0 and replaces the link with a directory (the target is untouched).
- T3: `submodule.recurse=true`, a person's commit on the submodule's detached `HEAD`, superproject fast-forward moving the pointer: exit 0, the submodule stays on the person's commit (no loss).
- T4: `fetch.pruneTags=true` in config: `git fetch --prune --tags origin` deletes a local-only tag; with `--no-prune-tags` it is kept.
- T5: a `--depth 1` clone, `fetch --prune --tags origin` with a tag on old history: the tag and the whole history behind it are fetched; `.git/shallow` keeps one line.
- T6: `HEAD` on origin through another branch (`origin/keep`) while `origin/main` was force-pushed to another line: the count of commits not on origin is 0, `HEAD` is not an ancestor of `O`; `merge --ff-only` exits 128 and changes nothing.
- T7: `-c gc.auto=0 -c maintenance.auto=false` reach git's children through `GIT_CONFIG_PARAMETERS`.

### Findings

None at needs-work. Notes for the implementer:

1. **[Paths check, directory replaced by a file] (note, implement and test exactly)** — For an added path that is a directory in the work tree (T1), the plan's words "a hit that is not a tracked path of `H`" read literally refuse every such move, even a directory holding only tracked files, forever and with a wrong message ("not tracked"). The obvious repair, treating a directory with tracked files as tracked, loses ignored files inside it (T1: `merge --ff-only` exit 0, `keep.log` deleted). The rule to build: an added path that is a directory in the work tree is in the way when it holds any file not tracked in `H` (untracked or ignored; `git ls-files -z --others -- <dir>` together with `--others --ignored --exclude-standard`, or a walk compared with `ls-files`), and not otherwise. Add the T1 case, with an ignored file and with only tracked files, to the ignored-file tests; the listed "parent directory is a file" test is the reverse case.
2. **[Paths check, symlinks] (note)** — "for a parent, is not a directory" must be judged with `lstat` (`stat.S_ISDIR(os.lstat(p).st_mode)`), not `os.path.isdir`, which follows links: an ignored symlink where an incoming directory goes is otherwise replaced silently (T2). One test.
3. **[Rung 12, missing row] (note)** — `HEAD` on origin (count 0) but not an ancestor of `O` happens when origin's `V` was rewound or rewritten and `HEAD` survives on another origin branch (T6). The plan's table has no row and says ahead and diverged "end at rung 11", which is not so here. `merge --ff-only` refuses and changes nothing, so it is safe through the backstop, but give it a row: left alone, `origin's <V> no longer contains this commit (rewritten upstream); left alone`, without calling `merge`.
4. **[Url rule, tests and comparison] (note)** — Rung 7's test column says "the url tests below" and none are listed. Name them: the three cases with a recorded url; no recorded url and `origin` differing (the owner's system: never repointed); `url.*.insteadOf` in config (raw value compared, probe fetched through the rewrite); a probe that finds unpushed local branches; a probe fetch failure; probe refs left by a kill removed at the next run. A trailing `.git` or `/` difference reads as "differs": safe (left as set), but printed every run for a clone that is in fact on the manifest's repo; compare after stripping one trailing `/` and `.git`, which can only move a case to "nothing to do" or to a probe-guarded repoint.
5. **[Lock, `init`] (note, keep the design true)** — The plan's reason for `init` not taking the lock, "`init` refuses when a system exists, so no `build` of that distro can", is false: `make_system_dir` renames `.repos-manifest/` in and only then calls `sync_distros` (`init.py:268-270`), so a `build` or a `sync` started meanwhile sees a system. No person's work is at risk (the system is empty, part 1's rename handles the clone race), but the reason must not go into the design. Simplest: `init` takes the lock too (it is never held there), which removes the `lock` argument; otherwise write the true reason.
6. **[Fetch under the person's config] (note)** — With `fetch.pruneTags=true` (or a tag refspec on `origin`), `sync`'s `fetch --prune --tags` deletes local-only tags (T4). The person asked for that on every fetch, so it is not a loss `sync` adds, but `--no-prune-tags` keeps `sync` from deleting anything; and pass `-c submodule.recurse=false` so the report's "submodules not updated" stays true whatever the person's config (T3 showed no loss, but a clean submodule would be moved).
7. **[Shallow clones] (note, design wording)** — "never deepens or un-shallows" is true of the shallow boundary, but `fetch --tags` brings every tag's history (T5), so a shallow clone of a repo with release tags grows to near its full size at the first `sync`. Say so in the design; whether to fetch tags at all for a shallow clone can be part 3's.
8. **[Rung 11 advice] (note)** — `git -C <P> pull --rebase` uses the branch's own upstream, which may be another remote or none. Print `git -C <P> pull --rebase origin <V>`.
9. **[Rung 10 with a person's origin] (note)** — When a person set `origin` (url case 3) to a fork that lacks `V`, rung 10 fails every run saying "another sync will not change that"; the message should add that `origin` is set by hand and give the `set-url` command. A fork whose `V` descends from `HEAD` is fast-forwarded from the fork, which the per-run url line makes visible; the design should say that the update follows the person's `origin`.
10. **[Tag lookup] (note)** — Rung 10 accepts `refs/tags/V` as "on origin", but a local tag made by a person, absent from origin, also satisfies it, and `sync` would switch to the person's tag. Check the tag on origin (`ls-remote --tags` from the fetch, or fetch tags into a reserved namespace) or say in the design that a local tag of the same name is used.
11. **[`moving` line] (note)** — The line is cleared only when a later `sync` finds the repo on `V`. If a person moves the repo by hand after a kill (rung 14), the line stays and a later dirty state is worded "a sync was stopped while moving" when it was not; clear it, or word from it only when `HEAD` is the line's `from` or `to`. It never makes `sync` change a repo (it changes wording only), which was the safety question; rung 8's row should name the wording as rung 5's does.

The design-document list keeps the field-machine paragraph and says the rebase rule is not built (design `docs/design.md` lines 676-681 are the paragraph that changes); the test plan's whole-repo snapshot comparison would fail without each tree-guarding rule, given notes 1 and 4.

### Summary

The revision resolves every finding as the checkpoint decided and follows the owner's four answers. Nothing in the ladder as written loses or silently changes a person's work; the two places the paths check's wording could be built unsafely (a directory replaced by a file, an ignored symlink) are notes 1 and 2, each with the exact rule and a test. Ready for implementation.

### Recommended Actions

- [ ] Build the paths check's directory and symlink cases as notes 1 and 2 say, with tests
- [ ] Add rung 12's row for a rewritten origin branch (note 3)
- [ ] Name and write the url tests; normalise trailing `/` and `.git` (note 4)
- [ ] Take the lock in `init` too, or give the true reason (note 5)
- [ ] `--no-prune-tags`, `-c submodule.recurse=false` (note 6); notes 7 to 11 in wording and design

## Checkpoint
**Status**: complete
**When**: 2026-11-19 14:58 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second review of part 2: ready, eleven notes for the implementer, none needs-work; the plan is unchanged since that review and part 2 is not delivered)
**After**: plan
**Decision**: proceed

The eleven notes of the Plan Review go to the implementer in the handoff and are to be built as the review states them, each with its test: (1) a directory replaced by a file is in the way only when it holds a file not tracked in HEAD; (2) the paths check uses lstat, so a symlink is never taken for a directory; (3) a row for a rewritten upstream where HEAD is on origin but not an ancestor of origin/V: left alone, reported; (4) the url rule's tests are named, the no-recorded-url case and url.*.insteadOf included, and urls are compared after stripping a trailing slash and .git; (5) init takes the lock for its first sync too, and the false reason is not written into the design; (6) fetch passes --no-prune-tags and git runs with submodule.recurse=false; (7) the design says a shallow clone grows when tags are fetched; (8) the unpushed-commits report prints git -C <path> pull --rebase origin <version>; (9) a hand-set origin that lacks the version gets a message saying origin was set by hand, with the set-url command; (10) a tag counts as on origin only when origin has it; (11) the moving line's wording at the uncommitted-changes row.

## Implementation
**Status**: complete
**When**: 2026-11-19 15:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-500 at `5f8130f0`
**Commits**: 62113648, 0823eea3, 9bfd59d0, 5f8130f0

Part 2 of the plan: `repos-manifest sync` updates clones that are there. All of (a) to (i) are done: (a) `snapshot_repo` and the fixtures (an ignored file, a linked work tree); (b) the read-only rules; (c) fetch and fast-forward with the paths check; (d) the move to another version; (e) the url record and rule; (f) the layer, no-record, not-in-manifest, not-a-repo and work-tree rows; (g) per-distro reports, exit status, the lock, the built-layer note; (h) the `moving` line and the kill table; (i) the documents.

### What was built
- `src/repos_manifest/update.py` (new): `update_repo`, the rules in order (type, a repository of its own, an operation in progress or `index.lock`, one `origin`, the url rule, tracked changes, fetch, the version on origin, commits not on origin, on the version, on the recorded version, moved by a person); `in_the_way`, the paths check; `_change`, every call that changes the tree, with the `moving` line before it, the state read after it, and the undo of a failed second step; `_repoint`, the url probe. Every `git` runs with `--no-optional-locks -c gc.auto=0 -c maintenance.auto=false -c advice.detachedHead=false -c submodule.recurse=false`; a call that changes the tree or the config runs with the stop signals held (checked: the child inherits them held) and the lock passed (`pass_fds`). `NEVER` lists the forbidden words, and `test_update_safety.py` scans the module's argument lists for them.
- `sync.py`: phase one per distro (`Reported`); the distro's build lock held for its phase two (`hold_build_lock(..., holder="sync")`), a held lock reports that distro and the others go on; present repos go to `update_repo` after the place checks; the layer rule with the `mv` command; repos that left the manifest listed and kept (record dropped when the directory is gone); the built-layer note and the manifest-in-a-moved-clone note; the per-distro report (cloned, updated, left alone, failed, optional skipped, up to date, no longer in the manifest).
- `system.py` (issue 531 is in this file too; the functions touched are only these): `RepoRecord` gains `url` and `moving`; `_read_state_data` allows and checks them; `read_state`; `_record_data` (new); `put_distro_state`; `hold_build_lock` takes `holder` and names the holder it reads from the lock file; `note_lock_holders` writes `sync <pid>` for a sync (a build's file is unchanged: pids only). `build.py`, `read_built` and `put_built_layers` are untouched.
- `init.py`: the three suggestions of 512's last review (the "still running" warning only for what init leaves and a pid that can name a process; the head-comment refusal ends "nothing was set up"; the output error names the recorded path is in `sync.resolve_all`). `init` takes the lock for its first sync (note 5): `sync_distros` always takes it.
- The eleven notes of the last plan review, each with its test: (1) a directory replaced by a file is in the way only when it holds a file not tracked in `HEAD` (`test_a_directory_replaced_by_a_file_holding_an_ignored_file_stops_it`, `..._holding_only_tracked_files_is_followed`); (2) `lstat` (`test_an_ignored_link_where_an_incoming_directory_goes_is_never_taken_for_one`); (3) `test_a_branch_rewound_upstream_while_head_is_on_another_origin_branch`; (4) the url tests in `test_update.py` (repoint, local commits not on it, new url not fetchable, origin set by hand, no recorded url, trailing `/` and `.git`, `insteadOf`, probe refs left by a kill, version missing from a hand-set origin); (5) `test_init_takes_the_lock_for_its_first_sync`; (6) `--no-prune-tags` (`test_a_local_only_tag_is_kept_by_the_fetch`, with `fetch.pruneTags=true`) and `submodule.recurse=false`; (7) design text on shallow clones; (8) `git -C <path> pull --rebase origin <version>`; (9) the hand-set-origin message; (10) a tag counts only when `git ls-remote --tags origin refs/tags/<V>` lists it (`test_a_local_tag_absent_from_origin_is_not_taken_as_the_version`); (11) the `moving` line words rung 5 and 8 only when `HEAD` is its `from` or `to`.
- Tests: `test_update.py` (63), `test_update_safety.py` (32: the forbidden-words scan, and the paths check on the fast-forward, a switch to a new branch, a switch to a local branch then fast-forward, and a detached switch to a tag, each with an ignored and an untracked file and with a file where an incoming directory goes, each `snapshot_repo(fetched=True)` equal), `test_sync_distros.py` (15: per-distro reports, the lock both ways, the build note, the manifest in a moved clone, a stub `git` for SIGKILL before a fetch and after a merge or switch, SIGTERM during a merge or switch, and a failing second step undone), two `vcs` behaviours in `test_vcs_behaviours.py` (pass on vcstool 0.3.0), an init sweep test. Part 1 tests changed for the new behaviour are named in commit 62113648; `test_build.py::test_the_install_note_names_removed_and_added_repos` now moves its repo by hand (5f8130f0).
- Documents: the tool's `docs/design.md` ("sync": the rules in order, the paths check and why, the url rule with `pushurl` / `pushInsteadOf`, the lock, the build note, submodules and shallow clones, the stop and kill table; "Where the resolved files and state go": `url` and `moving`, the lock; "Where repos are fetched from"; "Work done on a field machine" keeps its paragraph and says the rebase is not built; "build": the lock shared with sync; "What is built"; the layer question left "Open questions"), `README.md`, `docs/roadmap.md` (the init/sync line gets the check `file-exists src/repos_manifest/update.py`), and the workspace's `docs/manifest/design.md` (two sentences that said the tool's sync leaves a clone that is there as it is). Each design sentence was checked against the code after it was written.

### Departures from the plan
- A place that is a link to a directory is left alone ("is a link to <target>; sync does not update a repo through a link"), exit 0; the plan did not name the case, and updating through the link would change a repo outside the system.
- Rung 11's `pull --rebase` line is printed when origin's tip is not an ancestor of `HEAD` (origin has commits `HEAD` lacks). The plan wrote `merge-base --is-ancestor HEAD O` false, which is true whenever `HEAD` has unpushed commits.
- The moved-tag next step is chosen by matching git's `[rejected] ... (would clobber existing tag)` line on the failed fetch. It changes only the wording of a failure; nothing else reads git's messages.
- A version given as a commit counts when the object is there (7 to 40 hex digits); it is not checked to be reachable from an `origin` ref.
- For a recorded version that names none, "on the recorded version" means on the branch `origin/HEAD` points to now.
- A flat system whose manifest gained distros is now reported for that distro (exit 1) like the other per-distro reports, not a whole-run error; the manifest file that cannot be read stays a whole-run error.
- The plan said the workspace's `docs/manifest/design.md` does not change; two of its sentences became false (the tool's sync "leaves a repo that is there as it is", "that part of sync is not built yet"), so they were corrected, and its exit-status line names a reported distro.
- `docs/roadmap.md`'s Direction section holds no status, so parts 3 and 4 are not named there; the line got a check instead. The workspace's `docs/manifest/roadmap.md` has no row that changes.
- The kill tests kill `sync` before a fetch and right after a merge or a switch (a stub `git`); a kill in the middle of git's own tree write is not reproduced. The wording it leads to is tested with a hand-written `moving` line and a changed tree.

### Checks
- Whole suite at `5f8130f0`: `cd tools/repos-manifest && REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest -p no:cacheprovider`: 1268 passed in 312.52s (vcs from /usr/bin/vcs, vcstool 0.3.0).
- The signal and kill tests of `test_sync_distros.py` and the vcs tests, three runs in a row: 13 passed each time.
- `bash .agent/scripts/check_design_anchors.sh`: exit 0. black and flake8 ran in the commit hooks.
- No workspace script changed, so no `.agent/scripts/tests/` suite was run; the full pre-commit pass is left to the host. Commits made with `SKIP=validate-script-tests`.

### By hand, in a scratch system (local file remotes; `init ../m.manifest.yaml --distro rolling --yes`, three repos on main)
1. The pin of `core_a` changed in the manifest from main to dev, then `sync`: `core/src/core_a: moved from main to dev`, `updated (1): core/src/core_a`, `up to date (2)`, exit 0; branch `dev`; `state.yaml` for core_a: `version: dev`, the new commit, `url: <S>/remotes/core_a`. `sync` again: `up to date (3)`, exit 0. This is the issue's 2026-11-19 case.
2. `origin` of `core_b` set by hand to another bare copy, then `sync`: `core/src/core_b: origin is <S>/remotes/core_b-mine.git, the manifest says <S>/remotes/core_b; left as set (to use the manifest's: git -C <S>/sys/core/src/core_b remote set-url origin <S>/remotes/core_b)`, `up to date (3)`, exit 0; origin unchanged. The line comes again on the next run.
3. A local commit in `core_c` and a commit upstream, then `sync`: `core/src/core_c: left alone: has 1 commits not on origin; to bring origin's in by hand: git -C <S>/sys/core/src/core_c pull --rebase origin main`, `left alone (1): core/src/core_c`, exit 0; `HEAD` unchanged, status clean.
(`<S>` is the scratch directory; the script is the session scratchpad's `byhand.sh`.)

### By-hand acceptance for the owner
Not run by this pass. With the tool installed from this branch into `~/p11-venv`, in `~/project11` (or wherever his system is), with the repo of his own pin change in place of `<repo>` and its layer in place of `<layer>`:

```bash
cd ~/project11
git -C rolling/<layer>/src/<repo> status --short; git -C rolling/<layer>/src/<repo> log --oneline -1   # before
~/p11-venv/bin/repos-manifest sync --distro rolling
git -C rolling/<layer>/src/<repo> status --short; git -C rolling/<layer>/src/<repo> branch --show-current
grep -A6 '<repo>:' .repos-manifest/state.yaml    # version, commit and url are the new ones
~/p11-venv/bin/repos-manifest sync --distro rolling     # again: "up to date", nothing changes
```

His clones whose `origin` is ssh while the manifest says https are left as set, with one line each per run; this system's record has no urls yet, so none of them is repointed. For the safety rows, on a throw-away system made the same way in `~/p11-test` (never the real one): a changed tracked file (left alone, "has uncommitted changes"), a local commit (left alone, with the `git pull --rebase origin <branch>` command), a repo switched by hand to another branch (left alone, "moved by a person"), an `origin` set by hand (left as set, one line), an ignored file where an incoming file arrives (left alone, the path named with "(ignored)"); after each, `sync` then `git status` and `git log -1` compared with before.

### For the pull request body
- `sync` now updates each repo that is there, after the place checks, by rules checked in order. A clean clone on the manifest's branch is fast-forwarded; one on the version `sync` last recorded, when the manifest names another, is switched to it (a new tracking branch, a local branch fast-forwarded, or detached at a tag or commit); a clone pinned to a tag or commit stays. `state.yaml` records the new version, commit and url.
- Left as it is and reported, with the repo unchanged: tracked changes (also assume-unchanged and skip-worktree files, and changed files inside a submodule); commits not on `origin` (with the `git pull --rebase origin <branch>` command), including after an upstream force-push; another branch or a detached `HEAD` elsewhere; a rebase, merge, cherry-pick, revert, bisect or `index.lock`; no single `origin`; not a repository of its own; a link at the repo's place; a local branch of the new version with commits not on origin, or checked out in another work tree; a branch rewritten upstream; and any untracked or ignored file where an incoming file goes. Untracked files elsewhere do not stop an update.
- `origin`: repointed only when it still has the url `sync` recorded and the manifest names a new one, and only when every local branch is on the new url; an `origin` set by hand is left as set with one line per run. A system made before this change has no recorded urls, so nothing in it is repointed.
- A repo the manifest gives another layer is not moved: `sync` prints the `mkdir -p ... && mv ...` command and exits 1 (an optional repo is skipped). A repo no longer in the manifest is listed and left on disk.
- Per distro: a distro that does not resolve, or whose lock a `build` holds, is reported and the others go on (exit 1). `sync` and `init` hold the distro's build lock while they write its resolved files and update its repos; a build refused by a sync says "a sync of distro <d> is still running". A built layer whose repos changed gets a line saying `build` brings it up to date.
- Never run by `sync`: `reset`, `checkout -f`, `clean`, `stash`, `rebase`, `pull`, `push`, `gc`, `prune`, branch deletion, `--force`, `--no-verify` (a test scans `update.py`). Success is judged by the repo's state after each git call.
- Left for part 3: step 1 of the design's `sync` (the manifest's own clone and `local_manifest`, `--local-manifest`) and arguments after `--`. Left for part 4: the rebase of unpushed commits, with the three findings of the first part-2 plan review as its test list.
- Open on purpose: a repo left alone while the manifest names another version exits 0 (`status`, issue 502, is the script-readable check); the hand-set-origin line prints on every run; submodules are never updated (the report gives `git submodule update`); a shallow clone grows by the history of the tags the fetch brings.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 15:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-500 at `4fa6356c`
**Base**: origin/main
**Depth**: Deep (reason: about 3,600 lines over 22 files; safety-critical git operations on a person's clones)
**Must-fix**: 6 | **Suggestions**: 10
**Round**: 1 | **Ship**: continue — round 1: 6 must-fix; first round always re-reviews after fixes

Part 2 (sync on clones that are there). Whole suite at 4fa6356c: 1268 passed in 311s (`REPOS_MANIFEST_REQUIRE_COLCON=1`). Six mutations of update.py (paths check off, ahead check off, directory walk off, stat for lstat, repoint with no recorded url, tracked-changes check off) each fail 1 to 15 tests, so the snapshot comparison catches them. The owner's four answers are followed. Scratch systems (local file remotes, session scratchpad): ignored and untracked files, ignored directories, links, a directory replaced by a file, version moves, local commits, a detached HEAD, staged/intent-to-add/rm --cached, url rule, layers, shallow clones, hooks, signals and kills, and the lock all held, except the findings below. Cross-model: gemini and codex both completed.

### Findings
- [x] (must-fix) A submodule that an incoming commit replaces with a file or a link is deleted with its work tree; when its `.git` is a directory, the submodule's unpushed commits are deleted too. Exit 0, "updated". `in_the_way` checks only `--diff-filter=A` and skips paths tracked in HEAD (a gitlink is), and `tracked_changes` does not count a submodule on another commit. Reproduced: submodule `sub` cloned in place, a commit on branch `mywork` inside it, upstream replaces `sub` with a file; after sync `sub` is a file and the commit is gone. A submodule replaced by a directory also writes upstream files into the person's submodule. Check every gitlink of HEAD that is not the same gitlink in the target and leave the repo alone when its directory holds anything — `update.py:207-263`, `update.py:190`
- [x] (must-fix) A moved tag can never be followed. sync tells the person to `git tag -d <tag>` and sync again, but the next sync finds HEAD detached at the recorded commit with the version unchanged, and reports "moved by a person" on every later run. Reproduced: pin v1, move v1 on origin, follow the message; runs 2 and 3 exit 0 "left alone: moved by a person". The design's rule 7 implies this works — `update.py:500-507`, `update.py:550-565`
- [x] (must-fix) A local-only tag with the same name as the pinned branch fails the repo with "version dev is both a branch and a tag" (exit 1). The ambiguity check runs before the `ls-remote` check. The design's rule 8 says that a local tag origin lacks does not count. Reproduced with `git tag dev` in the clone and the pin set to `dev` — `update.py:355-358`
- [x] (must-fix) A two-step move (switch to a local branch, then fast-forward) whose `post-checkout` hook fails is an ERROR, exit 1, "another sync will not change that". The switch did happen, and the next sync completes it. The design says that a move with a failing hook counts. Reproduced: main→dev with a local dev behind origin/dev, hook `exit 1`. Judge step 1 by its state (HEAD on the local branch), not by its exit status — `update.py:630-642`
- [x] (must-fix) Design, sync: "Nothing in the repo changes before a fast-forward or a switch, except the remote-tracking refs and objects a fetch brings". The fetch also creates local tags (`--tags`). Name them — `tools/repos-manifest/docs/design.md` (sync, after the field-machine bullet list)
- [x] (must-fix) The record keeps the old layer after a person runs the printed `mv` and the repo is then left alone (for example, local commits). The design says "moved there by hand, it is handled there and its record names the new layer". `left()` should record the layer, as it records the url. Reproduced by the adversarial subagent (scratch case 2a) — `update.py:416-422`
- [x] (suggestion) Pass `--no-overwrite-ignore` to every `merge` and `switch`, including the undo, so git itself refuses an ignored file created between the paths check and the call. The race was reproduced with a wrapper that writes `build.log` just before the merge — `update.py:547,586,591,598,600,639-641`
- [x] (suggestion) A stale `moving` line hides the real reason ("a sync was stopped…" instead of "has uncommitted changes") after a hand reset to the `from` commit plus an edit, and `left()` never clears it. A record made by `_change` for a repo with no record is not removed on a clean failure either — `update.py:453-457`, `update.py:416-422`, `update.py:645-646`
- [x] (suggestion) Departure 4 (a commit counts when the object is there): a pin to a commit that exists only locally was followed (detached there), and the report did not say it is not on origin. Check that it is reachable from an origin ref or tag, with a stated rule for shallow clones — `update.py:371-374`
- [x] (suggestion) Departure 5 (origin/HEAD read as it is cached): when origin's default branch changes, the clone stays on the old branch, and a pin change is reported as "moved by a person". Say so in the design or record the branch used — `update.py:339-354`, `update.py:568-577`
- [x] (suggestion) The fetch runs with the person's `remote.origin.fetch`. A forced refspec into `refs/heads/*` would move local branches before any check. Fetch with an explicit `+refs/heads/*:refs/remotes/origin/*` refspec — `update.py:496-498`
- [x] (suggestion) After a repoint, if the fetch or the version lookup fails, the new url is not recorded. A later url change is then read as an origin set by hand (safe, but repointing stops) — `update.py:478-481`, `update.py:508-515`
- [x] (suggestion) A clean sparse checkout is always left as "has uncommitted changes (n files)", because skip-worktree entries are counted. Word it, or tell sparse entries apart — `update.py:192-197`
- [x] (suggestion) Urls are printed raw in the by-hand and repoint lines, including any `user:token@` — `update.py:483-486`, `update.py:696-715`
- [x] (suggestion) A disk failure writing one distro's resolved files ends the whole run (only `Refusal` is caught per distro). The design's "cannot be written out" means building the text; make that clear or catch it — `sync.py:611-616`
- [x] (suggestion) `git merge-tree` of this branch with `feature/issue-531` conflicts in `tools/repos-manifest/README.md` (the build paragraph). Code files merge cleanly, and the only build-side file this branch touches is the stated `tests/test_build.py` change — `tools/repos-manifest/README.md:124-127` (deferred: the host resolves the README conflict with issue 531's branch at merge, as the handoff says; this pass left it)

## Implementation
**Status**: complete
**When**: 2026-11-19 16:30 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-500 at `a342fc56`
**Addressed**: Local Review (Pre-Push) at `4fa6356c` (2026-11-19 15:48 -05:00)
**Commits**: dcbf4ec8, bd216203, fd3a0183, 8a24293d, 119fedcf, 1276ef9f, 4642805f, 535c803b, 34e7587f, da9d44b2, d07d6dd5, ca0dbc92, 1b98d10c, c236b3fc, 566dca05, 820c8769, 13a7327f, f5114a5c, 238134d9, a342fc56 (box checks)

Every finding was reproduced first: the reviewer's `probe2.py` (moved tag, local tag `dev`, two-step hook) and `probe3.py` (submodule replaced by a file, its unpushed commit lost) all failed as described at `5619a7a3`; after the fixes the same probes show the tag followed, `dev` moved to, the two-step move counted, and the submodule left with `mine.txt` there. Each code fix has a test that fails with the fix taken out (checked by reverting the source diff and running the new tests), comparing the whole repo with `snapshot_repo`, which now also covers each nested repository's HEAD, branch, refs, config and status.

### Actions
- [x] (must-fix 1) Submodules: before every fast-forward or switch, each gitlink of HEAD is compared with the same path in every target; a populated submodule the move removes or replaces (file, link, directory), or one whose pointer changes while its own HEAD is not the recorded commit (or that is not a repository of its own), leaves the repo as it was, named, "has to be dealt with by hand". Not-checked-out submodules and untracked files in a submodule whose pointer moves are no obstacle (git does not touch its work tree); a file or directory turned into a submodule goes through the paths check. `tests/test_update_submodules.py` (28 cases; 21 fail without the fix) — `update.py` `submodules_in_the_way`, `_change`
- [x] (must-fix 2) A tag moved on origin is followed after `git tag -d`: detached at the commit recorded for the tag the manifest still names, origin's tag elsewhere, the repo is switched there; never a tag force-update. Whole sequence tested (pin, move, report, `tag -d`, follow, up to date) and a repo moved off the tag by a person stays left — `update.py` update_repo, `_move`
- [x] (must-fix 3) A local tag counts only when origin has the same object, asked before the both-a-branch-and-a-tag check; both directions tested (local tag `dev` with a branch pin; local branch `v1` with a tag pin) — `update.py` `find_version`
- [x] (must-fix 4) Each step of a move is judged by the state it leaves (HEAD on that step's commit and branch, no tracked changes); a failing `post-checkout` on the switch of a two-step move is a note and the fast-forward follows. Tested — `update.py` `_change`
- [x] (must-fix 5) Design: the fetch brings origin's remote-tracking refs (and prunes gone ones), objects, local tags origin has and the clone lacks, and `FETCH_HEAD`; no local branch, HEAD, index or work-tree file changes before a move — `docs/design.md` sync
- [x] (must-fix 6) A repo moved by hand to its new layer has the layer recorded before the rules run, so whether followed or left (local commit, changed file, index.lock: tested) — `sync.py` `present_repo`
- [x] (suggestion) `--no-overwrite-ignore` on every merge and switch, the undo included; git 2.53.0 accepts it for both `merge` and `switch` (`-h` lists `--[no-]overwrite-ignore`). Race test with a stub git writing an ignored file just before the call, for the merge and the switch — `update.py`, `tests/test_sync_distros.py`
- [x] (suggestion) The moving line is added to the reason (uncommitted changes, operation in progress, index.lock), never in its place; a sync that finds HEAD on neither commit removes it; a clean failed fast-forward of a repo with no record writes a record without it — `update.py`
- [x] (suggestion) A commit pin is followed only when reachable, in the clone's history, from an origin branch or a tag origin has (same object); otherwise left alone and reported (exit 0). Shallow rule stated in the design — `update.py` `commit_on_origin`
- [x] (suggestion) Design states the default branch is origin/HEAD as the clone records it (the fetch does not move it; tested), what happens when origin's default changes, and the deleted-branch error now gives the `set-head` command — `docs/design.md`, `update.py`
- [x] (suggestion) Fetch with `--refmap= origin +refs/heads/*:refs/remotes/origin/*`; tested with `remote.origin.fetch=+refs/heads/*:refs/heads/*` (without the fix the person's `dev` was overwritten and `feature` pruned). Neighbour, own commit: the url probe also passes its refspec and `--refmap=` — `update.py`
- [x] (suggestion) The url is recorded right after a repoint, before the fetch; tested with a version that then fails — `update.py`
- [x] (suggestion) A sparse checkout (`core.sparseCheckout`) is left alone with a message saying so, cone and non-cone tested — `update.py`
- [x] (suggestion) Credentials: `mask_urls` masks `scheme://userinfo@` in every repo line `sync` prints (its words and git's), keeping an ssh user name alone; the `set-url` command for a masked url says to use the repo's url as the manifest gives it — `update.py`, `sync.py` `_say`
- [x] (suggestion) A failure putting one distro's resolved files on the disk is a `Refusal` for that distro; its repos are untouched, the others go on. Three part-1 tests in `test_sync.py` changed with it (238134d9) — `sync.py` `_sync_distro`
- [x] (suggestion) README conflict with issue 531's branch — `README.md:124-127` (deferred: the host resolves it at merge, as the handoff says; this pass changed README lines 108-118 only, not the build paragraph)

### Departures
- Must-fix 1, pointer moves: a submodule left on its old commit by an earlier `sync` (which never updates submodules) stops the next pointer move until a person updates it. That is the safe reading of "own HEAD is not the commit the superproject records": the two cases cannot be told apart, and sync's own `git submodule update` advice would otherwise move a person's detached commit away.
- Must-fix 1, tracked changes or untracked files in a submodule: tracked changes already leave the repo (`tracked_changes`); untracked files block only when the move removes or replaces the submodule (it is populated). A pointer move leaves the submodule's work tree as it is (`submodule.recurse=false`), so its untracked files do not block one; tested.
- Added beyond the list, found trying neighbours: the fetch passes `--no-recurse-submodules` (13a7327f). `-c submodule.recurse=false` already kept it out of submodules even with `fetch.recurseSubmodules=true`; the test fails only with both removed, so it guards existing behaviour and makes it independent of config order.
- Suggestion 8 leaves the repo alone (exit 0), not an error, as the handoff says.
- Masking keeps an ssh url's bare user name (`ssh://git@host`) and masks any other user name, since an https one is often a token.
- The "tag here is not origin's tag" branch of must-fix 3 is a guard for a tag that changed on origin between the fetch and the lookup; it has no test (the fetch refuses the clobber first).

### Tried by hand (scratch, `fx/neigh.py`, `fx/recurse.py`, `fx/refmap.sh` in the session scratchpad)
- A submodule at `lib/sm` whose parent `lib` becomes a file: left alone, repo unchanged.
- A submodule place that is a link to a person's clone with its own commit, pointer moved: left alone ("`git status` fails here"), unchanged.
- An annotated tag moved on origin: run 1 exit 1; after `tag -d`, followed to the new commit; again up to date.
- A directory with an ignored file replaced by a file: the paths check leaves it; git alone with `merge --ff-only --no-overwrite-ignore` also refuses (exit 1, file kept).
- An origin `https://alice:s3cret@127.0.0.1:9/x.git` (unreachable): neither the name nor the password printed, in sync's line or git's.
- A layer moved by hand, then the manifest moves it back: record says `extra`, then the `mv` command back is printed.
- A sparse checkout with `extensions.worktreeConfig`: left alone, unchanged.
- `fetch --refmap=` with explicit refspec against a hostile `remote.origin.fetch`: local branches kept, prune works.

### Checks
- Whole suite at `238134d9`: `cd tools/repos-manifest && REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest -p no:cacheprovider`: `1331 passed in 345.98s` (vcs 0.3.0 at /usr/bin/vcs, colcon at /usr/bin/colcon). The first run at `f5114a5c` had 3 failures, the part-1 tests fixed in 238134d9.
- Signal and kill tests (`test_sync_distros.py`, `test_vcs_behaviours.py`, `-k "kill or stop or signal or step or ignored_file_made or vcs or no_record"`) three runs: 17 passed each time.
- Forbidden-commands scan (`test_update_safety.py`) passes in the whole suite.
- `bash .agent/scripts/check_design_anchors.sh`: exit 0. black and flake8 ran in the commit hooks.
- No workspace script changed; no `.agent/scripts/tests/` suite run. The full pre-commit pass is left to the host. Commits with `SKIP=validate-script-tests`.
- `docs/manifest/design.md` re-read: its sync sentences still hold (exit 1 "a distro was reported" covers the new per-distro write report); not changed.

### For the pull request body
- `sync` updates each repo that is there, by rules checked in order. A clean clone on the manifest's branch is fast-forwarded; one on the version `sync` last recorded is switched to the manifest's new one (a new tracking branch, a local branch fast-forwarded, or detached at a tag or commit). A clone pinned to a tag stays; when origin moves that tag, the fetch fails with the `git tag -d` command, and after it the next `sync` follows the tag, if the repo is still where `sync` put it. `state.yaml` records version, commit, url and layer.
- What `sync` changes before a move: the fetch (`--refmap=` with its own refspec, `--no-recurse-submodules`) brings origin's remote-tracking refs, objects, new tags and `FETCH_HEAD`; never a local branch, a local tag, `HEAD`, the index or a work-tree file, whatever `remote.origin.fetch` or `fetch.recurseSubmodules` say.
- Left as it is and reported: tracked changes; commits not on origin (with `git pull --rebase origin <branch>`); another branch or detached HEAD; an operation in progress or `index.lock`; no single origin; not a repository of its own; a link at the place; a sparse checkout; a local branch of the new version with commits not on origin or checked out elsewhere; a branch rewritten upstream; an untracked or ignored file where an incoming file goes (git also refuses through `--no-overwrite-ignore`); a version given as a commit that origin does not hold.
- Submodules are never updated. A move that would remove or replace a checked-out submodule, or move the commit of one whose HEAD is not the recorded commit, leaves the whole repo as it was and names the submodule to be dealt with by hand; an empty (not checked out) submodule is no obstacle.
- Tags: only a tag origin has counts as the version; a local-only tag or branch of the same name never blocks or redirects a pin.
- `origin`: repointed only when it still has the recorded url and every local branch is on the new one; the new url is recorded at once. An origin set by hand is left as set, with one line per run. No line `sync` prints shows a url's user name or password; a masked `set-url` command says to use the manifest's url for that repo.
- A repo the manifest moves to another layer is not moved: the `mv` command is printed (exit 1, optional skipped); once moved by hand, the record names the new layer whatever happens next. Per distro: a distro that does not resolve, whose resolved files cannot be written, or whose lock a build holds, is reported and the others go on.
- Left for part 3: the manifest's own clone and `local_manifest` (step 1), arguments after `--`. Part 4: the rebase of unpushed commits, with its three findings as the test list.
- Open on purpose: a repo left alone while the manifest names another version exits 0 (`status`, issue 502); the hand-set-origin line prints every run; a submodule left behind by `sync` stops the next pointer move until a person updates it; a shallow clone grows by the history of fetched tags; when origin's default branch changes, a manifest with no version keeps the old branch until `git remote set-head origin --auto`, after which the repo reads as moved by a person; urls in vcs clone output are masked by the same report path, but urls in manifest errors (`show`, `resolve`, refusals) are not this part's.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 16:39 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a52816d3cdcc13103, resume 1 of 3)

**Branch**: feature/issue-500 at `36c5febb`
**Base**: origin/main
**Depth**: Deep (reason: whole branch diff, about 4,600 lines over 23 files; safety-critical git operations on a person's clones)
**Must-fix**: 3 | **Suggestions**: 9
**Round**: 2 | **Ship**: continue — round 2: 3 must-fix is high; another independent read warranted

All six round-1 must-fix are fixed. I re-ran each reproduction at 36c5febb, and each is now safe:
- **Submodule replaced by a file:** left alone, and `mine.txt` and the commit are kept. The subagent also covered a link and a directory, by fast-forward and by switch, with `.git` as a directory and as a file.
- **Moved tag:** after `tag -d`, it is followed, then up to date.
- **Local tag `dev`:** the branch pin is followed.
- **Failing hook on the two-step move:** counted, exit 0.
- **Layer record after a hand move:** recorded (subagent).
- **Local-only commit pin:** left alone.

Checks:
- **Whole suite at 36c5febb:** 1331 passed in 345s.
- **Submodule rule turned off in a copy:** 21 of 28 tests in `test_update_submodules.py` fail.
- **Forbidden-commands scan:** passes in the suite.
- **The three part-1 tests changed in 238134d9:** they still check the error text and the per-distro "reported above" line.

The submodule rule held in every direction tried: removed, replaced by a file, a link or a directory, nested, never initialised, deinitialised, absorbed, a file or directory turned into a submodule, a pointer move with the submodule's HEAD on and off the recorded commit, and switches adding or dropping one. The deep snapshots also compared the objects reachable in each nested repo and in `.git/modules`; nothing was lost.

Other cases that held:
- The moved-tag follow never moves a clone the person moved elsewhere. A detached HEAD at the recorded commit cannot be told apart from where sync put it, and it carries no work.
- `--no-overwrite-ignore` held on both steps and on the undo.
- A commit only on a pull-request ref, only on a local tag, or only local is left alone.
- With `fetch.recurseSubmodules=true`, the url probe did not fetch into a submodule (codex point 3, not reproduced).

### Findings
- [x] (must-fix) A move to a branch the clone's `remote.origin.fetch` does not map is left half-switched. This is a `git clone --single-branch` or `--depth` clone with the pin changed main→dev. `git switch -c dev --track refs/remotes/origin/dev` writes dev's tree into the index and work tree, then dies with "cannot set up tracking information", and HEAD stays on main. The undo is not tried because it was the first step.
  - Reproduced (`mine/probe5.py`, and the subagent's `adv2/c3b_detail.py`). Run 1: exit 1, "left the repo changed: HEAD was X (main), is X (main)". Afterwards main has `D .gitignore`, `A BRANCH` staged, so a `git commit -a` would commit dev's tree onto main. Run 2: exit 0, "has uncommitted changes (2 files); a sync was stopped while moving this repo", although nothing was stopped.
  - Fix: use `--no-track` and set `branch.<n>.remote`/`merge` explicitly; or check the mapping first and leave the repo alone. Also put a failed first step back, and stop calling a failure a stop in the wording. — `update.py:786-794`, `update.py:842-877`
- [x] (must-fix) sync's fetch prunes a person's remote-tracking refs that are not branches. With an extra `+refs/pull/*/head:refs/remotes/origin/pr/*` refspec, `--prune` with sync's own refspec removed `refs/remotes/origin/pr/1`, which origin still has.
  - Reproduced: `for-each-ref refs/remotes/origin/pr` held one ref before and was empty after. The subagent saw 3 objects become unreachable and a branch made from the PR now counted as not on origin.
  - The design's sentence "removes those of branches origin no longer has" is false.
  - Fix: prune only what sync's refspec brings, for example by listing `origin`'s heads and deleting `refs/remotes/origin/<b>` for each one gone; or drop `--prune`; or state the behaviour. — `update.py:668-678`, `docs/design.md` (sync, the fetch paragraph)
- [x] (must-fix) A password holding `'`, `"` or a space is printed in full. The `USERINFO` class stops at quotes and spaces, so `https://alice:s3cr'x@host/...` is shown whole (`mask_urls` checked directly, and the subagent saw it in the by-hand and repoint lines). The design's "A url's user name and password are never printed" is false for these urls. Fix: let the user info run to the last `@` before `/`, `?`, `#` or the end of the token, quotes included. — `update.py:152-161`
- [x] (suggestion) A person's own local tag that origin later also creates fails every fetch (exit 1) even when the manifest does not name it. The message says "was moved on origin" (false), and the advised `git tag -d` can orphan the person's commit when the tag is its only ref. Word it as "origin has a tag of the same name", and warn when the local tag is the only ref holding its commit. — `update.py:679-688`
- [x] (suggestion, usability) After the first fast-forward that moves a submodule's pointer, which sync never updates, every later move of that pointer is blocked until a person updates the submodule. A repo with submodules stops following at its second pointer move.
  - The blocked message, "submodule sm is on X, not on Y, the commit recorded here, and the move changes that commit; not updated (a submodule has to be dealt with by hand, then sync again)", gives no command.
  - For a submodule cloned by the person and not registered in `.git/config`, the earlier `git submodule update` hint does nothing.
  - The design says the blocking (line 809). The README says only "one a person has moved", which does not cover a submodule sync left behind.
  - Put `git -C <place> submodule update --init -- <path>` in the message, say "the commit the superproject's HEAD records", and add the case to the README. — `update.py:300-305`, `README.md:111-112`
- [x] (suggestion) A successful first step is not checked with `_arrived` before the second. A `post-checkout` hook that changes tracked files and exits 0 lets the fast-forward run on a dirty tree. It ends as an error, nothing is lost (codex). — `update.py:842-849`
- [x] (suggestion) The fetches run without the lock descriptor. A `sync` killed during a fetch frees the lock while git still writes refs (codex); the design's kill table covers the result. — `update.py:668-678`, `update.py:906`
- [x] (suggestion) A detached HEAD at the recorded commit of a recorded branch is treated as sync's own and moved on a pin change. Nothing is lost; the design states it (rule 11). Codex says to record attached or detached. — `update.py:765-766` (deferred: left as it is, the host's decision: nothing is lost and design rule 11 states it)
- [x] (suggestion) A commit pin beyond a shallow clone's history is reported as "version X is not on origin" (exit 1). That is true by design rule 8, but the message could name the shallow history. — `update.py:496-500`
- [x] (suggestion) The url-rule notes and the `left alone` lines are masked through `sync.py`. Messages raised as `ManifestError` from `present_repo` (the "may have been changed" path) and per-distro `Refusal`s are not. Not reached by a url in testing; worth one pass. — `sync.py:404-416`
- [x] (suggestion) A person switching branches between sync's HEAD read and the merge could have another branch fast-forwarded (codex). This is speculative, and the result is still a fast-forward of commits on origin. — `update.py:842` (deferred: left as it is, the host's decision: speculative, and the result is still only a fast-forward to commits on origin)
- [x] (suggestion, repeated from round 1) The README conflict with `feature/issue-531` is still deferred to the host at merge. — `README.md:124-127` (deferred: the host resolves the README conflict with issue 531's branch at merge)

## Implementation
**Status**: complete
**When**: 2026-11-19 17:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a5f44b6979a40343e, resume 1 of 3)

**Branch**: feature/issue-500 at `c295c3e9`
**Addressed**: Local Review (Pre-Push) at `36c5febb` (2026-11-19 16:39 -05:00)
**Commits**: df68895f, 407b8461, 611b146d, b4721144, a0c3ea30, d3d0bb2f, 7df20ca3, 7f5b4e2b, c295c3e9 (box checks)

I reproduced each must-fix first with the reviewer's `probe5.py`. M1: a single-branch clone moved main to dev failed with "HEAD was 9158e359…, is 9158e359…", `dev`'s tree was left staged, and the next run said "a sync was stopped". M2: `refs/remotes/origin/pr/1` was removed. S1: `mask_urls` printed `s3cr'x` and `p w` whole. After the fixes, each new test that covers a broken path fails when the source diff is reverted. The exceptions are the new single-branch tag and commit cases, the local-branch direction, and the narrow cases that guard paths which were already right.

### Actions
- [x] (must-fix 1) Narrow clones: a branch not yet local is made with `git switch -c <name> --no-track <origin's commit>`, which either does all of it or nothing. The upstream is set afterwards with `git branch --set-upstream-to`. If that fails, the move stands and a note says the branch has no upstream, why (the clone's `remote.origin.fetch` does not cover it, when that is the case), and gives the two `git config` commands that set one. Every step is checked by the state it leaves. A step that leaves a half-change is reported as "left the repo half-changed: HEAD is still at X (branch); staged: …; changed, not staged: …". Those changes are said to be git's, and the moving line is dropped, so the next sync reports uncommitted changes and not "a sync was stopped". Tests: `test_a_narrow_clone_is_moved_whole_or_not_at_all` (`--single-branch` and `--depth 1` × dev, tag, commit), `test_an_upstream_that_cannot_be_set_is_a_note_and_the_move_stands` (stub fails only the upstream step), `test_a_switch_that_leaves_a_half_change_says_what_it_left` (stub reproduces the M1 end state) — `update.py` `_move`, `_change`, `_half_changed`, `_set_upstream`
- [x] (must-fix 2) The fetch passes `--no-prune --no-prune-tags`, which win over `fetch.prune` and `remote.origin.prune`, so `sync` removes no remote-tracking ref. The version is asked of origin (`ls-remote origin refs/heads/V refs/tags/V`), and a branch's remote-tracking ref must equal origin's commit. A branch deleted on origin is an error that names the stale ref. A commit pin is followed only when a ref that holds it is listed by origin now. The "commits not on origin" count still uses `--remotes=origin`. A stale ref there can only let a repo be moved, and a move never loses a commit; the design says so. Tests: the reviewer's pull-request refspec with `None`, `fetch.prune` and `remote.origin.prune`; a pinned branch deleted on origin (repo unchanged); a commit held only by a stale ref (not followed) — `update.py` `find_version`, `ask_origin`, `_branch`, `commit_on_origin`, fetch
- [x] (must-fix 3) Masking by parsing, in the new `masking.py`. Every url the tool reads is registered: the manifest's at validation, before any error quotes it; origin's and the recorded one in `update_repo`. Its user information is everything between `://` and the last `@`, whatever it holds. That string and its `%`-decoded form are masked wherever they appear. Any other url is masked by its shape, up to the first `@` that a host follows. Tests: quotes, a space, `@`, `:`, `/`, `%` escapes and unicode in the user and the password, in by-hand, repoint and git lines. Two whole `sync` runs against `127.0.0.1:9` grep all output (18 cases fail with the old pattern) — `masking.py`, `update.py`, `sync.py`, `cli.py`, `manifest.py`
- [x] (suggestion a) Tag clash: git exits 1 for a tag it will not replace and still fetches the branches (checked: `origin/main` and `origin/dev` updated, exit 1). `sync` then fetches the branches again with `--no-tags` and goes on when that exits 0. A clash on a tag the manifest does not name is a note. For the manifest's tag the error gives both commits. It says origin "moved" the tag and advises `git tag -d` only when the record shows sync followed that tag at the commit it holds here; otherwise "which to keep is for a person to decide", with no deletion advice. Tests: a non-manifest clash (followed, local tag kept); a person's own tag that origin also made (no `tag -d`); the moved-tag sequence from round 1, unchanged — `update.py` fetch, `_tag_clash`
- [x] (suggestion b) The blocked-submodule messages give a command. For a submodule on another commit: `git -C P submodule update -- <path>` when it holds nothing of yours. For one removed or replaced: move it aside. The README says a repo with submodules follows one change of a submodule's commit and stops at the next until the submodule is updated by hand. A test shows that the given command lets the next sync follow — `update.py`, `README.md`
- [x] (suggestion c) Each step is judged by state even when it exits 0. A `post-checkout` hook that edits a tracked file after the switch stops the move before the fast-forward, reported as a half-change. `test_a_hook_that_edits_a_tracked_file_stops_a_two_step_move_after_its_switch` fails at the commit before 407b8461 — `update.py` `_change`
- [x] (suggestion d) The fetches (main and probe) are given the lock descriptor (`hold=True`) but not the held signals, so Ctrl-C still stops a hanging fetch or a password prompt. The kill-before-fetch test now asserts that the lock stays held while the killed sync's fetch runs, then that the next sync follows — `update.py` `Git.run`
- [x] (suggestion e) A commit pin beyond a shallow clone's history: "is not in this shallow clone's history; sync never deepens a clone (`git -C P fetch --unshallow origin`, run by hand, makes it whole)". Tested with a commit outside every tag's history — `update.py` `find_version`
- [x] (suggestion f) Errors (`cli.py`) and per-distro report and refusal lines (`sync.py`) go through `mask_urls`. A test with a url the manifest refuses (`foo::https://alice:<pw>@…`), in `sync` and `resolve`, found that a url in git's `<transport>::<address>` form was not registered; the scheme is now searched for anywhere in it — `cli.py`, `sync.py`, `masking.py`
- [x] (suggestion) Detached HEAD at a recorded branch's commit moved on a pin change (deferred: the host's decision; nothing is lost and design rule 11 states it)
- [x] (suggestion) A branch switched by a person during the run (deferred: the host's decision; speculative, and the result is still only a fast-forward to commits on origin)
- [x] (suggestion) README conflict with issue 531's branch (deferred: the host's at merge)

### Departures
- Must-fix 2 and suggestions a, d and e are in one commit (b4721144), because they are the same edits to the fetch and the version lookup.
- Must-fix 1 did not need a separate "create the ref, then switch" pair. `git switch -c <name> --no-track <commit>` makes the branch only when the switch succeeds, so it is one step that does all or nothing. Tracking is the separate last step, as asked. Undoing a half-change is not attempted, since sync runs no reset or forced checkout. The report names what is staged instead.
- Every sync now makes one `ls-remote origin` per repo, plus one more for a commit pin. That is the price of not reading a possibly stale ref. An https origin without a credential helper is asked for its password twice.
- The upstream advice gives `git config branch.<b>.remote origin` and `branch.<b>.merge refs/heads/<b>`, which work whatever the fetch settings are. `--set-upstream-to` would still refuse in a narrow clone.

### Tried by hand (session scratchpad `fx/neigh2.py`, `fx/clash.sh`, `fx/showmask.py`)
- A single-branch clone with `branch.autoSetupMerge=always`, pinned to dev: moved, clean, no upstream, note given (`--no-track` wins). Then pinned back to main (two-step path): moved, clean.
- A pinned branch deleted on origin with the pin unchanged: exit 1, the stale-ref message, repo unchanged.
- Passwords `a://b`, `x@y@z` and `p://q@r s`: masked whole in both quoted and bare forms.
- The manifest's tag moved on origin after sync followed it: the error gives both commits and the `tag -d` advice.
- An origin path that is gone: the by-hand line, then a fetch error.
- `remote.origin.tagOpt=--no-tags` with a pin to a new tag: found and moved to.
- Which path each awkward manifest url takes: all reach the repoint probe's failed fetch, masked. A refused url is covered by the new refused-url test.

### Checks
- Whole suite at `7df20ca3`: `cd tools/repos-manifest && REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest -p no:cacheprovider` gave `1387 passed in 370.58s` (vcs 0.3.0, colcon present). Only the design text changed after that (7f5b4e2b).
- Signal and kill tests (`test_sync_distros.py`, `test_vcs_behaviours.py`, `-k "kill or stop or signal or step or ignored_file_made or vcs or no_record or upstream or half"`), three runs: 19 passed each time.
- The forbidden-commands scan passes. Its sanity check now reads `fetch --tags` and the `--no-prune --no-prune-tags` argument list.
- `check_design_anchors.sh`: exit 0. black and flake8 ran in the commit hooks. No workspace script changed. The full pre-commit pass is the host's. Commits used `SKIP=validate-script-tests`.

### For the pull request body
- `sync` updates each repo that is there, by rules checked in order. A clean clone on the manifest's branch is fast-forwarded. One on the version `sync` last recorded is moved to the manifest's new one. A branch not yet local is made with `git switch -c --no-track` at origin's commit, all or nothing, and its upstream is set after as a separate step; in a `--single-branch` or `--depth` clone that step is refused, and the report gives the two `git config` commands. A local branch is switched to and fast-forwarded. A tag or a commit is checked out detached. Every step is judged by the state it leaves. A step that leaves a half-change is reported as exactly that, naming HEAD and the staged files, and nothing more runs in that repo.
- The fetch (`--tags --no-prune --no-prune-tags --no-recurse-submodules --refmap= origin +refs/heads/*:refs/remotes/origin/*`) removes no ref and writes no local branch, whatever the person's fetch settings. It holds the distro's lock but not the stop signals. The version is asked of origin itself, so a remote-tracking ref left from a deleted branch is never followed.
- Tags: only a tag origin has, as the same object, counts. A clash on a tag the manifest does not name is a note. For the manifest's tag, the error gives both commits, and advises `git tag -d` only when sync had followed that tag there. After that, the next sync follows origin's tag. A local tag or branch of the same name never blocks a pin.
- Left as it is and reported: tracked changes; commits not on origin (with `git pull --rebase origin <branch>`); another branch or detached HEAD; an operation in progress or `index.lock`; no single origin; not a repository of its own; a link at the place; a sparse checkout; a local branch of the new version with commits not on origin or checked out elsewhere; a branch rewritten upstream; an untracked or ignored file where an incoming file goes; a commit pin origin does not hold. A commit beyond a shallow clone's history and a branch origin deleted are errors that say so.
- Submodules are never updated. A move that would remove or replace a checked-out submodule, or move the commit of one whose HEAD is not the recorded commit, leaves the repo as it was and names the command to run. A repo with submodules follows one change of a submodule's commit and stops at the next until it is updated by hand.
- `origin` is repointed only when it still has the recorded url and every local branch is on the new one. An origin set by hand is left as set. No user name or password of a url is printed, in any repo line, error or refusal, whatever characters it holds.
- Layers, per-distro reports and the lock are as before. A repo moved by hand to its new layer has that layer recorded.
- Left for part 3: the manifest's own clone and `local_manifest`, and arguments after `--`. Part 4: the rebase of unpushed commits.
- Open on purpose: a repo left alone while the manifest names another version exits 0 (issue 502); the hand-set-origin line prints every run; one extra `ls-remote` per repo per run; a shallow clone grows by the history of fetched tags; origin's default branch follows the clone's `origin/HEAD` until `git remote set-head origin --auto`; a detached HEAD at a recorded branch's commit is moved on a pin change (nothing lost); a branch switched by a person during the run is not re-checked before the fast-forward.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 17:17 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a52816d3cdcc13103, resume 2 of 3)

**Branch**: feature/issue-500 at `3d8601c8`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 6
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Scope: the round 2 findings and the fix diff `482e0655..3d8601c8`. Cross-model: skipped (round-3 convergence check, per handoff). The Claude adversarial specialist ran fresh, held to this scope.

Round 2 must-fix, re-run at 3d8601c8:
- **Single-branch move (`probe5.py`):** moved to dev, clean, with the no-upstream note and the two `git config` commands. The next run is up to date.
- **Pull-request refspec:** `refs/remotes/origin/pr/1` is kept.
- **Passwords with quotes and spaces:** masked in sync's output, through the registered url. A bare unregistered url holding a space is not matched by the shape pattern; the design states the shape rule ("within one run of characters that are not white space").

Checks:
- Whole suite at 3d8601c8: 1387 passed in 370s.
- The forbidden-commands scan passes and still forbids the `prune` command and `remote prune`. It does not forbid the `--prune` or `-p` flags (suggestion).

The adversarial specialist found no lost work and no printed credential:
- Full, `--single-branch` and `--depth 1` moves held, with a local branch behind, ahead or unrelated.
- A refused upstream step left the move standing, with a note.
- After each half-change the `moving` line was cleared and the next sync said "has uncommitted changes".
- The design's stale-ref claim held: a commit only on a stale ref and HEAD's branch is still on the local branch after a move. This was with `fetch.prune` and `remote.origin.prune` set.
- A branch renamed on origin, a tag deleted on origin, and `ls-remote` failing after a good fetch each gave an error with the repo unchanged.
- In a tag clash, the person's tag was kept and the second fetch changed nothing of theirs. There was no `tag -d` advice for a person's tag.
- No credential appeared in stdout or stderr for manifest, origin, `foo::https://`, `%` or `insteadOf` urls.

### Findings
- [x] (suggestion) The half-change report says the changed files "are git's, not a person's", and the design says "which are git's, since the repo had no tracked changes before". When a person's `post-checkout` or `post-merge` hook made them, they are the hook's: reproduced by the specialist, cases 1a-1c in `adv3/s1_moves.py`. Say "made by git or a hook it ran". — `update.py:964-967`, `docs/design.md:815`
- [x] (suggestion) The two-step half-change report is inaccurate:
  - It says "nothing more was run here" after the undo switch ran, and that switch carried a hook's edit back onto main.
  - It says HEAD "is still at main" when it went to dev and back.
  - It does not say that the local `dev` was fast-forwarded.

  No commit was lost (`adv3/s1_moves.py` 1a). — `update.py:913-922`, `update.py:955-970`
- [x] (suggestion) A new branch whose move ends half-changed returns before `_set_upstream`. It is left without an upstream, and once the person cleans up, nothing says so (`adv3/s1c_next.py`). — `update.py:936-937`
- [x] (suggestion) Registered user information is replaced wherever `<info>@` appears.
  - A `file://` path holding `@` masks the system's own path in printed commands: `git -C ***@x/...`.
  - A user such as `git` or `main` turns `git@github.com:...` or `origin/main@{upstream}` into `***@...`.

  No leak, and the design says "more masked, never less". Register nothing for `file://` urls, or for user information holding `/`, and anchor the replacement after `://`. (`adv3/s4_mask.py`) — `masking.py:56-57`, `masking.py:71-72`
- [x] (suggestion) After a `sync` is killed, its orphaned fetch holds the lock, and the next run says "a sync is still running" naming a dead pid. A fetch stopped at a password prompt may hold the lock until killed. The design says "until the fetch ends"; say that this may need a kill, and name the git child in the refusal. (`adv3/s5_lock.py`) — `system.py:505-512`, `docs/design.md:909`
- [x] (suggestion) Add `--prune` (and fetch's `-p`) to the forbidden words, now that the design says sync prunes nothing. — `update.py` `NEVER`, `tests/test_update_safety.py`

## Checkpoint
**Status**: complete
**When**: 2026-11-19 17:42 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 approved with six suggestions; three of them are report lines that say something untrue and one prints a wrong command, which are not published as they are; main has also moved under the branch)
**After**: publish
**Decision**: address

The full pre-commit pass was not run: the answer changes the code, so the pass runs on the head that follows. Fixed in this round: suggestion 1 (the half-change report and the design say the changes were made by git or a hook it ran); suggestion 2 (the two-step half-change report says what really ran: the switch, the fast-forward of the local branch if it happened, the switch back, and where HEAD is); suggestion 3 (a branch left without an upstream after a half-change is reported on the run that finds the repo clean again, or the note is given with the half-change report); suggestion 4 (masking registers nothing for file urls and matches credentials only after ://, so a path or a name such as git@ or main@ is never masked); suggestion 5 (the lock message after a killed sync says a fetch of that sync may still be running, and the design says a fetch waiting at a prompt holds the lock until it ends or is killed); suggestion 6 (--prune and fetch's -p join the forbidden words). The branch also takes origin/main, which now holds pull request 534, and the README conflict is resolved.

## Implementation
**Status**: complete
**When**: 2026-11-19 18:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a5f44b6979a40343e, resume 2 of 3)

**Branch**: feature/issue-500 at `8279b435`
**Addressed**: Local Review (Pre-Push) at `3d8601c8` (2026-11-19 17:17 -05:00)
**Commits**: 64c5d0a2 (merge of origin/main), 3fa23a13, e5bbcde3, 35bb01d0, 9099dcf9, 8279b435 (box checks)

### Step 0: origin/main merged
- 64c5d0a2 merges `origin/main` into the branch, bringing pull request 534 (issue 531). It is a merge commit, not a rebase.
- There was one conflict, in `tools/repos-manifest/README.md`'s build paragraph. Both changes are kept: 531's sentence on `--packages-skip` and `--packages-ignore` and the record of skip and ignore options, and this branch's "or a `sync` of that distro" in the lock sentence.
- `system.py`, `docs/design.md`, `tests/test_build.py` and `tests/test_system.py` merged without conflict. In `system.py`, 531's `without` field and its record read and write (`LayerRecord`, `read_built`, `_read_without`) sit beside this branch's `RepoRecord` `url` and `moving` fields and the lock's `holder`. They share no function. This branch's changed test (`test_the_install_note_names_removed_and_added_repos`, the repo moved by hand) is still there, beside 531's new tests.
- Whole suite right after the merge: `1551 passed in 504.49s`.
- The merged design's "build" and "sync" sections were read for sentences the other change made untrue. "A `sync` writes no build record", "the record does not say that a layer is up to date with `sync`", and the shared lock sentences all still hold.

### Actions
- [x] (suggestion 1) The half-change report and the design say the changes "were made by git or a hook it ran (the repo had no tracked changes before)" — `update.py` `_half_changed`, `docs/design.md` sync
- [x] (suggestion 2) The half-change report says what ran, in order: each call with its exit status and where it took HEAD; a fast-forward naming the branch and both commits; the switch back when it ran; and where HEAD is now. It ends with "nothing after the steps above was run here". The switch back now runs only from a clean tree, so a hook's edit is never carried onto the old branch. In the review's case 1a the repo is left on dev at origin's commit with the hook's change, and once the person cleans it up the next sync records it as up to date. Tests: case 1a (a post-merge hook edits README), a hook on the switch after the first step, the switch back changed by a hook (three calls listed), and the stub half-switch. Each fails at the commit before 3fa23a13 — `update.py` `_change`, `_what_ran`, `_half_changed`
- [x] (suggestion 3) A branch that a half-changed move made, when it has no upstream, is reported in the same run with the two `git config` commands ("the move did not finish, so it was not set"). The review's case 1c gives it, and the stub half-switch test asserts it — `update.py` `_change`, `_no_upstream`
- [x] (suggestion 4) `file://` urls register nothing. A registered user information is masked only right after a scheme's `://`, by the same ssh and file rule as any url. Tests cover the review's three false positives: a system under `w@x` with `file://` urls (both urls and the command printed whole); `git@github.com:...` after an `https://git@` url; and `origin/main@{upstream}` and `/srv/main@2` after an `https://main@` url. A further test covers a registered `git` user next to an `ssh://git@host` url. For a password that is a common word (`git`, `main`, `a`), the registered text is `alice:<word>`, which only matches right after `://`, so the url is masked and the command printed beside it is unchanged. Every round-2 masking test still passes — `masking.py`, `docs/design.md`
- [x] (suggestion 5) When the lock file names a sync whose process has ended (or cannot be checked), the refusal says: "a sync … has ended (process N), and a git it started, such as a fetch, may still hold its lock … `fuser -v <lock>` names it … The fetch ends on its own, or, when it waits at a password prompt, only when it is killed (`kill <pid>` …)". The design says the same, and that a fetch at a password prompt holds the lock until it is killed. Tests: the dead-pid test and the kill-before-fetch test. The review's `s5_lock.py` now prints this — `system.py` `hold_build_lock`, `docs/design.md`
- [x] (suggestion 6) `--prune` and `-p` are in `NEVER`. The scan matches whole words, and a test shows `--prune` and `-p` are found while `--no-prune`, `--no-prune-tags` and `--prune-tags` are not. The design's list of what `sync` never passes names them — `update.py`, `tests/test_update_safety.py`

### Tried by hand
These used the session scratchpad: `fx/s1abc.py` (review cases 1a to 1c), `fx/s4_mask.py`, `fx/s5_lock.py`.
- 1a (post-merge hook, two-step): the report lists the switch and the fast-forward of dev with both commits. The repo is left on dev, and README is not carried to main.
- 1b (hook edits BRANCH): the same, no switch back.
- 1c (post-checkout hook on a new branch): the no-upstream note, then the half-change report.
- `s4_mask.py`: the system under `w@x` prints its paths whole, and `main@`, `git@github.com` and `origin/main@{upstream}` are unmasked.
- `s5_lock.py`: an orphaned fetch after a kill gives the new refusal.

### Checks
- Whole suite at `9099dcf9`: `cd tools/repos-manifest && REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest -p no:cacheprovider` gave `1569 passed in 506.61s` (vcs 0.3.0 at /usr/bin/vcs, colcon at /usr/bin/colcon).
- Signal and kill tests (`test_sync_distros.py`, `test_vcs_behaviours.py`, `-k "kill or stop or signal or step or ignored_file_made or vcs or no_record or upstream or half or ended"`), three runs: 20 passed each time.
- The forbidden-commands scan passes with `--prune` and `-p` added. black and flake8 ran in the commit hooks. No workspace script changed. The full pre-commit pass is the host's. Commits used `SKIP=validate-script-tests`.

### For the pull request body
**What `sync` does with a repo that is there.** The rules are checked in order (tool `docs/design.md`, "sync"):
- A git repo of its own, with one `origin`, nothing in progress, no tracked changes, not sparse, on the manifest's branch: fast-forwarded (`git merge --ff-only --no-overwrite-ignore`).
- A repo on the version `sync` last recorded, when the manifest names a new one: moved.
  - A new branch: `git switch -c <b> --no-track <origin's commit>` (all or nothing), then its upstream. In a `--single-branch` or `--depth` clone git refuses the upstream; the move stands, and a note gives the two `git config` commands.
  - A local branch: switched to and fast-forwarded. If the fast-forward does not get there from a clean tree, the switch is undone.
  - A tag or a commit: detached.
- A repo pinned to a tag stays. A tag moved on origin after `sync` followed it is reported with both commits and the `git tag -d` step; after that, the next `sync` follows it.
- Every call is judged by the state it leaves, whatever its exit status. A failing `post-checkout` hook after a real switch counts, with a note. A hook that edits tracked files stops the move. A call that leaves a half-change is reported as what ran, in order, where HEAD is now, and the files changed by git or a hook it ran. `sync` puts nothing back, and the next run reports uncommitted changes, never "a sync was stopped".
- Before any move: a paths check (no untracked or ignored file where an incoming file goes, judged with `lstat`), and a submodule check (no checked-out submodule removed or replaced, and no pointer moved under a submodule whose HEAD differs). Git's `--no-overwrite-ignore` is behind the paths check.

**Left as it is and reported:**
- tracked changes;
- commits not on origin (with `git pull --rebase origin <branch>`);
- another branch or a detached HEAD elsewhere;
- a rebase, merge, cherry-pick, revert, bisect or `index.lock`;
- no single origin;
- not a repository of its own;
- a link at the repo's place;
- a sparse checkout;
- a local branch of the new version with commits not on origin, or checked out in another work tree;
- a branch rewritten upstream;
- an untracked or ignored file where an incoming file goes;
- a commit pin that origin does not hold;
- a blocked submodule, with the command to run.

Untracked files elsewhere never stop an update.

**Errors that another sync will not fix:**
- a version not on origin, or both a branch and a tag there;
- a branch origin deleted (the stale ref is named);
- a commit beyond a shallow clone's history;
- a tag clash on the manifest's own tag.

A fetch that fails, or an `ls-remote` that fails, is an error a later sync can fix. An optional repo is skipped, not failed.

**The fetch.** `git fetch --tags --no-prune --no-prune-tags --no-recurse-submodules --refmap= origin +refs/heads/*:refs/remotes/origin/*`:
- It removes no ref and moves no local branch, whatever `remote.origin.fetch`, `fetch.prune`, `remote.origin.prune`, `fetch.pruneTags` or `fetch.recurseSubmodules` say.
- A tag clash on a tag the manifest does not name is a note; the branches are fetched again without tags.
- The version is asked of origin (`ls-remote`), so a stale remote-tracking ref is never followed.
- Every git runs with automatic gc and maintenance off and `submodule.recurse` off.
- `sync` never runs reset, `checkout -f`, clean, stash, rebase, pull, push, gc or prune, never deletes a branch, and passes no `--force`, `--no-verify`, `--prune` or `-p`. A test reads `update.py` for each.

**`origin` and urls:**
- `origin` is repointed only when it has the url `sync` recorded and every local branch is on the manifest's new url (probe refs in a namespace of their own); the new url is recorded at once.
- An origin set by a person is left as set, with one line per run and the `set-url` command; the update follows it. A system made before urls were recorded is never repointed.
- No user name or password of a url is printed in any repo line, error or refusal, whatever characters it holds (parsed, registered, masked after `://`). `file://` urls, local paths, scp-like addresses and `origin/main@{upstream}` are never masked.

**Layers and records:**
- A repo the manifest gives another layer is not moved. The `mkdir -p … && mv …` command is printed, and that is an error (exit 1) for a repo that is not optional.
- Moved by hand, the repo's record names the new layer.
- A repo that left the manifest is listed and left on disk.
- `state.yaml` records each repo's version, commit, url and, while a move runs, a `moving` line.

**Per distro, `init` and the lock:**
- A distro that does not resolve, whose resolved files cannot be written, or whose lock is held is reported, and the others go on (exit 1).
- `sync` and `init` (for its first sync) hold the distro's build lock from before the resolved files are written to the end of its repos. Every git that changes a repo, fetches included, is given the lock.
- A build refused by a running sync says so. After a killed sync, the refusal says a fetch it started may still hold the lock, how to find it with `fuser -v`, and that it ends on its own or, at a password prompt, when killed.
- A built layer whose repos this sync changed gets a line saying `build` brings it up to date.

**Documents changed:**
- `tools/repos-manifest/docs/design.md`: "sync", with its rules, the fetch, the paths and submodule checks, the url rule, credentials, the lock, and the stop and kill table; "Where the resolved files and state go"; "Where repos are fetched from"; "Work done on a field machine"; "build", on the shared lock; "What is built".
- `tools/repos-manifest/README.md`.
- `tools/repos-manifest/docs/roadmap.md`: a file-exists check.
- The workspace's `docs/manifest/design.md`: two sentences that said `sync` leaves a repo that is there as it is, and the exit-status line.

**Left for part 3:** step 1 of the design's sync (the manifest's own clone and `local_manifest`), `--local-manifest`, and the arguments after `--` passed to `vcs import`.

**Left for part 4:** the rebase of unpushed commits. Its three test cases, from the first part-2 plan review:
- an ignored file overwritten and then deleted by an aborted rebase;
- the rebase running under the person's git settings;
- a force-pushed upstream replayed as local commits.

**Open on purpose:**
- A repo left alone while the manifest names another version exits 0 (`sync.py:641-654`, `closing`). `status`, issue 502, is the check a script reads.
- The hand-set-origin line prints every run (`update.py:709`).
- One `ls-remote` per repo per run, plus one more for a commit pin (`update.py:486`, `update.py:455` `find_version`). An https origin without a credential helper asks for a password twice.
- Submodules are never updated (`update.py:957`). A repo with submodules follows one change of a submodule's commit and stops at the next until it is updated by hand.
- A shallow clone grows by the history of the tags it fetches (`update.py:734`).
- A manifest with no version follows the clone's `origin/HEAD` until `git remote set-head origin --auto` (`update.py:463`).
- A detached HEAD at a recorded branch's commit is moved on a pin change, and nothing is lost (`update.py:821-826`, `_on_recorded`; design rule 11).
- A branch switched by a person during the run is not re-checked before the fast-forward (`update.py:870`, `_change`).
- An https url whose path holds `@` has more masked than its user information (`masking.py:12`).

**Tests:** 1569 pass in the tool's suite with `REPOS_MANIFEST_REQUIRE_COLCON=1`, the 1315 that came with pull request 534 included.

**By-hand acceptance for the owner,** on his real project. Install the tool from this branch into his venv first (`~/p11-venv/bin/pip install --upgrade <this checkout>/tools/repos-manifest`). Then, in his system directory, with his own pin change in place of `<repo>` and its layer in place of `<layer>`:

```bash
cd ~/project11
git -C rolling/<layer>/src/<repo> status --short; git -C rolling/<layer>/src/<repo> log --oneline -1   # before
~/p11-venv/bin/repos-manifest sync --distro rolling
git -C rolling/<layer>/src/<repo> status --short; git -C rolling/<layer>/src/<repo> branch --show-current
grep -A6 '<repo>:' .repos-manifest/state.yaml    # version, commit and url are the new ones
~/p11-venv/bin/repos-manifest sync --distro rolling     # again: "up to date", nothing changes
```

His clones whose `origin` is ssh while the manifest says https are left as set, with one line each per run; his record has no urls yet, so none is repointed. For the safety rows, use a throw-away system made the same way (never the real one): a changed tracked file, a local commit, a repo switched by hand, an `origin` set by hand, and an ignored file where an incoming file arrives. After each, run `sync`, then `git status` and `git log -1`, and compare with before.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 18:21 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a52816d3cdcc13103, resume 3 of 3)

**Branch**: feature/issue-500 at `00ffcba9`
**Base**: origin/main
**Depth**: Deep (reason: round 4 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 8
**Round**: 4 | **Ship**: continue — round 4: must-fix rising (0 -> 1); the one must-fix is a mechanical fix

Scope: the round 3 suggestions and `3d8601c8..00ffcba9`. Cross-model: skipped (round-4 convergence check, per handoff). The Claude adversarial specialist ran fresh, held to this scope.

**Merge (64c5d0a2):** correct. For every file both sides touched, the change lines of `git diff 3d8601c8 64c5d0a2 -- tools/` equal those of `git diff b836e5e1 origin/main -- tools/` (PR 534's), except `README.md`. There, both sentences are kept whole: 534's skip and ignore options and record, and this branch's "or a `sync` of that distro". `system.py`, `docs/design.md`, `test_build.py` and `test_system.py` hold both changes. Whole suite at 00ffcba9: 1569 passed in 506s.

The six round 3 suggestions:
1. **"Made by git or a hook it ran":** fixed.
2. **The report lists what ran, in order:** fixed. Adversarial cases 1a-1c match the reflog word for word. The switch back runs only from a clean tree. In no path was the person left on a branch without the report saying so, or moved further than the manifest's branch.
3. **The upstream note with a half-change:** fixed. It is given once (S4 below).
4. **Masking:** the round-3 false positives are gone (`w@x` with `file://` urls, `git@github.com:`, `origin/main@{upstream}`, `/srv/main@2`, and common-word passwords). Every round-2 and round-3 leak case still holds. Two new leaks, below.
5. **Lock refusal after a killed sync:** every word true (`s5_lock.py`, `s5b.py`).
6. **`--prune` and `-p` in the scan:** fixed. `--no-prune` and `--prune-tags` are not flagged.

### Findings
- [x] (must-fix) A password held by a url in the manifest refusals is printed in full when Python's `repr` escapes it and it holds white space: `'` together with `"`, or a `\`, plus a space.
  - The refusals quote the url with `{url!r}`. The escaped text no longer matches the registered user information, and the fallback pattern stops at the space.
  - Reproduced through sync's output by the specialist (`adv4/s3_e2e.py` cases 0 and 4). Output: `repositories.a.url: 'foo::https://u:a\'b" c@127.0.0.1:9/r.git': the <transport>::<address> form is refused`.
  - Reproduced here at the function level: `mask_urls(repr(u))` after `remember_url(u)` returns the password whole for `u:a'b" c` and for `u:p\ q`.
  - The design says the user information is masked "whatever characters it holds (quotes, spaces, …)".
  - Fix: mask the url before quoting it in these messages. — `manifest.py:270`, `:281` (and the same `{url!r}` at :296, :300, :305, :313, :320, :338, :347, :364)
- [x] (suggestion) A `file://` url's user and password are printed whole (`file://u:SECRETPW@localhost/...` in the repoint failure line, `adv4/s3_e2e.py` case 5). I grade this a suggestion, not a printed credential:
  - The design says on purpose that a `file://` url is never masked.
  - git's file transport takes no user or password.

  Still, masking a `file://` user information that holds `:` and no `/` would close it. — `masking.py:44-49`, `docs/design.md:884`
- [x] (suggestion) The design's "so a change git or a hook made is never carried back onto the branch the repo was on" holds for tracked changes. An ignored file a `post-checkout` hook made on `dev` stays in the work tree after the switch back, and the report says "left as it was" (`adv4/s2_behaviour.py` 2b). Say "a tracked change". — `docs/design.md:805-807`
- [x] (suggestion) A half-changed move leaves the repo on `dev` with the record still on `main`. If the manifest then goes back to `main` and the tree is cleaned, the next sync says "moved by a person: it is on dev", though sync moved it (`adv4` 2e). — `update.py:815` (deferred: the host's decision: the record cannot tell sync's own unfinished move from a person's without a new field; the design now says so (be578f0f))
- [x] (suggestion) The report says "These changes were made by git or a hook it ran" when no changes are listed (both the merge and the switch back refused, so the tree is clean, case 2d). When git printed nothing, the error ends in "was run here:" and an empty line. — `update.py:1002`
- [x] (suggestion) With a stub git only, a merge that moves `dev` part way and exits 1 on a clean tree triggers the switch back. The report says "left as it was" while `dev` was moved; the `ran` list is dropped on the LEFT path. A real `merge --ff-only` is all-or-nothing, and the commits stay reachable (case 2h). — `update.py:940` (deferred: the host's decision: it needs a fake git, and a real merge --ff-only is all or nothing)
- [x] (suggestion) The missing upstream after a half-changed `switch -c` is said once. Once the tree is clean, later runs say "up to date" and never mention it again (1c, `s1c_next.py`). — `update.py:951` (deferred: the host's decision: a branch without an upstream is a normal state; the note is given once, with the half-change report)
- [x] (suggestion) Where `_holds` cannot check the process (no /proc, or a sync run by another user), a running sync is now reported as one that "may have ended", with advice to kill what `fuser` names. Before this diff it said "is still running". — `system.py:505-515`
- [x] (suggestion) The scan does not flag `-P`/`--prune-tags`, a bundled `-pt`, `switch -f`, `--discard-changes`, `branch -f`, or arguments held in a tuple variable. — `update.py` `NEVER`, `tests/test_update_safety.py`

## Checkpoint
**Status**: complete
**When**: 2026-11-19 18:22 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 4 found one must-fix, a password printed in the manifest's refusal lines; a branch that prints a credential is not published; this is the host's first address at this checkpoint for this part)
**After**: rounds
**Decision**: address

Round 4 confirmed the merge of main and all six round 3 points. Its one must-fix: a password holding a quote together with a double quote, or a backslash, and a space is printed whole in the manifest's refusal lines, because the url is quoted with repr before it is masked. The fix is structural, not one more pattern: a url is masked before it is put into any message (the refusal lines of manifest.py and every other place a url is formatted with repr or quotes), and a test walks every message in the tool's source that formats a url. Fixed with it: file urls whose user part holds a colon and no slash are masked too; the design sentence says a tracked change is never carried back; the half-change report prints no "These changes were made by" line when it lists no changes and never ends in an empty line; the lock refusal does not say a sync "may have ended" when it cannot check the process, and does not advise killing what it cannot identify; the forbidden-words scan covers -P, --prune-tags given to a pruning fetch, bundled short flags that include p, switch -f, --discard-changes and branch -f. Left, with the reason on the box: "moved by a person" after sync's own half-changed move when the manifest is then changed back (the record cannot tell the two apart without a new field; noted in the design); the missing upstream mentioned once only (a branch without an upstream is a normal state); a partly moved branch reported as left as it was (needs a fake git; a real fast-forward is all or nothing).

## Implementation
**Status**: complete
**When**: 2026-11-19 18:42 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a5f44b6979a40343e, resume 3 of 3)

**Branch**: feature/issue-500 at `4cc02562`
**Addressed**: Local Review (Pre-Push) at `00ffcba9` (2026-11-19 18:21 -05:00)
**Commits**: 81bdc172, be578f0f, c46c0ecd, 6e79d6ef, cfa593d4, 4cc02562 (box checks)

I reproduced the reviewer's `adv4/s3_e2e.py` first.
- Before the fix: case 0 (`foo::https://u:a'b" c@…`) and case 4 (`ssh://u:a'b" c@127.0.0.1:9`) printed the escaped password `a\'b` in the manifest's refusal, and case 5 printed `SECRETPW` from a `file://` url.
- After the fix: none of the 8 cases prints the password or its escaped form. The probe still lists `c` and `z`, but those are the one-letter last words of the passwords, matched anywhere in the output.

### Actions
- [x] (must-fix) **The structural fix.** A url is masked before it is put into any message. Every place in the tool that formats a url goes through one of two functions in `masking.py`: `mask_url` (masked, plain) or `quoted_url` (masked, then quoted as `repr` would).
  - Changed: the eleven `{url!r}` and the two `{value!r}` of `manifest.py` (used by `resolve`, `validate`, `init` and `sync`), the plan listing in `init.py`, the label of an extends base in `extends.py`, and the repoint lines in `update.py`.
  - Two f-strings that are not messages carry a `# url-text:` reason: the probe's git argument and a hash input.
  - The masking of what is printed stays as the second line of defence.
  - **The source-walking test** (`tests/test_url_messages.py`) parses every module of the package and looks at each value put into text: each f-string `{…}`, each operand of `+` or `%` on text, each `.format` argument, and each direct argument to `print`, `ManifestError`, `Refusal`, `Done` or `warn`. A value whose names (variables, attributes, constant keys) hold "url" or are `origin` must be a call of `mask_url`, `quoted_url`, `mask_urls` or `set_url_command`. Module constants in capitals are message text and not counted.
  - It chooses names over a marker because names are what the code already uses. A second test closes the name gap: a url taken from `.url`, `["url"]` or `self.url(...)` must be stored under a name the scan reads, so a url cannot change its name on the way to a message.
  - What it cannot follow is a url passed as an argument to a parameter with another name (`value` in `manifest.py`). Those functions use `quoted_url` on whatever they get, and the end-to-end test covers them.
  - Run over the previous source, the scan finds the 11 sites in `manifest.py`, 6 in `update.py`, 1 in `init.py` and 2 in `extends.py`.
  - **The end-to-end test** (`test_masking.py`) runs `resolve`, `validate`, `init` and `sync` over manifests in four forms: a repo url, a `foo::https://` url, an ssh url with no path, and a `file://` url. The passwords hold both quotes with a space, a backslash with a space, `%` escapes and letters beyond ASCII, and one user name holds a quote and a space. It greps stdout and stderr for each password, user name, escaped form and decoded form; 11 cases fail at the previous commit.
  - The earlier format's `extends.url` is tested with `resolve` and `validate`. It is refused without being echoed ("Credentials do not belong in a manifest").
  - The repo url is the format's only other url key: `base` takes paths.
- [x] (suggestion a) A `file://` url's `user:password` (a `:` and no `/`) is masked like any other, and a path before an `@` (`file:///srv/w@x/…`) is not. The design sentence is corrected, and a test covers both (81bdc172).
- [x] (suggestion b) The design says a *tracked* change is never carried back. It also says that an untracked or ignored file a hook wrote stays in the work tree and is not reported, because the "left as it was" comparison covers HEAD, branch, config, index and tracked status (be578f0f).
- [x] (suggestion c) The half-change report says "with no tracked changes; sync does not move it back" when it lists none, with no "These changes were made by" line. A report whose git printed nothing ends in a full stop, never an empty line after a colon. Tests: the fast-forward fails and the switch back is refused because a hook wrote an untracked file; and a silent failure (be578f0f).
- [x] (suggestion d) When the process the lock file names runs but its open files cannot be read (no `/proc`, or another user's process), the refusal says it cannot tell whether that is the sync, names the pid with `ps -p <pid> -o user,args` and `fuser -v <lock>`, and gives no advice to kill it. "Has ended" and the kill advice remain for a process that is gone. Tested by making `_holds` return None (c46c0ecd).
- [x] (suggestion e) `NEVER` gains `-P`, `--prune-tags`, `--discard-changes`, `switch -f` and `branch -f`. A test refuses bundled short flags holding `p`, `P` or `f` (`-pt`, `-fq`). `count` and `ask_origin` are scanned as git calls. The scan's docstring says what it cannot see (an argument held in a variable that is not a list literal), and a test holds `update.py` to spreading only argument names the scan reads (6e79d6ef).
- [x] (suggestion) "Moved by a person" after sync's own half-changed move when the manifest is changed back (deferred: the host's decision; the record cannot tell the two apart without a new field, and the design now says so, be578f0f)
- [x] (suggestion) A partly moved branch reported as left as it was (deferred: the host's decision; it needs a fake git, and a real `merge --ff-only` is all or nothing)
- [x] (suggestion) The missing upstream mentioned once only (deferred: the host's decision; a branch without an upstream is a normal state, and the note comes with the half-change report)

### Checks
- Whole suite at `cfa593d4`: `cd tools/repos-manifest && REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest -p no:cacheprovider` gave `1666 passed in 516.62s` (vcs 0.3.0, colcon present).
- `git status --porcelain` is clean. black and flake8 ran in the commit hooks. No workspace script changed. The full pre-commit pass is the host's. Commits used `SKIP=validate-script-tests`.
- I re-read the changed sentences of the tool's `docs/design.md` (masking, the switch back, the half-change report, the record's limit, the lock refusal, the never-run list) and `README.md` (masking now names `init`, `resolve` and `validate`) against the code.

### For the pull request body
Changed from the round 3 entry's text: the masking and the open-on-purpose items. Everything else stands as written there.
- **Masking:** no line `sync`, `init`, `resolve` or `validate` prints, an error included, shows a url's user name or password, whatever characters they hold.
  - Every message that formats a url masks it first (`masking.mask_url` or `quoted_url`), so quoting or `repr` escaping cannot hide it. What is printed is masked again.
  - A test walks the tool's source for every formatted value that names a url, and another runs all four commands over awkward passwords in every url form.
  - Nothing that does not follow `://` is masked: local paths holding `@`, `git@github.com:…` and `origin/main@{upstream}` print as they are. In a `file://` url, a path before an `@` is kept, and a `user:password` is masked.
- **The never-run list:** `sync` never runs reset, `checkout -f`, clean, stash, rebase, pull, push, gc or prune, never deletes a branch, and passes no `--force`, `--no-verify`, `--prune`, `-p`, `-P`, `--prune-tags`, `--discard-changes`, `switch -f`, `branch -f` or a bundled short flag holding `p`, `P` or `f`. A test reads `update.py` for each.
- **Half-changed moves:** the report lists what ran, where HEAD is, and the tracked changes git or a hook made, or says there are none. An untracked or ignored file a hook wrote stays in the work tree and is not reported.
- **Open on purpose:**
  - A repo left alone while the manifest names another version exits 0 (`sync.py:641-654`).
  - The hand-set-origin line prints every run (`update.py:714`).
  - One `ls-remote` per repo per run (`update.py:491`, `find_version` at `update.py:460`).
  - Submodules are never updated (`update.py:962`).
  - A shallow clone grows by the history of fetched tags (`update.py:739`).
  - No version follows the clone's `origin/HEAD` (`update.py:468`).
  - A detached HEAD at a recorded branch's commit is moved on a pin change (`update.py:826-831`).
  - A branch switched by a person during the run is not re-checked (`update.py:875`).
  - An https url whose path holds `@` has more masked (`masking.py:13`).
  - After sync's own half-changed move, a manifest changed back reads the repo as moved by a person (design, sync).
  - A branch left without an upstream by a half-changed move is mentioned once.
  - An untracked file a hook wrote during a move that was undone is not reported.
- **Tests:** 1666 pass with `REPOS_MANIFEST_REQUIRE_COLCON=1`.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 19:01 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-500 at `e260464e`
**Base**: origin/main
**Depth**: Deep (reason: round 5 convergence check per handoff)
**Must-fix**: 3 | **Suggestions**: 3
**Round**: 5 | **Ship**: continue — round 5: 3 must-fix is high; another independent read warranted

Scope: the round 4 findings and `git diff 15a94062..e260464e -- tools/`. Cross-model: skipped (round-5 convergence check, per handoff). The Claude adversarial specialist ran fresh, held to this scope. Static analysis: flake8 is clean under the repo's config. Whole suite at e260464e: `1666 passed in 517.79s` (REPOS_MANIFEST_REQUIRE_COLCON=1).

The round 4 must-fix is fixed for a url given as a string: `foo::https://`, ssh, https and `file://` urls whose passwords hold both kinds of quote with a space, or a backslash, no longer print. The five smaller fixes each have a test that fails when its source hunk is reverted. The one exception is `--prune-tags` (S2 below). Every changed design sentence about the half-change report, the untracked files, the record, the lock refusal and the never-run list is true. The update rules are untouched. But the changed README sentence ("No line `sync`, `init`, `resolve` or `validate` prints, an error included, shows a url's user name and password, whatever characters they hold") and the design's "every message that formats a url does it through one of two functions" are false. The three cases below each print a password; all three were reproduced.

### Findings
- [x] (must-fix) A url that is not a string prints whole. `quoted_url` on a non-str runs `mask_urls(repr(value))` without registering it, and the shape fallback stops at white space. Repro: `repositories: {a: {type: git, url: ["https://aliceQ:pw zQ@127.0.0.1:9/x.git"], version: main}}`, then `validate --manifest m1.yaml` prints `got a list (['https://aliceQ:pw zQ@127.0.0.1:9/x.git'])`. The specialist also saw it through `resolve`, `init` and `sync`, with a mapping, and with a password holding `@` and `/`. — `masking.py:103`, `manifest.py:215`
- [x] (must-fix) A `base:` url is echoed with `!r` and not masked. The scan misses it because the names are `path` and `location`. Repro: `base: "https://aliceQ:pw zQ@127.0.0.1:9/base.git"`, then `validate` prints `base: 'https://aliceQ:pw zQ@127.0.0.1:9/base.git' is a URL, not a path`. The mapping form of `base` prints the whole dict. — `manifest.py:488`, `:493`
- [x] (must-fix) A `file://` user:password is kept whole when the text before the last `@` holds a `/`: `mask_url("file://aliceQ:pw zQ@localhost/srv/w@x")` and `mask_url("file://aliceQ:pw/zQ@localhost/srv/x")` both return the url unchanged, and `init` prints it in its plan. git ignores it, but this makes the changed README sentence ("whatever characters they hold") false. — `masking.py:58`, `README.md:118`
- [x] (suggestion) Gaps in the source-walking scan: a url under another name (`getattr`, a tuple or annotated assignment, a walrus, a for target), a url passed to a helper, `", ".join(...)`, a dict then formatted, logging or `sys.stderr.write`, `prefix + url` with no constant side, `+=`, keyword arguments to `Done` or `Refusal`, and an exception printed as `{exc}`. Its docstring should name these. — `tests/test_url_messages.py`
- [x] (suggestion) The `--prune-tags` entry in `NEVER` has no test that fails without it (the only sample also holds `--prune`). The scan is adjacency-only: `["switch","-q","-f",…]` and `["branch","-q","-f",…]` pass. — `tests/test_update_safety.py:114`, `update.py` `NEVER`
- [x] (suggestion) An unknown top-level key holding a url is warned with `{name!r}` unmasked. — `manifest.py`

## Checkpoint
**Status**: complete
**When**: 2026-11-19 19:02 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 5 found three more ways a credential in a url is printed; this is the host's second address in a row at this checkpoint for this part, so the next answer here is the owner's)
**After**: rounds
**Decision**: address

Round 5 confirmed the update rules untouched and the five small fixes, and found three more paths that print a url's credentials (a url value that is not a string; a base: url; a file url whose user part holds a slash), which make two absolute sentences false: the README's "No line ... shows a url's user name and password, whatever characters they hold" and the design's "every message that formats a url does it through one of two functions". Each round since round 1 has found another such path. The absolute promise was the host's own addition in round 1 (a suggestion about credentials in printed urls); the format's specification says a credential in a url is not looked for, since the manifest is as trusted as the code it names. The host's decision: fix the three paths the cheap and sure way (a value that is not a string, and a base value, are not echoed at all, only described by type; the file url rule), and replace the absolute sentences with what is true: which messages mask a url's user information, how (the two functions and the output filter), what the source-walking test does and the gaps the review listed, and that this is a guard against accidents, not a guarantee, so credentials belong in a credential helper or an ssh key, not in a manifest url. Suggestions fixed with it: the scan's docstring names its gaps; --prune-tags gets its test and the scan looks at every word after the command, not only the next one; an unknown top-level key is not echoed with its value. A stronger guarantee, if the owner wants one, is its own issue; the host proposes it.

## Implementation
**Status**: complete
**When**: 2026-11-19 19:27 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-500 at `9fa1e6f5`
**Addressed**: Local Review (Pre-Push) at `e260464e` (2026-11-19 19:01 -05:00)
**Commits**: 5ae078a3, 14b102f6, 7936cdf2, ab91f9a2, 94755862, 9fa1e6f5 (box checks)

I reproduced each must-fix first. The reviewer's `adv5/drive.py` gave `cases 56 leaks 66` at `4f4efa0a` (the list and mapping urls, and both file url forms, through `validate`, `resolve`, `init` and `sync`), `lead5/m1.yaml` printed the list, `lead5/b1.yaml` printed the `base:` url, and `mask_url` returned both file urls unchanged. At `94755862`: `cases 56 leaks 0`; `m1.yaml` gives `must be a string, got a list; quote it in the YAML ...`; `b1.yaml` gives `base: 'https://***@127.0.0.1:9/base.git' is a URL, not a path`.

### Actions
- [x] (must-fix M1) A value of the wrong type is described, never echoed. `quoted_url` on a value that is not a string returns its kind (`a list`, `a mapping`, `a int`), from `masking.type_name` (moved from `manifest.py`), and `manifest.py`'s "must be a string, got ..." no longer quotes the value. That one message serves `url`, `base`, `version` and `type`; `name()` (layer, group, distro, role names) and the `format:` message describe a wrong-type value the same way (14b102f6).
- [x] (must-fix M2) `base:` as a string goes through `quoted_url`; its mapping form is described ("is a mapping, the form of a file in a git repo"), not shown. Every other value `manifest.py` echoed with `!r` now goes through `quoted_url`: a version, a name, a repeated name, a reserved layer name, a repo key (and the `where` built from it), a type, an unknown top-level, repo or distro key. In `schema.py` (earlier format): a name that fails its rule, case twins and unknown top-level keys. A test now holds `manifest.py` and `schema.py` to no `!r` and no `repr(...)` (14b102f6, 7936cdf2).
- [x] (must-fix M3) In a `file://` url the user information is the text before the last `@` ahead of the first `/` when it holds a `:`; when there is none, the text before the last `@` in the url when that holds a `:` (a password holding a `/`; masks more, never less). Text starting with `/` is a path. `file:///srv/w@x/...`, `file://localhost/srv/w@x` and `file://bobQ@localhost/srv/w@x` stay unmasked; tests cover both sides (5ae078a3).
- [x] (suggestion S1) `tests/test_url_messages.py`'s docstring says the scan is a guard, not a proof, and lists every gap the review named. A test holds the four calls the scan counts as safe to show nothing of a list, a mapping or a number (`quoted_url` describes it, `mask_url`, `mask_urls` and `set_url_command` raise `TypeError`) (7936cdf2).
- [x] (suggestion S2) The never-run scan finds a command's flag anywhere after the command (`["switch", "-q", "-f", ...]`, `["branch", "-q", "-f", ...]`, `["reset", "-q", "--hard", ...]` are flagged), and a `--prune-tags`-only sample fails when `--prune-tags` is taken out of `NEVER`; checked by hand both ways. The commit message of ab91f9a2 says "passes" where it means "would pass unflagged", i.e. the test fails (ab91f9a2).
- [x] (suggestion S3) An unknown top-level key, and an unknown repo or distro key, is named through `quoted_url`: masked when a string, described when not (14b102f6).
- [x] (documents) README and design no longer claim that no line shows a credential; they say where masking happens, that a wrong-type value is described, what the scan checks and cannot see, and that it is a guard, not a guarantee, quoting the specification's "a credential in a `url` is not looked for" (94755862).

Tests that fail without each fix, run against the source at `4f4efa0a` with the new tests: 33 in `test_masking.py` (list, mapping and both file url forms end to end; the three file url unit cases; the type description; the `base:` url, mapping and list; eight keys, names and values holding a url) plus 2 earlier-format cases, and 3 in `test_url_messages.py`. `test_masking.py` now clears the registered urls before each test: before, a url registered by an earlier test masked a later one and hid the file-url leak in the end-to-end test.

### Checks
- Whole suite at `94755862`: `cd tools/repos-manifest && PYTHONDONTWRITEBYTECODE=1 REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest -p no:cacheprovider --basetemp=<scratchpad>` gave `1712 passed in 524.76s (0:08:44)` (1666 before; 46 new).
- black and flake8 ran in the commit hooks. No workspace script changed, so no script suite was run; the full pre-commit pass is the host's. Commits used `SKIP=validate-script-tests`. `git status --porcelain` is clean.
- `update.py`'s rules, `sync.py`'s flow and the build code are unchanged (`git diff 4f4efa0a -- tools/repos-manifest/src/repos_manifest/{update,sync,build}.py` is empty).
- I re-read every masking sentence in `tools/repos-manifest/README.md` and `docs/design.md` (sync section) against `masking.py`, `manifest.py`, `schema.py`, `cli.py` (the `ERROR:` filter) and `sync.py` (its line filter).

### For the pull request body
Changed from the round 4 entry's text: the masking item and one open-on-purpose line. Everything else stands as written there and is copied here.
- **Masking:** a guard against accidents, not a guarantee; a user name and password belong in a credential helper or an ssh key, not in a manifest url (the specification already says a credential in a `url` is not looked for).
  - Where a message formats a url, and where the manifest reader quotes a value from a manifest (a `base:` path, a version, a name, a key), it goes through `masking.mask_url` or `quoted_url`, so quoting or `repr` escaping cannot hide the user information. A value of the wrong type (a list or a mapping given as a url) is described by its kind, never shown.
  - The lines `sync` prints and the `ERROR:` line of any command are masked again as they are printed.
  - A test walks the source for formatted values named as urls, another holds `manifest.py` and `schema.py` to no `!r`/`repr`, and end-to-end tests run `resolve`, `validate`, `init` and `sync` over awkward passwords in every url form, a list and a mapping among them.
  - Nothing that does not follow `://` is masked: local paths holding `@`, `git@github.com:…` and `origin/main@{upstream}` print as they are. In a `file://` url, a path starting with `/` is kept and a `user:password` before the host is masked, also when the path holds an `@` or the password a `/`.
- **The never-run list:** `sync` never runs reset, `checkout -f`, clean, stash, rebase, pull, push, gc or prune, never deletes a branch, and passes no `--force`, `--no-verify`, `--prune`, `-p`, `-P`, `--prune-tags`, `--discard-changes`, `switch -f`, `branch -f` or a bundled short flag holding `p`, `P` or `f`. A test reads `update.py` for each, a command's flag anywhere after the command.
- **Half-changed moves:** the report lists what ran, where HEAD is, and the tracked changes git or a hook made, or says there are none. An untracked or ignored file a hook wrote stays in the work tree and is not reported.
- **Open on purpose:**
  - A repo left alone while the manifest names another version exits 0 (`sync.py:641-654`).
  - The hand-set-origin line prints every run (`update.py:714`).
  - One `ls-remote` per repo per run (`update.py:491`, `find_version` at `update.py:460`).
  - Submodules are never updated (`update.py:962`).
  - A shallow clone grows by the history of fetched tags (`update.py:739`).
  - No version follows the clone's `origin/HEAD` (`update.py:468`).
  - A detached HEAD at a recorded branch's commit is moved on a pin change (`update.py:826-831`).
  - A branch switched by a person during the run is not re-checked (`update.py:875`).
  - An https url whose path holds `@`, or a `file://` url whose password holds `/`, has more masked (`masking.py`).
  - After sync's own half-changed move, a manifest changed back reads the repo as moved by a person (design, sync).
  - A branch left without an upstream by a half-changed move is mentioned once.
  - An untracked file a hook wrote during a move that was undone is not reported.
  - Masking is a guard, not a guarantee. The source scan cannot see a url under another name (`getattr`, tuple, annotated or walrus assignment, a `for` target, a parameter named otherwise), one passed to a helper, joined or formatted inside a list or mapping, `prefix + url` with no constant side, `+=`, keyword arguments, logging or `sys.stderr.write`, or an exception formatted whole; such a message is masked only by the print filter, which covers `sync`'s lines and `ERROR:` lines, and only a url with no white space in its user information when the tool did not read it. Warnings are not filtered. The earlier format's other value-printing messages (`docs/prototype.md` lists them) and an earlier-format `extends` path in its "escapes"/"not found" messages are not masked at the source.
- **Tests:** 1712 pass with `REPOS_MANIFEST_REQUIRE_COLCON=1`.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 19:36 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a586f9fcf3beb71f1, resume 1 of 3)

**Branch**: feature/issue-500 at `7593acc6`
**Base**: origin/main
**Depth**: Deep (reason: round 6 convergence check per handoff)
**Must-fix**: 2 | **Suggestions**: 6
**Round**: 6 | **Ship**: recommended — round 6: 2 mechanical must-fix (prev 3), not rising — fix and ship rather than another full round

Scope: the round 5 findings, the round 5 suggestions and `git diff bd108b2b..7593acc6 -- tools/`. Cross-model: skipped (round-6 convergence check, per handoff). The Claude adversarial specialist ran fresh with the same scope and must-fix rule. Whole suite at 7593acc6: `1712 passed in 524.35s` (REPOS_MANIFEST_REQUIRE_COLCON=1).

Round 5 must-fix:
- M1 (url not a string): fixed. `lead5/m1.yaml` now gives `must be a string, got a list; …`.
- M2 (`base:` url): fixed. `lead5/b1.yaml` now gives `base: 'https://***@127.0.0.1:9/base.git' is a URL, not a path`.
- M3 (`file://` user:password with a `/`): fixed. `adv5/drive.py` gives `cases 56 leaks 0`.

Round 5 suggestions:
- S1 (the scan's gaps): fixed. The docstring names them, and the safe-call test holds.
- S2 (`--prune-tags`): fixed. It has a test that fails without it, and the scan reads every word after the command; a flag after `--` is flagged, which errs on the safe side.
- S3 (unknown key): fixed. The key is named through `quoted_url`.

Other checks:
- Test isolation: no other test file depends on urls registered earlier. The test files pass alone and in both orders.
- `update.py`, `sync.py` and `build.py` are unchanged in this range.

### Findings
- [x] (must-fix) The design's "the `ERROR:` line of any command are masked again", and the README's "the error a command stops with", are false. Only a `ManifestError` (`cli.py:331`) and sync's lines are masked; `cli.py:128`, `:136`, `:159`, `signals.py:52` and `sync.py:612` print raw. Repro: `resolve --manifest p4.yaml --role 'https://alice:s3cret@h/x' --distro jazzy --out o4` prints `ERROR: unknown role 'https://alice:s3cret@h/x' (known: ['dev'])`. The value is typed by the user. Narrow both sentences, or mask those prints. — `docs/design.md` (masking, "As lines are printed"), `README.md:117-118`
- [x] (must-fix) The design gives the `file://` fallback as "for a password holding a `/`", but `_file_userinfo` applies it to any `file://host/...` url whose text before the last `@` holds a `:`. A url with no credential then has its host and path masked: `mask_url("file://localhost/srv/a:b/w@x")` gives `file://***@x`. With a real repo at such a path, `init` shows `file://***@x`, and sync's hand-set-origin line shows `origin is file://***@x, the manifest says file://***@x` with a `set-url` command that fails if copied. State the real condition and this consequence, or tighten the rule. — `docs/design.md` (`file://` rule), `masking.py` `_file_userinfo`
- [x] (suggestion) The docstring of `tests/test_url_messages.py` says the third test holds `manifest.py` and `schema.py` "to echo a value only through `quoted_url`". It checks only `!r` and `repr(`. `schema.py` still echoes `'{layer}'` (`:265`, `:275`) and whole lists (`:255`, `:262`, `:267`, `:276`). A repo key that is a url with a space in its password is printed by `validate`, earlier format (`adv6/p1-p3.yaml`). The design's limits cover those messages. — `tests/test_url_messages.py`
- [x] (suggestion) The top docstring of `tests/test_masking.py` still says a url's credentials are "never printed". — `tests/test_masking.py:1-3`
- [x] (suggestion, leak route, covered by the limits) The scp-like `aliceQ:pwzQ@127.0.0.1:x.git` passes `validate` and is printed whole in the `init` plan. Covered by "nothing that does not follow `://` is masked". — `masking.py`
- [x] (suggestion, leak route, not in the limits) `!r` echoes outside the manifest readers: `system.py:379`, `:643` (format of `state.yaml` and the built file), and `selection.py:61-86` and `init.py:62-92` (command-line role and distro). None takes a manifest url. — `system.py`, `selection.py`, `init.py`
- [x] (suggestion) Warnings are not filtered (`system.warn`). The progress entry says so; the design's limits do not. — `docs/design.md`
- [x] (suggestion) `test_pruning_flags_are_forbidden_and_no_prune_is_not` still lists `["fetch","--prune-tags"]` as `False`, which reads as if it were allowed. The never-run list also misses `+refs/...` forced refspecs, `reset --merge`/`--keep`, `checkout -B` and `update-ref -d`; these gaps predate this diff. — `tests/test_update_safety.py`

## Checkpoint
**Status**: complete
**When**: 2026-11-19 20:08 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: rounds
**Decision**: address

The owner was shown round 6's two must-fix verbatim (the changed sentences about error lines claim more than the code masks; the design states the wrong condition for the file:// fallback rule, and a file url with no credential whose path holds both a colon and an at sign gets its host and path masked), that the update rules have held since round 3, and four options: fix both then publish, publish now, drop the masking from this pull request, or stop. His answer: "Fix both, then publish (Recommended)" (one short pass: narrow the two sentences to what is true, and tighten the file:// rule so a path is never masked; then a narrow check of only that, the full local pass, and the pull request).

## Implementation
**Status**: complete
**When**: 2026-11-19 20:22 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent ae5fd1d2f18230daa, resume 1 of 3)

**Branch**: feature/issue-500 at `022ccad0`
**Addressed**: Local Review (Pre-Push) at `7593acc6` (2026-11-19 19:36 -05:00)
**Commits**: 0b8b4005, ecb00ada, d613429e, 022ccad0 (box checks)

This pass follows the owner's answer in the round 6 checkpoint: narrow the two sentences and tighten the `file://` rule, nothing more. The only code change is `_file_userinfo` and `_kept` in `masking.py`; no print site was added to the filter.

### Actions
- [x] (must-fix 1) The design and README name exactly which lines the print filter covers. Covered: each line `sync` prints for a repo (`_say`, and a repo's notes, `sync.py:328-334`, `:418`), sync's `ERROR:` line for a distro whose plan or run failed (`sync.py:628`, `:635`), and the `ERROR:` line of a `ManifestError` (`cli.py:331`). Printed as given: the earlier format's "unknown role" error (`cli.py:128`, `:159`), the stop line of a signal (`signals.py:52`), sync's setup-file line (`sync.py:612`, `:614`), and every `WARNING:` line (`system.warn`) (ecb00ada, d613429e).
- [x] (must-fix 2) A `file://` url's user information is only in its authority, the text between `file://` and the first `/`: the text before the last `@` there, when it holds a `:`. The fallback to the last `@` in the whole url is gone, and `_kept` keeps any `file://` text holding a `/`, so the shape filter cannot mask a path either. `file://localhost/srv/a:b/w@x` and its neighbours print whole; an end-to-end test runs a system under `a:b/w@x` with a hand-set origin, checks that nothing is masked, and runs the printed `set-url` command, which sets the manifest's url. `file://user:pw@host/path` is still masked. The two cases that relied on the fallback (`file://aliceQ:pw/zQ@localhost/srv/x`, `file://u@sQ:p:w/@zQ@localhost/srv/w@x`) are now listed as not masked, and the end-to-end form "file url, / in its password" is removed. Six tests fail on the previous source (0b8b4005).
- [x] (suggestion) The docstring of `tests/test_url_messages.py` says the reader test checks for `!r` and `repr(` only, and that `schema.py` still echoes some values as they are (ecb00ada).
- [x] (suggestion) The top docstring of `tests/test_masking.py` no longer says "never printed" (0b8b4005).
- [x] (suggestion) The scp-like form `user:password@host:path` is in the design's list of what is not masked, and the README now says it masks a `scheme://` url's user name and password (ecb00ada, d613429e).
- [x] (suggestion) Messages outside the manifest readers that echo a value typed on the command line or read from the tool's record files are in the list of what is not masked, unless the filter covers their line (ecb00ada).
- [x] (suggestion) Warnings are in the list of what is not masked (ecb00ada).
- [x] (suggestion) `test_pruning_flags_are_forbidden_and_no_prune_is_not` now checks every `NEVER` entry, so the `["fetch", "--prune-tags"]` sample is marked forbidden (`True`). The older gaps (`+refs/...` forced refspecs, `reset --merge`/`--keep`, `checkout -B`, `update-ref -d`) are named in the test file's docstring and left as they are (ecb00ada).

### Checks
- Whole suite at `ecb00ada` (code and tests as at the head; `d613429e` changes only the README, and `tests/test_documents.py` passes after it, 11 passed): `cd tools/repos-manifest && PYTHONDONTWRITEBYTECODE=1 REPOS_MANIFEST_REQUIRE_COLCON=1 PYTHONPATH=src /usr/bin/python3 -m pytest -p no:cacheprovider --basetemp=<scratchpad>` gave `1713 passed in 522.27s (0:08:42)` (1712 before; one new test, and one end-to-end form fewer with new unit cases).
- black and flake8 ran in the commit hooks. No workspace script changed; the full pre-commit pass is the host's. Commits used `SKIP=validate-script-tests`. `git status --porcelain` is clean.
- `update.py`, `sync.py`, `build.py`, `cli.py` and `signals.py` are unchanged.
- I read every sentence about masking in `tools/repos-manifest/README.md` and `docs/design.md` (sync section) against `masking.py`, `manifest.py`, `schema.py`, `cli.py`, `signals.py`, `sync.py` and `system.py`. Each is true as it now stands. The README's "an error that echoes a value typed on the command line" is an example: the new format's unknown role or distro is a `ManifestError`, so its line passes the filter, which masks a url by its shape when its user information has no white space.

### For the pull request body
Changed from the round 5 entry's text: the masking item and the masking lines under "open on purpose". Everything else stands as written there and is copied here.
- **Masking:** a guard against accidents, not a guarantee; a user name and password belong in a credential helper or an ssh key, not in a manifest url (the specification already says a credential in a `url` is not looked for).
  - Where a message formats a url (as far as the source scan sees), and where the manifest reader quotes a value from a manifest (a `base:` path, a version, a name, a key), it goes through `masking.mask_url` or `quoted_url`, so quoting or `repr` escaping cannot hide a `scheme://` url's user information. A value of the wrong type (a list or a mapping given as a url) is described by its kind, never shown.
  - These lines are masked again as they are printed: each line `sync` prints for a repo, sync's `ERROR:` line for a distro whose plan or run failed, and the `ERROR:` line of a manifest that cannot be read or is refused (the tool's own kind of error). Other lines are printed as given.
  - In a `file://` url, user information is only the text before the last `@` in the authority (between `file://` and the first `/`), when it holds a `:`; a path is never masked.
  - Nothing that does not follow `://` is masked: local paths holding `@`, `git@github.com:…` and `origin/main@{upstream}` print as they are.
  - Tests: a source scan for formatted values named as urls; no `!r`/`repr(` in `manifest.py` and `schema.py`; end-to-end runs of `resolve`, `validate`, `init` and `sync` over awkward passwords in every url form, a list and a mapping among them.
- **The never-run list:** `sync` never runs reset, `checkout -f`, clean, stash, rebase, pull, push, gc or prune, never deletes a branch, and passes no `--force`, `--no-verify`, `--prune`, `-p`, `-P`, `--prune-tags`, `--discard-changes`, `switch -f`, `branch -f` or a bundled short flag holding `p`, `P` or `f`. A test reads `update.py` for each, a command's flag anywhere after the command.
- **Half-changed moves:** the report lists what ran, where HEAD is, and the tracked changes git or a hook made, or says there are none. An untracked or ignored file a hook wrote stays in the work tree and is not reported.
- **Open on purpose:**
  - A repo left alone while the manifest names another version exits 0 (`sync.py:641-654`).
  - The hand-set-origin line prints every run (`update.py:714`).
  - One `ls-remote` per repo per run (`update.py:491`, `find_version` at `update.py:460`).
  - Submodules are never updated (`update.py:962`).
  - A shallow clone grows by the history of fetched tags (`update.py:739`).
  - No version follows the clone's `origin/HEAD` (`update.py:468`).
  - A detached HEAD at a recorded branch's commit is moved on a pin change (`update.py:826-831`).
  - A branch switched by a person during the run is not re-checked (`update.py:875`).
  - An https url whose path holds `@` has more masked (`masking.py`).
  - After sync's own half-changed move, a manifest changed back reads the repo as moved by a person (design, sync).
  - A branch left without an upstream by a half-changed move is mentioned once.
  - An untracked file a hook wrote during a move that was undone is not reported.
  - The never-run list does not cover `+refs/...` forced refspecs, `reset --merge`/`--keep`, `checkout -B` or `update-ref -d`; `update.py` runs none of them.
  - Masking is a guard, not a guarantee. Not masked: a `file://` url whose password holds a `/` (it cannot be told from a path; git's file transport ignores it); the scp-like `user:password@host:path`; values the earlier format's reader still prints as they are (`docs/prototype.md` lists them); every `WARNING:` line; the earlier format's "unknown role" error, a signal's stop line and sync's setup-file line; messages outside the manifest readers that echo a value typed on the command line or read from the tool's record files, unless the filter covers their line; and a url reaching a message by a way the source scan cannot see (another name, a helper, a join, a list or mapping formatted whole, keyword arguments, `+=`, logging, an exception formatted whole) on a line the filter does not cover, or one the tool did not read with white space in its user information.
- **Tests:** 1713 pass with `REPOS_MANIFEST_REQUIRE_COLCON=1`.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 20:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a586f9fcf3beb71f1, resume 2 of 3)

**Branch**: feature/issue-500 at `b9302842`
**Base**: origin/main
**Depth**: Deep (reason: round 7 convergence check per handoff)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 7 | **Ship**: recommended — round 7: 2 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

Scope: the round 6 findings and `git diff b8e35602..b9302842 -- tools/`. Cross-model: skipped (round-7 convergence check, per handoff). A fresh Claude adversarial specialist ran with the same scope and must-fix rule. Whole suite at b9302842: `1713 passed in 521.99s` (REPOS_MANIFEST_REQUIRE_COLCON=1).

Both round 6 must-fix are resolved:
- **The error-line sentences:** the design's "As some lines are printed" bullet is true line by line. `Refusal` subclasses `ManifestError` (`system.py:61`), so every refusal reaches `cli.py:331`. `sync.py:628` and `:635` are filtered. `signals.py:52`, `sync.py:612` and `:614`, and `WARNING:` lines are printed as given. The earlier format's unknown role is printed as given. The README is the exception (below).
- **The `file://` rule:** it matches `_file_userinfo` and `_kept`. No path is masked: `file://localhost/srv/a:b/w@x`, `…/a:b@x` and `file:///srv/a:b@c` print as they are. A `user:password` in the authority is masked through `mask_url`, `quoted_url` and the fallback; this was checked with `FILE://`, with a port, and with no path. The new end-to-end test runs the printed `set-url` command, and it fails on the old `masking.py`.

Other checks:
- The "What is not masked" list is true item by item.
- The prune-tags test fails when `--prune-tags` is removed from `NEVER`.
- `update.py`, `sync.py`, `build.py`, `cli.py` and `signals.py` are unchanged.

### Findings
- [x] (must-fix) The README's "Other lines, such as an error that echoes a value typed on the command line, are printed as given" is false for the current format. There, an unknown role or distro is a `ManifestError`, and its line passes the filter: `validate --manifest tests/fixtures/project11/project11.manifest.yaml --role 'https://alice:s3cret@h/x'` prints `has no role 'https://***@h/x'`. Only the earlier format prints it as given; the design says so correctly. Match the design. — `README.md:121-122`
- [x] (must-fix) The new docstring says "nothing in `update.py` runs these today: a forced refspec (`+refs/...`), … and `update-ref -d`". But `update.py:737` and `:1085` fetch with `+refs/heads/*:refs/remotes/…`, and `update.py:230` runs `update-ref -d` on probe refs. They touch only remote-tracking and probe refs, so the sentence should say that. — `tests/test_update_safety.py:6-8`
- [x] (suggestion) "Each line `sync` prints for a repo" is not quite true: `cloning <path>` (`sync.py:242`) and "holds the manifest" (`sync.py:524`) are not filtered. They cannot carry a `scheme://` url, since a repo key cannot hold `//`. — `docs/design.md:916-918`
- [x] (suggestion) "Other lines are printed as given:" reads as a complete list. It leaves out the earlier format's `--out` error (`cli.py:136`), the earlier format's `validate` table and violation lines (`cli.py:165-170`), and build's NOTE and report lines. Limits item 5 covers these; "among them:" would read truer. — `docs/design.md:924-927`
- [x] (suggestion) The `_say` docstring still says the user name and password "are never printed", which the limits list now contradicts. That line is outside this range. — `sync.py:325`

## Checkpoint
**Status**: complete
**When**: 2026-11-19 20:32 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 7 found two one-sentence wording must-fix and three wording suggestions, no behaviour; the owner's answer at the previous rounds checkpoint was to fix and then publish, and these are fixed in that same spirit; the previous answer here was the owner's, so this is the host's first in a row)
**After**: rounds
**Decision**: address

All five are sentences, fixed as the review states them: the README's example of a line printed as given is made true for the current format (it names the earlier format's unknown-role error, as the design does); the docstring of tests/test_update_safety.py says which forced refspec and which update-ref -d the update module does run (remote-tracking refs and its own probe refs only) and what the scan does not look for; the design's "each line sync prints for a repo" names the two lines that are not filtered and why they cannot hold a scheme url; "Other lines are printed as given" reads "among them"; the _say docstring in sync.py no longer says credentials are never printed. No code behaviour changes.

## Implementation
**Status**: complete
**When**: 2026-11-19 20:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent ae5fd1d2f18230daa, resume 2 of 3)

**Branch**: feature/issue-500 at `a4d8da8c`
**Addressed**: Local Review (Pre-Push) at `b9302842` (2026-11-19 20:31 -05:00)
**Commits**: a4d8da8c (sentences and box checks)

Sentences only: no behaviour changed. The one source file touched is a docstring in `sync.py`.

### Actions
- [x] (must-fix) README: "Other lines are printed as given: for example, the "unknown role" error of an earlier-format manifest, which echoes the role typed on the command line (in the current format that error passes the filter)." Checked against `cli.py`: the earlier format prints it at `cli.py:128` and `:159` with no filter; in the current format `selection.py` raises a `ManifestError`, which `cli.py:331` prints through `mask_urls`. The README also now says "the lines `sync` prints for a repo's outcome" (a4d8da8c).
- [x] (must-fix) `tests/test_update_safety.py` docstring: `update.py` fetches with a forced refspec into remote-tracking refs (`update.py:737`, `+refs/heads/*:refs/remotes/origin/*`) and into its own probe refs (`:1085`), and runs `update-ref -d` only on those probe refs (`:230`, `delete_probe_refs`). Neither touches a local branch, a tag or the work tree. The scan looks for none of these forms, nor for `reset --merge`/`--keep` or `checkout -B`; grep finds no `reset` or `checkout` call in `update.py`, only their names in `NEVER` and in messages (a4d8da8c).
- [x] (suggestion) Design: the filter covers "each line `sync` prints for a repo's outcome". The two lines it does not cover, `cloning <path>` (`sync.py:242`) and "<path>: holds the manifest, …" (`sync.py:524`), are named. They show only the repo key, which cannot hold a `scheme://` url because a repo key has no `//` (a4d8da8c).
- [x] (suggestion) Design: "Other lines are printed as given, among them:" (a4d8da8c).
- [x] (suggestion) `_say` docstring: what `sync` or git says goes through the masking filter (`mask_urls`) "within the limits the design lists"; it no longer says "never printed" (a4d8da8c).

### The grep
I grepped `tools/repos-manifest` (source, tests, documents) for "never printed", "never shown", "whatever characters", "every message" and "any command". I fixed `sync.py:325`. The other hits are true as written, so I left them:
- `manifest.py:186`, `schema.py:166` and `masking.py:137` ("never shown") are about a value of the wrong type, which is described by its kind and not shown.
- `masking.py:7` ("whatever characters it holds") is about how a registered url's user information is parsed, with the `file://` exception stated next to it.
- `extends.py:290` (git's output "never printed") is about the earlier format's extends clone, whose output is captured.
- `output.py:287` ("Every message") is not about masking.
- `design.md` ("every message of the manifest reader that quotes a value", "the `ERROR:` line any command ends with when it stops on the tool's own kind of error") is true as qualified.
- `prototype.md:154` ("a `url` or `ref` that fails its rule is never printed") is about the earlier format and is true.
- No test file matched.

### Checks
- `cd tools/repos-manifest && PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=src /usr/bin/python3 -m pytest -p no:cacheprovider tests/test_documents.py tests/test_update_safety.py tests/test_masking.py tests/test_url_messages.py`: `239 passed in 32.77s`.
- I did not run the whole suite for this sentences-only pass: the host's full pass and CI run it. The last whole run was `1713 passed` at `ecb00ada`, and the reviewer's at `b9302842` also gave 1713.
- black and flake8 ran in the commit hook. No workspace script changed. The commit used `SKIP=validate-script-tests`. `git status --porcelain` is clean.

### For the pull request body
Changed from the round 6 entry's text: the second masking line and the never-run line under "open on purpose". Everything else stands as written there and is copied here.
- **Masking:** a guard against accidents, not a guarantee; a user name and password belong in a credential helper or an ssh key, not in a manifest url (the specification already says a credential in a `url` is not looked for).
  - Where a message formats a url (as far as the source scan sees), and where the manifest reader quotes a value from a manifest (a `base:` path, a version, a name, a key), it goes through `masking.mask_url` or `quoted_url`, so quoting or `repr` escaping cannot hide a `scheme://` url's user information. A value of the wrong type (a list or a mapping given as a url) is described by its kind, never shown.
  - These lines are masked again as they are printed: each line `sync` prints for a repo's outcome, sync's `ERROR:` line for a distro whose plan or run failed, and the `ERROR:` line of the tool's own kind of error (a manifest that cannot be read or is refused, a system or a record in the wrong state). Other lines are printed as given, for example the earlier format's "unknown role" error.
  - In a `file://` url, user information is only the text before the last `@` in the authority (between `file://` and the first `/`), when it holds a `:`; a path is never masked.
  - Nothing that does not follow `://` is masked: local paths holding `@`, `git@github.com:…` and `origin/main@{upstream}` print as they are.
  - Tests: a source scan for formatted values named as urls; no `!r`/`repr(` in `manifest.py` and `schema.py`; end-to-end runs of `resolve`, `validate`, `init` and `sync` over awkward passwords in every url form, a list and a mapping among them.
- **The never-run list:** `sync` never runs reset, `checkout -f`, clean, stash, rebase, pull, push, gc or prune, never deletes a branch, and passes no `--force`, `--no-verify`, `--prune`, `-p`, `-P`, `--prune-tags`, `--discard-changes`, `switch -f`, `branch -f` or a bundled short flag holding `p`, `P` or `f`. A test reads `update.py` for each, a command's flag anywhere after the command.
- **Half-changed moves:** the report lists what ran, where HEAD is, and the tracked changes git or a hook made, or says there are none. An untracked or ignored file a hook wrote stays in the work tree and is not reported.
- **Open on purpose:**
  - A repo left alone while the manifest names another version exits 0 (`sync.py:641-654`).
  - The hand-set-origin line prints every run (`update.py:714`).
  - One `ls-remote` per repo per run (`update.py:491`, `find_version` at `update.py:460`).
  - Submodules are never updated (`update.py:962`).
  - A shallow clone grows by the history of fetched tags (`update.py:739`).
  - No version follows the clone's `origin/HEAD` (`update.py:468`).
  - A detached HEAD at a recorded branch's commit is moved on a pin change (`update.py:826-831`).
  - A branch switched by a person during the run is not re-checked (`update.py:875`).
  - An https url whose path holds `@` has more masked (`masking.py`).
  - After sync's own half-changed move, a manifest changed back reads the repo as moved by a person (design, sync).
  - A branch left without an upstream by a half-changed move is mentioned once.
  - An untracked file a hook wrote during a move that was undone is not reported.
  - The never-run scan does not look for forced refspecs or `update-ref -d`. `update.py` uses them only on remote-tracking refs and its own probe refs, never on a local branch, a tag or the work tree. It also does not look for `reset --merge`/`--keep` or `checkout -B`, which `update.py` does not run.
  - Masking is a guard, not a guarantee. Not masked: a `file://` url whose password holds a `/` (it cannot be told from a path; git's file transport ignores it); the scp-like `user:password@host:path`; values the earlier format's reader still prints as they are (`docs/prototype.md` lists them); every `WARNING:` line; the earlier format's "unknown role" error, a signal's stop line and sync's setup-file line; messages outside the manifest readers that echo a value typed on the command line or read from the tool's record files, unless the filter covers their line; and a url reaching a message by a way the source scan cannot see (another name, a helper, a join, a list or mapping formatted whole, keyword arguments, `+=`, logging, an exception formatted whole) on a line the filter does not cover, or one the tool did not read with white space in its user information.
- **Tests:** 1713 pass with `REPOS_MANIFEST_REQUIRE_COLCON=1` (last whole run at `ecb00ada`; this pass changed sentences only).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-19 20:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a586f9fcf3beb71f1, resume 3 of 3)

**Branch**: feature/issue-500 at `00f2ea1c`
**Base**: origin/main
**Depth**: Deep (reason: round 8 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 8 | **Ship**: recommended — no must-fix findings

Scope: `git diff d69c85ff..00f2ea1c -- tools/`: four files, five sentences, no code. Cross-model: skipped (round-8 convergence check, per handoff). No adversarial specialist ran; the handoff waived it for a diff of five sentences.

Tests: `tests/test_documents.py`, `test_update_safety.py`, `test_masking.py` and `test_url_messages.py` give `239 passed in 32.55s`.

The five sentences are each true:
1. **README:** the masked lines (`_say`, a `ManifestError`) are as stated. The "unknown role" example is right in both formats: the earlier format prints it as given (`cli.py:128`, `:159`); the current one passes the filter (round 7 repro: `has no role 'https://***@h/x'`).
2. **The `test_update_safety.py` docstring:** the forced refspecs are at `update.py:737` (into `refs/remotes/origin/*`) and `:1085` (into `refs/remotes/repos-manifest-probe/*`). `update-ref -d` runs only over `refs/remotes/repos-manifest-probe/` (`update.py:228-231`). No `reset --merge`, `reset --keep` or `checkout -B` is run.
3. **The design's filter bullet:** the `cloning` line (`sync.py:242`) and the "holds the manifest" line (`sync.py:526`) are the unfiltered ones. Neither can hold `://`: a repo key has no `//` (`manifest.py:513`), and the distro and layer names in the path are single words (`manifest.py:42`).
4. **"Other lines are printed as given, among them":** true; `signals.py:52`, `sync.py:612` and `system.warn` print raw.
5. **The `_say` docstring:** true; it masks with `mask_urls(done.detail)`.

Spot-checked leftover wording, all true: `manifest.py:186`, `schema.py:166`, `masking.py:7` and `:137`, `extends.py:290`, and `design.md:912`.

### Findings
- [ ] (suggestion) "they show only the repo's path, its key" equates the path with the key. The path is the distro and layer directories, `src`, then the key (`sync.py:232`). The conclusion holds, since those names are single words. "its path, made of single-word names and its key" would be exact. — `docs/design.md:924-926`

## Checkpoint
**Status**: complete
**When**: 2026-11-19 20:36 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 8 approved with no must-fix; the host's full pre-commit pass over the branch passed at fa98c208, every hook, no SKIP; the owner's answer at the round 6 checkpoint was to fix and then publish)
**After**: publish
**Decision**: publish

Round 8 approved the branch with one wording suggestion, which the pull request lists. The full pass ran on head fa98c208 with exit 0. The pull request says "Part of #500": parts 3 and 4 are not delivered, and the owner's by-hand acceptance on his real project is not done.

## Local Review
**Status**: complete
**When**: 2026-11-19 20:46 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #535 at `75549803`
**Depth**: Deep (reason: 7092+/254- lines over 31 files; safety-critical git mutation of a person's clones)
**Must-fix**: 5 | **Suggestions**: 10

Point 1 (real systems made with init from local remotes, record without urls): clone switched to rolling by hand: up to date, record now rolling with url, no clone change; clone on jazzy clean: moved to rolling (untracked and ignored files kept, upstream set); on rolling with 1 local commit: left alone, "has 1 commits not on origin", record stays jazzy; on jazzy with a tracked edit: left alone, "has uncommitted changes (1 files)". Second sync quiet each time. Hand-set origin: never repointed, one line per run. Lock both ways: refused and reported. Suite: 1713 passed (REPOS_MANIFEST_REQUIRE_COLCON=1). Cross-model: codex complete (7 findings, 2 reproduced); gemini failed twice (headless tool denial, empty response).

### Findings
- [ ] (must-fix) Fast-forward (rule 10) moves a branch also checked out in another work tree (`git worktree add -f`): that tree then shows the upstream commits reversed as staged changes; design says a linked work tree's branch is never moved; check `worktree_holding` before the merge — `tools/repos-manifest/src/repos_manifest/update.py:793`
- [ ] (must-fix) `version: heads/<branch>` (spec-valid; init clones it) makes every sync exit 1 with the false "version heads/jazzy is not on origin"; strip `heads/`/`tags/` as the manifest reader does — `tools/repos-manifest/src/repos_manifest/update.py:491`
- [ ] (must-fix) Probe cleanup `update-ref -d` follows a symbolic ref: a symref under refs/remotes/repos-manifest-probe/ to refs/heads/topic made sync delete branch topic; use `--no-deref` (precondition contrived, fix one word) — `tools/repos-manifest/src/repos_manifest/update.py:230`
- [ ] (must-fix) False doc sentences: README and design say the report gives the `git pull --rebase` command for commits not on origin, but it is printed only when origin's branch has commits the clone lacks (not in the owner's case); design "the url rule counts its commits" is false for a detached linked work tree (repoint went ahead) — `tools/repos-manifest/README.md:128`, `tools/repos-manifest/docs/design.md:691`, `tools/repos-manifest/docs/design.md:853`
- [ ] (must-fix) PR body: "A system made before the record held urls is never repointed" is false once its first sync records the url (reproduced: repointed); "nothing in rounds 4 to 8 touched [the update rules]" is false (3fa23a13 changed the undo condition in `_change`); "branch deletion" never run is false while the symref case stands; the pull --rebase line is conditional — PR #535 body
- [ ] (suggestion) A stale origin/release blocks origin's new release/next: every sync fails, and the closing line says "once they can be fetched" though another sync will not change it — `tools/repos-manifest/src/repos_manifest/update.py:737`
- [ ] (suggestion) An existing remote named repos-manifest-probe makes `-c remote.<probe>.url` append, so the probe fetches the person's remote, not the manifest url (codex; not reproduced) — `tools/repos-manifest/src/repos_manifest/update.py:1080`
- [ ] (suggestion) Branch names unquoted in the printed `git config branch.<b>...` commands — `tools/repos-manifest/src/repos_manifest/update.py:1061`
- [ ] (suggestion) A tag that peels to a tree or blob gives an empty target and ends as left alone with exit 0 (codex; not reproduced) — `tools/repos-manifest/src/repos_manifest/update.py:507`
- [ ] (suggestion) `CLOBBERED_TAG` matches English git output only; set LC_ALL=C/LANGUAGE in `Git.env` — `tools/repos-manifest/src/repos_manifest/update.py:86`
- [ ] (suggestion) No minimum git version is checked; tag non-clobbering needs >= 2.20, switch >= 2.23 — `tools/repos-manifest/docs/design.md:1686`
- [ ] (suggestion) Detached HEAD is switched without re-reading HEAD right before the call (small race; a commit made there would be left to the reflog) — `tools/repos-manifest/src/repos_manifest/update.py:846`
- [ ] (suggestion) `_half_changed` blames git or a hook for a tracked edit a person made during the move — `tools/repos-manifest/src/repos_manifest/update.py:1007`
- [ ] (suggestion) "has 1 commits"; and the c1 case records rolling with only "up to date (2)" printed, naming no repo — `tools/repos-manifest/src/repos_manifest/update.py:781`
- [ ] (suggestion) Acceptance block: the editable install runs from /home/roland/agent_workspace, so it has the change only once that checkout is pulled after the merge — PR #535 body
