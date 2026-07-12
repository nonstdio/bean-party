# Snapshot Arena

Graybox movement minigame for Milestone 7 (`HOST_SNAPSHOT`). First player to reach the center goal wins; everyone else is ranked by distance to the goal.

## Design brief

- **Players:** 2–4, free-for-all.
- **Objective:** reach the green center circle before other players.
- **Placement:** first to the goal wins; remaining players ordered by final distance to goal center.
- **Timing:** shell-owned briefing and countdown; open-ended active play until a winner.
- **Controls:** shell maps device slots to keyboard — Controller 1 = arrow keys, Controller 2 = WASD, Controller 3 = IJKL, Controller 4 = numpad/arrows (see `MinigameLocalDeviceInput`).
- **Accessibility:** the goal is a filled circle; each player uses a distinct circle, triangle, square, or diamond marker in addition to slot color.
- **Capability:** `network_capable`, sync profile `HOST_SNAPSHOT`.

## Integration notes

The scene root extends `MinigameController`. Online play is driven by `NetworkMinigameSession`, which polls local device input, runs host simulation, broadcasts position snapshots at 20 Hz, and interpolates on clients. The minigame reads display positions from that session during networked rounds and integrates movement locally only for harness/offline contract tests.

## Assets and provenance

The minigame reuses Bean Party's original [prototype theme and player identity markers](../../assets/standard/catalog.md). It uses no external assets.

## Validation

- Manifest contract test under `tests/`.
- Shell tests: `test_host_snapshot_simulator.gd`, `test_network_minigame_session.gd`.
- Manual: 2-peer session; snap serial and hash stay aligned; host declares winner; results and board reward agree.
