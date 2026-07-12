# WebRTC signaling server

This signaling server is Bean Party software licensed under MIT; see the repository [license overview](../../LICENSE.md).

Local development signaling for Bean Party WebRTC transport. This server relays lobby join messages and WebRTC SDP/ICE payloads between peers. It does not run game logic.

Protocol matches Godot's [webrtc_signaling demo](https://github.com/godotengine/godot-demo-projects/tree/master/networking/webrtc_signaling).

## Run locally

```bash
cd tools/signaling
npm install
npm start
```

Default URL: `ws://127.0.0.1:9080` (override with `PORT`).

Dev limits: 4 peers per lobby (`MAX_PEERS_PER_LOBBY`), 64 KiB max signaling payload.

## Client configuration

Use `MatchSession.host_with_transport("webrtc", {"signaling_url": "ws://127.0.0.1:9080"})` to host, or pass `room_code` when joining.

See [WebRTC setup](../../docs/guides/webrtc-setup.md) for the webrtc-native GDExtension and manual spike steps.
