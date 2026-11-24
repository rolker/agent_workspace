---
issue: 581
---

# Issue #581 — review-issue: make owning-repo resolution cwd-independent

## Issue Review
**Status**: complete
**When**: 2026-11-24 13:13 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #581

### Scope Assessment

**Well-scoped?** Yes, once narrowed — the title says review-issue, the body adds plan-task and review-plan. The defect is one shared pattern (a bare `gh` call, and a git-bug slug the skill leaves as the placeholder `<owner/repo>`), so one small helper plus a one-line change at each call site fits one pull request. Small, as the triage note says. Not "verified" in full: the issue names two lines; the real list is longer (below).
**Right repo?** Yes — skills and `.agent/scripts/` are workspace infrastructure.
**Serves**: Quality of the work — `docs/design.md#review-loop-and-timeline`
**Design picture?** No change — the rule that an issue's phase reads and writes in its owning repository is already in `docs/design.md#worktrees` / ADR-0012; this brings three skills in line with it.
**Dependencies**: none identified open. Issue 579 (review-plan reads the pull request body) edits the same file; see the file split under Recommendations. Numbers written with `#` in the issue body (#445, #260) were written in the fork and are not issues here.

**Where a bare call can act on the wrong repository (checked in this worktree, from the files):**
- review-issue step 1, line 90: `gh issue view <N> --json ...`; step 7, line 244: `gh issue comment <N> --body-file ...`. Both confirmed as the issue says.
- Lines 65-67 (git-bug lookup): `_REPO_SLUG="<owner/repo>"  # resolve from git remote` is a placeholder the agent fills in by hand, from the cwd's remote. Same defect, one step earlier, and not in the issue text. The same placeholder is in plan-task line 67 and review-plan line 132.
- plan-task: line 91 (`gh issue view`), line 182 (`gh issue view <N> --json url`, which decides the worktree type and so is circular when the cwd is wrong), line 201 (issue URL), lines 347-359 (`gh pr list/edit/create` for the draft pull request; the dispatched pass uses `--no-pr`, a standalone run does not).
- review-plan: line 156 (`gh issue view "$ISSUE_NUM"`), lines 72 and 75 (`gh pr view <N>` and the `grep -o '#[0-9]*'` of the body, which takes a bare number as an issue in the cwd's repository).
- The skills never post with `gh` except review-issue step 7; `review_progress.sh persist` writes to the cwd checkout's work-plans (it checks the path is `<repo-root>/.agent/work-plans/issue-<N>`), which is right only if the cwd is the owning checkout.

**What protects `/run-issue` today:** the handoff prints the bare number (`skill_task_line`, dispatch_phase.sh:438-441) and runs the phase from the owning checkout (`cd <that checkout> &&`). For a package worktree (a `.worktree-repos` manifest, ADR-0012) `resolve_issue_dir ... 1` (dispatch_phase.sh:~345-398) also asks `gh repo view` in that checkout and refuses when it differs from the manifest header's `owner/repo#N` — the case that matters being an `upstream` remote that gh prefers over origin — printing the `gh repo set-default` fix. So the run-issue path is protected for package issues. It is not protected for a workspace or single-repository worktree (the check is skipped when the directory is the worktree itself), and not at all for a standalone `/review-issue 581`, `/plan-task 581`, `/review-plan --issue 581`: they take whatever the cwd resolves.

**What no longer applies in the issue text:** the number references (#445 is a fork issue; #260 here is the fork cutover triage), and "only /run-issue is protected" is true only for package issues. Line numbers 90 and 244 still match. The claim that the skills "can" hit the wrong repository is true but narrower than it reads: a bare number is by definition the cwd's repository, so a run from the right directory is correct. The failure needs a wrong cwd, or a cwd whose gh default differs from its origin (upstream remote).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Put each thing at the level it applies to | OK | One helper under `.agent/scripts/` used by three skills, not three copies of an idiom in prose. |
| Only what's needed | Watch | Do not make the skills accept a free-form repository argument in addition to the number unless a real caller needs it; the smallest form is `<N>` or `<owner/repo#N>` (the ref form dispatch already uses), resolved once. |
| A safeguard has to earn its cost | OK | The failure is a comment posted on a stranger's issue, not undoable; a one-time resolution that prints the repository it chose is cheap. |
| Verify before claiming | Watch | The fix must be shown by a test that runs the skill's resolution from a second repository with an `upstream` remote, not only from the workspace. |
| Keep one current design | OK | No design change (above). |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0012 (worktree composition) | Yes | The owning repository is the one holding `feature/issue-<N>`; the fix must not reinvent how it is found. |
| ADR-0010 (git-bug optional) | Yes | The git-bug slug placeholder is part of the defect; keep the gh fallback when git-bug is absent. |
| ADR-0013 (progress.md entries) | Watch | No change to entry shape; persistence stays in the cwd's owning checkout. |
| ADR-0016 (user tier) | Watch | The new script must resolve through `$WS_ROOT` like the others. |

### Consequences

- `.agent/knowledge/script_reference.md` gains the new script; `.agent/knowledge/github_cli_patterns.md` gets the "name the repository on every gh call" rule if it is not there.
- `.agent/scripts/tests/test_skill_paths.sh` covers skill text; add a suite for the helper (ref forms, upstream-vs-origin mismatch, non-GitHub remote refused).
- run-issue step 2 already uses `-R owner/repo` (SKILL.md line ~310); the dispatch check can call the same helper instead of its own copy, or be left alone.

### Recommendations

- Add one helper (a function in `.agent/scripts/_issue_helpers.sh` or a small script) that takes `<N>` or `<owner/repo#N>` and prints the owning `owner/repo`: from the ref when qualified; otherwise from `gh repo view --json nameWithOwner` in the cwd, refusing when it differs from the origin remote's GitHub slug (`extract_gh_slug`) — the same check dispatch_phase.sh already makes for package worktrees — and naming `gh repo set-default`. The skills then put the result in `_REPO_SLUG` (replacing the hand-filled placeholder) and add `-R "$_REPO"` to every `gh issue/pr` call; step 1 prints the repository it chose so a mismatch is visible.
- Cover all three skills in this one pull request (review-issue lines 65-90 and 244; plan-task 67, 91, 182, 201, 347-359; review-plan 72-75, 132, 156), and retitle or note the scope: the issue title names review-issue only.
- Keep the file split with issue 579: this issue touches only `review-plan/SKILL.md` step 2 (the issue read, lines ~122-160, one `-R` and the `_REPO_SLUG` line) and the two `gh pr view` lines in step 1 (72 and 75). 579 owns the rest of step 1 (reading the plan file instead of the PR body) and step 5-6. Lines 72-75 sit inside 579's step; if both plans edit them, land 579 first or have 579 leave those two lines alone.
- Test from a second repository with an `upstream` remote, and say in the pull request which cases were run.

### Actions
- [ ] Add a helper that takes `<N>` or `<owner/repo#N>` and prints the owning `owner/repo` (from the ref, else gh in the cwd, refusing when it differs from the origin slug); skills set `_REPO_SLUG` from it and add `-R "$_REPO"` to every gh issue/pr call
- [ ] Cover all three skills in this one pull request (review-issue lines 65-90 and 244; plan-task 67, 91, 182, 201, 347-359; review-plan 72-75, 132, 156), and note that the issue title names review-issue only
- [ ] Keep the file split with issue 579: this issue touches only review-plan step 2 (the issue read, lines ~122-160) and the two `gh pr view` lines 72 and 75 in step 1; 579 owns the rest of step 1 and steps 5-6; land 579 first or have 579 leave lines 72-75 alone
- [ ] Test from a second repository with an `upstream` remote, and say in the pull request which cases were run

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:13 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review confirms the defect; covering review-issue, plan-task and review-plan is the scope the owner accepted at the triage: "issue review (and plan-task, review-plan) can act on the wrong repository"; its actions are directions for the plan)
**After**: issue-actions
**Decision**: proceed

The owner started this drive with "start those 3" (2026-11-24). Instructions for the plan (host decisions, listed for the owner's veto):
- Scope: the three skills in one pull request, although the title names review-issue only: every gh issue and gh pr call in them names the repository, and the _REPO_SLUG placeholder an agent fills in by hand is replaced by a value a script decides.
- One helper that takes <N> or <owner/repo#N> and prints the owning owner/repo, or refuses with a clear message when it cannot tell or when what gh would resolve in this directory differs from the checkout's own origin (the upstream-over-origin case). Build it on what exists: extract_gh_slug in _issue_helpers.sh (only a github.com remote names a GitHub repository, merged today) and the check dispatch_phase.sh already makes for package worktrees; do not write a second parser.
- A project with no GitHub remote is an ordinary case, not an error: the skills must say what they do then (the issue is read from git-bug or given by the owner), and the helper's refusal must not block it.
- The references in the issue's text to #445, #470, #473 and #260 were written in the old repository and are not this repository's issues.
- Issue 579 is driven at the same time and rewrites review-plan step 1 (lines 70 to 79: it reads the plan file at the pull request's head, not the body). In that step this plan only adds the repository to the two gh pr view calls; everything else there is 579's. Whichever of the two merges second takes main in first.
- Tests: the helper from a second sandbox repository with an upstream remote, and the skill text pinned in test_skill_paths.sh. Say which cases were run.

## Plan Authored
**Status**: complete
**When**: 2026-11-24 13:25 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-581/plan.md` at `9c23aa90`

One new script, issue_repo.sh (exit 0 repo printed; 1 bad ref; 2 gh differs from origin; 3 not git; 4 no GitHub remote, ordinary; 5 gh cannot answer), built on extract_gh_slug; the three skills set the repository from it and add -R to every gh issue/pr call. Tested in a two-repository sandbox with a stub gh; skill text pinned in test_skill_paths.sh.

## Plan Review
**Status**: complete
**When**: 2026-11-24 13:19 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #581 — review-issue: make owning-repo resolution cwd-independent (defer follow-up from #473)
**Plan**: `$WS_ROOT/.agent/work-plans/issue-581/plan.md` at `9c23aa90`
**Branch**: `feature/issue-581`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three skills, one script, its suite, two knowledge docs: one pull request, as the checkpoint set it. |
| Issue alignment | Needs work | Serves: "Quality of the work: `docs/design.md#review-loop-and-timeline`" (README `### Quality of the work` and the design heading both exist). The upstream case is covered; the issue's own acceptance test (a bare `/review-issue <N>` run from the other root's checkout) is not met for a bare number and the plan does not say how that box is answered (finding 4). Offline use that works today breaks (finding 1). |
| File targeting | Good | Every bare `gh issue`/`gh pr` line in the three skills is listed (checked: review-issue 90, 244; plan-task 91, 182, 201, 347, 356, 359; review-plan 72, 75, 156) and the three `_REPO_SLUG` placeholders. `dispatch_phase.sh` may need a line (finding 2). |
| Consequences | Needs work | The package-worktree agreement with `dispatch_phase.sh` is missed (finding 2); the shell-state gap for `$_REPO` (finding 3); follow-up and parity notes (finding 10). No existing `test_skill_paths.sh` pin on these lines breaks (checked). |
| Principle alignment | Concern | "A safeguard has to earn its cost": as written, the safeguard stops an ordinary offline run that works today and costs a network call in the single-remote case where gh can name nothing but origin (finding 1). |
| ADR compliance | Needs work | ADR-0012: the helper and `resolve_issue_dir` can disagree in a package checkout (finding 2). ADR-0010: no new git-bug path should be added (issue 547, git-bug "is not staying"; finding 5). ADR-0016: `$WS_ROOT` use is right; rc 127 unhandled (finding 7). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment — high]** Exit 5 makes all three skills stop whenever `gh` cannot answer. Today `/review-plan --issue <N>` (its Usage: "enable offline plan review without a PR") and `/plan-task <N> --no-pr` (its Usage: "Useful when working offline") work offline. That is a broken ordinary case, not a clear refusal of an unusual one. The plan also asks `gh repo view` (an API call) in the ordinary case where the answer cannot differ. Decide locally first: origin's slug from `extract_gh_slug`; no `GH_REPO` in the environment; no other github.com remote; no `remote.*.gh-resolved` naming another repository. Then gh can pick only origin, so print it and exit 0 with no gh call. Ask gh only when another GitHub remote or an explicit default exists, and keep exit 5 for that unusual case. In the wiring, review-plan on exit 5 goes on with plan content only, as its step 2 already allows ("Issue context unavailable"). Add tests: an offline single-remote case gives `own/alpha` and an empty gh log.
2. **[ADR compliance / Consequences — high]** In a package worktree the helper and `dispatch_phase.sh` can disagree. The dispatched task line holds the bare number (`skill_task_line` gets `$issue`, not `$ref`), and the handoff carries no qualified ref. `resolve_issue_dir` checks gh against the manifest header's `owner/repo`; the helper checks gh against origin. Take a checkout whose origin is a fork and whose issue is the upstream repository's (header `up/pkg#N`, gh resolves `up/pkg` through the `upstream` remote). Dispatch passes, and the helper refuses with exit 2. The fix the helper prints (`gh repo set-default <origin>`) then makes dispatch refuse the next phase: a deadlock. Fix, keeping dispatch as it is: for a bare number in a checkout under a `.worktree-repos` manifest whose header `issue=` ends in `#<N>`, the helper takes the header's `owner/repo` as the expected repository (the source dispatch checks; `_worktree_helpers.sh` already reads that field) and compares gh with it. The other fix is to put the qualified ref on these three skills' task lines in `skill_task_line`. Add a manifest sandbox case for either.
3. **[Approach — medium]** `_REPO` is set in step 1's block, but each Bash call starts a new shell (the skills' own "Workspace root" section says so). Step 7's `gh issue comment -R "$_REPO"`, plan-task step 8 and review-plan step 2 run in later calls and get `-R ""`. Say how each later block gets the repository. Either rerun the helper at the head of every block that calls gh (cheap only with finding 1's local path), or have the agent write the printed repository literally. Pin whichever is chosen.
4. **[Issue alignment — medium]** The issue's test scenario is `/review-issue <N>` from the project's checkout for a workspace issue, and the reverse, "resolve correctly without manual cd". With a bare number it still reads project X's issue N, passes the helper (gh = origin), and posts the comment on X. The plan answers this with the qualified ref, the printed `Repository:` line and the session-root rule (a bare number means the session root's repository). It should say so, run the scenario with `owner/repo#N` from the other repository, and report each acceptance box in the pull request. The "Overview precondition paragraph" box was never ported here, so it is retired, not done.
5. **[ADR compliance — low]** On exit 4 the wiring "reads the issue from git-bug by the id the owner gives". That is a new git-bug path while issue 547 is about dropping git-bug. Ask the owner for the issue text, or where the project keeps its issues, in hosting-service-neutral words. Also cover the other exit-4 effects. plan-task: the worktree type comes from the session's root; the plan template's `## Issue` line has no GitHub URL; the draft PR is skipped as with `--no-pr`. review-issue: step 8's "The posted comment **is** the entry" needs a no-comment wording.
6. **[Approach — low]** A multi-repository project's root folder is not a git repository, and a standalone run there is the Path 1 case the triage kept this issue for. A bare number there gives exit 3, which is right, but the plan gives the exit 3 message no next step. It should name `owner/repo#N`, as exits 2 and 5 do.
7. **[ADR compliance — low]** The wiring handles exits 0 to 5 only. Exit 127 is what a project session with no user tier gets, since `$WS_ROOT` is `.` there and the script is missing; an older workspace checkout gets it too. Add "any other non-zero: stop and show stderr".
8. **[Consequences — low]** plan-task line 182 (`gh issue view <N> --json url` to pick the worktree type) is inline code in prose, outside any fenced block, so the planned pin does not see it. With the helper the type is a local comparison of `$_REPO` with the workspace origin's slug, with no gh call. Reword the line and pin it.
9. **[Prior art — low]** `project_integration_audit.sh` already runs `GH_HOST=github.com GH_PROMPT_DISABLED=1 gh repo view --json nameWithOwner --jq .nameWithOwner </dev/null`. Take the `GH_HOST` pin and the closed stdin. Test `GH_REPO` set in the environment, which overrides gh's remote choice. `gh_create_issue.sh` has a similar repository safeguard; name it in Prior Art.
10. **[Consequences — low]** The deferred skills (address-findings, triage-reviews, review-code) should get a follow-up issue, offered to the host, not only a line in the pull request. `docs/fork_parity.md` row 2 lists these three skills for the package-repository loop: check whether its Notes need a line.

### Summary

The helper is the right shape and covers the upstream case, but its exit-5 rule breaks offline review-plan and plan-task runs that work today. In a package worktree it can also refuse what `dispatch_phase.sh` approved, and the helper's printed fix then deadlocks dispatch. Both have a small fix that keeps the scope (a local first decision; the manifest header as the expected repository), but the decision table and tests change, so the plan needs one revision. Findings 3 and 4 belong in that revision; 5 to 10 the implementer can take.

### Recommended Actions

- [ ] Decide the repository locally when gh can only pick origin (no other github.com remote, no `gh-resolved` elsewhere, no `GH_REPO`), with no gh call; keep exit 5 for the multi-remote case only; review-plan goes on with plan content on exit 5; add offline tests
- [ ] In a package checkout, take the expected repository from the `.worktree-repos` header (as `resolve_issue_dir` does), or put the qualified ref on the three skills' dispatched task lines; add a manifest sandbox case
- [ ] Say how later Bash blocks get `$_REPO` (rerun the helper, or the literal), and pin it
- [ ] State how the issue's acceptance test is answered (qualified ref, printed repository, session-root rule), run it with `owner/repo#N`, and report each acceptance box
- [ ] Exit 4: ask the owner for the issue text (no new git-bug path); cover plan-task's type, plan URL and draft PR, and review-issue step 8's wording
- [ ] Exit 3 message names `owner/repo#N`; any other non-zero exit stops the skill and shows stderr
- [ ] Reword and pin plan-task line 182; take `GH_HOST`, closed stdin and a `GH_REPO` case from `project_integration_audit.sh`
- [ ] Offer a follow-up issue for the other skills; check `docs/fork_parity.md` row 2

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:21 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work with two real gaps, both inside the agreed scope; neither changes what the work is for)
**After**: plan
**Decision**: revise

Revise the plan to answer the Plan Review at f1444d9b. Host decisions on its findings, listed for the owner's veto:
- Finding 1 (offline): the helper decides locally first. When origin is the only github.com remote, no remote.*.gh-resolved setting names another repository and GH_REPO is unset, gh can only mean origin: print origin's slug with no gh call and no network. gh repo view is asked only when the local facts leave a choice. When gh then cannot answer, the helper says so (exit 5) and the skills carry on as far as they can without the issue's text from GitHub (review-plan on the plan alone, as its step 2 already allows; plan-task --no-pr and review-issue say what they could not read and stop only where they truly need it). Offline use that works today must still work.
- Finding 2 (package worktree): inside a package worktree the expected repository comes from the .worktree-repos header, as dispatch_phase.sh's resolve_issue_dir takes it, so the helper and the dispatcher cannot disagree; dispatch_phase.sh is not edited. Add a sandbox test with a manifest, including origin being a fork of the repository the header names. The message for a mismatch must not tell the reader to run a gh repo set-default that would make the dispatcher refuse.
- Finding 3: each later code block that needs the repository gets it again from the helper (one line), since every block is a new shell; pin that no gh issue or gh pr line in the three skills runs with an unset or empty repository.
- Finding 4: a bare number means the repository of the checkout the skill is run in; that is the session-root rule, and the helper prints the repository so the reader sees it. An issue of another repository is named owner/repo#N. The issue's acceptance test is run in that form, and the plan says the "Overview precondition paragraph" was never ported here, so that box is retired, not done.
- Finding 5: with no GitHub remote the skill asks the owner for the issue's text; no new git-bug path is added (the owner said on 2026-11-24 that git-bug is not staying). The plan says what plan-task does then about the worktree type, the issue URL in the plan and the draft pull request, and what review-issue records in place of the posted comment.
- Findings 6, 7, 8, 9: taken as written (the not-a-git-repository message names owner/repo#N; any other non-zero exit stops the skill and shows stderr; plan-task's prose check at line 182 becomes a local comparison; reuse the gh invocation project_integration_audit.sh already uses, and test with GH_REPO set).
- Finding 10: the other skills with bare gh calls (address-findings, triage-reviews, review-code) are named in the pull request text as not covered; whether they get an issue is the owner's, and the host will put it to him at the merge.

## Plan Authored
**Status**: complete
**When**: 2026-11-24 13:23 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-581/plan.md` at `a3b24fcd`

Revision answering the Plan Review: the helper decides locally first and asks gh only when local facts leave a choice; in a package worktree the .worktree-repos header is the expected repository (no set-default to a fork); each code block re-asks the helper; a bare number means the checkout's repository, other repositories as owner/repo#N; with no GitHub remote the owner gives the issue text; contract and per-exit skill behaviour given as tables.

## Plan Review
**Status**: complete
**When**: 2026-11-24 13:26 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a24d46bf9103a8049, resume 1 of 3)
**Verdict**: ready

**Issue**: #581 — review-issue: make owning-repo resolution cwd-independent (defer follow-up from #473)
**Plan**: `$WS_ROOT/.agent/work-plans/issue-581/plan.md` at `a3b24fcd`
**Branch**: `feature/issue-581`

Round 2. Each of the ten findings of the review at f1444d9b is checked against the Checkpoint's decisions (After: plan, Decision: revise).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Still one pull request, about 9 files. `dispatch_phase.sh` and `_worktree_helpers.sh` are not edited. |
| Issue alignment | Good | Serves: "Quality of the work: `docs/design.md#review-loop-and-timeline`" (checked in round 1). Approach 3 reports the acceptance boxes one by one; the precondition box is retired. Offline single-remote runs keep working (contract case 2). |
| File targeting | Good | As in round 1. It adds review-issue step 8's wording and the Usage/Overview lines. |
| Consequences | Good | The fork_parity rows are checked. The other skills are named in the pull request, and the owner decides at the merge, as the Checkpoint said. |
| Principle alignment | Good | The ordinary case makes no `gh` call; the safeguard prints what it chose. |
| ADR compliance | Good | ADR-0012: the header is the expected repository, read as `resolve_issue_dir` reads it. ADR-0010: no new git-bug path. ADR-0016: any non-zero exit, including 127, stops the skill. A small condition is left (finding A). |
| ROS conventions | N/A | Workspace plan. |

### Round-1 findings

1. Offline: answered. Decision step b and contract case 2 make no `gh` call and get a test with no gh on PATH. Exit 5 never blocks review-plan.
2. Package worktree: answered. Step a reads the header as `resolve_issue_dir` does (`*/*#*` only). Case 7's message offers `gh repo set-default H` and never origin's slug. The fork-origin sandbox case is planned.
3. Shell state: answered. Each block repeats the head, a pin checks it, and a mutation case proves the pin fails without it.
4. Acceptance: answered. A bare number means the checkout's repository (the session-root rule); the scenario is run as `owner/repo#N`; box (b) is retired.
5. No GitHub remote: answered. The owner gives the text. Each skill's exit-4 behaviour is given, including plan-task's type, issue line and draft pull request, and review-issue's step 8.
6. Exit 3's message names `owner/repo#N`. 7. Any other non-zero exit stops the skill. 8. Line 182 becomes a local comparison and is pinned. 9. `GH_HOST` is pinned, stdin is closed and a `GH_REPO` case is added. All answered.
10. Answered as the Checkpoint decided: named in the pull request, and the owner decides at the merge.

### The planner's three departures

- (a) Accepted. Taking the header only when it is `owner/repo#<N>` for this number matches `resolve_issue_dir`, which checks only when the header is `*/*#*`. Dispatch never meets another number, because it resolves the worktree from that number. Letting origin decide otherwise is right. One condition is missing (finding A).
- (b) Accepted. Any `gh-resolved` setting triggers the `gh` call: one call, plus exit 5 when offline, but only in a checkout where `gh repo set-default` was run. In practice that is a checkout with several remotes, which asks `gh` anyway. A sharper rule is optional, not required: read the setting locally (`base` gives that remote's slug; `owner/repo` gives itself) and decide locally when the result equals origin.
- (c) Accepted. On exit 5 the repository is undecided and nothing is posted (review-issue records the review with no comment; plan-task skips the draft pull request), so asking the owner for the text carries no risk of the wrong repository. The case needs wording for a dispatched phase (finding C).

### The local decision checked

The local "origin, no `gh` call" rule does not name a wrong repository in any setting checked:
- A `gh repo set-default` run earlier writes `remote.<r>.gh-resolved` into the repository's config, which a linked worktree shares. That triggers the `gh` call.
- An `upstream` on another host: `extract_gh_slug` gives nothing for it, and `gh` run with `GH_HOST=github.com` filters it out too. Every skill call now carries `-R`, so `gh`'s own choice of remote no longer matters.
- An enterprise origin: `extract_gh_slug` accepts only github.com, so the result is exit 4, as in `worktree_create.sh`.
- An enterprise `upstream` beside a github.com origin: decided locally as origin; the calls carry `-R`. The one leak left is `GH_HOST` in the environment (finding D).

### New findings

A. **[ADR compliance — medium]** The header must count only when the cwd's checkout is the manifest's issue checkout.
   - Step a takes the header for any checkout below a manifest, including a sibling repository's checkout. There, a bare matching number gives exit 2 with the advice `gh repo set-default H`, which would point the sibling's `gh` at an unrelated repository.
   - Fix: take the header only when the cwd's top-level is `issue_checkout_of "$wt" <N>`, which `issue_checkout_guard` already compares; otherwise origin decides.
   - Find the manifest with `_wpd_enclosing_manifest` (`_resolve_work_plans_dir.sh`) instead of a new walk.
   - Add a sibling-checkout test case.
B. **[Approach — low]** The contract table does not cover the package worktree's top folder, which is not a git repository but holds a matching header. Under A it falls to exit 3; the message there should name `H#N`, and a test should cover it.
C. **[Approach — low]** A dispatched phase cannot ask the owner. On exit 4 or 5 the skill text must say that a dispatched review-issue or plan-task ends with **Status**: partial, naming the text it needs, and the host asks. How run-issue then passes the text is outside this issue; name it in the pull request.
D. **[Approach — low]** The skills' `-R "$_REPO"` takes its host from `GH_HOST` when that is set in the environment, while the helper's slug is always github.com. Write `-R "github.com/$_REPO"` (prior art: onboard-project's `gh pr create -R github.com/<owner>/<repo>`), or have the helper print that form, and pin it.
E. **[Approach — low]** The guard line's text, "no repository: stop", is wrong for exit 4, which is an ordinary case. It should print the exit code and send the reader to the per-exit table.

### Summary

All ten round-1 findings are answered as the Checkpoint decided. The three departures are sound. What is left (A to E) is one condition, one message and some wording, each with a test or pin. The implementer can take them as instructions without a third plan round.

### Recommended Actions

- [ ] Apply the header only when the cwd's top-level is the manifest's issue checkout (`issue_checkout_of`), find the manifest with `_wpd_enclosing_manifest`, and test a sibling checkout
- [ ] Cover the package worktree's top folder (exit 3 naming `H#N`) in the table and tests
- [ ] On exit 4 or 5, a dispatched phase ends with Status partial and names the issue text it needs; say so in the skill text and the pull request
- [ ] Name the host on every skill `gh` call (`-R "github.com/$_REPO"`) and pin it
- [ ] Make the guard's message name the exit code and point to the per-exit table

## Checkpoint
**Status**: complete
**When**: 2026-11-24 13:26 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 2 of the plan review says ready: all ten earlier findings are answered, and its five new points can be handed to the implementer as instructions)
**After**: plan
**Decision**: proceed

Implement the plan at a3b24fcd with these instructions, which answer the Plan Review at 403122c9 and bind the implementer (host decisions, listed for the owner's veto):
- A: the manifest header counts only when the current checkout is the manifest's issue checkout (issue_checkout_of). In a sibling repository's checkout the header is ignored and that checkout's own origin decides; the helper never advises gh repo set-default toward a repository that is not the current checkout's. Find the manifest with the existing _wpd_enclosing_manifest, not a new walk. Add a sibling-checkout test.
- B: a package worktree's top folder (not a git repository, but under a manifest whose header names this number) gives exit 3 with a message naming the header's owner/repo#N; add the test and the row in the contract table.
- C: a dispatched phase cannot ask the owner. On exit 4 or 5 the skill, when it cannot go on without the issue's text, ends its entry with Status partial and names the text it needs, so the host asks; the skill text says so.
- D: the skills write -R "github.com/$_REPO", as onboard-project already does, so an environment GH_HOST cannot send the call elsewhere; pin it.
- E: the guard line prints the helper's exit code and points to the per-exit table; it does not say "stop" for exit 4, which is an ordinary case.
- The planner's three departures stand as the reviewer accepted them: a header is taken only when it is owner/repo#N for this number; any gh-resolved setting triggers the gh call; on exit 5 review-issue and plan-task ask for the issue's text and nothing is posted.
- In review-plan step 1, issue 579 (driven at the same time) rewrites the "PR number" block, which will hold three gh calls after it lands. This change adds the repository to the gh calls that exist on this branch and says in its entry that the block will need the flag on all three whichever merges second.

## Implementation
**Status**: complete
**When**: 2026-11-24 13:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-581 at `8154ec52`

Implemented the plan at a3b24fcd with the Checkpoint's points A to E.

- `.agent/scripts/issue_repo.sh` (new): `<N>` or `owner/repo#N` → `owner/repo` on stdout. Exit 0 printed; 1 usage; 2 gh resolves another repository here; 3 not in a git repository (a package worktree's top folder names the header's `owner/repo#N`); 4 no GitHub repository here (ordinary, no gh call); 5 gh had to be asked and could not answer. Decided with no gh call when origin is the only remote naming a GitHub repository, no `remote.*.gh-resolved`, no `GH_REPO`; else one `GH_HOST=github.com GH_PROMPT_DISABLED=1 gh repo view ... </dev/null`. Built on `extract_gh_slug`, `_wpd_enclosing_manifest`, `issue_checkout_of`; no URL parser of its own; `dispatch_phase.sh` not edited.
- A: the header counts only when the checkout's top-level is `issue_checkout_of`'s answer; a sibling checkout's origin decides and its exit-2 advice names its own origin (tested). B: the top folder, outside git or inside another repository, is exit 3 naming `up/pkg#7` and the issue checkout (tested both ways). C: review-issue and plan-task say a dispatched phase on exit 4 or 5 ends its entry `**Status**: partial`, naming the issue text it needs. D: every gh issue/pr line in the three skills carries `-R "github.com/$_REPO"` (pinned). E: the guard prints `issue_repo.sh exit $_rc`, says the block makes no gh call and points to each skill's "Repository by exit code" table; no "stop".
- review-issue: helper at the head of steps 1 and 7; `_REPO_SLUG="$_REPO"`; per-exit table; step 8 no-comment wording. plan-task: steps 1 and 8 likewise; step 4's type is a local comparison of `$_REPO` with the workspace origin's slug; plan template Issue line from the printed repository; step 8 skipped on exit 4/5. review-plan: new step 0 with its table; step 1's PR block gains only the head and the flag on its two `gh pr view` calls; step 2 gets the head and sets `ISSUE_NUM` itself.
- Issue 579 rewrites review-plan step 1's pull-request block (three gh calls once it lands): whichever of the two merges second must put the issue_repo.sh head in that block and `-R "github.com/$_REPO"` on all its gh calls; `test_skill_paths.sh` fails until it does.
- `test_skill_paths.sh`: pins as planned plus `bash -n` of every bash block in the three skills, and two mutation cases (guard removed, flag removed). `script_reference.md` row; `github_cli_patterns.md` paragraph. The plan was synced (A, B rows, D, E, PR-form ref).
- Decided beyond the plan: another remote naming the same GitHub repository as origin does not force a gh call; review-plan's PR form passes the issue number from the branch name (else the PR number), since the PR's own issue reference needs the repository first; plan-task step 8's block also resolves `WORK_PLANS_DIR` and takes the title literally so it runs in a fresh shell; the manifest header is read with the same `sed` as `resolve_issue_dir` rather than sourcing `_worktree_helpers.sh` (it pulls in the project registry); issue_repo.sh is not added to `.agent/user_tier_scripts.txt` (the skills' other `$WS_ROOT` scripts are not there either), so a project session asks permission per call.
- Not exercised: `gh pr create -R` from a checkout whose origin is a fork of `$_REPO` (plan-task step 8, standalone only).

Suites run, each on its own:
- `bash .agent/scripts/tests/test_issue_repo.sh`: "test_issue_repo: 64 passed, 0 failed"
- `bash .agent/scripts/tests/test_skill_paths.sh`: "test_skill_paths: 234 passed, 0 failed"
- `bash .agent/scripts/tests/test_records_write_gate.sh`: "test_records_write_gate: 68 passed, 0 failed" (selected for the new script by suites_for_files.sh)
- `bash .agent/scripts/tests/test_checkpoint_269.sh`: "test_checkpoint_269: 43 passed, 0 failed"
- `bash .agent/scripts/tests/test_script_tests_hook_scope.sh`: "test_script_tests_hook_scope: 367 passed, 0 failed" (a suite file was added)
The changed skill blocks were also run in a fresh shell with a stub gh (exit 0 and exit 4 paths). The full pre-commit pass and full suite run are left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 13:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-581 at `2afab6f5`
**Base**: origin/main
**Depth**: Standard (reason: 10 files, +1251/-30, three skills and a new script; cold read with cross-model reviewers per handoff)
**Must-fix**: 2 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Cross-model: gemini ran (3 must-fix claimed, 1 kept as must-fix, 2 as suggestions); codex ran (2 must-fix, merged into finding 1). Claude adversarial: no must-fix, 5 suggestions (two of its sandbox probes reached the real gh read-only and failed; nothing read or written). Static: shellcheck --severity=warning clean on the three .sh files. Suites: test_issue_repo 64/0, test_skill_paths 234/0.

### Findings
- [x] (must-fix) A qualified `owner/repo#N` picks the GitHub repository, but every local record step still keys on the number alone, so from a checkout of another repository's issue N the records of the wrong issue are read or written with no message. Verified in a sandbox: `/review-issue rolker/agent_workspace#45` from a project checkout on `feature/issue-45` gets `Repository: rolker/agent_workspace`, and step 8's persist commits that review into the project's issue-45 progress.md. The same in review-plan step 1 (`--issue owner/repo#N` searches the checkout, then the workspace's issue-workspace-N worktree, and can review an unrelated plan against the named issue; codex too) and plan-task steps 4 and 7 (`resolve_work_plans_dir <N>` checks number and branch, not repository; codex). Before any records read or write, compare `$_REPO` with this checkout's own repository (issue_repo.sh on the bare number) and refuse or skip persistence with a message when they differ — `.claude/skills/review-plan/SKILL.md:129`, `.claude/skills/review-issue/SKILL.md:293`, `.claude/skills/plan-task/SKILL.md:179`
- [x] (must-fix) plan-task step 8 has the agent write the issue title literally inside double quotes (`ISSUE_TITLE="<issue title>"`): a title holding a backtick, `$(...)` or `$VAR` is executed or expanded in the agent's shell (backticked words are common in titles here; on a public project the title is anyone's text). New on this branch. Use a quoted heredoc (`ISSUE_TITLE=$(cat <<'TITLE_EOF' ... TITLE_EOF)`) — `.claude/skills/plan-task/SKILL.md:400`
- [x] (suggestion) The header checks in issue_repo.sh fall back to origin silently in three edge cases: a number with leading zeros (`008` never matches `#8`); a matching header whose issue_checkout_of fails (resolve_issue_dir refuses there); a package worktree's top folder inside some other git repository with a bare or non-matching header (gives the host repository, exit 0, not exit 3; gemini). Normalise N and make the top-folder test independent of the number match — `.agent/scripts/issue_repo.sh:96-116`
- [x] (suggestion) With GH_REPO set inside a package issue checkout, exit 2 advises `gh repo set-default <header repo>`, which GH_REPO overrides, so the advice does not clear it; name GH_REPO first (gemini) — `.agent/scripts/issue_repo.sh:181-201`
- [x] (suggestion) plan-task step 8 pushes to origin and then runs `gh pr create -R "github.com/$_REPO"` with no `--head`: unexercised when `$_REPO` is not origin's repository (a fork-origin package checkout, a qualified ref); say so or pass `--head <owner>:<branch>` — `.claude/skills/plan-task/SKILL.md:390-420`
- [x] (suggestion) review-plan step 0/1: `<N>` is the PR number in step 1's block and the issue number elsewhere; step 0 names `feature/issue-<N>` but not `feature/ISSUE-<N>-<desc>`; use a distinct `<PR>` placeholder — `.claude/skills/review-plan/SKILL.md:69-118`
- [x] (suggestion) An origin through an SSH host alias (`git@github-work:o/r.git`) or `ssh.github.com:443` gives exit 4 although gh resolves it; the message is clear, but the skills then post nothing and skip the draft PR. Worth one line in the exit-4 row (pass `owner/repo#N`) — `.agent/scripts/issue_repo.sh:126-132`

## Implementation
**Status**: complete
**When**: 2026-11-24 13:59 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-581 at `82520224`
**Addressed**: Local Review (Pre-Push) at `2afab6f5` (2026-11-24 13:47 -05:00)
**Commits**: 86a5102e, 86b0ad12, 64fa31b1, 82520224

Fix pass for round 1 (2 must-fix, 5 suggestions), with the host's directions, listed for the owner's veto:
- M1: the session-root rule is decided in one place, `issue_repo.sh`. Exit 0 now also means "this checkout's issue". A qualified `owner/repo#N` is printed only when `owner/repo` is this checkout's repository (origin's slug, or the header's in a package worktree's issue checkout, so the fork-origin package checkout is not refused); any other is exit 6, naming both and saying to run from a checkout of the named repository. When origin names no GitHub repository read locally (SSH host alias, `ssh.github.com:443`), one `gh repo view` in the checkout, `GH_REPO` unset, confirms it or the ref is refused. A qualified ref outside any checkout is exit 3. Each skill has an exit-6 row, and every block that reads or writes the issue's records (review-issue step 8 persist; plan-task steps 4, 7, 8; review-plan step 1's `--issue` plan lookup and step 6 persist) asks the helper first and goes on only on 0, 4 or 5 (4 and 5 come only from a bare number). This is pinned in `test_skill_paths.sh`, with a mutation case.
- Consequence: the plan's acceptance box (d) changes. A qualified ref from the other root is now refused (exit 6), not printed. The plan was updated.
- M2: plan-task step 8 takes the title through `ISSUE_TITLE=$(cat <<'TITLE_EOF' ... )`. The same defect existed before this branch in the three persist calls' `--title "<issue title>"` (review-issue step 8, plan-task step 7, review-plan step 6). Those blocks were being edited anyway, so they got the same fix. Pinned. Checked and left as they are: the guard lines' `"<ref>"` is the user's own argument, and the helper rejects anything that is not a ref. `<N>` and `ISSUE_NUM` are numbers. review-issue step 7's comment and the review-issue and review-plan entries use quoted heredocs. Three pre-existing spots carry text the agent writes, not the issue title, and are not on this branch: plan-task step 6's `git commit -m "...<one-line summary>"`, plan-task step 7's unquoted `<<ENTRY` (it must expand `WORK_PLANS_DIR` and `PLAN_SHA`, and its summary line is the agent's text), and review-plan step 6's `--branch "<plan's branch>"`. They are named here and not changed.
- S1: leading zeros and 0 are a bad reference (exit 1), not normalised, because the skills use `<N>` as typed in paths and `gh` calls. A matching header whose `issue_checkout_of` fails gives exit 3 and quotes it, as the dispatcher refuses. A package worktree's top folder, or any folder of it that is no checkout, gives exit 3 whatever the header says, inside another repository or not. Each case is tested.
- S2: with `GH_REPO` set, exit 2 says to unset it, also in a package issue checkout (tested). Exit 2 no longer advises passing the other repository's ref, which M1 now refuses. It advises this checkout's `owner/repo#N`.
- S3: done in a few lines. When origin's slug differs from `$_REPO`, step 8 passes `--head <origin owner>:<branch>`, and the bare branch otherwise. `test_issue_repo.sh` runs step 8's block as the skill writes it, in a sandbox with a local bare origin and the stub `gh`. It also checks that a hostile title reaches `gh` literally. All three checks fail against the step-8 text before this pass.
- S4: review-plan step 0 says `<N>` is the issue number except in step 1's PR number block (`<PR>`), and names `feature/ISSUE-<N>-<description>`. Step 1's PR block is untouched beyond the earlier repository flag (issue 579).
- S5: the exit-4 message and each skill's exit-4 row name the case and say that `owner/repo#N` names the repository (gh confirms it).
- Tests stay hermetic. They use sandbox repositories under `fake_remotes/github.com/...`, a stub `gh` first on PATH (it now also logs `pr list/create/edit`), the SSH alias `github-work` mapped in the stub, and local bare origins for the push. The real `gh` and the network are not used.

### Actions
- [x] (must-fix) Qualified ref picked the repository while records keyed on the number alone — `.agent/scripts/issue_repo.sh`, the three skills' records blocks (86a5102e)
- [x] (must-fix) plan-task step 8 title inside double quotes — `.claude/skills/plan-task/SKILL.md` step 8, plus the three persist `--title` lines (86b0ad12)
- [x] (suggestion) Three silent fallbacks to origin in issue_repo.sh — `.agent/scripts/issue_repo.sh` (86a5102e)
- [x] (suggestion) GH_REPO in a package issue checkout advised set-default — `.agent/scripts/issue_repo.sh` (86a5102e)
- [x] (suggestion) `gh pr create -R` with no `--head` for a fork origin — `.claude/skills/plan-task/SKILL.md` step 8 (64fa31b1)
- [x] (suggestion) review-plan `<N>` meaning and branch forms — `.claude/skills/review-plan/SKILL.md` step 0 (82520224)
- [x] (suggestion) SSH host alias origin gives exit 4 — `.agent/scripts/issue_repo.sh`, the three exit-4 rows (86a5102e)

Suites run, each on its own, after the last commit:
- `bash .agent/scripts/tests/test_issue_repo.sh`: "test_issue_repo: 107 passed, 0 failed"
- `bash .agent/scripts/tests/test_skill_paths.sh`: "test_skill_paths: 252 passed, 0 failed"
- `bash .agent/scripts/tests/test_records_write_gate.sh`: "test_records_write_gate: 68 passed, 0 failed"
`grep -lwF issue_repo.sh` lists only the first two. shellcheck --severity=warning passed on the changed scripts. The full pre-commit pass and the full suite run are left to the host. No command was refused.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 14:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a2c0e2713a95f3063, resume 1 of 3)
**Verdict**: changes-requested

**Branch**: feature/issue-581 at `fe3881ae`
**Base**: origin/main
**Depth**: Standard (reason: whole-branch diff, 10 files, a new script and three skills; fix-round re-review classified as a first review)
**Must-fix**: 3 | **Suggestions**: 2
**Round**: 2 | **Ship**: continue — round 2: 3 must-fix is high; another independent read warranted

Round 1's seven: all closed as written (M1 re-run in a stub-gh sandbox: `rolker/agent_workspace#45` from another repository's issue-45 checkout is now exit 6 before any record; the fork-origin package checkout is still accepted, suite case). The S5 fix opened the first finding below; the S3 fix left the lookup half (second finding). Cross-model: gemini ran (3 must-fix, 6 suggestions; 2 must-fix kept, 1 dropped: an alias-URL upstream beside a github.com origin is no wrong result since every call carries -R origin); codex ran (3 must-fix, all kept, merged with gemini's). Claude adversarial (fresh, stub gh only): no must-fix, 3 suggestions. Static: shellcheck --severity=warning clean. Suites: test_issue_repo 107/0, test_skill_paths 252/0, test_records_write_gate 68/0.

### Findings
- [x] (must-fix) A qualified ref in a checkout whose origin is not read as github.com (GitLab origin, SSH host alias, no origin) is confirmed by `gh repo view`, which answers the remote gh prefers (upstream, a set default), not origin: with a GitLab origin and a GitHub `upstream` of other/repo, `other/repo#7` is exit 0 and the records blocks proceed (verified with a stub gh preferring upstream); with an alias origin own/repo plus upstream, `own/repo#7` is refused and `other/repo#7` accepted. New with the S5 fix (gemini, codex). Take gh's answer only when origin is the checkout's only remote and no `remote.*.gh-resolved` is set; otherwise exit 6 saying it cannot be confirmed — `.agent/scripts/issue_repo.sh:219-234`
- [x] (must-fix) plan-task step 8 finds an existing pull request by branch name only (`gh pr list --head "$CURRENT_BRANCH"`, `.[0]`); `--head` takes no owner, so another fork's pull request on the same `feature/issue-<N>` can be picked and `gh pr edit` overwrites its title and body. Now reachable through the fork case this branch added. Select by head owner too (`--json url,headRepositoryOwner` and a jq filter on origin's owner, or this repository's owner when origin is `$_REPO`) (gemini, codex) — `.claude/skills/plan-task/SKILL.md:442`
- [x] (must-fix) review-plan step 1's `--issue` lookup: after the new records guard says the issue is this checkout's, the block still falls back to every registered project's worktrees by number alone, so from the workspace checkout another project's issue-N plan is reviewed against this repository's issue N, with no message. Older than this branch, but it contradicts the guard and the skill text this branch added ("refuses it here before any plan or record is read"). Drop the registered-projects fallback (the session-root rule), or accept a candidate only when `issue_repo.sh <N>` run in its checkout prints `$_REPO`; the workspace-worktree fallback is built from this checkout's top level and stays (codex; gemini as suggestion) — `.claude/skills/review-plan/SKILL.md:151-165`
- [x] (suggestion) plan-task steps 6 and 7 use `$WORK_PLANS_DIR` and `$PLAN_SHA` from earlier shells; step 6 fails loudly when they are empty, but step 7's unquoted `<<ENTRY` silently writes `**Plan**: \`/plan.md\` at \`\`` and runs any backtick in the agent's summary line. Older than this branch and not hit in practice (this issue's Plan Authored entries are right); resolve both in the block as step 8 now does and use a quoted heredoc — `.claude/skills/plan-task/SKILL.md:362-385`
- [x] (suggestion) A qualified ref is printed with the caller's casing (`SomeOne/Proj#45` prints `SomeOne/Proj`); it feeds the git-bug `github-url` lookup, which is case-sensitive, and the plan's `## Issue` URL. Print `$EXPECTED` (gemini, adversarial) — `.agent/scripts/issue_repo.sh:207-209`

## Implementation
**Status**: complete
**When**: 2026-11-24 14:22 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent adcf9fb69aa534953, resume 1 of 3)

**Branch**: feature/issue-581 at `c35bf6ee`
**Addressed**: Local Review (Pre-Push) at `fe3881ae` (2026-11-24 14:08 -05:00)
**Commits**: b9ed6cc1 (merge of origin/main), 44cdb74c, 233df9fe, ebb03ad5, 5336ffa3, df84f3ff, c35bf6ee

Fix round 2 (3 must-fix, 2 suggestions), with the host's directions, listed for the owner's veto. Across rounds 1 and 2 the same defect kept coming back: the issue's repository was decided by its number, or by asking `gh`, where the checkout itself should decide. Each fix below makes the rule narrower and adds no lookup.
- Merge of `origin/main` (pull request 604, issue 579). Two files conflicted: review-plan's "PR number" block and the end of `test_skill_paths.sh`. Both are now resolved, and both sides hold:
  - 604's text, cases and stop messages are kept as merged.
  - The block gets the `issue_repo.sh` head, and `-R "github.com/$_REPO"` is on its three `gh pr view` calls.
  - Where origin is not `$_REPO` (a package checkout whose origin is a fork), the block stops and says the PR number form is not supported there. It does not fetch from origin in that case.
  - The convention is 604's: in step 1's PR number form and the Step 5 note's PR lines, `<N>` is the pull request number and `<issue>` the issue number. Step 0 now says so.
  - Both pin sections are kept. This branch's step-0 pin follows the new wording, and a new pin covers the fork stop.
- N1: the `gh` confirmation of a qualified ref is removed. Where no GitHub repository is read from origin (another host, an SSH host alias, `ssh.github.com:443`, no origin), a qualified ref cannot be shown to be this checkout's, so it is exit 6. The message says so and says what works: run from a checkout whose origin is on github.com, or pass the bare number, which there takes the exit-4 path. The exit-4 and exit-6 rows of the three skills, the exit-4 message, the script reference and the plan are updated. Both of the reviewer's cases are tested (another-host origin beside a GitHub upstream; SSH-alias origin beside one), each with no `gh` call.
- N2: plan-task step 8 now matches an existing pull request on the branch name and the head repository's owner (`headRepositoryOwner`: origin's owner in the fork case, else `$_REPO`'s, compared without case). When more than one matches, it lists them and stops. The step-8 test's stub answers `pr list` from a JSON fixture through the block's own `--jq`. Three cases: two on the branch name, one from another owner (only the fork's own is edited); only another owner's (a new pull request is created); two from this head (stops). All three fail against the previous text.
- N3: review-plan's `--issue` lookup is now this checkout's plan, then the workspace worktree built from this checkout's top level, then a stop that names both paths. The registered-projects fallback is gone. A dispatched phase runs in the issue's own checkout, so the first path finds its plan. The PR number form's own fallback (this checkout only) agrees. `test_project_registry.sh`'s test of the dropped fallback (a copy of the prescribed loop) is removed with it.
- Suggestion (casing): a qualified ref's repository is printed in this checkout's casing (origin's or the header's). Tested for both.
- Suggestion (steps 6 and 7): fixed; it was a short change. Each block resolves the work-plans directory itself, behind the records guard, and step 7 asks `plan-sha` itself. The free text goes through quoted heredocs (step 6's summary, step 7's title and entry); only the `**Plan**` line is filled, by `printf`. `test_issue_repo.sh` runs both blocks as written, each in a fresh shell. All three of its checks fail against the previous text.
- Found by running the full set of named suites: `test_issue_repo.sh` reads the real plan-task SKILL.md (since round 1's step-8 test) but had no `ROOT_READERS` entry in `test_script_tests_hook_scope.sh`. The entry is added (c35bf6ee).

### Actions
- [x] (must-fix) Qualified ref confirmed by `gh` where origin is not GitHub — `.agent/scripts/issue_repo.sh` (44cdb74c)
- [x] (must-fix) plan-task step 8 took the first PR on the branch name — `.claude/skills/plan-task/SKILL.md` step 8 (ebb03ad5)
- [x] (must-fix) review-plan `--issue` fell back to registered projects by number — `.claude/skills/review-plan/SKILL.md` step 1 (5336ffa3)
- [x] (suggestion) plan-task steps 6 and 7 relied on earlier shells; unquoted ENTRY heredoc — `.claude/skills/plan-task/SKILL.md` steps 6, 7 (df84f3ff)
- [x] (suggestion) Qualified ref printed in the caller's casing — `.agent/scripts/issue_repo.sh` (233df9fe)

Suites run, each on its own, in the foreground, after the last code commit:
- `test_issue_repo.sh`: "test_issue_repo: 113 passed, 0 failed"
- `test_skill_paths.sh`: "test_skill_paths: 260 passed, 0 failed"
- `test_records_write_gate.sh`: "test_records_write_gate: 68 passed, 0 failed"
- `test_project_registry.sh`: "=== Results: 423 passed, 0 failed ==="
- `test_script_tests_hook_scope.sh`: "test_script_tests_hook_scope: 374 passed, 0 failed" (1 failed before c35bf6ee)
- `test_dispatch_phase.sh`: "test_dispatch_phase: 244 passed, 0 failed"
- `test_worktree_create.sh`: "PASS: 112 / FAIL: 0"
- `test_package_issue_loop.sh`: "test_package_issue_loop: 228 passed, 0 failed"
- `test_plan_correlation.sh`: "test_plan_correlation: 18 passed, 0 failed"
- `test_issue_review_entry.sh`: "test_issue_review_entry: 6 passed, 0 failed"
- `test_checkpoint_269.sh`: "test_checkpoint_269: 43 passed, 0 failed"

The full pre-commit pass and the full suite run are left to the host. No command was refused.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 14:26 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a2c0e2713a95f3063, resume 2 of 3)
**Verdict**: approved

**Branch**: feature/issue-581 at `e826e829`
**Base**: origin/main
**Depth**: Standard (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings

Round 2's five, all closed: N1 (a qualified ref where origin is not on github.com is exit 6 with no gh call; re-run with a stub gh that prefers upstream: GitLab origin plus GitHub upstream, `other/repo#7` is 6, gh log empty); N2 (step 8 matches branch and head owner, stops on two; suite cases); N3 (`--issue` looks in this checkout, then the workspace worktree from its top level, then stops naming both; the dispatched route and the main-checkout route for a workspace issue both found the plan in a sandbox run of the block as written); casing (prints this checkout's spelling); plan-task steps 6 and 7 (own shell, quoted heredocs, `printf` for the Plan line). The merged PR-number block of review-plan step 1: 604's three cases and stop messages intact, `-R "github.com/$_REPO"` on all three `gh pr view` calls, a stop before the origin fetch when origin is not `$_REPO`, and `<N>` (pull request) / `<issue>` used as step 0 now says. Ordinary cases on the fix diff: bare number in a checkout and its worktree, 0, no gh call; no GitHub remote, 4, and the records blocks go on; dispatched and offline paths unchanged. Cross-model skipped (round-3 convergence check, per handoff). Static: shellcheck --severity=warning clean. Suites, foreground: test_issue_repo 113/0, test_skill_paths 260/0, test_project_registry 423/0, test_script_tests_hook_scope 374/0.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-24 14:30 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 of the pre-push review approved with nothing open, Ship: recommended; the host's full pre-commit pass over the changed files passed, every hook, no SKIP, on the code at e826e829, run beside the round 3 review, which added a record commit only)
**After**: publish
**Decision**: publish

Three pre-push rounds: round 1 found 2 must-fix and 5 suggestions; round 2 found 3 must-fix and 2 suggestions in the fixes; round 3 (a convergence check, no cross-model reviewers) found every one closed and nothing new. Gemini and Codex ran in rounds 1 and 2 and found must-fix points in both. Main was merged in twice (pull requests 603 and 604); the second merge reconciled review-plan step 1 with pull request 604.

## Local Review
**Status**: complete
**When**: 2026-11-24 14:33 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #608 at `1c2193eb`
**Depth**: Deep (reason: cold read, cross-model only: codex, per handoff)
**Must-fix**: 1 | **Suggestions**: 0

Codex ran (EXIT=0, review complete) on the title, URL and diff only. It returned two findings; the lead kept one.
Suites run at `1c2193eb`: test_issue_repo.sh 113 passed, 0 failed; test_skill_paths.sh 260 passed, 0 failed.
Dropped (Codex 1, issue_repo.sh:141, a package worktree whose issue checkout folder was deleted): probed in a sandbox package worktree. From the sibling checkout the helper prints the sibling's origin with exit 0 both with the issue checkout present and after it was moved away. That is the documented sibling-checkout answer, so a missing folder changes nothing.

### Findings
- [x] (must-fix) review-plan's file path form never checks which checkout the plan file is in: step 0 passes the path's bare `issue-<N>` to issue_repo.sh in the session's checkout, so a plan path in another repository's checkout (the skill's own example `$WS_ROOT/.agent/work-plans/issue-45/plan.md` is the workspace checkout in a project session) is read, reviewed against this checkout's issue N fetched with `-R` this repository, and recorded on this checkout's issue N timeline with no refusal. Check that the path's checkout (`git -C <dir> rev-parse --show-toplevel`) is this checkout's repository (or run the helper from there) and refuse otherwise, with a test — `.claude/skills/review-plan/SKILL.md:72` (step 0, file path form) and `:184` (File path)

## Implementation
**Status**: complete
**When**: 2026-11-24 14:36 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent adcf9fb69aa534953, resume 2 of 3)

**PR**: #608 at `0c180902`
**Addressed**: Local Review at `1c2193eb` (2026-11-24 14:33 -05:00)
**Commits**: 0c180902

The cold read of the final diff found one must-fix in review-plan's file path form. The host's direction, listed for the owner's veto: apply the same rule as everywhere else in this change, narrow and refusing. Before the plan is read, the form checks that the plan file is in the checkout the skill runs in, and stops otherwise, naming the file's checkout.
- The form now has a block behind the records guard. The path comes in through a quoted heredoc.
- The block compares two physically resolved top folders: the plan file's own checkout (its folder's `git rev-parse --show-toplevel`) and this checkout's. Comparing the file's own checkout, rather than "is it under this folder", also refuses a checkout nested in this one's tree, the way worktrees sit inside the workspace checkout.
- A missing file stops the block. So does a symbolic link, which is not followed.
- The example path is now `./.agent/work-plans/issue-45/plan.md`; the path rule in `test_skill_paths.sh` passes.
- `test_issue_repo.sh` runs the block as written from a sandbox checkout. Its own plan goes on. A plan in another checkout is refused, and so is one in a checkout nested in its tree.
- `test_skill_paths.sh` pins the block and the example. `test_script_tests_hook_scope.sh`'s note on what `test_issue_repo.sh` reads now names the review-plan file; its `.claude/skills` prefix already covered it.

### Actions
- [x] (must-fix) The file path form never checked which checkout the plan file is in — `.claude/skills/review-plan/SKILL.md` file path form (0c180902)

Suites run, each on its own, in the foreground, after the commit:
- `test_issue_repo.sh`: "test_issue_repo: 116 passed, 0 failed"
- `test_skill_paths.sh`: "test_skill_paths: 261 passed, 0 failed"
- `test_script_tests_hook_scope.sh`: "test_script_tests_hook_scope: 374 passed, 0 failed"

The full pre-commit pass is left to the host. No command was refused.

## Local Review
**Status**: complete
**When**: 2026-11-24 14:39 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a2c0e2713a95f3063, resume 3 of 3)
**Verdict**: approved

**PR**: #608 at `d82934d3`
**Depth**: Standard (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0

The cold read's finding (review-plan's file path form read a plan in another checkout against this checkout's issue of the same number) is closed by 0c180902. I ran the block as written, in fresh shells, with a stub gh whose log stayed empty: the own plan from the issue's worktree (relative path), from a subfolder (`../../` path) and by absolute path all go on; a plan in a linked worktree read from the main checkout is refused, naming that worktree; a symbolic link, a missing file and an unexpanded `$WS_ROOT` path each stop with the "No plan file" message. The path goes in through a quoted heredoc and both top levels are physically resolved. Ordinary case unbroken. Note, not a finding: from the main workspace checkout the file path form now refuses a plan in the same repository's linked worktree, which the `--issue` form still finds; the refusal is clear. Cross-model skipped (round-3 convergence check, per handoff). Suites, foreground: test_issue_repo 116/0, test_skill_paths 261/0, test_script_tests_hook_scope 374/0.

### Findings
- [ ] No issues found. LGTM.

## Integrated Review
**Status**: complete
**When**: 2026-11-24 14:41 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Reviews-read**: none

**PR**: #608 at `d82934d3`
**Sources**: 6 (Local Review (Pre-Push) rounds 1–3 @ `2afab6f5`, `fe3881ae`, `e826e829`; Local Review (cold read by Codex) @ `1c2193eb`; Local Review (convergence) @ `d82934d3`; CI rollup)
**Cross-source confirmations**: 0
**CI**: pending (read 14:40, two runs for the last push: run 45472118741 Validate Documentation pass, Validate Adapter Contract pass, Lint (pre-commit) pending, repos-manifest tests Python 3.10 pending, Python 3.14 pending; run 45472132577 all five pending: Lint (pre-commit), Validate Adapter Contract, Validate Documentation, repos-manifest tests Python 3.10 and 3.14)

No pull-request review and no conversation comment on GitHub; no Copilot review was requested. `review_progress.sh sources` at `d82934d3`: no open local findings, no dropped entries. Every must-fix and suggestion of the three pre-push rounds and the cold read is ticked, each with its fix commit in an Implementation entry; the convergence check at `d82934d3` re-ran the fixed block and approved. The branch is mergeable, main has no commits past it.

Rulings (owner direction: a clear refusal of an unusual input is fine; a silent wrong result or a broken ordinary case must be fixed):
- The convergence note (from the main workspace checkout, the file path form refuses a plan in a linked worktree of the same repository while `--issue` finds it): may stay. The refusal names the plan's checkout and says to run review-plan from there (`.claude/skills/review-plan/SKILL.md:210`); `--issue <N>` from the main checkout still reads that worktree's plan; nothing silent, and the ordinary routes (dispatched phase in the issue's worktree, own plan by relative or absolute path) go on.
- Not covered: bare `gh` calls in address-findings, triage-reviews and review-code: may stay out. Issue 581 asks for review-issue only; this change already extends to plan-task and review-plan; the other three are unchanged behaviour, not a regression. No follow-up issue exists yet (searched open issues): the host should open one or the owner say it is not wanted, so it is not lost.
- Not covered: `issue_repo.sh` not on `.agent/user_tier_scripts.txt`: may stay. In a project session it costs a permission prompt per call, a visible stop, never a wrong result; `review_progress.sh`, which the same skills call, is not on the list either. The PR text's reason is partly wrong (see below).
- Not covered: an SSH host alias or `ssh.github.com:443` origin is not read as GitHub: may stay. A bare number takes exit 4 (no `gh` call, the issue's text from the owner) and a qualified ref is refused (exit 6), each with a message naming the case (`.agent/scripts/issue_repo.sh:225`, `:234`); tested with no `gh` call.
- Difference from the issue as written (working on another repository's issue from any folder answered by a refusal, exit 6): the owner's call at the merge question under the session-root rule, not a finding.

Decision summary checked against the branch. Wrong: "as the skills' other workspace scripts are not either": four of the scripts these skills use are on `.agent/user_tier_scripts.txt` (`_issue_helpers.sh`, `_resolve_work_plans_dir.sh`, `worktree_create.sh`, `worktree_enter.sh`); `review_progress.sh` and `_worktree_helpers.sh` are not. Missing: the file path form now refuses, from the main checkout, a plan in the same repository's linked worktree (use `--issue`); in the SSH-alias bullet, that `owner/repo#N` is refused there (exit 6); the removed test of the dropped registered-projects fallback in `test_project_registry.sh` (47 lines); that the host's full pre-commit pass ran at `e826e829`, before the cold-read fix `0c180902` (CI Lint covers the final head once it settles). The rest (exit codes 1–6, 116 checks, three `gh pr view` calls with `-R`, the `--issue` lookup order, the 604 merge) matches the branch.

### Findings

### False positives
