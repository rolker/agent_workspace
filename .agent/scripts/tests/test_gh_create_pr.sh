#!/usr/bin/env bash
# Tests for .agent/scripts/gh_create_pr.sh
#
# Run: bash .agent/scripts/tests/test_gh_create_pr.sh
#
# Strategy: shim `gh` and `git` in a temporary PATH so the wrapper runs
# end-to-end without network calls. The shimmed `gh pr create` writes its
# argv to a known file; assertions inspect that file.

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "FATAL: jq is required to run these tests" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/../gh_create_pr.sh"

if [[ ! -x "$SCRIPT" ]]; then
    echo "FATAL: wrapper not found or not executable at $SCRIPT"
    exit 1
fi

# --- shims ------------------------------------------------------------------
SHIM_DIR=$(mktemp -d /tmp/gh_create_pr_shim-XXXXXX)
ARGV_LOG="$SHIM_DIR/argv.log"
BODY_CAPTURE_DIR="$SHIM_DIR/body-capture"
mkdir -p "$BODY_CAPTURE_DIR"
trap 'rm -rf "$SHIM_DIR"' EXIT

# Real gh path for command discovery; we only shim `gh pr create`
REAL_GH=$(command -v gh || true)
cat > "$SHIM_DIR/gh" <<EOF
#!/bin/bash
# Capture argv to $ARGV_LOG when 'gh pr create' is called.
# Capture any --body-file contents to $BODY_CAPTURE_DIR so the test can
# inspect the post-injection body.
if [[ "\$1" = "pr" && "\$2" = "create" ]]; then
    : > "$ARGV_LOG"
    shift 2
    for arg in "\$@"; do
        printf '%s\n' "\$arg" >> "$ARGV_LOG"
    done
    # Snapshot any --body-file content while the temp file still exists
    prev=""
    for arg in "\$@"; do
        if [[ "\$prev" = "--body-file" && -f "\$arg" ]]; then
            cp "\$arg" "$BODY_CAPTURE_DIR/body.md"
        fi
        prev="\$arg"
    done
    exit 0
fi
exec "$REAL_GH" "\$@"
EOF
chmod +x "$SHIM_DIR/gh"

# The wrapper calls `command -v gh` and `command -v jq` early; shim PATH so
# only `gh` is mocked while jq/git remain real.
export PATH="$SHIM_DIR:$PATH"

PASS=0
FAIL=0

run_wrapper() {
    # Capture all argv from a single invocation. Echoes the script's
    # stdout/stderr and returns its exit code.
    "$SCRIPT" "$@"
}

read_argv() {
    # Print the captured argv (one per line), or empty if no call was made.
    [[ -f "$ARGV_LOG" ]] && cat "$ARGV_LOG"
}

argv_has() {
    # $1 = expected argv token (exact match against any line in argv.log).
    # `--` terminates grep option parsing so tokens like `--draft` don't
    # get interpreted as flags (ugrep is stricter than GNU grep here).
    grep -Fxq -- "$1" "$ARGV_LOG" 2>/dev/null
}

reset_capture() { rm -f "$ARGV_LOG"; rm -rf "$BODY_CAPTURE_DIR"; mkdir -p "$BODY_CAPTURE_DIR"; }

assert_calls_gh() {
    local label="$1"; shift
    reset_capture
    run_wrapper "$@" >/dev/null 2>&1
    rc=$?
    if [[ "$rc" -eq 0 && -f "$ARGV_LOG" ]]; then
        echo "  PASS [calls gh]:   $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL [calls gh]:   $label  (rc=$rc, argv-log $([[ -f $ARGV_LOG ]] && echo present || echo missing))"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit_code() {
    local label="$1" expected="$2"; shift 2
    reset_capture
    run_wrapper "$@" >/dev/null 2>&1
    rc=$?
    if [[ "$rc" -eq "$expected" ]]; then
        echo "  PASS [exit=$expected]: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL [exit=$expected]: $label  (got $rc)"
        FAIL=$((FAIL + 1))
    fi
}

# --- tests ------------------------------------------------------------------
echo
echo "=== Signature injection (env vars set) ==="
export AGENT_NAME="Test Agent"
export AGENT_MODEL="test-model"

assert_calls_gh "inline body, signature appended" \
    --title "T" --body "Body text"
if argv_has "Body text

---
**Authored-By**: \`Test Agent\`
**Model**: \`test-model\`
"; then
    echo "  PASS [body content]: inline body has signature footer"
    PASS=$((PASS + 1))
else
    echo "  FAIL [body content]: inline body did not get signature appended"
    echo "  Got argv:"
    sed 's/^/    /' "$ARGV_LOG"
    FAIL=$((FAIL + 1))
fi

TMPF=$(mktemp /tmp/test_body.XXXXXX.md)
echo "File body" > "$TMPF"
assert_calls_gh "--body-file, signature appended" \
    --title "T" --body-file "$TMPF"
if [[ -f "$BODY_CAPTURE_DIR/body.md" ]] \
   && grep -Fq "**Authored-By**: \`Test Agent\`" "$BODY_CAPTURE_DIR/body.md" \
   && grep -Fq "File body" "$BODY_CAPTURE_DIR/body.md"; then
    echo "  PASS [body content]: body-file gets signature appended"
    PASS=$((PASS + 1))
else
    echo "  FAIL [body content]: body-file signature missing or original lost"
    FAIL=$((FAIL + 1))
fi
rm -f "$TMPF"

echo
echo "=== Signature already present (no duplicate) ==="
TMPF=$(mktemp /tmp/test_body.XXXXXX.md)
cat > "$TMPF" <<'EOM'
This PR already has a signature

---
**Authored-By**: `Existing`
**Model**: `existing-model`
EOM
assert_calls_gh "body-file already signed, gh still called" \
    --title "T" --body-file "$TMPF"
# Verify only ONE Authored-By line in the captured body
SIG_COUNT=$(grep -cF '**Authored-By**:' "$BODY_CAPTURE_DIR/body.md" 2>/dev/null || echo 0)
if [[ "$SIG_COUNT" -eq 1 ]]; then
    echo "  PASS [body content]: already-signed body not duplicated (1 Authored-By line)"
    PASS=$((PASS + 1))
else
    echo "  FAIL [body content]: expected 1 Authored-By, got $SIG_COUNT"
    FAIL=$((FAIL + 1))
fi
rm -f "$TMPF"

echo
echo "=== --no-signature flag ==="
assert_calls_gh "--no-signature suppresses footer" \
    --title "T" --body "B" --no-signature
if argv_has "--no-signature"; then
    echo "  FAIL [argv]: --no-signature should be stripped before gh"
    FAIL=$((FAIL + 1))
else
    echo "  PASS [argv]:       --no-signature stripped from gh argv"
    PASS=$((PASS + 1))
fi
# Body should be exactly "B" (no signature)
if argv_has "B"; then
    echo "  PASS [body]:       --no-signature kept body unmodified"
    PASS=$((PASS + 1))
else
    echo "  FAIL [body]:       body changed despite --no-signature"
    FAIL=$((FAIL + 1))
fi

echo
echo "=== Hard fail when env vars unset (workspace policy) ==="
unset AGENT_NAME AGENT_MODEL
assert_exit_code "unset AGENT_NAME hard-fails" 2 \
    --title "T" --body "B"
# But --no-signature should still allow pass-through
assert_calls_gh "unset + --no-signature still calls gh" \
    --title "T" --body "B" --no-signature
# Already-signed body also bypasses the env-var check
TMPF=$(mktemp /tmp/test_body.XXXXXX.md)
cat > "$TMPF" <<'EOM'
Already signed body

---
**Authored-By**: `Someone`
**Model**: `x`
EOM
assert_calls_gh "unset + already-signed body calls gh" \
    --title "T" --body-file "$TMPF"
rm -f "$TMPF"

echo
echo "=== Pass-through flags ==="
export AGENT_NAME="Test Agent"
export AGENT_MODEL="test-model"
assert_calls_gh "--draft passes through" \
    --title "T" --body "B" --draft
argv_has "--draft" && echo "  PASS [argv]:       --draft preserved" && PASS=$((PASS + 1)) \
    || { echo "  FAIL [argv]:       --draft missing"; FAIL=$((FAIL + 1)); }

assert_calls_gh "--base and --head pass through" \
    --title "T" --body "B" --base develop --head feature/x
argv_has "--base" && argv_has "develop" && argv_has "--head" && argv_has "feature/x" \
    && echo "  PASS [argv]:       --base/--head preserved" && PASS=$((PASS + 1)) \
    || { echo "  FAIL [argv]:       --base/--head missing"; FAIL=$((FAIL + 1)); }

echo
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"

[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
