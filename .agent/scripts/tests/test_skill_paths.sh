#!/usr/bin/env bash
# .agent/scripts/tests/test_skill_paths.sh
# Keeps project-capable skills free of workspace-relative paths (#317), and
# guards the skill set itself: the declared session_scope list, the
# replacement of the old what-next skill by the sit-rep (#389), and the
# orchestrator skill, the host's standing rules, the run-issue
# checkpoint text they rely on, and the roadmap's two Paths paragraphs
# (#321), and the onboard-project rules the owner gave (#332).
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
        fail "orchestrator: the issue 398 log writes its text to the system temp dir (-t) or removes it whatever the post's exit"
    else
        pass "orchestrator: the issue 398 log neither writes to /tmp nor removes its text on a failed post"
    fi
    # Recipe (a)'s review-issue dispatch carries the drive's own root flags:
    # dispatch_phase.sh defaults to --type workspace, so a project drive
    # following a flagless command would review the workspace issue.
    has "$ORCH" "orchestrator: the restart recipe dispatches review-issue with the drive's --type, --project and --skill-prefix" \
        '$WS_ROOT/.agent/scripts/dispatch_phase.sh --issue <N> --skill review-issue [--type <type>] [--project <project>] [--skill-prefix agent-workspace:]'
    if tr '\n' ' ' < "$ORCH" | tr -s ' ' | grep -qF -- '--skill review-issue`'; then
        fail "orchestrator: a review-issue dispatch command ends without the drive's --type, --project and --skill-prefix"
    else
        pass "orchestrator: no review-issue dispatch command drops the drive's root flags"
    fi
    # Recipe (a) puts his restated goal where review-issue reads: a signed
    # comment on the issue (posted once, checked by its first line), and his
    # words quoted in the review-issue handoff too.
    has "$ORCH" "orchestrator: the restart recipe posts his words on the issue, once, before review-issue, and quotes them in its handoff" \
        'Post his words on the issue as a signed comment' \
        'MARK="Goal restated by the owner mid-drive (restart checkpoint, <its **When**>):"' \
        'elif grep -qF -- "$MARK" <<< "$COMMENTS"; then' \
        'BODY="$(mktemp "$WS_ROOT/.agent/scratchpad/restart-goal.XXXXXX.md")"' \
        'if gh issue comment <N> --body-file "$BODY"; then' \
        'On a "not posted" line, dispatch nothing' \
        'Paste his words, quoted, into its handoff as well' \
        'and into the `plan-task` handoff that follows it' \
        'the host does steps 2 and 3 then, from the `restart` entry'"'"'s words'
    # The restart comment carries his words, which a stranger could read as
    # his word, so the host shows him the exact comment and waits for his
    # yes every time, on the recovery path too (owner at issue 321's merge
    # checkpoint, 2026-10-28: "B ask first"); a no posts nothing and asks
    # him how the goal should reach the issue.
    has "$ORCH" "orchestrator: the restart comment is posted only on his yes to its exact text, every time, the recovery path included" \
        'Only on "not on the issue yet", ask, every time: show him the exact comment the post block below would post' \
        'and wait for his yes' \
        'On his no, nothing is posted: ask him how the restated goal should reach the issue instead' \
        'he may post it himself, or give words he is willing to have posted' \
        'The comment is not covered by that decision: step 2 checks the issue for it first, and only when it is not there shows him its exact text and waits for his yes before posting' \
        'signed comments on the issue being driven except one that carries his words' \
        'run from the issue'"'"'s worktree only after the owner has seen the exact comment it posts and said yes' \
        '`restart` checkpoint (recipe (a); its comment is checked for first and, when not there, still waits for his yes)'
    if tr '\n' ' ' < "$ORCH" | tr -s ' ' | grep -qE 'without asking \(the owner already decided it\)|signed comment on the issue being driven is inside the outward boundary'; then
        fail "orchestrator: the restart comment is still posted without asking him"
    else
        pass "orchestrator: no text lets the restart comment go out without his yes"
    fi
    # Check before ask: on a resumed drive the restart comment may already
    # be public, so the host looks for $MARK first and asks him only when
    # it is not there; a failed check asks nothing and posts nothing. The
    # post block keeps its own re-check as the idempotency guard.
    has "$ORCH" "orchestrator: the restart recipe checks the issue for the comment before asking him, on the recovery path too" \
        'Check first, then ask. Run the check block in "The restart comment" below' \
        'On "already on the issue", the comment went out on an earlier pass: ask him nothing and go on to step 3' \
        'the check itself failed: ask nothing, post nothing, and the line goes into the hand-back' \
        'checks, asks and posts it then' \
        'echo "not on the issue yet: show him the comment and ask"' \
        'It checks for `$MARK` again'
    orch_flat="$(tr '\n' ' ' < "$ORCH" | tr -s ' ')"
    check_at="$(grep -bo -F -- 'Check first, then ask' <<< "$orch_flat" | head -n1 | cut -d: -f1)"
    ask_at="$(grep -bo -F -- 'show him the exact comment' <<< "$orch_flat" | head -n1 | cut -d: -f1)"
    chk_blk="$(grep -bo -F -- 'echo "not on the issue yet' <<< "$orch_flat" | head -n1 | cut -d: -f1)"
    post_blk="$(grep -bo -F -- 'if gh issue comment <N>' <<< "$orch_flat" | head -n1 | cut -d: -f1)"
    if [[ -n "$check_at" && -n "$ask_at" && -n "$chk_blk" && -n "$post_blk" \
          && $check_at -lt $ask_at && $chk_blk -lt $post_blk ]]; then
        pass "orchestrator: the check comes before the question, and the check block before the post block"
    else
        fail "orchestrator: the restart recipe asks him before checking the issue for the comment"
    fi
    # A session that ends after the Issue Review resumes at plan-task, which
    # reads a git-bug copy that may lack the restart comment, and so do
    # review-plan and a plan-task revision after a plan checkpoint answered
    # revise: the host keeps quoting the restart words until the plan
    # checkpoint is answered proceed.
    has "$ORCH" "orchestrator: the restart words go into every review-issue, plan-task and review-plan handoff until a plan checkpoint answered proceed, on a resumed drive too" \
        'Until a `## Checkpoint` with `**After**: plan` and `**Decision**: proceed` follows the newest `restart` entry, the host quotes that entry'"'"'s words into every `review-issue`, `plan-task` and `review-plan` handoff, on a resumed drive too' \
        'a plan checkpoint answered `revise` routes back to `plan-task`'
    # The restart comment's first line is printed from $MARK, so the
    # duplicate check and the posted text cannot drift apart.
    has "$ORCH" "orchestrator: the restart comment's first line is \$MARK itself" \
        "printf '%s\\n\\n' \"\$MARK\""
    # Every bash block runs as written: raw lines, indentation kept, only
    # the <placeholders> replaced. A block indented inside a list item has
    # its heredoc's closing EOF indented too, so the heredoc never closes:
    # bash -n then reports a syntax error or warns, and either fails here.
    n_blocks=0; bad_blocks=""
    while IFS= read -r -d '' block; do
        n_blocks=$((n_blocks + 1))
        out="$(sed -E 's/<[A-Za-z][^<>]*>/PLACEHOLDER/g' <<< "$block" | bash -n 2>&1)"; rc=$?
        if [[ $rc -ne 0 || -n "$out" ]]; then
            bad_blocks+="block $n_blocks (exit $rc): $(head -n1 <<< "$out")"$'\n'
        fi
    done < <(awk '
        /^[[:space:]]*```bash[[:space:]]*$/ { inb = 1; buf = ""; next }
        inb && /^[[:space:]]*```[[:space:]]*$/ { inb = 0; printf "%s%c", buf, 0; next }
        inb { buf = buf $0 "\n" }' "$ORCH")
    if [[ $n_blocks -eq 0 ]]; then
        fail "orchestrator: no bash blocks found to parse"
    elif [[ -n "$bad_blocks" ]]; then
        fail "orchestrator: a bash block does not parse as written (bash -n):"
        printf '%s' "$bad_blocks" | sed 's/^/        /'
    else
        pass "orchestrator: all $n_blocks bash blocks parse as written (bash -n, indentation kept)"
    fi
    has "$ORCH" "orchestrator: parked items go to the inbox with capture.sh" \
        '$WS_ROOT/.agent/scripts/capture.sh'
else
    fail "orchestrator skill is missing: .claude/skills/orchestrator/SKILL.md"
fi

# --- onboard-project (#332 PR 3): the project side of onboarding, run at
# the project root; its owner-given rules are worded here so a rewrite
# cannot drop one silently.
ONB="$SKILLS/onboard-project/SKILL.md"
if [[ -f "$ONB" ]]; then
    has "$ONB" "onboard-project: no repository argument; --dry-run and --reask" \
        '/agent-workspace:onboard-project [--dry-run] [--reask <key>]' \
        'No repository argument'
    if grep -qF 'project/<repo-name>' "$ONB"; then
        fail "onboard-project still locates the repository as project/<repo-name>"
    else
        pass "onboard-project no longer locates the repository under project/"
    fi
    has "$ONB" "onboard-project: resolves the project with session_root.sh and sends an unregistered one to register_project.sh" \
        '"$WS_ROOT/.agent/scripts/session_root.sh"' 'register_project.sh <path>' \
        'Onboarding runs in a session started at the project'"'"'s root'
    has "$ONB" "onboard-project: shows the recorded choices and runs the integration audit" \
        '"$WS_ROOT/.agent/scripts/project_setting.sh" list <name>' \
        '"$WS_ROOT/.agent/scripts/project_integration_audit.sh" --format text'
    has "$ONB" "onboard-project: asks only unanswered footprint questions, with the provisional default" \
        'Ask only for a key with no recorded value, or the one `--reask` names' \
        'project_records_default "$WS_ROOT" <name> accepts-footprint' \
        '**provisional**' \
        'until the records lookup (#393) lands, only (project, project) is stored' \
        'records still land on each issue'"'"'s feature branch'
    has "$ONB" "onboard-project: offers only when instructions=tracked; audit-project always" \
        '### 5. Offers — only when `instructions=tracked`' \
        'When it is `none`, make no offer of a tracked file' \
        'Whatever `instructions` says, offer to run `/agent-workspace:audit-project`'
    has "$ONB" "onboard-project: every write waits for a yes" \
        '**Every write waits for a yes.**' 'changes nothing without a yes'
    has "$ONB" "onboard-project: the four answers and the owner's D6 words, verbatim" \
        '**Fix now**' '**Open issue**' '**Queue in the roadmap**' '**Skip**' \
        '"all that work should be cued up in the roadmap, if the user approves, so that it can get tackled maybe as other issues are resolved"' \
        '## Onboarding' \
        'until the records lookup (#393) lands, queue in the roadmap is not offered to it'
    has "$ONB" "onboard-project: process conflicts are flagged with both sides, never picked" \
        'never pick one' 'Governance Layering'
    has "$ONB" "onboard-project: the hygiene checklist keeps a labelled home until PR 4" \
        '## Hygiene checklist (moves to audit-project, #332 PR 4)'
    has "$ONB" "onboard-project: a project with no GitHub keeps its edits on a branch" \
        'leave the edits on the branch, push nothing'
    n_blocks=0; bad_blocks=""
    while IFS= read -r -d '' block; do
        n_blocks=$((n_blocks + 1))
        out="$(sed -E 's/<[A-Za-z][^<>]*>/PLACEHOLDER/g' <<< "$block" | bash -n 2>&1)"; rc=$?
        if [[ $rc -ne 0 || -n "$out" ]]; then
            bad_blocks+="block $n_blocks (exit $rc): $(head -n1 <<< "$out")"$'\n'
        fi
    done < <(awk '
        /^[[:space:]]*```bash[[:space:]]*$/ { inb = 1; buf = ""; next }
        inb && /^[[:space:]]*```[[:space:]]*$/ { inb = 0; printf "%s%c", buf, 0; next }
        inb { buf = buf $0 "\n" }' "$ONB")
    if [[ $n_blocks -eq 0 ]]; then
        fail "onboard-project: no bash blocks found to parse"
    elif [[ -n "$bad_blocks" ]]; then
        fail "onboard-project: a bash block does not parse as written (bash -n):"
        printf '%s' "$bad_blocks" | sed 's/^/        /'
    else
        pass "onboard-project: all $n_blocks bash blocks parse as written (bash -n, indentation kept)"
    fi
else
    fail "onboard-project skill is missing: .claude/skills/onboard-project/SKILL.md"
fi

# --- run-issue: the host may answer a checkpoint, within the orchestrator's table.
RI="$SKILLS/run-issue/SKILL.md"
has "$RI" "run-issue documents Decided-by: host and the owner-only answers" \
    '**Decided-by**: owner | host (<reason>)' \
    '`merge` and `merge-refused` always wait for the owner, and so do `takeover` at `phase-failed` and `merge` at `findings`' \
    'never lets the host do a phase'"'"'s work itself' '/orchestrator'
has "$RI" "run-issue: the restart words go into every review-issue, plan-task and review-plan handoff until a plan checkpoint answered proceed, on a resumed drive too" \
    'Until a `## Checkpoint` with `**After**: plan` and `**Decision**: proceed` follows the newest `restart` entry, the host quotes that entry'"'"'s words into every `review-issue`, `plan-task` and `review-plan` handoff, on a resumed drive too' \
    'a plan checkpoint answered `revise` routes back to `plan-task` after the `## Plan Authored` entry'
has "$RI" "run-issue: the restart comment is posted only on his yes to its exact text, every time, the resumed drive included" \
    'posted only after the host has shown him the exact comment and he has said yes, every time' \
    'on a no nothing is posted and the host asks him how the restated goal should reach the issue' \
    'the host checks first whether the comment is already there; if not, shows him the comment and posts it on his yes' \
    'When the check itself fails, nothing is asked, posted or dispatched: the "not posted" line goes into the hand-back and the `restart` entry stays the newest'
if tr '\n' ' ' < "$RI" | tr -s ' ' | grep -qF 'shows him the comment and posts it on his yes, unless it is already there'; then
    fail "run-issue: the resumed drive still asks before checking whether the restart comment is already there"
else
    pass "run-issue: the resumed drive checks for the restart comment before asking"
fi

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
