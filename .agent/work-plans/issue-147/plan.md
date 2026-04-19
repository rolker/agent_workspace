# Plan: Stop writing work-plans into main when invoked outside issue worktree

## Issue

https://github.com/rolker/agent_workspace/issues/147

## Context

Two consumers resolve their work-plans output directory from `git rev-parse
--show-toplevel`, so when invoked from the main checkout instead of the
matching `feature/issue-<N>` worktree, files land as untracked artifacts in
`main` rather than on the feature branch:

- `.agent/scripts/cross_model_review.sh:211` — `WORK_PLANS_DIR=$(git rev-parse
  --show-toplevel)/.agent/work-plans/issue-${ISSUE_NUMBER}`
- `.claude/skills/plan-task/SKILL.md` Step 4 — soft instruction ("check
  `$WORKTREE_ISSUE`"), not enforcement; Step 5 then writes the plan to the
  CWD's toplevel.

Seven stranded files exist today under `.agent/work-plans/issue-{52,58,142}/`
on the main tree — confirmed on no branch via `git log --all`.

The issue's own proposal suggests combining option (1) "refuse to run outside
the matching worktree" with option (4) "make the output path explicit". That's
the approach here.

## Approach

1. **Add a shared resolver helper** — `.agent/scripts/_resolve_work_plans_dir.sh`,
   sourceable. Exposes one function `resolve_work_plans_dir <issue-N>` that
   echoes the resolved absolute path on stdout, or exits non-zero with a
   clear error on stderr. Resolution rules:
   - If `$WORK_PLANS_DIR_OVERRIDE` is set (exported by callers that parsed
     `--work-plans-dir`) → use it verbatim.
   - Elif `$WORKTREE_ISSUE` matches the requested issue number → return
     `$(git rev-parse --show-toplevel)/.agent/work-plans/issue-<N>`.
   - Else → emit an error pointing to `worktree_enter.sh` and return 1.

2. **Wire `cross_model_review.sh`** — Add `--work-plans-dir <path>` flag
   parsing, source the helper, replace line 211 with a call that honours the
   flag or `$WORKTREE_ISSUE`. Abort with the helper's error if neither is
   satisfied.

3. **Update `plan-task` SKILL.md Step 4** — Replace soft instruction with a
   hard check: call the helper early (before step 5 writes anything), abort
   with the same message if the worktree doesn't match. Keep the existing
   create-or-enter-worktree guidance as remediation text in the error.

4. **Defer**:
   - The secondary 767-byte prompt-file bug (separable; out of scope).
   - Cleanup of the seven stranded files (one-line `rm` once the fix is in;
     ask the user before running it).

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_resolve_work_plans_dir.sh` | New sourceable helper with `resolve_work_plans_dir` function |
| `.agent/scripts/cross_model_review.sh` | Add `--work-plans-dir` flag; source helper; replace line 211 |
| `.claude/skills/plan-task/SKILL.md` | Step 4 becomes a hard check that aborts; remediation guidance preserved in error |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Fail loudly, not silently | Current behaviour silently writes to main — fix replaces it with an abort-with-guidance. |
| No premature abstraction | Helper is small (<30 lines) and has two current consumers. Justified shared surface, not speculative. |
| Caller responsibility at boundaries | Resolver validates once at the script/skill boundary; internals trust the resolved path. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0010 (git-bug-first) | No | Fix doesn't touch issue reads. |
| Worktree-per-issue workflow | Yes | Fix reinforces it — invalid states now abort instead of polluting main. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Work-plans-dir resolution contract | Any future consumer of `.agent/work-plans/issue-<N>/` | Yes — helper is the single place to adopt |
| `cross_model_review.sh` invocation surface | `AGENTS.md` script reference | No — new flag is optional; existing description still accurate |
| plan-task skill step numbering | — | No — step 4 keeps the same number, body changes |

## Open Questions

- Should the helper create the directory (`mkdir -p`) or leave that to
  callers? Plan: leave to callers — resolver only resolves.
- Error message wording — include `--type workspace` vs `--type project`
  hint? Plan: yes, print both options and let the user pick based on issue.

## Estimated Scope

Single PR. ~40 LOC new + ~10 LOC changed.
