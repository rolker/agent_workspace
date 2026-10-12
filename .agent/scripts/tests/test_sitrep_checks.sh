#!/usr/bin/env bash
# .agent/scripts/tests/test_sitrep_checks.sh
# Tests for .agent/scripts/sitrep_checks.sh (issue #386): the read-only
# check runner behind the sit-rep skill.
#
# Hermetic: a sandbox roadmap root (git repo with a synthetic GitHub remote),
# a sandbox runner checkout whose .agent/scripts holds stub scripts that
# record each call in a marker file, and a stub `gh` first on PATH, all under
# one `mktemp -d` sandbox (honours TMPDIR). No real gh call, no network, no
# real hosted project, no ~/.claude.
#
# Run: bash .agent/scripts/tests/test_sitrep_checks.sh

set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITREP="$SCRIPT_DIR/../sitrep_checks.sh"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SB="$(mktemp -d)"
trap 'chmod -R u+rw "$SB" 2>/dev/null; rm -rf "$SB"' EXIT
GIT_CEILING_DIRECTORIES="$(dirname "$SB")"
export GIT_CEILING_DIRECTORIES

[[ -f "$SITREP" ]] || fail "script under test missing: sitrep_checks.sh"

MARK="$SB/markers"; RCD="$SB/rc"
mkdir -p "$MARK" "$RCD" "$SB/bin" "$SB/root/docs" "$SB/root/.agent/scripts" \
    "$SB/runner/.agent/scripts" "$SB/elsewhere" "$SB/noremote/docs"

# --- stub gh: records its argv, prints $SB/gh_state, exits $SB/rc/gh ---------
cat > "$SB/bin/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$MARK/gh"
rc=\$(cat "$RCD/gh" 2>/dev/null || echo 0)
[ "\$rc" -eq 0 ] && cat "$SB/gh_state"
exit "\$rc"
EOF
chmod +x "$SB/bin/gh"
echo "CLOSED" > "$SB/gh_state"
export PATH="$SB/bin:$PATH"

# --- stub runner scripts: record "<cwd> <args>", exit $SB/rc/<name> ----------
RUNNER="$SB/runner"
for name in adapter user_tier_install.sh check_design_anchors.sh; do
    cat > "$RUNNER/.agent/scripts/$name" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "\$PWD" "\$*" >> "$MARK/$name"
exit "\$(cat "$RCD/$name" 2>/dev/null || echo 0)"
EOF
    chmod +x "$RUNNER/.agent/scripts/$name"
done
# The stub adapter keeps the real one's user-tier guard: exit 1 unless the
# cwd is inside the runner checkout.
cat > "$RUNNER/.agent/scripts/adapter" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "\$PWD" "\$*" >> "$MARK/adapter"
case "\$PWD" in "$RUNNER"|"$RUNNER"/*) ;; *) exit 1 ;; esac
exit "\$(cat "$RCD/adapter" 2>/dev/null || echo 0)"
EOF
chmod +x "$RUNNER/.agent/scripts/adapter"
mkdir -p "$RUNNER/.agent/project_types/single_project" "$SB/demo"
printf 'demo  single_project  %s\n' "$SB/demo" > "$RUNNER/.agent/projects.local"
export SITREP_SCRIPTS_DIR="$RUNNER/.agent/scripts"

# A project-root adapter that must never run.
cat > "$SB/root/.agent/scripts/adapter" <<EOF
#!/usr/bin/env bash
touch "$MARK/project-adapter"
EOF
chmod +x "$SB/root/.agent/scripts/adapter"

git init -q "$SB/root"
git -C "$SB/root" remote add origin https://github.com/acme/widgets.git
git init -q "$SB/elsewhere"
git -C "$SB/elsewhere" remote add origin https://github.com/acme/other.git
printf 'hello a*b world\n' > "$SB/root/docs/notes.md"

# run_rm <roadmap body> [extra args]: writes the roadmap, runs from
# $SB/elsewhere (cwd override: CWD=...); sets RC, OUT.
run_rm() {
    local body="$1"; shift
    printf '%s' "$body" > "$SB/root/docs/roadmap.md"
    RC=0
    OUT="$(cd "${CWD:-$SB/elsewhere}" && bash "$SITREP" --root "$SB/root" "$@" 2>"$SB/err")" || RC=$?
}
# res <item>: result column of the row whose item is <item>
res() { awk -F'\t' -v i="$1" '$2 == i { print $3; exit }' <<< "$OUT"; }
row() { awk -F'\t' -v i="$1" '$2 == i { print; exit }' <<< "$OUT"; }
# direction <rows...>: a roadmap whose Direction section has a Line/Check table
direction() {
    printf '# Roadmap\n\n## Direction\n\n| Line | Check |\n|------|-------|\n'
    printf '%s\n' "$@"
    printf '\n## Next section\n\nText.\n'
}
reset_marks() { rm -f "$MARK"/*; rm -f "$RCD"/*; echo "CLOSED" > "$SB/gh_state"; }

# --- 1. basic results ------------------------------------------------------------
echo "TEST: no check, file checks, field shape"
reset_marks
# Run from the roadmap root itself, so an unwanted glob of docs/* would
# match real files.
CWD="$SB/root" run_rm "$(direction \
    '| Nothing to check |  |' \
    '| Notes exist | file-exists docs/notes.md |' \
    '| Ghost exists | `file-exists docs/ghost.md` |' \
    '| Absolute | file-exists /etc/passwd |' \
    '| Dotdot | file-exists docs/../docs/notes.md |' \
    '| Has hello | file-contains docs/notes.md hello |' \
    '| Has star literal | file-contains docs/notes.md a*b world |' \
    '| Has nope | file-contains docs/notes.md nope nope |' \
    '| Glob | file-exists docs/* |' \
    '| Bare ref | #379 |' \
    '| Unknown kind | frobnicate x |')"
[[ $RC -eq 0 ]] && pass "(basic) exit 0" || fail "(basic) rc=$RC err=$(cat "$SB/err")"
[[ "$(res 'Nothing to check')" == unchecked ]] && pass "(basic) no check is unchecked" || fail "(basic) no check: $(row 'Nothing to check')"
[[ "$(row 'Nothing to check' | cut -f4)" == none ]] && pass "(basic) missing check printed as none" || fail "(basic) check field: $(row 'Nothing to check')"
[[ "$(res 'Notes exist')" == true ]] && pass "(basic) file-exists true" || fail "(basic) $(row 'Notes exist')"
[[ "$(res 'Ghost exists')" == false ]] && pass "(basic) file-exists false (backticks allowed)" || fail "(basic) $(row 'Ghost exists')"
[[ "$(res 'Absolute')" == unchecked && "$(res 'Dotdot')" == unchecked ]] && pass "(basic) absolute and .. paths unchecked" || fail "(basic) abs=$(res Absolute) dotdot=$(res Dotdot)"
[[ "$(res 'Has hello')" == true && "$(res 'Has nope')" == false ]] && pass "(basic) file-contains true/false" || fail "(basic) hello=$(res 'Has hello') nope=$(res 'Has nope')"
[[ "$(res 'Has star literal')" == true ]] && pass "(basic) file-contains takes the rest of the cell as a fixed string" || fail "(basic) star=$(res 'Has star literal')"
[[ "$(res 'Glob')" == false ]] && pass "(basic) a * in a cell is not globbed" || fail "(basic) glob=$(res Glob)"
[[ "$(res 'Bare ref')" == unchecked && "$(res 'Unknown kind')" == unchecked ]] && pass "(basic) bare #N and unknown kind unchecked" || fail "(basic) bare=$(res 'Bare ref') unknown=$(res 'Unknown kind')"
bad_rows="$(awk -F'\t' 'NF != 5 || $4 == "" || $1 == "" || $5 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/' <<< "$OUT")"
[[ -z "$bad_rows" ]] && pass "(basic) every row has five fields, a check and a date" || fail "(basic) malformed rows: $bad_rows"
[[ "$(awk -F'\t' '{print $1}' <<< "$OUT" | sort -u)" == line ]] && pass "(basic) rows print kind line" || fail "(basic) kinds: $(cut -f1 <<< "$OUT" | sort -u | tr '\n' ' ')"

echo "TEST: unreadable file for file-contains is unknown"
if [[ "$(id -u)" -eq 0 ]]; then
    pass "(unreadable) skipped: running as root"
else
    printf 'x\n' > "$SB/root/docs/locked.md"; chmod 000 "$SB/root/docs/locked.md"
    run_rm "$(direction '| Locked | file-contains docs/locked.md x |')"
    [[ "$(res Locked)" == unknown ]] && pass "(unreadable) unknown, not false" || fail "(unreadable) $(row Locked)"
    chmod 644 "$SB/root/docs/locked.md"
fi

# --- 2. gh-issue ---------------------------------------------------------------------
echo "TEST: gh-issue"
reset_marks
run_rm "$(direction '| Closed | gh-issue 5 closed |')"
[[ "$(res Closed)" == true ]] && pass "(gh) CLOSED matches closed" || fail "(gh) $(row Closed) err=$(cat "$SB/err")"
args="$(cat "$MARK/gh" 2>/dev/null)"
[[ "$args" == *"-R acme/widgets"* && "$args" != *"acme/other"* && "$args" == *"issue view 5"* ]] \
    && pass "(gh) -R from the roadmap root's remote, not the cwd's" || fail "(gh) args='$args'"
echo "OPEN" > "$SB/gh_state"
run_rm "$(direction '| Closed | gh-issue 5 closed |' '| Open upper | gh-issue 5 OPEN |')"
[[ "$(res Closed)" == false && "$(res 'Open upper')" == true ]] && pass "(gh) state compare, case-insensitive" || fail "(gh) closed=$(res Closed) open=$(res 'Open upper')"
reset_marks
run_rm "$(direction '| Explicit | gh-issue someone/thing#9 closed |')"
[[ "$(res Explicit)" == true && "$(cat "$MARK/gh" 2>/dev/null)" == *"-R someone/thing"*"issue view 9"* ]] \
    && pass "(gh) owner/repo#N names the repo" || fail "(gh) explicit $(row Explicit) args=$(cat "$MARK/gh" 2>/dev/null)"
reset_marks
run_rm "$(direction '| Bad n | gh-issue five closed |' '| Bad state | gh-issue 5 merged |' \
    '| Bad slug | gh-issue bad#5 closed |' '| Extra | gh-issue 5 closed now |' '| Missing | gh-issue 5 |')"
ok=true
for i in 'Bad n' 'Bad state' 'Bad slug' 'Extra' 'Missing'; do [[ "$(res "$i")" == unchecked ]] || ok=false; done
[[ $ok == true && ! -e "$MARK/gh" ]] && pass "(gh) malformed arguments unchecked, gh never called" || fail "(gh) malformed: $OUT"
echo 1 > "$RCD/gh"
run_rm "$(direction '| Fails | gh-issue 5 closed |')"
[[ "$(res Fails)" == unknown ]] && pass "(gh) failing gh is unknown" || fail "(gh) $(row Fails)"
reset_marks
printf '## Direction\n\n| Line | Check |\n|---|---|\n| No remote | gh-issue 5 closed |\n' > "$SB/noremote/docs/roadmap.md"
OUT="$(cd "$SB/elsewhere" && bash "$SITREP" --root "$SB/noremote" 2>/dev/null)"
[[ "$(res 'No remote')" == unknown && ! -e "$MARK/gh" ]] && pass "(gh) root without a GitHub remote is unknown" || fail "(gh) noremote $(row 'No remote')"

# --- 3. script checks ----------------------------------------------------------------
echo "TEST: script forms that must never run"
reset_marks
run_rm "$(direction \
    '| Install | script user_tier_install.sh |' \
    '| Uninstall | script user_tier_install.sh --uninstall |' \
    '| Check extra | script user_tier_install.sh --check --require now |' \
    '| Anchors arg | script check_design_anchors.sh /elsewhere |' \
    '| Build | script adapter --project demo build |' \
    '| Test | script adapter --project demo test |' \
    '| Sync | script adapter --project demo sync |' \
    '| Inst | script adapter --project demo install |' \
    '| Setup | script adapter --project demo setup |' \
    '| Validate extra | script adapter --project demo validate --force |' \
    '| Bad name | script adapter --project ../x validate |' \
    '| Path | script ../root/.agent/scripts/adapter --project demo validate |' \
    '| Star | script * |')"
ok=true
for i in Install Uninstall 'Check extra' 'Anchors arg' Build Test Sync Inst Setup 'Validate extra' 'Bad name' Path Star; do
    [[ "$(res "$i")" == unchecked ]] || { ok=false; echo "    $i -> $(res "$i")"; }
done
[[ $ok == true ]] && pass "(never-run) all unchecked" || fail "(never-run) some not unchecked"
[[ -z "$(ls -A "$MARK")" ]] && pass "(never-run) no stub ran, project-root adapter untouched" || fail "(never-run) markers: $(ls "$MARK")"

echo "TEST: allowed script forms run from the runner's checkout and map exit codes"
for code in 0 1 2; do
    reset_marks
    for n in adapter user_tier_install.sh check_design_anchors.sh; do echo "$code" > "$RCD/$n"; done
    run_rm "$(direction \
        '| Validates | script adapter --project demo validate |' \
        '| Tier | script user_tier_install.sh --check |' \
        '| Tier req | `script user_tier_install.sh --check --require` |' \
        '| Anchors | script check_design_anchors.sh |')"
    want=$([[ $code -eq 0 ]] && echo true || { [[ $code -eq 1 ]] && echo false || echo unknown; })
    ok=true
    for i in Validates Tier 'Tier req' Anchors; do [[ "$(res "$i")" == "$want" ]] || ok=false; done
    [[ $ok == true ]] && pass "(allowed) exit $code gives $want" || fail "(allowed) exit $code: $OUT"
    [[ -s "$MARK/adapter" && -s "$MARK/user_tier_install.sh" && -s "$MARK/check_design_anchors.sh" ]] \
        && pass "(allowed) exit $code: stubs ran" || fail "(allowed) exit $code: markers $(ls "$MARK")"
done
reset_marks
CWD=/ run_rm "$(direction '| Validates | script adapter --project demo validate |')"
cwd_seen="$(cut -d' ' -f1 "$MARK/adapter" 2>/dev/null)"
[[ "$(res Validates)" == true && "$cwd_seen" == "$RUNNER" ]] \
    && pass "(allowed) run from / outside the sandbox: cwd is the runner checkout, result true" \
    || fail "(allowed) from /: $(row Validates) cwd_seen='$cwd_seen'"
[[ ! -e "$MARK/project-adapter" ]] && pass "(allowed) project-root adapter never ran" || fail "(allowed) project-root adapter ran"

echo "TEST: adapter name checked against the runner's registry first"
reset_marks
run_rm "$(direction '| Unregistered | script adapter --project nosuch validate |')"
[[ "$(res Unregistered)" == unknown && ! -e "$MARK/adapter" ]] && pass "(registry) unregistered name unknown, adapter not run" || fail "(registry) $(row Unregistered)"
cp "$RUNNER/.agent/projects.local" "$SB/projects.good"
printf 'bad line with too many words here and=there\n' >> "$RUNNER/.agent/projects.local"
run_rm "$(direction '| Malformed | script adapter --project demo validate |')"
[[ "$(res Malformed)" == unknown && ! -e "$MARK/adapter" ]] && pass "(registry) malformed registry unknown" || fail "(registry) $(row Malformed)"
cp "$SB/projects.good" "$RUNNER/.agent/projects.local"
mv "$RUNNER/.agent/scripts/check_design_anchors.sh" "$SB/cda.bak"
run_rm "$(direction '| Missing script | script check_design_anchors.sh |')"
[[ "$(res 'Missing script')" == unknown ]] && pass "(missing) missing script unknown" || fail "(missing) $(row 'Missing script')"
mv "$SB/cda.bak" "$RUNNER/.agent/scripts/check_design_anchors.sh"

# --- 4. combination rule ----------------------------------------------------------------
echo "TEST: combination of several checks in one cell"
reset_marks
echo 1 > "$RCD/gh"   # gh-issue -> unknown
T='file-exists docs/notes.md'; F='file-exists docs/ghost.md'; U='gh-issue 5 closed'; C='frobnicate'
run_rm "$(direction \
    "| TU | $T ; $U |" "| FU | $F ; $U |" "| TC | $T ; $C |" "| FC | $F ; $C |" \
    "| TF | $T ; $F |" "| TT | $T ; $T |" "| FF | $F ; $F |" "| CC | $C ; $C |")"
for pair in TU:unknown FU:unknown TC:partial FC:partial TF:partial TT:true FF:false CC:unchecked; do
    i="${pair%%:*}"; want="${pair#*:}"
    [[ "$(res "$i")" == "$want" ]] && pass "(combine) $i gives $want" || fail "(combine) $i: $(row "$i")"
done

# --- 5. section and table shape ---------------------------------------------------------
echo "TEST: tables picked by header, deferrals, checklist items, section bounds"
reset_marks
body='# Roadmap

## Direction

Intro text.

| Line | Check |
|------|-------|
| L true | file-exists docs/notes.md |
| L false | file-exists docs/ghost.md |
| L none | |

```
| Line | Check |
|------|-------|
| Fenced | file-exists docs/notes.md |
```

| Item | Notes |
|------|-------|
| Other table | file-exists docs/notes.md |

| Deferral | Revisit check |
|----------|---------------|
| Paused thing (#12) | file-exists docs/notes.md |
| Waiting thing | |

- [ ] A checklist deferral (#12)

## Later

| Line | Check |
|------|-------|
| After section | file-exists docs/notes.md |
'
run_rm "$body"
[[ -z "$(row 'Other table')" && -z "$(row 'Fenced')" && -z "$(row 'After section')" ]] \
    && pass "(shape) other table, fenced example and later sections not read" || fail "(shape) $OUT"
[[ "$(row 'Paused thing (#12)' | cut -f1,3)" == $'deferral\ttrue' ]] && pass "(shape) deferral row kind and result" || fail "(shape) $(row 'Paused thing (#12)')"
[[ "$(res 'Waiting thing')" == unchecked ]] && pass "(shape) deferral without a check is unchecked" || fail "(shape) $(row 'Waiting thing')"
fmt="$(awk -F'\t' '$1 == "format"' <<< "$OUT")"
[[ "$fmt" == *"A checklist deferral (#12)"* && "$(cut -f3 <<< "$fmt")" == unchecked ]] \
    && pass "(shape) checklist item prints a format row" || fail "(shape) format row: '$fmt'"
run_rm "$body" --summary
[[ "$OUT" == "lines 1/3 deferrals 1/2" ]] && pass "(summary) counts match the rows" || fail "(summary) '$OUT'"

echo "TEST: no Direction section"
run_rm $'# Roadmap\n\n## Other\n\n| Line | Check |\n|---|---|\n| X | file-exists docs/notes.md |\n'
[[ $RC -eq 0 && "$(wc -l <<< "$OUT" | tr -d ' ')" -eq 1 && "$(cut -f1-4 <<< "$OUT")" == $'section\t(no Direction section)\tunchecked\tnone' ]] \
    && pass "(section) one section row" || fail "(section) rc=$RC '$OUT'"
run_rm $'# Roadmap\n' --summary
[[ "$OUT" == "lines 0/0 deferrals 0/0" ]] && pass "(section) summary of an absent section" || fail "(section) summary '$OUT'"

echo "TEST: usage"
RC=0; bash "$SITREP" --bogus >/dev/null 2>&1 || RC=$?
[[ $RC -eq 2 ]] && pass "(usage) unknown option exits 2" || fail "(usage) rc=$RC"

echo ""
echo "test_sitrep_checks: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
