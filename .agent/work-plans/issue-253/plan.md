# Plan: ros2_agent_workspace parity audit: classify remaining ADRs, skills, scripts for port/adapter/decline

## Issue

https://github.com/rolker/agent_workspace/issues/253

## Context

Owner, 2026-11-10: "How ready is the workspace to take over the duties of
ros_agent_workspace?" and "For the audit, the other workspace is at
~/project11." The fork checkout is `/home/roland/project11` (remote
`rolker/ros2_agent_workspace`), HEAD `323306a8` (2026-09-25), 454 tracked
files. `git ls-remote` shows its `main` has not moved. The Issue Review and
Checkpoint (progress.md) set the shape: one record, three parallel read-only
passes, one merge, no issues opened.

**The fork checkout is another root: READ ONLY.** In every pass: no write, no
commit, no fetch, no build, no script run inside `/home/roland/project11`.
Allowed: `ls`, `find`, `cat`/Read, `grep`, `diff`/`cmp` against this tree,
`git --no-optional-locks` `ls-files`, `log`, `branch`, `worktree list` and
`show` (read-only; they do not touch the index), and `gh` on the fork's
repository only to list or view. Anything that would run a fork script, a
fork test or `make` is out.

## Approach

**Who does what.** One implementing agent does every step below: it builds
the inventories, gathers the evidence, starts its own sub-agents for the three
passes (and the catch-all), merges, writes the document and runs the
verification. The host session does none of it.

**Brief text every pass gets (verbatim, plus the read-only rule above).**
- Fork access: every `git` call in the fork and its worktrees carries
  `--no-optional-locks`; unpushed work in `layers/worktrees/*` and
  `.workspace-worktrees/*` is read with
  `git --no-optional-locks -C <wt> log --oneline @{u}..` (or "no upstream");
  `gh` against `rolker/ros2_agent_workspace` is list/view only; no make, no
  script or test run, no fetch.
- Day-to-day blocker test, word for word: "Yes if a normal project11 change
  on pickerel would need the fork, or redoing by hand something the fork
  automates, within the first week, or the Rolling simulator acceptance case
  can't be reached." Otherwise retire-only. The merge step re-applies the test
  to every "yes" before it goes into list A.
- Classes: port, adapter, decline, already covered, partly covered (the fork
  has behaviour this tree lacks; the row names it), belongs to a project
  repository.

1. **Inventories (implementer), fail on any unassigned path.**
   Tracked: `git --no-optional-locks -C /home/roland/project11 ls-files`
   (454). Untracked/ignored: `git --no-optional-locks -C ... ls-files -o
   --directory` (about 355 entries without `__pycache__`; includes
   `.workspace-worktrees/issue-workspace-610`, 324 files in
   `.agent/scratchpad/`, `.agent/project_config.yaml`, `.rosdep/`, `.make/`,
   `.claude/settings.local.json`, generated `make_*` skills,
   `.claude/worktrees/`). Both saved in the session scratchpad. A split script
   assigns each path by prefix to one of four lists and exits non-zero,
   printing the paths, if any path matches none or two:
   - Pass 1: `.agent/scripts/`, `.agent/hooks/`, `.agent/templates/`,
     `.agent/tools/`, `scripts/`, `.github/workflows/`, `.pre-commit-config.yaml`,
     `.devcontainer/`, `requirements.txt`, test files, plus duty rows from
     `Makefile` (one row per target or target group: about 25 targets,
     `setup-all`, `sync`, the remote targets, `lock`/`unlock`, `pr-triage`,
     `agent-*`, `test-scripts`, `validate`, layer stamps) and CI jobs in
     `validate.yml` (lint, required-docs, link check, script tests).
   - Pass 2: `docs/decisions/`, `.claude/skills/`, `.agent/knowledge/`,
     instruction files (`AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `README.md`,
     `ROADMAP.md`, `.github/*instructions*`, `copilot-instructions.md`), extracting
     the things they tell agents to do by hand as duty rows (not one row per
     file); plus the closed-since-fork issues (read-only
     `gh issue list -R rolker/ros2_agent_workspace --state closed`, about 34
     since 2026-07-01, 16 since 2026-09-15), each mapped to a row or "no row:
     reason", as roadmap row 4 requires.
   - Pass 3: `configs/`, `layers/` (main and `worktrees/*`, 39),
     `.agent/work-plans/` (145), `.agent/work-artifacts`, `.agent/scratchpad/`,
     `.workspace-worktrees/`, `.rosdep/`, `.make/`, `presentations/`, `docs/`
     outside `decisions/`, `project11.code-workspace`, the fork's open pull
     requests (657 parked `merge_pr.sh` classification work, 663 dependabot;
     list view only) and unpushed work in every worktree.
   - Catch-all (to pass 2): everything else tracked or untracked, for example
     `.agent/AGENT_ONBOARDING.md`, `AI_IDENTITY_STRATEGY.md`, `AI_RULES.md`,
     `WORKFORCE_PROTOCOL.md`, `WORKTREE_GUIDE.md`, `.agent/instructions/`,
     `.agent/.identity*`, `.agent/github_metadata.json`, `.claude/settings.json`
     (PreToolUse hook running `check_question_context.py`, permissions
     allowlist), `.editorconfig`, `.gitignore`, `.claude/settings.local.json`.
2. **Evidence for the day-to-day list (implementer).** Read issue 429
   (run-issue on package repositories, in implementation) and issue 430
   (install on a second machine) and the `tools/ros-manifest/` README; extract
   what each says is missing for project11 here. Folded in by reference, not
   redone: 260, 261, 262, 208, 209, 172, 363 to 367.
3. **Three passes plus catch-all, run in parallel as the implementer's
   sub-agents.** Each returns a fragment in the scratchpad: rows grouped by
   duty (for example "field mode: N scripts, 3 skills, fork ADRs 0011 and 0014,
   2 knowledge files, Makefile remote targets"), each row listing its fork paths
   so the count check maps every path. Columns: Item, Fork paths, Class,
   Day-to-day blocker?, Covered by, one-line note. A pass ends with
   `inventoried N paths, classified N (rows R)`.
4. **"Already covered" is verified in THIS tree, three ways.**
   - Open the file here that does the job and name it; name similarity does
     not count.
   - Where a script exists in both trees (37 same-name, 31 of them differ) or
     a pair does the same job, read a read-only `diff` of the fork's file
     against this one. No fork-only behaviour: already covered. Fork-only
     behaviour: class partly covered (or port/adapter), the row names what is
     missing.
   - For the ROS build path (`setup_layers.sh`, `stage_rosdep_manifests.sh`,
     `rosdep_*` against `.agent/project_types/ros2_colcon/adapter.sh`) name the
     test here that exercises the behaviour, or write "covered, no test" (which
     counts as a day-to-day risk in the row note). Running anything in the fork
     stays forbidden. Hooks are checked against `.pre-commit-config.yaml` and
     `.agent/hooks/`; ADRs are matched by reading both decisions (fork 0012 is
     our 0008, fork 0013 our 0013, fork 0015 replaced by our 0014 and 0015),
     re-checked, not copied.
5. **Fixed class: manifest duties.** `sync_repos.py`, `validate_repos.py` and,
   where they serve the same duty, `list_overlay_repos.py`,
   `manifest_fallback.sh`, `resolve_repo_checkout.sh` are class adapter, not
   yet covered, day-to-day blocker yes. `tools/ros-manifest/` is a tested
   prototype but nothing in `.agent/`, `.claude/` or the `Makefile` calls it
   (grep, 2026-11-10) and the `ros2_colcon` adapter still reads vcstool
   `.repos` files from `configs/manifest/`. Owner, 2026-11-10: "I want the new
   manifest to be used for the pickerel test." "Covered by" names the resolver
   as the starting point and #267, never "already covered".
6. **Merge (implementer) writes `docs/fork_parity.md`.** Order: title and
   purpose with the fork checkout date and the `ls-remote` result; the quoted
   Cutover row 4 and Direction acceptance case; list A "Blocks developing
   project11 here" and list B "Blocks only retiring the fork" (about ten lines
   each; each line as effect, need, issue: "On pickerel, X cannot be done until
   Y, #N / no issue yet"); the table (about 40 to 70 rows grouped by duty,
   sorted by class then blocker); "Issues to open (owner's call)" (at most about
   ten, title and two lines, blockers first, none opened) with proposed
   "Decided Against" lines for the declines next to it (owner's call, not
   written to the roadmap); the per-pass counts. Plain words, no polish.
7. **Verification (implementer).** A scratchpad script (not committed):
   (a) the inventory split exits non-zero on any unassigned path, tracked or
   untracked; (b) every path in "Covered by" resolves in this tree; (c) every
   `#N` exists (`gh issue view` / `gh pr view`); (d) per pass, paths listed in
   rows equal the pass's inventory list, and the sum over passes (with the
   catch-all) equals tracked plus untracked entries. Misses are fixed in the
   document.
8. **Link.** Edit only the Notes of Cutover row 4 in `docs/roadmap.md` to link
   `fork_parity.md`, by hand. Status is left alone: `update_roadmap.sh` only
   sets `done` and `merge_pr.sh` already runs it at merge. One pointer line at
   the top of `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`.
   `docs/design.md` change-log row only if the picture changes (expected: no).
   Run pre-commit; commit the document and the link edits separately.

## Files to Change

| File | Change |
|------|--------|
| `docs/fork_parity.md` | New: two lists, table, issues-to-open section, counts |
| `docs/roadmap.md` | Cutover row 4 Notes only: link (status left to the merge) |
| `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md` | One pointer line to `docs/fork_parity.md` |
| `docs/design.md` | Change-log row only if the picture changes (expected: no) |
| `.agent/work-plans/issue-253/progress.md` | Entries per phase |

## Prior Art

The 2026-09-29 survey and digest (`.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`,
923 lines, classified A/P/R/O; filed #363 to #367) is input: its
classifications are re-verified against this tree, not copied, and its
length is the shape to avoid. The `audit-workspace` and `audit-project` skills
are checks of this tree against its own rules, not a cross-tree comparison, so
nothing from them is reused beyond the "every entry accounted for" habit.
`tools/ros-manifest/` is the existing candidate for the manifest duties. Nothing
new is built; no script is added.

## Serves

Flexibility and Trust, control and information (README `#workspace-goals`);
`docs/design.md#registry-and-adapters`; roadmap Cutover sequence row 4.

## Design Picture

No change to the design picture; the output is a record. The change log gets a
row only if step 8 finds a reason.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Only what's needed | One table, two short lists, at most about ten proposed issues; no appended digest |
| Verify before claiming | "Already covered" requires opening the file here; step 7 checks every path and issue number; counts must match |
| Put each thing at the level it applies to | Record may name the fork and project11; no mechanism file does; project layers classify as "belongs to a project repository" |
| Ask about what matters | Owner sees the two lists and the issues-to-open section; classification is the agent's |
| Leave a trail | Counts line per pass; progress.md entries |
| Do not touch another root | Fork read only in every pass (see Context) |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0003 | Yes | Record only; no project names in mechanism |
| ADR-0011 / 0012 | Yes | "adapter" rows point at `.agent/project_types/ros2_colcon/` and #429 |
| ADR-0016 | Yes | Session-root rule: fork rows obsolete under project-rooted sessions are classed decline or already covered; this session changes only this root |
| ADR-0013 | Yes | Progress entries |
| ADR-0014 / 0015 | Yes | Basis for declining container and subagent dispatch scripts |
| ADR-0018 | Watch | Fork hooks: home question under the plugin noted per row |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Cutover row 4 | Notes link by hand; Status set to done by `merge_pr.sh` | Yes (step 8) |
| Digest | pointer line | Yes (step 8) |
| #262 checklist, #260 buckets | issue edits | No: proposed in the document, owner's call |
| Issues to open | none opened | By design |

## Open Questions

None that block. One to note for the owner: the audit reads the fork as of
2026-09-25; `ls-remote` shows `main` unmoved, but unpushed local branches or
worktrees in the checkout are seen only because the checkout is read in place.

## Estimated Scope

Single PR. Document about 250 to 350 lines (about 20 lines of lists, about 40 to 70 rows grouped by duty, about 10 proposed issues). Three passes plus catch-all and a merge; no code.
