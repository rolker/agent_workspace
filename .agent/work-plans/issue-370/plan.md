# Plan: A skill for high-level design discussions

## Issue

https://github.com/rolker/agent_workspace/issues/370

## Context

The issue body proposes a challenge conversation (fresh idea or design in progress; ends in continue, prune, shelve or clearer-but-undecided; never builds) and ships a trial `SKILL.md`. Eight later comments add a goals-down skill, resume and pacing rules, and long-view / roadmap items (D1-D9, M1-M10). The Issue Review actions (accepted by the owner) are constraints here; the answers are in "Review actions" below.

**Proposed name: `challenge`** (`/challenge <topic>`). One plain verb, says what the user is asking for, and does not collide with `brainstorm`, `review-plan` or `review-issue`. The owner confirms or changes it at the plan checkpoint; the name appears in only the directory, the front matter and the list lines below, so a rename is cheap.

## Approach

1. **Create `.claude/skills/challenge/SKILL.md`** from the issue-body trial draft, with `session_scope: both`. Edits to the draft:
   - Rename `design-discussion` to `challenge`; keep the "Trial version" banner with its revise trigger (see Review actions 6).
   - Step 1 (existing design): add "list where the design's decisions and evidence live, including unmerged branches and working directories outside git" (comment 2026-10-01, fix 1).
   - Step 4 (existing design): add the decision-list pass, each item marked kept / waits / changed / dropped (fix 2).
   - Step 6: before the landing counts, show that list with changed and dropped first; check new terms against existing decisions; follow the design's own change rule or say the landing sets it aside; name settled work the conclusion strands. Ban the blanket "the existing design still stands" (fix 3). Step 7: optional fresh-session second pass when prune or shelve is written visibly (fix 4).
   - Resume rule (2026-10-05, 2026-10-05 follow-up): new first line of Step 1, "On resuming, the first output is the one-liner of the overall task, then progress against its plan, then only the context for the detail" (goes in Step 1).
   - Parking rule (2026-10-05): in Step 5, "park a detail only when it does not block work at this level and can be solved later without significant redesign; say both when parking" (goes in Step 5).
   - Trim: keep a "Why" only where an observed failure backs it. Failure-backed: judging before purpose (step 2), long first reply and seven questions (step 5 question rules), oversold objections (steps 3-4), decision-record check (steps 1, 4, 6). Rules from no observed failure (the "state a conclusion in your own words" prompt, the every-few-rounds open list) are marked "untested" in the text, not removed, because the trial exists to test them.
   - Record step: summary goes to `.agent/scratchpad/design-discussions/` under the session root (created if absent), kept private. Only the user moves a decision to a tracked place (design doc, roadmap, issue), each on a yes. Text states that scratch is working space, not a home for decisions (D9).
   - Skill text uses synthetic names only; no real project names, issue or PR numbers as names.
2. **Update `brainstorm`'s "what this is not"** with one line pointing to `/challenge` (brainstorm lists options in one pass; challenge is a two-way conversation that attacks and defends).
3. **Update lists**: recount the skills line in `docs/design.md#instruction-layers` (`ls -d .claude/skills/*/ | wc -l` at that time; 23 now, 24 with this skill, the line says 22), and add `challenge` to the skill lists in `.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`, `.agent/AGENT_ONBOARDING.md`.
4. **Regenerate the plugin manifest** with `make generate-user-tier-skills`; confirm `challenge` appears in `plugin.json`'s `skills` and run `.agent/scripts/tests/test_plugin_manifest.sh` (locate with `ls`; path to be verified at implementation).
5. **File follow-up issues** (not in this PR; each cites #370): (a) goals-down skill (2026-10-02 comments, includes upward check, evidence labels, level sorting); (b) long-view / route work: roadmap derivation from design, deferral homes, drift checks, measures (D1-D9 minus D9, M1-M10), which touches `docs/design.md` and goes to the owner on its own; (c) shared conversation rules between `challenge`, the goals-down skill and `orchestrator` (#398), only if (a) shows the rules duplicate.
6. **Trial**: see Review actions 6.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/challenge/SKILL.md` | New skill, from the trial draft plus the edits in step 1 |
| `.claude/skills/brainstorm/SKILL.md` | One line in "what this is not" |
| `docs/design.md` | Skill count in `#instruction-layers` |
| `.github/copilot-instructions.md`, `.agent/instructions/gemini-cli.instructions.md`, `.agent/AGENT_ONBOARDING.md` | Add `challenge` to the skill list |
| `.claude-plugin/plugin.json` (generated; path verified at implementation) | Regenerated |

## Review actions

1. **Scope.** First PR is the challenge skill only (body draft plus items below). Goals-down skill and long-view / roadmap parts go to follow-up issues (step 5). Nothing from D1-D8 or M1-M10 is built here; the skill's step 7 states the D9 rule only.
2. **brainstorm overlap and prior art.** `brainstorm` reads digests and governance docs and lists possibilities in one pass; it has no purpose-first step, no attack and defend, no assumptions kept and checked, no decision-record check and no landing. Those are what `challenge` adds, so a separate skill, cross-referenced both ways (step 2). Prior art: taken from gstack `office-hours` and `plan-ceo-review` (goal question first, rules against easy agreement, premises listed, mandatory alternatives, check for earlier design notes, "a recommendation settles nothing"); from BMAD `bmad-forge-idea` (attack, defend, switch roles; killed or clarified as valid endings); from `reason-grill` and `devils-advocate` (each objection survives its own rebuttal; state what the design gets right first). Rejected: gstack's size (about 80 KB per skill) and startup framing, and one-way grilling. Existing `review-plan` and `review-issue` were also looked at; they check a written artifact against rules, not whether the thing should exist.
3. **Name.** `challenge`, reason above; owner confirms at the plan checkpoint.
4. **First-PR scope.** Trial draft plus the four fixes from the 2026-10-01 comment (steps 1, 4, 6, 7), as in step 1 above.
5. **Resume and parking rules.** Both are folded in: resume one-liner goes in Step 1, parking conditions in Step 5 (named in step 1 above). The side-thoughts queue file is not folded in: its trial result was "still untested whether parked items get picked up", so it goes to follow-up (a).
6. **Trial.** The SKILL.md banner stays until two uses are recorded: one fresh idea, one existing design. The owner runs them (or asks for them); the outcome is posted as a comment on #370, and the same comment says settle, revise, or remove. Trigger to revisit: both uses done, or 2026-12-31 if not, whichever comes first, at which point the skill is revised or removed rather than left as a trial. Implementation does not claim the skill settled; the PR description says it is a trial.

## Prior Art

See action 2 above. Also looked at: other skills' `session_scope: both` front matter (`plan-task`, `orchestrator`) and the manifest generation for the plugin list. Nothing new is built in tooling; this is one skill text.

## Serves

Quality of the work and Trust, control and information (`README.md#workspace-goals`); `docs/design.md#instruction-layers` (layer 3, skills).

## Design Picture

No change to how the parts fit. A new `SKILL.md` is not a new mechanism; only the skill count in `docs/design.md#instruction-layers` is updated in this PR. Writing into the roadmap or design from a later mode is out of scope and goes to the owner on its own.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Small steps | First PR is one skill; the rest is filed separately |
| Look for prior art | Action 2 |
| Only what's needed | Rules without an observed failure are marked untested; no queue file, no second skill |
| Know whether it works | Two-use trial with a date and a recorded outcome (action 6) |
| Put each thing at the level it applies to | Synthetic names in the skill text; summary under the session root's scratchpad, which works in a project session as the project's own `.agent/scratchpad/` (verify at implementation; if a project session has none, the skill creates it) |
| Leave a trail | Summary is private; only the user moves a decision to a tracked place |
| Test what breaks | No code; plugin manifest test covers the generated list |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0018 Plugin-based skill delivery | Yes | `session_scope: both`; regenerate manifest; run manifest test |
| 0013 progress.md vocabulary | No | Skill never writes `progress.md` |
| 0017 Design document is the current picture | Yes, minor | Skill count recounted in the same change |
| 0014 In-process phase handoff | No | Not a `run-issue` phase |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Skill list | `docs/design.md#instruction-layers` count; three non-Claude adapter lists | Yes (step 3) |
| `session_scope: both` | `plugin.json` via generator | Yes (step 4) |
| Overlap with `brainstorm` | `brainstorm` "what this is not" | Yes (step 2) |
| Goals-down skill, long-view items | New issues | No, follow-up (step 5) |

## Open Questions

- Name: `challenge` is proposed; confirm or change.
- Trial date 2026-12-31: confirm or change.

## Estimated Scope

Single PR for the skill; three follow-up issues.
