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
Allowed: `ls`, `find`, `cat`/Read, `grep`, `git --no-optional-locks ls-files`
and `git log` (read-only; they do not touch the index). Anything that would
run a fork script, a fork test or `make` is out.

## Approach

1. **Fix the inventories first (host, before the passes).** From the fork,
   `git --no-optional-locks -C /home/roland/project11 ls-files` once, saved to
   the session scratchpad as `fork_files.txt` (454 lines), plus
   `find /home/roland/project11 -maxdepth 3 -not -path '*/.git/*'` for
   untracked or ignored entries (`layers/`, `.agent/work-artifacts`). Split by
   path prefix into three lists so every path lands in exactly one pass:
   - Pass 1: `.agent/scripts/`, `.agent/hooks/`, `.agent/templates/`,
     `.agent/tools/`, `Makefile`, `scripts/`, `.github/`, `.pre-commit-config.yaml`,
     `.devcontainer/`, `requirements.txt`, test files wherever they sit.
   - Pass 2: `docs/decisions/`, `.claude/skills/`, `.agent/knowledge/`,
     instruction files (`AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md`,
     `README.md`, `ROADMAP.md`, `.github/*instructions*`, `.github/copilot-instructions.md`).
   - Pass 3: `configs/`, `layers/` (main and `worktrees/*`, 39 entries),
     `.agent/work-plans/` (145 folders) and `.agent/work-artifacts`,
     `presentations/`, `docs/` outside `decisions/`, `project11.code-workspace`.
   Overlaps (a `.github/` instruction file) are assigned by the host in the
   lists, not left to the passes. Each list is a file the pass must account for
   line by line.
2. **Three parallel read-only passes** (fresh sub-agents, Sonnet, one brief each
   quoting the read-only rule). Each pass returns a table fragment in the
   scratchpad, one row per entry or per explicitly named group (a group is
   allowed only for same-kind files, for example "145 work-plan folders" with a
   rule and a count, or "19 tests of field mode"). Row fields: Item, Fork path,
   Class, Day-to-day blocker?, Covered by, one-line note.
   Class values: port, adapter, decline, already covered, belongs to a project
   repository. Pass summary line: `inventoried N, classified N (rows R, groups
   G covering g files)`.
3. **How "already covered" is verified in THIS tree (all passes).** A row may
   say "already covered" only after the pass has opened the file here that
   does the job and read enough to see it does (a script's usage, a skill's
   steps, an ADR's decision), and names it in "Covered by" as a path. Name
   similarity does not count. Per pass:
   - Pass 1: `ls .agent/scripts`, then Read the candidate; for scripts with a
     test, name the test (`.agent/scripts/tests/` or wherever it lives) and
     confirm it exercises the behaviour; for hooks check `.pre-commit-config.yaml`
     and `.agent/hooks/`; for Makefile targets check `Makefile` and
     `generate_make_skills.sh` output; templates against `.agent/templates/`.
     `sync_repos` / `validate_repos` are classified against the resolver in
     `tools/ros-manifest/` (src and tests read), saying what it does and
     what nothing calls yet; owner, 2026-11-10: "I want the new manifest to be
     used for the pickerel test".
   - Pass 2: each fork ADR matched to the ADR here by reading both decisions
     (the review already found the number collisions: fork 0012 is our 0008,
     fork 0013 is our 0013, fork 0015 replaced by our 0014 and 0015, and so
     on; the pass re-checks, not copies); each skill against
     `.claude/skills/<name>/SKILL.md` here; each knowledge file against
     `.agent/knowledge/` and `.agent/project_types/ros2_colcon/`, and for the
     ROS knowledge files the pass says where they would live (adapter, or the
     project's own `.agents`).
   - Pass 3: manifest and layer content is checked against the project
     repositories' own checkouts only by reading what is registered here
     (`projects.d/`, the registry) and the manifest resolver; in-flight
     `layers/worktrees/*` are classified by reading each entry's name and
     `ls` (never `git status` inside, which can write the index; a
     `git --no-optional-locks` read of branch and log is allowed) as finish,
     move or drop, with unpushed work flagged as the retire-only blocker.
4. **Evidence for the day-to-day list (host, while the passes run).** Read
   the issue 429 thread and branch (run-issue on package repositories, in
   implementation), issue 430 (install on a second machine) and the
   resolver README; extract what each says is missing for working on project11
   here, and hand the list to the merge step. Folded in by reference, not
   redone: 260, 261, 262, 208, 209, 172, 363 to 367 (rows say "filed" or "see
   #N"; issue states checked with `gh issue view`).
5. **Merge (one agent) writes `docs/fork_parity.md`.** Order: title and
   one-paragraph purpose with the fork's checkout date and the `ls-remote`
   result; the quoted Cutover row 4 and the Direction acceptance case from
   `docs/roadmap.md`; list A "Blocks developing project11 here" and list B
   "Blocks only retiring the fork" (about ten lines each, plain words, each
   line ends with its issue or "no issue yet"); the table (merged fragments,
   sorted by class then blocker); "Issues to open (owner's call)": at most
   about ten, a title and two lines each, day-to-day blockers first, none
   opened; per-pass counts line. Plain words, no polish; the owner reads the
   two lists, the table is the evidence.
6. **Verification (host, before the entry is final).** A script in the
   scratchpad (not committed) that, for every table row, (a) checks each path in
   "Covered by" resolves in this tree and (b) extracts each `#N` and runs
   `gh issue view N` (or `gh pr view`) to confirm it exists, printing misses;
   and compares per-pass counts: lines in each pass's inventory list equal
   rows plus group file counts equal the "classified" figure, and the sum over
   passes equals 454 plus the untracked entries found in step 1. Misses are
   fixed in the document, not waved through.
7. **Link and status.** `docs/roadmap.md` Cutover sequence row 4: Notes link
   `fork_parity.md`; Status updated through `.agent/scripts/update_roadmap.sh`
   to what is then true (in review while the PR is open). In
   `.agent/knowledge/inspiration_ros2_agent_workspace_digest.md`, a pointer
   line at the top to `docs/fork_parity.md` (not the content). Rows #260 to
   #262 notes in the roadmap are left alone; #262's checklist pointer is a
   proposed issue edit, listed in the document, not made.
8. **Design-document change log** only if the picture changes: expected none
   (the document is a record); if the audit finds that `docs/design.md`
   names no home for parity records is worth fixing, add one change-log row
   (the rule for rows and the line count are in `docs/design.md#change-log`).
   Run the pre-commit hooks, commit the document and the two link edits
   separately.

## Files to Change

| File | Change |
|------|--------|
| `docs/fork_parity.md` | New: two lists, table, issues-to-open section, counts |
| `docs/roadmap.md` | Cutover row 4: link and status through `update_roadmap.sh` |
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
| Verify before claiming | "Already covered" requires opening the file here; step 6 checks every path and issue number; counts must match |
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
| Cutover row 4 status | `docs/roadmap.md` via `update_roadmap.sh` | Yes (step 7) |
| Digest | pointer line | Yes (step 7) |
| #262 checklist, #260 buckets | issue edits | No: proposed in the document, owner's call |
| Issues to open | none opened | By design |

## Open Questions

None that block. One to note for the owner: the audit reads the fork as of
2026-09-25; `ls-remote` shows `main` unmoved, but unpushed local branches or
worktrees in the checkout are seen only because the checkout is read in place.

## Estimated Scope

Single PR. Document about 250 to 350 lines (about 20 lines of lists, one row
per entry or group, roughly 120 to 180 rows, about 10 proposed issues). Three
passes plus a merge; no code.
