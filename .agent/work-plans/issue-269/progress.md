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

- [x] (must-fix) Containment measure 3 (checkpoint after PR B) does not actually gate PR B's blast radius, only PR C's start. Once PR B merges, its fail-loud `resolve_work_plans_dir()` call and `progress_append.sh` refactor go live for every `review-code` invocation on every other in-flight PR immediately — the "exercise on #265 PR 2" observation happens after the risk is already live workspace-wide. PR B (`review-code`, a daily-use skill) is the one PR in this sequence whose worst case is genuinely "breaks a daily-use skill," and the checkpoint does not contain that; only the hermetic degradation tests do. Either correct the "Blast radius" section (risk point 2) to stop crediting the checkpoint for containing this, relying explicitly on the degradation tests alone, or ship PR B's fail-loud resolver call behind its own opt-in switch until the #265 PR 2 exercise passes, so the checkpoint is a real gate rather than a paperwork step. — plan.md:640,649-658 (Blast radius risk point 2), plan.md:768-796 (Estimated Scope checkpoint)
- [x] (must-fix) The checkpoint itself (measure 3) is unenforced: nothing in the plan mechanically prevents a session from starting PR C/D/E/F before the three observations on #265 PR 2 are recorded. The stated gate is "a note in this progress.md, not just verbal confirmation" (plan.md:792-793), but no script or worktree-creation check verifies that note exists before work on C–F begins — it is the one containment measure of the four not backed by a test or code path (1, 2, and 4 all are). Given this workspace's own "enforcement over documentation" standard (cited by PR F's own report-only design), either add a mechanical check (e.g., a precondition on creating the PR C/D/E/F worktree/branch that greps issue-269's progress.md for the checkpoint record) or explicitly name this measure as discipline-only, not parity with the other three. — plan.md:768-796
- [x] (must-fix) Report-only mode's default (non-bypass) path — the common case during the entire observation window this containment measure exists for — produces no durable record, only a stdout "would have refused because..." line (plan.md:374-377). `--force-unreviewed` gets a `## Merge (unreviewed)` progress.md entry (plan.md:432-435), but a report-only merge that fails both gate conditions and is *not* bypassed gets nothing durable. The plan's stated purpose for report-only mode is to "let the owner watch its output on real merges" before flipping to `--enforce` (plan.md:401-402) — but a stdout line captured nowhere can only be seen synchronously by whoever ran `make merge-pr`, not reviewed retrospectively by the owner across "several merges," which undercuts the stated purpose of the observation period. Add a durable record for every report-only refusal-line case, not just the `--force-unreviewed` bypass case. — plan.md:374-377, 423-435, Tests subsection plan.md:477-506
- [x] (suggestion) The plan doesn't note that `--enforce`/`--force-unreviewed` reach `merge_pr.sh` via `make merge-pr PR=<N> MERGE_PR_ARGS=--enforce` — verified: `Makefile:132-134` passes `$(MERGE_PR_ARGS)` through to `merge_pr.sh`, and AGENTS.md names `make merge-pr` as the preferred invocation path. Worth a one-line addition to PR F's "Lands" section and a Makefile help-text update (Makefile:70) so this isn't rediscovered at implementation time.
- [x] (suggestion) The "Blast radius" section's claim that the 16 untouched skills "None of these read or write progress.md" (plan.md:614-621) is slightly overstated: `start-task/SKILL.md:156` documents that `--workflow` initializes `progress.md`'s front-matter/title, delegated to `worktree_create.sh:797-816` (confirmed unmodified by this port, and confirmed it writes only front-matter + an H1, no ADR-0013 `##` entry heading — so the vocabulary-collision risk claim still holds). Scope the sentence to "no ADR-0013 entry types," not a flat "none... read or write progress.md."
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

- [x] Correct or strengthen containment measure 3 so it actually gates PR B's live exposure, not just PR C's start (add an opt-in switch for PR B's fail-loud resolver call, or explicitly stop crediting the checkpoint for risk point 2's containment) — plan.md:640,649-658, 768-796
- [x] Add a mechanical check for the checkpoint itself, or explicitly name it as discipline-only — plan.md:768-796
- [x] Give report-only mode's default (non-bypass) refusal case a durable record, not just stdout — plan.md:374-377, 423-435, 477-506
- [x] Note the `make merge-pr PR=<N> MERGE_PR_ARGS=--enforce` invocation path in PR F's Lands section and Makefile help text — Makefile:70,132-134
- [x] Scope the "16 untouched skills" claim to "no ADR-0013 entry types" given `start-task`'s front-matter-only `progress.md` reference — plan.md:614-621

## Plan Authored
**Status**: complete
**When**: 2026-09-16 (offset not captured by this session; UTC-agnostic timestamp)
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-269/plan.md` at `4f9e934`

Revision 4 — containment enforced in code, PR B behind a switch. One
line per revision-3 plan-review finding → resolution:

1. **Must-fix 1** (checkpoint didn't gate PR B's own exposure) → PR B,
   PR C, and PR E's `plan-task` swap now ship their fail-loud
   `resolve_work_plans_dir()` call and `progress_append.sh` swap behind
   a `PROGRESS_PERSISTENCE_STRICT` env var, default `0` (today's
   resolution/commit mechanism, plus a one-line "would have aborted"
   notice when the strict path would have refused); default `1` is what
   PR B2 flips to, after the checkpoint. `review-plan`'s brand-new
   append step (no existing mechanism to preserve compatibility with)
   is made non-fatal instead. Blast radius's risk point 2 no longer
   credits the checkpoint for containing PR B — the switch does that;
   the checkpoint's role is corrected to gating B2's flip and C's start.
2. **Must-fix 2** (checkpoint unenforced) → new `## Checkpoint` entry
   type (ADR, PR A), written by the owner after the #265 PR 2 exercise
   with four required evidence fields (`**PR**`, `**Review entry
   SHA**`, `**Resolver-hit**`, `**Decision summary URL**`); new
   hermetic CI check `.agent/scripts/tests/test_checkpoint_269.sh` (PR
   A) refuses any PR touching a C–F file (named: triage-reviews/
   SKILL.md, address-findings/, plan-task/review-plan heading changes,
   merge_pr.sh gate step, PR template) — or B2, which touches two of
   those files — without that entry present on `main`. Picked a test
   script over a validate.yml step specifically to avoid AGENTS.md's
   Ask-First gate on CI-config changes.
3. **Must-fix 3** (report-only mode's default path had no durable
   record) → new `## Merge (report-only)` entry type (ADR, PR A),
   appended via `progress_append.sh` (same helper as the
   `## Merge (unreviewed)` bypass entry) every time a report-only
   `merge_pr.sh` run fails a gate condition, naming which condition(s)
   failed and the PR head SHA. PR F's Tests subsection now asserts both
   entry types, not just stdout lines.
4. **Suggestion 1** (make merge-pr MERGE_PR_ARGS invocation path) →
   re-verified against this worktree: `Makefile:132-134` confirmed
   (the `merge-pr:` target passes `$(MERGE_PR_ARGS)` through verbatim;
   its usage line already documents the flag). PR F's Lands section now
   cites this, and PR F adds `Makefile:70`'s help text (currently
   missing `MERGE_PR_ARGS`) to the Files to Change table.
5. **Suggestion 2** (16-untouched-skills claim overstated) → scoped to
   "writes no ADR-0013 entry type, calls no progress_append.sh/
   progress_read.py, and is edited by no PR in this sequence," with
   `start-task/SKILL.md:156`'s front-matter-only `--workflow`
   initialization of `progress.md` named as the exception that doesn't
   collide with the vocabulary rename but does touch the file.

New "Blast radius" per-PR worst-case table (A–F, B2) added per the
review's own request: every row reads "notice printed" or "test fails
in CI" except B2, which is named plainly as the one PR that actually
flips the fail-loud paths live — contained by the same
`test_checkpoint_269.sh` mechanical gate (B2 touches two of the gated
files), not forced into the clean bucket.

PR sequence: A (ADR + scripts + `test_checkpoint_269.sh`) → B
(`review-code`, `PROGRESS_PERSISTENCE_STRICT=0` default) → **checkpoint**
(A+B exercised on #265 PR 2, `## Checkpoint` entry recorded, mechanically
required from here on) → **B2** (flips the switch's default to `1` for
review-code/triage-reviews/plan-task; gated by the same mechanical check;
opened after the checkpoint plus the owner's own judgment on the notice
track record) → C (`triage-reviews`, same switch) → D (`address-findings`,
new skill) → E (`plan-task`/`review-plan` headings, same switch on
`plan-task`, non-fatal new step on `review-plan`) → F (merge gate,
report-only default + `## Merge (report-only)` durable record + PR
template). B2's ordering relative to C–F is flexible (any time after the
checkpoint), not fixed at this position — see "Estimated Scope" for the
dependency detail.

## Plan Review
**Status**: complete
**When**: 2026-09-16 (offset not captured by this session; UTC-agnostic timestamp)
**By**: independent reviewer (claude-sonnet-5), fresh context, revision 4
**Verdict**: needs-work
**Plan**: `.agent/work-plans/issue-269/plan.md` at `4f9e934`

### Findings

- [ ] (must-fix) `test_checkpoint_269.sh`'s enforcement claim does not hold against this tree. PR A's own text (plan.md:154-179) says the script is "picked up by the existing test harness the same way every other PR's new `test_*.sh` file is." Verified false: `.github/workflows/validate.yml` calls out exactly three of this repo's ten existing `.agent/scripts/tests/test_*.sh` files by explicit, individually-named `run:` steps (`test_adapter.sh`, `test_project_registry.sh`, `test_ros2_colcon.sh`); the other seven (`test_merge_pr.sh`, `test_merge_pr_root_resolution.sh`, `test_resolve_work_plans_dir.sh`, `test_gh_create_pr.sh`, `test_block_bash_tool_mapping.sh`, `test_cross_model_review.sh`, `test_sync_gitbug.sh`) are not referenced anywhere in `validate.yml`, `.pre-commit-config.yaml`, or the Makefile. There is no auto-discovery loop anywhere in `.agent/scripts/` that globs `test_*.sh` and runs it. `make test` dispatches to `.agent/scripts/test.sh` → the project adapter's `TEST_CMD`, not this workspace's own test scripts. So dropping `test_checkpoint_269.sh` into `.agent/scripts/tests/` gets it exactly nothing running it in CI — the "mechanically enforced" checkpoint (revision 4's answer to revision 3's must-fix 2) does not actually gate any merge as designed; it is a script that exists and is never invoked. Wiring it in requires either an explicit new step in `validate.yml` (which is squarely the AGENTS.md Ask-First "changing CI... configuration" item the plan is trying to avoid by this design) or a new `repo: local` hook entry in `.pre-commit-config.yaml` (this repo already has local hooks there, e.g. `validate-adapter-contract`, that run inside the existing "Lint (pre-commit)" `validate.yml` job via `make lint` without any `validate.yml` edit — a real alternative the plan didn't consider and that may not need Ask-First treatment the way a workflow-file edit does, but that's a judgment call for the owner, not something this plan should silently assume). As written, PR A ships a checkpoint gate that is inert; this repeats the exact pattern revision 3 found in revision 2 ("real in name, not in effect") one layer down. — plan.md:154-179, 990-995, 1083-1093, Blast radius per-PR table row A
- [ ] (must-fix) Nothing stops a PR from editing or deleting `test_checkpoint_269.sh` (or narrowing its gated-file list) to route around the checkpoint, and the plan doesn't say what does. Given the CI-wiring gap above, this is currently moot (the check doesn't run either way), but even after wiring it correctly, the check is an ordinary repo file subject to the same review loop this issue is building, not yet gated by anything itself — a PR could remove its own gate in the same diff that touches a C–F file. The plan should state the actual answer (human review is the only backstop pre-Layer-2, same as everything else in this sequence) rather than leaving the question unaddressed, since PR F's own Layer 1 explicitly reasons through exactly this kind of self-defeat risk for the merge gate but PR A doesn't for the checkpoint gate.
- [ ] (must-fix) `## Merge (report-only)` / `## Merge (unreviewed)` durable-record writes (PR F, plan.md:567-580, 632-649, 1145-1158) never say which `progress.md` they target when the PR's issue lives in another repo — the exact case PR F's own refusal-scoping (containment measure 2) says is unresolved ("project-repo `progress.md` location is not yet stable," plan.md:627). Layer 1 stays report-only (never refuses) for `$WORKTREE_TYPE == "project"` and `""` (package PRs), but the "every report-only run... also appends a `## Merge (report-only)` entry" language (plan.md:572-580) is not scoped by `$WORKTREE_TYPE` the way the refusal path is, and `--force-unreviewed`'s `## Merge (unreviewed)` append (plan.md:641-644, 1145-1158) has no scope qualifier either. Since `merge_pr.sh` runs from the workspace worktree and the plan has already flagged that it doesn't know where a project or package repo's `progress.md` lives pre-#265-PR-4, the plan needs to say explicitly whether the durable-record append is skipped for project/package-scope PRs (mirroring the refusal-scoping reasoning it already applied one section earlier) or how it locates that other repo's file. As written this is a silent gap in the one place revision 4 added specifically to close a durability gap. — plan.md:567-580, 613-630, 632-649
- [ ] (must-fix) The `PROGRESS_PERSISTENCE_STRICT` env-var carrier (plan.md:258-270) is justified by "`review-code` is invoked as a skill..., not a CLI command with a stable flag surface..., so a flag can't be threaded through invocation the way PR F's `--enforce` can" — but `review-code/SKILL.md` already has exactly such a flag today: `--no-progress` (`review-code/SKILL.md:15,20,108,110,117,392,498`), documented in the same invocation line (`/review-code --branch [<base-ref>] [--issue <N>] [--no-progress] ...`) the plan says can't carry a flag. This is a factual contradiction with the plan's own cited evidence, not just a design preference: a `--strict-progress`-style invocation flag (mirroring the existing `--no-progress` pattern already proven to thread through this exact skill) would also be more discoverable for the one-off checkpoint-exercise run (plan.md:139, 1070-1071) than an ambient env var nothing in the invocation line surfaces — an agent running `/review-code` on #265 PR 2 has to be separately told out-of-band to export `PROGRESS_PERSISTENCE_STRICT=1` first, with no mechanism in the skill's own argument-hint reminding it to. Revise the carrier or correct the stated justification. — plan.md:258-270, PR C/E's identical env-var choice inherits the same issue
- [ ] (suggestion) PR B2 (plan.md:728-764) calls itself "a one-line default-value change" in its Lands section, but the same section and the Blast radius B2 row (plan.md:972) also say B2 "delete[s]" the compatibility-mode notice path, the old ad hoc resolution/inline-commit code it guards, and the switch-mode tests that exercised it. Those are two different claims: a one-line default flip is trivially revertible ("revertible back to 0 in a single follow-up commit," per line 972); deleting the dead code it guarded is not — a regression found after B2 would need the deleted code restored, not just the default flipped back. Either keep the old-path code in place after B2 (truly one-line, truly one-commit-revertible, cleanup deferred to its own later PR) or drop the "one-line"/"single follow-up commit" framing for B2 and state the real revert cost.
- [ ] (suggestion) Given the checkpoint's enforcement is currently inert (must-fix 1) and B2 is explicitly named as the one unbounded-worst-case PR in the sequence, consider splitting B2 into three single-skill PRs (review-code, triage-reviews, plan-task default flips), each gated by the same `test_checkpoint_269.sh`-if-wired mechanism, so a regression in one skill's strict path doesn't have to be diagnosed against three simultaneous flips. Not raised in the plan's own "merge-adjacent-seams" pass, which only considered C/D.

### Prior findings status (revisions 1–3)

All must-fixes and recommended actions from the two prior `## Plan Review` entries in this file remain applied in revision 4's text and are not contradicted — re-checked against plan.md: the false "type MERGE to confirm" banner claim stays removed (plan.md:520-530); the `#265` path-resolution section still states verified per-skill reality, not the earlier "resolves the same way" overclaim (plan.md:774-819); PR F's Layer 1 still checks both the review-entry and decision-summary-comment conditions (plan.md:540-554); PR D's dependency on PR B is still downgraded to soft (plan.md:1109-1121); `--force-unreviewed` still specifies a durable record (plan.md:632-649, though see the new cross-repo-target finding above); the report-only-default no-durable-record gap (revision 3's must-fix 3) is addressed in text via `## Merge (report-only)` (though the same finding shows its scope is underspecified); the checkpoint-doesn't-gate-PR-B gap (revision 3's must-fix 1) is addressed via the `PROGRESS_PERSISTENCE_STRICT` switch (though its carrier choice is now itself flagged above); and the checkpoint-is-unenforced gap (revision 3's must-fix 2) is the one prior finding whose revision-4 fix, on inspection against the actual tree, does not achieve what it claims — the mechanism it adds (`test_checkpoint_269.sh`) is not wired into anything that runs it. This is not a reopened finding in the sense of reverted text; it is the same underlying problem (checkpoint enforcement is prose dressed as mechanism) resurfacing one layer down, in the CI-wiring gap rather than the entry-schema gap revision 3 caught.

### Verified claims (spot-checked against the tree in this worktree)

- `Makefile:132-134` confirmed verbatim: the `merge-pr:` target passes `$(MERGE_PR_ARGS)` through to `.agent/scripts/merge_pr.sh`. `Makefile:70` confirmed to omit `MERGE_PR_ARGS` from the help-text line, consistent with the plan's stated gap and fix.
- `start-task/SKILL.md:156` confirmed verbatim: `` - `--workflow` progress.md scaffolding under `.agent/work-plans/issue-N/` ``.
- `merge_pr.sh:296-297` (`WORKTREE_TYPE=""` for `REPO_KIND == package`) and the surrounding `WORKTREE_TYPE` derivation block (`merge_pr.sh:281-357`) confirmed to match the plan's description. Step 2 (CI wait) and Step 3 (merge) markers at `merge_pr.sh:512` and `merge_pr.sh:540`, with the `gh pr merge` call at `merge_pr.sh:544`, confirmed — the claimed Step 2.5 insertion point is real and exactly where described.
- Full-file grep of `merge_pr.sh` (766 lines) for `confirm|read -p|type MERGE|WARNING` returns no interactive confirmation banner — the plan's "no pre-existing gate" premise for PR F holds.
- None of PR C–F's named target files (`.claude/skills/address-findings/`, `.claude/skills/triage-reviews/SKILL.md`, `.claude/skills/plan-task/SKILL.md`, `.claude/skills/review-plan/SKILL.md`) are missing or misnamed; `address-findings` correctly does not yet exist (PR D creates it). `.agent/scripts/tests/` currently holds 10 test scripts; the plan's claim about how a new one there gets executed does not match what any of them actually do (see must-fix 1).
- `.agent/scripts/_resolve_work_plans_dir.sh` read in full: its three-rule fail-loud/fallback structure matches the plan's description of what the `PROGRESS_PERSISTENCE_STRICT=1` path would invoke and what the degradation-test call sites need to pre-check.

### Summary

Revision 4's three targeted fixes (switch for PR B/C/E, `## Checkpoint` entry + test, `## Merge (report-only)` entry) are the right shape for what revision 3 asked for, and the plan's per-file verification discipline (Makefile line numbers, `start-task` line number, `merge_pr.sh` structure) checks out against this tree in every case tested. But the central new mechanism — `test_checkpoint_269.sh` as a "mechanically enforced" gate — does not actually run anywhere in this repo's CI as designed; that is a factual, verifiable gap, not a judgment call, and it undermines revision 4's own framing that this closes must-fix 2 "in code, not prose." The env-var carrier for `PROGRESS_PERSISTENCE_STRICT` is justified by a claim (`review-code` "not a CLI command with a stable flag surface") that `review-code`'s own existing `--no-progress` flag contradicts. The cross-repo target for the two new durable-record entry types is unaddressed even though the plan explicitly reasoned through the identical instability one section earlier for refusal-scoping. None of these look fatal to the six-PR structure or to starting PR A's ADR/scripts/tests work, but the checkpoint-enforcement gap specifically means PR A should not be considered to deliver a working mechanical gate until the CI-wiring question is resolved and stated in the plan (Ask-First `validate.yml` edit, or a `.pre-commit-config.yaml` local hook, named explicitly either way) — and that gate is what the rest of the sequence (B2 particularly) is relying on for containment.

### Recommended Actions

- [ ] State and implement how `test_checkpoint_269.sh` actually gets executed in CI — either an explicit (Ask-First) `validate.yml` step or a `.pre-commit-config.yaml` local hook — and correct the "picked up by the existing test harness... the same way every other PR's new `test_*.sh` file is" claim, which is false for 7 of this repo's 10 existing test scripts — plan.md:154-179
- [ ] State what stops a PR from editing/deleting `test_checkpoint_269.sh` itself, or name human review as the explicit (pre-Layer-2) backstop — plan.md:154-179
- [ ] Specify the `## Merge (report-only)` / `## Merge (unreviewed)` target `progress.md` location for project- and package-scope PRs, or explicitly scope the durable-record append to `$WORKTREE_TYPE == "workspace"` the same way refusal already is — plan.md:567-580, 613-649, 1145-1158
- [ ] Reconcile the `PROGRESS_PERSISTENCE_STRICT` env-var justification with `review-code`'s own existing `--no-progress` invocation flag, and consider an invocation-flag carrier instead — plan.md:258-270
- [ ] Either keep B2's old code path in place (true one-line, one-commit-revertible flip) or drop the "one-line"/"single follow-up commit" revert framing for B2 — plan.md:728-764, 972

## Plan Authored
**Status**: complete
**When**: 2026-09-16 (offset not captured by this session; UTC-agnostic timestamp)
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-269/plan.md` at `4a46a10`

Revision 5 — CI wiring, B2/B3 split. One line per revision-4 plan-review
finding → resolution:

1. **Must-fix 1** (`test_checkpoint_269.sh` never wired into anything that
   runs it — verified `validate.yml` names only 3 of 10 existing
   `test_*.sh` files, no auto-discovery loop anywhere) → PR A now adds a
   `.pre-commit-config.yaml` local hook (`validate-script-tests`,
   `always_run: true`, `pass_filenames: false`) running a new
   `.agent/scripts/tests/run_script_tests.sh` that executes every
   `test_*.sh` in that directory, inside the existing `Lint (pre-commit)`
   job — no `validate.yml` edit, same pattern as the existing
   `validate-adapter-contract` local hook. Measured all ten existing
   suites (`time bash test_*.sh` each, in this worktree): 1.18s, 1.27s,
   0.38s, 0.32s, 0.05s, 2.74s, 3.22s, 0.05s, 7.65s, 0.17s — total ~17.0s,
   fine for pre-commit; no two-tier fast/CI split needed, and
   `test_checkpoint_269.sh` stays a fast pre-commit suite either way. The
   false "picked up by the existing test harness" sentence is removed.
2. **Must-fix 2** (nothing stops a PR from editing/deleting the
   checkpoint test) → defense in depth, named plainly as that, not proof:
   `run_script_tests.sh` globs test files for coverage **and**
   separately asserts `test_checkpoint_269.sh`'s explicit presence (its
   deletion breaks the runner, not just silently drops one suite);
   `test_checkpoint_269.sh` asserts its own filename appears in that
   explicit assertion; a social rule requires any PR touching either file
   to say so in its decision summary, checked by the reviewer.
3. **Must-fix 3** (durable-record entries didn't say which `progress.md`
   they target for project/package-scope PRs) → resolved by reusing
   `merge_pr.sh`'s own existing resolution pattern rather than inventing
   one: `find_worktree_for_branch()` (`merge_pr.sh:176`, already called
   at `merge_pr.sh:457` for the roadmap-update step) with
   `_WT_REPO` chosen by `$WORKTREE_TYPE`, or `$PKG_WT_DIR`
   (`merge_pr.sh:389-436`) for package PRs — the same qualified
   `owner/repo#N` handling the roadmap step already uses. When no
   worktree is open (both resolve empty), the entry falls back to
   `.agent/work-plans/merges/<owner>-<repo>-pr<N>.md` in the workspace,
   named explicitly in the report line when taken. Consistent with the
   refusal-scoping section: refusal stays workspace-only, but the durable
   *record* is written for every scope.
4. **Must-fix 4** (`PROGRESS_PERSISTENCE_STRICT` env-var-only carrier
   justified by a false claim that `review-code` has no stable flag
   surface — contradicted by its own existing `--no-progress` flag) →
   carried both ways: `--strict-progress` (an invocation flag, mirroring
   `--no-progress`'s naming and placement) for the one-off checkpoint
   exercise and any other single-run override; `PROGRESS_PERSISTENCE_STRICT`
   (unchanged) as the ambient default-setter B2 flips for every ordinary
   invocation — a flag can't flip a default without editing every call
   site, which is the job only the env var can do.
5. **Suggestion** (B2's "one-line"/"single follow-up commit" framing
   contradicted by also deleting the compatibility-mode code and tests it
   depended on) → B2 is split: B2 is now only the default-value flip
   (three lines total, one commit, genuinely revertible, since the old
   code stays in place and keeps passing its existing tests); removing
   the now-dead compatibility path and its tests moves to a new **PR
   B3**, opened only after B2 has been in ordinary use. Blast radius's
   B2 row and the Estimated Scope PR-sequence paragraph are updated to
   name B3 and its own (much smaller) worst case.

**Final PR sequence**: A (ADR + `progress_append.sh`/`progress_read.py` +
`test_checkpoint_269.sh` + `run_script_tests.sh` + the new pre-commit
hook) → B (`review-code`, `PROGRESS_PERSISTENCE_STRICT=0`/
`--strict-progress` override default) → **checkpoint** (A+B exercised on
#265 PR 2 via `--strict-progress`, `## Checkpoint` entry recorded,
mechanically required from here on by `test_checkpoint_269.sh`) → **B2**
(flips the switch's default to `1` for review-code/triage-reviews/
plan-task only — no code deletion — gated by the same mechanical check) →
C (`triage-reviews`, same switch) → D (`address-findings`, new skill) → E
(`plan-task`/`review-plan` headings, same switch on `plan-task`,
non-fatal new step on `review-plan`) → F (merge gate, report-only default
+ `## Merge (report-only)`/`## Merge (unreviewed)` durable records with
cross-repo target resolution + PR template) → **B3** (later, opened only
after B2 has been trusted in use — deletes the dead compatibility-mode
code and its tests). B2's ordering relative to C–F stays flexible (any
time after the checkpoint); B3 lands later still, whenever the owner is
confident nothing needs the `0` fallback.

## Plan Review
**Status**: complete
**When**: 2026-09-16 (offset not captured by this session; UTC-agnostic timestamp)
**By**: independent reviewer (claude-sonnet-5), fresh context, revision 5
**Verdict**: needs-work
**Plan**: `.agent/work-plans/issue-269/plan.md` at `4a46a10`

### Findings

- [x] (must-fix) The cross-repo durable-record fallback path (plan.md:733-747, 813-819, resolving revision 4's must-fix 3) writes `.agent/work-plans/merges/<owner>-<repo>-pr<N>.md` "created via the same `progress_append.sh` helper (`-C` pointed at the workspace tree)" when no worktree is open for the PR's repo. `progress_append.sh` commits (per PR A's own description: "append + commit in one prompt-free step"). `merge_pr.sh` resolves `$ROOT_DIR` as "the workspace root (main tree)" (merge_pr.sh:140) — the main checkout, which AGENTS.md's worktree rules keep on `main` by convention ("never edit files in the main tree"; worktrees exist precisely so feature work never touches it directly). Committing there hits two independent blockers this plan doesn't address: (1) `.pre-commit-config.yaml`'s `no-commit-to-branch` hook (`args: ['--branch', 'main']`, confirmed in this tree) fails the commit outright unless skipped, and AGENTS.md hard-stops skipping hooks (`--no-verify`); (2) even if committed locally, `main` is push-protected (confirmed: "Never commit to main — branch is protected; direct pushes are rejected," and this repo's own git status banner says the same). Contrast with the roadmap-update precedent this section says it "reuses exactly" (merge_pr.sh Step 1): that commit lands on the PR's own feature branch, which still exists and is mergeable. The merges/ fallback has no such branch to land on — that's exactly why it exists — so "reuses exactly this" doesn't carry over the one property (a mergeable branch) that made the original pattern work. Separately, the plan never says whether `.agent/work-plans/merges/` is gitignored or committed, or who prunes it — if the branch-commit problem were solved, the directory still grows unbounded with no owner. Needs an actual delivery mechanism (e.g., a dedicated branch + auto-PR for the fallback file, or an explicitly out-of-git store) or the "documented workspace-local fallback" claim doesn't hold as specified. — plan.md:733-747, 813-819
- [x] (suggestion) The new `validate-script-tests` pre-commit hook (`always_run: true`, plan.md:190-193, 1213) runs on every commit in every worktree, unconditionally — unlike the hook the plan cites as its "exactly the way validate-adapter-contract already does" precedent, which is `files:`-scoped and only fires when adapter files are staged (confirmed: `.pre-commit-config.yaml:50-55` has a `files:` regex, no `always_run`). The "mirrors" framing is accurate only for "runs inside the existing Lint job, no `validate.yml` edit," not for when it fires — worth being precise about, since it means every commit workspace-wide now costs +~17–20s (measured myself: 18.4s across the ten current suites, close to the plan's ~17.0s), not just commits touching test/script files. The plan reasons about total runtime being acceptable but doesn't address the per-commit-regardless-of-diff cost or mention the `SKIP=validate-script-tests` escape hatch this repo's own CI job already uses the same `SKIP=` mechanism for (`validate.yml`'s Lint job sets `SKIP: check-commit-identity,...` today) — worth a line for WIP commits, though not a blocking gap since AGENTS.md's hook-skipping rule already covers the general case (skip only when justified, never `--no-verify`).

### Prior findings status (revisions 1–4)

Revision 4's four must-fixes are resolved on inspection, three cleanly and one only partially (see the must-fix above, which reopens part of must-fix 3, not the whole of it):
- Must-fix 1 (checkpoint test not wired into anything that runs it) — resolved. Verified `.github/workflows/validate.yml` names exactly `test_adapter.sh`, `test_project_registry.sh`, `test_ros2_colcon.sh` at lines 38/41/44 (confirmed against this tree) — matches the plan's "3 of 10" claim exactly, all 10 `test_*.sh` files confirmed present. The new `.pre-commit-config.yaml` local hook + `run_script_tests.sh` runner, executed inside the existing `Lint (pre-commit)` job via `make lint` (confirmed: `lint: ... $(PRE_COMMIT) run --all-files`), is a real fix — no `validate.yml` edit needed, closing the Ask-First concern too.
- Must-fix 2 (nothing stops editing/deleting the checkpoint test) — resolved as defense-in-depth, honestly framed as such (glob + explicit-presence self-check + social rule, explicitly not claimed as proof).
- Must-fix 3 (cross-repo `progress.md` target unspecified) — partially resolved. The "found" case (reusing `find_worktree_for_branch()` at `merge_pr.sh:176`/called at `:457`, and `$PKG_WT_DIR` resolved at `:389-436` — both confirmed verbatim against this tree) is solid and correctly scoped. The "not found" fallback is the new must-fix above — it's specified but not deliverable as written.
- Must-fix 4 (`PROGRESS_PERSISTENCE_STRICT` justified by a false claim about `review-code` having no stable flag surface) — resolved. Confirmed `--no-progress` exists at `review-code/SKILL.md:15,20,108,110,117,392,498` exactly as the plan now cites; the added `--strict-progress` invocation flag alongside the retained env var (for the different job of flipping an ambient default vs. a per-run override) is a coherent fix, not just a re-justification.

Revision 4's one suggestion (B2's "one-line"/"one-commit-revertible" framing vs. its bundled code deletion) is resolved by the B2/B3 split: B2 is now genuinely only the default-value flip (old code path untouched, confirmed no deletion language remains in the B2 section); cleanup is deferred to a named-but-not-yet-opened B3. B3 is correctly still caught by the checkpoint gate in practice — it touches `plan-task/SKILL.md` and `triage-reviews/SKILL.md`, both already on the checkpoint's gated-file list (confirmed: the checkpoint's own file-touch test cases are per-file, "a synthetic PR diff touching each gated file," not line-scoped to specific headings) — so the plan's claim that B3 "stays gated... with no special-casing needed" holds.

Revisions 1–3's must-fixes (the false "type MERGE to confirm" banner claim, the `#265` path-resolution overclaim, PR F's dropped decision-summary-comment condition, the checkpoint-doesn't-gate-PR-B gap, the checkpoint-is-unenforced-in-schema gap, report-only's missing durable record) remain applied in revision 5's text; nothing in the revision 4→5 diff touches those sections in a way that reopens them.

### Verified claims (spot-checked against the tree in this worktree)

- `.github/workflows/validate.yml` lines 38, 41, 44 name exactly `test_adapter.sh`, `test_project_registry.sh`, `test_ros2_colcon.sh`; the other 7 of this repo's 10 `.agent/scripts/tests/test_*.sh` files are absent from `validate.yml`, `.pre-commit-config.yaml`, and the Makefile, confirming the plan's "3 of 10" claim exactly.
- `.pre-commit-config.yaml`'s `validate-adapter-contract` hook (lines 50-55) confirmed: `files:` regex-scoped, no `always_run`, `pass_filenames: false` — the pattern the new hook's "runs inside Lint, no validate.yml edit" claim is accurate about, but not about firing unconditionally (see suggestion above).
- `merge_pr.sh:176` defines `find_worktree_for_branch()`; called at `merge_pr.sh:457`. `PKG_WT_DIR` is set at `merge_pr.sh:389` and used through `merge_pr.sh:435-440` — both confirmed at the plan's cited line numbers.
- `review-code/SKILL.md` confirmed to reference `--no-progress` at exactly lines 15, 20, 108, 110, 117, 392, 498 as the plan now cites.
- Ran all ten `.agent/scripts/tests/test_*.sh` suites myself in this worktree: all pass (`rc=0`), total 18.4s (`test_adapter.sh` 1.18s, `test_block_bash_tool_mapping.sh` 1.25s, `test_cross_model_review.sh` 0.37s, `test_gh_create_pr.sh` 0.32s, `test_merge_pr_root_resolution.sh` 0.05s, `test_merge_pr.sh` 2.70s, `test_project_registry.sh` 3.20s, `test_resolve_work_plans_dir.sh` 0.06s, `test_ros2_colcon.sh` 9.11s, `test_sync_gitbug.sh` 0.17s) — consistent with the plan's ~17.0s claim (machine variance, same order of magnitude; `test_ros2_colcon.sh` ran slower here than the plan's measured 7.65s but the total is still well within "fine for pre-commit" territory). None of the seven previously-unwired suites are currently red, so PR A's new runner would not turn CI red on day one.

### Summary

Revision 5 correctly resolves three of revision 4's four must-fixes (CI wiring, checkpoint self-protection, the `PROGRESS_PERSISTENCE_STRICT` justification) and cleanly un-bundles B2 from B3. The fourth (cross-repo durable-record target) is only half-resolved: the "found a worktree" path is solid and well-cited, but the documented fallback for "no worktree found" — commit a new file into the workspace's main tree via `progress_append.sh -C <workspace tree>` — runs straight into this repo's own `no-commit-to-branch` hook and branch-protected `main`, neither of which the plan addresses. This is the same shape of gap revision 4 found in revision 3 and revision 5 found in revision 4: a mechanism described as resolving a must-fix that, checked against the actual tree/policy, doesn't fully work as specified. Not ready for implementation until the fallback delivery mechanism is fixed or replaced.

### Recommended Actions

- [ ] Specify a working delivery mechanism for the `.agent/work-plans/merges/<owner>-<repo>-pr<N>.md` fallback record that doesn't require committing directly to the workspace's protected `main` — e.g., a dedicated short-lived branch + auto-opened PR, or a store outside `main`'s protection — and state whether the directory is gitignored/committed and who prunes it. — plan.md:733-747, 813-819
- [ ] Optional: note the `always_run: true` per-commit cost precisely (every commit, not just test/script-touching ones) and consider documenting `SKIP=validate-script-tests` as sanctioned for WIP commits, consistent with this repo's own existing `SKIP=` usage in `validate.yml`'s Lint job. — plan.md:190-236

## Plan Authored
**Status**: complete
**When**: 2026-09-16 14:52 -04:00
**By**: Claude Code Agent (claude-fable-5-1), with owner approval
**Plan**: `.agent/work-plans/issue-269/plan.md` at `11c2c37` — revision 6

- revision-5 must-fix (fallback merge record uncommittable on protected main) → record posted as a comment on the merged PR; no file, no commit; PR F tests stub `gh`
- revision-5 suggestion (always_run hook cost) → ~18 s per commit stated; `SKIP=validate-script-tests` sanctioned for WIP
- owner (2026-09-16): implementation may start with PR A

## Implementation
**Status**: complete
**When**: 2026-09-17 08:16 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**PR**: #270 at `3911bc9`
**Scope**: PR A of the plan at `11c2c37` (revision 6)

- `484fb94` run_script_tests.sh + validate-script-tests pre-commit hook (all 14 suites, ~18 s per commit)
- `a7acae7` progress_append.sh + progress_read.py ported, with test_progress_append.sh / test_progress_read.py
- `3911bc9` test_checkpoint_269.sh: C–F/B2 file changes refused until a `## Checkpoint` entry is on main
- ADR-0013, principles_review_guide row, and ARCHITECTURE note landed in earlier commits on this branch
- All 14 script suites pass locally; this entry is the first written by progress_append.sh itself

## Local Review
**Status**: complete
**When**: 2026-09-17 08:35 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**PR**: #270 at `88bbb3c`
**Depth**: Deep (reason: 10+ files, 200+ lines, enforcement + ADR files)
**Must-fix**: 6 | **Suggestions**: 4
**Cross-model**: gemini failed (argv too long, 242 KB prompt), copilot failed (#212), codex not installed

### Findings
- [ ] (must-fix) CI red: sandbox bare remote lacks `-b main`; clone lands on unborn master, push main fails on runners with default init branch — `.agent/scripts/tests/test_merge_pr.sh:184,383`
- [ ] (must-fix) Real checkpoint gate records PASS when origin/main is unresolvable; CI's depth-1 checkout hits this, gate inert in CI (confirmed in run log) — `.agent/scripts/tests/test_checkpoint_269.sh:211-213`
- [ ] (must-fix) checkpoint_entry_complete unions fields across adjacent Checkpoint entries; two incomplete entries pass — `.agent/scripts/tests/test_checkpoint_269.sh:72-76`
- [ ] (must-fix) Only the first heading is validated; extra `## ` lines in the body smuggle forged entries past the whitelist — `.agent/scripts/progress_append.sh:76-116,142`
- [ ] (must-fix) --title written unsanitized; embedded newlines forge entries — `.agent/scripts/progress_append.sh:126-127`
- [ ] (must-fix) Append redirect unchecked; write failure exits 0 as "already committed" — `.agent/scripts/progress_append.sh:142`
- [ ] (suggestion) AGENTS.md Script Reference lacks progress_append.sh / progress_read.py (Ask-First) — `AGENTS.md`
- [ ] (suggestion) Runner should preflight jq with a clear message (bootstrap installs it; CI has it) — `.agent/scripts/tests/run_script_tests.sh`
- [ ] (suggestion) Loose correlation regexes; frontmatter `issue:7` without space yields None — `.agent/scripts/progress_read.py:148,155,234`
- [ ] (suggestion) cross_model_review.sh passes a 242 KB prompt as argv to agy; open an issue — `.agent/scripts/cross_model_review.sh:110`

## Implementation
**Status**: complete
**When**: 2026-09-17 08:54 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**PR**: #270 at `3d4ca6c`
**Scope**: round-1 Local Review findings (entry at `20fdaab`), all six must-fixes + two suggestions

- [x] (must-fix) CI red / bare remote default branch → `f8a1cc9` pins HEAD to main; verified with init.defaultBranch=master
- [x] (must-fix) real gate inert in CI → `e7ff184` shallow-fetches origin/main, fails under CI when unresolvable, tree-diffs without a merge-base
- [x] (must-fix) adjacent Checkpoint blocks pooled → `e7ff184` per-block judgement, fence-aware
- [x] (must-fix) multi-heading body smuggles entries → `18ef777` one top-level heading per call
- [x] (must-fix) newline in --title → `18ef777` rejected
- [x] (must-fix) unchecked append redirect → `18ef777` exit 3, no false no-op
- [x] (suggestion) AGENTS.md Script Reference → `3d4ca6c` (owner-approved Ask-First edit)
- [x] (suggestion) jq preflight in runner → `3d4ca6c`
- [ ] (suggestion) progress_read.py loose regexes / frontmatter without space — deferred, hand-edited files only
- [ ] (suggestion) cross_model_review.sh argv limit with agy — filed as a separate issue

## Local Review
**Status**: complete
**When**: 2026-09-17 09:08 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**PR**: #270 at `a70a877`
**Depth**: Deep (rounds 2 and 3: fresh adversarial re-review of the fix commits only)
**Must-fix**: 0 | **Suggestions**: 1
**Convergence**: round 1 → 6 must-fix; round 2 → 1 new (unterminated fence hides later entries); round 3 → 1 new (fence-regex NBSP parity) + 1 diagnostic gap; round-3 items fixed in `a70a877` and verified by the affected suites; no further review round

### Findings
- [x] (must-fix, round 2) unterminated fence silently hid later entries in progress_read.py and the gate → `a1107c4` writer refuses, both readers exit 2 loudly
- [x] (must-fix, round 3) NBSP-prefixed fence accepted by writer, rejected by reader → `a70a877` all three matchers use `[ \t]*`
- [x] (suggestion, round 3) real-gate FAIL line carries the malformed-file reason → `a70a877`
- [ ] (suggestion, round 2) the real gate's base-ref resolution hard-fails under CI on a transient fetch failure for every PR, not only gated ones — intentional fail-closed; revisit if it flakes

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 10:13 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-269-prB at `f79e35c`
**Base**: main
**Depth**: Deep (reason: 500+ lines; skill + knowledge files are governance triggers)
**Must-fix**: 4 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 4 must-fix, two not mechanical (compat-path validation design, override handling)

### Findings
- [x] (must-fix) compat --title newline forges entries — `.agent/scripts/review_progress.sh:199` → 7539a35
- [x] (must-fix) compat entry content unvalidated (second heading, open fence committed) — `.agent/scripts/review_progress.sh:199-209` → 7539a35
- [x] (must-fix) compat retry after failed commit double-appends — `.agent/scripts/review_progress.sh:199-213` → 7539a35
- [x] (must-fix) strict WORK_PLANS_DIR_OVERRIDE root mis-derived; claims override honored — `.agent/scripts/review_progress.sh:177-188` → 7539a35
- [x] (suggestion) --strict-progress absent from step 1b parsing — `.claude/skills/review-code/SKILL.md` → 7539a35
- [x] (suggestion) usage() sed line range brittle — `.agent/scripts/review_progress.sh:59` → 7539a35
- [ ] (suggestion) progress_read.py branch regex captures backticks if **Branch** is backtick-wrapped; skill template does not wrap — `.agent/scripts/progress_read.py` deferred
- [x] (governance) "documented as absent" note missing; AGENTS.md row is a human call — `.claude/skills/review-code/SKILL.md` → 7539a35

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 10:13 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**Branch**: feature/issue-269-prB at `9fb9876`
**Base**: main
**Depth**: Deep (reason: re-review of the fix commit only)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 2 | **Ship**: recommended — no must-fix findings; all four round-1 fixes verified by reproduction; one low leftover (abort-path mkdir) fixed in 9fb9876

### Findings
- [x] (suggestion) strict abort created the override dir before checking it — `.agent/scripts/review_progress.sh:201` → 9fb9876

## Checkpoint
**Status**: complete
**When**: 2026-09-17 11:35 -04:00
**By**: Roland Arsenault (owner), attested in session after reading the condensed decision summary; exercise run by Claude Code Agent (claude-fable-5-1)

**PR**: #273
**Review entry SHA**: fd8e935 (entry committed at 7c43fba on feature/issue-265-pr2 by progress_append.sh, with **Round**/**Ship** fields)
**Resolver-hit**: resolve_work_plans_dir 265 under --strict-progress returned /home/roland/agent_workspace/worktrees/workspace/issue-workspace-265/.agent/work-plans/issue-265 (no fallback, no notice)
**Decision summary URL**: https://github.com/rolker/agent_workspace/pull/273#issuecomment-5716905535

Observations 1-3 from the plan's "Checkpoint after PR B" all held on a real, non-trivial PR. The exercise also found PR 273 needs work (4 must-fix); that is #265's concern, not a defect in PR A/B.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 11:49 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-269-prC at `976aad2`
**Base**: main
**Depth**: Deep (reason: skill + knowledge files are governance triggers; 370 lines)
**Must-fix**: 4 | **Suggestions**: 4
**Round**: 1 | **Ship**: continue — round 1: 4 must-fix, one (same-file rule) a design choice

### Findings
- [x] (must-fix) malformed reviews JSON crashed with a traceback, exit 1 — `.agent/scripts/review_progress.sh` → a6b774e
- [x] (must-fix) suffix path matching produced false cross-source candidates — `.agent/scripts/review_progress.sh` → a6b774e (exact repo-relative path)
- [x] (must-fix) a finding citing two files lost the first — `.agent/scripts/review_progress.sh` → a6b774e
- [x] (must-fix) --progress naming a directory degraded silently to an empty timeline — `.agent/scripts/review_progress.sh` → a6b774e
- [x] (suggestion) checked findings were emitted as "open" — `.agent/scripts/review_progress.sh` → a6b774e
- [x] (suggestion) Usage block omitted the flags; local_findings contents under-described — `.claude/skills/triage-reviews/SKILL.md` → a6b774e
- [x] (governance) stale consequences-map row for plan-file review blocks — `.agent/knowledge/principles_review_guide.md` → 54ca477
- [x] (governance) helper + PR B test touched beyond the plan's file list — justified drift, disclosed in the PR

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 11:52 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**Branch**: feature/issue-269-prC at `a6b774e`
**Base**: main
**Depth**: Deep (reason: re-review of the fix commits)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 2 | **Ship**: recommended — all seven round-1 items verified fixed by reproduction; no new findings

### Findings
- [ ] No issues found. LGTM.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 12:10 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-269-prD at `f5bc2fe`
**Base**: main
**Depth**: Deep (reason: new skill + gated files; helper change)
**Must-fix**: 1 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: a critical index-divergence bug in check (fixed in f5bc2fe)

### Findings
- [x] (must-fix) check's own checkbox scanner diverged from progress_read.py (fenced/indented/header boxes) and could flip the wrong line — `.agent/scripts/review_progress.sh` → fixed: reader reports line numbers, check uses them
- [x] (suggestion) CRLF files rewritten to LF file-wide — `.agent/scripts/review_progress.sh` → fixed (newline="")
- [x] (suggestion) --deferred "" silently indistinguishable from omitted — `.agent/scripts/review_progress.sh` → refused
- [x] (suggestion) heredoc-in-substitution warning in the test — `.agent/scripts/tests/test_address_findings.sh` → entry written to a file
- [x] (governance) review-code / triage-reviews had no hand-off to address-findings — both SKILL.md files → next-step paragraphs
- [ ] (governance) plan's Files-to-Change claims copilot/gemini instruction files list skills; they do not — plan claim wrong, noted in the PR, no file change

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 12:16 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**Branch**: feature/issue-269-prD at `60034f8`
**Base**: main
**Depth**: Deep (reason: re-review of the fix commit)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 2 | **Ship**: recommended — all round-1 items verified fixed by reproduction (decoy fixture, CRLF, empty deferred, hand-off docs); no new findings

### Findings
- [ ] No issues found. LGTM.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 12:29 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-269-prE at `5898888`
**Base**: main
**Depth**: Deep (reason: two gated skill files + helper)
**Must-fix**: 2 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix (spec gaps in the new review-plan step), fixed in 4af56b6

### Findings
- [x] (must-fix) review-plan report had no Status/When/By; step 6 referenced a field that did not exist — `.claude/skills/review-plan/SKILL.md` → header fields in all three templates
- [x] (must-fix) plan-sha required a local checkout; the PR-number form could not get the plan-commit SHA — `.agent/scripts/review_progress.sh` → --ref mode + fetch in the skill
- [x] (suggestion) "ERROR: " prefix not stripped (case) in the soft notice — `.agent/scripts/review_progress.sh` → fixed
- [x] (suggestion) --soft merged stderr notes into stdout — `.agent/scripts/review_progress.sh` → streams separated
- [x] (suggestion, governance) consequences-map row named only the review entry types — `.agent/knowledge/principles_review_guide.md` → all six types, five writers
- [ ] (suggestion) --branch is ignored when --issue is set (pre-existing across B–E) — deferred; harmless, documented arity

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 12:34 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**Branch**: feature/issue-269-prE at `4af56b6`
**Base**: main
**Depth**: Deep (reason: re-review of the fix commit)
**Must-fix**: 1 | **Suggestions**: 0
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 2), not rising; fixed in 1988c5f and covered by a test

### Findings
- [x] (must-fix) --soft failure path discarded the captured stderr (remediation lines lost) — `.agent/scripts/review_progress.sh` → re-emitted to stderr, test added

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-17 12:50 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-269-prF at `4988fb1`
**Base**: main
**Depth**: Deep (reason: merge_pr.sh is an enforcement file; gated files)
**Must-fix**: 5 | **Suggestions**: 6
**Round**: 1 | **Ship**: continue — round 1: 5 must-fix, two design-level (PR body, External Review); fixed in 4c57015

### Findings
- [x] (must-fix) condition (b) ignored the PR body where the template puts the summary — `.agent/scripts/merge_pr.sh` → body + comments
- [x] (must-fix) jq filter dropped External Review predecessor entries — `.agent/scripts/merge_pr.sh` → honoured under the Integrated Review rule
- [x] (must-fix) PR-comment record lacked the AI signature format — `.agent/scripts/merge_pr.sh` → Authored-By + Model
- [x] (must-fix) package worktree treated as a repo; timeline path structurally dead — `.agent/scripts/merge_pr.sh` → explicit comment path with reason
- [x] (must-fix) push failure after the record commit left a stranded commit plus a comment — `.agent/scripts/merge_pr.sh` → commit undone, one comment
- [x] (suggestion) malformed progress.md reported as "no entry" — `.agent/scripts/merge_pr.sh` → named as malformed
- [x] (suggestion) bypass banner printed twice via tee — `.agent/scripts/merge_pr.sh` → once
- [x] (governance) Layer 2 design absent from shipped artifacts — `.agent/scripts/merge_pr.sh` header, PR template
- [x] (governance) plan not amended for the Step 1.5 placement — `.agent/work-plans/issue-269/plan.md` implementation note
- [x] (governance) review-code / triage-reviews did not say the summary must be posted on the PR — both SKILL.md files
- [ ] (governance) AGENTS.md "Merging PRs from Worktrees" section could mention the gate — Ask-First beyond script rows; left for the owner
