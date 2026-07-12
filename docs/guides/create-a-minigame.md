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

Review [`reference-tap`](../../minigames/reference-tap/README.md) after scaffolding. It is deliberately small, but it demonstrates the accepted controller, context, normalized-input, result, test, and teardown boundaries.

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

### Asset size and audio formats

Every committed file must be at most **5 MiB** (`5 × 1024 × 1024` bytes). This is a repository-health limit, not a final runtime or platform asset budget. It applies to editable sources and runtime exports, including images, models, audio, and video. If an original or appropriately licensed asset cannot reasonably fit, discuss a narrow exception with a maintainer before adding it; approved paths are recorded in `tools/file-size-allowlist.txt`. Do not introduce Git LFS without a reviewed repository-wide change.

Choose audio formats by playback use instead of converting every sound to one format:

- use WAV for short, frequently repeated sound effects where low playback CPU cost matters;
- use Ogg Vorbis for music, speech, ambience, and long effects where compression materially reduces repository and build size;
- trim silence, use mono when spatial stereo is unnecessary, and avoid sample rates above 48 kHz unless the source has a documented editing or runtime need.

See [Godot 4.7 audio import guidance](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_audio_samples.html) for the format and import-setting tradeoffs. Keep original or appropriately licensed provenance in the minigame README regardless of format.

## 4. Run and test

Run repository quality checks and their guard tests:

```powershell
.\tools\quality.ps1 check
```

```bash
bash tools/quality.sh check
```

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
