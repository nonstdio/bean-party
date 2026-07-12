# Runtime debug harnesses

Bean Party's current scenes are architecture and contributor proofs, not a playable game loop. This guide explains what can be exercised today and where each proof stops. Follow the [Godot setup guide](godot-setup.md) first and read the [Godot project architecture](../architecture/godot-project.md) for ownership boundaries.

## Main debug shell

Run the main scene with `F5`. The shell is a scrollable network debug view for host/join sessions over **ENet (LAN)** or **WebRTC (internet room code)**.

Offline couch sessions and the local phase-flow debug UI are not on the main scene. Use `res://scenes/dev/minigame_harness.tscn` for local minigame contract work, and the unit tests for `OfflineMatchSession` / `LocalMatchPhaseController` proofs.

### ENet session (LAN)

To exercise the network slice on one machine:

1. Run two editor or game instances from the same checkout.
2. Select transport **ENet (LAN)**.
3. In the first instance, keep port `7777` or choose another free port and select `Host`.
4. In the second instance, use `127.0.0.1`, the same port, and select `Join`.
5. Optionally use `Echo test` to verify a reliable round trip to the first remote peer.

### WebRTC session (internet / NAT)

WebRTC requires the [webrtc-native GDExtension](webrtc-setup.md) on every desktop peer and a running signaling server (`tools/signaling/`) for contributor spikes. Windows playtesters should use the packaged [BeanParty-Windows.zip](../../README.md#download-the-latest-windows-test-build) instead of installing the extension manually.

1. Start signaling: `cd tools/signaling && npm install && npm start` (default `ws://127.0.0.1:9080`).
2. Run two game instances with webrtc-native available (editor checkout or extracted Windows test build).
3. Select transport **WebRTC (internet)**.
4. Host: leave room code empty and select `Host`. Copy the displayed room code.
5. Join: enter the signaling URL and room code, then select `Join`.
6. Use `Echo test` once connected.

STUN-only connectivity works on many networks; restrictive NATs need TURN. Configure ICE servers via [WebRTC setup](webrtc-setup.md) and [WebRTC operations runbook](webrtc-ops.md).

### Shared lobby → board → minigame flow

After connecting with either transport:
1. Each peer automatically joins the lobby with one local player when connected. Only one player per screen is supported online; the four-player cap applies across peers, not within one peer.
2. Edit display names and toggle lobby readiness per player.
3. On the host, select `Start board`. Only the peer that owns the active `PlayerSlot` can request `Advance turn`.
4. On the host, select `Start minigame flow`. Each peer marks briefing readiness for its player. The host drives the three-second countdown.
5. During `ActiveMinigame`, the shell loads **Action Spike** (`HOST_ACTION`) through `NetworkActionMinigameSession`. Required client movement prediction and host reconciliation apply; the status line shows snapshot serial/hash and prediction correction stats. Snapshot Arena (`HOST_SNAPSHOT`) remains available when wired separately.
6. Select `Disconnect` in each instance when finished.

All lobby, board, and phase synchronization in this slice uses reliable RPCs. The host validates slot ownership, board-turn ownership, and briefing readiness. The board roster is frozen when the host starts the board, so later lobby edits do not alter the active board match.

### Current network limitations

- ENet remains direct-IP LAN only (no NAT traversal). WebRTC adds signaling + STUN hole-punch; TURN relay is operator-configured via `WebRtcIceConfig` (see [webrtc-ops.md](webrtc-ops.md)).
- Shell and minigame RPCs use `TransportMessageLanes` transfer channels (session on 0, inputs on 1, snapshots on 2).
- The network placeholder minigame scene is no longer used during `ActiveMinigame`. The debug shell now loads **Action Spike** (`HOST_ACTION`) through `NetworkActionMinigameSession`; Snapshot Arena (`HOST_SNAPSHOT`) remains available via manifest selection when wired.
- Action Spike uses the milestone 10 action-netcode kit foundation: 30 Hz fixed-tick host sim, required client movement prediction + reconciliation, 20 Hz snapshots, and jump input on device-slot accept/space/u/numpad-enter keys.
- Snapshot Arena runs through `NetworkMinigameSession` with host snapshots, client interpolation, and optional local movement prediction (milestone 8 experiment). Latency impairment testing is manual.
- The debug UI has no match-start readiness gate; lobby ready flags are synchronized but do not block `Start board`.
- Disconnect recovery is partially implemented (milestone 9). Host departure emits a `session_ended` signal and shows **Host left the match.** Non-host disconnect during an active board marks the frozen roster slot `inactive` instead of removing it; briefing no longer waits on departed players. Reconnect at the **board phase boundary** can reclaim the prior `player_id` when the client rejoins with matching `match_epoch`, recovery session id, transport target (ENet address/port or WebRTC signaling URL + room code), and a per-slot reconnect token issued at board start. Pending reclaim state survives only a graceful in-process **Disconnect → Join** in the debug shell; it does not survive client crash/restart or link loss classified as host loss. Mid-minigame reconnect and host-loss recovery remain unsupported. Disconnect during an active minigame clears the departed player's input and excludes them from winner/result handling for that round.
- Rejoining while a minigame is already in progress is unsupported: the host keeps the frozen match roster, so a new connection gets a lobby slot but is treated as a **late joiner** until the host returns to board. The client shows the current phase label but does not load the active minigame scene or accept inputs for that round.
- Network phase state is synchronized live but does not use the offline `MatchSnapshot` serializer. No network phase-boundary recovery snapshot is retained.
- Manual multi-instance, LAN, internet, impairment, and human-playtest evidence is not stored as a durable repository artifact. Do not infer completion of a plan milestone's manual stop conditions from the presence of code or unit tests.

See the [networking implementation plan](../plans/networking.md#milestone-overview) for the status of each milestone and the [networking architecture](../architecture/networking.md) for accepted, proposed, and deferred boundaries.

## Local minigame development harness

Open `res://scenes/dev/minigame_harness.tscn` and run the current scene with `F6`. By default it loads `reference-tap` with two deterministic local players and RNG seed `12345`.

The harness proves registry-compatible manifest loading, context setup, shell-owned normalized input, result validation, abort, retry, and unload behavior. Change the scene's exported `manifest_path`, `player_count`, or `rng_seed` to exercise another local minigame. Its buttons inject the normalized `primary` action; they do not prove physical keyboard or controller routing.

The harness is the executable path for local minigame contract version 1 today. It is separate from both phase flows in the main debug shell.

## Automated validation

Run the full import and GUT suite after using a harness:

```powershell
.\tools\godot.ps1 all
```

```bash
bash tools/godot.sh all
```

The tests cover the local session and snapshot model, ENet session lifecycle helpers, host-authoritative lobby/board/phase logic, local minigame contract and reference behavior, project boundaries, main-scene instantiation, and relative Markdown links. They do not replace the manual multi-process and human-playtest checks listed in the networking plan.
