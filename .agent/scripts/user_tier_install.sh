#!/usr/bin/env bash
# .agent/scripts/user_tier_install.sh
# Install (or check, or remove) the agent_workspace user tier in ~/.claude,
# so a Claude Code session started anywhere under a registered project root
# gets the workspace layer (#317, #265 PR 3).
#
# What the user tier consists of:
#   1. ~/.claude/agent-workspace-root   -- one line, no trailing newline: the
#      absolute path of this workspace checkout. THE way a skill command
#      chain finds a workspace script from a project cwd. A plain file, not
#      an environment variable and not hook output, so it works whether or
#      not the SessionStart hook ran. See ADR-0016.
#   2. ~/.claude/hooks/agent-workspace-session-start.sh -- a symlink to this
#      checkout's .claude/hooks/session_start_project_layer.sh, registered
#      as a SessionStart hook by absolute path.
#   3. Two PreToolUse entries, by absolute path, for
#      .claude/hooks/block-bash-tool-mapping.sh and log-tool-use.sh. Both
#      carry the registry_require_root guard, so they are inert outside the
#      workspace checkout and outside every registered root.
#   4. Permission allow-rules for the promoted scripts in
#      .agent/user_tier_scripts.txt, by absolute path.
#   5. Symlinks in ~/.claude/skills/ for every skill whose SKILL.md declares
#      `session_scope: project` or `session_scope: both`.
#
# Every entry this script writes into ~/.claude/settings.json is tagged
# "_agent_workspace": "<this checkout>", which is what makes --check able to
# tell OUR entries from the user's own and from another checkout's.
#
# Modes:
#   (default)            install or repair; idempotent, safe to re-run
#   --check              report drift. Exits 0 with a one-line note when the
#                        user tier is simply not installed -- `make validate`
#                        must stay green on a machine that never installed
#                        it. Exits 1 on drift when it IS installed.
#   --check --require    also exit 1 when it is not installed, for a machine
#                        that expects it.
#   --uninstall          remove every entry tagged with this checkout.
#   --list-skills        print the skills that would be symlinked, one per
#                        line (what `make generate-user-tier-skills` shows).
#   --sync-skills        reconcile ~/.claude/skills/ only.
#
# Exit codes: 0 ok; 1 drift / failure; 2 usage; 3 missing dependency (jq).
#
# Scope: this script writes ONLY inside $HOME/.claude. It never edits the
# tracked .claude/settings.json in the checkout, which stays exactly as it
# is (Ask-First).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$WS_ROOT/.agent/user_tier_scripts.txt"

CLAUDE_DIR="${HOME}/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
ROOT_FILE="$CLAUDE_DIR/agent-workspace-root"
# The allow-rules the installed generation wrote, so uninstall and --check can
# recognise rules this checkout owns even after the manifest changes.
RULES_FILE="$CLAUDE_DIR/agent-workspace-rules.json"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SKILLS_DIR="$CLAUDE_DIR/skills"
SESSION_HOOK_LINK="$HOOKS_DIR/agent-workspace-session-start.sh"
SESSION_HOOK_TARGET="$WS_ROOT/.claude/hooks/session_start_project_layer.sh"

TAG="$WS_ROOT"

# Modes are mutually exclusive. Previously they were last-one-wins, so
# `--uninstall --check` silently ran check only -- the caller believed they
# had uninstalled.
MODE=""
REQUIRE=false
FORCE=false
set_mode() {
    if [[ -n "$MODE" && "$MODE" != "$1" ]]; then
        echo "ERROR: --$1 and --$MODE are mutually exclusive; pick one" >&2
        exit 2
    fi
    MODE="$1"
}
for arg in "$@"; do
    case "$arg" in
        --check)       set_mode check ;;
        --require)     REQUIRE=true ;;
        --force)       FORCE=true ;;
        --uninstall)   set_mode uninstall ;;
        --list-skills) set_mode list-skills ;;
        --sync-skills) set_mode sync-skills ;;
        -h|--help)
            sed -n '2,45p' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            echo "usage: user_tier_install.sh [--force] | --check [--require] | --uninstall | --list-skills | --sync-skills" >&2
            exit 2
            ;;
    esac
done

[[ -n "$MODE" ]] || MODE="install"
if [[ "$REQUIRE" == true && "$MODE" != "check" ]]; then
    echo "ERROR: --require is only meaningful with --check" >&2
    exit 2
fi

# jq is needed only by the modes that read or merge settings.json. Checking
# it up front made `make validate` exit 3 on a jq-less machine -- the exact
# case this script's --check is supposed to keep green.
case "$MODE" in
    install|check|uninstall)
        if ! command -v jq >/dev/null 2>&1; then
            if [[ "$MODE" == "check" ]]; then
                echo "agent_workspace user tier: jq not installed -- cannot check (install jq to enable this check)"
                exit 0
            fi
            echo "ERROR: jq is required to merge ~/.claude/settings.json" >&2
            exit 3
        fi
        ;;
esac

# ---------------------------------------------------------------- inputs ---
# The promoted scripts (not the hooks -- those get hook entries, not
# permission rules), as absolute paths.
promoted_scripts() {
    [[ -f "$MANIFEST" ]] || return 0
    local line
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        [[ "$line" == .claude/hooks/* ]] && continue
        echo "$WS_ROOT/$line"
    done < "$MANIFEST"
}

# Skills whose SKILL.md declares session_scope: project | both. Skills with
# no field are `workspace` (the documented default) and are excluded.
selected_skills() {
    local d name scope
    for d in "$WS_ROOT"/.claude/skills/*/; do
        [[ -f "$d/SKILL.md" ]] || continue
        name="$(basename "$d")"
        scope="$(awk '
            NR == 1 && $0 == "---" { fm = 1; next }
            fm && $0 == "---" { exit }
            fm && /^session_scope:/ { sub(/^session_scope:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit }
        ' "$d/SKILL.md")"
        case "$scope" in
            project|both) echo "$name" ;;
        esac
    done
}

# The permission rules this checkout owns, as a JSON array.
allow_rules_json() {
    local s
    { while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        printf '%s\n' "Bash($s:*)"
        printf '%s\n' "Bash($s)"
      done < <(promoted_scripts)
    } | jq -R . | jq -s .
}

# Every allow-rule this checkout may have written: the generation recorded at
# install time, unioned with what the current manifest would generate. The
# union matters because the manifest can change between install and uninstall,
# and a rule named by neither side would be orphaned in settings.json.
installed_rules_json() {
    local recorded='[]'
    if [[ -f "$RULES_FILE" ]] && jq -e . "$RULES_FILE" >/dev/null 2>&1; then
        recorded="$(cat "$RULES_FILE")"
    fi
    jq -n --argjson a "$recorded" --argjson b "$(allow_rules_json)" '($a + $b) | unique'
}

hook_commands() {
    echo "$WS_ROOT/.claude/hooks/log-tool-use.sh"
    echo "$WS_ROOT/.claude/hooks/block-bash-tool-mapping.sh"
}

# --------------------------------------------------------------- helpers ---
installed() {
    [[ -f "$ROOT_FILE" ]] && [[ "$(cat "$ROOT_FILE" 2>/dev/null)" == "$WS_ROOT" ]]
}

# The user tier is singular: ~/.claude/agent-workspace-root names exactly one
# checkout, and every skill's $WS_ROOT follows it. Prints the OTHER checkout's
# path when the file exists and points somewhere else; empty otherwise.
installed_elsewhere() {
    local other
    [[ -f "$ROOT_FILE" ]] || return 1
    other="$(cat "$ROOT_FILE" 2>/dev/null)"
    [[ -n "$other" && "$other" != "$WS_ROOT" ]] || return 1
    printf '%s\n' "$other"
}

# Is settings.json present but unparseable? That is a state of its own, not
# an empty file: treating it as {} would silently drop every key the user
# has (model, their own allow-rules, their own hooks) on the next write.
settings_unparseable() {
    [[ -f "$SETTINGS" ]] && ! jq -e . "$SETTINGS" >/dev/null 2>&1
}

# Refuse rather than guess. Callers that may WRITE must call this first.
require_parseable_settings() {
    settings_unparseable || return 0
    cat >&2 <<EOF
ERROR: $SETTINGS exists but is not valid JSON.

Refusing to touch it: rewriting it would discard every setting in it. Fix
the file (jq . "$SETTINGS" will point at the syntax error), or move it
aside, then re-run this script.
EOF
    return 1
}

read_settings() {
    if [[ -f "$SETTINGS" ]]; then
        # Parse errors are the caller's to handle via require_parseable_settings
        # / settings_unparseable -- never silently downgraded to {} here.
        jq '.' "$SETTINGS" 2>/dev/null || echo '{}'
    else
        echo '{}'
    fi
}

# A timestamped copy beside the original, before any rewrite. Cheap, and the
# difference between a bad merge being an annoyance and being a data loss.
BACKUP_KEEP=5
backup_settings() {
    local stamp dest n=0
    [[ -f "$SETTINGS" ]] || return 0
    # Nanoseconds, so two runs in the same second do not collide and silently
    # overwrite the older of the two backups. A counter suffix covers the
    # coreutils builds where %N is not expanded.
    stamp="$(date +%Y%m%d-%H%M%S-%N)"
    [[ "$stamp" == *N ]] && stamp="$(date +%Y%m%d-%H%M%S)-$$"
    dest="$SETTINGS.agent-workspace-backup.$stamp"
    while [[ -e "$dest" ]]; do
        n=$((n + 1))
        dest="$SETTINGS.agent-workspace-backup.$stamp-$n"
    done
    cp -p "$SETTINGS" "$dest" || return 1
    echo "  backed up $SETTINGS -> $dest"

    # Keep only the newest few: these accumulate on every install, and an
    # unbounded pile of them in ~/.claude is its own small mess.
    local -a old=()
    while IFS= read -r f; do old+=("$f"); done < <(
        ls -1t "$SETTINGS".agent-workspace-backup.* 2>/dev/null | tail -n +$((BACKUP_KEEP + 1))
    )
    if [[ "${#old[@]}" -gt 0 ]]; then
        rm -f "${old[@]}"
        echo "  pruned ${#old[@]} old backup(s), keeping the newest $BACKUP_KEEP"
    fi
}

write_settings() {  # <json on stdin>
    local tmp
    mkdir -p "$CLAUDE_DIR"
    tmp="$(mktemp "$CLAUDE_DIR/.settings.json.XXXXXX")" || return 1
    cat > "$tmp" || { rm -f "$tmp"; return 1; }
    if ! jq -e . "$tmp" >/dev/null 2>&1; then
        echo "ERROR: refusing to write malformed settings.json" >&2
        rm -f "$tmp"
        return 1
    fi
    if [[ -L "$SETTINGS" ]]; then
        # settings.json is a symlink -- commonly into a dotfiles repo. `mv`
        # onto the LINK would replace it with a regular file and silently
        # detach the user's dotfiles, so resolve it and rename onto the real
        # file instead. `cat > "$SETTINGS"` would write through the link but
        # truncates first: an interrupted write leaves a half-file where a
        # valid settings.json was. Rename is atomic.
        local real
        real="$(readlink -f "$SETTINGS" 2>/dev/null)"
        if [[ -z "$real" ]]; then
            echo "ERROR: $SETTINGS is a symlink that does not resolve" >&2
            rm -f "$tmp"
            return 1
        fi
        # The rename must land on the same filesystem as $tmp to be atomic;
        # stage beside the real file when the dotfiles repo is elsewhere.
        local staged="$real.agent-workspace.$$"
        cp "$tmp" "$staged" || { rm -f "$tmp" "$staged"; return 1; }
        rm -f "$tmp"
        mv "$staged" "$real"
        return 0
    fi
    mv "$tmp" "$SETTINGS"
}

# ------------------------------------------------------------- list mode ---
if [[ "$MODE" == "list-skills" ]]; then
    selected_skills
    exit 0
fi

# Does <link> point into a DIFFERENT agent_workspace checkout? Recognised by
# the manifest file that only a workspace checkout has. Used under --force:
# a takeover that moves $WS_ROOT but leaves every skill symlink pointing into
# the old checkout is worse than not taking over at all, because the root file
# and the skills then disagree.
foreign_skill_link() {  # <link path>
    local tgt root
    [[ "$FORCE" == true ]] || return 1
    tgt="$(readlink -f "$1" 2>/dev/null)" || return 1
    [[ -n "$tgt" ]] || return 1
    # <checkout>/.claude/skills/<name> -> walk up three levels
    root="$(cd "$tgt/../../.." 2>/dev/null && pwd -P)" || return 1
    [[ -f "$root/.agent/user_tier_scripts.txt" ]] || return 1
    [[ "$root" != "$WS_ROOT" ]] || return 1
    return 0
}

# ------------------------------------------------------------ skill sync ---
sync_skills() {  # prints what it changed
    local name target link changed=0
    mkdir -p "$SKILLS_DIR"
    # Add or repair.
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        target="$WS_ROOT/.claude/skills/$name"
        link="$SKILLS_DIR/$name"
        if [[ -L "$link" ]]; then
            if [[ "$(readlink "$link")" == "$target" ]]; then
                continue
            fi
            if [[ "$(readlink "$link")" == "$WS_ROOT"/* ]] || foreign_skill_link "$link"; then
                ln -sfn "$target" "$link"
                echo "  repaired skill symlink: $name"
                changed=1
            else
                echo "  SKIPPED skill $name: ~/.claude/skills/$name is a symlink to something else ($(readlink "$link")) -- not ours to replace"
            fi
        elif [[ -e "$link" ]]; then
            echo "  SKIPPED skill $name: ~/.claude/skills/$name exists and is not a symlink -- not ours to replace"
        else
            ln -s "$target" "$link"
            echo "  linked skill: $name"
            changed=1
        fi
    done < <(selected_skills)

    # Remove stale links this checkout owns but that are no longer selected.
    # The selection is captured ONCE into a variable rather than re-run into
    # `grep -q` per link: under `set -o pipefail`, grep -q exits on its first
    # match and SIGPIPEs the producer, so the pipeline reports 141 and the
    # first matching skill looks unselected -- and gets deleted.
    local base selected
    selected="$(selected_skills)"
    for link in "$SKILLS_DIR"/*; do
        [[ -L "$link" ]] || continue
        # Ours, or -- under --force -- another checkout's, which the takeover
        # is responsible for clearing out: a skill that this checkout does not
        # select must not survive as a link into the checkout we just took the
        # tier away from.
        if [[ "$(readlink "$link")" != "$WS_ROOT/.claude/skills/"* ]] \
           && ! foreign_skill_link "$link"; then
            continue
        fi
        base="$(basename "$link")"
        if ! grep -qxF "$base" <<< "$selected"; then
            rm -f "$link"
            echo "  removed stale skill symlink: $base"
            changed=1
        fi
    done
    return "$changed"
}

if [[ "$MODE" == "sync-skills" ]]; then
    sync_skills || true
    echo "Skill symlinks reconciled in $SKILLS_DIR"
    exit 0
fi

# ------------------------------------------------------------- uninstall ---
if [[ "$MODE" == "uninstall" ]]; then
    if [[ ! -e "$ROOT_FILE" && ! -e "$SESSION_HOOK_LINK" && ! -f "$SETTINGS" ]]; then
        echo "agent_workspace user tier: nothing installed at $CLAUDE_DIR"
        exit 0
    fi
    [[ -f "$ROOT_FILE" ]] && [[ "$(cat "$ROOT_FILE")" == "$WS_ROOT" ]] && rm -f "$ROOT_FILE" \
        && echo "  removed $ROOT_FILE"
    [[ -L "$SESSION_HOOK_LINK" ]] && rm -f "$SESSION_HOOK_LINK" \
        && echo "  removed $SESSION_HOOK_LINK"
    for link in "$SKILLS_DIR"/*; do
        [[ -L "$link" ]] || continue
        [[ "$(readlink "$link")" == "$WS_ROOT/.claude/skills/"* ]] || continue
        rm -f "$link"
        echo "  removed skill symlink: $(basename "$link")"
    done
    if [[ -f "$SETTINGS" ]]; then
        require_parseable_settings || exit 1
        backup_settings || { echo "ERROR: could not back up $SETTINGS -- not proceeding" >&2; exit 1; }
        read_settings | jq --arg tag "$TAG" --argjson rules "$(installed_rules_json)" '
            .hooks //= {} |
            .hooks |= with_entries(
                .value |= map(select((._agent_workspace // "") != $tag))
            ) |
            .hooks |= with_entries(select(.value | length > 0)) |
            if (.permissions.allow? // null) != null then
                .permissions.allow |= map(select(. as $a | ($rules | index($a)) == null))
            else . end
        ' | write_settings && echo "  removed settings entries tagged $TAG"
    fi
    # Only now: the rewrite above reads this file to find rules written by an
    # earlier manifest generation, so removing it first would orphan them.
    [[ -f "$RULES_FILE" ]] && rm -f "$RULES_FILE" && echo "  removed $RULES_FILE"
    echo "agent_workspace user tier removed."
    exit 0
fi

# ----------------------------------------------------------------- check ---
if [[ "$MODE" == "check" ]]; then
    # An unparseable settings.json is reported as itself, not as drift. The
    # old behaviour read it as {}, reported every entry missing, and told the
    # user to re-run the installer -- which would then have overwritten it.
    if settings_unparseable; then
        echo "agent_workspace user tier: $SETTINGS is not valid JSON -- cannot check. Fix it (jq . \"$SETTINGS\") or move it aside." >&2
        exit 1
    fi

    # Installed, but for a DIFFERENT checkout. Previously this fell through
    # installed() to "not installed (optional)" and exited 0, so the one state
    # that actually breaks every skill's $WS_ROOT was the quietest one.
    if other_root="$(installed_elsewhere)"; then
        echo "agent_workspace user tier: installed for a different checkout: $other_root" >&2
        echo "  (this checkout is $WS_ROOT; every skill's \$WS_ROOT currently resolves to the other one)" >&2
        echo "  Re-run the installer with --force from whichever checkout should own the user tier." >&2
        exit 1
    fi

    if ! installed; then
        if [[ "$REQUIRE" == true ]]; then
            echo "agent_workspace user tier: NOT INSTALLED (--require) -- run .agent/scripts/user_tier_install.sh" >&2
            exit 1
        fi
        echo "agent_workspace user tier: not installed (optional; run .agent/scripts/user_tier_install.sh to enable project sessions)"
        exit 0
    fi

    drift=0
    note() { echo "  DRIFT: $1"; drift=1; }

    [[ -L "$SESSION_HOOK_LINK" ]] || note "missing SessionStart hook symlink at $SESSION_HOOK_LINK"
    if [[ -L "$SESSION_HOOK_LINK" && "$(readlink "$SESSION_HOOK_LINK")" != "$SESSION_HOOK_TARGET" ]]; then
        note "stale SessionStart hook symlink: points at $(readlink "$SESSION_HOOK_LINK"), expected $SESSION_HOOK_TARGET"
    fi
    [[ -e "$SESSION_HOOK_TARGET" ]] || note "SessionStart hook target does not exist: $SESSION_HOOK_TARGET"

    settings="$(read_settings)"
    export WS_ROOT_PREFIX="$WS_ROOT/"

    # Our hook entries, present and pointing at this checkout.
    # while-read, not `for cmd in $(...)`: a checkout path containing a space
    # or a glob character would otherwise word-split into permanent drift.
    while IFS= read -r cmd; do
        if ! jq -e --arg c "$cmd" --arg tag "$TAG" '
            [.hooks // {} | to_entries[] | .value[]
             | select((._agent_workspace // "") == $tag)
             | .hooks[]? | .command] | index($c) != null
        ' <<< "$settings" >/dev/null; then
            note "missing hook entry for $cmd"
        fi
    done < <(hook_commands; printf '%s\n' "$SESSION_HOOK_LINK")

    # Entries tagged as ours but naming a path outside this checkout, or
    # tagged for a DIFFERENT checkout (a second clone installed over us).
    foreign="$(jq -r --arg tag "$TAG" '
        [.hooks // {} | to_entries[] | .value[]
         | select((._agent_workspace // "") != "" and (._agent_workspace != $tag))
         | ._agent_workspace] | unique | .[]
    ' <<< "$settings")"
    if [[ -n "$foreign" ]]; then
        while IFS= read -r f; do
            note "settings.json has hook entries from another workspace checkout: $f"
        done <<< "$foreign"
    fi

    # The SessionStart entry deliberately names the ~/.claude symlink, not
    # the checkout path -- that indirection is what lets the hook be found
    # without the user tier hard-coding a checkout into every session. Every
    # OTHER command tagged as ours must live in this checkout.
    stale="$(jq -r --arg tag "$TAG" --arg ws "$WS_ROOT/" --arg link "$SESSION_HOOK_LINK" '
        [.hooks // {} | to_entries[] | .value[]
         | select((._agent_workspace // "") == $tag)
         | .hooks[]? | .command
         | select(. != $link)
         | select(startswith($ws) | not)] | .[]
    ' <<< "$settings")"
    if [[ -n "$stale" ]]; then
        while IFS= read -r st; do
            note "hook entry tagged as ours points outside this checkout: $st"
        done <<< "$stale"
    fi

    # Permission rules.
    # `. as $w` matters: inside `$have | index(...)` a bare `.` would refer
    # to $have, not to the rule being tested, and every rule would look
    # present.
    missing_rules="$(jq -r --argjson want "$(allow_rules_json)" '
        (.permissions.allow // []) as $have
        | [$want[] | . as $w | select(($have | index($w)) == null)] | .[]
    ' <<< "$settings")"
    if [[ -n "$missing_rules" ]]; then
        n=$(grep -c . <<< "$missing_rules")
        note "$n permission allow-rule(s) missing (manifest changed? re-run the installer)"
    fi

    # Rules recorded by an earlier generation that the current manifest no
    # longer names: still in settings.json, no longer wanted.
    orphan_rules="$(jq -r --argjson want "$(allow_rules_json)" '
        (.permissions.allow // []) as $have
        | [$want[]] as $w
        | [$have[] | . as $r | select(($w | index($r)) == null)
           | select(startswith("Bash(" + $ENV.WS_ROOT_PREFIX))] | .[]
    ' <<< "$settings" 2>/dev/null)"
    if [[ -n "$orphan_rules" ]]; then
        n=$(grep -c . <<< "$orphan_rules")
        note "$n allow-rule(s) for this checkout are no longer in the manifest (re-run the installer, or --uninstall to clear them)"
    fi

    # Skills.
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        link="$SKILLS_DIR/$name"
        if [[ ! -L "$link" ]]; then
            note "skill not linked: $name"
        elif [[ "$(readlink "$link")" != "$WS_ROOT/.claude/skills/$name" ]]; then
            note "stale skill symlink: $name -> $(readlink "$link")"
        fi
    done < <(selected_skills)

    # Captured once -- see sync_skills() for why a per-link pipeline into
    # `grep -q` is wrong under pipefail.
    selected_now="$(selected_skills)"
    for link in "$SKILLS_DIR"/*; do
        [[ -L "$link" ]] || continue
        [[ "$(readlink "$link")" == "$WS_ROOT/.claude/skills/"* ]] || continue
        base="$(basename "$link")"
        grep -qxF "$base" <<< "$selected_now" \
            || note "skill symlink is no longer selected (session_scope changed?): $base"
    done

    if [[ "$drift" -eq 0 ]]; then
        echo "agent_workspace user tier: installed and current ($WS_ROOT)"
        exit 0
    fi
    echo "agent_workspace user tier: DRIFT detected -- re-run .agent/scripts/user_tier_install.sh" >&2
    exit 1
fi

# --------------------------------------------------------------- install ---
# Never rewrite a settings.json we cannot parse -- that is how every user key
# in it would be lost.
require_parseable_settings || exit 1

# The user tier is singular. If another checkout owns it, say so and stop:
# taking it over silently repoints every skill's $WS_ROOT, and the losing
# checkout's --check used to report a cheerful "not installed (optional)".
if other_root="$(installed_elsewhere)" && [[ "$FORCE" != true ]]; then
    cat >&2 <<EOF
ERROR: the user tier is already installed for a different workspace checkout.

  currently installed: $other_root
  this checkout:       $WS_ROOT

Only one checkout can own ~/.claude at a time -- every skill's \$WS_ROOT
follows $ROOT_FILE. Re-run with --force to take it over, or run the
installer from $other_root instead.
EOF
    exit 1
fi
if [[ -n "${other_root:-}" && "$FORCE" == true ]]; then
    echo "  --force: taking the user tier over from $other_root"
fi

mkdir -p "$CLAUDE_DIR" "$HOOKS_DIR" "$SKILLS_DIR"

backup_settings || { echo "ERROR: could not back up $SETTINGS -- not proceeding" >&2; exit 1; }

# 1. the workspace-root file (no trailing newline -- callers do a bare `cat`)
printf '%s' "$WS_ROOT" > "$ROOT_FILE"
echo "  wrote $ROOT_FILE"

# 1b. and a record of exactly which allow-rules this generation wrote.
# Without it, uninstall could only match the CURRENT manifest, so rules from
# an earlier generation -- a script since renamed or dropped from the
# manifest -- stayed in settings.json forever with nothing able to name them.
allow_rules_json > "$RULES_FILE"
echo "  recorded $(jq 'length' < "$RULES_FILE") generated allow-rule(s) in $RULES_FILE"

# 2. the SessionStart hook symlink
if [[ ! -e "$SESSION_HOOK_TARGET" ]]; then
    echo "ERROR: hook target missing: $SESSION_HOOK_TARGET" >&2
    exit 1
fi
if [[ -e "$SESSION_HOOK_LINK" && ! -L "$SESSION_HOOK_LINK" ]]; then
    echo "ERROR: $SESSION_HOOK_LINK exists and is not a symlink -- not overwriting" >&2
    exit 1
fi
ln -sfn "$SESSION_HOOK_TARGET" "$SESSION_HOOK_LINK"
echo "  linked $SESSION_HOOK_LINK -> $SESSION_HOOK_TARGET"

# 3+4. settings.json: our hook entries and allow-rules, replacing any
# previous generation of ours (that is what makes this idempotent) and
# leaving everything else in the file untouched.
PRE_HOOKS_JSON="$(jq -n --arg tag "$TAG" \
    --arg log "$WS_ROOT/.claude/hooks/log-tool-use.sh" \
    --arg block "$WS_ROOT/.claude/hooks/block-bash-tool-mapping.sh" '
    {
      _agent_workspace: $tag,
      hooks: [
        {type: "command", command: $log,   timeout: 5},
        {type: "command", command: $block, timeout: 5}
      ]
    }')"

SESSION_HOOKS_JSON="$(jq -n --arg tag "$TAG" --arg cmd "$SESSION_HOOK_LINK" '
    {
      _agent_workspace: $tag,
      hooks: [{type: "command", command: $cmd, timeout: 10}]
    }')"

read_settings | jq \
    --arg tag "$TAG" \
    --argjson force "$([[ "$FORCE" == true ]] && echo true || echo false)" \
    --argjson pre "$PRE_HOOKS_JSON" \
    --argjson ses "$SESSION_HOOKS_JSON" \
    --argjson rules "$(allow_rules_json)" '
    .hooks //= {}
    | .hooks.PreToolUse //= []
    | .hooks.SessionStart //= []
    # Drop the previous generation of agent_workspace entries, keeping the
    # user'"'"'s own (which carry no marker at all).
    #
    # Normally that means entries tagged with THIS checkout. Under --force we
    # are deliberately taking the tier over from another checkout, so every
    # marker-carrying entry goes regardless of which checkout tagged it --
    # otherwise the takeover leaves the old checkout'"'"'s SessionStart and
    # PreToolUse entries in place beside ours, both layers get injected into
    # every session, and --check reports drift immediately after a --force
    # that exited 0 claiming success.
    | .hooks.PreToolUse   |= map(select(($force and (._agent_workspace // "") != "") | not) | select((._agent_workspace // "") != $tag))
    | .hooks.SessionStart |= map(select(($force and (._agent_workspace // "") != "") | not) | select((._agent_workspace // "") != $tag))
    | .hooks.PreToolUse   += [$pre]
    | .hooks.SessionStart += [$ses]
    | .permissions //= {}
    | .permissions.allow //= []
    | .permissions.allow = ((.permissions.allow + $rules) | unique)
' | write_settings || { echo "ERROR: failed to write $SETTINGS" >&2; exit 1; }
echo "  merged hook entries and $(allow_rules_json | jq 'length') allow-rules into $SETTINGS"

# 5. skills
sync_skills || true

echo ""
echo "agent_workspace user tier installed from $WS_ROOT"
echo "Verify with: .agent/scripts/user_tier_install.sh --check"
exit 0
