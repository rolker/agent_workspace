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
- **A `parent=` instance in its parent's project.** A session reads the
  local settings of its project root, which is its git toplevel, or the
  main repository's for a git worktree. The live suite observed this with
  claude 2.1.282 (case G). So a plugin enabled at the parent reaches an
  instance only when the instance is a plain directory inside the
  parent's repository or a worktree of it. The installer checks this
  (`git rev-parse --git-common-dir`, compared as `pwd -P` forms). For
  those instances the parent is the root that gets enabled. Any other
  instance is enabled as a root of its own, with a note saying why, and
  `--check` holds it to that. That covers an instance in no git
  repository (including every instance of a plain-directory parent) and
  a separate repository nested in the parent. Before that observation the
  installer skipped every instance inside its parent's directory, which
  left the plain-parent and separate-repository shapes without the
  plugin.

  A declaration in a skipped instance, from this checkout or another, can
  shadow the parent's. `--check` reports it and install exits 1 naming the
  file to edit by hand. The installer does not run the CLI there. A
  skipped instance always shares its parent's repository. When it is a
  plain directory in that repository, local scope from there writes the
  repository's toplevel settings, which hold the parent's working enable
  (live case K asserts this against a repository with no declaration;
  that form of the case has not run yet). When it is a linked worktree,
  where local scope writes has not been established. Either way a
  local-scope remove could strip the parent's enable. The takeover's
  scratch directory is refused inside a git repository for the same
  reason.

  A session in a git repository nested inside any root, such as a colcon
  package repository under `src/`, has that repository as its project
  root. It does not see the root's plugin (live case G), and the
  registry does not list it, so the installer cannot enable it there.
- **A root not on disk.** The installer prints a note. This is not an
  error.

A root that is in no git repository at all is enabled.

The plugin step has two parts, in this order:

1. **The machine-level marketplace record, before any project root.**
   The CLI keeps one record per marketplace name for the whole machine
   (see Consequences). When that record does not name this checkout
   (it names another, or has no entry at all), and some registered root
   can be enabled from this one,
   install takes it over with one `marketplace add` run from a throwaway
   directory outside every project and every git repository, then reads
   the record back. If the CLI fails, or exits 0 and the record still
   does not name this checkout, install exits 1 at that point and no
   project root is touched. With no root to enable, the record is left
   alone.
2. **Each registered root's own declaration.** This part never touches
   the machine record and never removes a working declaration to repoint
   anything. It only enables a root that lacks the plugin, or replaces a
   root's declaration that names another checkout or no longer works.
   It still runs `marketplace remove --scope local` in some roots, so the
   installer reads the machine record again afterwards. If some root is
   now enabled from this checkout and the record does not name it, the
   installer takes it back once, the same way, and exits 1 if it cannot.

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
- a skipped `parent=` instance that declares the plugin itself
  (and, as a note, one that disables it locally with
  `enabledPlugins[...] = false`, which install leaves alone because it may
  be deliberate);
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
prefix is a caller-supplied string and is never derived from `--type`. A
workspace session driving a project issue has bare skills, and
`/start-task` moves the cwd mid-run.

`run-issue` decides the prefix once per run, before step 1, with
`.agent/scripts/skill_prefix.sh`. The script applies a location rule to
the directory the session started in. In the workspace checkout's git
repository (the checkout, a worktree of it, or a root such as `p11-jazzy`
inside its tree), the names are bare. In a registered project root, they
take the `agent-workspace:` prefix. Anywhere else, including a repository
nested in a root whose sessions read neither, the script fails with a
message and `run-issue` stops rather than guess. The rule holds because the
installer never enables the plugin in the workspace: the plugin's source
is the workspace's own `.claude/skills`, so enabling it there would load
every shipped skill twice. An earlier version asked the model to copy
`${CLAUDE_PLUGIN_ROOT}` into a shell command. Live run 2 showed a model
replacing that placeholder with its cwd, so the decision no longer passes
through anything the model has to transcribe.

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
  `--check` reads that one record, read-only, and flags it whenever some
  root has the plugin enabled from this checkout and the record does not
  name this checkout. That includes a record with no entry for it: live
  case J saw an absent record leave every enabled root without the
  plugin. This relies on the CLI's file format, and a file the installer
  cannot read an entry from counts as no entry. **Last install
  wins**: install from this checkout, finding the record on another
  checkout, takes the name over as the one machine-level step of
  decision 3, before any project root. The record is global, so it is
  handled once and never inside the per-root loop: an earlier per-root
  takeover that failed left the record foreign, and every later root
  repeated the failure and lost its declaration. The live suite's case I
  saw the CLI replace the record on such an add, and the record survive
  the throwaway directory's removal. The installer still reads the record
  back and exits 1, with every root untouched, if it does not name this
  checkout. The other checkout's `--check` then flags the
  record in turn, and its own install takes the name back. This matches
  the user tier, which is already singular (one checkout owns
  `~/.claude`).
- **A local `marketplace remove` drops the machine record** (observed
  live, case J). Removing the plugin from any one root also deletes the
  machine-level record, and every other root then stops reaching the
  plugin until the record is written again. Install removes the plugin
  from doubled roots and instance declarations, so it re-reads the record
  after the per-root step and takes it back (decision 3). `--uninstall`
  drops the record along with this checkout's roots, which is intended.
  Whether it also drops a record that names another checkout is not
  verified; if it does, that checkout's next install takes the name back.
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
- run-issue's prefix step, run by sessions through the Bash tool at the
  workspace root and at a project root;
- which `parent=` instance shapes reach the plugin enabled at their parent
  (a worktree or a plain directory of the parent's repository) and which
  do not (a plain-directory parent's instance, a separate repository);
- a second root enabled from the same source, with the first still working;
- the installer's machine-level takeover: a `marketplace add` from a
  scratch directory repoints the record, and the record survives the
  directory's removal;
- removing the plugin from one root, with another still working.

## Alternatives Considered

- **Keep the symlinks and rename the colliding skills.** Rejected: it fixes
  only the collisions known today. Symlinks still reach every unrelated
  repository.
- **Ship the whole `.claude/skills` directory as the plugin's skills.**
  Rejected: it exposes the 9 workspace-scoped skills (see decision 2) and
  the per-machine `/make_*` skills.
- **Enable the plugin at user scope.** Rejected: it has the same global
  reach as the symlinks.
- **Derive the handoff prefix from `--type` or the current cwd.**
  Rejected: `--type` says nothing about the host, and the cwd moves during
  a run (decision 6 uses the session's starting directory, once).
- **Detect the prefix from `${CLAUDE_PLUGIN_ROOT}` substitution.**
  Replaced: it depended on the model copying a placeholder literally
  (decision 6).
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
