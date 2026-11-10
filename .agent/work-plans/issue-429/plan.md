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

1. **Part 1, records for a package issue** (detailed below): the records lookup of 393 over the issue's
   full identity (mechanism 1 everywhere, mechanism 2 for the package case), honouring only the default
   combination of the records settings, with a return shape the other combinations can land in; includes
   `dispatch_phase.sh` accepting `owner/repo#N` and its test.
2. **Part 2, worktree creation and phase dispatch from a project-rooted session** (outline): a run
   started with only `owner/repo#N` creates the package worktree (`worktree_create.sh --type project
   --issue owner/repo#N --layer … --package-repos …`) and enters it with `cd`; the layer and
   `--package-repos` rule: infer the layer from the project's adapter (`worktree_repos`/manifest) and use
   the issue's repository alone, with the issue or a flag able to name more; `run-issue` passes the qualified
   ref where it passes `--issue` today (`dispatch_phase.sh` already accepts it and takes the records
   path from the lookup, part 1). Detail when its turn comes.
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

**The mechanism.** A bare issue number is not an issue's identity: number 7 means one thing in the
workspace, another in each package repository. Everything that went wrong in the first draft (a bare
number from the package worktree's folder, from a sibling repository, a sibling's pull request at the
gate, an outside location shared by two repositories) is that one confusion. So part 1 builds one
lookup over the issue's full identity, the owning repository and the number, resolved once, and every
reader, writer and the merge gate consume what it returns.

**Combinations.** Part 1 honours only the default, `(location=project, tracking=project)`: what every
reader does for workspace and project issues today, now also for a package issue. For a package issue
"in the project repository" means the package repository that owns the issue, at
`<package worktree>/<rel>/.agent/work-plans/issue-N/`, on the issue's feature branch. Still refused
(unchanged messages, return 3 / the writer refusal): `(project, untracked)`, `(outside, untracked)`,
`(outside, repo)`. The owner, 2026-11-10: "It's configurable so that projects that want to keep it in
the repo can and projects where we don't want to leave a footprint, we can pick a different location."
Part 1 does not build that configurability; it builds the return shape that lets it land (below) and
issue 393 stays open for it. Decision 2 and the ADR-0013 note are limited to the default combination.

**The lookup.** `resolve_issue_records <ref> [<from-dir>]` in `_resolve_work_plans_dir.sh` (the nearest
lookup that exists, per the design). `<ref>` is a bare number or `owner/repo#N`; `<from-dir>` defaults
to the cwd (the dispatcher passes the worktree path it already found). One output line of four
tab-separated fields, read with `cut` (an empty field would collapse under `read`, so "none" is the
literal word, as in `_project_records_check_entries`):

| Field | Meaning |
|---|---|
| `dir` | the records directory |
| `commit_repo` | absolute path of the repository that commits `dir`, or `none` |
| `key` | the directory name under the records location: `issue-N` in the default combination |
| `identity` | `owner/repo#N` (owner/repo empty when the origin has no github slug, as in sandboxes) |

Resolution order:

1. `WORK_PLANS_DIR_OVERRIDE` first (unchanged): `dir` as given; `commit_repo` is the toplevel of the
   nearest existing ancestor of `dir` that is inside a repository, else `none`; `key` is `issue-N`.
2. Find the enclosing package worktree: walk up from `<from-dir>` to a directory holding
   `.worktree-repos` with `wt_is_package_worktree` true. Read its header with `head -n1` (as
   `merge_pr.sh:497` does; `wt_read_manifest`'s header globals are lost in `$(...)`). The header's
   `issue=` is the identity. A bare `<ref>` number that differs from the header's number, or a
   qualified one that differs from the header, is refused loudly ("this worktree is for X, asked for
   Y"); a matching or bare-equal ref resolves through the header. So `WORKTREE_ISSUE=<N>`, which
   `worktree_enter.sh` exports as the number only (`ISSUE_NUM` is stripped of the owner/repo at 129),
   resolves to the right repository from the container and from inside any package repository of it.
3. Pick the owning repository: the manifest entry whose origin remote's `extract_gh_slug`
   (`_issue_helpers.sh:22`, the rule `merge_pr.sh:486-488` uses) equals the header's `owner/repo`, and
   whose recorded branch is `feature/issue-N` (siblings carry `feature/<repo>-issue-N`). Exactly one
   entry, else a loud failure (none, several). `commit_repo` = `<container>/<rel>`.
4. Not in a package worktree: a qualified `<ref>` is refused with the remediation ("enter the package
   worktree, or pass `<from-dir>`"); creating or finding it is part 2. A bare number resolves as today
   (rules 2 and 2b of the existing function, anchored on the toplevel of `<from-dir>`), `commit_repo` =
   that toplevel, identity from its origin slug.
5. The project's records settings, checked once, before returning anything but the override. Project
   name by kind of worktree: package, the header's `project=`; a project worktree of one repository
   and a project session, `registry_resolve_session_dir "$ROOT" <from-dir>` (the entry whose
   `worktrees=` or hosting directory contains it, ADR-0018); a workspace issue, no project and no
   check. `project_records_check` returns 0 (default: go on), 3 (valid but not the default: refuse with
   the existing text, naming what part 1 honours) or 2. Return 2 covers any malformed key in the
   project's settings file, not only a records key; the lookup refuses on 2 too, printing the check's
   own error, because without a parseable file it cannot know which combination applies and a silent
   fall back to the default could write a footprint the project did not choose. The cost: a malformed
   settings file stops that project's loop until repaired with `project_setting.sh`; the error says so.
6. `dir`, `commit_repo`, `key` come from one pure helper, `records_layout <location> <tracking>
   <identity> <repo-root> <location-path>`, whose default branch builds `<repo-root>/.agent/work-plans/issue-N`.
   Its `outside` branch builds a directory under `location_path` keyed by the identity (`owner--repo--N`
   style, path-safe) with `commit_repo` `none`, so two repositories' issue 7 cannot collide. Step 5
   stops anything but the default before the helper is reached, so that branch is unreachable from the
   lookup in part 1 and only the test calls it; it is the clean place the other combinations land,
   one more branch, not new return fields.

**Consumers** (each takes the four fields, none re-derives the repository or the number from a path):

- `progress_append.sh`: today `ROOT=git -C "$DIR" rev-parse --show-toplevel` and `FILE_REL` fixed at
  line 87. New `--records-dir <dir> --commit-repo <repo>` pair (the existing `-C <dir>` form stays and
  resolves through the lookup); it writes `<dir>/progress.md` and commits in `commit_repo` (`none`:
  write, do not commit; unreachable in part 1). The `^[0-9]+$` check at line 65 stays on the number.
- `review_progress.sh`: `round` (112-117) and `persist` (strict `expected=` shape check at 283, the
  compatibility path at 299-305) take `dir` and `commit_repo` from the lookup instead of
  `git rev-parse --show-toplevel`; in compatibility mode a package worktree no longer falls back to the
  container (the lookup does not abort for a package worktree, and a refusal there is a refusal in
  both modes). The path regex at 392, which recovers the issue number by parsing the path, takes the
  number from `--issue`/the lookup's `key` first and parses the path only as a last resort.
- `dispatch_phase.sh`: `--issue` accepts `owner/repo#N` in `dispatch`, `check-exit` and `next` (the
  `^[0-9]+$` gates at 325, 435, 542; `resolve_worktree` already reaches `find_worktree_by_issue`, which
  takes a qualified ref, 232-238); the progress path (365, 456, 548), the exit contract text (396,
  398), the implement task line (271) and `wt=` come from the lookup called with the worktree it found.
  The package-path work and its test are therefore both in part 1; part 2 keeps creation, the layer
  rule and `run-issue` passing the qualified ref.
- `cross_model_review.sh:751` and the `plan-task`/`review-plan`/`review-code` skill steps that call
  `resolve_work_plans_dir`: through the lookup (`resolve_work_plans_dir <N>` stays as a wrapper
  printing field one, so callers that only need the directory are unchanged).
- `worktree_create.sh:880` (`--workflow`): writes `progress.md` under `$WORKTREE_DIR/.agent/work-plans/`;
  for a package worktree that is the container, where nothing commits it and readers no longer look.
  The manifest is written first (756), so it calls the lookup with `<from-dir>` the new worktree and
  writes into `dir`.
- **Merge gate** (`merge_pr.sh`): for a package pull request the identity is `PKG_WT_ISSUE` (the header
  `issue=`, read at 497-499), never the number parsed from the pull request's branch (443). The gate
  calls the lookup with `PKG_WT_ISSUE` and `PKG_WT_DIR`, and takes `_gate_progress`, `_gate_wt` (for
  `_gate_record`: `commit_repo`, and the owning repository's `feature/issue-N` as the branch to push,
  not `PR_BRANCH`) and `_bookkeeping.sh`'s same-reviewed-state check repository from it. So a pull
  request from a sibling repository's `feature/<repo>-issue-N` reads and writes the owning repository's
  timeline. The "carries no issue timeline" gate reason (716) and the pull-request-comment fallback
  (853) remain only for the case where the lookup finds no timeline file. The gate stays report-only.

**Messages.** `_project_registry.sh` is the one place that prints "until the records lookup lands"
(1449, and the writer refusal at 1700): only that clause goes stale, and part 1 edits it there alone.
`register_project.sh:798`, `registration_verify.sh:131` and `dashboard.sh:199` are changed only if each
prints that clause independently (checked when implementing; the plan does not edit them otherwise).

**Tests** (synthetic, project- and machine-agnostic; the new suite names no project, so its manifest
header uses a made-up name, not `p11` as `test_merge_pr_gate.sh:483` does). New
`test_records_lookup.sh` (chmod +x): a hosting directory with two package repositories, each with a
bare remote and a github-shaped slug, and one package worktree whose issue is in the first and whose
second repository carries a sibling branch; stubbed `gh`. Cases:

1. a bare number from the package worktree's top folder returns the owning repository's directory and
   that repository as `commit_repo`, never the hosting repository's main tree;
2. a bare number from inside the second (sibling) package repository returns the owning repository's
   directory, not the sibling's own `issue-N` (the sibling is given a pre-existing `issue-N` records
   directory to prove it is not read);
3. a number or qualified ref that disagrees with the header is refused;
4. merge gate (`test_merge_pr_gate.sh` fixture shape, new case): a pull request from the sibling's
   `feature/<repo>-issue-N` branch reads the owning repository's timeline, and `_gate_record` appends,
   commits and pushes there (owning repository's `feature/issue-N`), leaving the sibling's records
   directory untouched; and a missing timeline stays report-only;
5. `records_layout` called directly with the `outside` combination and two identities sharing a number
   returns two different `dir` and `key` values (the return shape does not collide), while the lookup
   itself still refuses an outside combination with the honoured/refused text;
6. the override wins; non-default combination refused (3); malformed settings file refused (2) with the
   check's own error; no manifest entry and ambiguous entries fail loudly;
7. `persist` from the container and from the sibling writes and commits in the owning repository,
   never in the container, the hosting repository or the sibling (strict and compatibility modes);
8. `dispatch_phase.sh dispatch|check-exit|next --issue owner/repo#N` finds the package worktree, and the
   exit contract and progress path name the owning repository's directory;
9. `worktree_create.sh --workflow` for a package worktree puts `progress.md` in the owning repository.

Existing suites: `test_resolve_work_plans_dir.sh` cases still pass (plain-number behaviour); the
expectation at `test_merge_pr_gate.sh:483-509` ("package worktrees carry no issue timeline ... posted as
a comment") flips: the record is now committed in the owning package repository, and the case is
rewritten to say so. Any parallel run names its job count (`-j 4`), never bare.

**Design and consequences.** Worktrees Records bullet (replace the "has no timeline" sentence; refresh
every `merge_pr.sh`/`progress_append.sh` line number cited), Worktrees Target (mechanism 1 built;
mechanism 2 built for the package case; part 1 honours the default combination only; the return shape),
Review loop `_gate_record` and Merge gate bullets as they touch the package record,
`.agent/knowledge/script_reference.md` rows, the nine skills that cite `work-plans/issue-`
(`address-findings`, `review-code`, `sitrep`, `start-task`, `run-issue`, `triage-reviews`, `plan-task`,
`onboard-project`, `review-plan`; each verified against the lookup), an ADR-0013 note that for the
default combination the key is the number per owning repository and that other combinations key by the
identity, change-log row. The PR body states the reversal of 393's "stay so" line. Final step: a
repo-wide search for stale references (`has no timeline`, `carries no issue timeline`, `stay so`,
`not yet honoured`, `PROJECT_RECORDS_LOOKUP_ISSUE`, hard-coded `.agent/work-plans/issue-`
constructions) across the whole repository, not only the files above.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_resolve_work_plans_dir.sh` | `resolve_issue_records`, `records_layout`; `resolve_work_plans_dir` becomes a wrapper |
| `.agent/scripts/progress_append.sh`, `review_progress.sh` | Directory and committing repository from the lookup; persist, round, path regex |
| `.agent/scripts/dispatch_phase.sh` | Accept `owner/repo#N`; progress path, exit contract, task line from the lookup |
| `.agent/scripts/cross_model_review.sh` (751) | Through the lookup |
| `.agent/scripts/worktree_create.sh` (880) | `--workflow` progress.md into the owning repository |
| `.agent/scripts/merge_pr.sh`, `_bookkeeping.sh` | Gate and `_gate_record` use the lookup with the manifest header identity |
| `.agent/scripts/_project_registry.sh` (1449, 1700) | The "until the records lookup lands" clause; the other three scripts only if they print it themselves |
| `.agent/scripts/tests/test_records_lookup.sh` (new, `chmod +x`), `test_merge_pr_gate.sh` (flipped expectation at 483-509), `test_resolve_work_plans_dir.sh` | Synthetic sandbox tests |
| `docs/design.md`, `.agent/knowledge/script_reference.md`, nine skills, ADR-0013 note | Same-change text |
| Parts 2 to 4 | See outlines; files named when their turn comes |

## Prior Art

Existing: `resolve_work_plans_dir` and its `--work-plans-dir` override (extended, not replaced);
`project_records_check` and `project_records_default` (the settings and defaults, used as they are);
`wt_read_manifest` and the sibling-PR check in `merge_pr.sh` (the package-repository enumeration is
reused); the package-worktree test in `test_merge_pr_gate.sh` (~483) is the nearest fixture for the
synthetic sandbox. Rejected: a bare number as the lookup's input and a directory as its only output (the first draft):
number and repository are re-derived by every caller from a path or the cwd, which is how two
repositories' issue 7 get confused. Rejected for the default combination: a package-qualified directory
name (`issue-owner-repo-7`): the records live inside the owning repository, so the number is
unambiguous there and ADR-0013's correlation key stays the number; the outside combination keys by the
identity (the `records_layout` helper), which is why the return carries `key`. Reused: `extract_gh_slug`
(`_issue_helpers.sh:22`) for the owning repository, `wt_is_package_worktree`, the `head -n1` header read
of `merge_pr.sh:497`, `find_worktree_by_issue`'s qualified-ref support, `registry_resolve_session_dir`. Rejected: keeping gate records on the pull request only: loop state needs a timeline.

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
| Put each thing at the level it applies to | Lookup is generic over manifest and settings; no project or machine named in scripts or tests, including the new fixture's manifest header |
| Leave in a project only what it chose to carry | Honours the project's `location`/`tracking`; default unchanged; non-default stay refused until built |
| Enforcement over documentation | Refusals stay enforced; gate stays report-only, stated |
| A change includes its consequences | Step 7 and the repo-wide stale search; line numbers refreshed |
| Test what breaks | Synthetic sandbox with two package repositories covers collision, refusal, persist, gate |
| Only what's needed / small steps | Part 1 honours one combination; the return shape (dir, committing repository, key, identity) and the `records_layout` helper are the only provision for the others |
| Test what breaks (identity) | One test per way the bare number fails: container folder, sibling repository, sibling pull request at the gate, shared outside location |
| Ask about what matters | No mechanism question reaches the owner; decisions listed for veto |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0003 | Yes | Tests and text name no project |
| 0011 | Yes | Package awareness via `.worktree-repos`, not branching on type |
| 0012 | Yes | Manifest reused as is |
| 0013 | Yes | Default combination: key is the number, per owning repository; other combinations key by identity; note scoped to the default |
| 0014 | Yes (part 2) | Dispatch passes the looked-up path |
| 0016/0018 | Yes | Session root unchanged; records location counts as the root's own (the named bend in 393) |
| 0017 | Yes | Design edited in the same change |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Records path construction | the scripts that build it (progress_append, review_progress, dispatch_phase, cross_model_review, worktree_create, merge_pr) and nine skills that cite it | Yes, Consumers and Design and consequences |
| "has no timeline" for packages | Worktrees, Merge gate, 393's "stay so" (in PR text) | Yes, step 7 |
| Honoured combinations | only the "until the records lookup lands" clause in `_project_registry.sh`; the other three scripts if they print it themselves | Yes, Messages |
| `run-issue` Scope text | Part 4 | Yes, part 4 |
| Package-gate expectation in `test_merge_pr_gate.sh:483-509` | flips to the committed record | Yes, Tests |
| Zero-footprint onboarding roadmap rows (393 "Rules carried") | Waits for the other combinations | No, stays with 393 |

## Decisions for the owner's veto (mechanism, decided from principles and design)

1. **Records committed in the package repositories for his own project, the default.** A package issue's
   work plan and timeline live in the package repository that owns the issue, on its feature branch,
   because `(project, project)` is the default and no registered project sets another combination. For
   the project11 path that is a footprint in repositories that may not use this workspace. Undo cost:
   low before the first run (set the project's `location`/`tracking` and wait for 393's other
   combinations); after runs, each issue's `.agent/work-plans/issue-N/` must be moved out of the package
   repositories' history by hand.
2. **Honour only (project, project) in part 1, for package issues too.** Others stay refused. Undo cost:
   low; each is one more branch of `records_layout` and the settings check; 393 stays open for them.
3. **Directory stays `issue-N` inside the owning package repository for the default combination**, no
   qualified name there; other combinations key by identity. Undo: moderate (a rename across writers,
   readers and existing timelines), but nothing collides in the default combination.
4. **The lookup returns four fields (directory, committing repository, key, identity)** and every caller
   goes through it; `resolve_work_plans_dir <N>` stays as a wrapper. Undo: moderate (callers change
   once more), the reason it is decided now.
5. **A malformed project settings file refuses the lookup** (rc 2 of `project_records_check`) rather than
   falling back to the default. Undo: low.
6. **`--work-plans-dir` stays the first rule of the lookup**: an explicit per-call override beats the
   settings. Undo: low.
7. **Package gate stays report-only** in part 1 (as project pull requests are, Merge gate); making it
   blocking, now that a timeline exists, is decided in part 3. Undo: low.
8. **Lookup extends `_resolve_work_plans_dir.sh`** instead of a new file, the design's own "nearest
   lookup that exists". Undo: low.
9. **Deferred, not decided:** `tracking=repo` committer, branch and push timing (393 Unsettled item 1);
   the outside-path layout and default combination stay provisional in `project_records_default`; no code
   in part 1 reaches them beyond the unreachable `records_layout` branch.

## Open Questions

None for the owner. His 2026-11-10 answer settles where records live; the default for his own project is listed for his veto (decision 1).

## Estimated Scope

Four pull requests. Part 1 is the largest (about eight scripts, one new test suite, design text).
