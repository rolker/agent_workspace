# Plan: Delete the what-next skill; the sit-rep answers "what's next?"

## Issue

https://github.com/rolker/agent_workspace/issues/389

## Context

Two skills answer "what's next": `what-next` (ranks roadmap rows) and `/sitrep`
(#386, answers from checked facts). Owner decision 2026-10-13: delete
`what-next`; `/sitrep` answers "What's next?". Issue-review actions A1, A2, A4,
A5, A6 were approved; A3 (carry stale-row / needs-ticket detection into the
sit-rep) was declined by the owner ("Drop it") and is not carried over.

## Approach

1. **Delete the skill** — `git rm -r .claude/skills/what-next/`. The user-tier
   installer builds its list from `SKILL.md` frontmatter and `sync_skills`
   already removes the stale symlink; no installer change.
2. **Sit-rep triggers** — rewrite the `description` in
   `.claude/skills/sitrep/SKILL.md` with the trigger phrases first, as
   when-to-use ("Use when asked 'what's next?', 'what should I work on?' or
   'where are we?'. ..."), then still stating it reads and writes one
   run-record line. Keep the frontmatter valid YAML: quote the whole value and
   put no `: ` inside it. Adjust "What it is" to say it replaces `what-next`.
3. **Suggested next line** — add a fifth report item, "Suggested next", as the
   closing line, then at most one question (the suggestion proposes an action;
   the question asks the owner to decide). Source order is fixed: due
   deferral, then false Direction line, then in-flight work, then the
   proposed inbox "now" bin. The line names the fact it rests on, says "this
   rests on the proposed inbox sort" when it comes from that bin, and reads
   "nothing from this run's facts" when no source has an item. In the same
   edit: "Four sections, one screen" (step 5) becomes five; "The skill
   formats; it decides nothing" is reworded so the suggestion is a proposal
   like the inbox sort; the "End with at most one question" rule (line ~286)
   now follows the suggestion. Keep the printed note that registered project
   roots are not read.
4. **Test list** — in `.agent/scripts/tests/test_skill_paths.sh`, remove
   `what-next` from the scope loop and add `sitrep` (it declares `both`).
   Reword the header ("Scope: SKILL.md files ONLY") now that it also carries
   repo-wide guards.
5. **Mechanical guards** (A1) in `test_skill_paths.sh`:
   (a) the sitrep frontmatter `description` line (not the body) contains the
   trigger phrases;
   (b) `.claude/skills/what-next` does not exist;
   (c) no live pointer to the skill: `git grep` for `/what-next` and
   `skills/what-next`, patterns built from pieces so the test file does not
   match itself. Prose that merely names the skill passes. Exemptions are a
   rule, not a file: `.agent/work-plans/` and `.agent/knowledge/inspiration_*`
   digests (history records). Pathspec is limited to hook-covered prefixes
   (`.agent/`, `.claude/`, `AGENTS.md`, `Makefile`); `docs/` and `README.md`
   are left to CI's `make lint` (all files), because the
   `validate-script-tests` hook's `files:` regex does not cover them.
6. **Hook-scope declaration** — update the `test_skill_paths.sh` entry in
   `test_script_tests_hook_scope.sh` (line ~189, now `.claude/skills`) to the
   prefixes guard (c) reads, in that file's existing format; run that test.
7. **Roadmap** — rewrite scenario 4's "First form" paragraph (line ~95) to say
   `/sitrep` answers "What's next?" and replaced `what-next` (#389); extend the
   sit-rep row (line ~211); mark the "Morning status / standup skill" row
   (line ~210) done with `#386` in its Issue column (the sit-rep built it; #389
   extended it) and a note that the sit-rep covers it.
8. **Digest note** — dated note under A5 in
   `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`: skill deleted
   2026-10-13 (#389); the original text stays.
9. **Verify** — run `.agent/scripts/tests/run_script_tests.sh`; in a scratch
   HOME, install the user tier with `what-next` linked, rerun, and confirm
   the symlink is removed and `--check` is clean (A4). Manual acceptance: in a
   fresh session at the workspace root ask "what's next?" and record the
   prompt and which answered: the sit-rep skill, or the `~/CLAUDE.md`
   instruction to read `~/Documents/workplan/NOW.md`. Report the result to the
   owner. If NOW.md answered, do not edit `~/CLAUDE.md` or any instruction
   file (Ask First); the owner decides.
10. **PR text** — list what was dropped (project-roadmap probe,
    `--workspace-only`/`--project-only`, ranking, stale-row and needs-ticket
    detection, declined by the owner), that typing `/what-next` now does
    nothing, and the one-time `--check` drift on machines that had it linked.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/what-next/` | Delete |
| `.claude/skills/sitrep/SKILL.md` | Description, "What it is", Suggested next line, section count, "decides nothing" wording |
| `.agent/scripts/tests/test_skill_paths.sh` | Skill list; header; three new guards |
| `.agent/scripts/tests/test_script_tests_hook_scope.sh` | Declared reads for `test_skill_paths.sh` |
| `docs/roadmap.md` | Scenario 4 paragraph, sit-rep row, morning-status row |
| `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md` | Dated deletion note under A5 |

## Prior Art

`what-next` itself (read before deleting, for the one behaviour to keep: a
concrete suggestion). The installer's stale-symlink removal and
`test_user_tier_install.sh` case (e) already cover deletion. Nothing new is
built beyond one report line.

## Serves

Easy to use ("Work is easy to come back to"), `docs/design.md#documentation-layers`.

## Design Picture

No change to the design picture; `docs/design.md` does not name `what-next`.
Only the roadmap text changes.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Test what breaks | Guards in step 5; the fresh-session trigger is a manual, recorded acceptance step |
| Only what's needed | Take only the suggestion behaviour, not ranking or roadmap parsing |
| Keep one current design | Roadmap updated in the same change |
| Put each thing at the level it applies to | Report states that project roots are not read |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0016 | Yes | Deletion cleaned by `sync_skills`; verified in a scratch HOME |
| ADR-0013 | Yes | Normal progress entries |
| ADR-0003 | Watch | Narrower project-session offering follows the owner's decision |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Skill removal | `test_skill_paths.sh` list, hook-scope declaration | Yes |
| Skill removal | Roadmap, digest note | Yes |
| Skill removal | Installed symlinks on other machines | Yes, PR note; installer rerun |

## Open Questions

- None. Settled by the owner: the report ends with Suggested next, then at
  most one question.

## Estimated Scope

Single PR.

## Plan Review Resolution

Revision after the Plan Review of 2026-10-13 (verdict needs-work).

- M1 (guard (c) matched own text): now matches `/what-next` and
  `skills/what-next` only, built from pieces; history exemption stated as a
  rule (step 5).
- M2 (hook scope): step 6 and Files to Change add the hook-scope entry;
  guard (c) pathspec limited to hook-covered prefixes, docs left to CI (step 5).
- M3 (ending order): Suggested next, then at most one question; section count,
  "decides nothing" and the question rule updated (step 3); Open Question closed.
- S4: trigger phrases first, quoted valid YAML, guard (a) reads the
  description line only (steps 2, 5).
- S5: manual acceptance records whether `~/CLAUDE.md`/NOW.md answered, reports
  it, edits nothing (step 9).
- S6: fixed source order; line marks a basis in the proposed inbox sort (step 3).
- S7: morning-status row gets `#386` in Issue; PR note that `/what-next` no
  longer exists (steps 7, 10).
