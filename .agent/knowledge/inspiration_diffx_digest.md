# Inspiration Digest: diffx

Type: inspiration
Last checked: 2026-09-14
Repo: wong2/diffx @ 1388595f1fea0ca4f33c4a1c2773a9e19d1bc27b

Registry interest areas: review-before-push workflow integration; diff
presentation for human supervision of agent output; inline commenting and
finding-tracking UX; staying local-first / terminal-adjacent.

## Survey Summary (first run, 2026-09-14)

### What it is

`diffx` (npm `diffx-cli`, v0.16.0, MIT) is a ~40-file TypeScript tool: a
Hono HTTP server bound to `127.0.0.1` on a random port, serving a React/Vite
single-page app that renders `git diff` output GitHub-PR-style (split/unified,
Shiki highlighting, file tree, viewed-tracking, context expansion, image
diffs). Run `diffx` in any git repo and a browser opens; anything after `--`
is passed straight to `git diff` (`diffx -- main..HEAD`, `-- --staged`).

The coding-agent angle is the **comment round-trip**:

- Human clicks `+` on a diff line and writes a comment. Comment model
  (`src/types.ts`): `filePath`, `side` (additions|deletions), `lineNumber`,
  `lineContent`, `body`, `status` (open|resolved), `replies[]`.
- Comments are served over a local REST API (`GET/POST /api/comments`,
  `PUT /api/comments/:id` for status, `POST /api/comments/:id/replies`).
- "Copy comments" exports all comments as an XML block
  (`<code-review-comments><file path><comment line><code>+ ...</code>`)
  for pasting into any agent.
- Two shipped agent skills (`skills/diffx-start-review`,
  `skills/diffx-finish-review`, installed via `npx skills add wong2/diffx`):
  start = run `diffx` in the background and tell the user to review; finish =
  `curl` the comments API, treat each open comment as either a **change
  request** (apply, reply, mark resolved) or a **question** (reply only,
  leave open for the human), then summarise. The browser UI updates live as
  the agent resolves items (sidebar tracker: open / replied / resolved).

Comment storage is in-memory only (`InMemoryCommentStore`); nothing is
written to the repo, and comments vanish when the server exits (issue #29
asks for persistence, unaddressed).

### Mapping to workspace categories

| Category | diffx | Notes |
|----------|-------|-------|
| Governance model | none | Single-maintainer tool; no contributor guide, no ADRs |
| Skills / commands | 2 Claude-style `SKILL.md` files with `user_invocable: true` | Same shape as our `.claude/skills/*/SKILL.md`; skills are thin wrappers over `curl` |
| Isolation strategy | cwd-scoped git repo; no worktree awareness | Works unchanged inside any worktree because it only shells out to `git` |
| Identity management | none | Replies show a generic bot avatar; no agent/model attribution |
| Testing approach | **none** — zero test files | |
| CI/CD | one workflow: changesets release-PR + npm publish on push to `main` | No lint/test gate |
| Documentation | README + auto-generated CHANGELOG (changesets) | |

### Interest-area findings

**1. Review-before-push workflow integration.** diffx sits at a point our
loop does not cover: *human inline review of the agent's uncommitted or
unpushed diff, handed back to the same agent, before anything reaches
GitHub*. Our current loop is post-push: `/review-code` (agent reviews the
PR) and `/triage-reviews` (agent evaluates human/bot comments already on the
PR via `gh api`). diffx's start/finish skill pair is the pre-push mirror of
`/triage-reviews`: same "fetch comments, classify, act, reply, resolve"
shape, but sourced from a local API instead of GitHub. The pattern is
portable independent of the tool; the tool itself is not required for it.

**2. Diff presentation for human supervision.** This is the bulk of the
codebase (virtualised rendering, sticky file headers, context expansion,
viewed-tracking that auto-clears when a file's content hash changes). All of
it is browser UI. Nothing here is portable to a terminal; the only reusable
idea is the "mark viewed, invalidate on content change" progress tracker.

**3. Inline commenting and finding-tracking UX.** The useful, portable part
is the **contract**, not the UI: a small, line-anchored comment schema
(`filePath`/`side`/`lineNumber`/`lineContent`/`body`/`status`/`replies`)
plus the finish-skill's rule that *questions are answered but left open;
change requests are applied, replied to, and resolved*. `lineContent` is
carried so the agent can relocate the anchor after the line numbers shift.

**4. Staying local-first / terminal-adjacent.** diffx is local (loopback,
no cloud, no account) but **not terminal-adjacent** — the review surface is
a browser tab. Measured against this workspace's CLI-first architecture
note (see `inspiration_ros2_agent_workspace_digest.md`, "CLI-first
architecture note": tools should *augment* the terminal, not replace it),
diffx is on the wrong side of the line for the review surface, though it is
far lighter than a persistent dashboard: launched from the terminal, one
repo, one session, gone on Ctrl-C. The Ultraplan "Evaluate" row in
`docs/ROADMAP.md` already accepts a CLI→web-editor→back-to-CLI round trip
for plans, so a diffx-shaped round trip for diffs would not be a new
category of exception — but it would be a second one.

### Is diffx the `inline-comment-review-ui` roadmap idea?

**No.** The parked idea (ros2 digest "Pending roadmap add", subsumed into
the Ultraplan "Evaluate" row in `docs/ROADMAP.md`) is *inline comments on a
plan / long agent response* — a markdown document, commented per-line, that
the agent then addresses. diffx comments on **code diff lines**, not prose,
and cannot render a markdown document at all today. The open PR #39 /
issue #38 ("rendered markdown, Mermaid, Google Docs-style comments, dark
mode") would move it toward that, but it has sat unmerged since July.
diffx is an adjacent implementation of a *different* object (diff review),
and the two could share a comment contract, but it does not implement the
parked idea.

### Security note (governance-relevant)

The local API has no auth, accepted any `Origin`, and `/api/file-content`
served any repo file (including gitignored `.env`) until PR #40 — which is
**still unmerged** as of this check (opened 2026-07-31). Because the finish
skill applies posted comments as code edits, any web page open in the same
browser could inject "review comments" that the agent then executes. If the
workspace ever adopts a local review-comment API of this shape, loopback
`Host` + same-origin `Origin` checks and a diff-scoped file allowlist are
the minimum bar.

### Relevance to the workspace redesign (issue #172)

Nothing in diffx bears on project-type adapters, the multi-tenant project
registry, or per-project manifests. It is repo-agnostic (shells out to
`git` in the cwd) and would run identically in a workspace worktree or a
project worktree. The only touch point if a review-before-push skill were
ever built: it would resolve the review root via `adapter project_root`
like any other skill, and any on-disk comment store would be a gitignored
per-worktree file. **No change to the #172 path.**

## Activity Snapshot (2026-09-14)

- Repo created 2026-04-04; 199 stars, 33 forks; single maintainer (wong2).
- Last commit / release: **2026-06-23** (v0.16.0, sidebar resize). No
  commits in the ~12 weeks since; no issues or PRs closed in the last 30
  days. Five releases in Apr–Jun, then silence.
- 6 open issues (multiline comments #33, comment editing #34, persistence
  #29, import comments #28, scroll jump #24, markdown/dark-mode #38).
- 3 open PRs, all unreviewed by the maintainer: #39 markdown + Google-Docs
  comments (Jul 14), #40 API scoping / same-origin security fix (Jul 31),
  #41 untracked-file diff fix (Aug 7).
- Assessment: effectively dormant. See "Tracking status" below.

## Tracking status

- 2026-09-14: keep tracked for **one more round**. If there is still no
  maintainer activity (no commits after 2026-06-23, open PRs #39/#40/#41
  still unreviewed) at the next check, move diffx to **watched-not-tracked**
  — registry entry retired, this digest kept as the record. The portable
  ideas are already captured in the decision sections below, so nothing is
  lost by dropping it. No registry edit made this round.

## Pending Review

(none — all 2026-09-14 items decided below)

## Roadmapped (2026-09-14 decisions)

- `question-vs-change-request-split` — The finish skill's rule: questions
  get a reply and stay open for the human; change requests get applied,
  replied to, and resolved. `/triage-reviews` already classifies valid /
  false-positive but does not distinguish "the reviewer asked a question"
  from "the reviewer wants a change", and could resolve a question by
  answering it. Small absorb into `/triage-reviews` — added to ROADMAP.md
  via the consolidated 2026-09-14 sweep block in the gstack digest PR
  (2026-09-14)

## Skipped (2026-09-14 decisions)

- `viewed-tracking-with-content-hash` — Per-file "reviewed" flag that
  auto-clears when the file's content hash changes (PR #23). Only
  meaningful inside a review UI we do not have. (2026-09-14)
- `local-agent-api-injection-surface` — Governance caution, not a feature:
  a loopback HTTP API whose inputs become agent code edits is a
  prompt-injection surface (any open browser tab can POST to it); diffx
  shipped without origin/host checks and the fix (PR #40) is unmerged. We
  have no such API today; the caution stays recorded here (and in the
  "Security note" above) so it is found if a local review loop is ever
  built. (2026-09-14)

## Deferred (2026-09-14)

- `review-before-push-local-loop` — A pre-push human-review step: agent
  presents its working-tree diff, human leaves line-anchored comments, the
  same agent fetches them, applies change requests, answers questions, and
  resolves each — the local mirror of `/triage-reviews`. Real gap in our
  loop (all human review is post-push), but the only existing
  implementation is a browser UI on the wrong side of the CLI-first
  constraint. Revisit after the Ultraplan spike settles whether a
  CLI→web→CLI round trip is acceptable for plans; if yes, a diff-review
  variant is a candidate. (2026-09-14)
- `line-anchored-comment-contract` — Adopt diffx's comment schema
  (`filePath`, `side`, `lineNumber`, `lineContent`, `body`, `status`,
  `replies`) and its XML hand-back block as the workspace's canonical
  human→agent review-comment format, independent of any UI (a YAML file in
  the worktree, or `gh` review comments, could both serialise to it).
  Cheap and tool-agnostic; `lineContent` anchoring survives line drift.
  Only worth doing together with the loop above; no consumer today.
  (2026-09-14)
