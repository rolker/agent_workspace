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
