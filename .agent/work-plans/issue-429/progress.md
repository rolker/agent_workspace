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
- [ ] (must-fix) Regression: leading whitespace is stripped before the comment check, so `version:  # TODO pin` and `version: #main` are emitted as the refs `# TODO pin` / `#main`, and `repo_pin` exits 0 with kind unknown. The old parser gave an empty value, which was refused. `adapter_sync` gets the comment as the pin too. Fix: check for the comment before trimming, or treat a leading `#` as a comment. Add both to `test_repo_pin_reads_version_as_yaml`. Found by Claude adversarial; reproduced with the parser's awk — `.agent/project_types/ros2_colcon/adapter.sh:240-247`
- [ ] (must-fix) A quoted scalar is cut at the next matching quote and the rest of the line is not checked. `'stable''next'` reads as `stable`, `"main" extra` as `main`, and `"x\"y"` as `x\`. Each is printed as a clean ref nobody pinned, and the stray-quote guard never fires. Fix: keep the quoted cut only when nothing follows it except optional whitespace and a ` #` comment; otherwise emit the raw value so the quote guard refuses it. Add tests. Found by codex (must-fix), gemini and Claude adversarial (suggestion); reproduced — `.agent/project_types/ros2_colcon/adapter.sh:237-244`
- [ ] (suggestion) In `single_project`, when `ls-remote` fails for a reason other than the timeout (rc 128: origin missing or unreachable), the error still says "origin did not name its HEAD". It should say origin could not be asked (gemini) — `.agent/project_types/single_project/adapter.sh:308-321`

## Checkpoint
**Status**: complete
**When**: 2026-11-12 18:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (second review of the verb's diff found two must-fix defects in the fix itself; second host address in a row at this checkpoint, so the next answer here is the owner's)
**After**: rounds
**Decision**: address

Round 2 of this diff (the counter says 5 because it carries part 1's reviews). Two must-fix, both in the new version parser: a comment directly after "version:" is read as the ref; a quoted value is cut at the closing quote with the rest of the line unchecked. One suggestion: single_project's error text when ls-remote fails for a reason other than the timeout. Fix all three, then a narrow convergence review.
