# Plan: Pre-commit script-test hook: run only the suites whose declared files changed

## Issue

https://github.com/rolker/agent_workspace/issues/410

## Context

The `validate-script-tests` hook runs all 39 suites (about 7 minutes). Owner: "optimise for wall-clock, not tokens"; he measured the full run as roughly a third of each 25 to 30 minute fix pass. The issue assumes `test_script_tests_hook_scope.sh` already declares, per suite, the files it reads. It does not: it declares 5 `ROOT_READERS` entries (suites that derive a real repo root) and lists the out-of-tree path prefixes they read, never the script under test. The suite-to-file map has to be built.

Measured here (one run each, 2026-10-29): `test_register_project.sh` 94.8 s, `test_project_registry.sh` 18.1 s, `test_merge_pr.sh` 14.2 s. No helper is sourced by every suite; the 11 `.agent/scripts/_*.sh` helpers are each referenced by 1 to 14 suites.

## Approach

1. **Derive the map, do not hand-write it.** New `.agent/scripts/tests/suites_for_files.sh` (not a `test_*.sh`, so the runner's glob ignores it). For each suite it collects every tracked path whose repo-relative path or basename appears in the suite text (`git ls-files` is the vocabulary), then takes the transitive closure over those scripts' own text (so `merge_pr.sh` pulls in what it calls). Over-inclusion is fine; it only runs a suite too often.
2. **Declarations only for what text cannot show.** A suite that builds paths from variables (skill loops, manifest-driven reads) adds a `# covers: <prefix>` header line. The 5 existing `ROOT_READERS` prefixes are folded in automatically. `# covers: ALL` marks a suite that must always run.
3. **Fail-safe: when in doubt, run everything.** `suites_for_files.sh` prints `ALL` if: no files were passed (`make lint`, CI `--all-files`); any changed file is a full-run trigger (the runner, `suites_for_files.sh`, anything under `tests/` that is not a `test_*.sh`, `.pre-commit-config.yaml`, `Makefile`, `set_git_identity_env.sh`, and every `.agent/scripts/_*.sh` helper); a changed file inside the hook's `files:` scope maps to no suite; a suite derives no references and has no `covers:` line; or the script errors. Only a changed file that maps to named suites narrows the run.
4. **Pass the files in.** Hook becomes `pass_filenames: true` with `require_serial: true` (pre-commit otherwise splits the list across parallel processes, and each would run a different subset). The runner accepts `--files <f>...`; with none it runs everything as today. Over 200 files it also runs everything. The runner prints which suites it chose and why.
5. **Enforced drift check** in `test_script_tests_hook_scope.sh` (or a sibling suite): (a) every suite has a non-empty derived set or a `covers:` line; (b) every `ROOT_READERS` suite's declared prefix appears in the derived map; (c) the shell-injected `# covers:` prefixes exist in `git ls-files`; (d) the existing check that a root-reading suite without a declaration fails is kept unchanged. Residual risk, stated: a path assembled entirely at runtime from variables with no literal name anywhere is invisible to text derivation; it is caught only through (b) for real-root readers.
6. **Helper rule test.** `test_run_script_tests.sh` gains cases that iterate the glob `.agent/scripts/_*.sh` (currently `_agy_review`, `_bookkeeping`, `_cli_review`, `_issue_helpers`, `_progress_entry`, `_project_registry`, `_real_case_path`, `_resolve_default_branch`, `_resolve_work_plans_dir`, `_settings`, `_worktree_helpers`) and assert each yields `ALL`; a new helper is covered by the glob with no edit. Further cases: single script maps to a strict subset (a synthetic scripts dir); unmapped in-scope file yields `ALL`; no files yields `ALL`; suite without references yields `ALL`; each trigger in step 3 yields `ALL`.
7. **CI unchanged.** `pre-commit run --all-files` passes the whole tracked list, which contains the runner and so yields `ALL`; a runner test also asserts the no-argument and all-files-shaped calls run all 39. CI narrowing is not planned here. If wanted later it is a separate owner decision (it changes the Rules row `docs/design.md#rules`).
8. **Update wording** in the runner header, the `.pre-commit-config.yaml` comment block, and the #399 text ("final no-SKIP run over `git diff --name-only main...HEAD`" now runs the branch's suites).
9. **Measure after building** on two real fix commits (a `merge_pr.sh` change, a `register_project.sh` change) and record the numbers in the PR.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/tests/suites_for_files.sh` (new, `chmod +x`) | Derive suite set for a file list; prints suite names or `ALL` |
| `.agent/scripts/tests/run_script_tests.sh` | `--files` mode, choice logging, header comment |
| `.pre-commit-config.yaml` | `pass_filenames: true`, `require_serial: true`, comment block |
| `.agent/scripts/tests/test_script_tests_hook_scope.sh` | Drift checks in step 5 |
| `.agent/scripts/tests/test_run_script_tests.sh` | Scoped-mode and helper-rule cases |
| `# covers:` lines in a few suites | Only where text derivation cannot see the reads |

## Prior Art

The existing `ROOT_READERS` declaration and the regex check in `test_script_tests_hook_scope.sh` are kept and extended. A fully hand-written suite-to-file table was rejected: it is the drift risk the issue review flagged. `strace`-based read tracing was rejected for the hook (slow, needs privileges); it could be an occasional audit.

## Serves

Quality of the work and review-loop wall-clock (README Workspace goals); `docs/design.md#rules` and `docs/design.md#review-loop-and-timeline`.

## Design Picture

No change to the design picture, as CI keeps running every hook on all files.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforce what matters, as simply as possible | Map derived from text, one enforced drift check, default is "run it" |
| Verify before claiming | Timings above measured; post-build timings recorded in the PR |
| Only what's needed | No CI narrowing; no new tooling |
| Keep one current design | Rules row on CI unchanged |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | No | progress.md vocabulary suites keep their own triggers |
| ADR-0011 | No | Adapter not touched |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Runner usage | Runner header, hook comment block, #399 wording | Yes |
| Hook `files:` / `pass_filenames` | Scope test parses the block | Yes (step 5) |
| New helper `_*.sh` | Glob test covers it | Yes |

## Open Questions

- Acceptance says "under a minute for a typical fix commit". `test_register_project.sh` alone takes about 95 s, so a `register_project.sh` fix cannot meet that; a `merge_pr.sh` fix (about 14 s plus related suites) probably can. Accept as stated, or also speed up that suite (separate issue)?
- Any edit to a `_*.sh` helper runs the full 7 minutes (the requirement as given). If helper edits are common in fix passes, a later refinement could map helpers to their referencing suites; not planned.

## Estimated Scope

Single PR.
