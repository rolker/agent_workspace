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
