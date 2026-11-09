---
issue: 419
---

# Issue #419 — Pre-commit suite selector: a documentation file under .agent/ runs every suite because it maps to no suite

## Issue Review
**Status**: complete
**When**: 2026-11-09 11:58 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #419

### Scope Assessment

**Well-scoped?** Yes — one selector change (`is_code` already exists in `suites_for_files.sh`), one header list, one stderr note, tests, one doc row. Single PR.
**Right repo?** Yes — workspace (`.agent/scripts/tests/`, `.pre-commit-config.yaml` untouched).
**Serves**: "Easy to use" (a doc edit does not cost a 12-minute hook run) — `docs/design.md#the-design` (the hook/test-gate section; the plan names the exact anchor)
**Design picture?** No change — narrows an existing trigger inside the issue-410 design; the hook scope and `files:` pattern stay.
**Dependencies**: none open; builds on merged #410 and #399.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | Removes a cost with no coverage gained; no new mechanism, reuses `is_code`. |
| Enforcement over documentation | Watch | The full-run rule exists so an undeclared file cannot slip past the suites. A document is safe only if no suite reads it without declaring it. Suites that scan prefixes already join via `# scans:` (e.g. `test_skill_paths.sh` scans `.agent/ .claude/ AGENTS.md Makefile`), and the drift check covers `ROOT_READERS`, but a suite that reads a doc by a runtime-assembled path stays invisible (the header's "Residual risk"). The plan should state this residual risk next to the new rule. |
| Improve the system, not just the output | Watch | "Documentation" must be defined by a rule, not a hand-kept list, and narrowly. In scope today (tracked, minus work-plans): 104 `.sh`, 70 `.md`, 13 `.py`, plus `.json`, `.yml`, `.conf`, `.example`, `.txt`, `.cpp`. Only Markdown is plainly documentation; `.json`/`.yml`/`.conf`/`.example` are configuration that suites may parse, so "non-code" (`not is_code`) is too broad a test. Recommend Markdown only (decided from the tracked list), widening only with evidence. |
| Test what you change | Watch | An existing assertion contradicts the new rule: `test_run_script_tests.sh:702` expects `ALL` for the unmapped `.agent/docs/unmapped.md` ("an unmapped in-scope file yields ALL, even under a '# scans:' prefix"). It must be rewritten (keep the scans point with a non-Markdown file) or the change fails its own suite. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0013 (progress timeline) | Yes | Review entry persisted to progress.md. |
| ADR-0017 (design doc in same change) | No | No change to the design picture; the `docs/design.md` hook description should be checked for a statement that any unmapped file runs everything. |
| Others | No | |

### Consequences

- `.agent/knowledge/script_reference.md` rows for `suites_for_files.sh` and `run_script_tests.sh` (the latter lists "an in-scope file no suite maps" as a full-run case and needs the documentation exception).
- `.pre-commit-config.yaml` comment block and the `suites_for_files.sh` header list.
- Ordering catch: editing `suites_for_files.sh` and the runner is itself a full-run trigger, so the implementing branch runs every suite once at its final pass; expected, not a defect.

### Recommendations

- Define documentation as Markdown (`.md`) in the hook's scope, derived from the tracked file list per file, not a hand-kept allowlist; leave `.json`/`.yml`/`.conf`/`.example`/`.txt` on the existing unmapped-file rule unless the plan shows no suite reads them.
- Keep a documentation file that a suite does reference (derivation or `# covers:`) mapped to that suite as today; only an otherwise-unmapped document stops triggering ALL. A doc under a `# scans:` prefix still selects the scanning suites, so acceptance case 2 ("nothing more") means the suites that reach `sitrep_root.sh` plus those scan/required suites the selector already adds; say so in the plan so the test expectation is exact.
- Update `test_run_script_tests.sh:702` (unmapped `.md` no longer yields ALL) and add the issue's three cases plus: a deleted `.md` still yields ALL, an unmapped `.json` still yields ALL, a doc referenced by a suite still selects it.
- Update the stderr note, the header's full-run list, and the two `script_reference.md` rows named above in the same PR.

### Actions
- [ ] Define documentation as Markdown (`.md`) in the hook's scope, derived from the tracked file list per file, not a hand-kept allowlist; leave `.json`/`.yml`/`.conf`/`.example`/`.txt` on the existing unmapped-file rule unless the plan shows no suite reads them.
- [ ] Keep a documentation file that a suite does reference (derivation or `# covers:`) mapped to that suite as today; only an otherwise-unmapped document stops triggering ALL. A doc under a `# scans:` prefix still selects the scanning suites, so acceptance case 2 ("nothing more") means the suites that reach `sitrep_root.sh` plus those scan/required suites the selector already adds; say so in the plan so the test expectation is exact.
- [ ] Update `test_run_script_tests.sh:702` (unmapped `.md` no longer yields ALL) and add the issue's three cases plus: a deleted `.md` still yields ALL, an unmapped `.json` still yields ALL, a doc referenced by a suite still selects it.
- [ ] Update the stderr note, the header's full-run list, and the two `script_reference.md` rows named above in the same PR.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 11:54 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (the four open actions are mechanism: documentation defined as Markdown in the hook's scope from the tracked file list, a referenced doc stays mapped, one existing test rewritten plus new cases, the stderr note, header and reference rows updated; none changes what the owner asked for, a doc edit not costing the full suite run)
**After**: issue-actions
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. The actions go to plan-task as plan inputs.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 12:10 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-419/plan.md` at `257cb3f9`

An unreferenced Markdown file reaching no suite no longer triggers a full run (one extension test at the empty-hits branch of suites_for_files.sh); non-Markdown, deleted, and under-tests/ files keep ALL. Rewrites both tests that pinned the old rule (test_run_script_tests.sh:702 and the real-tree check in test_script_tests_hook_scope.sh), and updates header, stderr note, config comment and script_reference rows.

## Plan Review
**Status**: complete
**When**: 2026-11-09 12:00 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #419 — Pre-commit suite selector: a documentation file under .agent/ runs every suite because it maps to no suite
**Plan**: `.agent/work-plans/issue-419/plan.md` at `257cb3f9`
**Branch**: `feature/issue-419`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One branch in `main()` of `suites_for_files.sh`, comments, two test files, one doc file. Single PR. |
| Issue alignment | Needs work | Serves (as written): Goal "Easy to use" (`README.md#workspace-goals`), "under the hook and test-gate part of `docs/design.md#the-design`". All four Issue Review actions are addressed. Two gaps: acceptance command 2 cannot pass on this branch (finding 1), and "a doc-only change selects no extra suite" is never tested where it can hold (finding 2). |
| File targeting | Good | Checked against the code: the rule change sits at `if not hits:` (line 642); `hits` comes from `closure`, which holds every vocabulary file a suite or its reachable code names, documents included as leaves, so a referenced `.md` still has hits and stays mapped. Deleted paths (line 607), fixed triggers, `_*.sh` helpers and the under-`tests/` rule (line 636) all run before line 642, so the plan's claims about deleted `.md`, `.md` under tests/ and scans-joining are right. |
| Consequences | Needs work | Selector header, stderr note, runner header (line 34), config comment and the `script_reference.md` runner row (line 51) are listed; no selector row exists today, so adding one is right. Missed: the header of `test_script_tests_hook_scope.sh` (line ~73, "a file no code names runs everything") and the comment above the rewritten check (~689) state the old rule (finding 4). |
| Principle alignment | Good | Only what's needed: one extension test, no list. Enforce what matters: code and config still fail safe to `ALL`. Residual-risk statement is accurate: in-scope tracked `.md` today = 72, 41 unmapped, all under `.agent/` (28 knowledge, 7 templates, 4 top-level guides, 1 instructions, 1 workflows); every `.claude/` `.md` is already mapped (SKILL.md files by basename through scripts that name `SKILL.md`). Real-tree readers declare `ROOT_READERS`, and the suites that glob docs (`test_plugin_manifest.sh`, `test_skill_paths.sh`) declare `# scans:`. |
| ADR compliance | Good | ADR-0013 (timeline entries), ADR-0017 (no design change; `docs/design.md` checked, line 389 only names the runner), ADR-0005 (CI all-files run stays the backstop). |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Issue alignment] must-fix** — Acceptance command 2 names `.agent/scripts/sitrep_root.sh`, which is not on `main` or this branch: it arrives with the open sit-rep PR for issue 418 (PR 420). Run here, `suites_for_files.sh .agent/scripts/sitrep_root.sh` prints `ALL` ("maps to no suite": a passed path nothing references), so step 7's real-tree check of case 2 prints `ALL` whatever the fix does. Substitute a mapped script that exists on `main`, e.g. `.agent/scripts/sitrep_checks.sh` (today it selects `test_checkpoint_269.sh test_script_tests_hook_scope.sh test_sitrep_checks.sh test_skill_paths.sh`), say so in the plan, and state the criterion as "the doc plus the script selects exactly what the script alone selects".
2. **[Issue alignment / Test what breaks] must-fix** — Step 4(b)'s expected set contradicts itself: "beta's suites plus the same additions, equal to beta alone". `unmapped.md` sits under `test_scanner.sh`'s `# scans: .agent/docs/` and `beta.sh` does not, so doc plus beta is beta alone plus `test_scanner.sh`, not equal to beta alone. The issue's first test case, "a doc-only change selects no extra suite (the runner's required suite still joins)", is also untested in any place it can be true: on the real tree `test_skill_paths.sh` scans all of `.agent/`, and the only synthetic doc case uses a scanned doc. Add a doc fixture outside every scan prefix (e.g. `.agent/guide.md`) and pin it exactly: doc only gives `$BASE_ALWAYS test_noref.sh`, doc plus `beta.sh` gives exactly beta's set. Keep `unmapped.md` for the "scanning suite joins" case.
3. **[Issue alignment] suggestion** — Step 4(f) says "the existing `lone.sh` cases; confirm one exists". There is none: `lone.sh` appears only in the deleted-path case (line 704). Add `expect_sel "... undeclared script yields ALL" "ALL" -- .agent/scripts/lone.sh` with the "maps to no suite" stderr. On the real tree, step 5 needs no candidate search for the non-Markdown side: passed files join the vocabulary, so the issue's own `.agent/scripts/new_uncovered.sh` command works. Build that name at runtime in the suite (e.g. `".agent/scripts/new_uncovered_$$.sh"`): a literal path in `test_script_tests_hook_scope.sh`'s own text is a reference, which maps the file to that suite and turns the expected `ALL` into a selection. The same applies to the new `.json` and `tests/notes.md` synthetic cases: they need not be tracked fixtures, a passed path is enough, which keeps `make_syn_repo` unchanged.
4. **[Consequences] suggestion** — Update the `test_script_tests_hook_scope.sh` header (line ~73, "a file no code names runs everything") and the comment above the check at ~689 along with the check itself.
5. **[Scope] suggestion** — The rule covers every in-scope `.md` (`.claude/`, `AGENTS.md`, `.github/PULL_REQUEST_TEMPLATE.md`), wider than the issue's "`.md` under `.agent/`". This matches the Issue Review's recommendation and is safe today (all `.claude/` Markdown is mapped, see Principle alignment), but the plan should say it is wider, so the choice is on record.
6. **[Principle alignment] suggestion** — The residual risk has a live instance worth naming in the header: `worktree_create.sh:348` reads `.agent/workflows/${WORKFLOW}.md` through a path built at runtime. `collaborative.md` is unmapped and no suite exercises `--workflow`, so nothing is lost today.
7. **[Issue alignment] suggestion** — The Serves line cites `docs/design.md#the-design` and a "hook and test-gate part" that has no heading. Cite the section by anchor: `docs/design.md#registry-and-adapters` (the `test` verb row naming the runner, line 389) or `#rules`.

### Summary

The approach is right and matches the selector code: a referenced `.md` keeps its hits through the closure, and only the empty-hits branch changes. Two plan edits are needed before implementation: acceptance case 2 uses a script that does not exist on this branch, and the synthetic expectations neither agree with each other nor test a doc-only change outside a scan prefix.

### Recommended Actions

- [ ] Replace `sitrep_root.sh` in acceptance case 2 (steps 2 and 7) with a mapped script that exists on `main` (e.g. `.agent/scripts/sitrep_checks.sh`) and state the criterion as "same selection as the script alone".
- [ ] Add a synthetic doc fixture outside every `# scans:` prefix; pin doc-only = `$BASE_ALWAYS test_noref.sh` and doc + `beta.sh` = beta's set exactly; fix 4(b)'s contradictory expectation.
- [ ] Add a firm undeclared-`.sh` `ALL` case (no passed-`lone.sh` case exists); on the real tree use a runtime-built `new_uncovered` path, never a literal one.
- [ ] Update the `test_script_tests_hook_scope.sh` header and check comment that describe the old rule.
- [ ] Record that the rule covers all in-scope `.md`, not only `.agent/`; optionally cite the `worktree_create.sh` workflow read as the residual-risk example; cite a real design section anchor in Serves.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 12:01 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (two must-fix plan edits, both mechanism: acceptance command 2 names a script that exists only on the open sit-rep branch, so it must name one on main; test case 4(b)'s expectation contradicts itself and needs a doc fixture outside every scan prefix; first host revise on this issue)
**After**: plan
**Decision**: revise

Host answer under /orchestrator's checkpoint table. Findings 1-7 of the Plan Review at fc4651c6 go to plan-task.

## Plan Authored
**Status**: complete
**When**: 2026-11-09 12:03 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-419/plan.md` at `29e038fb`

Revision after the plan review (fc4651c6): acceptance case 2 now uses sitrep_checks.sh (host edits the issue bullet at PR open); a scan-free doc fixture pins the doc-only case and fixes 4(b); added lone.sh, .json, tests/notes.md and runtime-built new_uncovered cases; hook-scope header and comment updates; all-in-scope-.md breadth, the worktree_create.sh:348 residual-risk example and a real design.md anchor recorded.

## Plan Review
**Status**: complete
**When**: 2026-11-09 12:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #419 — Pre-commit suite selector: a documentation file under .agent/ runs every suite because it maps to no suite
**Plan**: `.agent/work-plans/issue-419/plan.md` at `29e038fb`
**Branch**: `feature/issue-419`

Second review (convergence check on findings 1-7 of the Plan Review at fc4651c6); scoped to those items and what the revision changed.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged: one branch at `if not hits:` in `suites_for_files.sh` `main()`, comments, two suites, one doc file. Single PR. |
| Issue alignment | Good | Serves (as checked): Goal "Easy to use" (`README.md#workspace-goals`), under `docs/design.md#registry-and-adapters` (heading exists at line 287; the `test` verb row names the runner). Finding 1 resolved: run here, `suites_for_files.sh .agent/scripts/sitrep_checks.sh` selects `test_checkpoint_269.sh test_script_tests_hook_scope.sh test_sitrep_checks.sh test_skill_paths.sh`, with `test_skill_paths.sh` joined through its `# scans: .agent/` prefix; the only real-tree scan prefixes are `.claude/skills/`, `.agent/scripts/tests/` and `.agent/ .claude/ AGENTS.md Makefile`, so after the fix `script_reference.md` adds only `test_skill_paths.sh` and doc plus script equals script alone, as the plan says. Today both print `ALL` (doc maps to no suite). Finding 2 resolved: the synthetic scan prefixes are `.agent/docs/` and `.agent/scripts/tests/` only (`test_scanner.sh`), so `.agent/guide.md` is outside all of them; traced through `main()`, the doc alone yields required + `# covers: ALL` + no-reference suites = `$BASE_ALWAYS test_noref.sh`, and doc plus `beta.sh` equals `beta.sh` alone. No synthetic case enumerates tracked files, so the new fixture does not disturb others. Finding 3 resolved: `lone.sh` case added; `.agent/scripts/new_uncovered_$$.sh` is built at runtime (checked: a runtime name prints `ALL` "maps to no suite"); `.agent/scripts/tests/notes.md` prints `ALL` through the under-`tests/` rule; `.json` and `notes.md` need no tracked fixtures. Finding 7 resolved (anchor). |
| File targeting | Good | Files table now lists the hook-scope header (~73) and check comment (~689); `make_syn_repo` changes only for `.agent/guide.md`. |
| Consequences | Good | Finding 4 resolved. The full-run pin at ~664 still holds after the fix: the all-files list includes `.pre-commit-config.yaml`, `Makefile` and unmapped `.sh` files, each of which still runs `ALL`. |
| Principle alignment | Good | Finding 5 resolved and checked by running the selector on each of the 72 in-scope tracked `.md` files: 41 print `ALL` today, all under `.agent/` (28 knowledge, 7 templates, 4 top-level guides, 1 instructions, 1 workflows); none under `.claude/`, `AGENTS.md` or `.github/`. Finding 6 resolved and checked: `worktree_create.sh:348` builds `.agent/workflows/${WORKFLOW}.md` at runtime, and no suite passes `--workflow`. |
| ADR compliance | Good | ADR-0013, ADR-0017 (no design change), ADR-0005 (CI backstop) as in round 1. |
| ROS conventions | N/A | Workspace plan. |

### Findings

None. All seven round-1 findings are resolved in the plan and the claims they depend on hold on this branch.

### Summary

The revised plan is ready for implementation. Acceptance case 2 now names a script that exists here and its "same as the script alone" criterion holds on the real tree; the scan-free synthetic fixture makes the doc-only case testable exactly.

### Recommended Actions

- [ ] None before implementation. At PR open, the host edits the issue's acceptance bullet to name `sitrep_checks.sh`, as the plan states.

## Checkpoint
**Status**: complete
**When**: 2026-11-09 12:08 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (plan review round 2 approved with no findings; every claim was checked on the branch by the reviewer)
**After**: plan
**Decision**: proceed

Host answer under /orchestrator's checkpoint table. The host edits the issue's acceptance command 2 to name sitrep_checks.sh when the PR opens.

## Implementation
**Status**: complete
**When**: 2026-11-09 12:23 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-419 at `946335a0`

- `suites_for_files.sh`: at `if not hits:`, a `.md` file prints "is documentation and reaches no suite" to stderr and falls through to the `# scans:` loop; any other unmapped in-scope file still prints `ALL` ("maps to no suite"). Header full-run bullet and residual-risk paragraph updated (runtime-built doc paths, live example `worktree_create.sh` `.agent/workflows/${WORKFLOW}.md`, no suite exercises `--workflow`).
- `run_script_tests.sh` header and the `validate-script-tests` comment in `.pre-commit-config.yaml` state the exception.
- `test_run_script_tests.sh`: old line 702 rewritten; new fixture `.agent/guide.md` (outside every scan prefix); cases for unmapped `.md` alone and with `beta.sh` (inside and outside a scan prefix), deleted `.md` -> ALL, unmapped `.json` -> ALL, undeclared `lone.sh` -> ALL, `.md` under `tests/` -> ALL, plus both stderr notes. 105 passed, 0 failed.
- `test_script_tests_hook_scope.sh`: real-tree check now expects an unnamed `.agent/knowledge/*.md` to select exactly the required, `# covers: ALL` and scanning suites (derived from `--dump`, so no suite is named) with the documentation note; a runtime-built `.agent/scripts/new_uncovered_$$.sh` still selects ALL; header updated. 263 passed, 0 failed.
- `script_reference.md`: runner row states the exception; new `suites_for_files.sh` row.
- Acceptance on the real tree: `suites_for_files.sh .agent/knowledge/script_reference.md` -> `test_checkpoint_269.sh test_skill_paths.sh` (no ALL); with `.agent/scripts/sitrep_checks.sh` added -> `test_checkpoint_269.sh test_script_tests_hook_scope.sh test_sitrep_checks.sh test_skill_paths.sh`, byte-identical to the script alone (substitute for the issue's `sitrep_root.sh`, which is not on main).
- Branch pre-commit (`.venv/bin/pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP): every hook Passed or no-files Skipped, exit 0; the selector chose ALL (the runner is a full-run trigger), so all 41 suites ran.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-09 12:28 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-419 at `5cd5b140`
**Base**: main
**Depth**: Standard (reason: override-trigger files `.pre-commit-config.yaml` and `.agent/knowledge/script_reference.md`)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 1 | **Ship**: recommended — no must-fix findings; the suggestion can be applied or tracked

Specialists: static analysis (shellcheck --severity=warning on the 4 changed .sh, yamllint on .pre-commit-config.yaml: clean); governance (pass; consequences all done); plan drift (none: files match the plan table, steps 1-6 present; the issue's acceptance bullet 2 edit to `sitrep_checks.sh` is left to the host at PR open, as planned); Claude adversarial (nothing of substance); cross-model Gemini (agy) and Codex (both complete, no issues found).

Verified: test_run_script_tests.sh 105 passed 0 failed; test_script_tests_hook_scope.sh 263 passed 0 failed. Real tree: `suites_for_files.sh .agent/knowledge/script_reference.md` prints test_checkpoint_269.sh + test_skill_paths.sh with "is documentation and reaches no suite"; adding `.agent/scripts/sitrep_checks.sh` selects exactly what the script alone selects; `.agent/scripts/new_uncovered.sh` prints ALL ("maps to no suite"); a new `.claude/skills/<x>/SKILL.md` stays mapped (16 suites); `.MD` and `.json` still give ALL.

### Findings
- [ ] (suggestion) The real-tree expected set (`doc_want`) mirrors the required, `# covers: ALL` and scanning suites but not the selector's fourth joining class, suites with no derived references (absent from `--dump`); none exists today (41 of 41 suites are in the dump), but adding one would fail this check spuriously. Add the suites missing from the dump to `doc_want` and to the header/pass text — `.agent/scripts/tests/test_script_tests_hook_scope.sh:710`

## Checkpoint
**Status**: complete
**When**: 2026-11-09 12:29 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (round 1 approved, Ship recommended, Gemini and Codex clean; the one suggestion guards a test against a suite class that does not exist today, 41 of 41 suites are in the dump, so it is carried to the PR as a noted follow-up rather than a fix round)
**After**: publish
**Decision**: publish

Host answer under /orchestrator's checkpoint table. Push and open the pull request; the host edits the issue's acceptance command 2 to name sitrep_checks.sh.

## Integrated Review
**Status**: complete
**When**: 2026-11-09 12:32 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #422 at `2f0acaa`
**Sources**: 3 (Copilot @ `2f0acaa` — did not review: "unable to review this pull request because the user who requested the review has insufficient remaining quota", 0 inline comments; Local Review (Pre-Push) @ `5cd5b14` (covers `2f0acaa` via bookkeeping); CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

Copilot's review is an outcome line, not a finding: it ran no review (quota), so this PR has no GitHub-side review coverage; its `copilot-pull-request-reviewer` check reports failure for the same reason. CI at triage time: Validate Adapter Contract, Validate Documentation and ros-manifest tests pass; Lint (pre-commit) still running.

The pre-push suggestion is confirmed against the code: `suites_for_files.sh` (the `for s in suites` loop after selection) adds any suite with no closure, no `# covers:` and no `# scans:` to every scoped run as "always (no derived references)"; such a suite has no `--dump` row, so the real-tree check's `doc_want` (required suite + `always` rows + scanners) would omit it and fail spuriously. Latent, not failing: 41 suites on disk, 41 in the dump. Kept open rather than deferred: the fix is a few lines in the test, and the merge waits on the owner either way.

### Findings
- [x] (suggestion, Local Review (Pre-Push) @ `5cd5b14`, covers via bookkeeping) The real-tree expected set (`doc_want`) omits the selector's fourth joining class, suites with no derived references (absent from `--dump`); none exists today (41 of 41 suites in the dump), but adding one would fail this check spuriously. Add the test_*.sh suites missing from the dump to `doc_want` and to the pass/fail text — `.agent/scripts/tests/test_script_tests_hook_scope.sh`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-09 12:32 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: host (one open suggestion box, a few lines in test_script_tests_hook_scope.sh so its expected set includes suites absent from --dump; Copilot did not run on this PR (quota), so the branch has only the pre-push Gemini and Codex coverage; fixing it costs one small round and merging past an open box is the owner's answer only, so address)
**After**: findings
**Decision**: address

Host answer under /orchestrator's checkpoint table. The open box of the Integrated Review at feb72bbc goes to address-findings.

## Implementation
**Status**: complete
**When**: 2026-11-09 12:44 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #422 at `632c5f7`
**Addressed**: Integrated Review at `2f0acaa` (2026-11-09 12:32 -05:00)
**Commits**: 632c5f7

### Actions
- [x] The real-tree unmapped-document check's expected set (`doc_want`) now adds the suites on disk with no `--dump` row (the selector's "always (no derived references)" class); header and pass/fail text name that class; no further suite is named — `.agent/scripts/tests/test_script_tests_hook_scope.sh:712`

### Verification
- `test_script_tests_hook_scope.sh`: 263 passed, 0 failed on the real tree.
- Throwaway probe (an unreferenced `test_*.sh` placed on disk, removed after): the unmapped-document check passed with the probe in its expected set; only check (a) failed, as designed.
- `test_run_script_tests.sh` not touched, so not run on its own; it ran inside the full hook run below.
- `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP: every hook passed, including the script-suite hook.

## Local Review
**Status**: complete
**When**: 2026-11-09 12:45 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved
**Dispatch**: resumed (agent a99c63f450f5114b1, resume 1 of 3)

**PR**: #422 at `e3b74369`
**Depth**: Standard (reason: narrow convergence check of the round-1 suggestion and fix commit 632c5f71, per handoff; whole diff unchanged otherwise)
**Must-fix**: 0 | **Suggestions**: 1

Scope: the one open box of the Integrated Review at feb72bbc and the fix diff 632c5f71. Cross-model: skipped (convergence check, per handoff). The round-1 suggestion is resolved: `doc_unreferenced` takes every on-disk suite with no `--dump` row, using the same `grep -qP` test as drift check (a), and joins it into `doc_want`; no suite name is written into the test. Verified: test_script_tests_hook_scope.sh 263 passed, 0 failed on the real tree; shellcheck --severity=warning clean. CI at e3b74369: Validate Documentation and ros-manifest tests pass; Lint (pre-commit) and Validate Adapter Contract still pending when read. Copilot did not review (quota).

### Findings
- [ ] (suggestion) The file-top summary still says an unnamed Markdown document "runs only the required, '# covers: ALL' and scanning suites"; add "and unreferenced" to match the check comment and pass text — `.agent/scripts/tests/test_script_tests_hook_scope.sh:74`

## Integrated Review
**Status**: complete
**When**: 2026-11-09 12:46 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent aba630c34fe2c05e6, resume 1 of 3)

**PR**: #422 at `9e3a44d`
**Sources**: 3 (Copilot @ `2f0acaa`, `6684ded`, `e3b7436`: all three are the quota notice "unable to review this pull request because the user who requested the review has insufficient remaining quota", 0 inline comments, so not a review source; Local Review @ `e3b7436` (covers `9e3a44d` via bookkeeping); CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

The box left open in the previous Integrated Review (at `2f0acaa`) is closed by commit 632c5f7, checked against the code. `doc_unreferenced` collects every `test_*.sh` in `ALL_SUITES` (line 549) that has no `--dump` row, and `doc_want` now includes them, so it matches the selector's "always (no derived references)" class. The comment above the check and the pass/fail text name that class, and no suite name is written into the test. The pre-push entry at `5cd5b14` is now stale (the test file changed since), and its one finding was ruled on and fixed through that Integrated Review.

The new suggestion holds. Lines 74-75 of `test_script_tests_hook_scope.sh` still say a Markdown document no code names "runs only the required, '# covers: ALL' and scanning suites", which disagrees with the check's own comment and pass text. It changes a comment only, with no behaviour or test outcome affected. **It does not block a merge call; the owner may defer it.** It is still kept as an open box rather than deferred, because the fix is a single wording change that can go in the same commit as any other change.

CI at `9e3a44d` when this entry was written: Validate Documentation passes. Lint (pre-commit), Validate Adapter Contract and ros-manifest tests were still pending. Earlier heads passed those last two.

### Findings
- [x] (suggestion, non-blocking, Local Review @ `e3b7436`, covers via bookkeeping) The file-top summary still says an unnamed Markdown document "runs only the required, '# covers: ALL' and scanning suites"; make it "required, '# covers: ALL', scanning and unreferenced suites" to match the check comment and pass text — `.agent/scripts/tests/test_script_tests_hook_scope.sh`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-09 13:15 -05:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: findings
**Decision**: address

Owner's answer: "address 422". The one open box of the Integrated Review at 1a28c8ce (the file summary at test_script_tests_hook_scope.sh:74-75 lists three suite classes where the check covers four) goes to address-findings.
