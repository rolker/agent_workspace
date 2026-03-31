# VS Code Setup Guide

How to use VS Code with the Agent Workspace. All VS Code configuration
files are gitignored — this guide describes how to generate them locally.

## Quick Start

```bash
code /path/to/workspace
```

## Makefile Tasks

The workspace Makefile wraps common operations. To use them from VS Code,
create `.vscode/tasks.json` at the workspace root:

```jsonc
// .vscode/tasks.json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Build",
      "type": "shell",
      "command": "make build",
      "group": { "kind": "build", "isDefault": true },
      "problemMatcher": "$gcc"
    },
    {
      "label": "Test",
      "type": "shell",
      "command": "make test",
      "group": "test"
    },
    {
      "label": "Lint",
      "type": "shell",
      "command": "make lint",
      "problemMatcher": []
    },
    {
      "label": "Dashboard",
      "type": "shell",
      "command": "make dashboard",
      "problemMatcher": []
    }
  ]
}
```

- **Ctrl+Shift+B** runs the default build task (`make build`)
- **Ctrl+Shift+P > Tasks: Run Task** shows all available tasks

## C++ IntelliSense

If the project uses CMake, enable `compile_commands.json` generation
(`CMAKE_EXPORT_COMPILE_COMMANDS=ON`). Then create
`.vscode/c_cpp_properties.json`:

```jsonc
{
  "configurations": [
    {
      "name": "Default",
      "compileCommands": "${workspaceFolder}/project/build/compile_commands.json",
      "intelliSenseMode": "linux-gcc-x64"
    }
  ],
  "version": 4
}
```

If multiple `compile_commands.json` files exist across build directories,
merge them:

```bash
jq -s 'add' build/*/compile_commands.json > build/compile_commands.json
```

## Python IntelliSense

If the project has a virtual environment or installed packages, configure
extra analysis paths in `.vscode/settings.json`:

```jsonc
{
  "python.analysis.extraPaths": [
    "${workspaceFolder}/project/src"
  ]
}
```

## Claude Code Integration

The [Claude Code VS Code extension](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code)
integrates directly into the editor:

1. Install the **Claude Code** extension from the VS Code marketplace
2. The extension shares configuration and history with the CLI
3. Use `Ctrl+Esc` to toggle focus between the editor and Claude

Both the extension and the CLI terminal can be used simultaneously.
Conversation history is shared — use `claude --resume` in the terminal
to continue an extension conversation.

## Recommended Extensions

- **C/C++** (`ms-vscode.cpptools`) — IntelliSense, debugging
- **Python** (`ms-python.python`) — Python language support
- **Claude Code** (`anthropic.claude-code`) — AI assistant integration
- **XML** (`redhat.vscode-xml`) — For XML files
- **YAML** (`redhat.vscode-yaml`) — For config files

## Working in Worktrees

Open each worktree in its own VS Code window — don't add worktree
folders to the main workspace. VS Code's source control targets whichever
`.git` root it detects first, so mixing worktrees and the main checkout
in one window causes commits to land in the wrong place.

```bash
source .agent/scripts/worktree_enter.sh --issue <N> --type workspace  # or --type project
code .
```

### IntelliSense paths

`compile_commands.json` records absolute paths at build time. If you build
in the main tree but edit in a worktree (or vice versa), IntelliSense won't
resolve headers. Always build in the same context you're editing.

### File watching and search

VS Code follows symlinks by default, which causes duplicate search results
and high file-watcher load in worktrees. Add these to `.vscode/settings.json`:

```jsonc
{
  "files.watcherExclude": {
    "**/build/**": true,
    "**/node_modules/**": true
  },
  "search.exclude": {
    "**/build/**": true,
    "**/node_modules/**": true
  }
}
```
