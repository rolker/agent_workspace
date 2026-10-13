---
issue: 389
---

# Issue #389 — Delete the what-next skill; the sit-rep answers "what's next?"

## Issue Review
**Status**: complete
**When**: 2026-10-13 08:58 -04:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #389

### Scope Assessment

**Well-scoped?** Yes — one PR: delete one skill directory, rewrite one skill description and a few lines of its text, update one test list and two roadmap passages. The owner's decision (delete, sitrep answers "What's next?") settles the keep-or-delete question and is not reopened here.
**Right repo?** Yes — a workspace skill, workspace test and `docs/roadmap.md`.
**Serves**: Easy to use ("Work is easy to come back to": one skill for one question) — `docs/design.md#documentation-layers` (the roadmap and sit-rep rows).
**Design picture?** No change — `docs/design.md` and `docs/principles.md` do not name `what-next` (checked by search); the roadmap text is the only design-adjacent mention.
**Dependencies**: none. Follows #386 (sit-rep, merged); the other #386 follow-ups are out of scope.

Search of the worktree for `what-next` (excluding `.git`, `.venv`) found these live references, fewer than the issue lists:
- `.agent/scripts/tests/test_skill_paths.sh:136` — skill list; the loop fails "expected skill is missing" once the skill is deleted, so this must change.
- `docs/roadmap.md` — contains no `what-next` string at all. Line 95 (scenario 4, "First form: the sit-rep") and line 211 (the sit-rep row) do not say what replaced it, so they need new text; they are not a find-and-replace.
- `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md:50-51` — history record; add a note, do not rewrite.
- Work plans and progress files (#121, #142, #265, #269, #317, #334, #386) — history, leave alone.
- No `Makefile` target, `.claude/commands` entry or generated skill index names it. The installer builds its skill list from `.claude/skills/*/SKILL.md` frontmatter, not from a name list.

User-tier installer: the issue's worry is already handled in code. `sync_skills` removes a symlink into this checkout whose skill is no longer selected ("removed stale skill symlink"), and `--check` reports "skill symlink is no longer selected" until a reinstall; `test_user_tier_install.sh` case (e) covers that path for a scope change. So "no drift about `what-next` after a reinstall" holds without installer changes, but `--check` will report drift once, on machines that had it linked, until they rerun the installer. That is expected, and worth one line in the PR.

What `what-next` did that the sit-rep does not: (1) stale-row detection (roadmap row says planned/unchecked, issue closed), (2) needs-ticket detection (planned row with no issue), (3) ranking ready-to-start items by phase order, ticket presence and dependencies, (4) project-roadmap discovery (`project/ROADMAP.md` and variants), (5) `--workspace-only` / `--project-only`. The sit-rep reads the workspace root only, has no ranked "next work" list, and ends with "at most one question". The owner declined keeping (1) and (2) as a separate check. Item (3) is what "What's next?" most directly asks for and is not covered, so the report needs a concrete suggestion.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Test what breaks | Action needed | The acceptance asks for "asking 'what's next?' invokes /sitrep (observed, not assumed)", which a script cannot show, and nothing mechanical protects the result afterwards. Add a check that the sitrep description names the trigger phrases and a check that no live file outside history records names `what-next`; keep the fresh-session observation as the manual acceptance step and record the prompt and the skill that fired. |
| Only what's needed | OK | Deleting the overlapping skill is the point. The sit-rep takes only the "suggest what to do" behaviour, not the roadmap-parsing, issue cross-reference or ranking machinery. |
| Keep one current design | OK | No design section names the skill; the roadmap passages are updated in scope. |
| Put each thing at the level it applies to | Watch | `what-next` was `session_scope: both` and read a project's own roadmap; `/sitrep` in this first mode reads the workspace root only. In a project session, "What's next?" will no longer reach that project's roadmap. That follows from the owner's decision, but say so in the sit-rep text ("registered project roots are not read in this mode" is already printed) so the answer is not mistaken for a project answer. |
| Leave in a project only what it chose to carry | OK | Nothing is written to a project. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| ADR-0016 (user tier) | Yes | Skills link from frontmatter; deletion is cleaned by `sync_skills`; no installer change needed (see above). |
| ADR-0013 (progress timeline) | Yes | Normal entries only. |
| ADR-0003 (project-agnostic workspace) | Watch | Losing the project-roadmap probe narrows what the workspace offers a project session; consistent with the decision. |

### Consequences

- `test_skill_paths.sh` skill list (breaks otherwise).
- Roadmap scenario 4 paragraph and the sit-rep row (#386) say what replaced `what-next`; the "Morning status / standup skill" row (line 210, "planned", "suggest prioritized work plan") now partly overlaps and should point at the sit-rep.
- `.claude/skills/sitrep/SKILL.md`: `description`, Usage and "What it is" text; its report currently has no suggestion line, only "at most one question".
- Digest note in `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md` (A5 entry), upstream's "port what-next here" item.
- Delete `.claude/skills/what-next/` and note the one-time `--check` drift on machines that had it linked.

### Recommendations

- Rewrite the sitrep `description` to trigger on "what's next?", "what should I work on?", "where are we?" while keeping it accurate (it reads, writes one run-record line); then add a final "Suggested next" report line naming one item and why, drawn from facts the sit-rep already read (due deferral, false Direction line, inbox "now" bin, in-flight work), since "ends with a clear suggestion" is in scope and the current end-of-report rule is a question only.
- Fold the lost stale-row and needs-ticket detection into the sit-rep only as a one-line fact if it is cheap (roadmap rows whose issue is closed); otherwise state in the PR that the owner declined it, so the loss is recorded rather than silent.
- In the PR description, list what was dropped (project-roadmap probe, `--workspace-only`/`--project-only`, ranking) and the one-time `user_tier_install.sh --check` drift on machines that had `what-next` linked; verify with a reinstall in a scratch HOME rather than assuming.
- Rewrite roadmap line 95 and the sit-rep row in `docs/roadmap.md` to name `/sitrep` as the answer to "What's next?", and repoint or close the line-210 morning-status row.
- Add a dated note to the inspiration digest A5 entry that `what-next` was deleted (owner decision 2026-10-13, #389) instead of editing its history text.

### Actions
- [ ] The acceptance asks for "asking 'what's next?' invokes /sitrep (observed, not assumed)", which a script cannot show, and nothing mechanical protects the result afterwards. Add a check that the sitrep description names the trigger phrases and a check that no live file outside history records names `what-next`; keep the fresh-session observation as the manual acceptance step and record the prompt and the skill that fired.
- [ ] Rewrite the sitrep `description` to trigger on "what's next?", "what should I work on?", "where are we?" while keeping it accurate (it reads, writes one run-record line); then add a final "Suggested next" report line naming one item and why, drawn from facts the sit-rep already read (due deferral, false Direction line, inbox "now" bin, in-flight work), since "ends with a clear suggestion" is in scope and the current end-of-report rule is a question only.
- [ ] Fold the lost stale-row and needs-ticket detection into the sit-rep only as a one-line fact if it is cheap (roadmap rows whose issue is closed); otherwise state in the PR that the owner declined it, so the loss is recorded rather than silent.
- [ ] In the PR description, list what was dropped (project-roadmap probe, `--workspace-only`/`--project-only`, ranking) and the one-time `user_tier_install.sh --check` drift on machines that had `what-next` linked; verify with a reinstall in a scratch HOME rather than assuming.
- [ ] Rewrite roadmap line 95 and the sit-rep row in `docs/roadmap.md` to name `/sitrep` as the answer to "What's next?", and repoint or close the line-210 morning-status row.
- [ ] Add a dated note to the inspiration digest A5 entry that `what-next` was deleted (owner decision 2026-10-13, #389) instead of editing its history text.

## Checkpoint
**Status**: complete
**When**: 2026-10-13 09:02 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed with actions A1, A2, A4, A5, A6 as proposed (A5: the old "Morning status / standup skill" roadmap row is closed as covered by the sit-rep).
Action 3 (fold stale-row / needs-ticket detection into the sit-rep): owner answered "Drop it" — the check is not carried over; the PR records that the owner declined it.

## Plan Authored
**Status**: complete
**When**: 2026-10-13 09:02 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Plan**: `.agent/work-plans/issue-389/plan.md` at `1dcd8551`

Delete the what-next skill, make sitrep trigger on "what's next?" with a Suggested next line, add guards in test_skill_paths.sh, update roadmap and digest note. Stale-row detection declined by the owner.

## Plan Review
**Status**: complete
**When**: 2026-10-13 09:05 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #389 — Delete the what-next skill; the sit-rep answers "what's next?"
**Plan**: `.agent/work-plans/issue-389/plan.md` at `1dcd8551`
**Branch**: `feature/issue-389`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, five files plus the one the plan misses (finding 2). |
| Issue alignment | Good | Covers the acceptance list and issue-review actions A1, A2, A4, A5, A6; A3 dropped per the owner. Serves, as checked: Easy to use ("Work is easy to come back to"), `docs/design.md#documentation-layers` — README has the "Easy to use" goal and that bullet; the anchor exists. |
| File targeting | Needs work | `.agent/scripts/tests/test_script_tests_hook_scope.sh` is missing (finding 2); `test_skill_paths.sh` header says "Scope: SKILL.md files ONLY" and needs rewording once it carries repo-wide guards. |
| Consequences | Needs work | The "no live file names what-next" guard fails on text the plan itself writes (finding 1); the sit-rep's "Four sections" and "it decides nothing" sentences change with the new line (finding 3). |
| Principle alignment | Needs work | "Enforce what matters, as simply as possible": guard (c) checks the word, not a live pointer to the skill, so it forbids legitimate history prose. "Test what breaks": fine otherwise; the manual trigger check is recorded. |
| ADR compliance | Good | ADR-0016: verified `sync_skills` removes a stale link (`user_tier_install.sh` ~line 347–368) and `--check` notes "no longer selected" (~line 562–568). ADR-0013 normal entries. ADR-0003 watch as stated. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Consequences] must-fix** — Guard (c) (`git grep -l what-next`, excluding work plans and the digest) fails on the plan's own edits: step 2 makes the sit-rep "What it is" say it replaces `what-next`, step 6 makes the roadmap say it "replaced `what-next` (#389)", and the guard's own literal in `test_skill_paths.sh` matches itself. A future design change-log row or ADR noting the deletion would fail it too. Match live pointers, not the word: `/what-next` (slash invocation) and `skills/what-next` (path), built so the test file does not match itself (or excluded by name); then prose history passes and only the digest's path mention needs its exemption. State the exemptions as a rule (work plans; inspiration digests), not one file.
2. **[File targeting] must-fix** — `test_script_tests_hook_scope.sh` declares `test_skill_paths.sh` reads only `.claude/skills`. Guard (c) reads the whole tracked tree, including `docs/` and `README.md`, which the `validate-script-tests` hook's `files:` regex does not cover, so a local docs-only commit would not run the guard (CI's `make lint` runs all files, so CI would). The plan must update that allowlist entry honestly and either limit guard (c)'s pathspec to hook-covered prefixes (`.agent/` minus work plans, `.claude/`, `AGENTS.md`, `Makefile`) or say why docs are left to CI. Add the file to Files to Change.
3. **[Principle alignment] must-fix** — Step 3 contradicts itself and the Open Question: Suggested next is "the last line" and also "the single question stays allowed after it", while the Open Question says the suggestion is "last-but-one". Pick one: Suggested next, then at most one question (recommended — the suggestion proposes an action, the question asks the owner to decide; they do different jobs). In the same edit: change "Four sections, one screen" in step 5 of the sit-rep; reword "The skill formats; it decides nothing" so the suggestion is a proposal like the inbox sort; require the line to name the fact it comes from, and to say "nothing from this run's facts" when no source has an item.
4. **[Issue alignment] suggestion** — Description: put the trigger phrases at the start, as when-to-use ("Use when asked 'what's next?', 'what should I work on?' or 'where are we?'"), since the start is what a picker scanning many skills weighs most; keep the frontmatter valid YAML (no `: ` inside the plain scalar, or quote the whole value — a broken frontmatter drops the skill entirely); guard (a) should read the frontmatter `description` line only, not the body.
5. **[Issue alignment] suggestion** — The manual acceptance can be won by something other than the description: `~/CLAUDE.md` (loaded in any session under the home directory, including the workspace root) tells agents to read `~/Documents/workplan/NOW.md` "when asked about priorities, the day, or the week". Record which one answered "what's next?"; if NOW.md wins, report it to the owner rather than edit his file (instruction files are Ask First).
6. **[Principle alignment] suggestion** — Suggested next draws partly from the inbox "now" bin, which is the sit-rep's own proposed sort, not a checked fact. Give a fixed order of sources (due deferral, then false Direction line, then in-flight work, then proposed inbox "now") so the line is mechanical and says when it rests on a proposal.
7. **[Consequences] suggestion** — Roadmap "Morning status / standup skill" row: say what goes in its Issue column (#386 or #389) when it becomes done, so `update_roadmap.sh` and readers can tie it to the work; and add to the PR note that typing `/what-next` now does nothing.

### Summary

Sound plan, right size, owner decisions respected. Three things to fix before implementing: the what-next guard as written fails on the plan's own text and itself, its repo-wide read is not declared to the hook-scope test, and the report's ending order is stated two ways.

### Recommended Actions

- [ ] Narrow guard (c) to live pointers (`/what-next`, `skills/what-next`), stop it matching its own source, and state the history exemptions as a rule.
- [ ] Update `test_script_tests_hook_scope.sh`'s entry for `test_skill_paths.sh` to what guard (c) reads, and limit its pathspec to hook-covered prefixes or say why docs are left to CI; add the file to Files to Change; reword the `test_skill_paths.sh` header.
- [ ] Settle the ending: Suggested next, then at most one question; update "Four sections" and "decides nothing" in the sit-rep; require the source fact and an empty case.
- [ ] Put trigger phrases first in a valid-YAML description; guard (a) reads the frontmatter description only.
- [ ] In the manual acceptance, record whether `~/CLAUDE.md`'s NOW.md instruction answered instead of /sitrep.
- [ ] Fix an order of sources for Suggested next and mark when it rests on the proposed inbox sort.
- [ ] Fill the morning-status row's Issue column; note in the PR that `/what-next` no longer exists.

## Checkpoint
**Status**: complete
**When**: 2026-10-13 09:08 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise the plan with must-fix M1–M3 and the four suggestions from the Plan Review (265c533f), then re-review.
Open question answered: "Suggestion, then a question" — the report ends with the "Suggested next" line, then at most one question.

## Plan Authored
**Status**: complete
**When**: 2026-10-13 09:09 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Plan**: `.agent/work-plans/issue-389/plan.md` at `8ddf55d5`

Revision: guard (c) narrowed to live pointers with a rule-based history exemption, hook-scope declaration added, report ends with Suggested next then at most one question (fixed source order), and the manual check records whether ~/CLAUDE.md answered. Resolutions are listed in the plan.

## Plan Review
**Status**: complete
**When**: 2026-10-13 09:11 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #389 — Delete the what-next skill; the sit-rep answers "what's next?"
**Plan**: `.agent/work-plans/issue-389/plan.md` at `8ddf55d5`
**Branch**: `feature/issue-389`

Round 2, after the revision. Round-1 findings, checked against the plan text and the source:
- M1 resolved: guard (c) now matches `/what-next` and `skills/what-next` only, built from pieces, with the history exemption as a rule. `git grep -E '/what-next|skills/what-next'` outside work plans today hits only the skill itself (deleted) and the digest line 51 (exempt), so the guard passes after the change.
- M2 resolved for the hook-scope entry (step 6): `.agent/ .claude/` directory prefixes plus `AGENTS.md` and `Makefile` (both in `LITERAL_FILE_PREFIXES`) fit the existing `ROOT_READERS` format, and `test_user_tier_install.sh` already declares `.agent/ .claude/`, so the coverage check passes. The CI half is wrong (finding 1).
- M3 resolved: Suggested next, then at most one question; "Four sections" (sitrep SKILL.md line 244), "it decides nothing" (line 42) and the question rule (line 286) are all named; source fact and empty case required.
- S4, S5, S6, S7 resolved (steps 2, 5, 9, 3, 7, 10).

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, six files. |
| Issue alignment | Good | Acceptance list and A1, A2, A4, A5, A6 covered; A3 dropped per the owner. Serves, as checked: Easy to use ("Work is easy to come back to"), `docs/design.md#documentation-layers` (README line 88/98, design.md line 86). The manual acceptance step observes the wrong tree (finding 2). |
| File targeting | Good | `test_script_tests_hook_scope.sh` added; `test_sitrep_checks.sh` only runs the `bash` blocks under steps 1–4 of the sitrep skill, so the step-5 text change does not touch it. |
| Consequences | Good | Roadmap lines 95, 210, 211 and digest line 50 match the plan's line numbers. |
| Principle alignment | Needs work | "Verify before claiming": the plan says CI checks `docs/` and `README.md` for live pointers, which the guard as specified will not do (finding 1). |
| ADR compliance | Good | ADR-0016, ADR-0013, ADR-0003 as before. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment] must-fix** — Step 5 limits guard (c)'s pathspec to `.agent/`, `.claude/`, `AGENTS.md`, `Makefile`, then says `docs/` and `README.md` "are left to CI's `make lint` (all files)". CI runs `make lint` = `pre-commit run --all-files` (`.github/workflows/validate.yml:25`, Makefile line 116), which runs the same guard with the same pathspec, so CI never reads `docs/` or `README.md` either. As planned, a `/what-next` pointer in `docs/`, `README.md`, `CODEX.md`, `CLAUDE.md` or `.github/copilot-instructions.md` is caught nowhere. Widening the pathspec is not an option (step 6 would have to declare `docs/`, which the hook's `files:` regex does not cover, and the hook-scope test fails). Fix the text: say these files are not guarded and why, in the plan, the test header and the PR, instead of saying CI covers them.
2. **[Issue alignment] must-fix** — Step 9's manual acceptance runs "in a fresh session at the workspace root". The workspace root is the main checkout (`~/.claude/agent-workspace-root` = `/home/roland/agent_workspace`), whose `.claude/skills/` still has `what-next` and the old sitrep description until this PR merges, so the check would observe the old skills and report a result that says nothing about this change. Say where it runs: a fresh session in this worktree before the PR (its `.claude/skills/` is the branch), or at the main root after merge. Either way, record the directory with the prompt. On this machine `~/.claude/skills/` links only `start-task`, so no user-tier copy of `what-next` interferes.
3. **[Consequences] suggestion** — Step 2's "What it is" text (and any other text under `.claude/` or `.agent/`) should name the old skill without the slash (`what-next`, not `/what-next`), or guard (c) fails on it. The test catches it, but saying it in step 2 saves a round.

### Summary

The revision fixes all three round-1 must-fix items and all four suggestions. Two new statements are wrong: CI does not check `docs/` for live pointers, and the manual acceptance as written runs against the main checkout instead of the branch. Both are one-sentence fixes to the plan text, and the approach does not change.

### Recommended Actions

- [ ] Step 5: replace "left to CI" with a statement that guard (c) does not read `docs/`, `README.md` or the other root instruction files, and why; carry the same wording into the test header and the PR text.
- [ ] Step 9: run the manual acceptance in a fresh session in this worktree (or at the main root after merge), and record the directory with the prompt and which answered.
- [ ] Step 2: name the old skill without the slash in live text under `.claude/` and `.agent/`.

## Checkpoint
**Status**: complete
**When**: 2026-10-13 09:13 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

"Proceed; fix in plan first": implementation starts; its first commit amends the plan with the round-2 Plan Review (1b27b385) findings N1 (docs/, README.md, CODEX.md, CLAUDE.md, .github/copilot-instructions.md are not guarded — say so and why in the plan, test header and PR; grep them once by hand in this change), N2 (run the manual "what's next?" check in the #389 worktree before the PR, recording the directory) and the suggestion (name the old skill without the slash in text under .claude/ and .agent/), then builds. No third plan review; the pre-push code review sees both.

## Implementation
**Status**: complete
**When**: 2026-10-13 09:46 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-389 at `3df7851b`

- `81dccfb6` plan amended with the round-2 Plan Review (`1b27b385`) findings N1, N2 and the no-slash suggestion, per the owner's "Proceed; fix in plan first".
- `9598a406` sitrep: quoted-YAML description leads with the triggers ("what's next?", "what should I work on?", "where are we?"); "What it is" says it replaces the old what-next skill and that the inbox sort and Suggested next are proposals; report ends with "Suggested next" (fixed order: due deferral, false Direction line, work in flight, proposed inbox "now" — marked "this rests on the proposed inbox sort"; empty case "nothing from this run's facts"), then at most one question; "Four sections" updated.
- `14f70e63` `.claude/skills/what-next/` deleted; `test_skill_paths.sh` lists sitrep instead and adds guards (a) description triggers, (b) directory gone, (c) no slash-command or skills-path pointer under `.agent/`, `.claude/`, `AGENTS.md`, `Makefile`, with work plans and inspiration digests exempt; header says `docs/`, `README.md`, `CODEX.md`, `CLAUDE.md`, `.github/copilot-instructions.md` are not guarded and why. Hook-scope entry now `.agent/ .claude/ AGENTS.md Makefile`. Guards checked failing on a planted pointer and a removed trigger, then restored.
- `3df7851b` roadmap scenario 4 paragraph, sit-rep row and morning-status row (done, `#386`); dated A5 note in the inspiration digest.
- Hand grep of the unguarded files (`docs/`, `README.md`, `CODEX.md`, `CLAUDE.md`, `.github/copilot-instructions.md`): no what-next reference at all.

Verification:
- `.agent/scripts/tests/run_script_tests.sh`: all 33 suites passed (234 s).
- Scratch HOME (session scratchpad clone): install at `9598a406` linked what-next; after checkout of `14f70e63`, `--check` reported DRIFT "skill symlink is no longer selected: what-next" (exit 1); reinstall printed "removed stale skill symlink: what-next"; `--check` then "installed and current" (exit 0). Scratch removed.
- Manual "what's next?": `claude -p "what's next?" --output-format stream-json --verbose --max-turns 2`, cwd `/home/roland/agent_workspace/worktrees/workspace/issue-workspace-389`. Init listed `sitrep` and no what-next; the first tool call was `Skill {"skill":"sitrep"}`; no read of `~/Documents/workplan/NOW.md`. Its later Bash calls (status line, steps 1–3) were all denied by headless permissions, so no report was produced and nothing was written; the run stopped at max turns.

PR notes for publish: dropped — project-roadmap probe, `--workspace-only`/`--project-only`, ranking, stale-row and needs-ticket detection (declined by the owner); typing `/what-next` now does nothing; machines that had it linked see one `user_tier_install.sh --check` drift until the installer is rerun; guard (c) does not read `docs/`, `README.md`, `CODEX.md`, `CLAUDE.md` or `.github/copilot-instructions.md` (CI runs the same hook over the same pathspec; widening would fail the hook-scope test).

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-13 09:55 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested

**Branch**: feature/issue-389 at `5123b139`
**Base**: main
**Depth**: Standard (reason: override-trigger file `.claude/skills/*/SKILL.md`; 520+/240-)
**Must-fix**: 1 | **Suggestions**: 2
**Round**: 1 | **Ship**: continue — round 1: 1 must-fix; first round always re-reviews after fixes

Reviewers: Claude adversarial ran (0 must-fix); Gemini ran; Codex ran (raised the must-fix, confirmed: `worktree_list.sh --json` lists the main checkout as `type: "main"`); Copilot ran. Not carried: roadmap morning-status row "done" (Copilot, adversarial) — owner closed it as covered (A5); project-session scope (Gemini, adversarial) — owner decision, already printed in the report and PR notes; design.md update (Gemini) — design.md does not name the old skill and the parts do not change.

### Findings
- [x] (must-fix) "Suggested next" counts every worktree as work in flight, but `worktree_list.sh --json` always lists the main checkout (`type: "main"`), so an idle main checkout outranks the inbox "now" bin and "nothing from this run's facts" can never be reached; exclude `type: "main"` from the candidates — `.claude/skills/sitrep/SKILL.md:291-293`
- [x] (suggestion) No pick within a source when several qualify (due deferrals, false lines, worktrees, open PRs), and the session's own worktree will nearly always win "work in flight"; state the tie-break (e.g. first as listed in the report) and whether the current worktree counts — `.claude/skills/sitrep/SKILL.md:291-294`
- [x] (suggestion) Only `false` Direction lines feed "Suggested next"; a `format` problem (broken Direction section) or all-`unknown`/`partial` lines fall through to in-flight work or "nothing"; say whether a format problem is a source, or that it is deliberately not — `.claude/skills/sitrep/SKILL.md:292`

## Implementation
**Status**: complete
**When**: 2026-10-13 10:11 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**Branch**: feature/issue-389 at `4ab547d1`
**Addressed**: Local Review (Pre-Push) at `5123b139` (2026-10-13 09:55 -04:00)
**Commits**: 545af354, 393e01b9, 4ab547d1

### Actions
- [x] (must-fix) The main checkout (`type: "main"`, always in the worktree list) is not work in flight: left out of the In flight section and never a Suggested next candidate — `.claude/skills/sitrep/SKILL.md` step 3 and step 5 rules
- [x] (suggestion) Pick within a source: the first as listed in the report; the session's own worktree counts like any other — `.claude/skills/sitrep/SKILL.md` step 5 rules
- [x] (suggestion) From the Direction section only a due deferral and a `false` line are sources; a `format` problem and `unknown`/`partial`/`unchecked` lines deliberately are not (a check could not decide); the closing question may ask about them — `.claude/skills/sitrep/SKILL.md` step 5 rules

### Checks
- `test_sitrep_checks.sh`: 141 passed, 0 failed
- `test_skill_paths.sh`: 58 passed, 0 failed
- pre-commit hooks passed on all three commits

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-10-13 10:31 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved
**Dispatch**: resumed (agent a20fc3d5a00a4467c, resume 1 of 3)

**Branch**: feature/issue-389 at `25923749`
**Base**: main
**Depth**: Standard (reason: override-trigger file `.claude/skills/*/SKILL.md`; whole-diff classification)
**Must-fix**: 0 | **Suggestions**: 1
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

Round-1 findings verified fixed in 545af354, 393e01b9, 4ab547d1. The fixer also left the main checkout out of the report's In flight section and step 3's per-worktree note: confirmed — the main checkout is not work in flight, and "first as listed in the report" only holds if the listed items and the candidates agree. Reviewers: Claude adversarial ran (0 must-fix; suggestions on pre-existing sitrep behaviour, untested template text and a long line, not carried); Codex ran (no issues); Copilot ran (no issues; its shell was denied, so it ran no tests); Gemini failed first ("stream was interrupted"), retried once and ran (5 suggestions: 1 carried, the rest not carried — no `set -e` in the suite, wording equivalent to the plan, cosmetic).

### Findings
- [ ] (suggestion) Within "work in flight", "first as listed" always picks a worktree over an open pull request, and a pull request whose branch has a worktree appears twice; consider one line merging the two by branch and saying whether a pull request awaiting the owner comes first — `.claude/skills/sitrep/SKILL.md:269-273, 303-307`

## Checkpoint
**Status**: complete
**When**: 2026-10-13 10:34 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: publish
**Decision**: publish

Publish after pre-push round 2 (411fb0fc, approved, 0 must-fix). The one open suggestion (merge worktrees and open PRs by branch under "work in flight"; say whether a PR waiting on the owner comes first) is noted in the PR body and picked up at triage with the bot findings.

## Integrated Review
**Status**: complete
**When**: 2026-10-13 10:38 -04:00
**By**: Claude Code Agent (claude-fable-5-1)

**PR**: #390 at `bff4f95`
**Sources**: 3 (Copilot R1 @ `bff4f95`, Local Review (Pre-Push) @ `2592374` (covers `bff4f95` via bookkeeping), CI rollup)
**Cross-source confirmations**: 1
**CI**: pending

### Findings
- [x] (cross-confirmed, suggestion; Copilot R1 @ `bff4f95` + Local Review (Pre-Push) @ `2592374`) Under "work in flight", "take the first as listed" picks a worktree over any open pull request, because the report lists worktrees before pull requests, and a pull request whose branch has a worktree appears twice. Fix: merge worktrees and open pull requests into one line per branch (match on `headRefName`), and say whether a pull request waiting on the owner comes before a branch with no pull request — `.claude/skills/sitrep/SKILL.md`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-10-13 10:50 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: findings
**Decision**: address

"Address, then merge": fix the one open suggestion from the Integrated Review (0a5a87ea) — under "work in flight", one line per branch (match worktrees and open PRs on headRefName) and say whether a PR waiting on the owner comes before a branch with no PR — then re-review and return to the merge decision.

## Implementation
**Status**: complete
**When**: 2026-10-13 10:55 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Dispatch**: resumed (agent a4c953679901c53f2, resume 1 of 3)

**PR**: #390 at `152b9d96`
**Addressed**: Integrated Review at `bff4f95` (2026-10-13 10:38 -04:00)
**Commits**: 152b9d96

### Actions
- [x] (cross-confirmed, suggestion) In flight is one line per branch (worktree `branch` matched to pull request `headRefName`); branches whose pull request waits on the owner (open, not a draft) come first, then drafts and worktree-only branches, in printed order; Suggested next's "work in flight" source is a branch line, so its first pick is an owner-waiting pull request when there is one — `.claude/skills/sitrep/SKILL.md` step 3, report template, step 5 rules

### Checks
- `test_sitrep_checks.sh`: 141 passed, 0 failed
- `test_skill_paths.sh`: 58 passed, 0 failed
- pre-commit hooks passed on the fix commit

## Local Review
**Status**: complete
**When**: 2026-10-13 11:03 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: changes-requested
**Dispatch**: resumed (agent a20fc3d5a00a4467c, resume 2 of 3)

**PR**: #390 at `7e183de5`
**Depth**: Standard (reason: override-trigger file `.claude/skills/*/SKILL.md`; whole-PR classification)
**Must-fix**: 1 | **Suggestions**: 2

Re-review after the post-triage fix 152b9d96 (one In flight line per branch, owner-waiting pull requests first). The Copilot R1 comment at `bff4f95` is addressed by that commit. CI at `7e183de5`: Lint (pre-commit) still pending at review time; the other checks passed. Reviewers: Claude adversarial ran (raised the must-fix); Codex ran (same must-fix, independently); Copilot ran (one finding rated must-fix, carried as a suggestion: the owner's checkpoint framed the group as "a PR waiting on the owner", and every ready PR here needs his merge; its shell was denied, so it ran no tests); Gemini ran (one suggestion, a dangling-symlink check in the test, not carried — a tracked symlink in the repo's skills directory is not a realistic case).

### Findings
- [x] (must-fix) The per-branch merge matches any worktree's `branch` to a workspace pull request's `headRefName`, but `worktree_list.sh --json` also emits `type: "project"` entries whose branches follow the same `feature/issue-<N>` naming with per-repo numbers, so a project worktree and an unrelated workspace pull request would share one line (and could become "Suggested next"); match only `type: "workspace"` worktrees and give project worktrees their own line with no pull request — `.claude/skills/sitrep/SKILL.md:195-200, 278-280`
- [x] (suggestion) "Waits on the owner" is inferred from open-and-not-draft while the fetched `reviewDecision` is unused (empty on this repo); either describe the group by what was checked ("open, not a draft") or say how `reviewDecision` (e.g. CHANGES_REQUESTED) affects it, and what to print when it is empty — `.claude/skills/sitrep/SKILL.md:197-198, 279`
- [x] (suggestion) "Keep the order the commands above printed" is ambiguous for a line built from both commands; state it, e.g. worktree-list order first, then pull-request-only branches in `gh` order — `.claude/skills/sitrep/SKILL.md:199-200`

## Implementation
**Status**: complete
**When**: 2026-10-13 11:18 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Dispatch**: resumed (agent a4c953679901c53f2, resume 2 of 3)

**PR**: #390 at `018b79b1`
**Addressed**: Local Review at `7e183de5` (2026-10-13 11:03 -04:00)
**Commits**: 1ce50fc6, 17a6f40f, 018b79b1

### Actions
- [x] (must-fix) Only workspace worktrees (`type: "workspace"`) are matched to the workspace pull requests by `headRefName`; a project worktree gets its own line, named `<project>/<branch>`, with no pull request — `.claude/skills/sitrep/SKILL.md` step 3 and the In flight template
- [x] (suggestion) The first group is named by what is checked, a ready pull request (open, not a draft; each needs the owner's merge); `reviewDecision` does not change the order, is printed as the review state when set and omitted when empty — `.claude/skills/sitrep/SKILL.md` step 3, In flight template, Suggested next sub-rule
- [x] (suggestion) Order within each group stated: branches with a worktree first in worktree-list order, then pull-request-only branches in `gh pr list` order — `.claude/skills/sitrep/SKILL.md` step 3

### Notes
- `review_progress.sh findings`/`check` do not treat a post-PR `## Local Review` as a source (they still select the Integrated Review at `bff4f95`, which has no open boxes), so the three boxes were checked by hand in each fix commit.

### Checks
- `test_sitrep_checks.sh`: 141 passed, 0 failed
- `test_skill_paths.sh`: 58 passed, 0 failed
- pre-commit hooks passed on all three fix commits

## Local Review
**Status**: complete
**When**: 2026-10-13 11:29 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved
**Dispatch**: resumed (agent a20fc3d5a00a4467c, resume 3 of 3)

**PR**: #390 at `ec271dcf`
**Depth**: Standard (reason: override-trigger file `.claude/skills/*/SKILL.md`; whole-PR classification)
**Must-fix**: 0 | **Suggestions**: 1

Re-review after fixes 1ce50fc6, 17a6f40f, 018b79b1 to the Local Review at `7e183de5`: all three verified in `.claude/skills/sitrep/SKILL.md` step 3, the In flight template and the step-5 tie-break (only `type: "workspace"` worktrees matched to workspace pull requests; project worktrees get their own line; "ready pull request" = open and not a draft, `reviewDecision` printed when set and not used for order; worktree-list order, then pull-request-only branches in `gh` order). The Copilot comment at `7e183de5` (cross-repo branch-name match) is answered by 1ce50fc6. CI at `ec271dcf`: all checks pass (Lint, Validate Documentation, Validate Adapter Contract, ros-manifest tests). Reviewers: Claude adversarial ran (0 must-fix; it checked `worktree_list.sh --json` and `gh pr list` live; its suggestions on package/legacy project-worktree fields, `type: "main"` covering worktrees outside the standard paths, `gh pr list` default limit of 30 and issue numbers inside branch names concern behaviour that predates this PR and are not carried); Codex ran (no issues); Copilot ran (no issues); Gemini ran (6 suggestions; 2 merged into the one below; not carried: `set -e` and empty `WS_ROOT` in the test — the suite runs `set -uo pipefail` without `-e` and sets `WS_ROOT` from its own path; dangling-symlink check; multi-line YAML description).

Tooling note for triage (not a finding in this PR): the fixer ticked the previous Local Review's three boxes by hand, because `review_progress.sh findings` does not treat a post-PR `## Local Review` entry as a source.

### Findings
- [ ] (suggestion) The In flight template line is loose for an agent filling it in: "draft" or its review state reads as either/or although step 3 prints `reviewDecision` whenever set, the "(for a project worktree, <project>/<branch>)" aside may be copied literally, and the fixed ";" leaves a dangling separator when a line has only a pull request or only a worktree; write it as alternatives (`<branch>` or `<project>/<branch>`; "draft, and its review state if set"; each part only when present) — `.claude/skills/sitrep/SKILL.md:287-289`

## Integrated Review
**Status**: complete
**When**: 2026-10-13 11:32 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Dispatch**: resumed (agent a94fcb5751a90f309, resume 1 of 3)

**PR**: #390 at `ec271dc`
**Sources**: 5 (Copilot R1 @ `bff4f95`, Copilot R2 @ `7e183de`, Copilot R3 @ `ec271dc`, Local Review @ `ec271dc`, CI rollup)
**Cross-source confirmations**: 0
**CI**: all-pass

Verdict: approved; 0 must-fix, 3 open suggestions. Already addressed, not re-listed: Copilot R1 @ `bff4f95` (one In flight line per branch, ready pull requests first) by 152b9d96, which also closes the Integrated Review at `bff4f95` and the stale pre-push suggestion at `2592374`; Copilot R2 @ `7e183de` (a project worktree joined to a workspace pull request by branch name) by 1ce50fc6, which matches only `type: "workspace"` worktrees. CI at `ec271dc`: Lint (pre-commit), Validate Documentation, Validate Adapter Contract and the ros-manifest tests all pass.

Tooling notes for the host, not findings on this PR; they belong with the open `review_progress.sh` issues #357 / #360: `review_progress.sh findings` does not treat a post-PR `## Local Review` as a fix source (the fixer ticked its boxes by hand); `review_progress.sh sources` extracts no file from a backticked `path:lines` reference, so the round-1 cross-source match was found by reading, not by `candidates`.

### Findings
- [x] (suggestion, Local Review @ `ec271dc`) The In flight template line is loose for an agent filling it in: "draft" or its review state reads as either/or although step 3 prints `reviewDecision` whenever set; the "(for a project worktree, <project>/<branch>)" aside may be copied literally; the fixed ";" leaves a dangling separator on a line with only a pull request or only a worktree. Write it as alternatives (`<branch>` or `<project>/<branch>`; "draft, and its review state if set"; each part only when present) — `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion, Copilot R3 @ `ec271dc`, review body) `headRefName` is not tied to a repository: a pull request from a fork can reuse a local workspace branch name and be joined to that worktree's line. The repository is public, so this can happen, although it has 0 forks and has never had a cross-repository pull request. Fix: add `isCrossRepository` to the `gh pr list --json` fields and join only pull requests where it is false; a cross-repository pull request gets its own line — `.claude/skills/sitrep/SKILL.md`
- [x] (suggestion, Copilot R3 @ `ec271dc`, review body) The PR body still carries "Open suggestion, for triage" (merge worktrees and pull requests by branch, owner-waiting first), which 152b9d96 resolved. Fix: the host removes that paragraph or marks it resolved when it next edits the PR body — PR #390 description (deferred: host edited the PR description)

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-10-13 11:41 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: findings
**Decision**: address

"Fix 1–2, then merge" on the second Integrated Review (1ca9bd79): rewrite the "In flight" template line (alternatives, each part shown only when present); add `isCrossRepository` to the `gh pr list` fields and join a PR to a worktree only when it is false. Finding 3 (stale "Open suggestion, for triage" paragraph in the PR description) is the host's edit, done directly. Then re-review and the merge decision.

## Implementation
**Status**: complete
**When**: 2026-10-13 11:53 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Dispatch**: resumed (agent a4c953679901c53f2, resume 3 of 3)

**PR**: #390 at `9baa4548`
**Addressed**: Integrated Review at `ec271dc` (2026-10-13 11:32 -04:00)
**Commits**: 4487bb0f, 9baa4548 (fixes); 6c44e30d (tick for the host's finding)

### Actions
- [x] (suggestion) In flight template is now `<name>: <pull request part>; <worktree part>`, with a report rule naming what each part holds (name: branch, or project/branch for a project worktree; pull request: title, then "draft" if one, then review state if set) and that a missing part and its "; " are left out — `.claude/skills/sitrep/SKILL.md` report template and rules
- [x] (suggestion) `gh pr list` now fetches `isCrossRepository`; a pull request joins a workspace worktree only when it is false; a fork's pull request gets its own line, "from a fork" after its title, no worktree part — `.claude/skills/sitrep/SKILL.md` step 3 and report rules
- [x] (suggestion) PR description still carried the resolved "Open suggestion" paragraph — PR #390 description (deferred: host edited the PR description)

### Notes
- `review_progress.sh check` saw this Integrated Review's boxes, so all three were ticked by the script, not by hand.
- `isCrossRepository` checked as a valid `gh pr list --json` field against this repository.

### Checks
- `test_sitrep_checks.sh`: 141 passed, 0 failed
- `test_skill_paths.sh`: 58 passed, 0 failed
- pre-commit hooks passed on all three commits

## Local Review
**Status**: complete
**When**: 2026-10-13 12:01 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Verdict**: approved

**PR**: #390 at `6b29b395`
**Depth**: Standard (reason: override-trigger file `.claude/skills/*/SKILL.md`; whole-PR classification)
**Must-fix**: 0 | **Suggestions**: 1

Fresh reviewer (the previous one reached its resume limit). Re-review after fixes 4487bb0f (In flight line as `<name>: <pull request part>; <worktree part>`, parts omitted when absent) and 9baa4548 (`isCrossRepository` fetched; a fork pull request never joins a worktree, gets its own line "from a fork"): both verified in `.claude/skills/sitrep/SKILL.md` step 3, the template and the step-5 rules, and consistent with the Suggested next ordering. Checks: `test_skill_paths.sh` 58 passed, `test_script_tests_hook_scope.sh` 108 passed, `test_sitrep_checks.sh` 141 passed (adversarial run); shellcheck (workspace .venv) clean on both edited tests; `git grep` finds no live what-next pointer outside work plans and the digest. CI at `6b29b395`: Lint (pre-commit) pending at review time, the other checks pass. Reviewers: Claude adversarial ran (0 must-fix, 3 suggestions: 2 merged into the one below; not carried: a ready fork pull request as a Suggested next source — the rules give it, and the repository has no forks); Codex ran (no issues); Gemini ran (3 suggestions, not carried: pull request number in the line — titles are what the report shows; `CHANGES_REQUESTED` ordering — decided in the previous round, `reviewDecision` does not change order; multi-line YAML description — the test would fail loudly, not silently); Copilot CLI failed (monthly quota exceeded); the Copilot hosted review at `6b29b395` is a quota notice, not a review.

### Findings
- [ ] (suggestion) In flight line wording: "one line per branch" does not say that a fork pull request and a worktree with the same branch name both get lines (an agent may drop one as a duplicate), and the pull request part's pieces (title, "from a fork", "draft", review state) have no separator, so it can render as a run-on; say the fork exception where "one line per branch" is stated and give the qualifiers a fixed form, e.g. in parentheses after the title — `.claude/skills/sitrep/SKILL.md:195, 289, 309-311`

## Integrated Review
**Status**: complete
**When**: 2026-10-13 12:01 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Dispatch**: resumed (agent a94fcb5751a90f309, resume 2 of 3)

**PR**: #390 at `6b29b39`
**Sources**: 2 (Local Review @ `6b29b39`, CI rollup); missing: Copilot @ `6b29b39`
**Cross-source confirmations**: 0
**CI**: all-pass

Verdict: approved; 0 must-fix, 1 open suggestion. Missing source: Copilot's review at `6b29b39` is a quota notice ("Copilot was unable to review this pull request because the user who requested the review has reached their quota limit"), not a review, so Copilot did not review this head. Its `copilot-pull-request-reviewer` check-run reads `failure` for the same reason; `merge_pr.sh` excludes that check-run from CI (#300), so it is not counted as a CI failure. CI at `6b29b39`: Lint (pre-commit), Validate Documentation, Validate Adapter Contract and the ros-manifest tests all pass, on both runs.

Already addressed, not re-listed: the three findings of the Integrated Review at `ec271dc` are ticked. 4487bb0f spells out the In flight line part by part (this also closes the Local Review at `ec271dc`, now stale). 9baa4548 adds `isCrossRepository` to `gh pr list` and never joins a fork's pull request to a worktree. The host edited the PR description. Checked against `.claude/skills/sitrep/SKILL.md` step 3 and the In flight report rules.

### Findings
- [ ] (suggestion, Local Review @ `6b29b39`) In flight wording: "one line per branch" (step 3, and the template's "one line per branch") does not say that a fork's pull request and a worktree with the same branch name each get a line, so an agent may drop one as a duplicate. The pull request part's pieces (title, "from a fork", "draft", review state) also have no separator and can run on. Fix: state the fork exception where "one line per branch" is stated, and give the qualifiers a fixed form, e.g. comma-separated in parentheses after the title — `.claude/skills/sitrep/SKILL.md`

### False positives

## Checkpoint
**Status**: complete
**When**: 2026-10-13 12:19 -04:00
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: findings
**Decision**: merge

"Merge, defer the wording note" on the third Integrated Review (f8fa6cd2): the open suggestion (state the fork exception where "one line per branch" appears; a fixed form for the labels after a PR title) is deferred to the first real sit-rep run that shows such a line — the repository has no forks. Hosted Copilot did not review the head (quota notice; its check-run is excluded from the gate since #300); CI all-pass at 6b29b395.
