# AGENTS.md

This repository is pre-production work for a collaborative Bean Battles-inspired party game. It has no chosen engine or production code yet.

## Start here

Read [README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md), and the relevant document in `docs/` before changing project direction. Treat the engine choice, target platforms, networking model, licensing, and asset pipeline as open decisions unless a maintainer has recorded otherwise.

## Working rules

- Keep a change focused. Do not bundle a minigame, broad refactor, engine migration, and design rewrite in one pull request.
- Preserve the distinction between the shared game shell and independently contributed minigames. Do not make a minigame depend directly on another minigame.
- Propose substantial minigames before implementation and follow the lifecycle in [docs/minigame-contract.md](docs/minigame-contract.md).
- Use original or appropriately licensed material only. Never copy code, art, audio, text, character designs, logos, or other assets from Bean Battles, Mario Party, or another game.
- Do not make an engine choice or add engine-specific generated files without an accepted decision and a maintainer’s approval.
- Update the relevant guide when a change establishes a new shared convention.

## Validation

Until an engine is selected, verify Markdown links, keep documents internally consistent, and report any validation that cannot yet be run. Once code exists, run the repository’s documented formatter, tests, and build before opening a pull request.

## Pull requests

Use the pull-request template. Explain the player-facing effect, list assets and their provenance, and call out any change to a shared interface or design decision. The `main` branch is protected; work from a branch and merge through a reviewed pull request.
