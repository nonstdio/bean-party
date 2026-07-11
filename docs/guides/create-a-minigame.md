# Create a minigame

This is the task-oriented path for adding a Bean Party minigame. The player-facing design criteria live in the [minigame design guide](../design/minigames.md); the normative runtime rules live in the [minigame integration contract](../architecture/minigame-integration.md).

## 1. Propose or experiment

Open a [minigame proposal](../../.github/ISSUE_TEMPLATE/minigame-proposal.yml) and wait for the `Approved for implementation` confirmation before substantial implementation intended for integration.

You may explore a small idea before approval in a personal branch or draft pull request. An experiment must stay self-contained, must not change shared interfaces, and must not be presented as integration-ready. If the experiment becomes a real contribution, update and obtain approval for its proposal before continuing substantial work.

## 2. Create the folder

From the repository root, run one of:

```powershell
.\tools\new-minigame.ps1 -Slug "bean-bumper" -DisplayName "Bean Bumper"
```

```bash
bash tools/new-minigame.sh bean-bumper "Bean Bumper"
```

The command creates the required folder, manifest, README, scene, controller, and local test from `minigames/_template/`. Slugs must use lowercase kebab-case and become stable runtime identifiers.

## 3. Implement through the contract

The scene root **must** extend `MinigameController`. Implement `_on_minigame_setup()`, `_on_minigame_start()`, and `_on_minigame_abort()` as needed. Read setup data through `get_minigame_context()` and submit exactly one `MinigameResult` through `submit_minigame_result()`.

Minigames:

- **MUST** use only the `PlayerSlot`s, teams, RNG seed, and input source supplied in `MinigameContext`;
- **MUST** return every participating player exactly once in ordered placement groups; players in the same group are tied;
- **MUST NOT** return or apply beans, items, board advantages, or other shared-economy changes;
- **MUST NOT** change match phases, load the board, create a transport, enumerate physical devices, or mutate the project `InputMap`;
- **MUST NOT** reference another minigame;
- **MUST** tolerate shell-requested abort and repeated load/run/unload cycles;
- **SHOULD** keep all owned scenes, scripts, tests, and assets inside its folder;
- **MAY** use reviewed resources from shared folders without modifying them.

The shell owns pause, retry, early exit, scene teardown, and translation from outcomes to board rewards.

## 4. Run and test

Run the complete repository checks:

```powershell
.\tools\godot.ps1 all
```

```bash
bash tools/godot.sh all
```

Tests under `minigames/<slug>/tests/` are part of the standard GUT run. Open `res://scenes/dev/minigame_harness.tscn` in Godot and run the current scene with `F6` to exercise a manifest with deterministic local players and inputs while developing.

At minimum, verify:

- every declared player count and team format;
- briefing, active play, ties, and normal completion;
- retry after completion;
- early exit and forced abort;
- two consecutive runs without leaked state;
- keyboard/controller layouts that the minigame claims to support;
- readable gameplay without relying on color alone.

## 5. Prepare integration review

Update the minigame README with its current rules, proposal link, controls, capability, assets and provenance, test notes, and known limitations. Complete the minigame section of the pull-request template and include a screenshot or short clip for visible gameplay.

Changing `scripts/shared/minigames/`, the contract version, or the shell/minigame ownership boundary is a shared-interface change and requires its own focused design review.

## Common mistakes

| Mistake | Use instead |
| --- | --- |
| Calling `Input` directly for gameplay | The context's per-player `MinigameInputSource` |
| Looking up controllers or device IDs | Shell-owned input assignment |
| Awarding beans in minigame code | Return placements/scores; let the shell apply reward policy |
| Calling `change_scene_to_*` | Submit a result and let `MinigameRunner` transition |
| Adding an autoload or static mutable state | State owned by the minigame scene instance |
| Referencing another minigame's helper | Propose a reviewed shared helper when there is demonstrated reuse |
| Creating ENet, Steam, or RPC plumbing | The provisional session/network extension when it is accepted |
