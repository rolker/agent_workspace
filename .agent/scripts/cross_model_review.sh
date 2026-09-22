#!/usr/bin/env bash
# Cross-model adversarial review via external CLI agents
#
# Runs one or more external CLI agents to provide independent adversarial
# reviews of a PR or local branch. Writes prompt and findings to
# .agent/work-plans/issue-<N>/ alongside the work plan — or to a /tmp dir
# under --no-progress. These files are not committed (gitignored under
# .agent/work-plans/, outside the repo under --no-progress). Regenerated
# each run, not part of the audit trail (durable findings live in
# progress.md). See #193 for the recursive-bloat failure mode that
# motivated this.
#
# Supported agents: gemini, codex, claude, copilot
# (the gemini agent runs via the `agy` binary — see AGENT_BINS — through
# the _agy_review.sh helper, which feeds the prompt over stdin and
# validates agy's result event; issues #274, #288)
#
# The embedded diff excludes .agent/work-plans/** (plan.md, progress.md,
# review artifacts): review bookkeeping, not code under review, and the
# main source of oversized prompts (#312).
#
# Execution model (ADR-0015, issue #206): every agent runs synchronously in
# its own background job, all selected agents in parallel, and the script
# blocks until the last one finishes. There is no tmux mode any more —
# reviews run headless, so the interactive session it provided had no
# remaining value, and the sandboxed callers it silently downgraded to
# sequential runs get parallelism back. `--sync` (the old opt-out) is
# rejected as removed. Live observation: `tail -f <findings-file>`.
#
# Each non-gemini agent is bounded by `timeout "$AGENT_TIMEOUT"` (seconds,
# env-overridable, default 1800) so one hung CLI cannot hang the call;
# gemini is bounded by _agy_review.sh's own --print-timeout (an outer
# SIGTERM would race its timeout-then-partial-response contract, #288).
#
# Usage:
#   .agent/scripts/cross_model_review.sh --pr <N>                              # gemini (default)
#   .agent/scripts/cross_model_review.sh --pr <N> --agent codex                # one specific agent
#   .agent/scripts/cross_model_review.sh --pr <N> --agents gemini,codex,copilot # several, in parallel
#   .agent/scripts/cross_model_review.sh --branch --agents gemini,codex        # local pre-push review
#   .agent/scripts/cross_model_review.sh --pr <N> --repo owner/repo            # explicit repo target
#   .agent/scripts/cross_model_review.sh --pr <N> --work-dir /path/to/worktree # explicit artifact dir
#
# --agent and --agents are mutually exclusive. --agents takes a comma list:
# entries are trimmed and lowercased, empty entries (stray commas) are
# rejected, exact duplicates collapse to one run, unknown names exit 2.
#
# The script runs in whichever repo worktree it's invoked from.
# Workspace issues run in workspace worktrees, project issues in project worktrees.
#
# Output (stdout), --agent <X> (single-agent, unchanged contract):
#   MODE=sync                        (machine-parseable)
#   AGENT=<agent-key>                (machine-parseable)
#   FINDINGS_FILE=<path-to-findings> (machine-parseable)
#   followed by informational lines for human consumption
#
# Output (stdout), --agents <list> (one entry or more):
#   MODE=parallel-sync               (once)
#   AGENT=<agent-key>                (one triplet per agent, after all
#   FINDINGS_FILE=<path-to-findings>  agents have finished; EXIT= is that
#   EXIT=<n>                          agent's own exit status, 0 = success)
#   followed by informational lines for human consumption
#
# Per-agent findings files always end with `--- Review complete ---` or
# `--- Review failed ---` (reason on the lines above), written by the
# agent's own job the moment it finishes — a slow agent never delays a
# fast agent's marker.
#
# Exit codes:
#   0 — every selected agent completed successfully
#   1 — missing dependencies: gh (PR mode), or no selected agent has a
#       usable CLI (with --agents, every agent's findings file still gets
#       a failed marker and a triplet with EXIT=1)
#   2 — invalid arguments
#   3 — failed to build the prompt (no AGENT= triplets printed under
#       --agents: the shared diff fetch failed or was empty and every
#       selected findings file carries the `--- Review error: ... ---`
#       marker), OR at least one agent failed (triplets printed — read
#       EXIT= per agent). The presence of triplets is the disambiguator.
#   4 — wrong worktree / invalid environment (see _resolve_work_plans_dir.sh)

set -euo pipefail

# --- Agent configuration ---
# Binary name to search for in PATH and fallback locations.
# The Gemini CLI migrated to the `agy` binary (issue #223); the agent key
# stays "gemini" so existing callers (--agent gemini, review-code skill
# mapping, artifact filenames) keep working.
declare -A AGENT_BINS=(
    ["gemini"]="agy"
    ["codex"]="codex"
    ["claude"]="claude"
    ["copilot"]="copilot"
)

# Timeout for agy print mode (Go duration format). agy's own default is
# 0s = wait until the turn completes; the explicit cap keeps a hung
# review from blocking the caller forever. On expiry agy exits 0 with a
# partial response — _agy_review.sh treats that as a failed review (#288).
AGY_PRINT_TIMEOUT="30m"

# Outer per-agent bound for codex/claude/copilot, in seconds (coreutils
# `timeout`). Env-overridable so tests can inject a small value. 124 is
# timeout's own "expired" status and counts as that agent's failure.
AGENT_TIMEOUT="${AGENT_TIMEOUT:-1800}"

# Helper that owns the gemini invocation. A missing helper makes the
# gemini agent unavailable (that agent fails; others still run).
AGY_REVIEW_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_agy_review.sh"

# Run one agent to completion. Args: agent_key, bin_path, prompt_file,
# findings_file. Returns the agent CLI's exit status (124 on timeout).
# Agents read the prompt from stdin, so prompt size is not bounded by
# argv limits.
run_agent_sync() {
    local agent="$1" bin="$2" prompt="$3" findings="$4"

    case "$agent" in
        # Helper owns the findings file; no stdout redirect (#274, #288).
        gemini)  "$AGY_REVIEW_HELPER" "$bin" "$prompt" "$findings" "$AGY_PRINT_TIMEOUT" ;;
        codex)   timeout "$AGENT_TIMEOUT" "$bin" exec < "$prompt" > "$findings" 2>&1 ;;
        claude)  timeout "$AGENT_TIMEOUT" "$bin" -p < "$prompt" > "$findings" 2>&1 ;;
        copilot) timeout "$AGENT_TIMEOUT" "$bin" -p < "$prompt" > "$findings" 2>&1 ;;
        *)       timeout "$AGENT_TIMEOUT" "$bin" -p < "$prompt" > "$findings" 2>&1 ;;
    esac
}

# Resolve an agent's CLI: PATH first, then common install locations.
# Prints the path on stdout (empty when not found); never exits.
resolve_agent_bin() {
    local agent="$1"
    local name="${AGENT_BINS[$agent]}"
    if command -v "$name" &>/dev/null; then
        command -v "$name"
        return 0
    fi
    local candidate
    for candidate in \
        "${HOME}/.nvm/versions/node"/*/bin/"${name}" \
        "${HOME}/.local/bin/${name}" \
        "${HOME}/.npm-global/bin/${name}" \
        /usr/local/bin/"${name}"; do
        if [[ -x "$candidate" ]]; then
            echo "INFO: ${name} not in PATH, found at: ${candidate}" >&2
            echo "$candidate"
            return 0
        fi
    done
    echo ""
}

# --- Argument parsing ---
PR_NUMBER=""
BRANCH_MODE=false
BRANCH_BASE=""
NO_PROGRESS=false
CLI_ISSUE_NUMBER=""
SINGLE_AGENT=""
AGENTS_LIST=""
EXPLICIT_REPO=""
EXPLICIT_WORK_DIR=""
CLI_WORK_PLANS_DIR=""

USAGE="Usage: $0 (--pr <N> | --branch [<ref>]) [--issue <N>] [--agent <name> | --agents <a,b,...>] [--repo owner/repo] [--work-dir <path>] [--work-plans-dir <path>] [--no-progress]"

# Helper: treat a missing value OR a value that looks like another long
# flag (`--foo`) as "missing value." Narrower than `-*` so negative
# integers and dash-prefixed paths fall through to their dedicated
# validators (per review feedback on #149).
require_value() {
    local flag="$1"
    local value="$2"
    if [[ -z "$value" || "$value" == --* ]]; then
        echo "ERROR: Missing value for $flag" >&2
        echo "$USAGE" >&2
        exit 2
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)
            require_value "--pr" "${2:-}"
            PR_NUMBER="$2"
            shift 2
            ;;
        --branch)
            BRANCH_MODE=true
            # --branch takes an optional value. Treat the next token as
            # the base ref only if it doesn't look like another flag and
            # isn't empty. Otherwise leave BRANCH_BASE empty so the
            # default-branch resolver runs.
            if [[ -n "${2:-}" && "${2}" != --* ]]; then
                BRANCH_BASE="$2"
                shift 2
            else
                shift 1
            fi
            ;;
        --no-progress)
            NO_PROGRESS=true
            shift 1
            ;;
        --issue)
            require_value "--issue" "${2:-}"
            CLI_ISSUE_NUMBER="$2"
            shift 2
            ;;
        --agent)
            require_value "--agent" "${2:-}"
            SINGLE_AGENT="${2,,}"  # lowercase
            shift 2
            ;;
        --agents)
            require_value "--agents" "${2:-}"
            AGENTS_LIST="$2"
            shift 2
            ;;
        --repo|-R)
            require_value "--repo" "${2:-}"
            EXPLICIT_REPO="$2"
            shift 2
            ;;
        --work-dir)
            require_value "--work-dir" "${2:-}"
            EXPLICIT_WORK_DIR="$2"
            shift 2
            ;;
        --work-plans-dir)
            require_value "--work-plans-dir" "${2:-}"
            CLI_WORK_PLANS_DIR="$2"
            shift 2
            ;;
        --sync)
            echo "ERROR: --sync was removed (#206, ADR-0015): synchronous parallel dispatch is the only mode now; drop the flag." >&2
            echo "$USAGE" >&2
            exit 2
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "$USAGE" >&2
            exit 2
            ;;
    esac
done

if [[ -n "$PR_NUMBER" && "$BRANCH_MODE" == true ]]; then
    echo "ERROR: --pr and --branch are mutually exclusive." >&2
    echo "" >&2
    echo "  Use --pr <N> for PR mode (post-push review)" >&2
    echo "  or --branch [<base>] for branch mode (local pre-push review)." >&2
    exit 2
fi
if [[ -z "$PR_NUMBER" && "$BRANCH_MODE" != true ]]; then
    echo "ERROR: one of --pr <N> or --branch [<ref>] is required" >&2
    echo "$USAGE" >&2
    exit 2
fi

# --- Agent selection ---
# --agent <X> (or neither flag: gemini) is the single-agent contract;
# --agents <list> is the multi-agent contract, even with one entry.
if [[ -n "$SINGLE_AGENT" && -n "$AGENTS_LIST" ]]; then
    echo "ERROR: --agent and --agents are mutually exclusive." >&2
    echo "$USAGE" >&2
    exit 2
fi

MULTI_AGENT=false
AGENTS_TO_RUN=()
if [[ -n "$AGENTS_LIST" ]]; then
    MULTI_AGENT=true
    # A leading or trailing comma is an empty entry too; `read -a` would
    # silently drop a trailing one, so check the raw string first.
    if [[ "$AGENTS_LIST" == ,* || "$AGENTS_LIST" == *, ]]; then
        echo "ERROR: --agents has an empty entry (stray comma?): '${AGENTS_LIST}'" >&2
        exit 2
    fi
    IFS=',' read -r -a raw_agents <<< "$AGENTS_LIST"
    for raw in "${raw_agents[@]}"; do
        # Trim surrounding whitespace, lowercase.
        entry="${raw#"${raw%%[![:space:]]*}"}"
        entry="${entry%"${entry##*[![:space:]]}"}"
        entry="${entry,,}"
        if [[ -z "$entry" ]]; then
            echo "ERROR: --agents has an empty entry (stray comma?): '${AGENTS_LIST}'" >&2
            exit 2
        fi
        if [[ -z "${AGENT_BINS[$entry]+x}" ]]; then
            echo "ERROR: Unknown agent '${entry}' in --agents" >&2
            echo "Supported agents: ${!AGENT_BINS[*]}" >&2
            exit 2
        fi
        # Exact duplicates collapse to one run: two jobs for the same
        # agent would race on one prompt/findings filename.
        dup=false
        for seen in "${AGENTS_TO_RUN[@]:-}"; do
            [[ "$seen" == "$entry" ]] && dup=true
        done
        [[ "$dup" == true ]] || AGENTS_TO_RUN+=("$entry")
    done
    # A list that was entirely empty entries cannot reach here (each is
    # rejected above), so AGENTS_TO_RUN has at least one element.
else
    SINGLE_AGENT="${SINGLE_AGENT:-gemini}"
    if [[ -z "${AGENT_BINS[$SINGLE_AGENT]+x}" ]]; then
        echo "ERROR: Unknown agent '${SINGLE_AGENT}'" >&2
        echo "Supported agents: ${!AGENT_BINS[*]}" >&2
        exit 2
    fi
    AGENTS_TO_RUN=("$SINGLE_AGENT")
fi

# Validate --repo slug (before dependency checks so bad input always exits 2)
if [[ -n "$EXPLICIT_REPO" && ! "$EXPLICIT_REPO" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
    echo "ERROR: --repo value '${EXPLICIT_REPO}' is not a valid owner/repo slug" >&2
    exit 2
fi

# Validate --issue is a bare positive integer (same contract as the
# per-issue work-plans resolver — see _resolve_work_plans_dir.sh).
if [[ -n "$CLI_ISSUE_NUMBER" && ! "$CLI_ISSUE_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: --issue value '${CLI_ISSUE_NUMBER}' is not a positive integer" >&2
    exit 2
fi

# --- Dependency checks ---
# gh is required for PR mode (PR body/diff retrieval) but optional for
# branch mode (offline pre-push review uses local git only).
if [[ "$BRANCH_MODE" != true ]] && ! command -v gh &>/dev/null; then
    echo "WARNING: GitHub CLI (gh) not installed — required for PR metadata" >&2
    exit 1
fi

# Resolve repo slug for explicit -R targeting (prevents misrouting in
# nested repos). Prefer `gh repo view` over parsing `git remote get-url`
# — gh handles SSH host aliases (~/.ssh/config), GitHub Enterprise, and
# custom remote names correctly, where the regex approach produced
# garbage or silently fell back (issue #150). Skipped in branch mode
# unless gh is available, since branch mode never calls gh -R.
GH_REPO_SLUG=""
if [[ -n "$EXPLICIT_REPO" ]]; then
    GH_REPO_SLUG="$EXPLICIT_REPO"
elif [[ "$BRANCH_MODE" != true ]] && command -v gh &>/dev/null; then
    # PR mode only — branch mode never uses GH_REPO_ARGS so the
    # network call is wasted work.
    GH_REPO_SLUG=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
fi
GH_REPO_ARGS=()
if [[ -n "$GH_REPO_SLUG" && "$GH_REPO_SLUG" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]]; then
    GH_REPO_ARGS=("-R" "$GH_REPO_SLUG")
fi

# --- Per-agent CLI resolution ---
# One missing CLI never aborts the others: the agent is recorded as
# unavailable with a reason, gets a failed marker once the artifact dir
# exists, and the run continues. Only "no selected agent is usable"
# is a dependency error (exit 1).
declare -A AGENT_BIN_FOR=()
declare -A AGENT_UNAVAILABLE_REASON=()
USABLE_AGENTS=0
for agent in "${AGENTS_TO_RUN[@]}"; do
    bin=$(resolve_agent_bin "$agent")
    if [[ -z "$bin" ]]; then
        AGENT_UNAVAILABLE_REASON["$agent"]="${AGENT_BINS[$agent]} CLI not found (PATH searched: ${PATH}; also ~/.nvm/versions/node/*/bin/, ~/.local/bin/, ~/.npm-global/bin/, /usr/local/bin/)"
    elif [[ "$agent" == "gemini" && ! -x "$AGY_REVIEW_HELPER" ]]; then
        AGENT_UNAVAILABLE_REASON["$agent"]="${AGY_REVIEW_HELPER} is missing or not executable"
    else
        AGENT_BIN_FOR["$agent"]="$bin"
        USABLE_AGENTS=$((USABLE_AGENTS + 1))
    fi
done

if [[ "$USABLE_AGENTS" -eq 0 ]]; then
    for agent in "${AGENTS_TO_RUN[@]}"; do
        echo "WARNING: ${agent} adversarial review unavailable — ${AGENT_UNAVAILABLE_REASON[$agent]}" >&2
    done
    exit 1
fi

# --- Resolve issue number ---
# Order: explicit --issue flag wins; otherwise mode-specific resolution.
# PR mode: require a GitHub closure keyword in the PR body. The loose
# "first standalone #N" fallback was removed in #149 — it silently
# routed artifacts to unrelated issues and, post-#147, caused the
# work-plans resolver to abort with a confusing wrong-issue message.
# Branch mode: parse the current branch name (AGENTS.md branch-naming
# rule: feature/issue-<N> or feature/ISSUE-<N>-<desc>). On parse
# failure, hard error unless --no-progress was passed.
if [[ -n "$CLI_ISSUE_NUMBER" ]]; then
    ISSUE_NUMBER="$CLI_ISSUE_NUMBER"
elif [[ "$BRANCH_MODE" == true ]]; then
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    # Tightened regex: requires a separator after digits (so
    # `feature/issue-3foo` doesn't silently capture `3`) and rejects
    # leading zeros (so `feature/issue-03` doesn't bypass the
    # --issue validator's positive-integer check). #149 lesson:
    # silent issue-number misrouting is the failure mode to prevent.
    if [[ "$CURRENT_BRANCH" =~ ^feature/[Ii][Ss][Ss][Uu][Ee]-([1-9][0-9]*)(-|$) ]]; then
        ISSUE_NUMBER="${BASH_REMATCH[1]}"
    elif [[ "$NO_PROGRESS" == true ]]; then
        # Sentinel used for the findings filename; the per-issue
        # artifact dir is replaced with a tmp dir below.
        ISSUE_NUMBER="noprogress"
    else
        {
            echo "ERROR: cannot resolve issue number."
            echo ""
            echo "  Current branch '${CURRENT_BRANCH}' does not match feature/issue-<N>."
            echo ""
            echo "  Fix one of:"
            echo "    --issue <N>     point to a specific issue"
            echo "    --no-progress   skip progress.md persistence"
            echo "                    (skill worktrees, one-off branches)"
            echo "    rename branch   if this should be tracked"
        } >&2
        exit 2
    fi
else
    # PR mode: parse Closes/Fixes/Resolves keyword from PR body.
    # Capture gh's exit status distinctly from "retrieved an empty body"
    # so auth/network/permission failures produce the right remediation
    # (per review feedback on #149).
    if ! PR_BODY=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json body --jq '.body' 2>/dev/null); then
        {
            echo "ERROR: Failed to retrieve body for PR #${PR_NUMBER}."
            echo ""
            echo "  Verify GitHub authentication, repository permissions,"
            echo "  and network connectivity, then try again."
            echo "  Alternatively, pass --issue <N> to skip PR-body extraction."
        } >&2
        exit 2
    fi

    # Match GitHub closure keywords (case-insensitive): Closes #N,
    # Fixes #N, Resolves #N. Requires a word boundary before the keyword
    # to avoid matching "encloses", "prefixes", etc. Also accepts the
    # cross-repo form "Closes owner/repo#N" (just extracts N).
    ISSUE_REF=$(printf '%s\n' "$PR_BODY" \
        | grep -ioE '(^|[^[:alnum:]_])(closes|fixes|resolves)[[:space:]]+([a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+)?#[0-9]+' \
        | head -n1 || true)
    ISSUE_NUMBER=$(printf '%s\n' "$ISSUE_REF" | grep -oE '[0-9]+$' || true)

    if [[ -z "$ISSUE_NUMBER" ]]; then
        {
            echo "ERROR: PR #${PR_NUMBER} body has no 'Closes|Fixes|Resolves #N' keyword."
            echo ""
            echo "  The loose '#N' fallback was removed in #149 because it routed"
            echo "  artifacts to unrelated issues. Two ways to proceed:"
            echo "    1. Pass --issue <N> to set the issue number explicitly, or"
            echo "    2. Edit the PR body to include a closure keyword"
            echo "       (e.g. 'Closes #123')."
        } >&2
        exit 2
    fi
fi

# --- Set up artifact directory ---
# Refuse to run outside the matching worktree (issue #147) unless the
# caller explicitly overrides the location via --work-plans-dir (exact
# path), --work-dir (repo root), or --no-progress (mktemp -d for
# ephemeral artifacts when there's no issue to track). Each override
# routes through $WORK_PLANS_DIR_OVERRIDE so the resolver treats them
# uniformly.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_resolve_work_plans_dir.sh
source "${SCRIPT_DIR}/_resolve_work_plans_dir.sh"
# shellcheck source=_resolve_default_branch.sh
source "${SCRIPT_DIR}/_resolve_default_branch.sh"

if [[ -n "$CLI_WORK_PLANS_DIR" ]]; then
    export WORK_PLANS_DIR_OVERRIDE="$CLI_WORK_PLANS_DIR"
elif [[ -n "$EXPLICIT_WORK_DIR" ]]; then
    if [[ ! -d "$EXPLICIT_WORK_DIR" ]]; then
        echo "ERROR: --work-dir is not an existing directory: ${EXPLICIT_WORK_DIR}" >&2
        exit 2
    fi
    # Resolve to absolute path so the findings paths printed are usable
    # from any cwd.
    EXPLICIT_WORK_DIR=$(cd "$EXPLICIT_WORK_DIR" && pwd)
    export WORK_PLANS_DIR_OVERRIDE="${EXPLICIT_WORK_DIR}/.agent/work-plans/issue-${ISSUE_NUMBER}"
elif [[ "$NO_PROGRESS" == true ]]; then
    # --no-progress: ephemeral artifact dir. Findings remain readable
    # for the session but aren't tied to a per-issue directory and won't
    # be picked up by progress.md commit conventions. Note that the
    # branch-name regex may still resolve a real ISSUE_NUMBER (e.g.
    # `feature/issue-3` with --no-progress); the artifact dir override
    # always wins when --no-progress is set, even if the issue number
    # was resolvable. Tmpdir is left in /tmp for the session; the OS
    # cleans it up on next boot. Adding a `trap` to remove on exit was
    # considered and declined: users frequently want to inspect
    # findings after the script finishes.
    NO_PROGRESS_TMP_DIR=$(mktemp -d -t "cross-model-review.XXXXXX")
    echo "INFO: --no-progress: artifacts going to ${NO_PROGRESS_TMP_DIR}" >&2
    export WORK_PLANS_DIR_OVERRIDE="${NO_PROGRESS_TMP_DIR}"
fi

WORK_PLANS_DIR=$(resolve_work_plans_dir "$ISSUE_NUMBER") || exit 4
mkdir -p "$WORK_PLANS_DIR"

prompt_file_for()   { echo "${WORK_PLANS_DIR}/review-$1-prompt.md"; }
findings_file_for() { echo "${WORK_PLANS_DIR}/review-$1-findings.md"; }

# Write one error marker into every selected agent's findings file
# (truncating) and exit 3 — the shared prompt could not be built, so no
# agent ran and no AGENT= triplet is printed.
abort_all_agents() {
    local marker="$1"
    local agent
    for agent in "${AGENTS_TO_RUN[@]}"; do
        echo "$marker" > "$(findings_file_for "$agent")"
    done
    exit 3
}

# --- Get review-target metadata ---
# PR mode: query gh for the PR's title and URL.
# Branch mode: resolve base ref via the helper, capture HEAD sha and
# branch name for the prompt header.
if [[ "$BRANCH_MODE" == true ]]; then
    BRANCH_NAME=$(git branch --show-current 2>/dev/null || echo "(detached)")
    HEAD_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    if [[ -n "$BRANCH_BASE" ]]; then
        # Validate and normalize: prefer the local ref, fall back to
        # origin/<ref> when only the remote-tracking branch exists.
        # Without normalization, `git diff develop...HEAD` would fail
        # on a fresh clone where only `origin/develop` is reachable.
        if git rev-parse --verify --quiet "$BRANCH_BASE" >/dev/null 2>&1; then
            BASE_REF="$BRANCH_BASE"
        elif git rev-parse --verify --quiet "origin/$BRANCH_BASE" >/dev/null 2>&1; then
            BASE_REF="origin/$BRANCH_BASE"
        else
            echo "ERROR: --branch base '${BRANCH_BASE}' is not a known ref (locally or as origin/${BRANCH_BASE})" >&2
            exit 2
        fi
    else
        BASE_REF=$(resolve_default_branch) || exit 2
    fi

    PR_TITLE="Local branch ${BRANCH_NAME} at ${HEAD_SHA}"
    PR_URL=""
else
    PR_TITLE=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json title --jq '.title' 2>/dev/null || echo "PR #${PR_NUMBER}")
    PR_URL=$(gh pr view "$PR_NUMBER" "${GH_REPO_ARGS[@]}" --json url --jq '.url' 2>/dev/null || echo "")
fi

# Human-readable label for status messages. Mode-aware so branch-mode
# logs read sensibly without "PR #" prefixes that don't apply. Computed
# after the metadata block so BRANCH_NAME is in scope under `set -u`.
if [[ "$BRANCH_MODE" == true ]]; then
    if [[ "$ISSUE_NUMBER" == "noprogress" ]]; then
        TARGET_LABEL="branch ${BRANCH_NAME} (no-progress mode)"
    else
        TARGET_LABEL="branch ${BRANCH_NAME} (issue #${ISSUE_NUMBER})"
    fi
else
    TARGET_LABEL="PR #${PR_NUMBER} (issue #${ISSUE_NUMBER})"
fi

# --- Write the shared prompt ---
# The header, metadata, diff and output-format footer are identical for
# every agent, so they are built once into a temp file and copied into
# each agent's prompt file; only the per-agent tool-use footer differs.
# Use a quoted heredoc for the static header to prevent shell expansion,
# then stream the diff directly from gh/git to avoid storing it in a
# variable (which could hit shell limits for large Deep-tier PRs).
SHARED_PROMPT=$(mktemp -t "cross-model-review-prompt.XXXXXX")
trap 'rm -f "$SHARED_PROMPT"' EXIT

cat > "$SHARED_PROMPT" << 'PROMPT_HEADER'
# Adversarial Code Review

## Your Role

You are an independent adversarial reviewer. Your job is to find issues that
other reviewers missed: edge cases, security implications, incorrect
assumptions, subtle bugs, and logic errors.

Review the diff below with fresh eyes. Do not assume previous reviewers caught
everything. Focus on:

- **Edge cases**: What inputs or states could break this code?
- **Security**: Are there injection, auth, or data exposure risks?
- **Assumptions**: What does the code assume that might not hold?
- **Subtle bugs**: Off-by-one, race conditions, resource leaks, null/undefined
- **Logic errors**: Does the code actually do what the PR title claims?

## PR Under Review

PROMPT_HEADER

# Append review-target metadata (needs expansion).
# Branch-mode prompt emits Branch + Base + HEAD instead of PR Number/URL
# so the agent reviewing local pre-push work has the right framing.
if [[ "$BRANCH_MODE" == true ]]; then
    printf '**Title**: %s\n**Branch**: %s\n**Base**: %s\n**HEAD**: %s\n\n' \
        "$PR_TITLE" "$BRANCH_NAME" "$BASE_REF" "$HEAD_SHA" >> "$SHARED_PROMPT"
else
    printf '**Title**: %s\n**URL**: %s\n**PR Number**: #%s\n\n' \
        "$PR_TITLE" "$PR_URL" "$PR_NUMBER" >> "$SHARED_PROMPT"
fi

# Drop .agent/work-plans/** file sections from a unified diff (#312).
# Reads the diff on stdin. A section starts at `diff --git a/<p> b/<p>`
# and runs to the next such header. Only the b/ (post-image) path
# decides: a deleted file still carries its b/ path on that line, and a
# file renamed OUT of work-plans into the codebase is new code that
# must stay in review. Git quotes paths with unusual characters
# (`"b/..."`), hence the optional quote. Everything else passes through
# byte-for-byte.
filter_work_plans_diff() {
    awk '
        /^diff --git / {
            skip = ($0 ~ / "?b\/\.agent\/work-plans\//)
        }
        !skip { print }
    '
}

# Stream diff into the shared prompt through the work-plans filter.
# Branch mode uses local `git diff <base>...HEAD`; PR mode uses `gh pr
# diff <N>`. The pipeline sits inside `if !` so `set -e` does not abort
# the script before the error branch runs; with `pipefail` the tested
# status is the first failing stage's, so a failed gh/git call is not
# masked by the filter succeeding on empty input, and a filter dying
# mid-stream cannot leave a truncated diff looking complete.
printf '## Diff\n\n```diff\n' >> "$SHARED_PROMPT"
DIFF_START_LINE=$(wc -l < "$SHARED_PROMPT")
if [[ "$BRANCH_MODE" == true ]]; then
    # Explicit a/ b/ prefixes so a diff.noprefix / diff.mnemonicPrefix
    # config cannot defeat the work-plans filter.
    if ! git diff --src-prefix=a/ --dst-prefix=b/ "${BASE_REF}...HEAD" 2>/dev/null | filter_work_plans_diff >> "$SHARED_PROMPT"; then
        echo "ERROR: Could not produce diff for ${BRANCH_NAME} against ${BASE_REF}" >&2
        abort_all_agents '--- Review error: failed to produce branch diff ---'
    fi
else
    if ! gh pr diff "$PR_NUMBER" "${GH_REPO_ARGS[@]}" 2>/dev/null | filter_work_plans_diff >> "$SHARED_PROMPT"; then
        echo "ERROR: Could not retrieve diff for PR #${PR_NUMBER}" >&2
        abort_all_agents '--- Review error: failed to retrieve diff ---'
    fi
fi
DIFF_END_LINE=$(wc -l < "$SHARED_PROMPT")

# Guard: if diff is empty (before or after the work-plans filter), abort
# with a clear error instead of launching agents with no content to
# review.
if [[ "$DIFF_END_LINE" -le "$DIFF_START_LINE" ]]; then
    if [[ "$BRANCH_MODE" == true ]]; then
        echo "ERROR: branch '${BRANCH_NAME}' has no reviewable changes against '${BASE_REF}' — nothing to review" >&2
        echo "  Either the branch is up-to-date with the base, the base ref is wrong," >&2
        echo "  or every changed file is under .agent/work-plans/ (excluded from review, #312)." >&2
        abort_all_agents '--- Review error: diff was empty (branch matches base, or only .agent/work-plans/ changed) ---'
    else
        echo "ERROR: PR #${PR_NUMBER} diff is empty — nothing to review" >&2
        echo "  This usually means the PR was not found in the target repo, or every" >&2
        echo "  changed file is under .agent/work-plans/ (excluded from review, #312)." >&2
        echo "  Try passing --repo <owner/repo> explicitly." >&2
        abort_all_agents '--- Review error: diff was empty (PR not found, no changes, or only .agent/work-plans/ changed) ---'
    fi
fi
printf '```\n\n' >> "$SHARED_PROMPT"

# Append output format instructions (quoted heredoc, no expansion)
cat >> "$SHARED_PROMPT" << 'PROMPT_FOOTER'
## Output Format

Write your findings to this exact format so they can be parsed:

### Findings

| # | Severity | File | Line | Finding |
|---|----------|------|------|---------|
| 1 | must-fix / suggestion | `path/to/file` | line number | Description of the issue |

If you find no issues, write:

### Findings

No issues found.

### Summary

Write a 1-3 sentence overall assessment after the findings table.
PROMPT_FOOTER

# --- Per-agent prompt files ---
# Gemini only: headless agy auto-denies shell commands and then returns
# an empty response (#288). Reading files is permitted, so the
# reviewer keeps that. Not added for codex/claude/copilot — codex reads
# files through the shell, so the line would cost it context.
for agent in "${AGENTS_TO_RUN[@]}"; do
    prompt_file=$(prompt_file_for "$agent")
    cp "$SHARED_PROMPT" "$prompt_file"
    if [[ "$agent" == "gemini" ]]; then
        cat >> "$prompt_file" << 'PROMPT_TOOL_USE'

## Tool Use

The diff above is the complete set of code changes under review; files
under `.agent/work-plans/` (plan and progress bookkeeping) are deliberately
excluded. You may read files in the repository for surrounding context.
Do NOT run shell commands: this is a headless session,
command execution is denied without a prompt, and a denied command can end
the review with no output.
PROMPT_TOOL_USE
    fi
done

# --- Run reviews: one background job per agent, all in parallel ---
# Each job runs its agent, then appends that agent's completion marker
# itself, so a slow agent never delays a fast agent's marker and the
# parent only has to collect exit statuses. Jobs write nothing to stdout,
# keeping the machine-parseable block contiguous.
run_agent_job() {
    local agent="$1"
    local prompt_file findings_file rc
    prompt_file=$(prompt_file_for "$agent")
    findings_file=$(findings_file_for "$agent")

    if [[ -n "${AGENT_UNAVAILABLE_REASON[$agent]+x}" ]]; then
        {
            echo "${agent} adversarial review unavailable."
            echo ""
            echo "Reason: ${AGENT_UNAVAILABLE_REASON[$agent]}"
            echo '--- Review failed ---'
        } > "$findings_file"
        return 1
    fi

    # `if` keeps set -e from aborting the job before rc is captured.
    if run_agent_sync "$agent" "${AGENT_BIN_FOR[$agent]}" "$prompt_file" "$findings_file"; then
        rc=0
    else
        rc=$?
    fi
    if [[ "$rc" -eq 124 ]]; then
        printf '\n%s review timed out after %ss (AGENT_TIMEOUT); partial output above, if any.\n' \
            "$agent" "$AGENT_TIMEOUT" >> "$findings_file"
    fi
    if [[ "$rc" -eq 0 ]]; then
        echo '--- Review complete ---' >> "$findings_file"
    else
        echo '--- Review failed ---' >> "$findings_file"
    fi
    return "$rc"
}

if [[ "$MULTI_AGENT" == true ]]; then
    echo "MODE=parallel-sync"
else
    echo "MODE=sync"
    echo "AGENT=${AGENTS_TO_RUN[0]}"
    echo "FINDINGS_FILE=$(findings_file_for "${AGENTS_TO_RUN[0]}")"
    echo ""
    echo "Running ${AGENTS_TO_RUN[0]} adversarial review synchronously for ${TARGET_LABEL}..."
    echo "  Prompt:  $(prompt_file_for "${AGENTS_TO_RUN[0]}")"
    echo "  Results: $(findings_file_for "${AGENTS_TO_RUN[0]}")"
fi

declare -A AGENT_PID=()
for agent in "${AGENTS_TO_RUN[@]}"; do
    run_agent_job "$agent" &
    AGENT_PID["$agent"]=$!
done

# Collect in selection order. `wait` returns the job's own status; the
# `|| rc=$?` keeps set -e from aborting the loop on the first failed
# agent before the remaining ones are collected.
declare -A AGENT_EXIT=()
ANY_FAILED=false
for agent in "${AGENTS_TO_RUN[@]}"; do
    rc=0
    wait "${AGENT_PID[$agent]}" || rc=$?
    AGENT_EXIT["$agent"]=$rc
    [[ "$rc" -eq 0 ]] || ANY_FAILED=true
done

if [[ "$MULTI_AGENT" == true ]]; then
    for agent in "${AGENTS_TO_RUN[@]}"; do
        echo "AGENT=${agent}"
        echo "FINDINGS_FILE=$(findings_file_for "$agent")"
        echo "EXIT=${AGENT_EXIT[$agent]}"
    done
    echo ""
    echo "Ran ${#AGENTS_TO_RUN[@]} adversarial review(s) in parallel for ${TARGET_LABEL}."
    for agent in "${AGENTS_TO_RUN[@]}"; do
        if [[ "${AGENT_EXIT[$agent]}" -eq 0 ]]; then
            echo "  ${agent}: complete — $(findings_file_for "$agent")"
        else
            echo "  ${agent}: FAILED (exit ${AGENT_EXIT[$agent]}) — $(findings_file_for "$agent")"
        fi
    done
    if [[ "$ANY_FAILED" == true ]]; then
        echo "ERROR: at least one agent failed — see EXIT= per agent above" >&2
        exit 3
    fi
else
    if [[ "$ANY_FAILED" == true ]]; then
        echo "ERROR: ${AGENTS_TO_RUN[0]} CLI exited with an error" >&2
        exit 3
    fi
    echo ""
    echo "Review complete. Results: $(findings_file_for "${AGENTS_TO_RUN[0]}")"
fi
