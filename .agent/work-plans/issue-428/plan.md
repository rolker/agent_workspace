# Plan: Loop defects from the GeoZui4D drives (#428)

## Issue

https://github.com/rolker/agent_workspace/issues/428

## Context

Five small loop defects. Main has moved since the issue was written (Issue Review, db67719d; Checkpoint, 6a9d00e4). Items 1, 3 and 4 are the work, each with a script test. Item 2 is already fixed in code (workflow-count check in `merge_pr.sh`); this plan finds the path that still steers to `--no-wait` and changes one message. Item 5 is skill text today; this plan says no script check is worth adding. Not folded in: #362, #431, #521. The issue body is not edited.

## Approach

1. **Item 1: the rule goes into text the host reads when writing a handoff, and into the handoff itself.**
   - `dispatch_phase.sh` `cmd_handoff`: add one sentence to the `conventions=` line for every phase: a parallel build or test command always names its job count, for example `-j 4` or `--parallel 4`, never a bare `-j` or `--parallel`; this holds for text copied from an issue or plan too. Every phase's handoff then carries the rule, which is the "point of writing a handoff" the acceptance asks for.
   - `.claude/skills/run-issue/SKILL.md`: one paragraph in the dispatch handoff section (near the existing `conventions=` paragraph, around line 473) stating the rule and that the host checks text it copies into a handoff.
   - `.agent/knowledge/host_standing_rules.md` (read by the orchestrator at start): one row with the reason (an OOM-killed compiler took the session down). The orchestrator skill points at that file, so it needs no edit; this keeps #431 item 11 from becoming a second edit to the orchestrator skill. Cross-reference #431 in the PR text.
   - Test in `test_dispatch_phase.sh`: the handoff of each phase type (implement, plan-task, review-code at least) contains the rule sentence, and that sentence contains no bare `-j`/`--parallel` example.
   - **Guard in `dispatch_phase.sh`: not added.** Reason: the script prints the handoff; the host writes the text that carries the flag, and the script never sees it (the handoff is pasted into the Agent tool, outside any script). A guard could only scan `--prompt-file` or the issue body, which are not where the bare flag came from in the GeoZui4D run (an implement agent's own command, copied from issue text). A check that cannot see the failure costs a code path and a test and catches nothing. Cheap backstop kept instead: the test above, plus a one-time grep of this repo's own text, which today finds no bare `-j`/`--parallel` outside the test runner's `-j N` (verified at plan time).
2. **Item 2: one message change in `merge_pr.sh`, no logic change.**
   - Paths to the `--no-wait` advice, from the code at `merge_pr.sh` ~1880-2100: with a readable workflow count of 0 and no pending review the result is `no-ci` and nothing waits (already tested, `test_merge_pr_gate.sh`). The 120 s wait plus the `--no-wait` demand is reached through `never-registered` when the count is `unknown` or non-zero, and through `failed`/`api-error`.
   - The path the GeoZui4D run most plausibly took: an `unknown` count. `PR_REPO_SLUG` is empty when `origin` is not a github.com URL, so the request is `repos//actions/workflows`, which fails; the count is `unknown`; after the grace period the message says "excluded by workflow path filters, re-run with `--no-wait`". That reason is wrong for this case, and it hands the host a mechanism-only reason to ask the owner for a relaxing flag. (The run's actual remote is unrecorded; this is the one reproducible route and the plan says so.)
   - Change: in the `never-registered` branch, when `_ci_wf_count` is `unknown`, print that the workflow list could not be read (name the repository slug used, say when it is empty, and that the remote may not be github.com) instead of the path-filter reason; keep the path-filter text for a non-zero count. `--no-wait` stays an owner-granted flag and neither message offers it as the mechanism fix for an unreadable count.
   - `failed` and `api-error` advice is unchanged: they name real, non-mechanism causes (a failing check, an unreachable API), and the "or pass --no-wait" tail is the existing, tested wording. Recorded as the reason not to touch them.
   - Test in `test_merge_pr_gate.sh`: workflow API fixture returning an error with no checks: the stderr contains the unreadable-list text and not the path-filter text; and a non-zero count with no checks still gives the path-filter text. Uses the existing sandbox helpers (`write_workflows`, `write_api_exit`).
3. **Item 3: make the tree writable before removal, in `worktree_remove.sh`.**
   - In the removal loop (~lines 455-473), run `chmod -R u+w "$_dest"` before each `git worktree remove` (both the `--force` and plain call), and `chmod -R u+w "$WORKTREE_DIR"` before the final `rm -rf` (covers the aggregate dir of a package worktree). `git worktree remove` fails on unwritable subdirectories before the `rm -rf` is reached, so the chmod must precede it. The chmod covers only the worktree being removed; never its parent.
   - A failed chmod does not hide the later removal error (`|| true` on the chmod only; the removal's own exit status stands).
   - The dirty-check section above the loop is unchanged, so removal of a dirty tree is still refused without `--force`.
   - New suite `.agent/scripts/tests/test_worktree_remove.sh` (name maps to the script for the hook): sandbox worktree with `install/lib` made `chmod a-w` (and a read-only file inside), then `worktree_remove.sh` succeeds and the directory is gone; same with `--force`; and a dirty tree is still refused. Reuse the sandbox helpers from `test_merge_pr_skill.sh`'s `worktree_remove --path` section.
   - Header comment of the script and the `script_reference.md` row (line 21) say the tree is made writable first.
4. **Item 4: github.com-only check in `extract_gh_slug`; do not let `gh` name the repository.**
   - Reason, from the callers (all read): `merge_pr.sh` compares the slug with `--repo` text (lines 442, 444) and builds API paths from it before any network; `worktree_create.sh` (634-704) and `worktree_enter.sh` (323-339) derive it at creation, when `gh` may not be authenticated or a remote may not exist yet; `sitrep_checks.sh` `check_gh_issue` (474) must work offline and returns `unknown` on an empty slug already; `_issue_helpers.sh` (85, 192, 248) call it in the offline-first path (git-bug first). A `gh repo view` call is a network call in each of these and fails exactly where the empty-slug answer is the safe one. The onboarding precedent (2026-10-30, "let gh resolve") was for a step that is already online and already holds the `gh` authority; these callers are not. The empty answer is also what ADR-0022-era text wants: a project may have no hosting service, and nothing here should invent a slug for another host.
   - Change in `_issue_helpers.sh`: classify the input form before stripping. An scp-like `[user@]host:path` or `scheme://[user@][host][:port]/path` URL yields a slug only when host is exactly `github.com` or `www.github.com` (case-insensitive); any other host (including `gitlab.com`, `notgithub.com`, `github.com.evil.example`) yields empty. An absolute or relative local path keeps the current parse, because the test sandboxes use a bare clone under `.../github.com/<owner>/<name>.git` as a fake remote (`test_merge_pr.sh` header comment ~207). The function's header comment states these rules. No `gh` call; the file stays user-tier inert (ADR-0016).
   - Test: new `test_issue_helpers.sh` (none exists) covering `git@github.com:o/r.git`, `https://github.com/o/r`, `ssh://git@github.com/o/r.git`, `https://www.github.com/o/r`; empty for `git@gitlab.com:o/r.git`, `https://example.com/o/r`, `https://notgithub.com/o/r`, `git@github.com.evil.example:o/r`, three-segment paths, and empty input; and the local-path fixture form still yields `o/r`. Plus one `test_sitrep_checks.sh` case: a bare `gh-issue N` with a non-GitHub origin reports `unknown`.
   - Listed for the owner's veto: github.com only; GitHub Enterprise hosts are not supported and give an empty slug.
5. **Item 5: no script check; record the reason.** The `run-issue` text (~line 924) already says a Copilot quota comment is not a review and the host moves on; the wait the issue saw was the host's polling, which that text now covers. A script would have to match free-form quota comment text from a hosted service, and the wording is not a stable contract (a wrong match would end a real review wait early, a miss changes nothing against today). `merge_pr.sh` already holds the merge only on the review check-run, not on a comment. No change; the PR text records this.
6. **Consequence checks:** `script_reference.md` rows for `dispatch_phase.sh` (conventions rule), `worktree_remove.sh`, `merge_pr.sh` (message only: no row change unless it names the path-filter text), and a mention of the new suites if the reference lists suites. Run only touched suites per the hook rule: `test_dispatch_phase.sh`, `test_merge_pr_gate.sh`, `test_merge_pr.sh`, `test_merge_pr_skill.sh`, `test_worktree_remove.sh`, `test_issue_helpers.sh`, `test_sitrep_checks.sh`, `test_worktree_create.sh`, `test_worktree_enter_stderr.sh`, `test_skill_paths.sh`, each on its own with `bash`. Any parallel command in this work names its count, for example `run_script_tests.sh -j 4`.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/dispatch_phase.sh` | job-count rule added to `conventions=` for every phase |
| `.agent/scripts/tests/test_dispatch_phase.sh` | handoff carries the rule |
| `.claude/skills/run-issue/SKILL.md` | rule in the handoff section |
| `.agent/knowledge/host_standing_rules.md` | standing-rule row with its reason |
| `.agent/scripts/merge_pr.sh` | `never-registered` message split on an unreadable workflow count |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | both message cases |
| `.agent/scripts/worktree_remove.sh` | `chmod -R u+w` before `git worktree remove` and the final `rm -rf`; header comment |
| `.agent/scripts/tests/test_worktree_remove.sh` | new: read-only tree, `--force`, dirty tree still refused |
| `.agent/scripts/_issue_helpers.sh` | host check in `extract_gh_slug` |
| `.agent/scripts/tests/test_issue_helpers.sh` | new: accepted and refused forms |
| `.agent/scripts/tests/test_sitrep_checks.sh` | non-GitHub origin case |
| `.agent/knowledge/script_reference.md` | rows for the changed scripts |

## Prior Art

Existing workflow-count check in `merge_pr.sh` (#271, #284) is the reason item 2 needs only a message change. The `test_merge_pr_gate.sh` fixture helpers and the `worktree_remove --path` tests in `test_merge_pr_skill.sh` are reused. The `gh` name-the-repository route (onboarding, 2026-10-30) was weighed for item 4 and rejected for the offline callers above. Nothing new is built beyond the two small suites.

## Serves

Goal: loop reliability (README workspace goals), under `docs/design.md#rules`; "a safeguard has to earn its cost" decides the item 1 guard and the item 5 script check (both declined).

## Design Picture

No change to the design picture.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A fix needs a test | Items 1, 2 (message), 3, 4 each have a script test; items 1-guard and 5 have recorded reasons. |
| Put each thing at the level it applies to | Item 1 sits in the handoff text and the standing rules, where it is read when writing a handoff. |
| A safeguard has to earn its cost | No dispatch guard (cannot see the failure); no quota-text matcher. |
| Ask what, not how | Items 1 guard, 2 and 4 decided from principles and listed for veto. |
| Only what's needed | Item 2 changes one message; `failed`/`api-error` untouched. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0013 | Yes | Plan Authored entry. |
| ADR-0016 | Yes | `_issue_helpers.sh` stays inert: no `gh` call, no repo-affecting action. |
| ADR-0022 | No | No part-level design. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `dispatch_phase.sh` `conventions=` | handoff text in `run-issue`, `script_reference.md` | Yes |
| `extract_gh_slug` | fake-remote fixtures in tests that rely on the local-path form | Yes (local paths keep working; verified by running the callers' suites) |
| `worktree_remove.sh` | `script_reference.md` row, header comment | Yes |
| `merge_pr.sh` message | any test matching the old path-filter text | Yes (grep before editing) |

## Open Questions

- None about the goal. Listed for veto: no `dispatch_phase.sh` guard; item 4 github.com-only (no GitHub Enterprise); item 5 left as skill text.
- The GeoZui4D run's actual remote and workflow state are unrecorded, so item 2's path is the reproducible one, not a confirmed match.

## Estimated Scope

Single PR.
