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
- [ ] (must-fix) A child that replaces the top-level distros list leaves inherited per-distro entries undefined (gemini, adversarial) — `tools/ros-manifest/docs/spec.md:309`
- [ ] (must-fix) Git URLs: no transport rule (ext:: runs a command at clone), base location values unchecked, prototype.md says URL rules carry over (gemini, adversarial) — `tools/ros-manifest/docs/spec.md:396`
- [ ] (must-fix) Containment check is incomplete: a key that is a prefix of another, a .git path component, layer names as paths, names colliding with src/build/install/log/.repos-manifest or a distro directory (gemini, adversarial) — `tools/ros-manifest/docs/spec.md:394`
- [ ] (must-fix) sync contradicts itself: repos follow the current manifest, yet a repo on another branch than the manifest names is left alone, so a changed version never applies (adversarial) — `tools/ros-manifest/docs/design.md:286`
- [ ] (must-fix) freeze keeps a repo's distros block, so a per-distro version still overrides the frozen commit; frozen url unstated (adversarial) — `tools/ros-manifest/docs/design.md:334`
- [ ] (must-fix) Claim "one repo with local changes makes the whole run fail" did not reproduce with vcs2l 1.1.7 (adversarial) — `tools/ros-manifest/docs/design.md:282`
- [ ] (must-fix) Example names a private repo in new prose (governance) — `tools/ros-manifest/docs/spec.md:54`
- [ ] (must-fix) README states unbuilt behaviour in the present tense under "Why another tool" (governance) — `tools/ros-manifest/README.md:66`
- [ ] (must-fix) Adapter comment cites the tool README for clone-protection rules that moved to docs/prototype.md (governance) — `.agent/project_types/ros2_colcon/adapter.sh:639`
- [ ] (suggestion) With repo-level absent: true, the meaning of a distro entry of {}, {absent: true} or {absent: false} is unstated — `tools/ros-manifest/docs/spec.md:142`
- [ ] (suggestion) A role or an extra group naming an undeclared group is undefined — `tools/ros-manifest/docs/spec.md:241`
- [ ] (suggestion) repositories, type and url are marked required but a later manifest may omit them; a child entry matching nothing in the parent is undefined — `tools/ros-manifest/docs/spec.md:81`
- [ ] (suggestion) The unnamed layer's .repos file has no stated name; unstated whether an empty layer gets a file — `tools/ros-manifest/docs/design.md:259`
- [ ] (suggestion) fetch_from: "the published manifest" is undefined in a chain; repos added by the machine's own manifest unclear — `tools/ros-manifest/docs/design.md:394`
- [ ] (suggestion) fetch_from URL as written ends in .git.git — `tools/ros-manifest/docs/design.md:361`
- [ ] (suggestion) show says it fetches nothing but reads parents from git and, with fallback, asks the other place — `tools/ros-manifest/docs/design.md:190`
- [ ] (suggestion) sync step 1 does not say which branch the manifest's clone is updated on — `tools/ros-manifest/docs/design.md:267`
- [ ] (suggestion) The git form of manifest has no config.yaml shape, and no CLI way to set fallback — `tools/ros-manifest/docs/design.md:142`
- [ ] (suggestion) Development machine walkthrough: init line lacks the fetch-from and remotes options the config then holds — `tools/ros-manifest/docs/design.md:482`
- [ ] (suggestion) prototype.md understates what an extension may do (merge.py also adds to existing groups and roles) — `tools/ros-manifest/docs/prototype.md:17`
- [ ] (suggestion) Put the sitrep_checks.sh --root form in the PR description; without it the roadmap's first check reads false — `tools/ros-manifest/docs/roadmap.md:10`
- [ ] (suggestion) List in the PR where the documents depart from the issue text (base, no overrides section, optional repos, the name, prototype.md) — `tools/ros-manifest/README.md:1`
- [ ] (suggestion) Owner to accept or reword the three links to the workspace issue tracker — `tools/ros-manifest/docs/prototype.md:72`
