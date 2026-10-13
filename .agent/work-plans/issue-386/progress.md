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

## Plan Review
**Status**: complete
**When**: 2026-10-12 18:19 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #386 — Direction section in the roadmap, a one-line inbox, and a sit-rep skill that answers what's next from checked facts
**Plan**: `.agent/work-plans/issue-386/plan.md` at `64c24a41`
**Branch**: `feature/issue-386`

Needs-work means plan-text amendments only; nothing here rescopes the five commits or reopens an owner decision.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Five commits, split point after commit 1, trim applied. Two items could move to follow-ups to keep it to tonight (finding 8). |
| Issue alignment | Needs work | All Issue Review actions are carried. Gaps: deferrals' "revisit condition holds" is left to agent judgment (finding 3), and "what moved and what did not" from the issue's read-out is neither built nor listed as dropped (finding 6). Serves, as checked: "Goals "Easy to use" (work is easy to come back to) and "The long view" (day-to-day work stays connected to direction); `docs/design.md#documentation-layers`, `docs/design.md#registry-and-adapters`." Both goals are `README.md#workspace-goals` subsections; both anchors exist in `docs/design.md`. No rule broken: the one roadmap mention of gz4d is allowed (roadmap is in the history exception; `rolker/geozui4d` is public, checked with `gh repo view`). |
| File targeting | Good | Test paths are written `tests/...` in the Approach; the suite runner only picks up `.agent/scripts/tests/test_*.sh` (there is no root `tests/`). Spell the full path (finding 9). |
| Consequences | Needs work | `update_roadmap.sh` collision is covered for the Line/Check table only; the Deferrals part is not (finding 2, reproduced). |
| Principle alignment | Needs work | "Enforce what matters, as simply as possible": a name-only script allowlist is not read-only (finding 1). "Test what breaks": runner tests need the not-executed proofs below. |
| ADR compliance | Good | ADR-0016 (`session_scope: both`, `$WS_ROOT`), ADR-0017 (commit 5), ADR-0011 (registry helper, no type branching), ADR-0013 not triggered. ADR-0010 (git-bug-first issue reads) is triggered by `gh-issue` and not in the table (finding 4). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment] High** — The `script` allowlist is by name only, and two of the three named scripts are not read-only with other arguments. `user_tier_install.sh` with no arguments installs into `~/.claude` and `--uninstall` removes it (its header, "Modes"); `adapter --project <name> build|test|install|setup|sync` runs the project's commands. So a roadmap cell `script user_tier_install.sh --uninstall` or `script adapter --project x install` passes the plan's grammar. Also, scripts resolve under `$root/.agent/scripts/`; for a registered project root that is a file in the project's repo, i.e. project-controlled code. Fix: allowlist exact argument shapes (`adapter --project <registry-name> validate`, `user_tier_install.sh --check [--require]`, `check_design_anchors.sh` with no argument) and resolve scripts under the runner's own `$SCRIPT_DIR` only. Parse the cell with `read -ra` (or `set -f`) so a `*` is not globbed, and take `file-contains`'s string as the rest of the cell, run as `grep -qF -- "$s"`. Tests: a stub script that touches a marker file proves `script user_tier_install.sh`, `script adapter --project x build` and a project-root `.agent/scripts/adapter` are `unchecked` and never run.
2. **[Consequences] Medium** — Reproduced in a scratch fixture with the current `update_roadmap.sh --issue 379`: a Line/Check row with `gh-issue 379 closed` and a Line cell mentioning `(#379)` stay byte-identical (good); a bare `#379` check cell is matched and only warns "replacement did not take effect"; but a Deferrals table shaped `| Item | #379 | Revisit when |` has its revisit condition overwritten with `done`, and a deferral written `- [ ] ... (#379)` is checked off. The plan never fixes the Deferrals format. Fix: state it in the section header (for example `| Deferral | Revisit when | Check |`, issue numbers only inside prose or a `gh-issue` check, no checklist items) and extend the `test_update_roadmap.sh` fixture to a Deferrals row and a Deferrals checklist line.
3. **[Issue alignment] Medium** — "Deferrals whose revisit condition holds" has no checked source: a prose revisit condition is judged by the agent, which breaks the plan's own rule (states nothing it did not check; skill formats only). Fix: give each deferral a check cell in the same grammar and have `sitrep_checks.sh` print deferral rows too (a `kind` column: `line` / `deferral`); a deferral with no check is listed as `unchecked`, never as due. The same section-scoped parser must then pick tables by header, so add a test that a second table inside Direction is not read as Line rows. "Paused branches named in Deferrals" needs a column for the branch, or drop it (finding 8).
4. **[ADR compliance] Medium** — `gh-issue <N> <state> [owner/repo]` with the repo omitted resolves against the cwd's remote, so the workspace roadmap's `gh-issue 379 closed` asked from a project session queries the project's #379. Default the repo to the roadmap root's own remote (`git -C "$root" remote get-url origin`), and test it. Add ADR-0010 to the ADR table: either use `issue_lookup --repo` (git-bug first) or record why a direct `gh` read is chosen (a cached state is not "checked this run").
5. **[Issue alignment] Low** — `capture.sh` edge cases not stated: an inbox path that is relative (resolves against each caller's cwd, so lines scatter; reject it or resolve it against the workspace root), an inbox whose directory is missing or unwritable (exit non-zero and echo the text back so the thought is not lost), and CRLF/trailing space in `settings.local` (the registry tolerates CRLF). Also say that the settings file is read from the script's own checkout: run from a workspace worktree copy it sees no `settings.local` (gitignored, like `projects.local`), so the skill and docs should call the main checkout's copy through `$WS_ROOT`. The `unknown` path is sound: `registry_derive_type_from_dir` returns 2 on a parse error, 1 outside every root (`none`).
6. **[Issue alignment] Low** — The issue's read-out includes "what moved and what did not"; the four sections drop it without saying so, and a run record of "one dated line" holds nothing to compare against next time, which makes it a thin first form of Measures. Either write each root's `true of total` counts into the run-record line (then "what moved" is one diff, and the Measures row is honest), or add "what moved" to the follow-ups.
7. **[Principle alignment] Low** — Multi-check aggregation does not say what `unchecked` inside a ` ; ` cell does (`true ; unchecked`). Pick one (for example: any `unchecked` part makes the line `unchecked`) and test it.
8. **[Scope] Low** — Could be follow-ups to finish tonight: the per-registered-root loop (no registered root has a Direction section today, so it prints only "no direction record"; the first cut can read the workspace root and list the others in one line, which also avoids the skill needing a way to enumerate roots that the plan does not give it), and paused branches from Deferrals (in-flight already comes from `worktree_list.sh --json` and `gh pr list`).
9. **[File targeting] Low** — Write the new tests' paths in full (`.agent/scripts/tests/test_capture.sh`, `.agent/scripts/tests/test_sitrep_checks.sh`); create sandboxes with `mktemp -d` under `TMPDIR` (`run_script_tests.sh` fails a suite that names `/tmp` or leaves files behind).

Defaults checked (handoff item 5): `.agent/settings.local` is sound (matches `projects.local`, gitignored, `.example` beside it); `partial` only from multi-check lines is sound given finding 7; the allowlist is not sound as names only (finding 1). Inputs checked (item 4): `worktree_list.sh --json` and `gh pr list` exist and are real sources; Deferrals is a source only after findings 2 and 3; nothing in the plan reads memory notes. Project session (item 3): the skill reaches the scripts through `$WS_ROOT`; `sitrep_checks.sh` is not in `.agent/user_tier_scripts.txt`, so from a project session it prompts, the same as `review_progress.sh` does for the other `both` skills today; not a blocker.

### Summary

The structure, split point and trim are right, and the `update_roadmap.sh` collision for the Line/Check table is real and handled. Before implementation, the check grammar needs argument-level allowlisting and workspace-only script resolution to be read-only in fact, and the Deferrals part needs a fixed format with checks so it neither collides with `update_roadmap.sh` nor relies on agent judgment.

### Recommended Actions

- [ ] Allowlist `script` checks by exact argument shape (`adapter --project <registry-name> validate`, `user_tier_install.sh --check [--require]`, `check_design_anchors.sh`), resolve scripts under the runner's own directory only, parse with `read -ra` and `grep -qF --`, and add marker-file tests proving non-allowlisted forms never run.
- [ ] Fix the Deferrals format in the Direction header (table with a Check column, no bare `#N` second cell, no checklist items) and extend the `test_update_roadmap.sh` fixture to a Deferrals row and a checklist line.
- [ ] Have `sitrep_checks.sh` check deferrals with the same grammar and print them with a kind column; test that a second table in Direction is not read as Line rows.
- [ ] Default `gh-issue`'s repo to the roadmap root's remote, test it, and add ADR-0010 to the ADR table with the chosen read path.
- [ ] State `capture.sh` behaviour for a relative inbox path, a missing or unwritable inbox directory, and CRLF settings lines; note that settings are read from the main checkout via `$WS_ROOT`.
- [ ] Either record per-root `true of total` counts in the run record or list "what moved" as a follow-up.
- [ ] Define how `unchecked` combines in a multi-check cell.
- [ ] Consider moving the per-registered-root loop and paused branches to follow-ups.
- [ ] Write the new test paths in full under `.agent/scripts/tests/`.

## Checkpoint
**Status**: complete
**When**: 2026-10-12 18:27 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Plan Review (c103ef0) needs-work: F1 high (script allowlist checks name only; exact argument forms, run from the runner's own directory, no glob expansion, marker-file tests), F2 (Deferrals table format collides with update_roadmap.sh; fix format, fixture covers a Deferrals row and a checklist line), F3 (deferral revisit conditions get a check in the same grammar; runner prints deferral rows), F4 (gh-issue defaults to the roadmap root's remote; ADR-0010 row), F5-F9 low (capture edge cases incl. echo the text back on write failure; "what moved" as a follow-up or counts in the run record; unchecked in multi-check cells; F8 move the every-root loop and paused branches to follow-ups; test paths under .agent/scripts/tests/). Host recommendation: revise, then a second review, with F8's two items taken out for tonight.

> revise

## Plan Authored
**Status**: complete
**When**: 2026-10-12 18:29 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-386/plan.md` at `13eea944`

Revision 2, same five commits. The sit-rep check runner now accepts only three exact script forms run from its own directory, the Deferrals table has a fixed format with checks so `update_roadmap.sh` cannot hit it, `gh-issue` uses the roadmap root's own remote, and the run record keeps true-of-total counts so "what moved" is built. The every-root loop and paused branches moved to follow-ups.

## Plan Review
**Status**: complete
**When**: 2026-10-12 18:31 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #386 — Direction section in the roadmap, a one-line inbox, and a sit-rep skill that answers what's next from checked facts
**Plan**: `.agent/work-plans/issue-386/plan.md` at `13eea944`
**Branch**: `feature/issue-386`

Round 2. All nine round-1 findings (c103ef0) are resolved in the plan text. One new medium finding and three low ones remain; each is a few lines of implementation and a test, so they are carried into implementation rather than sent back for a third plan round.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | 12 files (7 new, 5 changed), three parts (capture, check runner, skill) plus docs; above the 10-file guide, but half are tests and docs. Fits one PR tonight; nothing further needs to move out. Keep the split after commit 1 as the fallback if review-code needs more than one round on both halves. |
| Issue alignment | Good | Trim, Issue Review actions and round-1 findings all carried. Serves, as checked: "Goals "Easy to use" (work is easy to come back to) and "The long view" (day-to-day work stays connected to direction); `docs/design.md#documentation-layers`, `docs/design.md#registry-and-adapters`." Both anchors exist; no rule broken. F6 built as `--summary` counts in the run record: sound and cheap; counts show net change only (one line going true and another going false shows as no change), which is acceptable for a first form of Measures. |
| File targeting | Good | Test paths in full under `.agent/scripts/tests/`; sandboxes via `mktemp -d` under `TMPDIR`. |
| Consequences | Good | `update_roadmap.sh` only matches a table row whose second cell is exactly `#N` (line 130) or any line with `#N` for the checklist form (line 161); the fixed `| Line | Check |` and `| Deferral | Revisit check |` formats keep both tables out of reach, and the fixture pins the checklist line as flipped. `what-next` skip list, design.md rows (existing Direction/Measures rows at lines 104-105, gaps paragraph line 107, OQ-3 line 620) all named. |
| Principle alignment | Good | F1 resolved: three exact argument vectors, resolved under the runner's own scripts dir, `read -ra` under `set -f`, `grep -qF --`, marker-file tests for every disallowed form and for a project-root `adapter`. Verified the three forms are read-only: `user_tier_install.sh --check [--require]` only reports (exit 0/1, 2 usage, 3 no jq); `check_design_anchors.sh` with no argument checks its own repo (exit 0/1, 2 error); `adapter_validate` in both types only inspects the checkout. See finding 1 for exit-1 meaning. |
| ADR compliance | Good | ADR-0016, 0017, 0011 as in round 1. ADR-0010 departure for `gh-issue` accepted: ADR-0010's own rationale says a cache hit is not refreshed (pull only on miss), so a cached state is not "checked this run"; a `gh` failure gives `unknown`, which is honest offline. Recording it in the script header is enough. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment] Medium** — For `script adapter --project <name> validate`, exit 1 does not only mean "does not validate". `adapter` exits 1 when its user-tier guard refuses the cwd (`registry_require_root "$WORKSPACE_ROOT" "$PWD"`, `.agent/scripts/adapter` line 145), when the name is not registered (line 191) and on a malformed registry (also 1). The skill is `session_scope: both`, so it can run from any cwd; a session outside every root would show the line as `false`, not `unknown`. Fix: run each `script` check with its cwd set to the runner's checkout root (a subshell `cd "$SCRIPT_DIR/../.."`; the plan's "run from" should say cwd as well as path), look the name up first with `registry_lookup` (rc 2 gives `unknown`; rc 1 gives `false`, documented as "not registered on this machine"), and add a test that runs the adapter form from a cwd outside the sandbox and gets a result other than a guard-caused `false`.
2. **[Principle alignment] Low** — The combination rule as written gives `partial` when every part is `unchecked` ("any unchecked gives partial", no all-unchecked case), and `false ; unchecked` also reads `partial`, which suggests something is true. Make all-unchecked give `unchecked`, and add `unchecked+unchecked` to the pair tests.
3. **[Issue alignment] Low** — The skill's "open PRs" read has the same cwd problem round-1 F4 fixed for `gh-issue`: from a project session `gh pr list` lists the project's PRs. Use `gh pr list -R <slug from $WS_ROOT's origin>` (the same `extract_gh_slug` path).
4. **[Principle alignment] Low** — `gh-issue` argument checks are not stated: `<N>` numeric, state `open` or `closed`, `owner/repo` matching a slug pattern, anything else `unchecked`; compare against `gh`'s `OPEN`/`CLOSED` case-insensitively. Add one malformed-argument case to the tests. (Text nit: the Approach says the Revision log is "below"; it is above.)

### Summary

Revision 2 resolves every round-1 finding, including the high one: the script allowlist is now exact argument vectors run from the runner's own directory, and the three allowed forms were verified read-only. The ADR-0010 departure and building "what moved" as summary counts are both sound. Ready for implementation, with the four items below done as part of it; the scope fits one PR tonight.

### Recommended Actions

- [ ] Run `script` checks with cwd at the runner's checkout root; pre-check the adapter name with `registry_lookup` (rc 2 gives `unknown`); test the adapter form from an outside cwd.
- [ ] Make an all-`unchecked` cell give `unchecked`; add the pair to the tests.
- [ ] Target the skill's open-PR read at the workspace repo with `-R`.
- [ ] Validate `gh-issue` arguments (numeric N, open/closed, slug pattern), case-insensitive state compare, one malformed-argument test.

## Checkpoint
**Status**: complete
**When**: 2026-10-12 18:40 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Plan revision 2 (13eea94), Plan Review round 2 (45113b4) verdict ready. Four items go to the implementer without another plan round: (medium) script checks run from the runner's own checkout root with a registry lookup first, so an outside cwd, an unregistered name or a malformed registry give unknown, not false, with a test from an outside directory; (low) an all-unchecked multi-check cell stays unchecked; (low) gh pr list passes -R with the workspace repo from its own remote; (low) gh-issue arguments validated (number, open/closed, owner/repo), else unchecked, case-insensitive state; text slip "Revision log is below". Host recommendation: proceed.

> yes

## Implementation
**Status**: complete
**When**: 2026-10-12 19:20 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-386 at `6c6e73a1`

Five commits in the plan's order (revision 2, 13eea94), with the four checkpoint items (b6b7ac2) folded in:

- 89782ce8: `_settings.sh` (read, never sourced; worktree falls back to the main checkout's `settings.local`), `capture.sh`, `.agent/settings.local.example` (placeholder paths only), `.gitignore` entry; `test_capture.sh` 27 pass (before the code: 2 vacuous passes, 27 failures).
- 49327f7c: `sitrep_checks.sh` and `test_sitrep_checks.sh` 49 pass (before: 4 vacuous, 46 failures). Checkpoint items: script checks run with the cwd at the runner's checkout root and the adapter name is looked up in the registry first, so an outside cwd, an unregistered name or a malformed registry give `unknown` (tested from `/`); an all-`unchecked` cell stays `unchecked`; `gh-issue` arguments validated (number or `owner/repo#N`, `open`/`closed` case-insensitive), else `unchecked`. Mutation checks: dropping the cd or the registry lookup fails the suite.
- 8b62395d: Direction section at the top of `docs/roadmap.md` (ADR-0016 acceptance case, format rules, six Line rows, four Deferral rows), roadmap row for #386, scenario 4 pointer; Direction fixture in `test_update_roadmap.sh` (15 pass); `what-next` skips Direction.
- 49480229: `.claude/skills/sitrep/SKILL.md` (`session_scope: both`, `$WS_ROOT` paths, `gh pr list -R` from the workspace's own remote); `what-next` pointer.
- 6c6e73a1: `docs/design.md` Documentation layers (Direction and Measures rows, gaps paragraph, Target), `settings.local` sentence in Registry and adapters, OQ-3 partly answered, change-log row (729 lines).

Deviation: `file-contains` on a missing file gives `false` (an unreadable file stays `unknown`). Tests run: `check_design_anchors.sh` clean; `test_capture`, `test_sitrep_checks`, `test_update_roadmap`, `test_skill_paths` (54) pass; `run_script_tests.sh` all 33 suites passed; `make lint` clean. Not done here: `AGENTS.md` Script Reference rows (Ask First) and the plan's follow-ups.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-12 19:28 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-386 at `942bb2a`
**Base**: main
**Depth**: Deep (reason: 1828 changed lines across 14 files; new scripts and a skill)
**Must-fix**: 5 | **Suggestions**: 10
**Round**: 1 | **Ship**: continue — round 1: 5 must-fix; first round always re-reviews after fixes

Reviewers: Claude adversarial ran; Codex ran (4 findings); Copilot ran (3 findings); Gemini failed (agy headless auto-denied a RunCommand tool call, empty response). Static: shellcheck clean on all 6 changed .sh; test_sitrep_checks 49/0, test_capture 27/0, test_update_roadmap 15/0, test_skill_paths 54/0; check_design_anchors rc 0; update_roadmap.sh on a copy of the branch roadmap for #379, #265, #295 leaves it byte-identical.

### Findings
- [x] (must-fix) Run through the `scripts/` symlink, SCRIPT_DIR stays logical and `../..` lands on the checkout's parent: sitrep_checks.sh default root reads no roadmap and prints `lines 0/0` silently; capture.sh looks for settings in the wrong place (text is echoed back, not lost). Use `pwd -P` — `.agent/scripts/sitrep_checks.sh:71`, `.agent/scripts/capture.sh:126`
- [x] (must-fix) Fences are tracked only after the section starts: a fenced `## Direction` example before the real section is read as the section and the real one is dropped (reproduced) — `.agent/scripts/sitrep_checks.sh:288`
- [x] (must-fix) Rows split on every `|`, so a GFM `\|` truncates the check and can print `true` (`file-contains f a\|b` ran as `a\` and read true); extra cells are dropped silently. Honour `\|` or mark a row that is not exactly 2 cells `unchecked`; add tests — `.agent/scripts/sitrep_checks.sh:272`
- [x] (must-fix) The skill runs every check three times (rows, `--summary`, run-record step), so the recorded summary can differ from the rows shown; derive the summary from one run — `.claude/skills/sitrep/SKILL.md:63`, `.claude/skills/sitrep/SKILL.md:132`
- [x] (must-fix) `inbox_new` compares minute-resolution timestamp strings with `>`: captures in the same minute as the last run are never counted new, and offset changes compare wrong. Use the `inbox <n>` count the run record already stores — `.claude/skills/sitrep/SKILL.md:93`
- [x] (suggestion) `file-exists`/`file-contains` follow symlinks out of the root (true/false oracle on any readable file); resolve with `realpath -e` and require the root prefix — `.agent/scripts/sitrep_checks.sh:198`
- [x] (suggestion) `gh` runs inside the `while read < roadmap` loop without `</dev/null`; a stdin-reading child would eat the remaining rows silently (script checks already redirect) — `.agent/scripts/sitrep_checks.sh:152`
- [x] (suggestion) `timeout` without `-k`: a check that traps TERM runs past the limit (8 s against 1 s in a repro); use `timeout -k 5` — `.agent/scripts/sitrep_checks.sh:126`
- [x] (suggestion) A Direction section with no recognised table prints a blank line and `lines 0/0`, the same as an empty valid section; emit a `section`/`format` row — `.agent/scripts/sitrep_checks.sh:361`
- [x] (suggestion) The "single O_APPEND write" claim holds only up to 4096 bytes (strace: a 10 kB line went out as 4096+4096+1809); cap the text or take a lock, and fix the comment — `.agent/scripts/capture.sh:189`
- [x] (suggestion) Empty `WS_REPO` reaches `gh pr list -R ""`; step 4 does not check the run-record directory it says it checks; an empty agent-workspace-root file gives `WS_ROOT=""` — `.claude/skills/sitrep/SKILL.md:108`, `.claude/skills/sitrep/SKILL.md:131`
- [x] (suggestion) The three `**Accepted.**` checks depend on ADR-0016 keeping bold `**Accepted.**` (other ADRs write plain `Accepted.`) and match anywhere in the file — `docs/roadmap.md:47`
- [x] (suggestion) `user_tier_install.sh --check` exits 1 for "cannot check" (unparseable settings.json) too, which the runner reports as `false`, not `unknown`; note it or special-case it — `.agent/scripts/sitrep_checks.sh:170`
- [x] (suggestion) The explicit-repo `gh-issue` regex lets a slug start with `-` (`-x/y#5` reaches `gh -R -x/y`); require an alphanumeric first character — `.agent/scripts/sitrep_checks.sh:145`
- [x] (suggestion) Test gaps: CRLF roadmap, `~~~` fences, `###` subheadings, escaped pipes, symlink escape, timeout expiry, an empty section; capture text starting with `-` or holding `%`, an inbox that is a directory, a line over 4 KB — `.agent/scripts/tests/test_sitrep_checks.sh`, `.agent/scripts/tests/test_capture.sh`

## Implementation
**Status**: complete
**When**: 2026-10-12 20:02 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-386 at `9e68644`
**Addressed**: Local Review (Pre-Push) at `942bb2a` (2026-10-12 19:28 -04:00)
**Commits**: 12f6839, 9e68644

### Actions
- [x] (must-fix) `pwd -P` for SCRIPT_DIR (and the default root) in both scripts; tests run each through a `scripts/` symlink — `.agent/scripts/sitrep_checks.sh`, `.agent/scripts/capture.sh`
- [x] (must-fix) fences tracked from the top of the file, closing run of the same character at least as long; tests with ``` and `~~~` examples before the real section, a backtick fence inside `~~~`, a four-backtick fence — `.agent/scripts/sitrep_checks.sh`
- [x] (must-fix) rows split on unescaped pipes (`\|` is a literal pipe); a row with more than two cells is `unchecked` and shows the extra cells; tests for `a\|b`, `x\|y` against a file holding `x\`, and an extra cell — `.agent/scripts/sitrep_checks.sh`
- [x] (must-fix) one run of the checks per sit-rep: step 1 saves the rows to a temp file, `--summary-from` gives both the shown and the recorded summary, step 4 removes the file; tests run the skill's steps 1 and 4 as written and count gh calls — `.claude/skills/sitrep/SKILL.md`, `.agent/scripts/sitrep_checks.sh`
- [x] (must-fix) `inbox_new` is the line count minus the last record's `inbox <n>`, `unknown` when the inbox shrank or the record has no count; step 4 records the real count; tests with same-minute captures and a shrunk inbox — `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion) symlink escapes: a path whose parent or final link resolves outside the root is `unchecked`; tests for a file link, a directory link (existing and missing target) and an in-root link — `.agent/scripts/sitrep_checks.sh`
- [x] (suggestion) every bounded call takes stdin from `/dev/null`; test with a gh stub that reads stdin — `.agent/scripts/sitrep_checks.sh`
- [x] (suggestion) `timeout -k $SITREP_KILL_AFTER` (default 5); test with a check that ignores TERM — `.agent/scripts/sitrep_checks.sh`
- [x] (suggestion) `section` rows for a missing roadmap file and for a section with neither table (an empty section included) — `.agent/scripts/sitrep_checks.sh`
- [x] (suggestion) capture writes under an exclusive `flock` on the inbox (10 s wait); header states the unlocked case where flock is missing; tests for eight parallel 20 kB lines and a held lock — `.agent/scripts/capture.sh`
- [x] (suggestion) step 3 skips gh with an empty repo and says so; step 4 checks the run-record directory and says why nothing was written; an empty agent-workspace-root file falls back to `.`; tests for all three — `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion) new `adr-status <path> <word>` kind reads the first line under that file's `## Status`; the three ADR-0016 checks use it; tests for bold, plain, a bold word in the body, no Status heading — `.agent/scripts/sitrep_checks.sh`, `docs/roadmap.md`
- [x] (suggestion) `user_tier_install.sh --check` cannot be told apart: it exits 1 for both drift and an unparseable settings.json, so the header states that case reads `false`; exits other than 0/1 were already `unknown` — `.agent/scripts/sitrep_checks.sh`
- [x] (suggestion) slug owner must start with a letter or digit, repo name with a letter, digit, `.` or `_` (`.github` accepted); test for `-x/y#5` — `.agent/scripts/sitrep_checks.sh`
- [x] (suggestion) test gaps: CRLF roadmap, `~~~` fences, `###` subheadings, escaped pipes, symlink escape, timeout expiry, empty section; capture text starting with `-` or holding `%`, an inbox that is a directory (now refused), a line over 4 KB — `.agent/scripts/tests/test_sitrep_checks.sh`, `.agent/scripts/tests/test_capture.sh`
- [x] (host, live run) a worktree copy of `capture.sh` tagged the main checkout `none`: `workspace` now covers any checkout of the same repository (git common dir), and a worktree without `projects.local` reads the main checkout's registry; tests for main checkout, worktree, project and outside cwds, and the main copy from a worktree outside its directory; design.md registry note updated — `.agent/scripts/capture.sh`, `docs/design.md`

### Tests
- `test_sitrep_checks.sh`: before the fixes 54 passed, 29 failed (every new check); after, 83 passed, 0 failed
- `test_capture.sh`: before the fixes 32 passed, 5 failed (symlink, lock, three worktree-copy tags; the 20 kB parallel test passed by luck before the lock); after, 37 passed, 0 failed
- `test_script_tests_hook_scope.sh`: the new skill-step tests read the real SKILL.md, so the suite gets a ROOT_READERS entry (`.claude/skills`); 104 passed, 0 failed
- Full pre-commit (script-tests suite, shellcheck) passed on both commits

### Follow-ups (not done here)
- `user_tier_install.sh --check` could exit a distinct code for "cannot check"; it touches `make validate` and that script's own tests
- The `WS_ROOT` idiom in every other project-capable skill still yields an empty root from an empty agent-workspace-root file; only the sit-rep guards it
- Other scripts that read the registry from a worktree root (no main-checkout fallback) behave as before; only capture.sh falls back
- `split_row` treats only `\|` as an escape; `\\|` reads as a backslash and a literal pipe, not GFM's escaped backslash then a cell break
