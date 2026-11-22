---
name: brainstorm
description: Explore possibilities for a topic by combining research digests with project knowledge and governance context.
session_scope: both
---

# Brainstorm

## Usage

```
/brainstorm <topic>
```

## Overview

Creative exploration tool. Reads research digests, project knowledge, and
governance docs to explore possibilities for a given topic, from a workspace
session or a project session. The findings are presented in the conversation;
Step 4 then offers to save them as a signed comment on the topic's anchor
issue, written only on the user's yes, where `design-discussion` Step 1 reads
them.

**Lifecycle position**: Before `review-issue` and before `design-discussion` —
exploratory thinking before the work is settled. Can also be used mid-task to
explore alternatives.

## Workspace root

This skill can run in a **project** session — a session started in a project
checkout, not in the workspace. There, a bare `.agent/...` path does not
resolve: those paths belong to the workspace, and the cwd is somewhere else.

Every workspace path below is therefore written `$WS_ROOT/...`. Resolve
`$WS_ROOT` at the head of each command chain, because shell state does not
persist between tool calls:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
```

`~/.claude/agent-workspace-root` is written by the user-tier install
(`.agent/scripts/user_tier_install.sh`) and names the workspace's main
checkout. The `|| echo .` fallback is required: the user tier is optional
(ADR-0016), and without it `$WS_ROOT` would be empty and every path would
become `/.agent/...`. With the fallback, `$WS_ROOT` is `.`, which is right in
a workspace session.

A path written without `$WS_ROOT` (such as `.agents/README.md` or
`docs/design.md` in the project list below) is relative to the **project
root**: in a project session, the session's root; in a workspace session on a
project's topic, that project's registered folder, the `<path>` field of its
line in `$WS_ROOT/.agent/projects.local` (a relative `<path>` resolves against
`$WS_ROOT`). Ask the user which project when the topic does not name one, and
say so when it is not registered: there is then no project to read.

## Steps

### 1. Load context

Every source is optional. Read what exists, and say in the output (the
`### Sources` section) which sources were read and which were absent.

**Workspace sources** (always, from either session):

- `$WS_ROOT/.agent/knowledge/research_digest.md` — workspace research digest
- `$WS_ROOT/docs/principles.md` — workspace principles (for feasibility checks)
- `$WS_ROOT/AGENTS.md` — workspace-wide agent rules and conventions
- `$WS_ROOT/docs/design.md` — workspace design and layering constraints
- `$WS_ROOT/docs/decisions/` — ADRs for historical context
- the workspace roadmap: `$WS_ROOT/docs/roadmap.md`, else `$WS_ROOT/ROADMAP.md`

**Project sources** (from the project root above; in a workspace session,
only when the topic is about a project):

- `.agents/workspace-context/research_digest.md` — the project's research
  digest (the path `design-discussion` reads; #551 may move it)
- `.agents/README.md` — the project's agent rules, including what may not be
  written in its public places
- the project's principles (`PRINCIPLES.md` or `docs/principles.md`), design
  (`docs/design.md` or `ARCHITECTURE.md`) and ADRs (`docs/decisions/`)
- the project's roadmap: `docs/roadmap.md`, else `ROADMAP.md` (what
  `"$WS_ROOT/.agent/scripts/sitrep_root.sh" --dir <project root>` reports as
  `roadmap=`; without `--dir` it reports the session's own root)

**A part** (ADR-0022): when the topic is about a part of the workspace or a
project, also read the part's own `design.md`: the `design.md` in the same
directory as the part's sub-roadmap file, which its parent's
`| Sub-roadmap | Root |` row names (the rule `design-discussion` Step 0
uses; the row's `Root` cell is not where the design is). If there is none
there, say so; never guess another location.

Check digest freshness — if a digest is older than 30 days, note it and
suggest a refresh with `/research` but don't block on it.

### 2. Explore the topic

For the given topic, consider:

- **What exists**: What does the workspace/project already have that relates?
- **What's possible**: What approaches could work? Draw on research digest
  entries for external patterns and best practices.
- **What's missing**: What gaps exist? What would need to be built or changed?
- **Trade-offs**: What are the pros and cons of different approaches?
- **Principle alignment**: Would any approach conflict with workspace or
  project principles?

### 3. Present findings

Structure the output as:

```markdown
## Brainstorm: <topic>

### Sources
- Read: <each source read>
- Absent: <each source looked for and not found>
- Digest entries used: <each entry cited below, as digest file and entry heading>

### Current State
<what exists today>

### Possibilities
1. **<approach>** — <description>
   - Pros: ...
   - Cons: ...
   - Research: <reference to digest entry if applicable>

2. **<approach>** — ...

### Gaps
- <what's missing that any approach would need>

### Principle Considerations
- <any principle alignment issues>

### Suggested Next Steps
- <concrete actions to explore further or begin implementation>
```

In `### Sources`, name every file repo-relative: a workspace file from the
workspace root (`docs/principles.md`, never `$WS_ROOT` expanded to a local
path), a project file from the project root (`.agents/README.md`), and name
the repository once when the brainstorm draws on both. Never write an
absolute local path: the findings may be posted as a public comment (Step 4).

### 4. Offer to save

After presenting the findings, offer to save them. Nothing is written without
the user's yes.

**The saved form (the contract `design-discussion` Step 1 reads).** A signed
comment of its own on the topic's anchor issue, in the repository that owns
the issue, whose body opens with the line `## Brainstorm: <topic>` and holds
the Step 3 findings, citing the digest entries used. A reader finds it on the
issue by that heading. The brainstorm never goes in an issue's body, not even
one this step opens for it.

The topic's root is the project root (the Workspace root section, above)
when the topic is a project's, else the workspace. Its repository (`<owner/repo>`) is what
`gh repo view --json nameWithOwner --jq .nameWithOwner` prints, run in that
root. Pass `-R <owner/repo>` on every `gh` call below whenever the topic's root
is not the session's own root.

1. **Issues and `gh` first.** Before asking about an issue, check that the
   result can be saved at all:
   - `gh auth status` succeeds;
   - the topic's root is known and `<owner/repo>` resolves: a project's topic
     names a registered project (Workspace root, above), and `gh repo view`
     run in that root prints a repository (it fails with no GitHub remote).
     `gh repo view` walks up from a folder, so a folder inside another git
     repository resolves that one: first check the root is itself a git
     toplevel (`git -C <root> rev-parse --show-toplevel` equals the root, as
     `research` checks), and show the resolved `<owner/repo>` to the user;
   - for a project's topic, the project uses issues: the `issues` fact of
     `"$WS_ROOT/.agent/scripts/project_integration_audit.sh" --facts --format
     text --dir <project root>` (as `onboard-project` reads it); ask the user
     when it is `unknown`. `no` includes "enabled but none was ever opened"
     (the audit's rule), so a project's first issue is the user's call, not
     this skill's. The workspace uses issues.

   If `gh` is missing or not authenticated, the project is not registered,
   `<owner/repo>` does not resolve, or the fact is `no`, the result stays in
   the conversation. Say so plainly; write nothing anywhere else, and never
   fall back to the workspace repository for a project's topic.
2. **Anchor issue.** Ask which issue the brainstorm belongs to. If there is
   none, offer to open one (Issue-First Policy). Its body is a short statement
   of the topic, not the brainstorm. Give its title and body the
   public-project check (item 3) and show both in full; open it only on a
   yes, with item 4's chain and the title written verbatim too. It is item 4's
   chain with two additions: a second scratchpad file `t`, made right after
   `body` and filled by its own quoted heredoc after the body's; and a last
   line that creates the issue in place of `gh issue comment`, removes both
   files and still keeps the exit status (`rc=$?` and `(exit $rc)` stay):

   ```bash
   WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"; \
   WS_ROOT="$(cd "$WS_ROOT" && pwd)" && cd "<topic root>" && \
   source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" --agent <framework> "<model id>" && \
   body="$(mktemp "<scratch dir>/brainstorm.XXXXXX")" && \
   t="$(mktemp "<scratch dir>/brainstorm-title.XXXXXX")" && \
   cat > "$body" <<'BODY' &&
   <the issue body exactly as shown, without the signature>
   BODY
   cat > "$t" <<'TITLE' &&
   <the issue title exactly as shown>
   TITLE
   printf '\n---\n**Authored-By**: `%s`\n**Model**: `%s`\n' "$AGENT_NAME" "$AGENT_MODEL" >> "$body" && \
   gh issue create [-R <owner/repo>] --title "$(cat "$t")" --body-file "$body"; rc=$?; rm -f "$body" "$t"; (exit $rc)
   ```

   The title is never typed inside double quotes, so no backtick span, `$`
   or `$(...)` in it is run or expanded; the closing `TITLE` stands alone at
   the start of its line, like `BODY` (item 4). Report the issue's URL, which
   `gh issue create` prints, only when the chain exits 0; otherwise say the
   issue was not opened. Then save the brainstorm on it as a separate
   comment (items 3 and 4), which needs its own yes.
3. **Public-project check.** Before showing the comment, or a new anchor
   issue's title and body, check that text against the project's
   `.agents/README.md` rules (for example, no site data) and remove what they
   forbid. Say what was removed.
4. **Show, then post on a yes.** Show the full comment text. On the user's
   yes, in one command chain: resolve `$WS_ROOT`, `cd` into the topic's
   root, set the identity, write the body to a file in the session's
   scratchpad **verbatim** (a quoted heredoc,
   so no backtick span, `$` or `$(...)` in the text is run or expanded),
   append the signature with `printf`, post it, remove the file, and keep the
   chain's exit status, so a failed post is never reported as posted:

   ```bash
   WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"; \
   WS_ROOT="$(cd "$WS_ROOT" && pwd)" && cd "<topic root>" && \
   source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" --agent <framework> "<model id>" && \
   body="$(mktemp "<scratch dir>/brainstorm.XXXXXX")" && \
   cat > "$body" <<'BODY' &&
   <the comment text exactly as shown, without the signature>
   BODY
   printf '\n---\n**Authored-By**: `%s`\n**Model**: `%s`\n' "$AGENT_NAME" "$AGENT_MODEL" >> "$body" && \
   gh issue comment <N> [-R <owner/repo>] --body-file "$body"; rc=$?; rm -f "$body"; (exit $rc)
   ```

   `<scratch dir>` is the session's scratchpad directory when the framework
   gives one (Claude Code does), else `$WS_ROOT/.agent/scratchpad/` (AGENTS.md
   Workspace Cleanliness); `mktemp` makes the name unique, and the item 2
   title file `t` is made the same way. The chain `cd`s into the topic's
   root before sourcing the identity, because the identity's email follows
   the current folder's git email; `$WS_ROOT` is made absolute first, so a
   `.` fallback still names the workspace after the `cd`. The closing `BODY`
   stands alone at the start of its line (no list indent); if the text holds
   a line that is exactly `BODY`, pick another delimiter. Use
   `-R <owner/repo>` whenever the topic's root is not the session's own root
   (above). Never `--body`. Report the comment's URL,
   which `gh issue comment` prints, only when the chain exits 0; otherwise
   say the post failed.

**Never** a `progress.md` entry: brainstorm results are not an entry type on
an issue's timeline (ADR-0013), and an entry there derails a later
`/run-issue` on that issue, whose next phase is read from those entries.
**Never** a write to a research digest: the digests belong to `research`.

## Guidelines

- **Explore, don't decide** — present options with trade-offs. The user
  decides which direction to go.
- **Reference research** — when drawing on digest entries, cite them. This
  validates the digests' usefulness and helps the user trace your reasoning.
- **Stay grounded** — possibilities should be feasible within the workspace's
  architecture and constraints. Wild ideas are welcome but should be flagged
  as speculative.
- **One tracked write, on a yes** — the saved comment of Step 4 (and the
  anchor issue, if the user asks for one) is the only thing this skill writes
  outside the conversation. Opening any other issue from the brainstorm's
  ideas is the user's call, not this skill's.
- **Keep it conversational** — this is the most informal of the lifecycle
  skills. Be thorough but not rigid.

## What this is not

- Not a challenge to an idea. `brainstorm` lists options in one pass;
  `/design-discussion` is a two-way conversation that attacks and defends an
  idea or a design in progress and lands on continue, prune, shelve or
  clearer but undecided.
