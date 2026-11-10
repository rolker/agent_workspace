# Plan: run-issue: drive an issue in a package repository of a multi-repository project

## Issue

https://github.com/rolker/agent_workspace/issues/429

## Context

`/run-issue` cannot drive an issue whose code lives in a package repository of a multi-repository
project (`--issue owner/repo#N`, worked in an ADR-0012 package worktree). The Issue Review split the
acceptance ("reaches the merge checkpoint without hand steps") into four mechanisms. The owner's
direction (2026-11-10): "I think project11 on pickerel is not too far off, so let's not wait on other
stuff for that. We can do stuff in parallel."

**Where a package issue's records live is already settled.** The owner, 2026-11-10: "Did we not already
settle on 3 for this? It's configurable so that projects that want to keep it in the repo can and
projects where we don't want to leave a footprint, we can pick a different location. I think we might
also have settled defaults that can get overridden for both cases right?" Yes. `docs/design.md`,
Worktrees, Target: a project carries its records by choice through `location` (`project` or `outside`
at `location_path`), `tracking` (`untracked`, `project`, `repo`) and defaults from
`project_records_default` in `.agent/scripts/_project_registry.sh` ("(project, project) for a project
whose file says nothing"). The Target says: "Built in #332: the settings, their validation, and the
refusal to store any combination but the default ... Built by #393: mechanisms 1 to 3 below, and
honouring the other combinations." Issue 393 (records lookup) says: "Build the records lookup ... one
place that answers 'where are the records (work plan and progress timeline) for this project and this
issue'". So a package issue's records follow the project's records settings, and this issue's part 1 is
the work 393 describes, with a package issue as its consumer. No question about it goes to the owner.

What conflicts today: Worktrees, Records says "An issue in a package repository ... has no timeline: a
package worktree is a folder of several repositories, not one repository, so `merge_pr.sh` posts its
gate record on the pull request", while the same bullet's general rule says records are "committed in
the repository that owns the issue ... on the issue's feature branch". The package repository that owns
the issue is a real git worktree inside the package worktree (`.worktree-repos` lines
`<origin>\t<rel>\t<branch>`, header `# project=… issue=… layer=…`), so the general rule can apply. The
loop needs a timeline ("`progress.md` is the only place loop state lives", Review loop).

Issue 393's "Unsettled, to decide here" lists four items; this plan decides each below (Decisions).
Issue 393's text is not edited. Its line "Package-repository issues (`owner/repo#N`) have no timeline
today and stay so" is reversed by this work, and the part 1 pull request says so.

## Approach

Four parts on this one issue, each its own pull request; no new issues. Parts 2 and 3 can run in
parallel after part 1; part 4 closes.

1. **Part 1, records for a package issue** (detailed below): the records lookup of 393 (mechanism 1
   everywhere, mechanism 2 for the package case), honouring the default combination for a package issue.
2. **Part 2, worktree creation and phase dispatch from a project-rooted session** (outline): a run
   started with only `owner/repo#N` creates the package worktree (`worktree_create.sh --type project
   --issue owner/repo#N --layer … --package-repos …`) and enters it with `cd`; the layer and
   `--package-repos` rule: infer the layer from the project's adapter (`worktree_repos`/manifest) and use
   the issue's repository alone, with the issue or a flag able to name more; `dispatch_phase.sh` starts the
   sub-agent in the package worktree and passes the lookup's records path (`wt=` and the exit contract
   already use `$wt/.agent/work-plans/...`, which part 1 replaces by the lookup); `run-issue` passes the
   qualified ref where it passes `--issue` today; `WORKTREE_ISSUE` for a qualified issue. Detail when
   its turn comes.
3. **Part 3, the package pull request path** (outline): publish target is the repository named in
   `owner/repo#N` (AGENTS.md: "Issues and PRs live in whichever repo owns the code being changed");
   `review-code` reads that repository's diff against its base; `merge_pr.sh` gate and cleanup across the
   manifest repositories (sibling-PR check already exists, lines ~1445-1530). Whether the package gate
   turns blocking is decided here (see Decisions). Detail when its turn comes.
4. **Part 4, text and end-to-end test** (outline): rewrite the two `run-issue` Scope entries (`--type
   project` end to end; ADR-0012 package worktrees) and the paragraph near line 68; design sections
   (Worktrees, Review loop, Merge gate, script table rows) and change-log row; the end-to-end synthetic
   sandbox test (hosting directory, two package repositories, bare remotes, stubbed `gh`) that drives a
   package issue to the merge checkpoint. The real-project run is the owner's acceptance run after part 4.

### Part 1 in detail

Combinations. Honoured in part 1: `(location=project, tracking=project)`, the default and what every
reader does for workspace and project issues today, now also for a package issue. For a package issue
"in the project repository" means the package repository that owns the issue (the manifest entry whose
origin remote slug equals `owner/repo`), at `<package worktree>/<rel>/.agent/work-plans/issue-N/`, on
the issue's feature branch. Still refused (unchanged messages, return 3 / the writer refusal), with the
reason: `(project, untracked)`, `(outside, untracked)`, `(outside, repo)`. They are not needed to run a
multi-repository project whose records are tracked; each needs decisions part 1 does not (excluding the
directory in a repository the session does not own, a directory outside the worktree surviving
`merge_pr.sh` cleanup, and for `repo` who commits and pushes, which 393 lists as unsettled). They follow
the same lookup: each is one more branch of one function, which is why the lookup is built so the
directory is the only thing callers learn. Issue 393 stays open for them.

Steps:

1. **Lookup function.** Extend `_resolve_work_plans_dir.sh` (the nearest lookup that exists, per the
   design) rather than adding a file: `resolve_work_plans_dir <issue-or-qualified-ref>`. Order:
   `WORK_PLANS_DIR_OVERRIDE` first (unchanged), then the project's records combination via
   `project_records_check` (non-default combination: refuse with the existing "not yet honoured (#393)"
   text, naming what part 1 honours), then for a qualified `owner/repo#N` read the package worktree's
   manifest (`wt_read_manifest`) and return `<container>/<rel>/.agent/work-plans/issue-<N>`; a plain
   number resolves as today. Failure modes are loud: no manifest entry for the slug, ambiguous entries,
   and the container being the cwd's main tree.
2. **Writers.** `progress_append.sh` keeps `-C <dir>` and `issue-<N>` (the directory name stays the
   number: it is unambiguous because it lives inside the owning repository, so two package
   repositories' issue 7 cannot collide); `review_progress.sh persist` (strict and compatibility paths,
   the `expected=` shape check at ~283) takes the repository from the lookup instead of
   `git rev-parse --show-toplevel`, so a session in the container writes and commits in the package
   repository.
3. **Readers.** `review_progress.sh` (112-117, 268-290, the path regex at ~392), `dispatch_phase.sh`
   (the progress path at lines 365, 396-398, 456, 548 and the implement task line 271) all call the
   lookup; the exit contract text prints the looked-up path.
4. **Merge gate (mechanism 2, package case).** `merge_pr.sh` `_gate_wt`/`_gate_progress` for a package
   pull request point at the package repository worktree and its `progress.md`; the "package worktree
   carries no issue timeline" gate reason (line 716) and the pull-request-comment fallback at 852 become
   the "no timeline found" path only; `_bookkeeping.sh`'s same-reviewed-state check runs in the package
   repository. The gate stays report-only for package pull requests, as for project ones.
5. **Messages and refusals.** `_project_registry.sh` (`PROJECT_RECORDS_LOOKUP_ISSUE` texts at 1449, 1700),
   `register_project.sh:798`, `registration_verify.sh:131`, `dashboard.sh:199` say what is now honoured
   and what is not; the combination check helper has one place that says "honoured" so those do not
   disagree.
6. **Tests** (synthetic, project- and machine-agnostic). New `test_records_lookup.sh`: a hosting
   directory with two package repositories, each with a bare remote and a github-shaped slug, a package
   worktree for issue 7 in each; stubbed `gh`. Cases: lookup returns each repository's own directory and
   the two issue 7s do not collide; plain-number lookups unchanged (existing `test_resolve_work_plans_dir.sh`
   cases still pass); the override wins; a non-default combination is refused with the honoured/refused
   text; `persist` from the container writes and commits in the package repository, never in the
   container or a main tree; `dispatch_phase.sh` exit contract names the package path; the merge gate
   finds the package timeline and reports (does not block) on a missing one; no manifest entry and
   ambiguous entries fail loudly. Any parallel run names its job count (`-j 4`), never bare.
7. **Design and consequences.** Worktrees Records bullet (replace the "has no timeline" sentence; refresh
   every `merge_pr.sh`/`progress_append.sh` line number cited), Worktrees Target (mechanism 1 built;
   mechanism 2 built for the package case; which combinations are honoured), Review loop `_gate_record`
   and Merge gate bullets as they touch the package record, `.agent/knowledge/script_reference.md` rows,
   the seven skills that cite the path (verify each against the lookup), ADR-0013 note that the
   directory key is the number, per repository; change-log row. The PR body states the reversal of 393's
   "stay so" line. Final step: a repo-wide search for stale references (`has no timeline`, `carries no
   issue timeline`, `stay so`, `not yet honoured`, `PROJECT_RECORDS_LOOKUP_ISSUE`, hard-coded
   `.agent/work-plans/issue-` constructions) across the whole repository, not only the files above.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_resolve_work_plans_dir.sh` | The lookup: settings check, qualified ref via manifest |
| `.agent/scripts/progress_append.sh`, `review_progress.sh` | Root from the lookup; persist/readers use it |
| `.agent/scripts/dispatch_phase.sh` | Progress path and exit contract from the lookup |
| `.agent/scripts/merge_pr.sh`, `_bookkeeping.sh` | Package gate reads the package record |
| `.agent/scripts/_project_registry.sh`, `register_project.sh`, `registration_verify.sh`, `dashboard.sh` | Honoured/refused wording |
| `.agent/scripts/tests/test_records_lookup.sh` (new), existing suites | Synthetic sandbox tests |
| `docs/design.md`, `.agent/knowledge/script_reference.md`, skills citing the path, ADR-0013 note | Same-change text |
| Parts 2 to 4 | See outlines; files named when their turn comes |

## Prior Art

Existing: `resolve_work_plans_dir` and its `--work-plans-dir` override (extended, not replaced);
`project_records_check` and `project_records_default` (the settings and defaults, used as they are);
`wt_read_manifest` and the sibling-PR check in `merge_pr.sh` (the package-repository enumeration is
reused); the package-worktree test in `test_merge_pr_gate.sh` (~483) is the nearest fixture for the
synthetic sandbox. Rejected: a package-qualified directory name (`issue-owner-repo-7`): the records live
inside the owning repository, so the number is already unambiguous, and ADR-0013's correlation key stays
the number. Rejected: keeping gate records on the pull request only: loop state needs a timeline.

## Serves

Workspace goal "A project can be worked from its own root" (README Workspace goals; the project-rooted
`/run-issue` path of the Direction), `docs/design.md#worktrees` (Records, Target) and
`docs/design.md#review-loop-and-timeline`.

## Design Picture

Changes the picture: Worktrees (Records bullet and Target), Review loop and timeline (`_gate_record`),
Merge gate, the script table rows, and the change log, in the part that builds each. Sessions and roots
needs no change (a package worktree already lives under the root).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Put each thing at the level it applies to | Lookup is generic over manifest and settings; no project or machine named in scripts or tests |
| Leave in a project only what it chose to carry | Honours the project's `location`/`tracking`; default unchanged; non-default stay refused until built |
| Enforcement over documentation | Refusals stay enforced; gate stays report-only, stated |
| A change includes its consequences | Step 7 and the repo-wide stale search; line numbers refreshed |
| Test what breaks | Synthetic sandbox with two package repositories covers collision, refusal, persist, gate |
| Only what's needed / small steps | Part 1 honours one combination; the others are one function branch each later |
| Ask about what matters | No mechanism question reaches the owner; decisions listed for veto |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 | Yes | Tests and text name no project |
| 0011 | Yes | Package awareness via `.worktree-repos`, not branching on type |
| 0012 | Yes | Manifest reused as is |
| 0013 | Yes | Key stays the number; per-repository directory; note added |
| 0014 | Yes (part 2) | Dispatch passes the looked-up path |
| 0016/0018 | Yes | Session root unchanged; records location counts as the root's own (the named bend in 393) |
| 0017 | Yes | Design edited in the same change |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Records path construction | the five scripts and seven skills that build or cite it | Yes, steps 2 to 4, 7 |
| "has no timeline" for packages | Worktrees, Merge gate, 393's "stay so" (in PR text) | Yes, step 7 |
| Honoured combinations | `register_project.sh`, `project_setting.sh`, verify, dashboard wording | Yes, step 5 |
| `run-issue` Scope text | Part 4 | Yes, part 4 |
| Zero-footprint onboarding roadmap rows (393 "Rules carried") | Waits for the other combinations | No, stays with 393 |

## Decisions for the owner's veto (mechanism, decided from principles and design)

1. **Honour only (project, project) in part 1, for package issues too.** Others stay refused. Undo cost:
   low, each is one more branch of the one lookup function; 393 stays open for them.
2. **Directory stays `issue-N` inside the owning package repository**, no qualified name. Undo: moderate
   (a rename across writers, readers and existing timelines), but nothing collides today.
3. **`--work-plans-dir` stays the first rule of the lookup**: an explicit per-call override beats the
   settings (the settings name the source of truth when records exist in two places; an override is a
   caller saying where this call's records are). Undo: low.
4. **Package gate stays report-only** in part 1 (as project pull requests are, Merge gate); making it
   blocking, now that a timeline exists, is decided in part 3. Undo: low.
5. **Lookup extends `_resolve_work_plans_dir.sh`** instead of a new file, the design's own "nearest
   lookup that exists". Undo: low.
6. **Deferred, not decided:** `tracking=repo` committer, branch and push timing (393 Unsettled item 1);
   no code in part 1 reaches it, so nothing is lost by waiting.
7. **The outside-path layout and default combination stay provisional** in `project_records_default`;
   part 1 does not touch them.
8. **Records in a package repository are a footprint on a repository that may not use this workspace.**
   This is what (project, project) means by the owner's own design; a project that does not want it picks
   another combination, which part 1 refuses until built. Flagged so the owner sees the consequence for
   the project11 path.

## Open Questions

- For the owner, goal level: for the project11 path, does he accept records committed in the package
  repositories (the default, honoured in part 1), or does that project need the zero-footprint combination
  first (which moves `(outside, untracked)` into part 1)? Only this changes what part 1 builds.

## Estimated Scope

Four pull requests. Part 1 is the largest (about eight scripts, one new test suite, design text).
