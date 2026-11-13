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
