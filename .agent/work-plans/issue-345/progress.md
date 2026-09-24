---
issue: 345
---

# Issue #345 — User-tier skill symlinks replace a project's own same-named skills in unregistered repos

## Issue Review
**Status**: complete
**When**: 2026-09-24 14:25 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #345

### Scope Assessment

**Well-scoped?** Partially. The issue itself still presents three
undecided options — the decision recorded above (plugin, with namespace
renaming accepted) lives only in today's conversation and a private memory
note, not in the issue thread or an ADR. Before planning starts, that
decision needs a durable record the next agent can find cold (see
Principle Alignment and Recommendations).

Even with the approach fixed, the remaining surface is large for one PR:
plugin marketplace/install mechanism, the rename's effect on
`dispatch_phase.sh`'s hardcoded skill invocation strings
(`.agent/scripts/dispatch_phase.sh:236-244` prints bare `/review-issue`,
`/plan-task`, `/review-plan`, `/review-code`, `/triage-reviews`,
`/address-findings` as the task line for every phase — these become
`/<plugin>:<skill>` in a project session but must stay bare in a workspace
session), the installer/`--check` drift logic (`user_tier_install.sh`, per
the issue's own text), where "enable in this project" happens (registration
via #332 vs. a `user_tier_install.sh` step), and whether hooks move to the
plugin in the same PR or a later one. The owner's open questions below are
exactly this list — they read as scope-defining, not implementation detail,
and the plan should settle them before code, likely by narrowing the first
PR to skills only (hooks deferred) per "Improve incrementally."

**Right repo?** Yes — workspace infrastructure (`.claude/skills/` delivery
mechanism, `user_tier_install.sh`).

**Dependencies**:
- #317 / ADR-0016 (closed, Provisional) — this issue changes the mechanism
  ADR-0016 §3 ("The user tier injects the layers... skill symlinks")
  documents. A plugin-based delivery is a substantive change to that
  decision, not a cross-reference addendum under ADR-0008's test.
- #335 (design doc, zero-footprint direction) — owner has flagged this as a
  pre-requisite for zero-footprint work on `gz4d`/`project11-ng`; the plugin
  decision should be reflected there too.
- #332 (onboarding registers projects) — a candidate home for "enable in
  this project"; the plan must pick one owner for that step, not split it
  silently between #332 and this issue.
- #321 (orchestrator skill) — depends on how sub-agents are handed skill
  names across a host/dispatch boundary; the spike already confirmed a
  prefixed name works in a handoff prompt, but the naming convention itself
  should be settled once, not per-consumer.
- Portability: the owner's direction is that the loop also runs from Codex
  (agy deprioritized), Codex reads skills natively and a global tier does
  not shadow repo skills there, so Codex needs no equivalent fix — but any
  script logic this issue adds (naming, dispatch) must stay framework
  neutral where the rule is naturally portable; `${CLAUDE_PLUGIN_ROOT}` is
  flagged by the owner as possibly Claude-only and should not leak into
  shared script conventions.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Capture decisions, not just implementations | Action needed | The plugin-vs-alternatives decision (with its accepted trade-off — namespace renaming) is currently recorded only in a memory note and today's conversation, not in the issue or an ADR. ADR-0001 and the workspace's own practice call for this to survive in `docs/decisions/` before or alongside implementation, especially since it revises ADR-0016. |
| A change includes its consequences | Action needed | Touches ADR-0016 (needs a superseding revision, not an addendum, per ADR-0008's substantive-change test), the review guide's ADR table, `dispatch_phase.sh`'s hardcoded skill-invocation strings (ADR-0014 territory), and any doc that names skills for invocation (`AGENTS.md`/`CLAUDE.md` references, non-Claude adapter skill lists per the consequences map's "Workflow skill list" row). |
| Enforcement over documentation | Watch | `user_tier_install.sh --check` already mechanically detects the interim drift (good — this is enforcement, not just a note). The plan should keep an equivalent mechanical check for the plugin-based install, not let `--check` regress to informational-only. |
| Improve incrementally | Watch | Given the scope surface above, the first PR should be scoped narrowly (skills only, one plugin, minimal rename) with hooks and other consumers deferred to follow-ups, rather than shipped as one large change. |
| Primary framework first, portability where free | Watch | The mechanism is Claude-Code-specific (`claude plugin ...`, `${CLAUDE_PLUGIN_ROOT}`). That's fine as the primary-framework solution, but any shared script conventions it introduces (skill-naming, dispatch logic) need to stay expressible without assuming a plugin runtime, since Codex reads the same `SKILL.md` tree directly. |
| Workspace improvements cascade to projects | OK | The plugin's per-project opt-in (marketplace add + install, scoped to that project's `.claude/settings.local.json`) is a good match for this principle — no workspace-to-project coupling, and each project adopts independently. |
| The workspace serves the product | OK | Directly unblocks the product-critical path (`gz4d`/`project11` skill availability); the interim workaround already shows measurable value (project11 unblocked) and cost (`gz4d` currently has no workspace skills). |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0016 — Session roots and the user tier | Yes | Directly revises decision §3 (skill symlinks as the delivery mechanism) and the user-tier promotion rule's scope. Status is currently Provisional pending the gz4d acceptance run; this issue should either wait for or explicitly account for that in-flight status, and needs a superseding ADR (or a new one) rather than an addendum. |
| 0014 — In-process phase handoff | Yes, if skill names change | `dispatch_phase.sh`'s per-skill task-line table hardcodes bare `/skill` invocations. If the plan renames skills behind a plugin prefix, this table's contract (and its tests) move with it. |
| 0006 — Shared AGENTS.md | Watch | If the skill list or invocation convention changes, the non-Claude framework adapters (`CODEX.md`, `.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`) need to stay accurate about what a Codex/Copilot/Gemini session actually sees, especially since Codex is explicitly in scope for portability here. |
| 0011 — Project-type adapter contract | No | Not a project-shape change. |

### Consequences

- `.agent/knowledge/principles_review_guide.md` — ADR table row for 0016 needs updating once the revision lands.
- `docs/decisions/0016-session-roots-and-the-user-tier.md` — needs the superseding revision itself.
- `.agent/scripts/dispatch_phase.sh` — per-skill task-line table, if invocation names change.
- `.agent/scripts/user_tier_install.sh` and `.agent/user_tier_scripts.txt` — install/`--check` drift logic, per the issue's own text.
- Framework adapters (`CLAUDE.md`, `CODEX.md`, `.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`) — if the skill list or naming convention changes.
- `.agent/work-plans/issue-265/spike-results.md` and `#317`'s acceptance-test status — this issue's fix should not be read as satisfying or invalidating that still-open acceptance run.

### Recommendations

- Record the plugin decision (with the accepted namespace-rename trade-off) as a durable artifact before implementation — a superseding revision to ADR-0016, or a new ADR if the change is large enough to stand alone — so a future reader doesn't find three open options in the issue and no resolution anywhere in the repo.
- Scope the first PR to skills only (defer hooks) per the owner's own open question, and settle plugin name/prefix, where "enable in this project" happens, and how `dispatch_phase.sh` names skills across workspace vs. project sessions as explicit plan decisions, not implementation-time choices.
- Cross-link #335, #332, and #321 from this issue (or its plan) so the naming/registration/dispatch dependencies are visible to whoever picks this up next.
- Keep the fix framework-neutral where the rule is naturally portable (skill discovery, naming convention) and confine anything Claude-Code-specific (`${CLAUDE_PLUGIN_ROOT}`, `claude plugin ...` commands) to the Claude-only path, consistent with the owner's portability direction for Codex.

### Actions
- [ ] The plugin-vs-alternatives decision (with its accepted trade-off — namespace renaming) is currently recorded only in a memory note and today's conversation, not in the issue or an ADR. ADR-0001 and the workspace's own practice call for this to survive in `docs/decisions/` before or alongside implementation, especially since it revises ADR-0016.
- [ ] Touches ADR-0016 (needs a superseding revision, not an addendum, per ADR-0008's substantive-change test), the review guide's ADR table, `dispatch_phase.sh`'s hardcoded skill-invocation strings (ADR-0014 territory), and any doc that names skills for invocation (`AGENTS.md`/`CLAUDE.md` references, non-Claude adapter skill lists per the consequences map's "Workflow skill list" row).
- [ ] Record the plugin decision (with the accepted namespace-rename trade-off) as a durable artifact before implementation — a superseding revision to ADR-0016, or a new ADR if the change is large enough to stand alone — so a future reader doesn't find three open options in the issue and no resolution anywhere in the repo.
- [ ] Scope the first PR to skills only (defer hooks) per the owner's own open question, and settle plugin name/prefix, where "enable in this project" happens, and how `dispatch_phase.sh` names skills across workspace vs. project sessions as explicit plan decisions, not implementation-time choices.
- [ ] Cross-link #335, #332, and #321 from this issue (or its plan) so the naming/registration/dispatch dependencies are visible to whoever picks this up next.
- [ ] Keep the fix framework-neutral where the rule is naturally portable (skill discovery, naming convention) and confine anything Claude-Code-specific (`${CLAUDE_PLUGIN_ROOT}`, `claude plugin ...` commands) to the Claude-only path, consistent with the owner's portability direction for Codex.

## Checkpoint
**Status**: complete
**When**: 2026-09-24 14:33 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed to plan (Recommended) — plan covers a skills-only first PR, an ADR-0016 revision (or new ADR) recording the plugin decision, cross-links to #335/#332/#321, and these answers:
- Plugin name: owner — "Part of me likes 3 for being complete and un-ambiguous. If I have to type these a lot, I'd go 1, but in reality I probably don't need to type these much if at all." Host chose `agent-workspace` (option 3; descriptive kebab-case matches plugin convention); confirm at the plan checkpoint.
- Enable step: "In registration now (Recommended)" — registering a project runs the two --scope local install commands; onboarding (#332) takes it over later.
- Naming: "Prefix outside workspace (Recommended)" — bare /review-code in workspace sessions, /agent-workspace:review-code in project sessions, decided from the session root.

## Plan Authored
**Status**: complete
**When**: 2026-09-24 14:45 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-345/plan.md` at `8b64626`

Skills-only first PR: a Claude Code plugin (`agent-workspace`, namespaced
skills) replaces the user-tier symlink mechanism, retiring the
symlink/drift logic in user_tier_install.sh with a migration cleanup for
stale links, prefixing dispatch_phase.sh skill names by session root, and
recording the decision as a new ADR-0017 superseding ADR-0016 section 3
(cross-linking #335, #332, #321). Hooks-into-plugin is named as an explicit
follow-up. Open questions for the owner: session_scope filtering after the
plugin, start-task inclusion, and the new ADR number.

## Plan Review
**Status**: complete
**When**: 2026-09-24 14:51 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #345 — User-tier skill symlinks replace a project's own same-named skills in unregistered repos
**Plan**: `.agent/work-plans/issue-345/plan.md` at `8b64626`
**Branch**: `feature/issue-345`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Skills-only single PR, hooks deferred, as the checkpoint asked. |
| Issue alignment | Concern | Step 7 changes the owner's enable-step answer ("in registration now") into a manual documented step without asking (finding 1). The naming answer ("decided from the session root") becomes "keyed on `--type`", and those are not the same thing (finding 2). |
| File targeting | Needs work | Misses `Makefile` (`generate-user-tier-skills` calls the `--sync-skills` flag the plan removes) and `test_skill_paths.sh`. Also targets five Ask-First instruction files for a "correction" to text that does not exist (finding 6). |
| Consequences | Needs work | No drift report for leftover symlinks on machines that never re-run install. No guard against the plugin being enabled at the workspace root. The p11-* projects live inside the workspace git tree and are not assessed. The effect on ADR-0016 §2 ("never writes into a project checkout") is unaddressed. |
| Principle alignment | Needs work | "Enforcement over documentation": `--check` loses all skill enforcement, and the plugin manifest test does not replace a per-machine install check. "Only what's needed": the AGENTS/CLAUDE/adapter edits add content that nothing currently says. |
| ADR compliance | Needs work | A new superseding ADR is right. But the proposed back-pointer goes into ADR-0016's **Consequences** section, which ADR-0008 lists as substantive. ADR-0017 must also cover ADR-0016 §2 and the #317 acceptance run (finding 5). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment — DEVIATION, owner call]** The owner chose "In registration now — registering a project runs the two `--scope local` install commands". The plan's step 7 downgrades that to a manual step documented in WORKTREE_GUIDE.md, because `register_project.sh` does not exist. The premise is right: registration today means hand-editing `.agent/projects.local`. No registration script exists, and `setup_project.sh`, `validate_workspace.py` and the onboard-project skill do not register anything.

   A real hook point does exist, though: `user_tier_install.sh`. It is already the per-machine step that wires the workspace into Claude Code after registration. It can read the registry through `_project_registry.sh` (the same way the hook and guards do). Install mode could `cd <root> && claude plugin marketplace add … --scope local && claude plugin install agent-workspace@… --scope local` for every registered non-parent root. `--check` could then verify that each root's `.claude/settings.local.json` has `enabledPlugins["agent-workspace@<mkt>"]`, and `--uninstall` could disable the plugin. That keeps the owner's answer, since "register, then `make user-tier-install`" enables it. It also restores mechanical enforcement (finding 3), and #332 later calls the same function. Either way the change needs the owner's call. Severity: **High**.

2. **[Approach — dispatch prefix]** Step 6 prefixes skill names when `--type project` is set. But `--type` is the *issue/worktree* type, not the session root, and it defaults to `workspace`. The sub-agent inherits the *host's* skill set, which is fixed when the host session starts at its launch root. So:
   - A workspace session driving `/run-issue N --type project` has no plugin, only bare skills. That is the primary use case (project issues, and every p11-* issue driven from the workspace). The plan would hand every sub-agent `/agent-workspace:review-code`, which does not resolve there.
   - A project session (gz4d) driving `--type workspace` would get bare names and pick up the project's own same-named skill: the exact bug #345 fixes.
   - `$PWD` is not a safe substitute either. `/start-task` `cd`s the host into a worktree, so `$PWD` can say "project" in a workspace-launched session.
   - Codex hosts have no plugin and read SKILL.md by path, so a prefixed task line is wrong for them too.

   Suggested fix: `dispatch_phase.sh` takes an explicit `--skill-prefix <p>` that defaults to empty (bare, which is correct for workspace sessions and Codex). The run-issue SKILL.md, which is Claude-only, sets it from how it was itself loaded. `${CLAUDE_PLUGIN_ROOT}` expands only in plugin-loaded skill text (spike Q4), so a non-empty expansion means "loaded through the plugin, so prefix". That keeps `${CLAUDE_PLUGIN_ROOT}` confined to a Claude-only skill, as the owner's portability direction asks. Test all four combinations: workspace host with project issue, workspace host with workspace issue, project host with workspace issue, project host with project issue. Severity: **High**.

3. **[Consequences / enforcement — stale symlinks and `--check`]** Step 4 deletes the skill section of `--check` and relies on a cleanup at install/uninstall time. A machine that never re-runs install (the ROS machine, any other checkout) keeps shadowing project skills silently, and `make validate` stays green. The precedent here is the #328 tool-mapping hook: `--check` keeps reporting a leftover entry as drift. Do the same thing:
   - `--check` reports any `~/.claude/skills/*` symlink that points into *any* agent_workspace checkout as legacy drift. Keep `foreign_skill_link()`, because the plan's cleanup only matches `$WS_ROOT/.claude/skills/*` and would miss another checkout's links.
   - Leave non-symlinks and unrelated entries alone (e.g. `~/.claude/skills/synced/` on this machine).
   - Also `Makefile:161-162` (`generate-user-tier-skills` → `--sync-skills`) and its `.PHONY` entry must go or change, and `make generate-skills` must be re-run for the slash-command set. The plan does not list the Makefile.

   Severity: **High**.

4. **[Consequences — workspace root and p11-*]** Nothing in the plan prevents or tests the plugin being enabled where the bare skills already load. If that happens, every skill appears twice, bare and `agent-workspace:`. The risky case is concrete on this machine: `projects/p11-jazzy` and `projects/p11-rolling` have no `.git`. Their git toplevel is `/home/roland/agent_workspace`, and `.gitignore:10` ignores `projects/`. That leaves two things to verify, and the plan assesses neither:
   - (a) Whether a session launched at `projects/p11-jazzy` already loads the workspace's bare `.claude/skills` by walking up the directories. If it does, p11-* needs no plugin, and enabling it there duplicates everything.
   - (b) Whether `claude plugin install --scope local` run from there writes `projects/p11-jazzy/.claude/settings.local.json` or the git toplevel's `/home/roland/agent_workspace/.claude/settings.local.json`. The second would enable the plugin in every workspace session.

   Required: `--check` flags `agent-workspace@*` enabled in the workspace root's `.claude/settings.json` or `.claude/settings.local.json`, with a hermetic test. The enable step (finding 1) refuses a root whose resolved settings path is inside the workspace checkout, or skips a registered root under the workspace tree once (a) is confirmed. The live acceptance (finding 8) covers a p11-* session. Severity: **High**.

5. **[ADR compliance]** A new ADR-0017 superseding ADR-0016 §3 is correct. ADR-0016's own Status paragraph says that changing a Decision "takes a superseding ADR, not an edit here", and ADR-0008 agrees. Three corrections:
   - (a) The back-pointer must go into ADR-0016's **Status line and References**, not its Consequences section. ADR-0008 counts "adding … Consequences" as substantive. The existing ADR-0011 subsection in ADR-0016's Consequences is ADR-0016 recording its *own* supersession of 0011. The pattern ADR-0011 itself received was "a navigational pointer … and nothing more".
   - (b) Enabling the plugin writes `<project>/.claude/settings.local.json` inside the project checkout. ADR-0016 §2 says "the workspace never writes into a project checkout (beyond `.git/info/exclude` and an untracked `COLCON_IGNORE`)". The plan claims §2 is "untouched and in force". If the workspace (installer or registration) runs the enable commands, ADR-0017 must widen §2's exception list explicitly. If the owner runs them by hand, ADR-0017 must say so.
   - (c) ADR-0016's promotion condition is the gz4d `/run-issue` acceptance run, and that run will now go through plugin skills. ADR-0017 should state the relationship: the #317 run still promotes 0016, and it doubles as 0017's live acceptance or it does not. The issue review asked for this, and the plan omits it.

   Severity: **Medium**.

6. **[File targeting — Ask-First]** Step 9 proposes a "one-line correction" in `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md` and `.agent/AGENT_ONBOARDING.md`. None of these files mentions skill symlinks or the user tier: `grep -i 'symlink|user.tier|plugin'` finds only unrelated `scripts/` and `project/` symlink lines. There is nothing to correct, so the edits would be new instruction content. All five are Ask-First instruction files, and none is a Script Reference table row, which is the only pre-approved class (standing rule on #269). Recommend dropping them. ADR-0017, the principles-review-guide row, and WORKTREE_GUIDE.md or docs/design.md carry the mechanism. If a pointer is wanted for project sessions, the SessionStart hook's project-session header is the right place: it already reaches exactly those sessions and is not Ask-First. Its comment at lines 6-8 is also slightly stale. Any AGENTS.md/CLAUDE.md edit that stays in the plan needs explicit owner approval. Severity: **Medium**.

7. **[Approach — exposing all skills]** Step 2 calls exposing all skills "harmless but not useful". There are 22 skills, not 21. The claim is not accurate. `test_skill_paths.sh` enforces the `$WS_ROOT` idiom *only* for `session_scope: project|both` skills. The workspace-scoped ones (`audit-workspace`, `research`, `inspiration-tracker`, `skill-importer`, `analyze-permissions`, …) call `.agent/scripts/...` relative to the cwd. From a project session they either fail, or they run the *project's* same-named script. `~/project11/.agent/scripts` exists and is a fork of these scripts, and any future project may ship one. Curation does not need a second tree: `plugin.json` `skills` may take an array of per-skill directory paths. That needs checking with `claude plugin validate` plus a one-line spike; this review could not run it because the command was denied in this sandbox. If it does, generate or verify the list from `session_scope` in `test_plugin_manifest.sh`. If it does not, the plan must say what happens when a workspace-only skill is invoked from a project. Severity: **Medium**.

8. **[Tests — live acceptance]** Step 11 says the plugin behaviour "can't be asserted without a real `claude` CLI session" and keeps the check manual. The spike (`scratchpad/plugin-spike/spike.sh`) disproves that. It asserts collision, worktree inheritance, the unrelated-repo negative, namespaced invoke and sub-agent handoff headlessly, with `claude -p` in synthetic repos at `--scope local`, and cleans up with `cleanup.sh`. Recommendations:
   - Port it as an opt-in live script, e.g. `.agent/scripts/tests/live/plugin_acceptance.sh`, not collected by `run_script_tests.sh` because it needs auth and costs tokens.
   - Point it at the real workspace root, and add cases for (i) a session at the workspace root seeing each skill once, (ii) a session under a registered root *inside* the workspace tree (p11-* shape), and (iii) the dispatch prefix end to end.
   - Record its output in the PR.
   - `test_plugin_manifest.sh` should also run `claude plugin validate .` when `claude` is on PATH, and skip otherwise.

   Severity: **Medium**.

9. **[Consequences — bare cross-references]** 7 skills name each other with bare slash commands in prose (run-issue 10, start-task 12, review-plan 6, …). In a project session these names point at the project's own skill, or at nothing. The model will mostly map them correctly, but the plan should note the risk, or add a "workspace skills are `agent-workspace:`-prefixed in project sessions" line to the SessionStart project header (finding 6). Severity: **Low**.

10. **[Open questions]** The ADR number `0017` is free: there is no `001[7-9]` in any worktree or remote branch as of this review. Re-check just before committing the ADR. Opening the hooks follow-up issue now is cheap and makes the deferral durable. See the recommendations below. Severity: **Low**.

### Summary

The core mechanism (plugin, local scope, skills-only, new superseding ADR) is sound and matches the owner's choices. The plan is not ready to implement. It keys the skill prefix on the wrong signal, which breaks workspace-hosted project runs. It quietly replaces the owner's "enable in registration" answer. It removes `--check` enforcement without a replacement for stale links on other machines. It never assesses the workspace-root and p11-* duplicate/misplaced-enable hazard. And it proposes Ask-First instruction-file edits to text that does not exist.

### Recommended Actions

- [ ] Take the enable-step deviation to the owner. Recommend enabling the plugin from `user_tier_install.sh` for every registered root, with a matching `--check` and uninstall, over the manual documented step.
- [ ] Replace `--type`-keyed prefixing with an explicit `--skill-prefix` (default bare) that run-issue sets from `${CLAUDE_PLUGIN_ROOT}` expansion. Test all four host/issue-type combinations.
- [ ] Keep `--check` drift for legacy skill symlinks into any agent_workspace checkout (retain `foreign_skill_link`). Add the Makefile `generate-user-tier-skills` / `.PHONY` change and `make generate-skills` to the plan.
- [ ] Add a `--check` guard and hermetic test for `agent-workspace@*` enabled in the workspace root's settings. Verify how a p11-* session (under the workspace git tree) loads skills and where `--scope local` writes from there, then decide whether p11-* needs enabling.
- [ ] ADR-0017: put the pointer in ADR-0016's Status and References, not its Consequences. Address ADR-0016 §2's write-into-checkout rule. State the relationship to the #317 acceptance run.
- [ ] Drop the AGENTS.md / CLAUDE.md / adapter / AGENT_ONBOARDING.md edits, or get explicit owner approval for each.
- [ ] Verify whether `plugin.json` can list individual skill dirs. If it can, expose only `session_scope: project|both` skills and test the list against the frontmatter.
- [ ] Port the spike as an opt-in live acceptance script covering the workspace root, gz4d-shape and p11-shape roots, and an unrelated repo. Add `claude plugin validate` to the manifest test when `claude` is available.
