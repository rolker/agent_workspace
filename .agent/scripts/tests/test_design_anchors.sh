#!/usr/bin/env bash
# Tests for .agent/scripts/check_design_anchors.sh (issue #335, plan Wire-in 6)
#
# The checker fails a commit when a `docs/design.md#<anchor>` citation or an
# in-file `](#<slug>)` link does not resolve to a heading, and, once the
# Decision register exists, when the register or the in-file links are too
# thin to be trusted. Every case builds a small tree under a private temp
# dir and points the checker at it; the suite reads no real docs, so it needs
# no ROOT_READERS entry in test_script_tests_hook_scope.sh (the checker is
# found with a single `..` from this directory).
#
# Cases follow the plan's fixtures (a) to (g):
#   (a) broken citation fails and is named
#   (b) valid citations pass, `docs/design.md#glossary` among them
#   (c) `#<section>` placeholder, `(#295)` and `[x](#12)` are ignored
#   (d) `#How-it-works` is a malformed anchor
#   (e) guards are off while the register heading is absent
#   (f) guards are live once the register heading exists
#   (g) a new ADR file without a register row fails only once the register
#       exists
#
# Run: bash .agent/scripts/tests/test_design_anchors.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="${SCRIPT_DIR}/../check_design_anchors.sh"

PASS=0
FAIL=0

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# new_root <name> -- an empty fixture root with docs/ in it; prints the path.
new_root() {
    local root="$SANDBOX/$1"
    mkdir -p "$root/docs"
    echo "$root"
}

# add_adrs <root> <count> -- <count> dummy ADR files.
add_adrs() {
    local root="$1" n="$2" i
    mkdir -p "$root/docs/decisions"
    for ((i = 1; i <= n; i++)); do
        : > "$root/docs/decisions/000${i}-adr.md"
    done
}

# run_checker <root> -- sets RC and OUT (stdout and stderr together).
run_checker() {
    RC=0
    OUT="$(bash "$CHECKER" "$1" 2>&1)" || RC=$?
}

expect() {  # <label> <want-rc> [<grep -F text that must appear in OUT>...]
    local label="$1" want="$2" text
    shift 2
    if [[ "$RC" -ne "$want" ]]; then
        fail "$label: exit $RC, wanted $want"
        echo "    output: ${OUT//$'\n'/$'\n            '}"
        return
    fi
    for text in "$@"; do
        if ! grep -qF -- "$text" <<<"$OUT"; then
            fail "$label: output lacks '$text'"
            echo "    output: ${OUT//$'\n'/$'\n            '}"
            return
        fi
    done
    pass "$label"
}

# A design.md body with a few headings, no register and no in-file links.
plain_design() {  # <file>
    cat > "$1" <<'DOC'
# The design

## How it works

Text.

## Glossary

Terms.
DOC
}

# A design.md with a register of <rows> anchored rows (and the links that
# implies), then a closing Glossary section.
register_design() {  # <file> <rows>
    local file="$1" rows="$2" i
    {
        echo "# The design"
        echo
        echo "## How it works"
        echo
        echo "## Decision register"
        echo
        echo "| ADR | Standing | Section |"
        echo "|---|---|---|"
        for ((i = 1; i <= rows; i++)); do
            echo "| 000$i | in force | [How it works](#how-it-works) |"
        done
        echo
        echo "## Glossary"
    } > "$file"
}

# ---------------------------------------------------------------- (a)
echo "== (a) broken citation =="
R="$(new_root a)"
plain_design "$R/docs/design.md"
printf 'See docs/design.md#no-such-section for the rules.\n' > "$R/README.md"
run_checker "$R"
expect "a: citation of a missing heading exits 1 and is named with file:line" 1 \
    "README.md:1:" "no-such-section"

# in-file link to a missing heading
R="$(new_root a2)"
plain_design "$R/docs/design.md"
printf '\nSee [x](#gone).\n' >> "$R/docs/design.md"
run_checker "$R"
expect "a: in-file link to a missing heading exits 1, line number in the message" 1 \
    "docs/design.md:11:" "gone"

# ---------------------------------------------------------------- (b)
echo "== (b) valid citations =="
R="$(new_root b)"
plain_design "$R/docs/design.md"
printf '\nBack to [how it works](#how-it-works).\n' >> "$R/docs/design.md"
mkdir -p "$R/.claude/skills/some-skill" "$R/.agent/knowledge"
printf 'Read docs/design.md#glossary first.\n' > "$R/README.md"
# shellcheck disable=SC2016  # a literal $WS_ROOT prefix is the point
printf 'See $WS_ROOT/docs/design.md#how-it-works\n' > "$R/.claude/skills/some-skill/SKILL.md"
printf 'Cites docs/design.md#glossary and docs/design.md#how-it-works.\n' > "$R/.agent/knowledge/note.md"
printf 'docs/design.md#glossary\n' > "$R/docs/roadmap.md"
mkdir -p "$R/.agent"
printf 'docs/design.md#how-it-works\n' > "$R/.agent/AGENT_ONBOARDING.md"
run_checker "$R"
expect "b: valid citations from every scoped file and a valid in-file link pass" 0

# scope: a file outside the scope is not read
R="$(new_root b2)"
plain_design "$R/docs/design.md"
printf 'docs/design.md#no-such-section\n' > "$R/CHANGELOG.md"
run_checker "$R"
expect "b: a citation in a file outside the scope is not checked" 0

# slug rules
R="$(new_root b3)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## Rules (and why)

## Sessions & roots

## Rules (and why)

```text
## Not a heading
```

## `Code` heading
DOC
printf 'docs/design.md#rules-and-why docs/design.md#rules-and-why-1 docs/design.md#sessions--roots docs/design.md#code-heading\n' > "$R/README.md"
run_checker "$R"
expect "b: slugs drop punctuation, keep '&' gaps as '--', number repeats, ignore backticks" 0
printf 'docs/design.md#not-a-heading\n' > "$R/README.md"
run_checker "$R"
expect "b: a heading inside fenced code is not an anchor" 1 "not-a-heading"

# ---------------------------------------------------------------- (c)
echo "== (c) placeholder and issue references =="
R="$(new_root c)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## How it works

Tracked in (#295) and also [x](#12) and a placeholder [y](#<slug>).
DOC
printf 'Cite as docs/design.md#<section> in the skills.\n' > "$R/README.md"
run_checker "$R"
expect "c: #<section>, (#295), [x](#12) and [y](#<slug>) are ignored" 0

# ---------------------------------------------------------------- (d)
echo "== (d) malformed anchors =="
R="$(new_root d)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## How it works
DOC
printf 'See docs/design.md#How-it-works here.\n' > "$R/README.md"
run_checker "$R"
expect "d: #How-it-works against a 'How it works' heading is a malformed anchor" 1 \
    "README.md:1:" "malformed" "How-it-works"
printf 'See docs/design.md#how_it_works here.\n' > "$R/README.md"
run_checker "$R"
expect "d: #how_it_works (underscore) is a malformed anchor" 1 "malformed"
printf 'See docs/design.md#-how here.\n' > "$R/README.md"
run_checker "$R"
expect "d: a leading hyphen is a malformed anchor" 1 "malformed"
printf '\nSee [x](#How-it-works).\n' >> "$R/docs/design.md"
: > "$R/README.md"
run_checker "$R"
expect "d: a wrongly cased in-file link is a malformed anchor" 1 "docs/design.md:5:" "malformed"

# ---------------------------------------------------------------- (e)
echo "== (e) guards off while the register heading is absent =="
R="$(new_root e)"
plain_design "$R/docs/design.md"
add_adrs "$R" 3
run_checker "$R"
expect "e: no register heading, no in-file links, three ADR files: exit 0" 0

# ---------------------------------------------------------------- (f)
echo "== (f) guards live once the register heading exists =="
R="$(new_root f1)"
register_design "$R/docs/design.md" 2
add_adrs "$R" 3
run_checker "$R"
expect "f: two anchored rows against three ADR files exits 1" 1 \
    "docs/design.md:5:" "2 anchored rows" "3 files"

R="$(new_root f2)"
register_design "$R/docs/design.md" 3
add_adrs "$R" 3
run_checker "$R"
expect "f: three anchored rows against three ADR files exits 0" 0

R="$(new_root f3)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## Decision register

No rows and no links.
DOC
add_adrs "$R" 3
run_checker "$R"
expect "f: register heading present but no '](#' link anywhere exits 1 (guard a)" 1 \
    "no in-file"

R="$(new_root f4)"
register_design "$R/docs/design.md" 3
run_checker "$R"
expect "f: register present but no docs/decisions/ directory: guards stay off" 0

R="$(new_root f5)"
register_design "$R/docs/design.md" 2
printf '\n| 0009 | in force | [x](#how-it-works) |\n' >> "$R/docs/design.md"
add_adrs "$R" 3
run_checker "$R"
expect "f: a row after the register's section ends is not counted" 1 "2 anchored rows"

R="$(new_root f6)"
register_design "$R/docs/design.md" 3
# rows without a link do not count; neither does a prose link outside a row
sed -i 's/\[How it works\](#how-it-works) |$/plain text |/' "$R/docs/design.md"
printf '\nSee [x](#how-it-works).\n' >> "$R/docs/design.md"
add_adrs "$R" 3
run_checker "$R"
expect "f: table rows without a '](#' link do not count toward the register" 1 "0 anchored rows"

R="$(new_root f7)"
register_design "$R/docs/design.md" 3
sed -i 's/(#how-it-works)/(#decision-register)/' "$R/docs/design.md"
add_adrs "$R" 3
run_checker "$R"
expect "f: rows linking '#decision-register' itself resolve and count" 0

R="$(new_root f8)"
register_design "$R/docs/design.md" 3
sed -i 's/(#how-it-works)/(#no-such-heading)/' "$R/docs/design.md"
add_adrs "$R" 3
run_checker "$R"
expect "f: register rows linking a missing section fail the resolve check" 1 "no-such-heading"

# ---------------------------------------------------------------- (g)
echo "== (g) a new ADR file without a register row =="
R="$(new_root g1)"
register_design "$R/docs/design.md" 3
add_adrs "$R" 4
run_checker "$R"
expect "g: register of three rows, four ADR files: exit 1" 1 "3 anchored rows" "4 files"

R="$(new_root g2)"
plain_design "$R/docs/design.md"
add_adrs "$R" 4
run_checker "$R"
expect "g: the same fourth ADR file with no register heading: exit 0" 0

# ------------------------------------------------------- usage and root
echo "== usage and root selection =="
R="$(new_root u1)"
run_checker "$R"
expect "usage: missing docs/design.md exits 2" 2 "design.md"

RC=0
OUT="$(bash "$CHECKER" "$SANDBOX/no-such-dir" 2>&1)" || RC=$?
expect "usage: root that is not a directory exits 2" 2 "not a directory"

RC=0
OUT="$(bash "$CHECKER" "$R" extra 2>&1)" || RC=$?
expect "usage: more than one argument exits 2" 2 "usage"

R="$(new_root u2)"
plain_design "$R/docs/design.md"
printf 'docs/design.md#no-such-section\n' > "$R/README.md"
RC=0
OUT="$(DESIGN_ANCHORS_ROOT="$R" bash "$CHECKER" 2>&1)" || RC=$?
expect "usage: DESIGN_ANCHORS_ROOT selects the root when no argument is given" 1 "no-such-section"

echo ""
echo "test_design_anchors: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
