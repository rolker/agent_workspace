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
   `.claude/skills/sitrep/SKILL.md` so "what's next?", "what should I work
   on?" and "where are we?" trigger it, still stating it reads and writes one
   run-record line. Adjust "What it is" to say it replaces `what-next`.
3. **Suggested next line** — add a fifth report item, "Suggested next", as the
   last line: one item and why, drawn only from facts this run read (due
   deferral, false Direction line, inbox "now" bin, in-flight work). It
   replaces "at most one question" as the ending; the single question stays
   allowed after it. Keep the printed note that registered project roots are
   not read, so a project session does not mistake it for a project answer.
4. **Test list** — remove `what-next` from the scope loop in
   `.agent/scripts/tests/test_skill_paths.sh`; add `sitrep` to it (it declares
   `both`).
5. **Mechanical guards** (A1) in `test_skill_paths.sh`: (a) the sitrep
   `description` contains the trigger phrases; (b) `.claude/skills/what-next`
   does not exist; (c) no live file names `what-next`: `git grep -l what-next`
   excluding `.agent/work-plans/` and the digest (history records).
6. **Roadmap** — rewrite scenario 4's "First form" paragraph (line ~95) to say
   `/sitrep` answers "What's next?" and replaced `what-next` (#389); extend the
   sit-rep row; mark the "Morning status / standup skill" row done, covered by
   the sit-rep (A5).
7. **Digest note** — dated note under A5 in
   `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`: skill deleted
   2026-10-13 (#389); the original text stays.
8. **Verify** — run `.agent/scripts/tests/run_script_tests.sh`; in a scratch
   HOME, install the user tier with `what-next` linked, rerun, and confirm
   the symlink is removed and `--check` is clean (A4). Manual acceptance: in a
   fresh session at the workspace root ask "what's next?" and record the
   prompt and which skill fired.
9. **PR text** — list what was dropped (project-roadmap probe,
   `--workspace-only`/`--project-only`, ranking, stale-row and needs-ticket
   detection, declined by the owner), and the one-time `--check` drift on
   machines that had it linked.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/what-next/` | Delete |
| `.claude/skills/sitrep/SKILL.md` | Description, "What it is", Suggested next line |
| `.agent/scripts/tests/test_skill_paths.sh` | Skill list; three new guards |
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
| Skill removal | `test_skill_paths.sh` list | Yes |
| Skill removal | Roadmap, digest note | Yes |
| Skill removal | Installed symlinks on other machines | Yes, PR note; installer rerun |

## Open Questions

- Does the end-of-report "at most one question" rule stay after the new
  Suggested next line? Plan assumes yes, with the suggestion last-but-one.

## Estimated Scope

Single PR.
