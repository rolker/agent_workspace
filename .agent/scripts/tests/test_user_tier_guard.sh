#!/usr/bin/env bash
# .agent/scripts/tests/test_user_tier_guard.sh
# Enforces the user-tier rule (#317, #265 PR 3, ADR-0016): every entry in
# .agent/user_tier_scripts.txt is inert outside the workspace checkout and
# outside every registered project root.
#
# Two layers:
#   1. Static — each manifest entry either calls registry_require_root, or
#      carries a `# user-tier: inert` marker, or a
#      `# user-tier: guarded-by:<script>` marker naming an entry that does.
#      An ungoverned entry fails here, so adding a row to the manifest
#      without governing the script cannot pass silently.
#   2. Behavioural — each non-inert entry is run from a sandbox git repo
#      that is registered nowhere, with HOME redirected. Scripts must
#      refuse; the two promoted hooks must produce no block and no log
#      line. The guard fires before any gh/git/network call, so this needs
#      no `gh` auth and no network.
#
# Hermetic: HOME, the workspace copy, and the registry all live under one
# `mktemp -d` sandbox, which honours TMPDIR.
# The real ~/.claude is never read or written.
#
# Run: bash .agent/scripts/tests/test_user_tier_guard.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MANIFEST="$WS_ROOT/.agent/user_tier_scripts.txt"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

if ! command -v jq >/dev/null 2>&1; then
    echo "FATAL: jq is required (the promoted hooks need it too)" >&2
    exit 1
fi
if [[ ! -f "$MANIFEST" ]]; then
    echo "FATAL: manifest not found at $MANIFEST" >&2
    exit 1
fi

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# ------------------------------------------------------------- manifest ---
ENTRIES=()
while IFS= read -r line; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    ENTRIES+=("$line")
done < "$MANIFEST"

[[ "${#ENTRIES[@]}" -gt 0 ]] && pass "manifest lists ${#ENTRIES[@]} entries" \
    || fail "manifest is empty"

# --------------------------------------------------------- static layer ---
# marker_of <abs path> -- prints "guard", "inert", "guarded-by:<name>", or "none"
# Markers are checked before the guard call so that an inert file whose
# marker text merely NAMES registry_require_root isn't misread as guarded.
# The guard pattern deliberately requires a real call (a non-comment line),
# not a mention in prose.
marker_of() {
    local f="$1" gb
    if grep -q '^# user-tier: inert' "$f"; then echo "inert"; return; fi
    gb=$(grep -o '^# user-tier: guarded-by:[A-Za-z0-9._-]*' "$f" | head -n1)
    if [[ -n "$gb" ]]; then echo "guarded-by:${gb##*:}"; return; fi
    if grep -qE '^[[:space:]]*registry_require_root[[:space:]]' "$f"; then echo "guard"; return; fi
    echo "none"
}

NONINERT=()
for rel in "${ENTRIES[@]}"; do
    abs="$WS_ROOT/$rel"
    if [[ ! -f "$abs" ]]; then
        fail "manifest entry does not exist: $rel"
        continue
    fi
    m=$(marker_of "$abs")
    case "$m" in
        guard)
            pass "governed (registry_require_root): $rel"
            NONINERT+=("$rel")
            ;;
        inert)
            pass "governed (inert marker): $rel"
            ;;
        guarded-by:*)
            target="${m#guarded-by:}"
            if [[ -f "$WS_ROOT/.agent/scripts/$target" ]] \
               && grep -qE '^[[:space:]]*registry_require_root[[:space:]]' "$WS_ROOT/.agent/scripts/$target"; then
                pass "governed (delegates to guarded $target): $rel"
            else
                fail "$rel delegates to $target, which has no registry_require_root call"
            fi
            ;;
        *)
            fail "UNGOVERNED user-tier entry: $rel has neither a registry_require_root call nor a '# user-tier:' marker"
            ;;
    esac
done

# The guard must precede the first gh/git invocation, or the refusal path
# has already touched something.
for rel in "${NONINERT[@]}"; do
    abs="$WS_ROOT/$rel"
    guard_line=$(grep -nE '^[[:space:]]*registry_require_root[[:space:]]' "$abs" | head -n1 | cut -d: -f1)
    # An allowlist of calls that actually touch a repo or the network,
    # rather than a denylist of everything named gh/git -- the latter trips
    # on prose ("must run from within a git repository") and on the
    # read-only `git rev-parse` / `git worktree list` location queries that
    # several of these scripts must run to compute the very root the guard
    # is then called with.
    #
    # Matched anywhere on the line (start, inside $( ), after a pipe, as an
    # assignment's right-hand side), so cross_model_review.sh's
    # `$(gh pr view ...)` -- the call that actually escaped an earlier
    # version of this check -- is caught.
    first_call=$(grep -nE '(^|[^[:alnum:]_.-])(gh[[:space:]]+(pr|issue|api|repo|run|release|label|auth)|git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+(push|commit|merge|rebase|fetch|pull|checkout|switch|branch|tag|clone|worktree[[:space:]]+(add|remove)))[[:space:]]' "$abs" \
        | grep -vE ':[[:space:]]*#' | head -n1 | cut -d: -f1)
    if [[ -z "$first_call" || "$guard_line" -lt "$first_call" ]]; then
        pass "guard precedes the first gh/git call: $rel"
    else
        fail "$rel calls gh/git at line $first_call, before its guard at line $guard_line"
    fi
done

# ---------------------------------------------------- behavioural layer ---
# A workspace copy whose registry is empty, plus an unrelated git repo that
# is registered nowhere. Anything run from the unrelated repo must be inert.
WSC="$SANDBOX/ws"
mkdir -p "$WSC"
cp -r "$WS_ROOT/.agent" "$WSC/.agent"
cp -r "$WS_ROOT/.claude" "$WSC/.claude"
git -C "$WSC" init -q -b main
: > "$WSC/.agent/projects.local"

OUTSIDE="$SANDBOX/unrelated"
mkdir -p "$OUTSIDE"
git -C "$OUTSIDE" init -q -b main
git -C "$OUTSIDE" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

FAKE_HOME="$SANDBOX/home"
mkdir -p "$FAKE_HOME/.claude"

# --- scripts refuse ---
# Each script is driven with an invocation that WOULD do real work, not
# --help: the rule is that the guard fires before any repo-affecting
# action, and a usage dump is not one. A missing guard would let these
# reach git/gh, so a regression is loud rather than silent.
probe_args() {  # <manifest path> -- prints the argv for a real invocation
    case "$1" in
        *worktree_create.sh)    echo "--issue 1 --type workspace" ;;
        *worktree_enter.sh)     echo "--issue 1 --type workspace --print-path" ;;
        *worktree_remove.sh)    echo "--issue 1 --type workspace --force" ;;
        *worktree_list.sh)      echo "" ;;
        *merge_pr.sh)           echo "--pr 1" ;;
        *gh_create_pr.sh)       echo "--title t --body b" ;;
        *gh_create_issue.sh)    echo "--title t --body b" ;;
        *fetch_pr_reviews.sh)   echo "--pr 1" ;;
        *cross_model_review.sh) echo "--pr 1 --no-progress" ;;
        *build.sh|*test.sh)     echo "" ;;
        */adapter)              echo "build" ;;
        *) return 1 ;;
    esac
}

for rel in "${NONINERT[@]}"; do
    [[ "$rel" == .claude/hooks/* ]] && continue
    abs="$WSC/$rel"
    if ! args=$(probe_args "$rel"); then
        fail "no probe invocation defined for the new manifest entry $rel -- add one to probe_args()"
        continue
    fi
    # shellcheck disable=SC2086  # $args is a deliberate word-split argv
    out=$(cd "$OUTSIDE" && HOME="$FAKE_HOME" AGENT_NAME=t AGENT_EMAIL=t@t \
        timeout 30 bash "$abs" $args 2>&1); rc=$?
    if [[ "$rc" -ne 0 && "$out" == *"refusing to run"* ]]; then
        pass "refuses from an unregistered repo: $rel"
    else
        fail "$rel did not refuse from an unregistered repo (rc=$rc out=${out:0:200})"
    fi
done

# --- hooks stay silent ---
hook_payload() {  # <cwd> <command>
    jq -n --arg cwd "$1" --arg cmd "$2" '{
        session_id: "t", tool_name: "Bash",
        tool_input: {command: $cmd, description: "t"},
        cwd: $cwd, permission_mode: "default"
    }'
}

BLOCK_HOOK="$WSC/.claude/hooks/block-bash-tool-mapping.sh"
LOG_HOOK="$WSC/.claude/hooks/log-tool-use.sh"

# `cat <file>` is the canonical blocked pattern; from an unregistered cwd
# it must pass through (exit 0) and leave no sidecar log entry.
rm -f "$FAKE_HOME/.claude/tool-mapping-blocks.jsonl"
out=$(cd "$OUTSIDE" && HOME="$FAKE_HOME" bash "$BLOCK_HOOK" \
    <<< "$(hook_payload "$OUTSIDE" "cat README.md")" 2>&1); rc=$?
if [[ "$rc" -eq 0 && ! -s "$FAKE_HOME/.claude/tool-mapping-blocks.jsonl" ]]; then
    pass "block-bash-tool-mapping.sh: no block and no sidecar log from an unregistered repo"
else
    fail "block hook fired outside a registered root (rc=$rc out=${out:0:160})"
fi

rm -f "$FAKE_HOME/.claude/tool-use-log.jsonl"
out=$(cd "$OUTSIDE" && HOME="$FAKE_HOME" bash "$LOG_HOOK" \
    <<< "$(hook_payload "$OUTSIDE" "ls")" 2>&1); rc=$?
if [[ "$rc" -eq 0 && ! -s "$FAKE_HOME/.claude/tool-use-log.jsonl" ]]; then
    pass "log-tool-use.sh: no log line from an unregistered repo"
else
    fail "log hook wrote a line outside a registered root (rc=$rc)"
fi

# --- and both still fire inside the workspace checkout ---
rm -f "$FAKE_HOME/.claude/tool-mapping-blocks.jsonl"
out=$(cd "$WSC" && HOME="$FAKE_HOME" bash "$BLOCK_HOOK" \
    <<< "$(hook_payload "$WSC" "cat README.md")" 2>&1); rc=$?
[[ "$rc" -eq 2 ]] && pass "block hook still blocks inside the workspace checkout" \
    || fail "block hook did not block inside the workspace checkout (rc=$rc)"

rm -f "$FAKE_HOME/.claude/tool-use-log.jsonl"
(cd "$WSC" && HOME="$FAKE_HOME" bash "$LOG_HOOK" \
    <<< "$(hook_payload "$WSC" "ls")" >/dev/null 2>&1)
[[ -s "$FAKE_HOME/.claude/tool-use-log.jsonl" ]] \
    && pass "log hook still logs inside the workspace checkout" \
    || fail "log hook wrote nothing inside the workspace checkout"

# --- and inside a registered project root ---
PROOT="$SANDBOX/registered"
mkdir -p "$PROOT"
git -C "$PROOT" init -q -b main
echo "demo single_project $PROOT" > "$WSC/.agent/projects.local"

rm -f "$FAKE_HOME/.claude/tool-use-log.jsonl"
(cd "$PROOT" && HOME="$FAKE_HOME" bash "$LOG_HOOK" \
    <<< "$(hook_payload "$PROOT" "ls")" >/dev/null 2>&1)
[[ -s "$FAKE_HOME/.claude/tool-use-log.jsonl" ]] \
    && pass "log hook logs inside a registered project root" \
    || fail "log hook did not log inside a registered project root"

rm -f "$FAKE_HOME/.claude/tool-mapping-blocks.jsonl"
out=$(cd "$PROOT" && HOME="$FAKE_HOME" bash "$BLOCK_HOOK" \
    <<< "$(hook_payload "$PROOT" "cat README.md")" 2>&1); rc=$?
[[ "$rc" -eq 2 ]] && pass "block hook blocks inside a registered project root" \
    || fail "block hook did not block inside a registered project root (rc=$rc)"

echo ""
echo "test_user_tier_guard: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
