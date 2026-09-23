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
No PR exists yet for it. Merge `main` into this branch before `review-plan`
and again before `review-code` to avoid silently clobbering that work if it
lands first.

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

4. **Update the two workspace scripts with literal `docs/ROADMAP.md`
   references**, since the file that path pointed at no longer exists:
   - `.agent/scripts/merge_pr.sh` — line 776
     (`_only_bookkeeping_between ... "docs/ROADMAP.md"`) and line 1097
     (`MERGE_PR_CI_BOOKKEEPING_PATTERNS`): change `"docs/ROADMAP.md"` to
     `"docs/roadmap.md"`. Leave the root-level `"ROADMAP.md"` entry in both
     arrays untouched — that's a separate fallback location for repos (e.g.
     project repos) that keep the roadmap at the root, unrelated to the
     workspace's own file.
   - `.agent/scripts/update_roadmap.sh` — docstring (lines 8, 12) and the
     discovery loop (line 147, `for rel_path in "ROADMAP.md" "docs/ROADMAP.md"`).
     Add `"docs/roadmap.md"` as a third candidate rather than replacing
     `"docs/ROADMAP.md"` outright: this script also runs against project
     repos via the adapter, and per the issue's own "don't force a
     convention on projects" principle it should keep finding a project's
     existing uppercase roadmap, not just the workspace's newly-renamed one.
     Update the docstring to list all three candidate paths.

5. **Update `.agent/scripts/tests/test_merge_pr_gate.sh` fixtures** (lines
   629, 1227 write `$wt/docs/ROADMAP.md`; line 1212 is a comment) to write
   `$wt/docs/roadmap.md` instead, matching the real bookkeeping pattern the
   gate now checks. Re-run the suite to confirm the roadmap-after case still
   passes.

6. **Sweep every remaining reference to the three old paths** (~20 files,
   confirmed by `grep -rln 'ARCHITECTURE.md\|PRINCIPLES.md\|docs/ROADMAP.md'`
   at plan time, excluding the exemptions in step 7):
   - Root/instruction files: `README.md`, `AGENTS.md`, `CLAUDE.md`
     (both the inline `docs/`-adjacent references and the `## References`
     list), `.agent/AGENT_ONBOARDING.md`, `.github/PULL_REQUEST_TEMPLATE.md`.
   - Knowledge: `.agent/knowledge/principles_review_guide.md`,
     `.agent/knowledge/review_depth_classification.md`.
   - The nine skills that read the principles:
     `.claude/skills/audit-workspace/SKILL.md`,
     `.claude/skills/gather-project-knowledge/SKILL.md`,
     `.claude/skills/audit-project/SKILL.md`,
     `.claude/skills/plan-task/SKILL.md`,
     `.claude/skills/review-code/SKILL.md`,
     `.claude/skills/review-plan/SKILL.md`,
     `.claude/skills/triage-reviews/SKILL.md`,
     `.claude/skills/brainstorm/SKILL.md`,
     `.claude/skills/review-issue/SKILL.md`,
     plus `.claude/skills/what-next/SKILL.md` (references `docs/ROADMAP.md`
     as the file it reads — update to `docs/roadmap.md`).
   - Each reference becomes the new path (`docs/design.md`, `docs/roadmap.md`,
     `docs/principles.md`); plain-English mentions of "the architecture doc" /
     "the principles" stay as prose, only the path/link changes.

7. **Exemptions — do not rewrite**:
   - ADR bodies (`docs/decisions/*.md`) — none currently mention these paths
     (confirmed by grep), so this is a no-op guard, not active work.
   - `.agent/knowledge/inspiration_*_digest.md` (15 files) — historical,
     factual statements about *other* repos' files; rewriting them would
     misstate what those snapshots said.
   - `.agent/work-plans/issue-<N>/{plan.md,progress.md}` for every `N != 334`
     — point-in-time records of past plans/reviews; leave as written.

8. **README fixes**:
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

9. **Merge `main` before `review-plan`**, and again before `review-code`, to
   pick up #320 if it has landed by then — re-resolve any conflicts in
   `AGENTS.md` / `review-code` / `address-findings` `SKILL.md` by keeping
   both changes (path rename + #320's content).

10. **Verify**: `grep -rn 'ARCHITECTURE\.md\|docs/ROADMAP\.md\|docs/PRINCIPLES\.md'`
    across the repo returns only the exemptions from step 7 (and,
    incidentally, the `project_governance.md` template's example tree /
    `discover_governance.sh`'s own old-spelling `check_file` calls, which are
    intentional — they exist to keep matching projects that still use the
    old names).

## Files to Change

| File | Change |
|---|---|
| `ARCHITECTURE.md` → `docs/design.md` | `git mv`, content unchanged |
| `docs/ROADMAP.md` → `docs/roadmap.md` | `git mv`, content unchanged |
| `docs/PRINCIPLES.md` → `docs/principles.md` | `git mv`, content unchanged |
| `.agent/scripts/discover_governance.sh` | Add `docs/design.md` and `docs/principles.md` checks alongside the existing old-spelling checks |
| `.agent/scripts/tests/test_discover_governance.sh` (new) | 3 fixtures: workspace new-spelling, project old-spelling, project new-spelling; `chmod +x` |
| `.agent/scripts/merge_pr.sh` | `docs/ROADMAP.md` → `docs/roadmap.md` (lines ~776, ~1097); root `ROADMAP.md` entry untouched |
| `.agent/scripts/update_roadmap.sh` | Add `docs/roadmap.md` as a third discovery candidate; update docstring |
| `.agent/scripts/tests/test_merge_pr_gate.sh` | Roadmap fixtures write `docs/roadmap.md` (lines ~629, ~1227); update comment at ~1212 |
| `.agent/templates/project_governance.md` | Note lowercase `docs/` equivalents are equally discoverable |
| `README.md` | Documentation list links + opening line ("one or more external project repositories") |
| `AGENTS.md`, `CLAUDE.md`, `.agent/AGENT_ONBOARDING.md`, `.github/PULL_REQUEST_TEMPLATE.md` | Update path references |
| `.agent/knowledge/principles_review_guide.md`, `.agent/knowledge/review_depth_classification.md` | Update path references |
| 9 skills' `SKILL.md` (audit-workspace, gather-project-knowledge, audit-project, plan-task, review-code, review-plan, triage-reviews, brainstorm, review-issue) + `what-next` | Update `docs/PRINCIPLES.md` / `docs/ROADMAP.md` references |
| `.agent/knowledge/inspiration_*_digest.md` (15 files) | **No change** — exempt, historical |
| `.agent/work-plans/issue-<N>/*` for `N != 334` | **No change** — exempt, historical |
| `docs/decisions/*.md` | **No change** — no ADR mentions these paths |

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Script + test updates ship in the same PR as the moves; the reference sweep is scoped explicitly rather than left implicit. |
| Workspace vs. project separation | `discover_governance.sh` / `project_governance.md` changes are additive (accept both spellings) — no project is forced to rename anything. |
| Only what's needed | Content is not rewritten anywhere; the README opening-line fix is the one explicitly-permitted factual correction. |
| Documentation accuracy | README's "one external project repository" claim is verified against `ARCHITECTURE.md`'s own multi-project description before editing, not assumed. |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0008 (ADR cross-references immutable) | No | No ADR mentions these three paths (confirmed by grep) — no ADR edits, no References-section additions. |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| `ARCHITECTURE.md` → `docs/design.md` | `discover_governance.sh` architecture check (workspace scope) | Yes — step 2 |
| `docs/ROADMAP.md` → `docs/roadmap.md` | `merge_pr.sh` bookkeeping pattern lists, `update_roadmap.sh` discovery, `test_merge_pr_gate.sh` fixtures | Yes — steps 4–5 |
| `docs/PRINCIPLES.md` → `docs/principles.md` | 9 skills, `principles_review_guide.md`, `discover_governance.sh` | Yes — steps 2, 6 |
| Path renames generally | README documentation list, root instruction files | Yes — steps 6, 8 |
| Path renames generally | Inspiration digests, historical work-plans, ADR bodies | Explicitly excluded — step 7 |

## Open Questions

- Should `CLAUDE.md` move to `.claude/CLAUDE.md` (which Claude Code also
  reads)? Flagged by the issue as an owner decision, not made here — this
  plan keeps `CLAUDE.md` at the root and only updates its path references.

## Estimated Scope

Single PR. Two logical commits recommended: (1) the three `git mv` renames
alone, (2) script/test/reference updates — keeps the rename diff reviewable
independent of the sweep.
