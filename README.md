# Bean Battles

Bean Battles is a collaborative party game: a shared board game punctuated by short, competitive, cooperative, and team-based minigames. Players collect beans, take risks, trigger surprises, and compete for the win.

It takes structural inspiration from Mario Party-style board-and-minigame games, while its world, tone, and presentation draw from [Bean Battles on Steam](https://store.steampowered.com/app/765410/Bean_Battles/). This is an independent fan project, not an official Gupa Games product.

## Project goals

- Make it easy for contributors to create, test, and share self-contained minigames.
- Keep the core board game experience lightweight, approachable, and fun in local or online play.
- Build clear, reusable interfaces so minigames can plug into the main game without rewriting shared systems.
- Create a recognizably Bean Battles-inspired presentation without copying its code, art, audio, characters, or branding assets.

## Project status

The project is in pre-production. We have not chosen a game engine, target platforms, networking model, or final art pipeline. The early goal is to align on the game’s direction and establish a friendly, reviewable contribution workflow.

## Contributing

Ideas, minigame concepts, art, music, code, and playtesting feedback are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), then open a minigame proposal before beginning a substantial implementation.

## Project guides

- [Game design target](docs/game-design.md) — what “Mario Party-style” means for this project.
- [Creative direction](docs/creative-direction.md) — how to evoke Bean Battles without copying it.
- [Minigame contribution contract](docs/minigame-contract.md) — the intended shape of an independently developed minigame.
- [Engine evaluation](docs/engine-evaluation.md) — requirements, candidates, and a decision plan.
- [Project governance](docs/project-governance.md) — pull requests and the `main` branch rules.
- [Agent guide](AGENTS.md) — instructions for AI-assisted work in this repository.

## Open decisions

- Which engine and first target platform should we support?
- Is the first playable version local-only, online-only, or local-first with online play later?
- Which software and content licenses should govern contributions and releases?
- What is the final board economy: beans, victory tokens, or both?
