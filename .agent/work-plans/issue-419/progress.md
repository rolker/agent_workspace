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
