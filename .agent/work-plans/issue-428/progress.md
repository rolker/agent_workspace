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
