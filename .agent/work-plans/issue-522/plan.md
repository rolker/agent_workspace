# Plan: run-issue step 11's merge command is refused for a package pull request

## Issue

https://github.com/rolker/agent_workspace/issues/522

## Context

`merge_pr.sh` derives the repo kind from `--repo` and exits 2 on a `--type` that differs (the refusal is deliberate and pinned for `--type workspace` by `test_repo_conflicting_type_rejected`). `run-issue` tells a project session to pass `--project` "wherever this skill passes `--type`", `merge_pr.sh` included, so a package merge followed literally becomes `--pr <owner/repo#M> --type project --project <project>`, which is refused. The host has decided: the skill changes, not the script.

## Approach

1. **Skill, step 11 (`.claude/skills/run-issue/SKILL.md`, near line 1025).** Replace "then run `$WS_ROOT/.agent/scripts/merge_pr.sh --pr <M> --type <type>`, or `--pr <owner/repo#M>` for a package issue, so the script targets the package repository and finds the package worktree." with:
   "then run `$WS_ROOT/.agent/scripts/merge_pr.sh --pr <M> --type <type>` for a workspace or single-repository issue (with `--project <project>` when the session's `project=` is not empty). For a package issue run `$WS_ROOT/.agent/scripts/merge_pr.sh --pr <owner/repo#M>`, with `--project <project>` when the session's `project=` is not empty, and never `--type`: the script derives the kind from the repository and refuses a `--type` that differs, so the call targets the package repository and finds the package worktree."
2. **Skill, lines 51-55.** Replace "pass `--project <project>` wherever this skill passes `--type <type>` (start-task's arguments, every `dispatch_phase.sh` call and `merge_pr.sh`), so every script resolves the same project the check did." with:
   "pass `--project <project>` wherever this skill passes `--type <type>` (start-task's arguments, every `dispatch_phase.sh` call and a workspace or single-repository issue's `merge_pr.sh`), so every script resolves the same project the check did. A package issue's `merge_pr.sh` passes no `--type` (step 11); it passes `--project <project>` whenever `project=` is not empty."
3. **Skill, usage line near 155.** Replace "and `merge_pr.sh --type` at merge, with `--project` for a project root." with:
   "and `merge_pr.sh --type` at merge, with `--project` for a project root; a package issue's merge passes `--pr <owner/repo#M>` and `--project` (when `project=` is not empty) and no `--type`."
4. **`test_skill_paths.sh` pin.** After the existing `has "$RI" ...` lines (the suite's `has` joins wrapped lines and checks fixed strings), add one `has "$RI" "run-issue: a package issue's merge passes --pr <owner/repo#M> and --project, never --type"` with these fixed texts: `For a package issue run `$WS_ROOT/.agent/scripts/merge_pr.sh --pr <owner/repo#M>`, with `--project <project>` when the session's `project=` is not empty, and never `--type``, `A package issue's `merge_pr.sh` passes no `--type` (step 11)`, and `a package issue's merge passes `--pr <owner/repo#M>` and `--project` (when `project=` is not empty) and no `--type``. Run it against the unchanged skill first to see it fail.
5. **`test_merge_pr.sh` case.** Already pinned: `test_repo_conflicting_type_rejected` (`--type workspace` against a package repo is refused, exit 2, nothing merged) and `test_same_repo_under_two_instances_requires_project` (a qualified package `--pr` with `--project inst2` merges, exit 0, removes only that instance's worktree). Missing: `--type project` against a package repo, the exact form the skill produced. Add `test_repo_type_project_rejected_for_package_repo` (new function plus its call line in the run list), modelled on `test_repo_conflicting_type_rejected`: `--pr owner/pkg_a#561 --type project --project <registered name>` exits 2, the message contains "conflicts with --repo owner/pkg_a", and no `pr merge` call is logged. The implementer checks that the sandbox registers a project name for `--project`; if not, uses the sandbox's own registration helper rather than adding a second acceptance case. No acceptance case is added: the two-instances test already covers it.
6. **Other texts checked.** `.claude/skills/orchestrator/SKILL.md`, `.agent/WORKTREE_GUIDE.md` (lines 327-334 already give `--pr acme/sonar_msgs#57` with no `--type`) and `.agent/knowledge/script_reference.md` (describes the package path with no command line) carry no wrong form: no change. `docs/design.md` line 529 (the run-issue row) says `merge_pr.sh --type` without the package exception: append "(a package pull request passes `--pr <owner/repo#M>`, no `--type`)". The Design Picture is unchanged by this: it is a call-form note in a table.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/run-issue/SKILL.md` | Steps 1-3 above |
| `.agent/scripts/tests/test_skill_paths.sh` | One `has` pin for the package form |
| `.agent/scripts/tests/test_merge_pr.sh` | `--type project` against a package repo is refused |
| `docs/design.md` | Line 529 row gains the package exception |

## Prior Art

`merge_pr.sh`'s own usage header and `.agent/WORKTREE_GUIDE.md` already give the package form without `--type`; the skill is brought into line with them. `test_repo_conflicting_type_rejected` is the model for the new case. Rejected: letting the script accept `--type project` for a package repo, which would give the flag two meanings and weaken the guard that sends cleanup at the right checkout.

## Serves

Quality of the work: `docs/design.md#merge-gate`.

## Design Picture

No change to the design picture; the `docs/design.md` row at line 529 is a wording correction.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Enforcement over documentation | The skill text is pinned in `test_skill_paths.sh`; the script's refusal of `--type project` is pinned in `test_merge_pr.sh`. |
| Verify before claiming | Each sentence above was checked against `merge_pr.sh` lines 434-455 and 644-646 by the issue review. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0012 | Yes | The fix follows its "kind derived from the repository" rule. |
| ADR-0016 | No | No user-tier change. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Step 11's merge command | The `--project` sentence and the usage line in the same skill | Yes |
| The skill text | `test_skill_paths.sh` pin | Yes |
| The skill's `--type` wording | `docs/design.md` line 529 | Yes |

## Open Questions

None.

## Estimated Scope

Single PR, four files.
