# Plan: User-tier skill symlinks replace a project's own same-named skills in unregistered repos

## Issue

https://github.com/rolker/agent_workspace/issues/345

## Context

The user tier (`~/.claude`, ADR-0016 §3) currently ships workspace skills to
project sessions as flat symlinks in `~/.claude/skills/`. Symlinks by name
collide with a project's own same-named skill (`gz4d` already has its own
`plan-task`, `research`, `audit-project`, `brand-guidelines` — all shadowed
today), and a symlink is global to the machine, so it silently reaches
*every* repo, registered or not. Interim state on this machine: the 12
symlinks were removed by hand; only `start-task` remains, and
`user_tier_install.sh`/`--check` still carry the symlink logic and would
recreate them on the next install.

The owner has decided the fix is a **Claude Code plugin** (namespace rename
accepted as the trade-off), spiked and confirmed live (claude 2.1.281,
`reference-plugin-spike-345`): a local-scope marketplace + plugin install
writes only the *project's* gitignored `.claude/settings.local.json`,
namespaced skills (`agent-workspace:plan-task`) coexist with a project's own
`/plan-task`, worktrees inherit it, unrelated repos don't, and directory
marketplaces load in place (edits apply next session, no reinstall).

This plan covers **skills only**. Hooks (the `SessionStart` layer injection
and `log-tool-use.sh`) stay on the current user-tier mechanism and move into
the plugin in a follow-up issue — see Open Questions.

## Approach

1. **Add the plugin manifest at the workspace root.**
   `.claude-plugin/plugin.json` — `"name": "agent-workspace"`,
   `"skills": "./.claude/skills"` (the whole existing directory; see decision
   below on `session_scope` filtering). `.claude-plugin/marketplace.json` —
   one entry, plugin source `"./"`. Both are plain JSON, committed at the
   workspace root; nothing project-side is touched by adding them.

2. **Decide `session_scope`'s meaning post-plugin.** Symlink-based delivery
   used `session_scope: project|both` to curate *which* skills reached a
   project session, because every symlinked name was a collision risk. The
   plugin's namespacing removes that risk — a bare `session_scope: workspace`
   skill like `audit-workspace` or `research` can now be exposed under
   `agent-workspace:` without touching the project's own `/research`. Decision:
   expose the whole `.claude/skills` directory through the plugin (all 21
   skills, unfiltered) rather than build a curated subset tree — the field
   stops gating *exposure* and keeps documenting *intended* scope (a skill
   whose SKILL.md assumes the workspace cwd, e.g. `audit-workspace`, still
   only makes sense run bare from the workspace; running it under
   `agent-workspace:audit-workspace` from a project is harmless but not
   useful). This is simpler than maintaining a second, filtered skills tree
   and matches "namespacing solves the collision problem, so the curation
   problem doesn't need solving too." Flagged as a decision to confirm, not
   an obvious no-op — see Open Questions.

3. **`start-task` stays in the plugin.** It's `session_scope: both` and
   Claude-Code-only already; excluding it from the plugin would need a
   second, curated skills path (rejected in step 2) just for one skill.
   Running `agent-workspace:start-task` from a project session (to open a
   *workspace* worktree without leaving the project session) is an unusual
   but not harmful use; simplicity wins. Confirm at the plan checkpoint.

4. **Retire the skill-symlink code in `user_tier_install.sh`.** Remove
   `SKILLS_DIR`, `selected_skills()`, the skill portion of `sync_skills()`,
   `--list-skills`, `--sync-skills`'s skill effect, the skill section of
   `--check`'s drift report, and the skill-symlink removal loop in
   `--uninstall`. Update the file's header comment (item 5 goes away).
   Add a one-time **migration cleanup**: on `install` and `uninstall`, scan
   `~/.claude/skills/` for symlinks pointing into `$WS_ROOT/.claude/skills/*`
   (the old delivery mechanism) and remove them — this is what makes the
   change correct on a machine that hasn't manually removed them yet (only
   this machine has; #345's own interim state), not just on this one.

5. **Add a mechanical plugin-manifest check.** New
   `.agent/scripts/tests/test_plugin_manifest.sh`: `plugin.json` is valid
   JSON, `name` is `agent-workspace`, `skills` points at `./.claude/skills`;
   `marketplace.json` is valid JSON and its one plugin entry's `source` is
   `./`. This is the enforcement-over-documentation replacement for the
   drift check step 4 removes — a renamed/malformed manifest fails a test
   run instead of silently breaking every project's plugin install.

6. **Prefix skill names by session root in `dispatch_phase.sh`.**
   `skill_task_line()` (lines ~236–244) hardcodes bare `/review-issue`,
   `/plan-task`, etc. `dispatch_phase.sh` already resolves `--type
   workspace|project` for every dispatch. Add a local prefix — empty for
   `--type workspace`, `agent-workspace:` for `--type project` — and apply
   it to every skill name in `skill_task_line()`'s case statement (not to
   the literal `implement` instruction, which isn't a slash command). Add
   test cases to the existing `dispatch_phase.sh` test suite covering both
   `--type` values for at least two skills.

7. **Document the enable step as a manual, then-automated action.**
   `register_project.sh` doesn't exist yet (#332 / ADR-0016 decision 5 is
   PR-4-scoped and not landed) — today, registering a project means hand-
   editing `.agent/projects.local`. Add the two commands as the documented
   next manual step wherever that hand-edit is documented (`.agent/
   WORKTREE_GUIDE.md`), run from the project root:
   ```
   claude plugin marketplace add <workspace-root> --scope local
   claude plugin install agent-workspace@<marketplace-name> --scope local
   ```
   Note inline that #332's onboarding automation takes this step over once
   it lands — this plan does not implement #332.

8. **Record the decision durably: new ADR-0017.** ADR-0016 is itself
   Provisional (pending #317's gz4d acceptance run) and its Decision §3
   ("skill symlinks") is exactly what this issue replaces — a substantive
   change per ADR-0008's test, which needs a superseding ADR, not an
   addendum. Decision: a **new** `docs/decisions/0017-<slug>.md` that
   supersedes ADR-0016 §3 only (skill delivery), leaving §1/§2/§4–§8
   (session roots, registry, memory placement, the user-tier inertness
   rule, the root-file convention) untouched and in force. Rationale for a
   new ADR over editing 0016 in place: 0016 is still awaiting its own
   promotion decision, and folding an unrelated mechanism swap into a
   document that hasn't been accepted yet would conflate two open
   questions in one file; a scoped superseding ADR is the smaller, more
   reviewable diff and matches how 0016 itself points at 0011 for its own
   future supersession rather than editing 0011 in place. Add a "Record
   the plugin decision" cross-link from ADR-0016's Consequences section
   (same pattern as its existing "ADR-0011's discovery order will be
   superseded" subsection) pointing at ADR-0017.
   Cross-link #335 (zero-footprint design doc — this plugin mechanism is
   its packaging answer), #332 (registration automation — names the
   enable step above), and #321 (orchestrator skill — sub-agent handoffs
   already confirmed to work with prefixed names in the spike) from
   ADR-0017's References section.

9. **Update the ADR table and framework docs.**
   `.agent/knowledge/principles_review_guide.md` row 42 (ADR-0016) gets a
   trailing note that skill delivery moved to ADR-0017; add a new row for
   0017. `AGENTS.md`/`CLAUDE.md` and the non-Claude adapters
   (`.github/copilot-instructions.md`,
   `.agent/instructions/gemini-cli.instructions.md`,
   `.agent/AGENT_ONBOARDING.md`) get a one-line correction: workspace
   skills reach a registered project via the `agent-workspace` plugin
   (Claude Code only), not via symlinks; Codex/Gemini/Copilot are
   unaffected — they already read `.claude/skills/*/SKILL.md` (or the
   equivalent tree) directly and never had the symlink mechanism.

10. **Tests.**
    - Update `.agent/scripts/tests/test_user_tier_install.sh`: delete every
      symlink/`--list-skills`/`--sync-skills`/skill-drift test case; add one
      case asserting a fresh `install` (and `uninstall`) removes a
      pre-existing stale symlink under `~/.claude/skills/` that points into
      the sandboxed workspace copy (the migration-cleanup path from step 4).
    - `.agent/scripts/tests/test_user_tier_guard.sh` is unaffected (it
      governs promoted *scripts/hooks*, not skills) — no change, confirmed
      by reading it; note this in the PR so a reviewer doesn't go looking
      for a change that isn't there.
    - New `test_plugin_manifest.sh` (step 5).
    - Extend `dispatch_phase.sh`'s existing test coverage for the
      `--type`-aware prefix (step 6).
    - Add `.agent/scripts/tests/run_script_tests.sh` picks up the new suite
      automatically (glob-based); no registration step needed.

11. **Live acceptance step (manual, documented in the PR description, not
    automated — collisions with a real project's own skill can't be
    asserted without a real `claude` CLI session).**
    - Create a scratch git repo (synthetic — never a real registered
      project) with its own `.claude/skills/plan-task/SKILL.md` (or reuse
      an existing gz4d-style collision).
    - `claude plugin marketplace add <this-workspace-root> --scope local`
      then `claude plugin install agent-workspace@agent-workspace --scope
      local` from the scratch repo root.
    - In a Claude Code session there: confirm `/agent-workspace:plan-task`
      is available and distinct from the scratch repo's own `/plan-task`,
      and that an unrelated third repo (no marketplace/install) sees
      neither.
    - Record the result in the PR description; this substitutes for a
      scripted assertion the plugin CLI doesn't expose non-interactively
      for "list skills the picker resolves."

## Files to Change

| File | Change |
|------|--------|
| `.claude-plugin/plugin.json` | New — plugin manifest, `name: agent-workspace`, `skills: ./.claude/skills` |
| `.claude-plugin/marketplace.json` | New — one-entry marketplace, source `./` |
| `.agent/scripts/user_tier_install.sh` | Remove skill-symlink logic (`SKILLS_DIR`, `selected_skills`, skill half of `sync_skills`/`--check`/`--uninstall`, `--list-skills`, `--sync-skills`'s skill effect); add stale-symlink migration cleanup on install/uninstall; update header comment |
| `.agent/scripts/tests/test_user_tier_install.sh` | Remove symlink/skill-selection test cases; add stale-symlink-cleanup case |
| `.agent/scripts/tests/test_plugin_manifest.sh` | New — validates `plugin.json`/`marketplace.json` shape |
| `.agent/scripts/dispatch_phase.sh` | `skill_task_line()`: prefix skill names with `agent-workspace:` for `--type project`, bare for `--type workspace` |
| `.agent/scripts/tests/` (dispatch_phase test suite) | Add cases for the `--type`-aware prefix |
| `docs/decisions/0017-<slug>.md` | New ADR — supersedes ADR-0016 §3 (skill delivery), cross-links #335/#332/#321 |
| `docs/decisions/0016-session-roots-and-the-user-tier.md` | Add a Consequences pointer to ADR-0017 (pattern matches its existing ADR-0011 pointer) |
| `.agent/knowledge/principles_review_guide.md` | Update ADR-0016 row; add ADR-0017 row |
| `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`, `.agent/AGENT_ONBOARDING.md` | One-line correction: plugin, not symlinks, delivers workspace skills to registered projects (Claude Code only) |
| `.agent/WORKTREE_GUIDE.md` | Document the two `claude plugin ...` commands as the current manual enable step, with a note that #332 will automate it |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Capture decisions, not just implementations | ADR-0017 records the plugin decision, the namespace-rename trade-off, and the plugin-name/enable-step/naming answers from the owner's checkpoint before implementation starts |
| A change includes its consequences | Step 9 updates the ADR table and every framework adapter that names the delivery mechanism; step 8 cross-links the three dependent issues |
| Enforcement over documentation | Step 5's manifest test replaces the drift check step 4 removes, rather than leaving the plugin shape undocumented and unverified |
| Improve incrementally | First PR is skills-only; hooks are an explicit named follow-up (Open Questions), matching the owner's "In registration now" / "first PR skills only" checkpoint answers |
| Primary framework first, portability where free | `${CLAUDE_PLUGIN_ROOT}`/`claude plugin ...` stay confined to the Claude-only steps (manifest, install docs); `dispatch_phase.sh`'s prefixing logic is a plain string swap on `--type`, not plugin-runtime-dependent, so it stays framework-neutral where a Codex session reads the same script |
| Workspace improvements cascade to projects | Plugin install is per-project opt-in via each project's own gitignored `settings.local.json`; the workspace checkout's own tracked files are untouched |
| The workspace serves the product | Directly unblocks `gz4d` (currently zero workspace skills after the by-hand symlink removal) and both `p11-*` projects once each runs the two enable commands (step 11 / follow-up) |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0016 — Session roots and the user tier | Yes | §3 (skill symlinks) is superseded by new ADR-0017; §1/§2/§4–§8 untouched. A Consequences pointer added, mirroring the existing ADR-0011 pattern |
| 0008 — Cross-reference addendums | Yes | Confirms this is a substantive Decision change (not a cross-reference), so a superseding ADR is required, not an addendum — step 8's rationale |
| 0014 — In-process phase handoff | Yes | `dispatch_phase.sh`'s per-skill task-line table changes shape (prefix added); its test suite gets matching new cases |
| 0013 — progress.md entry-type vocabulary | No | No new entry type introduced |
| 0006 — Shared AGENTS.md | Yes | Framework adapters updated so Codex/Copilot/Gemini docs stay accurate about a mechanism that is Claude-Code-only |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Skill delivery mechanism (symlink → plugin) | ADR-0016, new ADR-0017, principles_review_guide.md ADR table | Yes — steps 8–9 |
| `dispatch_phase.sh` skill-name strings | Its test suite | Yes — step 6/10 |
| `user_tier_install.sh` skill logic | `test_user_tier_install.sh` | Yes — step 10 |
| Framework-adapter docs naming the delivery mechanism | AGENTS.md, CLAUDE.md, non-Claude adapters | Yes — step 9 |
| gz4d / p11-jazzy / p11-rolling currently have no workspace skills (symlinks removed) | Each needs the two enable commands run once, post-merge | Follow-up — not part of this PR's code, called out in the PR description and step 11's acceptance run |
| Hooks still on the old user-tier mechanism | Move into the plugin | No — explicit follow-up issue, out of scope for this PR |

## Open Questions

- **Plugin name confirmation.** Host picked `agent-workspace` (owner leaned
  towards the unambiguous option; confirm this is still the pick before
  the manifest is committed).
- **`session_scope` after the plugin (step 2).** Confirm exposing all 21
  skills unfiltered through the plugin is acceptable, versus keeping a
  curated subset (would need a second skills tree or a filtering shim in
  `plugin.json`, adding complexity this plan avoids).
- **`start-task` in the plugin (step 3).** Confirm including it is fine,
  versus excluding it (which would force the curated-subset approach step 2
  rejects).
- **Hooks follow-up.** This plan does not open the follow-up issue for
  moving `SessionStart`/`log-tool-use.sh` into the plugin — confirm whether
  to open it now (referencing this plan) or after the skills-only PR lands
  and gets its own acceptance signal.
- **New ADR number.** `0017` is the next free slot as of this plan; confirm
  no other in-flight PR is also claiming it (checked `docs/decisions/`
  locally — 0016 is the highest landed — but a concurrent branch could
  collide).

## Estimated Scope

Single PR (skills-only, per the owner's checkpoint decision). Hooks moving
into the plugin is an explicit follow-up issue, not part of this PR.
