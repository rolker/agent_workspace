# Plan: sit-rep: when I ask "what's next?", say what to work on towards the goals, where in-progress work stands, and what problems I should know about

## Issue

https://github.com/rolker/agent_workspace/issues/395

Revision of 2026-10-15. The issue was restated at goal level that day (checkpoint decision: restart). This plan replaces the one for the 2026-10-14 scope (composed orientation slots), which is history in the issue body and the timeline.

## Context

The owner wants three things when he asks "what's next?": what to work on next towards the goals, where in-progress work stands, and problems he should know about (stale documentation, research or an audit due, judged by work done since). It must be easy to digest. Today's `/sitrep` (`.claude/skills/sitrep/SKILL.md`) gives the first two from checked facts but opens with line counts and an inbox sort, and has nothing for the third. Also, its "Suggested next" rule picks "the first false Direction line", which today is the last link of the chain (the run from the project root that waits on everything before it), not the work that advances the chain.

Where the report needs something not written down (a cadence), the issue says ask once and keep the answer. v1 needs none: it prints days and work since, with a judgment.

## Approach

All changes are in the skill's text and commands; the check runner gains nothing.

1. **Revert `f293a4bb`** (the old-scope implementation: `sitrep_checks.sh` step and proof rows, per-line results, path modes, and their additions to `test_sitrep_checks.sh`). This is the first implementation commit, made with `git revert`; the commit stays in history. Run `test_sitrep_checks.sh` after to confirm the runner is back to its prior state.
2. **Reorder the report in SKILL.md step 5** to: (a) one direction sentence; (b) Suggested next; (c) In flight; (d) Problems; (e) then Acceptance-case counts, Inbox and Deferrals. The top (a to d) targets about 15 lines. The direction sentence is built from the Direction section's acceptance-case paragraph, first sentence, printed as written, plus the count of lines true. The inbox is one line (count, new since last run) with the five-bin sort only on `/sitrep inbox`.
3. **New "Suggested next" rule**: the first unmet Direction line in roadmap order (result not `true`), plus the in-flight branch whose issue that line, or its prose in the roadmap, names (matched by the `(#N)` or `gh-issue N` in the line's cell, or a `#N` in the Direction prose; a worktree branch `feature/issue-N` or pull request closing `#N`). If no in-flight branch matches, say "nothing in flight advances it" and name the line. Fall back to the previous order (due deferral, then in-flight, then inbox "now") only when no Direction line is unmet. A `format` problem or an `unknown`/`unchecked` line is still not a source, but an `unknown` line is listed under Problems since the check could not run.
4. **Add step "Read problems"**, read-only commands run once per sit-rep, each printing facts then one judgment word ("probably due", "recent", "cannot tell"):
   - Audit: newest `yes <date>` in design.md's Decision register Re-examined column (grep/sort), days since, and `git rev-list --count --since=<date> HEAD` on main (commits since). Named source: the Decision register, since `/audit-workspace` keeps no run log.
   - Research: the `Last full refresh:` date in `.agent/knowledge/research_digest.md` line 3, days since, commits since.
   - Documentation: `check_design_anchors.sh` result; days since `docs/design.md` last changed and the count of commits since that touched `.agent/`, `.claude/` or `docs/` (git log only), i.e. work that may have outrun the design.
   - Direction `format` rows and `unknown` lines.
   - In a project session the Problems section is the workspace's only, and says so; nothing is read from the project.
5. **Start a due read-only check in the background**: when the audit or research check says "probably due" (judgment, no stored threshold), the report STARTS it through the Agent tool with `run_in_background` and says so in the Problems line ("started /audit-workspace in the background, 41 commits since 2026-10-12; result comes back as a note"). The started agent reads and reports only; it does not edit tracked files. For research, the background agent surveys and returns proposed digest changes; applying them to the digest (a write) is offered, not done. Anything that writes to a repo or GitHub (digest edits, the register-table pull request the audit proposes, opening issues) is offered as a one-line yes/no. One check is not started twice in a session (the report says "already started this session"). The design-anchor check is cheap and runs inline.
6. **Run record**: unchanged. "Since last time" is the existing counts comparison, one clause.
7. **Update SKILL.md frontmatter description, the Rules, and the "Reads only" claim** to say it may start a read-only background check. Update `docs/design.md` Documentation layers Direction row (one sentence: the sit-rep also reports problems from the Decision register, the digest header and the anchor check, and may start due read-only checks), plus a change-log row (ADR-0017, same change).
8. **Acceptance**: after merge, run `/sitrep` for real. Confirm the Problems section prints the three facts (audit, research, documentation) from commands, the top is within about 15 lines, "Suggested next" names a line plus a branch with titles, and the owner can name his next step from the first screen. Look again after a week of use (record in the issue).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/sitrep_checks.sh`, `.agent/scripts/tests/test_sitrep_checks.sh` | Reverted to before `f293a4bb` (first commit) |
| `.claude/skills/sitrep/SKILL.md` | New report order, new Suggested-next rule, new Problems step, background-start rule, description and Rules |
| `docs/design.md` | Direction row sentence in Documentation layers; change-log row |

## Prior Art

Nothing new is built. Looked at: the audit's own Re-examined column (the only record of an audit date), the research skill's `Last full refresh` header (written for exactly this), `check_design_anchors.sh` (existing, used as is), the skill's step 3 pattern for read-only `gh`/git facts (copied). Rejected: a stored cadence or run log for audits (a new file and a mechanism choice the owner did not ask for); new runner check kinds (the runner reads the roadmap, these facts are elsewhere).

## Serves

Easy to use ("Work is easy to come back to") and The long view ("Know whether it works"); `docs/design.md#documentation-layers`.

## Design Picture

Small change: the Direction row of `docs/design.md#documentation-layers` gains one sentence and the change log a row, in this PR. No new file, so the seven-role mapping is unchanged.

## Principles Self-Check

| Principle | What it cuts or changes in this plan |
|---|---|
| Only what's needed | Cuts the old scope entirely: orientation slots, runner modes, run-record per-line field, roadmap Item rewrites, path/regressed grouping (the revert). Smallest change for the three wants: reorder the report, change one rule, add one Problems step of read-only commands. No code outside the skill. |
| Give the user what they need now | Changes the order: direction, next, in flight, problems first (about 15 lines); counts, inbox sort and deferrals move below or behind `/sitrep inbox`. Cuts the inbox sort from the default output. |
| Verify before claiming | Changes how "due" is said: every problem prints its dates and commit counts from a command run this invocation, then a judgment word; no bare "due", no remembered dates. "Cannot tell" when a date is missing. |
| Ask about what matters, and show how much | Cuts the cadence question: none asked, no threshold stored; a veto becomes a standing rule. Owner questions only if a goal is unclear. |
| Know whether it works | Cuts a parser unit-test as the proof; the test is a real `/sitrep` after merge plus a look after a week. Runner tests only to confirm the revert. |
| A change includes its consequences | Adds to the plan: description line, Rules, "Reads only" wording, design.md row and change log; removal of the old tests (revert). |
| Leave in a project only what it chose to carry | Changes: in a project session Problems reads only the workspace and says so; nothing is written to the project, and the background check runs against the workspace. |
| Enforce what matters, as simply as possible | Cuts new check kinds in the runner; the facts are read by commands in the skill, as step 3 does for pull requests. |

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
| Skill may start background agents | Nothing else reads the skill's "writes one line" claim except the description | Yes (description) |

## Open Questions

None for the owner. No goal is unclear, no two goals are in tension, nothing outward-facing or hard to undo happens.

## Decisions made (owner may veto)

- No stored cadence or threshold; the report gives days and commits since and a judgment. A veto becomes a standing rule.
- Last audit date comes from the newest `Re-examined` date in the Decision register (named in the report).
- Per the owner's words, a due read-only check (audit, research survey) is started in the background and the report says so; anything that writes (digest edits, register pull request, issues) is only offered. The research background run proposes digest changes instead of editing the digest.
- "Suggested next" is the first unmet Direction line in roadmap order plus the in-flight branch its issue names; no matching branch is stated, not papered over.
- Inbox sort appears only on `/sitrep inbox`; the default shows count and new lines.
- Documentation staleness is measured as anchor-check result plus days and commits since `docs/design.md` last changed; no new file.
- Old per-line "since last time", path grouping and roadmap cell rewrites are dropped.

## Estimated Scope

Single PR: one skill file, one design.md row, plus the revert.
