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
| `sed`, `awk` | Edit |
| `echo >`, heredoc redirection | Write |

These are auto-approved and don't consume permission prompts.

## Claude-Specific Notes

- Makefile `.PHONY` targets (excluding `help`) are available as `/make_*` slash commands
  (e.g., `/make_build`, `/make_test`, `/make_dashboard`). After adding or removing eligible
  `.PHONY` targets, run `make generate-skills` to regenerate the slash commands.

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
