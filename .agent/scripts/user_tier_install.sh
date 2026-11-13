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
#   3. One PreToolUse entry, by absolute path, for
#      .claude/hooks/log-tool-use.sh. It carries the registry_require_root
#      guard, so it is inert outside the workspace checkout and outside every
#      registered root. (The tool-mapping hook was promoted alongside it and
#      retired by #328; --check reports a leftover command for it as drift.)
#   4. Permission allow-rules for the promoted scripts in
#      .agent/user_tier_scripts.txt, by absolute path.
#   5. The agent-workspace Claude Code plugin (ADR-0018), enabled ONCE, at
#      user scope, for the whole machine: the workspace skills whose
#      SKILL.md declares `session_scope: project` or `both`, namespaced as
#      /agent-workspace:<skill> so a project's own same-named skill keeps
#      its bare name (#345). Install runs `claude plugin marketplace add
#      <this checkout> --scope user` and `claude plugin install
#      agent-workspace@agent-workspace --scope user`, from a throwaway
#      directory in no git repository, only when the CLI's records do not
#      already show it: ~/.claude/settings.json then holds
#      `enabledPlugins["agent-workspace@agent-workspace"] = true` and
#      `extraKnownMarketplaces["agent-workspace"]` with this checkout as its
#      directory source, and the CLI's machine-level record
#      (plugins/known_marketplaces.json) names this checkout, and the CLI's
#      record of installs (plugins/installed_plugins.json) lists a
#      user-scope install. Repointing another checkout's declaration
#      re-runs the install. The settings and the machine-level record are
#      read back after the calls; a run that finds all three current makes
#      no CLI call.
#      Nothing is written into any project root. The workspace checkout's
#      own tracked .claude/settings.json sets the plugin to false, so a
#      session at the checkout's root or in a worktree of it lists each
#      shipped skill once, under its bare name (the plugin's source IS this
#      checkout's .claude/skills). A session started in a subdirectory of
#      the checkout -- a plain subdirectory, or a registered root inside its
#      tree with no .git of its own -- lists each shipped skill under both
#      names, bare and /agent-workspace:<skill>; both run the same skill
#      (live suite, 2026-11-12; accepted by the owner that day). A project
#      that does not want the plugin sets it to false in its own settings
#      (narrower scope wins); the installer has no per-root switch. Without
#      the `claude` CLI on PATH the enable is skipped with a note (a
#      Codex-only machine has no plugins to enable).
#      Migration from the per-root generation, which enabled the plugin at
#      local scope in every registered root: install looks in the
#      registered roots, this checkout, and every root the CLI's own record
#      (plugins/installed_plugins.json) lists as a local-scope install of
#      the plugin, for a .claude/settings.local.json entry from this
#      checkout, and removes it with `claude plugin uninstall --scope local`
#      and `claude plugin marketplace remove --scope local`, run from that
#      root, AFTER the user-scope enable. A local `false` is left (a
#      deliberate opt-out), as is another checkout's entry (a note). The
#      CLI is run only where the root is its own git toplevel (not a linked
#      worktree) or is in no git repository: from a plain subdirectory of a
#      repository the CLI's local scope writes the toplevel's file, and from
#      a linked worktree where it writes is not established. An entry
#      anywhere else, a root not on disk, a file that is not JSON, and a
#      root in the CLI's record that is no longer on disk each get a note
#      with the removal by hand, on every run, never an error. After
#      migrating, the user-scope entries and the machine-level record are
#      read back, and their loss is an error.
#   (Before ADR-0018, item 5 was a symlink per skill in ~/.claude/skills/.
#   Those links were global to the machine and shadowed a project's own
#   same-named skills. Install removes any left behind; --check reports them.)
#
# Hook commands in ~/.claude/settings.json are recognised by their path, one
# command at a time, because the `claude plugin` commands rewrite that file
# and drop any key they do not know (#394). One function, classify_hooks,
# decides for --check, install, --force and --uninstall. A command is
# classified only when it is exactly a command this script writes or wrote
# (the SessionStart link, or this checkout's path -- lexical or physical --
# + /.claude/hooks/<name>), exactly <marker>/.claude/hooks/<name> inside an
# entry marked with <marker> (below), or when
# the whole command string is a literal absolute path -- it starts with `/`
# and holds no whitespace, quote, `$`, `~`, backslash, glob character or
# shell operator -- of the form <dir>/.claude/hooks/<name>, <name> a hook
# this script writes or has retired (INSTALLER_HOOK_NAMES,
# RETIRED_HOOK_NAMES). Such a command is:
#   - ours: <dir> is this checkout (its physical path too, so a symlinked
#     alias counts);
#   - another checkout's: <dir> holds .agent/user_tier_scripts.txt (the test
#     foreign_skill_link uses);
#   - dead, left by a checkout since moved or deleted: <dir> itself is not
#     on disk (a <dir> that exists and lacks only the file is someone's
#     project, not a dead checkout).
# What a mode removes is only what it can attribute to this installer: ours,
# and a dead command that sits in an entry marked with that command's own
# checkout (below). Any other dead command -- unmarked, or in an entry
# marked with another checkout -- is not proof of anything -- a drive that is not
# mounted looks the same -- so it is reported, by --check as drift and by
# install as a note, each naming the command and the remedy, and removed
# only by --force. --force also removes another checkout's commands. Every
# command a run removes that it does not write back is printed, with the
# path of the settings.json backup taken before the change.
# Anything else -- a quoted or variable path, an interpreter prefix, a
# trailing argument, `~` or a relative path, any other name -- is the
# user's, and is never removed, reported or rewritten, whatever it looks
# like. Only the classified commands are removed from an entry; the user's
# own commands in the same entry, and its other keys, stay, and an entry is
# dropped only when no command is left in it. Earlier generations tagged
# each entry "_agent_workspace": "<checkout>". That marker is no longer
# written, but it is still read where an entry carries it: a classified
# command under the marked checkout is that checkout's. Install and
# --uninstall drop this checkout's marker from every entry, and --force
# every marker, whether or not a command was removed from the entry.
#
# Modes:
#   (default)            install or repair; idempotent, safe to re-run
#   --check              report drift. Exits 0 with a one-line note when the
#                        user tier is simply not installed -- `make validate`
#                        must stay green on a machine that never installed
#                        it. Exits 1 on drift when it IS installed.
#   --check --require    also exit 1 when it is not installed, for a machine
#                        that expects it.
#   --uninstall          remove this checkout's hook commands and
#                        allow-rules, the plugin at user scope when this
#                        checkout declared it there, and every per-root
#                        entry install would migrate (another checkout's
#                        is left alone). An entry it cannot remove -- no
#                        CLI, or a root the CLI is not run in -- is an
#                        error naming the removal by hand.
#   --list-skills        print the skills the plugin exposes (session_scope
#                        project|both), one per line.
#   --generate-plugin-manifest
#                        rewrite the `skills` array of .claude-plugin/
#                        plugin.json from that list (what `make
#                        generate-user-tier-skills` runs). Touches only the
#                        tracked manifest in this checkout.
#
# Exit codes: 0 ok; 1 drift / failure; 2 usage; 3 missing dependency (jq).
#
# Scope: this script writes inside $HOME/.claude (and, only through the
# `claude plugin` CLI, the CLI's own user settings and plugin bookkeeping
# under ~/.claude/plugins/). The one write outside it is the migration of
# item 5: the CLI removing a legacy entry from a root's gitignored
# .claude/settings.local.json, never an edit by this script. It never edits
# the tracked .claude/settings.json in the checkout, which stays exactly as
# it is (Ask-First).
#
# Test seam: AGENT_WORKSPACE_CLAUDE_BIN names the claude binary (default
# `claude`), so the test suite can point it at a stub that records argv and
# never runs the real CLI.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# The physical form, for every comparison against a path git or the claude
# CLI reports (both resolve symlinks) and for the marketplace source itself.
WS_PHYS="$(cd "$WS_ROOT" && pwd -P)"
MANIFEST="$WS_ROOT/.agent/user_tier_scripts.txt"
PLUGIN_MANIFEST="$WS_ROOT/.claude-plugin/plugin.json"

# shellcheck source=_project_registry.sh
source "$SCRIPT_DIR/_project_registry.sh"

PLUGIN_NAME="agent-workspace"
MARKETPLACE_NAME="agent-workspace"
PLUGIN_ID="$PLUGIN_NAME@$MARKETPLACE_NAME"
CLAUDE_BIN="${AGENT_WORKSPACE_CLAUDE_BIN:-claude}"

CLAUDE_DIR="${HOME}/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
ROOT_FILE="$CLAUDE_DIR/agent-workspace-root"
# The allow-rules the installed generation wrote, so uninstall and --check can
# recognise rules this checkout owns even after the manifest changes.
RULES_FILE="$CLAUDE_DIR/agent-workspace-rules.json"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SKILLS_DIR="$CLAUDE_DIR/skills"
# The claude CLI's own plugin records (ADR-0018): the user-scope settings
# its `--scope user` calls write, its machine-level marketplace record, and
# its record of where the plugin is installed. Read only, never written
# here; only the CLI's own calls change them. They live under the CLI's
# configuration home: CLAUDE_CONFIG_DIR when set, else ~/.claude.
# (Observed with claude 2.1.282: with CLAUDE_CONFIG_DIR set, `marketplace
# add` writes $CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json and leaves
# ~/.claude alone.) Reading ~/.claude there would see stale records, and
# every read-back would fail.
CLI_HOME="${CLAUDE_CONFIG_DIR:-$CLAUDE_DIR}"
CLI_SETTINGS="$CLI_HOME/settings.json"
KNOWN_MARKETPLACES="$CLI_HOME/plugins/known_marketplaces.json"
INSTALLED_PLUGINS="$CLI_HOME/plugins/installed_plugins.json"
SESSION_HOOK_LINK="$HOOKS_DIR/agent-workspace-session-start.sh"
SESSION_HOOK_TARGET="$WS_ROOT/.claude/hooks/session_start_project_layer.sh"

# The "_agent_workspace" marker value an earlier generation wrote for this
# checkout. Read where present, never written (header).
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
usage_line() {
    echo "usage: user_tier_install.sh [--force] | --check [--require] | --uninstall | --list-skills | --generate-plugin-manifest" >&2
}
while [[ $# -gt 0 ]]; do
    arg="$1"
    shift
    case "$arg" in
        --check)       set_mode check ;;
        --require)     REQUIRE=true ;;
        --force)       FORCE=true ;;
        --uninstall)   set_mode uninstall ;;
        --list-skills) set_mode list-skills ;;
        --generate-plugin-manifest) set_mode generate-plugin-manifest ;;
        -h|--help)
            sed -n '2,/^set -uo pipefail/p' "${BASH_SOURCE[0]}" | sed '$d'
            exit 0
            ;;
        *)
            usage_line
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
    install|check|uninstall|generate-plugin-manifest)
        if ! command -v jq >/dev/null 2>&1; then
            if [[ "$MODE" == "check" ]]; then
                echo "agent_workspace user tier: jq not installed -- cannot check (install jq to enable this check)"
                exit 0
            fi
            echo "ERROR: jq is required (settings.json merge, plugin manifest)" >&2
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
    done | LC_ALL=C sort
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

# The hooks this script registers by checkout path, and the ones an earlier
# generation registered and #328 retired (checked across the script's
# history: no generation wrote any other). Together they are the only names
# classify_hooks recognises.
INSTALLER_HOOK_NAMES=(log-tool-use.sh)
RETIRED_HOOK_NAMES=(block-bash-tool-mapping.sh)

hook_commands() {
    local n
    for n in "${INSTALLER_HOOK_NAMES[@]}"; do
        echo "$WS_ROOT/.claude/hooks/$n"
    done
}

# Shared jq definition: the hook entries of a settings file, type-guarded,
# so an event whose value is not an array (or an entry that is not an
# object) is skipped rather than an error that empties every list built on
# it.
HOOK_ENTRIES_JQ='def hook_entries: .hooks // {} | objects | .[] | arrays | .[] | objects;
    def entry_commands: .hooks | arrays | .[] | objects | .command | strings;'

# Any character that makes a command string something other than a literal
# path: whitespace, a quote, `$`, `~`, a backslash, a glob character or a
# shell operator.
NOT_LITERAL_RE='[][[:space:]'"'"'"$~\;&|<>()`*?{}!#]'

# Whose is a checkout-shaped <dir>? self: this checkout (lexical or
# physical); foreign: it holds .agent/user_tier_scripts.txt (another
# checkout); dead: <dir> itself is not on disk (a checkout since moved or
# deleted -- or an unmounted drive); named: it exists and is none of these.
dir_class() {  # <dir>
    local phys=""
    [[ -d "$1" ]] && phys="$(cd "$1" 2>/dev/null && pwd -P)"
    if [[ "$1" == "$WS_ROOT" || "$1" == "$WS_PHYS" || "$phys" == "$WS_PHYS" ]]; then
        echo self
    elif [[ -f "$1/.agent/user_tier_scripts.txt" ]]; then
        echo foreign
    elif [[ ! -e "$1" ]]; then
        echo dead
    else
        echo named
    fi
}

# THE rule that decides whose a hook command is (header; #394). Every mode
# that reports or removes a hook command -- --check, install, --force,
# --uninstall -- classifies through this function and nothing else. Prints
# one JSON object, keyed by command, for the commands it classifies:
#   {"<command>": {"class": "self"|"foreign"|"dead"|"named"|"marked",
#                  "dir": "<dir>", "as": <dir_class of a marked <dir>>}}
#   self:    exactly a command this script writes or wrote -- the
#            SessionStart link, or $WS_ROOT or $WS_PHYS +
#            /.claude/hooks/<name> -- or a literal <dir>/.claude/hooks/<name>
#            with <dir> this checkout (dir_class);
#   foreign, dead, named: a literal <dir>/.claude/hooks/<name>, by
#            dir_class. A named one is the user's, unless an entry marked
#            with <dir> holds it (owner, below);
#   marked:  exactly <marker>/.claude/hooks/<name> for a marker some entry
#            carries, though not literal (a space in the path, say). Only an
#            entry marked with <dir> attributes it ("as" says to whom);
#            anywhere else it is the user's.
# A command not in the object is the user's. <name> must be one of
# INSTALLER_HOOK_NAMES or RETIRED_HOOK_NAMES. A jq failure is an error
# (return 1, a message on stderr), never an empty object: an empty one
# would read as "nothing to remove" and let a run report current.
classify_hooks() {  # <settings json>
    local enc menc b cmd dir name n w m class known as
    local -a out=() written=("$SESSION_HOOK_LINK")
    local -A marked=()
    for n in "${INSTALLER_HOOK_NAMES[@]}" "${RETIRED_HOOK_NAMES[@]}"; do
        written+=("$WS_ROOT/.claude/hooks/$n" "$WS_PHYS/.claude/hooks/$n")
    done
    enc="$(jq -r "$HOOK_ENTRIES_JQ"'[hook_entries | entry_commands] | unique | .[] | @base64' <<< "$1")" \
        && menc="$(jq -r "$HOOK_ENTRIES_JQ"'[hook_entries | ._agent_workspace | strings | select(. != "")] | unique | .[] | @base64' <<< "$1")" || {
        echo "ERROR: could not read the hook commands in $SETTINGS (jq failed) -- nothing changed" >&2
        return 1
    }
    while IFS= read -r b; do
        [[ -z "$b" ]] && continue
        m="$(base64 -d <<< "$b"; printf x)" || return 1
        m="${m%x}"
        for n in "${INSTALLER_HOOK_NAMES[@]}" "${RETIRED_HOOK_NAMES[@]}"; do
            marked["$m/.claude/hooks/$n"]="$m"
        done
    done <<< "$menc"
    while IFS= read -r b; do
        [[ -z "$b" ]] && continue
        # The x keeps a trailing newline in the command from being stripped.
        cmd="$(base64 -d <<< "$b"; printf x)" || return 1
        cmd="${cmd%x}"
        class=""
        dir=""
        as=""
        for w in "${written[@]}"; do
            [[ "$cmd" == "$w" ]] && class=self
        done
        if [[ -n "$class" ]]; then
            :
        elif [[ "$cmd" == /* ]] && ! [[ "$cmd" =~ $NOT_LITERAL_RE ]] \
             && [[ "$cmd" =~ ^(/.*)/\.claude/hooks/([^/]+)$ ]]; then
            dir="${BASH_REMATCH[1]}"
            name="${BASH_REMATCH[2]}"
            known=false
            for n in "${INSTALLER_HOOK_NAMES[@]}" "${RETIRED_HOOK_NAMES[@]}"; do
                [[ "$name" == "$n" ]] && known=true
            done
            [[ "$known" == true ]] && class="$(dir_class "$dir")"
        elif [[ -n "${marked["$cmd"]+set}" ]]; then
            dir="${marked["$cmd"]}"
            class=marked
            as="$(dir_class "$dir")"
        fi
        [[ -n "$class" ]] || continue
        out+=("$(jq -cn --arg c "$cmd" --arg k "$class" --arg d "$dir" --arg a "$as" '{($c): {class: $k, dir: $d, as: $a}}')") || return 1
    done <<< "$enc"
    if ((${#out[@]})); then
        printf '%s\n' "${out[@]}" | jq -cs 'add'
    else
        echo '{}'
    fi || { echo "ERROR: could not classify the hook commands in $SETTINGS (jq failed) -- nothing changed" >&2; return 1; }
}

# jq definitions shared by --check, install and --uninstall, on top of
# HOOK_ENTRIES_JQ. With $cls (from classify_hooks), $tag, $force and $dead
# bound:
#   owner($m): whose is the command (.) in an entry whose marker is $m (""
#     when unmarked)? "self", "foreign", "dead", or null for the user's. A
#     "named" or "marked" command is the marked checkout's when its <dir> is
#     the marker, and the user's anywhere else.
#   attributed($m): is the dead command (.) in an entry marked with its own
#     checkout (its <dir> is the marker)? Only then is it this installer's.
#   remove($m): ours; a dead one when $dead (install, --force) and either
#     attributed or under --force (any other is only reported: header);
#     another checkout's under --force.
#   prune: remove those commands from each entry of a hook event's array,
#     keeping the entry's other commands and keys, and dropping an entry
#     only when no command is left. An entry that loses a command drops its
#     marker. Every entry marked with this checkout drops the marker, and
#     under --force every marked entry does, whether or not a command was
#     removed: otherwise --check reports the marker for good and no run
#     clears it. An unmarked entry that loses nothing is left exactly as it
#     is.
PRUNE_JQ_DEFS="$HOOK_ENTRIES_JQ"'
    def owner($m):
        ($cls[.] // null) as $k
        | if $k == null then null
          elif $k.class == "named" then
              (if ($m | type) == "string" and $m != "" and $k.dir == $m
               then (if $m == $tag then "self" else "foreign" end) else null end)
          elif $k.class == "marked" then
              (if ($m | type) == "string" and $m != "" and $k.dir == $m
               then (if $k.as == "self" or $k.as == "dead" then $k.as else "foreign" end) else null end)
          else $k.class end;
    def marked($m): ($m | type) == "string" and $m != "";
    def attributed($m): marked($m) and ($cls[.] // {}).dir == $m;
    def remove($m):
        owner($m) as $o
        | $o == "self" or ($o == "dead" and $dead and (attributed($m) or $force))
          or ($o == "foreign" and $force);
    def unmark($m):
        if $m != "" and ($m == $tag or $force) then del(._agent_workspace) else . end;
    def prune:
        map(
            (._agent_workspace // "") as $m
            | if any(.hooks[]?; (.command? | strings) | remove($m))
              then (.hooks |= map(select(((.command? | strings) // "") as $c | ($c != "" and ($c | remove($m))) | not)))
                   | del(._agent_workspace)
                   | select((.hooks // []) | length > 0)
              else unmark($m) end);
'

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

# The hook events install adds an entry to must hold an array, or nothing:
# placing our entry in any other value would replace it, and drop whatever
# it held. Prints one line per such value; nothing when the shape is fine.
hook_shape_errors() {  # <settings json>
    jq -r '
        if .hooks == null then empty
        elif (.hooks | type) != "object" then "\"hooks\" is \(.hooks | type), not an object"
        else .hooks | to_entries[]
             | select(.key == "PreToolUse" or .key == "SessionStart")
             | select(.value != null and (.value | type) != "array")
             | "\"hooks.\(.key)\" is \(.value | type), not an array"
        end' <<< "$1"
}

# A timestamped copy beside the original, before any rewrite. Cheap, and the
# difference between a bad merge being an annoyance and being a data loss.
BACKUP_KEEP=5
BACKUP_PATH=""   # the newest backup this run took, for the messages that cite it
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
    BACKUP_PATH="$dest"
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
        # A failed rename is a failed write: callers stop on it.
        mv "$staged" "$real" || { rm -f "$staged"; return 1; }
        return 0
    fi
    mv "$tmp" "$SETTINGS" || { rm -f "$tmp"; return 1; }
}

# CLAUDE_CONFIG_DIR moves where the CLI reads its settings from, but the
# rest of the user tier (the root file, hook entries, allow-rules) is
# written to ~/.claude, where such a CLI does not look. Said, not hidden.
config_dir_note() {
    local a b
    [[ -n "${CLAUDE_CONFIG_DIR:-}" ]] || return 0
    a="$(cd "$CLAUDE_CONFIG_DIR" 2>/dev/null && pwd -P)" || a="$CLAUDE_CONFIG_DIR"
    b="$(cd "$CLAUDE_DIR" 2>/dev/null && pwd -P)" || b="$CLAUDE_DIR"
    [[ "$a" != "$b" ]] || return 0
    echo "  NOTE: CLAUDE_CONFIG_DIR is set ($CLAUDE_CONFIG_DIR): the plugin's user-scope entries and machine-level record are read there, but the rest of the user tier lives in $CLAUDE_DIR, which a claude CLI with CLAUDE_CONFIG_DIR set does not read"
}

# ------------------------------------------------------------- list mode ---
if [[ "$MODE" == "list-skills" ]]; then
    selected_skills
    exit 0
fi

# The plugin's `skills` array, generated from session_scope frontmatter so
# the manifest is never hand-maintained. An array of per-skill paths, not the
# whole .claude/skills directory: workspace-scoped skills call workspace
# scripts cwd-relative and would fail (or run a project's same-named script)
# from a project cwd, and the generated /make_* skills are gitignored
# per-machine files that must not ship.
if [[ "$MODE" == "generate-plugin-manifest" ]]; then
    if [[ ! -f "$PLUGIN_MANIFEST" ]] || ! jq -e . "$PLUGIN_MANIFEST" >/dev/null 2>&1; then
        echo "ERROR: $PLUGIN_MANIFEST is missing or not valid JSON" >&2
        exit 1
    fi
    skills_json="$(selected_skills | sed 's|^|./.claude/skills/|' | jq -R . | jq -s .)"
    tmp="$(mktemp "$PLUGIN_MANIFEST.XXXXXX")" || exit 1
    # Copied back over the original rather than renamed onto it: mktemp's
    # 0600 mode would otherwise replace the tracked file's.
    if jq --argjson s "$skills_json" '.skills = $s' "$PLUGIN_MANIFEST" > "$tmp" \
       && cat "$tmp" > "$PLUGIN_MANIFEST"; then
        rm -f "$tmp"
    else
        rm -f "$tmp"
        echo "ERROR: could not rewrite $PLUGIN_MANIFEST" >&2
        exit 1
    fi
    echo "Wrote $(jq length <<< "$skills_json") skill path(s) to $PLUGIN_MANIFEST"
    exit 0
fi

# ------------------------------------------------- legacy skill symlinks ---
# Before ADR-0018 the user tier shipped skills as symlinks in
# ~/.claude/skills/. They are global to the machine and shadow a project's
# own same-named skills (#345), so the mechanism is retired: install removes
# every such link, --check reports any left behind, and nothing creates them.
#
# Does <link> resolve into an agent_workspace checkout OTHER than this one?
# Recognised by the manifest file that only a workspace checkout has.
foreign_skill_link() {  # <link path>
    local tgt root
    tgt="$(readlink -f "$1" 2>/dev/null)" || return 1
    [[ -n "$tgt" ]] || return 1
    # <checkout>/.claude/skills/<name>: lexical, so a dangling link whose
    # skill was since deleted is still recognised.
    [[ "$(basename "$(dirname "$tgt")")" == "skills" ]] || return 1
    root="$(dirname "$(dirname "$(dirname "$tgt")")")"
    [[ -f "$root/.agent/user_tier_scripts.txt" ]] || return 1
    [[ "$root" != "$WS_PHYS" && "$root" != "$WS_ROOT" ]] || return 1
    return 0
}

# Does <link> point into THIS checkout's skills?
own_skill_link() {  # <link path>
    local raw tgt
    raw="$(readlink "$1" 2>/dev/null)" || return 1
    [[ "$raw" == "$WS_ROOT/.claude/skills/"* || "$raw" == "$WS_PHYS/.claude/skills/"* ]] && return 0
    tgt="$(readlink -f "$1" 2>/dev/null)" || return 1
    [[ "$tgt" == "$WS_PHYS/.claude/skills/"* ]]
}

# Every legacy workspace skill symlink, this checkout's or another's.
legacy_skill_links() {
    local link
    for link in "$SKILLS_DIR"/*; do
        [[ -L "$link" ]] || continue
        if own_skill_link "$link" || foreign_skill_link "$link"; then
            printf '%s\n' "$link"
        fi
    done
}

# ----------------------------------------------------------- the plugin ---
have_claude() { command -v "$CLAUDE_BIN" >/dev/null 2>&1; }

# Every `claude plugin` call, stdin closed: a CLI version that stops to ask
# (a trust or confirmation prompt) then fails instead of hanging the
# installer on a read nobody will answer.
claude_plugin() { "$CLAUDE_BIN" plugin "$@" </dev/null; }

# Is <path> this checkout, lexically or as its `pwd -P` form?
is_this_checkout() {  # <path>
    local phys
    [[ "$1" == "$WS_ROOT" || "$1" == "$WS_PHYS" ]] && return 0
    phys="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
    [[ "$phys" == "$WS_PHYS" ]]
}

# Does the machine-level record name THIS checkout? Anything else -- another
# checkout, or no entry at all -- may leave sessions without this
# checkout's skills: the per-root live suite (claude 2.1.282) saw an absent
# record leave every enabled root without the plugin.
machine_record_ours() {
    local src
    src="$(machine_record_source)"
    [[ -n "$src" ]] && is_this_checkout "$src"
}

# What the machine-level record says, for a message.
machine_record_what() {
    local src
    src="$(machine_record_source)"
    if [[ -z "$src" ]]; then
        echo "has no entry for it"
    elif [[ -d "$src" ]]; then
        echo "names $src"
    else
        echo "names $src (not on disk)"
    fi
}

# The source path the machine-level record gives the marketplace, or empty
# (no file, no entry, no `path` field, or a file that is not JSON).
machine_record_source() {
    [[ -f "$KNOWN_MARKETPLACES" ]] || return 0
    jq -r --arg m "$MARKETPLACE_NAME" '.[$m].source.path? // empty' "$KNOWN_MARKETPLACES" 2>/dev/null || true
}

# ------------------------------------------------ plugin, user scope ---
# The plugin's state in the CLI's user settings ($CLI_SETTINGS):
#   ours         enabled, and the marketplace is declared from this checkout
#   foreign      the marketplace is declared from ANOTHER checkout that is
#                on disk (enabled or not)
#   partial      anything else that names it: enabled with no declaration,
#                declared from this checkout but not enabled, or declared
#                from a path no longer on disk
#   absent       neither
#   unparseable  the file exists and is not JSON
user_plugin_source() {
    [[ -f "$CLI_SETTINGS" ]] || return 0
    jq -r --arg m "$MARKETPLACE_NAME" '.extraKnownMarketplaces[$m].source.path? // empty' "$CLI_SETTINGS" 2>/dev/null || true
}
user_scope_state() {
    local enabled src
    [[ -f "$CLI_SETTINGS" ]] || { echo absent; return 0; }
    jq -e . "$CLI_SETTINGS" >/dev/null 2>&1 || { echo unparseable; return 0; }
    enabled="$(jq -r --arg id "$PLUGIN_ID" '.enabledPlugins[$id]? // false | tostring' "$CLI_SETTINGS" 2>/dev/null)"
    src="$(user_plugin_source)"
    if [[ -n "$src" ]] && ! is_this_checkout "$src" && [[ -d "$src" ]]; then
        echo foreign
    elif [[ "$enabled" == true && -n "$src" ]] && is_this_checkout "$src"; then
        echo ours
    elif [[ "$enabled" == true || -n "$src" ]]; then
        echo partial
    else
        echo absent
    fi
}

# Run one `claude plugin ... --scope user` call from a throwaway directory
# in no git repository, so no local or project settings of any directory
# can be what the CLI reads or writes. Returns the CLI's status, or 1 with
# the reason on stderr when no such directory can be made.
cli_user() {  # <claude plugin args...>
    local scratch rc=0
    scratch="$(mktemp -d -t agent-workspace-plugin.XXXXXX)" || {
        echo "  ERROR: could not create a scratch directory to run \`claude plugin $*\` from" >&2
        return 1
    }
    # An interrupt while the CLI runs must not leave the directory behind
    # (its path is fixed into the trap now: the local is gone by then).
    # shellcheck disable=SC2064  # expand $scratch now, on purpose
    trap "rm -rf $(printf '%q' "$scratch"); exit 130" INT
    # shellcheck disable=SC2064
    trap "rm -rf $(printf '%q' "$scratch"); exit 143" TERM
    if git -C "$scratch" rev-parse --show-toplevel >/dev/null 2>&1; then
        rm -rf "$scratch"
        trap - INT TERM
        echo "  ERROR: the scratch directory $scratch is inside a git repository -- not running the claude CLI there (point TMPDIR at a directory outside any git repository)" >&2
        return 1
    fi
    (cd "$scratch" && claude_plugin "$@" >/dev/null) || rc=$?
    rm -rf "$scratch"
    trap - INT TERM
    return "$rc"
}

# Enable the plugin at user scope from this checkout: `marketplace add`
# unless the declaration and the machine-level record already name this
# checkout; `install` unless it is already enabled, the CLI's record lists
# a user-scope install, and the declaration was this checkout's before
# this call; then both read back. A second user-scope `marketplace add` of
# the same name from another path repoints both records (checked on claude
# 2.1.322), so another checkout's declaration needs no separate takeover.
# A repoint re-runs `install` because the enable and the CLI's install
# record and cache are the other checkout's. Whether the real CLI's
# `install` of a plugin already enabled at user scope refreshes that
# record and cache from the repointed marketplace, or exits non-zero, is
# not verified (no live case covers it); a failure is reported as one.
# Returns 1, with the reason on stderr.
enable_user_scope() {
    local src repointed=false
    src="$(user_plugin_source)"
    [[ -n "$src" ]] && ! is_this_checkout "$src" && repointed=true
    if ! { [[ -n "$src" ]] && is_this_checkout "$src" && machine_record_ours; }; then
        cli_user marketplace add "$WS_PHYS" --scope user || {
            echo "  ERROR: \`claude plugin marketplace add $WS_PHYS --scope user\` failed" >&2
            return 1
        }
    fi
    if [[ "$repointed" == true || "$(user_install_record)" == absent ]] \
        || ! jq -e --arg id "$PLUGIN_ID" '.enabledPlugins[$id]? == true' "$CLI_SETTINGS" >/dev/null 2>&1; then
        cli_user install "$PLUGIN_ID" --scope user || {
            echo "  ERROR: \`claude plugin install $PLUGIN_ID --scope user\` failed" >&2
            return 1
        }
    fi
    user_scope_readback "the claude CLI reported success"
}

# The read-back after any CLI call that may change the user-scope entries
# or the machine-level record: both must name this checkout.
user_scope_readback() {  # <what came before, for the message>
    if [[ "$(user_scope_state)" != ours ]]; then
        echo "  ERROR: $1, but $CLI_SETTINGS does not show $PLUGIN_ID enabled with the $MARKETPLACE_NAME marketplace declared from $WS_PHYS" >&2
        return 1
    fi
    if ! machine_record_ours; then
        echo "  ERROR: $1, but the claude CLI's machine-level record of the $MARKETPLACE_NAME marketplace ($KNOWN_MARKETPLACES) $(machine_record_what), not this checkout" >&2
        return 1
    fi
}

# ------------------------------------------------ legacy per-root entries ---
# The per-root generation enabled the plugin at local scope in each
# registered root. Where to look for what it left, one line per place,
# "<kind>\t<label>\t<path>": every registered root (kind registry), this
# checkout (checkout), and every directory the CLI's own record lists as a
# local-scope install of the plugin (cli-record), so a root unregistered
# by hand, or moved, is still found. Each place once, by its physical path
# when it is on disk. A registry that does not parse returns 2 (the parser
# has named the line on stderr). A CLI record that does not parse adds no
# place; every mode reports it (installed_plugins_unreadable).
legacy_places() {
    local entries name _type path _fields parse_rc=0 p key
    local -A seen=()
    entries="$(registry_entries_full "$WS_ROOT")" || parse_rc=$?
    {
        while IFS=$'\t' read -r name _type path _fields; do
            [[ -n "$name" ]] && printf 'registry\tregistered root %s\t%s\n' "$name" "$path"
        done <<< "$entries"
        printf 'checkout\tthe workspace checkout\t%s\n' "$WS_ROOT"
        if [[ -f "$INSTALLED_PLUGINS" ]]; then
            jq -r --arg id "$PLUGIN_ID" '
                (.plugins? // {})[$id]? // [] | if type == "array" then .[] else empty end
                | objects | select(.scope? == "local") | (.projectPath? // empty) | strings' \
                "$INSTALLED_PLUGINS" 2>/dev/null | while IFS= read -r p; do
                    [[ -n "$p" ]] && printf 'cli-record\ta root in the claude CLI'"'"'s record\t%s\n' "$p"
                done
        fi
    } | while IFS=$'\t' read -r _type name path; do
        key="$(cd "$path" 2>/dev/null && pwd -P)" || key="$path"
        [[ -n "${seen[$key]:-}" ]] && continue
        seen[$key]=1
        printf '%s\t%s\t%s\n' "$_type" "$name" "$path"
    done
    return "$parse_rc"
}

# The legacy entry in <root>'s .claude/settings.local.json:
#   ours         this checkout's: enabled, and/or declared from this
#                checkout or from a path no longer on disk
#   off          the plugin set to false: a deliberate opt-out, left alone
#   foreign      declared from another checkout that is on disk
#   absent       no file, or nothing about the plugin in it
#   unparseable  the file exists and is not JSON
legacy_state() {  # <root>
    local f="$1/.claude/settings.local.json" enabled src
    [[ -f "$f" ]] || { echo absent; return 0; }
    jq -e . "$f" >/dev/null 2>&1 || { echo unparseable; return 0; }
    enabled="$(jq -r --arg id "$PLUGIN_ID" '.enabledPlugins[$id]? | tostring' "$f" 2>/dev/null)"
    src="$(jq -r --arg m "$MARKETPLACE_NAME" '.extraKnownMarketplaces[$m].source.path? // empty' "$f" 2>/dev/null)"
    if [[ "$enabled" == false ]]; then
        echo off
    elif [[ -n "$src" ]] && ! is_this_checkout "$src" && [[ -d "$src" ]]; then
        echo foreign
    elif [[ "$enabled" == true || -n "$src" ]]; then
        echo ours
    else
        echo absent
    fi
}

# Why the installer does not run the claude CLI in <root>, printed, with
# status 0; status 1 (nothing printed) when it may: <root> is its own git
# toplevel, not a linked worktree, or is in no git repository.
cli_refusal() {  # <root>
    local top top_phys root_phys gd cd
    top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
    top_phys="$(cd "$top" 2>/dev/null && pwd -P)"
    root_phys="$(cd "$1" 2>/dev/null && pwd -P)"
    if [[ "$top_phys" != "$root_phys" ]]; then
        echo "it is a plain directory inside the git repository $top, and the claude CLI's local scope from there writes that repository's settings, not this file"
        return 0
    fi
    gd="$(cd "$1" && git rev-parse --path-format=absolute --git-dir 2>/dev/null)" \
        && gd="$(cd "$gd" 2>/dev/null && pwd -P)"
    cd="$(cd "$1" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
        && cd="$(cd "$cd" 2>/dev/null && pwd -P)"
    if [[ -z "$gd" || -z "$cd" || "$gd" != "$cd" ]]; then
        echo "it is a linked git worktree, and where the claude CLI's local scope writes from one is not established (a write to the main repository's file could remove a deliberate local false there)"
        return 0
    fi
    return 1
}

# A left entry: a NOTE on stdout, or with <strict> an ERROR on stderr.
legacy_say() {  # <strict or empty> <message>
    if [[ "$1" == strict ]]; then echo "  ERROR: $2" >&2; else echo "  NOTE: $2"; fi
}
hand_removal() {  # <settings.local.json>
    echo "delete \"$PLUGIN_ID\" from enabledPlugins and \"$MARKETPLACE_NAME\" from extraKnownMarketplaces in $1"
}

# The CLI's record of installs ($INSTALLED_PLUGINS): absent, ok, or
# unparseable (the file exists and is not JSON).
installed_plugins_state() {
    [[ -f "$INSTALLED_PLUGINS" ]] || { echo absent; return 0; }
    if jq empty "$INSTALLED_PLUGINS" >/dev/null 2>&1; then echo ok; else echo unparseable; fi
}
# Does the CLI's record list a user-scope install of the plugin? present,
# absent (no file, or no such object), or unparseable. The record does not
# name the marketplace's source, so it cannot say which checkout the
# install came from; it only says the CLI ran an install at user scope.
user_install_record() {
    case "$(installed_plugins_state)" in
        absent) echo absent; return 0 ;;
        unparseable) echo unparseable; return 0 ;;
    esac
    if jq -e --arg id "$PLUGIN_ID" '
        [(.plugins? // {})[$id]? // [] | if type == "array" then .[] else empty end
         | objects | select(.scope? == "user")] | length > 0' "$INSTALLED_PLUGINS" >/dev/null 2>&1; then
        echo present
    else
        echo absent
    fi
}

# What an unparseable record costs, for a message: legacy_places reads the
# roots it lists, and drops them all when it cannot.
installed_plugins_unreadable() {
    echo "$INSTALLED_PLUGINS (the claude CLI's record of plugin installs) is not valid JSON, so the roots it lists as local-scope installs of $PLUGIN_ID, which may hold per-root entries, were not looked at (fix it: jq . \"$INSTALLED_PLUGINS\")"
}

# Does the CLI's record list a local-scope install of the plugin in <root>
# (by its path as given or its physical path)? 1 when it does not, or when
# the record is absent or cannot be read.
local_install_recorded() {  # <root>
    local phys
    [[ "$(installed_plugins_state)" == ok ]] || return 1
    phys="$(cd "$1" 2>/dev/null && pwd -P)" || phys="$1"
    jq -e --arg id "$PLUGIN_ID" --arg a "$1" --arg b "$phys" '
        [(.plugins? // {})[$id]? // [] | if type == "array" then .[] else empty end
         | objects | select(.scope? == "local" and (.projectPath? == $a or .projectPath? == $b))]
        | length > 0' "$INSTALLED_PLUGINS" >/dev/null 2>&1
}

# Move one place's legacy entry to user scope (install), or remove it
# (--uninstall: <strict> = strict). Prints what it did or why it left the
# entry. Returns 1 when the CLI ran and the entry is still there (except an
# entry the CLI did not write, which is a note), and, when strict, also
# when the entry is left for any other reason (no CLI, a root the CLI is
# not run in): --uninstall must not report a clean removal while
# a root still enables the plugin. Sets LEGACY_CLI_RAN=1 when it ran the CLI.
LEGACY_CLI_RAN=0
migrate_legacy_root() {  # <kind> <label> <root> [strict]
    local kind="$1" label="$2" root="$3" strict="${4:-}" f why rc=0 hand_written
    f="$root/.claude/settings.local.json"
    [[ "$strict" == strict ]] && rc=1
    if [[ ! -d "$root" ]]; then
        if [[ "$kind" == cli-record ]]; then
            echo "  NOTE: the claude CLI's record ($INSTALLED_PLUGINS) lists a local-scope install of $PLUGIN_ID in $root, which is not on disk -- the CLI cannot be run from there; remove it by hand: delete the object with \"scope\": \"local\" and \"projectPath\": \"$root\" from the \"$PLUGIN_ID\" array in $INSTALLED_PLUGINS"
        else
            echo "  NOTE: $label is not on disk ($root) -- a per-root $PLUGIN_NAME entry there, if any, is moved on a later run"
        fi
        return 0
    fi
    case "$(legacy_state "$root")" in
        absent|off) return 0 ;;
        unparseable)
            legacy_say "$strict" "$f is not valid JSON -- cannot tell whether it holds a per-root $PLUGIN_NAME entry; left as it is (fix it: jq . \"$f\")"
            return "$rc" ;;
        foreign)
            echo "  NOTE: $f declares the $PLUGIN_NAME marketplace from another checkout, $(jq -r --arg m "$MARKETPLACE_NAME" '.extraKnownMarketplaces[$m].source.path' "$f") -- left for that checkout's installer"
            return 0 ;;
    esac
    if why="$(cli_refusal "$root")"; then
        legacy_say "$strict" "$f ($label) holds a per-root $PLUGIN_NAME entry from this checkout, and the installer does not run the claude CLI there: $why -- remove it by hand: $(hand_removal "$f")"
        return "$rc"
    fi
    if ! have_claude; then
        legacy_say "$strict" "$f ($label) holds a per-root $PLUGIN_NAME entry from this checkout; the claude CLI is not on PATH -- remove it by hand: $(hand_removal "$f")"
        return "$rc"
    fi
    # A local true with no marketplace declaration beside it and no
    # local-scope install in the CLI's readable record was not left by the
    # CLI (written by hand, or by an edit outside it). Whether the real
    # CLI's `uninstall --scope local` removes such an entry is not verified
    # (no live case covers it), so it is tried, and when the entry is still
    # there afterwards it is a note naming the removal by hand, not an
    # error that would fail every install. Judged before the CLI runs: its
    # uninstall changes the record.
    hand_written=false
    if [[ -z "$(jq -r --arg m "$MARKETPLACE_NAME" '.extraKnownMarketplaces[$m].source.path? // empty' "$f" 2>/dev/null)" ]] \
        && [[ "$(installed_plugins_state)" != unparseable ]] && ! local_install_recorded "$root"; then
        hand_written=true
    fi
    LEGACY_CLI_RAN=1
    (cd "$root" && claude_plugin uninstall "$PLUGIN_ID" --scope local >/dev/null 2>&1) || true
    (cd "$root" && claude_plugin marketplace remove "$MARKETPLACE_NAME" --scope local >/dev/null 2>&1) || true
    case "$(legacy_state "$root")" in
        absent|off)
            if [[ "$strict" == strict ]]; then
                echo "  removed the per-root $PLUGIN_NAME entry from $f"
            else
                echo "  moved the $PLUGIN_NAME plugin in $root from its per-root entry to user scope"
            fi
            return 0 ;;
    esac
    if [[ "$hand_written" == true ]]; then
        legacy_say "$strict" "$f ($label) enables the $PLUGIN_NAME plugin with no marketplace declaration, and the claude CLI's record lists no local install there (written by hand?); the claude CLI ran in $root and did not remove it -- remove it by hand: $(hand_removal "$f")"
        return "$rc"
    fi
    echo "  ERROR: the claude CLI ran in $root, but $f still holds a per-root $PLUGIN_NAME entry from this checkout -- remove it by hand: $(hand_removal "$f")" >&2
    return 1
}

# Every place's legacy entry, as migrate_legacy_root treats each.
migrate_legacy_roots() {  # [strict]
    local kind label path rc=0
    while IFS=$'\t' read -r kind label path; do
        [[ -n "$path" ]] || continue
        migrate_legacy_root "$kind" "$label" "$path" "${1:-}" || rc=1
    done <<< "$LEGACY_PLACES"
    return "$rc"
}

# The places, read once for every mode below (--uninstall, --check,
# install). A registry that does not parse stops all three here, before
# anything is read or changed: the parser has already named the bad line
# on stderr, and a root it dropped could keep an entry nobody reports.
if ! LEGACY_PLACES="$(legacy_places)"; then
    echo "ERROR: $(registry_file "$WS_ROOT") does not parse (the line is named above) -- fix it and re-run; nothing was changed" >&2
    exit 1
fi

# Does the plugin show anywhere this installer would remove it from: at
# user scope (anything but another checkout's declaration), or as a
# per-root entry of this checkout's (or a file that cannot be read)?
# --uninstall's "nothing installed" must mean the plugin too: the user-tier
# files can be gone while the plugin is still enabled.
plugin_anywhere() {
    local _kind _label path
    case "$(user_scope_state)" in ours|partial|unparseable) return 0 ;; esac
    # Roots the CLI's record lists were not looked at.
    [[ "$(installed_plugins_state)" == unparseable ]] && return 0
    while IFS=$'\t' read -r _kind _label path; do
        [[ -n "$path" && -d "$path" ]] || continue
        case "$(legacy_state "$path")" in ours|unparseable) return 0 ;; esac
    done <<< "$LEGACY_PLACES"
    return 1
}

if [[ "$MODE" == "uninstall" ]]; then
    if [[ ! -e "$ROOT_FILE" && ! -e "$SESSION_HOOK_LINK" && ! -f "$SETTINGS" ]] && ! plugin_anywhere; then
        echo "agent_workspace user tier: nothing installed at $CLAUDE_DIR"
        exit 0
    fi
    # The same order as install: settings.json is read, classified, its
    # rewrite built and backed up, and written, before anything else is
    # removed. Any failure up to and including that write exits 1 with
    # everything as it was -- the root file, the rules record, the link and
    # the plugin still in place -- rather than a tier that reads as removed
    # while our hook commands still run from settings.json.
    if [[ -f "$SETTINGS" ]]; then
        require_parseable_settings || exit 1
        # This checkout's commands only (classify_hooks); another checkout's
        # and dead ones are install's to clear. The user's commands in the
        # same entry stay, and this checkout's marker goes from every entry.
        uninstall_settings="$(read_settings)"
        uninstall_cls="$(classify_hooks "$uninstall_settings")" || exit 1
        uninstall_rules="$(installed_rules_json)" || {
            echo "ERROR: could not read the allow-rules this checkout wrote ($RULES_FILE) -- nothing changed" >&2
            exit 1
        }
        uninstall_merged="$(jq --arg tag "$TAG" --argjson force false --argjson dead false \
            --argjson cls "$uninstall_cls" \
            --argjson rules "$uninstall_rules" "$PRUNE_JQ_DEFS"'
            .hooks //= {} |
            .hooks |= with_entries(
                .value |= (if type == "array" then prune else . end)
            ) |
            .hooks |= with_entries(select(.value | length > 0)) |
            if (.permissions.allow? // null) != null then
                .permissions.allow |= map(select(. as $a | ($rules | index($a)) == null))
            else . end
        ' <<< "$uninstall_settings")" || {
            echo "ERROR: could not build the rewrite of $SETTINGS (jq failed: see above) -- nothing changed" >&2
            exit 1
        }
        backup_settings || { echo "ERROR: could not back up $SETTINGS -- not proceeding; nothing changed" >&2; exit 1; }
        write_settings <<< "$uninstall_merged" || {
            echo "ERROR: failed to write $SETTINGS -- nothing changed (the backup above is a copy of it)" >&2
            exit 1
        }
        echo "  removed this checkout's hook commands and allow-rules from $SETTINGS"
    fi
    [[ -f "$ROOT_FILE" ]] && [[ "$(cat "$ROOT_FILE")" == "$WS_ROOT" ]] && rm -f "$ROOT_FILE" \
        && echo "  removed $ROOT_FILE"
    [[ -L "$SESSION_HOOK_LINK" ]] && rm -f "$SESSION_HOOK_LINK" \
        && echo "  removed $SESSION_HOOK_LINK"
    # Legacy skill symlinks into THIS checkout only; another checkout's are
    # that checkout's to remove.
    for link in "$SKILLS_DIR"/*; do
        [[ -L "$link" ]] || continue
        own_skill_link "$link" || continue
        rm -f "$link"
        echo "  removed legacy skill symlink: $(basename "$link")"
    done
    # The plugin: every per-root entry of this checkout's (an entry the CLI
    # cannot remove is an error naming the removal by hand), then the
    # user-scope enable, when this checkout declared it. An enable with no
    # marketplace declaration beside it names no checkout: nothing ties it
    # to this one, so it is reported with the removal by hand and left.
    uninstall_rc=0
    migrate_legacy_roots strict || uninstall_rc=1
    if [[ "$(installed_plugins_state)" == unparseable ]]; then
        echo "  ERROR: $(installed_plugins_unreadable)" >&2
        uninstall_rc=1
    fi
    uninstall_us="$(user_scope_state)"
    [[ "$uninstall_us" == partial && -z "$(user_plugin_source)" ]] && uninstall_us=undeclared
    case "$uninstall_us" in
        undeclared)
            echo "  NOTE: $CLI_SETTINGS enables the $PLUGIN_NAME plugin at user scope with no $MARKETPLACE_NAME marketplace declaration, so nothing ties it to this checkout -- left as it is; to remove it by hand: delete \"$PLUGIN_ID\" from enabledPlugins in $CLI_SETTINGS" ;;
        ours|partial)
            if ! have_claude; then
                echo "  ERROR: the claude CLI is not on PATH -- cannot remove the $PLUGIN_NAME plugin at user scope; run \`claude plugin uninstall $PLUGIN_ID --scope user\` and \`claude plugin marketplace remove $MARKETPLACE_NAME --scope user\`" >&2
                uninstall_rc=1
            else
                # Best effort, each: the state read back decides.
                cli_user uninstall "$PLUGIN_ID" --scope user 2>/dev/null || true
                cli_user marketplace remove "$MARKETPLACE_NAME" --scope user 2>/dev/null || true
                if [[ "$(user_scope_state)" == absent ]]; then
                    echo "  removed the $PLUGIN_NAME plugin at user scope"
                else
                    echo "  ERROR: could not remove the $PLUGIN_NAME plugin at user scope (see $CLI_SETTINGS); run \`claude plugin uninstall $PLUGIN_ID --scope user\` and \`claude plugin marketplace remove $MARKETPLACE_NAME --scope user\`" >&2
                    uninstall_rc=1
                fi
            fi ;;
        foreign)
            echo "  NOTE: the $PLUGIN_NAME plugin at user scope is declared from another checkout ($(user_plugin_source)) -- left for that checkout's --uninstall" ;;
        unparseable)
            echo "  ERROR: $CLI_SETTINGS is not valid JSON -- cannot tell whether the $PLUGIN_NAME plugin is enabled at user scope; not removing it" >&2
            uninstall_rc=1 ;;
    esac
    # Only once settings.json is rewritten: its rewrite read this file to
    # find rules written by an earlier manifest generation, and a failed
    # rewrite exited above with the file still here.
    [[ -f "$RULES_FILE" ]] && rm -f "$RULES_FILE" && echo "  removed $RULES_FILE"
    if [[ "$uninstall_rc" -ne 0 ]]; then
        echo "agent_workspace user tier removed, except the plugin entries named above." >&2
        exit 1
    fi
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
    config_dir_note

    [[ -L "$SESSION_HOOK_LINK" ]] || note "missing SessionStart hook symlink at $SESSION_HOOK_LINK"
    if [[ -L "$SESSION_HOOK_LINK" && "$(readlink "$SESSION_HOOK_LINK")" != "$SESSION_HOOK_TARGET" ]]; then
        note "stale SessionStart hook symlink: points at $(readlink "$SESSION_HOOK_LINK"), expected $SESSION_HOOK_TARGET"
    fi
    [[ -e "$SESSION_HOOK_TARGET" ]] || note "SessionStart hook target does not exist: $SESSION_HOOK_TARGET"

    settings="$(read_settings)"
    export WS_ROOT_PREFIX="$WS_ROOT/"

    # Hook commands are judged by classify_hooks, marked or not (header;
    # #394). A jq failure in any query built on it is an error, not a clean
    # report.
    cls_json="$(classify_hooks "$settings")" || exit 1
    # Each caller adds `|| exit 1`: the function runs in a command
    # substitution, where its own exit would end only that subshell.
    class_query() {  # <jq filter> [jq args...] -- over settings.json, with the shared defs
        jq -r --arg tag "$TAG" --argjson cls "$cls_json" --argjson force false --argjson dead true \
            "${@:2}" "$PRUNE_JQ_DEFS$1" <<< "$settings" || {
            echo "ERROR: could not check the hook commands in $SETTINGS (jq failed)" >&2
            return 1
        }
    }

    # Our hook commands, each exactly once under its own event -- what
    # install leaves. A second copy (the duplicate #394's bug left behind)
    # or a copy under another event is drift too: install removes it, so a
    # --check that only asked "present anywhere?" would call current a file
    # the next install changes.
    # while-read, not `for cmd in $(...)`: a checkout path containing a space
    # or a glob character would otherwise word-split into permanent drift.
    check_event_count() {  # <command> <event>
        local here elsewhere
        here="$(class_query '[(.hooks // {} | objects | .[$ev]) | arrays | .[] | objects
                | entry_commands | select(. == $c)] | length' --arg c "$1" --arg ev "$2")" || return 1
        elsewhere="$(class_query '[.hooks // {} | objects | to_entries[] | select(.key != $ev)
                | select(any(.value | arrays | .[] | objects | entry_commands; . == $c)) | .key]
                | join(", ")' --arg c "$1" --arg ev "$2")" || return 1
        if [[ "$here" -eq 0 ]]; then
            note "missing hook entry for $1 (under $2)"
        elif [[ "$here" -gt 1 ]]; then
            note "hook command $1 is registered $here times under $2 (re-run the installer: it keeps one)"
        fi
        [[ -z "$elsewhere" ]] || note "hook command $1 is registered under $elsewhere, where it does not belong (re-run the installer: it keeps it under $2 only)"
    }
    # A hook event install would refuse to write into (hook_shape_errors).
    shape_errors="$(hook_shape_errors "$settings")" || { echo "ERROR: could not check the hooks in $SETTINGS (jq failed)" >&2; exit 1; }
    if [[ -n "$shape_errors" ]]; then
        while IFS= read -r e; do
            note "settings.json: $e -- the installer refuses to rewrite it; fix it by hand"
        done <<< "$shape_errors"
    fi
    while IFS= read -r cmd; do
        check_event_count "$cmd" PreToolUse || exit 1
    done < <(hook_commands)
    check_event_count "$SESSION_HOOK_LINK" SessionStart || exit 1

    # Hook entries from a DIFFERENT checkout (a second clone installed over
    # us): marked with it, or holding a command classified as its.
    foreign="$(class_query '
        [hook_entries | (._agent_workspace // "") as $m
         | (if ($m | type) == "string" and $m != "" and $m != $tag then $m else empty end),
           (entry_commands | select(owner($m) == "foreign") | $cls[.].dir)]
        | unique | .[]')" || exit 1
    if [[ -n "$foreign" ]]; then
        while IFS= read -r f; do
            note "settings.json has hook entries from another workspace checkout: $f"
        done <<< "$foreign"
    fi

    # Hook commands left by a checkout since moved or deleted: a hook this
    # script writes or has retired, under a <dir> no longer on disk. They
    # fail on every tool call. In an entry marked with the command's own
    # checkout, install removes them; any other (unmarked, or marked with
    # another checkout) only --force does (header), so the remedy differs.
    dead="$(class_query '[hook_entries | (._agent_workspace // "") as $m | entry_commands | select(owner($m) == "dead" and attributed($m))] | unique | .[]')" || exit 1
    if [[ -n "$dead" ]]; then
        while IFS= read -r d; do
            note "hook entry names a workspace hook in a checkout that is not on disk (moved or deleted?): $d (re-run the installer to remove it)"
        done <<< "$dead"
    fi
    dead="$(class_query '[hook_entries | (._agent_workspace // "") as $m | entry_commands | select(owner($m) == "dead" and (attributed($m) | not))] | unique | .[]')" || exit 1
    if [[ -n "$dead" ]]; then
        while IFS= read -r d; do
            note "hook command names a workspace hook in a directory that is not on disk: $d -- nothing attributes it to this installer (a moved or deleted checkout, or a drive not mounted?), so a plain install leaves it; if it is a dead checkout's, remove it with: $WS_ROOT/.agent/scripts/user_tier_install.sh --force"
        done <<< "$dead"
    fi

    # An entry still carrying this checkout's marker (an earlier generation
    # wrote it) beside a command that is not this checkout's. The command is
    # the user's and stays; the marker is what install drops.
    stale="$(class_query '
        [hook_entries | select((._agent_workspace // "") == $tag)
         | entry_commands | select(owner($tag) != "self")] | unique | .[]')" || exit 1
    if [[ -n "$stale" ]]; then
        while IFS= read -r st; do
            note "hook entry marked with this checkout holds a command outside it: $st (re-run the installer: it drops the marker and keeps the command)"
        done <<< "$stale"
    fi

    # Our commands that the current generation no longer produces -- a hook
    # retired from the user tier (#328), or one of ours written through a
    # symlinked alias of this checkout. None of the checks above fire for
    # it, so without this case --check says "installed and current" while
    # settings.json still runs a hook the checkout no longer ships (or no
    # longer has on disk). Re-running the installer removes it.
    wanted_json="$( { hook_commands; printf '%s\n' "$SESSION_HOOK_LINK"; } \
        | jq -R . | jq -s . )"
    retired="$(class_query '
        [hook_entries | (._agent_workspace // "") as $m
         | entry_commands | select(owner($m) == "self")] | unique
        | map(select(. as $c | ($want | index($c)) == null)) | .[]' --argjson want "$wanted_json")" || exit 1
    if [[ -n "$retired" ]]; then
        while IFS= read -r rt; do
            note "hook command of this checkout is no longer generated: $rt (re-run the installer)"
        done <<< "$retired"
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

    # Legacy skill symlinks: any link left in ~/.claude/skills/ that resolves
    # into an agent_workspace checkout (this one or another) is drift -- the
    # mechanism ADR-0018 retired, which shadows a project's own skills.
    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        note "legacy skill symlink (retired by ADR-0018; re-run the installer to remove it): $link -> $(readlink "$link")"
    done < <(legacy_skill_links)

    # The plugin at user scope. JSON reads only -- no CLI call. Without the
    # claude CLI install cannot enable it either, so a missing enable is a
    # note naming what is needed: drift whose advice cannot clear it would
    # keep --check red on a machine with no Claude Code.
    plugin_note() {  # <message>: drift, or a note when the CLI is missing
        if have_claude; then
            note "$1"
        else
            echo "  note: $1; the claude CLI is not on PATH, so there is nothing to enable it with"
        fi
    }
    case "$(user_scope_state)" in
        ours)
            # The machine-level record: the CLI keys it by marketplace name,
            # so a machine holds ONE `agent-workspace` source; when it names
            # another checkout, sessions may load that checkout's skills, and
            # with no entry they may not load the plugin at all. (This relies
            # on the CLI's format: a file the installer cannot read an entry
            # from looks the same.)
            if ! machine_record_ours; then
                plugin_note "the claude CLI's machine-level record of the $MARKETPLACE_NAME marketplace ($KNOWN_MARKETPLACES) $(machine_record_what), not this checkout -- sessions may not load this checkout's skills (re-run the installer: it repairs it)"
            fi
            # The same test as install's shortcut: --check calls current
            # only what install leaves alone.
            if [[ "$(user_install_record)" == absent ]]; then
                plugin_note "the claude CLI's record of plugin installs ($INSTALLED_PLUGINS) lists no user-scope install of $PLUGIN_ID, though $CLI_SETTINGS enables it -- the CLI's install and cache may be missing or another checkout's (re-run the installer: it runs the install)"
            fi ;;
        foreign)
            plugin_note "the $PLUGIN_NAME marketplace is declared at user scope ($CLI_SETTINGS) from another checkout, $(user_plugin_source), not from this one (re-run the installer to repoint it here)" ;;
        unparseable)
            note "$CLI_SETTINGS is not valid JSON -- cannot check the $PLUGIN_NAME plugin at user scope" ;;
        *)
            plugin_note "the $PLUGIN_NAME plugin is not enabled at user scope from this checkout ($CLI_SETTINGS; re-run the installer)" ;;
    esac

    # The workspace checkout's tracked .claude/settings.json sets the plugin
    # to false: the plugin's source is this checkout's .claude/skills, so
    # without it a session at the checkout's root would list every shipped
    # skill twice. The installer never writes that tracked file (header);
    # a missing entry is drift a commit fixes.
    if ! jq -e --arg id "$PLUGIN_ID" '.enabledPlugins[$id]? == false' "$WS_ROOT/.claude/settings.json" >/dev/null 2>&1; then
        note "the workspace checkout's tracked $WS_ROOT/.claude/settings.json does not set enabledPlugins[\"$PLUGIN_ID\"] to false, so a session at the checkout's root lists every shipped skill twice (restore the entry from the repository; the installer never edits that file)"
    fi

    # Per-root entries the per-root generation left: notes, not drift (the
    # plugin enabled at local and user scope is listed once, live case U7),
    # except in the workspace checkout itself, where a local true overrides
    # the tracked false entry and every skill is listed twice at its root.
    while IFS=$'	' read -r kind label root; do
        [[ -n "$root" ]] || continue
        f="$root/.claude/settings.local.json"
        if [[ ! -d "$root" ]]; then
            if [[ "$kind" == cli-record ]]; then
                echo "  note: the claude CLI's record ($INSTALLED_PLUGINS) lists a local-scope install of $PLUGIN_ID in $root, which is not on disk -- remove it by hand: delete the object with \"scope\": \"local\" and \"projectPath\": \"$root\" from the \"$PLUGIN_ID\" array in $INSTALLED_PLUGINS"
            else
                echo "  note: $label is not on disk ($root) -- not checked for a per-root $PLUGIN_NAME entry"
            fi
            continue
        fi
        case "$(legacy_state "$root")" in
            ours)
                if [[ "$kind" == checkout ]] && jq -e --arg id "$PLUGIN_ID" '.enabledPlugins[$id]? == true' "$f" >/dev/null 2>&1; then
                    note "$f enables the $PLUGIN_NAME plugin in the workspace checkout itself, overriding the false entry in its tracked .claude/settings.json, so a session at the checkout's root lists every skill twice (re-run the installer to remove it)"
                elif why="$(cli_refusal "$root")"; then
                    echo "  note: $f ($label) holds a per-root $PLUGIN_NAME entry from this checkout, and the installer does not run the claude CLI there: $why -- remove it by hand: $(hand_removal "$f")"
                else
                    echo "  note: $f ($label) still holds a per-root $PLUGIN_NAME entry from this checkout (re-run the installer to move it to user scope)"
                fi ;;
            foreign)
                echo "  note: $f ($label) declares the $PLUGIN_NAME marketplace from another checkout, $(jq -r --arg m "$MARKETPLACE_NAME" '.extraKnownMarketplaces[$m].source.path' "$f"), which a session there may load instead of this one's" ;;
            unparseable)
                echo "  note: $f ($label) is not valid JSON -- cannot tell whether it holds a per-root $PLUGIN_NAME entry" ;;
        esac
    done <<< "$LEGACY_PLACES"
    [[ "$(installed_plugins_state)" == unparseable ]] && echo "  note: $(installed_plugins_unreadable)"

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

config_dir_note

# Everything that can refuse is checked, and the settings.json merge built
# and backed up, before anything in ~/.claude is written: a refusal or a
# failed backup then leaves the tier exactly as it was, rather than a root
# file that reads as installed beside an unchanged settings.json.

# The SessionStart hook symlink's preconditions (written in step 2).
if [[ ! -e "$SESSION_HOOK_TARGET" ]]; then
    echo "ERROR: hook target missing: $SESSION_HOOK_TARGET" >&2
    exit 1
fi
if [[ -e "$SESSION_HOOK_LINK" && ! -L "$SESSION_HOOK_LINK" ]]; then
    echo "ERROR: $SESSION_HOOK_LINK exists and is not a symlink -- not overwriting" >&2
    exit 1
fi

# settings.json: our hook entries and allow-rules, replacing any previous
# generation of ours (that is what makes this idempotent) and leaving
# everything else in the file untouched. No marker is written: the
# `claude plugin` commands drop it (#394), so commands are told apart by
# classify_hooks (header).
PRE_HOOKS_JSON="$(jq -n --arg log "$WS_ROOT/.claude/hooks/log-tool-use.sh" '
    {
      hooks: [
        {type: "command", command: $log, timeout: 5}
      ]
    }')"

SESSION_HOOKS_JSON="$(jq -n --arg cmd "$SESSION_HOOK_LINK" '
    {
      hooks: [{type: "command", command: $cmd, timeout: 10}]
    }')"

current_settings="$(read_settings)"
shape_errors="$(hook_shape_errors "$current_settings")" || {
    echo "ERROR: could not read the hooks in $SETTINGS (jq failed) -- nothing changed" >&2
    exit 1
}
if [[ -n "$shape_errors" ]]; then
    echo "ERROR: refusing to rewrite $SETTINGS -- nothing changed:" >&2
    while IFS= read -r e; do
        echo "  $e; the installer adds its entry to an array there and will not replace what it holds -- fix it by hand, then re-run" >&2
    done <<< "$shape_errors"
    exit 1
fi
install_cls="$(classify_hooks "$current_settings")" || exit 1
# Remove the previous generation of our commands, the user's own commands
# staying (prune, PRUNE_JQ_DEFS): ours, and dead ones. Under --force we are
# deliberately taking the tier over from another checkout, so its commands
# go too -- otherwise the takeover leaves the old checkout's SessionStart
# and PreToolUse commands beside ours, both layers get injected into every
# session, and --check reports drift immediately after a --force that
# exited 0 claiming success. A plain install leaves another checkout's
# commands alone (--check reports them).
#
# The first entry that already is exactly ours stays where it is, so a file
# that is already current comes out unchanged rather than reordered.
merged_settings="$(jq \
    --arg tag "$TAG" \
    --argjson force "$([[ "$FORCE" == true ]] && echo true || echo false)" \
    --argjson dead true \
    --argjson cls "$install_cls" \
    --argjson pre "$PRE_HOOKS_JSON" \
    --argjson ses "$SESSION_HOOKS_JSON" \
    --argjson rules "$(allow_rules_json)" "$PRUNE_JQ_DEFS"'
    def place($w):
        (map(. == $w) | index(true)) as $i
        | [to_entries[] | if .key == $i then .value else ([.value] | prune | .[]) end]
        | if $i == null then . + [$w] else . end;
    .hooks //= {}
    | .hooks.PreToolUse //= []
    | .hooks.SessionStart //= []
    | .hooks |= with_entries(
        if .key == "PreToolUse" then .value |= place($pre)
        elif .key == "SessionStart" then .value |= place($ses)
        elif (.value | type) == "array" then .value |= prune
        else . end)
    | .permissions //= {}
    | .permissions.allow //= []
    | .permissions.allow = ((.permissions.allow + $rules) | unique)
' <<< "$current_settings")" || { echo "ERROR: could not merge $SETTINGS -- nothing changed" >&2; exit 1; }

# What the merge removes and does not write back, and the dead commands it
# leaves because nothing attributes them to this installer (header): both
# are named after the write. Same definitions and arguments as the merge.
install_report_query() {  # <jq filter>
    jq -r --arg tag "$TAG" \
        --argjson force "$([[ "$FORCE" == true ]] && echo true || echo false)" \
        --argjson dead true \
        --argjson cls "$install_cls" \
        --argjson want "$( { hook_commands; printf '%s\n' "$SESSION_HOOK_LINK"; } | jq -R . | jq -s . )" \
        "$PRUNE_JQ_DEFS$1" <<< "$current_settings"
}
install_removed="$(install_report_query '
    [hook_entries | (._agent_workspace // "") as $m | entry_commands
     | select(remove($m)) | select(. as $c | ($want | index($c)) == null)
     | "\(owner($m))\t\(.)"] | unique | .[]')" \
    && install_left="$(install_report_query '
    [hook_entries | (._agent_workspace // "") as $m | entry_commands
     | select(owner($m) == "dead" and (remove($m) | not))] | unique | .[]')" \
    || { echo "ERROR: could not list the hook commands this run removes from $SETTINGS -- nothing changed" >&2; exit 1; }

# Write only when something changed, compared ignoring key order: the CLI
# re-emits the file in its own key order, and rewriting it on every run in
# jq's would churn it (and pile up backups) for nothing.
settings_changed=true
if [[ "$(jq -S . <<< "$merged_settings")" == "$(jq -S . <<< "$current_settings")" ]]; then
    settings_changed=false
fi
if [[ "$settings_changed" == true ]]; then
    backup_settings || { echo "ERROR: could not back up $SETTINGS -- not proceeding; nothing changed" >&2; exit 1; }
fi

mkdir -p "$CLAUDE_DIR" "$HOOKS_DIR"

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
ln -sfn "$SESSION_HOOK_TARGET" "$SESSION_HOOK_LINK"
echo "  linked $SESSION_HOOK_LINK -> $SESSION_HOOK_TARGET"

# 3+4. settings.json, merged and backed up above
if [[ "$settings_changed" == false ]]; then
    echo "  $SETTINGS already has our hook entries and $(allow_rules_json | jq 'length') allow-rules -- not rewritten"
else
    write_settings <<< "$merged_settings" || {
        echo "ERROR: failed to write $SETTINGS -- nothing changed in it (the backup above is a copy of it); re-run the installer once it can be written" >&2
        exit 1
    }
    echo "  merged hook entries and $(allow_rules_json | jq 'length') allow-rules into $SETTINGS"
fi
if [[ -n "$install_removed" ]]; then
    while IFS=$'\t' read -r owner cmd; do
        case "$owner" in
            dead)    why="a workspace hook in a checkout not on disk" ;;
            foreign) why="another workspace checkout's, removed by --force" ;;
            *)       why="this checkout's, no longer generated" ;;
        esac
        echo "  removed hook command $cmd ($why)"
    done <<< "$install_removed"
    echo "  the settings.json from before these removals is kept at $BACKUP_PATH"
fi
if [[ -n "$install_left" ]]; then
    while IFS= read -r cmd; do
        echo "  NOTE: left in place: hook command $cmd names a workspace hook in a directory that is not on disk, and nothing attributes it to this installer (a moved or deleted checkout, or a drive not mounted?). If it is a dead checkout's, remove it with: $WS_ROOT/.agent/scripts/user_tier_install.sh --force"
    done <<< "$install_left"
fi

# 5. retire legacy skill symlinks (ADR-0018), this checkout's or another's
while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    rm -f "$link"
    echo "  removed legacy skill symlink: $(basename "$link")"
done < <(legacy_skill_links)

# 6. the plugin, once, at user scope (ADR-0018), then the migration of
# per-root entries -- in that order: a local remove while the user-scope
# declaration is present keeps the machine-level record, the reverse order
# can drop it.
# The shortcut also needs the CLI's record of a user-scope install: an
# enable with none was not made by the CLI's `install` (or its record was
# lost), so install runs. A record that does not parse cannot say; it is
# reported after the migration, and no CLI call is made over it.
case "$(user_scope_state)" in
    ours)
        if machine_record_ours && [[ "$(user_install_record)" != absent ]]; then
            echo "  the $PLUGIN_NAME plugin is already enabled at user scope from this checkout -- no claude CLI call"
            PLUGIN_ON=true
        fi ;;
    unparseable)
        echo "" >&2
        echo "agent_workspace user tier installed from $WS_ROOT, but $CLI_SETTINGS is not valid JSON, so the $PLUGIN_NAME plugin was not enabled at user scope (fix it: jq . \"$CLI_SETTINGS\"), and nothing in any project root was changed." >&2
        exit 1 ;;
    foreign)
        echo "  the $PLUGIN_NAME marketplace is declared at user scope from another checkout, $(user_plugin_source) -- repointing it here (the user tier is this checkout's)" ;;
esac
if [[ "${PLUGIN_ON:-false}" != true ]]; then
    if ! have_claude; then
        echo "  NOTE: the claude CLI is not on PATH -- not enabling the $PLUGIN_NAME plugin (a machine without Claude Code has no plugins to enable)"
    elif enable_user_scope; then
        echo "  enabled the $PLUGIN_NAME plugin at user scope from $WS_PHYS"
    else
        echo "" >&2
        echo "agent_workspace user tier installed from $WS_ROOT, but the $PLUGIN_NAME plugin could not be enabled at user scope (above); nothing in any project root was changed." >&2
        exit 1
    fi
fi

plugin_rc=0
migrate_legacy_roots || plugin_rc=1
[[ "$(installed_plugins_state)" == unparseable ]] && echo "  NOTE: $(installed_plugins_unreadable)"
# The read-back: a local-scope remove must not have cost the user-scope
# enable or the machine-level record (not established on the CLI; this is
# the guard). A re-run repairs either.
if [[ "$LEGACY_CLI_RAN" == 1 ]] && ! user_scope_readback "after moving per-root entries to user scope"; then
    echo "" >&2
    echo "agent_workspace user tier installed from $WS_ROOT, but moving the per-root entries lost the $PLUGIN_NAME plugin's user-scope enable or machine-level record (above): re-run the installer to restore it." >&2
    exit 1
fi
if [[ "$plugin_rc" -ne 0 ]]; then
    echo "" >&2
    echo "agent_workspace user tier installed from $WS_ROOT, but a per-root $PLUGIN_NAME entry could not be moved to user scope (above)." >&2
    exit 1
fi

echo ""
echo "agent_workspace user tier installed from $WS_ROOT"
echo "Verify with: .agent/scripts/user_tier_install.sh --check"
exit 0
