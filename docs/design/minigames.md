# Minigame design guide

This guide defines what a Bean Party minigame proposal and implemented design brief should explain. It applies the broader [game design target](game.md) and [creative direction](creative-direction.md) to independently contributed minigames. Technical ownership, runtime lifecycle, result handling, and networking requirements live in the [minigame integration contract](../architecture/minigame-integration.md).

## Source of truth and design lifecycle

Every substantial minigame should move through these stages:

1. **Proposal** — open a GitHub issue using the [Minigame proposal template](../../.github/ISSUE_TEMPLATE/minigame-proposal.md) before substantial implementation. The issue is the canonical design record while the idea is being discussed.
2. **Review** — resolve or explicitly defer questions about player format, objective, controls, accessibility, scope, shared-system needs, originality, and validation before committing to the implementation.
3. **Implementation brief** — when implementation begins, create `minigames/<slug>/README.md`. It becomes the canonical description of the minigame as its design changes in code; link back to the proposal issue for history.
4. **Playtest and revision** — test with the intended number of players when possible, record what happened, and update the implemented brief when the rules or player experience change.
5. **Integration review** — verify the design definition of done below and the separate [integration contract](../architecture/minigame-integration.md) before merge.

The proposal issue remains useful historical context after implementation begins, but contributors should not have to reconcile conflicting current rules between an issue and the minigame README.

## What a proposal should contain

| Area | Questions to answer |
| --- | --- |
| Elevator pitch | What happens, and what is the memorable player-facing moment? |
| Players and format | Which player counts are supported? Is it free-for-all, 2v2, 1v3, cooperative, or another clearly named format? |
| Objective and scoring | What does each player do? How does someone win, lose, place, or tie? |
| Timing | How long should briefing, active play, and results take? Explain a deliberate exception to the 30–90 second active-play target. |
| Controls and camera | Which inputs does each player need? What perspective or shared camera makes the action readable? |
| Player understanding | What must a newcomer understand before play starts, and how will the briefing or demonstration teach it? |
| Continued involvement | How can players recover, influence the outcome, or enjoy the spectacle after falling behind or being eliminated? |
| Accessibility | Which non-color signals, input accommodations, readable timing cues, or other needs affect the design? |
| Bean Party fit | What original setting, props, hazards, and comic tone make the minigame belong in this project? |
| Integration | Does it depend on board state or a new shared system? Is it `local_only` or `network_capable`; if network-capable, which conceptual sync profile is expected? |
| Assets | What original or appropriately licensed art and audio are needed, and how will provenance be recorded? |
| Validation | How will the experience be tested with its intended player count, and what observations would cause a design revision? |

The proposal should be detailed enough to expose design and integration risks without becoming a frame-by-frame specification. Unknowns are acceptable when they are labeled and paired with a way to test them.

## Review criteria

A promising minigame should satisfy these principles or explain a deliberate exception:

- **Legible quickly.** A newcomer can understand the objective, important state, and basic controls from a compact briefing.
- **Bounded and replayable.** The round reaches a clear result quickly enough to return to the board, while leaving room for mastery or rematches.
- **Involving until late.** Early mistakes do not create a long period with nothing meaningful or entertaining to do.
- **Fair enough to learn.** Randomness, reversals, and interference are understandable and leave players some agency.
- **Distinct within the collection.** The minigame contributes a useful skill, format, camera, or pacing variation instead of duplicating an existing design.
- **Relevant to the party.** Its result can be presented clearly and translated into the board or match flow without the minigame owning that shared economy.
- **Original and readable.** The setting and presentation fit Bean Party without copying another game's rules, maps, characters, text, or assets, and gameplay-critical information is not conveyed by color alone.
- **Scoped for independent contribution.** It can live under one stable minigame slug without depending directly on another minigame or inventing an unreviewed shared system.

## Implemented design brief

Once implementation begins, `minigames/<slug>/README.md` should record the current design and contributor-facing facts:

- proposal issue link and a short elevator pitch;
- supported player counts, team format, objective, rules, scoring, and tie behavior;
- briefing, controls, camera, accessibility considerations, and expected timing;
- board-state dependencies and expected result or reward data;
- `local_only` or `network_capable` capability and any conceptual sync profile;
- asset inventory, creators, sources, and licenses;
- playtests performed, automated or manual test notes, known limitations, and open design questions.

Keep implementation details in the minigame's scenes, scripts, tests, or focused technical notes. The README should let a contributor understand, run, evaluate, and credit the minigame without reading all of its code.

## Design definition of done

A minigame design is ready for integration review when:

- its proposal was reviewed and the implemented README reflects the current rules;
- its objective, controls, scoring, tie behavior, and result are unambiguous;
- it supports its stated player counts and team format;
- its briefing communicates the necessary information accessibly and quickly;
- it meets the intended timing or documents why a different duration improves the experience;
- it stays meaningful or entertaining after a player falls behind;
- it uses original or appropriately licensed material and records asset provenance;
- it has been playtested with people and the intended player count when possible, with any limitation disclosed;
- it identifies dependencies on board state, shared systems, and network capability for technical review.

Passing this design review does not by itself prove shell integration or network correctness. Apply the [minigame integration contract](../architecture/minigame-integration.md) as the next review boundary.
