---
issue: 425
---

# Issue #425 — Promote ADR-0018 to Accepted

## Issue Review
**Status**: complete
**When**: 2026-11-09 14:06 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #425

### Scope Assessment

**Well-scoped?** Yes — a status-line flip plus four dependent text spots; same shape as #423 / PR 424.
**Right repo?** Yes — workspace (ADR, design.md, review guide).
**Serves**: "The long view" (what is proven is recorded as proven) — `docs/design.md#sessions-and-roots`
**Design picture?** Changes Sessions and roots (Now block, register row) — status text only; the owner's decision is recorded in the issue, so no re-ask.
**Dependencies**: none (follow-up to #423, merged as PR 424; #351 separate).

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | The design.md spots checked: Sessions and roots Now block (lines ~188-190, "is still Provisional; ... promoting it is the owner's call"); register row 0018 (line 727, Status cell Provisional -> `in force`); Status key `decided, not proven` (line 70) names no ADR, no 0018 example, so no change needed; change-log row for 2026-11-09 with section names and the new `wc -l`. Change-log lines 799 and 813 are dated history and stay as written. Anchor check will confirm. |
| Verify before claiming | Watch | Evidence sentence must cite only what the issue records (GeoZui4D #9 and #7 drives, #423, owner decision 2026-11-09); the "found every prefixed skill" claim is the session's report, so word it as reported. |
| Only what's needed | OK | No Decision of ADR-0018 changes. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0008 | Yes | Status-line edit only; keep the original condition as history. |
| 0016 | Checked | Its Status paragraph (lines 22-27) describes the supersession of decision 3 and the settings.local.json exception, and names no status for 0018; no edit needed. |
| 0017 | Yes | design.md change in the same PR, with Change log row. |
| 0018 | Yes | Status first paragraph (line 5) and the "Promote to Accepted when..." paragraph (lines 11-13) both need rewording so none says it waits on a run. The Acceptance section (line 337) is a decision-time description of how the run counts; leave it. |

### Consequences

- `.agent/knowledge/principles_review_guide.md:53`: row ends "Status **Provisional**; its own promotion condition, the same GeoZui4D run, is met, and promoting it is the owner's call" -> Accepted with date.
- Repo-wide grep (outside work-plans) finds no other live Provisional claim about ADR-0018; hits on design.md 799/813 are dated change-log history.

### Recommendations

- ADR-0018: replace the first Status paragraph's `**Provisional.**` with `**Accepted** (2026-11-09)`, keep the supersession text, and fold the "Promote to Accepted when..." paragraph into history (original condition plus one evidence sentence naming the two GeoZui4D drives, #423 and the owner decision), as ADR-0016's Status does.
- design.md: rewrite the Now-block clause (~188-190) to say ADR-0018 is Accepted too, set register row 0018 to `in force`, and add a 2026-11-09 Change log row (Sessions and roots, Decision register) with the correct `wc -l`.
- Review guide row 0018: replace the Provisional sentence with Accepted (2026-11-09, #425).
- Leave ADR-0016 untouched (it names no status for 0018); verify with `adr-status` for 0018, `check_design_anchors.sh`, and `sitrep_checks.sh --root <worktree>`.

### Actions
- [ ] The design.md spots checked: Sessions and roots Now block (lines ~188-190, "is still Provisional; ... promoting it is the owner's call"); register row 0018 (line 727, Status cell Provisional -> `in force`); Status key `decided, not proven` (line 70) names no ADR, no 0018 example, so no change needed; change-log row for 2026-11-09 with section names and the new `wc -l`. Change-log lines 799 and 813 are dated history and stay as written. Anchor check will confirm.
- [ ] ADR-0018: replace the first Status paragraph's `**Provisional.**` with `**Accepted** (2026-11-09)`, keep the supersession text, and fold the "Promote to Accepted when..." paragraph into history (original condition plus one evidence sentence naming the two GeoZui4D drives, #423 and the owner decision), as ADR-0016's Status does.
- [ ] design.md: rewrite the Now-block clause (~188-190) to say ADR-0018 is Accepted too, set register row 0018 to `in force`, and add a 2026-11-09 Change log row (Sessions and roots, Decision register) with the correct `wc -l`.
- [ ] Review guide row 0018: replace the Provisional sentence with Accepted (2026-11-09, #425).
- [ ] Leave ADR-0016 untouched (it names no status for 0018); verify with `adr-status` for 0018, `check_design_anchors.sh`, and `sitrep_checks.sh --root <worktree>`.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 14:06 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the five open actions are mechanism: which design.md spots change, the ADR Status wording with the condition kept as history, the review-guide row, leaving ADR-0016 alone, and the verification commands; the owner decided the promotion)
**After**: issue-actions
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. The actions go to plan-task as plan inputs.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 14:07 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-425/plan.md` at `a014caf1`

Status-line promotion of ADR-0018 (condition folded into history with one evidence sentence), plus the design.md Now clause, register row and Change log row, and the review-guide row; ADR-0016 needs no edit. Single docs-only PR, no owner questions.

## Plan Review
**Status**: complete
**When**: 2026-11-09 14:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #425 — Promote ADR-0018 to Accepted: its condition (ADR-0016's acceptance run) passed on 2026-11-09
**Plan**: `.agent/work-plans/issue-425/plan.md` at `a014caf1`
**Branch**: `feature/issue-425`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Three docs files, status text only; same shape as #423 / PR 424 |
| Issue alignment | Good | Every "What to change" bullet and all review-issue actions are covered. Serves: "The long view (README Workspace goals): what is proven is recorded as proven. `docs/design.md#sessions-and-roots`" — README `### The long view` (line 106) and `## Sessions and roots` (design.md:177) both exist; no stated rule is broken |
| File targeting | Good | Repo-wide `git grep -niE provisional` outside work-plans: the only live claims about ADR-0018 are ADR-0018:5 and 11-13, design.md:189 and 727, principles_review_guide.md:53, all in the plan. Other hits are generic (design.md:70 Status key, :701 register key, audit-workspace SKILL.md:65), dated history (design.md:799, 813), the digests, or the unrelated records-default "provisional". `git grep 0018` shows no status claim elsewhere; docs/roadmap.md has no ADR-0018 line. ADR-0016:22-27 names no status for 0018 (confirmed) |
| Consequences | Needs work | Change-log row misses the Change log section's own rule for long sections (finding 2) |
| Principle alignment | Good | Verify before claiming: the route is backed by records — the GeoZui4D root's `.claude/settings.local.json` enables `agent-workspace@agent-workspace` from this checkout, `~/.claude/skills` holds no workspace symlinks, and both GeoZui4D timelines (issue-9, issue-7) carry entries from every dispatched phase; the timelines do not name the prefix, so wording "found the prefixed skills" as the session's own report is correct. Test what breaks: docs-only, no test needed; the adr-status check is the proof |
| ADR compliance | Good | ADR-0008: only the Status section is edited; the Acceptance subsection (under Consequences, line 337) correctly stays. ADR-0017: design.md and Change log row in the same change. ADR-0016 untouched |
| ROS conventions | N/A | Workspace plan |

### Findings

1. **[Principle alignment]** (suggestion) — Step 5's `sitrep_checks.sh adr-status docs/decisions/0018-... accepted` is not a valid invocation; the script reads check rows from a roadmap's `## Direction` table. Run it as `sitrep_checks.sh --root . --roadmap <scratch file>` with a row `| 18 | adr-status docs/decisions/0018-plugin-based-skill-delivery.md accepted |`. Verified with that form today: ADR-0016's `**Accepted** (2026-11-09).` reads `true`; ADR-0018 reads `false` for accepted and `true` for provisional (the baseline the edit must flip).
2. **[Consequences]** (suggestion) — The Change log Now rule says "a section past about 60 lines says in its row whether its detail should move next to the code". Sessions and roots is well past 60 lines; the row should say so, as the #423 row did ("a status edit, so no detail moves").
3. **[Issue alignment]** (suggestion) — The issue's acceptance says no sentence still "waits on a run", but ADR-0018:341 ("Until then, the opt-in `plugin_acceptance.sh` covers:") stays, rightly, since ADR-0008 permits only the Status edit and the Acceptance subsection sits under Consequences. Say this in the PR description against that acceptance line, and let the Status evidence sentence point at the run named under "Acceptance" below, so the reader sees it resolved there.

### Summary

The plan is complete and correctly targeted: the grep finds no Provisional claim about ADR-0018 outside the four spots it names, the `**Accepted** (2026-11-09).` form reads as accepted, and the plugin route is backed by the GeoZui4D root's records. The three findings are verification and bookkeeping wording the implementer can fold in; none blocks implementation.

### Recommended Actions

- [ ] Run the adr-status check through a scratch roadmap (`--roadmap`), not as a bare subcommand
- [ ] Change-log row says Sessions and roots is past 60 lines and that a status edit moves no detail
- [ ] PR description notes ADR-0018:341 "Until then" stays under ADR-0008; the Status evidence sentence names the run under "Acceptance"

## Checkpoint
**Status**: complete
**When**: 2026-11-09 14:10 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (plan review approved with no must-fix; three suggestions carried to implementation: the adr-status check runs through a scratch roadmap row, the change-log row carries the over-60-lines clause for Sessions and roots, and the PR explains why the Acceptance subsection's "Until then" sentence stays under ADR-0008)
**After**: plan
**Decision**: proceed

Host answer under /orchestrator's checkpoint table.

## Implementation
**Status**: complete
**When**: 2026-11-09 14:21 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-425 at `38098e72`

- `docs/decisions/0018-plugin-based-skill-delivery.md` (8b1c8937): Status only. `**Accepted** (2026-11-09).`, supersession text kept; the "Promote to Accepted when ..." paragraph folded into history: the condition (ADR-0016's own acceptance run, pointing at "Acceptance" below), one evidence sentence (rolker/geozui4d#9 PR 14 and #7 PR 15 from the GeoZui4D root through the merge checkpoint, the GeoZui4D session's own report that every dispatched phase found the prefixed skills, ADR-0016 promoted by #423 PR 424, owner promoted this ADR the same day #425), and the ADR-0008 sentence in past form. The Acceptance subsection, including "Until then, the opt-in `plugin_acceptance.sh` covers:", is unchanged (ADR-0008 permits only the Status edit). PR 14/15 titles and closing issues checked with `gh pr view`.
- `docs/design.md` (572be629): Sessions and roots Now block says ADR-0018 is Accepted too (2026-11-09, #425), its condition was the same run; register row 0018 `in force`; 2026-11-09 Change log row (Sessions and roots, Decision register; #425; 868 lines) with the over-60-lines clause: Sessions and roots is 116 lines, length unchanged, a status edit, so no detail moves.
- `.agent/knowledge/principles_review_guide.md` (38098e72): row 0018 Status **Accepted** (2026-11-09, #425).
- ADR-0016 untouched.

Final pass:
- adr-status through a scratch roadmap Direction table: `adr-status docs/decisions/0018-plugin-based-skill-delivery.md accepted` true; `... provisional` false.
- `check_design_anchors.sh`: exit 0.
- `sitrep_checks.sh --root <worktree>`: exit 0, all rows parse (one pre-existing `unknown` and one `false` row on machine-local user-tier and registry state, unrelated).
- Repo-wide `git grep -niE provisional` outside work-plans: no live claim about ADR-0018 remains. ADR-0018 hits are the Status history sentence (line 11), the dated Change log rows 799 and 813 and the new row 814; the rest are generic (design.md:70 Status key, :701 register key, audit-workspace SKILL.md:65), the digests, ADR-0016's own history, the roadmap's ADR-0016 line, or the unrelated records-default "provisional". No plugin doc says unproven.
- `pre-commit run --files $(git diff --name-only main...HEAD)` (no SKIP): exit 0, script-test suite Passed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-09 14:25 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-425 at `32412211`
**Base**: origin/main
**Depth**: Standard (reason: touches `docs/decisions/*.md` and `principles_review_guide.md`, governance override triggers)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 1 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

### Findings
- [x] (suggestion) "Until then this ADR was Provisional" has no antecedent for "then": the nearest "until" is "until issue #351 moves the hooks" in the paragraph above, so it can be read as Provisional-until-#351; reword to "Before 2026-11-09 this ADR was Provisional." and split the 8-line evidence sentence after "found the prefixed skills" — `docs/decisions/0018-plugin-based-skill-delivery.md:11`

Checked clean: ADR diff confined to Status (lines 5-19; Decision, Consequences, Alternatives and the Acceptance subsection untouched); `adr-status ... accepted` true and `... provisional` false via a scratch roadmap row; `check_design_anchors.sh` exit 0; `wc -l docs/design.md` 868 and Sessions and roots 116 lines, as the change-log row says; repo-wide grep finds no live Provisional/waits-on-a-run claim about ADR-0018 apart from the Acceptance subsection's "Until then" (by design, ADR-0008); geozui4d PRs 14 and 15 merged closing #9 and #7, PR 424 merged closing #423, the GeoZui4D root enables `agent-workspace@agent-workspace`; pre-commit on the three docs files passed. Cross-model: Gemini and Codex both completed, no findings.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 14:25 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (round 1 approved with one suggestion: "Until then this ADR was Provisional" has no clear referent and can read as waiting on #351; a one-line wording fix and a sentence split, cheap on a docs-only branch, so fixed before the push)
**After**: publish
**Decision**: address

Host answer under /orchestrator's checkpoint table. The suggestion of the Local Review (Pre-Push) at accaf169 goes to address-findings.

## Implementation
**Status**: complete
**When**: 2026-11-09 14:25 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-425 at `58e8f94e`
**Addressed**: Local Review (Pre-Push) at `32412211` (2026-11-09 14:25 -05:00)
**Commits**: 58e8f94e

### Actions
- [x] (suggestion) "Until then this ADR was Provisional" had no clear referent; now "Before 2026-11-09 this ADR was Provisional.", and the long evidence sentence is split after "found the prefixed skills" — `docs/decisions/0018-plugin-based-skill-delivery.md:11`

### Checks
- `sitrep_checks.sh --root . --roadmap <scratch>` with a Direction row `adr-status docs/decisions/0018-plugin-based-skill-delivery.md accepted`: true (negative control with `provisional`: false)
- `check_design_anchors.sh`: exit 0
- `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP: exit 0 (script suite Passed)

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-09 14:26 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a550fed372eb066a3, resume 1 of 3)

**Branch**: feature/issue-425 at `511f5caf`
**Base**: origin/main
**Depth**: Standard (reason: round 2 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

### Findings
- [x] No issues found. LGTM. The round 1 suggestion is closed by 58e8f94e: "Before 2026-11-09 this ADR was Provisional." has a dated referent, and the evidence sentence is split after "found the prefixed skills" with no wording change otherwise; the edit stays inside the Status section (lines 11-19, before `## Context`).

Checked: adr-status `accepted` true and `provisional` false via a scratch roadmap row; `check_design_anchors.sh` exit 0. Cross-model: skipped (round-2 convergence check, per handoff).

## Checkpoint
**Status**: complete
**When**: 2026-11-09 14:27 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (round 2 approved, Ship recommended, no findings; Gemini and Codex clean in round 1)
**After**: publish
**Decision**: publish

Host answer under /orchestrator's checkpoint table.

## Integrated Review
**Status**: complete
**When**: 2026-11-09 14:52 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #426 at `f9c8d11a`
**Sources**: 2 (Local Review (Pre-Push) R1 @ `32412211`, Local Review (Pre-Push) R2 @ `511f5caf` (covers f9c8d11a via bookkeeping), CI rollup); no GitHub review source: Copilot posted only a quota notice ("unable to review ... insufficient remaining quota"), no inline or conversation comments
**Cross-source confirmations**: 0
**CI**: all-pass

### Findings
None open. The R1 suggestion (ADR-0018 Status "Until then" had no referent — `docs/decisions/0018-plugin-based-skill-delivery.md`) was fixed at 58e8f94e and confirmed closed by R2. Gemini and Codex clean in R1; cross-model skipped in R2 (convergence check).

### False positives
- (CI) `copilot-pull-request-reviewer` check reports failure — it is the quota notice, not a code check; Lint (pre-commit), Validate Adapter Contract, Validate Documentation and ros-manifest tests all pass at f9c8d11a
