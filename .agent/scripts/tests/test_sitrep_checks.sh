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
[ -e "$SB/gh_eat" ] && cat > /dev/null
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

echo "TEST: a path under a directory that cannot be entered is unknown, a missing parent false"
if [[ "$(id -u)" -eq 0 ]]; then
    pass "(no-enter) skipped: running as root"
else
    mkdir -p "$SB/root/docs/shut/inner"
    printf 'x\n' > "$SB/root/docs/shut/inner/f.md"
    chmod 000 "$SB/root/docs/shut"
    run_rm "$(direction \
        '| Shut contains | file-contains docs/shut/inner/f.md x |' \
        '| Shut exists | file-exists docs/shut/inner/f.md |' \
        '| Shut direct | file-exists docs/shut/f.md |' \
        '| Shut adr | adr-status docs/shut/inner/f.md accepted |' \
        '| No parent | file-exists docs/nodir/deeper/f.md |' \
        '| File as parent | file-exists docs/notes.md/f.md |')"
    chmod 755 "$SB/root/docs/shut"
    ok=true
    for i in 'Shut contains' 'Shut exists' 'Shut direct' 'Shut adr'; do [[ "$(res "$i")" == unknown ]] || ok=false; done
    [[ $ok == true ]] && pass "(no-enter) every check under it is unknown, not false" \
        || fail "(no-enter) contains=$(res 'Shut contains') exists=$(res 'Shut exists') direct=$(res 'Shut direct') adr=$(res 'Shut adr')"
    [[ "$(res 'No parent')" == false && "$(res 'File as parent')" == false ]] \
        && pass "(no-enter) a missing parent or a file as parent is still false" || fail "(no-enter) noparent=$(res 'No parent') fileparent=$(res 'File as parent')"
    rm -rf "$SB/root/docs/shut"
fi

echo "TEST: a roadmap that cannot be read is not read as one without the section"
if [[ "$(id -u)" -eq 0 ]]; then
    pass "(roadmap unreadable) skipped: running as root"
else
    printf '%s' "$(direction '| L | file-exists docs/notes.md |')" > "$SB/root/docs/locked-roadmap.md"
    chmod 000 "$SB/root/docs/locked-roadmap.md"
    RC=0; OUT="$(cd "$SB/elsewhere" && bash "$SITREP" --root "$SB/root" --roadmap "$SB/root/docs/locked-roadmap.md" 2>/dev/null)" || RC=$?
    chmod 644 "$SB/root/docs/locked-roadmap.md"
    [[ $RC -eq 0 && "$(wc -l <<< "$OUT" | tr -d ' ')" -eq 1 \
        && "$(cut -f1-3 <<< "$OUT")" == $'section\t(roadmap not readable: '"$SB/root/docs/locked-roadmap.md"$')\tunknown' ]] \
        && pass "(roadmap unreadable) no read permission: one unknown section row" || fail "(roadmap unreadable) rc=$RC '$OUT'"
    mkdir -p "$SB/hidden/sub"
    printf '%s' "$(direction '| L | file-exists docs/notes.md |')" > "$SB/hidden/sub/roadmap.md"
    chmod 000 "$SB/hidden"
    OUT="$(cd "$SB/elsewhere" && bash "$SITREP" --root "$SB/root" --roadmap "$SB/hidden/sub/roadmap.md" 2>/dev/null)"
    chmod 755 "$SB/hidden"
    [[ "$(cut -f2-3 <<< "$OUT")" == "(roadmap not readable: $SB/hidden/sub/roadmap.md)"$'\tunknown' ]] \
        && pass "(roadmap unreadable) under a directory that cannot be entered: not readable, not missing" || fail "(roadmap unreadable) hidden '$OUT'"
    rm -rf "$SB/hidden" "$SB/root/docs/locked-roadmap.md"
fi
mkdir -p "$SB/root/docs/dir-roadmap.md"
OUT="$(cd "$SB/elsewhere" && bash "$SITREP" --root "$SB/root" --roadmap "$SB/root/docs/dir-roadmap.md" 2>/dev/null)"
[[ "$(cut -f2-3 <<< "$OUT")" == "(roadmap not readable: $SB/root/docs/dir-roadmap.md)"$'\tunknown' ]] \
    && pass "(roadmap unreadable) a directory in its place: not readable" || fail "(roadmap unreadable) dir '$OUT'"
rmdir "$SB/root/docs/dir-roadmap.md"

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

echo "TEST: a whole cell in backticks with ; inside is split after the backticks go"
run_rm "$(direction "| Wrapped pair | \`$T ; $T\` |" "| Wrapped mixed | \`$T ; $F\` |")"
[[ "$(res 'Wrapped pair')" == true && "$(res 'Wrapped mixed')" == partial ]] \
    && pass "(combine) wrapped cell reads as its checks" || fail "(combine) wrapped pair=$(res 'Wrapped pair') mixed=$(res 'Wrapped mixed')"

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
body_shape="$body"
run_rm "$body"
[[ -z "$(row 'Other table')"&& -z "$(row 'Fenced')" && -z "$(row 'After section')" ]] \
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

echo "TEST: a section with no recognised table, an empty section, a missing roadmap"
run_rm $'## Direction\n\nOnly prose here.\n\n| Item | Notes |\n|---|---|\n| x | y |\n\n## Next\n'
[[ "$(cut -f1-3 <<< "$OUT")" == $'section\t(no Line or Deferral table)\tunchecked' ]] \
    && pass "(section) prose-only section prints its own row" || fail "(section) no table: '$OUT'"
run_rm $'## Direction\n\n## Next\n'
[[ "$(cut -f1-3 <<< "$OUT")" == $'section\t(no Line or Deferral table)\tunchecked' ]] \
    && pass "(section) empty section prints the same row" || fail "(section) empty: '$OUT'"
OUT="$(cd "$SB/elsewhere" && bash "$SITREP" --root "$SB/root" --roadmap "$SB/root/docs/nosuch.md" 2>/dev/null)"
[[ "$(cut -f1 <<< "$OUT")" == section && "$(cut -f2 <<< "$OUT")" == "(roadmap not found: $SB/root/docs/nosuch.md)" ]] \
    && pass "(section) a missing roadmap file is named, not read as no section" || fail "(section) missing roadmap: '$OUT'"

echo "TEST: a Line or Deferral table with a header and no rows prints a section row"
run_rm $'## Direction\n\n| Line | Check |\n|---|---|\n\n| Deferral | Revisit check |\n|---|---|\n\n## Next\n'
[[ $RC -eq 0 && "$OUT" == $'section\t(no rows in the Line or Deferral tables)\tunchecked\tnone\t'* \
    && "$(wc -l <<< "$OUT" | tr -d ' ')" -eq 1 ]] \
    && pass "(section) header-only tables give one section row, no blank line" || fail "(section) header only: '$OUT'"

# --- 6. fences, headings, line endings ------------------------------------------------------
echo "TEST: a fenced ## Direction before the real section is skipped"
for fence in '```' '~~~'; do
    body="# Roadmap

${fence}markdown
## Direction

| Line | Check |
|------|-------|
| Example only | file-exists docs/ghost.md |
${fence}

## Direction

| Line | Check |
|------|-------|
| Real line | file-exists docs/notes.md |

## Next
"
    run_rm "$body"
    [[ -z "$(row 'Example only')" && "$(res 'Real line')" == true ]] \
        && pass "(fence $fence) example skipped, real section read" || fail "(fence $fence) '$OUT'"
done
body='## Direction

~~~
```
| Line | Check |
|------|-------|
| Inner | file-exists docs/notes.md |
~~~

````
```
still fenced
````

| Line | Check |
|------|-------|
| After fences | file-exists docs/notes.md |
'
run_rm "$body"
[[ -z "$(row Inner)" && "$(res 'After fences')" == true ]] \
    && pass "(fence) a backtick fence inside ~~~ does not close it; a longer fence needs a long close" || fail "(fence nested) '$OUT'"

echo "TEST: a backtick line with a backtick after it is not a fence"
body='## Direction

```x``` is inline code, not a fence

| Line | Check |
|------|-------|
| After inline | file-exists docs/notes.md |

~~~ info with `backticks`
| Line | Check |
|------|-------|
| Tilde fenced | file-exists docs/notes.md |
~~~
'
run_rm "$body"
[[ "$(res 'After inline')" == true && -z "$(row 'Tilde fenced')" ]] \
    && pass "(fence) backtick opener needs an info string without backticks; a tilde opener does not" || fail "(fence info) '$OUT'"

echo "TEST: ### subheadings stay in the section; CRLF roadmap"
run_rm $'## Direction\n\n### Lines\n\n| Line | Check |\n|---|---|\n| Under sub | file-exists docs/notes.md |\n\n## Next\n'
[[ "$(res 'Under sub')" == true ]] && pass "(heading) ### does not end the section" || fail "(heading) '$OUT'"
run_rm $'## Direction\r\n\r\n| Line | Check |\r\n|---|---|\r\n| Crlf | file-contains docs/notes.md hello |\r\n\r\n## Next\r\n'
[[ "$(res Crlf)" == true ]] && pass "(crlf) CRLF roadmap read" || fail "(crlf) '$OUT'"

echo "TEST: indented ATX and setext headings end the section; a thematic break does not"
for heading in '  ## Later' '   # Later' '##' $'Later\n=====' $'Later\n-----' $'Later\n  ---'; do
    body="## Direction

| Line | Check |
|---|---|
| Inside | file-exists docs/notes.md |

${heading}

| Line | Check |
|---|---|
| Outside | file-exists docs/notes.md |
"
    run_rm "$body"
    [[ "$(res Inside)" == true && -z "$(row Outside)" ]] \
        && pass "(heading) '${heading//$'\n'/\\n}' ends the section" || fail "(heading) '${heading//$'\n'/\\n}': '$OUT'"
done
for brk in '---' '***' '- - -' '    ## indented code'; do
    body="## Direction

| Line | Check |
|---|---|
| Inside | file-exists docs/notes.md |

${brk}

| Line | Check |
|---|---|
| Still inside | file-exists docs/notes.md |
"
    run_rm "$body"
    [[ "$(res Inside)" == true && "$(res 'Still inside')" == true ]] \
        && pass "(heading) '$brk' after a blank line does not end the section" || fail "(heading) '$brk': '$OUT'"
done
body="## Direction

| Line | Check |
|---|---|
| Inside | file-exists docs/notes.md |
---
| Line | Check |
|---|---|
| After rule | file-exists docs/notes.md |
"
run_rm "$body"
[[ "$(res 'After rule')" == true ]] && pass "(heading) --- right under a table row is not a setext underline" || fail "(heading) table rule: '$OUT'"
run_rm $'  ## Direction ##\n\n| Line | Check |\n|---|---|\n| Indented start | file-exists docs/notes.md |\n'
[[ "$(res 'Indented start')" == true ]] && pass "(heading) an indented ## Direction with closing #s starts the section" || fail "(heading) start: '$OUT'"

# --- 7. cells: escaped pipes, extra cells --------------------------------------------------
echo "TEST: GFM escaped pipes and rows with extra cells"
printf 'a|b here\nx\\ only\n' > "$SB/root/docs/pipes.md"
run_rm "$(direction \
    '| Escaped true | file-contains docs/pipes.md a\|b |' \
    '| Escaped false | file-contains docs/pipes.md a\|c |' \
    '| Prefix only | file-contains docs/pipes.md x\|y |' \
    '| Extra | file-exists docs/notes.md | stray |')"
[[ "$(res 'Escaped true')" == true && "$(res 'Escaped false')" == false && "$(res 'Prefix only')" == false ]] \
    && pass "(pipes) \\| is a literal pipe inside the check" \
    || fail "(pipes) true=$(res 'Escaped true') false=$(res 'Escaped false') prefix=$(res 'Prefix only')"
[[ "$(row 'Escaped true' | cut -f4)" == 'file-contains docs/pipes.md a|b' ]] \
    && pass "(pipes) check column shows the unescaped text" || fail "(pipes) check col '$(row 'Escaped true' | cut -f4)'"
[[ "$(res Extra)" == unchecked && "$(row Extra | cut -f4)" == *stray* ]] \
    && pass "(pipes) a row with extra cells is unchecked and shows them" || fail "(pipes) extra '$(row Extra)'"

echo "TEST: a data row with only empty cells or dashes prints a format row"
body='## Direction

| Line | Check |
|:-----|------:|
| Real | file-exists docs/notes.md |
|  |  |
| - | |
|---|---|

| Deferral | Revisit check |
|---|---|
| | - |
'
run_rm "$body"
fmt="$(awk -F'\t' '$1 == "format" { print $2 "=" $3 }' <<< "$OUT")"
[[ "$(res Real)" == true && "$(grep -c . <<< "$fmt")" -eq 4 \
    && "$fmt" == *"(empty row in the Line table: |  |  |)=unchecked"* \
    && "$fmt" == *"(empty row in the Line table: | - | |)=unchecked"* \
    && "$fmt" == *"(empty row in the Line table: |---|---|)=unchecked"* \
    && "$fmt" == *"(empty row in the Deferral table: | | - |)=unchecked"* ]] \
    && pass "(empty row) each one shown as a format row; the delimiter rows are not" || fail "(empty row) '$OUT'"
run_rm "$body" --summary
[[ "$OUT" == "lines 1/1 deferrals 0/0" ]] && pass "(empty row) format rows are not counted as lines" || fail "(empty row) summary '$OUT'"

# --- 8. path containment ---------------------------------------------------------------------
echo "TEST: symlinks that leave the root are refused"
printf 's3cret\n' > "$SB/secret.txt"
ln -s "$SB/secret.txt" "$SB/root/docs/esc"
ln -s "$SB" "$SB/root/linkdir"
ln -s notes.md "$SB/root/docs/alias"
run_rm "$(direction \
    '| Esc exists | file-exists docs/esc |' \
    '| Esc contains | file-contains docs/esc s3cret |' \
    '| Dir escape | file-exists linkdir/secret.txt |' \
    '| Dir escape missing | file-exists linkdir/nosuch.txt |' \
    '| In-root link | file-contains docs/alias hello |')"
[[ "$(res 'Esc exists')" == unchecked && "$(res 'Esc contains')" == unchecked \
    && "$(res 'Dir escape')" == unchecked && "$(res 'Dir escape missing')" == unchecked ]] \
    && pass "(contain) links out of the root are unchecked" \
    || fail "(contain) esc=$(res 'Esc exists') escc=$(res 'Esc contains') dir=$(res 'Dir escape') dirmiss=$(res 'Dir escape missing')"
[[ "$(res 'In-root link')" == true ]] && pass "(contain) a link inside the root is followed" || fail "(contain) in-root $(row 'In-root link')"
rm -f "$SB/root/docs/esc" "$SB/root/linkdir" "$SB/root/docs/alias"

echo "TEST: a trailing slash is tested as written"
mkdir -p "$SB/root/docs/decisions"
printf '# ADR\n\n## Status\n\nAccepted.\n' > "$SB/root/docs/decisions/slash.md"
ln -s notes.md "$SB/root/docs/alias"
run_rm "$(direction \
    '| File slash | file-exists docs/notes.md/ |' \
    '| File slash contains | file-contains docs/notes.md/ hello |' \
    '| ADR slash | adr-status docs/decisions/slash.md/ accepted |' \
    '| Link to file slash | file-exists docs/alias/ |' \
    '| Dir slash | file-exists docs/ |' \
    '| Dir no slash | file-exists docs |' \
    '| File no slash | file-exists docs/notes.md |')"
ok=true
for i in 'File slash' 'File slash contains' 'ADR slash' 'Link to file slash'; do [[ "$(res "$i")" == false ]] || ok=false; done
[[ $ok == true ]] && pass "(slash) a regular file named with a trailing / is false" \
    || fail "(slash) file=$(res 'File slash') contains=$(res 'File slash contains') adr=$(res 'ADR slash') link=$(res 'Link to file slash')"
[[ "$(res 'Dir slash')" == true && "$(res 'Dir no slash')" == true && "$(res 'File no slash')" == true ]] \
    && pass "(slash) a directory with or without /, a file without /, still true" || fail "(slash) dir=$(res 'Dir slash') dirno=$(res 'Dir no slash') file=$(res 'File no slash')"
rm -f "$SB/root/docs/alias" "$SB/root/docs/decisions/slash.md"

# --- 9. ADR status --------------------------------------------------------------------------
echo "TEST: adr-status reads the status line of that file only"
mkdir -p "$SB/root/docs/decisions"
printf '# ADR\n\n## Status\n\n**Provisional.** Promote when **Accepted.** is earned.\n\n## Context\n' > "$SB/root/docs/decisions/a.md"
printf '# ADR\n\n## Status\n\nAccepted. Plain form.\n' > "$SB/root/docs/decisions/b.md"
printf '# ADR\n\n## Status\n\n**Accepted.** Bold form.\n' > "$SB/root/docs/decisions/c.md"
printf '# ADR\n\nNo status heading. Accepted.\n' > "$SB/root/docs/decisions/d.md"
run_rm "$(direction \
    '| Prov | adr-status docs/decisions/a.md accepted |' \
    '| Prov is prov | adr-status docs/decisions/a.md Provisional |' \
    '| Plain | adr-status docs/decisions/b.md accepted |' \
    '| Bold | `adr-status docs/decisions/c.md Accepted` |' \
    '| No heading | adr-status docs/decisions/d.md accepted |' \
    '| Missing file | adr-status docs/decisions/zz.md accepted |' \
    '| Bad word | adr-status docs/decisions/b.md acc.pted |' \
    '| Escape | adr-status ../x.md accepted |')"
[[ "$(res Prov)" == false && "$(res 'Prov is prov')" == true ]] && pass "(adr) bold Accepted in the body is not the status" || fail "(adr) prov=$(res Prov) provprov=$(res 'Prov is prov')"
[[ "$(res Plain)" == true && "$(res Bold)" == true ]] && pass "(adr) plain and bold status lines" || fail "(adr) plain=$(res Plain) bold=$(res Bold)"
[[ "$(res 'No heading')" == unknown && "$(res 'Missing file')" == false ]] && pass "(adr) no Status heading unknown, missing file false" || fail "(adr) nohead=$(res 'No heading') missing=$(res 'Missing file')"
[[ "$(res 'Bad word')" == unchecked && "$(res Escape)" == unchecked ]] && pass "(adr) malformed arguments unchecked" || fail "(adr) bad=$(res 'Bad word') esc=$(res Escape)"

echo "TEST: adr-status reads CRLF files and skips fenced examples"
printf '# ADR\r\n\r\n## Status\r\n\r\nAccepted.\r\n' > "$SB/root/docs/decisions/e.md"
printf '# ADR\n\n```markdown\n## Status\n\nAccepted.\n```\n\n## Status\n\nProposed.\n' > "$SB/root/docs/decisions/f.md"
printf '# ADR\n\n~~~\n## Status\n```\nAccepted.\n~~~\n\n```x``` inline\n\n## Status\n\nProposed.\n' > "$SB/root/docs/decisions/g.md"
run_rm "$(direction \
    '| Crlf adr | adr-status docs/decisions/e.md accepted |' \
    '| Fenced accepted | adr-status docs/decisions/f.md accepted |' \
    '| Real proposed | adr-status docs/decisions/f.md proposed |' \
    '| Nested fence | adr-status docs/decisions/g.md proposed |')"
[[ "$(res 'Crlf adr')" == true ]] && pass "(adr) CRLF status read" || fail "(adr) crlf=$(res 'Crlf adr')"
[[ "$(res 'Fenced accepted')" == false && "$(res 'Real proposed')" == true ]] \
    && pass "(adr) a fenced Status example is skipped" || fail "(adr) fenced=$(res 'Fenced accepted') real=$(res 'Real proposed')"
[[ "$(res 'Nested fence')" == true ]] && pass "(adr) fence closes only on its own character; inline backticks are not a fence" || fail "(adr) nested=$(res 'Nested fence')"

# --- 10. external calls ----------------------------------------------------------------------
echo "TEST: gh cannot read the roadmap's remaining rows"
reset_marks
touch "$SB/gh_eat"
run_rm "$(direction '| First gh | gh-issue 5 closed |' '| After gh | file-exists docs/notes.md |')"
rm -f "$SB/gh_eat"
[[ "$(res 'First gh')" == true && "$(res 'After gh')" == true ]] \
    && pass "(stdin) rows after a gh check are still read" || fail "(stdin) '$OUT'"

echo "TEST: gh-issue slug must not start with -"
reset_marks
run_rm "$(direction '| Dash | gh-issue -x/y#5 closed |' '| Dot repo | gh-issue acme/.github#3 closed |')"
[[ "$(res Dash)" == unchecked && "$(res 'Dot repo')" == true ]] \
    && pass "(slug) -x/y unchecked, owner/.github accepted" || fail "(slug) dash=$(res Dash) dot=$(res 'Dot repo')"
[[ "$(grep -c -- '-R -x' "$MARK/gh" 2>/dev/null || true)" == 0 || ! -e "$MARK/gh" ]] \
    && pass "(slug) gh never got -R -x" || fail "(slug) gh args: $(cat "$MARK/gh")"

echo "TEST: a check that ignores TERM is killed after the grace period"
reset_marks
cat > "$RUNNER/.agent/scripts/check_design_anchors.sh" <<EOF
#!/usr/bin/env bash
trap '' TERM
sleep 30
EOF
start=$SECONDS
OUT="$(cd "$SB/elsewhere" && printf '%s' "$(direction '| Slow | script check_design_anchors.sh |')" > "$SB/root/docs/roadmap.md" \
    && SITREP_TIMEOUT=1 SITREP_KILL_AFTER=1 bash "$SITREP" --root "$SB/root" 2>/dev/null)"
took=$((SECONDS - start))
[[ "$(res Slow)" == unknown && $took -lt 8 ]] && pass "(timeout) unknown after ${took}s" || fail "(timeout) took ${took}s: '$OUT'"
cat > "$RUNNER/.agent/scripts/check_design_anchors.sh" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "\$PWD" "\$*" >> "$MARK/check_design_anchors.sh"
exit "\$(cat "$RCD/check_design_anchors.sh" 2>/dev/null || echo 0)"
EOF

# --- 11. one run, summary from saved rows --------------------------------------------------
echo "TEST: --summary-from counts saved rows and runs no check"
reset_marks
run_rm "$body_shape"
printf '%s\n' "$OUT" > "$SB/rows.tsv"
reset_marks
OUT2="$(bash "$SITREP" --summary-from "$SB/rows.tsv" 2>/dev/null)"
run_rm "$body_shape" --summary
[[ -n "$OUT2" && "$OUT2" == "$OUT" ]] && pass "(summary-from) matches --summary on the same roadmap" || fail "(summary-from) '$OUT2' vs '$OUT'"
printf 'line\tA\ttrue\tgh-issue 5 closed\t2026-01-01\nline\tB\tfalse\tx\t2026-01-01\ndeferral\tC\ttrue\ty\t2026-01-01\n' > "$SB/rows2.tsv"
reset_marks
OUT2="$(bash "$SITREP" --summary-from "$SB/rows2.tsv" 2>/dev/null)"
[[ "$OUT2" == "lines 1/2 deferrals 1/1" && ! -e "$MARK/gh" ]] && pass "(summary-from) hand-written rows, gh not called" || fail "(summary-from) '$OUT2'"
RC=0; bash "$SITREP" --summary-from "$SB/nosuch.tsv" >/dev/null 2>&1 || RC=$?
[[ $RC -eq 2 ]] && pass "(summary-from) unreadable file exits 2" || fail "(summary-from) rc=$RC"

echo "TEST: --summary-from refuses an empty argument, an empty file and rows it cannot read"
reset_marks
RC=0; OUT2="$(bash "$SITREP" --summary-from "" 2>"$SB/err")" || RC=$?
[[ $RC -ne 0 && -z "$OUT2" && -s "$SB/err" ]] && pass "(summary-from) empty argument refused, nothing run" || fail "(summary-from) '' rc=$RC out='$OUT2'"
: > "$SB/empty.tsv"
printf 'hello world\n' > "$SB/garbage.tsv"
printf 'line\tA\ttrue\tx\t2026-01-01\nline\tB\ttr' > "$SB/cut.tsv"
printf 'line\tA\tmaybe\tx\t2026-01-01\n' > "$SB/badword.tsv"
for f in empty garbage cut badword; do
    RC=0; OUT2="$(bash "$SITREP" --summary-from "$SB/$f.tsv" 2>"$SB/err")" || RC=$?
    [[ $RC -ne 0 && -z "$OUT2" && -s "$SB/err" ]] && pass "(summary-from) $f rows file refused with a message" || fail "(summary-from) $f rc=$RC out='$OUT2'"
done
printf 'section\t(no Direction section)\tunchecked\tnone\t2026-01-01\n' > "$SB/section.tsv"
OUT2="$(bash "$SITREP" --summary-from "$SB/section.tsv" 2>/dev/null)"
[[ "$OUT2" == "lines 0/0 deferrals 0/0" ]] && pass "(summary-from) a section row alone is a real run" || fail "(summary-from) section '$OUT2'"

echo "TEST: a run that did not read the roadmap has no summary to record"
printf 'section\t(roadmap not found: /x/roadmap.md)\tunchecked\tnone\t2026-01-01\n' > "$SB/notfound.tsv"
printf 'section\t(roadmap not readable: /x/roadmap.md)\tunknown\tnone\t2026-01-01\n' > "$SB/notreadable.tsv"
for f in notfound notreadable; do
    RC=0; OUT2="$(bash "$SITREP" --summary-from "$SB/$f.tsv" 2>"$SB/err")" || RC=$?
    [[ $RC -eq 3 && -z "$OUT2" && "$(cat "$SB/err")" == *"roadmap was not read"*"/x/roadmap.md"* ]] \
        && pass "(not read) --summary-from refuses $f rows: exit 3, no summary" || fail "(not read) $f rc=$RC out='$OUT2' err=$(cat "$SB/err")"
done
RC=0; OUT2="$(cd "$SB/elsewhere" && bash "$SITREP" --root "$SB/root" --roadmap "$SB/root/docs/nosuch.md" --summary 2>"$SB/err")" || RC=$?
[[ $RC -eq 3 && -z "$OUT2" && "$(cat "$SB/err")" == *"roadmap not found: $SB/root/docs/nosuch.md"* ]] \
    && pass "(not read) --summary on a missing roadmap: exit 3, no 0/0" || fail "(not read) --summary rc=$RC out='$OUT2' err=$(cat "$SB/err")"

echo "TEST: an interrupted run exits non-zero and prints no rows"
cat > "$RUNNER/.agent/scripts/check_design_anchors.sh" <<EOF
#!/usr/bin/env bash
sleep 1
EOF
printf '%s' "$(direction '| Before | file-exists docs/notes.md |' '| Slow | script check_design_anchors.sh |')" > "$SB/root/docs/roadmap.md"
# Job control gives the background run its own process group, so SIGINT
# is not ignored in it, as it is for a plain `&` job. A run started with
# SIGINT already ignored cannot see one at all; the probe skips that case.
for sig in INT TERM; do
    RC=0
    ( set -m
      bash -c 'kill -'"$sig"' $$; exit 0' & wait $! && exit 99
      bash "$SITREP" --root "$SB/root" > "$SB/int.out" 2>/dev/null &
      pid=$!
      sleep 0.3
      kill -"$sig" "$pid"
      wait "$pid" ) 2>/dev/null || RC=$?
    if [[ $RC -eq 99 ]]; then
        pass "(interrupt $sig) skipped: $sig is ignored in this environment"
    else
        [[ $RC -ne 0 && ! -s "$SB/int.out" ]] && pass "(interrupt $sig) exit $RC, no rows" || fail "(interrupt $sig) rc=$RC out='$(cat "$SB/int.out")'"
    fi
done
# running <pid>: the process exists and is not a zombie (a killed check
# re-parented to a slow reaper still answers kill -0).
running() {
    [[ -n "$1" ]] && kill -0 "$1" 2>/dev/null || return 1
    [[ "$(ps -o stat= -p "$1" 2>/dev/null)" != Z* ]]
}
echo "TEST: an interrupted run kills the running check at once"
# The check records its pid and sleeps far past the test's patience; a
# signal must end the run and the check within a few seconds, not when the
# sleep or the timeout ends.
cat > "$RUNNER/.agent/scripts/check_design_anchors.sh" <<EOF
#!/usr/bin/env bash
echo \$\$ > "$SB/slow.pid"
exec sleep 30
EOF
printf '%s' "$(direction '| Slow | script check_design_anchors.sh |' '| After | file-exists docs/notes.md |')" > "$SB/root/docs/roadmap.md"
for how in "TERM pid" "INT pid" "INT group"; do
    sig="${how% *}"; to="${how#* }"
    rm -f "$SB/slow.pid"
    RC=0
    start=$SECONDS
    ( set -m
      bash -c 'kill -'"$sig"' $$; exit 0' & wait $! && exit 99
      SITREP_TIMEOUT=60 bash "$SITREP" --root "$SB/root" > "$SB/int.out" 2>/dev/null &
      pid=$!
      for _ in $(seq 50); do [ -s "$SB/slow.pid" ] && break; sleep 0.1; done
      if [ "$to" = group ]; then kill -"$sig" -- "-$pid"; else kill -"$sig" "$pid"; fi
      wait "$pid" ) 2>/dev/null || RC=$?
    took=$((SECONDS - start))
    slow="$(cat "$SB/slow.pid" 2>/dev/null)"
    alive=no
    sleep 0.2
    running "$slow" && alive=yes
    if [[ $RC -eq 99 ]]; then
        pass "(interrupt now) $how skipped: $sig is ignored in this environment"
    else
        [[ $RC -ne 0 && $RC -ne 99 && ! -s "$SB/int.out" && -n "$slow" && $alive == no && $took -lt 8 ]] \
            && pass "(interrupt now) $how: exit $RC in ${took}s, no rows, the check is gone" \
            || fail "(interrupt now) $how: rc=$RC took=${took}s pid=${slow:-none} alive=$alive out='$(cat "$SB/int.out")'"
    fi
    [[ -n "$slow" ]] && kill -KILL "$slow" 2>/dev/null
done
rm -f "$SB/slow.pid"
cat > "$RUNNER/.agent/scripts/check_design_anchors.sh" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "\$PWD" "\$*" >> "$MARK/check_design_anchors.sh"
exit "\$(cat "$RCD/check_design_anchors.sh" 2>/dev/null || echo 0)"
EOF

# --- 12. run through the scripts/ symlink ----------------------------------------------------
echo "TEST: run through a scripts/ symlink, the default root is the checkout"
WS="$SB/ws"
mkdir -p "$WS/.agent/scripts" "$WS/docs"
for f in sitrep_checks.sh _issue_helpers.sh _project_registry.sh; do cp "$SCRIPT_DIR/../$f" "$WS/.agent/scripts/"; done
ln -s .agent/scripts "$WS/scripts"
printf '## Direction\n\n| Line | Check |\n|---|---|\n| Self | file-exists docs/roadmap.md |\n' > "$WS/docs/roadmap.md"
OUT="$(cd "$SB/elsewhere" && bash "$WS/scripts/sitrep_checks.sh" --summary 2>/dev/null)"
[[ "$OUT" == "lines 1/1 deferrals 0/0" ]] && pass "(symlink) default root read through scripts/" || fail "(symlink) '$OUT'"

# --- 13. the sit-rep skill's own commands -----------------------------------------------------
# The skill's steps are shell blocks the session runs as written; these run
# them (a ```bash block under "### <n>.", the first unless named) against
# a sandbox workspace.
SKILL="$SCRIPT_DIR/../../../.claude/skills/sitrep/SKILL.md"
skill_step() {  # <n> [k]: the k-th (default first) bash block of step n
    awk -v n="$1" -v k="${2:-1}" '
        $0 ~ "^### " n "\\. " { s = 1; next }
        s && /^### / { exit }
        s && !b && /^```bash/ { if (++c == k) b = 1; next }
        b && /^```/ { exit }
        b { print }' "$SKILL"
}
HOMESB="$SB/home"
mkdir -p "$HOMESB/.claude" "$SB/notes"
printf '%s' "$WS" > "$HOMESB/.claude/agent-workspace-root"
cp "$SCRIPT_DIR/../_settings.sh" "$WS/.agent/scripts/"
printf 'inbox=%s\nrun_record=%s\n' "$SB/notes/inbox.txt" "$SB/notes/runs.txt" > "$WS/.agent/settings.local"
printf '## Direction\n\n| Line | Check |\n|---|---|\n| Issue | gh-issue acme/widgets#5 closed |\n| Self | file-exists docs/roadmap.md |\n\n| Deferral | Revisit check |\n|---|---|\n| Later | file-exists docs/ghost.md |\n' > "$WS/docs/roadmap.md"
# run_step <n> [sed expr]: runs step n's block with the sandbox HOME; sets OUT, RC
run_step() {
    local blk; blk="$(skill_step "$1")"
    [ -n "${2:-}" ] && blk="$(sed "$2" <<< "$blk")"
    RC=0
    OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blk" 2>&1)" || RC=$?
}

echo "TEST: sit-rep step 1 runs the checks once and shows rows and summary"
reset_marks
run_step 1
rows_file="$(sed -n 's/^rows_file=//p' <<< "$OUT")"
n_gh="$(grep -c . "$MARK/gh" 2>/dev/null || true)"
[[ "$n_gh" == 1 ]] && pass "(skill 1) gh called once for one gh row" || fail "(skill 1) gh called ${n_gh:-0} times: $OUT"
[[ "$OUT" == *"lines 2/2 deferrals 0/1"* && -n "$rows_file" && -f "$rows_file" ]] \
    && pass "(skill 1) summary shown, rows saved" || fail "(skill 1) '$OUT'"

echo "TEST: sit-rep step 1 with a failed run keeps no rows file and says so"
mv "$WS/.agent/scripts/sitrep_checks.sh" "$SB/sitrep_checks.real"
printf '#!/usr/bin/env bash\nprintf "line\\tA\\ttrue\\tx\\t2026-01-01\\n"\nexit 130\n' > "$WS/.agent/scripts/sitrep_checks.sh"
chmod +x "$WS/.agent/scripts/sitrep_checks.sh"
mkdir -p "$SB/t1"
TMPDIR="$SB/t1" run_step 1
[[ "$OUT" != *rows_file=* && "$OUT" == *"exit 130"* && -z "$(ls -A "$SB/t1")" ]] \
    && pass "(skill 1) failed run: no rows_file, file removed, exit named" || fail "(skill 1) failed run: '$OUT' left: $(ls -A "$SB/t1")"
mv "$SB/sitrep_checks.real" "$WS/.agent/scripts/sitrep_checks.sh"

echo "TEST: sit-rep step 1 killed while the checks run stops them and removes the rows file"
cat > "$RUNNER/.agent/scripts/check_design_anchors.sh" <<EOF
#!/usr/bin/env bash
echo \$\$ > "$SB/slow.pid"
exec sleep 30
EOF
cp "$WS/docs/roadmap.md" "$SB/roadmap.saved"
printf '## Direction\n\n| Line | Check |\n|---|---|\n| Slow | script check_design_anchors.sh |\n' > "$WS/docs/roadmap.md"
mkdir -p "$SB/t1c"
rm -f "$SB/slow.pid"
blk="$(skill_step 1)"
start=$SECONDS
RC=0
( cd "$SB/elsewhere" || exit 98
  HOME="$HOMESB" TMPDIR="$SB/t1c" bash -c "$blk" > "$SB/step1.out" 2>&1 &
  bpid=$!
  for _ in $(seq 50); do [ -s "$SB/slow.pid" ] && break; sleep 0.1; done
  kill -TERM "$bpid"
  wait "$bpid" ) || RC=$?
took=$((SECONDS - start))
sleep 0.2
slow="$(cat "$SB/slow.pid" 2>/dev/null)"
alive=no; running "$slow" && alive=yes
[[ $RC -eq 143 && -n "$slow" && $alive == no && $took -lt 8 && -z "$(ls -A "$SB/t1c")" \
    && "$(cat "$SB/step1.out")" != *rows_file=* ]] \
    && pass "(skill 1) TERM: exit 143 in ${took}s, check gone, rows file removed" \
    || fail "(skill 1) TERM: rc=$RC took=${took}s alive=$alive left: $(ls -A "$SB/t1c") out='$(cat "$SB/step1.out")'"
[[ -n "$slow" ]] && kill -KILL "$slow" 2>/dev/null
rm -f "$SB/slow.pid"
mv "$SB/roadmap.saved" "$WS/docs/roadmap.md"
cat > "$RUNNER/.agent/scripts/check_design_anchors.sh" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "\$PWD" "\$*" >> "$MARK/check_design_anchors.sh"
exit "\$(cat "$RCD/check_design_anchors.sh" 2>/dev/null || echo 0)"
EOF

echo "TEST: sit-rep step 1 with no roadmap shows why and keeps nothing to record"
mv "$WS/docs/roadmap.md" "$SB/roadmap.saved"
mkdir -p "$SB/t1b"
TMPDIR="$SB/t1b" run_step 1
mv "$SB/roadmap.saved" "$WS/docs/roadmap.md"
[[ "$OUT" == *"(roadmap not found: "* && "$OUT" == *"no summary"* && "$OUT" != *rows_file=* \
    && "$OUT" != *"lines 0/0"* && -z "$(ls -A "$SB/t1b")" ]] \
    && pass "(skill 1) roadmap not found: row shown, no rows_file, file removed" || fail "(skill 1) no roadmap: '$OUT' left: $(ls -A "$SB/t1b")"

echo "TEST: sit-rep step 4 records the summary of the same rows and the inbox count"
printf '2026-10-12 10:00 -0400\tworkspace\t-\ta\n2026-10-12 10:00 -0400\tworkspace\t-\tb\n2026-10-12 10:00 -0400\tworkspace\t-\tc\n' > "$SB/notes/inbox.txt"
reset_marks
echo OPEN > "$SB/gh_state"   # a re-run would now give lines 1/2
# Step 2 counted 2 lines; a capture made since must not be in the record.
run_step 4 "s|<rows_file printed in step 1>|$rows_file|; s|<inbox_lines printed in step 2>|2|"
last="$(tail -n1 "$SB/notes/runs.txt" 2>/dev/null)"
[[ "$(cut -f2-4 <<< "$last")" == $'workspace\tlines 2/2 deferrals 0/1\tinbox 2' && ! -e "$MARK/gh" ]] \
    && pass "(skill 4) record from the saved rows and step 2's count, nothing re-run" || fail "(skill 4) last='$last' out='$OUT'"
[[ -n "$rows_file" && ! -e "$rows_file" ]] && pass "(skill 4) rows file removed" || fail "(skill 4) rows file left: $rows_file"
[[ "$(cut -f5- <<< "$last")" == $'2026-10-12 10:00 -0400\tworkspace\t-\tb' ]] \
    && pass "(skill 4) the record keeps the last inbox line step 2 counted" || fail "(skill 4) seen line: '$(cut -f5- <<< "$last")'"
printf 'inbox=%s\nrun_record=%s\n' "$SB/notes/inbox.txt" "$SB/nodir/runs.txt" > "$WS/.agent/settings.local"
printf 'line\tA\ttrue\tx\t2026-01-01\n' > "$SB/rows3.tsv"
run_step 4 "s|<rows_file printed in step 1>|$SB/rows3.tsv|; s|<inbox_lines printed in step 2>|3|"
[[ $RC -eq 0 && ! -e "$SB/nodir" && "$OUT" == *"not written"* ]] \
    && pass "(skill 4) missing record directory: not written, said so" || fail "(skill 4) nodir rc=$RC '$OUT'"
printf 'inbox=%s\nrun_record=%s\n' "$SB/notes/inbox.txt" "$SB/notes/runs.txt" > "$WS/.agent/settings.local"
before="$(wc -l < "$SB/notes/runs.txt")"
for case in "no rows file:" "empty rows file:$SB/empty.tsv" "roadmap not read:$SB/notfound.tsv"; do
    label="${case%%:*}"; f="${case#*:}"
    run_step 4 "s|<rows_file printed in step 1>|$f|; s|<inbox_lines printed in step 2>|3|"
    [[ $RC -eq 0 && "$(wc -l < "$SB/notes/runs.txt")" -eq $before && "$OUT" == *"not written"* ]] \
        && pass "(skill 4) $label: not written, said so" || fail "(skill 4) $label: rc=$RC '$OUT'"
done
printf 'line\tA\ttrue\tx\t2026-01-01\n' > "$SB/rows3.tsv"
run_step 4 "s|<rows_file printed in step 1>|$SB/rows3.tsv|"
[[ $RC -eq 0 && "$(wc -l < "$SB/notes/runs.txt")" -eq $before && "$OUT" == *"not written"* ]] \
    && pass "(skill 4) inbox count left as the placeholder: not written" || fail "(skill 4) placeholder: rc=$RC '$OUT'"

echo "TEST: sit-rep step 4 keeps a record without a final newline apart, and says when it cannot append"
printf '2026-10-12 09:00 -0400\tworkspace\tlines 0/2 deferrals 0/1\tinbox 1' > "$SB/notes/runs.txt"
printf 'line\tA\ttrue\tx\t2026-01-01\n' > "$SB/rows4.tsv"
run_step 4 "s|<rows_file printed in step 1>|$SB/rows4.tsv|; s|<inbox_lines printed in step 2>|2|"
[[ "$(wc -l < "$SB/notes/runs.txt" | tr -d ' ')" -eq 2 \
    && "$(sed -n 1p "$SB/notes/runs.txt")" == *$'\tinbox 1' \
    && "$(sed -n 2p "$SB/notes/runs.txt" | cut -f2-4)" == $'workspace\tlines 1/1 deferrals 0/0\tinbox 2' \
    && "$OUT" == *"written to"* ]] \
    && pass "(skill 4) a glued last line gets its newline first" || fail "(skill 4) glued: '$(cat -A "$SB/notes/runs.txt")' out='$OUT'"
if [[ "$(id -u)" -eq 0 ]]; then
    pass "(skill 4) read-only record skipped: running as root"
else
    cp "$SB/notes/runs.txt" "$SB/runs.before"
    chmod 444 "$SB/notes/runs.txt"
    printf 'line\tA\ttrue\tx\t2026-01-01\n' > "$SB/rows4.tsv"
    run_step 4 "s|<rows_file printed in step 1>|$SB/rows4.tsv|; s|<inbox_lines printed in step 2>|2|"
    chmod 644 "$SB/notes/runs.txt"
    [[ "$OUT" == *"not written (could not append to $SB/notes/runs.txt)"* && "$OUT" != *"written to"* ]] \
        && cmp -s "$SB/runs.before" "$SB/notes/runs.txt" \
        && pass "(skill 4) an append that fails says not written" || fail "(skill 4) read-only: '$OUT'"
    rm -f "$SB/runs.before"
fi

echo "TEST: sit-rep step 2 counts the inbox lines after the last one the previous run saw"
printf '2026-10-12 10:00 -0400\tworkspace\t-\ta\n2026-10-12 10:00 -0400\tworkspace\t-\tb\n2026-10-12 10:00 -0400\tworkspace\t-\tc\n' > "$SB/notes/inbox.txt"
rec() {  # <count> [<seen inbox line>]: one workspace record line
    printf '2026-10-12 10:00 -0400\tworkspace\tlines 1/2 deferrals 0/1\tinbox %s\t%s\n' "$1" "${2:-}" > "$SB/notes/runs.txt"
}
ib() { printf '2026-10-12 10:00 -0400\tworkspace\t-\t%s' "$1"; }
rec 2 "$(ib b)"
run_step 2
[[ "$OUT" == *"inbox_lines=3"* && "$OUT" == *"inbox_new=1"* ]] \
    && pass "(skill 2) same-minute capture counted new" || fail "(skill 2) '$OUT'"
rec 0
run_step 2
[[ "$OUT" == *"inbox_new=3"* ]] && pass "(skill 2) a run that saw an empty inbox: every line is new" || fail "(skill 2) from zero '$OUT'"
# Six lines seen; three removed from the top, five captured: 5 new, not 8 - 6 = 2.
: > "$SB/notes/inbox.txt"
for t in d e f g h i; do ib "$t" >> "$SB/notes/inbox.txt"; echo >> "$SB/notes/inbox.txt"; done
rec 6 "$(ib i)"
sed -i '1,3d' "$SB/notes/inbox.txt"
for t in n1 n2 n3 n4 n5; do ib "$t" >> "$SB/notes/inbox.txt"; echo >> "$SB/notes/inbox.txt"; done
run_step 2
[[ "$OUT" == *"inbox_lines=8"* && "$OUT" == *"inbox_new=5"* ]] \
    && pass "(skill 2) lines removed above the last one seen: new lines still counted right" || fail "(skill 2) removed+added '$OUT'"
rec 6 "$(ib gone)"
run_step 2
[[ "$OUT" == *"inbox_new=unknown (the line the last run saw last is gone)"* ]] \
    && pass "(skill 2) the last line seen was removed: unknown, with the reason" || fail "(skill 2) gone '$OUT'"
ib n2 >> "$SB/notes/inbox.txt"; echo >> "$SB/notes/inbox.txt"
rec 3 "$(ib n2)"
run_step 2
[[ "$OUT" == *"inbox_new=unknown (the line the last run saw last appears more than once)"* ]] \
    && pass "(skill 2) the last line seen now appears twice, not at its place: unknown" || fail "(skill 2) twice '$OUT'"
rec 5 "$(ib n2)"
run_step 2
[[ "$OUT" == *"inbox_new=4"* ]] && pass "(skill 2) a duplicate is fine when the line is still at its place" || fail "(skill 2) twice at place '$OUT'"
printf '2026-10-12 10:00 -0400\tworkspace\tlines 1/2 deferrals 0/1\n' > "$SB/notes/runs.txt"
run_step 2
[[ "$OUT" == *"inbox_new=unknown (the last record has no inbox count)"* ]] && pass "(skill 2) no count in the record: unknown" || fail "(skill 2) no count '$OUT'"

echo "TEST: sit-rep step 2 skips blank lines in the count, the oldest and the list"
printf '\n  \n%s\n\n%s\n \n' "$(ib x)" "$(ib y)" > "$SB/notes/inbox.txt"
sed -i '1s/^/\r/' "$SB/notes/inbox.txt"
rec 1 "$(ib x)"
run_step 2
listed="$(sed -n '/^---$/,$p' <<< "$OUT" | sed 1d)"
[[ "$OUT" == *"inbox_lines=2"* && "$OUT" == *"inbox_oldest=2026-10-12 10:00 -0400"* && "$OUT" == *"inbox_new=1"* \
    && "$(grep -c . <<< "$listed")" -eq 2 && "$(grep -c '^[[:space:]]*$' <<< "$listed")" -eq 0 ]] \
    && pass "(skill 2) blank lines skipped everywhere" || fail "(skill 2) blanks '$OUT'"

echo "TEST: sit-rep step 4 then step 2: the record's last line anchors the next count"
printf '%s\n%s\n' "$(ib p)" "$(ib q)" > "$SB/notes/inbox.txt"
: > "$SB/notes/runs.txt"
printf 'line\tA\ttrue\tx\t2026-01-01\n' > "$SB/rows5.tsv"
run_step 4 "s|<rows_file printed in step 1>|$SB/rows5.tsv|; s|<inbox_lines printed in step 2>|2|"
sed -i '1d' "$SB/notes/inbox.txt"
printf '%s\n%s\n' "$(ib r)" "$(ib s)" >> "$SB/notes/inbox.txt"
run_step 2
[[ "$OUT" == *"inbox_lines=3"* && "$OUT" == *"inbox_new=2"* ]] \
    && pass "(skill 4+2) one removed, two captured: two new" || fail "(skill 4+2) '$OUT' record='$(cat "$SB/notes/runs.txt")'"
printf '%s\n%s\n%s\n' "$(ib a)" "$(ib b)" "$(ib c)" > "$SB/notes/inbox.txt"

echo "TEST: sit-rep steps with an empty agent-workspace-root file fall back to the cwd"
: > "$HOMESB/.claude/agent-workspace-root"
blk="$(skill_step 2)"
RC=0; OUT="$(cd "$WS" && HOME="$HOMESB" bash -c "$blk" 2>&1)" || RC=$?
[[ "$OUT" == *"inbox_lines=3"* ]] && pass "(skill root) empty root file: WS_ROOT is the cwd" || fail "(skill root) '$OUT'"
printf '%s' "$WS" > "$HOMESB/.claude/agent-workspace-root"

echo "TEST: sit-rep step 3 with no GitHub remote does not call gh"
printf '#!/usr/bin/env bash\necho "[]"\n' > "$WS/.agent/scripts/worktree_list.sh"; chmod +x "$WS/.agent/scripts/worktree_list.sh"
reset_marks
run_step 3
[[ ! -e "$MARK/gh" && "$OUT" == *"no GitHub remote"* ]] && pass "(skill 3) empty repo: gh not called, said so" || fail "(skill 3) '$OUT' gh=$(cat "$MARK/gh" 2>/dev/null)"

echo "TEST: sit-rep step 3 gives each worktree with an issue its title and latest timeline entry"
cp "$SCRIPT_DIR/../progress_read.py" "$WS/.agent/scripts/"
mkdir -p "$SB/wt7/.agent/work-plans/issue-7" "$SB/wt8"
printf -- '---\nissue: 7\n---\n\n# Issue #7\n\n## Issue Review\n**Status**: complete\n**When**: 2026-10-01 10:00 -04:00\n**By**: t\n\n**Issue**: #7\n\n## Implementation\n**Status**: partial\n**When**: 2026-10-02 10:00 -04:00\n**By**: t\n\n**Issue**: #7\n' \
    > "$SB/wt7/.agent/work-plans/issue-7/progress.md"
cat > "$WS/.agent/scripts/worktree_list.sh" <<EOF
#!/usr/bin/env bash
echo '{"worktrees":[{"type":"main","issue":null,"branch":"main","path":"$WS"},{"type":"workspace","issue":7,"branch":"feature/issue-7","path":"$SB/wt7","repo":"workspace"},{"type":"workspace","issue":null,"skill":"research","branch":"skill/research-1","path":"$SB/wts"},{"type":"workspace","issue":8,"branch":"feature/issue-8","path":"$SB/wt8","repo":"workspace"}]}'
EOF
reset_marks
blk="$(skill_step 3 2)"
RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blk" 2>&1)" || RC=$?
[[ $RC -eq 0 && "$OUT" == $'workspace\tworkspace\tfeature/issue-7\tissue 7\tunknown (no GitHub remote)\timplementation partial\tpath unknown (steps not checked)\nworkspace\tworkspace\tfeature/issue-8\tissue 8\tunknown (no GitHub remote)\tno progress record yet\tpath unknown (steps not checked)' && ! -e "$MARK/gh" ]] \
    && pass "(skill 3) latest entry in state words; no row for main or a skill worktree; no remote, no gh" || fail "(skill 3) flight rc=$RC '$OUT'"

echo "TEST: sit-rep step 3 reads each worktree field by name: an empty branch or repo shifts nothing"
# Tab is IFS whitespace, so `read` with IFS=TAB folds empty fields: the
# issue number became the path. Detached (branch null), no repo, and an
# empty-string branch, each beside a worktree whose fields are all there.
cat > "$WS/.agent/scripts/worktree_list.sh" <<EOF
#!/usr/bin/env bash
echo '{"worktrees":[{"type":"workspace","issue":7,"branch":null,"path":"$SB/wt7"},{"type":"workspace","issue":8,"branch":"","path":"$SB/wt8","repo":""},{"type":"workspace","issue":7,"branch":"feature/issue-7","path":"$SB/wt7","repo":"workspace"}]}'
EOF
reset_marks
RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blk" 2>&1)" || RC=$?
[[ $RC -eq 0 && "$OUT" == $'workspace\tworkspace\t(no branch)\tissue 7\tunknown (no GitHub remote)\timplementation partial\tpath unknown (steps not checked)\nworkspace\tworkspace\t(no branch)\tissue 8\tunknown (no GitHub remote)\tno progress record yet\tpath unknown (steps not checked)\nworkspace\tworkspace\tfeature/issue-7\tissue 7\tunknown (no GitHub remote)\timplementation partial\tpath unknown (steps not checked)' ]] \
    && pass "(skill 3) no branch or no repo: the issue and path stay in place, read as (no branch)" || fail "(skill 3) empty fields rc=$RC '$OUT'"

echo "TEST: sit-rep step 3 reads a package worktree's repository and timeline through its manifest"
# Two ADR-0012 package worktrees: aggregate directories (not checkouts)
# holding two checkouts of different repositories each.
for p in pkg pkg2; do
    for r in a b; do
        git init -q "$SB/$p/src/pkg_$r"
        git -C "$SB/$p/src/pkg_$r" remote add origin "https://github.com/acme/pkg_$r.git"
    done
done
printf '# project=p issue=acme/pkg_b#12 layer=l1\n/o/a\tsrc/pkg_a\tfeature/issue-12\n/o/b\tsrc/pkg_b\tfeature/issue-12\n' > "$SB/pkg/.worktree-repos"
printf '# project=p issue=13 layer=l1\n/o/a\tsrc/pkg_a\tfeature/issue-13\n/o/b\tsrc/pkg_b\tfeature/issue-13\n' > "$SB/pkg2/.worktree-repos"
mkdir -p "$SB/pkg/src/pkg_b/.agent/work-plans/issue-12"
cp "$SB/wt7/.agent/work-plans/issue-7/progress.md" "$SB/pkg/src/pkg_b/.agent/work-plans/issue-12/progress.md"
cat > "$WS/.agent/scripts/worktree_list.sh" <<EOF
#!/usr/bin/env bash
echo '{"worktrees":[{"type":"project","issue":12,"branch":"feature/issue-12,feature/issue-12","path":"$SB/pkg","repo":"p"},{"type":"project","issue":13,"branch":"feature/issue-13,feature/issue-13","path":"$SB/pkg2","repo":"p"}]}'
EOF
reset_marks
echo "Package title" > "$SB/gh_state"
RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blk" 2>&1)" || RC=$?
[[ $RC -eq 0 && "$(sed -n 1p <<< "$OUT")" == $'project\tp\tfeature/issue-12,feature/issue-12\tissue 12\tPackage title\timplementation partial\tpath unknown (steps not checked)' ]] \
    && pass "(skill 3) package worktree: title from the header's repository, timeline found in a listed checkout" || fail "(skill 3) package rc=$RC '$OUT'"
[[ "$(cat "$MARK/gh" 2>/dev/null)" == "issue view 12 -R acme/pkg_b --json title --jq .title" ]] \
    && pass "(skill 3) package worktree: gh asked the header's repository only" || fail "(skill 3) package gh: $(cat "$MARK/gh" 2>/dev/null)"
[[ "$(sed -n 2p <<< "$OUT")" == $'project\tp\tfeature/issue-13,feature/issue-13\tissue 13\tunknown (its checkouts are not all in one GitHub repository)\tunknown (no repository to read it from)\tpath unknown (steps not checked)' ]] \
    && pass "(skill 3) package worktree with a bare issue number and two repositories: no guess" || fail "(skill 3) package bare '$OUT'"

echo "TEST: sit-rep step 3 reads a package worktree's title and timeline from the issue's repository only"
# pkg4: issue 14 of acme/pkg_b; acme/pkg_a, listed first, has its own
# issue 14 timeline. pkg5: issue 15 of acme/pkg_b; only acme/pkg_a has a
# timeline 15. pkg6: bare issue=16, the first checkout has no remote and
# the second is acme/pkg_b. pkg7: bare issue=17, both checkouts acme/pkg_b.
for p in pkg4 pkg5 pkg6 pkg7; do
    for r in a b; do git init -q "$SB/$p/src/pkg_$r"; done
done
for p in pkg4 pkg5; do
    git -C "$SB/$p/src/pkg_a" remote add origin "https://github.com/acme/pkg_a.git"
    git -C "$SB/$p/src/pkg_b" remote add origin "https://github.com/acme/pkg_b.git"
done
git -C "$SB/pkg6/src/pkg_b" remote add origin "https://github.com/acme/pkg_b.git"
git -C "$SB/pkg7/src/pkg_a" remote add origin "git@github.com:acme/pkg_b.git"
git -C "$SB/pkg7/src/pkg_b" remote add origin "https://github.com/acme/pkg_b.git"
printf '# project=p issue=acme/pkg_b#14 layer=l1\n/o/a\tsrc/pkg_a\tfeature/issue-14\n/o/b\tsrc/pkg_b\tfeature/issue-14\n' > "$SB/pkg4/.worktree-repos"
printf '# project=p issue=acme/pkg_b#15 layer=l1\n/o/a\tsrc/pkg_a\tfeature/issue-15\n/o/b\tsrc/pkg_b\tfeature/issue-15\n' > "$SB/pkg5/.worktree-repos"
printf '# project=p issue=16 layer=l1\n/o/a\tsrc/pkg_a\tfeature/issue-16\n/o/b\tsrc/pkg_b\tfeature/issue-16\n' > "$SB/pkg6/.worktree-repos"
printf '# project=p issue=17 layer=l1\n/o/a\tsrc/pkg_a\tfeature/issue-17\n/o/b\tsrc/pkg_b\tfeature/issue-17\n' > "$SB/pkg7/.worktree-repos"
reviewed_only=$'---\nissue: 14\n---\n\n# Issue #14\n\n## Issue Review\n**Status**: complete\n**When**: 2026-10-01 10:00 -04:00\n**By**: t\n\n**Issue**: #14\n'
mkdir -p "$SB/pkg4/src/pkg_a/.agent/work-plans/issue-14" "$SB/pkg4/src/pkg_b/.agent/work-plans/issue-14" "$SB/pkg5/src/pkg_a/.agent/work-plans/issue-15"
printf '%s' "$reviewed_only" > "$SB/pkg4/src/pkg_a/.agent/work-plans/issue-14/progress.md"
cp "$SB/wt7/.agent/work-plans/issue-7/progress.md" "$SB/pkg4/src/pkg_b/.agent/work-plans/issue-14/progress.md"
cp "$SB/wt7/.agent/work-plans/issue-7/progress.md" "$SB/pkg5/src/pkg_a/.agent/work-plans/issue-15/progress.md"
cat > "$WS/.agent/scripts/worktree_list.sh" <<EOF
#!/usr/bin/env bash
echo '{"worktrees":[{"type":"project","issue":14,"branch":"b14","path":"$SB/pkg4","repo":"p"},{"type":"project","issue":15,"branch":"b15","path":"$SB/pkg5","repo":"p"},{"type":"project","issue":16,"branch":"b16","path":"$SB/pkg6","repo":"p"},{"type":"project","issue":17,"branch":"b17","path":"$SB/pkg7","repo":"p"}]}'
EOF
reset_marks
echo "Package title" > "$SB/gh_state"
RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blk" 2>&1)" || RC=$?
[[ $RC -eq 0 && "$(sed -n 1p <<< "$OUT" | cut -f4,6)" == $'issue 14\timplementation partial' ]] \
    && pass "(skill 3) package worktree: the issue's repository's timeline, not another repository's issue of the same number" || fail "(skill 3) pkg4 '$OUT'"
[[ "$(sed -n 2p <<< "$OUT" | cut -f4,6)" == $'issue 15\tno progress record yet' ]] \
    && pass "(skill 3) package worktree: a timeline only in another repository's checkout is not read" || fail "(skill 3) pkg5 '$OUT'"
[[ "$(sed -n 3p <<< "$OUT" | cut -f4-6)" == $'issue 16\tunknown (its checkouts are not all in one GitHub repository)\tunknown (no repository to read it from)' ]] \
    && pass "(skill 3) package worktree, bare issue number: a checkout with no remote disagrees" || fail "(skill 3) pkg6 '$OUT'"
[[ "$(sed -n 4p <<< "$OUT" | cut -f4-5)" == $'issue 17\tPackage title' ]] \
    && pass "(skill 3) package worktree, bare issue number, one repository: its title" || fail "(skill 3) pkg7 '$OUT'"
[[ "$(cat "$MARK/gh" 2>/dev/null)" == $'issue view 14 -R acme/pkg_b --json title --jq .title\nissue view 15 -R acme/pkg_b --json title --jq .title\nissue view 17 -R acme/pkg_b --json title --jq .title' ]] \
    && pass "(skill 3) package worktrees: gh asked the issue's repository only, never for 16" || fail "(skill 3) pkg gh: $(cat "$MARK/gh" 2>/dev/null)"

echo "TEST: sit-rep step 3 names the latest timeline entry in state words"
cat > "$WS/.agent/scripts/worktree_list.sh" <<EOF
#!/usr/bin/env bash
echo '{"worktrees":[{"type":"workspace","issue":7,"branch":"feature/issue-7","path":"$SB/wt7","repo":"workspace"}]}'
EOF
state_of() {  # <entry heading> <status> [extra field lines]: step 3's state for a one-entry timeline
    printf -- '---\nissue: 7\n---\n\n# Issue #7\n\n## %s\n**Status**: %s\n**When**: 2026-10-01 10:00 -04:00\n**By**: t\n\n**Branch**: feature/issue-7 at `abc1234`\n%b\n' \
        "$1" "$2" "${3:-}" > "$SB/wt7/.agent/work-plans/issue-7/progress.md"
    (cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blk" 2>&1) | cut -f6
}
st_ok=true
while IFS='|' read -r heading status extra want; do
    got="$(state_of "$heading" "$status" "$extra")"
    [[ "$got" == "$want" ]] || { st_ok=false; echo "    $heading/$status/$extra: got '$got', want '$want'"; }
done <<'CASES'
Issue Review|complete||issue reviewed, not yet planned
Plan Authored|complete||plan written, not yet reviewed
Plan Review|complete||plan reviewed, not yet implemented
Checkpoint|complete|**After**: plan\n**Decision**: proceed|plan approved, implementing
Checkpoint|complete|**After**: plan\n**Decision**: revise|plan being revised
Checkpoint|complete|**After**: findings\n**Decision**: address|review findings being addressed
Checkpoint|complete|**After**: merge\n**Decision**: merge|approved to merge
Checkpoint|complete|**After**: phase-failed\n**Decision**: retry\n**Phase**: implement|a step failed; retrying it
Checkpoint|complete|**After**: phase-failed\n**Decision**: takeover\n**Phase**: implement|a step failed; the session is doing it by hand
Checkpoint|complete|**After**: merge-refused\n**Decision**: retriage|merge refused; reviews being triaged again
Checkpoint|complete|**After**: unexpected\n**Decision**: odd|checkpoint after unexpected: odd
Implementation|complete||implemented
Implementation|failed||implementation failed
Local Review (Pre-Push)|complete|\n### Findings\n- [ ] (must-fix) a\n- [x] (must-fix) b\n- [ ] (suggestion) c|code reviewed, 2 findings to address
Local Review (Pre-Push)|complete|\n### Findings\n- [x] (must-fix) a\n- [x] (suggestion) b — x (deferred: y)|code reviewed, nothing open
Local Review|complete||code reviewed, nothing open
Local Review (Pre-Push)|complete|**Verdict**: approved\n\n### Findings\n- [ ] No issues found. LGTM.|code reviewed, nothing open
Local Review|complete|\n### Findings\n- [ ] (must-fix) a|code reviewed, 1 finding to address
Integrated Review|complete|\n### Fix plan\n- [x] a\n- [x] b\n\n### False positives\n- c|reviews triaged, nothing open
Integrated Review|complete|\n### Fix plan\n- [ ] a\n- [x] b|reviews triaged, 1 finding to address
External Review (round 2)|complete|\n### Findings\n- [ ] a\n- [ ] b|reviews triaged, 2 findings to address
External Review (Round 5-6)|partial||review triage partial
Merge (report-only)|complete||merged although the merge check found problems
Merge (unreviewed)|complete||merged without review
CASES
$st_ok && pass "(skill 3) every timeline state reads as the mapping table says" || fail "(skill 3) state words (cases above)"

echo "TEST: sit-rep step 3 names the path each piece of work serves"
# Path 1: a Direction line names the issue in its own cells, or a check
# names the worktree's project. Path 2: a Serves line on the timeline.
# A deferral naming an issue does not make it Path 1, and a project
# worktree's bare number never matches a workspace issue.
mkdir -p "$SB/wt9/.agent/work-plans/issue-9" "$SB/wt8/.agent/work-plans/issue-8" "$SB/pq"
served=$'---\nissue: 8\n---\n\n# Issue #8\n\n## Issue Review\n**Status**: complete\n**When**: 2026-10-01 10:00 -04:00\n**By**: t\n\n**Issue**: #8\n\n### Scope Assessment\n\n**Serves**: Easy to use\n'
printf '%s' "$served" > "$SB/wt8/.agent/work-plans/issue-8/progress.md"
printf '%s' "${served//\*\*Serves\*\*: Easy to use/Nothing here}" > "$SB/wt9/.agent/work-plans/issue-9/progress.md"
cat > "$WS/.agent/scripts/worktree_list.sh" <<EOF
#!/usr/bin/env bash
echo '{"worktrees":[{"type":"workspace","issue":7,"branch":"feature/issue-7","path":"$SB/wt7","repo":"workspace"},{"type":"workspace","issue":8,"branch":"feature/issue-8","path":"$SB/wt8","repo":"workspace"},{"type":"workspace","issue":9,"branch":"feature/issue-9","path":"$SB/wt9","repo":"workspace"},{"type":"project","issue":3,"branch":"feature/issue-3","path":"$SB/pq","repo":"p"},{"type":"project","issue":7,"branch":"feature/issue-7","path":"$SB/pq","repo":"q"}]}'
EOF
printf 'line\tA line (#5, #7)\tfalse\tnone\t2026-10-15\nline\tThe project validates\ttrue\tscript adapter --project p validate\t2026-10-15\ndeferral\tLater (#9)\ttrue\tgh-issue 9 closed\t2026-10-15\n' > "$SB/rows3"
blk="$(skill_step 3 2)"
blkp="${blk//<rows_file printed in step 1>/$SB/rows3}"
reset_marks
RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blkp" 2>&1)" || RC=$?
[[ $RC -eq 0 && "$(cut -f1,2,4,7 <<< "$OUT")" == $'workspace\tworkspace\tissue 7\tPath 1\nworkspace\tworkspace\tissue 8\tPath 2\nworkspace\tworkspace\tissue 9\tno path\nproject\tp\tissue 3\tPath 1\nproject\tq\tissue 7\tno path' ]] \
    && pass "(skill 3) path: a Direction line's issue (second in a list too) or project is Path 1, a Serves line Path 2, else no path; deferrals and a project's bare number do not count" \
    || fail "(skill 3) path rc=$RC '$OUT'"
RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blk" 2>&1)" || RC=$?
[[ $RC -eq 0 && "$(cut -f7 <<< "$OUT" | sort -u)" == "path unknown (steps not checked)" ]] \
    && pass "(skill 3) path: with no rows from step 1 the path is unknown, never guessed" || fail "(skill 3) path no rows '$OUT'"

echo "TEST: sit-rep step 3 reads Path 2 from the newest complete Issue Review's Serves line only"
# A Serves line of "none" (review-issue's word for no goal) is no path; a
# newer Issue Review's Serves outranks an older one either way; a Serves
# line outside an Issue Review, or inside a fence, does not count.
ir() {  # <when> <serves line or empty> [status, default complete]
    printf '## Issue Review\n**Status**: %s\n**When**: %s\n**By**: t\n\n**Issue**: #1\n\n### Scope Assessment\n\n%s\n\n' "${3:-complete}" "$1" "$2"
}
hdr=$'---\nissue: 1\n---\n\n# Issue\n\n'
for n in 21 22 23 24 25 26 27 28; do mkdir -p "$SB/wt$n/.agent/work-plans/issue-$n"; done
{ printf '%s' "$hdr"; ir '2026-10-01 10:00 -04:00' '**Serves**: none'; } > "$SB/wt21/.agent/work-plans/issue-21/progress.md"
{ printf '%s' "$hdr"; ir '2026-10-01 10:00 -04:00' '**Serves**: Easy to use'; ir '2026-10-02 10:00 -04:00' '**Serves**: "none" — nothing in the README'; } > "$SB/wt22/.agent/work-plans/issue-22/progress.md"
{ printf '%s' "$hdr"; ir '2026-10-01 10:00 -04:00' '**Serves**: none'; ir '2026-10-02 10:00 -04:00' '**Serves**: Easy to use'; } > "$SB/wt23/.agent/work-plans/issue-23/progress.md"
{ printf '%s' "$hdr"; ir '2026-10-01 10:00 -04:00' ''; printf '## Plan Authored\n**Status**: complete\n\n**Serves**: Easy to use\n\n'; } > "$SB/wt24/.agent/work-plans/issue-24/progress.md"
{ printf '%s' "$hdr"; ir '2026-10-01 10:00 -04:00' $'```\n## Issue Review\n**Serves**: Easy to use\n```'; } > "$SB/wt25/.agent/work-plans/issue-25/progress.md"
{ printf '%s' "$hdr"; ir '2026-10-01 10:00 -04:00' '**Serves**: Nonetheless a goal'; } > "$SB/wt26/.agent/work-plans/issue-26/progress.md"
{ printf '%s' "$hdr"; ir '2026-10-01 10:00 -04:00' '**Serves**: Easy to use'; ir '2026-10-02 10:00 -04:00' '' partial; ir '2026-10-03 10:00 -04:00' '' failed; } > "$SB/wt27/.agent/work-plans/issue-27/progress.md"
{ printf '%s' "$hdr"; ir '2026-10-01 10:00 -04:00' '**Serves**: none'; ir '2026-10-02 10:00 -04:00' '**Serves**: Easy to use' partial; } > "$SB/wt28/.agent/work-plans/issue-28/progress.md"
{ printf '{"worktrees":['
  for n in 21 22 23 24 25 26 27 28; do
      [ "$n" = 21 ] || printf ','
      printf '{"type":"workspace","issue":%s,"branch":"feature/issue-%s","path":"%s","repo":"workspace"}' "$n" "$n" "$SB/wt$n"
  done
  printf ']}\n'; } > "$SB/wl-serves.json"
printf '#!/usr/bin/env bash\ncat %q\n' "$SB/wl-serves.json" > "$WS/.agent/scripts/worktree_list.sh"
reset_marks
RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blkp" 2>&1)" || RC=$?
[[ $RC -eq 0 && "$(cut -f4,7 <<< "$OUT")" == $'issue 21\tno path\nissue 22\tno path\nissue 23\tPath 2\nissue 24\tno path\nissue 25\tno path\nissue 26\tPath 2\nissue 27\tPath 2\nissue 28\tno path' ]] \
    && pass "(skill 3) path: only the newest complete Issue Review's Serves counts (a partial or failed one, with or without Serves, changes nothing); \"none\" is no path; Serves elsewhere or fenced does not count" \
    || fail "(skill 3) path from Serves rc=$RC '$OUT'"
rm -f "$SB/wl-serves.json"

echo "TEST: sit-rep step 3 reads the roadmap's Paths paragraphs, as written"
cp "$WS/docs/roadmap.md" "$SB/roadmap3.saved"
printf '%s\n' '# R' '' '**Path 9, Not this.** Outside the section.' '' '## Direction' '' 'Intro.' '' \
    '**Path 1, Alpha one.** First sentence, with `code`. Second' 'sentence.' '' \
    '**Path 2, Beta.** Only one sentence' '' '## Next' > "$WS/docs/roadmap.md"
RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$(skill_step 3 3)" 2>&1)" || RC=$?
[[ $RC -eq 0 && "$OUT" == $'path\tPath 1\tAlpha one\tFirst sentence, with `code`.\npath\tPath 2\tBeta\tOnly one sentence' ]] \
    && pass "(skill 3) paths: number, name and first sentence of each Path paragraph in the Direction section only" || fail "(skill 3) paths rc=$RC '$OUT'"
printf '## Direction\n\nNo paths.\n' > "$WS/docs/roadmap.md"
RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$(skill_step 3 3)" 2>&1)" || RC=$?
[[ $RC -eq 0 && "$OUT" == "paths=none"* ]] && pass "(skill 3) paths: none in the roadmap is said, not guessed" || fail "(skill 3) no paths '$OUT'"
mv "$SB/roadmap3.saved" "$WS/docs/roadmap.md"

echo "TEST: sit-rep step 8 template: lead words, one item per line, blank lines between sections"
tpl="$(awk '/^### 8\. / { s = 1; next } s && /^### / { exit }
    s && !b && /^```markdown/ { b = 1; next } b && /^```/ { exit } b { print }' "$SKILL")"
if [[ -z "$tpl" ]]; then
    fail "(skill 8) no markdown template found in step 8"
else
    lead_ok=true
    for w in "Done: " "Not yet: " "Next: " "Running: "; do
        grep -q "^\(- \)\?$w" <<< "$tpl" || { lead_ok=false; echo "    no line led by '$w'"; }
    done
    $lead_ok && pass "(skill 8) lines lead with Done:, Not yet:, Next: and Running:" || fail "(skill 8) lead words"
    joined="$(awk '/^ *- / { item = 1 } /^[[:space:]]*$/ || /^\*\*/ { item = 0 } item' <<< "$tpl" | grep -F '; ' || true)"
    [[ -z "$joined" ]] && pass "(skill 8) no list item joins items with '; '" || fail "(skill 8) joined list items: $joined"
    # A heading's paragraph may wrap; a bullet before the next blank line
    # means the heading and its list are not set apart.
    spacing="$(awk '/^\*\*[A-Z][A-Za-z ]*\*\*:/ { if (prev !~ /^[[:space:]]*$/) print "no blank line before: " $0; inhdr = 1; hdr = $0; prev = $0; next }
        /^[[:space:]]*$/ { inhdr = 0 }
        inhdr && /^- / { print "no blank line after: " hdr; inhdr = 0 }
        { prev = $0 }' <<< "$tpl")"
    [[ -z "$spacing" ]] && pass "(skill 8) a blank line before every section heading and after it" || fail "(skill 8) spacing: $spacing"
fi
grep -qF 'By default it is the focus: Path 1, Path' "$SKILL" && grep -qF '`no path`' "$SKILL" \
    && pass "(skill 8) the report marks each item's path and asks for the focus" || fail "(skill 8) path words or focus question missing"

echo "TEST: sit-rep step 5 takes issue numbers from the line's own cells only, text kept as written"
cat > "$WS/.agent/scripts/worktree_list.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"worktrees":[{"type":"main","issue":null,"branch":"main","path":"/m"},{"type":"workspace","issue":7,"branch":"feature/issue-7","path":"/w7"},{"type":"project","issue":7,"branch":"feature/issue-7","path":"/p7","repo":"p"},{"type":"workspace","issue":8,"branch":"feature/issue-8","path":"/w8"}]}'
EOF
chmod +x "$WS/.agent/scripts/worktree_list.sh"
mkdir -p "$WS/docs/decisions"
printf '# ADR-0042: A synthetic decision\n\nText.\n' > "$WS/docs/decisions/0042-a-synthetic-decision.md"
step5() {  # <item> <check>: step 5's block with both placeholders filled
    local blk; blk="$(skill_step 5)"
    blk="$(ITEM="$1" CHECK="$2" python3 -c '
import os, sys
b = sys.stdin.read()
b = b.replace("<item of the first line row whose result is not true>", os.environ["ITEM"])
print(b.replace("<check of that row, or nothing>", os.environ["CHECK"]))' <<< "$blk")"
    RC=0
    OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blk" 2>&1)" || RC=$?
}
reset_marks
step5 "It's \$HOME and \`x\` (#7), not #8" '`file-exists a` ; `gh-issue 9 closed`'
[[ $RC -eq 0 && "$OUT" == *"issues_named=7 9"* && "$OUT" != *"issue	8"* ]] \
    && pass "(skill 5) (#N) in the item and gh-issue N in the check; a bare #8 is not taken" || fail "(skill 5) numbers rc=$RC '$OUT'"
[[ "$(grep -c '^branch' <<< "$OUT")" -eq 1 && "$OUT" == *$'branch\tfeature/issue-7\t/w7'* ]] \
    && pass "(skill 5) only the workspace worktree of issue 7 matches" || fail "(skill 5) branches '$OUT'"
[[ ! -e "$MARK/gh" && "$OUT" == *$'issue\t7\tunknown (lookup failed)'* ]] \
    && pass "(skill 5) no GitHub remote: gh not called, title unknown, said so" || fail "(skill 5) gh=$(cat "$MARK/gh" 2>/dev/null) '$OUT'"
step5 'No number here' '`gh-issue acme/other#5 closed`'
[[ "$OUT" == *"issues_named=none"* && "$OUT" != *branch* ]] \
    && pass "(skill 5) another repository's gh-issue names no issue here" || fail "(skill 5) other repo '$OUT'"
step5 'Two at once (#7, #9), then (#11, see below) and #8' ''
[[ "$OUT" == *"issues_named=7 9 11"* && "$OUT" != *"issue	8"* ]] \
    && pass "(skill 5) every number of a list (#N, #M) is taken, and (#N, text) still is" || fail "(skill 5) list '$OUT'"
echo "TEST: sit-rep step 5 reads the acceptance case's first sentence, as written, with a simple command"
case5() {  # <roadmap text> [<lines for the TEXT markers>]: step 5's second block against it; sets OUT, RC
    cp "$WS/docs/roadmap.md" "$SB/roadmap.saved"
    printf '%b' "$1" > "$WS/docs/roadmap.md"
    local blk; blk="$(skill_step 5 2)"
    [ -z "${2:-}" ] || blk="$(T="$2" python3 -c '
import os, sys
print(sys.stdin.read().replace("<the Direction lines and deferrals the report prints, one per line>", os.environ["T"]))' <<< "$blk")"
    RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blk" 2>&1)" || RC=$?
    mv "$SB/roadmap.saved" "$WS/docs/roadmap.md"
}
case5 '# R\n\n**Acceptance case.** Not this one.\n\n## Direction\n\nIntro.\n\n**Acceptance case.** A synthetic `run` started\nfrom a root (see [x](design.md#a-b)) ends. Its target is\n`demo`.\n\nAfter.\n\n## Next\n'
[[ $RC -eq 0 && "$OUT" == $'acceptance_first=A synthetic `run` started from a root (see x) ends.\nacceptance_rest=Its target is `demo`.' ]] \
    && pass "(skill 5) first sentence of the Direction section's paragraph, joined, not split at a dot inside a link" || fail "(skill 5) case rc=$RC '$OUT'"
case5 '## Direction\n\n**Acceptance case.** One sentence only.\n'
[[ "$OUT" == $'acceptance_first=One sentence only.\nacceptance_rest=' ]] \
    && pass "(skill 5) a one-sentence paragraph has no rest" || fail "(skill 5) one sentence '$OUT'"
case5 '## Direction\n\nNo case here.\n\n## Other\n\n**Acceptance case.** Elsewhere.\n'
[[ $RC -eq 0 && "$OUT" == $'acceptance_first=\nacceptance_rest=' ]] \
    && pass "(skill 5) no paragraph in the Direction section: empty, so the line is left out" || fail "(skill 5) absent rc=$RC '$OUT'"
echo "TEST: sit-rep step 5 prints roadmap text with link text and ADR titles, never raw links or bare numbers"
case5 '## Direction\n\n**Acceptance case.** A project is used ([Roots](design.md#roots)). Until then,\nADR-0042 stays put\n([Sessions and roots](design.md#sessions-and-roots)); ADR-0042 (Its own words) is not doubled.\n' \
    $'ADR-0042 is promoted (#9)\nSee [the guide](docs/guide.md) and ADR-0043\n\nA plain line'
[[ $RC -eq 0 && "$OUT" == $'acceptance_first=A project is used (Roots).\nacceptance_rest=Until then, ADR-0042 (A synthetic decision) stays put (Sessions and roots); ADR-0042 (Its own words) is not doubled.\ntext=ADR-0042 (A synthetic decision) is promoted (#9)\ntext=See the guide and ADR-0043\ntext=A plain line' ]] \
    && pass "(skill 5) links print as their text; an ADR number gets its file's title unless a parenthesis follows (not an issue's); no file, as written" \
    || fail "(skill 5) render rc=$RC '$OUT'"
case5 '## Direction\n\n**Acceptance case.** Short.\n'
[[ $RC -eq 0 && "$OUT" == $'acceptance_first=Short.\nacceptance_rest=' ]] && pass "(skill 5) the TEXT placeholder left in place prints no text lines" || fail "(skill 5) placeholder '$OUT'"

# A workspace with a GitHub remote, for the steps that call gh and git-bug.
W5="$SB/ws5"
mkdir -p "$W5/.agent/scripts" "$W5/docs"
git init -q "$W5"
git -C "$W5" remote add origin https://github.com/acme/widgets.git
cp "$SCRIPT_DIR/../_issue_helpers.sh" "$W5/.agent/scripts/"
cp "$WS/.agent/scripts/worktree_list.sh" "$W5/.agent/scripts/"
printf "## Direction\n" > "$W5/docs/roadmap.md"
printf '%s' "$W5" > "$HOMESB/.claude/agent-workspace-root"

echo "TEST: sit-rep step 5 with gh failing reads the git-bug cache only, never pulling"
# git runs `git bug ...` as git-bug from PATH: a stub that records its argv.
cat > "$SB/bin/git-bug" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$MARK/git-bug"
case "\$*" in
    "bug -m github-url=https://github.com/acme/widgets/issues/7 --format json") echo '[{"human_id":"abc1234"}]' ;;
    "bug show abc1234 --format json") echo '{"title":"Cached title","status":"open","comments":[]}' ;;
    "bridge") echo "github" ;;
    *) echo "[]" ;;
esac
EOF
chmod +x "$SB/bin/git-bug"
reset_marks
echo 1 > "$RCD/gh"
step5 'A line (#7) and (#8)' ''
[[ "$OUT" == *$'issue\t7\tCached title (offline: git-bug cache)'* && "$OUT" == *$'issue\t8\tunknown (lookup failed)'* ]] \
    && pass "(skill 5) gh failing: the title comes from the git-bug cache, or is unknown" || fail "(skill 5) cache '$OUT'"
! grep -q "bridge" "$MARK/git-bug" 2>/dev/null && grep -q "^bug -m" "$MARK/git-bug" 2>/dev/null \
    && pass "(skill 5) a cache miss does not pull from GitHub (no git bug bridge call)" || fail "(skill 5) git-bug calls: $(cat "$MARK/git-bug" 2>/dev/null)"

echo "TEST: sit-rep step 3 with gh failing reads the git-bug cache only, never pulling"
for n in 7 8; do
    git init -q "$SB/wt3gb$n"
    git -C "$SB/wt3gb$n" remote add origin https://github.com/acme/widgets.git
done
cp "$W5/.agent/scripts/worktree_list.sh" "$SB/wl5.saved"
cat > "$W5/.agent/scripts/worktree_list.sh" <<EOF
#!/usr/bin/env bash
echo '{"worktrees":[{"type":"workspace","issue":7,"branch":"feature/issue-7","path":"$SB/wt3gb7","repo":"workspace"},{"type":"workspace","issue":8,"branch":"feature/issue-8","path":"$SB/wt3gb8","repo":"workspace"}]}'
EOF
reset_marks
echo 1 > "$RCD/gh"
blk3="$(skill_step 3 2)"
RC=0; OUT="$(cd "$SB/elsewhere" && HOME="$HOMESB" bash -c "$blk3" 2>&1)" || RC=$?
[[ $RC -eq 0 && "$(cut -f4,5 <<< "$OUT")" == $'issue 7\tCached title (offline: git-bug cache)\nissue 8\tunknown (lookup failed)' ]] \
    && pass "(skill 3) gh failing: the title comes from the git-bug cache, or is unknown" || fail "(skill 3) cache rc=$RC '$OUT'"
! grep -q "bridge" "$MARK/git-bug" 2>/dev/null && grep -q "^bug -m github-url=https://github.com/acme/widgets/issues/8" "$MARK/git-bug" 2>/dev/null \
    && pass "(skill 3) a cache miss does not pull from GitHub (no git bug bridge call)" || fail "(skill 3) git-bug calls: $(cat "$MARK/git-bug" 2>/dev/null)"
mv "$SB/wl5.saved" "$W5/.agent/scripts/worktree_list.sh"
rm -f "$SB/bin/git-bug"

echo "TEST: sit-rep step 5 matches open pull requests by branch or closing reference, whatever the references hold"
# A gh that applies its --jq filter with jq, as gh does, to a fixed list.
mv "$SB/bin/gh" "$SB/gh.saved"
cat > "$SB/bin/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$MARK/gh"
case "\$1 \$2" in
    "issue view") echo "Live title" ;;
    "pr list")
        while [ \$# -gt 0 ]; do [ "\$1" = "--jq" ] && { jq -r "\$2" "$SB/prs.json"; exit; }; shift; done
        cat "$SB/prs.json" ;;
esac
EOF
chmod +x "$SB/bin/gh"
cat > "$SB/prs.json" <<'EOF'
[{"number":20,"title":"Null references, other branch","headRefName":"w","isCrossRepository":false,"isDraft":false,"closingIssuesReferences":null},
 {"number":21,"title":"Branch match","headRefName":"feature/issue-7","isCrossRepository":false,"isDraft":true,"closingIssuesReferences":null},
 {"number":22,"title":"Closes it","headRefName":"other","isCrossRepository":false,"isDraft":false,"closingIssuesReferences":[{"number":7,"repository":{"owner":{"login":"acme"},"name":"widgets"}}]},
 {"number":23,"title":"Closes another repository's 7","headRefName":"x","isCrossRepository":false,"isDraft":false,"closingIssuesReferences":[{"number":7,"repository":{"owner":{"login":"acme"},"name":"other"}}]},
 {"number":24,"title":"Reference without repository","headRefName":"y","isCrossRepository":false,"isDraft":false,"closingIssuesReferences":[{"number":7}]},
 {"number":25,"title":"No references","headRefName":"z","isCrossRepository":false,"isDraft":false,"closingIssuesReferences":[]},
 {"number":26,"title":"From a fork","headRefName":"feature/issue-7","isCrossRepository":true,"isDraft":false,"closingIssuesReferences":[]}]
EOF
reset_marks
step5 'A line (#7)' ''
[[ $RC -eq 0 && "$(grep '^pull_request' <<< "$OUT")" == $'pull_request\t21\tBranch match\tdraft\npull_request\t22\tCloses it\tready' ]] \
    && pass "(skill 5) pull requests: null references do not stop the lookup; branch match, closing reference here; not another repository's, a bare reference, or a fork" \
    || fail "(skill 5) pull requests rc=$RC '$OUT'"
[[ "$OUT" == *$'issue\t7\tLive title'* ]] && pass "(skill 5) gh up: the live title" || fail "(skill 5) live title '$OUT'"
mv "$SB/gh.saved" "$SB/bin/gh"
printf '%s' "$WS" > "$HOMESB/.claude/agent-workspace-root"

echo "TEST: sit-rep step 6 reads the problems from main, without merges or work-plan-only commits"
W6="$SB/ws6"
mkdir -p "$W6/.agent/scripts" "$W6/.agent/knowledge" "$W6/docs" "$W6/src" "$W6/.agent/work-plans/issue-1"
cat > "$W6/.agent/scripts/check_design_anchors.sh" <<EOF
#!/usr/bin/env bash
echo "anchor: docs/x.md cites #gone"
exit "\$(cat "$RCD/anchors" 2>/dev/null || echo 0)"
EOF
chmod +x "$W6/.agent/scripts/check_design_anchors.sh"
ago() { python3 -c 'import datetime, sys; print(datetime.date.today() - datetime.timedelta(days=int(sys.argv[1])))' "$1"; }
D100="$(ago 100)"; D40="$(ago 40)"; D10="$(ago 10)"
c6() {  # <date> <message>: commit everything staged, dated <date>
    GIT_AUTHOR_DATE="$1 12:00:00" GIT_COMMITTER_DATE="$1 12:00:00" \
        git -C "$W6" -c user.name=t -c user.email=t@t commit -q -m "$2"
}
git init -q -b main "$W6"
# Row 2 has an escaped pipe in a cell (\|), which is not a column break;
# the separator row has spaces and a colon, which a separator may.
printf '## Decision register\n\n| ADR | Decision | Re-examined |\n| --- | :-- | --- |\n| 1 | a | yes %s |\n| 2 | b `x\\|y` | yes %s |\n| 3 | c | not yet |\n\n## Change log\n\n| x | yes 2099-01-01 |\n' "$D100" "$D40" > "$W6/docs/design.md"
printf '<!-- Last full refresh: %s (partial) -->\n\n### A\n**Added**: %s | **Last verified**: %s | **Sources**: x\n\n### B\n**Added**: %s | **Sources**: y\n' "$D100" "$D100" "$D10" "$D100" > "$W6/.agent/knowledge/research_digest.md"
git -C "$W6" add -A && c6 "$D40" "design and digest"
echo plan > "$W6/.agent/work-plans/issue-1/plan.md"; git -C "$W6" add -A && c6 "$D10" "work plan only"
echo doc > "$W6/docs/other.md"; git -C "$W6" add -A && c6 "$D10" "docs change"
git -C "$W6" checkout -q -b side
echo x > "$W6/src/x"; git -C "$W6" add -A && c6 "$D10" "side change"
git -C "$W6" checkout -q main
GIT_AUTHOR_DATE="$D10 13:00:00" GIT_COMMITTER_DATE="$D10 13:00:00" \
    git -C "$W6" -c user.name=t -c user.email=t@t merge -q --no-ff -m "merge side" side
git -C "$W6" checkout -q -b feature   # a worktree session's branch: not read
printf 'not on main\n' > "$W6/docs/design.md"
printf '%s' "$W6" > "$HOMESB/.claude/agent-workspace-root"
reset_marks
run_step 6
[[ $RC -eq 0 && "$OUT" == *"audit_adrs=3 not_yet_reexamined=1"* \
    && "$OUT" == *"newest_adr_reexamination=$D40 days=40 commits_since=2"* ]] \
    && pass "(skill 6) audit: newest Re-examined date on main, commits since without merge or work-plan-only commits" || fail "(skill 6) audit rc=$RC '$OUT'"
[[ "$OUT" == *"last_full_refresh=$D100"* && "$OUT" == *"digest_entries=2 past_30_days=1 past_90_days=1 oldest_days=100 undated=0"* ]] \
    && pass "(skill 6) research: Last verified, else Added, against 30 and 90 days" || fail "(skill 6) research '$OUT'"
[[ "$OUT" == *"design_doc_changed=$D40 days=40 commits_since_touching_agent_claude_docs=1"* ]] \
    && pass "(skill 6) documentation: commits since design.md changed, under .agent/.claude/docs only" || fail "(skill 6) docs '$OUT'"
[[ "$OUT" != *design_anchors* && "$OUT" == *"session_type=unknown"* ]] \
    && pass "(skill 6) a passing anchor check prints nothing; no session root is unknown" || fail "(skill 6) anchors pass '$OUT'"
echo 1 > "$RCD/anchors"
run_step 6
[[ "$OUT" == *$'design_anchors=failed\nanchor: docs/x.md cites #gone'* ]] \
    && pass "(skill 6) a failing anchor check prints with its output" || fail "(skill 6) anchors fail '$OUT'"
[[ "$OUT" == *"main_behind_origin=unknown (no origin/main)"* ]] \
    && pass "(skill 6) no origin/main: how far main lags is unknown" || fail "(skill 6) no origin '$OUT'"
ahead="$(git -C "$W6" -c user.name=t -c user.email=t@t commit-tree 'main^{tree}' -p main -m ahead)"
git -C "$W6" update-ref refs/remotes/origin/main "$ahead"
run_step 6
[[ "$OUT" == *"main_behind_origin=1"* ]] \
    && pass "(skill 6) origin/main one commit ahead: main is 1 behind, nothing fetched" || fail "(skill 6) behind '$OUT'"
printf '%s' "$WS" > "$HOMESB/.claude/agent-workspace-root"
run_step 6
[[ "$OUT" == *"audit=cannot tell"* && "$OUT" == *"research=cannot tell"* && "$OUT" == *"design_doc=cannot tell"* ]] \
    && pass "(skill 6) no git history: every fact says cannot tell" || fail "(skill 6) no repo '$OUT'"

echo "TEST: usage"
RC=0; bash "$SITREP" --bogus >/dev/null 2>&1 || RC=$?
[[ $RC -eq 2 ]] && pass "(usage) unknown option exits 2" || fail "(usage) rc=$RC"

echo ""
echo "test_sitrep_checks: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
