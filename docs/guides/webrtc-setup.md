# WebRTC setup

Bean Party's internet transport uses Godot's `WebRTCMultiplayerPeer` with a small WebSocket signaling server and public STUN for NAT traversal.

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

On macOS or Linux, download [`godot-extension-webrtc_native.zip`](https://github.com/godotengine/webrtc-native/releases/download/1.2.1-stable/godot-extension-webrtc_native.zip) and extract it to the repository root.

The extension is MIT-licensed. Do not commit generated `.godot/` import output.

## Run signaling for local spikes

```bash
cd tools/signaling
npm install
npm start
```

Default signaling URL: `ws://127.0.0.1:9080` (`MatchConstants.DEFAULT_WEBRTC_SIGNALING_URL`).

## Manual spike (Phase 0)

1. Start the signaling server on one machine.
2. Launch two game instances with webrtc-native installed.
3. Host with `webrtc` transport (debug UI join-code flow lands in Phase 1).
4. Join with the assigned room code.
5. Confirm `MatchSession` echo RPC succeeds between instances.

STUN-only (`stun:stun.l.google.com:19302`) is enough for many LAN/home networks. Production play requires TURN relay configuration (Phase 2).

## Related documents

- [WebRTC transport investigation](../research/webrtc-transport-investigation.md)
- [Networking architecture](../architecture/networking.md)
- [Runtime debug harnesses](runtime-debug-harnesses.md) — ENet LAN path remains available
