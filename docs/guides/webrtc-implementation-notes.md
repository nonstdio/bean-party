# WebRTC implementation notes

Developer-facing notes from building Bean Party's WebRTC transport. Use this when changing RPCs, signaling, ICE config, or session lifecycle code. Setup steps live in [WebRTC setup](webrtc-setup.md); deployment and NAT testing in [WebRTC operations runbook](webrtc-ops.md).

## Godot channel model (critical)

`WebRTCMultiplayerPeer` creates **three** data channels per peer connection:

| Internal index | Transfer mode | Typical Bean Party lane |
| --- | --- | --- |
| Reliable | `TRANSFER_MODE_RELIABLE` | Session, lobby, board, phase |
| Ordered | `TRANSFER_MODE_UNRELIABLE_ORDERED` | Player input |
| Unreliable | `TRANSFER_MODE_UNRELIABLE` | World snapshots, cosmetic |

Godot maps RPC `transfer_channel` like this (see `modules/webrtc/webrtc_multiplayer_peer.cpp`):

- **`transfer_channel == 0`** — route by `transfer_mode` to one of the three channels above.
- **`transfer_channel > 0`** — physical channel index becomes `transfer_channel + CH_RESERVED_MAX - 1` (with `CH_RESERVED_MAX == 3`).

That means non-zero RPC channels need **extra** negotiated data channels from `create_server(channels_config)` / `create_client(id, channels_config)`. Bean Party does not create those today. A decorator such as `@rpc(..., 2)` maps to physical channel **4**, which triggers:

```text
ERROR: Unable to send packet on channel 4, max channels: 3
```

**Rule:** shared shell and minigame `@rpc` decorators must use **`transfer_channel` 0** and separate lanes by **transfer mode** only. Constants: `TransportMessageLanes.CHANNEL_RPC`.

ENet still documents optional physical channels `1`–`3` (`CHANNEL_PLAYER_INPUT`, etc.) for future tuning, but RPC annotations stay on channel `0` so ENet and WebRTC share the same decorators.

### Lane map in code

| Lane | `@rpc` channel | Transfer mode | `TransportMessageLanes` |
| --- | --- | --- | --- |
| Session / entity lifecycle | 0 | `reliable` | `Lane.SESSION_CONTROL`, `Lane.ENTITY_LIFECYCLE` |
| Player input | 0 | `unreliable_ordered` | `Lane.PLAYER_INPUT` |
| World snapshot / cosmetic | 0 | `unreliable` | `Lane.WORLD_SNAPSHOT`, `Lane.COSMETIC` |

`WEBRTC_CHANNEL_BY_LANE` always returns `CHANNEL_RPC` (0); lane separation is by transfer mode, not by RPC channel index.

## Session lifecycle and RPC timing

### ICE must be connected before client RPCs

WebRTC clients stay in `MatchSession.SessionState.CONNECTING` until ICE data channels are open. Lobby and other client→host RPCs must not fire earlier.

Implemented guards:

- `MatchSession.is_client_rpc_ready()` — client may send RPCs to host.
- `MatchSession.is_peer_route_ready(peer_id)` — host may target a specific peer.
- `NetworkLobbySession._issue_client_rpc()` — queues client RPCs until ready; `_retry_pending_transport_work()` flushes on `session_state_changed`.
- `WebRtcMultiplayerCoordinator.poll_peer_connections()` — polls `WebRTCPeerConnection` each frame so ICE can complete.

Symptom if skipped: `Trying to call an RPC method which does not exist` or RPC errors immediately after join (offer/answer still in flight).

### Host disconnect without peers

`MatchSession.disconnect_session()` broadcasts `_rpc_session_ended` only when `get_remote_peer_ids()` is non-empty. Announcing session end to zero connected peers caused engine errors during early teardown (host disconnect while a client is still connecting).

### Async host/join

WebRTC connect is async (`MatchSession._begin_webrtc_session`, 20s timeout). `_transport_adapter` is assigned before the coordinator starts so timeout/teardown reports the correct transport id. Failed host/join resets the transport adapter.

### Node teardown

`MatchSession._exit_tree()` tears down the peer, resets the transport adapter, and emits `session_state_changed` when the session was still active.

## Signaling protocol

JSON messages match Godot's [webrtc_signaling demo](https://github.com/godotengine/webrtc-native): `{ "type", "id", "data" }`. Enum: `WebRtcSignalingMessages.Message` (`JOIN`, `ID`, `PEER_CONNECT`, …).

### Dev server (`tools/signaling/server.js`)

- Default URL: `ws://127.0.0.1:9080`.
- Star topology: host id `1`, `use_mesh = false`.
- Limits: 4 peers per lobby, 64 KiB max payload, duplicate `JOIN` rejected when `peer.lobby` is already set.
- WebSocket frames must be UTF-8 text; binary frames are rejected (`messageToString()` normalizes `Buffer` / `ArrayBuffer` input).

### ICE candidate wire format

`WebRtcSignalingClient.send_candidate()` sends:

```text
\n{mid}\n{index}\n{sdp}
```

Parsing strips an optional leading newline, then splits into three lines (`mid`, `index`, `sdp`). Tests should build payloads with `JSON.stringify` rather than hand-escaped `\n` in GDScript string literals.

### Lobby join flow

1. Client connects → signaling assigns id → `ID` message.
2. Client sends `JOIN` with room code (empty = host creates room).
3. Server responds with `JOIN` carrying the room code, connects peers with `PEER_CONNECT`, then clients exchange SDP via `OFFER` / `ANSWER` / `CANDIDATE`.

## ICE / STUN / TURN

Resolution order (`WebRtcIceConfig.resolve_ice_servers`):

1. Explicit `ice_servers` in transport options
2. `BEAN_PARTY_ICE_SERVERS_JSON` or `BEAN_PARTY_TURN_*` env vars
3. `user://webrtc_ice_servers.json`
4. `res://config/webrtc_ice_servers.json`
5. Default public STUN (`stun:stun.l.google.com:19302`)

TURN-only configs still get default STUN merged (`_ensure_default_stun`) so peers can attempt direct paths before relay.

Copy [config/webrtc_ice_servers.example.json](../../config/webrtc_ice_servers.example.json) to `config/webrtc_ice_servers.json` (gitignored) for local TURN testing.

## webrtc-native GDExtension

- Not vendored in git; install via `tools/setup-webrtc-native.ps1` (extracts to **repository root** `addons/webrtc_native/`).
- `WebRtcAvailability` probes `WebRTCPeerConnection.initialize()` — do not assume the extension is loaded from file presence alone.
- `WebRtcTransportAdapter.create_server_peer()` is intentionally unused; the coordinator owns `WebRTCMultiplayerPeer` creation after signaling assigns an id.

## Testing notes

- Run `tools/godot.ps1 all` before PRs.
- Godot script RPC metadata uses the key **`channel`**, not `transfer_channel`, in `GDScript.get_rpc_config()`.
- GUT lambdas do not reliably update outer `String`/`int` variables; use a `Dictionary` for signal capture in tests.
- Skip tests that need the extension with `pass_test("reason")`, not `pass("reason")` (invalid GDScript).
- `test_rpc_transfer_channels.gd` asserts channel `0` plus expected `transfer_mode` per lane.

## Common errors

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `Unable to send packet on channel 4, max channels: 3` | RPC uses `transfer_channel` 2+ on WebRTC | Use channel `0`; separate lanes by transfer mode |
| RPC before lobby sync / missing method on join | ICE not ready | Wait for `is_client_rpc_ready()` / queue client RPCs |
| Signaling close `4000` / invalid format | Binary WebSocket frame or oversized payload | Send JSON text; stay under 64 KiB |
| `No default WebRTC extension configured` | webrtc-native not installed or wrong extract path | Re-run setup script from repo root; restart Godot |
| Snapshots never arrive on client; no errors on ENet | Same channel bug as row 1 | Verify minigame `@rpc` decorators use channel `0` |
| Duplicate JOIN / already in lobby | Client sent JOIN twice | Server rejects; client should not re-join after assigned |

## Related documents

- [WebRTC setup](webrtc-setup.md)
- [WebRTC operations runbook](webrtc-ops.md)
- [WebRTC transport investigation](../research/webrtc-transport-investigation.md)
- [Networking architecture](../architecture/networking.md#transport-message-lanes)
- [Transport message lanes](../../scripts/shared/transport_message_lanes.gd)
