# Plan: User-tier skill symlinks replace a project's own same-named skills in unregistered repos

## Issue

https://github.com/rolker/agent_workspace/issues/345

## Context

The user tier (`~/.claude`, ADR-0016 §3) ships workspace skills to project
sessions as flat symlinks in `~/.claude/skills/`. Symlinks collide by name
with a project's own same-named skill (`gz4d` already has `plan-task`,
`research`, `audit-project`, `brand-guidelines`, all shadowed today), and a
symlink is global to the machine — it reaches every repo, registered or
not. Interim state on this machine: the 12 symlinks were removed by hand;
only `start-task` remains, and `user_tier_install.sh`/`--check` still carry
the symlink logic and would recreate them on the next install.

The owner has decided the fix is a **Claude Code plugin** (namespace rename
accepted as the trade-off), spiked and confirmed live (claude 2.1.281,
`reference-plugin-spike-345`): a local-scope marketplace + plugin install
writes only the *project's* gitignored `.claude/settings.local.json`,
namespaced skills (`agent-workspace:plan-task`) coexist with a project's
own `/plan-task`, worktrees inherit it, unrelated repos don't, and
directory marketplaces load in place.

This is **revision 2**, folding in the round-1 `review-plan` verdict
(needs-work, `956e633`) and the owner's "Accept all 8, revise" checkpoint.
Every numbered finding from that review is addressed below; the section
that answers it is named inline.

This plan still covers **skills only**. Hooks move into the plugin in a
follow-up issue opened alongside this plan (step 10).

## Approach

1. **Add the plugin manifest at the workspace root.**
   `.claude-plugin/plugin.json` — `"name": "agent-workspace"` (owner
   confirmed). `.claude-plugin/marketplace.json` — one entry, source `"./"`.
   The `skills` field is an **array of per-skill directory paths**, not the
   whole `./.claude/skills` glob — see step 2 (finding 7). Verify the array
   form against `claude plugin validate .` (available locally: claude
   2.1.282) before committing the manifest shape; if the schema rejects an
   array, fall back to the whole-directory glob and document the fallback's
   effect in step 2.

2. **Expose only `session_scope: project|both` skills (finding 7).**
   14 of 22 skills declare `project`/`both`; the other 8
   (`analyze-permissions`, `audit-workspace`, `brainstorm`,
   `brand-guidelines`, `gather-project-knowledge`, `inspiration-tracker`,
   `issue-triage`, `research`, `skill-importer`, `what-next` — default
   `workspace`, no field) call `.agent/scripts/...` cwd-relative, which
   `test_skill_paths.sh` allows precisely because they're documented as
   workspace-only. Exposing them through the plugin would either fail
   loudly (script not found under the project cwd) or, worse, silently run
   a same-named script the project happens to ship (`project11` already
   forks some of this tree). Decision: generate `plugin.json`'s `skills`
   array from `session_scope` frontmatter at commit time (a small
   generator step, mirroring `selected_skills()`'s existing awk logic, now
   repurposed rather than deleted) and verify it in
   `test_plugin_manifest.sh` (step 6) by re-deriving the list from
   frontmatter and diffing against the manifest. If `claude plugin
   validate` rejects an array `skills` field (checked in step 1), the
   fallback is the whole-directory glob *and* each workspace-scoped
   skill's cwd-relative script calls become a documented known limitation
   referenced from the hooks-into-plugin follow-up (step 10), not solved
   here.

3. **`start-task` is included** (owner decision). It's `session_scope: both`
   already, so it's in the generated list from step 2 without a special
   case.

4. **Retire the skill-symlink *delivery* code, keep symlink drift
   detection (finding 3).** In `user_tier_install.sh`:
   - Remove `sync_skills()`'s *creation* half (the `ln -s` add/repair loop)
     and `--list-skills`/`--sync-skills` as skill-creating modes — the
     plugin is the delivery mechanism now.
   - **Keep `foreign_skill_link()` and the removal loop.** `--check` keeps
     reporting any `~/.claude/skills/*` symlink that resolves into *any*
     `agent_workspace` checkout (this one or another) as legacy drift, the
     same precedent as the #328 retired-hook-entry check. `--uninstall`
     keeps removing symlinks this checkout owns. This is what makes the
     fix correct on a machine that never re-runs install, not just this
     one (which had them removed by hand already).
   - `selected_skills()` is repurposed by step 2's manifest generator, not
     deleted.

5. **Enable the plugin from `user_tier_install.sh`, per registered root
   (finding 1, owner decision 1).** New behavior, reusing
   `_project_registry.sh`:
   - `install`: for every `registry_names()` entry, resolve its path
     (`registry_field ... path`), then **skip any root whose
     `git -C <root> rev-parse --show-toplevel` equals `$WS_ROOT`**
     (finding 4's guard — confirmed live on this machine: `p11-jazzy` and
     `p11-rolling` have no `.git` of their own; their toplevel is the
     workspace checkout itself, so they already see the workspace's bare
     `.claude/skills` by ordinary directory walk-up, and enabling the
     plugin there would duplicate every skill under both names *and* write
     into the shared workspace-root `settings.local.json`, defeating the
     whole point of scoping). For every other root (`gz4d` today): `cd
     <root> && claude plugin marketplace add "$WS_ROOT" --scope local &&
     claude plugin install agent-workspace@agent-workspace --scope local`.
   - `--check`: verify each non-skipped registered root's
     `<root>/.claude/settings.local.json` has
     `enabledPlugins["agent-workspace@agent-workspace"] == true`;
     report drift per-root if missing, and separately flag (as an error,
     not silent) any *skipped* root whose settings show the plugin enabled
     anyway (a stale enable from before the guard existed).
   - `--uninstall`: `claude plugin uninstall agent-workspace@agent-workspace
     --scope local` from each enabled root (best-effort; a root that no
     longer exists on disk is skipped with a note, not a failure).
   - This function is written so #332's registration flow can call it
     directly for one new root, per the owner's decision that #332 reuses
     it later — no separate "enable" entry point to keep in sync.
   - **ADR-0016 §2 exception, accepted (owner decision 2).** §2 says "the
     workspace never writes into a project checkout (beyond `.git/info/
     exclude` and an untracked `COLCON_IGNORE`)". Running the two `claude
     plugin` commands from the installer writes the project's *gitignored*
     `.claude/settings.local.json`. ADR-0017 (step 9) records this as an
     explicit, scoped exception to §2, not a silent violation.

6. **Add the mechanical plugin-manifest check (finding 7, finding 8).**
   New `.agent/scripts/tests/test_plugin_manifest.sh`:
   - `plugin.json`/`marketplace.json` are valid JSON; `name` is
     `agent-workspace`; marketplace source is `./`.
   - The `skills` array (or glob, per step 1's outcome) matches exactly
     the skills `session_scope: project|both` selects from frontmatter —
     re-derives the list independently rather than trusting the generator
     that wrote it.
   - Runs `claude plugin validate .` when `claude` is on `PATH`, skips
     with a note otherwise (CI/other machines may not have it).

7. **Explicit `--skill-prefix` on `dispatch_phase.sh`, not `--type`-keyed
   (finding 2 — the round-1 plan's biggest defect).** `--type` is the
   *issue/worktree* type, not which skill set the *host* session has
   loaded; a workspace-launched host driving a `--type project` issue has
   no plugin and only bare skills (the primary `/run-issue` use case for
   every p11-* and gz4d issue today), and `$PWD` is not a safe substitute
   (`/start-task` `cd`s the host into a worktree, and Codex hosts have no
   plugin at all). Fix:
   - `dispatch_phase.sh` gains `--skill-prefix <p>` (default: empty —
     correct for a workspace-hosted session and for Codex, which never has
     the plugin). `skill_task_line()` prepends the prefix to every slash
     command it prints (not to the literal `implement` instruction, which
     isn't a slash command).
   - `run-issue`'s SKILL.md (Claude-Code-only) sets `--skill-prefix
     agent-workspace:` when `${CLAUDE_PLUGIN_ROOT}` is non-empty in its own
     rendered text — that variable expands only when the *skill itself* was
     loaded through the plugin (confirmed in the spike, Q4), which is
     exactly "this host session has the plugin" and is independent of
     `--type`/`$PWD`.
   - Test all four host/issue-type combinations: workspace-host +
     workspace-issue (bare, unaffected), workspace-host + project-issue
     (bare — the case round-1 broke), project-host + workspace-issue
     (prefixed — the exact bug #345 fixes, now correctly prefixed instead
     of colliding), project-host + project-issue (prefixed).

8. **Makefile and generated-skill housekeeping (finding 3).**
   `Makefile:159-161`'s `generate-user-tier-skills` target currently calls
   `user_tier_install.sh --sync-skills` for its skill-creating effect,
   which step 4 removes. Repoint it at the drift-check-only path
   (`--check`, or drop the target and fold its comment into
   `user-tier-install`'s) — a plan-time decision to make explicit in the
   PR diff, not leave implicit. Update the target's own comment (it
   currently says "derived from session_scope frontmatter" — still true,
   now for the plugin manifest instead of symlinks). Re-run `make
   generate-skills` after any `.PHONY` line change, per this repo's own
   convention (`CLAUDE.md`).

9. **Record the decision durably: new ADR-0017 (finding 5).**
   `docs/decisions/0017-plugin-based-skill-delivery.md`, superseding
   ADR-0016 §3 only. Three corrections from round 1:
   - (a) **Pointer placement**: ADR-0016 gets a **Status-line and
     References** addition naming ADR-0017 — not a Consequences
     subsection. ADR-0008 counts a Consequences addition as substantive;
     the existing "ADR-0011's discovery order will be superseded" text is
     ADR-0016 *itself* recording its own future supersession of another
     document, not the pattern for *receiving* one. The correct precedent
     is the one-line pointer ADR-0011 received.
   - (b) **§2 exception**: ADR-0017 explicitly states the write-into-
     project-checkout exception from step 5 (owner decision 2), scoped to
     exactly `.claude/settings.local.json` via the two `claude plugin`
     commands, nothing else.
   - (c) **Relationship to #317's acceptance run**: state plainly that the
     gz4d `/run-issue` acceptance run (ADR-0016's own promotion condition)
     will now exercise plugin-delivered skills, and that a passing run
     satisfies both ADR-0016's promotion *and* stands in for ADR-0017's own
     live acceptance (step 11) — one run, two ADRs watching it.
   - Cross-link #335 (zero-footprint design doc — this is its packaging
     answer), #332 (registration automation — reuses step 5's function),
     and #321 (orchestrator skill — prefixed sub-agent handoffs already
     confirmed live in the spike) from ADR-0017's References.

10. **Open the hooks-into-plugin follow-up issue now (owner decision 6).**
    Title: "Move SessionStart/log-tool-use.sh hook delivery into the
    agent-workspace plugin". Body references this plan and ADR-0017,
    names the two remaining user-tier mechanisms hooks still use, and
    records step 2's workspace-scoped-skill limitation as in-scope for
    that follow-up if step 1's array form isn't supported. The host opens
    this issue (not scripted here) — the plan step is "open it", the
    action is manual per the owner's note.

11. **No instruction-file edits; the note lives in the SessionStart hook
    header instead (finding 6, owner decision 7).** Round 1 proposed
    edits to `AGENTS.md`/`CLAUDE.md`/three adapters/`AGENT_ONBOARDING.md`
    "correcting" text that doesn't exist there — confirmed by grep, none
    of the five files mentions symlinks, the user tier, or skill delivery.
    Dropped entirely. Instead,
    `.claude/hooks/session_start_project_layer.sh`'s own header comment
    (lines 6–17, already describing what the hook injects for a project
    session) gets one added line: workspace skills reach a registered
    project through the `agent-workspace` plugin (Claude Code only, not
    through this hook), since 7 skills reference each other by bare slash
    command in prose (finding 9) and a reader of *this* file — not an
    Ask-First instruction file — is exactly who needs to know that.

12. **Tests.**
    - `test_user_tier_install.sh`: remove the skill-*creation* test cases
      (the `ln -s` add/repair paths); **keep and extend** the drift-
      detection cases for `foreign_skill_link()`/stale-symlink removal
      (finding 3 — nothing here gets deleted, only the creation half).
      Add cases for the new per-root enable/`--check`/`--uninstall` logic
      (step 5), including the workspace-toplevel skip guard, using a
      sandboxed registry the same way the existing suite sandboxes
      `$WS_ROOT`.
    - New `test_plugin_manifest.sh` (step 6).
    - Extend `dispatch_phase.sh`'s test suite with the four
      `--skill-prefix` combinations (step 7).
    - `test_user_tier_guard.sh` and `test_skill_paths.sh` are unaffected
      (guard governs promoted scripts/hooks, not skills; skill-paths keeps
      enforcing `$WS_ROOT` idiom for `project|both` skills regardless of
      delivery mechanism) — confirmed by reading both; noted in the PR so
      a reviewer isn't left looking for a change that isn't there.

13. **Live acceptance: port the spike, opt-in (finding 8).**
    `.agent/scripts/tests/live/plugin_acceptance.sh`, adapted from
    `scratchpad/plugin-spike/spike.sh` — **not** collected by
    `run_script_tests.sh` (needs a real `claude` session and, for the
    p11-shape case, is destructive-adjacent to the real registry — auth
    and cost gate it as opt-in). Covers, headlessly via `claude -p`:
    - Collision: a synthetic repo with its own `plan-task` skill sees
      both `/plan-task` (its own) and `/agent-workspace:plan-task`.
    - Worktree inheritance and the unrelated-repo negative (from the
      spike).
    - Workspace-root shape: a session *at* `$WS_ROOT` sees every plugin
      skill exactly once, bare — never doubled.
    - p11-shape: a synthetic root with no `.git` of its own, toplevel
      pointing at a synthetic "workspace", confirms the guard in step 5
      would skip it (this can be asserted without the real registry by
      pointing the script at a sandboxed one, matching the hermetic
      pattern the existing installer tests already use).
    - The `--skill-prefix` end-to-end path from step 7.
    Run once against the real workspace + a scratch project as part of
    this PR; record the transcript/output in the PR description.

## Files to Change

| File | Change |
|------|--------|
| `.claude-plugin/plugin.json` | New — `name: agent-workspace`, `skills` as a generated array of `project\|both` skill paths (or documented glob fallback) |
| `.claude-plugin/marketplace.json` | New — one-entry marketplace, source `./` |
| `.agent/scripts/user_tier_install.sh` | Remove skill-symlink *creation* only (keep drift detection/`foreign_skill_link()`); add per-registered-root plugin enable/`--check`/`--uninstall` with the workspace-toplevel skip guard |
| `.agent/scripts/tests/test_user_tier_install.sh` | Remove creation-only cases; keep/extend drift cases; add per-root enable/check/uninstall + guard cases |
| `.agent/scripts/tests/test_plugin_manifest.sh` | New — manifest shape, skill-list-matches-frontmatter, `claude plugin validate` when available |
| `.agent/scripts/dispatch_phase.sh` | `--skill-prefix` flag (default empty) on `skill_task_line()` |
| `.agent/scripts/tests/` (dispatch_phase suite) | Four `--skill-prefix`/host/issue-type combinations |
| `Makefile` | Repoint or retire `generate-user-tier-skills` (its `--sync-skills` call is gone); update comment; re-run `make generate-skills` |
| `docs/decisions/0017-plugin-based-skill-delivery.md` | New ADR — supersedes ADR-0016 §3, records the §2 exception, states the #317-run relationship, cross-links #335/#332/#321 |
| `docs/decisions/0016-session-roots-and-the-user-tier.md` | Status-line/References pointer to ADR-0017 (not Consequences) |
| `.agent/knowledge/principles_review_guide.md` | Update ADR-0016 row; add ADR-0017 row |
| `.claude/hooks/session_start_project_layer.sh` | One added header-comment line: plugin delivers workspace skills to project sessions, not this hook |
| `.agent/scripts/tests/live/plugin_acceptance.sh` | New — opt-in, ported from the spike |
| GitHub issue (new) | Hooks-into-plugin follow-up, opened by the host, referencing this plan and ADR-0017 |

**Explicitly not touched** (round 1 proposed, round 2 drops, per owner
decision 7): `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`,
`.agent/instructions/gemini-cli.instructions.md`,
`.agent/AGENT_ONBOARDING.md`.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Capture decisions, not just implementations | ADR-0017 records the plugin decision, the §2 exception, the #317-run relationship, and the plugin-name/enable-step/prefix/scope answers before implementation starts |
| A change includes its consequences | Step 9 updates the ADR table; step 8 the Makefile; step 11 the one file that actually needed a note; no unrelated instruction-file edits |
| Enforcement over documentation | Step 4 keeps `--check` drift detection rather than removing it; step 5 adds a mechanical per-root enable check; step 6 verifies the manifest against frontmatter instead of trusting hand-maintenance |
| Improve incrementally | Skills-only first PR; hooks are a named, opened follow-up issue (step 10) |
| Primary framework first, portability where free | `${CLAUDE_PLUGIN_ROOT}`/`claude plugin ...` stay confined to the Claude-only steps (manifest, `run-issue`'s own prefix-detection); `dispatch_phase.sh`'s `--skill-prefix` is a plain string parameter a Codex-equivalent caller can simply never pass |
| Workspace improvements cascade to projects | Plugin install is per-registered-root opt-in via each project's own gitignored `settings.local.json`, with an explicit guard against the workspace-root/p11-shape case where a project shares the workspace's own tree |
| The workspace serves the product | Unblocks `gz4d` (zero workspace skills today); p11-jazzy/p11-rolling are correctly identified as already covered by directory walk-up, not needing the plugin at all — verified from this machine's actual registry, not assumed |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0016 — Session roots and the user tier | Yes | §3 superseded by ADR-0017; §2's write-into-checkout rule gets an explicit, scoped exception (step 5/9); §1/§4–§8 untouched |
| 0008 — Cross-reference addendums | Yes | Confirms the supersession needs a new ADR, and that the pointer belongs in Status/References, not Consequences |
| 0014 — In-process phase handoff | Yes | `dispatch_phase.sh` gains `--skill-prefix`; its test suite covers all four combinations |
| 0013 — progress.md entry-type vocabulary | No | No new entry type |
| 0006 — Shared AGENTS.md | No (revised) | Round 1 wrongly triggered this on non-existent text; round 2 makes no AGENTS.md-family edits |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Skill delivery mechanism (symlink creation → plugin) | ADR-0016, new ADR-0017, principles_review_guide.md | Yes — steps 9 |
| `dispatch_phase.sh` skill-name strings | Its test suite | Yes — step 7/12 |
| `user_tier_install.sh` skill/enable logic | `test_user_tier_install.sh` | Yes — step 12 |
| `Makefile` `generate-user-tier-skills` | Its comment, `make generate-skills` re-run | Yes — step 8 |
| gz4d has no workspace skills today (symlinks removed) | Enabled automatically by the next `user_tier_install.sh` run (step 5) — no manual step | Yes — step 5, no follow-up needed |
| p11-jazzy / p11-rolling share the workspace git toplevel | Confirmed NOT needing the plugin (already see bare skills); guarded against double-enable | Yes — step 5's guard, verified live on this machine |
| Hooks still on the old user-tier mechanism | Move into the plugin | No — follow-up issue opened now (step 10), not implemented here |

## Open Questions

- **`skills` array vs. glob in `plugin.json` (step 1/2).** Needs a direct
  `claude plugin validate .` check against a trial array-form manifest
  before the real manifest is written — first implementation step, not
  deferred.
- **`generate-user-tier-skills` Makefile target's exact fate (step 8)** —
  repoint to `--check`, or retire and fold into `user-tier-install`'s own
  comment. Either is fine; pick one during implementation and say why in
  the commit.
- **New ADR number.** `0017` was free as of the round-1 review
  (2026-09-24); re-check immediately before committing the ADR file in
  case a concurrent branch has since claimed it.
- **Hooks follow-up issue body detail** — opened per step 10, but its own
  scope (which hook entries, whether `log-tool-use.sh` moves whole or
  gets a plugin-native equivalent) is intentionally left thin; that's the
  follow-up's own planning work, not this plan's.

## Estimated Scope

Single PR (skills-only, per the owner's checkpoint decision), plus one new
GitHub issue opened for the hooks follow-up (step 10, not implemented in
this PR).
