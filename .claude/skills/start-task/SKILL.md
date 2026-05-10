---
name: start-task
description: "Claude Code only — create or enter the worktree for an issue/skill and switch the session into it via the native EnterWorktree tool. Wraps worktree_create.sh / worktree_enter.sh so all project policy (issue checks, branch naming, skill allowlist, --plan-file draft PR, --workflow scaffolding) still applies."
argument-hint: "--issue <N> --type <workspace|project> | --skill <name> --type workspace [--branch <name>] [--parent-issue <N>] [--plan-file <path>] [--workflow <name>]"
---

# /start-task

Replace the two-step `worktree_create.sh && source worktree_enter.sh` ceremony with a single command that ends with the session inside the new worktree.

## When to use

- Starting work on a GitHub issue (`/start-task --issue 180 --type workspace`)
- Starting a skill worktree (`/start-task --skill research --type workspace`)
- Re-entering a worktree that already exists (auto-detected; no extra flag needed)

## When not to use

- The session is **already inside a worktree.** EnterWorktree refuses in that case. Step 1 below detects this and stops; tell the user to exit the current worktree first.
- You want a worktree without entering it (e.g., creating one for another agent). Call `worktree_create.sh` directly.
- The framework is **not Claude Code.** Codex / Gemini agents stay on the existing `worktree_create.sh` + `worktree_enter.sh --print-path` / `--shell-snippet` flow. This command depends on the native `EnterWorktree` tool.
- **Values containing embedded whitespace** (e.g. `--branch "feature/foo bar"`). Slash-command argument forwarding flattens user-supplied quotes; the inner whitespace will not be preserved across the boundary. Call `worktree_create.sh` directly for those cases.

## Argument handling

`$ARGUMENTS` contains the user's flags exactly as typed, as a flat string. The bash idioms below pass it **unquoted** so the shell word-splits it into separate flag tokens — this is what makes the typical multi-flag case (`--issue 188 --type workspace`) work. The invocation block is bracketed with `set -f` / `set +f` to suppress glob expansion: without the bracket, values containing `*`, `?`, or `[` (e.g. `--branch main*`, `--plan-file /tmp/*.md`) would expand against the cwd before reaching the script.

Two limitations of slash-command argument forwarding worth knowing:

- **Embedded whitespace in a value is not preserved.** `/start-task --branch "feature/foo bar"` flattens to `--branch feature/foo bar` at the slash-command boundary, then word-splits into three tokens. There is no recovery mechanism at this layer. For values with embedded whitespace, call `worktree_create.sh` directly. (Listed in "When not to use" above.)
- **Shell metacharacters in values** (`;`, `$`, backticks) reach the underlying scripts as literal characters. With `set -f` disabling glob expansion and bash not re-expanding variable contents, direct injection at the slash-command boundary isn't the concern; the actual risk is downstream — these characters can have unexpected meanings to the scripts that consume the values (as branch names, file paths, or in error messages). For values that need metacharacters, call `worktree_create.sh` directly with proper shell quoting.

## Steps

### 1. Refuse if already in a worktree (or not in the workspace at all)

The check below uses `git rev-parse --git-dir` vs `--git-common-dir`: in the main tree they're equal; in a linked worktree they differ. This is the most reliable git-native test for "am I in a linked worktree", regardless of where the worktrees live on disk.

```bash
GITDIR=$(git rev-parse --git-dir 2>/dev/null) || {
    echo "Not in a git repository. /start-task must be invoked from the workspace root." >&2
    exit 1
}
COMMON=$(git rev-parse --git-common-dir 2>/dev/null)

# Resolve to absolute paths so the comparison is robust.
GITDIR_ABS=$(cd "$GITDIR" && pwd -P)
COMMON_ABS=$(cd "$COMMON" && pwd -P)

if [ "$GITDIR_ABS" != "$COMMON_ABS" ]; then
    echo "Already inside a linked worktree:" >&2
    echo "  $(git rev-parse --show-toplevel)" >&2
    echo "Exit it first (cd back to the main workspace), then re-run /start-task." >&2
    exit 1
fi
```

If the test passes, the session is in the main tree — proceed.

### 2. Move to the workspace root

The script invocations below use repo-relative paths. Ensure `pwd` is the workspace root so `.agent/scripts/...` resolves regardless of the user's invocation directory:

```bash
cd "$(git rev-parse --show-toplevel)" || exit 1
```

### 3. Resolve the worktree path (existing → create-new fallback)

Exit-code-checked idiom — error text from the "not found" path goes to stderr, so `2>/dev/null` suppresses it. The `worktree_enter.sh` "Unknown option" path still writes to stdout (caught harmlessly by the elif chain when it overwrites `$WT`); see #194 for routing that to stderr too.

```bash
# Disable glob expansion for the unquoted $ARGUMENTS expansion below.
# Word-splitting still happens (so `--issue 188 --type workspace` becomes
# 4 args), but glob characters in values (e.g. `--branch main*`,
# `--plan-file *.md`) won't expand against the cwd. Restored in every
# branch exit.
set -f
if WT=$(.agent/scripts/worktree_enter.sh $ARGUMENTS --print-path 2>/dev/null); then
    set +f
    # Worktree already exists for this issue/skill.
    :
elif WT=$(.agent/scripts/worktree_create.sh $ARGUMENTS --print-path-only); then
    set +f
    # New worktree created; $WT is the path.
    :
else
    set +f
    # Creation failed. The script already wrote its error to stderr.
    # Surface the error to the user verbatim and STOP. Do not call EnterWorktree.
    #
    # Recovery: a partial creation may have left a worktree on disk even on
    # non-zero exit (e.g., set -e fires after `git worktree add` succeeds but
    # before bookkeeping finishes). Run `git worktree list` and, if anything
    # under worktrees/<type>/ matches, offer the user
    # `.agent/scripts/worktree_remove.sh --issue <N> --type <type>` (or
    # `--skill <name>`) to clean up before retrying.
    exit 1
fi
```

- The `2>/dev/null` on the enter step suppresses the "No worktree found" message — that's the expected non-error case for our flow.
- Both scripts exit non-zero on real failures; the `elif`/`else` chain handles each.
- If `worktree_create.sh` accepts an unknown flag (e.g., a typo), it errors with `Unknown option <flag>` on stderr (in `--print-path-only` mode, set up by an early pre-scan in the script) and exits non-zero.

> Argument compatibility: `worktree_enter.sh` accepts `--issue`/`--skill`/`--type`/`--repo`/`--repo-slug`. `worktree_create.sh` accepts those plus `--branch`/`--parent-issue`/`--plan-file`/`--workflow`, but does **not** accept `--repo` (only `--repo-slug`). For multi-project disambiguation, use `--repo-slug`. Creation-only flags (`--branch`, `--parent-issue`, `--plan-file`, `--workflow`) cause `worktree_enter.sh` to reject the call as "Unknown option", which makes the `if` branch fail and the `elif` (creation) branch run. That's the correct behavior: those flags only make sense at creation time.

### 4. Enter the worktree via the native tool

Call **EnterWorktree** with the captured path:

```
EnterWorktree(path="$WT")
```

The `path` parameter (rather than `name`) tells EnterWorktree to switch into a pre-existing worktree of this repo. EnterWorktree validates the path against `git worktree list` and rejects anything not registered.

**If EnterWorktree fails:** the worktree exists on disk but the session can't enter it. Tell the user the worktree path, and offer two recovery options: (a) manually `cd <path>` and continue without the harness-level worktree session, or (b) run `.agent/scripts/worktree_remove.sh --issue <N> --type <type>` (or `--skill <name>`) to clean up. Do not retry EnterWorktree silently.

### 5. Confirm to the user

After EnterWorktree returns successfully, briefly tell the user:

- Which worktree they're now in (issue/skill, branch)
- Whether it was newly created or pre-existing (you know from step 3 — the `if` branch hit means existing, `elif` means new)
- Any setup messages the underlying scripts printed (e.g., "Branch is up to date with origin")

## Manual verification

After changes to this skill, run these checks from a fresh main-tree session to confirm behaviour. End-to-end automation would require a Claude Code SDK test harness; declined as out-of-scope (issue #188).

1. **Typical case** — `/start-task --issue <test-N> --type workspace`. Expected: step 3's `elif` fires; new worktree created at `worktrees/workspace/issue-workspace-<test-N>/`; `EnterWorktree` succeeds; session lands in the new worktree.

2. **Skill case** — `/start-task --skill research --type workspace`. Same flow with a skill-worktree path (`worktrees/workspace/skill-research-<TS>/`).

3. **Re-entry case** — exit the worktree from check 1 (`ExitWorktree(action="keep")`), then re-run the same `/start-task --issue <test-N> --type workspace`. Expected: step 3's `if` branch fires (existing worktree found); no new creation; `EnterWorktree` returns to it.

4. **Glob safety (structural check)** — inspect step 3 of this skill body and confirm `set -f` precedes the `if` block and `set +f` is restored in each of the three branches. Without these, an invocation containing values like `--branch main*` or `--plan-file *.md` would glob-expand against the cwd before reaching the script. The bracket makes the failure mode structurally impossible.

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

Slash commands in Claude Code are markdown instructions — there is no executable file behind `/start-task`. The agent reads this body, runs the Bash calls in sections 1–3, and invokes EnterWorktree in section 4. The flow is intentionally short and prescriptive so it's reliable across model versions.
