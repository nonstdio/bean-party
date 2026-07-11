# Reference Tap

Reference Tap is a deliberately tiny local minigame used to prove and teach local minigame contract version 1. It is an infrastructure reference accepted with [Decision 0004](../../docs/decisions/0004-local-minigame-contract.md), not a production-content proposal.

## Design brief

- **Players:** 2–4, free-for-all.
- **Objective:** be the first player to press the primary action after play begins.
- **Placement:** the first player is first; all remaining players tie for second. If nobody presses within ten seconds, all players tie.
- **Timing:** no custom briefing, up to ten seconds of active play, immediate result.
- **Controls:** normalized `primary` action supplied by `MinigameInputSource`.
- **Accessibility:** the instruction and winner are displayed as text; no gameplay information relies on color.
- **Capability:** `local_only`.

## Integration notes

The scene root extends `MinigameController`, reads only its supplied `MinigameContext`, and returns ordered placements plus numeric scores. It never applies board rewards. Its local GUT test exercises registry discovery, setup, input, result delivery, and teardown.

## Assets and provenance

No external assets are used.

## Validation

- Automated local contract test under `tests/`.
- Intended as an executable reference and smoke fixture, not a balanced or presentation-complete minigame.
