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
