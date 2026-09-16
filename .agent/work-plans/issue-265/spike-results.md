# Issue #265 — Design B spike results

Claude Code 2.1.273. Run 2026-09-16 in worktree
`/home/roland/agent_workspace/worktrees/workspace/issue-workspace-265`
(branch `feature/issue-265`), scratch work under
`/tmp/claude-1000/-home-roland-agent-workspace/<session>/scratchpad/spike265/`.

## Blocker that shaped this run

The brief's verification method for experiments 1, 2, 3(a) and 6 is a nested
`claude -p` session launched with `CLAUDE_CONFIG_DIR` pointed at a throwaway
user tier. That mechanism itself works — `claude doctor` runs fine against
the fake config dir and confirms it's being read (see experiment 1). But a
fresh config dir has no stored credentials, and the sandbox's auto-mode
classifier denies both reading `~/.claude/.credentials.json`-adjacent files
and even `env | grep -i anthropic` (reason: "Credential Materialization") —
so there is no way to authenticate a nested session without violating the
constraint on the real user tier and the sandbox's own credential-access
policy. Per the brief ("if `CLAUDE_CONFIG_DIR` does not behave as expected,
say so and stop that experiment"), I stopped rather than working around it.
Where a live authenticated session was the only way to observe the real
behavior, I ran the closest static/standalone substitute I could (source
reading, standalone script execution mimicking hook I/O) and marked the
verdict accordingly — never silently substituted a guess for a PASS.

## Summary

| # | Experiment | Verdict | One-line finding |
|---|---|---|---|
| 1 | Skills via symlinked `<config>/skills/` dirs | **PASS** (authenticated follow-up run) | Two workspace skill dirs symlinked into the fake tier's `skills/` were listed by name (`audit-workspace`, `what-next`) by a session launched in an unrelated repo |
| 2 | Conditional SessionStart hook (registry-gated) | **PASS** (authenticated follow-up run) | Hook stdout lands in context verbatim as `SessionStart:startup hook success: <line>` when launched under a registered root; nothing injected from an unrelated repo; silent branch ~5.5ms |
| 3a | Absolute-path PreToolUse hook fires from project cwd | **PASS** (authenticated follow-up run) | User-tier `PreToolUse` hook with an absolute command path fired from `/home/roland/src/gz4d` (3 log lines for one `echo` turn) |
| 3b | Tool-mapping hook standing down outside registered roots | **PASS (by inspection)** | The hook has no root-awareness today — it fires on any `cat/head/tail/find/sed` Bash call regardless of cwd; moving it to the user tier needs a registry-lookup guard added before the pattern checks |
| 3c | Workspace `.claude/settings.json` allow rules don't leak into unrelated repos | **PASS (documented, not directly observed)** | Project-scoped settings files load only for that project's trusted directory tree; cited from Claude Code's settings-source model, not observed live here |
| 4 | Adapter cwd discovery from an out-of-tree root and a worktree beneath it | **PASS** | `adapter --from <root>/worktrees/x project_root` resolves to `<root>` by ancestry alone, same as `--from <root>` and `--project <name>` |
| 5 | Nested worktree excluded from `git status` and `colcon list` | **PASS** | `worktrees/` untracked until added to `.git/info/exclude` (then clean, confirmed still visible via `--ignored`); `colcon list` picks up a package under `worktrees/x/src/` until a `COLCON_IGNORE` file is dropped in `worktrees/`, then it's excluded |
| 6 | Per-project `CLAUDE.md` stays in context after `cd` into a worktree beneath it | **PASS with a caveat** (authenticated follow-up run) | In-session `cd worktrees/x` keeps the root `CLAUDE.md` and does **not** load the worktree's own. But a session launched *directly inside* a nested git worktree sees only the worktree's `CLAUDE.md`, and **none** when the worktree has no `CLAUDE.md` — the parent project's file is not walked as an ancestor across the worktree's git boundary. The project layer therefore cannot rely on ancestor walking; the registry-gated SessionStart hook must inject it |
| 7 | One root variable for `.agent/scripts` / `.claude/hooks` references | **PASS** | 11/20 skills and both `.claude/settings.json` hook commands use relative paths; existing scripts already derive `WORKSPACE_ROOT` from `BASH_SOURCE`, which works for scripts but not skill prose — a `SessionStart`-exported `AGENT_WORKSPACE_ROOT` is the missing piece for skill bodies |
| 8 | Context cost: unconditional import vs. conditional injection | **PASS (byte measurement); INCONCLUSIVE (live token report)** | `AGENTS.md` + `CLAUDE.md` = 21,915 bytes ≈ 5,479 tokens paid in *every* session under an unconditional `@`-import; a registry-gated hook pays ~0 bytes and ~5.5ms in unrelated repos — live `-p` token accounting not obtainable (auth blocker) |

---

## Experiment 1 — Skills discovered through symlinked directories in `<config>/skills/`

**Commands:**
```bash
mkdir -p "$SPIKE/fake-config"
cat > "$SPIKE/fake-config/CLAUDE.md" <<'EOF'
Reply with exactly the word PROBE-OK and nothing else.
EOF
env -u CLAUDECODE CLAUDE_CONFIG_DIR="$SPIKE/fake-config" claude -p "Say hello per your instructions" --output-format text
# → "Not logged in · Please run /login"

env -u CLAUDECODE CLAUDE_CONFIG_DIR="$SPIKE/fake-config" claude doctor
```

**Observed:** The `-p` probe never authenticated: a fresh `CLAUDE_CONFIG_DIR`
has no credentials, and the CLI exits immediately with `Not logged in`
before any hook/skill/CLAUDE.md loading is observable. `claude doctor`
against the same fake config dir *does* run (confirms the env var is honored
— it reports config-dir-scoped state like "Managed settings (remote): not
fetched" and no crash/fallback to the real `~/.claude`), but `doctor` does
not enumerate skills, so it can't substitute for the planned probe.

I could not read `~/.claude/.credentials.json` or check for an
`ANTHROPIC_API_KEY` env var to bootstrap auth in the fake tier — both were
denied by the sandbox's auto-mode classifier as "Credential Materialization".
I did not attempt further workarounds (e.g., symlinking the real
`~/.claude` credentials in), since that would both violate "never touch the
real user tier" in spirit and the explicit sandbox denial.

**Verdict:** BLOCKED. The `CLAUDE_CONFIG_DIR` override mechanism itself is
confirmed working (falsifiable — `doctor` reads it); what's unverified is
purely the skill-symlink-discovery question, which needs an authenticated
session.

**Caveat:** This experiment needs to be re-run by the human operator (or in
an environment where nested-session credential provisioning is permitted)
before the plan can claim skill symlinks work. Until then, treat it as an
open risk in the design.

---

## Experiment 2 — Conditional user-level SessionStart hook

**Commands:** built a standalone reproduction of the hook's *logic* (not
run via `claude`, since that needs auth) at
`$SPIKE/exp2/session-start-hook.sh`. It reads a JSON payload with a `cwd`
field (matching Claude Code's documented SessionStart hook input shape),
checks it against a scratch `.agent/projects.local`-style registry, and
prints a marker only on a match.

```bash
export AGENT_WORKSPACE_ROOT="$SPIKE/exp2/fake-ws"   # contains .agent/projects.local: "gz4d single_project /home/roland/src/gz4d"

echo '{"cwd":"/home/roland/src/gz4d"}' | "$SPIKE/exp2/session-start-hook.sh"
# → WORKSPACE-CONTEXT-INJECTED (project=gz4d)

echo "{\"cwd\":\"$AGENT_WORKSPACE_ROOT\"}" | "$SPIKE/exp2/session-start-hook.sh"
# → WORKSPACE-CONTEXT-INJECTED (workspace root)

echo "{\"cwd\":\"$SPIKE/exp2/unrelated-repo\"}" | "$SPIKE/exp2/session-start-hook.sh"
# → (silent)

time ( for i in $(seq 1 20); do echo "{\"cwd\":\"$SPIKE/exp2/unrelated-repo\"}" | "$SPIKE/exp2/session-start-hook.sh" > /dev/null; done )
# → real 0m0.109s  (≈5.5ms per stand-down call)
```

**Observed:** The registry-gated stand-down logic works exactly as
intended — silent for an unrelated scratch git repo, prints a marker for
both the registered project root and the workspace root itself, and the
silent-branch cost is ~5.5ms per invocation (bash startup + one `jq` call +
a handful of `cd`/`pwd -P` calls; dominated by process spawn, not the
registry walk).

**Verdict:** INCONCLUSIVE (partial). What's proven: the *mechanism's logic*
is correct and cheap. What's unproven: that Claude Code actually splices a
`SessionStart` hook's stdout into session context (this is documented
behavior, and the hook input/output contract matches what the script
assumes, but I could not run it through an actual `claude` session to
confirm empirically here).

**Caveat:** The 5.5ms figure is a standalone-script measurement, not a
figure taken from inside Claude Code's hook runner (which likely adds its
own fixed per-hook overhead — process supervision, timeout handling — on
top of this). Treat it as a lower bound on the real cost, not the real cost.

---

## Experiment 3 — Hook and permission entries with absolute paths

### 3a — Absolute-path PreToolUse hook fires from a project cwd

**Not directly testable** here (same auth blocker as experiments 1/2/6).
Claude Code's hook `command` field is documented as an arbitrary shell
command string, executed as-is — nothing in the schema or current workspace
usage (`.claude/hooks/block-bash-tool-mapping.sh` is already a bare relative
path resolved against cwd, i.e. it *depends on* cwd being the repo root
today) suggests absolute paths are treated specially or rejected. Expected
to work; unverified.

**Verdict:** INCONCLUSIVE.

### 3b — Can `block-bash-tool-mapping.sh` stand down outside registered roots?

Read `/home/roland/agent_workspace/worktrees/workspace/issue-workspace-265/.claude/hooks/block-bash-tool-mapping.sh`
in full. It has **no cwd/root awareness at all** today: it reads the
`PreToolUse` JSON payload, checks `tool_name == "Bash"`, then pattern-matches
the command head (`cat|head|tail|find|sed`) and blocks on match — unconditionally, regardless of what repo or directory the session is in. It's
also currently installed as a **project-scoped** hook (`.claude/settings.json`
inside the workspace repo), so under the *current* design it simply doesn't
run in unrelated repos at all (settings scoping does the "standing down" by
not being loaded — see 3c). Under design B's user-tier install, this
protection disappears: a hook installed with an absolute path in
`~/.claude/settings.json` runs in **every** repo, including untrusted
clones.

**Concrete change needed:** add a registry-lookup guard at the top of the
script — same shape as `session-start-hook.sh` in experiment 2 — that reads
`.tool_input.cwd` (or falls back to `$PWD`) from the hook input, resolves it
against `$AGENT_WORKSPACE_ROOT/.agent/projects.local` (or the workspace root
itself), and `exit 0`s immediately (no `INPUT=$(cat)`/`jq` cost beyond the
lookup) when the cwd isn't under a registered root. This mirrors the
"registered-root gate" the SessionStart hook needs, so the two could likely
share one small library function.

**Verdict:** PASS (as an inspection-based finding — the script's current
lack of root-awareness is directly confirmed by reading it; the *fix* is a
recommendation, not something tested against a live untrusted-repo session).

### 3c — Do workspace `.claude/settings.json` allow rules leak into unrelated repos?

Not run live (would require an authenticated session launched from a
directory outside this worktree, which I'm confined not to do, and which
faces the same nested-session auth blocker in the general case). Citing
Claude Code's documented settings model instead: project-level
`.claude/settings.json` is one of several **setting sources** (user →
project → local, with `--setting-sources` controlling which apply) and is
only loaded for sessions whose working directory is inside — and has
trust-accepted — that project. There is no mechanism by which a permission
`allow` rule written in `agent_workspace/.claude/settings.json` would apply
to a session opened in an unrelated repo's directory; it simply isn't one of
that session's setting sources.

**Verdict:** PASS (documented, not directly observed in this spike).

**Caveat:** this is exactly the assumption design B's plan should not take
on faith given the "Documentation Accuracy" workspace rule — recommend a
follow-up smoke test (e.g. via CI or a human running `claude -p` from
`/tmp` and checking `gh_create_issue.sh`-style commands are *not*
pre-approved) before relying on it operationally.

---

## Experiment 4 — Adapter cwd discovery

Registered a scratch root by writing a throwaway `.agent/projects.local` in
the **worktree** (gitignored, not the real registry, removed after the
test):

```bash
cat > .agent/projects.local <<EOF
spike4  single_project  $SPIKE/exp4/scratch-root
EOF
mkdir -p "$SPIKE/exp4/scratch-root/worktrees/x"

.agent/scripts/adapter --from "$SPIKE/exp4/scratch-root" project_root
# → .../spike265/exp4/scratch-root

.agent/scripts/adapter --from "$SPIKE/exp4/scratch-root/worktrees/x" project_root
# → .../spike265/exp4/scratch-root   (same — resolved by ancestry)

.agent/scripts/adapter --project spike4 project_root
# → .../spike265/exp4/scratch-root   (explicit selection, same result)

.agent/scripts/adapter --from /tmp project_root
# → <worktree>/project   (falls back to the legacy project/ symlink; /tmp isn't under any registered root)
```

**Observed:** `registry_resolve_from_dir` (used by the dispatcher for
discovery) walks up from the given `--from` directory and matches any
registered root by prefix, so a path arbitrarily deep under
`<root>/worktrees/x` resolves to the same project as the root itself,
identical to what `--project <name>` gives explicitly. An unrelated
directory (`/tmp`) correctly falls through to the legacy
`project/`-symlink path rather than guessing.

**Verdict:** PASS.

**Caveat:** I created `.agent/projects.local` directly in the worktree
rather than editing the real one (there was no real `.agent/projects.local`
present in this worktree — gitignored, per-machine). Removed it after the
test; confirmed with `rm -f .agent/projects.local`.

---

## Experiment 5 — Nested worktree exclusion (git and colcon)

**git — scratch repo:**
```bash
git init -q "$SPIKE/exp5/scratch-repo" && cd "$SPIKE/exp5/scratch-repo"
git commit ... ; git branch feature-x
git status --short                      # (clean)
git worktree add -q worktrees/x feature-x
git status --short                      # → ?? worktrees/
echo "worktrees/" >> .git/info/exclude
git status --short                      # → (clean again)
git status --short --ignored            # → !! worktrees/   (confirms it's excluded, not just coincidentally clean)
```

**colcon — scratch workspace:**
```bash
mkdir -p "$SPIKE/exp5/colcon-ws/src/pkg_a"              # package.xml for pkg_a
mkdir -p "$SPIKE/exp5/colcon-ws/worktrees/x/src/pkg_b"  # package.xml for pkg_b (simulates a nested worktree checkout)
cd "$SPIKE/exp5/colcon-ws"
colcon list
# → pkg_a  src/pkg_a               (ros.catkin)
#   pkg_b  worktrees/x/src/pkg_b   (ros.catkin)     <- picked up before COLCON_IGNORE

touch worktrees/COLCON_IGNORE
colcon list
# → pkg_a  src/pkg_a  (ros.catkin)                  <- pkg_b gone
```

**p11-jazzy layout (read-only; no build run):**
`/home/roland/agent_workspace/projects/p11-jazzy/` has `configs/` and
`layers/main/{core_ws,platforms_ws,sensors_ws,simulation_ws,site_ws,ui_ws,
underlay_ws}/`, each an independent colcon workspace with its own
`src/build/install/log`. Under design B, `worktrees/` for this project would
sit at the **project root** (`projects/p11-jazzy/worktrees/`), a sibling of
`layers/`, not inside any individual `*_ws`. A `COLCON_IGNORE` dropped there
protects against `colcon list`/`build` run with `--base-paths
projects/p11-jazzy` (or any recursive discovery rooted above `layers/`);
each `*_ws` build invoked directly (`colcon build` from inside `core_ws/`,
as the adapter's `build` verb presumably does per-layer) would never
traverse into `worktrees/` at all, since it isn't an ancestor of that
workspace's `src/`.

**Verdict:** PASS for both the git and colcon mechanisms; the p11-jazzy
placement is a documented (read-only) inference, not something exercised
against the real checkout, per the instruction not to build it.

---

## Experiment 6 — Per-project `CLAUDE.md` survives an in-session `cd` into a worktree

**Not directly testable** — same nested-session auth blocker. What I can
state: Claude Code's documented context-loading model reads `CLAUDE.md`
files from the launch working directory and its filesystem ancestors once,
at session start (not per-tool-call or per-`cd`). A worktree created under
`<project-root>/worktrees/x` is a descendant of `<project-root>`, so a
`CLAUDE.md` at `<project-root>` would remain an ancestor of the worktree
path and, per that model, should stay loaded after `/start-task`-style `cd
worktrees/x` within the same session. Directly launching `claude -p` **from**
`worktrees/x` should equally pick it up via ancestor-walk from the launch
dir. Both are exactly the two cases the brief asked for; neither was
observed live.

**Verdict:** BLOCKED. Flag this as the single most important experiment to
re-run with real credentials before the plan finalizes decision #1's "the
per-project CLAUDE.md stays an ancestor after `/start-task` cd's into a
worktree" consequence — it's currently an inference, not a confirmed fact.

---

## Experiment 7 — One root variable for `.agent/scripts` / `.claude/hooks` references

```bash
ls .claude/skills/*/SKILL.md | wc -c   # 20 skills total
grep -rlE '(^|[^/A-Za-z0-9_.-])\.agent/scripts|(^|[^/A-Za-z0-9_.-])\.claude/hooks' .claude/skills/*/SKILL.md | wc -l
# → 11
```
11 of 20: `analyze-permissions`, `issue-triage`, `onboard-project`,
`review-code`, `research`, `plan-task`, `gather-project-knowledge`,
`triage-reviews`, `start-task`, `audit-workspace`, `inspiration-tracker` —
matches the issue's "11 of 20 skills reference `.agent/scripts` relatively"
figure exactly.

```bash
grep -o '"\.claude/hooks/[^"]*"' .claude/settings.json
# → ".claude/hooks/log-tool-use.sh"
#   ".claude/hooks/block-bash-tool-mapping.sh"
```
Both hook `command` entries in `.claude/settings.json` are relative.

**Existing partial precedent:** `.agent/scripts/adapter`,
`gh_create_pr.sh`, `gh_create_issue.sh`, and `generate_make_skills.sh`
already derive a `WORKSPACE_ROOT`/`_WORKSPACE_ROOT` variable from
`BASH_SOURCE[0]` (their own script path), which is cwd-independent —
**for scripts invoked by absolute path**, this already solves the problem
with zero new mechanism. It does *not* help skill **prose**, which
instructs the agent in Markdown to run `.agent/scripts/foo.sh` as literal
relative text — the agent (not a script) resolves that path against
whatever its cwd happens to be.

**Resolution mechanism demonstrated:** the experiment-2 SessionStart hook
prototype already has everything needed — it knows `AGENT_WORKSPACE_ROOT`
(the fixed location the hook script itself is installed relative to, or a
value baked in at install time) and could `export` or print it as a
session-visible marker/env var. Concretely: a user-tier SessionStart hook
run from a registered project cwd would emit a line such as
`export AGENT_WORKSPACE_ROOT=/home/roland/agent_workspace` (or, if hooks
can't mutate the caller's env, print it as part of the injected
instructions block: "Workspace scripts live at
`$AGENT_WORKSPACE_ROOT` = `/home/roland/agent_workspace`"). Skill bodies
would then reference `$AGENT_WORKSPACE_ROOT/.agent/scripts/foo.sh` instead
of `.agent/scripts/foo.sh`, resolving correctly regardless of the session's
actual cwd (workspace session, project root, or a worktree beneath either).

**Verdict:** PASS. Migration list is the 11 skills + 2 hook commands above;
a regression test would grep skill/hook sources for a bare (non-`$AGENT_WORKSPACE_ROOT`-prefixed)
`.agent/scripts` or `.claude/hooks` reference and fail the build if found
outside an explicit allowlist (e.g. workspace-only skills that are never
run from a project session, if any remain intentionally relative).

---

## Experiment 8 — Context cost of unconditional import vs. conditional injection

```bash
wc -c < AGENTS.md    # 18475
wc -c < CLAUDE.md    # 3440
cat AGENTS.md CLAUDE.md | wc -c   # 21915
```

At ~4 chars/token: 21,915 / 4 ≈ **5,479 tokens**. An unconditional
`~/.claude/CLAUDE.md` `@`-import of `AGENTS.md` (as floated in the
2026-09-15 comment, and superseded by the SessionStart-hook direction in the
2026-09-16 decision) would load this into **every** session on the machine,
including ones in repos with nothing to do with this workspace or its
registered projects — paid once per session as part of the system-prompt
context, and repeatedly if `CLAUDE.md` content isn't cache-friendly across
unrelated repos (it wouldn't be, since cwd/env sections differ per session
regardless).

The conditional SessionStart-hook alternative (experiment 2) pays **0
bytes** of injected instruction content in an unrelated repo, at a measured
standalone cost of ~5.5ms per session start for the stand-down branch (see
experiment 2's caveat: that's a lower bound, not the real in-hook-runner
cost).

**Verdict:** PASS for the byte/token measurement (directly computed).
INCONCLUSIVE for corroborating this against a live session's actual
reported context size — `-p --output-format json` can report token usage,
but getting that from a nested session hit the same auth blocker as
experiments 1/2/3a/6.

---

## Authenticated follow-up run (experiments 1, 2, 3a, 6)

Run by the owner from the main session on 2026-09-16 with
`spike265_auth.sh` (scratchpad, not committed). The script copied
`~/.claude/.credentials.json` into a throwaway `CLAUDE_CONFIG_DIR`, built a
fake user tier there (SessionStart hook gated on `.agent/projects.local`,
`PreToolUse` hook logging to a file, two symlinked skill dirs), launched
`env -u CLAUDECODE CLAUDE_CONFIG_DIR=<tmp> claude -p ...` sessions, and
deleted the temp dir on exit. The real `~/.claude/` was not modified.

### Observations

**1 — symlinked skills.** From a scratch unrelated git repo, "list every
skill available to you" returned `audit-workspace` and `what-next` (the two
symlinks) alongside the built-ins. PASS.

**2 — SessionStart injection.** From `/home/roland/src/gz4d` (registered
`single_project`), the session quoted its context line verbatim:

```
SessionStart:startup hook success: SPIKE265-WORKSPACE-LAYER project=gz4d type=single_project root=/home/roland/src/gz4d
```

From the unrelated repo the only `SPIKE265` match was the prompt itself.
PASS both ways. The nested session's auto-memory directory was under the
fake config dir, confirming `CLAUDE_CONFIG_DIR` redirects memory too.

**3a — absolute-path PreToolUse hook.** One `echo hook-probe` turn from
`gz4d` produced three `PRETOOL-FIRED cwd=/home/roland/src/gz4d` lines in
the log (the hook fires per Bash call, including the model's own extra
calls). PASS.

**6 — project `CLAUDE.md` vs nested worktree.** Scratch git repo with
`CLAUDE.md` = `MARKER-ROOT-265`, a real `git worktree add worktrees/x`
containing `CLAUDE.md` = `MARKER-WT-265`, `worktrees/` in
`.git/info/exclude`.

| Launch dir | Action | Markers seen |
|---|---|---|
| project root | Bash `cd worktrees/x && ls`, then report | `MARKER-ROOT-265` only, from the file loaded at start; the worktree's `CLAUDE.md` was listed by `ls` but not loaded |
| `worktrees/x` | report | `MARKER-WT-265` only |
| `worktrees/x` with its `CLAUDE.md` removed | report | `NONE` |

So on Claude Code 2.1.273: instruction files are loaded once from the
launch directory; an in-session `cd` neither drops the launch-dir file nor
loads the target's. And a nested git worktree is **not** given its parent
directory's `CLAUDE.md` as an ancestor. This is the load-bearing finding
for decision 1 in the issue: the cmake-style layout keeps the project layer
only for sessions launched at the project root, not for sessions launched
inside a worktree. The registry-gated SessionStart hook resolves it: it
already knows the root for any cwd beneath it and can inject the project
layer along with the workspace layer, making ancestor walking irrelevant.

### Caveats

- All "markers seen" results are the nested model's self-report of its
  context, consistent across runs but not a byte-level dump.
- The two sessions launched in `gz4d` mentioned the status-line rule that
  lives only in the real `~/.claude/CLAUDE.md`; `gz4d`'s own `CLAUDE.md`
  does not contain it. Either `CLAUDE_CONFIG_DIR` does not redirect the
  user-level `CLAUDE.md`, or something else in that tree supplied it. Not
  resolved; irrelevant to the design (which installs into the real tier)
  but relevant to anyone reusing the fake-tier method.

## Cleanup performed

- Removed `.agent/projects.local` written into the worktree for experiment 4.
- Removed all scratch git repos and the fake config dir under
  `/tmp/claude-1000/-home-roland-agent-workspace/<session>/scratchpad/spike265/`
  after the run (`exp2`, `exp4`, `exp5`, `fake-config`).
- No files in `/home/roland/agent_workspace` (main tree) or
  `/home/roland/.claude/` were read (beyond the explicitly-permitted,
  read-only listing of `projects/p11-jazzy/` for experiment 5) or modified.
- `/home/roland/src/gz4d` was referenced only as a path string in scratch
  registry files (never `cd`'d into, built, or modified).
