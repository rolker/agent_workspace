# Plan: Workspace design document, phase 3 (rewrite docs/design.md as the current picture)

Revision 4 (2026-10-09), after plan review round 3 (needs-work, entry `e3c3eac`); revision 3 answered
round 2 (entry `9cfd1fe`), revision 2 answered round 1 (entry `6f8c643`) and the owner's decision on
the shape of the document (2026-10-08). What changed is in the "Revision 2", "Revision 3" and
"Revision 4 change log" sections at the end.

## Issue

https://github.com/rolker/agent_workspace/issues/335 (phase 3 of 3). Phases 1 and 2 are done and
merged: the principles PR (#375, merge commit `b7e8838`) and the AGENTS.md follow-ups (#376, merge
commit `ea0df4a`). `AGENTS.md` is 442 lines on main after #376.

**Where this plan departs from the issue text.** The issue's scope item 3 asks that "existing ADRs
get a one-line pointer to their design section". This plan does not do that: the mapping lives only in
the Decision register. Reason: ADR-0008 permits a Status-line note of a related ADR, a References
list and link or typo fixes, and a pointer line is none of those; an accepted ADR that gains one can
read as a restated decision, and ADR-0017 makes ADRs history. Whether to widen ADR-0008 so ADRs can
carry a pointer is open question **B1**. The departure is recorded in a comment on the issue once the
owner approves this plan. The issue's "Rules that must stay true" part is headed `Rules` (reason
under "Why `Rules`"), and its "Purpose" part has its own row in the section table.

## Context

`docs/design.md` is 223 lines of directory tree, registry field detail and script behaviour. Almost
all of that detail already lives, or belongs, next to the code (see "What leaves design.md").
ADR-0017 makes the design document the authority for how the parts fit and says the rewrite
reconciles it with the ADRs; until it lands, existing ADRs stand. The owner has settled what the
document is for: a short "How it works" at the top (H1: agents are strong within one piece of work
and weak across time, so the workspace is a day-to-day harness plus a long view, and the principles
connect them), the documentation layers as roles (Goals, How it works, Principles, Design,
Decisions, Direction, Measures; each project maps each role to a file, section, outside place or
none; this document holds the workspace's own mapping), and the "healthy / right direction" goal
served by the Direction role (G2). The owner writes plain prose and wants text he can edit, not a spec.

## Approach

### Process (how the document gets written)

1. Plan reviewed (rounds 1 to 3 done, this is revision 4), then owner approval. Worktree for #335 exists.
   No section is written before approval. Approval also covers two things that are otherwise Ask First:
   the new pre-commit hook in PR B (it is CI-like config: CI runs `make lint`, which runs every hook;
   question **B4**) and the one-line label edit in `.agent/AGENT_ONBOARDING.md` (Wire-in 7).
2. **"How it works" first, in the owner's words.** The agent supplies only a list of the facts and
   decisions it must cover (from H1 and the 16 principles' Serves lines), not prose. The owner writes
   or edits the paragraphs; the agent trims nothing without asking, and there is no length guide for
   this section. Everything below hangs off it.
3. **Then one section at a time**, in the order of the table below. Per section the agent drafts
   "Now" from code and records only (each line cites a script, ADR or file it was checked against),
   drafts "Target" only from recorded decisions, and turns every gap into an Open Questions row. The
   owner edits; one commit per section (atomic, so a dropped section drops cleanly).
4. **Cheap with/without test**, same shape as the 2026-10-02 Why-line test: before merging, put the
   same five questions (for example "does `onboard-project` register a project?", "where does a
   session started in a project get its skills?", "who decides a merge?") to fresh read-only agents
   given the old file, then the new file; compare correct answers and what each had to open. Ten
   short Sonnet reads. Ask the owner first before launching (standing rule: no silent sub-agents).
5. Verification before the PR: every "Now" line spot-checked against its cited source (Verify before
   claiming); grep for project names (private projects stay unnamed; the fork name
   `ros2_agent_workspace` is fine); `make lint`; script tests.

### The new document: shape, admission, status

**No line cap** (owner decision Q1, 2026-10-08). The control is the admission rule at the top of the
design part of the file: a fact is in only if two parts could otherwise choose incompatibly or a
newcomer cannot see it from the code. Two soft checks back it up:

- A section that grows past about 60 lines prompts one question: does this detail move next to the
  code (script header, document next to it)? If yes it moves; if no, the section stays and the change
  log says why. A part the owner wants longer may take `docs/design/<part>.md` and a pointer (issue's size rule).
- The change log records the document's line count at each rewrite (principle "Know whether it
  works"), so growth shows up as a number instead of a surprise. The owner's How-it-works prose has no length guide.

**Order of the file.** The first heading in the file is `# How it works` (owner's words, H1). A
second H1, `# The design`, follows; its opening paragraph states the admission rule, the split ("this
file = the current picture, ADRs = rationale and history, `progress.md` = per-issue history", the
reference updates at merge, ADR-0017) and the Status key. Every other part is an H2 under it. Reading
"first" as "first heading in the file" is a judgement call; the alternative (the admission rule above
the H1, unheaded) is open question **A2**.

**Status.** Status is per block. A part has a `Now` block (what the code does today, with the source
each line was checked against) and, only where it differs, a `Target` block. Each block opens with one
line `Status:` taking exactly one of five values, so a part can be `decided` now and `proposed` as a
target. A part with nothing built has only a Target block. A block holds statements of one status; if
it would mix, it is split, and a question goes to the Open questions table with a pointer, not into a
block that claims a status.

| Status | Means |
|---|---|
| `decided` | An owner decision is on record, cited (ADR number or issue and date), and the code does it |
| `decided, not built` | Decided and cited; the code does not do it yet |
| `decided, not proven` | Decided and built, but the acceptance test has not run (ADR-0016 is Provisional until the `/run-issue` run from a project root in #317) |
| `proposed` | Agent or owner suggestion, not decided |
| `open` | A question, listed under Open questions. An `open` block holds only a pointer to where the question is tracked (an issue number or the Open questions row), no question text |

`Now` states only what the code does today and cites where to check it; nothing proposed appears in
`Now`. `Target` paragraphs start with "Target:"; each proposal inside starts with "Proposed:" and moves
to `Now` when built (the change that builds it makes the move). A part with no Target carries one
status line (whether it also carries the `Now` label is A1). Research candidates are marked
`(candidate)` in the draft so the owner accepts or drops each before the PR; no `(candidate)` marker
survives into the final text.

**Sections** (document order; no line column, since there is no cap). Status is given per block: the
Now column is the status of the part's Now block, the Target column the status of its Target block, `-`
where the part has none.

| # | Section (stable heading) | What goes in | Now | Target |
|---|---|---|---|---|
| 1 | `# How it works` | Owner's words. Core ideas, day-to-day harness plus long view, principles connect them; README Workspace goals ends with a pointer. Optional one-line tree picture if the owner wants it (A5) | decided (H1) | - |
| 2 | `# The design` opening | Admission rule; the split (current picture / ADRs / `progress.md`); update-at-merge; the Status key | decided (ADR-0017) | - |
| 3 | `## Purpose` | Two or three sentences: what this file is for (how the parts fit today, checked at merge). Points at README `## Workspace goals` and `docs/principles.md` without restating them. This carries the issue's "Purpose" part | decided (ADR-0017) | - |
| 4 | Documentation layers | The seven roles; where each lives for the workspace (Goals: README `## Workspace goals`; How it works and Design: this file; Principles: `docs/principles.md` and the review guide; Decisions: `docs/decisions/`; Direction: `docs/roadmap.md`, "healthy" has no home yet; Measures: none yet). Shows the two gaps honestly. How a project maps its own is Target, seeded by `discover_governance.sh` types | decided (the roles and the workspace's mapping) | proposed (per-project mapping) |
| 5 | Rules | See "Why `Rules`" below. One table: rule, principle it implements (cited, not restated), enforced by. Only rules that carry an enforcement fact `AGENTS.md` does not state. Candidates verified in this revision: no commit to a protected branch, commit identity set, issue number matches the branch (all pre-commit hooks); progress entry shape (`_progress_entry.sh` and `progress_append.sh` validate it); the merge gate (`merge_pr.sh`). Rules with no check (for example worktree for all work) are listed as review only or nothing, after the owner accepts the column (A3). Now is `decided` because each listed rule and its check were verified; the "review only" and "nothing" entries are facts shown in the column, not a status | decided | - |
| 6 | Sessions and roots | A session starts in the workspace or in a project root; the user tier supplies the workspace layer to project sessions (ADR-0016). Target: the workspace as a registered project, a pointer to #295 only (an `open` block holds no question text) | decided, not proven | open (#295) |
| 7 | Registry and adapters | Registry maps names to roots and types; a 12-verb adapter contract per project type (ADR-0011, which supersedes ADR-0003 and carries its project-agnostic doctrine forward; one clause says so, which is why 0003 is checked in PR B); resolution order in one sentence. GitHub is not a project dependency, the workspace uses it for now (owner 2026-10-05). Target: `onboard-project` as the one registration path (#332), mixed-flavour projects (#310), project lifecycle register to unregister; the unsettled parts also sit in Open questions | decided (ADR-0011/0012) | proposed |
| 8 | Worktrees | Two kinds, workspace and project; why (ADR-0002); where they live is a pointer to the guide. What a project carries by choice is Target (zero-footprint mode; candidate) | decided | proposed |
| 9 | Review loop and timeline | Phase order, one entry per phase in `progress.md` (the only loop state), fresh-context sub-agent per phase (ADR-0013/0014/0015); where the work-plans directory lives. Target (candidates): which claims code verifies (exit contracts, entry validation, merge gate) versus self-reported; what a finding must contain and reviewer independence (C5); how a new session finds the records for its issue; size bound on records | decided | proposed |
| 10 | Merge gate | The owner decides every merge; the gate checks review currency and CI on the reviewed head; bookkeeping-only commits exempt; enforce by default on workspace PRs (`merge_pr.sh`, `_bookkeeping.sh`) | decided | - |
| 11 | Identity | Agents sign work with framework identity, ephemeral per session; pointer to `AI_IDENTITY_STRATEGY.md`; tool-neutral rule and what degrades without the main tool (principle "Use the main tool fully" cited) | decided | - |
| 12 | Instruction layers (candidate) | Only if accepted (A5): the four layers (always loaded, path-scoped, skill, on demand) and a size budget for the always-loaded layer (`AGENTS.md` is 442 lines against vendor guidance under 200); this file is not always loaded. Changing `AGENTS.md` is Ask First and is not part of this plan. Nothing is built, so this part has only a Target block | - | proposed |
| 13 | Decision register | **Purpose** (stated in the section): tell a reader which ADR still governs, so nobody follows a superseded or drifted one. One row per ADR (17, 0001 to 0017): one-line decision, standing (in force / superseded / superseded in practice / Provisional), the design section that carries it as an in-file link `(#<slug>)`, and **Re-examined**: `yes <date>` for the nine ADRs PR B's sections cite and check against code (0002, 0003, 0011, 0012, 0013, 0014, 0015, 0016, 0017), `not yet` for the other eight (0001, 0004 to 0010), which the issue allows. Plan-level decisions that never got an ADR listed with their issue. ADR-0003 is superseded by 0011 and is cited by the Registry row (row 7), so its `yes` is backed by a section. ADR-0004 and ADR-0005 stay `not yet` even though the Rules enforced-by column touches their ground: the column cites the hooks and scripts that do the checking, not those ADRs' reasoning, and the issue allows `not yet` | decided | - |
| 14 | Open questions | Table: ID, question, owner, what it changes. Seeded from the questions below | open | - |
| 15 | Change log | Date, section, one line, issue/PR, **document line count**; appended in the same change that alters a section | decided | - |

Section dates (candidate, A4): if accepted, each part carries `Checked: <date>` against the code,
refreshed by `/audit-workspace` step 2, which ADR-0017 work already pointed at this file.

**Why `Rules`, not `Rules that stay true`.** The heading is a citation anchor (`#rules`), so short and
stable wins. "Stay true" also promises more than the enforced-by column can back: some rules are
review only, and the table is there to show which.

### What leaves design.md and where it lands

Each row's destination was opened in this revision and compared with the current design.md text.

| Current text | Lands in | Verified state | Action |
|---|---|---|---|
| Directory Structure section (lines 11-58: heading and tree; "Project Repository Model" starts at line 60) | nowhere; `ls` and the script table in `AGENTS.md` show it | n/a | Delete. Keep only the three roots (workspace, project, user tier) inside "Sessions and roots". Also update the review-guide row (see Files to Change) |
| Registry field syntax (`parent=`, `worktrees=`, `role=`, `distro=`, `default_instance=`) | `.agent/projects.local.example` and `_project_registry.sh` headers | Both hold the five fields and the name/type/path rules | Delete |
| Resolution order (`--project`, then cwd inside a registered dir, longest match, then legacy `project/`; parent root to `default_instance`) | `.agent/scripts/adapter` header (the three steps) and `.agent/projects.local.example` lines 62-69 | Holds it. The plan's earlier claim that the registry headers hold it was wrong: `_project_registry.sh` documents only `registry_resolve_from_dir`'s longest-match rule at the function | Delete; keep one sentence in "Registry and adapters" |
| `validate_workspace.py` paragraph | `validate_workspace.py` docstring | Holds checks 1 to 5 incl. delegation to `adapter --project <name> validate`. The `project '<name>':` failure prefix is in the code, not the docstring | Delete the paragraph; PR A may add the prefix to the docstring |
| `ros2_colcon` detail (layers, bootstrap URL order, distro rule) | `.agent/project_types/ros2_colcon/adapter.sh` header | Holds layers, URL order and distro rule; `vcs` import is in the code (line 425 area), not the header | Delete; one sentence in "Registry and adapters" |
| Worktree locations, exclusion, `COLCON_IGNORE` | `.agent/WORKTREE_GUIDE.md` (lines 78-107) | Holds locations, `.git/info/exclude`, `COLCON_IGNORE` | Delete |
| Stamp-based setup (ADR-0007) | `Makefile` header and ADR-0007 | Header lists three stamps (the design text lists two: it omits `git-bug.done`) | Delete |
| Build and Test (`project_config.sh` variables) | `AGENTS.md` Build & Test | Duplicate | Delete |
| Multi-agent coordination: "the workspace lock (`make lock`/`make unlock`)" | **Nowhere today.** `.agent/WORKFORCE_PROTOCOL.md` section 3 is GitHub-issue task locking, not this lock. The lock is `.agent/scripts/lock.sh` / `unlock.sh`, a file `.agent/scratchpad/workspace.lock` shown by `dashboard.sh`; nothing else reads it, so it is advisory only | PR A adds a header paragraph to `lock.sh` saying so. Delete the design text; concurrency in the design is worktrees plus the draft-PR visibility rule (WORKFORCE_PROTOCOL sections 1-3), one line in "Worktrees" |
| Identity management | `.agent/AI_IDENTITY_STRATEGY.md` | Exists | Compress to "Identity" |
| Review loop lifecycle paragraph | `.agent/knowledge/review_loop_lifecycle.md`, `run-issue` skill, `dispatch_phase.sh` header | Lifecycle file cites ADR-0014 once (line 5, as a pointer) and says `/run-issue` "checks the exit contract", but never names `dispatch_phase.sh --check-exit`, its `OK/PARTIAL/FAILED/MISSING` result, the fresh-sub-agent-per-phase rule, or ADR-0015. The `dispatch_phase.sh` header holds `--check-exit` | PR A adds a short "Exit contract and dispatch" paragraph to the lifecycle file, then compress to "Review loop and timeline" |
| Governance bullets | `AGENTS.md` Boundaries and `docs/principles.md` | Duplicates | Delete |
| Two-shape (legacy `project/` vs registry) history | issue #172 and #265 plan | n/a | One Target sentence; delete when the legacy shape is dropped |

Rule for moves: nothing is deleted before its destination is confirmed to hold the text (open the
destination, quote the matching lines in the PR description); gaps are filled first (PR A).

### Wire-in

1. **Names.** Headings are the names; there is no separate list and no HTML comment. Renaming a
   heading is a design change that updates every citer in the same change; the anchor check (6) catches
   a miss, on the commit that renames it (the new pre-commit hook), again in `make lint` and CI, and its
   own logic is tested by the script-tests suite.
2. **Skills.** `review-issue`, `review-plan` and `plan-task` all run in project sessions
   (`session_scope: both`), where a bare `docs/design.md` does not resolve. Their wording changes from
   "which design section" to "name the section by its anchor in `$WS_ROOT/docs/design.md`", with
   `$WS_ROOT` resolved by the skills' existing idiom. The skills cite by anchor, not by heading in
   prose, so the anchor test reaches them: `review-issue` cites `$WS_ROOT/docs/design.md#how-it-works`
   for the goal an issue serves; `plan-task` and `review-plan` cite `$WS_ROOT/docs/design.md#the-design`
   for the Status key and the section list, and tell the agent to cite the matching section by its
   anchor, written in the skill text as `docs/design.md#<section>`. The skill text uses only the two
   real anchors above and that one angle-bracket placeholder; the checker ignores a placeholder because
   its anchor pattern is `[a-z0-9][a-z0-9-]*` and `<` does not match (a fixture proves it, Wire-in 6). Project issues keep the "the project's own design document, or say there is none"
   branch. `audit-workspace` (workspace scope only) keeps plain `docs/design.md` and checks section
   dates only if A4 is accepted.
3. **ADRs: register only (a departure from issue scope item 3, see Issue).** ADR-0008 permits a Status-line note of a related ADR, a References list
   of related ADRs, and link or typo fixes; a "Current description: design.md#..." line is none of
   those, and an ADR that gains one can read as restated decision. The mapping from ADR to design
   section therefore lives only in the Decision register, and accepted ADRs are not edited for it.
   One edit is allowed and included: ADR-0017 line 27 links ADR-0008 as
   `0008-permit-cross-reference-addendums-in-accepted-adrs.md`; the file is
   `0008-permit-cross-reference-addendums-in-adrs.md` (a broken-link fix, ADR-0008 "Permitted").
   Whether ADRs should also carry a pointer, with an ADR-0008 scope note allowing it, is **B1**.
4. **Roadmap, only rows that change the design picture.** `docs/roadmap.md` has 34 rows in `planned`
   (27), `in progress` (4) or `deferred` (3) status (recounted from the file; many sit under "To
   Consider"). Only a row whose issue adds, removes or re-shapes a part named in a design.md section
   gets a "design section:" note naming that section (the #172 and cutover tables have such rows). The
   rest are untouched, and so are rows marked `done`; PR C's description lists the rows it touched and
   the count left alone. Separately, `## Cross-cutting Decisions`
   (lines 405-482: storage model, 5-layer review model, progress as lifecycle record, roadmap over
   issues, triage-and-fix sessions, permission prompts) is an older second copy of parts of the design
   and already stale (it says review summaries "continue to work" in plan.md). PR C marks the section
   as history with a one-line note pointing at the design sections, and replaces "Storage model" and
   "Progress as lifecycle record" with a pointer to "Review loop and timeline", since design.md will hold
   those facts. The rest stays as dated rationale. Mark-as-history versus delete versus leave is **B2**.
5. **Review guide.** `.agent/knowledge/principles_review_guide.md` Consequences Map row "Work-plan
   directory convention" lists "`docs/design.md` directory tree" as a dependent. The tree goes in PR B,
   so the same change rewrites that cell to "the work-plans description in `docs/design.md` (Review
   loop and timeline)". The "Keep one current design" rows already say "matching section" and need no edit.
   (The same file's ADR-0016 row, line 51, names a real project; that is PR A.)
6. **Anchor check (PR B).** Two pieces, so the check runs where the breakage happens and the suite
   stays inside the #354 scoping.
   *The checker.* `.agent/scripts/check_design_anchors.sh [<root>]` (new; `chmod +x` in the same step,
   because the `check-shebang-scripts-are-executable` hook fails the commit otherwise). Plain grep and
   awk, no Python, so it is cheap enough to run on every docs commit. The root defaults to the
   repository root; the tests pass a fixture root. Exit 0 clean, 1 with each broken citation printed as
   `file:line: #anchor`, 2 if `docs/design.md` is missing.
   *One citation form.* From outside, `docs/design.md#<anchor>` (any prefix, so
   `$WS_ROOT/docs/design.md#<anchor>` counts), with the anchor matching `[a-z0-9][a-z0-9-]*`, so a
   `#<section>` placeholder is not a citation and is ignored. Inside design.md, including the
   register's section column, a Markdown link `](#<slug>)` whose slug is not all digits, so issue
   references such as a bare `(#295)` or a link written `[x](#295)` are never matched. `<slug>` is the heading's GitHub
   slug (lowercase, punctuation dropped, spaces to hyphens, repeats numbered `-1`, `-2`; `# How it
   works` is `how-it-works`). The checker computes slugs from the headings (skipping fenced code), so
   there is no second list to keep in sync.
   *Scope.* Every `docs/design.md#...` citation in `README.md`, `.agent/AGENT_ONBOARDING.md`,
   `.claude/skills/*/SKILL.md`, `.agent/knowledge/*.md` and `docs/roadmap.md`, and every `](#...)`
   link in design.md. When `<root>/docs/decisions/` exists it also fails if the Decision register has
   fewer rows carrying an anchor than there are files in `docs/decisions/`, and when design.md holds no
   in-file anchor links at all, so a rewrite that drops the register cannot pass vacuously. PR C's
   README pointer and skill wording come under it as they land.
   *The local hook.* PR B adds a second pre-commit hook beside `validate-script-tests`, in
   `.pre-commit-config.yaml` under `repo: local`, placed before `validate-script-tests` so the block
   that suite's guard parses is unchanged: id `check-design-anchors`, `entry: bash
   .agent/scripts/check_design_anchors.sh`, `language: system`, `pass_filenames: false`, and `files:
   ^(docs/design\.md$|README\.md$|docs/roadmap\.md$|\.agent/AGENT_ONBOARDING\.md$|\.agent/knowledge/|\.claude/skills/|\.pre-commit-config\.yaml$)`.
   A commit that renames a heading or edits a citer now runs the check locally; `make lint` and the CI
   Lint job (`make lint` runs every hook on all files) run it again, which is ADR-0005's CI layer plus a
   local feedback layer. The pattern does not include `docs/decisions/`, so a new ADR file without a
   register row is caught by `make lint` and CI, not by the local hook; adding that path is a one-word
   change if the owner wants it local too.
   *Why a separate hook and not a wider `validate-script-tests`.* Issue #354 narrowed that hook so docs
   commits skip the whole script-tests run; widening its `files:` to design.md, README and the roadmap
   would re-slow every docs commit and undo #354. Its guard suite also asserts the opposite:
   `test_script_tests_hook_scope.sh` lines 454 and 455 require `README.md` and `docs/roadmap.md` to be
   NOT covered.
   *The suite.* `.agent/scripts/tests/test_design_anchors.sh` (new, `chmod +x`) tests the checker, not
   the real docs. It builds small trees under its private `TMPDIR`: (a) a negative fixture with a
   design.md and a citing file containing `docs/design.md#no-such-section` (checker must exit 1 and
   name the citation); (b) a positive fixture with only valid anchors (exit 0); (c) a fixture whose
   citing file holds a `#<section>` placeholder and a design.md that mentions `(#295)` and
   `[x](#12)` (both ignored, exit 0); (d) a fixture with a `docs/decisions/` of three files and a
   register with two anchored rows (exit 1), and a design.md with no in-file links (exit 1). Because it
   reads only fixtures, it stays under the existing `validate-script-tests` hook (`.agent/` is covered)
   and satisfies the #354 guard's ROOT_READERS rule without any entry: it finds the checker with a single
   `$SCRIPT_DIR/../check_design_anchors.sh`, which the guard's root-derivation scan (`(\.\./){2,}` and
   its siblings) does not match. If it ever did derive a root, the entry to add would be
   `.agent/scripts`, which the hook covers. `test_script_tests_hook_scope.sh` is therefore not in Files
   to Change: its assertions at lines 454 and 455 and its parsed hook block stay as they are. Not done:
   an assertion that the new hook's `files:` keeps covering the seven paths (it would make the suite
   read the real config and need a ROOT_READERS entry); the CI run of `make lint` is what catches a
   dropped path.
   *Where it runs.* Locally on the commits it exists for (new hook), in `make lint` and CI (same hook),
   and its logic on any `.agent/` commit (script-tests suite). Test what breaks: renaming a section
   breaks citers silently otherwise.

7. **The "System design" label.** `docs/design.md` is labelled "System design" in `README.md` line 22,
   `.agent/AGENT_ONBOARDING.md` line 91, `AGENTS.md` line 436 and `CLAUDE.md` line 36. PR C changes the
   label in README and AGENT_ONBOARDING to "Design: how the parts fit today". `.claude/skills/brainstorm/SKILL.md` line 34 calls it "system design and layering
   constraints"; PR C changes that to "how the parts fit today". `AGENT_ONBOARDING.md` is the "Other"
   framework row of the adapter table in `AGENTS.md` (line 12), so its edit is near Ask First ground;
   the owner's approval of this plan covers that one-line label edit. `AGENTS.md` and
   `CLAUDE.md` are Ask First and are not touched, so they keep the old label until the owner decides
   (listed under the follow-up issue).

### PR split

- **PR A: destinations.** Fill the gaps found above (lifecycle file exit-contract paragraph;
  `lock.sh` header; `validate_workspace.py` docstring prefix line). Replace real project names
  (`gz4d`, `p11*`, `project11-ng`) with synthetic ones, because the workspace stays project-agnostic
  and the new design.md points at these as the examples: `_project_registry.sh` header (lines 11-14),
  `.agent/projects.local.example` (lines 52, 72-76), `WORKTREE_GUIDE.md` (lines 72, 181) and, as
  user-visible text, the `Makefile` help line (line 80, `make build PROJECT=gz4d`) and the ADR-0016 row of
  `.agent/knowledge/principles_review_guide.md` (line 51, "#317's gz4d acceptance run"). Boundary,
  stated: code comments keep the real names (`ros2_colcon/adapter.sh` line 835 and `merge_pr.sh`
  line 497 cite the real checkout where a bug was found, #237); test sandboxes and fixtures keep their
  names (`tests/test_*.sh`, `tools/ros-manifest/tests/`); ADRs and the roadmap are history. Also fix the
  ADR-0017 link. Nothing is deleted yet.
- **PR B: the rewrite.** New `docs/design.md`, the deletions, the guide-row edit (line 71), the anchor
  checker script, its pre-commit hook in `.pre-commit-config.yaml` and its script-tests suite. Section
  commits kept separate; the checker and hook land first, so each later section commit is checked.
- **PR C: wire-in.** Skills (citing by anchor), roadmap (open items, Cross-cutting note), README pointer
  and label, the `AGENT_ONBOARDING.md` and `brainstorm` labels. `Closes #335`.

B and C may merge together if the owner prefers fewer reviews. Review depth is at least Standard
(governance files). Both reviews and the merge stay the owner's call (standing rule).

## Files to Change

| File | Change | PR |
|------|--------|----|
| `.agent/knowledge/review_loop_lifecycle.md` | Add exit-contract and dispatch paragraph (`--check-exit`, its four results, fresh sub-agent per phase, ADR-0014/0015) | A |
| `.agent/scripts/lock.sh` | Header paragraph: advisory lock, file path, who reads it | A |
| `.agent/scripts/validate_workspace.py` | Docstring: failure-line prefix (optional) | A |
| `.agent/scripts/_project_registry.sh`, `.agent/projects.local.example`, `.agent/WORKTREE_GUIDE.md` | Synthetic project names in the examples (real names found at the lines above) | A |
| `Makefile` | Help line 80: `PROJECT=gz4d` becomes a synthetic name | A |
| `.agent/knowledge/principles_review_guide.md` (line 51) | ADR-0016 row: drop the real project name from the acceptance-run wording | A |
| `docs/decisions/0017-design-document-is-the-current-picture.md` | Fix the ADR-0008 link filename | A |
| `docs/design.md` | Rewrite per the section table | B |
| `.agent/knowledge/principles_review_guide.md` (line 71) | Consequences Map row "Work-plan directory convention": replace the directory-tree cell | B |
| `.agent/scripts/check_design_anchors.sh` (new, `chmod +x`) | The anchor checker: citation form, scope and register count as in Wire-in 6; grep and awk only | B |
| `.pre-commit-config.yaml` | New local hook `check-design-anchors` (files: the seven paths in Wire-in 6), placed before `validate-script-tests`. Ask First (CI-like config), approved with this plan (B4) | B |
| `.agent/scripts/tests/test_design_anchors.sh` (new, `chmod +x`) | Tests the checker with fixtures only (negative, positive, placeholder and issue-ref, register count); reads no real docs | B |
| `.claude/skills/{review-issue,review-plan,plan-task}/SKILL.md` | Section wording cites the real anchors `$WS_ROOT/docs/design.md#how-it-works` and `#the-design`, plus the `#<section>` placeholder (Wire-in 2) | C |
| `.claude/skills/audit-workspace/SKILL.md` | Checks the dates, only if A4 is accepted | C |
| `docs/roadmap.md` | Open and planned items name the design section; Cross-cutting Decisions note and pointers | C |
| `README.md` | Under `## Workspace goals`, a closing pointer to `docs/design.md#how-it-works`; the Documentation list label (line 22) | C |
| `.agent/AGENT_ONBOARDING.md` (line 91) | The same "System design" label change as README (covered by plan approval, Wire-in 7) | C |
| `.claude/skills/brainstorm/SKILL.md` (line 34) | Label "system design and layering constraints" becomes "how the parts fit today" | C |
| Not touched | `.agent/scripts/tests/test_script_tests_hook_scope.sh` (its assertions at lines 454-455 and the `validate-script-tests` hook's `files:` stay as they are), `AGENTS.md` line 436, `CLAUDE.md` line 36 (Ask First; they keep the old label, see follow-up), `docs/principles.md` (principle wording is a separate change), accepted ADRs other than the link fix | |

## Prior Art

Not re-researched. Used: `prior-art-comparison-2026-10-08/summary.md` (ten findings, each folded
above as a marked candidate; detail in `comparison-with-se-approaches.md`,
`how-human-processes-fail-with-agents.md`, `what-others-do.md`); the 2026-10-01 notes
`prior-art-alignment-human-teams.md` (ADR practice, Google design docs, arc42 solution strategy),
`prior-art-alignment-agent-frameworks.md` and `prior-art-alignment-agents-evidence.md`;
`oss-doc-survey.md` (vision and design live in README prose, no separate VISION file);
`redesign-fragments.md` section 13 (document kinds; roadmap needs a forcing function);
`zero-footprint-inventory.md`. Taken: reference plus dated records with a merge-time update step
(matches ADR-0017); the admission test; the draft-then-merge shape of the world-store design draft.
Held as candidates, not taken: dated sections, enforced-by column, instruction-layer budget.
Rejected for now: a separate VISION file; a document-kind vocabulary from the fork's
planning-document proposal beyond the seven roles the owner chose; a hard line cap (owner, Q1).

## Design Picture

This plan is the change to the design picture: `docs/design.md` is rewritten whole. It also changes
which design section the planning and review skills cite (headings in the new file).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | The deliverable. Five status values keep decided, built, proven and proposed apart; the roadmap's stale second copy is marked history |
| Only what's needed | Admission rule, 60-line prompt, detail goes next to code; each research candidate is owner-accepted, not added by default; no separate name list |
| A change includes its consequences | Moves confirmed before deletion; the guide's directory-tree row, skills, roadmap and README updated in the PR that makes each stale; ADR link fixed |
| Leave a trail; start limits strict | Decision register and change log with line counts; each section its own commit |
| Ask about what matters, and show how much | Design questions asked one at a time with what each changes (list below) |
| Verify before claiming | Every "Now" line cites its source and is spot-checked; revision 2 rechecked every "already lives" claim and found three wrong |
| Know whether it works | With/without test; line count in the change log; section dates if accepted; Measures role shown honestly as "none yet" |
| Put each thing at the level it applies to | Script detail to script headers; per-project mapping is project-level, the workspace's own mapping is here |
| Leave in a project only what it chose to carry | Footprint is Target, not described as built |
| Look for prior art before building | Prior Art section above |
| Small steps; step back when they stop converging | Three PRs, one commit per section; if sections keep passing 60 lines or the owner's edits keep reshaping the table, stop and propose a simpler section set instead of patching |
| Test what breaks | The checker runs in a new pre-commit hook on the commits that can break an anchor (design.md, README, roadmap, onboarding, knowledge files, skills, the config itself), then in `make lint` and CI; `test_design_anchors.sh` tests the checker with a negative fixture that must fail, so the check is shown to catch a broken anchor. The script-tests hook is not widened (#354). The rest of the change is documentation, covered by the with/without test and spot-checks |
| Enforce what matters, as simply as possible | The admission rule is a review check, backed by the cheapest mechanical check that fails when a name breaks (the grep-level anchor checker and its hook) and a recorded line count in place of a cap |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0017 | Yes | The plan implements it; the rewrite reconciles design and ADRs and records standing in the register |
| 0001 | Yes | No new ADR here; one is written only if the rewrite changes a decision two parts could choose incompatibly |
| 0008 | Yes | ADRs get no design pointers (register only); the one ADR edit is a link fix, which ADR-0008 permits |
| 0016 | Yes | Provisional: shown as `decided, not proven` until the acceptance run |
| 0003 / 0011 | Yes | 0003 is superseded by 0011; the workspace stays project-agnostic, no project names; the Registry row cites both |
| 0005 | Yes | The anchor check follows its layers: a pre-commit hook for local feedback, the same hook in CI lint as the enforcement layer |
| 0013 | Yes | Entries via `progress_append.sh` |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Design section names | Skills, README, roadmap, register column, anchor checker | Yes (checker, hook and suite PR B; skills, README and roadmap PR C) |
| Anchor checker added | `.pre-commit-config.yaml` (new hook, files: the seven paths); `test_design_anchors.sh` (fixtures only); NOT `test_script_tests_hook_scope.sh` or the script-tests hook's `files:` (#354 scoping and its lines 454-455) | Yes (PR B); the hook is Ask First, flagged at plan approval (B4) |
| Real project names in user-visible text | Makefile help line, review guide ADR-0016 row | Yes (PR A); code comments and test fixtures keep names |
| The "System design" label | README, `AGENT_ONBOARDING.md`, `brainstorm` skill (PR C); `AGENTS.md`, `CLAUDE.md` | README, onboarding and brainstorm yes; the other two No, Ask First (follow-up) |
| Directory tree removed | Review guide Consequences Map row "Work-plan directory convention" | Yes (PR B) |
| Detail removed from design.md | Its destination file | Yes (PR A, verified first) |
| Registry or adapter text | `adapter` and registry headers | Yes (verified; no gap found) |
| Lock text removed | `lock.sh` header (nothing else documents it) | Yes (PR A) |
| README Workspace goals pointer | README Documentation list label | Yes (PR C) |
| Roadmap Cross-cutting Decisions | The design sections that now hold the facts | Yes (PR C; B2 open) |
| Roadmap rows that change the design picture | A "design section:" note on those rows only; the other open rows stay as they are | Yes (PR C) |
| `AGENTS.md` (instruction budget) | Framework adapters | No, Ask First |

## Open Questions

Grouped by what they change. Stable IDs; ask in group order, each design question on its own.

**Decided**
- **Q1 (decided 2026-10-08).** Status marking yes with five values; Now block with sources, Target
  only where it differs; "Proposed:" and "(candidate)" markers; no hard line cap; admission rule
  plus a 60-line prompt plus line count in the change log; no length guide for How it works.

**A. Shape of the document**
- **A1.** A part with no Target: carry the `Now` label anyway, or leave it implicit (Status line and
  text only)? Q1 decided Now/Target and the Status marks; this is only the label. Cosmetic; trivial to change.
- **A2.** Placement of the admission rule: opening paragraph of `# The design` (this plan) or an
  unheaded note above `# How it works`. Changes the first screen of the file; trivial to undo.
- **A3.** The "enforced by" column in Rules. Shows gaps; needs upkeep; easy to undo.
- **A4.** `Checked: <date>` per section, refreshed by `/audit-workspace`. Adds upkeep and touches one skill; easy to drop.
- **A5.** Candidate sections: instruction layers (section 12) and the tree line in How it works. Each is an add or drop; cheap.

**B. Wire-in**
- **B1.** Should accepted ADRs carry a pointer to their design section (issue scope item 3)? Needs a
  scope note on ADR-0008 (or a superseding ADR). Default in this plan: no. Hard to undo once ADRs are edited.
- **B2.** Roadmap Cross-cutting Decisions: mark as history (this plan), delete, or leave. Marking is easy to reverse.
- **B4.** The new pre-commit hook `check-design-anchors` in `.pre-commit-config.yaml` (Ask First: CI-like
  config). This plan adds it, so a heading rename is caught on the commit that makes it, without
  widening the script-tests hook. Alternative: no hook, the check runs only in the script-tests suite
  and CI (a rename then fails after the push, not at the commit). Easy to remove.

**C. Content that stays open in the document**
- **C1.** Register scope and which ADRs the rewrite supersedes (ADR-0016 is Provisional). Superseding is hardest to undo; wording of standing per ADR is easy.
- **C2.** Workspace as a registered project (#295) or ADR-0016's interim rule made permanent. Hard to
  undo once built; the document can carry it as `open`.
- **C3.** Where a zero-footprint project's design and records live (workspace repo, a store outside
  both repos, or host-tool memory only). Decides the Worktrees Target and the work-plans conflict; can stay open.
- **C4.** `onboard-project` as the only registration path (#332), project lifecycle (unregister, one
  project on two machines) and mixed-flavour projects (#310). Shapes the Registry Target; can stay open.
- **C5.** What a review finding must contain (principle, guide row, or design text only). If design
  text only it goes in "Review loop and timeline"; if a principle, a separate change.

Settled by a principle, so not asked: keeping the anchor test (formerly B3; "Test what breaks").

### Follow-up issue (to open with owner approval)

These change principle or guide wording, or instruction files, and are not this document. They go on
their own issue, opened only if the owner says so; the design document does not wait on them.

- A countable step-back trigger for "Small steps" (a review-round limit).
- "Only what's needed" adds "after recording why it was there".
- Where a rule on editing or deleting existing tests belongs (principle, guide, or neither).
- A stated re-read trigger for the roadmap (Direction role).
- The "System design" label for `docs/design.md` in `AGENTS.md` line 436 and `CLAUDE.md` line 36
  (Ask First), so all four places agree after PR C.

Dropped: the former Q14 (mention session-clearing advice at all), per the standing rule against proposing it.

## Estimated Scope

Three PRs (A: destinations; B: the rewrite, the anchor checker with its hook and suite; C: wire-in), merge-able as two. The
writing is paced by the owner's edits (process step 2 first), not by drafting. Register sizing: 17 rows
written in PR B; nine of them (0002, 0003, 0011, 0012, 0013, 0014, 0015, 0016, 0017) are checked against
the code each describes, one short read per ADR done in the commit of the section that cites it; the
other eight are `not yet`. PR A is small (one script header, one docstring line, one paragraph, name
swaps in three files plus the Makefile help line and one guide row). PR B gains one small script
(grep and awk), one hook entry and one fixture suite.

## Revision 2 change log

Items 1 to 8 are the review's must-fix findings; S1 to S8 its suggestions (the entry lists 8
suggestions, not 7). Document line counts for the rewrite start with the first section commit.

| Item | What changed |
|---|---|
| 1 | "What leaves design.md" rebuilt from the files: resolution order is in the `adapter` header and `projects.local.example` lines 62-67; the lock is in no document (WORKFORCE_PROTOCOL section 3 is task locking), so `lock.sh` gets a header in PR A; the lifecycle file gets an exit-contract paragraph (it cites ADR-0014 once but not `--check-exit`) |
| 2 | Review guide Consequences Map row "Work-plan directory convention" added to Files to Change and the Consequences table (PR B) |
| 3 | `# How it works` is the first heading in the file; HTML-comment name list dropped; heading `Rules` chosen with the reason given |
| 4 | Roadmap wire-in limited to non-done items; Cross-cutting Decisions marked as history, with duplicate subsections replaced by pointers (B2 asks the owner) |
| 5 | ADR "Current description" addenda dropped (register only; B1 asks about a scope note); ADR-0017's ADR-0008 link filename fixed in PR A |
| 6 | Main merged (306938a); plan updated for #375 and #376 merged and AGENTS.md at 442 lines (was 431) |
| 7 | Status has five values including `decided, not proven`; ADR-0016 assigned to it |
| 8 | Line column, budget and 240 cap removed; admission rule, 60-line prompt and line count in the change log replace them; register has no row limit |
| S1 | Anchor test moved to PR B |
| S2 | `$WS_ROOT/docs/design.md` in the three both-scope skills; audit-workspace stays plain |
| S3 | Rules keeps only rules with an enforcement fact `AGENTS.md` lacks; four verified examples named |
| S4 | Open questions regrouped (Decided, A to D, stable IDs); old Q14 dropped |
| S5 | Synthetic-name changes placed in PR A; checked: real names do appear in three files (list in PR A) |
| S6 | Self-check gains "Small steps", "Test what breaks", "Enforce what matters" rows |
| S7 | Register gets a Purpose line and a Re-examined column (`yes <date>` / `not yet`) |
| S8 | README heading verified as `## Workspace goals` (README.md line 26) and used |

## Revision 3 change log

Answers plan review round 2 (entry `9cfd1fe`): items 1 and 2 are its must-fix findings (N1, N2), items
3 to 7 its suggestions (N3 and findings 4, 5, 7, 8), F1 and F2 its small false facts (finding 6). The
rewrite's line count is still logged from the first section commit.

| Item | What changed |
|---|---|
| 1 | Status is per block: a Now block and, only where it differs, a Target block, each with one status value. The key and the section table now agree (separate Now and Target columns, no compound values) |
| 2 | Anchor test re-specified (Wire-in 6): one citation form, `docs/design.md#<slug>` outside and `(#<slug>)` inside design.md; scope widened to README, AGENT_ONBOARDING, skills, knowledge files, roadmap and design.md's own links, including the register's section column; skills and README cite by anchor in PR C; a negative fixture with a broken anchor must fail, and a check that the register carries an anchor per ADR keeps it from passing vacuously. Stays in PR B |
| 3 | Real names: the Makefile help line (line 80) and the review guide ADR-0016 row (line 51) are added to PR A. Boundary stated: code comments (`ros2_colcon/adapter.sh` line 835, `merge_pr.sh` line 497), test sandboxes and fixtures, ADRs and the roadmap keep the names. The revision 2 line "three files" undercounted: five user-visible places change (three example files, the Makefile line, the guide row) and two code comments keep the names |
| 4 | B3 dropped (settled by "Test what breaks"); A1 cut to the one thing Q1 left open (the `Now` label on a part with no Target); D1 to D4 moved to a "Follow-up issue (to open with owner approval)" subsection, which also lists the `AGENTS.md`/`CLAUDE.md` label. Nothing there blocks this issue |
| 5 | The departure from issue scope item 3 (no per-ADR pointer) is stated in the Issue section with the ADR-0008 reason, and Wire-in 3 says so. New row 3 `## Purpose` carries the issue's Purpose part; rows renumbered to 15 and A5 now says section 12 |
| 6 | Register "Re-examined" named: `yes` for ADRs 0002, 0003, 0011, 0012, 0013, 0014, 0015, 0016, 0017 (the ones PR B sections cite), `not yet` for 0001 and 0004 to 0010; sized in Estimated Scope |
| 7 | `AGENT_ONBOARDING.md` line 91 checked: it carries "System design". It changes in PR C with README (Files to Change, Wire-in 7). `AGENTS.md` line 436 and `CLAUDE.md` line 36 stay (Ask First) and are listed in the follow-up |
| F1 | "Directory tree (lines 11-66)" is now "Directory Structure section (lines 11-58); Project Repository Model starts at line 60" (checked in `docs/design.md`) |
| F2 | `projects.local.example` "lines 62-67" is now 62-69 (checked in the file) |

## Revision 4 change log

Answers plan review round 3 (entry `e3c3eac`): item 1 is its must-fix (finding 1), items 2 to 8 its
suggestions (findings 2 to 8, all applied). The plan is 496 lines. The rewrite's line count is still
logged from the first section commit.

| Item | What changed |
|---|---|
| 1 | The anchor test never ran locally on a docs-only commit: the `validate-script-tests` hook does not cover design.md, README or the roadmap, and the #354 guard asserts README and the roadmap stay uncovered (lines 454-455). Not widened (that would re-slow docs commits). PR B instead adds a grep-level checker `.agent/scripts/check_design_anchors.sh` and its own pre-commit hook `check-design-anchors` with `files:` covering the seven paths. `test_design_anchors.sh` now tests the checker with fixtures only, so it stays under the existing hook and needs no ROOT_READERS entry. Added to Files to Change, Consequences, PR split, Wire-in 1 and 6, the "Test what breaks" row and ADR table (0005). New question B4 flags the hook (Ask First) for plan approval |
| 2 | In-file link form is `](#<slug>)` with a slug that is not all digits; `(#295)` and similar are never matched. A fixture checks it |
| 3 | Wire-in 2 and the skills row use the real anchors `#how-it-works` and `#the-design`, plus one `#<section>` placeholder that the checker ignores (anchor pattern excludes `<`; fixture checks it). The checker's home is `.agent/scripts/` (Wire-in 6, Files to Change) |
| 4 | Wire-in 7 and process step 1 say plan approval covers the `AGENT_ONBOARDING.md` label edit ("Other" row, `AGENTS.md` line 12); `AGENTS.md` and `CLAUDE.md` stay in the follow-up |
| 5 | Status key: an `open` block holds only a pointer, no question text; row 6 Target wording follows. Row 5 gets one clause saying why Now is `decided` while the enforced-by column awaits A3 |
| 6 | ADR-0003 added to the Registry row (row 7: superseded by 0011, doctrine carried forward), so its `yes` has a section behind it. Register row also says why 0004 and 0005 stay `not yet` |
| 7 | Wire-in 4 limited to roadmap rows whose issue adds, removes or re-shapes a part named in a design.md section (34 non-done rows counted: 27 planned, 4 in progress, 3 deferred); the rest untouched, PR C lists the counts. Consequences row added |
| 8 | `brainstorm` SKILL.md line 34 label touch added to PR C, Files to Change and the label Consequences row (line verified) |
