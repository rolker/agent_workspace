---
name: start-task
description: "Claude Code only — create or enter the worktree for an issue/skill and switch the session into it via the native EnterWorktree tool. Wraps worktree_create.sh / worktree_enter.sh so all project policy (issue checks, branch naming, skill allowlist, --plan-file draft PR, --workflow scaffolding) still applies."
argument-hint: "--issue <N> --type <workspace|project> | --skill <name> --type workspace [--branch <name>] [--parent-issue <N>] [--plan-file <path>] [--workflow <name>] [--repo <name>]"
---

# /start-task

Replace the two-step `worktree_create.sh && source worktree_enter.sh` ceremony with a single command that ends with the session inside the new worktree.

## When to use

- Starting work on a GitHub issue (`/start-task --issue 180 --type workspace`)
- Starting a skill worktree (`/start-task --skill research --type workspace`)
- Re-entering a worktree that already exists (auto-detected; no extra flag needed)

## When not to use

- The session is **already inside a worktree.** EnterWorktree refuses in that case. Exit the current worktree first (run `cd` back to the main tree, or use `ExitWorktree` if the session was entered via that tool).
- You want a worktree without entering it (e.g., creating one for another agent). Call `worktree_create.sh` directly.
- The framework is **not Claude Code.** Codex / Gemini agents stay on the existing `worktree_create.sh` + `worktree_enter.sh --print-path` / `--shell-snippet` flow. This command depends on the native `EnterWorktree` tool.

## Steps

You will receive `$ARGUMENTS` containing the user's flags exactly as typed (e.g. `--issue 180 --type workspace`). Pass them through verbatim.

### 1. Refuse if already in a worktree

Run:

```bash
git rev-parse --show-toplevel 2>/dev/null
```

If the result is a path under `worktrees/workspace/` or `worktrees/project/`, the session is already in a worktree. Stop and tell the user to exit the current worktree first.

Otherwise, the session is in the main tree — proceed.

### 2. Resolve the worktree path (existing → create-new fallback)

Use this exact bash idiom — it's exit-code-checked, so error text from the
"not found" path can't be mistaken for a real path:

```bash
if WT=$(.agent/scripts/worktree_enter.sh $ARGUMENTS --print-path 2>/dev/null); then
    # Worktree already exists for this issue/skill.
    :
elif WT=$(.agent/scripts/worktree_create.sh $ARGUMENTS --print-path-only); then
    # New worktree created; $WT is the path.
    :
else
    # Creation failed. The script already wrote its error to stderr.
    # Report the failure to the user and STOP. Do not call EnterWorktree.
    exit 1
fi
echo "$WT"
```

- The `2>/dev/null` on the enter step suppresses an `Error: No worktree found
  for issue #N` message that the script currently emits when the worktree
  doesn't exist — that's the expected non-error case for our flow, so we
  squelch it.
- Both scripts exit non-zero on real failures; the `elif` chain falls through
  cleanly.
- If creation fails, the agent should surface `worktree_create.sh`'s stderr
  output to the user verbatim (so they can see issue lookup errors, branch
  collisions, etc.).

> Argument compatibility: `worktree_enter.sh` accepts `--issue`/`--skill`/`--type`/`--repo`/`--repo-slug`. `worktree_create.sh` accepts those plus `--branch`/`--parent-issue`/`--plan-file`/`--workflow`. Passing creation-only flags through to the enter step is harmless when the worktree exists — `worktree_enter.sh` rejects unknown flags, which causes the `if` to fail and the `elif` (creation) to run. That's the correct behavior: if the user passed `--plan-file`, they want creation, and trying to enter an existing worktree with creation flags should fall through to the creation script (which itself errors if the worktree already exists).

### 3. Enter the worktree via the native tool

Call **EnterWorktree** with the captured path:

```
EnterWorktree(path=<captured-path>)
```

The `path` parameter (rather than `name`) tells EnterWorktree to switch into a pre-existing worktree of this repo — which is exactly what our scripts produced. EnterWorktree validates the path against `git worktree list` and rejects anything not registered.

### 4. Confirm to the user

After EnterWorktree returns, briefly tell the user:

- Which worktree they're now in (issue/skill, branch)
- Whether it was newly created or pre-existing (you know from step 2)
- The next-step suggestion already printed by the underlying scripts (e.g. "Branch is up to date with origin")

## Exit semantics

- The worktree was created **outside** of EnterWorktree (our scripts called `git worktree add`), so `ExitWorktree` will refuse to remove it. If the user asks to exit:
  - `ExitWorktree(action="keep")` returns the session to the original directory but leaves the worktree on disk. This is the only valid exit action for worktrees entered this way.
  - To actually delete the worktree, use `.agent/scripts/worktree_remove.sh --issue <N> --type <type>` or `make merge-pr PR=<N>` (which removes the worktree as part of the merge flow).

## Why not just call EnterWorktree directly?

EnterWorktree alone would work, but it doesn't know about:

- Issue-first policy (lookup, closed-issue warning, PR-vs-issue check)
- The workspace/project repo distinction (two repos managed in one tree)
- Branch naming conventions (`feature/issue-N`, `skill/<name>-<ts>`) that pre-commit hooks and `merge_pr.sh` depend on
- Parent-issue branching for sub-issues
- Skill worktree allowlist (`research`, `inspiration-tracker`)
- `--workflow` progress.md scaffolding under `.agent/work-plans/issue-N/`
- `--plan-file` draft-PR creation with AI signature
- Cross-repo PR targeting for project-type worktrees

`worktree_create.sh` enforces all of that. This skill keeps the script as the source of truth for policy and uses EnterWorktree only for the session-level switch — which gives smoother CWD handling and proper cache coherence on exit.

## Implementation note

Slash commands in Claude Code are markdown instructions — there is no executable file behind `/start-task`. The agent reads this body, runs the Bash calls in sections 1–2, and invokes EnterWorktree in section 3. The flow is intentionally short and prescriptive so it's reliable across model versions.
