#!/usr/bin/env bash
# .agent/scripts/tests/test_commit_identity.sh
# Issue #455: agent and accepted commit emails derive from the checkout's
# `git config user.email`; no address is hardcoded. Covers the shared helper
# .agent/scripts/identity_base.py, the hook .agent/hooks/check-commit-identity.py,
# .agent/scripts/framework_config.sh, .agent/scripts/set_git_identity_env.sh,
# .agent/scripts/configure_git_identity.sh and
# .agent/scripts/detect_agent_identity.sh.
#
# Hermetic: every command runs under `env -i` with HOME and GIT_CONFIG_GLOBAL
# pointed into a mktemp sandbox and GIT_CONFIG_NOSYSTEM=1, so this machine's
# git config is never read. Fixture addresses use example.org / example.net.
# Run: bash .agent/scripts/tests/test_commit_identity.sh

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOK="$REAL_ROOT/.agent/hooks/check-commit-identity.py"
HELPER="$REAL_ROOT/.agent/scripts/identity_base.py"
SET_ENV="$REAL_ROOT/.agent/scripts/set_git_identity_env.sh"
CONFIGURE="$REAL_ROOT/.agent/scripts/configure_git_identity.sh"
DETECT="$REAL_ROOT/.agent/scripts/detect_agent_identity.sh"
PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

DERIVED_CMD='source .agent/scripts/set_git_identity_env.sh --agent <framework> "<model-id>"'
UNSET_TEXT='git user.email is not set'
MALFORMED_TEXT='is not a usable address'

# mk_repo [global-email] -> prints the sandbox dir; repo is <dir>/repo, the
# global config file <dir>/gitconfig (empty when no email is given).
mk_repo() {
    local sb
    sb="$(mktemp -d -p "$SANDBOX")"
    mkdir -p "$sb/home"
    : > "$sb/gitconfig"
    if [ -n "${1:-}" ]; then
        git config --file "$sb/gitconfig" user.email "$1"
    fi
    git -c init.defaultBranch=main init --quiet "$sb/repo"
    echo "$sb"
}

# run_in <sb> [VAR=value...] -- <command...>: hermetic env, cwd = the repo.
run_in() {
    local sb="$1"; shift
    local -a extra=()
    while [ $# -gt 0 ] && [ "$1" != "--" ]; do extra+=("$1"); shift; done
    shift
    (cd "$sb/repo" && env -i PATH="$PATH" HOME="$sb/home" USER=tester \
        GIT_CONFIG_GLOBAL="$sb/gitconfig" GIT_CONFIG_NOSYSTEM=1 \
        "${extra[@]}" "$@")
}

hook_in() {  # <sb> [VAR=value...] -> output; rc in HOOK_RC
    local sb="$1"; shift
    HOOK_OUT="$(run_in "$sb" "$@" -- python3 "$HOOK" 2>&1)"
    HOOK_RC=$?
}

# ---- helper ----
echo "TEST: identity_base.py derives the base and agent emails"
sb="$(mk_repo "dev+claude-code@example.org")"
out="$(run_in "$sb" -- python3 "$HELPER" base 2>&1)"
[ "$out" = "dev@example.org" ] && pass "a configured +suffix is removed from the base" || fail "base (got: $out)"
out="$(run_in "$sb" -- python3 "$HELPER" agent codex 2>&1)"
[ "$out" = "dev+codex@example.org" ] && pass "agent codex -> <local>+codex@<domain>" || fail "agent (got: $out)"

for bad in "foo" "@example.org" "dev@" "a@b@c" "+x@example.org" "<dev@example.org>" "dev@." "dev@example..org" \
    "dev@example.org," "dev@exa mple.org" 'dev$(id)@example.org' 'dev;x@example.org' 'dev"@example.org' 'dev`x`@example.org'; do
    sb="$(mk_repo "$bad")"
    out="$(run_in "$sb" -- python3 "$HELPER" base 2>&1)"; rc=$?
    [[ $rc -eq 1 && "$out" == *"$MALFORMED_TEXT"* && "$out" == *"$bad"* && "$out" != *"$UNSET_TEXT"* ]] \
        && pass "malformed '$bad' fails with its own message showing the value" \
        || fail "malformed '$bad' (rc=$rc, got: $out)"
done
for good in "dev@localhost" "first.last-x_y%z@sub-1.example.org" "dev+claude-code@example.org"; do
    sb="$(mk_repo "$good")"
    out="$(run_in "$sb" -- python3 "$HELPER" base 2>&1)"; rc=$?
    [ $rc -eq 0 ] && pass "plain address '$good' is accepted as a base" || fail "good '$good' (rc=$rc, got: $out)"
done
out="$(run_in "$sb" -- python3 "$HELPER" agent 'a;b' 2>&1)"; rc=$?
[ $rc -eq 2 ] && pass "a suffix with a shell metacharacter is refused" || fail "suffix 'a;b' (rc=$rc, got: $out)"
sb="$(mk_repo)"
out="$(run_in "$sb" -- python3 "$HELPER" agent codex 2>&1)"; rc=$?
[[ $rc -eq 1 && "$out" == *"$UNSET_TEXT"* && "$out" == *'git config --global user.email'* ]] \
    && pass "unset email: helper exits 1 with the fix" || fail "unset helper (rc=$rc, got: $out)"

# ---- hook ----
echo "TEST: the hook accepts the base and <local>+<x>@<domain> of an arbitrary configured email"
sb="$(mk_repo "someone@example.org")"
hook_in "$sb"
[ $HOOK_RC -eq 0 ] && pass "human commit with the configured email" || fail "human (rc=$HOOK_RC: $HOOK_OUT)"
hook_in "$sb" GIT_AUTHOR_EMAIL=someone+x@example.org
[ $HOOK_RC -eq 0 ] && pass "agent email someone+x@example.org" || fail "agent (rc=$HOOK_RC: $HOOK_OUT)"
hook_in "$sb" GIT_AUTHOR_EMAIL=someone@EXAMPLE.ORG
[ $HOOK_RC -eq 0 ] && pass "domain compared case-insensitively" || fail "domain case (rc=$HOOK_RC: $HOOK_OUT)"

echo "TEST: the hook rejects another local part, another domain and another base in GIT_AUTHOR_EMAIL"
for other in "other+x@example.org" "other@example.org" "someone+x@example.net" "someone@example.net" "someone+@example.org" \
    "someoneelse@example.org" "someone+a b@example.org" "someone+x@example.org," "<someone@example.org>" \
    'someone+x;y@example.org' 'someone+$(id)@example.org'; do
    hook_in "$sb" GIT_AUTHOR_EMAIL="$other"
    [ $HOOK_RC -ne 0 ] && pass "rejects $other" || fail "accepted $other"
done

echo "TEST: the hook also checks GIT_COMMITTER_EMAIL when it is set"
hook_in "$sb" GIT_AUTHOR_EMAIL=someone+x@example.org GIT_COMMITTER_EMAIL=other@example.net
[[ $HOOK_RC -eq 1 && "$HOOK_OUT" == *"GIT_COMMITTER_EMAIL"*"other@example.net"* ]] \
    && pass "a foreign committer email is rejected and named" || fail "committer (rc=$HOOK_RC: $HOOK_OUT)"
hook_in "$sb" GIT_AUTHOR_EMAIL=someone+x@example.org GIT_COMMITTER_EMAIL=someone+x@example.org
[ $HOOK_RC -eq 0 ] && pass "an accepted committer email passes" || fail "committer ok (rc=$HOOK_RC: $HOOK_OUT)"

echo "TEST: a failing hook names the base, the exact derived command and the likely cause"
hook_in "$sb" GIT_AUTHOR_EMAIL=other+claude-code@example.net
[[ $HOOK_RC -eq 1 && "$HOOK_OUT" == *"someone@example.org"* && "$HOOK_OUT" == *"someone+*@example.org"* ]] \
    && pass "accepted patterns built from the base" || fail "patterns (got: $HOOK_OUT)"
[[ "$HOOK_OUT" == *"$DERIVED_CMD"* ]] && pass "prints the exact derived command" || fail "derived command (got: $HOOK_OUT)"
[[ "$HOOK_OUT" == *"literal"* && "$HOOK_OUT" == *"not yet updated from main"* ]] \
    && pass "names a stale literal setup line or a branch not updated from main" || fail "hint (got: $HOOK_OUT)"

echo "TEST: the hook with an unset or malformed configured email blocks with the message"
sb="$(mk_repo)"
hook_in "$sb" GIT_AUTHOR_EMAIL=someone+x@example.org
[[ $HOOK_RC -eq 1 && "$HOOK_OUT" == *"$UNSET_TEXT"* ]] && pass "unset: exit 1 even with GIT_AUTHOR_EMAIL set" \
    || fail "unset hook (rc=$HOOK_RC: $HOOK_OUT)"
sb="$(mk_repo "foo")"
hook_in "$sb"
[[ $HOOK_RC -eq 1 && "$HOOK_OUT" == *"$MALFORMED_TEXT"* && "$HOOK_OUT" == *"'foo'"* ]] \
    && pass "malformed 'foo': exit 1, the message shows the value" || fail "malformed hook (rc=$HOOK_RC: $HOOK_OUT)"

echo "TEST: a repo-local user.email beats the global one"
sb="$(mk_repo "global@example.org")"
git -C "$sb/repo" config user.email "clone@example.net"
hook_in "$sb" GIT_AUTHOR_EMAIL=clone+codex@example.net
[ $HOOK_RC -eq 0 ] && pass "hook accepts the clone base" || fail "clone base (rc=$HOOK_RC: $HOOK_OUT)"
hook_in "$sb" GIT_AUTHOR_EMAIL=global+codex@example.org
[ $HOOK_RC -ne 0 ] && pass "hook rejects the global base when the clone has its own" || fail "global base accepted"
out="$(run_in "$sb" -- bash -c 'source "$1" --agent codex >/dev/null; echo "$AGENT_EMAIL"' _ "$SET_ENV" 2>&1)"
[ "$out" = "clone+codex@example.net" ] && pass "--agent codex uses the clone value" || fail "clone --agent (got: $out)"

echo "TEST: the base comes from config files, never from git -c / GIT_CONFIG_* injection"
sb="$(mk_repo "someone@example.org")"
hook_in "$sb" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.email GIT_CONFIG_VALUE_0=evil@example.net \
    GIT_AUTHOR_EMAIL=evil+x@example.net
[ $HOOK_RC -ne 0 ] && pass "GIT_CONFIG_COUNT-injected base does not admit its own domain" \
    || fail "GIT_CONFIG_COUNT base accepted (rc=$HOOK_RC: $HOOK_OUT)"
hook_in "$sb" "GIT_CONFIG_PARAMETERS='user.email'='evil@example.net'"
[[ $HOOK_RC -ne 0 && "$HOOK_OUT" == *"evil@example.net"* && "$HOOK_OUT" == *"someone@example.org"* ]] \
    && pass "git -c user.email=<other>: base stays the file value, the -c value is the one checked" \
    || fail "git -c base (rc=$HOOK_RC: $HOOK_OUT)"
hook_in "$sb" "GIT_CONFIG_PARAMETERS='user.email'='someone+codex@example.org'"
[ $HOOK_RC -eq 0 ] && pass "git -c user.email=<accepted agent address> passes" \
    || fail "git -c accepted (rc=$HOOK_RC: $HOOK_OUT)"
out="$(run_in "$sb" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.email GIT_CONFIG_VALUE_0=evil@example.net \
    -- python3 "$HELPER" agent codex 2>&1)"
[ "$out" = "someone+codex@example.org" ] && pass "helper derives from the file value under injection" \
    || fail "helper under injection (got: $out)"
sb="$(mk_repo)"
hook_in "$sb" "GIT_CONFIG_PARAMETERS='user.email'='evil@example.net'" GIT_AUTHOR_EMAIL=evil@example.net
[[ $HOOK_RC -eq 1 && "$HOOK_OUT" == *"$UNSET_TEXT"* ]] && pass "an injected value never stands in for an unset base" \
    || fail "injected unset base (rc=$HOOK_RC: $HOOK_OUT)"

echo "TEST: an agent-configured clone (local+claude-code@d) normalises to the base"
sb="$(mk_repo)"
git -C "$sb/repo" config user.email "dev+claude-code@example.org"
out="$(run_in "$sb" -- bash -c 'source "$1" --agent codex >/dev/null; echo "$AGENT_EMAIL"' _ "$SET_ENV" 2>&1)"
[ "$out" = "dev+codex@example.org" ] && pass "--agent codex -> dev+codex@example.org" || fail "normalise (got: $out)"
hook_in "$sb"
[ $HOOK_RC -eq 0 ] && pass "hook accepts the configured agent address itself" || fail "hook on configured agent (rc=$HOOK_RC: $HOOK_OUT)"

# ---- set_git_identity_env.sh ----
echo "TEST: set_git_identity_env.sh --agent <fw> [model]"
sb="$(mk_repo "dev@example.org")"
out="$(run_in "$sb" -- bash -c 'source "$1" --agent claude-code "model-x" >/dev/null; echo "$AGENT_NAME|$AGENT_EMAIL|$AGENT_MODEL|$GIT_AUTHOR_EMAIL|$GIT_COMMITTER_EMAIL"' _ "$SET_ENV" 2>&1)"
[ "$out" = "Claude Code Agent|dev+claude-code@example.org|model-x|dev+claude-code@example.org|dev+claude-code@example.org" ] \
    && pass "--agent claude-code \"model-x\" sets the derived email and that model" || fail "--agent with model (got: $out)"
out="$(run_in "$sb" -- bash -c 'source "$1" --agent copilot-cli >/dev/null; echo "$AGENT_EMAIL|$AGENT_MODEL"' _ "$SET_ENV" 2>&1)"
[ "$out" = "dev+copilot-cli@example.org|GPT-4o" ] && pass "alias copilot-cli, table model by default" || fail "alias (got: $out)"
out="$(run_in "$sb" -- bash -c 'source "$1" "Custom Agent" "x+y@example.net" "m" >/dev/null; echo "$AGENT_EMAIL|$AGENT_MODEL"' _ "$SET_ENV" 2>&1)"
[ "$out" = "x+y@example.net|m" ] && pass "explicit 3-arg form unchanged" || fail "3-arg (got: $out)"
out="$(run_in "$sb" -- bash -c 'source "$1" --agent nosuch >/dev/null; echo "rc=$? ${AGENT_EMAIL-unset}"' _ "$SET_ENV" 2>&1)"
[ "$out" = "rc=1 unset" ] && pass "unknown framework fails, nothing exported" || fail "unknown fw (got: $out)"

echo "TEST: an empty framework key gives the intended error, not 'bad array subscript'"
out="$(run_in "$sb" -- bash -c 'source "$1" --agent "" 2>&1; echo "rc=$?"' _ "$SET_ENV" 2>&1)"
[[ "$out" == *"Unknown framework ''"* && "$out" == *"rc=1" && "$out" != *"bad array subscript"* ]] \
    && pass "set_git_identity_env.sh --agent \"\"" || fail "--agent empty (got: $out)"
out="$(run_in "$sb" AI_AGENT_NAME=-cli -- bash -c 'source "$1" --detect 2>&1; echo "rc=$?"' _ "$SET_ENV" 2>&1)"
[[ "$out" == *"no predefined identity for detected framework '-cli'"* && "$out" == *"rc=1" && "$out" != *"bad array subscript"* ]] \
    && pass "set_git_identity_env.sh --detect with an empty normalised key" || fail "--detect empty key (got: $out)"
out="$(run_in "$sb" -- bash "$CONFIGURE" --agent "" 2>&1)"; rc=$?
[[ $rc -eq 1 && "$out" == *"Unknown framework ''"* && "$out" != *"bad array subscript"* ]] \
    && pass "configure_git_identity.sh --agent \"\"" || fail "configure empty (rc=$rc, got: $out)"
out="$(run_in "$sb" -- bash -c 'source "$1"; framework_email ""; echo "rc=$?"' _ \
    "$REAL_ROOT/.agent/scripts/framework_config.sh" 2>&1)"
[[ "$out" == *"no email suffix configured for framework ''"* && "$out" == *"rc=1" && "$out" != *"bad array subscript"* ]] \
    && pass "framework_email \"\"" || fail "framework_email empty (got: $out)"
out="$(run_in "$sb" AI_AGENT_NAME=-cli -- bash "$DETECT" 2>&1)"; rc=$?
[[ $rc -eq 0 && "$out" == *"Email:      dev+ai-agent@example.org"* && "$out" != *"bad array subscript"* ]] \
    && pass "detect_agent_identity.sh falls back to ai-agent for an empty key" || fail "detect empty key (rc=$rc, got: $out)"

echo "TEST: unset email fails loudly with nothing exported (every entry point)"
sb="$(mk_repo)"
out="$(run_in "$sb" -- bash -c 'source "$1" --agent claude-code "m" >/dev/null; echo "rc=$? ${AGENT_EMAIL-unset} ${GIT_AUTHOR_EMAIL-unset} ${AGENT_NAME-unset}"' _ "$SET_ENV" 2>&1)"
[[ "$out" == *"$UNSET_TEXT"* && "$out" == *"rc=1 unset unset unset" ]] && pass "--agent" || fail "--agent unset (got: $out)"
out="$(run_in "$sb" ANTIGRAVITY_SESSION=1 -- bash -c 'source "$1" --detect >/dev/null; echo "rc=$? ${AGENT_EMAIL-unset} ${GIT_AUTHOR_EMAIL-unset}"' _ "$SET_ENV" 2>&1)"
[[ "$out" == *"$UNSET_TEXT"* && "$out" == *"rc=1 unset unset" ]] && pass "--detect" || fail "--detect unset (got: $out)"
out="$(run_in "$sb" ANTIGRAVITY_SESSION=1 -- bash "$DETECT" 2>&1)"; rc=$?
[[ $rc -ne 0 && "$out" == *"$UNSET_TEXT"* && "$out" != *"Email:"* ]] && pass "detect_agent_identity.sh (run)" \
    || fail "detect run (rc=$rc, got: $out)"
out="$(run_in "$sb" -- bash -c 'source "$1" --export >/dev/null; echo "rc=$? ${AGENT_EMAIL-unset}"' _ "$DETECT" 2>&1)"
[[ "$out" == *"$UNSET_TEXT"* && "$out" == *"rc=1 unset" ]] && pass "detect_agent_identity.sh --export (sourced)" \
    || fail "detect sourced (got: $out)"
out="$(run_in "$sb" -- bash "$CONFIGURE" --agent codex 2>&1)"; rc=$?
cfg="$(git -C "$sb/repo" config --local user.email)"
[[ $rc -ne 0 && "$out" == *"$UNSET_TEXT"* && -z "$cfg" ]] && pass "configure_git_identity.sh writes nothing" \
    || fail "configure unset (rc=$rc, cfg=$cfg, got: $out)"

echo "TEST: a failed re-source of set_git_identity_env.sh leaves no previous identity behind"
OWNED='${GIT_AUTHOR_NAME-u}|${GIT_AUTHOR_EMAIL-u}|${GIT_COMMITTER_NAME-u}|${GIT_COMMITTER_EMAIL-u}|${AGENT_NAME-u}|${AGENT_EMAIL-u}|${AGENT_MODEL-u}|${AGENT_FRAMEWORK-u}'
PRE_GIT=(GIT_AUTHOR_NAME=Old GIT_AUTHOR_EMAIL=old+codex@example.org GIT_COMMITTER_NAME=Old
    GIT_COMMITTER_EMAIL=old+codex@example.org AGENT_NAME=Old AGENT_EMAIL=old+codex@example.org
    AGENT_MODEL=old AGENT_FRAMEWORK=codex)
for args in '--agent claude-code m' '--detect' '--agent nosuch' 'a b c d'; do
    # $args is spliced into the inner script and word-split there on purpose.
    out="$(run_in "$sb" "${PRE_GIT[@]}" CLAUDECODE=1 -- bash -c \
        "source \"\$1\" $args >/dev/null 2>&1; echo \"rc=\$? $OWNED\"" _ "$SET_ENV" 2>&1)"
    [ "$out" = "rc=1 u|u|u|u|u|u|u|u" ] && pass "failed '$args' unsets every owned variable" \
        || fail "stale identity after '$args' (got: $out)"
done

echo "TEST: a failed sourced detect_agent_identity.sh keeps a pre-exported identity intact"
PRE_ID=(AGENT_NAME="Codex CLI Agent" AGENT_EMAIL=dev+codex@example.org AGENT_MODEL=gpt-x AGENT_FRAMEWORK=codex)
out="$(run_in "$sb" "${PRE_ID[@]}" CLAUDECODE=1 -- bash -c \
    'source "$1" --export >/dev/null 2>&1; echo "rc=$? $AGENT_NAME|$AGENT_EMAIL|$AGENT_MODEL|$AGENT_FRAMEWORK"' _ "$DETECT" 2>&1)"
[ "$out" = "rc=1 Codex CLI Agent|dev+codex@example.org|gpt-x|codex" ] \
    && pass "no AGENT_* value changes (framework, name, model or email)" || fail "mixed identity (got: $out)"

echo "TEST: --detect, detect_agent_identity.sh and configure_git_identity.sh derive from the base"
sb="$(mk_repo "dev@example.org")"
out="$(run_in "$sb" ANTIGRAVITY_SESSION=1 -- bash -c 'source "$1" --detect >/dev/null; echo "$AGENT_EMAIL"' _ "$SET_ENV" 2>&1)"
[ "$out" = "dev+antigravity@example.org" ] && pass "--detect" || fail "--detect (got: $out)"
out="$(run_in "$sb" -- bash "$DETECT" 2>&1)"
[[ "$out" == *"Email:      dev+ai-agent@example.org"* ]] && pass "detect_agent_identity.sh fallback ai-agent" || fail "detect fallback (got: $out)"
run_in "$sb" -- bash "$CONFIGURE" --agent codex >/dev/null 2>&1
cfg="$(git -C "$sb/repo" config --local user.email)"
[ "$cfg" = "dev+codex@example.org" ] && pass "configure_git_identity.sh --agent codex" || fail "configure (got: $cfg)"
out="$(run_in "$sb" -- bash -c 'source "$1" --agent gemini >/dev/null; echo "$AGENT_EMAIL"' _ "$SET_ENV" 2>&1)"
[ "$out" = "dev+gemini-cli@example.org" ] && pass "after configure, the base is unchanged" || fail "after configure (got: $out)"

echo "TEST: configure_git_identity.sh derives per repository it writes to"
sb="$(mk_repo "dev@example.org")"
git init --quiet "$sb/repo/project/own"
git -C "$sb/repo/project/own" config user.email "other@example.net"
git init --quiet "$sb/repo/project/plain"
run_in "$sb" -- bash "$CONFIGURE" --agent codex >/dev/null 2>&1
ws="$(git -C "$sb/repo" config --local user.email)"
own="$(git -C "$sb/repo/project/own" config --local user.email)"
plain="$(git -C "$sb/repo/project/plain" config --local user.email)"
[ "$ws|$own|$plain" = "dev+codex@example.org|other+codex@example.net|dev+codex@example.org" ] \
    && pass "a clone with its own email keeps its base; the others use the global one" \
    || fail "per-repo derivation (got: $ws|$own|$plain)"
sb="$(mk_repo "dev@example.org")"
git init --quiet "$sb/repo/project/bad"
git -C "$sb/repo/project/bad" config user.email "foo"
out="$(run_in "$sb" -- bash "$CONFIGURE" --agent codex 2>&1)"; rc=$?
ws="$(git -C "$sb/repo" config --local user.email)"
[[ $rc -ne 0 && -z "$ws" && "$out" == *"$MALFORMED_TEXT"* && "$out" == *"project/bad"* ]] \
    && pass "one underivable repository: nothing is written anywhere" || fail "partial write (rc=$rc, ws=$ws, got: $out)"

echo "TEST: detect_agent_identity.sh --write quotes the values it writes to .agent/.identity"
# A sandbox copy of the scripts, so the real checkout's .agent/.identity is never written.
sb="$(mk_repo "dev@example.org")"
mkdir -p "$sb/ws/.agent/scripts"
for f in detect_agent_identity.sh framework_config.sh identity_base.py detect_cli_env.sh; do
    cp "$REAL_ROOT/.agent/scripts/$f" "$sb/ws/.agent/scripts/$f"
done
evil_model='m"; touch '"$sb"'/pwned1; x="$(touch '"$sb"'/pwned2)`touch '"$sb"'/pwned3`'"'"
run_in "$sb" CLAUDECODE=1 CLAUDE_MODEL="$evil_model" -- bash "$sb/ws/.agent/scripts/detect_agent_identity.sh" --write >/dev/null 2>&1
out="$(env -i PATH="$PATH" bash -c 'source "$1"; printf "%s|%s" "$AGENT_EMAIL" "$AGENT_MODEL"' _ "$sb/ws/.agent/.identity" 2>&1)"
[ "$out" = "dev+claude-code@example.org|$evil_model" ] && pass "the sourced file gives back the exact values" \
    || fail ".identity round trip (got: $out)"
ls "$sb"/pwned* >/dev/null 2>&1 && fail "sourcing .identity ran a command" || pass "sourcing .identity runs nothing"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
