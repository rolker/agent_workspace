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

Value grammar (all three keys): `none`, or a project-relative path, optionally followed by `#<heading text>`.
What `#heading` does per reader (each has a test): `roadmap` -- `sitrep_checks.sh` scans only the `## Direction`
section, so a heading on `roadmap` is refused at `set` (the Direction section is fixed by the format; `update_roadmap.sh`
edits the whole file); `design` -- `check_design_anchors.sh` checks every heading of the file, so a heading is
accepted and ignored there (the file is the unit) and used only by readers that display a section; `goals` -- no
script reads it; the heading is kept and returned for design-discussion and onboarding. Path rules,
enforced at `set` and in the parser: not empty, no leading `/` or `~`, no `..`/`.` component, no
trailing `/`, no blanks or backslash in the path part, no `://` (a URL). A value that is
not a path is refused with the reason. Containment is checked again at read time (realpath under the
root, symlinks that leave it refused), because a file can change after `set`.

Shared candidate lists (the fallback for an unset key), in this order, replacing the differing fixed
searches:
- roadmap: `docs/roadmap.md`, `docs/ROADMAP.md`, `ROADMAP.md`
- design: `docs/design.md` only. Every script reader accepts only that today (`check_design_anchors.sh:174`,
  `sitrep_root.sh:354-357`); `ARCHITECTURE.md` stays an `audit-project`/`discover_governance.sh` display name, untouched.
- goals: no fallback. No script reads goals; unset reads as unset, and design-discussion's own rule ("the goals its
  design or README names", `SKILL.md:135-138`) is unchanged.

An unset key keeps each reader's behaviour exactly as today, except the roadmap list, now shared (host decision):
the sit-rep gains `docs/ROADMAP.md`.

**Part 1 (PR 1): settings, helper, script readers, tests, design text. Does not touch the two skills named below.**

1. **Keys** — in `_project_registry.sh` add `goals design roadmap` to `_PROJECT_FILE_KEYS`; value
   validation in `_project_file_value_error` (the grammar above); extend the header key list. Type
   `unused_settings` unchanged (every type reads them).
2. **Helper** — `project_document_path "$root" "$name" <goals|design|roadmap>` beside
   `project_records_default`. Prints one line `<source> <relpath>[#heading]`, `<source>` being `set` (key names
   an existing file), `fallback` (key unset, first existing candidate; never for `goals`), or `none` (explicit
   `none`, no path); exit 0 for these. Exit 1 with a reason when nothing exists (unset goals, or no candidate
   file, or a set key whose file is missing), exit 2 for a malformed file or a path that leaves the root. PR 2
   needs the field: onboarding offers a `fallback` candidate, design-discussion asks when the key is unset.
   Also `project_document_name_for_root "$root" "$dir"` wrapper using `registry_resolve_session_dir`; an
   unregistered root (the workspace itself) has no name and uses the candidates only. A thin CLI
   `project_setting.sh doc <name> <key>` prints the same line (no skill edits in PR 1; the CLI is for PR 2).
3. **`sitrep_root.sh`** — replace the `for f in docs/roadmap.md ROADMAP.md` loop (lines 322-326) with the helper;
   an explicit `none` prints `roadmap=` empty with a reason line; print a `design=` line beside `roadmap=`
   (empty with a reason for `none`); `check design_anchors/documentation/decision_register` (lines 354-357) take
   the design path from the helper (decision_register too, since it reads the same file); update the header
   lines 21-22 and 53-55. Unset gives `docs/design.md` exactly as today.
4. **`update_roadmap.sh`** — with the key set, edit that file only; unset, keep ticking every existing
   candidate of the shared list (the list now matches the sit-rep's); `none` is a clean no-op with a message.
   Update header line 12; the case-insensitive-filesystem dedupe stays.
5. **`check_design_anchors.sh`** — the root's design file comes from the helper (`DESIGN=` at line 174),
   so a project whose design key names another file is checked against its headings. The citation grammar
   (header lines 18-66) recognises `<design key path>#<section>` as a root citation, and that path is no longer
   treated as a part design even when its file name is `design.md` (e.g. `docs/arch/design.md`); parts are
   recognised as today. `none` skips the root-design checks with a message (today a missing design is exit 2;
   unset keeps that).
6. **`sitrep_checks.sh`** — header only: `--roadmap` default is the helper's result, not fixed `docs/roadmap.md`
   (`sitrep_root.sh` already passes the path; make the default call the helper).
6a. **`.claude/skills/sitrep/SKILL.md`** (not one of #452's files) -- Audit (line 868) and Documentation
   (lines 915-921) read the design path from the `design=` line of `sitrep_root.sh` (as lines 113/314/575/776
   already read `roadmap=`) instead of `docs/design.md`; text at lines 77, 949, 968 says "the design file".
6b. **Merge-gate bookkeeping** -- `_bookkeeping.sh:22` `BOOKKEEPING_ROADMAP_PATHS` is a fixed list feeding
   `_review_bookkeeping_between` (line 190) and `merge_pr.sh:1663` `MERGE_PR_CI_BOOKKEEPING_PATTERNS`. Add a
   function in `_bookkeeping.sh` that returns the list plus the path the `roadmap` key names (project name via
   `project_document_name_for_root`; unset or unregistered adds nothing), and have both call sites use it, so a
   post-review tick of a key-named roadmap stays bookkeeping.
7. **Tests** — new `test_project_documents.sh` (chmod +x; registered in the test runner the way the
   other `test_*.sh` are) for the helper: set, unset, `none`, bad value rows (absolute, `..`, `~`, URL,
   blank, symlink out), heading kept, missing file, unregistered root, a part also named in the pointer
   table (helper resolves the root's own key only; the pointer table is untouched). Extend
   `test_project_registry.sh` (key accepted, refused values, `set` validates), `test_sitrep_root.sh`
   (roadmap from key, `none`, fallback order), `test_update_roadmap.sh` (key set edits only that file;
   `docs/ROADMAP.md` now in both readers; none; `--root` finds the project name through
   `project_document_name_for_root`, an unregistered root uses the candidates), `test_design_anchors.sh` (key
   naming a non-`design.md` file; key naming a `design.md` that is not `docs/design.md`, not also a part design;
   key with `#heading`; `none`), and the sit-rep skill's tests if any grep the paths. Helper tests also cover
   the `source` field (`set`/`fallback`/`none`), unset `goals` exit 1, `#heading` refused on `roadmap`. Bookkeeping:
   cases in `test_merge_pr_gate.sh` (and the bookkeeping test file if one exists) for a roadmap tick at a key-named
   path counted as bookkeeping, and an unrelated file at that path's neighbour not counted.
8. **Design text (same PR, ADR-0017)** — `docs/design.md#documentation-layers`: Target status
   `proposed` to `decided` for the mapping, drop "not decided", name the three settings and the
   fallback for an unset one, the inside-the-project rule and `none`; the "Now" text about
   `update_roadmap.sh` candidates; `#registry-and-adapters`: the three keys; `#open-questions` OQ-1 is answered for where a
   project records its mapping (the settings file), for three roles (goals, design, direction); the other four of
   the seven roles stay unmapped, and the text says so (not "the Target is decided" for all seven); change-log row. `docs/roadmap.md` Direction **Format** paragraph: one line that
   the grammar applies to the file the `roadmap` setting names. Check the line budget of the Documentation
   layers section (already past the 60-line prompt; keep additions to a few lines).
9. **Reference docs** — `.agent/knowledge/script_reference.md` rows for `project_setting.sh` (new keys, `doc`),
   `update_roadmap.sh`, `sitrep_root.sh`; `project_setting.sh` help text.

**Part 2 (PR 2, after PR 1 merges; edits the skills; merge main first if #452 landed): skills.**

10. **`onboard-project/SKILL.md`** step 3 (footprint questions): ask for the three locations when unset
    (offer the detected candidate, `none`, or decide later; decide later keeps keys unset), store with
    `project_setting.sh set`; step 5 reads the roadmap through the helper, not `docs/roadmap.md`.
11. **`audit-project/SKILL.md`**: the `ARCHITECTURE.md` / `docs/design.md` check (line 186) reads the design key, keeping `ARCHITECTURE.md` as an accepted name;
    report a key naming a missing or untracked file, and a key naming a file the root's pointer table also names.
12. **design-discussion `SKILL.md`** (lines ~126-138): resolve roadmap/design/goals through `project_setting.sh doc`
    and ask when the source is not `set`/`none` (unset goals, `fallback` roadmap/design: "suggested, ask")
    instead of assuming `docs/roadmap.md`; the "goals its design or README names" rule stays.
12a. **`project_integration_audit.sh:941`** -- the ignore-rule check for `docs/roadmap.md` follows the roadmap key's
    path (with `docs/roadmap.md` when unset).
13. **Tests** — extend the skill-consistency tests if any grep these paths; run `make lint`, `make validate`.

## Files to Change

| File | Change | Part |
|---|---|---|
| `.agent/scripts/_project_registry.sh` | keys, value validation, `project_document_path` (with source field), header | 1 |
| `.agent/scripts/_bookkeeping.sh`, `merge_pr.sh` | roadmap bookkeeping paths include the key's path | 1 |
| `.claude/skills/sitrep/SKILL.md` | design path from `design=` line | 1 |
| `.agent/scripts/project_integration_audit.sh` | roadmap ignore-rule check follows the key (line 941) | 2 |
| `.agent/scripts/project_setting.sh` | help, `doc` subcommand | 1 |
| `.agent/scripts/sitrep_root.sh`, `sitrep_checks.sh` | read roadmap/design via helper, `design=` line; headers | 1 |
| `.agent/scripts/update_roadmap.sh` | key-aware candidates | 1 |
| `.agent/scripts/check_design_anchors.sh` | design file from helper | 1 |
| `.agent/scripts/tests/test_project_documents.sh` (new, `chmod +x`) and existing tests (registry, sitrep_root, update_roadmap, design_anchors, merge_pr_gate) | cases above | 1 |
| `docs/design.md`, `docs/roadmap.md` | Target, Now, keys, OQ-1, change log, Format line | 1 |
| `.agent/knowledge/script_reference.md` | rows | 1 |
| `.claude/skills/onboard-project/SKILL.md`, `audit-project/SKILL.md`, `design-discussion/SKILL.md` | question, audit, resolution | 2 |

## Prior Art

`project_records_default` and the `location`/`tracking` keys (#332) are the model for keys, validation and
`set`/`unset`; `sitrep_checks.sh` and `check_design_anchors.sh` already follow the Sub-roadmap table
(kept as is). The records lookup (#393) was considered and rejected as the home (owner, Q1). Outside
paths and repositories rejected (owner, Q2).

## Serves

Goal "Light touch on projects" (`README.md#workspace-goals`, heading checked), under
`docs/design.md#documentation-layers` and `docs/design.md#registry-and-adapters`.

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
| roadmap path other than the fixed three | merge-gate bookkeeping list (`_bookkeeping.sh`, `merge_pr.sh`) | Yes (PR 1) |
| design path read by scripts | `.claude/skills/sitrep/SKILL.md` Audit/Documentation | Yes (PR 1) |
| roadmap ignore rule check | `project_integration_audit.sh:941` | Yes (PR 2) |

## Open Questions

- Fallbacks (host decision, owner may veto): `design` is `docs/design.md` only; `goals` has none.
- `update_roadmap.sh` with an unset key keeps ticking every existing candidate (as today) rather than only the first; stated so the sit-rep and it agree on the list, not on first-only.
- PR 2 waits on #452 only for a textual merge; PR 1 does not touch its files.

## Estimated Scope

Two pull requests: PR 1 (settings, helper, sit-rep/update_roadmap/design-anchors/bookkeeping readers, sit-rep skill, tests, design text), PR 2 (three skills and the integration-audit check).
