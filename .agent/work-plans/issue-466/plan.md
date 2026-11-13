# Plan: onboard-project offers to register an unregistered folder, from the project session

## Issue

https://github.com/rolker/agent_workspace/issues/466

## Context

Today `onboard-project` step 1 runs `session_root.sh`; in an unregistered folder that exits 1
(verified: "neither in the workspace checkout nor under a registered project root") and the skill
says "register from a workspace session". `skill_prefix.sh` answers `agent-workspace:` there, so
the plugin skill is reachable. `register_project.sh` is deliberately not promoted (it writes the
registry, takes arbitrary paths). The owner wants onboarding to offer registration from the
project session itself. Goal: smallest change, one PR, under an hour.

Verified by sandbox runs (copy of the scripts, HOME redirected, temp dirs only):
- `register_project.sh <dir> --skip-run --dry-run` prints the registry line it would add and
  writes nothing; it takes no lock.
- A **git folder with no detectable build/test** is refused by the gate and rolled back
  ("no build command"), even with `--skip-run`; `--set build=none --set test=none` registers it.
  So the new script must pass through `--set build=` / `--set test=` (only those two keys).
- A **folder with no git repository** is refused by the gate (`adapter validate`: "not a git
  repository (no .git at its root)") and rolled back. Gap, out of scope: named in the skill and
  design.md, own issue; no non-git support is built here.
- A newly promoted script's absolute-path allow-rules (`Bash(<abs>:*)`, `Bash(<abs>)`) are written
  into `~/.claude/settings.json` by `user_tier_install.sh` from `user_tier_scripts.txt`. Machines
  already installed need the installer re-run (`--check` reports "allow-rule(s) missing"); until
  then the call prompts for permission rather than failing. Owner-visible step, listed in the PR.

## Approach

1. **Guard test first** (riskiest): `test_user_tier_guard.sh` gains a named marker
   `# user-tier: registers-cwd-only`, accepted only for the one manifest entry
   `register_session_root.sh` (named in the test), with static checks that the script calls the
   inverse guard (refuses when the cwd is inside or over a registered root or the workspace). Its
   behavioural probe moves out of the "refuses from an unregistered repo" loop (it would register
   there) into a dedicated block: unregistered sandbox + `--dry-run` writes nothing; any argument
   (a path) is refused; from a registered root and from the workspace it refuses. The assertion
   for every other entry is unchanged.
2. **`.agent/scripts/register_session_root.sh`** (new, chmod +x): args only `[--dry-run]`,
   `[--set build=<v>]`, `[--set test=<v>]`. Root = physical `$PWD`. Refuses: not the top of its
   git repository when in one, a linked worktree (register the main checkout), inside/over a
   registered root or the workspace, a name already registered, a nested git repo of a root.
   Then delegates to `$WS_ROOT/.agent/scripts/register_project.sh "$PWD" --skip-run [--dry-run]
   [--set ...]` (never `--install-user-tier`). WS_ROOT resolved as `session_root.sh` does.
   Reuses register_project's messages and `STATUS=` lines; adds no registry logic.
3. **Manifest**: add the entry to `.agent/user_tier_scripts.txt` with a comment (promoted
   because it writes only the session's own unregistered root; `register_project.sh` itself stays
   unpromoted). Run `test_user_tier_install.sh` (generated allow-rules gain the entry).
4. **New test** `test_register_session_root.sh` (chmod +x), synthetic sandbox only: registers an
   unregistered git folder (registry line + settings file, nothing in the project); dry run writes
   nothing; each refusal (inside a registered root, parent of one, name collision, linked
   worktree, subdirectory, the workspace, already registered); no-build folder refused until
   `--set build=none --set test=none`; no-git folder refused and rolled back (documents the gap);
   `--install-user-tier` never reached (sandbox `~/.claude` untouched).
5. **Skill** `.claude/skills/onboard-project/SKILL.md`: step 1 exit-1 branch: if the folder is
   unregistered, run `register_session_root.sh --dry-run`, show it, ask; on a yes run it (asking
   for build/test commands when the dry run says none were detected) then continue the run with
   the now-registered project; refusals are shown as printed. Overview "register from the
   workspace" paragraph and the write list gain the registry line + settings file as a write
   needing a yes. A no-git folder: say it is not supported yet.
6. **Docs**: `docs/design.md` Sessions and roots (the registration bullet and the one-exception
   paragraph gain the second exception; onboarding bullet) and Registry and adapters (Target),
   the ADR-0016 table row, change-log rows, in this PR (ADR-0017);
   `.agent/knowledge/script_reference.md` row; `register_project.sh` header pointer.
7. **Decision record, only after the owner's yes** (the host puts it to him by name): write
   `docs/decisions/0021-project-session-may-register-its-own-folder.md` superseding ADR-0016
   decision 5 only (ADR-0018 over decision 3 is the precedent) and recording the narrow
   exception, plus a one-line ADR-0008 pointer in ADR-0016's header. Not written in the plan
   phase. Number check: origin/main ends at 0020; no remote branch or open pull request
   (only #461, no ADR files) carries `0021`. Re-check at implement time.

## Files to Change

| File | Change |
|------|--------|
| `.agent/scripts/register_session_root.sh` | new guarded user-tier script |
| `.agent/scripts/tests/test_register_session_root.sh` | new test, `chmod +x` |
| `.agent/scripts/tests/test_user_tier_guard.sh` | named exception for the one entry |
| `.agent/user_tier_scripts.txt` | add the entry, adjust the "never promoted" comment |
| `.claude/skills/onboard-project/SKILL.md` | step 1 branch, Overview, write list |
| `docs/design.md` | Sessions and roots, Registry and adapters, ADR row, change log |
| `.agent/knowledge/script_reference.md` | new row |
| `.agent/scripts/register_project.sh` | header comment only |
| `docs/decisions/0021-*.md`, `docs/decisions/0016-*.md` | after the owner's yes only |

## Prior Art

`project_setting.sh set` is the existing precedent: a promoted script that writes one file of the
session's own project, guarded to that project. `ADR-0018` over ADR-0016 decision 3 is the
partial-supersession precedent. Rejected: promoting `register_project.sh` (arbitrary paths and
flags), loosening `session_root.sh` or `registry_require_root` (by-design refusals).

## Serves

Onboarding a project, one step from its own folder: `docs/design.md#sessions-and-roots` and
`docs/design.md#registry-and-adapters`.

## Design Picture

Changes: Sessions and roots (second named exception to the session-root rule, onboarding offers
registration) and Registry and adapters (Target: registration no longer workspace-only). Edited
in this PR.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | design.md edited in the same PR; ADR by supersession, not edit |
| Enforcement over documentation | exception enforced by the script's refusals and the guard test |
| Only what's needed | one script, no argument but build/test commands, no non-git support |
| Ask about what matters | only the ADR form goes to the owner |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0016 | Yes | decision 5 superseded in part; decision 6 constrains the script |
| ADR-0008 / 0017 | Yes | superseding ADR plus pointer; design.md updated with it |
| ADR-0018 / 0020 | Context | cited, unchanged |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| user_tier_scripts.txt | installer allow-rules; re-run installer on each machine (owner step) | Yes (PR note) |
| onboard-project step 1 | test_skill_paths.sh checks | Yes |
| register_project.sh header | test_register_project.sh (run, comment-only) | Yes |

## Open Questions

- Owner: the ADR-0021 form (host is asking). Installer re-run on each machine after merge.

## Estimated Scope

Single PR. Touched suites (run only these): `test_register_session_root.sh` (new),
`test_user_tier_guard.sh`, `test_user_tier_install.sh`, `test_skill_paths.sh`,
`test_register_project.sh`; pre-commit design-anchor check on the docs. The host runs the one
full pass before publishing.

**Stop condition**: stop and report, do not widen, if (a) the change needs an interface change to
`session_root.sh`, `registry_require_root` or `register_project.sh` (beyond its header comment),
(b) the guard test needs a second exception or a weaker assertion for another entry, (c) non-git
folders or a refusal not already made by the registry helpers turn out to need new registry
logic, or (d) the guard test (step 1) is still unfinished near the hour: split steps 5-6 into a
second small PR.
