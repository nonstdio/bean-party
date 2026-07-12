# AGENTS.md

This repository is pre-production work for Bean Party, a collaborative party game inspired by Bean Battles. It uses Godot 4.7 stable and GDScript for the initial shared codebase.

## Start here

Begin with [README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md), and the [documentation index](docs/README.md). Before changing code, documentation, behavior, or project direction, follow their links and read as many task-relevant design, architecture, guide, plan, research, decision, and project documents as reasonably necessary. Read the [Godot setup guide](docs/guides/godot-setup.md) and [Godot project architecture](docs/architecture/godot-project.md) before changing the project foundation or shared runtime structure. Treat target platforms, networking model, asset pipeline, and the shared minigame API as open decisions unless a maintainer has recorded otherwise. Follow [Decision 0006](docs/decisions/0006-project-licensing.md) and the repository [license overview](LICENSE.md) for licensing boundaries.

## Common task: contribute a minigame

For the usual minigame contribution, read the [game design target](docs/design/game.md), [creative direction](docs/design/creative-direction.md), [minigame design guide](docs/design/minigames.md), and [create-a-minigame guide](docs/guides/create-a-minigame.md), in that order. Then:

1. Open a [minigame proposal](.github/ISSUE_TEMPLATE/minigame-proposal.yml) and wait for a maintainer to record `Approved for implementation` before substantial integration-focused work. A small self-contained experiment may use a personal branch or draft pull request under the documented exception.
2. Review the [minigame integration contract](docs/architecture/minigame-integration.md), run `tools/new-minigame.ps1` or `tools/new-minigame.sh`, and use [`reference-tap`](minigames/reference-tap/README.md) as the executable contract example.
3. Develop with `res://scenes/dev/minigame_harness.tscn`, remembering that it injects normalized local input and does not prove physical controller routing, app-flow integration, or networking.
4. Run `tools/quality.ps1 check` and `tools/godot.ps1 all` on Windows, or `bash tools/quality.sh check` and `bash tools/godot.sh all` on macOS and Linux.
5. Complete the pull-request template, including proposal status, player-facing effect, validation, screenshots or clips, and asset provenance.

For a copyable contributor prompt and the human-facing fork-to-review path, see [Friend minigame contributor onboarding](docs/guides/friend-minigame-onboarding.md).

## Working rules

- Keep a change focused. Do not bundle a minigame, broad refactor, engine migration, and design rewrite in one pull request.
- Preserve the distinction between the shared game shell and independently contributed minigames. Do not make a minigame depend directly on another minigame.
- Propose substantial minigames before implementation, follow the [minigame design lifecycle](docs/design/minigames.md), and preserve the boundaries in the [minigame integration contract](docs/architecture/minigame-integration.md).
- Use original or appropriately licensed material only. Never copy code, art, audio, text, character designs, logos, or other assets from Bean Battles, Mario Party, or another game.
- Use Godot 4.7 stable and GDScript. Do not upgrade Godot, introduce C#, or change the renderer without an accepted decision record.
- Never commit `.godot/`, `.import/`, `.mono/`, exported builds, or other generated editor files.
- Keep Godot scenes (`.tscn`) and scripts (`.gd`) in the documented repository layout. Use `res://` paths and pair a scene with its controller script when that makes ownership clearer.
- Update the relevant guide when a change establishes a new shared convention.

## Documentation responsibilities

- Follow the [documentation responsibilities and lifecycle](docs/README.md#contributor-documentation-responsibilities). Treat documentation as part of the implementation: create or update the canonical document in the same change when work adds or changes durable behavior, interfaces, conventions, setup requirements, or project decisions.
- Correct clear documentation errors relevant to the work and small, evidence-backed gaps found along the way. Report substantial, uncertain, or unrelated gaps to the user or maintainer instead of silently ignoring them or expanding a focused change into a broad rewrite.
- When documentation, code, tests, or recorded decisions disagree, distinguish intended behavior from currently implemented behavior and investigate the available evidence. Reconcile the sources when the answer is clear and within scope; otherwise describe the discrepancy and ask the user or a maintainer before choosing an interpretation. Do not treat research, plans, or proposals as accepted project policy.

## Validation

Verify Markdown links, keep documents internally consistent, and run `godot --headless --path . --editor --quit` when Godot is installed. Run the repository’s documented formatter, linter, file-size guard, tests, and build before opening a pull request.

## Agent commands

Before opening a pull request, run `tools/quality.ps1 check` and `tools/godot.ps1 all` on Windows or `bash tools/quality.sh check` and `bash tools/godot.sh all` on macOS and Linux. The quality runners check project-owned GDScript formatting and lint, enforce the 5 MiB per-file repository limit, and test the guard. The Godot runners honor `GODOT_BIN`, validate the headless project import, and execute GUT tests.

## Pull requests

Use the pull-request template. Explain the player-facing effect, list assets and their provenance, and call out any change to a shared interface or design decision. The `main` branch is protected; work from a branch and merge through a documented pull request. Independent approval is temporarily optional while the project has one active contributor.
