# Godot project architecture

Status: **Active pre-production foundation**

## Foundation

Bean Party uses **Godot 4.7 stable**, **GDScript**, and the **Compatibility renderer**. This is a runnable architecture and contributor-test foundation, not a playable game or the final game architecture. It exists so contributors can exercise the implemented local session, local minigame contract, and ENet debug slice while the team evolves the board, network minigame API, art kit, and release targets through reviewed decisions.

Godot stores the main scene in `project.godot`; `res://` refers to this repository root. The initial entry point is `res://scenes/app/main.tscn`.

## Repository layout

```text
assets/                 # Standard runtime assets, ignored-from-Godot sources, and provenance
addons/                 # Reviewed, vendored Godot editor/runtime add-ons
docs/                   # Design, architecture, and decision records
minigames/              # One self-contained folder per contributed minigame
scenes/
  app/                  # Game entry scene and future app-level flow
  dev/                  # Contributor-only harness scenes, not shipped game flow
  shared/               # Shared scenes only after a reviewed need exists
scripts/
  app/                  # Controllers for app-level scenes
  dev/                  # Controllers for contributor-only harnesses
  shared/               # Shared GDScript only after a reviewed need exists
tests/                  # Project-level GUT tests; minigames may keep local tests
tools/                  # Platform runners for agent setup, validation, and tests
project.godot           # Godot project configuration and main-scene setting
```

The foundation does not create a production board manager or global singleton. The main scene owns app-level debug views and a `MatchSession` node with lobby, board, and network phase children. Separately, the local debug phase controller is `RefCounted`, and the minigame development harness owns a `MinigameRunner`. These are deliberately separate proofs; there is no app-level coordinator joining them into one match yet.

The shared ENet debug **session layer** is implemented in `scripts/shared/` as `MatchSession`, `TransportAdapter`, and `EnetTransportAdapter`, behind the boundary described in [networking architecture](networking.md). It is app-owned, not an autoload: the `MatchSession` node exists with the main scene, creates a peer only when hosting or joining, and explicitly clears the peer on disconnect, connection failure, server loss, or tree exit. `SteamTransportAdapter` is a fail-closed stub pending legal review and a live channel-parity spike.

## Implemented runtime surfaces

| Surface | Current implementation | Boundary |
| --- | --- | --- |
| Main app | `scenes/app/main.tscn` and `scripts/app/` | Scrollable debug shell, not a menu or production game flow |
| Offline session | `OfflineMatchSession`, `PlayerSlot`, and `couch_session_view.gd` | 2–4 local slots; physical device mapping is represented by session-local indices only |
| Offline phase proof | `LocalMatchPhaseController`, `MatchSnapshot`, serializer, and board stub | Walks placeholder phases and JSON snapshot restore; does not load a real minigame |
| Local minigame contract | `scripts/shared/minigames/`, `scenes/dev/minigame_harness.tscn`, and `reference-tap` | Accepted contract v1; harness-only integration today |
| ENet connection proof | `MatchSession` and `EnetTransportAdapter` | Direct address and port, one listen-server host, reliable echo, explicit teardown |
| Network shell proof | `NetworkLobbySession`, `NetworkBoardSession`, and `NetworkMatchPhaseSession` plus their authority objects | Reliable host-authoritative debug state through a placeholder scene; not production netcode |
| Standard asset gallery | `scenes/dev/standard_asset_gallery.tscn` and `assets/standard/` | Canonical prototype character, identity, material, and shell-token comparisons; contributor tooling rather than production art or shipped app flow |

Follow [Runtime debug harnesses](../guides/runtime-debug-harnesses.md) for the runtime proofs and [Use and contribute standard assets](../guides/standard-assets.md#inspect-the-kit) for gallery controls and visual checks.

## Conventions

- Use `.tscn` for editable scenes and `.gd` for GDScript. Keep files readable in Git and use one clear owner for each scene.
- Pair a scene with a nearby script when the script is specific to that scene, for example `scenes/app/main.tscn` and `scripts/app/main.gd`.
- Use `res://` paths in project resources. Do not use machine-specific absolute paths.
- Minigame-local scenes, scripts, and assets stay within `minigames/<slug>/`; only promote something to `scenes/shared/` or `scripts/shared/` when two or more minigames genuinely need it.
- Player-controlled 3D movement follows the [Godot 3D movement standards](godot-3d-movement.md), including simulation/render separation, physics ownership, interpolation, camera, networking, and validation requirements.
- Commit original assets and their source files when practical. Do not commit generated Godot folders, exports, or builds.
- Follow the [standard asset guide](../guides/standard-assets.md) for the canonical catalog, mixed Blender/GLB handoff, lifecycle states, and contributor gallery.
- Keep `.uid` sidecar files untracked under the current ignore policy; Godot may regenerate them locally.
- Use tabs for GDScript indentation and LF line endings. The repository’s `.editorconfig` and `.gitattributes` state this explicitly.

## Running and validating

Follow [Godot setup for agents](../guides/godot-setup.md) for the pinned engine and terminal-first workflow. Run `powershell -ExecutionPolicy Bypass -File .\tools\godot.ps1 all` on Windows or `bash tools/godot.sh all` on macOS and Linux; `all` imports the project headlessly and then runs the GUT suite. Use `validate` or `test` in place of `all` when only one action is needed.

Install Godot 4.7 stable, then either import `project.godot` through the Project Manager or run:

```text
godot --editor --path .
```

Run the project with `F5`. For a lightweight command-line validation on a machine with Godot installed:

```text
godot --headless --path . --editor --quit
```

Godot’s [nodes and scenes guide](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/nodes_and_scenes.html) explains the main-scene and `project.godot` relationship used by this foundation.
