# Bean Party documentation

This directory contains the durable design, architecture, operating guidance, research, plans, decisions, and governance for Bean Party. Organize documents by the question they answer rather than by a technology or feature name alone.

## Start here

### New contributors

1. Read the repository [README](../README.md) and [contribution guide](../CONTRIBUTING.md).
2. Follow the [Godot setup guide](guides/godot-setup.md).
3. Review the [Godot project architecture](architecture/godot-project.md) before adding shared systems or a minigame.
4. Read the [Godot 3D movement standards](architecture/godot-3d-movement.md) before implementing player-controlled 3D movement.
5. Use the [runtime debug harness guide](guides/runtime-debug-harnesses.md) to exercise the currently implemented local, minigame, and networking proofs.

### Minigame authors

Friends who are new to the repository can start with [Friend minigame contributor onboarding](guides/friend-minigame-onboarding.md), including copyable proposal and implementation prompts.

1. Read the [game design target](design/game.md) and [creative direction](design/creative-direction.md).
2. Use the [minigame design guide](design/minigames.md) to prepare and review the idea.
3. Open a [minigame proposal](../.github/ISSUE_TEMPLATE/minigame-proposal.yml) and receive approval before substantial implementation intended for integration.
4. Follow [Create a minigame](guides/create-a-minigame.md) and the [minigame integration contract](architecture/minigame-integration.md) during implementation.
5. For player-controlled 3D movement, follow the [Godot 3D movement standards](architecture/godot-3d-movement.md).

GitHub issues are the canonical home for pre-implementation minigame proposals. Once implementation begins, keep the design brief, controls, asset credits, and test notes with the minigame in `minigames/<slug>/README.md`.

### Networking contributors

Read [Decision 0003](decisions/0003-peer-hosted-networking.md), the [networking architecture](architecture/networking.md), and the [networking implementation plan](plans/networking.md) in that order. The decision remains proposed until its documented validation gates pass review.

### Art and presentation contributors

Read the [creative direction](design/creative-direction.md), [standard asset guide](guides/standard-assets.md), and [standard asset catalog](../assets/standard/catalog.md) before creating a shared character, identity marker, material, UI token, or similar reusable asset. Canonical prototypes are reuse defaults, not final production art.

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

## Contributor documentation responsibilities

Documentation is part of the implementation, not a follow-up task. Contributors should:

- Begin with the repository entry points and read as many linked design, architecture, guide, plan, research, decision, and project documents as reasonably necessary for the task before changing behavior or project direction.
- Create or update the canonical document in the same change when work adds or changes durable behavior, interfaces, conventions, setup requirements, decisions, or other knowledge future contributors will need. Keep transient experiments and work-in-progress findings in their issue or pull request unless they become durable guidance.
- Correct inaccurate, stale, broken, misleading, or contradictory documentation encountered during the work. Fix a small incidental gap when the correction is supported by clear evidence and remains focused; record a substantial, uncertain, or unrelated gap in the pull request or raise it with a maintainer rather than silently ignoring it or widening the change without review.
- Investigate disagreements among documentation, code, tests, and recorded decisions instead of assuming that any one source automatically overrides the others. Distinguish the intended behavior from the currently implemented behavior, and consider accepted decisions, active canonical documents, executable code and tests, document status, and relevant project history.
- Reconcile inconsistent sources when the intended resolution is clear and within scope. When evidence is incomplete, sources remain ambiguous, or a resolution would establish new project direction, describe the discrepancy and ask a maintainer before choosing an interpretation.

Research, plans, proposals, and draft documents can provide evidence, but they do not silently establish project policy. Use their recorded status and the lifecycle below to determine their authority.

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
- [Minigame design guide](design/minigames.md)

### Architecture and integration

- [Godot project architecture](architecture/godot-project.md)
- [Godot 3D movement standards](architecture/godot-3d-movement.md)
- [Minigame integration contract](architecture/minigame-integration.md)
- [Networking architecture](architecture/networking.md)

### Guides

- [Godot setup for agents](guides/godot-setup.md)
- [Friend minigame contributor onboarding](guides/friend-minigame-onboarding.md)
- [Create a minigame](guides/create-a-minigame.md)
- [Runtime debug harnesses](guides/runtime-debug-harnesses.md)
- [WebRTC setup](guides/webrtc-setup.md)
- [WebRTC operations runbook](guides/webrtc-ops.md)
- [WebRTC implementation notes](guides/webrtc-implementation-notes.md)
- [Use and contribute standard assets](guides/standard-assets.md)

### Plans

- [Networking implementation plan](plans/networking.md)

### Research

- [Research notes](research/README.md)
- [Engine evaluation](research/engine-evaluation.md)
- [Steam transport investigation](research/steam-transport-investigation.md) — Backlog
- [WebRTC transport investigation](research/webrtc-transport-investigation.md) — Phase 2 in progress

### Decisions

- [Decision record process and index](decisions/README.md)
- [Decision 0001: Godot 4.7](decisions/0001-godot-engine.md) — Accepted
- [Decision 0002: GUT testing](decisions/0002-gut-testing.md) — Accepted
- [Decision 0003: peer-hosted networking](decisions/0003-peer-hosted-networking.md) — Proposed
- [Decision 0004: local minigame contract](decisions/0004-local-minigame-contract.md)
- [Decision 0005: standard asset pipeline](decisions/0005-standard-asset-pipeline.md) — Accepted
- [Decision 0006: project licensing](decisions/0006-project-licensing.md) — Accepted

### Project

- [Project governance](project/governance.md)
