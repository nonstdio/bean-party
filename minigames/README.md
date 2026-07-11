# Minigames

Each independently developed minigame will live in `minigames/<slug>/`. The first contribution should include its design brief, Godot scenes, GDScript, minigame-specific assets, and test notes as described in [the minigame contract](../docs/architecture/minigame-integration.md).

There is no code-level minigame API yet. Propose that interface through the first vertical slice instead of making a minigame depend directly on the future board scene.
