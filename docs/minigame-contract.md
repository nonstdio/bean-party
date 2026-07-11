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

Keep each Godot minigame self-contained under its own stable slug:

```text
minigames/
  <minigame-slug>/
    README.md       # design brief, controls, player counts, asset credits
    scenes/         # Godot scenes owned by this minigame
    scripts/        # GDScript owned by this minigame
    assets/         # only assets needed by this minigame
    tests/          # automated or manual test notes
```

Do not place minigame-specific logic in the board or shared-system area without an accepted shared-interface change. Follow the broader conventions in [Godot project architecture](godot-architecture.md).

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

## Networking

Network-capable minigames plug into the shared shell through a proposed session interface documented in [networking architecture](networking-architecture.md). The code-level API will be formalized in milestone 11 of the [networking implementation plan](networking-implementation-plan.md). Names below are **proposals**.

### Capability declaration

Every minigame must declare one of:

| Mode | Meaning |
| --- | --- |
| `local_only` | No online play; may still use `PlayerSlot`s for couch play |
| `network_capable` | Can run under host authority when the shell provides a session |

Network-capable minigames must also declare a **sync profile** (see below). `CUSTOM_APPROVED` requires an explicit design review before implementation.

### Inputs from the shell (proposed)

The shell provides at setup time:

| Input | Description |
| --- | --- |
| Logical players | Ordered `PlayerSlot` list with stable `player_id`, `owning_peer_id`, `local_device_slot`, display identity, team, cosmetics |
| Peer ownership map | Which `peer_id` owns which local slots |
| Team assignments | Format-specific teams for 2v2, 1v3, cooperative modes |
| Authoritative RNG | Seed or stream handle owned by the host; minigame must not reseed unilaterally |
| Synchronized start | Host-approved start tick or wall-clock time for countdown alignment |
| Session interface | Approved handle for submitting inputs and receiving host events—**not** a raw `MultiplayerPeer` |
| Network quality (optional) | RTT, loss hints for diagnostics or adaptive UI—not for client-side authority |

### Outputs to the shell (proposed)

At result time the minigame returns:

| Output | Description |
| --- | --- |
| Placements or team outcome | Unambiguous winner(s) or team result |
| Score breakdown | Per-`PlayerSlot` or per-team scores for results UI |
| Board rewards | Beans, items, or advantages the host applies on `ReturnToBoard` |
| Diagnostic summary (optional) | Tick counts, correction stats, replay notes for debugging |

### Networking rules

1. **Only the authoritative host** may finalize a minigame result. Clients may predict locally for display but must accept host results.
2. **Declare `local_only` or `network_capable`** in the minigame README and proposal.
3. **Declare a sync profile** for every `network_capable` minigame.
4. **Do not construct** an independent session, ENet peer, or Steam connection inside a minigame.
5. **Clean up network state** during teardown: disconnect signal handlers, RPC registrations, buffered snapshots, and per-minigame network nodes.
6. **Do not depend** on another minigame's networking code. Shared networking utilities live in the shell/session layer only after a reviewed promotion to `scripts/shared/`.

### Sync profiles (conceptual)

Profiles are conceptual names until implementation validates them in milestone 11.

| Profile | Intended use | Client simulation |
| --- | --- | --- |
| `TURN_OR_EVENT` | Discrete turns, button presses, timing windows | Wait for host events; minimal prediction |
| `HOST_SNAPSHOT` | Continuous movement, physics, bump interactions | Input upstream; interpolate remote entities; optional local prediction |
| `CUSTOM_APPROVED` | Rollback, special replication, experimental sync | Design review required; stricter test plan |

A timing-based minigame will usually use `TURN_OR_EVENT`. A movement arena will usually use `HOST_SNAPSHOT`. Neither profile requires project-wide deterministic lockstep.

### Definition of done (network-capable minigames)

In addition to the local definition of done, a network-capable minigame is review-ready when:

- it declares its sync profile and supported player counts (2–8 `PlayerSlot`s or a documented subset);
- it runs without creating its own transport;
- host and all clients agree on results in manual multi-peer tests documented in the PR;
- teardown leaves no registered RPCs or session listeners.

See [Decision 0003](decisions/0003-peer-hosted-networking.md) for authority model and validation gates.

