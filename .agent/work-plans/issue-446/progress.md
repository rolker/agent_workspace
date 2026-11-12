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
