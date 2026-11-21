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
