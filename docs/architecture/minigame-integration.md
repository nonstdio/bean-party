# Minigame integration contract

Status: **Local contract v1 accepted; networking extension proposed**

## Purpose

This document describes how independently designed minigames join the shared shell without changing the board or another minigame. It defines ownership, runtime lifecycle, outcome, cleanup, and networking boundaries. [Decision 0004](../decisions/0004-local-minigame-contract.md) accepts the code-level local contract at version 1. The networking extension remains proposed until its required spikes and stabilization milestone complete.

Use the [minigame design guide](../design/minigames.md) for proposal requirements, player-facing review criteria, and the transition from a proposal issue to `minigames/<slug>/README.md`.

## Runtime lifecycle

Every minigame should support four runtime stages:

1. **Setup** — the shared shell loads the manifest and scene, then provides player identities, teams, a seeded RNG, per-player input, and approved configuration through `MinigameContext`.
2. **Briefing** — the minigame presents its explanation, controls, and ready state using shared conventions when available.
3. **Play and result** — the shell starts the controller; it runs a bounded round and submits exactly one outcome-only `MinigameResult`.
4. **Teardown** — the shell aborts when necessary and frees the scene. The minigame releases its audio, temporary state, input readers, signals, and any provisional network registrations so another minigame can start cleanly.

## Intended repository layout

Keep each Godot minigame self-contained under its own stable slug:

```text
minigames/
  <minigame-slug>/
    README.md       # design brief, controls, player counts, asset credits
    minigame.tres   # MinigameManifest consumed by the registry
    scenes/         # Godot scenes owned by this minigame
    scripts/        # GDScript owned by this minigame
    assets/         # only assets needed by this minigame
    tests/          # automated or manual test notes
```

Do not place minigame-specific logic in the board or shared-system area without an accepted shared-interface change. Follow the broader conventions in [Godot project architecture](godot-project.md).

Folders beginning with `_`, including `minigames/_template/`, are authoring support and are not discovered as playable minigames.

## Local contract v1

The stable shared types live in `scripts/shared/minigames/`:

| Type | Responsibility |
| --- | --- |
| `MinigameManifest` | Version, stable id, root scene, player range, format, and capability declaration |
| `MinigameContext` | Immutable match-scoped copies of players and teams, RNG seed, instance id, and shell-owned input source |
| `MinigameInputSource` | Per-`PlayerSlot` normalized movement, primary, and secondary input; minigames read but do not route devices |
| `MinigameController` | Required scene-root lifecycle and exactly-once result submission |
| `MinigameResult` | Ordered placement groups, optional per-player scores, or an abort reason |
| `MinigameRegistry` | Discovers and validates manifests under `minigames/` |
| `MinigameRunner` | Shell-owned load, setup, start, abort, retry, result acceptance, and unload behavior |

The manifest `contract_version` must equal `1`. A future breaking local change requires a new version and decision review; networking additions do not change the local version unless they break this surface.

### Result rules

- A completed result contains ordered best-to-worst placement groups. Multiple player ids in one group represent a tie.
- Every supplied participant appears exactly once. Unknown or duplicate player ids are invalid.
- Scores are optional, numeric, and keyed only by supplied player ids.
- An aborted result contains a reason and no placements or scores.
- Results never contain beans, items, board advantages, or other economy mutations. The shell translates the outcome into board rewards.
- The controller and runner reject duplicate, late, or malformed results.

### Input rules

The shell maps local physical devices to `PlayerSlot`s and writes normalized values into `MinigameInputSource`. A minigame reads that source by stable `player_id`. It must not enumerate controller ids, mutate the project `InputMap`, or use global input polling for gameplay. Pause, retry, and early exit remain shell actions rather than minigame actions.

## What the shared shell should own

- match and board state;
- player profiles, teams, and input assignment;
- scene loading and transition timing;
- global accessibility, audio, and UI settings;
- result validation and translation from placements/scores to board rewards;
- common art, audio, and UI kits once they exist.

## What a minigame should own

- its rules, arena, local state, scoring logic, and result presentation;
- minigame-specific art and audio with documented provenance;
- briefing and controls display that uses shared conventions when available;
- cleanup of everything it creates.

## Local integration definition of done

A minigame is ready for integration review when it satisfies the [design definition of done](../design/minigames.md#design-definition-of-done), passes manifest and contract validation, stays within its documented repository boundary, consumes shell-owned player and input assignments, returns a deterministic result for the same final state, and cleans up on restart or exit without leaking state into the next scene.

The pull request documents how setup, result delivery, retry, early exit, and teardown were tested for every supported player count. A dependency on a new shared interface requires explicit design review rather than placing minigame-specific behavior in the shell.

## Networking

Network-capable minigames will extend local contract v1 through a proposed session interface documented in [networking architecture](networking.md). The networking code-level API will be formalized in milestone 12 of the [networking implementation plan](../plans/networking.md), **after** the milestone 10 `HOST_ACTION` combat spike validates the shared action-netcode kit. Names below are **proposals**. Declaring networking metadata does not by itself make a minigame network-ready.

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
| Diagnostic summary (optional) | Tick counts, correction stats, replay notes for debugging |

### Networking rules

1. **Only the authoritative host** may finalize a minigame result. Clients may predict locally for display but must accept host results.
2. **Declare `local_only` or `network_capable`** in the proposal and implemented minigame README.
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

### Network integration definition of done

In addition to the design and local integration definitions of done, a network-capable minigame is review-ready when:

- it declares its sync profile and supported player counts (2–4 `PlayerSlot`s or a documented subset);
- it runs without creating its own transport;
- host and all clients agree on results in manual multi-peer tests documented in the PR;
- teardown leaves no registered RPCs, session listeners, or action-netcode kit registrations.

`HOST_ACTION` minigames additionally require:

- documented network-condition playtests (50, 100, and 150 ms latency; jitter; 1–2% loss where feasible);
- hitscan and/or projectile behavior validated through the shared kit;
- no durable network identity based on Godot node paths.

See [Decision 0003](../decisions/0003-peer-hosted-networking.md) for authority model and validation gates.
