# Plan: Workspace design document, phase 3 (rewrite docs/design.md as the current picture)

Revision 9 (2026-10-09). The owner approved revision 6 on 2026-10-09 (the `## Checkpoint` entry in
`progress.md`). This revision does not reopen the plan. It applies the owner's decisions on the A
group (shape of the document, A1 to A5; owner decision 2026-10-09: "Go for group A", the host's
recommendations accepted as stated) and cites issue #379, opened the same day for the merge-gate
lookup gap that revision 8 recorded. After this revision the only open questions are B1, B2, C4 and C5.
Revision 8 applied the owner's decisions on C2 (the workspace as a registered project: leave it open,
add an inventory) and C3 (where an issue's work plan and progress timeline live), both owner decisions
of 2026-10-09. Revision 7 recorded that PR A is merged (#377, merge commit `249a8d0`), applied the decisions on C1 and C6 and folded in the two
accepted suggestions from plan review round 5 (entry `65fb3c4`, verdict ready). Revision 6 applied
four owner decisions of 2026-10-09 (hook scope, label, purpose and anchors, glossary); revision 5
answered plan review round 4 (needs-work, entry `ffa20fe`), revision 4 answered round 3 (entry
`e3c3eac`), revision 3 answered round 2 (entry `9cfd1fe`), revision 2 answered round 1 (entry
`6f8c643`) and the owner's decision on the shape of the document (2026-10-08). What changed is in the
"Revision 2" to "Revision 9 change log" sections at the end.

## Issue

https://github.com/rolker/agent_workspace/issues/335 (phase 3 of 3). Phases 1 and 2 are done and
merged: the principles PR (#375, merge commit `b7e8838`) and the AGENTS.md follow-ups (#376, merge
commit `ea0df4a`). `AGENTS.md` is 442 lines on main after #376. PR A of this plan is merged too: #377,
merge commit `249a8d0`, 2026-10-09 (what it landed is under "PR split").

**Where this plan departs from the issue text.** The issue's scope item 3 asks that "existing ADRs
get a one-line pointer to their design section". This plan does not do that: the mapping lives only in
the Decision register. Reason: ADR-0008 permits a Status-line note of a related ADR, a References
list and link or typo fixes, and a pointer line is none of those; an accepted ADR that gains one can
read as a restated decision, and ADR-0017 makes ADRs history. Whether to widen ADR-0008 so ADRs can
carry a pointer is open question **B1**. The departure is recorded in a comment on the issue once the
owner approves this plan. The issue's "Rules that must stay true" part is headed `Rules` (reason
under "Why `Rules`"), and its "Purpose" part has its own row in the section table (accepted, owner
decision 2026-10-09: "Accept both.").

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

1. Plan reviewed (rounds 1 to 5 done) and approved by the owner at revision 6 on 2026-10-09; this is
   revision 9, which applies decisions made after that approval. Worktree for #335 exists. PR A is
   merged (#377). No PR B section is written before the owner's say-so on the plan. The new pre-commit hook in PR B is CI-like config (CI runs
   `make lint`, which runs every hook), so it is Ask First; the owner approved it on 2026-10-09 (owner
   decision 2026-10-09: "Yes, and watch the ADR directory too."), which settles question **B4**.
2. **"How it works" first, in the owner's words.** The agent supplies only a list of the facts and
   decisions it must cover (from H1 and the 16 principles' Serves lines), not prose. The owner writes
   or edits the paragraphs; the agent trims nothing without asking, and there is no length guide for
   this section. Everything below hangs off it.
3. **Then one section at a time**, in the order of the table below. Per section the agent drafts
   "Now" from code and records only (each line cites a script, ADR or file it was checked against),
   drafts "Target" only from recorded decisions, and turns every gap into an Open Questions row. The
   owner edits; one commit per section (atomic, so a dropped section drops cleanly). The glossary is
   the one section whose content is not drafted first: the owner settled which terms go in and wrote
   the plain one-line definitions (question **C6**, decided 2026-10-09, row 16); the agent only fits
   them into the document.
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
reference updates at merge, ADR-0017) and the Status key. Every other part is an H2 under it. The admission
rule is the opening paragraph of `# The design`, not a note above the H1, so `# How it works` (the
owner's prose) stays first and unencumbered (decided, owner decision 2026-10-09, A2: "Go for group A").

**Status.** Status is per block. A part has a `Now` block (what the code does today, with the source
each line was checked against) and, only where it differs, a `Target` block. Every `##` section
carries the label `Now`, also when it has no Target (decided, owner decision 2026-10-09, A1: yes);
`# How it works` (the owner's prose) and the opening paragraph of `# The design` (which holds this
key) carry no label. Each block opens with one
line `Status:` taking exactly one of five values, so a part can be `decided` now and `proposed` as a
target. A part with nothing built has one block, labelled `Now` (A1), with the status `proposed` (row 12).
A block holds statements of one status; if
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
`Now`, except in a part with nothing built (row 12, Instruction layers), whose single block is
labelled `Now` for A1 and carries `proposed`. `Target` paragraphs start with "Target:"; each proposal inside starts with "Proposed:" and moves
to `Now` when built (the change that builds it makes the move). A part with no Target carries the
`Now` label and one status line (A1, decided). Research candidates are marked `(candidate)` in the
draft so the owner accepts or drops each before the PR; no `(candidate)` marker survives into the
final text. As of revision 9 every candidate raised so far is accepted or dropped (A1 to A5 included),
so the marker is for anything new the drafts surface.

**Sections** (document order; no line column, since there is no cap). Status is given per block: the
Now column is the status of the part's Now block, the Target column the status of its Target block, `-`
where the part has none.

| # | Section (stable heading) | What goes in | Now | Target |
|---|---|---|---|---|
| 1 | `# How it works` | Owner's words. Core ideas, day-to-day harness plus long view, principles connect them; README Workspace goals ends with a pointer. No tree and no tree pointer: the directory tree leaves the document, and a pointer would only point at the repo (decided, owner decision 2026-10-09, A5) | decided (H1) | - |
| 2 | `# The design` opening | Admission rule; the split (current picture / ADRs / `progress.md`); update-at-merge; the Status key | decided (ADR-0017) | - |
| 3 | `## Purpose` | Two or three sentences: what this file is for (how the parts fit today, checked at merge). Points at README `## Workspace goals` and `docs/principles.md` without restating them. This carries the issue's "Purpose" part (row accepted, owner decision 2026-10-09) | decided (ADR-0017) | - |
| 4 | Documentation layers | The seven roles; where each lives for the workspace (Goals: README `## Workspace goals`; How it works and Design: this file; Principles: `docs/principles.md` and the review guide; Decisions: `docs/decisions/`; Direction: `docs/roadmap.md`, "healthy" has no home yet; Measures: none yet). Shows the two gaps honestly. How a project maps its own is Target, seeded by `discover_governance.sh` types | decided (the roles and the workspace's mapping) | proposed (per-project mapping) |
| 5 | Rules | See "Why `Rules`" below. One table: rule, principle it implements (cited, not restated), enforced by. Only rules that carry an enforcement fact `AGENTS.md` does not state. Candidates verified in this revision: no commit to a protected branch, commit identity set, issue number matches the branch (all pre-commit hooks); progress entry shape (`_progress_entry.sh` and `progress_append.sh` validate it); the merge gate (`merge_pr.sh`). The column takes exactly one of five values: hook, script, CI, review only, nothing (decided, owner decision 2026-10-09, A3: yes). Rules with no check (for example worktree for all work) are listed as review only or nothing from the first commit. Now is `decided` because each listed rule and its check were verified; the "review only" and "nothing" entries are facts shown in the column, not a status | decided | - |
| 6 | Sessions and roots | A session starts in the workspace or in a project root; the user tier supplies the workspace layer to project sessions (ADR-0016). Target: the workspace as a registered project, a pointer to #295 only (an `open` block holds no question text) | decided, not proven | open (#295) |
| 7 | Registry and adapters | Registry maps names to roots and types; a 12-verb adapter contract per project type (ADR-0011, which supersedes ADR-0003 and carries its project-agnostic doctrine forward; one clause says so, which is why 0003 is checked in PR B); resolution order in one sentence. GitHub is not a project dependency, the workspace uses it for now (owner 2026-10-05). **Inventory, in this section's Now block (owner decision 2026-10-09, C2):** two tables from one grep pass. (1) Every place where the workspace path differs from the registered-project path in the scripts: the `--type workspace|project` switch sites and the cwd derivation that stands in for them, named by script. (2) The 12 adapter verbs, each marked for the workspace, if it were a registered project, as real, thin wrapper or no-op. **Purpose:** #295 is decided by reading these two tables after the ADR-0016 acceptance run (#317), not by a hunch. Owner's reasoning: sorting project functionality from workspace-only functionality is a worthy goal; #295 is one route to it; the inventory is the cheaper probe. The seed found in this revision is under "Registry inventory" below and is re-verified when the section is written. The workspace as a registered project stays `open` in "Sessions and roots" (row 6), a pointer to #295 only. Target: `onboard-project` as the one registration path (#332), mixed-flavour projects (#310), project lifecycle register to unregister; the unsettled parts also sit in Open questions | decided (ADR-0011/0012) | proposed |
| 8 | Worktrees | Two kinds, workspace and project; why (ADR-0002); where they live is a pointer to the guide. **Records (owner decision 2026-10-09, C3).** Now: an issue's work plan and progress timeline are committed in the project repo on the issue's feature branch under `.agent/work-plans/issue-N/` (`progress_append.sh` line 87 writes `<repo-root>/.agent/work-plans/issue-<N>/progress.md`; ADR-0013 names that path). The one gap in the project case is shown, not hidden: `merge_pr.sh` anchors the gate's timeline lookup at `$ROOT_DIR/project` (line 670) and the gate is report-only for project PRs (lines 916, 929). The lookup gap is tracked as #379 (opened 2026-10-09, "merge_pr.sh review gate looks up a project PR's timeline at the legacy project/ path, not the registry root"); its one-line fix does not wait for the records resolver below. Target: what a project carries by choice, as two per-project settings in its registry entry, `location` and `tracking`, defaults derived when absent; three mechanisms; the colleague's project as acceptance test. Detail under "Records: where they live and whether they are tracked" below | decided | proposed |
| 9 | Review loop and timeline | **Names the eight phases in order** (`review-issue`, `plan-task`, `review-plan`, `implement`, `review-code`, `publish`, `triage-reviews`, `merge`), **with what each produces and who decides** (owner decision 2026-10-09, C6: the phase names are the workflow, described here, not glossary entries). Also: one entry per phase in `progress.md` (the only loop state), fresh-context sub-agent per phase (ADR-0013/0014/0015); where the work-plans directory lives. Target (candidates): which claims code verifies (exit contracts, entry validation, merge gate) versus self-reported; what a finding must contain and reviewer independence (C5); how a new session finds the records for its issue (the lookup is mechanism 1 of the row 8 Target); size bound on records | decided | proposed |
| 10 | Merge gate | The owner decides every merge; the gate checks review currency and CI on the reviewed head; bookkeeping-only commits exempt; enforce by default on workspace PRs (`merge_pr.sh`, `_bookkeeping.sh`) | decided | - |
| 11 | Identity | Agents sign work with framework identity, ephemeral per session; pointer to `AI_IDENTITY_STRATEGY.md`; tool-neutral rule and what degrades without the main tool (principle "Use the main tool fully" cited) | decided | - |
| 12 | `## Instruction layers` | A real section (decided, owner decision 2026-10-09, A5: keep it). The four layers an agent's instructions load in (always loaded, path-scoped, skill, on demand) and a budget for the always-loaded layer; this file is not always loaded. Sources: `AGENTS.md` is 442 lines (`wc -l`, this revision) against the Claude Code docs' target of under 200 lines per file, as the prior-art note records it (`prior-art-comparison-2026-10-08/summary.md` item 5; `prior-art-alignment-agent-frameworks.md`, Claude Code entry). Nothing is built, so its one block is labelled `Now` (A1) and carries `proposed`; the budget is a "Proposed:" line and no number is set in this plan. Changing `AGENTS.md` is Ask First and is not part of this plan | proposed | - |
| 13 | Decision register | **Purpose** (stated in the section): tell a reader which ADR still governs, so nobody follows a superseded or drifted one. One row per ADR (17, 0001 to 0017): one-line decision, standing, the design section that carries it as an in-file link `(#<slug>)`, and **Re-examined**: `yes <date>` for the nine ADRs PR B's sections cite and check against code (0002, 0003, 0011, 0012, 0013, 0014, 0015, 0016, 0017), `not yet` for the other eight (0001, 0004 to 0010), which the issue allows. **Standing values (owner decision 2026-10-09, C1-c): `in force`, `superseded`, `superseded in practice`, `Provisional`.** A drifted ADR gets `superseded in practice` plus one line saying what the code does instead. The register is the only place PR B records it: **no ADR file is edited in PR B**. ADR-0016 stays `Provisional`. The ADRs marked `superseded in practice` become candidates, listed for the owner after PR B; superseding happens afterwards, one ADR at a time, each the owner's call. **Rows with no carrying section** (0001 ADR process, 0006 AGENTS.md as shared file, 0007 make, 0009 Python policy, 0010 git-bug optional, per plan review round 5): the row's section link is `(#decision-register)`, the register's own anchor, so the implementer invents no section to satisfy the row count (Wire-in 6). Plan-level decisions that never got an ADR listed with their issue. ADR-0003 is superseded by 0011 and is cited by the Registry row (row 7), so its `yes` is backed by a section. ADR-0004 and ADR-0005 stay `not yet` even though the Rules enforced-by column touches their ground: the column cites the hooks and scripts that do the checking, not those ADRs' reasoning, and the issue allows `not yet` | decided | - |
| 14 | Open questions | Table: ID, question, owner, what it changes. Seeded from the questions below | open | - |
| 15 | Change log | Date, section, one line, issue/PR, **document line count**; appended in the same change that alters a section | decided | - |
| 16 | `## Glossary` (last in the document) | Owner decision 2026-10-09: "make it a glossary since it might have terminology that I'm not currently familiar with, so we should assume others might not be familiar with them too". One line per term, in plain words, for a reader who has never seen the workspace. **Rule: every term that appears in a situation report or checkpoint is in the glossary, except the eight phase names.** Those (`review-issue`, `plan-task`, `review-plan`, `implement`, `review-code`, `publish`, `triage-reviews`, `merge`) are the workflow, not vocabulary: they are described in order in the Review loop and timeline section (row 9), and are not glossary entries (owner decision 2026-10-09, C6). **Settled list (owner decision 2026-10-09, C6), with the owner's one-line definitions; the agent makes light edits for fit only.** *Own terms:* **phase**, one of the eight steps an issue passes through (names and order in the Review loop section); **round**, one pass of a review phase (round 2 is the re-review after fixes); **convergence**, rounds converge when each finds fewer must-fix items than the last (when they stop converging the loop steps back); **checkpoint**, a point where the loop stops and asks the owner (after the plan, before publish, before merge); **progress timeline**, the per-issue file where every phase writes an entry, so a new session can see what happened without re-reading the chat; **Integrated Review**, the entry `triage-reviews` writes (all review sources combined into one list of findings with a verdict on each); **must-fix / suggestion**, a review finding that blocks the next phase, versus one the implementer may take or leave with a reason. *Standard terms:* **stage gate**, work passes through fixed phases and a check at each boundary decides whether it goes on (our loop is one); **Definition of Done**, the agreed list of what must be true before work counts as finished (ours is the principles "A change includes its consequences" and "Verify before claiming"); **proposal status**, labels a proposal carries through its life (Kubernetes uses provisional, implementable, implemented; our ADRs use proposed, accepted, superseded; the design doc uses decided, decided not built, decided not proven, proposed, open); **ADR, Architecture Decision Record**, a short dated note recording one decision, its context and consequences (a record of history, not the current picture); **spike**, a short, throwaway experiment that answers one question, usually whether an approach works or what it would cost, before committing to it (ours: the plugin spike, #345, and the interop spike, Codex and agy as headless phase workers; not the same as prior-art research, which reads what others did); **backlog**, the ordered list of work not yet started (ours is the roadmap plus open issues); **circuit breaker**, a rule that stops work automatically when it exceeds a budget (we have none; the nearest is the review-round limit, `MAX_ROUNDS`); **reference versus record**, a reference says what is true now and is kept current, a record says what was decided when and is never rewritten (the design doc is the reference; ADRs and the progress timeline are records). That is 15 entries (the must-fix / suggestion pair is one). **Left out on purpose (owner): WIP limit and appetite.** The workspace has neither: a grep of `docs/`, `.agent/knowledge/`, `AGENTS.md` and the skills finds no use of either as a workspace term. The glossary's admission rule is the rule above (a newcomer cannot see the term from the code); there is no length guide beyond it. Its heading is an anchor like any other (`#glossary`, covered by the checker, Wire-in 6) | decided (C6) | - |

Section dates (decided, owner decision 2026-10-09, A4: yes, register rows only). Sections carry no
`Checked: <date>`. The register's `Re-examined: yes <date>` column (row 13) is the checked-date. PR C
adds one line to `/audit-workspace` step 2 telling it to refresh that column when it checks an ADR
against the code (Wire-in 2). Checked in this revision: step 2 of the skill today checks the Status
line, the listed consequences and whether `docs/design.md` records the current behaviour; it says
nothing about a register or a date.

**Why `Rules`, not `Rules that stay true`.** The heading is a citation anchor (`#rules`), so short and
stable wins. "Stay true" also promises more than the enforced-by column can back: some rules are
review only, and the table is there to show which.

### Registry inventory (the seed for row 7's Now block)

Owner decision 2026-10-09, C2 (C2-c plus an inventory): the workspace as a registered project (#295)
stays `open`; the probe is this inventory, one grep pass over the workspace-versus-project branches
in the scripts and the `adapter` header. **Purpose:** #295 is decided by reading the two tables after
the ADR-0016 acceptance run (#317, where ADR-0016 leaves Provisional), not by a hunch. Owner's
reasoning: the goal of sorting project functionality from workspace-only functionality is worthy;
#295 is one route; the inventory is the cheaper probe. Found in this revision (line numbers as of
`11a8fac`); PR B's Registry commit re-greps and corrects it before it is written into design.md, and
the inventory is cut back to what the #295 decision needs once that decision is made (the change log
says so). It is in the Now block by the owner's direction, and the admission rule is met by that
decision: the list is what a newcomer cannot see from any one script.

*Table 1: where the workspace path differs from the registered-project path.*

| Script | What differs | Lines |
|---|---|---|
| `worktree_create.sh` | Worktree base `wt_workspace_base` (`worktrees/workspace`) versus the registry entry's own root or `worktrees=` (`wt_project_base`); repo manifest from the adapter's `worktree_repos` for a project only, the workspace case never calls the adapter; draft PR to the workspace remote versus `$PROJECT_GH_SLUG`; `--layer` and `--package-repos` project only; `--type` derived from the cwd when omitted | 252-260, 301, 345, 546, 1023-1033 |
| `worktree_enter.sh`, `worktree_remove.sh` | Same `--type` check and cwd derivation; `--project` valid only with `--type project` | enter 143-174, remove 130-157 |
| `merge_pr.sh` | A project PR needs a resolved project root and an `origin` remote; PR-owner auto-detect queries both remotes; the roadmap update searches `PJ_REPO_ROOT`; the gate's timeline lookup is anchored at `$ROOT_DIR/project`, the legacy checkout, not `PJ_REPO_ROOT` (tracked as #379); the gate enforces on workspace PRs only and is report-only for project PRs "until #265 settles project timelines"; cleanup deletes the branch in `PJ_REPO_ROOT` and pulls the project too | 248-270, 379-418, 555, 670, 916 and 929, 1612-1630 |
| `dispatch_phase.sh` | `resolve_worktree`: workspace = `wt_workspace_base` plus the legacy base; project = `derive_project_name` (from `--project` or the registry), then the registry, transition and legacy bases; `--type` validated in all three modes | 122, 183, 302, 369, 461 |
| `gh_create_pr.sh` | Repo-safety check accepts the workspace slug or the slug of the legacy `project/` checkout; registered projects are not consulted | 215-229 |
| `worktree_list.sh` | A workspace worktree is recognised by the path `*/worktrees/workspace/*` | 149 |
| `_project_registry.sh` | `registry_derive_type_from_dir`: `project <name>` when the cwd is under a registered root, else `workspace` when inside the workspace checkout | 475-500 |
| `run-issue` skill and `agent start-task` | `--type` defaults to `workspace` and is threaded to `dispatch_phase.sh`, `worktree_create.sh`, `gh_create_pr.sh` targeting and `merge_pr.sh --type` | SKILL.md 47-54; `agent` 35, 91 |

Checked, no workspace/project branch: `review_progress.sh` (finds the records through the cwd's git
toplevel, lines 112 and 290), `progress_append.sh` (line 87), `_resolve_work_plans_dir.sh` and
`_bookkeeping.sh`. They matter to C3 (below), not to this table.

*Table 2: the 12 verbs of the `adapter` header, for the workspace as a registered project.* "Real"
means the workspace needs its own logic; "thin wrapper" means a script or target that already exists
does the work; "no-op" means the header allows doing nothing.

| Verb | For the workspace | Based on |
|---|---|---|
| `setup` | thin wrapper | the `setup-dev` and `git-bug` stamps (`Makefile` 98-115); `single_project/setup.sh` clones a project, which the workspace does not need |
| `sync` | thin wrapper | `single_project/sync.py` already syncs the workspace repo with the project |
| `validate` | thin wrapper, with care | `validate_workspace.py` checks the whole workspace and calls this verb for each registry entry, so the workspace's own implementation must not call back into it |
| `build` | no-op | nothing is built; `make build` runs the project's `BUILD_CMD` |
| `test` | thin wrapper | `.agent/scripts/tests/run_script_tests.sh`, the `validate-script-tests` hook's entry (`.pre-commit-config.yaml` 57-59) |
| `install` | thin wrapper | `user_tier_install.sh` (`make user-tier-install`) |
| `env` | no-op | the header: a type with no environment to expose emits nothing |
| `project_root` | real, trivial | prints the workspace root |
| `repos` | real, trivial | one `name:path` line |
| `scope_for_pr` | real, small | origin URL to `owner/repo`; `single_project`'s verb does this generically |
| `worktree_repos` | real, trivial | one line `<root>`, `.`, `feature/issue-<N>`; today `worktree_create.sh` does not call it for the workspace |
| `worktree_env` | no-op | no per-worktree environment |

Tally: 3 no-op, 5 thin wrapper, 4 real. The plan draws no conclusion from it; that is the #295
decision.

### Records: where they live and whether they are tracked (row 8)

Owner decision 2026-10-09, C3. The question was where an issue's work plan and progress timeline live
(C3 was raised as "where a zero-footprint project's design and records live").

**Why row 8 and not a new "Records" row.** C3 was asked as what decides the Worktrees Target, and the
records ride on the issue's feature branch, in its worktree; what a project carries by choice (row 8's
existing Target) is the same subject. A new row would renumber rows 9 to 16, change every "row N"
pointer in this plan and add an anchor, for a block of about 30 lines. If the written Target passes
the 60-line prompt, it splits out as a `## Records` section then; the anchor checker needs no change
(every heading is an anchor, Wire-in 6).

**Now (status `decided`).** The records are committed in the project repo on the issue's feature branch
under `.agent/work-plans/issue-N/`. Checked: `progress_append.sh` line 87, `_resolve_work_plans_dir.sh`
(the worktree's git toplevel, or `WORK_PLANS_DIR_OVERRIDE`), ADR-0013 line 11. The gap in the project
case is the one named in row 8 (`merge_pr.sh` 670, 916), tracked as #379. Its fix is one line: use the
registry-aware root at line 670 that line 555 already uses (`${PJ_REPO_ROOT:-$ROOT_DIR/project}`). It
does not wait for the one lookup in mechanism 1; the lookup would replace that line later, and #379 is
the first thing it fixes. The change that fixes #379 edits this sentence in the same change (ADR-0017).

**Target (status `proposed`).** Two per-project settings carried in the project's registry entry; each
has a default derived when absent.

- **location**: in the project repo (the default), or an outside path. The default outside path is a
  fixed derived one, for example a sibling directory of the project root; the exact path is chosen
  when this is built, not in this document.
- **tracking**: untracked; tracked in the project repo (the default when location is in the project
  repo); or tracked in a repo the user names. The design document gives no example that is the
  `agent_workspace` repo (owner: "I don't want to prohibit it, but I also don't want to encourage it").

| location | tracking | What it is |
|---|---|---|
| in the project repo | tracked in the project repo | Today. The records travel with the feature branch |
| outside | untracked | Zero footprint in the project; one machine |
| outside | tracked in a named repo | Zero footprint in the project; portable |
| in the project repo | untracked, through the clone's local exclude (`.git/info/exclude`) | Behaves like outside and untracked |

Other combinations are not named as working; whether the registry rejects them is decided when this is
built.

Three mechanisms, each a later build and none of it PR B work (PR B writes the Target text only):

1. **One lookup**, "where are the records for this project and issue", fed by the registry entry and
   used by every reader and writer. Today the path is written out at each one: `dispatch_phase.sh`
   (342, 344, 387, 479: the exit contract, `--check-exit` and `next`, which is what a resumed session
   reads), `merge_pr.sh` (674-675, 829-837: the gate and its `Merge` entry), `review_progress.sh`
   (112, 268, 290: `sources` and `persist`), `progress_append.sh` (87). `_resolve_work_plans_dir.sh` is
   the nearest lookup that exists, and `cross_model_review.sh --work-plans-dir` already feeds it an
   override. The seven skills that cite the path (`start-task`, `run-issue`, `plan-task`, `review-plan`,
   `review-code`, `triage-reviews`, `address-findings`) follow it. The gate's lookup at `merge_pr.sh`
   line 670 is the first of these to be wrong for a registered project and is tracked as #379; its
   one-line fix does not wait for this lookup.
2. **The merge gate's "same reviewed state" rule** (`_bookkeeping.sh`, shared with
   `review_progress.sh sources`) reads the record from where it lives and checks the project SHA the
   entry names; the walk changes repo. Finding the record at all is #379 (the gate looks in the legacy
   `project/` checkout), so that fix comes before this mechanism, not with it. Today both live in one worktree and the rule treats
   `.agent/work-plans/issue-N/*` and the roadmap as bookkeeping-only changes (`_bookkeeping.sh` line 190).
3. **Untracked records are per machine and per clone.** A second machine or a fresh clone starts with
   no timeline, and losing the directory loses the history. This is the cost of that combination and
   the design text says so plainly.

One rule: when records exist in two places, the registry setting names the source of truth.

**Acceptance test for this Target:** a colleague's project. By shape only: a single-repo web app
developed in a different style, with no GitHub issues or pull requests, and records where the
developer chooses. Both settings must be able to describe it. Because it has no pull requests, it
exercises the lookup and the tracking and not the merge gate (mechanism 2), which a project with pull
requests has to exercise.

### What leaves design.md and where it lands

Each row's destination was opened in this revision and compared with the current design.md text.
The gaps found were filled in PR A (merged, #377); those rows say "landed in PR A (#377)".

| Current text | Lands in | Verified state | Action |
|---|---|---|---|
| Directory Structure section (lines 11-58: heading and tree; "Project Repository Model" starts at line 60) | nowhere; `ls` and the script table in `AGENTS.md` show it | n/a | Delete. Keep only the three roots (workspace, project, user tier) inside "Sessions and roots". Also update the review-guide row (see Files to Change) |
| Registry field syntax (`parent=`, `worktrees=`, `role=`, `distro=`, `default_instance=`) | `.agent/projects.local.example` and `_project_registry.sh` headers | Both hold the five fields and the name/type/path rules | Delete |
| Resolution order (`--project`, then cwd inside a registered dir, longest match, then legacy `project/`; parent root to `default_instance`) | `.agent/scripts/adapter` header (the three steps) and `.agent/projects.local.example` lines 62-69 | Holds it. The plan's earlier claim that the registry headers hold it was wrong: `_project_registry.sh` documents only `registry_resolve_from_dir`'s longest-match rule at the function | Delete; keep one sentence in "Registry and adapters" |
| `validate_workspace.py` paragraph | `validate_workspace.py` docstring | Holds checks 1 to 5 incl. delegation to `adapter --project <name> validate`. The `project '<name>':` failure prefix (and the `parent root '<name>':` one) was in the code, not the docstring: landed in PR A (#377) | Delete the paragraph |
| `ros2_colcon` detail (layers, bootstrap URL order, distro rule) | `.agent/project_types/ros2_colcon/adapter.sh` header | Holds layers, URL order and distro rule; `vcs` import is in the code (line 425 area), not the header | Delete; one sentence in "Registry and adapters" |
| Worktree locations, exclusion, `COLCON_IGNORE` | `.agent/WORKTREE_GUIDE.md` (lines 78-107) | Holds locations, `.git/info/exclude`, `COLCON_IGNORE` | Delete |
| Stamp-based setup (ADR-0007) | `Makefile` header and ADR-0007 | Header lists three stamps (the design text lists two: it omits `git-bug.done`) | Delete |
| Build and Test (`project_config.sh` variables) | `AGENTS.md` Build & Test | Duplicate | Delete |
| Multi-agent coordination: "the workspace lock (`make lock`/`make unlock`)" | **Nowhere today.** `.agent/WORKFORCE_PROTOCOL.md` section 3 is GitHub-issue task locking, not this lock. The lock is `.agent/scripts/lock.sh` / `unlock.sh`, a file `.agent/scratchpad/workspace.lock` shown by `dashboard.sh`; nothing else reads it, so it is advisory only | Landed in PR A (#377): a header paragraph in `lock.sh` saying so (and the `make lock` help line in the Makefile). Delete the design text; concurrency in the design is worktrees plus the draft-PR visibility rule (WORKFORCE_PROTOCOL sections 1-3), one line in "Worktrees" |
| Identity management | `.agent/AI_IDENTITY_STRATEGY.md` | Exists | Compress to "Identity" |
| Review loop lifecycle paragraph | `.agent/knowledge/review_loop_lifecycle.md`, `run-issue` skill, `dispatch_phase.sh` header | Lifecycle file cites ADR-0014 once (line 5, as a pointer) and says `/run-issue` "checks the exit contract", but never names `dispatch_phase.sh --check-exit`, its `OK/PARTIAL/FAILED/MISSING` result, the fresh-sub-agent-per-phase rule, or ADR-0015. The `dispatch_phase.sh` header holds `--check-exit` | Landed in PR A (#377): the lifecycle file's "Exit contract and dispatch" section. Compress to "Review loop and timeline" |
| Governance bullets | `AGENTS.md` Boundaries and `docs/principles.md` | Duplicates | Delete |
| Two-shape (legacy `project/` vs registry) history | issue #172 and #265 plan | n/a | One Target sentence; delete when the legacy shape is dropped |

Rule for moves: nothing is deleted before its destination is confirmed to hold the text (open the
destination, quote the matching lines in the PR description); gaps are filled first (PR A).

What stays in "Registry and adapters" (owner decision 2026-10-09, C2): what the registry maps, the
12-verb contract per project type, the resolution order in one sentence, one sentence on `ros2_colcon`,
and the inventory (the two tables seeded above). Registry field syntax, the validate paragraph and
`ros2_colcon` detail leave as the table says. The inventory is the one place the section names scripts
line by line, on purpose: it is a dated probe for a pending decision, not a restatement of script
headers, and it is cut back when #295 is decided.

### Wire-in

1. **Names.** Headings are the names; there is no separate list and no HTML comment. Renaming a
   heading is a design change that updates every citer in the same change; the anchor check (6) catches
   a miss, on the commit that renames it (the new pre-commit hook), again in `make lint` and CI, and its
   own logic is tested by the script-tests suite.
2. **Skills.** `review-issue`, `review-plan` and `plan-task` all run in project sessions
   (`session_scope: both`), where a bare `docs/design.md` does not resolve. Their wording changes from
   "which design section" to "name the section by its anchor in `$WS_ROOT/docs/design.md`", with
   `$WS_ROOT` resolved by the skills' existing idiom. The skills cite by anchor, not by heading in
   prose, so the anchor test reaches them (the two anchors are accepted, owner decision 2026-10-09:
   "Accept both."): `review-issue` cites `$WS_ROOT/docs/design.md#how-it-works`
   for the goal an issue serves; `plan-task` and `review-plan` cite `$WS_ROOT/docs/design.md#the-design`
   for the Status key and the section list, and tell the agent to cite the matching section by its
   anchor, written in the skill text as `docs/design.md#<section>`. The skill text uses only the two
   real anchors above and that one angle-bracket placeholder; the checker ignores a placeholder because
   its anchor pattern is `[a-z0-9][a-z0-9-]*` and `<` does not match (a fixture proves it, Wire-in 6). Project issues keep the "the project's own design document, or say there is none"
   branch. `audit-workspace` (workspace scope only) keeps plain `docs/design.md` paths. PR C adds
   one line to its step 2 (A4, decided, owner decision 2026-10-09): when the audit checks an ADR
   against the code, it sets that ADR's `Re-examined` cell in the Decision register
   (`docs/design.md#decision-register`, cited by anchor so the checker reaches it) to `yes <today>`.
   The skill's Guidelines say "Report, don't fix"; this line is the one exception, a register cell and
   nothing else, and PR C words that Guidelines bullet to say so. No other date is added anywhere.
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
   the count left alone. #379 (the merge-gate lookup bug) is not such a row, so the roadmap is left
   alone for it: it fixes a lookup inside the Merge gate part, which already exists, and adds, removes
   or re-shapes no part named in a design.md section; `docs/roadmap.md` carries no row for it (grep
   finds no #379 there). Separately, `## Cross-cutting Decisions`
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
   `$WS_ROOT/docs/design.md#<anchor>` counts). The fragment is the run of `[A-Za-z0-9_-]` after the
   `#`. An empty run, as in the `#<section>` placeholder, is not a citation and is ignored. Any other
   fragment must match the lowercase pattern `[a-z0-9][a-z0-9-]*` or the checker reports it as a
   malformed anchor (exit 1), so a mistyped `design.md#How-it-works` or `#how_it_works` fails instead of
   slipping past a lowercase-only match; a fragment that matches is then looked up among the slugs.
   Inside design.md, including the
   register's section column, a Markdown link `](#<slug>)` whose slug is not all digits, so issue
   references such as a bare `(#295)` or a link written `[x](#295)` are never matched. `<slug>` is the heading's GitHub
   slug (lowercase, punctuation dropped, spaces to hyphens, repeats numbered `-1`, `-2`; `# How it
   works` is `how-it-works`). The checker computes slugs from the headings (skipping fenced code), so
   there is no second list to keep in sync.
   *Scope.* Every `docs/design.md#...` citation in `README.md`, `.agent/AGENT_ONBOARDING.md`,
   `.claude/skills/*/SKILL.md`, `.agent/knowledge/*.md` and `docs/roadmap.md`, and every `](#...)`
   link in design.md. PR C's README pointer and skill wording come under it as they land. Every
   heading in design.md is an anchor, the `## Glossary` heading (`#glossary`) included: a citation of
   `docs/design.md#glossary` resolves from the headings like any other, with no list to extend. The
   same holds for the new `## Instruction layers` heading (`#instruction-layers`, A5). PR C's
   `audit-workspace` line cites `docs/design.md#decision-register` from
   `.claude/skills/audit-workspace/SKILL.md`, which is in the checker's scope; it resolves only once
   the register heading exists, so PR C's skill commit comes after PR B's register commit. The `Now`
   label and the Rules column add no heading.
   *Anti-vacuity guards, conditional on the register.* The register section is identified by its
   heading anchor: the heading whose slug is `decision-register` (the section is named "Decision
   register", row 13). While design.md has no such heading, the checker does only the resolve check
   above, so the checker, hook and suite can land before the register exists. Once the heading exists
   (and `<root>/docs/decisions/` exists) two guards are live and each fails with exit 1: (a) design.md
   holds no `](#<slug>)` link at all; (b) the register has fewer anchored rows than there are
   `docs/decisions/*.md` files. A rewrite that drops the register's rows therefore cannot pass
   vacuously, while a rewrite that drops the register heading itself is caught in review and by the
   change log, not by the checker. *How the rows are found:* the lines that begin with `|` between the
   register heading and the next heading of the same or higher level, and that contain `](#`; the
   count is compared with `ls docs/decisions/*.md`, which is 17 today.
   *Register rows with no carrying section (plan review round 5, accepted).* Guard (b) needs 17
   anchored rows, but several ADRs have no design section of their own (0001, 0006, 0007, 0009, 0010).
   Such a row links to `#decision-register`, the register's own anchor, in its section column. The
   implementer invents no section to satisfy the count, and the checker accepts it because the slug
   resolves. Row 13 says the same.
   *The local hook.* PR B adds a second pre-commit hook beside `validate-script-tests`, in
   `.pre-commit-config.yaml` under `repo: local`, placed before `validate-script-tests` so the block
   that suite's guard parses is unchanged: id `check-design-anchors`, `entry: bash
   .agent/scripts/check_design_anchors.sh`, `language: system`, `pass_filenames: false`, and `files:
   ^(docs/design\.md$|README\.md$|docs/roadmap\.md$|\.agent/AGENT_ONBOARDING\.md$|docs/decisions/|\.agent/knowledge/|\.claude/skills/|\.pre-commit-config\.yaml$)`
   (eight paths). The pattern includes `docs/decisions/` (owner decision 2026-10-09: "Yes, and watch the
   ADR directory too."), so a commit that adds an ADR file without its register row fails guard (b) at
   commit time. That guard is live only once the register heading exists (the conditional guard above),
   so before then a new ADR file passes. A commit that renames a heading, edits a citer or touches the
   ADR directory now runs the check locally; `make lint` and the CI Lint job (`make lint` runs every hook
   on all files) run it again, which is ADR-0005's CI layer plus a local feedback layer.
   *Why a separate hook and not a wider `validate-script-tests`.* Issue #354 narrowed that hook so docs
   commits skip the whole script-tests run; widening its `files:` to design.md, README and the roadmap
   would re-slow every docs commit and undo #354. Its guard suite also asserts the opposite:
   `test_script_tests_hook_scope.sh` lines 454 and 455 require `README.md` and `docs/roadmap.md` to be
   NOT covered.
   *The suite.* `.agent/scripts/tests/test_design_anchors.sh` (new, `chmod +x`) tests the checker, not
   the real docs. It builds small trees under its private `TMPDIR`: (a) a negative fixture with a
   design.md and a citing file containing `docs/design.md#no-such-section` (checker must exit 1 and
   name the citation); (b) a positive fixture with only valid anchors, one of them `docs/design.md#glossary` against a
   `## Glossary` heading (exit 0); (c) a fixture whose
   citing file holds a `#<section>` placeholder and a design.md that mentions `(#295)` and
   `[x](#12)` (both ignored, exit 0); (d) a citing file with `docs/design.md#How-it-works` against a
   design.md that has the heading `How it works` (exit 1, malformed anchor); (e) the guards before the
   register exists: a design.md with no register heading and no in-file links, plus a `docs/decisions/`
   of three files (exit 0); (f) the guards once it exists: the same trees with a `## Decision register`
   heading added, first with two anchored rows against three ADR files (exit 1), then with a design.md
   whose register has three anchored rows (exit 0), and one whose register heading is present but the
   document holds no `](#` link (exit 1); (g) the hook's `docs/decisions/` case: the register of three
   anchored rows with a fourth ADR file added and no fourth row (exit 1), and the same fourth file
   against a design.md with no register heading (exit 0, the conditional guard). Because it
   reads only fixtures, it stays under the existing `validate-script-tests` hook (`.agent/` is covered)
   and satisfies the #354 guard's ROOT_READERS rule without any entry: it finds the checker with a single
   `$SCRIPT_DIR/../check_design_anchors.sh`, which the guard's root-derivation scan (`(\.\./){2,}` and
   its siblings) does not match. If it ever did derive a root, the entry to add would be
   `.agent/scripts`, which the hook covers. `test_script_tests_hook_scope.sh` is therefore not in Files
   to Change: its assertions at lines 454 and 455 and its parsed hook block stay as they are. Not done:
   an assertion that the new hook's `files:` keeps covering the eight paths (it would make the suite
   read the real config and need a ROOT_READERS entry); the CI run of `make lint` is what catches a
   dropped path.
   *Where it runs.* Locally on the commits it exists for (new hook), in `make lint` and CI (same hook),
   and its logic on any `.agent/` commit (script-tests suite). Test what breaks: renaming a section
   breaks citers silently otherwise.

### PR split

- **PR A: destinations. Done: merged as #377 on 2026-10-09 (merge commit `249a8d0`).** It landed: the
  lifecycle file's "Exit contract and dispatch" section (`.agent/knowledge/review_loop_lifecycle.md`);
  the `lock.sh` header (advisory lock, its file, nothing else reads it) and the matching Makefile help
  line for `make lock`; the `validate_workspace.py` docstring (the `project '<name>':` and
  `parent root '<name>':` failure prefixes and the unprefixed follow-up line); synthetic names in the
  examples of `_project_registry.sh`, `.agent/projects.local.example` and `.agent/WORKTREE_GUIDE.md`
  (`boat_sim`, `shore_tools`, `shore_tools-jazzy`, and the package-worktree example
  `acme/sonar_driver#111`); the Makefile help line `make build PROJECT=boat_sim`; the ADR-0016 row of
  `.agent/knowledge/principles_review_guide.md` (no real project name in the acceptance-run wording);
  and the ADR-0017 link fix. Boundary, unchanged and stated: code comments keep the real names
  (`ros2_colcon/adapter.sh` line 835 and `merge_pr.sh` line 497 cite the real checkout where a bug was
  found, #237); test sandboxes and fixtures keep their names (`tests/test_*.sh`,
  `tools/ros-manifest/tests/`); ADRs and the roadmap are history; and `tools/ros-manifest/` prose keeps
  real names too (owner decision 2026-10-09). Nothing was deleted from design.md in PR A.
- **PR B: the rewrite.** New `docs/design.md` (its last section is the glossary, whose terms the owner
  settled on 2026-10-09, **C6**, row 16), the deletions, the guide-row edit (line 71), the anchor
  checker script, its pre-commit hook in `.pre-commit-config.yaml` and its script-tests suite. Commit
  order, so that no commit fails the hook (the hook is never skipped): (1) checker, hook and suite
  (the guards are conditional on the register, so this commit passes with no design.md register);
  (2) the section commits, kept separate, each checked for resolving anchors by the hook; (3) the
  register section, after which both guards are live and the 17 rows are counted from then on; (4) the
  glossary, last in the document (its terms and one-line definitions are settled, row 16). **A section
  links only to sections already committed, and the register links last** (plan review round 5,
  accepted): a section that links forward to one not yet written would fail its own commit under the
  hook. The register's rows for ADRs with no carrying section link to `#decision-register` itself
  (Wire-in 6). No ADR file is edited in PR B (owner decision 2026-10-09, C1-c): a drifted ADR gets
  standing `superseded in practice` in the register only, and the list of those goes to the owner
  after PR B.
- **PR C: wire-in.** Skills (citing by anchor; `audit-workspace` gains its one `Re-examined` line, A4), roadmap (open items, Cross-cutting note), README pointer
  to `docs/design.md#how-it-works`. No label edits (owner decision 2026-10-09: keep "System design").
  `Closes #335`.

B and C may merge together if the owner prefers fewer reviews. Review depth is at least Standard
(governance files). Both reviews and the merge stay the owner's call (standing rule).

## Files to Change

PR A rows are done (merged as #377, `249a8d0`); the text of each row says what was planned and the PR
split says what landed.

| File | Change | PR |
|------|--------|----|
| `.agent/knowledge/review_loop_lifecycle.md` | Add exit-contract and dispatch paragraph (`--check-exit`, its four results, fresh sub-agent per phase, ADR-0014/0015) | A (done, #377) |
| `.agent/scripts/lock.sh` | Header paragraph: advisory lock, file path, who reads it | A (done, #377) |
| `.agent/scripts/validate_workspace.py` | Docstring: failure-line prefixes | A (done, #377) |
| `.agent/scripts/_project_registry.sh`, `.agent/projects.local.example`, `.agent/WORKTREE_GUIDE.md` | Synthetic project names in the examples, incl. the package-worktree example `acme/sonar_driver#111` | A (done, #377) |
| `Makefile` | Help line 80: `PROJECT=gz4d` becomes `PROJECT=boat_sim`; `make lock` help line says advisory | A (done, #377) |
| `.agent/knowledge/principles_review_guide.md` (line 51) | ADR-0016 row: drop the real project name from the acceptance-run wording | A (done, #377) |
| `docs/decisions/0017-design-document-is-the-current-picture.md` | Fix the ADR-0008 link filename | A (done, #377) |
| `docs/design.md` | Rewrite per the section table; the `Now` label on every `##` section (A1); the Rules table with its enforced-by column (A3); the `## Instruction layers` section, `proposed` (A5); no directory tree and no tree pointer; the Decision register marks standing only, no ADR file is edited (C1-c); the Registry inventory (two tables, C2) and the Worktrees records Target (C3), with the gate-lookup gap cited as #379 | B |
| `docs/design.md` (`## Glossary`, last section) | Vocabulary and standard terms, one plain line each; every term used in a situation report or checkpoint except the eight phase names; terms and definitions settled with the owner 2026-10-09 (C6, row 16); 15 entries | B |
| `.agent/knowledge/principles_review_guide.md` (line 71) | Consequences Map row "Work-plan directory convention": replace the directory-tree cell | B |
| `.agent/scripts/check_design_anchors.sh` (new, `chmod +x`) | The anchor checker: citation form, scope and register count as in Wire-in 6; grep and awk only | B |
| `.pre-commit-config.yaml` | New local hook `check-design-anchors` (files: the eight paths in Wire-in 6, `docs/decisions/` among them), placed before `validate-script-tests`. Ask First (CI-like config), approved by the owner 2026-10-09 (B4) | B |
| `.agent/scripts/tests/test_design_anchors.sh` (new, `chmod +x`) | Tests the checker with fixtures only (negative, positive, placeholder and issue-ref, uppercase citation, `#glossary` anchor, guards before and after the register exists, a new ADR file without a register row); reads no real docs | B |
| `.claude/skills/{review-issue,review-plan,plan-task}/SKILL.md` | Section wording cites the real anchors `$WS_ROOT/docs/design.md#how-it-works` and `#the-design`, plus the `#<section>` placeholder (Wire-in 2) | C |
| `.claude/skills/audit-workspace/SKILL.md` | Step 2 gains one line: refresh the Decision register's `Re-examined` cell (cited as `docs/design.md#decision-register`) when an ADR is checked against the code; the Guidelines "Report, don't fix" bullet notes that one exception (A4, owner decision 2026-10-09). No per-section dates | C |
| `docs/roadmap.md` | Open and planned items name the design section; Cross-cutting Decisions note and pointers | C |
| `README.md` | Under `## Workspace goals`, a closing pointer to `docs/design.md#how-it-works` | C |
| Not touched | `.agent/scripts/merge_pr.sh` and `test_merge_pr_gate.sh` (the gate-lookup fix is #379, its own change); `.agent/scripts/tests/test_script_tests_hook_scope.sh` (its assertions at lines 454-455 and the `validate-script-tests` hook's `files:` stay as they are), every "System design" label (`README.md` line 22, `.agent/AGENT_ONBOARDING.md` line 91, `.claude/skills/brainstorm/SKILL.md` line 34, `AGENTS.md` line 436, `CLAUDE.md` line 36; owner decision 2026-10-09: keep "System design"), `docs/principles.md` (principle wording is a separate change), accepted ADRs other than the link fix | |

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
Taken as candidates, owner decision 2026-10-09: the enforced-by column (A3), the instruction-layer
section with a budget, `proposed` (A5), and the register's Re-examined column as the checked-date
(A4). Not taken: a `Checked: <date>` on every section.
Rejected for now: a separate VISION file; a document-kind vocabulary from the fork's
planning-document proposal beyond the seven roles the owner chose; a hard line cap (owner, Q1).

## Design Picture

This plan is the change to the design picture: `docs/design.md` is rewritten whole. It also changes
which design section the planning and review skills cite (headings in the new file).

## Principles Self-Check

| Principle | Consideration |
|---|---|
| Keep one current design | The deliverable. Five status values keep decided, built, proven and proposed apart; the roadmap's stale second copy is marked history |
| Only what's needed | Admission rule, 60-line prompt, detail goes next to code; no tree pointer and no per-section dates (A4, A5); a glossary term is in only if a report or checkpoint uses it; each research candidate is owner-accepted, not added by default; no separate name list |
| A change includes its consequences | Moves confirmed before deletion; the guide's directory-tree row, skills, roadmap and README updated in the PR that makes each stale; ADR link fixed |
| Leave a trail; start limits strict | Decision register and change log with line counts; each section its own commit |
| Ask about what matters, and show how much | Design questions asked one at a time with what each changes (list below) |
| Verify before claiming | Every "Now" line cites its source and is spot-checked; revision 2 rechecked every "already lives" claim and found three wrong |
| Know whether it works | With/without test; line count in the change log; the register's `Re-examined` column is the checked-date and `/audit-workspace` refreshes it (A4); Measures role shown honestly as "none yet" |
| Put each thing at the level it applies to | Script detail to script headers; per-project mapping is project-level, the workspace's own mapping is here |
| Leave in a project only what it chose to carry | Footprint is Target, not described as built; the records settings (C3, row 8) make it a per-project choice, with the in-repo default unchanged |
| Look for prior art before building | Prior Art section above |
| Small steps; step back when they stop converging | Three PRs, one commit per section; if sections keep passing 60 lines or the owner's edits keep reshaping the table, stop and propose a simpler section set instead of patching |
| Test what breaks | The checker runs in a new pre-commit hook on the commits that can break an anchor (design.md, README, roadmap, onboarding, ADRs, knowledge files, skills, the config itself), then in `make lint` and CI; `test_design_anchors.sh` tests the checker with a negative fixture that must fail, so the check is shown to catch a broken anchor. The script-tests hook is not widened (#354). The rest of the change is documentation, covered by the with/without test and spot-checks |
| Enforce what matters, as simply as possible | The admission rule is a review check, backed by the cheapest mechanical check that fails when a name breaks (the grep-level anchor checker and its hook) and a recorded line count in place of a cap; the Rules enforced-by column (hook, script, CI, review only, nothing) shows which rules have a check at all (A3) |

## ADR Compliance

| ADR | Triggered | How addressed |
|---|---|---|
| 0017 | Yes | The plan implements it; the rewrite reconciles design and ADRs and records standing in the register |
| 0001 | Yes | No new ADR here; one is written only if the rewrite changes a decision two parts could choose incompatibly |
| 0008 | Yes | ADRs get no design pointers (register only); the one ADR edit is a link fix, which ADR-0008 permits |
| 0016 | Yes | Provisional: shown as `decided, not proven` until the acceptance run; the Registry inventory is read after that run to decide #295 (C2) |
| 0003 / 0011 | Yes | 0003 is superseded by 0011; the workspace stays project-agnostic, no project names; the Registry row cites both |
| 0005 | Yes | The anchor check follows its layers: a pre-commit hook for local feedback, the same hook in CI lint as the enforcement layer |
| 0013 | Yes | Entries via `progress_append.sh`. The records Target (C3) keeps the in-repo default path that ADR-0013 names; an outside location moves the root, not the entry vocabulary. ADR-0013 is not edited (C1-c) |

## Consequences

| If we change... | Also update... | Included in plan? |
|---|---|---|
| Design section names | Skills, README, roadmap, register column, anchor checker | Yes (checker, hook and suite PR B; skills, README and roadmap PR C) |
| Anchor checker added | `.pre-commit-config.yaml` (new hook, files: the eight paths, `docs/decisions/` included); `test_design_anchors.sh` (fixtures only); NOT `test_script_tests_hook_scope.sh` or the script-tests hook's `files:` (#354 scoping and its lines 454-455) | Yes (PR B); the hook is Ask First, approved by the owner 2026-10-09 (B4) |
| Real project names in user-visible text | Makefile help line, review guide ADR-0016 row | Yes (PR A, landed #377); code comments, test fixtures and `tools/ros-manifest/` prose keep names |
| A new ADR file | Its Decision register row (a missing row fails guard (b) in the hook, once the register exists); an ADR with no carrying section links to `#decision-register` | Yes (PR B) |
| Process terms used in situation reports or checkpoints | The `## Glossary` section (the eight phase names are not entries; they are described in "Review loop and timeline") | Yes (PR B; terms settled with the owner 2026-10-09, C6) |
| A drifted ADR found while writing a section | Register standing `superseded in practice` plus one line on what the code does instead; no ADR file edited in PR B; the owner gets the list after PR B and decides each supersession on its own | Yes (PR B, register only; supersession afterwards, C1-c) |
| Directory tree removed | Review guide Consequences Map row "Work-plan directory convention" | Yes (PR B) |
| Detail removed from design.md | Its destination file | Yes (PR A, landed #377, verified first) |
| Registry or adapter text | `adapter` and registry headers | Yes (verified; no gap found) |
| Lock text removed | `lock.sh` header (nothing else documents it) | Yes (PR A, landed #377) |
| Roadmap Cross-cutting Decisions | The design sections that now hold the facts | Yes (PR C; B2 open) |
| Registry inventory in `docs/design.md` | Re-grep the `--type` branches when the Registry commit is written; cut the inventory back once #295 is decided | Yes (PR B writes it; the cut-back follows the #295 decision) |
| Where records live (C3 Target) | Every reader and writer of `.agent/work-plans/issue-N/`: `dispatch_phase.sh`, `merge_pr.sh`, `review_progress.sh`, `progress_append.sh`, `_bookkeeping.sh`, `cross_model_review.sh`, and the seven skills that cite the path | No. A later build; PR B writes only the Target text, status `proposed` |
| Roadmap rows that change the design picture | A "design section:" note on those rows only; the other open rows stay as they are | Yes (PR C) |
| `AGENTS.md` (the instruction budget proposed in `## Instruction layers`) | Framework adapters | No, Ask First |
| Status key (`Now` label on every `##` section, A1) | The opening paragraph of `# The design`; each section's block; the skills that cite `#the-design` for the key | Yes (PR B writes the key and the blocks; PR C's skill wording cites the anchor) |
| A rule's check added or removed | Its row in the Rules enforced-by column (A3) | Yes (PR B writes the column; later upkeep is the change that adds or removes the check, per "A change includes its consequences") |
| `/audit-workspace` step 2 (A4) | `.claude/skills/audit-workspace/SKILL.md` (one line, plus the Guidelines exception); the register's `Re-examined` cells | Yes (PR C) |
| The merge gate's timeline lookup (#379) | `merge_pr.sh` line 670, `test_merge_pr_gate.sh`; the Worktrees Now sentence that cites the gap in `docs/design.md` | No. #379 is its own change; the change that fixes it edits the design sentence in the same change (ADR-0017). The roadmap needs no row (Wire-in 4) |

## Open Questions

Grouped by what they change. Stable IDs; ask in group order, each design question on its own.

**Still open (4): B1 and B2 (wire-in; B1 needs an answer before PR C, B2 before PR C marks the
roadmap section) and C4 and C5 (content that stays open in the document).** Every other question is
decided, below. As of revision 9 the A group (A1 to A5) is decided; the Q1, B4, Purpose and anchors,
Label, C1 to C3 and C6 entries are older decisions.

**Decided**
- **Q1 (decided 2026-10-08).** Status marking yes with five values; Now block with sources, Target
  only where it differs; "Proposed:" and "(candidate)" markers; no hard line cap; admission rule
  plus a 60-line prompt plus line count in the change log; no length guide for How it works.
- **B4 (decided 2026-10-09).** The `check-design-anchors` pre-commit hook is approved (owner: "Yes, and
  watch the ADR directory too."), with `docs/decisions/` in its `files:` (Wire-in 6).
- **Purpose section and anchors (decided 2026-10-09).** The `## Purpose` row and the skills' anchors
  `#how-it-works` and `#the-design` are accepted (owner: "Accept both.").
- **Label (decided 2026-10-09).** "System design" stays everywhere; no label edits in this plan.
- **A1 (decided 2026-10-09, owner decision: "Go for group A").** Every `##` section carries the label
  `Now`, also when it has no Target. The Status key says so. `# How it works` and the opening paragraph
  of `# The design` carry no label (the first is the owner's prose, A2; the second holds the key).
- **A2 (decided 2026-10-09, owner decision).** The admission rule is the opening paragraph of
  `# The design`. `# How it works`, the owner's prose, stays first and unencumbered. The plan's text
  already said this; it is marked decided.
- **A3 (decided 2026-10-09, owner decision).** The Rules table gets the enforced-by column with the
  values hook, script, CI, review only, nothing. The "review only" and "nothing" rows are in from the
  start; row 5's clause that waited on A3 is gone.
- **A4 (decided 2026-10-09, owner decision: yes, register rows only).** No `Checked: <date>` per
  section. The register's `Re-examined: yes <date>` column is the checked-date, and PR C adds one line
  to `/audit-workspace` step 2 to refresh it when an ADR is checked against the code. The skill file is
  in Files to Change (PR C). One wrinkle for PR C, found by reading the skill: its Guidelines say
  "Report, don't fix", so the line is worded as the one exception (a register cell only) and the
  bullet says so (Wire-in 2).
- **A5 (decided 2026-10-09, owner decision: keep the section, drop the tree line).** `## Instruction
  layers` is a real section (row 12), `Now` block status `proposed`, with the four layers and a budget
  for the always-loaded layer; sources in row 12. The one-line directory-tree pointer in How it works
  is dropped: the tree leaves the document, and a pointer would only point at the repo.
- **C1 (decided 2026-10-09, owner decision C1-c).** Register only in PR B. A drifted ADR gets standing
  `superseded in practice` with one line saying what the code does instead; no ADR file is edited in
  PR B. ADR supersession happens afterwards, one ADR at a time, each the owner's call. ADR-0016 stays
  Provisional. The `superseded in practice` rows are listed for the owner after PR B (row 13).
- **C6 (decided 2026-10-09, owner decision).** The eight phase names are not glossary entries; they
  are the workflow, described in order in "Review loop and timeline" (row 9). The glossary holds the
  vocabulary used about the loop plus the standard terms, with the owner's one-line definitions: the
  settled list of 15 is in row 16. WIP limit and appetite are left out on purpose, because the
  workspace has neither.
- **C2 (decided 2026-10-09, owner decision C2-c plus an inventory).** The workspace as a registered
  project (#295) stays `open`, a pointer to #295 only. The Registry section's Now block gains an
  inventory of the places where the workspace path differs from the registered-project path, and a
  per-verb classification of the 12 adapter verbs; #295 is decided by reading it after the ADR-0016
  acceptance run (#317), not by a hunch. Owner's reasoning: sorting project functionality from
  workspace-only functionality is a worthy goal; #295 is one route; the inventory is the cheaper
  probe. Seeded under "Registry inventory".
- **C3 (decided 2026-10-09, owner decision).** An issue's work plan and progress timeline are
  committed in the project repo on the issue's feature branch under `.agent/work-plans/issue-N/`
  (`decided`). Target (`proposed`): `location` and `tracking`, two per-project settings in the registry
  entry with derived defaults; three mechanisms (one lookup, the gate reading across repos, untracked
  means per machine and per clone); one rule (the registry setting names the source of truth). The
  design text gives no `agent_workspace` example. A colleague's single-repo project is the acceptance
  test. Row 8 and "Records: where they live and whether they are tracked". The gate's lookup gap in
  the project case is tracked as #379 and does not wait for this.

**B. Wire-in**
- **B1.** Should accepted ADRs carry a pointer to their design section (issue scope item 3)? Needs a
  scope note on ADR-0008 (or a superseding ADR). Default in this plan: no. Hard to undo once ADRs are edited.
- **B2.** Roadmap Cross-cutting Decisions: mark as history (this plan), delete, or leave. Marking is easy to reverse.

**C. Content that stays open in the document** (C1, C2, C3 and C6 moved to Decided)
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
- Widen the checker's scope to `AGENTS.md`, `CLAUDE.md` and `docs/principles.md` (none cites a design
  anchor today; the hook's `files:` already watches `docs/decisions/`, owner decision 2026-10-09).

Dropped: the former Q14 (mention session-clearing advice at all), per the standing rule against proposing it.

## Estimated Scope

Three PRs (A: destinations, **done**, merged as #377; B: the rewrite, the anchor checker with its hook and suite; C: wire-in), B and C merge-able as one. The
writing is paced by the owner's edits (process step 2 first), not by drafting. Register sizing: 17 rows
written in PR B; nine of them (0002, 0003, 0011, 0012, 0013, 0014, 0015, 0016, 0017) are checked against
the code each describes, one short read per ADR done in the commit of the section that cites it; the
other eight are `not yet`. PR A was small (one script header, one docstring, one lifecycle section, name
swaps in three files plus the Makefile help lines and one guide row) and is merged. PR B gains one small
script (grep and awk), one hook entry and one fixture suite, and the glossary (15 entries, settled by
the owner, C6, row 16). The Registry inventory (C2) is one grep pass over the `--type` and workspace
branches, written as a table of 8 rows plus a 12-row verb table (seeded in this revision, re-verified in
the Registry commit). The records Target (C3) is about 30 lines of Target text in Worktrees and no code. Revision 9 adds
no code: the `Now` label on each section, the enforced-by column (one value per rule row), the
Instruction layers section (about 15 lines, all `proposed`) and, in PR C, one line in
`/audit-workspace` step 2 with a matching exception in its Guidelines. The tree pointer and
per-section dates are gone.

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

## Revision 5 change log

Answers plan review round 4 (entry `ffa20fe`): item 1 is its must-fix (finding 1), items 2 to 4 its
suggestions (findings 2 to 4, all applied). The plan is 530 lines.

| Item | What changed |
|---|---|
| 1 | Commit order no longer fails the checker. The two anti-vacuity guards (no in-file links; fewer anchored rows than ADR files) apply only once a heading with slug `decision-register` exists; before it the checker only checks that cited anchors resolve. PR split states the order: (1) checker, hook and suite, (2) section commits, (3) register section, guards live. The hook is never skipped. Fixtures (e) and (f) cover both states |
| 2 | Register rows defined: lines beginning `|` between the register heading and the next heading of the same or higher level that contain `](#`, counted against `ls docs/decisions/*.md` (17) |
| 3 | A `design.md#` fragment (run of `[A-Za-z0-9_-]`) that does not match `[a-z0-9][a-z0-9-]*` is a malformed-anchor error; an empty run (the `#<section>` placeholder) is still ignored. Fixture (d) covers `#How-it-works` |
| 4 | Follow-up list gains one line: widen the checker scope to `AGENTS.md`, `CLAUDE.md`, `docs/principles.md`, `docs/decisions/` |

## Revision 6 change log

Applies the owner's four decisions of 2026-10-09 (no review round in between). The plan is 554 lines.
The rewrite's line count is still logged from the first section commit.

| Item | What changed |
|---|---|
| 1 | Hook approved, ADR directory watched (owner decision 2026-10-09: "Yes, and watch the ADR directory too."). B4 moved to Decided. `docs/decisions/` added to the `check-design-anchors` `files:` pattern (eight paths now), so a new ADR file without a register row fails guard (b) at commit time once the register exists. Suite gains fixture (g); the "caught only by lint/CI" sentence is gone; the follow-up scope clause keeps `AGENTS.md`, `CLAUDE.md`, `docs/principles.md` only. Files to Change, Consequences and process step 1 updated |
| 2 | "System design" label kept everywhere (owner decision 2026-10-09). Wire-in 7, the README line 22, `AGENT_ONBOARDING.md` line 91 and `brainstorm` line 34 label edits, the label Consequences row (and the README-label row that depended on it), the follow-up label line and the "plan approval covers the onboarding edit" sentences are removed. README keeps its `## Workspace goals` pointer to `docs/design.md#how-it-works` |
| 3 | `## Purpose` row and the `#how-it-works` / `#the-design` skill anchors accepted (owner decision 2026-10-09: "Accept both."); marked decided in the Issue section, row 3, Wire-in 2 and the Decided list |
| 4 | New last section `## Glossary` (row 16): process terms, one plain line each, rule "every term in a situation report or checkpoint is in it", no length guide beyond that rule. New question C6 (which terms go in), settled with the owner before PR B writes it, with the owner's candidate list as the start. Added to the PR split (PR B, commit 4), Files to Change, Consequences, process step 3 and the anchor-test scope (`#glossary`, fixture (b)) |

## Revision 7 change log

Applies the owner's decisions of 2026-10-09 on C1 and C6, records PR A as merged, and folds in the two
accepted round-5 suggestions (entry `65fb3c4`). It does not reopen the plan approved at revision 6. The
plan is 595 lines. The rewrite's line count is still logged from the first section commit.

| Item | What changed |
|---|---|
| 1 | PR A is merged (#377, `249a8d0`, 2026-10-09). PR split, Files to Change (PR column) and Estimated Scope mark it done and say what it landed: the lifecycle "Exit contract and dispatch" section, the `lock.sh` header, the `validate_workspace.py` docstring, synthetic names in `_project_registry.sh`, `projects.local.example` and `WORKTREE_GUIDE.md` (incl. the `acme/sonar_driver#111` example), the Makefile help lines, the guide's ADR-0016 row and the ADR-0017 link fix. `tools/ros-manifest/` prose keeps real names (owner decision 2026-10-09), added to the stated boundary. The three "PR A adds ..." cells of "What leaves design.md" now read "landed in PR A (#377)" |
| 2 | C1 decided (owner, C1-c): register only in PR B. Drifted ADR = standing `superseded in practice` plus one line on what the code does; no ADR file edited in PR B; supersession afterwards, one ADR at a time, the owner's call; ADR-0016 stays Provisional. C1 moved to Decided; row 13 states the standing values and that `superseded in practice` rows become candidates listed after PR B; Consequences row added; PR B commit order restates it |
| 3 | C6 decided: the eight phase names are not glossary entries (workflow, described in order in "Review loop and timeline"; row 9 now says it names the eight phases in order with what each produces and who decides). Row 16 holds the settled list of 15 with the owner's one-line definitions (7 own terms, 8 standard terms), the reworded admission rule (phase names excepted) and the left-out terms WIP limit and appetite (the workspace has neither; grep of `docs/`, `.agent/knowledge/`, `AGENTS.md` and the skills finds no use). C6 moved to Decided; process step 3, PR B text, Files to Change, Consequences and Estimated Scope follow. Checked: issue #345 exists (plugin spike); the interop spike has no issue, only the 2026-09-24 notes, so no number is cited for it; `MAX_ROUNDS` exists (`review_loop_lifecycle.md` lines 66 and 122), so "the nearest is the review-round limit" holds |
| 4 | Round-5 suggestion (a): register rows for ADRs with no carrying section (0001, 0006, 0007, 0009, 0010) link to `#decision-register`; stated in Wire-in 6 and row 13 |
| 5 | Round-5 suggestion (b): PR B commit order says a section links only to sections already committed and the register links last |

## Revision 8 change log

Applies the owner's decisions of 2026-10-09 on C2 and C3 (no review round in between). It does not
reopen the plan approved at revision 6. The plan is 744 lines. The rewrite's line count is still
logged from the first section commit.

| Item | What changed |
|---|---|
| 1 | C2 decided (owner decision 2026-10-09, C2-c plus an inventory): the workspace as a registered project stays `open`, a pointer to #295 only (row 6 unchanged). Row 7 gains the inventory in its Now block; the new subsection "Registry inventory" seeds it from one grep pass: a table of 8 script rows (`worktree_create.sh`, `worktree_enter.sh` and `worktree_remove.sh`, `merge_pr.sh`, `dispatch_phase.sh`, `gh_create_pr.sh`, `worktree_list.sh`, `_project_registry.sh`, the `run-issue` skill with `agent start-task`) and a 12-row verb table (3 no-op, 5 thin wrapper, 4 real). Purpose stated: #295 is decided by reading it after the ADR-0016 acceptance run (#317). "What leaves design.md" gains a "what stays in Registry and adapters" paragraph; Estimated Scope sizes it; Consequences, Files to Change and the ADR-0016 row follow. C2 moved to Decided |
| 2 | C3 decided (owner decision 2026-10-09). It lands in row 8 (Worktrees), not a new row, so no renumbering and no new anchor (reason in the subsection "Records: where they live and whether they are tracked"). Now, `decided`: records are committed in the project repo on the issue's feature branch under `.agent/work-plans/issue-N/`, with the `merge_pr.sh` project-case gap (lines 670, 916) shown. Target, `proposed`: settings `location` and `tracking` in the registry entry with derived defaults, the four combinations, three mechanisms (one lookup, the gate reading across repos, untracked means per machine and per clone), one rule (the registry setting names the source of truth), no `agent_workspace` example, a colleague's single-repo project (by shape only) as acceptance test. Row 9's Target candidate points at mechanism 1; Consequences, Self-Check and the ADR-0013 row follow. C3 moved to Decided; C4 and C5 are the only open C questions |

## Revision 9 change log

Applies the owner's A-group decisions of 2026-10-09 ("Go for group A": the host's recommendations
accepted as stated) and cites issue #379 (opened 2026-10-09). No review round in between. It does not
reopen the plan approved at revision 6. The plan is 818 lines. The rewrite's line count is still
logged from the first section commit.

| Item | What changed |
|---|---|
| 1 | A1 decided: every `##` section carries the label `Now`, also with no Target. The Status key says so; `# How it works` and the opening paragraph of `# The design` carry none (the first is the owner's prose, the second holds the key); the key's "nothing proposed in Now" rule now names its one exception, row 12 |
| 2 | A2 decided: the admission rule is the opening paragraph of `# The design`; `# How it works` stays first and unencumbered. The plan already said this; the "judgement call" sentence that pointed at A2 is replaced by the decision |
| 3 | A3 decided: row 5's Rules table has the enforced-by column with five values (hook, script, CI, review only, nothing); the clause waiting on A3 is gone and the review-only and nothing rows are in from the start |
| 4 | A4 decided, register rows only: no `Checked: <date>` per section; the register's `Re-examined` column is the checked-date; `/audit-workspace` step 2 gains one line in PR C (skill read: step 2 has no register or date wording today). Skill file added to Files to Change (PR C) with the Guidelines exception ("Report, don't fix" bullet), Wire-in 2, Consequences and Self-Check. The candidate paragraph under the section table is replaced by the decision |
| 5 | A5 decided: row 12 is a real section, `## Instruction layers`, Now `proposed`, sources named (`AGENTS.md` is 442 lines, counted this revision; the Claude Code docs' under-200-lines target as the prior-art note records it). The one-line tree pointer in row 1 is dropped. The new heading is an anchor like any other (Wire-in 6) |
| 6 | #379 cited: row 8's Now text, the "Records" Now paragraph, mechanisms 1 and 2, and the `merge_pr.sh` row of the Registry inventory name it as the tracker of the gate lookup at `merge_pr.sh` line 670 and say its one-line fix does not wait for the records resolver. Wire-in 4 says why the roadmap gets no row for it (it adds, removes or re-shapes no part named in a design.md section; grep finds no #379 in the roadmap). `merge_pr.sh` and its gate test are listed under "Not touched" |
| 7 | Open Questions: A1 to A5 moved to Decided; the A group heading is gone; a "Still open (4)" line at the top lists B1, B2, C4 and C5. Prior Art, Self-Check (three rows), Consequences (four new rows and the `AGENTS.md` row reworded), Files to Change (design.md and audit-workspace rows, one Not touched entry), PR split (PR C) and Estimated Scope follow |
