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

## Plan Authored
**Status**: complete
**When**: 2026-11-18 15:18 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)
**Plan**: `.agent/work-plans/issue-495/plan.md` at `e7f02e02`

Revised around the owner's three answers: flat by default with `init --distro-dirs` for a directory per distro, `add-distro` as its own command (flat systems refuse), and `distros` as a mapping in config.yaml whose entries may carry their own manifest. The plan states which distro and which manifest each command reads, what `sync` does when `distros:` changes, and every place the rule touches, including five sentences of docs/manifest/design.md.

## Plan Review
**Status**: complete
**When**: 2026-11-18 15:20 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: needs-work

**Issue**: #495 — repos-manifest design: start with one distro and add more later, without moving the first
**Plan**: `.agent/work-plans/issue-495/plan.md` at `e7f02e02`
**Branch**: `feature/issue-495`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Documents only, four files, four commits; the section issue 500 waits for comes first. |
| Issue alignment | Needs work | Carries out the owner's three answers: flat by default with `init --distro-dirs` (answer 1, and now the issue's own first bullet), `add-distro` as its own command with `init` refusing a set-up directory (answer 2), and a distro entry that may carry its own manifest beside the top-level one (answer 3). Nothing beyond them except the open questions. But the host's instruction "add-distro takes no flag for it (Plan Review finding 3)" is met only for `local_manifest`: `add-distro` still takes `<manifest>` and `--manifest-path`, which is the contradiction finding 3 was about (finding 1 below). Serves, as checked: "Workspace goals "Flexibility" and "Easy to use" (README); `tools/repos-manifest/docs/design.md#more-than-one-distro` and `#the-system-directory`; workspace side `docs/manifest/design.md#a-project-instance-is-a-system-directory`". |
| File targeting | Good | The four right files. |
| Consequences | Needs work | Every quoted present text and line number checked against the files and matches. Missing: "Where the manifest comes from" L171-179 and L184-190 (finding 2). |
| Principle alignment | Needs work | "Only what's needed": the per-distro entry is a full location where a version is all the owner's case needs (finding 1). "Ask about what matters": open question 1 is the owner's; 2-4 are mechanism. Docs-only, so no test; the plan says so ("documents only"). |
| ADR compliance | Good | ADR-0017 and ADR-0022: the part's design edited in place; the root's design unchanged; `docs/manifest/design.md` changes in the sentences that describe what the workspace expects of the tool. |
| ROS conventions | N/A | Workspace plan. |

### Earlier findings (Plan Review at `46fbb9f6`)

1 answered (a `distros` mapping whose entry may carry `manifest`, used on every read); 2 overridden by the owner (answer 2); 3 not answered for `--manifest-path` and `<manifest>` (finding 1 below); 4 answered, all five places (a)-(e) are in the table; 5 answered; 6 overridden by the owner (he chose "only when asked", which is the issue's wording); 7 answered, with `--distro-dirs` as the way around; 8 answered (shape left to 500, with the one property the design needs); 9 moot (`init` refuses any set-up directory).

### Findings

1. **[Principle alignment — Only what's needed / Consequences] (medium)** The per-distro `manifest` entry is a full location, and `add-distro` takes `[<manifest>] [--manifest-path]`. With one `local_manifest` path for every distro, an entry whose URL or path differs from the top-level one gives a case where the wrong copy is read: rule 1 (the local copy) wins from the second read on, so if rolling's entry names `rolling.manifest.yaml` while `local_manifest` is `core/src/unh_marine_autonomy/project11.manifest.yaml`, and the rolling branch still carries an old `project11.manifest.yaml`, rolling silently reads that file. The full form also records `url` and `path` twice (third `config.yaml` example), so editing the top-level `manifest` after `init`, as design.md L184-187 allows, no longer reaches rolling. The owner's case for "support both" is a manifest on per-distro branches. Smallest form: an entry carries only a version (`rolling: {manifest_version: rolling}` or `manifest: {version: rolling}`), taken with the top-level `url` and `path`; `add-distro` takes `--manifest-ref` only; a manifest that is not in git is shared by every distro. If the full location stays, say that once a local copy exists it wins over the entry whatever the entry names, and have `add-distro` refuse a URL or path that differs from the top-level one when `local_manifest` is set.
2. **[Consequences] (minor)** Not in the table: design.md L171-175 ("Before the first sync that repo is not on the machine, so the manifest is read from its URL. After the first sync there is a copy in the system directory") becomes "in each distro's directory" and "read from the distro's location"; L189-190 ("Only the checkout in the system directory counts as the local copy. A copy in another clone or another branch of the same repo is not looked at.") is ambiguous once the system directory holds rolling's checkout of the same repo; it should carry the plan's own sentence "A distro never reads another distro's local copy"; L184-187 (editing `manifest` after `init`) should say it applies to every distro without an entry of its own.
3. **[Issue alignment] (minor)** `add-distro` refusing because the recorded manifest does not list the distro (the jazzy-branch case) should say how to go on: "give the version of the manifest that lists it with `--manifest-ref`". Without that line the person is left with a refusal and no next step. The same check at `init` (a `--distro` the manifest does not list) is left to the resolver's error; say so in one line so issue 500 does not have to decide it.
4. **[Issue alignment] (minor)** The `docs/manifest/design.md` text "`setup` asks for that layout (`--distro-dirs`)" reads as asking the person, which open question 1 rejects. Say "passes `--distro-dirs`". The adapter's `add-distro` also needs the ref for the new distro when the instance's recorded manifest is on a distro branch; the `setup` row should say it passes `--manifest-ref` when it has one, or that this is part of the undecided "how a session says which distro".
5. **[Principle alignment — simplicity] (minor)** In `docs/manifest/design.md` L132-134 the rewritten bullet ("a part of the tool's design that is not built") duplicates the first bullet (tool commands not built). Simpler: add `add-distro` to the first bullet's list, drop the second, and make "three things" "two".
6. **[Consequences] (nit)** The third tree labels one `state.yaml` "rolling's entries added; jazzy's as they were", while item 4 leaves one file or a file per distro to issue 500. Label it "state for rolling added" so the tree does not decide the shape.

### Walk-throughs of the manifest rule

- Per-distro, one manifest for all, with `local_manifest`: jazzy's first sync reads the top-level location; the manifest's repo is cloned at jazzy's version; from the second sync jazzy reads its own checkout (which may list only jazzy; spec.md allows that). Rolling the same, in `rolling/`. Correct.
- Same without `local_manifest`: every read is the top-level location. Correct.
- Rolling with its own version (third example), with `local_manifest`: first sync reads the entry (rolling branch), then `rolling/core/src/.../project11.manifest.yaml`. Correct. Without `local_manifest`: the entry on every read, as the plan says. Correct.
- `add-distro rolling` with no arguments when the recorded manifest (jazzy branch) does not list rolling: refuses, nothing written. Correct, but the message needs the next step (finding 3). With `--manifest-ref rolling`: entry recorded, rolling synced. Correct.
- Wrong copy read: only with an entry whose `url` or `path` differs from the top-level one while `local_manifest` is set (finding 1). No case where two of the plan's rules disagree otherwise; `add-distro` reading the top-level location and not another distro's local copy is consistent with "a distro never reads another distro's local copy".

### Which distro a command uses

One rule a person can remember: `--distro`, else the distro directory you are in, else the top. At the top the table gives every command (`sync`/`status` every distro; `show`/`resolve`/`build`/`freeze` the only one or an error listing them; `add-distro` takes its argument; `init` not run). Missing only: `--distro` naming a distro the system does not record, or any `--distro` other than the one distro on a flat system, is an error; one line.

### The limit, and the owner's path

The limit is stated where a person choosing reads it: the opening of "More than one distro", a sentence under the first diagram of "The system directory", the `init` row of Commands, the README bullet, and one line printed by `init` before its existing question. One line per `init`, no new question: enough, not a nag.

Owner's path: the workspace's `setup` passes `--distro rolling --distro-dirs` with the manifest in git form; project11's rolling branch lists every distro (spec.md, "Copies of a manifest..."). Later `repos-manifest add-distro jazzy` with no arguments reads the top-level location, which lists jazzy; `jazzy/` is created and synced; `rolling/` is untouched; from jazzy's second sync it reads its own checkout. Nothing fails and nothing needs a hand edit. The reverse order (registered on the jazzy branch, then add rolling) needs `--manifest-ref rolling`, which the adapter must be able to pass (finding 4).

### The four new questions

1. `setup` always passes `--distro-dirs` when the project has a distro: a design choice for the owner, since it decides the layout of every workspace-set-up project with a distro and means none of them is flat. Recommend yes, as the plan does: the cost is one directory level, and the person setting up often cannot yet say whether a second distro will come.
2. One distro at the top used by `show`/`resolve`/`build`/`freeze`: mechanism, host decides. Recommend as planned; the refusal after a second distro is loud.
3. `--distro` wins over the current directory: mechanism, host decides. Recommend as planned.
4. The layout line for every flat system with a named distro: mechanism, host decides. Recommend as planned: a jazzy-branch copy lists only jazzy, so "only when the manifest lists several" would hide it from exactly the case that needs it.

### Enough for issue 500?

Yes. Items 1-4 fix the layout (flat and `--distro-dirs`), the `config.yaml` keys (`layout`, `distros` mapping, `local_manifest` inside each distro's directory), `init`'s flags and its refusal of a set-up directory, and where `resolved/` goes, with the one property state needs. `init` writes only empty entries, so finding 1 does not change what 500 builds. `add-distro` can follow without redoing the layout, since each thing it writes has its place fixed.

### Summary

The revision carries out the owner's three answers without adding to them, and the section issue 500 waits for is complete. One substantive gap: the per-distro manifest entry is wider than "support both" needs, and with one `local_manifest` path it reopens the earlier finding 3; narrowing it to a version fixes that and shortens the config. The rest is a few missed sentences and wording.

### Recommended Actions

- [ ] Narrow the per-distro entry to a version and `add-distro`'s location arguments to `--manifest-ref`, or state the local-copy-wins rule and refuse a differing URL or path when `local_manifest` is set (finding 1)
- [ ] Add design.md L171-175, L184-187 and L189-190 to the table (finding 2)
- [ ] Give the "manifest does not list the distro" refusal its next step; say `init` leaves an unlisted `--distro` to the resolver's error (finding 3)
- [ ] "passes `--distro-dirs`" in `docs/manifest/design.md`; say how the adapter gives `add-distro` a ref, or that it is part of the undecided distro question (finding 4)
- [ ] Fold the second "not built" bullet in `docs/manifest/design.md` into the first (finding 5)
- [ ] Add one line: a `--distro` the system does not record is an error, flat included
- [ ] Put open question 1 to the owner; decide 2-4 as mechanism

## Checkpoint
**When**: 2026-11-18 15:22 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (the second Plan Review found the plan carries out the owner's three answers exactly and its first section complete; the six findings left are located text fixes)
**After**: plan
**Decision**: proceed

Proceed to writing the documents, with the second Plan Review's findings applied as the documents are written; where this entry and the plan differ, this entry wins.

1. A distro's own manifest entry carries only a version: `distros: {rolling: {manifest_version: rolling}}` or the like (name it in the documents), read as the top-level manifest's location with that version. add-distro takes only --manifest-ref, no <manifest> and no --manifest-path. This is the smallest thing that supports a manifest per distro on per-distro branches, which is the case the owner named; a different url or path per distro is not supported, and the design says so. Editing the top-level manifest's url or path then reaches every distro.
2. Add the three passages of design.md the table missed (where the local copy is read from; editing manifest after init; "a copy in another clone or another branch of the same repo is not looked at", now said per distro).
3. add-distro's refusal when the recorded manifest does not list the distro names --manifest-ref as the next step. A --distro the system does not record is an error for every command, flat systems included. init leaves a --distro the manifest does not list to the resolver's error.
4. docs/manifest/design.md: setup "passes --distro-dirs" (it does not ask the person); how the adapter passes a version for a new distro is left with the open question of how a session names its distro, and the text says so.
5. The "not built" bullets in docs/manifest/design.md: fold add-distro into the first bullet; "two things".
6. The trees do not decide state.yaml's shape; issue 500 does.

Host decisions on the plan's four new questions (owner may veto):
- The workspace's setup passes --distro-dirs whenever the project has a distro. The workspace's design, which the owner merged, already says a project instance "holds every distro, each in its own directory from the first distro on", and his own project starts with one distro and adds more. Undoing it: one sentence, and a flag the adapter stops passing.
- At the top of a per-distro system with one distro, show, resolve, build and freeze use it; with several they refuse and list them.
- --distro wins over the directory the person is standing in.
- init prints its one line about the layout for every flat system with a named distro.
- Names: --distro-dirs, add-distro, layout: flat | distro-dirs.

## Implementation
**Status**: complete
**When**: 2026-11-18 15:29 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Branch**: feature/issue-495 at `0436088d`

Documents only, three commits:

- `0ef3deb2` tools/repos-manifest/docs/design.md, the part issue 500 waits for: a sentence under the first diagram (it is the flat layout); `config.yaml` example and table (`layout`, `distros` mapping, `local_manifest` per distro directory, `distro` removed); "More than one distro" rewritten under the same heading: what a distro is, the layout choice made once at `init`, the limit (a flat system cannot gain a second distro in place; several distros need `init --distro-dirs` and a fresh clone), four trees (smallest flat, `--distro-dirs`, after `add-distro rolling`, with layers), three `config.yaml` examples, "Setting up with init" (flags, refusal of a directory with `.repos-manifest/`, unlisted `--distro` left to the resolver, the layout line), "Where the resolved files and state go" (state.yaml's inner shape left open). One sentence under "show" points to the layout line.
- `477bece8` the rest of design.md, README.md, roadmap.md: "Adding a distro" (`add-distro <name> [--manifest-ref <ref>] [--yes]`, nothing else; refusals with next steps, including `--manifest-ref` when the manifest read does not list the distro), "Which distro a command uses" (with the error for an unrecorded `--distro`), "Which manifest a distro reads" (local copy, else `manifest` at the distro's `manifest_version`; every read; no other URL or path per distro); "Where the manifest comes from" (local copy per distro, editing `manifest`, no reading another distro's copy); Commands table (`init` row, new `add-distro` row), a second walk-through, `show`, `sync` (per distro, and what it does when the manifest's distros change), state, `build`, `status`, `freeze`, "Three machines", "Not covered", "What is built" (`add-distro` added to the not-built list), open questions; README bullet; roadmap Direction line.
- `0436088d` docs/manifest/design.md: "not built" bullets folded (two things, `add-distro` in the first); steps 4 and 6; `setup` passes `--distro-dirs` whenever the project has a distro; the `setup` row (`init --distro-dirs`, `add-distro`, the version for a new distro left with how a session names its distro); `<distro>/<layer>/` is the layout with a directory per distro.

Read a particular way, or not done as the plan's table said:
- The `resolve` section's "writes into `.repos-manifest/resolved/`" is not edited, because pull request 506 rewrites those lines; `resolved/<distro>/` is stated in "Where the resolved files and state go". Still true as written (the per-distro directories are inside `resolved/`).
- No third `init` example under "Where the manifest comes from"; the `--distro-dirs` forms are in the second walk-through and the `add-distro` example.
- `add-distro` refuses `--manifest-ref` when `manifest` is not in a git repo (a path or URL has no version); added to make the version-only rule hold.
- spec.md: nothing in it is made false (checked its "Distros" section and every "distro" hit). prototype.md not touched.

Post-task check against issue 495: the design describes starting with one distro in the per-distro layout and adding a second later with the commands typed, and the roadmap has a line. The issue's second bullet (`init --distro` again adds a distro) is replaced by the owner's answer 2 (`add-distro`). Per-distro settings: a manifest version is settled; role, groups, a differing `local_manifest` and removing a distro are left open in "Open questions". Not done here: the issue bodies' stale `tools/ros-manifest` paths and the follow-up comment on issue 500 (host's).

Hooks: each commit ran the hooks with `SKIP=validate-script-tests` (anchor check passed). No suite applies (no script changed); the full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 15:32 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-495 at `210a5621`
**Base**: origin/main
**Depth**: Deep (reason: 438 changed lines in 4 files, documents only)
**Must-fix**: 7 | **Suggestions**: 8
**Round**: 1 | **Ship**: continue — round 1: 7 must-fix; first round always re-reviews after fixes

Specialists: static (no linter profile for .md; `check_design_anchors.sh` passed), governance, plan drift and Claude adversarial completed; cross-model gemini and codex completed (EXIT=0). The owner's three answers are carried out; no departure found. Nothing is claimed as built that is not (cli.py has only `resolve` and `validate`). The tool's documents do not mention the workspace, its adapter or `ros2_colcon`.

Writer's readings: `resolve` left unedited is not enough (must-fix 7); no third `init` example is fine; `add-distro` refusing `--manifest-ref` for a non-git manifest is right but makes the "does not list" refusal's next step impossible there (must-fix 5); spec.md unchanged is right, but one citation of it does not hold (suggestion 3).

### Findings
- [x] (must-fix) "This is the layout of a system with one distro, or none" is false for a one-distro system set up with `--distro-dirs`; say "a flat system" — `tools/repos-manifest/docs/design.md:39`
- [x] (must-fix) `init`'s refusal is not exact: say that a first sync that fails after the record is written is finished with `sync`, give a next step for a record that is not complete (`sync` cannot read it), and say whether `init` run inside an existing system (found by walking up, the table's "not run in a system directory") is refused — `tools/repos-manifest/docs/design.md:261-265,339`
- [x] (must-fix) "A directory whose record is not complete is set up by running registration again" now contradicts the tool's `init` refusing any `.repos-manifest/`; tie it to the "`init` can be run again" ask — `docs/manifest/design.md:212-213`
- [x] (must-fix) `sync`'s check: "changes nothing for it" is false once step 1 has moved the manifest's clone, and "does not list a distro the system records" reads as every recorded distro, which a jazzy-only copy (spec.md:205) would fail; say "does not list that distro" and that step 1 has already run — `tools/repos-manifest/docs/design.md:567-574`
- [x] (must-fix) `add-distro` refusals: the "manifest does not list the distro" next step (`--manifest-ref`) is refused when `manifest` is not in git, so that case needs its own next step; and nothing says what happens when a directory `<name>/` already exists in the system directory — `tools/repos-manifest/docs/design.md:304-315`
- [x] (must-fix) "A manifest that is not in a git repo has no version, and every distro reads the same file" is false when `local_manifest` is set (allowed with a non-git manifest, as the example at line 63-64 has); add "until its local copy exists" — `tools/repos-manifest/docs/design.md:362-363`
- [x] (must-fix) `resolve` "writes into `.repos-manifest/resolved/`": with a directory per distro it is `resolved/<distro>/`, and pull request 506 makes that output "replaced whole", which would then wipe the other distros' files; point to "Where the resolved files and state go" here, or record it as a fix for whichever of 495 and 506 merges second — `tools/repos-manifest/docs/design.md:537-538`
- [x] (suggestion) Refusals with no message or next step: `add-distro` for a distro already recorded (point to `sync --distro`), a manifest with no `distros:` (also `init --distro-dirs`, line 254), and `init --distro-dirs` with several distros when the manifest read lists only one (next step: set up with one, then `add-distro --manifest-ref`) — `tools/repos-manifest/docs/design.md:254,310-313`
- [x] (suggestion) Say which version the local copy is at: the manifest repo's checkout at the version the manifest gives that repo on that distro, so "one manifest for all" can read per-branch copies from the second sync on — `tools/repos-manifest/docs/design.md:350-358`
- [x] (suggestion) spec "Distros" does not say that resolving for no distro is an error when the manifest has `distros:`; cite "What resolving produces" or add the sentence to the spec — `tools/repos-manifest/docs/design.md:576`
- [x] (suggestion) The config key `layout: flat|distro-dirs` shares a name with the built `resolve --layout manifest-dir`; and the manifest's version has three names (`--manifest-ref`, `version`, `manifest_version`) — `tools/repos-manifest/docs/design.md:83`
- [x] (suggestion) "holds one distro" / "holds a single distro" should read "one distro, or none" — `tools/repos-manifest/docs/design.md:445`, `tools/repos-manifest/README.md:54`
- [x] (suggestion) The `setup` row sends the new distro's version to "Not decided", whose item names only how a session says its distro; add the version there — `docs/manifest/design.md:192,331`
- [x] (suggestion) How `init` decides the manifest's repo "is one the manifest lists" (URL match across ssh and https forms) and which distro's path it records when the repo is absent on one distro — `tools/repos-manifest/docs/design.md:420-422`
- [x] (suggestion) Style: "The smallest system, one repo on one distro with no layers and no roles, set up flat." is not a sentence — `tools/repos-manifest/docs/design.md:117`

## Implementation
**Status**: complete
**When**: 2026-11-18 15:37 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-495 at `ab08db1e`
**Addressed**: Local Review (Pre-Push) at `210a5621` (2026-11-18 15:32 -05:00)
**Commits**: 647a797d, bad71794, 5598c188, 61dc1df1, 1a69daac, de50d573, bc48becc, 0236dfc9, ed644fc3, 98c9f61a, a0b98fca, 4c694232, 66608cf8, b074f407, 4f80cdc1, ab08db1e

### Actions
- [x] (must-fix 1) The first diagram is "the layout of a flat system, the default" — `tools/repos-manifest/docs/design.md:39`
- [x] (must-fix 2) `init` writes `.repos-manifest/config.yaml` whole before it clones anything; a failed or interrupted first sync is finished with `sync`; `init` refuses a directory with `.repos-manifest/` and any directory inside an existing system (found by walking up), changing nothing, with a quoted message naming `sync` and `add-distro`; a missing or unreadable `config.yaml` is an error from every command that names the file and what is wrong, with no promised repair. The "Which distro" table row and the Commands row follow — `tools/repos-manifest/docs/design.md` "Setting up with init"
- [x] (must-fix 3) Registering again over an incomplete record is tied to the ask "`init` can be run again"; today's tool design refuses — `docs/manifest/design.md` "A project instance is a system directory"
- [x] (must-fix 4) `sync`'s check runs after step 1: the manifest's own clone has been updated, nothing else of that distro is changed (not resolved, no repo touched); the condition is "the manifest this distro reads no longer lists it" — `tools/repos-manifest/docs/design.md` "sync"
- [x] (must-fix 5) `add-distro`, distro not listed: `--manifest-ref` as the next step when `manifest` is in git, "add it to the manifest's `distros:`" when it is a path or URL not in git; an existing `<name>/` that is not a recorded distro is a refusal naming the directory — `tools/repos-manifest/docs/design.md` "Adding a distro"
- [x] (must-fix 6) "every distro reads the same file until its local copy exists" — `tools/repos-manifest/docs/design.md` "Which manifest a distro reads"
- [x] (must-fix 7) One paragraph added at the end of the `resolve` section (its first lines, which pull request 506 rewrites, untouched): a distro's files go in `resolved/<distro>/`, resolving one distro never touches another's, pointer to "Where the resolved files and state go" — `tools/repos-manifest/docs/design.md` "resolve"
- [x] (suggestion 1) Quoted messages with next steps for every `add-distro` refusal (already recorded points to `sync --distro`; no `distros:`; `--manifest-ref` on a non-git manifest); `init --distro-dirs` on a manifest with no `distros:` says to set up flat; `init` with distros the manifest lists only some of says to set up with those and `add-distro --manifest-ref` the rest — `tools/repos-manifest/docs/design.md`
- [x] (suggestion 2) The local copy is the manifest's repo as the distro syncs it, at the version the manifest gives that repo on that distro, so per-branch copies are read from the second sync on — `tools/repos-manifest/docs/design.md` "Which manifest a distro reads"
- [x] (suggestion 3) Cite "What resolving produces" in the specification; spec.md not changed — `tools/repos-manifest/docs/design.md` "sync"
- [x] (suggestion 4) `layout` kept, called the system directory's layout, unrelated to `resolve --layout`; where `manifest_version` is introduced: it is what `add-distro --manifest-ref` records, as `init --manifest-ref` records `version` in `manifest` — `tools/repos-manifest/docs/design.md:83,199`
- [x] (suggestion 5) "one distro, or none" in the Commands `init` row and the README — `tools/repos-manifest/docs/design.md`, `tools/repos-manifest/README.md:54`
- [x] (suggestion 6) "Not decided" names how a session gives the manifest version for a distro it adds — `docs/manifest/design.md` "Not decided"
- [x] (suggestion 7) How `init` matches the manifest's repo by URL, and that a distro where it is absent has no local copy and reads the recorded location — `tools/repos-manifest/docs/design.md` "Where the manifest comes from"
- [x] (suggestion 8) "The smallest system is one repo on one distro ..." — `tools/repos-manifest/docs/design.md:117`

Host decisions applied as given (listed for the owner's veto): must-fix 2, 3, 4, 5, 7 and suggestions 4 and 7 as the handoff worded them.

One addition beyond the host's wording, for the host's or owner's veto: suggestion 7's URL rule also reads the `:` after the host in an scp-style ssh URL (`git@host:team/system.git`) as `/`; without it an ssh URL and an https URL of one repo would not match, which was the review's point.

Last commit `ab08db1e` is wording only: `init`'s refusal says "A system is already set up here: <system directory>" (it may be run from a subdirectory), and a line over the width is wrapped.

Checks: the four documents grepped for "distro", "init" and "resolved", every changed hit read against the rules; "workspace" hits in the tool's documents are all "colcon workspace"; no mention of the adapter, `.agent/` or `ros2_colcon`; nothing claimed as built beyond `resolve` and `validate`. `bash .agent/scripts/check_design_anchors.sh` printed nothing and exited 0. Every commit ran the hooks with `SKIP=validate-script-tests`; no script changed, so no suite applies; the full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 15:44 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-495 at `486400a9`
**Base**: main
**Depth**: Deep (reason: whole-branch diff, 1295 changed lines in 6 files, documents and timeline only; fix-round rule)
**Must-fix**: 5 | **Suggestions**: 12
**Round**: 2 | **Ship**: continue — round 2: 5 must-fix is high (falling from 7); all five are located text fixes

Specialists: static (no linter profile for .md; `check_design_anchors.sh` printed nothing, exit 0), governance, plan drift (files match the plan's table; no drift) and Claude adversarial completed; cross-model gemini and codex completed (EXIT=0). Every round 1 finding is fixed as the Implementation entry states. The owner's three answers are carried out; no departure. Nothing is claimed as built beyond `resolve` and `validate`; the tool's documents name no workspace, adapter, `.agent/` or `ros2_colcon`. Fixer's choices: the scp-style `:` rule is right (say it is the scp form only, not `ssh://host:port/`); "A system is already set up here: <system directory>" is right; the docs/manifest sentence "an `init` that was interrupted can leave the folder without a complete record" now disagrees with the tool's design (must-fix 1). Quoted messages: trim to condition, what changes and next step; keep only the layout line quoted (suggestion).

### Findings
- [x] (must-fix) An interrupted `init` can leave `.repos-manifest/` without `config.yaml` (folder made before the record), which the design calls "damaged by hand", and for that directory two rules give `init` two different messages; say the folder and its record appear together (written aside, moved into place), which message `init` gives in a damaged directory and its next step; and change docs/manifest/design.md's "an `init` that was interrupted can leave the folder without a complete record" to match — `tools/repos-manifest/docs/design.md:266-280`, `docs/manifest/design.md:207-208` (codex, Claude adversarial, lead)
- [x] (must-fix) "A distro's own manifest version is settled, and used on every read" contradicts "Which manifest a distro reads": the local copy wins once it exists; say "used whenever the distro reads the recorded location" — `tools/repos-manifest/docs/design.md:1010` (Claude adversarial)
- [x] (must-fix) `add-distro` refusals overlap ("has no `distros:`" is also "does not list the distro") and have no order; say they are checked in the listed order, first match wins, the ones needing no fetch before the manifest is read, and "has `distros:` and does not list it" — `tools/repos-manifest/docs/design.md:319-341` (Claude adversarial, lead)
- [x] (must-fix) Which distro a command uses from a subdirectory of a per-distro system that is in no distro's directory (`<system>/notes`, an unrecorded `rolling/`) is not said; treat it as the top — `tools/repos-manifest/docs/design.md:356-365` (codex, Claude adversarial)
- [x] (must-fix) `add-distro` "takes nothing else" shuts out arguments after `--`, so a distro with submodule repos cannot be cloned `--recursive` (later syncs update existing repos with `git`, not `vcs import`); say `add-distro` and `init` pass arguments after `--` to their sync — `tools/repos-manifest/docs/design.md:308-311,653-654` (Claude adversarial)
- [x] (suggestion) Quoted refusal messages: a design gives the condition, that nothing changes, and the next step; full message text (six times "Nothing has been changed") belongs with the code and its tests; keep the layout line quoted — `tools/repos-manifest/docs/design.md:274-286,321-341` (lead)
- [x] (suggestion) The scp-style rule: say it applies to the `host:path` form only, so `ssh://host:22/x` is not read as `host/22/x` — `tools/repos-manifest/docs/design.md:454-456` (lead, Claude adversarial)
- [x] (suggestion) "Not in a git repo" in the `add-distro` refusals: say "not given in the git form", since a local path may sit in a git working tree — `tools/repos-manifest/docs/design.md:327-341` (Claude adversarial)
- [x] (suggestion) `init` with an unlisted `--distro`: say it stops without asking, and the message when none of the given distros is listed — `tools/repos-manifest/docs/design.md:260-264` (Claude adversarial)
- [x] (suggestion) What `init` prints for several distros (one `show` block per distro?) — `tools/repos-manifest/docs/design.md:282` (Claude adversarial)
- [x] (suggestion) Say `init` sets up the current directory and what it does with what is already there (an existing `src/` or `jazzy/`), against `add-distro` refusing an existing `<name>/` — `tools/repos-manifest/docs/design.md:266` (lead, Claude adversarial)
- [x] (suggestion) A role or group the new distro's manifest lacks, at `add-distro` and at `sync`: resolver error or per-distro report — `tools/repos-manifest/docs/design.md:313,606-621` (Claude adversarial)
- [x] (suggestion) The shared `local_manifest` path may never exist on a distro whose manifest puts the repo in another layer or key; say that distro then reads the recorded location — `tools/repos-manifest/docs/design.md:241-244,457` (Claude adversarial) (deferred: already answered: "Which manifest a distro reads" takes the local copy only once the file exists, and "Where the manifest comes from" says a distro without it reads the recorded location)
- [x] (suggestion) Relative `manifest: ./system.manifest.yaml` in `config.yaml`: relative to the system directory? — `tools/repos-manifest/docs/design.md:123,206` (Claude adversarial)
- [x] (suggestion) `sync`'s exit status when one distro is reported and the others go on — `tools/repos-manifest/docs/design.md:606-609` (Claude adversarial)
- [x] (suggestion) The `setup` row says `init --distro-dirs` with no condition; add "when the project has a distro", as line 174 says — `docs/manifest/design.md:192` (Claude adversarial)
- [x] (suggestion) Style: "A distro never reads another distro's ... copy" said twice; short wrapped line "one entry, or none when the" — `tools/repos-manifest/docs/design.md:200-202,384,469` (lead, Claude adversarial)

## Implementation
**Status**: complete
**When**: 2026-11-18 15:47 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-495 at `dacfd070`
**Addressed**: Local Review (Pre-Push) at `486400a9` (2026-11-18 15:44 -05:00)
**Commits**: ea0da239, dacfd070

The host's guiding instruction for this round was to make the design shorter and plainer. The tool's design.md went from 1014 lines to 897; "More than one distro" (with its subsections) from 313 lines to 192. Cut: the tree of the same system set up with `--distro-dirs` before `add-distro` (merged into the after-tree), the tree with layers (one sentence says each distro's directory holds its layers), two of the three `config.yaml` examples (the per-branch one stays, with a clause for one manifest for all), every quoted refusal message, the "damaged by hand" paragraph, the restated "every read" sentences, and the per-command "Reads" table (one sentence).

### Actions
- [x] (must-fix 1) `init` makes `.repos-manifest/` with its `config.yaml` in one step, written aside and moved into place; before it nothing exists and `init` can be run again; a `.repos-manifest/` without a readable `config.yaml` is an error that names the file; "damaged by hand" removed. docs/manifest/design.md's "interrupted `init`" paragraph now agrees — `tools/repos-manifest/docs/design.md` "Setting up with init", `docs/manifest/design.md` route test
- [x] (must-fix 2) "settled: it is used whenever the distro reads the recorded location" — `tools/repos-manifest/docs/design.md` "Open questions"
- [x] (must-fix 3) One "Refusals" table: checks in the order listed, first that applies is given, the ones needing no fetch first; `add-distro`'s `<name>/` row follows "already recorded", and "has no `distros:`" precedes "has `distros:` and does not list it" — `tools/repos-manifest/docs/design.md` "Refusals"
- [x] (must-fix 4) "anywhere else in the system directory counts as the top" — `tools/repos-manifest/docs/design.md` "Which distro a command uses"
- [x] (must-fix 5) `add-distro` synopsis takes `[-- <vcs import arguments>]`; "takes nothing else" removed; `sync` says `init` and `add-distro` pass theirs to the `vcs import` of their first sync — `tools/repos-manifest/docs/design.md` "Adding a distro", "sync"
- [x] (suggestion 1, host) Quoted refusals replaced by the table (command, condition, next step); "A refusal changes nothing" said once; only the layout line is quoted — "Refusals"
- [x] (suggestion 2, host) scp rule names the `host:path` form only — "Where the manifest comes from"
- [x] (suggestion 3, host) "not given in the git form" in both `add-distro` rows and "Which manifest a distro reads"
- [x] (suggestion 4, host) An unlisted `--distro` is an `init` row of the table, and "It refuses as listed under Refusals, before anything is created"
- [x] (suggestion 5, host) Open question: what `init` prints for several distros
- [x] (suggestion 6, host) "`init` sets up the current directory"; table row: a directory it would create already exists
- [x] (suggestion 7, host) Open question: a distro's manifest lacking the system's role or a group, at `add-distro` and `sync`
- [x] (suggestion 8, host) deferred: already answered by "Which manifest a distro reads" (local copy once the file exists) and "Where the manifest comes from" (a distro without it reads the recorded location)
- [x] (suggestion 9, host) `manifest` row: a relative path is taken from the system directory — config.yaml table
- [x] (suggestion 10, host) Open question: `sync`'s exit status when one distro is reported and the others go on
- [x] (suggestion 11, host) `setup` row: `init`, with `--distro-dirs` when the project has a distro — `docs/manifest/design.md`
- [x] (suggestion 12, host) The section's copy of "never reads another distro's copy" removed (kept in "Where the manifest comes from"); the short wrapped line is gone with the rewrite; one more short line in "sync" reflowed

Host decisions applied as given (listed for the owner's veto): suggestions 1 to 12 as the handoff worded them.

Readings for the reviewer: `init`'s refusal for an unlisted `--distro` keeps round 1's next step (set up with the distros listed, add the others with `add-distro --manifest-ref`). The "Which distro" table no longer has an `init` row; `init` anywhere in a system is the first Refusals row. `show`'s pointer to the layout line was removed (the text there is back to main's). The ask "`init` can be run again" under "What the tool has to give" in docs/manifest/design.md is not edited (outside the named sentences); with the folder and record made together its case no longer arises, which the host may want to settle.

Checks: the four documents grepped for "distro", "init" and "resolved", every hit read against the rules; no workspace, adapter, `.agent/` or `ros2_colcon` in the tool's documents; nothing claimed as built beyond `resolve` and `validate`; the `resolve` section's first lines untouched. `bash .agent/scripts/check_design_anchors.sh` printed nothing and exited 0. Commits ran the hooks with `SKIP=validate-script-tests`; no script changed, so no suite applies; the full pre-commit pass is left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 15:53 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-495 at `bbb18d04`
**Base**: main
**Depth**: Deep (reason: round 3 convergence check per handoff)
**Must-fix**: 3 | **Suggestions**: 5
**Round**: 3 | **Ship**: continue — round 3: 3 must-fix is high (falling from 5); all three are located text fixes, none a design question

Scope: the round 2 findings and `git diff b3438aba..HEAD`. Specialists: static (no linter profile for .md; `check_design_anchors.sh` printed nothing, exit 0), governance (ADR-0017: both designs edited with the change; no departure from the owner's three answers), plan drift (no new files; the host's cut is not drift) and Claude adversarial completed; cross-model skipped (round-3 convergence check, per handoff). All five round 2 must-fix are fixed as stated. The cut keeps what issue 500 needs for config.yaml in both layouts, the per-distro tree, which manifest is read on first and later syncs, which distro a command uses, and where resolved files and state go; the gaps are in the `init` rows of the Refusals table. Fixer's notes: (a) the ask now contradicts the route paragraph (must-fix 1); (b) the ordering rule holds, since rows are checked in listed order and the "a directory it would create" row needs the manifest in the flat case; (c) nothing is lost: `init` anywhere in a system is the first Refusals row, and the layout line is in "Setting up with init".

### Findings
- [x] (must-fix) The ask "`init` can be run again ... completes the record instead of refusing" is listed as "not in the tool's design yet", while lines 210-213 say the tool's design now gives it (folder and record in one step); drop the bullet, make "Two of today's guarantees" three with "an interrupted `init` leaves nothing, so registration is run again, or a system whose first sync `sync` finishes", and drop "an `init` that can be run again" from docs/manifest/roadmap.md:27 — `docs/manifest/design.md:243-244,249`
- [x] (must-fix) `init` with no `--distro` (with or without `--distro-dirs`) on a manifest that has `distros:` has no Refusals row; line 179 only implies it is wrong; add a row before the unlisted-distro row: "No `--distro`, with a manifest that has `distros:`" / "Name one with `--distro`" — `tools/repos-manifest/docs/design.md:179-181,228`
- [x] (must-fix) The unlisted-`--distro` row's next step ("add each other one with `add-distro`") is false for a flat `init`, which `add-distro` refuses, and meaningless for a manifest with no `distros:`; give the `add-distro` part only with `--distro-dirs`, and for a manifest with no `distros:` "set up without `--distro`" — `tools/repos-manifest/docs/design.md:228`
- [x] (suggestion) `.repos-manifest/` with an unreadable `config.yaml` above or here: say `init` gives that error (not the "system is set up" row) and its next step, repair or remove the folder — `tools/repos-manifest/docs/design.md:186,225`
- [x] (suggestion) Route test: say that the tool's error for an unreadable record does not count as answering (or does), so the adapter knows which route a damaged instance takes — `docs/manifest/design.md:208-209`
- [x] (suggestion) "A flat system has one entry, or none": say the key is absent, as the table at line 84 does — `tools/repos-manifest/docs/design.md:152`
- [x] (suggestion) The ordering sentence: say the row "a directory it would create already exists" is checked after the manifest is read — `tools/repos-manifest/docs/design.md:220-221,229`
- [x] (suggestion) The "directory it would create" row: say whether an existing `setup.bash` or other file at a path `init` writes is refused too — `tools/repos-manifest/docs/design.md:229`

## Checkpoint
**When**: 2026-11-18 15:52 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 3 left three located text fixes and no design question; the reviewer says to fix and publish)
**After**: rounds
**Decision**: address

Fix the three must-fix findings and the five suggestions of the round 3 review, then publish.

Host decisions (owner may veto):
- docs/manifest/design.md: the ask "init can be run again" leaves the list of things the tool's design does not give yet, because the tool's design now gives what it was for: init makes the settings folder and its record in one step, so an interrupted init leaves either nothing, and registration is run again, or a system whose first sync is finished by sync. It moves to the guarantees the workspace relies on. docs/manifest/roadmap.md's mention of it is corrected in the same change. Undoing it: put the bullet back.
- init with no --distro on a manifest that has distros is refused, with the next step "name one with --distro".
- The tool's error for a settings folder whose config.yaml cannot be read tells the person to repair or remove the folder; for the workspace, that error counts as the tool not answering, so the instance is not treated as set up.

## Implementation
**Status**: complete
**When**: 2026-11-18 15:54 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**Branch**: feature/issue-495 at `131943f8`
**Addressed**: Local Review (Pre-Push) at `bbb18d04` (2026-11-18 15:53 -05:00)
**Commits**: dab7fb0f, 1b957932, 45a5acd0, 32b7bda2, dc9b9d6f, 21b76690, 3c0f97a8, 131943f8

### Actions
- [x] (must-fix 1) The "`init` can be run again" ask dropped from "What the tool has to give"; "Two of today's guarantees" is now three, adding that an interrupted `init` leaves either nothing, in which case registration is run again, or a system whose first sync `sync` finishes; roadmap line drops "an `init` that can be run again" (words only, its empty check cell untouched). No count other than "Two" was in that section; no other sentence describes a folder without a complete record — `docs/manifest/design.md` "What the tool has to give", `docs/manifest/roadmap.md:27`
- [x] (must-fix 2) Refusals row: `init`, no `--distro` with a manifest that has `distros:`, next step "Name one with `--distro`", before the unlisted-distro rows — `tools/repos-manifest/docs/design.md` "Refusals"
- [x] (must-fix 3) Unlisted-`--distro` row split by layout: without `--distro-dirs` "Name a distro it lists, or give the version of the manifest that lists it with `--manifest-ref`"; with it, the `add-distro` next step; new row for a `--distro` without `--distro-dirs` on a manifest with no `distros:` ("Set up without `--distro`") — "Refusals"
- [x] (suggestion 1) `init` gives the unreadable-`config.yaml` error, not the "system is set up" refusal; next step: repair or remove that `.repos-manifest/` folder — "Setting up with init"
- [x] (suggestion 2) The tool's error for an unreadable record counts as the tool not answering, so the instance is not treated as set up — `docs/manifest/design.md` route order
- [x] (suggestion 3) "A flat system has one entry, and the key is absent when the manifest has no distros" — "More than one distro"
- [x] (suggestion 4) The existing-directory row says it is checked after the manifest is read — "Refusals"
- [x] (suggestion 5) Same row covers a file it writes such as `setup.bash` — "Refusals"

Host decisions applied as given in the Checkpoint at 15:52 (listed for the owner's veto).

Checks: `bash .agent/scripts/check_design_anchors.sh` printed nothing and exited 0. The tool's documents were grepped for workspace, adapter, `.agent/` and `ros2_colcon`: only "colcon workspace" and prototype.md's issue links, both untouched by this round. The `resolve` section's first lines untouched. Commits ran the hooks with `SKIP=validate-script-tests`; no script changed, so no suite applies; the full pre-commit pass is left to the host. One line in "More than one distro" is now longer than its neighbours (the suggestion 3 clause), left unreflowed by the no-reflow rule.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 15:58 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**Branch**: feature/issue-495 at `a139997a`
**Base**: main
**Depth**: Standard (reason: round 4 convergence check per handoff)
**Must-fix**: 1 | **Suggestions**: 1
**Round**: 4 | **Ship**: recommended — round 4: 1 mechanical must-fix (prev 3), not rising — fix and ship rather than another full round

Scope: the round 3 findings and `git diff 4084a9e5..HEAD` (eight commits plus the checkpoint and implementation entries). Specialists: static (no linter profile for .md; `check_design_anchors.sh` printed nothing, exit 0), governance (ADR-0017 met; no departure from the owner's three answers or the host's round 3 decisions), plan drift (only the four expected files changed; progress.md changes are the round 3 boxes ticked plus the two new entries) and Claude adversarial completed; cross-model skipped (round-4 convergence check, per handoff). All three round 3 must-fix and all five suggestions are fixed as stated. docs/manifest/design.md and roadmap.md agree: five asks left in both, "Three of today's guarantees" includes the interrupted `init`, the route paragraph says the same, and the unreadable record counts as the tool not answering. `sitrep_checks.sh --root . --roadmap docs/manifest/roadmap.md --no-follow` (read-only) parses the changed line as an `unchecked` line, exit 0. Every `init` combination (`--distro` 0/1/2+, `--distro-dirs` or not, `distros:` or not, listed or not) falls in exactly one first-applying row or is allowed (no distro on a manifest without `distros:`; listed distros, one flat or one or more with `--distro-dirs`); the one defect is the loop below.

### Findings
- [x] (must-fix) Two or more `--distro` on a manifest with no `distros:` loops: row "More than one `--distro` without `--distro-dirs`" says add `--distro-dirs`, then row "`--distro-dirs` with a manifest that has no `distros:`" says set up without it, and back; make the latter's next step "Set up without `--distro-dirs` and without `--distro`" — `tools/repos-manifest/docs/design.md:228-229`
- [x] (suggestion) The two unlisted-`--distro` rows give only `--manifest-ref` steps, which need `manifest` in the git form; add "or, when `manifest` is not given in the git form, add the distro to its `distros:`", as the `add-distro` row does — `tools/repos-manifest/docs/design.md:232-233`

## Checkpoint
**When**: 2026-11-18 15:57 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 4 left one one-line fix and one suggestion, and its ship line recommends fixing and publishing)
**After**: rounds
**Decision**: address

Make the two text fixes of the round 4 review: the refusal for --distro-dirs on a manifest with no distros says to set up without --distro-dirs and without --distro, so that two refusals do not send a person back and forth; and the two unlisted-distro rows also give the next step for a manifest that is not given in the git form. Nothing else. This is the host's second address answer at this checkpoint in a row; the next answer here is publish or the owner's.

## Implementation
**Status**: complete
**When**: 2026-11-18 15:58 -05:00
**By**: Claude Code Agent (claude-sonnet-5-5)

**Branch**: feature/issue-495 at `6e66e92e`
**Addressed**: Local Review (Pre-Push) at `a139997a` (2026-11-18 15:58 -05:00)
**Commits**: d8677aa7, 6e66e92e

### Actions
- [x] (must-fix) `--distro-dirs` with no `distros:` row now says "Set up without `--distro-dirs` and without `--distro`", ending the loop with the more-than-one-`--distro` row — `tools/repos-manifest/docs/design.md:228-229`
- [x] (suggestion) The two unlisted-`--distro` rows now also say to add the distro to the manifest's `distros:` when `manifest` is not given in the git form — `tools/repos-manifest/docs/design.md:232-233`

Table re-read: no `init` row's next step lands on a refusal that sends the person back. `check_design_anchors.sh` printed nothing, exit 0. Documents only; no suites run; full pass left to the host.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-18 15:59 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**Branch**: feature/issue-495 at `ef2e3335`
**Base**: main
**Depth**: Standard (reason: round 5 convergence check per handoff)
**Must-fix**: 0 | **Suggestions**: 0
**Round**: 5 | **Ship**: recommended — no must-fix findings

Scope: the round 4 findings and `git diff 9e1d191a..HEAD` (d8677aa7, 6e66e92e changing three cells of the Refusals table in tools/repos-manifest/docs/design.md, plus the checkpoint and implementation entries). Because the diff is three table cells, the reviewer did the governance, plan-drift and adversarial reads itself instead of dispatching subagents; cross-model skipped (round-5 convergence check, per handoff). Static: `check_design_anchors.sh` exit 0; every Refusals table line splits into the same 3 cells (16 lines, 5 `|`-fields each), no stray `|`. Plan drift: only design.md and progress.md changed; the progress.md removals are the two round 4 boxes ticked. Governance: no departure from the Checkpoint decisions.

`init` combinations walked (first applying row, next step, until allowed): no `distros:` — 0 flat allowed; 0 dirs → row 3 → allowed; 1 flat → row 5 → allowed; 1 dirs → row 3 → allowed; 2+ flat → row 2 → (2+ dirs) row 3 → allowed; 2+ dirs → row 3 → allowed. With `distros:` — 0 flat/dirs → row 4 → named distro: listed allowed, unlisted → row 6 or 7; listed 1 flat or 1+ dirs allowed; 2+ flat → row 2 → 2+ dirs; unlisted flat → row 6 (name a listed one, `--manifest-ref`, or edit `distros:`) → allowed; unlisted dirs → row 7 (set up with listed ones, then `add-distro`, or edit `distros:`) → allowed. No chain returns to a refusal it came from; the round 4 loop (rows 2 and 3) ends at row 3 since it now drops `--distro` too. The two unlisted rows' new clause matches the `add-distro` row's wording ("when `manifest` is not given in the git form, add the distro to its `distros:`").

### Findings
None.

## Checkpoint
**When**: 2026-11-18 15:59 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: host (round 5 approved with no findings, and the full pre-commit pass passed at 23db6d0e)
**After**: publish
**Decision**: publish

The full pass (every hook, no SKIP, over the files the branch changes) passed on 23db6d0e. Published; the pull request closes the issue.

## Integrated Review
**Status**: complete
**When**: 2026-11-18 16:14 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #508 at `85c3ed05`
**Sources**: 2 (Local Review (Pre-Push) round 5 @ `ef2e3335`, covers `85c3ed05` via bookkeeping; CI rollup at `85c3ed05`)
**Cross-source confirmations**: 0
**CI**: all-pass

No hosted review: `fetch_pr_reviews.sh --pr 508` found 0 reviews, 0 inline comments and 0 conversation comments, and a second look after CI settled (16:13) found the same; Copilot has not reviewed. `review_progress.sh sources` at `85c3ed05` returned no local findings, no dropped entries and no candidates. CI at `85c3ed05`, both runs (push 44396846340 and pull_request 44396855944): Lint (pre-commit) pass (8m44s, 13m5s), Validate Adapter Contract pass, Validate Documentation pass, repos-manifest tests pass.

Earlier open boxes. Every finding of the five pre-push rounds is ticked. Boxes left unticked are in the Issue Review (8) and the two Plan Reviews (8 and 7): those are action lists the loop answers with a plan revision and a Checkpoint, not by ticking. Checked against the documents: each Plan Review action is carried out (the `manifest_version`-only distro entry, "passes `--distro-dirs`", the "two things" bullet, the unrecorded-`--distro` error, a distro never reading another's local copy), or overridden by the owner's three answers. Three Issue Review actions are outside this pull request and still open: the text of issues 495 and 500 names `tools/ros-manifest/` (the PR body says so); no separate issue has been opened for the workspace's asks of the tool (the Checkpoint at 15:05 leaves that to the owner, the host to propose); issue 500's "part of the design follow-up (#495)" bullet still lists "an `init` that can be run again", which this branch drops as an ask.

For the owner's merge decision, two host decisions recorded for veto: `setup` passes `--distro-dirs` whenever the project has a distro (Checkpoint 15:22; the second Plan Review called this the owner's choice), and "`init` can be run again" moved from the asks to the guarantees (Checkpoint 15:52).

Pull request 506 (`feature/issue-498` at `9356877e`): `git merge-tree --write-tree` gives one conflict, in `docs/manifest/design.md`, "What the tool has to give": 506 rewrites the "A failed resolve changes nothing" bullet (the tool's `resolve` now replaces its output whole), and this branch removes the next bullet, "`init` can be run again". Adjacent edits, not a contradiction: the resolution keeps 506's bullet and drops the `init` bullet. `tools/repos-manifest/docs/design.md` and `README.md` merge cleanly, and the merged text agrees: 506's "writes into `.repos-manifest/resolved/`" and `--out` outside a system directory, with this branch's `resolved/<distro>/` for a directory per distro; "What is built" carries both. The merged tool documents pass 506's `test_documents.py` rule (no match for its patterns).

Cross-model: not needed before merge. The outside models saw round 2; rounds 3 to 5 changed refusals-table cells, one guarantee sentence and wording, each re-read by a full review that walked every `init` combination. A pass on the Refusals table and the interrupted-`init` guarantee is optional if the owner wants a second reader.

### Findings
None.

### False positives
None.

Nothing remains open in this pull request before the owner's merge decision. Outside it: the three issue-text items above, and a resolution of the one conflict with 506 by whichever merges second.

## Checkpoint
**When**: 2026-11-18 16:15 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Decided-by**: owner
**After**: merge
**Decision**: address

The owner chose "Resolve, re-check, merge (Recommended)" in a dialog (2026-11-18). The option as shown to him: a background agent merges main into the branch and resolves the one conflict as described (in docs/manifest/design.md, "What the tool has to give": keep the sentence pull request 506 wrote for "A failed resolve changes nothing", drop the "init can be run again" bullet this branch removes), a short review checks the result and CI runs again, and then the host merges without asking him again, provided the review finds nothing and CI is green; if anything else turns up, the host comes back to him.

The finding to address: pull request 508 conflicts with main since pull request 506 merged (4d319d9d). Merge origin/main into feature/issue-495 and resolve that conflict as stated; resolve nothing else by judgment.

## Implementation
**Status**: complete
**When**: 2026-11-18 16:17 -05:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #508 at `645971dd`
**Addressed**: owner Checkpoint (After: merge, Decision: address) at 2026-11-18 16:15 -05:00, which follows Integrated Review at `85c3ed05` (2026-11-18 16:14 -05:00)
**Commits**: 645971dd (merge of origin/main at 4d319d9d)

### Actions
- [x] Merge origin/main into feature/issue-495 and resolve the one conflict as the Checkpoint states — `docs/manifest/design.md` "What the tool has to give": kept main's (pull request 506) text of the bullet "A failed resolve changes nothing" (the tool's `resolve` replaces its output whole) and kept this branch's removal of the bullet "`init` can be run again". No other file conflicted.

The section still reads true after the merge: the failed-resolve bullet now credits the tool's `resolve` with whole-or-nothing output and keeps as the ask what `sync` must do when the manifest does not resolve (other repos and the resolved output unchanged, the manifest named as the failure). The "Three of today's guarantees" sentence lists the manifest re-read on every `sync`, `sync` deleting nothing, and the interrupted `init`; it does not list the failed resolve, so nothing is both asked and given. No edit beyond the conflict.

Checks on the merge: `test_documents.py` 11 passed; the tool suite `tools/repos-manifest/tests` 736 passed; `check_design_anchors.sh` exit 0. `tools/repos-manifest/docs/design.md` read where both branches wrote ("resolve", "What is built", the Commands table): no sentences disagree (flat `.repos-manifest/resolved/` and `--out` from 506, `resolved/<distro>/` for a directory per distro from this branch, and the same split under "Where the resolved files and state go"), so no second commit.

## Local Review
**Status**: complete
**When**: 2026-11-18 16:30 -05:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: changes-requested

**PR**: #508 at `dddf0074`
**Depth**: Deep (reason: 1546 changed lines over 7 files; round 1 of PR mode)
**Must-fix**: 3 | **Suggestions**: 5

Merge 645971dd: resolved exactly as described. "What the tool has to give" keeps main's "A failed resolve changes nothing" bullet and drops "`init` can be run again"; the section, the route paragraph ("an interrupted `init` leaves either nothing ... or a system whose first sync is finished with `sync`") and "Three of today's guarantees" agree with the tool's design ("Setting up with init", "resolve": output replaced whole). Main's `resolve` text (`--out`, replaced whole, no lock, issue 500) is intact; this branch adds only the per-distro output paragraph, which agrees with it. spec.md is unchanged; every citation of it ("Distros", "What resolving produces", "Reading a manifest before using it") exists and says what is claimed. Nothing claimed as built beyond `resolve` and `validate` (cli.py). No workspace or adapter in the tool's documents (test_documents.py: 11 passed).

Checks: CI at `dddf0074`, both runs (44399975410, 44399989016): Lint (pre-commit) pass (13m30s, 13m17s), Validate Adapter Contract pass, Validate Documentation pass, repos-manifest tests 3.10 and 3.14 pass. Local: `pytest -q tools/repos-manifest/tests` 736 passed; `check_design_anchors.sh` exit 0; mergeable MERGEABLE.

Specialists: static (no linter profile for .md; `check_design_anchors.sh` exit 0), governance (no departure from the owner's three answers or the host's checkpoints), plan drift (none), Claude adversarial, cross-model gemini and codex (both EXIT=0, both completed). Dropped: unreadable `config.yaml` counting as the tool not answering (gemini, codex: host decision, Checkpoint 15:52); scp/`ssh://` URL comparison (codex, gemini: reviewed and chosen in round 1); resolved/<name>/ leftover (codex: the output rule already replaces a marked directory).

### Findings
- [x] (must-fix) docs/manifest/roadmap.md's commands line lists `show`, `init`, `sync`, `build` and `status`; the design now has the adapter's `setup` call `add-distro` (docs/manifest/design.md:130-131, :192) — `docs/manifest/roadmap.md:28` (Claude adversarial, gemini, codex)
- [x] (must-fix) "Inside a system directory the distro is chosen as under 'Which distro a command uses'" covers `validate`, but that section's table has no `validate` row, so what `validate` does at the top of a system with several distros is unsaid — `tools/repos-manifest/docs/design.md:259-263, 408-411` (gemini)
- [x] (must-fix) Refusals: `add-distro` refuses `--manifest-ref` when `manifest` is not in the git form (:238), but `init` has no row for `--manifest-ref` with a local path or a URL without `--manifest-path` (:304), so the builder guesses refuse or ignore — `tools/repos-manifest/docs/design.md:220-234` (Claude adversarial)
- [ ] (suggestion) The `init` row says "a file it writes such as `setup.bash`", but `build` writes `setup.bash` (:605); say "a file the system will have" — `tools/repos-manifest/docs/design.md:234` (Claude adversarial)
- [ ] (suggestion) Whether `sync` goes on with the other distros when one distro's manifest does not resolve or a required repo cannot be fetched is unsaid (only the config mismatch case is); state it or add it beside the exit-status open question — `tools/repos-manifest/docs/design.md:543-546, 593-594, 963` (Claude adversarial)
- [ ] (suggestion) Say `add-distro` replaces `config.yaml` whole, as `init` writes it aside and moves it, so an interrupted `add-distro` cannot leave the record unreadable for every distro — `tools/repos-manifest/docs/design.md:204-207` (gemini, codex)
- [ ] (suggestion) `add-distro <name>` checks `<name>/` before anything checks the name, so `add-distro ..` gets "Move it out of the way"; refuse a name that breaks the spec's name rule first; and distro names that differ only in case collide as directories on some disks, which the spec rules out only for layers — `tools/repos-manifest/docs/design.md:235-237` (gemini, codex)
- [ ] (suggestion) The small trees show `resolved/` with only `_unnamed.repos` and omit `./system.manifest.yaml`, while `resolve` always writes `layers.txt`, `optional.txt` and its marker; say they are abridged or complete them — `tools/repos-manifest/docs/design.md:114-148` (Claude adversarial, gemini)
