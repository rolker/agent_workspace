#!/usr/bin/env bash
# .agent/scripts/tests/test_skill_paths.sh
# Keeps project-capable skills free of workspace-relative paths (#317), and
# guards the skill set itself: the declared session_scope list, the
# replacement of the old what-next skill by the sit-rep (#389), and the
# orchestrator skill, the host's standing rules, the run-issue
# checkpoint text they rely on, and the roadmap's two Paths paragraphs
# (#321).
#
# A skill whose SKILL.md declares `session_scope: project` or `both` can run
# in a session started in a project checkout. There, a bare
# `.agent/scripts/...` does not resolve -- it names a workspace path from a
# cwd that is not the workspace. Such a skill must write the path as
# `$WS_ROOT/.agent/scripts/...` and resolve $WS_ROOT from
# ~/.claude/agent-workspace-root (ADR-0016).
#
# This test fails on any such reference introduced after this PR.
#
# Path scan scope: SKILL.md files ONLY. The tracked .claude/settings.json keeps its two
# existing relative hook commands as-is -- it is Ask-First and this PR does
# not edit it; the user tier gets its own generated copy with absolute paths
# (user_tier_install.sh). Workspace-scoped skills (no session_scope field --
# `workspace` is the documented default) keep relative paths, which are
# correct for them: they only ever run in the workspace checkout.
#
# The what-next guards at the end (#389) read more than SKILL.md files:
#  (a) the sitrep frontmatter `description` line names the trigger phrases
#      ("what's next?", "what should I work on?", "where are we?");
#  (b) the .claude/skills directory of the old skill does not exist;
#  (c) no live pointer to the old skill -- its slash command or its skills
#      path -- in tracked files under .agent/, .claude/, AGENTS.md or
#      Makefile. Prose that only names the skill passes. History records are
#      exempt by rule: work plans (.agent/work-plans/) and inspiration
#      digests (.agent/knowledge/inspiration_*).
#      NOT guarded: docs/, README.md, CODEX.md, CLAUDE.md and
#      .github/copilot-instructions.md. CI runs `make lint`, i.e.
#      `pre-commit run --all-files`, which runs this same hook over the same
#      pathspec, so CI does not read them either; and widening the pathspec
#      would need the hook-scope declaration (test_script_tests_hook_scope.sh)
#      to name docs/, which the validate-script-tests hook's `files:` regex
#      does not cover, so that test would fail. Those files were checked by
#      hand in #389.
#
# Hermetic: reads tracked files only (git grep for guard (c)). No HOME
# access, no network, no gh.
#
# Run: bash .agent/scripts/tests/test_skill_paths.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SKILLS="$WS_ROOT/.claude/skills"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

[[ -d "$SKILLS" ]] || { echo "FATAL: no skills directory at $SKILLS" >&2; exit 1; }

scope_of() {  # <SKILL.md> -- prints the declared session_scope, or "workspace"
    local scope
    scope="$(awk '
        NR == 1 && $0 == "---" { fm = 1; next }
        fm && $0 == "---" { exit }
        fm && /^session_scope:/ { sub(/^session_scope:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit }
    ' "$1")"
    echo "${scope:-workspace}"
}

# A workspace-relative reference: `.agent/scripts/` or `.claude/hooks/` NOT
# already prefixed by $WS_ROOT (or by another path component, which would
# make it part of a longer path rather than a bare relative one).
# Extended past .agent/scripts: a project-capable skill citing any workspace
# directory relatively has the same problem (round 1 review -- audit-project,
# document-project and test-engineering cited .agent/templates/ and
# .agent/knowledge/ and were missed by the narrower pattern).
BAD_RE='(^|[^/A-Za-z0-9_.$-])\.(agent/(scripts|templates|knowledge|project_types|work-plans)|claude/(hooks|skills))/'

scoped=0
for d in "$SKILLS"/*/; do
    f="$d/SKILL.md"
    [[ -f "$f" ]] || continue
    name="$(basename "$d")"
    scope="$(scope_of "$f")"
    case "$scope" in
        project|both) ;;
        workspace) continue ;;
        *)
            fail "$name declares an unknown session_scope: '$scope' (expected project, both, or no field)"
            continue
            ;;
    esac
    scoped=$((scoped + 1))

    # Two exclusions from the scan:
    #  - the YAML frontmatter, whose `description` names files in prose (it
    #    is what the skill picker reads, never a command to run);
    #  - the "Workspace root" section, which states the idiom and so has to
    #    quote the bare paths it is explaining.
    #  - a table explicitly marked `<!-- skill-paths: patterns-not-commands -->`,
    #    whose cells are path PATTERNS matched against a diff, not commands to
    #    run (the marker covers the table rows that follow it).
    body="$(awk '
        NR == 1 && $0 == "---" { fm = 1; next }
        fm { if ($0 == "---") fm = 0; next }
        /^## Workspace root[[:space:]]*$/ { skip = 1; next }
        skip && /^## / { skip = 0 }
        /skill-paths: patterns-not-commands/ { tbl = 1; next }
        tbl && /^[[:space:]]*\|/ { next }
        tbl && /^[[:space:]]*$/ { next }
        tbl { tbl = 0 }
        !skip { print }
    ' "$f")"

    hits="$(grep -nE "$BAD_RE" <<< "$body" || true)"
    if [[ -z "$hits" ]]; then
        pass "$name ($scope): no workspace-relative paths outside the idiom section"
    else
        n=$(grep -c . <<< "$hits")
        fail "$name ($scope): $n workspace-relative reference(s) -- write them as \$WS_ROOT/.agent/scripts/... :"
        head -n3 <<< "$hits" | sed 's/^/        /'
    fi

    # A skill that uses $WS_ROOT must also say where it comes from...
    if grep -q '\$WS_ROOT' "$f"; then
        if grep -q 'agent-workspace-root' "$f"; then
            pass "$name ($scope): \$WS_ROOT is resolved from ~/.claude/agent-workspace-root"
        else
            fail "$name ($scope): uses \$WS_ROOT but never says it comes from ~/.claude/agent-workspace-root"
        fi

        # ...and EVERY resolution must carry the `|| echo .` fallback. The
        # user tier is optional (ADR-0016, and --check says so), so without
        # the fallback $WS_ROOT is empty on a machine that never installed
        # it and every command becomes `/.agent/scripts/...` -- a regression
        # on the relative path this idiom replaced.
        bare=$(grep -nF 'cat ~/.claude/agent-workspace-root' "$f" \
               | grep -v '2>/dev/null || echo \.' || true)
        if [[ -z "$bare" ]]; then
            pass "$name ($scope): every \$WS_ROOT resolution carries the || echo . fallback"
        else
            n=$(grep -c . <<< "$bare")
            fail "$name ($scope): $n bare \`cat\` of agent-workspace-root (no || echo . fallback):"
            head -n3 <<< "$bare" | sed 's/^/        /'
        fi
    fi
done

if [[ "$scoped" -gt 0 ]]; then
    pass "scanned $scoped project-capable skill(s)"
else
    fail "no skill declares session_scope project or both -- the scoped set is empty, so this test proves nothing"
fi

# The frontmatter set itself: the scoped skills are a deliberate list, and a
# typo in the field name would silently drop a skill from the user tier.
for name in start-task plan-task review-plan review-code triage-reviews \
            test-engineering sitrep run-issue review-issue address-findings \
            orchestrator; do
    f="$SKILLS/$name/SKILL.md"
    [[ -f "$f" ]] || { fail "expected skill is missing: $name"; continue; }
    [[ "$(scope_of "$f")" == "both" ]] \
        && pass "$name declares session_scope: both" \
        || fail "$name should declare session_scope: both (got '$(scope_of "$f")')"
done
for name in document-project audit-project onboard-project; do
    f="$SKILLS/$name/SKILL.md"
    [[ -f "$f" ]] || { fail "expected skill is missing: $name"; continue; }
    [[ "$(scope_of "$f")" == "project" ]] \
        && pass "$name declares session_scope: project" \
        || fail "$name should declare session_scope: project (got '$(scope_of "$f")')"
done

# --- The old what-next skill is gone; the sit-rep answers "what's next?" (#389)
# The old name is built from pieces so this file never matches guard (c).
OLD="what""-next"

# (a) Trigger phrases, read from the frontmatter description line only.
desc="$(awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && /^description:/ { print; exit }
' "$SKILLS/sitrep/SKILL.md" 2>/dev/null)"
if [[ -z "$desc" ]]; then
    fail "sitrep: no frontmatter description line"
else
    for phrase in "what's next?" "what should I work on?" "where are we?"; do
        if grep -qiF -- "$phrase" <<< "$desc"; then
            pass "sitrep description names the trigger \"$phrase\""
        else
            fail "sitrep description does not name the trigger \"$phrase\""
        fi
    done
fi

# (b) The skill directory is gone.
if [[ -e "$SKILLS/$OLD" ]]; then
    fail ".claude/skills/$OLD still exists -- the sit-rep replaced it (#389)"
else
    pass "the old $OLD skill directory does not exist"
fi

# (c) No live pointer in hook-covered tracked files (see the header for what
# is not guarded, and why). git grep exits 0 on a match, 1 on none, >1 on error.
hits="$(git -C "$WS_ROOT" grep -nF -e "/$OLD" -e "skills/$OLD" -- \
    .agent/ .claude/ AGENTS.md Makefile \
    ':(exclude).agent/work-plans/' \
    ':(exclude,glob).agent/knowledge/inspiration_*' 2>&1)"
rc=$?
if [[ $rc -eq 1 ]]; then
    pass "no live pointer to the old $OLD skill under .agent/, .claude/, AGENTS.md, Makefile"
elif [[ $rc -eq 0 ]]; then
    n=$(grep -c . <<< "$hits")
    fail "$n live pointer(s) to the old $OLD skill (name it without the slash or path):"
    head -n5 <<< "$hits" | sed 's/^/        /'
else
    fail "could not run git grep for live pointers (exit $rc): $hits"
fi

# --- The orchestrator skill (#321): thin, pointing at run-issue and the
# rules file; the tokens only the owner answers; the issue 398 log.
ORCH="$SKILLS/orchestrator/SKILL.md"
has() {  # <file> <label> <fixed text>...: every text appears in the file,
          # line breaks and runs of spaces read as one space (prose wraps)
    local f="$1" label="$2" t flat; shift 2
    flat="$(tr '\n' ' ' < "$f" 2>/dev/null | tr -s ' ')"
    for t in "$@"; do
        grep -qF -- "$t" <<< "$flat" || { fail "$label: does not say '$t'"; return; }
    done
    pass "$label"
}
if [[ -f "$ORCH" ]]; then
    has "$ORCH" "orchestrator points at /run-issue and reads the standing rules" \
        '/run-issue' '$WS_ROOT/.agent/knowledge/host_standing_rules.md'
    has "$ORCH" "orchestrator: takeover at phase-failed and merge at findings are the owner's only" \
        '| `phase-failed` | `retry` | `takeover` |' '| `findings` | `address` | `merge`' \
        '| `merge` | — | every answer |' '| `merge-refused` | — | every answer |' \
        'never lets the host do a phase'"'"'s work itself'
    has "$ORCH" "orchestrator: a repeated host answer is capped at two in a row (retry, revise at plan, address at rounds)" \
        'two host `retry` answers in a row for the same phase' \
        'two host `revise` answers at `plan` in a row' \
        'two host `address` answers at `rounds` in a row' \
        "that checkpoint's next answer is the owner's"
    has "$ORCH" "orchestrator: the issue 398 log, signed, with its four headings" \
        'gh issue comment 398 -R "$WS_REPO" --body-file' \
        '## What reached the owner, and why' '## Decisions made, and any vetoes' \
        '## Where the decision-rights table was wrong or silent' \
        '## What the sit-rep or hand-back got wrong' '**Authored-By**' '**Model**'
    has "$ORCH" "orchestrator: the issue 398 log is posted only from the workspace checkout's own remote" \
        'if [ -f "$WS_ROOT/.agent/scripts/dispatch_phase.sh" ]; then' \
        'if [ -z "$WS_REPO" ]; then echo "not posted:' 'it is never retried against another repository'
    has "$ORCH" "orchestrator: a failed issue 398 post reaches the not-posted line and keeps its text in the workspace scratchpad" \
        'BODY="$(mktemp "$WS_ROOT/.agent/scratchpad/orchestrator-log.XXXXXX.md")"' \
        'if gh issue comment 398 -R "$WS_REPO" --body-file "$BODY"; then rm -f "$BODY" else echo "not posted: gh issue comment failed'
    if grep -qE 'mktemp -t|; rm -f "\$BODY"' "$ORCH"; then
        fail "orchestrator: the issue 398 log uses mktemp -t (/tmp) or removes its text whatever the post's exit"
    else
        pass "orchestrator: the issue 398 log neither writes to /tmp nor removes its text on a failed post"
    fi
    has "$ORCH" "orchestrator: parked items go to the inbox with capture.sh" \
        '$WS_ROOT/.agent/scripts/capture.sh'
else
    fail "orchestrator skill is missing: .claude/skills/orchestrator/SKILL.md"
fi

# --- run-issue: the host may answer a checkpoint, within the orchestrator's table.
RI="$SKILLS/run-issue/SKILL.md"
has "$RI" "run-issue documents Decided-by: host and the owner-only answers" \
    '**Decided-by**: owner | host (<reason>)' \
    '`merge` and `merge-refused` always wait for the owner, and so do `takeover` at `phase-failed` and `merge` at `findings`' \
    'never lets the host do a phase'"'"'s work itself' '/orchestrator'

# --- The host's standing rules (#321): every rule carries its reason.
# Rules with reasons are followed by intent, rules without them only
# literally (the 2026-10-15 audit the issue cites); an empty Reason cell
# is the defect this guards. The table is the one under `## Rules`, its
# header `| Rule | Reason | Source |`.
RULES="$WS_ROOT/.agent/knowledge/host_standing_rules.md"
if [[ ! -f "$RULES" ]]; then
    fail "host standing rules file is missing: .agent/knowledge/host_standing_rules.md"
else
    # Cells split on `|` outside backticks, so a code span holding a pipe
    # does not shift the Reason column.
    rules_out="$(python3 - "$RULES" <<'PYRULES'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
def cells(row):
    out, cur, code = [], "", False
    for ch in row.strip().strip("|"):
        if ch == "`":
            code = not code
        if ch == "|" and not code:
            out.append(cur.strip()); cur = ""
        else:
            cur += ch
    out.append(cur.strip())
    return out
sec = hdr = found = False
rows = bad = 0
for l in lines:
    if l.startswith("## "):
        sec = l.strip() == "## Rules"; hdr = False; continue
    if not sec or not l.lstrip().startswith("|"):
        continue
    c = cells(l)
    if not hdr:
        hdr = c[:2] == ["Rule", "Reason"]; found = found or hdr; continue
    if set("".join(c)) <= set("-: "):
        continue
    rows += 1
    if len(c) < 2 or not c[0] or not c[1]:
        bad += 1; print("empty: " + l[:100])
print("rows=%d bad=%d header=%s" % (rows, bad, found))
PYRULES
)"
    summary="$(tail -n1 <<< "$rules_out")"
    if [[ "$summary" == *"header=True" && "$summary" == "rows="* && "$summary" != "rows=0 "* && "$summary" == *" bad=0 "* ]]; then
        pass "host standing rules: every rule row has a reason ($summary)"
    else
        fail "host standing rules: a rule without a reason, or no | Rule | Reason | table under ## Rules: $rules_out"
    fi
fi

# --- The roadmap's two paths (#321): both paragraphs sit in the Direction
# section, as prose, with no table row between them (a Path column or
# table there would change sitrep_checks.sh's grammar).
ROADMAP="$WS_ROOT/docs/roadmap.md"
paths_out="$(awk '
    /^## / { sec = ($0 == "## Direction"); next }
    !sec { next }
    /^\*\*Path 1,/ { p1 = 1; inpaths = 1 }
    /^\*\*Path 2,/ { p2 = 1; last = 1 }
    inpaths && /^[[:space:]]*\|/ { print "table row between the Paths paragraphs: " $0 }
    last && /^[[:space:]]*$/ { inpaths = 0; last = 0 }
    END { if (!p1) print "no **Path 1, paragraph in ## Direction"
          if (!p2) print "no **Path 2, paragraph in ## Direction" }
' "$ROADMAP" 2>&1)"
if [[ -f "$ROADMAP" && -z "$paths_out" ]]; then
    pass "roadmap: Path 1 and Path 2 paragraphs in ## Direction, no table row between them"
else
    fail "roadmap paths: ${paths_out:-docs/roadmap.md is missing}"
fi

echo ""
echo "test_skill_paths: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
