# Plan: Enable the agent-workspace plugin once for the whole machine (user scope), as decided 2026-10-13

> **Sequencing, read first.** Pull request A (issue 394) is driven on issue
> 394's own worktree and timeline (started 2026-11-12); this plan's A section
> is the source its plan pass copies. Pull request B's implementation on this
> branch starts only after A is merged and installed, `main` is merged in, and
> the owner has answered how the live check runs.

## Issue

https://github.com/rolker/agent_workspace/issues/446

## Context

The `agent-workspace` plugin is enabled per registered root at local scope
(`claude plugin install --scope local` run from each root, writing the root's
gitignored `.claude/settings.local.json`). The owner decided on 2026-10-13
("What if I enabled it for all of ~?", "I like that it could simplify things")
and again on 2026-11-12 ("Doesn't the plugin namespace mitigate earlier fears
of skill name collisions?") that it is enabled once at user scope. The
decision is settled and this plan does not reopen it. "Simplify" is the goal:
the result is less installer code, not a user-scope path beside the old
per-root one.

What exists today (read in this worktree):

- `user_tier_install.sh` (1476 lines) carries the per-root machinery:
  `plugin_roots` (classifies each registry root as enable / skip / parent=
  instance / enclosed), `plugin_state`, `plugin_enabled_flag`,
  `plugin_disabled_flag`, `same_project`, `enclosing_repo`, `enclosed_reason`,
  `enclosed_advice`, `instance_cli_reason`, `local_disable_note`,
  `enable_plugin_in_root`, `disable_plugin_in_root`, `uninstall_plugin_from`,
  `uninstall_refused_root`, `claim_machine_record` (the takeover of the CLI's
  machine-level marketplace record), the `--disable-root` mode, and the
  matching `--check` and `--uninstall` branches (about lines 478-1005, 1151-1245,
  1360-1476).
- `register_project.sh` (1244 lines): `--remove` calls
  `user_tier_install.sh --disable-root`; `root_plugin_enabled_here`,
  `ROOT_PLUGIN_BEFORE` and the rollback steps decide whether to undo a root
  enable; step 4 runs the installer so the plugin lands in the root.
- `skill_prefix.sh` (126 lines) decides bare vs `agent-workspace:` from the
  registry and git common-dir comparisons, and refuses nested repositories and
  unregistered folders. `session_start_project_layer.sh` prints a header
  from it. `session_root.sh` refuses the same nested directories with the same
  reason.
- #394: `claude plugin` commands rewrite `~/.claude/settings.json` and drop the
  installer's `_agent_workspace` hook marker, so `--check` reports drift and a
  re-run duplicates both hooks. Every user-scope enable rewrites that file, so
  the idempotence acceptance line cannot pass without the fix.

### Spike, run 2026-11-12 (step 1 of the issue review's actions, done in this phase)

Claude Code 2.1.322 (was 2.1.296 on 2026-10-13). Scratch HOME under this
session's scratchpad; `CLAUDE_CONFIG_DIR` unset; the real `~/.claude` was not
used (its `settings.json` and `plugins/known_marketplaces.json` have the same
size and mtime before and after). No model session was started (no auth in a
scratch HOME), so only the CLI facts below could be checked.

Verified:

- `claude plugin marketplace add <checkout> --scope user` then
  `claude plugin install agent-workspace@agent-workspace --scope user` from a
  directory marketplace write only under the scratch `~/.claude`:
  `settings.json`, `plugins/known_marketplaces.json`,
  `plugins/installed_plugins.json`, `plugins/cache/`, plus the scratch
  `~/.claude.json` and one backup of it. Nothing was written in the checkout.
- New fact: the user-scope `marketplace add` declares the marketplace in
  `~/.claude/settings.json` as
  `extraKnownMarketplaces["agent-workspace"].source = {source: directory, path: <checkout>}`
  and install adds `enabledPlugins["agent-workspace@agent-workspace"] = true`.
  Both are plain JSON the installer can read for idempotence and `--check`.
- `claude plugin list --json` run in a directory reports the effective
  `enabled` state for that directory. With user scope enabled: a repository
  whose committed `.claude/settings.json` has the `false` entry reports
  `false`; a linked worktree of it reports `false`; a repository with only a
  local-scope `false` reports `false` (and `true` when the local entry is
  `true`); an unrelated repository, a non-git folder, and a repository nested
  inside another repository all report `true`.

Not verified (cannot be done without a model session):

- `plugin list` read each directory's own `.claude/settings*.json` and did not
  walk up to the git toplevel (a plain subdirectory of the "off" repository
  reported `true`), which differs from what live case G saw for sessions. So
  `plugin list` is not a proxy for sessions in plain subdirectories, and the
  facts that depend on it stay unverified: whether the committed `false` entry
  covers a registered root inside the workspace tree with no `.git` of its own
  (the `p11-*` shape), and whether a session in a repository nested in a
  registered root lists the `agent-workspace:` skills.
- Whether local scope `true` plus user scope `true` lists the skills once.

(A second user-scope `marketplace add` of the same name from another path
repoints both records: verified on 2.1.322 by the first plan review; see
Approach, PR B step 2.)

These become PR B's step 1, a live session case run by the host or owner with a stop
condition (below). The stop condition is part of the plan, not a risk to
accept silently.

## Approach

Two pull requests, in this order.

**Sequencing (finding 9).** `dispatch_phase.sh next` keys one timeline to one
pull request: with `--pr merged` it answers "the worktree is gone, nothing
left to resolve" (header and line 703), and the merge removes the worktree.
So the loop's scripts cannot carry two merge cycles on one timeline. PR A is
therefore planned under its **own worktree and timeline for issue 394**
(branch `feature/issue-394`, `Closes #394`), from `main`, as its own
`run-issue` pass; it is implementable without any owner answer. PR B (this
issue, branch `feature/issue-446`, `Closes #446`) is implemented only after A
is merged and installed, on this branch after merging `main` in. Issue 394
needs its own plan entry (a short one, taken from the PR A section below)
when its pass starts; this plan is its source.

**PR A: #394, hook markers and `.gitignore` (small, own issue, merges first).**

1. Decide "ours" by command path, not by `_agent_workspace`. An entry is the
   installer's if its command is `SESSION_HOOK_LINK`, or any command under
   `$WS_ROOT/.claude/hooks/` (this covers `log-tool-use.sh` and the retired
   hooks of #328, which the retired-hook check at about lines 1095-1115 and
   its test at `test_user_tier_install.sh:305` only find today when tagged).
   `--check`, the re-run, `--force` and `--uninstall` use this rule whether or
   not the marker is present. When the `_agent_workspace` marker is present
   it is still read, as today: the "foreign" check, the "points outside this
   checkout" check and the `--force` removal keep honouring it, so an entry
   whose checkout was moved or deleted (a dead command path, which the
   path rule alone cannot attribute) is still reported and removed. Another checkout's entry is recognised the way
   `foreign_skill_link` does: the entry's directory (two levels above
   `.claude/hooks/`) holds `.agent/user_tier_scripts.txt` and is not
   `$WS_ROOT`; a same-named hook in an unrelated repository is not caught
   (finding 6c). A re-run over unmarked entries does not add a second copy.
2. Idempotent write (finding 6b): the installer stops **writing** the marker
   (command-path matching makes it carry nothing the command does not) but
   keeps **reading** it where present (step 1), and skips the write of
   `settings.json` when the merged result equals the current content under
   `jq -S` (this also covers the CLI reordering keys). `backup_settings`
   (line 1281) moves behind that comparison so a no-op run writes no backup.
3. Add `.claude/settings.local.json` to `.gitignore`.
4. Tests (scratch HOME, stub CLI that strips markers and reorders keys on
   every call): install, CLI call, then `--check` passes (exit 0) and a
   second install leaves `settings.json` byte-identical (no backup written
   either); an unmarked retired-hook entry under `$WS_ROOT/.claude/hooks/` is
   found by `--check` and replaced by install; a same-named hook outside the
   checkout without `user_tier_scripts.txt` is left alone; one with it is
   reported as another checkout's; `--uninstall` after a strip removes the
   entries; a marked entry whose command points into a checkout that was
   moved or deleted (path gone from disk) is still reported by `--check` and
   removed by `--force`.

**PR B: user-scope enable and removal of the per-root machinery (this issue,
branch `feature/issue-446`, after A is merged and installed).** One pull
request, commits in this order:

1. **Live check (waits for the owner's yes; no live session starts before
   it).** A live session needs auth, which a scratch HOME lacks and a
   dispatched phase must not borrow from the real `~/.claude`. Plan for the
   host's recommended answer: once PR A is merged and installed (so the hook
   markers are no longer at risk), the existing opt-in suite
   `.agent/scripts/tests/live/plugin_acceptance.sh` (real auth, renamed
   `aw-accept-<pid>` plugin, cleanup on exit) gains user-scope cases that
   enable the renamed test plugin at user scope in the real `~/.claude` for
   the minutes the run takes and then remove it. A trap removes it on any
   exit; the suite prints, at the start, the commands that remove it by hand if
   the run is killed (see the safety extras below). The suite's header promise ("never touches
   `~/.claude/settings.json`") is rewritten to say exactly this. The run is
   made by the host or the owner, **not by an implement sub-agent**; its
   FACT lines go on the timeline and in "Implementation Notes".
   **Who writes the cases, and the limit on the first dispatch:** the first
   implement dispatch for PR B is limited to this step's suite commit (the
   user-scope cases, the copy's off entry, the safety extras below, the
   header rewrite) and **ends with a hand-back when that commit is made**. It
   must not start steps 2 to 8, run the suite, or edit anything else; steps 2
   to 8 begin only in a later dispatch, after the suite's FACT lines are on
   the timeline and the stop conditions below have been checked against them.
   An implement agent reading only this plan stops after the suite commit.
   **The copy's off entry (finding 3):** the suite runs on a copy of the
   checkout whose plugin is renamed `aw-accept-<pid>`; before the
   committed-off-repository and worktree cases are made, it writes
   `"aw-accept-<pid>@aw-accept-<pid>": false` into the copy's
   `.claude/settings.json` (under `enabledPlugins`) and commits it there (step
   5's real entry names `agent-workspace@agent-workspace`, which would not
   cover the renamed plugin). Without it a session at the copy's root would
   list the probe twice and the first stop condition would fire on a test
   defect.
   **Safety extras (finding 8):** the trap covers EXIT, INT, TERM and HUP; the
   suite records "user-scope enabled" before making the CLI call (as
   `ENABLED_ROOTS` is recorded today) so an interrupted call is still cleaned
   up; it prints a removal line naming both commands,
   `claude plugin uninstall aw-accept-<pid>@aw-accept-<pid> --scope user` and
   `claude plugin marketplace remove aw-accept-<pid> --scope user`; and it
   compares the real `~/.claude/settings.json` under `jq -S` before and after
   the run, treating leftover empty objects as expected and printing any other
   difference (the CLI's rewrite races the owner's concurrent sessions). The
   real `agent-workspace` entry is never named. Cases: a session in the committed-off repository,
   in a plain subdirectory root of it, in a worktree of it; an in-tree root
   (the `p11-*` shape: a registered root inside the workspace tree with no
   `.git` of its own); a repository nested in an ordinary root; an
   unregistered folder; local `true` plus user `true` (listed once?); and a
   root whose local entry is `false` under user `true` (finding 3; the
   migration rule "false stays false" rests on it). **Stop conditions:** if
   the committed `false` entry does not keep a workspace session to bare
   names; or does not cover the in-tree root (finding 2: the failure is then
   a doubled skill list there, and only a per-root `false` written into that
   root cures it, which brings back a per-root write -- it trades "simplify"
   against "never doubled", the owner's to weigh; the `skill_prefix.sh`
   registry fallback is dropped, it would not cure it); or a nested-repository
   session does not list the `agent-workspace:` skills; or a local `false`
   does not win over user `true`: stop and report to the host.
   Alternatives the owner may pick instead of the recommended answer:
   (i) he runs the live case by hand from a written checklist: the plan gains
   a checklist file (the same cases, as steps with the expected lines), the
   suite gains no user-scope cases, and the FACT lines are pasted by him;
   (ii) a token for a scratch config directory: the suite runs with
   `CLAUDE_CONFIG_DIR` pointing at a scratch directory and the token, never
   touching his real `~/.claude`, a dispatched phase could run it, and the
   trap/print-the-removal-command part is dropped.
2. **Install, migrate, `--check`, `--uninstall` for user scope** (the new
   shape; about 120 lines added):
   - Install: if `~/.claude/settings.json` already shows
     `enabledPlugins[id] == true` and
     `extraKnownMarketplaces[name].source.path == WS_PHYS`, **and**
     `plugins/known_marketplaces.json` holds the entry with the same source,
     make no CLI call (finding 5: a re-run repairs what `--check` reports).
     Otherwise, from a scratch directory outside any repository, run
     `claude plugin marketplace add "$WS_PHYS" --scope user` and
     `claude plugin install "$PLUGIN_ID" --scope user`, then read the settings
     back and fail if they do not show it (the existing read-back habit).
     Another checkout's declaration: the user tier is already singular
     (`installed_elsewhere`), so the same refusal applies; no separate
     machine-record takeover (`claim_machine_record`, about 60 lines) (the
     review re-checked on 2.1.322 that a second user-scope `marketplace add`
     of the same name from another path repoints both records, so the add is
     the takeover). Order: user-scope add and install first, then migrate
     (a local remove with the user declaration present keeps the machine
     record; the reverse order can drop it).
   - Migrate one legacy root with a single function `migrate_legacy_root
     <root>`, used by install and uninstall for the registry roots, the
     workspace checkout, and the roots found in the CLI's own record
     `~/.claude/plugins/installed_plugins.json` (entries with
     `"scope":"local"` for this plugin id, `projectPath` = the root), so a
     root unregistered by hand or moved is still found (finding 4; a
     `projectPath` that no longer exists gets the one note below). It runs
     the CLI only where the root is its own git toplevel **with git-dir equal
     to git-common-dir** (not a linked worktree), or is in no git repository;
     from a plain subdirectory the CLI would change the toplevel's file and
     leave the root's own entry, so every run would find it again, and from a
     linked worktree where `--scope local` writes is not established (the
     deleted `instance_cli_reason` said so; a write to the main repository's
     file could also remove its deliberate local `false`). Elsewhere (a plain
     subdirectory, a linked worktree, an in-tree `p11-*` root, a `parent=`
     instance that is a plain directory of its parent's repository) it
     prints the entry and the one-line hand removal, and `--check` notes it;
     never an error.
     It reads `<root>/.claude/settings.local.json`:
     `enabledPlugins[id] == true` from this checkout, run from the root:
     `claude plugin uninstall "$PLUGIN_ID" --scope local` and
     `claude plugin marketplace remove "$MARKETPLACE_NAME" --scope local`
     (through the CLI, never by editing the file); `false` is left untouched
     (a deliberate local opt-out; narrower scope wins); a declaration from a
     different checkout's path is left with a note; the file is absent or has
     no entry: nothing. A registry root that is no longer on disk: one note,
     no error, and the next run tries again (idempotent). An unparseable file:
     a note, not an error (the same plugin enabled at two scopes is not a
     doubling; verified in step 1, and if not, this becomes an error).
     A second run finds nothing to migrate and prints nothing about it, except
     two kinds of entry that get a note on every run: a report-only entry
     (plain subdirectory or linked worktree), and an
     `installed_plugins.json` `projectPath` that no longer exists (for that
     one the note gives the hand removal, since the CLI cannot be run from a
     directory that does not exist: delete that entry from the `local` list of
     `~/.claude/plugins/installed_plugins.json`).
     After migrating, the installer reads the user-scope state and the
     machine record (`known_marketplaces.json`) back and fails if either was
     lost (whether a local `uninstall` with the same plugin installed at user
     scope leaves the user-scope install intact is not checked on 2.1.322; the
     read-back is the guard, and a failure there is an error naming it).
   - `--check`: read-only. Drift if the user settings do not show the plugin
     enabled from this checkout; if `plugins/known_marketplaces.json` has no
     entry for it or a different source; if the workspace checkout's committed
     `.claude/settings.json` lacks the `false` entry; and a note (not drift)
     for each registry root still holding a legacy `true` entry ("re-run the
     installer to move it"). `--require` as today.
   - `--uninstall`: `claude plugin uninstall --scope user` and
     `marketplace remove --scope user`, plus `migrate_legacy_root` over the
     registry roots and the checkout so no per-root entry is left behind.
3. **Remove the dead per-root code, as its own commit** (so the review can see
   a pure deletion; expected net removal from the three scripts: roughly
   600-800 lines). Removed, not adapted: the workspace-tree skip,
   `parent=` handling, the nested-repository and enclosed-directory refusals
   (`same_project`, `enclosing_repo`, `enclosed_reason`, `enclosed_advice`,
   `instance_cli_reason`), `plugin_roots`, `plugin_enabled_flag`,
   `plugin_disabled_flag`, `local_disable_note`, `enable_plugin_in_root`,
   `disable_plugin_in_root`, `uninstall_plugin_from`, `uninstall_refused_root`,
   the `--disable-root` mode and its usage/help, the root-enable rollback in
   `register_project.sh` (`root_plugin_enabled_here`, `ROOT_PLUGIN_BEFORE`,
   the `plugin` rollback step and its `rollback_left` text), and the
   `--remove` plugin step and its failure branches. Per-root opt-out is a
   root's own `enabledPlugins` `false` (project or local settings), not
   installer logic.
4. **Say what is true**:
   - `register_project.sh`: registration writes the registry line and the
     settings file and runs the build and test; it no longer runs the
     installer to enable a plugin in the root (`--install-user-tier` stays as
     the explicit way to install the user tier). `--remove` drops the registry
     line and the settings file only. Header text and `--help` follow.
   - `skill_prefix.sh`: the rule becomes: in the workspace checkout's
     repository (checkout, worktrees, and the registry roots inside the
     workspace tree, which step 1 must show are covered or the plan stops),
     bare; anywhere else,
     `agent-workspace:`. No registry read for the common case, no refusal
     for nested repositories or unregistered folders.
   - `session_start_project_layer.sh`: header says what is true in a
     registered root, a nested repository, an unregistered folder (plugin
     present; no workspace root registered there) and the workspace; the
     "plugin is not enabled for this root" line becomes "if no
     `agent-workspace:` skills are listed, the user-tier plugin is not
     installed: run the installer".
   - `session_root.sh`: keeps both refusals (lines 149-155; the root rule is
     about which root a session works under, not about the plugin). Only the
     reason text ("neither the root's plugin nor its layer reaches the
     session") is reworded, per shape. (1) A package repository nested in a
     root: "a multi-repo project's root is its registered hosting directory,
     never a package repository nested in it". (2) A subdirectory of a root
     in no git repository: the session's layer (the root's settings and
     adapter) is found from the session's git toplevel, which such a
     directory lacks, so the true reason is that no root's layer can be
     located from it; the text says that, not the plugin. Whether to relax
     either refusal is a follow-up issue opened in this PR, not part of this
     change.
   - `run-issue` SKILL.md prefix step, `script_reference.md`,
     `project_integration_audit.sh` where it names the per-root enable;
     `.agent/knowledge/principles_review_guide.md` line 53 (the ADR-0018 row:
     "enabled at local scope per registered root ... the only write into a
     project checkout is ... `settings.local.json`") rewritten to the
     user-scope rule; `registration_verify.sh --user-tier` stays as a
     read-only check after registration (which no longer runs the installer),
     its plugin expectations following the user-scope shape.
5. **The committed off entry:** add
   `"enabledPlugins": {"agent-workspace@agent-workspace": false}` to the
   workspace checkout's tracked `.claude/settings.json`. The installer
   still never edits that file; a test asserts the entry exists so removing it
   fails CI.
6. **Records, same PR (ADR-0017):**
   - ADR-0018: decision 3 becomes "The installer enables the plugin once, at
     user scope" (the per-root text, the three steps and the `parent=`/nested
     discussion shrink to the user-scope rule, the migration and the opt-out);
     decision 4 (the scoped exception) is withdrawn: the plugin's records are
     `~/.claude/settings.json` and `~/.claude/plugins/`, which the user tier
     already owns, and nothing is written into a project checkout; the rejected
     alternative "Enable the plugin at user scope" is removed from
     Alternatives and a "Per-root enabling at local scope" alternative is added
     as rejected by the owner's 2026-10-13 and 2026-11-12 decisions; decision
     6's prefix rule, Consequences and Acceptance follow. A dated amendment
     note in Status.
   - ADR-0016: decision 2's exception paragraph (lines 25-27 and the
     reference at 252) says the exception was withdrawn on 2026-11-12 and the
     user tier gains the plugin's `~/.claude` entries.
   - `docs/design.md`: "Sessions and roots" plugin bullet (line 248-251),
     the registry/`--remove` bullet (lines 314-320), the root-rule text at
     lines 205-207 (unconditionally: "sessions do not read the root's local
     settings" is false after this change; the refusal's remaining reasons are
     the design's "a multi-repo project's root is its registered hosting
     directory, never a package repository nested in it", around line 200,
     and, for a subdirectory of a root in no git repository, that no root's
     layer can be located from it),
     the register row for ADR-0018 (line 744) and C4 (line 767), and a
     history row.
7. **Tests** (scratch HOME and synthetic sandbox roots, a stub CLI that
   records argv and mutates the scratch settings as the real CLI does;
   nothing names a real project; run with an explicit job count if run in
   parallel, as `run_script_tests.sh --jobs N`). The old per-root cases in
   `test_user_tier_install.sh` (106 mentions of the plugin) and
   `test_register_project.sh` are deleted with the code, not rewritten. New:
   - clean HOME install: the CLI is called exactly twice, user scope, and
     the registered roots' files are untouched (byte-identical);
   - re-run: zero CLI calls, nothing changes; `--check --require` exits 0
     (with the PR A marker stripping applied between);
   - migration: a root with a legacy `true` entry ends with none, through
     the CLI stub (assert the `--scope local` argv and cwd, not a file edit);
     a registry root that does not exist is noted and does not fail the run
     and a later run still migrates it once it appears; a root whose local
     entry is `false` is not touched and not reported as drift; a root
     whose entry names another checkout is left with a note; an old install
     moved over by one run, and the next run prints no migration line;
   - `--uninstall` after a migrated install leaves no `--scope local` entry
     anywhere and no user-scope entry;
   - `--check` reports a missing committed off entry, a user-scope entry
     from another checkout, and a legacy `true` entry (note, not drift);
   - `register_project.sh` register and `--remove`: no installer call, no
     `settings.local.json` touch, and the existing rollback tests that were
     about the plugin step are removed;
   - `skill_prefix.sh`: workspace checkout and worktree bare; ordinary
     root, nested repository, unregistered folder: `agent-workspace:`;
     inside-tree root bare; `test_user_tier_guard.sh` lines 249-272 (which
     assert exit 1 from an unregistered repository) are rewritten to the new
     answer;
   - migration extras: a legacy entry in a root that is a linked git
     worktree is reported with the hand removal, no CLI call is made, and the
     main repository's local `false` is untouched; a gone `projectPath` is
     noted on every run with the hand removal; the user-scope entry and
     machine record are read back after migration (a stub that drops them
     makes the run fail); a legacy entry in a root that is a plain
     subdirectory of a repository is reported, not migrated, and the next
     run neither re-migrates it nor calls it drift; a root found only in
     `installed_plugins.json` is migrated; a re-run with the machine record
     missing but settings correct calls the CLI and repairs it;
   - `test_session_start_layer.sh`: the header in each of those places;
   - `test_design_anchors.sh` and the ADR/design consistency tests still pass.
8. **Acceptance (live, opt-in; recorded in the PR):** the issue's four lines,
   plus the added line from the review: a session in a git repository
   nested under a registered root (a colcon-package-like `src/<pkg>` shape)
   lists the `agent-workspace:` skills.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/user_tier_install.sh` | PR A (issue 394 worktree): match hook entries by command path; PR B: user-scope install, `migrate_legacy_root`, new `--check` and `--uninstall`; delete the per-root functions and `--disable-root` |
| `.agent/scripts/register_project.sh` | Drop `--disable-root` calls, `root_plugin_enabled_here`, `ROOT_PLUGIN_BEFORE`, the plugin rollback step and the installer run in registration; header and `--help` |
| `.agent/scripts/skill_prefix.sh` | New rule: workspace repository bare, anywhere else `agent-workspace:`; header comment |
| `.agent/scripts/session_root.sh` | Reword the nested-repository reason only, citing the design's root rule |
| `.agent/scripts/tests/test_user_tier_guard.sh` | Lines 249-272: `skill_prefix.sh` from an unregistered repository now prints `agent-workspace:` |
| `.agent/knowledge/principles_review_guide.md` | ADR-0018 row (line 53) |
| `.claude/hooks/session_start_project_layer.sh` | Header text for each place |
| `.claude/settings.json` | Committed `enabledPlugins` false entry for the plugin |
| `.gitignore` | PR A (issue 394's own worktree): `.claude/settings.local.json` |
| `.claude/skills/run-issue/SKILL.md`, `.agent/knowledge/script_reference.md`, `.agent/scripts/project_integration_audit.sh` | Wording that names the per-root enable |
| `.agent/scripts/tests/test_user_tier_install.sh`, `test_register_project.sh`, `test_skill_prefix.sh`, `test_session_start_layer.sh`, `test_session_root.sh`, `test_project_integration_audit.sh` | Remove per-root cases; add the cases above |
| `.agent/scripts/tests/live/plugin_acceptance.sh` | Retire the per-root cases (E, G, H, J, K; I if the takeover goes); add the user-scope step-1 and acceptance cases with the exit trap and the printed removal command; header text |
| `docs/decisions/0018-plugin-based-skill-delivery.md`, `docs/decisions/0016-session-roots-and-the-user-tier.md` | Amend as in step 6 |
| `docs/design.md` | Sessions and roots, registry bullet, decision register rows 0018 and C4, history |

## Prior Art

- The 2026-10-13 spike on issue 332 (user scope works; narrower scope wins),
  re-checked today as far as the CLI allows (above). Taken: its facts as
  hypotheses to confirm, not as results.
- The installer's own read-back and read-only `--check` habits (JSON reads,
  no CLI call) are kept for the user-scope entries; `claude plugin list --json`
  was considered as the check source and rejected because it is a
  cwd-dependent view, not the stored state (it does not walk up to the git
  toplevel), and `--check` must be read-only and deterministic.
- Per-root opt-out through the root's own `enabledPlugins` false is the
  CLI's own scope rule, so no installer feature is built for it.
- `claim_machine_record` was built for a per-root world with several
  declarations of one name; at user scope there is one declaration, and the
  first plan review verified that a second user-scope `marketplace add` of the
  same name repoints both records, so it is dropped.
- #351 (hooks into the plugin) would remove the marker problem at the root;
  it is out of scope, hence the PR A fix.

## Serves

Light touch on projects (the workspace stops writing a plugin entry into
each project root) and Easy to use (one install per machine) --
`docs/design.md#sessions-and-roots`

## Design Picture

Yes. `docs/design.md#sessions-and-roots` (plugin bullet, registry/`--remove`
bullet, and the root-rule note at lines 205-207, edited unconditionally in step 6),
`docs/design.md#registry-and-adapters` where it says unregistering removes
the plugin enable, the ADR-0018 row of the decision register (now "enabled at
user scope") and C4, in PR B (ADR-0017).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Per-root machinery is deleted in its own commit, not kept beside the user-scope path; no new opt-out feature (the CLI's scope rule does it) |
| Put each thing at the level it applies to | A machine-wide plugin at user scope; a root's opt-out in that root's settings |
| Keep one current design | ADR-0018, ADR-0016 and `docs/design.md` amended in the same PR as the code |
| Verify before claiming | Spike re-run (CLI facts verified; session facts named as unverified with a step-1 live case and a stop condition); no claim about sessions beyond what was run |
| Tests have a scratch HOME | Scratch HOME, synthetic roots, stub CLI; no test names a real project |
| Don't make work for the owner | No owner question: the decision is settled; the mechanism choices below are listed for veto |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0018 | Yes | Decisions 3 and 4 amended, the user-scope alternative moved from rejected to accepted, 6/Consequences/Acceptance follow |
| ADR-0016 | Yes | Decision 2's exception (the `settings.local.json` write) withdrawn; the user tier gains `enabledPlugins` and the marketplace record under `~/.claude` |
| ADR-0017 | Yes | Design sections and register rows in the same PR |
| ADR-0013 | Yes | Timeline entries as usual |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `skill_prefix.sh` rule | `session_start_project_layer.sh` header, `run-issue` SKILL.md prefix step, `dispatch_phase.sh --skill-prefix` callers (unchanged contract), `script_reference.md`, `test_skill_prefix.sh` | Yes |
| Installer drops the per-root enable | `register_project.sh` step 4, `--remove`, rollback, `registration_verify.sh --user-tier` expectations, `project_integration_audit.sh` wording | Yes |
| Committed `.claude/settings.json` gains `enabledPlugins` | A test pins it; `analyze-permissions` SKILL.md mentions settings files only generally | Yes |
| `session_root.sh` nested-repository refusal | Reason text only; relaxing it is a separate decision | Reword now; follow-up issue |
| `plugin_acceptance.sh` cases | Opt-in suite, not in `run_script_tests.sh` | Yes |
| A machine installed the old way | Migration in the installer, tested | Yes |

## Open Questions

One owner answer pending, and it blocks only PR B's step 1: how the live
sessions are authenticated (the recommended answer and two alternatives are
in the Approach; "waits for the owner's yes"). PR A does not wait for it.
Mechanism choices made from the principles, listed for veto:

- The committed `false` entry in the workspace's tracked
  `.claude/settings.json` (not an installer write). This departs from the
  #332 decision comment, which says "the installer ... writes the workspace
  override"; the installer header (lines 100-102) calls the tracked file
  Ask-First, and an installer editing a tracked file is worse; a committed
  entry also reaches every clone.
- PR A under issue 394's own worktree and timeline (the loop's `next` ends a
  timeline at one merged pull request), PR B after it, with `main` merged in.
- Two pull requests (PR A #394, PR B this issue), because #394 is a bug fix
  with its own issue and tests that is independently mergeable, a
  precondition for PR B's idempotence line, and leaving it unmerged would make
  PR B's tests depend on an unreviewed change. PR B stays one pull request,
  with the dead-code removal as its own commit: splitting the removal into a
  third PR would leave `main` holding the per-root path and the user-scope
  path side by side, which is the "second path" the goal rejects, and the ADR
  amendments, design update and code must land together (ADR-0017).
- `register_project.sh` no longer runs the installer during registration.
- The nested-repository refusal in `session_root.sh` stays for now.

## Estimated Scope

Two pull requests on two timelines (A: issue 394's worktree; B: this one,
after A is merged). PR A: small (one script, one test, `.gitignore`). PR B: large
in diff but mostly deletion (about 600-800 lines out of three scripts and their
tests, about 150 in), with the deletion in its own commit.
