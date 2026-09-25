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
