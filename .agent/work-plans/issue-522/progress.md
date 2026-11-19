---
issue: 522
---

# Issue #522 — run-issue step 11's merge command is refused for a package pull request

## Issue Review
**Status**: complete
**When**: 2026-11-19 14:40 -05:00
**By**: Claude Code (claude-sonnet-5-5)

**Issue**: #522

### Scope Assessment

**Well-scoped?** Yes. The claim checks out: `merge_pr.sh` derives the repo kind from `--repo` (a repo that is neither the workspace's nor the resolved project's remote is `package`) and exits 2 on a `--type` that differs (`merge_pr.sh` lines 442-453, message "Drop --type; it is derived from --repo"). Step 11 of `run-issue` reads `merge_pr.sh --pr <M> --type <type>`, "or `--pr <owner/repo#M>` for a package issue", and the earlier paragraph (lines 51-55) says to pass `--project <project>` wherever the skill passes `--type <type>`, `merge_pr.sh` included. Line 155 repeats "`merge_pr.sh --type` at merge, with `--project` for a project root". Followed literally for a package issue in a project session, that gives `--pr <owner>/<repo>#<M> --type project --project <project>`, which is refused.
**Right repo?** Yes. The skill, the script's tests and `test_skill_paths.sh` are all workspace files.
**Serves**: Quality of the work — `docs/design.md#merge-gate`
**Design picture?** No change. The fix states how a package merge is called; it moves no part.
**Dependencies**: none identified.

**Which fix.** Fix the skill, not the script.
- The script's refusal is deliberate and tested: `test_repo_conflicting_type_rejected` pins it (for `--type workspace`), and the comment at lines 434-441 gives the reason: a wrong `--type` sends cleanup at the wrong checkout. For a package repo, `WORKTREE_TYPE` is cleared at line 455 so the single-repo cleanup path is never taken.
- Accepting `--type project` for a package repo would make `--type project` mean two things in one script: "the project's own repo" (single-repo cleanup) and "a package repo of the project" (manifest cleanup). It would need a special case in the conflict check, which would weaken the guard for the one case it exists for.
- `.agent/WORKTREE_GUIDE.md` (lines 327-334) already gives the package merge without `--type` (`--pr acme/sonar_msgs#57`); the script header's usage does too. The skill is the one text that disagrees.

**`--project` in that call.** Accepted, and optional. It is resolved by `registry_resolve_project_arg` at the top of the script (an unregistered name is refused), and its one effect for a package PR is to narrow the package-worktree lookup to the manifests whose header names that instance (lines 644-646). It is needed only when the same repo and branch are worktreed under two instances (`test_same_repo_under_two_instances_requires_project`). Passing it always is harmless and keeps the lookup to the project the run checked, so the sound text is `--pr <owner/repo#M> [--project <project>]`, with `--project` passed whenever the session's `project=` is not empty. It is not refused with a package `--repo`; only `--type` is.

**Other texts**: no other text gives a package merge command with `--type`. `.agent/knowledge/`, the `orchestrator` skill and `docs/` have none; `.agent/knowledge/script_reference.md` describes the package path without a command line.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | Action needed | The drift needs a pin. Add a `has` line to `.agent/scripts/tests/test_skill_paths.sh` for step 11's package form (no `--type`, `--project` kept), and a case in `test_merge_pr.sh` that `--type project` against a package repo is refused while `--project <name>` with a qualified package `--pr` is accepted. |
| Verify before claiming | OK | Every claim above was read from the script, the skill and the tests. |
| Keep one current design | OK | No design section changes; the `merge_pr.sh` row in `docs/design.md` is checked for any `--type` wording during the work. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0012 | Yes | Package worktrees and repo-qualified merge; the fix matches its "kind derived from the repo" rule. |
| ADR-0016 | No | No user-tier change. |

### Consequences

- Reword step 11 and the sentence at lines 51-55 of `.claude/skills/run-issue/SKILL.md`, and line 155, so a package merge is `--pr <owner/repo#M>` with `--project` and no `--type`.
- If `docs/design.md` or `script_reference.md` repeat the `--type` form for a package merge, update them in the same change.

### Recommendations

- Fix the skill: in step 11 give the package form as `merge_pr.sh --pr <owner/repo#M> [--project <project>]`, state that `--type` is derived from the repo and is not passed, and exempt the package merge in the "wherever this skill passes `--type`" sentence (lines 51-55) and in line 155.
- Add the two pins described under Principle Alignment (the skill text in `test_skill_paths.sh`, the refusal and acceptance in `test_merge_pr.sh`).
- One short plan is enough: three files (the skill, `test_skill_paths.sh`, `test_merge_pr.sh`), one PR, no design change.

### Actions
- [ ] The drift needs a pin. Add a `has` line to `.agent/scripts/tests/test_skill_paths.sh` for step 11's package form (no `--type`, `--project` kept), and a case in `test_merge_pr.sh` that `--type project` against a package repo is refused while `--project <name>` with a qualified package `--pr` is accepted.
- [ ] Fix the skill: in step 11 give the package form as `merge_pr.sh --pr <owner/repo#M> [--project <project>]`, state that `--type` is derived from the repo and is not passed, and exempt the package merge in the "wherever this skill passes `--type`" sentence (lines 51-55) and in line 155.
- [ ] Add the two pins described under Principle Alignment (the skill text in `test_skill_paths.sh`, the refusal and acceptance in `test_merge_pr.sh`).
- [ ] One short plan is enough: three files (the skill, `test_skill_paths.sh`, `test_merge_pr.sh`), one PR, no design change.
