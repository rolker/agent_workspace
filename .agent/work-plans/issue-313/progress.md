---
issue: 313
---

# Issue #313 — cross_model_review.sh: codex/claude/copilot arms have no result validation

## Issue Review
**Status**: complete
**When**: 2026-09-22 12:43 -04:00
**By**: Claude Code Agent (claude-sonnet-5)

**Issue**: #313

### Scope Assessment

**Well-scoped?** Yes — the ask is narrow and mechanical: give the codex,
claude, and copilot arms of `run_agent_sync` in `.agent/scripts/cross_model_review.sh`
the same result-validation contract `_agy_review.sh` already gives the gemini
arm (#288): distinguish "CLI exited 0 with a real review" from "CLI exited 0
with an empty/error/denied/timed-out response". Confirmed in the current tree
(post-PR #318, ADR-0015): the three arms are still bare
`timeout ... "$bin" ... < "$prompt" > "$findings" 2>&1`, success gated on exit
code alone. Three independent per-CLI investigations plus tests is a
reasonable single-PR scope, but it is three CLIs' worth of undocumented
failure-mode research (denied tool, timeout, API error, each CLI's own
markers) — if that research turns up materially different shapes per CLI
(likely, given codex's own comment about full-prompt echo), consider landing
codex first as the concrete, already-diagnosed case and following with
claude/copilot once their failure shapes are confirmed, rather than
discovering all three shapes inside one PR.

**Right repo?** Yes — `.agent/scripts/cross_model_review.sh` and its helpers
are workspace infrastructure.

**Dependencies**: #212 (copilot `-p ""` / `--allow-all-tools` invocation bug)
overlaps directly — the copilot arm here can't be validated against a broken
invocation, so #212 should land first or be folded into this issue's copilot
work rather than treated as a parallel, unrelated fix. #320 (Standard tier +
plan context for gemini/codex) is sequenced after this per the issue's own
"Related" note and needs no changes here. The codex-echo finding in the
issue's comment (`-o/--output-last-message <FILE>`) is pre-researched and
ready to implement; claude and copilot need the same discovery step from
scratch.

### Principle Alignment

| Principle | Status | Notes |
|---|---|---|
| Enforcement over documentation | Action needed | The bug this issue fixes is exactly "validation exists only for one of four agents" — the fix must give codex/claude/copilot the same forced validation gate `_agy_review.sh` gives gemini (own findings-file ownership + truncate-first + fail() helper + `EXIT=` semantics), not just better logging that a human has to notice. |
| Test what breaks | Action needed | This is timing/process-exit/silent-failure territory exactly where the workspace principle calls for tests, and the issue itself asks for "Tests with a mock per CLI" — that must not be treated as optional scope. |
| A change includes its consequences | Watch | `review-code`'s dispatch step and any doc describing "how cross_model_review reports failure" should be checked for per-agent assumptions once codex/claude/copilot start failing with reasons in the findings file instead of always exit-code-only. |
| Improve incrementally | OK | Extends an already-landed pattern (ADR-0015 background jobs + EXIT= lines) rather than restructuring dispatch. |
| Only what's needed | Watch | Three CLIs' worth of per-agent helper scripts (mirroring `_agy_review.sh`) is the natural shape but is real new surface area — confirm each CLI actually needs its own helper file versus a shared validator parameterized by CLI-specific markers, to avoid three near-duplicate scripts. |

### ADR Applicability

| ADR | Triggered | Notes |
|---|---|---|
| 0015 — Parallel sync is the only review dispatch mode | Yes | This issue touches `cross_model_review.sh` and per-agent helpers directly. The ADR's requirement ("failure is per agent — own marker, own `EXIT=` line") is already partially met by the background-job structure from #318; this issue closes the remaining gap where a per-agent "own marker" exists (`EXIT=0`) but doesn't reflect a real validation result for three of the four agents. Any new helper scripts should be added to the ADR's referenced set and to the Script Reference table (see Consequences). |
| 0013 — progress.md entry-type vocabulary | No | Not touched by this change. |

### Consequences

- `AGENTS.md`'s Script Reference table lists `_agy_review.sh` under
  `cross_model_review.sh`; new per-CLI helper scripts (if that's the shape
  chosen) need their own rows, following the pattern already set.
- If the fix changes what a failed agent's findings file/marker looks like,
  `review-code`'s reading of `EXIT=` per agent (ADR-0015's own requirement)
  should be re-checked against the new failure-reason content, even though
  the `EXIT=` contract itself isn't changing.

### Recommendations

- Confirm the copilot arm's fix doesn't collide with #212's separate
  invocation-flag fix — do #212 first, or scope this issue's copilot work to
  include the `-p ""`/`--allow-all-tools` correction so a single PR doesn't
  ship copilot validation logic against a call that's still broken upstream.
- Before writing three near-duplicate `_codex_review.sh` / `_claude_review.sh`
  / `_copilot_review.sh` helpers, check whether the common truncate-first /
  fail() / EXIT-marker skeleton can be factored into a shared function each
  CLI-specific script parameterizes, rather than copy-pasting `_agy_review.sh`
  three times.

### Actions
- [ ] The bug this issue fixes is exactly "validation exists only for one of four agents" — the fix must give codex/claude/copilot the same forced validation gate `_agy_review.sh` gives gemini (own findings-file ownership + truncate-first + fail() helper + `EXIT=` semantics), not just better logging that a human has to notice.
- [ ] This is timing/process-exit/silent-failure territory exactly where the workspace principle calls for tests, and the issue itself asks for "Tests with a mock per CLI" — that must not be treated as optional scope.
- [ ] Confirm the copilot arm's fix doesn't collide with #212's separate invocation-flag fix — do #212 first, or scope this issue's copilot work to include the `-p ""`/`--allow-all-tools` correction so a single PR doesn't ship copilot validation logic against a call that's still broken upstream.
- [ ] Before writing three near-duplicate `_codex_review.sh` / `_claude_review.sh` / `_copilot_review.sh` helpers, check whether the common truncate-first / fail() / EXIT-marker skeleton can be factored into a shared function each CLI-specific script parameterizes, rather than copy-pasting `_agy_review.sh` three times.

## Checkpoint
**Status**: complete
**When**: 2026-09-22 12:48 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: issue-actions
**Decision**: proceed

Proceed to planning. Fold #212 (Copilot -p / --allow-all-tools invocation fix) into this PR, which will close #313 and #212. The plan must give codex/claude/copilot a forced validation gate matching _agy_review.sh's contract, factor the common truncate-first / fail() / marker skeleton into one shared helper rather than three copies, and include a mocked test per CLI (not optional). Copilot's live check waits for quota; its flags come from Usage: copilot [options] [command]

GitHub Copilot CLI - An AI-powered coding assistant.

Start an interactive session to chat with Copilot, or use -p/--prompt for
non-interactive scripting. Copilot can edit files, run shell commands, search
your codebase, and more — all with configurable permissions.

Run `copilot <command> --help` for details on any subcommand.

Options:
  --effort, --reasoning-effort <level>  Set the reasoning effort level (choices:
                                        "none", "low", "medium", "high",
                                        "xhigh", "max")
  --acp                                 Start as Agent Client Protocol server
  --add-dir <directory>                 Add a directory to the allowed list for
                                        file access (can be used multiple times)
  --add-github-mcp-tool <tool>          Add a tool to enable for the GitHub MCP
                                        server instead of the default CLI subset
                                        (can be used multiple times). Use "*"
                                        for all tools.
  --add-github-mcp-toolset <toolset>    Add a toolset to enable for the GitHub
                                        MCP server instead of the default CLI
                                        subset (can be used multiple times). Use
                                        "all" for all toolsets.
  --additional-mcp-config <json>        Additional MCP servers configuration as
                                        JSON string or file path (prefix with @)
                                        (can be used multiple times; augments
                                        config from ~/.copilot/mcp-config.json
                                        for this session)
  --agent <agent>                       Specify a custom agent to use
  --allow-all                           Enable all permissions (equivalent to
                                        --allow-all-tools --allow-all-paths
                                        --allow-all-urls)
  --allow-all-paths                     Disable file path verification and allow
                                        access to any path
  --allow-all-tools                     Allow all tools to run automatically
                                        without confirmation; required for
                                        non-interactive mode (env:
                                        COPILOT_ALLOW_ALL)
  --allow-all-urls                      Allow access to all URLs without
                                        confirmation
  --allow-tool[=tools...]               Tools the CLI has permission to use;
                                        will not prompt for permission
  --allow-url[=urls...]                 Allow access to specific URLs or domains
  --attachment <path>                   Attach a file (image or native document)
                                        to the initial prompt; only valid in
                                        non-interactive mode (can be used
                                        multiple times)
  --autopilot                           Start in autopilot mode
  --available-tools[=tools...]          Only these tools will be available to
                                        the model
  --banner                              Show the startup banner
  --bash-env[=value]                    Enable BASH_ENV support for bash shells
                                        (on|off)
  -C <directory>                        Change working directory before doing
                                        anything else
  --connect[=sessionId]                 Connect directly to a remote session
                                        (optionally specify session ID or task
                                        ID)
  --context <tier>                      Set the context window tier (overrides
                                        persisted setting) (choices: "default",
                                        "long_context")
  --continue                            Resume the most recent session
  --deny-tool[=tools...]                Tools the CLI does not have permission
                                        to use; will not prompt for permission
  --deny-url[=urls...]                  Deny access to specific URLs or domains,
                                        takes precedence over --allow-url
  --disable-builtin-mcps                Disable all built-in MCP servers
                                        (currently: github-mcp-server)
  --disable-mcp-server <server-name>    Disable a specific MCP server (can be
                                        used multiple times)
  --disallow-temp-dir                   Prevent automatic access to the system
                                        temporary directory
  --enable-all-github-mcp-tools         Enable all GitHub MCP server tools
                                        instead of the default CLI subset.
                                        Overrides --add-github-mcp-toolset and
                                        --add-github-mcp-tool options.
  --enable-memory                       Enable memory in prompt mode (disabled
                                        by default)
  --enable-reasoning-summaries          Request reasoning summaries for OpenAI
                                        models
  --excluded-tools[=tools...]           These tools will not be available to the
                                        model
  --experimental                        Enable experimental features
  --extension-sdk-path <directory>      Override the bundled @github/copilot-sdk
                                        injected into extension subprocesses
                                        with a local `copilot-sdk/` folder.
                                        Invalid paths fall back to the bundled
                                        SDK.
  -h, --help                            display help for command
  -i, --interactive <prompt>            Start interactive mode and automatically
                                        execute this prompt
  --log-dir <directory>                 Set log file directory (default:
                                        ~/.copilot/logs/)
  --log-level <level>                   Set the log level (choices: "none",
                                        "error", "warning", "info", "debug",
                                        "all", "default")
  --max-autopilot-continues <count>     Maximum number of continuation messages
                                        in autopilot mode (default: 5)
  --mode <mode>                         Set the initial agent mode (choices:
                                        "interactive", "plan", "autopilot")
  --model <model>                       Set the AI model to use (use 'auto' to
                                        let Copilot pick automatically)
  --mouse[=value]                       Enable mouse support in alt screen mode
                                        (on|off)
  -n, --name <name>                     Set a name for the new session
  --no-ask-user                         Disable the ask_user tool (agent works
                                        autonomously without asking questions)
  --no-auto-update                      Disable downloading CLI update
                                        automatically (disabled by default in CI
                                        environments)
  --no-bash-env                         Disable BASH_ENV support for bash shells
  --no-color                            Disable all color output
  --no-custom-instructions              Disable loading of custom instructions
                                        from AGENTS.md and related files
  --no-experimental                     Disable experimental features
  --no-mouse                            Disable mouse support in alt screen mode
  --no-remote                           Disable remote control of your session
                                        from GitHub web and mobile
  --output-format <format>              Output format: 'text' (default) or
                                        'json' (JSONL, one JSON object per line)
                                        (choices: "text", "json")
  -p, --prompt <text>                   Execute a prompt in non-interactive mode
                                        (exits after completion)
  --plain-diff                          Disable rich diff rendering (syntax
                                        highlighting via diff tool specified by
                                        git config)
  --plan                                Start in plan mode
  --plugin-dir <directory>              Load a plugin from a local directory
                                        (can be used multiple times)
  -r, --resume[=value]                  Resume from a previous session
                                        (optionally specify existing session ID,
                                        task ID, ID prefix, or name; name
                                        matching is exact, case-insensitive)
  --remote                              Enable remote control of your session
                                        from GitHub web and mobile
  -s, --silent                          Output only the agent response (no
                                        stats), useful for scripting with -p
  --screen-reader                       Enable screen reader optimizations
  --secret-env-vars[=vars...]           Environment variable names whose values
                                        are stripped from shell and MCP server
                                        environments and redacted from output
                                        (e.g.,
                                        --secret-env-vars=MY_KEY,OTHER_KEY)
  --session-id <id>                     Resume an existing session or task by
                                        ID, or set the UUID for a new session
  --share[=path]                        Share session to markdown file after
                                        completion in non-interactive mode
                                        (default: ./copilot-session-<id>.md)
  --share-gist                          Share session to a secret GitHub gist
                                        after completion in non-interactive mode
  --stream <mode>                       Enable or disable streaming mode
                                        (choices: "on", "off")
  -v, --version                         show version information
  --yolo                                Enable all permissions (equivalent to
                                        --allow-all-tools --allow-all-paths
                                        --allow-all-urls)

Commands:
  completion <shell>                    Generate a shell completion script
  help [topic]                          Display help information
  init                                  Initialize Copilot instructions
  login [options]                       Authenticate with Copilot
  mcp                                   Manage MCP servers
  plugin                                Manage plugins
  update [channel]                      Download the latest version
  version                               Display version information

Help Topics:
  billing      AI Credit Usage
  commands     Interactive Mode Commands
  config       Configuration Settings
  environment  Environment Variables
  logging      Logging
  monitoring   Monitoring with OpenTelemetry
  permissions  Permissions
  providers    Custom Model Providers (BYOK)

Examples:
  # Start interactive mode
  $ copilot

  # Start interactive mode and automatically execute a prompt
  $ copilot -i "Fix the bug in main.js"

  # Execute a prompt in non-interactive mode (exits after completion)
  $ copilot -p "Fix the bug in main.js" --allow-all-tools

  # Enable all permissions with a single flag
  $ copilot -p "Fix the bug in main.js" --allow-all
  $ copilot -p "Fix the bug in main.js" --yolo

  # Start with a specific model
  $ copilot --model gpt-5.2

  # Resume the most recent session
  $ copilot --continue

  # Resume a previous session using session picker
  $ copilot --resume

  # Resume a specific session by ID
  $ copilot --resume=<session-id>

  # Name a new session
  $ copilot --name="my feature"

  # Start a new session with a specific UUID
  $ copilot --session-id=0cb916db-26aa-40f2-86b5-1ba81b225fd2

  # Resume or attach to an existing session or task by ID
  $ copilot --session-id=<session-or-task-id>

  # Resume a session by name
  $ copilot --resume="my feature"

  # Resume a session by ID prefix (7+ hex chars)
  $ copilot --resume=0cb916d

  # Resume with auto-approval
  $ copilot --allow-all-tools --resume

  # Allow access to additional directory
  $ copilot --add-dir /home/user/projects

  # Allow multiple directories
  $ copilot --add-dir ~/workspace --add-dir /tmp

  # Disable path verification (allow access to any path)
  $ copilot --allow-all-paths

  # Allow all git commands except git push
  $ copilot --allow-tool='shell(git:*)' --deny-tool='shell(git push)'

  # Allow all file editing
  $ copilot --allow-tool='write'

  # Allow all but one specific tool from MCP server with name "MyMCP"
  $ copilot --deny-tool='MyMCP(denied_tool)' --allow-tool='MyMCP'

  # Allow GitHub API access (defaults to HTTPS)
  $ copilot --allow-url=github.com

  # Deny access to specific domain over HTTPS
  $ copilot --deny-url=https://malicious-site.com
  $ copilot --deny-url=malicious-site.com

  # Allow all URLs without confirmation
  $ copilot --allow-all-urls

  # Initialize Copilot instructions for a repository
  $ copilot init

Learn More:
  Use `copilot <command> --help` for more information about a command.
  Read the documentation at https://docs.github.com/copilot/how-tos/copilot-cli (-p <text>, --allow-all-tools, -s/--silent, --output-format).

## Plan Authored
**Status**: complete
**When**: 2026-09-22 12:53 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-313/plan.md` at `8c75011`

One shared skeleton (`_review_helper_common.sh`, sourced) plus three thin per-CLI helpers (`_codex_review.sh`, `_claude_review.sh`, `_copilot_review.sh`) give codex/claude/copilot the same forced validation gate `_agy_review.sh` already gives gemini; `_agy_review.sh` itself is left as-is (stream-json parsing has no shared analog). Codex uses `-o <file>` to avoid the stdout prompt-echo; claude uses `--output-format json` for a parseable result object; copilot fixes #212 by passing `-p <text>` as an argument with `--allow-all-tools`/`-s` instead of stdin. PR closes #313 and #212; #320 is explicitly out of scope.
