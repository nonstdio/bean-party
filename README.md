# Bean Party

Bean Party is a collaborative party game: a shared board game punctuated by short, competitive, cooperative, and team-based minigames. Players collect beans, take risks, trigger surprises, and compete for the win.

It takes structural inspiration from Mario Party-style board-and-minigame games, while its world, tone, and presentation draw from [Bean Battles on Steam](https://store.steampowered.com/app/765410/Bean_Battles/). This is an independent fan project, not an official Gupa Games product.

## Project goals

- Make it easy for contributors to create, test, and share self-contained minigames.
- Keep the core board game experience lightweight, approachable, and fun in local or online play.
- Build clear, reusable interfaces so minigames can plug into the main game without rewriting shared systems.
- Create a recognizably Bean Battles-inspired presentation without copying its code, art, audio, characters, or branding assets.

## Project status

The project is in pre-production. We have selected **Godot 4.7 stable** with **GDScript** for the initial shared codebase. A **proposed** peer-hosted networking architecture ([Decision 0003](docs/decisions/0003-peer-hosted-networking.md)) targets up to 8 players online; it is not validated netcode yet. Target platforms, final art pipeline, and board economy remain open decisions.

## Run the starter project

Agents should first follow [Godot setup for agents](docs/godot-agent-setup.md), which installs the pinned editor and runs the terminal-first validation and test commands on Windows, macOS, and Linux.

1. Install [Godot 4.7 stable](https://godotengine.org/download/archive/).
2. Import the repository’s `project.godot` file in the Godot Project Manager.
3. Select the project and press `F6`/`F5`, or run `godot --editor --path .` from the repository root.

The starter scene is deliberately small: it proves that the project loads and gives contributors a safe place to begin. See the [Godot project architecture](docs/godot-architecture.md) before adding shared systems or a minigame.

## Contributing

Ideas, minigame concepts, art, music, code, and playtesting feedback are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), then open a minigame proposal before beginning a substantial implementation.

## Project guides

- [Game design target](docs/game-design.md) — what “Mario Party-style” means for this project.
- [Creative direction](docs/creative-direction.md) — how to evoke Bean Battles without copying it.
- [Minigame contribution contract](docs/minigame-contract.md) — the intended shape of an independently developed minigame.
- [Networking architecture](docs/networking-architecture.md) — proposed online topology, authority, and phase machine.
- [Networking implementation plan](docs/networking-implementation-plan.md) — milestones and test matrix for future netcode work.
- [Godot project architecture](docs/godot-architecture.md) — repository layout and Godot conventions.
- [Engine evaluation](docs/engine-evaluation.md) — the evaluation that led to the Godot decision.
- [Project governance](docs/project-governance.md) — pull requests and the `main` branch rules.
- [Agent guide](AGENTS.md) — instructions for AI-assisted work in this repository.

- [Godot setup for agents](docs/godot-agent-setup.md) — exact installation, validation, and test commands on Windows, macOS, and Linux.

## Open decisions

- Is the first playable version local-only, online-only, or local-first with online play later? (Networking direction is [proposed](docs/decisions/0003-peer-hosted-networking.md); local-first remains the implementation order.)
- Which software and content licenses should govern contributions and releases?
- What is the final board economy: beans, victory tokens, or both?
