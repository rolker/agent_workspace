---
name: analyze-permissions
description: Analyze tool-use logs and propose permission allowlist additions grouped by safety tier.
---

# Analyze Permissions

## Usage

```
/analyze-permissions [--since YYYY-MM-DD] [--min-count N] [--show-covered]
```

- `--since`: Only analyze log entries after this date (default: all entries)
- `--min-count`: Minimum occurrence count to include in report (default: 2)
- `--show-covered`: Include already-allowed patterns in the report

## Overview

**Lifecycle position**: Utility — run periodically to review and update the
permission allowlist based on actual tool usage.

Reads the tool-use log produced by the `PreToolUse` logging hook, extracts
Bash command patterns, compares them against the current `.claude/settings.json`
allowlist, and produces a report with proposed additions grouped by safety tier.

**Data flow**: `log-tool-use.sh` hook captures data -> this skill analyzes it

## Steps

### 1. Locate and validate inputs

**Tool-use log**: `~/.claude/tool-use-log.jsonl`
- If the file doesn't exist or is empty, report "No tool-use log found.
  Enable the PreToolUse logging hook first." and stop.

**Current settings**: Read `.claude/settings.json` from the workspace root
(not the worktree — use `$WORKTREE_MAIN_TREE/.claude/settings.json` if in a
worktree, otherwise `.claude/settings.json`).

Extract the current `permissions.allow` and `permissions.deny` arrays.

### 2. Extract Bash commands from the log

Filter log entries where `tool == "Bash"`. For each entry:

1. Parse `input_summary` as JSON and extract the `command` field
2. If `input_summary` is truncated (ends abruptly at 200 chars), note it as
   partial but still extract the command prefix

Apply `--since` filter if specified: compare `ts` field against the cutoff date.

### 3. Normalize commands into allowlist patterns

For each Bash command, extract the **base pattern** — the command name and
subcommand that would appear in an allowlist rule. Normalization rules:

**Simple commands** (single executable + args):
- `git log --oneline -5` -> `Bash(git log *)`
- `gh issue view 42 --json title` -> `Bash(gh issue view *)`
- `make dashboard` -> `Bash(make dashboard *)`
- `jq '.foo' file.json` -> `Bash(jq *)`

**Git/gh subcommand depth**: Use 2 tokens for git/gh (`git log`, `gh pr view`),
1 token for everything else (`make`, `jq`, `shellcheck`).

**Exception — `gh api`**: Use 3 tokens (`gh api <path-prefix>`) to preserve
the endpoint path. Also check for write flags (`-X POST`, `-X PUT`,
`-X PATCH`, `-X DELETE`, `-f`, `--field`, `--input`) — if any are present,
classify the command as Tier 3 (write operation) regardless of the endpoint.
Examples:
- `gh api repos/owner/repo/compare/main...HEAD` -> `Bash(gh api repos/*/compare/*)` (Tier 1)
- `gh api repos/owner/repo/issues -f title="..."` -> `Bash(gh api *)` (Tier 3, write detected)

**Path-based commands** (scripts):
- `/home/user/daddy_camp/.agent/scripts/dashboard.sh --quick` -> `Bash(.agent/scripts/dashboard.sh *)`
- `.agent/scripts/worktree_create.sh --issue 42` -> `Bash(.agent/scripts/worktree_create.sh *)`
- Normalize absolute paths: strip any prefix up to and including the workspace
  root or worktree root, keeping the relative path from `.agent/` onward.

**Source commands**:
- `source .agent/scripts/worktree_enter.sh --issue 42` -> `Bash(source .agent/scripts/worktree_enter.sh *)`
- `source /abs/path/.agent/scripts/foo.sh` -> `Bash(source .agent/scripts/foo.sh *)`

**Compound commands** (pipes, `&&`, `;`):
- Extract **all commands** in the pipeline/chain. Normalize each independently.
- Classify the compound at the tier of its **most dangerous component** — e.g.,
  `echo foo && rm -rf /` is Tier 4 (destructive), not Tier 1 (read-only).
- Flag compound commands separately as "compound commands that may need manual
  review" since they can't be precisely allowlisted with a single pattern.

**Commands to skip**:
- `cd` (directory changes, not meaningful for allowlisting)
- Commands inside heredocs or string arguments
- Empty commands

### 4. Match against current allowlist

For each normalized pattern, check if it's already covered by an existing
allow rule. A pattern is "covered" if any allow rule would match it:
- `Bash(git log *)` covers `git log --oneline`, `git log -5`, etc.
- Exact match or glob match

Also check the deny list — if a pattern matches a deny rule, flag it
as "denied (correct)" rather than proposing to allow it.

### 5. Classify uncovered patterns into safety tiers

Group uncovered patterns into tiers:

**Tier 1 — Read-only** (safe to auto-allow):
- `git` read commands: `log`, `show`, `diff`, `status`, `branch`, `remote`,
  `worktree list`, `rev-parse`, `ls-files`, `describe`, `tag`, `stash list`
- `gh` read commands: `issue view`, `issue list`, `pr view`, `pr list`,
  `pr diff`, `pr checks`, `repo view`, `api` (only when no write flags
  detected — see `gh api` exception in step 3)
- Read-only tools: `jq`, `shellcheck`, `wc`, `which`, `ls`, `pwd`, `cat`,
  `head`, `tail`, `file`, `stat`

**Tier 2 — Workspace scripts** (safe within this workspace):
- `.agent/scripts/*.sh` — workspace automation
- `make` targets — workspace task runner
- `source .agent/scripts/*.sh` — environment setup
- `git-bug` read commands: `bug`, `version`, `user`, `bridge`, `--help`

**Tier 3 — Standard write operations** (review before allowing):
- `git add`, `git commit`, `git push` (without force), `git stash`,
  `git checkout`, `git switch`, `git merge`, `git rebase`
- `gh pr create`, `gh pr merge`, `gh issue create`, `gh issue comment`
- `gh api` with write flags (`-X POST/PUT/PATCH/DELETE`, `-f`, `--field`)
- `git-bug` write commands: `add`, `comment`, `label`, `status`

**Tier 4 — Destructive / dangerous** (suggest for deny list):
- `git push --force`, `git push -f`, `git push --force-with-lease`
- `git reset --hard`
- `git clean`
- `rm -rf`, `rm -r`
- `git checkout -- .`, `git restore .`
- Any command with `sudo`

**Unclassified**: Commands that don't fit a tier. Present them for manual
review with their frequency count.

### 6. Produce the report

```markdown
## Permission Analysis Report

**Log file**: ~/.claude/tool-use-log.jsonl
**Entries analyzed**: <N> total, <M> Bash commands
**Date range**: <first entry date> to <last entry date>
**Current allowlist**: <N> allow rules, <N> deny rules

### Tier 1 — Read-Only (safe to auto-allow)

| Pattern | Count | Example command |
|---------|-------|-----------------|
| `Bash(git describe *)` | 12 | `git describe --tags` |

### Tier 2 — Workspace Scripts (safe within this workspace)

| Pattern | Count | Example command |
|---------|-------|-----------------|
| `Bash(.agent/scripts/build.sh *)` | 8 | `.agent/scripts/build.sh` |

### Tier 3 — Standard Write Operations (review before allowing)

| Pattern | Count | Example command |
|---------|-------|-----------------|
| `Bash(git commit *)` | 45 | `git commit -m "feat: ..."` |

### Tier 4 — Suggest for Deny List

| Pattern | Count | Example command | Why |
|---------|-------|-----------------|-----|
| `Bash(sudo *)` | 1 | `sudo apt install ...` | Privilege escalation |

### Compound Commands (manual review)

| First command | Count | Example |
|---------------|-------|---------|
| `git stash && git checkout` | 3 | `git stash && git checkout main` |

### Already Covered

<only shown if --show-covered flag>

| Pattern | Allow rule | Count |
|---------|-----------|-------|
| `Bash(git log *)` | `Bash(git log *)` | 89 |

### Denied (correctly blocked)

| Pattern | Deny rule | Count |
|---------|----------|-------|
| `Bash(git push --force *)` | `Bash(git push --force *)` | 0 |

### Summary

- **<N> patterns** already covered by allowlist
- **<N> new patterns** found across <N> tiers
- **Recommendation**: <1-2 sentences about what to add>
```

Omit any section with no entries.

## Guidelines

- **Read-only** — this skill does not modify settings.json. It reports findings
  and the user decides what to add.
- **Conservative classification** — when uncertain about a command's safety,
  classify it one tier higher (more restrictive). It's better to require manual
  review than to suggest auto-allowing something dangerous.
- **Frequency matters** — commands used once might be one-offs. Focus
  recommendations on patterns with `--min-count` or more occurrences (default 2).
- **Compound commands are tricky** — `git add . && git commit -m "..."` can't
  be precisely allowlisted with a single pattern. Flag these for manual review
  rather than proposing an overly broad pattern.
- **Path normalization is critical** — the same script appears with absolute
  paths from different worktrees. Normalize all workspace paths to relative
  `.agent/scripts/...` form.
- **Settings layering context** — remind the user that `.claude/settings.json`
  is shared (committed), while `.claude/settings.local.json` is per-developer
  (gitignored). Tier 1-2 additions belong in the shared file; Tier 3 additions
  may be better in the local file depending on the team's trust model.
