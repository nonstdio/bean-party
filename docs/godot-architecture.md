# Godot project architecture

## Foundation

Bean Party uses **Godot 4.7 stable**, **GDScript**, and the **Compatibility renderer**. This is a small, runnable foundation, not the final game architecture. It exists so contributors can open the project immediately while the team evolves the board, minigame API, art kit, and release targets through reviewed decisions.

Godot stores the main scene in `project.godot`; `res://` refers to this repository root. The initial entry point is `res://scenes/app/main.tscn`.

## Repository layout

```text
assets/                 # Original source art, audio, fonts, and third-party license notes
addons/                 # Reviewed, vendored Godot editor/runtime add-ons
docs/                   # Design, architecture, and decision records
minigames/              # One self-contained folder per contributed minigame
scenes/
  app/                  # Game entry scene and future app-level flow
  shared/               # Shared scenes only after a reviewed need exists
scripts/
  app/                  # Controllers for app-level scenes
  shared/               # Shared GDScript only after a reviewed need exists
tests/                  # Project-level GUT tests; minigames may keep local tests
tools/                  # Platform runners for agent setup, validation, and tests
project.godot           # Godot project configuration and main-scene setting
```

The foundation intentionally does not create a board manager, global singleton, networking layer, or minigame API. Those systems must earn their complexity through the vertical slice.

## Conventions

- Use `.tscn` for editable scenes and `.gd` for GDScript. Keep files readable in Git and use one clear owner for each scene.
- Pair a scene with a nearby script when the script is specific to that scene, for example `scenes/app/main.tscn` and `scripts/app/main.gd`.
- Use `res://` paths in project resources. Do not use machine-specific absolute paths.
- Minigame-local scenes, scripts, and assets stay within `minigames/<slug>/`; only promote something to `scenes/shared/` or `scripts/shared/` when two or more minigames genuinely need it.
- Commit original assets and their source files when practical. Do not commit generated Godot folders, exports, or builds.
- Use tabs for GDScript indentation and LF line endings. The repository’s `.editorconfig` and `.gitattributes` state this explicitly.

## Running and validating

Follow [Godot setup for agents](godot-agent-setup.md) for the pinned engine and terminal-first workflow. Run `powershell -ExecutionPolicy Bypass -File .\tools\godot.ps1 all` on Windows or `bash tools/godot.sh all` on macOS and Linux; `all` imports the project headlessly and then runs the GUT suite. Use `validate` or `test` in place of `all` when only one action is needed.

Install Godot 4.7 stable, then either import `project.godot` through the Project Manager or run:

```text
godot --editor --path .
```

Run the project with `F5`. For a lightweight command-line validation on a machine with Godot installed:

```text
godot --headless --path . --editor --quit
```

Godot’s [nodes and scenes guide](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/nodes_and_scenes.html) explains the main-scene and `project.godot` relationship used by this foundation.
