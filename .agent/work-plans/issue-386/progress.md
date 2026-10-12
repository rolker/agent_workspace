---
issue: 386
---

# Issue #386 — Direction section in the roadmap, a one-line inbox, and a sit-rep skill that answers what's next from checked facts

## Issue Review
**Status**: complete
**When**: 2026-10-12 18:10 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #386

### Scope Assessment

**Well-scoped?** Yes, if the sit-rep's first cut is trimmed — five items fit one PR only when the sit-rep reads facts that exist today. As written it also promises "sweep due?" (no health report and no sweep skill exist), a tooling-versus-project share and resume cards (the issue itself puts the cards out of scope), each of which is its own small design. See the recommendations.
**Right repo?** Yes — `docs/roadmap.md`, `docs/design.md`, a workspace script and a workspace skill. The gz4d lines are workspace facts only while they stay about the workspace's own acceptance case (see recommendations).
**Serves**: Easy to use ("Work is easy to come back to") and The long view ("Each project says what healthy and the right direction mean", "It is known whether a change helped") — `docs/design.md#documentation-layers`. The issue's second anchor, `docs/design.md#review-loop-and-timeline`, fits only if the sit-rep reads `progress.md`; its read list does not (worktrees, PRs, roadmap, inbox). `docs/design.md#registry-and-adapters` fits better: the inbox maps the cwd to a registered project and its setting sits beside the registry.
**Design picture?** Changes Documentation layers (Direction row, Measures row, the "two of the seven are gaps" paragraph, the Target, OQ-3). The issue records the owner's decision (roadmap section, measured status kept local) and names the update, so no re-ask. Not covered by the issue: where the machine-local setting lives (first Action row).
**Dependencies**: none blocking. #332 (onboarding asks the footprint question) is only the reason the gz4d lines are marked pending. Overlaps to keep apart: `what-next` (below) and #321 (host protocol: orientation, parked-items ledger), which also wants "where was I" cards.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | Action needed | The one rule ("never states a status it did not check this run") is behaviour of an agent reading prose, so it is not testable as written. Make it mechanical: give Direction lines a fixed check grammar and put the running of checks in a script (for example `sitrep_checks.sh`) that prints one row per line: line, result, check, date. The skill only formats those rows. Tests then cover: a line with no check prints `unchecked`; a check that cannot run prints `unknown`, never `false`; `true`/`false` come only from the check's exit status; no output row lacks its check field. Without this, item 5's "parsing of the Direction section" has nothing sharp to test. |
| Enforce what matters, as simply as possible | Action needed | Running "a command" named in a committed roadmap means a project's roadmap can make the sit-rep execute arbitrary text. Limit check kinds to read-only ones (a file exists or contains a string; an issue's state through `gh`; a named read-only workspace script such as `adapter --project <name> validate`) and treat anything else as `unchecked`. State the kinds in the Direction section's own header so the grammar and the allowed set are in one place. |
| Keep one current design | Action needed | The inbox path "is a machine-local setting beside the project registry", but nothing there takes a setting: `.agent/projects.local` is parsed strictly as one project per line (a setting line is a parse error), `.agent/projects.d/<name>.sh` is per project, and `.agent/project_config.sh` holds build commands. The run record needs the same kind of home. Say in the issue where it goes. Proposal: one new gitignored key=value file, read without sourcing it, holding the inbox path and the run-record path, with an environment override for tests; add it to `.gitignore` and an `.example`, and one sentence in `docs/design.md#registry-and-adapters`. No default path is invented: `capture.sh` with no setting fails with how to set it. |
| Leave in a project only what it chose to carry | OK | Nothing is written to a project; gz4d lines are marked pending the footprint choice. See the gz4d recommendation for the one way this could slip. |
| Put each thing at the level it applies to | OK | Authored direction in the tracked roadmap; measurements and inbox machine-local. Matches the decided split. |
| Only what's needed | Watch | Trim as in the first recommendation. "Inbox: one line, three automatic fields" and the one-rule sit-rep are the right size. |
| Give the user what they need now | OK | One screen, at most one question. |
| Know whether it works | OK | The run record is the first concrete Measures form; the design change-log row should say it is a first form (OQ-3 only partly answered), as the issue does. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0017 (design document is the current picture) | Yes | Item 4 covers it; add the exact rows listed under Consequences. |
| ADR-0016 (session roots and the user tier) | Yes | "Any terminal or agent can call" `capture.sh` means promoting it in `.agent/user_tier_scripts.txt`, where an entry must be inert outside registered roots (`registry_require_root`). That refuses a cwd with no registry match, which contradicts the `none` mapping; decide inert-marker (it appends outside every repo) or guarded, and test it (`test_user_tier_guard.sh`). The skill needs `session_scope: both` and the `$WS_ROOT` path idiom (`test_skill_paths.sh` enforces it). |
| ADR-0011 (adapter contract) | Watch | The cwd-to-project mapping should call `registry_resolve_from_dir`, not re-implement the longest-match rule, and must not branch on project type. |
| ADR-0013 (progress.md vocabulary) | No | The run record is not a timeline entry. |

### Consequences

- `docs/design.md`: Documentation layers table (Direction and Measures rows), the paragraph "Two of the seven are gaps", the Target, OQ-3 (partly answered), a Registry and adapters sentence for the setting, and a change-log row with the new line count.
- `docs/roadmap.md`: a row for this issue; scenario 4 "Monday morning bootstrap" is what the sit-rep delivers, so link it.
- `.claude/skills/what-next/SKILL.md` parses every roadmap section except Decided Against and To Consider; the Direction section must join the skip list.
- `.agent/scripts/update_roadmap.sh` treats any table row whose second cell is exactly `#N` as an issue row and overwrites the third cell with `done` when #N completes. A Direction line whose check cell is just an issue reference would be rewritten at merge. Add a Direction fixture to `test_update_roadmap.sh`, or write issue checks so the cell is never a bare `#N`.
- `.gitignore`, `.agent/user_tier_scripts.txt` and the user-tier tests, per above.
- The Script Reference table in `AGENTS.md` would gain a `capture.sh` row, but `AGENTS.md` is Ask First; ask the owner or leave the row out (the skill and the script header document it).

### Recommendations
- Trim the sit-rep's first cut to what has a source today: acceptance lines with their checks, the inbox, in-flight work (`worktree_list.sh --json` and open PRs, with last commit or PR state in place of resume cards), and deferrals whose revisit condition holds. Leave out "sweep due?" (nothing to sweep with, and 20 merges or 14 days is a guess), the tooling-versus-project share and resume cards; each becomes a one-line follow-up issue. Seven output sections become four.
- Order the work so it can split: first the setting, `capture.sh` and its tests; then the Direction section, check runner, skill and design edit. One PR, but if review runs past one round on either half, split there.
- `capture.sh` details to fix in the issue and test: it never loses a thought (a registry parse error or no match still appends, with project `unknown`); the line is one line (tabs and newlines in the text collapse); the current issue comes from `WORKTREE_ISSUE` if set, else from a `feature/issue-N` branch name, because a Claude Code Bash call does not keep exported variables between calls; appends use a single write so two terminals do not interleave.
- Keep the gz4d lines to the workspace's own acceptance case for ADR-0016 (design OQ-2), with gz4d named as the run's target as `docs/roadmap.md` already does in the Workspace Redesign row. Facts that belong to the project (its conventions file, its untracked skill, its issue tracker) wait for its own Direction after the footprint question, since `docs/principles.md` asks that a project carry only what it chose. Checks stay ones the workspace can run from the registry.
- `what-next` overlap: today it ranks roadmap rows by issue state; the sit-rep answers the same question from checked facts, so the owner will have two skills for "what's next". Do not retire it here, but add a one-line pointer in `what-next` and open the fold-or-retire follow-up now, with the decision it needs, instead of leaving it as "later" in the out-of-scope list.
- Replace the second Serves anchor as above, or say what in `progress.md` the sit-rep reads.

### Actions
- [ ] The one rule ("never states a status it did not check this run") is behaviour of an agent reading prose, so it is not testable as written. Make it mechanical: give Direction lines a fixed check grammar and put the running of checks in a script (for example `sitrep_checks.sh`) that prints one row per line: line, result, check, date. The skill only formats those rows. Tests then cover: a line with no check prints `unchecked`; a check that cannot run prints `unknown`, never `false`; `true`/`false` come only from the check's exit status; no output row lacks its check field. Without this, item 5's "parsing of the Direction section" has nothing sharp to test.
- [ ] Running "a command" named in a committed roadmap means a project's roadmap can make the sit-rep execute arbitrary text. Limit check kinds to read-only ones (a file exists or contains a string; an issue's state through `gh`; a named read-only workspace script such as `adapter --project <name> validate`) and treat anything else as `unchecked`. State the kinds in the Direction section's own header so the grammar and the allowed set are in one place.
- [ ] The inbox path "is a machine-local setting beside the project registry", but nothing there takes a setting: `.agent/projects.local` is parsed strictly as one project per line (a setting line is a parse error), `.agent/projects.d/<name>.sh` is per project, and `.agent/project_config.sh` holds build commands. The run record needs the same kind of home. Say in the issue where it goes. Proposal: one new gitignored key=value file, read without sourcing it, holding the inbox path and the run-record path, with an environment override for tests; add it to `.gitignore` and an `.example`, and one sentence in `docs/design.md#registry-and-adapters`. No default path is invented: `capture.sh` with no setting fails with how to set it.
- [ ] Trim the sit-rep's first cut to what has a source today: acceptance lines with their checks, the inbox, in-flight work (`worktree_list.sh --json` and open PRs, with last commit or PR state in place of resume cards), and deferrals whose revisit condition holds. Leave out "sweep due?" (nothing to sweep with, and 20 merges or 14 days is a guess), the tooling-versus-project share and resume cards; each becomes a one-line follow-up issue. Seven output sections become four.
- [ ] Order the work so it can split: first the setting, `capture.sh` and its tests; then the Direction section, check runner, skill and design edit. One PR, but if review runs past one round on either half, split there.
- [ ] `capture.sh` details to fix in the issue and test: it never loses a thought (a registry parse error or no match still appends, with project `unknown`); the line is one line (tabs and newlines in the text collapse); the current issue comes from `WORKTREE_ISSUE` if set, else from a `feature/issue-N` branch name, because a Claude Code Bash call does not keep exported variables between calls; appends use a single write so two terminals do not interleave.
- [ ] Keep the gz4d lines to the workspace's own acceptance case for ADR-0016 (design OQ-2), with gz4d named as the run's target as `docs/roadmap.md` already does in the Workspace Redesign row. Facts that belong to the project (its conventions file, its untracked skill, its issue tracker) wait for its own Direction after the footprint question, since `docs/principles.md` asks that a project carry only what it chose. Checks stay ones the workspace can run from the registry.
- [ ] `what-next` overlap: today it ranks roadmap rows by issue state; the sit-rep answers the same question from checked facts, so the owner will have two skills for "what's next". Do not retire it here, but add a one-line pointer in `what-next` and open the fold-or-retire follow-up now, with the decision it needs, instead of leaving it as "later" in the out-of-scope list.
- [ ] Replace the second Serves anchor as above, or say what in `progress.md` the sit-rep reads.

## Checkpoint
**Status**: complete
**When**: 2026-10-12 18:14 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Issue Review (2a4ccef) actions all accepted: A1 testable check rule (fixed check grammar; a script prints one row per line; skill formats only; tests for unchecked / unknown / exit-status), A2 read-only check kinds only, A3 one new git-ignored key=value settings file read without sourcing; capture fails with instructions when unset. Trim accepted: drop "sweep due?", tooling-vs-project share and resume cards from this PR, file each as a follow-up. Also: update_roadmap.sh fixture for Direction cells; what-next gets a pointer, fold-or-retire issue later; gz4d lines limited to the workspace's own acceptance case; second Serves anchor becomes #registry-and-adapters; the AGENTS.md script-table row stays out (Ask First, asked separately).

> yes, proceed with all three and the trim

## Plan Authored
**Status**: complete
**When**: 2026-10-12 18:16 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-386/plan.md` at `64c24a41`

Five commits in one PR, splittable after the first: the machine-local settings file and `capture.sh` with tests; then a read-only check runner (`sitrep_checks.sh`) with a fixed grammar, the Direction section in `docs/roadmap.md` with an `update_roadmap.sh` fixture, the `sitrep` skill (first mode) with a `what-next` pointer, and the `docs/design.md` update. Six trimmed items are listed as follow-ups.
