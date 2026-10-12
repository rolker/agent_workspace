#!/usr/bin/env bash
# .agent/scripts/tests/test_capture.sh
# Tests for .agent/scripts/capture.sh (the one-line inbox writer) and
# .agent/scripts/_settings.sh (the machine-local settings reader), issue #386.
#
# Hermetic: a synthetic workspace (copies of the scripts under test plus a
# registry naming one synthetic project), a stub HOME and every inbox live
# under one `mktemp -d` sandbox, which honours TMPDIR. No real hosted
# project, no ~/.claude, no gh, no network.
#
# Run: bash .agent/scripts/tests/test_capture.sh

set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR WORKTREE_ISSUE AGENT_SETTINGS_FILE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SB="$(mktemp -d)"
cleanup() { chmod -R u+w "$SB" 2>/dev/null; rm -rf "$SB"; }
trap cleanup EXIT
# Git discovery never climbs out of the sandbox, so a TMPDIR that happens to
# sit inside a checkout cannot leak that checkout's branch or settings in.
GIT_CEILING_DIRECTORIES="$(dirname "$SB")"
export GIT_CEILING_DIRECTORIES

for f in capture.sh _settings.sh _project_registry.sh; do
    [[ -f "$SRC/$f" ]] || { fail "script under test missing: $f"; }
done

# --- sandbox workspace -------------------------------------------------------
WS="$SB/ws"
mkdir -p "$WS/.agent/scripts" "$SB/home" "$SB/demo/sub" "$SB/outside" "$SB/inbox"
for f in capture.sh _settings.sh _project_registry.sh; do
    [[ -f "$SRC/$f" ]] && cp "$SRC/$f" "$WS/.agent/scripts/"
done
mkdir -p "$WS/.agent/project_types/single_project"
printf 'demo  single_project  %s\n' "$SB/demo" > "$WS/.agent/projects.local"
CAP="$WS/.agent/scripts/capture.sh"
SETTINGS="$WS/.agent/settings.local"
INBOX="$SB/inbox/in.txt"

# run_cap <cwd> <args...>: runs capture.sh with the stub HOME; sets RC, OUT, ERR.
run_cap() {
    local cwd="$1"; shift
    RC=0
    OUT="$(cd "$cwd" && HOME="$SB/home" bash "$CAP" "$@" 2>"$SB/err")" || RC=$?
    ERR="$(cat "$SB/err")"
}
lines_of() { [[ -f "$1" ]] && wc -l < "$1" | tr -d ' ' || echo 0; }

# --- 1. inbox not set ----------------------------------------------------------
echo "TEST: no settings file: fails, says how to set it, echoes the text, writes nothing"
run_cap "$WS" "a thought"
if [[ $RC -eq 1 ]] && [[ "$OUT$ERR" == *"inbox="* ]] && [[ "$OUT$ERR" == *"not saved: a thought"* ]] \
    && [[ "$OUT$ERR" == *"$SETTINGS"* ]] && [[ ! -e "$INBOX" ]]; then
    pass "(unset) exit 1, instruction, text echoed, nothing written"
else
    fail "(unset) rc=$RC out='$OUT' err='$ERR'"
fi

echo "TEST: settings file without an inbox key behaves the same"
printf 'run_record=%s\n' "$SB/inbox/runs.txt" > "$SETTINGS"
run_cap "$WS" "another thought"
if [[ $RC -eq 1 ]] && [[ "$OUT$ERR" == *"not saved: another thought"* ]] && [[ ! -e "$INBOX" ]]; then
    pass "(no key) exit 1, text echoed"
else
    fail "(no key) rc=$RC out='$OUT' err='$ERR'"
fi

echo "TEST: empty text is a usage error"
printf 'inbox=%s\n' "$INBOX" > "$SETTINGS"
run_cap "$WS" ""
[[ $RC -eq 2 ]] && [[ ! -e "$INBOX" ]] && pass "(empty) exit 2" || fail "(empty) rc=$RC"
run_cap "$WS"
[[ $RC -eq 2 ]] && pass "(no args) exit 2" || fail "(no args) rc=$RC"

# --- 2. fields -----------------------------------------------------------------
# field <n> of the last inbox line
field() { tail -n1 "$INBOX" | cut -f"$1"; }

echo "TEST: project field"
run_cap "$SB/demo/sub" "in demo"
[[ $RC -eq 0 && "$(field 2)" == "demo" && "$(field 4)" == "in demo" ]] \
    && pass "(project) registered cwd gives its name" || fail "(project) rc=$RC line='$(tail -n1 "$INBOX" 2>/dev/null)' err='$ERR'"
run_cap "$WS" "in ws"
[[ $RC -eq 0 && "$(field 2)" == "workspace" ]] \
    && pass "(project) workspace cwd gives workspace" || fail "(project) ws line='$(tail -n1 "$INBOX" 2>/dev/null)'"
run_cap "$SB/outside" "outside"
[[ $RC -eq 0 && "$(field 2)" == "none" ]] \
    && pass "(project) outside cwd gives none" || fail "(project) outside line='$(tail -n1 "$INBOX" 2>/dev/null)'"
cp "$WS/.agent/projects.local" "$SB/projects.good"
printf 'bad line with too many words here and=there\n' >> "$WS/.agent/projects.local"
before="$(lines_of "$INBOX")"
run_cap "$SB/demo" "malformed registry"
after="$(lines_of "$INBOX")"
[[ $RC -eq 0 && "$(field 2)" == "unknown" && $after -eq $((before + 1)) ]] \
    && pass "(project) malformed registry gives unknown, line still written" \
    || fail "(project) malformed rc=$RC line='$(tail -n1 "$INBOX" 2>/dev/null)'"
cp "$SB/projects.good" "$WS/.agent/projects.local"

date_re='^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}$'
[[ "$(field 1)" =~ $date_re ]] && pass "(date) local time with offset" || fail "(date) '$(field 1)'"

echo "TEST: issue field"
RC=0; (cd "$WS" && WORKTREE_ISSUE=42 HOME="$SB/home" bash "$CAP" "from env" >/dev/null 2>&1) || RC=$?
[[ $RC -eq 0 && "$(field 3)" == "42" ]] && pass "(issue) from WORKTREE_ISSUE" || fail "(issue) env field='$(field 3)'"
git init -q -b feature/issue-77 "$SB/demo" 2>/dev/null || { git init -q "$SB/demo" && git -C "$SB/demo" checkout -q -b feature/issue-77; }
run_cap "$SB/demo" "from branch"
[[ "$(field 3)" == "77" ]] && pass "(issue) from feature/issue-N branch" || fail "(issue) branch field='$(field 3)'"
git -C "$SB/demo" checkout -q -b feature/ISSUE-91-some-thing
run_cap "$SB/demo" "from long branch"
[[ "$(field 3)" == "91" ]] && pass "(issue) from feature/ISSUE-N-desc branch" || fail "(issue) long branch field='$(field 3)'"
git -C "$SB/demo" checkout -q -b main
run_cap "$SB/demo" "no issue"
[[ "$(field 3)" == "-" ]] && pass "(issue) absent gives -" || fail "(issue) absent field='$(field 3)'"

# --- 3. one line per call ---------------------------------------------------------
echo "TEST: tabs and newlines collapse to single spaces"
before="$(lines_of "$INBOX")"
run_cap "$WS" $'first\tsecond\n\nthird\r\nfourth'
after="$(lines_of "$INBOX")"
[[ $after -eq $((before + 1)) && "$(field 4)" == "first second third fourth" ]] \
    && [[ "$(tail -n1 "$INBOX" | awk -F'\t' '{print NF}')" -eq 4 ]] \
    && pass "(collapse) one line, four fields" || fail "(collapse) last='$(tail -n1 "$INBOX")' lines $before->$after"

echo "TEST: two parallel calls give two intact lines"
before="$(lines_of "$INBOX")"
( cd "$WS" && HOME="$SB/home" bash "$CAP" "parallel one" >/dev/null 2>&1 ) &
( cd "$WS" && HOME="$SB/home" bash "$CAP" "parallel two" >/dev/null 2>&1 ) &
wait
after="$(lines_of "$INBOX")"
if [[ $after -eq $((before + 2)) ]] && grep -q $'\tparallel one$' "$INBOX" && grep -q $'\tparallel two$' "$INBOX"; then
    pass "(parallel) both lines intact"
else
    fail "(parallel) lines $before->$after"
fi

# --- 4. inbox location and write failures -------------------------------------------
echo "TEST: a relative inbox resolves against the settings file's directory"
printf 'inbox=notes/in.txt\n' > "$SETTINGS"
mkdir -p "$WS/.agent/notes"
run_cap "$SB/outside" "relative"
[[ $RC -eq 0 ]] && grep -q 'relative$' "$WS/.agent/notes/in.txt" 2>/dev/null && [[ ! -e "$SB/outside/notes" ]] \
    && pass "(relative) landed under the settings file's directory" || fail "(relative) rc=$RC err='$ERR'"

echo "TEST: a missing inbox directory fails and prints the text"
printf 'inbox=%s\n' "$SB/nodir/in.txt" > "$SETTINGS"
run_cap "$WS" "lost thought"
[[ $RC -ne 0 && "$OUT$ERR" == *"not saved: lost thought"* && ! -e "$SB/nodir" ]] \
    && pass "(missing dir) non-zero, text printed, directory not created" || fail "(missing dir) rc=$RC out='$OUT' err='$ERR'"

echo "TEST: an unwritable inbox fails and prints the text"
if [[ "$(id -u)" -eq 0 ]]; then
    pass "(read-only) skipped: running as root, permissions are not enforced"
else
    mkdir -p "$SB/ro"; chmod 555 "$SB/ro"
    printf 'inbox=%s\n' "$SB/ro/in.txt" > "$SETTINGS"
    run_cap "$WS" "ro thought"
    [[ $RC -ne 0 && "$OUT$ERR" == *"not saved: ro thought"* ]] \
        && pass "(read-only) non-zero, text printed" || fail "(read-only) rc=$RC out='$OUT' err='$ERR'"
    chmod 755 "$SB/ro"
fi

echo "TEST: a CRLF settings file works for both keys"
printf 'inbox=%s  \r\nrun_record=%s\r\n' "$INBOX" "$SB/inbox/runs.txt" > "$SETTINGS"
run_cap "$WS" "crlf"
[[ $RC -eq 0 && "$(field 4)" == "crlf" ]] && pass "(crlf) inbox key read" || fail "(crlf) rc=$RC err='$ERR'"
v="$(source "$WS/.agent/scripts/_settings.sh" && settings_get "$WS" run_record)"
[[ "$v" == "$SB/inbox/runs.txt" ]] && pass "(crlf) run_record key read" || fail "(crlf) run_record='$v'"

# --- 5. worktree fallback -------------------------------------------------------------
echo "TEST: a linked worktree without settings.local reads the main checkout's"
REPO="$SB/repo"
mkdir -p "$REPO/.agent/scripts"
cp "$WS/.agent/scripts/"* "$REPO/.agent/scripts/"
git init -q "$REPO"
git -C "$REPO" add -A
git -C "$REPO" -c user.name=t -c user.email=t@example.invalid commit -q -m init
git -C "$REPO" worktree add -q "$SB/repo-wt" -b wt 2>/dev/null
printf 'inbox=%s\n' "$SB/inbox/main.txt" > "$REPO/.agent/settings.local"
v="$(source "$REPO/.agent/scripts/_settings.sh" && settings_get "$SB/repo-wt" inbox)"
[[ "$v" == "$SB/inbox/main.txt" ]] && pass "(worktree) main checkout's settings found" || fail "(worktree) got '$v'"
rm "$REPO/.agent/settings.local"
RC=0
OUT="$(cd "$SB/repo-wt" && HOME="$SB/home" bash "$SB/repo-wt/.agent/scripts/capture.sh" "wt thought" 2>&1)" || RC=$?
[[ $RC -eq 1 && "$OUT" == *"$SB/repo-wt/.agent/settings.local"* && "$OUT" == *"$REPO/.agent/settings.local"* \
    && "$OUT" == *"not saved: wt thought"* ]] \
    && pass "(worktree) neither found: both paths named" || fail "(worktree) rc=$RC out='$OUT'"

# --- 6. settings reader ------------------------------------------------------------------
echo "TEST: settings reader"
S2="$SB/s2.local"
cat > "$S2" <<EOF
# a comment
inbox=~/notes/in.txt
inbox=$SB/second.txt
run_record=a=b=c
shellish=\$(touch $SB/marker)
EOF
r() { (source "$WS/.agent/scripts/_settings.sh" && AGENT_SETTINGS_FILE="$S2" HOME="$SB/home" settings_get "$WS" "$1"); }
[[ "$(r inbox)" == "$SB/home/notes/in.txt" ]] && pass "(reader) ~/ expands to HOME; first match wins" || fail "(reader) inbox='$(r inbox)'"
[[ "$(r run_record)" == "a=b=c" ]] && pass "(reader) value containing = kept whole" || fail "(reader) run_record='$(r run_record)'"
[[ "$(r shellish)" == "\$(touch $SB/marker)" && ! -e "$SB/marker" ]] \
    && pass "(reader) a shell-looking line is not executed" || fail "(reader) shellish='$(r shellish)'"
rc=0; r missing >/dev/null || rc=$?
[[ $rc -eq 1 ]] && pass "(reader) absent key returns 1" || fail "(reader) absent key rc=$rc"
rc=0; (source "$WS/.agent/scripts/_settings.sh" && AGENT_SETTINGS_FILE="$SB/none.local" settings_get "$WS" inbox) >/dev/null || rc=$?
[[ $rc -eq 1 ]] && pass "(reader) absent file returns 1" || fail "(reader) absent file rc=$rc"

echo ""
echo "test_capture: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
