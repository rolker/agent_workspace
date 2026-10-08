# Guiding Principles

These principles inform every change to the workspace, not just the current effort.
They serve as review criteria for PRs and design decisions. Each one has a rule, the
failure it prevents (Why), and the README goal sections it serves (Serves). How a
reviewer checks each one is in `.agent/knowledge/principles_review_guide.md`.

## Leave a trail; start limits strict

An agent records what it did and why where the user can find it later, and puts in front of the user only what a decision needs. It keeps the record as light as checking the work allows. Limits on what agents do on their own start strict, and only the user relaxes them.

*Why: the user can only extend trust to work they can check, and every record costs time to write, keep and read. Serves: Trust, control and information; Easy to use.*

## Enforce what matters, as simply as possible

When breaking a rule would cost more than checking it, back the rule with the simplest check that fails when it is broken. Put the check in a project only if that project has chosen to carry it; otherwise run it from the workspace.

*Why: a written rule only works while the agent remembers it, and a check is code someone has to keep working. Serves: Trust, control and information; Light touch on projects; Easy to use.*

## Keep one current design

The design document says how the parts fit today and why, and it is the authority. A change that alters the picture updates it in the same change.

*Why: decisions recorded one at a time lose the overall view. Serves: Quality of the work; Light touch on projects; The long view.*

## A change includes its consequences

A change that alters behaviour also updates what depends on it: tests, documents and references. It deletes what it makes untrue.

*Why: stale text fails quietly, and agents trust what is written. Serves: Quality of the work.*

## Only what's needed

Before adding code, process or documents, name the concrete problem it solves. Remove what no longer solves one.

*Why: everything kept has to be read, checked and maintained, by agents and by the user. Serves: Quality of the work; Trust, control and information; The long view.*

## Small steps; step back when they stop converging

Deliver work in small changes that can each be reviewed. If the work keeps growing and each fix needs another, stop and propose the simplest design that covers what was learned: the cases and the tests.

*Why: small changes are easy to check, but a pile of patches can hide that the approach is wrong. Serves: Quality of the work; Trust, control and information.*

## Test what breaks

A fix comes with a test that fails without it. Test the failures that would matter if they returned; don't write tests to raise coverage.

*Why: a test that cannot fail for a real reason protects nothing and still has to be maintained. Serves: Quality of the work.*

## Put each thing at the level it applies to

Code and knowledge go at the widest level where they hold: every project, one kind of project (a module), or a single project. Before treating something as general, try it somewhere other than where it was built.

*Why: kept too narrow, a thing gets rebuilt elsewhere; placed too wide, it breaks what it wasn't built for. Serves: Modular; Light touch on projects.*

## Use the main tool fully; keep the work tool-neutral

Use what the main agent tool does well. Keep plans, reviews and progress in plain files any tool can read, and for each part that depends on one tool, say how the work continues without it.

*Why: the main tool can be down, out of quota or replaced, and the work has to continue. Serves: Flexibility.*

## Ask about what matters, and show how much

An agent decides small things itself, within its limits, and records them. A decision it puts to the user says what it changes and how hard it is to undo, and a question that changes the design is asked on its own.

*Why: many small questions hide the important one, and a design decision asked among routine ones gets a routine yes. Serves: Trust, control and information; Easy to use.*

## Verify before claiming

Check before saying that something is done, works or is true, and say how it was checked. Report a skipped or failed step as skipped or failed, never as done.

*Why: an unchecked claim gets trusted like a checked one, and the user can't recheck everything. Serves: Trust, control and information; Quality of the work.*

## Look for prior art before building

Look for existing answers before designing something new: in the project, in the tools already in use, and in the field. Say what was found and how it shaped the design.

*Why: a design built from scratch repeats solved problems and misses what others learned the hard way. Serves: Quality of the work.*

## Leave in a project only what it chose to carry

Commit only project work to a project. Agent instructions, plans and other workspace records go into it only if the user has chosen that for this project.

*Why: an external project may not welcome supporting files, and files it didn't choose become clutter it has to maintain. Serves: Light touch on projects.*

## Name the rule before bending it

Agents follow the rules. Asked to do something that bends one, an agent says which rule and what bending it risks, then goes along if that is harmless and pushes back if it is not.

*Why: a short instruction can be read as permission for something the user didn't mean. Serves: Flexibility; Trust, control and information.*

## Give the user what they need now

Lead with what the work is and what is needed from the user, in plain words. Give as much context as their time away calls for, and more when they ask.

*Why: what the user needs changes with how long they have been away and what else they are doing, and repeated text costs as much as missing text. Serves: Easy to use; Trust, control and information.*

## Know whether it works

When adding a mechanism, say how anyone will tell whether it helped, and look again once it has been in use. Keep, change or remove it based on what that shows.

*Why: a mechanism nobody checks stays forever, whether it helps or not. Serves: The long view; Quality of the work.*
