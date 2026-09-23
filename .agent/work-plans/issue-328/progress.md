---
issue: 328
---

# Issue #328 — Retire the Bash tool-mapping hook: it now contradicts Claude Code's auto-mode guidance

## Issue Review
**Status**: complete
**When**: 2026-09-23 13:08 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #328

### Scope Assessment

**Well-scoped?** Partially. The workspace-tier retirement (delete the hook, its `.claude/settings*.json` registration, the CLAUDE.md paragraph, reword AGENTS.md) is a single, tightly-scoped PR. But the issue predates PR #326 (#317, the session-layer/user-tier work, ADR-0016), which merged the day after this issue was filed (2026-09-23) and promoted this same hook to the user tier. Today the hook is also:
- listed in `.agent/user_tier_scripts.txt`
- registered by `user_tier_install.sh` as an absolute-path `PreToolUse` entry in `~/.claude/settings.json`
- guarded by `registry_require_root` (line 84 of the hook)
- covered by `test_user_tier_guard.sh` and `test_user_tier_install.sh`

None of this is in the issue's "What" list. If the PR only deletes the workspace-tier registration, an already-installed machine keeps a `~/.claude/settings.json` entry pointing at a file that no longer exists — a broken PreToolUse hook on every session, everywhere, not just in this workspace.

The removal mechanism already exists and doesn't need new machinery: `user_tier_install.sh`'s install mode replaces the *entire* tagged hooks block each run (it says so at line ~609: "replacing any previous generation of ours ... that is what makes this idempotent"). So dropping the hook from `.agent/user_tier_scripts.txt` and the `PRE_HOOKS_JSON` construction, then re-running the installer, removes the stale `~/.claude/settings.json` entry automatically — no separate uninstall-of-one-entry step is needed. `--check` will report the drift in the meantime (old command string / stale generation) so a machine that hasn't re-installed yet gets a visible signal.

**Right repo?** Yes — workspace infra only.

**Dependencies**:
- **#329** (user-tier hooks fire twice) targets *both* `log-tool-use.sh` and `block-bash-tool-mapping.sh`. Once this issue removes the block hook from the user tier entirely, #329's scope narrows to `log-tool-use.sh` alone. #329 isn't blocked by this issue (its issue body says so explicitly), but it should be re-read after this merges — its acceptance criteria and shared-helper design currently assume two hooks need the dedup guard.
- **#338** (retire CLAUDE.md) already sequences itself after this issue in its own Gate section — no conflict, just confirming it's consistent.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| A change includes its consequences | Action needed | Issue's step 2 lists only the workspace-tier registration (`.claude/settings*.json`). It omits the user-tier consequences introduced by ADR-0016/#317 after this issue was filed: `.agent/user_tier_scripts.txt`, the `PRE_HOOKS_JSON` block in `user_tier_install.sh`, and the two test files that cover the hook there. |
| Enforcement over documentation | OK | Retiring the enforcement mechanism is the explicit, owner-approved point of this issue — not a violation. |
| Capture decisions, not just implementations | OK | Owner decision already cited (PR #324 walkthrough, item 4). |
| Only what's needed | OK | No scope creep once the user-tier piece is added; it's the same rename/delete pattern, not new machinery. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0004 (Enforcement hierarchy) | Yes | Handled — the issue already plans to remove the "Enforced by hook" claim from CLAUDE.md so docs don't overstate enforcement that no longer exists. |
| ADR-0016 (Session roots and the user tier) | Yes, but not addressed | "Promoting a script or hook" to the user tier triggers this ADR per the review guide; the reverse (retiring one already promoted) should get the same treatment — manifest, installer, and both user-tier test files updated together, not left to drift. |

### Consequences

- Add to scope: remove `.claude/hooks/block-bash-tool-mapping.sh` from `.agent/user_tier_scripts.txt`; drop its entry from the `PRE_HOOKS_JSON` construction in `.agent/scripts/user_tier_install.sh`; update `test_user_tier_guard.sh` and `test_user_tier_install.sh` to stop asserting coverage for it.
- Note for the PR description: re-running `user_tier_install.sh` after the change clears the stale `~/.claude/settings.json` entry on any machine that already has the user tier installed (idempotent replace-on-install); `--check` shows the drift beforehand.
- Confirmed the block log supports full retirement with no kept rule: 155 entries on this machine, all routine reads — `sed -n 'SCRIPT' <file>` (107), `cat <file>` (31), `find` for file enumeration (9), `tail <file>` (7), `head <file>` (1). Zero `sed -i` occurrences, so there is no evidence for the "keep one rule" fallback the issue allows for.

### Recommendations

- Expand step 2 to cover the user-tier registration and its tests (see Consequences), not just the workspace-tier `.claude/settings*.json` entry.
- Issue's step 1 (read and summarise the block log, post to the issue) is an implementation action, not something to execute during issue review — make sure the work plan carries it as an explicit first task so it isn't skipped once implementation starts.
- After this merges, re-check #329's scope and acceptance criteria against the now-single remaining doubled hook (`log-tool-use.sh`).

### Actions
- [ ] Issue's step 2 lists only the workspace-tier registration (`.claude/settings*.json`). It omits the user-tier consequences introduced by ADR-0016/#317 after this issue was filed: `.agent/user_tier_scripts.txt`, the `PRE_HOOKS_JSON` block in `user_tier_install.sh`, and the two test files that cover the hook there.
- [ ] Expand step 2 to cover the user-tier registration and its tests (see Consequences), not just the workspace-tier `.claude/settings*.json` entry.
- [ ] Issue's step 1 (read and summarise the block log, post to the issue) is an implementation action, not something to execute during issue review — make sure the work plan carries it as an explicit first task so it isn't skipped once implementation starts.
- [ ] After this merges, re-check #329's scope and acceptance criteria against the now-single remaining doubled hook (`log-tool-use.sh`).

## Checkpoint
**Status**: complete
**When**: 2026-09-23 13:19 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed (Recommended): full retirement, workspace and user tier — plan covers the user-tier removal (.agent/user_tier_scripts.txt, user_tier_install.sh PRE_HOOKS_JSON, test_user_tier_guard.sh / test_user_tier_install.sh; re-running the installer clears an installed machine, --check shows the drift meanwhile), the block-log summary as an explicit first task (this machine: 155 blocks, all routine reads — sed -n 107, cat 31, find 9, tail 7, head 1; zero sed -i, so no rule is kept), and a note to re-scope #329 to log-tool-use.sh after merge.
