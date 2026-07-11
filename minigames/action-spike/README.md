# Action Spike

Milestone 10 graybox combat arena (`HOST_ACTION`). This spike validates the shared action-netcode kit and `NetworkActionMinigameSession` integration before hitscan, projectiles, and full combat rules land in follow-up slices.

## Controls

| Device slot | Turn | Move | Jump | Fire |
| --- | --- | --- | --- | --- |
| 0 | Arrow left/right | Arrow up/down | Enter / ui_accept | Left click |
| 1 | A / D | W / S | Space | F |
| 2 | J / L | I / K | U | O |
| 3 | Numpad 4 / 6 | Numpad 8 / 2 | Numpad Enter | Numpad 0 |

Eliminate rivals with hitscan fire. Last bean standing wins; ties break on eliminations then remaining health.

## Networking

- Sync profile: `HOST_ACTION`
- Session: `NetworkActionMinigameSession`
- Required client movement prediction with host reconciliation
