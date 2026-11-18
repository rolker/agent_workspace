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

## Checkpoint
**When**: 2026-11-18 15:05 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the review's actions narrow nothing the owner asked for; the owner started this drive on 2026-11-18 with "do 1 and 2")
**After**: issue-actions
**Decision**: proceed

Proceed to planning, with these instructions for the plan:
- Scope stays the tool's documents under tools/repos-manifest/ (the issue's tools/ros-manifest paths are the old name). The plan lists every place the layout rule touches: "More than one distro", the config.yaml table, the "Three machines" examples, "What is built", the README, and the roadmap line.
- The plan puts first, and marks as what init and sync (issue 500) wait for: the layout rule from the first distro on; what config.yaml holds; the init flags and what init does in a directory that already exists; where state.yaml and resolved/ go.
- The owner's requirement, in his words: several distros in one project root, "starting with one, adding more", without moving the first. He also said a small project should be able to start as little more than vcs and colcon and grow later, so the plan says what the smallest system looks like under the new rule and does not make one repo on one distro heavier than it has to be.
- Choices that change the design and are hard to undo are listed in the plan as open questions for the owner at the plan checkpoint, each with a recommendation: distro directories always or only on request; distros always a list in config.yaml; local_manifest per distro; a manifest version per distro; what happens to a system made without distro directories.
- The six things the workspace asks of the tool (docs/manifest/design.md, "What the tool has to give") are not in this issue, except the one overlap: what init does in an existing directory. A separate issue for the rest is the owner's to open; the host will propose it.

## Plan Authored
**Status**: complete
**When**: 2026-11-18 15:07 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-495/plan.md` at `46fbb9f6`

Distro directories from the first distro on, config.yaml with a list of distros, and `init --distro` adding a distro to an existing directory; the plan leads with the section issue 500 waits for, draws the smallest system before and after a second distro, lists every place in the tool's documents the rule touches, and puts five open questions with recommendations to the owner.

## Plan Review
**Status**: complete
**When**: 2026-11-18 15:10 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #495 — repos-manifest design: start with one distro and add more later, without moving the first
**Plan**: `.agent/work-plans/issue-495/plan.md` at `46fbb9f6`
**Branch**: `feature/issue-495`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Documents only, four files, one PR. The section issue 500 waits for is put first and committed on its own. |
| Issue alignment | Needs work | Covers the layout rule, config.yaml, adding a distro, the flat case and the per-distro-settings question, and every action of the Issue Review and the Checkpoint. Serves, as checked: "Workspace goals "Flexibility" and "Easy to use" (README); `tools/repos-manifest/docs/design.md#more-than-one-distro` and `#the-system-directory`; workspace side `docs/manifest/design.md#a-project-instance-is-a-system-directory`" (README headings at lines 62 and 90, the three anchors exist). But the issue's first bullet says `init` "can be told" to use distro directories for one distro, which is option B of open question 1; the plan recommends A without saying that A departs from the issue's text (finding 6). |
| File targeting | Needs work | Right four files. The table of places misses text the new rule makes false (finding 4). |
| Consequences | Needs work | Missed: the `Commands` walk-through (`source setup.bash` at the top), "Not covered" (`distro` is recorded), the `resolve` section's output path, `show`/`resolve` distro choice inside a system directory; what `sync` does when a manifest gains or drops `distros:`. |
| Principle alignment | Needs work | "Only what's needed": `per_distro` and `init`'s second meaning add shape the owner's own case does not need (findings 1, 2). "Ask about what matters": the `init`-versus-own-command choice is design-changing and is decided silently (finding 2). "Keep one current design" and "Look for prior art" are answered. Docs-only, no test, said so implicitly by "documents only". |
| ADR compliance | Good | ADR-0017 and ADR-0022 handled: the part's design is edited in place, the root's design changes in one sentence. ADR-0001 rightly not triggered. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Principle alignment — Only what's needed] (medium)** `per_distro` is not needed for the owner's case and its meaning is ambiguous. The owner's case starts with rolling (`docs/manifest/design.md` "The case it is designed for"; `docs/manifest/roadmap.md`: "Jazzy is set up ... as a second distro of the same root"), and the spec says the rolling copy lists every distro (spec.md "Copies of a manifest on different branches..."), so the recorded manifest already lists jazzy. The plan's own semantics, "replaces the top-level `manifest` for that distro's reads before its first sync", is either one-shot (then it need not be recorded at all) or permanent (then the text is wrong, and a system with no `local_manifest` breaks on the second sync of that distro). Simpler shape, one key: the recorded `manifest` must list every distro in `distros`; adding a distro that it does not list takes a new location, which replaces `manifest` and is accepted only if it lists all the system's distros (a newer branch does). Each distro then reads its own local copy after its first sync, as the design already says. If `per_distro` stays, say whether it is first-sync-only or every read, and make `distros` a mapping instead of a list plus a second map naming distros.
2. **[Principle alignment — simplicity] (medium)** "Add a distro" as `init --distro X` in an existing directory gives `init` two meanings, each with its own accepted and refused flags, and a third once the re-runnable `init` ask is designed (complete the record). A command of its own (`repos-manifest add-distro <d> [--manifest-ref/--manifest-path]`, name for the owner) has one meaning, needs no refusal list for `--role`/`--with`/`--fetch-from`/`--remote`, and lets issue 500's `init` simply refuse any directory that has `.repos-manifest/`. Either way this is design-changing (the CLI the adapter's `setup` row names) and belongs in the open questions; the Issue Review listed it as a blocking point ("whether `init --distro X` ... means add X or needs `--add`"), and the plan decided it without asking.
3. **[Issue alignment] (medium)** `--manifest-path` on "add a distro" contradicts open question 3's recommendation A: if rolling's manifest is at a different path, the one `local_manifest` string, the same in every distro, points at the wrong file for rolling. Drop `--manifest-path` from the add command (the path must be the same in each distro), or make `local_manifest` per distro.
4. **[Consequences] (medium)** Places the plan's table misses, from a grep of `design.md` for "distro" and "setup.bash": (a) "Commands", lines 209–223: `repos-manifest init ... --distro jazzy` then `source setup.bash` at the top, which no longer exists; it becomes `jazzy/setup.bash`. (b) "Not covered", line 649: "`distro` is recorded", a removed key. (c) "resolve", lines 271–272: writes "into `.repos-manifest/resolved/`", now `resolved/<distro>/` (or `resolved/` when flat). (d) "show", line 259, and line 225: which distro `show` and `resolve` use inside a system directory with several distros is not said; the plan gives the one-distro-at-the-top rule only for `build`. State one rule for every command once: inside a distro's directory, that distro; at the top with one distro, that one; at the top with several, `sync` and `status` act on each and the others need `--distro`. (e) `docs/manifest/design.md`'s `setup` row ("`repos-manifest init` ... for a distro the instance does not have yet (#495)"), which the Issue Review named: drop "(#495)" and keep or change the command to whatever finding 2 settles.
5. **[Consequences] (minor)** What `sync` does when the manifest's `distros:` changes shape is unstated: a flat system whose manifest gains `distros:` (resolving with no distro is then an error by spec.md "Distros"), and a distro system whose manifest drops it. Say that `sync` refuses with the same "set up a new directory" message.
6. **[Issue alignment] (minor)** Open question 1 should label the conflict: the issue's first bullet ("`init` can be told to use one directory per distro even when it is given a single distro") reads as B; the workspace design and the owner's "the first distro's directories must not move" read as A. The plan's recommendation is right, but the owner should see that it departs from the issue's wording.
7. **[Issue alignment] (minor)** The flat limit is stated only as a refusal message of `init`. The design text should say it as a limit, with the cheap way around it: a project that may later have distros names one from the start (`distros: [main]`) and pays one directory level. Moving a flat system is a re-clone or a hand move; say so plainly.
8. **[Consequences] (minor)** `state.yaml` as one shared file for every distro makes "jazzy's entries are not touched" a promise about rewriting a shared file, and two distros' syncs write the same file (the lock ask). A file per distro beside its resolved output (`.repos-manifest/resolved/<distro>/` or `.repos-manifest/<distro>/`) gives that for free. The plan leaves the shape to 500 but fixes "one file"; leave that open too, or choose per distro.
9. **[Issue alignment] (minor)** `init <manifest> --distro rolling` in a complete directory is not in the refusal list (the plan says only that the add form "takes no `<manifest>` argument"). Moot if finding 2 gives adding its own command.

### Grow path, step by step

- One repo, one distro: `init m --distro jazzy` gives `jazzy/src/my_repo`, `resolved/jazzy/`. One extra level against today. Fine.
- Layers added: unnamed layer's `src/` stays in `jazzy/`, named layers beside it. Nothing moves (a repo given a layer later is the design's existing open question). Fine.
- Second distro: nothing of jazzy moves, no hand edit, no re-clone. Holds when the recorded manifest lists the new distro (the owner's rolling-first case); for jazzy-first the plan needs `per_distro` (finding 1 gives a one-key alternative).
- Third distro: same as the second.
- Flat (no distro) to distros: not possible in place; a new directory and a re-clone or hand move. The right limit, since the unnamed variant stops resolving once `distros:` exists, but it must be stated as a limit with its way around (finding 7).

### Open questions for the owner

1. Distro directories always: agree with A. Keep it as a question, labelled as a conflict with the issue's wording (finding 6).
2. `distros` always a list: agree with A. Mechanism that follows from 1; decide it, do not ask.
3. `local_manifest` one string: agree with A, which also follows from spec.md (a repo's layer does not vary by distro); then the add command must not take `--manifest-path` (finding 3). Mostly mechanism.
4. Per-distro manifest version: disagree with A. Add option D, one `manifest` key that must list every distro, replaced when a distro is added that it does not list (finding 1), and recommend it; or B, with a refusal message. The owner's own case (rolling first) needs neither A nor C.
5. Flat for no distros: agree with A, with the limit and the way around it in the design (finding 7).
Missing: adding a distro as `init` in an existing directory or as its own command (finding 2).

### Summary

The layout rule, the `distros` list, the flat case and the section issue 500 waits for are right and close to complete; `init` and `sync` for the first distro can be built from section 1 items 1, 2 (without `per_distro`) and 4. Before implementation: settle or simplify `per_distro`, put "add a distro: `init` or its own command" to the owner, drop the `--manifest-path`/`local_manifest` contradiction, and add the missed places to the table.

### Recommended Actions

- [ ] Replace `per_distro` with the one-`manifest`-key rule (recorded manifest lists every distro; adding one it does not list replaces it with a location that does), or define `per_distro` precisely and make `distros` a mapping (finding 1)
- [ ] Add "add a distro: `init --distro` in an existing directory, or a command of its own" to the open questions, with a recommendation (finding 2)
- [ ] Remove `--manifest-path` from adding a distro, or make `local_manifest` per distro (finding 3)
- [ ] Add to the table: the Commands walk-through, "Not covered", "resolve", one distro-selection rule for every command, and the `setup` row in `docs/manifest/design.md` (finding 4)
- [ ] Say what `sync` does when the manifest gains or drops `distros:` (finding 5)
- [ ] Label open question 1 as a conflict with the issue's first bullet; decide 2 and 3 as mechanism (findings 6, 3)
- [ ] State the flat limit and the `distros: [main]` way around it in the design (finding 7)
- [ ] Leave `state.yaml`'s split to 500, or choose a file per distro (finding 8)

## Checkpoint
**When**: 2026-11-18 15:15 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: plan
**Decision**: revise

The owner answered three design questions in a dialog (2026-11-18). His answers, as chosen:

1. Distro directories: "Only when asked". A one-distro system is flat unless init is told to use a directory per distro. The option he chose was described to him as: lighter for one distro, but a system made flat can never gain a second distro in place; it needs a new directory and a fresh clone.
2. Adding a distro: "Its own command (Recommended)", for example `repos-manifest add-distro rolling` (name open). init has one job, setting up a new directory, and refuses a directory that is already set up.
3. Where a second distro reads its manifest: "Support both". One manifest that lists every distro, and a manifest per distro (project11 keeps its manifest on per-distro branches).

Host instructions for the revision (mechanism; owner may veto):
- Answer 1 reverses the plan's recommendation, so the plan is rewritten around it: flat is the default; init takes a flag that gives a directory per distro (name it in the plan); add-distro works only on a system made with that flag and otherwise refuses, changing nothing, with a message that says nothing is moved and how to set up a new directory. The design states this plainly as a limit, where a reader choosing at init will see it, not only in a refusal message.
- In config.yaml the list of distros has one shape whether there is one or several (the Plan Review agreed; it follows from wanting no rewrite of the settings when a distro is added). The layout choice is recorded there too.
- Answer 3: keep it as small as supporting both allows. Distros are named in one place in config.yaml (the Plan Review's suggestion: a mapping whose entries may carry a manifest), with the top-level manifest used by any distro that has none of its own. Say exactly which manifest is read when, for every read and not only the first, so the second sync of a distro with its own manifest works.
- local_manifest stays one path, the same in every distro; add-distro takes no flag for it (Plan Review finding 3).
- Take every other Plan Review finding: the places in the documents the table missed (finding 4), what sync does when the manifest gains or drops distros (5), one rule for which distro every command uses inside a system directory, state.yaml's shape left to issue 500 (8).
- A manifest with no distros stays flat and has nothing to add.
