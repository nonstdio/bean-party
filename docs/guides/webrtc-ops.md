# WebRTC operations runbook

Bean Party's internet transport uses a **signaling server** (WebSocket) plus **ICE** (STUN/TURN) for peer connectivity. Gameplay still runs on Godot RPCs; this document covers operating the transport layer for friend-hosted sessions.

## Components

| Component | Role | Repository location |
| --- | --- | --- |
| Signaling server | Exchanges SDP offers/answers and ICE candidates; assigns room codes | `tools/signaling/` |
| STUN | Discovers public addresses for hole-punching | Default: `stun:stun.l.google.com:19302` |
| TURN | Relays media when direct peer paths fail | Operator-provided |
| webrtc-native | Godot GDExtension for desktop WebRTC | `tools/setup-webrtc-native.ps1` |

Star topology: clients connect to peer `1` (host). The host relays gameplay RPCs.

## Signaling server (development)

```bash
cd tools/signaling
npm install
npm start
```

Default URL: `ws://127.0.0.1:9080` (`MatchConstants.DEFAULT_WEBRTC_SIGNALING_URL`).

Godot sends WebSocket frames as binary `Buffer` payloads; the bundled server normalizes them to text before JSON parsing.

## Signaling server (production sketch)

1. Run `server.js` behind a reverse proxy that terminates **TLS** (`wss://`).
2. Restrict origins or add authentication before exposing signaling publicly.
3. Set the in-game **signaling URL** to the public `wss://` endpoint.
4. Monitor process health, open connections, and room count (extend `server.js` or wrap with your process manager).

The signaling server does **not** carry gameplay traffic. It only negotiates WebRTC sessions.

## ICE / TURN configuration

`WebRtcIceConfig` resolves ICE servers in this order:

1. Explicit `ice_servers` passed to `MatchSession.host_with_transport` / `join_with_transport`
2. Environment variable `BEAN_PARTY_ICE_SERVERS_JSON` (JSON array or object)
3. `user://webrtc_ice_servers.json` (per-user installs / exports)
4. `res://config/webrtc_ice_servers.json` (project-local, gitignored)
5. Default public STUN only

### Config file

Copy [config/webrtc_ice_servers.example.json](../../config/webrtc_ice_servers.example.json) to `config/webrtc_ice_servers.json` (repository root, gitignored) or `user://webrtc_ice_servers.json`:

```json
[
  {
    "urls": ["stun:stun.l.google.com:19302"]
  },
  {
    "urls": ["turn:turn.example.com:3478", "turns:turn.example.com:5349"],
    "username": "bean-party-user",
    "credential": "replace-with-generated-secret"
  }
]
```

Restart Godot after changing project config files.

### Environment variables

| Variable | Purpose |
| --- | --- |
| `BEAN_PARTY_ICE_SERVERS_JSON` | Full ICE server list as JSON (array or single object) |
| `BEAN_PARTY_TURN_URLS` | Comma-separated TURN URLs when JSON is not used |
| `BEAN_PARTY_TURN_USERNAME` | TURN username (with `BEAN_PARTY_TURN_URLS`) |
| `BEAN_PARTY_TURN_CREDENTIAL` | TURN password or time-limited credential |

Example (PowerShell):

```powershell
$env:BEAN_PARTY_TURN_URLS = "turn:turn.example.com:3478,turns:turn.example.com:5349"
$env:BEAN_PARTY_TURN_USERNAME = "bean-party-user"
$env:BEAN_PARTY_TURN_CREDENTIAL = "secret"
```

### TURN provider options

| Option | Notes |
| --- | --- |
| Self-hosted [coturn](https://github.com/coturn/coturn) | Full control; requires TLS cert for `turns:` |
| Managed TURN (Twilio, Xirsys, Metered, etc.) | Faster setup; watch egress costs |
| Game-specific relay | Not required for the debug shell; evaluate when scaling playtests |

Use **time-limited credentials** in production. Do not commit live TURN secrets to git.

## RPC message lanes

Shell and minigame RPCs use channel `0` with lane-specific transfer modes:

| Lane | RPC channel | Delivery | Traffic |
| --- | --- | --- | --- |
| Session / board / phase | 0 | Reliable | Lobby, board, phase, echo |
| Player input | 0 | Unreliable ordered | Minigame input RPCs |
| World snapshot / cosmetic | 0 | Unreliable | Snapshot RPCs |

Godot multiplexes channel `0` into three internal lanes (reliable, unreliable ordered, unreliable). WebRTC exposes exactly those three data channels per peer. Non-zero RPC channels map to unavailable WebRTC indices and fail at runtime.

ENet still supports additional physical channels `1`–`3` for future tuning (`TransportMessageLanes.CHANNEL_PLAYER_INPUT`, etc.), but shared RPC decorators stay on channel `0` so both transports behave the same.

See [WebRTC implementation notes](webrtc-implementation-notes.md) for why non-zero RPC channels fail on WebRTC and how Godot maps transfer modes to data channels.

## NAT traversal test matrix

Record results when validating a signaling + TURN deployment. STUN-only success is common on home LANs; symmetric NAT and carrier-grade NAT often require TURN.

### Two-peer scenarios

| # | Host network | Client network | STUN only | TURN required | Notes |
| --- | --- | --- | --- | --- | --- |
| A | Same LAN | Same LAN | Expected | — | Fastest local smoke test |
| B | Home NAT | Same home LAN | Expected | — | Router hairpin may vary |
| C | Home NAT | Different home NAT | Often | Sometimes | Primary friend-session case |
| D | Mobile hotspot | Home NAT | Rare | Expected | Strict NAT common |
| E | Corporate Wi‑Fi | Home NAT | Rare | Expected | UDP/TURN policy dependent |

### Four-peer scenarios (star host)

Run one host plus three remote clients. Verify lobby slot assignment, board start, and Action Spike movement for each client.

| # | Peers | Pass criteria |
| --- | --- | --- |
| 1 | 4 × home NAT (distinct ISPs) | All join within 20s; echo RPC succeeds; minigame inputs reconcile |
| 2 | Host on LAN + 3 remote NAT | LAN host reachable; remotes use TURN if configured |
| 3 | Host disconnect | Clients receive host-left signal; no ghost slots |

### Per-run checklist

- [ ] Signaling server reachable from every peer (`wss://` in production)
- [ ] ICE config includes STUN + TURN when testing restrictive NAT rows
- [ ] Godot restarted after ICE config changes
- [ ] Room code shared; host selected **WebRTC (internet)** with empty room code
- [ ] No `RPC via a multiplayer peer which is not connected` errors
- [ ] `Echo test` succeeds host ↔ each client
- [ ] Board start + Action Spike movement on each client
- [ ] Record: transport (`webrtc`), signaling URL, STUN/TURN endpoints, NAT row, pass/fail, Godot version

## Troubleshooting

| Symptom | Likely cause | Action |
| --- | --- | --- |
| `No default WebRTC extension configured` | webrtc-native missing | Run `tools/setup-webrtc-native.ps1`; restart Godot |
| Signaling disconnect `4000` | Protocol mismatch | Use bundled `tools/signaling/server.js` |
| Stuck in `Connecting...` | ICE failed | Add TURN; verify firewall UDP |
| RPC errors on join | ICE not complete | Ensure Phase 1+ connect timing fix is present |
| `Unable to send packet on channel 4, max channels: 3` | RPC uses non-zero `transfer_channel` on WebRTC | Use channel `0`; see [implementation notes](webrtc-implementation-notes.md#godot-channel-model-critical) |
| One client works, another fails | Asymmetric NAT | Enable TURN relay |

## Related documents

- [WebRTC setup](webrtc-setup.md) — developer install and local spikes
- [WebRTC implementation notes](webrtc-implementation-notes.md) — Godot channel model, RPC timing, signaling wire format
- [WebRTC transport investigation](../research/webrtc-transport-investigation.md)
- [Runtime debug harnesses](runtime-debug-harnesses.md)
- [Networking architecture](../architecture/networking.md#transport-message-lanes)
