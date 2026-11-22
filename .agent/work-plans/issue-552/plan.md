# Plan: brainstorm in project sessions, with its results saved for the design discussion

## Issue

https://github.com/rolker/agent_workspace/issues/552

## Context

`brainstorm` is a workspace-scoped skill: no `session_scope`, so the plugin does not ship
it, and its Step 1 reads cwd-relative workspace paths (`.agent/knowledge/...`,
`docs/design.md`). It also says "output stays in the conversation" and "Don't create
issues". `design-discussion` (unmerged, branch `feature/issue-370`) Step 1 reads "any
brainstorm results recorded on the anchor issue" but does not say how one is recognised.
This change makes `brainstorm` work from any session root and gives its result a saved form
the design discussion can find. Accepted constraints are the `## Issue Review` Actions and
the newest `## Checkpoint` (ship apart from #331; offer an anchor issue only on a yes; no
digest writing).

## Approach

1. **Frontmatter and root** — in `.claude/skills/brainstorm/SKILL.md` add
   `session_scope: both`, and a `## Workspace root` section with the
   `WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"`
   idiom, worded as in `review-issue` / `design-discussion`.
2. **Step 1 reads by root** — workspace sources via `$WS_ROOT/...` (`.agent/knowledge/research_digest.md`,
   `docs/principles.md`, `AGENTS.md`, `docs/design.md`, `docs/decisions/`, the roadmap). In a
   project session read the project's own digest at `.agents/workspace-context/research_digest.md`
   (the path `design-discussion` names; #335/#551 may move it), `.agents/README.md`, and its
   own design/principles/ADRs. Drop the `.agent/project_knowledge/` symlink paths unless they
   still exist in the code (verify when editing). Every source is optional; the output
   says which were read and which were absent. For a topic about a part, also read the
   part's own `design.md` (ADR-0022).
3. **Save step (new Step 4)** — offered after presenting findings, written only on the user's yes:
   - ask for the anchor issue; if none, offer to open one, on a yes only (as `design-discussion` does);
     if the project uses no issues or `gh` is unavailable, stay conversation-only and say so;
   - the comment opens with `## Brainstorm: <topic>`, the stated contract for `design-discussion` Step 1;
   - signed: identity set in the same command chain (`set_git_identity_env.sh --agent claude-code "<model id>"`),
     body written to a scratchpad file, posted with `gh issue comment <N> [-R <owner/repo>] --body-file`,
     file removed; ends with the `Authored-By` / `Model` block;
   - never a `progress.md` entry (it derails `/run-issue` routing; #544) and never a write to the digest (`research` owns that, #331);
   - cites the digest entries used;
   - public-project check before posting: compare the text against the project's `.agents/README.md`
     rules (e.g. no site data); show it first and post only after that and the yes.
4. **Reword** the Overview ("output stays in the conversation unless the user asks to save it"
   becomes the save step), the lifecycle-position text, and the "Don't create issues" guideline
   (no issue without a yes; the save is the one tracked write).
5. **Regenerate the plugin list** — `make generate-user-tier-skills`; commit `.claude-plugin/plugin.json`
   (14 to 15 entries).
6. **ADR-0018 count** — line 85 says "(13 skills when this ADR was written)": a dated snapshot, already
   differing from the 14 shipped today, so leave it unchanged. Verify the wording again at edit time.
7. **Verify** — run `.agent/scripts/tests/test_skill_paths.sh` (flags workspace-relative paths in
   `session_scope: both` skills), `test_plugin_manifest.sh`, `test_user_tier_install.sh`, and
   `make lint`. Read `.agent/knowledge/skill_workflows.md` and `.agent/AGENT_ONBOARDING.md` for a
   brainstorm scope statement; edit only if one is now wrong.
8. **Follow-up, not in this PR** — after #370 merges, change the "Before this" paragraph in
   `design-discussion` ("neither is available yet (#331, #552)") to say `brainstorm` is available
   in a project session. File nothing now; record it in the PR description.

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/brainstorm/SKILL.md` | Frontmatter, `WS_ROOT`, root-relative reads, save step, rewording |
| `.claude-plugin/plugin.json` | Regenerated; adds `brainstorm` |
| `.agent/knowledge/skill_workflows.md`, `.agent/AGENT_ONBOARDING.md` | Only if they state brainstorm's scope |

## Prior Art

`design-discussion` (branch `feature/issue-370`): Step 0 anchor-issue rule, Step 7 yes-per-write,
signed comment via `--body-file`, identity-first rule, `WS_ROOT` idiom. Taken as is. `review-issue`:
`## Workspace root` section. Taken. Rejected: a new progress.md entry type (#544 routing problem,
ADR-0013) and writing to the digest (overlaps `research`). Nothing new mechanism-wise.

## Serves

Flexibility (a skill works from any session root): `docs/design.md#sessions-and-roots`.

## Design Picture

No change to the design picture. One more skill ships through the plugin (ADR-0018); no new mechanism.
Check `docs/design.md` for a skills list naming brainstorm's scope while editing (the greps for
"brainstorm" in design.md found none).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | Item 3 of the issue (design-discussion reading results) is already in #370; not redone |
| Put each thing at the level it applies to | Result goes on the anchor issue in the owning repo (`-R`); no digest writes |
| Ask about what matters | Every tracked write (comment, issue) shown first and made on a yes |
| Leave in a project only what it chose to carry | Public-project check against `.agents/README.md` before posting |
| A change includes its consequences | Plugin list regenerated; ADR count checked; tests run |
| Verify before claiming | Comment cites digest entries; PR claims tied to test runs |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0016 | Yes | `WS_ROOT` idiom with fallback |
| ADR-0018 | Yes | `session_scope: both`, regenerated list, count left as a dated snapshot |
| ADR-0013 | By exclusion | No progress.md entry; issue comments only |
| ADR-0022 | Watch | Part topics read the part's design |
| ADR-0010 | Watch | `gh` unavailable means conversation-only |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `session_scope` | `.claude-plugin/plugin.json` | Yes |
| brainstorm scope | ADR-0018 count, onboarding/workflow docs | Checked, edit only if stale |
| #370 contract | `design-discussion` pointer line | No, follow-up after #370 merges |

## Open Questions

- None blocking. Veto points recorded in the Checkpoint: ship apart from #331; digest path until #551 settles.

## Estimated Scope

Single PR.
