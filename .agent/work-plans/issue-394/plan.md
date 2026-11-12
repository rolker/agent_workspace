# Plan: user_tier_install.sh: claude plugin commands strip the hook markers, so --check reports drift and a re-run duplicates the hooks

## Issue

https://github.com/rolker/agent_workspace/issues/394

## Context

`claude plugin ...` commands rewrite `~/.claude/settings.json` and drop the
`_agent_workspace` marker that `user_tier_install.sh` puts on each hook entry
(written at lines 1310-1321). The installer finds its own entries only through
that marker: `--check` (lines 1052-1115), the re-run and `--force` (lines
1343-1344) and `--uninstall` (lines 989-993). After any CLI call, `--check`
reports drift and a re-run adds a second copy of both hooks. Install also
rewrites the file on every run (and takes a backup first, line 1281), writing
jq's key order instead of the CLI's, so a re-run churns the file.

This is "pull request A" of issue 446's plan (revision at commit 8e9e97c1, two
plan reviews answered). It is built here, on issue 394's own worktree and
timeline, and merges before issue 446's second pull request (pull request B,
which enables the plugin at user scope and relies on the CLI rewriting
`settings.json`). The issue body's line "Fix before or inside #332 PR 2" is
stale: #332 is closed and #446 is its successor. The pull request says
"Closes #394" and "Part of #446".

## Approach

All line numbers are in `.agent/scripts/user_tier_install.sh` as on this branch.

1. **Decide "ours" by command path.** Add one helper (beside `hook_commands`,
   line 276) answering "is this hook command ours": it is `SESSION_HOOK_LINK`,
   or any path under `$WS_ROOT/.claude/hooks/`. That covers `log-tool-use.sh`
   and retired hooks (#328). An entry is ours when any of its
   `.hooks[].command` is ours. Another checkout's entry is a command of the
   form `<dir>/.claude/hooks/<file>` where `<dir>` is not `$WS_ROOT` or
   `$WS_PHYS` (line 114) and `<dir>/.agent/user_tier_scripts.txt` exists, the
   same test `foreign_skill_link` (line 445) uses. A same-named hook in a
   repository without that file is not ours and not foreign: left alone.
2. **Keep reading the marker, stop writing it.** Where an entry carries
   `_agent_workspace`, the existing reads stay: the "another workspace
   checkout" check (lines 1066-1076), the "points outside this checkout" check
   (lines 1078-1093) and the `--force` removal of every marker-carrying entry
   (lines 1343-1344). That is what still attributes an entry whose checkout was
   moved or deleted (a dead command path, which the path rule cannot attribute:
   no `user_tier_scripts.txt` beside it). Remove `_agent_workspace` from
   `PRE_HOOKS_JSON` and `SESSION_HOOKS_JSON` (lines 1308-1321).
3. **Switch each consumer to the rule in step 1, marked or not.**
   - `--check` "missing hook entry" (lines 1052-1064): look for the command in
     any entry, not only tagged ones.
   - `--check` retired hooks (lines 1095-1115): a command under
     `$WS_ROOT/.claude/hooks/` (not `$WS_ROOT/`) that is not in the wanted
     list, marked or not. Update the message wording ("tagged as ours").
   - `--check` another checkout: add unmarked entries recognised as foreign by
     step 1 to the existing "another workspace checkout" note.
   - Install's drop-the-previous-generation jq (lines 1325-1346): drop entries
     that are ours by step 1 or carry this checkout's marker; under `--force`
     also every marker-carrying entry and every entry foreign by step 1. The
     foreign test needs the filesystem, so compute the foreign directories in
     bash first (list the distinct `<dir>` from the current settings, test each
     for `.agent/user_tier_scripts.txt`) and pass them to jq with `--argjson`.
     A re-run over unmarked entries therefore replaces them and adds no copy.
   - `--uninstall` (lines 984-996): remove entries tagged with this checkout
     and entries ours by step 1.
4. **Skip a write that changes nothing.** In the install merge (line 1325
   onward), build the merged JSON into a variable instead of piping straight to
   `write_settings`. Compare `jq -S .` of it with `jq -S .` of the current file
   (the file absent counts as `{}`). Equal: print a line saying settings.json
   is already current and do not call `write_settings` (so key order from the
   CLI is untouched). Different: `backup_settings`, then `write_settings`.
   Move the `backup_settings` call at line 1281 to just before that write; the
   `require_parseable_settings` at line 1223 stays first. The "merged hook
   entries ..." echo at line 1348 becomes conditional. The `--uninstall`
   `backup_settings` (line 987) is unchanged.
5. **`.gitignore`**: add `.claude/settings.local.json` (after line 35,
   `.claude/*.lock`, with a one-line comment). Absent today (checked).
6. **Reword the header comment** at lines 62-64 ("Every entry this script
   writes ... is tagged ...") to say entries are recognised by command path,
   the marker is still read where present and no longer written. Check the
   `--uninstall` line in the mode list (lines 80-82: "entry tagged with this
   checkout") the same way.
7. **Text that states the tagging, same change (ADR-0017):**
   `docs/design.md` line 219 ("Everything it writes is tagged with the
   checkout") and `docs/decisions/0016-session-roots-and-the-user-tier.md`
   lines 207-210 ("Every settings entry ... is tagged"). Reword both to the
   path rule. `.agent/knowledge/script_reference.md` has no entry for
   `user_tier_install.sh` and no marker description (grep for `user_tier` and
   `_agent_workspace`: no match), so nothing to update there.

## Tests

`.agent/scripts/tests/test_user_tier_install.sh` already runs on a scratch HOME
(`HOMEDIR`, `run`, a stub CLI at line 55 that edits `settings.local.json`).
Add a second stub, `claude-rewrite`, that on every call rewrites
`$HOME/.claude/settings.json` the way the real CLI does: deletes every
`_agent_workspace` key and re-emits the keys in reversed order. The new cases
call it directly between installer runs. No test names a real project.

- install, run the rewriting stub, `--check` exits 0, a second install leaves
  `settings.json` byte-identical (`cmp`) and creates no new backup file;
  PreToolUse and SessionStart each still have one ours entry.
- an unmarked retired hook (`$WSC/.claude/hooks/zz-retired-hook.sh`) is
  reported by `--check` and dropped by install (the case at lines 295-325
  stays as the marked variant).
- a moved-or-deleted checkout: a marked entry whose command is under a
  directory that does not exist, with the marker kept (rewriting stub not
  applied): `--check` reports it, `--force` removes it. (Once the CLI has
  stripped that marker nothing can attribute it: say so in a test comment.)
- another checkout, unmarked: command under a scratch `<dir>/.claude/hooks/`
  with `<dir>/.agent/user_tier_scripts.txt` present: `--check` reports it,
  `--force` removes it, plain install leaves it. A same-named hook under a
  scratch directory without that file is never reported and never removed.
- `--uninstall` after the rewriting stub removes the entries.
- Existing cases that assume the marker is written or that install always
  writes, to update:
  - line 197-203 (tagged PreToolUse carries only `log-tool-use.sh`; every hook
    tagged): assert by command path, and that no entry carries the marker;
  - lines 253, 260-267, 309 (the marked-variant drift cases) keep working;
    keep them as the marker-still-read cases;
  - line 342 (uninstall leaves no tagged entry) and line 454 (`--force` leaves
    nothing tagged with the old checkout): assert by command path as well;
  - line 389 (backup before rewrite) and line 569 (seven installs leave exactly
    five backups): a no-op install now writes no backup, so change the
    settings between runs (drop an allow-rule) so each run does write;
  - line 643 (the dotfiles file "received the marker entries") and the inode
    check after it: assert on the command paths, and make the install a real
    change first so the rename still happens.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/user_tier_install.sh` | Steps 1-4 and 6 |
| `.agent/scripts/tests/test_user_tier_install.sh` | Tests above |
| `.gitignore` | `.claude/settings.local.json` |
| `docs/design.md`, `docs/decisions/0016-session-roots-and-the-user-tier.md` | Reword the tagging sentences (step 7) |

## Prior Art

Nothing new is built. `foreign_skill_link` (line 445) is the model for
recognising another checkout; `jq -S` comparison is the standard way to compare
JSON ignoring key order. Rejected: reporting any hook under a `.claude/hooks/`
directory missing on disk as drift (a heuristic that would flag the user's own
dead hooks); keeping the marker as the only recogniser (the bug).

## Serves

Quality of the work and Easy to use -- `docs/design.md#sessions-and-roots`

## Design Picture

No change to how the parts fit. It restores what ADR-0016 and the script
header already promise (`--check` reports real drift, install is idempotent);
the two sentences naming the tag are reworded (step 7).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Stub CLI strip-and-reorder, byte-identical re-run, moved checkout, unrelated same-named hook |
| Verify before claiming | Line numbers checked against this branch; script_reference.md grepped |
| Only what's needed | Every step traces to the issue, the review's four actions, or issue 446's plan A |
| Keep one current design | Header comment, design.md and ADR-0016 reworded in the same change |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0016 | Yes | Optional tier and `--check` exit 0 when not installed kept; tagging paragraph reworded |
| ADR-0017 | Yes | Design text reworded in this change |
| ADR-0018 | Watch | It is why the CLI rewrites the file; no change |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Marker no longer written | Header comment, design.md line 219, ADR-0016 lines 207-210 | Yes |
| Install may skip the write | Tests at 389, 569, 616-680 | Yes |
| `.claude/hooks/` path rule | Marked-variant tests stay green | Yes |

## Open Questions

None for the owner. Listed for veto: an entry is ours when any of its commands
is (an entry mixing ours with a user's own command is dropped whole, as a
marked one is today).

## Estimated Scope

Single pull request: one script, its test, `.gitignore`, two text edits.
