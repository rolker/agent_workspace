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
# named from its own sandbox path, and, after a user-scope enable, only this
# run's two user-scope entries. And the user-scope cases' judging helpers.
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
# marker) and probe()/probe_said() (up to the per-root cases' marker, which
# opens an `if` block the extract must not take half of).
helpers="$(awk '
    /^SESSION_OUT=""/ { on = 1 }
    /^# -+ setup ---/ { on = 0 }
    /^PROBE_REACHED=0/ { on = 1 }
    /^# =+ per-root cases ===/ { on = 0 }
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
        got="$(cd "$work" && TMPDIR="$2" PATH="${3:+$3:}$PATH" bash -c "$cleanup_def"$'\n''new_sandbox' 2>/dev/null)"; rc=$?
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

# sandbox_install() runs the copy's installer with the sandbox HOME and no
# CLAUDE_CONFIG_DIR, however the suite was started; and it is the only way
# the suite runs that installer.
siw="$SANDBOX/si-work"
mkdir -p "$siw/W/.agent/scripts" "$siw/sb/home"
printf '#!/bin/sh\necho "cfg=[${CLAUDE_CONFIG_DIR:-}] home=[$HOME] bin=[$AGENT_WORKSPACE_CLAUDE_BIN] args=[$*]"\n' > "$siw/W/.agent/scripts/user_tier_install.sh"
got="$(CLAUDE_CONFIG_DIR=/owner/real/config W="$siw/W" SANDBOX="$siw/sb" bash -c "$cleanup_def"$'\n''sandbox_install --check')"
[[ "$got" == "cfg=[] home=[$siw/sb/home] bin=[$siw/sb/bin/claude] args=[--check]" ]] \
    && pass "sandbox_install drops an inherited CLAUDE_CONFIG_DIR and uses the sandbox HOME and stub" \
    || fail "sandbox_install environment: $got"
rm -rf "$siw"
direct="$(grep -n 'bash "\$W/.agent/scripts/user_tier_install.sh"' "$SUITE" | grep -v '^[0-9]*:        bash "\$W/.agent/scripts/user_tier_install.sh" "\$@"$' || true)"
[[ -z "$direct" ]] \
    && pass "the live suite runs the copy's installer only through sandbox_install" \
    || fail "the live suite runs the installer directly: $direct"

# cleanup()'s user-scope removal: when the run enabled its test plugin at
# user scope (USER_ENABLED=1), cleanup runs exactly the two --scope user
# removals for THIS run's name, from a directory in no git repository,
# leaves the real agent-workspace entries alone, and removes the plugin
# cache; when the removal does not take, it says so and prints the two
# hand-removal commands.
real_def="$(awk '/^REAL_SETTINGS=/ { on = 1 } /^if \[\[ "\$RUN_USER" == 1 \]\]; then/ { on = 0 } on' "$SUITE")"
if [[ "$real_def" != *"user_removal_lines() {"* || "$cleanup_def" != *"user_scope_remove() {"* ]]; then
    fail "could not find REAL_SETTINGS/user_removal_lines() or user_scope_remove() in $SUITE (section markers moved?)"
else
    usw="$SANDBOX/us-work"
    for takes in yes no; do
        rm -rf "$usw"
        mkdir -p "$usw/bin" "$usw/home/.claude/plugins/cache/aw-accept-4242/x" "$usw/home/.claude/plugins/cache/aw-accept-42" \
            "$usw/aw-plugin-accept.us1"
        jq -n '{enabledPlugins: {"agent-workspace@agent-workspace": true, "aw-accept-4242@aw-accept-4242": true},
            extraKnownMarketplaces: {"agent-workspace": {source: {source: "directory", path: "/real"}},
                                     "aw-accept-4242": {source: {source: "directory", path: "/copy"}}}}' \
            > "$usw/home/.claude/settings.json"
        cat > "$usw/bin/claude" <<'STUBEOF'
#!/usr/bin/env bash
printf '%s|%s\n' "$PWD" "$*" >> "$US_LOG"
[[ "$US_TAKES" == yes ]] || exit 0
f="$HOME/.claude/settings.json"
case "$1 $2 $3" in
    "plugin uninstall "*) jq --arg id "$3" 'del(.enabledPlugins[$id])' "$f" > "$f.tmp" && mv "$f.tmp" "$f" ;;
    "plugin marketplace remove") jq --arg m "$4" 'del(.extraKnownMarketplaces[$m])' "$f" > "$f.tmp" && mv "$f.tmp" "$f" ;;
esac
STUBEOF
        chmod +x "$usw/bin/claude"
        : > "$usw/cli.log"
        out="$(cd "$usw" && HOME="$usw/home" PATH="$usw/bin:$PATH" US_LOG="$usw/cli.log" US_TAKES="$takes" \
            NAME=aw-accept-4242 SANDBOX="$usw/aw-plugin-accept.us1" \
            bash -c "unset CLAUDE_CONFIG_DIR; $real_def"$'\n'"$cleanup_def"$'\n''ENABLED_ROOTS=(); USER_ENABLED=1; USER_TOUCHED=1; cleanup' 2>&1)"
        calls="$(cut -d'|' -f2 "$usw/cli.log" | tr '\n' ';')"
        cwds="$(cut -d'|' -f1 "$usw/cli.log" | sort -u)"
        if [[ "$takes" == yes ]]; then
            [[ "$calls" == "plugin uninstall aw-accept-4242@aw-accept-4242 --scope user;plugin marketplace remove aw-accept-4242 --scope user;" ]] \
                && pass "cleanup removes this run's user-scope enable with exactly the two --scope user calls, for its own name" \
                || fail "cleanup's user-scope removal called: '$calls'"
            [[ "$cwds" == "$usw/aw-plugin-accept.us1" || "$cwds" == "/" ]] \
                && pass "...from a directory in no git repository (the sandbox)" \
                || fail "...from '$cwds'"
            jq -e '(.enabledPlugins | has("aw-accept-4242@aw-accept-4242") | not) and (.extraKnownMarketplaces | has("aw-accept-4242") | not)
                   and .enabledPlugins["agent-workspace@agent-workspace"] == true and .extraKnownMarketplaces["agent-workspace"].source.path == "/real"' \
                "$usw/home/.claude/settings.json" >/dev/null \
                && pass "...leaving neither of its entries, and the real agent-workspace entries as they were" \
                || fail "...user settings after cleanup: $(jq -c . "$usw/home/.claude/settings.json")"
            [[ ! -e "$usw/home/.claude/plugins/cache/aw-accept-4242" && -d "$usw/home/.claude/plugins/cache/aw-accept-42" && "$out" != *WARNING* ]] \
                && pass "...and removes its own plugin cache (not another run's), with no warning" \
                || fail "...cache or warning after a user-scope cleanup (out=$out; cache: $(ls "$usw/home/.claude/plugins/cache"))"
        else
            [[ "$out" == *"WARNING: $usw/home/.claude/settings.json still has this run's entries"* \
               && "$out" == *"claude plugin uninstall aw-accept-4242@aw-accept-4242 --scope user"* \
               && "$out" == *"claude plugin marketplace remove aw-accept-4242 --scope user"* ]] \
                && pass "cleanup whose user-scope removal does not take warns and prints both hand-removal commands" \
                || fail "cleanup when the user-scope removal does not take (out=$out)"
        fi
    done
    rm -rf "$usw"
fi

# The user-scope cases' judging helpers (#446): a case is judged from the
# session's init command list when there is one, and from the probes only
# when there is none; a stop condition is clear, FIRES or UNDECIDED.
judge_def="$(awk '/^# us_got <id> bare\|plug:/ { on = 1 } /^# us_finish: / { on = 0 } on' "$SUITE")"
if [[ "$judge_def" != *"us_got() {"* || "$judge_def" != *"us_verdict() {"* || "$judge_def" != *"us_expect() {"* ]]; then
    fail "could not find us_got()/us_expect()/us_verdict() in $SUITE (section markers moved?)"
else
    # shellcheck disable=SC2034  # NAME and the U_* arrays are read by the eval'd helpers
    got="$(
        NAME=aw-accept-4242
        PROBE_REACHED=0 PROBE_NOT_REACHED=1 PROBE_SESSION_FAILED=2
        declare -A U_BARE=() U_PLUG=() U_BARE_SAID=() U_PLUG_SAID=() U_LISTED=()
        eval "$judge_def"
        # Both listed, though the prefixed probe was "not reached" (U4, 2026-11-12).
        U_LISTED[A]="zz-probe,aw-accept-4242:zz-probe"; U_BARE[A]=0; U_PLUG[A]=1
        # Only the prefixed name listed, though the bare probe "reached" (U5).
        U_LISTED[B]="aw-accept-4242:zz-probe"; U_BARE[B]=0; U_PLUG[B]=0
        # An empty list: evidence of "not listed".
        U_LISTED[C]="<none>"; U_BARE[C]=2; U_PLUG[C]=2
        # No init line: the probes decide; a failed one is unknown.
        U_LISTED[D]="<no init line>"; U_BARE[D]=0; U_PLUG[D]=2
        # Slash-prefixed entries count too.
        U_LISTED[E]="/zz-probe"; U_BARE[E]=1; U_PLUG[E]=1
        for id in A B C D E; do printf '%s=%s,%s ' "$id" "$(us_got "$id" bare)" "$(us_got "$id" plug)"; done
        printf '| %s | %s | %s' "$(us_verdict yes yes no no)" "$(us_verdict yes no unknown no)" "$(us_verdict unknown yes yes yes)"
        pass() { printf ' P:%s' "$1"; }
        fail() { printf ' F:%s' "$1"; }
        us_expect A yes yes "a" >/dev/null; us_expect A yes yes "a"; us_expect B - no "b"
    )"
    [[ "$got" == "A=yes,yes B=no,yes C=no,no D=yes,unknown E=yes,no | clear | FIRES | UNDECIDED"*" P:A: a F:B: wanted bare zz-probe listed - and aw-accept-4242:zz-probe listed no; got no and yes (init command list: aw-accept-4242:zz-probe)" ]] \
        && pass "the user-scope cases are judged from the init command list, the probes only without one; stop checks clear / FIRES / UNDECIDED" \
        || fail "user-scope judging helpers: $got"
fi

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
