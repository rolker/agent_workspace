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

## Plan Authored
**Status**: complete
**When**: 2026-09-23 13:25 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-328/plan.md` at `f4f42de`

Full retirement of the tool-mapping hook at both the workspace and user tier (hook file, its dedicated test, both settings.json/manifest registrations, and the two user-tier test files), a minimal CLAUDE.md diff deleting the whole "Tool Mapping" section, an AGENTS.md "Tool Usage" reword to drop the enforcement claim (ADR-0004), a ROADMAP.md example-list trim, the block-log summary as an explicit first task, and a deferred note to re-scope #329 after merge.

## Plan Review
**Status**: complete
**When**: 2026-09-23 13:30 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #328 — Retire the Bash tool-mapping hook: it now contradicts Claude Code's auto-mode guidance
**Plan**: `.agent/work-plans/issue-328/plan.md` at `f4f42de`
**Branch**: `feature/issue-328`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Single PR; deletions plus manifest/installer/test trims. |
| Issue alignment | Good | Covers both tiers per the owner checkpoint; block-log summary is task 1; #329 re-scope deferred as agreed. |
| File targeting | Needs work | Repo-wide grep (`block-bash-tool-mapping`, `tool-mapping`, `tool-mapping-blocks`, `Enforced by hook`) finds every listed file plus one missed normative doc: `docs/decisions/0016-session-roots-and-the-user-tier.md` (§6, lines 103 and 105-108). No hits in Makefile, `.github/`, `.pre-commit-config.yaml`, CODEX.md, onboarding/copilot/gemini instructions, templates or skills; `run_script_tests.sh` discovers suites by glob and names no suite, so deleting the test needs no runner edit. |
| Consequences | Concern | The user-tier migration claim is half wrong (finding 1) and the live-machine window after merge is not planned (finding 2). |
| Principle alignment | Needs work | "A change includes its consequences": ADR-0016 and the `--check` gap. Otherwise minimal. |
| ADR compliance | Needs work | ADR-0004 handled for CLAUDE.md/AGENTS.md; ADR-0016's own Decision text still records the promotion (finding 3). ADR-0016 is Provisional, so revising it in place is permitted (ADR-0008's immutability applies to accepted ADRs). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences]** (must-fix) — The plan's claim that `--check` reports the retired entry as drift is false. Verified in `user_tier_install.sh`: install mode does clear it (lines 638-639 drop every `PreToolUse` entry tagged with this checkout, then append the new `$pre`, so re-running the installer is enough — confirmed). But `--check` (lines 458-498) only reports (a) wanted commands that are missing, (b) entries tagged by another checkout, and (c) tagged commands outside `$WS_ROOT/`. A tagged entry for `$WS_ROOT/.claude/hooks/block-bash-tool-mapping.sh` is none of those, and hooks are excluded from allow-rules (`promoted_scripts` line 132), so the orphan-rule check does not fire either. On a machine that has not re-installed, `--check` prints "installed and current" while settings.json runs a hook whose file is gone. This machine is in that state now: `~/.claude/settings.json` lists `/home/roland/agent_workspace/.claude/hooks/block-bash-tool-mapping.sh`. Fix: add a `--check` case in `user_tier_install.sh` that flags any command tagged as ours that the current generation (`hook_commands` plus `$SESSION_HOOK_LINK`) no longer produces, e.g. "hook entry tagged as ours is no longer generated: <cmd> (re-run the installer)". Add drift case (f) to `test_user_tier_install.sh`: inject a tagged `PreToolUse` entry for a retired hook path under `$WSC`, assert `--check` exits 1 with that note, re-run the installer, assert the entry is gone and `--check` is clean. The test is warranted: this is the first time a hook has left the generation, and without the check the migration is silent. Correct the plan's step 4 note to match.
2. **[Consequences]** (must-fix) — Plan a post-merge step on this machine, not just a line in the PR description. `merge_pr.sh` syncs main, and that deletes `/home/roland/agent_workspace/.claude/hooks/block-bash-tool-mapping.sh`, which the installed user-tier entry names by absolute path. Every Bash call in every registered-root session then runs a missing hook command (a non-blocking hook error on each call) until someone re-runs the installer. Add step 11: straight after merge, run `.agent/scripts/user_tier_install.sh` from the main checkout and then `--check`, and confirm it is clean.
3. **[File targeting / ADR compliance]** (must-fix) — `docs/decisions/0016-session-roots-and-the-user-tier.md` §6 still says "The tool-mapping and tool-use-logging hooks are promoted under this rule (owner decision, 2026-09-22), so project sessions keep the Bash-to-dedicated-tools steering…" (lines 105-108) and "for the two hooks, stay silent" (line 103). After this PR both are false. ADR-0016 is Provisional ("revise here if it does not"), so revise §6 in place: only `log-tool-use.sh` is promoted, and the tool-mapping hook was retired by #328 on 2026-09-23. Add the file to Files to Change and the Consequences table. The Context mention at line 26 describes the old state and can stay.
4. **[File targeting]** (suggestion) — Step 8 says "two" inspiration digests mention the hook. There are three: `inspiration_harness_digest.md:152`, `inspiration_gstack_digest.md:433` and `inspiration_project-codeguard_digest.md:108`. (`inspiration_superpowers_digest.md:372` is an unrelated "tool-mapping boilerplate".) Leaving them as historical record is still right; correct the count.
5. **[Consequences]** (suggestion) — AGENTS.md `## Tool Usage` is one of the sections `session_start_project_layer.sh` injects into project sessions (`WORKSPACE_SECTIONS`, line 68), so the reword also changes what every registered-project session is told. The heading is kept, so `test_session_start_layer.sh` still passes. Add a Consequences row saying so, so the owner approves the text knowing where it lands.
6. **[Sequencing with #334]** (suggestion) — No real conflict. #334 moves `docs/ROADMAP.md` → `docs/roadmap.md` with `git mv` and no content change (its plan, step 1 / Files table), so git's rename detection (ort, 100% similarity) carries #328's one-line edit at ROADMAP line 373 across the rename whichever branch merges second. The CLAUDE.md edits are in separate hunks (`## Tool Mapping`, lines 15-43, against `## References`, line 55+). #334's plan wrongly says #328 edits "one AGENTS.md script-table row"; it edits the `## Tool Usage` bullet, also a separate hunk. The second branch should merge main, not rebase, and check afterwards that `git grep -n block-bash-tool-mapping docs/` is empty. Correct #334's description of #328 when that branch next merges main.
7. **[Ask-First]** (suggestion) — Both instruction-file edits are stated precisely enough to approve. CLAUDE.md: delete the whole `## Tool Mapping` section (heading through the "Enforced by hook" paragraph). AGENTS.md: exact before/after text is given. Neither does #338's work: CLAUDE.md is trimmed, not retired, and nothing moves out of it except the deleted section. The host should put both texts verbatim in the post-review checkpoint dialog, because the owner's earlier "proceed" approved retirement in principle, not this wording.

### Summary

The plan covers the removal completely at both tiers, and re-running the installer does clear an installed entry. It rests on a `--check` drift report that does not exist, though, and it leaves the owner's own machine with a dangling hook after merge. It also misses ADR-0016's Decision text. With those three fixed, it is ready.

### Recommended Actions

- [ ] (must-fix) Add a `--check` case to `user_tier_install.sh` for tagged hook commands the current generation no longer produces, plus drift case (f) in `test_user_tier_install.sh` (inject a retired tagged entry → `--check` exits 1 → re-install clears it → `--check` clean); correct step 4's note — `.agent/scripts/user_tier_install.sh:458-498`
- [ ] (must-fix) Add a post-merge step: re-run `user_tier_install.sh` and `--check` from the main checkout on this machine right after merge, because the installed absolute-path entry dangles once main syncs — `~/.claude/settings.json`
- [ ] (must-fix) Revise ADR-0016 §6 in place (it is Provisional): only `log-tool-use.sh` is promoted, the tool-mapping hook was retired by #328, and "two hooks" becomes one — `docs/decisions/0016-session-roots-and-the-user-tier.md:103,105-108`
- [ ] (suggestion) Correct step 8's count: three inspiration digests mention the hook (harness, gstack, project-codeguard), all left as history — `.agent/work-plans/issue-328/plan.md:110-118`
- [ ] (suggestion) Add a Consequences row: the AGENTS.md `## Tool Usage` reword is also injected into project sessions via `session_start_project_layer.sh` `WORKSPACE_SECTIONS` — `.claude/hooks/session_start_project_layer.sh:68`
- [ ] (suggestion) Sequencing with #334: rename detection carries the ROADMAP line-373 edit across #334's content-unchanged `git mv`; the second branch merges main and checks `git grep block-bash-tool-mapping docs/` is empty — `docs/ROADMAP.md:373`
- [ ] (suggestion) Put the CLAUDE.md section deletion and the AGENTS.md before/after text verbatim in the post-review checkpoint (Ask-First); the earlier "proceed" approved retirement in principle, not this wording — `CLAUDE.md:15-43`, `AGENTS.md:100-104`

## Checkpoint
**Status**: complete
**When**: 2026-09-23 13:36 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise, all 7 (Recommended): (1) user_tier_install.sh --check flags tagged hook entries the current generation no longer produces, with drift case (f) in test_user_tier_install.sh (inject retired entry -> --check exits 1 -> re-install clears it -> --check clean); (2) post-merge step on this machine: re-run user_tier_install.sh then --check from the main checkout right after merge; (3) revise ADR-0016 §6 (Provisional) in place: the hook is no longer promoted, "two hooks" -> one; suggestions: three inspiration digests mention the hook (left as history); add a Consequences row that the AGENTS.md Tool Usage text is also injected into project sessions via session_start_project_layer.sh WORKSPACE_SECTIONS; sequencing with #334 per the review (rename detection; second branch checks git grep block-bash-tool-mapping docs/ is empty); put the exact instruction-file text in the plan.

Owner APPROVED the instruction-file wording as proposed (Ask-First): AGENTS.md Tool Usage bullet becomes "**Prefer dedicated tools where they fit** — shell commands (`cat`, `grep`, `sed`, `find`, etc.) are fine for reads and simple edits; reach for a framework's dedicated search/read/edit tool instead when a shell command would be fragile or ambiguous — exact or multi-line replacements, or `sed`/`awk` flags that differ between GNU and BSD/macOS. This is a preference the agent applies by judgment, not an enforced rule." CLAUDE.md: delete the whole `## Tool Mapping` section (heading, table, "Enforced by hook" paragraph).

## Plan Authored
**Status**: complete
**When**: 2026-09-23 13:43 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-328/plan.md` at `9ad124f`

Revision addressing all seven plan-review findings: added a `--check` drift
case (plus test) for retired user-tier hook entries, a post-merge re-install
step for this machine, an in-place ADR-0016 §6 revision, corrected the
inspiration-digest count to three, added a Consequences row noting the
AGENTS.md reword is injected into project sessions, expanded the #334
sequencing note, and confirmed the owner-approved CLAUDE.md/AGENTS.md
wording is already verbatim in the plan.

## Plan Review
**Status**: complete
**When**: 2026-09-23 13:46 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: ready

**Issue**: #328 — Retire the Bash tool-mapping hook: it now contradicts Claude Code's auto-mode guidance
**Plan**: `.agent/work-plans/issue-328/plan.md` at `9ad124f`
**Branch**: `feature/issue-328`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Single PR: deletions, manifest/installer trims, one small `--check` addition plus its test, three short doc rewords. |
| Issue alignment | Good | Both tiers per the owner's proceed checkpoint; block-log summary is step 1; #329 re-scope deferred (step 12). |
| File targeting | Good | Repo-wide grep for `block-bash-tool-mapping` / `tool-mapping` outside work-plans matches the Files table exactly: hook, its test, `.claude/settings.json:134`, `user_tier_scripts.txt:42`, `user_tier_install.sh:17,180,614`, both user-tier tests, CLAUDE.md, ADR-0016:26/105, ROADMAP:373, and the three digests (left as history). No hits in Makefile, `.github/`, `.pre-commit-config.yaml`, CODEX.md. |
| Consequences | Good | The installed-machine window is covered twice: a `--check` drift case (step 5) and a post-merge re-install (step 13). Project-session injection of the AGENTS.md text and the #334 sequencing are both recorded. |
| Principle alignment | Good | The only new machinery is the drift case, justified as the first hook ever to leave the generation. |
| ADR compliance | Good | ADR-0004: the enforcement claim goes. ADR-0016 is **Provisional** (Status, line 5), and ADR-0008's rule narrows immutability for *Accepted* ADRs only, so the in-place revision of §6 is correct. One minor wording spot in §3 remains (finding 1). |
| ROS conventions | N/A | Workspace plan. |

### Prior findings (round 1, 5a43e55) — resolution

1. `--check` drift case (must-fix): **resolved.** Step 5 now states the gap correctly and proposes the check. I read the source (`user_tier_install.sh:458-499`). Checks (a), (b) and (c) do not fire for a `$TAG`-tagged, in-checkout command that `hook_commands()` no longer emits. The proposed case is sound and will not false-positive, for three reasons:
   - It selects only entries whose `_agent_workspace == $TAG`, and `$TAG` is `$WS_ROOT` (line 65). The user's own hooks carry no marker, so they are excluded.
   - Another checkout's entries carry a different tag, so they are excluded too; check (b) already reports those.
   - Restricting it to in-checkout commands avoids double-reporting with check (c), and it also skips `$SESSION_HOOK_LINK`, which is in the wanted set anyway.
   Drift case (f) fits the existing (a)-(e) sequence in `test_user_tier_install.sh:164-205`. For the re-install half to hold, the injected entry must carry `_agent_workspace: "$WSC"`; the plan's "tagged" wording covers this. Install line 648 then drops it.
2. Post-merge re-install on this machine (must-fix): **resolved.** Step 13 covers it, as does the Consequences row.
3. ADR-0016 §6 in-place revision (must-fix): **resolved.** Step 9 rewords lines 103 and 105-108. Its legitimacy is verified: the ADR is Provisional, and ADR-0008 covers Accepted ADRs.
4. Three inspiration digests (suggestion): **resolved.** Step 10 names harness:152, gstack:433 and project-codeguard:108, and excludes superpowers:372. Verified by grep.
5. `WORKSPACE_SECTIONS` injection row (suggestion): **resolved.** It is noted in step 8 and in the Consequences table.
6. Sequencing with #334 (suggestion): **resolved.** Step 7 covers merge-not-rebase, the `git grep` check, and the correction to #334's plan.
7. Ask-First wording (suggestion): **resolved.** The AGENTS.md replacement text in step 8 matches the owner-approved text in the 13:36 checkpoint word for word. The CLAUDE.md action (delete the whole `## Tool Mapping` section) also matches. Not re-litigated.

### Findings

1. **[ADR compliance]** (suggestion): ADR-0016 §3, line 67, says "`~/.claude` carries a `SessionStart` hook, `PreToolUse` hooks, …". After retirement only one `PreToolUse` hook remains. When revising §6, make this "a `PreToolUse` hook" in the same edit, or leave it deliberately as the generic mechanism. The plan's step 9 revises only §6 and line 26.

### Summary

All seven round-1 items are resolved against source. The new `--check` case is correct and scoped by tag, so it cannot flag the user's own hooks or another checkout's entries. The plan is ready for implementation.

### Recommended Actions

- [ ] (suggestion) Singularise "`PreToolUse` hooks" in ADR-0016 §3 alongside the §6 revision, or consciously leave it generic — `docs/decisions/0016-session-roots-and-the-user-tier.md:67`

## Checkpoint
**Status**: complete
**When**: 2026-09-23 13:50 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed + suggestion (Recommended): implement the plan at 9ad124f, plus the round-2 Plan Review suggestion — singularise "`PreToolUse` hooks" in ADR-0016 §3 (docs/decisions/0016-session-roots-and-the-user-tier.md:67) alongside the §6 revision.

## Implementation
**Status**: complete
**When**: 2026-09-23 14:07 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-328 at `b9f6ded`

- Block-log summary posted on #328 (https://github.com/rolker/agent_workspace/issues/328#issuecomment-5800035609). Re-read today: 163 log lines, not 155 — the 8 added since the issue review are all `sed -n` reads (sed -n 115, cat 31, find 9, tail 7, head 1; zero `sed -i`). 24 events are logged twice by the user-tier double-fire (#329), so 139 distinct blocked calls.
- `1381ac6`: `user_tier_install.sh --check` reports a hook entry tagged with this checkout, pointing inside it, that the current generation no longer produces ("hook entry tagged as ours is no longer generated: <cmd> (re-run the installer)"). Drift case (f) added to `test_user_tier_install.sh`: inject, then `--check` exits 1, re-install clears it, `--check` is clean. Mutation proof on a scratch copy: with the new check removed, case (f) fails (72 pass, 1 fail; `--check` said "installed and current").
- `1d3cf19`: hook retired from the user tier (`.agent/user_tier_scripts.txt`, installer `hook_commands()`/`PRE_HOOKS_JSON`/header). The guard test loses the four block-hook assertions and the fixture copy. The install test checks only log-tool-use.sh.
- `599a10f`: deleted the hook, its unit test, and its `.claude/settings.json` PreToolUse entry. The install test's retired-hook check is an exact-set assertion: the tagged PreToolUse entry must be `[log-tool-use.sh]`. That way the deleted file is not named in the repo.
- `c5ba1b9`: CLAUDE.md "Tool Mapping" section deleted, and AGENTS.md "Tool Usage" bullet replaced, both with the owner-approved wording, verbatim.
- `b9f6ded`: ADR-0016 §6 revised in place (only the tool-use-logging hook is promoted; the tool-mapping hook was retired by #328), "two hooks" became "the hook", and §3 "`PreToolUse` hooks" became "a `PreToolUse` hook". The ROADMAP fail-closed-audit item drops the deleted hook from its example list.
- Verified: `run_script_tests.sh` passed all 26 suites. `git grep -n block-bash-tool-mapping` outside work plans returns only the gstack and project-codeguard inspiration digests (the harness digest says "tool-mapping" without the file name). All three are left as history.
- Not done (host, post-merge): re-run `user_tier_install.sh` and then `--check` from the main checkout. The installer was never run against the real ~/.claude.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-23 14:12 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-328 at `ea61148`
**Base**: main
**Depth**: Deep (reason: 200+ changed lines (+592 -773); AGENTS.md/CLAUDE.md governance files)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 1 | **Ship**: recommended — no must-fix findings

Verified: test_user_tier_install (73/0), test_user_tier_guard (42/0), test_session_start_layer (42/0); shellcheck --severity=warning clean on the three changed scripts; .claude/settings.json valid JSON. AGENTS.md Tool Usage bullet matches the owner-approved checkpoint text word for word; CLAUDE.md deletes the whole `## Tool Mapping` section and nothing else. New --check case filters by `_agent_workspace == $TAG` and `startswith("$WS_ROOT/")`, so untagged user hooks, other checkouts' entries, and the SessionStart symlink entry cannot false-positive; case (f) fails without it (confirmed independently). No remaining dependents of the deleted hook or its test (run_script_tests.sh globs test_*.sh; Makefile, CI, pre-commit, skills clean); only the three inspiration digests mention it, left as history per plan. ADR-0016 is Provisional, so the in-place §3/§6 revision is consistent with ADR-0008 (which narrows immutability for Accepted ADRs).

Deviation (exact-set "retired hook not written" check in 599a10f instead of naming the hook): accepted — strictly stronger than a by-name negative (catches any extra tagged PreToolUse command) and keeps the deleted filename out of the repo; a future promotion must update it deliberately, which is the desired friction.

Cross-model: codex — no issues found; gemini — failed (headless mode auto-denied a ViewFile tool call, empty response).

### Findings
- [ ] No issues found. LGTM.
