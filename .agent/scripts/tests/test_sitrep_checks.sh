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

echo "TEST: ### subheadings stay in the section; CRLF roadmap"
run_rm $'## Direction\n\n### Lines\n\n| Line | Check |\n|---|---|\n| Under sub | file-exists docs/notes.md |\n\n## Next\n'
[[ "$(res 'Under sub')" == true ]] && pass "(heading) ### does not end the section" || fail "(heading) '$OUT'"
run_rm $'## Direction\r\n\r\n| Line | Check |\r\n|---|---|\r\n| Crlf | file-contains docs/notes.md hello |\r\n\r\n## Next\r\n'
[[ "$(res Crlf)" == true ]] && pass "(crlf) CRLF roadmap read" || fail "(crlf) '$OUT'"

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

echo "TEST: sit-rep step 4 records the summary of the same rows and the inbox count"
printf '2026-10-12 10:00 -0400\tworkspace\t-\ta\n2026-10-12 10:00 -0400\tworkspace\t-\tb\n2026-10-12 10:00 -0400\tworkspace\t-\tc\n' > "$SB/notes/inbox.txt"
reset_marks
echo OPEN > "$SB/gh_state"   # a re-run would now give lines 1/2
run_step 4 "s|<rows_file printed in step 1>|$rows_file|"
last="$(tail -n1 "$SB/notes/runs.txt" 2>/dev/null)"
[[ "$(cut -f2- <<< "$last")" == $'workspace\tlines 2/2 deferrals 0/1\tinbox 3' && ! -e "$MARK/gh" ]] \
    && pass "(skill 4) record from the saved rows, no check re-run" || fail "(skill 4) last='$last' out='$OUT'"
[[ -n "$rows_file" && ! -e "$rows_file" ]] && pass "(skill 4) rows file removed" || fail "(skill 4) rows file left: $rows_file"
printf 'inbox=%s\nrun_record=%s\n' "$SB/notes/inbox.txt" "$SB/nodir/runs.txt" > "$WS/.agent/settings.local"
printf 'line\tA\ttrue\tx\t2026-01-01\n' > "$SB/rows3.tsv"
run_step 4 "s|<rows_file printed in step 1>|$SB/rows3.tsv|"
[[ $RC -eq 0 && ! -e "$SB/nodir" && "$OUT" == *"not written"* ]] \
    && pass "(skill 4) missing record directory: not written, said so" || fail "(skill 4) nodir rc=$RC '$OUT'"
printf 'inbox=%s\nrun_record=%s\n' "$SB/notes/inbox.txt" "$SB/notes/runs.txt" > "$WS/.agent/settings.local"

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
