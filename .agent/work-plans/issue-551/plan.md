# Plan: Where a project keeps its goals, design and roadmap (#551)

## Issue

https://github.com/rolker/agent_workspace/issues/551

## Context

A project's goals, design and roadmap are found by fixed searches that disagree: `sitrep_root.sh`
takes the first of `docs/roadmap.md`, `ROADMAP.md`; `update_roadmap.sh` edits every one of
`ROADMAP.md`, `docs/ROADMAP.md`, `docs/roadmap.md`; `check_design_anchors.sh` and the sit-rep checks
hard-code `docs/design.md`; the skills name paths in prose. `docs/design.md#documentation-layers`
Target says where the mapping is kept "is not decided" (OQ-1). Owner decisions (checkpoint, 2026-11-23):
separate settings `goals`, `design`, `roadmap` in `.agent/projects.d/<name>` read through one helper (no
wait on #393); values are a tracked path inside the project, optionally `path#heading`, or `none`;
outside paths and separate repositories refused; a part's documents stay named only by the root's
`| Sub-roadmap | Root |` table (ADR-0022). Host decisions: one shared candidate list; two PRs.

## Approach

Value grammar (all three keys): `none`, or a project-relative path, optionally followed by `#<heading text>`
(only the roadmap/goals/design reader that can use a section does; others use the file). Path rules,
enforced at `set` and in the parser: not empty, no leading `/` or `~`, no `..`/`.` component, no
trailing `/`, no blanks or backslash in the path part, no `://` (a URL). A value that is
not a path is refused with the reason. Containment is checked again at read time (realpath under the
root, symlinks that leave it refused), because a file can change after `set`.

Shared candidate lists (the fallback for an unset key), in this order, replacing the differing fixed
searches:
- roadmap: `docs/roadmap.md`, `docs/ROADMAP.md`, `ROADMAP.md`
- design: `docs/design.md`, `ARCHITECTURE.md` (the two names `audit-project` already accepts)
- goals: `README.md` (no search exists today; the skills name README or the design's goals section)

**Part 1 (PR 1): settings, helper, script readers, tests, design text. Does not touch the two skills named below.**

1. **Keys** — in `_project_registry.sh` add `goals design roadmap` to `_PROJECT_FILE_KEYS`; value
   validation in `_project_file_value_error` (the grammar above); extend the header key list. Type
   `unused_settings` unchanged (every type reads them).
2. **Helper** — `project_document_path "$root" "$name" <goals|design|roadmap>` beside
   `project_records_default`. Prints one line `<relpath>[#heading]` and exit 0 for a set key whose
   file exists; `none` (exit 0, second output field says explicit-none) for `none`; for an unset key the
   first existing candidate; exit 1 with a reason when nothing exists, exit 2 for a malformed file or
   a path that leaves the root. Also `project_document_name_for_root "$root" "$dir"` wrapper using
   `registry_resolve_session_dir`; an unregistered root (the workspace itself) uses the candidates
   only. A thin CLI `project_setting.sh doc <name> <key>` so skills and prose call the same code
   (no skill edits in PR 1; the CLI is for PR 2).
3. **`sitrep_root.sh`** — replace the `for f in docs/roadmap.md ROADMAP.md` loop with the helper; an
   explicit `none` prints `roadmap=` empty with a reason line; `check design_anchors/documentation`
   take the design path from the helper; update the header lines 21-22 and 53-55.
4. **`update_roadmap.sh`** — with the key set, edit that file only; unset, keep ticking every existing
   candidate of the shared list (the list now matches the sit-rep's); `none` is a clean no-op with a message.
   Update header line 12; the case-insensitive-filesystem dedupe stays.
5. **`check_design_anchors.sh`** — the root's design file comes from the helper (`DESIGN=` at line 174),
   so a project whose design key names another file is checked against its headings; citation
   resolution for parts is unchanged. `none` skips the root-design checks with a message.
6. **`sitrep_checks.sh`** — header only: `--roadmap` default is the helper's result, not fixed `docs/roadmap.md`
   (`sitrep_root.sh` already passes the path; make the default call the helper).
7. **Tests** — new `test_project_documents.sh` (chmod +x; registered in the test runner the way the
   other `test_*.sh` are) for the helper: set, unset, `none`, bad value rows (absolute, `..`, `~`, URL,
   blank, symlink out), heading kept, missing file, unregistered root, a part also named in the pointer
   table (helper resolves the root's own key only; the pointer table is untouched). Extend
   `test_project_registry.sh` (key accepted, refused values, `set` validates), `test_sitrep_root.sh`
   (roadmap from key, `none`, fallback order), `test_update_roadmap.sh` (key set edits only that file;
   `docs/ROADMAP.md` now in both readers; none), `test_design_anchors.sh` (design key points at another file).
8. **Design text (same PR, ADR-0017)** — `docs/design.md#documentation-layers`: Target status
   `proposed` to `decided` for the mapping, drop "not decided", name the three settings and the
   fallback for an unset one, the inside-the-project rule and `none`; the "Now" text about
   `update_roadmap.sh` candidates; `#registry-and-adapters`: the three keys; `#open-questions` mark OQ-1
   answered by #551; change-log row. `docs/roadmap.md` Direction **Format** paragraph: one line that
   the grammar applies to the file the `roadmap` setting names. Check the line budget of the Documentation
   layers section (already past the 60-line prompt; keep additions to a few lines).
9. **Reference docs** — `.agent/knowledge/script_reference.md` rows for `project_setting.sh` (new keys, `doc`),
   `update_roadmap.sh`, `sitrep_root.sh`; `project_setting.sh` help text.

**Part 2 (PR 2, after PR 1 merges; edits the skills; merge main first if #452 landed): skills.**

10. **`onboard-project/SKILL.md`** step 3 (footprint questions): ask for the three locations when unset
    (offer the detected candidate, `none`, or decide later; decide later keeps keys unset), store with
    `project_setting.sh set`; step 5 reads the roadmap through the helper, not `docs/roadmap.md`.
11. **`audit-project/SKILL.md`**: the `ARCHITECTURE.md` / `docs/design.md` check reads the design key;
    report a key naming a missing or untracked file, and a key naming a file the root's pointer table also names.
12. **design-discussion `SKILL.md`** (lines ~126-134): resolve roadmap/design/goals through the helper and
    ask when a key is unset instead of assuming `docs/roadmap.md`.
13. **Tests** — extend the skill-consistency tests if any grep these paths; run `make lint`, `make validate`.

## Files to Change

| File | Change | Part |
|---|---|---|
| `.agent/scripts/_project_registry.sh` | keys, value validation, `project_document_path`, header | 1 |
| `.agent/scripts/project_setting.sh` | help, `doc` subcommand | 1 |
| `.agent/scripts/sitrep_root.sh`, `sitrep_checks.sh` | read roadmap/design via helper; headers | 1 |
| `.agent/scripts/update_roadmap.sh` | key-aware candidates | 1 |
| `.agent/scripts/check_design_anchors.sh` | design file from helper | 1 |
| `.agent/scripts/tests/test_project_documents.sh` (new, `chmod +x`) and four existing tests | cases above | 1 |
| `docs/design.md`, `docs/roadmap.md` | Target, Now, keys, OQ-1, change log, Format line | 1 |
| `.agent/knowledge/script_reference.md` | rows | 1 |
| `.claude/skills/onboard-project/SKILL.md`, `audit-project/SKILL.md`, `design-discussion/SKILL.md` | question, audit, resolution | 2 |

## Prior Art

`project_records_default` and the `location`/`tracking` keys (#332) are the model for keys, validation and
`set`/`unset`; `sitrep_checks.sh` and `check_design_anchors.sh` already follow the Sub-roadmap table
(kept as is). The records lookup (#393) was considered and rejected as the home (owner, Q1). Outside
paths and repositories rejected (owner, Q2).

## Serves

Goal "Projects keep their own documents" (README workspace goals), under `docs/design.md#documentation-layers`
and `docs/design.md#registry-and-adapters`.

## Design Picture

Yes: `docs/design.md#documentation-layers` (Target decided, Now text), `docs/design.md#registry-and-adapters`
(keys), `docs/design.md#open-questions` (OQ-1), change log, in PR 1 with the behaviour; PR 2 adds no design change
beyond skill wording.

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | Design text lands with the code in PR 1 |
| Put each thing at the level it applies to | Root's own documents in the root's settings; parts only via the pointer table |
| A project is never forced | Unset keeps a search; `none` and "decide later" are answers |
| Only what's needed | One helper, no outside kinds |
| Enforcement stays with the code | Grammar enforced at `set` and read; tests per reader |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| ADR-0017 | Yes | Design and change log in PR 1 |
| ADR-0022 | Yes | Pointer table stays the way to name a part's documents |
| ADR-0016 | Yes | Outside paths and symlink escapes refused |
| ADR-0013 | Yes | Plan Authored entry |

## Consequences

| If we change... | Also update... | Included? |
|---|---|---|
| `_PROJECT_FILE_KEYS` | header, `project_setting.sh` help, script_reference, `check`/`unused_settings` tests | Yes (PR 1) |
| sit-rep roadmap lookup | `sitrep_root.sh`/`sitrep_checks.sh` headers, tests, design Target text | Yes (PR 1) |
| `update_roadmap.sh` candidates | design Now text, `test_update_roadmap.sh` | Yes (PR 1) |
| onboard/audit/design-discussion wording | skills | Yes (PR 2) |
| `docs/roadmap.md` Format paragraph | design `check_design_anchors` cites | Yes (PR 1) |

## Open Questions

- The goals fallback (`README.md`) and the design fallback (`ARCHITECTURE.md` second) are the host's reading of what the skills accept today; owner may veto.
- `update_roadmap.sh` with an unset key keeps ticking every existing candidate (as today) rather than only the first; stated so the sit-rep and it agree on the list, not on first-only.
- PR 2 waits on #452 only for a textual merge; PR 1 does not touch its files.

## Estimated Scope

Two pull requests: PR 1 (settings, helper, three scripts, tests, design text), PR 2 (three skills).
