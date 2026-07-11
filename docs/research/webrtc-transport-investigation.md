# WebRTC transport investigation

Status: **In progress (Phase 2)**

## Question

Can WebRTC with a small signaling server replace Steam/ENet for internet friend sessions behind `TransportAdapter` without rewriting board, phase, or minigame gameplay code?

## Context

Steam transport follow-up is **backlogged**. WebRTC is the active internet transport path. The repository already has:

- `TransportAdapter` / `TransportAdapterRegistry`
- `MatchSession.host_with_transport` / `join_with_transport`
- `WebRtcTransportAdapter`, `WebRtcMultiplayerCoordinator`, `WebRtcSignalingClient`
- Node signaling server in `tools/signaling/`
- `WebRtcIceConfig` for STUN/TURN resolution

## Phase 0–1 (done)

- webrtc-native GDExtension (developer-installed, not vendored in git)
- Star topology (`use_mesh = false`) with host relay via `WebRTCMultiplayerPeer`
- Async connect through `MatchSession` (`WEBRTC_CONNECT_TIMEOUT_MSEC = 20000`)
- Join-code debug UI and reconnect keys (`signaling_url` + `room_code`)
- ICE polling before lobby RPCs; manual 2-peer lobby/board/minigame validated

## WebRTC lane map (implemented)

| Lane | RPC channel | Transfer mode | WebRTC data channel |
| --- | --- | --- | --- |
| `SESSION_CONTROL`, `ENTITY_LIFECYCLE` | 0 | Reliable | Reliable |
| `PLAYER_INPUT` | 0 | Unreliable ordered | Ordered |
| `WORLD_SNAPSHOT`, `COSMETIC` | 0 | Unreliable | Unreliable |

Constants: `TransportMessageLanes.CHANNEL_RPC` and `WEBRTC_CHANNEL_BY_LANE`.

## Phase 2 (current)

| Item | Status |
| --- | --- |
| TURN / ICE config (`WebRtcIceConfig`, example JSON, env vars) | Done |
| Shell/minigame RPC `transfer_channel` wiring | Done |
| Operations runbook + NAT matrix | Done ([webrtc-ops.md](../guides/webrtc-ops.md)) |
| Formal 4-peer NAT matrix execution | **Open** (manual; template in runbook) |

Default STUN remains enabled when no TURN is configured.

Developer implementation notes (Godot channel limits, RPC gating, signaling wire format): [WebRTC implementation notes](../guides/webrtc-implementation-notes.md).

## Go / no-go gates

| Gate | Status |
| --- | --- |
| `TransportAdapter` registration | Done |
| Signaling protocol client | Done |
| Signaling server (dev) | Done |
| webrtc-native install docs | Done |
| 2-peer lobby/board/minigame (manual) | Done |
| Join-code production UI | Done (debug shell) |
| TURN relay configuration path | Done |
| RPC lane channels | Done |
| 4-peer NAT matrix | Open (manual) |

## Backlog (not in scope)

- Steam / GodotSteam transport integration — see [steam transport investigation](steam-transport-investigation.md)
- Production signaling auth, rate limits, and matchmaking
- Automated NAT matrix in CI

## Related documents

- [WebRTC setup](../guides/webrtc-setup.md)
- [WebRTC operations runbook](../guides/webrtc-ops.md)
- [WebRTC implementation notes](../guides/webrtc-implementation-notes.md)
- [Networking plan](../plans/networking.md)
