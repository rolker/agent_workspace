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

## Checkpoint
**Status**: complete
**When**: 2026-11-13 11:19 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review keeps the issue's goal and scope; its seven actions are about how the change is built: one guarded script that registers only the session's own unregistered root and delegates to register_project.sh, a named exception in the guard test, the design.md edits; none adds or drops a behaviour the owner's words ask for)
**After**: issue-actions
**Decision**: proceed

Read: the Issue Review at 7395390f and its report. The one action that is the owner's, the decision record (a new ADR superseding ADR-0016 decision 5, with a pointer on ADR-0016), is put to him by name in the session before it is written; the plan may describe it, the implement pass writes it only after his yes.

### Decisions made (owner may veto)
- Proceed to planning with the review's narrow shape (one new guarded script, no interface change to session_root.sh, registry_require_root or register_project.sh) — undoing it: revise the plan at its checkpoint.

## Plan Authored
**Status**: complete
**When**: 2026-11-13 11:21 -05:00
**By**: Claude Code (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-466/plan.md` at `1d0b8f5a`

One new guarded user-tier script (register_session_root.sh) registers only the session's own unregistered root via register_project.sh --skip-run; onboard-project step 1 offers it; guard test gets a named exception; design.md in the same PR; ADR-0021 only after the owner's yes.

## Plan Review
**Status**: complete
**When**: 2026-11-13 11:24 -05:00
**By**: Claude Code (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #466 — onboard-project offers to register an unregistered folder, from the project session
**Plan**: `.agent/work-plans/issue-466/plan.md` at `1d0b8f5a`
**Branch**: `feature/issue-466`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, nine files, one new script that delegates to `register_project.sh`. The fix below makes it smaller (steps 1 and 3 drop). |
| Issue alignment | Good | Covers every "What the plan has to settle" item and the review's seven actions. Serves (as checked): "Onboarding a project, one step from its own folder: `docs/design.md#sessions-and-roots` and `docs/design.md#registry-and-adapters`"; both sections exist (design.md lines 177, 314). |
| File targeting | Needs work | `.agent/user_tier_scripts.txt` and `test_user_tier_guard.sh` should not change (finding 1). Add a "not in the manifest" assertion to the new test. |
| Consequences | Good | The installer re-run consequence disappears with finding 1. |
| Principle alignment | Concern | Promotion turns registration, the owner's trust gate for the whole user tier, into a call that needs no prompt (finding 1). |
| ADR compliance | Concern | Promotion breaks ADR-0016 decision 6, which the agreed ADR-0021 does not supersede (finding 1). Step 7 otherwise matches what the owner agreed: supersedes decision 5 only, a one-line pointer on ADR-0016, a script that writes only the folder's own registry line and settings file. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment / ADR compliance], must-fix**: do not promote `register_session_root.sh` (no line in `.agent/user_tier_scripts.txt`, so no allow-rule). How it goes wrong as planned: the owner opens a session in a folder he does not trust (a downloaded clone). Text in that folder (its CLAUDE.md, say) tells the agent to run `register_session_root.sh --set build=./x.sh` or just `register_session_root.sh` (detection writes `build=make` from the folder's own Makefile). That call is allow-listed, so no prompt. The next call, `build.sh`, is also allow-listed (`~/.claude/settings.json` has `Bash(<ws>/.agent/scripts/build.sh:*)`). It now passes `registry_require_root` and runs the folder's own code, again with no prompt. Today the same chain stops at `build.sh`, because registration needs the owner (`register_project.sh` has no allow-rule anywhere). It is not the same as `register_project.sh --set build=` from the workspace: that path never runs without the owner. Registration is what turns on every user-tier script for a folder, so a self-service registration with no prompt removes the owner from that gate. The skill's dry run and question cannot enforce anything, because an injected call never goes through the skill. A permission prompt can: without an allow-rule, each call prompts with the full command, `--set` values included. The plan already found that an unpromoted call prompts rather than fails. Promotion also contradicts ADR-0016 decision 6 ("an entry may be promoted only if it is inert outside ... every registered project root"), and this script acts only outside every root. ADR-0021 as agreed supersedes decision 5 only. The fix: drop plan steps 1 and 3 and the installer re-run note. `test_user_tier_guard.sh` and the manifest stay as they are, and the manifest's "never promoted" comment gains the new script with this reason. The new test asserts the script is absent from the manifest. The script header, `script_reference.md` and design.md say "not promoted: each call raises a permission prompt, which is the owner's yes".

### Notes for the implementer (no re-plan needed)

- The guard-marker question is moot once the script is not promoted. If promotion is ever revisited: as planned, the named marker is safe only if `marker_of` returns its own value and the case arm fails it for any entry but the one named file. The existing `# user-tier: inert` marker is already a self-declared exemption that is checked behaviourally for four named entries only, so the new marker would be no weaker than that.
- Refuse a folder that is already a registered root (equality) before delegating. `register_project.sh` treats a registered path as an adoption and writes the `--set` keys (lines 559-567, 719-721), so without the refusal the script would rewrite a registered project's build command. Test it with `--set build=x` and assert the settings file is unchanged.
- "Inside a registered root or the workspace" is `registry_require_root` succeeding, or `registry_derive_type_from_dir` returning 0. "Over" (a registered root or the workspace lies under `$PWD`, as in a session in `~`) has no helper: a short loop over `registry_entries` with `_registry_path_under`. Both are in the plan's step 2 and are not the "new registry logic" of stop condition (c).
- Resolve WS_ROOT from the script's own location (as `session_root.sh` lines 76-78 do: the main checkout of its own repository), not from `~/.claude/agent-workspace-root`, so a sandbox copy in the test is self-contained.
- Pass `--set` only for `build=` and `test=`, one argv element each (quoted). `register_project.sh` already validates values (`_project_file_value_error`: no shell metacharacters).
- `register_project.sh --dry-run` prints detection notes ("note: no build command detected ...") on stderr (line 763). The skill must capture `2>&1` to know when to ask for build/test commands.
- A dry run does not run the gate (`registration_verify.sh`), so a no-git folder's dry run looks clean and only the real run refuses and rolls back. The skill shows that refusal as printed and says non-git folders are not supported yet.
- With no allow-rule, the dry run and the real run each prompt. The skill shows the dry-run output (registry line, settings it would write, the build/test commands) and lets the real call's permission prompt be the yes, rather than asking twice in text.
- Confirmed by reading the code: (a) no-git is refused by `single_project` `adapter_validate` ("not a git repository (no .git at its root)", adapter.sh line 174), reached through `registration_verify.sh` (line 163), which `register_project.sh` runs at step 2 even with `--skip-run`, then rolls back. This stays a named gap. (b) Allow-rules come only from the manifest (`allow_rules_json`, user_tier_install.sh lines 296-301) and `--check` reports "allow-rule(s) missing" (line 1394). That re-run would have been needed only for a promoted entry, so it goes away with finding 1.

### Summary

The plan is small and well grounded except for one choice. Promoting the new script lets any session, in any folder, register that folder and so open every user-tier script there with no prompt, and it breaks ADR-0016 decision 6, which the owner did not agree to supersede. Leaving the script unpromoted fixes both, removes the guard-test change and the installer re-run, and keeps ADR-0021 exactly as agreed. With that change the plan is ready to implement.

### Recommended Actions

- [ ] Drop the promotion: no `user_tier_scripts.txt` entry and no `test_user_tier_guard.sh` change. Add the script to the manifest's "never promoted" comment, assert its absence in `test_register_session_root.sh`, and state "not promoted; each call prompts" in the script header, `script_reference.md` and design.md.
- [ ] Remove the "re-run `user_tier_install.sh` on each machine" consequence and the PR note.
- [ ] Refuse a folder that is already a registered root before delegating, and test that `--set` cannot change a registered project's settings through this script.

## Checkpoint
**Status**: complete
**When**: 2026-11-13 11:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the plan review's one must-fix removes work rather than adding it: the new script is NOT promoted to the user tier, so plan steps 1 and 3 and the installer re-run are dropped; the review says nothing else needs a re-plan and its seven notes are each a bounded instruction the implement pass can apply; the owner asked for this change in under an hour and a re-plan plus second review would cost about ten minutes for no new information; first host answer at this checkpoint)
**After**: plan
**Decision**: proceed

Read: the Plan Review at bcde893b and its report. The implement handoff carries the must-fix and the notes verbatim. The must-fix keeps the change inside what the owner agreed to: ADR-0021 supersedes ADR-0016 decision 5 only, and promotion would have broken decision 6 (promoted only if inert outside every registered root). Consequence the owner will see: registering from a project session asks for permission each time, and that prompt is the yes. The owner answered "yes to ADR-0021" on 2026-11-13, so plan step 7 is unblocked.

### Decisions made (owner may veto)
- The new register_session_root.sh is not promoted to the user tier: every call prompts, showing the full command — undoing it: a later change adds it to user_tier_scripts.txt with a guard-test exception and its own decision record for ADR-0016 decision 6.
- Proceed on a needs-work plan review without a re-plan, with the must-fix and notes in the implement handoff — undoing it: answer this checkpoint revise instead; nothing is implemented yet.

## Implementation
**Status**: complete
**When**: 2026-11-13 11:37 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-466 at `03f37dcd`

Implements the plan as amended by the Plan Review's must-fix (the script is NOT promoted; plan steps 1 and 3 and the installer re-run dropped) and its seven notes.

- `.agent/scripts/register_session_root.sh` (new): takes only `--dry-run` and `--set build=`/`test=` (each one quoted argument, at most once); the folder is `pwd -P`. WS_ROOT from its own location (as `session_root.sh` lines 76-78). Refuses, exit 1 and before handing over: already a registered root (note 1), inside a registered root or `worktrees=` dir, inside the workspace or its repository, over a registered root or the workspace (loop over the registry with `_registry_path_under`, note 2), not the top of its git repository, a linked worktree, a name already registered (pointing at `register_project.sh --name` from the workspace). Then `exec register_project.sh <folder> --skip-run [--dry-run] [--set ...]`, never `--install-user-tier`. Header says each call asks for permission and why, and names the no-git gap and the unlocked pre-check race.
- `.agent/scripts/tests/test_register_session_root.sh` (new, synthetic sandbox only): 53 checks, each refusal above, `--set build=x` on a registered folder leaves its settings file unchanged, dry run writes nothing, no build/test/installer run, no-build folder refused until `--set build=none --set test=none`, a value with a blank kept whole, no-git folder refused and rolled back, worktree copy registers in the main checkout, absent from the manifest.
- `.agent/user_tier_scripts.txt`: comment only; the never-promoted paragraph names the script and the reason. No manifest line; `test_user_tier_guard.sh` unchanged.
- `.agent/scripts/tests/test_script_tests_hook_scope.sh`: ROOT_READERS entry for the new suite (its drift check requires one).
- `.claude/skills/onboard-project/SKILL.md`: step 1 exit-1 branch (dry run `2>&1`, refusals as printed, ask for build/test when a note says none detected, the real call's permission prompt is the yes, re-read `session_root.sh` and carry on, no-git gap named); Overview, write list, settings-file paragraph, description. `test_skill_paths.sh` pins the new wording.
- `docs/decisions/0021-a-project-session-may-register-its-own-folder.md` (new, Accepted 2026-11-13): supersedes ADR-0016 decision 5 only; non-promotion recorded in Context. `0016`: one-line ADR-0008 pointer. Review guide: 0021 row, 0016 note. Number checked free on origin/main and both open pull requests' branches before writing.
- `docs/design.md`: Sessions and roots, Registry and adapters (Now and Target), decision register (row 0021, 0016 note, count 19 -> 21), C4, change-log row.
- `.agent/knowledge/script_reference.md` row; `register_project.sh` header comment only.

Suites run, each on its own: test_register_session_root 53/0, test_user_tier_guard 64/0, test_user_tier_install 276/0, test_skill_paths 138/0, test_register_project 197/0, test_script_tests_hook_scope 326/0 (touched: ROOT_READERS); check_design_anchors.sh clean. Commits used SKIP=validate-script-tests; the full pre-commit pass was skipped on the owner's direction (2026-11-13), for the host's one run before publishing.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-13 11:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-466 at `092368bb`
**Base**: origin/main
**Depth**: Deep (reason: security-relevant: the permission gate for registration, which turns on the user-tier scripts for a folder)
**Must-fix**: 1 | **Suggestions**: 2
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

Reviewers: static (shellcheck clean on the three changed scripts), governance, plan drift, Claude adversarial (fresh sub-agent), cross-model Gemini (agy) completed, Codex completed. Suites run one at a time: test_register_session_root 53/0, test_user_tier_guard 64/0, test_skill_paths 138/0, test_script_tests_hook_scope 326/0. Sandbox probes: symlinked cwd and trailing slash resolve to the physical path; a newline in --set is refused by register_project.sh; `--` is a usage error; a WS_ROOT environment variable is not read; a folder holding a symlink to the workspace is accepted (correct: every check is on physical paths); worktrees= must lie under its root or the workspace, so no "over a worktrees dir" gap.

Limits the implement pass documented, judged acceptable: (a) the race between the checks and register_project.sh's lock needs two concurrent calls on the same or nested folders, each its own permission prompt showing its --set values, so nothing lands that the owner did not see; (b) the registering session lacks the workspace layer, said by the skill, design.md and the ADR, fixed by a new session.

ADR-0021's Decision section stays within what the owner agreed: decision 1 is the exception (that folder's registry line and settings file, one guarded script, nothing else); decision 2 restates the status quo the issue named; ADR-0016 gets the one-line pointer only. design.md claims about the script match its code.

### Findings
- [x] (must-fix) The real registration's only yes is its permission prompt ("Do not also ask for a yes in text"), and a prompt is not guaranteed: picking "Yes, and don't ask again" on the harmless-looking dry-run prompt (same command prefix), auto mode, or a broader allow rule lets the registration run with no yes at all. Ask one yes in text after showing the dry run, keep the prompt as the second gate; update the write-list wording, ADR-0021's Consequences bullet, design.md's onboarding bullet and the pinned phrase in test_skill_paths.sh (Gemini and Codex both, confirmed by reading) — `.claude/skills/onboard-project/SKILL.md:159`
- [x] (suggestion) With no --set, the real call's prompt shows no build or test command; register_project.sh re-detects them from the folder's files at that run, so the prompt does not show what is written and the folder can change between the dry run and the real run. Have the skill pass the dry run's detected commands as explicit --set build=/test= so the prompt carries them (Claude adversarial) — `.claude/skills/onboard-project/SKILL.md:149`, `.agent/scripts/register_session_root.sh:52`
- [x] (suggestion) A folder whose name is not a valid registry name (e.g. one with a space) passes the pre-checks and register_project.sh answers `NEXT=choose a name with --name`, an option this script refuses; pre-check it like the registered-name case and point at register_project.sh --name from the workspace (sandbox probe) — `.agent/scripts/register_session_root.sh:160`

## Implementation
**Status**: complete
**When**: 2026-11-13 11:48 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-466 at `fb6630db`
**Addressed**: Local Review (Pre-Push) at `092368bb` (2026-11-13 11:43 -05:00)
**Commits**: c2449b32, 6ab8ce86, fb6630db

### Actions
- [x] (must-fix) The registration's only yes was its permission prompt, which is not guaranteed. onboard-project now shows the dry run and asks one yes in text before the real call; the real call's prompt, when it appears, is a second gate. Same wording in the skill's write list, ADR-0021 (Context and Consequences only; Decision untouched), design.md's onboarding bullet and its change-log row (line counts 149 for Sessions and roots, 989 for the file), register_session_root.sh's header, the principles guide row, and test_skill_paths.sh's pinned phrases, plus a check that "Do not also ask for a yes in text" is gone — `.claude/skills/onboard-project/SKILL.md:149` (c2449b32)
- [x] (suggestion) The skill now passes every build= and test= the dry run listed (or the user gave) as --set on the real call and names them in the text question, so the question and the prompt show what is written; the script header says why. New test: the dry run's commands, passed back as --set after the folder's build system changed (Makefile replaced by Cargo.toml), are what is written — `.claude/skills/onboard-project/SKILL.md:164`, `.agent/scripts/register_session_root.sh:16` (6ab8ce86)
- [x] (suggestion) register_session_root.sh refuses a folder name that is not a valid project name (register_project.sh's rule) before handing over, pointing at register_project.sh --name from a workspace session. Tests: sandbox folders 'sp ace' and 'tool.sh'. Refusal lists in the skill, design.md, script reference and principles guide updated — `.agent/scripts/register_session_root.sh:164` (fb6630db)

### ADR-0021 wording changed (Context and Consequences only)
- Context, before: "That prompt is the owner's yes: a session in a folder he does not trust cannot register the folder, and so make its own build command runnable, without him seeing the command." After: "That prompt is the owner's gate, unless he has allowed the command: a session in a folder he does not trust cannot register the folder, and so make its own build command runnable, without him seeing the command."
- Consequences, first bullet, before: "shows the registration's dry run and, on the permission prompt's yes, registers the folder and carries on." After: "shows the registration's dry run, asks one yes in text and, on that yes, registers the folder and carries on."
- Consequences, second bullet, before: "**Two permission prompts per registration from a project session**, the dry run's and the real call's. The skill shows the dry run and does not ask a third time in text." After: "**A yes in text, and the permission prompts as a second gate.** The dry run and the real call each ask for permission, but a prompt is not guaranteed: \"Yes, and don't ask again\" on the dry run's prompt allows the real call too, and auto mode or a broader allow rule removes both. So the skill asks one yes in text after showing the dry run, before the real call, and the real call's prompt, when it appears, is a second gate."

### Checks
- test_register_session_root.sh: 60 passed, 0 failed (was 53; +7 new)
- test_skill_paths.sh: 139 passed, 0 failed
- test_script_tests_hook_scope.sh: 326 passed, 0 failed
- check_design_anchors.sh: exit 0
- The full pre-commit pass and the full suite were skipped on the owner's direction (2026-11-13, "yes, one local run before a pr"): the host runs the one full pass before publishing. Every commit used SKIP=validate-script-tests; no --no-verify.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-13 11:55 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-466 at `2212c07b`
**Base**: origin/main
**Depth**: Deep (reason: whole-diff classification as round 1, security-relevant: the permission gate for registration; fix round re-review of 303696b1..HEAD, the merge of pull request 461 set aside)
**Must-fix**: 0 | **Suggestions**: 3
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round 1's must-fix is closed: the only path to the real `register_session_root.sh` call is under the `STATUS=dry-run` bullet, after the yes in text; a refusal (exit 1, the wrapper's or register_project.sh's), the skill's own --dry-run, and user-supplied commands (asked before the yes) all stop or come before it; a re-run in a registered folder never reaches the branch. The question must name the registry line (folder and name) and the build and test commands. ADR-0021's Decision section is byte-identical to 9f2d5fd4 (diff of the section between the two commits is empty; only Context and Consequences hunks). The --set pass-through quoting is safe: every valid value excludes quotes, $, backtick, backslash, ( ), & | ; < >, and detected commands are fixed strings. Both types require build and test, so a key with no detected command always gives a note: line and the skill asks for it. The name check is register_project.sh:581's rule copied exactly. The merge's conflict resolution keeps main's rows and this branch's row last; design.md is 1045 lines, Sessions and roots 149 and Registry and adapters 139 as the row says, check_design_anchors.sh exit 0.

Reviewers: static (shellcheck --severity=warning on register_session_root.sh and the two touched tests, clean), governance, plan drift, Claude adversarial (fresh sub-agent: 0 must-fix, 4 suggestions), cross-model Gemini (agy) completed EXIT=0 and Codex completed EXIT=0 (fix-round rule: whole-diff Deep tier, so cross-model ran). Suites run one at a time: test_register_session_root.sh 60 passed 0 failed; test_skill_paths.sh 139 passed 0 failed. Full suite and full pre-commit not run (owner's rule of 2026-11-13; the host runs the one pass).

Dismissed: Codex's lock race (round 1's judged limit (a), not in the fix diff; each call still needs its own yes in text); Codex's nested repository inside a workspace worktree outside the checkout (workspace worktrees live under the checkout here and are refused as inside it; not in the fix diff); Gemini's worktrees= containment (worktrees= must lie under its root or the workspace, both already refused, round 1 probe); Gemini's unset key re-detected (both types require build and test, a missing one gives a note: and the skill asks); Gemini's plan divergence on promotion (ADR-0021 records it).

### Findings
- [ ] (suggestion) Before the yes, re-run the dry run with the exact --set arguments the real call will pass: a user's command register_project.sh refuses (e.g. "make && make install") or a copied "(detected (Makefile))" annotation is only caught after the yes, as STATUS=refused and a rollback, and the shown output is then exactly the real call's (Claude adversarial, confirmed by reading) — `.claude/skills/onboard-project/SKILL.md:149`
- [ ] (suggestion) A settings file left under the folder's name (register_project.sh --remove --keep-settings) is kept: the dry run says "settings file kept as it is" with no build= or test= lines, so the question names no commands and the skill's "both show what is written" is untrue there; show that file's build and test in the question — `.claude/skills/onboard-project/SKILL.md:165`
- [ ] (suggestion) The name rule is a second copy of register_project.sh's; a change to one leaves the other refusing or passing names differently (worst case round 1's NEXT=--name message again); move it into a function in _project_registry.sh both call — `.agent/scripts/register_session_root.sh:171`

## Checkpoint
**Status**: complete
**When**: 2026-11-13 12:05 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 2 is approved with no must-fix; by the review-depth rule a third round runs only for a real defect; its three suggestions go to triage; the host's one full pre-commit pass on 2212c07b, every hook and every suite with no SKIP, exited 0 in 824 s; the commit after it changes progress.md only)
**After**: publish
**Decision**: publish

Read: the round 2 Local Review (Pre-Push) at 5b9887f5 and its report; the full pass output. Open suggestions for triage: SKILL.md:149 re-run the dry run with the exact --set arguments before asking the yes; SKILL.md:165 show a kept settings file's commands in the question; register_session_root.sh:171 share the name rule with register_project.sh through one function.

## Integrated Review
**Status**: complete
**When**: 2026-11-13 12:07 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #469 at `53c1635`
**Sources**: 2 (Local Review (Pre-Push) R2 @ `2212c07` (covers `53c1635` via bookkeeping), CI rollup)
**Cross-source confirmations**: 0
**CI**: pending

GitHub side: 0 reviews, 0 inline comments, 0 conversation comments (Copilot's automatic review is off for this repository, owner 2026-11-12). Round 1's three findings are closed (Implementation at `fb6630db`, confirmed by round 2). The round-2 review at `2212c07` covers the head: everything after it changes progress.md only. The host's full pre-commit pass on `2212c07b` (every hook and suite, no SKIP) exited 0. CI at `53c1635`: Validate Adapter Contract, Validate Documentation and ros-manifest tests pass in both runs; Lint (pre-commit) still running in both.

All three round-2 suggestions are confirmed by reading the code at the head. None can write something the owner did not agree to; two make the skill's yes less exact than it says it is.

Recommendation: fix findings 1 and 2 in this pull request, together. They are the same paragraph of the skill (SKILL.md 139-177), skill text only, one light re-review. Finding 2 contradicts the skill's own claim "the text question and the prompt both show what is written", which is the claim this change's permission design rests on. Finding 3 goes to a follow-up issue: the rule is already copied in four places, and doing it properly covers all of them. That is the owner's call.

Fix plan for 1 and 2, in `.claude/skills/onboard-project/SKILL.md`, `STATUS=dry-run` bullet:
- Pass the value after `build=` / `test=` only, without the dry run's parenthesised source note.
- When the dry run says `settings file kept as it is: <path>`, read that file and show its contents with the question, and pass its build= and test= as --set like detected commands. If a key is missing, ask for it.
- Once the --set list is complete, re-run `register_session_root.sh --dry-run` with exactly those arguments. Show that output and ask the yes on it. A refusal there stops before the yes.
- Update any pinned phrase in `test_skill_paths.sh`.

### Findings
- [x] (suggestion, Local Review (Pre-Push) R2 @ `2212c07`, covers via bookkeeping) Valid. The yes is asked before the exact --set arguments are checked. The dry-run line is `    build=make    (detected (Makefile))`. The skill says to pass the lines "as printed", which invites copying the note, and `_project_file_value_error` refuses `(` `)`. A user's command such as `make && make install` is refused the same way. Either one is caught only after the yes: `register_project.sh` validates before writing, ends `STATUS=refused` and writes nothing. Owner impact: a wasted yes, a confusing refusal and a re-run, never a wrong write. Likelihood: moderate for the copied note, because the wording invites it. Fix in this pull request (plan above) — `.claude/skills/onboard-project/SKILL.md:149`
- [x] (suggestion, Local Review (Pre-Push) R2 @ `2212c07`, covers via bookkeeping) Valid, and weighed as security-relevant. When a settings file already exists under the folder's name (`register_project.sh --remove --keep-settings` keeps it), `register_project.sh` sets SETTINGS_EXISTED=1 and skips detection. The dry run prints only `settings file kept as it is: <path>`, with no build=, no test= and no note: lines. The skill then names no commands in the question and passes no --set, and the registration activates the kept file's build, test and any other keys unseen. That makes "the text question and the prompt both show what is written" untrue there. Bound on the harm: an untrusted session cannot plant that file. Writing it needs a registered root (`project_setting.sh` calls registry_require_root and writes only its own project's file), or a write into the workspace checkout, which raises its own permission prompt. So the file is one the owner once wrote. It may belong to an earlier, unrelated folder with the same name. Nothing runs at registration (`--skip-run`). Likelihood: low, since it needs a prior remove with --keep-settings under the same folder name. Fix in this pull request (plan above) — `.claude/skills/onboard-project/SKILL.md:165`
- [ ] (suggestion, Local Review (Pre-Push) R2 @ `2212c07`, covers via bookkeeping) Valid, low impact. The name rule at `register_session_root.sh:171` is a copy of `register_project.sh:581`. The same base rule is also copied at `_project_registry.sh` 150, 192 and 491, without the `.sh` clause, so the duplication was there before this change. If the copies drift, `register_project.sh` stays the authority under its lock, so the worst case is a misleading refusal message (round 1's `NEXT=choose a name with --name`) or a needless refusal, never a wrong write. Likelihood: low, because the rule rarely changes. Recommend a follow-up issue that puts all five copies into one helper in `_project_registry.sh`; deferring is the owner's call — `.agent/scripts/register_session_root.sh:171`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-11-13 12:08 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (triage classified all three open findings valid; F1 and F2 are text in one paragraph of the skill and F2 makes a security-relevant claim in the skill untrue, so both are fixed in this pull request; F3, sharing the name rule across five copies, is wider than this pull request and is left open for the owner to defer at the merge checkpoint; first host address at this checkpoint)
**After**: findings
**Decision**: address

Read: the Integrated Review at 0c82bb99 and its report. The fix pass works F1 and F2 only and leaves F3's box open.
