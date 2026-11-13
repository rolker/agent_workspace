---
issue: 446
---

# Issue #446 — Enable the agent-workspace plugin once for the whole machine (user scope), as decided 2026-10-13

## Issue Review
**Status**: complete
**When**: 2026-11-12 11:44 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #446

### Scope Assessment

**Well-scoped?** Mostly, with one scope correction: the issue sizes this as an installer change plus an ADR amendment, but the code and ADR-0018 show the change is larger and mostly a deletion. ADR-0018 decision 3 ("The installer enables the plugin per registered root", about 125 lines) is a stack of per-root special cases: roots skipped because their git toplevel is the workspace checkout (`p11-*`), `parent=` instances, worktrees and plain directories inside another repository, and the nested-repository gap (live case G). Each exists only because a local-scope enable lands in one directory's settings. At user scope most of them go away. `user_tier_install.sh` (`plugin_roots`, `plugin_state`, `plugin_enabled_flag`, `plugin_disabled_flag`, the nested-repository refusals), `register_project.sh` (`root_plugin_enabled_here`, `ROOT_PLUGIN_BEFORE`, the rollback and `--remove` plugin steps, `--disable-root`) and `skill_prefix.sh` (reading a registered root's local settings) all carry that logic. The issue lists the outcomes ("`--check` and uninstall follow the new shape") but not that removal of this per-root machinery is the bulk of the work, so a single PR may be large. It still fits one PR if the deletions are kept mechanical; the plan should decide whether to split "install and migrate" from "remove the dead per-root code".
**Right repo?** Yes. Workspace: `.agent/scripts/`, `.claude/settings.json`, `docs/decisions/0018`, `docs/design.md`.
**Serves**: Work across many projects from one workspace (user tier, plugin delivery of skills) -- `docs/design.md#sessions-and-roots`
**Design picture?** Changes Sessions and roots (`docs/design.md#sessions-and-roots`, the plugin bullet and the ADR-0018 row of the decision register, "enabled at local scope per registered root"). The owner's decision is recorded on #332 (2026-10-13) and re-confirmed 2026-11-12, and the issue names the design update (ADR-0017), so no new question to him.
**Dependencies**: #394 (hook markers stripped by `claude plugin` commands) is a precondition: user-scope enable and disable rewrite `~/.claude/settings.json`, which is exactly what drops the markers. It must be fixed first or inside this PR; "or say why it can stay separate" is not available, because the acceptance line "re-running the installer changes nothing and `--check --require` passes" fails without it. #351 (hooks into the plugin) is correctly out of scope and would later remove the marker problem entirely, but this issue cannot wait for it.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | OK | Decision recorded on #332; issue names the ADR-0018 amendment and the `docs/design.md` update in the same change. |
| Put each thing at the level it applies to | OK | A machine-wide plugin belongs at user scope; per-root enables were the wrong level. |
| Only what's needed | Action needed | The issue does not say that the per-root machinery (skip rules, `parent=` handling, nested-repository refusals, `--disable-root`, rollback of a root enable) is removed rather than adapted. State it as in scope, otherwise the change adds a user-scope path on top of dead per-root code. |
| Verify before claiming | Action needed | The 2026-10-13 spike facts are a month old on Claude Code 2.1.296; the issue says to re-check them. Make the re-check a named first step with its result recorded, covering: the committed `enabledPlugins` false entry stops doubling in the workspace checkout and its worktrees; the same entry covers the `p11-*` roots inside the workspace tree; narrower scope wins in a session in a nested repository. |
| Tests have a scratch HOME | OK | Issue already requires scratch-HOME tests with no real registered project. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0018 (plugin delivery) | Yes | Amend decision 3 and the "Enable the plugin at user scope" rejected alternative (the stated reason, "same global reach as the symlinks", is exactly what the owner now accepts because the plugin namespace removes the name-collision concern, 2026-11-12). Decision 6 (`skill_prefix.sh`, handoff prefix) and the Consequences and Acceptance sections also mention per-root enabling. |
| ADR-0016 (user tier) | Yes | Decision 2's scoped exception (the project's gitignored `.claude/settings.local.json`, written by the CLI) goes away; the exception paragraph and the ADR-0018 decision 4 that records it need amending, and the user tier gains one more `~/.claude` write (`enabledPlugins`, marketplace record). |
| ADR-0017 (design doc) | Yes | `docs/design.md#sessions-and-roots` and the decision-register row for ADR-0018 update in the same change; the issue says so. |
| ADR-0013 (timelines) | No | -- |

### Consequences

- `.claude/settings.json` (workspace, committed) gains `"enabledPlugins": {"agent-workspace@agent-workspace": false}`; it is absent today (checked). Worktrees under `worktrees/` inherit it by being checkouts of the same branch tree.
- `.claude/hooks/session_start_project_layer.sh` and `skill_prefix.sh` currently say "plugin is not enabled for this root: run the installer" and reason from the root's local settings; after the change a session anywhere sees the plugin, so the header should say what is true in an unregistered folder (plugin present, no workspace root there) and in a registered root. The issue names both; add the unregistered-folder message.
- `register_project.sh` header, `--remove` (which disables the plugin in the root) and its rollback steps; the design's registry text ("unregistering removes ... the plugin enable", decision register C4) change to "registration tells the workspace about the root only".
- Migration: an old install has per-root `enabledPlugins` entries in `<root>/.claude/settings.local.json`. The installer run that moves the machine over must remove those entries through the CLI (not by editing the files) and handle a root that was since unregistered or moved; the issue's "no root left with a stale local entry" needs that stated, plus the case where a registry root is unreachable.
- Open-question to carry into the plan, not to the owner: the plugin ships only `session_scope: project` and `both` skills; workspace-scoped skills stay out, so 2026-11-12's "workspace skills only opt-in" concerns the `both`/`project` set only. No decision needed.
- `.gitignore` entry for `.claude/settings.local.json` from #394 stays valid and is still wanted.

### Recommendations

- State in the Not-in-scope/What-is-needed sections that the per-root special cases (workspace-tree skip, `parent=` handling, nested-repository refusal, `--disable-root`, root-enable rollback) are removed, and name `register_project.sh --remove` and its rollback as affected.
- Make fixing #394 a precondition inside this issue's PR (or an earlier PR that merges first); drop the "or say why it can stay separate" option, since the idempotence acceptance line depends on it.
- Add the migration cases to the issue: per-root entries removed through the CLI, a registry root that no longer exists, and a root where the local entry was deliberately set to false.
- Add an acceptance line for a session in a nested git repository under a registered root (the live case G gap): it lists the `agent-workspace:` skills after the change.
- Plan the PR so the dead-code removal is a separate commit from the install-and-migrate change, and decide in the plan whether it is one PR or two.

### Actions
- [ ] The issue does not say that the per-root machinery (skip rules, `parent=` handling, nested-repository refusals, `--disable-root`, rollback of a root enable) is removed rather than adapted. State it as in scope, otherwise the change adds a user-scope path on top of dead per-root code.
- [ ] The 2026-10-13 spike facts are a month old on Claude Code 2.1.296; the issue says to re-check them. Make the re-check a named first step with its result recorded, covering: the committed `enabledPlugins` false entry stops doubling in the workspace checkout and its worktrees; the same entry covers the `p11-*` roots inside the workspace tree; narrower scope wins in a session in a nested repository.
- [ ] State in the Not-in-scope/What-is-needed sections that the per-root special cases (workspace-tree skip, `parent=` handling, nested-repository refusal, `--disable-root`, root-enable rollback) are removed, and name `register_project.sh --remove` and its rollback as affected.
- [ ] Make fixing #394 a precondition inside this issue's PR (or an earlier PR that merges first); drop the "or say why it can stay separate" option, since the idempotence acceptance line depends on it.
- [ ] Add the migration cases to the issue: per-root entries removed through the CLI, a registry root that no longer exists, and a root where the local entry was deliberately set to false.
- [ ] Add an acceptance line for a session in a nested git repository under a registered root (the live case G gap): it lists the `agent-workspace:` skills after the change.
- [ ] Plan the PR so the dead-code removal is a separate commit from the install-and-migrate change, and decide in the plan whether it is one PR or two.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 11:45 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review keeps the owner's decision and the issue's goal; its five actions are about how the change is built: remove the per-root machinery rather than keep it beside the new path, fix issue 394 first or in the same pull request, name the migration cases, add a nested-repository acceptance line, re-run the 2026-10-13 spike as a recorded first step. None adds or drops a behaviour his words ask for)
**After**: issue-actions
**Decision**: proceed

The host read the Issue Review entry at 3c1e5e4c. The plan takes all five actions as requirements. Listed for the owner's veto: issue 394 becomes a precondition inside this work; the installer's per-root enable and its --disable-root flag go, with per-root opt-out left to a root's own settings (narrower scope wins, to be re-verified by the spike step); ADR-0016 decision 2 and ADR-0018 decisions 3 and 4 are amended.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 11:49 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-446/plan.md` at `ef7fd2cc`

Two PRs: first the 394 hook-marker fix, then one PR for user-scope install, migration of per-root entries through the CLI, and removal of the per-root machinery as its own commit, with ADR-0016/0018 and design.md amended in it. The spike was run on Claude Code 2.1.322 in a scratch HOME: CLI facts verified (user-scope writes only under the scratch ~/.claude; committed-off entry holds in a worktree; narrower scope wins), session-level facts (root inside the workspace tree, nested repository) need a model session and are the implement pass's step 1 with a stop condition.

## Plan Review
**Status**: complete
**When**: 2026-11-12 11:54 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #446 — Enable the agent-workspace plugin once for the whole machine (user scope), as decided 2026-10-13
**Plan**: `.agent/work-plans/issue-446/plan.md` at `ef7fd2cc`
**Branch**: `feature/issue-446`

Checked against the code (`user_tier_install.sh`, `register_project.sh`, `skill_prefix.sh`, `session_root.sh`, their tests, `tests/live/plugin_acceptance.sh`), ADR-0016, ADR-0018, `docs/design.md`, the issue, issue 394, the #332 decision comment, and the Issue Review and Checkpoint entries. Four CLI facts were re-checked in a scratch HOME (`CLAUDE_CONFIG_DIR` unset, Claude Code 2.1.322, no session started):

- A user-scope `disable` then `enable` still drops `_agent_workspace` from every hook entry; the allow-rules and an unknown top-level key survive; the top-level keys are reordered.
- A second user-scope `marketplace add` of the same name from another path repoints both `~/.claude/settings.json` `extraKnownMarketplaces` and `plugins/known_marketplaces.json` ("now points at ..."). So the user-scope add is the takeover, and dropping `claim_machine_record` holds (the plan's third unverified fact, CLI part).
- With the marketplace declared at user scope, a local `uninstall` and `marketplace remove --scope local` run from a legacy root kept the machine record and left `{"enabledPlugins":{},"extraKnownMarketplaces":{}}` in the root.
- `plugins/installed_plugins.json` records every local-scope install as `{"scope":"local","projectPath":"<root>"}`.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Two pull requests: A = issue 394 alone, B = this issue with the deletion as its own commit. That is the split the issue review asked for. Sequencing of A and B is not stated (finding 9). |
| Issue alignment | Needs work | Covers every "What is needed" line and the review's five actions. The migration misses roots whose own directory is not their git toplevel, and legacy enables in roots no longer registered (finding 4). Step 1 cannot run as written (finding 1). Serves: "Light touch on projects (the workspace stops writing a plugin entry into each project root) and Easy to use (one install per machine) -- `docs/design.md#sessions-and-roots`". Both are README goal sections, and the design section is right. |
| File targeting | Needs work | Not listed: `tests/test_user_tier_guard.sh`, `.agent/knowledge/principles_review_guide.md`, and the unconditional `docs/design.md` root-rule edit (finding 7). |
| Consequences | Needs work | Same as finding 7. Also not stated: whether registration still runs `registration_verify.sh --user-tier` once it no longer runs the installer. |
| Principle alignment | Needs work | "Verify before claiming": step 1 has no runnable path and no owner answer for one (finding 1). "Only what's needed": the per-root code is deleted, not kept, which is good. The in-tree fallback, though, keeps a rule for a failure it does not cure (finding 2). |
| ADR compliance | Good | ADR-0018 decisions 3, 4 and 6 and the alternatives are amended, the ADR-0016 exception is withdrawn, and ADR-0017's same-change design update is planned. One departure from the recorded #332 wording should be listed for veto (finding 10). |
| ROS conventions | N/A | Workspace plan |

The three mechanism choices:

- **Two pull requests.** Sound. Issue 394 is independently mergeable, and B's idempotence line depends on it. Say how B is based (finding 9).
- **`register_project.sh` no longer runs the installer.** Sound. After user scope, nothing per root is left for registration to do. Keeping `--install-user-tier` is harmless.
- **`session_root.sh` keeps refusing a nested package repository.** Defensible, provided the reworded reason is a true one (finding 8).

Additions the issue does not ask for:

- a follow-up issue on relaxing `session_root.sh`
- `--check` checking the committed `false` entry
- a test that pins that entry

All three are small and in keeping with the issue. No significant scope creep.

### Findings

1. **[Principle alignment: Verify before claiming] (must-fix)** — An implement sub-agent cannot run step 1's live check as planned. A live session needs auth, and the plan's own spike says a scratch HOME has none. Dispatched phases are told never to touch the real `~/.claude`. The existing suite gets auth by using the real HOME, and it only ever enables at local scope in sandbox directories. Its header promises it never touches `~/.claude/settings.json`. A user-scope case there would enable the renamed plugin in the owner's real `~/.claude/settings.json`. That would (a) put the test plugin into every one of his concurrent sessions while it runs, (b) strip his real hook markers (issue 394) unless PR A is already installed, and (c) leave the plugin enabled machine-wide if the run dies. The plan must say how step 1 gets an authenticated session. There are three ways: the owner runs it himself; he allows a temporary user-scope enable in his real `~/.claude`; or he provides a token for a scratch `CLAUDE_CONFIG_DIR`. Choosing between them is the owner's decision (his credentials and his live sessions). Until it is answered, step 1 is blocked and its stop conditions cannot fire.
2. **[Approach: stop conditions] (should-fix)** — The plan lists the in-tree root (the `p11-*` shape) both as a stop and as "a documented narrowing, not a stop". The narrowing keeps "the registry-based rule for roots inside the workspace tree" in `skill_prefix.sh`. But `skill_prefix.sh` answers bare for those roots by its git common-dir comparison (rule 1), not from the registry, and it stays right whatever step 1 finds. If the committed `false` does not reach such a root, the failure is somewhere else: a session there lists every skill twice (bare by walk-up, as live case E saw, plus `agent-workspace:` from user scope). Only a per-root `false` written into that root cures it, which brings back a per-root write. Make it a stop: it trades "simplify" against "never doubled", which is the owner's to weigh. Drop the `skill_prefix.sh` fallback.
3. **[Approach: step 1 cases] (minor)** — Step 1's live cases lack the deliberate opt-out: a session in a root whose local entry is `false` while user scope is `true`. The migration rule "false stays false" rests on that case. The spike checked it only through `plugin list` at a repository root, and the plan itself says `plugin list` is no proxy for sessions.
4. **[Approach: migration] (should-fix)** — `migrate_legacy_root` has two gaps.
   - **Wrong file for some roots.** It reads `<root>/.claude/settings.local.json`, but it runs `claude plugin ... --scope local` from the root. From a plain subdirectory of a git repository, the CLI writes the toplevel's file instead (live case K). Two root shapes are affected: an in-tree `p11-*` root, and a `parent=` instance that is a plain directory of its parent's repository. For those, the CLI changes the toplevel's file and leaves the root's own entry, so every run finds and "migrates" it again (not idempotent) and `--check` notes it forever. The old installer refused the CLI there for this reason (`enclosing_repo`, `instance_cli_reason`), and step 3 deletes that logic. Migration should run the CLI only where the root is its own toplevel or in no git repository. Elsewhere it should report the entry for hand removal, or the plan should say why such an entry cannot exist.
   - **Roots no longer registered.** The registry scan misses a legacy enable in a root that was unregistered by hand or moved. The CLI's own record lists every local install with its path (`plugins/installed_plugins.json`, `"scope":"local","projectPath":...`, checked above). The issue's "no root left with a stale local entry" needs that record as a second source, or a stated limit.
5. **[Approach: install idempotence] (should-fix)** — Install's no-CLI shortcut checks only `~/.claude/settings.json` (enabled, source path is `WS_PHYS`). It does not check `plugins/known_marketplaces.json`, which the plan's `--check` does flag. Live case J saw a local `marketplace remove` drop that machine record when no other declaration held it. A re-run that finds settings.json correct and skips the CLI then never repairs what `--check` reports. Two changes fix it:
   - Make the shortcut also require the machine record.
   - Fix the order: user-scope add and install first, then migrate. Run today on 2.1.322, a local remove with the user-scope declaration already present kept the record.
6. **[PR A sufficiency] (should-fix)** — PR A's command-path matching fixes the two symptoms of issue 394 (false drift, duplicated hooks); the strip was re-checked above on 2.1.322. Three gaps remain:
   - **(a) Retired hooks.** PR A matches only the current commands (`log-tool-use.sh` and `SESSION_HOOK_LINK`). The retired-hook check (#328; `user_tier_install.sh` around lines 1095-1115; the test at `test_user_tier_install.sh:305`) only looks at tagged entries. An unmarked retired entry would then be invisible to `--check` and to install's replacement. Treat as ours any command under `$WS_ROOT/.claude/hooks/`, plus the link.
   - **(b) Re-run changes the file.** Install rewrites settings.json on every run. It re-adds the marker the CLI stripped, and writes jq's key order instead of the CLI's. So after any CLI call, a re-run changes the file, against PR B's "re-running changes nothing". Either stop writing the marker (with command-path matching it carries nothing the command does not), or skip the write when the merged result equals the current one (`jq -S` compare). Test with a stub CLI that strips markers and reorders keys on every call.
   - **(c) Foreign-checkout fallback.** Matching by the suffix `.../.claude/hooks/log-tool-use.sh` outside this checkout can catch an unrelated repository's same-named hook (the fork has the same layout). Recognise another checkout the way `foreign_skill_link` does: `<dir>/.agent/user_tier_scripts.txt` exists.
7. **[File targeting / Consequences] (should-fix)** — PR B breaks or makes false three things the plan does not list.
   - `.agent/scripts/tests/test_user_tier_guard.sh` lines 249-272 assert that `skill_prefix.sh` exits 1 ("neither in the workspace checkout") from an unregistered repository. Step 4 makes it print `agent-workspace:` there.
   - `.agent/knowledge/principles_review_guide.md` line 53 (the ADR-0018 row, which every review applies) says "enabled at local scope per registered root ... the only write into a project checkout is ... `settings.local.json`".
   - `docs/design.md` lines 205-207 justify the `session_root.sh`/`skill_prefix.sh` refusal by "sessions do not read the root's local settings". The plan makes that edit conditional on step 1, but the sentence is false after PR B whatever step 1 finds.
8. **[Mechanism choice: session_root.sh] (minor)** — Keeping the refusal is defensible, but the plan does not say what the reworded reason is. The comment at `session_root.sh` lines 149-155 gives one reason: "neither the root's plugin nor its layer reaches the session". After PR B the plugin does reach it. The reason that remains is `docs/design.md`'s "A multi-repo project's root is its registered hosting directory, never a package repository nested in it" (around line 200). Cite that, so the refusal keeps a true reason.
9. **[Scope: sequencing] (minor)** — PR A is issue 394's, but the plan does not say where it is built (its own worktree, branch from main and timeline). Nor does it say whether PR B's branch is stacked on A's or waits for A to merge. The merge is the owner's call, so waiting adds an owner round trip before B's tests can run. Say which.
10. **[ADR / recorded decision] (minor)** — The #332 decision comment says "the installer ... writes the workspace override". The installer header (lines 100-102) calls the tracked `.claude/settings.json` Ask-First. The plan commits the `false` entry instead. That is simpler, and every clone gets it, but it departs from the recorded wording. Add it to the veto list.

### Summary

The plan's shape is right: issue 394 first, user scope with the per-root code deleted in its own commit, and the records in the same change. The CLI facts it builds on hold on 2.1.322. It is not ready to implement:

- Step 1's live check has no runnable path without an owner decision on auth.
- Two of its fallbacks are aimed at the wrong mechanism (the in-tree root, and migration from a non-toplevel root).
- PR A needs its "ours" definition and its write idempotence tightened.

### Recommended Actions

- [ ] Ask the owner how the step-1 live sessions get auth (he runs it; a temporary user-scope enable in his real `~/.claude`; or a token for a scratch `CLAUDE_CONFIG_DIR`), and write the answer into step 1 (finding 1)
- [ ] Make "the committed `false` does not reach an in-tree root" a stop, and drop the `skill_prefix.sh` fallback (finding 2); add the local-`false` opt-out session case (finding 3)
- [ ] In migration: run the CLI only where the root is its own toplevel or in no git repository, report the rest; add `installed_plugins.json` as the source for unregistered roots; order user-scope add before migration, and make the no-CLI shortcut require the machine record (findings 4, 5)
- [ ] In PR A: treat any command under `$WS_ROOT/.claude/hooks/` as ours; stop writing the marker or skip a no-op write; recognise a foreign checkout by `.agent/user_tier_scripts.txt` (finding 6)
- [ ] Add `test_user_tier_guard.sh`, `principles_review_guide.md` and the unconditional `docs/design.md` root-rule edit to the file list (finding 7); name `session_root.sh`'s new reason (finding 8); say how PR A and PR B are sequenced (finding 9); list the committed-entry departure for veto (finding 10)

## Checkpoint
**Status**: complete
**When**: 2026-11-12 11:56 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's verdict is needs-work: one must-fix and nine smaller findings, all about how the change is built and verified, none a change to what the owner asked for; first host revise on this plan)
**After**: plan
**Decision**: revise

The host read the Plan Review entry at 0cbb326d. Findings 2 to 10 are taken as written. Finding 1 (an implement sub-agent cannot start an authenticated live session without touching the owner's real ~/.claude) has a part only the owner can answer, how the live sessions are authenticated; it is put to him separately. The revised plan writes step 1 for the host's recommended answer (the live case runs after pull request A is merged and installed, with a renamed test plugin enabled at user scope in the real ~/.claude for the minutes it runs, removed on exit) and marks it as waiting for his yes; no live session starts before it. Pull request A does not depend on that answer.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 11:58 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-446/plan.md` at `2d29b087`

Revision answering the ten findings of the plan review. Pull request A (issue 394) moves to its own worktree and timeline because dispatch_phase.sh next ends a timeline at one merged pull request; B follows on this branch after A is merged, with main merged in. Step 1's live check is written for the recommended answer (user-scope cases in the opt-in live suite, trap-removed) and waits for the owner's yes; the in-tree root failing is a stop and the skill_prefix.sh fallback is dropped. Migration, install idempotence, PR A's hook matching and write skip, the added files, and the committed-entry veto item are in the plan.

## Plan Review
**Status**: complete
**When**: 2026-11-12 12:02 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #446 — Enable the agent-workspace plugin once for the whole machine (user scope), as decided 2026-10-13
**Plan**: `.agent/work-plans/issue-446/plan.md` at `2d29b087`
**Branch**: `feature/issue-446`

Second review. It re-checks the ten findings of the Plan Review at `ef7fd2cc` against the revision at `2d29b087`, and looks for anything the revision broke or added.

Checked against:

- `user_tier_install.sh`: the header, the hook merge at lines 1306-1350, `backup_settings`, `foreign_skill_link`, the `--check` hook checks at lines 1052-1115, and the per-root helpers at lines 486-740
- `test_user_tier_install.sh` around lines 253-342 and 440-470
- `tests/live/plugin_acceptance.sh`: header, `cleanup`, `trap`, the copy setup
- `session_root.sh` lines 145-158
- `docs/design.md` lines 198-208, 246-252, 312-321, 744, 767
- `principles_review_guide.md` line 53
- `registration_verify.sh` and `register_project.sh` (the `--user-tier` path)
- `dispatch_phase.sh` phase routing
- `.gitignore`
- issue 394

A scratch-HOME CLI check of where `--scope local` writes from a linked worktree was denied by the permission system. Finding 4 below is therefore argued from the code's own comment, not observed.

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | A is now issue 394 on its own worktree and timeline. B follows on this branch after A merges. That matches `dispatch_phase.sh` (one timeline, one merged pull request). Earlier finding 9 is resolved. |
| Issue alignment | Good | Serves, as checked: "Light touch on projects (the workspace stops writing a plugin entry into each project root) and Easy to use (one install per machine) -- `docs/design.md#sessions-and-roots`". Both are README goal sections. |
| File targeting | Good | `test_user_tier_guard.sh`, `principles_review_guide.md` line 53 and the unconditional design root-rule edit were added. Earlier finding 7 is resolved; the line references were checked and are right. |
| Consequences | Good | `registration_verify.sh --user-tier` stays as a read-only check after registration. That answers the first review's open consequence. |
| Principle alignment | Needs work | "Verify before claiming": step 1 is safe in what it touches, but it cannot run as written, and its stop does not hold (findings 2 and 3). "Test what breaks": A loses a check it has today (finding 1). |
| ADR compliance | Good | Unchanged from the first review. The committed-entry departure from the issue 332 wording is now on the veto list (earlier finding 10 resolved). |
| ROS conventions | N/A | Workspace plan |

Status of the first review's findings:

- **Resolved:** 2 (stop made, fallback dropped), 3 (the local-`false` case added), 5 (the shortcut requires the machine record; install runs before migration), 6b (marker no longer written; a write that changes nothing is skipped), 6c (`user_tier_scripts.txt`), 7, 9, 10.
- **Resolved, with a new gap:**
  - 1: waits for the owner's yes, but see findings 2 and 3 below.
  - 4: the subdirectory roots and `installed_plugins.json` are handled, but see finding 4 below.
  - 6a: any command under the hooks directory counts as ours, but see finding 1 below.
- **Partly resolved:** 8 (see finding 6 below).

**Pull request A: not ready, by one sentence.** Its section is otherwise complete enough to implement with no further planning:

- the ownership rule
- the foreign-checkout rule
- the marker dropped, with the fallback stated
- the no-op write skip, whose test also requires no backup (so `backup_settings` at line 1281 must move behind the comparison)
- `.gitignore` (the entry is absent today, checked)
- the stub-CLI test that strips markers and reorders keys

Issue 394's own loop still runs review-issue, plan-task and review-plan first, because `dispatch_phase.sh` routes an empty timeline to review-issue. Its plan-task pass copies this section.

### Findings

1. **[PR A: moved or deleted checkout] (should-fix)** — PR A drops every reader of `_agent_workspace`, so "ours" and "another checkout's" are decided by path alone. A checkout that was moved or deleted after an install leaves hook entries whose commands are under a directory that no longer exists. Such an entry is not under `$WS_ROOT/.claude/hooks/`, and it has no `.agent/user_tier_scripts.txt`. So `--check` stops reporting it, and `--force` stops removing it. Today the marker catches both: the "foreign" check at lines 1067-1076, the "points outside this checkout" check at lines 1082-1093, and the `--force` jq at lines 1343-1344. The dead PreToolUse command then fails on every tool call, machine-wide, and nothing reports it. That is a silent failure the current code does not have. Fix (one sentence in PR A step 1/2): keep reading the marker when present, and stop only writing it. Or report as drift any hook entry whose command path ends in `/.claude/hooks/log-tool-use.sh` and does not exist on disk. Either way, add the moved-checkout case to step 4's tests.
2. **[PR B step 1: who writes the live cases, and when the stop bites] (should-fix)** — Step 1 is commit 1 of B, and it says the run happens "before B's implementation starts". But the user-scope cases in `plugin_acceptance.sh` are code, the plan does not say who writes them, and `dispatch_phase.sh` routes a ready plan to one implement phase, "implement the plan at .agent/work-plans/issue-446/plan.md". An implement pass dispatched as usual would write the suite, skip the run (it is told not to run it), and go on to steps 2-8. The stop conditions would then come too late to stop anything. Say which of these it is, and that steps 2-8 wait for the FACT lines:
   - the first implement dispatch for B is limited to the suite commit and ends with a hand-back;
   - or the host writes the cases himself.
3. **[PR B step 1: the copy needs the renamed off entry] (should-fix)** — The suite runs on a copy of the checkout (`cp -r "$WS_ROOT/.claude" ... "$W/"`) whose plugin is renamed `aw-accept-<pid>`. Step 1 runs before step 5 commits the off entry, and that entry names `agent-workspace@agent-workspace`, which would not cover the renamed plugin anyway. As planned, the "committed-off repository" case has nothing turning the test plugin off. A session at the copy's root would then list the probe twice, and the first stop condition would fire on a test defect. State that the suite writes `"aw-accept-<pid>@aw-accept-<pid>": false` into the copy's `.claude/settings.json`, and commits it before the worktree case is made.
4. **[Migration: linked-worktree roots] (should-fix)** — `migrate_legacy_root` runs the CLI where "the root is its own git toplevel". A linked git worktree is its own toplevel, so the rule admits it. The code being deleted says, at `instance_cli_reason` lines 715-722, that "where the claude CLI's local scope writes from a worktree is not established". `same_project`'s comment records live case G: a session in a worktree reads the main repository's local settings. If the CLI there writes the main repository's file too, the result has the same non-idempotence earlier finding 4 fixed for plain subdirectories. Possible effects:
   - the worktree's own entry stays, and every run finds it again;
   - and the main repository's local `false`, a deliberate opt-out, could be removed.
   Require git-dir equal to git-common-dir (not a linked worktree) for the CLI path, and give a linked worktree the report-only path. Or add a scratch-HOME check of where `--scope local` writes from a worktree, and its result, to step 1's CLI facts.
5. **[Migration: what repeats, and the read-back after it] (minor)**
   - "A second run finds nothing to migrate and prints nothing about it" is not true for two kinds of entry, which get a note on every run: a report-only entry (plain subdirectory or worktree), and an `installed_plugins.json` `projectPath` that no longer exists. That is acceptable, but say so. For the gone `projectPath`, give the hand removal: the CLI cannot be run from a directory that does not exist.
   - Read the user-scope state and the machine record back after migration as well, and fail if they are lost. Whether a local `uninstall` with the same plugin installed at user scope leaves the user-scope install intact has not been checked on 2.1.322; the first review checked only the marketplace record.
6. **[session_root.sh reason: the second shape] (minor)** — The refusal at lines 149-155, and `docs/design.md` lines 205-207, cover two shapes:
   - a package repository nested in a root;
   - a subdirectory of a root in no git repository.
   The planned new reason, "a multi-repo project's root is its registered hosting directory, never a package repository nested in it", covers only the first. Give the second shape a true reason, or say it is relaxed (the follow-up issue may take it).
7. **[Stale text after the revision] (minor)** Three places still contradict the revised plan:
   - Context "Not verified" still lists "What a second `marketplace add` of the same name from a different path at user scope does", and Prior Art says `claim_machine_record` is dropped "unless the unverified third spike fact says otherwise". Approach step 2 records that the first review verified it.
   - Design Picture says "the nested-repository note if step 1 changes it", while step 6 makes that edit unconditional.
   Align them, so the implement pass does not reopen a settled point.
8. **[Live run safety extras] (minor)** — The suite's trap is `trap cleanup EXIT` only (line 181). For the user-scope cases:
   - also trap INT, TERM and HUP;
   - record "user-scope enabled" before the CLI call, the way `ENABLED_ROOTS` is recorded today;
   - print a removal line that names both commands: `claude plugin uninstall aw-accept-<pid>@aw-accept-<pid> --scope user` and `claude plugin marketplace remove aw-accept-<pid> --scope user`;
   - and compare the real `~/.claude/settings.json` under `jq -S` before and after. Leftover empty objects are expected; any other difference is printed, since the CLI's rewrite races the owner's concurrent sessions.

   As written, the removal touches only `$NAME`, and the cache removal is `plugins/cache/${NAME:?}`. The real `agent-workspace` entry is never named, and no live session starts before the owner's yes. Step 1 is safe in what it touches.

### Summary

The revision answers the ten findings. Pull request A is one sentence short of ready: keep the marker as a read signal, or report dangling hook commands. Pull request B's live step is safe in what it touches, but needs two fixes before it can run as a real gate: who writes the cases, so that steps 2-8 wait; and the renamed off entry in the copy. Migration needs the linked-worktree guard the deleted code had.

### Recommended Actions

- [ ] PR A: keep reading `_agent_workspace` when present, and stop only writing it (or report dangling hook commands as drift); add a moved-checkout test (finding 1)
- [ ] PR B step 1: say who writes the user-scope suite cases, and that steps 2-8 wait for the FACT lines (finding 2); the copy gets `aw-accept-<pid>@aw-accept-<pid>: false` in its committed `.claude/settings.json` (finding 3)
- [ ] Migration: no CLI from a linked worktree, or establish where local scope writes from one (finding 4); state which notes repeat, and read the user-scope state back after migrating (finding 5)
- [ ] Reason for the non-git-subdirectory refusal (finding 6); remove the stale "unverified" lines and the conditional Design Picture wording (finding 7); trap signals and diff the real settings around the live run (finding 8)

## Checkpoint
**Status**: complete
**When**: 2026-11-12 12:03 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second plan review found all ten earlier findings answered and eight new ones, four should-fix and four minor, each a sentence or short paragraph of plan text and none a change to what the owner asked for; second host revise in a row on this plan, so the next plan answer other than proceed is the owner's)
**After**: plan
**Decision**: revise

The host read the Plan Review entry at 03821f15. All eight findings are taken as written, with these choices where the reviewer offered two: finding 1, keep reading the marker when present and stop only writing it; finding 2, the first implement dispatch for pull request B is limited to the live-suite commit and ends with a hand-back, and steps 2 to 8 wait for the FACT lines on the timeline; finding 4, the CLI path requires git-dir equal to git-common-dir and a linked worktree gets the report-only path; finding 6, the second shape (a subdirectory of a root in no git repository) keeps its refusal with its own true reason. Pull request A is driven on issue 394's own worktree and timeline, starting now; its plan pass copies this plan's A section with finding 1's sentence.

## Plan Authored
**Status**: complete
**When**: 2026-11-12 12:05 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-446/plan.md` at `8e9e97c1`

Second revision answering the eight findings of the plan review at 03821f15 with the host's choices: the marker is still read and no longer written, with a moved-checkout test; B's first implement dispatch is limited to the live-suite commit and ends with a hand-back; the copy gets its renamed off entry; the CLI migration path excludes linked worktrees; repeated notes and read-back stated; the second session_root shape has its own reason; stale passages aligned; four live-run safety extras added. A sequencing note sits at the top.

## Plan Review
**Status**: complete
**When**: 2026-11-12 12:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: ready

**Issue**: #446 — Enable the agent-workspace plugin once for the whole machine (user scope), as decided 2026-10-13
**Plan**: `.agent/work-plans/issue-446/plan.md` at `8e9e97c1`
**Branch**: `feature/issue-446`

Third review, a narrow convergence check. It checks the eight findings of the Plan Review at `03821f15`, with the host's choices in the Checkpoint at `8b229638`, against the revision at `8e9e97c1`. It does not re-review what the first two reviews passed and this revision did not touch.

Checked against:

- the plan diff `2d29b087..8e9e97c1`
- `user_tier_install.sh`: `TAG` (line 147), `SESSION_HOOK_LINK` (line 144), the marker readers (lines 991, 1058, 1069, 1084, 1106, 1343-1344) and writers (lines 1312, 1320)
- issue 394's body: "Any `claude plugin` command that rewrites that file ... drops the field"
- `session_root.sh` lines 123-160
- `skill_prefix.sh` lines 33-37 (live case G) and 80-115
- `docs/design.md` lines 193-208 and 248-256
- `tests/live/plugin_acceptance.sh` lines 11, 181, 216, 236
- the shape of `installed_plugins.json` (read only)

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Unchanged. The sequencing note at the top matches the Checkpoint. |
| Issue alignment | Good | Serves, as checked: "Light touch on projects (the workspace stops writing a plugin entry into each project root) and Easy to use (one install per machine) -- `docs/design.md#sessions-and-roots`". |
| File targeting | Good | Unchanged. |
| Consequences | Good | The repeated notes, the read-back after migration and the linked-worktree test are in step 7. |
| Principle alignment | Needs work (small) | "Verify before claiming": the new reason for the second refusal shape is not true (finding 2). "Test what breaks": the chosen fix for the moved-checkout hook covers almost no real entry (finding 1, PR A only). |
| ADR compliance | Good | Unchanged. |
| ROS conventions | N/A | Workspace plan |

Status of the second review's eight findings:

- **Resolved:**
  - 2: the first B dispatch is limited to the suite commit and ends with a hand-back; steps 2 to 8 wait for the FACT lines.
  - 3: the copy gets `"aw-accept-<pid>@aw-accept-<pid>": false` and commits it. The copy is `git init`ed (suite line 236), so the commit can be made.
  - 4: the CLI path needs git-dir equal to git-common-dir; a linked worktree is report-only; a test was added.
  - 5: the repeated notes are stated; the read-back of the user-scope state and the machine record is added and tested.
  - 7: the "Not verified" line, the Prior Art line and the Design Picture wording are aligned. No stale "unverified third fact" text remains.
  - 8: all four extras are in. They are the signal traps, the record before the call, the two-command removal line, and the `jq -S` diff of the real settings.
- **Written as chosen, but not resolved in effect:** 1 (finding 1 below).
- **Written as chosen, but the reason is not true:** 6 (finding 2 below).

The revision added nothing unasked. The `backup_settings` move and the sequencing note both come from the second review and the Checkpoint.

### Findings

1. **[PR A: reading the marker does not catch a moved checkout after B] (should-fix, PR A section only)**
   - The host chose "keep reading the marker when present, stop only writing it".
   - That keeps the check only for entries that still carry the marker. Issue 394's own finding is that every `claude plugin` command that rewrites `~/.claude/settings.json` drops the marker.
   - PR B's install makes user-scope `claude plugin` calls. So after B's first install, no hook entry on the machine carries a marker.
   - From then on, the case finding 1 described is back, with nothing to report it. A checkout is moved or deleted. Its `log-tool-use.sh` PreToolUse command points at a path that no longer exists. That entry is not under the new `$WS_ROOT/.claude/hooks/` and has no `user_tier_scripts.txt`, so neither `--check` nor `--force` sees it.
   - The new step-4 test uses a marked entry, so it passes while the real case fails.
   - This is my second review's mistake: it offered the two fixes as equal, and they are not.
   - Fix: add the second rule as well. Any hook command whose path ends in `/.claude/hooks/<a hook the installer writes or has retired>` and does not exist on disk is drift for `--check`, and install and `--force` remove it.
   - Test it with an unmarked entry pointing into a deleted checkout.
   - The SessionStart entry names the `~/.claude` link, not the checkout (line 144), so only the PreToolUse command needs this.
   - Issue 394's plan pass, now running, copies this section, so this sentence has to reach it. PR B's build is not affected.
2. **[PR B step 6: the reason for the second refusal shape is not true] (should-fix, wording only)**
   - The plan says a subdirectory of a root in no git repository is refused because "the session's layer (the root's settings and adapter) is found from the session's git toplevel, which such a directory lacks, so ... no root's layer can be located from it". Step 6 puts the same words into `docs/design.md` lines 205-207.
   - First, the root can be located from that directory. `session_root.sh` finds it by registry prefix (`root_of`, line 143) before the refusal, and the refusal message names it ("start the session at $S_ROOT").
   - Second, the mechanism is wrong. The recorded rule (live case G) is that outside git a session reads the settings of **its own directory**: `session_root.sh` lines 149-155, `skill_prefix.sh` lines 33-37, `docs/design.md` lines 205-206. It does not fail to find a toplevel and then read nothing.
   - Third, "adapter" is probably wrong too. Claude Code loads `CLAUDE.md` from the cwd and its parent directories, so the root's adapter likely does reach such a session. This was not checked live here.
   - True reason, to use in both places: "a session started outside git reads the settings of its own directory, so the root's `.claude/settings.json` and `.claude/settings.local.json` (its hooks and permission rules) never reach a session in a subdirectory of the root".
   - That is the same kind of reason as shape 1, a different directory's settings. It is also what the refusal message at line 159 already says.
3. **[PR B step 2: the hand removal names a list that does not exist] (minor)**
   - The note for a `projectPath` that no longer exists says "delete that entry from the `local` list of `~/.claude/plugins/installed_plugins.json`".
   - The file has no such list. `.plugins["agent-workspace@agent-workspace"]` is an array of objects, each with its own `scope` and `projectPath` (plan line 240 describes it right).
   - The note should say: delete the object with `"scope": "local"` and that `projectPath` from that array.

### Summary

Six of the eight findings are resolved as written, and the revision broke nothing in PR B. Two choices fall short in effect.

- Finding 1's marker read stops working once B's first `claude plugin` call strips the markers. PR A also needs the dangling-path rule.
- Finding 6's new reason is false. A one-sentence true reason is given above.

Neither changes what PR B builds, and the step-6 wording can be carried by the implement pass. The PR A sentence has to reach issue 394's plan pass, which is running now.

### Recommended Actions

- [ ] PR A, on issue 394's plan: also report and remove any hook command under `.../.claude/hooks/` whose path does not exist on disk, and test it with an unmarked entry (finding 1)
- [ ] PR B step 6 and the `docs/design.md` edit: use the true reason for the second shape, the root's settings files never reach a session outside git in a subdirectory (finding 2); the implement pass can carry it
- [ ] PR B step 2: describe the hand removal by `scope` and `projectPath` inside the plugin's array (finding 3); the implement pass can carry it

## Checkpoint
**Status**: complete
**When**: 2026-11-12 17:39 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the third plan review's verdict is ready; its two open boxes for pull request B are wording the implement pass carries, and its pull request A box was for issue 394, merged as pull request 450)
**After**: plan
**Decision**: proceed

The host read the Plan Review entry at 43014931. Pull request A (issue 394) is merged and main is merged into this branch (dc7ca120). The owner approved the live check as the plan recommends (a temporary aw-accept-<pid> plugin at user scope in the real ~/.claude), recorded by the host session of 2026-11-12. The installer has not been re-run on this machine yet (--check reports each hook registered three times); that run edits the owner's real ~/.claude/settings.json and waits for his yes. It is needed before the live suite is run, not before the suite is written, so the first implement dispatch goes ahead, limited as the plan says to step 1's suite commit and ending with a hand-back. Findings 2 and 3 of the review (the true reason for the second refusal shape; the hand removal described by scope and projectPath) go into the later dispatch for steps 2 to 8.

## Implementation
**Status**: complete
**When**: 2026-11-12 18:21 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-446 at `72d40918`

Limited dispatch: step 1's live-suite commit only; steps 2 to 8 not started, the suite not run.

What changed, all in `.agent/scripts/tests/live/plugin_acceptance.sh` (commits `ea8f955e`, `72d40918`):

- **Case selection**: `PLUGIN_ACCEPTANCE_CASES` is `per-root` (the default, cases A to K as before), `user` (only U0 to U8), or `all` (A to K, then U0 to U8). Any other value exits 2.
- **U0 setup**: the copy's `.claude/settings.json` gains `"aw-accept-<pid>@aw-accept-<pid>": false` under `enabledPlugins` and is committed in the copy before the committed-off and worktree cases (a PASS line checks `HEAD:.claude/settings.json`). The copy also gets a `.gitignore` with `projects/` and `.claude/settings.local.json`, the two lines of the real one that bear on the in-tree shape. Then the plugin is enabled at user scope from the sandbox, after checking that the sandbox is in no git repository.
- **Cases U1 to U8**: committed-off repository root, a plain subdirectory root of it, a worktree of it, an in-tree root, a repository nested in an ordinary root, an unregistered folder, local `true` plus user `true`, and a local `false` under user `true` (its own control skill must answer first). Each prints one FACT line. After them come four STOP-CHECK lines, one per stop condition of the plan, and a CHECK U7 line for "listed once" (not a stop condition; step 2's migration rests on it).
- **Safety extras**:
  - Traps on EXIT, INT, TERM and HUP. The signal traps exit, so cleanup runs once, and cleanup ignores further signals.
  - `USER_ENABLED=1` is set before the CLI call.
  - The two hand-removal commands, plus the cache path, are printed at the start, before the sandbox is made.
  - The real settings file is compared under `jq -S` before and after. Empty objects are pruned on both sides and expected; any other difference is printed as a FACT, not counted as a failure.
  - The suite removes the user-scope enable at the end of the cases (U-end) and again in cleanup if it is still there.
  - The real `agent-workspace` entry is never named.
- **Header**: the old promise ("never touches `~/.claude/settings.json`") is rewritten. It now says the per-root cases never touch the file, and the user-scope cases add the two entries for the minutes they take, then remove them, as described above.
- **Per-root cases**: unchanged. Their probe helpers moved above them so both groups share them. They sit in an `if` block that is not re-indented, because re-indenting would put leading spaces into their heredoc SKILL.md files.
- **Second commit**: `test_plugin_acceptance_helpers.sh` evals the suite's text from `ENABLED_ROOTS=()` to the sandbox line under `set -u`. The first commit's start-of-run print in that range read `RUN_USER`, unbound there, which failed 3 helper checks. The print, `REAL_SETTINGS` and `user_removal_lines` moved above that range.

Checks run:

- `bash -n`: ok.
- shellcheck: `--severity=warning`, the hook's level, is clean. At info level there are only SC2015 notes, the existing `&& pass || fail` style.
- `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP on `72d40918`: exit 0, the script test suites included.

Not done, and why:

- A dry check of the new jq filters against synthetic stream-json and settings data was denied (the dispatch limits checks to `bash -n` and shellcheck). Left as is.
- The `us_session` stream-json init-line shape (`slash_commands`) is assumed, not observed. If it differs, U7 FAILs loudly saying so, and the other cases are unaffected unless the result line is missing too, in which case every session reads as failed.
- `test_plugin_acceptance_helpers.sh` has no case yet for cleanup's new user-scope branch. This dispatch was barred from editing other files, so it belongs to the later dispatch.

## Checkpoint
**Status**: complete
**When**: 2026-11-12 18:51 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

The host ran the live suite's user-scope cases at 72d40918 (Claude Code 2.1.323, model haiku; 12 passed, 1 failed) after the owner's yes to re-running the installer ("Q1 yes"); the installer check passed before and after. Stop condition 1 of plan step 1 fired, and the host put it to the owner as "Is a doubled skill list in workspace-subfolder sessions acceptable?", recommending to accept it (both names run the same skill; nothing per-root is written; the in-tree roots are due to be unregistered under issue 295). The owner's answer, verbatim: "Q1 accept it". Steps 2 to 8 go ahead on that answer.

The host counts U4 as doubled too, despite the suite's "clear": its init command list holds both names, and the verdict rests on one call to the prefixed name not going through.

FACT lines of the run (aw-accept-884313 shortened to N):

- U0 user-scope marketplace add + install, run from a directory in no git repository: exit 0; settings now has enabledPlugins[N@N]=true extraKnownMarketplaces[N].source.path=<the copy>; machine record source: <the copy>
- U1 committed-off repository, at its root: bare /zz-probe reached; /N:zz-probe not reached; init command list: zz-probe
- U2 committed-off repository, in a plain subdirectory root of it: bare /zz-probe reached; /N:zz-probe reached; init command list: zz-probe,N:zz-probe
- U3 committed-off repository, in a worktree of it outside its directory: bare /zz-probe reached; /N:zz-probe not reached; init command list: zz-probe
- U4 in-tree root (inside the copy's tree, ignored by its git, no .git of its own): bare /zz-probe reached; /N:zz-probe not reached; init command list: zz-probe,N:zz-probe
- U5 repository nested in an ordinary root: bare /zz-probe reached; /N:zz-probe reached; init command list: N:zz-probe
- U6 unregistered folder in no git repository: bare /zz-probe reached; /N:zz-probe reached; init command list: N:zz-probe
- U7 local true plus user true: bare /zz-probe reached; /N:zz-probe reached; init command list: N:zz-probe (listed once)
- U8 root whose local entry is false under user true: bare /zz-probe not reached; /N:zz-probe not reached; init command list: <none>; its own control skill answered
- U-end after the user-scope uninstall + marketplace remove: neither entry left; machine record source: <none>; real settings differ only by empty objects left behind (expected)
- STOP-CHECK 1 (U1, U2, U3): FIRES (U2). STOP-CHECK 2 (U4): clear by the suite, counted as doubled by the host. STOP-CHECK 3 (U5): clear. STOP-CHECK 4 (U8): clear. CHECK U7: yes.

In U5 and U6 the bare /zz-probe also "reached" while the list holds only the prefixed name: the bare outcome there is not evidence of a bare skill.

## Implementation
**Status**: complete
**When**: 2026-11-12 19:55 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-446 at `b54d0ab3`

Pull request B, plan steps 2 to 7 and the test side of step 8, on the owner's answer "Q1 accept it" (the doubled skill list in workspace-subfolder sessions is accepted). Commits, in order:

- `e16ce585` step 2: `user_tier_install.sh` enables the plugin once at user scope (`marketplace add` / `install --scope user` from a throwaway directory in no git repository, only the call the records show is needed, read back), migrates per-root entries (registry roots, the checkout, and local installs listed in `installed_plugins.json`; CLI only where the root is its own git toplevel and not a linked worktree, or in no git repository; elsewhere a note with the hand removal), new `--check` and `--uninstall`. Tests replaced.
- `9b40d5f7` step 3: pure deletion of the per-root machinery (installer functions, `--disable-root`, the takeover; `register_project.sh` root-enable rollback and `--remove` plugin step; their tests).
- `eb4623e8` step 4: say what is true: `register_project.sh` (no installer run unless `--install-user-tier`; read-only `registration_verify.sh --user-tier`; `--remove` leaves the root alone), `skill_prefix.sh` (bare in the workspace repository, `agent-workspace:` elsewhere, no registry, no refusal), the SessionStart hook, `session_root.sh` (each refusal with its true reason, the third plan review's wording for the no-git shape), run-issue and onboard-project SKILL.md, `script_reference.md`, the ADR-0018 review-guide row.
- `429ab62e` step 5: the committed `"agent-workspace@agent-workspace": false` in `.claude/settings.json`; `--check` reports it missing; a test pins it.
- `866f291d` step 6: records. ADR-0019 (new), ADR-0008 addendums to ADR-0018 and ADR-0016, `docs/design.md` (plugin, user-tier, registration and root-rule bullets, register rows 0018 and 0019, C4, change log), review-guide rows.
- `5237f1e5` steps 7 and 8 (test side): the live suite judges every U case from the init command list (probes only when there is none); U2 and U4 and stop checks 1 and 2 expect the accepted doubling; cases E and G to K retired; F's unregistered repo expects `agent-workspace:`. Helper tests for cleanup's user-scope removal and the judging helpers.
- `b54d0ab3`: wording fix in `docs/design.md` and the ADR-0019 review row (the migration's CLI runs only outside linked worktrees).

What a reader must know:

- The issue's acceptance line "a workspace session lists each skill once, under its bare name" holds at the checkout's root and in its worktrees only. A session started in a subdirectory of the checkout (a plain subdirectory, or an in-tree root with no `.git`) lists each shipped skill under both names; both run the same skill; accepted by the owner on 2026-11-12. ADR-0019, `docs/design.md`, the hook header and the `skill_prefix.sh` header say so.
- Deviation from the plan, for veto: the plan said to rewrite ADR-0018 decisions 3 and 4 in place. ADR-0001, ADR-0008 and ADR-0017 make accepted ADRs history (superseded, not edited, apart from status and reference addendums), so the decision is recorded as a new ADR-0019, and ADR-0018 and ADR-0016 get addendum notes only. Folding it back into ADR-0018 is a revert of one commit's ADR files.
- The third plan review's two wordings are carried: the no-git refusal reason, and the `installed_plugins.json` hand removal ("delete the object with `"scope": "local"` and that `projectPath` from the plugin's array").
- Net lines in the three scripts: `user_tier_install.sh` 1852 to 1612, `register_project.sh` 1244 to 1219, `skill_prefix.sh` 126 to 100 (net 291 fewer; 794 removed, 503 added). The plan's 600-800 estimate was for removal, not net; PR A had grown the installer since the plan's count.

Checks run:

- Suites run directly during the pass, all passing at their last run: `test_user_tier_install.sh` (254), `test_register_project.sh` (197), `test_project_integration_audit.sh` (279), `test_session_root.sh` (71), `test_session_start_layer.sh` (52), `test_user_tier_guard.sh` (64), `test_skill_prefix.sh` (24), `test_plugin_acceptance_helpers.sh` (29), `test_skill_paths.sh` (136), `test_plugin_manifest.sh` (12), `test_design_anchors.sh` (47), `check_design_anchors.sh` (exit 0).
- `pre-commit run --files $(git diff --name-only main...HEAD)` with no SKIP, at `5237f1e5`: exit 0 (every hook on the branch's 25 files, the script suites they reach included). It ran past the tool's 10-minute foreground limit, so it ran in the background and was waited on to its exit; a first foreground attempt was cut off at 590 s and is not counted. The two docs edited after it (`b54d0ab3`) went through `pre-commit run --files` on those two files with no SKIP: exit 0.

Not done, or not verified:

- The live suite was not run (the host runs it). The changed U-case judging is tested on synthetic lists only.
- The real `claude` CLI was invoked by mistake during one test run in this pass: the second-checkout case of `test_user_tier_install.sh` ran the installer without the stub (`run2` set no `AGENT_WORKSPACE_CLAUDE_BIN`, and the installer now calls the CLI on every install), so its `--force`, plain and `--uninstall` runs could each call `claude plugin ... --scope user` (marketplace add, install, uninstall, marketplace remove) from a scratch directory, with `HOME` set to the test's sandbox; the `--force` run exited 1. The real `~/.claude` was not read to confirm it is untouched. Fixed: `run2` uses the stub, and the stub is first on `PATH` for the whole suite.
- The proposed follow-up issue about relaxing the `session_root.sh` refusals is not opened (the owner's); its text is in the hand-back.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 20:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-446 at `630c47d6`
**Base**: main
**Depth**: Deep (reason: 25 files, +3198 -2202; governance files: ADRs, design.md, principles_review_guide.md, .claude/settings.json)
**Must-fix**: 2 | **Suggestions**: 7
**Round**: 1 | **Ship**: continue — round 1: 2 must-fix; first round always re-reviews after fixes

Specialists: static (shellcheck --severity=warning clean on all changed .sh; settings.json parses), governance, plan drift, Claude adversarial (ran 8 non-live suites, 0 failures: test_user_tier_install 254, test_register_project 197, test_project_integration_audit 279, test_session_root 71, test_session_start_layer 52, test_user_tier_guard 64, test_skill_prefix 24, test_plugin_acceptance_helpers 29), cross-model gemini (agy) and codex, both completed. No non-live test can reach the real claude CLI or the real ~/.claude (stub first on PATH, sandbox HOME, AGENT_WORKSPACE_CLAUDE_BIN set on every installer call). New ADR-0019 instead of editing ADR-0018 complies with ADR-0001/0008/0017; the plan's "amend in place" would have broken ADR-0017.

### Findings
- [x] (must-fix) ADR-0019 also replaces ADR-0018 decision 6's skill-names paragraph (prefix script "fails ... run-issue stops", the same-advice refusals, "installer never enables the plugin in the workspace"), but ADR-0018's Status addendum and ADR-0019's Status name only decisions 3 and 4 and say "the rest of ADR-0018 stands"; name decision 6's skill-names paragraph as superseded too (also the design.md register row 0018 and the review-guide 0018 row) — `docs/decisions/0018-plugin-based-skill-delivery.md:11`, `docs/decisions/0019-plugin-enabled-once-at-user-scope.md:5`
- [x] (must-fix) Decision register still says "One row per ADR in docs/decisions/ (18)"; there are now 19 — `docs/design.md:739`
- [x] (suggestion) A local `enabledPlugins` true with no marketplace declaration and no CLI install record (hand-written) may not be removable by `claude plugin uninstall --scope local`; install then exits 1 with ERROR on every run. Consider a note with the hand removal when there is no declaration and no CLI-record install — `.agent/scripts/user_tier_install.sh:967`
- [x] (suggestion) An installed_plugins.json that exists but does not parse silently drops the roots found only through it; `--uninstall` can then report a clean removal. Say so (note, and an error under strict) — `.agent/scripts/user_tier_install.sh:859`
- [x] (suggestion) The enable trusts `enabledPlugins[id] == true` without the user-scope record in installed_plugins.json; after a repoint from another checkout `install` is skipped, so the CLI's install record/cache may still be the other checkout's. Consider checking the user-scope install record in install and `--check` — `.agent/scripts/user_tier_install.sh:819`
- [x] (suggestion) `--uninstall` treats `partial` (enabled true, no declaration) as this checkout's and runs the user-scope uninstall + marketplace remove on an enable it cannot attribute — `.agent/scripts/user_tier_install.sh:1079`
- [x] (suggestion) cli_user traps INT and TERM but not HUP, so a hang-up leaves the scratch directory — `.agent/scripts/user_tier_install.sh:788`
- [x] (suggestion) The workspace copy keeps a real `.claude/settings.local.json` (the other two suites remove it), so the "checkout" place reads the machine's own file until the test overwrites it — `.agent/scripts/tests/test_user_tier_install.sh:44`
- [ ] (suggestion) Plan step 4 said the follow-up issue on relaxing the session_root.sh refusals is opened in this PR; it is not (left to the owner). Open it or say so in the PR body — `.agent/work-plans/issue-446/plan.md:329`

## Implementation
**Status**: complete
**When**: 2026-11-12 20:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-446 at `1296a975`
**Addressed**: Local Review (Pre-Push) at `630c47d6` (2026-11-12 20:12 -05:00)
**Commits**: 81deeb69, 439376e7, 2457525e, cbfdabe0, 9e659ffa, d28fe6f5, 2c8edcbd, 1296a975

### Actions
- [x] (must-fix) ADR-0018 decision 6's paragraph on how `run-issue` decides the prefix (`skill_prefix.sh`) named as superseded in both ADR Status lines, design register row 0018 and review-guide row 0018 — `docs/decisions/0018-plugin-based-skill-delivery.md:11`, `docs/decisions/0019-plugin-enabled-once-at-user-scope.md:5` (81deeb69)
- [x] (must-fix) Decision register counts 19 ADRs; the #446 change-log row says so — `docs/design.md:739` (439376e7)
- [x] (suggestion) A hand-written local true (no declaration, no local install in the CLI's record) that the CLI leaves is a note with the hand removal on install, still an error on --uninstall; the real CLI's behaviour on it is unverified and the code says so — `.agent/scripts/user_tier_install.sh` migrate_legacy_root (2457525e)
- [x] (suggestion) An unparseable installed_plugins.json is a note on install and --check, an error on --uninstall (no clean-removal or "nothing installed" claim) — `.agent/scripts/user_tier_install.sh` installed_plugins_state (cbfdabe0)
- [x] (suggestion) The no-call shortcut and --check also need a user-scope install object in installed_plugins.json; a repoint re-runs install (unverified on the real CLI, said in the code); ADR-0019 decision 1, the installer header, and the register and audit suites' stubs follow — `.agent/scripts/user_tier_install.sh` enable_user_scope (9e659ffa)
- [x] (suggestion) --uninstall leaves a user-scope enable with no declaration, with a note naming the hand removal and no CLI call — `.agent/scripts/user_tier_install.sh` uninstall (d28fe6f5)
- [x] (suggestion) cli_user traps HUP (exit 129) as well — `.agent/scripts/user_tier_install.sh` cli_user (2c8edcbd)
- [x] (suggestion) test_user_tier_install.sh deletes the copy's .claude/settings.local.json — `.agent/scripts/tests/test_user_tier_install.sh:44` (1296a975)
- [ ] (suggestion) Follow-up issue on relaxing the session_root.sh refusals — `.agent/work-plans/issue-446/plan.md:329` (left open: opening it is the owner's call; the host will ask him)

### Checks
- test_user_tier_install.sh: 265 passed, 0 failed (after the last change)
- test_register_project.sh: 197 passed, 0 failed; test_project_integration_audit.sh: 279 passed, 0 failed (after the stub change)
- `pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP, on the final tree before this entry: exit 0, validate-script-tests Passed
- Not run: the live suite, any claude CLI call, the installer against the real HOME (per the handoff)

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-12 20:52 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested
**Dispatch**: resumed (agent ace1c4380862fee80, resume 1 of 3)

**Branch**: feature/issue-446 at `f3dccb33`
**Base**: main
**Depth**: Deep (reason: whole-branch diff, 25+ files, ADRs/design.md/settings.json; fix-round re-review at the whole-diff tier)
**Must-fix**: 2 | **Suggestions**: 5
**Round**: 2 | **Ship**: continue — round 2: 2 must-fix include a design/correctness concern (not mechanical)

Round 1's findings: both must-fix fixed (ADR status lines and register/guide rows name decision 6's skill_prefix paragraph; register counts 19); suggestions 1-6 fixed with tests; suggestion 7 (follow-up issue) left for the owner by the host, not counted. Specialists: static (shellcheck --severity=warning clean), governance (ADR-0018 status edit is a permitted ADR-0008 addendum), plan drift (no new drift), Claude adversarial (fresh; ran test_user_tier_install 265, test_register_project 197, test_project_integration_audit 279, test_plugin_acceptance_helpers 29, all 0 failed; no must-fix), cross-model gemini and codex (both completed). Both must-fix below were found independently by all three adversarial reviewers.

### Findings
- [x] (must-fix) A repoint's required re-install is lost when it fails or is interrupted: `marketplace add` has already repointed the declaration and machine record, so the next run sees `ours` plus the other checkout's user-scope install record, takes the no-call shortcut, and `--check` says "installed and current" while the install/cache are still the other checkout's. Same when only the machine record names another checkout (`repointed` reads the settings source only). Make the pending re-install survive a failure (e.g. remove the user-scope install before repointing, or treat a machine record/declaration that was another checkout's as a repoint) and test failure-then-rerun — `.agent/scripts/user_tier_install.sh:826`
- [x] (must-fix) `user_scope_readback` checks the settings and the machine record but not the user-scope install record that the shortcut and `--check` now require, so an install (or a migration whose local uninstall drops the user record) can exit 0 while `--check` immediately reports drift. Require `user_install_record` present (when the record parses) in the read-back, with a stub test for each path — `.agent/scripts/user_tier_install.sh:845`
- [x] (suggestion) A local true in the workspace checkout's own settings.local.json is DRIFT in `--check` with "re-run the installer to remove it", but install leaves it with a NOTE and exits 0 when it is hand-written or the CLI is missing; give `--check` the same hand-removal advice (and `plugin_note` without the CLI) there — `.agent/scripts/user_tier_install.sh:1446`
- [x] (suggestion) A hand-written local true the CLI leaves makes every install run the two `--scope local` CLI calls again (and the read-back), so a re-run is never call-free; consider not re-running the CLI once it is known to leave the entry — `.agent/scripts/user_tier_install.sh:1038` (deferred: costs two harmless local CLI calls per install in a state the installer already reports with its hand removal; skipping them needs a record of the CLI's earlier failure, more than this round's narrow fix)
- [x] (suggestion) The hand removal for a root the CLI is not run in names only settings.local.json; when the CLI's record lists a local install there, also name its `installed_plugins.json` object, or a later deleted root leaves a note on every run — `.agent/scripts/user_tier_install.sh:943`
- [x] (suggestion) With the workspace in no git repository, the fallback answers bare for a git repository nested under it; guard it with an empty `dir_repo` — `.agent/scripts/skill_prefix.sh:94`
- [x] (suggestion) Live suite: `us_case` replaces a valid empty list (`<none>`) from the first session with the second session's `<no init line>`, and U7 treats `<none>` as "no init line" (UNDECIDED wording instead of "0 times") — `.agent/scripts/tests/live/plugin_acceptance.sh:635`

## Implementation
**Status**: complete
**When**: 2026-11-12 21:20 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent afce6a3db90432d7a, resume 1 of 3)

**Branch**: feature/issue-446 at `bfd1c72d`
**Addressed**: Local Review (Pre-Push) at `f3dccb33` (2026-11-12 20:52 -05:00)
**Commits**: e5308e65, c07d082a, dd010fee, b712b7a6, bfd1c72d

### Actions
- [x] (must-fix) A take-over (the settings declaration or the machine-level record names another checkout) runs uninstall --scope user, then marketplace add, then install, so a failure part way leaves no user-scope install record and the next run installs; ADR-0019 decision 1 and the installer header follow; tests: failed take-over then re-run, machine-record-only take-over — `.agent/scripts/user_tier_install.sh` enable_user_scope (e5308e65)
- [x] (must-fix) user_scope_readback also requires the user-scope install record when the record parses; tests on the install and migration paths — `.agent/scripts/user_tier_install.sh` user_scope_readback (e5308e65, one commit with the must-fix above: they share the read-back and the stub)
- [x] (suggestion) --check gives install's advice for a local true in the checkout's own settings.local.json: a note with the removal by hand without the CLI, the removal by hand in drift for a refused root or a hand-written entry — `.agent/scripts/user_tier_install.sh` check loop (c07d082a)
- [x] (suggestion) A hand-written local true repeats two local CLI calls on each install — `.agent/scripts/user_tier_install.sh` migrate_legacy_root (deferred: costs two harmless local CLI calls per install in a state the installer already reports with its hand removal; skipping them needs a record of the CLI's earlier failure, more than this round's narrow fix)
- [x] (suggestion) Every hand removal also names the installed_plugins.json local-install object when the CLI's record lists one there — `.agent/scripts/user_tier_install.sh` hand_removal (c07d082a, one commit with the --check advice: they share the hand-removal helpers)
- [x] (suggestion) skill_prefix.sh: a git repository nested in a checkout that is in no git repository takes the prefix (fixed, not deferred: a one-line guard with an existing test harness) — `.agent/scripts/skill_prefix.sh:94` (b712b7a6)
- [x] (suggestion) Live suite: us_case keeps an empty first list, and U7 counts an empty list as 0 (us_no_list, us_count; helper tests on synthetic lists) — `.agent/scripts/tests/live/plugin_acceptance.sh:635` (dd010fee)

### Checks
- test_user_tier_install.sh: 276 passed, 0 failed; test_plugin_acceptance_helpers.sh: 31 passed, 0 failed; test_skill_prefix.sh: 25 passed, 0 failed
- `pre-commit run --files $(git diff --name-only main...HEAD)`, no SKIP, on the final tree before this entry: exit 0, validate-script-tests Passed
- Not run: the live suite, any claude CLI call, the installer against the real HOME (per the handoff)
- Not verified on the real CLI: that `uninstall --scope user` removes the user-scope install record (the take-over's safety rests on it; the read-back requires the record again after install)
