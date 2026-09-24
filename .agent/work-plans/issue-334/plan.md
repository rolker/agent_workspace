# Plan: Docs reorganisation: move planning docs into docs/ with lowercase names; ARCHITECTURE.md becomes docs/design.md; discovery accepts both spellings

## Issue

https://github.com/rolker/agent_workspace/issues/334

## Context

Planning docs are split between the root (`ARCHITECTURE.md`) and `docs/`
(`ROADMAP.md`, `PRINCIPLES.md`) with shouting-case names — not where an
open-source reader or a skill would look. This is a **mechanical** move: no
content is rewritten (companion issue #335 owns that). Three files move with
`git mv` so history follows:

- `ARCHITECTURE.md` → `docs/design.md`
- `docs/ROADMAP.md` → `docs/roadmap.md`
- `docs/PRINCIPLES.md` → `docs/principles.md`

Confirmed against source (corrections from the Issue Review / owner
checkpoint, both already folded in):
- `discover_governance.sh` and `.agent/templates/project_governance.md` look
  for `PRINCIPLES.md` and `ARCHITECTURE.md` only — **not** `ROADMAP.md`.
- Nine skills read the principles (`docs/PRINCIPLES.md`):
  `audit-workspace`, `gather-project-knowledge`, `audit-project`, `plan-task`,
  `review-code`, `review-plan`, `triage-reviews`, `brainstorm`, `review-issue`.
- No ADR mentions any of these three paths — no ADR References work.
- `discover_governance.sh scan_scope()` runs once over the workspace root
  (`scope="workspace"`) and once over `project/` (`scope="project"`) — the
  same function, so a fix here must work for both call sites.

Concurrent work: issue #320 ("cross_model_review: run Gemini/Codex at the
Standard tier...") is in flight in another session and is expected to touch
one `AGENTS.md` row and possibly `review-code`/`address-findings` `SKILL.md`.
Issue #328 (retire the Bash tool-mapping hook) is also in flight and edits
CLAUDE.md's "Enforced by hook" paragraph and tool-mapping table, plus one
AGENTS.md script-table row. No PR exists yet for either. Merge `main` into
this branch before `review-plan` and again before `review-code` to avoid
silently clobbering that work if it lands first — this plan only touches
CLAUDE.md's and AGENTS.md's `## References` list, separate hunks from both
#320 and #328, so conflicts are unlikely but the merges must still happen.

**Ask-First CI change (owner-approved 2026-09-23)**: `.github/workflows/validate.yml`
hard-requires the root `ARCHITECTURE.md` in its `validate-documentation` job
(`required_files="README.md ARCHITECTURE.md AGENTS.md"` at line 73). After the
`git mv`, every PR — this one and every later one — would fail that job unless
this line changes to `docs/design.md`. The owner has already approved this
specific edit (Ask-First per AGENTS.md, since it changes CI configuration).

## Approach

1. **Move the three files with `git mv`** (separate commit, so history is
   clean and the diff is reviewable as a pure rename):
   - `git mv ARCHITECTURE.md docs/design.md`
   - `git mv docs/ROADMAP.md docs/roadmap.md`
   - `git mv docs/PRINCIPLES.md docs/principles.md`

2. **Fix `discover_governance.sh` so the workspace's own scan still finds its
   architecture doc and principles doc after the move**, and so a project can
   use either spelling/location:
   - Add `check_file "$dir/docs/design.md" architecture "$scope"` alongside
     the existing `check_file "$dir/ARCHITECTURE.md" architecture "$scope"`.
   - Add `check_file "$dir/docs/principles.md" principles "$scope"` alongside
     the existing `PRINCIPLES.md` / `docs/PRINCIPLES.md` checks.
   - Do not touch `ROADMAP.md` handling — this script never looked for it.
   - `.agent/templates/project_governance.md` stays a *suggestion*: leave its
     example layout as-is (it documents one convention among several the
     script now accepts) but add a line noting the lowercase `docs/`
     equivalents are equally discoverable, so the template doesn't read as
     the only sanctioned shape.

3. **Add a discovery test** (none currently exists —
   `find .agent/scripts/tests -iname '*governance*'` is empty). New
   `.agent/scripts/tests/test_discover_governance.sh`:
   - Fixture A (workspace-scope regression guard): run the script with
     `ROOT_DIR` pointed at a sandbox containing `docs/design.md` and
     `docs/principles.md` only (the new workspace shape) and assert both
     rows appear with `scope=workspace`.
   - Fixture B (project, old spelling): sandbox project dir with root
     `ARCHITECTURE.md` and root `PRINCIPLES.md`; assert both are found with
     `scope=project`.
   - Fixture C (project, new spelling): sandbox project dir with
     `docs/design.md` and `docs/principles.md`; assert both are found.
   - `chmod +x` the new script (pre-commit's
     `check-shebang-scripts-are-executable` hook fails otherwise).
   - Wire it into `.agent/scripts/tests/run_script_tests.sh`'s discovery (it
     globs `test_*.sh`, so no registration should be needed — verify during
     implementation that the glob picks it up).

4. **Update the two workspace scripts that reference `docs/ROADMAP.md`
   literally.** The workspace's own file moves, but `merge_pr.sh`'s
   bookkeeping lists and `update_roadmap.sh`'s discovery loop apply to
   project PRs too — a project (or a workspace branch that predates this
   rename) can still legitimately have `docs/ROADMAP.md` on disk. **Add the
   new spelling; never remove the old one:**
   - `.agent/scripts/merge_pr.sh` — line 776
     (`_only_bookkeeping_between ... "ROADMAP.md" "docs/ROADMAP.md"`) and
     line 1097 (`MERGE_PR_CI_BOOKKEEPING_PATTERNS=(".agent/work-plans/*"
     "ROADMAP.md" "docs/ROADMAP.md")`): add `"docs/roadmap.md"` as a new
     entry in both, keeping `"ROADMAP.md"` and `"docs/ROADMAP.md"`
     permanently. Without this, a roadmap-bookkeeping commit against the new
     path would no longer be recognized as bookkeeping-only, forcing a stale
     CI wait or review hold on an otherwise-trivial commit.
   - `.agent/scripts/update_roadmap.sh` — docstring (lines 8, 12) and the
     discovery loop (line 147, `for rel_path in "ROADMAP.md" "docs/ROADMAP.md"`).
     Add `"docs/roadmap.md"` as a third candidate alongside the existing two
     (do not replace either): this script also runs against project repos
     via the adapter, and per the issue's own "don't force a convention on
     projects" principle it should keep finding a project's existing
     uppercase roadmap, not just the workspace's newly-renamed one. Update
     the docstring to list all three candidate paths.

5. **Update `.agent/scripts/tests/test_merge_pr_gate.sh`.** Keep the existing
   `docs/ROADMAP.md` fixtures (lines 629, 1227; line 1212 is a comment) as-is
   — they must keep passing, since the old spelling stays supported — and add
   a new fixture/case per spelling asserting `docs/roadmap.md` is *also*
   treated as bookkeeping-only by both the `_only_bookkeeping_between` gate
   check and the `MERGE_PR_CI_BOOKKEEPING_PATTERNS` walk. Re-run the suite to
   confirm both the existing and new cases pass.

6. **Update `.github/workflows/validate.yml`** (Ask-First CI change,
   owner-approved 2026-09-23): in the `validate-documentation` job, change
   `required_files="README.md ARCHITECTURE.md AGENTS.md"` (line 73) to
   `required_files="README.md docs/design.md AGENTS.md"`. Without this, the
   Validate Documentation job fails on this PR and every PR after it.

7. **Sweep references to the workspace's own files — rename outright.** These
   name the workspace's own root/`docs/` files, so the old spelling stops
   applying anywhere and the reference becomes the new path
   (`docs/design.md`, `docs/roadmap.md`, `docs/principles.md`):
   - Root/instruction files: `README.md`, `AGENTS.md`, `CLAUDE.md`
     (both the inline `docs/`-adjacent references and the `## References`
     list), `.github/PULL_REQUEST_TEMPLATE.md`.
   - `.agent/AGENT_ONBOARDING.md:91` — `[\`../ARCHITECTURE.md\`](../ARCHITECTURE.md)`
     → `[\`../docs/design.md\`](../docs/design.md)` (relative link from
     `.agent/`, not the bare `ARCHITECTURE.md` form used elsewhere).
   - `.agent/knowledge/principles_review_guide.md` — references the
     workspace's own principles file.
   - Four skills whose `docs/PRINCIPLES.md` / `ARCHITECTURE.md` reference is
     explicitly the *workspace's own* copy (verified — each says "workspace
     principles"/"system design" or reads from `docs/`, not a project's
     copy): `.claude/skills/audit-workspace/SKILL.md:31`,
     `.claude/skills/plan-task/SKILL.md:110`,
     `.claude/skills/triage-reviews/SKILL.md:158,206`,
     `.claude/skills/brainstorm/SKILL.md:32,34` (`docs/PRINCIPLES.md` and
     `ARCHITECTURE.md` in the "Load context" list — rename both; lines 36-37
     of the same list are the project-scope equivalents, handled in step 8).
   - `.claude/skills/inspiration-tracker/SKILL.md:251,259` — both write to
     the workspace's own `docs/ROADMAP.md` ("To Consider" section) →
     `docs/roadmap.md`. Leave line 161 alone — it lists `ARCHITECTURE.md` as
     a tracked config file of *other*, external repos being surveyed, not
     this workspace's file.
   - `.claude/skills/what-next/SKILL.md` — reads `docs/ROADMAP.md` for the
     workspace (line 34, `**Workspace**: \`docs/ROADMAP.md\``) → rename to
     `docs/roadmap.md`. Its project-side probe (line 35,
     `**Project**: \`project/ROADMAP.md\``) is project-scope — see step 8,
     not this step.

8. **Sweep references to project-scope files — list both spellings, don't
   rename.** These name a *project's* copy of the file (which this issue does
   not touch), so imposing the new spelling would violate "don't force a
   convention on projects." Update each to list both the existing and the
   workspace-equivalent spelling, e.g. "`PRINCIPLES.md` / `docs/principles.md`",
   "`ARCHITECTURE.md` / `docs/design.md`" — keep the old spelling, add the new:
   - `.claude/skills/audit-project/SKILL.md:80,81,148` — project governance
     coverage table rows for `PRINCIPLES.md` / `ARCHITECTURE.md`.
   - `.claude/skills/review-code/SKILL.md:200` — "Read project `PRINCIPLES.md`
     if it exists."
   - `.claude/skills/review-plan/SKILL.md:176` — "Project `PRINCIPLES.md` if
     it exists."
   - `.claude/skills/review-issue/SKILL.md:120` — "The project repo's
     `PRINCIPLES.md`."
   - `.claude/skills/brainstorm/SKILL.md:36-37` — project-level equivalents
     list (`project PRINCIPLES.md`, `.agents/README.md`, `ARCHITECTURE.md`,
     `docs/decisions/`); add the new spellings alongside (`PRINCIPLES.md` /
     `docs/principles.md`, `ARCHITECTURE.md` / `docs/design.md`). Line 32
     (`docs/PRINCIPLES.md`) and line 34 (`ARCHITECTURE.md`) earlier in the
     same list are the workspace's own files — handled in step 7, not here.
   - `.claude/skills/gather-project-knowledge/SKILL.md:112` — "Project-level
     principles (from any repo's `PRINCIPLES.md`)."
   - `.agent/knowledge/review_depth_classification.md:98` — governance-file
     tier row currently reads `docs/PRINCIPLES.md`, `PRINCIPLES.md` (applies
     to project diffs); add `docs/principles.md` alongside without dropping
     either existing entry. Leave `ARCHITECTURE.md` out of this row unless
     verified during implementation that architecture docs belong in the
     same tier — don't add `docs/design.md` speculatively.
   - `.claude/skills/what-next/SKILL.md:35,38,44` — project roadmap probe
     currently only `project/ROADMAP.md`. Match `update_roadmap.sh`'s three
     candidates: also check `project/docs/ROADMAP.md` and
     `project/docs/roadmap.md`, keeping `project/ROADMAP.md` as the first
     candidate. Update the "no ROADMAP.md found" message (line 38) and the
     read-loop description (line 44) to reflect all three.

9. **Fix `docs/design.md`'s own self-references, in a commit after the pure
   rename (path fixes, not the "content unchanged" of step 1).** The moved
   file's directory-tree diagram and prose describe the *pre-move* layout:
   - Line 47 (`ARCHITECTURE.md        # This file`) → `docs/design.md`, and
     move that line to sit under the `docs/` entry in the tree, next to line
     52 (`PRINCIPLES.md` → `docs/principles.md`, already shown under `docs/`
     in the tree).
   - Line 222 (`**PRINCIPLES.md**: Seven guiding principles in
     \`docs/PRINCIPLES.md\``) → `docs/principles.md`.
   - `docs/roadmap.md:340` (`AGENTS.md / PRINCIPLES.md` prose, in a historical
     "governance wording regression tests" idea entry) — leave unchanged
     intentionally; it's a design-idea description, not a live path
     reference, and rewriting past idea entries misstates their original
     wording. Record this explicitly as "checked, left as written," not an
     oversight.

10. **Exemptions — do not rewrite**:
    - ADR bodies (`docs/decisions/*.md`) — none currently mention these paths
      (confirmed by grep), so this is a no-op guard, not active work.
    - `.agent/knowledge/inspiration_*_digest.md` (15 files) — historical,
      factual statements about *other* repos' files; rewriting them would
      misstate what those snapshots said.
    - `.agent/work-plans/issue-<N>/{plan.md,progress.md}` for every `N != 334`
      — point-in-time records of past plans/reviews; leave as written.
    - `docs/roadmap.md:340` — see step 9, checked and intentionally left.

11. **README fixes**:
    - `## Documentation` list: update the three links
      (`docs/design.md`, `docs/roadmap.md` — currently absent from the list,
      leave that absence alone, out of scope — `docs/principles.md`).
    - Opening line "Manages one external project repository" is factually
      stale: `ARCHITECTURE.md` (soon `docs/design.md`) itself describes
      multi-project support (`project/` legacy symlink *and/or* named
      projects under `projects/`). Reword to match current capability
      (e.g. "Manages one or more external project repositories") — this is
      the one content correction the issue explicitly allows ("fix only the
      factually wrong opening line... if needed for accuracy"); the Goals
      section stays untouched (companion issue #335's job).

12. **Merge `main` before `review-plan`**, and again before `review-code`, to
    pick up #320 and #328 if either has landed by then — re-resolve any
    conflicts in `AGENTS.md` (both #320 and #328 touch a table row there,
    separate hunks from this plan's `## References` edit) / `CLAUDE.md`
    (#328's "Enforced by hook" paragraph and tool-mapping table, separate
    hunks from this plan's `## References` edit) / `review-code` /
    `address-findings` `SKILL.md` by keeping all changes (path rename +
    #320's and #328's content).

13. **Verify**:
    - `grep -rn 'ARCHITECTURE\.md\|docs/ROADMAP\.md\|docs/PRINCIPLES\.md'`
      across the repo returns only the exemptions from step 10, the
      project-scope dual-spelling mentions from step 8 (which correctly keep
      the old spelling), and the `project_governance.md` template's example
      tree / `discover_governance.sh`'s own old-spelling `check_file` calls
      (intentional — they keep matching projects that still use the old
      names).
    - After each `main` merge in step 12, run
      `git ls-files docs/ROADMAP.md docs/PRINCIPLES.md ARCHITECTURE.md` and
      confirm it prints nothing — a merge of a pre-rename branch that only
      *added* lines to one of the old paths can otherwise recreate the file
      via rename-detection misses.
    - Note in the PR body: contributors on case-insensitive filesystems
      (macOS default) should do a clean pull/checkout of this branch rather
      than merging on top of an existing checkout — a case-only rename
      (`docs/ROADMAP.md` → `docs/roadmap.md`, `docs/PRINCIPLES.md` →
      `docs/principles.md`) can leave a stale-cased file or a dirty working
      tree on those filesystems.

## Files to Change

| File | Change |
|---|---|
| `ARCHITECTURE.md` → `docs/design.md` | `git mv`, content unchanged |
| `docs/ROADMAP.md` → `docs/roadmap.md` | `git mv`, content unchanged |
| `docs/PRINCIPLES.md` → `docs/principles.md` | `git mv`, content unchanged |
| `.agent/scripts/discover_governance.sh` | Add `docs/design.md` and `docs/principles.md` checks alongside the existing old-spelling checks |
| `.agent/scripts/tests/test_discover_governance.sh` (new) | 3 fixtures: workspace new-spelling, project old-spelling, project new-spelling; `chmod +x` |
| `.agent/scripts/merge_pr.sh` | Add `"docs/roadmap.md"` alongside `"ROADMAP.md"`/`"docs/ROADMAP.md"` in both bookkeeping lists (lines ~776, ~1097) — additive, nothing removed |
| `.agent/scripts/update_roadmap.sh` | Add `docs/roadmap.md` as a third discovery candidate; update docstring |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Keep existing `docs/ROADMAP.md` fixtures (lines ~629, ~1227, comment ~1212); add new fixture/case(s) for `docs/roadmap.md` |
| `.github/workflows/validate.yml` | `required_files`: `ARCHITECTURE.md` → `docs/design.md` (line 73) — Ask-First CI change, owner-approved |
| `.agent/templates/project_governance.md` | Note lowercase `docs/` equivalents are equally discoverable |
| `README.md` | Documentation list links + opening line ("one or more external project repositories") |
| `AGENTS.md`, `CLAUDE.md`, `.github/PULL_REQUEST_TEMPLATE.md` | Rename path references (workspace's own files) |
| `.agent/AGENT_ONBOARDING.md:91` | Rename relative link `../ARCHITECTURE.md` → `../docs/design.md` |
| `.agent/knowledge/principles_review_guide.md` | Rename path references (workspace's own file) |
| `.agent/knowledge/review_depth_classification.md:98` | Add `docs/principles.md` alongside existing `docs/PRINCIPLES.md` / `PRINCIPLES.md` entries — dual-spelling, project-scope row |
| `.claude/skills/inspiration-tracker/SKILL.md:251,259` | Rename `docs/ROADMAP.md` → `docs/roadmap.md` (workspace's own roadmap writes); line 161 (`ARCHITECTURE.md` of *other* surveyed repos) untouched |
| 4 skills' `SKILL.md` (audit-workspace, plan-task, triage-reviews, brainstorm:32,34) | Rename `docs/PRINCIPLES.md` / `ARCHITECTURE.md` references (workspace's own files) |
| 6 skills' `SKILL.md` (audit-project, review-code, review-plan, review-issue, brainstorm:36-37, gather-project-knowledge) | Add new spelling alongside old (project-scope references) — dual-spelling, no rename |
| `.claude/skills/what-next/SKILL.md:34` | Rename `docs/ROADMAP.md` → `docs/roadmap.md` (workspace probe) |
| `.claude/skills/what-next/SKILL.md:35,38,44` | Add `project/docs/ROADMAP.md` and `project/docs/roadmap.md` candidates alongside `project/ROADMAP.md` (project-scope probe) |
| `docs/design.md` (post-move) | Follow-up commit: fix self-references at lines 47, 222 (tree diagram + prose) to the new paths |
| `.agent/knowledge/inspiration_*_digest.md` (15 files) | **No change** — exempt, historical |
| `.agent/work-plans/issue-<N>/*` for `N != 334` | **No change** — exempt, historical |
| `docs/roadmap.md:340` | **No change** — checked, historical idea-entry prose, not a live path reference |
| `docs/decisions/*.md` | **No change** — no ADR mentions these paths |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Script + test updates, the CI `required_files` fix, and the reference sweep all ship in the same PR as the moves; the sweep is scoped explicitly rather than left implicit. |
| Workspace vs. project separation | `discover_governance.sh` / `project_governance.md` / `merge_pr.sh` / `update_roadmap.sh` changes are additive (accept both spellings) — no project is forced to rename anything; the reference sweep (steps 7–8) explicitly splits workspace-own renames from project-scope dual-spelling additions so no project-facing skill starts requiring the new names. |
| Only what's needed | Content is not rewritten anywhere except the moved file's own now-stale self-references (step 9) and the README opening-line fix (the one explicitly-permitted factual correction). |
| Documentation accuracy | README's "one external project repository" claim is verified against `ARCHITECTURE.md`'s own multi-project description before editing, not assumed. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0008 (ADR cross-references immutable) | No | No ADR mentions these three paths (confirmed by grep) — no ADR edits, no References-section additions. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `ARCHITECTURE.md` → `docs/design.md` | `discover_governance.sh` architecture check (workspace scope); `.github/workflows/validate.yml` `required_files` (CI hard-requires the old path); `docs/design.md`'s own tree/prose self-references | Yes — steps 2, 6, 9 |
| `docs/ROADMAP.md` → `docs/roadmap.md` | `merge_pr.sh` bookkeeping pattern lists (additive), `update_roadmap.sh` discovery, `test_merge_pr_gate.sh` fixtures, `inspiration-tracker` SKILL.md writes, `what-next` SKILL.md workspace probe | Yes — steps 4–5, 7 |
| `docs/PRINCIPLES.md` → `docs/principles.md` | 4 workspace-scope skills + `principles_review_guide.md` (rename), 6 project-scope skills + `review_depth_classification.md` (dual-spelling add), `discover_governance.sh` | Yes — steps 2, 7–8 |
| Path renames generally | README documentation list, root instruction files, `AGENT_ONBOARDING.md` relative link | Yes — steps 7, 11 |
| Path renames generally | Inspiration digests, historical work-plans, ADR bodies, `docs/roadmap.md:340` idea-entry prose | Explicitly excluded — step 10 |
| Case-only renames merging with pre-existing branches | `git ls-files` re-introduction check after each `main` merge; macOS clean-pull note in PR body | Yes — step 13 |

## Open Questions

None. The issue flagged whether `CLAUDE.md` should move to
`.claude/CLAUDE.md` as an owner decision; the owner has decided (2026-09-23):
**`CLAUDE.md` stays at the root**, unchanged except for the path-reference
updates this issue already needs (step 7). Its eventual retirement — Claude
Code now loads `AGENTS.md` natively — is a separate, later issue that follows
#328 and this one.

## Estimated Scope

Single PR. Three logical commits recommended: (1) the three `git mv` renames
alone — keeps the rename diff reviewable independent of everything else;
(2) script/test/CI updates (steps 4–6) and the reference sweep (steps 7–8,
11); (3) `docs/design.md`'s own self-reference fixes (step 9), kept separate
per the plan review so "content unchanged" in commit 1 stays literally true
and the path-only follow-up in commit 3 is easy to audit on its own.
