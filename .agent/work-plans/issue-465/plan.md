# Plan: Run the script test suites when a chunk of work is done, not on every commit

## Issue

https://github.com/rolker/agent_workspace/issues/465

## Context

Job 1 of the issue (the Issue Review at 26e4f013, host Checkpoint after it):
write down the owner's 2026-11-13 rule ("yes, do the third option on both
machines", "yes, one local run before a pr") where the loop reads it, plus
one host addition (record-only pushes). Job 2 (suites off the commit hook,
AGENTS.md wording) is a later pull request; this one says "Part of #465", not
"Closes".

The rule: (1) dispatched implement and address-findings passes keep
`SKIP=validate-script-tests` on every commit, the progress entry included,
never `--no-verify`; (2) they run no full `pre-commit run --files` pass, only
the suites their change touches, and say so in the entry; (3) the host runs
the full pass once per pull request, after the pre-push review approves and
before the push, no SKIP; a failure goes back as findings (publish checkpoint
answered `address`), never fixed by the host; (4) after publish, fix passes
run touched suites only, CI on each push is the check, confirmed before the
merge checkpoint.

## Approach

Implement in this order (one atomic commit each, all with
`SKIP=validate-script-tests`, never `--no-verify`):

1. **Dispatcher text** — `.agent/scripts/dispatch_phase.sh`: replace the
   `pass_rule` string (about line 618) with the new rule: SKIP on every
   commit including the entry; no `--no-verify`; no full `pre-commit run`
   pass; run the suites the change touches, found by
   `.agent/scripts/tests/suites_for_files.sh -- $(git diff --name-only origin/main...HEAD)`
   (prints `ALL` or one suite basename per line; run each with
   `bash .agent/scripts/tests/<suite>`, `ALL` means `run_script_tests.sh`),
   and name them in the entry; the host runs the full pass before the push.
   Drop `root_q` if unused. Update the header comment (lines 79-84) and the
   comment at 605-607 and the test-context comments they feed.
2. **Tests that pin it** — `test_dispatch_phase.sh` (about 942-1002, 1122-1129):
   drop the pins on `$SB/.venv/bin/pre-commit run --files`, `600000 ms ...
   wait for its exit`, "about 2 minutes", "sub-issue worktree it also covers",
   and the spaced-root block (the printed path is gone). New pins: SKIP on
   every commit incl. the entry; `--no-verify` forbidden; "the suites your
   change touches" and "say so in your entry"; the `suites_for_files.sh`
   command; and `pre-commit run --files` absent from the agent's text. The
   review-phase and project-handoff negatives stay. Commit 1 and 2 may be one
   commit if the suite must pass between them.
3. **run-issue skill** — `.claude/skills/run-issue/SKILL.md`: rewrite the
   "Hook rule" paragraph (about 466-485) to the new rule, owner's words
   quoted; step 7 Publish (about 743): before `git push`, after the pre-push
   review approves, the host runs the main checkout's
   `.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`
   with no SKIP, timeout 600000 ms (about 4 minutes at 4 jobs, 240 s on
   2026-11-13, against 14 to 18 minutes at one job, 824 to 1069 s); a failure
   goes back through address-findings as findings (checkpoint `publish` answer
   `address`), never fixed by the host; step 9 (CI re-check) and step 10 say
   that after publish a fix pass's push is checked by CI, awaited before the
   merge checkpoint.
4. **Push records once** (same paragraphs; see Open Questions for the
   finding) — step 10 "The host owns every push" and the lines in steps 7,
   9 and 11 that tell the host to push: a commit that changes code is pushed
   when made (before the next `review-code <M>` or `triage-reviews`); record-only
   commits (review, triage, checkpoint entries, deferred-box ticks) are not
   pushed after each phase; they ride on the next code push, and the host
   pushes once, with `git status`/`git rev-list origin/<branch>..HEAD`
   checked clean afterwards, immediately before `merge_pr.sh`. Never run
   `merge_pr.sh` with a record commit or an uncommitted `progress.md` edit
   outstanding (issue #462).
5. **address-findings skill** — `.claude/skills/address-findings/SKILL.md`:
   step 3 "Dispatched pass" paragraph (about 150-157) and step 4 (about
   175-204): SKIP on every commit; step 4 becomes "run the suites your change
   touches (the `suites_for_files.sh` command), say so in the entry"; the full
   pass is the host's; replace "about 2 minutes ... about 7". A hand-run
   session and a project pass are unchanged.
6. **Host standing rule** — `.agent/knowledge/host_standing_rules.md`: one new
   row: the host runs the full pre-commit pass once per pull request, after
   the pre-push review approves and before the push, no SKIP, failure goes
   back as findings; reason cell holds his two quotes; and a second row only
   if the record-push rule needs one (host-decided; put it in the same row's
   rule cell otherwise).
7. **New pins** — `test_skill_paths.sh`: `has` pins for the run-issue step 7
   sentence, the rewritten Hook-rule paragraph, the step 10 record-only rule,
   the address-findings step 4 sentence, and the new standing-rules row (the
   empty-reason check already covers the cell).
8. **Stale comments, last commit** — `.agent/scripts/tests/run_script_tests.sh`
   header (lines 150-155) and the comment above the hook in
   `.pre-commit-config.yaml` (lines 85-89): point at the new rule. This
   triggers a full suite run on the commit; do it last, once, with the SKIP
   env still set, then the host's full pass covers it.
9. **Verify** — grep for any leftover "about 7", "2 minutes", "intermediate
   commits only", "once ... before its progress entry"; confirm `docs/design.md`,
   `AGENTS.md`, `CLAUDE.md`, `merge_pr.sh`, `.github/workflows` are untouched
   (`git diff --stat origin/main...HEAD`).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/dispatch_phase.sh` | `pass_rule` text and two comment blocks |
| `.agent/scripts/tests/test_dispatch_phase.sh` | replace pins on old text, add new pins |
| `.claude/skills/run-issue/SKILL.md` | Hook rule paragraph, step 7, 9, 10 (and 6, 11 push wording) |
| `.claude/skills/address-findings/SKILL.md` | steps 3 and 4, timing text |
| `.agent/knowledge/host_standing_rules.md` | one new row |
| `.agent/scripts/tests/test_skill_paths.sh` | new `has` pins |
| `.agent/scripts/tests/run_script_tests.sh`, `.pre-commit-config.yaml` | comments only, last commit |

## Prior Art

The rule and its tooling exist: issue #399 (once-per-pass rule), #410
(`suites_for_files.sh` maps changed files to suites; its interface is
`suites_for_files.sh [--deleted <p>]... -- <file>...`, prints `ALL` or suite
basenames, `ALL` on any internal error), #444 (parallel runs). The plan reuses
`suites_for_files.sh` rather than naming suites in the handoff: exact beats
judgment, and the suite list drifts when suites are added. Rejected: naming
the suites in `conventions=` (a fixed list goes stale and cannot follow the
diff). Nothing new is being built.

## Serves

Reviews that catch the real problems, cheaply (the loop's wall-clock cost):
`docs/design.md#rules`.

## Design Picture

No change to the design picture. `docs/design.md` states no sentence about
when the suites run (grep for `SKIP`, `pre-commit` found only rules-table and
verb rows), so it stays untouched.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Removes the agent's long full-pass run and its handoff text; adds one host step |
| Enforcement over documentation | Pins keep the text from drifting; the enforcing move (suites off the hook) is job 2 |
| Verify before claiming | Timings are the 2026-11-13 measurements, no more precision |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0005 | Yes | CI per push is the check after publish; local full pass is the pre-push mirror |
| ADR-0013 | Yes | Implementation entry names the suites it ran |
| ADR-0017 | No | No design sentence changes |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| dispatcher `pass_rule` | tests that pin it, run-issue and address-findings text | Yes |
| step 10 push rule | steps 6, 7, 9, 11 wording; step 10 second paragraph | Yes |
| runner header / hook comment | triggers all suites on that commit | Yes, last commit |
| AGENTS.md "Run pre-commit hooks before committing" | job 2 | No, follow-up |

## Open Questions

None needing the owner. Finding on "push records once": correct as a text
change, with one required condition. Reads: `fetch_pr_reviews.sh` and the
pull-request-mode `review-code` read GitHub's head (`headRefOid`), and
`review_progress.sh sources --head <that sha>` reads the local `progress.md`
with local ancestry checks, so unpushed record commits on top of the pushed
head are invisible to GitHub readers but harmless: entries correlate to the
pushed head. `git pull --ff-only` in triage step 2 is a no-op when ahead.
The workspace merge gate reads the worktree's working-copy `progress.md`, and
the worktree is removed at merge, so records not pushed before
`merge_pr.sh` never reach main: the single push must come before
`merge_pr.sh`. `merge_pr.sh` then treats the new head as bookkeeping
(`_only_bookkeeping_between`, `MERGE_PR_CI_BOOKKEEPING_PATTERNS` = work plans
and roadmap) and targets CI on the reviewed head, so the final push adds no
CI wait. Interaction with #462: that bug publishes unpushed commits when a
recording run (`--report-only`, `--force-unreviewed`) pushes; the rule makes
the worktree equal origin before every `merge_pr.sh` run, the clean state #462
needs, so it does not worsen it, but the host must check
`git rev-list origin/<branch>..HEAD` is empty and `git status` clean first.
Residual cost: unpushed records are local-only until then (a lost worktree
loses them); stated in the text.

## Estimated Scope

Single PR, "Part of #465". The implement pass runs the touched suites only:
`test_dispatch_phase.sh` and `test_skill_paths.sh` (plus whatever
`suites_for_files.sh` prints for its diff); stop when both pass, the grep in
step 9 is clean and the untouched-file check holds. Commit 8 makes the host's
full pass a full run, about 4 minutes.
