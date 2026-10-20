---
issue: 321
---

# Issue #321 — Interim department-head skill: run issues with the owner at goal level only, standing rules repo-tracked, two parallel paths in the roadmap

## Issue Review
**Status**: complete
**When**: 2026-10-15 14:58 -04:00
**By**: Claude Code Agent (sonnet)

**Issue**: #321

### Scope Assessment

**Well-scoped?** Yes if cut as below, no as written. The body's scope list is four items, but the folded 2026-09-22 shape adds eight skill items and nineteen field notes, and the Acceptance line says the 09-22 parallel-drive acceptance "still holds". One PR can carry: the skill (decision rights, hand-back shape, parked items, time box), the standing-rules file (only rules no script enforces), the roadmap paths, and the consequences. It cannot carry a claim mechanism, a collision map, peer-host messaging, or quota accounting (notes 4, 11, 12, 17). Those are not needed to run one issue with the owner at goal level, which is the evidence-backed goal.
**Right repo?** Yes. Workspace: skill, knowledge file, roadmap, run-issue, ADR-0014 reference.
**Serves**: Trust, control and information; Easy to use — `docs/design.md#review-loop-and-timeline` (who answers a checkpoint) and `docs/design.md#documentation-layers` (Direction).
**Design picture?** Changes `docs/design.md#review-loop-and-timeline` and the "How it works" paragraph ("The loop stops at checkpoints and asks the owner"). Today's mode has the host answer most checkpoints. The issue records the owner's decision for this (his quoted words), so this is recorded as OK with a pointer; the design update itself is a required consequence (see Consequences).
**Dependencies**: PR for the sit-rep wrap-up (#395, "what to work on next towards the goals") is the other half of acceptance ("sit-rep shows the two paths"); this issue's roadmap text must land with or after it. Path 1's in-flight items live mostly in the `gz4d` root, which the sit-rep does not read yet (roadmap deferral "sit-rep over every registered root").

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Ask about what matters, and show how much | Action needed | The obvious implementation copies the issue's three question kinds as a bullet list. A Sonnet or Codex host cannot apply "is this the goal you meant" as a test; it needs the decision made checkable. What it CUTS: judgment-by-vibe. What it CHANGES: each kind gets (1) a mechanical trigger and (2) a default when unsure. Kind 3 ("outward-facing or hard to undo") already has an enumerated list: AGENTS.md Ask-First (instruction files, CI/branch protection, project remote URL), the merge (design.md Rules: "owner decides every merge"), anything posted outside the repo, deleting data. Reference those, do not restate. Kind 1 trigger: the question changes what the work is for, its scope, or drops/adds a user-visible behaviour (as #395's "restart" did). Kind 2 trigger: two README goals or two principles give opposite answers (name both). Default when unsure whether a question is mechanism or goal: decide it, list it under "Decisions made (owner may veto)", and say what undoing it costs; a design-changing question is the exception and is asked alone (existing principle). Also state which of run-issue's nine checkpoints the host answers itself and records with a new `**Decided-by**: host (<reason>)`; today the doc defines only `owner`, and no script or ADR-0013 mentions the field, so #395's use was an unwritten extension. |
| Leave a trail; start limits strict | Action needed | Limits "only the user relaxes". The owner relaxed them for checkpoints in the quoted words, but run-issue's "No auto-chaining" section says the loop "never advances past a checkpoint on its own judgment". Both cannot stand. Smallest fix: the checkpoint is still raised and written as an entry before `next`, with `Decided-by: host`; what changes is only who answers the non-owner kinds. The merge checkpoint is NOT relaxed: design.md Rules row 157 says the owner decides every merge (a `review only` rule), and project PRs are gate report-only (row 156, line 296), so nothing else would stop a host merge in `gz4d`. Write that explicitly into the skill. |
| Only what's needed | Action needed | Cut list for the skill: items 4 (claim line), notes 11, 12, 13, 17, 18, 19 stay as comments on this issue for the design session. Ledger (item 6): do not add a ledger file. The inbox from #395 already exists (`settings_path inbox`); parked items go there as lines and in the hand-back's "Parked" line. Hand-back "sub-agent shape" (item 7) is already `dispatch_phase.sh`'s exit contract plus run-issue's Decision summary; point at it. Item 5 (phase→agent reuse) is run-issue step 4a, already built. Item 1 (orientation) is run-issue step 6 ("Every dialog is self-contained"); only the extra hand-back lines (decisions list, reviewer outcome lines) are new. |
| Enforce what matters, as simply as possible | Action needed | Standing-rules file: see rule-by-rule split under Recommendations. Rules the scripts already enforce get no rule text (a duplicate that can drift). One enforcement gap deserves a check later, not now: "host never edits files during a drive" is `review only`. |
| A change includes its consequences | Action needed | Required: `docs/design.md` (How it works paragraph; Review loop and timeline; Rules table row 157 wording if the host answers non-merge checkpoints), run-issue "No auto-chaining" and step 6 (`Decided-by: host`), `dispatch_phase.sh` header only if it validates `Decided-by` (it does not today: grep found no use), ADR-0014 References, `session_scope: both` + `make generate-user-tier-skills` + plugin manifest test (the skill must work in the `gz4d` session, the acceptance run), skill index in `.agent/knowledge/skill_workflows.md`/README skill lists if present. |
| Put each thing at the level it applies to | Watch | The skill must use the `$WS_ROOT` idiom to read the rules file from a project session. The rules apply to every root; per-root rules (project11, GeoZui4D) belong in that root later, which is the design session's job, not this PR's. Path 1/Path 2 text is workspace-level (roadmap). |
| Keep one current design | OK | Owner decision is on the issue; design update named above. |
| Know whether it works | Watch | Acceptance is one fresh-session run. Say in the skill how to tell whether it helped: count owner-level questions per issue and mechanism questions that reached him (the issue already calls those loop defects, so log them as one line each in the hand-back). Look again after the `gz4d` run. |
| Use the main tool fully; keep the work tool-neutral | Watch | The decisions list, hand-back shape and rules file are plain files readable by Codex. The skill itself is Claude-only (needs the Agent tool); say in one line that a Codex host follows the rules file by hand. |
| Verify before claiming | Watch | Several rules cite memory (e.g. "second code-review round only when the first found a real defect"); verify the wording against the audit before copying, or label it unverified. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0014 (in-process handoff) | Yes | References entry. Its handoff contract is the sub-agent hand-back shape already; do not restate. Its "one driver per issue" convention is the answer to the claim line. |
| ADR-0013 (entry vocabulary) | Yes | `**Decided-by**: host` is a new field value on `## Checkpoint`. Note it where `Decided-by` is documented (run-issue step 6); no new entry type, no script change. |
| ADR-0016 / ADR-0018 (roots, plugin) | Yes | Skill is `session_scope: both`; session-root rule: it conducts only the root it was launched in. Provisional until the acceptance run; do not mark anything about project-root behaviour as proven. |

### Consequences

- design.md edits above, in the same change.
- run-issue: "No auto-chaining", step 6 `Decided-by`, cross-reference to the new skill; keep its dialog-orientation text as the single source.
- Roadmap: paths text, written without status or dates (see (b)).
- Memory notes shrink to pointers only after the rules file merges.

### Recommendations

- **(a) Decision-rights contract.** Write it as three triggers plus the default above, and a table of run-issue's nine checkpoints: `issue-actions`, `plan`, `publish`, `rounds`, `findings`, `phase-failed`, `unexpected` are host-answered with `Decided-by: host` unless the answer would change scope, goals or hard-to-undo state; `merge` and `merge-refused` always reach the owner; `unexpected` reaches him if the host cannot map it to a vocabulary token. Test by having a Sonnet-class dispatched agent classify the 395 timeline's questions from the text alone.
- **(b) Roadmap paths.** Add a short "Paths" subsection under `## Direction`'s intro (above the step table, as the issue says): one paragraph each in the owner's words. It holds no status, no dates, no check cells, so the "holds no status" rule is not touched; the format section already ignores tables that match neither header. Define membership by rule, not by an issue list: Path 1 is work the acceptance case needs (a Direction line or the `gz4d` acceptance) or the monitoring of GeoZui4D's testing; Path 2 is any other work that serves a README goal. The sit-rep then names the path per in-flight item with no new mechanism, because every Issue Review already records a "Serves" line and every in-flight item has an Issue Review. An item matching neither is reported as "no path", which is itself the useful signal. Do not add a `Path` column to the Direction tables (changes `sitrep_checks.sh`'s grammar) and do not label GitHub issues. The focus choice (one, the other, both) is asked by the sit-rep, answered in the same session, and never stored (storing it creates status).
- **(c) Overlap with run-issue.** Stays in run-issue: state machine, nine checkpoints, self-contained dialog template, phase reuse, one-driver rule. Moves/new in the skill: which checkpoints reach the owner, the hand-back's extra lines (decisions list, reviewer outcome lines, one question at most), conduct across several issues (one agent per worktree, owner directions mid-flight go to the running agent, time box, parked items), and an orient-then-load pointer to run-issue. Keep the skill to one screen (note 8); point, don't restate.
- **(d) Standing-rules file.** No rule text (already enforced; list in one pointer line each at most): merge gate with decision summary and current review (workspace PRs, `merge_pr.sh`); bookkeeping-only commits exempt (`_bookkeeping.sh`); "triage may start before CI" (`dispatch_phase.sh next` takes no CI input); host dispatches every phase, `takeover` the sole inline row (decision table row 27); orientation line and Bash description prefix (run-issue step 6); model tier per phase (ADR-0014). Rule text needed, each with its reason: merge only when clean for project PRs (gate is report-only there); owner decides every merge; a review with open issues goes to the owner at merge; wall-clock over tokens; second code-review round only after a real defect, third a narrow convergence check without external reviewers; no new phase that cannot finish before the stated stop; reviewer outcome lines (ran/failed/skipped and why); numbers always carry a plain-words label; veto becomes a rule with its reason. Verify each against its source before copying.
- **Name.** Use `/department-head` ("interim" in the description) so the later per-root orchestrator design can take `orchestrate`.
- **Acceptance.** Keep the fresh-session run as the test; count owner-level questions and mechanism questions that reached him. State plainly that `gz4d` in-flight items will show only if the sit-rep reads that root; until then the sit-rep shows Path 1 items that live in the workspace and says so.

### Decisions made (owner may veto)

- Merge and merge-refused stay owner-level; the other seven checkpoints are host-answered under the contract.
- Skill named `/department-head`; rules file at `.agent/knowledge/host_standing_rules.md` as the issue says.
- Path membership defined by rule via the existing Serves line; no Path column, no labels.
- Parked items use the existing inbox, no new ledger file.
- Claim line and notes 11, 12, 13, 17, 18, 19 deferred to the design session; item 5 and 7 are pointers.
- Rules already enforced by scripts get no rule text.

### Questions for the owner

None. All remaining questions are mechanism and are decided above.

### Actions
- [ ] The obvious implementation copies the issue's three question kinds as a bullet list. A Sonnet or Codex host cannot apply "is this the goal you meant" as a test; it needs the decision made checkable. What it CUTS: judgment-by-vibe. What it CHANGES: each kind gets (1) a mechanical trigger and (2) a default when unsure. Kind 3 ("outward-facing or hard to undo") already has an enumerated list: AGENTS.md Ask-First (instruction files, CI/branch protection, project remote URL), the merge (design.md Rules: "owner decides every merge"), anything posted outside the repo, deleting data. Reference those, do not restate. Kind 1 trigger: the question changes what the work is for, its scope, or drops/adds a user-visible behaviour (as #395's "restart" did). Kind 2 trigger: two README goals or two principles give opposite answers (name both). Default when unsure whether a question is mechanism or goal: decide it, list it under "Decisions made (owner may veto)", and say what undoing it costs; a design-changing question is the exception and is asked alone (existing principle). Also state which of run-issue's nine checkpoints the host answers itself and records with a new `**Decided-by**: host (<reason>)`; today the doc defines only `owner`, and no script or ADR-0013 mentions the field, so #395's use was an unwritten extension.
- [ ] Limits "only the user relaxes". The owner relaxed them for checkpoints in the quoted words, but run-issue's "No auto-chaining" section says the loop "never advances past a checkpoint on its own judgment". Both cannot stand. Smallest fix: the checkpoint is still raised and written as an entry before `next`, with `Decided-by: host`; what changes is only who answers the non-owner kinds. The merge checkpoint is NOT relaxed: design.md Rules row 157 says the owner decides every merge (a `review only` rule), and project PRs are gate report-only (row 156, line 296), so nothing else would stop a host merge in `gz4d`. Write that explicitly into the skill.
- [ ] Cut list for the skill: items 4 (claim line), notes 11, 12, 13, 17, 18, 19 stay as comments on this issue for the design session. Ledger (item 6): do not add a ledger file. The inbox from #395 already exists (`settings_path inbox`); parked items go there as lines and in the hand-back's "Parked" line. Hand-back "sub-agent shape" (item 7) is already `dispatch_phase.sh`'s exit contract plus run-issue's Decision summary; point at it. Item 5 (phase→agent reuse) is run-issue step 4a, already built. Item 1 (orientation) is run-issue step 6 ("Every dialog is self-contained"); only the extra hand-back lines (decisions list, reviewer outcome lines) are new.
- [ ] Standing-rules file: see rule-by-rule split under Recommendations. Rules the scripts already enforce get no rule text (a duplicate that can drift). One enforcement gap deserves a check later, not now: "host never edits files during a drive" is `review only`.
- [ ] Required: `docs/design.md` (How it works paragraph; Review loop and timeline; Rules table row 157 wording if the host answers non-merge checkpoints), run-issue "No auto-chaining" and step 6 (`Decided-by: host`), `dispatch_phase.sh` header only if it validates `Decided-by` (it does not today: grep found no use), ADR-0014 References, `session_scope: both` + `make generate-user-tier-skills` + plugin manifest test (the skill must work in the `gz4d` session, the acceptance run), skill index in `.agent/knowledge/skill_workflows.md`/README skill lists if present.
- [ ] **(a) Decision-rights contract.** Write it as three triggers plus the default above, and a table of run-issue's nine checkpoints: `issue-actions`, `plan`, `publish`, `rounds`, `findings`, `phase-failed`, `unexpected` are host-answered with `Decided-by: host` unless the answer would change scope, goals or hard-to-undo state; `merge` and `merge-refused` always reach the owner; `unexpected` reaches him if the host cannot map it to a vocabulary token. Test by having a Sonnet-class dispatched agent classify the 395 timeline's questions from the text alone.
- [ ] **(b) Roadmap paths.** Add a short "Paths" subsection under `## Direction`'s intro (above the step table, as the issue says): one paragraph each in the owner's words. It holds no status, no dates, no check cells, so the "holds no status" rule is not touched; the format section already ignores tables that match neither header. Define membership by rule, not by an issue list: Path 1 is work the acceptance case needs (a Direction line or the `gz4d` acceptance) or the monitoring of GeoZui4D's testing; Path 2 is any other work that serves a README goal. The sit-rep then names the path per in-flight item with no new mechanism, because every Issue Review already records a "Serves" line and every in-flight item has an Issue Review. An item matching neither is reported as "no path", which is itself the useful signal. Do not add a `Path` column to the Direction tables (changes `sitrep_checks.sh`'s grammar) and do not label GitHub issues. The focus choice (one, the other, both) is asked by the sit-rep, answered in the same session, and never stored (storing it creates status).
- [ ] **(c) Overlap with run-issue.** Stays in run-issue: state machine, nine checkpoints, self-contained dialog template, phase reuse, one-driver rule. Moves/new in the skill: which checkpoints reach the owner, the hand-back's extra lines (decisions list, reviewer outcome lines, one question at most), conduct across several issues (one agent per worktree, owner directions mid-flight go to the running agent, time box, parked items), and an orient-then-load pointer to run-issue. Keep the skill to one screen (note 8); point, don't restate.
- [ ] **(d) Standing-rules file.** No rule text (already enforced; list in one pointer line each at most): merge gate with decision summary and current review (workspace PRs, `merge_pr.sh`); bookkeeping-only commits exempt (`_bookkeeping.sh`); "triage may start before CI" (`dispatch_phase.sh next` takes no CI input); host dispatches every phase, `takeover` the sole inline row (decision table row 27); orientation line and Bash description prefix (run-issue step 6); model tier per phase (ADR-0014). Rule text needed, each with its reason: merge only when clean for project PRs (gate is report-only there); owner decides every merge; a review with open issues goes to the owner at merge; wall-clock over tokens; second code-review round only after a real defect, third a narrow convergence check without external reviewers; no new phase that cannot finish before the stated stop; reviewer outcome lines (ran/failed/skipped and why); numbers always carry a plain-words label; veto becomes a rule with its reason. Verify each against its source before copying.
- [ ] **Name.** Use `/department-head` ("interim" in the description) so the later per-root orchestrator design can take `orchestrate`.
- [ ] **Acceptance.** Keep the fresh-session run as the test; count owner-level questions and mechanism questions that reached him. State plainly that `gz4d` in-flight items will show only if the sit-rep reads that root; until then the sit-rep shows Path 1 items that live in the workspace and says so.

## Plan Authored
**Status**: complete
**When**: 2026-10-15 15:00 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-321/plan.md` at `2d876881`

Skill /department-head plus a rules file; run-issue and design.md changed so the host answering seven of nine checkpoints (merge, merge-refused stay with the owner) is the documented rule; roadmap Paths prose and a path word on each sit-rep In flight line, landed after PR 396 merges. No owner questions.

## Plan Review
**Status**: complete
**When**: 2026-10-15 15:06 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #321 — Interim department-head skill: run issues with the owner at goal level only, standing rules repo-tracked, two parallel paths in the roadmap
**Plan**: `.agent/work-plans/issue-321/plan.md` at `2d876881`
**Branch**: `feature/issue-321`

First test, as asked: could a fresh Sonnet or Codex session that loads only `/department-head` and `host_standing_rules.md` run one issue the way issue 395 (the sit-rep rework) was run today? Not yet. The kind-level split of the nine checkpoints matches the host. But it is too coarse at the level of answer tokens. Two host-answered checkpoints carry tokens that merge, or that put the host to work inline. Three of today's five owner interactions fall outside the table, or depend on rules that today live only in the host's private memory.

### Checkpoint-table walk

Nine run-issue checkpoints. Host practice on 395 is from its timeline, restart checkpoint onward. Plan as written.

| Checkpoint | Host on 395 today | Plan | Same? |
|---|---|---|---|
| `issue-actions` | Host. Issue Review 13:10 had open Actions; plan dispatched; no `## Checkpoint` written | Host, entry written | Same answerer; plan adds the trail (321's own timeline also skips this entry, Issue Review → Plan Authored) |
| `plan` | Host, 12:37 `Decided-by: host`, proceed with one must-fix folded in | Host | Yes |
| `publish` | Host (PR 396 opened; no entry) | Host, entry written | Yes, but kind 3 "anything posted outside the repo" also covers a PR on GitHub: the plan contradicts itself (finding 4) |
| `rounds` | Host (three pre-push rounds, third narrow) | Host | Yes |
| `findings` | Host answered `address` | Host, whole checkpoint | No, at token level. `findings` + `merge` routes straight to `merge` (`dispatch_phase.sh` `if after in ("findings", "merge")`), and that skips the merge checkpoint. Owner rule 2026-09-22: "If a review comes back with issues, then don't merge, ask me first" (finding 1) |
| `phase-failed` | Not reached | Host, whole checkpoint | No, at token level. `takeover` emits `mode=inline`, so the host would choose by itself to do a phase's work. That loosens "host never implements inline" (finding 1) |
| `unexpected` | Not reached | Host unless unmappable | Yes |
| `merge` | Owner (PR 396 merge decision) | Owner | Yes |
| `merge-refused` | Not reached | Owner | Yes |

Five owner interactions on 395 today:

| Interaction | Host classified | Plan classifies | Same? |
|---|---|---|---|
| Restart (owner restated the goal mid-drive) | Owner, kind 1; recorded `After: implementation`, `Decision: restart`, then review-issue dispatched by hand | Kind 1 fits, but no checkpoint carries it and no recipe exists. `implementation`/`restart` is outside run-issue step 6's vocabulary ("write within the vocabulary"; row 28 if newest) | Answerer yes, mechanics no (finding 2) |
| "Yes, name GeoZui4D in the roadmap" | Owner (project-agnostic rule vs a checkable acceptance line); his answer is now the "mechanism vs record" rule | A fresh host would find design.md Rules row 161 (roadmap is history, public names allowed) and decide it. Or it would re-ask, because the owner's 2026-10-15 rule exists only in private memory | No. The answer is not carried, so a settled question gets re-asked or decided without its reason (finding 3) |
| Acceptance-case sentence, offered for veto | Host drafted it from the owner's 2026-10-14 words and listed it for veto, not asked | Ambiguous. Kind 1 ("would change what the work is for") can read as covering rewording of goal text, so a Sonnet host may ask instead | Not reliably (finding 5) |
| PR 396 merge decision | Owner | Owner (`merge`) | Yes |
| 321 go-ahead (open the issue, run it now) | Owner | Silent. No row for starting a drive or opening an issue; the focus choice exists only at sit-rep | No (finding 6) |

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Skill, rules file, run-issue/design wording, roadmap Paths prose, one sit-rep change. Each serves the issue's acceptance. Additions below are table rows and template lines, not new parts. |
| Issue alignment | Needs work | The Issue Review's cuts are all honoured. Missing: owner redirects, starting a drive, the 2026-10-15 dogfooding log on issue 398, and the owner's 2026-10-15 sit-rep readability input (findings 2, 6, 8, 9). Serves, as checked: "Trust, control and information; Easy to use. `docs/design.md#review-loop-and-timeline` and `docs/design.md#documentation-layers`." Both README goals exist (`README.md` lines 48, 88) and both anchors exist. |
| File targeting | Needs work | `docs/design.md` lines 469 and 721 are not listed (finding 7). `.agent/knowledge/README.md` index needs the rules file. `test_skill_paths.sh` already scans every `session_scope` skill, so "add to the project-capable list" means nothing more to do (verify). Sit-rep path tests belong in `test_sitrep_checks.sh`, which PR 396 owns. |
| Consequences | Needs work | Finding 7, plus `dispatch_phase.sh:693` reason text "owner decides proceed, revise, or stop" (suggestion). |
| Principle alignment | Needs work | See findings; each says what the principle cuts or changes. |
| ADR compliance | Good | ADR-0013 (vocabulary documented in run-issue step 6 and the lifecycle file, no script change), ADR-0014 (References only), ADR-0016/0018 (`session_scope: both`, `$WS_ROOT`), ADR-0017 (design.md in the same change). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Leave a trail; start limits strict: token-level rights]** The plan's table splits checkpoints by kind. Two host-answered kinds carry a token that is not the host's to give. `findings` → `merge` merges past open findings without passing the `merge` checkpoint. `phase-failed` → `takeover` runs the phase inline in the host. The owner relaxed checkpoints, not those two limits. What the principle CHANGES: the table lists allowed tokens per checkpoint, not just an answerer. Exact change in the skill's checkpoint table and in run-issue "No auto-chaining": `findings`: host may answer `address`; `merge` (deferring open boxes) is the owner's. `phase-failed`: host may answer `retry`; `takeover` is the owner's (the one inline exception, granted by his answer). `rounds`/`publish`: host may answer `publish` or `address`. `issue-actions`: `proceed`. `plan`: `proceed` or `revise`. `stop` is open to the host anywhere. Keep "Phases never dispatch each other" and "each `next` call decides exactly one step" verbatim. Add one sentence there: "A host-answered checkpoint never lets the host do a phase's work itself." Test: `test_skill_paths.sh` asserts department-head names `takeover` and the `findings`→`merge` token as owner-only.
2. **[Leave a trail: owner redirect]** No recipe for the owner restating the goal mid-drive. Today's entry (`After: implementation`, `Decision: restart`) is outside step 6's vocabulary. Exact change, decided from "Only what's needed" (no script change) and "Leave a trail": in the skill, write `## Checkpoint` with `Decided-by: owner`, `After: <the checkpoint pending, else unexpected>`, `Decision: restart`, his words verbatim. Then dispatch `review-issue` with `dispatch_phase.sh --issue <N> --skill review-issue`. Its `## Issue Review` becomes the newest entry and routes as usual, so `next` never reads `restart`. Run-issue step 6 gets one sentence naming `restart` as that host-recorded owner redirect.
3. **[Verify before claiming / A change includes its consequences: rules carried out of memory]** Step 2 builds its rule list from the Issue Review's (d) list. That list misses rules the 395 run applied, and the plan shrinks memory notes to pointers afterwards, so whatever is not carried is lost. What it CHANGES: step 2 gains a sweep. Each `feedback-*` note the 395 run applied gets a row with its reason, a pointer to where it is already written, or one line saying why it stays private. At minimum these get rows: (a) names in workspace text. Mechanism (skills, scripts, templates, tests) names no project. Record text (roadmap Direction, change log, ADR history, work plans) may name a *public* project, checked with `gh repo view --json visibility`. Reason: an acceptance line is checkable only if it names the real project (owner, 2026-10-15, issue 395). (b) Merge only when everything is clean unless he says skip. Reason: project PRs are gate report-only, design.md Rules row 156. It is its own row; the plan merges it into "owner decides every merge". (c) Never pass `--no-wait`, `--allow-pending-review` or `--force-unreviewed` unless he said so for that merge. (d) Quote recorded design before asking a design question. (e) Design questions are asked alone with what changes and how hard to undo. Also, "takeover as the only inline row" is in the plan's "already enforced" list, but nothing enforces "the host never edits repository files during a drive" (`review only`; the dispatcher only routes). Move it to the rule table with the owner's reason (2026-09-22): "Having you do the work might be faster, but I lose access to my orchestrator."
4. **[Ask about what matters: kind 3 boundary]** "Anything posted outside the repo" either catches `publish` and phase comments (which contradicts the table and today's practice) or is vague. Exact change: outward-facing means a write outside the loop's own outputs. That covers new issues, comments on other issues, anything in a repository the owner does not own, deleting data or branches not created in this drive, and the AGENTS.md Ask-First list. The loop's own push, PR and phase comments on the issue being driven are inside. A standing authorization from the owner, recorded in the rules file with his words, turns one outward class into a host action (finding 8 is the first).
5. **[Ask about what matters: goal text]** Add to the decision rights: text that states his goals (README goals, roadmap acceptance case, Direction lines, Paths) is written only from his quoted words, never invented. It goes first under "Decisions made (owner may veto)" with the quote it came from. It is a veto item, not a question. Only when no quote of his covers it is it a kind-1 question. This reproduces today's acceptance-sentence handling and covers step 4's Paths prose.
6. **[Ask about what matters: starting work]** Add a row: opening an issue and starting a drive are the owner's (AGENTS.md Issue-First: "ask the user: Should I open an issue"; the roadmap Paths focus is his). The hand-back's one question may propose the next drive. The host does not start one after a merge on its own.
7. **[A change includes its consequences: design.md]** The plan lists How it works (line 15-16), the Review loop bullet (474) and the phase table. Also edit line 469 ("anything but `OK` goes to the owner at `phase-failed` to retry, take over or stop" becomes host retry/stop, owner take over) and the glossary at line 721 ("checkpoint: a point where the loop stops and asks the owner"). Line 463 stays true once finding 1 lands. Add the rules file to `.agent/knowledge/README.md`.
8. **[Owner input 2026-10-15: dogfooding log]** Not in the plan. The owner wants the skill to report its dogfooding on the design-session issue 398 ("Orchestrator design session: one department head per root … dogfooding log for #321 until then"). Exact change: an end-of-run step in the skill. After each issue it drives, post one comment on issue 398 with `gh issue comment 398 --body-file`, AI signature, covering: what reached the owner and why; decisions made and whether any were vetoed; where the decision-rights table was wrong or silent; what the sit-rep or hand-back shape got wrong. The skill states it is an outward-facing GitHub write under a standing authorization (owner, 2026-10-15), and the rules file records that authorization with his words. Files table and tests: the skill names issue 398 and the four headings.
9. **[Give the user what they need now: sit-rep readability, owner input 2026-10-15]** Step 5 adds only a path word. After seeing the dry run, the owner said "made me wonder if it was describing the current state, or what we still need to do … a list inline with commas does not read as well as a list with an item per line". Exact template change in `.claude/skills/sitrep/SKILL.md` step 8, after PR 396 merges, same as the path word:
   - Every line starts with a lead word saying state or to-do: `Done:`, `Not yet:`, `Next:`, `In flight:`, `Problem:`. Never a sentence that could read as either. Split `<t> of <n> steps done; next: …` into `Done: <t> of <n> steps` and `Next: <line>`.
   - One item per line, never comma- or semicolon-joined. Expand `**Steps**: … Not yet done: <line>; ...`, `and <k> more: <their names>`, the inbox's new items and `No automatic check yet: <deferrals>` into bullets.
   - A blank line between sections.
   - Each In flight bullet ends with its path word.
   - Update the rules text to match and add `test_sitrep_checks.sh` cases: no `; ` join in the template's list lines; each section separated by a blank line.
10. **[Issue alignment: path word source]** The plan's rule (a Serves line naming a Direction line or the gz4d acceptance means Path 1) misclassifies the main Path 1 item. Issue 332's Serves line is "Light touch on projects … Easy to use … `docs/design.md#registry-and-adapters`" and names neither, yet issue 332 is the Direction line "GeoZui4D (`gz4d`) is onboarded through onboard-project (#332)". Serves lines name README goals by construction, so the rule sends nearly everything to Path 2. Exact change, with no new mechanism: an item whose issue number matches a Direction line's own cell (sit-rep step 5's existing match) is Path 1. Otherwise an item whose Issue Review Serves line names a README goal is Path 2. Otherwise "no path". The roadmap rule text matches. The issue body's Path 2 phrase "acceptance-case sequence" means the cases after GeoZui4D; the current acceptance case (the Direction lines) is Path 1.

### Other checks

- **Roadmap Paths prose**: in his words, no status, no dates, no table, no issue list, so it holds no status. "Any other table here is ignored" is unaffected. OK, given finding 10's wording.
- **Sequencing against PR 396 (sit-rep)**: workable. PR 396 touches `test_sitrep_checks.sh`, the sitrep skill, design.md, roadmap and its work plans. Steps 1-3 overlap only at design.md, in other sections plus a change-log row, which is a trivial append conflict. Steps 4-5 plus finding 9 wait for the merge, else a follow-up PR without `Closes`.
- **"No auto-chaining" vs the host never implementing inline**: as worded ("host answers the non-owner kinds"), it loosens the rule through `takeover`. Finding 1 closes that gap.
- **Standing-rules file**: one reason per rule is planned. Finding 3 moves one review-only rule out of the "enforced" list. The rest of that list (merge gate on workspace PRs, `_bookkeeping.sh`, model tier, orientation template) is enforced or written elsewhere. The review-round rule's source is the owner's 2026-10-15 audit in his private workplan log ("relax round counts … by trial, with an escape rate … as the stop condition"), not repo text. Cite it as such and mark the "second round only after a real defect" wording as the host's practice, unverified.
- **Suggestion**: `dispatch_phase.sh:693` prints "owner decides proceed, revise, or stop" at every plan checkpoint. Change it to "proceed, revise, or stop" so a host reading the action line is not told the opposite of the skill. No test asserts the string (grep).

### Summary

The shape is right and small. Before implementation, the decision-rights table needs answer tokens, an owner-redirect recipe, a starting-work row, a goal-text rule and a precise outward boundary. The rules file must carry the owner rules 395 actually used, and the plan must take on the two 2026-10-15 owner inputs (dogfooding log on issue 398, sit-rep readability). One revision, then ready.

### Recommended Actions

- [ ] Finding 1: per-checkpoint allowed host tokens. `findings`→`merge` and `phase-failed`→`takeover` are owner-only, in the skill, run-issue "No auto-chaining" and design.md, with a test.
- [ ] Finding 2: owner-redirect recipe (`Decision: restart` checkpoint, then review-issue dispatch); one sentence in run-issue step 6.
- [ ] Finding 3: rules-file sweep of the applied memory rules (names in workspace text, merge only when clean, no gate-relaxing flags unasked, quote design before asking, design questions alone). "Host never edits files during a drive" goes into the rule table with its reason.
- [ ] Finding 4: kind-3 boundary (the loop's own outputs inside; other GitHub writes, other owners' repos and deletes outside; standing authorizations recorded).
- [ ] Finding 5: goal text from his quoted words, listed first for veto.
- [ ] Finding 6: opening an issue or starting a drive is the owner's.
- [ ] Finding 7: design.md lines 469 and 721; `.agent/knowledge/README.md` entry.
- [ ] Finding 8: end-of-run dogfooding comment on issue 398, marked outward-facing under standing authorization.
- [ ] Finding 9: sit-rep template lead words, one item per line, blank lines between sections, tests (after PR 396).
- [ ] Finding 10: path word from the Direction-line cell match first, then Serves, else "no path".
- [ ] Acceptance test: the Sonnet classification check covers today's five interactions and the two owner-only tokens, recorded in progress.md.

### Decisions made (owner may veto)

- The host may answer `stop` at any checkpoint. `merge` from `findings` and `takeover` from `phase-failed` stay his, because they bypass the merge checkpoint or the host's no-inline rule.
- The loop's own push, PR and phase comments on the driven issue are not outward-facing. Other GitHub writes are, unless a standing authorization of his is recorded.
- A restart is recorded as `Decision: restart` and re-entered through a review-issue dispatch, with no dispatcher change.
- Path 1 means the issue is named in a Direction line's own cell. "Acceptance-case sequence" in the issue body means later acceptance cases, which are Path 2.
- `dispatch_phase.sh:693`'s reason text is reworded (suggestion; implementer may skip it).

No owner-level questions: the goal reading matches the issue and the owner's two 2026-10-15 inputs, no two goals conflict, and the one outward write (issue 398 comments) is already authorized in his words.

## Plan Authored
**Status**: complete
**When**: 2026-10-15 15:07 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-321/plan.md` at `cff251c4`

Revision after Plan Review dfd6cd5d: rebased on merged PR 396; checkpoint table limits tokens (findings never merge, phase-failed never takeover); recipes for restart, project naming, owner-text veto, starting a drive, merge; rules sweep; outward line; design.md 469 and 721; Path 1 by Direction cell; issue 398 dogfooding step; sit-rep lead words and spacing. No owner questions.

## Plan Review
**Status**: complete
**When**: 2026-10-15 15:10 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #321 — Interim department-head skill: run issues with the owner at goal level only, standing rules repo-tracked, two parallel paths in the roadmap
**Plan**: `.agent/work-plans/issue-321/plan.md` at `cff251c4`
**Branch**: `feature/issue-321`
**Serves**: Trust, control and information; Easy to use. `docs/design.md#review-loop-and-timeline` and `docs/design.md#documentation-layers` (checked in round 1; unchanged).

Round 2, convergence check on the revision of round 1 (`dfd6cd5d`; the round had ten findings, eight of them owner-routing must-fixes). Nine are resolved in the plan text. Finding 1 is resolved in the skill but not in run-issue. The walk of today's eight issue-395 decisions lands six where they landed. Two do not land reliably: the third review round, and the research cap. Three one-sentence fixes; each can be folded into the implementation's first plan.md commit, as on issue 395.

### Round-1 findings

| # | Status | Plan text that resolves it |
|---|---|---|
| 1 Token-level rights | Partly | Skill: "`findings`: `address`; `merge` (deferring open boxes) is the owner's. `phase-failed`: `retry`; `takeover` is the owner's … A host-answered checkpoint never lets the host do a phase's work itself." Not in run-issue: step 3 says only "No auto-chaining (host answers the non-owner kinds; merge and merge-refused still wait for the owner)". See must-fix 1. |
| 2 Owner redirect | Resolved | Recipe (a): "`Decision: restart`, his words verbatim; then dispatch `review-issue` … so `next` never reads `restart`. Run-issue step 6 gets one sentence." |
| 3 Rules sweep | Resolved | Step 2: "each `feedback-*` note applied gets a row with its reason, a pointer … or one line on why it stays private". Names, merge-when-clean as its own row, the three gate flags, quote design, design questions alone, and "the host never edits repository files during a drive" (with his 2026-09-22 reason) are all listed. |
| 4 Outward boundary | Resolved | "inside the boundary are the loop's own push, PR creation, signed comments on the issue being driven and progress entries. Everything else outward goes to the owner … A standing authorization of his … turns one outward class into a host action". |
| 5 Goal text | Resolved | Recipe (c): "written only from his quoted words; the host drafts it, shows the sentence with its quote under 'Decisions made (owner may veto)', and only a 'no' changes it." |
| 6 Starting work | Resolved | Recipe (d): "opening an issue and starting a drive are the owner's … the host never starts one on its own after a merge." |
| 7 design.md, index | Resolved | Step 3 names lines 469 and 721 and the glossary; step 2 adds the `.agent/knowledge/README.md` entry. After the rebase they sit at lines 472 and 724 (see Decisions). |
| 8 Issue 398 log | Resolved | Skill bullet "Dogfooding step", four headings, signed `gh issue comment 398 --body-file`; Tests assert issue 398 and the headings. |
| 9 Sit-rep readability | Resolved | Step 5: lead words, "one item per line, never comma- or semicolon-joined", "a blank line between sections", with `test_sitrep_checks.sh` cases. |
| 10 Path word | Resolved | Step 4/5: "an issue named in a Direction line's own cell is Path 1; everything else serving a README goal is Path 2 … otherwise `no path`." |

### Walk: today's issue 395 decisions through the plan

| Decision on 395 | Landed today | Plan routes it | Same? |
|---|---|---|---|
| Restart (owner restated the goal) | Owner; `Decision: restart`; review-issue dispatched | Recipe (a): owner entry, then review-issue dispatch. `After` becomes `unexpected` instead of today's out-of-vocabulary `implementation`; same route | Yes |
| "Yes, name GeoZui4D" | Owner (agnostic rule vs a checkable acceptance line) | Kind 2 when first met; now settled by recipe (b), with his reason, "not re-asked" | Yes |
| Acceptance sentence offered for veto | Host drafted from his 2026-10-14 words, listed for veto | Recipe (c) | Yes |
| Merge of PR 396 | Owner, after the decision summary | Table: `merge` always the owner's; recipe (e) | Yes |
| Go-ahead to start issue 321 | Owner | Recipe (d) | Yes |
| Second review round (round 1 found 4 must-fix) | Host | Mechanical. A pre-push entry not `approved` routes to `address-findings`, then `review-code`, with no checkpoint (`dispatch_phase.sh`, Local Review (Pre-Push) block); rules-file row | Yes |
| Third round narrow, no externals | Host, in the handoff | Rules-file row, but marked "the host's practice, unverified", and it contradicts review-code's written fix-round rule: "never lower it below the whole-diff classification … A Standard or Deep result dispatches cross-model as usual" (#320). A fresh host follows the written skill and runs Gemini and Codex, or asks the owner | No (must-fix 2) |
| Research auto-run capped at three topics | Host ("the cost is handled by the cap in the suggestion, not by asking") | Kind 1's trigger "add/drop a user-visible behaviour" reads literally on it: the cap drops 16 of 19 topics from each run. So do 395's other host calls ("long issue titles print in full", the unchecked onboarding line). A literal Sonnet host asks | Not reliably (must-fix 3) |

**"No auto-chaining" vs "host never implements inline"**: not intact as step 3 words it. "Host answers the non-owner kinds" makes `phase-failed` a host answer in run-issue, and `takeover` there emits `mode=inline`. The limit lives only in `/department-head`, but run-issue is the state machine every host reads, with or without that skill.

**Standing-rules file, a reason per rule**: yes in structure ("table of rule / reason"; each swept rule "gets a row with its reason"). The plan spells out reasons for five rows only. "Never pass the gate flags", "quote recorded design", "design questions alone", "wall-clock over tokens" and the review-round rule leave theirs to the implementer. Covered by the test in Decisions.

### Findings

1. **[Leave a trail; start limits strict — run-issue keeps the inline limit]** Step 3, the run-issue "No auto-chaining" edit. Replace "host answers the non-owner kinds; merge and merge-refused still wait for the owner" with: "The host may answer a checkpoint itself, with the tokens `/department-head`'s table allows, written `Decided-by: host (<reason>)`. `merge` and `merge-refused` always wait for the owner, and so do `takeover` at `phase-failed` and `merge` at `findings`. A host-answered checkpoint never lets the host do a phase's work itself." Tests: `test_skill_paths.sh` asserts that run-issue names `takeover` as owner-only.
2. **[Verify before claiming; Ask about what matters — the round-3 rule]** Step 2's review-round row. Source: the issue 321 body, which any session can read ("Review depth follows the audit's rule: a second code-review round only when the first found a real defect; a third is a narrow convergence check without external reviewers"). The owner's private audit is the background only. Drop "unverified". State the mechanism: the round-3 handoff names its scope (the prior round's items and the fix diff) and says "no cross-model reviewers". It is the owner's standing exception to review-code's fix-round rule (#320) for round 3 only. Reason: each round costs about 20–25 minutes, and a convergence check re-reads only the fixes. Without this, the decision lands with the externals run, or with the owner.
3. **[Ask about what matters — kind 1 trigger]** Step 1, kind (1). Replace "add/drop a user-visible behaviour" with "add or drop a behaviour his quoted words ask for or rule out. How a behaviour he asked for works (its limits, wording, order, format, defaults) is a host decision listed for veto (395: research auto-start capped at the three oldest topics; long titles printed in full)."

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged; one PR. |
| Issue alignment | Good | Both 2026-10-15 owner inputs (issue 398 log, sit-rep readability) are in. Serves line above, as checked. |
| File targeting | Good | design.md line numbers moved by 3 after the rebase (Decisions). |
| Consequences | Good | Round-1 additions all listed. |
| Principle alignment | Needs work | Findings 1–3. |
| ADR compliance | Good | 0013, 0014, 0016/0018, 0017 as in round 1. |
| ROS conventions | N/A | Workspace plan. |

### Summary

Nine of ten round-1 findings are resolved. The fixes are three sentences: run-issue keeps `takeover` and `findings`→`merge` with the owner; the round-3 rule cites issue 321 and states its exception to #320; kind 1 stops catching tuning of behaviour the owner already asked for. Folded into the implementation's first commit, the plan is ready, with no third plan review.

### Recommended Actions

- [ ] Finding 1: the run-issue "No auto-chaining" text names the owner-only tokens and the no-phase-work sentence; add a test.
- [ ] Finding 2: the round-3 row cites the issue 321 body, gives the mechanism, the #320 exception and the reason.
- [ ] Finding 3: narrow kind 1's trigger to behaviour his words ask for or rule out.

### Decisions made (owner may veto)

- The three fixes are folded into the implementation's first plan.md commit, with no third plan review (as on issue 395).
- design.md edits are placed by quoted text, not line number: "take over or stop" is now line 472, the glossary line 724, "Nine checkpoint kinds" line 476.
- Drop step 1's duplicate "Decision rights" bullet (the second one restates the first).
- `test_skill_paths.sh` also asserts that every row of the rules table has a non-empty reason cell. That is the simplest check that keeps "a reason per rule".
- Recipe (a) waits for any running phase to return before it dispatches review-issue (one agent per worktree).

No owner-level questions: no finding changes what the work is for, no two of his goals conflict, and nothing new is outward-facing.

## Checkpoint
**Status**: complete
**When**: 2026-10-15 15:11 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (under the issue's contract: no owner-level question arose)
**After**: plan
**Decision**: proceed

Plan Review round 2 (ab5123e3): nine of ten round-1 findings resolved; six of the eight decisions from today's #395 run land where they did. Three one-sentence fixes remain, folded into the implementation's first commit as the reviewer recommends, no third plan review: (1) run-issue's "No auto-chaining" edit names `takeover` at phase-failed and `merge` at findings as the owner's answers, so a host never runs a phase inline or merges past open findings; (2) the review-round rule (second round only after a real defect; third narrow, no externals) is stated as the rule in the standing-rules file and reconciled with review-code's fix-round rule (#320) so a fresh host does not re-run externals on a convergence check; (3) the outward-facing line is worded so a host-made cap on a background read-only run (the research three-topic cap) is a listed decision, not an owner question. Also: every standing-rule row carries its reason, with a test; design.md edits placed by quoted text; the restart recipe waits for any running phase.

Decisions made this round (owner may veto): the host decided the checkpoint; the dogfooding comment on #398 is inside the outward boundary because the owner asked for it.

## Implementation
**Status**: complete
**When**: 2026-10-20 13:07 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-321 at `c6759ef1`

Plan Approach items 1 to 6 were already on the branch in nine commits (16bf013d through 002bd5a9): the `/orchestrator` skill, `host_standing_rules.md` and its knowledge-index entry, run-issue's "No auto-chaining", step 6 and checkpoint text, design.md (How it works, phase table, exit-check and checkpoint bullets, glossary, Rules row, Direction row, change log), the lifecycle file, the ADR-0014 References entry, the `dispatch_phase.sh` plan reason text, the roadmap Paths paragraphs, the sit-rep path word and readability, and their tests. This pass added what was still missing:

- Item 7, plugin manifest: `make generate-user-tier-skills` rewrote `.claude-plugin/plugin.json` with no change; the orchestrator path was already in it.
- Item 7, skill list: `.agent/knowledge/skill_workflows.md` lists skills, so it gets an `orchestrator` row (bfc999cb).
- Tests: the plan's guard "roadmap.md has both paths with no `|` table row between the Paths paragraphs" was missing; added to `test_skill_paths.sh`, and checked by hand that it fails on a table row between the paragraphs and on a missing Path 2 paragraph (7f8d5ebc).
- Tests, dispatched-agent check: a Sonnet agent read only the orchestrator SKILL.md and `host_standing_rules.md` and classified ten situations from issue 395's drive. It matched the intended answer on all ten. Restart: owner, recipe (a). Project name in the roadmap: host, not re-asked, recipe (b). Quoted acceptance-case sentence: host, listed for veto, recipe (c). Starting the next drive: owner, recipe (d). Merge: owner. Merge past open findings: owner only. MISSING exit check: host retry or stop, `takeover` owner only. Research cap on a read-only run: host, listed. Title truncation: host. Plan proceed: host. One real conflict found: the outward boundary's "an edit to his text" also claimed recipe (c)'s quoted drafts; the boundary now excludes text drafted from his quoted words (c6759ef1). Left as is, not this skill's to fix: no retry limit at `phase-failed` (run-issue's), and how far a mid-drive restatement must differ before it counts as a restart.
- Tests run: `.agent/scripts/tests/run_script_tests.sh` passed as the pre-commit hook on each commit; `test_skill_paths.sh` 69 passed, 0 failed; pre-commit on every file changed on the branch (`git diff --name-only main...HEAD`) passed.
- The three commits above were first made under the human git identity (identity env not carried into the commit shell) and were re-authored to the agent identity by a rebase before this entry; none had been pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-20 13:15 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-321 at `f8501d77`
**Base**: main
**Depth**: Deep (reason: 1243 changed lines across 16 files, with skill, knowledge and ADR files)
**Must-fix**: 2 | **Suggestions**: 7
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Specialists: static analysis (shellcheck clean; pre-commit on every changed file passed, including the script test suite), governance, plan drift, Claude adversarial (test_skill_paths 69/0, test_sitrep_checks 183/0), cross-model Gemini (ran, 6 findings: 3 verified false positives dropped — the `; offered` template join is `, offered` and the test passes; `slug` is reset each loop; `SendMessage` exists — 2 dropped as matching the workspace's own idioms, 1 kept) and Codex (ran, 1 finding, kept).

### Findings
- [x] (must-fix) Path 2 is any non-empty `**Serves**:` line anywhere on the timeline, so `**Serves**: none` (which review-issue's template allows) reads as Path 2, and an older positive line outranks a newer `none`; read the newest Issue Review's Serves, treat `none` as no path, and add both cases to test_sitrep_checks.sh (Codex) — `.claude/skills/sitrep/SKILL.md:336`
- [x] (must-fix) The review-round rule is not reconciled where the rules it overrides live: review_depth_classification.md "Fix-Round Re-Reviews" and review-code step 2 still say a fix round is never lowered (#320, owner) with no round-3 exception, review-code has no way to take "no cross-model reviewers" from a handoff, and "a second round only after a real defect" has no lever (dispatch_phase.sh routes a changes-requested review to address-findings and then review-code with no checkpoint) — `.agent/knowledge/host_standing_rules.md:30`
- [x] (suggestion) Roadmap Path 2 lists "a backlog sweep (#321)", which mislabels issue 321 (the orchestrator skill) and is printed verbatim in the sit-rep's closing question, while the sit-rep classifies 321 as Path 1 through its Direction line — `docs/roadmap.md:47`
- [x] (suggestion) Recipe (a) has no resume path: if the session ends between the `Decision: restart` checkpoint and the review-issue entry, `next` routes to `unexpected`, which the table sends to the owner as a mechanism question; say the host re-dispatches review-issue in that state — `.claude/skills/orchestrator/SKILL.md:102`
- [x] (suggestion) The host may answer `retry` at `phase-failed` and `revise` at `plan` with no cap, so a persistent failure can loop without the owner; add "after N host retries, ask the owner" (Claude adversarial) — `.claude/skills/orchestrator/SKILL.md:81`
- [x] (suggestion) "`stop` is open to the host at any checkpoint" contradicts the `merge` and `merge-refused` rows ("—"); state the exception and that a host `stop` is recorded `Decided-by: host` (Claude adversarial) — `.claude/skills/orchestrator/SKILL.md:84`
- [x] (suggestion) The issue 398 comment block derives the repo from `$WS_ROOT`'s origin; with the `.` fallback in a project session it would post to the project's repository; abort when `WS_REPO` is empty or not the workspace repo (Claude adversarial) — `.claude/skills/orchestrator/SKILL.md:181`
- [x] (suggestion) Path 1's `\(#[0-9]+[,)]` match takes only the first issue of a list like "(#101, #102)"; none in the roadmap today, but the comment promises "(#N" in a line's item (Gemini) — `.claude/skills/sitrep/SKILL.md:213`
- [x] (suggestion) Plan drift, for the record: Path 1 also counts a project named by an `adapter --project` check, and the roadmap gained a Direction line for 321 (owner's instruction quoted in 002bd5a9); both beyond the plan's text, both consistent with it — `docs/roadmap.md:75` (deferred: a record of plan drift, no change asked: both additions are consistent with the plan and are listed in this round's Implementation entry)

## Implementation
**Status**: complete
**When**: 2026-10-20 14:14 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-321 at `336503c1`
**Addressed**: Local Review (Pre-Push) at `f8501d77` (2026-10-20 13:15 -04:00)
**Commits**: 87ba79b8, 07524c62, f8d16509, a64c77a6, 816fb1b2, d929eb89, 312a1f2b, 3019b499, 42eb1122, 336503c1

### Actions
- [x] (must-fix) Sit-rep Path 2 reads only the newest Issue Review's Serves line (fence-aware); `none` (any case, quoted or bold) is no path; tests for a lone `none`, a newer `none` over an older goal, a newer goal over an older `none`, Serves outside an Issue Review, Serves in a fence, and "Nonetheless…" — `.claude/skills/sitrep/SKILL.md:330` (87ba79b8)
- [x] (must-fix) Review-round rule reconciled per the host's direction: the rules row says its first half is the ship verdict's rule (`review_progress.sh verdict`) and points at where the second half lives; the round-3 exception is in `review_depth_classification.md` ("Round-3 convergence check", with a one-line pointer from the issue 320 text) and review-code step 2 (what to look for in the task text); `dispatch_phase.sh` appends the scope and "no cross-model reviewers" to a pre-push review-code task line at round 3+, tested for rounds 1-4, another branch, PR mode and a detached worktree; ADR-0015's Status points at the exception — `.agent/knowledge/host_standing_rules.md:30` (07524c62, f8d16509, 336503c1)
- [x] (suggestion) Roadmap Path 2: dropped "(#321)" after "a backlog sweep" (no issue tracks the sweep); his words unchanged — `docs/roadmap.md:47` (a64c77a6)
- [x] (suggestion) Recipe (a) resume path: a `restart` checkpoint with no Issue Review after it is re-dispatched to review-issue by the host; `unexpected` row and run-issue's note updated — `.claude/skills/orchestrator/SKILL.md:102` (816fb1b2)
- [x] (suggestion) Host `retry`/`revise` capped at two in a row per checkpoint, counted from the timeline; run-issue points at the limit — `.claude/skills/orchestrator/SKILL.md:84` (d929eb89)
- [x] (suggestion) Host `stop` excluded at `merge` and `merge-refused`, recorded `Decided-by: host` elsewhere — `.claude/skills/orchestrator/SKILL.md:84` (312a1f2b)
- [x] (suggestion) Issue 398 log resolves a repository only when `$WS_ROOT` is the workspace checkout (holds `dispatch_phase.sh`), else prints "not posted" for the hand-back; pinned in test_skill_paths — `.claude/skills/orchestrator/SKILL.md:181` (3019b499)
- [x] (suggestion) "(#N, #M)" lists: one list-aware match in sit-rep steps 3 and 5, tested in both — `.claude/skills/sitrep/SKILL.md:213` (42eb1122)
- [x] (suggestion) Plan drift record — `docs/roadmap.md:75` (deferred: a record of plan drift, no change asked; both additions are consistent with the plan)

### Checks
- `run_script_tests.sh`: all 37 suites passed (test_sitrep_checks 185/0, test_dispatch_phase 119/0, test_skill_paths 70/0).
- pre-commit on every changed file: passed (validate-script-tests skipped in that run only, since the full suite had just run).
- New tests fail on the old code (checked for the Serves case: 183/1 before the fix).
- The issue 398 block's guard was not executed end to end: running the extracted block was denied by the permission system; it is covered by reading and the text pin.

### Decisions made (owner may veto)
- Round 1 with suggestions but no must-fix still gets a round 2 in the loop as it routes today: review-code writes `**Verdict**: changes-requested` whenever any finding survives, and `dispatch_phase.sh next` routes on Verdict (to address-findings, then review-code), not on the `**Ship**` line. The rules row therefore says the first half is the ship verdict's rule, not that the routing enforces it — undoing it: reword the row; making routing follow it is a `next` change the host did not ask for.
- The round-3 scope goes on the task line (which every host pastes), not a new handoff key — undoing it: move it to its own key and update run-issue's paste list.
- PR mode has no round counter, so `dispatch_phase.sh` prints the round-3 words for pre-push only; a host may write them into a PR-mode handoff — undoing it: count PR-mode `## Local Review` rounds in the script.
- Host retry/revise cap set at two in a row — undoing it: change the number in one sentence.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-20 14:23 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-321 at `02e72bd6`
**Base**: main
**Depth**: Deep (reason: whole-diff classification for a fix round: 1399 changed lines across 20 files, with skill, knowledge, script and ADR files)
**Must-fix**: 2 | **Suggestions**: 2
**Round**: 2 | **Ship**: continue — round 2: 2 must-fix include a design/correctness concern (not mechanical)

Specialists: static analysis (shellcheck clean on the 4 changed scripts; pre-commit on every changed file passed, script-test hook skipped there because the suites ran separately), governance, plan drift (fix-round files beyond the plan all trace to round 1's must-fix and are listed in the Implementation entry), Claude adversarial (test_dispatch_phase 119/0, test_sitrep_checks 185/0, test_skill_paths 70/0), cross-model Gemini (ran, 5 findings: 1 kept merged into a suggestion; dropped: the progress file is under the worktree for every --type, as --check-exit and next read it; handoff is dispatch_phase.sh's default mode; `<...>` placeholders are the skill's fill-in idiom; the trailing space after `gh-issue N` is the check grammar) and Codex (ran, 2 findings, both kept). Round 1's 8 actionable items are confirmed fixed in 87ba79b8..336503c1.

### Findings
- [x] (must-fix) The round-3 handoff counts rounds with `review_progress.sh round`, which counts every pre-push review entry on the branch whatever its Status, while `next`'s round_count counts only `complete` ones; one failed attempt makes the second real review a "round 3" with no cross-model reviewers, and two failed attempts give a convergence check before any complete review; count only complete entries here and test a failed and a partial entry (Codex, Claude adversarial, lead) — `.agent/scripts/dispatch_phase.sh:359`
- [x] (must-fix) A recipe (a) restart does not reset the round count: after a restart following two reviews, the first review of the new implementation is handed off as a round-3 convergence check on the old work's findings, skipping cross-model, and `next` reaches MAX_ROUNDS on it; count only reviews after the newest `**Decision**: restart` checkpoint (in the handoff and in `next`'s round_count) and test it, including the untested restart -> `checkpoint:unexpected` route (Codex) — `.agent/scripts/dispatch_phase.sh:359`
- [x] (suggestion) The `rounds` checkpoint (raised when the loop hits MAX_ROUNDS without approval) is host-answerable with `address` with no cap, so rounds 4, 5, ... can run without the owner; extend the two-in-a-row cap to `address` at `rounds` (the plan-approved table otherwise unchanged) (Gemini, lead) — `.claude/skills/orchestrator/SKILL.md:77`
- [x] (suggestion) A newest Issue Review that is partial or failed and has no `**Serves**:` line erases an older complete review's goal (the worktree reads "no path"); skip non-complete Issue Reviews or keep the last Serves of a complete one, and add the case to test_sitrep_checks.sh (Claude adversarial) — `.claude/skills/sitrep/SKILL.md:340`

## Implementation
**Status**: complete
**When**: 2026-10-20 14:38 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-321 at `ebd59aa3`
**Addressed**: Local Review (Pre-Push) at `02e72bd6` (2026-10-20 14:23 -04:00)
**Commits**: 438fb3bf, 360cbad4, 2d822cc7, ebd59aa3

### Actions
- [x] (must-fix) Round count counts only complete pre-push reviews: fixed in `review_progress.sh round` itself, the counter the round-3 handoff calls, so the handoff, review-code's **Round** field and `next` all count one way; tests for a failed and a partial entry in test_review_code_convergence.sh, test_dispatch_phase.sh (handoff and `next`) — `.agent/scripts/review_progress.sh:102`, `.agent/scripts/dispatch_phase.sh:23`
- [x] (must-fix) A restart checkpoint starts the round count over: `review_progress.sh round` and `next`'s round_count count only reviews after the newest `**Decision**: restart` checkpoint; tests for a restart followed by reviews (round, handoff, `next` incl. reaching MAX_ROUNDS on the new work's own third review) and the previously untested restart -> `checkpoint:unexpected` route; orchestrator recipe (a) says so — `.agent/scripts/dispatch_phase.sh:627`, `.claude/skills/orchestrator/SKILL.md:110`
- [x] (suggestion) The two-in-a-row cap on host answers now covers `address` at `rounds`; test_skill_paths pins all three capped answers — `.claude/skills/orchestrator/SKILL.md:84`
- [x] (suggestion) Sit-rep reads Serves from the newest complete Issue Review only; a partial or failed one leaves the older Serves in place; test_sitrep_checks covers partial and failed reviews with and without a Serves line — `.claude/skills/sitrep/SKILL.md:331`

### Decisions made (owner may veto)
- The complete-only and restart rules went into `review_progress.sh round`, not a second counter in `dispatch_phase.sh`: the handoff already calls it, and review-code records its **Round** from it, so one rule keeps the handoff's round and the review's own Round field equal. Undoing it: revert 438fb3bf and 360cbad4's `review_progress.sh` hunks.

### Tests
Fix commits used `SKIP=validate-script-tests` (host decision for this pass). The full suite ran once at the end of the pass: `.agent/scripts/tests/run_script_tests.sh`, all 37 suites passed (test_dispatch_phase 127/0, test_review_code_convergence 35/0, test_sitrep_checks 185/0, test_skill_paths 71/0). pre-commit on every file changed in this pass passed (script-test hook skipped there, as the suite had just run); this entry's commit runs the hook normally.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-20 14:46 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-321 at `ea2491f1`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff; whole diff 1667 changed lines across 22 files, with skill, knowledge, script and ADR files)
**Must-fix**: 1 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — round 3: 1 mechanical must-fix (prev 2), not rising; fix and ship rather than another full round

Scope: round 2's four findings and the fix diff since it (438fb3bf, 360cbad4, 2d822cc7, ebd59aa3). Specialists: static analysis (shellcheck clean on the 6 changed scripts), governance, plan drift (every fix-pass file traces to a round-2 finding), Claude adversarial (1 suggestion, verified with a crafted timeline; the two round counters checked to agree on restart, status, branch and fences); cross-model skipped (round-3 convergence check, per handoff). Round 2's 4 findings are confirmed fixed: complete-only counting and the restart reset live in `review_progress.sh round` and `next`'s round_count alike, the cap covers `address` at `rounds`, and sit-rep reads Serves from the newest complete Issue Review. Tests: test_dispatch_phase 127/0, test_review_code_convergence 35/0, test_sitrep_checks 185/0, test_skill_paths 71/0. A check that the new tests fail on the pre-fix code was not run here (the command was denied by the permission system); the adversarial reviewer judged them discriminating by reading.

### Findings
- [ ] (must-fix) The design picture still describes `round_count` as the count of completed pre-push reviews on the branch, without the new reset at the newest `**Decision**: restart` checkpoint; add that clause in both places that describe it (ADR-0017) — `docs/design.md:461`, `.agent/knowledge/review_loop_lifecycle.md:57`
- [ ] (suggestion) The sit-rep awk takes `**Status**:` from anywhere in an Issue Review body, while `progress_read.py` reads Status only from the header; a `**Status**: partial` line under a `###` subsection of a complete review drops its Serves (verified with a crafted timeline); stop the Status match at the first `### ` line — `.claude/skills/sitrep/SKILL.md:338`
