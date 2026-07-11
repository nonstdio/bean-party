# Minigames

Each independently developed minigame will live in `minigames/<slug>/`. Open a GitHub issue before substantial implementation using the lifecycle in the [minigame design guide](../docs/design/minigames.md). Once implementation begins, the first contribution should include `minigames/<slug>/README.md` as the current design brief alongside the Godot scenes, GDScript, minigame-specific assets, and test notes.

Follow the [minigame integration contract](../docs/architecture/minigame-integration.md) for shell ownership, runtime, result, cleanup, and networking boundaries. There is no accepted code-level minigame API yet; propose that interface through the first vertical slice instead of making a minigame depend directly on the future board scene.
