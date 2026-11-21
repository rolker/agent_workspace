---
name: research
description: Survey external sources on a topic and maintain living research digests. The workspace digest lives in the workspace repo; a project digest lives in the project's own repo. The default scope is the session's root.
session_scope: both
---

# Research

## Usage

```
/research <topic>                      # Add to the session root's digest (default)
/research --scope project <topic>      # Add to the project digest
/research --scope workspace <topic>    # Add to the workspace digest
/research --ingest <url>               # Extract takeaways from a URL
/research --refresh                    # Re-survey known topics, prune stale entries
```

No `--scope` means the digest of the session's root (see Scope below): the
workspace digest in a workspace session, the project digest in a project session.

## Overview

**Lifecycle position**: Utility — not tied to the per-issue lifecycle. Use any
time to survey external sources or maintain research digests.

Maintain living research digests that capture external best practices, emerging
techniques, and relevant developments. This is **external research** — surveying
sources outside the workspace. For project introspection, use
`gather-project-knowledge`.

## Workspace root

This skill can run in a **project** session — a session started in a project
checkout, not in the workspace. There, `.agent/scripts/...` does not resolve:
those paths belong to the workspace, and the cwd is somewhere else entirely.

Every workspace path below is therefore written `$WS_ROOT/.agent/...`.
Resolve `$WS_ROOT` at the head of each command chain, because shell state does
not persist between tool calls:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
"$WS_ROOT/.agent/scripts/<script>" ...
```

`~/.claude/agent-workspace-root` is written by
`.agent/scripts/user_tier_install.sh` (ADR-0016). The `|| echo .` fallback is
required: the user tier is optional, and without it a missing file would leave
`$WS_ROOT` empty and turn every path into `/.agent/scripts/...`. With the
fallback, a workspace session on a machine without the user tier keeps working. The
`WS_ROOT="${WS_ROOT:-.}"` that follows covers a file that exists but is empty,
which `|| echo .` does not (`cat` succeeds there and prints nothing).

## Scope

Run this before anything else:

```bash
WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
"$WS_ROOT/.agent/scripts/session_root.sh"
```

It prints `root=`, `type=workspace|project` and `project=` (exit 1: this
directory is no session's root; stop and report its message).

- **No `--scope`**: the session root's digest — `type=workspace` gives the
  workspace digest, `type=project` the project digest of `project=`.
- **Workspace session**: both scopes work as before (`--scope project` writes
  through a project worktree; see Worktree setup).
- **Project session**: `--scope project` is the default. `--scope workspace`
  stays available for **reading and surveying** (reading across roots is
  allowed), but a session changes only its own root (ADR-0018 decision 6;
  `docs/design.md`, "Sessions and roots"). So a workspace-digest **write** from
  a project session does not create a workspace worktree. Instead:
  1. Draft the entry in the digest format and show the full entry text in the
     conversation, so the survey is not lost.
  2. Record it in the inbox. The topic and summary come from the web, so they
     are written to a temporary file through a quoted heredoc (`<<'EOF'`) and
     passed as `"$(cat "$f")"`: the quoted heredoc copies every character
     verbatim, and the text a command substitution returns inside double
     quotes is not expanded again, so a `$`, backtick, `$(...)` or quote in
     it stays text. Double quotes around the text itself would expand `$` and
     backticks; single quotes break on an apostrophe in it.
     ```bash
     WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
     f="$(mktemp)"
     cat > "$f" <<'EOF'
     research for the workspace digest: <topic> — <one-line summary>
     EOF
     "$WS_ROOT/.agent/scripts/capture.sh" "$(cat "$f")"; rm -f "$f"
     ```
     The script tags the line with the project the cwd is in, so the text itself
     must say it is for the workspace digest.
  3. Offer a workspace issue that carries the drafted entry in its body; open it
     only after the user's yes. From a project cwd a bare `gh issue create`
     would land in the project's repo, so open it through the signing wrapper
     with `-R` naming the workspace repo, looked up with `gh` in `$WS_ROOT`
     (never built from a directory name). The title and body, which carry web
     text, go in through quoted heredocs, as in step 2. Pass no `--label`:
     inside the project's git checkout the wrapper checks labels against that
     checkout's list, not the workspace's.
     ```bash
     WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
     source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" --agent <framework> "<model-id>"
     ws_repo="$(cd "$WS_ROOT" && gh repo view --json nameWithOwner --jq .nameWithOwner)"
     t="$(mktemp)"; b="$(mktemp)"
     cat > "$t" <<'EOF'
     research for the workspace digest: <topic>
     EOF
     cat > "$b" <<'EOF'
     <the drafted digest entry>
     EOF
     "$WS_ROOT/.agent/scripts/gh_create_issue.sh" -R "$ws_repo" --title "$(cat "$t")" --body-file "$b"
     rm -f "$t" "$b"
     ```

## Digests

Two digests, each git-tracked so they're shared across agents and sessions:

### Workspace digest

**Location**: `<research worktree>/.agent/knowledge/research_digest.md` in the
workspace repo (git-tracked; create with the digest format below if it doesn't
exist). Write it in the `--skill research` worktree, at that path relative to
the worktree's root, never as `$WS_ROOT/.agent/knowledge/research_digest.md`: `$WS_ROOT` is
the main checkout, and a write there edits the main tree instead of the
worktree's branch. `$WS_ROOT/.agent/knowledge/research_digest.md` is for
reading only, for example to survey the workspace digest from a project
session.

Topics relevant to any project using this workspace:
- Agent workflow patterns and multi-framework coordination
- CI/CD for AI-assisted development
- Governance automation and enforcement patterns
- Build system and tooling developments
- Worktree and git workflow patterns

### Project digest

**Location**: `.agents/workspace-context/research_digest.md` in the project's own
repo, git-tracked, committed there through a project worktree. This is the default
for every project type. When the workspace gains a per-project setting for where
such files live, the skill reads the path through that setting and falls back to
this default when it is unset.

"The project's own repo" is the git repository at the project's root (the
`root=` that `session_root.sh` prints, or the registered root of `--project
<name>`). A project whose root is not a git repository (a plain directory
holding several clones) has no such repo, and `worktree_create.sh --issue <N>
--type project` refuses there. Until the per-project setting above names a
place, such a project has no project digest: do not pick one of its clones.
Show the drafted entry in full in the conversation and record it in the inbox
as in Scope step 2, with the text starting `research for the <project> project
digest (root is not a git repository):`, then stop. Check before setting up a
worktree:

```bash
root="<root>"
top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)"
[ -n "$top" ] && [ "$(cd "$top" && pwd -P)" = "$(cd "$root" && pwd -P)" ] \
    && echo "root is a git repository" || echo "root is not a git repository"
```

Topics specific to the project domain (varies by project).

## Digest Format

```markdown
# Research Digest: <scope>

<!-- Last full refresh: YYYY-MM-DD -->
<!-- Run /research --refresh periodically to re-survey stale entries -->

## <Topic Title>

**Added**: YYYY-MM-DD | **Last verified**: YYYY-MM-DD | **Sources**: [link1](url), [link2](url)

Key takeaways:
- <concise finding>
- <concise finding>

**Relevance**: <why this matters to the workspace/project>

---

## <Topic From A Report Without Links>

**Added**: YYYY-MM-DD | **Last verified**: YYYY-MM-DD | **Sources**: pending

...
```

**Sources pending**: an entry carried over from a report that gave no links is
marked `**Sources**: pending` instead of inventing or dropping its sources.
`--refresh` takes pending entries first and replaces the mark with links.

**Staleness rules**: An entry is stale when its `Last verified` date (or `Added`
date if never verified) exceeds 30 days. Entries older than 90 days should be
flagged for review or removal. The top-level `Last full refresh` timestamp
records when `--refresh` last ran across all entries — it is not updated when
individual topics are added.

## Workflow

### Worktree setup

The worktree type depends on the scope:

- **Workspace scope** (workspace session only): use a `--skill research` worktree,
  no issue needed.
  ```bash
  WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
  "$WS_ROOT/.agent/scripts/worktree_create.sh" --skill research --type workspace
  source "$WS_ROOT/.agent/scripts/worktree_enter.sh" --skill research --type workspace
  ```

- **Project scope**: the project digest lives in the project repo, so a project
  digest update needs a project issue and a project worktree. `--skill research` is
  for workspace worktrees only: `worktree_create.sh` rejects
  `--skill research --type project`.
  ```bash
  WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
  "$WS_ROOT/.agent/scripts/worktree_create.sh" --issue <N> --type project
  source "$WS_ROOT/.agent/scripts/worktree_enter.sh" --issue <N> --type project
  ```
  In a project session the project is the one the cwd is in; from a workspace
  session add `--project <name>`.

### Project rules before committing a project digest

Before committing to a project digest, read the project's `.agents/README.md`
for rules about what may be committed (for example: the repo is public, or no
site data). When a rule applies: draft the full report somewhere the project
ignores or keeps private, write the digest entries in generic terms, and commit
only those entries. With no such rule, commit as usual.

### Adding research (`/research <topic>`)

1. Resolve the scope (see Scope) and set up the worktree for it (see Worktree
   setup); a workspace-digest write from a project session hands back instead
2. Search the web for current information on the topic, with generic queries
   only (see Guidelines: no real locations); pass that rule in the prompt of
   any sub-agent the search is delegated to
3. Read and synthesize relevant sources
4. Check the existing digest for related entries — update rather than duplicate
5. Append or update the entry in the appropriate digest (set both `Added` and
   `Last verified` to today for new entries; update `Last verified` for existing)
6. Commit in the correct repo: workspace digest commits go in the workspace
   repo; project digest commits go in the project repo (not the workspace),
   after the project-rules check above
7. Push and create the PR with the wrapper, which adds the AI signature and
   checks the target repo (a bare `gh pr create --fill` does neither). Run it
   from the worktree, so the PR goes to the repo the digest was committed in.
   The body names the issue: `Closes #<N>` for a project digest (its project
   issue); a workspace `--skill research` worktree has no issue and names none.
   ```bash
   WS_ROOT="$(cat ~/.claude/agent-workspace-root 2>/dev/null || echo .)"; WS_ROOT="${WS_ROOT:-.}"
   source "$WS_ROOT/.agent/scripts/set_git_identity_env.sh" --agent <framework> "<model-id>"
   git push -u origin HEAD
   "$WS_ROOT/.agent/scripts/gh_create_pr.sh" --title "research: <topic>" --body-file <body file>
   ```
   The title is your own short wording, with no `$`, backtick or quote in it;
   anything taken from the web goes in the body file, written through a quoted
   heredoc (`<<'EOF'`) as in Scope.
8. Leave the worktree in place: once the owner says to merge, the PR is
   merged, and the worktree cleaned up, by `$WS_ROOT/.agent/scripts/merge_pr.sh --pr <N>`
   (never `gh pr merge --delete-branch` from the worktree). It removes the
   worktree on the PR's branch and its branches; until then review fixes land there.

### Ingesting a URL (`/research --ingest <url>`)

1. Fetch and read the URL content (reading needs no worktree)
2. Extract key takeaways relevant to the workspace or project
3. Decide the scope before anything is set up: `--scope` when given;
   otherwise from the content, the session root's digest when it fits there,
   the other root's when it is clearly about that root, and ask when unclear
4. Apply that scope as Adding research step 1 does: a workspace-digest write
   from a project session hands back (see Scope) and stops here; otherwise set
   up the worktree for it (see Worktree setup), and for a project digest
   follow Project rules before writing it
5. Check the digest for related entries, then append or update (dates as in
   Adding research step 5)
6. Commit, push and create the PR as in Adding research steps 6 and 7; it is merged, and the worktree cleaned up, by `$WS_ROOT/.agent/scripts/merge_pr.sh --pr <N>`

### Refreshing (`/research --refresh`)

1. Resolve the scope (see Scope: `--scope`, else the session root). A refresh
   of the workspace digest from a project session reads and re-surveys but
   writes nothing: steps 2 to 4 run on the digest read from `$WS_ROOT`, and the
   updated entries are handed back together, once, as in Scope; no step 5 or
   6. Otherwise set up the worktree for it (see Worktree setup), and for a
   project digest follow Project rules before editing it
2. Read the digest for the target scope
3. Identify the entries to re-survey:
   - **`**Sources**: pending`**: first in line, to get links
   - then by each entry's `Last verified` date (or `Added` date if never verified):
     **>30 days**: prioritize for re-survey; **>90 days**: flag for review or removal
4. For each entry (pending first, then oldest first):
   - Search for updates on the topic (generic queries, as in Adding research)
   - Update findings if new information exists, and replace a pending mark with links
   - Update the entry's `Last verified` date to today
   - Mark as stale or remove if no longer relevant
5. Update the top-level `Last full refresh` timestamp to today
6. Commit, push and create the PR as in Adding research steps 6 and 7; it is merged, and the worktree cleaned up, by `$WS_ROOT/.agent/scripts/merge_pr.sh --pr <N>`

## Guidelines

- **External sources only** — this skill surveys the web, papers, docs, and
  community resources. It does not scan the workspace codebase.
- **No real locations in web queries** — web searches, and any research agent
  they are delegated to, use generic queries: no real coordinates, bounding
  boxes, site names or addresses, unless the owner approves that query. Pass
  this rule in every sub-agent prompt.
- **Concise entries** — each topic should be 5-15 lines. The digest is a
  reference, not a literature review.
- **Cite sources** — every entry needs at least one link, except one marked
  `**Sources**: pending` because its source report had none.
- **Dedup** — check for existing entries on the same topic before adding.
  Update existing entries rather than creating duplicates.
- **Commit each update** — so the digest history is traceable.
- **Staleness** — tracked per entry via `Last verified`. Entries >30 days
  are prioritized for refresh; >90 days are flagged for review or removal.
  Fast-moving topics may need shorter windows.
