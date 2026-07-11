# Godot 3D movement standards

Status: **Active**

This document defines the shared engineering standard for player-controlled 3D movement in Bean Party. It applies to local minigames and networked `HOST_SNAPSHOT` / `HOST_ACTION` minigames. A spike may temporarily deviate to answer a focused question, but the deviation and its validation limits must be documented in the pull request.

Related documents:

- [Godot project architecture](godot-project.md)
- [Minigame integration contract](minigame-integration.md)
- [Networking architecture](networking.md)
- [Networking implementation plan](../plans/networking.md)

## Goals

Movement should be:

- responsive to the local player;
- stable across 30, 60, 120, and 144 FPS rendering;
- consistent under the configured fixed simulation rate;
- collision-aware and visually honest about floors, walls, slopes, and cover;
- smooth for local predicted players and remote interpolated players; and
- measurable through repeatable tests rather than judged only on the developer's machine.

## Required architecture

### Separate simulation from presentation

Maintain distinct simulation and render states.

- **Simulation state** is authoritative or predicted gameplay state: position, orientation, linear/angular velocity, grounded state, and other movement state required for replay.
- **Render state** is the interpolated or smoothed pose shown by meshes and followed by the camera.
- Gameplay decisions, hit tests, scoring, and snapshots use simulation state. They must not use a cosmetically smoothed render transform.
- Presentation code must not feed its smoothed transform back into simulation.

Fixed-tick movement stores at least the previous and current simulation poses. Rendering interpolates between them. Do not copy a 20–30 Hz simulation transform directly to a mesh every rendered frame.

For local non-networked physics, prefer Godot's built-in physics interpolation. For custom or networked interpolation, use an explicit render-state buffer and `Engine.get_physics_interpolation_fraction()` where local simulation ticks align with Godot physics ticks.

### Use the physics process for collidable movement

Player collision bodies use `CharacterBody3D` unless a reviewed minigame-specific requirement justifies another body type.

- Read or queue input before the physics step.
- Update velocity, grounded state, jump state, and movement in `_physics_process()`.
- Call `move_and_slide()` from the physics step.
- Use `is_on_floor()`, `is_on_wall()`, and slide-collision data instead of inferring ground contact from a hard-coded Y coordinate.
- Floors, walls, pillars, and visible cover that should block movement or shots require matching `StaticBody3D` / `CollisionShape3D` geometry.
- Do not move a collidable character by assigning `position` or `global_position` each rendered frame.

The host is the only authority for networked collision outcomes. Clients may run the same movement motor for prediction, but authoritative snapshots correct any disagreement.

### Fixed simulation rate

Network-capable real-time minigames use a fixed simulation rate selected and documented by the minigame.

- Start evaluation at 30 or 60 ticks per second.
- Do not tie simulation ticks to render FPS.
- Cap catch-up work per frame and report dropped/excess simulation time; an unbounded accumulator loop can create a spiral of death after a stall.
- Include a monotonic simulation tick in input frames and snapshots.
- Snapshot state must include every quantity needed to continue the motor correctly, including velocity, yaw/angular velocity, vertical velocity, grounded state when it cannot be derived safely, and the last processed input tick.

## Input pipeline

Continuous values and one-shot actions have different delivery needs.

- Sample one normalized input frame per simulation tick.
- Assign the tick before sending the frame.
- Send or batch the newly sampled frame, not a render-frame control state labeled with the previous simulation tick.
- Retain a bounded history and include a short redundant tail for unreliable delivery.
- The host buffers frames per player, rejects stale/duplicate ticks, and consumes each accepted tick at most once.
- A snapshot acknowledges the last input tick **processed by authoritative simulation**, not merely the latest packet received.
- Preserve one-shot edges such as jump, dodge, interact, and fire. They must not be lost when render FPS exceeds simulation FPS or duplicated when a render frame produces multiple simulation ticks.

Add automated coverage for lost, duplicated, delayed, and reordered inputs, including press/release edges.

## Movement motor and feel

A movement motor exposes tunable data rather than scattering constants through view code.

At minimum, define:

- maximum ground speed and optional air-control speed;
- acceleration and deceleration;
- turn/angular acceleration and maximum turn speed;
- gravity, terminal velocity, and jump impulse;
- floor angle, step, and slope behavior; and
- optional jump buffer and coyote-time windows.

Guidelines:

- Approach target velocity over time; do not switch instantly between zero and maximum speed unless the minigame intentionally calls for digital, arcade movement.
- Keep visual smoothing separate from acceleration. Smoothing a camera cannot repair an unstable movement motor.
- Make jump input edge-triggered. A held jump must not retrigger every tick after landing unless auto-jump is an explicit mechanic.
- Consider a small jump buffer and coyote-time allowance for forgiving action movement.
- Normalize diagonal input and clamp untrusted client values at the authority.
- Put tuning values in a resource or a clearly owned motor configuration so a minigame can tune feel without forking transport/reconciliation code.

## Rendering and interpolation

### Local offline or authoritative player

When simulation uses Godot physics ticks:

- enable physics interpolation in project settings for eligible nodes;
- update transforms only in physics ticks; and
- call `reset_physics_interpolation()` after teleports, respawns, or authoritative warps.

To diagnose mistakes, temporarily lower physics ticks per second to 10. Visible stepping, double movement, or transform warnings usually indicate that a transform is being written outside the intended tick.

### Local predicted network player

Prediction maintains an unsmoothed predicted simulation state and a separate visual correction.

1. Apply the authoritative snapshot for its acknowledged input tick.
2. Reset all movement state represented by the snapshot, including position, yaw, and velocities.
3. Replay retained inputs newer than the acknowledged tick exactly once.
4. Compare the pre-reconcile prediction with the post-replay prediction.
5. Smooth only the visual correction offset toward zero.

Do not blend the predicted simulation state toward an old authoritative position after replay. That reintroduces latency and contaminates the next prediction step.

Large corrections, teleports, respawns, or invalid history reset immediately and clear interpolation history. Small corrections may decay over a short, tunable window.

### Remote network players

Remote entities use buffered snapshot interpolation.

- Snapshots include a host tick or authoritative timestamp.
- Keep a bounded, ordered buffer.
- Render behind authority by a small interpolation delay, normally enough for 2–3 snapshots.
- Interpolate position and velocity-aware motion between bracketing snapshots; use `lerp_angle()` or quaternion interpolation for orientation.
- Do not chase the newest packet with `current.lerp(latest, delta * rate)` as the primary remote strategy. That produces frame-rate- and packet-arrival-dependent motion.
- Allow short, bounded extrapolation only when measurement shows it is needed; clamp and correct it when snapshots resume.

## Camera standard

The camera follows the interpolated render pose, never the raw low-frequency simulation pose.

- Use a pivot/yaw rig and `SpringArm3D` for third-person cameras so walls and cover move the camera inward instead of clipping.
- Exclude the local player collision body from the spring arm collision mask.
- Smooth focus, yaw, shoulder offset, and distance with frame-rate-independent damping, for example `1.0 - exp(-sharpness * delta)`.
- Keep camera smoothing parameters separate from movement reconciliation parameters.
- Teleports and respawns reset camera history so the camera does not sweep across the arena.
- Avoid independently smoothing several parent/child transforms that represent the same motion; stacked smoothing adds lag and can oscillate.

## Networking authority rules

For `HOST_ACTION` movement:

- the host validates ownership, participation, input ranges, tick order, action cooldowns, and movement constraints;
- the host consumes buffered input frames on its fixed tick;
- clients predict only their locally controlled player;
- remote players interpolate authoritative snapshots;
- damage, deaths, pickups, scoring, spawn/despawn, and results remain authoritative;
- client-provided aim or camera values are clamped and validated against the authoritative player state; and
- disconnected/inactive players stop producing movement immediately and are excluded from active winner logic according to the minigame rules.

Godot physics is not assumed deterministic across peers. Prediction is an approximation corrected by the host, not a second authority.

## Scene and ownership pattern

A typical player representation separates nodes by responsibility:

```text
CharacterBody3D                 # simulation/collision owner
  CollisionShape3D
  VisualRoot                    # render pose/animation only
    MeshInstance3D
  CameraPivot                   # local player only
    SpringArm3D
      Camera3D
```

Network sessions own input transport, tick buffers, snapshots, and reconciliation. Minigame code owns movement rules, tuning, animation, arena geometry, and player-facing feedback. A minigame must not create its own `MultiplayerPeer`.

## Anti-patterns

Do not:

- update collidable player transforms from `_process()`;
- render a fixed-tick state without interpolation;
- acknowledge inputs when received instead of when simulated;
- keep only the latest input dictionary while claiming tick-accurate replay;
- reset position during reconciliation but leave yaw or velocity predicted;
- use camera smoothing to hide simulation stepping;
- make visible cover non-collidable without clearly labeling it cosmetic;
- let remote interpolation modify authoritative gameplay state; or
- introduce a second movement/prediction implementation when a shared motor or netcode component satisfies the need.

## Validation requirements

Every substantial 3D movement change records:

### Automated tests

- fixed-tick behavior independent of render-frame chunking;
- input order, duplicate rejection, redundant history, and processed-tick acknowledgements;
- jump press/release preservation;
- movement/collision constraints and slope/floor behavior;
- prediction reset and replay for position, yaw, and velocities;
- remote interpolation buffer ordering;
- teleport/respawn interpolation reset; and
- inactive/disconnected player behavior.

### Manual matrix

| Scenario | Required observation |
| --- | --- |
| Render 30 / 60 / 120 / 144 FPS | Comparable speed; no stepping or camera vibration |
| Simulation 30 and 60 Hz | Documented feel and correction-rate comparison |
| Latency 0 / 50 / 100 / 150 ms | Local response, remote smoothness, correction count/magnitude |
| Jitter + 1–2% loss | No persistent divergence or lost action edges |
| Delayed/reordered/duplicated inputs | No double actions or stale movement takeover |
| Corners, slopes, steps, cover | Stable sliding and no visible geometry pass-through |
| Jump, land, teleport, respawn | No vertical pop, interpolation trail, or camera sweep |
| Two consecutive rounds | Buffers, camera state, and interpolation reset cleanly |
| 4 peers × 1 player | Launch topology; identical winner/result state |

Movement feel remains a human acceptance gate. After automated and impairment checks pass, stop at a playable checkpoint for feedback on acceleration, turning, jump timing, camera weight, aiming, and correction visibility.

## Pull request checklist

A movement PR should answer:

- What owns canonical simulation?
- What runs in physics ticks, network ticks, and rendered frames?
- Which state is predicted, interpolated, or cosmetic?
- Which input tick does each snapshot acknowledge?
- How are one-shot actions preserved?
- How are position, yaw, and velocities reconciled?
- What collides with players, shots, and the camera?
- What resets on teleport, respawn, disconnect, retry, and consecutive runs?
- Which automated and manual matrix rows were completed?
- Where should a human evaluate movement feel?

## Official Godot references

- [Using physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html)
- [Physics interpolation introduction](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)
- [Advanced physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html)
- [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
- [Moving the player with code](https://docs.godotengine.org/en/stable/getting_started/first_3d_game/03.player_movement_code.html)
- [SpringArm3D](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html)
- [Third-person camera with spring arm](https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html)
