# Plan: #265 PR 3 — minimal session layer (user tier, root-resolved skills, cwd-derived type/project)

## Issue

https://github.com/rolker/agent_workspace/issues/317

Part of #265 (design B, revision 2 — `.agent/work-plans/issue-265/plan.md`),
PR 3 of 4. Driven with the owner's issue-review checkpoint folded in
(2026-09-22, decision `proceed`): `run-issue`/`review-issue`/`address-findings`
classified for project sessions; the new ADR drafted in this PR; acceptance
scope widened to the full `/run-issue` loop from `~/src/gz4d` through the
merge checkpoint.

## Context

Today every session — workspace or project — starts in the workspace
checkout; `projects/<name>` or the legacy `project/` symlink hosts the
project. Skills, hooks and settings are launch-dir only, so a session
started at `~/src/gz4d` sees none of the workspace layer. The parent plan's
spike (`.agent/work-plans/issue-265/spike-results.md`) confirmed the
mechanism: a registry-gated user-tier `SessionStart` hook injects both
layers when the cwd is under a registered root and stays silent elsewhere
(~5ms), user-tier skill symlinks are discovered by name, and absolute-path
user-tier hooks fire from a project cwd. PRs 1–2 (registry schema,
worktrees-under-root) are merged. This PR builds the user tier itself and
makes the acceptance test — the full `/run-issue` loop, run from `gz4d`,
through the merge checkpoint — pass.

**Branch currency**: `feature/issue-317` is 13 commits behind `origin/main`.
Two in-flight PRs touch files this plan also touches — `dispatch_phase.sh`
(#300, open as PR #319, MERGEABLE) and the `run-issue` skill area (#314,
open as PR #316/#318). Step 0 below merges `main` before implementation
starts; a second merge is required before final review (per dispatch
instructions) to pick up whichever of #319/#316/#318 have landed by then.

## Approach

1. **Merge `main`** into `feature/issue-317` before writing code. Re-check
   `dispatch_phase.sh` and the run-issue skill for conflicts with this
   plan's changes (steps 6–7 below) after the merge, and again immediately
   before final review.

2. **`_project_registry.sh: registry_require_root [dir]`** — new function:
   exits non-zero with a one-line reason unless `dir` (default `$PWD`) is
   under a registered root or under the workspace checkout. Add
   `registry_resolve_from_dir`-based lookup reuse (already exists per plan
   §1) rather than a new resolution path.

3. **SessionStart hook** `.claude/hooks/session_start_project_layer.sh`
   (new): resolves `$PWD` via the registry; silent (exit 0, no output)
   outside any root; under a root, prints in order: header naming the
   project/instance, `AGENT_WORKSPACE_ROOT=<ws>` line, the workspace layer
   (rendered from `AGENTS.md` by a pinned heading list — see step 4), the
   project layer (name/type/root/parent-instances,
   `adapter --project <name> build|test|env|validate` commands, issue
   scope, worktree dir, and the project's own `<root>/.agent/CLAUDE.md`
   verbatim if present), then `WORKTREE_TYPE=`/`PROJECT=`/`INSTANCES=`
   lines for step 7 to consume. Parent-root default-instance resolution
   per plan §2's parent-root rule.

4. **Heading-drift test** `tests/test_session_start_layer.sh`: asserts
   every heading the hook's renderer keys on exists verbatim in
   `AGENTS.md`; fails loudly on a section rename (ADR-0006: render, never
   fork).

5. **Tool-mapping and log-tool-use hook stand-down**: add the same
   `registry_require_root` guard to `.claude/hooks/block-bash-tool-mapping.sh`
   and `log-tool-use.sh` before their existing pattern checks — outside a
   registered root and outside the workspace checkout, exit 0 immediately
   (spike 3b).

6. **`user_tier_install.sh`** (new, idempotent, `--check`/`--uninstall`):
   symlinks `~/.claude/hooks/agent-workspace-session-start.sh` and the
   guarded tool-mapping/log hooks; merges `~/.claude/settings.json` hook
   entries (marked `"_agent_workspace": "<ws path>"`) and the absolute-path
   script allow-rules generated from a manifest
   `.agent/user_tier_scripts.txt`; symlinks the curated skill subset (step
   9) into `~/.claude/skills/`; installs the `register-project` bootstrap
   command (**stub only** — `register_project.sh` itself is PR 4 scope; the
   command prints "not yet available, see #265 PR 4" rather than failing
   silently). `--check` reports missing/stale/foreign-owned entries,
   non-zero exit on drift. Wire `--check` into `make validate`.

7. **Non-inert user-tier scripts call `registry_require_root`**: every
   script on the manifest that is not marked `# user-tier: inert`
   (`worktree_create/enter/remove/list.sh`, `merge_pr.sh`, `gh_create_pr.sh`,
   `gh_create_issue.sh`, `fetch_pr_reviews.sh`, `cross_model_review.sh`,
   `build.sh`, `test.sh`, `adapter`, `dashboard.sh`) gains the guard call
   before any repo-affecting action. `set_git_identity_env.sh`,
   `_issue_helpers.sh`, `_resolve_work_plans_dir.sh` get the inert marker
   (no guard needed — they only set vars/functions).
   `tests/test_user_tier_guard.sh`: runs each listed script from a sandbox
   unregistered git repo, asserts refusal + no side effect; fails if a
   listed script has neither the guard call nor the inert marker.

8. **cwd-derived `--type`/`--project`**: `dispatch_phase.sh`,
   `worktree_create.sh`, `worktree_enter.sh`, `worktree_remove.sh`, and
   `/start-task`'s `SKILL.md` default `--type`/`--project` from the hook's
   `WORKTREE_TYPE=`/`PROJECT=` session lines when the flags are omitted;
   an explicit `--type`/`--project` always wins. Add the pinned workspace
   registry entry (#295 fold, owner decision 2026-09-18) so a workspace
   session resolves the same way a project session does — one registry
   lookup either way. **Resolve the merge-conflict risk with #300/PR#319**
   at step 1's re-merge: #319 touches `dispatch_phase.sh`'s exit/next
   plumbing, not its `--type` parsing, but confirm no overlap before
   editing.

9. **Skills: `session_scope` frontmatter + root-resolved paths**. Add
   `session_scope: project | workspace | both` (default `workspace`) to
   every `SKILL.md`'s frontmatter per the parent plan's table, with the
   issue-review correction folded in:

   | Scope | Skills |
   |---|---|
   | both | start-task, plan-task, review-plan, review-code, triage-reviews, test-engineering, what-next, **run-issue, review-issue, address-findings** |
   | project | document-project, audit-project, onboard-project |
   | workspace | audit-workspace, analyze-permissions, brainstorm, inspiration-tracker, research, gather-project-knowledge, issue-triage, skill-importer, brand-guidelines |

   (`review-issue` moves from workspace-only to `both`; `run-issue` and
   `address-findings` — absent from the parent plan's table — are added as
   `both`, since the acceptance test's `/run-issue` dispatches
   `review-issue` as its first phase and `address-findings` as a later one,
   both from the `gz4d` session.) Rewrite the 11 skills identified in spike
   7 as cwd-relative (`.agent/scripts/...` → `${AGENT_WORKSPACE_ROOT:-.}/.agent/scripts/...`).
   `tests/test_skill_paths.sh`: fails on any new relative
   `.agent/scripts`/`.claude/hooks` reference in `SKILL.md` or
   `settings.json`.

10. **`make generate-user-tier-skills`**: new Makefile target, writes the
    `~/.claude/skills/` symlink list from the `session_scope` frontmatter
    field (scopes `project` and `both`). Add to `Makefile`'s `.PHONY` list;
    run `make generate-skills` is unaffected (different target).

11. **Draft the new ADR**: `docs/decisions/0015-session-roots-and-the-user-tier.md`
    (status **Provisional** — the acceptance test on this machine is
    the promotion condition, per the parent plan's ADR-Compliance table).
    Records: decisions 2–6 from the parent plan (separate session roots,
    workspace-tree-hosts-no-project, user-tier layer injection, memory
    attaches to the project root, registration is a workspace script with
    one bootstrap-command exception), the user-tier rule ("only entries
    inert outside registered roots") and its enforcement (`registry_require_root`
    + generated manifest + `test_user_tier_guard.sh`), the registry-only
    discovery order superseding ADR-0011's legacy `project/` step (flag
    as an ADR-0008 cross-reference addendum on ADR-0011, not silently), and
    the worktree-boundary finding (spike 6: ancestor walking does not cross
    a git worktree boundary, which is why the hook — not `@`-imports —
    carries the project layer).

12. **Reconcile plan/issue drift**: this issue's acceptance scope (full
    `/run-issue` loop through the merge checkpoint) is wider than the
    parent plan's PR-sequence note ("PR 3: Acceptance test steps 1–3").
    Edit `.agent/work-plans/issue-265/plan.md`'s PR-sequence table (PR 3
    row) to say so, in a commit separate from this plan's own commit, so
    the two documents don't silently drift apart. This is a plan
    correction, not an `AGENTS.md`/`.claude/settings.json` edit, so it does
    not need Ask-First.

13. **Hermetic tests** (new, alongside the existing `.agent/scripts/tests/`
    suite): registry `registry_require_root` cases (inside/outside a root,
    inside the workspace checkout); hook silent/inject branches
    (`session_start_project_layer.sh` given synthetic registry + cwd
    payloads, no live `claude` session — same constraint the spike hit);
    `test_session_start_layer.sh` heading-drift; `test_user_tier_guard.sh`;
    `test_skill_paths.sh`; `user_tier_install.sh --check` drift detection
    (foreign entry, missing entry, stale symlink). All run under
    `make validate` per `.agent/scripts/tests/run_script_tests.sh`'s
    existing harness (private `TMPDIR`, no absolute-`/tmp` `mktemp`).

14. **Acceptance test — live, on this machine, from `~/src/gz4d`**:
    - `claude` at `~/src/gz4d` shows both layers in context; skills listed
      include `start-task`, `review-code`, `run-issue`; an unrelated
      scratch repo shows nothing.
    - `/run-issue <a real gz4d issue> --type project` runs review-issue →
      plan-task → review-plan → implement → review-code → publish →
      triage-reviews through to the merge checkpoint, with the timeline
      written to the `gz4d` repo's own `.agent/work-plans/issue-<N>/`
      (not the workspace's).
    - `make validate` in the workspace passes `user_tier_install.sh --check`
      before and after.
    - A session launched in an unrelated repo (no registry entry) sees
      nothing from the workspace (hook silent, no allow-rules fire).
    This is a manual/live step (no `-p` auth path per the spike's blocker)
    — run and record the transcript summary in the PR description, not a
    CI assertion.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/_project_registry.sh` | `registry_require_root` guard helper |
| `.claude/hooks/session_start_project_layer.sh` (new) | Registry-gated layer injection; `WORKTREE_TYPE`/`PROJECT`/`INSTANCES` lines |
| `.claude/hooks/block-bash-tool-mapping.sh`, `log-tool-use.sh` | Registry guard added before existing checks |
| `.agent/scripts/user_tier_install.sh` (new) | Install/`--check`/`--uninstall` |
| `.agent/user_tier_scripts.txt` (new) | Manifest of promoted scripts |
| `.agent/scripts/worktree_create.sh`, `worktree_enter.sh`, `worktree_remove.sh`, `worktree_list.sh`, `merge_pr.sh`, `gh_create_pr.sh`, `gh_create_issue.sh`, `fetch_pr_reviews.sh`, `cross_model_review.sh`, `build.sh`, `test.sh`, `adapter`, `dashboard.sh` | `registry_require_root` guard call (non-inert scripts only) |
| `.agent/scripts/dispatch_phase.sh` | cwd-derived `--type`/`--project` default when flags omitted |
| `Makefile` | `user-tier-install`, `generate-user-tier-skills` targets; `.PHONY` update; `validate` runs `user_tier_install.sh --check` |
| `.claude/skills/*/SKILL.md` (22) | `session_scope` frontmatter on all; 11 identified in spike 7 get `${AGENT_WORKSPACE_ROOT:-.}` path rewrites |
| `.claude/skills/start-task/SKILL.md` | Default `--type`/`--project` from session lines |
| `.claude/commands/register-project.md` (new, installed to user tier) | Bootstrap command, stub pending PR 4 |
| `docs/decisions/0015-session-roots-and-the-user-tier.md` (new) | Provisional ADR |
| `docs/decisions/0011-project-type-adapter-contract.md` | Cross-reference addendum (ADR-0008) noting the registry-only discovery order supersedes the legacy `project/` step |
| `.agent/work-plans/issue-265/plan.md` | PR-sequence table correction (PR 3 scope), separate commit |
| `.agent/scripts/tests/test_session_start_layer.sh`, `test_user_tier_guard.sh`, `test_skill_paths.sh` (new) | Hermetic coverage per step 13 |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Every promoted script gets the guard or the inert marker, checked by a test that fails on an ungoverned entry; every rewritten skill path is covered by `test_skill_paths.sh` |
| Capture decisions, not just implementations | New ADR drafted in this PR (step 11), not deferred |
| Only what's needed / Improve incrementally | `register_project.sh` itself, `project/`/`projects/` retirement, `--type` special-case collapse, p11 migration stay in PR 4; the bootstrap command is a stub, not a fake implementation |
| Workspace vs. project separation | User-tier entries are inert outside registered roots by construction and by test; the workspace never writes into a project checkout in this PR |
| Enforcement over documentation | `registry_require_root` + generated manifest + `test_user_tier_guard.sh`; heading-drift test pins the ADR-0006 render-not-fork rule |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0006 (shared AGENTS.md, thin adapters) | Yes | Hook renders `AGENTS.md` sections by heading list; `test_session_start_layer.sh` pins the heading list against drift |
| ADR-0008 (cross-reference addendums) | Yes | ADR-0011 gets an addendum noting the registry-only discovery order (not a rewrite of its Decision) |
| ADR-0011 (adapter contract) | Yes, partially deferred | No new verb; `registry_require_root` is additive. Full `project/` fallback removal is PR 4 — this PR's guard does not remove the legacy discovery step, only adds the user-tier check |
| ADR-0014 (in-process phase handoff) | Yes | `/run-issue`'s dispatch path is exercised live from `~/src/gz4d` in the acceptance test; `dispatch_phase.sh`'s cwd-derived `--type` (step 8) must not regress its existing `--type`-required contract for direct callers |
| New: ADR-0015 "session roots and the user tier" | Yes | Authored in this PR, status Provisional (see step 11) |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `dispatch_phase.sh` `--type` defaulting | `/run-issue`'s own SKILL.md (dispatch examples), #319 (open PR touching the same file) — reconcile at the step-1 merge | Yes (step 1, step 8) |
| Skill `session_scope` frontmatter | `make generate-user-tier-skills` output, `user_tier_install.sh`'s symlink step | Yes (step 9, step 10) |
| Hook renders `AGENTS.md` sections | `#259` (trim `AGENTS.md`) must keep headings the renderer keys on | Cross-reference note only, no code change here |
| New ADR added | `docs/decisions/` index/count referenced elsewhere (e.g. ADR-0001's own text, if it enumerates) — check for a stale count during implementation | Verify during implementation |
| Parent plan's PR-sequence table | Issue #317's own acceptance-scope note | Yes (step 12) |

## Open Questions

- **#300/PR #319 and #314/PR #316,#318 overlap** with `dispatch_phase.sh`
  and the run-issue skill area: confirmed no `--type`-parsing overlap as of
  this plan's writing (PR #319 touches exit/next plumbing), but this must
  be re-verified at both the pre-implementation merge (step 1) and the
  pre-review merge, not assumed stable.
- **ADR number**: this plan assumes the new ADR is `0015` (next available
  after `0014`); confirm no other in-flight PR has claimed `0015` before
  committing the file.
- **Ask-First edits**: none required in this PR's Files-to-Change list.
  `.claude/settings.json` itself is not edited (the user tier gets its own
  merged copy under `~/.claude/`, generated by `user_tier_install.sh`, not
  a change to the repo's tracked `.claude/settings.json`); `AGENTS.md`
  wording changes stay deferred to PR 4 per the parent plan. If
  implementation finds either file needs a tracked-repo edit beyond what's
  listed here, stop and ask before making it.

## Estimated Scope

Single PR (workspace issue #317, PR 3 of 4 in the #265 series). Hermetic
tests cover the guard/hook/path/frontmatter mechanics; the acceptance test
is a live, manual run from `~/src/gz4d` recorded in the PR description.
