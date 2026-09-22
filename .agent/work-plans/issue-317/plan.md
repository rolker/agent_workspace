# Plan: #265 PR 3 — minimal session layer (user tier, root-resolved skills, cwd-derived type/project)

## Issue

https://github.com/rolker/agent_workspace/issues/317

Part of #265 (design B, revision 2 — `.agent/work-plans/issue-265/plan.md`),
PR 3 of 4. Driven with the owner's issue-review checkpoint folded in
(2026-09-22, decision `proceed`): `run-issue`/`review-issue`/`address-findings`
classified for project sessions; the new ADR drafted in this PR; acceptance
scope widened to the full `/run-issue` loop from `~/src/gz4d` through the
merge checkpoint.

**Revision 2** (2026-09-22): rewritten against the `## Plan Review` at
`421d8ac` (verdict needs-work, 13 findings) and the owner's `revise`
checkpoint. Two findings blocked acceptance outright and are fixed at the
mechanism level (see steps 2 and 8); the rest are number/attribution
corrections and scope trims, folded in below.

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
worktrees-under-root) are merged, including `registry_require_root` (see
step 2). This PR builds the user tier itself and makes the acceptance test
— the full `/run-issue` loop, run from `gz4d`, through the merge checkpoint
— pass.

**Two mechanisms this revision corrects** (plan review findings 1–2, both
block acceptance):

- `dispatch_phase.sh`'s `resolve_worktree()` only resolves a project base
  when exactly one project is registered. This machine has three
  (`gz4d`, `p11-jazzy`, `p11-rolling`), so `/run-issue <N> --type project`
  fails at the first dispatch today. Fix: add a real `--project` flag and
  derive it from `$PWD` when omitted (step 8).
- `SessionStart` hook stdout is context text for the model, not
  environment — nothing sets `AGENT_WORKSPACE_ROOT` in the Bash tool's
  fresh per-call shell. Fix: the install script writes the workspace root
  to a fixed file (`~/.claude/agent-workspace-root`); skills read that
  file at the head of each command chain, and workspace scripts (which
  already resolve their own root from `BASH_SOURCE`) call
  `registry_resolve_from_dir` on `$PWD` directly rather than trusting
  anything the hook printed (step 3, step 9).

**Branch currency** (corrected — plan review finding 5): `feature/issue-317`
is behind `origin/main`. `#300`'s PR #319 already **merged** to `main`
(`bc2a509`, confirmed ~12:50 today) — it touched `merge_pr.sh`,
`run-issue/SKILL.md`, `review-code/SKILL.md`, `AGENTS.md`, `Makefile`, and
is no longer an in-flight conflict once step 1's merge lands it. The real
overlap is **`feature/issue-314`, local and unpushed with no PR** — it is
not visible to a `git merge origin/main`, and it substantially rewrites
`dispatch_phase.sh` (+187/−? lines, including `--type` plumbing this plan
also touches), `run-issue/SKILL.md` (+260 lines), `AGENTS.md`, `Makefile`,
and claims the ADR number `0015` (freed by #318's merge, which renumbered
its own ADR — see step 11). Step 1 below merges `main` and separately diffs
against `feature/issue-314` to scope the real conflict; if #314 lands
(gets pushed and merged) before this PR does, rebase onto it rather than
re-deriving the `--type`/`--project` change independently.

## Approach

1. **Merge `main`** into `feature/issue-317` before writing code. Then run
   `git diff main feature/issue-314 --stat -- .agent/scripts/dispatch_phase.sh
   .claude/skills/run-issue AGENTS.md Makefile docs/decisions/` to see the
   current shape of the local #314 overlap (confirmed present as of this
   revision) and plan around it explicitly — rebasing over #314 if it lands
   first, rather than assuming the `origin/main` merge covers it. Repeat
   both checks immediately before final review.

2. **Call the existing `registry_require_root`** — it already landed with
   PR 1 (`.agent/scripts/_project_registry.sh:479`, signature
   `registry_require_root <ws_root> [dir]`, workspace-checkout special case
   included). This step is not "add the guard", it is "call it": every
   promoted script (step 7) resolves its own workspace root the way
   existing scripts already do (`BASH_SOURCE`-relative), then calls
   `registry_require_root "$ws_root"` before any repo-affecting action.

3. **SessionStart hook** `.claude/hooks/session_start_project_layer.sh`
   (new): resolves `$PWD` via the registry; silent (exit 0, no output)
   outside any root; under a root, prints in order: header naming the
   project/instance, the `AGENT_WORKSPACE_ROOT` value as informational text
   (**not** consumed by any script — see the idiom decision below), the
   workspace layer (rendered from `AGENTS.md` by a pinned heading list —
   step 4), the project layer (name/type/root/parent-instances,
   `adapter --project <name> build|test|env|validate` commands, issue
   scope, worktree dir, and the project's own `<root>/.agent/CLAUDE.md`
   verbatim if present). No `WORKTREE_TYPE=`/`PROJECT=` lines for scripts
   to parse — scripts derive that themselves (step 8/9), since hook stdout
   never reaches a tool-call shell as environment.

4. **Heading-drift test** `tests/test_session_start_layer.sh`: for each
   heading the renderer keys on, asserts (a) the heading exists verbatim in
   `AGENTS.md`, (b) the extracted section is non-empty, and (c) extraction
   stops at the next same-level heading (not just "heading exists" — plan
   review finding 11). Two open branches already touch `AGENTS.md`
   (`feature/issue-314`, and `#318` already merged); this test is the only
   thing between a section rename and a silently empty workspace layer.

5. **Workspace-root idiom for skills** (decided per plan review finding 2,
   option (b)): `user_tier_install.sh` (step 6) writes the absolute
   workspace path to `~/.claude/agent-workspace-root` (one line, no
   trailing newline complications — `printf '%s' "$ws_root" >`). Every
   skill command chain that needs a workspace script starts with:
   ```bash
   WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"
   "$WS_ROOT/.agent/scripts/<script>" ...
   ```
   This is a plain file read, not a hook-output dependency, so it works
   whether or not the `SessionStart` hook ran in the session and needs no
   sourcing. `AGENT_WORKSPACE_ROOT` as an env var name is dropped from
   scripts' vocabulary to avoid implying it's ambient; the file is the
   single source. Document this decision in the new ADR (step 11) so it
   isn't re-litigated per skill.

6. **`user_tier_install.sh`** (new, idempotent, `--check`/`--uninstall`):
   symlinks `~/.claude/hooks/agent-workspace-session-start.sh`; writes
   `~/.claude/agent-workspace-root` (step 5); merges `~/.claude/settings.json`
   hook entry (marked `"_agent_workspace": "<ws path>"`) and the
   absolute-path script allow-rules generated from a manifest
   `.agent/user_tier_scripts.txt` (step 7's trimmed list); symlinks the
   curated skill subset (step 9) into `~/.claude/skills/`. **Dropped from
   this PR** (plan review finding 9): the `register-project` bootstrap
   command and any install/uninstall path for it — `register_project.sh`
   itself is PR 4 scope and `gz4d` is already registered, so a stub buys
   nothing for the acceptance test. `--check` reports missing/stale/foreign
   entries and exits non-zero on drift **only** when installed; on a
   machine with no user tier installed it prints a one-line "not installed"
   note and exits 0 (plan review finding 10 — this keeps `make validate`
   green on the ROS machine and a fresh checkout). `--check --require`
   exits non-zero when not installed, for use on a machine that expects it.
   Wire plain `--check` (no `--require`) into `make validate`.

7. **Non-inert user-tier scripts call `registry_require_root`**, trimmed
   to what the acceptance loop actually invokes from `gz4d` (plan review
   finding 9): `worktree_create.sh`, `worktree_enter.sh`,
   `worktree_remove.sh`, `worktree_list.sh`, `merge_pr.sh`,
   `gh_create_pr.sh`, `gh_create_issue.sh`, `fetch_pr_reviews.sh`,
   `cross_model_review.sh`, `build.sh`, `test.sh`, `adapter`. `dashboard.sh`
   is dropped from the manifest — not in the loop, and each manifest row
   costs a guard call plus a test row. **`.claude/hooks/block-bash-tool-mapping.sh`
   and `log-tool-use.sh` stay project-scoped** (not promoted to the user
   tier in this PR) — nothing in the acceptance test needs them in a
   project session, and promoting them without the guard would violate the
   user-tier rule; deferred to PR 4 as a pair (promote + guard together,
   never one without the other). `set_git_identity_env.sh`,
   `_issue_helpers.sh`, `_resolve_work_plans_dir.sh` get a
   `# user-tier: inert` marker (no guard needed — they only set
   vars/functions). The guard call precedes any `gh`/`git` call in every
   listed script, so the refusal path touches nothing (plan review finding
   10). `tests/test_user_tier_guard.sh`: runs each listed script from a
   sandbox unregistered git repo (temp `HOME`, no network/`gh` auth
   required — the guard fires before any network call), asserts refusal +
   no side effect; fails if a listed script has neither the guard call nor
   the inert marker.

8. **`dispatch_phase.sh`: add `--project`, thread it through
   `resolve_worktree()`** (plan review finding 1, blocks acceptance).
   Today `resolve_worktree()` only builds a project base when exactly one
   project is registered (`_project_registry.sh` lookup ×N with no
   disambiguation). Change:
   - Add `--project <name>` to `dispatch_phase.sh`'s three subcommands
     (`dispatch`, `check-exit`, `next`) and their usage/header text.
   - `resolve_worktree(issue, type, project)`: when `type == project` and
     `project` is non-empty, resolve that single named root directly
     (`wt_project_base "$ROOT_DIR" "$project"` +
     `wt_transition_project_base`), skipping the "exactly one registered"
     branch entirely.
   - When `type == project` and `project` is empty, derive it: call
     `registry_resolve_from_dir "$ROOT_DIR" "$PWD"` (the function already
     does longest-prefix ancestor matching — no hook dependency, per the
     step-3/5 idiom decision). If that resolves, use the resolved name. If
     it does not (cwd is not under any registered root), fall back to the
     existing "exactly one registered" behavior for backward compatibility
     with today's callers, then the legacy `project/` base.
   - This is additive: existing callers that pass neither `--project` nor
     a resolvable cwd see identical behavior to today.

9. **`worktree_create.sh`, `worktree_enter.sh`, `worktree_remove.sh`,
   and `/start-task`'s `SKILL.md`**: same derivation as step 8 — when
   `--type`/`--project` are omitted, resolve from `$PWD` via
   `registry_resolve_from_dir` (scripts call it directly, having resolved
   their own root via `BASH_SOURCE`; `/start-task`'s skill prose uses the
   step-5 file idiom to locate the script, then lets the script do the
   `$PWD` resolution — the skill does not attempt its own registry lookup).
   An explicit `--type`/`--project` always wins. **The pinned workspace
   registry entry is dropped from this PR** (plan review finding 12 —
   its shape, `worktrees=` override and consumer list were unspecified and
   the blast radius touches `adapter --from` discovery, `dashboard.sh`
   classification and `registry_worktree_dir`'s default). Instead, a
   workspace-type default is produced by the existing
   "cwd under the workspace checkout" branch, which `registry_require_root`
   and `resolve_worktree`'s `type == workspace` path already handle without
   a registry entry.

10. **Skills: `session_scope` frontmatter + root-resolved paths**, scoped
    to the 13 skills that need it (plan review finding 9 — `workspace` is
    the documented default for the rest, so only `project` and `both` get
    the field):

    | Scope | Skills |
    |---|---|
    | both | start-task, plan-task, review-plan, review-code, triage-reviews, test-engineering, what-next, run-issue, review-issue, address-findings |
    | project | document-project, audit-project, onboard-project |

    (`review-issue` moves from workspace-only to `both`; `run-issue` and
    `address-findings` — absent from the parent plan's table — are added as
    `both`, per the issue-review action folded into the owner's checkpoint.)

    **Re-grep at implementation time, not from spike 7's stale count**: as
    of this revision, 15 of 22 `SKILL.md` files carry relative
    `.agent/scripts`/`.claude/hooks` references (`run-issue` 17,
    `review-code` 15, `plan-task` 8, `analyze-permissions` 8,
    `triage-reviews` 7, `start-task` 7, `review-plan` 5,
    `inspiration-tracker` 5, `research` 4, `address-findings` 4,
    `gather-project-knowledge` 3, `onboard-project` 2, `audit-workspace` 2,
    `review-issue` 1, `issue-triage` 1) — confirm the current count when
    implementing, since `feature/issue-314` is independently rewriting
    `run-issue/SKILL.md`. Rewrite each relative reference using the step-5
    idiom. `tests/test_skill_paths.sh`: **scoped to `SKILL.md` files only**
    (plan review finding 6 — the tracked `.claude/settings.json` keeps its
    two existing relative hook commands as-is; it is Ask-First and this PR
    does not edit it). Fails on any new relative `.agent/scripts`/
    `.claude/hooks` reference introduced in a `SKILL.md` after this PR.

11. **`make generate-user-tier-skills`**: new Makefile target, writes the
    `~/.claude/skills/` symlink list from the `session_scope` frontmatter
    field (scopes `project` and `both`; skills with no field are
    `workspace` and excluded). Add to `Makefile`'s `.PHONY` list;
    `make generate-skills` is unaffected (different target, different
    purpose).

12. **Draft the new ADR**: `docs/decisions/0016-session-roots-and-the-user-tier.md`
    (number corrected — `0015` is claimed by the already-merged PR #318;
    re-check the highest existing number at the pre-review merge in case
    another PR lands first). Status **Provisional** — the acceptance test
    on this machine is the promotion condition, per the parent plan's ADR
    Compliance table. Records: decisions 2–6 from the parent plan (separate
    session roots, workspace-tree-hosts-no-project, user-tier layer
    injection, memory attaches to the project root, registration is a
    workspace script with one bootstrap-command exception — noting the
    command itself is deferred to PR 4 per step 6), the user-tier rule
    ("only entries inert outside registered roots") and its enforcement
    (`registry_require_root` + generated manifest + `test_user_tier_guard.sh`),
    the workspace-root-idiom decision (step 5 — a file, not hook-splice
    environment), the registry-only discovery order that **will**
    supersede ADR-0011's legacy `project/` step once PR 4 removes the
    fallback (recorded here now, since this ADR is where the parent plan
    says the supersession belongs — not yet *in effect*, since this PR
    does not remove the fallback), and the worktree-boundary finding
    (spike 6: ancestor walking does not cross a git worktree boundary,
    which is why the hook — not `@`-imports — carries the project layer).
    **ADR-0011 itself gets only a pointer** (plan review finding 4 — an
    ADR-0008 navigational edit: a References entry to ADR-0016), not an
    addendum describing the supersession — the parent plan and ADR-0008's
    own test both say the substantive content belongs in the new ADR, and
    this PR does not yet change ADR-0011's actual discovery order (that's
    PR 4), so an addendum here would document a change that hasn't
    happened.

13. **Reconcile plan/issue drift**: this issue's acceptance scope (full
    `/run-issue` loop through the merge checkpoint) is wider than the
    parent plan's PR-sequence note ("PR 3: Acceptance test steps 1–3").
    Edit `.agent/work-plans/issue-265/plan.md`'s PR-sequence table (PR 3
    row) to say so, in a commit separate from this plan's own commit, so
    the two documents don't silently drift apart. This is a plan
    correction, not an `AGENTS.md`/`.claude/settings.json` edit, so it does
    not need Ask-First.

14. **Hermetic tests** (new, alongside the existing `.agent/scripts/tests/`
    suite, all redirecting `HOME` to a private temp dir and needing no
    network or `gh` auth): `registry_require_root` cases (inside/outside a
    root, inside the workspace checkout — exercising the existing
    function, not a new one); `dispatch_phase.sh --project` resolution
    (named project, `$PWD`-derived with 1 and 3+ registered projects,
    unresolvable-cwd fallback); **hook silent/inject branches as the
    hermetic proxy named in plan review finding 13**: drive
    `session_start_project_layer.sh` directly with a synthetic registry and
    a `{"cwd": …}` payload (spike 2's method — no live `claude` session) for
    both "unrelated repo: silent" and "registered root: both layers
    printed"; `test_session_start_layer.sh` heading-drift (step 4);
    `test_user_tier_guard.sh` (step 7); `test_skill_paths.sh` (step 10);
    `user_tier_install.sh --check` drift detection (foreign entry, missing
    entry, stale symlink, and the not-installed/`--require` split from step
    6). All run under `make validate` per
    `.agent/scripts/tests/run_script_tests.sh`'s existing harness (private
    per-run `TMPDIR`, no absolute-`/tmp` `mktemp`).

15. **Acceptance test — live, on this machine, from `~/src/gz4d`**. Scoped
    down to what only a live session can prove, now that step 14 covers the
    hook's silent/inject logic hermetically (plan review finding 13):
    - `claude` at `~/src/gz4d` shows both layers spliced into context
      (proves Claude Code actually splices `SessionStart` stdout — the one
      thing the hermetic driver can't prove); skills listed include
      `start-task`, `review-code`, `run-issue` (proves symlink discovery);
      an unrelated scratch repo shows nothing.
    - `/run-issue <a real gz4d issue> --type project` runs review-issue →
      plan-task → review-plan → implement → review-code → publish →
      triage-reviews through to the merge checkpoint, with the timeline
      written to the `gz4d` repo's own `.agent/work-plans/issue-<N>/` (not
      the workspace's) — proves the full loop end to end, including step
      8's `--project` fix.
    - `make validate` in the workspace passes `user_tier_install.sh --check`
      before and after.
    Record the transcript summary in the PR description, not a CI
    assertion (no `-p` auth path per the spike's blocker).

## Files to Change

| File | Change |
|------|--------|
| `.claude/hooks/session_start_project_layer.sh` (new) | Registry-gated layer injection; informational header only, no script-consumed lines |
| `.agent/scripts/user_tier_install.sh` (new) | Install/`--check`[`--require`]/`--uninstall`; writes `~/.claude/agent-workspace-root` |
| `.agent/user_tier_scripts.txt` (new) | Trimmed manifest of promoted scripts (step 7) |
| `.agent/scripts/worktree_create.sh`, `worktree_enter.sh`, `worktree_remove.sh`, `worktree_list.sh`, `merge_pr.sh`, `gh_create_pr.sh`, `gh_create_issue.sh`, `fetch_pr_reviews.sh`, `cross_model_review.sh`, `build.sh`, `test.sh`, `adapter` | `registry_require_root` guard call (existing function; non-inert scripts only) |
| `.agent/scripts/dispatch_phase.sh` | `--project` flag; `resolve_worktree()` takes a project name or derives one via `registry_resolve_from_dir($PWD)` |
| `Makefile` | `user-tier-install`, `generate-user-tier-skills` targets; `.PHONY` update; `validate` runs `user_tier_install.sh --check` (no `--require`) |
| `.claude/skills/*/SKILL.md` (13: the `project`/`both` set) | `session_scope` frontmatter; re-grepped relative-path rewrites via the step-5 file idiom |
| `.claude/skills/start-task/SKILL.md` | `$PWD`-derived `--type`/`--project` via the underlying script, not hook output |
| `docs/decisions/0016-session-roots-and-the-user-tier.md` (new) | Provisional ADR (number corrected from 0015) |
| `docs/decisions/0011-project-type-adapter-contract.md` | Navigational pointer only (References entry to ADR-0016) |
| `.agent/work-plans/issue-265/plan.md` | PR-sequence table correction (PR 3 scope), separate commit |
| `.agent/scripts/tests/test_session_start_layer.sh`, `test_user_tier_guard.sh`, `test_skill_paths.sh`, plus `dispatch_phase.sh --project` test cases (new/extended) | Hermetic coverage per step 14 |

**Deferred to PR 4** (unchanged or newly deferred by this revision):
`register_project.sh` and its bootstrap command/stub, promoting
`block-bash-tool-mapping.sh`/`log-tool-use.sh` to the user tier (with their
guard, as a pair), `dashboard.sh`'s guard, the pinned workspace registry
entry, `project/`/`projects/` retirement, the `--type` special-case
collapse, p11 migration, `AGENTS.md` wording.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Every promoted script gets the guard or the inert marker, checked by a test that fails on an ungoverned entry; every rewritten skill path is covered by `test_skill_paths.sh`; `dispatch_phase.sh`'s new `--project` path is additive and covered for both the named and derived cases |
| Capture decisions, not just implementations | New ADR drafted in this PR (step 12); the workspace-root idiom (step 5) is a decision this revision makes explicit and records, not just implements |
| Only what's needed / Improve incrementally | Register-project stub, both hooks' promotion, `dashboard.sh`'s guard, and the pinned workspace registry entry are all trimmed or dropped this revision, on top of what PR 4 already deferred |
| Workspace vs. project separation | User-tier entries are inert outside registered roots by construction and by test; the workspace never writes into a project checkout in this PR |
| Enforcement over documentation | `registry_require_root` (already landed) + trimmed manifest + `test_user_tier_guard.sh`; heading-drift test now also checks non-empty/bounded extraction, not just heading existence |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0006 (shared AGENTS.md, thin adapters) | Yes | Hook renders `AGENTS.md` sections by heading list; `test_session_start_layer.sh` pins the heading list against drift, including non-empty/bounded extraction |
| ADR-0008 (cross-reference addendums) | Yes | ADR-0011 gets a navigational pointer only (References entry); the supersession content lives entirely in the new ADR-0016 |
| ADR-0011 (adapter contract) | Yes, unchanged in substance | No new verb; `registry_require_root` is additive and pre-existing. Full `project/` fallback removal is PR 4 — this PR does not alter ADR-0011's documented discovery order |
| ADR-0014 (in-process phase handoff) | Yes | `/run-issue`'s dispatch path is exercised live from `~/src/gz4d` in the acceptance test; `dispatch_phase.sh`'s new `--project` flag and `$PWD`-derived fallback (step 8) must not regress its existing `--type`-required contract for direct callers — covered by the additive-behavior test cases in step 14 |
| New: ADR-0016 "session roots and the user tier" | Yes | Authored in this PR, status Provisional (step 12); number corrected from the review's flagged conflict with PR #318's ADR-0015 |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `dispatch_phase.sh` `--project`/`$PWD` resolution | `/run-issue`'s own SKILL.md dispatch examples; reconcile against the local, unpushed `feature/issue-314`'s independent `dispatch_phase.sh` rewrite at both merges (step 1) | Yes (step 1, step 8) |
| Skill `session_scope` frontmatter | `make generate-user-tier-skills` output, `user_tier_install.sh`'s symlink step | Yes (step 10, step 11) |
| Hook renders `AGENTS.md` sections | `#259` (trim `AGENTS.md`) must keep headings the renderer keys on; `feature/issue-314` also touches `AGENTS.md` — re-check headings survive at the pre-review merge | Cross-reference note; re-verified at step 1 |
| New ADR added | Confirm `0016` is still free at the pre-review merge (`0015` was already reclaimed once by #318) | Yes (step 12, re-verify) |
| Parent plan's PR-sequence table | Issue #317's own acceptance-scope note | Yes (step 13) |
| Workspace-root file idiom (step 5) replaces hook-output env vars | Any skill or doc that assumed `AGENT_WORKSPACE_ROOT` was ambient — none exist yet in tracked files, confirmed by this revision's re-grep (step 10) | Yes, verified clean |

## Open Questions

- **`feature/issue-314` timing**: it is local, unpushed, and independently
  rewrites `dispatch_phase.sh` and `run-issue/SKILL.md`. If it gets pushed
  and merged before this PR, rebase onto it rather than re-deriving the
  `--type`/`--project` change; if it lands after, re-diff at the pre-review
  merge (step 1). Not resolved by this plan — a timing call at
  implementation.
- **ADR number reconfirmation**: `0016` assumed correct as of this
  revision (`0015` belongs to the merged #318); re-check the highest
  existing number immediately before creating the file.
- **Ask-First edits**: none required in this PR's Files-to-Change list.
  The tracked `.claude/settings.json` is not edited (kept exactly as-is,
  including its two existing relative hook commands — `test_skill_paths.sh`
  no longer checks it, per step 10); `AGENTS.md` wording changes stay
  deferred to PR 4. If implementation finds either file needs a
  tracked-repo edit beyond what's listed here, stop and ask before making
  it.

## Estimated Scope

Single PR (workspace issue #317, PR 3 of 4 in the #265 series). Hermetic
tests cover the guard/hook/path/frontmatter/dispatch mechanics; the
acceptance test is a live, manual run from `~/src/gz4d` recorded in the PR
description, now scoped to only what the hermetic tests can't prove
(context splicing, skill listing, and the full loop end to end).
