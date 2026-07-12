# Minigames

Each independently developed minigame lives in `minigames/<slug>/`. Open a GitHub issue and receive approval before substantial integration-focused implementation using the lifecycle in the [minigame design guide](../docs/design/minigames.md). Small experiments may proceed in personal branches or draft pull requests. Once approved implementation begins, the first contribution includes `minigames/<slug>/README.md` as the current design brief alongside the Godot scenes, GDScript, minigame-specific assets, and tests.

Follow [Create a minigame](../docs/guides/create-a-minigame.md) and the [minigame integration contract](../docs/architecture/minigame-integration.md) for shell ownership, runtime, outcome, cleanup, and networking boundaries. Local contract version 1 is stable; networking extensions remain provisional.

Minigame software and Godot project files use MIT. Original minigame art, audio, prose, and similar creative content use CC BY 4.0. Record every external asset's creator, source, and compatible license in the minigame README; see the repository [license overview](../LICENSE.md).
