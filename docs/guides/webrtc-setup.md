# WebRTC setup

Bean Party's internet transport uses Godot's `WebRTCMultiplayerPeer` with a small WebSocket signaling server and ICE (STUN/TURN) for NAT traversal.

## Prerequisites

- Godot 4.7 stable ([godot-setup.md](godot-setup.md))
- Node.js 18+ for the local signaling server (`tools/signaling/`) — contributors only
- webrtc-native GDExtension on every desktop peer that uses WebRTC transport

Windows playtesters receive webrtc-native automatically in the [BeanParty-Windows.zip](https://github.com/nonstdio/bean-party/releases/download/latest-windows/BeanParty-Windows.zip) rolling build. Ordinary players do not install Godot, Node.js, or the extension manually.

## Install webrtc-native for contributors

The pinned release is recorded in [config/webrtc_native.version.json](../../config/webrtc_native.version.json). CI downloads that exact archive, verifies its SHA-256 checksum, and installs it before export.

From the repository root on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup-webrtc-native.ps1
powershell -ExecutionPolicy Bypass -File .\tools\godot.ps1 validate
```

The script extracts `addons/webrtc_native/` into the **repository root** (`bean-party/`, not the parent `beansinc/` folder). If WebRTC errors mention `No default WebRTC extension configured`, re-run the script from the repo root and restart the editor.

On macOS or Linux, run `tools/install-webrtc-native.ps1` with PowerShell 7+ or download the pinned archive named in `config/webrtc_native.version.json` and extract it to the repository root.

The extension is MIT-licensed. Do not commit generated `.godot/` import output.

## Windows export packaging

Godot embeds the game PCK inside `BeanParty.exe`, but webrtc-native remains a GDExtension with native libraries that must ship beside the executable. The Windows CI workflow exports:

- `BeanParty.exe`
- `addons/webrtc_native/webrtc_native.gdextension`
- `addons/webrtc_native/lib/libwebrtc_native.windows.template_release.x86_64.dll`

and packages them into `BeanParty-Windows.zip`. The standalone `BeanParty.exe` asset is not WebRTC-capable without those companion files.

Exported builds support a headless smoke probe:

```powershell
.\BeanParty.exe --headless --webrtc-export-smoke
```

The Windows workflow runs `tools/smoke-webrtc-export.ps1` against the exported directory before publishing the ZIP.

## Run signaling for local spikes

```bash
cd tools/signaling
npm install
npm start
```

Default signaling URL: `ws://127.0.0.1:9080` (`MatchConstants.DEFAULT_WEBRTC_SIGNALING_URL`).

This Node.js server is for contributor architecture spikes only. Production signaling and TURN relay deployment are tracked separately in [WebRTC operations runbook](webrtc-ops.md).

## Host or join (debug shell)

1. Start the signaling server.
2. Launch Godot with webrtc-native installed, or run the extracted Windows test build ZIP.
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

Implementation details (channels, RPC timing, signaling quirks): [WebRTC implementation notes](webrtc-implementation-notes.md).

## Related documents

- [WebRTC operations runbook](webrtc-ops.md)
- [WebRTC implementation notes](webrtc-implementation-notes.md)
- [WebRTC transport investigation](../research/webrtc-transport-investigation.md)
- [Networking architecture](../architecture/networking.md)
- [Runtime debug harnesses](runtime-debug-harnesses.md) — ENet LAN path remains available
