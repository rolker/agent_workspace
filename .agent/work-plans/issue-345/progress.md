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
