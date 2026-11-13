---
issue: 466
---

# Issue #466 — onboard-project offers to register an unregistered folder, from the project session

## Issue Review
**Status**: complete
**When**: 2026-11-13 11:25 -05:00
**By**: Claude Code (claude-sonnet-5-5)

**Issue**: #466

### Scope Assessment

**Well-scoped?** Yes, if the plan keeps to one thin path: a narrow registering call that a project session may run, the skill's step 1 branch that uses it, tests, and the design.md edits. It fits "under an hour" only if the plan does not rework `register_project.sh` and does not open any other workspace write to project sessions. Two things would make it larger: (1) accepting a folder with no git repository (see below), (2) a refusal path that needs its own new checks instead of reusing the ones `register_project.sh` already makes.
**Right repo?** Yes. Skill, scripts, ADR and design are all workspace.
**Serves**: Onboarding a project, one step from its own folder (registering and onboarding in one flow) - `docs/design.md#sessions-and-roots` and `docs/design.md#registry-and-adapters`
**Design picture?** Changes Sessions and roots (the session-root rule gains a second named exception beside the project settings file; the onboarding bullet gains "an unregistered folder is offered registration") and Registry and adapters (Target says registration is a workspace-side step). The issue records the owner's decision (2026-11-13) and names these sections, so this is `OK` with a pointer; do not re-ask the flow itself.
**Dependencies**: none open. ADR-0020 (#446, merged) removed the bootstrap reason for the split.

What is in scope: onboard-project step 1 in an unregistered root shows the `--dry-run` output and registers on a yes; the guard change that lets exactly that call run from an unregistered root; refusals; tests; design.md.

What the plan must settle (grounded in the code):

- Which script writes. `register_project.sh` is deliberately not in `user_tier_scripts.txt` ("never promoted: it writes the registry") and refuses to run from a linked worktree; it runs against the workspace checkout. The smallest form is a new narrow entry point (for example `register_from_project.sh`, user-tier, carrying its own guard) that takes no path argument (the root is the session's own `$PWD`, checked as the top of a folder that is registered nowhere), refuses anything else, and calls `$WS_ROOT/.agent/scripts/register_project.sh` with `--skip-run` and without `--install-user-tier`. Promoting `register_project.sh` itself is the wrong direction: it takes arbitrary paths and flags.
- `registry_require_root` refuses (exit 1) an unregistered dir by design, and `session_root.sh` exits 1 for it (line 152). Do not loosen either. The new script does its own check ("this dir is no registered root, is not under or over one, is a directory") and the skill reads the unregistered case from `session_root.sh` exit 1 plus that script's own pre-check. `test_user_tier_guard.sh` asserts every promoted entry refuses from a sandbox repo registered nowhere, so the new entry needs a documented, tested exception form (a new marker such as `# user-tier: registers-cwd-only`), not a silent hole. That test change is the part most likely to run long.
- What is skipped or deferred: the build and test run (`--skip-run`; the status says so) and `--install-user-tier` (the installer rewrites ~/.claude; never from a project session). With no user tier on the machine the skill is not running at all (no `/agent-workspace:` command), so "no user tier" is a non-case here; the refusal that matters is `~/.claude/agent-workspace-root` pointing at a missing or non-main checkout.
- Refusals to show: folder inside another registered root, a parent root of registered ones, name collision, a linked worktree of the project (register the main checkout), the workspace checkout itself. All are checks `register_project.sh` already makes or can make with the registry helpers; the plan should test each message, not add new logic.
- Folder with no git repository: `session_root.sh` (line 172) refuses a root that is in no git repository when the session is in a subdirectory, and accepts it at the root itself. The owner decided 2026-11-12 that any registered folder is a project. The least-widening choice is to accept it if `register_project.sh` already does (verify by test) and name any gap in the issue/design rather than fix it here. Do not build non-git support in this change.
- Concurrency: the write is a registry line plus a settings file under the existing `.registry.lock`; no new locking.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | Action needed | Update design.md "Sessions and roots" (second named exception to the session-root rule, onboarding bullet) and "Registry and adapters" (Target: registration is no longer workspace-only), in the same change (ADR-0017), with change-log rows. The flow is already decided by the owner (issue body); the decision-record form is the open item, below. |
| Enforcement over documentation | Action needed | The exception must be enforced, not described: the new entry refuses anything but registering the session's own unregistered root, and `test_user_tier_guard.sh` and a new test cover it. Without that the user-tier rule (ADR-0016 decision 6) has an unguarded writer. |
| Only what's needed | OK | The issue's Not-in-scope list holds the line; the one-line registry write is the whole new capability. |
| Put each thing at the level it applies to | OK | Registry is per machine and workspace-owned; the skill stays in the project session. |
| Ask about what matters | Watch | The ADR form is the owner's by his 2026-11-13 rule; the flow itself is settled. Put only the record decision to him. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0016 | Yes | Decision 5 ("Registration is a workspace script ... not something a project session does to itself") is contradicted in part. The session-root rule it records (Sessions and roots; D1 on #332) gets a second narrow exception. Decision 6 (user-tier rule) is the constraint on the new script. |
| ADR-0008 | Yes | Governs the form: addendums are only cross-reference pointers; a change to what was decided needs a superseding ADR ("Was a decision changed? If yes, supersede"). |
| ADR-0017 | Yes | Accepted ADRs are superseded, not edited; design.md carries the current picture and is updated in the same change. |
| ADR-0018, ADR-0020 | Context | ADR-0018 already superseded decision 3 of ADR-0016 and ADR-0016's header says so; ADR-0020 removed the bootstrap reason. They are cited, not changed. |
| ADR-0013 | Yes | This review is an entry under it. |

**Decision records touched and in what form (for the owner, by name):** a new ADR, titled for example "ADR-0021: A project session may register its own folder", that supersedes ADR-0016 decision 5 only (partial supersession, the precedent being ADR-0018 over decision 3), and records the narrow exception to the session-root rule (a project session may write the registry line and settings file for its own unregistered root, through one guarded script, and nothing else). Then, under ADR-0008, a cross-reference addendum on ADR-0016 (a Status/header pointer "Decision 5 is superseded by ADR-0021", as it already does for decision 3) and a row in design.md's decision table. An in-place edit of decision 5 is not allowed: it changes what was decided. An addendum alone is not enough for the same reason. The session-root rule itself is not an ADR; it lives in design.md "Sessions and roots" (from #345) and changes there under ADR-0017.

### Consequences

- design.md: Sessions and roots, Registry and adapters, the ADR table row for ADR-0016 ("decision 5 is superseded by ADR-0021"), change-log rows.
- `.claude/skills/onboard-project/SKILL.md`: step 1 branch for exit 1 / unregistered, the Overview "Lifecycle position" paragraph ("register from the workspace") and the write list.
- `.agent/user_tier_scripts.txt` and its comment that register_project.sh is never promoted; `test_user_tier_guard.sh` and `test_user_tier_install.sh` (the generated allow-rules gain the entry).
- `.agent/knowledge/script_reference.md` (new script) and the register_project.sh header ("D1 step 1, workspace side").
- New test: a sandbox unregistered folder registers on the narrow call; each refusal; the call is inert from an already-registered root and from the workspace.

### Recommendations

- Put the record to the owner by name before writing it: new ADR superseding ADR-0016 decision 5 only, plus the ADR-0008 pointer on ADR-0016, not an edit or addendum alone.
- Keep the write to one new guarded user-tier script that registers only the session's own unregistered root (no path argument), delegates to `register_project.sh --skip-run` without `--install-user-tier`, and leave `session_root.sh`, `registry_require_root` and `register_project.sh`'s interface unchanged.
- Give the guard test an explicit, named exception form for this one entry rather than weakening the "refuses from an unregistered sandbox" assertion for the others.
- Accept a no-git folder only if `register_project.sh` already registers one (prove by test); otherwise state the gap in the skill and design.md and leave the fix to its own issue.
- Plan to finish the guard test first: it is the riskiest part for the hour budget; if it grows, split the skill wiring into a second small PR rather than widening this one.

### Actions
- [ ] Update design.md "Sessions and roots" (second named exception to the session-root rule, onboarding bullet) and "Registry and adapters" (Target: registration is no longer workspace-only), in the same change (ADR-0017), with change-log rows. The flow is already decided by the owner (issue body); the decision-record form is the open item, below.
- [ ] The exception must be enforced, not described: the new entry refuses anything but registering the session's own unregistered root, and `test_user_tier_guard.sh` and a new test cover it. Without that the user-tier rule (ADR-0016 decision 6) has an unguarded writer.
- [ ] Put the record to the owner by name before writing it: new ADR superseding ADR-0016 decision 5 only, plus the ADR-0008 pointer on ADR-0016, not an edit or addendum alone.
- [ ] Keep the write to one new guarded user-tier script that registers only the session's own unregistered root (no path argument), delegates to `register_project.sh --skip-run` without `--install-user-tier`, and leave `session_root.sh`, `registry_require_root` and `register_project.sh`'s interface unchanged.
- [ ] Give the guard test an explicit, named exception form for this one entry rather than weakening the "refuses from an unregistered sandbox" assertion for the others.
- [ ] Accept a no-git folder only if `register_project.sh` already registers one (prove by test); otherwise state the gap in the skill and design.md and leave the fix to its own issue.
- [ ] Plan to finish the guard test first: it is the riskiest part for the hour budget; if it grows, split the skill wiring into a second small PR rather than widening this one.
