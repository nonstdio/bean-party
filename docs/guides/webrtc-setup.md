# WebRTC setup

Bean Party's internet transport uses Godot's `WebRTCMultiplayerPeer` with a small WebSocket signaling server and ICE (STUN/TURN) for NAT traversal.

## Prerequisites

- Godot 4.7 stable ([godot-setup.md](godot-setup.md))
- Node.js 18+ for the local signaling server (`tools/signaling/`)
- [webrtc-native](https://github.com/godotengine/webrtc-native) GDExtension on desktop exports

## Install webrtc-native (desktop)

From the repository root on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup-webrtc-native.ps1
powershell -ExecutionPolicy Bypass -File .\tools\godot.ps1 validate
```

The script extracts `addons/webrtc_native/` into the **repository root** (`bean-party/`, not the parent `beansinc/` folder). If WebRTC errors mention `No default WebRTC extension configured`, re-run the script from the repo root and restart the editor.

On macOS or Linux, download [`godot-extension-webrtc_native.zip`](https://github.com/godotengine/webrtc-native/releases/download/1.2.1-stable/godot-extension-webrtc_native.zip) and extract it to the repository root.

The extension is MIT-licensed. Do not commit generated `.godot/` import output.

## Run signaling for local spikes

```bash
cd tools/signaling
npm install
npm start
```

Default signaling URL: `ws://127.0.0.1:9080` (`MatchConstants.DEFAULT_WEBRTC_SIGNALING_URL`).

## Host or join (debug shell)

1. Start the signaling server.
2. Launch Godot with webrtc-native installed and run the main scene (`F5`).
3. Select transport **WebRTC (internet)**.
4. **Host:** leave room code empty, select **Host**, copy the displayed room code.
5. **Join:** enter the signaling URL and room code, select **Join**.
6. Use **Echo test**, then run the lobby → board → minigame flow.

See [README hosting steps](../../README.md#host-a-multiplayer-session) for a concise checklist.

## ICE and TURN (Phase 2)

By default only public STUN is used (`stun:stun.l.google.com:19302`). Restrictive NATs need a TURN relay.

Configure ICE servers via:

- `config/webrtc_ice_servers.json` (copy from [config/webrtc_ice_servers.example.json](../../config/webrtc_ice_servers.example.json))
- `user://webrtc_ice_servers.json`
- Environment variables (`BEAN_PARTY_ICE_SERVERS_JSON` or `BEAN_PARTY_TURN_*`)

Full deployment, NAT matrix, and troubleshooting: [WebRTC operations runbook](webrtc-ops.md).

## Related documents

- [WebRTC operations runbook](webrtc-ops.md)
- [WebRTC transport investigation](../research/webrtc-transport-investigation.md)
- [Networking architecture](../architecture/networking.md)
- [Runtime debug harnesses](runtime-debug-harnesses.md) — ENet LAN path remains available
