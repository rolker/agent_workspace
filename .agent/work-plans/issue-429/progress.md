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
