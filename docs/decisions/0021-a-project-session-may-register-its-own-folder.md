# ADR-0021: A Project Session May Register Its Own Folder

## Status

**Accepted** (2026-11-13, #466). Supersedes decision 5 of
[ADR-0016](0016-session-roots-and-the-user-tier.md) ("Registration is a
workspace script"); the rest of ADR-0016 stands, decision 6 (the user-tier
rule) included.

## Context

ADR-0016 decision 5 made registration "a workspace operation, not something
a project session does to itself", and decision D1 on #332 (2026-10-13)
split adding a project into two steps: register from the workspace, onboard
from the project. Both follow the session-root rule: a session only changes
things under the root it was launched in.

On 2026-11-13 the owner asked: "Is there a good reason for that other than
the agents only modify stuff where they were launched idea?" A second
reason had been bootstrap: a session in a folder that was not registered had
no workspace skills until registration enabled the plugin for that root.
That reason ended with [ADR-0020](0020-plugin-enabled-once-at-user-scope.md)
(#446, 2026-11-12): the plugin is enabled once, at user scope, so a session
in any folder already has `/agent-workspace:onboard-project`. What is left
is the session-root rule, which already has one narrow exception: a project
session writes its own project's settings file in the workspace checkout,
through `project_setting.sh set`.

The owner wants one step from the project's own folder: onboarding, run in
a folder that is not registered, offers to register it and carries on. He
approved this record by name on 2026-11-13 ("yes to ADR-0021").

Registration is also the gate for the user tier: a folder's registration is
what lets the promoted scripts (`build.sh`, `test.sh` and the rest) run
there. A registration that needs no permission would let text in a folder
the owner does not trust (its instructions file, say) have an agent
register the folder with a build command of its choosing, then run it
through the promoted `build.sh`, with no prompt at either step.

So the script that does the write is not promoted to the user tier: ADR-0016
decision 6 stands (an entry may be promoted only if it is inert outside
every registered root, and this script acts only there), and this record
does not supersede it. The script has no line in
`.agent/user_tier_scripts.txt`, so no permission rule allows it, and each
call asks for permission, showing the full command. That prompt is the
owner's gate, unless he has allowed the command: a session in a folder he
does not trust cannot register the folder, and so make its own build
command runnable, without him seeing the command.

## Decision

### 1. A session may register the folder it was started in

A session started in a folder that is not registered may write that
folder's own line in the workspace's registry (`.agent/projects.local`) and
its settings file (`.agent/projects.d/<name>`), through one guarded script,
`.agent/scripts/register_session_root.sh`, and nothing else in the
workspace. What guards it, as built in #466: it takes no path (the folder
is its working directory) and no option but `--dry-run` and the folder's
build and test commands; it refuses a folder that is already registered,
lies inside or over a registered root or the workspace, is not the top of
its git repository or is a linked worktree, or whose name is registered;
and it hands over to `register_project.sh` with `--skip-run`, never
`--install-user-tier` (the installer rewrites `~/.claude`). The script's
header holds the current rules.

This is a second named exception to the session-root rule, beside the
project settings file, and of the same kind: per-machine, gitignored
workspace configuration that the project's onboarding owns.

### 2. Registration from the workspace keeps working

`register_project.sh <path>`, run from the workspace's main checkout, is
unchanged and remains the way to register with options the narrow script
does not take (a name, a type, a parent root, `--remove`).

## Consequences

- **Onboarding is one step from the project's folder.**
  `/agent-workspace:onboard-project` in a folder that is not registered
  shows the registration's dry run, asks one yes in text and, on that yes,
  registers the folder and carries on.
- **A yes in text, and the permission prompts as a second gate.** The dry
  run and the real call each ask for permission, but a prompt is not
  guaranteed: "Yes, and don't ask again" on the dry run's prompt allows the
  real call too, and auto mode or a broader allow rule removes both. So
  the skill asks one yes in text after showing the dry run, before the real
  call, and the real call's prompt, when it appears, is a second gate.
- **The build and test are not run** by a registration from a project
  session; the status says so.
- **A folder in no git repository cannot be registered this way yet.**
  The owner decided on 2026-11-12 that any registered folder is a project,
  but registration's gate (`adapter validate`) still requires a git
  repository. Its dry run does not run the gate, so it looks clean until
  the real run refuses and rolls back. This is a named gap, not fixed here.
- **The session that registers lacks the workspace layer** the
  `SessionStart` hook gives a registered root: it started before the
  registration. A new session at the root has it.

## Alternatives Considered

- **Promote the script to the user tier**, with a guard-test exception.
  Rejected: registration would need no prompt, which removes the owner from
  the gate that turns on every user-tier script for a folder (the chain in
  Context), and it breaks ADR-0016 decision 6, which this record does not
  supersede.
- **Promote `register_project.sh` itself.** Rejected: it takes any path and
  every option, so a project session could register or rewrite any folder.
- **Loosen `session_root.sh` or `registry_require_root`** so a project
  session's ordinary scripts accept an unregistered root. Rejected: their
  refusals are by design, and loosening them opens every workspace write,
  not only registration.

## References

- [ADR-0016](0016-session-roots-and-the-user-tier.md) — decision 5
  superseded here; decision 6 constrains the script
- [ADR-0020](0020-plugin-enabled-once-at-user-scope.md) — ended the
  bootstrap reason for registering from the workspace
- [ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md) — the
  pointer added to ADR-0016's Status
- [ADR-0017](0017-design-document-is-the-current-picture.md) — why this is a
  new ADR and not an edit of ADR-0016
- Issue #466 (this change), #332 (registration and onboarding, D1)
