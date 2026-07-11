# Contributing to Bean Party

Thank you for helping make Bean Party. We want the project to feel like a party built by friends: ideas should be easy to pitch, minigames should be easy to try, and changes should be easy to review.

## Before you begin

Read the [game design target](docs/design/game.md), [creative direction](docs/design/creative-direction.md), and [minigame design guide](docs/design/minigames.md). For a substantial minigame or a shared-system change, open an issue using the **Minigame proposal** template and receive `Approved for implementation` before substantial integration-focused work. Small experiments may proceed in personal branches or draft pull requests, but they do not establish shared conventions. Follow [Create a minigame](docs/guides/create-a-minigame.md) and review the separate [minigame integration contract](docs/architecture/minigame-integration.md) before implementation.

## Godot setup

The project standard is **Godot 4.7 stable** with **GDScript**. Follow [Godot setup for agents](docs/guides/godot-setup.md) for the exact Windows, macOS, or Linux installation and non-interactive validation commands. Run `tools/godot.ps1 all` on Windows or `bash tools/godot.sh all` on macOS or Linux before opening a pull request. See the [Godot project architecture](docs/architecture/godot-project.md) for the repository layout and `res://` paths.

Do not commit Godot-generated folders such as `.godot/`, `.import/`, or `.mono/`, and do not add exported builds to the repository. Use a decision record before upgrading the engine, adding C#, changing renderer defaults, or adding a project-wide Godot plugin.

## Contribution workflow

1. Choose or open an issue. Explain the player count, controls, objective, likely round length, and visual idea.
2. Create a branch from `main`, such as `minigame/bean-bumper` or `docs/engine-spike-plan`.
3. Keep the change narrow and update its design notes as it evolves.
4. Test the experience with the intended number of players when possible. Record what you tested in the pull request.
5. Open a pull request using the repository template. Respond to review feedback and resolve conversations before requesting merge.

## Designing a minigame

The [minigame design guide](docs/design/minigames.md) is the canonical source for proposal contents and design review criteria. The GitHub issue remains canonical while an idea is being discussed; once implementation begins, keep the current brief in `minigames/<slug>/README.md` and link it back to the proposal.

Use Godot scenes and GDScript through local minigame contract version 1, documented in the [minigame integration contract](docs/architecture/minigame-integration.md). Networking extensions remain provisional until their planned spikes and stabilization milestone complete.

## Art, audio, and third-party material

Submit only material you created or have clear permission to use. Credit the creator and license for every non-original asset in the pull request. Do not extract or copy assets from Bean Battles, Mario Party, Steam, or other games. A reference can guide an original creation; it is not a source of reusable assets.

The project has not selected a software or content license yet. Until one is added, do not assume repository material is available for reuse outside this project.

## Review and branch rules

`main` is the default and protected branch. Direct pushes, force pushes, and branch deletion are blocked. Merges require a pull request and all review conversations resolved. The required-approval count is temporarily **zero** while the project has one active contributor, so a contributor may merge their own pull request. Stale approvals are still dismissed when the pull request changes. Maintainers retain an emergency bypass for recovery; it should not be the normal path.

When the project has at least two active contributors, restore one required independent approval before merge.

The required `Godot tests` check runs headless validation and GUT tests on Windows, macOS, and Linux. It must pass before a pull request merges; run the same command locally before requesting review.

## Good pull requests

- One clear purpose and a descriptive title.
- A short explanation of the player-facing result.
- A link to the proposal or design note, when applicable.
- Asset provenance and licensing notes.
- Tests performed and known limitations.
- Screenshots or a short clip for visual or gameplay changes, when an engine is in place.
