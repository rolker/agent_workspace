#!/usr/bin/env bash
# .agent/scripts/tests/test_plugin_acceptance_helpers.sh
# Hermetic tests for the helpers of the opt-in live suite
# tests/live/plugin_acceptance.sh (#345). The live suite itself starts real
# Claude Code sessions and is never run here; this loads only its helper
# definitions (the session/probe block, cut out by its section markers) and
# drives them with a stub `claude` that prints a canned reply and exits with
# a canned status.
#
# What it pins: a negative case ("this name does NOT reach the probe") is
# evidence only when the session itself ran, so probe() must report a
# timed-out, failed or silent session as a failure, never as "not reached".
# And cleanup(), which deletes under the real ~/.claude when the live suite
# runs: only the suite's own plugin cache entry and the session directories
# named from its own sandbox path.
#
# Run: bash .agent/scripts/tests/test_plugin_acceptance_helpers.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE="$SCRIPT_DIR/live/plugin_acceptance.sh"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/bin"
cat > "$SANDBOX/bin/claude" <<'EOF'
#!/bin/sh
printf '%s' "${STUB_OUT:-}"
exit "${STUB_RC:-0}"
EOF
chmod +x "$SANDBOX/bin/claude"
PATH="$SANDBOX/bin:$PATH"
export PATH
# shellcheck disable=SC2034  # read by the extracted session()
MODEL=stub

# The two definition blocks: session()/session_said() (up to the setup
# marker) and probe()/probe_said() (up to case A's marker).
helpers="$(awk '
    /^SESSION_OUT=""/ { on = 1 }
    /^# -+ setup ---/ { on = 0 }
    /^PROBE_REACHED=0/ { on = 1 }
    /^# -+ A: collision ---/ { on = 0 }
    on
' "$SUITE")"
if [[ "$helpers" != *"probe() {"* || "$helpers" != *"session() {"* ]]; then
    echo "FATAL: could not find the session/probe helpers in $SUITE (section markers moved?)" >&2
    exit 1
fi
eval "$helpers"

expect() {  # <want> <label> <stub output> <stub exit>
    local want="$1" label="$2" got
    STUB_OUT="$3" STUB_RC="$4" probe "$SANDBOX" "/x"
    got=$?
    [[ "$got" -eq "$want" ]] \
        && pass "$label" \
        || fail "$label (probe returned $got, wanted $want)"
}

expect "$PROBE_REACHED" "a session that answers with the marker reached the probe" 'PROBE<<<x>>>' 0
expect "$PROBE_NOT_REACHED" "a session that ran and answered without the marker did not reach it" 'Unknown skill: x' 0
expect "$PROBE_SESSION_FAILED" "a session that exits non-zero is a failed session, not a negative" 'Error: not logged in' 1
expect "$PROBE_SESSION_FAILED" "a timed-out session (exit 124) is a failed session, not a negative" '' 124
expect "$PROBE_SESSION_FAILED" "a session that exits 0 with no output is a failed session, not a negative" '' 0
expect "$PROBE_SESSION_FAILED" "a marker from a session that then failed is not trusted" 'PROBE<<<x>>>' 1

STUB_OUT='line one
line two' STUB_RC=3 probe "$SANDBOX" "/x"
said="$(probe_said "$?")"
[[ "$said" == "session failed (exit 3: line one line two"* ]] \
    && pass "probe_said names the exit status and the output of a failed session" \
    || fail "probe_said gave: $said"

# cleanup() deletes under the real ~/.claude when the live suite runs, so
# pin exactly what it removes: the suite's own plugin cache entry, only
# after an enable, and never a neighbour.
cleanup_def="$(awk '/^ENABLED_ROOTS=\(\)/ { on = 1 } /^trap cleanup EXIT/ { on = 0 } on' "$SUITE")"
if [[ "$cleanup_def" != *"cleanup() {"* ]]; then
    fail "could not find cleanup() in $SUITE (section markers moved?)"
else
    for enabled in yes no; do
        fake_home="$SANDBOX/home-$enabled"
        mkdir -p "$fake_home/.claude/plugins/cache/aw-accept/x" "$fake_home/.claude/plugins/cache/aw-accept-other" \
            "$SANDBOX/root-$enabled" "$SANDBOX/suite-$enabled"
        # shellcheck disable=SC2034  # NAME and ENABLED_ROOTS are read by the eval'd cleanup()
        (
            HOME="$fake_home"
            unset CLAUDE_CONFIG_DIR
            NAME=aw-accept
            SANDBOX="$SANDBOX/suite-$enabled"
            eval "$cleanup_def"
            [[ "$enabled" == yes ]] && ENABLED_ROOTS=("$SANDBOX/../root-$enabled")
            cleanup
        )
        cache="$fake_home/.claude/plugins/cache"
        if [[ "$enabled" == yes ]]; then
            [[ ! -e "$cache/aw-accept" && -d "$cache/aw-accept-other" && ! -e "$SANDBOX/suite-$enabled" ]] \
                && pass "cleanup removes the suite's aw-accept plugin cache, and nothing beside it" \
                || fail "cleanup after an enable left: $(ls "$cache" 2>&1)"
        else
            [[ -d "$cache/aw-accept" ]] \
                && pass "cleanup leaves the plugin cache alone when the suite enabled nothing" \
                || fail "cleanup removed the aw-accept cache without having enabled anything"
        fi
    done
fi

# cleanup() also removes the ~/.claude/projects directories the sessions
# left, and it deletes under the real ~/.claude, so pin that it removes
# exactly those named from this run's sandbox path (the path itself, and
# paths below it) and nothing else: not a name that merely starts with it,
# not another run's, not an unrelated one -- and nothing at all for a
# sandbox without the suite's mktemp name.
if [[ "$cleanup_def" != *"session_dirs() {"* ]]; then
    fail "could not find session_dirs() in $SUITE"
else
    enc() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }
    for kind in suite plain; do
        fake_home="$SANDBOX/home-sessions-$kind"
        proj="$fake_home/.claude/projects"
        case "$kind" in
            suite) run_sb="$SANDBOX/aw-plugin-accept.Ab3dEf9HiJ" ;;
            plain) run_sb="$SANDBOX/tmp.Ab3dEf9HiJ" ;;
        esac
        mkdir -p "$run_sb"
        e="$(enc "$run_sb")"
        other="$(enc "$SANDBOX/aw-plugin-accept.ZZ9yX8wV7u")"
        mine=("$e" "$e-proj" "$e-proj-worktrees-wt" "$e-famg-inst")
        keep=("${e}X" "${e}0-proj" "$other" "$other-proj" "-home-user-project")
        for d in "${mine[@]}" "${keep[@]}"; do mkdir -p "$proj/$d/memory"; done
        # shellcheck disable=SC2034  # NAME and ENABLED_ROOTS are read by the eval'd cleanup()
        (
            HOME="$fake_home"
            unset CLAUDE_CONFIG_DIR
            NAME=aw-accept
            SANDBOX="$run_sb"
            eval "$cleanup_def"
            ENABLED_ROOTS=()
            cleanup
        )
        left_mine=0; left_keep=0
        for d in "${mine[@]}"; do [[ -e "$proj/$d" ]] && left_mine=$((left_mine + 1)); done
        for d in "${keep[@]}"; do [[ -d "$proj/$d" ]] && left_keep=$((left_keep + 1)); done
        if [[ "$kind" == suite ]]; then
            [[ "$left_mine" -eq 0 && "$left_keep" -eq "${#keep[@]}" ]] \
                && pass "cleanup removes exactly the session directories named from its sandbox path" \
                || fail "cleanup session dirs: $left_mine of ${#mine[@]} own left, $left_keep of ${#keep[@]} others kept ($(ls "$proj" | tr '\n' ' '))"
        else
            [[ "$left_mine" -eq "${#mine[@]}" && "$left_keep" -eq "${#keep[@]}" ]] \
                && pass "cleanup removes no session directory for a sandbox without the suite's mktemp name" \
                || fail "cleanup removed session dirs for a plain sandbox ($(ls "$proj" | tr '\n' ' '))"
        fi
    done
fi

echo ""
echo "test_plugin_acceptance_helpers: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
