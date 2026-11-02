#!/usr/bin/env bash
# Tests for .agent/scripts/gh_create_issue.sh's AI signature contract
# (issue #323), which mirrors gh_create_pr.sh's.
#
# Run: bash .agent/scripts/tests/test_gh_create_issue.sh
#
# Strategy: shim `gh` in a temporary PATH so the wrapper runs end-to-end
# without network calls (modelled on test_gh_create_pr.sh). The shimmed
# `gh issue create` writes its argv and any --body-file contents to known
# files; `gh repo view` prints the workspace's own slug so the parent-ref
# path stays offline. `git` is the real binary against the real worktree.
# Every temp file the wrapper makes honours TMPDIR: each run gets a private
# TMPDIR that must be empty afterwards (the runner's per-run TMPDIR leak
# check is the backstop).

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "FATAL: jq is required to run these tests" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/../gh_create_issue.sh"
WS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [[ ! -x "$SCRIPT" ]]; then
    echo "FATAL: wrapper not found or not executable at $SCRIPT"
    exit 1
fi

# One sandbox for the whole run, created at top level so the trap fires.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "${SANDBOX:?}"' EXIT

# --- shims ------------------------------------------------------------------
SHIM_DIR="$SANDBOX/shim"
ARGV_LOG="$SHIM_DIR/argv.log"
BODY_CAPTURE="$SHIM_DIR/body.md"
mkdir -p "$SHIM_DIR"
WS_SLUG=$(git -C "$WS_ROOT" remote get-url origin 2>/dev/null \
    | sed -E 's#.*github\.com[:/]##' | sed 's/\.git$//')

cat > "$SHIM_DIR/gh" <<EOF
#!/bin/bash
if [[ "\$1" = "issue" && "\$2" = "create" ]]; then
    : > "$ARGV_LOG"
    shift 2
    for arg in "\$@"; do
        printf '%s\n' "\$arg" >> "$ARGV_LOG"
    done
    prev=""
    for arg in "\$@"; do
        if [[ "\$prev" = "--body-file" && -f "\$arg" ]]; then
            cp "\$arg" "$BODY_CAPTURE"
        fi
        prev="\$arg"
    done
    exit 0
fi
if [[ "\$1" = "repo" && "\$2" = "view" ]]; then
    echo "$WS_SLUG"
    exit 0
fi
echo "gh shim: unexpected call: \$*" >&2
exit 99
EOF
chmod +x "$SHIM_DIR/gh"
export PATH="$SHIM_DIR:$PATH"

unset WORKTREE_ISSUE GITBUG_CREATE

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

OUT=""
RC=0
RUN_N=0
run() {
    # Each run gets a fresh private TMPDIR, which must be empty afterwards.
    local wrap_tmp
    RUN_N=$((RUN_N + 1))
    wrap_tmp="$SANDBOX/wrap-tmp.$RUN_N"
    mkdir -p "$wrap_tmp"
    rm -f "$ARGV_LOG" "$BODY_CAPTURE"
    OUT=$(cd "$WS_ROOT" && TMPDIR="$wrap_tmp" "$SCRIPT" "$@" 2>&1)
    RC=$?
    if [[ -n "$(ls -A "$wrap_tmp")" ]]; then
        fail "temp file left behind by: $* ($(ls -A "$wrap_tmp" | tr '\n' ' '))"
    fi
}
gh_called() { [[ -f "$ARGV_LOG" ]]; }
argv_has() { grep -Fxq -- "$1" "$ARGV_LOG" 2>/dev/null; }
sig_in() {  # <file>: the footer for the test identity is present
    grep -Fq '**Authored-By**: `Test Agent`' "$1" && grep -Fq '**Model**: `test-model`' "$1"
}
sig_count() { grep -cF '**Authored-By**:' "$1" 2>/dev/null || true; }

export AGENT_NAME="Test Agent"
export AGENT_MODEL="test-model"

echo
echo "=== Inline body is signed (--body, --body=, -b) ==="
for form in "--body" "-b"; do
    run --title T "$form" "Body text"
    if [[ "$RC" -eq 0 ]] && gh_called && grep -Fq 'Body text' "$ARGV_LOG" && sig_in "$ARGV_LOG"; then
        pass "$form VALUE signed"
    else
        fail "$form VALUE not signed (rc=$RC): $OUT"
    fi
done
run --title T "--body=Eq body"
if [[ "$RC" -eq 0 ]] && argv_has "--body" && grep -q '^Eq body' "$ARGV_LOG" && sig_in "$ARGV_LOG"; then
    pass "--body=VALUE normalised and signed"
else
    fail "--body=VALUE not signed (rc=$RC): $OUT"
fi
run --title T --body ""
if [[ "$RC" -eq 0 ]] && gh_called && sig_in "$ARGV_LOG"; then
    pass "--body \"\" is non-interactive and signed"
else
    fail "--body \"\" not signed (rc=$RC)"
fi

echo
echo "=== Body file is signed through a copy (--body-file, --body-file=, -F, -) ==="
BODYF="$SANDBOX/body.md"
for form in "--body-file" "-F" "eq"; do
    printf 'File body\n' > "$BODYF"
    if [[ "$form" = eq ]]; then
        run --title T "--body-file=$BODYF"; label="--body-file=PATH"
    else
        run --title T "$form" "$BODYF"; label="$form PATH"
    fi
    if [[ "$RC" -eq 0 ]] && [[ -f "$BODY_CAPTURE" ]] && grep -Fq 'File body' "$BODY_CAPTURE" \
       && sig_in "$BODY_CAPTURE"; then
        pass "$label signed"
    else
        fail "$label not signed (rc=$RC): $OUT"
    fi
    if [[ "$(cat "$BODYF")" = "File body" ]] && gh_called && ! argv_has "$BODYF"; then
        pass "$label: caller's file untouched, gh got a copy"
    else
        fail "$label: caller's file modified or passed to gh directly"
    fi
done
run --title T --body-file - <<<"Stdin body"
if [[ "$RC" -eq 0 ]] && [[ -f "$BODY_CAPTURE" ]] && grep -Fq 'Stdin body' "$BODY_CAPTURE" \
   && sig_in "$BODY_CAPTURE"; then
    pass "--body-file - (stdin) signed"
else
    fail "--body-file - not signed (rc=$RC): $OUT"
fi

echo
echo "=== Already-signed body is not signed twice ==="
SIGNEDF="$SANDBOX/signed.md"
cat > "$SIGNEDF" <<'EOM'
Already signed

---
**Authored-By**: `Existing`
**Model**: `existing-model`
EOM
run --title T --body-file "$SIGNEDF"
if [[ "$RC" -eq 0 ]] && [[ "$(sig_count "$BODY_CAPTURE")" -eq 1 ]]; then
    pass "signed body file keeps one footer"
else
    fail "signed body file got $(sig_count "$BODY_CAPTURE") footers (rc=$RC)"
fi
run --title T --body "$(cat "$SIGNEDF")"
if [[ "$RC" -eq 0 ]] && [[ "$(sig_count "$ARGV_LOG")" -eq 1 ]]; then
    pass "signed inline body keeps one footer"
else
    fail "signed inline body got $(sig_count "$ARGV_LOG") footers (rc=$RC)"
fi

echo
echo "=== --no-signature ==="
run --title T --body B --no-signature
if [[ "$RC" -eq 0 ]] && argv_has "B" && ! argv_has "--no-signature" \
   && ! grep -Fq '**Authored-By**:' "$ARGV_LOG"; then
    pass "--no-signature: body unsigned, flag never reaches gh"
else
    fail "--no-signature handling broken (rc=$RC)"
fi

echo
echo "=== Identity unset: a body hard-fails before gh ==="
unset AGENT_NAME AGENT_MODEL
PLAINF="$SANDBOX/plain.md"
printf 'Plain\n' > "$PLAINF"
for args in "--body|B" "--body=B" "-b|B" "--body-file|$PLAINF" "--body-file=$PLAINF" "-F|$PLAINF"; do
    IFS='|' read -r -a argv <<<"$args"
    run --title T "${argv[@]}"
    if [[ "$RC" -eq 2 ]] && ! gh_called && [[ "$OUT" == *set_git_identity_env.sh* ]]; then
        pass "identity unset + ${argv[*]}: exit 2 naming set_git_identity_env.sh, gh not called"
    else
        fail "identity unset + ${argv[*]}: rc=$RC gh_called=$(gh_called && echo yes || echo no)"
    fi
done
WORKTREE_ISSUE=4242 run --title T --body B
if [[ "$RC" -eq 2 ]] && ! gh_called && [[ "$OUT" != *"Auto-added parent"* ]]; then
    pass "identity unset + WORKTREE_ISSUE: exit 2 before the parent-ref lookup"
else
    fail "identity unset + WORKTREE_ISSUE: rc=$RC"
fi
run --title T --body B --no-signature
if [[ "$RC" -eq 0 ]] && gh_called; then
    pass "identity unset + --no-signature still creates"
else
    fail "identity unset + --no-signature refused (rc=$RC)"
fi
run --title T --body-file "$SIGNEDF"
if [[ "$RC" -eq 0 ]] && gh_called; then
    pass "identity unset + already-signed body still creates"
else
    fail "identity unset + already-signed body refused (rc=$RC)"
fi
run --title T
if [[ "$RC" -eq 0 ]] && gh_called; then
    pass "identity unset + no body flag (interactive) passes through"
else
    fail "identity unset + no body flag refused (rc=$RC)"
fi
export AGENT_NAME="Test Agent"
export AGENT_MODEL="test-model"

echo
echo "=== No body flag passes through unsigned ==="
run --title T
if [[ "$RC" -eq 0 ]] && gh_called && ! grep -Fq '**Authored-By**:' "$ARGV_LOG"; then
    pass "no body flag: gh called, nothing signed"
else
    fail "no body flag handling broken (rc=$RC)"
fi

echo
echo "=== Usage errors ==="
for flag in "--body" "-b" "--body-file" "-F" "--label"; do
    run --title T "$flag"
    if [[ "$RC" -eq 2 ]] && ! gh_called; then
        pass "$flag with no value: exit 2"
    else
        fail "$flag with no value: rc=$RC"
    fi
done
run --title T --body B --body-file "$PLAINF"
if [[ "$RC" -eq 2 ]] && ! gh_called; then
    pass "--body + --body-file: exit 2"
else
    fail "--body + --body-file: rc=$RC"
fi
run --title T -b B -F "$PLAINF"
if [[ "$RC" -eq 2 ]] && ! gh_called; then
    pass "-b + -F: exit 2"
else
    fail "-b + -F: rc=$RC"
fi

echo
echo "=== Parent reference injection keeps the footer last ==="
printf 'Sub-issue body\n' > "$BODYF"
WORKTREE_ISSUE=4242 run --title T --body-file "$BODYF"
if [[ "$RC" -eq 0 ]] && [[ -f "$BODY_CAPTURE" ]] && grep -Fq 'Part of #4242' "$BODY_CAPTURE" \
   && sig_in "$BODY_CAPTURE" \
   && [[ "$(tail -n1 "$BODY_CAPTURE")" == '**Model**: `test-model`' ]]; then
    pass "body file: parent reference, then footer last"
else
    fail "body file: parent reference / footer order wrong (rc=$RC)"
    sed 's/^/    /' "$BODY_CAPTURE" 2>/dev/null
fi
if [[ "$(cat "$BODYF")" = "Sub-issue body" ]]; then
    pass "body file: caller's file untouched by both injections"
else
    fail "body file: caller's file modified"
fi
WORKTREE_ISSUE=4242 run --title T --body "Inline sub"
if [[ "$RC" -eq 0 ]] && grep -Fq 'Part of #4242' "$ARGV_LOG" \
   && [[ "$(tail -n1 "$ARGV_LOG")" == '**Model**: `test-model`' ]]; then
    pass "inline body: parent reference, then footer last"
else
    fail "inline body: parent reference / footer order wrong (rc=$RC)"
fi

echo
echo "=== The user-tier root guard refuses before signing ==="
# Same probe as test_user_tier_guard.sh (--title t --body b, AGENT_MODEL
# unset), from a repo registered nowhere: the guard's refusal must come
# first, not the signature's exit 2.
WSC="$SANDBOX/ws"
mkdir -p "$WSC/.agent/scripts"
cp "$SCRIPT_DIR/../gh_create_issue.sh" "$SCRIPT_DIR/../_project_registry.sh" "$WSC/.agent/scripts/"
: > "$WSC/.agent/projects.local"
git -C "$WSC" init -q -b main
OUTSIDE="$SANDBOX/unrelated"
mkdir -p "$OUTSIDE"
git -C "$OUTSIDE" init -q -b main
rm -f "$ARGV_LOG"
out=$(cd "$OUTSIDE" && env -u AGENT_MODEL AGENT_NAME=t bash "$WSC/.agent/scripts/gh_create_issue.sh" --title t --body b 2>&1); rc=$?
if [[ "$rc" -eq 1 && "$out" == *"refusing to run"* ]] && ! gh_called; then
    pass "unregistered repo: the guard refuses (exit 1) before the signature check"
else
    fail "unregistered repo: rc=$rc out=${out:0:200}"
fi

echo
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
