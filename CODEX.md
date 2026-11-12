# Codex CLI - Workspace Rules

Codex reads [`AGENTS.md`](AGENTS.md) natively. Treat that file as the shared
source of truth for workspace rules. This adapter adds only Codex-specific
setup and workflow notes.

## Environment Setup

```bash
# Auto-detect from the active Codex session
source .agent/scripts/set_git_identity_env.sh --detect

# Or specify Codex explicitly
source .agent/scripts/set_git_identity_env.sh --agent codex

# Or pin the exact runtime model yourself
source .agent/scripts/set_git_identity_env.sh --agent codex "<your-model-id>"
```

Use your actual runtime model when you pass a model. The email is derived from
this machine's git email (`git config user.email` in the checkout, any `+suffix`
removed) as `<local>+codex@<domain>`; if it is not set, the script says how to
set it. Source it in the checkout you commit in: the email follows the current
directory's git email, not the repository a later `git -C` targets.

## Worktree Entry

Codex shell/tool calls do not share shell state, so a sourced `worktree_enter.sh`
does not persist across separate commands. Use one of these patterns instead:

```bash
# For commands that can accept an explicit working directory
WT_PATH=$(.agent/scripts/worktree_enter.sh --issue 107 --type workspace --print-path)

# For a single shell command that needs cd + exported worktree vars
eval "$(.agent/scripts/worktree_enter.sh --issue 107 --type workspace --shell-snippet)"
```

Keep using the sourced form when you are working interactively in a single
shell session.

## Skills

Workflow skills live in `.claude/skills/*/SKILL.md`. Despite the directory
name, these are plain markdown instructions and are usable from Codex.

## References

- [`AGENTS.md`](AGENTS.md) - Shared workspace rules
- [`.agent/AI_IDENTITY_STRATEGY.md`](.agent/AI_IDENTITY_STRATEGY.md) - Identity setup
- [`.agent/WORKTREE_GUIDE.md`](.agent/WORKTREE_GUIDE.md) - Worktree patterns
