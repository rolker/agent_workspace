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
