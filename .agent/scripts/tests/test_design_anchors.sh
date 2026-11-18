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
#   (h) a part's design (issue #488): citations resolve against the part's
#       headings, never the root's; each form's base (link from its file,
#       backtick from its file then the root); URLs skipped; the root's
#       design, part designs and followed sub-roadmaps as citers; untracked
#       copies ignored
#   usage and root selection, including the default root: a sandbox copy of
#       the checker run with no argument through a `scripts/` symlink checks
#       its own repository, not the repository's parent
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

# a citer in docs/ also cites design.md by a relative path
R="$(new_root b2r)"
plain_design "$R/docs/design.md"
printf 'See [x](design.md#no-such-section) and [y](./design.md#also-missing).\n' > "$R/docs/roadmap.md"
run_checker "$R"
expect "b: relative design.md# and ./design.md# citations in docs/roadmap.md are checked" 1 \
    "docs/roadmap.md:1:" "no-such-section" "also-missing"
printf '[x](design.md#glossary) [y](./design.md#how-it-works)\n' > "$R/docs/roadmap.md"
run_checker "$R"
expect "b: valid relative citations in docs/roadmap.md pass" 0
printf 'See docs/design.md#gone here.\n' > "$R/docs/roadmap.md"
run_checker "$R"
expect "b: a docs/design.md# citation in docs/roadmap.md is reported once, not again as relative" 1 \
    "check_design_anchors: 1 finding(s)"
printf '[x](../design.md#elsewhere) [y](other-design.md#elsewhere)\n' > "$R/docs/roadmap.md"
printf 'design.md#elsewhere\n' > "$R/README.md"
run_checker "$R"
expect "b: ../design.md#, other-design.md# and a bare design.md# outside docs/ name other files and are not checked" 0

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

# fences: a closer carries no info string; tilde fences work
R="$(new_root b4)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## A

````md
```bash
## Inside the fence
```
[x](#still-inside)
````

~~~
## Tilde hidden
[y](#tilde-inside)
~~~

[z](#a)
DOC
run_checker "$R"
expect "b: a bash-tagged fence line inside an open fence does not close it; tilde fences hide headings and links" 0

R="$(new_root b5)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## A

```md
```bash
more
```
[x](#nope)
DOC
run_checker "$R"
expect "b: a fence closed by a bare fence line ends, so the link after it is checked" 1 \
    "docs/design.md:9:" "nope"

R="$(new_root b6)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## A

~~~
```
[x](#nope)
~~~
[y](#nope2)
DOC
run_checker "$R"
expect "b: a backtick line does not close a tilde fence; the tilde closer does" 1 \
    "docs/design.md:9:" "nope2"

# fences: indentation and end of file
R="$(new_root b9)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## A

Indented code, not a fence:

    ```
[x](#nope)
DOC
run_checker "$R"
expect "b: a 4-space-indented backtick line outside a list is not a fence, so the link after it is checked" 1 \
    "docs/design.md:8:" "nope"
if grep -qF "never closed" <<<"$OUT"; then fail "b: indented code was taken for an unclosed fence"; else pass "b: indented code is not reported as an unclosed fence"; fi

R="$(new_root b10)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## A

```bash
echo never closed
DOC
run_checker "$R"
expect "b: a fence still open at end of file fails and names its opening line" 1 \
    "docs/design.md:5:" "never closed"

R="$(new_root b11)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## A

- An item with a fence:

  ```bash
  ## Hidden in the item
  [x](#item-inside)
  ```

10. An ordered item, content at column 4:

    ```
    [y](#ordered-inside)
    ```

- Outer
  - Inner, content at column 4:

    ~~~
    [z](#nested-inside)
    ~~~

[w](#a)
DOC
run_checker "$R"
expect "b: fences nested in list items (bullet, wide ordered marker, nested list) still hide their links" 0

R="$(new_root b12)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## A

- An item:

      ```
[x](#nope)
DOC
run_checker "$R"
expect "b: a backtick line 4 spaces past an item's content column is indented code, so the link after it is checked" 1 \
    "docs/design.md:8:" "nope"

R="$(new_root b13)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## A

```
    ```
[x](#hidden)
```
[y](#nope)
DOC
run_checker "$R"
expect "b: a 4-space-indented closer does not close a top-level fence; the real closer does" 1 \
    "docs/design.md:9:" "nope"
if grep -qF "hidden" <<<"$OUT"; then fail "b: a link inside the fence was checked"; else pass "b: the link inside the fence stays hidden"; fi

# repeated slugs follow GitHub's slugger
R="$(new_root b14)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## A

## A

## A-1

## B-1

## B

## B
DOC
printf 'docs/design.md#a docs/design.md#a-1 docs/design.md#a-1-1 docs/design.md#b-1 docs/design.md#b docs/design.md#b-2\n' > "$R/README.md"
run_checker "$R"
expect "b: a repeated slug takes the first free -N (A, A, A-1 give a, a-1, a-1-1; B-1, B, B give b-1, b, b-2)" 0
printf 'docs/design.md#a-2\n' > "$R/README.md"
run_checker "$R"
expect "b: no a-2 is made when A-1 is a heading of its own" 1 "a-2"

# headings: closing #s, links in headings, empty slug, underscore
R="$(new_root b7)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## Closing hashes ##

## snake_case words

## !!!

## Plain
DOC
printf 'docs/design.md#closing-hashes docs/design.md#snake_case-words docs/design.md#plain\n' > "$R/README.md"
run_checker "$R"
expect "b: closing #s are dropped, '_' is kept and citable, an empty-slug heading is skipped cleanly" 0
if grep -qiF "subscript" <<<"$OUT"; then fail "b: empty slug leaks a bash error"; else pass "b: empty-slug heading produces no bash error output"; fi

R="$(new_root b8)"
cat > "$R/docs/design.md" <<'DOC'
# The design

## [See](#gone)

## [Self](#self)
DOC
run_checker "$R"
expect "b: a link inside a heading is checked: the broken one is named, the self link passes" 1 \
    "docs/design.md:3:" "gone"
if grep -qF "#self" <<<"$OUT"; then fail "b: the resolving heading link was reported"; else pass "b: the resolving heading link is not reported"; fi

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
expect "d: #how_it_works against a 'How it works' heading is a broken anchor, not malformed" 1 "broken" "how_it_works"
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

# ---------------------------------------------------------------- (h)
echo "== (h) a part's design (issue #488) =="
# part_root <name>: a git root with the root's design (headings How it
# works, Glossary, Only root), a part design under tools/t/docs with the
# headings Only part and Inner, and one under docs/manifest with Route.
part_root() {
    local root
    root="$(new_root "$1")"
    plain_design "$root/docs/design.md"
    printf '\n## Only root\n' >> "$root/docs/design.md"
    mkdir -p "$root/tools/t/docs" "$root/docs/manifest"
    printf '# Tool\n\n## Only part\n\n## Inner\n\nSee [inner](#inner).\n' > "$root/tools/t/docs/design.md"
    printf '# Manifest\n\n## Route\n' > "$root/docs/manifest/design.md"
    git -C "$root" init -q
    git -C "$root" add -A
    echo "$root"
}
R="$(part_root h1)"
printf 'Cites `tools/t/docs/design.md#only-part` and `docs/manifest/design.md#route`.\n' > "$R/README.md"
git -C "$R" add README.md
run_checker "$R"
expect "h: a part's design is cited by its path and resolves against its own headings" 0
printf 'Cites `tools/t/docs/design.md#only-root`.\n' > "$R/README.md"
run_checker "$R"
expect "h: a fragment present only in the root's design fails as a part citation" 1 \
    "README.md:1:" "no such heading in tools/t/docs/design.md"
printf 'Cites `docs/design.md#only-part`.\n' > "$R/README.md"
run_checker "$R"
expect "h: a fragment present only in the part's design fails as a root citation" 1 "no such heading in docs/design.md"
printf 'Cites `tools/gone/docs/design.md#x`.\n' > "$R/README.md"
run_checker "$R"
expect "h: a missing part design file is an error" 1 "no such design file 'tools/gone/docs/design.md'"
printf 'Cites `tools/t/docs/design.md#Only-Part` and `tools/t/docs/design.md#` here.\n' > "$R/README.md"
run_checker "$R"
expect "h: a malformed part fragment fails; an empty one is a placeholder" 1 "malformed" "check_design_anchors: 1 finding(s)"
printf 'See https://github.com/o/r/blob/main/docs/design.md#nosuch and [x](https://github.com/o/r/blob/main/tools/t/docs/design.md#nosuch).\n' > "$R/README.md"
run_checker "$R"
expect "h: a URL into a design file is neither checked nor an error" 0

R="$(part_root h2)"
mkdir -p "$R/.claude/skills/s"
printf 'Use `docs/manifest/design.md#route`.\n' > "$R/.claude/skills/s/SKILL.md"
printf 'See [route](manifest/design.md#route) and `manifest/design.md#route` and `design.md#glossary`.\n' > "$R/docs/roadmap.md"
run_checker "$R"
expect "h: a backtick part path in a skill; a link and a backtick with the same text in docs/roadmap.md both resolve from docs/" 0
printf 'See [route](manifest/design.md#gone) and `manifest/design.md#gone2`.\n' > "$R/docs/roadmap.md"
run_checker "$R"
expect "h: both forms are checked against docs/manifest/design.md" 1 \
    "docs/roadmap.md:1: broken anchor '#gone' (no such heading in docs/manifest/design.md)" "#gone2"
printf 'See [x](docs/manifest/design.md#route).\n' > "$R/docs/roadmap.md"
run_checker "$R"
expect "h: a link resolves from its file only (docs/docs/manifest is missing)" 1 "no such design file 'docs/docs/manifest/design.md'"
printf 'See `docs/manifest/design.md#route`.\n' > "$R/docs/roadmap.md"
run_checker "$R"
expect "h: a backtick path with no file beside the citer falls back to the root" 0
# UP is `../`, so the fixture text holds no doubled parent step (which the
# hook-scope suite's root-derivation scan would read as this suite
# deriving a real repository root; it reads only its sandbox).
UP='../'
printf '[x](%s%s%soutside/docs/design.md#a)\n' "$UP" "$UP" "$UP" > "$R/docs/roadmap.md"
run_checker "$R"
expect "h: a path whose .. leaves the root is an error" 1 "leaves the root"
: > "$R/docs/roadmap.md"

printf '# Manifest\n\nSee [tool](%s%stools/t/docs/design.md#only-part) and [bad](%s%stools/t/docs/design.md#nope).\n\n## Route\n' "$UP" "$UP" "$UP" "$UP" > "$R/docs/manifest/design.md"
run_checker "$R"
expect "h: a link from one part's design to another resolves from its directory" 1 \
    "docs/manifest/design.md:3:" "#nope" "check_design_anchors: 1 finding(s)"
printf '# Manifest\n\n## Route\n' > "$R/docs/manifest/design.md"

printf '\nThe manifest route: [manifest/design.md](manifest/design.md#gone).\n' >> "$R/docs/design.md"
run_checker "$R"
expect "h: the root's design is a citer of a part's design" 1 "docs/design.md:" "no such heading in docs/manifest/design.md"
plain_design "$R/docs/design.md"

printf '# Tool\n\n## Only part\n\n[broken](#not-here)\n' > "$R/tools/t/docs/design.md"
run_checker "$R"
expect "h: a tracked part design's own in-file links are checked against its headings" 1 \
    "tools/t/docs/design.md:5:" "no such heading in tools/t/docs/design.md"
printf '# Tool\n\n## Only part\n' > "$R/tools/t/docs/design.md"

mkdir -p "$R/worktrees/x/docs" "$R/worktrees/y/tools/z/docs"
printf '# Draft\n\n[broken](#nowhere)\n' > "$R/worktrees/x/docs/design.md"
printf 'Cites `docs/design.md#nowhere`.\n' > "$R/worktrees/y/tools/z/docs/roadmap.md"
run_checker "$R"
expect "h: untracked copies (a git-ignored worktrees/ folder) are not read" 0

# A citation inside a followed sub-roadmap, outside any git repository: the
# pointer table finds the sub-roadmap and the design beside it.
R="$(new_root h3)"
plain_design "$R/docs/design.md"
mkdir -p "$R/tools/t/docs"
printf '# Tool\n\n## Only part\n\n[x](#gone-inner)\n' > "$R/tools/t/docs/design.md"
printf '# Tool roadmap\n\nSee [d](design.md#only-part) and [e](design.md#gone-sub).\n' > "$R/tools/t/docs/roadmap.md"
printf '# Roadmap\n\n## Direction\n\n| Sub-roadmap | Root |\n|---|---|\n| `tools/t/docs/roadmap.md` | `tools/t` |\n\n## Later\n' > "$R/docs/roadmap.md"
run_checker "$R"
expect "h: a followed sub-roadmap and the design beside it are citers, found through the pointer table" 1 \
    "tools/t/docs/roadmap.md:3:" "#gone-sub" "tools/t/docs/design.md:5:" "#gone-inner" "check_design_anchors: 2 finding(s)"

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

# Default root, as the hook calls it: no argument, DESIGN_ANCHORS_ROOT unset,
# run through the repo-root `scripts/` symlink from another directory. A
# lexical `../..` from <repo>/scripts/ is <repo>'s parent, which has no
# docs/design.md (exit 2); the repository's own fixture fails with exit 1.
mkdir -p "$SANDBOX/sym/repo/.agent/scripts" "$SANDBOX/sym/elsewhere"
SYM_REPO="$(cd "$SANDBOX/sym/repo" && pwd -P)"
cp "$CHECKER" "$SYM_REPO/.agent/scripts/check_design_anchors.sh"
ln -s .agent/scripts "$SYM_REPO/scripts"
mkdir -p "$SYM_REPO/docs"
plain_design "$SYM_REPO/docs/design.md"
printf 'docs/design.md#no-such-section\n' > "$SYM_REPO/README.md"
RC=0
OUT="$(cd "$SANDBOX/sym/elsewhere" && env -u DESIGN_ANCHORS_ROOT \
    bash "$SYM_REPO/scripts/check_design_anchors.sh" 2>&1)" || RC=$?
expect "usage: no argument through the scripts/ symlink checks the checker's own repository" 1 \
    "README.md:1:" "no-such-section"

echo ""
echo "test_design_anchors: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
