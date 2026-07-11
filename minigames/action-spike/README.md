# Action Spike

Milestone 10 graybox combat arena (`HOST_ACTION`). Validates the shared action-netcode kit and `NetworkActionMinigameSession` before milestone 12 freezes the networking API.

Related: [Godot 3D movement standards](../../docs/architecture/godot-3d-movement.md), [networking implementation plan](../../docs/plans/networking.md#milestone-10-3d-combat-spike-host_action-and-action-netcode-kit).

## Controls

Tank controls: turn left/right, throttle forward/back along facing (not strafe).

| Device slot | Turn | Move | Jump | Fire |
| --- | --- | --- | --- | --- |
| 0 | Arrow left/right | Arrow up/down | Enter / ui_accept | Left click |
| 1 | A / D | W / S | Space | F |
| 2 | J / L | I / K | U | O |
| 3 | Numpad 4 / 6 | Numpad 8 / 2 | Numpad Enter | Numpad 0 |

Eliminate rivals with hitscan fire (50 damage, 0.4s cooldown). Last bean standing wins; ties group by eliminations then remaining health.

## Networking

- Sync profile: `HOST_ACTION`
- Session: `NetworkActionMinigameSession`
- 30 Hz host simulation, 20 Hz snapshots
- Required client movement prediction with ticked input, host hold-last consumption, processed-tick acks, and replay reconciliation

## Spike scope (M10)

**In this spike:** tank movement, jump, hitscan combat, health HUD, third-person chase camera, inactive-player exclusion from last-standing logic.

**Deferred:** lag compensation, projectiles, physics props, knockback, respawn, `CharacterBody3D` collision, render interpolation, `SpringArm3D` camera, and full movement-standard manual matrix. See spike deviations in the networking plan.
