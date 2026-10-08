# Agent Workspace

A set of tools that allows multiple agents to safely work on one or more
projects with instructions to prioritize quality while keeping the user informed
and in control.

Agents use git worktrees to keep work isolated and follow good software
engineering practices, documenting plans, reviews, and progress in plain files
that any agent tool can pick up.

## Getting started

Ask your favorite agent to look at github.com/rolker/agent_workspace.

You can also clone it yourself, launch an agent CLI in the local clone, and ask
it to set up the workspace.

## Documentation

If you're an AI agent, or you think you are, see [`AGENTS.md`](AGENTS.md).

- [`docs/design.md`](docs/design.md) — System design
- [`docs/decisions/`](docs/decisions/) — Architecture Decision Records
- [`docs/principles.md`](docs/principles.md) — Guiding principles

## Workspace goals

The workspace exists to help one person manage many AI agents across one or more
projects, so the results can be trusted and the user stays informed and in
control. These goals drive the design and help agents and me see the big picture
as we improve the workspace.

### Quality of the work

- Agents take the time and resources a quality result needs, within practical
  limits: economical, but never at the cost of quality.
- Documentation, code and designs are concise and distilled, so a newcomer can
  grasp them without much effort.
- Agents learn from what's already there: why existing code was written the way
  it was, how the project already solves similar problems, and what the field
  considers good practice. They bring the same care to new code. Where existing
  code isn't up to standard, they improve or modernize it; where it's fine, they
  keep its approach unless there's a clear reason, looking ahead, to change it.
- Code meets the safety expectations of the project's field. A path planning
  algorithm for a marine robot should be scrutinized for safety differently than
  a path planning algorithm for a game.

### Trust, control and information

- The user stays in control: agents make decisions on their own only as far as
  the trust they've earned allows. When in doubt, they ask.
- Agents can't do lasting damage: they get only the access a task needs, and
  anything that can't be undone needs the user's OK.
- Agents strive to be trustworthy and take care not to break the trust they've
  earned.
- The user has limited time and attention, so agents give the right amount of
  information: enough to make the important decisions and keep understanding the
  whole project, and no more.

### Flexibility

- When practical, preference should go to open source and open standards to
  minimize vendor lock-in. Have an exit strategy for anything that depends on a
  vendor's closed product or infrastructure.
- Agents follow the rules. When asked to bend one, they go along when it's
  harmless, push back if it seems harmful, and make sure a misunderstanding
  doesn't turn into a mistake.

### Modular

- The workspace is project-agnostic and modular: knowledge about a kind of
  project, like ROS best practices, and workflows for different kinds of work,
  not only coding, are added as modules without changing the rest of the
  workspace.
- The workspace is improved with the same process and standards used on
  projects.

### Light touch on projects

- Each project chooses how much footprint the workspace leaves in it. Agents can
  work on projects without committing anything that isn't project work, but if
  the user chooses so, agents can add agent instructions and other
  process-related documents to the project. This lets the workspace be used on
  external projects that may not welcome its supporting files.
- A project that workspace agents have worked on can still be developed and
  maintained without them. Using this workspace doesn't lock you in.

### Easy to use

- The workspace is easy to use on a project wherever it lives. It doesn't impose
  a rigid file structure on the project or around it.
- The user works the way they normally would: start an agent in the project's
  own directory and the workspace is there.
- Setting up the workspace is something an agent can do for the user.
- There is little to remember. Agents know the commands and describe work in
  plain words, so the user doesn't have to recall flags or what an issue number
  refers to.
- Work is easy to come back to. Agents refresh the user's mind when they return:
  the big picture, where the current work fits in it, and what it needs from
  them.
- Friction has to earn its place. Prompts, gates and checkpoints are how a user
  stays in control while trust is built, and how much is right differs from user
  to user. Agents notice friction that no longer earns its place and offer to
  reduce it. The user decides.

### The long view

- The workspace keeps track of a project's long-term view, so day-to-day work
  keeps it healthy and moving in the right direction.
- Each project says what healthy and the right direction mean for it, and so
  does the workspace.
- They move toward their goals without carrying extra baggage.
- It is known whether a change helped.

## History

Before 2026 I had been dismissing "vibe coding" without having tried it. Towards
the end of 2025, I started dabbling with Gemini, which came with my Pixel phone,
and was impressed at how quickly it would whip up complex throw-away Python
scripts to answer some of my questions. That led me to try having Gemini build a
web version of one of my projects, and the results were impressive yet needed
much more guidance than can be provided in a simple prompt.

Realizing that I essentially had a team of smart interns at my disposal, I
started testing them out on real work by having them first help me update
documentation and find where documentation was lacking in my ROS 2 based
projects. This being an experiment, I didn't want to commit agent instructions
in project repos yet, so I had agents create a separate repo so I could try
teaching agents how I work with ROS. The result was ros2_agent_workspace. I also
tried different GUIs, CLIs, and models, eventually settling on Claude Code as my
primary tool, but keeping the workspace usable with other tools.

The focus of the workspace was teaching agents the nuances of ROS 2 development
so they wouldn't keep making rookie mistakes. I also recognized the potential of
having multiple agents working together, so enabling that capability was the
other goal of the workspace.

Being new to AI agents at the time, I asked agents to help me put together the
workspace. To avoid reinventing the wheel, I kept having agents survey the
landscape to find a platform that finally did what I needed so I didn't have to
build and maintain it myself. The agents would come back with lots of good ideas
to adopt, but nothing ready to replace the workspace due to the complex nature
of my ROS 2 based projects.

When I started working on a simpler non-ROS project, I considered expanding
ros2_agent_workspace to handle generic projects, but didn't want to dilute its
ROS 2 focus. That's when I started agent_workspace as a lightweight version of
ros2_agent_workspace for simple single-repo projects that didn't need the
complex build system for the multiple layers needed for a large ROS 2 framework.

I was perhaps naive to think I could easily manage agents to keep the common
cores of the two workspaces in sync while both were still being improved. As the
workspaces diverged, I started forgetting which one had which feature and
realized that splitting the workspaces was the wrong approach, and it was
leading to frustration.

Instead of dropping agent_workspace in order to make ros2_agent_workspace
support different projects, I decided to make the simpler agent_workspace
modular so it could work with different project types, and eventually
incorporate ros2_agent_workspace's functionality.
