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
#     running would burn quota on an abandoned review.
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
# would prompt; `copilot -p <text> --allow-all-tools -s` prints only the
# agent response, and the `-p ""` + stdin form is the one verified in #212.

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

# Scan the CLI's own stderr/transcript for those markers. Free text from
# the CLI, not review prose, so the full pattern is safe here.
marker_in_log() {
    local file="$1"
    [[ -s "$file" ]] || return 1
    grep -qiE "$ERROR_MARKER_RE" "$file"
}

# Scan a *result* for the same markers. A genuine adversarial review may
# legitimately discuss rate limits or authentication, so the scan applies
# only to text short enough that it cannot be a review and that carries no
# markdown structure — i.e. a bare error line the CLI printed in place of
# an answer. Failing a real review would be worse than missing an error.
marker_in_result() {
    local text="$1"
    [[ "${#text}" -le 400 ]] || return 1
    [[ "$text" != *$'\n#'* && "$text" != '#'* ]] || return 1
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
CLI_PID=""
trap '[[ -n "$CLI_PID" ]] && kill "$CLI_PID" 2>/dev/null; exit 130' INT
trap '[[ -n "$CLI_PID" ]] && kill "$CLI_PID" 2>/dev/null; exit 143' TERM HUP

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
        # stdout/stderr transcript — banner, echoed prompt, tool chatter —
        # goes to a log that is discarded on success and excerpted into
        # the reason on failure, never into the findings file.
        run_cli "$STDOUT_FILE" - "$CLI_BIN_RESOLVED" exec -o "$CODEX_OUT_FILE"
        if [[ "$CLI_EXIT" -ne 0 ]]; then
            fail "codex exited ${CLI_EXIT}$(bound_note)$(log_excerpt 'codex output' "$STDOUT_FILE")"
        fi
        if marker_in_log "$STDOUT_FILE"; then
            fail "codex reported a quota / rate-limit / authentication error$(log_excerpt 'codex output' "$STDOUT_FILE")"
        fi
        if [[ ! -s "$CODEX_OUT_FILE" ]]; then
            fail "empty response: codex wrote no final message (its --output-last-message file is missing or empty). In headless mode this is what an aborted turn looks like — the exit code stays 0.$(log_excerpt 'codex output' "$STDOUT_FILE")"
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
        if [[ "$IS_ERROR" == "true" ]]; then
            fail "claude returned is_error=true (subtype ${SUBTYPE})${RESULT:+: ${RESULT}}"
        fi
        if [[ "$SUBTYPE" != "success" ]]; then
            fail "claude result subtype is '${SUBTYPE}', not 'success'${RESULT:+: ${RESULT}}"
        fi
        ;;
    copilot)
        # #212/#274: the prompt goes over STDIN, never argv. A single argv
        # string is capped at MAX_ARG_STRLEN (128 KiB on Linux) regardless
        # of ARG_MAX, and review prompts routinely pass that on Deep-tier
        # PRs — putting the prompt on argv fails the exec outright. The
        # guard below is a belt-and-braces bound at exactly that limit: on
        # this stdin path it can only fire where the argv form would have
        # exec-failed anyway, so it never converts a working review into a
        # failure. The real enforcement of the channel is the stdin
        # contract test in test_cross_model_review.sh.
        COPILOT_PROMPT_MAX_BYTES=131072
        PROMPT_BYTES=$(wc -c < "$PROMPT_FILE" | tr -d ' ')
        if [[ "$PROMPT_BYTES" -gt "$COPILOT_PROMPT_MAX_BYTES" ]]; then
            fail "prompt is ${PROMPT_BYTES} bytes, above the ${COPILOT_PROMPT_MAX_BYTES}-byte guard (Linux MAX_ARG_STRLEN). The prompt is passed on stdin, so shrink the review scope rather than the invocation."
        fi
        # -p "" keeps print mode without putting the prompt on argv; -s
        # prints only the agent response (no stats footer), so the output
        # is used as-is — no second strip, which could truncate a review
        # body that happens to contain a footer-looking line.
        run_cli "$STDOUT_FILE" "$STDERR_FILE" \
            "$CLI_BIN_RESOLVED" -p "" --allow-all-tools -s
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
    fail "empty response$(bound_note). In headless mode this is what a permission denial or an aborted turn looks like — the exit code stays 0.$(log_excerpt "${AGENT} stderr" "$STDERR_FILE")"
fi
if marker_in_result "$RESULT"; then
    fail "${AGENT} returned an error in place of a review: ${RESULT}"
fi

# Success. Plain > is safe: the file was truncated above and readers key
# off the caller's completion marker, appended only after we exit.
if ! printf '%s\n' "$RESULT" > "$FINDINGS_FILE"; then
    fail "could not write the findings file: ${FINDINGS_FILE}"
fi
exit 0
