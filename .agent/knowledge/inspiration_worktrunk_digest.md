# Inspiration Digest: worktrunk

Type: inspiration
Last checked: 2026-11-13
Repo: max-sixty/worktrunk @ d5b9a7e01dc086a5109673d04e3b0243ea14647b
Previously checked: 2026-09-22 (no commit SHA recorded: the first survey was
done from the README and GitHub API without a clone)

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

## Changelog (2026-09-22 → 2026-11-13)

Method note: the 2026-09-22 survey recorded no commit SHA, so a compare from
the last-checked SHA was impossible; and the volume is large anyway (378
commits since 2026-09-22 by `gh api repos/max-sixty/worktrunk/commits?since=2026-09-22T00:00:00Z`),
well past the compare API's 250-commit limit. Used instead the release notes
in the new shallow clone (`CHANGELOG.md`, HEAD d5b9a7e, commit date
2026-11-12; clone at `.agent/scratchpad/inspiration/worktrunk/` in the main
checkout), `gh release list`, and merged-PR titles. Release notes for v0.80.0
and v0.81.0 were read; per-commit diffs were not.

**Releases since the survey**: v0.80.0 (2026-09-27) and v0.81.0
(2026-10-20). v0.79.0 was 2026-09-21, one day before the survey. A release PR
for v0.82.0 (#4716) is open; nothing released in the 24 days since v0.81.0
although commits land daily.

Changes touching the registry interest areas:

- **Copy-on-write build-cache sharing (`wt step copy-ignored`)**, v0.81.0.
  Linux: copied files now keep the source mtime (cargo previously rebuilt much
  of a copied `target/`); a reflink rejected with `EPERM` falls back to a
  plain copy; directory patterns in `.worktreeinclude` and
  `[step.copy-ignored] exclude` now behave like `.gitignore`. Open-in-last-48h
  fix #4751 (copy-ignored reaching `.worktreeinclude` paths inside a wholly
  ignored directory). The mechanism is a reflink copy driven by
  `.worktreeinclude`, which the survey said was not detailed.
- **Hooks**, v0.81.0 (marked breaking): serial foreground hooks (`pre-*`,
  `wt hook <type> --foreground`) inherit wt's stdin, so a hook can prompt;
  hooks no longer receive context as JSON on stdin (use template arguments or
  the new `tojson` filter); templates moved to MiniJinja 3 with undefined
  variables now errors; hook failures name the hook's source. Open issue
  #4143: `wt switch <branch>` skips `pre-start`, so a suggested recovery after
  a failed setup reports success on an unusable worktree; PR #4705 adds a
  retry-setup hint.
- **Worktree lifecycle UX**, v0.81.0: `wt switch -` returns to the worktree it
  left; experimental `wt switch --path` places one worktree outside the
  `worktree-path` template; `wt merge --branch` merges another worktree's
  branch without leaving the current one; faster bulk removal; removal
  refusals explain themselves (`--force` lists what it discards); `wt step
  prune` fixes.
- **Merge safety**, v0.80.0 and v0.81.0: a squash whose commit fails keeps the
  branch untouched (it used to leave it at the merge base with changes
  staged); squash backups print a `refs/wt-backup/<branch>` recovery command;
  formatter pre-commit hooks during a squash now land in the squash commit.
- **PR/MR checkout**: `wt switch pr:N` continues to gain forge coverage (Azure
  DevOps, Gitea, GitHub Enterprise host handling in merged PRs #4722, #4734,
  #4764). No change to the basic behaviour.
- **LLM commit messages**: Codex command updated to a smaller model with
  reasoning off (v0.80.0); open issue #4264 proposes a direct small-model
  query instead of an agent CLI.
- **Agent integration (outside the registry list, but relevant)**: the Claude
  Code plugin's `WorktreeCreate` / `WorktreeRemove` hooks route worktrees that
  Claude Code creates (`claude --worktree`, `EnterWorktree`) through `wt
  switch --create` / `wt remove`; the plugin ships a `wt-switch-create` skill
  that moves a session into a worktree, including in another repository, and
  (v0.81.0) reads that repo's root `CLAUDE.md` and `AGENTS.md`. Open issue
  #4776 documents that the Claude desktop app skips the plugin's worktree
  hooks. An OpenCode 2 integration and a Cursor plugin (PR #4225, open) exist.
- **Repo conventions**: `AGENTS.md` shared by Claude Code and Codex was cut
  from 2,763 to 382 lines in v0.80.0 (121 lines in the current clone). The
  repo uses its own skills (`.claude/skills/release`, `running-tend`,
  `writing-user-outputs`) for maintenance by agents. Releases carry a signed
  `packslip.sigstore.json` manifest (v0.80.0).

**Corrections to the 2026-09-22 survey**

- Stars: the survey recorded 8,335; the current count is 12,502.
- The survey said `wt step copy-ignored` was "not fully detailed" and needed a
  source read: it is now cloned and the behaviour above is from the release
  notes; the implementation under `src/` was not read in this run.
- The "Clone note" is superseded by the clone made on this run.
- The survey's hook description ("pre-merge, post-merge, post-create implied")
  predates the v0.81.0 hook changes above (pre-start, pre-remove, post-remove
  hooks named in release notes); the hook model is larger than described.

## Activity Snapshot

Snapshot 2026-11-13 (supersedes the 2026-09-22 snapshot above for counts):

- 12,502 stars (was 8,335), dual MIT/Apache-2.0, Rust, not archived, default
  branch `main`, `pushedAt` 2026-11-13T06:40Z.
- 45 open issues listed, 19 open PRs listed (limit 200). Issue themes: forge
  edge cases (GitHub Enterprise, Gitea, Azure DevOps), `wt list` output and
  JSON schema (last-activity timestamp, JSON Schemas for config), agent
  integration (Claude plugin version matching, desktop app hook gap, Cursor
  plugin, marker staleness), performance on machines with per-exec endpoint
  security cost (#4514), and flaky macOS interrupt tests.
- 378 commits in 52 days, of which a large share are bot dependency bumps and
  agent-maintained doc/test cleanups (merged PR titles such as "Correct stale
  comments..." and "skills(running-tend)...", consistent with the project's
  own agent-run maintenance). Substantive user-facing change arrives in the
  roughly monthly releases.

## Pending Review

New in the 2026-11-13 check:

- `worktrunk-1` `copy-ignored-matured-and-source-available` — v0.81.0
  hardened `wt step copy-ignored` (mtime preserved on Linux so cargo does not
  rebuild, EPERM fallback to copy, `.worktreeinclude` directory patterns).
  Strengthens the existing `cow-build-cache-sharing-for-project-worktrees`
  item below: the mechanism is real and tested at scale, and the source is now
  cloned for the read that item required. (2026-11-13)
- `worktrunk-2` `claude-worktree-hooks-and-cross-repo-entry` — the plugin's
  `WorktreeCreate`/`WorktreeRemove` hooks and `wt-switch-create` skill (enter
  a worktree, including in another repository, then read its `CLAUDE.md` and
  `AGENTS.md`) address the same problem as this workspace's `/start-task`
  `cd` approach and the native `EnterWorktree` limits for project worktrees.
  Also documents a known gap (issue #4776: desktop app skips these hooks).
  Worth a read of `plugins/worktrunk/skills/wt-switch-create/rationale.md`.
  (2026-11-13)
- `worktrunk-3` `hook-semantics-lessons` — v0.81.0 hook changes (foreground
  hooks can prompt; context passed by template args not stdin JSON) and open
  issue #4143 (recovery after a failed `pre-start` reports success on an
  unusable worktree) are concrete failure modes for any lifecycle-hook design.
  Refines the existing `worktree-lifecycle-hooks` item below. (2026-11-13)
- `worktrunk-4` `merge-safety-backups` — failed squash leaves the branch
  untouched; squash backups under `refs/wt-backup/<branch>` with a printed
  restore command. Possible hardening ideas for `merge_pr.sh` / local merge
  paths; relevant only if a local squash path is ever added (see
  `local-squash-merge-one-shot` below). (2026-11-13)
- `worktrunk-5` `agents-md-trim-reference` — an agent-instruction file cut from
  2,763 to 382 lines (121 now) and shared across Claude Code and Codex.
  Informational comparison point for the `AGENTS.md` line budget. (2026-11-13)

Carried from 2026-09-22, still undecided:

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
