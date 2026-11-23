# Plan: sit-rep: report each path on its own, as the roadmap's Direction section writes them

## Issue

https://github.com/rolker/agent_workspace/issues/563 (part of #560, the workspace design review)

## Context

The sit-rep reads every `| Line | Check |` table of the roadmap's Direction section as one ordered chain, reports one count and names the first line not yet true as the next step. The roadmap on `feature/issue-560` rewrites the section as five paths, each with a Line table of its own (Path 5 has none: "no design yet"), plus an "Across the paths" paragraph and table. The owner (2026-11-23): "the sit-rep results have been looking more and more stale"; "the roadmap was done with an expected sequence, and any deviation from that sequence might trip up the tracking of actual progress." Goal: one report per path, lines in no fixed order, marks that follow the paths as written.

## Approach

One pull request, two commit groups (host decision). Decisions listed for the owner's veto are marked (V).

**Group 1: checker and its tests**

1. **Path attribution from the section as written** — in `scan_roadmap` (root only, never a sub-roadmap), a non-table paragraph that opens `**Path <n>` or `**Across the paths` emits one `path` row where it is met; the name is the bold text, trimmed of trailing `.` and `,` (`Path 1, ROS 2 projects`). Line rows after it, until the next `path` row, belong to that path by position; no field is added to line rows. Deferral and pointer tables are not attributed.
2. **(V) Row format** — a separate `path` row ahead of each path's lines, five fields as now. Result `true` with check `lines` when a Line table followed, `unchecked` with check `no lines (no design yet)` when none did; `Across the paths` has check `group`. A saved rows file with no `path` row stays valid, so old rows files still work. `ROW_RE` gains `path`. Under `--list-pointers` no `path` row is printed (that mode prints only pointers).
3. **(V) Across the paths** — a group of its own, named as the roadmap names it, counted and listed like a path but never described as behind. A path with no table is "no design yet" and not behind.
4. **Compatibility rule** — a Direction section with no `**Path` paragraph (a project's roadmap, or the workspace's before #560 lands) emits no `path` row and every output (rows, `--summary`, `--summary-from`, `--next-steps-from`) is byte-for-byte as today: one group. A `line` table before the first path paragraph also stays ungrouped.
5. **Summary line** — keep the prefix `lines <t>/<n> deferrals <t>/<n>` unchanged; when `path` rows exist append ` paths P1 1/4 P2 0/4 ... across 0/1 P5 none` (number labels, no spaces in names). Two runs stay comparable by the prefix; the run-record comparison in SKILL.md step 4 is checked so a longer line does not break it.
6. **`--next-steps-from`** — with `path` rows, one tab line per path in place of the single `(root)` line: `<path name><TAB><first line not true><TAB><result>`, `<name><TAB>none open`, or `<name><TAB>no lines (no design yet)`; sub-roadmap lines unchanged. Without `path` rows, the `(root)` line as today. The header grammar of `sitrep_checks.sh` documents `path` rows, the attribution rule and the compatibility rule; the sentence "a sub-roadmap's own Paths paragraphs are not read" stays true and is stated as left for later (a part is one group).
7. **`sitrep_root.sh --worktrees --rows`** — keep `named` yes/no and `named_part` as they are (their readers do not break); add `named_path`: the name of the first path (roadmap order) whose line rows name the work by the same rules, "" otherwise. The Python block tracks the current path while reading rows. Header documents it.
8. **`gh-issue N closed` true in fact, issue open** — out of scope for the checker. The roadmap uses another existing check kind where one fits, else an empty cell; stated in the checker header so it is not read as a defect.

**Group 2: skill text and design row**

9. **`SKILL.md`** — step 3: marks become `named_path` (path name), else the part's path, else "serves <goal>" from the newest complete Issue Review's Serves line, else "unknown"; the Path 1/2/3 fallback block (about lines 414-491) and the "A project worktree is never Path 2 or Path 3" rules are removed; the path list for the closing question is read from the `path` rows (names) with the first sentence kept from the paragraph. Step 5: next step reported per path from the new next-steps lines (no single chain; "unchecked" and "unknown" still count as not true; Across and no-table paths never "behind"). Step 8: per-path block (name, `t/n`, lines not true), "Running: nothing on this machine" in place of "nothing advances it" (about line 1149), marks and the closing question as in step 3. Front-matter description updated.
10. **`docs/design.md`** Documentation layers, Direction row: replace "names the first line not yet true as the next step" and "A Paths paragraph names the two paths" by per-path reporting, the compatibility rule and marks that follow the paths as written; add a Decision-register-style history row as the file does.

## Files to Change

| File | Change |
|---|---|
| `.agent/scripts/sitrep_checks.sh` | `path` rows, `ROW_RE`, summary suffix, per-path next steps, header grammar |
| `.agent/scripts/sitrep_root.sh` | `named_path` field and header text |
| `.agent/scripts/tests/test_sitrep_checks.sh` | new section 16 (path attribution), summary and next-steps cases |
| `.agent/scripts/tests/test_sitrep_root.sh` | `named_path` cases |
| `.claude/skills/sitrep/SKILL.md` | steps 3, 5, 8, closing question, description |
| `docs/design.md` | Direction row of Documentation layers (+ history row) |
| `docs/roadmap.md` | only once #560 is on main: tick the Across-the-paths line, update its "Until that is built" sentence (via the repo's roadmap-update path) |
| `.agent/scripts/check_design_anchors.sh` | no change expected; confirmed by test (it reads `--list-pointers` only) |

## Tests

Each says which roadmap it reads; all fixtures are heredoc roadmaps in a scratch root.

- Path rows: two paths, one table each; counts per path in `--summary`; prefix equals the old line.
- Table with no preceding path paragraph (stays ungrouped; rows as today).
- Path paragraph with no table (Path 5): `path` row `unchecked`, summary `P5 none`, next-steps `no lines (no design yet)`, not behind.
- Across the paths table: own group, never behind.
- Two tables under one path (both attributed to it); deferral table between paths (not attributed, not breaking attribution of the next path's table).
- Compatibility: a Direction section with no `**Path` paragraph, and a project session's roadmap (section 14 fixtures), give output identical to current expected strings; an old saved rows file (no `path` rows) works in `--summary-from` and `--next-steps-from`.
- Sub-roadmap: a part's own `**Path` paragraph emits no `path` row; its `subline` rows and next step are unchanged.
- `--list-pointers` prints no `path` row; fenced `**Path` text and a `**Path` inside a table or bullet are not paragraphs.
- Frozen copy of the real five-path Direction text from `feature/issue-560` (heredoc in the test): five paths plus Across, 4/4/3/3/none/1 line counts, `gh-issue` checks stubbed as in existing tests.
- `test_sitrep_root.sh`: `named_path` for a line under Path 2, under Across, for work named in two paths (first wins), unnamed work (""), `named`/`named_part` unchanged.
- One live run of `sitrep_checks.sh --roadmap` on the real text, recorded in the PR (state which file: `git show feature/issue-560:docs/roadmap.md` until it is on main, then `docs/roadmap.md`).

## Prior Art

The existing parser is extended, not replaced: one parser stays shared with `check_design_anchors.sh` (via `--list-pointers`), as its sharing note requires. The `part`/`subline` rows (#488) are the model for a header-like row ahead of grouped rows. Rejected: a sixth field on line rows (breaks the five-field rule and saved rows files); a configuration naming paths (the section as written already says it).

## Serves

Easy to use (the sit-rep is the user's view of what is next), and A safeguard has to earn its cost; `docs/design.md#documentation-layers` (the Direction row).

## Design Picture

Alters how the sit-rep reads the Direction section: `docs/design.md#documentation-layers`, Direction row, changes in this PR (group 2).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | Table below names each consumer |
| Test what breaks | Each attribution edge case has a fixture; one run on the real text |
| Enforce what matters, as simply as possible | Path comes from the section as written; no config; one parser |
| Ask about what matters | Row format and Across group decided here, listed (V) for veto |
| Know whether it works | Judged by a sit-rep run on the merged roadmap: five paths with their own counts, "nothing on this machine" wording |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0022 | Yes | `part`/`subline` rows and per-part next steps unchanged; a part's own paths are not read (left for later) |
| ADR-0016 | Yes | Compatibility rule keeps a project's one-table roadmap reported as today |
| ADR-0013 | Yes | Plan Authored entry |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Header grammar and row kinds of `sitrep_checks.sh` | `ROW_RE`, header text | Yes |
| `--summary`, `--summary-from`, run-record line | SKILL.md step 4 comparison with the previous record; old records stay comparable by the unchanged prefix | Yes |
| `--next-steps-from` | SKILL.md step 5, step 8 | Yes |
| `sitrep_root.sh` fields | `test_sitrep_root.sh`, SKILL.md step 3 | Yes |
| `check_design_anchors.sh` | reads `--list-pointers` only; verify no `path` row leaks | Yes (test) |
| Sub-roadmap reading | stated left for later; tested unchanged | Yes |
| Direction row | `docs/design.md`, history row | Yes |
| Any other reader of rows (grep `sitrep_checks` and `--rows` across `.agent/` and `.claude/` before editing) | adjust | Yes |

## What changes if the #560 branch is not on main at implementation

Code, tests (frozen fixture of the real text) and skill text are built and tested unchanged; the compatibility rule makes merging safe because the current roadmap prints as one group. The live run and the roadmap tick/sentence edit wait for the merge of #560; if #560 is not on main when this one is ready, hold the roadmap edit and the live run (run it against `git show feature/issue-560:docs/roadmap.md`) and say so in the PR.

## Open Questions

None for the owner. Veto items (V): separate `path` row; Across as a group never behind; `named_path` added beside `named` instead of changing it; next-steps lines per path replacing `(root)` only when paths exist.

## Estimated Scope

Single PR, two commit groups.
