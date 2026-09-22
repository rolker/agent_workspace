#!/usr/bin/env bash
# Run one headless codex / claude / copilot review turn and validate it.
#
# Usage:
#   _cli_review.sh <agent> <bin> <prompt-file> <findings-file> [<timeout-label>]
#
# <agent> is codex, claude or copilot. Gemini has its own helper
# (_agy_review.sh): its stream-json prompt encoding and result-event
# parsing share no shape with these three, so folding it in here would
# add a fourth case with nothing in common but the trap block.
#
# <timeout-label> is informational only — the bound itself is the caller's
# outer `timeout -k` (cross_model_review.sh: AGENT_TIMEOUT). It is quoted
# in failure reasons so a reader knows which bound the run was under.
#
# Why this exists (issue #313, folding in #212):
#   Before this helper the codex/claude/copilot arms of
#   cross_model_review.sh were bare `timeout ... "$bin" -p < prompt >
#   findings 2>&1` calls, gated on the CLI's exit code alone. Every
#   failure mode that does not move the exit code therefore landed in the
#   findings file as if it were a review:
#     * an empty response (the #288 class: a headless permission denial or
#       an aborted turn that still exits 0);
#     * a quota / rate-limit / auth error printed as ordinary output;
#     * codex's stdout transcript (banner, echoed prompt, tool chatter)
#       stored as the review body because `2>&1` merged everything.
#   Each arm now gets the same forced gate gemini has had since #288.
#
# Contract (identical to _agy_review.sh, deliberately):
#   * This script OWNS the findings file: it is truncated as the very
#     first statement, before any guard can fail, and afterwards holds
#     either the review text or a failure reason — never the previous
#     run's review under a fresh failure marker. The caller must not
#     redirect stdout onto it, and appends the "--- Review complete ---" /
#     "--- Review failed ---" marker itself.
#   * Exit 0 only when the CLI exited 0 and produced a non-empty result
#     that carries no known error marker. Exit 1 otherwise (findings file
#     holds the reason). Exit 2 on usage errors (also recorded in the
#     findings file when it is writable).
#   * The CLI runs as a background child that is `wait`ed on, with
#     INT/TERM/HUP traps armed BEFORE the spawn, so a TERM from the
#     caller's `timeout -k` or its cleanup reaches the CLI itself instead
#     of being deferred until the turn ends on its own. Leaving a CLI
#     running would burn quota on an abandoned review. The handler then
#     WAITS for the child, escalating to SIGKILL after
#     REVIEW_KILL_ESCALATION seconds (default 5), so this helper never
#     exits out from under a live CLI.
#   * No temp files survive any exit path this script can observe (EXIT
#     trap plus signal traps that exit). SIGKILL is the exception; the
#     caller closes that gap by handing us a TMPDIR it owns and sweeps
#     (cross_model_review.sh: AGENT_TMP_ROOT).
#   * All diagnostics go to stderr; stdout is unused.
#
# Verified against codex-cli 0.155.1, claude 2.x and copilot 1.0.61 help
# output on this host (2026-09-22): `codex exec [PROMPT]` reads stdin when
# no prompt argument is given and `-o/--output-last-message <FILE>` writes
# only the final message; `claude -p --output-format json` emits a single
# result object and `--permission-prompts none` auto-denies anything that
# would prompt; `copilot -p <text> -s` prints only the agent response,
# with `--available-tools`, `--disable-builtin-mcps` and `--no-ask-user`
# available to strip a headless run down to no tools at all, and the
# `-p ""` + stdin form is the one verified in #212.

set -uo pipefail

usage() {
    echo "Usage: $0 <agent: codex|claude|copilot> <bin> <prompt-file> <findings-file> [<timeout-label>]" >&2
}

if [[ $# -lt 4 || $# -gt 5 ]]; then
    usage
    exit 2
fi

AGENT="$1"
CLI_BIN="$2"
PROMPT_FILE="$3"
FINDINGS_FILE="$4"
TIMEOUT_LABEL="${5:-}"

# Truncate the findings file before anything else can fail. Without this a
# guard failure would leave the previous run's review in place under a
# fresh "--- Review failed ---" marker, and review-code would read stale
# findings as current (_agy_review.sh:69-72 does the same, for the same
# reason).
if ! : > "$FINDINGS_FILE"; then
    echo "ERROR: cannot write findings file: ${FINDINGS_FILE}" >&2
    exit 2
fi

# Write a failure reason into the findings file and exit 1.
fail() {
    local reason="$1"
    {
        echo "${AGENT} review did not produce a usable result."
        echo ""
        echo "Reason: ${reason}"
    } > "$FINDINGS_FILE"
    echo "ERROR: ${AGENT} review failed: ${reason}" >&2
    exit 1
}

# Usage error, recorded in the findings file so the caller's failure
# marker has a reason above it rather than an empty file.
usage_fail() {
    local reason="$1"
    {
        echo "${AGENT} review could not be started."
        echo ""
        echo "Reason: ${reason}"
    } > "$FINDINGS_FILE"
    echo "ERROR: ${reason}" >&2
    usage
    exit 2
}

case "$AGENT" in
    codex|claude|copilot) ;;
    *) usage_fail "unsupported agent '${AGENT}' (codex, claude and copilot run here; gemini runs through _agy_review.sh)" ;;
esac

if [[ ! -r "$PROMPT_FILE" ]]; then
    fail "prompt file not readable: ${PROMPT_FILE}"
fi
# Accept a bare name (resolved on PATH) or a path; `test -x` alone only
# looks at the current directory for a bare name.
CLI_BIN_RESOLVED=$(command -v "$CLI_BIN" 2>/dev/null || true)
if [[ -z "$CLI_BIN_RESOLVED" || ! -x "$CLI_BIN_RESOLVED" ]]; then
    fail "${AGENT} binary not found or not executable: ${CLI_BIN}"
fi
if [[ "$AGENT" == "claude" ]] && ! command -v jq >/dev/null 2>&1; then
    fail "jq is required to parse claude's --output-format json result (see bootstrap.sh)"
fi

# Known error markers. A CLI that is out of quota, rate-limited or
# logged out usually prints one of these and exits 0, so the exit code
# alone cannot see it.
ERROR_MARKER_RE='quota|rate limit|usage limit|overloaded|not logged in|unauthorized|authentication (failed|error|required)|please (log ?in|sign in)'
# How a CLI opens a message that IS an error rather than an answer:
# either an announcement ("Error:", "## Failure") or one of the known
# error sentences itself.
ERROR_OPENER_RE='^#{0,6}[[:space:]]*(error|fatal|failure|failed|warning)\b|^you( have|.ve)? exceeded|^(rate limit|usage limit|quota exceeded|quota exhausted|not logged in|unauthorized|authentication (failed|error|required)|please (log ?in|sign in))'

# Scan a channel that carries only the CLI's own diagnostics — its
# stderr. Never the prompt-echoing transcript: codex's stdout replays the
# prompt (diff included), so scanning it fails any review of a diff that
# merely mentions a rate limit. That false positive was observed live on
# this branch's own review (#313 round 1).
marker_in_log() {
    local file="$1"
    [[ -s "$file" ]] || return 1
    grep -qiE "$ERROR_MARKER_RE" "$file"
}

# Decide whether a *result* is an error the CLI printed in place of a
# review. Neither length nor markdown structure can tell the two apart:
# an adversarial review may be two concise bullets that both mention a
# rate limit, and a real quota error may be six wrapped lines under a
# "# Error" heading. Both heuristics were tried and produced exactly
# those false positives and negatives (#313 round 1).
#
# What does separate them is how the text OPENS. A review never begins
# by announcing an error or by stating a known error sentence; an error
# response always does. So: the first non-empty line must match
# ERROR_OPENER_RE, and a known marker must appear somewhere in the text.
result_is_error_only() {
    local text="$1" first
    first=$(grep -m1 -v '^[[:space:]]*$' <<< "$text")
    first="${first#"${first%%[![:space:]]*}"}"
    grep -qiE "$ERROR_OPENER_RE" <<< "$first" || return 1
    grep -qiE "$ERROR_MARKER_RE" <<< "$text"
}

# Temp files (codex's final-message file, each CLI's stdout/stderr logs)
# live under the TMPDIR the caller hands us, and are removed on every exit
# path this script can trap.
TMP_DIR=$(mktemp -d -t cli-review.XXXXXX) || fail "mktemp failed"
trap 'rm -rf "$TMP_DIR"' EXIT
# Armed before the CLI is launched (CLI_PID empty until then) so a signal
# in the launch window cannot leave the CLI running behind an exited
# helper. TERM is the live path under cross_model_review.sh: this helper
# runs as a background child of a non-interactive shell, where bash makes
# SIGINT ignored (and an ignored signal cannot be trapped). The INT trap
# is for a direct interactive invocation, where Ctrl-C does arrive.
#
# The handler does not just signal and leave: it waits for the CLI to
# actually die, escalating to SIGKILL after REVIEW_KILL_ESCALATION
# seconds. Exiting straight after the `kill` would (a) let the EXIT trap
# remove TMP_DIR out from under a CLI still writing into it, and (b)
# defeat the caller's `timeout -k` backstop, whose SIGKILL is aimed at
# this helper — once we are gone it has nothing left to kill and a CLI
# that ignored SIGTERM would keep running, burning quota on an abandoned
# review. The default sits below the caller's own kill-after grace
# (AGENT_KILL_AFTER, default 10s) so this escalation always completes
# first.
REVIEW_KILL_ESCALATION="${REVIEW_KILL_ESCALATION:-5}"
CLI_PID=""
terminate_child() {
    local code="$1" watchdog
    if [[ -n "$CLI_PID" ]]; then
        kill "$CLI_PID" 2>/dev/null
        # A watchdog rather than a poll loop: an exited-but-unreaped
        # child still answers `kill -0`, so polling that would always
        # run the full escalation window.
        ( sleep "$REVIEW_KILL_ESCALATION"; kill -9 "$CLI_PID" 2>/dev/null ) &
        watchdog=$!
        wait "$CLI_PID" 2>/dev/null
        kill "$watchdog" 2>/dev/null
        wait "$watchdog" 2>/dev/null
    fi
    exit "$code"
}
trap 'terminate_child 130' INT
trap 'terminate_child 143' TERM HUP

STDOUT_FILE="${TMP_DIR}/stdout.txt"
STDERR_FILE="${TMP_DIR}/stderr.txt"
CODEX_OUT_FILE="${TMP_DIR}/final-message.txt"

# Last 20 lines of a log, for failure reports: a fatal error lands at the
# end, after any startup chatter.
log_excerpt() {
    local label="$1" file="$2"
    if [[ -s "$file" ]]; then
        printf '\n%s (last 20 lines):\n' "$label"
        tail -n 20 "$file"
    fi
}

bound_note() {
    [[ -n "$TIMEOUT_LABEL" ]] && printf ' (run under the caller bound %s)' "$TIMEOUT_LABEL"
}

# Run the CLI as a waited-on background child, so a TERM/INT trapped here
# reaches it at once instead of being deferred until the turn ends on its
# own. Args: <stdout-file> <stderr-file, or "-" to merge into stdout>
# followed by the command.
#
# The prompt redirect goes on the backgrounded command itself, never on
# the call to this function: bash points an asynchronous command's stdin
# at /dev/null unless the command carries its own redirect, so a redirect
# one level up would hand the CLI an empty prompt.
run_cli() {
    local out="$1" err="$2"
    shift 2
    if [[ "$err" == "-" ]]; then
        "$@" < "$PROMPT_FILE" > "$out" 2>&1 &
    else
        "$@" < "$PROMPT_FILE" > "$out" 2> "$err" &
    fi
    CLI_PID=$!
    CLI_EXIT=0
    wait "$CLI_PID" || CLI_EXIT=$?
    CLI_PID=""
}

case "$AGENT" in
    codex)
        # No [PROMPT] argument, so codex reads the prompt from stdin
        # (passing one would make stdin an appended <stdin> block
        # instead). `-o` writes ONLY the final assistant message; the
        # stdout transcript — banner, echoed prompt, tool chatter — goes
        # to a log that is discarded on success and excerpted into the
        # reason on failure, never into the findings file.
        #
        # stderr is kept SEPARATE from that transcript on purpose. The
        # transcript replays the prompt, diff included, so an error-marker
        # scan over it fails any review of a diff that mentions a rate
        # limit — observed live on this branch (#313 round 1). Only
        # stderr is scanned; the `-o` file's emptiness and the exit code
        # remain the primary signals.
        DIAG_LABEL='codex transcript'
        DIAG_FILE="$STDOUT_FILE"
        run_cli "$STDOUT_FILE" "$STDERR_FILE" "$CLI_BIN_RESOLVED" exec -o "$CODEX_OUT_FILE"
        if [[ "$CLI_EXIT" -ne 0 ]]; then
            fail "codex exited ${CLI_EXIT}$(bound_note)$(log_excerpt 'codex transcript' "$STDOUT_FILE")$(log_excerpt 'codex stderr' "$STDERR_FILE")"
        fi
        if marker_in_log "$STDERR_FILE"; then
            fail "codex reported a quota / rate-limit / authentication error$(log_excerpt 'codex stderr' "$STDERR_FILE")"
        fi
        if [[ ! -s "$CODEX_OUT_FILE" ]]; then
            fail "empty response: codex wrote no final message (its --output-last-message file is missing or empty). In headless mode this is what an aborted turn looks like — the exit code stays 0.$(log_excerpt 'codex transcript' "$STDOUT_FILE")$(log_excerpt 'codex stderr' "$STDERR_FILE")"
        fi
        RESULT=$(cat "$CODEX_OUT_FILE")
        ;;
    claude)
        # --output-format json gives exactly one result object, so a
        # truncated or empty turn is detectable; --permission-prompts none
        # auto-denies anything that would prompt instead of hanging (the
        # headless behaviour _agy_review.sh relies on). No
        # --permission-mode: plan mode's terminal move is presenting a
        # plan for approval, which would pass every gate below while
        # putting a plan, not a review, in the findings file.
        DIAG_LABEL='claude stderr'
        DIAG_FILE="$STDERR_FILE"
        run_cli "$STDOUT_FILE" "$STDERR_FILE" \
            "$CLI_BIN_RESOLVED" -p --output-format json --permission-prompts none
        if [[ "$CLI_EXIT" -ne 0 ]]; then
            fail "claude exited ${CLI_EXIT}$(bound_note)$(log_excerpt 'claude stderr' "$STDERR_FILE")"
        fi
        if marker_in_log "$STDERR_FILE"; then
            fail "claude reported a quota / rate-limit / authentication error$(log_excerpt 'claude stderr' "$STDERR_FILE")"
        fi
        if ! jq -e . "$STDOUT_FILE" >/dev/null 2>&1; then
            fail "claude did not emit a JSON result object$(log_excerpt 'claude stdout' "$STDOUT_FILE")$(log_excerpt 'claude stderr' "$STDERR_FILE")"
        fi
        IS_ERROR=$(jq -r '(.is_error // false) | tostring' "$STDOUT_FILE")
        SUBTYPE=$(jq -r '.subtype // "missing"' "$STDOUT_FILE")
        RESULT=$(jq -r '.result // ""' "$STDOUT_FILE")
        # `.error` may be a string or an object; take .message when it is
        # an object. Without this, an is_error / bad-subtype failure whose
        # `.result` is empty reports no cause at all.
        ERROR_MSG=$(jq -r '((.error // "") | if type == "object" then (.message // (. | tostring)) else tostring end)' "$STDOUT_FILE")
        CLAUDE_DETAIL="${RESULT:-}"
        [[ -n "$ERROR_MSG" ]] && CLAUDE_DETAIL="${ERROR_MSG}${RESULT:+ | result: ${RESULT}}"
        if [[ "$IS_ERROR" == "true" ]]; then
            fail "claude returned is_error=true (subtype ${SUBTYPE})${CLAUDE_DETAIL:+: ${CLAUDE_DETAIL}}$(log_excerpt 'claude stderr' "$STDERR_FILE")"
        fi
        if [[ "$SUBTYPE" != "success" ]]; then
            fail "claude result subtype is '${SUBTYPE}', not 'success'${CLAUDE_DETAIL:+: ${CLAUDE_DETAIL}}$(log_excerpt 'claude stderr' "$STDERR_FILE")"
        fi
        ;;
    copilot)
        # #212/#274: the prompt goes over STDIN, never argv — a single
        # argv string is capped at MAX_ARG_STRLEN (128 KiB on Linux)
        # regardless of ARG_MAX, and Deep-tier prompts pass that. There is
        # deliberately NO prompt-size guard here: stdin has no such limit,
        # so a bound could only reject large reviews that would otherwise
        # work, re-imposing the ceiling the stdin path removed. The
        # channel is enforced by the stdin-contract test in
        # test_cross_model_review.sh, which asserts the prompt is absent
        # from argv and present on stdin.
        #
        # Least privilege: a reviewer needs no tools at all — the diff is
        # in the prompt — and the diff is untrusted input, so
        # --allow-all-tools would be a privilege escalation driven by
        # whatever the PR contains. --available-tools='' removes the tool
        # set, --disable-builtin-mcps removes the built-in MCP servers,
        # and --no-ask-user stops the agent blocking on a question no one
        # can answer headlessly. -p "" keeps print mode without putting
        # the prompt on argv; -s prints only the agent response (no stats
        # footer), so the output is used as-is — no second strip, which
        # could truncate a review body containing a footer-looking line.
        #
        # The empty tool set is read from `copilot --help` on 1.0.61 and
        # still needs ONE live confirmation when Copilot quota returns
        # (#313): if copilot rejects an empty --available-tools, the
        # documented fallback is to drop it and deny the dangerous tools
        # instead — `--deny-tool='shell' --deny-tool='write'` — keeping
        # --disable-builtin-mcps and --no-ask-user.
        DIAG_LABEL='copilot stderr'
        DIAG_FILE="$STDERR_FILE"
        run_cli "$STDOUT_FILE" "$STDERR_FILE" \
            "$CLI_BIN_RESOLVED" -p "" -s --available-tools='' --disable-builtin-mcps --no-ask-user
        if [[ "$CLI_EXIT" -ne 0 ]]; then
            fail "copilot exited ${CLI_EXIT}$(bound_note)$(log_excerpt 'copilot stderr' "$STDERR_FILE")"
        fi
        if marker_in_log "$STDERR_FILE"; then
            fail "copilot reported a quota / rate-limit / authentication error$(log_excerpt 'copilot stderr' "$STDERR_FILE")"
        fi
        RESULT=$(cat "$STDOUT_FILE")
        ;;
esac

if [[ -z "${RESULT//[[:space:]]/}" ]]; then
    # DIAG_FILE is the channel that actually carries this CLI's
    # diagnostics: codex merges nothing into stderr, so for it the
    # transcript is the only place a reason can be found.
    fail "empty response$(bound_note). In headless mode this is what a permission denial or an aborted turn looks like — the exit code stays 0.$(log_excerpt "$DIAG_LABEL" "$DIAG_FILE")"
fi
# The result itself is the last channel an error can arrive on: a CLI
# that prints "You have exceeded your usage limit" as its answer exits 0
# with that text as the whole response.
if result_is_error_only "$RESULT"; then
    fail "${AGENT} returned an error in place of a review: ${RESULT}$(log_excerpt "$DIAG_LABEL" "$DIAG_FILE")"
fi

# Success. Plain > is safe: the file was truncated above and readers key
# off the caller's completion marker, appended only after we exit.
if ! printf '%s\n' "$RESULT" > "$FINDINGS_FILE"; then
    fail "could not write the findings file: ${FINDINGS_FILE}"
fi
exit 0
