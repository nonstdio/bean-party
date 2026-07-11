# Runtime debug harnesses

Bean Party's current scenes are architecture and contributor proofs, not a playable game loop. This guide explains what can be exercised today and where each proof stops. Follow the [Godot setup guide](godot-setup.md) first and read the [Godot project architecture](../architecture/godot-project.md) for ownership boundaries.

## Main debug shell

Run the main scene with `F5`. The shell contains independent local and network sections in one scrollable view.

### Local couch session and phase flow

The local section starts with two `PlayerSlot`s. It can:

- add or remove local players up to the four-player cap;
- edit display names, ready flags, colors, and session-local controller-slot assignments;
- walk the guarded phase sequence from `Lobby` through the board and placeholder minigame phases;
- advance the board stub's active turn; and
- capture and restore the most recent board-boundary JSON snapshot while keeping controller assignments local.

`Advance phase` always takes the first valid happy-path transition. The selected minigame id, winner, and three-bean reward are stub data chosen by the local controller; no minigame scene is loaded. The local phase flow and the local minigame contract are not integrated yet.

### ENet session, lobby, board, and placeholder phase flow

To exercise the network slice on one machine:

1. Run two editor or game instances from the same checkout.
2. In the first instance, keep port `7777` or choose another free port and select `Host`.
3. In the second instance, use `127.0.0.1`, the same port, and select `Join`.
4. Optionally use `Echo test` to verify a reliable round trip to the first remote peer.
5. Add local players on either peer, edit their names, and toggle lobby readiness. The four-player cap applies across all peers. Controller-slot selection remains local and is not replicated.
6. On the host, select `Start board`. Only the peer that owns the active `PlayerSlot` can request `Advance turn`.
7. On the host, select `Start minigame flow`. Each local slot must separately mark briefing readiness. The host drives the three-second countdown.
8. During `ActiveMinigame`, the shell loads `minigames/_network_stub/network_stub_minigame.tscn`. The host selects `End round`, then `Return to board`; one randomly selected slot receives three beans once.
9. Select `Disconnect` in each instance when finished.

All lobby, board, and phase synchronization in this slice uses reliable RPCs. The host validates slot ownership, board-turn ownership, and briefing readiness. The board roster is frozen when the host starts the board, so later lobby edits do not alter the active board match.

### Current network limitations

- This is direct-IP ENet only. It has no discovery, join codes, NAT traversal, matchmaking, or Steam transport.
- The network placeholder is not a `MinigameManifest`, does not extend `MinigameController`, and does not use `MinigameRunner`. It exists only to prove synchronized scene loading and unloading.
- There is no real networked minigame simulation, input stream, snapshot interpolation, prediction, or network minigame API.
- The debug UI has no match-start readiness gate; lobby ready flags are synchronized but do not block `Start board`.
- Disconnect recovery and reconnect are not implemented. A client losing the host returns its `MatchSession` to idle; a non-host disconnect removes that peer's lobby slots, but an already frozen board/phase roster is not reconciled. A disconnect during briefing can therefore leave readiness waiting on a departed slot.
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
