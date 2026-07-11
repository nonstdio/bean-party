# Minigame contribution contract

## Purpose

This document describes how independently designed minigames should join the shared game without each contributor changing the board or another minigame. It is an interface *goal*, not an engine-specific API. The final code-level contract will be written after the engine spike.

## Contribution lifecycle

Every minigame should have five stages:

1. **Proposal** — an issue captures the player count, controls, objective, timing, scoring, and art note.
2. **Setup** — the shared shell provides player identities, teams, input assignments, and any approved configuration.
3. **Briefing** — the minigame presents a short, accessible explanation and a ready state.
4. **Play and result** — it runs a bounded round, produces an unambiguous result, and exposes any result data required by the board.
5. **Teardown** — it releases its own scene, audio, temporary state, and input hooks so another minigame can start cleanly.

## Intended repository layout

Once implementation begins, keep each minigame self-contained under its own stable slug:

```text
minigames/
  <minigame-slug>/
    README.md       # design brief, controls, player counts, asset credits
    src/            # engine-specific gameplay source
    assets/         # only assets needed by this minigame
    tests/          # automated or manual test notes
```

The selected engine may add required files, but do not place minigame-specific logic in the board or shared-system area without an accepted shared-interface change.

## What the shared shell should own

- match and board state;
- player profiles, teams, and input assignment;
- scene loading and transition timing;
- global accessibility, audio, and UI settings;
- the result format consumed by the board;
- common art, audio, and UI kits once they exist.

## What a minigame should own

- its rules, arena, local state, scoring logic, and result presentation;
- minigame-specific art and audio with documented provenance;
- briefing and controls display that uses shared conventions when available;
- cleanup of everything it creates.

## Definition of done

A minigame is ready for review when it has an approved brief, supports its stated player counts, explains its controls, returns a deterministic result for the same final state, cleans up on restart or exit, credits every third-party asset, and has been tested with people rather than only in a solo editor session.

## Integration questions for the engine spike

The prototype must answer how the shell loads a minigame, passes player/input information, receives results, handles pause/quit/retry, and prevents a minigame from leaking state into the next scene. Those answers will become the code-level interface before multiple minigames are accepted.
