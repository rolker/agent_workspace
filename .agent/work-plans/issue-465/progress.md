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
