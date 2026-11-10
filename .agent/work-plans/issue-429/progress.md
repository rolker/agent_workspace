---
issue: 429
---

# Issue #429 — run-issue: drive an issue in a package repository of a multi-repository project

## Issue Review
**Status**: complete
**When**: 2026-11-10 09:49 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #429

### Scope Assessment

**Well-scoped?** No, as one change. The acceptance ("reaches the merge checkpoint without hand steps") crosses at least four independent mechanisms: where a package issue's records live, worktree creation and phase dispatch inside a package worktree, the merge gate for a package pull request, and the skill/design text. Split proposed below.
**Right repo?** Yes. The work is in `run-issue`, `dispatch_phase.sh`, `merge_pr.sh`, the records lookup and the design text, all workspace. A session at the project root does it (ADR-0016/0018 session-root rule), so no cross-root work is needed.
**Serves**: the project-rooted `/run-issue` path of the Direction (acceptance sequence step "project11 after 10-24"), `docs/design.md#sessions-and-roots` and `#worktrees`.
**Design picture?** Changes [Worktrees] (the Records bullet and Target) and [Review loop and timeline] (package pull requests in the merge gate and `_gate_record`). The change log row is part of each part.
**Dependencies**: #393 (records lookup, open, Part of #332, already lists "Package-repository issues have no timeline today and stay so" under Unsettled; this issue reverses that, so #393 must be amended or this issue becomes its first consumer). #265 (open, "Step 5: hosted projects" roadmap entry) overlaps on `--type project` end to end.

What the design already records (quoted, so the plan asks only what is open):

- Package worktrees: ADR-0012 (`worktree_repos`, `worktree_env`; the `.worktree-repos` manifest per worktree; `ros2_colcon` requires `--issue owner/repo#N` plus `--layer` and `--package-repos`; the issue's own repo gets `feature/issue-<N>`). Design, Sessions and roots: "A multi-repo project's root is its registered hosting directory, never a package repository nested in it", and worktrees "live under their root". So the session-root rule already allows a package worktree from a project-rooted session; only `run-issue`'s Scope text says it does not.
- Where the timeline lives: Worktrees, Records: "An issue in a package repository (`--issue owner/repo#N`, worked in a package worktree) has no timeline: a package worktree is a folder of several repositories, not one repository, so `merge_pr.sh` posts its gate record on the pull request". Same section, general rule: records are "committed in the repository that owns the issue ... on the issue's feature branch, under `.agent/work-plans/issue-N/` (owner decision 2026-10-09, C3)". These two sentences conflict for a package issue: the owning repository is the package repository, which is a real git worktree inside the package worktree, yet the design says no timeline. The loop cannot run without one: Review loop, "`.agent/work-plans/issue-<N>/progress.md` is the only place loop state lives".
- Which repository the pull request targets: not written for packages. The general rule, "Issues and PRs live in whichever repo owns the code being changed" (AGENTS.md), gives the package repository. The Merge gate text already says "Project and package pull requests are report-only", and `_gate_record` already posts on the pull request when no worktree can commit the entry.
- Records settings (Worktrees Target, #393): `location` project|outside, `tracking` untracked|project|repo, only (project, project) honoured today. The records location "counts as the root's own", so a session writing records there keeps the session-root rule.

**Real gap found**: for a package issue (project, project) means the project's own repository, but a multi-repository project's hosting directory is usually not a git repository carrying the issue's code, and the package repository is the owner. Writing `.agent/work-plans/` into a third-party package repository is a footprint on a repository that did not opt in (owner goal 2026-09-23: "don't force conventions on projects"). That choice is the one thing the design leaves open.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Put each thing at the level it applies to | Action needed | Mechanism text and the synthetic sandbox must name no project; the acceptance run against a real project is a separate, owner-run step, not a test (design Rules row). |
| Enforcement over documentation | Watch | The gate is report-only for package pull requests. Decide in the split whether this stays so; do not leave it unstated. |
| A change includes its consequences | Action needed | `run-issue/SKILL.md` Scope, the Worktrees Records bullet and Target, the Merge gate bullet, `merge_pr.sh` line references and the design change log all change. |
| Capture decisions / Verify before claiming | Watch | Script line numbers cited in the design (merge_pr.sh 810, 853, 926, 939) drift; refresh them. |
| Improve the system, not only the output | OK | Matches the owner's path: project11 development from a project-rooted session. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0003 project-agnostic workspace | Yes | Tests use a synthetic multi-repository sandbox; skills and scripts name no project. |
| 0011 adapter contract | Yes | Generic scripts must not branch on project type; package awareness goes through the `.worktree-repos` manifest and the adapter verbs. |
| 0012 worktree composition | Yes | Package worktree creation is done; the issue builds on it. `run-issue` stays type-agnostic and reads the manifest, not the type. |
| 0013 progress.md vocabulary | Yes | Correlation key is the issue number only; `owner/repo#N` needs a rule for the directory name `issue-N` so two package repositories' issue 7 do not collide. |
| 0014 in-process handoff | Yes | `dispatch_phase.sh` must start the sub-agent in the package worktree and pass the records path. |
| 0016 / 0018 session roots, plugin delivery | Yes | Session works only under its root; `session_root.sh` refuses a package repository as a root, so the run starts at the hosting directory and the worktree is entered with `cd`. |
| 0017 design is the current picture | Yes | Update Worktrees, Review loop, Merge gate and the change log in the same changes. |

### Consequences

- `run-issue/SKILL.md` Scope: the two out-of-scope entries are rewritten (acceptance asks for it); also the paragraph near line 68 about a package worktree giving a different skill-prefix answer.
- Worktrees Records bullet and Target (design.md ~440-450 and the Target list), Review loop bullet on `_gate_record`, Merge gate bullet "Project and package pull requests are report-only", the `merge_pr.sh` and `worktree_create.sh` rows of the script table.
- #393 text: "Package-repository issues ... stay so" is reversed; its mechanism 1 call sites (`progress_append.sh:87`, `review_progress.sh`, `dispatch_phase.sh`, `merge_pr.sh`, `_resolve_work_plans_dir.sh`) are the same sites this issue needs.
- Tests: a synthetic sandbox of a hosting directory plus two package repositories with bare remotes; none exists for `merge_pr.sh` against a package pull request today, check `.agent/scripts/tests/` for the nearest.
- The issue number key: the directory `issue-N` and `progress_append.sh --issue` need a package-qualified form, or the records live per repository so the number is unambiguous.

### Recommendations

- Split into parts, in this order: (1) records for a package issue: settle where they live and add the lookup, as the first consumer of #393 (or fold into #393 PR 2); (2) worktree creation and phase dispatch from a project-rooted session on a package issue, using the `.worktree-repos` manifest, including how `--layer` and `--package-repos` are chosen; (3) the package pull request path: publish target, review reading the package diff, `merge_pr.sh` gate and cleanup across the manifest repositories; (4) rewrite the `run-issue` Scope entries, the design sections and add the end-to-end synthetic sandbox test. Parts 2 and 3 can run in parallel after part 1; part 4 closes.
- Add to the issue body (or the part 1 plan) the owner decision on records location for a package issue, as an owner question stated at goal level: should the work plan and timeline of a package issue be committed in the package repository (the owner of the code, visible to its other contributors) or kept at the project root outside it, since the package repository may not use this workspace? Everything else (qualified directory name, manifest handling, gate behaviour) is mechanism and is decided from the existing design.
- Decide in the plan, from existing design and not by asking: the pull request targets the package repository named in `owner/repo#N`; the review reads that repository's diff against its base; the gate stays report-only for package pull requests as the Merge gate section already says, unless the records move makes it enforceable.
- State `--layer` and `--package-repos` selection for a run started with only an issue reference: the adapter requires both, so `run-issue` needs a rule (infer the layer from the manifest and use the issue's repository alone) or the issue must carry them; the issue's text does not say.
- Amend #393's "Unsettled" line on package issues so the two issues do not contradict.
- Keep tests on the synthetic sandbox (hosting directory, two package repositories, bare remotes, a stubbed `gh`); the real-project run is the owner's acceptance run after part 4, as for #423.

### Actions
- [ ] Mechanism text and the synthetic sandbox must name no project; the acceptance run against a real project is a separate, owner-run step, not a test (design Rules row).
- [ ] `run-issue/SKILL.md` Scope, the Worktrees Records bullet and Target, the Merge gate bullet, `merge_pr.sh` line references and the design change log all change.
- [ ] Split into parts, in this order: (1) records for a package issue: settle where they live and add the lookup, as the first consumer of #393 (or fold into #393 PR 2); (2) worktree creation and phase dispatch from a project-rooted session on a package issue, using the `.worktree-repos` manifest, including how `--layer` and `--package-repos` are chosen; (3) the package pull request path: publish target, review reading the package diff, `merge_pr.sh` gate and cleanup across the manifest repositories; (4) rewrite the `run-issue` Scope entries, the design sections and add the end-to-end synthetic sandbox test. Parts 2 and 3 can run in parallel after part 1; part 4 closes.
- [ ] Add to the issue body (or the part 1 plan) the owner decision on records location for a package issue, as an owner question stated at goal level: should the work plan and timeline of a package issue be committed in the package repository (the owner of the code, visible to its other contributors) or kept at the project root outside it, since the package repository may not use this workspace? Everything else (qualified directory name, manifest handling, gate behaviour) is mechanism and is decided from the existing design.
- [ ] Decide in the plan, from existing design and not by asking: the pull request targets the package repository named in `owner/repo#N`; the review reads that repository's diff against its base; the gate stays report-only for package pull requests as the Merge gate section already says, unless the records move makes it enforceable.
- [ ] State `--layer` and `--package-repos` selection for a run started with only an issue reference: the adapter requires both, so `run-issue` needs a rule (infer the layer from the manifest and use the issue's repository alone) or the issue must carry them; the issue's text does not say.
- [ ] Amend #393's "Unsettled" line on package issues so the two issues do not contradict.
- [ ] Keep tests on the synthetic sandbox (hosting directory, two package repositories, bare remotes, a stubbed `gh`); the real-project run is the owner's acceptance run after part 4, as for #423.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 10:20 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

The host asked where a package issue's work plan and timeline are kept. The owner's answer, verbatim: "Did we not already settle on 3 for this? It's configurable so that projects that want to keep it in the repo can and projects where we don't want to leave a footprint, we can pick a different location. I think we might also have settled defaults that can get overridden for both cases right?"

He is right: `docs/design.md`, Worktrees, Target records the per-project records settings (`location`, `location_path`, `tracking`) with defaults in one function (`project_records_default`), and issue 393 (records lookup) is the work that makes the other combinations honoured. The question should not have reached him (host defect: the review quoted these settings and the host asked anyway). A package issue's records follow the project's records settings. Host decisions for the plan, listed for his veto: the split into parts stays on this issue as separate pull requests, no new issues; part 1 builds the records lookup of issue 393 with a package issue as a consumer, and amends issue 393's "package issues stay without a timeline" line through the pull request text rather than by editing that issue.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 09:58 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-429/plan.md` at `69995a5b`

Four parts on this issue, each its own pull request. Part 1 builds the records lookup of 393 with a package issue as consumer, honouring only (project, project) and keeping the other combinations refused; parts 2 to 4 are outlined.

## Plan Review
**Status**: complete
**When**: 2026-11-10 10:01 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #429 — run-issue: drive an issue in a package repository of a multi-repository project
**Plan**: `.agent/work-plans/issue-429/plan.md` at `69995a5b`
**Branch**: `feature/issue-429`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | Four-part split is right. Part 1 is broader than the smallest unblocker (merge gate overlaps part 3; wording in four scripts while the honoured set does not change), and its dispatch test needs qualified-ref plumbing the plan puts in part 2 (findings 4, 7). |
| Issue alignment | Good | Serves, as checked: workspace goal "A project can be worked from its own root", `docs/design.md#worktrees` (Records, Target), `docs/design.md#review-loop-and-timeline`. Covers the Issue Review's split, the layer/package-repos rule (part 2), the gate decision, the reversal of 393's "stay so" line. Open Questions re-asks the owner what the Checkpoint says must not reach him (finding 8). |
| File targeting | Needs work | Missing: `worktree_create.sh:880` (`--workflow` scaffolds `progress.md` in the package container) and `cross_model_review.sh:751` (lookup caller with a bare number). Nine skills cite the path, not seven. |
| Consequences | Needs work | Existing `test_merge_pr_gate.sh:483-509` expects "package worktrees carry no issue timeline ... posted as a comment" and flips; its fixture names a project in the header (`project=p11`), which must not be copied into the new suite. |
| Principle alignment | Concern | "Only what's needed" vs the owner's "configurable": the lookup returns a directory only, which does not leave the other combinations "one more branch" (finding 3). "Test what breaks": the bare-number and sibling-repository cases that actually confuse two repositories' issue N are not in the test list (findings 1, 2). |
| ADR compliance | Needs work | ADR-0013 note "key is the number, per repository" holds only for (project, project); an outside location for a multi-repository project needs the repository in the key. ADR-0003: tests synthetic, `-j 4` stated. ADR-0016/0018: part 1 writes only in `<container>/<rel>` under the root's `worktrees=` dir and reads `.agent/projects.d/<name>`; nothing outside the root, provided finding 1 closes the fallback to the enclosing hosting repository. |
| ROS conventions | N/A | Workspace plan. |

Script claims checked: `_resolve_work_plans_dir.sh` rules 1/2/2b/3 as stated; `project_records_check` returns 3 for valid-but-not-honoured with the 1449 text, writer refusal at 1700; `progress_append.sh` numeric-only, `-C`; `review_progress.sh` 112-117, 268-290 (`expected=` at 283), path regex at 392; `dispatch_phase.sh` 271, 365, 396-398, 456, 548 (the design's 368/370/428/520 are the stale ones); `merge_pr.sh` 716 correct, PR-comment reason at 853 (plan says 852), sibling check 465-530; manifest lines `<origin>\t<rel>\t<branch>`, owning repo gets `feature/issue-N`, siblings `feature/<repo>-issue-N` (ros2_colcon adapter 768-774).

### Findings

1. **[Principle alignment / must-fix]** A bare issue number inside a package worktree still resolves to the wrong repository. `worktree_enter.sh:326` exports `WORKTREE_ISSUE=<number>` for a package worktree, and every entry point passes the number (`review_progress.sh persist --issue`, `round` gated `^[0-9]+$` at 113, `cross_model_review.sh:751`, `dispatch_phase.sh` 325/435/542). The plan keeps "a plain number resolves as today", so rule 2 returns `$(git rev-parse --show-toplevel)/.agent/work-plans/issue-N`: from the container that is the enclosing hosting repository's main tree (the container is a plain directory inside the project tree, `worktree_create.sh` hook-preflight comment), and from a sibling package repository's subdirectory it is that sibling's `issue-N`, which after any merged sibling issue N is the sibling's own timeline. Resolution: the lookup finds an enclosing `.worktree-repos` from the cwd and resolves a bare number through its header (refusing when the number differs), so the qualified path is taken whatever the caller passes; test both cwd cases.
2. **[Consequences / must-fix]** Merge gate: for a package pull request, select the timeline in the owning repository named by the manifest header (`PKG_WT_ISSUE`), not the pull request's repository. `merge_pr.sh:443` takes `ISSUE_NUM` from `feature/<repo>-issue-N` too, so a sibling repository's pull request reaches the gate with the same N; reading `<container>/<sibling>/.agent/work-plans/issue-N` would read the sibling's own issue N timeline. `_gate_record` pushes `PR_BRANCH` from `_gate_wt` (837-838); for a sibling pull request the record belongs on the owning repository's `feature/issue-N`. State the sibling case (or leave it explicitly to part 3) and test it.
3. **[Principle alignment / must-fix]** The lookup's interface: "the directory is the only thing callers learn" does not let the other combinations land as "one more branch of one function". Tracking decides whether and where a writer commits (`progress_append.sh` commits in `git -C <dir> rev-parse --show-toplevel`; `persist` strict mode refuses any dir not shaped `<repo-root>/.agent/work-plans/issue-N` at 283; `_gate_record` commits and pushes); `review_progress.sh:392` recovers the issue number by parsing the path; and an outside location shared by two package repositories collides on `issue-N`. Two findings in this mechanism point at one fix: have part 1's lookup return what callers need (directory, the repository that commits it or none, and the key), make writers and readers consume that instead of re-deriving the repository or number from the path, and scope decision 2 and the ADR-0013 note to (project, project). Then decision 1's low undo cost is true.
4. **[Scope]** Part 1/part 2 boundary: part 1's test "`dispatch_phase.sh` exit contract names the package path" needs `dispatch_phase.sh` to accept `owner/repo#N` and `resolve_worktree` to find a package worktree by qualified ref (today numeric only, and a bare number across several package worktrees is ambiguous in `find_worktree_by_issue`), which the plan assigns to part 2. Either move qualified-ref acceptance in `dispatch_phase.sh`'s three subcommands into part 1 or move the test to part 2.
5. **[File targeting]** `worktree_create.sh:880` writes `$WORKTREE_DIR/.agent/work-plans/issue-N/progress.md` under `--workflow`; for a package worktree that is the container, where nothing commits it and readers will no longer look. Route it through the lookup or refuse `--workflow` for a package worktree; add to Files.
6. **[File targeting]** Owning-repository selection: reuse the slug rule `merge_pr.sh` already uses (`extract_gh_slug` of the origin remote, 486-487) or the adapter's `adapter_scope_for_pr`, and cross-check with the `feature/issue-N` branch; read the header with `head -n1` as `merge_pr.sh:494` does, since `wt_read_manifest`'s header globals are lost in `$(...)`.
7. **[Scope]** Step 5 rewrites honoured/refused wording in four scripts while part 1 honours exactly what is honoured today; only the "until the records lookup lands" clause goes stale. Keep the edit to that clause in `_project_registry.sh` (one place) unless the other three print it independently.
8. **[Issue alignment]** Open Questions asks the owner whether records in package repositories are acceptable, while Context and the Checkpoint say the settings answer it and no question goes to him; no registered project sets a non-default combination today. Drop it or leave it as veto item 8.
9. **[Principle alignment]** Say what the lookup does when `project_records_check` returns 2 for a settings-file error unrelated to records (any malformed key fails the parse), and how it finds the project name for each worktree kind (manifest header `project=`, registry match from the cwd, none for a workspace issue).
10. **[Consequences]** Nine skills cite `work-plans/issue-` (review-code, plan-task, address-findings, review-plan, onboard-project, triage-reviews, sitrep, run-issue, start-task), not seven; verify each.

### Summary

The four-part split and the decision to honour the default combination are sound and the script line references are mostly accurate. Part 1 is not ready: a bare issue number inside a package worktree still resolves to the hosting or a sibling repository, the gate does not say which repository's `issue-N` it reads for a sibling pull request, and a directory-only lookup closes off the owner's "configurable" more than the plan claims.

### Recommended Actions

- [ ] Lookup resolves a bare number through an enclosing `.worktree-repos` header; tests from the container and from a sibling repository (finding 1)
- [ ] Merge gate takes the owning repository from the manifest header; sibling pull request case stated and tested (finding 2)
- [ ] Lookup returns directory plus committing repository (or none) and key; writers and readers consume it; decision 2 and the ADR-0013 note scoped to (project, project) (finding 3)
- [ ] Settle the dispatch qualified-ref boundary between parts 1 and 2 (finding 4)
- [ ] Add `worktree_create.sh --workflow` and `cross_model_review.sh` to Files; reuse the existing slug rule; trim step 5; drop the open question; settings rc 2 and project-name rule; nine skills; no project name in the new fixture (findings 5-10)

## Checkpoint
**Status**: complete
**When**: 2026-11-10 10:55 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review found three must-fixes, all mechanism and none a change of scope; first host revise on this plan)
**After**: plan
**Decision**: revise

Host read the Plan Review of 2026-11-10 (needs-work, 3 must-fix, 8 suggestions) and directs:
- The three must-fixes are one mechanism: a bare issue number standing for an issue's identity. Do not add three point fixes. The lookup takes and returns the issue's full identity: the owning repository and the number, resolved once (from the `.worktree-repos` header inside a package worktree, from the repository itself elsewhere), and returns the records directory, the repository that commits it (or none), and the key. Every reader, writer and the merge gate go through it, so a bare number inside a package worktree, a pull request from another repository's `feature/<repo>-issue-N` branch, and an outside location shared by two repositories all resolve by identity, each with a test.
- Part 1 still honours only the default combination, but the lookup's return shape is what the other combinations need, so the owner's "configurable" stays open. Decision 2 and the ADR-0013 note are limited to the default combination.
- Take all eight suggestions. The dispatcher's package-path work and its test sit in the same part (move one so they agree). Drop the Open Question to the owner: his answer of 2026-11-10 covers it, and the default for his own project is listed for his veto instead.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 10:05 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-429/plan.md` at `067cb744`

Revision after the plan review: part 1's lookup now takes and returns the issue's full identity (directory, committing repository, key, identity), resolved from the .worktree-repos header inside a package worktree and from the repository elsewhere; every reader, writer and the merge gate consume it, with a test for each way a bare number failed. Part 1 still honours only the default records combination; the eight suggestions are taken and the owner question is replaced by veto item 1.

## Plan Review
**Status**: complete
**When**: 2026-11-10 10:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #429 — run-issue: drive an issue in a package repository of a multi-repository project
**Plan**: `.agent/work-plans/issue-429/plan.md` at `067cb744`
**Branch**: `feature/issue-429`

Second review, after the host's revise of 10:55. Scope: the revise directions only; points the first review accepted are not reopened.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | About 25 files: 9 scripts, 3 to 5 test suites, design, script reference, ADR-0013, 9 skills. At the upper edge for one pull request; the clean cut is the merge gate (finding 2). |
| Issue alignment | Good | Serves, as checked: workspace goal "A project can be worked from its own root", `docs/design.md#worktrees` (Records, Target), `docs/design.md#review-loop-and-timeline`. Open Question to the owner dropped; decision 1 lists his project's default for veto. |
| File targeting | Needs work | Script readers and writers named, but several call sites that build the path or take the repository from the container are not (finding 1). |
| Consequences | Good | Test flip at `test_merge_pr_gate.sh:483-509`, no project name in the new fixture, repo-wide stale search, 393 reversal in PR text. Grep answer for the wording below. |
| Principle alignment | Needs work | One mechanism, as directed: `resolve_issue_records` returning dir, commit_repo, key, identity, with `records_layout` as the one place other combinations land. Right mechanism. Two gaps: not every caller goes through it yet (finding 1), and the same bare-number confusion recurs one level down, in the pull request number inside a shared timeline (finding 2). |
| ADR compliance | Good | ADR-0013 note scoped to the default combination; ADR-0003 synthetic fixture; ADR-0016/0018 unchanged. Finding 2 touches ADR-0013's `**PR**: #M` correlation key if the gate stays in part 1. |
| ROS conventions | N/A | Workspace plan. |

Checked against the scripts: `_resolve_work_plans_dir.sh` (sourced only, refuses execution at 128); `progress_append.sh` 65, 73, 87; `review_progress.sh` 113-117, 267-305, 392; `dispatch_phase.sh` 271, 352, 365-368, 396-398, 452-502, 544-548; `find_worktree_by_issue` (`_worktree_helpers.sh:315`) takes a qualified ref; `merge_pr.sh` 443, 456-528 (header via `head -n1` at 497), 673-683, 726-727, 805, 818-853, 887-893, 986; `_bookkeeping.sh:190`; `worktree_create.sh` 756 (manifest) before 880 (`--workflow`); manifest header `issue=<owner/repo#N|N>` (`_worktree_helpers.sh:405`); `extract_gh_slug` returns empty for a non-GitHub origin (`_issue_helpers.sh:22-28`).

Test coverage asked for: bare number from the package worktree's top folder (case 1) yes; from inside a second package repository (case 2, with a pre-existing sibling `issue-N`) yes; sibling `feature/<repo>-issue-N` pull request at the gate including where `_gate_record` writes (case 4) yes; two repositories with the same issue number: yes inside one package worktree (case 2) and for the outside layout (case 5), not for two package worktrees under one root (finding 4).

### Findings

1. **[File targeting / must-fix]** Not every caller goes through the lookup. Script sites the plan does not name: `dispatch_phase.sh:367` (`git -C "$wt" symbolic-ref` for the round count's branch) and `:502` (`check-exit` prints `sha=` from `git -C "$wt" rev-parse HEAD`): for a package worktree `$wt` is the container, so both read the enclosing hosting repository; take them from `commit_repo`. `merge_pr.sh:839,847` and `_bookkeeping.sh:190` build `.agent/work-plans/issue-N` relative to the repository by hand; derive it from `dir` relative to `commit_repo`. Skills that build the path themselves, not just cite it: `sitrep/SKILL.md:341` (`$d/.agent/work-plans/issue-$issue/progress.md` over worktree dirs, misses a package timeline), `triage-reviews/SKILL.md:138` (`$(git rev-parse --show-toplevel)/...`), `address-findings/SKILL.md:91`, `review-plan/SKILL.md:102-107` (worktree glob to the container). Skills cannot call the lookup today, since `_resolve_work_plans_dir.sh` refuses to run unsourced; add one executable entry point (for example `review_progress.sh records --issue <ref> [--from <dir>]` printing the four fields) and route these sites through it. The plan's "each verified against the lookup" is not routing.
2. **[Principle alignment / must-fix]** The identity defect recurs one level down. Once the owning repository's timeline holds entries for pull requests from several repositories, the pull request number is a bare number too: gate condition (a) takes the `last` review entry of any pull request (`merge_pr.sh:726-727`), `_gate_already_recorded` matches `.correlation.pr == PR_NUMBER` (887-893), and `_gate_record` writes `**PR**: #${PR_NUMBER}` (805). A sibling pull request is judged against the owning pull request's review, and sibling #M and owning #M share one idempotency key. The lookup mechanism is still right; the identity has to reach the pull request correlation as well. Either (a) the gate keeps the sibling case in part 1 and selects and writes entries by the pull request's repository and number (`**PR**: owner/repo#M` for a pull request outside the owning repository, parsed by `progress_read.py:183-189`, ADR-0013 note), with a test where owning #M and sibling #M share the timeline; or (b) recommended, cut the merge gate to part 3, which already owns the package pull request path and decides blocking: part 1 leaves `merge_pr.sh` and `_bookkeeping.sh` unchanged (report-only, PR comment, as today, as the first review allowed), and part 3 does gate, `_gate_record` and pull-request identity together.
3. **[Principle alignment]** Owning-repository selection (step 3) requires slug match and branch. The header may carry a bare `issue=N` (`_worktree_helpers.sh:405`) and a non-GitHub origin gives an empty slug, so the lookup fails loudly for such a project. Select by the `feature/issue-N` branch (the adapter's owning-repository rule), and use the slug as a cross-check only when both header and origin carry one. In `records_layout`'s outside branch, do not build the key from an empty owner/repo (`----N` collides).
4. **[Test what breaks]** Add two package worktrees under one root for different repositories with the same number (`pkg_a#7`, `pkg_b#7`): `dispatch_phase.sh --issue owner/pkg_a#7` and `owner/pkg_b#7` each find their own worktree and records, and a bare `7` from the project session is refused as ambiguous.
5. **[Principle alignment]** "One more branch, not new return fields" holds for `location=outside` and `tracking=untracked`, not obviously for `tracking=repo`, whose writer also needs the branch and push timing (decision 9 defers it). Soften the claim to "the other combinations land in `records_layout`; `tracking=repo` may add a branch field".

Suggestions of the first review (findings 4 to 10 and the Consequences items): dispatch qualified-ref and its test both in part 1, taken. `worktree_create.sh --workflow` through the lookup after the manifest write, taken. `extract_gh_slug` and `head -n1` reuse, taken (see finding 3). Step 5 trimmed to the stale clause, taken. Open Question dropped, taken. Settings rc 2 refuses and project-name rule per worktree kind, taken. Nine skills named, taken in name, routing is finding 1. No project name in the new fixture and the flipped gate expectation, taken.

Wording ("until the records lookup lands"), checked by grep: `register_project.sh:798` prints it itself ("not stored until the records lookup lands"), asserted by `tests/test_register_project.sh:347`, so it changes with `_project_registry.sh:1449,1700` (whose 1700 text is asserted by `tests/test_project_file.sh:1243`); the `_project_registry.sh:1470` comment and the `project_setting.sh:20-23` header comment carry it too. `registration_verify.sh:131` and `dashboard.sh:199` print only "valid but not yet honoured (#393)", which stays true after part 1: leave them.

### Summary

The revision answers the three must-fixes with one mechanism, the right one, and the return shape gives the other records combinations a clean place to land. Not yet ready: several call sites, mostly in skills that have no way to call the lookup, still build the path or take the repository from the container, and the gate carries the same bare-number confusion in the pull request number; cutting the gate to part 3 fixes that and brings part 1 to a fair size.

### Recommended Actions

- [ ] Route `dispatch_phase.sh:367,502`, `merge_pr.sh:839,847`, `_bookkeeping.sh:190` and the skills at `sitrep:341`, `triage-reviews:138`, `address-findings:91`, `review-plan:102-107` through the lookup, with one executable entry point for skills (finding 1)
- [ ] Move the merge gate to part 3, or key gate selection, idempotency and `**PR**:` by the pull request's repository and number with a shared-timeline test (finding 2)
- [ ] Select the owning repository by branch, slug as cross-check; no empty-slug key in `records_layout` (finding 3)
- [ ] Add the two-package-worktrees same-number test (finding 4); soften the return-shape claim (finding 5)
- [ ] Edit `register_project.sh:798` with its test and the two comments; leave `registration_verify.sh` and `dashboard.sh`

## Checkpoint
**Status**: complete
**When**: 2026-11-10 11:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second plan review: the identity mechanism is confirmed right; two must-fixes about its reach, both mechanism, no change of scope; second host revise in a row, so the next answer at this checkpoint is the owner's)
**After**: plan
**Decision**: revise

Host read the second Plan Review of 2026-11-10 (needs-work, 2 must-fix, 2 suggestions) and directs:
- Must-fix 1: one executable entry point for the lookup (the sourced resolver stays as its library), and every site the review lists goes through it: `dispatch_phase.sh` (the branch and `sha=` reads), `_bookkeeping.sh`, and the skills that build the path themselves. Nothing builds the path by hand after part 1 except the lookup.
- Must-fix 2: take the review's recommendation. The merge gate (`merge_pr.sh` gate conditions, the duplicate check, `_gate_record`) moves to part 3, where the pull request's own identity (repository and number) is handled once together with the publish target. Part 1 leaves `merge_pr.sh` reading as today and says so; the existing merge-gate test's expectation does not flip in part 1.
- Take both suggestions: the owning repository is picked by its `feature/issue-N` branch with the slug as a cross-check, an empty slug never enters a key; add the two-worktree test (the same number in two package repositories, qualified ref finds each, a bare number is refused); soften the `tracking=repo` claim. Use the review's grep answer for the wording files: edit `register_project.sh` and its two test assertions and the two comments; leave `registration_verify.sh` and `dashboard.sh`.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 10:10 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-429/plan.md` at `ec2594de`

Second revision: one executable records entry point (review_progress.sh records) with a hand-built path audit across the repository; merge gate moved to part 3 with the pull request identity; owning repository chosen by feature/issue-N branch, slug as cross-check, no empty-slug key; two-package-worktree test added; tracking=repo claim softened; wording edits per the grep answer.

## Plan Review
**Status**: complete
**When**: 2026-11-10 10:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #429 — run-issue: drive an issue in a package repository of a multi-repository project
**Plan**: `.agent/work-plans/issue-429/plan.md` at `ec2594de`
**Branch**: `feature/issue-429`

Third review, a narrow convergence check after the host's second revise (11:25). Scope: the second review's must-fixes and suggestions, and this revision's own changes (entry point and audit, gate cut to part 3, part 1 size). Nothing an earlier review accepted is reopened.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | 26 files, one mechanism. Take the plan's own fallback from the start (answer below). |
| Issue alignment | Good | Serves, as checked: workspace goal "A project can be worked from its own root", `docs/design.md#worktrees` (Records, Target), `docs/design.md#review-loop-and-timeline`. Unchanged since the second review. |
| File targeting | Needs work | Audit grep re-run (`git grep -n work-plans` over the repository): two sites wrongly left or missing that part 1 breaks (findings 1, 2), four minor omissions (finding 4). |
| Consequences | Needs work | `_bookkeeping.sh` is the merge gate's own rule, so routing it in part 1 changes the gate that decision 7 says stays as today (finding 1). |
| Principle alignment | Needs work | The lookup's bare-number rule judges the caller's `$WORKTREE_ISSUE`, not the directory it is handed, so callers that are environment-independent today become environment-dependent (finding 2). |
| ADR compliance | Good | ADR-0013 note scoped to the default combination; ADR-0003 synthetic fixture; gate and `**PR**:` identity in part 3. |
| ROS conventions | N/A | Workspace plan. |

Second review resolved, checked in the plan: must-fix 1 (one executable entry point `review_progress.sh records`, the library stays sourced; `dispatch_phase.sh` 367 and 502 from `commit_repo`; the skills at `sitrep` 341, `triage-reviews` 138, `address-findings` 91, `review-plan` 102-107 routed): yes, but see findings 1 and 2 for what the routing does. Must-fix 2 (gate to part 3, `merge_pr.sh` and `test_merge_pr_gate.sh:483-509` unchanged in part 1): yes for `merge_pr.sh`, not for its helper (finding 1). Owning repository by `feature/issue-N`, slug as cross-check, no empty-slug key: yes (steps 3 and 6, case 4). Two-worktree test: yes (case 4). `tracking=repo` claim softened: yes. Wording files per the grep answer: yes.

Checked against the code: `_resolve_work_plans_dir.sh` rule 2 trusts `$WORKTREE_ISSUE` and rule 2b runs only when it is unset (58-99), rule 3 refuses; `dispatch_phase.sh` builds `$wt/...` from `resolve_worktree` with no environment check (352-368); `_bookkeeping.sh:189-190` pathspec is constant and repository-relative; its callers `merge_pr.sh:760` (`$_ci_wt`, the pull request's worktree toplevel, 689-700) and `review_progress.sh sources` at 405 (`os.getcwd()`; comment 388-391: "The timeline file may live outside that repository"); `sitrep_root.sh` `repository()` (470-480, `repository_dirs` from the header slug or the checkouts' agreement) and its tests at `test_sitrep_checks.sh:1040-1100`; `test_project_registry.sh:1477-1520` (`_review_plan_find_plan`, a copy of `review-plan` 102-107).

### Findings

1. **[Consequences / must-fix]** `_bookkeeping.sh:190` is the merge gate's coverage rule, so routing it through the entry point in part 1 changes the gate, against decision 7 ("part 1 leaves `merge_pr.sh` reading as today"). Today the pathspec `.agent/work-plans/issue-N/*` is a constant, independent of cwd, environment and settings. Through `records --issue N --from <wt>` it can be refused: by a mismatched `$WORKTREE_ISSUE` (finding 2), by `review_progress.sh sources` passing `os.getcwd()` from outside the issue's worktree (the case its comment at 388-391 allows), and by project settings rc 2 or 3. A refusal turns "only bookkeeping since the review" into "review coverage could not be confirmed", which blocks a workspace merge that passes today (every pull request gets `progress:` commits after its review). Resolution: leave `_bookkeeping.sh` unchanged in part 1 and move it to part 3 with the gate (in the default combination the repository-relative pathspec is already right for the owning package repository); list it under "Left" in the audit with that reason.
2. **[Principle alignment / must-fix]** The bare-number rule with an explicit `--from` still trusts the caller's `$WORKTREE_ISSUE` (step 4: "rules 2 and 2b of the existing function, anchored on the toplevel of `<from-dir>`"; rule 2 matches the variable, rule 2b only runs when it is unset). `dispatch_phase.sh` and the sitrep listing already know the worktree and today read it with no environment check; after part 1 a shell where `worktree_enter.sh` exported another issue (script-flow agents, a terminal, an orchestrator that entered one worktree and drives another) is refused for an ordinary single-repository issue. Resolution: with `--from`, judge the directory by its own manifest, basename `issue-*-N` or branch `feature/issue-N`, never by `$WORKTREE_ISSUE` (the #147 guard stays for the cwd form); add a case: `WORKTREE_ISSUE=<other>` set, `dispatch_phase.sh dispatch --issue <N>` still names `<wt>/.agent/work-plans/issue-<N>/progress.md`. In the same vein, `sitrep` is a read-only report: a refusal of the entry point must become the row's "unknown (<reason>)" text, not an error.
3. **[File targeting / must-fix]** `test_sitrep_checks.sh` is wrongly "left" as a fixture that "builds inputs": its step-3 tests (1009-1100) run the very `sitrep` block part 1 rewrites. Two of their fixtures stop passing through the lookup: `$SB/wt7` (basename not `issue-*-7`, one entry detached) fails rule 2b, and every package fixture puts all checkouts on `feature/issue-N`, which step 3 refuses as "several". Real worktrees name siblings `feature/<repo>-issue-N` (ros2_colcon adapter 772), so update the fixtures to that and keep the existing expectations (header repository's timeline, not another repository's issue N; bare header with no single owner gives no guess). Add the file to Files.
4. **[File targeting]** Audit omissions (minor, wording or tests): `sitrep_root.sh` `repository()` is a second owning-repository rule (header slug or checkout agreement) with no `work-plans` literal, so the grep cannot find it; say which rule wins for sitrep rows or make it consume the lookup. `test_project_registry.sh:1477-1520` copies `review-plan` 102-107 and keeps testing the old glob after the skill changes; update it with the skill. `run-issue/SKILL.md:292` quotes the implement task text that `dispatch_phase.sh:271` changes. `address-findings` 45 and 77, `.agent/knowledge/review_loop_lifecycle.md:47` and `.agent/workflows/README.md:10,71` describe the path and belong on the reworded list. `cross_model_review.sh:1231` (diff filter) is a pattern and right as it is; list it as left.
5. **[Consequences]** Step 5 makes every loop reader and writer refuse a project issue when the project's settings file is malformed (rc 2) or holds a hand-set non-default combination (rc 3), where today the loop runs on the default path (the 1449 warning says so). Accepted earlier as a decision; say it in the part 1 pull request and run `registration_verify.sh` over the registered projects before merging so no current project stops. Also state what the lookup does when the registry itself does not parse (`registry_resolve_session_dir` rc 2): a workspace issue's lookup reads no registry today and should not start failing on it; test the workspace case with a broken registry.

### Size

26 files is one mechanism but not one reviewable pull request: ten shell scripts with a new subcommand, four test files, and nine skills of which six change behaviour (they call the entry point and are driven by tests such as `test_sitrep_checks.sh`). Take the plan's fallback from the start: part 1a is the library, entry point, script consumers, messages, their tests and the design/script-reference/ADR-0013 text; part 1b is the nine skills with `test_sitrep_checks.sh` and the `test_project_registry.sh` copy. The window between them is safe: skills keep building `<worktree>/.agent/work-plans/issue-N`, which is the lookup's answer for every single-repository issue, and no package issue is driven until part 2.

### Summary

The second review's two must-fixes and suggestions are resolved in the plan, and the gate cut leaves `merge_pr.sh` itself as today. Part 1 still changes the gate through its helper `_bookkeeping.sh`, and the lookup's bare-number rule makes environment-independent callers depend on `$WORKTREE_ISSUE`; both can refuse an ordinary single-repository issue that works today. Fix those, move the sitrep test into scope, and split part 1 into scripts then skills.

### Recommended Actions

- [ ] Leave `_bookkeeping.sh` to part 3 with the gate; list it as left with the reason (finding 1)
- [ ] With `--from`, judge the directory, not `$WORKTREE_ISSUE`; test dispatch with a mismatched variable; sitrep turns a refusal into row text (finding 2)
- [ ] Add `test_sitrep_checks.sh` to Files; sibling fixtures on `feature/<repo>-issue-N`, existing expectations kept (finding 3)
- [ ] Audit omissions: `sitrep_root.sh` rule, `test_project_registry.sh` copy, `run-issue` 292, the docs and `address-findings` lines (finding 4)
- [ ] Pull request states the rc 2/3 stop and checks registered projects; broken-registry workspace case tested (finding 5)
- [ ] Split part 1: scripts first, skills second (Size)

## Checkpoint
**Status**: complete
**When**: 2026-11-10 13:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: revise

At the third plan review (needs-work, 3 must-fix, a size finding) the owner asked: "Are we struggling with this because we missed something, or are we on the right path and just need to polish the plan a little?"

The host answered that something was missed, by its own decision: the design held in all three reviews, but the host had folded the whole records lookup (issue 393, a refactor of about 20 scripts and 9 skills that build the records path by hand) into the first step of this issue. For a project on the default records setting the records go in the package repository that owns the issue, and the existing scripts already find that place when a phase runs from inside that repository's checkout (`_resolve_work_plans_dir.sh` and `progress_append.sh` work from `git rev-parse --show-toplevel`; the first plan review noted the same). Not yet checked: the dispatcher, which takes a bare issue number, and the merge gate. The host offered R1 (one more plan round asking only for the least change that lets the loop run from the owning repository's checkout, and where that breaks; the full lookup stays as issue 393) and R2 (continue with the lookup in two pull requests).

The owner's answer, verbatim: "R1, try the small route first"

## Plan Authored
**Status**: complete
**When**: 2026-11-10 11:33 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Plan**: `.agent/work-plans/issue-429/plan.md` at `6b328060`

Replan on the small route (owner: "R1, try the small route first"). It holds, with five changes in two
pull requests. The evidence came from a synthetic sandbox that ran every loop script from the session
root, the package worktree's top folder, the owning checkout and a sibling checkout with the same issue
number. PR 1: `dispatch_phase.sh` accepts `owner/repo#N` and maps a manifest worktree to the issue's
checkout (prototyped in the sandbox), and adds `where`. A manifest-scoped guard refuses records writes
from a sibling or the top folder (today they commit silently into the sibling's own timeline or the
workspace main branch). Also in PR 1: `run-issue` text (step 1 `cd`, publish `-R`, step 11 root and
qualified `--pr`, Scope), the literal records lines in review-plan and address-findings, a new test
suite, and the design Records bullet. PR 2: the merge gate reads and records the owning checkout's
timeline and stays report-only. The records lookup stays with issue 393.

## Plan Review
**Status**: complete
**When**: 2026-11-10 11:44 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #429 — run-issue: drive an issue in a package repository of a multi-repository project
**Plan**: `.agent/work-plans/issue-429/plan.md` at `6b328060`
**Branch**: `feature/issue-429`

Fresh review of the small-route replan (owner: "R1, try the small route first"). Earlier reviews of the larger approach are not carried over.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two pull requests, about 11 and 3 files; the records lookup stays with issue 393. Nothing in PR 1 is removable without breaking the route (see Least change). |
| Issue alignment | Good | Serves, as checked: "Workspace goal 'A project can be worked from its own root'. Design: `docs/design.md#worktrees` (Records) and `docs/design.md#review-loop-and-timeline` (PR 2: `docs/design.md#merge-gate`)". The design anchors exist; the goal name does not appear under `README.md#workspace-goals` (finding 5). |
| File targeting | Needs work | `run-issue` lines 244 and 497 (`PF="<worktree>/..."`) and the handoff's `conventions=` line are not in the change list (findings 2, 3). |
| Consequences | Good | Design Records bullet, script reference, `run-issue` Scope; gate text in PR 2. |
| Principle alignment | Needs work | Verify before claiming: "In A, identity comes from the repository itself (`gh` and git both resolve `owner/pkg_a`)" is false for a checkout with an `upstream` remote, checked with real `gh` (finding 1). |
| ADR compliance | Good | ADR-0003 synthetic fixture; ADR-0012 manifest rule; ADR-0013 unchanged under the default setting; ADR-0017 design in the same pull request. |
| ROS conventions | N/A | Workspace plan. |

**Evidence re-run.** Fresh sandbox from the planner's `sb429_setup.sh` (this branch's HEAD, unmodified scripts), package worktree for `owner/pkg_a#7` created from H: `pkg_a` on `feature/issue-7`, `pkg_b` on `feature/pkg_a-issue-7`, C's toplevel the workspace main checkout. All matched the plan's table:
- `dispatch_phase.sh --issue 7 --skill review-plan` from H prints `worktree=C` and an exit contract under C (breaks row).
- `--issue owner/pkg_a#7` is refused ("--issue <N> is required"); `next --issue 7` says `action=review-issue` while A holds a Plan Authored entry; with `--progress <A>` it says `action=review-plan`.
- `progress_append.sh 7` from C committed `progress: checkpoint for #7` on the workspace's `main`, rc 0 (silent write).
- `review_progress.sh persist` (compatibility) from B printed "would have aborted", then committed into `pkg_b`'s own merged issue-7 timeline on `feature/pkg_a-issue-7`, rc 0 (silent write).
- Resolver: A resolves with `WORKTREE_ISSUE` unset or 7; B, C, H refuse when unset; with `WORKTREE_ISSUE=7`, B gives B's own directory and C and H give the workspace main checkout's.
- `persist --strict` from A commits in A.
- `worktree_enter.sh --issue owner/pkg_a#7` exports `WORKTREE_ISSUE=7` and lands in C.

**Guard placement.** The writers that commit records are `progress_append.sh` (also the strict path of `persist` and `merge_pr.sh`'s `_gate_record` at 837), `persist`'s compatibility write, and `plan-task`'s `git commit` of `plan.md`, whose directory comes from `resolve_work_plans_dir` (plan-task 147). The plan puts the guard in all three places, so it closes B and C for every writer, not only the dispatched paths. Rule 1 (`WORK_PLANS_DIR_OVERRIDE`) skips the resolver's guard, but strict `persist` still ends in `progress_append.sh`, so that case is covered too. `review_progress.sh check` writes no commit: it edits the `--progress` file in place, and the host then runs a plain `git commit`. That is safe only if the host's `PF` names A (finding 2). Single-repository issues are unchanged. Workspace worktrees have no manifest. `worktree_create.sh` 741-756 writes no manifest for a lone `.` entry, so single-repo project worktrees have none either, and the guard does nothing for both. The plan says single-repo project worktrees "write" a `.` entry. That is wrong, but harmless (finding 4).

**Pull request dependency.** PR 1 does not depend on PR 2. With PR 1 alone, `next` reads A's timeline, so a package issue reaches the merge checkpoint. Step 11's `merge_pr.sh --pr owner/repo#M` exists today. The gate takes its existing "carries no issue timeline" branch (merge_pr.sh 673-716), which is report-only, and posts its record as a comment. PR 2 needs PR 1's guard to accept A, which is the right direction.

**Least change.** Nothing in PR 1 can go without breaking the route. The ambiguity-message passthrough is the only polish, and it costs three lines. PR 2 could wait without breaking anything. Until it lands, each package merge posts a false "would have refused" comment on the package repository, and PR 1's description should say so.

**Main-checkout gap (case H).** A separate issue is right for the guard: closing it changes compatibility mode for every issue, and existing tests assert that behaviour. But the gap is more likely than "a sub-agent that forgets to `cd`". Checked in this run: a dispatched sub-agent's shell returns to the session's start folder on every call. My calls after `cd <worktree> && ...` ran in `/home/roland/agent_workspace`, the main checkout on `main`. So every command chain without its own `cd` runs at H. Finding 3 covers what PR 1 should carry, and the follow-up should be filed before the acceptance run.

### Findings

1. **[Principle alignment / must-fix]** The route rests on "in A, `gh` resolves `owner/pkg_a`". Real `gh` 2.103.3, run non-interactively in a checkout whose origin is `rolker/agent_workspace` and whose `upstream` is `cli/cli`, chose `cli/cli` for both `gh repo view` and `gh issue view 1`. gh ranks `upstream` above `origin` when no default is set. A package checkout that is a fork with an `upstream` remote would therefore read the upstream project's issue N. `review-issue` would post its findings with `gh issue comment <N>` (SKILL 232, no `-R`) on the upstream project's issue: a silent wrong-repository write, outward. Today's registered package checkouts carry no `upstream` (0 of 88), so it is latent, but the workspace is project-agnostic. Resolution: `where` (or `run-issue` step 1) checks `gh repo view --json nameWithOwner` from the mapped checkout against the ref's `owner/repo`. On a mismatch it refuses and names `gh repo set-default <owner/repo>` as the remedy. Add a test case with an `upstream` remote and a stub that ranks `upstream` first. Replace the "not tested" line with this check.
2. **[File targeting]** `run-issue` 244 and 497 build `PF="<worktree>/.agent/work-plans/issue-<N>/progress.md"` for `$BEFORE` and for `findings` / `check`. For a package issue, "the worktree" is C, the path `start-task` prints. A `PF` under C gives `BEFORE=0`, while `--check-exit` reads A, so a repeated entry type (a second Plan Review) is reported OK when the phase wrote nothing. Say in the `run-issue` change that `<worktree>` is `where`'s output (or `$(git rev-parse --show-toplevel)` after step 1's `cd`), and list both lines.
3. **[File targeting]** The plan lists "the Agent tool's sub-agent working directory" as not tested, with no action. It was checked here (see the gap section): the cwd resets per call, so a phase that obeys "cd into it first and stay there" (this very handoff's wording) runs most calls at H. Resolution: in PR 1, the handoff's `conventions=` line (dispatch_phase.sh 415) says "start every command chain with `cd <worktree> &&`". At the acceptance run, check that the workspace main checkout, the session root's repository (if any) and the sibling checkouts gained no commits.
4. **[Consequences]** Correct the plan's text: single-repo project worktrees write no `.worktree-repos` (worktree_create.sh 741-756; `wt_read_manifest` makes up the `.` entry). Test case 3 should use that real shape (no manifest), and a legacy one-entry `.` manifest if it is kept.
5. **[Issue alignment]** The Serves goal "A project can be worked from its own root" is not a goal under `README.md#workspace-goals`. The nearest is "Easy to use" ("start an agent in the project's own directory and the workspace is there"). Name the section. Decision 1 (records in the package repository) also touches "Light touch on projects", which the veto list already covers.
6. **[Consequences]** Once the host `cd`s into A, the `$WS_ROOT` fallback `.` resolves to A, which has no `.agent/scripts`. Without the user tier, every later `$WS_ROOT/.agent/scripts/...` call fails, loudly. State that a package issue needs the user tier, or have step 1 capture an absolute `WS_ROOT` before the `cd`.

### Summary

The evidence is real: seven rows re-run from a fresh sandbox, including both silent writes, all matched. The guard is in the right places for B and C across every records writer, and it does nothing to single-repo issues. PR 1 stands alone and reaches the merge checkpoint. One must-fix: the claim that gh resolves the owning repository is false for a checkout with an `upstream` remote, and that leaves an outward wrong-repository write open. The remaining findings are small text and test changes.

### Recommended Actions

- [ ] `where` / step 1 checks gh's default repository against the ref and refuses on a mismatch; test with an `upstream` remote (finding 1)
- [ ] `run-issue` 244 and 497: `PF` from `where`'s path (finding 2)
- [ ] Handoff `conventions=`: `cd <worktree> &&` on every command chain; acceptance-run check for stray commits; file the case-H follow-up before that run (finding 3)
- [ ] Fix the single-repo manifest wording and test case 3's fixture (finding 4)
- [ ] Serves names the README goal section (finding 5)
- [ ] State the user-tier requirement or capture `WS_ROOT` before the `cd` (finding 6)

## Checkpoint
**Status**: complete
**When**: 2026-11-10 14:20 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review re-ran the plan's evidence and all 7 rows matched; its one must-fix and five suggestions are each a specific, bounded addition the implementer can apply, none changes the route the owner chose; the previous answer at this checkpoint was the owner's, so this is the host's first in the run)
**After**: plan
**Decision**: proceed

Host read the Plan Review of the small route (needs-work, 1 must-fix, 5 suggestions) and carries all six to the implementer of pull request 1 as directions:
- Must-fix: the one place that decides the directory also checks that `gh` resolves to the issue's own repository from that checkout (`gh repo view` against the ref), refuses on a mismatch, and has a test with an `upstream` remote. Real gh prefers `upstream` over `origin`, so a forked checkout would otherwise send issue comments to the upstream project.
- The run-issue text takes the progress path from `where`, never from the worktree's top folder.
- The handoff's `conventions=` line tells a dispatched phase to `cd <worktree> &&` on every command chain, since a sub-agent's shell returns to the session's start folder on each call; the acceptance run checks for stray commits.
- Single-repository project worktrees write no `.worktree-repos`: fix the plan's wording and the test fixture.
- Serves names a README workspace-goals heading.
- `WS_ROOT` is captured before the host moves into the owning checkout, or the user tier is required and said so.
Pull request 2 (the merge gate reads the owning checkout's timeline) follows pull request 1. The gap that exists for workspace issues too (records committed into a main checkout from outside any worktree) is a separate issue; opening it is the owner's, asked at the next hand-back.

## Implementation
**Status**: complete
**When**: 2026-11-10 12:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-429 at `c225c951`

Pull request 1 of the plan (the loop runs in the owning checkout), with the six directions from the plan checkpoint. Pull request 2 (the merge gate) is not started.

- `1cd31fb5` Records guard: `issue_checkout_of` and `issue_checkout_guard` in `_resolve_work_plans_dir.sh`. Inside a package worktree only the checkout on `feature/issue-N` commits the issue's records; a sibling checkout and the top folder are refused, naming the right checkout. Run by resolver rules 2 and 2b, `progress_append.sh` (new exit 4) and `review_progress.sh persist` in both modes, before the compatibility-mode write (exit 4). A lone `.` entry is the worktree itself; any other single entry must still be on `feature/issue-N`, so a worktree holding only a sibling has no owning checkout and refuses. `test_merge_pr_gate.sh`'s fixture copies the resolver.
- `06bb6047` `dispatch_phase.sh`: every mode takes `owner/repo#N`; `resolve_issue_dir` is the one place that decides the directory. The handoff gives `worktree=` (the owning checkout) and `package_worktree=`; the exit contract, `next`, `--check-exit`, `sha=` and the round branch follow it. New `where` subcommand. The ambiguity message for a bare number is passed through. `conventions=` says `cd <worktree> &&` on every command chain. Direction 1: the handoff and `where` run `gh repo view --json nameWithOwner` in the owning checkout and refuse a mismatch with the manifest's `owner/repo`, naming both and `gh repo set-default`. `next` and `--check-exit` stay gh-free. `test_dispatch_phase.sh` fixtures copy the resolver.
- `268ba32d` New `test_package_issue_loop.sh`, 56 checks, synthetic: two package repositories, bare remotes over a `GIT_SSH_COMMAND` stub, the same issue number in both, and a stub `gh` that ranks set-default, then upstream, github, origin. Cases: H naming A for where, handoff, next, check-exit and the round branch; the second repository; bare 7 refused; a workspace issue and a single-repo project issue unchanged (no manifest written, no gh asked), plus a legacy `.` manifest; every writer commits in A and refuses B and C (also `-C`), with HEAD and status unchanged in the workspace main checkout, B, pkg_b's own checkout and the second worktree; the resolver with `WORKTREE_ISSUE=7`; no owning entry; an upstream remote, set-default, and a failing gh.
- `ad74dfef` review-plan's issue-number lookup tries the current repository first. Its `--ref` plan-sha and `git show` lines take a top-folder-relative `./.agent/...` path; checked: `plan-sha --plan ./... --ref HEAD` works from the top folder and from a subfolder. address-findings reads progress.md from the current repository.
- `eb9002cc` run-issue: usage `owner/repo#N`, `--layer` and `--package-repos`; step 1 `cd "$(dispatch_phase.sh where ...)"`; every call passes `<ref>`. Step 4 and step 6 `PF` come from `where` (direction 2). The `package_worktree=` and `cd` convention are pasted on; publish uses `-R`; step 11 `cd`s to the session root `root=` and passes `--pr owner/repo#M`. The skill-prefix paragraph says the prefix is read at the root only. Scope is rewritten.
- `68f6d3b5` design Records bullet (and the line citations of the three changed scripts), a change-log row, and the script reference rows.
- `c225c951` plan.md: Serves names `README.md#easy-to-use` (direction 5, plus `#light-touch-on-projects` for decision 1). The single-repo manifest wording is corrected (direction 4), and the gh "not tested" line is replaced.

Direction 6, picked: a package issue requires the user tier, checked in step 1 before anything is created. A captured absolute `WS_ROOT` does not survive between tool calls. That makes the check the loudest failure: one message naming the installer, instead of a missing-file error at whichever call comes first.

Checks: `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, rc 0. That includes the script-suite hook, which runs every suite because a shared helper changed, and shellcheck. Also run on their own: test_dispatch_phase 139/0, test_resolve_work_plans_dir 21/0, test_progress_append 23/0, test_skill_paths 136/0, test_checkpoint_269 43/0, test_address_findings 15/0, test_package_issue_loop 56/0.

Not done:
- The implement handoff's exit contract names `.agent/scripts/progress_append.sh` relative to the checkout, and the task line `.agent/work-plans/issue-N/plan.md` the same way. In a package repository's checkout the script path does not exist (the plan path does). A dispatched implement pass there would hit a missing file and have to find the workspace script. Neither the plan nor the directions name this; the fix is `$SCRIPT_DIR`, an absolute path, in the contract.
- The case-H follow-up issue (writes from outside any worktree, compatibility mode) is the host's to file, as the checkpoint says.
- The acceptance-run check for stray commits in the workspace main checkout, the session root and sibling checkouts (plan review finding 3) belongs to that run.
- The prototype sandbox at `.../scratchpad/impl429` was not removed (rm denied).

## Implementation
**Status**: complete
**When**: 2026-11-10 12:20 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-429 at `8ac2ca32`

The coordinator asked for two things before the first review of pull request 1.

- Merge from main landed as `f3ab3f27` (`git merge main`, no rebase). The one conflict was `docs/design.md`, in the change log only: both sides added a 2026-11-10 row. I kept both, main's Documentation layers row first and then this branch's #429 row, and changed the #429 row's line count to the merged file's 879. Main's other changed files (`docs/roadmap.md`, issue 432's records) merged cleanly.
- `8ac2ca32` (the exit-contract gap, item 2): the implement handoff's exit contract now prints `progress_append.sh` and the run-issue `SKILL.md` by absolute path into the workspace that `dispatch_phase.sh` runs from. That applies to every issue type, so workspace issues print the absolute path too: one code path. The other paths the handoff prints:
  - `conventions=`: its only command, the workspace hook rule's pre-commit, was already absolute. The new `cd` line names the worktree, which is absolute.
  - Task lines: these are slash commands, except implement's plan path. That path stays relative, because it names the records directory, which is in the phase's own checkout.
- Tests:
  - `test_package_issue_loop.sh` extracts the printed command from the contract. It runs it inside the owning package checkout, which has no `.agent/scripts`, and checks the entry is committed there. It also checks that the printed skill path exists. 58 passed, 0 failed.
  - `test_dispatch_phase.sh` checks both absolute paths for a workspace issue: 140 passed, 0 failed.
- `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed (rc 0), including the script-suite hook and shellcheck.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-10 12:32 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-429 at `6d35497a`
**Base**: main
**Depth**: Deep (reason: 14 files, +1647/-96; records writers' guard and three governance-touching skills plus docs/design.md)
**Must-fix**: 3 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

Pull request 1 of 2 (the loop runs in the owning checkout). The guard holds for `progress_append.sh` and both `persist` modes against every path tried: a symlink into B or C, a subfolder of A (commits) and of B (refused), a non-repository subfolder of C, `-C` from A to B and from the session root to C, `WORKTREE_ISSUE=7` from B, a detached HEAD in A (commits in A; `where` still names A), and an issue number the manifest is not for. Reverting each piece in a scratch copy fails the new suite (the guard in `progress_append.sh` 8 checks, in `persist` 6, the owning-checkout mapping 15, the gh check 3). Existing suites pass: test_dispatch_phase 140, test_merge_pr_gate 106, test_package_issue_loop 58, test_resolve_work_plans_dir 21, test_progress_append 23, test_review_code_convergence 35, test_triage_reviews_integration 59, test_issue_review_entry 6, test_address_findings 15, test_checkpoint_269 43, test_skill_paths 136, all 0 failed; shellcheck clean. No workspace or single-repository path asks gh anything (the check runs only when the directory differs from the worktree). The gh check sits in `resolve_issue_dir`, fails closed when gh fails, and compares `gh repo view` with the manifest's ref without parsing a remote URL.

Not closed, and not this pull request's: a write from outside any worktree. Reproduced: `progress_append.sh 7` from the session root committed on the workspace's `main`; `persist` with `WORKTREE_ISSUE=7` from the hosted pkg_b checkout committed on pkg_b's `main`. That is the follow-up issue the plan checkpoint left to the owner, and it should exist before the acceptance run.

### Findings
- [ ] (must-fix) `review_progress.sh check` (and the `findings` read that feeds it) has no guard, so address-findings' literal `--progress "$(git rev-parse --show-toplevel)/…"` from a sibling ticks pkg_b's own issue-7 review, and from the top folder ticks the workspace main's own issue-N review; the plain `git commit` then lands it there (both reproduced). The mechanism is right; the writer list missed the in-place editor: guard `check` and `findings` on the file's directory with N from its `issue-N` path, add the B and C cases, and make the design Records bullet and run-issue Scope name it — `.agent/scripts/review_progress.sh:580`
- [x] (must-fix) run-issue step 1 `cd "$(… where …)"` and the step 4 and step 6 `PF="$(… where …)/…"` fail open: a refused or failed `where` gives `cd ""`, a silent no-op (rc 0, reproduced), leaving the host in the top folder, and `PF=/.agent/…` gives `BEFORE=0`, so `--check-exit` (no gh) can report OK for a repeated entry type the phase never wrote. `where` now asks gh, so a transient gh failure is enough. Capture and stop: `d=$(…) || stop; cd "$d"` (cross-confirmed by codex) — `.claude/skills/run-issue/SKILL.md:217`
- [ ] (must-fix) The design cites `dispatch_phase.sh` lines 511, 513, 575, 687; since `8ac2ca32` they are 521, 523, 585, 697 (477 is right), while the change-log row says they were refreshed (cross-confirmed by gemini) — `docs/design.md:502`
- [x] (suggestion) The host's own chains after step 1 (`git push`, `gh_create_pr.sh`, `check_branch_updates.sh`, checkpoint appends) carry no `cd <dir> &&`, though the skill says shell state does not persist; give them the rule `conventions=` gives phases — `.claude/skills/run-issue/SKILL.md:226`
- [x] (suggestion) The gh check captures `gh repo view` with `2>&1`, so a stderr notice on success is compared as the repository name; capture stdout alone and quote stderr only in the error — `.agent/scripts/dispatch_phase.sh:312`
- [x] (suggestion) `round` (no `--progress`) and `findings` read the current top folder's timeline unguarded: from B or C a lost `cd` gives `round=1` or another repository's findings instead of a refusal; guard the reads with the same call as must-fix 1 — `.agent/scripts/review_progress.sh:120`
- [x] (suggestion) Case 3's "asked gh nothing" counts only `repo view` lines; count every gh line around the dispatcher calls alone — `.agent/scripts/tests/test_package_issue_loop.sh:274`
- [ ] (suggestion) The owning entry rests on the adapter's hand-written origin URL parser (`adapter_scope_for_pr`, pre-existing); the gh check backstops it for `where` and the handoff. Record it for issue 393 or its own issue, not here — `.agent/project_types/ros2_colcon/adapter.sh:868`

Belongs elsewhere: the merge gate reading A's timeline is pull request 2; `worktree_create.sh --workflow` scaffolding a timeline in the top folder (pre-existing) is issue 393's, as the plan says; writes from outside any worktree are the follow-up issue. Dropped: gemini's branch-match finding (the manifest's branch is the adapter's exact `feature/issue-N`, never the live branch).

Cross-model: gemini ran (complete, 2 findings: 1 kept as must-fix 3, 1 dropped); codex ran (complete, 1 finding, kept as must-fix 2). Claude adversarial ran (6 findings: 2 merged into must-fix 2 and 3, 3 suggestions, 1 to issue 393).
