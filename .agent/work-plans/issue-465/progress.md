---
issue: 465
---

# Issue #465 — Run the script test suites when a chunk of work is done, not on every commit

## Issue Review
**Status**: complete
**When**: 2026-11-13 14:50 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #465

### Scope Assessment

**Well-scoped?** Not as written, yes once split. The issue asks for a mechanism, which is two jobs. Job 1 is writing down the rule the owner decided on 2026-11-13 ("yes, do the third option on both machines", "yes, one local run before a pr"): (1) dispatched implement and address-findings agents keep `SKIP=validate-script-tests` on every commit, the progress entry included, never `--no-verify`; (2) they run no full `pre-commit run --files ...` pass, only the suites their change touches, and say so in their entry; (3) the host runs the full pass once per pull request, after the pre-push review approves and before the push, with no SKIP, and a failure there goes back through the loop as findings, not fixed by the host; (4) after publish, fix passes again run only touched suites, and CI on each push is the check, confirmed before the merge checkpoint. Job 2 is moving the suites off the commit hook. This pull request is job 1 only.
**Right repo?** Yes — workspace (`.agent/`, skills, knowledge).
**Serves**: Reviews that catch the real problems, cheaply (the loop's wall-clock cost) — `docs/design.md#rules`; no design-section change.
**Design picture?** No change. `docs/design.md` has no sentence stating the old rule (grep for the hook id, "per commit" and "pre-commit" found only the rules-table hook rows and the `test` verb row, none about when the suites run), so leave it untouched.
**Dependencies**: none open. Issues #399 (old rule), #410 (suite scoping), #444 (parallel runs, merged as PRs 468 and 474) are all done. `git log origin/main -5 -- .agent/scripts/dispatch_phase.sh` shows today's PRs 459/461/467 merged (latest 91967144); `gh pr list --state open` shows only PR 475 (inspiration digests), which touches none of the files below. No collision.

**Pull request 1 — exact scope (write the decided rule where the loop reads it)**

1. `.agent/scripts/dispatch_phase.sh`: the `pass_rule` text at about line 618 ("Hook rule for this dispatched pass (owner-decided 2026-10-20) ...") becomes the 2026-11-13 rule, for `implement|address-findings` in a workspace handoff only: SKIP on every commit including the entry, never `--no-verify`, run only the suites the change touches and say which in the entry, no full `pre-commit run` pass, the host runs it before the push. The `$root_q/.venv/bin/pre-commit` command and its long-timeout paragraph leave the agent's text (the host runs that command now). Update the two comment blocks that restate the old rule: header lines 79-84 and the comment at 605-607. `$root_q` stays only if still used.
2. `.claude/skills/run-issue/SKILL.md`: (a) the "Hook rule for the dispatched implement and fix passes" paragraph at about lines 466-485 rewritten to the new rule, citing the owner's words; (b) step 7 Publish (line 743) gains the host's full pass: after the pre-push review approves, before `git push`, run the main checkout's `.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP and a long timeout (about 4 minutes at 4 jobs on 2026-11-13; give 600000 ms), and a failure goes back through address-findings as findings, never fixed by the host; (c) step 10 (line 880) and step 9 (line 817) where they mention what a push or waiting means: say that after publish a fix pass's push is checked by CI, awaited before the merge checkpoint.
3. `.claude/skills/address-findings/SKILL.md`: step 3's "Dispatched pass" paragraph (lines 150-157) and step 4's paragraph (lines 175-204) that runs the full pass at the end. Step 4 becomes: run the suites your change touches, say so in the entry; the full pass is the host's. A hand-run session and a project pass are unchanged (they commit with every hook).
4. `.agent/knowledge/host_standing_rules.md`: one new row in the Rules table, rule = the host runs the full pre-commit pass once per pull request after the pre-push review approves and before the push, with no SKIP, a failure going back as findings; reason = his words ("yes, do the third option on both machines", "yes, one local run before a pr", 2026-11-13). The file requires a non-empty reason cell, and says a new rule goes in through a pull request.
5. Time texts that become wrong in the same pull request (measured 2026-11-13 on this machine, no more precision): "takes about 2 minutes for a typical fix, about 7 when every suite runs" appears in `dispatch_phase.sh` (line 618, which disappears) and `address-findings/SKILL.md` (lines 198-199): replace with "about 4 minutes at 4 jobs, against 14 to 18 at one job" (240 s against 824 to 1069 s). `run_script_tests.sh` header lines 150-155 and the comment above the hook in `.pre-commit-config.yaml` (lines 85-89) restate the old rule (SKIP intermediate, run once before the entry); reword them to point at the new rule. Editing `.pre-commit-config.yaml` and the runner triggers the full suite run on this branch, which is expected; do it as the last commit so it runs once. `.agent/knowledge/script_reference.md` line 56 needs a change only if it mentions run timing (it names the hook, not a time).
6. Tests that pin the old text: `.agent/scripts/tests/test_dispatch_phase.sh` lines 942-1002 and 1122-1129. Pinned phrases to replace: `*"SKIP=validate-script-tests"*`, `*"\`$SB/.venv/bin/pre-commit run --files "*`, `*'$(git diff --name-only main...HEAD)'*`, `*"600000 ms"*"wait for its exit"*`, `*"suites those files reach when a changed file that still exists matches that hook"*..."about 2 minu..."`, `*"sub-issue worktree it also covers the parent's files"*`, and the spaced-root block (lines 971-992) that proves the printed `printf %q` command runs. The new pins: SKIP on every commit including the entry, `--no-verify` forbidden, "the suites your change touches" plus "say so in your entry", and the absence of `pre-commit run --files` (so the rule cannot drift back into asking the agent to run it). The project-handoff and review-phase negatives (lines 996-1002, 1126) stay as they are. If the printed pre-commit path is gone, drop the spaced-root block or keep it only if the host path is printed elsewhere. `test_skill_paths.sh` pins none of these texts today (grep found no hook-rule phrase and no `host_standing_rules` row count); add a `has` pin there for the new run-issue step 7 sentence and the new standing-rules row (the file already pins run-issue and host-standing-rules rows by the same helper). `test_script_tests_hook_scope.sh` pins only the `RUN_SCRIPT_TESTS_JOBS` comment (line 552), which stays.

**Wider question — move the suites off the commit hook (job 2): a later pull request, with its own issue.** Reasons: (a) it changes what a hook guarantees for work outside the loop, which the owner has not decided, and needs a design choice (a pre-push hook that only the work's own clone has, a CI-only check, or a `make` target), while job 1 is decided and costs nothing to ship; (b) the AGENTS.md rule "Run pre-commit hooks before committing" (line 35, plus lines 143 and 158 touching it) would need rewording, and AGENTS.md is Ask First and capped at 200 lines; (c) pull request 1 already removes the cost the owner complained about for the loop (every dispatched commit skips the suites, the host runs one pass per pull request), so job 2 only serves a commit by hand or another framework's session, where the guarantee is worth keeping until a replacement exists. Keep #465 open with that remainder, or open a successor issue for it; open the successor only when the owner asks. The host leaning is right.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | The rule is decided; the pull request writes it down and removes the now-wrong handoff text and the agent's long full-pass run. |
| Keep one current design | OK | No design section changes; `docs/design.md` states no sentence about when the suites run, so it stays untouched. |
| Enforcement over documentation | Watch | The rule stays text in a handoff, and the new pins keep it from drifting. The enforcing replacement (suites off the hook, run before push) is job 2. |
| Verify before claiming | OK | The time texts take 2026-11-13 measurements (240 s at 4 jobs, 824 to 1069 s at one job), with no more precision than measured. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0005 (CI is the enforcement layer, hooks the local mirror) | Yes | Consistent: CI confirms each push after publish; the local full pass is the pre-push mirror. |
| ADR-0013 (progress timeline) | Yes | Implementation entries must say which suites ran. |
| ADR-0017 (design in the same change) | No | No design sentence states the old rule. |

### Consequences

- Both machines already run by this rule through hand-pasted handoffs; after the pull request merges, the dispatcher prints it, so the host stops pasting.
- A change to `.pre-commit-config.yaml` or the runner makes the hook run every suite on this branch (about 4 minutes at 4 jobs); put those edits in one late commit.
- AGENTS.md is not touched, so no Ask First is needed for this pull request.

### Recommendations

- Verdict: ready to plan as ONE pull request with the six file groups above (dispatcher text, run-issue skill, address-findings skill, host standing rules row, the stale time and rule comments, the pinning tests). Keep `docs/design.md` and AGENTS.md out of it.
- Leave the wider question (suites off the commit hook, plus the AGENTS.md wording) for a later pull request; do not close #465 with this one unless the owner says the remainder is dropped.
- In the pull request description, quote the owner's decision and the 2026-11-13 timings (240 s at 4 jobs against 824 to 1069 s at one job; CI lint 7 to 9.5 minutes against 11 to 13.5).

## Checkpoint
**Status**: complete
**When**: 2026-11-13 14:42 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review scopes the issue to one pull request that writes the owner's decided rule where the loop reads it, and leaves the wider question, taking the suites off the commit hook and the AGENTS.md wording, for a later pull request because the owner has not decided it and AGENTS.md is Ask First; that keeps the issue's goal and adds or drops no behaviour his words ask for)
**After**: issue-actions
**Decision**: proceed

Read: the Issue Review at 26e4f013 and its report. The owner's rule (2026-11-13): "yes, do the third option on both machines", "yes, one local run before a pr". His instruction for this drive: "Keep in mind the lessons about what waists time and modify the skills as needed to be efficient".

### Decisions made (owner may veto)
- One addition to the review's scope, in the same paragraphs of run-issue this pull request already rewrites (step 10, "The host owns every push"): record-only commits (review entries, triage entries, checkpoints) are pushed once, with the merge, not after each phase; commits that change code are still pushed when made, so CI and the pull-request-mode review see them. Each push starts two CI runs; on 2026-11-13 most pushes on a published pull request carried records only. Issue 477's review ranked this first of the later changes and marked it the host's to decide — undoing it: drop that paragraph's change from the pull request.
- Issue 465 stays open after this pull request for the wider question.

## Plan Authored
**Status**: complete
**When**: 2026-11-13 14:45 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-465/plan.md` at `f4d00412`

One pull request ("Part of #465"): the 2026-11-13 rule in the dispatcher text, run-issue, address-findings and the host standing rules, with the host's one full pass before the push and record-only pushes held until the merge, pinned by tests; stale time and rule comments last. The implement pass finds its suites with suites_for_files.sh.

## Plan Review
**Status**: complete
**When**: 2026-11-13 14:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #465 — Run the script test suites when a chunk of work is done, not on every commit
**Plan**: `.agent/work-plans/issue-465/plan.md` at `f4d00412`
**Branch**: `feature/issue-465`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One pull request, the six file groups of the Issue Review plus the host's record-push rule; `AGENTS.md`, `CLAUDE.md`, `docs/design.md`, `.github/workflows`, `merge_pr.sh` untouched; "Part of #465", issue stays open for job 2. |
| Issue alignment | Needs work | Serves line, as checked: "Reviews that catch the real problems, cheaply (the loop's wall-clock cost): `docs/design.md#rules`". That is not a section name under `README.md#workspace-goals` (finding 5). The rule itself is the owner's and is carried faithfully, but the agent's suite command and the host's failure path do not do what the rule says (findings 1, 2). |
| File targeting | Good | Grep for the old rule ("intermediate commits", `pre-commit run --files`, "about 7", issue #399) finds it only in the plan's files: dispatcher, its test, run-issue, address-findings, runner header, hook comment. |
| Consequences | Needs work | The failure route through `address-findings` has no finding to act on (finding 2), and address-findings' step 2 is the consequence to update. |
| Principle alignment | Needs work | "Only what's needed": as written the agent's per-pass run costs as much as the old rule's run (finding 1). "Test what breaks": pins are planned and fail if the old text returns (note 7). |
| ADR compliance | Good | ADR-0005 (CI the enforcement layer, local run the mirror) and ADR-0013 (entry names the suites run) handled; ADR-0017 not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment, must-fix]** The agent's suite command prints `ALL` on every branch, and selects most suites even when fixed. `suites_for_files.sh` prints `ALL` when a passed file is outside the hook's `files:`/`exclude:` scope (it expects pre-commit's filtered list). Every loop branch carries `.agent/work-plans/issue-<N>/plan.md` and `progress.md`, which the hook excludes, so `-- $(git diff --name-only origin/main...HEAD)` prints `ALL` every time (checked: `plan.md progress.md` -> ALL; `run-issue/SKILL.md` + `progress.md` -> ALL; `docs/design.md` -> ALL). Filtered to the hook's scope, the kinds of change made on 2026-11-13 still reach most of the 49 suites: run-issue or address-findings skill text 38, `dispatch_phase.sh` with its test 36, `merge_pr.sh` 36, `review_progress.sh` 36; of the 12 merges since 2026-11-12, 4 print ALL (they touch the runner) and 8 reach 38 to 43 suites. A knowledge doc reaches 2 or 3 (`host_standing_rules.md` 3, `script_reference.md` 2), so the 2026-11-09 inbox note that a knowledge doc prints ALL is true only for the unfiltered call. And the plan has the agent run each listed suite with `bash .agent/scripts/tests/<suite>`, one after another, without the runner's parallel jobs, deletion check or leak guard: 36 to 49 suites run one at a time is roughly the one-job time (14 to 18 minutes for all 49). How it goes wrong: every implement and fix pass spends longer in the suites than under the old rule, and the host's pass comes on top, so the pull request removes no wall-clock and adds some. Resolution, for the implement pass (mechanism, host may veto): the agent text drops the mapper and says: run the suites that test what you changed, the `test_<name>.sh` of each script you changed and the suite that pins any text you changed (`test_skill_paths.sh` for skill and knowledge text, `test_dispatch_phase.sh` for the dispatcher), each with `bash .agent/scripts/tests/<suite>`, and name them in your entry; what reaches further is the host's pass and CI's. If exact selection is wanted instead, the working form is `$root_q/.venv/bin/pre-commit run validate-script-tests --files $(git diff --name-only origin/main...HEAD)` with no SKIP in that command (pre-commit filters to the hook's scope, the runner maps, runs in parallel and handles deletions), but it costs what the old rule's run cost. The test pins and run-issue's Hook-rule paragraph follow whichever text is chosen.
2. **[Consequences, must-fix]** The host's full-pass failure route dead-ends. The plan puts the pass in step 7 (Publish), which runs after the `publish` checkpoint has already been written `**Decision**: publish`, and sends a failure "through address-findings as findings (checkpoint `publish` answered `address`)". `address` is in the host's vocabulary at `publish` (`/orchestrator`'s table) and `dispatch_phase.sh` routes `after in ("publish", "rounds")` + `address` to `address-findings`, but `address-findings` step 2 reads only the latest review entry's open boxes; after an approved pre-push review `open` is empty (the LGTM box is not listed when the counts are 0), so the pass reports "nothing to address" and exits without a commit. How it goes wrong: the failure is never fixed by the loop; the host either fixes it inline (forbidden) or pushes anyway. Resolution: run the pass when `checkpoint:publish` is raised, before it is answered (step 6/7 text); on failure write the checkpoint `**After**: publish`, `**Decision**: address` with the failing suites and their last output lines quoted, quote the same in the `address-findings` handoff, and add to address-findings step 2 that a dispatched pass whose handoff quotes a host full-pass failure treats that failure as its open finding even when `open` is empty. Its `## Implementation` then routes to another `review-code --branch` round, which is the loop working as intended.
3. **[Consequences, note]** Which tree: say the pass runs on the exact head that gets pushed, after the approval and after step 8's merge of the base, never alongside the review; if anything but record commits lands before the push, it runs again. Main moving after that is the combined-with-main CI run's to catch, as it did on pull request 468; no extra step needed.
4. **[Consequences, note]** Timeout: 600000 ms is the Bash ceiling, and "about 4 minutes at 4 jobs" holds on a 16-CPU machine (the runner's default is CPUs/4, between 2 and 6). A machine with fewer than 16 CPUs runs 2 or 3 jobs, roughly 6 to 9 minutes. Say: run it in the background and wait for its exit notification (or set `RUN_SCRIPT_TESTS_JOBS=4`); a run cut off at the timeout has not passed. Use `origin/main...HEAD` rather than `main...HEAD` in the host command (a stale local `main` only widens the list, so this is cosmetic); for a sub-issue branch the list includes the parent's files, a superset, which is fine.
5. **[Issue alignment, note]** The Serves line should name a section under `README.md#workspace-goals`: "Quality of the work" ("economical, but never at the cost of quality"), with `docs/design.md#rules`. Copy it so into the pull request description.
6. **[Consequences, note]** "Push records once" checks out against the code, on the plan's condition. (a) `fetch_pr_reviews.sh` takes `headRefOid`; `review_progress.sh sources --head` checks coverage in the local repository (review SHA an ancestor of the head with only bookkeeping between) and refuses nothing for a local head ahead of GitHub's; a push sends the whole branch, so every record made before a code push rides on it, and only records after the last code push stay local. (b) The gate (a review at R covers head H through bookkeeping-only commits) and the CI target (`_ci_walk_bookkeeping` walks back to the newest bookkeeping-only ancestor with a CI verdict; `.agent/work-plans/*` is a bookkeeping pattern) make the final record push cost no CI wait; the walk stops at a merge commit, which is a code push anyway. A workspace gate reads the worktree's working copy; an owning package checkout ahead of origin is not read at all (`_GATE_OWN_NOREAD`), so the push before `merge_pr.sh` is required there too, as the plan says. (c) `pr_start.py` and `check_branch_updates.sh` read local state or the base, not the branch on GitHub. The real cost: a drive resumed on the other machine reads origin's timeline without the latest records and re-runs a phase (for example triage again); wasted time, not a wrong merge. Add one clause to step 10: also push outstanding records when a drive parks or the session ends.
7. **[Principle alignment, note]** Tests: the planned pins (`pre-commit run --files` absent from the agent's text, SKIP on every commit including the entry) fail if the old rule's text returns; add a negative pin on "intermediate" so the old scope of SKIP cannot come back either. The spaced-root block tests only the printed `$root_q/.venv/bin/pre-commit` path: with finding 1's first resolution that path is gone and dropping the block loses nothing still present; with the hook-id form, keep the block and adapt it to `run validate-script-tests --files`. The review-phase and `--type project` negatives stay meaningful. The rule stays workspace-only, as before: a package issue is a project handoff and gets no rule, and the relative `.agent/scripts/tests/` path is printed only into a workspace worktree, where it resolves.

### Summary

The plan carries the owner's rule to the right files with the right scope, and the record-push analysis holds against the code. Two things must change before or during implementation: the agent's suite command as written always runs everything (and selects 36 to 43 of 49 suites even when fixed), and a failed host pass has no finding for `address-findings` to act on. Both are text changes inside files the plan already edits; no re-plan is needed if the implement handoff carries findings 1 and 2.

### Recommended Actions

- [ ] Finding 1: replace the `suites_for_files.sh` instruction in `pass_rule`, run-issue's Hook-rule paragraph and address-findings step 4 with "the suites that test what you changed" (or the hook-id `pre-commit run validate-script-tests --files` form), and pin the chosen text
- [ ] Finding 2: run the host pass when `checkpoint:publish` is raised, record a failure as `**Decision**: address` with the failure quoted, and let address-findings act on a quoted host-pass failure when `open` is empty
- [ ] Notes 3 to 7 as the implement pass sees fit: which tree, background run and `origin/main`, the Serves goal name, the record push at session end, the "intermediate" negative pin

## Checkpoint
**Status**: complete
**When**: 2026-11-13 14:52 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work with two must-fix findings, and it says both are text changes in files the plan already edits and need no re-plan if the implement handoff carries them; the host takes the review's own fix for each, so a second plan round would add about ten minutes and no information; first host answer at this checkpoint)
**After**: plan
**Decision**: proceed

Read: the Plan Review at 6ebf04f3 and its report. Both must-fix findings and notes N1 to N5 go into the implement handoff verbatim.

### Decisions made (owner may veto)
- F1: the agent does not call suites_for_files.sh. It runs the suites that test what it changed: the test_<name>.sh of each changed script, plus the suite that checks any text it changed (test_skill_paths.sh for skill and knowledge text, test_dispatch_phase.sh for the dispatcher), names them in its entry, and leaves the rest to the host's pass and CI. This is what both machines did all day on 2026-11-13. The review measured the alternative: the selection script prints ALL on every loop branch as called, and 36 to 43 of 49 suites when filtered — undoing it: use the exact-selection command and pay about the old run's cost per pass.
- F2: the host runs its full pass when the publish checkpoint is raised, before answering it, on the exact head that will be pushed; on a failure it answers address with the failing suites quoted, and address-findings treats a quoted host-pass failure as its open finding — undoing it: none sensible; without it a failed pass has no route back into the loop.
- N4: outstanding records are also pushed when a drive parks or the session ends, so a drive resumed on the other machine does not re-run a phase — undoing it: drop that sentence.

## Implementation
**Status**: partial
**When**: 2026-11-13 15:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-465 at `f7fdd50f`

Stopped early on the coordinator's word (machine shutting down). Every plan step and binding change (F1, F2, N2, N4, N5) is written and committed; one suite result is unexplained.

### Done
- `4a526aa2`, `eb369bb1` dispatch_phase.sh: new `pass_rule` (SKIP on every commit incl. the entry, never --no-verify, run only the suites that test what changed, name them in the entry, no pre-commit command printed); `root_q` dropped; header and inline comments updated. test_dispatch_phase.sh: old pins and the spaced-root block replaced by pins on the new sentences, plus negatives on `pre-commit run --files`, `.venv/bin/pre-commit`, `run_script_tests.sh`, `suites_for_files.sh`, "intermediate"; review-phase and project negatives also refuse "Hook rule".
- `9e807298` run-issue: Hook rule paragraph (owner's words); step 7 host full pass at checkpoint:publish (and rounds) before answering, on the head to be pushed, `origin/main...HEAD`, background or long timeout, failure answered `address` with failing lines quoted; step 9 CI confirmed before merge checkpoint; step 10/11 record-only push rule (before merge_pr.sh with rev-list/status check, issue #462; and when a drive parks). address-findings: step 2 host-pass failure as open finding, step 3 SKIP on every commit, step 4 own suites only, step 5 `**Addressed**` for a host-pass fix. host_standing_rules.md: one new row. script_reference.md: runner row's rule sentence was the old rule, corrected. test_skill_paths.sh: pins for all of it.
- `f7fdd50f` run_script_tests.sh header and .pre-commit-config.yaml hook comment (comments only), last.

### Suites (each on its own; full pass skipped on the owner's direction)
- test_dispatch_phase.sh: 232 passed, 0 failed (tree at eb369bb1 plus the uncommitted skill edits; dispatcher unchanged since)
- test_skill_paths.sh: 154 passed, 0 failed (tree = 9e807298)
- test_checkpoint_269.sh: 43 passed, 0 failed; test_package_issue_loop.sh: 220 passed, 0 failed (tree = 9e807298 content)
- test_script_tests_hook_scope.sh: 325 passed, 3 failed (tree = f7fdd50f content): "hub guard: register_project.sh" selects 35 suites (limit 16), including test_cross_model_review.sh. Not investigated; may come from this branch's new text (suites_for_files.sh maps by references) or exist on main.
- test_run_script_tests.sh: not run (stopped for the shutdown).

### Left
- Find out whether the hook-scope hub-guard failure is caused by this branch (compare against origin/main), and fix if so.
- Run test_run_script_tests.sh.
- test_address_findings.sh not run: it does not read the skill text.

## Checkpoint
**Status**: complete
**When**: 2026-11-16 12:39 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (first retry for this phase; the partial entry says every plan step is written and committed and only verification is left: three failing checks in test_script_tests_hook_scope.sh not yet compared with main; the owner asked on 2026-11-16 to "have agents work on the other in progress issues we had going")
**After**: phase-failed
**Decision**: retry
**Phase**: implement

Re-dispatch the implement pass to finish the verification and write a complete entry.

## Implementation
**Status**: complete
**When**: 2026-11-16 12:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-465 at `f8557cfc`

Retry of the partial entry at 5c857dfd: verification finished, and the one failing suite fixed.

### The merged tree
- Since the old merge base, main changed none of the files this plan edits except one line in test_script_tests_hook_scope.sh (a ROOT_READERS row, PR 478). A grep of the tree for the old rule's wording ("intermediate commits", "about 7 when", "about 2 minutes", "once ... before its entry") finds only the new negative pin in test_skill_paths.sh. No rework needed.

### The three hook-scope failures: this branch's, now fixed
- `suites_for_files.sh -- .agent/scripts/register_project.sh` selects 13 suites (12 + test_checkpoint_269.sh) in the main checkout at d06cce95, 37 on this branch before the fix: the failure was this branch's.
- Cause: the dispatcher's hook-rule text names `test_dispatch_phase.sh` and `test_skill_paths.sh`, and test_dispatch_phase.sh pins that text. The mapper expanded the closure through every referenced code file, suites included, so every suite that reads dispatch_phase.sh inherited test_skill_paths.sh's reach. Removing the two names in a scratch clone brought the count back to 13 (14 with the pin).
- Fix (`f8557cfc`, mechanism decision for the host's veto): in suites_for_files.sh a suite reached through another file joins the closure but is not expanded (naming a suite does not run it; only the runner runs one by name, the required suite). Measured with `--dump`: on main's tree 283 closure edges drop, all reached through a suite named as data, and no file loses its last suite; on this branch register_project.sh is back to 13. Header comment and the script_reference.md row say so. New cases in test_run_script_tests.sh (case l, ast fixture): a script naming a suite and a suite reading that script; the leaf case fails on the old mapper (169 passed, 1 failed, checked in a scratch clone) and passes on the new.
- Rejected: spelling the suite names in pieces in the dispatcher text so the mapper cannot see them; that hides the edge instead of fixing it.

### Suites (each on its own, final tree content)
- test_script_tests_hook_scope.sh: 333 passed, 0 failed
- test_run_script_tests.sh: 170 passed, 0 failed
- test_dispatch_phase.sh: 232 passed, 0 failed
- test_skill_paths.sh: 154 passed, 0 failed

### Full pass
- This handoff's conventions (printed by main's dispatcher, still the 2026-10-20 rule) asked for one `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP; run at f8557cfc, exit 0, 3 min 46 s on 16 CPUs. Every hook Passed (validate-script-tests ran every suite: the branch touches the runner, the mapper and the hook config) except adapter contract, black, flake8, pylint: no files to check.
- AGENTS.md, CLAUDE.md, docs/design.md, merge_pr.sh, .github/workflows untouched (`git diff --stat origin/main...HEAD` lists none of them).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-16 12:56 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-465 at `ecc3ca00`
**Base**: origin/main
**Depth**: Deep (reason: 13 files, about 830 changed lines; .pre-commit-config.yaml, skill and knowledge files are override triggers)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

Reviewers: static analysis (shellcheck, yamllint) clean; governance, plan drift, Claude adversarial (fresh subagent) ran; Gemini (agy) and Codex completed (EXIT=0, short but substantive). Suites run here on ecc3ca00: test_run_script_tests.sh 170/0, test_script_tests_hook_scope.sh 333/0, test_dispatch_phase.sh 232/0, test_skill_paths.sh 154/0, test_checkpoint_269.sh 43/0.

Plan drift, suites_for_files.sh leaf change: accepted on its merits. Old and new mapper --dump on this branch's tree: 858 closure edges drop, none gained, and no file is left with no suite. No suite and no script runs another suite by name (grep: suite names appear only as fixture strings, comments, the runner and CI YAML), so no dropped edge was a real test of the file. A future suite that runs another suite would need a `# covers:` line; the new comment says so. List it in the pull request description as a mechanism decision the host may veto.

Owner rule: the dispatcher text, run-issue step 4, address-findings steps 3 and 4 and host_standing_rules.md agree with each other and with the 2026-11-13 words. AGENTS.md and CLAUDE.md are untouched.

### Findings
- [x] (must-fix) A host full-pass failure is reopened by a later fix pass: step 2 counts it when "the newest `## Checkpoint`" quotes it, but a changes-requested review after the fix routes to address-findings with no new checkpoint (dispatch_phase.sh next, Local Review (Pre-Push) row), so the second pass re-acts on the fixed failure and stamps `**Addressed**: host full pass` again; count it only while no `## Implementation` follows that checkpoint (or only when the handoff quotes it) — `.claude/skills/address-findings/SKILL.md:108`
- [x] (suggestion) The suite-naming rule finds no suite for 44 of 69 scripts, many of them named directly by suites (review_progress.sh 8, _worktree_helpers.sh 11, suites_for_files.sh 4, pr_start.py 3), so the pass runs none and a defect first shows at the host's pass after approval, costing another round; e.g. add the suites that name the changed script's file — `.agent/scripts/dispatch_phase.sh:619` (mirrored in run-issue step 4 and address-findings step 4)
- [x] (suggestion) No repeat cap on host `address` answers at `publish` after a failed full pass (orchestrator caps `rounds` only, SKILL.md:84-86); a pass that keeps failing loops publish, address, review indefinitely; say the second failure in a row goes to the owner — `.claude/skills/run-issue/SKILL.md:779`
- [x] (suggestion) Step 7 sequencing: say the pass runs before the checkpoint dialog is shown and a failure is answered by the host without asking; at `rounds` run it only once `publish` is the chosen answer, since an `address` answer changes the code anyway — `.claude/skills/run-issue/SKILL.md:745`

## Implementation
**Status**: complete
**When**: 2026-11-16 13:06 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-465 at `6414f4ff`
**Addressed**: Local Review (Pre-Push) at `ecc3ca00` (2026-11-16 12:56 -05:00)
**Commits**: 55847375, 99b5532d, 9082fc15, 6414f4ff

### Actions
- [x] (must-fix) A host full-pass failure is reopened by a later fix pass — `.claude/skills/address-findings/SKILL.md` step 2. Host decision (for the owner's veto): fix it. Now: the failure "is an open finding only while no `## Implementation` entry follows the checkpoint that quotes it"; a later pass "does not act on it again or name it in `**Addressed**`, even when its handoff still quotes it"; the exit line reads "no host full-pass failure is open". run-issue step 7 says the same ("until a fix pass's `## Implementation` follows that checkpoint"). Pinned in test_skill_paths.sh beside the neighbouring address-findings pins. (55847375)
- [x] (suggestion) The suite-naming rule finds no suite for most scripts — `.agent/scripts/dispatch_phase.sh` hook rule, run-issue step 4, address-findings step 4. Host decision (for the owner's veto): adopt; reason: a defect that first shows at the host's full pass, after an approving review, costs a fix round and a review round. The three places now carry the same words: "its `test_<name>.sh` and any `test_<name>_*.sh` (...), and every suite that names the script's file, which one grep lists: `grep -lwF <file name> <worktree>/.agent/scripts/tests/test_*.sh`". The owner's meaning is unchanged (only the suites that test what the pass changed; the host runs the one full pass). Measured on this tree: 8 of 66 scripts outside tests/ get no suite (bootstrap.sh, generate_make_skills.sh, git_bug_setup.sh, git_helpers.sh, lock.sh, pr_status.sh, revert_feature.sh, unlock.sh), the most any script selects is 18 (_project_registry.sh). Pins: test_skill_paths.sh (run-issue, address-findings) and test_dispatch_phase.sh (dispatcher) check the same fragment; test_dispatch_phase.sh also runs the printed grep (lists test_dispatch_phase.sh for dispatch_phase.sh; whole-word match, so `phase.sh` does not match `x_phase.sh`). The skills write `<worktree>/` before the path because test_skill_paths.sh forbids a bare workspace-relative path in a skill. (99b5532d)
- [x] (suggestion) No limit on host `address` answers at `publish` after a failed full pass — `.claude/skills/run-issue/SKILL.md` step 7, `.claude/skills/orchestrator/SKILL.md` repeat-limit paragraph. Host decision (for the owner's veto): adopt. run-issue step 7 has a new bullet "**It fails again**: a second failure in a row goes to the owner", the host shows the dialog with the failure quoted; the orchestrator paragraph gets one clause: "or one host `address` answer to a failed full pass at `publish` or `rounds` (`run-issue` step 7) when the next full pass fails too". Pinned in test_skill_paths.sh. (6414f4ff)
- [x] (suggestion) Step 7 sequencing — `.claude/skills/run-issue/SKILL.md` step 7. Host decision (for the owner's veto): adopt both points. Now: the pass runs "before the checkpoint dialog is shown: the host answers a failure itself, without asking the owner"; "At `checkpoint:rounds` the pass runs only once `publish` is the chosen answer, by the owner or by the host, and before that answer is recorded"; a failure there is recorded as the host's `address`, the chosen `publish` and who chose it named in the entry's body. Pin updated in test_skill_paths.sh. (9082fc15)

### Suites (each on its own with bash, from the worktree, on the final content)
- test_skill_paths.sh: 158 passed, 0 failed (skill and orchestrator text, and a changed suite)
- test_dispatch_phase.sh: 233 passed, 0 failed (dispatch_phase.sh changed, and a changed suite)
- Suites that name dispatch_phase.sh, by the new rule: test_records_write_gate.sh 68 passed, 0 failed; test_review_code_convergence.sh 38 passed, 0 failed; test_package_issue_loop.sh 220 passed, 0 failed
- Extra, because the previous round's mapper problem came from the dispatcher text: test_script_tests_hook_scope.sh 333 passed, 0 failed; test_run_script_tests.sh 170 passed, 0 failed; `suites_for_files.sh -- .agent/scripts/register_project.sh` still selects 13 suites.
- Full pass left to the host (owner's 2026-11-13 rule); every commit here used `SKIP=validate-script-tests`, no `--no-verify`.

### Notes for the host
- Left as is: the suites_for_files.sh leaf change of the previous pass (accepted by the review); the pull-request description still needs to list it as a mechanism decision the owner may veto.
- Not changed: the host_standing_rules.md hook-rule row. It stays true (it states the first failure going back as findings) but does not mention the second-failure cap; add it there if the row should carry the whole rule.
- AGENTS.md, CLAUDE.md and docs/design.md untouched; none of them states the changed rules.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-16 13:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent adf2b4e2a1bdf0477, resume 1 of 3)
**Verdict**: changes-requested

**Branch**: feature/issue-465 at `fd40b9c4`
**Base**: origin/main
**Depth**: Deep (reason: whole-diff classification, 14 files, about 960 changed lines; .pre-commit-config.yaml, skill and knowledge files are override triggers)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 1), not rising — fix and ship rather than another full round

Reviewers: static analysis (shellcheck on the 3 changed scripts) clean; governance, plan drift, Claude adversarial (fresh subagent) ran; Gemini (agy) and Codex completed (EXIT=0). Suites on fd40b9c4: test_skill_paths.sh 158/0, test_dispatch_phase.sh 233/0, test_checkpoint_269.sh 43/0, test_script_tests_hook_scope.sh 333/0.

Round 1 findings: all four closed in the text and pinned (55847375, 99b5532d, 9082fc15, 6414f4ff); the must-fix's fix opened the new must-fix below. The grep does what the sentence says: `-w` treats `_` as a word character, so `phase.sh` does not match `x_phase.sh`, and a leading `_` is fine; it selects 11 suites at most for common helpers. The three texts carry the same words (pinned), and the rule still says the owner's 2026-11-13 rule. host_standing_rules.md need not carry the second-failure cap: that file holds the owner's rules, and the cap is the host's mechanism decision for his veto, like the record-push rule.

### Findings
- [x] (must-fix) Any later `## Implementation` closes the host full-pass failure, a partial or failed one too: after such a pass, phase-failed `retry` dispatches address-findings again, the rule (and "even when its handoff still quotes it") says the failure is closed, `open` is empty after an approved review, and the retry exits "nothing to address" with the failure unfixed; say a `**Status**: complete` `## Implementation`, in both places — `.claude/skills/address-findings/SKILL.md:111`, `.claude/skills/run-issue/SKILL.md:796`
- [x] (suggestion) The second failure goes to the owner, but nothing says his `address` answer's checkpoint entry and the handoff quote the failure; without the quote address-findings finds nothing open and exits — `.claude/skills/run-issue/SKILL.md:803`
- [x] (suggestion) "Second failure in a row" counts the newest earlier `publish`/`rounds` checkpoint, so a review-findings `rounds` `address` between two failed passes hides the first; count the previous full-pass result instead, use the same words in the orchestrator clause, and say a full-pass `address` does not count toward the two-at-`rounds` limit — `.claude/skills/run-issue/SKILL.md:803`, `.claude/skills/orchestrator/SKILL.md:87`
- [x] (suggestion) The grep finds direct mentions only: a module reached by import (`lib/workspace.py`: 1 suite by grep, about 31 by the hook's map) or a helper sourced through another script gets fewer suites; add that a suite reaching a script only through another script or an import is the host pass's, and list the move away from the plan's `suites_for_files.sh` selection in the pull request description — `.agent/scripts/dispatch_phase.sh:619` (mirrored in run-issue step 4 and address-findings step 4)

## Implementation
**Status**: complete
**When**: 2026-11-16 13:15 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a9120ef3cbfa67853, resume 1 of 3)

**Branch**: feature/issue-465 at `82ead841`
**Addressed**: Local Review (Pre-Push) at `fd40b9c4` (2026-11-16 13:10 -05:00)
**Commits**: 60c2c7ee, 7ba303bc, cf745e3f, 82ead841

### Actions
- [x] (must-fix) Any later `## Implementation` closed the host full-pass failure, a partial or failed one too — `.claude/skills/address-findings/SKILL.md` step 2, `.claude/skills/run-issue/SKILL.md` step 7. Host decision (for the owner's veto): the closing entry is a `## Implementation` with `**Status**: complete`; a partial or failed one leaves the failure open, so a retry still fixes it. address-findings now: "only while no `## Implementation` entry with `**Status**: complete` follows the checkpoint that quotes it", "A `partial` or `failed` `## Implementation` leaves it open, so a retry still fixes it", and the check is `grep -nE '^(## |\*\*Status\*\*)' <progress.md>`. run-issue step 7 says the same. Pins updated in test_skill_paths.sh. (60c2c7ee)
- [x] (suggestion) The owner's `address` to a second failure did not say it quotes the failure — run-issue step 7. Host decision (for the owner's veto): adopt. Now: "When he answers `address`, his `## Checkpoint` entry (`**Decided-by**: owner`, his words in the body) and the `address-findings` handoff quote the failure as for the host's answer, so that skill's step 2 finds it open." Pinned. (7ba303bc)
- [x] (suggestion) "Second failure in a row" counted the newest earlier `publish`/`rounds` checkpoint — run-issue step 7, orchestrator repeat-limit paragraph. Host decision (for the owner's veto): adopt. run-issue: "\"In a row\" is judged by the previous full-pass result, not by the checkpoints between", "When this pass fails and the previous full-pass result was a failure too" (a full pass is recorded only when it fails; one that passes is followed by the push), and "A host `address` answer to a failed full pass does not count toward `/orchestrator`'s limit of two host `address` answers at `rounds` in a row". Orchestrator clause, same words: "or a full pass that fails when the previous full-pass result was a failure too (`run-issue` step 7; a host `address` answer to a failed full pass does not count toward the two at `rounds`)". Pins updated. (cf745e3f)
- [x] (suggestion) The grep finds direct mentions only — dispatcher hook rule, run-issue step 4, address-findings step 4. Host decision (for the owner's veto): adopt the one clause, same words in the three: "A suite that reaches a script only through another script or an import is left to the host's full pass." Pinned in test_dispatch_phase.sh and test_skill_paths.sh. The pull-request-description notes (the move away from the plan's suites_for_files.sh selection; the suites_for_files.sh leaf change) are the host's. (82ead841)

### Suites (each on its own with bash, from the worktree, on the final content)
- test_skill_paths.sh: 160 passed, 0 failed (skill text, and a changed suite)
- test_dispatch_phase.sh: 233 passed, 0 failed (dispatch_phase.sh changed, and a changed suite)
- Suites that name dispatch_phase.sh, by the branch's rule: test_records_write_gate.sh 68 passed, 0 failed; test_review_code_convergence.sh 38 passed, 0 failed; test_package_issue_loop.sh 220 passed, 0 failed
- Extra, for the dispatcher-text mapper risk: test_script_tests_hook_scope.sh 333 passed, 0 failed; `suites_for_files.sh -- .agent/scripts/register_project.sh` still selects 13 suites.
- Full pass left to the host; every commit used `SKIP=validate-script-tests`, no `--no-verify`.

### Not changed
- host_standing_rules.md (host decision: the row needs no change). AGENTS.md, CLAUDE.md, docs/design.md untouched.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-16 13:17 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent adf2b4e2a1bdf0477, resume 2 of 3)
**Verdict**: approved

**Branch**: feature/issue-465 at `035cb089`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 3 | **Ship**: recommended — no must-fix findings

Scope: the round-2 entry's four findings and the fix diff 275ab7c0..035cb089 (60c2c7ee, 7ba303bc, cf745e3f, 82ead841). Cross-model reviewers: skipped (round-3 convergence check, per handoff); the Claude adversarial specialist was not dispatched for this narrow check. Static analysis: shellcheck on the 3 changed scripts clean. Suites on 035cb089: test_skill_paths.sh 160/0, test_dispatch_phase.sh 233/0, test_checkpoint_269.sh 43/0.

Round-2 findings, all closed:
- must-fix (a partial or failed Implementation closed a host-pass failure): closed; only a `**Status**: complete` `## Implementation` closes it, in address-findings step 2 and run-issue step 7, and a partial or failed one leaves it open for the retry; pinned.
- owner's `address` quotes the failure: closed in run-issue step 7; pinned.
- "in a row" counting: closed; judged by the previous full-pass result in run-issue step 7 and the orchestrator clause, and a full-pass `address` does not count toward the two at `rounds`; pinned.
- indirect reach: closed; the same sentence in the dispatcher text, run-issue step 4 and address-findings step 4; pinned in both test files.

Nothing new opened. Note, below the finding threshold: a passing full pass is not recorded, so in an issue delivered in several pull requests (or after a restart) the newest recorded result can be an earlier pull request's failure, and a first failure would go to the owner instead of being answered by the host. That only asks him one extra question; bounding the look-back at the pull request's start (pr_start.py round_start) would remove it.

### Findings
- [ ] No issues found. LGTM.

## Checkpoint
**Status**: complete
**When**: 2026-11-16 13:21 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3, a narrow convergence check, is approved with no must-fix and no suggestions; rounds 1 and 2 each had one must-fix, both fixed and pinned by tests; Gemini and Codex ran in rounds 1 and 2; the host's one full pre-commit pass ran after the approval on f0f9f6ca, the reviewed head, every hook and every suite with no SKIP: exit 0 in 227 s)
**After**: publish
**Decision**: publish

Publish the branch as a pull request and wait for the review sources, then triage. The merge is the owner's.

## Integrated Review
**Status**: complete
**When**: 2026-11-16 13:25 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #490 at `30a4939`
**Sources**: 4 (Local Review (Pre-Push) round 1 @ `ecc3ca00` and round 2 @ `fd40b9c4`, both stale and closed by later fix passes; Local Review (Pre-Push) round 3 @ `035cb089` (covers 30a4939 via bookkeeping: only progress.md changed since); CI rollup). Copilot absent: no review, no review request, no check-run on the PR (not a pass). No human reviews, no inline or conversation comments.
**Cross-source confirmations**: 0
**CI**: pending

Rounds 1 and 2 each had one must-fix and three suggestions; all eight are ticked and closed (Implementation entries at 6414f4ff and 82ead841, confirmed closed by round 3), and `review_progress.sh sources` returns no open local finding and no dropped entry at this head. Gemini (agy) and Codex ran in rounds 1 and 2; round 3 was a narrow convergence check without them. CI at 13:24: Validate Documentation, Validate Adapter Contract and ros-manifest tests pass in both workflow runs; Lint (pre-commit) still pending in both. The host's one full pre-commit pass (no SKIP) ran on f0f9f6ca, exit 0.

### Findings
- [ ] (suggestion, Local Review (Pre-Push) round 3 @ `035cb089`, note below its threshold; already in the PR's Known limits) "In a row" reads back to the newest recorded full-pass failure with no bound, and a passing pass leaves no record, so on an issue delivered in several pull requests (this one is "Part of #465") or after a restart an earlier failure counts as "previous" and a first failure goes to the owner instead of the host. Errs toward asking, not toward a silent pass, but it costs him a question the rule meant the host to answer. Five-minute fix: a `publish` decision at `checkpoint:publish` is only reached after a pass that passed (step 7, lines 751-759, 785-787), so say in step 7's "It fails again" bullet and the orchestrator clause that a failure followed by a `## Checkpoint` with `**Decision**: publish` is not the previous result (the push ended that run), and pin it in test_skill_paths.sh — `.claude/skills/run-issue/SKILL.md`, `.claude/skills/orchestrator/SKILL.md`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-16 13:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (one open suggestion, valid, with a five-minute text fix the triage spells out; fixing it now costs one fix pass and a re-check in the background, leaving it costs the owner a question the rule meant the host to answer)
**After**: findings
**Decision**: address

Address the open finding: a failure followed by a `## Checkpoint` with `**Decision**: publish` is not "the previous full-pass result" (run-issue step 7 "It fails again", the orchestrator clause, a pin in test_skill_paths.sh).
