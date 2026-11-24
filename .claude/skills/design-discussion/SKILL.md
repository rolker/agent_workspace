---
name: design-discussion
description: A two-way conversation that works out the goals, design and roadmap of one level (the workspace, a project, or a part of either). Revises a level that has them, or carves a part out as a sub-design of its parent. Finds blind spots on both sides, and saves every decision, open question and reason in tracked documents and the discussion's issue, so later sessions resume from them. Never implements.
session_scope: both
---

# Design discussion

> **Trial version.** Part 1 of the workspace issue that introduced it (#370): the Revise
> and Carve uses. It stays a trial until two uses are recorded, one Revise and one Carve.
> The outcome of those uses, and whether to settle, revise or remove the skill, goes in a
> comment on rolker/agent_workspace#370 (the full name: a project session's `gh` reads a
> bare number as the project's issue). Revisit when both uses are done, or on 2026-12-31 if they are not,
> whichever comes first; at that point the skill is revised or removed, not left as a
> trial. That date judges Part 1 only. Create (a level with no goals, design or roadmap)
> comes in Part 2, which waited on #551 (where a project keeps its goals, design and
> roadmap: now its `goals`, `design` and `roadmap` settings, Step 0); its own trial use
> keeps the trial open for that use. A rule marked *untested*
> came from no observed failure and is here for the trial to test. A rule with a *Why*
> came from a failure seen in a real session (the dated comments on #370); it can go when
> its reason does.

## Usage

```
/design-discussion <topic>
```

Use it when the user wants to work out or challenge the goals, design or roadmap of the
workspace, a project, or a part of one; asks whether something is a good idea; or wants
to split a sub-component or a new feature off as a part with its own design. Reach for
it before the first implementation issue of a new design, not only when doubts appear.

**Before this** (optional): `/research` on the topic, then `/brainstorm` for options;
Step 1 reads what they left. Both are available in a project session too.

It is a conversation, and its product is the level's tracked documents. A discussion
bigger than one session loses its details unless they are saved where every later
session reads them, until the work is done. So everything decided, everything still open
and the reason for each decision is offered for a tracked place during the session, and
written there on the user's yes (Step 7). The scratchpad holds in-session notes only: it is one
machine, untracked, and a fresh session does not see it, so it is never the home of a
decision. The skill writes no code and no work plan.

Run the conversation on the strongest model available. Send research and measurements to
cheaper agents.

Workspace scripts are written `$WS_ROOT/.agent/scripts/...`. Resolve `$WS_ROOT` at the
head of each command chain (shell state does not persist between tool calls):

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
```

`~/.claude/agent-workspace-root` is written by the user-tier install and names the
workspace's main checkout; without it the fallback is the cwd, right in a workspace
session.

## Steps

### 0. Level, use, anchor and documents

- **Level.** Ask which level the discussion is about: the workspace, a project, or a part
  of either (ADR-0022). For a part, read its parent's goals first. *Why: the same failures
  showed up on a workspace redesign and a project redesign; the level and its parent's
  goals were never named up front (#370, 2026-10-12).*
- **The level's own session.** `gh`, `sitrep_root.sh` and the worktree route all act on
  the session's root (the cwd). Discuss a level in a session started at its root: a
  project's level from a workspace session, or the reverse, writes to the wrong
  repository. If the level belongs to another root, say so and stop before any tracked
  write.
- **Use.**
  - **Revise**: the level has goals, design and roadmap; challenge and revise them.
  - **Carve**: split a sub-component or a new feature off as a part, with its own goals,
    design and roadmap, as a sub-design of the parent (the Carve section below).
  - **Create** (a level with none of the three) is not available yet; it comes in
    Part 2. Say so. The conversation still runs, and what it produces is recorded on the
    anchor issue (Step 7, "No document").
- **Anchor issue.** At the start, ask whether the discussion already has an issue: a
  resumed discussion is read from it (Step 1). If it has none, offer to open one before
  the first tracked write (Issue-First Policy); open it only on a yes. Every session
  writes to that issue and resumes from it. Drafts go on that issue's branch, in a
  worktree made by the root's own route for issues.
- **No anchor issue, no record.** If the user declines the anchor issue, say plainly
  that nothing from this session can be saved for later sessions: every record path in
  Step 7 (drafts, reasons, the state comment) needs it. The conversation may still run,
  but stop before any tracked write (no worktree, commit, comment or file), as for a
  project that uses no issues (below). Offer the anchor issue again before the session
  ends.
- **A project that uses no issues is not supported yet.** Whether it uses them is the
  `issues` fact of `"$WS_ROOT/.agent/scripts/project_integration_audit.sh" --facts
  --format text`, run in the project's root; ask the user when it is `unknown`. The
  audit's `no` covers more than one case. Read its `github` fact from the same output
  first:
  - `github` is `no` or `unknown` (no GitHub repository of the root's own, for example
    a root that is not the top of a git repository, or one gh could not read): say so
    plainly and stop before any tracked write: no worktree, commit, comment or file.
    Never ask `gh` from the root here: `gh` walks up from a folder, so a root nested
    in another git repository would resolve that enclosing repository.
  - `github` is `yes`: its evidence names the repository (`gh repo view resolves the
    repository to github.com/<owner/repo>`). Show that `<owner/repo>` to the user and
    query it explicitly, `gh repo view github.com/<owner/repo> --json hasIssuesEnabled --jq
    .hasIssuesEnabled` (the field the audit itself reads), passing `-R github.com/<owner/repo>`
    on every later `gh` call for this project too:
    - `false`, or the call fails (issues disabled, or cannot be read): say so
      plainly and stop before any tracked write: no worktree, commit, comment or file.
    - `true` (issues enabled, but none was ever opened, which the audit counts as not
      using them): explain that to the user, since the discussion is saved on an anchor
      issue and the project has none yet, and ask whether to open the project's first
      issue as the anchor. On a yes, open it as the anchor issue (above), with its title
      and body shown in full and checked against the project's `.agents/README.md` rules
      first, and the body written and signed as Step 7 says (identity in the same chain,
      `--body-file`). Write the body with a quoted heredoc and pass the title without
      shell expansion, never typed inside double quotes, so no backtick span, `$` or
      `$(...)` in either is run or expanded: the chain in `brainstorm` Step 4 item 2,
      with `-R github.com/<owner/repo>`. Report the issue's URL only when that chain exits 0. The
      session then proceeds as for any anchored discussion. On a no, say
      plainly that nothing can be saved and stop before any tracked write, as above.

  Where no anchor can be had, the skill has nothing to
  write to or resume from, and no worktree route that needs no issue. The
  modular-workflow issue (#544: GitHub-optional backends, files as work items, work keyed
  by branch) and the records-lookup issue (#393: where a project's records live) are
  where that support comes from.
- **Documents.** Find the level's documents where every reader finds them. Where one is
  missing, say so and ask; never guess a location.
  - **A project's root:** its goals, design and roadmap are where the project's settings
    say. `"$WS_ROOT/.agent/scripts/session_root.sh"` prints the project's name as
    `project=`; ask the one lookup every reader uses, once per document:

    ```bash
    WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
    "$WS_ROOT/.agent/scripts/project_setting.sh" doc <project> goals
    "$WS_ROOT/.agent/scripts/project_setting.sh" doc <project> design
    "$WS_ROOT/.agent/scripts/project_setting.sh" doc <project> roadmap
    ```

    - `set <path>[#<heading>]`: the project's recorded answer. Use it without asking.
    - `none`: the project keeps no such document, by its own answer. Look nowhere else;
      Step 7's "No document" applies to it.
    - `fallback <path>`: not recorded; a fixed list of names (roadmap: `docs/roadmap.md`,
      `docs/ROADMAP.md`, `ROADMAP.md`; design: `docs/design.md`) found `<path>`. It is a
      suggestion: ask whether it is the project's roadmap (or design) before relying on
      it.
    - nothing, with the reason on stderr: not recorded and nothing found (exit 1; goals
      has no fixed list, so unrecorded goals always land here), a recorded file that is
      missing (exit 1), or a recorded value the lookup refuses (exit 2). Say so, with the
      reason. For goals, offer the goals the project's own design or README names; else
      ask where they are.
    - nothing, exit 2 with the reason `the registry <file> has errors`: the registry
      itself is broken, not this setting. Nothing, exit 3: no project is registered under
      that name. Neither is about the document: show the message, offer to record
      nothing, and have the registry (from a workspace session) or the name fixed first.

    When the user names or confirms a place that is not recorded, offer to record it,
    `"$WS_ROOT/.agent/scripts/project_setting.sh" set <project> '<key>=<value>'` (the
    value `<path>`, `<path>#<heading>` or `none` when the project keeps no such document,
    quoted as one argument in single quotes, since a `` ` `` or `$` in a heading would
    run in double quotes; a `'` in it is written `'\''`), as a write on its own yes. Then run `doc` for that key
    again: exit 0 is recorded; exit 1 means the file it names is not written yet (say
    so); exit 2 means the lookup refuses what `set` took (a roadmap that is a symbolic
    link or reached through one): show the reason, and offer to remove the key
    (`project_setting.sh unset <project> <key>`) or name another file, each its own yes.
    That settings file lives in the workspace checkout, per machine and untracked;
    it is the one thing a project session writes outside its root. `set` refuses a value
    a reader cannot follow and says why (the limits are listed in `onboard-project`
    step 3c: inside the project, only ASCII letters, digits, `.`, `_`, `-` and `/` in
    the path, and a roadmap that is a whole Markdown file, not the README, an agent
    instruction file or the design): show the refusal as printed, as a limit of the
    workspace's readers, never as a fault of the project, and never suggest moving the
    project's files to fit. When it cannot be recorded, or the user declines, record the
    answer on the anchor issue instead, so later sessions find it.
  - **The workspace:** it is not a registered project and has no settings.
    `"$WS_ROOT/.agent/scripts/sitrep_root.sh"` reports its roadmap as `roadmap=` and its
    design as `design=` (the fixed lists above); its goals are
    `README.md#workspace-goals`.
  - **A part:** its roadmap is the sub-roadmap file its parent's `| Sub-roadmap | Root |`
    row names (a part has no settings of its own; ADR-0022). Its design is the
    `design.md` in the same directory as its sub-roadmap file (`check_design_anchors.sh`
    reads "the design.md beside it"); the row's `Root` cell is only the directory the
    sub-roadmap's check paths resolve against, not where the design is. Cite a part's
    design section as `<path>/design.md#<section>`, `<path>` being the design file's
    directory. Its goals are the goals section of its `design.md`.

### 1. Prepare quietly

- **On resuming** (the user comes back to a discussion, or the anchor issue shows earlier
  sessions), read in this order: the anchor issue's latest state comment (Step 7,
  "Undecided state") and its other comments, which hold the reasons (Step 7, "The why");
  the level's design; the roadmap's
  Direction lines; the branch or draft PR holding the drafts; open issues that cite them.
  The first output is the one-liner of the overall task, then progress against the
  roadmap's lines (which are true, which is next), then only the context needed for the
  detail being resumed. *Why: a resumed session went straight into the detail, and the
  user had to ask for the context; another resumed without the status and produced it
  only when asked (#370, 2026-10-05).*
- **Revise:** read the design and its history, and measure what exists: how much data,
  how much code, who uses it, how much effort has gone in. List everywhere the design's
  decisions and evidence live: the main document, its decision record or change log,
  unmerged branches, issue comments, deferrals, and working directories outside git.
  *Why: a conclusion that parked a branch also parked design corrections that existed
  only on that branch, and the evidence for the decided sections sat in an untracked
  directory.* Say whether earlier attempts at the design exist; the discussion leans on
  them (#370, 2026-10-02).
- **Carve:** read the parent's design and roadmap, and what the project already has that
  partly does the part's job.
- **Earlier preparation**, when it exists: the level's research digest (the workspace's
  `$WS_ROOT/.agent/knowledge/research_digest.md`; a project's
  `.agents/workspace-context/research_digest.md` in the project repository, if it exists) and any
  brainstorm results saved on the anchor issue: `/brainstorm` saves them, on the user's
  yes, as a signed comment whose body opens with the line `## Brainstorm: <topic>`, so
  find them by that heading among the issue's comments. Say what you read, or that there
  was none.
- Write down the decisions and assumptions you can see, including your own assumptions
  about what the user wants, as in-session notes. Step 5 checks them against the user's
  answers.
- Look facts up yourself. Ask the user only what they alone know. A statement about what
  the system does today comes from the code or the records, not memory. *Why: such
  statements made from memory were wrong twice (#370, 2026-10-02 and 2026-10-12).*

### 2. Purpose before critique

Ask why the work was started, what must be true when it is done, who it is for, and what
the session is for: to clarify, to test, or to decide between continuing, pruning and
shelving.

Give no verdict before these are answered. *Why: an agent judged a design before it knew
why the work had been started; the real reason came out four rounds in.*

### 3. Attack

- A few objections, ranked, each with evidence and each tied to a goal the user stated.
- Before showing an objection, write the strongest one-line reply to it and ask what
  happens if it is ignored. Drop the ones that lose. *Why: objections were oversold and
  only corrected when the user asked what would be lost.*
- Research alternatives. Say plainly where the research does not support them.

### 4. Defend

- **Revise:** say what would be lost by changing course. Then go through the design's
  own decision list, item by item, and mark each one *kept*, *waits*, *changed* or
  *dropped*. *Why: "what do we lose" answered in features hid decisions that were quietly
  reversed.*
- **Carve:** make the case for keeping it inside the parent's design, and the case for the
  smallest part.
- Correct anything you oversold in step 3.

### 5. Rounds

- Take a position on each answer and say what would change it.
- After the user answers, say which of your written assumptions broke and whether your
  position moved.
- List your own assumptions and invite the user to attack them. The user can say
  "attack this", "defend this" or "switch sides" at any time.
- **Sort by level.** Sort what the user says, and each finding, by level before showing
  it: goal, principle, design, or detail. Check each sentence of draft goal text for its
  level; text that says how rather than what moves to the design, it is not lost. *Why:
  review findings were shown as "missing goals" when they were details, and the user cut
  draft goal bullets twice for saying how (#370, 2026-10-02).*
- **One item per turn** when settling text: the current and the proposed text side by
  side, starting from the user's words and making the smallest edit. *Why: the user
  refused a batch edit so he could add context to each item (#370, 2026-10-02).*
- **"Let's keep thinking" is a mode.** When the user says it, stop offering text to
  accept: say what the history shows, where you would push back, and ask a few
  independent questions. *Why: the goal sentence that stuck came from the user, not
  from a draft (#370, 2026-10-02).*
- Questions. *Why: a first reply was a long report with seven questions.*
  - usually two to five in a turn; more than five means you have not chosen;
  - no question may depend on the answer to another one in the same turn;
  - keep to the recent part of the conversation; going back to an open item is fine if
    you say that is what you are doing;
  - no recommended answers on questions about purpose.
- Park a detail only when it does not block work at the level the discussion is at and
  can be solved later without significant redesign. Say both when parking it, and
  record it (Step 7). *Why: once this rule was stated, details settled or parked in one
  or two exchanges instead of several rounds (#370, 2026-10-05).*
- Every few rounds, show a short list of what is still open. *(untested)*
- Before a conclusion counts, ask the user to state it in their own words. *Why: short
  assent ("sounds good") to the agent's framing accepted structures that were never
  stated as decisions.* Record an idea only offered as offered, not settled. *Why: an
  offered idea was recorded as settled (#370, 2026-10-12).*
- Use the user's words. Give each thing a plain name the first time and keep to it.
  Define a term before leaning on it. Never use an issue or PR number as a name. *Why:
  the agent used names the user did not recognise, and numbers as names.*

### 6. Land

- Any of these is a valid ending: continue, prune, shelve, or clearer but undecided.
  Every ending offers to record what it settled and what is open (Step 7).
- **Revise**, before the landing counts:
  - show the step 4 list with the *changed* and *dropped* items first;
  - check every new term in the conclusion against the existing decisions;
  - if the design says how it may be changed, follow that, or say plainly that the
    landing sets it aside;
  - name any settled work the conclusion strands, and where it is;
  - **upward check:** compare the draft with the history (issues, branches, deferrals)
    and say what the history contradicts or the draft leaves out, each finding sorted by
    level, its evidence labelled *counted*, *sampled* or *judged*. A judged finding alone
    does not change a goal. *Why: the upward check found a gap and statements the
    history contradicted that the downward pass could not (#370, 2026-10-02).*
    *(untested in this skill)*

  "The existing design still stands" is not a landing statement on its own. *Why: a
  landing that said so left settled items unnamed, changed others without saying, and
  suspended a decision the design's own change rule protected.*
- **Carve:** run the landing check in the Carve section, once its writes are committed on
  the user's yes (Step 7); a broken pointer blocks calling the carve landed. If the user
  declines a write the check needs, the carve is not landed; say so and record it as
  open.
- Say where the conversation ended up, the one assumption the conclusion rests on, the
  cheapest test of that assumption, and what is still open.
- If the conclusion follows your own framing, say so.

### 7. Record

Everything decided, everything open and every reason is offered for a tracked place
before the session ends. One rule covers every tracked write (a commit, a push, a draft
PR, an issue, a comment): it is shown first and made only on the user's yes to that
item. A no makes no write: the item stays open, and the next state comment offered
lists it among the open questions. Never start building.

- **Identity first.** Before the first commit or comment, set the agent identity in the
  same command chain as the write (shell state does not persist between tool calls), in
  the worktree the drafts go in:
  `cd <worktree> && source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" --agent <framework> "<model id>" && …`.
  A write made before any worktree exists (opening the anchor issue, a comment on a
  path with no drafts yet) sources it in the root's own checkout instead, the session's
  starting directory: `cd <root> && source … && …`.
  It sets the commit identity and `AGENT_NAME` and `AGENT_MODEL`, which the signature
  below needs.
- **Every comment is signed.** Each comment the skill posts (a reason, the undecided
  state, drafts with no document), and each issue body it opens, is written to a file in
  the session's scratchpad and posted with `gh issue comment <N> --body-file <file>` (or
  `gh issue create --body-file <file>`), never `--body`; the file is
  removed afterwards. The body ends with the AI signature, the variables expanded to
  their values:

  ```markdown
  ---
  **Authored-By**: `$AGENT_NAME`
  **Model**: `$AGENT_MODEL`
  ```
- **Drafts live in the documents from the first session.** The first time the user says
  something is decided, propose the target document and section. On the user's yes, put
  the draft into that document on the anchor issue's branch and commit it. Each later
  decision is a tracked edit on a yes of its own, one at a time. No decision waits in
  scratch. *Why: settled text lived only in scratch notes for days, and a deferral said
  in conversation and kept in a scratch file was later read as a gap (#370, 2026-10-02
  and 2026-10-12).*
- **Drafts leave the machine.** A commit alone is on this machine only, and a session
  elsewhere cannot resume from it. After each draft commit, and at every ending, offer to
  push the branch, or to open a draft PR from it (which pushes it); do either on a yes.
  The user may instead give one standing yes to push after every draft commit for the
  rest of the session; then push each one and say so. Open a draft PR with
  `"$WS_ROOT/.agent/scripts/gh_create_pr.sh" --draft --title <title> --body-file <file>`,
  never raw `gh pr create`: the wrapper adds the signature and refuses a repository
  that is not the workspace's or a registered project's. The state comment (below) names the branch, the draft PR if there is one,
  and whether the latest draft commit is pushed; when it is not, it says the drafts are
  on this machine only.
- **Where each kind goes:**
  - a design decision into the level's design: one current picture, edited in place, no
    revision layers (ADR-0017); follow the design's own change rule, or say it is set
    aside;
  - work into the roadmap's `## Direction` section as a `| Line | Check |` row, each line
    with a check (grammar in the header of `sitrep_checks.sh` and, in the workspace's
    `docs/roadmap.md`, the `**Format.**` paragraph of its Direction section), and into the issues the lines cite, each issue body carrying the detail an
    implementer needs;
  - a parked or shelved item into the `| Deferral | Revisit check |` table, with its
    reason and what brings it back;
  - a pruned or rejected option under Decided Against, with its reason;
  - an offered but unsettled idea under To Consider, marked offered.

  If the roadmap lacks the section or table for an item's kind, say so and record that
  item on the anchor issue (below) rather than adding a section the readers do not know.
- **The why.** Each decision's reason goes to the Decisions role
  (`docs/design.md#documentation-layers`) as a signed comment on the anchor issue (the
  decision, its reason, the date, and where the decided text now lives), and as an ADR
  draft as well when the decision is a rule. Never as an entry in the issue's
  `progress.md`: a `## Checkpoint` or any other entry on the anchor issue's timeline
  derails a later `/run-issue` on that issue, whose next phase is read from those
  entries. The design keeps the current picture only, so without this the reasoning is
  lost and later sessions reopen what was settled.
- **Undecided state.** At every ending, offer a state comment on the anchor issue; offer
  one mid-session too, whenever the user asks, and before the next long research step
  when a session may be cut off mid-round *(untested)*. It is posted on a yes, like every
  write, and holds the open questions, the options still in play, what was parked and
  why, where the discussion stands, and where the drafts are (branch, draft PR, pushed or
  not). Step 1 reads the latest one first.
- **No document.** If the level has no goals, design or roadmap, or a Revise target is
  missing (say, no Direction section), the conversation still runs: drafts and open
  questions go in a comment on the anchor issue, not in a new file at a location no
  reader looks, and not only in the conversation. Say that Create comes in Part 2.
- **Second pass.** On a prune or shelve landing, offer a second pass by a fresh session
  (or a different model) that reads only the tracked record (documents, the anchor issue
  and its comments) and the design's decision record, and reports what the record does not
  account for. *Why: a fresh session, asked only whether the note was a useful redirect,
  found most of what the discussing session had missed in one read of the history.*
- Deriving a whole roadmap from a design is not part of this skill.

## Carve

A part has its own goals, design and roadmap (ADR-0022); the parent keeps only what
crosses the boundary. Each file written and each commit below is a tracked write: shown
first and made on the user's yes to it (Step 7's rule), the identity set first (Step 7).

1. **Place.** Propose the part's directory and confirm it with the user. Its `design.md`
   and `roadmap.md` go side by side in that one directory: the checkers read the design
   beside the sub-roadmap file. Propose the pointer row's `Root` cell too (the part's
   directory, or `.`): every check path in the sub-roadmap resolves against it, and the
   sub-roadmap file must sit inside it. Confirm both. Both cells are relative to the
   parent roadmap's root (for a parent that is itself a part, the parent's own `Root`).
   The part's directory must be in the parent's git repository, not a nested repository
   or submodule.
2. **The part's files.**
   - `design.md`: a goals section (no reader looks for a part's goals anywhere else),
     each goal naming the root goal it serves (ADR-0022 decision 7); then the part's
     design.
   - `roadmap.md`: a `## Direction` section with at least one `| Line | Check |` or
     `| Deferral | Revisit check |` row; a sub-roadmap with nothing to check is
     reported broken.
3. **The parent.** The parent's design keeps only what crosses the boundary, plus a
   pointer to the part cited `<path>/design.md#<section>` (ADR-0022 decision 6). The
   parent's roadmap gets one `| Sub-roadmap | Root |` row in its Direction section.
4. **Landing check.** Commit the part's files and the parent's edits first, so what is
   checked is what is landed: `check_design_anchors.sh` finds most citing files through
   `git ls-files` (tracked and staged files), but reads a sub-roadmap the pointer table
   names, and the `design.md` beside it, whether git tracks them or not. Then run the checks against
   the worktree the drafts were committed in (`$WT`), never against the root
   `sitrep_root.sh` reports: that is the main checkout, which does not hold the drafts,
   so the checks there pass without having read them. Paths in `<…>` are relative to
   the root, as the parent roadmap's pointer row writes them:

   ```bash
   WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
   WT="$(git -C <the drafts' worktree> rev-parse --show-toplevel)"
   "$WS_ROOT/.agent/scripts/check_design_anchors.sh" "$WT"; echo "check_design_anchors exit $?"
   "$WS_ROOT/.agent/scripts/sitrep_checks.sh" --root "$WT" --roadmap "$WT/<root roadmap>"; echo "sitrep_checks exit $?"
   ```

   and, when the parent is itself a part, also
   `"$WS_ROOT/.agent/scripts/sitrep_checks.sh" --root "$WT/<parent's Root>" --roadmap "$WT/<parent's roadmap>"`,
   which follows the new row. Report the results:
   - `check_design_anchors.sh` exit 0 is clean; exit 1 lists the broken citations; exit
     2 when the root has no `docs/design.md` means there was nothing to check against:
     say so, never count it as a pass.
   - It reads a part's design and roadmap as citers only when they sit under a `docs/`
     directory or the root roadmap's pointer table names the roadmap. A nested part
     outside `docs/` is checked only where another checked file cites it; say so when
     the placement keeps the part's files out of its reach.
   - In `sitrep_checks.sh`, the new row's `part` result must be `true`; `unchecked` is a
     broken pointer, which blocks calling the carve landed. Run on the root's roadmap
     with a nested part, the row shows `not-followed` (the checker follows one level):
     expected, not a failure.

## What this is not

- `brainstorm` lists options in one pass. This is a conversation that attacks and
  defends, and records what it settles.
- `review-plan` and `review-issue` check a written plan or issue against the rules. This
  asks whether the thing should exist in its current form.
- `sitrep` reports where a root stands. This changes the root's goals, design and
  roadmap, on the user's yes.
