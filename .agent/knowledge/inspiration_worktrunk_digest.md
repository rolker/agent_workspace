# Inspiration Digest: worktrunk

Type: inspiration
Last checked: 2026-09-22
Repo: max-sixty/worktrunk (no local clone checked out; survey done from
README + GitHub API — see "Clone note" below)

First-run survey. Registry interest areas: worktree lifecycle UX
(switch/list/merge addressed by branch name); pre/post-merge and
post-create hooks for workflow automation; copy-on-write build-cache
sharing across worktrees; LLM-generated commit messages; PR/MR checkout
directly into a worktree.

## Survey Summary

Worktrunk (dual MIT/Apache-2.0, Rust) is a CLI, `wt`, that makes git
worktrees addressable and manageable by branch name instead of by path.
Released "at the start of the year" per the README's September 2026
banner and, per that same banner, already "the most popular git
worktree manager" — corroborated by 8,335 stargazers (by far the
highest-starred project in this registry) and daily commit activity
(`pushedAt` within hours of this survey). It targets the same problem
this workspace's `worktree_create.sh` / `worktree_enter.sh` /
`worktree_remove.sh` scripts solve, but as a general-purpose,
installable tool (Homebrew/Cargo/Winget/pacman/Conda) rather than a
workspace-specific script set.

### Interest-area findings

**1. Worktree lifecycle UX.** Three core commands —
`wt switch [--create] <branch>`, `wt list`, `wt remove` — replace the
multi-step plain-git sequence (`git worktree add -b <branch>
../repo.<branch> && cd ../repo.<branch>`) with one addressed-by-branch
call. `wt list` renders a status table per worktree: staged/unstaged
diff counts, ahead/behind vs. main, unpushed-commit indicator, last
commit age and message — richer at a glance than `worktree_list.sh`'s
output today. `wt switch -c -x claude feat` creates the worktree *and*
launches an agent inside it in one command, directly comparable to
`/start-task`'s `cd`-into-worktree step, except Worktrunk also chains
the agent launch.

**2. Hooks.** Documented hook types include pre-merge, post-merge, and
(implied by "on create") post-create — commands run automatically at
worktree lifecycle transitions, configured once and applied to every
worktree. This workspace has no hook mechanism today; `worktree_create.sh`
/ `worktree_enter.sh` are the only lifecycle points, and any per-worktree
setup (venv activation, dependency install) is currently manual or
baked into the entry script itself rather than user-configurable.

**3. Copy-on-write build-cache sharing.** `wt step copy-ignored`
(exact mechanism not fully detailed in the README, deferred to
worktrunk.dev docs) lets ten worktrees share `target/`, `node_modules/`,
etc. "without building or copying them" on APFS/btrfs/XFS — i.e.
filesystem-level CoW reflinks, not a build-cache server. This is the
most directly relevant interest area for #265 / ADR-0012: every project
worktree created by `worktree_create.sh --type project` today pays a
full dependency install (or must be told to reuse one out of band), and
package-manager caches are the main friction point named in that
ADR. A CoW-based ignored-file mirror (git-worktree-agnostic, filesystem
feature-gated) is a concrete mechanism to evaluate, distinct from a
shared package-manager cache directory.

**4. LLM commit messages.** `wt merge` (local squash/rebase/
fast-forward-merge/cleanup path) generates a commit message from the
diff as part of the merge step, shown inline in the README's `wt merge
main` transcript ("Generating commit message and committing changes...").
This workspace already has an LLM in the loop for every commit (the
agent writing it), so the *automation* value is lower here than for a
human-driven CLI — but the merge-workflow packaging (squash + rebase +
fast-forward + worktree/branch cleanup as one command) is itself
useful independent of the LLM part; `merge_pr.sh` already does a
superset of this for GitHub-mediated merges, but there is no equivalent
one-shot *local* squash-merge command in this workspace's script set.

**5. PR/MR checkout.** `wt switch pr:123` fetches and checks out a PR's
branch into its own worktree in one call, for both GitHub and GitLab.
No equivalent exists here; reviewing or continuing someone else's PR
locally today means manually fetching the branch and creating a
worktree by hand.

### Not directly relevant

The interactive picker (streaming CI status, diff/log/PR-comment
previews), per-worktree unique dev-server ports (`hash_port` template
filter), and aliases/per-branch state variables are polish features
tied to Worktrunk's own interactive terminal UI — useful for a human
running `wt` day to day, not something an agent-driven worktree script
needs to replicate.

### Activity Snapshot (2026-09-22)

- 8,335 stars (by a wide margin the most-starred project in this
  registry), dual MIT/Apache-2.0, Rust, created 2025-10-17. `pushedAt`
  2026-09-22T14:12Z — commits landing within the hour of this survey.
- 10 open PRs sampled, spanning bug fixes (separate-git-dir path
  resolution, picker cursor targeting), new integrations (Cursor agent
  plugin), and experimental config sources (`worktrunk.config.*`
  git-config project source) — broad, active contribution surface, not
  a single-maintainer trickle.
- 10 open issues sampled include agent-integration requests (Cursor
  plugin + mixed-agent setup guidance, GitHub Copilot CLI activity
  tracking) confirming this project explicitly targets the
  multi-agent-CLI audience this workspace also serves.
- Maintained with `tend` (the author's own release/maintenance tooling,
  badge-linked) — a signal of an established release process, not an
  ad hoc project.

### Clone note

Per skill step 2, a local shallow clone would normally live at
`<MAIN_ROOT>/.agent/scratchpad/inspiration/worktrunk/`. This first-run
survey was done from the GitHub README + `gh api` activity endpoints
only (no local clone); the hook and CoW-cache mechanisms are
documented only at the summary level on worktrunk.dev and would need a
source read (`src/` for the `wt step copy-ignored` implementation, the
hook config schema) before any port decision.

## Activity Snapshot

See "Activity Snapshot (2026-09-22)" above.

## Pending Review

- `cow-build-cache-sharing-for-project-worktrees` — Evaluate `wt step
  copy-ignored`'s filesystem-CoW approach (APFS/btrfs/XFS reflinks) for
  sharing `node_modules`/`target`/venv-equivalent directories across
  `worktree_create.sh --type project` worktrees, as a concrete mechanism
  for the #265 / ADR-0012 package-worktree pain point. Needs a source
  read of the actual `wt step copy-ignored` implementation before
  scoping. (2026-09-22)
- `worktree-lifecycle-hooks` — No hook mechanism exists today for
  `worktree_create.sh` / `worktree_enter.sh`; Worktrunk's
  pre-merge/post-merge/post-create hook model is a candidate shape
  (config-driven, not agent-invoked) for per-worktree setup automation
  (dependency install, venv activation) that is currently manual or
  hardcoded. (2026-09-22)
- `pr-checkout-into-worktree` — `wt switch pr:N` (fetch + checkout a PR
  branch into a fresh worktree in one command) has no equivalent here;
  reviewing/continuing another agent's or human's PR locally is
  currently a manual fetch + worktree_create sequence. (2026-09-22)
- `local-squash-merge-one-shot` — `wt merge main`'s local
  squash/rebase/fast-forward/cleanup-in-one-command path has no
  standalone equivalent outside the GitHub-mediated `merge_pr.sh` flow;
  worth checking whether a local-only merge path is ever needed (e.g.
  skill-worktree digest commits that don't go through a PR review gate
  — though per this skill's own workflow, they still go through a PR).
  (2026-09-22)

## Roadmapped

(none — first-run survey; items above are pending review, not yet
triaged into roadmap/skip/defer)

## Skipped

(none)

## Deferred

(none)
