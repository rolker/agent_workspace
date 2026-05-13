# Claude Code — Workspace Rules

@AGENTS.md

## Environment Setup

```bash
source .agent/scripts/set_git_identity_env.sh "Claude Code Agent" "roland+claude-code@rolker.net" "<your-model-id>"
```

Replace `<your-model-id>` with your actual model ID from your system prompt
(e.g., `claude-opus-4-6`, `claude-sonnet-4-6`). The 3-arg form skips all
detection and uses exactly what you provide — do NOT edit `framework_config.sh`.

## Tool Mapping

The AGENTS.md "Tool Usage" section applies to all frameworks. In Claude Code,
the dedicated tools are:

| Instead of | Use |
|------------|-----|
| `ls`, `find` | Glob |
| `grep`, `rg` | Grep |
| `cat`, `head`, `tail` | Read |
| `sed -i ...` | Edit |
| `sed -n 'SCRIPT' <file>` | Read (offset/limit) or Grep |
| `awk` (any) | Edit |
| `echo >`, heredoc redirection | Write |

These are auto-approved and don't consume permission prompts.

**Enforced by hook**: `.claude/hooks/block-bash-tool-mapping.sh` blocks
Bash calls that match the simple cases — `cat <file>`, `head [-N] <file>`,
`tail [-N] <file>`, `find [path] ...` (any filesystem enumeration without
an operational flag, including bare `find` which defaults to `.`),
`sed -n 'SCRIPT' <file>` (inline scripts, including `-e SCRIPT`; external
`-f script.sed` passes through), and `sed -i ...` (including combined
short-flag clusters like `-ni`). Pipes, redirects, heredocs, and
operational flags (`head -c`, `tail -f`, `find -exec/-delete/-mtime/...`,
plain `sed 's/x/y/'` without `-i` or `-n`) pass through unchanged. Blocks
are logged to `~/.claude/tool-mapping-blocks.jsonl` so we can measure how
often the hook fires.

## Claude-Specific Notes

- Makefile `.PHONY` targets (excluding `help`) are available as `/make_*` slash commands
  (e.g., `/make_build`, `/make_test`, `/make_dashboard`). After adding or removing eligible
  `.PHONY` targets, run `make generate-skills` to regenerate the slash commands.

- **Worktree entry**: prefer `/start-task --issue <N> --type <workspace|project>` (or
  `--skill <name> --type workspace`) over the two-step `worktree_create.sh` +
  `source worktree_enter.sh` flow. The slash command wraps the policy scripts and
  `cd`s the session into the worktree in one invocation. `cd` is used uniformly
  across `--type workspace`, `--type project`, and `--skill` modes — the native
  `EnterWorktree` tool would reject project worktrees (those live in a separate
  git repo from the workspace), so `cd` is the one mechanism that covers every
  mode. All policy still applies (issue checks, branch naming, `--plan-file`,
  `--workflow`, skill allowlist). Codex / Gemini agents use per-command shells
  and stay on the script flow — `/start-task` is Claude Code only.

## References

- [`AGENTS.md`](AGENTS.md) — Shared workspace rules (all agents)
- [`README.md`](README.md) — Workspace purpose and goals
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — System design
- [`docs/decisions/`](docs/decisions/) — Architecture Decision Records
- [`.agent/WORKTREE_GUIDE.md`](.agent/WORKTREE_GUIDE.md) — Detailed worktree patterns
- [`.agent/AI_IDENTITY_STRATEGY.md`](.agent/AI_IDENTITY_STRATEGY.md) — Multi-framework identity
- [`.agent/WORKFORCE_PROTOCOL.md`](.agent/WORKFORCE_PROTOCOL.md) — Multi-agent coordination
- [`.agent/knowledge/`](.agent/knowledge/) — Development patterns, CLI best practices, skill workflows
- [`.agent/templates/`](.agent/templates/) — Issue and PR templates
