---
issue: 331
---

# Issue #331 — research skill is not available in project-rooted sessions

## Issue Review
**Status**: complete
**When**: 2026-11-21 17:53 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #331

### Scope Assessment

**Well-scoped?** Mostly. The four listed changes (WS_ROOT idiom, session-root default scope, per-project-type digest location, skill-worktree path) fit one PR. The 2026-11-21 ice_cube comment adds three more (private-draft-then-scrub for public repos, no real-location web queries, entries without links), which are skill-text changes of the same file and fit the same PR, but the issue body should be amended or the PR description should list them so acceptance covers them. Point 4's premise is stale: `worktree_create.sh` now rejects `--skill research --type project` (line 415: "--skill X is for --type <skill_worktree_type>"), and `AGENTS.md` says `research` makes workspace worktrees only. So a project digest update cannot avoid an issue by that route unless the allowlist is changed (a change to `AGENTS.md`, Ask First).
**Right repo?** Yes — the skill, `AGENTS.md` and `worktree_create.sh` are workspace infrastructure.
**Serves**: Light touch on projects (and Easy to use) — `docs/design.md#sessions-and-roots`, with `docs/design.md#registry-and-adapters` for the per-type digest location.
**Design picture?** Changes `docs/design.md#documentation-layers` / `#registry-and-adapters` if the digest location is decided here (the design text says the per-project footprint is a proposal and records can live outside the project, rows at design.md:710-717). #335 is closed, so the earlier "blocked on #335" comment no longer holds, but the open question moved to #551. The digest location is the one decision that needs the owner.
**Dependencies**: #551 (where a project keeps goals, design, roadmap) for the digest location; #552 (brainstorm in project sessions) is a sibling; #370 Part 1/2 consume both. rolker/geozui4d#7 is no longer blocked by this (owner correction), only made more convenient.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Put each thing at the level it applies to | Action needed | The project digest location must be decided once and recorded, not hard-coded to `.agents/workspace-context/` for single repositories. Under the owner's optional-zero-footprint goal a committed digest in a public project (ice_cube) is a footprint; decide which of the design's location options (design.md:710-717) apply, or take the answer from #551's setting. |
| Keep one current design | Action needed | If the digest location or the research worktree rule changes, update the matching `docs/design.md` sections and Change log in the same PR (ADR-0017); the owner decision on location goes to the owner on its own. |
| Ask about what matters | Watch | Allowlist change for `--skill research --type project` and the `AGENTS.md` Skill Worktree Exception text are Ask First. |
| Verify before claiming | Watch | The body's claim that `worktree_create.sh` does not restrict `--skill` to workspace is out of date; the PR must test the actual behavior. |
| Safeguard earns its cost | Watch | The private-draft/scrub step should be a check against the project's own rules (`.agents/README.md`) rather than a new mandatory ceremony for every project. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0016 session roots and user tier | Yes | WS_ROOT idiom, registry-resolved default scope, `session_scope: both`, user-tier guard test coverage. |
| ADR-0011 project-type adapter contract | Yes | Digest location by project shape belongs behind the adapter or a per-project setting. |
| ADR-0002 worktree isolation | Yes | Research must use a worktree in a project session; no branch switching. |
| ADR-0017 design document is the current picture | Yes | See Design picture. |
| ADR-0003 workspace infrastructure is project-agnostic | Watch | The skill must not hard-code ros2 or ice_cube specifics. |
| ADR-0018 plugin-based skill delivery | Watch | `session_scope: both` is what makes the plugin ship the skill to project sessions. |

### Consequences

- `user_tier_install.sh --list-skills` and the user-tier guard test cover `research`; the plugin skill list follows.
- `docs/design.md` sections above, `AGENTS.md` Skill Worktree Exception if the allowlist changes, and the skill's description line ("project digest lives in the manifest repo").
- Skill docs/scripts that mention the research digest path (`sitrep`, `brainstorm`, `inspiration-tracker`) if the location moves.

### Recommendations

- Ship #331 and #552 together as one change set on one branch (two commits, or two PRs stacked) rather than apart: both are "prepare for a design discussion in a project session", both must resolve the same digest location, and #552 step 1 reads the digest #331 defines. Reviewing them apart would force #552 to guess the location. Keep them as separate issues with `Closes` for each; do not merge them into one issue. If the owner prefers smaller PRs, land #331 first, since #552 depends on it and not the reverse.
- Settle the digest location with #551, not here: make #331 read the project's digest path through the same "where is X for this project" lookup #551 introduces, defaulting to `.agents/workspace-context/research_digest.md` when unset. That default is what ice_cube already uses and matches today's fixed-search behavior. #551 is the owner of the question; #331 is a reader of it. If #551 will not land soon, ship #331 with the default, state it per project type, and list it as the first reader to follow #551.
- Resolve point 4 explicitly: either keep research workspace-only (so project digest updates need a project issue, and say so in the skill and `AGENTS.md`), or ask the owner to allow `--skill research --type project` (an allowlist and `AGENTS.md` change). The ice_cube comment shows an issue per digest update is a real cost, so put the choice to the owner.
- Add the ice_cube lessons to the acceptance list: a check of the project's `.agents/README.md` rules (e.g. public repo, no site data) before committing a project digest, with a private-draft step when the rules require it; a rule that web queries carry no real locations without owner approval; and a "sources pending" mark (or a required link-collection step) so no entry is left without a link.
- Update the issue body (or add an Acceptance addendum comment) to replace the "blocks geozui4d#7" line and the stale point 4, so the plan starts from the current facts.
- Add acceptance test coverage for a project-rooted run: default scope follows the session root and `--scope workspace` stays available.

### Actions
- [ ] The project digest location must be decided once and recorded, not hard-coded to `.agents/workspace-context/` for single repositories. Under the owner's optional-zero-footprint goal a committed digest in a public project (ice_cube) is a footprint; decide which of the design's location options (design.md:710-717) apply, or take the answer from #551's setting.
- [ ] If the digest location or the research worktree rule changes, update the matching `docs/design.md` sections and Change log in the same PR (ADR-0017); the owner decision on location goes to the owner on its own.
- [ ] Ship #331 and #552 together as one change set on one branch (two commits, or two PRs stacked) rather than apart; keep them as separate issues with `Closes` for each. If smaller PRs are preferred, land #331 first.
- [ ] Settle the digest location with #551, not here: read the project's digest path through the same lookup #551 introduces, defaulting to `.agents/workspace-context/research_digest.md` when unset; list #331 as a reader to follow #551.
- [ ] Resolve point 4 explicitly: keep research workspace-only (say so in the skill and `AGENTS.md`), or ask the owner to allow `--skill research --type project` (allowlist and `AGENTS.md` change).
- [ ] Add the ice_cube lessons to the acceptance list: check the project's `.agents/README.md` rules before committing a project digest (private draft when required); no real-location web queries without owner approval; a "sources pending" mark or required link collection.
- [ ] Update the issue body (or add an Acceptance addendum comment) to replace the "blocks geozui4d#7" line and the stale point 4.
- [ ] Add acceptance test coverage for a project-rooted run: default scope follows the session root and `--scope workspace` stays available.

## Checkpoint
**Status**: complete
**When**: 2026-11-21 18:00 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Owner answered "Proceed, keep defaults": plan #331 now with the project digest at .agents/workspace-context/research_digest.md (what ice_cube and design-discussion already use), read through #551's setting once that exists; research keeps its current worktree rule (a project digest update needs a project issue; no --skill research --type project, no AGENTS.md change). #331 ships apart from #552 (owner kept the host's ship-apart decision on #552). Easy to revisit after the workspace design review.

## Plan Authored
**Status**: complete
**When**: 2026-11-21 18:01 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-331/plan.md` at `05f27884`

Make research a session_scope: both skill (WS_ROOT idiom, session_root.sh default scope, project digest at the default path pending #551, worktree rule unchanged) and fold in the project lessons (project-rules check, no real-location queries, sources-pending mark), with test_skill_paths and plugin-list test coverage. Includes a text draft of the issue-body addendum.

## Plan Review
**Status**: complete
**When**: 2026-11-21 18:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #331 — research skill is not available in project-rooted sessions (no session_scope; workspace-relative paths; workspace default scope)
**Plan**: `.agent/work-plans/issue-331/plan.md` at `05f27884`
**Branch**: `feature/issue-331`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One skill file plus test edits; one PR. |
| Issue alignment | Good | Covers all review-issue actions under the owner's Checkpoint (default path, read through #551 later; worktree rule kept; ice_cube lessons; project-rooted default scope; issue-body addendum drafted). Serves: "Light touch on projects and Easy to use (README `## Workspace goals`); `docs/design.md#sessions-and-roots`, with `docs/design.md#registry-and-adapters` untouched because the location setting is #551's." Checked: both anchors exist; no rule broken. |
| File targeting | Needs work | `.claude-plugin/plugin.json` is missing (finding 1). The `test_user_tier_guard.sh` row targets a test that does not assert the skill set (finding 2). |
| Consequences | Needs work | `session_scope` -> plugin manifest regeneration not planned (finding 1); merge interaction with #552 (finding 4). |
| Principle alignment | Good | Safeguard earns its cost (rules check, not ceremony); Keep one current design addressed with a fallback; prior art named. |
| ADR compliance | Good | ADR-0016/0018: `$WS_ROOT`, `session_root.sh`, `both`. ADR-0018 decision 6 (root rule): the hand-back decision complies (see finding 3). ADR-0003: no project named. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences]** (medium) Adding `session_scope: both` changes the plugin's skill set, but the plan never regenerates `.claude-plugin/plugin.json`. `test_plugin_manifest.sh` re-derives the list from frontmatter and fails until `make generate-user-tier-skills` is run and the manifest committed; without it the plugin does not ship `research` to project sessions at all, which is the point of the issue. Add the regeneration step and list `.claude-plugin/plugin.json` in Files to Change (as #552's plan does).
2. **[File targeting]** (low) Step 8's "add a case to `test_user_tier_guard.sh` or the plugin-list test that `research` is listed" is unneeded: `test_user_tier_guard.sh` does not assert the skill set, `test_plugin_manifest.sh` already checks the manifest equals the scoped set, and `test_user_tier_install.sh` covers `--list-skills` with fixtures. Likewise `test_session_root.sh` (line 165) already asserts `type=project` for a registered root, so no new `session_root.sh` case. Drop that row; the guard that matters is `research` in `test_skill_paths.sh`'s `both` loop plus finding 1.
3. **[ADR compliance]** (low) The planner's decision (a workspace-digest write from a project session stops and hands back; reading stays allowed) matches ADR-0018 decision 6 and `docs/design.md#sessions-and-roots` ("Work that belongs to another root becomes an issue there (or an inbox line) ... Reading across roots is allowed"); creating a workspace worktree from a project session would break it. Make the step concrete: name `$WS_ROOT/.agent/scripts/capture.sh` for the inbox line (it tags the line with the project the cwd is in, so the text must say it is for the workspace digest), say that a workspace issue is opened only after a yes, and say where the drafted entry text goes (the issue body, or shown in the conversation) so the survey is not lost to a one-line inbox note.
4. **[Consequences]** (low) Merge with #552: both branches add a name to the same `for name in start-task ... orchestrator; do` lines in `test_skill_paths.sh`, which will be a textual conflict if both edit the same line; resolution is keeping both names. Both regenerate `plugin.json`; the inserts (`brainstorm` after `audit-project`, `research` after `plan-task`) are non-adjacent and should merge cleanly. Nothing beyond an ordinary merge, but whichever lands second re-runs `make generate-user-tier-skills` and `test_plugin_manifest.sh`/`test_skill_paths.sh` after rebasing to confirm the manifest has both.

### Summary

Sound plan that follows the owner's decisions and the root rule; the planner's hand-back decision is correct. One real gap: the plugin manifest must be regenerated or the skill still does not reach project sessions and `test_plugin_manifest.sh` fails. Ready once finding 1 is folded in.

### Recommended Actions

- [ ] Add `make generate-user-tier-skills` and `.claude-plugin/plugin.json` to the plan (Approach and Files to Change); run `test_plugin_manifest.sh`.
- [ ] Drop the `test_user_tier_guard.sh` / new `session_root.sh` case rows; rely on existing `test_plugin_manifest.sh`, `test_session_root.sh` and the `test_skill_paths.sh` `both` list.
- [ ] Make the workspace-write hand-back concrete: `$WS_ROOT/.agent/scripts/capture.sh` line saying it is for the workspace digest, or a workspace issue after a yes carrying the drafted entry.
- [ ] When the second of #331/#552 lands, resolve the `test_skill_paths.sh` list conflict by keeping both names and re-run the manifest generator and both tests.

## Checkpoint
**Status**: complete
**When**: 2026-11-21 18:03 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (orchestrator; four mechanism fixes, none changes scope; same "proceed, fixes in the implementer's handoff" pattern the owner chose at #370's plan checkpoints)
**After**: plan
**Decision**: proceed

The implementer applies the Plan Review's findings beyond plan.md: (1) run make generate-user-tier-skills and list .claude-plugin/plugin.json under the files changed, so the plugin ships research; (2) drop the step-8 tests the review showed are redundant (test_user_tier_guard.sh, a new plugin-list or session_root test); the guards are research in test_skill_paths.sh's both list plus the regenerated manifest; (3) make the workspace-digest hand-back concrete: $WS_ROOT/.agent/scripts/capture.sh with text saying it is for the workspace digest, a workspace issue only after a yes, and the drafted entry text kept in the issue body or the conversation so the result is not lost; (4) #552 also edits test_skill_paths.sh's both list: an ordinary merge, keep both names, and whichever lands second re-runs generate-user-tier-skills, test_plugin_manifest.sh and test_skill_paths.sh. The planner's own decision (no workspace-digest write from a project session) stands: the review confirmed it against ADR-0018 decision 6.

## Implementation
**Status**: complete
**When**: 2026-11-21 18:11 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-331 at `8430c19c`

- `.claude/skills/research/SKILL.md` (229c07fc): `session_scope: both`; "Workspace root" idiom section and every script as `$WS_ROOT/.agent/scripts/...`; new "Scope" step from `session_root.sh` (no `--scope` = session root's digest; `--scope workspace` added to Usage); a workspace-digest write from a project session shows the drafted entry in the conversation, records `"$WS_ROOT/.agent/scripts/capture.sh" "research for the workspace digest: ..."`, and opens a workspace issue carrying the entry only after a yes; project digest location stated once (default `.agents/workspace-context/research_digest.md`, read through a per-project setting once one exists); worktree rule explicit (`--skill research` workspace only, project digest needs a project issue); project-rules check (`.agents/README.md`) before committing a project digest; no real locations in web queries (passed to sub-agents); `**Sources**: pending` mark taken first by `--refresh`; description no longer says "manifest repo". No project named.
- `.claude-plugin/plugin.json` (229c07fc): regenerated with `make generate-user-tier-skills`; now lists `research`.
- `.agent/scripts/tests/test_skill_paths.sh` (8430c19c): `research` in the `both` list; text guards for the scope step, workspace-only `--skill research`, capture.sh hand-back, `.agents/README.md` check, no-real-location rule, sources-pending mark, no "manifest repo". The redundant step-8 tests (user-tier guard, plugin-list, session_root cases) were dropped per the Checkpoint.
- `docs/design.md`: no change; no sentence there states the digest location or the skill's scope.
- #552 overlap: ordinary merge; whichever lands second keeps both names in the `both` list and re-runs `make generate-user-tier-skills`, `test_plugin_manifest.sh`, `test_skill_paths.sh`.

Suites (each run on its own): `test_skill_paths.sh`: 175 passed, 0 failed; `test_plugin_manifest.sh`: 12 passed, 0 failed; `test_project_integration_audit.sh`: 279 passed, 0 failed; `test_project_file.sh`: 694 passed, 0 failed; `test_user_tier_install.sh`: 276 passed, 0 failed. The full pre-commit pass and full suite run are left to the host.

Issue-body addendum (text draft for the host; not posted):
> Replace "Blocks: rolker/geozui4d#7" with: "No longer blocks rolker/geozui4d#7 (owner correction); makes it convenient."
> Replace point 4 with: "Decided 2026-11-21: `research` keeps its worktree rule. `worktree_create.sh` rejects `--skill research --type project`; a project digest update needs a project issue. No allowlist or `AGENTS.md` change."
> Add to Acceptance: "- [ ] Before committing a project digest, the skill reads the project's `.agents/README.md` for commit rules. - [ ] Web queries carry no real locations unless the owner approves. - [ ] Entries without links are marked `**Sources**: pending` and `--refresh` takes them first. - [ ] A project-rooted run defaults to the project digest, with `--scope workspace` available (a workspace-digest write hands back)."

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-21 18:25 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-331 at `b98619c7`
**Base**: main
**Depth**: Deep (reason: 475 changed lines, 200+; skill definition is an override trigger)
**Must-fix**: 5 | **Suggestions**: 3
**Round**: 1 | **Ship**: continue — round 1: 5 must-fix; first round always re-reviews after fixes

### Findings
- [x] (must-fix) Workspace digest location is `$WS_ROOT/.agent/knowledge/research_digest.md`; $WS_ROOT is the main checkout, so a write edits the main tree, not the research worktree. Write it worktree-relative ($WS_ROOT only for reading) — `.claude/skills/research/SKILL.md:89`
- [x] (must-fix) Step 7 still says `git push -u origin HEAD && gh pr create --fill`: no AI signature, no `Closes #<N>` for the project issue now required; use `"$WS_ROOT/.agent/scripts/gh_create_pr.sh"` (Ingest/Refresh step 6 inherit it) — `.claude/skills/research/SKILL.md:194`
- [x] (must-fix) Ingest step 1 sets up the scope's worktree before step 4 "determine scope from content"; and Ingest/Refresh do not carry the project-session hand-back or the `.agents/README.md` rules check. Decide scope first, then apply both — `.claude/skills/research/SKILL.md:202-223`
- [x] (must-fix) `capture.sh` snippet double-quotes web-derived `<topic> — <one-line summary>`: a `$`, backtick or `$(...)` in it expands in the shell. Single-quote it (or say to) — `.claude/skills/research/SKILL.md:78`
- [ ] (must-fix) "Offer a workspace issue ... open it only after the user's yes" names no command; from a project cwd a bare `gh issue create` lands in the project repo. Name `"$WS_ROOT/.agent/scripts/gh_create_issue.sh" -R <workspace repo> --body-file <file>` — `.claude/skills/research/SKILL.md:80-81`
- [ ] (suggestion) An existing but empty `~/.claude/agent-workspace-root` leaves $WS_ROOT empty; add `; WS_ROOT="${WS_ROOT:-.}"` as sitrep does — `.claude/skills/research/SKILL.md:44`
- [ ] (suggestion) "In the project's own repo" is undefined for a multi-repo project whose root is not a git repo (`worktree_create.sh` refuses there); say what happens — `.claude/skills/research/SKILL.md:101-105`
- [ ] (suggestion) Read `.agents/README.md` before editing the project digest, not only before committing (AGENTS.md "before modifying"), and keep project-private data out of the workspace hand-back text — `.claude/skills/research/SKILL.md:174`
