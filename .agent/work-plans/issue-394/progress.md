---
issue: 394
---

# Issue #394 — user_tier_install.sh: claude plugin commands strip the hook markers

## Issue Review
**Status**: complete
**When**: 2026-11-12 12:06 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #394

### Scope Assessment

**Well-scoped?** Yes. One script (`.agent/scripts/user_tier_install.sh`), its test, and a one-line `.gitignore` addition fit one small pull request. Checked against the code: the marker is written at lines 1310-1321, read by `--check` at lines 1052-1115, by the re-run and `--force` at lines 1343-1344, and by `--uninstall` at lines 989-993. That is the whole bug, and the pull request is the first of two planned under #446.
**Right repo?** Yes. Workspace infrastructure.
**Serves**: Quality of the work (a drift check that is true, no hook running twice) and Easy to use (the plugin can be enabled or disabled without the installer going wrong) -- `docs/design.md#sessions-and-roots`
**Design picture?** No change. It restores the behaviour ADR-0016 and the script header already describe: `--check` reports real drift, and install is idempotent.
**Dependencies**: none to start. It must merge before the user-scope work in #446 (pull request B), which relies on the CLI rewriting `settings.json`. The "Fix before or inside #332 PR 2" line in the issue is stale: #332 is closed (checked), and #446 is its successor.

Does the #446 plan's pull request A answer the issue as written? Yes, with two additions the issue never asked for and one gap to close.

- Issue: "identify by command path ... `--check` and the re-run must treat an unmarked entry with the installer's command as the installer's." Plan: any command under `$WS_ROOT/.claude/hooks/` or equal to `SESSION_HOOK_LINK` counts as ours; the re-run no longer duplicates. Answered. The retired-hook case (#328) comes along for free.
- Issue: "add a test that runs a settings rewrite without the marker between install and `--check`". Plan: a stub CLI that strips markers and reorders keys on every call. Answered, and stronger.
- Issue: `.gitignore`. Plan step 3. Answered; the entry is absent today (checked).
- Added by the plan, not in the issue: stop writing the marker, and skip a write that changes nothing (so `backup_settings` at line 1281 moves behind the comparison). Both are sound and small. The skip matters because the stripped file differs from the merged result on every run, so without it the backup count and the file churn grow on each run.
- Gap: the marker is also what tells "another checkout's" and "a checkout since moved or deleted" entries apart. Dropping every reader of it silently loses the moved-checkout case (the plan review's finding 1 on #446).

So the issue needs one scope note, not a rewrite: the fix also removes the dependence on the marker as the only recogniser, and covers a moved or deleted checkout. The #446 plan's "stop only writing it" resolution (keep reading the marker when present) fits inside the issue's own wording ("not by a field the CLI does not preserve").

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | Action needed | The test must also cover a checkout moved or deleted after the install: its hook commands are under a directory that no longer exists, carry no marker once the CLI strips it, and have no `.agent/user_tier_scripts.txt` beside them. Today `--check` reports such an entry through the marker (lines 1067-1093) and `--force` removes it (lines 1343-1344). Keep reading the marker when present and stop only writing it, or report as drift any hook command under a `.claude/hooks/` directory that does not exist on disk. |
| Verify before claiming | OK | Reproduction in the issue was a sandbox run on 2026-10-13. The code at HEAD still writes and reads the marker as described. |
| Only what's needed | OK | Every part of the fix traces to the reported failures; the no-op write skip is what makes "re-run does not churn" testable. |
| Put each thing at the level it applies to | OK | Workspace installer, workspace repo. `.gitignore` entry is a repository-level protection for any clone. |
| Keep one current design | Watch | No design text changes. The script header (lines 62-64) says every entry is tagged with `_agent_workspace`; it must be reworded in the same pull request, or it states something the code no longer does. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0016 (session roots and the user tier) | Yes | The user tier stays optional, `--check` exits 0 with a note when it is not installed. The change must keep that. |
| ADR-0018 (plugin-based skill delivery) | Watch | It is why the CLI rewrites the file at all. No change needed. |
| ADR-0013 (progress timeline) | Yes | This entry. |

### Consequences

- Reword the header comment of `user_tier_install.sh` about the marker (lines 62-64).
- `test_user_tier_install.sh` (retired-hook case around line 305, foreign-checkout and `--force` cases) are written against tagged entries. They need an unmarked variant, not only the tagged one.
- `.agent/knowledge/script_reference.md` is worth a look if it describes the marker (not checked here).
- The "Fix before or inside #332 PR 2" line is stale; no edit to the issue body is needed, the plan references the successor.

### Recommendations

- Scope note on the issue (comment only): the fix may also stop writing `_agent_workspace` and skip a settings write that changes nothing; it must keep detecting a hook entry from a checkout that has since been moved or deleted. State that "fix before #332 PR 2" is now "fix before #446 pull request B".
- Add to the test list: install, CLI strip and reorder, `--check` exits 0, a second install leaves `settings.json` byte-identical with no new backup; a moved-or-deleted-checkout entry is still reported by `--check` and removed by `--force`.
- Reword the header comment in `user_tier_install.sh` about the marker in the same pull request.

### Actions
- [ ] The test must also cover a checkout moved or deleted after the install: its hook commands are under a directory that no longer exists, carry no marker once the CLI strips it, and have no `.agent/user_tier_scripts.txt` beside them. Today `--check` reports such an entry through the marker (lines 1067-1093) and `--force` removes it (lines 1343-1344). Keep reading the marker when present and stop only writing it, or report as drift any hook command under a `.claude/hooks/` directory that does not exist on disk.
- [ ] Scope note on the issue (comment only): the fix may also stop writing `_agent_workspace` and skip a settings write that changes nothing; it must keep detecting a hook entry from a checkout that has since been moved or deleted. State that "fix before #332 PR 2" is now "fix before #446 pull request B".
- [ ] Add to the test list: install, CLI strip and reorder, `--check` exits 0, a second install leaves `settings.json` byte-identical with no new backup; a moved-or-deleted-checkout entry is still reported by `--check` and removed by `--force`.
- [ ] Reword the header comment in `user_tier_install.sh` about the marker in the same pull request.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 12:05 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review finds the issue well-scoped and answered by the design in issue 446's plan, pull request A; its four actions are a test case, a comment-only scope note, a test list and a header reword, none a change of scope)
**After**: issue-actions
**Decision**: proceed

The host read the Issue Review entry at 3d512a6e. The plan takes the four actions as requirements: keep reading the marker when present and stop only writing it (the host's choice between the two the review offers, the same as on issue 446's plan), with the moved-or-deleted-checkout test. The scope note is carried in the plan and the pull request text; no comment is posted on the issue for it.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 12:07 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-394/plan.md` at `a4fc6888`

Issue 446's pull request A, made self-contained and checked against the script and its tests on this branch: hook entries matched by command path, marker still read but no longer written, no-op settings writes skipped (backup moved behind the comparison), .gitignore entry, stub-CLI tests including the moved-checkout case, header, design.md and ADR-0016 wording.

## Plan Review
**Status**: complete
**When**: 2026-11-12 12:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #394 — user_tier_install.sh: claude plugin commands strip the hook markers, so --check reports drift and a re-run duplicates the hooks
**Plan**: `.agent/work-plans/issue-394/plan.md` at `a4fc6888`
**Branch**: `feature/issue-394`

Ready with five must-fix amendments the implement pass carries (Actions below); none needs a re-plan. Settled by issue 446's two plan reviews and not re-argued here: match by command path; read the marker when present, stop writing it; skip a write that changes nothing; another checkout recognised by `.agent/user_tier_scripts.txt`.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One script, its test, `.gitignore`, `docs/design.md`. One pull request. |
| Issue alignment | Needs work | Answers the issue as written. Serves, as checked: "Quality of the work and Easy to use -- `docs/design.md#sessions-and-roots`" (both are sections of `README.md`'s goals; the anchor exists at design.md line 177). The plan does not keep the Issue Review's action "it must keep detecting a hook entry from a checkout that has since been moved or deleted" once the CLI has stripped the marker (finding 1). |
| File targeting | Good | Right files. Some line numbers are off (finding 7). |
| Consequences | Needs work | Two existing test cases are described as "keep working" but break. A third one goes vacuous and is not listed (findings 4, 5). |
| Principle alignment | Needs work | Test what breaks: the dead-checkout case is tested only in its marked form (finding 1). Quality Standard: a user's own hook command is dropped silently (finding 2). |
| ADR compliance | Concern | Step 7 edits the Consequences of ADR-0016, which is Accepted. ADR-0017 says Accepted ADRs are "superseded, not edited, apart from ADR-0008 addendums" (finding 3). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment: Test what breaks]** must-fix. This comes from issue 446's third plan review (finding 1), and it holds here. Issue 394's own finding is that every `claude plugin` command that rewrites `~/.claude/settings.json` drops the marker. Issue 446's pull request B makes user-scope `claude plugin` calls on every install. So soon after this lands, no entry on the machine carries a marker. A checkout moved or deleted after that leaves a PreToolUse command `<old>/.claude/hooks/log-tool-use.sh` that is not under `$WS_ROOT/.claude/hooks/`, has no `user_tier_scripts.txt` beside it and carries no marker, so neither `--check` nor `--force` sees it. The plan's own test comment ("Once the CLI has stripped that marker nothing can attribute it") accepts this gap. The Issue Review's action rules it out. Add the second rule as well as reading the marker. A hook command of the form `<dir>/.claude/hooks/<name>`, where `<name>` is a hook the installer writes or has retired (today `log-tool-use.sh` and `block-bash-tool-mapping.sh`; checked in the script's git history, 1d3cf19f), and whose path does not exist on disk, is drift for `--check`. Install and `--force` remove it. This is narrower than the rule Prior Art rejected ("any hook under a `.claude/hooks/` directory missing on disk"), so a user's own dead hook with another name is still left alone. The existence test needs the filesystem, so compute it in bash next to the foreign-directory list (finding 6). The SessionStart entry names the `~/.claude` link (line 144), so only PreToolUse needs the rule. Test it with an unmarked entry that points into a deleted scratch checkout: `--check` reports it, plain install removes it. Also keep the planned marked variant, and update Prior Art to say what was taken.
2. **[Principle alignment: Quality Standard]** must-fix. This is the mixed-entry rule. Remove only our commands from an entry and keep the rest; drop an entry only when it is left with no command. Reason: the path rule identifies each command on its own, so dropping the user's command along with ours buys nothing and silently deletes something the user wrote in their own `~/.claude/settings.json`. Without the marker, a matcher-less PreToolUse or SessionStart entry that holds a second command is more likely the user's edit than ours, because the installer only ever writes one command per entry. "As a marked one is today" describes the same loss and does not justify it. In jq: `map(.hooks |= map(select(<command is ours> | not))) | map(select((.hooks // []) | length > 0))`. The entry's other keys (for example `matcher`) are kept. For a marked entry, "ours" also covers commands under `<marker>/`, so a dead checkout's marked command still goes and anything else in that entry stays. Apply this in install, `--force` and `--uninstall`. Test: an entry that holds our command and `/opt/mine.sh` keeps `/opt/mine.sh`, in the same entry, after a re-install, after `--force` and after `--uninstall`. Remove the item from Open Questions.
3. **[ADR compliance]** must-fix. Drop the edit to ADR-0016 lines 207-210 (Consequences, "A second checkout is detectable, not silently merged"). ADR-0016 is Accepted, and ADR-0017's Decision says Accepted ADRs are "superseded, not edited, apart from ADR-0008 addendums". ADR-0008 allows navigational pointers only, and rewording is not one. The consequence itself still holds (a second checkout is still detectable). Only the mechanism changes, which is implementation detail for the script header. Where the two disagree, `docs/design.md` wins (ADR-0017 Consequences). So reword design.md line 219 and the script header, and leave the ADR as it is. Update the plan's ADR Compliance row for ADR-0016, its Consequences row and Files to Change.
4. **[Consequences: tests]** must-fix. Two existing cases break; the plan says they "keep working". (a) Lines 252-256 remove our entry with `select((._agent_workspace // "") == "")`. With no marker written, that keeps every entry, so `--check` finds nothing missing and the case fails. Remove the entry by command path instead. (f) Lines 304-312 append the retired command into entries tagged `$WSC`. None exist any more, so nothing is appended and the case fails. Make (f) the marked variant by writing a marked entry itself, beside the planned unmarked one. Case (b), lines 259-268, does still work, because it writes its own marked entry.
5. **[Consequences: tests]** must-fix. The symlinked-settings case at lines 518-530 is not listed, and it becomes vacuous. The `run` at line 523 follows a run that made settings current, so it is now a no-op. "still a symlink" and "the real file received the install" then pass without the write-through path being exercised. Make a real change first (drop an allow-rule, as planned for the dotfiles case at line 632) and assert that the rule came back in the real file. The other planned test changes are true consequences of the no-op skip and keep their guarantee: backup-before-rewrite (line 389), seven-installs-five-backups (line 569, each run must write), dotfiles inode (line 648) and the uninstall and `--force` assertions (lines 342 and 452-457) by command path. Lines 459-464 already assert by path. Add a no-op assertion beside line 389 as well: a run with nothing to change writes no backup. That is the new guarantee, and it lives next to the old one.
6. **[Approach step 3]** should-fix. `--force` computing the other checkouts' directories in bash and passing them to jq is sound. Make it one helper, used by `--check` (whose "another checkout" note needs the same list; the plan describes the computation only for install) and by install. It returns a JSON array built with `jq -R . | jq -s .`, as `wanted_json` is today, and it also carries finding 1's dead paths. Compare `<dir>`'s physical path (`cd "$dir" && pwd -P`) with `$WS_PHYS`, not only the lexical one with `$WS_ROOT`. Otherwise an entry written through a symlinked alias of this checkout is reported as another checkout's, which is false drift. Match the whole command with `^(.*)/\.claude/hooks/[^/]+$` and leave anything else alone.
7. **[File targeting]** note. The header the plan cites at lines 62-64 is at 61-63. The `--uninstall` line in the mode list is at 73-75, not 80-82. `require_parseable_settings` is at line 1256, not 1223. The other user-facing text that says "tagged" also needs rewording: line 997 ("removed settings entries tagged $TAG"), line 1091 ("tagged as ours points outside"), line 1113 ("tagged as ours is no longer generated") and line 20 (the retired-hook note).
8. **[Approach step 3, retired-hook prefix]** note, agreed. The prefix has to narrow from `$WS_ROOT/` to `$WS_ROOT/.claude/hooks/`. Without the marker, the old prefix would treat a user's own hook that runs a checkout script (for example a promoted `.agent/scripts/` script) as ours and drop it on install. Nothing is lost: every generation in the script's history wrote hook commands only under `.claude/hooks/` (checked across all its commits). Keep the retired names in one list, shared with finding 1's dead-path rule.

### Summary

The design is right and the plan is close. The implement pass carries five must-fix amendments: the dead-path rule with an unmarked test, per-command removal for mixed entries, no edit to the Accepted ADR, the two existing tests that break, and the symlink test that would go vacuous. Two notes and one should-fix tighten details. No re-plan is needed.

### Actions
- [ ] Add the dead-path rule: a command `<dir>/.claude/hooks/<log-tool-use.sh or block-bash-tool-mapping.sh>` whose path is absent on disk is drift for `--check`, and install and `--force` remove it. Test with an unmarked entry into a deleted scratch checkout. Update Prior Art (finding 1).
- [ ] Remove only our commands from a hook entry and keep the user's; drop an entry only when it is left with no command. Do this in install, `--force` and `--uninstall`, with a mixed-entry test for each (finding 2).
- [ ] Do not edit ADR-0016. Reword `docs/design.md` line 219 and the script header only, and fix the plan's ADR and Consequences rows (finding 3).
- [ ] Rewrite existing test (a), lines 252-256, to remove by command path. Make (f), lines 304-312, seed its own marked entry (finding 4).
- [ ] Make the symlinked-settings case at lines 518-530 a real change and assert the write-through. Add a no-op-writes-no-backup assertion beside line 389 (finding 5).
- [ ] Put the other-checkout and dead-path computation in one bash helper used by `--check` and install. Compare with `pwd -P` against `$WS_PHYS` (finding 6).
- [ ] Reword the remaining "tagged" messages at lines 20, 997, 1091 and 1113 (finding 7).

## Checkpoint
**Status**: complete
**When**: 2026-11-12 12:12 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is ready: an implement pass builds the right thing provided it carries the review's Actions list, five must-fix changes, one should-fix and a wording note, none needing a new plan; the reviewer says so, and a revise round would only copy that list into the plan)
**After**: plan
**Decision**: proceed

The host read the Plan Review entry at 0f57c07a. The implement handoff makes the entry's Actions list a requirement equal to the plan, and where the two differ the review wins: the dead-path rule beside reading the marker; only the installer's own command is removed from a mixed entry and the user's is kept; ADR-0016 is not edited; test cases (a) and (f) and the symlinked-settings case are repaired; one helper computes the other-checkout and dead-path lists with physical paths.

## Implementation
**Status**: complete
**When**: 2026-11-12 12:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-394 at `8cfb9f6c`

Built the plan with the Plan Review's Actions list (0f57c07a) taking precedence where they differ. Commits 699f0386 (script and tests), d9327dc7 (.gitignore), 8cfb9f6c (design.md).

- `user_tier_install.sh`: hook commands are recognised one at a time by path. One helper, `hook_path_lists`, returns three JSON arrays for `--check` and install: this checkout's `.claude/hooks/` prefixes (lexical, physical, and any `<dir>` whose `pwd -P` is this checkout, so a symlinked alias is not another checkout); other checkouts' `<dir>` (holding `.agent/user_tier_scripts.txt`); and dead paths (`<dir>/.claude/hooks/<name>`, `<name>` in `INSTALLER_HOOK_NAMES` or `RETIRED_HOOK_NAMES`, the shared list: `log-tool-use.sh`, `block-bash-tool-mapping.sh`; path not on disk). The whole command is matched with `^(.*)/\.claude/hooks/[^/]+$`; the SessionStart link is skipped.
- Mixed entries (review finding 2): one shared jq `prune` (`PRUNE_JQ_DEFS`) removes only the installer's commands from an entry and keeps the user's commands and the entry's other keys (`matcher`). It drops an entry only when no command is left. For a marked entry, commands under the marker's checkout count too. Used by install, `--force` and `--uninstall`. `--force` also removes other checkouts' commands, by path or by marker. A plain install removes dead paths and leaves other checkouts' commands alone. `--uninstall` removes this checkout's commands only.
- The `_agent_workspace` marker is still read where present and no longer written. Where a command is removed from an entry that survives, the marker is removed from that entry as well. Without that, a marked mixed entry left after `--force` would keep `--check` red permanently ("another workspace checkout"), and no install could clear it.
- `--check`: a missing hook is checked across all entries, marked or not. The "another workspace checkout" note now also covers unmarked commands under another checkout. A new drift line reports dead paths. The retired-hook check covers any command under this checkout's `.claude/hooks/` (narrowed from `$WS_ROOT/`), and under the checkout in an entry marked with it.
- Install: the merged JSON is built in a variable and compared with `jq -S` against the current file (absent counts as `{}`). When they are equal, the file is not written and gets no backup. `backup_settings` moved to just before the real write. To keep a current file byte-identical, the first entry that already equals ours stays where it is (no remove-and-append reordering). This is a choice made to meet the plan's byte-identical test, listed here for veto.
- User-facing text: the header (now lines 61-76) and the `--uninstall` mode line are reworded. The "tagged" messages at the old lines 997, 1091 and 1113 are reworded, and the old line 20 now says "command".
- `docs/design.md` line 219 reworded. ADR-0016 not edited (review finding 3). `.gitignore` now lists `.claude/settings.local.json` (`git check-ignore` confirms).
- Tests (`test_user_tier_install.sh`, 203 to 237 assertions): repaired (a) (removes by path), (f) (seeds its own marked entry), the symlinked-settings case (drops an allow-rule first, asserts the rule came back in the real file), the backup cases (no-op run: no backup and a "not rewritten" line; rotation and dotfiles runs each make a real change), and the uninstall and `--force` assertions (by command path). New: a `claude-rewrite` stub that strips every marker and reverses key order. With it: `--check` stays clean, a re-install is byte-identical (`cmp`) with no backup, and each event holds our hook once. Also new: an unmarked retired hook; an unmarked dead-checkout command (reported, removed by plain install); a marked moved-checkout entry (reported, removed by `--force`); another checkout's unmarked command (reported, kept by install, removed by `--force`); mixed entries under install, `--force` (unmarked and marked) and `--uninstall`; the user's own dead hook and a same-named hook outside any checkout, never reported and never removed; a symlinked alias.
- Verification: `bash .agent/scripts/tests/test_user_tier_install.sh` gives 237 passed, 0 failed. A mutation check in a scratch copy disabled each of four parts (dead rule, physical compare, no-op skip, per-command prune) and each made the new cases fail (3, 3, 4 and 5 failures). `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, exit 0. Its script-tests hook ran 11 of 45 suites, all passing, including test_user_tier_install, test_register_project, test_session_start_layer, test_user_tier_guard and test_sitrep_checks. Every run used the scratch HOME and the stub CLI. The real `~/.claude` was not touched.
- Not done: the plan file itself was not amended (Prior Art, the ADR-0016 row, Consequences, Open Questions). The review's Actions govern those, as the host's checkpoint recorded.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 12:42 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-394 at `310c978a`
**Base**: main
**Depth**: Deep (reason: 917 changed lines across 6 files, enforcement script that edits the user's ~/.claude/settings.json)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Held against plan.md and the Plan Review Actions at 0f57c07a (the review wins where they differ). Specialists: static analysis (shellcheck --severity=warning on both scripts: clean), governance, plan drift, Claude adversarial (fresh subagent), cross-model (Gemini and Codex both ran). Tests: `test_user_tier_install.sh` 237 passed, 0 failed. Both must-fix findings were reproduced in a scratch HOME with the test's stub CLI.

### Findings
- [x] (must-fix) The dead-path and path rules treat any string matching `<dir>/.claude/hooks/<file>` as a path. A user's own working hook is classified dead and removed by a plain install when written `"$CLAUDE_PROJECT_DIR"/.claude/hooks/log-tool-use.sh`, `bash /existing/.claude/hooks/log-tool-use.sh` or `~/x/.claude/hooks/log-tool-use.sh` (`! -e "$cmd"` on an unexpanded string). `./.claude/hooks/...` is resolved against the installer's cwd: removed as ours from the checkout, reported as "another workspace checkout: ." elsewhere. Fix: classify only a literal absolute path (starts with `/`, no whitespace, quote, `$` or `~`), and call it dead only when `<dir>` itself is gone (a moved or deleted checkout), not just the file, which also spares an existing project that lacks only its hook file (Codex). Test each form — `user_tier_install.sh:325-341`
- [x] (must-fix) A marked entry from which nothing is removed keeps its marker, so `--check` stays red and no install clears it: an entry marked with this checkout holding only `/opt/mine.sh` ("marked with this checkout points outside it"), or another checkout's marked entry holding only a user command, even after `--force` ("another workspace checkout"). Fix: in `prune`, drop the marker from every entry marked with this checkout (install, `--uninstall`) and, under `--force`, from every marked entry, whether or not a command was removed. Test both — `user_tier_install.sh:374-381`
- [x] (suggestion) `hook_path_lists` reads commands with `.[]? | .[]? | .hooks[]?`; a non-array event value such as `"X": {"a": 1}` makes jq error inside the process substitution, the error is swallowed, and the dead and foreign lists come back empty: install prints "merged" and `--check` reports current while those commands stay. Guard the types (`select(type=="array")`, `select(type=="object")`) or fail loud — `user_tier_install.sh:341`
- [x] (suggestion) "Ours" is any file under this checkout's `.claude/hooks/`, so a user's own hook wired directly to another file there (for example `session_start_project_layer.sh`) is removed as retired. `INSTALLER_HOOK_NAMES` and `RETIRED_HOOK_NAMES` now exist; match on those names under the self prefixes — `user_tier_install.sh:368,1236`
- [x] (suggestion) `backup_settings` now runs after the root file and the SessionStart link are written; a failed backup exits 1 with the root file in place, so the tier reads as installed with settings unchanged. Build the merge and take the backup before step 1, or say so in the error — `user_tier_install.sh:1407-1497`

Implement-pass choices, judged: (1) dropping the marker from an entry that loses a command: agreed; must-fix 2 extends the same reasoning to entries that lose nothing. (2) an entry already exactly ours stays in place: agreed; jq `==` ignores key order, and only position is affected. (3) `--uninstall` removes only this checkout's commands: agreed; same scope as the old tag-based uninstall, and dead or foreign commands are install's and `--force`'s to clear.

Dismissed: Gemini and Codex "ADR-0016 lines 207-210 not reworded" (deliberate: ADR-0017 forbids editing an Accepted ADR, Plan Review finding 3); Gemini "`$WS_PHYS` could be empty" (set at startup, line 128); adversarial "a scalar inside an event array fails the merge" (fails safe, writes nothing, and predates this branch).

## Implementation
**Status**: complete
**When**: 2026-11-12 13:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-394 at `f0ae3b8a`
**Addressed**: Local Review (Pre-Push) at `310c978a` (2026-11-12 12:42 -05:00)
**Commits**: aecbb853, 6130d151, f0ae3b8a

### Actions
- [x] (must-fix) Look-alike user hooks were classified as paths and removed. `classify_hooks` is now the one function that decides, used by `--check`, install, `--force` and `--uninstall`. It classifies a command only when it is exactly one the installer writes, or when the whole string is a literal absolute path (starts with `/`; no whitespace, quote, `$`, `~`, backslash, glob character or shell operator) of the form `<dir>/.claude/hooks/<name>`, with `<name>` in `INSTALLER_HOOK_NAMES` or `RETIRED_HOOK_NAMES`. "Dead" requires `<dir>` itself to be gone. Anything else is the user's: never reported, removed or rewritten. The jq side no longer matches on string shape (`hookdir` and the prefix lists are gone) — `user_tier_install.sh` `classify_hooks`, `PRUNE_JQ_DEFS` (aecbb853)
- [x] (must-fix) A marked entry that lost nothing kept its marker. `prune` now drops this checkout's marker from every entry (install, `--uninstall`) and, under `--force`, every marker, whether or not a command was removed. `--check`'s message for the this-checkout case now says that a re-install drops the marker and keeps the command — `PRUNE_JQ_DEFS` `unmark` (6130d151)
- [x] (suggestion) A swallowed jq error on a non-array event value. Hook entries are read through the type-guarded `hook_entries`/`entry_commands` defs everywhere. A jq failure in classification or in any `--check` query built on it exits 1 with a message, and settings.json stays untouched — `HOOK_ENTRIES_JQ`, `class_query` (aecbb853)
- [x] (suggestion) "Ours" meant any file under this checkout's `.claude/hooks/`. A command is now ours only when its name is in the written-or-retired lists (or it is exactly a written command) — `classify_hooks` (aecbb853)
- [x] (suggestion) The backup ran after the root file and the link were written. Install now checks the link's preconditions, classifies, merges and backs up first, and only then writes the root file, the rules record, the link and settings.json — install section (f0ae3b8a)

### Notes
- Choice listed for veto: a command exactly equal to one the installer writes (the `log-tool-use.sh` path, the SessionStart link) is ours even if the checkout or HOME path holds a character the literal rule rejects. Without that, a checkout path with a space would make every install add a second copy of our hook.
- Tests changed: fixtures (f), (h) and (j) used `zz-retired-hook.sh` and `x.sh`, names the new rule leaves to the user. They now use `block-bash-tool-mapping.sh` and `log-tool-use.sh`. (j)'s moved checkout now exists without a manifest, so the marker is what attributes its command.
- Tests added (`test_user_tier_install.sh`, 237 to 255 assertions): (n) seven user forms (quoted variable, interpreter prefix, tilde, relative path, our hook with a trailing argument, an existing project lacking only the file, a hook wired to `session_start_project_layer.sh` in this checkout), run through `--check` from this checkout and from another checkout's cwd, install, `--force` and `--uninstall`; (o) a non-array event value beside a dead hook; (p) both marker cases through `--check`, install and `--force`, plus the `--uninstall` marker case; and a `cp` shim that fails only the backup, after which no root file, rules record or link exists and settings.json is byte-identical. The run() helper gains `RUN_PATH_PREFIX`.
- Verification: the suite gives 255 passed, 0 failed, and each intermediate commit's state passed too (246, 252). Mutation check: the new test file run against the round-1 script (fee1eeab) gives 14 failures, and each of the seven user forms is removed there individually. shellcheck `--severity=warning` is clean on both files. `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, exit 0, script-tests hook included. Scratch HOME and the stub CLI only; the real `~/.claude` was not touched.
- Outside these findings, reported and not fixed: `--uninstall` has the same ordering as suggestion 5. It removes the root file, the link and the plugin from every root before `backup_settings`, so a failed backup there exits 1 with those already gone and settings.json unchanged.

### Next step
`/review-code --branch`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 13:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-394 at `086d86ff`
**Base**: main
**Depth**: Deep (reason: 1248 changed lines across 6 files, enforcement script that edits the user's ~/.claude/settings.json; whole-diff classification, fix round)
**Must-fix**: 1 | **Suggestions**: 4
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 2), not rising; fix and ship rather than another full round

Re-review of aecbb853, 6130d151 and f0ae3b8a (round 1's two must-fix and three suggestions: all five fixed as described; checked against the code and the tests). Specialists: static analysis (shellcheck --severity=warning on both files: clean), governance, plan drift, Claude adversarial (fresh subagent), cross-model (Gemini and Codex both ran). Tests: `test_user_tier_install.sh` 255 passed, 0 failed. Scratch HOME and stub CLI only; the real `~/.claude` was not touched.

### Findings
- [x] (must-fix) `--uninstall` removes the root file, the SessionStart link and the plugin from every root before it checks, classifies and backs up settings.json, and its rewrite (`jq ... | write_settings && echo`) has no failure branch: a jq failure (a non-object entry in a hooks array, a boolean event value, a non-array `permissions.allow`) or a refused write still deletes `agent-workspace-rules.json`, prints "user tier removed." and exits 0 with our hook commands left in settings.json; a classify or backup failure exits 1 with the files already gone. Do what install now does: parse check, classify, build the rewrite and back up first, then remove anything; on a failed rewrite exit 1 and keep the rules file. Test each failure (reproduced by the adversarial specialist) — `user_tier_install.sh:1111-1172`
- [x] (suggestion) The exact-match rule covers only the commands written today. With a space in a checkout path, this checkout's retired `block-bash-tool-mapping.sh` is never reported or removed, and `--force` keeps another checkout's marked command while dropping its marker, after which `--check` reports current and nothing can attribute it. Extend the exact match to `$WS_ROOT`/`$WS_PHYS` + `/.claude/hooks/<retired name>` and, inside a marked entry, to `<marker>/.claude/hooks/<known name>` (Codex) — `user_tier_install.sh:361-366,426`
- [x] (suggestion) `--check` reports "installed and current" when our command sits in two PreToolUse entries (the state this issue's bug left behind) or only under another event: it tests presence anywhere. Check `.hooks.PreToolUse` and `.hooks.SessionStart` themselves and flag a count above one, so `--check` agrees with what install would change — `user_tier_install.sh:1234-1237`
- [x] (suggestion) A plain install removes a dead command, and a whole entry with its matcher when nothing else is left, without naming it; a user's own `log-tool-use.sh` on an unmounted drive goes this way. Print each dead or foreign command removed, with the backup path (Codex, adversarial) — `user_tier_install.sh:1500-1523`
- [x] (suggestion) A `PreToolUse` or `SessionStart` value that is an object rather than an array is turned into an array by `place`, and its keys are dropped. Refuse with "nothing changed" instead — `user_tier_install.sh:1508-1516`

Fix-pass choice, judged: a command exactly equal to one the installer writes counts as ours even when the path holds a character the literal rule rejects. Agreed: it is equality with a string the installer itself produced, not a guess from its shape, so a user hook can only match by being that exact command; without it a checkout path with a space makes every install add a second copy. The second suggestion applies the same reasoning to the strings earlier generations wrote.

`--uninstall` ordering (reported by the fix pass, not fixed): belongs in this pull request, as must-fix 1. Same file, same class as round 1's suggestion 5 that this branch fixed for install, the block was already rewritten here (and gained a new late failure point, `classify_hooks`), and the silent exit 0 is a failure the Quality Standard does not leave for later.

Dismissed: Gemini and Codex "ADR-0016 lines 207-210 not updated" (deliberate, ADR-0017; Plan Review finding 3, as in round 1); Gemini "the SessionStart link is always classified ours, even in an entry marked with another checkout" (the link is one per machine and the installer's own, and `--uninstall` already removes the link file itself, unchanged from main); Gemini "a marked entry with an empty hooks array passes --check" (harmless; install drops the marker); adversarial "a non-object entry in a hooks array fails install" (fails safe, predates the branch, dismissed in round 1; its uninstall consequence is must-fix 1).

## Implementation
**Status**: complete
**When**: 2026-11-12 13:31 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-394 at `86614aa2`
**Addressed**: Local Review (Pre-Push) at `086d86ff` (2026-11-12 13:08 -05:00)
**Commits**: 33261037, 9613a9fa, 0a53c3c6, 4c5d851b, 86614aa2

### Actions
- [x] (must-fix) `--uninstall` now follows install's order: parse check, classify, read the recorded rules, build the rewrite, back up, write settings.json, and only then remove the root file, the link, legacy skill links, the plugin and the rules record. Every failure up to and including the write exits 1 with "nothing changed". `write_settings` now returns 1 on a failed rename (both branches; the symlink branch returned 0 before) and removes its temporary file. Tested: a boolean event value, a non-array `permissions.allow`, a non-object entry in a hooks array, a failed classification (jq shim), a failed backup (cp shim), a refused write (mv shim); each leaves the root file, rules record, link, plugin (no stub CLI call) and settings.json as they were, with no temporary file — `user_tier_install.sh` uninstall section (33261037)
- [x] (suggestion) The exact match now covers `$WS_ROOT`/`$WS_PHYS` + `/.claude/hooks/<name>` for every written or retired name, and a new class `marked`: exactly `<marker>/.claude/hooks/<known name>`, attributed only inside an entry carrying that marker (the user's anywhere else). `dir_class` is the one place that decides self/foreign/dead/named. Tested with a checkout path holding a space (its retired hook reported and removed, our hook held once) and another checkout's marked entry under a spaced path (plain install keeps it, `--force` removes it, the same string in an unmarked entry stays) — `classify_hooks`, `dir_class`, `owner` (9613a9fa)
- [x] (suggestion) `--check` counts each of our commands under its own event: none is "missing ... (under <event>)", more than one is "registered N times", and a copy under another event is drift. Tested with duplicates in both events and the hook moved to PostToolUse; install fixes each and `--check` is clean after — `check_event_count` (0a53c3c6)
- [x] (suggestion) Host direction applied: a plain install removes only what it can attribute (ours by exact match or path rule, or a dead command in an entry carrying the marker). An unmarked dead command is reported by `--check` and named by a plain install, both with the remedy `<checkout>/.agent/scripts/user_tier_install.sh --force`, and left in place; `--force` removes it. Every command a run removes and does not write back is printed with the backup path (`BACKUP_PATH`). Tests (i) and (o) changed from "plain install removes" to "plain install names and keeps, `--force` removes"; new (i2): a marked dead command, removed by a plain install. Header reworded; `docs/design.md`'s sentence does not state the dead rule, so it is unchanged — `remove`, install report (4c5d851b)
- [x] (suggestion) Install refuses a `hooks` that is not an object, or a `PreToolUse`/`SessionStart` that is neither null nor an array, with "nothing changed", before classify, backup or any write; `--check` reports it as drift. Tested with an object, a string and an array `hooks`: exit 1, settings.json byte-identical, no backup — `hook_shape_errors` (86614aa2)

### Notes
- Verification: `bash .agent/scripts/tests/test_user_tier_install.sh` gives 302 passed, 0 failed (255 before this pass); each intermediate commit's state passed too (279, 286, 291, 296). `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP passed, exit 0, script-tests hook included. Scratch HOME and the stub CLI only; the real `~/.claude` was not touched.
- Denied: a mutation check (the new test file run against the round-2 script in a scratchpad copy) was refused by the permission system and not run another way.
- Choice listed for veto: the printed removals include this checkout's retired or alias-path commands as well as dead and foreign ones ("every command a run removes and does not write back"), since `--force` was to print each command it removes.
- Choice listed for veto: `write_settings` failure handling (a failed rename now returns 1) is outside the five findings' lines but is what makes the must-fix's "on a failed rewrite exit 1" true for a symlinked settings.json.

### Next step
`/review-code --branch`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 13:35 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a06a5823d94870b2d, resume 1 of 3)

**Branch**: feature/issue-394 at `1e02b457`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff; whole diff 1717 changed lines across 6 files, enforcement script that edits the user's ~/.claude/settings.json)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — no must-fix findings; the remaining suggestion can be applied or tracked

Narrow check of the round 2 findings and the fix diff 22a52c40..1e02b457 (33261037, 9613a9fa, 0a53c3c6, 4c5d851b, 86614aa2). Cross-model: skipped (round-3 convergence check, per handoff). Specialists: static analysis (shellcheck --severity=warning on both files: clean), governance, plan drift, Claude adversarial (fresh subagent; its scratch-HOME reproduction was denied by the permission system and not worked around, so its findings are from reading). Tests: `test_user_tier_install.sh` 302 passed, 0 failed. The real `~/.claude` was not touched.

All five round 2 findings are closed. The must-fix: `--uninstall` now checks, classifies, builds, backs up and writes settings.json before it removes anything, and every failure up to the write exits 1 with "nothing changed". The four suggestions: exact match for retired names and marked checkouts, `--check` counting per event, removals named with the backup path (plain install leaves unmarked dead commands, per the host's direction), and refusal of a non-array event.

Mutation check by reading (the run was denied to the fix pass). Each new case fails against the round 2 script:
- the six `--uninstall` failure cases: round 2 removed the root file and the link, and called the stub CLI for the plugin enabled in the checkout, before touching settings.json, so the "leaving ..." and "no claude CLI call" assertions fail; the messages "could not build the rewrite" and "failed to write" do not exist there;
- (q): round 2 classified neither the spaced retired command nor the spaced marked one, and `--force` dropped the marker and kept the command;
- (r): round 2 tested presence anywhere, so `--check` exits 0;
- (s): round 2 had no shape check, so install exits 0;
- (i): round 2 removed an unmarked dead command on a plain install.

### Findings
- [ ] (suggestion) A dead command in an entry carrying any marker, not only its own checkout's, is attributed to the installer and removed by a plain install: `owner` returns "dead" without comparing `$k.dir` with the marker, and `remove` only asks `marked($m)`. A moved checkout's entry always has the command under the marker's own path, so requiring `$k.dir == $m` for "dead" loses nothing and keeps the rule to "an entry marked with that checkout" (adversarial) — `user_tier_install.sh:459-471`

Fix-pass choices, judged:
- `write_settings` returns 1 on a failed rename and removes its temporary file: agreed. The must-fix depends on it, and the symlinked-settings branch returned 0 after a failed `mv`, a false success of the same kind. Its failure is tested only on the plain path: the `mv` shim matches `*/.claude/settings.json`, not a dotfiles target.
- The printed removals include this checkout's retired or alias-path commands: agreed. Every command taken out of the owner's file is named, at a cost of one line per command.

Dismissed:
- Adversarial "`--check` is clean when our command sits in a mixed or marked entry that install moves to a fresh entry": converges in one run, the hook runs once either way, and a leftover marker is reported separately.
- Adversarial "the `--force` remedy also removes other checkouts' commands": `--check` reports those on lines of their own, and from the owning checkout `--force` takes nothing over.
- Adversarial "install writes the root file and the link before settings.json": either order leaves a window; `--check` reports it and a re-run converges; the backup-first order asked for in round 1 holds.
- Adversarial "`--uninstall` adds `hooks: {}` and drops empty events": predates the branch, and the key holds nothing.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 13:36 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 approved with no must-fix; all five round 2 findings are closed and each new failure test was checked by reading to fail against the round 2 script)
**After**: publish
**Decision**: publish

The host read the round 3 Local Review (Pre-Push) entry at 6cf7a38d: verdict approved, Ship recommended, one open suggestion (a dead command is attributed to the installer in an entry carrying any marker, not only its own checkout's; require the command's directory to equal the marker). That suggestion is about what a plain install may remove from the owner's settings file, so it is not left as a suggestion: its box stays open, triage raises it, and it is fixed on the pull request before the merge decision, together with a test for the symlinked-settings failed-write path the reviewer noted is untested.

## Integrated Review
**Status**: complete
**When**: 2026-11-12 13:41 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #450 at `715ae2ff`
**Sources**: 3 (Local Review (Pre-Push) round 3 @ `1e02b457` (covers `715ae2ff` via bookkeeping), Copilot @ `715ae2ff` (failed: quota), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

Copilot: failed (quota) — its review at the head says "Copilot was unable to review this pull request because the user who requested the review has insufficient remaining quota"; no inline comments. No human review requested; no conversation comments. Earlier local rounds 1 and 2 were closed by the Implementation entries and confirmed closed by round 3. CI at the time of writing: Validate Documentation, Validate Adapter Contract and ros-manifest tests pass on both runs; Lint (pre-commit) pending on both.

Both findings below were checked against the code at the head. The host's publish Checkpoint (13:36) rules that they are fixed on this pull request before the merge decision, not left as suggestions: they decide what a plain install may remove from the owner's settings file, and whether a failed write to it is reported.

### Findings
- [x] (suggestion, Local Review (Pre-Push) @ `1e02b457`) A dead command in an entry carrying any marker, not only its own checkout's, is attributed to the installer and removed by a plain install: `owner` returns "dead" without comparing `$k.dir` with the marker, and `remove` only asks `marked($m)`. A moved checkout's entry always has the command under the marker's own path, so requiring `$k.dir == $m` for "dead" loses nothing and keeps the rule to "an entry marked with that checkout" (adversarial) — `user_tier_install.sh:459-471`. Confirmed: the `else $k.class` branch of `owner` returns "dead" for any marker. Fix: attribute a dead command to the installer only when `$k.dir == $m`; one in an entry marked with another checkout is handled like an unmarked dead command (reported by `--check` and named by a plain install with the `--force` remedy, left in place; `--force` removes it), and `--check`'s two dead-command reports (around line 1364) follow the same split. Test: a dead command inside an entry marked with another checkout — a plain install keeps it and names it, `--force` removes it.
- [ ] (test gap, Local Review (Pre-Push) @ `1e02b457`, raised by the host Checkpoint) The failed write to a symlinked settings.json is untested: `write_settings` returns 1 when the `mv` onto the resolved dotfiles file fails, but the only `mv` shim matches `*/.claude/settings.json`, which the symlink branch never passes to `mv`, and the dotfiles tests cover only the success path — `.agent/scripts/tests/test_user_tier_install.sh` (around 859 and 1211-1276), `user_tier_install.sh` `write_settings`. Fix: a shim that fails the rename onto the dotfiles target; check that install and `--uninstall` exit 1 with "nothing changed", the dotfiles file and the link are unchanged, and no `.agent-workspace.<pid>` staging file or temporary file is left behind.

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-12 13:42 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the Integrated Review has two open findings, both about what the installer may do to the owner's settings file; a review with open findings is sent back for fixes, not merged past)
**After**: findings
**Decision**: address

The host read the Integrated Review entry at b85e49f5. The fix pass does the two findings as the entry words them: a dead command is the installer's only in an entry marked with its own checkout, and the failed write onto a symlinked settings file gets its test.
