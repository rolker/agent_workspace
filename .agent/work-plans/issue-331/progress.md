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
