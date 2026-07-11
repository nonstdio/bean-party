# AGENTS.md

This repository is pre-production work for Bean Party, a collaborative party game inspired by Bean Battles. It uses Godot 4.7 stable and GDScript for the initial shared codebase.

## Start here

Read [README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md), [docs/godot-agent-setup.md](docs/godot-agent-setup.md), [docs/godot-architecture.md](docs/godot-architecture.md), and the relevant document in `docs/` before changing project direction. Treat target platforms, networking model, licensing, asset pipeline, and the shared minigame API as open decisions unless a maintainer has recorded otherwise.

## Working rules

- Keep a change focused. Do not bundle a minigame, broad refactor, engine migration, and design rewrite in one pull request.
- Preserve the distinction between the shared game shell and independently contributed minigames. Do not make a minigame depend directly on another minigame.
- Propose substantial minigames before implementation and follow the lifecycle in [docs/minigame-contract.md](docs/minigame-contract.md).
- Use original or appropriately licensed material only. Never copy code, art, audio, text, character designs, logos, or other assets from Bean Battles, Mario Party, or another game.
- Use Godot 4.7 stable and GDScript. Do not upgrade Godot, introduce C#, or change the renderer without an accepted decision record.
- Never commit `.godot/`, `.import/`, `.mono/`, exported builds, or other generated editor files.
- Keep Godot scenes (`.tscn`) and scripts (`.gd`) in the documented repository layout. Use `res://` paths and pair a scene with its controller script when that makes ownership clearer.
- Update the relevant guide when a change establishes a new shared convention.

## Validation

Verify Markdown links, keep documents internally consistent, and run `godot --headless --path . --editor --quit` when Godot is installed. Once automated checks exist, run the repository’s documented formatter, tests, and build before opening a pull request.

## Agent commands

Before opening a pull request, run `tools/godot.ps1 all` on Windows or `bash tools/godot.sh all` on macOS and Linux. The runners honor `GODOT_BIN`, validate the headless project import, and execute GUT tests.

## Pull requests

Use the pull-request template. Explain the player-facing effect, list assets and their provenance, and call out any change to a shared interface or design decision. The `main` branch is protected; work from a branch and merge through a documented pull request. Independent approval is temporarily optional while the project has one active contributor.
