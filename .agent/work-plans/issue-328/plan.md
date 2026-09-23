# Plan: Retire the Bash tool-mapping hook: it now contradicts Claude Code's auto-mode guidance

## Issue

https://github.com/rolker/agent_workspace/issues/328

## Context

`.claude/hooks/block-bash-tool-mapping.sh` blocks `cat`/`head`/`tail`/`find`/`sed`
Bash calls in favor of Read/Glob/Edit. Claude Code's own auto-mode guidance now
says the opposite: do reads and edits through the shell, and use dedicated
tools only when the shell can't do the job. The hook fires repeatedly against
an agent following that guidance.

Since the issue was filed, PR #326 (#317, ADR-0016) promoted this same hook to
the Claude Code **user tier**: it's now also listed in
`.agent/user_tier_scripts.txt`, generated into `~/.claude/settings.json` by
`user_tier_install.sh`, guarded by `registry_require_root`, and covered by
`test_user_tier_guard.sh` / `test_user_tier_install.sh`. The owner's checkpoint
decision (progress.md, 2026-09-23) is full retirement at both tiers — this plan
covers both.

The block log (`~/.claude/tool-mapping-blocks.jsonl`, this machine) was
reviewed as part of issue review: 155 entries, all routine reads —
`sed -n 'SCRIPT' <file>` (107), `cat <file>` (31), `find` for enumeration (9),
`tail <file>` (7), `head <file>` (1). Zero `sed -i` occurrences. No rule is
worth keeping; this is full retirement, not a reduction to one rule.

## Approach

1. **Post the block-log summary to the issue** — comment on #328 with the
   counts above and the "no rule worth keeping" conclusion, before touching
   any code. (Carries forward the issue-review recommendation that this step
   not get skipped once implementation starts.)

2. **Delete the hook and its test**:
   - `git rm .claude/hooks/block-bash-tool-mapping.sh`
   - `git rm .agent/scripts/tests/test_block_bash_tool_mapping.sh` (dedicated
     unit test for the hook; `run_script_tests.sh` discovers `test_*.sh` by
     glob, so no separate registration to remove)

3. **Remove the workspace-tier registration** in `.claude/settings.json`:
   delete the `block-bash-tool-mapping.sh` `PreToolUse` entry (lines ~132-136),
   keeping the `log-tool-use.sh` entry.

4. **Remove the user-tier registration**:
   - `.agent/user_tier_scripts.txt` — delete the
     `.claude/hooks/block-bash-tool-mapping.sh` line (keep `log-tool-use.sh`)
   - `.agent/scripts/user_tier_install.sh` — drop the `$block` variable and
     its entry from `PRE_HOOKS_JSON` (lines ~612-621, keep `$log`); drop the
     `.claude/hooks/block-bash-tool-mapping.sh` line from `hook_commands()`
     (line 180); update the file-header comment (lines 16-19) describing "Two
     PreToolUse entries ... Both carry the registry_require_root guard" to
     describe the single remaining one.
   - Note for the PR description: re-running `user_tier_install.sh` on an
     already-installed machine replaces the whole tagged hooks block on the
     next run (install mode is a full replace, not an incremental merge —
     verified at lines 638-639: every `PreToolUse` entry tagged with this
     checkout is dropped, then the new `$pre` is appended), so the stale
     `~/.claude/settings.json` entry clears automatically once the installer
     is re-run — no separate uninstall-of-one-entry step. `--check` does
     **not** report this drift today (see step 5) — until step 5 lands,
     `--check` prints "installed and current" on a machine that still has
     the stale entry.

5. **Add a `--check` drift case for retired hook entries** in
   `.agent/scripts/user_tier_install.sh`. Today's `--check` (lines 458-499)
   only reports (a) expected commands that are missing (the
   `hook_commands`/`$SESSION_HOOK_LINK` loop, lines 461-469), (b) entries
   tagged for a different checkout (lines 471-482), and (c) tagged entries
   naming a path outside this checkout (lines 484-499). None of these fire
   for a tagged entry that still points inside this checkout but is no
   longer produced by the current `hook_commands()` — exactly the state
   this PR creates on this machine (`~/.claude/settings.json` currently
   names `/home/roland/agent_workspace/.claude/hooks/block-bash-tool-mapping.sh`).
   Add a fourth check: compute the set of commands the current generation
   produces (`hook_commands; printf '%s\n' "$SESSION_HOOK_LINK"`), diff it
   against the tagged, in-checkout commands actually present in
   `settings.json`, and `note` any tagged in-checkout command that isn't in
   the current set — e.g. "hook entry tagged as ours is no longer generated:
   <cmd> (re-run the installer)". Add drift case (f) to
   `.agent/scripts/tests/test_user_tier_install.sh`: inject a tagged
   `PreToolUse` entry for a retired hook path under `$WSC`, assert `--check`
   exits 1 with that note, re-run the installer, assert the entry is gone
   and `--check` is clean.

6. **Update the two user-tier test files** to stop asserting coverage for the
   block hook:
   - `.agent/scripts/tests/test_user_tier_guard.sh` — remove the `BLOCK_HOOK`
     variable and its four assertions (unregistered-repo silence, in-checkout
     block, in-registered-root block, fail-closed-when-registry-missing);
     keep the parallel `LOG_HOOK` assertions. Remove the
     `cp .../block-bash-tool-mapping.sh "$BROKEN/..."` fixture setup line for
     the hook that no longer exists.
   - `.agent/scripts/tests/test_user_tier_install.sh` — line 110's
     `for h in log-tool-use.sh block-bash-tool-mapping.sh` loop becomes a
     single assertion for `log-tool-use.sh` (or drop the loop and assert the
     one entry directly).

7. **CLAUDE.md** (Ask-First — instruction file; owner approved the retirement
   in principle on 2026-09-22, and separately APPROVED this exact wording on
   2026-09-23 — see the plan-review checkpoint): delete the
   entire `## Tool Mapping` section — heading, the instead-of/use table, the
   "These are auto-approved..." line, and the "**Enforced by hook**"
   paragraph. Nothing salvageable is left once the enforcement claim and the
   table it introduces are both gone, and the general guidance moves to
   AGENTS.md's "Tool Usage" section (step 8) so it isn't duplicated. The `##
   References` list and everything else in CLAUDE.md is untouched — this
   session is also driving #334 (docs reorg) against that same list in a
   separate hunk. No real conflict: #334 moves `docs/ROADMAP.md` to
   `docs/roadmap.md` with `git mv` and no content change, so git's rename
   detection carries this PR's ROADMAP.md edit (step 10) across the rename
   regardless of merge order; the CLAUDE.md edits are in separate hunks
   (`## Tool Mapping` vs `## References`). Whichever of #328/#334 merges
   second should merge `main` (not rebase) and then confirm
   `git grep -n block-bash-tool-mapping docs/` is empty; #334's own plan
   currently mis-describes this PR's AGENTS.md edit as "one script-table
   row" and should be corrected to "the Tool Usage bullet" when that branch
   next merges main.

8. **AGENTS.md "Tool Usage"** (also Ask-First; owner APPROVED this exact
   wording on 2026-09-23 — see the plan-review checkpoint) — reword away
   from the enforcement-shaped framing to match auto-mode guidance and
   ADR-0004 (don't claim enforcement that no longer exists). Note for the
   PR description: this heading is one of the sections
   `.claude/hooks/session_start_project_layer.sh`'s `WORKSPACE_SECTIONS`
   (line 68) injects verbatim into every registered project session, so the
   reword also changes what project sessions are told. The heading itself
   is unchanged, so `test_session_start_layer.sh` still passes — only the
   bullet body changes.

   Replace:
   > **Prefer dedicated tools over shell equivalents** — When your framework
   > provides built-in tools for file search, content search, file reading, or
   > file editing, use those instead of shell commands (`ls`, `find`, `grep`,
   > `cat`, `sed`, etc.). Dedicated tools provide better audit trails and
   > typically require fewer permission prompts.

   With:
   > **Prefer dedicated tools where they fit** — shell commands (`cat`,
   > `grep`, `sed`, `find`, etc.) are fine for reads and simple edits; reach
   > for a framework's dedicated search/read/edit tool instead when a shell
   > command would be fragile or ambiguous — exact or multi-line
   > replacements, or `sed`/`awk` flags that differ between GNU and
   > BSD/macOS. This is a preference the agent applies by judgment, not an
   > enforced rule.

   Leave the "Chain shell commands only when state depends on it" bullet as
   is — it doesn't presume the hook.

9. **Revise ADR-0016 §6 in place** — `docs/decisions/0016-session-roots-and-the-user-tier.md`
   is Provisional (line 5), so revising it is permitted (ADR-0008's
   immutability applies to Accepted ADRs, not Provisional ones). §6 (lines
   103, 105-108) currently reads "for the two hooks, stay silent" and "The
   tool-mapping and tool-use-logging hooks are promoted under this rule
   (owner decision, 2026-09-22), so project sessions keep the
   Bash-to-dedicated-tools steering and the tool-use log, and an
   unregistered repo gets neither." Both sentences are false once this PR
   merges. Reword to: only `log-tool-use.sh` is promoted under this rule;
   the tool-mapping hook was promoted alongside it on 2026-09-22 but was
   retired by #328 on 2026-09-23, so project sessions now keep only the
   tool-use log, and an unregistered repo gets neither. "For the two hooks,
   stay silent" (line 103) becomes "for the hook, stay silent" (singular).
   The Context mention at line 26 ("no tool-mapping hook") describes the
   pre-promotion state and is left as-is.

10. **`.agent/knowledge/`** — no normative doc there presumes the hook (checked
   `README.md`, `skill_workflows.md`, `principles_review_guide.md`, and the
   rest; none mention tool-mapping enforcement). The hits are three
   `inspiration_*_digest.md` files (research-skill living documents recording
   what the hook did *at the time of that research pass*):
   `inspiration_harness_digest.md:152`, `inspiration_gstack_digest.md:433`,
   and `inspiration_project-codeguard_digest.md:108`
   (`inspiration_superpowers_digest.md:372`'s "tool-mapping boilerplate" is
   unrelated and stays untouched). Also `docs/ROADMAP.md`'s "Fail-closed hook
   audit" item (line 373), which names `block-bash-tool-mapping` as one of
   two examples (the other is pre-commit). Leave the inspiration digests as
   historical record — rewriting past research notes to match a later repo
   state is not this issue's job. Reword the ROADMAP line to drop the
   now-deleted hook from its example list (keep the pre-commit example; the
   fail-closed-audit idea itself still applies to remaining hooks).

11. **The block-log file itself**
   (`~/.claude/tool-mapping-blocks.jsonl`) — lives outside the repo (`$HOME`,
   untracked), written only by the hook being deleted, and read by nothing
   else in the workspace (`grep` across `Makefile`, `.agent/scripts/`, and
   `.claude/skills/` found no other reader). No repo action needed. It's
   harmless dead data once the hook is gone; leave cleanup to the owner if
   they want it, out of scope for a workspace-repo PR.

12. **Re-scope #329** — after this PR merges, re-read #329 (user-tier hooks
    fire twice): it currently targets both `log-tool-use.sh` and
    `block-bash-tool-mapping.sh`; once this issue removes the block hook from
    the user tier entirely, #329's scope narrows to `log-tool-use.sh` alone.
    Not part of this PR's diff — a follow-up comment/edit on #329 after
    merge.

13. **Post-merge: re-run the user-tier installer on this machine.** Not part
    of the PR diff, but a required action right after merge — `merge_pr.sh`
    syncs `main`, which deletes
    `/home/roland/agent_workspace/.claude/hooks/block-bash-tool-mapping.sh`
    on disk. This machine's `~/.claude/settings.json` already has a
    `PreToolUse` entry naming that exact absolute path (installed under
    #317/ADR-0016), so every Bash call in every registered-root session
    would run a missing hook command (a non-blocking hook error each time)
    until the installer is re-run. Immediately after merge: run
    `.agent/scripts/user_tier_install.sh` from the main checkout, then
    `.agent/scripts/user_tier_install.sh --check`, and confirm `--check`
    reports clean (this also exercises step 5's new drift case on real
    state, not just the test fixture).

## Files to Change

| File | Change |
|------|--------|
| `.claude/hooks/block-bash-tool-mapping.sh` | Deleted |
| `.agent/scripts/tests/test_block_bash_tool_mapping.sh` | Deleted |
| `.claude/settings.json` | Remove the hook's `PreToolUse` entry |
| `.agent/user_tier_scripts.txt` | Remove the hook's manifest line |
| `.agent/scripts/user_tier_install.sh` | Remove `$block` from `PRE_HOOKS_JSON`, drop it from `hook_commands()`, update header comment; add the `--check` drift case for tagged-but-no-longer-generated hook commands (step 5) |
| `.agent/scripts/tests/test_user_tier_guard.sh` | Remove `BLOCK_HOOK` and its 4 assertions + fixture copy |
| `.agent/scripts/tests/test_user_tier_install.sh` | Narrow the `for h in ...` loop to `log-tool-use.sh` only; add drift case (f) for the new `--check` behavior (step 5) |
| `CLAUDE.md` | Delete the `## Tool Mapping` section (heading, table, enforcement paragraph) |
| `AGENTS.md` | Reword "Tool Usage" bullet to drop the enforcement framing |
| `docs/decisions/0016-session-roots-and-the-user-tier.md` | Revise §6 in place: only `log-tool-use.sh` remains promoted, "two hooks" becomes one (Provisional, per ADR-0008) |
| `docs/ROADMAP.md` | Drop `block-bash-tool-mapping` from the fail-closed-hook-audit example list |
| GitHub issue #328 | Comment with the block-log summary (not a repo file change) |
| (post-merge, not in PR diff) `~/.claude/settings.json` on this machine | Re-run `user_tier_install.sh` + `--check` after merge (step 13) |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Both tiers (workspace + user), both test files, the two instruction files, and ADR-0016's own Decision text are updated in the same PR; a `--check` drift case and a post-merge action cover the installed-machine window so nothing is left to drift silently. |
| Enforcement over documentation (inverted here) | This is the rare direction: removing enforcement that now actively fights the tool's own guidance. The instruction-file wording is brought back in line with reality (ADR-0004) rather than left overstating what's enforced. |
| Only what's needed | The only new machinery is the `--check` drift case (step 5), added because retiring a promoted hook is a first-of-its-kind operation the installer couldn't detect before; everything else is deletion and manifest edits reusing the existing install/replace mechanism. #329's re-scope and the log file's fate are explicitly deferred, not folded in. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0004 (Enforcement hierarchy) | Yes | Removes an instruction-file claim ("Enforced by hook") that would otherwise outlive the enforcement it describes; AGENTS.md's reworded bullet states a preference, not an enforced rule. |
| ADR-0016 (Session roots / user tier) | Yes | Retiring a promoted hook gets the same care as promoting one: manifest, installer (plus its new `--check` drift case), both user-tier test files, and the ADR's own §6 Decision text are updated together (steps 4-6, 9), matching the plan-review flag. |
| ADR-0008 (ADR immutability) | Yes | ADR-0016 is Provisional, not Accepted, so revising §6 in place (step 9) is the correct move rather than a superseding ADR. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Delete the hook file | Its dedicated test (`test_block_bash_tool_mapping.sh`) | Yes — step 2 |
| Drop it from `.agent/user_tier_scripts.txt` | `user_tier_install.sh`'s `PRE_HOOKS_JSON` / `hook_commands()` | Yes — step 4 |
| Retiring a promoted hook | `--check` has no way to detect the stale entry today | Yes — step 5 (new drift case + test) |
| User-tier registration removed | `test_user_tier_guard.sh`, `test_user_tier_install.sh` | Yes — step 6 |
| CLAUDE.md loses the enforcement claim | AGENTS.md's parallel "Tool Usage" wording | Yes — step 8 |
| AGENTS.md "Tool Usage" reworded | `session_start_project_layer.sh`'s `WORKSPACE_SECTIONS` injects this section verbatim into every registered project session | Yes — noted in step 8; heading unchanged so `test_session_start_layer.sh` is unaffected |
| Hook retired from the user tier | ADR-0016 §6's Decision text, which still says two hooks are promoted | Yes — step 9 |
| Hook deleted | `docs/ROADMAP.md`'s fail-closed-audit item that names it | Yes — step 10 |
| Hook deleted | `.agent/knowledge/inspiration_*_digest.md` mentions (three: harness, gstack, project-codeguard) | No — historical record, left as-is |
| Hook deleted | `~/.claude/tool-mapping-blocks.jsonl` (the log file) | No — out-of-repo, unread elsewhere, owner's call |
| This merges | #329's scope (currently covers both hooks) | No — explicit post-merge follow-up (step 12), not this PR's diff |
| This merges to `main` | This machine's installed `~/.claude/settings.json` entry, which names the file `main` sync just deleted | Yes — step 13, post-merge action (not part of the PR diff) |
| #328 and #334 both touch CLAUDE.md/AGENTS.md/ROADMAP.md | Whichever merges second merges `main` and checks `git grep block-bash-tool-mapping docs/` is empty | Yes — noted in step 7 |

## Open Questions

None — the owner's checkpoint decisions (progress.md, 2026-09-23) resolve
scope (full retirement, both tiers), the block-log disposition (no rule
kept), the #329 handling (re-scope after merge), the plan-review must-fixes
(`--check` drift case, post-merge re-install, ADR-0016 §6 revision), and the
exact instruction-file wording for CLAUDE.md and AGENTS.md (both approved
verbatim).

## Estimated Scope

Single PR. Mechanical deletions/manifest edits, one new `--check` drift case
plus its test, three short instruction/decision-record rewords (CLAUDE.md,
AGENTS.md, ADR-0016 §6); no new scripts, only a small addition to one
existing installer and trims to three existing test/doc files.
