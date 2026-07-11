# Runtime debug harnesses

Bean Party's current scenes are architecture and contributor proofs, not a playable game loop. This guide explains what can be exercised today and where each proof stops. Follow the [Godot setup guide](godot-setup.md) first and read the [Godot project architecture](../architecture/godot-project.md) for ownership boundaries.

## Main debug shell

Run the main scene with `F5`. The shell is a scrollable network debug view for host/join ENet sessions.

Offline couch sessions and the local phase-flow debug UI are not on the main scene. Use `res://scenes/dev/minigame_harness.tscn` for local minigame contract work, and the unit tests for `OfflineMatchSession` / `LocalMatchPhaseController` proofs.

### ENet session, lobby, board, and minigame flow

To exercise the network slice on one machine:

1. Run two editor or game instances from the same checkout.
2. In the first instance, keep port `7777` or choose another free port and select `Host`.
3. In the second instance, use `127.0.0.1`, the same port, and select `Join`.
4. Optionally use `Echo test` to verify a reliable round trip to the first remote peer.
5. Each peer automatically joins the lobby with one local player when connected. Only one player per screen is supported online; the four-player cap applies across peers, not within one peer.
6. Edit display names and toggle lobby readiness per player.
7. On the host, select `Start board`. Only the peer that owns the active `PlayerSlot` can request `Advance turn`.
8. On the host, select `Start minigame flow`. Each peer marks briefing readiness for its player. The host drives the three-second countdown.
9. During `ActiveMinigame`, the shell loads Snapshot Arena with host snapshots and optional client-side movement prediction. The client status line shows snapshot serial/hash and prediction correction stats.
10. Select `Disconnect` in each instance when finished.

All lobby, board, and phase synchronization in this slice uses reliable RPCs. The host validates slot ownership, board-turn ownership, and briefing readiness. The board roster is frozen when the host starts the board, so later lobby edits do not alter the active board match.

### Current network limitations

- This is direct-IP ENet only. It has no discovery, join codes, NAT traversal, matchmaking, or Steam transport.
- The network placeholder minigame scene is no longer used during `ActiveMinigame`; Snapshot Arena is loaded instead.
- Snapshot Arena runs through `NetworkMinigameSession` with host snapshots, client interpolation, and optional local movement prediction (milestone 8 experiment). Latency impairment testing is manual.
- The debug UI has no match-start readiness gate; lobby ready flags are synchronized but do not block `Start board`.
- Disconnect recovery and reconnect are not implemented. A client losing the host returns its `MatchSession` to idle; a non-host disconnect removes that peer's lobby slots, but an already frozen board/phase roster is not reconciled. A disconnect during briefing can therefore leave readiness waiting on a departed slot.
- Rejoining while a minigame is already in progress is unsupported: the host keeps the frozen match roster, so a new connection gets a lobby slot but is treated as a **late joiner** until the host returns to board. The client shows the current phase label but does not load Snapshot Arena or accept inputs for that round.
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
