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
