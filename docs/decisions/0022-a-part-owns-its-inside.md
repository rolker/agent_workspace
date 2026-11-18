# ADR-0022: A Part Owns Its Inside

## Status

**Accepted** (2026-11-18, #488). Owner decisions of 2026-11-18 on #488
("Part owns its inside"; written as a new decision record; no limit on
levels of planning and design). Scopes
[ADR-0017](0017-design-document-is-the-current-picture.md) without
editing it ([ADR-0008](0008-permit-cross-reference-addendums-in-adrs.md)).

## Context

ADR-0017 makes one design document the current picture of how the parts
fit, and the roadmap's `## Direction` section is the one place the
sit-rep reads the next step from. Some parts of a root have grown goals,
a design and an order of work of their own. Two were drafted in
November 2026: the manifest tool's (`tools/ros-manifest/docs/` with its
own spec, design and roadmap, #486) and the workspace's manifest support
(`docs/manifest/design.md` and `roadmap.md`, #487). The same can happen
in a project. With one picture per root, either the root's design copies
the part's mechanics, which then drift, or the part's documents are
invisible to the checks: no script follows a pointer, and the anchor
check reads any `docs/design.md#x` as a citation of the root's design.

The owner was asked where the boundary sits between the root's design
and a part's, and chose "Part owns its inside". On levels he said: "only
support one level with the scripts ... but I see no reason to not allow
however many levels of planning and design I need for my work."

The rule was checked against the two drafts before it was written down.
`tools/ros-manifest/docs/` (#486, pull request 494): the root's
`docs/design.md` on `main` names the tool only at its boundary (the
resolver, installed by `make install-ros-manifest`, called by CLI from
the adapter) and holds no resolver mechanics; it conforms as it stands.
The workspace's manifest support (#487): on `main`, the Registry and
adapters bullet for the manifest route mixes what crosses the boundary
(the settings `source`, `source_ref`, `source_path`; the registry line's
`role=` and `distro=`; one source only; never silently stale; network
needs) with route mechanics that `docs/manifest/design.md` gives step by
step (the flock on `configs/.lock.source`, the relinked generated
directory and what is kept, what `validate` compares). So the rule does
not hold for that bullet as written; the #487 branch trims it to the
boundary and a pointer at `manifest/design.md` (its commit "the manifest
text in the main design keeps what crosses the boundary").

## Decision

1. A root (the workspace, or a registered project) may have parts, and a
   part may carry its own goals, design and roadmap. Nothing requires
   it: a project is never made to split its documents.
2. A part owns its inside. The root's design describes a part only by
   what crosses its boundary (what the rest of the root calls, reads or
   sets, and what it can rely on) and points at the part's design, which
   is the one current picture of that part. Mechanics, steps and
   internals are in the part's design only. ADR-0017's "one current
   picture" holds per owner: one for the root, one for each part.
3. The rule sets no limit on levels: a part may have parts, each with its
   own documents, as the work needs. What the tools follow is a separate
   matter (5).
4. Pointer. The root's roadmap points at a part's roadmap in its
   `## Direction` section, with a `| Sub-roadmap | Root |` table: the
   sub-roadmap file, and the directory its checks' paths are relative to.
   Prose links elsewhere in the roadmap may stay for the reader; the
   table is what the tools read.
5. Levels followed. The sit-rep's checker follows one level today: the
   root's pointers are read, a pointer inside a sub-roadmap is listed as
   not followed and is not a problem. That is a limit of the checker,
   changed in the checker alone, not a limit of the rule or the pointer.
6. Citation. A part's design is cited by its path and section,
   `<path>/design.md#<section>`, where `<path>` is the directory of the
   design file (`tools/ros-manifest/docs/design.md#<section>`,
   `docs/manifest/design.md#<section>`). The anchor check resolves it against
   that file's headings, never the root's.
7. Serves. Work inside a part serves a goal of the root (a section of the
   root's goals) and may also name the part's own goal, citing the part's
   design section by the form above.
8. A part in another repository is cited by URL. A pointer to a roadmap
   in another repository is not supported until there is a case.

## Consequences

- `docs/design.md` (Documentation layers) says what a part is, the
  pointer table, the boundary and the one level followed; its Rules
  table gains a row for the part-citation check (`hook`) and one for the
  boundary rule (`review only`, a row in the principles review guide
  under "Keep one current design").
- `sitrep_checks.sh` follows the pointer table one level, with row kinds
  for parts that keep a part's lines out of the root's totals, and gives
  each part's next step from the saved rows; the sit-rep reports it in
  every run and marks work a part's line names with the part's
  sub-roadmap path.
- `check_design_anchors.sh` checks citations of a part's design against
  the part's headings, and reads the part's design and roadmap as citers.
- The review skills accept a part's design section in Serves and Design
  Picture lines.
- The rule applies to text written after it and to text a change
  touches; the manifest-route bullet is trimmed by #487.
- Following deeper pointers, or pointers across repositories, is a later
  change to the checker and the pointer grammar, made when a case needs
  it.
