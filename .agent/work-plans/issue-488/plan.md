# Plan: Sub-roadmaps: a part of a root carries its own goals, design and roadmap, for the workspace and for projects

## Issue

https://github.com/rolker/agent_workspace/issues/488

## Context

A root (the workspace, or a registered project) may have parts that carry their own goals, design and roadmap. Two exist as unmerged drafts: the manifest tool's (`tools/ros-manifest/docs/{roadmap,spec,design}.md`, branch `origin/feature/issue-486`, PR 494; check paths relative to `tools/ros-manifest`) and the workspace's manifest support (`docs/manifest/{design,roadmap}.md`, local branch `feature/issue-487`; check paths relative to the workspace root). Today nothing follows a pointer: `sitrep_root.sh` returns one roadmap (first of `docs/roadmap.md`, `ROADMAP.md`), `sitrep_checks.sh` reads one (`--root`, `--roadmap` are already separate), and `check_design_anchors.sh` treats any prefix before `docs/design.md#` as a citation of the root's design, so `tools/ros-manifest/docs/design.md#x` would be checked against the root's headings. In the 487 draft the main roadmap points at the sub-roadmap in prose, in its Roadmap tables, not in `## Direction`, so no script can read it.

Owner decisions (checkpoint 2026-11-18, `progress.md`): "Part owns its inside" (the root's design describes a part only by what crosses its boundary and points at the part's design, the one current picture of that part; applies to both examples as written); the rule is written in a new ADR beside ADR-0017, for the workspace and for projects. The Issue Review's other actions are the instructions below.

Mechanism decisions made here (listed for veto, not owner questions):

- Pointer format: a third table kind in the root's `## Direction` section, header `| Sub-roadmap | Root |`. Row: cell 1 the sub-roadmap file, cell 2 the directory its check paths are relative to (what `--root` gets); both are paths relative to the pointing roadmap's root, written in backticks or bare; an empty Root cell means `.`. The 486 case is `tools/ros-manifest/docs/roadmap.md` / `tools/ros-manifest`; the 487 case is `docs/manifest/roadmap.md` / `.`. Both must resolve (symlinks followed) inside the pointing root, and the file must lie inside its Root. Same grammar for the workspace and a project: the sit-rep gets the root and roadmap from `sitrep_root.sh` as now, so no project-specific code path.
- Depth: one level. A sub-roadmap's own pointer table is not followed; it is reported, so it is not silently ignored. Two real cases justify one level ("Only what's needed").
- Broken or circular pointer: reported, never skipped, never fatal to the root's rows. Missing target, unreadable target, path outside the root, file outside its Root, nested pointer (not followed) and a target that resolves to the pointing roadmap itself or to a roadmap already followed (a cycle or duplicate) each give a `part` row with a reason; the sit-rep prints them under Problems.
- Totals: sub-roadmap lines do not count in the root's `lines`/`deferrals` totals. The run record's counts compare one root across runs, and a part's progress is the part's; the report shows the part's own counts beside its rows. The record format is unchanged.
- Citation form for a part's design: `<path>/design.md#<fragment>` where `<path>` is the part's directory relative to the citing root (`tools/ros-manifest/docs/design.md#x`, `docs/manifest/design.md#x`). The root's own design is cited, as now, `docs/design.md#x` (with the existing `$WS_ROOT/` and relative forms, nothing else before `docs/`). Any other path before `design.md#` is a part citation, resolved against that file's headings with the same `slug()` rule; a missing file or heading is an error. A part in another repository is not cited by anchor (cited by URL, not checked); a pointer across repos is out of scope until a case exists (deferral).
- Serves for work inside a part: the root goal it serves (README section) plus the part's own goal, citing the part's design section by the form above. Neither draft names a README goal, so the rule goes in the review skills and the ADR, not in the drafts.

## Approach

Commits in this order, each atomic and each with its tests:

1. **Decision record and design text, with the pointer format fixed first.** New `docs/decisions/0022-a-part-owns-its-inside.md` (numbering: highest existing is 0021): a part of a root (workspace or project) may carry its own goals, design, roadmap; the root's design describes the part only by what crosses its boundary and points at the part's design, which is the one current picture of that part; ADR-0017's "one current picture" holds per owner (root, part); pointer and citation forms; one level; never forced on a project. It scopes ADR-0017 and amends nothing (ADR-0008). In `docs/design.md`: Documentation layers (Now: what a part is, the Direction pointer table, the boundary; Target: relate to the proposed per-project mapping, OQ-1), the Direction row (sit-rep follows pointers), Rules table row for the new check, Decision register row for 0022, Change log row. Check the section's line budget.
2. **Sit-rep checks follow the pointer.** `sitrep_checks.sh`: parse the `Sub-roadmap | Root` table; for each valid pointer run the same checks with `--root <pointing root>/<Root>` against the sub-roadmap, one level; new row kinds `part` (the pointer: item = the sub-roadmap path, result `true` read / `unknown` unreadable / `unchecked` broken, check = the reason) and `subline` / `subdeferral` (item prefixed by the sub-roadmap's own path, so the report marks the next step by path name); `--no-follow` for callers that want the root only. `--summary` and `--summary-from` count `line` and `deferral` only; extend the row validator for the new kinds; update the header grammar. Extend `test_sitrep_checks.sh`: synthetic roots with (a) a part whose Root is `.`, (b) a part whose Root is its own directory with a relative `file-exists`, (c) missing target, (d) unreadable target, (e) path outside root, (f) self or repeated pointer, (g) a nested pointer, (h) totals unchanged by sub rows, (i) `--summary-from` over saved rows with the new kinds.
3. **Sit-rep skill and discovery.** `.claude/skills/sitrep/SKILL.md`: show a part's rows under its path name, take the next step as the first Direction line not true in the root and, when the root has none left, or when asked, the part's; print `part` problems under Problems; the run record keeps the root's counts only. Confirm and, if needed, make `update_roadmap.sh` (finds `ROADMAP.md`, `docs/ROADMAP.md`, `docs/roadmap.md`) and `discover_governance.sh` ignore a sub-roadmap, with a test in `test_update_roadmap.sh` (a part roadmap with a `#N` row is not edited, since a Direction-format sub-roadmap holds no status). Add the pointer table to `docs/roadmap.md`'s Format paragraph.
4. **Anchor check covers a part's design.** `check_design_anchors.sh`: split the citation scan into root citations (prefix empty, `$WS_ROOT/`, or the relative forms) and part citations (any other path); build the heading slug set per resolved file; check the part design's own `](#frag)` links too if the per-file refactor allows it cleanly. Extend `test_design_anchors.sh`: `tools/ros-manifest/docs/design.md#x` resolves against the part's headings and is not resolved against the root's (a fragment present only in the root fails, one present only in the part passes); missing part file; missing heading; empty and malformed fragments; the `docs/manifest/design.md#x` form. Update the script's header and the `check-design-anchors` hook's file filter if it should run when a part design changes.
5. **Reviews can cite a part's design.** `review-issue`, `review-plan`, `plan-task` (Serves and Design Picture wording, including that the design section to update may be the part's), and `.agent/knowledge/principles_review_guide.md`: accept `<part>/docs/design.md#<section>` and the rule above for the goal. Regenerate any generated skill copies (`make generate-skills`) if these skills are mirrored, and check the plugin delivery path (ADR-0018) for a second copy.
6. **Project session.** Tests with a synthetic registered project (the sandbox style of `test_sitrep_root.sh`: sandbox workspace, sandbox registry, `HOME` redirected, no gh call, no network): a project whose `docs/roadmap.md` (and one using `ROADMAP.md`) carries a pointer, run through `sitrep_root.sh --dir <project>` and then `sitrep_checks.sh --root --roadmap` as the skill does; a project with no Direction section and one with no pointer are unchanged. Add the same part to a workspace-session case. Update `onboard-project` / `audit-project` text only if they enumerate the Direction tables (grep first).
7. **Manifest acceptance, conditional.** The third acceptance bullet cannot be shown until #486 and #487 merge. When both are on `main`, add the two pointer rows to the root's `docs/roadmap.md` Direction section and run the sit-rep: it must report each part's next step through the pointer, and `check_design_anchors.sh` must pass with a citation into each part's design. If either is not merged when the rest is done, this commit is left out, the PR says so, and the issue keeps the bullet open; the synthetic tests of steps 2, 4 and 6 are the acceptance that does not depend on them. Once merged, the 487 prose pointers in the Roadmap tables stay (they are the reader's link; the Direction row is the machine's).

## Files to Change

| File | Change |
|------|--------|
| `docs/decisions/0022-a-part-owns-its-inside.md` | New ADR, scopes ADR-0017 |
| `docs/design.md` | Documentation layers, Direction row, Rules, Decision register, Change log |
| `docs/roadmap.md` | Format paragraph: the pointer table; (conditional step 7) two pointer rows |
| `.agent/scripts/sitrep_checks.sh` | Follow pointers, new row kinds, `--no-follow`, header grammar |
| `.agent/scripts/check_design_anchors.sh` | Root vs part citations, per-file slug set, header |
| `.agent/scripts/update_roadmap.sh`, `.agent/scripts/discover_governance.sh` | Only if the tests show a sub-roadmap is mishandled |
| `.agent/scripts/tests/test_sitrep_checks.sh`, `test_sitrep_root.sh`, `test_design_anchors.sh`, `test_update_roadmap.sh` | Cases listed above |
| `.claude/skills/sitrep/SKILL.md` | Part rows, problems, next step, totals |
| `.claude/skills/review-issue/SKILL.md`, `review-plan/SKILL.md`, `plan-task/SKILL.md`, `.agent/knowledge/principles_review_guide.md` | Serves and Design Picture accept a part's design |
| `.agent/knowledge/script_reference.md` | Entries for the changed scripts |
| pre-commit config | Hook file filter for the anchor check, if needed |

`AGENTS.md` and `CLAUDE.md` are not touched (ask first).

## Prior Art

Existing: `sitrep_checks.sh` already separates `--root` and `--roadmap`, and its table-by-header parsing takes a third table without new machinery; `check_design_anchors.sh`'s `slug()` is reused per file; the sandbox style of `test_sitrep_root.sh` is reused for the project case. The two drafts (#486, #487) show the pointer must carry the root. Outside practice: monorepo tools (Cargo workspaces, Bazel packages) let each package keep its own manifest with the root listing members and resolving paths against the member's directory; the Root cell is the same idea. Rejected: following pointers recursively (no case needs it), and counting part lines in the root's totals (mixes two units of progress).

## Serves

"How I interact with the system and keep track of what's relevant" (the sit-rep follows the pointer) and "Keep one current design" (a part's design is the one picture of the part) — `docs/design.md#documentation-layers`

## Design Picture

Yes. `docs/design.md#documentation-layers` changes in this PR (what a part is, the pointer table, the boundary, one level), with the Direction row, the Rules table, the Decision register (new ADR-0022) and the Change log; `docs/design.md#sessions-and-roots` is touched only if the project-session wording needs a line. The Target block's proposed per-project mapping of the seven roles (OQ-1) is related, not answered: a part with its own documents is one instance of it, and the row says so without closing OQ-1.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | ADR-0022 gives each owner one current picture; the root cites the part's, never copies it; ADR-0017 scoped, not edited |
| Put each thing at the level it applies to | Part's design owns the part; the root keeps how it fits and the pointer |
| Enforcement over documentation | The pointer is machine-read; broken, circular and nested pointers produce `part` rows; the anchor check covers part citations |
| Only what's needed | One level; no cross-repo pointers; no change to the run record |
| Ask about what matters, and show how much | The boundary and the ADR were the owner's (answered); mechanism choices above are listed for veto |
| Verify before claiming | Header claims re-read from `sitrep_checks.sh`, `sitrep_root.sh`, `check_design_anchors.sh`; manifest cases read with `git show`; each skill and doc statement is checked against the finished scripts |
| Tests with the fix | Each script change lands with its synthetic-project test; no test depends on a real hosted project |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0017 | Yes | A second design document gets its stated boundary in ADR-0022; `docs/design.md` updated in the same change |
| ADR-0008 | Yes | ADR-0017 is not edited; ADR-0022 is a new record that scopes it |
| ADR-0001 | Yes | New ADR, same format and status header |
| ADR-0013 | No | No new progress entry type |
| ADR-0011 / ADR-0019 | No | Sit-rep goes through `sitrep_root.sh`, not the adapter |
| ADR-0018 | Watch | Skill edits may have a delivered copy; checked in step 5 |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Direction section grammar | `sitrep_checks.sh` header, `docs/roadmap.md` Format paragraph, sitrep skill | Yes (steps 2, 3) |
| Row kinds | `--summary-from` validator, skill's row handling, tests | Yes (step 2) |
| Anchor citation rule | Script header, tests, hook filter, any existing citation with a non-root prefix | Yes (step 4; grep for existing `*/docs/design.md#` first and fix or whitelist) |
| Serves wording | review-issue, review-plan, plan-task, principles review guide | Yes (step 5) |
| ADR added | Decision register, ADR index if one exists, design Change log | Yes (step 1) |
| Script changes | `script_reference.md` | Yes |
| Pointers in `docs/roadmap.md` | Needs #486 and #487 on `main` or the pointer reports broken | Conditional (step 7) |
| Cross-repo pointer (tool moves to its own repo) | Pointer grammar | No: deferral until a case exists |

## Open Questions

- None for the owner. Veto-able mechanism choices: one level of nesting; part lines excluded from the root's totals; `part` rows reported as Problems; cross-repo pointers deferred.

## Estimated Scope

One PR in seven commits (step 7 conditional on #486 and #487). If the sit-rep part (steps 2 and 3) grows past review size, split it into a sub-issue after the ADR and design text land.
