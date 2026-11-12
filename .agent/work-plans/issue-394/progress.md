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
