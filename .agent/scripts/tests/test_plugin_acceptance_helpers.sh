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
cleanup_def="$(awk '/^ENABLED_ROOTS=\(\)/ { on = 1 } /^SANDBOX="\$\(new_sandbox\)"/ { on = 0 } on' "$SUITE")"
if [[ "$cleanup_def" != *"cleanup() {"* ]]; then
    fail "could not find cleanup() in $SUITE (section markers moved?)"
else
    for enabled in yes no; do
        fake_home="$SANDBOX/home-$enabled"
        mkdir -p "$fake_home/.claude/plugins/cache/aw-accept-4242/x" "$fake_home/.claude/plugins/cache/aw-accept-42" \
            "$fake_home/.claude/plugins/cache/aw-accept-424242" "$fake_home/.claude/plugins/cache/aw-accept" \
            "$SANDBOX/root-$enabled" "$SANDBOX/aw-plugin-accept.suite-$enabled"
        # shellcheck disable=SC2034  # NAME and ENABLED_ROOTS are read by the eval'd cleanup()
        (
            HOME="$fake_home"
            unset CLAUDE_CONFIG_DIR
            NAME=aw-accept-4242
            SANDBOX="$SANDBOX/aw-plugin-accept.suite-$enabled"
            eval "$cleanup_def"
            [[ "$enabled" == yes ]] && ENABLED_ROOTS=("$SANDBOX/../root-$enabled")
            cleanup
        )
        cache="$fake_home/.claude/plugins/cache"
        if [[ "$enabled" == yes ]]; then
            [[ ! -e "$cache/aw-accept-4242" && -d "$cache/aw-accept-42" && -d "$cache/aw-accept-424242" \
                  && -d "$cache/aw-accept" && ! -e "$SANDBOX/aw-plugin-accept.suite-$enabled" ]] \
                && pass "cleanup removes this run's own plugin cache, and not another run's beside it" \
                || fail "cleanup after an enable left: $(ls "$cache" 2>&1)"
        else
            [[ -d "$cache/aw-accept-4242" ]] \
                && pass "cleanup leaves the plugin cache alone when the suite enabled nothing" \
                || fail "cleanup removed this run's plugin cache without having enabled anything"
        fi
    done
fi

# The sandbox (round-4 must-fix). `cd ""` succeeds in bash, so a failed
# mktemp used to leave SANDBOX as the directory the suite ran from, which
# the EXIT trap then deleted. new_sandbox() must fail, printing nothing,
# when mktemp fails or prints nothing; cleanup() must refuse to delete an
# empty SANDBOX, the current directory, or one without the suite's name.
if [[ "$cleanup_def" != *"new_sandbox() {"* || "$cleanup_def" != *"sandbox_safe() {"* ]]; then
    fail "could not find new_sandbox()/sandbox_safe() in $SUITE"
else
    work="$SANDBOX/sb-work"
    mkdir -p "$work/bin" "$work/tmp"
    printf '#!/bin/sh\nexit 0\n' > "$work/bin/mktemp"      # succeeds, prints nothing
    chmod +x "$work/bin/mktemp"
    try_new() {  # <label> <TMPDIR> [PATH prefix]: new_sandbox must fail, printing nothing
        local got rc
        got="$(cd "$work" && TMPDIR="$2" PATH="${3:+$3:}$PATH" bash -c "$cleanup_def"$'\n''new_sandbox')"; rc=$?
        [[ "$rc" -ne 0 && -z "$got" && -d "$work" ]] \
            && pass "new_sandbox fails, printing nothing, when $1" \
            || fail "new_sandbox when $1 (rc=$rc printed='$got')"
    }
    try_new "mktemp fails (TMPDIR not on disk)" "$work/no-such-dir"
    try_new "mktemp succeeds but prints nothing" "$work/tmp" "$work/bin"
    got="$(cd "$work" && TMPDIR="$work/tmp" bash -c "$cleanup_def"$'\n''new_sandbox')"; rc=$?
    [[ "$rc" -eq 0 && -d "$got" && "$(basename "$got")" == aw-plugin-accept.* && "$got" == "$(cd "$work/tmp" && pwd -P)"/* ]] \
        && pass "new_sandbox prints a fresh aw-plugin-accept.* directory under TMPDIR" \
        || fail "new_sandbox normal case (rc=$rc got='$got')"
    # cleanup() over a SANDBOX that is not its own: each must survive.
    here="$work/aw-plugin-accept.cwd"      # named like a sandbox, but the cwd
    mkdir -p "$here" "$work/plain-dir"
    for sb in "" "$here" "$work/plain-dir"; do
        # shellcheck disable=SC2034  # read by the eval'd cleanup()
        out="$(cd "$here" && HOME="$work/home" NAME=aw-accept-4242 SANDBOX="$sb" bash -c "unset CLAUDE_CONFIG_DIR; $cleanup_def"$'\n''ENABLED_ROOTS=(); cleanup' 2>&1)"
        [[ -d "$here" && -d "$work/plain-dir" && "$out" == *"not removing sandbox"* ]] \
            && pass "cleanup refuses to remove SANDBOX='${sb#"$work"/}' (empty, the cwd, or not the suite's)" \
            || fail "cleanup with SANDBOX='${sb#"$work"/}' (out=$out)"
    done
    rm -rf "$work"
fi

# cleanup()'s last resort for the machine record: only when the record
# still has THIS run's name, and then one `marketplace remove <that name>`
# -- never another entry's.
kmw="$SANDBOX/km-work"
mkdir -p "$kmw/bin" "$kmw/aw-plugin-accept.km1" "$kmw/home/.claude/plugins"
printf '#!/bin/sh\necho "$*" >> "%s"\n' "$kmw/cli.log" > "$kmw/bin/claude"
chmod +x "$kmw/bin/claude"
for has in yes no; do
    : > "$kmw/cli.log"
    mkdir -p "$kmw/aw-plugin-accept.km1"    # cleanup() removes it each time
    if [[ "$has" == yes ]]; then
        echo '{"aw-accept-4242": {"source": {"path": "/x"}}, "agent-workspace": {"source": {"path": "/y"}}}' > "$kmw/home/.claude/plugins/known_marketplaces.json"
    else
        echo '{"aw-accept-42": {"source": {"path": "/x"}}, "agent-workspace": {"source": {"path": "/y"}}}' > "$kmw/home/.claude/plugins/known_marketplaces.json"
    fi
    (cd "$kmw" && HOME="$kmw/home" PATH="$kmw/bin:$PATH" NAME=aw-accept-4242 SANDBOX="$kmw/aw-plugin-accept.km1" \
        bash -c "unset CLAUDE_CONFIG_DIR; $cleanup_def"$'\n''ENABLED_ROOTS=(); cleanup' >/dev/null 2>&1)
    calls="$(tr '\n' ';' < "$kmw/cli.log")"
    if [[ "$has" == yes ]]; then
        [[ "$calls" == "plugin marketplace remove aw-accept-4242;" ]] \
            && pass "cleanup removes a machine record still holding this run's name, and only that one" \
            || fail "cleanup's machine-record fallback called: '$calls'"
    else
        [[ -z "$calls" ]] \
            && pass "cleanup runs no CLI for the machine record when it has no entry of this run's name" \
            || fail "cleanup called the CLI for another run's record: '$calls'"
    fi
done
rm -rf "$kmw"

# The encoding itself, pinned to literal names rather than re-derived with
# the implementation's own sed: every character but [A-Za-z0-9] becomes
# `-` (as Claude Code named the real directories earlier runs left, e.g.
# /tmp/claude-1000/-home-... -> -tmp-claude-1000--home-...). session_dirs
# only reads the sandbox path as a string, so it need not exist.
lit="$SANDBOX/lit-projects"
mkdir -p "$lit/-a-b-c-aw-plugin-accept-Q1w2" "$lit/-a-b-c-aw-plugin-accept-Q1w2-proj-wt" \
    "$lit/-a-b_c-aw-plugin-accept-Q1w2" "$lit/-a-b-c-aw-plugin-accept.Q1w2" "$lit/-a-b-c-aw-plugin-accept-Q1w2x"
got="$(eval "$cleanup_def"; session_dirs "$lit" "/a/b_c/aw-plugin-accept.Q1w2" | xargs -n1 basename | sort | tr '\n' ' ')"
[[ "$got" == "-a-b-c-aw-plugin-accept-Q1w2 -a-b-c-aw-plugin-accept-Q1w2-proj-wt " ]] \
    && pass "session_dirs encodes /a/b_c/aw-plugin-accept.Q1w2 as -a-b-c-aw-plugin-accept-Q1w2, matching it and paths below it only" \
    || fail "session_dirs literal encoding (got: '$got')"
rm -rf "$lit"

# The plugin name is per run: the CLI keys its machine-level records and
# plugin cache by it, so two concurrent runs sharing one would remove each
# other's. Two processes evaluating the suite's NAME line must differ.
name_line="$(grep -m1 '^NAME=' "$SUITE")"
n1="$(bash -c "$name_line; printf '%s' \"\$NAME\"")"
n2="$(bash -c "$name_line; printf '%s' \"\$NAME\"")"
[[ -n "$n1" && "$n1" != "$n2" && "$n1" == aw-accept-* ]] \
    && pass "each live run gets its own plugin name ($n1, $n2)" \
    || fail "two live runs would share the plugin name ('$n1', '$n2' from: $name_line)"

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
        mine=("$e" "$e-proj" "$e-proj-wt" "$e-famg-inst")
        keep=("${e}X" "${e}0-proj" "$other" "$other-proj" "-home-user-project")
        for d in "${mine[@]}" "${keep[@]}"; do mkdir -p "$proj/$d/memory"; done
        # shellcheck disable=SC2034  # NAME and ENABLED_ROOTS are read by the eval'd cleanup()
        (
            HOME="$fake_home"
            unset CLAUDE_CONFIG_DIR
            NAME=aw-accept-4242
            SANDBOX="$run_sb"
            eval "$cleanup_def"
            ENABLED_ROOTS=()
            cleanup
        ) 2>/dev/null
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
