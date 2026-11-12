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
