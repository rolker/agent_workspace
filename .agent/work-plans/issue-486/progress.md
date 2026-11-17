---
workflow: collaborative
issue: 486
---

# Issue #486 — ros-manifest: its own goals, design and roadmap, with no mention of the workspace

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-17 14:13 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Verdict**: changes-requested

**Branch**: feature/issue-486 at `9b382a4c`
**Base**: origin/main
**Depth**: Deep (reason: 1718 changed lines, docs only)
**Must-fix**: 9 | **Suggestions**: 14
**Round**: 1 | **Ship**: continue — 9 must-fix, several are design questions

Specialists: governance, Claude adversarial, Gemini (complete). Codex failed (usage limit). Static analysis: no profile for Markdown. Plan drift: no work plan.

### Findings
- [x] (must-fix) A child that replaces the top-level distros list leaves inherited per-distro entries undefined (gemini, adversarial) — `tools/ros-manifest/docs/spec.md:309`
- [x] (must-fix) Git URLs: no transport rule (ext:: runs a command at clone), base location values unchecked, prototype.md says URL rules carry over (gemini, adversarial) — `tools/ros-manifest/docs/spec.md:396`
- [x] (must-fix) Containment check is incomplete: a key that is a prefix of another, a .git path component, layer names as paths, names colliding with src/build/install/log/.repos-manifest or a distro directory (gemini, adversarial) — `tools/ros-manifest/docs/spec.md:394`
- [x] (must-fix) sync contradicts itself: repos follow the current manifest, yet a repo on another branch than the manifest names is left alone, so a changed version never applies (adversarial) — `tools/ros-manifest/docs/design.md:286`
- [x] (must-fix) freeze keeps a repo's distros block, so a per-distro version still overrides the frozen commit; frozen url unstated (adversarial) — `tools/ros-manifest/docs/design.md:334`
- [x] (must-fix) Claim "one repo with local changes makes the whole run fail" did not reproduce with vcs2l 1.1.7 (adversarial) — `tools/ros-manifest/docs/design.md:282`
- [x] (must-fix) Example names a private repo in new prose (governance) — `tools/ros-manifest/docs/spec.md:54`
- [x] (must-fix) README states unbuilt behaviour in the present tense under "Why another tool" (governance) — `tools/ros-manifest/README.md:66`
- [x] (must-fix) Adapter comment cites the tool README for clone-protection rules that moved to docs/prototype.md (governance) — `.agent/project_types/ros2_colcon/adapter.sh:639`
- [x] (suggestion) With repo-level absent: true, the meaning of a distro entry of {}, {absent: true} or {absent: false} is unstated — `tools/ros-manifest/docs/spec.md:142`
- [x] (suggestion) A role or an extra group naming an undeclared group is undefined — `tools/ros-manifest/docs/spec.md:241`
- [x] (suggestion) repositories, type and url are marked required but a later manifest may omit them; a child entry matching nothing in the parent is undefined — `tools/ros-manifest/docs/spec.md:81`
- [x] (suggestion) The unnamed layer's .repos file has no stated name; unstated whether an empty layer gets a file — `tools/ros-manifest/docs/design.md:259`
- [x] (suggestion) fetch_from: "the published manifest" is undefined in a chain; repos added by the machine's own manifest unclear — `tools/ros-manifest/docs/design.md:394`
- [x] (suggestion) fetch_from URL as written ends in .git.git — `tools/ros-manifest/docs/design.md:361`
- [x] (suggestion) show says it fetches nothing but reads parents from git and, with fallback, asks the other place — `tools/ros-manifest/docs/design.md:190`
- [x] (suggestion) sync step 1 does not say which branch the manifest's clone is updated on — `tools/ros-manifest/docs/design.md:267`
- [x] (suggestion) The git form of manifest has no config.yaml shape, and no CLI way to set fallback — `tools/ros-manifest/docs/design.md:142`
- [x] (suggestion) Development machine walkthrough: init line lacks the fetch-from and remotes options the config then holds — `tools/ros-manifest/docs/design.md:482`
- [x] (suggestion) prototype.md understates what an extension may do (merge.py also adds to existing groups and roles) — `tools/ros-manifest/docs/prototype.md:17`
- [ ] (suggestion) Put the sitrep_checks.sh --root form in the PR description; without it the roadmap's first check reads false — `tools/ros-manifest/docs/roadmap.md:10`
- [ ] (suggestion) List in the PR where the documents depart from the issue text (base, no overrides section, optional repos, the name, prototype.md) — `tools/ros-manifest/README.md:1`
- [ ] (suggestion) Owner to accept or reword the three links to the workspace issue tracker — `tools/ros-manifest/docs/prototype.md:72`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-17 14:23 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Verdict**: changes-requested

**Branch**: feature/issue-486 at `4067a6ef`
**Base**: origin/main
**Depth**: Deep (reason: 1700+ changed lines, docs only)
**Must-fix**: 4 | **Suggestions**: 10
**Round**: 2 | **Ship**: continue — 4 must-fix, all mechanical, down from 9

Specialists: Claude adversarial, Gemini (complete). Codex failed (usage limit). Governance findings of round 1 checked inline (resolved). Static analysis: no profile for Markdown. Plan drift: no work plan.

### Findings
- [x] (must-fix) sync step 1 updates parent manifests' clones before the chain is known (gemini) — `tools/ros-manifest/docs/design.md:283`
- [x] (must-fix) "Any URL git can clone works" contradicts the transport rule (adversarial) — `tools/ros-manifest/docs/spec.md:289`
- [x] (must-fix) freeze leaves repo-level absent in place, so a repo present only by a distro entry is frozen as absent; a repo absent on the distro would come back (adversarial, gemini) — `tools/ros-manifest/docs/design.md:356`
- [x] (must-fix) A location's path may be absolute; the sentence that git is handed nothing that runs a program overstates (gemini) — `tools/ros-manifest/docs/spec.md:407`
- [x] (suggestion) Where sync records the last version is unstated; a repo with no record is undefined — `tools/ros-manifest/docs/design.md:302`
- [x] (suggestion) A local path as url does not exclude the name::address transport form; file:// neither listed nor refused — `tools/ros-manifest/docs/spec.md:409`
- [x] (suggestion) "No key is the start of another key's path" can be read as a string prefix — `tools/ros-manifest/docs/spec.md:400`
- [x] (suggestion) base is "one or more" manifests but the list form is never stated — `tools/ros-manifest/docs/spec.md:270`
- [x] (suggestion) A chain "that comes back to a manifest already read" also catches two parents sharing a parent — `tools/ros-manifest/docs/spec.md:335`
- [x] (suggestion) A later manifest cannot clear an inherited absent: true or optional: true — `tools/ros-manifest/docs/spec.md:123`
- [x] (suggestion) fetch_from does not cover a parent manifest given in the git form — `tools/ros-manifest/docs/design.md:418`
- [x] (suggestion) freeze and build's setup.bash are undefined for a system directory with several distros — `tools/ros-manifest/docs/design.md:357`
- [x] (suggestion) show "before anything is fetched" sits against the later paragraph on what it fetches — `tools/ros-manifest/docs/design.md:231`
- [x] (suggestion) Roadmap prose says each line has a check; most do not yet — `tools/ros-manifest/docs/roadmap.md:8`

## Local Review (Pre-Push)
**Status**: complete
**When**: 2026-11-17 14:25 -05:00
**By**: Claude Code Agent (claude-fable-5-2)
**Verdict**: approved

**Branch**: feature/issue-486 at `e996aec7`
**Base**: origin/main
**Depth**: Deep (reason: round 3 convergence check on the round 2 findings and the fix commit 6cd83b32)
**Must-fix**: 0 | **Suggestions**: 4
**Round**: 3 | **Ship**: recommended — no must-fix findings

Specialists: Claude adversarial, scoped to the round 2 findings and the fix diff. Cross-model skipped (round-3 convergence check). The reviewer read the tree at 72335551; its four wording suggestions were applied in the commit after it, which this entry's head includes and which no reviewer has read.

### Findings
- [x] (suggestion) The multi-distro tree does not show state.yaml or say it is kept per distro — `tools/ros-manifest/docs/design.md:93`
- [x] (suggestion) A relative parent comes from an updated clone only when the naming manifest is the local copy — `tools/ros-manifest/docs/design.md:301`
- [x] (suggestion) A repo with no record is never tracked again — `tools/ros-manifest/docs/design.md:306`
- [x] (suggestion) "before any repo is cloned" is looser than the later paragraph — `tools/ros-manifest/docs/design.md:233`
