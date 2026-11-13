# Inspiration Digest: project-codeguard

Type: inspiration
Last checked: 2026-11-13
Repo: cosai-oasis/project-codeguard @ 41160d54980bab0618165485ade3cfd2ade93288
Previously checked: 2026-09-14 @ d6a04cc5bfee65fc400a931fcaff5926d2d9bfe8

Registry interest areas: secure-by-default rule design for agent workflows;
rule packaging and distribution format; integration with review pipelines;
model-agnostic enforcement mechanisms.

## Changelog (2026-09-14 → 2026-11-13)

16 commits, 81 files changed, `d6a04cc...41160d5` with status `ahead`
(0 behind) on the GitHub compare API; complete, not truncated (16 commits
listed of 16 reported; 81 files is under the API's file cap). The clone was
moved to `41160d5` with `git fetch --depth=1 origin` and `git reset --hard
origin/main` (git reported a forced update of the shallow ref, a side effect
of the shallow history; the compare API confirms the old SHA is an ancestor).
Several listed commits carry dates before 2026-09-14 because they are branch
commits that were merged after that date.

Merged since the last check: #123 (MCP server publish address configurable,
default `127.0.0.1`), #109 (Devin host support alongside Windsurf), #128
(SecurityEval isolation and generation controls), #124 (ADR 0001 accepted),
#126 (narrower `languages:` in 12 core rules), #131 (dependency updates for
Dependabot alerts), #133 (v1.5.0 release prep), #137 (SecurityEval reporting
plus published 1.4.0 results). Closed issues: #121, #94, #61, #37.

What bears on the interest areas:

- **Release line.** v1.5.0 (published 2026-09-29) is stated in release issue
  #132 to be "the last release of the rule-file version of CodeGuard":
  "2.0 moves to the portable skill (#125), and 1.x continues on a
  `release/1.x` branch for security fixes only". The `release/1.x` branch
  step was still unchecked in #132 when read. #125 ("Track CodeGuard skill
  modernization and validation") is the 2.0 tracker and was marked stale by
  the bot on 2026-10-31. PRs #112 (agent-skill security rule) and #113 (APM
  install path) were "held as input for 2.0" / "to be reshaped for the 2.0
  skill" per #132, and are still open.
- **Over-targeting fix landed (#126, resolves #121).** The generated
  `skills/codeguard/SKILL.md` language table now maps `javascript` to 16 rule
  files (it listed 18 in 1.4.0; counted from the file diff; with the 3
  always-apply rules that is 19 of 23, against the 21 of 23 reported in
  #121), `c` from 14 to 9, `xml` from 6 to 3, `yaml` from 11 to 6; the `d`, `matlab`, `perl` and
  `vlang` rows were removed. The skill's `description` and "When to Use"
  section were not changed: they still say to use it when "writing new code
  in any language". #117 (skill fails to activate, "too broad") is therefore
  still open with its cause untouched; it was marked stale on 2026-10-10 and
  has 1 comment.
- **First published effect numbers (#137, `docs/results/2026-09-codeguard-1.4.0/`).**
  SecurityEval, 121 cases, Semgrep findings (not confirmed vulnerabilities).
  Model "GPT-5.6 Sol" (111 shared cases): baseline 42 findings / 17 high+medium
  at $10.55 total; a plain "secure prompt" 22 / 4 at +19.4% cost; CodeGuard
  1.4.0 26 / 6 at +187.6% cost, 162.4K tokens per case vs 42.7K, 9 of 121
  attempts unfinished (baseline 1). Model "GPT-5.6 Luna" (116 shared
  cases): baseline 47 / 18; secure prompt 30 / 8 (+24.4%); CodeGuard 35 / 11
  (+65.1%). So in these runs a short secure prompt cut findings about as much
  as, or more than, the skill, at a fraction of the token cost. The page
  itself says harness snapshots differ between runs and that findings are
  scanner results only. Cost figures are the project's own estimates; not
  independently checked.
- **Consumer-update workflow hardening (`update-codeguard-rules.yml`).** It now
  reads the vendored version from `SKILL.md` (`codeguard-version:`) for
  Agent Skill bundles, reports `mixed` when detected formats disagree,
  validates the downloaded archive before deleting existing files, and also
  refreshes `SKILL.md` along with the rules. Adds the `.devin` format.
- **MCP server default.** #123 makes the Docker published port bind to
  `127.0.0.1` by default (`CODEGUARD_PUBLISH_ADDRESS`) and documents that a
  reverse proxy must provide TLS and authentication. Same lesson as the
  diffx loopback note; no action here.
- **Governance.** ADR 0001 (guidance vs runtime and scanning) went from
  Proposed to Accepted (#124). New open issue #139 asks for a versioning
  policy ADR; a maintainer proposal in the thread treats changes to
  activation, rule-selection strategy or required review steps as *major*
  releases even when the install keeps working.
- **Open PR #135** (2026-11-10 update): pinned Prettier + markdownlint over
  `sources/` and generated output, `.editorconfig`/`.gitattributes`, Ruff and
  Pylint/Pyright in CI, and a CI rule that each top-level `src/*.py` module's
  own test file covers at least 95% of its statements. Prompted by issue
  #134, a downstream user reporting thousands of markdownlint violations in
  the shipped rules (MD013 line length 3,564; MD041 207 because the converter
  puts `rule_id:` before the first heading; and others).
- **Not read in detail:** the 727-line `samples.csv`, the evaluation harness
  code changes (`export_results.py`, `results_report.py`), #136 (local-model
  evaluation at 4K and 8K contexts), #140 (CyberSecEval), #138 (firmware
  rules), #141 (rewritten logging rule, read only the PR description).

Corrections to the 2026-09-14 survey above:

- "#37 (precedence between CodeGuard and other skills/MCP tools — open,
  unanswered)" — #37 closed 2026-10-06 (completed). The outcome was not read.
- "Fix PR #126 (open) narrows the frontmatter in 12 rules" and the "JavaScript
  task loads 21 of 23 rules" statement — #126 merged 2026-09-29; JavaScript
  now maps to 16 table rules plus the 3 always-apply rules (19 of 23; 21
  before).
- "Lightweight ADR practice ... status Proposed" — ADR 0001 is Accepted
  (2026-09-29).
- Activity Snapshot "last release v1.4.0" — now v1.5.0 (see below).
- Survey line "Governance ... nothing to port" for ADRs stands.

## Survey Summary (first run, 2026-09-14)

**What it is.** An OASIS/CoSAI open project (CC BY 4.0, 336 stars, 63
forks) that publishes a corpus of ~23 core + ~85 OWASP security *rules* as
plain markdown with YAML frontmatter, plus two authored skills
(`security-review`, `memory-safe-migration`) and one read-only reviewer
subagent. A Python converter (`src/convert_to_ide_formats.py`) emits the
same sources into nine host-specific layouts (Claude, Codex, Cursor,
Windsurf, Copilot, Antigravity, OpenCode, OpenClaw, Hermes); release
automation zips each layout and publishes SHA256SUMS. There is also an MCP
server (`src/codeguard-mcp/`) that serves the rules as tools for
centrally-managed installs. Its "enforcement" is entirely
instruction-level: rules load into the agent's context by glob/language
match; nothing runs as a hook or gate.

### Mapped to workspace categories

- **Governance model** — Standards-body governance (CoSAI TSC, OASIS
  code of conduct, AI-usage guidelines). Issue-first: contributors must
  find/open an issue and wait for maintainer assignment before large
  work. Two issue-form templates (`new-rule.yml`, `rule-feedback.yml`)
  channel rule proposals so the maintainers own metadata/conversion.
  Lightweight ADR practice added 2026-08 (`docs/adr/`, one record so far,
  status Proposed): ADR-0001 draws a boundary that guidance must not
  claim runtime state or detection guarantees — scanning and incremental
  state belong to tools, not rule text. Same shape as our ADR practice;
  nothing to port.
- **Skills / commands** — Authored sources live in `sources/`
  (`rules/core`, `rules/owasp`, `skills/`, `agents/`, `templates/`);
  `skills/codeguard/` is a *committed generated artifact* (the Claude
  Agent Skill) regenerated by the converter and checked in CI. The
  generated `SKILL.md` is a routing table: three always-apply rules,
  a tag→rules table, and a language→rules table; rule bodies live in
  `rules/` beside it (progressive disclosure). Two open issues are the
  most instructive things in the repo for *our* skill authoring:
  - #117 — the skill "fails to activate": five Claude Code users had zero
    activations in 30 days; the agent reported the skill as "too broad"
    and preferred a narrower competing security skill.
  - #121 — `languages:` over-targeting: a JavaScript task loads 21 of 23
    rules (~27k tokens), so progressive disclosure "delivers close to
    nothing". Fix PR #126 (open) narrows the frontmatter in 12 rules.
  Together: a skill that declares itself relevant to everything is
  skipped by the agent *and* expensive when it does load.
- **Isolation strategy** — Not a code-execution project; the only
  isolation is in the evaluation harness (networkless Codex container +
  separately isolated, digest-pinned Semgrep service; generated code is
  never executed) and in the reviewer subagent contract (read-only,
  single SARIF write, repo content treated as untrusted data). Per-host
  permission frontmatter is generated from `src/artifact_targets.py` —
  e.g. the OpenCode reviewer gets `bash: deny`, `edit: deny` except
  `codeguard-findings-*.sarif: ask`, `webfetch/websearch: deny`.
- **Identity management** — None beyond GitHub; bot commits use the
  `github-actions[bot]` identity. Not relevant.
- **Testing approach** — Three layers: (1) `validate_unified_rules.py`
  enforces the rule frontmatter schema (`description` required;
  `languages` XOR `alwaysApply`; tags must be in `KNOWN_TAGS`; non-empty
  body); (2) `validate_versions.py` asserts one version string across
  `pyproject.toml`, both plugin manifests, the marketplace manifest and
  the generated `SKILL.md`, and the release workflow re-checks it against
  the git tag; (3) a new Inspect-AI evaluation harness
  (`evaluations/codeguard-inspect/`, merged 2026-09-08) runs 121
  SecurityEval cases under baseline / secure-prompt / skill-installed
  conditions and scores Semgrep findings plus a `skill_loaded` signal.
  The scanner contract is pinned by image digest and a rules-tree
  content hash; a rules update is a reviewed lock change plus a full
  rerun. This is the first upstream we track that measures whether a
  skill *changes agent behaviour* rather than asserting it.
- **CI/CD patterns** — Path-filtered `validate-rules.yml` (schema +
  versions + required-file presence), `validate-codeguard-evaluations.yml`
  (pytest + Inspect task discovery + `docker compose config`), release
  build on `release: published` (validate → convert → zip per host →
  SHA256SUMS → upload), docs deploy, stale bot, and a *consumer-side*
  workflow `update-codeguard-rules.yml` that downstream repos vendor:
  monthly it detects which host directories exist, compares the vendored
  `version:` to the latest release, downloads only the matching zips,
  warns on legacy paths, and opens/refreshes a single
  `codeguard-rules-update` PR. All actions pinned to immutable SHAs
  (PR #108, 2026-08).
- **Documentation patterns** — MkDocs site; `docs/install-paths.md` is a
  decision guide keyed on *who is deploying* (individual / team-repo /
  org) with explicit admin responsibilities and scope precedence
  (org baseline → project → user-scope trial), and a decision tree
  choosing between rule files, Agent Skills, marketplace plugin, remote
  instructions, org dashboard and MCP. `docs/custom-rules.md` documents
  how a downstream adds `sources/rules/<own>/` and builds with
  `--source core my-rules`.

### Relation to what this workspace already has

- Our `security-review` is Claude Code's built-in (pending changes on the
  current branch). CodeGuard's `security-review` skill is a *whole-repo*
  audit that loads the rule corpus and emits a formal report; the
  `codeguard-reviewer` subagent emits SARIF. They are complementary, not
  duplicates, and installing CodeGuard is a user-scope or project-scope
  decision (`/plugin install`, vendored rule files), not workspace
  infrastructure.
- The roadmap's **fail-closed hook audit** (from gstack) is about our
  enforcement hooks (`.claude/hooks/block-bash-tool-mapping.sh`,
  pre-commit, `.agent/hooks/*.py`) failing closed. CodeGuard has no hook
  layer at all — its enforcement is advisory context. The only overlap
  is thematic: PR #112's agent-skill rule asks for logging of all agent
  actions and human approval on high-risk actions, which is the same
  posture the hook audit protects.
- Our skill sources are hand-authored per host (`CLAUDE.md`, `CODEX.md`,
  `.github/copilot-instructions.md`, gemini adapter). CodeGuard's
  single-source → multi-host emission is the generated alternative; the
  `harness-starter-kit` registry entry already tracks cross-harness
  portability, so this is a second data point, not a new topic.
- `skill-importer` checks redundancy, format, safety and attribution.
  PR #112 is a concrete, external checklist for the "safety" part.

### Relevance to the workspace redesign (issue #172)

Two things bear on the adapter / manifest design; neither changes its
direction:

1. **Per-project rule packs are a natural manifest payload.** CodeGuard's
   own docs model exactly the layering #172 proposes — org baseline,
   project-scoped vendored rules, user-scope trials — and its consumer
   workflow shows what "the manifest carries a vendored rules pack and
   keeps it fresh" looks like: detect host dirs present, compare
   vendored version to upstream release, PR the delta. A manifest's
   `.project_config` could name a rules pack (upstream bundle version +
   optional `sources/rules/<project>/` custom rules) and `adapter sync`
   could refresh it, with the *workspace* never carrying project-specific
   rules. This is additive to the current design.
2. **Host-surface generation from sources.** #172 already plans
   `.claude/commands/` "assembled per machine from active types"
   (gitignored). CodeGuard's `artifact_targets.py` is a compact worked
   example of a per-host emission table (frontmatter, rules dir, file
   extension, permission block per host) that the assembly step could
   grow into if the workspace ever emits Codex/Copilot surfaces from one
   source rather than maintaining them by hand.

## Activity Snapshot (2026-11-13)

- 19 open issues, 6 open PRs (#141, #136, #135, #113, #112, #82); 371 stars,
  75 forks (2026-09-14: 336 stars, 63 forks). Last release v1.5.0
  (2026-09-29); last commit on `main` 2026-10-12 (merge of #137); repo push
  timestamp 2026-10-27 (not matched to a commit on `main`; not checked).
- Four issues closed since 2026-09-14 (#121, #94, #61, #37); 8 PRs merged.
- Cadence: slowed. Direction is a rewrite: rule files are frozen after 1.5.0
  and effort moves to a 2.0 portable skill (#125). Open issues #117, #125 and
  others were marked stale by the bot between 2026-10-10 and 2026-10-31.
  Contributor and downstream-user activity is still coming in (#134, #138,
  #139, #140, PR #141).
- Notable for our interest areas: #117 (still open, cause untouched), #125
  (2.0 tracker), PR #112 (agent-skill security rule, held for 2.0, 5
  comments, updated 2026-11-03), the published SecurityEval numbers above,
  #139 (versioning policy), PR #135 (lint and coverage gates).

(2026-09-14 snapshot, kept: 15 open issues, 9 open PRs; 7 PRs merged and 9
issues closed in the previous 60 days; v1.4.0 (2026-06-29); last push
2026-09-08; #37 open.)

## Pending Review

(2026-09-14 items are decided below.)

(none pending from this round)

## Decided (2026-11-13)

Roadmapped (addenda to existing roadmap lines, no new lines):

- **codeguard-2.** `secure-prompt-vs-skill-effect-numbers` — addendum to the
  "Skill-authoring guidance knowledge doc" line, citing the published
  three-condition SecurityEval numbers: short secure prompt 22 findings at
  +19% cost vs full skill 26 at +188% on one model; 30 vs 35 on the other.
  Scanner findings, upstream's own cost estimates, not independently
  checked. Cross-referenced to the `gstack-1` retirement criterion
  (2026-11-13)
- **codeguard-3.** `activation-fix-incomplete` — one sentence added to the
  "Skill activation and targeting evidence" line: the targeting half (#121)
  was fixed upstream, the activation half (#117) is still open (2026-11-13)

Skipped:

- **codeguard-4.** `consumer-update-workflow-validate-then-replace` —
  informational: a small pattern (never delete before the replacement is
  verified) that belongs to the roadmapped `manifest-carried-rule-packs`
  when that is built (2026-11-13)
- **codeguard-6.** `source-lint-and-per-module-coverage-gate` — open,
  unmerged, mostly Python tooling this workspace does not have; overlaps the
  roadmapped `skill-source-schema-and-version-gate` only in spirit
  (2026-11-13)

## Deferred (2026-11-13 decisions)

- **codeguard-1.** `rule-files-frozen-skill-2.0-direction` — v1.5.0 is the
  last rule-file release; 2.0 is a portable skill. Re-check the two earlier
  decisions it affects (`manifest-carried-rule-packs`,
  `single-source-multi-host-emission`) once the 2.0 shape is visible
  (2026-11-13)
- **codeguard-5.** `behaviour-change-is-a-major-version` — issue #139's
  proposal that changes to activation, selection or required steps are major
  releases. Discussion only; no upstream decision (2026-11-13)

## Roadmapped (2026-09-14 decisions)

- `skill-activation-and-targeting-evidence` — Upstream field evidence
  that a skill declared relevant to "any code" is skipped by agents as
  "too broad" (#117) and, when it does load, over-broad `languages:`
  targeting pulls ~90% of the corpus into context (#121). Lesson for our
  skill descriptions and for any progressive-disclosure layout: derive
  applicability from what the skill actually governs, and keep the
  activation description narrow enough that the agent believes it.
  Candidate addendum to the already-roadmapped "Skill-authoring guidance
  knowledge doc" (superpowers, 2026-07-14). Relevance: High. — added to ROADMAP.md via the consolidated 2026-09-14 sweep block in the gstack digest PR (2026-09-14)
- `agent-skill-security-checklist` — PR #112's
  `codeguard-0-ai-agent-skills.md`: tool allowlists instead of "do
  anything" tools, explicit filesystem/network boundaries, parameterised
  shell, timeouts, logging of all actions, human approval for high-risk
  actions (delete, push, infra). Concrete external checklist for
  `skill-importer`'s safety check and for `audit-workspace`; thematically
  adjacent to the fail-closed hook audit. Relevance: Medium. — added to ROADMAP.md via the consolidated 2026-09-14 sweep block in the gstack digest PR (2026-09-14)
- `manifest-carried-rule-packs` — For #172: model a project's security
  rules as a manifest payload (upstream bundle version + optional custom
  rule sources) refreshed by `adapter sync`, following CodeGuard's
  consumer-side update workflow (detect host dirs, compare vendored
  version to release, single refresh PR, legacy-path warnings). Keeps
  project-specific rules out of the workspace by construction. Relevance:
  High for the redesign; no change to its direction. — added to ROADMAP.md via the consolidated 2026-09-14 sweep block in the gstack digest PR (2026-09-14)
- `skill-source-schema-and-version-gate` — CI gate pattern:
  frontmatter-schema validator for authored skill/rule sources (required
  fields, mutually exclusive targeting fields, closed tag vocabulary,
  non-empty body) plus a one-version-everywhere check across manifests
  and generated files, re-run against the tag at release. We validate the
  adapter contract but not skill frontmatter; `audit-workspace` could
  grow a schema check. Relevance: Medium. — added to ROADMAP.md via the consolidated 2026-09-14 sweep block in the gstack digest PR (2026-09-14)

## Skipped (2026-09-14 decisions)

- `codeguard-as-project-baseline` — Adopting CodeGuard itself (plugin
  install or vendored rule files) is a per-project or per-user decision,
  not workspace infrastructure; a project that wants it records that in
  its own repo/manifest. Listed so the decision is explicit. Relevance:
  Low for the workspace. — skipped: per-project/per-user adoption decision, not workspace infrastructure (2026-09-14)

## Deferred (2026-09-14)

- `read-only-reviewer-with-structured-findings` — `codeguard-reviewer`
  contract: read-only on source, single SARIF 2.1.0 findings file as the
  only write, repo content treated as untrusted (prompt-injection
  clause), secrets redacted in evidence, candidates re-verified at the
  cited line before emission, per-host permission blocks generated from
  one table. Convergent with the roadmapped superpowers "reviewers are
  read-only" rule; the new piece is a machine-readable findings format
  that `triage-reviews` could consume. Relevance: Medium. — revisit on a later run (2026-09-14)
- `single-source-multi-host-emission` — `sources/` → converter →
  per-host bundles with a committed generated skill and a per-host
  emission table (`artifact_targets.py`). Second data point for the
  cross-harness portability topic already tracked via
  `harness-starter-kit`; relevant to #172's per-machine assembly of
  `.claude/commands/` if the workspace ever generates Codex/Copilot
  surfaces from one source. Relevance: Medium, redesign-dependent.
  — revisit on a later run (2026-09-14)
- `skill-efficacy-eval-harness` — Inspect-AI harness comparing
  baseline / secure-prompt / skill-installed conditions with a
  `skill_loaded` signal and a digest-pinned scanner contract. First
  tracked example of measuring whether a skill changes agent output;
  heavy (Docker, pinned Semgrep) and security-specific, but the
  three-condition design is the reusable idea — it is the rigorous form
  of superpowers' "micro-test wording" advice. Relevance: Low–Medium.
  — revisit on a later run (2026-09-14)
