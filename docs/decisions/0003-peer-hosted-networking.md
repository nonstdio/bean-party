# Decision: Peer-hosted host-authoritative networking

Date: 2026-07-11

Status: Proposed

## Implementation checkpoint

The repository contains debug proofs for the offline session/phase foundation and ENet milestones 3–5, plus a partial milestone 6 placeholder phase flow. This evidence does not change the decision status: milestones 7 and 9 and the other validation gates below have not completed, required manual evidence is not stored in the repository, and no network-capable contract minigame exists. See the [networking plan status](../plans/networking.md#milestone-overview) and [runtime debug harness guide](../guides/runtime-debug-harnesses.md).

## Context

Bean Party is a short-session social party game: a board frames the match and 30–90 second minigames create the memorable moments. The project has accepted **Godot 4.7 stable** with **GDScript** ([Decision 0001](0001-godot-engine.md)) and a local-first contributor workflow. Online play is a later milestone, not a blocker for the first local vertical slice.

Constraints that matter for this decision:

- **2–4 logical players** per match (**architectural direction**). A match may have 1–4 network peers depending on couch/online mix; one peer may own multiple local `PlayerSlot`s.
- The shared **shell** (lobby, board, phase transitions, economy, results) must stay separate from independently contributed **minigames** ([minigame integration contract](../architecture/minigame-integration.md), [Godot architecture](../architecture/godot-project.md)).
- Contributors need a path that works for LAN/direct-IP development now and a future Steam release without rewriting board or minigame rules.
- This record proposes a baseline aligned with the 2–4 player compatibility target in [game design](../design/game.md).

## Options considered

- **Dedicated servers or relay-only authority** — strongest consistency and cheat resistance; requires matchmaking, session brokering, hosting cost, and ops the project does not have in pre-production.
- **Peer-hosted, host-authoritative** — one player's machine owns canonical state; clients submit intentions and inputs; fits friend-session party games.
- **Universal deterministic lockstep or rollback (GGPO-style)** — lowest perceived latency for fighting games; demands strict cross-platform determinism across mixed 2D/3D minigames and raises contributor burden.
- **Godot high-level Multiplayer API** ([MultiplayerAPI](https://docs.godotengine.org/en/4.7/classes/class_multiplayerapi.html), [SceneMultiplayer](https://docs.godotengine.org/en/4.7/classes/class_scenemultiplayer.html)) vs raw sockets — the Multiplayer API integrates RPCs, peer IDs, and channels with the scene tree; raw ENet/Steam sockets would duplicate session plumbing in every minigame.
- **`MultiplayerSynchronizer` as the primary replication model** — convenient for whole-scene sync; too coarse for explicit authority boundaries (board economy, RNG, scoring) and risks replicating state clients must not own.

## Decision

Adopt the following baseline (**architectural direction** unless labeled otherwise):

| Area | Choice |
| --- | --- |
| Match topology | **Host-authoritative, peer-hosted** matches for **2–4** logical players (hard cap: 4 `PlayerSlot`s) |
| Game-facing API | Godot **high-level Multiplayer API** |
| Initial transport | **`ENetMultiplayerPeer`** for LAN/direct-IP spike ([ENetMultiplayerPeer](https://docs.godotengine.org/en/4.7/classes/class_enetmultiplayerpeer.html)) |
| Future transport | **Transport abstraction** so [Steam Networking Sockets](https://partner.steamgames.com/doc/features/networking) / [Steam Datagram Relay](https://partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay) can replace ENet without changing board or minigame rules |
| Sync model | **Reliable authoritative** sync for lobby, board, phase transitions, match economy, RNG, and results; **input submission + host simulation** for real-time minigames; **snapshot interpolation** for remote entities; sync profiles `HOST_SNAPSHOT` (optional prediction) and `HOST_ACTION` (required prediction for player movement) |
| Authority vs players | **Authority process**, **network peer**, and **`PlayerSlot`** are separate; gameplay must not assume the authority always controls a bean (**deferred:** dedicated headless authority) |
| Lockstep / rollback | **No project-wide** deterministic lockstep or rollback requirement; `CUSTOM_APPROVED` for per-minigame exceptions |
| Players vs peers | **Logical `PlayerSlot`s separate from network peers** so one machine can own multiple local-controller players |
| Reconnect / migration | **Non-host reconnect** at phase boundaries (**architectural direction**). **Any host disconnect ends the session cleanly in v1**, regardless of phase. Phase-boundary snapshots support testing, non-host reconnect, and future recovery. **Host migration** and minigame abort/replay after host loss are **deferred** to milestone 13 |

See [networking architecture](../architecture/networking.md) for topology, authority tables, phase machine, and message categories. See [networking implementation plan](../plans/networking.md) for milestones and validation.

### Why peer-hosted authority fits a party game

- Sessions are friend-hosted, short, and social—not persistent ranked ladders.
- Board play and phase changes are low-frequency authoritative events; most bandwidth goes to brief minigames.
- Zero dedicated-server ops cost matches pre-production and a small contributor team.
- Couch-plus-online hybrid (multiple `PlayerSlot`s per peer) maps naturally to “one household joins as one connection.”

### Why dedicated servers are not the initial choice

Dedicated servers excel when sessions are long-lived, competitive integrity is paramount, or the product needs always-on matchmaking. Bean Party's first online milestone is “friends can finish a board together.” Matchmaking, accounts, relay brokering, and anti-cheat are **deferred**. A dedicated-server path remains an alternative if peer-hosted migration and cheat concerns prove unacceptable after spike validation.

### Why universal rollback or lockstep is not the initial choice

- Most minigames are 30–90 seconds; host simulation with periodic snapshots and interpolation is simpler for minigame authors.
- Lockstep requires identical simulation across peers; mixed 2D/3D minigames with different physics and floating-point paths make that expensive.
- Rollback is reserved for minigames that demonstrate a need and can satisfy a stricter contract (`CUSTOM_APPROVED`).

### Transport strategy

**Implemented spike:** `MatchSession` owns connection lifecycle and uses the concrete `EnetTransportAdapter` helper to create `ENetMultiplayerPeer` server/client peers. This proves app-owned transport setup and teardown for direct address/port sessions. It is not yet a general `TransportAdapter` interface, does not support Steam substitution, and is not exposed to minigames. Board and minigames must not construct ENet or Steam peers directly.

**Open question:** equivalent RPC channel behavior in candidate Godot Steam peer extensions must be investigated in milestone 11; channel parity is a **release blocker** for Steam, not a minor note.

## Consequences

### What becomes easier

- Contributors implement minigames against a single host-authority model and declared sync profiles.
- Local multiplayer can share the same `PlayerSlot` model as online play.
- LAN playtests work without Steam or cloud infrastructure.
- Phase-boundary snapshots give one recovery primitive for reconnect and host migration.

### What becomes harder or required

- The host peer runs authoritative simulation; host advantage is possible in real-time minigames—mitigate with server-side scoring and validation, not client-reported wins.
- **Host migration** and abort/replay after host loss are **deferred** to milestone 13. In v1, **any host disconnect ends the session cleanly** for all peers—there is no surviving authority to restore snapshots without migration or dedicated servers.
- **`HOST_ACTION`** minigames (3D shooters, brawls) need a shared action-netcode kit and combat spike before the networking API is frozen; a movement-only demo is insufficient.
- Bandwidth scales with player count; 4-player `HOST_SNAPSHOT` minigames need measurement (**open question**: snapshot aggregation vs interest management).
- Every network-capable minigame must declare a sync profile and clean up network state on teardown.
- Automated tests must cover phase agreement, result agreement, and disconnect recovery—not only “feels fine” playtests.

### Host advantage and host disconnect

| Scenario | Intended first-version behavior | Label |
| --- | --- | --- |
| Host has lower latency to authority | Expected; scoring and win detection remain host-side | **Architectural direction** |
| **Any host disconnect** (any phase, including `Countdown` / `ActiveMinigame`) | End session cleanly; return all peers to lobby/menu with a clear message | **Architectural direction** (v1) |
| Non-host disconnect | `PlayerSlot` → `inactive`; match may continue | **Spike assumption** |
| Non-host reconnect at phase boundary | Restore from snapshot + `match_epoch` | **Architectural direction** |
| Host migration (continue match after host loss) | Remaining peers elect host and resume | **Deferred** (milestone 13) |
| Host loss during minigame → abort round and replay | Requires surviving authority (migration or reconnect) | **Deferred** (milestone 13, after migration) |

Host migration sub-problems (detection, election, snapshot source on crash, RPC continuity, player-facing resync) are documented in [networking architecture](../architecture/networking.md#host-migration-and-disconnect-policy).

### Relationship to local-first development

Local play remains the fastest path for minigame iteration. The repository implements offline `PlayerSlot`s and phase logic without a network peer, plus a separate accepted local minigame contract harness. These proofs are not wired into one app match flow yet. Future online layers must attach through the session boundary so a minigame that works locally can become network-capable by declaring a sync profile—not by forking its rules.

### Explicitly out of scope for this decision

- Matchmaking, accounts, progression services, voice chat, anti-cheat infrastructure, cross-platform certification
- Mid-minigame late join (**deferred**)
- Third-party networking addons in the documentation PR
- Blind whole-scene replication via `MultiplayerSynchronizer` as the default integration pattern

## Validation required before Accepted

This decision moves to **Accepted** only when spike milestones in [networking implementation plan](../plans/networking.md) demonstrate:

1. **Phase agreement** — all peers report the same match phase after every host-driven transition.
2. **Result agreement** — placements, scores, and board rewards match on all peers after each minigame.
3. **Board-state consistency** — canonical snapshot hash (or equivalent) matches across peers at phase boundaries.
4. **Disconnect recovery (v1 scope)** — non-host disconnect handled; non-host reconnect at phase boundaries; **any host disconnect ends the session cleanly** in every phase.
5. **Bandwidth sampling** — message rates and payload sizes recorded for at least one `HOST_SNAPSHOT` minigame at 2 and 4 `PlayerSlot`s.
6. **4-player session** — e.g. 2 peers × 2 local players, or 4 single-player peers.

Host migration (milestone 13) is **not** required to move this decision to **Accepted**. The minigame networking API must **not** be considered frozen until milestone 10 (`HOST_ACTION` combat spike) and milestone 12 (API stabilization) complete.

Human playtesting remains required for perceived input responsiveness; it is not sufficient on its own.
