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
    [[ -n "$slow" ]] && kill -0 "$slow" 2>/dev/null && alive=yes
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
# them (first ```bash block under "### <n>.") against a sandbox workspace.
SKILL="$SCRIPT_DIR/../../../.claude/skills/sitrep/SKILL.md"
skill_step() {
    awk -v n="$1" '
        $0 ~ "^### " n "\\. " { s = 1; next }
        s && /^### / { exit }
        s && !b && /^```bash/ { b = 1; next }
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
alive=no; [[ -n "$slow" ]] && kill -0 "$slow" 2>/dev/null && alive=yes
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
[[ "$(cut -f2- <<< "$last")" == $'workspace\tlines 2/2 deferrals 0/1\tinbox 2' && ! -e "$MARK/gh" ]] \
    && pass "(skill 4) record from the saved rows and step 2's count, nothing re-run" || fail "(skill 4) last='$last' out='$OUT'"
[[ -n "$rows_file" && ! -e "$rows_file" ]] && pass "(skill 4) rows file removed" || fail "(skill 4) rows file left: $rows_file"
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

echo "TEST: sit-rep step 2 counts new inbox lines from the recorded count"
printf '2026-10-12 10:00 -0400\tworkspace\tlines 1/2 deferrals 0/1\tinbox 2\n' > "$SB/notes/runs.txt"
run_step 2
[[ "$OUT" == *"inbox_lines=3"* && "$OUT" == *"inbox_new=1"* ]] \
    && pass "(skill 2) same-minute capture counted new" || fail "(skill 2) '$OUT'"
printf '2026-10-12 10:00 -0400\tworkspace\tlines 1/2 deferrals 0/1\tinbox 5\n' > "$SB/notes/runs.txt"
run_step 2
[[ "$OUT" == *"inbox_new=unknown"* ]] && pass "(skill 2) fewer lines than recorded: unknown" || fail "(skill 2) shrink '$OUT'"

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

echo "TEST: usage"
RC=0; bash "$SITREP" --bogus >/dev/null 2>&1 || RC=$?
[[ $RC -eq 2 ]] && pass "(usage) unknown option exits 2" || fail "(usage) rc=$RC"

echo ""
echo "test_sitrep_checks: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
