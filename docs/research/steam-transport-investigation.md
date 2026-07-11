# Steam transport investigation

Status: **Concluded**

## Question

Can Steam Networking Sockets / Steam Datagram Relay (SDR) replace ENet behind a shared `TransportAdapter` without rewriting board, phase, or minigame gameplay code?

## Context

[Decision 0003](../decisions/0003-peer-hosted-networking.md) proposes peer-hosted play with ENet for LAN/direct-IP development and a future Steam transport for release. Milestone 11 must produce a **go / no-go / conditional go** recommendation and identify **channel parity** gaps before milestone 12 freezes the networking API.

Bean Party's current debug shell routes all RPCs through Godot's `SceneMultiplayer` on a single `MultiplayerPeer`. The [networking architecture](../architecture/networking.md#transport-message-lanes) defines five logical lanes (session control, entity lifecycle, player inputs, world snapshots, cosmetic) that should not block one another. ENet supports multiple transfer channels; current RPCs still default to channel 0.

## Sources and evidence

| Source | Finding |
| --- | --- |
| [GodotSteam MultiplayerPeer](https://godotsteam.com/classes/multiplayer_peer/) | Merged into main GodotSteam 4.17+; uses SteamNetworkingSockets (`createListenSocketP2P`, `connectP2P`); exposes `create_host`, `create_client`, `host_with_lobby`, `connect_to_lobby`. |
| [GodotSteam MultiplayerPeer changelog](https://godotsteam.com/changelog/multiplayer_peer/) | Retired standalone repo; July 2025 replaced SteamNetworkingMessages with SteamNetworkingSockets. |
| [expressobits/steam-multiplayer-peer](https://github.com/expressobits/steam-multiplayer-peer) | GDExtension using SteamSockets; author paused development Dec 2025; **explicitly no channel support** (issue #2). |
| Repository code audit | All shell/minigame RPCs use `@rpc(..., reliable)` or `@rpc(..., unreliable)` without `transfer_channel`; lane separation is documented but not wired. |
| Milestone 11 implementation | `TransportAdapter` interface, `EnetTransportAdapter`, `SteamTransportAdapter` stub, `TransportMessageLanes` proposed ENet map, `MatchSession.host_with_transport` / `join_with_transport`. |

## Findings

### Transport abstraction

A thin `TransportAdapter` boundary is sufficient. `MatchSession` can swap peers by transport id without changing lobby, board, phase, or minigame session code. Gameplay continues to use Godot RPCs and `multiplayer` peer ids.

### Candidate: GodotSteam MultiplayerPeer (conditional)

**Pros:**

- Official community path; MultiplayerPeer merged into GodotSteam main branch (4.17+).
- Uses SteamNetworkingSockets (low-level, ENet-like connection model).
- Integrates with Steam lobbies (`host_with_lobby`, `connect_to_lobby`) for NAT/SDR-friendly joins.
- Works with existing Godot RPC / `SceneMultiplayer` patterns once peer is bound.

**Cons / gaps:**

- Requires Steamworks SDK and legal review before committing SDK or redistributables to the repository.
- Typically needs a **custom Godot build** (module) or approved distribution path—not plain stock Godot export without additional setup.
- **Channel parity unverified in CI:** GodotSteam docs do not clearly document ENet-equivalent `transfer_channel` mapping for all five lanes. Must spike with real Steam peers before declaring parity.
- Steam init, lobby flow, and dedicated-server packaging are separate from transport peer creation.

### Ruled out: expressobits Steam Multiplayer Peer

No channel support; development paused. Incompatible with the architecture requirement that inputs/snapshots not block session control without application-level multiplexing.

### Current ENet lane gap

Even on ENet, RPCs are not yet assigned to `TransportMessageLanes` channels. Milestone 11 documents a **proposed** map (channels 0–3). Wiring RPCs to channels is follow-up work that benefits both ENet hygiene and Steam parity measurement.

## Options and trade-offs

| Option | Outcome | Cost |
| --- | --- | --- |
| **A. Conditional go — GodotSteam** | Proceed with Steam as optional transport behind `TransportAdapter` after legal review + channel spike | Custom build/pipeline, Steam partner account, manual CI |
| **B. ENet-only longer** | Defer Steam; ship LAN/direct-IP only | No Steam release path without revisit |
| **C. Application-level multiplexing** | Single Steam channel; frame type byte in payload | More code in session layer; duplicates Godot channel feature |

## Conclusion

**Recommendation: conditional go** on **GodotSteam MultiplayerPeer** (SteamNetworkingSockets path).

Conditions before production Steam integration:

1. Legal/license review for Steamworks SDK redistribution.
2. Manual spike: host/join through Steam lobby + echo RPCs on all five logical lanes; document actual channel/ordering behavior vs ENet.
3. Wire shell RPCs to `TransportMessageLanes` on ENet first so parity testing has a concrete baseline.
4. No Steam SDK or GodotSteam binaries in this repository until conditions 1–2 pass review.

**No-go** for expressobits GDExtension as primary Steam transport (no channels).

## Follow-up

- Implement `GodotSteamTransportAdapter` in a gated branch or optional build profile after legal review (not in milestone 11 PR).
- Record channel-parity results in a short addendum to this note or a new decision record if Steam becomes required for release.
- See [networking implementation plan — milestone 11](../plans/networking.md#milestone-11-steam-transport-investigation-and-spike) for stop-condition tracking.
