# Agent Workspace

A general-purpose multi-agent development platform. Manages one or more external
project repositories with full AI agent infrastructure: worktree isolation, governance, skills,
hooks, and multi-agent coordination.

## Goals

The workspace exists to help one person manage many AI agents across one or
more projects, so the results can be trusted and the user stays informed and
in control. <!-- P -->

### Quality of the work

- Agents take the time and resources a quality result needs, within practical
  limits: economical, but never at the cost of quality. <!-- Q1 -->
- Documentation, code and designs are concise and distilled, so a newcomer can
  grasp them without much effort. <!-- Q2 -->
- Agents learn from what's already there: why existing code was written the
  way it was, how the project already solves similar problems, and what the
  field considers good practice. They bring the same care to new code.
  Where existing code isn't up to standard, they improve or modernize it;
  where it's fine, they keep its approach unless there's a clear reason,
  looking ahead, to change it. <!-- Q3 -->
- Code meets the safety expectations of the project's field. A path planning
  algorithm for a marine robot should be scrutinized for safety differently
  than a path planning algorithm for a game. <!-- Q4 -->

### Trust, control and information

- The user stays in control: agents make decisions on their own only as far
  as the trust they've earned allows. When in doubt, they ask. <!-- T2 draft -->
- Agents can't do lasting damage: they get only the access a task needs, and
  anything that can't be undone needs the user's OK. <!-- T3 draft -->
- Agents strive to be trustworthy and take care not to break the trust they've
  earned. <!-- T1 -->
- The user has limited time and attention, so agents give the right amount of
  information: enough to make the important decisions and keep understanding
  the whole project, and no more. <!-- T4 draft -->

### Flexibility

- When practical, preference should go to open source and open standards to
  minimize vendor lock-in. Have an exit strategy for anything that depends on
  a vendor's closed product or infrastructure. <!-- F1 -->
- Agents follow the rules. When asked to bend one, they go along when it's
  harmless, push back if it seems harmful, and make sure a misunderstanding
  doesn't turn into a mistake. <!-- F2 -->

### Modular

- The workspace is project-agnostic and modular: knowledge about a kind of
  project, like ROS best practices, and workflows for different kinds of work,
  not only coding, are added as modules without changing the rest of the
  workspace. <!-- W1+W4 draft merge -->
- The workspace is improved with the same process and standards used on
  projects. <!-- W5 -->

### Light touch on projects

- Each project chooses how much footprint the workspace leaves in it, from none
  at all to agent instructions and other process-related documents. This lets
  the workspace be used on external projects that may not welcome its
  supporting files. <!-- W2; second sentence draft -->
- A project the workspace has worked on can still be developed and maintained
  without it. <!-- W3 -->

## History

<!-- PLACEHOLDER: the owner will write this section. Also to cover: moving from
coder to manager of agents; why one workspace (the trust built into its
instructions and what agents have learned). -->

Before 2026 I had been dismissing "vibe coding" without having tried it. I
finally tried it to get a better grasp of what it could do, using a one-year
Gemini subscription that came with my phone and that I was barely using. The
results opened my eyes to how much agents could do in very little time, but
also showed the weaknesses: code that wasn't designed to grow well with the
idea, and that didn't follow the principles I would. So I pivoted to agentic
coding. In January 2026 I started ros2_agent_workspace simply as the place to
version-control my agent instructions, without adding them to the project11
repos. agent_workspace began later for simple non-ROS projects, to avoid
scope-creeping ros2_agent_workspace; it is now its successor, and
ros2_agent_workspace is being retired.

## Getting started

TODO: basic user instructions.

## Documentation

- [`docs/design.md`](docs/design.md) — System design
- [`docs/decisions/`](docs/decisions/) — Architecture Decision Records
- [`docs/principles.md`](docs/principles.md) — Guiding principles

If you're an AI agent, or you think you are, see [`AGENTS.md`](AGENTS.md).
