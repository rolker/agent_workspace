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

## Plan Review
**Status**: complete
**When**: 2026-09-22 13:00 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: needs-work

**Issue**: #313 — cross_model_review.sh: codex/claude/copilot arms have no result validation (#288 failure class still undetected)
**Plan**: `.agent/work-plans/issue-313/plan.md` at `8c75011`
**Branch**: `feature/issue-313`

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | One PR, four new scripts, one wiring point, one test suite. Folding #212 into the copilot helper is right — the copilot arm cannot be validated against a broken invocation. |
| Issue alignment | Good | Covers the ask (per-CLI failure shapes + forced gate + a mocked test per CLI) and the owner's Checkpoint (one shared skeleton, gate matching `_agy_review.sh`, tests not optional). |
| File targeting | Needs work | Misses `cross_model_review.sh`'s own availability precheck (line 467, gemini-only) and its header/timeout prose (lines ~31-36, 882). The existing `AGENTS.md` `cross_model_review.sh` row also describes the per-agent invocation and changes here. |
| Consequences | Needs work | Truncate-first helpers make `run_agent_job`'s "partial output above, if any" message false for these three agents; not listed. |
| Principle alignment | Concern | "Only what's needed": the copilot argv form breaks the documented invariant at `cross_model_review.sh:203` and reintroduces #274. "Test what breaks": the child-kill/TERM-forwarding property is not in the plan. |
| ADR compliance | Good | ADR-0015's per-agent background-job / `exec` / `EXIT=` structure is untouched; the closing consequence bullet (ADR lines 109-110) is correctly listed for update. |
| ROS conventions | N/A | Workspace plan. |

### Findings

1. **[Approach — copilot, blocking]** `-p "$(cat "$prompt")"` puts the whole
   prompt (diff included) into one argv string. Linux caps a *single*
   argument at MAX_ARG_STRLEN (128 KiB) regardless of `ARG_MAX` (2 MiB on
   this host), and #313's own comment records a 79 KB prompt for a modest
   PR; there is no diff-size cap in the script. `cross_model_review.sh:203`
   states the invariant explicitly — "Agents read the prompt from stdin, so
   prompt size is not bounded by argv" — and the plan silently breaks it.
   The failure mode is a hard `Argument list too long` exec failure, i.e.
   exactly #274 back again, on the largest (Deep-tier) reviews where it
   matters most. The plan's parenthetical only considers `$()` whitespace
   stripping, not the size limit. Resolve before implementation: `copilot
   --help` on the installed 1.0.61 still documents only `-p, --prompt
   <text>`, but #212 verified `copilot -p "" --allow-all-tools < prompt`
   (stdin) on 1.0.48 — the plan must either keep that stdin form (and say
   how it is confirmed on 1.0.61 given copilot quota is exhausted), or, if
   argv is truly the only route, add an explicit prompt-size guard that
   fails with a readable reason instead of exec-failing.

2. **[Approach — shared skeleton, blocking]** `_review_helper_common.sh` is
   sourced, so a missing or broken common file fails the helper *before*
   `rh_truncate_findings` can run, leaving the previous run's review in the
   findings file under a fresh `--- Review failed ---` marker. That is the
   stale-findings hazard `_agy_review.sh:65-72` truncates first to prevent —
   the #288 class in a different coat. Each helper must truncate the
   findings file inline before sourcing, or the `source` must be guarded by
   a failure path that truncates and writes a reason. Related: the
   per-agent availability precheck at `cross_model_review.sh:467` covers
   only `AGY_REVIEW_HELPER`; step 5 chmods the new helpers but never
   extends that check, so a lost exec bit or a missing common file surfaces
   as an opaque exec error rather than "helper missing or not executable".

3. **[Approach — signals, blocking]** The plan mentions traps only for
   temp-dir cleanup (`rh_mktemp_dir`). `_agy_review.sh` additionally runs
   the CLI as a background child with `wait` and INT/TERM/HUP traps that
   kill it (lines 111-141), so a TERM from `timeout -k` or from the
   parent's `cleanup_jobs` actually reaches the CLI. Insert a helper layer
   without that and an interrupted or timed-out run leaves codex / claude /
   copilot running for up to `AGENT_TIMEOUT`, burning quota — the exact
   regression `run_agent_job`'s comment (lines 857-868) and the existing
   "codex was killed" assertion in `test_agents_timeout` guard against. Put
   the spawn+wait+trap pattern in the shared skeleton as a function, and
   keep an explicit kill assertion per CLI.

4. **[Approach — structure, non-blocking]** On the split: three thin
   helpers is defensible — each is still `exec`'d, so the "the job's PID is
   the CLI's" discipline holds exactly as it does for gemini, and a sourced
   common file never needs to be exec'd. But the plan should state the
   trade it made against one `_cli_review.sh <agent> ...` dispatcher, which
   is also exec'able and gives one file instead of four, one AGENTS.md row
   instead of four, one resolution variable and one availability precheck
   instead of three, and eliminates finding 2's source-before-truncate
   ordering problem outright. Extra test surface is roughly neutral (the
   per-CLI cases are the same either way). Either justify the four-file
   shape in one sentence or take the dispatcher.

5. **[Approach — copilot output, medium]** The helper passes both `-s`
   ("output only the agent response (no stats)") and a `sed -n
   '/^Changes$/q;p'` footer strip. If `-s` works the sed is dead code; if
   it ever fires it silently truncates any review whose body contains a
   bare `Changes` line — entirely plausible in an adversarial review, and a
   silent content loss with no marker. Pick `-s`; if the strip is kept,
   anchor it to the real footer block (`Changes`/`Requests`/`Tokens`
   together, at end of output), not a bare word.

6. **[Approach — claude, medium]** The plan validates claude's JSON result
   fields but never pins headless permission behavior, which is the very
   mechanism #288 was about (agy auto-denying a tool and returning an empty
   response at exit 0). `claude --help` offers `--permission-prompts none`
   ("anything that would prompt is denied automatically") and
   `--permission-mode`; unpinned, the claude arm's denial behavior varies
   by version and default, and a denial shows up only as "empty response"
   with no reason, whereas `_agy_review.sh` reports `denied_actions` by
   name. Pin the flag and surface any denial information the JSON carries.

7. **[Testing, medium]** "Keep the existing 196 assertions green" understates
   the work: the generic `make_mock_agent`
   (`test_cross_model_review.sh:1282-1300`) consumes stdin and writes the
   review to stdout, relying on the arm's `> "$findings"` redirect that this
   change removes. Every parallel-dispatch test that uses it for
   codex/claude/copilot must be reworked, including the argv-contract
   assertion near line 1366 (which asserts today's `codex exec` / `-p`
   shapes) and the timeout / interrupt kill assertions. List these as
   changed tests, not just "extend `make_mock_agent`". The `MOCK_ARGV_DIR`
   hook is the right place for the #212 invocation regression test.

8. **[Consequences, low]** Add to Files to Change:
   `cross_model_review.sh`'s header block (lines ~31-36, which documents
   the bare `<cli> -p < prompt` invocation for the three agents) and
   `run_agent_job`'s non-gemini timeout message (line 882, "partial output
   above, if any" — never true once the helper truncates first), plus the
   existing `AGENTS.md` `cross_model_review.sh` row.

9. **[Verification, low — confirmatory]** Re-checked the plan's `--help`
   claims on this host: codex-cli 0.155.1 has `-o, --output-last-message
   <FILE>` and `codex exec [PROMPT]` reads stdin when no prompt argument is
   given (help also notes stdin is appended as a `<stdin>` block if a prompt
   arg *is* given — so keep passing none). claude has `--output-format json`
   ("single result"). copilot 1.0.61 has `-p, --prompt <text>`, `-s`,
   `--allow-all-tools`, `--output-format text|json`. All as the plan states.
   One addition: say explicitly that codex's `-o` file and each helper's
   logs live under the helper's `mktemp -d` inside `$TMPDIR`, so the parent
   scratch root (`AGENT_TMP_ROOT`) and `run_script_tests.sh`'s leak sweep
   both cover them.

### Summary

The shape is right and the CLI contracts check out against the installed
binaries, but three items must be resolved before implementation: the
copilot argv regression (#274), truncate-before-source ordering in the
shared skeleton, and TERM forwarding to the CLI child. Findings 5-8 are
corrections to make while editing rather than reasons to re-plan.

### Recommended Actions

- [ ] Resolve the copilot prompt channel: keep `-p "" --allow-all-tools < prompt` (stdin, per #212) or add an explicit argv-size guard; do not silently break `cross_model_review.sh:203`'s no-argv-bound invariant
- [ ] Truncate the findings file before sourcing `_review_helper_common.sh` (or guard the source with a truncating failure path)
- [ ] Extend `cross_model_review.sh:467`'s availability precheck to the three new helpers (and the common file)
- [ ] Put the CLI-as-background-child + `wait` + INT/TERM/HUP kill pattern in the shared skeleton; assert per CLI that a timeout/interrupt kills the mock
- [ ] Drop the `^Changes$` sed in favour of `-s`, or anchor the strip to the full footer block
- [ ] Pin claude's headless permission flag (`--permission-prompts none` or equivalent) and surface denials in the failure reason
- [ ] State the four-file split vs a single `_cli_review.sh <agent>` dispatcher in one sentence, or take the dispatcher
- [ ] Add to Files to Change: `cross_model_review.sh` header (~31-36) and line 882 message; existing `AGENTS.md` `cross_model_review.sh` row; list the existing dispatch tests being reworked

## Checkpoint
**Status**: complete
**When**: 2026-09-22 13:05 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: revise

Revise with all eight round-1 plan-review action items folded in, and take the single-dispatcher shape: one exec'd `_cli_review.sh <agent> <bin> <prompt> <findings> [<timeout>]` with a per-agent case (codex/claude/copilot; gemini stays on _agy_review.sh), so truncate-first runs before anything can fail, one availability precheck, one AGENTS.md row. Copilot must read the prompt from stdin (`-p "" --allow-all-tools < prompt`, the #212-verified form) or carry an explicit size guard; the helper runs its CLI as a waited-on child and forwards INT/TERM/HUP like _agy_review.sh; no double footer strip; pin claude's headless permission flag; name the mock/test rework and the missing doc targets.

## Plan Authored
**Status**: complete
**When**: 2026-09-22 13:09 -04:00
**By**: Claude Code Agent (claude-sonnet-5)
**Plan**: `.agent/work-plans/issue-313/plan.md` at `2c24f22`

Revision folding in round-1 plan review (49e5b16, needs-work) and the owner's Checkpoint decision (single-dispatcher shape). Replaced the sourced-skeleton/three-helper design with one exec'd `_cli_review.sh <agent> <bin> <prompt> <findings> [<timeout>]` (per-agent case for codex/claude/copilot; gemini unchanged on `_agy_review.sh`). Truncates findings before any guard; copies `_agy_review.sh`'s spawn/wait/INT-TERM-HUP-forward pattern. Copilot reverts to the #212-verified stdin form (`-p "" --allow-all-tools -s < prompt`) with a 100 KiB size guard as belt-and-braces pending re-confirmation on 1.0.61 (quota exhausted). Claude pins `--permission-mode plan --permission-prompts none`. Dropped the double footer-strip idea. Extended `cross_model_review.sh`'s availability precheck and named the test-mock rework explicitly. PR still closes #313 and #212; #320 out of scope.

## Plan Review
**Status**: complete
**When**: 2026-09-22 13:20 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: ready

**Issue**: #313 — cross_model_review.sh: codex/claude/copilot arms have no result validation (#288 failure class still undetected)
**Plan**: `.agent/work-plans/issue-313/plan.md` at `2c24f22`
**Branch**: `feature/issue-313`
**Round**: 2 (round 1 at 49e5b16, needs-work)

### Evaluation

| Dimension | Verdict | Notes |
|---|---|---|
| Scope | Good | Single dispatcher, one wiring point, one test suite, six doc targets. Smaller than the round-1 four-file design. |
| Issue alignment | Good | Owner's second Checkpoint (revise; single `_cli_review.sh <agent>`) is followed literally, and all eight round-1 action items are folded in. |
| File targeting | Good | Round-1 gaps closed: precheck (~467), header comment (~31-36), timeout message (~882), existing `AGENTS.md` row, and the named test rework. `agent_wait_patterns.md` added conditionally. |
| Consequences | Good | Now stated inline and each one traced to a file in the table. |
| Principle alignment | Good | Forced gate before any guard (Enforcement over documentation); kill/timeout/empty/marker cases all asserted (Test what breaks); one file instead of four (Only what's needed). |
| ADR compliance | Good | ADR-0015's `exec` / `timeout -k` / background-job / `EXIT=` structure untouched; closing bullet still listed for update. |
| ROS conventions | N/A | Workspace plan. |

### Round-1 items — status

| # | Round-1 item | Status in 2c24f22 |
|---|---|---|
| 1 | Copilot argv regression (#274) | Resolved — approach 3 uses `-p "" --allow-all-tools -s < "$prompt"`, the #212-verified stdin form, never argv; the open question records that 1.0.61 re-confirmation waits on quota. |
| 2 | Truncate-before-source ordering | Resolved and made moot — nothing is sourced; approach 1 makes `: > "$FINDINGS_FILE"` or `fail` the first statement, matching `_agy_review.sh:69-72`. |
| 3 | TERM forwarding to the CLI child | Resolved — approach 2 copies `_agy_review.sh:105-141`: EXIT trap after `mktemp -d`, INT/TERM/HUP armed *before* the spawn, CLI as a background job that is `wait`ed on. |
| 4 | Four files vs one dispatcher | Resolved — owner took the dispatcher; gemini correctly stays on `_agy_review.sh`. |
| 5 | Double footer strip | Resolved — `-s` output used as-is; the `sed '/^Changes$/q'` idea is dropped with the reason recorded. |
| 6 | Pin claude's headless permission flag | Addressed; see suggestion 1 on the choice of `--permission-mode plan`. |
| 7 | Mock/test rework named | Resolved — the table names `make_mock_agent`'s rework, per-CLI mocks (codex `-o` + transcript, claude JSON, copilot stdin + `-s`), the ~1366 argv assertion, the #212 stdin-contract and size-guard tests, and a per-CLI kill assertion. |
| 8 | Missing doc targets | Resolved — header (~31-36), message (~882), existing `AGENTS.md` row, plus `agent_wait_patterns.md` as a conditional. |

Verified against this host: `claude --help` has both `--permission-mode`
(choices include `plan`) and `--permission-prompts none` ("anything that
would prompt is denied automatically; the permission mode still decides
everything else"); codex-cli 0.155.1 has `-o/--output-last-message` and
reads stdin when no `[PROMPT]` arg is passed; copilot 1.0.61 has `-p`,
`-s`, `--allow-all-tools`.

### Findings

1. **[Approach — claude flags, suggestion]** `--permission-prompts none`
   is the right pin and is sufficient on its own: it auto-denies anything
   that would prompt, which is the exact `_agy_review.sh` behavior being
   mirrored. Adding `--permission-mode plan` is a different lever —
   plan mode is a *workflow* mode whose intended terminal move is
   presenting a plan for approval, not answering the prompt. In `-p`
   mode that risks a turn that exits 0 with `subtype: success` and a
   `.result` that is a plan rather than a review, which every validation
   gate in this plan would pass. Recommend dropping `--permission-mode
   plan` (default mode + `--permission-prompts none`), or, if it is kept,
   asserting in the claude mock test that the review text — not a plan
   wrapper — is what lands in the findings file. Not blocking: this is
   one flag, decidable during implementation against a real (non-quota)
   claude run.

2. **[Approach — copilot size guard, suggestion]** The 100 KiB guard is
   described as failing the copilot review before invoking the CLI. On
   the stdin path there is no size limit, so this converts a prompt that
   *would work* into a hard failure — and it bites precisely on the large
   Deep-tier PRs where an extra reviewer is most valuable. The regression
   it defends against (a future edit moving the prompt back to argv) is
   better caught by the test that already asserts the stdin invocation
   contract. Recommend one of: make the test the enforcement and drop the
   runtime fail; or keep the check but emit a warning note into the
   findings file and proceed; or raise the bound to just under
   MAX_ARG_STRLEN (128 KiB) so it only ever fires where argv would have
   failed anyway. Decide during implementation and say which in the PR.

3. **[Approach — precheck scope, nit]** Approach 4 says the availability
   precheck also requires `CLI_REVIEW_HELPER` present + executable. Keep
   that conditional on the agent being codex/claude/copilot, the way the
   existing check is conditional on `gemini` — a missing `_cli_review.sh`
   must not mark a gemini-only run unavailable.

### Summary

The revision answers all eight round-1 items, and the single-dispatcher
shape removes the ordering hazard that made item 2 blocking. No design
flaw remains. Ready for implementation; the two suggestions above are
one-flag / one-threshold decisions to make while writing the code, and
should be recorded in the PR description rather than re-planned.

### Recommended Actions

- [ ] Drop `--permission-mode plan` in favour of `--permission-prompts none` alone, or add a claude-mock assertion that the findings file holds a review rather than a plan
- [ ] Decide the copilot size guard's form (test-enforced invariant, warn-and-proceed, or a 128 KiB bound) and record the choice in the PR description
- [ ] Scope the `CLI_REVIEW_HELPER` availability check to codex/claude/copilot, matching the existing gemini-only `AGY_REVIEW_HELPER` check

## Checkpoint
**Status**: complete
**When**: 2026-09-22 13:18 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: plan
**Decision**: proceed

Proceed to implementation with the round-2 suggestions folded in: no --permission-mode plan for claude (--output-format json + --permission-prompts none only); Copilot prompt-size guard at 128 KiB (the kernel MAX_ARG_STRLEN bound) with the stdin contract test as the real enforcement; the CLI_REVIEW_HELPER availability precheck scoped to codex/claude/copilot. Main merged into the branch first so implementation runs under the post-#314 dispatched-implement rules.

## Implementation
**Status**: complete
**When**: 2026-09-22 13:36 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-313 at 0aad5bd
**Plan**: `.agent/work-plans/issue-313/plan.md` at `2c24f22`

Implemented the approved plan with the owner Checkpoint's three
adjustments (no `--permission-mode plan`; 128 KiB copilot guard with the
stdin-contract test as the real enforcement; `CLI_REVIEW_HELPER`
precheck scoped to codex/claude/copilot).

**What landed**

- `.agent/scripts/_cli_review.sh` (new, exec'd): truncates the findings
  file as its first statement, then guards; per-agent case for
  codex (`exec -o <file>`, transcript to a log kept only in failure
  reasons), claude (`-p --output-format json --permission-prompts none`
  with `.is_error` / `.subtype` / non-empty `.result` validated) and
  copilot (`-p "" --allow-all-tools -s`, prompt on stdin, 128 KiB
  guard). Empty response, non-zero exit and quota / rate-limit / auth
  markers are failures with the reason in the file. The CLI runs as a
  waited-on background child with INT/TERM/HUP armed before the spawn;
  temp files live under the caller's TMPDIR and are removed on every
  trappable exit.
- `.agent/scripts/cross_model_review.sh`: the codex/claude/copilot arms
  exec the helper under the existing `exec env TMPDIR=... timeout -k`
  discipline (no stdout redirect); availability precheck extended and
  scoped; header, `EXIT=` documentation and the exit-124 message updated.
- `.agent/scripts/tests/test_cross_model_review.sh`: `make_mock_agent`
  reworked into per-CLI mocks reproducing each CLI's real output shape;
  12 new test functions; 196 -> 298 assertions, all green, and
  `run_script_tests.sh` passes all 23 suites with no temp leaks.
- Docs: `AGENTS.md` (new `_cli_review.sh` row + updated
  `cross_model_review.sh` row), ADR-0015 (closing consequence bullet and
  the bound clause), `.claude/skills/review-code/SKILL.md`
  (result-reading and findings-collection notes),
  `.agent/knowledge/agent_wait_patterns.md` (inner half of the wait).
- `plan.md` synced inline, with an `## Implementation Notes` section for
  the rationale-bearing pivots.

**Deviations / decisions made while writing**

- A bug the tests caught: a background child's stdin is `/dev/null`
  unless the redirect is on the backgrounded command itself. The first
  draft put `< "$prompt"` on the call to the spawn helper, which would
  have handed every CLI an empty prompt — silently. Fixed and pinned by
  `test_cli_prompt_reaches_every_cli_on_stdin`.
- `EXIT=` for these three agents is now the helper's `1` on failure, not
  the CLI's own status (gemini's shape since #288). One existing
  assertion changed; the script header, ADR-0015 and the review-code
  skill say so.
- Error-marker scanning is asymmetric: the full marker set against the
  CLI's stderr/transcript, but against the *result* only when it is
  short and unstructured, so a review that legitimately discusses rate
  limits is not failed. Both halves asserted.
- `run_agent_sync`'s `*)` arm routes through the helper (which rejects an
  unknown agent with a reason) instead of keeping a bare `-p` fallback.

Not done, by instruction: no real agy/codex/claude/copilot run (quota),
so copilot's stdin form is still only verified against #212's 1.0.48
check plus the mock contract; nothing pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 13:45 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: changes-requested

**Branch**: feature/issue-313 at `7effe51`
**Base**: main
**Depth**: Deep (reason: enforcement-path script + cross-model dispatch wiring; cross-model input supplied by the host)
**Must-fix**: 6 | **Suggestions**: 4
**Round**: 1 | **Ship**: continue — round 1: 6 must-fix; first round always re-reviews after fixes

Tests: `test_cross_model_review.sh` 298/298 pass; `run_script_tests.sh` 23/23 suites pass (86s). Cross-model input read from disk (gemini complete, codex marked FAILED by the helper's own false positive — a confirmed must-fix, findings recovered from its log excerpt). Copilot flag options read from `copilot --help` (1.0.61); no Copilot review was run (quota exhausted), so the least-privilege recommendation is from help text plus #212's earlier run.

### Findings
- [x] (must-fix) codex's merged stdout transcript echoes the prompt+diff, so the error-marker scan fails valid reviews — confirmed live on this very branch; scan a channel that cannot echo the prompt (separate stderr file) or drop the scan for codex — `.agent/scripts/_cli_review.sh:223`
- [x] (must-fix) remove the 128 KiB copilot prompt guard: the prompt goes over stdin, so the bound can only reject large reviews that would otherwise work — it re-imposes exactly the #212 ceiling the stdin path removed; delete its pinning test too — `.agent/scripts/_cli_review.sh:270-274` (test `:2015-2037`)
- [x] (must-fix) `--allow-all-tools` is a privilege escalation on an untrusted diff; recommended replacement: `-p "" -s --available-tools='' --disable-builtin-mcps --no-ask-user --disallow-temp-dir` (no tools are needed — the diff is in the prompt); if the empty set is rejected, a single read-only tool plus `--deny-tool='shell'` / `--deny-tool='write'`; update the argv assertion — `.agent/scripts/_cli_review.sh:280` (test `:2009`)
- [x] (must-fix) the TERM/HUP trap kills the CLI child and exits without waiting, so the outer `timeout -k` never escalates to SIGKILL and the EXIT trap removes TMP_DIR under a still-running CLI; wait for the child (with the helper's own bounded escalation to `kill -9`) before exiting — `.agent/scripts/_cli_review.sh:167-168`
- [x] (must-fix) the same TERM-trap gap exists in the gemini helper and must be fixed with it — `.agent/scripts/_agy_review.sh:112-113`
- [x] (must-fix) the codex mock echoes only `head -n 2` of the prompt, so no test transcript ever contains diff body — this is why the live false positive was not caught; add a full-prompt-echo knob and a case with a marker word (`unauthorized`, `overloaded`) in the diff — `.agent/scripts/tests/test_cross_model_review.sh:1333`
- [x] (suggestion) `marker_in_result`'s length/heading heuristic gives false positives on concise list-formatted findings and false negatives on `#`-headed CLI errors; prefer structured status or an exact known-error match — `.agent/scripts/_cli_review.sh:148-153`
- [x] (suggestion) claude's error payload (`.error` / `.error.message`) is never read, so an `is_error=true` or bad-subtype failure reports no underlying cause when `.result` is empty — `.agent/scripts/_cli_review.sh:253-258`
- [x] (suggestion) the shared empty-response reason excerpts `$STDERR_FILE`, which codex never writes (its stderr is merged into stdout), so a codex whitespace-only result carries no transcript at all — `.agent/scripts/_cli_review.sh:292`
- [x] (suggestion) a copilot quota/auth error printed to stdout that exceeds 400 chars or carries a markdown heading passes every gate; `marker_in_log` covers only stderr — `.agent/scripts/_cli_review.sh:284-288`

## Implementation
**Status**: complete
**When**: 2026-09-22 14:01 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-313 at ca7f87c
**Plan**: `.agent/work-plans/issue-313/plan.md` at `2c24f22`
**Round**: address-findings round 1 (review at `45c4b0e`, branch `7effe51`)

All ten findings resolved, none deferred. One commit: `ca7f87c`.

1. **codex transcript scan (must-fix)** — codex now writes stderr to its
   own file; only that is scanned for error markers. The transcript
   replays the prompt, which is why a diff mentioning a rate limit
   failed this branch's own review. The `-o` file's emptiness and the
   exit code remain the primary signals, and failure reasons excerpt the
   transcript (codex's only diagnostic channel).
2. **128 KiB copilot guard (must-fix)** — deleted, with its pinning
   test. Replaced by `test_cli_no_prompt_size_ceiling`: a 128 KiB + 1
   prompt is reviewed by all three CLIs and arrives whole on stdin.
3. **Copilot least privilege (must-fix)** — `-p "" -s
   --available-tools='' --disable-builtin-mcps --no-ask-user` replaces
   `--allow-all-tools`; the argv assertion now pins the exact form and
   asserts `--allow-all-tools` is never passed. Note: the dispatch
   instruction's flag list omitted the review's `--disallow-temp-dir`,
   so it is NOT included — worth adding at the one live confirmation
   when Copilot quota returns, which the call-site comment already flags
   (along with the `--deny-tool='shell'` / `--deny-tool='write'`
   fallback if an empty tool set is rejected).
4. + 5. **TERM/HUP escalation (must-fix, both helpers)** —
   `_cli_review.sh` and `_agy_review.sh` now kill the child, wait for it,
   and escalate to SIGKILL after `REVIEW_KILL_ESCALATION` seconds
   (default 5, deliberately below the caller's 10s `timeout -k` grace).
   A watchdog rather than a `kill -0` poll, because an unreaped child
   still answers `kill -0`. Tested per helper with a TERM-ignoring mock:
   helper exits 143, the CLI is gone, no temp dir survives.
6. **codex mock fidelity (must-fix)** — added `MOCK_CODEX_ECHO_FULL`
   (full prompt echoed into the transcript, as the real CLI does) and
   `MOCK_CODEX_IGNORE_TERM`. New test: a diff containing `overloaded`,
   `unauthorized` and `usage limit` is reviewed successfully, while the
   same run with a marker on codex's stderr still fails.
7. + 10. **Result-error detection (suggestions)** — the length/heading
   heuristic is gone. The rule is now an opener match: the first
   non-empty line must announce an error (`Error:`, `## Failure`) or be
   a known error sentence, and a marker must appear somewhere. Tested
   both directions — a long, `#`-headed quota error fails; concise
   list-formatted findings and a one-line review naming a rate limit
   pass.
8. **claude `.error` payload (suggestion)** — read as string or object
   (`.message`) and included in the `is_error` / bad-subtype reasons,
   with the stderr excerpt appended. Tested with an empty `.result` for
   both payload shapes.
9. **Empty-response excerpt (suggestion)** — each arm sets its real
   diagnostic channel (`DIAG_FILE`/`DIAG_LABEL`); codex's empty-result
   reason now carries its transcript instead of a stderr file it never
   writes.

Tests: `test_cross_model_review.sh` 329/329 (was 298); mock sleeps now
run in 0.1s slices so a SIGKILLed mock leaves no orphan.
`run_script_tests.sh` 23/23 suites in 81s, no temp leaks. Pre-commit
green (shellcheck included). plan.md gained a "Round 1 of
address-findings" block in Implementation Notes covering the guard
removal, the least-privilege pivot and the other seven items.

No real agy/codex/claude/copilot prompt was run (quota); nothing pushed.

## Implementation
**Status**: complete
**When**: 2026-09-22 14:21 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-313 at fb8b6d9
**Plan**: `.agent/work-plans/issue-313/plan.md` at `2c24f22`
**Round**: implementation round 2 (live gemini + codex re-run of `ca7f87c`)

Codex was failed again by the helper's own text scan. Root cause: codex
prints its entire transcript on stderr as well as stdout — prompt, tool
calls and each tool's output (this run, a `jq: error` line from a
command codex itself ran). Neither channel is a diagnostics channel, so
text cannot be a failure cause on any of them.

**The rule now implemented and documented** (helper header + plan
Implementation Notes): only a non-zero exit status, a missing or empty
result, or a structured error field (claude `.is_error` / `.error`) may
FAIL a run. Error text only EXPLAINS a failure those signals already
established, by choosing the reason line. `ERROR_OPENER_RE`,
`result_is_error_only` and `marker_in_log`-as-cause are deleted;
`marker_note` replaces them. The residual gap — a CLI that exits 0 with
a quota message as its whole answer is passed through as a review — is
stated in the header and in the review-code skill's result-reading note,
because every attempt to close it discarded real reviews (three designs,
three live false positives; the table is in the plan).

Per arm: codex fails on a non-zero exit or an empty/missing `-o` file
only; claude on structured fields only; copilot on a non-zero exit or
empty `-s` output only.

**Also fixed from the same run**

- claude non-object JSON (codex must-fix 1): `jq -e .` accepts `"oops"`,
  `[]`, `1`; `.is_error` then aborted jq and the helper died under
  `set -e` leaving an EMPTY findings file. Now `type == "object"` is
  required before indexing, every field read is guarded, and assignment
  uses `printf -v` so a failure reaches `fail()` instead of exiting a
  subshell.
- `cleanup_jobs` (codex must-fix 2): reaps the job shells before
  removing `AGENT_TMP_ROOT`, bounded by `CLEANUP_REAP_TIMEOUT` (8s).
  Found while testing: each job's own TERM trap exited immediately,
  which is what told the parent the job was finished — it now waits for
  its helper too.
- Escalation vs the caller's grace (codex must-fix 3 / gemini 4): both
  helpers refuse to start unless `AGENT_KILL_AFTER` >
  `REVIEW_KILL_ESCALATION` (exit 2, reason in the findings file);
  `AGENT_KILL_AFTER` is exported to them. Both zero is the one legal
  equal case, so the documented `AGENT_KILL_AFTER=0` stays usable when
  paired with `REVIEW_KILL_ESCALATION=0`.
- Watchdog (gemini 4): no longer waited on — a subshell sleeping in
  `sleep` defers the TERM we send it, so waiting cost the full window on
  every clean exit. It re-checks liveness before `kill -9`, so it cannot
  hit a recycled PID.
- Re-entrancy (gemini 6): `terminate_child` disarms INT/TERM/HUP on
  entry in both helpers and clears the child PID. `_agy_review.sh`
  already cleared `AGY_PID` after the normal reap (gemini 5).
- jq preflight (gemini 8): missing jq marks claude unavailable with a
  reason instead of failing every claude run.
- Copilot (gemini 7): no code change; the call-site comment now names
  BOTH `-p ""` and `--available-tools=''` as pending one live
  confirmation when quota returns, with the fallback for each.

**Tests**: 329 -> 369 assertions, all green. New: error-text-explains-
never-causes per CLI (exit 0 with a quota answer passes; the same marker
with a non-zero exit fails and picks the reason line; a transient
`[WARN] overloaded` does not fail a completed review), review text never
reclassified ("# Error Handling in auth.py" and concise list findings
both accepted), non-object JSON reported rather than crashing, TERM
returns in under 3s with a 5s window, jq preflight, cleanup reap
ordering under a TERM-ignoring CLI, and the kill-grace refusal.
`run_script_tests.sh` 23/23 suites, no temp leaks. Pre-commit green
including shellcheck.

Commit: `fb8b6d9`. No real CLI prompt was run; nothing pushed.

## Implementation
**Status**: complete
**When**: 2026-09-22 14:35 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Branch**: feature/issue-313 at bb815ea
**Plan**: `.agent/work-plans/issue-313/plan.md` at `2c24f22`
**Round**: implementation round 3 (third live gemini + codex run of `fb8b6d9`; both completed, codex EXIT=0)

The validation rule holds — the third live run is the first where both
reviewers completed, so the remaining must-fix was the round-2 cleanup
code itself, which both reviewers converged on. All three items fixed in
`cross_model_review.sh`:

1. **Bounded reap became an unbounded wait.** The poll expired and then
   `wait "$pid"` ran anyway, so a wedged job blocked the exit path
   forever and `AGENT_TMP_ROOT` was never removed — worse than the race
   round 2 fixed. `wait` now runs only for a job confirmed finished;
   otherwise the job is SIGKILLed, a warning on stderr names it, and
   cleanup proceeds to remove the root.
2. **Reap budget derived, not hard-coded.** `CLEANUP_REAP_TIMEOUT`
   defaults to `REVIEW_KILL_ESCALATION + CLEANUP_REAP_MARGIN` (3s), and
   an explicit value is refused at startup (exit 2, message naming both
   knobs) unless it exceeds the escalation. The old fixed 8s silently
   broke for any escalation above it — the parent would drop the temp
   root while a helper was still legitimately escalating.
3. **Liveness no longer depends on `/proc`.** `job_finished` now reads
   bash's own job table first (`jobs -pr` lists only RUNNING jobs, so an
   exited-but-unreaped child — which still answers `kill -0` — is
   correctly reported finished), keeping the `/proc` state read as a
   cross-check where `/proc` exists. On macOS/BSD or in a stripped
   container every cleanup previously burned the whole budget.

**Tests**: 369 -> 381 assertions, all green.
- `test_cleanup_survives_a_wedged_job`: a stub `_cli_review.sh` that
  ignores INT/TERM/HUP (in a copied scripts dir) makes its job shell
  genuinely unreturnable — the only way a correctly-configured budget
  can expire. The interrupted run still exits 143 in ~2s and still
  removes the temp root.
- `test_cleanup_budget_follows_the_escalation`: a 10s escalation (past
  the old 8s constant) completes cleanly, and `CLEANUP_REAP_TIMEOUT=3`
  with `REVIEW_KILL_ESCALATION=10` exits 2 with both knobs named.
- `test_job_finished_without_proc`: `job_finished` is extracted from the
  script and run with `awk` stubbed out to force the non-`/proc` path,
  asserting both directions (a running job reported running, an
  exited-but-unreaped job reported finished).

`run_script_tests.sh` 23/23 suites, no temp leaks. Pre-commit green
including shellcheck. Commit `bb815ea`. No real CLI prompt; nothing
pushed.

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-09-22 14:39 -04:00
**By**: Claude Code Agent (claude-opus-5)
**Verdict**: approved

**Branch**: feature/issue-313 at `24eddc0`
**Base**: main
**Depth**: Deep (reason: enforcement-path script + cross-model dispatch wiring; live gemini + codex runs both COMPLETED through the helper this round)
**Must-fix**: 0 | **Suggestions**: 2
**Round**: 2 | **Ship**: recommended — no must-fix findings; remaining suggestions can be applied or tracked

All ten round-1 items verified resolved in code, each with a pinning test: the codex transcript scan is gone (the rule is now "only non-zero exit, empty/missing result, or claude's structured `.is_error`/`.error` may fail a run; error text only picks the reason line"), the 128 KiB copilot guard is gone, `--allow-all-tools` is replaced by `-p "" -s --available-tools='' --disable-builtin-mcps --no-ask-user`, both helpers' TERM path now waits with a bounded SIGKILL escalation validated to fit inside `AGENT_KILL_AFTER` (default 10 > 5), `cleanup_jobs` reaps on a derived, bounded budget before dropping the shared temp root, claude requires a JSON *object* before indexing and reads `.error`/`.error.message`, and jq is a preflight for claude rather than a per-run failure. The live false positive has a direct regression test (`MOCK_CODEX_ECHO_FULL=1` with `overloaded`/`unauthorized` inside the reviewed diff, plus a `jq: error ... usage limit` line on codex's stderr). The residual gap — a CLI exiting 0 with a quota message as its whole answer is reported as a completed review — is deliberate, documented in the helper header and called out in the skill's result-reading note.

Tests: `test_cross_model_review.sh` 381/381 pass; `run_script_tests.sh` 23/23 suites pass (84s). Copilot's `--available-tools=''` and `-p ""` still await one live 1.0.61 confirmation (quota); the fallback is written into the helper.

### Findings
- [ ] (suggestion) `job_finished`'s /proc fallback reads process state with `awk '{print $3}'`, which lands on the wrong field when a process's comm contains a space; prefer the text after the last `)`. The `jobs -pr` path is primary, so this only bites where bash's job table is empty — `.agent/scripts/cross_model_review.sh:752-757`
- [ ] (suggestion) two comments justify the guarded jq extraction by what would happen "under `set -e`", but the helper runs `set -uo pipefail` with no `-e`; the guard is right, the stated mechanism is not (a bare jq failure would leave an empty value, not kill the helper) — `.agent/scripts/_cli_review.sh:335-354`

## Checkpoint
**Status**: complete
**When**: 2026-09-22 14:45 -0400
**By**: Claude Code Agent (claude-fable-5-1)
**Decided-by**: owner
**After**: publish
**Decision**: publish

Publish. Pre-push review approved at round 2 (12b263f), 0 must-fix; three live Gemini+Codex runs through the helper, the last completing for both agents. Main merged in before the push.

## Integrated Review
**Status**: complete
**When**: 2026-09-23 09:54 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #327 at `4d7bb94`
**Sources**: 2 (Local Review (Pre-Push) round 2 @ `24eddc0`, CI rollup @ `4d7bb94`)
**Cross-source confirmations**: 0
**CI**: all-pass

Copilot's only review at `4d7bb94` is the quota notice ("unable to review ... quota limit") with 0 inline comments, and its `copilot-pull-request-reviewer` check-run shows `failure` for the same reason; neither is a review source and neither is counted. All real CI checks (Lint, Validate Adapter Contract, Validate Documentation, ros-manifest tests) pass at `4d7bb94`. 0 GitHub inline or conversation comments.

The pre-push review was at `24eddc0`; `24eddc0..4d7bb94` touches neither `.agent/scripts/cross_model_review.sh` nor `.agent/scripts/_cli_review.sh` (only the main merge and progress bookkeeping), so its round-2 approval and both open suggestions carry forward unchanged to the PR head. Both re-verified in the current code. Neither is must-fix: finding 1's worst case is a bounded wait then SIGKILL (not a hang or leak), finding 2 is comment accuracy only.

### Findings
- [x] (suggestion, Local Review R2) `job_finished`'s /proc fallback reads process state with `awk '{print $3}'`, which lands on the wrong field when a process's comm contains a space; prefer the text after the last `)`. Still present at lines 755-757. Failure mode is bounded: a misread state reports the job running, so cleanup waits out `CLEANUP_REAP_TIMEOUT` and SIGKILLs — `.agent/scripts/cross_model_review.sh`
- [x] (suggestion, Local Review R2) two comments (lines 337 and 351) justify the guarded jq extraction by what would happen "under `set -e`", but the helper runs `set -uo pipefail` (line 86) with no `-e`; the guard is right, the stated mechanism is not (an unguarded jq failure would leave an empty value, not kill the helper) — `.agent/scripts/_cli_review.sh`

### False positives
- (Copilot) "unable to review this pull request because the user who requested the review has reached their quota limit" (review and failed check-run at `4d7bb94`) — not a review: it asserts nothing about the code, and the quota exhaustion is known (Sept 2026); excluded from sources and from the CI verdict.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 10:04 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: findings
**Decision**: address

Fix both, then merge (Recommended)

## Implementation
**Status**: complete
**When**: 2026-09-23 10:13 -04:00
**By**: Claude Code Agent (claude-opus-5-5)

**PR**: #327 at `b1d2748`
**Addressed**: Integrated Review at `4d7bb94` (2026-09-23 09:54 -04:00)
**Commits**: 939e370, b1d2748

### Actions
- [x] `job_finished`'s /proc fallback misread the state for a comm containing a space — new `proc_state` reads the word after the last `)`; new test `test_job_finished_proc_comm_with_space` covers a running "a Z b" and a zombie "x y" — `.agent/scripts/cross_model_review.sh` (`job_finished`), `.agent/scripts/tests/test_cross_model_review.sh`
- [x] Two comments justified the guarded jq extraction by `set -e`, which the helper does not use; restated as "an unguarded jq failure would leave an empty value" (comment-only) — `.agent/scripts/_cli_review.sh:337,351`

Tests: `test_cross_model_review.sh` 385 passed / 0 failed; `run_script_tests.sh` all 23 suites passed.

## Local Review
**Status**: complete
**When**: 2026-09-23 10:18 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Verdict**: approved

**PR**: #327 at `debb083`
**Depth**: Standard (reason: fix-round re-review of enforcement scripts, scoped to 4d7bb94..debb083; adversarial pass inline with a mutation check)
**Must-fix**: 0 | **Suggestions**: 1

Verified: `test_cross_model_review.sh` 385 passed / 0 failed; shellcheck --severity=warning clean on the three changed scripts; `_cli_review.sh:86` confirms `set -uo pipefail` (no `-e`), so the corrected comments are accurate. Mutation check (new test's probe against the 4d7bb94 awk `$3` code): the running "a Z b" half fails the old code (RUNNING-REPORTED-FINISHED), so the test does guard the regression; the zombie "x y" half passes against both old and new code because bash has already reaped the child before `job_finished` runs (see finding).

### Findings
- [ ] (suggestion) the zombie half of `test_job_finished_proc_comm_with_space` is vacuous: the probe's own bash reaps "x y" during the foreground `sleep 1`, so `job_finished` returns via `kill -0` and never reads /proc; spawn it under a parent that does not reap (e.g. `sh -c '"$1" 0.2 & echo $! > "$2"; exec sleep 5'`), which a scratch mutation run confirmed makes the old code fail with DEAD-REPORTED-ALIVE and the new code pass — `.agent/scripts/tests/test_cross_model_review.sh:2375-2378`

## Integrated Review
**Status**: complete
**When**: 2026-09-23 10:20 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a71d4c0e6954f823b, resume 1 of 3)

**PR**: #327 at `8b51699`
**Sources**: 2 (Local Review (PR mode) @ `debb083`, CI rollup @ `8b51699`)
**Cross-source confirmations**: 0
**CI**: pending

Fix-round re-triage. Only progress bookkeeping separates `debb083` (the reviewed commit) from the head `8b51699`, so the PR-mode review applies at head. Both findings from the previous Integrated Review (at `4d7bb94`) are resolved in code and verified here: `proc_state` in `.agent/scripts/cross_model_review.sh` now takes the word after the last `) ` of `/proc/<pid>/stat` (939e370), and the two comments in `.agent/scripts/_cli_review.sh` no longer claim `set -e` (b1d2748). CI at `8b51699` has not settled: Validate Documentation and the ros-manifest tests pass; Lint (pre-commit) and Validate Adapter Contract have no conclusion yet. Copilot posted two more quota notices (at `4d7bb94` and `debb083`, 0 inline comments); neither is a review source. There are 0 GitHub inline or conversation comments.

### Findings
- [x] (suggestion, Local Review @ debb083) the zombie half of `test_job_finished_proc_comm_with_space` is vacuous: the probe's own bash reaps "x y" during the foreground `sleep 1`, so `job_finished` returns via `kill -0` and never reads /proc; spawn it under a parent that does not reap (e.g. `sh -c '"$1" 0.2 & echo $! > "$2"; exec sleep 5'`). Confirmed independently: in `bash -c 'sleep 0.2 & d=$!; sleep 1; kill -0 $d'`, `kill -0` fails because the child has already been reaped. The production fix is correct, and the running "a Z b" half does catch the regression, so this is a gap in the tests, not a defect — `.agent/scripts/tests/test_cross_model_review.sh`

### False positives
- (Copilot) "unable to review this pull request because the user who requested the review has reached their quota limit" (reviews at `4d7bb94` and `debb083`) — says nothing about the code: Copilot's quota is exhausted (known, Sept 2026); excluded from both sources and CI.

## Checkpoint
**Status**: complete
**When**: 2026-09-23 10:24 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Decided-by**: owner
**After**: findings
**Decision**: address

Fix it, then merge (Recommended)

## Implementation
**Status**: complete
**When**: 2026-09-23 10:30 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent aa6bb4ed9af2cd85d, resume 1 of 3)

**PR**: #327 at `c46b4ed`
**Addressed**: Integrated Review at `8b51699` (2026-09-23 10:20 -04:00)
**Commits**: c46b4ed

### Actions
- [x] The zombie half of `test_job_finished_proc_comm_with_space` never reached /proc because the probe's own bash reaped "x y". It now spawns "x y" under `sh -c '"$1" 0.2 & echo $! > "$2"; exec sleep 10'`, whose sleep never reaps. A precondition assertion checks that the zombie still answers `kill -0` before `job_finished` runs. The test kills the parent at the end so init reaps the zombie, and its pidfile stays under TMPDIR_BASE. — `.agent/scripts/tests/test_cross_model_review.sh`

Tests: `test_cross_model_review.sh` 386 passed / 0 failed; `run_script_tests.sh` all 23 suites passed (the check for files left behind is clean); no "x y" / "a Z b" processes remain afterwards. Not verified: whether the zombie half fails against the old awk `$3` code. That check was not permitted (Bash permission denied).

## Local Review
**Status**: complete
**When**: 2026-09-23 10:35 -04:00
**By**: Claude Code Agent (claude-opus-5-5)
**Dispatch**: resumed (agent a8d5e50365869fa6b, resume 1 of 3)
**Verdict**: approved

**PR**: #327 at `5240b7d`
**Depth**: Standard (reason: fix-round re-review of an enforcement-script test, scoped to c46b4ed; adversarial pass inline with a mutation check and a stress run)
**Must-fix**: 0 | **Suggestions**: 0

Verified: mutation check in a scratch copy, running the new `test_job_finished_proc_comm_with_space` against the 4d7bb94 awk `$3` `job_finished` — old code 1 passed / 4 failed (the precondition "zombie still unreaped" passes; the running "a Z b" half fails with RUNNING-REPORTED-FINISHED and the zombie "x y" half now fails with DEAD-REPORTED-ALIVE), new code 5 passed / 0 failed; so both halves guard the regression. Timing: 24 runs (8 in parallel, 3 waves) with 16 CPU burners on a 16-core host, 24/24 passed; the 1 s wait against the 0.2 s zombie delay leaves ample margin, and a missed pidfile after the 5 s poll fails loudly through the precondition assertion rather than passing vacuously. Leaks: no "a Z b", "x y" or burner processes left after the runs; `run_script_tests.sh` (per-suite private TMPDIR, fails on leftover files) all 23 suites passed, `test_cross_model_review.sh` 386 passed / 0 failed; shellcheck --severity=warning clean on the test file. Prior suggestion (vacuous zombie half) is resolved by c46b4ed.

### Findings
- [ ] No issues found. LGTM.
