#!/usr/bin/env bash
# Tests for .agent/scripts/gh_create_pr.sh
#
# Run: bash .agent/scripts/tests/test_gh_create_pr.sh
#
# Strategy: shim `gh` in a temporary PATH so the wrapper runs end-to-end
# without network calls. The shimmed `gh pr create` writes its argv to a
# known file; assertions inspect that file. `git` (rev-parse, remotes) is
# the real binary against the real worktree.

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

# One sandbox for the whole run, created at top level (not inside $()) so
# the trap actually fires — see issue #297. No hardcoded /tmp templates
# anywhere in this file: `mktemp` honors TMPDIR, and every scratch file the
# tests write is a child of $SANDBOX, so the trap covers abort paths too.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# --- shims ------------------------------------------------------------------
SHIM_DIR="$SANDBOX/shim"
ARGV_LOG="$SHIM_DIR/argv.log"
BODY_CAPTURE_DIR="$SHIM_DIR/body-capture"
mkdir -p "$BODY_CAPTURE_DIR"

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

LEAK_LOG="$SANDBOX/leaks.log"
RUN_N=0
run_wrapper() {
    # Capture all argv from a single invocation. Echoes the script's
    # stdout/stderr and returns its exit code. Each call gets a private
    # TMPDIR that must be empty afterwards (the body copy honours TMPDIR);
    # a leak is logged to a file, since a piped call runs in a subshell.
    local wrap_tmp rc
    RUN_N=$((RUN_N + 1))
    wrap_tmp="$SANDBOX/wrap-tmp.$RUN_N.$BASHPID"
    mkdir -p "$wrap_tmp"
    TMPDIR="$wrap_tmp" "$SCRIPT" "$@"
    rc=$?
    if [[ -n "$(ls -A "$wrap_tmp")" ]]; then
        echo "$* ($(ls -A "$wrap_tmp" | tr '\n' ' '))" >> "$LEAK_LOG"
    fi
    return "$rc"
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
# Use targeted `grep -Fq` rather than `argv_has` (`grep -Fxq`): the shim
# writes each argv token via `printf '%s\n'`, so the signed `--body`
# token's embedded newlines split it across multiple lines of argv.log.
# `grep -Fxq` is line-oriented and would match too loosely against any
# single line of the expected multi-line block.
if grep -Fq 'Body text' "$ARGV_LOG" \
   && grep -Fq '**Authored-By**: `Test Agent`' "$ARGV_LOG" \
   && grep -Fq '**Model**: `test-model`' "$ARGV_LOG"; then
    echo "  PASS [body content]: inline body has signature footer"
    PASS=$((PASS + 1))
else
    echo "  FAIL [body content]: inline body did not get signature appended"
    echo "  Got argv:"
    sed 's/^/    /' "$ARGV_LOG"
    FAIL=$((FAIL + 1))
fi

TMPF=$(mktemp "$SANDBOX/test_body.XXXXXX.md")
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

echo
echo "=== Signature already present (no duplicate) ==="
TMPF=$(mktemp "$SANDBOX/test_body.XXXXXX.md")
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
# The hint names the derived form, not a literal name/email (#455).
reset_capture
hint_out="$(run_wrapper --title "T" --body "B" 2>&1)"
if [[ "$hint_out" == *'set_git_identity_env.sh --agent <framework> "<model-id>"'* && "$hint_out" != *'"email"'* ]]; then
    echo "  PASS: unset hint names --agent <framework> \"<model-id>\""
    PASS=$((PASS + 1))
else
    echo "  FAIL: unset hint (got: $hint_out)"
    FAIL=$((FAIL + 1))
fi
# But --no-signature should still allow pass-through
assert_calls_gh "unset + --no-signature still calls gh" \
    --title "T" --body "B" --no-signature
# Already-signed body also bypasses the env-var check
TMPF=$(mktemp "$SANDBOX/test_body.XXXXXX.md")
cat > "$TMPF" <<'EOM'
Already signed body

---
**Authored-By**: `Someone`
**Model**: `x`
EOM
assert_calls_gh "unset + already-signed body calls gh" \
    --title "T" --body-file "$TMPF"

echo
echo "=== Joined-equals forms (--body=X, --body-file=X) ==="
export AGENT_NAME="Test Agent"
export AGENT_MODEL="test-model"

assert_calls_gh "--body=VALUE shape" \
    --title "T" --body=Inline-body-via-equals
# After normalization + signature injection, gh should see `--body` followed
# by the body+signature on the next argv line, not a single positional token.
if argv_has "--body" \
   && grep -q '^Inline-body-via-equals' "$ARGV_LOG" \
   && grep -Fq '**Authored-By**: `Test Agent`' "$ARGV_LOG"; then
    echo "  PASS [argv]:       --body=VALUE normalized and signed"
    PASS=$((PASS + 1))
else
    echo "  FAIL [argv]:       --body=VALUE handling broken"
    echo "  argv was:"; sed 's/^/    /' "$ARGV_LOG"
    FAIL=$((FAIL + 1))
fi

TMPF=$(mktemp "$SANDBOX/test_body.XXXXXX.md")
echo "Eq form body" > "$TMPF"
assert_calls_gh "--body-file=PATH shape" \
    --title "T" "--body-file=$TMPF"
if argv_has "--body-file" \
   && [[ -f "$BODY_CAPTURE_DIR/body.md" ]] \
   && grep -Fq "Eq form body" "$BODY_CAPTURE_DIR/body.md" \
   && grep -Fq "**Authored-By**: \`Test Agent\`" "$BODY_CAPTURE_DIR/body.md"; then
    echo "  PASS [body]:       --body-file=PATH normalized and signed"
    PASS=$((PASS + 1))
else
    echo "  FAIL [body]:       --body-file=PATH handling broken"
    FAIL=$((FAIL + 1))
fi

echo
echo "=== --body-stdin path ==="
# Signed stdin (env vars set, content not pre-signed)
reset_capture
printf '%s\n' "Stdin body content" | run_wrapper --title "T" --body-stdin >/dev/null 2>&1
rc=$?
if [[ "$rc" -eq 0 ]] && argv_has "--body-file" \
   && [[ -f "$BODY_CAPTURE_DIR/body.md" ]] \
   && grep -Fq "Stdin body content" "$BODY_CAPTURE_DIR/body.md" \
   && grep -Fq "**Authored-By**: \`Test Agent\`" "$BODY_CAPTURE_DIR/body.md"; then
    echo "  PASS [stdin]:      --body-stdin drained, rewritten to --body-file, signed"
    PASS=$((PASS + 1))
else
    echo "  FAIL [stdin]:      --body-stdin signed path broken (rc=$rc)"
    FAIL=$((FAIL + 1))
fi
# --body-stdin should never reach gh
if argv_has "--body-stdin"; then
    echo "  FAIL [stdin]:      --body-stdin leaked through to gh"
    FAIL=$((FAIL + 1))
else
    echo "  PASS [stdin]:      --body-stdin stripped before gh"
    PASS=$((PASS + 1))
fi

# Stdin + already-signed content → no duplicate
reset_capture
printf '%s' "Pre-signed stdin

---
**Authored-By**: \`Someone\`
**Model**: \`x\`
" | run_wrapper --title "T" --body-stdin >/dev/null 2>&1
SIG_COUNT_STDIN=$(grep -cF '**Authored-By**:' "$BODY_CAPTURE_DIR/body.md" 2>/dev/null || echo 0)
if [[ "$SIG_COUNT_STDIN" -eq 1 ]]; then
    echo "  PASS [stdin]:      already-signed stdin not duplicated (1 Authored-By)"
    PASS=$((PASS + 1))
else
    echo "  FAIL [stdin]:      already-signed stdin got $SIG_COUNT_STDIN Authored-By lines"
    FAIL=$((FAIL + 1))
fi

# Stdin + --no-signature → still drained and rewritten, no signature added
reset_capture
printf '%s\n' "Stdin no-sig" | run_wrapper --title "T" --body-stdin --no-signature >/dev/null 2>&1
rc=$?
if [[ "$rc" -eq 0 ]] && argv_has "--body-file" \
   && [[ -f "$BODY_CAPTURE_DIR/body.md" ]] \
   && grep -Fq "Stdin no-sig" "$BODY_CAPTURE_DIR/body.md"; then
    if grep -Fq '**Authored-By**:' "$BODY_CAPTURE_DIR/body.md"; then
        echo "  FAIL [stdin]:      --no-signature on stdin still added signature"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS [stdin]:      --body-stdin + --no-signature drains without signing"
        PASS=$((PASS + 1))
    fi
else
    echo "  FAIL [stdin]:      --body-stdin + --no-signature didn't reach gh (rc=$rc)"
    FAIL=$((FAIL + 1))
fi

echo
echo "=== Interactive (no body provided) ==="
# With env vars set: no body means editor mode; should not hard-fail or
# require signature injection.
assert_calls_gh "no body, env vars set" \
    --title "T"
# With env vars UNSET: no body should ALSO pass through (no signature needed
# because there's nothing to sign yet — user will edit interactively).
unset AGENT_NAME AGENT_MODEL
assert_calls_gh "no body, env vars unset (no hard-fail)" \
    --title "T"
export AGENT_NAME="Test Agent"
export AGENT_MODEL="test-model"

echo
echo "=== Missing value rejection ==="
# --body / --body-file / --label as the last arg with no value used to
# either hard-fail on missing identity (misleading) or silently pass a
# value-less flag through to gh. Now hard-fails with a clear error and
# exit 2 — consistent with --repo's existing behavior.
export AGENT_NAME="Test Agent"
export AGENT_MODEL="test-model"
assert_exit_code "--body as last arg → exit 2" 2 \
    --title "T" --body
assert_exit_code "--body-file as last arg → exit 2" 2 \
    --title "T" --body-file
assert_exit_code "--label as last arg → exit 2" 2 \
    --title "T" --body "B" --label

echo
echo "=== Mutually exclusive body sources ==="
# Specifying more than one of --body / --body-file / --body-stdin would
# let the wrapper sign one source while gh uses another (or errors),
# leaving the PR unsigned. Reject with exit 2.
TMPF_MX=$(mktemp "$SANDBOX/test_body.XXXXXX.md")
echo "file body" > "$TMPF_MX"
assert_exit_code "--body + --body-file → exit 2" 2 \
    --title "T" --body "B" --body-file "$TMPF_MX"
assert_exit_code "--body + --body-stdin → exit 2" 2 \
    --title "T" --body "B" --body-stdin
assert_exit_code "--body-file + --body-stdin → exit 2" 2 \
    --title "T" --body-file "$TMPF_MX" --body-stdin

echo
echo "=== Empty body flag (--body \"\") is non-interactive ==="
# `--body ""` is flag-present, so it must NOT collapse into interactive
# mode: signature gets appended, and missing identity hard-fails.
assert_calls_gh "--body \"\" still gets signature" \
    --title "T" --body ""
if grep -Fq '**Authored-By**: `Test Agent`' "$ARGV_LOG" \
   && grep -Fq '**Model**: `test-model`' "$ARGV_LOG"; then
    echo "  PASS [body content]: --body \"\" got signature appended"
    PASS=$((PASS + 1))
else
    echo "  FAIL [body content]: --body \"\" did not get signature appended"
    echo "  Got argv:"
    sed 's/^/    /' "$ARGV_LOG"
    FAIL=$((FAIL + 1))
fi
unset AGENT_NAME AGENT_MODEL
assert_exit_code "--body \"\" hard-fails with unset env vars" 2 \
    --title "T" --body ""
export AGENT_NAME="Test Agent"
export AGENT_MODEL="test-model"

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
echo "=== Short forms with glued values (-b=X, -bX, -F=X, -FX, -db X) ==="
body_signed() {  # <file>
    grep -Fq '**Authored-By**: `Test Agent`' "$1" && grep -Fq '**Model**: `test-model`' "$1"
}
check() {  # <label> <command...>: one PASS/FAIL line
    local label="$1"; shift
    if "$@"; then
        echo "  PASS [parse]:      $label"; PASS=$((PASS + 1))
    else
        echo "  FAIL [parse]:      $label"; FAIL=$((FAIL + 1))
        [[ -f "$ARGV_LOG" ]] && sed 's/^/    /' "$ARGV_LOG"
    fi
}
# shellcheck disable=SC2016  # the bash -c programs expand their own $1
for form in "-b=Glued body" "-bGlued body"; do
    assert_calls_gh "$form" --title "T" "$form"
    check "$form read as --body and signed" \
        bash -c 'grep -Fxq -- --body "$1" && grep -q "^Glued body" "$1" && ! grep -Fxq -- "$2" "$1"' _ "$ARGV_LOG" "$form"
    check "$form footer" body_signed "$ARGV_LOG"
done
TMPF_G=$(mktemp "$SANDBOX/test_body.XXXXXX.md")
for form in "-F=" "-F"; do
    echo "Glued file body" > "$TMPF_G"
    assert_calls_gh "${form}PATH" --title "T" "$form$TMPF_G"
    # shellcheck disable=SC2016
    check "${form}PATH read as --body-file and signed through a copy" \
        bash -c 'grep -Fq "Glued file body" "$1" && ! grep -Fxq -- "$2" "$3"' _ \
        "$BODY_CAPTURE_DIR/body.md" "$form$TMPF_G" "$ARGV_LOG"
    check "${form}PATH footer" body_signed "$BODY_CAPTURE_DIR/body.md"
done
assert_calls_gh "-db VALUE" --title "T" -db "Cluster body"
# shellcheck disable=SC2016
check "-db VALUE: -d kept, body signed" \
    bash -c 'grep -Fxq -- -d "$1" && grep -q "^Cluster body" "$1"' _ "$ARGV_LOG"
check "-db VALUE footer" body_signed "$ARGV_LOG"

echo
echo "=== Values that look like flags are values ==="
assert_calls_gh "--title -b --body B" --title -b --body B
# shellcheck disable=SC2016
check "the title is \"-b\", the body B is signed" \
    bash -c '[[ "$(sed -n 2p "$1")" = "-b" ]] && grep -qx B "$1"' _ "$ARGV_LOG"
check "--title -b --body B footer" body_signed "$ARGV_LOG"
assert_calls_gh "--body '--repo=x'" --title "T" --body '--repo=x'
# shellcheck disable=SC2016
check "--body '--repo=x' stays the body, not a repo flag" \
    bash -c 'grep -qx -- "--repo=x" "$1" && ! grep -Fxq -- --repo "$1"' _ "$ARGV_LOG"
check "--body '--repo=x' footer" body_signed "$ARGV_LOG"
assert_calls_gh "a value --no-signature" --title --no-signature --body B
# shellcheck disable=SC2016
check "a value --no-signature is kept as the title" \
    bash -c 'grep -Fxq -- --no-signature "$1"' _ "$ARGV_LOG"
check "a value --no-signature does not suppress the footer" body_signed "$ARGV_LOG"
assert_calls_gh "--base --body" --title "T" --base --body --body B
# shellcheck disable=SC2016
check "--base --body: \"--body\" is the base branch" \
    bash -c '[[ "$(sed -n 3p "$1")" = "--base" && "$(sed -n 4p "$1")" = "--body" ]] && grep -qx B "$1"' _ "$ARGV_LOG"

echo
echo "=== A body file that is a pipe is signed ==="
assert_calls_gh "--body-file <(...)" --title "T" --body-file <(printf 'Process substitution body\n')
# shellcheck disable=SC2016
check "process-substitution body read and signed" \
    bash -c 'grep -Fq "Process substitution body" "$1"' _ "$BODY_CAPTURE_DIR/body.md"
check "process-substitution body footer" body_signed "$BODY_CAPTURE_DIR/body.md"
FIFO="$SANDBOX/body.fifo"
mkfifo "$FIFO"
printf 'Fifo body\n' > "$FIFO" &
assert_calls_gh "-F FIFO" --title "T" -F "$FIFO"
wait
# shellcheck disable=SC2016
check "FIFO body read and signed" \
    bash -c 'grep -Fq "Fifo body" "$1"' _ "$BODY_CAPTURE_DIR/body.md"
check "FIFO body footer" body_signed "$BODY_CAPTURE_DIR/body.md"
rm -f "$FIFO"
assert_exit_code "missing --body-file → exit 2" 2 \
    --title "T" --body-file "$SANDBOX/no-such-body.md"
# shellcheck disable=SC2016
check "missing --body-file: gh not called" bash -c '[[ ! -f "$1" ]]' _ "$ARGV_LOG"
assert_exit_code "directory as --body-file → exit 2" 2 \
    --title "T" --body-file "$SANDBOX"

echo
echo "=== A long body is checked whole (no pipe to cut short) ==="
FILLER=$(head -c 100000 /dev/zero | tr '\0' 'x')
# shellcheck disable=SC2016  # the backticks are literal markdown
assert_calls_gh "100 KB already-signed inline body" \
    --title "T" --body "$(printf '**Authored-By**: `Early`\n%s' "$FILLER")"
# shellcheck disable=SC2016
check "100 KB signed inline body keeps one footer" \
    bash -c '[[ "$(grep -cF "**Authored-By**:" "$1")" -eq 1 ]]' _ "$ARGV_LOG"

echo
echo "=== gh-written bodies (--fill, --template, --recover) need a body or --no-signature ==="
# shellcheck disable=SC2016  # the bash -c programs expand their own $1
for args in "--fill" "-f" "-df" "--fill-first" "--fill-verbose" "--template|tpl.md" "-T|tpl.md" "--recover|r.json"; do
    IFS='|' read -r -a argv <<<"$args"
    assert_exit_code "${argv[*]} with no body → exit 2" 2 --title "T" "${argv[@]}"
    check "${argv[*]} with no body: gh not called" bash -c '[[ ! -f "$1" ]]' _ "$ARGV_LOG"
done
out=$(run_wrapper --title "T" --fill 2>&1)
# shellcheck disable=SC2016
check "--fill refusal names --fill and --no-signature" \
    bash -c '[[ "$1" == *"--no-signature"* && "$1" == *"--fill with no"* ]]' _ "$out"
assert_calls_gh "--fill --no-signature: the explicit opt-out creates unsigned" --title "T" --fill --no-signature
# shellcheck disable=SC2016
check "--fill --no-signature: --fill reaches gh" bash -c 'grep -Fxq -- --fill "$1"' _ "$ARGV_LOG"
assert_calls_gh "--template with a body: the body is signed" --title "T" --template tpl.md --body "B"
check "--template with a body: footer" body_signed "$ARGV_LOG"
assert_calls_gh "--fill=false is not a fill" --title "T" --fill=false --body "B"
assert_exit_code "--recover with a body → exit 2 (gh loads it over the body)" 2 \
    --title "T" --recover r.json --body "B"
# shellcheck disable=SC2016
check "--recover with a body: gh not called" bash -c '[[ ! -f "$1" ]]' _ "$ARGV_LOG"
RECOVER_BODY="$SANDBOX/recover-body.md"
printf 'Recover body\n' > "$RECOVER_BODY"
assert_exit_code "--recover with --body-file → exit 2" 2 \
    --title "T" --recover r.json --body-file "$RECOVER_BODY"
# shellcheck disable=SC2016
check "--recover with --body-file: gh not called" bash -c '[[ ! -f "$1" ]]' _ "$ARGV_LOG"
reset_capture
out=$(printf 'Recover stdin body\n' | run_wrapper --title "T" --recover r.json --body-stdin 2>&1)
rc=$?
# shellcheck disable=SC2016
check "--recover with --body-stdin → exit 2, gh not called, the reason named" \
    bash -c '[[ "$1" -eq 2 && ! -f "$2" && "$3" == *"--recover makes gh load the recovered input over any --body / --body-file"* ]]' \
    _ "$rc" "$ARGV_LOG" "$out"
assert_calls_gh "--recover --no-signature: the explicit opt-out" --title "T" --recover r.json --no-signature
unset AGENT_NAME AGENT_MODEL
assert_exit_code "identity unset + --fill → exit 2" 2 --title "T" --fill
export AGENT_NAME="Test Agent"
export AGENT_MODEL="test-model"

pass295() { echo "  PASS [#295]:       $1"; PASS=$((PASS + 1)); }
fail295() { echo "  FAIL [#295]:       $1"; FAIL=$((FAIL + 1)); }
echo
echo "=== Registered project repositories are accepted (issue #295) ==="
# A sandbox main checkout (its own copy of the scripts, its own registry)
# run the way a project session runs it: cwd in a registered project's own
# checkout, no project/ symlink. Remotes are github.com URLs that are
# never contacted (`gh` is shimmed; only `gh pr create` is reached).
R295="$SANDBOX/r295"
WS295="$R295/ws"
mkdir -p "$WS295/.agent/scripts"
cp "$SCRIPT_DIR/../gh_create_pr.sh" "$SCRIPT_DIR/../_project_registry.sh" \
    "$SCRIPT_DIR/../_gh_create_args.sh" "$WS295/.agent/scripts/"
git -C "$WS295" init -q -b main
git -C "$WS295" remote add origin https://github.com/ws-owner/ws.git
DEMO295="$R295/demo"
git init -q -b main "$DEMO295"
git -C "$DEMO295" remote add origin git@github.com:demo-owner/demo.git
# A scratch clone nested inside the registered root: the guard accepts its
# cwd (under a registered root) but its slug is no registered root's.
git init -q -b main "$DEMO295/scratch"
git -C "$DEMO295/scratch" remote add origin https://github.com/stray-owner/stray.git
UNREL295="$R295/unrelated"
git init -q -b main "$UNREL295"
git -C "$UNREL295" remote add origin https://github.com/demo-owner/demo.git
run295() {  # <cwd>: run the sandbox copy there; sets OUT295 and RC295
    rm -f "$ARGV_LOG"
    OUT295=$(cd "$1" && env -u WORKTREE_ISSUE TMPDIR="$R295" \
        bash "$WS295/.agent/scripts/gh_create_pr.sh" --title t --body b --no-signature 2>&1)
    RC295=$?
}

# Nothing registered: the demo checkout is refused by the guard.
run295 "$DEMO295"
if [[ "$RC295" -eq 1 && "$OUT295" == *"refusing to run"* && ! -f "$ARGV_LOG" ]]; then
    pass295 "nothing registered: the demo checkout is refused by the guard"
else
    fail295 "nothing registered: rc=$RC295 out=${OUT295:0:300}"
fi

echo "demo single_project $DEMO295" > "$WS295/.agent/projects.local"
run295 "$DEMO295"
if [[ "$RC295" -eq 0 && -f "$ARGV_LOG" ]]; then
    pass295 "registered root: its repository is accepted (gh pr create reached)"
else
    fail295 "registered root: rc=$RC295 out=${OUT295:0:300}"
fi

run295 "$DEMO295/scratch"
if [[ "$RC295" -eq 2 && ! -f "$ARGV_LOG" && "$OUT295" == *"gh would target 'stray-owner/stray'"* \
      && "$OUT295" == *"Project repo:   demo-owner/demo"* ]]; then
    pass295 "registered root, other slug: refused by the safety check, accepted slugs listed"
else
    fail295 "registered root, other slug: rc=$RC295 out=${OUT295:0:300}"
fi

run295 "$UNREL295"
if [[ "$RC295" -eq 1 && "$OUT295" == *"refusing to run"* && ! -f "$ARGV_LOG" ]]; then
    pass295 "unrelated checkout (same slug, not registered): refused by the guard"
else
    fail295 "unrelated checkout: rc=$RC295 out=${OUT295:0:300}"
fi

# A registry with a parse error: registry_repo_slugs prints nothing and
# returns 0 under set -e, so a run from the workspace checkout itself
# (the guard does not read the registry there) still completes.
echo "bad name with spaces=" > "$WS295/.agent/projects.local"
run295 "$WS295"
if [[ "$RC295" -eq 0 && -f "$ARGV_LOG" ]]; then
    pass295 "registry parse error: a workspace run is not broken by the slug lookup"
else
    fail295 "registry parse error: rc=$RC295 out=${OUT295:0:300}"
fi

# The first machine's shape: a legacy project/ checkout and registered roots
# that are clones of the same repository (ssh and https origins). The
# accepted set holds that slug once, and each place is accepted.
git init -q -b main "$WS295/project"
git -C "$WS295/project" remote add origin git@github.com:demo-owner/demo.git
DEMO295B="$R295/demo-b"
git init -q -b main "$DEMO295B"
git -C "$DEMO295B" remote add origin https://github.com/demo-owner/demo.git
printf 'demo single_project %s\ndemo-b single_project %s\n' "$DEMO295" "$DEMO295B" \
    > "$WS295/.agent/projects.local"
run295 "$DEMO295/scratch"
LISTED295="$(grep -F 'Project repo:' <<< "$OUT295")"
if [[ "$RC295" -eq 2 && ! -f "$ARGV_LOG" && "$LISTED295" == "   Project repo:   demo-owner/demo" ]]; then
    pass295 "legacy project/ plus registered roots, one slug: listed once in the refusal"
else
    fail295 "legacy project/ plus registered roots: rc=$RC295 listed=[$LISTED295] out=${OUT295:0:300}"
fi
for CWD295 in "$WS295/project" "$DEMO295" "$DEMO295B"; do
    run295 "$CWD295"
    if [[ "$RC295" -eq 0 && -f "$ARGV_LOG" ]]; then
        pass295 "legacy project/ plus registered roots: ${CWD295#"$R295"/} accepted"
    else
        fail295 "legacy project/ plus registered roots, ${CWD295#"$R295"/}: rc=$RC295 out=${OUT295:0:300}"
    fi
done

echo
echo "=== Temp files ==="
if [[ -s "$LEAK_LOG" ]]; then
    echo "  FAIL [tmp]:        temp files left behind:"; sed 's/^/    /' "$LEAK_LOG"
    FAIL=$((FAIL + 1))
else
    echo "  PASS [tmp]:        every run left its TMPDIR empty"
    PASS=$((PASS + 1))
fi

echo
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"

[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
