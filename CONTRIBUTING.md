# Contributing to Bean Battles

Thank you for helping make Bean Battles. We want the project to feel like a party built by friends: ideas should be easy to pitch, minigames should be easy to try, and changes should be easy to review.

## Before you begin

Read the [game design target](docs/game-design.md), [creative direction](docs/creative-direction.md), and [minigame contribution contract](docs/minigame-contract.md). For a substantial minigame or a shared-system change, open an issue using the **Minigame proposal** template first. A short proposal saves everyone from building the same idea twice or discovering an integration problem late.

## Contribution workflow

1. Choose or open an issue. Explain the player count, controls, objective, likely round length, and visual idea.
2. Create a branch from `main`, such as `minigame/bean-bumper` or `docs/engine-spike-plan`.
3. Keep the change narrow and update its design notes as it evolves.
4. Test the experience with the intended number of players when possible. Record what you tested in the pull request.
5. Open a pull request using the repository template. Respond to review feedback and resolve conversations before requesting merge.

## Designing a minigame

The first supported target is a minigame that is understandable at a glance, fair enough to rematch, and short enough to return players to the board quickly. A useful proposal answers:

- What does each player do, and how does someone win or lose?
- Is it free-for-all, 2v2, 1v3, cooperative, or another clearly named format?
- What information must the player understand in the first ten seconds?
- How does the game avoid an early mistake making the rest of the round pointless?
- What makes it feel at home in Bean Battles rather than a generic party-game scene?

Do not assume an engine, programming language, file extension, or shared API until the project chooses one. The intended folder layout and lifecycle are described in [docs/minigame-contract.md](docs/minigame-contract.md).

## Art, audio, and third-party material

Submit only material you created or have clear permission to use. Credit the creator and license for every non-original asset in the pull request. Do not extract or copy assets from Bean Battles, Mario Party, Steam, or other games. A reference can guide an original creation; it is not a source of reusable assets.

The project has not selected a software or content license yet. Until one is added, do not assume repository material is available for reuse outside this project.

## Review and branch rules

`main` is the default and protected branch. Direct pushes, force pushes, and branch deletion are blocked. Merges require a pull request, one approval, and all review conversations resolved. Stale approvals are dismissed when the pull request changes. Maintainers retain an emergency bypass for recovery; it should not be the normal path.

Continuous integration is not configured yet, so no automated checks are required today. When build and test workflows exist, they will become part of the merge requirements.

## Good pull requests

- One clear purpose and a descriptive title.
- A short explanation of the player-facing result.
- A link to the proposal or design note, when applicable.
- Asset provenance and licensing notes.
- Tests performed and known limitations.
- Screenshots or a short clip for visual or gameplay changes, when an engine is in place.
