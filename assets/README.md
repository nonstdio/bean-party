# Assets

Store original, project-owned source assets here as the common art and audio kit emerges. Keep minigame-specific assets inside that minigame’s directory instead.

The initial reusable kit is indexed in the [standard asset catalog](standard/catalog.md). Read [Use and contribute standard assets](../docs/guides/standard-assets.md) before creating a similar shared asset. Assets marked **Canonical prototype** are the default for new work even though their appearance remains replaceable and pre-production quality; do not add new uses of entries marked **Deprecated**.

Editable standard sources live under `source/standard/`, behind `.gdignore`; committed runtime exports and Godot-native resources live under `standard/`. This keeps Blender out of ordinary Godot imports and CI while preserving source history.

For every imported third-party asset, include clear provenance and license information. Do not add extracted, copied, or lightly edited assets from Bean Battles, Mario Party, Steam, or another game.

Generated imports belong in `.godot/` and are intentionally ignored by Git.
