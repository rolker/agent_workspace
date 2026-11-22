# Plan: research skill is not available in project-rooted sessions (no session_scope; workspace-relative paths; workspace default scope)

## Issue

https://github.com/rolker/agent_workspace/issues/331

## Context

`.claude/skills/research/SKILL.md` has no `session_scope:`, writes bare `.agent/scripts/...`
paths, defaults to the workspace digest, and says the project digest "lives in the manifest
repo". Owner decisions (progress.md `## Checkpoint`, 2026-11-21): the project digest stays at
`.agents/workspace-context/research_digest.md`, read through #551's setting once it exists
(#551's setting is not built here); `research` keeps its worktree rule (a project digest
update needs a project issue; no `--skill research --type project`, no `AGENTS.md` change,
which `worktree_create.sh` line 415 already enforces); ships apart from #552. Project
lessons (ice_cube, 2026-11-21) are folded in below. Mechanism text names no project (ADR-0003).

## Approach

1. **Scope and paths in `.claude/skills/research/SKILL.md`** — add `session_scope: both` to the
   frontmatter. Add the `WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"`
   preamble (same text as `plan-task`) and write every script as `$WS_ROOT/.agent/scripts/...`
   (worktree create/enter, `merge_pr.sh`).
2. **Default scope follows the session root** — add a "Scope" step that runs
   `$WS_ROOT/.agent/scripts/session_root.sh` (prints `type=workspace|project`); no `--scope`
   means the session root's digest. In a workspace session behaviour is unchanged. In a project
   session `--scope project` is the default and `--scope workspace` stays available for
   *reading and surveying*, but a project session changes only its own root (session-root
   rule): a workspace-digest write from a project session stops and hands the result back as
   an inbox line / workspace issue instead of creating a workspace worktree. (Decision made
   in this plan from the session-root rule in `session_root.sh`; listed in Open Questions
   for veto.) Usage block and `description` updated (drop "lives in the manifest repo").
3. **Digest location, stated once** — a "Project digest location" paragraph: the default is
   `.agents/workspace-context/research_digest.md` in the project's own repo, for every project
   type; when #551 provides a "where is X for this project" setting the skill reads the path
   through it and falls back to this default when unset. Not built here; the follow-up reader
   change is named in the PR description (#331 is a reader of #551).
4. **Worktree rule, made explicit** — project scope needs a project issue and
   `--issue <N> --type project --project <name>` worktree; `--skill research` is workspace
   only (state the reason: `worktree_create.sh` rejects `--skill research --type project`).
5. **Project-rules check before committing a project digest** — before commit, read the
   project's `.agents/README.md` (also an AGENTS.md "Always" rule) for rules about what may
   be committed (e.g. public repo, no site data). When a rule requires it: draft the report
   in a location the project ignores/keeps private, make the entries generic, commit only
   those. No rule, no ceremony (Safeguard earns its cost).
6. **No real-location web queries** — a guideline and a step-2 line: search and any
   delegated research agent get generic queries; no real coordinates, bounding boxes, site or
   address names, unless the owner approves that query; pass this rule in every sub-agent
   prompt.
7. **Sources-pending mark** — entries need a link, except one marked
   `**Sources**: pending` when the source report had none; `--refresh` treats a pending entry
   as first in line to get links; format example and Guidelines updated.
8. **Tests** — in `.agent/scripts/tests/test_skill_paths.sh`: add `research` to the `both`
   list (its path scan then fails any bare `.agent/scripts/` reference, giving the WS_ROOT
   coverage); add string guards that SKILL.md contains the `session_root.sh` scope step, the
   `--skill research` workspace-only sentence, the `.agents/README.md` check, the
   no-real-location rule and the sources-pending mark. Add a case to
   `test_user_tier_guard.sh` or the plugin-list test (check which asserts the shipped skill
   set; `user_tier_install.sh --list-skills`) that `research` is listed. Add a project-rooted
   case for `session_root.sh --dir <tmp registered project>` returning `type=project` if no
   existing test covers it (check `test_session_start_layer.sh` first). Hermetic, no gh/network.
9. **Issue body addendum** (a draft for the owner; this phase posts nothing). Replace the
   "Blocks: rolker/geozui4d#7" line with "No longer blocks rolker/geozui4d#7 (owner
   correction); makes it convenient." Replace point 4 with: "Decided 2026-11-21: `research`
   keeps its worktree rule. `worktree_create.sh` rejects `--skill research --type project`; a
   project digest update needs a project issue. No allowlist or `AGENTS.md` change." Add to
   Acceptance: project-rules check, no real-location queries, sources-pending mark, a
   project-rooted run defaults to the project digest with `--scope workspace` available.
10. **Design and consequences** — see below; run `make lint`/`run_script_tests.sh` for the
    touched tests; `brainstorm`/`sitrep` keep reading their paths (unchanged location).

## Files to Change

| File | Change |
|------|--------|
| `.claude/skills/research/SKILL.md` | Steps 1-7 |
| `.agent/scripts/tests/test_skill_paths.sh` | `research` in the `both` list; text guards (step 8) |
| `.agent/scripts/tests/test_user_tier_guard.sh` (or the plugin-list test) | `research` shipped to project sessions |
| `docs/design.md` Change log | Only if the Sessions-and-roots or Registry text changes (see Design Picture) |

## Prior Art

`plan-task`, `sitrep` and `review-issue` already carry `session_scope: both`, the `$WS_ROOT`
idiom and `session_root.sh`/`sitrep_root.sh` root resolution: taken as is. A manual emulation
by a project session (rolker/ice_cube#17/#18, from the issue comments) shows the digest path
and the three lessons; taken. Rejected: `--skill research --type project` (owner decision,
and the script forbids it); a new digest-location setting (#551 owns it).

## Serves

Light touch on projects and Easy to use (README `## Workspace goals`);
`docs/design.md#sessions-and-roots`, with `docs/design.md#registry-and-adapters` untouched
because the location setting is #551's.

## Design Picture

No change to the design picture: `docs/design.md` mentions research only in the Direction row,
the Problems paragraph and the skill-worktree merge bullet; none states a digest location or
the skill's scope. If the implementer finds a sentence that does, edit that section and add a
Change log row in the same PR (ADR-0017).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Put each thing at the level it applies to | Location stated once, default only, read through #551 later |
| Keep one current design | Checked above; update if a sentence is found |
| Ask about what matters | Owner answered the location and worktree questions; no `AGENTS.md` edit |
| Safeguard earns its cost | The privacy check is "read the project's rules", not a ceremony |
| Verify before claiming | Tests assert the script behaviour and skill text, not the issue's old claim |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0016 | Yes | `$WS_ROOT` idiom, `session_root.sh` default scope, `session_scope: both` |
| ADR-0018 | Yes | `both` ships the skill via the plugin; test lists it |
| ADR-0002 | Yes | Worktree for every write; no branch switching |
| ADR-0003 | Yes | No project named in skill text |
| ADR-0011 | Watch | Location is a default now, a setting later (#551) |
| ADR-0017 | Watch | See Design Picture |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Skill `session_scope` | `test_skill_paths.sh` list, plugin skill list | Yes |
| Skill description line | Any listing quoting it | Yes (grep before commit) |
| Digest location | `brainstorm`, `sitrep` paths | No change: location unchanged; #551 follow-up |

## Open Questions

- Workspace-scope write from a project session: this plan refuses (hands back), per the
  session-root rule. Veto if the owner wants a workspace worktree to be allowed there.
- #331 ships apart from #552; #552 reads the same default path, so no ordering needed.

## Estimated Scope

Single PR, one skill file and test edits (about 8 atomic steps, 2-3 commits).
