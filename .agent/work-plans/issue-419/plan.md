# Plan: Pre-commit suite selector: a documentation file under .agent/ runs every suite because it maps to no suite

## Issue

https://github.com/rolker/agent_workspace/issues/419

## Context

`suites_for_files.sh` prints `ALL` ("maps to no suite", `run_all` in `main()`, after the `if not hits:` test) for any in-scope changed file that no suite references or declares. The hook's `files:` admits all of `.agent/`, so an unreferenced `.agent/knowledge/*.md` edit runs every suite (about 12 minutes) for no coverage gained. The issue review (2026-11-09) narrowed "documentation" to Markdown. Four places state or pin the old rule and must change with it: the selector header, the stderr note, the `.pre-commit-config.yaml` comment, the `script_reference.md` runner row, and two tests (`test_run_script_tests.sh:702` and the real-tree check at `test_script_tests_hook_scope.sh` ~689-711, which the review did not list).

## Approach

1. **Selector: a `.md` file that reaches no suite is documentation, not an undeclared file.** In `suites_for_files.sh` `main()`, at `if not hits:` (the only change to the rule): if `f` ends in `.md`, note `f"{f} is documentation and reaches no suite"` and fall through instead of `run_all`; any other extension still `run_all("... maps to no suite")`.

   **Breadth, on record.** The rule covers every in-scope `.md` (`.claude/`, `AGENTS.md`, `.github/PULL_REQUEST_TEMPLATE.md`), wider than the issue's "under `.agent/`". This follows the Issue Review's recommendation and is safe today: every `.claude/` Markdown file is already mapped (SKILL.md files by basename through scripts that name `SKILL.md`), so the 41 unmapped `.md` files are all under `.agent/` (28 knowledge, 7 templates, 4 top-level guides, 1 instructions, 1 workflows). No allowlist: the test is the file's own extension, decided per changed file from the passed list (tracked-list evidence from the review: 72 in-scope `.md`, 41 unmapped, all under `.agent/`; `.json/.yml/.conf/.example/.txt/.cpp` stay unmapped-triggers because suites may parse them and no evidence says otherwise). Everything before that point is untouched, so these still apply to a `.md` first: out-of-scope file, fixed triggers, `_*.sh` helpers, and the `under tests/` rule (a `.md` beside the suites that is not an exact `# covers:` file stays `ALL`). A deleted `.md` still yields `ALL` through the runner's `--deleted` path: pre-commit never passes it and a suite may still name the old path; the issue allows this.
2. **A referenced doc stays mapped.** `hits` is computed before the new branch, so a doc named by derivation or `# covers:` still selects its suites; only the empty-`hits` case changes. A doc under a `# scans:` prefix still adds the scanning suites (the `scans` loop is unchanged) but was never a mapping; it now simply does not escalate. Acceptance case 2, as written in the issue, names `.agent/scripts/sitrep_root.sh`, which exists only on the open sit-rep branch (PR 420), not on `main` or this branch; there it prints `ALL` whatever the fix does. The plan substitutes a mapped script that exists on `main`, `.agent/scripts/sitrep_checks.sh` (today it selects `test_checkpoint_269.sh test_script_tests_hook_scope.sh test_sitrep_checks.sh test_skill_paths.sh`), and the criterion becomes: `suites_for_files.sh .agent/knowledge/script_reference.md .agent/scripts/sitrep_checks.sh` selects exactly what `suites_for_files.sh .agent/scripts/sitrep_checks.sh` alone selects. This holds on the real tree only because `script_reference.md` is under `test_skill_paths.sh`'s `# scans: .agent/` prefix, which the script alone already selects; the plan records that. The host edits the issue's acceptance bullet to match when the PR opens. Acceptance case 1 (a doc alone) prints no `ALL`; on the real tree it still gains the scanning suite(s), so "no `ALL`" is the real-tree criterion. "A doc-only change selects no extra suite" can hold only outside every scan prefix, so it is pinned in the synthetic repo (step 4) with a fixture outside all prefixes. Tests assert exact sets.
3. **Header and comments.** `suites_for_files.sh` header: replace the "an in-scope changed file maps to no suite" bullet with "a non-Markdown in-scope changed file maps to no suite (a `.md` that reaches no suite is documentation and only adds its `# scans:` suites)"; add a Residual-risk sentence: a suite that reads a doc through a path built at runtime stays invisible, as for code, so a doc edit that such a suite would catch is not run until CI's all-files run; CI is the backstop, and the drift check covers `ROOT_READERS` only. Name the live example: `worktree_create.sh:348` builds `.agent/workflows/${WORKFLOW}.md` at runtime; `collaborative.md` is unmapped and no suite exercises `--workflow`, so nothing is lost today. `run_script_tests.sh` header (lines ~33-34, "an in-scope file no suite maps") gets the same exception. `.pre-commit-config.yaml` comment above `validate-script-tests`: add "a documentation file no suite reads does not run them all". That edit is itself a full-run trigger.
4. **Tests, synthetic repo in `test_run_script_tests.sh`.** The synthetic hook scope is `.agent/`, so `.agent/docs/unmapped.md` exists (and `scanned.md`, referenced by `other.sh`); `unmapped.md` sits under `test_scanner.sh`'s `# scans: .agent/docs/`. Passed paths join the vocabulary, so the `.json`, `tests/notes.md` and `lone.sh` cases need no tracked fixtures and `make_syn_repo` changes only for the one doc fixture below. Changes:
   - (a) Rewrite line 702 to `expect_sel "an unmapped .md is documentation: no ALL, only the scanning suite joins" "$BASE_ALWAYS test_noref.sh test_scanner.sh" -- .agent/docs/unmapped.md` (BASE_ALWAYS = `test_always.sh test_checkpoint_269.sh`).
   - (b) Add a doc fixture outside every scan prefix, `.agent/guide.md` (add to `make_syn_repo`; verify no `# scans:` line covers `.agent/` itself). Pin: the doc alone gives exactly `$BASE_ALWAYS test_noref.sh` (the issue's "doc-only change selects no extra suite; the runner's required suite still joins"); the doc plus `.agent/scripts/beta.sh` gives exactly beta's set, equal to `beta.sh` alone. Separately, `unmapped.md` plus `beta.sh` gives beta's set plus `test_scanner.sh`.
   - (c) Deleted `.md` still `ALL`: `--deleted .agent/docs/gone.md -- .agent/scripts/beta.sh`.
   - (d) Unmapped `.json` still `ALL`: pass `.agent/docs/unmapped.json` (untracked path).
   - (e) A referenced doc (`scanned.md`) still selects `test_other.sh` (existing line 691 pins this; relabel only if needed).
   - (f) Undeclared `.sh` still `ALL`: no existing case passes `lone.sh` (it appears only in the deleted-path case), so add `expect_sel "an undeclared script yields ALL" "ALL" -- .agent/scripts/lone.sh`, with the "maps to no suite" stderr.
   - (g) A `.md` under `tests/` not declared still `ALL`: pass `.agent/scripts/tests/notes.md`.
   - The new stderr note is asserted by capturing stderr of one call and matching `documentation`.
5. **Tests, real tree in `test_script_tests_hook_scope.sh` ~689-711.** The check picks a tracked `.agent/knowledge/*.md` unnamed by any non-Markdown file and asserts `ALL` with "maps to no suite"; this now fails by design. Change it to assert: no `ALL`, stderr says documentation, output contains `test_checkpoint_269.sh` and `test_skill_paths.sh` (real scans prefix). Also assert the non-Markdown side on the real tree: pass `.agent/scripts/new_uncovered_$$.sh`, built at runtime in the suite (a literal path in the suite's own text counts as a reference and would map it to that suite, turning the expected `ALL` into a selection), and expect `ALL` with "maps to no suite". Update the suite's header (~line 73, "a file no code names runs everything") and the comment above the rewritten check (~689), which describe the old rule. The full-run pin at ~664 (all in-scope files select `ALL`) stays true because the list includes `.sh` and fixed triggers; verify by running it.
6. **`script_reference.md`.** Runner row (line 51): "an in-scope file no suite maps" becomes "an in-scope file no suite maps, other than a Markdown document, which only adds its scanning suites". Selector row: the review says "if its description changes"; grep found no `suites_for_files.sh` row, so add one (the header says it is a script in `.agent/scripts/tests/` and the file is documented as covering every script) with the documentation rule. Verify the row format against neighbouring rows before writing.
7. **Verification at the final pass.** Run the changed suites directly (`test_run_script_tests.sh`, `test_script_tests_hook_scope.sh`), the acceptance commands on the real tree (case 2 with `sitrep_checks.sh`, comparing doc plus script against the script alone), then the branch pre-commit once with no SKIP (the changed selector and runner make this a full run, expected per the review).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/tests/suites_for_files.sh` | `.md` exemption at `if not hits:`; stderr note; header full-run list and residual risk |
| `.agent/scripts/tests/run_script_tests.sh` | header comment lists the exception (comment only) |
| `.pre-commit-config.yaml` | one comment sentence |
| `.agent/scripts/tests/test_run_script_tests.sh` | rewrite line 702; fixture `.agent/guide.md` (outside every scan prefix); new cases (b)-(g) |
| `.agent/scripts/tests/test_script_tests_hook_scope.sh` | rewrite real-tree unmapped-file check (~689-711); add runtime-built `new_uncovered` `ALL` case; update header (~73) and check comment (~689) |
| `.agent/knowledge/script_reference.md` | runner row; selector row |

## Prior Art

The selector already has `is_code` (code = `.sh`, `.py`, or an extensionless `#!` file) and treats documents as closure leaves, so the idea that documents are not code is already in the file. It is not reused as the test: `not is_code` would cover `.json/.yml/.conf/.example/.txt`, which suites may parse (review finding). Rejected: a hand-kept allowlist of doc paths (the issue forbids it); widening the hook's `files:` pattern (out of scope, shared with other hooks); unscoped doc exemption inside `.agent/scripts/tests/` (kept as `ALL` by the existing rule). Taken from issue-410: derive from the tracked list, fail safe on doubt.

## Serves

Goal "Easy to use" (`README.md#workspace-goals`; a doc edit does not cost a 12-minute run), under `docs/design.md#registry-and-adapters` (the `test` verb row naming the runner as the hook and test-gate entry).

## Design Picture

No change to the design picture. `docs/design.md` has no statement that an unmapped file runs everything (grep for `unmapped`/`no suite` finds only the unrelated role-mapping text at line 131); line 389 only names the runner as the `test` verb's entry.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | One extension test at one branch; no new mechanism or list |
| Enforce what matters, as simply as possible | Code and config still fail safe to `ALL`; only Markdown, which no suite reads without a visible reference, is relaxed |
| Test what breaks | Both tests that pinned the old rule are rewritten; new cases pin each side of the line (doc outside every scan prefix, deleted `.md`, `.json`, referenced doc, `.sh`, `.md` under `tests/`) |
| A change includes its consequences | Header, stderr note, config comment, both reference rows, runner header all in the same PR |
| Verify before claiming | Acceptance outputs are run on the real tree and the exact set recorded in the PR |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | Yes | Plan Authored entry in `progress.md` |
| ADR-0017 | No | No design-picture change; `docs/design.md` checked |
| ADR-0005 | Yes (light) | CI all-files run remains the backstop for the residual risk |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Selector rule | Selector header, stderr note, runner header | Yes |
| Selector rule | `.pre-commit-config.yaml` comment, `script_reference.md` rows | Yes |
| Selector rule | `test_run_script_tests.sh:702`, `test_script_tests_hook_scope.sh` ~689-711, its header (~73) and check comment | Yes |
| Editing selector/runner/config | Full-run trigger on this branch | Expected; one full run at the final pass |

## Open Questions

None for the owner. Residual risk, stated in the header: a suite that builds a doc path at runtime is invisible to the derivation, so a doc edit it would catch waits for CI's all-files run. Listed for veto: the rule covers all in-scope `.md`, not only `.agent/` (step 1); `.md` only (not `.txt`/`.json`/`.yml`); deleted `.md` keeps `ALL`; `.md` under `tests/` keeps `ALL`.

## Estimated Scope

Single PR.
