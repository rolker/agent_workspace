# ADR-0019: The agent-workspace Plugin Is Enabled Once, at User Scope

## Status

**Accepted** (2026-11-12, #446). Supersedes decisions 3 and 4 of
[ADR-0018](0018-plugin-based-skill-delivery.md), its decision 6's
paragraph on how `run-issue` decides the prefix (`skill_prefix.sh`; by
decisions 3 and 6 here), and its rejected alternative "Enable the plugin
at user scope"; the rest of ADR-0018 stands.
Withdraws the scoped exception to
[ADR-0016](0016-session-roots-and-the-user-tier.md) decision 2 that
ADR-0018 decision 4 recorded.

## Context

ADR-0018 delivered the workspace skills to project sessions through the
`agent-workspace` Claude Code plugin and had the installer enable it at
local scope in every registered root: one `claude plugin` call pair per
root, writing each root's gitignored `.claude/settings.local.json`. Keeping
that correct took most of the installer: which roots to skip (the
workspace's own tree, `parent=` instances, plain directories inside another
repository), refusals where the CLI's local scope would write the wrong
file, a takeover of the CLI's one machine-level marketplace record, and a
removal path in registration and its rollback.

ADR-0018 rejected user scope because it "has the same global reach as the
symlinks". The reason the symlinks were retired was the name collision,
and the plugin's namespace (`/agent-workspace:<skill>`) removes that
whatever the scope. The owner decided on 2026-10-13 ("What if I enabled it
for all of ~?", "I like that it could simplify things") and again on
2026-11-12 ("Doesn't the plugin namespace mitigate earlier fears of skill
name collisions?") that the plugin is enabled once, at user scope. The
goal is simplification: less installer code, not a second path beside the
per-root one.

Checked before deciding (claude 2.1.322, scratch HOME, 2026-11-12):
`claude plugin marketplace add <checkout> --scope user` and `claude plugin
install agent-workspace@agent-workspace --scope user` write only under
`~/.claude` (`settings.json`: `extraKnownMarketplaces` and
`enabledPlugins`; `plugins/`), and a second user-scope `marketplace add`
of the same name from another path repoints both records.

Checked live by the opt-in suite (`tests/live/plugin_acceptance.sh`, user
cases U0 to U8; claude 2.1.323, 2026-11-12), with the plugin at user scope
and the workspace copy's tracked `.claude/settings.json` setting it to
false:

- a session at the workspace checkout's root, and in a worktree of it,
  lists each shipped skill once, bare;
- a session started in a subdirectory of the checkout (a plain
  subdirectory, and a registered root inside its tree with no `.git` of
  its own) lists each shipped skill twice, bare and under the plugin's
  prefix; both names run the same skill;
- a git repository nested in an ordinary root, and an unregistered folder
  in no git repository, list the prefixed skills;
- local `true` plus user `true` lists the skill once;
- a root whose local entry is `false` under user `true` has no plugin
  skill.

The doubling in workspace subdirectories was one of the plan's stop
conditions. Curing it would take a per-root `false` written into each such
directory, which brings back a per-root write. Asked on 2026-11-12 "Is a
doubled skill list in workspace-subfolder sessions acceptable?", the owner
answered "Q1 accept it".

## Decision

### 1. The installer enables the plugin once, at user scope

`user_tier_install.sh` runs `claude plugin marketplace add <checkout>
--scope user` and `claude plugin install agent-workspace@agent-workspace
--scope user`, from a throwaway directory in no git repository, only when
the records do not already show the plugin enabled from this checkout and
the machine-level record naming it; it reads both back. A re-run that
finds them current makes no CLI call. Another checkout's user-scope
declaration is repointed by the same `marketplace add` (the user tier is
already singular); there is no separate machine-record takeover.

### 2. Nothing is written into a project checkout

ADR-0018 decision 4's exception is withdrawn. The plugin's records are
`~/.claude/settings.json` and the CLI's `~/.claude/plugins/`, which the user
tier already owns (ADR-0016 decision 3). Registration enables nothing per
root, and `--remove` removes nothing from the root.

### 3. The workspace checkout sets the plugin to false, in a tracked file

The checkout's tracked `.claude/settings.json` holds
`"enabledPlugins": {"agent-workspace@agent-workspace": false}`, so a
session at its root or in a worktree lists each shipped skill once, bare
(the plugin's source is the checkout's own `.claude/skills`). It is a
commit, not an installer write: the installer never edits that file.
`--check` reports it missing.

A session started in a subdirectory of the checkout lists each shipped
skill under both names, and both run the same skill. This is accepted
(owner, 2026-11-12); nothing per directory is written to cure it.
`skill_prefix.sh` answers bare there, because the bare name works.

### 4. A project opts out in its own settings

Narrower scope wins: a root whose project or local settings set the plugin
to `false` has none of its skills. That is the root's own setting, not
installer logic, and the installer has no per-root switch.

### 5. The per-root generation is migrated

Install removes this checkout's local-scope entries left by the per-root
installer, after the user-scope enable, with `claude plugin uninstall
--scope local` and `marketplace remove --scope local` run from the root.
It looks in the registered roots, the checkout, and every local-scope
install the CLI's `installed_plugins.json` lists. It runs the CLI only
where the root is its own git toplevel (not a linked worktree) or is in no
git repository; anywhere else, and for a recorded directory no longer on
disk, it prints the removal by hand. A local `false` and another
checkout's entry are left. `--uninstall` removes both scopes' entries.

### 6. Skill names follow from the location alone

`skill_prefix.sh` (ADR-0018 decision 6) answers bare in the workspace
checkout's git repository and `agent-workspace:` anywhere else; it reads no
registry and refuses nothing. `session_root.sh` keeps refusing a package
repository nested in a root and a subdirectory of a root in no git
repository, for reasons that are about the root, not the plugin.

## Consequences

- **The installer shrinks.** The per-root classification, refusals,
  takeover and `--disable-root` are gone; the plugin part is an enable, a
  migration and their checks.
- **Every session on the machine has the plugin**, unrelated repositories
  included. The skills are namespaced, so nothing is shadowed; a project
  that does not want them sets the plugin to false.
- **Workspace-subfolder sessions list each shipped skill twice** (decision
  3). Both names run the same skill.
- **The issue's acceptance line "a workspace session lists each skill
  once, under its bare name" holds at the checkout's root and in its
  worktrees only.**

## Alternatives Considered

- **Keep enabling per root at local scope** (ADR-0018 decision 3).
  Rejected by the owner's decisions of 2026-10-13 and 2026-11-12: it keeps
  the per-root machinery the change exists to remove.
- **Write a per-root `false` into each workspace subdirectory root** to
  cure the doubling. Rejected (owner, 2026-11-12): it brings back a
  per-root write for a doubling whose two names run the same skill.
- **Have the installer write the workspace's `false` entry.** Rejected:
  the installer never edits a tracked file, and a committed entry reaches
  every clone.

## References

- [ADR-0018](0018-plugin-based-skill-delivery.md) — decisions 3 and 4 and
  the user-scope alternative superseded here; the rest stands
- [ADR-0016](0016-session-roots-and-the-user-tier.md) — decision 2's
  exception withdrawn; the user tier gains the plugin's `~/.claude` entries
- [ADR-0017](0017-design-document-is-the-current-picture.md) — why this is
  a new ADR and not an edit of ADR-0018
- Issue #446 (this change), #394 (hook entries recognised by path, which
  the CLI's rewrite of `~/.claude/settings.json` needed first), #332
  (registration)
