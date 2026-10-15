# Plan: Interim department-head skill: run issues with the owner at goal level only, standing rules repo-tracked, two parallel paths in the roadmap

## Issue

https://github.com/rolker/agent_workspace/issues/321

## Context

Today's mode (issue 395, the sit-rep rework) had the host answer most loop checkpoints and bring the owner only goal-level questions. That mode lives in the host's private memory and the owner's long conversations. Run-issue's "No auto-chaining" section and design.md ("The loop stops at checkpoints and asks the owner"; Review loop bullet "Nine checkpoint kinds stop for the owner") say the opposite, and `**Decided-by**: host` appears nowhere (grep: only `owner` in run-issue step 6, ADR-0014 line 136, design.md line 476, `review_loop_lifecycle.md` line 34, the review guide, `test_dispatch_phase.sh`). `dispatch_phase.sh` routes on `**After**` and `**Decision**` only, so a `host` value needs no script change. The Issue Review (02b00ed6) cut the scope to: skill, rules file, roadmap paths, consequences.

## Approach

1. **Skill `.claude/skills/department-head/SKILL.md`** (`session_scope: both`, description says "interim"; one screen, points at `/run-issue`, uses the `$WS_ROOT` idiom to read the rules file). Contents:
   - *Decision rights*: three kinds of question reach the owner, each a trigger plus a default. (1) Goal meant: the answer would change what the work is for, its scope, or add/drop a user-visible behaviour. (2) Goals in tension: two README goals or two principles give opposite answers; name both. (3) Outward or hard to undo: the AGENTS.md Ask-First list, the merge, anything posted outside the repo, deleting data (referenced, not restated). Default when unsure: decide it, list it under "Decisions made (owner may veto)" with what undoing costs; a design-changing question is asked alone (existing principle). A mechanism question that reaches the owner is logged as a loop defect, one line in the hand-back.
   - *Checkpoint table*: `issue-actions`, `plan`, `publish`, `rounds`, `findings`, `phase-failed`, `unexpected` host-answers with `Decided-by: host (<reason>)` unless the answer changes scope, goals or hard-to-undo state; `merge` and `merge-refused` always reach the owner; `unexpected` reaches him only if the host cannot map it to a vocabulary token. The checkpoint is still raised and written as an entry before `next`.
   - *Hand-back shape*: two orientation lines, what happened, decisions list, one reviewer outcome line per external reviewer (ran/failed/skipped, why, anything of substance), parked items, at most one question. Every number carries a plain-words label.
   - *Conduct across issues*: one agent per worktree; owner directions mid-flight go to the running agent by message and onto the timeline; stated stop time means no phase that cannot finish; parked items go to the existing inbox with `capture.sh` and into the hand-back's "Parked" line (no ledger file).
   - *Is it helping*: count owner-level questions per issue and mechanism questions that reached him; look again after the GeoZui4D run. One line: a Codex host follows the rules file by hand.
2. **`.agent/knowledge/host_standing_rules.md`**: table of rule / reason only for rules no script enforces: owner decides every merge (project PRs are gate report-only, design.md Rules row); a review with open issues goes to the owner at merge; wall-clock over tokens; second code-review round only after a real defect, third a narrow convergence check without external reviewers (verify wording against the 2026-10-15 audit before copying, else mark unverified); reviewer outcome lines; numbers carry labels; a veto becomes a rule with its reason. A short "already enforced, no rule text" pointer list (merge gate, bookkeeping exemption, takeover as the only inline row, orientation line, model tier). The decisions-list format.
3. **Resolve the conflict, same PR**: `run-issue/SKILL.md` "No auto-chaining" (host answers the non-owner kinds; merge and merge-refused still wait for the owner), step 6 (`Decided-by: owner | host (<reason>)`, cross-reference to the skill), the nine-checkpoints sentence near line 152. `docs/design.md`: How it works paragraph, Review loop "Nine checkpoint kinds" bullet and the phase table's who-decides wording, Rules row on the merge checkpoint stays, change-log row. `review_loop_lifecycle.md` line 34 and ADR-0014 References entry (and the `Decided-by` sentence near line 136 by pointer, not rewrite). ADR-0013 is not edited: the vocabulary of `Decided-by` lives in run-issue step 6 and the lifecycle file.
4. **Roadmap paths** (`docs/roadmap.md`, Direction intro, above the tables): two prose paragraphs in the owner's words from the issue ("focus on getting the workspace ready to support geozui, as well as monitor the testing and evaluation of it" / "implementing the missing pieces to making this workspace reflect the goals we set"). Membership by rule: Path 1 = what the acceptance case needs or monitors; Path 2 = anything else serving a README goal. No status, dates or check cells; no Path column; no issue labels. The owner picks one, the other or both when he asks for a sit-rep, never stored.
5. **Sit-rep path line** (`.claude/skills/sitrep/SKILL.md` step 3 and the report template): each In flight line ends with `Path 1`, `Path 2` or `no path`, derived from the item's `**Serves**` line in its Issue Review (Direction-line or gz4d acceptance mentioned means 1, a README goal means 2, neither means "no path"). The skill asks which path to focus on after the report and says gz4d items show only once the sit-rep reads that root (roadmap deferral).
6. **Sit-rep vs PR 396 (issue 395)**: 396 rewrites SKILL.md (about 680 lines changed), the roadmap and design.md Direction row. Steps 1-3 touch none of those hunks except run-issue/design.md prose in other sections, so they proceed now. Steps 4-5 are done last, after 396 merges: rebase this branch on main then, apply the edits against the merged text. If 396 is still open at that point, steps 4-5 become a follow-up PR on the same issue (this PR then does not use `Closes`). No edit to sitrep, roadmap or the design Direction row is made on a base that lacks 396.
7. **Install**: `make generate-user-tier-skills` for the plugin manifest; `chmod +x` not needed (no new script). Add to the skill list in `.agent/knowledge/skill_workflows.md` if it lists skills.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/department-head/SKILL.md` | New skill (step 1) |
| `.agent/knowledge/host_standing_rules.md` | New rules file (step 2) |
| `.claude/skills/run-issue/SKILL.md` | No auto-chaining, step 6, checkpoint sentence, pointer to the skill |
| `docs/design.md` | How it works, Review loop bullet and table wording, change-log row |
| `.agent/knowledge/review_loop_lifecycle.md`, `docs/decisions/0014-in-process-phase-handoff.md` | `Decided-by: host`; References entry |
| `docs/roadmap.md`, `.claude/skills/sitrep/SKILL.md` | Paths paragraphs; path word in In flight (after 396) |
| `.agent/scripts/tests/test_skill_paths.sh` | Guards below |
| plugin manifest (generated) | `make generate-user-tier-skills` |

## Prior Art

Looked at: run-issue's decision table and checkpoint vocabulary (reused, unchanged), the existing inbox and `capture.sh` (used for parked items instead of a new ledger), the Issue Review for 321 and the 395 timeline (the worked example; its restart checkpoint and decisions list set the shapes). Rejected: a claim line and collision map (deferred to the design session), a new Path column or issue labels (would change the `sitrep_checks.sh` grammar), a stored focus choice (creates status).

## Serves

Trust, control and information; Easy to use. `docs/design.md#review-loop-and-timeline` and `docs/design.md#documentation-layers`.

## Design Picture

Changes it: who answers a checkpoint. `docs/design.md#review-loop-and-timeline` and the How it works paragraph change in this PR; the Direction row in `docs/design.md#documentation-layers` gets one clause for the paths (after 396).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Ask about what matters, and show how much | CUTS judgment-by-vibe: each of the three kinds is a trigger plus a default, so a Sonnet or Codex host can apply it. CHANGES who answers seven of nine checkpoints: the host, recorded and listed for veto. |
| Leave a trail; start limits strict | CHANGES a limit the owner relaxed in his own words: checkpoints still become entries before `next`, only the answerer differs. CUTS the relaxation at merge and merge-refused (project PRs are report-only at the gate, so nothing else stops a host merge). |
| Only what's needed | CUTS the claim line, notes 11-13 and 17-19, a ledger file (inbox instead), sub-agent shape, phase reuse, orientation (all already in run-issue/dispatch_phase), and rule text for anything a script enforces. |
| Enforce what matters, as simply as possible | CUTS duplicate rule text; adds no new check beyond string guards. The "host never edits files" rule stays `review only`. |
| A change includes its consequences | CHANGES run-issue, design.md, lifecycle file, ADR-0014 references, roadmap, sit-rep, plugin manifest in the same PR. Deletes the "never advances on its own judgment" claim it makes untrue. |
| Keep one current design | CHANGES design.md in this PR (How it works, Review loop, change log). |
| Put each thing at the level it applies to | CHANGES the skill to `$WS_ROOT` paths and `session_scope: both`; per-root rules wait for the design session. Paths are workspace-level roadmap text. |
| Use the main tool fully; keep the work tool-neutral | CHANGES nothing in the rules (plain files); the skill is Claude-only and says a Codex host follows the file by hand. |
| Verify before claiming | CHANGES the rules file: each rule is checked against its source (audit, design.md, script) before copying, else marked unverified. |
| Know whether it works | CHANGES the skill: counts owner-level and mechanism questions that reached him; re-look after the GeoZui4D run. |
| Give the user what they need now | Hand-back shape starts with two orientation lines; it points at run-issue step 6, does not restate it. |
| Look for prior art | See Prior Art. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0014 | Yes | References entry; no change to the handoff contract; one driver per issue kept |
| 0013 | Yes | `Decided-by: host` added to the vocabulary in run-issue step 6 and the lifecycle file; no new entry type |
| 0016 / 0018 | Yes | `session_scope: both`; the skill conducts only the session's own root; anything about project-root behaviour stays unproven until the gz4d run |
| 0017 | Yes | design.md updated in the same change |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Checkpoint answerer | run-issue, design.md, lifecycle, ADR-0014 | Yes |
| New skill with `session_scope: both` | plugin manifest, `test_skill_paths.sh` | Yes |
| Direction intro / sit-rep In flight | design.md Direction row, 396's text | Yes, after 396 |
| Memory notes shrink to pointers | host memory files | After merge, host task, not in the PR |

## Tests

`test_skill_paths.sh` (hermetic, tracked files): department-head has `session_scope: both`, no bare `.agent/scripts/` path, points at run-issue and the rules file, and the rules file exists; run-issue documents `Decided-by: host` and states merge and merge-refused still reach the owner; (after 396) sitrep's SKILL.md names `Path 1`, `Path 2` and `no path`, and roadmap.md has both paths with no `|` table row between the Paths paragraphs. Add `department-head` to the project-capable skill list. Dispatched-agent check from the review: a Sonnet agent classifies 395's questions from the skill text alone, result recorded in progress.md.

## Open Questions

None for the owner. Everything below is decided.

Decisions made (owner may veto):
- Skill named `/department-head`; parked items go to the inbox via `capture.sh`; `session_scope: both`.
- Merge and merge-refused stay owner-level; the other seven are host-answered under the contract.
- Path membership by rule via the Issue Review Serves line; no Path column, labels or stored focus.
- ADR-0013 text is not edited; the field is documented where the vocabulary lives.
- Sit-rep and roadmap edits wait for 396; otherwise a follow-up PR.
- Smallest change meeting acceptance: skill + rules file + run-issue/design wording + roadmap paragraphs + one path word per In flight line.

## Estimated Scope

One PR (two if 396 has not merged when steps 4-5 are due).
