# Plan: sit-rep: when I ask "what's next?", say what to work on towards the goals, where in-progress work stands, and what problems I should know about

## Issue

https://github.com/rolker/agent_workspace/issues/395

Revision of 2026-10-15, revised again after Plan Review 92b16637. The issue was restated at goal level that day (checkpoint decision: restart). This plan replaces the one for the 2026-10-14 scope (composed orientation slots), which is history in the issue body and the timeline.

## Context

The owner wants three things when he asks "what's next?": what to work on next towards the goals, where in-progress work stands, and problems he should know about (stale documentation, research or an audit due, judged by work done since). It must be easy to digest. Today's `/sitrep` (`.claude/skills/sitrep/SKILL.md`) gives the first two from checked facts but opens with line counts and an inbox sort, and has nothing for the third. Also, its "Suggested next" rule picks "the first false Direction line", so an `unchecked` line (today the run from the project root) is skipped and it lands on the last link, the ADR promotion, which waits on everything before it. Neither is the work that advances the chain: the missing link is onboarding the acceptance project (issue 332, onboard-project registers and audits projects), which no Direction line names.

Where the report needs something not written down (a cadence), the issue says ask once and keep the answer. v1 needs none: it prints days and work since, with a judgment.

## Approach

All changes are in the skill's text and commands, plus one roadmap line; the check runner gains nothing.

1. **Revert `f293a4bb`** (the old-scope implementation: `sitrep_checks.sh` step and proof rows, per-line results, path modes, and their additions to `test_sitrep_checks.sh`). This is the first implementation commit, made with `git revert`; the commit stays in history. Run `test_sitrep_checks.sh` after to confirm the runner is back to its prior state.
2. **Roadmap: add one Direction line**, placed before the project-root run line: "The acceptance project is onboarded (#332)" with check `gh-issue 332 closed`. It is stage 2 of the owner's own three-stage test (register, onboard, run an issue), stated today; issue 332's body records onboarding as held before the acceptance run. The goal does not change, only the chain's wording. Then run `sitrep_checks.sh` to confirm the new row parses and reads `false` while 332 is open.
3. **Reorder the report in SKILL.md step 5** to: (a) one direction sentence; (b) Suggested next; (c) In flight; (d) Problems; (e) then Acceptance-case counts (with the acceptance-case paragraph), Inbox and Deferrals. The top (a to d) targets about 15 lines. The direction sentence is built from the Direction lines, not the acceptance paragraph: "<t> lines of <n> true; next: <first unmet line's text>". Every number has its label, so a line like "3 of 6 Direction lines true" never appears bare. The inbox is one line (count, new since last run) with the five-bin sort only on `/sitrep inbox`.
4. **New "Suggested next" rule**: unmet means any result other than `true`, in roadmap order; an `unchecked` line counts as unmet and is not skipped (this resolves the old contradiction), and an `unknown` first line reads "check could not run" and is not skipped either, since the chain is ordered. The result word is printed. The in-flight branch is matched only on the line's own cell: `(#N)` or `gh-issue N` there, then a worktree branch `feature/issue-N` or a pull request closing `#N`. No matching in the Direction prose (it would hit the Format paragraph's literal `(#N)` and the deferral rows). If no in-flight branch matches, say "nothing in flight advances it" and name the line. Fall back to the previous order (due deferral, then in-flight, then inbox "now") only when every Direction line is `true`. Any `#N` or ADR number printed from roadmap text carries its title (issue title as in step 6; ADR title from the ADR file's H1).
5. **Add step "Read problems"**, read-only commands run once per sit-rep, each printing facts then one judgment word ("probably due", "recent", "cannot tell"). Commit counts exclude work-plan commits and merge commits, always on `main` in `$WS_ROOT` (a worktree session's `.` is a feature branch):
   `git -C "$WS_ROOT" rev-list --count --no-merges <sha>..main -- . ':!.agent/work-plans'`
   where `<sha>` is the commit that set the date (found with `git -C "$WS_ROOT" log -1 --format=%H main -- <file>` or `--before=<date>` where the date comes from a table cell).
   - Audit: the newest `yes <date>` in design.md's Decision register Re-examined column, labelled "newest ADR re-examination (Decision register)", never "last audit" (that date comes from the design rewrite, not an audit run), with the count of ADRs still "not yet" (the column gives it free), days since, and commits since by the command above. Judgment is a word, no stored threshold.
   - Research: "probably due" applies the research skill's written rule (`.claude/skills/research/SKILL.md`, Staleness rules): an entry is stale when its `Last verified` (or `Added`) date is more than 30 days old, flagged for review past 90. The report prints the count of entries past 30 and past 90 days, parsed from the `**Last verified**:` dates in `.agent/knowledge/research_digest.md`, and the digest's `Last full refresh:` date (leading date only; the line carries a parenthetical). Any stale entry means due. Not a judgment call, so no cadence is asked.
   - Documentation: days since `docs/design.md` last changed and the count of commits since that touched `.agent/`, `.claude/` or `docs/`, by the command above with those pathspecs (work that may have outrun the design). `check_design_anchors.sh` is printed only when it fails (it passes in pre-commit and CI, so a pass says nothing).
   - Direction `format` rows and `unknown` lines.
   - In a project session the Problems section is the workspace's only, and says so; nothing is read from the project.
6. **In flight shows where the work stands**: for each worktree branch (`worktree_list.sh --json` gives `issue`): the issue title (git-bug first, then `gh`, as `_issue_helpers.sh` does) and the latest `progress.md` entry type and status, from `python3 .agent/scripts/progress_read.py <worktree>/.agent/work-plans/issue-N/progress.md` (last element of `entries`: `type`, `status`; checked here, it prints e.g. "Plan Review complete"), plus open pull request number, if any, with its title. Example: "onboard-project registers projects (issue 332): Implementation complete, no pull request yet". The latest commit subject is dropped from the line.
7. **Start a due read-only check in the background**: when the audit or research check says "probably due", and the Agent tool exists and the session is a workspace session, the report STARTS it through the Agent tool with `run_in_background` and says so in the Problems line. In a project session (these skills have no `session_scope`, so the plugin does not ship them there), or when the Agent tool is unavailable (Codex, agy), the check is offered with where to run it ("run /audit-workspace from the workspace"), not started. One check is not started twice in a session ("already started this session"). Prompts, spelled out:
   - **Audit**: "Run the /audit-workspace skill's checks and report findings only. Do not edit any file, create a worktree, commit, push, or open a pull request or issue. Return the findings and, separately, the Decision-register cell changes you would propose." (The skill's Report-don't-fix mode: it reads files and runs `worktree_list.sh`; its only write is a pull request it asks about afterwards, which this prompt forbids.)
   - **Research**: the `/research --refresh` skill writes (every mode creates a worktree, commits, pushes and opens a pull request), so the background run is not that skill. Prompt: "Do not run the /research skill. Read-only, no worktree, no commit, no push, no pull request, no issue, no file edit. Read .agent/knowledge/research_digest.md and find entries whose Last verified date is more than 30 days old. For each, in oldest-first order, do the web survey the research skill's --refresh steps 2 to 4 describe, and return, as text only, the proposed new or changed entry content and the new Last verified date. Do not write anything to disk." Applying the proposals (worktree, commit, pull request) is offered as a one-line yes/no.
   Anything that writes to a repo or GitHub is offered, never done.
8. **Run record**: unchanged. "Since last time" is the existing counts comparison, one clause.
9. **Update SKILL.md frontmatter description, the Rules, and the "Reads only" claim** to say it may start a read-only background check. Update `docs/design.md` Documentation layers: the Direction row (one sentence: the sit-rep also reports problems from the Decision register, the research digest's entry dates and the commit counts, and may start due read-only checks), the gap paragraph that says the Direction section says "not what healthy means" (one clause: the Problems section is a first form of health signals), plus a change-log row (ADR-0017, same change).
10. **Acceptance**: after merge, run `/sitrep` for real. Confirm: the top is within about 15 lines; the direction sentence reads, on today's roadmap, "<t> lines of 7 true; next: The acceptance project is onboarded (#332)" with 332's title beside the number; Suggested next names that line plus the `feature/issue-332` branch with its title and the latest progress entry type and status; the Problems section prints audit, research and documentation facts from commands, with commit counts that exclude work-plan and merge commits; and the owner can name his next step from the first screen. Look again after a week of use (record in the issue).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/sitrep_checks.sh`, `.agent/scripts/tests/test_sitrep_checks.sh` | Reverted to before `f293a4bb` (first commit) |
| `docs/roadmap.md` | One Direction line: the acceptance project is onboarded (#332), check `gh-issue 332 closed`, before the project-root run line |
| `.claude/skills/sitrep/SKILL.md` | New report order, direction sentence, Suggested-next rule, In flight lookups, Problems step, background-start rule and prompts, description and Rules |
| `docs/design.md` | Direction row sentence and gap-paragraph clause in Documentation layers; change-log row |

## Prior Art

Nothing new is built. Looked at: the audit's own Re-examined column (the only record of an audit date), the research skill's `Last full refresh` header (written for exactly this), `check_design_anchors.sh` (existing, used as is), the skill's step 3 pattern for read-only `gh`/git facts (copied). Rejected: a stored cadence or run log for audits (a new file and a mechanism choice the owner did not ask for); new runner check kinds (the runner reads the roadmap, these facts are elsewhere).

## Serves

Easy to use ("Work is easy to come back to") and The long view ("Know whether it works"); `docs/design.md#documentation-layers`.

## Design Picture

Small change: the Direction row of `docs/design.md#documentation-layers` gains one sentence and the change log a row, in this PR. No new file, so the seven-role mapping is unchanged.

## Principles Self-Check

| Principle | What it cuts or changes in this plan |
|---|---|
| Only what's needed | Cuts the old scope entirely: orientation slots, runner modes, run-record per-line field, roadmap Item rewrites, path/regressed grouping (the revert). Cuts the design-anchor check from the default output (prints only on failure) and the acceptance paragraph from the top. Smallest change for the three wants: reorder the report, change one rule, add one roadmap line and one Problems step of read-only commands. No code outside the skill. |
| Give the user what they need now | Changes the order: direction, next, in flight, problems first (about 15 lines); counts, inbox sort and deferrals move below or behind `/sitrep inbox`. Cuts the inbox sort from the default output, and every number carries its label (issue and ADR titles beside numbers printed from roadmap text). |
| Verify before claiming | Changes how "due" is said: every problem prints its dates and commit counts from a command run this invocation, then a judgment word; no bare "due", no remembered dates. Changes the audit label to "newest ADR re-examination" (not "last audit") and the commit count to exclude work-plan and merge commits. "Cannot tell" when a date is missing. |
| Ask about what matters, and show how much | Cuts the cadence question: research's cadence is already written (30 days), the audit's is a judgment word, nothing stored; a veto becomes a standing rule. Owner questions only if a goal is unclear. |
| Know whether it works | Cuts a parser unit-test as the proof; the test is a real `/sitrep` after merge plus a look after a week. Runner tests only to confirm the revert. |
| A change includes its consequences | Adds to the plan: description line, Rules, "Reads only" wording, design.md row and change log; removal of the old tests (revert). |
| Leave in a project only what it chose to carry | Changes: in a project session Problems reads only the workspace and says so; nothing is written to the project, and due checks are offered with where to run them, never started there. |
| Enforce what matters, as simply as possible | Cuts new check kinds in the runner; the facts are read by commands in the skill, as step 3 does for pull requests. The one new roadmap line uses an existing check kind (`gh-issue`). |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0017 design document is the current picture | Yes | Design.md row and change-log row in the same change |
| 0016 session roots | Watch | Every new command uses the `$WS_ROOT` idiom; no cross-root reads |
| 0013 progress.md vocabulary | No | The report is not a progress entry |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Report template | Skill description, Rules, "Reads only" claim | Yes |
| Sit-rep behaviour | design.md Direction row and change log | Yes |
| Revert `f293a4bb` | `test_sitrep_checks.sh` goes back with it | Yes |
| New Direction line | `sitrep_checks.sh` parses it (run to confirm); written like the existing `(#379)` line (issue number in prose as `(#N)`, check cell `gh-issue 332 closed`) | Yes (step 2) |
| Problems section is a first health signal | design.md gap paragraph ("not what healthy means") | Yes (step 9) |
| Skill may start background agents | Nothing else reads the skill's "writes one line" claim except the description | Yes (description) |

## Open Questions

None for the owner. No goal is unclear, no two goals are in tension, nothing outward-facing or hard to undo happens.

## Decisions made (owner may veto)

- Audit has no stored cadence or threshold; the report gives days and commits since (work-plan and merge commits excluded) and a judgment. Research "due" follows the research skill's written 30-day rule. A veto becomes a standing rule.
- The audit fact is the newest `Re-examined` date in the Decision register, labelled "newest ADR re-examination", not "last audit".
- A Direction line "The acceptance project is onboarded (#332)" is added to the roadmap before the project-root run line: stage 2 of the owner's own three-stage test, with `gh-issue 332 closed` as its check.
- The direction sentence is "<t> lines of <n> true; next: <first unmet line>", built from the Direction lines; the acceptance paragraph moves to the counts section.
- An `unchecked` or `unknown` Direction line counts as unmet and is the Suggested next; not skipped.
- The design-anchor check prints only on failure.
- In a project session, or when the Agent tool is unavailable, due checks are offered with where to run them, never started.
- Per the owner's words, a due read-only check (audit, research survey) is started in the background and the report says so; anything that writes (digest edits, register pull request, issues) is only offered. The research background run uses a read-only prompt (spelled out in step 7) that proposes digest changes and never creates a worktree, commits, pushes or opens a pull request.
- "Suggested next" is the first unmet Direction line in roadmap order plus the in-flight branch its issue names; no matching branch is stated, not papered over.
- Inbox sort appears only on `/sitrep inbox`; the default shows count and new lines.
- Documentation staleness is days and commits since `docs/design.md` last changed (anchor check only on failure); no new file.
- In flight lines show the issue title and the latest progress.md entry type and status, not the commit subject.
- Old per-line "since last time", path grouping and roadmap cell rewrites are dropped.

## Estimated Scope

Single PR: one skill file, one roadmap line, design.md edits, plus the revert.
