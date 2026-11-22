---
issue: 552
---

# Issue #552 — brainstorm in project sessions, with its results saved for the design discussion

## Issue Review
**Status**: complete
**When**: 2026-11-21 17:53 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #552

### Scope Assessment

**Well-scoped?** Yes — one skill edit (frontmatter, `WS_ROOT` paths, a save step) plus regenerating the plugin list. The "To decide here" items are decided below, so the plan can start without another round.
**Right repo?** Yes — `brainstorm` is a workspace skill; the saved comment goes to whichever repo owns the anchor issue.
**Serves**: Flexibility (a skill works from any session root) — `docs/design.md#sessions-and-roots`
**Design picture?** No change to how the parts fit. It adds one more skill to the set the plugin ships (ADR-0018 session_scope), no new mechanism.
**Dependencies**: #370 Part 1 (unmerged, branch `feature/issue-370`): its Step 1 already reads "any brainstorm results recorded on the anchor issue", so #552 item 3 is already covered there. #552 only needs #370 merged for the one-line pointer edit in design-discussion ("neither is available yet (#331, #552)"). #331 (open, `research`) and #335/#551 (digest location) are soft: `brainstorm` can read a digest "if it exists".

**The contract #552 must meet** (read in `issue-workspace-370`, `design-discussion` Steps 0 and 1): Step 1 reads "any brainstorm results recorded on the anchor issue" and the level's digest at `.agents/workspace-context/research_digest.md` (project) or `$WS_ROOT/.agent/knowledge/research_digest.md`. It does not say how a brainstorm comment is recognised. The comment must therefore be a signed issue comment (never a progress.md entry, which derails `/run-issue` routing per #544) that opens with the existing `## Brainstorm: <topic>` heading, so a reader finds it by heading; #552 should state that heading as the contract.

**Ship with #331 or apart?** Apart, in either order. Neither needs the other to work: `brainstorm` tolerates a missing digest, and `research` carries its own open questions (worktree type, digest location, issue cost, public-repo scrubbing, web query privacy). Bundling would hold the small skill behind #331's unsettled design. One shared point: both must read the digest from the same project path, so the plan should use the path `design-discussion` already names and note that #335/#551 may move it.

**Needs #370 merged first?** To implement and merge: no. To finish the "neither is available yet" pointer in design-discussion: yes, so make that a follow-up edit once #370 is on main, or take it as part of #370's own change.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Only what's needed | OK | Proposed shape is small; item 3 is already in #370 and must not be redone here. |
| Put each thing at the level it applies to | Watch | A brainstorm result belongs to the issue it informs, in the repo that owns the anchor issue (use `-R` for a project). Saving "prior art" into the project digest overlaps `research`'s job; keep digest writing in `research` (#331). |
| Ask about what matters, and show how much | Action needed | The save is a tracked write: `brainstorm` today says "Don't create issues" and "output stays in the conversation". The skill must say: ask for the anchor issue; if none, offer to open one only on a yes (as `design-discussion` does); if the project uses no issues, conversation-only and say so. |
| Leave in a project only what it chose to carry | Watch | In a project session, resolve `WS_ROOT` and read the root's own docs; a public project with a "no site data" rule (the ice_cube data point on #331) needs the saved comment checked against the project's `.agents/README.md` before posting. |
| A change includes its consequences | Action needed | `session_scope: both` changes the plugin's skill list: run `make generate-user-tier-skills`, and update the skill count named in ADR-0018 if it is stated as a number. |
| Verify before claiming | OK | Comment content cites the digest entries it used. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0016 (session roots, user tier) | Yes | `WS_ROOT` idiom with the `|| echo .` fallback, as in `review-issue`. |
| ADR-0018 (plugin skill delivery) | Yes | `session_scope: both` frontmatter; regenerate the plugin list; the ADR names a count of shipped skills. |
| ADR-0013 (progress.md entry types) | Yes, by exclusion | Brainstorm results are not a progress entry type; they go in issue comments only. |
| ADR-0022 (a part owns its inside) | Watch | A brainstorm about a part reads the part's own design as well as the root's. |
| ADR-0010 (git-bug optional) | Watch | Posting uses `gh`; say what happens when `gh` is unavailable (conversation-only). |

### Consequences

- `make generate-user-tier-skills` and commit the plugin skill list; check the ADR-0018 count.
- `design-discussion` "Before this" paragraph (lines 32-34 on the #370 branch) says brainstorm is unavailable in a project session; update after both land.
- `brainstorm`'s "Lifecycle position" text and the "Don't create issues" guideline need rewording for the save step.
- Check `design.md` for a skills list that names `brainstorm`'s scope.

### Recommendations

- Decide in the issue: ship apart from #331, in either order; do not wait for #331.
- Decide the no-issue-yet case: offer to open an anchor issue on a yes (same as `design-discussion`); do not write to the digest from `brainstorm`.
- Define the save contract in the skill: a signed comment on the anchor issue, opening with `## Brainstorm: <topic>`, never a progress.md entry; and state it so #370's Step 1 can find it by that heading.
- Read the project digest at `.agents/workspace-context/research_digest.md` and the root's `docs/design.md`, roadmap and principles via `WS_ROOT`; treat each as optional and say which were read.
- Add a check before posting in a public project: compare against the project's `.agents/README.md` rules (no site data).
- Keep the `design-discussion` pointer edit as a follow-up that lands after #370 merges.

### Actions
- [ ] The save is a tracked write: `brainstorm` today says "Don't create issues" and "output stays in the conversation". The skill must say: ask for the anchor issue; if none, offer to open one only on a yes (as `design-discussion` does); if the project uses no issues, conversation-only and say so.
- [ ] `session_scope: both` changes the plugin's skill list: run `make generate-user-tier-skills`, and update the skill count named in ADR-0018 if it is stated as a number.
- [ ] Decide in the issue: ship apart from #331, in either order; do not wait for #331.
- [ ] Decide the no-issue-yet case: offer to open an anchor issue on a yes (same as `design-discussion`); do not write to the digest from `brainstorm`.
- [ ] Define the save contract in the skill: a signed comment on the anchor issue, opening with `## Brainstorm: <topic>`, never a progress.md entry; and state it so #370's Step 1 can find it by that heading.
- [ ] Read the project digest at `.agents/workspace-context/research_digest.md` and the root's `docs/design.md`, roadmap and principles via `WS_ROOT`; treat each as optional and say which were read.
- [ ] Add a check before posting in a public project: compare against the project's `.agents/README.md` rules (no site data).
- [ ] Keep the `design-discussion` pointer edit as a follow-up that lands after #370 merges.

## Checkpoint
**Status**: complete
**When**: 2026-11-21 17:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (orchestrator; every action is mechanism: save contract, plugin list, read paths, ship order; none changes the goal or scope)
**After**: issue-actions
**Decision**: proceed

The plan takes on the Issue Review's eight actions. Host decisions, listed for the owner's veto: ship #552 apart from #331 (in either order, not waiting for #331); in the no-issue-yet case, offer to open an anchor issue on a yes, never write to the digest from brainstorm; read the project digest at .agents/workspace-context/research_digest.md (the path design-discussion already reads) until #551 settles locations; the design-discussion pointer edit is a follow-up after #370 merges.

## Plan Authored
**Status**: complete
**When**: 2026-11-21 17:54 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-552/plan.md` at `003378d3`

Make brainstorm session_scope both (WS_ROOT idiom, root-relative reads) and add an on-yes save step posting a signed `## Brainstorm: <topic>` comment to the anchor issue; regenerate the plugin list. design-discussion pointer edit is a follow-up after #370 merges.

## Plan Review
**Status**: complete
**When**: 2026-11-21 18:01 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #552 — brainstorm in project sessions, with its results saved for the design discussion
**Plan**: `.agent/work-plans/issue-552/plan.md` at `003378d3`
**Branch**: `feature/issue-552`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One skill, the generated plugin list, one test list; single PR. |
| Issue alignment | Good | All eight Issue Review actions covered; host Checkpoint decisions kept (apart from #331, anchor issue on a yes, no digest writes, pointer edit after #370). Serves: "Flexibility (a skill works from any session root): `docs/design.md#sessions-and-roots`" — anchor exists. Contract with `design-discussion` Step 1 / Step 7 (branch `feature/issue-370`) is met: signed comment on the anchor issue opening `## Brainstorm: <topic>`, `--body-file`, identity in the same chain, never progress.md, digest at `.agents/workspace-context/research_digest.md`. |
| File targeting | Needs work | `.agent/scripts/tests/test_skill_paths.sh` is missing from Files to Change (finding 1). |
| Consequences | Needs work | Same gap; plugin list and ADR-0018 snapshot handled correctly (`plugin.json` has 14 entries today; ADR line 85 reads "(13 skills when this ADR was written)"). |
| Principle alignment | Good | Ask-on-yes for every tracked write, public-project check, prior art named, design picture unchanged and said so. |
| ADR compliance | Good | ADR-0016 idiom with fallback, ADR-0018 scope + regen, ADR-0013 by exclusion. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences]** (medium) `.agent/scripts/tests/test_skill_paths.sh` keeps a deliberate list of the `session_scope: both` skills (the `for name in start-task plan-task ... orchestrator` loop, "a typo in the field name would silently drop a skill from the user tier"). Plan step 7 only runs the test; it passes without `brainstorm` in the list, so the new scope is unguarded. Add `brainstorm` to that loop and list the test file under Files to Change.
2. **[File targeting]** (low) Plan step 3 writes the identity command as bare `set_git_identity_env.sh`; in a project session it must be `source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" --agent <framework> "<model id>"`, as `design-discussion` Step 7 does (a bare `.agent/scripts/` path would also fail `test_skill_paths.sh`'s BAD_RE).
3. **[Issue alignment]** (low) Step 2 says "the roadmap" without a path. Name it as `design-discussion` Step 0 does: the root's `docs/roadmap.md`, else `ROADMAP.md` (what `sitrep_root.sh` reports as `roadmap=`), under `$WS_ROOT` for the workspace and in the project root for a project.

### Summary

The plan meets the `design-discussion` contract and the owner's kept decisions. One real gap: the scoped-skill guard in `test_skill_paths.sh` must name `brainstorm`, or the change ships with no check that fails if the scope is dropped. Two small wording fixes. Ready once finding 1 is folded in.

### Recommended Actions

- [ ] Add `brainstorm` to the `session_scope: both` list in `.agent/scripts/tests/test_skill_paths.sh` and list that file in Files to Change.
- [ ] Write the identity command as `source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" ...` in the save step.
- [ ] Name the roadmap path (`docs/roadmap.md`, else `ROADMAP.md`) in the Step 1 reads.

## Checkpoint
**Status**: complete
**When**: 2026-11-21 18:01 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (orchestrator; three small mechanism fixes, none changes scope; the owner chose the same "proceed, fixes in the implementer's handoff" pattern at #370's plan checkpoints)
**After**: plan
**Decision**: proceed

The implementer applies the Plan Review's three findings beyond plan.md: (1) add brainstorm to test_skill_paths.sh's session_scope: both list and list that test file under the files changed; (2) the identity line is source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" ..., as design-discussion Step 7 does; (3) Step 2 names the roadmap path as design-discussion Step 0 does: docs/roadmap.md, else ROADMAP.md (sitrep_root.sh roadmap=).

## Implementation
**Status**: complete
**When**: 2026-11-21 18:04 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-552 at `9194800f`

- `.claude/skills/brainstorm/SKILL.md` (150517d2): `session_scope: both`; `## Workspace root` section with the `WS_ROOT` idiom and `|| echo .` fallback; Step 1 reads workspace sources via `$WS_ROOT/...` and project sources from the project root (digest at `.agents/workspace-context/research_digest.md`, `.agents/README.md`, principles, design, ADRs), roadmap named as `docs/roadmap.md`, else `ROADMAP.md` (sitrep_root.sh `roadmap=`), a part's own `design.md` (ADR-0022); output gains a `### Sources` read/absent section; the stale `.agent/project_knowledge/` paths are dropped (no such path exists). New Step 4: on a yes only, a signed comment on the anchor issue opening `## Brainstorm: <topic>` (the contract for design-discussion Step 1), identity via `source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" ...` in the same chain, `--body-file` from the scratchpad then removed, `-R` for another repo; offer an anchor issue on a yes; conversation-only when no issues or no `gh`; public-project check against `.agents/README.md`; never a progress.md entry, never a digest write. Overview, lifecycle text and the "Don't create issues" guideline reworded.
- `.agent/scripts/tests/test_skill_paths.sh` (150517d2): `brainstorm` added to the `session_scope: both` list.
- `.claude-plugin/plugin.json` (9194800f): regenerated, 14 to 15 skills.
- Unchanged after checking: ADR-0018's "(13 skills when this ADR was written)" is a dated snapshot; `skill_workflows.md`, `AGENT_ONBOARDING.md` and `docs/design.md` state no scope for brainstorm.
- Not done here (follow-up after #370 merges): design-discussion's "neither is available yet (#331, #552)" pointer.

Suites: `test_skill_paths.sh` — "test_skill_paths: 168 passed, 0 failed"; `test_plugin_manifest.sh` — "test_plugin_manifest: 12 passed, 0 failed"; `test_user_tier_install.sh` — "test_user_tier_install: 276 passed, 0 failed". The full pre-commit pass (`make lint`) was left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-21 18:08 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-552 at `71a5481b`
**Base**: main
**Depth**: Standard (reason: override-trigger file `.claude/skills/*/SKILL.md`)
**Must-fix**: 4 | **Suggestions**: 5
**Round**: 1 | **Ship**: continue — round 1: 4 must-fix; first round always re-reviews after fixes

Cross-model: gemini complete (EXIT=0), codex complete (EXIT=0). Claude adversarial complete. Tests: test_skill_paths 168/0, test_plugin_manifest 12/0, test_user_tier_install 276/0; plugin.json valid JSON; shellcheck not installed (static analysis of the one-line .sh change skipped).

### Findings
- [x] (must-fix) Step 4 body write invites an unquoted heredoc ("signature expanded from $AGENT_NAME / $AGENT_MODEL"), which runs every markdown backtick span and `$`/`$(...)` in the brainstorm text; write the body verbatim (quoted heredoc or Write tool) and append the signature with `printf` and `"$AGENT_NAME" "$AGENT_MODEL"` (adversarial + gemini) — `.claude/skills/brainstorm/SKILL.md:158`
- [x] (must-fix) Trailing `; rm -f <file>` makes the chain exit 0 when `source`, the body write or `gh issue comment` fails, so a failed post can be reported as posted; keep the status (`rc=$?; rm -f ...; (exit $rc)` or a trap) (codex + gemini + adversarial) — `.claude/skills/brainstorm/SKILL.md:159`
- [x] (must-fix) `sitrep_root.sh` reports the session root's roadmap (its header: "a session in a registered project root gets that project's"), so the parenthetical on the workspace-roadmap bullet is false in a project session; move it to the project roadmap bullet (line 79) or drop it — `.claude/skills/brainstorm/SKILL.md:67`
- [x] (must-fix) Opening an anchor issue: `gh issue create` has no `-R <owner/repo>` (a workspace session on a project topic opens it in agent_workspace), the issue body gets no public-project check or preview, and it is unstated whether the brainstorm goes in the issue body or in a separate `## Brainstorm: <topic>` comment (the contract design-discussion Step 1 reads); say: `-R` for the owning repo, show and check the body first, then post the brainstorm as its own comment (adversarial + gemini) — `.claude/skills/brainstorm/SKILL.md:142`
- [x] (suggestion) "A path without `$WS_ROOT` is the session root's own file" contradicts reading a project's files from a workspace session "from that project's registered folder", and no lookup for that folder is named; resolve the relative paths against the registered folder and name how it is found (adversarial + gemini) — `.claude/skills/brainstorm/SKILL.md:49`
- [x] (suggestion) "Uses no issues" has no test, and is checked after asking for an anchor issue; check first, via `"$WS_ROOT/.agent/scripts/project_integration_audit.sh" --facts` (`issues=yes|no|unknown`, as onboard-project does) and `gh auth status` (adversarial + gemini) — `.claude/skills/brainstorm/SKILL.md:145`
- [x] (suggestion) A part's `design.md` has no location rule; reuse design-discussion Step 0's (the `design.md` beside the sub-roadmap file the parent's `| Sub-roadmap | Root |` row names) — `.claude/skills/brainstorm/SKILL.md:81`
- [x] (suggestion) Step 4 requires citing the digest entries used, but the Step 3 template only lists source files; add the citation to the template (gemini) — `.claude/skills/brainstorm/SKILL.md:108`
- [x] (suggestion) `.agent/workflows/README.md` still lists brainstorm among the skills that append a progress.md section and shows a `## Brainstorm` entry, contradicting the new "Never a progress.md entry" rule and ADR-0013's entry types — `.agent/workflows/README.md:58`

## Implementation
**Status**: complete
**When**: 2026-11-21 18:12 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-552 at `4f22c930`
**Addressed**: Local Review (Pre-Push) at `71a5481b` (2026-11-21 18:08 -05:00)
**Commits**: adaac04f, b1cbfa09, 60fd653b, 112c45d3, 08700eb8, 43a94862, 4f22c930

### Actions
- [x] (must-fix) Comment body written verbatim with a quoted heredoc; signature appended with `printf` and "$AGENT_NAME" "$AGENT_MODEL" — `.claude/skills/brainstorm/SKILL.md` Step 4 item 4 (08700eb8)
- [x] (must-fix) Exit status kept: `rc=$?; rm -f "$body"; (exit $rc)`, URL reported only on exit 0 (checked with a stub `gh`: exit 0 and 3 passed through) — Step 4 item 4 (08700eb8)
- [x] (must-fix) `sitrep_root.sh` note moved to the project roadmap bullet, with `--dir <project root>` — Step 1 (adaac04f)
- [x] (must-fix) The brainstorm is its own signed `## Brainstorm: <topic>` comment, never an issue body; a new anchor issue's body gets the public-project check and a preview before the yes; `-R <owner/repo>` (from `gh repo view` in the topic's root) whenever that root is not the session's own — Step 4 (43a94862)
- [x] (suggestion) Relative paths resolve against the project root: in a workspace session, the `<path>` of the project's line in `$WS_ROOT/.agent/projects.local` — Workspace root section (b1cbfa09)
- [x] (suggestion) `gh auth status` and the `issues` fact of `project_integration_audit.sh --facts --format text --dir <project root>` checked first, before asking for an issue — Step 4 item 1 (43a94862)
- [x] (suggestion) A part's `design.md` is the one beside its sub-roadmap file (design-discussion Step 0's rule) — Step 1 (60fd653b)
- [x] (suggestion) Sources template gains "Digest entries used" — Step 3 (112c45d3)
- [x] (suggestion) `.agent/workflows/README.md`: `## Brainstorm` example and brainstorm in the skills list removed, with a line that it writes no section; no script or test reads that section name — `.agent/workflows/README.md:58` (4f22c930)

### Checks
- `test_skill_paths.sh`: "test_skill_paths: 168 passed, 0 failed"
- No script changed; no manifest change. The full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-21 18:19 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-552 at `a3788a5e`
**Base**: main
**Depth**: Standard (reason: override-trigger file `.claude/skills/*/SKILL.md`)
**Must-fix**: 1 | **Suggestions**: 5
**Round**: 2 | **Ship**: recommended — round 2: 1 mechanical must-fix (prev 4), not rising — fix and ship rather than another full round

Round-1 findings: all 9 resolved (checked against `.claude/skills/brainstorm/SKILL.md` lines 49-55, 82-91, 118, 153-203 and `.agent/workflows/README.md`). Contract with design-discussion (feature/issue-370, SKILL.md:138-142, 255-264) met: signed comment opening `## Brainstorm: <topic>`, `--body-file`, identity in the chain. Cross-model: gemini complete (EXIT=0), codex complete (EXIT=0). Claude adversarial complete (Step 4 chain run with stub `gh`: body verbatim, exit status kept on `gh`/`source` failure, file removed). Tests: test_skill_paths 168/0, test_plugin_manifest 12/0; plugin.json valid JSON. Pre-commit on the changed files did not finish within 300 s (not reported as passed); shellcheck not installed.

### Findings
- [x] (must-fix) `gh issue create ... --title "<title>"` is double-quoted, so a backtick span, `$` or `$(...)` in the title is run or expanded, the same hazard item 4 guards the body against; prescribe a non-expanding form (single quotes with `'\''`, or the title read from a quoted heredoc) (gemini) — `.claude/skills/brainstorm/SKILL.md:174`
- [x] (suggestion) `body="<scratchpad file>"` names no unique file and no directory outside Claude Code (the skill is shared); use `mktemp` in the session scratchpad, else `$WS_ROOT/.agent/scratchpad/` (AGENTS.md Workspace Cleanliness) (adversarial + gemini) — `.claude/skills/brainstorm/SKILL.md:190`
- [x] (suggestion) No rule when `<owner/repo>` cannot be resolved (`gh repo view` fails: no GitHub remote, not a git folder) or the topic's project is unregistered; say the result then stays in the conversation, never falling back to the workspace repo (gemini) — `.claude/skills/brainstorm/SKILL.md:153`
- [x] (suggestion) The public-project check covers a new anchor issue's body but not its title; check both (gemini) — `.claude/skills/brainstorm/SKILL.md:171`
- [x] (suggestion) `### Sources` lists sources read via `$WS_ROOT` / the registered `<path>`, i.e. absolute local paths, which then go into a public comment; write them repo-relative (gemini) — `.claude/skills/brainstorm/SKILL.md:116`
- [x] (suggestion) design-discussion Step 7 `cd`s into the root before sourcing the identity (the email follows the cwd's git config); Step 4 sources it in whatever the cwd is; add `cd <topic root> &&` to match (adversarial) — `.claude/skills/brainstorm/SKILL.md:189`

## Implementation
**Status**: complete
**When**: 2026-11-21 18:37 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-552 at `99eed9ef`
**Addressed**: Local Review (Pre-Push) at `a3788a5e` (2026-11-21 18:19 -05:00)
**Commits**: 4af32bcd, 678e5b2c, 9c1b4031, 598d67b0, 8e9eebaf, 99eed9ef

### Actions
- [x] (must-fix) anchor issue's title written through a quoted heredoc to a mktemp file and passed as `--title "$(cat "$t")"` (the #331 form), never typed in double quotes — `.claude/skills/brainstorm/SKILL.md` Step 4 item 2
- [x] scratch files made with `mktemp` in the session scratchpad, else `$WS_ROOT/.agent/scratchpad/` — Step 4 item 4
- [x] result stays in the conversation when the project is unregistered or `<owner/repo>` does not resolve; never falls back to the workspace repo — Step 4 item 1
- [x] public-project check covers a new anchor issue's title and body — Step 4 items 2 and 3
- [x] `### Sources` names files repo-relative, never absolute local paths — Step 3
- [x] the post chain makes `$WS_ROOT` absolute, then `cd`s into the topic's root before sourcing the identity — Step 4 item 4

### Checks
- `bash .agent/scripts/tests/test_skill_paths.sh`: `test_skill_paths: 168 passed, 0 failed`
- the Step 4 snippet, placeholders filled and `gh` replaced by `cat`: `bash -n` clean, ran with exit 0, scratch file removed
- No script changed; the full pre-commit pass was left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-21 18:38 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-552 at `6eda5b17`
**Base**: main
**Depth**: Standard (reason: round 3 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 3 | **Ship**: recommended — no must-fix findings; remaining suggestion can be applied or tracked

Round-2 findings: all 6 resolved by 4af32bcd..99eed9ef (checked in `.claude/skills/brainstorm/SKILL.md` Step 3 lines 141-145, Step 4 items 1-4 lines 165-229). Exit status: the item-4 comment chain still ends `rc=$?; rm -f "$body"; (exit $rc)`; the item-2 issue-create chain composed as written (item-4 chain, `t` by mktemp + quoted heredoc, `gh issue create --title "$(cat "$t")"`, `rm -f "$body" "$t"` in the rm slot) was run with a stub `gh`: title with backticks/`$(...)`/`$HOME` passed verbatim, chain exit 0 on gh 0 and 1 on gh 1, both scratch files removed. Cross-model: skipped (round-3 convergence check, per handoff). Tests: test_skill_paths 168 passed, 0 failed. Pre-commit not run (host runs the full pass).

### Findings
- [x] (suggestion) Item 2 gives the issue-create chain as edits to item 4's in prose ("and `rm -f "$body" "$t"`") without saying that replaces item 4's `rm -f "$body"` while `rc=$?;` and `(exit $rc)` stay; spell out the final line (`gh issue create ... --body-file "$body"; rc=$?; rm -f "$body" "$t"; (exit $rc)`) and where `t="$(mktemp ...)"` goes, so a reader cannot drop the kept status — `.claude/skills/brainstorm/SKILL.md:189`

## Checkpoint
**Status**: complete
**When**: 2026-11-21 19:43 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: host (orchestrator; the branch no longer merges with main, so the reviewed head cannot be the merged head)
**After**: publish
**Decision**: address

The host's full pre-commit pass on HEAD 5dfa4647 passed (exit 0). But main moved after the round-3 review: PR #553 (design-discussion, #370 Part 1) merged, and `git merge-tree --write-tree HEAD origin/main` reports:

    Auto-merging .claude-plugin/plugin.json
    CONFLICT (content): Merge conflict in .claude-plugin/plugin.json
    Auto-merging .claude/skills/brainstorm/SKILL.md

Findings for the fix pass: (1) merge origin/main into the branch; resolve .claude-plugin/plugin.json by regenerating it with make generate-user-tier-skills (it must list both design-discussion and brainstorm), and check the auto-merged brainstorm/SKILL.md keeps main's "What this is not" pointer to /design-discussion. (2) The round-3 review's one open suggestion: Step 4 item 2 gives the issue-create chain in prose; spell out its final line (gh issue create ... --body-file "$body"; rc=$?; rm -f "$body" "$t"; (exit $rc)) and where t="$(mktemp ...)" goes. (3) design-discussion (now on main) says brainstorm is not available in a project session yet (#552); update that line in .claude/skills/design-discussion/SKILL.md now that this branch makes it available.
