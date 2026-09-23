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
     next run (install mode is a full replace, not an incremental merge), so
     the stale `~/.claude/settings.json` entry clears automatically — no
     separate uninstall-of-one-entry step. `--check` reports the drift (a
     `PreToolUse` entry tagged as ours that the current manifest no longer
     generates) on a machine that hasn't re-installed yet.

5. **Update the two user-tier test files** to stop asserting coverage for the
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

6. **CLAUDE.md** (Ask-First — instruction file; owner approved the retirement
   in principle on 2026-09-22, this is the exact diff for review): delete the
   entire `## Tool Mapping` section — heading, the instead-of/use table, the
   "These are auto-approved..." line, and the "**Enforced by hook**"
   paragraph. Nothing salvageable is left once the enforcement claim and the
   table it introduces are both gone, and the general guidance moves to
   AGENTS.md's "Tool Usage" section (step 7) so it isn't duplicated. The `##
   References` list and everything else in CLAUDE.md is untouched — this
   session is also driving #334 (docs reorg) against that same list in a
   separate hunk; whichever branch merges second rebases past the other.

7. **AGENTS.md "Tool Usage"** (also Ask-First) — reword away from the
   enforcement-shaped framing to match auto-mode guidance and ADR-0004 (don't
   claim enforcement that no longer exists):

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

8. **`.agent/knowledge/`** — no normative doc there presumes the hook (checked
   `README.md`, `skill_workflows.md`, `principles_review_guide.md`, and the
   rest; none mention tool-mapping enforcement). The only hits are two
   `inspiration_*_digest.md` files (research-skill living documents recording
   what the hook did *at the time of that research pass*) and
   `docs/ROADMAP.md`'s "Fail-closed hook audit" item, which names
   `block-bash-tool-mapping` as one of two examples (the other is pre-commit).
   Leave the inspiration digests as historical record — rewriting past
   research notes to match a later repo state is not this issue's job.
   Reword the ROADMAP line to drop the now-deleted hook from its example list
   (keep the pre-commit example; the fail-closed-audit idea itself still
   applies to remaining hooks).

9. **The block-log file itself**
   (`~/.claude/tool-mapping-blocks.jsonl`) — lives outside the repo (`$HOME`,
   untracked), written only by the hook being deleted, and read by nothing
   else in the workspace (`grep` across `Makefile`, `.agent/scripts/`, and
   `.claude/skills/` found no other reader). No repo action needed. It's
   harmless dead data once the hook is gone; leave cleanup to the owner if
   they want it, out of scope for a workspace-repo PR.

10. **Re-scope #329** — after this PR merges, re-read #329 (user-tier hooks
    fire twice): it currently targets both `log-tool-use.sh` and
    `block-bash-tool-mapping.sh`; once this issue removes the block hook from
    the user tier entirely, #329's scope narrows to `log-tool-use.sh` alone.
    Not part of this PR's diff — a follow-up comment/edit on #329 after
    merge.

## Files to Change

| File | Change |
|------|--------|
| `.claude/hooks/block-bash-tool-mapping.sh` | Deleted |
| `.agent/scripts/tests/test_block_bash_tool_mapping.sh` | Deleted |
| `.claude/settings.json` | Remove the hook's `PreToolUse` entry |
| `.agent/user_tier_scripts.txt` | Remove the hook's manifest line |
| `.agent/scripts/user_tier_install.sh` | Remove `$block` from `PRE_HOOKS_JSON`, drop it from `hook_commands()`, update header comment |
| `.agent/scripts/tests/test_user_tier_guard.sh` | Remove `BLOCK_HOOK` and its 4 assertions + fixture copy |
| `.agent/scripts/tests/test_user_tier_install.sh` | Narrow the `for h in ...` loop to `log-tool-use.sh` only |
| `CLAUDE.md` | Delete the `## Tool Mapping` section (heading, table, enforcement paragraph) |
| `AGENTS.md` | Reword "Tool Usage" bullet to drop the enforcement framing |
| `docs/ROADMAP.md` | Drop `block-bash-tool-mapping` from the fail-closed-hook-audit example list |
| GitHub issue #328 | Comment with the block-log summary (not a repo file change) |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Both tiers (workspace + user), both test files, and the two instruction files are updated in the same PR — nothing left to drift silently. |
| Enforcement over documentation (inverted here) | This is the rare direction: removing enforcement that now actively fights the tool's own guidance. The instruction-file wording is brought back in line with reality (ADR-0004) rather than left overstating what's enforced. |
| Only what's needed | No new machinery — deletion and manifest edits reuse the existing install/replace mechanism. #329's re-scope and the log file's fate are explicitly deferred, not folded in. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0004 (Enforcement hierarchy) | Yes | Removes an instruction-file claim ("Enforced by hook") that would otherwise outlive the enforcement it describes; AGENTS.md's reworded bullet states a preference, not an enforced rule. |
| ADR-0016 (Session roots / user tier) | Yes | Retiring a promoted hook gets the same care as promoting one: manifest, installer, and both user-tier test files updated together (step 4-5), matching the issue-review flag. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Delete the hook file | Its dedicated test (`test_block_bash_tool_mapping.sh`) | Yes — step 2 |
| Drop it from `.agent/user_tier_scripts.txt` | `user_tier_install.sh`'s `PRE_HOOKS_JSON` / `hook_commands()` | Yes — step 4 |
| User-tier registration removed | `test_user_tier_guard.sh`, `test_user_tier_install.sh` | Yes — step 5 |
| CLAUDE.md loses the enforcement claim | AGENTS.md's parallel "Tool Usage" wording | Yes — step 7 |
| Hook deleted | `docs/ROADMAP.md`'s fail-closed-audit item that names it | Yes — step 8 |
| Hook deleted | `.agent/knowledge/inspiration_*_digest.md` mentions | No — historical record, left as-is |
| Hook deleted | `~/.claude/tool-mapping-blocks.jsonl` (the log file) | No — out-of-repo, unread elsewhere, owner's call |
| This merges | #329's scope (currently covers both hooks) | No — explicit post-merge follow-up (step 10), not this PR's diff |

## Open Questions

None — the owner's checkpoint decision (progress.md, 2026-09-23, "Decision:
proceed") already resolves scope (full retirement, both tiers), the block-log
disposition (no rule kept), and the #329 handling (re-scope after merge).

## Estimated Scope

Single PR. Mechanical deletions/manifest edits plus two short instruction-file
rewords; no new scripts or tests to write, only trims to two existing ones.
