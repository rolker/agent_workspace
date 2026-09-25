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

## Checkpoint
**Status**: complete
**When**: 2026-09-24 15:02 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Accept all 8, revise (Recommended) — plan revision folds in all findings from the Plan Review at 956e633 and the reviewer's 8 recommended decisions: (1) user_tier_install.sh enables the plugin for each registered root, with --check and uninstall, #332 reuses it later; (2) accept writing the ignored .claude/settings.local.json into projects and record the exception in the new ADR; (3) p11 projects decided after a live check of what a session there already loads; (4) expose only project/both-scoped skills if plugin.json supports a list, otherwise all with workspace-only skills handled; (5) include start-task; (6) open the hooks follow-up issue now; (7) no instruction-file edits, any note goes in the SessionStart hook header; (8) plugin name agent-workspace confirmed. Then plan review round 2.

## Plan Authored
**Status**: complete
**When**: 2026-09-24 15:11 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Dispatch**: resumed (agent a92e944bf41c8ecfb, resume 1 of 3)
**Plan**: `.agent/work-plans/issue-345/plan.md` at `9828235`

Revision 2, folding in every finding from the round-1 Plan Review
(`956e633`, needs-work) and the owners accept-all-8-revise checkpoint:
skill prefix now an explicit `--skill-prefix` on dispatch_phase.sh set
from `${CLAUDE_PLUGIN_ROOT}` (not the wrong --type signal); the plugin is
enabled per registered root from user_tier_install.sh itself (install,
--check, --uninstall; #332 reuses the function), guarded against roots
that share the workspaces own git toplevel (confirmed live: p11-jazzy and
p11-rolling already see bare workspace skills by directory walk-up and
must never get the plugin); --check keeps legacy symlink-drift detection
(foreign_skill_link retained) instead of losing it; plugin.json exposes
only session_scope project|both skills (generated + cross-checked against
frontmatter), verified with claude plugin validate; the Makefile
generate-user-tier-skills target and make generate-skills are now in
scope; ADR-0017s pointer moves to ADR-0016s Status/References (not
Consequences) and records the ADR-0016 section 2 write-into-checkout
exception plus the relationship to the #317 acceptance run; the
hooks-into-plugin follow-up issue is opened now (host action); no
AGENTS.md/CLAUDE.md/adapter edits (dropped; a one-line note goes in the
SessionStart hook header instead); a live acceptance script is ported
from the spike as an opt-in suite.

## Plan Review
**Status**: complete
**When**: 2026-09-24 15:22 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a027be12a6ebddfcd, resume 1 of 3)
**Verdict**: ready

**Issue**: #345 — User-tier skill symlinks replace a project's own same-named skills in unregistered repos
**Plan**: `.agent/work-plans/issue-345/plan.md` at `9828235`
**Branch**: `feature/issue-345`

Round 2. It checks the plan against the round-1 review (`956e633`) and the owner's accept-all-8 checkpoint.

### Round-1 findings

| # | Finding | Resolved? |
|---|---|---|
| 1 | Enable step: manual step instead of "in registration" | Yes. Step 5 enables per registered root from `user_tier_install.sh` (install, `--check`, `--uninstall`), and #332 reuses it. |
| 2 | Prefix keyed on `--type` | Yes in design. Step 7 adds an explicit `--skill-prefix` (default bare) and tests the four combinations. The detection rule needs pinning down (new finding A). |
| 3 | `--check` loses drift detection; Makefile | Yes. `foreign_skill_link` and removal are kept, and `--check` reports legacy links. The Makefile is in scope, but its fate is left open (new finding E). |
| 4 | Workspace-root and p11 duplicates | Yes. There is a toplevel-equality skip, a stale-enable error in `--check`, and a live workspace-root case. |
| 5 | ADR placement, §2, #317 | Yes. (a), (b) and (c) are all in step 9. |
| 6 | Ask-First instruction edits | Yes. They are dropped. |
| 7 | Expose only project/both skills | Yes. The array is generated and cross-checked, and the glob fallback is documented. The count in the plan text is wrong (new finding F). |
| 8 | Scripted live acceptance | Yes. Step 13 ports the spike as an opt-in suite and adds `claude plugin validate`. |
| 9 | Bare cross-references in prose | Partly. The note goes into the hook's *source comment*, which the model never sees (new finding D). |
| 10 | ADR number / hooks issue | Yes. The number is re-checked at commit time, and the hooks follow-up is opened as #351. |

The owner's 8 decisions are all implemented as stated. Decision 3 (p11) was settled by the live walk-up check: p11 never gets the plugin.

### Findings

A. **[Approach — prefix detection, Medium]** Step 7 sets the prefix "when `${CLAUDE_PLUGIN_ROOT}` is non-empty in its own rendered text". Spike Q4 proved only the plugin-loaded case, where the variable is substituted with the source directory. The bare case, run-issue loaded from the workspace's `.claude/skills`, was never tested. In that case the token is most likely left *literal*. A literal `${CLAUDE_PLUGIN_ROOT}` string is non-empty, so a naive test fires in exactly the session that must stay bare. And if the token lands unquoted in a Bash command, the shell expands it from the environment, which may be set by some *other* enabled plugin. The user has `clangd-lsp` enabled at user scope. Specify a rule that works whether or not the token is substituted:
- Emit it single-quoted, e.g. `PR='${CLAUDE_PLUGIN_ROOT}'`, so the shell never expands it.
- Prefix only if `"$PR" == "$WS_ROOT"` after `pwd -P` normalisation. The plugin source is the workspace root, and comparing against it beats testing for "non-empty" or "starts with /".

Add the bare-load case to step 13's live suite: a workspace-root session's run-issue must produce bare names. That is the one behaviour the design rests on that nobody has observed yet.

B. **[Approach — toplevel guard, Medium]** Step 5's skip condition is `git -C <root> rev-parse --show-toplevel == $WS_ROOT`. The installer builds `$WS_ROOT` from a plain `cd && pwd`, which keeps symlinks, while git returns the resolved physical path. So a checkout reached through a symlinked path never matches, and p11 would get enabled into the workspace-root `settings.local.json`, the exact hazard the guard exists for. Compare `pwd -P` forms on both sides. Also define:
- a root that is not in any git repo (rev-parse fails): enable, not skip, and not an error;
- `parent=` pseudo-roots versus their instances: say which one gets enabled.

C. **[Approach — installer runs the `claude` CLI, Medium]** Step 5 has `install`, `--check` and `--uninstall` call `claude plugin ...`, but the plan does not cover three things:
- **No `claude` on PATH.** On a Codex-only or ROS machine, install must skip with a note and exit 0. `--check`'s per-root check reads JSON only and must not need the CLI.
- **Idempotency.** Re-running `marketplace add` or `install` when already enabled must be a no-op. Check `enabledPlugins` first.
- **Tests.** `test_user_tier_install.sh` must put a stub `claude` on PATH that records its argv. It must never invoke the real CLI, which writes real settings and costs a session.

D. **[Consequences — model-visible note, Low]** Step 11 adds the "workspace skills are `agent-workspace:`-prefixed here" line to the hook's header *comment*. Round-1 finding 9 needs it in the hook's *printed* project-session header, which the model reads. Owner decision 7 says "in the SessionStart hook header", which fits the printed header. If the line is printed, `test_session_start_layer.sh` needs one assertion for it.

E. **[File targeting — Makefile, Low]** Step 8 and the Open Questions leave the `generate-user-tier-skills` target as either "repoint to `--check`" or "retire". The target has a natural new job: regenerate `plugin.json`'s `skills` array. That is the generator step 2 needs a home for, and the target's own comment ("derived from session_scope frontmatter") already describes it. Recommend that option, so step 2's generator is not a second, unnamed entry point.

F. **[Plan text, Low]** Step 2 says "14 of 22 … the other 8" and lists `what-next` as workspace-scoped. On disk, 13 skills declare `project|both`, and `what-next` is `both`. The other 9 are analyze-permissions, audit-workspace, brainstorm, brand-guidelines, gather-project-knowledge, inspiration-tracker, issue-triage, research and skill-importer. The generator makes this moot for the manifest, but the ADR and PR text should not copy the wrong count.

### Summary

Every round-1 finding is addressed, and all 8 owner decisions are carried out faithfully. The plan is ready to implement. A, B and C are implementation-level corrections, not structural ones. A matters most because the whole prefix design rests on it. Carry A–C into the implementation and verify A live before the prefix is wired into run-issue.

### Recommended Actions

- [ ] Detect plugin loading with a single-quoted `${CLAUDE_PLUGIN_ROOT}` compared to `$WS_ROOT` (`pwd -P`). Add the bare-load case to the live suite.
- [ ] Compare `pwd -P` forms in the toplevel skip guard. Define the no-git-root and `parent=` behaviour.
- [ ] Make the installer's `claude plugin` calls optional when the CLI is absent, idempotent, and stubbed in tests.
- [ ] Put the prefix note in the hook's printed project header, and assert it in the hook's test.
- [ ] Repurpose `generate-user-tier-skills` to regenerate the `plugin.json` skills array.
- [ ] Fix step 2's skill count and the `what-next` classification.

## Checkpoint
**Status**: complete
**When**: 2026-09-24 15:20 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Approve, start implementing now — dispatch the implementation now (owner accepted it will likely run past 15:30); the implementer folds in round-2 Plan Review findings A–F (5fadd1a).

## Implementation
**Status**: complete
**When**: 2026-09-25 08:38 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-345 at `28d15be`

Resumed pass. It adds 5 commits on top of the 2 from the interrupted pass (8e14d33 --skill-prefix, e6266ce the printed SessionStart note). Main had not moved.

- 6d8682f: the `.claude-plugin/` manifests. The plugin ships 13 `project|both` skills as a generated per-skill array, and `claude plugin validate` accepts that form. New `test_plugin_manifest.sh` re-derives the list independently. It also asserts that only skills ship: no default component dirs, no other manifest keys.
- a564d97: `user_tier_install.sh`. It enables the plugin at local scope per registered root. The skip guard compares `pwd -P` forms and skips p11-shape roots (B). A root with no git repo is enabled, and so is a parent root; its `parent=` instance is skipped. With no CLI, install notes and exits 0. `--check` reads JSON only. Enabling is idempotent and the result is verified from the file (C). Also: the workspace-root self-enable guard, legacy symlink removal and drift reporting, and `--generate-plugin-manifest`, which the Makefile target now runs (E). The claude stub in the tests brings the suite to 111 passing.
- 6e8111a: run-issue detects the prefix with a single-quoted `${CLAUDE_PLUGIN_ROOT}` compared to `$WS_ROOT` in `pwd -P` form (A).
- c5a1291: ADR-0017, plus pointers from ADR-0016 (Status and References only), the principles guide and design.md. The ADR carries the correct 13/9 count (F).
- 28d15be: the opt-in live suite, `tests/live/plugin_acceptance.sh`. One run (claude 2.1.282, haiku) passed 10 of 10. That run includes the bare-load case: there `${CLAUDE_PLUGIN_ROOT}` stays literal, so the prefix is empty. AGENTS.md: `--skill-prefix` added to the dispatch_phase row.

Tests: `run_script_tests.sh` passes all 30 suites.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-25 08:56 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-345 at `63e0944`
**Base**: main
**Depth**: Deep (reason: governance/enforcement files — ADR-0016/0017, user-tier installer, dispatch_phase.sh, SessionStart hook; 19 files, +2127/-167)
**Must-fix**: 3 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 3 must-fix; first round always re-reviews after fixes

Reviewers: Claude adversarial ran; Codex ran (3 findings, all confirmed); Gemini failed (agy response exceeded its output token limit); Copilot skipped (quota exhausted Sept 2026). Static: shellcheck (pre-commit) passed; hermetic suites pass (install 111, manifest 12, dispatch 112, session-start 46).

### Findings
- [x] (must-fix) `disable_plugin_in_root` returns 0 when the claude CLI is absent, so `--uninstall` says "removed" and install says success while the plugin stays enabled (a doubled workspace-root enable included); return 1 when a present plugin cannot be removed (Codex) — `.agent/scripts/user_tier_install.sh:511`
- [x] (must-fix) `--uninstall` ignores a root whose settings.local.json is `unparseable` and exits 0; report it and exit non-zero, leaving the file alone (Codex) — `.agent/scripts/user_tier_install.sh:552`
- [x] (must-fix) live suite `has_probe` discards the session's exit status, so a timeout/auth/CLI failure passes the negative isolation case C (unrelated repo has no plugin); fail the case when the session itself failed (Codex) — `.agent/scripts/tests/live/plugin_acceptance.sh:122`
- [x] (suggestion) `plugin_state` "stale" also covers a root enabled from ANOTHER checkout, and `--uninstall` removes it; either restrict uninstall to roots sourced from this checkout, or state it as intended — and record in ADR-0017 Consequences that the marketplace name is one-source-per-machine (`~/.claude/plugins/known_marketplaces.json` is keyed by name, so --check can say "enabled" from settings.local.json while another checkout's record is what loads) — `.agent/scripts/user_tier_install.sh:448-462,543-558`
- [x] (suggestion) `skip-instance` assumes a session inside a `parent=` instance sees the parent's local-scope settings; that is unverified live, and the registry does not require an instance path to lie under its parent, so a mis-nested instance gets no plugin while the SessionStart header still promises `/agent-workspace:` and --check stays clean; verify (live case) or validate containment and flag it in --check — `.agent/scripts/user_tier_install.sh:427`, `.claude/hooks/session_start_project_layer.sh:102`
- [x] (suggestion) only one enabled root is exercised against the real CLI; a second `marketplace add` of the same name/source from another root (the #332 path) is untested — add a second project root to the live suite — `.agent/scripts/tests/live/plugin_acceptance.sh:111`
- [x] (suggestion) live-suite header says it removes what it adds on exit; the two records do go, but a copy of the checkout stays in `~/.claude/plugins/cache/aw-accept/` (orphan-marked by Claude Code, seen after the implementer's run); remove that cache dir in `cleanup()`, or state in the header that Claude Code's orphan sweep clears it (unverified) — `.agent/scripts/tests/live/plugin_acceptance.sh:13,59-65`
- [x] (suggestion) the `claude plugin` calls do not redirect stdin, so if a CLI version asks for a trust prompt the installer hangs instead of failing; add `</dev/null` — `.agent/scripts/user_tier_install.sh:493-516`

## Implementation
**Status**: complete
**When**: 2026-09-25 09:40 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-345 at `3d7b698`
**Addressed**: Local Review (Pre-Push) at `63e0944` (2026-09-25 08:56 -04:00)
**Commits**: 945b83b, ee4150a, d59f473, af1b6d5, 2b1aed5, f8bb651, 9d15cf5, 3d7b698

### Actions
- [x] No-CLI disable now returns 1 with an ERROR, so `--uninstall` and install over a doubled root exit 1 instead of claiming success; ADR-0017 updated — `.agent/scripts/user_tier_install.sh` `disable_plugin_in_root` (945b83b)
- [x] An unparseable settings.local.json is reported, left untouched and exits 1 in `--uninstall`, and also in install/`--check` for a skipped workspace-toplevel root and the workspace checkout itself (the same silent pass-over) — `.agent/scripts/user_tier_install.sh` `unparseable_root` (ee4150a)
- [x] Live suite `probe()` returns reached / not reached / session failed; every negative demands "ran, not reached", C runs a control skill in the unrelated repo first, A and F check exit status; new hermetic `test_plugin_acceptance_helpers.sh` pins probe() against a stub claude — `.agent/scripts/tests/live/plugin_acceptance.sh` (d59f473)
- [x] New `foreign` plugin state: `--uninstall` leaves another checkout's declaration with a note, `--check` names the other checkout, install still repoints registered roots and clears doubled ones; `--check` also reads `~/.claude/plugins/known_marketplaces.json` (read-only) and flags a record naming another checkout; ADR-0017 records one-source-per-machine — `.agent/scripts/user_tier_install.sh` `plugin_state`, `uninstall_plugin_from` (af1b6d5)
- [x] `parent=` instance skipped only when its path lies inside the parent's (`pwd -P`); a mis-nested one is enabled as its own root with a note and `--check` holds it to that; live case G checks the containment assumption itself — `.agent/scripts/user_tier_install.sh` `plugin_roots`, `path_inside` (2b1aed5)
- [x] Live case H enables a second root from the same source and re-probes both — `.agent/scripts/tests/live/plugin_acceptance.sh` (f8bb651)
- [x] Live suite `cleanup()` removes `~/.claude/plugins/cache/aw-accept` (only after an enable); helpers test pins it removes nothing beside it — `.agent/scripts/tests/live/plugin_acceptance.sh` (9d15cf5)
- [x] Every `claude plugin` call goes through `claude_plugin()` with `</dev/null`; the mutation run showed a stdin-reading CLI would also consume the `while read < <(plugin_roots)` loop input and skip later roots; the live suite's plugin calls and `claude -p` sessions redirect too — `.agent/scripts/user_tier_install.sh` (3d7b698)

Tests: install suite 111 -> 130, new helpers suite 9; `run_script_tests.sh` 31/31 suites pass. Each new test was mutation-checked (fix broken, test fails, fix restored). The live suite was edited but not run: its 10/10 result predates these changes, and the new cases G (parent= instance) and H (second root) have never run live.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-25 09:47 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-345 at `2662178`
**Base**: main
**Depth**: Deep (reason: governance/enforcement files — ADR-0016/0017, user-tier installer, dispatch_phase.sh, SessionStart hook; 20 files, +2717/-166)
**Must-fix**: 1 | **Suggestions**: 4
**Round**: 2 | **Ship**: continue — round 2: 1 must-fix includes a design/correctness concern (not mechanical)

Round-1 fixes verified: all 8 close their findings (no-CLI removal errors, unparseable uninstall, tri-state probe, foreign state, containment check, case H, cache cleanup, stdin closed); each has a hermetic test. Reviewers: Claude adversarial ran; Codex ran (2 findings: 1 confirmed must-fix, 1 kept as suggestion); Gemini ran (4 suggestions: 2 false positives — selected_skills already reads only frontmatter and strips quotes — 1 duplicate of the must-fix, 1 dropped as needing a broken install); Copilot skipped (quota exhausted Sept 2026). Static: shellcheck --severity=warning clean on changed scripts; hermetic suites pass (install 130, acceptance helpers 9, manifest 12, dispatch 112, session-start 46). Live suite not run (cases G/H never run live).

### Findings
- [x] (must-fix) the new --check machine-record drift (known_marketplaces.json names another checkout) cannot be cleared by its own advice: install short-circuits on roots already `enabled` from this checkout and never runs the CLI, so after the other checkout is deleted or its --uninstall leaves the record, --check stays red forever; repoint (run `marketplace add` in one root when the record is foreign) or give the exact live-verified command, plus a test of install after the fixture (Codex, Claude, Gemini; caused by round-1 fix) — `.agent/scripts/user_tier_install.sh:540,840-852`
- [x] (suggestion) `skip-instance` roots get no local-state check in install or --check (unparseable, foreign or stale settings.local.json pass silently) while ADR-0017 now says install and --check exit 1 on an unparseable file in any skipped root; add the case or narrow the ADR sentence (Codex; ADR wording from round-1 fix) — `.agent/scripts/user_tier_install.sh:984,803-826`, `docs/decisions/0017-plugin-based-skill-delivery.md`
- [x] (suggestion) a declaration whose source path no longer exists is classed `foreign`, so --uninstall leaves it "for that checkout's --uninstall", which can never run; treat a source not on disk as removable, or call it orphaned in the note (caused by round-1 fix) — `.agent/scripts/user_tier_install.sh:486-503,601`
- [x] (suggestion) notes misdescribe two cases: an instance at the same path as its parent, or whose parent is not on disk, is told it is "outside its parent's directory"; and a foreign/stale declaration without an enable in a skipped root is reported as "enabled ... every skill loads twice" (caused by round-1 fixes) — `.agent/scripts/user_tier_install.sh:458-477,823,836`
- [x] (suggestion) live case G uses plain directories for the parent and instance, so the likely real shape (parent a git repo, instance a separate repo or worktree inside it) is not the one that validates skip-instance; `git init` the parent (caused by round-1 fix) — `.agent/scripts/tests/live/plugin_acceptance.sh:297-313`

## Implementation
**Status**: complete
**When**: 2026-09-25 10:11 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-345 at `9d5d4f7`
**Addressed**: Local Review (Pre-Push) at `2662178` (2026-09-25 09:47 -04:00)
**Commits**: 4871f3b, df7556a, ae1bf86, d941118, 9d5d4f7

### Actions
- [x] Last install wins (owner's choice): when `known_marketplaces.json` names another checkout, install re-enables the first enabled root (remove + add + install), which takes the name over; later roots short-circuit again. The record is read back after every add, and one the CLI left elsewhere is an error. `--check` flags the record only while some root is enabled from this checkout, because with none install has nowhere to repoint from. The stub now writes the machine record on `marketplace add` (`STUB_NO_KM=1` turns that off). ADR-0017 records the rule and says the CLI's replacement of the record is not yet live-verified — `.agent/scripts/user_tier_install.sh` `machine_record_foreign`, `enable_plugin_in_root` (4871f3b)
- [x] A skip-instance root with an unparseable settings.local.json now fails install and `--check`. The ADR's `--check` list is narrowed: a doubled enable is reported for a workspace-toplevel root only — `.agent/scripts/user_tier_install.sh`, `docs/decisions/0017-plugin-based-skill-delivery.md` (df7556a)
- [x] A declaration whose source is not on disk is `stale`, not `foreign`: `--check` reports it as not enabled from this checkout, and `--uninstall` removes it. ADR updated — `.agent/scripts/user_tier_install.sh` `plugin_state` (ae1bf86)
- [x] An instance whose parent is not on disk says so, not "outside its parent's directory". The same-path and unregistered-parent cases cannot reach the installer, because the registry parser drops both. A leftover declaration without an enable in a workspace-toplevel root or the checkout itself is now called a leftover, not "loads twice", and install still removes it — `.agent/scripts/user_tier_install.sh` `plugin_roots`, `plugin_enabled_flag` (d941118)
- [x] Live case G also probes a git-repo parent with a separate-repo instance and a worktree instance inside it. The case was edited but not run — `.agent/scripts/tests/live/plugin_acceptance.sh` (9d5d4f7)

Tests: install suite 130 -> 143, acceptance helpers 9. The full script suite passed in each commit's pre-commit hook. Each new test was mutation-checked: fix broken, test fails, fix restored. New paths tested: a single repoint across several enabled roots, a CLI that does not repoint (error), and a foreign record with no own-enabled root (not drift). Paths not covered: a foreign record on a machine with no claude CLI, where install notes and `--check` stays red. A source on a temporarily unmounted path now counts as stale, so `--uninstall` removes it.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-25 10:17 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ac5f93dbe244f722a, resume 1 of 3)

**Branch**: feature/issue-345 at `14a0bc7`
**Base**: main
**Depth**: Deep (reason: governance/enforcement files — ADR-0016/0017, user-tier installer, dispatch_phase.sh, SessionStart hook; 20 files, +2965/-164)
**Must-fix**: 1 | **Suggestions**: 6
**Round**: 3 | **Ship**: continue — round 3: 1 must-fix includes a design/correctness concern (not mechanical)

Round-2 fixes verified: all 5 close their findings, each with a hermetic test (install suite 143, helpers 9, manifest 12, session-start 46 pass; shellcheck --severity=warning clean). Registry output: the optional 4th `detail` field of plugin_roots is read by install and --check and absorbed harmlessly by --uninstall's `_verdict`; no other caller. Reviewers: Claude adversarial ran (fresh; 1 must-fix, 2 suggestions, all reproduced against a patched stub); Codex ran (3 must-fix claims: 1 kept as a suggestion, 2 downgraded to suggestions as rare/pre-existing); Gemini ran (5 suggestions: 1 duplicate, 1 kept, 3 dropped — frontmatter parsing already bounded and quote-stripping, fixed plugin name, source-without-path edge); Copilot skipped (quota exhausted Sept 2026). Live suite not run.

### Findings
- [x] (must-fix) a failed machine-record takeover strips the marketplace declaration from EVERY enabled root: an `enabled` root now runs `marketplace remove` before `marketplace add`, and when add fails (or the CLI does not repoint the record) `machine_record_foreign` stays true, so each later root is removed too — reproduced with a refusing stub, four working roots left undeclared; attempt the takeover in one root per run, leave the rest alone after a failure, and add a refusing-add stub mode asserting the other roots survive (Claude adversarial; caused by round-2 fix) — `.agent/scripts/user_tier_install.sh:574-600`
- [x] (suggestion) with no claude CLI on PATH a foreign machine record keeps --check red with advice ("re-run this installer") that cannot help, and install says "not enabling" for roots already enabled; gate the machine-record drift on have_claude as the `*` branch does, and reword the no-CLI note (Claude adversarial, own review; caused by round-2 fix) — `.agent/scripts/user_tier_install.sh:574-583,906`
- [x] (suggestion) a source on a temporarily unmounted path is now `stale`, so this checkout's --uninstall removes another checkout's plugin from a shared root, the one thing uninstall promised not to do; acceptable if unmounted checkouts are out of scope, but ADR-0017 should say so (it implies only a deleted checkout) (Claude adversarial; caused by round-2 fix) — `.agent/scripts/user_tier_install.sh:520`, `docs/decisions/0017-plugin-based-skill-delivery.md:123`
- [x] (suggestion) a skip-instance root is checked only for unparseable JSON; an instance with its own enabled or foreign declaration is ignored by install and --check, and if its local settings shadow the parent's, it loads the other checkout's skills while --check is clean; flag enabled/foreign there (Codex, Gemini; not caused by round-2 fix — round 2 narrowed the gap) — `.agent/scripts/user_tier_install.sh:1040,875`
- [x] (suggestion) the live suite's `claude -p` probes leave one Claude Code project dir per probed path (transcripts and a `memory/` dir) under ~/.claude/projects, named from the sandbox path: two earlier runs left 10 (92-276K each), and the round-2 G/H cases add about 5 more per run; cleanup() should remove the dirs derived from $SANDBOX (guarded by its unique mktemp prefix), or the header should say they stay (own review; not caused by round-2 fix, extended by it) — `.agent/scripts/tests/live/plugin_acceptance.sh:78-95`
- [x] (suggestion) --uninstall exits "nothing installed" before the plugin loop when the root file, hook link and ~/.claude/settings.json are all absent, so plugin enables left in registered roots survive; rare (settings.json almost always exists), check the roots before that return (Codex; not caused by round-2 fix) — `.agent/scripts/user_tier_install.sh:649-651`
- [x] (suggestion) live case B puts the worktree inside the project ($P/worktrees/wt), so it cannot tell directory walk-up from git-worktree inheritance; add a sibling worktree outside $P, and note that two concurrent live runs share the `aw-accept` name and cache (Gemini, Codex; not caused by round-2 fix) — `.agent/scripts/tests/live/plugin_acceptance.sh:227,90`

## Checkpoint
**Status**: complete
**When**: 2026-09-25 10:22 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Structural fix + round 4 — take over the machine-wide plugin record (known_marketplaces.json) once per run as its own step before any per-root work; a failed takeover stops install before touching any project. Fold in the 6 round-3 suggestions, then one more pre-push review.

## Implementation
**Status**: complete
**When**: 2026-09-25 10:55 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-345 at `cc5973d`
**Addressed**: Local Review (Pre-Push) at `14a0bc7` (2026-09-25 10:17 -04:00)
**Commits**: 0ad8a67, e816b87, 1fad013, 08fdf9b, ecf8949, 4ce1635, cc5973d

### Actions
- [x] Structural fix (owner's checkpoint decision): the machine-level marketplace record is now one step, run once before any project root. When it names another checkout and some root is to be enabled, install runs one `marketplace add` from a throwaway directory outside every project and git repository, then reads the record back. A refused add, or one that leaves the record elsewhere, exits 1 with no root touched. The per-root loop handles each root's own declaration only. Removed: the per-root takeover in `enable_plugin_in_root` (remove + add of an enabled root) and its post-add record check. ADR-0017 describes the two-part structure — `.agent/scripts/user_tier_install.sh` `claim_machine_record`, step 6a (0ad8a67)
- [x] No CLI + foreign record: `--check` now gives a note, not drift, and says the claude CLI is needed. Install notes the same and reports enabled roots as "already enabled" — `.agent/scripts/user_tier_install.sh` (0ad8a67, e816b87)
- [x] ADR-0017 says a source on an unmounted drive or share is treated as stale and is out of scope — `docs/decisions/0017-plugin-based-skill-delivery.md` (1fad013)
- [x] A `parent=` instance that declares the plugin itself (this checkout's or another's) is drift in `--check`, and install removes it. Without the CLI that removal is an error — `.agent/scripts/user_tier_install.sh` skip-instance (08fdf9b)
- [x] `--uninstall` looks at the registered roots before saying "nothing installed" — `.agent/scripts/user_tier_install.sh` `plugin_anywhere` (ecf8949)
- [x] The live suite's cleanup removes the `~/.claude/projects` dirs its sessions leave. It matches only the sandbox path's exact encoded name, or that name plus `-`, and only for a sandbox with the suite's `aw-plugin-accept.XXXXXXXXXX` mktemp name. A helpers test pins exactly what it removes. Existing leftovers are untouched — `.agent/scripts/tests/live/plugin_acceptance.sh` `session_dirs` (4ce1635)
- [x] Live case B's worktree is now a sibling of the project. The plugin name is now `aw-accept-<pid>` per run, and the helpers test pins that names differ between runs and that cleanup removes only its own cache — `.agent/scripts/tests/live/plugin_acceptance.sh` (cc5973d)

Tests: install suite 143 -> 158, acceptance helpers 9 -> 12. The full script suite passed in each commit's pre-commit hook. Every new test was mutation-checked, and each mutation made a test fail. The mutations were: carry on after a failed takeover; skip the read-back; drop the git-repo guard; claim with no root to enable; keep the scratch dir; drift regardless of CLI; claim without CLI; the instance check and removal each off; the uninstall early exit unguarded; a broader session-dir glob; no mktemp-name guard; no session-dir removal; a fixed plugin name. New paths opened and tested: the scratch directory (removed afterwards; refused inside a git repo), no takeover with no root to enable, the no-CLI takeover note, and no-CLI removal of an instance declaration (exit 1). Not verified live: that `marketplace add` from a scratch directory repoints the CLI's record (read back and fails safe if not), and case B in its new form. The live suite was not run.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-25 11:05 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ac5f93dbe244f722a, resume 2 of 3)

**Branch**: feature/issue-345 at `6cbe185`
**Base**: main
**Depth**: Deep (reason: governance/enforcement files — ADR-0016/0017, user-tier installer, dispatch_phase.sh, SessionStart hook; 20 files, +3389/-165)
**Must-fix**: 1 | **Suggestions**: 7
**Round**: 4 | **Ship**: recommended — round 4: 1 mechanical must-fix (prev 1), not rising; fix and ship rather than another full round

The structural fix closes the regression chain: the machine record is claimed once (step 6a) from a scratch dir, read back, and a failure exits 1 before any root; the per-root takeover and its post-add check are fully gone (no dead code); the failed-takeover test compares every root byte for byte and asserts no CLI call ran in any root. All 6 round-3 suggestions are closed. Hermetic suites pass (install 158, helpers 12, manifest 12, session-start 46, dispatch 112); shellcheck --severity=warning clean. The claim path, instance removal and new case B have not run live. Reviewers: Claude adversarial ran (fresh; 0 must-fix, 4 suggestions); Codex ran (3 must-fix claims: 1 confirmed, 2 downgraded to suggestions); Gemini ran (5: 1 false positive repeated from round 2 — run-issue prefix without the user tier cannot occur, since uninstall removes the plugin too — 4 dropped as low value or contradicted by round-1 observation); Copilot skipped (quota exhausted Sept 2026).

### Findings
- [x] (must-fix) live suite: if `mktemp -d` fails, SANDBOX is empty, `cd ""` succeeds in bash, and SANDBOX becomes the cwd (verified), so the EXIT trap's `rm -rf "$SANDBOX"` deletes the directory the suite was started from, possibly the checkout; abort when mktemp or the cd fails, before the trap is set (Codex; not caused by a round-3 fix, the pattern predates it) — `.agent/scripts/tests/live/plugin_acceptance.sh:74-75`
- [x] (suggestion) nothing re-reads the machine record after step 6b, though 6b still runs `marketplace remove --scope local` (repointing a foreign/stale root, and disable in skip-workspace/skip-instance roots and the checkout); if a local remove also drops the machine record, as the live-suite header implies, a successful takeover is undone while install exits 0 and --check stays green (a missing entry "says nothing"); read back after 6b, or pin the CLI behaviour in a live case (Claude adversarial; caused by a round-3 fix: yes, the two-step structure) — `.agent/scripts/user_tier_install.sh:~1115-1162`
- [x] (suggestion) instance-declaration removal runs `marketplace remove --scope local` from the instance dir with no git-toplevel guard; for a plain subdirectory of a git-repo parent the CLI's local scope may resolve to the parent, stripping the parent's working enable on every run (claim_machine_record guards against exactly this) (Claude adversarial, own review; caused by a round-3 fix: yes) — `.agent/scripts/user_tier_install.sh:1134-1144`
- [x] (suggestion) step 6a claims the name whenever some root has an enable verdict, even when every such root is unparseable and will fail, moving the other checkout's sessions for nothing; require one enable root whose state is not `unparseable` (Claude adversarial; caused by a round-3 fix: yes) — `.agent/scripts/user_tier_install.sh:1107-1108`
- [x] (suggestion) KNOWN_MARKETPLACES is always under $HOME/.claude, but the CLI stores its records under CLAUDE_CONFIG_DIR when set; with it set, a stale ~/.claude record makes the claim's read-back fail every time and install now stops before any root; honour CLAUDE_CONFIG_DIR for this read, or refuse it up front (Codex; the $HOME/.claude assumption predates round 3, and the claim step made it block every root: partly caused) — `.agent/scripts/user_tier_install.sh:111,122`
- [x] (suggestion) an instance with `enabledPlugins[id] = false` and no declaration is classed `absent`, so the new skip-instance check misses an explicit local disable that could block the parent's plugin (Codex; not caused by a round-3 fix) — `.agent/scripts/user_tier_install.sh:528`
- [x] (suggestion) test gaps in round-3 tests: the helpers test's `enc()` copies the implementation's sed, so pin a known real encoding (`/a/b_c.d` -> `-a-b-c-d`); `stale_enable` writes a complete enable (state `enabled`), so the instance loop never sees a real `stale`; the session-dir fixture still names the old `proj-worktrees-wt` and not the new `proj-wt` (Claude adversarial; caused by a round-3 fix: yes) — `.agent/scripts/tests/test_plugin_acceptance_helpers.sh:~139`, `.agent/scripts/tests/test_user_tier_install.sh:~724`
- [x] (suggestion) no live case runs claim_machine_record, so it is unverified that a scratch-dir `marketplace add --scope local` repoints the record and that the record survives the scratch dir's removal (no orphan sweep); `claim_machine_record` also has no trap, so an interrupt leaves `agent-workspace-claim.*` in TMPDIR (Claude adversarial, own review; caused by a round-3 fix: yes) — `.agent/scripts/user_tier_install.sh:582-611`, `.agent/scripts/tests/live/plugin_acceptance.sh`

## Checkpoint
**Status**: complete
**When**: 2026-09-25 11:10 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Fix all, live test, review — fix the round-4 must-fix (live-suite mktemp/cd guard before the trap) and all 7 suggestions, then run the live suite once (renamed plugin copy in ~/.claude/plugins, cleaned up after), fix what it shows, then a final pre-push review.

## Implementation
**Status**: complete
**When**: 2026-09-25 12:08 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a4f2b47b9f324e986, resume 1 of 3)

**Branch**: feature/issue-345 at `c8b8581`
**Addressed**: Local Review (Pre-Push) at `6cbe185` (2026-09-25 11:05 -04:00)
**Commits**: cd6c2f4, 30bcef9, 9471a2b, 4cdf625, c007eda, 1f8040e, ed8af2f, 25d7b33, 741e776, c8b8581

### Actions
- [x] (must-fix) The live suite creates its sandbox through `new_sandbox()`, which fails on a failed or silent mktemp or cd, and exits before the EXIT trap is set. `cleanup()` refuses to delete anything that lacks the suite's mktemp name, is `/`, is the cwd, or contains the cwd. Both are pinned in the helpers suite — `.agent/scripts/tests/live/plugin_acceptance.sh` (cd6c2f4)
- [x] Machine record read back after step 6b (step 6c): if it named this checkout before and no longer does, it is taken back once, and install exits 1 if that fails. Live case J showed a local `marketplace remove` does drop the record, and that the other root stops reaching the plugin until the record is taken back — `.agent/scripts/user_tier_install.sh` (4cdf625)
- [x] One `enclosing_repo()` guard is shared by the claim scratch dir and instance removal. Install never runs the CLI from an instance that is a plain directory inside a git repo; it names the file to edit and exits 1, and `--check` gives the same advice. Live case K confirmed local scope from such a directory resolves to the git toplevel (c007eda)
- [x] Step 6a claims the name only when some enable root is not unparseable (30bcef9)
- [x] The CLI's record is read under `CLAUDE_CONFIG_DIR` when set. Observed with claude 2.1.282 using an isolated config dir (the real `~/.claude` was untouched). Install and `--check` note that the rest of the user tier stays in `~/.claude` (9471a2b)
- [x] An instance's `enabledPlugins[id] = false` is reported as a note by `--check` and install, and left alone because it may be deliberate (1f8040e)
- [x] Three test gaps closed: a literal encoding pin, the two genuinely stale fixtures, and `proj-wt` (ed8af2f)
- [x] The claim step has an INT/TERM trap that removes its scratch dir (a TERM test covers it). Live cases I/J/K added. `cleanup()` removes the machine record of this run's name if it is left behind, and only that name (25d7b33)

### Found by the live run and fixed
- Case G disproved skip-instance. A session reads the local settings of its git toplevel (the main repo's, for a worktree). The installer now skips an instance only when it shares its parent's git common dir, and enables every other instance as its own root. The installer's verdicts are asserted against the live sessions. ADR-0017 is rewritten for this, and records that a colcon-style package repo nested in a root does not see the root's plugin (741e776, c8b8581)
- Case A failed because haiku did not echo a loosely worded marker. The markers now use the probe's exact-line wording (c8b8581)

### Live runs (owner-approved; run 2 confirmed the fixes)
Run 1 (before the G/J/A fixes): 14 passed, 4 failed — A, both G checks, J. Run 2: 18 passed, 1 failed — F's bare-load check. The session returned the workspace path for `${CLAUDE_PLUGIN_ROOT}` where run 1 returned it literally, while D passed in the same run, so this is most likely haiku filling in its cwd. It was not re-run, and it is not fixed. It bears on run-issue's prefix rule (decision 6): a model that substitutes its cwd at the workspace root would pick the `agent-workspace:` prefix in a bare workspace session. This needs the owner's decision.

CLI facts observed (claude 2.1.282):
- A scratch-dir `marketplace add` repoints the machine record, and the record survives the directory's removal and a later CLI run (case I).
- A local `marketplace remove` drops the machine record, after which other roots stop reaching the plugin; re-taking the record restores them (case J).
- Local scope from a plain subdir of a git repo writes to the git toplevel (case K).
- With `CLAUDE_CONFIG_DIR` set, the CLI's records live under it.
- `plugin uninstall` + local `marketplace remove` leave `{"enabledPlugins":{},"extraKnownMarketplaces":{}}`.

Cleanup verified after both runs: no `aw-accept-*` in `known_marketplaces.json`, `installed_plugins.json`, `cache/` or `marketplaces/`, and `~/.claude/projects` unchanged. `~/.claude/plugins/cache/aw-accept` was there before the runs, left by an earlier fixed-name run, and is left for the owner.

Tests: install 158 -> 175, helpers 12 -> 21. Every new test was mutation-checked, and each mutation made it fail. One mutation of the same-toplevel branch showed that branch was dead, and it was removed. The full script suite passed in each pre-commit hook.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-25 12:19 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ac5f93dbe244f722a, resume 3 of 3)

**Branch**: feature/issue-345 at `d038832`
**Base**: main
**Depth**: Deep (reason: governance/enforcement files — ADR-0016/0017, user-tier installer, dispatch_phase.sh, SessionStart hook; 20 files, +4041/-166)
**Must-fix**: 1 | **Suggestions**: 6
**Round**: 5 | **Ship**: recommended — round 5: 1 mechanical must-fix (prev 1), not rising; fix and ship rather than another full round

All round-4 findings are closed; same_project() matches live case G's shapes; the enclosing_repo guard, explicit-false note, claim trap, new_sandbox/cleanup refusals verified. Hermetic suites pass (install 175, helpers 21, manifest 12, session-start 46, dispatch 112); shellcheck --severity=warning clean. Reviewers: Claude adversarial ran (fresh; 1 must-fix, 5 suggestions); Gemini failed twice (agy auto-denied a RunCommand tool call in headless mode, empty response); Codex failed (usage limit, resets 1:48 PM); Copilot skipped (quota exhausted Sept 2026). Only one independent reviewer this round.

Open human call (live case F / run-issue prefix): detection = harness text substitution + a shell comparison, but the model must transcribe the literal `'${CLAUDE_PLUGIN_ROOT}'` into its Bash call; F's probe (tools off) only measures what the model SAYS, and in run 2 haiku replaced the literal with its cwd. F is a probe weakness, but the same model behaviour in run-issue would yield `agent-workspace:` in a bare workspace-root session. Proposed: a deterministic veto — a session whose git toplevel is the workspace checkout is always bare (the installer never enables the plugin there and --check flags it) — plus rewrite F to run the real snippet with the Bash tool on. Owner decides: accept the veto + probe change, or rework detection (e.g. SessionStart hook states the prefix).

### Findings
- [x] (must-fix) a machine record that is ABSENT is never repaired and never flagged, though live case J shows an absent record leaves every enabled root without the plugin: 6a claims only a foreign record, 6c's baseline (`km_ours`) is taken after 6a so a record created by 6b's first add and then dropped by a later local remove (a leftover in the checkout or a skipped root) is not taken back, and --check treats a missing entry as "says nothing"; reproduced — install rc 0, known_marketplaces.json `{}`, --check "installed and current"; claim whenever the record is not this checkout's and an enable root can succeed (6a and 6c), flag an absent entry in --check while own_enabled, and drop the ADR's "missing ... says nothing" and "if the record named this checkout before" (own review + Claude adversarial; caused by a round-4 fix: yes, 6c's gate) — `.agent/scripts/user_tier_install.sh:1188,1214-1216,1271,~1058`, `docs/decisions/0017-plugin-based-skill-delivery.md:252`
- [x] (suggestion) 6c's note prints the path twice: `${km_src:+naming $km_src}${km_src:-without an entry for it}` expands to "naming /a/a" when set; use if/else (Claude adversarial; caused by a round-4 fix: yes) — `.agent/scripts/user_tier_install.sh:1273`
- [ ] (suggestion) run-issue prefix detection depends on the model transcribing a literal placeholder (see Open human call); add the workspace-toplevel veto and make live case F run the real snippet with the Bash tool (own review; caused by a round-4 fix: no, surfaced by live run 2) — `.claude/skills/run-issue/SKILL.md` "Skill names in this session", `.agent/scripts/tests/live/plugin_acceptance.sh` case F
- [x] (suggestion) live cases E/G run the copy's installer with the sandbox HOME but an inherited CLAUDE_CONFIG_DIR, so with it set the copy reads the owner's real `agent-workspace` record as foreign, 6a calls the failing stub and exits 1, and G fails; unset CLAUDE_CONFIG_DIR for those calls as the hermetic run() does (Claude adversarial; caused by a round-4 fix: yes, CLAUDE_CONFIG_DIR support) — `.agent/scripts/tests/live/plugin_acceptance.sh:432-433`
- [ ] (suggestion) live case K only prints a FACT and $FAMG already declares the plugin, so it cannot tell "wrote to the toplevel" from "wrote nothing", yet ADR decision 3 cites it; run K against an undeclared repo and assert the toplevel file appears (Claude adversarial; caused by a round-4 fix: yes) — `.agent/scripts/tests/live/plugin_acceptance.sh:544-553`
- [ ] (suggestion) a worktree instance passes enclosing_repo (its toplevel is itself), but its sessions read the main repo's local settings, so its own declaration cannot shadow anything (--check drift is noise) and, if local scope from a worktree also resolves to the main repo, removal strips the parent's enable; verify live or treat worktree instances like the plain-subdir case (Claude adversarial; caused by a round-4 fix: yes, same_project change) — `.agent/scripts/user_tier_install.sh:1237`
- [ ] (suggestion) the SessionStart hook checks the registered root's toplevel, not the session cwd's, so a session in a nested package repo under a root (which case G shows never sees the plugin) is told the skills arrive via the plugin and to re-run the installer; apply the same_project rule to the cwd (Claude adversarial; caused by a round-4 fix: no, exposed by live G) — `.claude/hooks/session_start_project_layer.sh:107-121`

## Checkpoint
**Status**: complete
**When**: 2026-09-25 12:28 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: rounds
**Decision**: address

Finish option 3: fix the round-5 must-fix and the suggestions, then re-review now with the reviewers available (Codex at its 5-hour limit, Gemini failing). Skill-name (prefix) detection: owner asked for more context — undecided; suggestion 2 (prefix veto / case F rewrite) waits for that decision. Owner also asked whether Gemini needs a reliability fix.
