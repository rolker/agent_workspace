---
issue: 495
---

# Issue #495 — repos-manifest design: start with one distro and add more later, without moving the first

## Issue Review
**Status**: complete
**When**: 2026-11-18 15:20 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Issue**: #495

### Scope Assessment

**Well-scoped?** Yes, with one split and one sharpening. Changing "layout is chosen at `init`; one distro means no distro directories" to "distro directories from the first distro on, and `init --distro` adds a distro to an existing directory" is one design-and-roadmap edit. Two things the issue should say that it does not: (a) what `config.yaml` holds, since that is what `init` writes and issue 500 builds, and (b) the six asks from the workspace design ("What the tool has to give") belong in a separate issue, not here (see Recommendations).
**Right repo?** Yes. The tool's documents live in `tools/repos-manifest/` in this repo (a part with its own design, ADR-0022). The issue and #500 still say `tools/ros-manifest/...`; the directory is now `tools/repos-manifest/` (verified), so the paths in both issues are stale.
**Serves**: the root goals "Flexibility" and "Easy to use" (README#workspace-goals), through the part's own design, `tools/repos-manifest/docs/design.md#more-than-one-distro` and `#the-system-directory`; the workspace side is `docs/manifest/design.md#a-project-instance-is-a-system-directory`, which already says each distro is in its own directory "from the first distro on, so that adding a distro later moves nothing".
**Design picture?** Changes the tool's own design (`tools/repos-manifest/docs/design.md#more-than-one-distro`, `#config-yaml`, `#the-system-directory`, "What is built", "Open questions"). The root design needs no change: it already states the target, and the owner's decision is recorded in the issue (2026-11-18). The tool's text is what contradicts it today.
**Dependencies**: #494/#486 are merged and closed. Blocks #500 in part (below). The workspace roadmap line "The tool's design covers starting with one distro in a directory of its own and adding a distro later (#495)" is checked by `gh-issue 495 closed`, so closing this issue satisfies it.

### What the design says today, against what the issue asks

- `design.md` "More than one distro" ends: "The layout is chosen at `init`. A system directory set up for one distro has no distro directories." That is the sentence to reverse. `config.yaml` has `distro` (one) or `distros` (list), "in place of" each other, so going from one to two changes the key too, not only the directories.
- The tool's own worked examples assume the old rule: "A field machine" records `distro: jazzy` and its layout is flat. Whether a one-distro system is still allowed flat is a decision the issue's "what happens in a flat system" bullet depends on.
- `resolved/<distro>/` and `state.yaml` "for each distro when there is more than one" are already per distro in the diagram; with distro directories always, the "when there is more than one" wording goes.
- `local_manifest` is a single string in `config.yaml` but is described as "a path inside the distro's directory". One string cannot name a path per distro. This is the same open question the issue lists as optional, and it is not optional: the first distro's `local_manifest` exists before the second is added.
- The workspace's own example uses a manifest read from branch `jazzy` (`--manifest-ref jazzy`) because project11 keeps manifests on distro branches. Adding `rolling` to that directory needs a way to say that rolling's manifest is read from a different ref, or the design must say it cannot be done and the second `init --distro` gets the same `manifest`.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Keep one current design | OK | The tool's design is the document that changes; the root design already states the target and the issue records the owner's decision. Name the tool sections above in the plan. |
| A change includes its consequences | Action needed | The sentence "A system directory set up for one distro has no distro directories", the `distro`/`distros` rows of the `config.yaml` table, the "Three machines" examples, "What is built", the README line on side-by-side distros and the existing roadmap line "A system directory can hold more than one distro, each in its own directory" all change with the layout rule; the issue lists only "More than one distro" and the roadmap. Also reword #500's "A directory per distro" bullet once this settles. |
| Verify before claiming | Action needed | The issue and #500 cite `tools/ros-manifest/docs/design.md`; the directory is `tools/repos-manifest/`. Correct the paths (a comment or an edit by the owner; this review does not edit the body). |
| Only what's needed | Watch | Keep the per-distro-settings answer minimal: record only what the first real case (project11: jazzy and rolling, manifests on distro branches) needs, and leave the rest open with a line saying so. |
| Ask about what matters, and show how much | Watch | Two choices change what `init` writes and are hard to undo once #500 ships: whether a one-distro system can still be flat, and how `config.yaml` names distros. The plan should propose both with a default and show them to the owner at the plan checkpoint. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0022 | Yes | Work inside a part's design; the root's design changes only where what crosses the part boundary changes, and here it does not. |
| 0017 | Yes | The design document is the current picture; no ADR needed, the tool's design is edited in place. |
| 0001 | No | No decision between independent options that needs an ADR; the owner's decision is already in the issue. |

### Consequences

- `tools/repos-manifest/docs/design.md`: "More than one distro", the `config.yaml` table, the "Three machines" examples, `status`/`freeze`/`build` wording that says "when there is more than one distro", "What is built", "Open questions".
- `tools/repos-manifest/docs/roadmap.md`: the existing line for several distros in their own directories (reword it to cover starting with one and adding another) and any line the six-asks issue adds.
- `tools/repos-manifest/README.md` line on distros side by side; `docs/manifest/design.md` table row for `setup` ("for a distro the instance does not have yet (#495)") keeps pointing at the right command once the flags are settled.
- Issue #500's text (paths, and the bullet that sends the six asks to #495).

### The six asks from the workspace design

Separate issue. They are about robustness and the adapter becoming thin (`docs/manifest/design.md#what-the-tool-has-to-give`), not about layout, and none changes what `init` writes except the re-run one. Putting them here would make a one-edit layout issue wait on six designs and would hold #500 for no reason; #500 already excludes them. Against the tool's design today (grep of `design.md` finds no lock, time limit or atomic replacement):

| Ask | Covered by the tool's design now? |
|---|---|
| A status a script can read, with an exit status | No. `status` is "shows what the system directory holds"; no machine form, no exit status, no role/distros output. |
| A lock against two runs | No. |
| Time limits on fetches | No. Only the git password prompt behaviour (asks at a terminal, fails without one) is described. |
| A failed resolve changes nothing | No. `resolve` is described as writing the files; what a failure leaves behind is not. |
| A re-runnable `init` | Partly. "A first sync that fails part way is finished with `sync`", and `sync` does not clone again; `init` over an unfinished directory is not described (init says "a new system directory"). |
| A manifest named by a commit | No. The git form takes a branch or tag; repo versions may be commits, the manifest's location may not. |

One overlap to settle here, not there: `init --distro <name>` in a directory that already has a record is a second kind of re-run of `init`. This issue must say what `init` does in an existing directory (adds a distro when `.repos-manifest/` is complete; what it does when it is not complete belongs to the re-run ask), so the two issues do not define it twice. The lock ask also covers adding a distro, since it writes `config.yaml` while `sync` may be reading it.

### What blocks #500

Blocks #500 (settle first, small):
1. The directory layout rule: distro directories from the first distro on, always, or for one distro by an option. #500 says "the unnamed first layer's `src/` directly in the system directory", which is only right if there are no distro directories.
2. What `config.yaml` holds: `distros: [..]` always (a one-distro system is a list of one), or `distro` and `distros`; and the `local_manifest` shape given one path per distro.
3. The `init` flags: repeated `--distro`, and whether `init --distro X` in an existing directory means "add X" (the issue's text) or needs `--add`.
4. Where `state.yaml` and `resolved/` go (already `resolved/<distro>/`; state for each distro).

Does not block #500: the text for adding a second distro with its commands, what happens in a system set up flat (if flat stays allowed, #500 can refuse to add a distro to it with a message), per-distro manifest ref/role (leave open), the roadmap line, the six asks. #500 can start on the first-distro `init` and `sync` once points 1 to 4 are written; "add a distro" can come as a later step.

### Recommendations

- Settle the four blocking points first and land them as the first commit, so #500 can start; do the rest of the edit, the consequences list and the roadmap in the same PR.
- Make the per-distro layout the only layout for a system with a `distro`/`distros` setting, with `distros: [..]` in `config.yaml` always a list, so no key changes when a second distro is added; say plainly that a manifest with no distros gives the flat colcon layout and has nothing to add.
- Say what `init --distro <name>` does in an existing directory: add the distro when the record is complete, refuse with a message when the named distro is already there, and leave an incomplete record to the re-run ask; and what it does in a flat directory: refuse, state that nothing is moved, and say how to set up a new directory instead.
- Settle the per-distro settings question at the smallest size the first case needs (a per-distro `manifest` ref and `local_manifest` path), or leave it open with a sentence saying that a second distro reuses the first one's `manifest` and `role`; do not leave `local_manifest` as one string.
- Open a separate issue for the six asks in `docs/manifest/design.md#what-the-tool-has-to-give`, make it depend on this one for the `init`-in-an-existing-directory rule only, and change #500's "part of the design follow-up (#495)" wording to point there.
- Correct `tools/ros-manifest/...` to `tools/repos-manifest/...` in this issue and #500.

### Actions
- [ ] The sentence "A system directory set up for one distro has no distro directories", the `distro`/`distros` rows of the `config.yaml` table, the "Three machines" examples, "What is built", the README line on side-by-side distros and the existing roadmap line "A system directory can hold more than one distro, each in its own directory" all change with the layout rule; the issue lists only "More than one distro" and the roadmap. Also reword #500's "A directory per distro" bullet once this settles.
- [ ] The issue and #500 cite `tools/ros-manifest/docs/design.md`; the directory is `tools/repos-manifest/`. Correct the paths (a comment or an edit by the owner; this review does not edit the body).
- [ ] Settle the four blocking points first and land them as the first commit, so #500 can start; do the rest of the edit, the consequences list and the roadmap in the same PR.
- [ ] Make the per-distro layout the only layout for a system with a `distro`/`distros` setting, with `distros: [..]` in `config.yaml` always a list, so no key changes when a second distro is added; say plainly that a manifest with no distros gives the flat colcon layout and has nothing to add.
- [ ] Say what `init --distro <name>` does in an existing directory: add the distro when the record is complete, refuse with a message when the named distro is already there, and leave an incomplete record to the re-run ask; and what it does in a flat directory: refuse, state that nothing is moved, and say how to set up a new directory instead.
- [ ] Settle the per-distro settings question at the smallest size the first case needs (a per-distro `manifest` ref and `local_manifest` path), or leave it open with a sentence saying that a second distro reuses the first one's `manifest` and `role`; do not leave `local_manifest` as one string.
- [ ] Open a separate issue for the six asks in `docs/manifest/design.md#what-the-tool-has-to-give`, make it depend on this one for the `init`-in-an-existing-directory rule only, and change #500's "part of the design follow-up (#495)" wording to point there.
- [ ] Correct `tools/ros-manifest/...` to `tools/repos-manifest/...` in this issue and #500.
