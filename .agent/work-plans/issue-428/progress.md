---
issue: 428
---

# Issue #428 — Loop defects from the GeoZui4D drives

## Issue Review
**Status**: complete
**When**: 2026-11-20 09:30 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #428

### Scope Assessment

**Well-scoped?** Partly. Five small defects in one issue is fine for one PR, but the issue was written 2026-11-10 and main has moved: item 2 is already fixed in code, items 1, 3, 4 and 5 are open (item 5 partly). Re-state the list before planning.
**Right repo?** Yes. Every item is a workspace script or skill text.
**Serves**: "A safeguard has to earn its cost" and the loop-reliability goal; `docs/design.md#rules`.
**Design picture?** No change. Fixes inside existing scripts and skill text.
**Dependencies**: none blocking. Related, not folded in: #362 (unticked "No issues found" placeholder), #431 (orchestrator skill updates; its item 8 overlaps item 2 and its item 11 overlaps item 1 here), #521 (merge_pr.sh leaves branches behind when origin cannot be pushed to).

**Per-item state against this branch (main at 63207c1b)**

1. Bare `-j` / `--parallel` in handoffs: OPEN. No script, skill or knowledge text states the rule; grep of `.agent/`, `.claude/skills/`, `Makefile` finds only the test runner's own `-j N` option (`run_script_tests.sh`), which always takes a count. `.claude/skills/run-issue/SKILL.md` and `.claude/skills/orchestrator/SKILL.md` have no mention. The acceptance line (rule in the text read at the point of writing a handoff) means the dispatch handoff section of `run-issue` and the orchestrator's standing rules, not only a table. A mechanical backstop is possible: `dispatch_phase.sh` could refuse or warn on a handoff containing a bare `-j`/`--parallel`; that is a choice for the plan.
2. `merge_pr.sh` waiting for CI on a repo with none: FIXED in code, cannot be reproduced. `merge_pr.sh`, CI wait block (around lines 1875-2090): it reads `gh api repos/<slug>/actions/workflows` `total_count`; with 0 and no pending review it exits `no-ci` ("no CI configured for ...; nothing to wait for"), covered by `tests/test_merge_pr_gate.sh` (ci-27 and the `total_count:0` sandboxes); introduced by #271 and #284 in September, before the issue was written. The 120 s wait the issue saw matches `MERGE_PR_CI_GRACE_SECONDS=120`, reached when the workflow count is `unknown` (API failure or non-JSON) or non-zero with no checks registered (`never-registered`), or when a review was pending/unreadable. The issue's premise ("no `.github/workflows`") is therefore not the cause; the actual repo state on the GeoZui4D run is unrecorded. The error text still points at `--no-wait` for those paths, which is the part that sent a mechanism question to the owner. Remaining work: find which path the GeoZui4D run took (ask or recreate), and either make those paths say what they are without steering to `--no-wait`, or record that item 2 is closed.
3. Read-only directories block worktree removal: OPEN. `worktree_remove.sh` (removal loop around lines 455-473) calls `git worktree remove [--force]` then `rm -rf "$WORKTREE_DIR"`; no `chmod` anywhere in it or `merge_pr.sh`. Note `git worktree remove` of a tree with unwritable subdirectories fails before the `rm -rf`, so the fix must run `chmod -R u+w` on the worktree before that call. Needs a test with a read-only subdirectory.
4. `extract_gh_slug` accepts any host: OPEN. `_issue_helpers.sh` `extract_gh_slug` strips `.*github\.com[:/]` with sed; a URL with no `github.com` is left unchanged and passes the `owner/repo` shape check if it has exactly two segments, so a non-GitHub host can yield a slug. Callers: `worktree_create.sh`, `worktree_enter.sh`, `merge_pr.sh` (several), `sitrep_checks.sh` `check_gh_issue`, `_issue_helpers.sh`. Decision needed: github.com-only check (smallest, the function's own comment already says "validated GitHub slug"), versus letting `gh` name the repository (`gh repo view --json nameWithOwner`; right for GitHub Enterprise hosts but needs a network call and fits only some callers). Per the ADR-0022-era rule on text assuming GitHub (project may have no hosting service), the github.com-only check returning empty is the safe default.
5. Copilot quota notice ending the wait: PARTLY. `.claude/skills/run-issue/SKILL.md` (around line 924) now tells the host that a Copilot quota comment is not a review and to move on; that is text only. `merge_pr.sh` has no quota handling (its pending-review hold waits on the `copilot-pull-request-reviewer` check-run), and no script detects the notice. Remaining: decide whether the skill text suffices (then record it and close the item) or a script check is wanted; the issue's "10 to 20 minutes" wait was in the host's polling, which the text now covers.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | Action needed | Rewrite the issue's item list to the current state before planning: drop item 2's stated cause, narrow item 5, so the plan does not rebuild what exists. |
| A fix needs a test | Action needed | Items 1, 3, 4 each need a script test (read-only tree removal; non-GitHub host slug; bare-flag guard if one is added); acceptance requires a test or a recorded reason per item. |
| Put each thing at the level it applies to | OK | Item 1's rule belongs in the handoff-writing text of `run-issue`/`orchestrator`, as the acceptance line says. |
| Ask what, not how | Watch | Item 4's host-check choice is a mechanism decision; decide from the principles and list it for veto rather than asking the owner. |
| Scope | Watch | Overlaps with #431 items 8 and 11: land item 1 here and cross-reference, to avoid two edits to the orchestrator skill. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (progress timeline) | Yes | This entry. |
| ADR-0016 (user tier) | Watch | `_issue_helpers.sh` is marked user-tier inert; item 4 must keep it free of repo-affecting actions. |
| ADR-0022 (parts with own design) | No | No part-level design involved. |

### Consequences

- Item 1: `.agent/knowledge/script_reference.md` or the dispatch conventions text, if a dispatch_phase.sh check is added.
- Item 3: `worktree_remove.sh` header comment and its test suite; `.agent/knowledge/script_reference.md` row.
- Item 4: tests for each caller that relied on the permissive parse (`test_*` for sitrep_checks, worktree_create).
- Any script change runs only the touched suites under the hook rule; the host runs the full pass once before publish.

### Recommendations

- Re-scope the issue to the current state: item 2 is closed pending a look at which wait path the GeoZui4D run took, item 5 reduces to a yes/no on a script check, items 1, 3 and 4 are the work.
- For item 2, record the finding and close it unless the reproduction shows a path that still steers to `--no-wait` for a mechanism-only reason; if so, change that message only.
- For item 4, take the github.com-only check unless a caller needs a non-github.com host; record the choice on the issue.
- Put the item 1 rule in the handoff-writing section of `run-issue` and in the orchestrator's standing rules, and consider a `dispatch_phase.sh` guard that rejects a bare `-j`/`--parallel` in a handoff.

### Actions
- [ ] Rewrite the issue's item list to the current state before planning: drop item 2's stated cause, narrow item 5, so the plan does not rebuild what exists.
- [ ] Items 1, 3, 4 each need a script test (read-only tree removal; non-GitHub host slug; bare-flag guard if one is added); acceptance requires a test or a recorded reason per item.
- [ ] Re-scope the issue to the current state: item 2 is closed pending a look at which wait path the GeoZui4D run took, item 5 reduces to a yes/no on a script check, items 1, 3 and 4 are the work.
- [ ] For item 2, record the finding and close it unless the reproduction shows a path that still steers to `--no-wait` for a mechanism-only reason; if so, change that message only.
- [ ] For item 4, take the github.com-only check unless a caller needs a non-github.com host; record the choice on the issue.
- [ ] Put the item 1 rule in the handoff-writing section of `run-issue` and in the orchestrator's standing rules, and consider a `dispatch_phase.sh` guard that rejects a bare `-j`/`--parallel` in a handoff.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 09:28 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the open actions change no goal: the issue's acceptance already allows "a fix with a test, or a recorded reason not to" per item)
**After**: issue-actions
**Decision**: proceed

Read: the Issue Review at db67719d. Its actions are taken into the plan, not into the issue body: the host does not rewrite the issue's text. The plan works from the current state the review found: items 1, 3 and 4 are the work, each with a test; item 2 is already fixed in merge_pr.sh (the workflow-count check), so the plan finds which wait path the GeoZui4D run took and changes a message only if one still points at --no-wait for a mechanism-only reason, else records the reason; item 5 is skill text today and the plan says whether a script check is worth adding. Item 4's choice (github.com only, or let gh name the repository) is a mechanism decision for the plan, listed for the owner's veto.

## Plan Authored
**Status**: complete
**When**: 2026-11-20 10:05 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-428/plan.md` at `dae2b500`

Items 1, 3, 4 are fixed with script tests: the job-count rule goes into every handoff's conventions line, the run-issue text and the host standing rules (no dispatch guard); the worktree is made writable before removal; extract_gh_slug accepts only github.com hosts (gh not used, callers are offline). Item 2 changes one merge_pr.sh message for an unreadable workflow count; item 5 gets no script check.

## Plan Review
**Status**: complete
**When**: 2026-11-20 09:34 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #428 — Loop defects from the GeoZui4D drives: parallel-build job count, CI wait with no CI, read-only cleanup, slug host check, quota-notice wait
**Plan**: `.agent/work-plans/issue-428/plan.md` at `dae2b500`
**Branch**: `feature/issue-428`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, five small items, #362/#431/#521 kept out. |
| Issue alignment | Concern | Item 2 fixes a path the GeoZui4D runs did not take (finding 1). Item 5's "no change" reason rests on skill text that predates the incident and misdescribes the notice (finding 2). Serves: "Goal: loop reliability (README workspace goals), under `docs/design.md#rules`" — `#rules` exists; "loop reliability" is not a heading under README "Workspace goals" (finding 4). |
| File targeting | Needs work | Item 4 misses `test_ros2_colcon.sh` (a copy of `extract_gh_slug`), the `test_merge_pr_gate.sh` hang-3 fixtures and the `worktree_create.sh` fallback (finding 3). |
| Consequences | Needs work | Item 4's empty slug sends a project issue lookup to the workspace repository (finding 3c). |
| Principle alignment | Needs work | "Look for prior art before building": `sitrep_root.sh` already parses GitHub origins (#418) and the plan writes a second, different grammar. "Test what breaks": the planned item 2 test passes only against a stub answer real GitHub never gives. |
| ADR compliance | Good | ADR-0013 (entries), ADR-0016 (`_issue_helpers.sh` stays inert, no `gh` call). ADR-0022 not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment] Item 2: the plan's route is not the one the runs took, and an empty slug does not reach that message.** Checked: GeoZui4D's origin is `git@github.com:rolker/geozui4d.git`, so `PR_REPO_SLUG` was `rolker/geozui4d`, not empty. The GeoZui4D session transcripts show the message twice: 2026-11-02 (PR 10) and 2026-11-09 (PR 14), both "no checks registered ... after 120s; if this commit is excluded by workflow path filters, re-run with --no-wait". `gh api repos/rolker/geozui4d/actions/workflows` returns `total_count: 1`, and the one workflow is `dynamic/agents/copilot-pull-request-reviewer`. The repository has no `.github/workflows`. Copilot's own review workflow makes the count non-zero, so the script goes to `never-registered` with the path-filter text. The plan keeps that text for any non-zero count, so its change would not have altered either run. The empty-slug route does not reach `never-registered` either: `_ci_poll_state` requests `repos//commits/<sha>/check-runs`. Real GitHub rejects that, so each poll gives `error` and the run ends at `api-error`. The planned test passes only because the sandbox stub answers `repos//...` for the check-runs request. Resolution: count only workflows whose `path` is under `.github/workflows/`, and leave out `dynamic/` ones. That is the issue's own ask: no workflow files means no CI. When `total_count` is higher than the number of workflows listed, use `per_page=100` or `--paginate`, or treat the count as unknown, so a long list is never read as zero. Update the existing fixtures: about 20 of them in `test_merge_pr_gate.sh` are bare `{"total_count":N}` with no `workflows` array, so a filtered count reads them as 0. Add a test whose fixture has the real shape (one `dynamic/...` workflow, no checks) and expects `no-ci`; the pending-review hold still applies. Whether to also reword `never-registered` for an `unknown` count is optional once this is fixed.
2. **[Issue alignment] Item 5: the recorded reason does not hold.** The `run-issue` text about the Copilot quota (~line 924) was added in f96f80e4 on 2026-09-21. That is seven weeks before the 2026-11-09 drive, so the text was in place and did not prevent the wait; it does not "now cover" it. The text also describes the wrong shape. It says Copilot "posts a plain issue comment ... instead of a review". The 2026-11-09 transcript shows a **review**: author `copilot-pull-request-reviewer`, state `COMMENTED`, body "Copilot was unable to review this pull request because the user who requested the review has insufficient remaining quota." A host following the text looks for a comment and finds a review, which counts as a review source. Resolution: correct the text to the observed shape, at the least. Then weigh the script check again on a stable key instead of on free text: author `copilot-pull-request-reviewer`, a review with no inline comments and a body under a set length, reported by `fetch_pr_reviews.sh` as "quota notice, not a review". The issue's other case, "a review that never started", is not addressed by the plan or by the existing text. Say what bounds that wait, or record why nothing does.
3. **[File targeting / Consequences] Item 4: prior art and three consequences the plan misses.**
   (a) `sitrep_root.sh` (`gh_slug`, ~lines 229-238, from #418, the issue item 4 follows up) already holds the github.com grammar: https/http, `ssh://` with an optional port, `git://`, and scp-like forms, with an anchored owner/repo pattern, an optional `.git` and a trailing `/`. Its header says that a local path or an ssh host alias is "not on GitHub". The plan's rule differs on three points: it accepts `www.github.com`, keeps local paths, and leaves trailing `/`, `git://` and `http://` unstated. Use the same grammar, or record each difference and the reason for it.
   (b) `test_ros2_colcon.sh` ~line 845 holds a verbatim copy of today's `extract_gh_slug`, with a comment calling it "the real implementation". After the change the copy is stale. Update it or source the real function.
   (c) `test_merge_pr_gate.sh` hang-3 (~1585, ~1616) sets an origin of `ssh://git@github.com$sb/fake_remotes/github.com/owner/pkg_a.git`: host github.com, with an absolute path behind it. A strict path parse returns empty for it, so `merge_pr.sh` (~622) stops finding the package worktree. Say how this fixture is handled.
   (d) `worktree_create.sh` ~700: when `GH_REPO_SLUG` is empty, `_LOOKUP_REPO` falls back to the **workspace** remote's slug. Today an scp-form non-GitHub project origin (`git@gitlab.com:o/r.git`) gives a non-empty garbage slug. After this change it gives empty, so a project issue N would be looked up in the workspace repository: the wrong title would be printed. If the workspace has a pull request numbered N, creation is refused with "is a pull request, not an issue". Limit that fallback to workspace-type worktrees, or skip the lookup for a project with no GitHub slug, and add a test.
4. **[Issue alignment] Serves line and principle names.** "Loop reliability" is not a goal heading under README "Workspace goals". The headings are Quality of the work, Trust, control and information, Flexibility, Modular, Light touch on projects, Easy to use, and The long view. The plan also cites "A safeguard has to earn its cost" and "A fix needs a test", and neither is a name in `docs/principles.md`. The nearest are "Enforce what matters, as simply as possible" and "Test what breaks". Name the real goal and the real principles.
5. **[Principle alignment] Item 3, suggestion: the chmod and the test.** Reviewed for escape: GNU `chmod -R` does not follow symlinks it meets while walking the tree. A symlink given as the argument itself is followed, though. A package entry `$WORKTREE_DIR/<rel>` that is a symlink passes the owner check, because both sides are compared as physical paths. Skip the chmod for an entry that is a symlink, or use `find -P <dest> -type d ! -perm -u+w -exec chmod u+w {} +`. Sibling checkouts are not touched, since each chmod covers one entry. `--path` already refuses anything that is not a worktree. The dirty preflight runs before any chmod and is unchanged, and `u+w` changes nothing `git status` sees, since git tracks only the exec bit. The final `chmod` needs a `[ -d "$WORKTREE_DIR" ]` guard, because the single-entry tree is already gone by then. For the test: `install/` must be gitignored, or the non-force run is refused for untracked files and never reaches the code under test. Run as root, the test passes without the fix, because root ignores mode bits; skip it there and say so.
6. **[Principle alignment] Item 4, suggestion: the local-path exception and the sitrep test.** The exception keeps the substring hole for local paths: `/x/notgithub.com/o/r.git` still gives `o/r`. Narrow it to a path segment that is exactly `github.com` (`(^|/)github\.com/<o>/<r>(\.git)?$`). Say in the header that it exists for test fixtures. Add `https://user:token@github.com/o/r.git` and a trailing `/` to the test list, and record that `ssh.github.com` (the port-443 form) is not supported. The planned `test_sitrep_checks.sh` case must use an scp-form non-GitHub origin such as `git@gitlab.com:acme/w.git`. An https non-GitHub origin already reports `unknown` today, so that test would pass without the fix. With the scp form, today's garbage slug reaches the stub `gh`, which answers for any slug, and the result is `true`.
7. **[Principle alignment] Item 1, suggestion: the test wording.** A test that the rule sentence "contains no bare `-j`/`--parallel`" will match the rule's own words ("never a bare `-j` or `--parallel`"). Assert that the counted examples (`-j 4`, `--parallel 4`) appear instead. On placement: `conventions=` is the right place. `dispatch_phase.sh` prints it, so the host reads it while writing the handoff. It also reaches the implement agent, which read the issue itself and ran the bare command. The `run-issue` paragraph covers text the host copies.

### Summary

Items 1 and 3 are sound and need only small test corrections. Item 2 targets a route the GeoZui4D runs did not take: the real cause is Copilot's dynamic workflow, which makes the workflow count non-zero. Item 5's "no change" rests on text that predates the incident and describes the notice wrongly. Item 4 misses prior art in `sitrep_root.sh` and a wrong-repository fallback in `worktree_create.sh`. Not ready to implement until findings 1 to 4 are addressed.

### Recommended Actions

- [ ] Item 2: count only `.github/workflows/` workflows and leave out `dynamic/` ones; handle a paged list; update the `{"total_count":N}` fixtures; test with the real one-dynamic-workflow shape expecting `no-ci` (finding 1).
- [ ] Item 5: correct the `run-issue` text to the observed shape (a COMMENTED review by `copilot-pull-request-reviewer`); weigh again a `fetch_pr_reviews.sh` check keyed on author and review shape; address or record the "never started" case (finding 2).
- [ ] Item 4: use `sitrep_root.sh`'s grammar or record each difference; update the `test_ros2_colcon.sh` copy; decide the hang-3 `ssh://git@github.com<path>` fixture; fix the `worktree_create.sh` workspace-slug fallback for project worktrees, with a test (finding 3).
- [ ] Name a real README goal and the real principle names in Serves and the self-check (finding 4).
- [ ] Take suggestions 5 to 7 into the item 3, 4 and 1 tests.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 09:36 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work with four must-fix items, none a question about the goal)
**After**: plan
**Decision**: revise

Read: the Plan Review at 7bffcb35. Its must-fix items go back to the plan as written there: item 2's fix aims at a path the GeoZui4D runs did not take (the workflow count was 1, the hosted reviewer's own dynamic workflow, so count only workflows under .github/workflows/, handle a list past one page, test the real shape); item 5's "no change" reason does not hold (the skill text predates the wait and describes a comment where the notice was a review; the "review never started" case is not addressed); item 4 misses the existing parser in sitrep_root.sh, a stale copy in test_ros2_colcon.sh, the hang-3 fixtures in test_merge_pr_gate.sh and the empty-slug fallback in worktree_create.sh; the Serves line and the principles cited name things that do not exist. Its suggestions for items 1, 3 and 4 are taken too. First host revise at this checkpoint.

## Plan Authored
**Status**: complete
**When**: 2026-11-20 10:40 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-428/plan.md` (revision after the Plan Review at 7bffcb35)

Revised for every finding. Item 2: count only active `.github/workflows/` entries (GeoZui4D's one workflow is the hosted reviewer's `dynamic/` one), a list past one page is `unknown`, fixtures rewritten to the real shape, no message change. Item 5: skill text corrected to a COMMENTED review by the hosted reviewer, a `notice_only` flag in `fetch_pr_reviews.sh` keyed on author and shape, and a stated bound on the never-started wait. Item 4: `sitrep_root.sh`'s grammar reused with recorded differences, stale `test_ros2_colcon.sh` copy, hang-3 fixtures and the `worktree_create.sh` workspace-slug fallback fixed, local-path exception narrowed. Item 3: symlink-safe `find -P` chmod, guarded final step, gitignored `install/`, skip as root. Item 1: placement kept, test asserts the counted examples. Serves and principle names corrected to existing headings. One PR, with a split proposed only as a fallback.

## Plan Review
**Status**: complete
**When**: 2026-11-20 09:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #428 — Loop defects from the GeoZui4D drives: parallel-build job count, CI wait with no CI, read-only cleanup, slug host check, quota-notice wait
**Plan**: `.agent/work-plans/issue-428/plan.md` at `8a64b893`
**Branch**: `feature/issue-428`

Second review, after the revision of the plan that the Plan Review at 7bffcb35 found needs-work.

### First review, point by point

- Finding 1 (item 2, wrong route): answered. Only active `.github/workflows/` entries are counted, a list past one page is `unknown`, the fixtures get the real shape, and test (a) is the GeoZui4D shape. The narrower exclusion is suggestion 4 below.
- Finding 2 (item 5, the reason for no change): partly. The text now names the right shape and the "never started" case gets a bound. The new flag can mark a real review as a notice (must-fix 1), and the bound does not cure the reported wait (must-fix 2).
- Finding 3a (prior art in `sitrep_root.sh`): answered. Same grammar, with each difference recorded. Implementation note: `gh_slug` takes `.git` off with a non-greedy repo pattern, and bash ERE has no non-greedy match, so strip a trailing `/` and then `.git` before matching.
- Finding 3b (stale copy in `test_ros2_colcon.sh`): answered.
- Finding 3c (hang-3 fixtures): answered. The fixture moves to a real URL and `serve_shim` rewrites the path. The other `ssh://git@github.com$bare` fixture (`test_merge_pr_gate.sh` ~1648) is missed by the planned grep, but it already gives an empty slug today, because the greedy sed leaves more than two segments. So it does not change.
- Finding 3d (`worktree_create.sh` fallback): partly. See must-fix 3.
- Finding 4 (Serves and principle names): answered. The README "Quality of the work" bullet is quoted at README line 37. `docs/design.md#rules` exists. The self-check uses real headings from `docs/principles.md`.
- Suggestion 5 (item 3 chmod and test): answered. `find -P`, directories only, guarded final step, gitignored `install/`, skip as root.
- Suggestion 6 (item 4 local path and sitrep test): answered. The rule is narrowed to the last three segments, `user:token@` and a trailing `/` are in the table, `ssh.github.com` is recorded, and the sitrep case uses the scp form.
- Suggestion 7 (item 1 test wording): answered. The test asserts the counted examples are present.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Needs work | About 18 files across five items. Take the split up front, regrouped (finding 6). |
| Issue alignment | Needs work | The item 5 bound is longer than the wait the issue reports as the defect (must-fix 2). Serves: "README 'Workspace goals', 'Quality of the work': 'A safeguard has to earn its cost …' … and 'Trust, control and information' … Under `docs/design.md#rules`." Checked: both headings exist, the bullet is at README line 37, and `#rules` is at design.md line 163. |
| File targeting | Good | All 18 files are named. |
| Consequences | Needs work | The `notice_only` text in `run-issue` and `triage-reviews` turns a wrong flag into dropped findings (must-fix 1). The project-type lookup skip leaves the `gh pr view` check without `--repo` in place (must-fix 3). |
| Principle alignment | Needs work | "Verify before claiming": the 500-character threshold rests on one sample of a long Copilot review. "Enforce what matters, as simply as possible": the 1800 s value is taken from the CI timeout, not set by the standing timeout rule. |
| ADR compliance | Good | ADR-0013 and ADR-0016 hold: `_issue_helpers.sh` stays inert, and the flag adds no API call. ADR-0022 is not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences] Item 5: `notice_only` marks real Copilot reviews that carry findings, and the planned text tells the host to drop them.** Checked: `gh api repos/rolker/agent_workspace/pulls/416/reviews`. That pull request has eight real Copilot reviews of 204 to 296 characters, each with state COMMENTED and no inline comments (its review comments belong only to reviews 5740889641 and 5741419861). Each would get `notice_only: true` under the plan's rule. Review 5741265646, 296 characters, reads "Human assessment is needed because an unpublished finding indicates that the documented symlink invocation can check the wrong AGENTS.md and falsely pass an over-budget repository file". That is a finding carried in the body. The plan says a wrong flag "costs a host reading a short body". It does not: the plan's own lines in `run-issue` section 9 and `triage-reviews` say `notice_only` reviews "carry no findings and are not a review source", so a wrong flag drops the finding. No script reads the flag. `review_progress.sh sources` reads only the inline `comments` of each review, so a zero-comment review adds nothing there either way. The skill text is the only consumer, and the harm lands there. The 3897-character "real review" in the plan is a single sample. Resolution: key the flag on what the notice says, so that a miss is the safe side. Checked over the last 60 pull requests of this repository: 186 Copilot reviews. 18 real ones all start with `<!-- ccr-overview`. 168 notices come in three wordings: two quota texts (119 and 122 characters) and "Copilot encountered an error and was unable to review this pull request" (117 characters, PR 411). All three contain "unable to review this pull request". The rule: Copilot author, COMMENTED, no inline comments, and the body contains that phrase. A new notice wording is missed, which costs only today's behaviour. A real review is flagged only if its body says it could not review. Keying on the absence of the `<!-- ccr-overview` marker also catches all three wordings, but if the format changes it flags real reviews, which is the unsafe side. Add review 5741265646's shape as a negative fixture and the error wording as a positive one, and record the chosen key in the header.
2. **[Issue alignment] Item 5: the 1800 s bound is longer than the wait the issue calls the defect, and it is not set by the standing rule.** The issue says the loop "waited 10 to 20 minutes for a review that never started". A 30-minute bound allows that wait and more. `host_standing_rules.md` line 31 says "no waits on things that will not arrive, a timeout of about twice the expected duration". Measured on pull requests 416, 417 and 420: Copilot reviews arrive 0 to 9 minutes after the reviewed commit's committer time, most within 1 to 6 minutes, with two outliers at 17 and 30. Committer time is earlier than push time, so these are upper bounds. Twice the usual duration is about 10 to 15 minutes, not 30. The value is placed where the host reads it while waiting (section 9), which is right. But it is `MERGE_PR_CI_TIMEOUT_SECONDS` taken from CI. Resolution: set the host's bound from the standing rule (about 900 s, with the measurement cited in the text), or record why a longer one is wanted. Keep `merge_pr.sh`'s 1800 s review-pending hold as it is: that is a different wait.
3. **[Consequences] Item 4: the project-type skip leaves the `gh pr view` check without `--repo`. That check is the refusal first-review finding 3d named.** `worktree_create.sh` ~716-725: the pull-request check runs when `_LOOKUP_REPO` is non-empty **or** `ROOT_NOT_GIT=false`. With the plan's change, a project with no GitHub slug has an empty `_LOOKUP_REPO` and `ROOT_NOT_GIT=false`. It still runs `gh pr view N` with no `--repo`, and that resolves against the current folder, because the `cd "$ROOT_DIR"` comes later, at ~857. From a workspace-folder session, a workspace pull request numbered N still gives "is a pull request, not an issue" and creation is refused. The plan skips only the `issue view` fallback (~710). Resolution: treat "project type, no GitHub slug" the way the `ROOT_NOT_GIT` branch is treated already: no lookup, no `issue view` fallback, no PR check, and a message branch of its own. Add a `gh pr view` call to the test's recorded-calls assertion.
4. **[Issue alignment] Item 2, suggestion: leaving out every `dynamic/` workflow also leaves out code scanning, and there are two Copilot paths.** This repository lists `dynamic/agents/copilot-pull-request-reviewer` and `dynamic/copilot-pull-request-reviewer/copilot-pull-request-reviewer` (`gh api repos/rolker/agent_workspace/actions/workflows`). Code scanning's default setup is also a `dynamic/` workflow, `dynamic/github-code-scanning/codeql`, and it does put check-runs on pull requests. With no workflow files and default setup on, the plan counts 0. `no-ci` is taken on the first poll whose state is `none`, so a merge run before CodeQL's checks register skips a wait it should have kept. Today that repository gets up to 120 s of grace. The window is small, because reviews take minutes after a push, but it is the kind of merge without checks that the #284 review guarded against. Either leave out only the reviewer's own workflows (both paths, matching `MERGE_PR_CI_EXCLUDE_CHECK_RUN`) and other known workflows that never run on pull requests (`dynamic/dependabot/…`, `dynamic/pages/…`), or keep the `dynamic/` rule and record the code-scanning case as accepted. Fixture (a) should carry both Copilot paths. The other shape asked about, required checks from an external app with no workflow file, already counts 0 today, so the plan changes nothing there. A workflow file that runs only on other events (tag, schedule) still gets `never-registered` and the `--no-wait` hint after 120 s. That is the issue's complaint, left in place for that shape. Record it as a known gap. Parsing `on:` is not worth it. Optionally, have the message state the fact ("N workflow file(s), none registered a check on this commit").
5. **[Principle alignment] Item 4, suggestion: wording at worktree creation for a project hosted elsewhere.** The planned note is "the project's origin is not a github.com URL". Word it as something the workspace supports, not a fault: for example, "Issue #N not looked up: issue titles are read from GitHub, and this project's origin is hosted elsewhere". Without the ⚠️ the existing branches use. It replaces the "Could not fetch issue title (offline or issue does not exist)" line and is not printed beside it. A project with no `origin` at all also takes this path today: `extract_gh_slug ""` is empty at ~638, so it falls back to the workspace's slug as well. The plan's fix covers it, but that case needs its own wording ("has no origin"), and the test table should include it. "Light touch on projects" is the README goal this serves.
6. **[Scope] Take the split up front, grouped by the files the items share.** The plan's fallback pairs item 5 with item 4. But item 5 edits `run-issue/SKILL.md` section 9 and item 1 edits the same file's handoff section, while item 4 shares no files with the other items. Item 4 is the change with the widest reach: 21 call sites outside the tests and fixtures in four suites. A must-fix in item 4 would otherwise send items 1, 2, 3 and 5 through another 20-25 minute review round. Suggested: PR A with items 1, 2, 3 and 5, then PR B with item 4 alone.

### Summary

The revision answers every point of the first review except two that it answers only in part: item 5's flag and the `worktree_create.sh` fallback. The new `notice_only` rule would mark real Copilot reviews that carry findings as notices, and the planned text then drops those findings. The new 1800 s bound is longer than the wait the issue reports. Items 1 and 3 are ready, item 2 is ready apart from suggestion 4, and item 4 needs the PR-check skip.

### Recommended Actions

- [ ] Item 5: key `notice_only` on the phrase "unable to review this pull request" (all three observed notice wordings), not on body length; add a short real Copilot review with no inline comments as a negative fixture and the error wording as a positive one (finding 1).
- [ ] Item 5: set the host's wait bound from the standing rule (about twice the measured review time, about 900 s) with the measurement cited, or record why it is longer (finding 2).
- [ ] Item 4: for a project with no GitHub slug, skip the `gh pr view` check without `--repo` too, mirroring the `ROOT_NOT_GIT` branch; assert no `pr view` call in the test (finding 3).
- [ ] Item 2: narrow the `dynamic/` exclusion to the reviewer's own workflows (both paths) and known non-PR ones, or record the code-scanning case; record the gap for a workflow file that runs only on other events (finding 4).
- [ ] Item 4: word the worktree-creation note as something the workspace supports, and cover a project with no `origin` (finding 5).
- [ ] Split up front: items 1, 2, 3 and 5, then item 4 (finding 6).

## Checkpoint
**Status**: complete
**When**: 2026-11-20 09:46 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second plan review's verdict is needs-work with three must-fix items, each with its fix named and none a question about the goal)
**After**: plan
**Decision**: revise

Read: the Plan Review at 21ffdc89. Second host revise in a row at this checkpoint; the next answer here is the owner's. The must-fix items go back as written there: the notice_only flag keyed on shape would mark real short reviews that carry a finding (key it on the phrase "unable to review this pull request"; a new wording is missed, which is today's behaviour); the 1800 s bound on a review that never starts is longer than the wait the issue calls the defect (about 900 s by the standing rule of twice the expected duration); for a project with no GitHub slug the pull-request check still runs without --repo and can refuse creation (handle it as the existing not-a-git-repository branch does). Suggestions 4 and 5 are taken. The split is taken up front, grouped by shared files: items 1, 2, 3 and 5 in the first pull request (Part of #428), item 4 alone in the second (Closes #428).

## Plan Authored
**Status**: complete
**When**: 2026-11-20 11:20 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-428/plan.md` (second revision, after the Plan Review at 21ffdc89)

Revised for the three must-fix items and both suggestions. Item 5: `notice_only` keyed on the phrase "unable to review this pull request" (hosted reviewer's account, COMMENTED, no inline comments); an unknown wording is not flagged; tests carry the three notice wordings and real short reviews as negatives. Host wait for a review that never starts is about 900 s, with the standing rule and the measurement cited in the section 9 text. Item 4: a project with no GitHub slug (non-GitHub origin or no origin) gets no issue lookup and no pull-request check, like the not-a-git-repository branch, with its own notes and a workspace-folder test. Item 2: leave-out list is the reviewer's two paths plus dependabot and pages; code scanning is counted; two gaps recorded. Split taken up front: Part 1 is items 1, 2, 3, 5 (`Part of #428`); Part 2 is item 4 alone (`Closes #428`). Files per part are listed in the plan.

## Plan Review
**Status**: complete
**When**: 2026-11-20 09:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #428 — Loop defects from the GeoZui4D drives: parallel-build job count, CI wait with no CI, read-only cleanup, slug host check, quota-notice wait
**Plan**: `.agent/work-plans/issue-428/plan.md` at `6b241e5d`
**Branch**: `feature/issue-428`

Third review, a convergence check on the second revision, after the Plan Review at 21ffdc89.

### Second review, point by point

- Must-fix 1 (`notice_only` marks real short reviews): answered. The key is now the phrase "unable to review this pull request" together with the hosted reviewer's account, COMMENTED and no inline comments. The three notice wordings are positive fixtures. The short real review with a finding (the shape of review 5741265646) is a negative one. The skill text no longer tells the host to drop flagged reviews as a source; it says they hold no findings. `fetch_pr_reviews.sh` already carries `user_login`, `state`, `body` and per-review `comments` (~109, ~180-190), so the flag needs no new call.
- Must-fix 2 (1800 s bound): answered. The host bound is about 900 s. The text cites `host_standing_rules.md` line 31 (checked: "a timeout of about twice the expected duration") and the measurement. `merge_pr.sh`'s 1800 s review-pending hold is left as it is.
- Must-fix 3 (`gh pr view` with no `--repo`): answered. For a project with no GitHub slug, the issue lookup, the `issue view` fallback (~710) and the PR check (~716-725) are all skipped, the same as the `ROOT_NOT_GIT` branch. The test asserts that no `pr view` call is made, from a workspace-folder session where the stub answers a pull request numbered N. Placement note: suggestion 3.
- Suggestion 4 (the `dynamic/` exclusion): answered. The leave-out list is the reviewer's two paths plus the dependabot and pages prefixes. Code scanning is counted (case f). Fixture (a) carries both reviewer paths. Two gaps are recorded. See the evidence below and suggestion 1.
- Suggestion 5 (creation-note wording, no origin): answered. The note is worded as a supported case, with no warning sign. It replaces the "offline or issue does not exist" line, and the no-origin case has its own wording and its own test.

### What this revision introduced, tested

**The dependabot and pages leave-outs.** The evidence supports them, but the plan does not cite it. Read-only API check over every repository of this owner: dynamic workflows found are `dynamic/dependabot/dependabot-updates` (ros2_agent_workspace), `dynamic/dependabot/update-graph` (unh_marine_autonomy, marine_tools, marine_ais, rqt_sonardyne, imagenex_deltat) and `dynamic/pages/pages-build-deployment` (daddy_camp). Their runs were read from `actions/workflows/<id>/runs`: 123 runs, every one `event: dynamic` on the repository's default branch (`jazzy`, `main`, `noetic`), and none with a linked pull request. That fits how both work: Pages builds on a push to its publishing branch, and Dependabot's jobs run on its own schedule against the default branch. Neither runs on a pull request's head commit. The worst case is also small. The leave-out matters only in the `none` state (no check-run on the head yet), because `merge_pr.sh` (~2052-2068) takes `no-ci` only when nothing is registered. A check that has registered is waited for as before. Both entries also matter in practice: marine_tools (reviewer + `update-graph`) and daddy_camp (reviewer + pages) would otherwise still get the 120 s wait and the `--no-wait` hint.

**The split.** The boundary is clean. Part 1 can be finished with its tests passing and no change from Part 2. Checked:
- No Part 1 file calls `extract_gh_slug`. Its callers are `_issue_helpers.sh`, `worktree_create.sh`, `worktree_enter.sh`, `merge_pr.sh` and `sitrep_checks.sh`, and Part 1's `merge_pr.sh` edit is the workflow count only.
- The gate suite's CI cases use origin `${sb}.remote.git` (~159). That path has no `github.com` segment, so it gives an empty slug under both the old parser and the new one. `workflows_path()` (`repos//actions/workflows`) does not move when Part 2 lands.
- The only other suite with a workflows stub (`test_package_issue_loop.sh` ~112, `*/actions/workflows`, which would not match `?per_page=100`) runs `merge_pr.sh` only with `--no-wait`. It never reaches the lookup.

The two shared files are edited in different places: workflow fixtures against hang-3 fixtures and `serve_shim`, and four rows of `script_reference.md` against two others. "Part 2 starts from main after Part 1 merges" is what run-issue step 13 already does: a fresh `/run-issue 428` recreates `feature/issue-428` from the base. So it is enough.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two parts, grouped by shared files: Part 1 is about 12 files, Part 2 about 8. |
| Issue alignment | Good | Serves: "README 'Workspace goals', 'Quality of the work': 'A safeguard has to earn its cost …' … and 'Trust, control and information' … Under `docs/design.md#rules`." Already checked in the second review. Unchanged. |
| File targeting | Good | Each part's table matches its items. Shared files are named with the region each part edits. |
| Consequences | Good | The second review's three consequence findings are answered. No new one rises to a must-fix. |
| Principle alignment | Good | "Verify before claiming": the leave-out list rests on reads the plan does not cite (suggestion 1). |
| ADR compliance | Good | ADR-0013 and ADR-0016 as before. ADR-0022 not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

No must-fix. Suggestions for the implementer:

1. **[Principle alignment] Item 2: record the evidence for the dependabot and pages leave-outs** in the `merge_pr.sh` header next to the list: runs read across this owner's repositories, all on the default branch, none linked to a pull request. Also say that a leave-out acts only before any check registers. Without this, a later reader cannot tell the list from a guess.
2. **[Issue alignment] Item 2: name the hosted coding agent as a third known gap.** `dynamic/copilot-swe-agent/copilot` is active in udp_bridge, unh_marine_radar, carp, drix_description, unh_marine_autonomy and ros2_agent_workspace. Its runs are on its own `copilot/*` pull-request branches, so it can register checks, and counting it is right. As a result, a repository with only the reviewer and the coding agent still gets the 120 s wait and the `--no-wait` hint. That is the issue's complaint, left for that shape. Record it with the other two gaps.
3. **[Consequences] Item 4: put the no-slug skip after the qualified-ref branch.** It belongs with the `ROOT_NOT_GIT` `elif` (~694-698), not in front of `[ -n "$ISSUE_OWNER_REPO" ]`. A qualified `--issue owner/repo#N` names its own repository, and the header comment there allows a package's owning repository to differ from the project's remote, so it must still be looked up. Add that case to the `test_worktree_create.sh` table.
4. **[Scope] Part 1 must leave `plan.md` unchanged.** At the post-merge plan checkpoint, step 13 offers `proceed` for Part 2 only when `plan.md` is unchanged since this review's commit. Any plan edit made during Part 1 sends Part 2 back through `plan-task` and `review-plan`.

### Summary

The second revision answers all three must-fix items and both suggestions. The new leave-out list is backed by the API record, though the plan does not cite it, and the split's boundary holds. Ready for Part 1, with four suggestions for the implementer.

### Recommended Actions

- [ ] Item 2: cite the dependabot and pages run evidence in the `merge_pr.sh` header, and say that a leave-out acts only before a check registers (suggestion 1).
- [ ] Item 2: record the coding-agent workflow as a third known gap (suggestion 2).
- [ ] Item 4: keep the qualified-ref lookup ahead of the no-slug skip, and test it (suggestion 3).
- [ ] Part 1: leave `plan.md` unchanged, so Part 2 can `proceed` (suggestion 4).

## Checkpoint
**Status**: complete
**When**: 2026-11-20 10:42 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

The owner's answer in the dialog, to "Approve this plan so implementation of part 1 starts?": "Approve (Recommended)". The dialog showed the two parts (part 1: items 1, 2, 3 and 5; part 2: item 4) and the choices listed for his veto (github.com only, no dispatch guard, the notice mark keyed on the hosted reviewer's phrase). The question reached him because the host had answered revise twice in a row. Plan Review b52a78d0 is ready with four suggestions for the implementer.

## Implementation
**Status**: complete
**When**: 2026-11-20 11:06 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-428 at `2e560433`

Part 1 of 2 (items 1, 2, 3 and 5; `Part of #428`). Item 4 is part 2 and was not touched. `plan.md` is unchanged since the Plan Review at b52a78d0.

- Item 1 (`f2a320bf`): `dispatch_phase.sh` puts the job-count rule (`-j 4`, `--parallel 4`, never the flag alone, copied text included) in `conventions=` for every phase and issue type; a paragraph in run-issue step 4 says the host checks text it copies into a handoff; a row in `host_standing_rules.md` with its reason (the 2026-11-09 out-of-memory crash) and source; `script_reference.md` row; `test_dispatch_phase.sh` asserts the counted examples for every phase and for a project implement handoff. No guard, as planned.
- Item 2 (`a563428f`): `merge_pr.sh` reads `actions/workflows?per_page=100` and counts active entries not on the leave-out list (the hosted reviewer's two paths, `dynamic/dependabot/`, `dynamic/pages/`); a list past one page or with no `workflows` array is unknown. Next to the list it cites the Dependabot and Pages evidence (123 runs, all `event: dynamic` on the default branch, none linked to a pull request) and says a leave-out acts only before any check registers. The header records three known gaps; the third is the hosted coding agent's `dynamic/copilot-swe-agent` workflow, which is counted, so a repository with only the reviewer and the coding agent still waits 120 s and gets the `--no-wait` hint (Plan Review suggestions 1 and 2). `test_merge_pr_gate.sh`: the 17 bare `total_count` fixtures go through `workflows_json`; new cases (a)-(f) as planned, plus a no-`workflows`-array case, the Dependabot and Pages prefixes, and the coding agent. Case (a) also checks that the run takes less than its 20 s grace window.
- Item 3 (`11b7e00f`): `worktree_remove.sh` runs `find -P <tree> -type d ! -perm -u=w -exec chmod u+w {} +` before each `git worktree remove` and before the final `rm -rf` (guarded; a symlinked tree is skipped; a failed chmod does not hide the removal error). The header and `script_reference.md` row say so. New suite `test_worktree_remove.sh`: plain and `--force` removal of a gitignored read-only install tree, a dirty tracked file still refused, and a symlink to a read-only directory outside the tree left alone; it skips as root.
- Item 5 (`2e560433`): `fetch_pr_reviews.sh` adds `notice_only` to every review, true only for the hosted reviewer's account, COMMENTED, no inline comments and the phrase "unable to review this pull request". run-issue step 9 now gives the notice's real shape (a review, not an issue comment), the `notice_only` reading, and a bound of about 900 s on the host's review poll with its two reasons; `merge_pr.sh`'s 1800 s review hold is described and left as it is. One line in triage-reviews and the `script_reference.md` row. New suite `test_fetch_pr_reviews.sh`: three notice wordings are marked, six non-notices are not.
- Consequence not named in the plan: `test_script_tests_hook_scope.sh` needs a `ROOT_READERS` entry for each new suite (`test_worktree_remove.sh`, `test_fetch_pr_reviews.sh`), or it fails. Both entries are added.

Suites run, each on its own with `bash` (last result line):
- `test_dispatch_phase.sh`: test_dispatch_phase: 244 passed, 0 failed
- `test_merge_pr_gate.sh`: test_merge_pr_gate: 210 passed, 0 failed
- `test_merge_pr.sh`: === Results: 175 passed, 0 failed ===
- `test_merge_pr_skill.sh`: test_merge_pr_skill: 132 passed, 0 failed
- `test_merge_pr_root_resolution.sh`: === Results: 6 passed, 0 failed ===
- `test_checkpoint_269.sh`: test_checkpoint_269: 43 passed, 0 failed
- `test_project_registry.sh`: === Results: 425 passed, 0 failed ===
- `test_user_tier_guard.sh`: test_user_tier_guard: 64 passed, 0 failed
- `test_package_issue_loop.sh`: test_package_issue_loop: 220 passed, 0 failed
- `test_records_write_gate.sh`: test_records_write_gate: 68 passed, 0 failed
- `test_review_code_convergence.sh`: test_review_code_convergence: 38 passed, 0 failed
- `test_validate_workspace_stale.sh`: test_validate_workspace_stale: 126 passed, 0 failed
- `test_ros2_colcon.sh` (it names `worktree_remove.sh`; run only, not edited): === Results: 1375 passed, 0 failed, 0 skipped ===
- `test_worktree_remove.sh` (new): test_worktree_remove: 16 passed, 0 failed
- `test_fetch_pr_reviews.sh` (new): test_fetch_pr_reviews: 11 passed, 0 failed
- `test_script_tests_hook_scope.sh` (changed): test_script_tests_hook_scope: 352 passed, 0 failed
- `test_skill_paths.sh`: test_skill_paths: 164 passed, 0 failed

Without the fix, the new tests fail: `test_merge_pr_gate.sh` 17 failed (case (a) included), `test_worktree_remove.sh` 5 failed, `test_fetch_pr_reviews.sh` 10 failed.

The full pre-commit pass and the full run of every suite are left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 11:13 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-428 at `5a857f7e`
**Base**: origin/main
**Depth**: Deep (reason: 13 files and about 600 changed lines outside the work plan, plus skill and knowledge files)
**Must-fix**: 2 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Part 1 only (items 1, 2, 3 and 5); no Part 2 file is touched. The `test_script_tests_hook_scope.sh` change is correct and needed: both new suites take the real root (`../../..`) and copy from `.agent/scripts`, so without the `ROOT_READERS` entries that suite fails. Static analysis: shellcheck at warning severity is clean on all nine changed shell files. Cross-model: Gemini ran (one must-fix, four suggestions, merged below). Codex failed: its model was at capacity. Claude adversarial ran: no must-fix, and the five touched suites pass.

### Findings
- [x] (must-fix) The `notice_only` match is an unanchored `contains` of the phrase. A real hosted review that has no inline comments and quotes or summarises the phrase would be marked and skipped. A review of this pull request is one plausible case. Anchor the match to the notice's opening, or add a length cap (notices are 117 to 122 characters, real reviews 204 or more), and add a negative test for a real review that quotes the phrase. Found by Gemini and the Claude adversarial reviewer. — `.agent/scripts/fetch_pr_reviews.sh:213`
- [x] (must-fix) The 900 s bound also cuts off a hosted review whose check-run exists and is still running. This contradicts the step's own wait condition (wait until the check-run has completed), and the step's own sample shows reviews at 17 and 30 minutes. A review that lands after triage is never triaged. Apply the 900 s bound only while no review check-run has appeared. Say what bounds a running one (for example `merge_pr.sh`'s 1800 s). Fix the measured-time sentence ("0 to 9 minutes" next to outliers at 17 and 30). — `.claude/skills/run-issue/SKILL.md:944`
- [x] (suggestion) A missing or non-numeric `total_count` reads as 0, which skips the guard for a list past one page, so `{"workflows":[]}` gives "no CI". Return "unknown" when `total_count` is not a number. Unreachable with GitHub's documented answer. Found by Gemini, the Claude adversarial reviewer and the lead. — `.agent/scripts/merge_pr.sh:1782`
- [x] (suggestion) A mechanism comment names a real project ("a GeoZui4D merge"). Reword it neutrally ("a project's merge"). The evidence stays in the issue and the plan. — `.agent/scripts/merge_pr.sh:1753`
- [x] (suggestion) Three changes to the `find` line: `chmod u+rwx` with `! -perm -u=rwx`, so a directory missing `x` or `r` is also repaired; `--` before the paths; and `-xdev`, so a bind mount inside the tree is not crossed. — `.agent/scripts/worktree_remove.sh:467`
- [x] (suggestion) The tests never exercise the aggregate (package) path where `_make_dirs_writable "$WORKTREE_DIR"` does real work, or an entry `$_dest` that is itself a symlink. — `.agent/scripts/tests/test_worktree_remove.sh`
- [x] (suggestion) `fetch_pr_reviews.sh` returns every review in the PR's history. At round 2 or later, an earlier round's `notice_only` review could end the wait for the current head. Say that only a review whose `commit_id` is the current `head_sha` ends the wait. — `.claude/skills/run-issue/SKILL.md:938`

## Implementation
**Status**: complete
**When**: 2026-11-20 11:40 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-428 at `a3d6f10f`
**Addressed**: Local Review (Pre-Push) at `5a857f7e` (2026-11-20 11:13 -05:00)
**Commits**: d2745d16, 22441d54, 98a20099, 8b9cd9a5, 6096fc74, a3d6f10f

Part 1 fix pass (items 1, 2, 3 and 5). No part 2 file touched; `plan.md` unchanged.

Must-fix 1, the host's question before patching the matcher a third time, answered from the code and the API:
- (a) Does the wait need the mark? No. run-issue step 9 waits until the `copilot-pull-request-reviewer` check-run has completed. On pull request 400 (read-only `gh api`), the check-run of each of five notice commits completed with conclusion `failure` within 1 to 4 s of the notice review. The notice is also a review on the head, so either wait condition is met without any mark.
- (b) Does triage need the mark? No. The notice body says in plain words that the review could not be done; a reader of the body sees it.
- So the mark is removed, not repaired: `fetch_pr_reviews.sh` is back to main's text, `test_fetch_pr_reviews.sh` (it tested only the mark) and its `ROOT_READERS` entry are deleted, the `script_reference.md` row is back to main's, and run-issue step 9 and triage-reviews describe the notice as a review by the hosted reviewer, read like any review, which holds no findings only because its own words say so. No review is skipped unread.

### Actions
- [x] (must-fix) `notice_only` unanchored match: mark removed (answers above) — `.agent/scripts/fetch_pr_reviews.sh:213` (d2745d16)
- [x] (must-fix) 900 s bound cut off a running review: the 900 s now applies only while no review check-run is in `ci_checks`; a running one is waited for, bounded by `merge_pr.sh`'s own hold (`MERGE_PR_CI_TIMEOUT_SECONDS`, 1800 s), after which the host records it, triages what exists and re-fetches before the merge checkpoint so a late review on the head goes to triage first; measured-times sentence corrected (0 to 30 minutes, most 1 to 6, all but two within 9, outliers 17 and 30). `merge_pr.sh` unchanged for this — `.claude/skills/run-issue/SKILL.md` step 9 (22441d54)
- [x] (suggestion) only a review whose `commit_id` is the current `head_sha` ends the round's wait — `.claude/skills/run-issue/SKILL.md` step 9 (22441d54)
- [x] (suggestion) `total_count` missing or not a number is "unknown"; new case ci-28d3 (missing, null, string) — `.agent/scripts/merge_pr.sh:1782` (98a20099)
- [x] (suggestion) mechanism comment names no project ("a project's merge") — `.agent/scripts/merge_pr.sh:1753` (8b9cd9a5)
- [x] (suggestion) `find -P -- <tree> -xdev -type d ! -perm -u=rwx -exec chmod u+rwx {} \;`. Also changed from `+` to `\;`: a batched chmod runs after the walk, too late for find to enter a directory that lacked r or x, so a read-only directory under one was missed (seen with GNU find 4.9.0) — `.agent/scripts/worktree_remove.sh:467` (6096fc74)
- [x] (suggestion) tests for the aggregate (package) path and a symlinked entry — `.agent/scripts/tests/test_worktree_remove.sh` (6096fc74, a3d6f10f). The symlinked-entry test found a defect the review did not name: `git worktree remove` given an entry that is a link acts on the checkout it points to (with `--force` it deleted that outside checkout's files and dropped its worktree record, after already removing the other entry). `worktree_remove.sh` now refuses, before anything is removed, an entry whose resolved path is outside the worktree; header and `script_reference.md` row updated.

Without the fixes the new tests fail: `test_worktree_remove.sh` 8 failed against the previous `worktree_remove.sh` (aggregate case 3, symlinked entry 5); ci-28d3's missing-`total_count` case gave no-ci under the previous jq.

Suites run, each on its own with `bash` (last result line):
- `test_worktree_remove.sh` (changed): test_worktree_remove: 37 passed, 0 failed
- `test_merge_pr_gate.sh` (changed): test_merge_pr_gate: 213 passed, 0 failed
- `test_script_tests_hook_scope.sh` (changed): test_script_tests_hook_scope: 347 passed, 0 failed
- `test_skill_paths.sh`: test_skill_paths: 164 passed, 0 failed
- `test_merge_pr.sh`: === Results: 175 passed, 0 failed ===
- `test_merge_pr_skill.sh`: test_merge_pr_skill: 132 passed, 0 failed
- `test_merge_pr_root_resolution.sh`: === Results: 6 passed, 0 failed ===
- `test_dispatch_phase.sh`: test_dispatch_phase: 244 passed, 0 failed
- `test_checkpoint_269.sh`: test_checkpoint_269: 43 passed, 0 failed
- `test_records_write_gate.sh`: test_records_write_gate: 68 passed, 0 failed
- `test_package_issue_loop.sh`: test_package_issue_loop: 220 passed, 0 failed
- `test_project_registry.sh`: === Results: 425 passed, 0 failed ===
- `test_user_tier_guard.sh`: test_user_tier_guard: 64 passed, 0 failed
- `test_validate_workspace_stale.sh`: test_validate_workspace_stale: 126 passed, 0 failed
- `test_ros2_colcon.sh` (names `worktree_remove.sh`; part 2 file, run only): === Results: 1374 passed, 1 failed, 0 skipped === — FAILED, not from this pass: "adapter sync: the tool's own report" expects `present, not touched (2)`, but the in-repo `repos-manifest` sync now prints `up to date (2)` (`tools/repos-manifest/src/repos_manifest/sync.py:644`, changed on main by PR 535's commits for issue 500 and brought in by the merge 5a857f7e). Those files are identical to origin/main, so main is expected to fail the same way. Not fixed here: `test_ros2_colcon.sh` is a part 2 file and the cause is outside this issue.

The full pre-commit pass and the full run of every suite are left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 11:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a17e31622226f8c63, resume 1 of 3)

**Branch**: feature/issue-428 at `54c28fe3`
**Base**: origin/main
**Depth**: Deep (reason: 12 files and about 610 changed lines outside the work plan, plus skill and knowledge files; a fix round is classified on the whole diff)
**Must-fix**: 2 | **Suggestions**: 5
**Round**: 2 | **Ship**: recommended — round 2: 2 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

Round 2, after the fix pass e4a9e5f1. The round-1 findings are settled as follows.

- The `notice_only` mark is removed, and the reasoning holds against step 9 as now written. The wait ends when the hosted reviewer's check-run completes, which happens within seconds of a could-not-review notice, and triage reads the notice's body. `fetch_pr_reviews.sh` and its `script_reference.md` row are back to main's text. `git grep notice_only` finds nothing outside the work plans.
- The `total_count` fix and the neutral comment are correct.
- The `\;` change is correct: the adversarial reviewer ran it, and it reaches a read-only directory under a directory with no search permission.
- The new refusal of an entry that leads outside the worktree is right. It handles relative links, a link to a sibling entry, a dangling link and a lookalike prefix path, and it refuses no real package layout. The one gap is the cd-failure message (must-fix 2).

Shellcheck at warning severity is clean. No real project name appears in mechanism text or fixtures; the one mention is the evidence column of `host_standing_rules.md`. The failure in `test_ros2_colcon.sh` does not come from this branch: the branch changes nothing under `tools/repos-manifest` or `.agent/project_types`, and the expected string and the new `sync.py` text are both on main as they are.

Reviewers:
- Gemini ran.
- Codex ran.
- Claude adversarial ran, with a fresh agent. `test_worktree_remove.sh` passed 37 and failed 0; `test_merge_pr_gate.sh` passed 213 and failed 0.

### Findings
- [x] (must-fix) The pre-merge re-fetch is written only inside the bullet for a running check-run. Two cases miss it. After the 900 s "never arrived" exit, a hosted review that starts late reaches the merge checkpoint unread. When a bookkeeping push has moved the head, a review that lands on an earlier commit of this round is not "on the head" and is missed too. Fix: before every merge checkpoint, fetch again, and send any hosted review the `## Integrated Review` has not read, whatever its `commit_id`, to `triage-reviews` first. Found by the lead and the adversarial reviewer. — `.claude/skills/run-issue/SKILL.md:954-972`
- [x] (must-fix) When `cd` into an entry fails (a directory with no search permission), `_real` is empty. The script then says the entry "leads outside this worktree through a symbolic link" and tells the user to delete a link that does not exist. Fix: when `_real` is empty and the entry is not a link, say the entry cannot be entered (permissions). Found by Gemini, the adversarial reviewer and the lead. — `.agent/scripts/worktree_remove.sh:406-410`
- [x] (suggestion) Say that a concluded `copilot-pull-request-reviewer` check-run ends the wait even when no review lands on the head, so that "only a review on the head counts" is not read as requiring one. Found by Gemini. — `.claude/skills/run-issue/SKILL.md:945-950`
- [x] (suggestion) Call `_make_dirs_writable "$WORKTREE_DIR"` once before the entry loop. Today a read-only container directory between the worktree and an entry makes `git worktree remove` fail part way. Found by Gemini. — `.agent/scripts/worktree_remove.sh:492-514`
- [x] (suggestion) "Mounts never crossed" overstates `-xdev`. A bind mount from the same filesystem has the same device and is crossed. `rm -rf` crossed it before this change too. Say "a mount of another filesystem is not crossed" here and in the `script_reference.md` row. Found by Codex, downgraded from its must-fix. — `.agent/scripts/worktree_remove.sh:31,480`
- [x] (suggestion) `plan.md` item 5 still describes the `notice_only` mark. Record the change in the plan or the pull request text. Found by Gemini, downgraded from its must-fix: plan drift is a suggestion, and the removal is reasoned in the Implementation entry. — `.agent/work-plans/issue-428/plan.md:50-55` (deferred: plan.md stays unchanged since its review so part 2 can go straight on; the host records the change (notice_only mark removed) in the pull request text)
- [x] (suggestion) The trap's `chmod -R u+w` cannot descend into the test's `chmod 600` directory. If the test fails before the repair, the sandbox leaks. Use `u+rwx`. Found by Gemini. — `.agent/scripts/tests/test_worktree_remove.sh:47`

## Implementation
**Status**: complete
**When**: 2026-11-20 12:05 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a9184401bb6c30a1f, resume 1 of 3)

**Branch**: feature/issue-428 at `2c82204f`
**Addressed**: Local Review (Pre-Push) at `54c28fe3` (2026-11-20 11:50 -05:00)
**Commits**: e15c60c4, 32269153, e6b46deb, 75af46ba, 2c82204f

Round 2 fix pass for part 1. No part 2 file touched; `plan.md` unchanged.

### Actions
- [x] (must-fix) pre-merge re-fetch on every path: the "Re-check CI" paragraph is now "Fetch again before every merge checkpoint", with two checks on the output. First, any hosted review the latest `## Integrated Review` has not read goes to `triage-reviews` first, whatever its `commit_id`; unread means its `**Sources**` line does not name it or its `**Reviews**` count is lower than now. Second, the CI-pending rule as before. The running-check-run bullet no longer carries its own copy. The step now says plainly that ending the wait (only the current head) and being read at triage (every review) are two different things — `.claude/skills/run-issue/SKILL.md` step 9 (e15c60c4)
- [x] (must-fix) an entry that cannot be entered and is not a link is refused with a permission message and the chmod to give it back, never the link message; new test (mode 600 entry). Against the previous script 2 checks fail — `.agent/scripts/worktree_remove.sh:406` (32269153)
- [x] (suggestion) a concluded `copilot-pull-request-reviewer` check-run ends the wait even with no review on the head — `.claude/skills/run-issue/SKILL.md` step 9 (e15c60c4)
- [x] (suggestion) `_make_dirs_writable "$WORKTREE_DIR"` once before the entry loop, after every refusal. The pass after the loop is dropped. A package worktree's entries are still walked on their own, which reaches an entry on another filesystem. The single-entry tree is not walked twice. New test: two entries in a read-only `layer_ws/src`. Against the previous script 3 checks fail — `.agent/scripts/worktree_remove.sh` (e6b46deb)
- [x] (suggestion) `-xdev` wording, "a mount of another filesystem", in the header, the comment and the `script_reference.md` row — `.agent/scripts/worktree_remove.sh:31,480` (75af46ba)
- [x] (suggestion) plan drift — `.agent/work-plans/issue-428/plan.md:50-55` (deferred: addressed by the host, which records the change, the `notice_only` mark removed, in the pull request text; `plan.md` stays unchanged since its review so part 2 can go straight on)
- [x] (suggestion) the test trap uses `chmod -R u+rwx`, checked to reach a read-only directory under a mode 600 one — `.agent/scripts/tests/test_worktree_remove.sh:47` (2c82204f)

Suites run, each on its own with `bash` (last result line):
- `test_worktree_remove.sh` (changed): test_worktree_remove: 46 passed, 0 failed
- `test_skill_paths.sh`: test_skill_paths: 164 passed, 0 failed
- `test_script_tests_hook_scope.sh`: test_script_tests_hook_scope: 347 passed, 0 failed
- `test_merge_pr.sh`: === Results: 175 passed, 0 failed ===
- `test_merge_pr_skill.sh`: test_merge_pr_skill: 132 passed, 0 failed
- `test_merge_pr_gate.sh`: test_merge_pr_gate: 213 passed, 0 failed
- `test_merge_pr_root_resolution.sh`: === Results: 6 passed, 0 failed ===
- `test_validate_workspace_stale.sh`: test_validate_workspace_stale: 126 passed, 0 failed
- `test_user_tier_guard.sh`: test_user_tier_guard: 64 passed, 0 failed
- `test_project_registry.sh`: === Results: 425 passed, 0 failed ===
- `test_ros2_colcon.sh` (names `worktree_remove.sh`; part 2 file, run only): === Results: 1374 passed, 1 failed, 0 skipped === — FAILED, the same case as round 1 and not from this branch ("adapter sync: the tool's own report": the in-repo `repos-manifest` now prints `up to date (2)`; the round-2 review confirmed both strings are on main as they are).

The full pre-commit pass and the full run of every suite are left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 12:06 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a17e31622226f8c63, resume 2 of 3)

**Branch**: feature/issue-428 at `84e27963`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — round 3: 1 mechanical must-fix (prev 2), not rising — fix and ship rather than another full round

Scope: the round-2 findings and the fix diff since f60c8faf. Cross-model: skipped (round-3 convergence check, per handoff).

Round-2 findings:
- Must-fix 1 (re-fetch on every path): partly fixed. The re-fetch now runs before every merge checkpoint. Its test for a review not yet read keys on fields the entry does not carry reliably (the new must-fix below).
- Must-fix 2 (the false link message): fixed. A new permission message, and a test with a mode 600 entry.
- Concluded check-run ends the wait: fixed.
- `_make_dirs_writable "$WORKTREE_DIR"` before the loop: fixed. It runs at line 510, after every refusal: the owner and link checks, and the dirty check at 473. The dropped pass after the loop covered nothing that remains: the container was walked before the loop, an entry on another filesystem is still walked on its own, and removal creates no read-only directory.
- `-xdev` wording: fixed.
- Test trap: fixed.
- Plan drift: taken by the host, recorded in the pull request text.

The fix diff introduces no other defect.

Verified:
- `test_worktree_remove.sh`: 46 passed, 0 failed, run with `bash`.
- shellcheck at warning severity: clean on `worktree_remove.sh` and its test.

### Findings
- [x] (must-fix) The test for a review not yet read keys on a `**Reviews**` line. The `## Integrated Review` entry that triage-reviews persists has no such line (`triage-reviews/SKILL.md:396-412`; `**Reviews**` is only in its conversation report, line 292). Its `**Sources**` line is a count with optional examples, not a required list of each review and its commit. As written, the check can miss a late review. Fix: key the check on a field that exists, for example any review whose `submitted_at` is later than the latest Integrated Review's `**When**`; or make triage-reviews write the field it names. — `.claude/skills/run-issue/SKILL.md:1008-1013`

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:06 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 left one must-fix open, so publishing is not clean; first host address at this checkpoint)
**After**: rounds
**Decision**: address

Read: the Local Review (Pre-Push) at fc7eddcb, round 3, verdict changes-requested, Ship recommended, one must-fix and no suggestions: run-issue step 9's test for a review the latest Integrated Review has not read is keyed on a Reviews line that triage-reviews does not write into the entry and a Sources line that is a count, so the check can miss a late review. It goes back for one fix, keyed on fields that exist. No full pass was run: publish was not the chosen answer.

## Implementation
**Status**: complete
**When**: 2026-11-20 12:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a9184401bb6c30a1f, resume 2 of 3)

**Branch**: feature/issue-428 at `5509c1ac`
**Addressed**: Local Review (Pre-Push) at `84e27963` (2026-11-20 12:06 -05:00)
**Commits**: 5509c1ac

Round 3 fix pass for part 1, answering the Checkpoint (address) at aa667cb2. Skill text only; no part 2 file touched; `plan.md` unchanged; nothing added to what `triage-reviews` writes.

Fields checked against the code:
- `submitted_at`: `fetch_pr_reviews.sh` prints it on each review (lines 105 and 176), copied from GitHub's reviews API. It is UTC, e.g. `2026-10-20T18:56:41Z` (read-only `gh api` of pull request 400 in round 1).
- `**When**`: the `## Integrated Review` template in `triage-reviews/SKILL.md` (lines 396-412) writes `**When**: <YYYY-MM-DD HH:MM ±HH:MM>`. It has no `**Reviews**` line, and its `**Sources**` line is a count.
- GNU `date -d` reads both forms: `2026-11-20 12:06 -05:00` gives `2026-11-20T17:06:00Z`.

### Actions
- [x] (must-fix) the not-yet-read test in "Fetch again before every merge checkpoint" now compares each review's `submitted_at` with the latest Integrated Review's `**When**`, both turned into the same instant (e.g. `date -d ... +%s`). A review submitted at or after the start of that minute counts as not read and goes to `triage-reviews` first, whatever its `commit_id`; so does one whose time is empty or unreadable. The text says the rule errs toward triaging again — `.claude/skills/run-issue/SKILL.md:1008` (5509c1ac)

Suites run, each on its own with `bash` (last result line):
- `test_skill_paths.sh`: test_skill_paths: 164 passed, 0 failed

The full pre-commit pass and the full run of every suite are left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 12:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a17e31622226f8c63, resume 3 of 3)

**Branch**: feature/issue-428 at `fdee5c9a`
**Base**: origin/main
**Depth**: Deep (reason: round 4 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 0
**Round**: 4 | **Ship**: recommended — round 4: 1 mechanical must-fix (prev 1), not rising — fix and ship rather than another full round

Scope: the round-3 must-fix and commit 5509c1ac. Cross-model: skipped (round-4 convergence check, per handoff).

The round-3 must-fix is partly fixed. Both fields now exist under the names the text uses: `submitted_at` in the `fetch_pr_reviews.sh` output, and `**When**` in the persisted `## Integrated Review`. Three parts of the comparison check out:
- Time zones: GNU `date -d` gives the same epoch for `2026-11-20 12:06 -05:00` and `2026-11-20T17:06:00Z`.
- "At or after the start of that minute" is right for a `**When**` kept to the minute.
- An empty time counts as not read. Note that `date -d ''` exits 0 with midnight, so the explicit emptiness test in the text is what catches it.

The paragraph agrees with the rest of step 9. The flaw is the reference time (below).

### Findings
- [x] (must-fix) `**When**` is written when triage-reviews finishes, but triage fetches the reviews at its step 3, minutes earlier. A review submitted after that fetch and before the minute of `**When**` counts as read but never was. That is the late-review case this rule exists for, and the rule errs toward skipping there, not toward triaging again. Fix: compare against a time no later than triage's fetch, for example the time the host dispatched `triage-reviews`, which the host notes when it dispatches. — `.claude/skills/run-issue/SKILL.md:1008-1019`

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:09 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 4 left one must-fix open, so publishing is not clean; second host address in a row at this checkpoint, the next answer here is the owner's)
**After**: rounds
**Decision**: address

Read: the Local Review (Pre-Push) at a28f0757, round 4, verdict changes-requested, Ship recommended, one must-fix: run-issue step 9 compares a review's time with the Integrated Review's When, which is written when triage finishes, minutes after triage fetched the reviews, so a review that lands in between counts as read when it was not. This is the third finding in how that paragraph tells a read review from an unread one (fields that are not written, then the wrong reference time), so the mechanism changes rather than the wording: triage-reviews records in its entry the time it fetched the reviews, and the rule compares against that. No full pass was run: publish was not the chosen answer.

## Implementation
**Status**: complete
**When**: 2026-11-20 12:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a9184401bb6c30a1f, resume 3 of 3)

**Branch**: feature/issue-428 at `c458e132`
**Addressed**: Local Review (Pre-Push) at `fdee5c9a` (2026-11-20 12:08 -05:00)
**Commits**: c458e132

Round 4 fix pass for part 1, answering the Checkpoint (address) at 2f45f595: the mechanism changes, and the entry now records the fact the rule needs. No part 2 file touched; `plan.md` unchanged.

Readers of `## Integrated Review` entries, checked before adding the field. None needs a change:
- `progress_read.py` parses every `**Key**: value` header line into a generic `fields` map and has no allowlist. A sample entry with `**Fetched**` parsed with its correlation and findings unchanged.
- `review_progress.sh`, `dispatch_phase.sh` and `merge_pr.sh`'s gate read only the type, status, correlation, findings and `**Verdict**`.
- `_progress_entry.sh` validates the heading type only.
- ADR-0013 lists required header and correlation fields only, no per-type field list. The progress tests (`test_progress_read.*`, `test_triage_reviews_integration.sh`) assert no closed field set.
- So the change is the template line, triage-reviews step 3, and run-issue step 9, with no field list or test to extend.

### Actions
- [x] (must-fix) reference time now taken before the fetch — `.claude/skills/triage-reviews/SKILL.md` step 3 and template; `.claude/skills/run-issue/SKILL.md` step 9 (c458e132)
  - triage-reviews step 3 notes the local time just before running `fetch_pr_reviews.sh`, and the template writes it as `**Fetched**: <YYYY-MM-DD HH:MM ±HH:MM>`.
  - A run with only the local timeline as a source still writes the field.
  - run-issue step 9: a review counts as not read when its `submitted_at` is at or after the start of the `**Fetched**` minute, when its time is empty or cannot be read (empty is tested first, since `date -d ''` gives midnight), or when the entry has no `**Fetched**` line. All three err toward triaging again.

Suites run, each on its own with `bash` (last result line):
- `test_skill_paths.sh`: test_skill_paths: 164 passed, 0 failed
- `test_triage_reviews_integration.sh`: test_triage_reviews_integration: 69 passed, 0 failed
- `test_checkpoint_269.sh` (names `triage-reviews/SKILL.md`): test_checkpoint_269: 43 passed, 0 failed

The full pre-commit pass and the full run of every suite are left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 12:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-428 at `a8a95eb9`
**Base**: origin/main
**Depth**: Deep (reason: round 5 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 1
**Round**: 5 | **Ship**: recommended — round 5: 1 mechanical must-fix (prev 1), not rising — fix and ship rather than another full round

Scope: the round-4 must-fix and commit c458e132, with bd6937f4 and a8a95eb9 (records only). Cross-model: skipped (round-5 convergence check, per handoff).

Round-4 must-fix (reference time later than the fetch): fixed. `**Fetched**` is the first act of triage-reviews step 3, before `fetch_pr_reviews.sh`, and the text says a run whose only source is the local timeline still notes it and writes the field. triage-reviews fetches the reviews itself; nothing hands it the host's earlier JSON, and any later read in the same run only makes the noted time more conservative. A review read in the `**Fetched**` minute is triaged once more, and the next triage notes a later minute, so a review with a real `submitted_at` reaches "read" and the rule ends. The no-`**Fetched**` case ends the same way: the re-triage writes a new entry that has the line.

Readers of `## Integrated Review`, spot-checked: the claim holds. `progress_read.py` builds `fields` from every `**Key**: value` header line (no allowlist) and looks fields up by name; `dispatch_phase.sh` routes this type on its open boxes only; `_progress_entry.sh` names the type only; `merge_pr.sh` reads status, correlation and boxes; sitrep reads type and boxes.

The one defect left is a case the rule never ends (below), present since 5509c1ac and kept by c458e132.

### Findings
- [x] (must-fix) A review in state `PENDING` (a draft its author has started and not submitted) has no `submitted_at`. GitHub's list-reviews endpoint returns the authenticated user's own draft, and `fetch_pr_reviews.sh` keeps every review with no state filter (lines 101-111), so a draft by the account the loop runs as comes out with `submitted_at: null`. Step 9 counts that as "empty or cannot be read", sends it to triage-reviews, and on the next re-fetch it is still null, so it is never read and the merge checkpoint is never reached. Fix: skip a review whose `state` is `PENDING` (not submitted, nobody's review yet); an empty time on any other review still counts as not read. — `.claude/skills/run-issue/SKILL.md:1015-1018`
- [x] (suggestion) The margin between `**Fetched**` and the real fetch is only the part of the minute already gone, 0 to 59 s. A local clock running ahead of GitHub's, or a review GitHub stamps just before a minute boundary but lists a moment later, can fall before the `**Fetched**` minute without having been read. Comparing against one minute before `**Fetched**` closes both at the cost of an occasional second triage, which the rule already accepts. — `.claude/skills/run-issue/SKILL.md:1015-1016`

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:14 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: rounds
**Decision**: address

The owner's answer in the dialog, to "Fix F1 and F2 once more before publishing?": "Fix once more (Recommended)". F1 is the round 5 must-fix (Local Review (Pre-Push) at 8e35a651): run-issue step 9's rule can loop forever on a review in state PENDING, which has no submitted_at; skip a review whose state is PENDING. F2 is that review's suggestion: compare against one minute before Fetched. The question reached him because the host had answered address twice in a row at this checkpoint. In the same dialog he answered a second question, about a stale check in test_ros2_colcon.sh that comes from main and not from this branch: "Issue + fix main first (Recommended)", so part 1 is published only after that fix is on main and merged into this branch.

## Implementation
**Status**: complete
**When**: 2026-11-20 12:16 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-428 at `e668b698`
**Addressed**: Local Review (Pre-Push) at `a8a95eb9` (2026-11-20 12:14 -05:00)
**Commits**: e668b698

Round 5 fix pass for part 1, answering the Checkpoint (address, owner: "Fix once more (Recommended)") at 5bac9083. Fresh dispatch after the earlier fix agent reached its resume limit. Only run-issue step 9's "Fetch again before every merge checkpoint" paragraph changed; no part 2 file touched; `plan.md` unchanged.

Field confirmed before writing: `fetch_pr_reviews.sh` emits each review's state as `state` under `reviews[]` (line 107 builds it from GitHub's `.state`, line 177 carries it into the output). Script unchanged.

### Actions
- [x] (must-fix) F1: a review whose `state` is `PENDING` is skipped (an unsubmitted draft, no `submitted_at`, nobody's review to read yet) and never sends the host back to triage; an empty or unreadable time in any other state still counts as not read — `.claude/skills/run-issue/SKILL.md` step 9 (e668b698)
- [x] (suggestion) F2: the comparison is against one minute before the start of the `**Fetched**` minute (`$(( $(date -d '<Fetched>' +%s) - 60 ))`), with the reason (local clock ahead of GitHub's, or a review listed a moment after it was stamped) and the cost (an occasional second triage) — `.claude/skills/run-issue/SKILL.md` step 9 (e668b698)

### Termination, case by case
- Submitted before the margin: it counts as read and is never sent to triage, so it cannot start a round.
- Submitted inside the margin: it is triaged; that triage notes a later `**Fetched**` minute, and since `submitted_at` is fixed and `**Fetched**` only moves forward with the clock, it falls before the margin once a triage starts about two minutes after it, so it is read at most a few times, in practice once more.
- PENDING: skipped outright, so it never sends the host round; once submitted it has a time and becomes one of the two cases above.
- Any other state with an empty or unreadable time: this can still loop. Each triage reads it, the next re-fetch returns the same empty time, and it counts as not read again. Nothing in the text bounds it, and `dispatch_phase.sh`'s MAX_ROUNDS counts only pre-push reviews, not Integrated Reviews. What bounds it is GitHub's contract alone: every submitted review (any state but PENDING) carries `submitted_at`, so the case needs a GitHub or fetch fault. Left as is: a stop rule for it was not part of the owner's answer.

Suites run, each on its own with `bash` (last result line):
- `test_skill_paths.sh`: test_skill_paths: 164 passed, 0 failed

The full pre-commit pass and the full run of every suite are left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-20 12:18 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a8838d81e2a8db33f, resume 1 of 3)

**Branch**: feature/issue-428 at `5d58e7d9`
**Base**: origin/main
**Depth**: Deep (reason: round 6 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 6 | **Ship**: recommended — no must-fix findings

Scope: the round-5 findings and commit e668b698, with 5bac9083 and 5d58e7d9 (records only). Cross-model: skipped (round-6 convergence check, per handoff).

Round-5 findings:
- F1 (a PENDING review loops the rule): fixed. Step 9 skips a review whose `state` is `PENDING` before any time test, and the empty-or-unreadable clause now reads "in any state but `PENDING`". `fetch_pr_reviews.sh` carries `state` from GitHub's `.state` (line 107).
- F2 (one-minute margin): fixed. The comparison is against `$(( $(date -d '<Fetched>' +%s) - 60 ))`. Checked: `2026-11-20 12:06 -05:00` gives 1795194360, minus 60 gives 1795194300, the same as `2026-11-20T17:05:00Z`. The reason and the cost are stated.

The fix diff introduces no defect. Termination holds: `submitted_at` is fixed and each triage notes a later `**Fetched**`, so a review stops counting as not read after at most a few triages. triage-reviews step 3 still reads true: a review landing during or after its run is at or after the `**Fetched**` minute, so it is also after the earlier reference time.

A review in any state but PENDING with an empty or unreadable `submitted_at` (left alone by the fix pass, judged here): acceptable as written, not a finding. GitHub stamps `submitted_at` when a review is submitted, and every state but PENDING is a submitted review (DISMISSED keeps its time). `fetch_pr_reviews.sh` exits 1 when the reviews call fails rather than emitting partial records (lines 95-98). GitHub writes ISO 8601 UTC, which `date -d` reads. So the case needs GitHub to break its own contract. If it did, the result is a visible repeated triage dispatch, never a merge past an unread review, which is the side the rule is meant to err on.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-20 12:58 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the pre-push review approved with no findings and the host's full pass passed on the head to be pushed)
**After**: publish
**Decision**: publish

Read: the Local Review (Pre-Push) at ed9e28df, round 6, approved, Ship recommended, no must-fix and no suggestions. After it, main was merged into the branch once more (a2a8b3ab): it brought in the one-line test fix of pull request 540 (part 1 of issue 539), which the owner asked to land on main before this branch is published, and that issue's work-plan records. The host's full pass (pre-commit over the branch's files against origin/main, no SKIP) then passed on that head: every hook Passed or had no files, the script test suites hook included. Part 1 of two: the pull request says Part of #428.

## Local Review
**Status**: complete
**When**: 2026-11-20 13:20 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #542 at `47a1ea83`
**Depth**: Deep (reason: 11 files and 758 changed lines, skill and knowledge files included; the first PR-mode review, classified on the whole diff, with cross-model)
**Must-fix**: 1 | **Suggestions**: 3

Scope check first. The host's account holds:
- `git diff ed9e28df HEAD -- . ':!.agent/work-plans'` is one line in `test_ros2_colcon.sh`. That line is main's own change: commit 1164e166, pull request 540.
- The pull request's patch against main, without work plans and `index` lines, is byte-identical to the round-6 approved patch against its own base (916aab50).
- Main's merge changed no file this pull request touches.

So this review covers the same code round 6 approved. The skill still classifies a first PR-mode review on the whole diff. Rounds 3 to 6 were narrow checks with no outside models, so this review read the whole diff again, Gemini and Codex included.

Static analysis: shellcheck at warning severity is clean on all seven changed shell files. It was run from the workspace `.venv`, because shellcheck is not on PATH.

Hosted reviews: `fetch_pr_reviews.sh --pr 542` shows no reviews, no comments and no `copilot-pull-request-reviewer` check-run.

Plan drift: the `notice_only` mark is not in the diff. The pull request text records that it was built and then removed. Not a finding.

The must-fix was reproduced in a sandbox:
- Setup: a package worktree with an uncommitted change in `layer_ws/src/pkg_a`, and `layer_ws/src` set to mode 600.
- This branch: exit 0, "Worktree removed successfully", the change deleted, and the package repository's worktree record left `prunable`.
- Main's `worktree_remove.sh`: exit 1, `rm: cannot remove ... Permission denied`, the entry and its change kept.

Reviewers:
- Gemini ran, EXIT 0. It found the must-fix, plus suggestion 2 and suggestion 3.
- Codex ran, EXIT 0. It found the must-fix, plus suggestion 1 and suggestion 3.
- Claude adversarial ran with a fresh agent. It made no must-fix and found suggestion 3. `test_worktree_remove.sh`: 46 passed, 0 failed. `test_merge_pr_gate.sh`: 213 passed, 0 failed. `test_dispatch_phase.sh`: 244 passed, 0 failed. `test_script_tests_hook_scope.sh`: 347 passed, 0 failed.

Dropped:
- Gemini's plan-drift item: the pull request text records the change.
- Gemini's claim that `WORKTREE_DIR` is not canonical: false, it is resolved with `pwd -P` at line 354.
- Gemini's claim that a human review ends the wait: the text says "a hosted review".
- Gemini's point about GNU `date` portability: the examples are marked "e.g.", and the workspace runs on Linux.

### Findings
- [x] (must-fix) A package entry under a folder with no search permission is treated as already gone. `[ ! -d "$_dest" ]` is false on EACCES as well as on ENOENT, so the entry gets no owner, the link check is skipped, and the dirty preflight (line 460) is skipped too. `_make_dirs_writable "$WORKTREE_DIR"` (line 510) then opens the folder, and `rm -rf` (line 534) deletes the checkout, uncommitted work included, without `--force`. Main fails safe here. The "cannot enter ... or on a folder above it" message at line 412 cannot be reached for a folder above the entry. Fix: tell an unreachable entry from a missing one before any repair. For example, refuse when a folder between `WORKTREE_DIR` and the entry cannot be entered. Add a test: a dirty entry under a mode 600 `layer_ws/src`, plain removal, refused, change kept. Found by the lead (reproduced), Codex and Gemini. — `.agent/scripts/worktree_remove.sh:399`
- [x] (suggestion) `find -xdev` still tests and chmods the top folder of a mount of another filesystem; it only stops descending into it. Giving that folder u+rwx lets the later `rm -rf` unlink the mount's top-level entries, and `rm -rf` already crosses mounts, before this change too. Consider skipping mount-point folders in the chmod, or `rm -rf --one-file-system`. Found by Codex, downgraded from must-fix: the setup is contrived, and the crossing predates this change. — `.agent/scripts/worktree_remove.sh:500`
- [x] (suggestion) "Its cost is an occasional second triage" understates it. The review that ends the wait is handed to triage within a minute or two. A `**Fetched**` noted that soon, taken back to the start of its minute and then by 60 s more, will often be at or before that review's `submitted_at`, so a second triage before the merge checkpoint is likely on many pull requests. State the cost as it is, or key "read" on the review ids that triage records. Found by Gemini, downgraded from must-fix: it errs in the safe direction. — `.claude/skills/run-issue/SKILL.md:1019-1024`
- [x] (suggestion) A non-PENDING review with an empty or unreadable `submitted_at` is sent to triage before every checkpoint, with no end. Round 6 judged this acceptable, because it needs GitHub to break its own contract. Three reviewers raised it independently this round. A one-line cap would make the rule provably end: at most one more triage for the same review id, then report it to the owner. Found by Codex, Gemini and the Claude adversarial reviewer. — `.claude/skills/run-issue/SKILL.md:1025-1028`

## Implementation
**Status**: complete
**When**: 2026-11-20 13:37 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #542 at `cc145c26`
**Addressed**: Local Review at `47a1ea83` (2026-11-20 13:20 -05:00)
**Commits**: d8bcf950, 49def999, 027c0b26, cc145c26

### Actions
- [x] (must-fix) An entry under a folder with no search permission was taken as gone and deleted with its uncommitted work. Now each entry's path is walked down from the worktree (`_entry_reach`): a name is looked up only in a folder already entered, so a failed lookup means "not there"; a folder on the way that cannot be entered is refused before any removal or chmod, plain and --force, naming the folder and the `chmod u+rwx` that fixes it. Test first: the reviewer's case (dirty entry under a mode 600 `layer_ws/src`) failed 14 checks before the fix (exit 0, change deleted, mode opened) and passes after; a genuinely absent entry, and one under a missing folder, are still skipped and the rest removed. — `.agent/scripts/worktree_remove.sh:399`
- [x] (must-fix, same pass) Other "nothing to do" decisions that access denial could fake, checked: the dirty preflight's `git -C status` reads a folder it cannot open (mode 000) as clean with exit 0; it is now refused without --force when status fails or reports a permission denial (test failed before: the tree was chmodded before git's own check refused; passes after). The preflight now skips only entries proven gone (empty owner), not `[ -d ]`. Left as is, fail-safe: line 350 `[[ ! -d WORKTREE_DIR ]]` refuses (wording says "does not exist" when unreachable, never removes); the entry's own `cd`/`git -C rev-parse` failures refuse; the removal loop's `[ -d ]` runs after the chmod, and a skip there leaves `rm -rf` unable to enter the folder, so it fails rather than deletes; `_make_dirs_writable`'s `[ -d ]` skip changes nothing; the branch lookups (lines 333 and the closing hints) only print. — `.agent/scripts/worktree_remove.sh:460`
- [x] (suggestion) The chmod now changes only folders on the walk's starting device, so a mount of another filesystem's top folder keeps its mode (`find -xdev` alone still listed it). Test in a user and mount namespace (`unshare -rm`, skipped where not allowed): tmpfs top folder stays 555, a same-filesystem folder gets u+rwx; the previous find line gave the mount top 755 in the same setup. Wording in the comment, header and script reference corrected: `rm -rf` still deletes into a mount it can already write, as before. — `.agent/scripts/worktree_remove.sh:500`
- [x] (suggestion) Second-triage cost: replaced, per host direction, by recording what was read. `triage-reviews` writes `**Reviews-read**: <review_id>, ...` (or `none`) for every non-PENDING review fetched, replacing `**Fetched**`; `fetch_pr_reviews.sh` prints `review_id` at line 104 (`review_id: .id`), passed to the output at line 175. `progress_read.py` parses `**Reviews-read**:` as a field (checked on a sample entry). — `.claude/skills/run-issue/SKILL.md:1008`, `.claude/skills/triage-reviews/SKILL.md:126`
- [x] (suggestion) Endless triage on an unreadable `submitted_at`: gone with the time comparison; run-issue step 9 now says a non-PENDING review whose `review_id` is not on the latest Integrated Review's line is unread, an entry without the line counts as none read. Every `**Fetched**` and time-comparison trace removed from both skills; the separate rule that only a review on the current head ends the WAIT is unchanged. — `.claude/skills/run-issue/SKILL.md:1008`

### Why the step 9 rule now ends
- A review already on the list: read, no triage.
- A new review: one triage, which lists its id, so the next fetch finds it read.
- A PENDING review: never sends to triage and is never listed; once submitted (same id) it is new once, as above.
- An entry without the field: counts as none read, so one triage writes the field, and the cases above apply.

### Suites run (each on its own, the full pass left to the host)
- test_worktree_remove.sh: 74 passed, 0 failed
- test_merge_pr_root_resolution.sh: 6 passed, 0 failed
- test_merge_pr.sh: 175 passed, 0 failed
- test_merge_pr_skill.sh: 132 passed, 0 failed
- test_project_registry.sh: 425 passed, 0 failed
- test_merge_pr_gate.sh: 213 passed, 0 failed
- test_script_tests_hook_scope.sh: 347 passed, 0 failed
- test_validate_workspace_stale.sh: 126 passed, 0 failed
- test_ros2_colcon.sh: 1375 passed, 0 failed, 0 skipped
- test_user_tier_guard.sh: 64 passed, 0 failed
- test_skill_paths.sh: 164 passed, 0 failed

No part 2 file and not `plan.md` touched. Scratch probe files in the session scratchpad were left: their delete was denied by the permission check.

## Local Review
**Status**: complete
**When**: 2026-11-20 13:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent ae4a8940bb75088a1, resume 1 of 3)

**PR**: #542 at `d2adb33a`
**Depth**: Deep (reason: 11 files and about 900 changed lines, skill and knowledge files included; a fix round is classified on the whole diff, so cross-model ran)
**Must-fix**: 0 | **Suggestions**: 3

Re-review after the fix pass (d8bcf950, 49def999, 027c0b26, cc145c26; Implementation entry d2adb33a). This is PR-mode round 2. The verdict is approved because no finding is a must-fix, per the handoff.

Earlier findings (Local Review e7ab04e3):
- Must-fix (an entry under a folder with no search permission was taken as gone and deleted): fixed. My reproduction against the pushed head covers 20 shapes:
  - Refused, change kept, plain and `--force`: a parent with no search permission (600), a grandparent with read only (400), an entry with mode 000.
  - Dirty check reached as before: a parent with search only (100), and a dirty entry under a link inside the tree.
  - Refused without `--force`, removed with it: an entry with no read permission (300), clean or dirty, and an untracked folder with mode 000.
  - Refused through the link message, outside checkout kept: a parent that is a link out of the tree.
  - Removed, with the outside checkout and its permissions kept: a parent link to a folder that cannot be reached.
  - Removed as before: a healthy package worktree, a read-only install tree, and an ignored `build/` with mode 000 or 555 (`git status` never opens an ignored folder, so the new refusal does not block it).
  - Both refusals stop the run before any chmod or removal. Refusing an unreadable `git status` without `--force` is right. `--force` removing an entry git cannot fully read is what `--force` already means.
- Suggestion (chmod of a foreign mount's top folder): partly fixed. The chmod now changes only folders on the walk's own device. `rm -rf --one-file-system` was not taken; the comment says so. The mount test ran here and was not skipped.
- Suggestion (second-triage cost): fixed. The time rule is replaced by `review_id`s, and no `**Fetched**` or time comparison is left in either skill.
- Suggestion (endless triage on an unreadable time): fixed. Each review sends the host back to triage at most once.

The `**Reviews-read**` rule ends in every case:
- `review_id`, `state` and `commit_id` are real fields: `fetch_pr_reviews.sh:104-108,175`.
- The list is cumulative, and the latest entry is the one read.
- An entry with no such line counts as none read.
- A PENDING draft keeps its id after it is submitted and is then new once.
- A DISMISSED review keeps its id and needs no new read: right.
- The rule that only a review on the head ends the wait reads correctly beside it, and is unchanged.

Verified:
- shellcheck at warning severity is clean on `worktree_remove.sh` and its test.
- `test_worktree_remove.sh`: 74 passed, 0 failed.

Reviewers:
- Gemini ran, EXIT 0. It found suggestions 1 and 2. Dropped from its review:
  - Plan drift: recorded in the pull request text.
  - "Field names unverified": they are real.
  - A wait-end on a non-hosted review: the text says "hosted".
  - `WORKTREE_DIR` not physical: it is resolved with `pwd -P` at line 354.
  - An EPERM wording point: marginal.
  - `none` on a local-only triage: there are no pull-request reviews then, and the rule still ends.
- Codex ran, EXIT 0. It found suggestion 3 (downgraded from must-fix). Its plan-drift point was dropped.
- The Claude adversarial reviewer ran, with a fresh agent. No must-fix. It confirmed that `rm -rf` still crosses a writable mount, which the comment records.

### Findings
- [ ] (suggestion) A folder on an entry's path that is a symbolic link is not recognised. When the link's target has no search permission, the refusal names the link and advises `chmod u+rwx <link>`, which follows the link and changes a folder outside the worktree. The script itself changes nothing (reproduced: the outside mode stays 600). The same happens at line 452 for an entry with no search permission under a searchable outside link. Fix: in `_entry_reach`, give the "leads outside through a symbolic link" refusal when `[ -L "$cur" ]` points outside, before the search check. Found by Gemini. — `.agent/scripts/worktree_remove.sh:436`
- [ ] (suggestion) The header (line 33) and the `script_reference.md` row say a mount of another filesystem is "neither walked nor changed, its top folder included". The per-entry walk at line 597 deliberately walks and repairs an entry that is itself on another filesystem, its top folder included. That behaviour is right, since the entry is what is being removed, but the claim needs that exception. Found by Gemini. — `.agent/scripts/worktree_remove.sh:597`
- [ ] (suggestion) "So no review is merged past unread" overclaims. GitHub lets a review's body be updated under the same `review_id`, and the reviews API gives no edit time, so an edit after triage is not read again. The earlier time rule had the same gap, and the hosted reviewer posts new reviews rather than editing old ones. Name this limit in the text, or compare a hash of the body. Found by Codex, downgraded from must-fix. — `.claude/skills/run-issue/SKILL.md:1019`

## Integrated Review
**Status**: complete
**When**: 2026-11-20 13:49 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Reviews-read**: none

**PR**: #542 at `d2adb33a`
**Sources**: 3 (Local Review @ `d2adb33a` (entry 592ddc83, approved, three open suggestions), Local Review @ `47a1ea83` (entry e7ab04e3, one must-fix and three suggestions, all closed by the fix pass at `cc145c26`..`d2adb33a`, not re-listed), CI rollup). No hosted review, no inline or conversation comment on the pull request.
**Cross-source confirmations**: 0
**CI**: pending

Summary: no must-fix open; all three open suggestions of the approved local review are valid (one misleading refusal message, two overclaiming texts), each a small fix; CI on `d2adb33a` still running (Lint and one Python 3.14 manifest test pending, nothing failed).

### Findings
- [x] (suggestion, Local Review @ `d2adb33a`) Valid, confirmed here: `_entry_reach` returns 2 naming a folder on the entry's path that is a symbolic link to an outside folder with no search permission (reproduced with the function extracted from this branch: rc=2, the blocked path is the link, outside mode stays 600). The refusal then advises `chmod u+rwx <link>`, which follows the link and changes a folder outside the worktree; the case is exactly the one the link refusal exists for. Line 452 has the same wrong advice for an unenterable entry under a searchable outside link. Fix: in `_entry_reach`, when `[ -L "$cur" ]` and its resolved target is outside the worktree, return a distinct code that the caller turns into the existing "leads outside this worktree through a symbolic link" refusal, before the search check; at line 452, resolve the entry's parent (`cd "$(dirname "$_dest")" && pwd -P`) and give the link refusal when it lies outside. Size: about 10-15 lines plus two test cases (unsearchable outside link target; unenterable entry under a searchable outside link) — `.agent/scripts/worktree_remove.sh:436`
- [x] (suggestion, Local Review @ `d2adb33a`) Valid: the header (lines 31-33) and the `script_reference.md` row say a mount of another filesystem is "neither walked nor changed, its top folder included", but line 597 walks a package entry that is itself on another filesystem from its own top folder (`_make_dirs_writable` takes the device from its start), so that entry and its same-device folders do get u+rwx. The behaviour is right (the entry is what is being removed, and the comment at lines 585-588 already says so); the two summaries overclaim. Fix: add the exception to both, e.g. "except a package worktree's entry that is itself on another filesystem, which is walked from its own top folder". Size: wording only, two places — `.agent/scripts/worktree_remove.sh:33`, `.agent/knowledge/script_reference.md:21`
- [x] (suggestion, Local Review @ `d2adb33a`) Valid: "so no review is merged past unread" overclaims. `fetch_pr_reviews.sh` keeps only `review_id`, `submitted_at`, `state`, `body`, `commit_id` and the user (lines 103-111), and the REST review object carries no edit time, so a review body edited after triage under the same `review_id` is not read again. The hosted reviewer posts new reviews rather than editing, so the gap is mainly a human edit. Fix: name the limit in the sentence (an edit to a review already read is not seen; the list gives no edit time), or record a hash of each read review's body beside its id. Size: one sentence for the wording; the hash is a larger change to both skills and not needed for part 1 — `.claude/skills/run-issue/SKILL.md:1019`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-20 13:50 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (three valid findings are open, each a small fix; merging with findings open is the owner's answer only, sending them back is the host's)
**After**: findings
**Decision**: address

Read: the Integrated Review at 98c47a8c: no must-fix, three open findings, all classified valid: the refusal in worktree_remove.sh that advises a chmod which would follow a symbolic link to a folder outside the worktree (lines 436 and 452); the header and script_reference.md wording that says a mount of another filesystem is never walked or changed, without the exception for an entry that is itself on one; and the run-issue step 9 sentence "so no review is merged past unread", which does not hold for a review edited after triage. CI was pending at triage, with no failure. The quality standard is that a misleading message or an overclaiming text is fixed, not deferred.

## Implementation
**Status**: complete
**When**: 2026-11-20 13:57 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a9bb1c9dbbf534a0a, resume 1 of 3)

**PR**: #542 at `3575bbee`
**Addressed**: Integrated Review at `d2adb33a` (2026-11-20 13:49 -05:00)
**Commits**: 97e48c95, f7959ef4, 3575bbee

### Actions
- [x] (suggestion) A folder on an entry's path that is a symbolic link out of the worktree now gets the "leads outside this worktree ... through the symbolic link <link>" refusal from `_entry_reach` (resolved with `readlink -f`), before any search-permission check, so no `chmod` is advised on a link; this also covers the line-452 case (an entry that cannot be entered under a searchable outside link). A link whose target cannot be resolved is refused the same way. A link out of the worktree whose target is not a reachable folder is still taken as gone, as before (`rm -rf` removes only the link). A link that stays inside is walked through as before; decided: when its target cannot be entered, the advice names that target (a folder inside the worktree) instead of the link, so the advised chmod is on the real folder. Tests: two new cases (outside target cannot be entered; entry under a searchable outside link cannot be entered) failed 4 checks before (the link message and no-chmod-advice checks, each case) and pass after; an inside-link dirty entry is refused for its change before and after; the inside-link no-search naming check failed before and passes after. — `.agent/scripts/worktree_remove.sh:436`
- [x] (suggestion) Header and `script_reference.md` row now name the exception: a package worktree's entry that is itself on another filesystem is walked from its own top folder. Wording only. — `.agent/scripts/worktree_remove.sh:33`, `.agent/knowledge/script_reference.md:21`
- [x] (suggestion) Run-issue step 9's sentence now states the limit: a review whose text is edited after triage keeps its `review_id` and is not read again (GitHub gives no edit time). No body hash. — `.claude/skills/run-issue/SKILL.md:1019`

### Suites run (each on its own, the full pass left to the host)
- test_worktree_remove.sh: 92 passed, 0 failed
- test_merge_pr_root_resolution.sh: 6 passed, 0 failed
- test_merge_pr.sh: 175 passed, 0 failed
- test_merge_pr_skill.sh: 132 passed, 0 failed
- test_project_registry.sh: 425 passed, 0 failed
- test_merge_pr_gate.sh: 213 passed, 0 failed
- test_script_tests_hook_scope.sh: 347 passed, 0 failed
- test_validate_workspace_stale.sh: 126 passed, 0 failed
- test_ros2_colcon.sh: 1375 passed, 0 failed, 0 skipped
- test_user_tier_guard.sh: 64 passed, 0 failed
- test_skill_paths.sh: 164 passed, 0 failed

shellcheck at warning severity is clean on `worktree_remove.sh` and its test. No part 2 file and not `plan.md` touched.

## Local Review
**Status**: complete
**When**: 2026-11-20 14:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ae4a8940bb75088a1, resume 2 of 3)

**PR**: #542 at `0c3c7b47`
**Depth**: Deep (reason: whole-diff classification for a fix round, 11 files and about 950 changed lines; no convergence-check words in the handoff, so cross-model ran)
**Must-fix**: 1 | **Suggestions**: 1

Re-review after the fix pass 97e48c95, f7959ef4 and 3575bbee (Implementation entry 0c3c7b47).

Earlier suggestions (Local Review 592ddc83):
- A link out of the worktree got chmod advice: fixed. A folder on the entry's path that is a link out is refused as a link, before any search check, with no chmod advice. Tested for both shapes. The adversarial reviewer also checked a link out to a mode 000 folder and a link out at the entry's own name.
- The mount wording: fixed, in the header and in the `script_reference.md` row.
- The edited-review limit: fixed. Step 9 names it.

Statements tested:
- "A link to something that is not a reachable folder is still taken as gone." This is safe when the target is outside the worktree: a dangling link, a link to a file, or a link to an outside folder whose parent cannot be searched. `rm -rf` removes only the link, and the outside tree keeps its contents and modes. It is not safe when the target is inside the worktree. See the must-fix.
- "The advice names the target, a folder inside the worktree." This holds: the walk prints only the `readlink -f` target of a link checked to be inside, or a non-link path reached through inside links.

Reproduced, with main as the control:
- Setup: a real checkout at `layer_ws/src/sub/pkg_a` with an uncommitted change. The manifest names `alias/pkg_a`, and `alias -> layer_ws/src/sub`. `layer_ws/src` is mode 600.
- Branch: exit 0, "removed successfully", the change deleted.
- Main: exit 1 with `rm: cannot remove ... Permission denied`, the change kept.
- The same happens when the entry's own name is such a link. With `layer_ws/src` searchable, the branch refuses for the uncommitted change.

This was present since d8bcf950, and I missed it in round 2.

Verified:
- shellcheck at warning severity is clean on `worktree_remove.sh` and its test.
- `test_worktree_remove.sh`: 92 passed, 0 failed.

Reviewers:
- Gemini ran, EXIT 0. It found the must-fix and the suggestion. Dropped from its review:
  - Plan drift: recorded in the pull request text.
  - Matching `could not open directory`: when the error is not EACCES, chmod cannot open the folder either, so `rm -rf` fails rather than deletes.
  - `merge_pr.sh`'s hold after 1800 s: that is the documented existing behaviour.
  - The wait-end wording points: dropped in earlier rounds.
  - A negative `total_count`: GitHub never sends one.
- Codex ran, EXIT 0. It found the must-fix.
- The Claude adversarial reviewer ran, with a fresh agent. It found the must-fix, reproduced with the link at the entry's own name, and the suggestion.

### Findings
- [x] (must-fix) A link that stays inside the worktree, but whose target sits under a folder with no search permission, is taken as gone. `[ -d ]` follows the link and is false on EACCES, at line 432 (a folder on the path) and at line 427 (the entry's own name), and both run before the `[ -L ]` check. The entry gets no owner and no dirty check. `_make_dirs_writable` then opens the folder, and `rm -rf` deletes the checkout with its uncommitted work, without `--force`. Main fails safe here. Fix: when `[ -d ]` is false on a component that is a link, resolve it (`readlink -m`). If the target is inside the worktree, refuse (return 2, naming the folder that cannot be entered). Keep "gone" only for a target outside the worktree. Add a test for an intermediate link and one for a link at the entry's own name, each with a dirty entry under a mode 600 folder. Found by the lead (reproduced), Codex, Gemini and the Claude adversarial reviewer. — `.agent/scripts/worktree_remove.sh:432`
- [x] (suggestion) An entry that is itself a link to a folder inside the worktree that cannot be entered gets the "leads outside this worktree ... through a symbolic link" message at line 495, because `_real` is empty and `[ -L ]` is true at line 487. The refusal is safe; only the message is wrong. Found by the Claude adversarial reviewer and Gemini. — `.agent/scripts/worktree_remove.sh:487`

## Implementation
**Status**: complete
**When**: 2026-11-20 14:15 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a9bb1c9dbbf534a0a, resume 2 of 3)

**PR**: #542 at `b3dce4d6`
**Addressed**: Local Review at `0c3c7b47` (2026-11-20 14:04 -05:00)
**Commits**: b3dce4d6

Per host direction, the entry decision is turned round to "refuse unless proven": `_entry_state` in `worktree_remove.sh` replaces `_entry_reach` and the separate link and cannot-enter checks, and one `case` acts on its three results. The walk looks a name up only in a folder it has entered, follows links one level at a time (`readlink`) under the same rules, and uses no `[ -d ]` or `[ -e ]` on a path it has not reached. Deliberate change from the last pass: a dangling link, a link to a file, and a link outside the worktree (including one to an outside folder that cannot be reached) are now refused, not taken as gone; the header and `script_reference.md` say to remove such a link by hand. A present entry is carried on as its physical path, asserted inside the worktree.

### Actions
- [x] (must-fix) An inside link whose target sits under a folder with no search permission was taken as gone and deleted. Reproduction (manifest `alias/pkg_a`, `alias -> layer_ws/src/sub`, `layer_ws/src` mode 600, uncommitted change), plain and `--force`, link on the path and link as the entry itself: before, all 16 checks of the 4 cases failed (exit 0, change deleted, mode opened); after, all pass (exit 1, "cannot enter <layer_ws/src>", mode 600 kept, change kept). — `.agent/scripts/worktree_remove.sh:432`
- [x] (suggestion) An entry that is a link to an inside folder that cannot be entered got the "leads outside" message. Now refused as "cannot enter <inside folder>" with the chmod advice on that real folder; test failed 2 checks before, passes after. — `.agent/scripts/worktree_remove.sh:487`

### The three states and the tests that pin them
- PRESENT (reached, then owner and dirty checks): read-only install tree, plain and `--force`; dirty tracked file refused; aggregate with read-only leftovers; read-only container between entries; clean entry through an inside link removed (new); dirty entry under an inside link refused for its change; unreadable folder refused without `--force`, removed with it.
- PROVEN ABSENT: "an entry that is genuinely absent is skipped, the rest removed" (missing `layer_ws/src/pkg_b`, and `gone_ws` missing above `pkg_c`).
- REFUSED, with or without `--force`: the reproduction (path link and entry link, plain and `--force`, new); entry link to an inside folder that cannot be entered (new); a link that does not reach a folder inside (dangling, to a file, outside and unreachable, a name missing behind a link; each new, each `--force`, each with "remove the link by hand" and no chmod advice); entry under a 600 folder (plain and `--force`); entry itself with no search permission; inside link to a folder that cannot be entered; outside link on the path (target or entry cannot be entered); entry that is itself an outside link (plain and `--force`).

### Suites run (each on its own with `timeout 600`, the full pass left to the host)
- test_worktree_remove.sh: 135 passed, 0 failed (before the fix: 105 passed, 30 failed)
- test_merge_pr_root_resolution.sh: 6 passed, 0 failed
- test_merge_pr.sh: 175 passed, 0 failed
- test_merge_pr_skill.sh: 132 passed, 0 failed
- test_project_registry.sh: 425 passed, 0 failed
- test_merge_pr_gate.sh: 213 passed, 0 failed
- test_script_tests_hook_scope.sh: 347 passed, 0 failed
- test_validate_workspace_stale.sh: 126 passed, 0 failed
- test_ros2_colcon.sh: 1375 passed, 0 failed, 0 skipped
- test_user_tier_guard.sh: 64 passed, 0 failed
- test_skill_paths.sh: 164 passed, 0 failed

shellcheck at warning severity is clean on `worktree_remove.sh` and its test. No part 2 file and not `plan.md` touched. A link written as an absolute path to the worktree by a path other than its physical one is refused as outside; that errs toward refusing.

## Local Review
**Status**: complete
**When**: 2026-11-20 14:25 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ae4a8940bb75088a1, resume 3 of 3)

**PR**: #542 at `7b49a579`
**Depth**: Deep (reason: whole-diff classification for a fix round; no convergence-check words in the handoff, so cross-model ran)
**Must-fix**: 2 | **Suggestions**: 1

Re-review after b3dce4d6, which replaced the gone-or-not test with `_entry_state`: present, proven absent, or refused (Implementation entry 7b49a579).

The owner's direction, given during this round (2026-11-20), quoted: "it's ok if scripts don't handle everything and come back saying they can't do it. If it's occasinal and an agent can deal with, that's fine. If it happens too often, than we can look at root causes and such. Let's not waist too much time going for perfect when we can have agents handle the edge cases."

Applied as the host reads it:
- A clear refusal, even of an unusual healthy layout, is at most a suggestion.
- A must-fix is silent harm: deleting uncommitted work or anything outside the worktree, false success, or refusing an ordinary layout.

Earlier findings (Local Review ac4c8d0c):
- Must-fix (an inside link to a target under a folder with no search permission was taken as gone): fixed. With the link on the path and with the link as the entry, both are now refused, naming the folder inside the worktree, and the change is kept.
- Suggestion (wrong link message): fixed. An entry that links to an inside folder that cannot be entered now gets "cannot enter <that folder>".

Attack on `_entry_state`: refused, change kept, for all of these:
- a link loop, and links to `..` at the top;
- a file in the middle of the path;
- a manifest `.../pkg_a/..`.

Present, with the uncommitted change caught on the physical path, for all of these:
- an absolute manifest path (treated as relative to the worktree);
- empty and `.` segments;
- a link to `.`;
- an absolute link to the worktree itself;
- a name with a leading dash and a space;
- a folder that can be searched but not read;
- an entry that can be read but not written.

From the decision to the removal, the code uses only the vetted physical path: `ENTRY_DESTS[i]` is replaced, and the dirty check, the chmod and `git worktree remove` all read it.

Ordinary layouts are all removed: a package worktree with one entry or with two, an entry removed by hand, a whole layer removed by hand, and a read-only install tree. The plain single worktree is covered by the suite. A link that names the worktree by a non-physical path is refused with a clear message; that is acceptable under the owner's direction.

The function is lines 430-501, about one and a half screens. Its header is true except for the `..` case below.

Verified:
- shellcheck at warning severity is clean on `worktree_remove.sh` and its test.
- `test_worktree_remove.sh`: 135 passed, 0 failed.

Reviewers:
- Gemini ran, EXIT 0. Dropped from its review:
  - Its must-fix that `$2` is unchecked: false. `$2` is always `WORKTREE_DIR` or `WORKTREE_DIR/<rel>` (lines 382-384), and `WORKTREE_DIR` is physical and was entered at line 354.
  - The `git status` message wording: a refusal with a message.
  - Plan drift, the wait-end wording and `none` on a local-only triage: dropped in earlier rounds.
- Codex ran, EXIT 0. It found must-fix 2, and the suggestion as a must-fix; its plan-drift point was dropped.
- The Claude adversarial reviewer ran, with a fresh agent. It found must-fix 1, independently, and the suggestion.

### Findings
- [x] (must-fix) A manifest path with `..` after a missing name is judged ABSENT at that missing name, and the rest of the path is never checked. The function's contract is "refuse unless proven", and this breaks it. Example: manifest `gone/../layer_ws/src/sub/pkg_a`, with a real checkout there holding an uncommitted change. Reproduced: exit 0, "removed successfully", the change deleted. Main's script loses it the same way. The scripts never write `..`, so this needs a hand-edited manifest. Fix: refuse any `..` segment in a manifest path, or return ABSENT only when nothing remains of the path. Found by the lead (reproduced) and the Claude adversarial reviewer. — `.agent/scripts/worktree_remove.sh:477`
- [x] (must-fix) The unread-review check runs only before the merge checkpoint is presented. A hosted review that lands while the owner is deciding is merged past unread: step 11 runs `merge_pr.sh` with no fetch, and `merge_pr.sh` holds only on a running check-run. The text "so no review is merged past unread" is then false. The documented late reviews, at 17 and 30 minutes, and the 900 s "never arrived" exit make this reachable. Fix: in step 11, after the owner's yes and before `merge_pr.sh`, fetch once more and apply the same check. Any review not yet read goes to triage, and the merge checkpoint is presented again. Found by Codex. — `.claude/skills/run-issue/SKILL.md:1019`
- [x] (suggestion) A bind mount of an outside folder from the same filesystem, inside the tree, is walked by the chmod (same device). Its read-only folders are opened, and `rm -rf` then deletes them as well. Main's `rm -rf` already deleted the writable parts, the comment states the behaviour, and making such a mount needs root. Cheap closure: refuse when `/proc/self/mountinfo` lists a mount point under the worktree. Found by Codex as a must-fix, downgraded: documented, root-only, mostly pre-existing. — `.agent/scripts/worktree_remove.sh:628` (deferred: documented in the script, needs root to set up, and main's rm -rf already deleted the writable parts; under the owner's 2026-11-20 direction not worth another change)

## Implementation
**Status**: complete
**When**: 2026-11-20 14:37 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a9bb1c9dbbf534a0a, resume 3 of 3)

**PR**: #542 at `8314ad24`
**Addressed**: Local Review at `b3dce4d6` (entry 711f12bd)
**Commits**: ca7e4b94, 2ccc87cc, 8314ad24

Kept as small as the owner asked (2026-11-20): "it's ok if scripts don't handle everything and come back saying they can't do it. If it's occasinal and an agent can deal with, that's fine. If it happens too often, than we can look at root causes and such. Let's not waist too much time going for perfect when we can have agents handle the edge cases."

### Actions
- [x] (must-fix) A manifest path with a `..` segment is refused before the walk, in one line ("a manifest path may not contain .."); no other path validation added. Test (`gone/../layer_ws/src/sub/pkg_a` with an uncommitted change): 3 checks failed before (exit 0, change deleted), all pass after. — `.agent/scripts/worktree_remove.sh:477`
- [x] (must-fix) Run-issue step 11: on the owner's merge answer, before anything else, fetch the reviews once more and apply step 9's "A review not yet read" check; a review that landed while he decided goes to `triage-reviews` and the merge checkpoint is shown again. Placed before step 11's existing push, unpushed check and `cd` to the root, which still read in order after it. — `.claude/skills/run-issue/SKILL.md` step 11
- [x] (suggestion) Bind mount from the same filesystem inside the tree — `.agent/scripts/worktree_remove.sh:628` (deferred: documented in the script, needs root to set up, and main's `rm -rf` already deleted the writable parts; under the owner's direction above it is not worth another change)

### Suites run (each on its own with `timeout 600`, the full pass left to the host)
- test_worktree_remove.sh: 138 passed, 0 failed
- test_merge_pr_root_resolution.sh: 6 passed, 0 failed
- test_merge_pr.sh: 175 passed, 0 failed
- test_merge_pr_skill.sh: 132 passed, 0 failed
- test_project_registry.sh: 425 passed, 0 failed
- test_merge_pr_gate.sh: 213 passed, 0 failed
- test_script_tests_hook_scope.sh: 347 passed, 0 failed
- test_validate_workspace_stale.sh: 126 passed, 0 failed
- test_ros2_colcon.sh: 1375 passed, 0 failed, 0 skipped
- test_user_tier_guard.sh: 64 passed, 0 failed
- test_skill_paths.sh: 164 passed, 0 failed

shellcheck at warning severity is clean on `worktree_remove.sh` and its test. No part 2 file, not `plan.md`, and no change to `_entry_state`.

## Local Review
**Status**: complete
**When**: 2026-11-20 14:45 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #542 at `8ce42584`
**Depth**: Deep (reason: whole-diff classification for a fix round; no convergence-check words in the handoff, so cross-model ran)
**Must-fix**: 0 | **Suggestions**: 3

Re-review after ca7e4b94, 2ccc87cc and 8314ad24 (Implementation entry 8ce42584), by a fresh reviewer.

The bar, the owner's words (2026-11-20): "it's ok if scripts don't handle everything and come back saying they can't do it. If it's occasinal and an agent can deal with, that's fine. If it happens too often, than we can look at root causes and such. Let's not waist too much time going for perfect when we can have agents handle the edge cases."

Applied as the host reads it: a must-fix is only silent harm (losing uncommitted work or anything outside the worktree, false success, telling the host to skip something that may hold a finding, or failing an ordinary case). A clear refusal, wording and polish are suggestions at most.

Earlier must-fix items (Local Review 711f12bd):
- The `..` manifest path: fixed. Reproduced against the head, plain and `--force`, for `gone/../layer_ws/src/sub/pkg_a`, `layer_ws/src/sub/pkg_a/..`, `../issue-workspace-7/layer_ws/src/sub/pkg_a` and `layer_ws/./src/gone/../sub/pkg_a`, each with an uncommitted change: all 8 exit 1 with "a manifest path may not contain ..", the change kept, the worktree kept. The check sits in the decision loop, before the dirty check, the chmod and any removal, so "Nothing was removed" is true. No false positive on `.`, an absolute path, `a..b`, `..x` or `x..` (checked by the adversarial reviewer).
- The merge-answer re-fetch: fixed. The sentence comes first in step 11, before step 10's push and unpushed check, the `cd` to the root and `merge_pr.sh`, and applies step 9's own check unchanged. It also covers a resume: a recorded `merge` answer makes `next` return `action=merge`, which reaches step 11. The triage it sends to writes an `## Integrated Review`, which becomes the newest entry, and it is not a start entry for `pr_start.py`, so no false pull-request boundary.

Verified:
- shellcheck at warning severity is clean on `worktree_remove.sh` and its test.
- `test_worktree_remove.sh`: 138 passed, 0 failed.
- `fetch_pr_reviews.sh --pr 542` at `8ce42584`: no hosted review and no `copilot-pull-request-reviewer` check-run.

Reviewers:
- Gemini ran, EXIT 0. It found suggestion 1, as a must-fix. Dropped:
  - The wait ends on any review on the head, or on an earlier finished check-run: a review that lands later is caught by the re-fetch before the checkpoint and at the merge answer.
  - Plan drift (`notice_only`): recorded in the pull request text.
  - The unchecked `$2` prefix, the `git status` error matching and the contracts of `fetch_pr_reviews.sh` and `progress_read.py`: settled in earlier rounds.
- Codex ran, EXIT 0. Dropped:
  - The same-filesystem bind mount: already deferred by the host under the owner's direction.
  - New inline comments on an already-read review: on GitHub a reply is posted as its own review, with a new `review_id` (documented behaviour, not reproduced).
  - Plan drift: as above.
- Copilot: the CLI reviewer was dropped by owner decision (#344); no hosted Copilot review is on the pull request yet, and `triage-reviews` reads one if it lands.
- The Claude adversarial reviewer ran, with a fresh agent. No must-fix.

### Findings
- [ ] (suggestion) Step 11 says to "present the merge checkpoint again" after the late review's triage; when that triage leaves open boxes, `next` raises `checkpoint:findings`. Say "call `next` again" instead. Both checkpoints offer merge and address, and the dialog carries the triage, so nothing is hidden. Found by the lead and Gemini. — `.claude/skills/run-issue/SKILL.md:1110`
- [ ] (suggestion) The script header's list of refused cases and the `script_reference.md` row do not mention the `..` refusal. The error message itself is clear. — `.agent/scripts/worktree_remove.sh:27`
- [ ] (suggestion) The pull request's Decision summary is out of date: item 5 says `triage-reviews` records a fetch time in `**Fetched**`, which is now `**Reviews-read**` with review ids; item 3 does not say that links which do not reach a folder inside, and `..` paths, are refused, to be removed or corrected by hand. Refresh it before the merge gate reads it. — pull request 542 body

## Integrated Review
**Status**: complete
**When**: 2026-11-20 14:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Reviews-read**: none
**Dispatch**: resumed (agent adfe2f8b386465a21, resume 1 of 3)

**PR**: #542 at `8ce42584`
**Sources**: 2 (Local Review @ `8ce42584` (entry 4bd5eeb0, approved, three open suggestions), CI rollup). No hosted review, no hosted-reviewer check-run, no inline or conversation comment. The stale Local Review @ `d2adb33a` (three open boxes, listed as dropped) was ruled on in the Integrated Review of 98c47a8c, and all three were fixed (97e48c95, f7959ef4, 3575bbee); not re-listed. The intervening rounds at `0c3c7b47` and `7b49a579` are closed; the bind-mount suggestion there was declined by the fix pass, as recorded.
**Cross-source confirmations**: 0
**CI**: pending

Owner direction (2026-11-20), applied here: "it's ok if scripts don't handle everything and come back saying they can't do it. If it's occasinal and an agent can deal with, that's fine. If it happens too often, than we can look at root causes and such. Let's not waist too much time going for perfect when we can have agents handle the edge cases."

Summary: no must-fix open. S1 and S2 are valid wording fixes, one phrase or line each. S3 (stale Decision summary) is addressed by the host's rewrite, checked against the branch. CI on `8ce42584` is still running (Lint and the repos-manifest tests pending in both runs; nothing failed). Whether S1 and S2 are fixed before or after the merge is the owner's call at the checkpoint.

### Findings
- [x] (suggestion, Local Review @ `8ce42584`) S1, valid, wording: step 11 says that after a late review's triage the host should "present the merge checkpoint again". After that triage the route is `next`'s to decide: `dispatch_phase.sh:1227` emits `checkpoint:findings` when the new Integrated Review has open boxes, so naming only the merge checkpoint is wrong in that case. The harm is small, because both checkpoints offer merge and address and the dialog carries the triage, and an agent handles it, as the owner's direction allows. Fix: replace the phrase with "call `next` again". Size: one phrase — `.claude/skills/run-issue/SKILL.md:1110` (deferred: deferred by the owner at the findings checkpoint 2026-11-20 ("Merge, carry F1 F2") to part 2's pull request on this issue)
- [x] (suggestion, Local Review @ `8ce42584`) S2, valid, wording: the header's list of refused cases (lines 24-36) and the `script_reference.md` row name the unreachable folder and the bad link but not the refusal of a manifest path containing `..` (lines 506-512). The error message itself is clear and says what to correct. Fix: add "or a manifest path containing `..` (correct `.worktree-repos` by hand)" to both. Size: one line in each of two places — `.agent/scripts/worktree_remove.sh:27`, `.agent/knowledge/script_reference.md:21` (deferred: deferred by the owner at the findings checkpoint 2026-11-20 ("Merge, carry F1 F2") to part 2's pull request on this issue)
- [x] (suggestion, Local Review @ `8ce42584`) S3: the Decision summary was out of date. Addressed by the host's rewrite of the pull request text, checked here. Item 5 now describes `**Reviews-read**` and the edited-review limit. Item 3 describes the three-state decision and the hand-fixed refusals, `..` included. "Open, small" lists S1 and S2. The counts are right: 6 `## Local Review (Pre-Push)` and 5 `## Local Review` entries in `progress.md`, and `test_worktree_remove.sh` ran here with 138 passed and 0 failed. The leave-out list (`dynamic/dependabot/`, `dynamic/pages/`) is in `merge_pr.sh:1770-1771` — pull request 542 body

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-20 14:53 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: findings
**Decision**: merge

The owner's answer in the dialog, to "Merge pull request 542 now, with F1 and F2 carried into part 2 of the same issue?": "Merge, carry F1 F2 (Recommended)". F1 is the open suggestion on run-issue step 11 ("present the merge checkpoint again" should say "call next again"); F2 is the open suggestion on the worktree_remove.sh header and its script_reference.md row (the refusal of a manifest path containing ".." is not listed). Both are deferred to part 2's pull request on this issue. The dialog showed: six pre-push rounds and five pull-request reviews, the last approved with no must-fix (4bd5eeb0); the Integrated Review at 895aae63; CI settled with all 10 checks passed on 8ce42584; no hosted review ever started; the host's fetch just before asking: no reviews, no comments, mergeable. His direction earlier the same day applies: "Let's not waist too much time going for perfect when we can have agents handle the edge cases."

## Checkpoint
**Status**: complete
**When**: 2026-11-24 08:23 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (run-issue step 13's conditions hold: plan.md is at 6b241e5d, the commit the newest Plan Review names, and the plan names Part 2, which is not delivered)
**After**: plan
**Decision**: proceed

The owner asked for this drive today: "/orchestrator 563 and 428". Pull request 542 (Part 1: items 1, 2, 3 and 5) merged on 2026-11-20; the issue stays open because Part 2 (item 4, the github.com-only slug check) is still to come and its pull request is the one that says Closes #428. The leftover Part 1 worktree and local branch were removed (every commit was on main) and recreated from main at c11c6816.

Instructions that bind the implementer (host decisions, listed for the owner's veto):
- Implement Part 2 only (item 4 and its rows of item 6). Part 1's files are delivered.
- The plan was reviewed on 2026-11-19 and main has moved since: before editing, list the call sites again on this branch and work from that list, not from the plan's line numbers; say in the entry where the two differ.
- Carry the two suggestions the owner deferred to this pull request on 2026-11-20 ("Merge, carry F1 F2"): F1, run-issue step 11 says "present the merge checkpoint again" after a late review's triage and should say to call next again; F2, the worktree_remove.sh header and its script_reference.md row do not list the refusal of a manifest path containing "..".
- Issue 563 (sit-rep per path) is in flight on its own branch and rewrites parts of test_sitrep_checks.sh and test_sitrep_root.sh: keep this part's edits to those two suites to the fixtures item 4 needs.

## Implementation
**Status**: complete
**When**: 2026-11-24 08:41 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-428 at `b7c0c7d3`
**Commits**: 62c1f1e1, aa2968f6, fa8d167b, b7c0c7d3

Part 2 of the issue (plan item 4 and its rows of item 6), plus the two suggestions the owner carried here on 2026-11-20 ("Merge, carry F1 F2"). Part 1's files were not redone. Owner direction applied (2026-11-20): "Let's not waist too much time going for perfect when we can have agents handle the edge cases."

### Changes
- `extract_gh_slug` (`.agent/scripts/_issue_helpers.sh`) uses `sitrep_root.sh`'s `gh_slug` grammar in bash, no `gh` call: https/http (user or user:token), ssh (user, port), git and scp-like github.com forms, host in any case, exactly owner/repo, optional `.git` and trailing `/`. Not accepted: other hosts, `notgithub.com`, `github.com.evil.example`, `www.`/`ssh.github.com`, GitHub Enterprise, more than two path segments, a bare `owner/repo`. Kept difference, recorded in the header: an absolute path (starting with `/`) ending `/github.com/<owner>/<repo>[.git]`, the sandboxes' bare-clone form. — 62c1f1e1
- New `test_issue_helpers.sh`: a 49-row table through `extract_gh_slug` and, for parity, through `gh_slug` taken from `sitrep_root.sh`'s PYLIB block (the suite fails if the block cannot be found). The 3 local-path rows are marked as the intended difference. Run against the old parser, 24 checks fail. — 62c1f1e1
- `test_ros2_colcon.sh`: the stub `_issue_helpers.sh` now sources the real file and replaces only `issue_lookup`, so there is no stale copy. Two new assertions: the stub's function gives nothing for `git@gitlab.com:o/r.git` (the old copy gave `git@gitlab.com:o/r`) and `o/r` for a GitHub URL. — 62c1f1e1
- `test_merge_pr_gate.sh`: the hang-3 (applied, applied-ontop) and hang-4 origins are now `ssh://git@github.com/owner/pkg_a.git`. `serve_shim` maps a quoted path that is not a local folder into `$sb/fake_remotes/github.com`; a path that is a local folder is served as before. — 62c1f1e1
- `test_sitrep_checks.sh`: one case, a root whose origin is `git@gitlab.com:acme/w.git`, so a bare `gh-issue 5 closed` gives `unknown` and gh is never called. Nothing else in that suite changed; `test_sitrep_root.sh` is unchanged. — 62c1f1e1
- `worktree_create.sh`: a bare `--issue` for `--type project` with no GitHub slug (an origin on another host, or no origin) gets no lookup, no `gh issue view` fallback and no `gh pr view` check. The worktree is made and one of the plan's two notes is printed, without the "offline or issue does not exist" line. The workspace-slug fallback now runs for the workspace type only. Tests in `test_worktree_create.sh`: both project cases, run from the workspace folder with a gh stub that answers any repo and number, plus the unchanged workspace-type case (looked up and pr-checked in `ws-owner/ws`). — aa2968f6
- `script_reference.md`: `_issue_helpers.sh` row (62c1f1e1) and `worktree_create.sh` row (aa2968f6).
- F2: the `worktree_remove.sh` header's refused list and its `script_reference.md` row now include "a manifest path containing `..` (correct `.worktree-repos` by hand)". It was not already on main. — fa8d167b
- F1: run-issue step 11 now says "call `next` again (after that triage it may raise `checkpoint:findings` rather than the merge checkpoint)" instead of "present the merge checkpoint again". It was not already on main. — b7c0c7d3

### Call sites on this branch versus the plan
- Same set as the plan: `merge_pr.sh` (now lines 466, 468, 535, 541, 646, 2294, 2419), `worktree_create.sh` (634, 642, 660, 663, 672, 704), `worktree_enter.sh` (323, 339), `sitrep_checks.sh` (474), the three internal calls in `_issue_helpers.sh`, and the orchestrator skill's WS_REPO snippet. Every one passes `git remote get-url` output; none passes a bare slug.
- Different from the plan: `test_ros2_colcon.sh`'s fixtures already use `git@github.com:owner/<name>.git` behind a `GIT_SSH_COMMAND` shim, so the only stale thing there was the copy (line 845). The plan's `make_origin_repo` reference is in `test_merge_pr.sh` (line 207); its comment described the old "plain text substitution", so it was reworded (a comment-only change in a file the plan does not list). The plan's line numbers for the hang-3 fixtures (~1585, ~1616) are now 1606 and 1637. The third `github.com$` fixture (hang-ws, line 1669, `ssh://git@github.com$bare` for the workspace sandbox) gives an empty slug under both the old and the new parser (more than two segments), which that sandbox's `repos//...` fixtures expect, so it was left as is.

### Decided here (not in the plan)
- The local-path form is accepted only when the input starts with `/`. Without that, the plan's own refused case `ssh://git@github.com/tmp/x/github.com/o/r.git` would match.
- `serve_shim` maps only paths that are not local folders. Mapping every path would have broken hang-ws, whose origin path is an absolute bare repo.
- Other copies of the old loose parser (the `sed 's#.*github\.com[:/]##'` pattern in `gh_create_issue.sh`, `gh_create_pr.sh`, `git_bug_setup.sh`, `pr_status.sh` and `_project_registry.sh:784`) are not in the plan and were not changed. Listed for the host to decide whether they need an issue.

### Suites run (each on its own with `bash`; the full pass is left to the host)
- test_issue_helpers.sh: 98 passed, 0 failed
- test_sitrep_checks.sh: 253 passed, 0 failed
- test_sitrep_root.sh: 65 passed, 0 failed
- test_worktree_create.sh: PASS: 112 FAIL: 0
- test_worktree_enter_stderr.sh: 35 passed, 0 failed
- test_ros2_colcon.sh: 1553 passed, 0 failed, 0 skipped
- test_merge_pr_gate.sh: 213 passed, 0 failed
- test_merge_pr.sh: 175 passed, 0 failed
- test_merge_pr_skill.sh: 132 passed, 0 failed
- test_merge_pr_root_resolution.sh: 6 passed, 0 failed
- test_project_registry.sh: 425 passed, 0 failed
- test_precommit_hook_path.sh: 19 passed, 0 failed
- test_worktree_remove.sh: 138 passed, 0 failed
- test_skill_paths.sh: 200 passed, 0 failed
- test_records_write_gate.sh: 68 passed, 0 failed
- test_user_tier_install.sh: 276 passed, 0 failed
- test_package_issue_loop.sh: 228 passed, 0 failed
- test_validate_workspace_stale.sh: 126 passed, 0 failed
- test_user_tier_guard.sh: 64 passed, 0 failed
- test_script_tests_hook_scope.sh: 358 passed, 0 failed

Hook rule: the first commit (62c1f1e1) was made without `SKIP=validate-script-tests` by mistake. The `validate-script-tests` hook ran its selection and passed. Every later commit, this entry's included, set it.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-24 08:50 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-428 at `be996b08`
**Base**: origin/main
**Depth**: Deep (reason: 407 changed lines across 12 files; skill and knowledge files present)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 1 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Part 2 only (plan item 4, plus F1 and F2 carried from part 1). Specialists: static analysis (shellcheck --severity=warning on the 9 changed shell files: clean), governance, plan drift, Claude adversarial (fresh subagent; ran test_issue_helpers 98/0, test_worktree_create 112/0, test_sitrep_checks 253/0, test_ros2_colcon 1553/0, test_merge_pr_gate 213/0), cross-model: Gemini ran (2 must-fix claimed, rated suggestions here: both need a crafted origin URL and gh_slug shares them; 2 more dropped: a pre-existing workspace-type path, and F1/F2 called out of scope though the owner carried them here), Codex ran (no issues found).

### Findings
- [ ] (suggestion) Parser hardening, in step with gh_slug: userinfo class admits `?`/`#` (`https://evil.example?@github.com/o/r` gives `o/r`), and repo `.`/`..` is accepted (`https://github.com/o/..` gives `o/..`); crafted URLs only — `.agent/scripts/_issue_helpers.sh:64-66`
- [ ] (suggestion) The local-path fixture form accepts any absolute path ending `/github.com/<o>/<r>`, so a local origin under a GOPATH/ghq-style layout is read as GitHub `o/r`; could be narrowed to `fake_remotes/github.com/` — `.agent/scripts/_issue_helpers.sh:70`
- [ ] (suggestion) Owner pattern excludes `_`, so a github.com Enterprise Managed User owner (`name_shortcode`) gives no slug and worktree_create.sh's note says the origin is "hosted elsewhere"; same limit as gh_slug — `.agent/scripts/_issue_helpers.sh:65`
- [ ] (suggestion) The PR closes issue 428 while the same loose host parsing stays in gh_create_pr.sh:136,141, gh_create_issue.sh:130,191,197,249, pr_status.sh:37, git_bug_setup.sh:93, _project_registry.sh:784, and worktree_enter.sh:323-327 still looks a project worktree's bare issue up in the workspace repository first (pre-existing); name these in the PR text or a follow-up issue — `.agent/scripts/worktree_enter.sh:323`

## Checkpoint
**Status**: complete
**When**: 2026-11-24 08:54 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 1 of the pre-push review approved with no must-fix, Ship: recommended; the host's full pre-commit pass over the 12 changed files passed, every hook, no SKIP, on e64aeefd)
**After**: publish
**Decision**: publish

The review's four suggestions stay open and are listed in the pull request text for the owner at the merge question: (1) the slug parser accepts a crafted user part with ? or #, and a repository named . or .., as sitrep_root.sh's gh_slug does; (2) the local test-path form accepts any absolute path ending /github.com/<owner>/<repo>; (3) an owner name with _ gives no slug; (4) five other scripts keep the old loose parsing (captured in the inbox for the owner). Reason for not fixing before the push: each needs an unusual or crafted origin, and the owner's direction on this issue (2026-11-20) is "Let's not waist too much time going for perfect when we can have agents handle the edge cases". Outside reviewers: Gemini ran, found (1), which it rated must-fix and the lead rated a suggestion; Codex ran, found nothing.

## Integrated Review
**Status**: complete
**When**: 2026-11-24 08:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Reviews-read**: none

**PR**: #570 at `95e6593c`
**Sources**: 2 (Local Review (Pre-Push) @ `be996b08` (entry e64aeefd, approved, four open suggestions; covers `95e6593c` via bookkeeping), CI rollup). No hosted review, no hosted-reviewer check-run, no inline or conversation comment on the pull request. Part 1's entries (pull request 542) are closed and not sources here.
**Cross-source confirmations**: 0
**CI**: pending

Owner direction (2026-11-20), applied here: "it's ok if scripts don't handle everything and come back saying they can't do it. If it's occasinal and an agent can deal with, that's fine. If it happens too often, than we can look at root causes and such. Let's not waist too much time going for perfect when we can have agents handle the edge cases."

Summary: no must-fix. Each of the four suggestions was checked by running `extract_gh_slug` on the cited inputs at `95e6593c`; every claim reproduces. S1 to S3 are valid suggestions on unusual or crafted origins, none reachable from an ordinary origin URL, so none is a broken ordinary case; they stay open for the owner's merge-or-fix call (the pull request text already lists all three under "Open, small"). S4 asked for the out-of-scope copies to be named in the pull request text or a follow-up issue; the pull request text names them, so it is addressed here, and whether to open a follow-up issue before `Closes #428` takes effect is the owner's call. CI on `95e6593c`: Validate Documentation passed in both runs; Lint, Validate Adapter Contract and the two repos-manifest suites are still pending in both runs at 08:56; nothing failed.

### Findings
- [x] (suggestion, Local Review (Pre-Push) @ `be996b08`, covers `95e6593c` via bookkeeping) S1, valid: the userinfo class `[^@/[:space:]]+@` admits `?` and `#`, so `https://evil.example?@github.com/o/r` and `https://evil.example#@github.com/o/r` give `o/r` although git would fetch from evil.example; and the repo class admits `.` and `..` (`https://github.com/o/..` gives `o/..`). Reproduced. Only a crafted origin reaches it, and whoever can write `.git/config` can already run code through it; `o/..` gets a refusal from gh, not a wrong action. `sitrep_root.sh`'s `GH_URL` has the same classes, so the fix goes in both together. Fix: exclude `?#` from the userinfo class in both parsers, refuse a repo of exactly `.` or `..`, add rows to the shared table in `test_issue_helpers.sh`. Size: two regex edits in each of two files plus about four table rows — `.agent/scripts/_issue_helpers.sh:48`, `.agent/scripts/sitrep_root.sh:231-232`
- [x] (suggestion, Local Review (Pre-Push) @ `be996b08`, covers `95e6593c` via bookkeeping) S2, valid: the test-fixture branch accepts any absolute path ending `/github.com/<o>/<r>[.git]`; `/home/u/go/src/github.com/o/r` and `/home/u/ghq/github.com/o/r.git` both give `o/r` (reproduced). In those layouts the folder is normally a clone of that very GitHub repository, so the slug is usually right; a wrong slug needs a local folder named after a GitHub repository it is not. Fix: narrow the branch to `/fake_remotes/github.com/`. Size: one regex line, plus moving the one fixture outside `fake_remotes` (`test_worktree_create.sh:1515-1516`, `$SANDBOX/github.com/acme/demo15.git`) and updating the three local-path rows and the header note — `.agent/scripts/_issue_helpers.sh:52`
- [x] (suggestion, Local Review (Pre-Push) @ `be996b08`, covers `95e6593c` via bookkeeping) S3, valid: the owner class `[A-Za-z0-9][A-Za-z0-9-]*` excludes `_`, so a managed-user owner such as `name_short` gives no slug (reproduced with `git@github.com:name_short/r.git`). The result is a skipped lookup and a printed note, not a wrong action, and the worktree is still made; but the note at `worktree_create.sh:762` then says the origin "is hosted elsewhere", which is untrue for such an owner. `gh_slug` has the same limit. Fix: admit `_` in the owner class in both parsers (with a table row), or soften the note to "is not a github.com repository this script can read". Size: one class edit in each of two files plus one row, or one message line — `.agent/scripts/_issue_helpers.sh:47`, `.agent/scripts/worktree_create.sh:762`
- [x] (suggestion, Local Review (Pre-Push) @ `be996b08`, covers `95e6593c` via bookkeeping) S4, valid and addressed: the old loose pattern remains in `gh_create_pr.sh`, `gh_create_issue.sh`, `pr_status.sh`, `git_bug_setup.sh` and `_project_registry.sh`, and `worktree_enter.sh` (unchanged by this pull request) still looks up a project worktree's bare issue in the workspace repository first. These are outside issue 428's item 4, which names `extract_gh_slug` only. The finding asked for them to be named in the pull request text or a follow-up issue; the pull request 570 body names all six under "Not in this issue's scope" (checked). No follow-up issue exists yet; because this pull request closes issue 428, opening one before the merge is the owner's call — `.agent/scripts/worktree_enter.sh:323`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-24 08:57 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (address is the one answer the host may give at findings; merging with boxes open is the owner's alone, and he is away while the loop runs)
**After**: findings
**Decision**: address

The Integrated Review at a0cfd6a7 left three valid suggestions open, each a small fix: S1 (a crafted user part with ? or #, and a repository named . or .., are accepted; fix in both parsers, _issue_helpers.sh and sitrep_root.sh), S2 (the test-fixture local-path form accepts any absolute path ending /github.com/<owner>/<repo>; narrow it to the test sandboxes' fake_remotes/github.com/ folders), S3 (an owner name with _ gives no slug and worktree_create.sh then says the origin is hosted elsewhere, which is untrue). Reason for fixing now rather than asking: a cold read of the final diff comes before the merge question in any case, so a fix round now adds little wait, and the three fixes are a few regex lines with test rows. Issue 563's branch also edits sitrep_root.sh and its suite: the S1 and S3 edits there stay to the slug pattern and its test rows.

## Implementation
**Status**: complete
**When**: 2026-11-24 09:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #570 at `1bf11430`
**Addressed**: Integrated Review at `95e6593c` (2026-11-24 08:58 -05:00)
**Commits**: `72d77eee`, `82603cf2`, `1bf11430`

### Actions
- [x] S1: a `?` or `#` in the https/ssh user part gives no slug, and a repository of `.` or `..` (after the `.git` suffix, so `o/..git` and `o/...git` too) gives none, in both parsers; ten table rows, one (`o/.x`) guarding against over-refusal — `.agent/scripts/_issue_helpers.sh:50-63`, `.agent/scripts/sitrep_root.sh:231-235` (`72d77eee`)
- [x] S2: the local-path form needs `/fake_remotes/github.com/`; the `demo15` fixture moved under `fake_remotes`; rows added for `~/go/src/github.com/o/r`, `~/ghq/github.com/o/r.git`, `remotes/github.com/...` and `not_fake_remotes/github.com/...` (all give nothing); the three host-name local-path rows now sit under `fake_remotes` so they still test the host segment; header notes in `_issue_helpers.sh`, `test_issue_helpers.sh`, `test_merge_pr.sh` and the `script_reference.md` line say `fake_remotes` — `.agent/scripts/_issue_helpers.sh:40-46,57`, `.agent/scripts/tests/test_worktree_create.sh:1505-1517` (`82603cf2`)
- [x] S3: `_` accepted after the owner's first character in both parsers; rows `o_x/r` (now `o_x/r`), `name_short/r.git` and `_o/r` (nothing) — `.agent/scripts/_issue_helpers.sh:25-26,49`, `.agent/scripts/sitrep_root.sh:234-235` (`1bf11430`)

### Host directions applied (listed for the owner's veto)
- S1 and S3 fixed in both parsers with table rows; S2 narrowed to `fake_remotes/github.com/` with the named fixture moved.
- `sitrep_root.sh` edits are only in `GH_URL` (issue 563 also edits the file). `GH_URL` no longer reuses `SLUG`: `SLUG` is also the gh-issue reference grammar shared with `sitrep_checks.sh`, so admitting `_` there would have changed reference parsing in one of two places. `GH_URL` carries its own copy with `_` in the owner; the reference grammar is unchanged.
- The scp-like form's user part (`[^@/:\s]+@`) was left as it was: there git hands the user to ssh and still connects to github.com.

### Checks
Suites run, each on its own (four at a time), all from this worktree:
- `test_issue_helpers.sh`: test_issue_helpers: 130 passed, 0 failed
- `test_sitrep_root.sh`: test_sitrep_root: 65 passed, 0 failed
- `test_sitrep_checks.sh`: test_sitrep_checks: 253 passed, 0 failed
- `test_worktree_create.sh`: PASS: 112 FAIL: 0
- `test_merge_pr.sh`: Results: 175 passed, 0 failed
- `test_merge_pr_gate.sh`: test_merge_pr_gate: 213 passed, 0 failed
- `test_merge_pr_skill.sh`: test_merge_pr_skill: 132 passed, 0 failed
- `test_project_registry.sh`: Results: 425 passed, 0 failed
- `test_precommit_hook_path.sh`: test_precommit_hook_path: 19 passed, 0 failed
- `test_worktree_enter_stderr.sh`: Results: 35 passed, 0 failed
- `test_worktree_remove.sh`: test_worktree_remove: 138 passed, 0 failed
- `test_ros2_colcon.sh`: Results: 1553 passed, 0 failed, 0 skipped
- `test_skill_paths.sh`: test_skill_paths: 200 passed, 0 failed

Commits made with `SKIP=validate-script-tests` (issue 465 rule); the full pre-commit pass is left to the host.
