# Decision: Peer-hosted host-authoritative networking

Date: 2026-07-11

Status: Proposed

## Context

Bean Party is a short-session social party game: a board frames the match and 30–90 second minigames create the memorable moments. The project has accepted **Godot 4.7 stable** with **GDScript** ([Decision 0001](0001-godot-engine.md)) and a local-first contributor workflow. Online play is a later milestone, not a blocker for the first local vertical slice, but the networking design must not assume a four-player ceiling.

Constraints that matter for this decision:

- **Up to 8 logical players** per match (**architectural direction**). A match may have 1–8 network peers depending on couch/online mix; one peer may own multiple local `PlayerSlot`s.
- The shared **shell** (lobby, board, phase transitions, economy, results) must stay separate from independently contributed **minigames** ([minigame contract](../minigame-contract.md), [Godot architecture](../godot-architecture.md)).
- Contributors need a path that works for LAN/direct-IP development now and a future Steam release without rewriting board or minigame rules.
- This record proposes a baseline. Early spikes may prove with 2–4 players first (**spike assumption**), but session, snapshot, and message schemas must size for eight `PlayerSlot`s.

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
| Match topology | **Host-authoritative, peer-hosted** matches for **2–8** logical players (hard cap: 8 `PlayerSlot`s) |
| Game-facing API | Godot **high-level Multiplayer API** |
| Initial transport | **`ENetMultiplayerPeer`** for LAN/direct-IP spike ([ENetMultiplayerPeer](https://docs.godotengine.org/en/4.7/classes/class_enetmultiplayerpeer.html)) |
| Future transport | **Transport abstraction** so [Steam Networking Sockets](https://partner.steamgames.com/doc/features/networking) / [Steam Datagram Relay](https://partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay) can replace ENet without changing board or minigame rules |
| Sync model | **Reliable authoritative** sync for lobby, board, phase transitions, match economy, RNG, and results; **input submission + host simulation** for real-time minigames; **snapshot interpolation** for remote entities; **optional** prediction/reconciliation for the locally controlled character |
| Lockstep / rollback | **No project-wide** deterministic lockstep or rollback requirement; a latency-sensitive minigame may adopt rollback later via an approved `CUSTOM_APPROVED` sync profile |
| Players vs peers | **Logical `PlayerSlot`s separate from network peers** so one machine can own multiple local-controller players |
| Reconnect / migration | **Reconnect** and **host migration** only between safe phases initially (**spike assumption**). Host loss during a short minigame: abort round, restore last phase-boundary snapshot, migrate if possible, replay |

See [networking architecture](../networking-architecture.md) for topology, authority tables, phase machine, and message categories. See [networking implementation plan](../networking-implementation-plan.md) for milestones and validation.

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

**Spike assumption:** `ENetMultiplayerPeer` behind a proposed session/transport boundary (`MatchSession`, `TransportAdapter`—names are proposals). Board and minigames must not construct ENet or Steam peers directly.

**Open question:** RPC channel parity in candidate Godot Steam peer extensions must be investigated in milestone 10 before treating Steam as a drop-in replacement.

## Consequences

### What becomes easier

- Contributors implement minigames against a single host-authority model and declared sync profiles.
- Local multiplayer can share the same `PlayerSlot` model as online play.
- LAN playtests work without Steam or cloud infrastructure.
- Phase-boundary snapshots give one recovery primitive for reconnect and host migration.

### What becomes harder or required

- The host peer runs authoritative simulation; host advantage is possible in real-time minigames—mitigate with server-side scoring and validation, not client-reported wins.
- **Host migration at phase boundaries** is the highest-risk open design: election, snapshot handoff, and RPC rebinding are undefined until milestone 9 validates them. Until then, this decision stays **Proposed**.
- Bandwidth scales with player count; 8-player `HOST_SNAPSHOT` minigames need measurement (**open question**: snapshot aggregation vs interest management).
- Every network-capable minigame must declare a sync profile and clean up network state on teardown.
- Automated tests must cover phase agreement, result agreement, and disconnect recovery—not only “feels fine” playtests.

### Host advantage and host disconnect

| Scenario | Intended first-version behavior | Label |
| --- | --- | --- |
| Host has lower latency to authority | Expected; scoring and win detection remain host-side | **Architectural direction** |
| Host disconnect during `Countdown` or `ActiveMinigame` | Abort round; restore last phase-boundary snapshot; elect new host if possible; replay minigame | **Spike assumption** |
| Host disconnect at phase boundary (lobby, board, results, etc.) | Remaining peers continue from stored snapshot | **Open question** until milestone 9 |
| In-round authority handoff without abort | Not supported in v1 | **Deferred** |

Host migration sub-problems (detection, election, snapshot source on crash, RPC continuity, player-facing resync) are documented in [networking architecture](../networking-architecture.md#host-migration-and-disconnect-policy).

### Relationship to local-first development

Local play remains the fastest path for minigame iteration. The offline session model (milestone 1) should implement `PlayerSlot`s and phase logic without any network peer. Online layers attach through the session boundary so a minigame that works locally can become network-capable by declaring a sync profile—not by forking its rules.

### Explicitly out of scope for this decision

- Matchmaking, accounts, progression services, voice chat, anti-cheat infrastructure, cross-platform certification
- Mid-minigame late join (**deferred**)
- Third-party networking addons in the documentation PR
- Blind whole-scene replication via `MultiplayerSynchronizer` as the default integration pattern

## Validation required before Accepted

This decision moves to **Accepted** only when spike milestones in [networking implementation plan](../networking-implementation-plan.md) demonstrate:

1. **Phase agreement** — all peers report the same match phase after every host-driven transition.
2. **Result agreement** — placements, scores, and board rewards match on all peers after each minigame.
3. **Board-state consistency** — canonical snapshot hash (or equivalent) matches across peers at phase boundaries.
4. **Disconnect recovery** — documented matrix passes for non-host disconnect and host disconnect (Case A abort/replay; Case B continue from snapshot at phase boundaries).
5. **Bandwidth sampling** — message rates and payload sizes recorded for at least one `HOST_SNAPSHOT` minigame at 4 and 8 `PlayerSlot`s.
6. **8-player session** — e.g. 4 peers × 2 local players, or 8 single-player peers when hardware allows.

Human playtesting remains required for perceived input responsiveness; it is not sufficient on its own.
