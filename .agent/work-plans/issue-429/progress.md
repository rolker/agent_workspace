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
**When**: 2026-11-10 09:55 -05:00
**When-corrected**: written as 10:20 by the host from an estimate; corrected on 2026-11-10 to the entry's commit time
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
**When**: 2026-11-10 10:02 -05:00
**When-corrected**: written as 10:55 by the host from an estimate; corrected on 2026-11-10 to the entry's commit time
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
**When**: 2026-11-10 10:08 -05:00
**When-corrected**: written as 11:25 by the host from an estimate; corrected on 2026-11-10 to the entry's commit time
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
**When**: 2026-11-10 11:19 -05:00
**When-corrected**: written as 13:25 by the host from an estimate; corrected on 2026-11-10 to the entry's commit time
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
**When**: 2026-11-10 11:44 -05:00
**When-corrected**: written as 14:20 by the host from an estimate; corrected on 2026-11-10 to the entry's commit time
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
- [x] (must-fix) `review_progress.sh check` (and the `findings` read that feeds it) has no guard, so address-findings' literal `--progress "$(git rev-parse --show-toplevel)/…"` from a sibling ticks pkg_b's own issue-7 review, and from the top folder ticks the workspace main's own issue-N review; the plain `git commit` then lands it there (both reproduced). The mechanism is right; the writer list missed the in-place editor: guard `check` and `findings` on the file's directory with N from its `issue-N` path, add the B and C cases, and make the design Records bullet and run-issue Scope name it — `.agent/scripts/review_progress.sh:580`
- [x] (must-fix) run-issue step 1 `cd "$(… where …)"` and the step 4 and step 6 `PF="$(… where …)/…"` fail open: a refused or failed `where` gives `cd ""`, a silent no-op (rc 0, reproduced), leaving the host in the top folder, and `PF=/.agent/…` gives `BEFORE=0`, so `--check-exit` (no gh) can report OK for a repeated entry type the phase never wrote. `where` now asks gh, so a transient gh failure is enough. Capture and stop: `d=$(…) || stop; cd "$d"` (cross-confirmed by codex) — `.claude/skills/run-issue/SKILL.md:217`
- [x] (must-fix) The design cites `dispatch_phase.sh` lines 511, 513, 575, 687; since `8ac2ca32` they are 521, 523, 585, 697 (477 is right), while the change-log row says they were refreshed (cross-confirmed by gemini) — `docs/design.md:502`
- [x] (suggestion) The host's own chains after step 1 (`git push`, `gh_create_pr.sh`, `check_branch_updates.sh`, checkpoint appends) carry no `cd <dir> &&`, though the skill says shell state does not persist; give them the rule `conventions=` gives phases — `.claude/skills/run-issue/SKILL.md:226`
- [x] (suggestion) The gh check captures `gh repo view` with `2>&1`, so a stderr notice on success is compared as the repository name; capture stdout alone and quote stderr only in the error — `.agent/scripts/dispatch_phase.sh:312`
- [x] (suggestion) `round` (no `--progress`) and `findings` read the current top folder's timeline unguarded: from B or C a lost `cd` gives `round=1` or another repository's findings instead of a refusal; guard the reads with the same call as must-fix 1 — `.agent/scripts/review_progress.sh:120`
- [x] (suggestion) Case 3's "asked gh nothing" counts only `repo view` lines; count every gh line around the dispatcher calls alone — `.agent/scripts/tests/test_package_issue_loop.sh:274`
- [x] (suggestion) The owning entry rests on the adapter's hand-written origin URL parser (`adapter_scope_for_pr`, pre-existing); the gh check backstops it for `where` and the handoff. Record it for issue 393 or its own issue, not here — `.agent/project_types/ros2_colcon/adapter.sh:868` (deferred: not this pull request's (pre-existing adapter_scope_for_pr URL parser); recorded for issue 393 in this round's Implementation entry)

Belongs elsewhere: the merge gate reading A's timeline is pull request 2; `worktree_create.sh --workflow` scaffolding a timeline in the top folder (pre-existing) is issue 393's, as the plan says; writes from outside any worktree are the follow-up issue. Dropped: gemini's branch-match finding (the manifest's branch is the adapter's exact `feature/issue-N`, never the live branch).

Cross-model: gemini ran (complete, 2 findings: 1 kept as must-fix 3, 1 dropped); codex ran (complete, 1 finding, kept as must-fix 2). Claude adversarial ran (6 findings: 2 merged into must-fix 2 and 3, 3 suggestions, 1 to issue 393).

## Implementation
**Status**: complete
**When**: 2026-11-10 13:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-429 at `41588938`
**Addressed**: Local Review (Pre-Push) at `6d35497a` (2026-11-10 12:32 -05:00)
**Commits**: 5867e1b2, 3652efc7, 3f6e8da9, 96a32987, 019ccf7a, e740064a, eb23d01a, c207dd4f, 41588938

### Actions
- [x] (must-fix 1, as a class) One records gate: `records_path <path> [<from-dir>]` and `records_dir <N> [<dir>]` in `_resolve_work_plans_dir.sh`. The issue number comes from the path. A path inside a package worktree that is not in the issue's own checkout is refused, for reads and writes alike, and the refusal names that checkout. The manifest is looked for above the path's repository, then above the path itself, then above the calling directory. Every script path to a timeline now passes the gate: `resolve_work_plans_dir` (all rules, the override included), `progress_append.sh`, `review_progress.sh` `round` (with and without `--progress`), `persist` (both modes), `sources`, `findings`, `check` and `plan-sha` (with and without `--ref`), `dispatch_phase.sh` (`resolve_issue_dir`, so the handoff, `where`, `next` and `--check-exit`, plus `next --progress`), and `merge_pr.sh`'s gate lookup. `verdict` takes no path. A path that does not have the records shape, or that is outside every package worktree, passes unchanged. Test: case 8 of `test_package_issue_loop.sh` reads `review_progress.sh`'s dispatch table and fails on any subcommand that has no row. It runs 16 entry points from C (the top folder) and from B (the sibling), each with the path the skills build. Each must refuse with the right exit code, name A, print nothing on stdout and leave every repository and timeline unchanged. The same reads from A, and from the workspace main checkout for its own issue-7 timeline, still work. Removing the `findings` guard fails 2 checks. Docs: the design Records bullet, the run-issue Scope and the script reference now say what the gate guards and what it does not — `.agent/scripts/_resolve_work_plans_dir.sh:193`
- [x] (must-fix 2) Each of run-issue's three `where` blocks (steps 1, 4 and 6) now captures `D`, tests the exit code and checks that `D` is non-empty and a directory. Otherwise it prints `STOP` and exits 1, before any `cd` and before any path is built. `where` itself never prints an empty or missing directory with exit 0. `--check-exit` was checked: it derives the path through the gate, and a missing file counts 0, so the result is `MISSING`, never OK. Test: case 9 takes the three blocks from `SKILL.md` and runs them twice, once with a refused `where` (bare 7) and once with a failing gh. Each block stops and nothing changes. Step 1's block with an answer moves into A. For a package issue with no timeline yet, step 4's block prints `BEFORE=0` and `--check-exit` reports `MISSING`. Run against the old `SKILL.md`, 7 of these checks fail — `.claude/skills/run-issue/SKILL.md:219`
- [x] (must-fix 3) The line citations are re-derived from the final files, as the last code change. `dispatch_phase.sh` mechanism 1 is now 489, 533, 535, 597, 718. My edits also moved the citations of `merge_pr.sh`, `review_progress.sh` and `progress_append.sh` (inventory table, inventory sentence, Records bullet, mechanism 1), so those are refreshed too. The inventory row for `dispatch_phase.sh` was already stale on main; it now cites 167, 228-277, 452, 581, 669, 700 and says the `--type` check is in four modes. The change-log row says this and gives 885 lines — `docs/design.md:375`
- [x] (suggestion a) A paragraph after step 1 says once that every host chain after step 1 starts with `cd <dir> &&`, the rule `conventions=` gives phases, and that step 11 starts with `cd <root> &&` instead — `.claude/skills/run-issue/SKILL.md:236`
- [x] (suggestion b) The gh check now captures stdout alone and keeps stderr in a temporary file. stderr is quoted only in the refusal. A non-zero exit or an empty answer refuses. Tests: a gh that prints a notice on stderr and then answers still passes; a gh that exits 0 with no answer refuses — `.agent/scripts/dispatch_phase.sh:321`
- [x] (suggestion c) `round` and `findings` (and `sources`, `plan-sha`) go through the same gate as must-fix 1: same commit, same test — `.agent/scripts/review_progress.sh:126`
- [x] (suggestion d) Case 3 now counts every gh line logged during each dispatcher call, over the case's 4 calls, and requires zero. Setup's gh calls no longer count — `.agent/scripts/tests/test_package_issue_loop.sh:250`
- [x] (suggestion e) Deferred, not changed here. For issue 393: the owning `.worktree-repos` entry rests on `adapter_scope_for_pr`'s hand-written origin URL parser (`.agent/project_types/ros2_colcon/adapter.sh:868`, there before this change). The gh check in `where` and the handoff backstops it, but the records gate trusts the manifest as written — `.agent/project_types/ros2_colcon/adapter.sh:868` (deferred: recorded for issue 393)

### Also changed
- `test_merge_pr.sh`'s sandbox copies `_resolve_work_plans_dir.sh`, which `merge_pr.sh` now sources (`c207dd4f`).
- `test_script_tests_hook_scope.sh` declares what `test_package_issue_loop.sh` reads from the real tree (`.agent/scripts`, `.agent/project_types`, `.claude/skills`). Its new `rev-parse --show-toplevel` calls match the root-derivation scan (`41588938`).

### Checks
- `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP, on the final tree: rc 0. That includes the script-suite hook, which ran every suite because a shared helper changed, and shellcheck. An earlier full run failed in `test_merge_pr.sh` and `test_script_tests_hook_scope.sh`; both were fixed (above) and the run repeated.
- Run on their own: test_package_issue_loop 125/0, test_merge_pr 91/0, test_merge_pr_gate 106/0, test_script_tests_hook_scope 275/0. After the gate commit: test_resolve_work_plans_dir 21/0, test_progress_append 23/0, test_address_findings 15/0, test_review_code_convergence 35/0, test_dispatch_phase 140/0, test_triage_reviews_integration 59/0, test_issue_review_entry 6/0, test_checkpoint_269 43/0.

### Not done
- Paths that do not go through the gate:
  - `worktree_create.sh --workflow`'s scaffold of a timeline in a package worktree's top folder (line 880). It could pass the gate, but the gate would then make `--workflow` fail partway through creating a package worktree. That belongs to issue 393, as the plan says.
  - An agent opening `plan.md` or `progress.md` with its own Read tool (review-plan, review-code). This is not a script call.
  - `progress_read.py`, the parser. It takes any path from its callers, and those callers pass the gate. The exceptions are sitrep's survey loop, which reads every listed worktree's timeline for display and already skips a package worktree's top folder, and run-issue step 4's count, whose `PF` now comes from a checked `where`.
- A write from outside any worktree (from the session root, or from a package's hosted checkout) still commits on that checkout's own branch. The gate does not close it: no manifest encloses those directories, so it lets them through exactly as it does an ordinary workspace issue. Closing it would need a new rule for workspace issues, which is the separate issue the owner is being asked to allow. Not enabled.
- The merge gate reading the owning checkout's timeline is still pull request 2. `merge_pr.sh` now passes its lookup through the gate: for a package worktree the lookup is refused, and the existing "carries no issue timeline" reason stands.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-10 13:24 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a4978891eeca7425a, resume 1 of 3)

**Branch**: feature/issue-429 at `e8205e67`
**Base**: main
**Depth**: Deep (reason: whole-diff classification as in round 1, per the fix-round rule: records gate, merge_pr.sh, three skills, docs/design.md; cross-model dispatched as usual, since round 2 is no convergence check)
**Must-fix**: 2 | **Suggestions**: 4
**Round**: 2 | **Ship**: recommended — round 2: 2 mechanical must-fix (prev 3), not rising — fix and ship rather than another full round

Round 1's three must-fixes are closed, and so are its four acted-on suggestions; the fifth was deferred to issue 393. Re-tried against the new gate (`records_path`), from B (the sibling checkout) and C (the package worktree's top folder):
- refused: a `..` path from A into B's timeline (rc 4), and every round-1 vector;
- a symlink in B into A's records directory reads A's own timeline, and writes through it fail loudly (rc 3, nothing committed in either repository);
- `progress_append.sh` from the session root still commits on the workspace's `main`, as issue 437 expects.

Mutation copies all fail the suite:
- a new `review_progress.sh` subcommand with no table row fails 2 checks;
- removing the `check` gate fails 7;
- the old step-1 `cd "$(where)"` block fails 2.

The `where` blocks stop when `where` prints a path and exits non-zero (the assignment carries the substitution's status). The run-issue citations and the design citations re-checked against the files. Suites, 0 failed each:
- test_package_issue_loop 125, test_dispatch_phase 140, test_merge_pr_gate 106, test_merge_pr 91;
- test_script_tests_hook_scope 275, test_resolve_work_plans_dir 21, test_progress_append 23;
- test_review_code_convergence 35, test_triage_reviews_integration 59, test_issue_review_entry 6;
- test_address_findings 15, test_checkpoint_269 43, test_skill_paths 136.

The two changed suites only add a copied file and a declaration; nothing they assert was removed.

Issue 437: `records_path` is the single place every writer passes, so 437's rule lands there. The gate serves reads and writes alike, though, and case 8 asserts that the workspace main checkout reads its own issue-7 timeline. So 437 needs a write mode in the gate, not just a new refusal.

Outside reviewers:
- codex ran, 1 finding: must-fix 1, which I had reproduced independently;
- gemini ran, 1 suggestion: review-plan's fallback glob probes the top folder. It reads nothing wrong (it finds nothing there), and it is a hand-built path, so it goes to issue 393;
- the Claude adversarial specialist ran: must-fix 2 (shared with my own reproduction) and two suggestions, kept below.

### Findings
- [x] (must-fix) The gate reads the issue number only from the symlink-resolved path, and the regex needs a leading slash. Two ways through:
  - a sibling's `.agent/work-plans/issue-7` that is a symlink to a directory outside the records shape passes unchecked, and `check` then edited that target (reproduced; codex found the same);
  - where `realpath -m` is missing (BSD or macOS), a relative `.agent/work-plans/issue-7/...` path also skips the gate.

  Fix: match `(^|/)\.agent/work-plans/issue-N(/|$)` on the path as given, check the resolved location separately, and add a symlink test — `.agent/scripts/_resolve_work_plans_dir.sh:199`
- [x] (must-fix) `issue_checkout_guard` falls back to the caller's directory (`$PWD` by default) even for a path in an unrelated repository. With the current directory inside a package worktree, a workspace worktree's timeline is refused. Reproduced: `findings --progress <workspace worktree>/…/issue-12/progress.md` from A gives rc 4, while from its own worktree it gives rc 0. `merge_pr.sh:691` calls `records_path` with no from-directory, so an ordinary workspace merge run from such a directory gets "the records gate refused the timeline" and the enforcing gate refuses the merge. That is not "exactly as before". Fix: consult the from-directory only when the path has no repository or shares the from-directory's toplevel (C still refuses: its toplevel is the path's), pass `"$_gate_wt"` at `merge_pr.sh:691`, and add a test — `.agent/scripts/_resolve_work_plans_dir.sh:169`
- [x] (suggestion) sitrep's survey reads `$d/.agent/work-plans/issue-N/progress.md` directly. It is limited to the issue's repository checkouts, so I found no wrong read, but "every records read passes one gate" is not literally true. Name it in the design's "does not cover" list — `docs/design.md:457`
- [x] (suggestion) Issue 437 will need a write mode in `records_path`, since one function serves reads and writes and case 8 keeps the main checkout's read of its own timeline. Record this on issue 437 — `.agent/scripts/_resolve_work_plans_dir.sh:193` (deferred: for issue 437, recorded in this round's Implementation entry; nothing changed here)
- [x] (suggestion) The enumeration parses only `    name)  cmd_x` rows of `review_progress.sh`'s case table. A row written another way (`name) shift; cmd_x`) would slip past both checks; parse every label between `case "$SUB" in` and `esac` instead — `.agent/scripts/tests/test_package_issue_loop.sh:452`
- [x] (suggestion) review-plan's `--issue` fallback overwrites `WS_ROOT` and globs the top folder (gemini). It is harmless here, and the hand-built path belongs to issue 393 — `.claude/skills/review-plan/SKILL.md:105` (deferred: for issue 393 (hand-built path), recorded in this round's Implementation entry; nothing changed here)

## Implementation
**Status**: complete
**When**: 2026-11-10 13:46 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a95c639566387c1ba, resume 1 of 3)

**Branch**: feature/issue-429 at `2ff275cd`
**Addressed**: Local Review (Pre-Push) at `e8205e67` (2026-11-10 13:24 -05:00)
**Commits**: 04d775bb, 79250930, 20d1b493, 2ff275cd

### Actions
- [x] (must-fix 1) `records_path` matches `(^|/)\.agent/work-plans/issue-N(/|$)` twice: on the path as given, and on its physical location. The given match is judged at the directory that holds the named `.agent`, so a symlinked records folder is judged where the link sits; the physical match is judged where it resolves. Two different numbers, or a path that cannot be resolved, refuse. Resolution is `_wpd_physical`, which uses only `cd -P`, `pwd -P` and plain `readlink` (no `realpath -m`). Tests, case 10 of `test_package_issue_loop.sh`: B's records folder as a symlink out of the records shape is refused for `findings`, `check` (from B and from A) and `progress_append.sh`, and the target and B are unchanged. Relative paths from B are refused with GNU realpath and with a stub `realpath` that rejects every call; the same relative read from A still works. 7 of these checks fail on the previous gate — `.agent/scripts/_resolve_work_plans_dir.sh:255`
- [x] (must-fix 2) `issue_checkout_guard` now uses the from-folder's manifest only when the path is in no repository or the from-folder has the same git toplevel, so the top folder (toplevel = the workspace main checkout) still refuses. `merge_pr.sh` passes `"$_gate_wt"` to `records_path`. Tests: case 10 runs a workspace worktree's timeline from inside A. `findings`, `round` and `sources` give exactly what they give from that worktree, and `check`, `progress_append.sh -C`, the resolver override and `next --progress` all work. `test_merge_pr_gate.sh` (def-pkg): an all-good workspace merge started inside a package checkout merges. 6 checks in case 10 and def-pkg fail on the previous gate — `.agent/scripts/_resolve_work_plans_dir.sh:179`
- [x] (suggestion a) The design's "does not cover" list names the sit-rep's survey, which reads each listed checkout's `progress.md` with `progress_read.py` directly. The change-log row's line count is now 886 — `docs/design.md:457`
- [x] (suggestion b) Deferred, nothing changed. For issue 437: `records_path` serves reads and writes alike, and case 8 asserts that the workspace main checkout reads its own issue-7 timeline. So 437's "no records write outside a worktree" rule needs a write mode in the gate, not a refusal for every caller — `.agent/scripts/_resolve_work_plans_dir.sh:193` (deferred: for issue 437)
- [x] (suggestion c) The enumeration now takes every label between `case "$SUB" in` and `esac`, fails on a line it cannot read, and requires the labels to equal the subcommands the usage text names. A `newsub) shift; cmd_findings` row fails 3 checks (the old parse missed it) — `.agent/scripts/tests/test_package_issue_loop.sh:452`
- [x] (suggestion d) Deferred, nothing changed. For issue 393: review-plan's `--issue` fallback overwrites `WS_ROOT` and globs a package worktree's top folder, a hand-built records path that finds nothing there today — `.claude/skills/review-plan/SKILL.md:105` (deferred: for issue 393)

### Checks
- `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP, on the final tree: rc 0. That includes the script-suite hook (every suite, since a shared helper changed) and shellcheck.
- Run on their own: test_package_issue_loop 148/0, test_merge_pr_gate 107/0, test_merge_pr 91/0, test_resolve_work_plans_dir 21/0, test_progress_append 23/0, test_address_findings 15/0, test_review_code_convergence 35/0, test_dispatch_phase 140/0, test_triage_reviews_integration 59/0, test_checkpoint_269 43/0, test_cross_model_review 920/0.
- The design citations of `merge_pr.sh`, `dispatch_phase.sh`, `review_progress.sh` and `progress_append.sh` were re-checked against the files after the merge from main; all still hold.

### Not done
- `review_progress.sh persist --strict` still calls `realpath -m` to compare the resolved directory (there before this branch). Where it is missing, the comparison fails and persist refuses (exit 4), so it fails closed. Left as is.

## Implementation
**Status**: complete
**When**: 2026-11-10 14:00 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a95c639566387c1ba, resume 2 of 3)

**Branch**: feature/issue-429 at `ff82c5a1`
**Addressed**: Local Review (Pre-Push) at `e8205e67` (2026-11-10 13:24 -05:00)
**Commits**: 1aa504f7, ff82c5a1

Merge from main landed as `1aa504f7` (`git merge main`, no rebase). It brings in pull request 417 at `93c5e99c`. Two files conflicted:
- `.agent/scripts/tests/test_dispatch_phase.sh`: six sandbox copy lists conflicted. Each one keeps both sides' helpers: main's `_resolve_default_branch.sh` and this branch's `_resolve_work_plans_dir.sh`. No cases or helper names collided.
- `docs/design.md`: the conflicts were three hunks, and this branch's text wins in all three: the inventory rows for `merge_pr.sh` and `dispatch_phase.sh`, the Records bullet, and mechanism 1. Main's `worktree_create.sh` row and main's `gh_create_pr.sh` citation (125-152) are kept; this branch does not change either script. The `merge_pr.sh` citations are re-derived from the merged file, since both sides moved its lines:
  - the inventory row is now 243-287, 394-433, 577, 694, 721 and 858, 966 and 979, 1732-1748;
  - the Records bullet cites 839, 893, 287, 577, 694, 721, 858, 966 and 979;
  - mechanism 1 cites 689-710 and 822-903.
  The `dispatch_phase.sh`, `review_progress.sh` and `progress_append.sh` citations were re-checked and are unchanged. Main's three #323 change-log rows auto-merged, so all rows are dated 2026-11-10. This branch's row now gives 896 lines.

Auto-merged files checked together. `merge_pr.sh` carries main's review hold and this branch's records-gate lookup (`records_path "$_gate_cand" "$_gate_wt"`, lines 701-708). `test_merge_pr.sh` still copies the resolver.

The merge broke one fixture, fixed in `ff82c5a1`. Main's `worktree_create.sh` now asks origin whether `feature/issue-N` exists before starting the branch, and refuses when origin cannot answer (issue 323). In `test_package_issue_loop.sh`, the single-repository project fixture had an origin URL with nothing behind it. So its worktree was not created, and 6 checks failed. The fixture now gets a bare remote served like pkg_a and pkg_b. After the fix the suite is 148 passed, 0 failed. No script was changed.

Checks:
- `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP, on the final tree: rc 0, including the script-suite hook (every suite) and shellcheck.
- Run on their own after the merge: test_dispatch_phase 140/0, test_package_issue_loop 148/0, test_merge_pr 91/0, test_merge_pr_gate 121/0.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-10 14:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-429 at `a6c2d2f2`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff; whole-diff tier as rounds 1 and 2)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings

Narrow check of round 2's two must-fixes, the fix diff since `e8205e67`, and the merge from main (`1aa504f7`). Cross-model: skipped (round-3 convergence check, per handoff). Static analysis: shellcheck --severity=warning clean on `_resolve_work_plans_dir.sh`, `merge_pr.sh` and the three changed suites.

Round 2 must-fix 1 (path as given and as resolved, no `realpath -m`) holds. Probes in a sandbox built from the suite's own setup, beyond case 10:
- A's records folder as a symlink to B's: `findings`, `check` and `progress_append.sh` from A are refused (rc 4).
- B's `.agent` as a symlink to A's `.agent`: the relative read from B, the absolute read from A and `progress_append.sh` from B are all refused.
- `..` paths into B are refused: from C, from A via `../pkg_b`, and from A via `.agent/work-plans/issue-7/../../../../pkg_b/...`.
- A symlink outside the records shape that points to B's timeline is refused from the session root. One that points to A's timeline reads A from B, which is A's own timeline.
- A's own relative read, `check` and append work from A.

Round 2 must-fix 2 (the current folder counts only for its own repository) holds. A workspace issue-7 timeline gives identical `findings` and `round` output from A and from its own worktree. `progress_append.sh -C <ws worktree>` from B commits there, and `where` works from A. A path into the workspace main checkout is read from A but refused from C, because C shares that checkout's toplevel, as intended. `merge_pr.sh` passes `"$_gate_wt"`. Its def-pkg case merges from inside a package checkout.

The enumeration test fails in three scratch mutations:
- a new gated-nowhere subcommand in the table and usage fails 2 checks;
- an odd-form row (`peek) shift; ...`) left out of usage fails 3;
- a new ungated subcommand given an entry-point row fails 3 (refusal from B and C).

Merge from main: `git diff main HEAD` touches only this branch's 17 files. The remerge diff keeps both helper lists in all six `test_dispatch_phase.sh` copy loops. `docs/design.md` keeps main's `gh_create_pr.sh` and `worktree_create.sh` rows. The `merge_pr.sh` citations (287, 577, 694, 721, 839, 858, 893, 966, 979) match the file. `merge_pr.sh` differs from main only by the gate lookup and its refusal reason, so the review hold is intact. `_wt_add_repo` and the manifest format (`feature/issue-N` on the owning entry) still give what `issue_checkout_of` and the suite assume.

Suites, 0 failed each: test_package_issue_loop 148, test_dispatch_phase 140, test_merge_pr_gate 121, test_merge_pr 91, test_worktree_create 58, test_ros2_colcon 218.

Follow-up only, nothing new: issue 437 (writes from outside any worktree; the gate needs a write mode), issue 393 (non-default records settings, `--workflow` scaffold, review-plan fallback). The `realpath -m` left in `persist --strict` is not part of this pull request and fails closed.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-10 14:06 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 approved, Ship recommended, no must-fix and no suggestions)
**After**: publish
**Decision**: publish

Host read the round-3 review (approved; both round-2 must-fixes hold against 8 further vectors; the merge from main lost nothing). This is pull request 1 of 2 for the issue, so the pull request says "Part of", not "Closes". Five of the host's earlier checkpoint times on this timeline were corrected to their commit times in a bookkeeping commit before publishing.

## Integrated Review
**Status**: complete
**When**: 2026-11-10 14:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #445 at `2340e012`
**Sources**: 2 (Local Review (Pre-Push) round 3 @ `a6c2d2f2` (covers `2340e012` via bookkeeping), CI rollup); Copilot posted only its quota notice, no review
**Cross-source confirmations**: 0
**CI**: pending

No human review and no conversation comments on the pull request; no inline comments. Copilot's one review at the head is the notice that it could not review for lack of quota, and its `copilot-pull-request-reviewer` check run "failure" is that notice, not a CI result. CI at the time of writing: Validate Adapter Contract, Validate Documentation and the ros-manifest tests pass on both runs; Lint (pre-commit) is still running on both.

The local timeline: round 1 (3 must-fix, 5 suggestions) and round 2 (2 must-fix, 4 suggestions) are all ticked, each fixed or deferred with a named home in the following Implementation entries; `sources` lists no dropped or unverifiable entries. Round 3 at `a6c2d2f2` approved with no must-fix and no suggestions; its unticked "No issues found. LGTM." line is the clean-review placeholder (issue 362), not a finding. Spot check: `merge_pr.sh:704` passes `"$_gate_wt"` to `records_path`, as round 2 must-fix 2 required.

Commits after the reviewed head (`e29142b1` review entry, `82164749` time correction, `2340e012` checkpoint) touch only `.agent/work-plans/issue-429/progress.md` (`git diff --stat a6c2d2f2 HEAD`). The correction changes only the `**When**` lines of five host checkpoints and adds a `**When-corrected**` line to each; the corrected times (09:55, 10:02, 10:08, 11:19, 11:44) match the commit times of the five checkpoint commits. The timeline still parses: `progress_read.py` rc 0, and `review_progress.sh sources` rc 0.

Belongs elsewhere, not open here: writes from outside any worktree (issue 437, which needs a write mode in `records_path`); the non-default records settings, the `--workflow` scaffold and review-plan's fallback glob (issue 393); the adapter's hand-written origin URL parser (noted for issue 393); the merge gate reading the owning checkout's timeline and the base branch from the manifest pin (pull request 2 of issue 429).

### Findings
None open.

### False positives
- (Copilot) check run `copilot-pull-request-reviewer` reported failure — it is the quota notice ("insufficient remaining quota"), not a review or a CI job; nothing in the code was examined

## Checkpoint
**Status**: complete
**When**: 2026-11-10 14:39 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

The merge dialog for pull request 445 (part 1 of 2) showed what the change does, what is left for part 2, what only a real run can test, the review record and CI (all 8 checks pass). The owner first asked two things: "the goal is to make this work with project11, but we are implementing it so it works with other similar projects right? Nothing here is specific to project11? Also, I have been trying to ween off of depending on github, but I see a lot of github related parts here. Are we just solidifying our dependence on github?" The host answered from the diff: the scripts and skill text name no project, and one test fixture uses "p11" as its made-up project's name in two lines; the guard is plain git; the change adds one `gh repo view` check before work starts on a package issue, which stops when `gh` cannot answer, and identifies an issue as `owner/repo#N`; the loop as a whole is already bound to GitHub and no recorded goal says to depend on it less. Asked "Merge pull request 445 as it is, with the p11 fixture name renamed in part 2?", the owner answered: "Q1 yes". On recording "depend less on GitHub" as a goal: "Q2, we need to discuss this".

Carried to part 2: rename the fixture's made-up project so no test names a project.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 14:46 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-429/plan.md` at `156efb94`

Revision for part 2 after part 1 merged (pull request 445). Part 2 is cut as 2a (base branch: a base given by hand until repo_pin from issue 436 exists, the base also decides the branch start point and is recorded in the manifest header, forwarded to publish) and 2b (the gate reads and records in the owning checkout with pull request identity as repository plus number, report-only kept, cleanup pinned by tests, the end-to-end test, texts, fixture rename). Eleven decisions listed for the owner's veto; issue 437 merges before 2b.

## Plan Review
**Status**: complete
**When**: 2026-11-10 14:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #429 — run-issue: drive an issue in a package repository of a multi-repository project
**Plan**: `.agent/work-plans/issue-429/plan.md` at `156efb94`
**Branch**: `feature/issue-429`
**Serves**: Workspace goal `README.md#easy-to-use`; touches `README.md#light-touch-on-projects`; design `docs/design.md#worktrees` (Records), `docs/design.md#review-loop-and-timeline`, `docs/design.md#merge-gate`. Checked: the sections exist. Part 2 also falls under `README.md#flexibility`, which the line does not cite (finding 3).

Scope of this review: "Part 2 (detailed)" only; part 1's text is the record of merged work. Read against the merged code at `3486edba`: `worktree_create.sh`, `_worktree_helpers.sh` (`_wt_add_repo`, `wt_add_new_branch`, `wt_lookup_for_new_branch`, `wt_read_manifest`), `merge_pr.sh` (package scan, gate, `_gate_record`, `_gate_already_recorded`, Step 4), `progress_read.py`, `review_progress.sh`, `dispatch_phase.sh`, the `adapter` dispatcher, the `ros2_colcon` adapter; issue 436's plan (worktree `issue-workspace-436`) and issue 437's branch diff (worktree `issue-workspace-437`).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | 2a (about 8 files) and 2b (about 11 files) are each one reviewable change. 2b is lighter without step 7 (finding 2) |
| Issue alignment | Good | Closes the rest of the issue: base, gate on the owning timeline, end-to-end test, texts. Serves line copied above |
| File targeting | Needs work | 2a's texts are listed under 2b (finding 6); `wt_read_manifest`'s header parser needs a change the plan does not list (finding 5) |
| Consequences | Needs work | Base text, script rows and ADR-0012 header text trail 2a into 2b; `script_reference.md` is also shared with issue 437 (textual) |
| Principle alignment | Needs work | Table below. The plan's own self-check uses names that are not headings ("Enforcement over documentation", "Only what's needed / small steps") and lists five of sixteen |
| Flexibility goal (`README.md#flexibility`) | Needs work | Row below |
| ADR compliance | Good with one note | 0011: the pin read only through `adapter repo_pin`; 0012: header field additive once the layer parser is fixed; 0013: amendment is additive and every reader keeps working on bare `#M` (checked), but see finding 2; 0017: see finding 6 |
| ROS conventions | N/A | Workspace scripts; no ROS interfaces |

#### Principle alignment (every heading of `docs/principles.md`)

| Principle | Applies? | Assessment |
|---|---|---|
| Leave a trail; start limits strict | Applies | Good: package gate records move onto the owning timeline; a run with no base refuses rather than guesses |
| Enforce what matters, as simply as possible | Applies | Partly: the start point is the real enforcement and the merge cross-check reports a wrong target; but the stated mechanism does not enforce origin's base (finding 1), and step 7 guards a case no flow produces (finding 2) |
| Keep one current design | Applies | Needs work: 2a changes the worktree picture (branch start, `base=` header) but its design and ADR-0012 text are in 2b (finding 6) |
| A change includes its consequences | Applies | Needs work: same as above, plus `script_reference.md` rows for `base`, `_pr_base.sh`, `--base` |
| Only what's needed | Applies | Needs work: step 7 and the verb-absent stopgap both build things no current flow needs (findings 2, 4) |
| Small steps; step back when they stop converging | Applies | Good: two pull requests; can run in parallel with one move (finding 7) |
| Test what breaks | Applies | Needs work: missing cases for a local `<base>` with an unpushed commit, `--allow-unverified-branch` with an unknown base, and the layer field after `base=` (findings 1, 5) |
| Put each thing at the level it applies to | Applies | Good: `_pr_base.sh` names no type; the pin comes from the adapter. One gap: how the repository name is found before the worktree exists (finding 8) |
| Use the main tool fully; keep the work tool-neutral | Applies | Needs work: its rule "for each part that depends on one tool, say how the work continues without it" is the one principle serving Flexibility; the GitHub-bound rows give no way to continue (finding 3) |
| Ask about what matters, and show how much | Applies | Partly: the veto list says what each changes and its undo cost; veto 5 contradicts the table (finding 4); the GitHub question is left "for the owner's discussion" although the goal is recorded (finding 3) |
| Verify before claiming | Applies | Needs work: "older readers ignore it" is false for `layer=` (finding 5); "the rule is not in the tree" is false (finding 9) |
| Look for prior art before building | Applies | Partly: reusing the parent-branch path is right, but its semantics (local branch first, default fallback) were not carried over correctly (finding 1) |
| Leave in a project only what it chose to carry | Applies | Good: gate records join the timeline in the package repository that decision 1 (part 1, owner's veto) already put there; `base=` lives in the workspace manifest |
| Name the rule before bending it | Applies | Good: the tests-name-no-project rule is named and the partial rename is put to veto 8 |
| Give the user what they need now | Applies | Good: decisions are in plain words with undo cost; the Flexibility table is a usable start for the owner's question |
| Know whether it works | Applies | Good: step 8's base cross-check at merge is the check that the base mechanism worked |

#### Flexibility goal row

`README.md#flexibility`: "preference should go to open source and open standards to minimize vendor lock-in. Have an exit strategy for anything that depends on a vendor's closed product or infrastructure." The plan says "no goal is recorded"; this one is.

- **No new `gh` call: verified.** Step 8 adds `baseRefName` to the existing `_head_json` `gh pr view` (merge_pr.sh:545); publish adds `--base` to the existing `gh pr create` through `gh_create_pr.sh` pass-through; `_pr_base.sh` and `dispatch_phase.sh base` use git and the adapter; cleanup's `gh pr list` is unchanged.
- **Records move off the pull request: verified for the owning pull request only.** `_gate_record` (merge_pr.sh:848) skips the timeline whenever `PKG_WT_DIR` is set and falls back to `gh pr comment`; step 6 lifts that for the owning checkout. Sibling pull requests' records, and the push-refused and no-identity fallbacks, still go to `gh pr comment`, and `_gate_already_recorded` still reads the comment store for them. The table's "Gate record location" row should say so.
- **Table incomplete:** missing rows: the sibling record path (`gh pr comment`, stays), the comment-store duplicate check (stays), and the owning-checkout match in step 6 (a new use of `extract_gh_slug`, which parses GitHub remotes only; the manifest scan at merge_pr.sh:488-499 already matched that entry by branch and slug, so reusing the match needs no second parse).
- **Deepened:** step 7 writes the GitHub-derived `owner/repo` into ADR-0013's record vocabulary (finding 2).
- **No exit stated** for any "No"/"Stays" row. After part 2 the gate's decision for a package pull request is already a git record; the exit can be one line per row (publish = push the branch; merge = `git merge` into the base and push, with the gate read from the timeline; reviews from local reviewers), or an issue that owns it.

### Findings

1. **[Approach — must-fix] The stated start-point mechanism does not give origin's base.** Step 3 passes the base as `_wt_add_repo`'s parent and promises "starts at `origin/<base>`; a missing or unreachable base is an error, never a silent fall back". The merged parent path (`_worktree_helpers.sh:787-806`) does three other things: (a) a local `refs/heads/<base>` is used as is, with no fetch, so in a vcs-imported checkout that sits on the pinned branch, any local or stale commits there go into the new branch and the pull request; (b) a base absent on origin prints a WARNING and starts from the default branch (`_wt_default_start_point`), the wrong branch; (c) with `--allow-unverified-branch`, an unknown base is treated as absent and also starts from the default. The parent add also omits `--no-track`, so the new branch tracks `origin/<base>`. Resolution: a separate base path, owning entry only: fetch `refs/heads/<base>` with `wt_fetch_named_branch`; present → `wt_add_new_branch ... origin/<base> --no-track`; absent or unknown → error, whatever `--allow-unverified-branch` says, with the rollback the manifest loop already does. Never the local `<base>`. Tests: a local `<base>` carrying an unpushed commit (the new branch must not contain it); `--allow-unverified-branch` with an unreachable origin (must refuse). `pr_base_for`'s offline "unverified" acceptance and the creation's "unknown → stop" then disagree: say which wins in the message.
2. **[Flexibility / Only what's needed — must-fix] Step 7 adds a GitHub-derived identity to the record format for a case no flow produces, with no exit.** On today's flows (and after part 2) only the owning pull request's records land in A's timeline: siblings go to comments (step 6), sibling repositories are not committed to (part 1's Scope), and review entries in A are written bare `#M`. Step 7 says so itself ("only guards the case where two repositories' entries meet"). It still amends ADR-0013 and writes `owner/repo` from `extract_gh_slug`, a GitHub-only parser, into every package merge record. Resolution: drop step 7 (and the ADR-0013 amendment and its tests); bare `#M` already means "the timeline's own repository". If kept, key on a forge-neutral name (the manifest entry's directory name) and state the exit. For the record: adding `repo` is additive and every reader keeps working on bare `#M` (checked: `review_progress.sh` round/sources/findings use `kind`/`sha`/`branch`; `dispatch_phase.sh` check-exit and `next` use `sha`/`branch`; the gate uses `sha` and `.pr`; `sitrep` does not read correlations; `progress_read.py`'s `re.search` already matches `owner/repo#M at`).
3. **[Flexibility] The goal is recorded, and the plan should be judged against it, not leave it to discussion.** Cite `README.md#flexibility` in Serves and in the self-check through "Use the main tool fully; keep the work tool-neutral"; complete the table (rows above) and give one exit line per GitHub-bound row.
4. **[Approach] Drop the verb-absent stopgap; order issue 436's pull request (c) first.** Issue 436's plan lists (c), `repo_pin` as a required verb, as depending on nothing for the verb itself and runnable in parallel with (b). The acceptance case on a fresh machine needs 436's manifest route anyway, so (c) will be in by then; the stopgap serves only a window with no real package runs, and costs a verb-detection branch, a refusal message and stub-adapter tests that are deleted later. An "optional verb" would be a new concept in ADR-0011 (every type implements every verb), so not smaller. Make 2a's `base` call `adapter repo_pin` and merge after (c); keep `--base` as an override only. As written, the table refuses every package run without `--base`, while veto 5 says the owner types it only "for a project whose pin differs from the default": one of them is wrong.
5. **[Verify before claiming] `base=` after `layer=` empties `WT_MANIFEST_LAYER`.** `wt_read_manifest` (`_worktree_helpers.sh:444`) reads `layer` with an end-anchored `sed 's/.* layer=\([^ ]*\)$/\1/p'`; on `# project=demo issue=owner/pkg_a#7 layer=l1 base=pinned` it prints nothing (run here). Nothing reads `WT_MANIFEST_LAYER` today, so it is latent, but the claim "readers use sed on named fields, so older readers ignore it" is false for this one. Remove the anchor in 2a and add the case to `test_worktree_create.sh`. The other header readers (`issue=`, `project=`) are not anchored.
6. **[Keep one current design / Consequences] 2a's texts belong in 2a.** 2a introduces the base start point, the `base=` header, `dispatch_phase.sh base`, `_pr_base.sh` and `worktree_create.sh --base`, but the `docs/design.md#worktrees` sentence, ADR-0012's manifest paragraph and the three `script_reference.md` rows are in step 13 (2b). Since "each is merged on its own", main would carry 2a with a stale design. Move them into 2a.
7. **[Small steps] 2a and 2b can be developed in parallel.** Only step 8 (base cross-check) and the end-to-end test's `--base` step need 2a. Move step 8 into 2a (it is about the base, and is silent without `base=`); then 2b needs nothing from 2a, and the end-to-end test's base step is added by whichever of the two merges second.
8. **[Put each thing at the level it applies to] Say how `base` names the repository before the worktree exists.** `repo_pin <name>` takes the directory name, which can differ from the GitHub repository name in `owner/repo#N`. Take it from the owning entry of `adapter worktree_repos --issue <ref> --layer --package-repos` (the entry on `feature/issue-N`, basename of its path), not from the issue reference.
9. **[Verify before claiming] "A run removes only what it made" is in the merged tree.** `worktree_create.sh:70-75` (`undo_new_branch_checkout`: "Only what this run made is undone") and `_worktree_helpers.sh` (`wt_add_new_branch`: "a failure undoes only what this run made"; `_wt_add_repo`'s `made_branch`). It concerns undoing a failed creation, not merge-time cleanup. Step 10 changes no code, so nothing rests on the misreading, but it should not cite that rule for cleanup. The cleanup sweep (merge_pr.sh:1664-1690) safe-deletes every manifest entry's local branch whose remote is gone, whichever run made it. Close the open question. Add one pinned case: the owning repository's own checkout on a branch other than the base, where `git branch -d` keeps the merged branch as "not fully merged".
10. **[Consequences] Issue 437 overlap: claims verified, one file missing.** 437's branch does not touch `merge_pr.sh`; its `progress_append.sh` write rule (`records_dir --write`) accepts A on `feature/issue-N`, so `_gate_record`'s `-C A` passes; `test_package_issue_loop.sh` is shared (437 changes one assertion block). `.agent/knowledge/script_reference.md` is also shared (437 step 8 adds rows), and 2a edits `test_package_issue_loop.sh` too, so 2a is not free of 437 either: textual only.
11. **[Name the rule] Fixture rename: leaving the six other suites to a follow-up is right**, since that rename is unrelated to part 2's behaviour (168 lines counted: `test_ros2_colcon.sh` 71, `test_project_registry.sh` 47, `test_merge_pr.sh` 40, `test_session_root.sh` 6, `test_skill_prefix.sh` 3, `test_session_start_layer.sh` 1; comments at `skill_prefix.sh:14`, `user_tier_install.sh:1208`). The follow-up is mechanical and depends on nothing: file it now so it can run beside 2a and 2b. `run-issue/SKILL.md:83` (`p11-jazzy`) is in the files part 2 touches and is covered by step 11.

### Summary

The two-pull-request cut and the gate-on-the-owning-timeline approach are sound, and the claim of no new `gh` call holds. Two things must change before implementation: the start point must come from origin's base by its own strict path (as written, the parent path can start a package branch from a stale local base or from the default branch), and step 7 should be dropped (it adds a GitHub-derived identity to the record format for a case no flow produces). Beyond those: the Flexibility table needs completing with exits, the stopgap can be replaced by ordering issue 436's (c) first, and 2a's texts move into 2a.

### Recommended Actions

- [ ] (must-fix) Step 3: a strict base path for the owning entry (fetch origin's base, `--no-track`, absent or unknown is an error even with `--allow-unverified-branch`, never the local `<base>`), with the two tests in finding 1
- [ ] (must-fix) Drop step 7 and the ADR-0013 amendment, or key on a forge-neutral name and state the exit
- [ ] (suggestion) Cite `README.md#flexibility`; complete the GitHub-bound table (sibling comment records, comment-store duplicate check, step 6's slug match) with one exit line per row
- [ ] (suggestion) Replace the verb-absent stopgap by merging 2a after issue 436 (c); `--base` as override only; fix veto 5's contradiction
- [ ] (suggestion) Un-anchor the `layer=` parser in `wt_read_manifest` and test it
- [ ] (suggestion) Move the base texts (design, ADR-0012, script rows) and step 8 into 2a
- [ ] (suggestion) Name the repository for `repo_pin` from `adapter worktree_repos`' owning entry
- [ ] (suggestion) Step 6: reuse the manifest scan's matched entry instead of a second `extract_gh_slug` parse
- [ ] (suggestion) Step 10: cite the creation rule correctly, close the open question, add the "own checkout not on the base" case
- [ ] (suggestion) File the fixture-rename follow-up now
- [ ] (suggestion) Rebuild the Principles Self-Check from the sixteen headings of `docs/principles.md`

## Checkpoint
**Status**: complete
**When**: 2026-11-10 14:53 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review of part 2 found two must-fixes and a better order, all mechanism; first host revise on the part 2 plan)
**After**: plan
**Decision**: revise

Correction to this timeline's merge checkpoint of 2026-11-10: the host wrote there that no recorded goal says to depend less on GitHub. That was wrong. The README's Workspace goals, Flexibility, say: "When practical, preference should go to open source and open standards to minimize vendor lock-in. Have an exit strategy for anything that depends on a vendor's closed product or infrastructure." The plan repeated the host's error and must be corrected too.

Host read the Plan Review (needs-work, 2 must-fix, suggestions) and directs:
- Must-fix 1: the branch's start point gets its own strict path: fetch origin's base, start the new branch from it with no tracking, refuse when the base is absent or unknown on origin, never use a local copy of the base branch; test both refusals and that unpushed local commits on the base do not enter.
- Must-fix 2: drop the qualified pull-request identity in records (plan step 7). No flow writes two repositories' pull requests onto one timeline, and a bare `#M` keeps every reader working.
- The base comes from the adapter now, not by hand: pull request 2a itself adds the `repo_pin` verb as a required verb every project type implements (the ROS type answers from the `.repos` file it already reads; a single-repository type answers with its default branch), with ADR-0011's verb list updated, and uses it. Issue 436's own pull request for that verb is then dropped there; the host records that on issue 436's timeline. `--base` stays only as an override, and a pinned tag, commit or unknown kind refuses and names it.
- The Flexibility goal: complete the table of what stays GitHub-bound (the sibling-record comment, the push-failure fallback, the second slug parse, which reuses the manifest scan's match instead), and for every row state the exit: how the work would continue without GitHub. Where no exit exists today, say so plainly; those rows go to the owner's discussion.
- Take every suggestion: un-anchor the manifest header's `layer=` parser before adding `base=`, with a test; move the base texts into 2a so 2a and 2b can be built in parallel; name the repository for `repo_pin` from the adapter's own entry; close the cleanup question (the rule the planner could not find covers undoing a failed creation, not merge cleanup) and add the test for a package checkout not on the base branch; list `script_reference.md` among the files shared with issue 437; rebuild the self-check from the sixteen headings of docs/principles.md. The rename of the made-up project name in the other six suites is drafted as a follow-up issue for the owner to allow.

## Plan Authored
**Status**: complete
**When**: 2026-11-10 14:57 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-429/plan.md` at `5609626c`

Revision of part 2 after the plan review and the host's revise checkpoint. The start point gets its own strict path (fetch origin's base, no tracking, refuse when absent or unknown even with the unverified-branch flag, never the local copy). Pull request 2a adds repo_pin as a required verb (ADR-0011 amended) and carries all base texts; 2b is the gate on the owning timeline, cleanup tests, end-to-end test and Scope text; the two are built in parallel. The qualified pull-request identity is dropped. The Flexibility goal is cited, and the GitHub-bound table is completed with an exit column. The self-check uses the sixteen principle headings; the fixture-rename follow-up issue is drafted, not opened.

## Plan Review
**Status**: complete
**When**: 2026-11-10 14:59 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready
**Dispatch**: resumed (agent a3124c0f507720522, resume 1 of 3)

**Issue**: #429 — run-issue: drive an issue in a package repository of a multi-repository project
**Plan**: `.agent/work-plans/issue-429/plan.md` at `5609626c`
**Branch**: `feature/issue-429`
**Serves**: `README.md#easy-to-use`, `README.md#light-touch-on-projects`, `README.md#flexibility`; design `docs/design.md#worktrees`, `docs/design.md#review-loop-and-timeline`, `docs/design.md#merge-gate`. Checked: Flexibility is now cited with the README's words, and the withdrawn "no goal recorded" statement is corrected on the timeline and in the plan.

Second review, narrow: whether the first review's findings (entry of 2026-11-10 14:53, plan `156efb94`) are resolved as worded, and whether the revision introduced anything wrong. Checked against `3486edba` code: `adapter`, `validate_adapter.sh`, both adapters, `_worktree_helpers.sh`, `merge_pr.sh`, `.github/workflows/validate.yml`, `.pre-commit-config.yaml`, the adapter test suites, ADR-0008, ADR-0011, ADR-0012, `principles_review_guide.md`.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | 2a at about 16 files carries a contract change (a 13th required verb) alongside the base mechanism; cut the verb out as its own pull request first (finding 1) |
| Issue alignment | Good | Unchanged from the first review; all of part 2 is covered |
| File targeting | Needs work | Verb-count text and assertions not listed (finding 3) |
| Consequences | Needs work | Same as above, plus the ADR route (finding 2) |
| Principle alignment | Good | Self-check now has all sixteen headings of `docs/principles.md`, each with a consideration; I agree with each, except that "Keep one current design" depends on finding 3 |
| Flexibility goal (`README.md#flexibility`) | Good | Table complete; no new `gh` call; no exit claimed is false; two wordings to fix (finding 5) |
| ADR compliance | Needs work | ADR-0011 edit route conflicts with ADR-0008 (finding 2); ADR-0013 now untouched (good) |
| ROS conventions | N/A | Workspace scripts |

### First review's findings, as resolved

- Must-fix 1 (strict start path): **resolved as worded.** 2a step 4: fetch origin's base, `origin/<base> --no-track`, refuse on absent or unknown whatever `--allow-unverified-branch` says, never the local `<base>`, owning entry only, rollback by the manifest loop; a resumed branch is checked out as today; "creation wins" over an offline `pr_base_for`. Tests (i) to (vi) include both refusals, the unpushed local commit and "no upstream". The chain fits the merged code: the branch's own lookup in `_wt_add_repo` stops first on "unknown" without the flag, and with the flag the base lookup then refuses.
- Must-fix 2 (qualified identity): **resolved**: step 7 dropped, ADR-0013 unchanged, decision 7 records it.
- Flexibility: **resolved**: goal cited; rows added for the sibling comment, the push-refused and no-identity fallbacks, the comment-store duplicate check; the second slug parse is replaced by reusing the scan's `_m_rel` (2b step 1); every row has an exit or "none today" with what one would take.
- `--base` by hand: **resolved**: `repo_pin` built in 2a, `--base` only an override; veto 5's contradiction is gone.
- Suggestions: **all taken**: `layer=` un-anchored with a test (step 5); base texts and the cross-check moved into 2a, so 2b needs nothing from 2a; repository name from `adapter worktree_repos`' owning entry; cleanup rule found and cited correctly, case (d) added; `script_reference.md` listed as shared with 437; follow-up issue drafted, not opened.

### Findings

1. **[Scope] Cut the verb out of 2a as its own pull request first.** Steps 1-2 are a change to the adapter contract (ADR-0011, `REQUIRED_VERBS`, both adapters, `validate_adapter.sh`, the verb tests, the design's verb text, plus the new ADR of finding 2): reviewed by different criteria from the base mechanism, depending on nothing, and touching the files a CI job (`validate-adapter-contract`) guards. With it inside, 2a is about 16 files and two subjects. The rest of 2a (strict start, header, `_pr_base.sh`, dispatcher, cross-check, run-issue) can be built in parallel against the sandbox's stub adapter type and merge after the verb. So: **two pull requests, the verb first.**
2. **[ADR compliance] Do not edit ADR-0011's verb table; record the verb in a new ADR.** The plan says "ADR-0011 amended in 2a (Status paragraph: now 13 verbs, as ADR-0012 amended it to 12; the verb table gains the row)". The precedent is the other way round: ADR-0012 is a new ADR that decided its two verbs; ADR-0011 got only a Status-line cross-reference ("Amended by ADR-0012: +2 verbs") and its verb table still has the original 10 rows (`docs/decisions/0011-*.md` 36-47). ADR-0008 permits only Status-line and References addendums; adding a verb row rewords the Decision section, which "still requires a new/superseding ADR". `principles_review_guide.md:64` says the same ("or a new ADR per ADR-0008 if the verb count changes"). So: a short new ADR for `repo_pin` (contract, the four kinds, who answers what) and a one-line Status addendum in ADR-0011. Issue 436's plan (c) repeated the same misreading; nothing there to fix now, since the verb moves here.
3. **[Consequences] Verb-count text and assertions.** Four assertions check the literal "all 12 verbs implemented": `test_adapter.sh:204`, `:218`, `test_ros2_colcon.sh:671`, `:672`. Step 8 lists those suites under "unchanged ... (existing cases)". They must change to 13, and `test_adapter.sh` runs in the `validate-adapter-contract` CI job, so leaving them would fail CI. Text that says "12-verb": `docs/design.md:341` and `.agent/knowledge/principles_review_guide.md:46`; neither is in the files table. Stub types in `test_adapter.sh` (`fake_type`) and `test_project_registry.sh` (`other_type`, `probe`) are already incomplete and are only dispatched, never validated, so they are unaffected (the dispatcher checks the verb name, not that the type defines it).
4. **[Approach] Name the answer when one repository appears in more than one layer's `.repos`.** `repo_pin <repo>` reads "the `.repos` files of its manifest directory", which are per layer (`adapter_sync` loops layer by layer). An overlay can pin the same name in two layers at different refs. Either take the layer (the caller has `--layer`) or exit 1 naming both; do not take the first match silently. One test.
5. **[Flexibility] Two exits are worded wrongly; none is false in substance.** (a) Owner/repo row: "would take a forge-neutral repository key ... in the scan, `worktree_repos` ownership and `gh_create_pr.sh`'s safety check". `worktree_repos` ownership already goes through `adapter_scope_for_pr`, which parses any host's URL or scp form (`ros2_colcon/adapter.sh` 868-896). Only the scan (`extract_gh_slug`, GitHub-only, `_issue_helpers.sh:22`) and `gh_create_pr.sh` would change. (b) Base cross-check row: "the push names the base". A push of the feature branch names no base. Under the merge exit, the `git merge` target is read from the header's `base=`, so there is nothing to cross-check. The other exits hold: the `**Branch**` correlation is accepted by `progress_read.py`; `git merge` plus `git push` is a real path for the merge; the field-mode bullet exists at `run-issue/SKILL.md:910`; and the sibling, fallback, CI and decision-summary rows say "none today" with a plausible route.
6. **[Small] 2b step 1, implementer note.** The scan `break`s with `_m_rel` set, but the matches are collected as `dir<TAB>project<TAB>issue` and `_m_rel` is `unset` afterwards; carry the relative path as a fourth field of `_PKG_MATCHES` so `PKG_OWN_REL` comes from the one chosen match.

### Project types and CI (asked)

Types in the tree: `ros2_colcon` and `single_project` (`.agent/project_types/`), the only ones `validate_adapter.sh` iterates. The plan names both answers: ROS from `_rc_repos_entries` with the kind from git; single-repository the default branch from `origin/HEAD` (`ls-remote --symref` fallback), kind `branch`, exit 1 for another name. `validate_adapter.sh` checks only `declare -F adapter_<verb>` for every `REQUIRED_VERBS` entry, so with both functions defined the pre-commit hook and the `validate-adapter-contract` job pass. That job also runs `test_adapter.sh` and the registry tests: they pass once finding 3's assertions move to 13.

### Summary

The revision resolves both must-fixes, the Flexibility findings and the `--base` question as worded, and takes every suggestion. Nothing introduced would start or target the wrong branch, break a type or a timeline, or claim a false exit. 2a is ready to implement as two pull requests: the verb first (with a new ADR rather than an edit to ADR-0011's table, and the 12-to-13 text and assertions), then the base mechanism, built in parallel and merged after it.

### Recommended Actions

- [ ] (suggestion) Split 2a: `repo_pin` verb pull request first, base mechanism second (built in parallel)
- [ ] (suggestion) A new short ADR for `repo_pin`; ADR-0011 gets a Status-line addendum only
- [ ] (suggestion) Update the four "all 12 verbs" assertions and the "12-verb" text in `docs/design.md:341` and `principles_review_guide.md:46`
- [ ] (suggestion) `repo_pin` for a name pinned in two layers: take the layer or refuse naming both, with a test
- [ ] (suggestion) Reword the owner/repo and base cross-check exits as in finding 5
- [ ] (suggestion) Carry `_m_rel` in `_PKG_MATCHES` for `PKG_OWN_REL`

## Checkpoint
**Status**: complete
**When**: 2026-11-10 15:00 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second plan review of part 2: ready, no must-fix)
**After**: plan
**Decision**: proceed

Host read the second Plan Review (ready). Carried to the implementer: `repo_pin` is recorded in a new short ADR, with only a one-line Status note on ADR-0011 (ADR-0008 forbids editing its verb table); the four "all 12 verbs implemented" assertions and the two "12-verb" texts become 13; `repo_pin` takes the layer, or refuses naming both, when a repository is pinned in two layers; two exits in the GitHub table are reworded as the review says; `_m_rel` is carried in `_PKG_MATCHES` for 2b. Order: the verb with its ADR is its own pull request first; the base mechanism follows it; 2b in parallel.

NOT dispatched: the owner's stop time (15:00 on 2026-11-10) was reached, and no phase starts after it. The loop resumes here: the next step is the implement pass for the verb's pull request.

## Implementation
**Status**: complete
**When**: 2026-11-12 17:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-429 at `bfe6ebba`
**Commits**: afd01eac, bfe6ebba

Scope of this pass: the verb's pull request only, the first of part 2's pull requests, as the plan checkpoint of 2026-11-10 15:00 ordered ("the verb with its ADR is its own pull request first; the base mechanism follows it; 2b in parallel"). The base mechanism (2a steps 3 to 8) and 2b are later pull requests and are not on this branch.

- `afd01eac` `repo_pin <repo> [--layer <l>]` is the 13th entry of `REQUIRED_VERBS` (`.agent/scripts/adapter`, header and usage). It prints `<ref><TAB><kind>`, kind `branch`, `tag`, `commit` or `unknown`.
  - `ros2_colcon`: the `version:` of the repo in `repos/<layer>.repos` (through `_rc_repos_entries`), quotes stripped. On origin, `refs/heads/<ref>` is a branch, then `refs/tags/<ref>` a tag. A 40- or 64-hex ref is a commit, else unknown. When origin cannot be asked, or the repo is not cloned, the local refs decide and stderr says "unverified". A repo pinned in two layers at different refs refuses, naming each layer and ref, unless `--layer` is given.
  - `single_project`: only the name `adapter repos` prints. It answers `origin/HEAD`, else `ls-remote --symref origin HEAD`, kind `branch`. It exits 1 when neither answers, and refuses `--layer`.
  - Tests: `test_adapter.sh` gets 6 cases, among them the validator on a type that lacks only `repo_pin`. `test_ros2_colcon.sh` gets 8 cases: all four kinds online, branch before tag, a branch deleted upstream with a stale remote ref (unknown), offline fallback including a local-only branch, not cloned, quoted refs, not found, and two layers. The four "all 12 verbs implemented" assertions now say 13.
- `bfe6ebba` New `docs/decisions/0019-repo-pin-verb.md`. ADR-0011 gets only a Status-line and References addendum (ADR-0008). Other texts:
  - `docs/design.md`: the contract bullet says 13 verbs and what the verb does; Table 2 gets the row (tally 5 real); the decision register gets the 0019 row, and ADR-0011's row says 13; a change-log row (917 lines).
  - `principles_review_guide.md`: "13-verb", and a 0019 row.
  - `script_reference.md`: the `adapter` row.

### Adaptations from the plan
- Drift check against the tree after the merge from main: `REQUIRED_VERBS` still had 12 entries. `_rc_repos_entries`, `adapter_worktree_repos`'s owning rule and the four assertions were where the reviews cited them, and the "12-verb" texts were at `docs/design.md:347` (the review said 341) and `principles_review_guide.md:46`. No mechanical drift changed a step.
- Kind lookup: the plan's separate `ls-remote --heads` and `--tags` calls are replaced by one `ls-remote origin refs/heads/<ref> refs/tags/<ref>` call. Its output is compared exactly, because ls-remote patterns match on the tail. A ref that `git check-ref-format` rejects is never sent to origin.
- "Unverified" is a NOTE on stderr. The stdout line stays the plan's two fields.
- Not cloned: a 40- or 64-hex ref is still `commit`, since that needs no repository. Any other ref is `unknown`.
- Two layers: the same ref in several layers is one answer. Only different refs refuse. The checkpoint's wording ("takes the layer, or refuses naming both") does not cover equal refs.
- Not in the plan's file list, added as consequences: Table 2 of the design (the dated verb probe), the review guide's 0019 row (its "An ADR" consequence row), and the decision-register row, which `check_design_anchors.sh` requires for every ADR file.
- Issue 436 is untouched. The plan's note that whichever of the two quote-strippers lands second drops the duplicate still stands.

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP, on the final tree: rc 0.
  - Hooks: adapter contract, design anchors, shellcheck, and the script-suite hook. The hook selects 40 suites (`suites_for_files.sh` over the in-scope files; the adapters reach most suites), and every one passed.
  - Run on their own while building: test_adapter 139/0, test_ros2_colcon 254/0.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 17:57 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-429 at `391a2d03`
**Base**: main
**Depth**: Deep (reason: extends the ADR-0011 adapter contract that every project type implements, adds ADR-0019 and design/governance text; 10 files, about 545 lines outside the timeline)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue (round 1: 2 must-fix; the first round always gets a re-review after fixes)

Round correction by the host: `review_progress.sh round` counts this as round 4, because part 1 (merged as PR 445) had three pre-push reviews on this branch's timeline. The diff under review (`main...HEAD`: the `repo_pin` verb, its tests, ADR-0019 and the design and knowledge text) had never been reviewed. So it was treated as round 1: a cold read of the whole diff at full depth, with the cross-model reviewers dispatched. The round-3 "narrow convergence check" rule was not applied.

Specialists:
- Static: shellcheck `--severity=warning` on the 5 changed shell files, rc 0. test_ros2_colcon 254/0, test_adapter 139/0. `validate_adapter.sh`: 13/13 for both types.
- Governance: ADR-0008 followed (new ADR, Status and References addendum only on ADR-0011). ADR-0011 and ADR-0017 followed (the design bullet, Table 2, the register and the change log were all updated).
- Plan drift: the five adaptations were judged acceptable:
  - one exact-compared `ls-remote` call;
  - "unverified" reported on stderr;
  - an uncloned full sha reported as `commit`;
  - equal refs in two layers accepted, different refs refused;
  - three extra files, which are consequences the anchors check requires.
- Claude adversarial subagent: ran.
- Cross-model:
  - gemini (agy): complete, 2 suggestions.
  - codex: complete, 1 must-fix (`#` truncation).
  - Copilot: skipped (disabled for quota).

### Findings
- [x] (must-fix) The `_rc_repos_entries` parser cuts the version at any `#`, so `version: fix#12` reads as `fix`, and `"fix#12"` reads as `"fix` with the quote left in; the verb then exits 0 with the wrong ref (a silent wrong base when a branch `fix` exists). Strip only a whitespace-preceded `#` comment, refuse a ref left holding `"`, `'` or `\r` (CRLF files give `dev\r`), and add tests (codex and Claude adversarial, reproduced) — `.agent/project_types/ros2_colcon/adapter.sh:225`
- [x] (must-fix) The origin queries in `repo_pin` have no time limit: `GIT_TERMINAL_PROMPT=0` does not stop SSH prompts or a stalled host. A reproduction with a 15s ssh stub took 30s. The worktree creation path that ADR-0019 names as a caller bounds every origin call with `wt_bounded_git` (#323), so bound these the same way; a timeout should fall to the unverified local answer — `.agent/project_types/ros2_colcon/adapter.sh:891`, `.agent/project_types/single_project/adapter.sh:311`
- [x] (suggestion) When the same ref is pinned in several layers, the kind is judged in the first layer's checkout even if only a later layer has it cloned. The result is `unknown (unverified)` for a valid branch, where `--layer l2` gives `branch`. Use the first hit layer whose checkout exists, and extend `test_repo_pin_two_layers` (gemini and Claude adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:977`
- [x] (suggestion) An entry with no `version:` key (vcstool uses the default branch) is reported as "no repository ... pinned (known: ...)" and left out of the known list. Give it its own message. Slash keys and flow-style entries are dropped the same way; that comes from the existing parser (Claude adversarial) — `.agent/project_types/ros2_colcon/adapter.sh:215-229`
- [x] (suggestion) An uppercase 40-hex sha is reported as `unknown`, although git accepts it. Match case-insensitively, or say "lowercase" in ADR-0019 (gemini) — `.agent/project_types/ros2_colcon/adapter.sh:878`

## Checkpoint
**Status**: complete
**When**: 2026-11-12 17:56 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the round limit was reached only because the counter carries part 1's three reviews; this was the first review of the verb's diff and it found two must-fix defects; first host address at this checkpoint)
**After**: rounds
**Decision**: address

The round counter says 4 because part 1 (pull request 445) had three pre-push reviews on this timeline. The diff under review (the repo_pin verb and ADR-0019) had never been reviewed, so the review ran as a full first round with outside reviewers. It found two must-fix defects (a version value cut at any "#"; origin calls with no time limit) and three suggestions. Fix all five, then re-review.

## Implementation
**Status**: complete
**When**: 2026-11-12 18:20 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-429 at `97fa1bd5`
**Addressed**: Local Review (Pre-Push) at `391a2d03` (2026-11-12 17:57 -05:00)
**Commits**: 72d89cb1, e416c3ce, 3fd6d185, 37075936, 97fa1bd5

### Actions
- [x] (must-fix) `version:` read as YAML: `_rc_repos_entries` keeps a quoted scalar whole, starts a comment only at a whitespace-preceded `#`, drops a CRLF line end (name lines too); `repo_pin` refuses a ref still holding `"`, `'` or CR. Test `test_repo_pin_reads_version_as_yaml` (`fix#12` with a branch `fix` also on origin, quoted with trailing comment, `fix # comment`, CRLF file, three stray-quote refusals) — `.agent/project_types/ros2_colcon/adapter.sh:211`
- [x] (must-fix) Origin queries bounded: the dispatcher gains `_adapter_bounded_git` / `_adapter_git_limit` (same `WT_FETCH_TIMEOUT` knob and `timeout -k 5` as `wt_bounded_git`, #323); `ros2_colcon` falls to the unverified local answer naming the limit, `single_project` names the timeout in its error. Tests `test_repo_pin_hanging_origin_is_bounded` in both `test_ros2_colcon.sh` and `test_adapter.sh` (blocking ssh shim, 2s limit, 60s ceiling); ADR-0019 says so — `.agent/scripts/adapter`, `.agent/project_types/ros2_colcon/adapter.sh:_rc_pin_kind`, `.agent/project_types/single_project/adapter.sh:adapter_repo_pin`
- [x] (suggestion) Multi-layer same-ref pin judged in the first hit layer whose checkout is cloned; `test_repo_pin_two_layers` extended (cloned only in l2: `branch`, verified, agrees with `--layer l2`) — `.agent/project_types/ros2_colcon/adapter.sh:adapter_repo_pin`
- [x] (suggestion) Entry with no `version:` key: `_rc_repos_entries --all` emits it; `repo_pin` lists it as known, gives it its own message, and reports it as a differing ref against a layer that pins one. Test `test_repo_pin_entry_without_version`; ADR-0019 says so. Slash keys and flow-style entries are still dropped by the parser (unchanged, as the finding noted) — `.agent/project_types/ros2_colcon/adapter.sh:211`
- [x] (suggestion) Uppercase 40/64-hex sha matched case-insensitively; tests in `test_repo_pin_kinds_online` (online) and `test_repo_pin_not_cloned` (uncloned); ADR-0019 says "either case" — `.agent/project_types/ros2_colcon/adapter.sh:_rc_pin_kind`

### Checks
- Pre-commit over `main...HEAD` with no SKIP (main checkout venv): all hooks passed, including `validate-script-tests`. A first run failed only `check-commit-identity` because the identity was not sourced in that shell; re-run with it sourced passed.
- A revert-and-rerun check that the two-layer test fails on the old code was denied by the permission classifier; not done.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 18:26 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a590f22537565001a, resume 1 of 3)

**Branch**: feature/issue-429 at `45ad3988`
**Base**: main
**Depth**: Deep (reason: whole-diff classification is unchanged; the change extends the ADR-0011 adapter contract and adds ADR-0019. Fix-round rule: no lower than the whole diff)
**Must-fix**: 2 | **Suggestions**: 1
**Round**: 2 | **Ship**: recommended (round 2: 2 mechanical must-fix (prev 2), not rising; fix and ship rather than another full round)

Round note: the dispatcher labels this round 5, and `review_progress.sh round` counts part 1's reviews (PR 445). The host made the same correction as at round 1: this is round 2 of this diff. Scope: the five round-1 findings and the fix diff `9a62100a..45ad3988` (72d89cb1, e416c3ce, 3fd6d185, 37075936, 97fa1bd5). Specialists run: a fresh Claude adversarial sub-review, and cross-model gemini (agy) and codex, both complete. Copilot was skipped (disabled for quota).

Round-1 findings, all five addressed:
- `#` inside a ref: fixed, but the fix brought in a new must-fix (below).
- Bounded origin queries: fixed.
- First cloned layer: fixed.
- No-`version:` message: fixed.
- Uppercase sha: fixed.

Host's questions:
- **Two-layer test:** it pins the fix. `pkg_b` is pinned in l1 and l2 at the same ref, and the test removes l1's checkout. The old code judged the first hit layer (l1), so it would print "not a cloned repository (unverified)" and `pinned<TAB>unknown`. The test asserts `pinned<TAB>branch` with no "unverified", so it fails on the old code. This rests on reading the code; a revert-and-run was not done.
- **Hanging-origin tests:** not timing-fragile. There is a 2s limit against a 60s ceiling, the shim blocks for 300s, and `ssh://…example.invalid` does no DNS lookup under `GIT_SSH_COMMAND`. Measured runs: 2s in each suite; test_ros2_colcon took 20s in all, test_adapter 4.6s.
- **Leftover processes:** none. `pgrep 'sleep 300'` was empty after the runs. This machine's uutils `timeout` 0.10.0 kills the whole process group: verified with a `sleep 30` child that did not survive. The tests also kill the shim's pid from the pidfile.
- **Other parser callers:** `adapter_sync:608` and `adapter_validate:650` use it without `--all`. Their output is unchanged except for CRLF (now stripped, an improvement) and the leading-comment regression below.
- **Codex's "sync regression" on quoted versions:** dismissed as not a regression. Main's `$2` parse already kept the quotes of `"pinned"`, checked with `git show main:…adapter.sh`. The planned issue-436 parser change is where quote stripping for sync belongs.

Checks run:
- test_ros2_colcon: 289 passed, 0 failed.
- test_adapter: 143 passed, 0 failed.
- shellcheck `--severity=warning` on the 5 shell files: rc 0.
- `validate_adapter.sh`: 13/13 verbs for both types.

### Findings
- [x] (must-fix) Regression: leading whitespace is stripped before the comment check, so `version:  # TODO pin` and `version: #main` are emitted as the refs `# TODO pin` / `#main`, and `repo_pin` exits 0 with kind unknown. The old parser gave an empty value, which was refused. `adapter_sync` gets the comment as the pin too. Fix: check for the comment before trimming, or treat a leading `#` as a comment. Add both to `test_repo_pin_reads_version_as_yaml`. Found by Claude adversarial; reproduced with the parser's awk — `.agent/project_types/ros2_colcon/adapter.sh:240-247`
- [x] (must-fix) A quoted scalar is cut at the next matching quote and the rest of the line is not checked. `'stable''next'` reads as `stable`, `"main" extra` as `main`, and `"x\"y"` as `x\`. Each is printed as a clean ref nobody pinned, and the stray-quote guard never fires. Fix: keep the quoted cut only when nothing follows it except optional whitespace and a ` #` comment; otherwise emit the raw value so the quote guard refuses it. Add tests. Found by codex (must-fix), gemini and Claude adversarial (suggestion); reproduced — `.agent/project_types/ros2_colcon/adapter.sh:237-244`
- [x] (suggestion) In `single_project`, when `ls-remote` fails for a reason other than the timeout (rc 128: origin missing or unreachable), the error still says "origin did not name its HEAD". It should say origin could not be asked (gemini) — `.agent/project_types/single_project/adapter.sh:308-321`

## Checkpoint
**Status**: complete
**When**: 2026-11-12 18:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second review of the verb's diff found two must-fix defects in the fix itself; second host address in a row at this checkpoint, so the next answer here is the owner's)
**After**: rounds
**Decision**: address

Round 2 of this diff (the counter says 5 because it carries part 1's reviews). Two must-fix, both in the new version parser: a comment directly after "version:" is read as the ref; a quoted value is cut at the closing quote with the rest of the line unchecked. One suggestion: single_project's error text when ls-remote fails for a reason other than the timeout. Fix all three, then a narrow convergence review.

## Implementation
**Status**: complete
**When**: 2026-11-12 18:37 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a67905ba1b4cca62a, resume 1 of 3)

**Branch**: feature/issue-429 at `f30044c0`
**Addressed**: Local Review (Pre-Push) at `45ad3988` (2026-11-12 18:26 -05:00)
**Commits**: ff1297ef, 25407246, f30044c0

### Actions
- [x] (must-fix) A comment right after the key (`version:  # TODO pin`, `version: #main`) now leaves the value empty, before any trimming; `repo_pin` refuses it as "has an empty version:". Tests: `test_repo_pin_reads_version_as_yaml` (both forms), `test_repos_entries_parser_table` — `.agent/project_types/ros2_colcon/adapter.sh:_rc_repos_entries`
- [x] (must-fix) A quoted value is unquoted only when nothing but whitespace and a ` #` comment follows its closing quote; otherwise the raw text (quotes included) is emitted and `repo_pin`'s quote guard refuses it. The parser now unquotes for every caller (so `adapter_sync` compares a quoted pin to the branch correctly) and `repo_pin` dropped its own strip. Fixed with finding 1 in one commit (ff1297ef): same lines. Tests: `test_repo_pin_reads_version_as_yaml` (`'stable''next'`, `"main" extra`, `"x\"y"`, `"main"#c` refused), `test_repos_entries_parser_table`, `test_sync_reads_quoted_and_commented_pins` (sync pulls `"fakefox" # pinned`, fetches the comment-only pin as `pinned: `; validate sees both repos). ADR-0019 states the rules (25407246) — `.agent/project_types/ros2_colcon/adapter.sh:_rc_repos_entries`
- [x] (suggestion) `single_project`: an `ls-remote` failure other than the timeout now says "origin could not be asked (git ls-remote exited <rc>)"; "origin did not name its HEAD" stays for an origin that answers without a branch HEAD. Test: `test_repo_pin_undetermined_fails` (unreachable origin; origin whose HEAD names a missing branch) — `.agent/project_types/single_project/adapter.sh:adapter_repo_pin`

### Parser input table (`test_repos_entries_parser_table`)
Text after `    version:` → value emitted (`repo_pin` outcome):

| Input | Emitted | repo_pin |
|-------|---------|----------|
| ` pinned` | `pinned` | ref |
| ` fix#12` | `fix#12` | ref |
| ` fix # a comment` | `fix` | ref |
| ` "fix#12"` | `fix#12` | ref |
| ` 'v1.0'` | `v1.0` | ref |
| ` "fix#12" # pinned for #12` | `fix#12` | ref |
| `  'v1.0'   ` | `v1.0` | ref |
| `  # TODO pin` (comment only) | empty | refused, empty |
| ` #main` | empty | refused, empty |
| (nothing) | empty | refused, empty |
| ` ""` | empty | refused, empty |
| ` dev` + CRLF | `dev` | ref |
| ` "dev"` + CRLF | `dev` | ref |
| ` dev # c` + CRLF | `dev` | ref |
| ` "fix` | `"fix` | refused, quote |
| ` fix'` | `fix'` | refused, quote |
| ` fi"x` | `fi"x` | refused, quote |
| ` 'stable''next'` | `'stable''next'` | refused, quote |
| ` "main" extra` | `"main" extra` | refused, quote |
| ` "x\"y"` | `"x\"y"` | refused, quote |
| ` "main"#c` | `"main"#c` | refused, quote |
| no `version:` key | name alone (with `--all`) | own message |

`adapter_validate` reads only names, and every row emits its name; `adapter_sync` gets the emitted value (checked end to end for the quoted+comment and comment-only rows).

### Checks
- Pre-commit over `main...HEAD`, no SKIP, identity sourced: all hooks passed (rc=0), including `validate-script-tests`.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 18:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a590f22537565001a, resume 2 of 3)

**Branch**: feature/issue-429 at `3ab6be9d`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff; the whole diff extends the ADR-0011 adapter contract and adds ADR-0019)
**Must-fix**: 0 | **Suggestions**: 3
**Round**: 3 | **Ship**: recommended (no must-fix findings; the remaining suggestions can be applied or tracked)

**Round note:** the dispatcher says round 6, and its counter carries part 1's reviews. This is round 3 of this diff. Per the round-3 convergence rule:
- Scope: the round-2 findings and the fix diff `6444f844..3ab6be9d` (ff1297ef, 25407246, f30044c0).
- Cross-model: skipped (round-3 convergence check, per handoff).
- A fresh Claude adversarial sub-review ran.

**Round-2 findings, all three addressed:**
- A comment after the key is now an empty value, which is refused.
- A quoted value counts only when nothing but a comment follows its closing quote; otherwise it is emitted raw and the quote guard refuses it.
- `single_project` says "origin could not be asked (git ls-remote exited N)".

**The parser table:** all 21 rows plus the no-`version:` row were run through the real `_rc_repos_entries` (`test_repos_entries_parser_table` sources the adapter). Every row emits what the Implementation table says.

**Callers:**
- `adapter_sync` changes only as claimed: main's `$2` parse kept `"fakefox"`, so a quoted pin never matched its branch; it now pulls. Comment-only pins were already empty on main.
- `adapter_validate` reads names only, so it is unchanged.

**Rounds 1-2:** nothing regressed (CRLF, `#` inside a ref, `--all`, uppercase sha, bounded `ls-remote`, first cloned layer).

**Checks:**
- test_ros2_colcon: 327 passed, 0 failed.
- test_adapter: 147 passed, 0 failed.
- shellcheck at warning severity: rc 0.
- `validate_adapter.sh`: 13/13 verbs for both types.
- No leftover `sleep 300` processes.

### Findings
- [ ] (suggestion) In `adapter_sync`, an empty pinned version on a detached checkout equals the empty `git branch --show-current`. Sync then takes the pull path, which fails ("pull failed (continuing)"), and skips the fetch. This diff widens the case from a literal empty `version:` to comment-only and `""` pins, and it does no harm beyond the skipped fetch. Fix: take the pull path only when `$branch` is non-empty (Claude adversarial, reproduced) — `.agent/project_types/ros2_colcon/adapter.sh:607`
- [ ] (suggestion) A double-quoted value with backslash escapes is not decoded: `"a\" #b"` gives `a\`, and `"v\x31.0"` gives `v\x31.0`, both with exit 0. Each still contains a backslash, which git forbids in a ref, so the kind is `unknown`, which callers refuse; no wrong base results. Add `\\` to the guard's character class so the error message is right (Claude adversarial; this predates the diff) — `.agent/project_types/ros2_colcon/adapter.sh:1048`
- [ ] (suggestion) YAML typing of plain scalars is ignored. vcstool checks out `str(value)`, so `version: 1.10` is `1.1` to vcstool, while repo_pin answers `1.10<TAB>tag` (and `null`, `yes` or `!!str x` similarly). Refuse plain values that YAML types as a number, null or bool, or that start with `!`, `>`, `|`, `&` or `*`, or track it in a follow-up issue. This predates the diff and was not introduced in this round (Claude adversarial, reproduced) — `.agent/project_types/ros2_colcon/adapter.sh:236-262`

## Checkpoint
**Status**: complete
**When**: 2026-11-12 18:41 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (pre-push review approved at round 3 of this diff, no must-fix; three suggestions go to triage)
**After**: publish
**Decision**: publish

The convergence review approved the verb's diff with three suggestions (sync's pull path on an empty pin with a detached checkout; backslash in the quote guard; YAML typing of unquoted values), two of which predate this change. Publish; triage decides them.

## Integrated Review
**Status**: complete
**When**: 2026-11-12 18:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #456 at `d0eb4a84`
**Sources**: 2 (Local Review (Pre-Push) @ `3ab6be9` (covers d0eb4a84 via bookkeeping), CI rollup). Copilot review skipped (disabled for quota); no GitHub reviews or conversation comments. Earlier pre-push entries of this diff (`391a2d03`, `45ad3988`) have no open findings; the stale `a6c2d2f` entry belongs to part 1 / PR #445 and is out of scope.
**Cross-source confirmations**: 0
**CI**: pending (Lint (pre-commit) x2 and one Validate Adapter Contract still running; ros-manifest tests, Validate Documentation, the other Validate Adapter Contract pass)

All three suggestions were re-read against the code and reproduced; each is a fix in this pull request.

### Findings
- [x] (should-fix, Local Review @ `3ab6be9`) `adapter_sync`: an empty pin on a detached checkout equals the empty `git branch --show-current`, so sync takes the pull path, which fails with a misleading "pull failed", and the fetch is skipped (stale checkout). Widened by this diff: comment-only and `""` pins now parse empty. Fix: take the pull path only when `[ -n "$branch" ] && [ "$branch" = "$version" ]`; add a test with a detached checkout and an empty or comment-only pin that asserts the fetch runs — `.agent/project_types/ros2_colcon/adapter.sh:607-608`
- [x] (should-fix, Local Review @ `3ab6be9`) A double-quoted value with a backslash escape is decoded wrongly by the parser. Reproduced: `"a\" #b"` gives `a\` (YAML: `a" #b`), and `"v\x31.0"` gives `v\x31.0` (YAML: `v1.0`), both exit 0. Callers refuse both as kind `unknown`, so no wrong base results, but the error message is wrong. This diff also contradicts its own parser comment ("an escaped quote" is emitted raw). Correction to the review: the quoted-scalar decoding and the quote guard are both new in this diff, so it does not predate it. Fix: in `_rc_repos_entries`, send a double-quoted value whose content holds `\` down the raw branch; add `\\` to the repo_pin guard's character class (line 1055); add both cases to `test_repos_entries_parser_table` and the repo_pin refusal tests — `.agent/project_types/ros2_colcon/adapter.sh:246-260,1055`
- [x] (should-fix, Local Review @ `3ab6be9`) YAML typing of plain scalars is ignored. Verified: vcstool `import_.py:173` passes `str(repo['version'])` from `yaml.safe_load`, so `version: 1.10` checks out `1.1` while repo_pin answers `1.10`. That is a silent wrong base when both tags exist, and a wrong error otherwise. The parser's `$2` predates the diff, but repo_pin, the new consumer that turns it into a base, is new here. Fix: in repo_pin, refuse a plain (unquoted) value that PyYAML's implicit resolvers type as bool, null, int or float (`yes/no/on/off/true/false`, `~/null`, decimal/octal/hex/sexagesimal ints, floats incl. `.inf`/`.nan`), or that starts with a YAML indicator (`! & * | > % @` or a backtick), with a message to quote it. A quoted value stays accepted. Add table tests. If the host wants to keep scope, the alternative is a follow-up issue opened before merge, not an unrecorded deferral — `.agent/project_types/ros2_colcon/adapter.sh:236-262,1048-1058`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-12 18:43 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (triage classified all three open findings valid and should-fix in this pull request; one is a silent wrong base)
**After**: findings
**Decision**: address

Fix all three in pull request 456: sync's pull path on an empty pin with a detached checkout; a backslash inside a double-quoted value; repo_pin refusing an unquoted value that YAML types as bool, null or number, or that starts with a YAML indicator, asking for it to be quoted.

## Implementation
**Status**: complete
**When**: 2026-11-12 18:57 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a67905ba1b4cca62a, resume 2 of 3)

**PR**: #456 at `942a442c`
**Addressed**: Integrated Review at `d0eb4a84` (2026-11-12 18:43 -05:00)
**Commits**: d4a7750b, 7127cc81, 942a442c

### Actions
- [x] (should-fix) `adapter_sync` pulls only when `[ -n "$branch" ] && [ "$branch" = "$version" ]`, so a detached checkout with an empty pin is fetched rather than sent down the pull path. Test: `test_sync_reads_quoted_and_commented_pins` extended (detached checkout, pins `  # TODO pin` and `""`: the "fetching" line, no "pull failed", and origin's new commit is in `origin/fakefox`) — `.agent/project_types/ros2_colcon/adapter.sh:adapter_sync`
- [x] (should-fix) A double-quoted value holding a backslash is emitted raw; the `repo_pin` guard also refuses `\`, and its message names "a stray quote, a backslash escape or a carriage return". Tests: parser table rows, and `test_repo_pin_reads_version_as_yaml` refusals for `"a\" #b"`, `"v\x31.0"`, `'a\b'` — `.agent/project_types/ros2_colcon/adapter.sh:_rc_repos_entries`, `adapter_repo_pin`
- [x] (should-fix) `repo_pin` refuses an unquoted value that PyYAML `safe_load` (YAML 1.1) types as a bool, null, int or float, or that starts with an indicator character (`! & * | > % @` backtick `[ ] { } ,`). The message asks for quotes, e.g. `quote it: version: "1.10"`. Every layer pinning the repo is checked, so a ref that is quoted in l1 but plain in l2 is refused, naming l2. `_rc_yaml_plain_type` is an explicit pattern list whose comment names the forms. A dev-time comparison against PyYAML 6.0.3 on 70 samples agreed on every value. The differences were only the documented ones: indicators, which PyYAML rejects or reads as a non-string, and a date alone, which round-trips. Timestamps with a time part are not covered: they hold a `:`, which no git ref can. To tell quoted from plain, `_rc_repos_entries --all` became `--detail`, which adds a `quoted`/`plain`/`none` field; the default output that sync and validate read is unchanged, so sync still compares an unquoted `1.10` as `1.10`. Tests: `test_repo_pin_refuses_yaml_typed_plain_pins` (14 values, quoted `"1.10"` and `'1.10'` accepted as `1.10 tag`, mixed layers), parser table. ADR-0019 updated — `.agent/project_types/ros2_colcon/adapter.sh:_rc_yaml_plain_type`, `adapter_repo_pin`

### Parser input table (`test_repos_entries_parser_table`, both outputs checked)
Text after `    version:` → value (default output, read by sync), the form `--detail` adds, and the `repo_pin` result:

| Input | Value | Form | repo_pin |
|-------|-------|------|----------|
| ` pinned` | `pinned` | plain | ref |
| ` fix#12` | `fix#12` | plain | ref |
| ` fix # a comment` | `fix` | plain | ref |
| ` "fix#12"` | `fix#12` | quoted | ref |
| ` 'v1.0'` | `v1.0` | quoted | ref |
| ` "fix#12" # pinned for #12` | `fix#12` | quoted | ref |
| `  'v1.0'   ` | `v1.0` | quoted | ref |
| `  # TODO pin` | empty | plain | refused, empty |
| ` #main` | empty | plain | refused, empty |
| (nothing) | empty | plain | refused, empty |
| ` ""` | empty | quoted | refused, empty |
| ` dev` + CRLF | `dev` | plain | ref |
| ` "dev"` + CRLF | `dev` | quoted | ref |
| ` dev # c` + CRLF | `dev` | plain | ref |
| ` "fix` | `"fix` | plain | refused, quote |
| ` fix'` | `fix'` | plain | refused, quote |
| ` fi"x` | `fi"x` | plain | refused, quote |
| ` 'stable''next'` | `'stable''next'` | plain | refused, quote |
| ` "main" extra` | `"main" extra` | plain | refused, quote |
| ` "x\"y"` | `"x\"y"` | plain | refused, quote |
| ` "main"#c` | `"main"#c` | plain | refused, quote |
| ` "a\" #b"` (new) | `"a\"` | plain | refused, quote/backslash |
| ` "v\x31.0"` (new) | `"v\x31.0"` | plain | refused, quote/backslash |
| ` 'a\b'` (new) | `a\b` | quoted | refused, backslash |
| ` 1.10` (new) | `1.10` | plain | refused, a float |
| ` "1.10"` (new) | `1.10` | quoted | ref |
| ` '1.10'` (new) | `1.10` | quoted | ref |
| ` yes` (new) | `yes` | plain | refused, a bool |
| ` ~` (new) | `~` | plain | refused, null |
| ` 0x1F` (new) | `0x1F` | plain | refused, an int |
| ` .inf` (new) | `.inf` | plain | refused, a float |
| ` !tag` (new) | `!tag` | plain | refused, indicator |
| ` 2024-01-01` (new) | `2024-01-01` | plain | ref (a date round-trips) |
| no `version:` key | (left out) | none (only with `--detail`) | own message |

`adapter_validate` reads only names, and every row emits its name. `adapter_sync` reads the default value column, which this pass leaves unchanged for every earlier row; its own handling of an unquoted numeric-looking pin is unchanged.

### Checks
- Pre-commit over `main...HEAD`, no SKIP, identity sourced: all hooks passed (rc=0), including `validate-script-tests`.

## Local Review
**Status**: complete
**When**: 2026-11-12 19:00 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a590f22537565001a, resume 3 of 3)

**PR**: #456 at `6807c9f4`
**Depth**: Deep (reason: fix-round re-review. The whole-diff tier is unchanged: the change extends the ADR-0011 adapter contract and adds ADR-0019)
**Must-fix**: 1 | **Suggestions**: 0

Scope: the three triage findings and the fix diff (d4a7750b, 7127cc81, 942a442c), as the handoff set. Cross-model reviewers were not dispatched, per the host's handoff. Static analysis, governance and plan drift were done inline.

**Checks:**
- test_ros2_colcon: 433 passed, 0 failed.
- test_adapter: 147 passed, 0 failed.
- shellcheck at warning severity: rc 0.

**`_rc_yaml_plain_type` against PyYAML:** 70 plain values were run through both `yaml.safe_load('v: <x>')` followed by `str()`, which is vcstool's own path (`import_.py:78,173`), and through a copy of the function.
- **Bool/null:** the PyYAML forms are matched. `y`, `Y`, `n`, `oN` and `nUll` stay strings and are correctly accepted; `Yes`, `ON`, `On`, `yes` and the three `null` spellings are refused.
- **Ints:** `017`, `0x1F`, `0b101`, `1:30`, `1_000` and `+5` are refused.
- **Floats:** `.inf`, `-.inf`, `+.INF`, the NaN forms, `.5`, `1.`, `1.50`, `01.5`, `1_0.5`, `1.5e+3` and `1.10` are refused.
- **Strings kept:** `1e3`, `1e5`, `1.5e3`, `0o17`, `018` and `0123456789` are strings in PyYAML and are accepted.
- **Indicators:** values starting with an indicator character are refused (`!`, `@`, `%` and `,` probed; PyYAML errors on all of them).
- **Real ref names accepted:** `main`, `rolling`, `v1.10`, `1.10.x`, `release/1.2`, `0.3.1`, `deadbeef`, `1e5abcd` and `2024-01-01`.
- **Misses:** none that matter. `=` and `<<` make PyYAML itself fail on the manifest.

**Shas:**
- A leading-zero sha prefix of octal digits only (`0123456`) is octal 42798 to vcstool, so refusing it with "quote it" is right.
- An exponent-looking sha (`1e5abcd`, `12e4567`) is a string and is accepted.
- An all-digit sha without a leading zero (a 7-digit prefix is all digits about 4% of the time) is refused as an int, although `str()` gives it back unchanged. For a sha the outcome barely differs, because a commit or unknown kind is refused as a base anyway; only the message is wrong.

**`--all` renamed to `--detail`:** no caller or test is left on `--all`. `adapter_sync` (633) and `adapter_validate` (675) call with no flag, and `repo_pin` (1070) uses `--detail`.

**Sync pull condition:** `[ -n "$branch" ] && [ "$branch" = "$version" ]`.
- A branch checkout whose pin is the same branch still pulls (`test_sync_*`: "pkg_a: on 'fakefox' — pulling", and the quoted+comment case).
- A different branch still fetches (`on 'feature/x' (pinned: fakefox) — fetching`, line 1478).
- A detached checkout fetches for every pin, empty or not, as before for a non-empty pin.

**Backslash:** a double-quoted value holding `\` is passed raw, and the guard now includes `\`. That holds.

### Findings
- [x] (must-fix) False refusal: every plain value YAML types as an int or float is refused, including those whose `str()` is the text itself. vcstool checks those out exactly as written, yet the error claims "vcstool would not check out '<ref>'". Affected forms:
  - floats `2.0`, `1.0`, `1.5`, `0.3`;
  - ints `2024`, `0`, `-5`;
  - an all-digit sha or sha prefix (verified against PyYAML).
  A project pinned at a release branch such as `2.0` cannot be used without editing its manifest. Fix: refuse only when `str()` changes the text.
  - Ints: accept `^(0|-?[1-9][0-9]*)$`.
  - Floats: accept `^-?(0|[1-9][0-9]*)\.([0-9]*[1-9]|0)$` with at most 15 significant digits, an integer part of at most 16 digits, and not `0.0000…`. This rule was checked against PyYAML on 178,646 random floats: 0 accepted values changed under `str()`, and no value of 15 digits or fewer that round-trips was refused.
  - Add these cases to the test.
  — `.agent/project_types/ros2_colcon/adapter.sh:_rc_yaml_plain_type` and the refusal in `adapter_repo_pin`

## Implementation
**Status**: complete
**When**: 2026-11-12 19:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a67905ba1b4cca62a, resume 3 of 3)

**PR**: #456 at `e361588d`
**Addressed**: Local Review at `6807c9f4` (2026-11-12 19:00 -05:00)
**Commits**: e361588d

### Actions
- [x] (must-fix) False refusal of round-tripping numbers. `_rc_yaml_plain_type` is now `_rc_yaml_plain_reading` and refuses only when YAML's reading changes the text (its comment names that rule).
  - Kept unquoted: ints matching `^(0|-?[1-9][0-9]*)$`, and floats matching `^-?(0|[1-9][0-9]*)\.([0-9]*[1-9]|0)$` with at most 15 significant digits, an integer part of at most 16 digits, and no `0.0000` start.
  - Still refused: every other int or float, plus bool, null and indicator values.
  - The error now says what vcstool would check out, e.g. "reads as the number 1.1, so vcstool would check out '1.1', not '1.10'".
    - The replacement is exact where the shell can compute it: octal, hex, binary, `+`, `_`, a decimal with trailing or leading zeros, `.inf`/`.nan`, bool → `True`/`False`, null → `None`.
    - Otherwise the message says it cannot confirm str() is the text.
  - The helper also moved out from between `_rc_pin_kind` and its header comment.
  - Cross-check, run while developing, against PyYAML 6.0.3 `safe_load` + `str()` on 4,060 values (fixed cases plus random floats, ints and octal-looking strings):
    - no accepted value changes under `str()`, and no printed checkout differs from PyYAML's;
    - 44 values were refused although they round-trip, all of them more than 15 significant digits, which the rule refuses on purpose.

  Test `test_repo_pin_refuses_yaml_typed_plain_pins` covers:
  - refused, each naming the reading and the checkout: `1.10`, `1.50`, `017`, `+5`, `1_000`, `0x1F`, `yes`, `Off`, `~`, `Null`, `.inf`, `1.5e+3`, `0.00001`, `!tag`, `&anchor`, `@x`;
  - accepted unquoted: `2.0`, `1.0`, `1.5`, `0.3`, `2024`, `0`, `-5`, `1e+5`, a 40-digit all-decimal sha; `2.0` as a real branch gives `2.0	branch`;
  - quoted `"1.10"` and `'1.10'` accepted, and the l1-quoted/l2-plain refusal unchanged.

  Parser table rows added. ADR-0019 updated. — `.agent/project_types/ros2_colcon/adapter.sh:_rc_yaml_plain_reading`, `adapter_repo_pin`

The finding's box is checked by hand in the `## Local Review` entry: `review_progress.sh findings` takes only an Integrated Review or a Local Review (Pre-Push) as a source.

### Parser input table (`test_repos_entries_parser_table`, both outputs checked)
Text after `    version:` → value (default output, read by sync), the form `--detail` adds, and the `repo_pin` result:

| Input | Value | Form | repo_pin |
|-------|-------|------|----------|
| ` pinned` | `pinned` | plain | ref |
| ` fix#12` | `fix#12` | plain | ref |
| ` fix # a comment` | `fix` | plain | ref |
| ` "fix#12"` | `fix#12` | quoted | ref |
| ` 'v1.0'` | `v1.0` | quoted | ref |
| ` "fix#12" # pinned for #12` | `fix#12` | quoted | ref |
| `  'v1.0'   ` | `v1.0` | quoted | ref |
| `  # TODO pin` | empty | plain | refused, empty |
| ` #main` | empty | plain | refused, empty |
| (nothing) | empty | plain | refused, empty |
| ` ""` | empty | quoted | refused, empty |
| ` dev` + CRLF | `dev` | plain | ref |
| ` "dev"` + CRLF | `dev` | quoted | ref |
| ` dev # c` + CRLF | `dev` | plain | ref |
| ` "fix` | `"fix` | plain | refused, quote |
| ` fix'` | `fix'` | plain | refused, quote |
| ` fi"x` | `fi"x` | plain | refused, quote |
| ` 'stable''next'` | `'stable''next'` | plain | refused, quote |
| ` "main" extra` | `"main" extra` | plain | refused, quote |
| ` "x\"y"` | `"x\"y"` | plain | refused, quote |
| ` "main"#c` | `"main"#c` | plain | refused, quote |
| ` "a\" #b"` | `"a\"` | plain | refused, quote/backslash |
| ` "v\x31.0"` | `"v\x31.0"` | plain | refused, quote/backslash |
| ` 'a\b'` | `a\b` | quoted | refused, backslash |
| ` 1.10` | `1.10` | plain | refused: the number 1.1, checks out `1.1` |
| ` "1.10"` | `1.10` | quoted | ref |
| ` '1.10'` | `1.10` | quoted | ref |
| ` yes` | `yes` | plain | refused: the bool True, checks out `True` |
| ` ~` | `~` | plain | refused: null, checks out `None` |
| ` 0x1F` | `0x1F` | plain | refused: the number 31 |
| ` .inf` | `.inf` | plain | refused: the float inf |
| ` !tag` | `!tag` | plain | refused, indicator |
| ` 2024-01-01` | `2024-01-01` | plain | ref (a date round-trips) |
| ` 2.0` (new) | `2.0` | plain | ref (str() gives `2.0`) |
| ` 2024` (new) | `2024` | plain | ref (str() gives `2024`) |
| ` 1.50` (new) | `1.50` | plain | refused: the number 1.5 |
| ` 017` (new) | `017` | plain | refused: the number 15 |
| no `version:` key | (left out) | none (only with `--detail`) | own message |

`adapter_sync` and `adapter_validate` are untouched by this pass; the parser's default output is unchanged.

### Checks
- Pre-commit over `main...HEAD`, no SKIP, identity sourced: all hooks passed (rc=0), including `validate-script-tests`.

## Local Review
**Status**: complete
**When**: 2026-11-12 19:28 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #456 at `33cbccd7`
**Depth**: Deep (reason: fix-round re-review; the whole-diff tier is unchanged, the change extends the ADR-0011 adapter contract and adds ADR-0019)
**Must-fix**: 1 | **Suggestions**: 0

Scope: the one finding of the Local Review at `6807c9f4` and its fix, e361588d (`_rc_yaml_plain_reading`, its caller `adapter_repo_pin`, `test_repo_pin_refuses_yaml_typed_plain_pins`, the parser table rows, ADR-0019). The handoff said no cross-model reviewers, so none were dispatched. Governance and plan drift were checked inline.

**Checks:**
- test_ros2_colcon: 479 passed, 0 failed.
- test_adapter: 147 passed, 0 failed.
- shellcheck was not run because it is not installed on this machine.

**`_rc_yaml_plain_reading` against PyYAML 6.0.3 (system python3):** 459,445 plain values were run through `yaml.safe_load('v: <x>')` + `str()` and through the extracted function. The values covered random strings over `0-9._-+eExXbBoO:abf` up to 6 characters, random decimals with up to 17 integer digits and up to 8 fraction digits (with signs and leading zeros), and named cases.
- **Accepted values `str()` changes:** only `2024-01-01T00:00:00Z`. It holds a `:` that no git ref can hold, and the helper's comment says so.
- **Accepted values PyYAML cannot load:** values ending in `:`, `-`, `?`, `=` and `<<`. vcstool fails on the manifest for these, so nothing is silently checked out. The earlier review already noted `=` and `<<`.
- **"would check out X" claims:** none differs from PyYAML's `str()`, with one exception, `True`/`False`, covered by the finding below.
- **False refusals, apart from floats of more than 15 significant digits (refused by design):**
  - `._<digits>`: PyYAML 6's resolver is `\.[0-9][0-9_]*`, not `\.[0-9_]+`. A ref component cannot start with `.`, so no real ref is affected.
  - `True` and `False`: the finding below.
- **Common refs accepted:** `main`, `rolling`, `humble`, `v1.10`, `1.10.x`, `3.0.0`, `1.0.0`, `2.0`, `10.0`, `0.1`, `2024`, `0123456` (refused as octal, correctly), `1234567`.

### Findings
- [x] (must-fix) `version: True` and `version: False` (unquoted) are refused, though PyYAML gives the bool `True`/`False` and `str()` turns it back into the same text, so vcstool checks out the ref as written. That breaks the stated rule. Run through the real verb, with a branch `True` on origin, the error says something false: `... which YAML reads as the bool True, so vcstool would check out 'True', not 'True'; quote it`. ADR-0019 line 52 also lists "a bool" among the values whose reading changes the text. Fix: accept exactly `True` and `False`, or exclude them from the bool branch, and add both to the test's kept list and the ADR wording. Other spellings (`true`, `TRUE`, `yes`, ...) stay refused. — `.agent/project_types/ros2_colcon/adapter.sh:949-952`, `docs/decisions/0019-repo-pin-verb.md:52`

## Implementation
**Status**: complete
**When**: 2026-11-12 19:54 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #456 at `8fc482b9`
**Addressed**: Local Review at `33cbccd7` (2026-11-12 19:28 -05:00)
**Commits**: 556ead1b (merge of main), 8fc482b9

The branch took main first: merge commit `556ead1b` brings in issue 455's identity change. Its one conflict was the `docs/design.md` change log, where main and this branch each added a 2026-11-12 row. Both rows are kept, main's first and then this branch's, matching the table's merge order. This branch's row, now the last, gives the merged file's length (921 lines, was 917). `check_design_anchors.sh` passed.

### Actions
- [x] (must-fix) Unquoted `True` and `False` were falsely refused, and the error contradicted itself ("would check out 'True', not 'True'"). Both are now taken out of the bool branch of `_rc_yaml_plain_reading`. Every other bool spelling stays refused (`true`, `TRUE`, `yes`, `On`, `false`, `FALSE`, `Off`, ...). The helper's comment says why. — `.agent/project_types/ros2_colcon/adapter.sh:_rc_yaml_plain_reading`
  - Test `test_repo_pin_refuses_yaml_typed_plain_pins` changes:
    - `True` and `False` are in the accepted list.
    - A real branch `True` on origin gives `True	branch`.
    - `true`, `TRUE`, `false` and `FALSE` are added to the refused list, each naming the bool and the checkout `True`/`False`.
  - Parser table (`test_repos_entries_parser_table`) gains ` True` → `True` plain and ` false` → `false` plain.
  - ADR-0019 no longer lists every bool among the values whose reading changes the text. It now says a bool other than `True` or `False` is refused, and lists `True` and `False` among the values accepted unquoted. — `docs/decisions/0019-repo-pin-verb.md:52-61`

The finding's box was ticked by hand in the `## Local Review` entry, because `review_progress.sh findings` does not read a post-publish Local Review.

Not changed: the `^\.[0-9_]+` float pattern. PyYAML 6 uses `\.[0-9][0-9_]*`. Aligning them is not a one-character change, which is what the handoff allowed. The difference only refuses `._<digits>`-style values, and no git ref can start with `.`.

### Parser input table additions (repo_pin column)
| Input | Value | Form | repo_pin |
|-------|-------|------|----------|
| ` True` (new) | `True` | plain | ref (str() gives `True`) |
| ` false` (new) | `false` | plain | refused: the bool False, checks out `False` |

### Checks
- PyYAML 6.0.3 cross-check (system python3, `safe_load` + `str()`) on 58,758 plain values: every bool spelling in every case, random strings over digits, `._-+eExXbBoO:abfTrueFalsNn~`, and random decimals.
  - No accepted value changes under `str()`.
  - Every "would check out X" claim matches PyYAML's `str()`.
  - The bool branch now refuses all 16 other spellings and accepts only `True` and `False`, the only two it was wrongly refusing.
  - Null: `~`, `null`, `Null` and `NULL` become `None` and stay refused. `None` itself is a string and is accepted.
  - The remaining false refusals:
    - 515 floats, all with more than 15 significant digits (refused by design);
    - `._0`, `._7` and `.__` (the pattern difference above).
- `test_ros2_colcon.sh`: 504 passed, 0 failed.
- Pre-commit over `main...HEAD` (local `main` = origin/main `38119e32`), no SKIP, identity sourced: all hooks passed (rc=0), including `validate-script-tests`, `check-design-anchors`, `shellcheck` and the adapter contract check.

## Local Review
**Status**: complete
**When**: 2026-11-12 19:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a8f506ccaa4d38400, resume 1 of 3)

**PR**: #456 at `8d563c2d`
**Depth**: Deep (reason: fix-round re-review; the whole-diff tier is unchanged, the change extends the ADR-0011 adapter contract and adds ADR-0019)
**Must-fix**: 0 | **Suggestions**: 0

Scope: the `True`/`False` finding of the Local Review at `33cbccd7`, its fix 8fc482b9, and the merge of main at 556ead1b. Cross-model reviewers were not dispatched, per the handoff.

**Checks:**
- test_ros2_colcon: 504 passed, 0 failed.
- test_adapter: 147 passed, 0 failed.
- test_commit_identity, which came in with the merge: 93 passed, 0 failed.
- `check_design_anchors.sh`: rc 0.

**The fix against PyYAML 6.0.3:** the 459,456 values from last round were re-run through the re-extracted function, plus every case variant of each bool word.
- `True` and `False` are now accepted.
- All 16 other PyYAML bool spellings are refused, and each message names the right `str()` (`True` or `False`). The spellings are `yes Yes YES true TRUE on On ON` and `no No NO false FALSE off Off OFF`.
- Mixed case such as `tRUE` and `yES` is a string in PyYAML and is accepted.
- No "would check out X" claim differs from PyYAML.
- The only accepted value `str()` changes is `2024-01-01T00:00:00Z`, which no git ref can hold.
- The only false refusals left are the `._0`-style values (left as is, per the handoff) and floats of more than 15 significant digits (refused by design).

**ADR-0019:** the wording now says "a bool other than `True` or `False`" and lists `True` and `False` among the values accepted unquoted. This matches the code.

**Merge 556ead1b:**
- It was checked against an automatic re-merge of its parents (`git merge-tree 61fa5323 38119e32`). The only difference is the conflict in `docs/design.md`'s change-log table: the #455 row (914) is kept, and the #429 row follows it.
- The #429 row's line count changed from 917 to 921. That matches `wc -l` at 556ead1b and at HEAD (921). Main's own count at 38119e32 was 914, so main's row is still true.
- Nothing else was hand-edited.

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-11-12 20:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a106241f8d2e28d79, resume 1 of 3)

**PR**: #456 at `4430a0ec`
**Sources**: 2 (Local Review @ `8d563c2` (covers 4430a0ec via bookkeeping), verdict approved, 0 must-fix, 0 suggestions; CI rollup). Copilot review skipped (disabled for quota); no GitHub reviews or conversation comments.
**Cross-source confirmations**: 0
**CI**: pending (Validate Documentation passes in both runs; Validate Adapter Contract, ros-manifest tests and Lint (pre-commit) still running in both runs 43341955028 and 43341948474; no failures)

Accounting of every earlier finding box on this diff:
- Integrated Review at `d0eb4a84`: all three findings ticked, fixed in d4a7750b, 7127cc81 and 942a442c (Implementation at `942a442c`).
- Local Review (Pre-Push) at `3ab6be9`: its three open boxes are the same three suggestions that Integrated Review ruled on. The `sources` helper lists them as stale, because code changed since, and they are closed by that ruling and its fixes.
- Local Review at `6807c9f4`: the must-fix false refusal of round-tripping numbers was fixed in e361588d. The box was ticked by hand, because `review_progress.sh findings` does not read a post-publish Local Review.
- Local Review at `33cbccd7`: the must-fix false refusal of unquoted `True`/`False` was fixed in 8fc482b9. The box was ticked by hand, for the same reason.
- Local Review at `8d563c2d`: approved. Its only box is the "No issues found. LGTM." placeholder, not a finding (see False positives).
- Local Review (Pre-Push) at `a6c2d2f`: part 1 / PR #445, out of scope.

Deliberately left unchanged, recorded by the last two rounds:
- The float pattern refuses `._<digits>` values. No git ref can start with `.`.
- Floats of more than 15 significant digits are refused by design.
- Neither is an open finding.

### Findings

### False positives
- (Local Review @ `8d563c2`) "No issues found. LGTM." appears as an unchecked box. It is the approved review's empty-findings placeholder, not a defect, so there is nothing to act on.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 21:31 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

Merge (Recommended)

## Plan Authored
**Status**: complete
**When**: 2026-11-12 21:37 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-429/plan.md` at `92fe4a93`

Revision after the verb merged (pull request 456). The plan marks it merged and re-checks 2a steps 3 to 8 and 2b steps 1 to 6 against main with files and lines. Order for this worktree: 2a next, then 2b. Adjustments: `repo_pin` takes `--layer` and its refusals and stderr note are passed through; the merge cross-check applies to the owning pull request only; the 2a tests use real `.repos` pins instead of a stub adapter type; 2b's Scope rewrite also drops a sentence issue 437 made false. One small open question (the merge cleanup's `git pull --ff-only`). No premise is gone; no issue opened.

## Plan Review
**Status**: complete
**When**: 2026-11-12 21:39 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #429 — run-issue: drive an issue in a package repository of a multi-repository project
**Plan**: `.agent/work-plans/issue-429/plan.md` at `92fe4a93`
**Branch**: `feature/issue-429`

Scope of this review: the "Revision of 2026-11-12" refresh (remaining 2a steps 3-8, 2b steps 1-6, the order 2a then 2b) against main at `b151b741` (= `origin/main` now). Merged parts (445, 456) and design settled by the 2026-11-10 review are not reopened. Owner direction read on the issue (comment of 2026-11-10): a package pull request takes its base from the manifest pin, not GitHub's default branch.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | 2a rest about 11 files / 450 lines, 2b about 8 / 300; built in order in one worktree. The reasons for 2a first (riskier mechanism settles first; the end-to-end case written once with the base step; the Scope text written once) hold. |
| Issue alignment | Good | Base comes only from `repo_pin` (or an explicit `--base`), never `origin/HEAD` or the forge: matches the owner's comment. Serves, as checked: `README.md#easy-to-use`, `README.md#flexibility`; design `docs/design.md#worktrees`, `docs/design.md#review-loop-and-timeline` (`#merge-gate`). |
| File targeting | Good | Every cited line re-checked and correct: `adapter` 26/71/114-130; ros2_colcon `adapter.sh` 744-834 (`worktree_repos` prints `<layer>_ws/src/<pkg>`), 1082 (`adapter_repo_pin`); `dispatch_phase.sh` 35-38, 306, 316, 514, 660; `_resolve_work_plans_dir.sh` 152; `_worktree_helpers.sh` 416-422, 430-451 (end-anchored `layer=` at 444, still the only `layer=` reader, `WT_MANIFEST_LAYER` read nowhere else), 550, 723, 752-834; `worktree_create.sh` 256, 399-410, 770-784, 804, 814, 846, 1017-1020, mktemp at 1097/1138 vs `run_script_tests.sh` 348 citing 1091,1132; `merge_pr.sh` 485-523, 497, 504-506, 535, 545, 675, 689-704, 717, 1548-1660, 1565-1572, 1580, 1625; `progress_append.sh` 94; run-issue SKILL.md 4, 83, 671-690, 826-829, 908-932 (927-928 sentence present); `docs/design.md` 476-478 ("lines 839 and 893"); `test_package_issue_loop.sh` 682 lines, cases 1-10 from 166, `.repos` pins `main` at 100; `test_merge_pr_gate.sh` 522. Finding 3 on where two new values are stored. |
| Consequences | Needs work | ADR route for the `base=` header field (finding 1); stale ADR-0011 wording left in live sections (finding 2). |
| Principle alignment | Good | Strict start path ("start limits strict"), tests named per refusal, prior art (parent path read and rejected; `wt_fetch_named_branch`/`wt_add_new_branch` reused), one rule for the cross-check scope. |
| ADR compliance | Needs work | ADR-0008 as applied by 456/ADR-0019: step 5 still says "ADR-0012's manifest paragraph ... change in 2a" (finding 1). ADR-0011/0012/0019 otherwise respected: `_pr_base.sh` names no type and calls the verb. |
| ROS conventions | N/A | Workspace plan. |

Checked per kind and answer of `repo_pin` (code at ros2_colcon `adapter.sh` 1025-1185): `branch` -> the base, and creation's strict path then fetches `origin/<base>` (`wt_fetch_named_branch`) and refuses absent/unknown even with `--allow-unverified-branch` (the `else` arm of `_wt_add_repo` is reached in that mode too, since `wt_lookup_for_new_branch` returns 1 there, so the base path still runs and still refuses offline: consistent). `tag`, `commit`, `unknown` -> refuse naming it, `--base` offered. Exit 1 (no `version:`, YAML-retyped value, stray quote/backslash/CR, unknown repo, ambiguous layers, unknown layer) -> printed verbatim, exit 2; `--layer` always passed, so the ambiguity refusal cannot arise for a package issue. Offline `NOTE ... (unverified)` -> passed through, creation decides ("creation wins"). The repository name rule is sound: `--package-repos` names are the `src/` directory names, and the `.repos` parser (`_rc_repos_entries`, key pattern `[A-Za-z0-9_.-]+`) has no nested keys, so the last path component equals the pin's key. Cross-check scope (owning `feature/issue-N` only) is right: `base=` describes the owning entry only.

### Findings

1. **[ADR compliance]** (should-fix) Step 5 and the Files table say ADR-0012's manifest paragraph changes in 2a. ADR-0012 line 65 lists the header as (`project`, `issue`, `layer`); adding `base` and "the base decides the start point" is decision text, which ADR-0008 (as 456 applied it: ADR-0019 says adding to a decision's text "is a new ADR") forbids editing in place. Resolution: decide the route in the plan: record the header field and start-point rule in `docs/design.md#worktrees` (plus a cross-reference addendum in ADR-0012, ADR-0008's permitted form), or a new ADR if the owner wants it as a decision. ADR-0019 already states the start point comes from the pin (its Consequences), so a design-doc entry plus addendum is probably enough.
2. **[Consequences]** (minor) Live (non-record) sections still say ADR-0011 is amended: Principles "Keep one current design" (557), ADR table 0011/0012 row (577), Consequences row "repo_pin is a required verb" (592), Decision 5 (608). Also step 8's "a stub adapter type in the sandbox reports each kind" and Estimated Scope's "2a about 16 files, 600 lines" contradict the revision table. Resolution: mark those as superseded or update them to ADR-0019 / real `.repos` pins / 11 files.
3. **[File targeting]** (minor) `merge_pr.sh` scan: the plan saves `PKG_OWN_REL` (2b.1) and reads `base=` (2a.7) "at the match / beside the other header fields", but matches are collected in `_PKG_MATCHES` (tab tuples, 521) and filtered by `--project` after the match; a scalar set at the match can be overwritten by a later manifest. Resolution: carry both as extra fields of the `_PKG_MATCHES` tuple and read them at line 530 with `PKG_WT_DIR`.
4. **[Issue alignment]** (minor) A part-1 worktree with no `base=` asks `dispatch_phase.sh base` on resume, but nothing writes `base=` into its header, so the merge cross-check stays silent for it and a `--base` override given then is never checked on origin (the strict path runs only for a new branch). Resolution: either have `base` write the header field when the worktree exists and has none (after a `git ls-remote --heads` check), or state the gap in the plan as accepted.
5. **[Issue alignment]** (minor) What `dispatch_phase.sh base` prints/returns for a workspace or single-repository issue is unstated ("unchanged" only). Resolution: one line (e.g. prints nothing, exit 0; or run-issue calls it only for a qualified ref) and a case in `test_dispatch_phase.sh`.

Open question (merge cleanup `git pull --ff-only` at `merge_pr.sh` 1625, on whatever branch the owning checkout is on): recommendation **change**, not keep. Today, on a branch other than the base with an upstream it fast-forwards an unrelated branch and prints "synced" (a misleading success); on a branch with no upstream, a detached HEAD (vcstool on a tag/commit pin) or a dirty tree it marks the cleanup incomplete for a non-problem. `adapter_sync` (ros2_colcon `adapter.sh` 599-630) already pulls only when clean and on the pinned branch and fetches otherwise; one rule for both is "Keep one current design". After 2a, `baseRefName` is already in `_head_json`, so the change is a few lines: pull `--ff-only` only when the checkout is clean and on `baseRefName`; otherwise `git fetch` and say "on <x>, not the base <y>: fetched only", without marking the cleanup incomplete; an empty `baseRefName` fetches only. Place it in 2a with step 7 (it needs `baseRefName`) and rewrite 2b.3(d) to pin the new behaviour. The host decides.

### Summary

The refresh is accurate: every "what changed" claim and line citation checked out against main, the base comes only from the manifest pin through `repo_pin` with every kind, refusal and the offline note handled, and the cross-check scope is right. One rule conflict (editing ADR-0012's decision text, which 456 itself avoided for ADR-0011) and a few stale or unstated points need small plan edits before 2a starts; no redesign.

### Recommended Actions

- [ ] Choose the ADR route for `base=` and the start point (design doc + ADR-0012 addendum, or a new ADR); update step 5, the Files table and the ADR table (finding 1)
- [ ] Update or mark superseded the stale ADR-0011 / stub-adapter / 16-file statements (finding 2)
- [ ] Carry `PKG_OWN_REL` and the header `base=` in the `_PKG_MATCHES` tuple (finding 3)
- [ ] Decide `base=` back-fill for part-1 worktrees or state the gap (finding 4)
- [ ] State `dispatch_phase.sh base` behaviour for non-package issues, with a test (finding 5)
- [ ] Host: decide the cleanup-pull question (recommended: pull only on `baseRefName`, fetch otherwise; in 2a)

## Checkpoint
**Status**: complete
**When**: 2026-11-12 21:40 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (plan review verdict needs-work, small text edits only; first revise at this checkpoint since the last proceed)
**After**: plan
**Decision**: revise

Revise the plan for the review's five findings, with these host decisions: (1) the base= field and the start-point rule are recorded in docs/design.md#worktrees with a cross-reference addendum in ADR-0012, not by editing ADR-0012's decision text and not as a new ADR; (2) remove the stale "ADR-0011 amended", stub-adapter and size statements; (3) PKG_OWN_REL and the header's base= travel inside the _PKG_MATCHES record; (4) a worktree with no base= gets the field written on resume, and a --base given on resume is checked on origin; (5) say what dispatch_phase.sh base prints for a workspace or single-repository issue, with a test. Open question decided: change the merge cleanup's pull. Pull --ff-only only when the owning checkout is clean and on the pull request's base branch; otherwise fetch and print "fetched only" without marking the cleanup incomplete; an empty base also means fetch only. It goes in 2a next to the cross-check step, and 2b's cleanup test pins the new behaviour.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 21:43 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-429/plan.md` at `6cba9799`

Revision for the plan review (needs-work) and the host's checkpoint. The header field and start-point rule are recorded in the design (Worktrees) with an ADR-0012 cross-reference addendum only; stale ADR-0011, stub-adapter and size statements are corrected; the owning-checkout path and the header base travel in the `_PKG_MATCHES` record; a worktree with no base gets it written on resume after an origin check; `dispatch_phase.sh base` prints nothing for an issue with no package base, with a test; and the cleanup pull runs only when the owning checkout is clean and on the pull request's base (otherwise fetch only), in 2a, pinned by 2b's case (d).

## Plan Review
**Status**: complete
**When**: 2026-11-12 21:44 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #429 — run-issue: drive an issue in a package repository of a multi-repository project
**Plan**: `.agent/work-plans/issue-429/plan.md` at `6cba9799`
**Branch**: `feature/issue-429`

Convergence review of the revision for the previous Plan Review (needs-work) and the host's checkpoint (revise, six decisions). Code on the branch equals main at `b151b741`. Merged parts (445, 456) and earlier-settled design not reopened.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: 2a's rest, then 2b, in this worktree. |
| Issue alignment | Good | Serves, as checked: `README.md#easy-to-use`, `README.md#flexibility`; design `docs/design.md#worktrees`, `docs/design.md#review-loop-and-timeline` (`#merge-gate`). Base still comes only from the pin or `--base` (owner comment of 2026-11-10). Finding 3. |
| File targeting | Needs work | Pull-rule test is placed in the wrong suite and an existing assertion it breaks is not listed (finding 1). |
| Consequences | Good | Decision 1 route reflected in step 5, Files, ADR and Consequences tables. Banner (finding 2). |
| Principle alignment | Good | Strict resume write-back (refuse, write nothing) fits "start limits strict". |
| ADR compliance | Good | ADR-0012 decision text and its line-65 header list untouched; addendum only (ADR-0008); no new ADR. |
| ROS conventions | N/A | Workspace plan. |

Decisions applied, each checked in plan.md: (1) step 5 (395-398), Files row 560, ADR row 613, Consequences row 629: applied. (2) Stale text: "ADR-0011 amended" survives only in the record heading of step 2 with its bracketed correction (366); "stub adapter" only negated (262, 424); sizes say 11 files / 500 lines with the 16/600 figure explained (217, 244, 675): applied. (3) `_PKG_MATCHES` carries `PKG_OWN_REL` and `base=` (2a.7 row 261, 2b.1 439-445): applied; the `-` placeholder is sound: the record is built once (`merge_pr.sh` 521) and read only at 527 (ambiguity message) and 533 (`PKG_WT_DIR`/`PKG_WT_PROJECT`/`PKG_WT_ISSUE`), no reader outside `merge_pr.sh` (grep of `.agent`), a tab `IFS` is whitespace so empty fields do collapse (today's `_hdr_project`/`_hdr_issue` already could), and `-` cannot be a real branch, project or relative path. Mapping back at both reads covers every reader. (4) Step 6 (401-407): `wt_set_manifest_base` beside `wt_write_manifest` (`_worktree_helpers.sh` 416-422), origin check via `wt_bounded_git` (exists, 476), refuse and write nothing when absent or unknown, differing `--base` refused; consistent with step 3's "header first" rule and with step 5's un-anchored `layer=` reader (an appended ` base=` would otherwise blank `WT_MANIFEST_LAYER`, 444). Consequence accepted by the decision: an offline resume of a part-1 worktree stops at step 1. (5) Step 6 (407-410) and step 8 (427-428): applied, but see finding 3. (6) Step 7 (413-421): pull only when clean and on `baseRefName`, else fetch with "fetched only: <why>", not incomplete; failed pull or fetch still incomplete; empty base fetch only; 1742 untouched; matches `merge_pr.sh` 1624-1631 and `_OWN_ORIGIN` (1569) as the owning repository's own checkout. Note: `adapter_sync` (ros2_colcon `adapter.sh` 614-617) skips a dirty checkout outright rather than fetching, so "the rule adapter_sync already follows" is approximate; fetching a dirty checkout is harmless.

Nothing the previous review confirmed has regressed: the revision table's citations (`merge_pr.sh` 485-535, 545, 1548-1660; `_worktree_helpers.sh` 416-451) re-read and still correct.

### Findings

1. **[File targeting]** (should-fix) The pull-rule case does not belong in `test_merge_pr_gate.sh`: that suite tests the gate, and its stub stops a run at the merge by default (`GH_MERGE_EXIT=1`, line 181). The package cleanup (Step 4) is tested in `test_merge_pr.sh` (sibling, sweep, banner and sync cases, 295-611), and its `write_pr_view_fixture` (139-144) writes no `baseRefName`. After 2a's rule every package case there has an empty base and fetches only, so `test_own_repo_sync_failure_is_reported` (394-421; asserts "Could not fast-forward owner/pkg_a" and "cleanup incomplete") fails. Resolution: put the pull-rule case in `test_merge_pr.sh` beside that test; give `write_pr_view_fixture` a `baseRefName` (default `main`, the sandbox origin's branch) so the existing case keeps pinning a failed pull; add `test_merge_pr.sh` to 2a's Files row and step 8. Likewise 2b.3's cleanup cases (a)-(d), listed under `test_merge_pr_gate.sh` (Files row 562), fit `test_merge_pr.sh`, where (b)/(c)-like cases already exist (`test_sibling_pr_open_keeps_worktree` 295, `test_sweep_reports_unmerged_local_branch` 524); check before adding duplicates.
2. **[Consequences]** (minor) After a fetch-only cleanup the final banner still prints "merged, cleaned up, and synced" (`merge_pr.sh` 1759), the misleading success the rule set out to remove. Resolution: one line in step 7: the banner says the checkout was fetched only (or the step accepts it explicitly); the case in finding 1 asserts it.
3. **[Issue alignment]** (minor) Step 6 lists "a bare number" among the no-base cases, but `resolve_issue_dir` (`dispatch_phase.sh` 306) maps a unique bare number to a package worktree's owning checkout; `base` would then print nothing and the handoff would drop `base=` for a package issue. Resolution: decide "no base" by the resolved worktree (no manifest, or a lone `.` entry) and pre-creation mode (no `--layer`), not by the form of the ref.
4. **[File targeting]** (nit) Files row 559 (2a tests) still lists `test_adapter.sh` and `test_ros2_colcon.sh` as edited ("Verb" cases merged in 456) and omits `test_dispatch_phase.sh`; step 8 names `test_dispatch_phase.sh` both as gaining a case and as unchanged (427, 431). Resolution: fix the row and the list when 2a starts.

### Summary

All six checkpoint decisions are in the plan as decided and agree with each other and with main; the `-` placeholder, the resume write-back and the pull rule are sound. The pull-rule test is aimed at the wrong suite and misses an existing assertion it breaks; that and three smaller points are edits to make as 2a starts, not a reason for another plan round.

### Recommended Actions

- [ ] Move the pull-rule case to `test_merge_pr.sh`; add `baseRefName` to `write_pr_view_fixture`; list the suite in 2a (finding 1)
- [ ] State the final banner after a fetch-only cleanup (finding 2)
- [ ] Key "no package base" on the resolved worktree, not on a bare number (finding 3)
- [ ] Correct the 2a tests row and step 8's suite list (finding 4)

## Checkpoint
**Status**: complete
**When**: 2026-11-12 21:45 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (plan review verdict ready; its four notes are text edits the review says to make as 2a starts)
**After**: plan
**Decision**: proceed

Proceed with 2a's remaining steps (the base-branch mechanism), then 2b as its own pull request. The implementer applies the review's four notes: the pull-rule test goes in test_merge_pr.sh with a baseRefName in write_pr_view_fixture (not test_merge_pr_gate.sh); the final banner says what happened after a fetch-only cleanup; "no base" is decided by the worktree a ref resolves to, not by how the ref is written; the Files table and step 8 are corrected.

## Implementation
**Status**: complete
**When**: 2026-11-12 22:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-429 at `08db856f`

Pull request 2a's remaining steps (3 to 8): the base branch of a package pull request. 2b (the gate, the end-to-end test, the Scope text) is not started.

**Commits**: 796ad13a (strict start path, `--base`, header field), 9ade367e (`dispatch_phase.sh base`, `_pr_base.sh`, handoff `base=`, run-issue and start-task text), fb92b220 (`merge_pr.sh` cross-check and cleanup pull rule), 0bdf1abe (design, ADR-0012 addendum, script reference), 1ff0ac0c (plan corrections), 08db856f (Table 1 mode count)

### What changed
- `_worktree_helpers.sh`: `_wt_add_repo` takes a fifth argument, the base. A new owning branch starts from `origin/<base>` fetched now, `--no-track`. If origin lacks the base or does not answer, it stops having made nothing, also with `--allow-unverified-branch`. The local `<base>` is never used. `wt_write_manifest` writes ` base=<b>` when given. `wt_read_manifest` reads `layer=` unanchored and sets `WT_MANIFEST_BASE`. New `wt_set_manifest_base` replaces the header line in one rename, and refuses a different recorded base.
- `worktree_create.sh --base <branch>`: only with `--layer`. It is refused with `--parent-issue`, for an invalid name, and when no entry is on `feature/issue-N`. It is passed to the owning entry only. The draft-PR message points at publish. `run_script_tests.sh` re-cites the two `/tmp` mktemp lines (now 1148 and 1189).
- `_pr_base.sh` (new, sourced) `pr_base_for`, in order: the recorded `base=`; then `--base`; then `adapter repo_pin <repo> --layer <l>` when its kind is `branch`. A tag, commit or unknown pin refuses with "<repo> is pinned at <ref> (<kind>); only a branch can be a base. Pass --base <branch>.". An adapter exit 1 shows the adapter's message, then "none is guessed", exit 2. The NOTE "unverified" passes through.
- `dispatch_phase.sh base`: decided by the resolved worktree.
  - A package worktree: the recorded base. With none recorded, the pin or `--base`, checked with `wt_bounded_git ls-remote` in the owning checkout, then written; absent or no answer refuses and writes nothing.
  - Any other worktree: nothing, exit 0; `--base`/`--layer` refused.
  - No worktree yet: the owning entry from `adapter worktree_repos` gives the directory name.
  - The handoff prints `base=` after `package_worktree=` when recorded.
- `merge_pr.sh`:
  - `_PKG_MATCHES` carries `base=` as a fourth field, `-` for empty, mapped back at both reads.
  - `_head_json` adds `baseRefName`.
  - For `feature/issue-N` only, a differing or unreadable base is a gate reason.
  - Step 4 pulls the owning checkout only when it is clean and on the PR's base. Otherwise it fetches (bounded) and prints "fetched only: <why>", not incomplete; the banner says the checkout was fetched only.
- `run-issue/SKILL.md`: usage `--base`; step 1 runs `base` before `/start-task` and passes `--base` with `--layer`/`--package-repos`; publish passes `-R <owner/repo> --base <base>`. `start-task/SKILL.md`: `--base` in the creation-only list.
- Docs: `docs/design.md#worktrees` Base branch bullet; change-log row; refreshed `merge_pr.sh` and `dispatch_phase.sh` citations in the Records bullet and mechanism 1; Table 1's mode count. ADR-0012 cross-reference addendum (Status and References), decision text unchanged. Script reference rows.

### The four plan-review notes
1. The cleanup pull-rule test is in `test_merge_pr.sh` (`test_own_repo_pulls_only_on_the_base`). `write_pr_view_fixture` defaults `baseRefName` to `main`. `test_own_repo_sync_failure_is_reported` now also asserts a pull was attempted (not fetch-only), so it still pins a failed pull on the base. Nothing was added to `test_merge_pr_gate.sh`.
2. The banner after a fetch-only cleanup: "merged and cleaned up; <repo>'s checkout was fetched only, not fast-forwarded (<why>)". It is asserted for all four fetch-only setups.
3. "No base" is keyed on the resolved worktree. A bare `11` resolving to the package worktree prints `base=pinned` (tested).
4. The plan's Files table and step 8 are corrected in 1ff0ac0c, with steps 6 and 7 annotated as built.

### Deviations from the plan
- `start-task/SKILL.md` edited: its creation-only flag list would otherwise send `--base` to `worktree_enter.sh` without saying so.
- The `merge_pr.sh` and `dispatch_phase.sh` line citations in `docs/design.md`'s Records bullet and mechanism 1 were refreshed here, not left to 2b, because this change moved them. The mechanism-1 `dispatch_phase.sh` numbers were already off by 3 on main.
- `dispatch_phase.sh base` refuses a qualified ref with no worktree and no `--layer`/`--package-repos` (exit 2) rather than printing nothing. The plan was silent on that case, and "nothing" would be a silent wrong answer for a package issue.
- A recorded base whose `baseRefName` cannot be read is a gate reason, not silence.
- The resume origin check passes git's message to `wt_fetch_why` with a "git ls-remote exited N" fallback, so the wording is true for ls-remote.

### Checks
- Suites run directly:
  - `test_worktree_create.sh` 71/0
  - `test_package_issue_loop.sh` 180/0
  - `test_dispatch_phase.sh` 148/0
  - `test_merge_pr.sh` 131/0
  - `test_merge_pr_gate.sh` 121/0 (unchanged suite)
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP, identity sourced: every hook passed, rc 0, including `validate-script-tests`, shellcheck and check-design-anchors. The branch touches `.agent/scripts/_*.sh` helpers and `run_script_tests.sh`, both full-run triggers, so that hook ran every suite. Its per-suite output is hidden by pre-commit on a pass.
- Each new behaviour has a test that fails on the old code. Examples: the base start point (old code starts from origin/main), the `base` subcommand, `base=` in the handoff, fetch-only and its banner, the cross-check reason.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 22:17 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-429 at `69b6072a`
**Base**: main
**Depth**: Deep (reason: 17 files, +1414/-95; new and changed worktree/merge scripts and run-issue/start-task skills, cross-layer: creation, dispatch, merge)
**Must-fix**: 2 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Round correction by the host: `review_progress.sh round` counts 7 because the pre-push reviews of this issue's merged pull requests 445 and 456 share this timeline (tracked as issue 459). The code beyond main (`git diff main...HEAD`) had never been reviewed, so this is round 1 of a new change: full Deep depth, cold read of the whole diff, cross-model reviewers run, verdict script given `--round 1`.

Specialists: static analysis (pre-commit shellcheck on the 9 changed .sh files: pass); governance and plan drift (lead); Claude adversarial (fresh subagent); cross-model gemini (via agy) and codex, both completed; Copilot skipped (disabled for quota). Suites run: test_worktree_create 71/0, test_package_issue_loop 180/0, test_dispatch_phase 148/0, test_merge_pr 131/0; no sleep or wall-clock tuning in the new cases, no leftover processes.

Implementation deviations judged: start-task SKILL.md edit, citation refresh, qualified-ref refusal with no worktree, unreadable baseRefName as a gate reason, wt_fetch_why fallback: all accepted. The stated gap (`base` ignores `--package-repos` for an existing worktree) is suggestion 5.

### Findings
- [x] (must-fix) Resume write-back records the pin as `base=` without checking the owning branch started there: a worktree made without `--base` (every part-1 worktree, or `/start-task --layer l1 --package-repos pkg_a` directly) starts `feature/issue-N` at origin's default branch; `base` then writes `base=<pin>` after only an `ls-remote`, publish targets the pin and carries default-only commits, and the merge cross-check agrees. Check ancestry against origin/<base> before recording (or refuse), and decide whether a package worktree may be created without `--base` — `.agent/scripts/dispatch_phase.sh:789-807`
- [x] (must-fix) Cleanup `pull --ff-only` follows the checkout's configured upstream, not origin's `$PR_BASE_REF`: a base branch tracking another remote/branch is moved to unrelated history while the line says "<base> fast-forwarded"; one with no upstream fails and marks the cleanup incomplete. Pull `origin "$PR_BASE_REF"` explicitly; test both upstream setups (codex, adversarial) — `.agent/scripts/merge_pr.sh:1678`
- [x] (suggestion) A legacy `project/` worktree's header says `project=project` (`${PROJECT_NAME:-project}`); resume passes `--project project` to the adapter, which refuses "not registered", and step 1 stops. Pass the header's project only when it is registered — `.agent/scripts/dispatch_phase.sh:786`
- [x] (suggestion) The failed-fetch branch of the cleanup ("Could not fetch origin ... so no pull was due", incomplete) has no test; add one with a dead origin and a checkout off the base — `.agent/scripts/tests/test_merge_pr.sh`
- [x] (suggestion) A pin of kind `unknown` (offline with no remote-tracking ref, so repo_pin's NOTE says unverified) is refused as "pinned at <ref> (unknown); only a branch can be a base": the cause may be an unanswered origin, not a non-branch; word it as "kind could not be established" and suggest retrying online — `.agent/scripts/_pr_base.sh:109-111`
- [x] (suggestion) `base` for an existing package worktree ignores `--package-repos` without a message, and the header comment does not say so (the implementer's stated gap): compare it with the manifest and refuse a mismatch, or say it is ignored — `.agent/scripts/dispatch_phase.sh:26-55`
- [x] (suggestion) docs/design.md Table 1 `dispatch_phase.sh` row was edited but its line citations (167, 228-277, 452, 581, 669, 700) are stale (`resolve_worktree` is now at 269; they were already off on main) — `docs/design.md`

## Checkpoint
**Status**: complete
**When**: 2026-11-12 22:18 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (first review of the base mechanism's diff, two must-fix; the round limit is reached only because the counter carries the merged pull requests' reviews, issue 459; first host address for this pull request, the owner's merge of pull request 456 having come between)
**After**: rounds
**Decision**: address

Fix all seven findings. Host decisions on finding 1 (a resumed worktree recorded the pin as base= without checking the branch started there): (a) nothing is recorded silently. On resume with no base=, the candidate base (an explicit --base, else the pin) is recorded only after a check that the owning branch carries no foreign history against origin/<base>: every commit in origin/<base>..HEAD that is also reachable from another branch on origin (other than the issue branch itself) is foreign; if any exists, refuse, name the count and the branch they come from, and say how to proceed (recreate the worktree, or pass the --base it was really started from). (b) Creating the owning repository's branch in a package worktree always resolves a base: an explicit --base, else the manifest pin through pr_base_for; if neither gives a branch, creation refuses and asks for --base. A package worktree is no longer started from origin's default branch by omission. This follows the owner's direction of 2026-11-10 (the base comes from the manifest pin, not GitHub's default branch). Finding 2: pull origin <base> explicitly. Finding 6: refuse a --package-repos that does not match the existing manifest. The other findings as the review states them.

## Implementation
**Status**: complete
**When**: 2026-11-12 22:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-429 at `c7a73165`
**Addressed**: Local Review (Pre-Push) at `69b6072a` (2026-11-12 22:17 -05:00)
**Commits**: d02587c4, be953d46, 517b827e, e2638167, 37c1ad2d, c7a73165

### Actions
- [x] (must-fix 1) Resume no longer records an unchecked base; creation always resolves a base — `.agent/scripts/dispatch_phase.sh` (cmd_base), `.agent/scripts/worktree_create.sh`, `.agent/scripts/_worktree_helpers.sh` (`wt_base_foreign_history`, `WT_ADD_STARTED_FROM_BASE`). (a) The candidate base (`--base`, else the pin) is written only when no commit in `origin/<base>..feature/issue-N` is also on another origin branch (base and the issue branch excluded). One bounded fetch goes into a private ref namespace, removed again; the checkout's remote-tracking refs are untouched. A refusal names the count and the branches (most commits first, ties closest first), says "Recreate the worktree, or pass the --base it was started from", and writes nothing. (b) A package worktree with an owning entry always resolves a base before anything is made (`--base`, else `pr_base_for`); no branch means refuse and ask for `--base`. An owning branch that already exists (locally or on origin) gets `base=` only after the same check, else creation refuses and rolls back with the branch kept. Siblings get no base. Every creation path goes through `worktree_create.sh`: direct, `/start-task`, run-issue step 1.
- [x] (must-fix 2) Cleanup pulls `origin <base>` by name: `pull --ff-only --no-rebase origin "$PR_BASE_REF"` — `.agent/scripts/merge_pr.sh:1678-1680`; test `test_own_repo_pull_takes_origin_base_not_upstream` (upstream origin/pinned, origin/main, none). On the old code it fails 5 assertions: "other" is moved to main's history, "none" is marked incomplete.
- [x] (suggestion 3) Legacy `project=project` header: the header's project is passed to the adapter only when `registry_lookup` finds it — `.agent/scripts/dispatch_phase.sh` cmd_base. Test: owner/pkg_a#14 with a `project=project` header reaches the adapter's answer, not "not registered".
- [x] (suggestion 4) Failed-fetch test: `test_own_repo_failed_fetch_marks_cleanup_incomplete` (origin's bare moved away, URL kept, checkout on `other`) — `.agent/scripts/tests/test_merge_pr.sh`
- [x] (suggestion 5) An unknown pin now gives one of three true messages: origin not asked or not answering (the adapter's "(unverified)" NOTE; retry or `--base`), a name no branch can have, or origin asked with no branch or tag of that name — `.agent/scripts/_pr_base.sh`. Tests for all three are in case 11 of `test_package_issue_loop.sh`.
- [x] (suggestion 6) For an existing package worktree, `--package-repos` must equal the manifest's repositories as a set (order free); a mismatch is refused naming both. Header comment and exit codes updated — `.agent/scripts/dispatch_phase.sh`. Tests: `pkg_b,pkg_a` gives the recorded base; `pkg_a` is refused.
- [x] (suggestion 7) Table 1's `dispatch_phase.sh` row now cites 219, 280-329, 504, 638, 726, 758, 905. Mechanism 1's citations are refreshed to 544, 590, 592, 654, 923 (this pass moved them) — `docs/design.md`

### Finding 1: inputs and results
`wt_base_foreign_history <checkout> <branch> <base>` (unit cases in `test_worktree_create.sh`). Origin has: main = M0 M1; rel = M0 R1; old = M0; ahead = M0 M1 A1; dev2 = M0 M1 D2.

| Branch | Base | Result |
|---|---|---|
| no own commits, from rel | rel | 0, none |
| from rel plus own commits | rel | 0, none |
| from origin main (the reported case) | rel | 1: 1 commit, from main (named first) |
| base is an ancestor of main: from main plus own | old | 1: 1 commit, from main |
| main is an ancestor of the base: from main plus own | ahead | 0 (only its own commit) |
| issue branch pushed to origin, from rel | rel | 0 (its pushed copy is not "another") |
| issue branch pushed to origin, from main | rel | 1 (main's commit; the branch itself not named) |
| two origin branches carry it | rel | 1: 2 commits, "dev2 (2), main (1), ..." |
| base not on origin | nosuch | 2: "origin has no branch 'nosuch'", nothing written |
| no local branch | rel | 3 |
| origin unreachable / fetch fails | rel | 3, git's line; nothing written |
| every case | | no `refs/wt-base-check/` refs left, remote-tracking refs unchanged |

End to end:
- Resume (`test_package_issue_loop.sh` case 13): C (from main before `pinned` moved on; main is an ancestor of pinned) records `pinned`. C14 (from main after main moved past pinned) is refused with "1 commit(s) ... origin's main (1)", header unchanged; with `--base main` (its own commit pushed) `base=main` is recorded. A `--base` origin lacks, a tag pin and a dead origin (bounded, git's "Network is unreachable") each refuse and write nothing.
- Creation (`test_ros2_colcon.sh`):
  - No `--base` gives base=fakefox (the pin), and the branch is at origin/fakefox.
  - A tag pin with no `--base` refuses before anything is made (no directory, no owning or sibling branch); with `--base main` it records main.
  - Siblings only: no base, created.
  - Existing local branch from the pin, with own work: recorded.
  - Existing local branch from main (main past the pin): refused, rolled back, branch kept at its commit, no check refs left; with `--base main`: recorded.
  - Branch on origin only, from the pin: recorded.

### Existing tests changed, and why
- `test_ros2_colcon.sh`: package repositories' origins were unreachable `git@github.com:owner/<pkg>` URLs. Creation now needs a base origin confirms, so they are served offline by a `GIT_SSH_COMMAND` stub from the per-test `fake_remotes/github.com/` (it fails as an unreachable host outside one). origin holds the pin `fakefox` as a branch, and the sandbox copies `_pr_base.sh`. The tests state a base through the pin; none asserts a refusal, since each is about layout or rollback.
- `test_package_issue_loop.sh`:
  - Setup now asserts `base=main` on C and C2 and none on C9. It then strips `base=` from C so C stands in for a pre-field worktree, which keeps the "no base= line" handoff check and case 13 meaningful.
  - The `unknown` expectation is the new message.
  - Case 13's dead-origin check passes `--base pinned` and expects the new "could not check whether ... started from origin's 'pinned'" message.
- `test_worktree_create.sh`, `test_merge_pr.sh`: only additions.
- `run_script_tests.sh` re-cites `worktree_create.sh:1215,1256`.

### Checks
- Suites run directly on the final code: `test_ros2_colcon.sh` 531/0, `test_package_issue_loop.sh` 188/0, `test_worktree_create.sh` 84/0, `test_merge_pr.sh` 150/0. `test_dispatch_phase.sh` 148/0 (run after the last `dispatch_phase.sh` code edit).
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, identity sourced, no SKIP: rc 0, every hook passed. This includes `validate-script-tests`: a shared helper changed, so every suite ran. shellcheck and check-design-anchors passed too.
- Tests that fail on the old code:
  - finding 2: shown, 5 failures with the old pull line.
  - finding 1: the reported-case refusal and the creation base= checks (the old code recorded `pinned` and created with no base).
  - finding 3: the old code passes `--project project` and gets "not registered".
  - finding 5: the old message is "(unknown)".
  - finding 6: the old code ignored the list.
- Finding 4's test pins existing behaviour.

### Notes
- The fetch for the check pulls every origin branch's objects once, on resume or creation over an existing branch only.
- A commit of the issue's own that someone also pushed to another origin branch counts as foreign (conservative: the run refuses and names that branch).
- Table 1's other rows (`worktree_create.sh`, `merge_pr.sh`) cite lines that were already stale before this pass (the table calls itself a dated probe). Only the `dispatch_phase.sh` row was in scope and is now true.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 22:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a3be5b1d6eca4c5d8, resume 1 of 3)

**Branch**: feature/issue-429 at `2d814db9`
**Base**: main
**Depth**: Deep (reason: whole-diff classification, unchanged from round 1: worktree/dispatch/merge scripts and skills, cross-layer)
**Must-fix**: 2 | **Suggestions**: 6
**Round**: 2 | **Ship**: continue — round 2: 2 must-fix include a design/correctness concern (not mechanical)

Round 2 of this diff (the dispatcher counts higher because the merged pull requests 445 and 456 share the timeline, issue 459; the verdict script was given `--round 2`). Scope: round 1's seven findings and the fix diff d02587c4, be953d46, 517b827e, e2638167, 37c1ad2d. Round-2 rule: Deep on the whole diff, so cross-model ran (gemini via agy, codex: both completed); Copilot skipped (disabled for quota); fresh Claude adversarial sub-review ran.

Round 1 findings: 1 (resume records unchecked base) fixed by the foreign-history check and creation always resolving a base, but see must-fix 1 and 2 below; 2 (explicit `pull --ff-only --no-rebase origin <base>`) fixed and tested; 3 (legacy `project=project`), 4 (failed-fetch test), 5 (three true `unknown` messages), 6 (`--package-repos` set compared) and 7 (Table 1 citations) fixed as stated.

Suites run: test_ros2_colcon 531/0, test_worktree_create 84/0, test_package_issue_loop 188/0, test_dispatch_phase 148/0, test_merge_pr 150/0; no `refs/wt-base-check/` refs left in this checkout. The GIT_SSH_COMMAND stub in test_ros2_colcon serves only the sandbox's fake_remotes and fails as unreachable elsewhere; the layout and rollback tests still assert what they did. The comment at test_ros2_colcon.sh:272 still says the fixture origins cannot be reached.

### Findings
- [x] (must-fix) A package worktree with `--parent-issue` and no `--base` now starts from the pin, not the parent: `worktree_create.sh --issue owner/pkg_a#12 --type project --layer l1 --package-repos pkg_a --parent-issue 10` resolves BASE_BRANCH from the pin (the `--base`/`--parent-issue` guard at :354 runs before it), `_wt_add_repo` takes the base path ahead of the parent path, the banner still says "Parent: #10", and base=<pin> is recorded. Before this pass the branch started from feature/issue-10. Refuse the combination or skip pin resolution with a parent (codex, adversarial) — `.agent/scripts/worktree_create.sh:738`
- [x] (must-fix) `wt_base_foreign_history` counts the issue's own commits as foreign when another origin branch also has them: feature/issue-7 from origin/rel plus one own commit, its tip also pushed as feature/issue-12 (a sub-issue branch stacked on it with --parent-issue, or a backup) gives rc=1 "1 commit(s) ... origin's feature/issue-12 (1): it did not start from 'rel'", false, and both resume and creation over the existing branch refuse. This is the host's rule as written, so it needs a decision: e.g. count only commits that another branch has AND that are not descended from the branch's fork point with the base, or word the refusal as "also on <branch>" and offer a way through (adversarial, gemini) — `.agent/scripts/_worktree_helpers.sh:519-536`
- [x] (suggestion) A branch with no history in common with the base passes: an orphan feature/issue-N makes every merge-base empty, every origin branch is skipped, rc=0, and base= is recorded although no pull request can be opened. Require `merge-base <tip> <ns>/<base>` to be non-empty (codex) — `.agent/scripts/_worktree_helpers.sh:529`
- [x] (suggestion) The check's fetch updates the checkout's remote-tracking refs (git's opportunistic update for a command-line refspec), contrary to its header: verified, a clone with no refs/remotes/origin/dev gets one after `fetch origin "+refs/heads/*:refs/wt-base-check/x/*"`. Add `--refmap=`; the "remote-tracking refs are unchanged" test passes on the current code because its clone's refs were already current (adversarial) — `.agent/scripts/_worktree_helpers.sh:507`, `.agent/scripts/tests/test_worktree_create.sh:816` (deferred: falls away: wt_base_foreign_history and its all-branch fetch are removed (host decision); wt_check_named_base fetches only origin/<base> by its own refspec)
- [x] (suggestion) No INT/TERM handling: a Ctrl-C during the merge-base loop of `dispatch_phase.sh base` leaves `refs/wt-base-check/<pid>-<rand>/*` refs that pin objects and show in `--all`; sweep stale ones at the start or trap (adversarial) — `.agent/scripts/_worktree_helpers.sh:500-562` (deferred: falls away: the private refs/wt-base-check refs are no longer made (check removed, host decision))
- [x] (suggestion) `--branch <name>` with `--layer` is not refused, and the owning entry is found by `BRANCH_NAME`: `--branch foo --layer l1 --package-repos pkg_a` finds no owning entry, resolves no base, and feature/issue-N starts from origin's default branch with no base= (adversarial) — `.agent/scripts/worktree_create.sh:735`
- [x] (suggestion) `dispatch_phase.sh base --base ""` is ignored (the pin is used) and `pr_base_for`/`cmd_base` validate with `check-ref-format refs/heads/<b>`, which accepts `-foo` and `HEAD`; use `git check-ref-format --branch` and refuse an empty value, as worktree_create.sh does (gemini) — `.agent/scripts/dispatch_phase.sh:752`, `.agent/scripts/_pr_base.sh:68`
- [x] (suggestion) Test gaps: no case for the foreign-history refusal after sibling worktrees were added (rollback of siblings); case 13's dead-origin resume now passes `--base pinned`, so reading the pin while origin is down and then reaching the check is no longer exercised (adversarial) — `.agent/scripts/tests/test_ros2_colcon.sh`, `.agent/scripts/tests/test_package_issue_loop.sh`

## Checkpoint
**Status**: complete
**When**: 2026-11-12 22:51 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 2 of the base mechanism's diff, two must-fix, both from the host's own round-1 decision; second host address in a row at this checkpoint, so the next answer here is the owner's)
**After**: rounds
**Decision**: address

The host withdraws its round-1 decision (a): the foreign-history check (wt_base_foreign_history) is removed, with its fetch of every origin branch and its private refs. It guessed where a branch started and was wrong both ways (the issue's own commits on a stacked or backup branch read as foreign; an orphan branch passed). Replacement, simpler: a worktree with no base= recorded never has one recorded from the pin. On resume, and on creation over an owning branch that already exists, the base must be named with --base; it is recorded after two checks only: the branch exists on origin (bounded), and the issue branch has a common ancestor with origin/<base>. Without --base the run refuses and says so truthfully: the worktree or branch predates base recording, or already existed, so the workspace cannot know where it started; pass --base naming the branch it was started from, or recreate it. Decision (b) stands: creating a NEW owning branch always resolves a base (--base, else the pin; refuse if neither is a branch). Must-fix 1: with --parent-issue the pin is not read; the branch starts from the parent's branch as before this change, and what base= records then follows what the existing sub-issue flow targets (the parent's branch), stated in the entry. Suggestions 6, 7, 8 and the stale comment are fixed as the review states; 3 becomes the common-ancestor check above; 4 and 5 fall away with the removed check (confirm no caller or text still refers to it).

## Implementation
**Status**: complete
**When**: 2026-11-12 23:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a3896df654672786a, resume 1 of 3)

**Branch**: feature/issue-429 at `8e62ad61`
**Addressed**: Local Review (Pre-Push) at `2d814db9` (2026-11-12 22:50 -05:00), under the host's Checkpoint of 2026-11-12 22:51
**Commits**: a0363b19, e10b5348, 77939677, 8e62ad61

### Actions
- [x] Withdrawn check removed (host decision). `wt_base_foreign_history` is gone, along with its fetch of every origin branch, the private `refs/wt-base-check/` refs, its tests and every text about it. Nothing outside this progress timeline still names it (grep for `wt_base_foreign_history`, `WT_FOREIGN` and `wt-base-check`). This also retires must-fix 2 — `.agent/scripts/_worktree_helpers.sh`
- [x] Replacement rule: a base is named and checked. A worktree with no recorded `base=`, or an owning branch that already existed at creation, never gets the pin.
  - The base must be named with `--base`. It is recorded after `wt_check_named_base`: origin has the branch (`wt_fetch_named_branch`, bounded), and the issue branch has a common ancestor with `origin/<base>` (suggestion 3).
  - Without `--base`, the run refuses and writes nothing. The message says the worktree predates base recording, or the branch already existed, so the workspace cannot know where it started; it asks for `--base` naming that branch, or a recreate.
  - With origin down, the run refuses and writes nothing, giving the whole fetch reason.
  - Code: `dispatch_phase.sh` cmd_base, `worktree_create.sh` manifest write, `_worktree_helpers.sh` `wt_check_named_base`.
- [x] (must-fix 1) `--parent-issue` on a package worktree. The pin is not read, and a new branch starts from the parent's branch as before this change. `base=` records the parent's branch when it is found, which is the existing sub-issue flow's own notion (`check_existing_branch_parent` → `PARENT_BRANCH_FOUND`): a sub-issue's draft PR targets the parent's branch when it is found locally or on origin. The banner's new `Base:` line names the parent's branch. Test: `test_worktree_create_package_parent_issue_starts_from_parent`, where the pin is a tag that would refuse if read. It checks that the branch is at the parent's tip, that both banner lines and `base=feature/issue-10` agree, and that `--base` with `--parent-issue` is still refused — `.agent/scripts/worktree_create.sh`
- [x] (suggestion 4) deferred: falls away with the removed check. `wt_check_named_base` fetches only `origin/<base>`, by its own refspec.
- [x] (suggestion 5) deferred: falls away; no private refs are made any more.
- [x] (suggestion 6) `--branch` with `--layer` is refused, and I chose refusal over resolving a base. `--branch` renames the issue's branch in the one repository a worktree is of, but in a package worktree the adapter names every repository's branch. A custom name therefore matches no entry, and no base could be tied to it. Test: `test_worktree_create_package_refuses_branch_and_empty_base` — `.agent/scripts/worktree_create.sh`
- [x] (suggestion 7) `--base` validation is the same in `pr_base_for`, `cmd_base` and `worktree_create.sh`: `check-ref-format --branch` plus `refs/heads/<b>` (`wt_valid_branch_name`). An empty value is refused, not ignored; `-foo`, `HEAD`, `a..b` and `@{-1}` are refused. Tested in all three paths — `.agent/scripts/_pr_base.sh`, `dispatch_phase.sh`, `worktree_create.sh`
- [x] (suggestion 8) Two test gaps closed:
  - (i) An existing owning branch without `--base`, listed after a sibling: refused, "rolling back 2", the sibling's worktree and branch removed, the existing branch kept (`test_ros2_colcon.sh`).
  - (ii) The pin read while origin is down: `base` prints `base=pinned` with the "(unverified)" note, then creation with origin down refuses with nothing made in either repository (`test_package_issue_loop.sh` case 12).
- [x] The comment at `test_ros2_colcon.sh:272` now says the fixture origins answer.

### Resume: inputs and results (`dispatch_phase.sh base`, the worktree exists)
| header `base=` | `--base` | origin | result |
|---|---|---|---|
| X | none, or X | – | `base=X` |
| X | Y ≠ X | – | refused (records X) |
| none | none | – | refused: "records no base: it was made before base recording ... cannot know which branch ... started from, and does not take the pin". The pin is not read; nothing written |
| none | `""`, `-foo`, `HEAD` | – | refused: not a valid branch name |
| none | B, which origin lacks | answers | refused: "origin has no branch 'B'"; nothing written |
| none | B | down | refused: "could not check --base B ... (whole fetch reason)"; nothing written |
| none | B; orphan issue branch | answers | refused: "has no commit in common with origin's 'B'"; nothing written |
| none | B, on origin, history shared | answers | `base=B` recorded, entries unchanged (also under a `project=project` header) |

### Creation: inputs and results (`worktree_create.sh`, owning branch)
| owning branch | `--base` | `--parent-issue` | result |
|---|---|---|---|
| new | B | no | starts at `origin/B`, `base=B`; refused with nothing made if origin lacks B or is down |
| new | none; pin a branch P | no | starts at `origin/P`, `base=P` |
| new | none; pin a tag, commit or unknown | no | refused before anything is made |
| new | none | yes | pin not read; starts from the parent's branch; `base=<parent>` when found. If the parent is not found it starts from the default branch with the pre-existing WARNING (unchanged sub-issue behaviour) and gets no `base=`, with a note |
| any | B | yes | refused |
| exists (local or origin) | none | no | refused: "already existed ... cannot know ... does not take the pin"; rolled back, siblings too; the branch kept |
| exists | B, origin has it, history shared | no | `base=B` |
| exists | B, which origin lacks; or an orphan branch | no | refused, rolled back |
| exists | B, origin down | no | refused (retry), rolled back |
| exists | none | yes | checked out; no `base=` (a note); a later `base --base` records it |
| `--branch` with `--layer` | – | – | refused, nothing made |
| no owning entry (siblings only) | none | no | no base, as before |

`run-issue` step 1 now passes `--base` to creation only when the owner gave it, never the pin `base` printed; otherwise creation would turn the pin into a "named" base for an existing branch.

### Tests removed or changed
- **Removed** (the check is withdrawn):
  - the `wt_base_foreign_history` edge table in `test_worktree_create.sh`;
  - `test_worktree_create_package_existing_branch_checked_before_base_recorded` in `test_ros2_colcon.sh`;
  - case 13's foreign refusal and its no-leftover-refs check in `test_package_issue_loop.sh`.
- **Replaced by:**
  - the `wt_check_named_base` and `wt_valid_branch_name` input table (`test_worktree_create.sh`);
  - `test_worktree_create_package_existing_branch_needs_named_base`, `..._parent_issue_starts_from_parent` and `..._refuses_branch_and_empty_base` (`test_ros2_colcon.sh`);
  - case 13 rewritten to the resume table above (`test_package_issue_loop.sh`).
- **Changed:** case 13's "origin has the pinned branch: recorded" check now passes `--base pinned`, because recording without a named base is exactly what the new rule forbids. The legacy `project=project` check now records a named `--base`: no adapter call remains on the resume path, so I removed the header-project code that round 1 added.

### Checks
- Suites run directly on the final code, all with 0 failures: `test_worktree_create.sh` rc 0, `test_ros2_colcon.sh` 558/0, `test_package_issue_loop.sh` 194/0, `test_dispatch_phase.sh` 148/0, `test_merge_pr.sh` 150/0.
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, identity sourced, no SKIP: rc 0, every hook passed. That includes `validate-script-tests`, which ran every suite because a shared helper changed.
- Each of these fails on round 2's code:
  - the resume refusal without `--base`, which round 2 recorded from the pin;
  - the parent case, where round 2 read the tag pin and refused;
  - the `--branch` refusal;
  - the empty and `-foo` `--base` values;
  - the existing-branch refusal without `--base`.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 23:17 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a3be5b1d6eca4c5d8, resume 2 of 3)

**Branch**: feature/issue-429 at `0144179c`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round 3 of this diff. The dispatcher counts higher because merged pull requests 445 and 456 share this timeline (issue 459); the verdict script was given `--round 3`.

Scope: round 2's eight findings and the fix diff a0363b19, e10b5348, 77939677.

Cross-model: skipped (round-3 convergence check, per handoff). A fresh Claude adversarial sub-review ran every row of the Implementation entry's resume and creation tables in sandboxes.

Round 2's findings:
- Must-fix 1 (`--parent-issue` overridden by the pin): fixed. The pin is not read; the branch starts from the parent's branch; `base=` records the parent's branch when it is found.
- Must-fix 2 (the issue's own commits counted as foreign): fell away. The host withdrew the history check, and nothing outside `.agent/work-plans` still refers to `wt_base_foreign_history`, `wt-base-check` or `WT_FOREIGN` (grep).
- Suggestion 3 (orphan branch passes): now refused with rc 4, "no commit in common".
- Suggestions 4 and 5 (the history check's fetch and refs): fell away with the check.
- Suggestion 6 (`--branch` with `--layer`): refused before anything is made.
- Suggestion 7 (`--base` values): `''`, `-foo`, `HEAD`, `a..b` and `@{-1}` are refused through `wt_valid_branch_name`.
- Suggestion 8 (test gaps): sibling rollback is tested. The pin read with origin down is case 12. The stale test comment is fixed.

Checked by running:
- Every table row gives the stated result, and each refusal message is true for its input. This covers an existing branch without `--base`, origin down, and a base origin lacks.
- Rollback: a sibling added first, then a refusal. Both repositories are back to `main`, no aggregate directory is left, and the pre-existing branch is kept.
- Two rows start from the default branch: "parent not found" and "exists, none, yes". The first is main's own parent-not-found WARNING path, unchanged. The second checks out the existing branch. In both, the printed Note is true.
- The only thing left behind is a fetched `refs/remotes/origin/<base>` for a base origin has.
- run-issue step 1 and the scripts agree: `--base` goes to creation only when the owner gave it.

No regressions:
- `merge_pr.sh` is unchanged since round 2, so the cleanup pull still names origin's base.
- The unknown-pin messages are unchanged.
- The `--package-repos` comparison is unchanged.
- Table 1's `dispatch_phase.sh` row cites 216 and 277-326, which is where `derive_project_name` and `resolve_worktree` are.

Suites run: test_ros2_colcon 558/0, test_worktree_create 79/0, test_package_issue_loop 194/0, test_dispatch_phase 148/0, test_merge_pr 150/0.

### Findings
- [ ] (suggestion) The rule "an owning branch that already exists needs `--base`, else creation refuses" is stated without its `--parent-issue` exception. Input: an existing local `feature/issue-201` with `--layer l1 --package-repos pkg_a --parent-issue 10`. Result: exit 0, a Note, no `base=`. `--base` cannot be given there either, since it is refused with `--parent-issue`. Add the exception: the existing branch is accepted, no base is recorded, and `dispatch_phase.sh base --base` records one later — `docs/design.md:500-505`, `.claude/skills/start-task/SKILL.md:175`, `.agent/scripts/worktree_create.sh:205-207`

## Checkpoint
**Status**: complete
**When**: 2026-11-12 23:18 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (pre-push review approved at round 3 of this diff, no must-fix; one documentation suggestion goes to triage)
**After**: publish
**Decision**: publish

Round 3 approved after running every row of the two input tables against the real scripts. One suggestion stays open for triage: the rule "an existing owning branch needs --base" is written without its --parent-issue exception in docs/design.md, start-task's SKILL.md and worktree_create.sh's usage text.

## Integrated Review
**Status**: complete
**When**: 2026-11-12 23:18 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #460 at `4c248c51`
**Sources**: 4 (Local Review (Pre-Push) @ `69b6072a` round 1, @ `2d814db9` round 2, @ `0144179c` round 3 (covers 4c248c51 via bookkeeping), CI rollup); Copilot skipped (disabled for quota); no GitHub reviews or comments
**Cross-source confirmations**: 0
**CI**: pending

Scope: the three pre-push reviews after the Checkpoint of 2026-11-12 21:45 (After: plan, Decision: proceed). Rounds 1 (7 findings) and 2 (8 findings) are all ticked, each with its fix or its host decision recorded. The helper also lists stale open boxes in entries at `a6c2d2f`, `3ab6be9` and `8d563c2`: those belong to the merged pull requests 445 and 456 and are out of scope here, not re-triaged. CI at triage time: Validate Documentation passed in both runs, one ros-manifest run passed; Lint (pre-commit), Validate Adapter Contract and the other ros-manifest run had no conclusion yet.

### Findings
- [x] (should-fix, documentation defect, Local Review (Pre-Push) @ `0144179c` covers head via bookkeeping) The rule "an owning branch that already exists needs `--base`, otherwise creation refuses" is written without its `--parent-issue` exception. Verified in code: `worktree_create.sh:955-969` accepts an existing owning branch under `--parent-issue`, records no `base=`, prints a Note, and exits 0; `--base` is refused with `--parent-issue`, so the rule as written cannot be followed there. Under the Quality Standard, documentation that states a rule the code does not follow is a defect, not a nit. Fix in this pull request: add the exception (existing branch accepted, no base recorded, `dispatch_phase.sh base --base` records one later) to all three places — `docs/design.md:500-505`, `.claude/skills/start-task/SKILL.md:175`, `.agent/scripts/worktree_create.sh:205-207`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-12 23:19 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (triage classified the one open finding valid, a documentation defect to fix in this pull request)
**After**: findings
**Decision**: address

Fix in pull request 460: state the --parent-issue exception to "an existing owning branch needs --base" in docs/design.md, start-task's SKILL.md and worktree_create.sh's usage text: the existing branch is accepted, no base is recorded, and dispatch_phase.sh base --base records one later.

## Implementation
**Status**: complete
**When**: 2026-11-12 23:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a3896df654672786a, resume 2 of 3)

**PR**: #460 at `9bc5f3ee`
**Addressed**: Integrated Review at `4c248c51` (2026-11-12 23:18 -05:00)
**Commits**: 9bc5f3ee

### Actions
- [x] (should-fix, documentation defect) The rule "an owning branch that already exists needs `--base`, otherwise creation refuses" now carries its `--parent-issue` exception everywhere it was stated without it. The exception matches `worktree_create.sh`'s manifest write: with `--parent-issue`, where `--base` is refused, an existing owning branch is accepted, no `base=` is recorded, a Note says so, and `dispatch_phase.sh base --base <branch>` records one later. This is text only; no behaviour changed. Places:
  - `docs/design.md#worktrees` (Base branch bullet)
  - `.claude/skills/start-task/SKILL.md:175`
  - `.agent/scripts/worktree_create.sh`: the `--base` usage text, and the manifest-write comment, which stated the rule the same way
  - `.agent/WORKTREE_GUIDE.md` (Base branch bullet)
  - `.agent/knowledge/script_reference.md` (`worktree_create.sh` row)
  - `.agent/work-plans/issue-429/plan.md` (Part 2 step 4)

### Places left as they are
- `.claude/skills/run-issue/SKILL.md` (lines 144 and 247) states the rule without the exception, and I left it: run-issue never passes `--parent-issue`, so in its flow the rule holds as written.
- The ADR-0012 addendum also stays. It says only that for a branch the workspace did not start "only a base the owner names is recorded", which is still true when nothing is recorded.
- No test asserts the usage text: a grep of `.agent/scripts/tests/` found none.

### Checks
- `/home/roland/agent_workspace/.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, identity sourced, no SKIP: rc 0, every hook passed. That includes `validate-script-tests`, which ran the suites the branch's changed files reach.

## Local Review
**Status**: complete
**When**: 2026-11-12 23:32 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a3be5b1d6eca4c5d8, resume 3 of 3)

**PR**: #460 at `7b85fe7d`
**Depth**: Deep (reason: whole-diff classification; fix round scoped by the handoff to the one documentation suggestion and the text-only fix 9bc5f3ee)
**Must-fix**: 0 | **Suggestions**: 0

Fix-round re-review of the round-3 suggestion (the `--parent-issue` exception to the existing-branch rule). Cross-model: skipped per handoff (text and usage text only, no behaviour).

- **The exception, in each of the six places changed** (`docs/design.md#worktrees`, start-task SKILL.md, `WORKTREE_GUIDE.md`, `script_reference.md`, `worktree_create.sh`'s `--base` usage text and its manifest-write comment): each says an existing owning branch is accepted, no `base=` is recorded, a note says so, and `dispatch_phase.sh base --base <branch>` records one later. That matches `worktree_create.sh`'s manifest write, the `elif [ -n "$PARENT_BRANCH" ]` branch with its Note, and the refusal of `--base` with `--parent-issue`.
- **No behaviour changed:** inside `worktree_create.sh`, the diff of 9bc5f3ee touches only `echo` lines of `show_usage` and a comment block; `bash -n` passes.
- **Places left as they are:**
  - run-issue SKILL.md never passes `--parent-issue` (0 occurrences), so its rule needs no exception.
  - The ADR-0012 addendum still holds ("for a branch the workspace did not start only a base the owner names is recorded": the exception records nothing). It defers the detail to design.md.
- **Suites rerun at 7b85fe7d:** test_ros2_colcon 558/0, test_worktree_create 0 failed, test_package_issue_loop 194/0, test_dispatch_phase 148/0, test_merge_pr 150/0.

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-11-12 23:33 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a30219fdb6d71d1ef, resume 1 of 3)

**PR**: #460 at `89ea6ef7`
**Sources**: 2 (Local Review @ `7b85fe7d` (covers 89ea6ef7 via bookkeeping), CI rollup); Copilot skipped (disabled for quota); no GitHub reviews or comments
**Cross-source confirmations**: 0
**CI**: pending

Repeat triage after the documentation fix 9bc5f3ee and its re-review. The previous Integrated Review's one finding (the `--parent-issue` exception to "an existing owning branch needs `--base`") is fixed: `docs/design.md:505-507`, `.claude/skills/start-task/SKILL.md:175` and the `--base` usage text at `.agent/scripts/worktree_create.sh:205-211` now state that the existing branch is accepted, no `base=` is recorded, and `dispatch_phase.sh base --base` records one later. That matches the Note path at `worktree_create.sh:973`. The same text was also corrected in WORKTREE_GUIDE.md, script_reference.md and plan.md. The Local Review at `7b85fe7d` approved with no findings; its only box is the "No issues found" placeholder, not an action item. The helper now lists the round-3 pre-push entry at `0144179c` as stale with one open box: that is the same finding, ruled on in the previous Integrated Review and fixed in 9bc5f3ee. The stale open boxes at `a6c2d2f`, `3ab6be9` and `8d563c2` belong to the merged pull requests 445 and 456 and remain out of scope. CI at triage time: Validate Documentation passed in both runs; Lint (pre-commit), Validate Adapter Contract and both ros-manifest runs had no conclusion yet, and none had failed.

### Findings

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-13 06:01 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: merge

Merge (Recommended)

## Plan Authored
**Status**: complete
**When**: 2026-11-13 06:04 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-429/plan.md` at `51766e95`

Revision after 2a merged (pull request 460): 2a marked merged with what review changed; 2b re-checked against main, with cleanup cases (a) to (c) and the pull half of (d) already covered, one case left; acceptance table added. One open question: the pre-push review and the behind-check use the default branch, not the pin.

## Plan Review
**Status**: complete
**When**: 2026-11-13 06:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #429 — run-issue: drive an issue in a package repository of a multi-repository project
**Plan**: `.agent/work-plans/issue-429/plan.md` at `51766e95`
**Branch**: `feature/issue-429`

Scope: the "Revision of 2026-11-13" refresh for pull request 2b only, checked against main at `03d0bbfa` (origin/main is the same commit).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | 2b is about 8 files; with the base step below about 12 files, still one pull request. Every line citation for 2b.1 checked and correct: `_gate_wt` 708-711, match loop `_m_rel` 494, four-field record 530, read 543, `unset` 548, `records_path` 723, `_ci_wt` 736, reason 761-762, `_gate_record` repo test 880, `progress_append.sh -C` 898, push 902, comment fallback 924-925, cross-check 846-850, `PR_BASE_REF` 565-566, Step 4 at 1581, sibling `gh pr list` 1612 (plan says 1597: the loop starts there), kept message 1707 |
| Issue alignment | Needs work | Acceptance table is right except row "Needed 3: the review reads the package's diff", which is stated too broadly as "not met" (finding 2). Plan's Serves line, as checked: "Workspace goal `README.md#easy-to-use` ... `README.md#flexibility` ... Design: `docs/design.md#worktrees` (Records) and `docs/design.md#review-loop-and-timeline` (`docs/design.md#merge-gate`)"; all anchors exist (README 60, 88; design 429, 571, 657) |
| File targeting | Needs work | 2b's files are right for the gate. The base step, if taken, touches files the plan does not list: `dispatch_phase.sh` (the task line, not run-issue), `check_branch_updates.sh`, `review-code/SKILL.md`, `script_reference.md` row 34 (finding 1) |
| Consequences | Good | Line-citation refresh in `docs/design.md` 476-478 (already stale: says 871/925, code is 898/924), 384, 553 is listed; run-issue step 11 sentence (872-876) and the false Scope sentence (974-975) are listed |
| Principle alignment | Good | "Test what breaks": the gate flip and end-to-end case pin the change. Finding 3 removes a test that would not fail independently |
| ADR compliance | Good | ADR-0003 (fixture rename `p11` to `demo`, 2b.4; lines 430, 434, 511, 514 confirmed), ADR-0012/0013/0017 as in the plan; nothing new triggered |
| ROS conventions | N/A | Workspace plan |

### Verified "already done by 460" claims

- Cross-check at `merge_pr.sh` 846-850, owning branch only: confirmed.
- `PKG_WT_BASE` read from the header (`_hdr_base`, 512) and carried in `_PKG_MATCHES` (530, 543): confirmed.
- `PR_BASE_REF` from `baseRefName` in the same `gh pr view` (559, 565-566): confirmed.
- Cleanup (a) `test_qualified_pr_ref_resolves_package_worktree` 263-292, (b) its pkg_b `wip` commit and `test_sweep_reports_unmerged_local_branch` 727-751, (c) `test_sibling_pr_open_keeps_worktree` 310, (d) pull half `test_own_repo_pulls_only_on_the_base` 469-529, 531, 546: all confirmed.
- `test_package_issue_loop.sh` is 946 lines, cases 1-13, case 12 creates with `--base pinned`, case 13 resumes, publish check 815-831 asserts `--repo owner/pkg_a --base pinned` from A: confirmed.
- Gate fixture at `test_merge_pr_gate.sh` 503-526 with the "package worktrees carry no issue timeline" assertion at 522; `AGENT_NAME`/`AGENT_EMAIL` are exported at 35-36, so after the flip the record really can commit in A: confirmed.

### Findings

1. **[Issue alignment / File targeting] (must-fix) Take option 1, but it is not "two call sites in run-issue and a test".** What I read: (a) the pre-push task line is built by `dispatch_phase.sh` `skill_task_line` (435: `/review-code --branch --issue $issue`), not by run-issue; the handoff already prints `base=$pkg_base` (531, 565) but review-code's SKILL never reads a `base=` line, so the sub-agent falls to `resolve_default_branch` (review-code SKILL 134-142), which prefers a *local* default branch name. (b) `review-code` already accepts `--branch <base-ref>` (SKILL 43, 125-151) and passes it to `cross_model_review.sh --branch <base>` (402; that script verifies local `<base>` first, then `origin/<base>`, 848-855), but the SKILL's text does not say the cross-model call must get the same base as step 1b. (c) `check_branch_updates.sh` takes only `--strict` as `$1`, has no test suite, and has two other callers (`worktree_enter.sh` 458, pre-commit hook `check-branch-updates.py`) that must keep working with no argument. (d) run-issue step 8 says "merge main into the branch": for a pin that is not the default branch the host would merge the default branch into a feature branch started from the pin, putting unrelated commits into the package pull request (a silent harm, worse than a wrong review). PR-mode `review-code <M>` (`gh pr diff`), `triage-reviews` and `fetch_pr_reviews.sh` read the pull request through `gh` in A, whose repository `where` checks, so they carry no default-branch assumption. The exact step: **2b.7** (i) `dispatch_phase.sh`: read `pkg_base` before the task line (or rewrite it after) and, for `review-code` with no `--pr` and a package base, emit `/review-code --branch origin/<base> --issue N` (`origin/`: the local `<base>` in A may be absent or stale, the plan's own finding on the parent-branch path); no base: unchanged. (ii) `check_branch_updates.sh`: real argument parsing for `[--strict] [--base <branch>]`; with `--base` it uses that branch in place of the default for the on-branch shortcut, the fetch, the counts and the recommendations; no argument: unchanged. (iii) run-issue step 8: run `check_branch_updates.sh --base <base>` for a package issue, and "merge `origin/<base>`" (main for every other issue). (iv) review-code SKILL step 5e/branch mode: one sentence, the cross-model call takes the same base step 1b resolved. (v) `script_reference.md` row 34. Tests: `test_dispatch_phase.sh` or `test_package_issue_loop.sh` asserts the task line with `origin/pinned` for a package worktree and the unchanged line for a workspace one; `test_package_issue_loop.sh` runs step 8's block (extracted from SKILL.md the way the publish check at 815-831 does) in A with origin `pinned` ahead and `main` further ahead, asserting it reports behind `pinned` by the right count and names `origin/pinned`, and that a bare call still compares with the default. About 5 files and 80 lines more.
2. **[Issue alignment] (should-fix) Acceptance row "Needed 3: the review reads the package's diff" is stated too broadly.** PR-mode review, triage and review fetching already read the package pull request (445, `where`'s `gh repo view` check); only the pre-push review and the behind-check judge the default branch, and only when the pin is not it. Re-state the row as met by 445 for PR mode and by 2b.7 for branch mode, so the closing pull request does not overclaim or underclaim.
3. **[Principle alignment] (should-fix) Drop the planned `git branch -d` case; it duplicates existing assertions.** The post-removal sweep (`merge_pr.sh` 1732-1760) is one loop over every manifest entry with no owning/sibling distinction; `test_sweep_reports_unmerged_local_branch` (727-751) already asserts "Kept local branch", git's "not fully merged" and the branch still present for an entry whose remote is gone, and the "fetched only" half is the `other` setup of `test_own_repo_pulls_only_on_the_base`. A new case would fail only together with those. The plan already allows dropping it; do so and say why in the pull request.
4. **[Issue alignment] (should-fix) Acceptance line 1, "untestable", should name what is testable.** Walking run-issue steps 1-11 for a package issue against the merged scripts: steps 1 (user tier, `base`, start-task, `where`), 2 (`gh pr list` in A), 3-4 (`next`, handoff, `check-exit` on A's timeline), 7 (publish `-R --base`, tested), 9 (`fetch_pr_reviews.sh` in A, 2b.5 adds it), 10 (pushes from A) and 11 (`merge_pr.sh --pr owner/repo#M` from the root; gate and record in A once 2b.1 lands) need no hand. The hand steps found are step 8 (the host has to know not to merge `main`) and the pre-push review base, both closed by finding 1; both are script or SKILL-block behaviour and testable. Only the Agent-tool working directory and how a sub-agent reads prose stay untested. Say so in the table.
5. **[Consequences] (nit) Line citation.** 2b.3 says the sibling check is at 1597; the `gh pr list -R` call is 1612 (1597 is the loop's comment block). Also `docs/design.md` 476-478 cites 871 and 925, which are already off (898 and 924) before 2b; the refresh will fix both.

### Summary

The 2b refresh is accurate against main: every line and every "done by 460" claim checks out, and the gate change (2b.1) is correctly placed. It needs one added step before implementation: option 1 for the base of the pre-push review and the behind-check, which is the issue's own "the review reads the package's diff" line and the only hand step a real run with a non-default pin would still hit; its real size is about five files (the task line lives in `dispatch_phase.sh`, `check_branch_updates.sh` needs real argument parsing, step 8 says "merge main"), still small.

### Recommended Actions

- [ ] Add 2b.7 as in finding 1 (`dispatch_phase.sh` task line `--branch origin/<base>`, `check_branch_updates.sh --base`, run-issue step 8 text and block, review-code SKILL sentence for the cross-model base, `script_reference.md` row 34) with the tests named there
- [ ] Restate the acceptance rows for "Needed 3" and "Acceptance 1" per findings 2 and 4
- [ ] Drop the `git branch -d` cleanup case as a duplicate of `test_sweep_reports_unmerged_local_branch` (finding 3)
- [ ] Fix the 2b.3 sibling-check citation (finding 5)

## Checkpoint
**Status**: complete
**When**: 2026-11-13 06:09 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (plan review verdict needs-work: one missing step; first revise at this checkpoint since the last proceed)
**After**: plan
**Decision**: revise

Open question decided: option 1, as the review's step 2b.7 gives it. The issue's own text asks that the review read the package's diff, and run-issue step 8 as written would merge the default branch into a branch started from the pin. So: (i) dispatch_phase.sh emits "/review-code --branch origin/<base> --issue N" for a pre-push review of a package issue with a recorded base, unchanged otherwise; (ii) check_branch_updates.sh takes [--strict] [--base <b>], with no argument behaving as now for its other callers; (iii) run-issue step 8 uses the base for a package issue and merges origin/<base>; (iv) review-code's SKILL says the cross_model_review.sh --branch call takes the base step 1b resolved; (v) script_reference.md; with the two tests the review names. Also: narrow the acceptance row to what is really unmet (only the pre-push review and the behind-check, only when the pin is not the default branch); drop the planned git branch -d case (already asserted); say in acceptance line 1 what is testable; fix the two line citations.

## Plan Authored
**Status**: complete
**When**: 2026-11-13 06:09 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-429/plan.md` at `a68a3d74`

Revision after the plan review (needs-work) and the host's revise: added step 2b.7 (base of the pre-push review and the behind-check), narrowed the two acceptance rows, dropped the git branch -d case, fixed the two line citations, updated the Files table and Estimated Scope.

## Plan Review
**Status**: complete
**When**: 2026-11-13 06:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #429 — run-issue: drive an issue in a package repository of a multi-repository project
**Plan**: `.agent/work-plans/issue-429/plan.md` at `a68a3d74`
**Branch**: `feature/issue-429`

Scope: convergence review of the revision after the plan review of 06:07 and the host's revise checkpoint of 06:09. Checked against main at `03d0bbfa` (origin/main; the branch adds only plan and progress commits on top).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | 2b is now about 12 files; 2b.7 adds about 5 files. Still one pull request |
| Issue alignment | Good | Every checkpoint item is applied: 2b.7 added with (i)-(v) and both tests as decided; "Needed 3" row narrowed to the pre-push review and behind-check only (PR mode met by 445); Acceptance 1 now names what is testable (steps 1-4, 7, 9-11, and 8 plus the pre-push base via 2b.7) and what is not; `git branch -d` case dropped in 2b.3 with the reason; citations fixed (sibling `gh pr list -R` at 1612; design 476-478 noted as already off, 898/924). Open question withdrawn, Open Questions says none. Serves line, as checked: "Workspace goal `README.md#easy-to-use` ... `README.md#light-touch-on-projects` ... `README.md#flexibility` ... Design: `docs/design.md#worktrees` (Records) and `docs/design.md#review-loop-and-timeline` (pull request 2: `docs/design.md#merge-gate`)" (unchanged since the last review, anchors confirmed then) |
| File targeting | Good | Files table gains the 2b.7 row (`dispatch_phase.sh`, `check_branch_updates.sh`, review-code and run-issue SKILLs, `script_reference.md` rows 34 and 51, a test suite) |
| Consequences | Good | One nit (finding 1). `docs/design.md` names neither `check_branch_updates.sh` nor the pre-push base, so 2b.7 changes no design section |
| Principle alignment | Good | "Test what breaks": the task-line assertion and the extracted step-8 block run in A pin both halves; a bare call is asserted unchanged |
| ADR compliance | Good | Nothing new triggered |
| ROS conventions | N/A | Workspace plan |

### 2b.7 tested against the code on main

- **Task line and base**: `skill_task_line` builds `/review-code --branch --issue $issue` (`dispatch_phase.sh` 435), called at 516; the recorded base is read only at 531 (`pkg_base` from the header) and printed at 565. So (i) needs the base read before 516 or the task rewritten after 531; the plan's "Read" cites both lines, enough for the implementer.
- **Round 3**: the convergence suffix is appended to `$task` after `--issue N` (540-552), so the line becomes `/review-code --branch origin/pinned --issue 7 (round 3: ...; no cross-model reviewers)`: well-formed; review-code step 2 keys only on the words "no cross-model reviewers" (SKILL 189-204), and round 3 skips 5e, so the base is used only for the diff.
- **review-code accepts the form**: usage `--branch [<base-ref>] [--issue <N>]` (SKILL 43); step 1b uses the given value as `$BASE` and diffs `"$BASE"...HEAD` (134-151).
- **cross_model_review.sh accepts it**: `--branch` takes an optional value (405-412); `git rev-parse --verify origin/pinned` hits at 851, so `BASE_REF=origin/pinned` (the `origin/$BRANCH_BASE` fallback at 853 is not reached). SKILL 402 already shows `--branch <base>`; (iv) adds only the "same base" sentence.
- **check_branch_updates.sh**: `$1 == --strict` only (27); default from origin/HEAD (38-43); the branch is used in the shortcut (47), fetch (61, 66), counts (73-78) and messages (98-153), the places (ii) lists. Its other callers pass no argument: `worktree_enter.sh` 458-460 and `.agent/hooks/check-branch-updates.py` (`subprocess.run([str(check_script)])`). No test suite exists for it; the plan's test runs it via step 8's block.
- **Workspace issue unchanged**: (i) only when a base is recorded; (iii) keeps `main` for every other issue. The existing package assertion `task=/review-code --branch --issue 7 (round 3:` (`test_package_issue_loop.sh` 225) uses worktree C, whose `base=` is stripped at 176-180, so it stays valid; `test_dispatch_phase.sh` 458-696 use workspace worktrees and stay valid.
- **Step 8 block extraction**: `check_branch_updates.sh` appears in one bash block of run-issue SKILL (767; 274 is prose), so the 815-831 extraction pattern works.

### Findings

1. **[Consequences] (nit)** run-issue SKILL line 237 says "Keep the branch after `base=` as `<base>` for the run (step 7 needs it)"; with 2b.7 step 8 needs it too, and the step 8 heading "Merge-from-main" (760) and its echoes at 481 and 843 say "main". Update them with (iii) so the host is not told the base is used only at publish.

### Summary

The revision applies every checkpoint item as decided, and 2b.7's wording matches the code: both review-code and `cross_model_review.sh` accept `--branch origin/<base>`, the round-3 line stays well-formed, the no-argument callers of `check_branch_updates.sh` are named, and workspace issues are unchanged. Nothing confirmed earlier has regressed. Ready for implementation.

### Recommended Actions

- [ ] With 2b.7 (iii), update run-issue SKILL 237 ("step 7 needs it" to steps 7 and 8) and the "merge-from-main" wording at 481, 760 and 843 (finding 1)
