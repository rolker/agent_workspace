# Plan: Interim department-head skill: run issues with the owner at goal level only, standing rules repo-tracked, two parallel paths in the roadmap

## Issue

https://github.com/rolker/agent_workspace/issues/321

## Context

Today's mode (issue 395, the sit-rep rework) had the host answer most loop checkpoints and bring the owner only goal-level questions. That mode lives in the host's private memory and the owner's long conversations. Run-issue's "No auto-chaining" section and design.md ("The loop stops at checkpoints and asks the owner"; Review loop bullet "Nine checkpoint kinds stop for the owner") say the opposite, and `**Decided-by**: host` appears nowhere (grep: only `owner` in run-issue step 6, ADR-0014 line 136, design.md line 476, `review_loop_lifecycle.md` line 34, the review guide, `test_dispatch_phase.sh`). `dispatch_phase.sh` routes on `**After**` and `**Decision**` only, so a `host` value needs no script change. The Issue Review (02b00ed6) cut the scope to: skill, rules file, roadmap paths, consequences. PR 396 (sit-rep, issue 395) has merged to main (a3b9969a) and this branch is rebased on it, so every edit below applies to the merged sit-rep, roadmap and design text directly; there is no sequencing wait.

## Approach

1. **Skill `.claude/skills/orchestrator/SKILL.md`** (`session_scope: both`, description says "interim"; one screen, points at `/run-issue`, uses the `$WS_ROOT` idiom to read the rules file). Contents:
   - *Decision rights*: three kinds of question reach the owner, each a trigger plus a default. (1) Goal meant: the answer would change what the work is for, its scope, or add or drop a behaviour his quoted words ask for or rule out. How a behaviour he asked for works (its limits, wording, order, format, defaults) is a host decision listed for veto (395: research auto-start capped at the three oldest topics; long titles printed in full). (2) Goals in tension: two README goals or two principles give opposite answers; name both. (3) Outward or hard to undo: the AGENTS.md Ask-First list, the merge, anything posted outside the repo, deleting data (referenced, not restated). Default when unsure: decide it, list it under "Decisions made (owner may veto)" with what undoing costs; a design-changing question is asked alone (existing principle). A mechanism question that reaches the owner is logged as a loop defect, one line in the hand-back.
   - *Checkpoint table* limits which answers the host may give, not only who answers. `issue-actions`: `proceed`. `plan`: `proceed` or `revise`. `publish` and `rounds`: `publish` or `address`. `findings`: `address`; `merge` (deferring open boxes) is the owner's. `phase-failed`: `retry`; `takeover` is the owner's (the one inline exception, granted by his answer). `unexpected`: host if it maps to a vocabulary token, else the owner. `merge` and `merge-refused` always the owner. `stop` is open to the host anywhere. Every host answer is written `Decided-by: host (<reason>)` and the checkpoint is still raised and written as an entry before `next`. A host-answered checkpoint never lets the host do a phase's work itself. "Phases never dispatch each other" and "each `next` call decides exactly one step" stay verbatim in run-issue.
   - *Recipes for the owner interactions seen on issue 395*: (a) **Restart**: the owner restates the goal mid-drive. Write `## Checkpoint` with `Decided-by: owner`, `After: <the checkpoint pending, else unexpected>`, `Decision: restart`, his words verbatim; then, once any running phase has returned (one agent per worktree), dispatch `review-issue` (`dispatch_phase.sh --issue <N> --skill review-issue`). Its `## Issue Review` becomes the newest entry and routes as usual, so `next` never reads `restart`. Run-issue step 6 gets one sentence naming `restart` as this host-recorded owner redirect. (b) **Project names**: record text (roadmap Direction, change log, ADR history, work plans) may name a public project, checked with `gh repo view --json visibility`; skill, script, template and test text never names a project. Reason: an acceptance line is checkable only if it names the real project (owner, 2026-10-15). A settled question is not re-asked. (c) **Owner-text veto**: text that states his goals (README goals, the roadmap acceptance case, Direction lines, Paths) is written only from his quoted words; the host drafts it, shows the sentence with its quote under "Decisions made (owner may veto)", and only a "no" changes it. It becomes a kind-1 question only when no quote of his covers it. (d) **Starting a drive**: opening an issue and starting a drive are the owner's (AGENTS.md Issue-First). A row: his go-ahead, or a sit-rep "Next" item he accepts. The hand-back's one question may propose the next drive; the host never starts one on its own after a merge. (e) **Merge decision**: always the owner's, after a decision summary; reviews reduce what he reads, they do not decide.
   - *Outward-facing line*: inside the boundary are the loop's own push, PR creation, signed comments on the issue being driven and progress entries. Everything else outward goes to the owner: new issues, merges, edits to the owner's text, messages to other sessions, comments on other issues, deletes of data or branches not created in this drive, and anything a stranger could see as the owner's word (plus the AGENTS.md Ask-First list, referenced not restated). A limit the host sets on a read-only background run (the research three-topic cap) is not outward; it is a listed decision. A standing authorization of his, recorded in the rules file with his words, turns one outward class into a host action; the 398 comment below is the first.
   - *Hand-back shape*: two orientation lines, what happened, decisions list, one reviewer outcome line per external reviewer (ran/failed/skipped, why, anything of substance), parked items, at most one question. Every number carries a plain-words label.
   - *Conduct across issues*: one agent per worktree; owner directions mid-flight go to the running agent by message and onto the timeline; stated stop time means no phase that cannot finish; parked items go to the existing inbox with `capture.sh` and into the hand-back's "Parked" line (no ledger file).
   - *Dogfooding step*: after each issue the skill drives, post one signed comment on issue 398 (`gh issue comment 398 --body-file`, AI signature) with four headings: what reached the owner and why; decisions made and any vetoes; where the decision-rights table was wrong or silent; what the sit-rep or hand-back got wrong. A GitHub write inside the boundary because the owner asked for it (2026-10-15). Count owner-level and mechanism questions in it; look again after the GeoZui4D run. A Codex host follows the rules file by hand.
2. **`.agent/knowledge/host_standing_rules.md`**: table of rule / reason for rules no script enforces, swept from the owner rules issue 395 actually applied (each `feedback-*` note applied gets a row with its reason, a pointer to where it is written, or one line on why it stays private): owner decides every merge (project PRs are gate report-only, design.md Rules row); merge only when everything is clean unless he says skip (its own row, same reason); never pass `--no-wait`, `--allow-pending-review` or `--force-unreviewed` unless he said so for that merge; **the host never edits repository files during a drive, it delegates** (not script-enforced; the dispatcher only routes; owner's reason, 2026-09-22: "Having you do the work might be faster, but I lose access to my orchestrator."); names in workspace text (recipe b, with its reason); quote recorded design before asking a design question; design questions are asked alone with what changes and how hard to undo; wall-clock over tokens; second code-review round only after a real defect, third a narrow convergence check without external reviewers (source: the issue 321 body, "Review depth follows the audit's rule: a second code-review round only when the first found a real defect; a third is a narrow convergence check without external reviewers"; the owner's private audit is background only. Mechanism: the round-3 handoff names its scope, the prior round's items and the fix diff, and says "no cross-model reviewers". It is the owner's standing exception to review-code's fix-round rule (issue 320) for round 3 only. Reason: each round costs about 20-25 minutes, and a convergence check re-reads only the fixes); reviewer outcome lines; numbers carry labels; a veto becomes a rule with its reason; standing authorization: the issue 398 comment, with his words. A short "already enforced, no rule text" pointer list (merge gate, bookkeeping exemption, orientation line, model tier). The decisions-list format. Also an entry in `.agent/knowledge/README.md`.
3. **Resolve the conflict, same PR**: `run-issue/SKILL.md` "No auto-chaining" ("The host may answer a checkpoint itself, with the tokens `/orchestrator`'s table allows, written `Decided-by: host (<reason>)`. `merge` and `merge-refused` always wait for the owner, and so do `takeover` at `phase-failed` and `merge` at `findings`. A host-answered checkpoint never lets the host do a phase's work itself."), step 6 (`Decided-by: owner | host (<reason>)`, cross-reference to the skill), the nine-checkpoints sentence near line 152. `docs/design.md` (edits placed by quoted text, not line number): How it works paragraph, "anything but `OK` goes to the owner at `phase-failed` to retry, take over or stop" (becomes host retry or stop, owner take over), the glossary "checkpoint: a point where the loop stops and asks the owner", Review loop "Nine checkpoint kinds" bullet and the phase table's who-decides wording, Rules row on the merge checkpoint stays, change-log row. `review_loop_lifecycle.md` line 34 and ADR-0014 References entry (and the `Decided-by` sentence near line 136 by pointer, not rewrite). `dispatch_phase.sh` line 693 reason text "owner decides proceed, revise, or stop" becomes "proceed, revise, or stop" (suggestion; implementer may skip; no test asserts the string). ADR-0013 is not edited: the vocabulary of `Decided-by` lives in run-issue step 6 and the lifecycle file.
4. **Roadmap paths** (`docs/roadmap.md`, Direction intro, above the tables): two prose paragraphs in the owner's words from the issue ("focus on getting the workspace ready to support geozui, as well as monitor the testing and evaluation of it" / "implementing the missing pieces to making this workspace reflect the goals we set"). Membership by rule: an issue named in a Direction line's own cell is Path 1; everything else serving a README goal is Path 2 (not decided by the Serves line). "Acceptance-case sequence" in the issue body means the cases after GeoZui4D, so Path 2. No status, dates or check cells; no Path column; no issue labels. The owner picks one, the other or both when he asks for a sit-rep, never stored.
5. **Sit-rep path word and readability** (`.claude/skills/sitrep/SKILL.md` step 3 and the report template, on the merged text): each In flight line ends with `Path 1`, `Path 2` or `no path`: an item whose issue number matches a Direction line's own cell (step 5's existing match) is Path 1; otherwise an Issue Review Serves line naming a README goal is Path 2; otherwise `no path`. The skill asks which path to focus on after the report and says gz4d items show only once the sit-rep reads that root. Readability, from the owner's words ("That sample made me wonder if it was describing the current state, or what we still need to do ... more whitespace to make it easier to read and see the structure"): every line carries a lead word fixing its tense (`Done:`, `Not yet:`, `Next:`, `Running:`); one item per line, never comma- or semicolon-joined (steps, "and <k> more", inbox items and deferrals become bullets); a blank line between sections. `test_sitrep_checks.sh` cases: no `; ` join in the template's list lines, a blank line between sections.
6. **Sequencing**: none. 396 has merged; the branch is rebased on main.
7. **Install**: `make generate-user-tier-skills` for the plugin manifest; `chmod +x` not needed (no new script). Add to the skill list in `.agent/knowledge/skill_workflows.md` if it lists skills.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/orchestrator/SKILL.md` | New skill (step 1) |
| `.agent/knowledge/host_standing_rules.md` | New rules file (step 2) |
| `.claude/skills/run-issue/SKILL.md` | No auto-chaining, step 6, checkpoint sentence, pointer to the skill |
| `docs/design.md` | How it works, lines 469 and 721, Review loop bullet and table wording, change-log row |
| `.agent/knowledge/README.md` | Index entry for the rules file |
| `.agent/scripts/dispatch_phase.sh` | Line 693 reason text (optional) |
| `.agent/knowledge/review_loop_lifecycle.md`, `docs/decisions/0014-in-process-phase-handoff.md` | `Decided-by: host`; References entry |
| `docs/roadmap.md`, `.claude/skills/sitrep/SKILL.md`, `.agent/scripts/tests/test_sitrep_checks.sh` | Paths paragraphs; path word and readability in the template; their tests |
| `.agent/scripts/tests/test_skill_paths.sh` | Guards below |
| plugin manifest (generated) | `make generate-user-tier-skills` |

## Prior Art

Looked at: run-issue's decision table and checkpoint vocabulary (reused, unchanged), the existing inbox and `capture.sh` (used for parked items instead of a new ledger), the Issue Review for 321 and the 395 timeline (the worked example; its restart checkpoint and decisions list set the shapes). Rejected: a claim line and collision map (deferred to the design session), a new Path column or issue labels (would change the `sitrep_checks.sh` grammar), a stored focus choice (creates status).

## Serves

Trust, control and information; Easy to use. `docs/design.md#review-loop-and-timeline` and `docs/design.md#documentation-layers`.

## Design Picture

Changes it: who answers a checkpoint. `docs/design.md#review-loop-and-timeline` and the How it works paragraph change in this PR; the Direction row in `docs/design.md#documentation-layers` gets one clause for the paths.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Ask about what matters, and show how much | CUTS judgment-by-vibe: each of the three kinds is a trigger plus a default, so a Sonnet or Codex host can apply it. CHANGES who answers seven of nine checkpoints and which tokens: `findings`→`merge` and `phase-failed`→`takeover` stay the owner's, recorded and listed for veto. |
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
| Direction intro / sit-rep In flight | design.md Direction row, merged sit-rep text | Yes |
| Memory notes shrink to pointers | host memory files | After merge, host task, not in the PR |

## Tests

`test_skill_paths.sh` (hermetic, tracked files): orchestrator has `session_scope: both`, no bare `.agent/scripts/` path, points at run-issue and the rules file, and the rules file exists; run-issue documents `Decided-by: host`, states merge and merge-refused still reach the owner, and names `takeover` as owner-only; every row of the rules table has a non-empty reason cell; orchestrator names `takeover` and the `findings`→`merge` token as owner-only, names issue 398 and its four headings; sitrep's SKILL.md names `Path 1`, `Path 2` and `no path` and the lead words, and roadmap.md has both paths with no `|` table row between the Paths paragraphs. `test_skill_paths.sh` already scans every `session_scope` skill (verify; nothing to add). Dispatched-agent check from the review: a Sonnet agent classifies 395's questions from the skill text alone, covering the five interactions on 395 (restart, project naming, owner-text veto, starting a drive, merge) and the two owner-only tokens; result recorded in progress.md.

## Amendment (Plan Review round 2, ab5123e3; Checkpoint 4788c593)

Folded in before implementation, no third plan review: (1) run-issue's "No auto-chaining" text names `takeover` at `phase-failed` and `merge` at `findings` as the owner's, with the no-phase-work sentence and a test; (2) the review-round row cites the issue 321 body, states the round-3 handoff mechanism, the exception to review-code's fix-round rule (issue 320) and the reason, no longer "unverified"; (3) kind 1's trigger covers only behaviour his words ask for or rule out, how such a behaviour works is a listed host decision, and the outward line says a host-set limit on a read-only background run is a listed decision. Also from the review's decisions: the duplicate Decision rights bullet is dropped, design.md edits are placed by quoted text, the rules-table reason test is added, and recipe (a) waits for any running phase.

**Rename (owner, 2026-10-15).** The skill is `orchestrator` (`.claude/skills/orchestrator/SKILL.md`, `/orchestrator`), not `department-head`: "orchestrator" is the word he has been reaching for and the one the field uses, and "department head" was coined the same day as a contrast to "chief of staff". The description line keeps the idea: the orchestrator for one root, which keeps the owner at goal level and runs issues in the background (the "department head" for that root, as explanation, never as the name). The role name in status lines and hand-backs is "orchestrator for <root>". This overrides the Issue Review's naming recommendation (keep `orchestrate` free for the later per-root design).

## Open Questions

None for the owner. Everything below is decided.

Decisions made (owner may veto):
- Skill named `/orchestrator` (owner, 2026-10-15; see the rename note above); parked items go to the inbox via `capture.sh`; `session_scope: both`.
- The host may answer `stop` anywhere. `merge` from `findings` and `takeover` from `phase-failed` stay the owner's; merge and merge-refused stay owner-level.
- Restart is recorded as `Decision: restart` and re-entered through a review-issue dispatch; no dispatcher change.
- The loop's own push, PR creation, signed issue comments and progress entries are inside the boundary; all else outward is the owner's, unless a standing authorization of his is recorded.
- Goal text is written only from his quotes and listed first for veto.
- Path 1 means the issue is named in a Direction line's own cell; the Serves line decides only Path 2.
- ADR-0013 text is not edited; the field is documented where the vocabulary lives.
- `dispatch_phase.sh:693` reason text reworded (optional).
- Smallest change meeting acceptance: skill + rules file + run-issue/design wording + roadmap paragraphs + sit-rep path word and readability.

## Estimated Scope

One PR.
