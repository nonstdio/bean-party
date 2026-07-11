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

Do not place minigame-specific logic in the board or shared-system area without an accepted shared-interface change. Follow the broader conventions in [Godot project architecture](godot-project.md).

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

Network-capable minigames plug into the shared shell through a proposed session interface documented in [networking architecture](networking.md). The code-level API will be formalized in milestone 12 of the [networking implementation plan](../plans/networking.md), **after** the milestone 10 `HOST_ACTION` combat spike validates the shared action-netcode kit. Names below are **proposals**.

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
| Logical players | Ordered `PlayerSlot` list with stable `player_id`, `owning_peer_id`, `local_player_index`, display identity, team, cosmetics |
| Peer ownership map | Which `peer_id` owns which `local_player_index` values |
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
5. **Clean up network state** during teardown: disconnect signal handlers, RPC registrations, buffered snapshots, per-minigame network nodes, and action-netcode kit registrations.
6. **Do not depend** on another minigame's networking code. Shared networking utilities live in the shell/session layer and the shared **action-netcode kit** (`scripts/shared/`) after review—not copied per minigame.
7. **Do not assume** the authority process controls a `PlayerSlot`. Gameplay code must work when authority is a listen-server host, a peer with no local bean, or (later) a dedicated headless process.

### Sync profiles (conceptual)

Profiles are conceptual names until implementation validates them in milestones 7, 10, and 12.

| Profile | Intended use | Client simulation |
| --- | --- | --- |
| `TURN_OR_EVENT` | Discrete turns, button presses, timing windows | Tick-numbered input frames (unreliable + short redundant history); host adjudicates; reliable messages only for idempotent side effects |
| `HOST_SNAPSHOT` | Slower movement, racing, obstacle courses, bump arenas | Input upstream; interpolate remote entities; **optional** local movement prediction |
| `HOST_ACTION` | 3D shooters, melee combat, vehicles, physics-heavy arenas | Fixed-tick host sim; **required** local movement prediction + reconciliation; remote interpolation; lag-compensated hitscan; shared action-netcode kit |
| `CUSTOM_APPROVED` | Rollback, special replication, experimental sync | Design review required; stricter test plan |

A timing-based minigame will usually use `TURN_OR_EVENT`. A movement arena will usually use `HOST_SNAPSHOT`. Bean Battles-like 3D combat is expected to use `HOST_ACTION`, not `HOST_SNAPSHOT` alone. Neither profile requires project-wide deterministic lockstep.

### `HOST_ACTION` requirements

Minigames that declare `HOST_ACTION` must use the shared action-netcode kit for:

- tick-numbered input with redundant history;
- local movement prediction and server reconciliation;
- remote-player snapshot interpolation;
- stable `network_entity_id` values (not Godot node paths);
- reliable, idempotent spawn/despawn/death/pickup/damage messages;
- hitscan lag compensation with a bounded server rewind window;
- projectile authority (host owns canonical projectiles; clients may show cosmetic predicted copies);
- host-only canonical 3D physics for props, vehicles, and ragdolls (clients interpolate replicated state).

Minigames supply movement rules, weapons, arena layout, entity types, and scoring through the kit—they must not reimplement transport, prediction buffers, or hit validation independently.

### Replicated-entity contract (conceptual)

Every networked entity in a `HOST_ACTION` minigame should conceptually expose:

| Field | Purpose |
| --- | --- |
| `network_entity_id` | Stable ID for the minigame instance—not a node path |
| `minigame_instance_id` | Ties entity to one briefing→results run |
| `entity_type` | Enum or string slug |
| `owning_player_id` | Optional `PlayerSlot` reference |
| `spawn_tick` | Authoritative spawn tick |
| Position, orientation | Authoritative transform |
| Linear/angular velocity | When relevant |
| Gameplay state | Health, animation phase, weapon state, etc. |
| `despawn_reason`, `despawn_tick` | When removed |

Spawns, despawns, deaths, pickups, and confirmed hits must be **reliable and idempotent**. Frequent transforms and velocities should be **unreliable snapshots**.

See [networking architecture — action-game requirements](networking.md#action-game-requirements-host_action) for hitscan/projectile flows and physics authority.

### Definition of done (network-capable minigames)

In addition to the local definition of done, a network-capable minigame is review-ready when:

- it declares its sync profile and supported player counts (2–4 `PlayerSlot`s or a documented subset);
- it runs without creating its own transport;
- host and all clients agree on results in manual multi-peer tests documented in the PR;
- teardown leaves no registered RPCs, session listeners, or action-netcode kit registrations.

`HOST_ACTION` minigames additionally require:

- documented network-condition playtests (50, 100, and 150 ms latency; jitter; 1–2% loss where feasible);
- hitscan and/or projectile behavior validated through the shared kit;
- no durable network identity based on Godot node paths.

See [Decision 0003](../decisions/0003-peer-hosted-networking.md) for authority model and validation gates.
