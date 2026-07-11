# WebRTC transport investigation

Status: **In progress (Phase 0)**

## Question

Can WebRTC with a small signaling server replace Steam/ENet for internet friend sessions behind `TransportAdapter` without rewriting board, phase, or minigame gameplay code?

## Context

Steam transport follow-up is **backlogged**. WebRTC is the active internet transport path. The repository already has:

- `TransportAdapter` / `TransportAdapterRegistry`
- `MatchSession.host_with_transport` / `join_with_transport`
- `WebRtcTransportAdapter`, `WebRtcMultiplayerCoordinator`, `WebRtcSignalingClient`
- Node signaling server in `tools/signaling/`

## Phase 0 scope (current)

- webrtc-native GDExtension (developer-installed, not vendored in git)
- Star topology (`use_mesh = false`) with host relay via `WebRTCMultiplayerPeer`
- Public STUN only (`stun:stun.l.google.com:19302`)
- Async connect through `MatchSession` (`WEBRTC_CONNECT_TIMEOUT_MSEC = 20000`)

## Proposed WebRTC channel map

| Channel | Lanes |
| --- | --- |
| 0 reliable | `SESSION_CONTROL`, `ENTITY_LIFECYCLE` |
| 1 unreliable ordered | `PLAYER_INPUT` |
| 2 unreliable | `WORLD_SNAPSHOT`, `COSMETIC` |

Constants live in `TransportMessageLanes.WEBRTC_CHANNEL_BY_LANE`. RPC wiring is follow-up work.

## Go / no-go gates

| Gate | Status |
| --- | --- |
| `TransportAdapter` registration | Done |
| Signaling protocol client | Done |
| Signaling server (dev) | Done |
| webrtc-native install docs | Done |
| 2-peer internet echo (manual) | **Open** |
| Join-code production UI | Phase 1 |
| TURN relay | Phase 2 |
| 4-peer NAT matrix | Phase 2 |

## Backlog (not in scope)

- Steam / GodotSteam transport integration — see [steam transport investigation](steam-transport-investigation.md)

## Follow-up

- Phase 1: join-code UX in `network_session_view`, reconnect keys by `room_code`
- Phase 2: TURN, lane RPC wiring, ops runbook
- Update [networking plan](../plans/networking.md) milestone table when Phase 0 manual spike completes
