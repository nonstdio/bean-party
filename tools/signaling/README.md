# WebRTC signaling server

Local development signaling for Bean Party WebRTC transport. This server relays lobby join messages and WebRTC SDP/ICE payloads between peers. It does not run game logic.

Protocol matches Godot's [webrtc_signaling demo](https://github.com/godotengine/godot-demo-projects/tree/master/networking/webrtc_signaling).

## Run locally

```bash
cd tools/signaling
npm install
npm start
```

Default URL: `ws://127.0.0.1:9080` (override with `PORT`).

## Client configuration

Use `MatchSession.host_with_transport("webrtc", {"signaling_url": "ws://127.0.0.1:9080"})` to host, or pass `room_code` when joining.

See [WebRTC setup](../../docs/guides/webrtc-setup.md) for the webrtc-native GDExtension and manual spike steps.
