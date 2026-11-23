# Plan: sit-rep: report each path on its own, as the roadmap's Direction section writes them

## Issue

https://github.com/rolker/agent_workspace/issues/563 (part of #560, the workspace design review)

Revision 2, after the Plan Review (M1 to M6, S1 to S7) and the host's checkpoint decisions on it.

## Context

The sit-rep reads every `| Line | Check |` table of the roadmap's Direction section as one ordered chain, reports one count and names the first line not yet true as the next step. The roadmap on `feature/issue-560` (read at commit `b4b8b8af`, "Across the paths leads with what is not built (#563)"; the branch is still being fixed, so re-read it at implementation) writes the section as five paths. Paths 1 to 4 each have a Line table, Path 5 has none ("no design yet"), and an "Across the paths" paragraph has one line. The owner (2026-11-23): "the sit-rep results have been looking more and more stale"; "the roadmap was done with an expected sequence, and any deviation from that sequence might trip up the tracking of actual progress." Goal: one report per path, lines in no fixed order, marks that follow the paths as written.

Assumption (host order, M5): the five-path roadmap and its Direction row of `docs/design.md` are on main before this is implemented; this change edits them as that change leaves them. Owner (2026-11-23): "To keep things simple, it's ok if something breaks with the sit-rep skill if one lands before the other". So no work protects the interval between the two landing, and the work is not split into two pull requests for it. Said plainly: until the five-path section is on main, main's roadmap (three `**Path n` paragraphs, one table after the Format paragraph) is read by the new rule as Path 3 holding all four lines and Paths 1 and 2 as "no design yet"; this is accepted. The compatibility rule below is for other roots, not for that interval.

## Approach

One pull request, two commit groups (host decision). Decisions made here for the owner's veto are marked (V).

**Group 1: checker, root helper and their tests**

1. **Attribution rule** — in `scan_roadmap` (root's roadmap only, never a sub-roadmap) a table belongs to the nearest path or Across paragraph above it. A paragraph opens a path when its first line starts with `**Path <n>` (pattern `^\*\*Path [0-9]+`, so `**Paths.**` never matches) and the paragraph is not a wrapped continuation (the line before was blank, a table, a heading or the section start, not paragraph text). A bold span that wraps over two or more lines is joined first, up to its closing `**`; the name is the bold text with a trailing `.` or `,` dropped (`Path 1, ROS 2 projects`). `**Across the paths` opens the Across group, named `Across the paths`. Anything else (the Acceptance case, Format, bullets, a deferral table) belongs to the group above it: a Line table after the Format paragraph reads as the last group's. The rule is written in the checker header and in the roadmap's Format bullet ("a path's lines sit in a table under the path's paragraph; a table belongs to the nearest path or Across paragraph above it").
2. **(V) Row format** — a separate `path` row ahead of each path's lines, five fields, so saved rows files keep their shape. Result `true` with check `lines` when a Line table came under it; `unchecked` with check `no lines (no design yet)` when none did; Across is `true`/`group` or `unchecked`/`no lines`. The result is known only after the table, so it is patched back by index as `follow_pointer` patches `ROWS[idx]`. `path` rows do not count toward `SCAN_ROWS` or as table rows, so a section with path paragraphs and empty tables still gives its `(no rows in the Line or Deferral tables)` section row. `ROW_RE` gains `path`. Under `--list-pointers` no `path` row is printed. The header says rows are read in order and a path row governs the line rows up to the next path row (part rows attribute by item prefix, `<path>: <item>`; path rows by position, so they are only partly like them).
3. **Ungrouped lines (M1)** — lines in a table above the first path paragraph, when paths exist, are a group of their own: a `path` row `no path` (check `lines`) inserted before them in a pass after the scan, with its own count and unmet lines like any path. With no `**Path` paragraph anywhere there are no `path` rows and no `no path` group.
4. **(V) Across the paths** — a group of its own, counted and listed like a path, never described as behind. A path with no table is "no design yet" and not behind.
5. **Compatibility rule** — a Direction section with no `**Path` paragraph (a project's roadmap, or any root that has not adopted paths) gives no `path` row, and rows, `--summary`, `--summary-from`, `--next-steps-from` and the marks are as today: one group, `(root)` next step, no path word.
6. **Summary line (S6)** — the prefix `lines <t>/<n> deferrals <t>/<n>` is unchanged. When `path` rows exist append ` paths ` and one `<label> <t>/<n>` per group in roadmap order, `none` in place of counts for a path with no lines. (V) Labels: `P<n>` for `Path <n>`, `across` for Across, `nopath` for the ungrouped group. Example: `... paths nopath 0/1 P1 1/4 P2 0/4 P3 0/3 P4 1/3 P5 none across 0/1`. The suffix holds no TAB, so the run-record readers (step 2's `cut -f4`, step 8's `-f5-`) keep working. Step 8's "what moved" compares per path only when both records carry the suffix with the same labels; otherwise it compares the prefix only.
7. **`--next-steps-from`** — with `path` rows, one tab line per group in roadmap order, in place of `(root)`: `<group name>\t<first line not true>\t<result>`, `<group name>\tnone open`, or `<group name>\tno lines (no design yet)`; sub-roadmap lines unchanged. Without `path` rows, `(root)` as today. The lines carry no check cell; step 5 reads it from the saved rows (below).
8. **`sitrep_root.sh --worktrees --rows`** — `named` (yes/no) and `named_part` stay. Add `named_path`: the name of the first group (roadmap order) whose line rows name the work by the same rules, `""` when none or when no `path` rows exist. The Python block tracks the current group while reading rows. Header documents it.
9. **`gh-issue N closed` true while the issue stays open** — out of scope for the checker (host decision); the roadmap uses another existing check kind where one fits, else an empty cell. Stated in the header.
10. **Roadmap Across line gets a check (S4)** — on the roadmap (as #560 leaves it): the Across paragraph's "To be built (#563) ... Today it reads ..." is reworded to present tense, and its line gets `` `file-contains .agent/scripts/sitrep_checks.sh a path row governs the line rows up to the next path row` `` (the sentence this change adds to the checker header, exactly; (V) text chosen here). The Format bullet gets the nearest-paragraph rule from item 1.

**Group 2: skill text, design row, knowledge file**

11. **`SKILL.md` step 1** — add `path` to the row kinds; the `--- next steps` text says: with paths, one line per group by its name (or `no lines (no design yet)`), without paths `(root)`; the summary text mentions the suffix.
12. **Step 3 marks (M4)** — exact text, (V):
    - a line names the work: the path's name as the roadmap writes it (`Path 2, modular workflows`); the Across group: `Across the paths`; the ungrouped group: `no path (a line names it)`; a part's line: the sub-roadmap path as today.
    - no line names it: `no path line (serves a goal)`, `no path line (serves no goal)` (Serves `none`), `no path line (no complete issue review)`, `no path line (its issue review has no Serves line)`.
    - step 1 saved no rows: `path unknown (steps not checked)`.
    - a root with no `**Path` paragraph: no path word, as today.
    - The Path 2 and Path 3 rules and "a project worktree is never Path 2 or Path 3" are removed. The list of paths for the closing question is read from the `path` rows (names), keeping each paragraph's first sentence from the awk block.
13. **Step 5** — per path: for each next-steps line with a line not true, take its check cell from the saved rows file (the first `line` row after the `path` row of that name, up to the next `path` row, whose result is not true), then run the existing issue/branch/pull-request lookup once per path. `unchecked` and `unknown` still count as not true; Across and no-table paths are never "behind".
14. **Step 8** — top of the report: one line per group: name, `t/n` true, first line not yet true as written ("no design yet" for a no-table path); the full lists stay in the Steps section. The line after the heading names the acceptance case as Path 1's test (`acceptance_first` applies to Path 1 only). In flight: branches matching any group's first unmet line come first (the rule "the next step's branch is among the five shown" is read per group). A pull request with no worktree is marked with the path whose line names its issue, read from the saved rows (the match step 5 makes), else `path unknown (no worktree, timeline not read)`; no word when the root has no Path paragraph. "Running: nothing advances it" becomes "Running: nothing on this machine". The closing question offers the groups as the section names them. Front-matter description updated.
15. **`docs/design.md` Direction row (M5)** — against #560's wording: replace "reads the paths' line tables as one list and names the first line not yet true as the next step (reporting each path on its own is not built, #563)" with per-path reporting (each path's name, count and unmet lines in no fixed order; Across as a group; a path with no table is "no design yet"; a root with no Path paragraph is read as one group); replace "Until the sit-rep reports each path on its own (#563), its marks follow the three paths of before #560 ... Paths 4 and 5 are never marked" with the marks of item 12. Measures row: add the per-path counts the record gains. Add a history row as the file does.
16. **`.agent/knowledge/script_reference.md` lines 55-56 (M6)** — add `named_path`, the `path` row, per-path next steps and the summary suffix.

## Files to Change

| File | Change |
|---|---|
| `.agent/scripts/sitrep_checks.sh` | `path` rows, ungrouped group, `ROW_RE`, summary suffix, per-path next steps, header |
| `.agent/scripts/sitrep_root.sh` | `named_path`, header |
| `.agent/scripts/tests/test_sitrep_checks.sh` | new section 16; rewrites listed below |
| `.agent/scripts/tests/test_sitrep_root.sh` | `named_path` cases |
| `.claude/skills/sitrep/SKILL.md` | steps 1, 3, 5, 8, closing question, description |
| `docs/design.md` | Direction and Measures rows, history row |
| `docs/roadmap.md` | Across paragraph and line check, Format bullet (assumes #560 on main) |
| `.agent/knowledge/script_reference.md` | lines 55-56 |
| `.agent/scripts/check_design_anchors.sh` | no change; test confirms no `path` row reaches it |

## Tests

Fixtures are heredoc roadmaps in a scratch root. New section 16 in `test_sitrep_checks.sh`:

- two paths, one table each: `path` rows, per-path counts, prefix equal to the old line, per-path next steps.
- a Line table above the first path paragraph: `no path` group, counted and listed, in the suffix and the next steps (M1); `named_path` for work it names.
- a path paragraph with no table: `unchecked`, `P5 none`, `no lines (no design yet)`, not behind.
- Across: own group, never behind; result `true`/`group`.
- two tables under one path; a deferral table between paths (not attributed, next path unaffected); a Line table after the Format paragraph (belongs to the group above).
- empty Line tables under path paragraphs still give the `(no rows ...)` section row (path rows not counted).
- `**Paths.**`, a `**Path 3` at the start of a wrapped continuation line, a bold span wrapped over two lines (joined), `**Path` in a fence, table or bullet: pattern cases.
- compatibility: no `**Path` paragraph gives rows, summary and next steps identical to today's; an old rows file without `path` rows works in `--summary-from` and `--next-steps-from`.
- a sub-roadmap with its own `**Path` paragraph: no `path` row; `subline` rows and next steps unchanged; `--list-pointers` prints no `path` row.
- frozen copy of the real five-path text (heredoc, read from `feature/issue-560` at `b4b8b8af`, `gh-issue` checks stubbed as the existing tests do): five paths plus Across, line counts per path.
- the Across line's `file-contains` check is true against the checker header after the change.
- `test_sitrep_root.sh`: `named_path` for work under a path, under Across, under `no path`, named in two paths (first wins), unnamed (`""`); `named` and `named_part` unchanged.

Existing tests that change (line numbers as the plan review found them; re-read before editing):

- `test_sitrep_checks.sh` section 13, step 1 fixture (about lines 819-836: `**Path 1, One.**`, `**Path 2, Two.**`, one Line table): the table now belongs to Path 2, so the next-steps assertion changes from `(root)<TAB>none open` to a `Path 1, One` line with `no lines (no design yet)` and a `Path 2, Two` line for its first line not true (or `none open`).
- section 13, lines about 1176-1262 and 1286-1296 (marks `Path 1`, `Path 2`, `Path 3`, `no path` and the step 8 wording): rewritten to the item 12 texts and "nothing on this machine".
- section 14 (about line 1539: `proj_roadmap paths` default writes `**Path 1, Ship.**`; lines 1610-1634): this default fixture now has a path, so output is not unchanged (the first plan's claim was wrong). Assertions become `Path 1, Ship` for work its line names and `no path line (serves a goal)` for other project work; the case with no Paths paragraph (about line 1626) keeps "no path word".
- other cases in sections 11-14 are checked by running the suite; any that fail on the new output are listed in the commit message.

One live run of `sitrep_checks.sh --roadmap` on the real text, recorded in the pull request with which file it read (`git show feature/issue-560:docs/roadmap.md` until it is on main, then `docs/roadmap.md`). Full suite run once by the host, per the standing rule.

## Prior Art

The existing parser is extended, not replaced; one parser stays shared with `check_design_anchors.sh` through `--list-pointers`. The `part`/`subline` rows (#488) show a header-like row ahead of grouped rows, but they attribute by item prefix, not by position. Rejected: a sixth field on line rows (breaks the five-field rule and saved rows files); a path configuration (the section as written already says it).

## Serves

Easy to use (the sit-rep is the user's view of what is next), and A safeguard has to earn its cost; `docs/design.md#documentation-layers` (the Direction row).

## Design Picture

Alters how the sit-rep reads the Direction section: `docs/design.md#documentation-layers`, Direction and Measures rows, in this PR (group 2), edited against #560's text.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| A change includes its consequences | The table below; every reader of the rows was listed in the plan review |
| Test what breaks | New cases plus the named rewrites of existing tests |
| Enforce what matters, as simply as possible | Path comes from the section as written; no configuration; one parser |
| Ask about what matters | Mechanism choices decided here and listed (V) for veto |
| Know whether it works | A sit-rep run on the merged roadmap shows five paths with their own counts and the new wording; the Across line's check turns true |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0022 | Yes | `part`/`subline` rows and per-part next steps unchanged; a part's own paths are not read (left for later) |
| ADR-0016 | Yes | A root with no Path paragraph is read as today |
| ADR-0013 | Yes | Plan Authored entry per revision |
| ADR-0017 | Yes | The design rows change in the same change |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| Header grammar, row kinds, `ROW_RE` | `sitrep_checks.sh` header, `script_reference.md` | Yes |
| `--summary`, `--summary-from`, run-record line | SKILL.md step 8 comparison (not step 4, which only writes); steps 2 and 8 readers | Yes |
| `--next-steps-from` | SKILL.md steps 1, 5, 8 | Yes |
| `sitrep_root.sh` fields | `test_sitrep_root.sh`, step 3, `script_reference.md` | Yes |
| `check_design_anchors.sh` | reads `--list-pointers` only; test | Yes |
| Sub-roadmap reading | unchanged, tested | Yes |
| Direction and Measures rows | `docs/design.md`, history row | Yes |
| Roadmap Across paragraph, line and Format bullet | `docs/roadmap.md` | Yes |
| Any other reader of the rows | grep `sitrep_checks` and `--rows` across `.agent/` and `.claude/` before editing (`design-discussion` SKILL.md reads only the `part` result) | Yes |

## Open Questions

None for the owner. For veto (V): separate `path` row; Across as a group never behind; `named_path` beside `named`; per-path next-steps lines replacing `(root)` only when paths exist; the ungrouped group named `no path` and marked `no path (a line names it)`; suffix labels `P<n>`, `across`, `nopath`; the exact mark texts of item 12; the Across check text `a path row governs the line rows up to the next path row`.

## Estimated Scope

Single PR, two commit groups.
