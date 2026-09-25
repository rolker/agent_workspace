# ADR-0017: Workspace Skills Reach Project Sessions Through a Claude Code Plugin

## Status

**Provisional.** Supersedes decision 3 of
[ADR-0016](0016-session-roots-and-the-user-tier.md) for **skills only**; the
rest of ADR-0016 section 3 (the `SessionStart` hook, the `PreToolUse` hook, the
permission allow-rules) stands until issue #351 moves the hooks into the
plugin too. Records one scoped exception to ADR-0016 decision 2.

Promote to Accepted when ADR-0016's own acceptance run passes (see
"Acceptance" below). As with ADR-0016, flipping this line is a status-line
edit, not a substantive one, and ADR-0008 permits it.

## Context

ADR-0016 decision 3 shipped workspace skills to project sessions as one
symlink per skill in `~/.claude/skills/`. Two properties of that mechanism
made it wrong (issue #345):

- **Name collisions.** A user-tier skill and a project skill of the same
  name collide. The symlink won: `gz4d` has its own `plan-task`, `research`,
  `audit-project` and `brand-guidelines`, and all four were shadowed.
- **Global reach.** `~/.claude/skills/` is read by every session on the
  machine, in every repository, registered or not. ADR-0016's own user-tier
  rule (decision 6: inert outside the workspace and every registered root)
  was met by the hooks and scripts but not by the skills, which cannot
  carry a guard.

A Claude Code plugin fixes both. A plugin's skills are namespaced
`/<plugin>:<skill>`, so `/agent-workspace:plan-task` coexists with a
project's own `/plan-task`. And a plugin enabled at *local* scope is
enabled only for the directory it was installed from. A spike on
2026-09-24 (claude 2.1.281) confirmed this live:

- `claude plugin marketplace add <checkout> --scope local` and
  `claude plugin install <plugin>@<marketplace> --scope local`, run from a
  project root, write only that root's gitignored
  `.claude/settings.local.json` (`extraKnownMarketplaces` with a `directory`
  source, and `enabledPlugins`). The CLI also keeps its own records under
  `~/.claude/plugins/`.
- A worktree of that project sees the plugin. An unrelated repository sees
  nothing.
- A directory marketplace loads the skills from its source in place: an
  edit to a skill applies in the next session, with no reinstall.
- `${CLAUDE_PLUGIN_ROOT}` in a plugin-loaded `SKILL.md` is replaced with the
  plugin's source directory.
- A sub-agent told to run `agent-workspace:<skill>` runs it, so phase
  handoffs work with prefixed names.

The owner chose the plugin and accepted the rename as its cost.

## Decision

### 1. The workspace checkout is a one-plugin marketplace

`.claude-plugin/marketplace.json` names one plugin, `agent-workspace`, with
source `./`. The plugin root is the checkout root. The marketplace is also
named `agent-workspace`, so the plugin's id is
`agent-workspace@agent-workspace`.

### 2. The plugin ships the `project` and `both` skills, and nothing else

`.claude-plugin/plugin.json`'s `skills` field lists each skill whose
`SKILL.md` declares `session_scope: project` or `session_scope: both` (13
skills when this ADR was written). It is an array of per-skill directory
paths, not the whole `.claude/skills` directory. The 9 workspace-scoped
skills call workspace scripts by cwd-relative paths, which from a project
cwd would fail, or run a same-named script the project ships. The
generated `/make_*` skills are per-machine files and must not ship either.

The array is generated from frontmatter (`make generate-user-tier-skills`,
which runs `user_tier_install.sh --generate-plugin-manifest`), never
hand-maintained. `test_plugin_manifest.sh` re-derives the list with its own
parser and fails on any difference. It also fails if the checkout root
grows a default plugin component location (`commands/`, `agents/`,
`hooks/`, `bin/`, `.mcp.json`, ...), because Claude Code would load it
whether or not the manifest names it.

### 3. The installer enables the plugin per registered root

`user_tier_install.sh` enables the plugin at local scope in every
registered session root. It skips:

- **A root whose git toplevel is the workspace checkout**, compared in
  `pwd -P` form (the `p11-*` shape: registered roots with no `.git` of their
  own, inside the workspace tree). A session there already sees the bare
  skills by directory walk-up. Enabling the plugin would load every skill
  twice, under two names, and would write into the workspace's own
  settings.
- **A `parent=` instance inside its parent's directory.** Its parent root
  is the one that gets enabled. This rests on a session in the instance
  seeing the parent's local-scope settings, which the live suite's case G
  checks. The registry does not require an instance to lie under its
  parent, so the installer checks containment (`pwd -P` forms). An
  instance outside its parent's directory is enabled as a root of its
  own, with a note, and `--check` holds it to that. A declaration in an
  instance inside its parent, from this checkout or another, can shadow
  the parent's: `--check` reports it and install removes it.
- **A root not on disk.** The installer prints a note. This is not an
  error.

A root that is in no git repository at all is enabled.

The plugin step has two parts, in this order:

1. **The machine-level marketplace record, once per run, before any
   project root.** The CLI keeps one record per marketplace name for the
   whole machine (see Consequences). When that record names another
   checkout and some registered root is to be enabled from this one,
   install takes it over with one `marketplace add` run from a throwaway
   directory outside every project and every git repository, then reads
   the record back. If the CLI fails, or exits 0 and leaves the record on
   the other checkout, install exits 1 at that point and no project root
   is touched. With no root to enable, the record is left alone.
2. **Each registered root's own declaration.** This part never touches
   the machine record and never removes a working declaration to repoint
   anything. It only enables a root that lacks the plugin, or replaces a
   root's declaration that names another checkout or no longer works.
   It still runs `marketplace remove --scope local` in some roots, so the
   installer reads the machine record again afterwards. If the record
   named this checkout before and no longer does, the installer takes it
   back once, the same way, and exits 1 if it cannot.

Enabling is idempotent. A root that already has the plugin enabled from
this checkout does not run the CLI at all. The installer checks the
result by reading the settings file, not by trusting the CLI's exit code.
With no
`claude` CLI on `PATH` (a Codex-only machine) the installer prints a note
and skips enabling the plugin. Removing one that is present (a doubled
root, `--uninstall`) cannot be done without the CLI, so that is an error,
not a note. `--check` reads JSON only and never runs the CLI. It
reports:

- a registered root without the plugin, or with it declared from another
  checkout;
- a root inside the workspace checkout's git tree (skipped) that has the
  plugin enabled anyway;
- a `parent=` instance inside its parent that declares the plugin itself;
- the plugin enabled at the workspace checkout itself;
- a machine-level marketplace record that names another checkout (see
  Consequences). Without the `claude` CLI on `PATH` this is a note that
  says the CLI is needed, not drift, because install cannot take the
  record over there either.

`--uninstall` removes the plugin from every root where this checkout
declared it. A root whose declaration names another checkout is left alone
with a note: it is that checkout's to remove. A declaration whose source
is not on disk has no checkout left to remove it, so it counts as this
checkout's. The installer cannot tell a deleted checkout from one that is
only unreachable for now, such as one on an unmounted drive or network
share, so both are treated as stale: this checkout's `--uninstall` removes
such a declaration from a shared root, and install replaces it. Checkouts
on storage that comes and goes are out of scope. Install, by contrast,
repoints such a root when it is in this checkout's registry, and removes
the plugin from a skipped root or the workspace checkout whichever
checkout declared it, since there it doubles every skill either way.

A root whose `.claude/settings.local.json` is not valid JSON is reported
and never rewritten. Whether the plugin is enabled there cannot be known,
so install, `--check` and `--uninstall` all exit 1 on it, including in a
root where the plugin must not be (a skipped root, the workspace checkout).

Issue #332's registration flow reuses this step for a newly registered
root by re-running the installer. There is no second enable entry point
to keep in sync.

### 4. Exception to ADR-0016 decision 2, scoped

ADR-0016 decision 2 says the workspace never writes into a project checkout
beyond `.git/info/exclude` and an untracked `COLCON_IGNORE`. This ADR adds
exactly one exception: **the project root's gitignored
`.claude/settings.local.json`, written only by the two `claude plugin`
commands above** (and removed by `claude plugin uninstall` / `marketplace
remove`). The installer never edits that file itself, and it writes
nothing else into a project checkout. A tracked `.claude/settings.json` is
never touched.

### 5. The skill-symlink mechanism is retired, and its leftovers are drift

Nothing creates `~/.claude/skills/` symlinks any more. Install removes any
that resolve into an `agent_workspace` checkout, this one or another.
`--check` reports each one as drift, so a machine that never re-runs
install still learns about them. `--uninstall` removes this checkout's
links. A symlink the user made into a directory that is not a workspace
checkout is left alone.

### 6. Handoffs name the host session's form of each skill

`dispatch_phase.sh --skill-prefix <name>:` puts the prefix on every slash
command in a handoff's task line. The default is empty, which is correct
for a workspace session and for Codex, which never has the plugin. The
prefix is a caller-supplied string and is never derived from `--type` or
`$PWD`. A workspace session driving a project issue has bare skills, and
`/start-task` moves the cwd.

`run-issue` decides the prefix once per run. It sets
`PLUGIN_ROOT='${CLAUDE_PLUGIN_ROOT}'`, single-quoted so that the shell never
expands the token from an environment another plugin may have set. It uses
`agent-workspace:` only when that value is a directory whose `pwd -P` form
equals the workspace root's.

For the model, the project session's `SessionStart` header states which
form applies. That header is output, not a source comment, because the
model reads the output. Skills still name each other by bare slash command
in their prose.

## Consequences

- **Project sessions invoke `/agent-workspace:<skill>`.** Workspace sessions
  keep the bare names.
- **`gz4d` gets its workspace skills back on the next install**, with its
  own four same-named skills unshadowed. `p11-jazzy` and `p11-rolling` do
  not need the plugin and do not get it.
- **Hooks still use the old user-tier mechanism** until #351 moves them.
  Until then, the permission allow-rules and the two hook entries in
  `~/.claude/settings.json` are unchanged.
- **The machine-level `~/.claude/plugins/` records** are the CLI's
  bookkeeping, not the workspace's. The installer never edits them
  itself; they change only through the CLI calls it runs.
- **One `agent-workspace` marketplace source per machine.** The CLI keys
  `~/.claude/plugins/known_marketplaces.json` (under `CLAUDE_CONFIG_DIR`
  instead, when that is set, observed with claude 2.1.282; the installer
  reads it there) by marketplace name, so two
  checkouts on one machine cannot both be the plugin's source. A root's
  `settings.local.json` can declare this checkout while the machine record
  names another, and then sessions may load the other checkout's skills.
  `--check` reads that one record, read-only, and flags it only when it
  positively names a different directory and some root has the plugin
  enabled from this checkout. A missing file, entry or `path` field says
  nothing either way, because the format is the CLI's. **Last install
  wins**: install from this checkout, finding the record on another
  checkout, takes the name over as the one machine-level step of
  decision 3, before any project root. The record is global, so it is
  handled once and never inside the per-root loop: an earlier per-root
  takeover that failed left the record foreign, and every later root
  repeated the failure and lost its declaration. That the CLI replaces the
  record on such an add is not yet verified live, so the installer reads
  the record back and exits 1, with every root untouched, if it still
  names the other checkout. The other checkout's `--check` then flags the
  record in turn, and its own install takes the name back. This matches
  the user tier, which is already singular (one checkout owns
  `~/.claude`).
- **A new skill ships only after the manifest is regenerated.** Add the
  `session_scope` field, run `make generate-user-tier-skills`, and commit
  the manifest. `test_plugin_manifest.sh` fails the commit otherwise.

### Acceptance

ADR-0016's promotion condition is the gz4d `/run-issue` acceptance run
(issue #317). That run now exercises plugin-delivered skills. One passing
run promotes ADR-0016 and also serves as this ADR's live acceptance. Until
then, the opt-in `.agent/scripts/tests/live/plugin_acceptance.sh` covers:

- the collision case;
- worktree inheritance, and no plugin in an unrelated repo;
- the workspace-root shape, with no doubled skills;
- the skip guard for a `p11`-shape root;
- the bare-load and plugin-load prefix detection;
- a `parent=` instance reaching the plugin enabled at its parent;
- a second root enabled from the same source, with the first still working.

## Alternatives Considered

- **Keep the symlinks and rename the colliding skills.** Rejected: it fixes
  only the collisions known today. Symlinks still reach every unrelated
  repository.
- **Ship the whole `.claude/skills` directory as the plugin's skills.**
  Rejected: it exposes the 9 workspace-scoped skills (see decision 2) and
  the per-machine `/make_*` skills.
- **Enable the plugin at user scope.** Rejected: it has the same global
  reach as the symlinks.
- **Derive the handoff prefix from `--type` or the cwd.** Rejected: neither
  says which skill set the host loaded (decision 6).
- **Copy the skills into each project.** Rejected for the reasons ADR-0016
  gives: it writes into project checkouts, and the copies drift.

## References

- [ADR-0016](0016-session-roots-and-the-user-tier.md) — section 3 superseded
  for skills; decision 2 gets the scoped exception above
- [ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md) — why this is
  a new ADR and ADR-0016 gets only a Status/References pointer
- [ADR-0014](0014-in-process-phase-handoff.md) — `dispatch_phase.sh`, which
  gains `--skill-prefix`
- Issue #345 (this change), #351 (hooks into the plugin), #317 (the
  acceptance run), #335 (zero-footprint design doc; this is its packaging
  answer for skills), #332 (registration; reuses decision 3), #321
  (orchestrator skill; prefixed sub-agent handoffs confirmed in the spike)
