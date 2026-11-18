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
