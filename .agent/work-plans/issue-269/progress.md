---
issue: 269
---

# Issue #269 — Port the review loop from ros2_agent_workspace: progress entry vocabulary, convergence verdict, integrated triage, address-findings, merge gate

## Plan
**Status**: complete
**When**: 2026-09-16 00:00
**By**: Claude Code Agent (claude-sonnet-5)

Plan file: `.agent/work-plans/issue-269/plan.md`.

Six independently mergeable PRs (A: ADR + progress_append.sh + progress_read.py;
B: review-code convergence + decision summary; C: triage-reviews →
Integrated Review; D: address-findings; E: plan-task/review-plan headings;
F: merge gate + PR template), per the owner's 2026-09-16 decision comment
adjustments. Merge-gate Layer 2 (CI/branch-protection) is called out as
Ask-First and left as an open question rather than assumed either way.

## Plan Review
**Status**: complete
**When**: 2026-09-16 (offset not captured by this session; UTC-agnostic timestamp)
**By**: independent reviewer (claude-sonnet-5), fresh context
**Verdict**: needs-work
**Plan**: `.agent/work-plans/issue-269/plan.md` at `15173b7`

### Findings

- [x] (must-fix) PR F's design premise ("this check only adds a precondition before that [existing] banner") cites "the human 'type MERGE to confirm' banner this repo's `merge_pr.sh` already has" (plan.md:234-235, repeated at 258-260 with a dangling "see grep evidence in Files to Change" — the Files to Change table has no such evidence). A full grep of `.agent/scripts/merge_pr.sh` (766 lines) for `confirm`/`read -p`/`WARNING`/`type MERGE` finds no interactive confirmation banner; the real human gate is a human choosing to invoke `make merge-pr PR=<N>`. PR F needs to either build the confirmation step as new work or re-describe the actual (weaker) existing gate accurately. — .agent/work-plans/issue-269/plan.md:234
- [x] (must-fix) The "#265 dependency and progress.md path resolution" section (plan.md:274-302) claims "every skill this plan touches resolves progress.md/plan.md the same way today." In this worktree, `plan-task`/`review-plan` call the strict, fail-loud `resolve_work_plans_dir()` helper (`.agent/scripts/_resolve_work_plans_dir.sh`, from #265 PR1), while `review-code`/`triage-reviews` instead duplicate ad hoc prose ("owning repo's worktree, else current worktree, else create") that never calls the shared resolver and fails silently rather than aborting. Both happen to be git-toplevel-based (neither hardcodes `<ws>/worktrees/...`), so the plan's bottom-line conclusion (no hard block on #265 PRs 2-4) likely survives, but the "resolves the same way" claim is false, and the plan doesn't decide whether to unify onto the shared resolver while PR B/C already touch these two skills. — .agent/work-plans/issue-269/plan.md:281-285
- [x] (must-fix) PR F's Layer-1 gate ("Lands", plan.md:222-235) only checks `progress.md` entries (type, correlation SHA, verdict). Issue #269's original item 7 spec described refusing "unless ... no `## Local Review` entry ... **or no decision summary comment**." The plan silently drops the decision-summary-comment half of that OR condition — unlike every other dropped fork behavior in this plan (Ollama, Copilot-CLI, container dispatcher, #492 disambiguation), which gets an explicit "Dropped" note with rationale. Either add the check or document the drop. — .agent/work-plans/issue-269/plan.md:222
- [x] (suggestion) Owner's decision comment instructed "merge adjacent seams where a PR would otherwise be trivial," but the plan's Estimated Scope (plan.md:400-411) restates the reviewer's original A-F split without showing that test applied. PR C (triage-reviews rename, small) and PR D (address-findings, depends on C's output) are the most plausible merge candidates; the plan should show why they stay split, or merge them. — .agent/work-plans/issue-269/plan.md:400
- [x] (suggestion) plan.md:406-408 states PR D depends on PR B for `## Local Review (Pre-Push)` entries, but PR B's own "Lands" section (plan.md:88-90) and Evidence note this workspace's `review-code` **already** writes `## Local Review (Pre-Push)` with conformant headings today, before PR B lands (PR B only swaps the commit mechanism and adds convergence math). D's hard dependency on B may be overstated — re-verify whether D can land after A+C alone. — .agent/work-plans/issue-269/plan.md:406
- [x] (suggestion) `--force-unreviewed` (plan.md:230-231) bypasses with a "loud warning banner" but the plan doesn't specify a durable record of the bypass (e.g., a `progress.md` marker) beyond terminal stdout at merge time — thin for a rule whose own ADR-0004 lineage is "human control and transparency." — .agent/work-plans/issue-269/plan.md:230
- [x] (suggestion) The decision-summary shape (behaviour change / findings / open human calls / what was verified) is repeated as prose in both PR B and PR F but never pinned to a concrete markdown template (exact headings/fields) — add one worked example so every PR produces the literal same shape. — .agent/work-plans/issue-269/plan.md:95-98,243-247

### Verified claims (spot-checked against fork source at /home/roland/project11, read-only)

- (a) Fork `merge_pr.sh` has no review/progress gate — confirmed: grep for "Local Review"/"progress"/"force-unreviewed"/"decision summary" returns nothing.
- (b) `progress_read.py` exists at `~/project11/.agent/scripts/progress_read.py`; parses ADR-0013 entries into JSON with `type`/`base_type`/`recognized`/`predecessor_of`/`status`/`when`/`when_has_offset`/`by`/`correlation`/`findings`, supports `--type` filtering with predecessor recognition — matches the plan's description.
- (c) Confirmed by reading both SKILL.md files in this worktree: `review-code/SKILL.md` already writes `## Local Review` / `## Local Review (Pre-Push)`; `triage-reviews/SKILL.md` still writes `## External Review` (line 216) and its own inline `git add`/`git commit` (line 228, not yet on `progress_append.sh`).
- (d) Fork citation spot-check, 4 of the plan's "evaluate while porting" citations: #537 (convergence assessment) confirmed in `review-code/SKILL.md` (3 hits); #594 (`progress_append.sh` prompt-free appender) confirmed in the script's own header comment; #492 (`run-issue` orchestrator `## Implementation` disambiguation, correctly dropped as inapplicable) confirmed in `address-findings/SKILL.md`; #481 phase C (address-findings origin) confirmed in fork ADR-0013 and ADR-0015. No wrong or fabricated fork citations found among these four; the plan is appropriately calibrated where it labels claims UNVERIFIED (convergence/#537 and progress_append/#594 outcome claims, both correctly flagged as "cited but not independently re-verified").

### Summary

Scope, issue-alignment, consequences coverage, and principle/ADR self-checks are strong — the plan visibly incorporates all six of the owner's binding adjustments, correctly identifies and honestly flags the ADR-0004 two-layer gap, and its fork-citation discipline (UNVERIFIED labeling, explicit Dropped sections) is good practice this review's spot-checks bore out. But PR F rests part of its design on a "type MERGE to confirm" banner in this repo's `merge_pr.sh` that does not exist (verified by full-file grep), silently narrows the merge-gate spec by dropping the decision-summary-comment check without saying so, and the #265 path-resolution section overclaims uniformity where two different mechanisms actually coexist in this codebase today. None of these look fatal to the six-PR structure, but PR F's "Lands" section needs a rewrite before implementation starts on it, and the path-resolution and decision-summary-comment gaps should be resolved (or explicitly deferred with rationale) before PR F specifically proceeds. PRs A-E are not blocked by these findings.

### Recommended Actions

- [x] Rewrite PR F's "Lands" section to either implement an actual pre-merge confirmation step or accurately describe today's real human gate (invoking `make merge-pr` is itself the gate; no in-script banner exists) — plan.md:234, 259-260
- [x] Correct the "#265 dependency and progress.md path resolution" section's uniformity claim and decide (in-scope or explicitly deferred) whether review-code/triage-reviews should be refactored onto the shared `resolve_work_plans_dir()` helper as part of PR B/C — plan.md:274-302
- [x] Add the decision-summary-comment check to PR F's Layer-1 gate, or add an explicit "Dropped" note with rationale matching the plan's own convention elsewhere — plan.md:222-235
- [x] Re-verify PR D's dependency on PR B given `## Local Review (Pre-Push)` already exists pre-port — plan.md:406-408
- [x] Specify a durable record for `--force-unreviewed` bypass events — plan.md:230-231

## Plan Authored
**Status**: complete
**When**: 2026-09-16 (offset not captured by this session; UTC-agnostic timestamp)
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-269/plan.md` at `2f4e4728ac8ce01fdf982fac9c5b0f031a186560`

Revision 2 — plan-review findings applied. One line per finding →
resolution:

1. **Must-fix 1** (false "type MERGE to confirm" banner claim) →
   removed; full-file grep of `merge_pr.sh` confirms no interactive
   confirmation exists; PR F's Layer 1 check now cited as new work
   inserted between the existing CI-wait step and the existing merge
   call, not a precondition on a pre-existing banner.
2. **Must-fix 2** ("every skill resolves progress.md the same way") →
   replaced with verified reality: only `plan-task` calls the shared
   fail-loud `resolve_work_plans_dir()`; `review-code`/`triage-reviews`
   duplicate ad hoc, silently-falling-back prose; `review-plan` has no
   documented append step at all today. PR B/C now unify `review-code`/
   `triage-reviews` onto the shared resolver with a silent-fallback-gone
   test; PR E is corrected to give `review-plan` its first automated
   append step rather than claiming a rename of one that doesn't exist.
   The #265-PRs-2-4 no-hard-block conclusion still holds and is
   re-verified against the unification decision.
3. **Must-fix 3** (dropped decision-summary-comment check) → restored;
   PR F's Layer 1 now checks both the review-entry condition and a PR
   comment containing the `## Decision summary` marker (via `gh pr view
   --json comments`), refusing if either is absent.
4. **Suggestions** → PR C/D merge evaluated and declined (each carries
   its own non-trivial mechanical scope); PR D's dependency on PR B
   downgraded from hard to soft (`## Local Review (Pre-Push)` already
   exists pre-PR-B) with a defensive-read note; `--force-unreviewed` now
   appends a `## Merge (unreviewed)` progress.md entry (new vocabulary
   type, not in the fork) as its durable audit record; the
   decision-summary shape is pinned to one concrete template in PR B,
   referenced (not re-described) by PR F.

PR sequence unchanged in count and ordering, adjusted in dependency/scope
detail: A (ADR + `progress_append.sh` + `progress_read.py`, foundation) →
B (`review-code`: `progress_append.sh` swap + resolver unification +
convergence + decision-summary template) → C (`triage-reviews`:
`## Integrated Review` + resolver unification) → D (`address-findings`
new skill; depends on A + C, soft-depends on B) → E (`plan-task` heading
rename + `review-plan` heading rename and new automated append step) → F
(merge gate: two-condition Layer 1 gate + unreviewed-bypass audit record
+ Layer 2 left Ask-First + PR template decision-summary section).

## Plan Authored
**Status**: complete
**When**: 2026-09-16 (offset not captured by this session; UTC-agnostic timestamp)
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-269/plan.md` at `ac4aa23`

Revision 3 — blast-radius containment. The owner (2026-09-16) accepted
four containment measures after reviewing revision 2; one line per
measure → where it landed:

1. **Merge gate ships report-only first, `--enforce` flips it on** →
   PR F's Layer 1 "Lands" section rewritten: default mode prints what it
   would have refused and why, never blocks; `--enforce` turns on the
   same two-condition refusal. Cites the fork's `janitor-sweep`
   precedent (verified: `~/project11/.claude/skills/janitor-sweep/SKILL.md`
   describes itself as "Report-only — opens no PRs, files no issues, and
   publishes nothing"). A CLI flag was chosen over a
   `.agent/project_config.sh` switch or a `make` variable, with the
   choice justified inline (consistency with `merge_pr.sh`'s existing
   flag interface; `project_config.sh` is gitignored/per-developer, not
   a shared point of truth; the later flip is then a reviewable one-line
   diff). The flip to enforce-by-default is named as a separate, later
   PR, not part of this sequence. PR F's Tests subsection now covers
   both modes explicitly.
2. **Gate scoped to workspace PRs at first** → PR F's Layer 1 now reads
   `$WORKTREE_TYPE` (the exact detection `merge_pr.sh` already computes
   at `merge_pr.sh:296-297,313-355` — `"workspace"`, `"project"`, or
   `""` for package-repo/qualified-`--repo` PRs) and only refuses when it
   is `"workspace"`; `"project"` and `""` stay report-only regardless of
   `--enforce`, until #265 PRs 2–4 settle project `progress.md` location.
   PR F's Tests subsection adds a case asserting `--enforce` has no
   refusal effect outside workspace scope.
3. **Checkpoint after PRs A and B** → added to the PR sequence intro and
   as its own subsection at the top of Estimated Scope, with "exercised"
   defined concretely as three observed facts on #265 PR 2: (a)
   `review-code` writes its entry via `progress_append.sh` with the
   `**Round**`/`**Ship**` convergence fields present; (b) the fail-loud
   `resolve_work_plans_dir()` call is hit from #265 PR 2's own (project)
   worktree, not just PR B's hermetic fixtures; (c) the decision summary
   on that PR's report uses the exact template pinned in PR B. The
   Estimated Scope dependency-ordering paragraph is corrected to note the
   checkpoint holds PR E back too, despite E's structural dependency
   being on PR A alone.
4. **Degradation test for no-issue / skill-worktree cases** → PR B and PR
   C's Tests subsections each add a hermetic degradation test: a
   skill-worktree branch and a branch with no linked issue both skip the
   `resolve_work_plans_dir()` call (no issue number is derivable) and
   print "Progress persistence skipped (<reason>)," completing the
   review with no `progress.md` write, distinct from the existing
   mismatched-worktree case (which still aborts per issue #147, since an
   issue number *is* resolvable there).

Also added a "Blast radius" section (before Files to Change): the 16
skills outside the lifecycle chain this port never edits (verified by
listing `.claude/skills/`, 20 entries total), plus adapters, worktree
scripts, the registry, and hosting, each stated as untouched with why;
and the three risk points the owner discussed with how each is
contained (gate scoped off project PRs until #265 settles; fail-loud
`resolve_work_plans_dir()` change degrades gracefully rather than
aborting for skill worktrees/issue-less branches; the vocabulary rename
verified to have exactly the three SKILL.md files this port already
edits as writers plus `progress_read.py` and human eyes as readers — two
other grep hits, an issue-template checklist section and a pre-ADR-0013
illustrative doc example, are named as out-of-namespace/pre-existing,
not silently waved off as clean).

## Plan Review
**Status**: complete
**When**: 2026-09-16 18:06 UTC
**By**: independent reviewer (claude-sonnet-5), fresh context, revision 3
**Verdict**: needs-work
**Plan**: `.agent/work-plans/issue-269/plan.md` at `ac4aa23`

### Findings

- [ ] (must-fix) Containment measure 3 (checkpoint after PR B) does not actually gate PR B's blast radius, only PR C's start. Once PR B merges, its fail-loud `resolve_work_plans_dir()` call and `progress_append.sh` refactor go live for every `review-code` invocation on every other in-flight PR immediately — the "exercise on #265 PR 2" observation happens after the risk is already live workspace-wide. PR B (`review-code`, a daily-use skill) is the one PR in this sequence whose worst case is genuinely "breaks a daily-use skill," and the checkpoint does not contain that; only the hermetic degradation tests do. Either correct the "Blast radius" section (risk point 2) to stop crediting the checkpoint for containing this, relying explicitly on the degradation tests alone, or ship PR B's fail-loud resolver call behind its own opt-in switch until the #265 PR 2 exercise passes, so the checkpoint is a real gate rather than a paperwork step. — plan.md:640,649-658 (Blast radius risk point 2), plan.md:768-796 (Estimated Scope checkpoint)
- [ ] (must-fix) The checkpoint itself (measure 3) is unenforced: nothing in the plan mechanically prevents a session from starting PR C/D/E/F before the three observations on #265 PR 2 are recorded. The stated gate is "a note in this progress.md, not just verbal confirmation" (plan.md:792-793), but no script or worktree-creation check verifies that note exists before work on C–F begins — it is the one containment measure of the four not backed by a test or code path (1, 2, and 4 all are). Given this workspace's own "enforcement over documentation" standard (cited by PR F's own report-only design), either add a mechanical check (e.g., a precondition on creating the PR C/D/E/F worktree/branch that greps issue-269's progress.md for the checkpoint record) or explicitly name this measure as discipline-only, not parity with the other three. — plan.md:768-796
- [ ] (must-fix) Report-only mode's default (non-bypass) path — the common case during the entire observation window this containment measure exists for — produces no durable record, only a stdout "would have refused because..." line (plan.md:374-377). `--force-unreviewed` gets a `## Merge (unreviewed)` progress.md entry (plan.md:432-435), but a report-only merge that fails both gate conditions and is *not* bypassed gets nothing durable. The plan's stated purpose for report-only mode is to "let the owner watch its output on real merges" before flipping to `--enforce` (plan.md:401-402) — but a stdout line captured nowhere can only be seen synchronously by whoever ran `make merge-pr`, not reviewed retrospectively by the owner across "several merges," which undercuts the stated purpose of the observation period. Add a durable record for every report-only refusal-line case, not just the `--force-unreviewed` bypass case. — plan.md:374-377, 423-435, Tests subsection plan.md:477-506
- [ ] (suggestion) The plan doesn't note that `--enforce`/`--force-unreviewed` reach `merge_pr.sh` via `make merge-pr PR=<N> MERGE_PR_ARGS=--enforce` — verified: `Makefile:132-134` passes `$(MERGE_PR_ARGS)` through to `merge_pr.sh`, and AGENTS.md names `make merge-pr` as the preferred invocation path. Worth a one-line addition to PR F's "Lands" section and a Makefile help-text update (Makefile:70) so this isn't rediscovered at implementation time.
- [ ] (suggestion) The "Blast radius" section's claim that the 16 untouched skills "None of these read or write progress.md" (plan.md:614-621) is slightly overstated: `start-task/SKILL.md:156` documents that `--workflow` initializes `progress.md`'s front-matter/title, delegated to `worktree_create.sh:797-816` (confirmed unmodified by this port, and confirmed it writes only front-matter + an H1, no ADR-0013 `##` entry heading — so the vocabulary-collision risk claim still holds). Scope the sentence to "no ADR-0013 entry types," not a flat "none... read or write progress.md."
- [ ] (suggestion) The call-site "is an issue number derivable" pre-check in PR B/C (containment measure 4) re-implements `resolve_work_plans_dir()`'s own rule-2/2b branch/worktree-basename pattern matching rather than reusing it — two independent copies of the same detection logic risk drifting apart later (e.g. if issue #147-style branch-naming conventions change). Consider a shared detection entry point (e.g. a `--detect-only` mode on the resolver) instead of re-deriving the pattern at each call site.

### Verified claims (spot-checked against the tree in this worktree)

- `merge_pr.sh:296-297,313-355` confirmed: `$WORKTREE_TYPE` is computed exactly where and how PR F's Layer 1 design claims, taking values `"workspace"`, `"project"`, or `""` (package/qualified-repo PRs).
- Step 2 (CI wait) ends at `merge_pr.sh:538`, Step 3 (`gh pr merge`) begins at `merge_pr.sh:540` with the merge call at `merge_pr.sh:544` — the claimed Step 2.5 insertion point exists exactly as described.
- `.claude/skills/` listing (20 entries) confirmed against the plan's 16-skill "untouched" list: removing the 4 touched skills (`plan-task`, `review-code`, `review-plan`, `triage-reviews`) from the actual directory listing yields exactly the 16 names the plan names, in the same set. `grep -rl "progress.md\|progress_append.sh\|progress_read.py\|resolve_work_plans_dir" .claude/skills/` returns only `plan-task`, `review-code`, `start-task`, `triage-reviews` — `start-task`'s one hit is the front-matter-only case noted in the suggestion above; no other of the 16 references this vocabulary or mechanism.
- `~/project11/.claude/skills/janitor-sweep/SKILL.md:3` confirmed verbatim: "Report-only — opens no PRs, files no issues, and publishes nothing." PR F's citation of this precedent is accurate.
- `grep -rn "## External Review\|## Plan Review:\|^## Plan$" .agent/ .claude/ .github/` (excluding historical `progress.md` data files) returns exactly the three SKILL.md writers the plan names (`triage-reviews/SKILL.md:216`, `review-plan/SKILL.md:181,217,227`, `plan-task/SKILL.md:211`) plus the two "unrelated" hits the plan names (`.github/ISSUE_TEMPLATE/feature_track.md:22`, `.agent/workflows/README.md:65`) — no additional writers found.
- `.agent/scripts/_resolve_work_plans_dir.sh` read in full: Rule 3's abort fires only when an issue number is resolvable (set-but-mismatched `$WORKTREE_ISSUE`, or unset with a pattern-matching branch/worktree basename) but doesn't match the current tree — consistent with the plan's claim that the existing fail-loud abort (issue #147) is preserved unweakened, distinct from the new "no issue number derivable at all" skip path (measure 4).
- Revision 2's five "Recommended Actions" (all checked `[x]` above) remain applied in revision 3's plan text: the false confirmation-banner claim stays removed, the two-condition Layer 1 gate (review entry + decision-summary comment) is still both present, the `#265` path-resolution section still states verified reality (not the prior "resolves the same way" overclaim), PR D's dependency on B is still downgraded to soft, and `--force-unreviewed` still specifies its durable record. No re-opened must-fixes found.
- Issue #269's two GitHub comments (both from `rolker`, 2026-09-16T17:35/17:36) contain the `review-issue` evaluation and the owner's six-adjustment decision comment only — they do not contain the "four blast-radius containment measures" revision 3 attributes to a same-day owner decision. That decision is not contradicted by anything in the issue thread, but it is not corroborated there either; it appears to rest on an out-of-band conversation with the planning session, consistent with how revision 2's own `## Plan Review` was never posted to the issue either (this skill does not post to GitHub). Not flagged as a finding — noted for the record.

### Summary

Revision 3's four containment measures are largely real decisions, not options, and three of the four (report-only default, workspace-only scope, no-issue degradation) are backed by concrete code changes and hermetic tests that were verified to align with the actual `merge_pr.sh` and `_resolve_work_plans_dir.sh` source. The fourth — the checkpoint after PR B — is the weakest of the four as designed: it is unenforced, and even if recorded faithfully, it does not actually delay PR B's exposure to the rest of the workspace (only PR C's start), which means the one PR in this sequence with a "breaks a daily-use skill" worst case is not contained by the measure the plan credits for containing it. Combined with the report-only mode's default path leaving no durable record — undercutting the explicit purpose of the observation window the whole report-only design exists to serve — these are structural, not cosmetic, gaps in a plan whose central selling point this revision is blast-radius containment. Revision 2's findings remain correctly applied; no regressions found there. Not ready for implementation until the three must-fixes above are resolved.

### Recommended Actions

- [ ] Correct or strengthen containment measure 3 so it actually gates PR B's live exposure, not just PR C's start (add an opt-in switch for PR B's fail-loud resolver call, or explicitly stop crediting the checkpoint for risk point 2's containment) — plan.md:640,649-658, 768-796
- [ ] Add a mechanical check for the checkpoint itself, or explicitly name it as discipline-only — plan.md:768-796
- [ ] Give report-only mode's default (non-bypass) refusal case a durable record, not just stdout — plan.md:374-377, 423-435, 477-506
- [ ] Note the `make merge-pr PR=<N> MERGE_PR_ARGS=--enforce` invocation path in PR F's Lands section and Makefile help text — Makefile:70,132-134
- [ ] Scope the "16 untouched skills" claim to "no ADR-0013 entry types" given `start-task`'s front-matter-only `progress.md` reference — plan.md:614-621
