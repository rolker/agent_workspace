#!/usr/bin/env bash
# Run one headless agy (Gemini CLI successor) review turn and validate it.
#
# Usage:
#   _agy_review.sh <agy-bin> <prompt-file> <findings-file> [<print-timeout>]
#
# Called by cross_model_review.sh for the "gemini" agent (in its own
# background job alongside the other agents, ADR-0015), so there is one
# invocation and one success test.
#
# Why this exists (issues #274, #288):
#   * agy print mode takes the prompt as the -p argument value; large PR
#     prompts exceed the kernel's per-argument limit (~128 KiB) and fail
#     with "Argument list too long". Its stream-json input mode reads the
#     prompt from stdin instead, one NDJSON message per line.
#   * When the model calls a tool that headless mode cannot approve (any
#     shell command), agy auto-denies it, prints a notice on stderr, and
#     exits 0 with an EMPTY response. The exit code is therefore not a
#     usable failure signal; the terminal `result` event is.
#   * When --print-timeout expires mid-turn agy also exits 0 with
#     status SUCCESS and a partial (possibly empty) response; the only
#     signal is a stderr line containing "print timeout after".
#
# Contract:
#   * This script OWNS the findings file: it is truncated first thing, and
#     receives either the review text or a failure reason. The caller must
#     not redirect stdout onto it. The caller appends the
#     "--- Review complete ---" / "--- Review failed ---" marker.
#   * Exit 0 only when agy exited 0, emitted a result event with
#     status SUCCESS and a non-empty response, and did not time out.
#     Exit 1 otherwise (findings file holds the reason). Exit 2 on usage
#     errors (also recorded in the findings file when it is writable).
#   * The caller wraps this helper in an outer `timeout` backstop set
#     ABOVE <print-timeout> (cross_model_review.sh: GEMINI_BACKSTOP). The
#     print-timeout handling here stays the primary path — the backstop
#     only fires if this helper never returns at all, so it cannot race
#     the timeout-then-partial-response contract above.
#   * No temp files survive any exit path this script can observe: the
#     EXIT trap covers normal exits and the signal traps turn a kill into
#     an exit so it still fires. SIGKILL is the exception — no trap runs,
#     so the `agy-review.XXXXXX` dir would be left behind. The only sender
#     is `timeout -k` on the caller's backstop (a wedged helper), and
#     cross_model_review.sh closes that gap by pointing TMPDIR at a
#     scratch root it owns and removes itself.
#   * All diagnostics go to stderr; stdout is unused.
#
# Verified against agy 1.2.8 (2026-09-22): see the plan for issue #288.

set -uo pipefail

usage() {
    echo "Usage: $0 <agy-bin> <prompt-file> <findings-file> [<print-timeout>]" >&2
}

if [[ $# -lt 3 || $# -gt 4 ]]; then
    usage
    exit 2
fi

AGY_BIN="$1"
PROMPT_FILE="$2"
FINDINGS_FILE="$3"
PRINT_TIMEOUT="${4:-30m}"

# Truncate the findings file before anything else can fail. Without this a
# guard failure would leave the previous run's review in place under a
# fresh "--- Review failed ---" marker, and review-code would read stale
# findings as current (the #288 failure class in a different coat).
if ! : > "$FINDINGS_FILE"; then
    echo "ERROR: cannot write findings file: ${FINDINGS_FILE}" >&2
    exit 2
fi

# Write a failure reason into the findings file and exit 1.
fail() {
    local reason="$1"
    {
        echo "agy review did not produce a usable result."
        echo ""
        echo "Reason: ${reason}"
    } > "$FINDINGS_FILE"
    echo "ERROR: agy review failed: ${reason}" >&2
    exit 1
}

if ! command -v jq >/dev/null 2>&1; then
    fail "jq is required to build the stream-json prompt and parse agy's result event (see bootstrap.sh)"
fi
if [[ ! -r "$PROMPT_FILE" ]]; then
    fail "prompt file not readable: ${PROMPT_FILE}"
fi
# Accept a bare name (resolved on PATH) or a path; `test -x` alone only
# looks at the current directory for a bare name.
AGY_BIN_RESOLVED=$(command -v "$AGY_BIN" 2>/dev/null || true)
if [[ -z "$AGY_BIN_RESOLVED" || ! -x "$AGY_BIN_RESOLVED" ]]; then
    fail "agy binary not found or not executable: ${AGY_BIN}"
fi

# Temp files: the NDJSON input line, agy's stdout (event stream), and agy's
# stderr. Removed on every exit path — the EXIT trap covers normal exits
# and the signal traps turn a kill into an exit so it still fires; on
# failure the useful parts are copied into the findings file first.
TMP_DIR=$(mktemp -d -t agy-review.XXXXXX) || fail "mktemp failed"
trap 'rm -rf "$TMP_DIR"' EXIT
# Armed before agy is launched (AGY_PID empty until then) so a signal in
# the launch window cannot leave agy running behind an exited helper.
# TERM is the live path under cross_model_review.sh: this helper runs as a
# background child of a non-interactive shell, where bash makes SIGINT
# ignored (and an ignored signal cannot be trapped). The INT trap is for a
# direct interactive invocation of this script, where Ctrl-C does arrive.
AGY_PID=""
trap '[[ -n "$AGY_PID" ]] && kill "$AGY_PID" 2>/dev/null; exit 130' INT
trap '[[ -n "$AGY_PID" ]] && kill "$AGY_PID" 2>/dev/null; exit 143' TERM HUP
INPUT_FILE="${TMP_DIR}/input.ndjson"
STREAM_FILE="${TMP_DIR}/stream.ndjson"
STDERR_FILE="${TMP_DIR}/stderr.txt"

# Exactly one NDJSON line: jq -Rs slurps the whole prompt as a single
# string and escapes it (size bounded only by memory); -c keeps the
# message on one line, which is the stream-json contract.
if ! jq -c -Rs '{event: "user", message: {role: "user", content: .}}' "$PROMPT_FILE" > "$INPUT_FILE"; then
    fail "could not encode the prompt as a stream-json message"
fi

# No pipeline here: the exit status is agy's own, not jq's. `-p=` is the
# verified spelling for "print mode, prompt comes from stdin" on agy 1.2.8:
# a bare -p swallows the next flag as its prompt and `-p ""` is rejected
# as an empty prompt.
# agy runs as a background child and is waited on, so a TERM/INT sent
# to this helper (cross_model_review.sh's cleanup on interrupt) reaches
# agy at once instead of being deferred until the turn ends on its own.
"$AGY_BIN_RESOLVED" \
    --input-format=stream-json \
    --output-format=stream-json \
    --print-timeout "$PRINT_TIMEOUT" \
    --disable-slash-commands \
    -p= < "$INPUT_FILE" > "$STREAM_FILE" 2> "$STDERR_FILE" &
AGY_PID=$!
AGY_EXIT=0
wait "$AGY_PID" || AGY_EXIT=$?
AGY_PID=""

# Last 20 lines of stderr, for failure reports: a fatal error lands at
# the end, after any startup chatter.
stderr_excerpt() {
    if [[ -s "$STDERR_FILE" ]]; then
        printf '\nagy stderr (last 20 lines):\n'
        tail -n 20 "$STDERR_FILE"
    fi
}

# The last result event wins (stream-json emits exactly one per turn).
# Read line-wise with fromjson? so a stray non-JSON stdout line (update
# banner, notice) is skipped instead of aborting the whole parse.
RESULT_JSON=$(jq -R -c 'fromjson? | select(.event == "result") | .result' "$STREAM_FILE" 2>/dev/null | tail -n 1 || true)

if [[ "$AGY_EXIT" -ne 0 ]]; then
    fail "agy exited ${AGY_EXIT}$(stderr_excerpt)"
fi
# Timeout before the result-event check: an expiry can truncate the
# stream, and "print timeout" is the right reason then, not "no result".
if grep -q 'print timeout after' "$STDERR_FILE" 2>/dev/null; then
    fail "print timeout (${PRINT_TIMEOUT}) expired with the turn in progress; partial output discarded$(stderr_excerpt)"
fi
if [[ -z "$RESULT_JSON" ]]; then
    fail "agy emitted no result event$(stderr_excerpt)"
fi

# One jq call per field. (A single @tsv pass was tried and rejected: tab
# is IFS whitespace, so `read` collapses an empty field and shifts the
# error message into the wrong variable.) `.error` may be a string or an
# object, hence tostring.
STATUS=$(jq -r '.status // "MISSING"' <<< "$RESULT_JSON")
RESPONSE=$(jq -r '.response // ""' <<< "$RESULT_JSON")
ERROR_MSG=$(jq -r '(.error // "") | tostring' <<< "$RESULT_JSON")
DENIED=$(jq -r '(.denied_actions // []) | map(.display_name // .action) | join(", ")' <<< "$RESULT_JSON")
DENIED_COUNT=$(jq -r '(.denied_actions // []) | length' <<< "$RESULT_JSON")

if [[ "$STATUS" != "SUCCESS" ]]; then
    fail "result status ${STATUS}${ERROR_MSG:+: ${ERROR_MSG}}$(stderr_excerpt)"
fi
if [[ -z "${RESPONSE//[[:space:]]/}" ]]; then
    if [[ "$DENIED_COUNT" -gt 0 ]]; then
        fail "empty response; ${DENIED_COUNT} tool action(s) were auto-denied in headless mode (${DENIED}). The reviewer needs the diff only; it must not run shell commands.$(stderr_excerpt)"
    fi
    fail "empty response${ERROR_MSG:+: ${ERROR_MSG}}$(stderr_excerpt)"
fi

# Success. Plain > is safe: the file was truncated above and readers key
# off the caller's completion marker, appended only after we exit.
if ! printf '%s\n' "$RESPONSE" > "$FINDINGS_FILE"; then
    fail "could not write the findings file: ${FINDINGS_FILE}"
fi
if [[ "$DENIED_COUNT" -gt 0 ]]; then
    if ! printf '\n> Note: %s tool action(s) were denied in headless mode (%s); the review ran with less context than the model asked for.\n' \
        "$DENIED_COUNT" "$DENIED" >> "$FINDINGS_FILE"; then
        fail "could not write the findings file: ${FINDINGS_FILE}"
    fi
fi
exit 0
