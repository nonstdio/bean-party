# Bean Party documentation

This directory contains the durable design, architecture, operating guidance, research, plans, decisions, and governance for Bean Party. Organize documents by the question they answer rather than by a technology or feature name alone.

## Start here

### New contributors

1. Read the repository [README](../README.md) and [contribution guide](../CONTRIBUTING.md).
2. Follow the [Godot setup guide](guides/godot-setup.md).
3. Review the [Godot project architecture](architecture/godot-project.md) before adding shared systems or a minigame.

### Minigame authors

1. Read the [game design target](design/game.md) and [creative direction](design/creative-direction.md).
2. Open a [minigame proposal](../.github/ISSUE_TEMPLATE/minigame-proposal.md) before substantial implementation.
3. Follow the [minigame contribution contract](architecture/minigame-integration.md).

GitHub issues are the canonical home for pre-implementation minigame proposals. Once implementation begins, keep the design brief, controls, asset credits, and test notes with the minigame in `minigames/<slug>/README.md`.

### Networking contributors

Read [Decision 0003](decisions/0003-peer-hosted-networking.md), the [networking architecture](architecture/networking.md), and the [networking implementation plan](plans/networking.md) in that order. The decision remains proposed until its documented validation gates pass review.

### Maintainers

Use the [project governance guide](project/governance.md) for branch and review policy. Record consequential, hard-to-reverse choices using the [decision record process](decisions/README.md).

## Documentation structure

| Directory | Purpose | Typical question |
| --- | --- | --- |
| [`design/`](design/) | Player experience, creative direction, and gameplay constraints | What are we trying to make? |
| [`architecture/`](architecture/) | Shared-system boundaries, integration contracts, and intended technical structure | How do the parts fit together? |
| [`guides/`](guides/) | Repeatable setup, development, and operating procedures | How do I perform this task? |
| [`plans/`](plans/) | Ordered implementation or validation work | What should happen next, and in what order? |
| [`research/`](research/) | Durable evidence, experiments, and trade-off analysis | What did we learn? |
| [`decisions/`](decisions/) | Consequential choices and their rationale | What did the project choose, and why? |
| [`project/`](project/) | Repository governance and maintenance policy | How is the project managed? |

Subjects can appear in more than one directory. For example, Godot installation belongs in `guides/`, Godot project structure belongs in `architecture/`, an engine comparison belongs in `research/`, and the engine choice belongs in `decisions/`.

## Where a new document belongs

- Put player-facing goals, gameplay principles, and creative constraints in `design/`.
- Put current or proposed system boundaries and shared interfaces in `architecture/`.
- Put instructions that a contributor can follow repeatedly in `guides/`.
- Put milestone sequences and temporary implementation roadmaps in `plans/`.
- Put reusable investigation results in `research/`. Keep transient spike notes and work-in-progress findings in their issue or pull request.
- Put expensive-to-reverse project choices in `decisions/`. Research may support a decision, but it does not establish project policy by itself.
- Put branch, review, ownership, and maintenance policy in `project/`.

If a document answers more than one of these questions, split it when each part can stand on its own and has a different lifecycle. Otherwise place it according to its primary purpose and link to related material.

## Document lifecycle

A substantial question may move through the following lifecycle:

```text
Issue or discussion -> Research -> Decision -> Design or architecture -> Plan -> Guide
```

Not every change needs every stage. A small correction can update a guide directly. A consequential change to the engine, networking model, licensing, asset pipeline, or shared minigame API should have a decision record.

- Research records evidence and may recommend an option; it is not binding.
- A decision records the authoritative choice and links to supporting research.
- Design and architecture describe active or proposed direction and cite the decisions that govern it.
- A plan sequences future work and should not become the permanent source of architectural truth.
- When a plan finishes, move durable conclusions into the relevant design, architecture, or guide document.

Use a visible status near the top of a document when its state is not obvious:

- General documents: `Draft`, `Active`, or `Superseded`.
- Research: `In progress`, `Concluded`, or `Stale`.
- Plans: `Proposed`, `Active`, `Complete`, or `Paused`.
- Decisions: `Proposed`, `Accepted`, or `Superseded`.

Do not add owner or last-reviewed metadata until the project has a defined ownership and review cadence. Git history remains the source for authorship and modification dates.

## Naming and maintenance

- Use lowercase kebab-case Markdown filenames.
- Number only decision records, using a zero-padded sequence and short slug.
- Prefer relative links so documentation works in local checkouts and on GitHub.
- Link to the canonical document instead of duplicating its rules elsewhere.
- Update this index when adding, moving, superseding, or removing a durable document.
- Keep a superseded document only when its history remains useful, and place a prominent link to its replacement at the top.
- Do not create an archive directory for material that Git history already preserves.

## Document index

### Design

- [Game design target](design/game.md)
- [Creative direction](design/creative-direction.md)

### Architecture and integration

- [Godot project architecture](architecture/godot-project.md)
- [Minigame contribution contract](architecture/minigame-integration.md)
- [Networking architecture](architecture/networking.md)

### Guides

- [Godot setup for agents](guides/godot-setup.md)

### Plans

- [Networking implementation plan](plans/networking.md)

### Research

- [Research notes](research/README.md)
- [Engine evaluation](research/engine-evaluation.md)

### Decisions

- [Decision record process and index](decisions/README.md)

### Project

- [Project governance](project/governance.md)
